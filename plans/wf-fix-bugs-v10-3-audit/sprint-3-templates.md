# Sprint 3 — Template + Schema Compliance (wf-fix-bugs v10.3)

> **Started:** 2026-05-15
> **Completed:** 2026-05-15 ✅ DONE (7 commits, ~5h actual)
> **Owner:** Sprint 3 — Template + Schema Compliance
> **Scope:** 10 findings (~7h estimate; actual ~5h, -28%)
> **Audit:** `docs/wf-fix-bugs-audit-2026-05-15.md` §Sprint 3
> **Detail findings:** `.mc-data/audit/wf-fix-bugs-2026-05-15/findings-07-templates.md` + `findings-04-cross-references.md`

## Commits Summary

| Commit | Finding |
|---|---|
| `16f07e3c` | XF-04 — canonical STRIP pattern jq walk |
| `f97222d1` | XF-03 / F07.001 — fix-log.json canonical v2 |
| `289c08ba` | F07.003 + F07.011 — add $schema to 5 templates |
| `af94b7b9` | F07.009 — bug-triage + fix-report sync v10 |
| `5a1ef053` | F07.010 — fix-plan.md canonical v10 |
| `60771856` | F07.008 + F07.007 — archive lane-signal + clarify lane-report |
| `de99ef08` | F07.004 — 7 Phase{N}-report CORE-028 compliant |

## Sprint 3 Decision Note (F07.007 Audit Error)

Audit suggested archive `_shared/lane/templates/lane-report.md` nhưng phát hiện 11 QD lane skills (wf-fix-functional, wf-fix-security, wf-fix-performance, wf-fix-business, wf-fix-business-completeness, wf-fix-compat, wf-fix-data, wf-fix-integration, wf-fix-observability, wf-fix-runtime-health, wf-fix-ux-a11y) đang reference template này qua `_contract.json`. **Revised decision:** KHÔNG archive — thay vào đó document distinction qua HTML comment header trong CẢ 2 templates (lane-report.md serves QD lane skills, QD-report.md serves orchestrator inline rendering — schemas + scopes khác nhau).

## Mục tiêu

Đạt **CORE-031 + CORE-036 PASS** sau Sprint 3:
- Mọi JSON template có `$schema` field (CORE-036)
- STRIP pattern bảo vệ MỌI `_*` field (CORE-031, Protocol 19)
- Resolve dual template versions (1 canonical, archive legacy)
- 7 Phase{N}-report.md theo CORE-028 format

## Decision Points (Self-Decided — user delegated)

| # | Decision | Choice | Rationale |
|---|---|---|---|
| 1 | XF-04 STRIP pattern scope | **Document trong _shared.md §10 (canonical) + apply trong tất cả procedures dùng template→output flow** | BHV-002 simplicity: single source. Pattern `walk(... select(.key | startswith("_") | not))` cover mọi `_*` fields, an toàn |
| 2 | XF-03 fix-log.json v1 vs v2 | **v2 canonical** | `dashboard_generator.py` đã consume v2; `wf-fix-bugs/_contract.json` line 82 ghi v2; more operational info (action, result, file_changed, retry_count, error_code) |
| 3 | F07.009 dual bug-triage.md + fix-report.md | **Keep v10 minimal (29/28 lines), archive legacy** | v10 architecture chuộng templates concise; legacy 244/230 dòng pre-orchestrator era; archive vào `wf-fix-triage/templates/archive/` |
| 4 | F07.010 fix-plan.md dual | **Keep v10 minimal (36 lines), archive legacy v7 (320 lines)** | Same rationale as #3; legacy v7 chứa nhiều pipeline metadata redundant với fix-status.json |
| 5 | F07.007 lane-report.md vs QD-report.md | **QD-report.md canonical (v10), archive lane-report.md** | wf-fix-bugs/_contract.json line 73 đã reference `templates/phase4-find-bugs/QD-report.md` — canonical theo v10 architecture |

## Plan File-by-File

### F1. XF-04 — STRIP pattern jq filter (2h)

