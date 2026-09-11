# Playbook: Phân tích Analytics Requirements

> **Type**: Agent Procedure
> **Agent**: data-expert
> **Triggered by**: /wf-analyze-requirements khi project có analytics/BI/reporting modules
> **Output**: `.mc-data/docs/phase1-business/analytics-requirements.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-analyze-requirements`
- Khi dự án có bất kỳ module nào liên quan đến: analytics, BI, reporting, dashboard, KPI, metrics, báo cáo
- Khi cần xác định analytics requirements từ business idea

---

## Procedure

### Bước 1: Đọc context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, KNOWLEDGE_BASE

Cần xác định:
□ Loại sản phẩm/dịch vụ (ERP, CRM, E-commerce, SaaS...)
□ Các departments sử dụng dữ liệu (Ban giám đốc, Sales, Marketing, Finance...)
□ Đã có analytics platform chưa? Nếu có → đang dùng gì?
□ Quy mô dữ liệu ước tính (số bản ghi/ngày, số năm lịch sử)
```

### Bước 2: Xác định Analytics Maturity Level

```
READ: .claude/references/team-expert/data/analytics-framework.md → Analytics Maturity Model

Đặt câu hỏi để xác định level hiện tại và level mục tiêu:
□ Hiện tại: Dữ liệu được xem dưới dạng gì? (Excel, báo cáo tĩnh, dashboard?)
□ Mục tiêu: Cần phân tích gì? (Mô tả quá khứ / Chẩn đoán nguyên nhân / Dự báo?)
□ Khoảng cách: Cần đầu tư gì để đạt mục tiêu?

Ghi chú: data-expert tập trung Level 1-3 (Adhoc → Descriptive → Diagnostic).
Level 4-5 (Predictive/Prescriptive) → phối hợp với ai-engineer.
```

### Bước 3: Map Data Consumers

```
Xác định ai sẽ dùng analytics system:
□ Executive/BGĐ → cần KPI tổng hợp, trend, cảnh báo ngưỡng
□ Manager/Trưởng phòng → cần báo cáo phòng ban, so sánh mục tiêu
□ Analyst/Chuyên viên → cần drill-down, export, ad-hoc query
□ Operations/Nhân viên → cần báo cáo tác nghiệp hàng ngày

Với mỗi nhóm: note frequency (real-time / daily / weekly / monthly)
```

### Bước 4: Identify KPIs per Department

```
READ: .claude/references/team-expert/data/analytics-framework.md → KPI Framework + Use Cases by Domain

Với mỗi department có trong dự án:
□ Financial KPIs: Revenue, Profit, Cash flow, Budget vs Actual
□ Sales KPIs: Pipeline, Conversion rate, Revenue by rep/region
□ Operations KPIs: Throughput, Cycle time, Inventory turnover
□ Customer KPIs: NPS, CSAT, Retention rate, CLV
□ HR KPIs: Headcount, Turnover rate, Productivity

Ghi nhận: KPI nào là leading indicator vs lagging indicator?
```

### Bước 5: Data Sources Inventory

```
Xác định nguồn dữ liệu cần kết nối:
□ Transactional DB chính (ERP, CRM, eCommerce...)
□ External sources (APIs bên thứ ba, file import)
□ Manual inputs (Excel upload, form entry)
□ Real-time streams vs batch exports

Với mỗi source: ghi chú data owner, update frequency, data quality risks
```

### Bước 6: Granularity & Latency Requirements

```
□ Granularity: Level of detail cần thiết (transaction-level / daily aggregate / monthly)
□ History: Cần lưu dữ liệu lịch sử bao lâu? (1 năm / 3 năm / 5 năm+)
□ Latency: Dữ liệu cần fresh đến mức nào?
   - Real-time (<1 phút): operational dashboards, alerts
   - Near real-time (15-60 phút): management dashboards
   - Daily refresh: executive reports, trend analysis
   - On-demand: ad-hoc reports, exports
```

### Bước 7: Viết requirements

Format mỗi requirement:

```markdown
### REQ-DATA-[MODULE]-[NNN]: [Tên requirement ngắn gọn]

**Mô tả**: [Diễn giải đầy đủ tính năng/yêu cầu]
**Data Consumer**: [Ai cần — Executive / Manager / Analyst / Operations]
**Business Value**: [Quyết định gì sẽ được cải thiện]
**Acceptance Criteria**:
- [ ] [Tiêu chí 1]
- [ ] [Tiêu chí 2]
**Data Sources**: [Tables/APIs cần thiết]
**Latency**: [Real-time / Daily / On-demand]
**Priority**: [Must-have / Should-have / Nice-to-have]
```

**REQ-ID Format:**
```
REQ-DATA-RPT-001   → Operational reporting
REQ-DATA-DASH-001  → BI/Executive dashboard
REQ-DATA-KPI-001   → KPI framework & definitions
REQ-DATA-EXPORT-001 → Export & distribution
REQ-DATA-ACCESS-001 → Access control & security
```

### Bước 8: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/analytics-requirements.md

Cấu trúc output:
1. Executive Summary (scope analytics, maturity level hiện tại vs mục tiêu)
2. Data Consumer Map (table: nhóm người dùng → nhu cầu)
3. KPI Inventory (per department)
4. Data Sources (table: source → owner → frequency → quality notes)
5. Requirements (theo module, có REQ-ID)
6. Non-functional requirements (latency, retention, performance)
7. Open questions cần confirm với stakeholders
```

---

## Checklist trước khi submit

```
□ Mỗi REQ có REQ-ID đúng format REQ-DATA-[MODULE]-[NNN]
□ Mỗi KPI có definition rõ ràng (formula, data source)
□ Data latency requirements đã được xác định
□ Access control requirements đã được included
□ Integration với departments khác đã được noted
□ Open questions được list ra để stakeholders review
```
