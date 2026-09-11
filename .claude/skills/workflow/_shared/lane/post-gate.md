# Lane POST-GATE — T1-T4 Schema Validation

> **Phien ban:** v1.0 (S3 wf-fix-bugs v7.0)
> **Ap dung cho:** 10 lane skills (QD1-QD10)
> **Reference:** CORE-012 POST-GATE Schema Validation, Protocol 10
> **Schema reference:** `_shared.md` §1, §5

---

## Muc dich

POST-GATE chay SAU khi lane chay xong probes. Validate output truoc khi return ve orchestrator. 4 tier:

| Tier | Ten | Check |
|------|-----|-------|
| **T1** | Existence | File ton tai + non-empty |
| **T2** | Structure | Required sections/fields hien dien |
| **T3** | Content | Minimum content depth (signals count, evidence count) |
| **T4** | Cross-reference | IDs/refs khop voi registry + lane-status |

POST-GATE FAIL → lane retry POST-GATE 2 lan, neu van fail → mark `status: "partial"`, return ve orchestrator (orchestrator quyet dinh).

---

## Output files PHAI co (after lane done)

| File | Required | Schema |
|------|----------|--------|
| `$SESSION_DIR/lanes/QDx/lane-status.json` | YES | lane-status-v1 |
| `$SESSION_DIR/lanes/QDx/signals.json` | YES | lane-signals-v1 (signal-v2 entries) |
| `$SESSION_DIR/lanes/QDx/lane-report.md` | YES | lane-report-v1 (CORE-031 template) |
| `$SESSION_DIR/lanes/QDx/phase-summary.md` | YES | CORE-028 (<=15 dong tieng Viet) |
| `$SESSION_DIR/lanes/QDx/raw/*.json` | OPTIONAL | per-probe raw outputs |
| `$SESSION_DIR/lanes/QDx/evidence/*` | OPTIONAL | screenshots, traces |

---

## T1 — Existence Check

```bash
LANE_DIR="$SESSION_DIR/lanes/$DIMENSION"

for f in "lane-status.json" "signals.json" "lane-report.md" "phase-summary.md"; do
  if [ ! -s "$LANE_DIR/$f" ]; then
    echo "T1 FAIL: $f missing or empty" >&2
    return 1
  fi
done
```

**Pass criteria:** 4/4 required files ton tai va non-empty.

---

## T2 — Structure Check

### T2.1 — lane-status.json structure

```bash
# Required JSON fields
for field in '$schema' lane dimension session_id session_dir profile status started_at probes totals; do
  jq -e ".[\"$field\"] // .\"$field\"" "$LANE_DIR/lane-status.json" > /dev/null || {
    echo "T2 FAIL: lane-status.json missing field: $field" >&2
    return 1
  }
done

# $schema phai = "lane-status-v1"
SCHEMA=$(jq -r '."$schema"' "$LANE_DIR/lane-status.json")
[ "$SCHEMA" = "lane-status-v1" ] || {
  echo "T2 FAIL: lane-status.json wrong schema: $SCHEMA" >&2; return 1;
}

# status PHAI thuoc enum
STATUS=$(jq -r '.status' "$LANE_DIR/lane-status.json")
case "$STATUS" in
  pending|in_progress|completed|partial|failed) ;;
  *) echo "T2 FAIL: invalid status: $STATUS" >&2; return 1 ;;
esac
```

### T2.2 — signals.json structure (B2 v8.2.2 — full envelope check)

```bash
SF="$LANE_DIR/signals.json"

# $schema phai = "lane-signals-v1"
SCHEMA=$(jq -r '."$schema"' "$SF")
[ "$SCHEMA" = "lane-signals-v1" ] || {
  echo "T2 FAIL: signals.json wrong schema: $SCHEMA" >&2; return 1;
}

# B2 v8.2.2 — Required canonical fields (lane-signals-v1):
#   $schema, lane, dimension, session_id, session_dir, profile,
#   generated_at, probes_executed, cache_policy, signals[]
# LLM fields (llm_merged, llm_signals_count, cross_signals_count,
# llm_dedup_dropped) la OPTIONAL — chi xuat hien sau merge_signals.py.
REQUIRED_FIELDS=(lane dimension session_id session_dir profile generated_at probes_executed cache_policy signals)
for f in "${REQUIRED_FIELDS[@]}"; do
  jq -e --arg k "$f" 'has($k)' "$SF" > /dev/null || {
    echo "T2 FAIL: signals.json missing required field: $f" >&2; return 1;
  }
done

# Type checks
jq -e '.signals | type == "array"' "$SF" > /dev/null || {
  echo "T2 FAIL: signals[] not an array" >&2; return 1;
}
jq -e '.probes_executed | type == "number"' "$SF" > /dev/null || {
  echo "T2 FAIL: probes_executed not a number" >&2; return 1;
}
# cache_policy: "allowed" | "never" | null (template default)
CACHE_POLICY=$(jq -r '.cache_policy // "null"' "$SF")
case "$CACHE_POLICY" in
  allowed|never|null) ;;
  *) echo "T2 FAIL: cache_policy invalid: $CACHE_POLICY" >&2; return 1 ;;
esac
```

