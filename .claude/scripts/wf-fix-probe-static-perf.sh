#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-static-perf.sh — Static probe: Performance Audit (QD4)
#
# Combined static performance probe:
#   1. Bundle size: kiem tra build artifacts (dist/, build/, .next/) vs threshold
#   1b. Webpack-stats.json / vite bundle report: per-asset + per-module analysis (IMP-014)
#   2. N+1 query patterns: grep .findOne / await loop / for-loop voi DB call
#   3. Large bundled deps (heuristic): node_modules sub-package size
#
# OUTPUT: JSON tren stdout theo schema lane-signals-v1
# Cache policy: allowed (static analysis)
#
# USAGE:
#   bash wf-fix-probe-static-perf.sh \
#     --session-dir <path> --lane wf-fix-performance \
#     --probe P-QD4-bundle-size-audit \
#     [--profile quick|standard|deep|exhaustive] \
#     [--source-dir src/] [--build-dir dist/] \
#     [--bundle-stats webpack-stats.json] \
#     [--bundle-warn-kb 500] [--bundle-fail-kb 1000] \
#     [--threshold-overrides '{"bundle_warn_kb":300}']
#
# IMP-004: Thresholds load từ _shared/profiles.json theo profile;
#          --bundle-warn-kb/--bundle-fail-kb vẫn hoạt động (CLI wins over profile).
#          --threshold-overrides JSON bulk-override (wins over profile, loses to explicit CLI).
# IMP-014: --bundle-stats parses webpack-stats.json / vite rollup JSON for per-module sizes.
#          Auto-detected at: webpack-stats.json, dist/stats.json, build/stats.json
#
# EXIT CODES: 0 success, 1 error
#
# Author: S5 wf-fix-bugs v7.0 / IMP-004; IMP-014 bundle-stats parsing


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./wf-fix-common.sh
source "$SCRIPT_DIR/wf-fix-common.sh"

# Defensive runtime cap (SB-01 v7.4.0 e2e fix): prevent hang on large codebases.
with_runtime_cap "$@"
# Cross-platform sha256 (GNU sha256sum / macOS shasum)
_sha256() { sha256sum 2>/dev/null || shasum -a 256; }

SESSION_DIR=""
LANE="wf-fix-performance"
PROBE_ID="P-QD4-bundle-size-audit"
PROBE_VERSION="v1.1"
PROFILE="standard"
SOURCE_DIR="src/"
BUILD_DIR=""
# sentinel: -1 means "not set via CLI, use profile/override"
BUNDLE_WARN_KB_CLI=-1
BUNDLE_FAIL_KB_CLI=-1
THRESHOLD_OVERRIDES="{}"
BUNDLE_STATS_ARG=""   # IMP-014: explicit path override for bundle stats JSON

while [ $# -gt 0 ]; do
  case "$1" in
    --session-dir) SESSION_DIR="$2"; shift 2 ;;
    --lane) LANE="$2"; shift 2 ;;
    --probe) PROBE_ID="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --source-dir) SOURCE_DIR="$2"; shift 2 ;;
    --build-dir) BUILD_DIR="$2"; shift 2 ;;
    --bundle-stats) BUNDLE_STATS_ARG="$2"; shift 2 ;;
    --bundle-warn-kb) BUNDLE_WARN_KB_CLI="$2"; shift 2 ;;
    --bundle-fail-kb) BUNDLE_FAIL_KB_CLI="$2"; shift 2 ;;
    --threshold-overrides) THRESHOLD_OVERRIDES="$2"; shift 2 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg $1" >&2; exit 1 ;;
  esac
done

# ============================================================
# IMP-004: Load thresholds from profiles.json
# Priority: explicit CLI > --threshold-overrides JSON > profiles.json
# ============================================================
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || { cd "$SCRIPT_DIR/../.." && pwd; })"
PROFILES_JSON="$REPO_ROOT/.claude/skills/workflow/_shared/profiles/profiles.json"

_profile_threshold() {
  local key="$1" default="$2"
  if [ -f "$PROFILES_JSON" ]; then
    local val
    val=$(jq -r --arg p "$PROFILE" --arg k "$key" \
      '.profiles[$p].thresholds[$k] // empty' "$PROFILES_JSON" 2>/dev/null || true)
    [ -n "$val" ] && [ "$val" != "null" ] && echo "$val" && return
  fi
  echo "$default"
}

