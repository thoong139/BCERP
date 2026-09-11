# Phase 6 Group C — CI Impact + CDG (Step 6.3)

> **Entry condition:** Group B POST-GATE PASS với DRY_RUN=false (live mode only).
> **Exit condition:** `ci-impact-report.json` written + user CDG decision recorded (nếu có HIGH/CRITICAL).
> **Next:** [phase6-execute/D-spawn-execute.md](D-spawn-execute.md) (Spawn Execute Agent).
>
> **Shared protocols cần thiết:**
> - [`_shared/12-ci-detection.md`](../_shared/12-ci-detection.md) — CI-ROUTE Matrix
> - [`_shared/16-critical-decision-gate.md`](../_shared/16-critical-decision-gate.md) — CDG pattern HIGH/CRITICAL

> **⚠ GIỮ INLINE — KHÔNG extract sang script:** CDG render (AskUserQuestion) cho HIGH/CRITICAL risks. Fast/Slow Path logic phức tạp + user-facing CDG decision.

## Input contract (env vars từ Group B)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$CI_CONTEXT`, `$GITNEXUS_AVAILABLE` | Pipeline state |
| `phase5-triage/issue-registry.json` | Source cho blast_radius (Fast Path) |
| `phase5-triage/fix-plan.md` | Fallback cho Slow Path (extract targets) |

## Output contract (env vars truyền sang Group D)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `CRITICAL_RISK_TARGETS`, `HIGH_RISK_TARGETS` | 6.3 | Space-separated strings |
| `FAST_PATH_USED`, `CI_TOOL_LABEL` | 6.3 | Path detection result |
| `FIX_TARGETS_COUNT` | 6.3 | Total targets analyzed |
| `phase6-execute/ci-impact-report.json` | 6.3 | Aggregated impact report |

---

## Step 6.3 — CI-ROUTE: Pre-Execution Impact Analysis

**Mục đích:** Xác định fix targets có risk CAO (HIGH/CRITICAL) trước khi spawn agent → cảnh báo user via CDG.

**Tối ưu W1.1 — De-duplicate CI Work:** Phase 5 wf-fix-triage Step 2.1b/2.1c (ADR-22 rule 2) đã enrich `blast_radius.{direct_count, critical_downstream[]}` cho mọi issue. Step 6.3 ưu tiên **Fast Path** đọc lại data đó thay vì gọi `mcp__plugin_gitnexus_gitnexus__impact` lần nữa.

### 6.3a — Detect Fast Path khả thi

```bash
ISSUE_REGISTRY="$SESSION_DIR/phase5-triage/issue-registry.json"
BLAST_RADIUS_AVAILABLE=$(jq -e '
  (.issues | length) > 0 and
  (.issues | all(has("blast_radius") and (.blast_radius | has("direct_count")) and (.blast_radius.direct_count | type) == "number"))
' "$ISSUE_REGISTRY" >/dev/null 2>&1 && echo "true" || echo "false")
FAST_PATH_USED=false
```

### 6.3b — FAST PATH (khi `BLAST_RADIUS_AVAILABLE=true`)

Aggregate target risk từ issue-level blast_radius. Quy ước:
- `severity=CRITICAL` OR `blast_radius.direct_count >= 20` → CRITICAL
- `severity=HIGH` OR `direct_count >= 5` (và không CRITICAL) → HIGH

```bash
if [ "$BLAST_RADIUS_AVAILABLE" = "true" ]; then
  FAST_PATH_USED=true
  CI_TOOL_LABEL="blast_radius_reused"

  CRITICAL_RISK_TARGETS=$(jq -r '
    [.issues[] | select(.severity == "CRITICAL" or (.blast_radius.direct_count // 0) >= 20)
      | (.target.symbol // .target.file // .file_path // .location.file // "unknown")
    ] | unique | .[]
  ' "$ISSUE_REGISTRY" 2>/dev/null | tr '\n' ' ')

  HIGH_RISK_TARGETS=$(jq -r '
    [.issues[] | select(((.severity == "HIGH") or ((.blast_radius.direct_count // 0) >= 5))
                       and .severity != "CRITICAL"
                       and ((.blast_radius.direct_count // 0) < 20))
      | (.target.symbol // .target.file // .file_path // .location.file // "unknown")
    ] | unique | .[]
  ' "$ISSUE_REGISTRY" 2>/dev/null | tr '\n' ' ')

  FIX_TARGETS_COUNT=$(jq -r '[.issues[] | (.target.symbol // .target.file // .file_path // .location.file // "unknown")] | unique | length' "$ISSUE_REGISTRY")
fi
```

