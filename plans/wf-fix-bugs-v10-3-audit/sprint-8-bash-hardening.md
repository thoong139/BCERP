# Sprint 8 — Bash Scripts Hardening (wf-fix-bugs v10.3) — DONE

**Status:** DONE
**Sprint kick-off:** 2026-05-15
**Sprint closure:** 2026-05-15 (single session, sau Sprint 7)
**Owner:** kỹ sư MCV3 senior

## Final Result

✅ **8/8 findings áp dụng** (1 drift documented không action: F05.024)
✅ **Regression PASS:** `bash run-tests.sh` 1015 pass, coverage 81.75% (Sprint 7 baseline preserved)
✅ Bash syntax check pass cho tất cả scripts edited
✅ F05.011: 26/26 probe scripts move `set -euo pipefail` line 2 (idempotent helper)
✅ Effort actual: ~2h vs estimate 4h (kế thừa Sprint 7 verify-first momentum)

## Mục tiêu

Apply 8 F05 findings cho cross-platform safety + observability bash scripts. Tổng effort estimate ~4h.

## Drift detection (BHV-001 verify trước khi action)

| # | Finding | Audit nói | Thực tế | Action |
|---|---------|-----------|---------|--------|
| 1 | F05.003 | acquire_lock() heredoc → JSON-unsafe | confirmed line 333-347 dùng heredoc raw `$(host_name)` | FIX |
| 2 | F05.004 | wf-fix-report-builder.sh thiếu atomic write | TBD — đọc và verify | INSPECT |
| 3 | F05.005 | wf-fix-baseurl-conflict-check.sh shell concat | TBD | INSPECT |
| 4 | F05.006 | atomic_write_json `.tmp.$$.$RANDOM` | confirmed line 91 | FIX |
| 5 | F05.007 | wf-fix-ci-batch.sh `dirname "$0"` | confirmed line 54 `dirname "$0"` | FIX |
| 6 | F05.009 | ERR trap helper missing | TBD verify | FIX |
| 7 | F05.024 | wf-fix-lane-to-bus.py thiếu QD11 + handlers | **DRIFT**: VALID_DIMS đã có "QD11" line 43 | KIỂM TRA handlers |
| 8 | F05.011 | 26 probe scripts vi phạm `set -euo` line 2 | **confirmed 26/26 vi phạm** | BATCH FIX |

## Strategy chi tiết

### F05.003: acquire_lock() heredoc → jq -n

Hiện tại `wf-fix-common.sh:333-347` dùng heredoc với `$(host_name)` raw. Trên Windows domain, `host_name()` có thể trả `DOMAIN\username` chứa backslash → JSON-unsafe.

**Fix:** Thay heredoc bằng `jq -n --arg`:
```bash
lock_json=$(jq -n \
  --arg session "$(basename "$session_dir")" \
  --argjson pid $$ \
  --arg host "$(host_name)" \
  --arg user "$(user_name)" \
  --arg started "$(iso_now)" \
  --arg phase "${ACTIVE_PHASE:-unknown}" \
  --arg skill "${ACTIVE_SKILL:-wf-fix-bugs}" \
  '{
    "$schema": "wf-fix-lock-v1",
    session_id: $session, pid: $pid, host: $host, user: $user,
    started_at: $started, heartbeat: $started,
    active_phase: $phase, skill: $skill
  }')
```

### F05.006: atomic_write_json mktemp

Thay `${target}.tmp.$$.$RANDOM` bằng `mktemp` (Linux/macOS/Git Bash đều support):
```bash
local tmp
tmp=$(mktemp "${target}.XXXXXX") || { echo "ERROR: mktemp fail" >&2; return 1; }
```

### F05.007: dirname "$0" → ${BASH_SOURCE[0]}

`wf-fix-ci-batch.sh:54` dùng `dirname "$0"` — fail nếu script được sourced. Thay bằng `dirname "${BASH_SOURCE[0]}"`.

### F05.009: ERR trap helper

Add `_err_trap()` vào common.sh:
```bash
_err_trap() {
  local rc=$?
  local cmd="$BASH_COMMAND"
  echo "ERROR (rc=$rc) at line $LINENO: $cmd" >&2
  return $rc
}

enable_err_trap() {
  trap _err_trap ERR
  set -E  # ERR trap inherits to subshells
}
```

Apply ở entry-point critical scripts: `wf-fix-flow-driver.sh`, `wf-fix-record-probe-failure.sh`, `wf-fix-ci-batch.sh`.

### F05.024: lane-to-bus.py — verify QD11 + handlers

VALID_DIMS đã có "QD11" → drift, no action. Cần verify handlers `(KeyboardInterrupt, BrokenPipeError)`.

### F05.011: 26 probe scripts batch fix

Tạo helper script `scripts/move-set-euo-line2.sh`:
- Đọc từng probe script
- Find line `^set -euo pipefail`
- Delete line đó + insert `set -euo pipefail` ngay sau shebang (line 2)
- Idempotent — skip nếu line 2 đã là `set -euo pipefail`

## Execution plan

| Phase | Finding | Estimate | Status |
|-------|---------|----------|--------|
| 1 | Pre-flight verify + plan file | 30min | DONE |
| 2 | F05.003 acquire_lock jq -n | 30min | PENDING |
| 3 | F05.006 atomic_write_json mktemp | 15min | PENDING |
| 4 | F05.009 ERR trap helper | 30min | PENDING |
| 5 | F05.007 ci-batch BASH_SOURCE | 10min | PENDING |
| 6 | F05.004 + F05.005 verify + fix | 30min | PENDING |
| 7 | F05.024 verify (drift documented) | 5min | PENDING |
| 8 | F05.011 batch 26 probe scripts | 30min | PENDING |
| 9 | Regression test + closure | 30min | PENDING |

Tổng actual estimate ~3h30min.

## Acceptance criteria

✅ 8 findings F05.003-024 applied (hoặc drift documented)
✅ `bash run-tests.sh` PASS (regression vs Sprint 7 81.75%)
✅ `bash -n` clean cho mọi script edited
✅ Audit report append "Sprint 8 Closed YYYY-MM-DD"
✅ 6-8 commits trên master

## Risks & Mitigation

| Risk | Mitigation |
|------|-----------|
| F05.003 jq -n fail nếu jq < 1.5 | Document jq ≥1.5 requirement (đã có F05.025 mention) |
| F05.011 batch fix corrupt scripts | Helper idempotent + dry-run mode + git diff verify |
| F05.009 ERR trap break existing logic | Chỉ add `enable_err_trap` opt-in, không auto-trap |
| Regression Python tests | Run `bash run-tests.sh` smoke sau mỗi fix common.sh |
