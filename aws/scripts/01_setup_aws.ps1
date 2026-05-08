# ============================================================
# 01_setup_aws.ps1
# AWS side setup — S3 bucket, EC2 instance, IAM role
# Run from the aws/ folder: .\scripts\01_setup_aws.ps1
# Prerequisites: aws CLI installed and configured (aws configure)
# ============================================================

# ── Configuration — update these before running ─────────────
$S3_BUCKET      = "<YOUR_S3_BUCKET>"        # e.g. healthcare-lakehouse-poc-aws
$AWS_REGION     = "us-east-1"
$KEY_PAIR_NAME  = "lakehouse-key"           # EC2 key pair name
$INSTANCE_TYPE  = "t3.medium"
$IAM_ROLE_NAME  = "lakehouse-ec2-role"
$INSTANCE_PROFILE_NAME = "lakehouse-ec2-profile"
$SG_NAME        = "lakehouse-sg"
# ────────────────────────────────────────────────────────────

Write-Host "`n=== Step 1: Verify AWS CLI Identity ===" -ForegroundColor Cyan
aws sts get-caller-identity

Write-Host "`n=== Step 2: Create S3 Bucket ===" -ForegroundColor Cyan
if ($AWS_REGION -eq "us-east-1") {
    aws s3api create-bucket --bucket $S3_BUCKET --region $AWS_REGION
} else {
    aws s3api create-bucket --bucket $S3_BUCKET --region $AWS_REGION `
      --create-bucket-configuration LocationConstraint=$AWS_REGION
}
aws s3api put-public-access-block `
  --bucket $S3_BUCKET `
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

Write-Host "`n=== Step 3: Create IAM Role for EC2 + BigQuery Federation ===" -ForegroundColor Cyan
# trust-policy.json allows both EC2 and GCP BigQuery (via OIDC) to assume this role
aws iam create-role `
  --role-name $IAM_ROLE_NAME `
  --assume-role-policy-document file://trust-policy.json

# Attach S3 access policy inline
$S3_POLICY = @"
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:GetObject","s3:PutObject","s3:DeleteObject","s3:ListBucket"],
    "Resource": ["arn:aws:s3:::$S3_BUCKET","arn:aws:s3:::$S3_BUCKET/*"]
  }]
}
"@
$S3_POLICY | Out-File -FilePath "$env:TEMP\s3-policy.json" -Encoding ascii

aws iam put-role-policy `
  --role-name $IAM_ROLE_NAME `
  --policy-name "lakehouse-s3-access" `
  --policy-document "file://$env:TEMP\s3-policy.json"

Write-Host "`n=== Step 4: Create Instance Profile and Attach Role ===" -ForegroundColor Cyan
aws iam create-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME
aws iam add-role-to-instance-profile `
  --instance-profile-name $INSTANCE_PROFILE_NAME `
  --role-name $IAM_ROLE_NAME

Write-Host "`n=== Step 5: Create Security Group (ports 22 and 8080) ===" -ForegroundColor Cyan
$VPC_ID = aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" `
  --query "Vpcs[0].VpcId" -o tsv

$SG_ID = aws ec2 create-security-group `
  --group-name $SG_NAME `
  --description "Lakehouse POC — SSH + Iceberg REST" `
  --vpc-id $VPC_ID `
  --query "GroupId" -o tsv

# SSH access
aws ec2 authorize-security-group-ingress `
  --group-id $SG_ID --protocol tcp --port 22 --cidr "0.0.0.0/0"

# Iceberg REST catalog — open to BigQuery (0.0.0.0/0 for POC, restrict in prod)
aws ec2 authorize-security-group-ingress `
  --group-id $SG_ID --protocol tcp --port 8080 --cidr "0.0.0.0/0"

Write-Host "Security Group ID: $SG_ID"

Write-Host "`n=== Step 6: Launch EC2 Instance ===" -ForegroundColor Cyan
# Amazon Linux 2023 AMI (update AMI ID for your region if needed)
$AMI_ID = aws ec2 describe-images `
  --owners amazon `
  --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" `
  --query "sort_by(Images,&CreationDate)[-1].ImageId" -o tsv

$INSTANCE_ID = aws ec2 run-instances `
  --image-id $AMI_ID `
  --instance-type $INSTANCE_TYPE `
  --key-name $KEY_PAIR_NAME `
  --security-group-ids $SG_ID `
  --iam-instance-profile Name=$INSTANCE_PROFILE_NAME `
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=lakehouse-iceberg-rest}]" `
  --user-data @"
#!/bin/bash
yum update -y
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
"@ `
  --query "Instances[0].InstanceId" -o tsv

Write-Host "Instance ID: $INSTANCE_ID"
Write-Host "Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

$EC2_PUBLIC_IP = aws ec2 describe-instances `
  --instance-ids $INSTANCE_ID `
  --query "Reservations[0].Instances[0].PublicIpAddress" -o tsv

Write-Host "`n================================================================" -ForegroundColor Green
Write-Host "AWS setup complete." -ForegroundColor Green
Write-Host "  S3_BUCKET     = $S3_BUCKET"
Write-Host "  INSTANCE_ID   = $INSTANCE_ID"
Write-Host "  EC2_PUBLIC_IP = $EC2_PUBLIC_IP"
Write-Host "  IAM_ROLE      = $IAM_ROLE_NAME"
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next: Run .\scripts\02_setup_gcp.ps1" -ForegroundColor Yellow
Write-Host "Then: Run .\scripts\03_run_pipeline.ps1 to deploy the stack to EC2" -ForegroundColor Yellow
