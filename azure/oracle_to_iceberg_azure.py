import oracledb
import pyarrow as pa
from pyiceberg.catalog.sql import SqlCatalog
from adlfs import AzureBlobFileSystem
from datetime import datetime

ORACLE_DSN          = "localhost:1521/XEPDB1"
ORACLE_USER         = "healthcare"
ORACLE_PASSWORD     = "<YOUR_ORACLE_PASSWORD>"

# Postgres — Iceberg metadata store
PG_URI              = "postgresql+psycopg2://iceberg:<YOUR_PG_PASSWORD>@localhost:5432/iceberg_catalog"

# Azure Data Lake Storage Gen2
ADLS_ACCOUNT_NAME   = "<YOUR_ADLS_ACCOUNT_NAME>"
ADLS_ACCOUNT_KEY    = "<YOUR_ADLS_ACCOUNT_KEY>"
ADLS_CONTAINER      = "lakehouse"

NAMESPACE           = "healthcare"

def get_oracle_connection():
    return oracledb.connect(user=ORACLE_USER, password=ORACLE_PASSWORD, dsn=ORACLE_DSN)

def extract_table(conn, table_name):
    cursor = conn.cursor()
    cursor.execute(f"SELECT * FROM {table_name}")
    columns = [col[0].lower() for col in cursor.description]
    rows = cursor.fetchall()
    data = {col: [] for col in columns}
    for row in rows:
        for col, val in zip(columns, row):
            if isinstance(val, datetime):
                val = val.isoformat()
            data[col].append(val)
    arrays = [pa.array(data[col]) for col in columns]
    return pa.table(dict(zip(columns, arrays)))

def adls_location(table_name):
    return f"abfss://{ADLS_CONTAINER}@{ADLS_ACCOUNT_NAME}.dfs.core.windows.net/{NAMESPACE}/{table_name}"

def sync_bigquery_metadata(table_name, fs):
    """After each write, create v{n}.metadata.json + version-hint.text so BigQuery
    can discover the latest Iceberg snapshot via the directory URI without manual updates."""
    meta_prefix = f"{ADLS_CONTAINER}/{NAMESPACE}/{table_name}/metadata"

    all_files = fs.ls(meta_prefix, detail=False)
    meta_files = sorted([
        f for f in all_files
        if f.split("/")[-1][:5].isdigit() and f.endswith(".metadata.json")
    ])

    if not meta_files:
        return

    latest = meta_files[-1]
    version = int(latest.split("/")[-1][:5])

    fs.copy(latest, f"{meta_prefix}/v{version}.metadata.json")

    with fs.open(f"{meta_prefix}/version-hint.text", "w") as f:
        f.write(str(version))

    print(f"  BigQuery metadata synced → v{version}.metadata.json")

def main():
    tables = ["members", "claims"]

    print("\n=== Oracle → PyIceberg → ADLS Gen2 (with snapshots) ===\n")

    fs = AzureBlobFileSystem(account_name=ADLS_ACCOUNT_NAME, account_key=ADLS_ACCOUNT_KEY)

    catalog = SqlCatalog(
        name="healthcare",
        **{
            "uri": PG_URI,
            "warehouse": f"abfss://{ADLS_CONTAINER}@{ADLS_ACCOUNT_NAME}.dfs.core.windows.net/",
            "adls.account-name": ADLS_ACCOUNT_NAME,
            "adls.account-key": ADLS_ACCOUNT_KEY,
            "py-io-impl": "pyiceberg.io.fsspec.FsspecFileIO",
        }
    )

    try:
        catalog.create_namespace(NAMESPACE)
        print(f"Created namespace: {NAMESPACE}")
    except Exception:
        print(f"Namespace '{NAMESPACE}' already exists")

    print("\nConnecting to Oracle XE...")
    conn = get_oracle_connection()
    print("Connected!\n")

    for table_name in tables:
        print(f"Processing: {table_name.upper()}")

        arrow_table = extract_table(conn, table_name)
        print(f"  Extracted {len(arrow_table)} rows from Oracle")

        try:
            catalog.drop_table(f"{NAMESPACE}.{table_name}")
            print(f"  Dropped existing table")
        except Exception:
            pass

        iceberg_table = catalog.create_table(
            identifier=f"{NAMESPACE}.{table_name}",
            schema=arrow_table.schema,
            location=adls_location(table_name),
        )

        iceberg_table.overwrite(arrow_table)
        print(f"  Written to {adls_location(table_name)}")
        print(f"  Snapshot created!")

        sync_bigquery_metadata(table_name, fs)
        print()

    conn.close()
    print("=== Done! Iceberg tables with snapshots ready for BigQuery Omni ===")

if __name__ == "__main__":
    main()
