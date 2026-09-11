#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-static-route.sh — Static probe: Multi-stack Route Config Parse (QD1)
#
# IMP-001 (Stage 3): Detect API routes/endpoints from multi-stack source code.
# Supported stacks: ASP.NET Core (.NET), Spring Boot (Java), Django/FastAPI (Python),
#                   Express/NestJS/Next.js (Node.js).
# Uses adapter framework: .claude/skills/workflow/_shared/adapters/
#
# OUTPUT: JSON on stdout per schema lane-signals-v1
#  SKILL.md routes output to $SESSION_DIR/lanes/QD1/raw/P-QD1-route-config-parse.json
#
# USAGE:
#   bash wf-fix-probe-static-route.sh \
#     --session-dir <path> --lane wf-fix-functional --probe P-QD1-route-config-parse \
#     [--profile quick|standard|deep|exhaustive] [--source-dir src/]
#
# EXIT CODES:
#   0 — success (may emit 0 signals if no routes found)
#   1 — fatal error
#
# Author: IMP-001 Stage 3


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wf-fix-common.sh"

# Defensive runtime cap (SB-01 v7.4.0 e2e fix): prevent hang on large codebases.
with_runtime_cap "$@"
_sha256() { sha256sum 2>/dev/null || shasum -a 256; }

SESSION_DIR=""
LANE="wf-fix-functional"
PROBE_ID="P-QD1-route-config-parse"
PROBE_VERSION="v1.0"
PROFILE="standard"
SOURCE_DIR="src/"

while [ $# -gt 0 ]; do
  case "$1" in
    --session-dir) SESSION_DIR="$2"; shift 2 ;;
    --lane)        LANE="$2";        shift 2 ;;
    --probe)       PROBE_ID="$2";    shift 2 ;;
    --profile)     PROFILE="$2";     shift 2 ;;
    --source-dir)  SOURCE_DIR="$2";  shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg $1" >&2; exit 1 ;;
  esac
done

# ============================================================
# Locate adapter framework
# ============================================================
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || { cd "$SCRIPT_DIR/../.." && pwd; })"
ADAPTER_DIR="$REPO_ROOT/.claude/skills/workflow/_shared/adapters"

if [ ! -d "$ADAPTER_DIR" ]; then
  echo "ERROR: adapter framework not found at $ADAPTER_DIR (IMP-000 required)" >&2
  exit 1
fi

# ============================================================
# Detect which stacks are present
# ============================================================
DETECTED_STACKS=()
for stack_file in "$ADAPTER_DIR/stack/"*.sh; do
  stack_name=$(basename "$stack_file" .sh)
  # Source adapter's detect() in a subshell to avoid contaminating env
  if (source "$stack_file" && detect "$SOURCE_DIR") 2>/dev/null; then
    DETECTED_STACKS+=("$stack_name")
  fi
done

# ============================================================
# Collect raw route hits from all detected stacks
# ============================================================
MCV3_TMP=""
if [ -n "$SESSION_DIR" ]; then
  MCV3_TMP="$SESSION_DIR/.probe-route-tmp"
  mkdir -p "$MCV3_TMP" 2>/dev/null || true
else
  MCV3_TMP="$(mktemp -d -t probe-route-XXXXXX)"
fi
ROUTES_TMP="$MCV3_TMP/routes.$$.jsonl"
: > "$ROUTES_TMP"
trap 'rm -rf "$MCV3_TMP"' EXIT

for stack_name in "${DETECTED_STACKS[@]}"; do
  stack_file="$ADAPTER_DIR/stack/${stack_name}.sh"
  # Collect route hits (each line = JSON object from scan())
  while IFS= read -r route_json; do
    [[ -z "$route_json" ]] && continue
    # Skip stub output lines (use if-form to avoid set -e false-positive on grep exit 1)
    if echo "$route_json" | grep -q '^\[stub\]'; then continue; fi
    # Validate it's JSON
    if echo "$route_json" | jq -e '.' >/dev/null 2>&1; then
      printf '%s\n' "$route_json"
    fi
  done < <((set +euo pipefail; source "$stack_file" && scan "$SOURCE_DIR") 2>/dev/null) >> "$ROUTES_TMP" || true
