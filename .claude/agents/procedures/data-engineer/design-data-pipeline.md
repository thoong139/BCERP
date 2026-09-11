# Playbook: Thiết kế Data Pipeline

> **Type**: Agent Skill Playbook
> **Agent**: data-engineer
> **Triggered by**: Phase 3 khi cần thiết kế data pipeline/architecture
> **Output**: `.mc-data/docs/phase3-architecture/data-pipeline-design.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-design` khi dự án có yêu cầu data pipeline
- Khi cần thiết kế luồng dữ liệu từ nguồn đến lớp tiêu thụ
- Khi dự án dùng bất kỳ từ khóa: ETL, ELT, data lake, data warehouse, batch processing, streaming, CDC, dbt, Airflow, Spark, Medallion Architecture

---

## Procedure

### Bước 1: Đọc requirements và xác định scope

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3 (architecture), PHASE2 (functional requirements)

Cần xác định:
□ Các REQ-ID liên quan đến data pipeline
□ Nguồn dữ liệu: database, API, file, event stream, SaaS platform
□ Tần suất cập nhật mỗi nguồn (real-time / near-real-time / daily / weekly)
□ Volume ước tính: số bản ghi/ngày, kích thước file, throughput event/giây
□ Consumers của data: BI dashboard, ML model, API, report
□ SLA freshness: data cần sẵn sàng trong bao lâu sau khi nguồn cập nhật?
```

### Bước 2: Data Sources Inventory

Lập danh sách đầy đủ nguồn dữ liệu theo bảng:

```markdown
| Nguồn | Loại | Schema | Volume | Tần suất | Độ nhạy | CDC? |
|-------|------|--------|--------|----------|---------|------|
| [tên] | [DB/API/File/Stream] | [schema mô tả] | [rows/day] | [realtime/batch] | [low/med/high] | [yes/no] |
```

Với mỗi nguồn, xác định:
- Có thể CDC (Change Data Capture) hay chỉ full-load?
- Có watermark/timestamp để incremental load không?
- Giới hạn rate limit (với API sources)?
- PII hoặc sensitive data nào tồn tại?

### Bước 3: Lựa chọn Pipeline Pattern

Dựa trên latency SLA và volume, chọn pattern phù hợp:

```
BATCH (daily/hourly):
  → Dùng khi: SLA freshness > 1 giờ, volume lớn, cost optimization ưu tiên
  → Tool: dbt + Airflow/Prefect, PySpark trên Databricks/Fabric

MICRO-BATCH (minutes):
  → Dùng khi: SLA freshness 5-60 phút, cần near-real-time nhưng không full streaming
  → Tool: Spark Structured Streaming với trigger interval, Azure Event Hub

STREAMING (real-time):
  → Dùng khi: SLA freshness < 5 phút, event-driven use case
  → Tool: Kafka + Spark Structured Streaming, Azure Event Hub + Stream Analytics

HYBRID (batch + streaming):
  → Dùng khi: Historical backfill + real-time updates cùng lúc
  → Tool: Lambda Architecture hoặc Kappa Architecture
```

Ghi rõ lý do chọn pattern — WHY, không chỉ WHAT.

### Bước 4: Thiết kế Medallion Architecture

Định nghĩa 3 lớp với data contracts rõ ràng:

```
BRONZE (Raw Ingest):
  □ Schema: append-only, giữ nguyên format nguồn
  □ Metadata columns bắt buộc: _source_system, _ingestion_ts, _source_file, _batch_id
  □ Partition: theo ingestion_date để tái xử lý lịch sử tiết kiệm
  □ Schema evolution: mergeSchema=true, cảnh báo nếu column mới xuất hiện
  □ Retention policy: bao lâu giữ raw data?

SILVER (Cleanse & Conform):
  □ Deduplication: window function trên primary key + event_ts
  □ Kiểu dữ liệu: chuẩn hóa date (ISO 8601), currency (ISO 4217), country code (ISO 3166)
  □ Null handling: document strategy từng field (impute/flag/reject)
  □ SCD Type 2: áp dụng cho dimensions nào?
  □ Data quality: checks nào chạy ở lớp này?

GOLD (Business Metrics):
  □ Aggregations: theo domain, bám câu hỏi nghiệp vụ cụ thể
  □ Optimization: partition pruning, Z-order, pre-aggregation
  □ Data contract: schema, freshness SLA, owner, consumers
  □ Read access: chỉ Gold được expose cho consumers
```

### Bước 5: Ingestion Strategy

Cho từng nguồn trong inventory, thiết kế ingestion:

```
FULL LOAD:
  → Khi nào: nguồn không có watermark, volume nhỏ (< 100k rows)
  → Rủi ro: tốn chi phí khi scale, xử lý delete phức tạp
  → Giảm thiểu: schedule off-peak hours, có snapshot partition

INCREMENTAL (Watermark-based):
  → Khi nào: có updated_at hoặc created_at, nguồn lớn
  → Lưu ý: late-arriving data — cần lookback window bao lâu?
  → State: lưu last_processed_watermark vào metadata store

