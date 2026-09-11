# Playbook: Implement ETL/ELT Pipeline

> **Type**: Agent Skill Playbook
> **Agent**: data-engineer
> **Triggered by**: `/wf-implement-feature` khi implement ETL/ELT pipeline
> **Output**: ETL/ELT pipeline implementation code + documentation

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-implement-feature` cho feature liên quan đến data pipeline
- Khi cần viết code ingestion, transformation, hoặc load cho Medallion Architecture
- Khi cần implement dbt models, PySpark jobs, hoặc Airflow/Prefect DAGs

---

## Procedure

### Bước 1: Đọc Pipeline Design

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3 (architecture), PHASE5 (implementation tasks)

Cần đọc và ghi nhớ:
□ .mc-data/docs/phase3-architecture/data-pipeline-design.md
□ .mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md
□ REQ-IDs được gán cho feature đang implement
□ Data contracts: schema, SLA, owner, consumers
□ Lớp Medallion cần implement: Bronze / Silver / Gold
□ Ingestion pattern: full load / incremental / CDC
□ Orchestration tool đã được chọn trong design
```

Không implement trước khi đọc design doc — thiết kế là source of truth.

### Bước 2: Source Connector Setup

Tùy loại nguồn dữ liệu:

```
DATABASE (PostgreSQL, MySQL, SQL Server):
  □ Connection string qua environment variable — KHÔNG hardcode
  □ Dùng connection pool, không single connection
  □ Service account riêng cho pipeline với quyền READ-ONLY trên nguồn
  □ SSL/TLS enabled cho mọi kết nối production
  □ Kiểm tra CDC enable chưa (nếu dùng CDC pattern)

REST API:
  □ Authentication: OAuth2 token từ secret manager, không từ env plain text
  □ Rate limit handling: exponential backoff, retry với jitter
  □ Pagination: cursor-based pagination ưu tiên hơn offset pagination
  □ Timeout: set connect_timeout và read_timeout riêng

FILE (CSV, Parquet, JSON, AVRO):
  □ Schema inference chỉ dùng khi prototyping — production phải có explicit schema
  □ Corrupt file handling: skip + log hoặc quarantine
  □ File pattern matching: glob pattern để tránh đọc partial file (đang ghi)

EVENT STREAM (Kafka):
  □ Consumer group ID naming convention: [pipeline-name]-[env]
  □ Auto-offset-reset=earliest cho initial load, latest cho steady-state
  □ Exactly-once semantics nếu tính idempotency quan trọng
  □ Dead letter topic cho poison messages
```

### Bước 3: Extraction Logic

```
FULL LOAD:
  □ SELECT * với explicit column list — không SELECT *
  □ Query hint nếu cần: NOLOCK (SQL Server), READ COMMITTED SNAPSHOT
  □ Batch fetch: fetchsize/chunk_size để tránh OOM
  □ Log row count extracted

INCREMENTAL (Watermark-based):
  □ Load last_watermark từ metadata store (không hardcode)
  □ Query: WHERE updated_at > last_watermark AND updated_at <= current_run_ts
  □ Lookback window: lookback = last_watermark - buffer (thường 10-30 phút cho late-arriving data)
  □ Save new_watermark = current_run_ts SAU KHI load thành công
  □ Log: start_watermark, end_watermark, rows_extracted

CDC (Debezium / native CDC):
  □ Capture INSERT, UPDATE, DELETE events
  □ Preserve op_type field trong Bronze
  □ Handle schema evolution events từ CDC log
  □ Checkpoint offset sau mỗi batch thành công
```

### Bước 4: Data Validation tại Source

Validate trước khi ghi vào Bronze — sớm hơn là tốt hơn:

```python
# REQ-ID: [REQ-ID-TƯƠNG-ỨNG]
# Validation tại điểm extraction — fail fast, không để garbage vào Bronze

SCHEMA VALIDATION:
  □ Expected columns có đủ không?
  □ Critical NOT NULL columns có null không?
  □ Data type có khớp không? (int field nhận string → schema drift)

VOLUME VALIDATION:
  □ Extracted row count > 0 (cảnh báo nếu 0 hàng — có thể nguồn có vấn đề)
  □ Row count không drop > 30% so với run trước (cảnh báo, không block)

SANITY CHECKS:
  □ Timestamp columns: không có timestamp trong tương lai > 1 ngày
  □ Numeric columns: không có giá trị âm cho trường phải dương (amount, quantity)
```

