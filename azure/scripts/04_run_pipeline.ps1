# ============================================================
# 04_run_pipeline.ps1
# Start Docker stack, verify Oracle, and run the pipeline
# Run from the azure/ folder: .\scripts\04_run_pipeline.ps1
# ============================================================

Write-Host "`n=== Step 1: Start Docker Stack ===" -ForegroundColor Cyan
docker compose up -d

Write-Host "`nWaiting for Oracle XE to initialize (this takes 2-3 min on first start)..."
Write-Host "Watching logs — press Ctrl+C once you see 'DATABASE IS READY TO USE!'" -ForegroundColor Yellow
docker logs -f oracle-xe

Write-Host "`n=== Step 2: Verify Oracle Tables ===" -ForegroundColor Cyan
Write-Host "Connecting to Oracle and checking table counts..."
docker exec oracle-xe bash -c "echo `"SELECT table_name FROM user_tables; SELECT COUNT(*) FROM members; SELECT COUNT(*) FROM claims; EXIT;`" | sqlplus -s 'healthcare/Healthcare1#@//localhost/XEPDB1'"

Write-Host "`n=== Step 3: Install Python Dependencies ===" -ForegroundColor Cyan
pip install oracledb pyiceberg pyarrow adlfs azure-storage-file-datalake psycopg2-binary

Write-Host "`n=== Step 4: Run the Pipeline ===" -ForegroundColor Cyan
python oracle_to_iceberg_azure.py

Write-Host "`n================================================================" -ForegroundColor Green
Write-Host "Pipeline complete." -ForegroundColor Green
Write-Host "Next: Run bigquery/create_iceberg_tables.sql in BigQuery Studio" -ForegroundColor Yellow
Write-Host "Then: Run bigquery/healthcare_queries.sql to query across clouds" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Green
