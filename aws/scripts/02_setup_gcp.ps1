# ============================================================
# 02_setup_gcp.ps1
# GCP side setup — BigQuery project, dataset, and connection
# to the Iceberg REST catalog running on EC2
# Run after 01_setup_aws.ps1
# Prerequisites: gcloud, bq CLIs installed and logged in
# ============================================================

# ── Configuration — update these before running ─────────────
$GCP_PROJECT_ID   = "<YOUR_GCP_PROJECT_ID>"      # e.g. cross-cloud-lakehouse-aws
$GCP_PROJECT_NAME = "Cross Cloud Lakehouse AWS"
$GCP_ORG_ID       = "<YOUR_GCP_ORG_ID>"          # numeric org ID
$BILLING_ACCOUNT  = "<YOUR_BILLING_ACCOUNT_ID>"  # e.g. 0136F5-89093C-CC5CA7
$BQ_DATASET       = "healthcare_lakehouse"
$BQ_LOCATION      = "us"
$BQ_CONNECTION_ID = "healthcare-iceberg-conn"
$EC2_PUBLIC_IP    = "<EC2_PUBLIC_IP>"             # from 01_setup_aws.ps1 output
$AWS_ROLE_ARN     = "<IAM_ROLE_ARN>"             # arn:aws:iam::<ACCOUNT_ID>:role/lakehouse-ec2-role
# ────────────────────────────────────────────────────────────

Write-Host "`n=== Step 1: Create GCP Project ===" -ForegroundColor Cyan
gcloud projects create $GCP_PROJECT_ID `
  --name=$GCP_PROJECT_NAME `
  --organization=$GCP_ORG_ID

Write-Host "`n=== Step 2: Set Active Project ===" -ForegroundColor Cyan
gcloud config set project $GCP_PROJECT_ID

Write-Host "`n=== Step 3: Link Billing Account ===" -ForegroundColor Cyan
gcloud billing projects link $GCP_PROJECT_ID --billing-account=$BILLING_ACCOUNT

Write-Host "`n=== Step 4: Enable BigQuery API ===" -ForegroundColor Cyan
gcloud services enable bigquery.googleapis.com --project=$GCP_PROJECT_ID

Write-Host "`n=== Step 5: Create BigQuery Dataset ===" -ForegroundColor Cyan
bq mk --location=$BQ_LOCATION --dataset "${GCP_PROJECT_ID}:${BQ_DATASET}"

Write-Host "`n=== Step 6: Create BigQuery Connection to Iceberg REST on EC2 ===" -ForegroundColor Cyan
Write-Host "Create the connection in BigQuery Studio:" -ForegroundColor Yellow
Write-Host "  + Add → Connections to external data sources"
Write-Host "  Type:          Cloud resource"
Write-Host "  Connection ID: $BQ_CONNECTION_ID"
Write-Host "  Location:      $BQ_LOCATION"
Write-Host ""
Write-Host "After creation, note the BigQuery service account email."
Write-Host "Update trust-policy.json with that email's unique ID (accounts.google.com:sub)" -ForegroundColor Yellow
Write-Host "Then run: aws iam update-assume-role-policy --role-name lakehouse-ec2-role --policy-document file://trust-policy.json"

Write-Host "`n=== Step 7: Create External Iceberg Tables ===" -ForegroundColor Cyan
Write-Host "Once the pipeline is running on EC2, run in BigQuery Studio:" -ForegroundColor Yellow
Write-Host @"

CREATE OR REPLACE EXTERNAL TABLE ``$GCP_PROJECT_ID.$BQ_DATASET.members``
WITH CONNECTION ``projects/$GCP_PROJECT_ID/locations/$BQ_LOCATION/connections/$BQ_CONNECTION_ID``
OPTIONS (
  format = 'ICEBERG',
  uris = ['http://${EC2_PUBLIC_IP}:8080/v1/namespaces/healthcare/tables/members']
);

CREATE OR REPLACE EXTERNAL TABLE ``$GCP_PROJECT_ID.$BQ_DATASET.claims``
WITH CONNECTION ``projects/$GCP_PROJECT_ID/locations/$BQ_LOCATION/connections/$BQ_CONNECTION_ID``
OPTIONS (
  format = 'ICEBERG',
  uris = ['http://${EC2_PUBLIC_IP}:8080/v1/namespaces/healthcare/tables/claims']
);
"@

Write-Host "`n================================================================" -ForegroundColor Green
Write-Host "GCP setup complete." -ForegroundColor Green
Write-Host "  GCP_PROJECT_ID = $GCP_PROJECT_ID"
Write-Host "  EC2 endpoint   = http://${EC2_PUBLIC_IP}:8080"
Write-Host "================================================================" -ForegroundColor Green
Write-Host "Next: Run .\scripts\03_run_pipeline.ps1" -ForegroundColor Yellow
