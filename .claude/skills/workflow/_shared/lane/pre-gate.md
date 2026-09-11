# Lane PRE-GATE — Forensic Validation Template

> **Phien ban:** v1.0 (S3 wf-fix-bugs v7.0)
> **Ap dung cho:** 10 lane skills (QD1-QD10): `wf-fix-{functional,business,security,performance,ux-a11y,data,compat,observability,runtime-health,integration}`
> **Reference:** CORE-011 Forensic PRE-GATE, Protocol 10.4
> **Schema reference:** `_shared.md` §1 (signal-v2), §5 (lane-status-v1)

---

## Muc dich

PRE-GATE chay TRUOC khi lane bat dau probes. Muc dich:

1. **Forensic check:** Verify CONTENT cua input files (KHONG chi `test -f`)
2. **Initialize lane state:** Tao `lane-status.json` voi `status: "in_progress"`
3. **Resolve profile:** Convert `--profile` → probe subset (xem `profile-resolver.md`)
4. **Acquire probe lock:** Optional — neu probe doi hoi exclusive resource (vi du Playwright session)

PRE-GATE FAIL → lane KHONG chay probes, ghi `lane-status.json` voi `status: "failed"` + `errors[]`.

---

## Steps PRE-GATE chuan

### Step 1 — Verify orchestrator handoff

```bash
# Required env vars (set boi orchestrator wf-fix-bugs)
[ -n "${SESSION_DIR:-}" ] || { echo "ERROR: SESSION_DIR khong set" >&2; exit 1; }
[ -d "$SESSION_DIR" ] || { echo "ERROR: SESSION_DIR khong ton tai: $SESSION_DIR" >&2; exit 1; }

# Required file: fix-status.json (orchestrator state)
[ -f "$SESSION_DIR/fix-status.json" ] || { echo "ERROR: fix-status.json missing" >&2; exit 1; }

# Forensic CORE-011: KHONG chi check existence — verify content
jq -e '.session_id' "$SESSION_DIR/fix-status.json" > /dev/null || {
  echo "ERROR: fix-status.json missing session_id" >&2; exit 1;
}
jq -e '.phases.phase_1' "$SESSION_DIR/fix-status.json" > /dev/null || {
  echo "ERROR: fix-status.json.phases.phase_1 not initialized" >&2; exit 1;
}
```

### Step 2 — Verify input data (registry + source)

```bash
# Registry — bat buoc cho cross-ref
REGISTRY=".mc-data/docs/_meta/req-registry.json"
[ -f "$REGISTRY" ] || { echo "ERROR: req-registry.json missing" >&2; exit 1; }

# Forensic: registry phai co requirements (khong rong)
jq -e '.requirements | length > 0' "$REGISTRY" > /dev/null || {
  echo "ERROR: req-registry.json.requirements empty" >&2; exit 1;
}

# Source code dirs (any-of)
if [ ! -d "src" ] && [ ! -d "apps" ]; then
  echo "ERROR: Neither src/ nor apps/ exists" >&2; exit 1;
fi
```

### Step 3 — Verify dimension scope

```bash
# Lane chi chay khi dimension nam trong selected_dims (do orchestrator dispatch)
DIMENSION="${LANE_DIMENSION:-QD1}"  # Set per lane skill (vi du QD1=functional, QD2=business...)

# Optional: verify dimension trong fix-status.dimensions_resolved
SELECTED=$(jq -r '.dimensions_resolved // [] | join(",")' "$SESSION_DIR/fix-status.json")
case ",$SELECTED," in
  *",$DIMENSION,"*) ;;
  *) echo "WARN: $DIMENSION khong nam trong dimensions_resolved — orchestrator phai check truoc" >&2 ;;
esac
```

### Step 4 — Resolve profile → probe subset

```bash
PROFILE="${PROFILE:-standard}"
case "$PROFILE" in
  quick|standard|deep|exhaustive) ;;
  *) echo "ERROR: invalid profile: $PROFILE" >&2; exit 1 ;;
esac

# Lane skill goi profile-resolver de get probe list
# Xem `_shared/lane/profile-resolver.md` cho mapping cu the
```

### Step 5 — Initialize lane working dir

```bash
LANE_DIR="$SESSION_DIR/lanes/$DIMENSION"
mkdir -p "$LANE_DIR/raw"
mkdir -p "$LANE_DIR/evidence"

# Idempotent: neu LANE_DIR da ton tai (resume) → KHONG xoa
```

### Step 6 — Init lane-status.json

```bash
LANE_STATUS="$LANE_DIR/lane-status.json"

# Doc template tu _shared/lane/templates/lane-status.json
TEMPLATE_PATH=".claude/skills/workflow/_shared/lane/templates/lane-status.json"

# POPULATE template voi runtime data
SESSION_ID=$(jq -r '.session_id' "$SESSION_DIR/fix-status.json")
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

jq --arg lane "$LANE_NAME" \
   --arg dim "$DIMENSION" \
   --arg sid "$SESSION_ID" \
   --arg sdir "$SESSION_DIR" \
   --arg prof "$PROFILE" \
   --arg now "$NOW" \
   '.lane = $lane | .dimension = $dim | .session_id = $sid | .session_dir = $sdir
   | .profile = $prof | .status = "in_progress" | .started_at = $now' \
   "$TEMPLATE_PATH" > "$LANE_STATUS.tmp" && mv "$LANE_STATUS.tmp" "$LANE_STATUS"
```

