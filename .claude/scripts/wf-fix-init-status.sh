#!/usr/bin/env bash
# wf-fix-init-status.sh — Init fix-status.json từ template + parse flags từ $ARGUMENTS.
#
# Vai tro: 1 chỗ duy nhất tạo fix-status.json — tránh inline jq scattered trong nhiều procedures.
# Tuân thủ CORE-031 (Template Usage): READ template → POPULATE → WRITE.
#
# Usage:
#   bash wf-fix-init-status.sh \
#     --session-dir <path> \
#     --fix-id <id> \
#     --profile <quick|standard|deep|exhaustive> \
#     --dimensions <QD1,QD3,QD5> \
#     [--arguments "<raw $ARGUMENTS string>"] \
#     [--scope <all|system|module>] \
#     [--name <id>]
#
# Flag detection từ --arguments:
#   --llm-scan   → flags.llm_scan = true
#   --dry-run    → flags.dry_run = true
#   --deep       → flags.deep = true
#   --responsive → flags.responsive = true
#   --no-browser → flags.no_browser = true
#   --browser-only → flags.browser_only = true
#   --run-tests  → flags.run_tests = true
#   --url=<URL>  → flags.url = "<URL>"           (fix #2)
#   --credentials=email:password|cookie:NAME=VAL → flags.credentials = "<value>"  (fix #2)
#
# Validation:
#   --llm-scan + profile NOT IN {deep, exhaustive} → exit 2 với suggestion.
#
# Exit codes:
#   0 — success (fix-status.json written)
#   1 — invalid args / template missing
#   2 — flag validation fail (e.g., --llm-scan + profile=quick)
#   3 — write fail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE_PATH="$REPO_ROOT/.claude/skills/workflow/_shared/templates/fix-status.json"

# ============================================================
# ARG PARSING
# ============================================================
SESSION_DIR=""
FIX_ID=""
PROFILE="standard"
DIMENSIONS=""
ARGUMENTS_RAW=""
SCOPE="all"
NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-dir) SESSION_DIR="$2"; shift 2 ;;
    --fix-id)      FIX_ID="$2"; shift 2 ;;
    --profile)     PROFILE="$2"; shift 2 ;;
    --dimensions)  DIMENSIONS="$2"; shift 2 ;;
    --arguments)   ARGUMENTS_RAW="$2"; shift 2 ;;
    --scope)       SCOPE="$2"; shift 2 ;;
    --name)        NAME="$2"; shift 2 ;;
    -h|--help)     sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -n "$SESSION_DIR" ] || { echo "ERROR: --session-dir required" >&2; exit 1; }
[ -d "$SESSION_DIR" ] || { echo "ERROR: session-dir not found: $SESSION_DIR" >&2; exit 1; }
[ -n "$FIX_ID" ]     || FIX_ID="$(basename "$SESSION_DIR")"
[ -s "$TEMPLATE_PATH" ] || { echo "ERROR: template not found: $TEMPLATE_PATH" >&2; exit 1; }

# ============================================================
# DETECT FLAGS từ $ARGUMENTS
# ============================================================
# Bash word-match (space-delimited) — sufficient cho flag detection.
flag_present() {
  local needle="$1"
  case " $ARGUMENTS_RAW " in
    *" $needle "*|*" $needle="*) return 0 ;;
    *) return 1 ;;
  esac
}

LLM_SCAN=false
DRY_RUN=false
DEEP=false
RESPONSIVE=false
NO_BROWSER=false
BROWSER_ONLY=false
RUN_TESTS=false

flag_present "--llm-scan"     && LLM_SCAN=true
flag_present "--dry-run"      && DRY_RUN=true
flag_present "--deep"         && DEEP=true
flag_present "--responsive"   && RESPONSIVE=true
flag_present "--no-browser"   && NO_BROWSER=true
flag_present "--browser-only" && BROWSER_ONLY=true
flag_present "--run-tests"    && RUN_TESTS=true

# --full-test = --deep + --responsive (per SKILL.md Arguments table)
if flag_present "--full-test"; then
  DEEP=true
  RESPONSIVE=true
fi

# Parse --url=<URL> và --credentials=<value> (fix #2 — runtime probe context)
URL_VAL=""
CREDS_VAL=""
# Use sed to extract value after `--url=` (rest until next space).
# Tolerant pattern: matches both `--url=foo` and `--url foo`.
URL_MATCH=$(echo " $ARGUMENTS_RAW " | sed -n 's/.* --url=\([^ ]*\).*/\1/p; s/.* --url \([^ ]*\).*/\1/p' | head -1)
[ -n "$URL_MATCH" ] && URL_VAL="$URL_MATCH"

CREDS_MATCH=$(echo " $ARGUMENTS_RAW " | sed -n 's/.* --credentials=\([^ ]*\).*/\1/p; s/.* --credentials \([^ ]*\).*/\1/p' | head -1)
[ -n "$CREDS_MATCH" ] && CREDS_VAL="$CREDS_MATCH"

# ============================================================
# VALIDATE
# ============================================================
# --llm-scan requires --profile in {deep, exhaustive}
if [ "$LLM_SCAN" = "true" ]; then
  case "$PROFILE" in
    deep|exhaustive) ;;
    *)
      echo "ERROR: --llm-scan requires --profile=deep|exhaustive (current: $PROFILE)." >&2
      echo "  Lý do: LLM probe cost ~\$0.50-2.00/run. Profile=quick/standard không justify cost." >&2
      echo "  Fix: chạy lại với --profile=deep --llm-scan." >&2
      exit 2
      ;;
  esac
