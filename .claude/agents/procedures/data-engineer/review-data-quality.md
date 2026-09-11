# Playbook: Review Data Quality

> **Type**: Agent Skill Playbook
> **Agent**: data-engineer
> **Triggered by**: Data quality review của pipeline hoặc dataset — gọi định kỳ hoặc khi có sự cố
> **Output**: Data quality review report

---

## Khi nào dùng playbook này

- Review định kỳ sau khi pipeline đã chạy production một thời gian
- Khi consumer báo cáo anomaly trong data
- Khi cần audit data quality trước khi bàn giao cho ML team hoặc analytics
- Sau major schema change hoặc upstream system migration

---

## Procedure

### Bước 1: Đọc context và xác định scope review

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE3 (data pipeline design), PHASE5 (implementation)

Cần xác định:
□ Dataset nào cần review? (Bronze / Silver / Gold / cụ thể bảng nào)
□ Time range cần review (tuần trước? tháng trước? từ khi deploy?)
□ Consumer của dataset là ai? (BI / ML / API)
□ SLA đã cam kết với consumers là gì?
□ Có incidents gần đây không?
```

### Bước 2: Schema Validation

Kiểm tra schema thực tế so với data contract đã định nghĩa:

```
□ Tất cả expected columns có đủ không?
□ Có columns mới xuất hiện không có trong contract? (schema drift)
□ Có columns bị mất so với contract?
□ Data types có khớp contract không?
  → Date/timestamp: đúng timezone? đúng format?
  → Numeric: đúng precision? có bị cast mất dữ liệu không?
  → String: có truncation không? encoding issue?

CÁCH KIỂM TRA:
  SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'X'
  So sánh với schema.yml hoặc data contract document
```

Ghi nhận: [Column] — [Kỳ vọng] — [Thực tế] — [Tác động]

### Bước 3: Null và Missing Values Analysis

```
Với mỗi critical column (NOT NULL theo contract):
  □ Null rate (%) trong 30 ngày gần nhất
  □ Null rate có tăng theo thời gian không? (trend)
  □ Null tập trung vào ngày nào? (có thể chỉ ra upstream issue)

THRESHOLDS THÔNG THƯỜNG:
  Critical PK/FK: null rate = 0%
  Required business fields: null rate < 0.1%
  Optional fields: null rate documented, không trend tăng

QUERY MẪU:
  SELECT
    COUNT(*) as total,
    SUM(CASE WHEN critical_col IS NULL THEN 1 ELSE 0 END) as null_count,
    ROUND(100.0 * SUM(CASE WHEN critical_col IS NULL THEN 1 ELSE 0 END) / COUNT(*), 4) as null_pct
  FROM table
  WHERE partition_date >= DATEADD(day, -30, GETDATE())
```

### Bước 4: Duplicate Records Analysis

```
DEDUPLICATION VERIFICATION:
  □ Có duplicate trên primary key không?
  □ Duplicate rate là bao nhiêu?
  □ Duplicate tập trung trong time range nào? (có thể chỉ ra double-run)

QUERY MẪU:
  SELECT pk_col, COUNT(*) as cnt
  FROM silver_table
  GROUP BY pk_col
  HAVING COUNT(*) > 1
  ORDER BY cnt DESC
  LIMIT 100;

  -- Row count vs distinct PK count
  SELECT COUNT(*) as total_rows, COUNT(DISTINCT pk_col) as distinct_pks
  FROM silver_table;

PHÂN LOẠI DUPLICATE:
  - Exact duplicate (same data, same timestamp): pipeline bug, double-write
  - Near duplicate (same PK, different timestamps): CDC events, cần window dedup
  - Semantic duplicate (khác PK nhưng cùng entity): cần business rule
```

### Bước 5: Business Rule Violations

```
Kiểm tra các business rules đã defined trong design:

VÍ DỤ CHECKS PHỔ BIẾN:
  □ amount >= 0 cho financial tables
  □ quantity > 0 cho order lines
  □ start_date <= end_date cho date ranges
  □ status IN ('active', 'inactive', 'pending') cho enum fields
  □ FK references hợp lệ (customer_id có tồn tại trong customers table)
  □ Cross-table consistency (order total = sum of order lines)

QUERY MẪU:
  SELECT 'amount_negative' as rule, COUNT(*) as violation_count
  FROM orders WHERE amount < 0
  UNION ALL
  SELECT 'invalid_status', COUNT(*)
  FROM orders WHERE status NOT IN ('active','inactive','pending');

Ghi nhận tất cả violations + volume + sample records
```

### Bước 6: Referential Integrity

```
□ FK → PK: mọi FK reference có tồn tại trong parent table không?
□ Orphaned records: có records không có parent không?
□ Circular references: nếu có hierarchy, có cycle không?

QUERY MẪU:
  SELECT COUNT(*) as orphaned_count
  FROM order_lines ol
  LEFT JOIN orders o ON ol.order_id = o.order_id
  WHERE o.order_id IS NULL;

