# wf-e2e Migration Guide: v7.0 → v8.0

## Consumer Skills Affected

### wf-flow-e2e-test (consumer)

- **Tác động:** Consume `findings/*` và `outputs/test-scenario.md`
- **Migration:** KHÔNG break — findings paths giữ nguyên
- **Action:** PRE-GATE thêm check `contract_version >= 8.0.0` trong _contract.json

### wf-test-business-workflow (consumer)

- **Tác động:** Consume `issues.json`, `block-test.json`, `implement-required.json`
- **Migration:** KHÔNG break — paths và schema giữ nguyên
- **Action:** `implement-required.json` có schema mới v2 với 4 fields bổ sung (optional backward compat)

### wf-verify-sync (consumer)

- **Tác động:** Nhận `fix-impact.json` (giữ nguyên)
- **Migration:** Add support cho `cross-module-gaps.json` mới

## Migration Script

```bash
# Scan và tag v7 sessions
bash .claude/scripts/wf-e2e-migrate-v7-to-v8.sh

# Kiểm tra sessions cũ (dry-run, không thay đổi file)
bash .claude/scripts/wf-e2e-migrate-v7-to-v8.sh --dry-run
```

## Schema Diff: e2e-status.json

```json
// v7 schema (8 steps)
{ "f1_test": {...}, "f2_browser": {...}, ... "f8_demo": {...} }

// v8 schema (11 steps) — 3 steps mới ở đầu
{ "f0_infra": {...}, "f0a_finding": {...}, "f0b_seed": {...},
  "f1_test": {...}, ... "f8_demo": {...},
  "f6_f5_loops": { "critical": {...}, "high": {...}, ... }
}
```

## Deprecation Timeline

| Version | Status |
|---------|--------|
| v8.0.0 (Day 1) | v7 sessions: support với WARN |
| v8.1.0 (Day 30) | v7 sessions: require --legacy flag |
| v9.0.0 (Day 90) | v7 sessions: support removed |

## Checklist Migration

- [ ] Update _contract.json consumers (thêm version check)
- [ ] Chạy migration script cho sessions đang in-progress
- [ ] Test backward compat với --legacy flag
- [ ] Update CI/CD nếu có script gọi wf-e2e-verify trực tiếp
