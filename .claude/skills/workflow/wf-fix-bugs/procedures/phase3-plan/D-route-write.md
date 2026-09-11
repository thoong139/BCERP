# Phase 3 Group D — Route + Write Outputs (Step 3.5)

> **Entry condition:** Group C POST-GATE PASS (workload-gate.json + user CDG accepted).
> **Exit condition:** `work-plan.json` + `dimension-plan.json` written, `EXECUTION_MODE` set.
> **Next:** [phase3-plan/E-report.md](E-report.md) (Phase Report).
>
> **Shared protocols cần thiết:** None (script delegation only).

## Input contract (env vars từ Group C)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$SESSION_ID` | Session identity |
| `$REFINED_DIMS`, `$REFINED_PROFILE` | Refined plan |
| `$WORKLOAD_COUNT`, `$TOTAL_ESTIMATED` | Partition metrics |
| `$INTERFACE_TYPE`, `$MOBILE_MODE`, `$SHOW_BROWSER`, `$RESPONSIVE_MODE` | UI/Playwright config |

## Output contract (env vars truyền sang Group E)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `EXECUTION_MODE` | 3.5 | `inline` hoặc `agent_dispatch` |
| `AGENT_COUNT` | 3.5 | Số agent dispatch (≤ 10) |
| `PW_MODE` | 3.5 | `none` / `headless` / `visible` / `mobile` |
| `DIMENSIONS_ROUTED` | 3.5 | Số dims đã route vào lane |
| `work-plan.json` written | 3.5 | `$SESSION_DIR/phase3-plan/work-plan.json` |
| `dimension-plan.json` written | 3.5 | `$SESSION_DIR/phase3-plan/dimension-plan.json` (consumer Phase 4) |

---

## Step 3.5 — Route + Write Outputs (delegated to route-and-write.sh)

**Mục đích:** Thực hiện **4 logical sub-steps trong 1 atomic call**:

1. **Agent Dispatch Threshold** (CORE-038): `EXECUTION_MODE = agent_dispatch` nếu `TOTAL_ESTIMATED > 200` HOẶC `CONTEXT_PCT > 70`; else `inline`. `AGENT_COUNT = min(WORKLOAD_COUNT, 10)` cho agent_dispatch.
2. **Playwright Planning**: Mode (none/headless/visible/mobile) + slot reservation. Tự ép `api-only → none`.
3. **Dimension → Lane Routing**: 11 dims (QD1-QD11) → lane skill + agent type + probe count + output_dir + needs_playwright + playwright_priority. Profile-based probe adjustment (quick÷2, deep×1.5, exhaustive×2). Validate unique output_dir (CORE-025).
4. **WRITE work-plan.json + dimension-plan.json** (CORE-031 READ→POPULATE→WRITE từ templates + Atomic Write Pattern).

```bash
export SESSION_DIR SESSION_ID REFINED_DIMS REFINED_PROFILE WORKLOAD_COUNT TOTAL_ESTIMATED INTERFACE_TYPE
export MOBILE_MODE SHOW_BROWSER RESPONSIVE_MODE

PHASE3_S2=$(bash .claude/scripts/wf-fix-bugs/route-and-write.sh)

EXECUTION_MODE=$(echo "$PHASE3_S2" | jq -r '.execution_mode')
AGENT_COUNT=$(echo "$PHASE3_S2" | jq -r '.agent_count')
PW_MODE=$(echo "$PHASE3_S2" | jq -r '.pw_mode')
DIMENSIONS_ROUTED=$(echo "$PHASE3_S2" | jq -r '.dimensions_routed')
export EXECUTION_MODE AGENT_COUNT PW_MODE DIMENSIONS_ROUTED

echo "$PHASE3_S2" | jq -e '.status == "ok"'
```

**VERIFY (POST-GATE T1-T3 phần write):**

```bash
test -s "$SESSION_DIR/phase3-plan/work-plan.json"
test -s "$SESSION_DIR/phase3-plan/dimension-plan.json"
jq -e '.execution_mode and .dimensions and .playwright' "$SESSION_DIR/phase3-plan/work-plan.json"
jq -e '.dimensions | length > 0' "$SESSION_DIR/phase3-plan/dimension-plan.json"
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|-----------|-----------|
| E034 | Script exit 1 (env var thiếu) | Re-export REFINED_DIMS, WORKLOAD_COUNT — re-run |
| E035 | Template không tồn tại (script exit 2) | Kiểm tra `templates/phase3-plan/` |
| E036 | Atomic write fail (script exit 3) | Retry x1, escalate E001 |
| E037 | Duplicate output_dir (CORE-025 violation) | Script auto-detect + exit 3 |

**Cross-ref:** CORE-031, CORE-035 (Atomic Write), CORE-036 (Cross-Skill — dimension-plan.json consumer Phase 4), CORE-025 (unique output_dir), CORE-038 (Context Budget).

---

## Group D POST-GATE Verify

```bash
test -s "$SESSION_DIR/phase3-plan/work-plan.json" && \
test -s "$SESSION_DIR/phase3-plan/dimension-plan.json" && \
jq -e '.execution_mode and .dimensions and .playwright' \
  "$SESSION_DIR/phase3-plan/work-plan.json" >/dev/null && \
jq -e '.dimensions | length > 0' \
  "$SESSION_DIR/phase3-plan/dimension-plan.json" >/dev/null && \
  echo "Group D PASS" || echo "Group D FAIL"
```

## Next Group

→ Group E Phase Report — đọc [`phase3-plan/E-report.md`](E-report.md)