HÀNH ĐỘNG:
  - Orphaned < 0.01%: log warning, track trend
  - Orphaned > 0.1%: alert, investigate upstream
  - Orphaned > 1%: block Gold load, escalate
```

### Bước 7: Statistical Anomalies

```
ROW COUNT TREND:
  □ Vẽ (text-based) row count theo ngày 30 ngày gần nhất
  □ Có ngày nào row count = 0 không? (missed run hoặc source down)
  □ Có spike bất thường không? (double load)
  □ Trend: stable / growing / declining?

DISTRIBUTION MONITORING:
  □ Numeric columns: min, max, mean, stddev, percentiles (P5, P25, P50, P75, P95)
  □ So sánh với baseline (30 ngày trước)
  □ Nếu mean thay đổi > 2 stddev so với baseline → investigate

CATEGORICAL COLUMNS:
  □ Top 10 values và tỷ lệ
  □ Có giá trị mới xuất hiện không mong đợi?
  □ Có giá trị cũ biến mất không?
```

### Bước 8: Late-Arriving Data Handling

```
□ Có records với event_ts < (current_run_ts - SLA_window) không?
□ Volume late-arriving records là bao nhiêu? Trend như thế nào?
□ Pipeline có lookback window đủ rộng để capture late data không?
□ Gold aggregations có bị ảnh hưởng bởi late-arriving data không?

METRICS:
  - Late arrival rate (%) = late records / total records
  - Average late arrival time (minutes)
  - P95 late arrival time (minutes)
  - Lookback window hiện tại có bao phủ P95 không?

HÀNH ĐỘNG:
  - Late rate < 0.1%: acceptable, document
  - Late rate 0.1%-1%: review lookback window
  - Late rate > 1%: redesign ingestion strategy hoặc accept eventual consistency
```

### Bước 9: Data Freshness SLA

```
□ Thời điểm data mới nhất trong Gold: MAX(updated_at) hoặc MAX(partition_date)
□ So sánh với SLA đã cam kết
□ Lịch sử freshness 30 ngày: có bao nhiêu lần breach SLA?
□ Breach pattern: thứ mấy? giờ nào? (có thể chỉ ra scheduling issue)

QUERY MẪU:
  SELECT
    MAX(updated_at) as latest_data,
    DATEDIFF(minute, MAX(updated_at), GETDATE()) as minutes_behind,
    CASE WHEN DATEDIFF(minute, MAX(updated_at), GETDATE()) > [SLA_minutes]
         THEN 'BREACH' ELSE 'OK' END as sla_status
  FROM gold_table;
```

### Bước 10: Data Lineage Completeness

```
□ Mỗi Gold record có thể trace về Bronze source không?
□ _lineage_id hoặc _batch_id có populated không?
□ dbt lineage graph có accurate không? (sources → staging → marts)
□ Column-level lineage: nếu compliance yêu cầu, có document đầy đủ không?
□ Transformation logic có documented trong dbt descriptions hoặc comments không?
```

### Bước 11: Incident Response cho Data Issues

```
Nếu phát hiện issues nghiêm trọng trong review:

PHÂN LOẠI MỨC ĐỘ:
  P1 (Critical): PII leak, data loss, Gold consumers bị ảnh hưởng
    → Alert ngay, stop downstream consumption, escalate
  P2 (High): Freshness breach > 2x SLA, duplicate rate > 0.5%
    → Alert on-call, investigate trong 1 giờ
  P3 (Medium): Business rule violations < 1%, schema drift minor
    → Create ticket, fix trong sprint hiện tại
  P4 (Low): Minor anomalies, trend warnings
    → Document, monitor, backlog

RUNBOOK CHO MỖI ISSUE:
  1. Xác định root cause (upstream? pipeline? schema change?)
  2. Đánh giá tác động (consumers nào bị ảnh hưởng?)
  3. Thông báo consumers (nếu P1/P2)
  4. Fix: reprocess từ Bronze nếu cần
  5. Validate sau fix
  6. Post-mortem nếu P1/P2
```

### Bước 12: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase3-architecture/data-quality-review-[date].md

Cấu trúc output:
1. Executive Summary
   - Tổng thể: PASS / WARNING / FAIL
   - Số issues phát hiện theo severity
   - Recommendation ngắn gọn

2. Schema Validation Results
3. Null & Missing Values Report
4. Duplicate Analysis
5. Business Rule Violation Report
6. Referential Integrity Check
7. Statistical Anomaly Report
8. Late-Arriving Data Analysis
9. Freshness SLA Report
10. Data Lineage Completeness
11. Action Items (có owner, deadline, priority)
```

---

## Checklist trước khi submit

```
□ Mọi bảng trong scope đã được review
□ Mỗi finding có: mô tả, volume/rate, sample records, severity
□ SLA freshness đã so sánh với cam kết thực tế
□ Issues được phân loại P1/P2/P3/P4
□ Action items có owner và deadline
□ Trend analysis đã bao gồm (không chỉ snapshot 1 ngày)
□ Consumer impact đã assessed
□ Recommendations có actionable next steps
```
