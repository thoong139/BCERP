#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-static-depvuln.sh — Static probe: Multi-PM Dependency Vulnerability Scan (QD3)
#
# IMP-003 (Stage 3): Detect vulnerable dependencies across multiple package managers.
# Supported: npm/yarn/pnpm, pip, nuget (.NET), maven/gradle (Java), go modules.
# Uses adapter framework: .claude/skills/workflow/_shared/adapters/package-manager/
#
# If audit tool not installed → emits SPEC-ONLY-PROBE-SKIP signal (graceful degradation).
#
# OUTPUT: JSON on stdout per schema lane-signals-v1
#  SKILL.md routes output to $SESSION_DIR/lanes/QD3/raw/P-QD3-dependency-vuln-scan.json
#
# USAGE:
#   bash wf-fix-probe-static-depvuln.sh \
#     --session-dir <path> --lane wf-fix-security --probe P-QD3-dependency-vuln-scan \
#     [--profile quick|standard|deep|exhaustive] [--source-dir .]
#
# EXIT CODES:
#   0 — success (may emit 0 non-skip signals if no vulns found)
#   1 — fatal error
#
# Author: IMP-003 Stage 3


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wf-fix-common.sh"

# Defensive runtime cap (SB-01 v7.4.0 e2e fix): prevent hang on large codebases.
with_runtime_cap "$@"
_sha256() { sha256sum 2>/dev/null || shasum -a 256; }

SESSION_DIR=""
LANE="wf-fix-security"
PROBE_ID="P-QD3-dependency-vuln-scan"
PROBE_VERSION="v1.0"
PROFILE="standard"
SOURCE_DIR="."

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

if [ ! -d "$ADAPTER_DIR/package-manager" ]; then
  echo "ERROR: package-manager adapters not found at $ADAPTER_DIR (IMP-000 required)" >&2
  exit 1
fi

# ============================================================
# Detect which PMs are present
# ============================================================
DETECTED_PMS=()
for pm_file in "$ADAPTER_DIR/package-manager/"*.sh; do
  pm_name=$(basename "$pm_file" .sh)
  if (set +euo pipefail; source "$pm_file" && detect "$SOURCE_DIR") 2>/dev/null; then
    DETECTED_PMS+=("$pm_name")
  fi
done

# ============================================================
# Temporary files
# ============================================================
MCV3_TMP=""
if [ -n "$SESSION_DIR" ]; then
  MCV3_TMP="$SESSION_DIR/.probe-depvuln-tmp"
  mkdir -p "$MCV3_TMP" 2>/dev/null || true
else
  MCV3_TMP="$(mktemp -d -t probe-depvuln-XXXXXX)"
fi
SIGNALS_TMP="$MCV3_TMP/signals.$$.jsonl"
: > "$SIGNALS_TMP"
trap 'rm -rf "$MCV3_TMP"' EXIT

