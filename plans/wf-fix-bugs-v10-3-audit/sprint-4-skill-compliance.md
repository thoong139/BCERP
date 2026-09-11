# Sprint 4 — SKILL.md Compliance + Architecture (wf-fix-bugs v10.3)

> **Started:** 2026-05-15
> **Completed:** 2026-05-15 ✅ DONE (6 commits, single session)
> **Owner:** Sprint 4 — SKILL.md Compliance + Architecture (CORE-032)
> **Scope:** 6 findings (~8h estimate; actual ~3h)
> **Audit:** `docs/wf-fix-bugs-audit-2026-05-15.md` §Sprint 4 + §XF-07
> **CORE Standards:** CORE-032 (Lazy-Load Procedures), CORE-007 (Cross-Skill Output Path), CORE-036 (Cross-Skill Artifact Contract), CORE-037 (Agent Prompt Templates)

## State Verified (2026-05-15)

| File | Lines | CORE-032 Limit | Over | Status |
|---|---|---|---|---|
| `wf-fix-bugs/SKILL.md` | 588 | 500 | +88 | NEEDS EXTRACTION |
| `wf-fix-triage/SKILL.md` | 556 | 500 | +56 | NEEDS EXTRACTION |
| `wf-fix-execute/SKILL.md` | 512 | 500 | +12 | NEEDS TRIM |

**Procedure directories verified:**
- `wf-fix-bugs/procedures/`: ✅ 9 files (_shared, phase1-7, resume-status)
- `wf-fix-execute/procedures/`: ✅ 9 files (_shared, phase3-6 + sub-batches)
- `wf-fix-triage/procedures/`: ⚠️ Chỉ có `phase2-triage.md` — thiếu `_shared.md` + `resume-status.md` (F01.017)

**Drift verified:**
- Templates wf-fix-bugs: SKILL.md ghi "32", disk có 36 files (F04.004 confirmed)
- Step counts wf-fix-bugs: SKILL.md (23/14/10) vs actual procedures (25/15/11) for Phase 1/5/6 (F08.003-004 confirmed)
- `agents/README.md` EXISTS (312 dòng) — chưa có SDK Runtime section (F02.001 confirmed)

## Decision Points Confirmed (User 2026-05-15)

1. **XF-07b strategy:** Extract PRE-GATE chi tiết (~100 dòng lines 96-194) → `wf-fix-triage/procedures/_shared.md`; POST-GATE T5/T6 jq scripts + escalations builder (~100 dòng lines 302-401) → `procedures/phase2-triage.md`. Giữ summary table + pointer.
2. **`_shared.md` content source:** Reference sang `wf-fix-bugs/procedures/_shared.md` cho cross-cutting concerns (state vars, atomic write, error handling, CI). File chỉ chứa sections đặc thù triage (CI-ROUTE Bug Investigation, POST-GATE T5/T6 patterns).
3. **XF-07c strategy:** Compact Phase Summary 7 phases (lines 189-321) từ 17-21 dòng/phase xuống 5-7 dòng/phase. Extract Namespace Convention (~12 dòng) → pointer to `_shared.md §4`. Save ~80-90 dòng.
4. **F02.001 location:** Section mới "SDK Runtime Agent Types" sau `## Domain Expert Routing` và trước `## Tools Summary`.

## Findings & Status

