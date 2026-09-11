# Phase 0.5: impl_status Initialization (CHỈ LEGACY_MODE)

> Seed `impl_status` từ `impl-status-snapshot.json` — **1 lần duy nhất** (P8).
> SAU khi seed, registry là SSOT. KHÔNG đọc snapshot nữa.

**PRE-GATE:**

```bash
# Chỉ chạy nếu LEGACY_MODE = true
test "$LEGACY_MODE" = "true"
```

> Nếu `$LEGACY_MODE = false` → SKIP phase này, chuyển thẳng `phase1-scope-mapping.md`.

**INPUT:** `.mc-data/work/legacy-scan/impl-status-snapshot.json` + registry (features list từ Phase 0)

**OUTPUT:** In-memory `$IMPL_STATUS_MAP` — map `{FEAT-ID → impl_status}` persist vào `define-features-status.json.flags.impl_status_map`

## Steps

| Step  | Action | Verify |
|-------|--------|--------|
| 0.5.1  | Đọc `impl-status-snapshot.json` từ `.mc-data/work/legacy-scan/` | File loaded |
| 0.5.1b | **GRACEFUL DEGRADATION:** Nếu snapshot `modules` rỗng (`{}`) HOẶC file không tồn tại → LOG WARNING: "⚠️ impl-status-snapshot trống/không tồn tại — tất cả features sẽ có impl_status = 'not_started'. Khuyến nghị chạy lại /wf-legacy-scan để populate snapshot." → SKIP phase, tất cả features dùng default "not_started" | Snapshot validated |
| 0.5.2  | Với mỗi feature sẽ được defined:<br>- Tìm matching entry trong impl-status-snapshot<br>- Nếu `status == DONE` và `confidence >= 0.8` → pre-populate `impl_status = "done"`<br>- Nếu `status == PARTIAL` → pre-populate `impl_status = "in_progress"`<br>- Nếu `status == NOT_STARTED` → `impl_status = "not_started"` (default)<br>- Nếu KHÔNG tìm thấy match → `impl_status = "not_started"` (default) | Mapping built |
| 0.5.3  | Chuẩn bị agent context addendum cho Phase 2 (xem `_shared.md §LEGACY_MODE Context Injection`):<br>IF feature has impl-status:<br>&nbsp;&nbsp;Add: "⚠️ Code hiện tại cho feature này: [status] tại [code_refs]"<br>&nbsp;&nbsp;Add: "Viết spec DỰA TRÊN code thực tế, không phải design mới" | Context enriched |
| 0.5.4  | **PERSIST `$IMPL_STATUS_MAP`** — lưu internal map `{FEAT-ID → impl_status}` vào **CẢ HAI** locations: (a) `define-features-status.json.flags.impl_status_map` (legacy status file) và (b) `session-state.json.flags.impl_status_map` (PRIMARY checkpoint — ADR-OPT-02, ưu tiên đọc khi resume). Phase 5 đọc từ `session-state.json` trước khi fallback sang `define-features-status.json`. | Map persisted in both locations |

**POST-GATE:**

```bash
# T1: impl-status-snapshot loaded (hoặc graceful degradation logged)
test -n "$IMPL_STATUS_MAP" || echo "WARNING: impl-status-snapshot not loaded — all features default not_started"
# T2: impl_status_map tồn tại ở CẢ HAI locations
jq -e '.flags.impl_status_map' $SESSION_DIR/define-features-status.json > /dev/null
jq -e '.flags.impl_status_map' $SESSION_DIR/session-state.json > /dev/null
# T3: Map entries count > 0 (hoặc valid empty khi graceful degradation)
```

> **(Protocol 6.6)** Nếu `$LARGE_PROJECT = true`: **SAVE CHECKPOINT** sau Phase 0.5.

**Status update:** `session-state.json` → `phases.P0_5_SEED.status = "completed"`, `completed_at = <ISO timestamp>`.

### Khi Thất Bại

| Điều kiện | Hành động |
|-----------|----------|
| Snapshot không tồn tại | Graceful degradation — tất cả features = not_started |
| JSON parse fail | SKIP phase, log WARNING, tiếp tục |

### Tóm tắt Phase (CORE-028)

1. READ template: `.claude/doc-framework/_meta/phase-summary.template.md`
2. FILL: phase_id, status, items_processed, key_findings, next_action
3. WRITE: `$SESSION_DIR/phase-summary.md`

> **(CORE-026)** Append COMPLETE entry vào `.mc-data/work/_trace/session-log.json`.

**Next phase:** `phase1-scope-mapping.md`
