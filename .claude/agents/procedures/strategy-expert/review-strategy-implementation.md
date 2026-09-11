# Playbook: Review Strategy Module Implementation

> **Type**: Agent Procedure
> **Agent**: strategy-expert
> **Triggered by**: /wf-implement-feature review pass cho strategy modules
> **Output**: Review report inline hoặc `.mc-data/work/wf-implement-feature/strategy-review-[date].md`

---

## Khi nào dùng playbook này

- Khi `/wf-implement-feature` hoàn thành một strategy module và cần business review (KHÔNG phải code review)
- Khi cần verify: logic nghiệp vụ đúng, access controls hoạt động, governance workflows correct
- Scope: Executive Dashboard, OKR system, Board Portal, M&A module, Holding Company reporting

---

## Procedure

### Bước 1: Đọc requirements và design specs

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK:
  Requirements → .mc-data/docs/phase1-business/strategy-requirements.md
  Design → .mc-data/docs/phase3-architecture/strategy/[module].md
  Task → .mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md

Xác định:
□ Module được review (Executive Dashboard / OKR / Board Portal / M&A / Holding)
□ REQ-IDs được implement trong sprint này
□ Design specs đã approved
□ Known deviations từ design (nếu có — documented trong task file)
```

### Bước 2: Chạy review theo checklist

Thực hiện đầy đủ 6 categories bên dưới.

---

## Checklist Review

### Category 1: Access Control Enforcement

```
□ Role-based data filtering hoạt động đúng:
  - CEO: Thấy Company + All BUs → VERIFY với test account CEO role
  - CFO: Thấy Financial KPIs + All BU financials → VERIFY
  - BU Head: Chỉ thấy own BU + Company aggregates → VERIFY không thấy peer BU details
  - Strategy Manager: OKR all BUs, Financial = aggregated only → VERIFY
  - Board: Summary level only + Board Confidential tier → VERIFY

□ Filtering xảy ra ở DATA LAYER (server-side):
  - KHÔNG chỉ ẩn UI elements — data response API phải bị filter
  - Test: Gọi trực tiếp API với BU Head token → Response KHÔNG chứa peer BU data
  - Flag nếu phát hiện client-side filtering only → CRITICAL ISSUE

□ Board Confidential tier không leak:
  - M&A data: Chỉ deal team members mới access được
  - CEO remuneration: Chỉ Remuneration Committee + Board
  - Test với account ngoài authorized list → 403 Forbidden hoặc empty response

□ Audit trail ghi đầy đủ:
  - User ID, timestamp, IP, action type, entity accessed
  - Export actions logged (who exported what, when, format)
  - Check: Audit log records generated sau mỗi access action
```

### Category 2: KPI Calculation Accuracy

```
□ Aggregation logic correct:
  - Revenue: SUM (không average) của BU revenues → VERIFY với known test data
  - EBITDA margin: EBITDA / Revenue × 100% → VERIFY formula
  - OKR score: Weighted average of KR scores → VERIFY weights
  - NPS: (-100 to +100 scale) → VERIFY không dùng raw %, phải đúng NPS formula

□ Currency conversion applied consistently:
  - Nếu có foreign currency subsidiaries: conversion rate policy → VERIFY
  - Check: Sử dụng rate nào (spot / average / closing)?
  - Flag: Kết quả khác nhau khi reload (dùng rate thay đổi real-time vs fixed)

□ Intercompany elimination cho group-level KPIs:
  - Revenue: Loại bỏ intercompany revenue (IC sales không double-count)
  - VERIFY với test case: IC sale 10B → Group revenue KHÔNG tăng 10B
  - Flag nếu elimination không được implement cho consolidated view

□ Historical comparison uses same definition (apples-to-apples):
  - KPI definition không thay đổi mid-year → historical data valid
  - Nếu definition thay đổi → cần restatement flag + footnote
  - VERIFY: Comparison period uses same formula
```

### Category 3: OKR / BSC Workflow Completeness

```
□ Cascade hierarchy enforced:
  - BU OKR PHẢI link tới Company Objective → VERIFY không thể save orphan BU OKR
  - Max 4 levels: Company → BU → Dept → Individual → VERIFY level 5 bị blocked
  - Child OKR scope không vượt parent scope → flag nếu validation thiếu

□ Check-in reminders trigger correctly:
  - Weekly reminder: Sent D-2 trước deadline → VERIFY với test scheduled job
  - Escalation: Confidence < 50% sau 2 consecutive check-ins → Manager notified
  - VERIFY escalation email/notification generated với correct recipient

□ Scoring formula matches agreed methodology:
  - KR score = current_value / target (không phải % complete of timeline)
  - Objective score = weighted average of KR scores (weights configurable)
  - VERIFY với test: KR target 100, current 70 → score = 0.7 (not 0.5 based on time)

