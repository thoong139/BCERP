<!--
_schema_notes:
  purpose: Phase 1 (Init + CI PRE-GATE) report. CORE-028 ≤15 dòng tiếng Việt.
  rules:
    - Max 15 dòng total
    - Tiếng Việt, không jargon
    - 4 fields: Đã làm, Kết quả, Tiếp theo, Vấn đề (nếu có)
  delete_before_write: true
-->
## Phase 1: Init + CI PRE-GATE — [STATUS_PASS_FAIL]

Thời gian: [STARTED_AT] → [COMPLETED_AT]
Session ID: [SESSION_ID]

**Đã làm:** Khởi tạo phiên `wf-cmi` với scope [SCOPE_TYPE] [MODULES], profile [PROFILE]. Validate 16 args, kiểm tra CI tools (GitNexus: [GITNEXUS_STATUS], Serena: [SERENA_STATUS]), check index freshness [CI_FRESHNESS], thu thập CDG buffer (E091/E090b).

**Kết quả:** Session lock + heartbeat OK. Dimensions active: [DIMS_ACTIVE] ([N_LANES] lanes). Author: [GIT_USER_EMAIL] @ branch [GIT_BRANCH]. File đầu ra: integrity-status.json + session-log.json + error-ledger.json.

**Tiếp theo:** Phase 2 — Discovery (build 6 graphs: entity/module/workflow/api/event/rbac PARALLEL).

[NẾU FAIL:]
**Vấn đề:** [ERROR_MESSAGE] (error code [ERROR_CODE])
**Cách xử lý:** [RECOVERY_PLAN]
