import oracledb
import pyarrow as pa
from pyiceberg.catalog.rest import RestCatalog
from datetime import datetime

ORACLE_DSN       = "localhost:1521/XEPDB1"
ORACLE_USER      = "healthcare"
ORACLE_PASSWORD  = "<YOUR_ORACLE_PASSWORD>"
ICEBERG_REST_URL = "http://localhost:8080"
S3_BUCKET        = "healthcare-lakehouse-poc-east1"
AWS_REGION       = "us-east-1"
NAMESPACE        = "healthcare"

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

def main():
    tables = ["members", "claims"]

    print("\n=== Oracle → PyIceberg → S3 (with snapshots) ===\n")

    # Connect to Iceberg REST catalog
    catalog = RestCatalog(
        name="healthcare",
        **{
            "uri": ICEBERG_REST_URL,
            "s3.endpoint": f"https://s3.{AWS_REGION}.amazonaws.com",
            "s3.region": AWS_REGION,
            "py-io-impl": "pyiceberg.io.pyarrow.PyArrowFileIO",
        }
    )

    # Ensure namespace exists
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

        # Extract from Oracle
        arrow_table = extract_table(conn, table_name)
        print(f"  Extracted {len(arrow_table)} rows from Oracle")

        # Drop existing table if exists
        try:
            catalog.drop_table(f"{NAMESPACE}.{table_name}")
            print(f"  Dropped existing table")
        except Exception:
            pass

        # Create Iceberg table with proper schema
        iceberg_table = catalog.create_table(
            identifier=f"{NAMESPACE}.{table_name}",
            schema=arrow_table.schema,
            location=f"s3://{S3_BUCKET}/{NAMESPACE}/{table_name}",
        )

        # Write data — creates proper Iceberg snapshot
        iceberg_table.overwrite(arrow_table)
        print(f"  Written to s3://{S3_BUCKET}/{NAMESPACE}/{table_name}")
        print(f"  Snapshot created!")
        print()

    conn.close()
    print("=== Done! Iceberg tables with snapshots ready for BigQuery ===")
    print(f"\nVerify:")
    print(f"  curl http://localhost:8080/v1/namespaces/{NAMESPACE}/tables")
    print(f"  aws s3 ls s3://{S3_BUCKET}/{NAMESPACE}/ --recursive")

if __name__ == "__main__":
    main()