| # | Finding | Effort (est → actual) | Strategy | Status | Commit |
|---|---|---|---|---|---|
| 1 | **XF-07a** | 30min → ~10min | Audit "xóa Version History" stale (block không còn tồn tại). Thay vào: compact v9.2.0 Context Injection (4 bash blocks → 4-row table). **512 → 483** | ✅ DONE | `b8302941` |
| 2 | **F08.003-004** | 15min → ~5min | Edit step count literals + References table sync | ✅ DONE | `975534cd` |
| 3 | **F04.004** | 30min → ~15min | "32 templates" → 36 (3 places); thêm 3 missing files (probe-failures-log, bug-dashboard, fix-execution-result) vào Output table; renumber rows 17-35 | ✅ DONE | `72444944` |
| 4 | **XF-07b** | 3h → ~45min | Extract PRE-GATE (100 dòng) → Summary table + `procedures/_shared.md §T1`; POST-GATE T1-T6 jq + escalations builder → `phase2-triage.md` (append); tạo `_shared.md` (71 dòng, reference wf-fix-bugs no dual source) + `resume-status.md` (86 dòng). **556 → 411** | ✅ DONE | `e34d7ee7` |
| 5 | **XF-07c** | 3h → ~30min | Verify CI PRE-GATE + Error Codes đã condensed (audit stale). Compact Phase Summary 7 phases (133 dòng) thành 1 combined table 7 rows × 6 cols. **591 → 476** | ✅ DONE | `73d42ebc` |
| 6 | **F02.001** | 30min → ~15min | Add 'SDK Runtime Agent Types' section sau Domain Expert Routing, trước Tools Summary | ✅ DONE | `42cf2153` |

## Quality Gates (DỪNG nếu gặp)

- ❌ SKILL.md sau extract vẫn >500 dòng → re-evaluate strategy
- ❌ Extract làm mất pointer/contract (output path, gate marker biến mất)
- ❌ Procedure file mới tạo trùng nội dung file đã có (dual source of truth)
- ❌ `_contract.json` procedure[] array không khớp procedure files thực tế

## Completion Criteria — ALL MET ✅

- ✅ Tất cả 6 findings → commit + status DONE
- ✅ `wf-fix-bugs/SKILL.md` = **476 dòng** ≤ 500
- ✅ `wf-fix-triage/SKILL.md` = **411 dòng** ≤ 500 + có `procedures/_shared.md` (71) + `procedures/resume-status.md` (86)
- ✅ `wf-fix-execute/SKILL.md` = **483 dòng** ≤ 500
- ✅ Step counts SKILL.md khớp procedures (Phase 1/5/6 = 25/15/11)
- ✅ Template count SKILL.md = 36 (verified disk has 36 non-archive files), Output table có 3 missing files (35 rows)
- ✅ `agents/README.md` document SDK runtime types (`claude` + `general-purpose`)
- ✅ Output paths preserved (34 phase paths trong SKILL.md)
- ✅ Gate markers preserved (51 occurrences POST-GATE/PRE-GATE/CQG/CDG)
- ✅ Cross-skill artifact `fix-impact.json` reference preserved
- ✅ Audit report append "Sprint 4 Closed 2026-05-15"

## Decision Notes

**XF-07a audit drift:** Audit recommend "xóa Version History block lines 495-512" nhưng block đó không còn tồn tại (đã xóa từ Sprint trước). Verify state thực tế: lines 500-512 là Related Skills + Next sections. Pivoted: compact v9.2.0 Context Injection (lines 141-178, 38 dòng bash blocks a/b/c/d) thành 4-row table với pointer sang `procedures/_shared.md#v920-source-aware-fix-protocol`. Bài học (giống Sprint 3 F07.007): LUÔN verify state thực tế trước khi sửa.

**XF-07c audit drift:** Audit nói "Extract CI PRE-GATE 3-step narrative + Error Codes narrative" — nhưng cả 2 đã được condensed từ Sprint trước (CI PRE-GATE 20-dòng table, Error Handling 45 dòng với pointer + Quick Lookup). Không có narrative dài để extract. Pivoted: compact Phase Summary 7 phases (133 dòng) thành 1 condensed table — cùng mục tiêu CORE-032 compliance, không phá contract.

**XF-07b new procedure files:** `_shared.md` chọn strategy "reference wf-fix-bugs/procedures/_shared.md" (Decision Point 2) để tránh dual source of truth (F02.002). Chỉ có 3 sections đặc thù triage: §T1 CI-ROUTE Bug Investigation, §T2 POST-GATE Tiered Validation Pattern, §T3 Output Schema References.
