# ============================================================
# 01_setup_azure.ps1
# Azure side setup for the cross-cloud lakehouse POC
# Run from the azure/ folder: .\scripts\01_setup_azure.ps1
# Prerequisites: az CLI installed and logged in (az login)
# ============================================================

# ── Configuration — update these before running ─────────────
$STORAGE_ACCOUNT  = "<YOUR_STORAGE_ACCOUNT>"     # e.g. healthcarelakehousepoc
$RESOURCE_GROUP   = "<YOUR_RESOURCE_GROUP>"       # e.g. rg-lakehouse-poc
$LOCATION         = "eastus"
$CONTAINER_NAME   = "lakehouse"
$APP_DISPLAY_NAME = "bigquery-omni-healthcare"
# ────────────────────────────────────────────────────────────

Write-Host "`n=== Step 1: Create Resource Group ===" -ForegroundColor Cyan
az group create --name $RESOURCE_GROUP --location $LOCATION

Write-Host "`n=== Step 2: Create Storage Account (ADLS Gen2 with HNS) ===" -ForegroundColor Cyan
az storage account create `
  --name $STORAGE_ACCOUNT `
  --resource-group $RESOURCE_GROUP `
  --location $LOCATION `
  --sku Standard_LRS `
  --kind StorageV2 `
  --enable-hierarchical-namespace true `
  --allow-blob-public-access false

Write-Host "`n=== Step 3: Create lakehouse Container ===" -ForegroundColor Cyan
az storage container create `
  --name $CONTAINER_NAME `
  --account-name $STORAGE_ACCOUNT `
  --auth-mode login

Write-Host "`n=== Step 4: Allow Public Network Access (POC only) ===" -ForegroundColor Cyan
az storage account update `
  --name $STORAGE_ACCOUNT `
  --resource-group $RESOURCE_GROUP `
  --default-action Allow

Write-Host "`n=== Step 5: Get Account Key ===" -ForegroundColor Cyan
$ACCOUNT_KEY = az storage account keys list `
  --account-name $STORAGE_ACCOUNT `
  --resource-group $RESOURCE_GROUP `
  --query "[0].value" -o tsv

Write-Host "Account Key: $ACCOUNT_KEY"
Write-Host ">>> Update ADLS_ACCOUNT_KEY in oracle_to_iceberg_azure.py with this value" -ForegroundColor Yellow

Write-Host "`n=== Step 6: Create Azure AD App Registration ===" -ForegroundColor Cyan
$APP_JSON = az ad app create --display-name $APP_DISPLAY_NAME | ConvertFrom-Json
$APP_CLIENT_ID = $APP_JSON.appId
Write-Host "App Client ID: $APP_CLIENT_ID"

Write-Host "`n=== Step 7: Create Service Principal for the App ===" -ForegroundColor Cyan
az ad sp create --id $APP_CLIENT_ID

Write-Host "`n=== Step 8: Get Azure Tenant ID ===" -ForegroundColor Cyan
$TENANT_ID = az account show --query tenantId -o tsv
Write-Host "Tenant ID: $TENANT_ID"

Write-Host "`n=== Step 9: Get Subscription ID ===" -ForegroundColor Cyan
$SUB_ID = az account show --query id -o tsv
Write-Host "Subscription ID: $SUB_ID"

Write-Host "`n================================================================" -ForegroundColor Green
Write-Host "Azure setup complete. Save these values for the GCP setup script:" -ForegroundColor Green
Write-Host "  AZURE_TENANT_ID    = $TENANT_ID"
Write-Host "  AZURE_APP_CLIENT_ID= $APP_CLIENT_ID"
Write-Host "  STORAGE_ACCOUNT    = $STORAGE_ACCOUNT"
Write-Host "  ACCOUNT_KEY        = $ACCOUNT_KEY"
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next: Run 02_setup_gcp.ps1, then come back here for step 10." -ForegroundColor Yellow
Write-Host "After BigQuery connection is created, you will get a BIGQUERY_GOOGLE_IDENTITY number."
Write-Host "Run 03_grant_bigquery_access.ps1 with that number to complete the Azure side." -ForegroundColor Yellow