**Vấn đề:** `_template_notes` STRIP chỉ cover 2 fields chuẩn nhưng template có `_how_to_use`, `_example`, `_entry_schema_notes` (lồng).

**Hành động:**
- Update `_shared.md §10` Template Metadata Stripping → canonical jq filter pattern
- Update procedures referencing old pattern:
  - `phase1-init.md` (multiple places)
  - `phase2-scan.md:628-629`
  - `phase4-find-bugs.md:256, 321, 751`
  - `phase7-verify.md:538, 636`

**Pattern mới:**
```bash
jq 'walk(if type == "object" then with_entries(select(.key | startswith("_") | not)) else . end)' \
  "$TEMPLATE_PATH" > "$OUTPUT_PATH"
```

**Verify:** grep `_template_notes\|_schema_notes\|_how_to_use\|_example\|_entry_schema_notes` không còn trong runtime outputs.

**Status:** ✅ DONE

---

### F2. XF-03 / F07.001 — fix-log.json canonical v2 (1h)

**Vấn đề:** 3 nguồn conflict (v1 vs v2 schema, missing `$schema` field, broken procedure references).

**Hành động:**
- `wf-fix-bugs/templates/phase5-triage/fix-log.json`: ADD `"$schema": "fix-log-v2"` field (v2 spec retained)
- `_shared/lane/templates/fix-log.json`: ARCHIVE → `_shared/lane/templates/archive/fix-log-v1.json`
- `wf-fix-triage/_contract.json` line 58-59: update template path → `../wf-fix-bugs/templates/phase5-triage/fix-log.json`
- `procedures/phase5-triage.md`: update reference table label "fix-log-v1" → "fix-log-v2"

**Verify:** `jq -e '."$schema" == "fix-log-v2"' wf-fix-bugs/templates/phase5-triage/fix-log.json`

**Status:** ✅ DONE

---

### F3. F07.003 — fix-execution-result.json $schema (15min)

**Vấn đề:** Contract khai báo schema `fix-execution-result-v1` nhưng template không có `$schema` field.

**Hành động:** ADD `"$schema": "fix-execution-result-v1"` field vào `wf-fix-bugs/templates/phase6-execute/fix-execution-result.json`

**Verify:** `jq -e '."$schema" == "fix-execution-result-v1"' fix-execution-result.json`

**Status:** ✅ DONE

---

### F4. F07.011 — Add $schema vào 4 templates (30min)

**Vấn đề:** 4 templates khai báo schema trong contract nhưng template thiếu `$schema` field.

**Files:**
- `wf-fix-bugs/templates/phase5-triage/issue-registry.json` → `"$schema": "issue-registry-v2"`
- `wf-fix-bugs/templates/phase5-triage/cdg-tokens.json` → `"$schema": "cdg-tokens-v1"`
- `wf-fix-bugs/templates/phase5-triage/process-violations.json` → `"$schema": "process-violations-v1"`
- `wf-fix-bugs/templates/phase5-triage/safety-check.json` → `"$schema": "safety-check-v1"`

**Verify:** All 4 files pass `jq -e '."$schema"'`

**Status:** ✅ DONE

---

### F5. F07.009 — Resolve dual bug-triage.md + fix-report.md (30min)

**Vấn đề:**
- `wf-fix-triage/templates/bug-triage.md` (244 dòng legacy) vs `wf-fix-bugs/templates/phase5-triage/bug-triage.md` (29 dòng v10)
- `wf-fix-execute/templates/fix-report.md` (230 dòng legacy) vs `wf-fix-bugs/templates/phase6-execute/fix-report.md` (28 dòng v10)

**Hành động:**
- ARCHIVE `wf-fix-triage/templates/bug-triage.md` → `wf-fix-triage/templates/archive/bug-triage-v7.md`
- COPY `wf-fix-bugs/templates/phase5-triage/bug-triage.md` → `wf-fix-triage/templates/bug-triage.md` (sync v10)
- ARCHIVE `wf-fix-execute/templates/fix-report.md` → `wf-fix-execute/templates/archive/fix-report-v7.md`
- COPY `wf-fix-bugs/templates/phase6-execute/fix-report.md` → `wf-fix-execute/templates/fix-report.md` (sync v10)