Nếu validation critical fail → raise exception, không tiếp tục. Ghi lỗi vào dead letter store.

### Bước 5: Transformation Code

**Bronze Layer — giữ nguyên, thêm metadata:**

```python
# REQ-ID: [REQ-ID-TƯƠNG-ỨNG]
# Bronze: append-only, không biến đổi dữ liệu gốc

from datetime import datetime

def add_bronze_metadata(df, source_system: str, batch_id: str):
    """
    WHY: Bronze cần audit trail đầy đủ để tái xử lý lịch sử khi cần.
    Không modify source data — chỉ thêm metadata columns.
    """
    return df.withColumn("_source_system", lit(source_system)) \
             .withColumn("_ingestion_ts", lit(datetime.utcnow())) \
             .withColumn("_batch_id", lit(batch_id)) \
             .withColumn("_ingestion_date", current_date())  # partition column
```

**Silver Layer — dedup, cleanse, conform:**

```python
# REQ-ID: [REQ-ID-TƯƠNG-ỨNG]
# Silver: cleanse + deduplicate, đưa về schema chuẩn

def deduplicate_by_primary_key(df, pk_columns: list, event_ts_column: str):
    """
    WHY: Window function giữ record mới nhất theo event timestamp.
    Đảm bảo idempotency — chạy lại cho cùng kết quả.
    """
    from pyspark.sql.window import Window
    from pyspark.sql.functions import row_number

    window = Window.partitionBy(pk_columns).orderBy(col(event_ts_column).desc())
    return df.withColumn("_row_num", row_number().over(window)) \
             .filter(col("_row_num") == 1) \
             .drop("_row_num")
```

**Gold Layer — aggregation theo business domain:**

```python
# REQ-ID: [REQ-ID-TƯƠNG-ỨNG]
# Gold: business metrics, tối ưu cho query patterns

def build_daily_sales_summary(silver_orders_df, silver_products_df):
    """
    WHY: Pre-aggregate daily để BI tool không cần scan full Silver.
    Partition by reporting_date để query theo date range efficient.
    """
    # Viết transformation logic cụ thể ở đây
    pass
```

### Bước 6: Data Quality Tests

Implement tests SONG SONG với transformation — không phải sau:

```
DBT TESTS (nếu dùng dbt):
  □ not_null: critical columns
  □ unique: primary key của mỗi model
  □ accepted_values: enum fields
  □ relationships: FK references
  □ Custom singular tests cho business rules

PYSPARK ASSERTIONS:
  □ assert df.filter(col("pk").isNull()).count() == 0
  □ assert df.count() > 0
  □ assert df.filter(col("amount") < 0).count() == 0

GREAT EXPECTATIONS:
  □ expect_column_values_to_not_be_null
  □ expect_column_values_to_be_between
  □ expect_table_row_count_to_be_between
```

Test failure strategy:
- Critical test fail → raise exception, không ghi Gold
- Warning test fail → log cảnh báo, ghi Gold nhưng đánh flag quality_score

### Bước 7: Load Strategy

```
OVERWRITE (Idempotent Full Refresh):
  → Khi nào: Gold aggregations nhỏ, cần đảm bảo consistency tuyệt đối
  → Cách làm: write to temp table/partition → swap atomically
  → Rủi ro: downtime ngắn khi swap — dùng partition overwrite để giảm

APPEND (Event tables, Bronze):
  → Khi nào: Bronze layer, event log, immutable records
  → Lưu ý: không dùng cho tables có update/delete

UPSERT (MERGE):
  → Khi nào: Silver layer, cần handle UPDATE + DELETE từ CDC
  → Delta Lake: MERGE INTO với ON pk_match
  → Đảm bảo MERGE condition trên partition column để tối ưu
  → Test idempotency: chạy lại cùng batch → row count không tăng

PARTITION OVERWRITE:
  → Khi nào: daily/hourly partitioned tables
  → Spark config: spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")
  → Chỉ overwrite partition cần thiết, không toàn bộ table
```

