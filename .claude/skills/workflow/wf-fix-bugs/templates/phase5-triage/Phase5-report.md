## Phase 5: Classify & Triage — [STATUS_PASS_FAIL]

Thời gian: [STARTED_AT] → [COMPLETED_AT]
Session ID: [SESSION_ID]

**Đã làm:** Aggregate [RAW_SIGNALS] raw signals → dedup còn [DEDUPED_SIGNALS]. Spawn wf-fix-triage để classify severity + fixability + domain. Process integrity check (PI1-PI5). CDG handoff trước Phase 6.

**Kết quả:** [TOTAL_ISSUES] issues. Severity: Critical [CRITICAL] / High [HIGH] / Medium [MEDIUM] / Low [LOW]. Fixability: Auto [AUTO] / Manual [MANUAL] / Deferred [DEFERRED]. CDG: [CDG_DECISION] ([TOKENS_ACCEPTED]/[TOKENS_TOTAL] accept). Safety: [SAFETY_ALL_PASS]. File đầu ra: issue-registry.json + bug-triage.md + fix-plan.md + fix-log.json + cdg-tokens.json + safety-check.json + process-violations.json.

**Tiếp theo:** Phase 6 — Execute Fix (wf-fix-execute spawn agents fix theo plan).