**Status:** ✅ DONE

---

### F6. F07.010 — Resolve fix-plan.md dual (30min)

**Vấn đề:** v10 36 dòng (wf-fix-bugs canonical) vs v7 320 dòng (_shared/lane legacy).

**Hành động:**
- ARCHIVE `_shared/lane/templates/fix-plan.md` → `_shared/lane/templates/archive/fix-plan-v7.md`
- `wf-fix-triage/_contract.json` line 46-47: update template → `../wf-fix-bugs/templates/phase5-triage/fix-plan.md`

**Status:** ✅ DONE

---

### F7. F07.008 — Delete orphan lane-signal.json (10min)

**Vấn đề:** `_shared/lane/templates/lane-signal.json` không reference từ skill/contract/procedure nào.

**Hành động:** ARCHIVE → `_shared/lane/templates/archive/lane-signal-orphan.json` (per anti-pattern §9: archive thay delete)

**Verify:** `grep -rn "lane-signal.json"` empty (sau khi archive)

**Status:** ✅ DONE

---

### F8. F07.007 — Resolve lane-report.md vs QD-report.md (30min)

**Vấn đề:** `_shared/lane/templates/lane-report.md` (164 dòng) vs `wf-fix-bugs/templates/phase4-find-bugs/QD-report.md` (33 dòng).

**Hành động:**
- KEEP `QD-report.md` (canonical, wf-fix-bugs contract line 73 đã reference)
- ARCHIVE `_shared/lane/templates/lane-report.md` → `_shared/lane/templates/archive/lane-report-v1.md`

**Status:** ✅ DONE

---

### F9. F07.004 — 7 Phase-report templates CORE-028 (1h)

**Vấn đề:** 7/7 reports dùng `# Phase N Report:` (H1) thay vì `## Phase [N]: ... — PASS|FAIL` (H2). Thiếu `**Đã làm:**`, `**Kết quả:**`, `**Tiếp theo:**` sections. Line count 21-35 > 15.

**Hành động:** Update 7 templates theo CORE-028 format:
- `phase1-init/Phase1-report.md`
- `phase2-scan/Phase2-report.md`
- `phase3-plan/Phase3-report.md`
- `phase4-find-bugs/Phase4-report.md`
- `phase5-triage/Phase5-report.md`
- `phase6-execute/Phase6-report.md`
- `phase7-verify/Phase7-report.md`

**Format chuẩn:**
```markdown
## Phase [N]: [Tên Phase] — PASS|FAIL

Thời gian: [STARTED_AT] → [COMPLETED_AT]

**Đã làm:** [1-2 câu mô tả]

**Kết quả:** [Số liệu chính] + [File đầu ra chính]

**Tiếp theo:** [Phase kế tiếp hoặc hành động user]
```

**Status:** ✅ DONE

---

## Validation Strategy

User instructed: compliance audit + schema-sync scripts có thể chưa chính xác. Approach:
- **File-level verification per finding** (jq, grep, content check trực tiếp)
- Scripts dùng làm cross-check cuối cùng, không phải source of truth
- Mỗi commit pre-validate qua jq cho JSON, grep cho cross-refs

## Commit Pattern

```
fix({scope}): {one-line summary} [F0X.0YY]

{2-3 dòng giải thích Vietnamese}

Audit: docs/wf-fix-bugs-audit-2026-05-15.md F0X.0YY
```

## Acceptance Criteria

Sprint 3 DONE khi:
- ✅ Tất cả 10 findings có commit reference
- ✅ Mọi JSON template có `$schema` field
- ✅ STRIP pattern documented trong `_shared.md §10`
- ✅ Dual versions resolved (1 canonical, archive legacy)
- ✅ 7 Phase-report templates conform CORE-028
- ✅ Audit report append "Sprint 3 Closed YYYY-MM-DD"
