# Playbook: Design Pipeline Management Module

> **Type**: Agent Skill Playbook
> **Agent**: sales-expert
> **Triggered by**: /wf-define-features hoặc /wf-design khi có CRM pipeline module
> **Output**: Feature spec cho pipeline management module

---

## Khi nào dùng playbook này

- Khi cần spec module "Pipeline Management" hoặc "Quản lý Cơ hội Bán hàng"
- Khi cần thiết kế data model cho opportunity lifecycle
- Khi review/audit hệ thống pipeline CRM hiện có

---

## Procedure

### Bước 1: Đọc sales requirements

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE1_DEPTS, PHASE2

Xác định từ requirements:
□ Pipeline stages đã được define (số lượng, tên, probability)
□ Deal qualification framework (MEDDPICC, BANT, hay custom)
□ Territory/Account model (assigned territory vs open)
□ Forecasting method (weighted, commit, best-case)
□ Win/Loss tracking có cần capture reason không?
```

### Bước 2: Thiết kế Opportunity Lifecycle

```
READ: operations.md → Pipeline stages & transitions
READ: pipeline-analytics.md → Forecasting models

Standard opportunity stages:

Prospecting → Qualified → Demo/Proposal → Negotiation → Closed Won / Closed Lost
  (10%)         (25%)         (50%)           (75%)          (100%)   (0%)

Mỗi stage cần define:
□ Tên stage + probability mặc định (%)
□ Entry criteria (required fields khi move vào)
□ Activities cần có (calls, emails, meetings)
□ Next action required (push rep có action tiếp theo)
□ Stale deal threshold (bao nhiêu ngày không có activity → cảnh báo)
```

### Bước 3: Thiết kế Win/Loss Tracking

```
Win tracking:
□ Closed date (actual vs forecasted)
□ Deal size (vs quoted)
□ Competitive displacement (nếu win từ competitor)
□ Sales cycle length (actual vs average)

Loss tracking:
□ Loss reason categories (Price, Product fit, Competitor, Timing, No decision)
□ Lost to competitor (track competitor win rate)
□ Stage lost at (để identify drop-off point)
□ Rep notes (free text)

Báo cáo cần:
□ Win rate by stage, by rep, by product, by industry
□ Average sales cycle (won vs lost)
□ Loss reason breakdown (Pareto)
□ Competitive win/loss matrix
```

### Bước 4: Thiết kế Forecasting

```
READ: pipeline-analytics.md → Forecasting methodology

Forecast types:

| Type         | Cách tính                                    | Khi dùng                  |
|--------------|----------------------------------------------|---------------------------|
| Weighted     | Σ (Deal Value × Stage Probability)           | Default pipeline forecast |
| Commit       | Chỉ deals rep đánh dấu "Commit"              | Revenue commit to Finance |
| Best Case    | Commit + deals có probability > 50%          | Upside scenario planning  |
| Pipeline     | Tổng toàn bộ open deals (không weight)       | Pipeline health check     |

Forecast roll-up:
Rep → Manager → Director → CRO (mỗi level có thể override với judgment)

Forecast accuracy tracking:
□ Predicted vs Actual mỗi tháng/quý
□ Forecast accuracy % per rep, per manager
□ Call variance (sai lệch giữa commit và actual)
```

### Bước 5: Thiết kế Activity Tracking

```
Activity types cần log:
□ Call (ngày, duration, outcome, next step)
□ Email (sent, opened, replied — integrate với email client)
□ Meeting (ngày, attendees, type: demo/discovery/negotiation)
□ Note (free text, tagged by topic)
□ Task (due date, assigned to, status)

Auto-tracking (nếu có email integration):
□ Email sent/received tự động log vào opportunity
□ Meeting invite → auto-create activity record
□ Voicemail/call log từ sales dialer (nếu integrate)

Stale deal alert:
□ Không có activity trong X ngày → notify rep và manager
□ X configurable per stage (Prospecting: 3 ngày, Negotiation: 1 ngày)
```

### Bước 6: Thiết kế Territory Management

```
READ: controls.md → Territory & access rules

Territory model options:
□ Geographic (by region/province/country)
□ Industry vertical (Tech, Finance, Healthcare...)
□ Company size (SMB/Mid-market/Enterprise)
□ Named accounts (specific account list assigned to rep)
□ Round-robin (leads tự động assign theo lượt)

Access control rules:
□ Rep chỉ xem opportunities trong territory của mình
□ Manager xem tất cả trong team
□ Có "sharing rules" để rep cộng tác on deal không?
□ Territory override: Manager có thể reassign không? → Audit log
```

### Bước 7: Feature Spec Output

```markdown
# Feature Spec: Pipeline Management

## Overview
[Mô tả module, scope]

## User Stories
[Theo personas từ personas.md]

## Functional Requirements
REQ-SALES-PIPE-001: Opportunity CRUD với stage tracking
REQ-SALES-PIPE-002: Stage transition với entry/exit criteria
REQ-SALES-PIPE-003: Win/Loss tracking với reason capture
REQ-SALES-PIPE-004: Activity logging (call, email, meeting, note, task)
REQ-SALES-PIPE-005: Forecast view (weighted, commit, best-case)
REQ-SALES-PIPE-006: Stale deal alerts và next action prompts
REQ-SALES-PIPE-007: Territory-based access control
REQ-SALES-PIPE-008: Pipeline health dashboard per rep/manager

## Data Model
[ERD: Opportunity, Stage, Activity, ForecastEntry, Territory]

## Non-functional Requirements
- Pipeline list load < 1s cho 1000+ opportunities
- Forecast calculation real-time (không batch)
- Mobile-friendly cho field sales (rep update trên điện thoại)
```

---

## Checklist trước khi submit

```
□ Tất cả stages có probability % được define
□ Win/Loss reason categories đã thiết kế
□ Forecast methodology đã chọn (weighted / commit / best-case)
□ Territory access control đã rõ ràng
□ Stale deal threshold đã có (configurable)
□ Integration với Quotation module đã noted (nếu applicable)
□ Mobile requirements đã được xem xét (field sales)
□ REQ-ID format: REQ-SALES-PIPE-[NNN]
```
