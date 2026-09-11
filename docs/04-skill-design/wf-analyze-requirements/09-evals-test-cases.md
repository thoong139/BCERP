# 09 — Evals & Test Cases

> **Mục đích file:** 20 evals match `evals/evals.json` — bao phủ domain (CRM/ERP/Healthcare/Logistics), workflows, ADR-OPTs, error handling.

---

## 1. Bảng test cases (20 evals)

### Core workflows (1-10)

| ID | Type | Mục đích |
|----|------|----------|
| 1 | integration | ERP project full run — BA trước, experts parallel, registry update |
| 2 | resume | `--resume` từ checkpoint giữa phase |
| 3 | scope | `scope=business` CRM — chỉ business, skip 6b/6c/6d |
| 4 | conflict | Phase 6d phân loại findings (AUTO/EXPERT/DEFER) |
| 5 | registry | Phase 8 update direct (NO AGENT), valid JSON, counts match |
| 6 | crossval | Phase 8b 8 validation checks, auto-correction loop |
| 7 | escalate | Auto-fix fail sau 3 iterations → STOP với error report |
| 8 | error | Chưa có `.mc-data/` → E000/E016, STOP ngay |
| 9 | scope | `scope=MOD-SALES` targeted single module |
| 10 | resume | Resume từ Phase 3 done → preserve existing Phần A, complete Phase 4+ |

### Domain-specific (11-14)

| ID | Type | Mục đích |
|----|------|----------|
| 11 | domain | CRM Sales — sales/marketing/customer/finance experts |
| 12 | domain | Healthcare — healthcare-expert + finance (BHYT), compliance |
| 13 | domain | Logistics — logistics/operations experts, TMS+WMS systems |
| 14 | legacy | LEGACY_MODE — merge existing dept docs, preserve REQ-IDs cũ |

### ADR-OPT integration (15-20)

| ID | Type | Mục đích |
|----|------|----------|
| 15 | session | **ADR-OPT-02** Session Isolation — 2 runs khác `sessions/{id}/`, `latest` trỏ mới nhất |
| 16 | workload | **ADR-OPT-03** Workload Gate dead_zone silent continue |
| 17 | workload | **ADR-OPT-03** Workload Gate block + CDG-A02 Override |
| 18 | lane | **ADR-OPT-01** Lane Dispatch parallel writes — 5 lanes isolated |
| 19 | aggregate | **ADR-OPT-04** Signal Aggregator dedup REQ-SHARED-001 từ 2 lanes |
| 20 | strip | **ADR-OPT-05** Template strip — canonical KHÔNG leak `_*` keys |

---

## 2. Test case detail (extract)

### TC-01 — ERP full run

**Setup:** ERP project với 5 departments, P0-01-brainstorm.md đầy đủ.

**Run:** `/wf-analyze-requirements`

**Expected:**
1. PRE-GATE: req-registry.json + P0-01-brainstorm.md exist (E000/E016 guard)
2. Phase 3: spawn `business-analyst` TRƯỚC
3. Phase 4: spawn parallel domain-experts (sales/marketing/customer/finance/operations)
4. Phase 6b: P1-02-business-workflow.md
5. Phase 6c: stakeholder-review.md
6. Phase 8: registry update DIRECT (NO AGENT), chỉ update `systems[]`, `modules[]`, `departments[]`, `requirements[]`, `interface_type` — KHÔNG `features[]`
7. Report cuối: số REQ-IDs + suggest `/wf-define-features`

**Pass criteria:** 10 assertions trong evals.json id=1 PASS.

### TC-15 — Session Isolation (ADR-OPT-02)

**Setup:** Same project, chạy 2 lần liên tiếp (không `--resume`).

**Expected:**
1. Run 1: `sessions/{id1}/session-state.json` non-empty
2. Run 2: tồn tại 2 directories `sessions/{id1}/` và `sessions/{id2}/`
3. `latest` pointer trỏ `sessions/{id2}/`
4. Session cũ (id1) preserve — `session-state.json` không bị reset, `workload-report.md` không bị ghi đè
5. `id1 != id2` (timestamp-based khác nhau)

**Pass criteria:** CORE-030 Working Directory Session Isolation honored.

### TC-17 — Workload Gate block + CDG-A02 (ADR-OPT-03)

**Setup:** Project lớn (≥10 departments, ≥50 requirements) → ratio > 1.5.

**Expected:**
1. Phase 0.5 ratio > 1.5 → BLOCK
2. AskUserQuestion với ≥2 options (Plan A narrow scope / Plan B Override)
3. User chọn Override → tạo `cdg-tokens.json` với `cdg_id="CDG-A02-workload-override"`, `decision="accept"`, user acknowledged
4. Skill continue Phase 1+ với flag `override=true`
5. Nếu chọn Plan A → STOP với hướng dẫn revise brainstorm

