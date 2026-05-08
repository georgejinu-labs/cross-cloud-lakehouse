import pyarrow as pa
import pyarrow.parquet as pq
import oracledb
import requests
import boto3
import tempfile
import os
from datetime import datetime

ORACLE_DSN       = "localhost:1521/XEPDB1"
ORACLE_USER      = "healthcare"
ORACLE_PASSWORD  = "<YOUR_ORACLE_PASSWORD>"
ICEBERG_REST_URL = "http://localhost:8080"
S3_BUCKET        = "healthcare-lakehouse-poc-aws"
AWS_REGION       = "us-east-2"
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

def upload_to_s3(table, table_name):
    s3 = boto3.client('s3', region_name=AWS_REGION)
    path = os.path.join(tempfile.gettempdir(), f"{table_name}.parquet")
    pq.write_table(table, path)
    s3_key = f"{NAMESPACE}/{table_name}/data.parquet"
    s3.upload_file(path, S3_BUCKET, s3_key)
    os.remove(path)
    print(f"  Uploaded to s3://{S3_BUCKET}/{s3_key}")
    return s3_key

def ensure_namespace():
    r = requests.post(
        f"{ICEBERG_REST_URL}/v1/namespaces",
        json={"namespace": [NAMESPACE], "properties": {"owner": "healthcare-poc"}}
    )
    if r.status_code in (200, 409):
        print(f"  Namespace '{NAMESPACE}' ready")
    else:
        print(f"  Namespace error: {r.status_code} {r.text}")

def register_iceberg_table(table_name, arrow_table):
    fields = []
    for i, field in enumerate(arrow_table.schema):
        iceberg_type = "string"
        if pa.types.is_int64(field.type) or pa.types.is_int32(field.type):
            iceberg_type = "long"
        elif pa.types.is_float64(field.type) or pa.types.is_decimal(field.type):
            iceberg_type = "double"
        fields.append({
            "id": i+1,
            "name": field.name,
            "type": iceberg_type,
            "required": False
        })

    payload = {
        "name": table_name,
        "schema": {
            "type": "struct",
            "schema-id": 0,
            "fields": fields
        },
        "location": f"s3://{S3_BUCKET}/{NAMESPACE}/{table_name}",
        "properties": {
            "source": "oracle-xe",
            "created-at": datetime.utcnow().isoformat()
        }
    }

    r = requests.post(
        f"{ICEBERG_REST_URL}/v1/namespaces/{NAMESPACE}/tables",
        json=payload,
        headers={"Content-Type": "application/json"}
    )
    if r.status_code in (200, 201, 409):
        print(f"  Table '{NAMESPACE}.{table_name}' registered in Iceberg catalog")
    else:
        print(f"  Table error: {r.status_code} {r.text}")

def main():
    tables = ["members", "claims"]

    print("\n=== Oracle → AWS S3 + Iceberg REST Bridge ===\n")

    print("1. Connecting to Oracle XE...")
    conn = get_oracle_connection()
    print("   Connected!\n")

    print("2. Ensuring Iceberg namespace...")
    ensure_namespace()
    print()

    for table_name in tables:
        print(f"3. Processing: {table_name.upper()}")
        arrow_table = extract_table(conn, table_name)
        print(f"   Extracted {len(arrow_table)} rows from Oracle")
        upload_to_s3(arrow_table, table_name)
        register_iceberg_table(table_name, arrow_table)
        print()

    conn.close()

    print("=== Done! Oracle data is in AWS S3 + Iceberg catalog ===")
    print(f"\nVerify tables:")
    print(f"  curl http://localhost:8080/v1/namespaces/{NAMESPACE}/tables")
    print(f"\nVerify S3:")
    print(f"  aws s3 ls s3://{S3_BUCKET}/{NAMESPACE}/ --recursive")

if __name__ == "__main__":
    main()