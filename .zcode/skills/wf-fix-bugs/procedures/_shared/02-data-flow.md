# §2 Cross-Phase Data Flow

```
Phase 1 (Init)        → fix-status.json, session-log.json, error-ledger.json,
                         .lock (acquired), $SESSION_ID, $DIMS_ARRAY, $PROFILE,
                         $SCOPE, $LEGACY_MODE, $CI_CONTEXT, $SHOW_BROWSER,
                         $MOBILE_MODE, Phase1-report.md,
                         bug-dashboard.md (khởi tạo rỗng — session root)

Phase 2 (Scan)        → scope-analysis.json, code-inventory.json,
                         doc-inventory.json, $INTERFACE_TYPE,
                         $SCOPE_INVENTORY, Phase2-report.md

Phase 3 (Plan)        → work-plan.json, dimension-plan.json,
                         workloads/W{N}/fix-workload.json,
                         $EXECUTION_MODE, Phase3-report.md

Phase 4 (Find Bugs)   → lanes/QD{n}/static-scan/signals.json,
                         lanes/QD{n}/runtime/signals.json,
                         lanes/QD{n}/llm-scan/signals.json,
                         lanes/QD{n}/lane-status.json,
                         lanes/QD{n}/QD{n}-report.md,
                         probe-failures.log, Phase4-report.md

Phase 5 (Triage)      → issue-registry.json, bug-triage.md, fix-plan.md,
                         fix-log.json, cdg-tokens.json, safety-check.json,
                         process-violations.json, coverage-report.md,
                         ../bug-dashboard.md (populate dữ liệu issues — session root),
                         $TOTAL_ISSUES, Phase5-report.md

Phase 6 (Execute)     → fix-report.md, docs-sync-report.json,
                         ../bug-dashboard.md (cập nhật kết quả fix — session root),
                         Phase6-report.md

Phase 7 (Verify)      → orchestrator-summary.md, fix-impact.json,
                         phase-summary.md,
                         ../bug-dashboard.md (hoàn thiện lần cuối — session root),
                         Phase7-report.md,
                         fix-status.json (phase7=completed, pipeline_status=DONE)
```

> **CORE-035 Exemption — bug-dashboard.md (v10.10.0 doc):** File `bug-dashboard.md`
> đặt tại **SESSION_DIR root** (không trong `phase{N}-{name}/` subdirectory) vì
> đây là **cross-phase shared state** — Phase 1 init stub, Phase 5 populate
> dữ liệu issues, Phase 6 update fix results, Phase 7 finalize. Đặt ngoài
> subdirectory để 4 phases cùng update mà không vi phạm CORE-025 "1 file = 1
> writer per phase" semantic (mỗi phase update đúng vùng riêng trong file qua
> shared template). Audit/POST-GATE PHẢI check `$SESSION_DIR/bug-dashboard.md`
> chứ KHÔNG check `$SESSION_DIR/phase5-triage/bug-dashboard.md`.
