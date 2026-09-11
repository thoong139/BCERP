# Playbook: Review Product Management Implementation

> **Type**: Agent Procedure
> **Agent**: product-expert
> **Triggered by**: /wf-implement-feature khi review code của product management modules
> **Output**: Product implementation review report

---

## Khi nào dùng playbook này

- Trong `/wf-implement-feature` khi review code của product module
- Khi cần validate implementation từ product domain perspective
- Khi cần check business logic cho roadmap, backlog, metrics, feedback

---

## Procedure

### Bước 1: Xác định module đang review

```
INPUT: Paths do skill cung cấp qua prompt — code files cần review

Identify module type:
□ Roadmap Management  → check horizon logic, OKR links, visibility rules
□ Backlog Management  → check RICE scoring, story status transitions
□ Metrics/Analytics   → check velocity calc, throughput, cycle time accuracy
□ Feedback System     → check NPS/CSAT collection, sentiment, routing
□ User Story Workflow → check DoR/DoD enforcement, acceptance criteria
□ Sprint Planning     → check capacity calc, commitment tracking
```

### Bước 2: Review theo product requirements

```
READ: .claude/references/team-expert/product/requirements-framework.md

Xác định REQ-PROD-xxx tương ứng với module đang review.
Đối chiếu từng requirement với implementation:
□ Mỗi REQ-PROD có được implemented đầy đủ không?
□ Acceptance Criteria trong requirements đã pass không?
□ Edge cases (empty backlog, no active sprint, etc.) đã handle?
```

### Bước 3: Verify prioritization logic

**RICE Scoring:**
```
□ Công thức đúng: (Reach × Impact × Confidence) / Effort?
□ Division-by-zero protection khi Effort = 0?
□ Rounding: Có consistent không? (2 decimal places)
□ Score recalculation: Triggered khi field nào thay đổi?
□ Score history: Có lưu score history để audit không?
□ Override: Có audit log khi PM manually override score?
```

**MoSCoW:**
```
□ Chỉ 1 classification per item (không vừa Must vừa Should)?
□ Re-classification có require approval không?
□ "Won't have" items: Có visible hay hidden?
```

### Bước 4: Check roadmap visualization

```
□ Timeline rendering: Đúng với horizon data (Now/Next/Later dates)?
□ Gantt/Timeline: Có overlap detection không?
□ Drag-and-drop re-scheduling: Có update underlying dates đúng không?
□ Dependency arrows: Có render đúng chiều không?
□ Public roadmap: Visibility filter đang apply đúng không?
   (Internal-only items KHÔNG được expose ra public view)
□ PDF/export: Có sanitize trước khi export không?
□ Filter/search: Có index hợp lý trên horizon, status, team fields?
```

### Bước 5: Validate metrics calculations

**Velocity:**
```
□ Unit: Story points hay item count? Nhất quán trong toàn hệ thống?
□ Calculation window: Completed trong sprint hay committed?
□ Rolling average: 3-sprint hay configurable?
□ Outlier handling: Sprint đặc biệt (holiday, major incident) có được exclude?
```

**Throughput:**
```
□ Đếm stories "Done" hay cả "Deployed"?
□ Partial credit cho unfinished stories trong sprint?
□ Cancelled items: Có exclude khỏi throughput không?
```

**Cycle Time và Lead Time:**
```
□ Cycle time = In Progress → Done (không phải Created → Done)
□ Lead time = Created → Done
□ Blocked time: Có exclude thời gian blocked không?
□ Timezone handling: Timestamps phải nhất quán (UTC recommended)
```

### Bước 6: User story workflow

```
□ Status transitions đúng không?
   Backlog → Ready → In Progress → In Review → Done (→ Deployed)
□ DoR enforcement: Có validate fields bắt buộc trước khi "Ready" không?
   (title, description, AC, story points, epic link)
□ DoD enforcement: Có validate checklist trước khi "Done" không?
□ Re-open logic: Story đã "Done" có thể re-open không? Audit trail?
□ Blocked state: Có separate "Blocked" status với blocker link không?
□ Sprint assignment: Story có thể trong nhiều sprint không? (phải block)
```

### Bước 7: Integration với development tools

```
□ GitHub/GitLab PR link: Story ↔ PR có bidirectional không?
□ Auto-transition: PR merged → Story auto-close?
□ Commit reference: "BACK-123" trong commit message có được parsed không?
□ CI/CD status: Build status có visible từ story không?
□ Deployment tracking: Deploy event có update story status không?
□ Webhook reliability: Có retry logic khi webhook fails không?
```

### Bước 8: Reporting accuracy

```
□ Dashboard data: Có cache stale data không? Cache TTL bao lâu?
□ Export: CSV/Excel export có đúng với on-screen data không?
□ Timezone in reports: Có convert đúng sang user's timezone không?
□ Historical data: Có immutable snapshot cho sprint reports không?
   (sprint completed data không được thay đổi retroactively)
□ Permissions: Report chỉ show data user có quyền xem?
```

### Bước 9: Output — Review Report

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/product-implementation-review.md

```markdown
# Product Implementation Review: [Module Name]

## Status tổng thể: ✅ PASS / ❌ FAIL / ⚠️ CẦN CHÚ Ý

## Critical Issues (block go-live)
- [ ] [Issue]: [Location] → [Required fix]

## Important Issues (fix trước sprint tiếp theo)
- [ ] [Issue]: [Location] → [Recommendation]

## Suggestions (nice-to-have)
- [ ] [Suggestion]

## Requirements Coverage
[Table: REQ-ID | Implemented | Notes]

## Business Logic Checklist
[Table: Item | Status | Notes]

## Performance Concerns
[List any N+1, missing indexes, heavy calculations]

## Sign-off
□ Prioritization logic: OK / ISSUE
□ Metrics accuracy: OK / ISSUE
□ Workflow state machine: OK / ISSUE
□ Data integrity: OK / ISSUE
□ Integration reliability: OK / ISSUE
```
```

---

## Checklist trước khi submit

```
□ Tất cả REQ-PROD-xxx liên quan đã được verify
□ Prioritization logic (RICE/MoSCoW) đã được validated
□ Metrics calculations đã được checked với edge cases
□ Story workflow state machine đã được reviewed
□ Integration points với dev tools đã được tested
□ Historical data immutability đã được confirmed
□ Performance risks đã được flagged
```
