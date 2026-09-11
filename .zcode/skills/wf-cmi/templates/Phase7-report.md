<!--
_schema_notes:
  purpose: Phase 7 (GAP + CDG — gap detection + user decisions + sidecar APPEND) report. CORE-028 ≤15 dòng tiếng Việt.
  rules:
    - Max 15 dòng total
    - Tiếng Việt, không jargon
    - Summary: detected gaps + CDG decisions + sidecar APPEND count
    - Note: multi-user E095 dual-approval nếu 2 dev cùng touch invariant
  delete_before_write: true
-->
## Phase 7: GAP + CDG — [STATUS_PASS_FAIL]

Thời gian: [STARTED_AT] → [COMPLETED_AT] ([DURATION_SEC]s)

**Đã làm:** Detect GAP per-dim ([N_GAPS] gaps), spawn triage agent generate [N_TOTAL] suggestions. CDG hỏi user quyết định mỗi suggestion (ACCEPT/REJECT/DEFER). Sidecar artifact `business-invariants.json` APPEND [N_INV_APPENDED] entry mới (sau lock WRITE).

**Kết quả:**

- Total suggestions: [N_TOTAL]
- ACCEPTED: [N_ACCEPTED] (test: [N_TEST], invariant: [N_INV], API: [N_API], doc: [N_DOC])
- REJECTED: [N_REJECTED] (lý do log đầy đủ tại cdg-decisions.jsonl)
- DEFERRED: [N_DEFERRED] (chờ session sau)
- Multi-user dual-approval (E095): [N_DUAL_APPROVAL] decisions

**Tiếp theo:** Phase 8 — Report (build integrity-report.md + integrity-impact.json cross-skill).

[NẾU FAIL (vd E094 sidecar APPEND lock timeout):]
**Vấn đề:** [ERROR_MESSAGE]
**Cách xử lý:** [RECOVERY_PLAN | RETRY_WITH_BACKOFF]
