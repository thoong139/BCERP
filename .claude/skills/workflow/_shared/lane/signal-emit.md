# Lane Signal Emit Protocol

> **Phien ban:** v1.0 (S3 wf-fix-bugs v7.0)
> **Ap dung cho:** 10 lane skills (QD1-QD10) + probes
> **Muc dich:** Cach emit signal atomic + dedup vao `lanes/QDx/signals.json`
> **Schema reference:** `_shared.md` §1 (signal-v2)

---

## Nguyen tac

1. **Atomic emit** — 1 signal = 1 jq update + atomic mv (KHONG partial write)
2. **Dedup theo fingerprint** — KHONG emit signal trung lap (same file+line+probe+dimension)
3. **APPEND-only** — KHONG xoa signal cu khi emit moi (lane-local signals[] APPEND)
4. **Counter monotonic** — `id = SIG-QDx-NNN` voi NNN tang theo thu tu emit
5. **Evidence first** — TAO file evidence TRUOC khi emit signal (transactional voi evidence)

---

## Signal ID generation

```bash
# Lay counter hien tai tu signals.json
SIGNALS_FILE="$LANE_DIR/signals.json"
NEXT_NUM=$(jq '[.signals[].id] | map(split("-")[-1] | tonumber) | (max // 0) + 1' "$SIGNALS_FILE")
SIGNAL_ID=$(printf "SIG-%s-%03d" "$DIMENSION" "$NEXT_NUM")
```

Format: `SIG-QD1-001`, `SIG-QD1-002`, ...

---

## Fingerprint generation

Fingerprint la sha256 cua TUPLE `(dimension_id, location.file, location.line, probe_id, signal_type)` — dedup key duy nhat.

```bash
generate_fingerprint() {
  local dim="$1" file="$2" line="${3:-0}" probe="$4" sig_type="${5:-issue}"
  echo -n "${dim}|${file}|${line}|${probe}|${sig_type}" | sha256sum | awk '{print "sha256:"$1}'
}

FINGERPRINT=$(generate_fingerprint "$DIMENSION" "$FILE" "$LINE" "$PROBE_ID" "$SIG_TYPE")
```

---

## Atomic emit pattern

### Step 1 — Tao evidence files truoc

```bash
# Probe ghi raw output truoc khi emit signal
EVIDENCE_PATH="$LANE_DIR/evidence/screenshot-${SIG_NUM}.png"
# ... probe tao evidence file (Playwright, curl, ...) ...

# Verify evidence ton tai truoc khi reference
[ -s "$EVIDENCE_PATH" ] || { echo "ERROR: evidence file khong duoc tao" >&2; return 1; }
```

### Step 2 — Build signal JSON

```bash
SIGNAL=$(jq -n \
  --arg id "$SIGNAL_ID" \
  --arg dim "$DIMENSION" \
  --arg probe "$PROBE_ID" \
  --arg pver "$PROBE_VERSION" \
  --arg sev "$SEVERITY" \
  --arg fix "$FIXABILITY" \
  --arg dom "$DOMAIN" \
  --arg title "$TITLE" \
  --arg desc "$DESCRIPTION" \
  --arg file "$FILE" \
  --argjson line "${LINE:-null}" \
  --arg fp "$FINGERPRINT" \
  --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg detector "$LANE_NAME/$PROBE_ID" \
  --arg evpath "$EVIDENCE_PATH" \
  --arg evdesc "$EVIDENCE_DESC" \
  --arg evtype "${EVIDENCE_TYPE:-stdout}" \
  '{
    "$schema": "signal-v2",
    id: $id,
    dimension_id: $dim,
    probe_id: $probe,
    probe_version: $pver,
    severity: $sev,
    fixability: $fix,
    domain: $dom,
    title: $title,
    description: $desc,
    location: {file: $file, line: $line, column: null, selector: null, url: null},
    evidence: [{type: $evtype, path: $evpath, description: $evdesc}],
    cdg_flags: [],
    fingerprint: $fp,
    detected_at: $now,
    detected_by: $detector
  }')
```

### Step 3 — Dedup check

```bash
# Check fingerprint co ton tai chua
EXISTING=$(jq --arg fp "$FINGERPRINT" '.signals | map(select(.fingerprint == $fp)) | length' "$SIGNALS_FILE")

if [ "$EXISTING" -gt 0 ]; then
  echo "INFO: signal voi fingerprint $FINGERPRINT da ton tai → skip emit" >&2
  return 0
fi
```

### Step 4 — Atomic append + update lane-status

```bash
# Append signal vao signals.json (atomic)
TMP="$SIGNALS_FILE.tmp.$$"
jq --argjson sig "$SIGNAL" '.signals += [$sig]' "$SIGNALS_FILE" > "$TMP"

# Validate JSON before mv
jq -e '.' "$TMP" > /dev/null || { rm -f "$TMP"; echo "ERROR: invalid JSON" >&2; return 1; }
mv "$TMP" "$SIGNALS_FILE"

# Update lane-status.json totals
LANE_STATUS="$LANE_DIR/lane-status.json"
TMP="$LANE_STATUS.tmp.$$"
jq --arg sev "$SEVERITY" '
  .totals.signals_emitted += 1
  | .totals.signals_by_severity[$sev] += 1
' "$LANE_STATUS" > "$TMP"
mv "$TMP" "$LANE_STATUS"
```

---

## Helper function (recommended)

Dat trong probe script hoac inline trong lane SKILL.md:

