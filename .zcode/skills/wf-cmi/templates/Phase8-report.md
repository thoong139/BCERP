<!--
_schema_notes:
  purpose: Phase 8 (Report — build artifacts, release lock, mark session COMPLETED) report. CORE-028 ≤15 dòng tiếng Việt.
  rules:
    - Max 15 dòng total
    - Tiếng Việt, không jargon
    - Summary: artifacts produced + session COMPLETED + next step cho 4 consumers downstream
  delete_before_write: true
-->
## Phase 8: Report — [STATUS_PASS_FAIL]

Thời gian: [STARTED_AT] → [COMPLETED_AT] ([DURATION_SEC]s)
Pipeline duration tổng: [PIPELINE_DURATION_SEC]s

**Đã làm:** Build báo cáo user-facing `integrity-report.md` (≤30 dòng tiếng Việt) + cross-skill artifact `integrity-impact.json` (schema integrity-impact-v1, audit_chain checksum). Update session-log COMPLETED, release lock, append vào _index/sessions.jsonl.

**Kết quả:**

- Coverage: [OVERALL_PCT]% / [N_VIOLATIONS] violations / [N_ACCEPTED] artifacts ACCEPT
- File chính: integrity-report.md + integrity-impact.json (consumed bởi 4 skills downstream qua --from-cmi)
- Sidecar APPEND: [N_INV_APPENDED] invariants mới tại `.mc-data/work/wf-cmi/business-invariants.json`

**Tiếp theo (4 consumers):**

- wf-verify-sync --from-cmi: re-validate impl_status vs invariants mới
- wf-fix-bugs --from-cmi: seed Phase 1 với [N_MUST] MUST violations
- wf-implement-feature --from-cmi: warn nếu touch affected modules
- wf-prepare-deployment --from-cmi: [DEPLOY_RECOMMENDATION]

[NẾU FAIL (vd E083 cannot write artifact):]
**Vấn đề:** [ERROR_MESSAGE]
**Cách xử lý:** [RECOVERY_PLAN]
