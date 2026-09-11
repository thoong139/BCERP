# Engineering - Data Engineering Patterns

> **Domain**: Engineering / Data Engineering
> **Last Updated**: 2026-03-15

---

## 1. Medallion Architecture — Mô hình Lớp

```
[Source Systems] → Bronze (raw) → Silver (cleansed) → Gold (business-ready)
     Kafka/DB          Delta Lake       Delta Lake          Delta Lake / DW
```

| Lớp | Nguyên tắc | Đặc điểm |
|-----|-----------|----------|
| **Bronze** | Raw, immutable, append-only | Không biến đổi dữ liệu gốc; ghi metadata ingest |
| **Silver** | Cleansed, deduped, conformed | Có thể join xuyên domain; dedup, normalize |
| **Gold** | Business-ready, aggregated, SLA | Tối ưu cho query patterns; consumer không đọc Bronze/Silver |

---

## 2. Pipeline PySpark + Delta Lake (Medallion)

```python
# REQ-ID: REQ-XXX
# Module: Data Pipeline
# Author: Data Engineer

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, current_timestamp, lit
from pyspark.sql.window import Window
from pyspark.sql.functions import row_number, desc
from delta.tables import DeltaTable

spark = SparkSession.builder \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

# Lớp Bronze: ingest thô, append-only, không biến đổi
def ingest_bronze(source_path: str, bronze_table: str, source_system: str) -> int:
    df = spark.read.format("json").option("inferSchema", "true").load(source_path)
    df = df.withColumn("_ingested_at", current_timestamp()) \
           .withColumn("_source_system", lit(source_system)) \
           .withColumn("_source_file", col("_metadata.file_path"))
    df.write.format("delta").mode("append").option("mergeSchema", "true").save(bronze_table)
    return df.count()

# Lớp Silver: dedup, chuẩn hóa, upsert
def upsert_silver(bronze_table: str, silver_table: str, pk_cols: list[str]) -> None:
    source = spark.read.format("delta").load(bronze_table)
    w = Window.partitionBy(*pk_cols).orderBy(desc("_ingested_at"))
    source = source.withColumn("_rank", row_number().over(w)).filter(col("_rank") == 1).drop("_rank")

    if DeltaTable.isDeltaTable(spark, silver_table):
        target = DeltaTable.forPath(spark, silver_table)
        merge_condition = " AND ".join([f"target.{c} = source.{c}" for c in pk_cols])
        target.alias("target").merge(source.alias("source"), merge_condition) \
            .whenMatchedUpdateAll() \
            .whenNotMatchedInsertAll() \
            .execute()
    else:
        source.write.format("delta").mode("overwrite").save(silver_table)

# Lớp Gold: tổng hợp theo nghiệp vụ
def build_gold_daily_revenue(silver_orders: str, gold_table: str) -> None:
    df = spark.read.format("delta").load(silver_orders)
    gold = df.filter(col("status") == "completed") \
             .groupBy("order_date", "region", "product_category") \
             .agg({"revenue": "sum", "order_id": "count"}) \
             .withColumnRenamed("sum(revenue)", "total_revenue") \
             .withColumnRenamed("count(order_id)", "order_count") \
             .withColumn("_refreshed_at", current_timestamp())
    gold.write.format("delta").mode("overwrite") \
        .option("replaceWhere", f"order_date >= '{gold['order_date'].min()}'") \
        .save(gold_table)
```

---

## 3. Kafka Streaming Pipeline (PySpark)

