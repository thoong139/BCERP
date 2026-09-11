# Checkpoint Protocol — wf-verify-sync

> Trigger save checkpoint khi: context > 65% (advisory) / > 80% (mandatory) / sau Phase 1 nếu project lớn.

**Save checkpoint pattern (mọi phase):**

```
1. READ templates/checkpoint.json (nếu chưa init từ Phase 0)
2. POPULATE:
   - position.current_phase, progress.phases_completed[]
   - data_snapshot.{req_index, code_refs, orphan_list, w001_anomalies, w002_anomalies, w003_anomalies,
                    sync_rate, coverage_rate, interface_type, feature_summary,
                    scan_results (v4.0+ S4: raw output từ vs-scan-code.sh),
                    analysis_results (v4.0+ S4: raw output từ vs-analyze.sh),
                    ui_scan_results (v4.0+ S4: raw output từ vs-scan-ui.sh),
                    validation_report (nếu Phase 5 đã hoàn thành),
                    fix_log (nếu Phase 4 đã hoàn thành),
                    report_data (v4.0+ S4: raw output từ vs-build-report-data.sh)}
   - registry_state.{fingerprint, counts_snapshot, snapshot_timestamp}
3. WRITE $SESSION_DIR/checkpoint.json (atomic)
4. Đồng thời cập nhật $SESSION_DIR/verify-sync-status.json (phases.[name].status, timestamps)
```

**Batch strategy cho large projects (Phase 1 scan):**

```
file_count = count(src/**/*.{ts,js,py,go,java,cs})

IF file_count <= 500:
  → Scan toàn bộ bằng vs-scan-code.sh (v4.0+ S4: bash script delegation)

IF file_count > 500:
  → Chia theo module directories (từ registry.modules[])
  → Mỗi batch = 1 module directory
  → Scan tuần tự per batch, merge results
  → CHECKPOINT sau mỗi 5 batches (hoặc khi context > 65%)
```

**Resume:** Load `data_snapshot` từ checkpoint → restore `$REQ_INDEX`, `$CODE_REFS`, `$ORPHAN_LIST`, `$SYNC_RATE`, `$W001_ANOMALIES`, `$GAPS_LIST`. CONTINUE từ `next_action`.
