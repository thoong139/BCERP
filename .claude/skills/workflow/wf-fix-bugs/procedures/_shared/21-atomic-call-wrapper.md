# §21 Atomic-Call Wrapper Pattern (v10.3 → v10.9)

> **Đúc kết từ chu trình tối ưu Phase 1-7 (v10.3 → v10.9)** — pattern delegate N logical sub-steps thành 1 atomic script call. Áp dụng khi N steps làm cùng 1 mục đích (init, validate, generate reports, finalize) — gộp + delegate → giảm context budget procedure file -40% đến -65%.

## §21.1 Khi áp dụng

| Pattern | Use case | Ví dụ |
|---------|----------|-------|
| **Init block** | PRE-GATE + state setup + TRACE START | setup-lanes.sh, setup-triage.sh, setup-execute.sh, setup-verify.sh |
| **Validate block** | Spot-check + integrity check + POST-GATE | aggregate-and-spot-check.sh, validate-lane-outputs.sh, validate-triage-outputs.sh, verify-execute-outputs.sh |
| **Reports block** | Generate 2-4 reports cùng phase | generate-phase5-reports.sh (3), generate-phase7-reports.sh (4 — lớn nhất) |
| **Finalize block** | Update fix-status + TRACE COMPLETE | finalize-phase4.sh, finalize-phase5.sh, finalize-phase6.sh, finalize-phase7.sh |

## §21.2 Pattern Template

```bash
#!/usr/bin/env bash
# =============================================================================
# <name>.sh — Phase N Step N.X (gộp N sub-steps — vXX)
# =============================================================================
# Gộp X logical sub-steps thành 1 atomic call:
#   N.X1 <Step name 1>
#   N.X2 <Step name 2>
#   ...
#
# Required env vars: SESSION_DIR, <others>
# Optional env vars: <list>
#
# Exit codes:
#   0 — Success (orchestrator continues)
#   1 — Required env var missing
#   3 — Atomic write fail (E035/E001)
#   4 — Critical condition (e.g., POST-GATE fail)
#   5 — Special path (e.g., E005 healthy, DRY_RUN done)
#
# Output JSON (stdout): {<aggregated fields>, status: "ok|<other>"}
# =============================================================================

set -eu

# 1. Validate env vars
for var in SESSION_DIR <others>; do
  [ -z "${!var:-}" ] && { echo "ERROR: \$$var empty" >&2; exit 1; }
done

# 2. Load context
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# ... load state files ...

# 3. Execute sub-steps sequentially (atomic per sub-step)
# Sub-step N.X1
# Sub-step N.X2
# ...

# 4. Emit aggregated JSON for orchestrator eval
jq -n --argjson <field> "$VAR" \
      '{<field>: $<field>, status: "ok"}'

exit 0
```

## §21.3 Orchestrator Usage Pattern

```bash
# Procedure file orchestrator step:
PHASE_S<N>=$(bash .claude/scripts/wf-fix-bugs/<name>.sh) || RC=$?

if [ "${RC:-0}" -ne 0 ]; then
  case "$RC" in
    2) echo "<E_CODE_A>: <reason>" ;;
    5) echo "<E_CODE_SPECIAL>: <special path action>" ;;
    *) echo "<E_CODE_GENERIC>: $RC" ;;
  esac
  exit "$RC"
fi

# Extract values cho subsequent steps
FIELD_VAL=$(echo "$PHASE_S<N>" | jq -r '.<field>')
export FIELD_VAL
```

## §21.4 Quy tắc preservation (BHV-003 Surgical Changes)

