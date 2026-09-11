#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-static-secret.sh — Static probe: Secret Detection (QD3)
#
# Phat hien hard-coded secrets: API keys, passwords, tokens, private keys trong source code.
# CDG trigger: signals carry CDG-SECURITY-LIVE flag (require user confirm truoc khi auto-fix).
#
# OUTPUT: JSON tren stdout theo schema lane-signals-v1
# Cache policy: NEVER (ADR-22 Rule 6 — security probes always re-scan)
#
# USAGE:
#   bash wf-fix-probe-static-secret.sh \
#     --session-dir <path> --lane wf-fix-security --probe P-QD3-secret-detection \
#     [--profile standard|deep|exhaustive] [--source-dir src/]
#
# EXIT CODES: 0 success, 1 error
#
# Author: S5 wf-fix-bugs v7.0


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./wf-fix-common.sh
source "$SCRIPT_DIR/wf-fix-common.sh"

# Defensive runtime cap (SB-01 v7.4.0 e2e fix): prevent hang on large codebases.
with_runtime_cap "$@"
# Cross-platform sha256 (GNU sha256sum / macOS shasum)
_sha256() { sha256sum 2>/dev/null || shasum -a 256; }

SESSION_DIR=""
LANE="wf-fix-security"
PROBE_ID="P-QD3-secret-detection"
PROBE_VERSION="v1.0"
PROFILE="standard"
SOURCE_DIR="src/"

while [ $# -gt 0 ]; do
  case "$1" in
    --session-dir) SESSION_DIR="$2"; shift 2 ;;
    --lane) LANE="$2"; shift 2 ;;
    --probe) PROBE_ID="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --source-dir) SOURCE_DIR="$2"; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg $1" >&2; exit 1 ;;
  esac
done

if [ ! -d "$SOURCE_DIR" ]; then
  # Skip — emit empty signals
  jq -nc \
    --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
    --arg profile "$PROFILE" --arg now "$(iso_now)" \
    '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD3", probe_id: $probe,
      probe_version: $pver, profile: $profile, generated_at: $now,
      signals: [], skip_reason: "no_source_dir"}'
  exit 0
fi

# ============================================================
# Secret patterns (regex high-confidence)
# Format: "label|severity|regex"
# ============================================================
PATTERNS=(
  "AWS Access Key|critical|AKIA[0-9A-Z]{16}"
  "AWS Secret Key|critical|aws_secret_access_key[\"'[:space:]]*[:=][\"'[:space:]]*[A-Za-z0-9/+=]{40}"
  "Google API Key|critical|AIza[0-9A-Za-z_-]{35}"
  "GitHub Token|critical|gh[pousr]_[A-Za-z0-9]{36,255}"
  "Slack Token|critical|xox[baprs]-[A-Za-z0-9-]+"
  "Stripe Live Key|critical|sk_live_[0-9a-zA-Z]{24,}"
  "Stripe Test Key|high|sk_test_[0-9a-zA-Z]{24,}"
  "JWT Token|high|eyJ[A-Za-z0-9_-]{10,}\\.eyJ[A-Za-z0-9_-]{10,}\\.[A-Za-z0-9_-]{10,}"
  "Private Key Header|critical|-----BEGIN (RSA|DSA|EC|OPENSSH|PGP) PRIVATE KEY-----"
  "Generic API Key|high|api[_-]?key[\"'[:space:]]*[:=][\"'[:space:]]*[\"'][A-Za-z0-9+/=_-]{16,}[\"']"
  "Generic Password|high|password[\"'[:space:]]*[:=][\"'[:space:]]*[\"'][^[:space:]\"']{8,}[\"']"
  "Database URL|high|(postgres|postgresql|mysql|mongodb|redis)://[^[:space:]\"']+:[^[:space:]\"']+@"
  "Bearer Token Hardcoded|high|[Bb]earer[[:space:]]+[A-Za-z0-9._~+/=-]{20,}"
  "Hex Hash 64+|medium|[\"'][0-9a-fA-F]{64,}[\"']"
)

# G5 (v11.1.0): Build exclusion regex từ exclusions.json (schema scan-exclusions-v1).
# Default fallback dùng inline regex để backward-compat với sessions chạy trên repo
# chưa có exclusions.json. Env MCV3_FIX_SECURITY_EXCLUSIONS_DISABLE=true → bypass G5.
EXCLUSIONS_FILE="${MCV3_FIX_SECURITY_EXCLUSIONS_FILE:-.claude/skills/workflow/wf-fix-security/exclusions.json}"
EXCLUDE_PATTERN='(__tests__|test/|tests/|spec/|\.test\.|\.spec\.|fixtures/|mocks?/|examples?/|docs?/|\.md$|node_modules|\.git/)'

