# Playbook: Thiết kế Reporting Module

> **Type**: Agent Procedure
> **Agent**: data-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi cần design operational reporting
> **Output**: Feature spec cho reporting module tại `.mc-data/docs/phase2-features/`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-define-features` hoặc `/wf-design`
- Khi project cần operational reporting (báo cáo tác nghiệp hàng ngày/tuần/tháng)
- Khi cần thiết kế standard report catalog với export và scheduling
- Phân biệt với `design-bi-dashboard.md`: playbook này dành cho báo cáo dạng bảng/list — không phải dashboard KPI

---

## Procedure

### Bước 1: Đọc requirements & context

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE1, PHASE2

Cần xác định:
□ analytics-requirements.md đã có chưa? → Đọc để lấy REQ-DATA-RPT-xxx
□ Departments nào cần báo cáo? → Sales / Finance / Operations / HR?
□ Frequency: Daily / Weekly / Monthly / On-demand?
□ Audience: Internal chỉ, hay gửi ra ngoài (khách hàng, đối tác)?
```

### Bước 2: Standard Report Catalog

```
READ: .claude/references/team-expert/data/analytics-framework.md → Use Cases by Domain

Với mỗi department, liệt kê standard reports:

Finance:
□ Báo cáo doanh thu theo kỳ (ngày/tuần/tháng/năm)
□ Báo cáo chi phí theo danh mục
□ Báo cáo công nợ phải thu/phải trả
□ Báo cáo so sánh ngân sách vs thực tế

Sales:
□ Báo cáo doanh số theo nhân viên/khu vực/sản phẩm
□ Báo cáo pipeline cơ hội
□ Báo cáo hoạt động bán hàng (cuộc gọi, demo, proposal)

Operations:
□ Báo cáo tồn kho
□ Báo cáo đơn hàng (trạng thái, SLA)
□ Báo cáo hiệu suất sản xuất

Với mỗi report: xác định columns, filters, sort order mặc định
```

### Bước 3: Report Parameters & Filters

```
Với mỗi report trong catalog:
□ Bộ lọc bắt buộc: Date range (từ ngày - đến ngày)
□ Bộ lọc tùy chọn: Department, Region, Product category, Status
□ Group by options: Theo ngày / tuần / tháng / quý / năm
□ Comparison: So với kỳ trước / cùng kỳ năm ngoái (YoY)

Thiết kế UX filter panel: ưu tiên pre-set ranges (Hôm nay, 7 ngày, 30 ngày, Tháng này, Quý này)
```

### Bước 4: Scheduling & Distribution

```
□ Scheduled delivery: Email báo cáo tự động (daily/weekly/monthly)
□ Recipients: Cố định hay có thể cấu hình?
□ Trigger: Theo lịch cố định hay theo sự kiện (vd: cuối tháng)?
□ Format gửi: Inline trong email hay file đính kèm?
□ Timezone: Báo cáo chạy theo timezone nào?
□ Failure handling: Thông báo khi báo cáo lỗi?
```

### Bước 5: Export Formats

```
□ PDF: Báo cáo in ấn, gửi khách hàng — cần template/branding
□ Excel (.xlsx): Phân tích thêm — cần giữ số liệu raw, không merge cells
□ CSV: Import vào tool khác — UTF-8 encoding, separator options
□ Google Sheets: Real-time sync nếu dùng Google Workspace

Lưu ý: PDF cần thiết kế layout phù hợp với khổ A4
```

### Bước 6: Access Controls per Report

```
READ: .claude/references/team-expert/data/analytics-framework.md → Data Requirements Checklist

□ Report visibility: Ai được xem report nào? (role-based)
□ Data masking: Có field nào cần ẩn theo role không? (vd: lương, giá vốn)
□ Row-level security: User A chỉ thấy dữ liệu của khu vực A?
□ Audit log: Có cần track ai xem report nào không?
```

### Bước 7: Caching Strategy cho Heavy Reports

```
Xác định reports nào tốn tài nguyên (>10,000 rows, join nhiều bảng):
□ Pre-computed: Chạy sẵn vào giờ thấp tải (2-4 AM), cache kết quả
□ Incremental refresh: Chỉ tính phần mới thêm vào
□ Async generation: User request → job queue → notify khi xong
□ Cache invalidation: Khi nào cần clear cache? (data update, parameter change)

Quy tắc: Report chạy >5 giây → PHẢI có caching strategy
```

### Bước 8: Viết Feature Spec

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase2-features/[sys]/reporting/reporting-module.md

Cấu trúc output:
1. Overview (mục tiêu, scope, audience)
2. Report Catalog (table: tên → mô tả → frequency → audience)
3. Filter & Parameter spec (per report)
4. Scheduling & Distribution spec
5. Export spec (formats + constraints)
6. Access control matrix (role → report → permissions)
7. Performance requirements (SLA per report type)
8. REQ-ID mapping (feature → REQ-DATA-RPT-xxx)
```

---

## Checklist trước khi submit

```
□ Report catalog cover đủ các departments đã identify
□ Mỗi report có filter spec rõ ràng
□ Export formats đáp ứng nhu cầu stakeholders (PDF/Excel/CSV)
□ Access control matrix đã được define
□ Heavy reports đã có caching strategy
□ REQ-ID mapping đầy đủ với requirements phase 1
```