### Step 7 — Init signals.json (idempotent — preserve khi resume)

> **A2 fix (2026-05-09):** PRE-GATE PHẢI idempotent trên `--resume` / retry POST-GATE.
> KHÔNG được overwrite signals.json về `signals: []` nếu file đã có signals hợp lệ
> (vì non-static probes hoặc lane_dispatch trước đó có thể đã append signals).
> Chỉ init từ template khi: file thiếu/rỗng/invalid HOẶC `lane-status.status == "failed"`.

```bash
SIGNALS_FILE="$LANE_DIR/signals.json"
TEMPLATE_PATH=".claude/skills/workflow/_shared/lane/templates/signals.json"

# A2 — Resume guard: kiểm tra file hiện hữu trước khi overwrite
SHOULD_INIT_FRESH=true

if [ -s "$SIGNALS_FILE" ]; then
  # File có nội dung — verify schema hợp lệ
  if jq -e '."$schema" == "lane-signals-v1" and (.signals | type == "array")' "$SIGNALS_FILE" > /dev/null 2>&1; then
    # Check lane-status để quyết định: status=failed → reset, ngược lại → preserve
    LANE_STATUS_FILE="$LANE_DIR/lane-status.json"
    LANE_STATE="absent"
    if [ -s "$LANE_STATUS_FILE" ]; then
      LANE_STATE=$(jq -r '.status // "absent"' "$LANE_STATUS_FILE" 2>/dev/null || echo "absent")
    fi

    if [ "$LANE_STATE" != "failed" ]; then
      EXISTING_COUNT=$(jq '.signals | length' "$SIGNALS_FILE" 2>/dev/null || echo 0)
      echo "INFO: PRE-GATE preserved signals.json ($EXISTING_COUNT signals, lane_state=$LANE_STATE)" >&2
      SHOULD_INIT_FRESH=false
    else
      echo "INFO: PRE-GATE reset signals.json (lane_state=failed)" >&2
    fi
  else
    echo "WARN: signals.json invalid → reinit từ template" >&2
  fi
fi

if [ "$SHOULD_INIT_FRESH" = "true" ]; then
  # B1 (v8.2.2): file-level lock chong race voi lane_dispatch.py / merge_signals.py /
  # emit_signal song song khac (vi du parallel lane spawn cung dim).
  if ! acquire_signals_lock "$SIGNALS_FILE" 30 300; then
    echo "ERROR: PRE-GATE Step 7 khong acquire duoc signals lock — bo qua init" >&2
    return 1
  fi
  jq --arg lane "$LANE_NAME" \
     --arg dim "$DIMENSION" \
     --arg sid "$SESSION_ID" \
     --arg sdir "$SESSION_DIR" \
     --arg prof "$PROFILE" \
     --arg now "$NOW" \
     '.lane = $lane | .dimension = $dim | .session_id = $sid | .session_dir = $sdir
     | .profile = $prof | .generated_at = $now | .signals = []' \
     "$TEMPLATE_PATH" > "$SIGNALS_FILE.tmp" && mv "$SIGNALS_FILE.tmp" "$SIGNALS_FILE"
  release_signals_lock "$SIGNALS_FILE"
fi
```

---

## PRE-GATE Failure Handling

Neu BAT KY step nao fail:

1. Update `lane-status.json` voi `status: "failed"`, append `errors[]`:
   ```json
   {
     "errors": [
       {"step": "step_2_verify_input_data", "message": "req-registry.json missing", "timestamp": "2026-04-28T10:30:00Z"}
     ]
   }
   ```
2. Tao `lane-report.md` toi thieu (chi metadata + error block) — tu template
3. Tao `phase-summary.md` voi message "Lane FAILED tai PRE-GATE: [reason]"
4. Exit non-zero — orchestrator detect failure va xu ly

---

## Resume Behavior

Khi lane resume (orchestrator pass `--resume`):

1. Doc lane-status.json hien tai
2. Neu `status == "completed"` → exit 0 (idempotent)
3. Neu `status == "in_progress"` → tiep tuc tu probe cuoi cung chua done
4. Neu `status == "failed"` → re-run PRE-GATE (clear errors[]), restart probes
5. Neu file khong ton tai → run PRE-GATE binh thuong nhu lan dau

---

## Lane-specific Extension Points

Moi lane co the bo sung steps PRE-GATE rieng (vi du QD3 security KHONG dung cache, QD5 a11y can browser):

```markdown
## Lane PRE-GATE Extensions (vi du wf-fix-security)

### Step 8 — Disable cache (ADR-22 Rule 6)

```bash
USE_CACHE="false"  # QD3 security KHONG bao gio cache
```

### Step 9 — Verify --base-url cho runtime probes

```bash
[ -n "${BASE_URL:-}" ] || echo "INFO: --base-url khong set, skip runtime probes" >&2
```
```

Lane skill SKILL.md doc PRE-GATE chi tu file nay + extension steps cua minh.
