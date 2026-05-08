# ============================================================
# 03_run_pipeline.ps1
# Deploy Docker stack to EC2 and run the Oracle → S3 pipeline
# Run from the aws/ folder: .\scripts\03_run_pipeline.ps1
# Prerequisites: EC2 instance running, lakehouse-key.pem present
# ============================================================

# ── Configuration — update these before running ─────────────
$EC2_PUBLIC_IP  = "<EC2_PUBLIC_IP>"         # from 01_setup_aws.ps1 output
$KEY_FILE       = ".\lakehouse-key.pem"
$EC2_USER       = "ec2-user"
$S3_BUCKET      = "<YOUR_S3_BUCKET>"
$AWS_REGION     = "us-east-1"
# ────────────────────────────────────────────────────────────

$SSH = "ssh -i $KEY_FILE -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_PUBLIC_IP}"
$SCP = "scp -i $KEY_FILE -o StrictHostKeyChecking=no"

Write-Host "`n=== Step 1: Copy docker-compose.yml to EC2 ===" -ForegroundColor Cyan
Invoke-Expression "$SCP .\docker-compose.yml ${EC2_USER}@${EC2_PUBLIC_IP}:~/docker-compose.yml"

Write-Host "`n=== Step 2: Start the Docker Stack on EC2 ===" -ForegroundColor Cyan
Invoke-Expression "$SSH 'docker compose up -d'"

Write-Host "`nWaiting 15 seconds for services to start..."
Start-Sleep -Seconds 15

Write-Host "`n=== Step 3: Verify Iceberg REST Catalog on EC2 ===" -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Uri "http://${EC2_PUBLIC_IP}:8080/v1/config"
    Write-Host "Iceberg REST catalog is up on EC2." -ForegroundColor Green
} catch {
    Write-Host "Not ready yet — check EC2 logs: $SSH 'docker compose logs iceberg-rest'" -ForegroundColor Yellow
}

Write-Host "`n=== Step 4: Install Python Dependencies (local) ===" -ForegroundColor Cyan
pip install oracledb pyiceberg pyarrow boto3

Write-Host "`n=== Step 5: Update Pipeline Script ===" -ForegroundColor Cyan
Write-Host "Make sure oracle_to_iceberg_aws.py has:" -ForegroundColor Yellow
Write-Host "  ICEBERG_REST_URL = 'http://${EC2_PUBLIC_IP}:8080'"
Write-Host "  S3_BUCKET        = '$S3_BUCKET'"
Write-Host "  AWS_REGION       = '$AWS_REGION'"

Write-Host "`n=== Step 6: Run the Pipeline (locally, writes to S3 via EC2 catalog) ===" -ForegroundColor Cyan
python oracle_to_iceberg_aws.py

Write-Host "`n=== Step 7: Verify Data in S3 ===" -ForegroundColor Cyan
aws s3 ls "s3://$S3_BUCKET/healthcare/" --recursive

Write-Host "`n=== Step 8: Verify Tables in Iceberg Catalog on EC2 ===" -ForegroundColor Cyan
try {
    $tables = Invoke-RestMethod -Uri "http://${EC2_PUBLIC_IP}:8080/v1/namespaces/healthcare/tables"
    Write-Host "Tables registered in Iceberg catalog:" -ForegroundColor Green
    $tables | ConvertTo-Json
} catch {
    Write-Host "Could not reach catalog — check EC2 security group allows port 8080" -ForegroundColor Yellow
}

Write-Host "`n================================================================" -ForegroundColor Green
Write-Host "Pipeline complete. Data is in S3 and registered in Iceberg catalog on EC2." -ForegroundColor Green
Write-Host "Next: Run bigquery/create_iceberg_tables.sql in BigQuery Studio" -ForegroundColor Yellow
Write-Host "Then: Run bigquery/healthcare_queries.sql to query the data" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Green