CDC (Change Data Capture):
  → Khi nào: cần detect DELETE, volume rất lớn, latency thấp
  → Tool: Debezium (PostgreSQL/MySQL), Azure SQL CDC, DMS
  → Handling: phân biệt INSERT/UPDATE/DELETE trong Bronze
```

### Bước 6: Transformation Logic

Thiết kế transformation từng lớp:

```
Bronze → Silver transformations:
  □ Dedup rule: GROUP BY pk ORDER BY event_ts DESC
  □ Type casting rules: mỗi field có casting logic rõ ràng
  □ Business rule validation: list các rules sẽ áp dụng
  □ Reject/quarantine logic: record không hợp lệ đi đâu?

Silver → Gold transformations:
  □ Aggregation logic: GROUP BY dimensions, metrics tính thế nào
  □ Join strategy: broadcast join vs shuffle join, tránh cartesian
  □ Slowly Changing Dimensions: SCD Type 1 vs Type 2 cho từng dimension
```

### Bước 7: Data Quality Checks

Xác định checks cho từng lớp — chạy TẠI CHỖ, không phải post-hoc:

```
SCHEMA CHECKS (Bronze):
  □ Expected columns present
  □ Critical columns not null
  □ Data types match contract

BUSINESS RULE CHECKS (Silver):
  □ Referential integrity (FK relationships)
  □ Value ranges valid (age > 0, amount ≥ 0)
  □ Enum values within expected set
  □ Duplicate rate < threshold (thường < 0.1%)

FRESHNESS CHECKS (Gold):
  □ Last updated timestamp không quá SLA window
  □ Row count không drop > X% so với run trước
  □ Null rate không tăng đột biến
```

Tool đề xuất: dbt tests (generic + singular), Great Expectations, hoặc custom PySpark assertions.

### Bước 8: Data Lineage Tracking

Thiết kế lineage tracking:

```
□ Mỗi record Gold có thể trace về Bronze gốc qua _lineage_id
□ dbt exposure và source definitions để tạo lineage graph
□ Metadata store: lưu run_id, source_row_count, output_row_count, rejection_count
□ Column-level lineage nếu downstream có compliance requirement
```

### Bước 9: Partitioning Strategy

Cho mỗi bảng quan trọng trong Medallion:

```
Bronze:
  → Partition by: ingestion_date (YYYY-MM-DD)
  → Lý do: tái xử lý lịch sử chỉ scan partition cần thiết

Silver:
  → Partition by: event_date hoặc updated_date tùy use case
  → Z-order by: columns thường dùng trong WHERE/JOIN

Gold:
  → Partition by: business date (thường là reporting_date)
  → Pre-aggregate common query patterns để giảm scan cost
```

### Bước 10: Orchestration Tool Selection

```
AIRFLOW:
  → Khi nào: complex DAG dependencies, nhiều teams dùng chung, mature ecosystem
  → Managed: MWAA (AWS), Cloud Composer (GCP), Astronomer

PREFECT:
  → Khi nào: Python-native, cần dynamic pipelines, developer experience tốt hơn Airflow
  → Managed: Prefect Cloud

DBT (với Airflow/Prefect):
  → Khi nào: transformation-heavy, SQL-based transforms, cần lineage + testing tích hợp

MICROSOFT FABRIC / ADF:
  → Khi nào: Azure ecosystem, low-code pipeline cho non-engineers, Microsoft stack

Tiêu chí chọn:
□ Team skillset: SQL heavy → dbt; Python heavy → Prefect
□ Complexity: nhiều dependencies phức tạp → Airflow
□ Cloud lock-in: Azure → Fabric/ADF; multi-cloud → Prefect/Airflow
□ Budget: self-hosted Airflow rẻ hơn nhưng ops overhead cao hơn
```

### Bước 11: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase3-architecture/data-pipeline-design.md

Cấu trúc output:
1. Executive Summary — scope pipeline, pattern đã chọn, lý do
2. Data Sources Inventory (bảng đầy đủ)
3. Pipeline Architecture Diagram (text-based nếu không có tool đồ họa)
4. Medallion Architecture: định nghĩa 3 lớp + data contracts
5. Ingestion Strategy per source
6. Transformation Logic
7. Data Quality Framework
8. Orchestration Design
9. Partitioning & Performance Strategy
10. Monitoring & Alerting Plan
11. Open Questions cho stakeholders
```

---

## Checklist trước khi submit

```
□ Mỗi pipeline có SLA freshness định nghĩa rõ
□ Mọi nguồn dữ liệu đều có ingestion strategy (full/incremental/CDC)
□ Bronze không có transformation logic
□ Silver có dedup + null handling strategy
□ Gold chỉ expose data đã có contract với consumers
□ Data quality checks được define trước, không phải sau khi build
□ Lineage tracking design đã included
□ REQ-ID được reference trong design doc
□ Orchestration tool đã chọn + lý do ghi rõ
□ Late-arriving data handling đã được address
```
