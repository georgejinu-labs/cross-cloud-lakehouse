# ============================================================
# 02_setup_gcp.ps1
# GCP side setup — BigQuery Omni project, dataset, connection
# Run after 01_setup_azure.ps1
# Prerequisites: gcloud, bq CLIs installed and logged in
# ============================================================

# ── Configuration — update these before running ─────────────
$GCP_PROJECT_ID    = "<YOUR_GCP_PROJECT_ID>"      # e.g. cross-cloud-lh-azure
$GCP_PROJECT_NAME  = "Cross Cloud Lakehouse"
$GCP_ORG_ID        = "<YOUR_GCP_ORG_ID>"          # numeric org ID
$BILLING_ACCOUNT   = "<YOUR_BILLING_ACCOUNT_ID>"  # e.g. 0136F5-89093C-CC5CA7
$BQ_DATASET        = "healthcare_lakehouse"
$BQ_LOCATION       = "azure-eastus2"
$BQ_CONNECTION_ID  = "healthcare-azure-conn"
$AZURE_TENANT_ID   = "<YOUR_AZURE_TENANT_ID>"     # from 01_setup_azure.ps1 output
$AZURE_APP_ID      = "<YOUR_AZURE_APP_CLIENT_ID>" # from 01_setup_azure.ps1 output
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

Write-Host "`n=== Step 5: Create BigQuery Dataset in Azure Region ===" -ForegroundColor Cyan
bq mk --location=$BQ_LOCATION --dataset "${GCP_PROJECT_ID}:${BQ_DATASET}"

Write-Host "`n================================================================" -ForegroundColor Green
Write-Host "GCP project and dataset ready." -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next: Create the BigQuery connection MANUALLY in BigQuery Studio:" -ForegroundColor Yellow
Write-Host "  1. Go to BigQuery Studio → + Add → Connections to external data sources"
Write-Host "  2. Type:          Lakehouse on Azure (via BigQuery Omni)"
Write-Host "  3. Connection ID: $BQ_CONNECTION_ID"
Write-Host "  4. Location:      $BQ_LOCATION"
Write-Host "  5. Identity type: Federated identity"
Write-Host "  6. Tenant ID:     $AZURE_TENANT_ID"
Write-Host "  7. App Client ID: $AZURE_APP_ID"
Write-Host "  8. Click Create connection"
Write-Host ""
Write-Host "After creation, copy the 'BigQuery Google identity' number shown." -ForegroundColor Yellow
Write-Host "Then run: .\scripts\03_grant_bigquery_access.ps1" -ForegroundColor Yellow