### Bước 8: Error Handling và Dead Letter Queue

```python
# REQ-ID: [REQ-ID-TƯƠNG-ỨNG]
# WHY: Silent failure là kẻ thù của data reliability.
# Mọi lỗi phải được capture, classify, và route đúng.

DEAD LETTER QUEUE DESIGN:
  □ Schema: {record_id, original_payload, error_type, error_message, failed_at, pipeline_name, stage}
  □ Error types: SCHEMA_MISMATCH, NULL_VIOLATION, BUSINESS_RULE_VIOLATION, SOURCE_UNAVAILABLE
  □ Retention: 30 ngày để reprocess hoặc audit

RETRY STRATEGY:
  □ Transient errors (network, timeout): retry 3 lần với exponential backoff
  □ Permanent errors (schema mismatch, constraint violation): không retry → dead letter
  □ Partial failure: ghi thành công records, dead letter failed records — không atomic fail toàn batch

ALERTING:
  □ Pipeline failure → alert trong 5 phút qua Teams/Slack/PagerDuty
  □ DLQ row count tăng > threshold → alert on-call
  □ Freshness SLA breach → alert consumers
```

### Bước 9: Monitoring và Alerting

```
PIPELINE METRICS cần log:
  □ run_id, pipeline_name, started_at, completed_at, duration_seconds
  □ source_row_count, extracted_row_count, transformed_row_count, loaded_row_count
  □ rejected_row_count, dlq_row_count
  □ quality_check_pass_count, quality_check_fail_count
  □ watermark_start, watermark_end (cho incremental)

FRESHNESS MONITORING:
  □ Sau mỗi Gold run thành công: UPDATE metadata store với last_successful_run = NOW()
  □ Monitoring job (chạy riêng): nếu NOW() - last_successful_run > SLA_threshold → alert

ROW COUNT ANOMALY:
  □ So sánh row count hiện tại với moving average 7 ngày
  □ Nếu drop > 30% hoặc spike > 200% → alert (có thể là upstream issue)

SCHEMA DRIFT:
  □ Detect new/removed/type-changed columns so với expected schema
  □ Log + alert, không silently accept
```

### Bước 10: REQ-ID Reference

```python
# Mọi file code phải có REQ-ID reference ở đầu file
# REQ-ID: REQ-[DEPT]-[NNN] hoặc REQ-[SYSTEM]-[MODULE]-[NNN]
# FEAT-ID: FEAT-[MODULE]-[NNN]

"""
Module: [tên pipeline]
REQ-ID: REQ-DATA-PIPE-001
FEAT-ID: FEAT-INGEST-001
Mô tả: [mô tả ngắn gọn pipeline này làm gì]
"""
```

### Bước 11: Output

```
Ghi code vào cấu trúc thư mục phù hợp với project:
  Monorepo: apps/backend/data-pipelines/ hoặc apps/data/
  Standalone: src/pipelines/

Cấu trúc thư mục gợi ý:
  pipelines/
  ├── bronze/
  │   └── [source_name]_ingestion.py
  ├── silver/
  │   └── [domain]_cleanse.py (hoặc dbt models/silver/)
  ├── gold/
  │   └── [metric_name]_aggregation.py (hoặc dbt models/gold/)
  ├── common/
  │   ├── connectors.py
  │   ├── quality_checks.py
  │   └── metadata_store.py
  ├── dags/
  │   └── [pipeline_name]_dag.py
  └── tests/
      └── test_[module]_pipeline.py
```

---

## Checklist trước khi submit

```
□ REQ-ID reference trong tất cả code files
□ Không có hardcoded credentials, connection strings, hoặc API keys
□ Pipeline idempotent — test bằng cách chạy lại cùng batch
□ Dead letter queue setup cho error records
□ Monitoring metrics được log đầy đủ
□ Alert trigger được define (freshness SLA, row count anomaly, pipeline failure)
□ Data quality tests implemented song song với transformation
□ Bronze không có transformation — append-only, metadata only
□ Unit tests cho transformation functions (coverage > 80%)
□ README hoặc runbook: mô tả pipeline, dependencies, cách reprocess, owner
```
