# Sprint 9 — Procedure Logic + Cleanup (wf-fix-bugs v10.3) — DONE

**Status:** DONE
**Closed:** 2026-05-15 (single session ~4h actual)
**Regression:** 1015 pass, 10 skipped (baseline Sprint 8 preserved)
**Schema sync:** PASS (`validate-schema-sync.sh wf-fix-bugs`)
**Sprint kick-off:** 2026-05-15 (sau Sprint 8 closure cùng ngày)
**Owner:** kỹ sư MCV3 senior
**Estimate:** ~4h | **Scope:** 9 findings F08.* + F03.014 cho code organization, DRY, traceability

---

## Mục tiêu

Áp dụng 9 findings procedure logic — DRY (F08.015), step split (F08.018), CDG persist (F08.016), step rename (F08.020), TRACE FAIL (F08.021), resume partial (F08.022), audit path doc (F08.030), Process Integrity naming (F08.009), context budget impl (F03.014). **CHỈ touch DOCUMENTATION/PROCEDURE** — KHÔNG đổi runtime semantic, KHÔNG move runtime files.

## Drift detection (BHV-001 — verify trước action)

| # | Finding | Audit nói | Thực tế (verified 2026-05-15) | Action |
|---|---------|-----------|--------------------------------|--------|
| 1 | F08.015 | bug-dashboard duplicated 4 lần | confirmed: phase1-init Step ~1.x, phase5-triage Step 5.11b, phase6-execute Step 6.7b, phase7-verify Step ~7.x | APPLY |
| 2 | F08.018 | Step 6.4 (178 dòng) → tách 6.4a Impact / 6.4b Risk / 6.4c CDG | **DRIFT**: Step 6.4 (276-449 = 173 dòng) ĐÃ ĐƯỢC tách 6.4a Detect Fast Path / 6.4b Fast Path / 6.4c Slow Path / 6.4d CDG render / 6.4e ci-impact-report. Schema audit khác hiện tại. | DOC DRIFT, NO ACTION |
| 3 | F08.016 | append cdg-tokens.json explicit cho 6 CDGs Phase 1 | confirmed: Phase 1 có 5 CDGs (E090, E090b, E091, E092, E093) + E013 legacy = 6. Hiện chỉ ghi vào variables `$CDG_E0**_DECISION`, KHÔNG persist `cdg-tokens.json` (Phase 5 mới append). | APPLY (add pattern) |
| 4 | F08.020 | Rename Step 5.11b → 5.12, shift 5.12-5.14 → 5.13-5.15 | confirmed: phase5-triage line 692 (Step 5.11), 761 (Step 5.11b), 841 (Step 5.12), 893 (Step 5.13), 930 (Step 5.14) | APPLY |
| 5 | F08.021 | TRACE FAIL explicit pattern Phase 7 | confirmed: phase7-verify chỉ có TRACE START (Step 7.2) + TRACE COMPLETE (Step 7.11), KHÔNG có TRACE FAIL explicit | APPLY |
| 6 | F08.022 | Resume R5 handle partial outputs (MOVE → `partial-{timestamp}/`) | confirmed: resume-status.md R5 line 58 chỉ tìm resume point, KHÔNG xử lý phase `in_progress` có partial outputs | APPLY |
| 7 | F08.030 | MOVE `path-audit-report.md` + `phase2-scan-audit-report.md` → `.mc-data/audit/` | **DRIFT**: grep toàn bộ SKILL.md + procedures KHÔNG thấy 2 file này. Không có path nào cần đổi. | DOC DRIFT, NO ACTION |
| 8 | F08.009 | Phase 5 C1-C5 → PI1-PI5 (Process Integrity) | confirmed: Step 5.5 line 284, comments line 297-339 dùng C1/C2/C3/C4/C5 | APPLY |
| 9 | F03.014 | CORE-038 Phase 4 context budget stub | confirmed: phase4-find-bugs Step 4.6 line 558-559 chỉ có 2 dòng comment placeholder, KHÔNG có logic | APPLY (replace stub) |

**Tổng:** 7 findings APPLY + 2 DRIFT (document only).

## Decision points (user confirmed batch trước execute)

1. **F08.015 style:** Inline cross-ref `> See _shared.md §dashboard-update`
2. **F08.020 method:** Manual Edit + grep cross-refs (SKILL.md routing table verify)
3. **F03.014 impl:** Match wf-fix-bugs SKILL.md `_shared.md §9` context-budget pattern

## Plan execute

| # | Finding | File | Effort | Status |
|---|---------|------|--------|--------|
| 0 | Baseline verify | — | 5min | DONE (1015 tests pass) |
| 1 | F08.030 (drift) | (none) | 0min | DOC DRIFT — audit reports not present |
| 2 | F08.018 (drift) | (none) | 0min | DOC DRIFT — Step 6.4 đã tách 6.4a/b/c/d/e |
| 3 | F08.015 centralize | `_shared.md §19` + 4 phase cross-refs | 45min | DONE |
| 4 | F08.016 CDG append | `phase1-init.md` Step 1.16b + `_shared.md §20` + 5 cross-refs | 30min | DONE |
| 5 | F08.020 rename | `phase5-triage.md` 5.11b→5.12, 5.12→5.13, 5.13→5.14, 5.14→5.15 + cross-refs (SKILL.md, _contract.json, _shared.md) | 20min | DONE |
| 6 | F08.009 PI naming | `phase5-triage.md` + `_contract.json` + `SKILL.md` + 2 templates (Phase5-report.md, process-violations.json) | 30min | DONE |
| 7 | F08.022 partial | `resume-status.md` R5 + Partial Output Handling section | 30min | DONE |
| 8 | F08.021 TRACE FAIL | `phase7-verify.md` Standard TRACE FAIL Pattern + 6 error codes updated | 20min | DONE |
| 9 | F03.014 context budget | `phase4-find-bugs.md` Step 4.6 stub → 3-tier CORE-038 implementation | 30min | DONE |
| 10 | Regression + closure | run-tests + skill-audit + schema-sync | 30min | DONE |

**Actual estimate:** ~4h (1 single session).

## Acceptance criteria

✅ 7 findings applied + 2 drift documented
✅ `bash run-tests.sh --fast` PASS 1015 tests (regression vs Sprint 8 baseline)
✅ `bash .claude/scripts/skill-compliance-audit.sh wf-fix-bugs` clean
✅ Audit report append "Sprint 9 Closed YYYY-MM-DD"
✅ 6-9 commits trên master (per finding hoặc nhóm logically related)

## Risks & Mitigation

| Risk | Mitigation |
|------|-----------|
| F08.020 step rename phá SKILL.md routing | Grep cross-refs SKILL.md + _contract.json + tất cả procedure trước commit |
| F08.009 C1-C5 → PI1-PI5 phá error code mapping | Verify chỉ comments/labels đổi, error code E052 giữ nguyên |
| F08.016 CDG append phá schema cdg-tokens-v1 | Sử dụng cùng schema Phase 5 (`{$schema, tokens:[]}`) — atomic write pattern |
| F03.014 stub replace phá monitor loop | Match _shared.md §9 thresholds — không thay logic poll |
| Regression Python test | Sprint 9 KHÔNG touch Python/bash — chỉ markdown procedure → low risk |
