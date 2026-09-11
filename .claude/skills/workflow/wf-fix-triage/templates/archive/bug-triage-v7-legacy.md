<!-- Template: bug-triage.md — Phân loại lỗi trước khi fix -->
<!-- Ai viết: AI tự động generate ở Phase 2 cua /wf-fix-triage (spawned bởi /wf-fix-bugs) -->

# Bug Triage

**Generated:** YYYY-MM-DD HH:mm:ss
**Scope:** [all / system=X / module=Y]
**User Description:** [Mô tả lỗi từ user hoặc "Scan toàn bộ"]
**Preflight Score:** X%
**Profile:** [quick / standard / deep / exhaustive]
**Workload ID:** [fix_id = workload_id — tham chiếu fix-workload.json]

> **Taxonomy CANONICAL** (KHÔNG chế thay từ — xem SKILL.md Anti-Invention Rule):
> - Severity: CRITICAL | HIGH | MEDIUM | LOW
> - Fixability: AUTO_FIX | AGENT_FIX | MANUAL_FIX | ESCALATE | SKIP
> - **CẤM dùng:** "FIX NOW", "FIX IF BUDGET", "DEFER MANUAL", "DEFER BACKLOG", "TODO LATER", "FOLLOW-UP", "POSTPONE".

---

## Summary

| Severity \\ Fixability | AUTO_FIX | AGENT_FIX | MANUAL_FIX | ESCALATE | SKIP | Total |
|-----------------------|----------|-----------|------------|----------|------|-------|
| CRITICAL | X | X | X | X | X | X |
| HIGH | X | X | X | X | X | X |
| MEDIUM | X | X | X | X | X | X |
| LOW | X | X | X | X | X | X |
| **Total** | **X** | **X** | **X** | **X** | **X** | **X** |

### Batch Routing (theo profile)

| Batch | Phai bao gom | Profile=quick | Profile=standard | Profile=deep | Profile=exhaustive |
|-------|--------------|---------------|------------------|--------------|---------------------|
| Batch 1 | CRITICAL (AUTO_FIX/AGENT_FIX) | YES | YES | YES | YES |
| Batch 2 | HIGH (AUTO_FIX/AGENT_FIX) | YES | YES | YES | YES |
| Batch 3 | MEDIUM + LOW (AUTO_FIX/AGENT_FIX) | NO (skip) | MEDIUM only | MEDIUM only | MEDIUM + LOW |
| escalations.json | MANUAL_FIX + ESCALATE | YES | YES | YES | YES |
| Log only | SKIP | YES | YES | YES | YES |

> Profile=quick: LOW + MEDIUM AUTO_FIX/AGENT_FIX → fixability set thanh SKIP với `skip_reason="profile=quick"`.
> Profile=exhaustive: TAT CA AUTO_FIX/AGENT_FIX phai vao batches — KHONG defer LOW/MEDIUM.

---

## Workload Overview

> Du lieu tu `fix-workload.json` (ADR-14, ADR-15) — uoc tinh cong suc fix toan session.

**Total estimated:** [total_minutes] phút (= [total_estimated_seconds] giây)
**Profile:** [small | medium | large — chọn theo file_count va edge_count impact-graph.json]
**Workload Gate:** [Plan A passed | Plan B triggered — lý do neu Plan B]

### Quality Dimensions Breakdown

| QD | Ten | So loi | Minutes | Safety Floor | Ghi chu |
|----|-----|--------|---------|--------------|---------|
| QD1 | Correctness | X | M | yes | Loi logic, test failure, compile error |
| QD2 | Completeness | X | M | yes | Thieu coverage, missing edge cases |
| QD3 | Security | X | M | never-cached (CDG) | Co the bi chan boi CDG |
| QD4 | Maintainability | X | M | no | Lint, style, refactor |
| QD5 | Consistency | X | M | yes | UI label, terminology, naming |
| QD6 | Performance | X | M | no | Cham, memory leak |
| QD7 | UX | X | M | no | Orphan UI, missing feature spec |
| QD8 | Observability | X | M | yes | Retry/CB, timeout, log, metrics, health-check, alert |

**Safety floor (QD1/QD2/QD5):** luôn xử lý, khong loại bỏi Workload Gate → nếu Plan B trigger, chỉ cắt bớt QD3/4/6/7/8.

### Impact Graph Context