□ Quarter transition handled correctly:
  - Close cycle: All OKRs archived với final scores → VERIFY no data loss
  - New cycle: Created with correct date range, blank OKRs ready to plan
  - Historical: Closed cycle accessible (read-only) for trend analysis
  - VERIFY: Cannot edit closed cycle OKRs (immutable after close)
```

### Category 4: Governance Workflow

```
□ DoA-based approval routing correct:
  - CAPEX VND 10-50B → Routes to CFO (not BU Head) → VERIFY routing
  - CAPEX > VND 50B → Routes to CEO → VERIFY
  - Nếu wrong approver receives → FLAG as CRITICAL

□ Board resolution workflow:
  - Quorum check: Meeting cannot proceed without quorum → VERIFY logic
  - Voting: Records who voted what, when → VERIFY vote captured
  - Minutes: Auto-generated after meeting with votes → VERIFY content
  - Resolution signed: Digital signature captured → VERIFY audit trail

□ M&A deal code / confidentiality controls (nếu M&A module):
  - Deal code: Each target has code name (not real name) visible to broader team
  - VDR access: Restricted to deal team only → VERIFY access list
  - Insider trading controls: Deal team flagged in system → notify blackout period
  - VERIFY: Non-deal-team user cannot see deal details even with correct role

□ Document versioning với approval history:
  - Every version saved với: author, timestamp, status change
  - Approved version immutable (cannot edit) → VERIFY lock on approved docs
  - Audit trail: Who approved, when, any comments
```

### Category 5: Reporting & Export

```
□ Executive dashboard refreshes on correct schedule:
  - Financial KPIs: T+1 → VERIFY data reflects previous day's actuals
  - Real-time KPIs (operational): < 30 second lag → VERIFY with live test
  - Manual inputs: Immediately visible after save → VERIFY

□ Board pack PDF generation:
  - Format: Company branding (logo, colors, fonts) → VERIFY visual
  - Content: All required sections present (per board pack standard)
  - Data accuracy: Figures in PDF match dashboard → VERIFY spot-check 3 KPIs
  - Page numbers, date, version stamp → VERIFY present

□ No sensitive data in export metadata:
  - PDF metadata: Check author name, internal paths not exposed
  - Excel: Check sheet names, hidden columns, cell comments
  - Flag nếu find internal names/paths/user details in export

□ Export audit: Export action logged → VERIFY audit trail entry created
```

### Category 6: Performance & Reliability

```
□ Dashboard load time < 3 seconds:
  - Test: Cold load (no cache) → measure first paint + data load
  - Test: CEO mobile view → measure on 4G equivalent
  - Flag: > 3 seconds → performance optimization needed

□ Mobile layout đúng trên iOS và Android:
  - CEO view: Max 5 KPI cards on first screen (no horizontal scroll)
  - KPI cards readable without zoom
  - Check-in form: Usable on mobile keyboard (no overlap)
  - Test with real device or responsive testing tool

□ Real-time KPIs: max 30-second lag acceptable:
  - Identify which KPIs are "real-time" (per design spec)
  - Test: Update source data → verify dashboard reflects within 30 seconds
  - Flag: > 30 seconds lag → investigate caching or polling interval

□ Concurrent user capacity:
  - Per design spec (e.g., 50 concurrent C-suite users)
  - Load test nếu production expected to have high concurrent use
  - Flag nếu performance degrades > 20% under expected load
```

---

## Output Format

```markdown
# Strategy Module Review — [Module Name]
**Date**: YYYY-MM-DD
**Reviewer**: strategy-expert
**Sprint / Feature**: [Feature name]
**REQ-IDs covered**: REQ-STR-[MODULE]-001, ...

## Summary
[1 paragraph: pass/fail verdict, critical issues count, notable findings]

## Critical Issues (MUST FIX before release)
| # | Category | Description | Severity |
|---|----------|-------------|----------|
| 1 | Access Control | BU Head can see peer BU revenue via API | 🔴 Critical |

## Non-critical Issues (Fix in next sprint)
| # | Category | Description | Priority |
|---|----------|-------------|----------|
| 1 | Performance | Dashboard loads in 4.2s on mobile | 🟡 High |

## Passed Checks
[List categories that passed cleanly]

## Open Questions
[Items requiring business decision or PM clarification]

## Verdict
[ ] ✅ PASS — Ready for UAT
[ ] ⚠️ CONDITIONAL PASS — Pass after fixing critical issues
[ ] ❌ FAIL — Significant rework needed
```

---

## Checklist trước khi submit review

```
□ Đã test access control với multiple roles (CEO, CFO, BU Head, Board)
□ Đã verify server-side filtering (không chỉ UI)
□ Đã spot-check KPI formulas với known test data
□ Đã verify OKR cascade hierarchy enforcement
□ Đã check governance workflow routing correctness
□ Đã test export (PDF, Excel) cho sensitive data leakage
□ Đã measure dashboard load time
□ Đã test mobile layout (CEO check-in use case)
□ All Critical issues documented với reproduction steps
□ Verdict clearly stated với rationale
```
