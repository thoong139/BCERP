# State Variables Glossary — wf-verify-sync

> Cross-cutting state variables được set/đọc xuyên suốt skill execution.

| Variable | Set by Phase | Read by Phase | Description |
|----------|--------------|---------------|-------------|
| `$SESSION_ID` | Phase 0 (session-init SI.1) | 0–6 | `{YYYY-MM-DD}-{scope-slug}-{NN}` — unique session identifier |
| `$SESSION_DIR` | Phase 0 (session-init SI.3) | 0–6 | `.mc-data/work/wf-verify-sync/sessions/$SESSION_ID` |
| `$LOCK_PATH` | Phase 0 (session-init SI.4) | 0–6 | `$SESSION_DIR/.session.lock` |
| `$HEARTBEAT_PID` | Phase 0 (session-init SI.5) | 0, 6 | PID của heartbeat daemon |
| `$SCOPE` | Phase 0 (init) | 0–6 | `all` / `system` / `module` |
| `$NAME` | Phase 0 (init) | 0–6 | Tên system hoặc module khi `$SCOPE != all` |
| `$HAS_FIX_FLAG` | Phase 0 (init) | 4, 6 | Boolean — true nếu `--fix` |
| `$HAS_STATUS_FLAG` | Phase 0 (init) | 0 | Boolean — true nếu `--status` (early exit) |
| `$HAS_RESUME_FLAG` | Phase 0 (init) | 0 | Boolean — true nếu `--resume` |
| `$HAS_FROM_FIX_BUGS_FLAG` | Phase 0 (init) | 0, 5, 6 | **(v2.1+ S9)** Boolean — true nếu `--from-fix-bugs` |
| `$FROM_FIX_BUGS_SESSION_ID` | Phase 0 (init) | 0 | **(v2.1+ S9)** String — session_id từ `--from-fix-bugs=<id>`, hoặc empty (auto-resolve latest) |
| `$FROM_FIX_BUGS_SESSION_DIR` | Phase 0 (init) | 5, 6 | **(v2.1+ S9)** String — absolute path tới resolved `sessions/{id}/`, hoặc null nếu không resolve được |
| `$FIX_IMPACT_CONTEXT` | Phase 0 (init) | 5, 6 | **(v2.1+ S9)** Object — parsed `fix-impact.json` (schema fix-impact-v1) hoặc `null`. Phase 5 dùng cho check 5.11 (registry_changes cross-check), Phase 6 dùng cho section "Fix Impact Cross-Reference". |
| `$DOCS_SYNC_CONTEXT` | Phase 0 (init) | 3, 6 | **(v2.1+ S9)** Object — parsed `docs-sync-report.json` (schema docs-sync-report-v1) hoặc `null`. Phase 3 (UI coverage) dùng `mismatches[]` để flag, Phase 6 inform UI section. |
| `$HAS_FROM_ADD_SCOPE_FLAG` | Phase 0 (init) | 0, 5, 6 | **(v4.0+ S3)** Boolean — true nếu `--from-add-scope` |
| `$FROM_ADD_SCOPE_SESSION_ID` | Phase 0 (init) | 0 | **(v4.0+ S3)** String — session_id từ `--from-add-scope=<id>`, hoặc empty (auto-resolve latest) |
| `$ADD_SCOPE_CONTEXT` | Phase 0 (init) | 5, 6 | **(v4.0+ S3)** Object — parsed `scope-impact.json` (schema scope-impact-v1) hoặc `null`. Phase 5 dùng cho check 5.12 (cross-check new modules[] against code scan), Phase 6 dùng cho section "Add-Scope Impact Cross-Reference". |
| `$HAS_FROM_MANAGE_CHANGE_FLAG` | Phase 0 (init) | 0, 5, 6 | **(v4.0+ S3)** Boolean — true nếu `--from-manage-change` |
| `$FROM_MANAGE_CHANGE_ID` | Phase 0 (init) | 0 | **(v4.0+ S3)** String — change_id từ `--from-manage-change=<id>`, hoặc empty (auto-resolve latest) |
| `$MANAGE_CHANGE_CONTEXT` | Phase 0 (init) | 5, 6 | **(v4.0+ S3)** Object — parsed `change-impact.json` (schema change-impact-v1) hoặc `null`. Phase 5 dùng cho check 5.13 (cross-check registry_changes[] against current registry), Phase 6 dùng cho section "Change Impact Cross-Reference". |
| `$HAS_FROM_PREFLIGHT_FLAG` | Phase 0 (init) | 0, 5, 6 | **(v4.0+ S3)** Boolean — true nếu `--from-preflight` |
| `$FROM_PREFLIGHT_SESSION_ID` | Phase 0 (init) | 0 | **(v4.0+ S3)** String — session_id từ `--from-preflight=<id>`, hoặc empty (auto-resolve latest) |
| `$PREFLIGHT_IMPACT_CONTEXT` | Phase 0 (init) | 5, 6 | **(v4.0+ S3)** Object — parsed `preflight-impact.json` (schema preflight-impact-v1) hoặc `null`. Phase 5 dùng cho check 5.14 (cross-check preflight findings against current scan), Phase 6 dùng cho section "Preflight Impact Cross-Reference". |
| `$REGISTRY_CHANGES` | Phase 6 (report) | 6 | **(v4.0+ S3)** Array `[{req_id, field, before, after}]` — capture before/after impl_status từ Step 6.3a safe-update. Dùng bởi vs-impact-build.sh để populate `registry_changes[]` trong verify-sync-impact.json. |
| `$SCOPE_FILTER` | Phase 0 (init) | 1, 2 | Object `{req_ids: [], modules: []}` — REQ-IDs + module paths thuộc scope |
| `$PREFLIGHT_CONTEXT` | Phase 0 (init) | 6 | Object `{verdict, score, critical_count, high_count, run_id, scope, loaded_at}` hoặc `null` |
| `$FIX_REPORT_CONTEXT` | Phase 0 (init) | 6 | Object `{total_fixes, critical_fixes, high_fixes, scope, loaded_at}` hoặc `null` — từ wf-fix-bugs report gần nhất |
| `$REQ_INDEX` | Phase 1 (scan) | 2, 5 | In-memory map REQ-ID → metadata từ registry + docs |
| `$CODE_REFS` | Phase 1 (scan) | 2, 5 | In-memory map REQ-ID → list source file paths |
| `$ORPHAN_LIST` | Phase 1 (scan) | 2, 4, 5 | Array source file paths không có REQ-ID |
| `$SYNC_RATE` | Phase 2 (analyze) | 5, 6 | Number 0-100 — `(Implemented / Total) × 100` |
| `$COVERAGE_RATE` | Phase 2 (analyze) | 5, 6 | Number 0-100 — `((Implemented + InProgress) / Total) × 100` |
| `$W001_ANOMALIES` | Phase 2 (analyze) | 5, 6 | Array REQ-IDs có `impl_status="done"` nhưng code không tìm thấy |
| `$W002_ANOMALIES` | Phase 2 (analyze) | 5, 6 | Array REQ-IDs có `impl_status="in_progress"` nhưng code không tìm thấy |
| `$W003_ANOMALIES` | Phase 2 (analyze) | 5, 6 | Array REQ-IDs có `impl_status="done"` và có code nhưng Feature cha có `impl_status="in_progress"` hoặc `"not_started"` — downgrade từ Implemented xuống In Progress trong báo cáo (CORE-008: KHÔNG downgrade registry impl_status) |
| `$GAPS_LIST` | Phase 2 (analyze) | 3, 4, 5, 6 | Array `{req_id, type, priority, suggested_action, w002?, w003?}` — Missing/Partial/Orphan/DesignMismatch |
| `$FEATURE_SUMMARY` | Phase 2 (Step 2.3) | 6 | **(v3.1+)** Object `{total, done, in_progress, not_started, skipped}` — tổng hợp `features[]` từ registry. Global layer — không filter theo `$SCOPE_FILTER`. All-zeros nếu registry không có `features[]`. |
| `$HAS_IN_PROGRESS_FEATURES` | Phase 2 (Step 2.3) | 6 | **(v3.1+)** Boolean — true nếu `$FEATURE_SUMMARY.in_progress > 0`. Dùng bởi Phase 6 để xác định verdict. |
| `$IN_PROGRESS_FEATURES_LIST` | Phase 2 (Step 2.3) | 6 | **(v3.1+)** Array `{id, name}` — features[] có `impl_status="in_progress"`, sorted by id (max 20). Dùng bởi Phase 6 trong Feature Completion section. |
| `$INTERFACE_TYPE` | Phase 0 (init) | 3 | `web` / `mobile` / `web+mobile` / `api-only` — đọc từ registry |
| `$UI_COVERAGE_DATA` | Phase 3 (UI) | 6 | Object — kết quả Phase 3 (chỉ khi chạy) — `{matched, partial, missing, coverage_pct, ...}` |
| `$FIX_LOG` | Phase 4 (fix) | 6 | Array fixes đã apply (chỉ khi `--fix`) |
| `$VALIDATION_REPORT` | Phase 5 (crossval) | 6 | Object kết quả 10 checks + iterations run |
| `$SCAN_RESULTS` | Phase 1 (vs-scan-code.sh) | 2, 5 | **(v4.0+ S4)** Object — raw output từ `scan-results.json` (code_refs + orphan_list) |
| `$ANALYSIS_RESULTS` | Phase 2 (vs-analyze.sh) | 5, 6 | **(v4.0+ S4)** Object — raw output từ `analysis-results.json` |
| `$UI_SCAN_RESULTS` | Phase 3 (vs-scan-ui.sh) | 6 | **(v4.0+ S4)** Object — raw output từ `ui-scan-results.json` |
| `$REPORT_DATA` | Phase 6 (vs-build-report-data.sh) | 6 | **(v4.0+ S4)** Object — pre-computed report data từ bash script |
| `$CONTEXT_PERCENT` | Every phase | Every phase | Context budget usage — trigger checkpoint at 65/80% |
| `error_log[]` | All phases | Phase 6 | Array errors collected — dùng cho Auto-Correction Loop + report |