- Nodes: [N files trong repo duoc scan]
- Edges: [M import edges]
- Critical blast radius (direct_count >= 5): [K issues] — xem cot "Blast Radius" duoi.

---

## CRITICAL Issues (Batch 1 — fix ngay)

> Compile errors, type errors, registry corruption — chan toan bo workflow.

| # | ID | Type | Source | File | Line | Description | Blast Radius | Fixability |
|---|----|------|--------|------|------|-------------|--------------|------------|
| 1 | ISSUE-001 | compile_error | static | src/path/file.ts | NN | [Mô tả] | direct=X | AUTO_FIX |
| 2 | ISSUE-002 | type_error | static | src/path/file.ts | NN | [Mô tả] | direct=X | AUTO_FIX |

> **Blast Radius:** so file downstream phu thuoc truc tiep (depth=1, strength >= 0.5) tu Impact Graph.
> Neu direct_count >= 5 va severity ban dau la MEDIUM/LOW → tu dong bump len HIGH (xem `issue.severity_bump_reason`).

---

## HIGH Issues (Batch 2 — fix)

> Test failures, security issues, logic bugs — anh huong chinh xac va an toan.

| # | ID | Type | Source | File | Line | Description | Blast Radius | Fixability |
|---|----|------|--------|------|------|-------------|--------------|------------|
| 1 | ISSUE-003 | test_failure | static | tests/path/file.test.ts | NN | [Mô tả] | direct=X | AGENT_FIX |
| 2 | ISSUE-004 | security_issue | static | src/path/file.ts | NN | [Mô tả] | direct=X | AGENT_FIX |
| 3 | ISSUE-005 | logic_bug | static | src/path/file.ts | NN | [Mô tả] | direct=X | AGENT_FIX |

---

## MEDIUM Issues (Batch 3 — auto-fix/agent-fix)

> Lint errors, orphan code (thieu REQ-ID), registry format, code quality — chat luong code.

| # | ID | Type | Source | File | Line | Description | Blast Radius | Fixability |
|---|----|------|--------|------|------|-------------|--------------|------------|
| 1 | ISSUE-006 | lint_error | static | src/path/file.ts | NN | [Mô tả] | direct=X | AUTO_FIX |
| 2 | ISSUE-007 | orphan_code | static | src/path/file.ts | — | Thieu REQ-ID comment | direct=X | AUTO_FIX |
| 3 | ISSUE-008 | registry_format | static | req-registry.json | — | [Mô tả] | direct=X | AUTO_FIX |

---

## LOW Issues (Batch 3 — chỉ khi profile=exhaustive, hoặc SKIP với các profile khác)

> Style suggestions, minor nits, micro-optimizations.
> **profile=exhaustive:** vao Batch 3 cung MEDIUM. **profile khac:** SKIP với `skip_reason="profile=<X>"`.

| # | ID | Type | Source | File | Line | Description | Blast Radius | Fixability |
|---|----|------|--------|------|------|-------------|--------------|------------|
| 1 | ISSUE-00X | style_nit | static | src/path/file.ts | NN | [Mô tả] | direct=X | AUTO_FIX |

---

## ESCALATED Issues (xuất ra escalations.json — cần stakeholder review)

> MANUAL_FIX (architectural changes, multi-module refactor) hoac ESCALATE (missing docs, design issues).
> Tat ca cac issue trong section nay PHAI co entry tuong ung trong `$SESSION_DIR/escalations.json` với `stakeholder_hint` + `suggested_skill`.

| # | ID | Severity | Fixability | File | Description | Stakeholder | Suggested Action |
|---|----|----------|------------|------|-------------|-------------|------------------|
| 1 | ISSUE-009 | HIGH | ESCALATE | — | Thieu feature spec cho [feature] | product_owner | Chay `/wf-define-features` |
| 2 | ISSUE-010 | HIGH | MANUAL_FIX | src/path/file.ts | API contract conflict | architect | Chay `/wf-design` + ADR |
| 3 | ISSUE-011 | CRITICAL | MANUAL_FIX | src/payment/file.ts | Compliance violation (Decree 91) | legal | Stakeholder review + spec change |

---

## SKIP Issues (informational only)

| # | ID | Type | Source | File | Description |
|---|----|------|--------|------|-------------|
| 1 | ISSUE-011 | style_suggestion | static | src/path/file.ts | [Mô tả] |

---