fi

# ============================================================
# BUILD dimensions array (JSON)
# ============================================================
DIMS_JSON='null'
if [ -n "$DIMENSIONS" ]; then
  DIMS_JSON=$(echo "$DIMENSIONS" | jq -R -c 'split(",") | map(select(length > 0))')
fi

NAME_JSON='null'
[ -n "$NAME" ] && NAME_JSON=$(jq -n --arg n "$NAME" '$n')

URL_JSON='null'
[ -n "$URL_VAL" ] && URL_JSON=$(jq -n --arg v "$URL_VAL" '$v')

## HIGH-8 fix v9.0.3 — redact credentials trong fix-status.json
##
## Truoc fix: $CREDS_VAL plaintext duoc ghi vao .flags.credentials → bat ky tool nao
## doc fix-status.json deu thay credential. PII/audit risk.
##
## Sau fix:
##   - fix-status.json: chi luu metadata an toan (scheme, length, sha256_8 prefix)
##   - $SESSION_DIR/.credentials.txt: raw value (chmod 600, .mc-data/ gitignored toan bo)
##   - Probe scripts can credential -> doc tu $SESSION_DIR/.credentials.txt thay vi flags.credentials
CREDS_JSON='null'
if [ -n "$CREDS_VAL" ]; then
  # Persist raw vao file separate (chmod 600 — chong thay duoc tinh co qua jq read)
  CREDS_FILE="$SESSION_DIR/.credentials.txt"
  printf '%s' "$CREDS_VAL" > "$CREDS_FILE"
  chmod 600 "$CREDS_FILE" 2>/dev/null || true

  # Tinh metadata an toan
  CRED_LEN=${#CREDS_VAL}
  # Best-effort hash 8 ky tu prefix (sha256), giup audit khac voi nhau ma khong leak
  CRED_HASH8=$(printf '%s' "$CREDS_VAL" | sha256sum 2>/dev/null | cut -c1-8 || echo "n/a")
  # Detect scheme tu format
  case "$CREDS_VAL" in
    cookie:*)        CRED_SCHEME="cookie" ;;
    *@*:*|*:*)       CRED_SCHEME="email_password" ;;
    *)               CRED_SCHEME="opaque" ;;
  esac

  CREDS_JSON=$(jq -nc \
    --arg scheme "$CRED_SCHEME" \
    --argjson length "$CRED_LEN" \
    --arg hash8 "$CRED_HASH8" \
    --arg ref "$CREDS_FILE" \
    '{
      "$redacted": true,
      scheme: $scheme,
      length: $length,
      hash8: $hash8,
      raw_path: $ref,
      note: "Plaintext credentials persist o raw_path (chmod 600). Probe scripts doc tu day, KHONG tu fix-status.json."
    }')
fi

# ============================================================
# POPULATE template + WRITE atomic
# ============================================================
NOW_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
OUT_PATH="$SESSION_DIR/fix-status.json"
TMP_PATH="$SESSION_DIR/.fix-status.tmp.$$"

jq \
  --arg fix_id "$FIX_ID" \
  --argjson dims "$DIMS_JSON" \
  --arg profile "$PROFILE" \
  --arg scope "$SCOPE" \
  --argjson name "$NAME_JSON" \
  --argjson dry_run "$DRY_RUN" \
  --argjson deep "$DEEP" \
  --argjson responsive "$RESPONSIVE" \
  --argjson no_browser "$NO_BROWSER" \
  --argjson browser_only "$BROWSER_ONLY" \
  --argjson run_tests "$RUN_TESTS" \
  --argjson llm_scan "$LLM_SCAN" \
  --argjson url "$URL_JSON" \
  --argjson credentials "$CREDS_JSON" \
  --arg now "$NOW_ISO" \
  '
  .fix_id = $fix_id
  | .dimensions_resolved = $dims
  | .profile_used = $profile
  | .flags.scope = $scope
  | .flags.name = $name
  | .flags.dry_run = $dry_run
  | .flags.deep = $deep
  | .flags.responsive = $responsive
  | .flags.no_browser = $no_browser
  | .flags.browser_only = $browser_only
  | .flags.run_tests = $run_tests
  | .flags.llm_scan = $llm_scan
  | .flags.url = $url
  | .flags.credentials = $credentials
  | .created_at = $now
  | .updated_at = $now
  ' "$TEMPLATE_PATH" > "$TMP_PATH" || {
    echo "ERROR: jq populate failed" >&2
    rm -f "$TMP_PATH"
    exit 3
  }

# Sanity: output is valid JSON
jq -e '.' "$TMP_PATH" >/dev/null 2>&1 || {
  echo "ERROR: populated JSON invalid" >&2
  rm -f "$TMP_PATH"
  exit 3
}

mv "$TMP_PATH" "$OUT_PATH"

# ============================================================
# REPORT
# ============================================================
echo "OK: fix-status.json initialized at $OUT_PATH"
echo "  fix_id      = $FIX_ID"
echo "  profile     = $PROFILE"
echo "  dimensions  = ${DIMENSIONS:-(auto)}"
echo "  llm_scan    = $LLM_SCAN"
[ "$LLM_SCAN" = "true" ] && echo "  → LLM probes WILL be invoked (profile=$PROFILE allows it)"
exit 0