_override_threshold() {
  local key="$1" default="$2"
  local val
  val=$(jq -r --arg k "$key" '.[$k] // empty' <<< "$THRESHOLD_OVERRIDES" 2>/dev/null || true)
  [ -n "$val" ] && [ "$val" != "null" ] && echo "$val" && return
  echo "$default"
}

# Load from profile, then apply --threshold-overrides, then apply explicit CLI
BUNDLE_WARN_KB=$(_profile_threshold "bundle_warn_kb" 500)
BUNDLE_WARN_KB=$(_override_threshold "bundle_warn_kb" "$BUNDLE_WARN_KB")
[ "$BUNDLE_WARN_KB_CLI" -ge 0 ] 2>/dev/null && BUNDLE_WARN_KB="$BUNDLE_WARN_KB_CLI"

BUNDLE_FAIL_KB=$(_profile_threshold "bundle_fail_kb" 1000)
BUNDLE_FAIL_KB=$(_override_threshold "bundle_fail_kb" "$BUNDLE_FAIL_KB")
[ "$BUNDLE_FAIL_KB_CLI" -ge 0 ] 2>/dev/null && BUNDLE_FAIL_KB="$BUNDLE_FAIL_KB_CLI"

# Auto-detect build dir neu chua chi dinh
if [ -z "$BUILD_DIR" ]; then
  for candidate in dist build .next out; do
    if [ -d "$candidate" ]; then
      BUILD_DIR="$candidate"
      break
    fi
  done
fi

# Fix #7 v8.0: JSONL temp file accumulation (tranh "Argument list too long" + O(N²) jq parsing)
MCV3_TMP="$SESSION_DIR/.probe-perf-tmp"
mkdir -p "$MCV3_TMP" 2>/dev/null || { echo "ERROR: cannot create tmp dir $MCV3_TMP" >&2; exit 1; }
SIGNALS_TMP="$MCV3_TMP/signals.$$.jsonl"
trap 'rm -rf "$MCV3_TMP"' EXIT
: > "$SIGNALS_TMP"
SIG_NUM=0

# ── Probe dispatch (IMP-025) ──────────────────────────────────────────
RUN_BUNDLE=0   # bundle size + webpack-stats (P-QD4-bundle-size-audit)
RUN_N_PLUS_1=0 # N+1 query patterns (P-QD4-db-query-analysis)

case "$PROBE_ID" in
  P-QD4-bundle-size-audit)
    RUN_BUNDLE=1 ;;
  P-QD4-db-query-analysis)
    RUN_N_PLUS_1=1 ;;
  P-QD4-core-web-vitals)
    # Handled by wf-fix-probe-playwright-cwv.sh (IMP-018)
    jq -nc --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
      --arg profile "$PROFILE" --arg now "$(iso_now)" \
      '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD4", probe_id: $probe,
        probe_version: $pver, profile: $profile, generated_at: $now,
        signals: [], probe_status: "SPEC-ONLY-PROBE-SKIP",
        skip_reason: "delegated_to_wf-fix-probe-playwright-cwv.sh"}'
    exit 0 ;;
  P-QD4-render-perf-check|P-QD4-api-latency-probe|P-QD4-memory-leak-scan)
    # Runtime probes — static bash cannot cover these fully
    jq -nc --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
      --arg profile "$PROFILE" --arg now "$(iso_now)" \
      '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD4", probe_id: $probe,
        probe_version: $pver, profile: $profile, generated_at: $now,
        signals: [], probe_status: "SPEC-ONLY-PROBE-SKIP",
        skip_reason: "requires_runtime_environment"}'
    exit 0 ;;
  *)
    echo "ERROR: unknown PROBE_ID '$PROBE_ID' for QD4 — valid: P-QD4-bundle-size-audit, P-QD4-db-query-analysis, P-QD4-core-web-vitals, P-QD4-render-perf-check, P-QD4-api-latency-probe, P-QD4-memory-leak-scan" >&2
    exit 1 ;;
esac