```python
# REQ-ID: REQ-XXX
# Module: Streaming Ingest
from pyspark.sql.functions import from_json, col, current_timestamp
from pyspark.sql.types import StructType, StringType, DoubleType, TimestampType

order_schema = StructType() \
    .add("order_id", StringType()) \
    .add("customer_id", StringType()) \
    .add("revenue", DoubleType()) \
    .add("event_time", TimestampType())

def stream_bronze_orders(kafka_bootstrap: str, topic: str, bronze_path: str):
    stream = spark.readStream \
        .format("kafka") \
        .option("kafka.bootstrap.servers", kafka_bootstrap) \
        .option("subscribe", topic) \
        .option("startingOffsets", "latest") \
        .option("failOnDataLoss", "false") \
        .load()

    parsed = stream.select(
        from_json(col("value").cast("string"), order_schema).alias("data"),
        col("timestamp").alias("_kafka_timestamp"),
        current_timestamp().alias("_ingested_at")
    ).select("data.*", "_kafka_timestamp", "_ingested_at")

    return parsed.writeStream \
        .format("delta") \
        .outputMode("append") \
        .option("checkpointLocation", f"{bronze_path}/_checkpoint") \
        .option("mergeSchema", "true") \
        .trigger(processingTime="30 seconds") \
        .start(bronze_path)
```

---

## 4. Data Quality Contract với dbt

```yaml
# models/silver/schema.yml
version: 2

models:
  - name: silver_orders
    description: "Bản ghi đơn hàng đã chuẩn hóa và loại trùng. SLA: làm mới mỗi 15 phút."
    config:
      contract:
        enforced: true
    columns:
      - name: order_id
        data_type: string
        constraints:
          - type: not_null
          - type: unique
        tests:
          - not_null
          - unique
      - name: customer_id
        data_type: string
        tests:
          - not_null
          - relationships:
              to: ref('silver_customers')
              field: customer_id
      - name: revenue
        data_type: decimal(18, 2)
        tests:
          - not_null
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
              max_value: 1000000
      - name: order_date
        data_type: date
        tests:
          - not_null
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: "'2020-01-01'"
              max_value: "current_date"
    tests:
      - dbt_utils.recency:
          datepart: hour
          field: _updated_at
          interval: 1
```

---

## 5. Validation với Great Expectations

```python
# REQ-ID: REQ-XXX
import great_expectations as gx
from datetime import datetime

context = gx.get_context()

def validate_silver_orders(df) -> dict:
    batch = context.sources.pandas_default.read_dataframe(df)
    result = batch.validate(
        expectation_suite_name="silver_orders.critical",
        run_id={"run_name": "silver_orders_daily", "run_time": datetime.now()}
    )
    stats = {
        "success": result["success"],
        "evaluated": result["statistics"]["evaluated_expectations"],
        "passed": result["statistics"]["successful_expectations"],
        "failed": result["statistics"]["unsuccessful_expectations"],
    }
    if not result["success"]:
        raise DataQualityException(
            f"Silver orders không qua validation: {stats['failed']} kiểm tra thất bại"
        )
    return stats
```

---

## 6. SCD Type 2 Pattern

Cho slowly changing dimensions (ví dụ: customer attributes thay đổi theo thời gian):

```python
# Window function phát hiện thay đổi, gắn effective_from/effective_to
from pyspark.sql.functions import col, lag, when, desc
from pyspark.sql.window import Window

w = Window.partitionBy("customer_id").orderBy(desc("change_timestamp"))
scd2_df = source.withColumn(
    "change_flag",
    when(lag("hash_value").over(w) != col("hash_value"), 1).otherwise(0)
).filter(col("change_flag") == 1)
# Thêm effective_from, effective_to, is_current cho mỗi version
```

---

## 7. Soft Delete & Audit Columns

Mọi bảng có business significance cần có:

```sql
created_at    TIMESTAMP NOT NULL DEFAULT NOW(),
updated_at    TIMESTAMP NOT NULL DEFAULT NOW(),
deleted_at    TIMESTAMP,                    -- NULL = not deleted; non-NULL = soft-deleted
source_system VARCHAR(50) NOT NULL          -- Track origin cho lineage
```

---

## 8. Null Handling Philosophy

Null handling cần có chủ ý — không cho phép null propagate ngầm:

