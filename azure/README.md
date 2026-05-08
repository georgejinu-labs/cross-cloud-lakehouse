# Azure POC — Oracle → Iceberg → ADLS Gen2 → BigQuery Omni

Extract healthcare data from Oracle XE, write Iceberg tables to Azure Data Lake Storage Gen2,
and run federated SQL queries from GCP BigQuery Omni — data never leaves Azure.

---

## Architecture

```
Oracle XE (Docker)
      │  oracledb (Python)
      ▼
PyIceberg SqlCatalog
      │  metadata → Postgres (Docker)
      │  data     → adlfs (FsspecFileIO)
      ▼
Azure ADLS Gen2
  abfss://lakehouse@<STORAGE_ACCOUNT>.dfs.core.windows.net/
      └── healthcare/
            ├── members/    ← Parquet + Iceberg metadata
            ├── claims/
            └── prior_auth/
                    │
                    ▼
         GCP BigQuery Omni (compute runs inside Azure eastus2)
         federated SQL — no data movement across clouds
```

---

## Scripts

Automation scripts are in [`scripts/`](scripts/). Run them in order:

| Script | What it does |
|--------|-------------|
| `01_setup_azure.ps1` | Creates storage account, container, AD app, service principal |
| `02_setup_gcp.ps1` | Creates GCP project, links billing, enables BigQuery, creates dataset |
| `03_grant_bigquery_access.ps1` | Adds federated credential, grants RBAC on ADLS container |
| `04_run_pipeline.ps1` | Starts Docker stack, verifies Oracle, runs the Python pipeline |

Update the variable block at the top of each script before running.

---

## Prerequisites

- Docker Desktop
- Python 3.9+
- Azure subscription
- GCP account with billing enabled
- `az` CLI, `gcloud` CLI, `bq` CLI installed

---

## Part 1 — Azure Storage Setup

### Step 1 — Create Storage Account

1. Azure Portal → **Storage accounts** → **Create**
2. Fill in:
   - **Storage account name**: `<YOUR_STORAGE_ACCOUNT>` (globally unique, lowercase, no hyphens)
   - **Region**: East US
   - **Performance**: Standard / **Redundancy**: LRS
3. **Advanced** tab → **Data Lake Storage Gen2** → tick **Enable hierarchical namespace**
   > This cannot be enabled after creation — do not skip it
4. **Review + Create** → **Create**

### Step 2 — Create Container

Storage account → **Containers** → **+ Container**
- Name: `lakehouse`
- Public access: **Private**

### Step 3 — Get Account Key

Storage account → **Security + networking** → **Access keys** → copy **key1**

### Step 4 — Allow Network Access

Storage account → **Networking** → **Public network access** → set to **Enabled from all networks**
> Lock this down after the POC

---

## Part 2 — Start the Docker Stack

The `docker-compose.yml` starts three services:
- **oracle-xe** — Oracle 21c XE with `healthcare` user and tables auto-created on first start
- **iceberg-postgres** — Postgres storing Iceberg table metadata
- **iceberg-rest** — Iceberg REST catalog on port 8080

```bash
docker compose up -d
```

Watch Oracle initialize (2–3 min on first start):
```bash
docker logs -f oracle-xe
# Wait for: DATABASE IS READY TO USE!
```

Verify Oracle tables were created by the init script:
```bash
docker exec -it oracle-xe bash
```
```bash
sqlplus 'healthcare/Healthcare1#@//localhost/XEPDB1'
```
```sql
SELECT table_name FROM user_tables;
SELECT COUNT(*) FROM members;     -- 13
SELECT COUNT(*) FROM claims;      -- 10
SELECT COUNT(*) FROM prior_auth;  -- 12
EXIT;
```

> If the init script did not run (Oracle volume already existed), manually run:
> ```bash
> docker cp oracle_setup_healthcare.sql oracle-xe:/tmp/
> docker exec -it oracle-xe bash -c "sqlplus 'healthcare/Healthcare1#@//localhost/XEPDB1' @/tmp/oracle_setup_healthcare.sql"
> ```

---

## Part 3 — Configure the Pipeline Script

Edit `oracle_to_iceberg_azure.py` and set your values:

```python
ADLS_ACCOUNT_NAME = "<YOUR_STORAGE_ACCOUNT>"
ADLS_ACCOUNT_KEY  = "<YOUR_ACCOUNT_KEY>"
ADLS_CONTAINER    = "lakehouse"
```

The Postgres and Oracle connection strings match the docker-compose defaults and do not need changes.

---

## Part 4 — Install Python Dependencies

```bash
pip install oracledb pyiceberg pyarrow adlfs azure-storage-file-datalake psycopg2-binary
```

---

## Part 5 — Run the Pipeline

```bash
python oracle_to_iceberg_azure.py
```

Expected output:
```
=== Oracle → PyIceberg → ADLS Gen2 (with snapshots) ===

Namespace 'healthcare' already exists

Connecting to Oracle XE...
Connected!

Processing: MEMBERS
  Extracted 13 rows from Oracle
  Dropped existing table
  Written to abfss://lakehouse@<STORAGE_ACCOUNT>.dfs.core.windows.net/healthcare/members
  Snapshot created!
  BigQuery metadata synced → v1.metadata.json

Processing: CLAIMS
  ...

Processing: PRIOR_AUTH
  ...

=== Done! Iceberg tables with snapshots ready for BigQuery Omni ===
```

