# Phase 1 Group A — Bootstrap (Steps 1.1 → 1.4)

> **Entry condition:** SKILL.md route đến Phase 1 (đọc index trước → load file này).
> **Exit condition:** Step 1.4 PASS (deprecation block clear).
> **Next:** [phase1-init/B-wave1.md](B-wave1.md) (Wave 1 Parallel Discovery).
>
> **Shared protocols cần thiết:** None (bootstrap thuần — source helpers, parse flags, dispatch check).
>
> **PRE-GATE:** `.claude/scripts/wf-fix-common.sh` tồn tại (đã verify ở phase1-init.md index PRE-GATE).

## Input contract (env vars có sẵn từ orchestrator)

| Variable | Description |
|----------|-------------|
| `$ARGUMENTS` | CLI arguments string (từ SKILL.md `$ARGUMENTS` placeholder) |
| `MCV3_PROFILE` | (optional) Override profile mặc định |
| `MCV3_SCOPE` | (optional) Override scope mặc định |

## Output contract (env vars truyền sang Group B)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `PROFILE`, `SCOPE`, `NAME` | 1.2 | CLI flags parsed |
| `DRY_RUN`, `LLM_SCAN`, `SHOW_BROWSER`, `NO_BROWSER`, `MOBILE_MODE`, `MOBILE_DEVICE` | 1.2 | Boolean flags |
| `DIMS_ARRAY`, `URL`, `CREDENTIALS`, `SESSION_ID_FLAG`, `RESUME_STRATEGY` | 1.2 | Optional flags |
| `HAS_STATUS`, `HAS_RESUME`, `HAS_MIGRATE` | 1.2 | Dispatch flags |
| All helper functions từ `wf-fix-common.sh` | 1.1 | sourced |
| Cleanup trap registered | 1.1 | EXIT/INT/TERM |

---

## Step 1.1 — Source Helpers + Register Cleanup Trap

```bash
source .claude/scripts/wf-fix-common.sh
trap cleanup EXIT INT TERM

# VERIFY: 3 core functions có sẵn
type cleanup append_session_index atomic_write_json | grep -q function || {
  echo "E001: wf-fix-common.sh missing functions"; exit 1
}
```

**On Failure:** E001 → STOP (kiểm tra installation).

---

## Step 1.2 — Parse CLI Flags (delegated to script)

> **v10.14.0:** 60+ dòng inline bash extracted → `phase1-parse-flags.sh` (~110 dòng standalone).

```bash
# Delegate parse → eval env-style stdout
eval "$(bash .claude/scripts/wf-fix-bugs/phase1-parse-flags.sh)"

# VERIFY: core flags set
test -n "$PROFILE" || { echo "E002: PROFILE empty"; exit 2; }
test -n "$SCOPE" || { echo "E002: SCOPE empty"; exit 2; }
```

**Outputs (env vars sau eval):** xem [phase1-parse-flags.sh §Output](../../../../scripts/wf-fix-bugs/phase1-parse-flags.sh).

**On Failure:** E002 → Fallback `standard`/`all` + WARN (script đã handle).

---

## Step 1.3 — Flag Dispatch (--status / --resume / --migrate)

```bash
# Route to handler files when dispatch flag set, then STOP pipeline
if [ "$HAS_STATUS" = "true" ]; then
  echo "E010: --status dispatched → route resume-status.md §--status Handler"
  # → Đọc procedures/resume-status.md, route §--status Handler, STOP
  exit 10
fi

if [ "$HAS_RESUME" = "true" ]; then
  echo "E011: --resume dispatched → route resume-status.md §--resume Handler"
  # → Đọc procedures/resume-status.md, route §--resume Handler, STOP
  exit 11
fi

if [ "$HAS_MIGRATE" = "true" ]; then
  # PRE-GATE legacy detection (v10.10.0 fix — tránh corrupt sessions index)
  LEGACY_ROOT=".mc-data/work/wf-fix-bugs"
  LEGACY_COUNT=0
  if [ -d "$LEGACY_ROOT" ]; then
    LEGACY_COUNT=$(find "$LEGACY_ROOT" -maxdepth 2 -type d -name "run-*" 2>/dev/null | wc -l | tr -d ' ')
  fi
  if [ "$LEGACY_COUNT" -eq 0 ]; then
    echo "INFO: Không phát hiện legacy v6.x sessions — KHÔNG cần --migrate"
    exit 0
  fi
  echo "INFO: Phát hiện $LEGACY_COUNT legacy sessions — bắt đầu migrate..."
  bash .claude/scripts/wf-fix-migrate-sessions.sh
  exit 12
fi

echo "OK: No dispatch flag — continue Phase 1"
```

**On Failure:** E010/E011/E012 đều là dispatch handlers — STOP pipeline (không phải lỗi).

---

## Step 1.4 — Deprecation BLOCK

```bash
bash .claude/scripts/wf-fix-deprecation-block.sh
DEPRECATION_EXIT_CODE=$?

if [ $DEPRECATION_EXIT_CODE -ne 0 ]; then
  if [ "${MCV3_FIX_BUGS_LEGACY_DEPRECATED_OK:-0}" = "1" ]; then
    echo "WARN: Legacy deprecation overridden by escape hatch"
  else
    echo "FATAL: E013 — Legacy deprecation block"
    exit 13
  fi
else
  echo "OK: No legacy paths detected"
fi
```

**On Failure:** E013 → CDG render → escape hatch `MCV3_FIX_BUGS_LEGACY_DEPRECATED_OK=1`.

---

## Group A POST-GATE Verify

```bash
# Mọi env vars cốt lõi đã set
test -n "$PROFILE" && test -n "$SCOPE" && type cleanup >/dev/null 2>&1
[ $? -eq 0 ] && echo "Group A PASS" || echo "Group A FAIL"
```

## Next Group

→ Group B Wave 1 Parallel Discovery — đọc [`phase1-init/B-wave1.md`](B-wave1.md)
