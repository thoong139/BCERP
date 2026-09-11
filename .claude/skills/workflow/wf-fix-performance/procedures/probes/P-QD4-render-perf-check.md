# P-QD4-render-perf-check — Kiem tra hieu nang render frontend

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD4-render-perf-check |
| **Loai** | static+runtime (playwright) |
| **Profile** | quick (static-only), standard, deep, exhaustive |
| **Muc dich** | Phat hien (1) missing memoization (React.memo, useMemo, useCallback), (2) layout thrashing (batched DOM reads/writes), (3) excessive re-renders qua component size heuristic, (4) runtime FCP/TTI do Playwright. |
| **Cache** | skip (runtime probe) |
| **Migrates from** | Stage D (new) |

## PRE-GATE

```
IF khong co frontend source dir (src/, app/, components/, pages/, ui/) -> SKIP
IF profile=quick -> chi chay static checks, SKIP runtime playwright
IF runtime mode AND (no --base-url OR playwright not in PATH) -> SKIP runtime, note "playwright_unavailable"
IF khong tim thay React/Vue/Svelte config files (package.json > check dependencies) -> SKIP, note "not_a_frontend_project"
```

## SENSE

### B1: Delegate to inline static analysis (S5 v7.0)

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD4-performance/raw/P-QD4-render-perf-check.json"
mkdir -p "$(dirname "$RAW_OUT")"
SIGNALS_JSON='[]'

SOURCE="${SOURCE_DIR:-src/}"
# Fallback neu SOURCE_DIR khong ton tai
if [ ! -d "$SOURCE" ]; then
  for candidate in app components pages ui lib; do
    [ -d "$candidate" ] && { SOURCE="$candidate"; break; }
  done
fi