done

# ============================================================
# Build signals from route hits
# ============================================================
SIGNALS_TMP="$MCV3_TMP/signals.$$.jsonl"
: > "$SIGNALS_TMP"

while IFS= read -r route_json; do
  [[ -z "$route_json" ]] && continue
  file=$(echo "$route_json" | jq -r '.file // "unknown"')
  line=$(echo "$route_json" | jq -r '.line // 0')
  method=$(echo "$route_json" | jq -r '.method // "ANY"')
  route=$(echo "$route_json" | jq -r '.route // "[inferred]"')
  framework=$(echo "$route_json" | jq -r '.framework // "unknown"')

  fp=$(echo -n "QD1|$file|$line|$PROBE_ID|route_detected|$method:$route" | _sha256 | awk '{print "sha256:"$1}')

  jq -nc \
    --arg file "$file" \
    --argjson line "$line" \
    --arg method "$method" \
    --arg route "$route" \
    --arg framework "$framework" \
    --arg probe "$PROBE_ID" \
    --arg pver "$PROBE_VERSION" \
    --arg fp "$fp" \
    --arg now "$(iso_now)" \
    --arg detector "$LANE/$PROBE_ID" \
    '{
      "$schema": "signal-v2",
      dimension_id: "QD1",
      probe_id: $probe,
      probe_version: $pver,
      severity: "info",
      fixability: "none",
      domain: "routing",
      title: ("Route detected: " + $method + " " + $route + " (" + $framework + ")"),
      description: ("API route " + $method + " " + $route + " detected in " + $file + " (framework: " + $framework + "). Verify route is registered in req-registry.json."),
      location: {file: $file, line: $line, column: null, selector: null, url: null},
      evidence: [{type: "code", path: $file, description: ("Route definition found at line " + ($line | tostring))}],
      cdg_flags: [],
      fingerprint: $fp,
      registry_refs: {},
      detected_at: $now,
      detected_by: $detector
    }' >> "$SIGNALS_TMP"
done < "$ROUTES_TMP"

# ============================================================
# If no stacks detected, emit SPEC-ONLY-PROBE-SKIP info signal
# ============================================================
if [ ${#DETECTED_STACKS[@]} -eq 0 ]; then
  jq -nc \
    --arg probe "$PROBE_ID" \
    --arg pver "$PROBE_VERSION" \
    --arg now "$(iso_now)" \
    --arg detector "$LANE/$PROBE_ID" \
    '{
      "$schema": "signal-v2",
      dimension_id: "QD1",
      probe_id: $probe,
      probe_version: $pver,
      severity: "info",
      fixability: "none",
      domain: "routing",
      title: "Route probe: no stack detected in source directory",
      description: "No supported stack (Node.js/Java/.NET/Python) detected in SOURCE_DIR. Route config parse skipped.",
      location: {file: "N/A", line: null, column: null, selector: null, url: null},
      evidence: [{type: "spec", path: "N/A", description: "SPEC-ONLY-PROBE-SKIP: no stack manifest found"}],
      cdg_flags: [],
      fingerprint: "spec-only-probe-skip-route",
      registry_refs: {},
      detected_at: $now,
      detected_by: $detector
    }' >> "$SIGNALS_TMP"
fi

# ============================================================
# Output JSON wrapper (schema lane-signals-v1)
# ============================================================
jq -n \
  --arg lane "$LANE" \
  --arg dim "QD1" \
  --arg probe "$PROBE_ID" \
  --arg pver "$PROBE_VERSION" \
  --arg profile "$PROFILE" \
  --arg now "$(iso_now)" \
  --slurpfile signals "$SIGNALS_TMP" \
  '{
    "$schema": "lane-signals-v1",
    lane: $lane,
    dimension: $dim,
    probe_id: $probe,
    probe_version: $pver,
    profile: $profile,
    generated_at: $now,
    signals: $signals
  }'

exit 0