# ============================================================
# Scan each detected PM for vulnerabilities
# ============================================================
for pm_name in "${DETECTED_PMS[@]}"; do
  pm_file="$ADAPTER_DIR/package-manager/${pm_name}.sh"
  VULN_TMP="$MCV3_TMP/vuln-${pm_name}.$$.jsonl"
  : > "$VULN_TMP"

  while IFS= read -r vuln_json; do
    [[ -z "$vuln_json" ]] && continue

    # Check for SPEC-ONLY-PROBE-SKIP lines
    if echo "$vuln_json" | grep -q '^\[stub\] SPEC-ONLY-PROBE-SKIP'; then
      # Extract pm and tool from skip message
      skip_pm=$(echo "$vuln_json" | grep -oE 'pm=[a-zA-Z0-9_-]+' | cut -d= -f2) || true
      skip_tool=$(echo "$vuln_json" | grep -oE 'tool=[^ ]+' | cut -d= -f2) || true
      [[ -z "$skip_pm" ]] && skip_pm="$pm_name"
      [[ -z "$skip_tool" ]] && skip_tool="unknown"

      fp=$(echo -n "QD3|$pm_name|$SOURCE_DIR|$PROBE_ID|skip|$skip_tool" | _sha256 | awk '{print "sha256:"$1}')
      jq -nc \
        --arg pm "$skip_pm" \
        --arg tool "$skip_tool" \
        --arg probe "$PROBE_ID" \
        --arg pver "$PROBE_VERSION" \
        --arg fp "$fp" \
        --arg now "$(iso_now)" \
        --arg detector "$LANE/$PROBE_ID" \
        '{
          "$schema": "signal-v2",
          dimension_id: "QD3",
          probe_id: $probe, probe_version: $pver,
          severity: "info", fixability: "none", domain: "dependency",
          title: ("Dep vuln scan skipped: " + $pm + " (" + $tool + " not installed)"),
          description: ("Package manager " + $pm + " detected but audit tool " + $tool + " is not installed. Install it to enable vulnerability scanning. SPEC-ONLY-PROBE-SKIP."),
          location: {file: "N/A", line: null, column: null, selector: null, url: null},
          evidence: [{type: "spec", path: "N/A", description: ("SPEC-ONLY-PROBE-SKIP: " + $tool + " not installed")}],
          cdg_flags: [], fingerprint: $fp, registry_refs: {},
          detected_at: $now, detected_by: $detector
        }' >> "$SIGNALS_TMP"
      continue
    fi

    # Validate JSON vulnerability entry
    if ! echo "$vuln_json" | jq -e '.' >/dev/null 2>&1; then continue; fi

    # Build signal from vulnerability JSON
    vuln_pkg=$(echo "$vuln_json" | jq -r '.package // "unknown"')
    vuln_ver=$(echo "$vuln_json" | jq -r '.version // "unknown"')
    vuln_sev=$(echo "$vuln_json" | jq -r '.severity // "unknown"')
    vuln_cve=$(echo "$vuln_json" | jq -r '.cve // "N/A"')
    vuln_desc=$(echo "$vuln_json" | jq -r '.description // "Vulnerable dependency"')
    vuln_pm=$(echo "$vuln_json" | jq -r '.pm // "'"$pm_name"'"')

    # Map severity to signal severity
    case "$vuln_sev" in
      critical)       sig_sev="critical" ;;
      high)           sig_sev="high" ;;
      medium|moderate) sig_sev="medium" ;;
      *)              sig_sev="low" ;;
    esac

    fp=$(echo -n "QD3|$vuln_pm|$vuln_pkg|$vuln_ver|$PROBE_ID|$vuln_cve" | _sha256 | awk '{print "sha256:"$1}')

    jq -nc \
      --arg pm "$vuln_pm" \
      --arg pkg "$vuln_pkg" \
      --arg ver "$vuln_ver" \
      --arg sev "$sig_sev" \
      --arg cve "$vuln_cve" \
      --arg desc "$vuln_desc" \
      --arg probe "$PROBE_ID" \
      --arg pver "$PROBE_VERSION" \
      --arg fp "$fp" \
      --arg now "$(iso_now)" \
      --arg detector "$LANE/$PROBE_ID" \
      '{
        "$schema": "signal-v2",
        dimension_id: "QD3",
        probe_id: $probe, probe_version: $pver,
        severity: $sev, fixability: "code-change", domain: "dependency",
        title: ("Vulnerable dependency: " + $pkg + "@" + $ver + " (" + $pm + ")"),
        description: ($cve + ": " + $desc + " — Package: " + $pkg + " " + $ver + " via " + $pm + ". Update to a patched version."),
        location: {file: "N/A", line: null, column: null, selector: null, url: null},
        evidence: [{type: "spec", path: "N/A", description: ("CVE/Advisory: " + $cve)}],
        cdg_flags: ["security"], fingerprint: $fp, registry_refs: {},
        detected_at: $now, detected_by: $detector
      }' >> "$SIGNALS_TMP"
  done < <((set +euo pipefail; source "$pm_file" && scan "$SOURCE_DIR") 2>/dev/null) || true
done

# ============================================================
# If no PMs detected, emit info signal
# ============================================================
if [ ${#DETECTED_PMS[@]} -eq 0 ]; then
  jq -nc \
    --arg probe "$PROBE_ID" \
    --arg pver "$PROBE_VERSION" \
    --arg now "$(iso_now)" \
    --arg detector "$LANE/$PROBE_ID" \
    '{
      "$schema": "signal-v2",
      dimension_id: "QD3",
      probe_id: $probe, probe_version: $pver,
      severity: "info", fixability: "none", domain: "dependency",
      title: "Dep vuln probe: no package manager detected in source directory",
      description: "No supported PM lockfile/manifest found. Dependency vulnerability scan skipped.",
      location: {file: "N/A", line: null, column: null, selector: null, url: null},
      evidence: [{type: "spec", path: "N/A", description: "SPEC-ONLY-PROBE-SKIP: no PM detected"}],
      cdg_flags: [], fingerprint: "spec-only-probe-skip-depvuln",
      registry_refs: {},
      detected_at: $now, detected_by: $detector
    }' >> "$SIGNALS_TMP"
fi

# ============================================================
# Output JSON wrapper (schema lane-signals-v1)
# ============================================================
jq -n \
  --arg lane "$LANE" \
  --arg dim "QD3" \
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