if [ ! -d "$SOURCE" ]; then
  # Inline fallback - emit empty signals
  cat > "$RAW_OUT" <<EOF
{"\$schema":"lane-signals-v1","lane":"wf-fix-performance","dimension":"QD4",
 "probe_id":"P-QD4-render-perf-check","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"no_frontend_source_dir"}
EOF
  exit 0
fi

# --- Static Check 1: Large component files (>300 lines) without React.memo ---
while IFS=: read -r file line match; do
  [ -z "$file" ] && continue
  if grep -qE '(export (default )?(function|class)|export const)' "$file" 2>/dev/null; then
    if ! grep -q 'React\.memo\|memo(' "$file" 2>/dev/null; then
      fp=$(echo -n "QD4|$file|$line|P-QD4-render-perf-check|missing_memo" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
      sig=$(jq -nc \
        --arg file "$file" --argjson line "$line" \
        --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
          "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-render-perf-check",
          probe_version: "v1.0", severity: "medium", fixability: "agent_fix", domain: "frontend",
          title: "Large component khong co React.memo",
          description: ("Component tai " + $file + " co >300 dong nhung khong co React.memo. Co the gay unnecessary re-renders khi parent re-render."),
          location: {file: $file, line: $line, column: null, selector: null, url: null},
          evidence: [{type: "code", path: $file, description: "Component >300 lines thieu React.memo"}],
          cdg_flags: [], fingerprint: $fp,
          remediation: {suggested_action: "Wrap component voi React.memo() hoac React.lazy()", suggested_agent: "frontend-developer", estimated_effort: "low"},
          detected_at: $now, detected_by: "wf-fix-performance/P-QD4-render-perf-check"
        }')
      SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
    fi
  fi
done < <(find "$SOURCE" -type f \( -name '*.tsx' -o -name '*.jsx' -o -name '*.vue' -o -name '*.svelte' \) \
          ! -path '*/node_modules/*' ! -path '*/__tests__/*' ! -name '*.test.*' ! -name '*.spec.*' \
          2>/dev/null | while read -r f; do
            lines=$(wc -l < "$f" 2>/dev/null || echo 0)
            [ "$lines" -gt 300 ] && echo "$f:1:file"
          done)

# --- Static Check 2: Missing useMemo/useCallback on expensive computations ---
while IFS=: read -r file line match; do
  [ -z "$file" ] && continue
  fp=$(echo -n "QD4|$file|$line|P-QD4-render-perf-check|missing_usememo" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
  sig=$(jq -nc \
    --arg file "$file" --argjson line "$line" --arg snippet "$(echo "$match" | head -c 80)" \
    --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-render-perf-check",
      probe_version: "v1.0", severity: "low", fixability: "agent_fix", domain: "frontend",
      title: "Co the thieu useMemo/useCallback",
      description: ("Expensive operation khong duoc memoize tai " + $file + ":" + ($line | tostring) + ". Co the gay re-tinh toan khong can thiet."),
      location: {file: $file, line: $line, column: null, selector: null, url: null},
      evidence: [{type: "code", path: $file, description: ($snippet)}],
      cdg_flags: [], fingerprint: $fp,
      remediation: {suggested_action: "Wrap expensive calculation trong useMemo() hoac callback trong useCallback()", suggested_agent: "frontend-developer", estimated_effort: "low"},
      detected_at: $now, detected_by: "wf-fix-performance/P-QD4-render-perf-check"
    }')
  SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
done < <(grep -rnE '\.(sort|filter|reduce|map)\(.*\)' "$SOURCE" \
          --include='*.tsx' --include='*.jsx' --include='*.ts' --include='*.js' \
          2>/dev/null | grep -vE '(node_modules|__tests__|\.test\.|\.spec\.)' || true)

# --- Static Check 3: Layout thrashing (forced reflow) ---
while IFS=: read -r file line match; do
  [ -z "$file" ] && continue
  fp=$(echo -n "QD4|$file|$line|P-QD4-render-perf-check|layout_thrashing" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
  sig=$(jq -nc \
    --arg file "$file" --argjson line "$line" --arg snippet "$(echo "$match" | head -c 80)" \
    --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-render-perf-check",
      probe_version: "v1.0", severity: "medium", fixability: "agent_fix", domain: "frontend",
      title: "Layout thrashing - DOM read after write",
      description: ("Phat hien forced reflow pattern tai " + $file + ":" + ($line | tostring) + ". Doc offsetWidth/scrollHeight sau khi ghi style co the gay layout thrashing."),
      location: {file: $file, line: $line, column: null, selector: null, url: null},
      evidence: [{type: "code", path: $file, description: ($snippet)}],
      cdg_flags: [], fingerprint: $fp,
      remediation: {suggested_action: "Batch DOM reads truoc khi DOM writes. Su dung requestAnimationFrame hoac FastDOM pattern.", suggested_agent: "frontend-developer", estimated_effort: "medium"},
      detected_at: $now, detected_by: "wf-fix-performance/P-QD4-render-perf-check"
    }')
  SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
done < <(grep -rnE '\.(offsetWidth|offsetHeight|scrollTop|scrollHeight|clientWidth|clientHeight|getBoundingClientRect|getComputedStyle)\s*\)?' "$SOURCE" \
          --include='*.tsx' --include='*.jsx' --include='*.ts' --include='*.js' \
          2>/dev/null | grep -vE '(node_modules|__tests__|\.test\.|\.spec\.)' \
          | head -20 || true)

# --- Static Check 4: Excessive useState in single file (>5 useState calls) ---
while IFS=: read -r file line match; do
  [ -z "$file" ] && continue
  count=$(grep -c 'useState' "$file" 2>/dev/null || echo 0)
  [ "$count" -le 5 ] && continue
  fp=$(echo -n "QD4|$file|1|P-QD4-render-perf-check|excessive_usestate" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
  sig=$(jq -nc \
    --arg file "$file" --argjson count "$count" \
    --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-render-perf-check",
      probe_version: "v1.0", severity: "low", fixability: "agent_fix", domain: "frontend",
      title: ("Excessive useState: " + ($count | tostring) + " calls in " + $file),
      description: ("File " + $file + " co " + ($count | tostring) + " useState calls. Nhieu state vars dong nghia voi nhieu re-renders. Can nhac gom nhom bang useReducer."),
      location: {file: $file, line: 1, column: null, selector: null, url: null},
      evidence: [{type: "code", path: $file, description: ($count | tostring) + " useState calls detected"}],
      cdg_flags: [], fingerprint: $fp,
      remediation: {suggested_action: "Gom nhom related state vars bang useReducer hoac xem xet state colocation", suggested_agent: "frontend-developer", estimated_effort: "medium"},
      detected_at: $now, detected_by: "wf-fix-performance/P-QD4-render-perf-check"
    }')
  SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
done < <(grep -rlc 'useState' "$SOURCE" \
          --include='*.tsx' --include='*.jsx' --include='*.ts' --include='*.js' \
          2>/dev/null | grep -vE '(node_modules|__tests__|\.test\.|\.spec\.)' | while read -r f; do
            echo "$f:1:useState"
          done)

# --- Runtime Check: Playwright FCP/TTI (chi khi profile != quick AND base-url AND playwright available) ---
if [ "${PROFILE:-standard}" != "quick" ] && [ -n "${BASE_URL:-}" ]; then
  if command -v npx &>/dev/null && npx playwright --version &>/dev/null 2>&1; then
    RUNTIME_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD4-performance/runtime"
    mkdir -p "$RUNTIME_DIR"
    # Launch shared browser session (playwright-session.js — xem _shared.md §0)
    pw_launch || { echo "E096: browser_unavailable" >&2; exit 1; }
    playwright_script=$(mktemp)
    cat > "$playwright_script" <<'PLAYWRIGHT_SCRIPT'
const { chromium } = require('playwright');
const fs = require('fs');
const baseUrl = process.env.BASE_URL || 'http://localhost:3000';
(async () => {
  const state = JSON.parse(fs.readFileSync(process.env.SESSION_FILE, 'utf-8'));
  const browser = await chromium.connectOverCDP(state.wsEndpoint);
  const context = browser.contexts()[0] || await browser.newContext();
  const page = await context.newPage();
  let fcp = 0, domContentLoaded = 0;
  page.on('console', msg => {
    const text = msg.text();
    if (text.startsWith('FCP:')) fcp = parseFloat(text.replace('FCP:', ''));
    if (text.startsWith('DCL:')) domContentLoaded = parseFloat(text.replace('DCL:', ''));
  });
  await page.addInitScript(() => {
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) {
        if (entry.entryType === 'paint' && entry.name === 'first-contentful-paint') {
          console.log('FCP:' + entry.startTime);
        }
      }
    }).observe({ type: 'paint', buffered: true });
    window.addEventListener('DOMContentLoaded', () => {
      console.log('DCL:' + performance.now());
    });
  });
  try {
    await page.goto(baseUrl, { waitUntil: 'networkidle', timeout: 30000 });
    await page.waitForTimeout(2000);
  } catch (e) { /* timeout is ok */ }
  console.log(JSON.stringify({ fcp, domContentLoaded }));
  // Browser stays alive — shared session managed by playwright-session.js
})().catch(e => { console.error(e); process.exit(1); });
PLAYWRIGHT_SCRIPT
    SESSION_FILE="$SESSION_DIR/playwright-session.json" BASE_URL="$BASE_URL" node "$playwright_script" > "$RUNTIME_DIR/fcp_tti.json" 2>/dev/null || true
    if [ -f "$RUNTIME_DIR/fcp_tti.json" ]; then
      fcp=$(jq -r '.fcp // 0' "$RUNTIME_DIR/fcp_tti.json" 2>/dev/null)
      if [ "$(echo "$fcp > 0" | bc -l 2>/dev/null)" = "1" ]; then
        severity="low"
        [ "$(echo "$fcp > 4000" | bc -l 2>/dev/null)" = "1" ] && severity="high"
        [ "$(echo "$fcp > 2500" | bc -l 2>/dev/null)" = "1" ] && severity="medium"
        fp=$(echo -n "QD4|runtime|fcp|P-QD4-render-perf-check|fcp_tti" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
        sig=$(jq -nc \
          --argjson fcp "$fcp" --arg severity "$severity" --arg fp "$fp" \
          --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          '{
            "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-render-perf-check",
            probe_version: "v1.0", severity: $severity, fixability: "agent_fix", domain: "frontend",
            title: ("FCP: " + ($fcp | tostring) + "ms - " + $severity),
            description: ("First Contentful Paint = " + ($fcp | tostring) + "ms. Target: FCP < 2500ms."),
            location: {file: "runtime", line: null, column: null, selector: null, url: null},
            evidence: [{type: "metric", path: "runtime", description: "FCP: " + ($fcp | tostring) + "ms"}],
            cdg_flags: [], fingerprint: $fp,
            remediation: {suggested_action: "Optimize render-blocking resources, reduce JS bundle, lazy-load non-critical components", suggested_agent: "frontend-developer", estimated_effort: "medium"},
            detected_at: $now, detected_by: "wf-fix-performance/P-QD4-render-perf-check"
          }')
        SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
      fi
    fi
    rm -f "$playwright_script"
  fi
fi

# Final output
jq -nc \
  --arg lane "wf-fix-performance" --arg probe "P-QD4-render-perf-check" --arg pver "v1.0" \
  --arg profile "${PROFILE:-standard}" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson signals "$SIGNALS_JSON" \
  '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD4", probe_id: $probe,
    probe_version: $pver, profile: $profile, generated_at: $now, signals: $signals}' \
  > "$RAW_OUT"
```

**Bash script handles:**
- Static: grep for missing React.memo (components >300 lines), missing useMemo/useCallback (sort/filter/reduce operations), layout thrashing (forced reflow via offsetWidth/height after style writes), excessive useState (>5 calls per file)
- Runtime (profile != quick + playwright available): launch headless Chromium, inject PerformanceObserver for FCP, measure DOMContentLoaded time
- Filter out test files, node_modules, spec files
- Cross-platform: GNU sha256sum / BSD shasum fallback tu dong

### B2: Threshold customization

Default thresholds:
- Component warn: >300 lines without React.memo -> severity=medium
- FCP: >2500ms -> medium, >4000ms -> high
- useState threshold: >5 calls per file -> low

Override qua env var (RENDER_WARN_LINES, FCP_WARN_MS, FCP_FAIL_MS) hoac CLI args.

## THINK

Inline bash logic:
1. **Missing memoization:** Component >300 lines ma khong co React.memo wrapper -> re-render ca subtree khi parent changes -> MEDIUM. Can optimize bang React.memo + useMemo.
2. **Expensive computations:** .sort/.filter/.reduce trong JSX body khong duoc memoize -> re-tinh toan moi render -> LOW (heuristic, can false positive).
3. **Layout thrashing:** DOM read (offsetWidth, scrollHeight) sau DOM write (style.x = Y) -> browser forced reflow -> MEDIUM. Can batch reads truoc writes.
4. **Excessive useState:** >5 useState per file -> nhieu re-render triggers -> LOW. Can gom nhom bang useReducer.
5. **Runtime FCP:** >4000ms -> HIGH (user abandonment risk). 2500-4000ms -> MEDIUM (can improve). <2500ms -> no signal.
6. **Domain:** `frontend`
7. **Fixability:** `agent_fix` (frontend-developer)

## ACT

Output schema `signal-v2`:
- Missing memo: `title: "Large component thieu React.memo"`, `remediation.suggested_action: "Wrap component voi React.memo()"`
- Missing useMemo: `title: "Co the thieu useMemo/useCallback"`, `remediation.suggested_action: "Wrap expensive calculation trong useMemo()"`
- Layout thrashing: `title: "Layout thrashing - DOM read after write"`, `remediation.suggested_action: "Batch DOM reads truoc DOM writes"`
- Excessive useState: `title: "Excessive useState: N calls"`, `remediation.suggested_action: "Gom nhom bang useReducer"`
- FCP runtime: `title: "FCP: Nms - severity"`, `remediation.suggested_action: "Optimize render-blocking resources"`

## VERIFY

1. Moi Signal co `dimension_id == "QD4"`
2. Static signals co `evidence[].path` tro den file ton tai
3. FCP runtime signal co metric value trong description
4. Severity trong [HIGH, MEDIUM, LOW] (khong critical/default cho probe nay)
5. Remediation present cho moi signal
6. Khong co duplicate fingerprints (cung file+type+line)

## Severity Rules

| Pattern | Severity |
|---------|----------|
| FCP > 4000ms (runtime) | HIGH |
| Layout thrashing pattern (DOM read after write) | MEDIUM |
| Component >300 lines thieu React.memo | MEDIUM |
| FCP 2500-4000ms (runtime) | MEDIUM |
| Missing useMemo/useCallback on expensive operations | LOW |
| Excessive useState (>5 calls per file) | LOW |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Khong tim thay frontend source dir | Skip probe, emit 0 signals, skip_reason="no_frontend_source_dir" |
| playwright khong available (runtime) | Chi chay static checks, note "runtime_skipped_playwright_unavailable" |
| --base-url khong duoc cung cap (runtime) | Chi chay static checks, note "runtime_skipped_no_base_url" |
| HTML components (.html files) thay vi React/Svelte/Vue | Skip probe, note "non_component_based_frontend" |
| Cross-platform stat/checksum fail | Inline fallback: BSD-compatible commands (wc, grep MacOS patterns) |
| Runtime FCP playwright timeout >30s | Note "runtime_timeout", chi dung static signals |