| Rule | Lý do |
|------|-------|
| **GIỮ INLINE cho user interaction** | CDG render (AskUserQuestion) phải INLINE để user thấy context — không delegate sang script |
| **GIỮ orchestrator-side cho Agent tool calls** | `Agent({subagent_type, ...})` chỉ gọi được từ orchestrator context — không script được (CORE-037) |
| **GIỮ orchestrator-side cho UI tools** | TodoWrite, Completion Display — UI tools, không script được |
| **PRESERVE semantics khi delegate execution** | Khi gộp logic vào script, giữ nguyên check rules / behavior gốc (vd verify-lane-prompt.sh giữ 6 check points v10.2) |
| **Step numbering giữ gaps** | Khi gộp N+M → N, GIỮ M number gap để tránh churn cross-refs trong các phase khác |

## §21.5 Cross-Platform Defensive Patterns (Git Bash + WSL + Linux)

```bash
# 1. bc absent trên Git Bash Windows → fallback awk
# WRONG: VAL=$(echo "scale=0; $x * 100 / $y" | bc)
# RIGHT:
VAL=$(awk -v x="$x" -v y="$y" 'BEGIN {if(y>0) printf "%d", x*100/y; else print "0"}')

# 2. find -exec ... | paste -sd+ - | bc → fallback awk sum
# WRONG: CNT=$(find ... -exec jq '.signals | length' {} + | paste -sd+ - | bc)
# RIGHT:
CNT=$(find ... -exec jq '(.signals // []) | length' {} + 2>/dev/null | awk '{s+=$1} END {print s+0}')

# 3. grep -c | tr -d '\r' chống "0\n0" corruption
# WRONG: CNT=$(grep -c "pattern" "$file" 2>/dev/null || echo 0)  # khi no match → "0\n0"
# RIGHT:
CNT=$(grep -c "pattern" "$file" 2>/dev/null | head -1 | tr -d '\r')
[ -z "$CNT" ] && CNT=0

# 4. Atomic JSON write pattern (CORE-035 universal)
TMP="$TARGET.tmp.$$"
if jq <filter> "$SOURCE" > "$TMP" \
   && jq '.' "$TMP" >/dev/null \
   && mv "$TMP" "$TARGET"; then
  : # success
else
  rm -f "$TMP"
  echo "ERROR: Atomic write fail" >&2
  exit 3
fi

# 5. Pipeline state load với defaults (graceful degradation)
if [ -z "${VAR:-}" ]; then
  VAR=$(jq -r '.field // "default"' "$STATE_FILE" 2>/dev/null || echo "fallback")
fi
```

## §21.6 Metrics đã đạt được (Phase 1-7, v10.3 → v10.9)

| Phase | Tokens trước | Tokens sau | Δ | Scripts |
|-------|--------------|------------|---|---------|
| 1 Init (v10.3) | ~28K | ~10.75K | -62% | 3 |
| 2 Scan (v10.4) | ~8.4K | ~3.45K | -59% | 2 |
| 3 Plan (v10.5) | ~10.93K | ~5.24K | -52% | 3 |
| 4 Find Bugs (v10.6) | ~15.65K | ~8.56K | -45% | 7 |
| 5 Triage (v10.7) | ~10.73K | ~5.77K | -46% | 7 |
| 6 Execute (v10.8) | ~10.81K | ~5.71K | -47% | 5 |
| 7 Verify (v10.9) | ~11.96K | ~5.77K | -52% | 5 |
| **Total** | **~96.48K** | **~45.25K** | **-53%** | **32** |

Pipeline v10.9: tất cả procedure files < 12K tokens, end-to-end multi-session safe.

## §21.7 Khi KHÔNG áp dụng

- 1 step làm 1 mục đích atomic (KHÔNG cần gộp)
- User interaction giữa 2 sub-steps (gộp sẽ phá UX flow)
- Agent tool call giữa 2 sub-steps (không script được)
- Sub-steps có dependency cross-phase (không atomic per phase)

## §21.8 Reference Scripts Pipeline-Wide (32 scripts)

Tất cả scripts tại `.claude/scripts/wf-fix-bugs/`. Mỗi file có header comment đầy đủ với phase/step mapping, env vars contract, exit codes, output JSON schema.
