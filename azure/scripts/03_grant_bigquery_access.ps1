# ============================================================
# 03_grant_bigquery_access.ps1
# Grant BigQuery Omni access to Azure ADLS Gen2
# Run after the BigQuery connection is created in the console
# and you have the BigQuery Google identity number
# ============================================================

# ── Configuration — update these before running ─────────────
$AZURE_APP_CLIENT_ID      = "<YOUR_AZURE_APP_CLIENT_ID>"   # from 01_setup_azure.ps1
$BIGQUERY_GOOGLE_IDENTITY = "<BIGQUERY_GOOGLE_IDENTITY>"   # number from BigQuery connection page
$STORAGE_ACCOUNT          = "<YOUR_STORAGE_ACCOUNT>"
$RESOURCE_GROUP           = "<YOUR_RESOURCE_GROUP>"
$CONTAINER_NAME           = "lakehouse"
# ────────────────────────────────────────────────────────────

Write-Host "`n=== Step 1: Add Federated Credential to Azure AD App ===" -ForegroundColor Cyan
$fedParams = @{
    name      = "bigquery-omni-fed"
    issuer    = "https://accounts.google.com"
    subject   = $BIGQUERY_GOOGLE_IDENTITY
    audiences = @("api://AzureADTokenExchange")
} | ConvertTo-Json -Compress

az ad app federated-credential create `
  --id $AZURE_APP_CLIENT_ID `
  --parameters $fedParams

Write-Host "`n=== Step 2: Grant Storage Blob Data Reader on lakehouse Container ===" -ForegroundColor Cyan
$SUB_ID = az account show --query id -o tsv
$SCOPE = "/subscriptions/$SUB_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT/blobServices/default/containers/$CONTAINER_NAME"

az role assignment create `
  --assignee $AZURE_APP_CLIENT_ID `
  --role "Storage Blob Data Reader" `
  --scope $SCOPE

Write-Host "`n================================================================" -ForegroundColor Green
Write-Host "BigQuery Omni access granted." -ForegroundColor Green
Write-Host "Wait 1-2 minutes for RBAC to propagate, then:" -ForegroundColor Yellow
Write-Host "  1. Run the pipeline: python oracle_to_iceberg_azure.py"
Write-Host "  2. Create BigQuery tables: run bigquery/create_iceberg_tables.sql in BigQuery Studio"
Write-Host "  3. Run queries: run bigquery/healthcare_queries.sql in BigQuery Studio"
Write-Host "================================================================" -ForegroundColor Green