After each run, `v1.metadata.json` is overwritten with the latest Iceberg snapshot —
BigQuery always reads current data without any table redefinition.

---

## Part 6 — BigQuery Omni Setup (cross-cloud federated query)

### Step 1 — Create GCP Project

```bash
gcloud projects create <YOUR_GCP_PROJECT_ID> \
  --name="Cross Cloud Lakehouse" \
  --organization=<YOUR_GCP_ORG_ID>

gcloud config set project <YOUR_GCP_PROJECT_ID>

gcloud billing projects link <YOUR_GCP_PROJECT_ID> \
  --billing-account=<YOUR_BILLING_ACCOUNT_ID>

gcloud services enable bigquery.googleapis.com
```

### Step 2 — Create BigQuery Dataset in Azure Region

```bash
bq mk --location=azure-eastus2 --dataset <YOUR_GCP_PROJECT_ID>:healthcare_lakehouse
```

> The dataset **must** be in `azure-eastus2` — this is where BigQuery Omni compute runs inside Azure.

### Step 3 — Create an Azure AD App Registration

```bash
az ad app create --display-name "bigquery-omni-healthcare"
# Note the appId from the output → this is your <AZURE_APP_CLIENT_ID>
```

### Step 4 — Create BigQuery Connection to Azure

In BigQuery Studio → **+ Add** → **Connections to external data sources**:

| Field | Value |
|-------|-------|
| Connection type | Lakehouse on Azure (via BigQuery Omni) |
| Connection ID | `healthcare-azure-conn` |
| Location | `azure-eastus2` |
| Identity type | Federated identity |
| Tenant ID | `<YOUR_AZURE_TENANT_ID>` → get via `az account show --query tenantId -o tsv` |
| Azure federated application (client) ID | `<AZURE_APP_CLIENT_ID>` from Step 3 |

After creation BigQuery shows a **BigQuery Google identity** number → copy it as `<BIGQUERY_GOOGLE_IDENTITY>`.

### Step 5 — Configure Azure to Trust BigQuery's Identity

```bash
# Add federated credential so Azure trusts GCP's OIDC token
az ad app federated-credential create \
  --id <AZURE_APP_CLIENT_ID> \
  --parameters '{
    "name": "bigquery-omni-fed",
    "issuer": "https://accounts.google.com",
    "subject": "<BIGQUERY_GOOGLE_IDENTITY>",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create a service principal for the app
az ad sp create --id <AZURE_APP_CLIENT_ID>

# Grant Storage Blob Data Reader on the lakehouse container
az role assignment create \
  --assignee <AZURE_APP_CLIENT_ID> \
  --role "Storage Blob Data Reader" \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/<YOUR_RESOURCE_GROUP>/providers/Microsoft.Storage/storageAccounts/<YOUR_STORAGE_ACCOUNT>/blobServices/default/containers/lakehouse"
```

> Wait 1–2 minutes for RBAC to propagate before creating BigQuery tables.

### Step 6 — Create External Iceberg Tables

Run `bigquery/create_iceberg_tables.sql` in BigQuery Studio
(update `<YOUR_GCP_PROJECT_ID>` and `<YOUR_STORAGE_ACCOUNT>` placeholders first).

The URI points to `v1.metadata.json` — updated automatically on every pipeline run:
```sql
OPTIONS (
  format = 'ICEBERG',
  uris = ['azure://<YOUR_STORAGE_ACCOUNT>.blob.core.windows.net/lakehouse/healthcare/members/metadata/v1.metadata.json']
)
```

### Step 7 — Run Federated Queries

Run `bigquery/healthcare_queries.sql` in BigQuery Studio.
BigQuery Omni executes the query inside Azure — the Parquet files never leave ADLS Gen2.

---

## Updating Data

Whenever Oracle data changes:

1. Insert/update rows in Oracle:
   ```bash
   docker exec -it oracle-xe bash
   sqlplus 'healthcare/Healthcare1#@//localhost/XEPDB1'
   ```
2. Re-run the pipeline:
   ```bash
   python oracle_to_iceberg_azure.py
   ```
3. Query BigQuery — new data is immediately visible, no table changes needed.

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| Oracle `ORA-01017` | Password has special chars — use `bash -c "sqlplus '...'"` |
| Oracle tables missing after first start | Run `oracle_setup_healthcare.sql` manually (see Part 2) |
| `psycopg2.OperationalError: Connection refused` | Postgres port 5432 not exposed — check `docker-compose.yml` |
| `adlfs` write error | Verify `ADLS_ACCOUNT_KEY` in the script |
| BigQuery `Not found: Files` | Run the pipeline first so `v1.metadata.json` exists |
| BigQuery `Access Denied` | RBAC not propagated — wait 2 min and retry |
| BigQuery `Not found: Connection` | Connection location must be exactly `azure-eastus2` |
| BigQuery `OMNI_NOT_AVAILABLE` | Dataset must be in `azure-eastus2`, not `us` or `US` |
