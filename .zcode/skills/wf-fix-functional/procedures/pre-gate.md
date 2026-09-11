# PRE-GATE — wf-fix-functional (QD1 Lane)

> **Reference:** `_shared/lane/pre-gate.md` (steps 1-7 chuẩn cho mọi lane)
> **Schema:** `_shared/lane/_shared.md` §5 (lane-status-v1)
> **Phiên bản:** v1.0 (S4 wf-fix-bugs v7.0)

---

## Lane-Specific Variables

```bash
LANE_NAME="wf-fix-functional"
DIMENSION="QD1"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional"
```

## Steps Chuẩn (1-7)

Đọc và thực hiện đầy đủ theo `_shared/lane/pre-gate.md`:

1. Verify orchestrator handoff (`SESSION_DIR`, `fix-status.json`)
2. Verify input data (registry + source dirs)
3. Verify dimension scope (QD1 trong dimensions_resolved)
4. Resolve profile → probe subset (dùng Pattern A inline shell, xem `_shared/lane/profile-resolver.md` §QD1)
5. Initialize lane working dir (`mkdir -p $LANE_DIR/{raw,evidence}`)
6. Init `lane-status.json` từ template `_shared/lane/templates/lane-status.json`
7. Init `signals.json` từ template `_shared/lane/templates/signals.json`

## QD1-Specific Extension Steps

### Step 8 — Verify --base-url cho runtime probes (optional)

```bash
if [ -z "${BASE_URL:-}" ]; then
  echo "INFO: BASE_URL khong set, runtime probes (P-QD1-infra-preflight, P-QD1-deep-ui-traversal, P-QD1-api-smoke) se skip" >&2
  RUNTIME_PROBES_AVAILABLE=false
else
  RUNTIME_PROBES_AVAILABLE=true
fi
```

### Step 9 — Resolve probe list theo profile (QD1)

```bash
case "$PROFILE" in
  quick)
    PROBES=("P-QD1-req-registry-xref" "P-QD1-route-config-parse")
    ;;
  standard)
    PROBES=("P-QD1-req-registry-xref" "P-QD1-route-config-parse"
            "P-QD1-infra-preflight" "P-QD1-api-smoke" "P-QD1-orphan-ui-detect")
    ;;
  deep|exhaustive)
    PROBES=("P-QD1-req-registry-xref" "P-QD1-route-config-parse"
            "P-QD1-infra-preflight" "P-QD1-deep-ui-traversal"
            "P-QD1-api-smoke" "P-QD1-orphan-ui-detect"
            "P-QD1-agent-feature-verify")
    ;;
esac
```

## PRE-GATE Failure Handling

Theo `_shared/lane/pre-gate.md` §"PRE-GATE Failure Handling": ghi `lane-status.json` với `status: "failed"` + `errors[]`, exit non-zero.

## Resume Behavior

Theo `_shared/lane/pre-gate.md` §"Resume Behavior": idempotent re-entry, skip nếu `status == "completed"`.
