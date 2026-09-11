# P-QD4-memory-leak-scan — Quet phat hien patterns gay memory leak

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD4-memory-leak-scan |
| **Loai** | static |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Phat hien patterns co the gay memory leak: (1) addEventListener thieu removeEventListener, (2) setInterval/setTimeout thieu clear, (3) useEffect thieu cleanup return, (4) large objects trong module scope, (5) closures giam bien lon, (6) DOM reference leak (detached DOM nodes). |
| **Cache** | **allowed** (static analysis — deterministic) |
| **Migrates from** | Stage D (new) |

## PRE-GATE

```
IF khong co source dir (src/, app/, lib/, components/, ui/) -> SKIP, note "no_source"
IF profile=quick -> SKIP (memory leak scan chi chay standard+)
IF frontend project (React/Vue/Svelte detected) -> chay tat ca checks
IF backend project (Node.js/Deno/Bun) -> chi chay checks 2, 3, 5 (bo qua DOM-related)
```

## SENSE

### B1: Delegate to inline bash static analysis (S5 v7.0)

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD4-performance/raw/P-QD4-memory-leak-scan.json"
mkdir -p "$(dirname "$RAW_OUT")"
SIGNALS_JSON='[]'

SOURCE="${SOURCE_DIR:-src/}"
if [ ! -d "$SOURCE" ]; then
  for candidate in app lib components ui pages; do
    [ -d "$candidate" ] && { SOURCE="$candidate"; break; }
  done
fi

