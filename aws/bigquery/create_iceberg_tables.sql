-- BigQuery Omni — External Iceberg tables on AWS S3
-- Dataset: <YOUR_GCP_PROJECT_ID>.healthcare_lakehouse (region: aws-us-east-1)
-- v1.metadata.json is always overwritten by oracle_to_iceberg_aws.py on each run
-- so this table definition never needs to change — it always reads the latest snapshot
-- Replace <YOUR_GCP_PROJECT_ID>, <YOUR_CONNECTION_ID>, <YOUR_S3_BUCKET> with your values

CREATE OR REPLACE EXTERNAL TABLE `<YOUR_GCP_PROJECT_ID>.healthcare_lakehouse.members`
WITH CONNECTION `projects/<YOUR_GCP_PROJECT_ID>/locations/aws-us-east-1/connections/<YOUR_CONNECTION_ID>`
OPTIONS (
  format = 'ICEBERG',
  uris = ['s3://<YOUR_S3_BUCKET>/healthcare/members/metadata/v1.metadata.json']
);

CREATE OR REPLACE EXTERNAL TABLE `<YOUR_GCP_PROJECT_ID>.healthcare_lakehouse.claims`
WITH CONNECTION `projects/<YOUR_GCP_PROJECT_ID>/locations/aws-us-east-1/connections/<YOUR_CONNECTION_ID>`
OPTIONS (
  format = 'ICEBERG',
  uris = ['s3://<YOUR_S3_BUCKET>/healthcare/claims/metadata/v1.metadata.json']
);
