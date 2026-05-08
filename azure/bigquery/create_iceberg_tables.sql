-- BigQuery Omni — External Iceberg tables on Azure ADLS Gen2
-- Dataset: cross-cloud-lh-azure.healthcare_lakehouse (region: azure-eastus2)
-- v1.metadata.json is always overwritten by oracle_to_iceberg_azure.py on each run
-- so this table definition never needs to change — it always reads the latest snapshot

CREATE OR REPLACE EXTERNAL TABLE `cross-cloud-lh-azure.healthcare_lakehouse.members`
WITH CONNECTION `projects/cross-cloud-lh-azure/locations/azure-eastus2/connections/healthcare-azure-conn`
OPTIONS (
  format = 'ICEBERG',
  uris = ['azure://healthcarelakehousepoc.blob.core.windows.net/lakehouse/healthcare/members/metadata/v1.metadata.json']
);

CREATE OR REPLACE EXTERNAL TABLE `cross-cloud-lh-azure.healthcare_lakehouse.claims`
WITH CONNECTION `projects/cross-cloud-lh-azure/locations/azure-eastus2/connections/healthcare-azure-conn`
OPTIONS (
  format = 'ICEBERG',
  uris = ['azure://healthcarelakehousepoc.blob.core.windows.net/lakehouse/healthcare/claims/metadata/v1.metadata.json']
);