### 6.3c — SLOW PATH (fallback khi `BLAST_RADIUS_AVAILABLE=false`)

Behavior cũ — extract fix targets từ fix-plan, gọi `mcp__plugin_gitnexus_gitnexus__impact` cho từng target (hoặc Grep fallback nếu `GITNEXUS_AVAILABLE=false`). Set `CI_TOOL_LABEL="gitnexus_fresh"` hoặc `"grep_fallback"`.

### 6.3d — CDG render (CORE-027 — IDENTICAL ở cả Fast/Slow Path)

```
IF [ -n "$CRITICAL_RISK_TARGETS" ] OR [ -n "$HIGH_RISK_TARGETS" ]:
  AskUserQuestion: "Phát hiện rủi ro cao khi sửa các target sau:
                    🔴 CRITICAL: $CRITICAL_RISK_TARGETS
                    🟡 HIGH: $HIGH_RISK_TARGETS
                    Tiếp tục thực thi fix?"
  Options: ACCEPT / ABORT
  IF ABORT → update fix-status phase6=aborted → exit
```

**Pattern:** Orchestrator gọi `AskUserQuestion` tool trực tiếp. KHÔNG delegate qua script.

### 6.3e — Ghi `ci-impact-report.json`

```bash
# v10.10.0 fix: convert space-separated string → JSON array để consumer parse structured
CRITICAL_ARRAY=$(echo "$CRITICAL_RISK_TARGETS" | tr ' ' '\n' | grep -v '^$' | jq -R -s 'split("\n") | map(select(length>0))' 2>/dev/null || echo '[]')
HIGH_ARRAY=$(echo "$HIGH_RISK_TARGETS" | tr ' ' '\n' | grep -v '^$' | jq -R -s 'split("\n") | map(select(length>0))' 2>/dev/null || echo '[]')

jq -n --argjson critical "$CRITICAL_ARRAY" --argjson high "$HIGH_ARRAY" \
      --argjson tc "${FIX_TARGETS_COUNT:-0}" --arg tool "$CI_TOOL_LABEL" \
      --argjson fast "$FAST_PATH_USED" \
      '{critical:$critical, high:$high, targets_analyzed:$tc, tool:$tool, fast_path_used:$fast}' \
  > "$SESSION_DIR/phase6-execute/ci-impact-report.json"
```

**VERIFY:**

```bash
test -s "$SESSION_DIR/phase6-execute/ci-impact-report.json"
jq -e '.targets_analyzed >= 0 and (.tool | IN("blast_radius_reused", "gitnexus_fresh", "grep_fallback")) and (.fast_path_used | type == "boolean")' \
  "$SESSION_DIR/phase6-execute/ci-impact-report.json"
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E062 | blast_radius schema invalid | Fallback Slow Path (auto), log `fast_path_used=false` |
| E062 | GitNexus impact fail (Slow Path) | Fallback Grep (auto, no user ask) |
| E062 | User reject sau CDG warning | Dừng — update fix-status=aborted |
| E001 | ci-impact-report.json write fail | Retry x1 → escalate |

**Cross-ref:** CORE-033 (CI-First), CORE-027 (CDG), CORE-011 (Forensic — verify content), Protocol 20 §20.11.

---

## Group C POST-GATE Verify

```bash
test -s "$SESSION_DIR/phase6-execute/ci-impact-report.json" && \
jq -e '.targets_analyzed >= 0 and (.tool | IN("blast_radius_reused", "gitnexus_fresh", "grep_fallback"))' \
  "$SESSION_DIR/phase6-execute/ci-impact-report.json" >/dev/null && \
  echo "Group C PASS" || echo "Group C FAIL"
```

## Next Group

→ Group D Spawn Execute Agent — đọc [`phase6-execute/D-spawn-execute.md`](D-spawn-execute.md)