```bash
emit_signal() {
  local lane_dir="$1" probe_id="$2" probe_version="$3"
  local severity="$4" fixability="$5" domain="$6"
  local title="$7" description="$8"
  local file="$9" line="${10:-null}"
  local evidence_type="${11:-stdout}" evidence_path="${12}" evidence_desc="${13}"

  local signals_file="$lane_dir/signals.json"
  local lane_status="$lane_dir/lane-status.json"
  local dim=$(jq -r '.dimension' "$lane_status")

  # 1. Generate ID + fingerprint
  local next_num=$(jq '[.signals[].id] | map(split("-")[-1] | tonumber) | (max // 0) + 1' "$signals_file")
  local sig_id=$(printf "SIG-%s-%03d" "$dim" "$next_num")
  local fp=$(echo -n "${dim}|${file}|${line}|${probe_id}|issue" | sha256sum | awk '{print "sha256:"$1}')

  # 2. Dedup check
  local existing=$(jq --arg fp "$fp" '.signals | map(select(.fingerprint == $fp)) | length' "$signals_file")
  if [ "$existing" -gt 0 ]; then
    echo "INFO: dedup skip $fp" >&2
    return 0
  fi

  # 3. Build + emit
  local now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local sig=$(jq -n \
    --arg id "$sig_id" --arg dim "$dim" --arg probe "$probe_id" --arg pver "$probe_version" \
    --arg sev "$severity" --arg fix "$fixability" --arg dom "$domain" \
    --arg title "$title" --arg desc "$description" \
    --arg file "$file" --argjson ln "$line" \
    --arg fp "$fp" --arg now "$now" --arg detector "$probe_id" \
    --arg evtype "$evidence_type" --arg evpath "$evidence_path" --arg evdesc "$evidence_desc" \
    '{
      "$schema": "signal-v2", id: $id, dimension_id: $dim,
      probe_id: $probe, probe_version: $pver, severity: $sev, fixability: $fix, domain: $dom,
      title: $title, description: $desc,
      location: {file: $file, line: $ln, column: null, selector: null, url: null},
      evidence: [{type: $evtype, path: $evpath, description: $evdesc}],
      cdg_flags: [], fingerprint: $fp,
      detected_at: $now, detected_by: $detector
    }')

  # 4. Atomic write — B1 (v8.2.2): file-level lock chong race voi
  # lane_dispatch.py + merge_signals.py (cung path convention .lock/).
  local emit_rc=0
  if ! acquire_signals_lock "$signals_file" 30 300; then
    echo "ERROR: emit_signal khong acquire duoc signals lock — race possible" >&2
    return 1
  fi
  local tmp="$signals_file.tmp.$$"
  if jq --argjson sig "$sig" '.signals += [$sig]' "$signals_file" > "$tmp" \
    && jq -e '.' "$tmp" > /dev/null \
    && mv "$tmp" "$signals_file"; then
    emit_rc=0
  else
    rm -f "$tmp"
    emit_rc=1
  fi
  release_signals_lock "$signals_file"
  [ "$emit_rc" -eq 0 ] || return 1

  # 5. Update totals (lane-status.json — KHONG dung signals lock)
  local sttmp="$lane_status.tmp.$$"
  jq --arg sev "$severity" '
    .totals.signals_emitted += 1
    | .totals.signals_by_severity[$sev] += 1
  ' "$lane_status" > "$sttmp" && mv "$sttmp" "$lane_status"

  echo "$sig_id"  # return sig_id cho caller
}
```

**Yeu cau:** caller phai source `.claude/scripts/wf-fix-common.sh` truoc khi
goi `emit_signal` de helper `acquire_signals_lock` + `release_signals_lock`
co the resolve. Probe runtime do `wf-fix-bugs/procedures/phase1-engine.md`
ensure (PRE-GATE source common.sh).

---

## CDG flag attachment

Neu signal can CDG (vi du fix se delete data):

```bash
# Sau khi emit signal, append cdg_flags
jq --arg id "$SIG_ID" '
  .signals = [.signals[] |
    if .id == $id then .cdg_flags += ["CDG-DELETE-DATA"] else . end]
' "$SIGNALS_FILE" > "$SIGNALS_FILE.tmp" && mv "$SIGNALS_FILE.tmp" "$SIGNALS_FILE"
```

CDG codes — xem `_shared.md` §6.

---

## Concurrent safety

Lanes chay parallel (orchestrator dispatch parallel) — moi lane ghi `lanes/QDx/signals.json` doc lap.

**Cross-writer race (v8.2.0 → v8.2.2 fix):** lane_dispatch.py (Python),
emit_signal (bash), merge_signals.py (Python) co the cung touch
`lanes/QDx/signals.json` (vi du resume + LLM merge song song).

→ B1 fix: file-level lock `<signals_file>.lock/` (mkdir POSIX atomic)
duoc share giua bash + Python. Convention chung:

| Writer | Lock helper |
|--------|-------------|
| `lane_dispatch.py` (static probes) | `_signals_lock_acquire()` |
| `signal-emit.md emit_signal` (non-static probes) | `acquire_signals_lock` |
| `merge_signals.py` (LLM signals) | `_signals_lock_acquire()` |

Timeout 30s, stale 5min. Lock failure → log WARNING, fallback
non-locked write (best-effort, A1 merge defense van bao ve preserve).

Probe parallel ben trong (vi du QD1 spawn 3 sub-probes) — `acquire_signals_lock`
serialize all writes ve cung file. Bo qua khi write timeout (>30s) — race
moi co the xay ra; A1 _merge_static_signals lay lai non-static signals tu
existing file.