### T2.3 — lane-report.md sections

```bash
# Required headings (lane-report-v1)
REPORT="$LANE_DIR/lane-report.md"
grep -q "^# Lane Report" "$REPORT" || { echo "T2 FAIL: missing title heading" >&2; return 1; }
grep -q "^## Thong tin" "$REPORT" || grep -q "^## Thông tin" "$REPORT" || {
  echo "T2 FAIL: missing thong tin section" >&2; return 1;
}
grep -q "^## Ket qua\|^## Kết quả" "$REPORT" || {
  echo "T2 FAIL: missing ket qua section" >&2; return 1;
}
grep -q "^## Tom tat\|^## Tóm tắt" "$REPORT" || {
  echo "T2 FAIL: missing tom tat section" >&2; return 1;
}
```

### T2.4 — phase-summary.md format

```bash
SUMMARY="$LANE_DIR/phase-summary.md"
LINE_COUNT=$(wc -l < "$SUMMARY")
[ "$LINE_COUNT" -le 20 ] || {
  echo "T2 FAIL: phase-summary.md too long ($LINE_COUNT lines, max 15-20)" >&2; return 1;
}
grep -q "Phase Summary" "$SUMMARY" || {
  echo "T2 FAIL: phase-summary.md missing title" >&2; return 1;
}
```

---

## T3 — Content Depth

### T3.1 — Per-signal validation

```bash
# Moi signal PHAI co required fields (signal-v2)
INVALID=$(jq '
  [.signals[] | select(
    (."$schema" != "signal-v2")
    or (.id == null or .id == "")
    or (.dimension_id == null or .dimension_id == "")
    or (.severity == null)
    or (.fixability == null)
    or (.title == null or .title == "")
    or (.location.file == null or .location.file == "")
    or (.fingerprint == null or .fingerprint == "")
  )] | length
' "$LANE_DIR/signals.json")

[ "$INVALID" = "0" ] || {
  echo "T3 FAIL: $INVALID signals invalid (missing required fields)" >&2; return 1;
}

# Severity enum check
INVALID_SEV=$(jq '
  [.signals[] | select(.severity != "critical" and .severity != "high"
    and .severity != "medium" and .severity != "low" and .severity != "info")] | length
' "$LANE_DIR/signals.json")

[ "$INVALID_SEV" = "0" ] || {
  echo "T3 FAIL: $INVALID_SEV signals voi severity invalid" >&2; return 1;
}

# Fixability enum check
INVALID_FIX=$(jq '
  [.signals[] | select(.fixability != "auto_fix" and .fixability != "agent_fix"
    and .fixability != "escalate" and .fixability != "skip")] | length
' "$LANE_DIR/signals.json")

[ "$INVALID_FIX" = "0" ] || {
  echo "T3 FAIL: $INVALID_FIX signals voi fixability invalid" >&2; return 1;
}
```

### T3.2 — Fingerprint uniqueness

```bash
TOTAL=$(jq '.signals | length' "$LANE_DIR/signals.json")
UNIQUE=$(jq '[.signals[].fingerprint] | unique | length' "$LANE_DIR/signals.json")

[ "$TOTAL" = "$UNIQUE" ] || {
  echo "T3 FAIL: $((TOTAL - UNIQUE)) signal fingerprints duplicated" >&2; return 1;
}
```

### T3.3 — Probes count consistency

```bash
# probes[] count phai >= 1 (lane phai chay it nhat 1 probe, hoac fail PRE-GATE)
PROBE_COUNT=$(jq '.probes | length' "$LANE_DIR/lane-status.json")
[ "$PROBE_COUNT" -ge 1 ] || {
  echo "T3 FAIL: probes[] empty in lane-status.json" >&2; return 1;
}

# totals.signals_emitted phai khop voi signals[].length
EMITTED=$(jq '.totals.signals_emitted' "$LANE_DIR/lane-status.json")
ACTUAL=$(jq '.signals | length' "$LANE_DIR/signals.json")
[ "$EMITTED" = "$ACTUAL" ] || {
  echo "T3 FAIL: totals.signals_emitted ($EMITTED) != signals[] length ($ACTUAL)" >&2; return 1;
}
```