# ============================================================
# Part 1: Bundle size audit (build artifacts)
# ============================================================
if [ "$RUN_BUNDLE" -eq 1 ] && [ -n "$BUILD_DIR" ] && [ -d "$BUILD_DIR" ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    [ ! -f "$file" ] && continue

    # Size in KB (cross-platform)
    size_bytes=$(stat -c %s "$file" 2>/dev/null || stat -f %z "$file" 2>/dev/null || echo 0)
    size_kb=$(( size_bytes / 1024 ))

    severity=""
    if [ "$size_kb" -gt "$BUNDLE_FAIL_KB" ]; then
      severity="high"
    elif [ "$size_kb" -gt "$BUNDLE_WARN_KB" ]; then
      severity="medium"
    fi

    if [ -n "$severity" ]; then
      fp=$(echo -n "QD4|$file|0|$PROBE_ID|bundle_size" | _sha256 | awk '{print "sha256:"$1}')
      sig=$(jq -nc \
        --arg file "$file" --argjson size "$size_kb" \
        --argjson warn "$BUNDLE_WARN_KB" --argjson fail "$BUNDLE_FAIL_KB" \
        --arg severity "$severity" \
        --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
        --arg fp "$fp" --arg now "$(iso_now)" --arg detector "$LANE/$PROBE_ID" \
        '{
          "$schema": "signal-v2", dimension_id: "QD4", probe_id: $probe, probe_version: $pver,
          severity: $severity, fixability: "agent_fix", domain: "frontend",
          title: ("Large bundle: " + ($size | tostring) + "KB " + $file),
          description: ("Bundle " + $file + " (" + ($size | tostring) + "KB) exceeds threshold (warn=" + ($warn | tostring) + "KB, fail=" + ($fail | tostring) + "KB). Consider code-splitting, tree-shaking, dynamic import."),
          location: {file: $file, line: null, column: null, selector: null, url: null},
          evidence: [{type: "stdout", path: $file, description: ("File size: " + ($size | tostring) + " KB")}],
          cdg_flags: [], fingerprint: $fp,
          remediation: {suggested_action: "Code-split via dynamic import or analyze with webpack-bundle-analyzer", suggested_agent: "frontend-developer", estimated_effort: "medium"},
          detected_at: $now, detected_by: $detector
        }')
      SIG_NUM=$((SIG_NUM + 1))
      printf '%s\n' "$sig" >> "$SIGNALS_TMP"
    fi
  done < <(find "$BUILD_DIR" -type f \( -name '*.js' -o -name '*.css' -o -name '*.mjs' \) 2>/dev/null \
            | grep -vE '\.map$' || true)
fi

# ============================================================
# Part 1b: Parse webpack-stats.json / vite bundle report (IMP-014)
# Provides per-module granularity beyond binary artifact size checks.
# Detects: large assets, heavy vendor chunks, top-N expensive deps.
# ============================================================
if [ "$RUN_BUNDLE" -eq 1 ]; then
BUNDLE_STATS_FILE="${BUNDLE_STATS_ARG:-}"

# Auto-detect if no explicit path given
if [ -z "$BUNDLE_STATS_FILE" ]; then
  for _candidate in webpack-stats.json dist/stats.json build/stats.json; do
    if [ -f "$_candidate" ]; then
      BUNDLE_STATS_FILE="$_candidate"
      break
    fi
  done
fi

if [ -n "$BUNDLE_STATS_FILE" ] && [ -f "$BUNDLE_STATS_FILE" ]; then
  # ---- Webpack-stats: .assets[] ----
  if jq -e '.assets | length > 0' "$BUNDLE_STATS_FILE" >/dev/null 2>&1; then
    while IFS= read -r asset; do
      asset_name=$(echo "$asset" | jq -r '.name // ""')
      asset_bytes=$(echo "$asset" | jq -r '.size // 0')
      [ -z "$asset_name" ] && continue
      # Skip source-maps
      echo "$asset_name" | grep -qE '\.map$' && continue

      asset_kb=$(( asset_bytes / 1024 ))
      severity=""
      [ "$asset_kb" -gt "$BUNDLE_FAIL_KB" ] && severity="high"
      [ -z "$severity" ] && [ "$asset_kb" -gt "$BUNDLE_WARN_KB" ] && severity="medium"
      [ -z "$severity" ] && continue

      fp=$(echo -n "QD4|${BUNDLE_STATS_FILE}|${asset_name}|$PROBE_ID|bundle_stats_asset" | _sha256 | awk '{print "sha256:"$1}')
      sig=$(jq -nc \
        --arg asset  "$asset_name" \
        --argjson kb  "$asset_kb" \
        --argjson warn "$BUNDLE_WARN_KB" \
        --argjson fail "$BUNDLE_FAIL_KB" \
        --arg sev    "$severity" \
        --arg stats  "$BUNDLE_STATS_FILE" \
        --arg probe  "$PROBE_ID" --arg pver "$PROBE_VERSION" \
        --arg fp     "$fp" --arg now "$(iso_now)" --arg detector "$LANE/$PROBE_ID" \
        '{
          "$schema": "signal-v2", dimension_id: "QD4", probe_id: $probe, probe_version: $pver,
          severity: $sev, fixability: "agent_fix", domain: "frontend",
          title: ("Large asset in bundle report: " + $asset + " (" + ($kb|tostring) + "KB)"),
          description: ("webpack-stats asset " + $asset + " is " + ($kb|tostring) + "KB (warn=" + ($warn|tostring) + "KB, fail=" + ($fail|tostring) + "KB). Apply code-splitting, lazy-load, or tree-shake."),
          location: {file: $stats, line: null, column: null, selector: null, url: null},
          evidence: [{type: "stdout", path: $stats, description: ("Asset " + $asset + ": " + ($kb|tostring) + "KB"), stats_source: "webpack-stats"}],
          cdg_flags: [], fingerprint: $fp,
          remediation: {suggested_action: "Run webpack-bundle-analyzer; apply dynamic import or route-level code-splitting", suggested_agent: "frontend-developer", estimated_effort: "medium"},
          detected_at: $now, detected_by: $detector
        }')
      SIG_NUM=$((SIG_NUM + 1))
      printf '%s\n' "$sig" >> "$SIGNALS_TMP"
    done < <(jq -c '.assets[]?' "$BUNDLE_STATS_FILE" 2>/dev/null || true)
  fi

  # ---- Webpack-stats: .modules[] — top heavy deps (> half of warn threshold) ----
  MODULE_THRESHOLD_KB=$(( BUNDLE_WARN_KB / 2 ))
  if jq -e '.modules | length > 0' "$BUNDLE_STATS_FILE" >/dev/null 2>&1; then
    while IFS= read -r mod; do
      mod_name=$(echo "$mod" | jq -r '.name // ""')
      mod_bytes=$(echo "$mod" | jq -r '.size // 0')
      [ -z "$mod_name" ] && continue
      # Only flag node_modules entries (dep analysis)
      echo "$mod_name" | grep -q 'node_modules' || continue

      mod_kb=$(( mod_bytes / 1024 ))
      [ "$mod_kb" -le "$MODULE_THRESHOLD_KB" ] && continue

      fp=$(echo -n "QD4|${BUNDLE_STATS_FILE}|${mod_name}|$PROBE_ID|bundle_stats_module" | _sha256 | awk '{print "sha256:"$1}')
      sig=$(jq -nc \
        --arg mod    "$mod_name" \
        --argjson kb  "$mod_kb" \
        --argjson thr "$MODULE_THRESHOLD_KB" \
        --arg stats  "$BUNDLE_STATS_FILE" \
        --arg probe  "$PROBE_ID" --arg pver "$PROBE_VERSION" \
        --arg fp     "$fp" --arg now "$(iso_now)" --arg detector "$LANE/$PROBE_ID" \
        '{
          "$schema": "signal-v2", dimension_id: "QD4", probe_id: $probe, probe_version: $pver,
          severity: "medium", fixability: "agent_fix", domain: "frontend",
          title: ("Heavy dependency in bundle: " + $mod + " (" + ($kb|tostring) + "KB)"),
          description: ("Module " + $mod + " contributes " + ($kb|tostring) + "KB to the bundle (threshold=" + ($thr|tostring) + "KB). Consider lighter alternative or code-splitting."),
          location: {file: $stats, line: null, column: null, selector: null, url: null},
          evidence: [{type: "stdout", path: $stats, description: ("Module size: " + ($kb|tostring) + "KB"), stats_source: "webpack-stats"}],
          cdg_flags: [], fingerprint: $fp,
          remediation: {suggested_action: "Replace with lightweight alternative or use tree-shaking imports", suggested_agent: "frontend-developer", estimated_effort: "medium"},
          detected_at: $now, detected_by: $detector
        }')
      SIG_NUM=$((SIG_NUM + 1))
      printf '%s\n' "$sig" >> "$SIGNALS_TMP"
    done < <(jq -c '.modules[]?' "$BUNDLE_STATS_FILE" 2>/dev/null || true)
  fi
fi
fi # RUN_BUNDLE

# ============================================================
# Part 2: N+1 query patterns trong source
# ============================================================
if [ "$RUN_N_PLUS_1" -eq 1 ] && [ -d "$SOURCE_DIR" ]; then
  # Pattern 1: await ... .findOne|.find inside for/forEach/map (N+1 risk)
  N_PLUS_1_PATTERNS=(
    "await.*\\.find(One|All|ById|First)?\\("
    "await.*\\.query\\("
    "await.*\\.fetch\\("
    "await.*\\.get\\("
  )

  # Fix #7 v8.0: Combined regex single grep + --exclude-dir + cap
  COMBINED_N1_REGEX=""
  for entry in "${N_PLUS_1_PATTERNS[@]}"; do
    if [ -z "$COMBINED_N1_REGEX" ]; then COMBINED_N1_REGEX="$entry"
    else COMBINED_N1_REGEX="$COMBINED_N1_REGEX|$entry"; fi
  done

  N1_TMP=$(mktemp)
  grep -rEn -e "$COMBINED_N1_REGEX" "$SOURCE_DIR" \
    --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build --exclude-dir=.next --exclude-dir=coverage \
    2>/dev/null > "$N1_TMP" || true

  MAX_N1_MATCHES=200
  n1_match_count=0
  while IFS=: read -r file line match; do
    [ -z "$file" ] && continue
    [ -z "$line" ] && continue
    n1_match_count=$((n1_match_count + 1))
    [ "$n1_match_count" -gt "$MAX_N1_MATCHES" ] && break

    # Filter out test files
    if echo "$file" | grep -qE '(__tests__|test/|tests/|\.test\.|\.spec\.|node_modules)'; then
      continue
    fi

    # Heuristic: check if surrounded by for/forEach (look 5 lines before)
    start_line=$((line > 5 ? line - 5 : 1))
    context=$(sed -n "${start_line},${line}p" "$file" 2>/dev/null || echo "")

    if echo "$context" | grep -qE '(for[[:space:]]*\(|\.forEach|\.map\(|\.reduce\()'; then
      fp=$(echo -n "QD4|$file|$line|$PROBE_ID|n_plus_1" | _sha256 | awk '{print "sha256:"$1}')
      sig=$(jq -nc \
        --arg file "$file" --argjson line "$line" \
        --arg snippet "$(echo "$match" | head -c 100)" \
        --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
        --arg fp "$fp" --arg now "$(iso_now)" --arg detector "$LANE/$PROBE_ID" \
        '{
          "$schema": "signal-v2", dimension_id: "QD4", probe_id: $probe, probe_version: $pver,
          severity: "high", fixability: "agent_fix", domain: "backend",
          title: "Possible N+1 query pattern",
          description: ("Phat hien await DB call ben trong loop tai " + $file + ":" + ($line | tostring) + ". Consider batch fetch / eager loading / dataloader."),
          location: {file: $file, line: $line, column: null, selector: null, url: null},
          evidence: [{type: "code", path: $file, description: ("Snippet: " + $snippet)}],
          cdg_flags: [], fingerprint: $fp,
          remediation: {suggested_action: "Refactor to batch fetch or use dataloader pattern", suggested_agent: "developer", estimated_effort: "medium"},
          detected_at: $now, detected_by: $detector
        }')
      SIG_NUM=$((SIG_NUM + 1))
      printf '%s\n' "$sig" >> "$SIGNALS_TMP"
    fi
  done < "$N1_TMP"
  rm -f "$N1_TMP"
fi

# Output (dung --slurpfile tranh "Argument list too long")
jq -nc \
  --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
  --arg profile "$PROFILE" --arg now "$(iso_now)" \
  --argjson signal_count "$SIG_NUM" \
  --slurpfile signals "$SIGNALS_TMP" \
  '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD4", probe_id: $probe,
    probe_version: $pver, profile: $profile, generated_at: $now, signals: $signals}'

exit 0
