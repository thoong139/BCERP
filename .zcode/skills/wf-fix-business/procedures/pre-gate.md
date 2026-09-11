# PRE-GATE — wf-fix-business (QD2 Lane)

> **Reference:** `_shared/lane/pre-gate.md` (steps 1-7 chuẩn cho mọi lane)
> **Schema:** `_shared/lane/_shared.md` §5 (lane-status-v1)
> **Phiên bản:** v1.0 (S4 wf-fix-bugs v7.0)

---

## Lane-Specific Variables

```bash
LANE_NAME="wf-fix-business"
DIMENSION="QD2"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD2-business"
```

## Steps Chuẩn (1-7)

Đọc và thực hiện đầy đủ theo `_shared/lane/pre-gate.md`:

1. Verify orchestrator handoff (`SESSION_DIR`, `fix-status.json`)
2. Verify input data (registry + source dirs)
3. Verify dimension scope (QD2 trong dimensions_resolved)
4. Resolve profile → probe subset (Pattern A inline, xem `_shared/lane/profile-resolver.md` §QD2)
5. Initialize lane working dir
6. Init `lane-status.json` từ shared template
7. Init `signals.json` từ shared template

## QD2-Specific Extension Steps

### Step 8 — Quick profile early exit

QD2 là dimension tốn agent token nhất. Profile `quick` SKIP toàn bộ:

```bash
if [ "$PROFILE" = "quick" ]; then
  jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     '.status = "completed" | .completed_at = $now | .skip_reason = "profile_quick_skip_QD2"' \
     "$LANE_DIR/lane-status.json" > "$LANE_DIR/lane-status.json.tmp" && \
     mv "$LANE_DIR/lane-status.json.tmp" "$LANE_DIR/lane-status.json"
  # Tạo lane-report.md + phase-summary.md tối thiểu (skip messaging)
  echo "QD2 lane bo qua (profile quick — ton token nhat). Khuyen nghi: chay --profile=standard de phat hien bug nghiep vu." > "$LANE_DIR/phase-summary.md"
  exit 0
fi
```

### Step 9 — Verify domain agents available

```bash
DEPARTMENTS=$(jq -r '.departments[]?.id // empty' "$REGISTRY_PATH" | sort -u)
for DEPT in $DEPARTMENTS; do
  AGENT_FILE=".claude/agents/business/${DEPT}-expert.md"
  if [ ! -f "$AGENT_FILE" ]; then
    echo "WARN: Domain agent $AGENT_FILE not found — P-QD2-domain-expert-review se skip dept=$DEPT" >&2
  fi
done
```

### Step 10 — Resolve probe list theo profile (QD2)

```bash
case "$PROFILE" in
  standard)
    PROBES=("P-QD2-hardcoded-value-detect" "P-QD2-calculation-check" "P-QD2-domain-expert-review")
    ;;
  deep)
    PROBES=("P-QD2-hardcoded-value-detect" "P-QD2-calculation-check"
            "P-QD2-domain-expert-review" "P-QD2-domain-fixture")
    ;;
  exhaustive)
    PROBES=("P-QD2-hardcoded-value-detect" "P-QD2-calculation-check"
            "P-QD2-domain-expert-review" "P-QD2-domain-fixture"
            "P-QD2-business-analyst-review")
    ;;
esac
```

## PRE-GATE Failure Handling

Theo `_shared/lane/pre-gate.md` §"PRE-GATE Failure Handling".

## Resume Behavior

Theo `_shared/lane/pre-gate.md` §"Resume Behavior".