- Mỗi nullable field trong Silver/Gold cần có quy tắc xử lý rõ ràng: impute, flag, hoặc reject
- Document null handling strategy per field trong schema.yml
- Reject hoặc quarantine rows có null trên critical fields (primary keys, foreign keys)
- Impute với giá trị mặc định có ý nghĩa cho non-critical fields (kèm flag `_is_imputed`)

---

## 9. Data Contracts & Consumer Partnership

Trước khi deploy Gold layer:
- Công bố schema contracts và SLA với consumer teams
- Contract bao gồm: schema, freshness SLA, primary keys, valid value ranges
- Breaking schema changes yêu cầu 2-tuần notice + migration period
- Track consumer NPS quarterly: "Dữ liệu có đáng tin cậy không?" (target: >= 8/10)

---

## 10. Lakehouse Patterns Nâng cao

- **Time Travel & Auditing**: Snapshot Delta/Iceberg cho truy vấn point-in-time và tuân thủ quy định
- **Row-Level Security**: Column masking và row filters cho nền tảng dữ liệu đa tenant
- **Materialized Views**: Chiến lược refresh tự động cân bằng freshness và chi phí tính toán
- **Data Mesh**: Sở hữu theo domain với federated governance và global data contracts

---

## 11. Tối ưu Hiệu năng

- **Adaptive Query Execution (AQE)**: Dynamic partition coalescing, tối ưu broadcast join
- **Z-Ordering**: Phân cụm đa chiều cho truy vấn compound filter
- **Liquid Clustering**: Tự động compaction và clustering trên Delta Lake 3.x+
- **Bloom Filters**: Bỏ qua files trên cột string cardinality cao (IDs, emails)

---

## 12. Nền tảng Cloud

| Platform | Công cụ chính |
|----------|--------------|
| **Microsoft Fabric** | OneLake, Shortcuts, Mirroring, Real-Time Intelligence, Spark notebooks |
| **Databricks** | Unity Catalog, Delta Live Tables (DLT), Workflows, Asset Bundles |
| **Azure Synapse** | Dedicated SQL pools, Serverless SQL, Spark pools, Linked Services |
| **Snowflake** | Dynamic Tables, Snowpark, Data Sharing, tối ưu chi phí theo query |
| **dbt Cloud** | Semantic Layer, Explorer, CI/CD integration, model contracts |

---

## 13. Output Templates

### Tài liệu Thiết kế Pipeline

```markdown
# Thiết kế Pipeline: [Tên Pipeline]

## REQ-ID
REQ-XXX

## Tổng quan
[Mô tả ngắn gọn mục đích pipeline]

## Sơ đồ Luồng Dữ liệu
[Source Systems] → Bronze (raw) → Silver (cleansed) → Gold (business-ready)

## Data Sources
| Nguồn | Loại | Tần suất | CDC? | SLA |
|-------|------|----------|------|-----|

## Schema Contracts
| Lớp | Table | Cột chính | Constraints |
|-----|-------|-----------|-------------|

## SLA & Monitoring
| Pipeline | Freshness SLA | Alert Threshold | Owner |
|----------|---------------|-----------------|-------|

## Lineage
[Mô tả data lineage từ source đến gold]

## Runbook
- Lỗi thường gặp: [danh sách]
- Cách khắc phục: [hướng dẫn]
- Người liên hệ: [owner]
```

---

## 14. Checklist Pipeline

- [ ] Pipeline là idempotent (chạy lại an toàn)
- [ ] Schema contracts được định nghĩa cho mọi lớp
- [ ] Data quality checks được triển khai tại Silver và Gold
- [ ] Audit columns hiện diện (`created_at`, `updated_at`, `_source_system`)
- [ ] Soft delete được triển khai cho dữ liệu quan trọng
- [ ] Pipeline observability: alerting, freshness monitoring, row count checks
- [ ] Runbook được viết cho mỗi pipeline
- [ ] Data lineage được ghi lại từ source đến Gold
- [ ] Consumer đã được thông báo về data contracts trước khi deploy
- [ ] Null handling strategy documented cho mỗi nullable field
- [ ] SCD Type 2 implemented cho slowly changing dimensions