### TC-18 — Lane Dispatch parallel writes (ADR-OPT-01)

**Setup:** 5 departments, 5 domain-experts khác nhau.

**Expected:**
1. `sessions/{id}/lanes/` có 5 subdirs (1 per dept-expert pair)
2. Mỗi lane có `signals.json` non-empty, schema `lane-signal-v1`
3. `lane_keys` unique across 5 lanes
4. `items[]` giữa lanes không overlap (mỗi item chỉ thuộc 1 lane)
5. `session-log.json` KHÔNG có file lock/write conflict errors
6. CORE-025 honored: ownership rõ, isolated write scope, stable contract

### TC-20 — Template Strip (ADR-OPT-05)

**Setup:** ERP full run, Phase 8c chạy.

**Expected:**
1. `.mc-data/docs/_meta/dept-digests.json` valid JSON
2. KHÔNG chứa keys: `_template_notes`, `_comments`, `_examples`, `_placeholder`, `_description`
3. `_meta/phase1-handoff.json` cũng KHÔNG chứa các keys trên
4. Template file gốc (`_digests/dept-digests.template.json`) VẪN GIỮ các helper keys (chỉ canonical bị strip)
5. Strip áp dụng đệ quy (nested objects/arrays)
6. CORE-031: READ template → POPULATE → STRIP → WRITE canonical

---

## 3. Eval criteria

### Pass criteria

| Criteria | Threshold |
|----------|-----------|
| PRE-GATE/POST-GATE T1-T4 PASS | 100% |
| Registry safe-write — chỉ fields_owned modified | 100% |
| BA chạy TRƯỚC experts | 100% |
| Lanes write isolation — 0 race condition | 100% |
| Phase 8b auto-fix loop ≤3 iterations | 100% |
| Template strip — canonical KHÔNG có `_*` keys | 100% |
| Phase 1 docs valid + format đúng | 100% |
| Context budget | <80% (smoke), <90% (full ERP) |

### Fail criteria

| Criteria | Verdict |
|----------|---------|
| BA spawn parallel với experts từ đầu | FAIL |
| Registry `features[]` bị modify | FAIL |
| Registry `impl_status` bị modify | FAIL |
| Sessions overwrite cũ (CORE-030 violated) | FAIL |
| Phase 8b loop > 3 không STOP | FAIL |
| `_*` keys leak vào canonical `_meta/dept-digests.json` | FAIL |
| Lane signals write outside sub-dir của mình | FAIL |

---

## 4. Coverage matrix

| | NEW | LEGACY | scope=all | scope=business | scope=module |
|---|-----|--------|-----------|---------------|--------------|
| **CRM** | TC-03, TC-11 | — | TC-11 | TC-03 | — |
| **ERP** | TC-01, TC-04, TC-05, TC-06, TC-07 | — | TC-01 | — | TC-09 |
| **Healthcare** | TC-12 | — | TC-12 | — | — |
| **Logistics** | TC-13 | — | TC-13 | — | — |
| **Legacy** | — | TC-14 | TC-14 | — | — |
| **Session iso** | TC-15 | — | — | — | — |
| **Workload** | TC-16, TC-17 | — | TC-16, TC-17 | — | — |
| **Lane** | TC-18 | — | TC-18 | — | — |
| **Aggregate** | TC-19 | — | TC-19 | — | — |
| **Template strip** | TC-20 | — | TC-20 | — | — |
| **Resume** | TC-02, TC-10 | — | TC-10 | — | — |
| **Error** | TC-08 | — | TC-08 | — | — |

---

## 5. Eval execution

```bash
# Chạy 1 test case
./.claude/scripts/audit/run-skill-evals.sh wf-analyze-requirements --test-id=1

# Chạy tất cả 20 evals
./.claude/scripts/audit/run-skill-evals.sh wf-analyze-requirements --all

# Domain-specific fixtures
ls skills-test-workspace/wf-analyze-requirements-workspace/fixtures/
# tc1-crm-sales/, tc2-hospital-mgmt/, tc3-logistics-platform/, tc4-from-legacy-scan/
```

---

## 6. Liên kết

- Eval schema: [`.claude/scripts/audit/EVAL-SCHEMA.md`](../../../.claude/scripts/audit/EVAL-SCHEMA.md)
- Eval source: [`.claude/skills/workflow/wf-analyze-requirements/evals/evals.json`](../../../.claude/skills/workflow/wf-analyze-requirements/evals/evals.json)
- Standards: [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md) §7
- Review checklist: [`../../05-review-standards/wf-analyze-requirements.md`](../../05-review-standards/wf-analyze-requirements.md)
