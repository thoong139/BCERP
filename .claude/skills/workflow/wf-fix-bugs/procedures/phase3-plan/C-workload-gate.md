# Phase 3 Group C — Workload Gate CDG-11 (Step 3.4)

> **Entry condition:** Group B POST-GATE PASS (workloads created + REFINED_DIMS set).
> **Exit condition:** `workload-gate.json` written + user CDG decision recorded.
> **Next:** [phase3-plan/D-route-write.md](D-route-write.md) (Route + Write outputs).
>
> **Shared protocols cần thiết:**
> - [`_shared/16-critical-decision-gate.md`](../_shared/16-critical-decision-gate.md) — CDG-11 pattern
> - [`_shared/20-cdg-tokens.md`](../_shared/20-cdg-tokens.md) — CDG token format

> **⚠ GIỮ INLINE — KHÔNG extract sang script:** Bước này cần user interaction qua AskUserQuestion. Phải hiển thị context trực tiếp trong orchestrator.

## Input contract (env vars từ Group B)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$REFINED_PROFILE`, `$REFINED_DIMS` | Refined plan state |
| `$WORKLOAD_COUNT`, `$TOTAL_ESTIMATED` | Partition metrics |
| `workloads/W*/fix-workload.json` × N | Partition outputs |

## Output contract (env vars truyền sang Group D)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `RATIO_PCT`, `RATIO_DISPLAY` | 3.4 | Workload ratio (% và 1.5x format) |
| `AGENT_CAPACITY` | 3.4 | Profile-based capacity |
| `GATE_DECISION` | 3.4 | `continue` / `ask_warn` / `ask_block` |
| `workload-gate.json` written | 3.4 | `$SESSION_DIR/phase3-plan/workload-gate.json` |

---

## Step 3.4 — Workload Gate (CDG-11)

**Mục đích:** Tính workload ratio + áp dụng CDG-11 để user quyết định có tiếp tục.

### 3.4a — Tính ratio + classify zone

```bash
# Tính tổng estimated + agent capacity theo profile
TOTAL_ESTIMATED=0
for w in "$SESSION_DIR/phase3-plan/workloads/"W*/fix-workload.json; do
  EST=$(jq -r '.estimated_issues' "$w")
  TOTAL_ESTIMATED=$((TOTAL_ESTIMATED + EST))
done

case "$REFINED_PROFILE" in
  quick)      AGENT_CAPACITY=30 ;;
  standard)   AGENT_CAPACITY=60 ;;
  deep)       AGENT_CAPACITY=120 ;;
  exhaustive) AGENT_CAPACITY=240 ;;
  *)          AGENT_CAPACITY=60 ;;
esac

# Ratio (integer arithmetic — bash không float)
RATIO_PCT=$((TOTAL_ESTIMATED * 100 / AGENT_CAPACITY))
RATIO_X10=$((TOTAL_ESTIMATED * 10 / AGENT_CAPACITY))
RATIO_DISPLAY=$(printf "%d.%dx" $((RATIO_X10 / 10)) $((RATIO_X10 % 10)))

# Phân loại + CDG decision
if [ "$RATIO_PCT" -lt 80 ]; then
  GATE_DECISION="continue"        # DEAD_ZONE — silent
elif [ "$RATIO_PCT" -le 150 ]; then
  GATE_DECISION="ask_warn"        # WARN — AskUserQuestion Yes/No
else
  GATE_DECISION="ask_block"       # BLOCK — AskUserQuestion 4 options A/B/C/D
fi
export RATIO_PCT RATIO_DISPLAY AGENT_CAPACITY GATE_DECISION
```

### 3.4b — Ghi gate decision (Atomic Write)

```bash
TMP="$SESSION_DIR/phase3-plan/workload-gate.json.tmp.$$"
jq -n \
  --argjson rp "$RATIO_PCT" \
  --arg rd "$RATIO_DISPLAY" \
  --argjson te "$TOTAL_ESTIMATED" \
  --argjson ac "$AGENT_CAPACITY" \
  --arg dec "$GATE_DECISION" \
  '{ratio_pct:$rp, ratio_display:$rd, total_estimated:$te, agent_capacity:$ac, decision:$dec}' \
  > "$TMP" && mv "$TMP" "$SESSION_DIR/phase3-plan/workload-gate.json"
```

### 3.4c — CDG-11 User Prompt (INLINE AskUserQuestion)

| Zone | Hành động orchestrator |
|------|------------------------|
| `< 0.8` (dead) | Silent continue |
| `0.8-1.5` (warn) | AskUserQuestion: "Workload cao (${RATIO_DISPLAY}). Tiếp tục?" → No → E033 pause |
| `> 1.5` (block) | AskUserQuestion 4 options: **A** Continue / **B** Reduce dims (re-run Step 3.3) / **C** Lower profile (re-run Step 3.3) / **D** Cancel (E033) |

**Pattern:** Orchestrator gọi `AskUserQuestion` tool trực tiếp khi `GATE_DECISION ∈ {ask_warn, ask_block}`. KHÔNG delegate qua script.

**VERIFY:** `test -s workload-gate.json` + `jq -e '.ratio_pct >= 0'`.

**On Failure:**

| Code | Tình huống | Hành động |
|------|-----------|-----------|
| E033 | User chọn Cancel/No | UPDATE fix-status paused, hướng dẫn `--resume` |
| CDG-11 B | Reduce dims | Re-run Step 3.3 (Group B) với dims giảm |
| CDG-11 C | Lower profile | Re-run Step 3.3 (Group B) với profile thấp hơn |

**Cross-ref:** CORE-027 (CDG-11), CORE-034 (E033), CORE-035 (Atomic Write).

---

## Group C POST-GATE Verify

```bash
test -s "$SESSION_DIR/phase3-plan/workload-gate.json" && \
jq -e '.ratio_pct >= 0 and .decision != null' \
  "$SESSION_DIR/phase3-plan/workload-gate.json" >/dev/null && \
  echo "Group C PASS" || echo "Group C FAIL"
```

## Next Group

→ Group D Route + Write — đọc [`phase3-plan/D-route-write.md`](D-route-write.md)
