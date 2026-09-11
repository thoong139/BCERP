# Phase 1 Group F — Wave 4 Parallel State Init (Steps 1.15 + 1.16)

> **Entry condition:** Group E POST-GATE PASS (`$DIMS_ARRAY` resolved).
> **Exit condition:** Bundle dispatcher returns + state files + dashboard initialized.
> **Next:** [phase1-init/G-finalize.md](G-finalize.md) (Finalize).
>
> **Shared protocols cần thiết:**
> - [`_shared/19-bug-dashboard.md`](../_shared/19-bug-dashboard.md) — Bug Dashboard pattern (Worker 2)

## Input contract (env vars từ Group E + all upstream)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$SESSION_ID` | Session identity (Group D) |
| `$PROFILE`, `$SCOPE`, `$NAME`, `$DIMS_ARRAY` | CLI + ISG outputs |
| `$LEGACY_MODE`, `$DRY_RUN`, `$LLM_SCAN` | Flags |
| `$SHOW_BROWSER`, `$NO_BROWSER`, `$MOBILE_MODE`, `$MOBILE_DEVICE` | Browser flags |
| `$URL`, `$INTERFACE_TYPE` | Web flags |
| `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`, `$FRESHNESS_STATUS` | CI flags (Group B) |

## Output contract (env vars truyền sang Group G)

| Variable | Mô tả |
|----------|------|
| `$WAVE4_EXIT` | 0=OK, 1=W1 fail, 2=W2 fail NON-BLOCKING, 3=both fail |
| 5 files created | fix-status.json, session-log.json, error-ledger.json, Phase1-report.md, bug-dashboard.md + .meta.json |

---

## Wave 4: Parallel State Init (Steps 1.15 + 1.16 — gộp v10.12.0)

> **v10.12.0 optimization:** 2 init scripts (init-session-state.sh ghi 4 file + init-bug-dashboard.sh ghi 1 file) dispatch PARALLEL qua wrapper `phase1-init-bundle.sh`. Giảm 1 bash tool call + 2 sub-processes chạy song song.

**Pattern canonical:** CORE-031 + CORE-035 + CORE-006 + CORE-026 + CORE-034 + CORE-028 + [`_shared/19-bug-dashboard.md`](../_shared/19-bug-dashboard.md).

### Files được tạo (5 outputs / 2 workers parallel)

| Worker | Script | Outputs |
|--------|--------|---------|
| **W1: State files** | `init-session-state.sh` | `fix-status.json`, `session-log.json`, `error-ledger.json`, `phase1-init/Phase1-report.md` |
| **W2: Dashboard** | `init-bug-dashboard.sh` | `bug-dashboard.md`, `bug-dashboard.md.meta.json` |

### Thực thi

```bash
# Auto-detect PROJECT_NAME nếu chưa set (registry → basename pwd)
PROJECT_NAME="${PROJECT_NAME:-$(jq -r '.project_name // empty' .mc-data/docs/_meta/req-registry.json 2>/dev/null)}"
PROJECT_NAME="${PROJECT_NAME:-$(basename "$(pwd)")}"
export PROJECT_NAME

# Bundle dispatcher — internal parallel via bash & wait
SESSION_DIR="$SESSION_DIR" SESSION_ID="$SESSION_ID" PROFILE="$PROFILE" SCOPE="$SCOPE" NAME="$NAME" \
DIMS_ARRAY="$DIMS_ARRAY" LEGACY_MODE="$LEGACY_MODE" DRY_RUN="$DRY_RUN" LLM_SCAN="$LLM_SCAN" \
SHOW_BROWSER="$SHOW_BROWSER" NO_BROWSER="$NO_BROWSER" MOBILE_MODE="$MOBILE_MODE" MOBILE_DEVICE="$MOBILE_DEVICE" \
URL="$URL" INTERFACE_TYPE="${INTERFACE_TYPE:-unknown}" \
GITNEXUS_AVAILABLE="$GITNEXUS_AVAILABLE" SERENA_AVAILABLE="$SERENA_AVAILABLE" FRESHNESS_LEVEL="$FRESHNESS_STATUS" \
PROJECT_NAME="$PROJECT_NAME" \
bash .claude/scripts/wf-fix-bugs/phase1-init-bundle.sh
WAVE4_EXIT=$?
# Output JSON (stdout): {"state":"ok","dashboard":"ok","duration_ms":150}
```

### VERIFY (mọi outputs phải tồn tại)

```bash
# W1 State files
test -s "$SESSION_DIR/fix-status.json" && jq -e '.session_id and .dimensions' "$SESSION_DIR/fix-status.json"
test -s "$SESSION_DIR/session-log.json" && jq -e '.session_id' "$SESSION_DIR/session-log.json"
test -s "$SESSION_DIR/error-ledger.json" && jq -e '.session_id' "$SESSION_DIR/error-ledger.json"
test -s "$SESSION_DIR/phase1-init/Phase1-report.md" && grep -q "$SESSION_ID" "$SESSION_DIR/phase1-init/Phase1-report.md"
# Không còn placeholders chưa replace
! grep -qE '\[[A-Z_]+\]' "$SESSION_DIR/phase1-init/Phase1-report.md"

# W2 Dashboard
test -s "$SESSION_DIR/bug-dashboard.md" && grep -q "$SESSION_ID" "$SESSION_DIR/bug-dashboard.md"
test -s "$SESSION_DIR/bug-dashboard.md.meta.json" && jq -e '.session_id' "$SESSION_DIR/bug-dashboard.md.meta.json"
```

### Xử lý lỗi (bundle exit code aggregation)

| Exit | Worker fail | Severity | Hành động |
|------|------------|----------|-----------|
| 0 | (none) | OK | Tiếp tục Group G |
| 1 | W1 only (state files) | CRITICAL | E035 retry x1 → nếu vẫn fail: STOP |
| 2 | W2 only (dashboard) | NON-BLOCKING | E035 WARN, dashboard re-init Phase 5 Step 5.9 ([_shared/19-bug-dashboard.md §19.4](../_shared/19-bug-dashboard.md#194-error-codes-canonical-mapping)) |
| 3 | Cả W1+W2 | CRITICAL | E035 retry x1 → nếu vẫn fail: STOP |

**Cross-ref:** CORE-031, CORE-035, CORE-006, CORE-026, CORE-034, CORE-028, [_shared/19-bug-dashboard.md](../_shared/19-bug-dashboard.md). Script: `phase1-init-bundle.sh` (wrapper) → `init-session-state.sh` + `init-bug-dashboard.sh` (workers).

---

## Group F POST-GATE Verify

```bash
[ "${WAVE4_EXIT:-99}" -le 2 ] && \
test -s "$SESSION_DIR/fix-status.json" && \
test -s "$SESSION_DIR/session-log.json" && \
  echo "Group F PASS" || echo "Group F FAIL"
```

## Next Group

→ Group G Finalize — đọc [`phase1-init/G-finalize.md`](G-finalize.md)