if [ "${MCV3_FIX_SECURITY_EXCLUSIONS_DISABLE:-false}" != "true" ] && \
   [ -f "$EXCLUSIONS_FILE" ] && command -v jq >/dev/null 2>&1; then
  G5_PATTERNS=$(jq -r '
    [.exclusions[]
     | select((.applies_to // []) | index("P-QD3-secret-detection"))
     | .patterns[]]
    | unique
    | join("|")
  ' "$EXCLUSIONS_FILE" 2>/dev/null)
  if [ -n "$G5_PATTERNS" ] && [ "$G5_PATTERNS" != "null" ]; then
    EXCLUDE_PATTERN="($G5_PATTERNS)"
  fi
fi

MCV3_TMP="$SESSION_DIR/.probe-secret-tmp"
mkdir -p "$MCV3_TMP" 2>/dev/null || { echo "ERROR: cannot create tmp dir $MCV3_TMP" >&2; exit 1; }
SIGNALS_TMP="$MCV3_TMP/signals.$$.jsonl"
trap 'rm -rf "$MCV3_TMP"' EXIT
: > "$SIGNALS_TMP"
SIG_NUM=0

if [ -d "$SOURCE_DIR" ]; then
  # Fix #7 v8.0: Build combined regex — single grep scan thay O(N) scans.
  # Classification per line van dung PATTERNS array, nhung moi grep test
  # chi tren 1 dong text (microseconds) thay vi full directory scan.
  COMBINED_REGEX=""
  for entry in "${PATTERNS[@]}"; do
    IFS='|' read -r _label _severity regex <<< "$entry"
    if [ -z "$COMBINED_REGEX" ]; then
      COMBINED_REGEX="$regex"
    else
      COMBINED_REGEX="$COMBINED_REGEX|$regex"
    fi
  done

  SECRET_TMP=$(mktemp)
  grep -rEn -e "$COMBINED_REGEX" "$SOURCE_DIR" \
    --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
    --include='*.py' --include='*.java' --include='*.cs' --include='*.go' --include='*.rs' \
    --include='*.json' --include='*.yml' --include='*.yaml' --include='*.env' \
    --include='*.config' --include='*.conf' \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build --exclude-dir=.next --exclude-dir=coverage \
    2>/dev/null > "$SECRET_TMP" || true

  while IFS=: read -r file line match; do
    [ -z "$file" ] && continue
    [ -z "$line" ] && continue

    # Filter out test fixtures, examples, docs
    if echo "$file" | grep -qE "$EXCLUDE_PATTERN"; then
      continue
    fi

    # Classify: find which pattern matched (lightweight — single text line)
    found_label=""
    found_severity=""
    for entry in "${PATTERNS[@]}"; do
      IFS='|' read -r label severity regex <<< "$entry"
      if echo "$match" | grep -qE -e "$regex"; then
        found_label="$label"
        found_severity="$severity"
        break
      fi
    done
    [ -z "$found_label" ] && continue

    # Filter out comment-only lines (heuristic: line starts voi //, #, or *)
    if echo "$match" | grep -qE '^[[:space:]]*(//|#|\*|--)' ; then
      # Check vi du / placeholder
      if echo "$match" | grep -qiE '(example|placeholder|TODO|FIXME|sample|your_|your-|YOUR_|change[_-]?me)'; then
        continue
      fi
    fi

    SIG_NUM=$((SIG_NUM + 1))
    snippet=$(echo "$match" | head -c 200 | jq -Rs '.' | sed 's/^"//; s/"$//')
    fp=$(echo -n "QD3|$file|$line|$PROBE_ID|secret|$found_label" | _sha256 | awk '{print "sha256:"$1}')

    sig=$(jq -nc \
      --arg label "$found_label" \
      --arg severity "$found_severity" \
      --arg file "$file" \
      --argjson line "$line" \
      --arg probe "$PROBE_ID" \
      --arg pver "$PROBE_VERSION" \
      --arg snippet "$(echo "$match" | head -c 100)" \
      --arg fp "$fp" \
      --arg now "$(iso_now)" \
      --arg detector "$LANE/$PROBE_ID" \
      '{
        "$schema": "signal-v2",
        dimension_id: "QD3",
        probe_id: $probe,
        probe_version: $pver,
        severity: $severity,
        fixability: "agent_fix",
        domain: "security",
        title: ("Hardcoded secret: " + $label),
        description: ("Phat hien possible " + $label + " trong source code. Move secret sang env var hoac secrets manager."),
        location: {file: $file, line: $line, column: null, selector: null, url: null},
        evidence: [{type: "code", path: $file, description: ("Pattern matched: " + $label + " | snippet: " + $snippet)}],
        cdg_flags: ["CDG-SECURITY-LIVE"],
        fingerprint: $fp,
        detected_at: $now,
        detected_by: $detector
      }')
    printf '%s\n' "$sig" >> "$SIGNALS_TMP"
  done < "$SECRET_TMP"
  rm -f "$SECRET_TMP"
fi

# Output JSON (dung --slurpfile tranh "Argument list too long")
jq -n \
  --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
  --arg profile "$PROFILE" --arg now "$(iso_now)" \
  --argjson signal_count "$SIG_NUM" \
  --slurpfile signals "$SIGNALS_TMP" \
  '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD3", probe_id: $probe,
    probe_version: $pver, profile: $profile, generated_at: $now, signals: $signals}'

exit 0
