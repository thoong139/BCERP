# Cross-Phase Data Flow — wf-verify-sync

```
Phase 0 (init)         → $SCOPE, $NAME, $HAS_*, $SCOPE_FILTER, $INTERFACE_TYPE,
                         $PREFLIGHT_CONTEXT, $FIX_REPORT_CONTEXT,
                         $FIX_IMPACT_CONTEXT, $DOCS_SYNC_CONTEXT (v2.1+ S9 — khi --from-fix-bugs),
                         $FROM_FIX_BUGS_SESSION_DIR (v2.1+ S9 resolved path hoặc null),
                         $ADD_SCOPE_CONTEXT (v4.0+ S3 — khi --from-add-scope),
                         $MANAGE_CHANGE_CONTEXT (v4.0+ S3 — khi --from-manage-change),
                         $PREFLIGHT_IMPACT_CONTEXT (v4.0+ S3 — khi --from-preflight),
                         registry_state.fingerprint (compute & save to checkpoint),
                         verify-sync-status.json, checkpoint.json
Phase 1 (scan)         → $REQ_INDEX, $SCAN_RESULTS (v4.0+ S4: từ vs-scan-code.sh),
                         $CODE_REFS, $ORPHAN_LIST                    [PARALLEL groups]
Phase 2 (analyze)      → $ANALYSIS_RESULTS (v4.0+ S4: từ vs-analyze.sh),
                         $SYNC_RATE, $COVERAGE_RATE, $W001_ANOMALIES, $W002_ANOMALIES,
                         $W003_ANOMALIES, $GAPS_LIST,
                         $FEATURE_SUMMARY, $HAS_IN_PROGRESS_FEATURES,
                         $IN_PROGRESS_FEATURES_LIST (v3.1+)
                         [E020: nếu Total==0 → $SYNC_RATE=null, skip Phase 3/4/5, jump Phase 6]
Phase 3 (UI coverage)  → $UI_SCAN_RESULTS (v4.0+ S4: từ vs-scan-ui.sh),
                         $UI_COVERAGE_DATA, ui-coverage-report.md    [conditional]
Phase 4 (fix)          → $FIX_LOG, $SHARED_UTILITY_PENDING, $CONFIRMED_SHARED_UTILS,
                         $SKIPPED_MANUAL_REVIEW, source files updated  [conditional --fix]
Phase 5 (crossval)     → $VALIDATION_REPORT (v4.0+ S4: validation-report.json từ vs-validate.sh)
                         (10 checks, hoặc skipped nếu E020)
Phase 6 (report)       → $REPORT_DATA (v4.0+ S4: từ vs-build-report-data.sh),
                         verify-sync.md, registry safe-update, history, status, summary
```

**Quy tắc:** Mỗi phase chỉ READ variables đã được SET ở phase trước. KHÔNG được SET lại variables của phase khác.