## User Journey Impact (QD10 — Chỉ khi có cross-module issues)

> Issues co `user_journey_broken=true` — luong người dùng bi gian doan boi cross-module gap.
> Bo qua section nay khi QD10 lane khong chay hoac khong co cross-module issues.

**Tổng cross-module issues:** [N] | **Severity bumped vì user_journey_broken:** [N] issues (MEDIUM/LOW → HIGH)

| # | ID | Severity (sau bump) | Cross-Module Impact | Affected Flows | Data Consistency Risk |
|---|----|---------------------|---------------------|----------------|-----------------------|
| 1 | ISSUE-NNN | HIGH | MOD-A → MOD-B | [flow-id hoac "—"] | high / medium / low |

> **data_consistency_risk mapping:** high = orphan/entity-sync-shape/data-loss; medium = api-contract/cache-staleness/fk-mismatch; low = other.

---

## Runtime Discovery Results

> Kết quả tu Phase 1c — phat hien loi runtime bang Playwright.

**App URL:** [url hoac "Not scanned"]
**Pages scanned:** [N]
**Screenshots:** [N] files tại `.mc-data/work/wf-fix-bugs/evidence/`

### Console Errors
| # | ID | Message | Page | Count |
|---|----|---------|------|-------|

### Network Errors (4xx/5xx)
| # | ID | URL | Status | Method | Page |
|---|----|-----|--------|--------|------|

### UI Issues
| # | ID | Type | Element | Page | Description |
|---|----|------|---------|------|-------------|

### Form Validation Issues
| # | ID | Form | Page | Issue |
|---|----|------|------|-------|

---

## UI→Docs Gap Analysis (--deep)

> Kết quả tu Phase 1c.9b — phat hien UI elements khong co feature spec.
> Chi hien thi khi `--deep` flag active. Neu khong dung --deep → bo qua section nay.

**Total orphan UI elements:** [N]

### Orphan UI Actions (thieu feature spec)

| # | ID | Element | Page | Suggested Feature Name | Severity |
|---|----|---------|------|------------------------|----------|
| 1 | ISSUE-012 | [element text] | [page URL] | [ten feature goi y] | MEDIUM |

### Orphan UI Screens (thieu UX doc)

| # | ID | Page URL | Page Title | Expected Doc Path | Severity |
|---|----|----------|------------|-------------------|----------|
| 1 | ISSUE-013 | [/path] | [title] | phase4-ux/[sys]/[mod]/screens-[slug].md | HIGH |

### Orphan UI Flows (thieu flow doc)

| # | ID | Flow Name | Steps | Page | Severity |
|---|----|-----------|-------|------|----------|
| 1 | ISSUE-014 | [flow name] | [N steps] | [page URL] | HIGH |

---

## E2E Flow Testing Results (--e2e / --full-test)

> Kết quả tu Phase 1d — kiểm tra luong nghiep vu end-to-end.
> Chi hien thi khi `--e2e` hoac `--full-test` flag active.

**Total flows tested:** [N] (PASSED: [X], FAILED: [Y], PARTIAL: [Z])

| # | ID | Flow Name | Source Doc | Steps | Result | Failed Step |
|---|----|-----------|------------|-------|--------|-------------|
| 1 | ISSUE-015 | [flow name] | [source doc path] | [N] | PASS / FAIL / PARTIAL | [step # hoac "—"] |

---

## Execution Plan

> Protocol 9 — Token estimate va checkpoint strategy

| Batch | Issues | Est. Tokens | Owner | Checkpoint |
|-------|--------|-------------|-------|------------|
| Batch 1 (CRITICAL) | X | ~(X x 10K) | skill (auto) | Sau batch 1 |
| Batch 2 (HIGH) | X | ~(X x 10K) | developer / domain-expert | Sau batch 2 |
| Batch 3 (MEDIUM + LOW neu exhaustive) | X | ~(X x 5K) | skill (auto) + agents | Sau batch 3 |
| Escalations (MANUAL_FIX/ESCALATE) | X | — | stakeholder review | escalations.json artifact |

**Resume point:** batch_number + last_fixed_issue_id
**Token estimate:** [tong] tokens
**Multi-session:** [Co / Khong] — [lý do neu co]

---

*Triage auto-generated by DEVKIT `/wf-fix-triage` Phase 2 (spawned bởi /wf-fix-bugs)*
