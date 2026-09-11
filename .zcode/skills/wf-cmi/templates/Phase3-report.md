<!--
_schema_notes:
  purpose: Phase 3 (Invariant Artifact — 3-pass LLM inference) report. CORE-028 ≤15 dòng tiếng Việt.
  rules:
    - Max 15 dòng total
    - Tiếng Việt, không jargon
    - 3-pass output: pattern (Pass 1) → domain heuristic (Pass 2) → registry gap (Pass 3)
    - Note: Phase 3 produce DRAFT artifact; CANONICAL APPEND tại Phase 7 sau CDG
  delete_before_write: true
-->
## Phase 3: Invariant Artifact (3-pass LLM) — [STATUS_PASS_FAIL]

Thời gian: [STARTED_AT] → [COMPLETED_AT] ([DURATION_SEC]s)

**Đã làm:** Infer business invariants 3 lượt: Pass 1 cross-module pattern compare ([N_PASS1] candidates), Pass 2 domain heuristic ([N_DOMAINS] experts: [DOMAINS], output [N_PASS2] candidates), Pass 3 registry gap detection ([N_PASS3] invariants ưu tiên).

**Kết quả:** [N_INVARIANTS] invariant candidates DRAFT — MUST: [N_MUST], SHOULD: [N_SHOULD], MAY: [N_MAY]. Cross-module deps: [N_CMD]. Confidence distribution: HIGH (≥0.8): [N_HIGH], MED: [N_MED], LOW: [N_LOW]. File đầu ra: business-invariants.json (DRAFT) + invariants-diff.json.

**Tiếp theo:** Phase 4 — Coverage Dispatch (spawn [N_LANES] lane agents PARALLEL CD1-CD10).

[NẾU FAIL/CDG E091 (cross-domain conflict):]
**Vấn đề:** [ERROR_MESSAGE]
**Cách xử lý:** [CDG_RESOLUTION | RETRY_PLAN]
