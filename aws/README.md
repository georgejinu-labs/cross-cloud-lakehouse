# AWS POC — Oracle → Iceberg → S3

Extract healthcare data from Oracle XE running on an EC2 instance and write Iceberg tables to AWS S3 via an Iceberg REST catalog.

---

## Architecture

```
Oracle XE (EC2 instance)
      │  oracledb (Python)
      ▼
PyIceberg → Iceberg REST Catalog (Docker)
      │         metadata in Postgres (Docker)
      ▼
AWS S3  s3://healthcare-lakehouse-poc-aws/
      └── healthcare/
            ├── members/
            ├── claims/
            └── prior_auth/
```

---

## Scripts

Automation scripts are in [`scripts/`](scripts/). Run them in order:

| Script | What it does |
|--------|-------------|
| `01_setup_aws.ps1` | Creates S3 bucket, blocks public access, creates IAM policy |
| `02_setup_gcp.ps1` | Creates GCP project, links billing, enables BigQuery, creates dataset |
| `03_run_pipeline.ps1` | Starts Docker stack, installs deps, runs the Python pipeline |

Update the variable block at the top of each script before running.

---

## Prerequisites

- Docker Desktop running
- Oracle XE running on an EC2 instance (`healthcare` user on `XEPDB1`)
- Python 3.9+
- AWS credentials configured (`aws configure`)

---

## Step 1 — Start the Stack

```bash
docker compose up -d
```

Services started:
- `iceberg-rest` — Iceberg REST catalog on port 8080
- `postgres` — catalog metadata store
- `minio` — local S3 emulator on port 9000 (for local dev)
- `minio-init` — creates the `warehouse` bucket

Verify:
```bash
docker compose ps
curl http://localhost:8080/v1/config
```

---

## Step 2 — Install Python Dependencies

```bash
pip install oracledb pyiceberg pyarrow boto3
```

---

## Step 3 — Run the Pipeline

```bash
python oracle_to_iceberg_aws.py
```

Or using the REST catalog directly (without MinIO):
```bash
python oracle_to_iceberg_proper.py
```

Expected output:
```
=== Oracle → AWS S3 + Iceberg REST Bridge ===

1. Connecting to Oracle XE (EC2 instance)...
   Connected!

2. Ensuring Iceberg namespace...
   Namespace 'healthcare' ready

3. Processing: MEMBERS
   Extracted 13 rows from Oracle
   Uploaded to s3://healthcare-lakehouse-poc-aws/healthcare/members/data.parquet
   Table 'healthcare.members' registered in Iceberg catalog
...
=== Done! Oracle data is in AWS S3 + Iceberg catalog ===
```

---

## Step 4 — Verify

```bash
# Iceberg catalog
curl http://localhost:8080/v1/namespaces/healthcare/tables

# S3
aws s3 ls s3://healthcare-lakehouse-poc-aws/healthcare/ --recursive
```

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `Connection refused` on port 8080 | Iceberg REST not ready — wait 10s and retry |
| `NoCredentialError` | Run `aws configure` or set `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` |
| `NoSuchBucket` | Create the S3 bucket first in your AWS account |
| Oracle `ORA-01017` | Check `ORACLE_USER` / `ORACLE_PASSWORD` in the script |