if [ ! -d "$SOURCE" ]; then
  cat > "$RAW_OUT" <<EOF
{"\$schema":"lane-signals-v1","lane":"wf-fix-performance","dimension":"QD4",
 "probe_id":"P-QD4-memory-leak-scan","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"no_source_dir"}
EOF
  exit 0
fi

# Detect frontend vs backend
IS_FRONTEND=false
if [ -f package.json ]; then
  if grep -qE '"react"|"vue"|"svelte"|"angular"' package.json 2>/dev/null; then
    IS_FRONTEND=true
  fi
fi

# ============================================================
# Check 1: addEventListener without removeEventListener (frontend)
# ============================================================
if [ "$IS_FRONTEND" = true ]; then
  while IFS=: read -r file line match; do
    [ -z "$file" ] && continue
    # Count add vs remove in file
    add_count=$(grep -c 'addEventListener' "$file" 2>/dev/null || echo 0)
    remove_count=$(grep -c 'removeEventListener' "$file" 2>/dev/null || echo 0)
    if [ "$add_count" -gt "$remove_count" ]; then
      count_mismatch=$((add_count - remove_count))
      fp=$(echo -n "QD4|$file|$line|P-QD4-memory-leak-scan|event_listener_leak" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
      sig=$(jq -nc \
        --arg file "$file" --argjson line "$line" \
        --argjson add_count "$add_count" --argjson remove_count "$remove_count" \
        --arg snippet "$(echo "$match" | head -c 80)" \
        --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
          "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-memory-leak-scan",
          probe_version: "v1.0", severity: "high", fixability: "agent_fix", domain: "frontend",
          title: ("Event listener leak: " + ($add_count | tostring) + " add vs " + ($remove_count | tostring) + " remove in " + $file),
          description: ("File " + $file + ":" + ($line | tostring) + " co " + ($add_count | tostring) + " addEventListener nhung chi " + ($remove_count | tostring) + " removeEventListener. Event listeners khong duoc cleanup se giam memory khi component unmount."),
          location: {file: $file, line: $line, column: null, selector: null, url: null},
          evidence: [{type: "code", path: $file, description: ($snippet)}],
          cdg_flags: [], fingerprint: $fp,
          remediation: {suggested_action: "Them removeEventListener tuong ung trong cleanup phase (useEffect return / componentWillUnmount)", suggested_agent: "frontend-developer", estimated_effort: "low"},
          detected_at: $now, detected_by: "wf-fix-performance/P-QD4-memory-leak-scan"
        }')
      SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
    fi
    break 1  # chi can 1 signal per file, break sau file dau
  done < <(grep -rn 'addEventListener' "$SOURCE" \
            --include='*.tsx' --include='*.jsx' --include='*.ts' --include='*.js' --include='*.vue' --include='*.svelte' \
            2>/dev/null | grep -vE '(node_modules|__tests__|\.test\.|\.spec\.|\.map$)' || true)
fi

# ============================================================
# Check 2: setInterval / setTimeout without clearInterval / clearTimeout
# ============================================================
while IFS=: read -r file line match; do
  [ -z "$file" ] && continue
  add_count=$(grep -cE '(setInterval|setTimeout)' "$file" 2>/dev/null || echo 0)
  remove_count=$(grep -cE '(clearInterval|clearTimeout)' "$file" 2>/dev/null || echo 0)
  if [ "$add_count" -gt "$remove_count" ]; then
    # Check if it's inside useEffect (React) - may have cleanup in same file
    in_use_effect=false
    if grep -qzP 'useEffect\s*\([^)]*\)\s*\{[^}]*set(Interval|Timeout)' "$file" 2>/dev/null; then
      # Check if there's a return cleanup
      block=$(grep -ozP 'useEffect\s*\([^)]*\)\s*\{[^}]*\}' "$file" 2>/dev/null || echo "")
      if echo "$block" | grep -q 'return.*clear'; then
        continue  # Has cleanup, skip
      fi
    fi

    fp=$(echo -n "QD4|$file|$line|P-QD4-memory-leak-scan|interval_leak" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
    sig=$(jq -nc \
      --arg file "$file" --argjson line "$line" \
      --arg snippet "$(echo "$match" | head -c 80)" \
      --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{
        "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-memory-leak-scan",
        probe_version: "v1.0", severity: "medium", fixability: "agent_fix", domain: "general",
        title: "Interval/Timer leak - thieu clear",
        description: ("Phat hien setInterval/setTimeout khong co clear tuong ung tai " + $file + ":" + ($line | tostring) + ". Timer khong duoc cleanup co the tiep tuc chay sau khi component unmount hoac page close."),
        location: {file: $file, line: $line, column: null, selector: null, url: null},
        evidence: [{type: "code", path: $file, description: ($snippet)}],
        cdg_flags: [], fingerprint: $fp,
        remediation: {suggested_action: "Luu interval/timeout ID va clear trong cleanup: clearInterval(intervalId) / clearTimeout(timeoutId)", suggested_agent: "frontend-developer", estimated_effort: "low"},
        detected_at: $now, detected_by: "wf-fix-performance/P-QD4-memory-leak-scan"
      }')
    SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
  fi
done < <(grep -rnE 'setInterval|setTimeout' "$SOURCE" \
          --include='*.tsx' --include='*.jsx' --include='*.ts' --include='*.js' --include='*.vue' --include='*.svelte' \
          2>/dev/null | grep -vE '(node_modules|__tests__|\.test\.|\.spec\.|\.map$)' || true)

# ============================================================
# Check 3: useEffect without cleanup return (React-specific)
# ============================================================
if [ "$IS_FRONTEND" = true ]; then
  while IFS=: read -r file line match; do
    [ -z "$file" ] && continue
    # Skip files that already have cleanup patterns
    if grep -qE 'return.*(clearInterval|clearTimeout|removeEventListener|removeObserver|unsubscribe|destroy|disconnect|cleanup)' "$file" 2>/dev/null; then
      continue
    fi
    fp=$(echo -n "QD4|$file|$line|P-QD4-memory-leak-scan|use_effect_cleanup" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
    sig=$(jq -nc \
      --arg file "$file" --argjson line "$line" \
      --arg snippet "$(echo "$match" | head -c 80)" \
      --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{
        "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-memory-leak-scan",
        probe_version: "v1.0", severity: "high", fixability: "agent_fix", domain: "frontend",
        title: "useEffect co subscriptions/events thieu cleanup",
        description: ("useEffect tai " + $file + ":" + ($line | tostring) + " co subscriptions (addEventListener/interval/subscribe) nhung khong co return cleanup function. Component unmount khong cleanup -> memory leak."),
        location: {file: $file, line: $line, column: null, selector: null, url: null},
        evidence: [{type: "code", path: $file, description: ($snippet)}],
        cdg_flags: [], fingerprint: $fp,
        remediation: {suggested_action: "Them return cleanup function trong useEffect: return () => { /* remove listeners, clear intervals */ }", suggested_agent: "frontend-developer", estimated_effort: "low"},
        detected_at: $now, detected_by: "wf-fix-performance/P-QD4-memory-leak-scan"
      }')
    SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
  done < <(grep -rnE 'useEffect\s*\(' "$SOURCE" \
            --include='*.tsx' --include='*.jsx' --include='*.ts' --include='*.js' \
            2>/dev/null | grep -vE '(node_modules|__tests__|\.test\.|\.spec\.|\.map$)' \
            | head -30 || true)
fi

# ============================================================
# Check 4: Large objects in module/global scope
# ============================================================
while IFS=: read -r file line match; do
  [ -z "$file" ] && continue
  fp=$(echo -n "QD4|$file|$line|P-QD4-memory-leak-scan|module_scope_object" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
  sig=$(jq -nc \
    --arg file "$file" --argjson line "$line" \
    --arg snippet "$(echo "$match" | head -c 80)" \
    --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-memory-leak-scan",
      probe_version: "v1.0", severity: "medium", fixability: "agent_fix", domain: "general",
      title: "Large persistent object trong module scope",
      description: ("Phat hien large object/array trong module scope tai " + $file + ":" + ($line | tostring) + ". Object o module scope ton tai suot vong doi app va khong bao gio duoc GC. Co the gay memory growth neu du lieu accumulate."),
      location: {file: $file, line: $line, column: null, selector: null, url: null},
      evidence: [{type: "code", path: $file, description: ($snippet)}],
      cdg_flags: [], fingerprint: $fp,
      remediation: {suggested_action: "Xem xet dung WeakMap/WeakSet de cho phep GC, hoac gioi han cache size bang LRU pattern", suggested_agent: "developer", estimated_effort: "medium"},
      detected_at: $now, detected_by: "wf-fix-performance/P-QD4-memory-leak-scan"
    }')
  SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
done < <(grep -rnE '(const|let|var)\s+\w+\s*=\s*\{\s*$|const\s+\w+\s*=\s*\[\s*$|new\s+(Map|Set)\s*\(\s*$' "$SOURCE" \
          --include='*.ts' --include='*.js' --include='*.tsx' --include='*.jsx' \
          2>/dev/null | grep -vE '(node_modules|__tests__|\.test\.|\.spec\.|\.map$)' \
          | grep -vE '(export|module\.exports)' | head -20 || true)

# ============================================================
# Check 5: Circular references via closures (WebSocket / Observable patterns)
# ============================================================
while IFS=: read -r file line match; do
  [ -z "$file" ] && continue
  fp=$(echo -n "QD4|$file|$line|P-QD4-memory-leak-scan|closure_reference_leak" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
  sig=$(jq -nc \
    --arg file "$file" --argjson line "$line" \
    --arg snippet "$(echo "$match" | head -c 80)" \
    --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-memory-leak-scan",
      probe_version: "v1.0", severity: "medium", fixability: "agent_fix", domain: "general",
      title: "Potential closure-captured reference giam memory",
      description: ("Phat hien subscription/callback pattern tai " + $file + ":" + ($line | tostring) + ". Callback capture outer scope co the giam references -> ngăn GC. Dung WeakRef hoac cleanup handler."),
      location: {file: $file, line: $line, column: null, selector: null, url: null},
      evidence: [{type: "code", path: $file, description: ($snippet)}],
      cdg_flags: [], fingerprint: $fp,
      remediation: {suggested_action: "Dam bao unsubscribe/remove callback khi khong con can. Dung WeakRef cho large object references trong closure.", suggested_agent: "developer", estimated_effort: "medium"},
      detected_at: $now, detected_by: "wf-fix-performance/P-QD4-memory-leak-scan"
    }')
  SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
done < <(grep -rnE '\.(subscribe|on\s*\(|addListener|observe|watch)\s*\(' "$SOURCE" \
          --include='*.ts' --include='*.js' --include='*.tsx' --include='*.jsx' --include='*.py' \
          2>/dev/null | grep -vE '(node_modules|__tests__|\.test\.|\.spec\.|\.map$)' \
          | grep -vE '(unsubscribe|removeListener|dispose)' | head -20 || true)

# ============================================================
# Check 6: Detached DOM references (frontend only)
# ============================================================
if [ "$IS_FRONTEND" = true ]; then
  while IFS=: read -r file line match; do
    [ -z "$file" ] && continue
    fp=$(echo -n "QD4|$file|$line|P-QD4-memory-leak-scan|detached_dom" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
    sig=$(jq -nc \
      --arg file "$file" --argjson line "$line" \
      --arg snippet "$(echo "$match" | head -c 80)" \
      --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{
        "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-memory-leak-scan",
        probe_version: "v1.0", severity: "medium", fixability: "agent_fix", domain: "frontend",
        title: "DOM reference co the gay detached DOM tree leak",
        description: ("Phat hien DOM element reference luu trong variable tai " + $file + ":" + ($line | tostring) + ". Khi element bi remove khoi DOM, reference van ton tai -> detached DOM tree khong duoc GC."),
        location: {file: $file, line: $line, column: null, selector: null, url: null},
        evidence: [{type: "code", path: $file, description: ($snippet)}],
        cdg_flags: [], fingerprint: $fp,
        remediation: {suggested_action: "Set DOM reference = null khi element bi remove, hoac dung querySelector trong scope thay vi global reference", suggested_agent: "frontend-developer", estimated_effort: "low"},
        detected_at: $now, detected_by: "wf-fix-performance/P-QD4-memory-leak-scan"
      }')
    SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
  done < <(grep -rnE '(document\.getElementById|document\.querySelector|document\.getElementsByClassName|ref\s*=)\s*[({]' "$SOURCE" \
            --include='*.tsx' --include='*.jsx' --include='*.ts' --include='*.js' --include='*.vue' --include='*.svelte' \
            2>/dev/null | grep -vE '(node_modules|__tests__|\.test\.|\.spec\.|\.map$)' \
            | grep -vE '(useRef|useTemplateRef)' | head -15 || true)
fi

# Final output
jq -nc \
  --arg lane "wf-fix-performance" --arg probe "P-QD4-memory-leak-scan" --arg pver "v1.0" \
  --arg profile "${PROFILE:-standard}" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson signals "$SIGNALS_JSON" \
  '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD4", probe_id: $probe,
    probe_version: $pver, profile: $profile, generated_at: $now, signals: $signals}' \
  > "$RAW_OUT"
```

**Bash script handles:**
- Event listener leak (Check 1): count `addEventListener` vs `removeEventListener` calls per file. Neu add > remove -> HIGH. Chi chay frontend mode.
- Interval/Timer leak (Check 2): count `setInterval/setTimeout` vs `clearInterval/clearTimeout`. Kiem tra xem co cleanup trong useEffect return khong -> skip neu co. MEDIUM.
- useEffect cleanup (Check 3): grep useEffect calls co subscriptions (addEventListener/interval/subscribe) nhung thieu return cleanup function. HIGH. Frontend only.
- Module scope objects (Check 4): phat hien large objects/arrays/Maps/Sets o module scope level -> ton tai suot vong doi app. MEDIUM.
- Closure reference leak (Check 5): subscription/callback patterns (subscribe, on(), addListener) thieu cleanup. MEDIUM.
- Detached DOM (Check 6): DOM element references duoc luu trong variable (getElementById, querySelector) co the gay detached tree. MEDIUM. Frontend only.
- Frontend/backend detection: check package.json dependencies

### B2: Scan Cache check

```bash
if [ "${USE_CACHE:-0}" -eq 1 ]; then
  python -m _shared.scan_cache.cache_lookup \
    --cache-root .mc-data/cache/wf-fix-bugs/probes/ \
    --probe-id P-QD4-memory-leak-scan --probe-version 1.0.0 \
    >> "$RAW_OUT.cache" 2>/dev/null || true
fi
```

## THINK

Inline bash logic:
1. **Event listener leak:** addEventListener ma khong co removeEventListener dong cap => listeners accumulate khi component mount/unmount nhieu lan => HIGH. Each listener giam reference den component => khong GC duoc.
2. **Interval/Timer leak:** setInterval/setTimeout khong duoc clear => tiep tuc chay trong background => MEDIUM. Dac biet nguy hiem neu callback capture large state.
3. **useEffect cleanup:** useEffect tao subscriptions (WebSocket, event listeners, intervals) nhung khong return cleanup => HIGH. React component unmount nhung subscriptions van chay.
4. **Module scope objects:** `const cache = {}` hoac `const list = []` o top-level => ton tai suot vong doi process => MEDIUM. Accumulate data theo thoi gian => memory growth.
5. **Closure reference leak:** Callback/subscribe capture outer scope references => ngăn GC => MEDIUM. Can unsubscribe khi khong con can.
6. **Detached DOM:** Luu DOM element reference trong variable => element bi remove khoi DOM nhung reference van con => browser giam DOM tree khong GC duoc => MEDIUM.
7. **Domain:** `frontend` (checks 1, 3, 6), `general` (checks 2, 4, 5)
8. **Fixability:** `agent_fix` (frontend-developer / developer)

## ACT

Output schema `signal-v2`:
- Event listener leak: `title: "Event listener leak: N add vs M remove"`, `remediation.suggested_action: "Them removeEventListener trong cleanup phase"`
- Interval leak: `title: "Interval/Timer leak - thieu clear"`, `remediation.suggested_action: "Luu ID va clear trong cleanup"`
- useEffect cleanup: `title: "useEffect co subscriptions thieu cleanup"`, `remediation.suggested_action: "Them return cleanup function"`
- Module scope: `title: "Large persistent object trong module scope"`, `remediation.suggested_action: "Dung WeakMap/WeakSet hoac LRU cache"`
- Closure reference: `title: "Potential closure-captured reference"`, `remediation.suggested_action: "Unsubscribe callback khi khong con can"`
- Detached DOM: `title: "DOM reference co the gay detached tree leak"`, `remediation.suggested_action: "Set reference = null khi element bi remove"`

## VERIFY

1. Moi Signal co `dimension_id == "QD4"`
2. Moi signal co `evidence[].path` tro den file ton tai
3. Event listener signals co add_count vs remove_count trong description
4. Interval signals co evidence la code snippet
5. Severity trong [HIGH, MEDIUM] (khong critical/low cho probe nay)
6. Remediation present cho moi signal
7. Frontend checks chi emit khi IS_FRONTEND=true

## Severity Rules

| Pattern | Severity |
|---------|----------|
| addEventListener > removeEventListener (gap >= 1) | HIGH |
| useEffect co subscriptions thieu cleanup return | HIGH |
| setInterval/setTimeout thieu clearInterval/clearTimeout | MEDIUM |
| Large object/array trong module scope | MEDIUM |
| Subscription/callback closure potential leak | MEDIUM |
| Detached DOM reference (frontend) | MEDIUM |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Khong co source dir | Skip probe, note "no_source" |
| package.json khong ton tai | Assume general project (ko frontend-specific checks) |
| Frontend project nhung khong phai React/Vue/Svelte | Chi chay backend-safe checks (2, 4, 5), note "unknown_framework" |
| grep patterns khong tim thay leaks | Emit 0 signals (OK - khong co memory leak patterns phat hien) |
| Cache hit | Dung cached signals, khong chay lai grep |
| File encoding issue (binary/non-UTF8) | Skip file do, log warning, continue |