---

## T4 — Cross-reference Check

### T4.1 — Signal location.file ton tai

```bash
# Sample 5 signals random — check file path real (chong fantasy)
jq -r '.signals[0:5] | .[] | .location.file' "$LANE_DIR/signals.json" | while read f; do
  [ -n "$f" ] && [ -f "$f" ] || {
    echo "T4 WARN: signal location.file khong ton tai: $f" >&2
    # WARN, KHONG return 1 — vi co the la deleted file
  }
done
```

### T4.2 — REQ-ID/FEAT-ID xref voi registry (neu signal co)

```bash
REGISTRY=".mc-data/docs/_meta/req-registry.json"

# Check moi REQ-ID trong signal.registry_refs.req_ids ton tai trong registry
jq -r '.signals[].registry_refs.req_ids[]?' "$LANE_DIR/signals.json" 2>/dev/null | sort -u | while read req_id; do
  [ -z "$req_id" ] && continue
  if ! jq -e ".requirements[] | select(.id == \"$req_id\")" "$REGISTRY" > /dev/null 2>&1; then
    echo "T4 WARN: REQ-ID $req_id (in signal) khong co trong registry" >&2
  fi
done
```

### T4.3 — Probe IDs khop voi probes[] declared

```bash
# Probes trong signals[].probe_id PHAI khop voi probes[].id trong lane-status.json
DECLARED=$(jq -r '.probes[].id' "$LANE_DIR/lane-status.json" | sort -u)
EMITTED=$(jq -r '.signals[].probe_id' "$LANE_DIR/signals.json" | sort -u)

for p in $EMITTED; do
  echo "$DECLARED" | grep -qx "$p" || {
    echo "T4 FAIL: signal references probe '$p' khong declared trong lane-status.probes[]" >&2
    return 1
  }
done
```

---

## POST-GATE Pass Criteria

ALL 4 tiers PASS → lane status = `completed` (hoac `partial` neu probes failed_count > 0).

```bash
# Update lane-status.json sau khi POST-GATE pass
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PROBES_FAILED=$(jq '[.probes[] | select(.status == "failed")] | length' "$LANE_DIR/lane-status.json")

if [ "$PROBES_FAILED" -eq 0 ]; then
  FINAL_STATUS="completed"
else
  FINAL_STATUS="partial"
fi

jq --arg now "$NOW" --arg status "$FINAL_STATUS" \
   '.completed_at = $now | .status = $status' \
   "$LANE_DIR/lane-status.json" > "$LANE_DIR/lane-status.json.tmp" \
   && mv "$LANE_DIR/lane-status.json.tmp" "$LANE_DIR/lane-status.json"
```

---

## Failure Handling

POST-GATE FAIL retry tu dong (max 2 lan):

1. Lan 1 fail → log loi → re-run POST-GATE (co the do file ghi cham)
2. Lan 2 fail → log loi → mark `status: "partial"` neu signals da co, hoac `status: "failed"` neu khong co signals
3. Final state: return ve orchestrator voi error[] in lane-status.json

Orchestrator (`wf-fix-bugs`) detect lane status:
- `completed` → continue aggregate
- `partial` → aggregate signals available + warn user
- `failed` → exclude lane khoi report, log warning

---

## Verify-fix Loop

POST-GATE bi fail → lane skill thuc hien:

```
Iteration 1: Run POST-GATE → FAIL → log issue → fix automatic (vi du regenerate report) → re-run POST-GATE
Iteration 2: Run POST-GATE → FAIL → log issue → escalate to user (CDG)
Iteration 3: Run POST-GATE → FAIL → mark partial, return
```

Max 3 iterations theo Protocol 10. Sau 3 lan fail → lane status = `partial` hoac `failed`.

---

## CORE-028 Phase Summary

POST-GATE pass → tao `phase-summary.md` (tieng Viet, <=15 dong, non-technical):

```bash
# Doc template tu _shared/lane/templates/phase-summary.md
TEMPLATE_PATH=".claude/skills/workflow/_shared/lane/templates/phase-summary.md"

# POPULATE template voi runtime data tu lane-status.json
# Vi du fields can fill: [DIMENSION], [DIMENSION_NAME], [PROFILE],
# [N], [a], [b], [c], [d], [e] (severity counts), [X], [Y], [Z] (probe counts)
# [mm] (duration), [SUMMARY], [DECISION_NEEDED], [ADVICE]
```

Xem `templates/phase-summary.md` cho format chi tiet.
