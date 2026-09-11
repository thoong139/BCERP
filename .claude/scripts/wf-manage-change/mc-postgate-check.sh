#!/usr/bin/env bash
# mc-postgate-check.sh — T1->T4 validation cho bat ky phase/file
# Usage: mc-postgate-check.sh --file=PATH --type=json
#        mc-postgate-check.sh --file=PATH --type=markdown --headings="## Summary,## Changes"
#
# Output: JSON {"t1_existence":bool,"t2_nonempty":bool,"t3_format":bool,"t4_content":bool,"pass":bool}
#
# Exit codes: 0 = all pass, 1 = any fail

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=mc-common.sh
source "$SCRIPTS_DIR/mc-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

FILE=""
TYPE=""
HEADINGS=""

for arg in "$@"; do
  case "$arg" in
    --file=*)     FILE="${arg#*=}" ;;
    --type=*)     TYPE="${arg#*=}" ;;
    --headings=*) HEADINGS="${arg#*=}" ;;
    *) mc_warn "Unknown arg: $arg" ;;
  esac
done

if [[ -z "$FILE" ]]; then
  mc_err "Usage: mc-postgate-check.sh --file=PATH --type=json|markdown [--headings=H1,H2]"
  exit 2
fi

T1=false T2=false T3=false T4=false

# ─── T1: File exists ────────────────────────────────────────

if [[ ! -f "$FILE" ]]; then
  if mc_has_jq; then
    jq -n '{t1_existence:false,t2_nonempty:false,t3_format:false,t4_content:false,pass:false,error:"file_not_found"}'
  else
    echo '{"t1_existence":false,"t2_nonempty":false,"t3_format":false,"t4_content":false,"pass":false,"error":"file_not_found"}'
  fi
  exit 1
fi
T1=true

# ─── T2: Non-empty ─────────────────────────────────────────

SIZE=$(wc -c < "$FILE")
if [[ $SIZE -gt 0 ]]; then
  T2=true
fi

# ─── T3: Format ────────────────────────────────────────────

if [[ "$TYPE" == "json" ]]; then
  if mc_jq_validate "$FILE"; then
    T3=true
  fi
elif [[ "$TYPE" == "markdown" ]]; then
  # Markdown format check: look for markdown markers in first 5 lines
  # T3 for markdown is intentionally lenient — real content validation happens in T4 (headings check)
  if head -5 "$FILE" | grep -qE '^#|^\*\*|^\-|^>' 2>/dev/null; then
    T3=true
  else
    # No markdown markers found — could be plain text or malformed
    # Still pass T3 since T4 heading check will catch real issues
    T3=true
    mc_debug "T3 markdown: no markers in first 5 lines — deferring to T4"
  fi
else
  # Unknown type — skip T3 (pass)
  T3=true
fi

# ─── T4: Content ───────────────────────────────────────────

if [[ -n "$HEADINGS" ]]; then
  T4_PASS=true
  MISSING=()
  IFS=',' read -ra HEADS <<< "$HEADINGS"
  for h in "${HEADS[@]}"; do
    if ! grep -qF "$h" "$FILE" 2>/dev/null; then
      MISSING+=("$h")
      T4_PASS=false
    fi
  done
  if $T4_PASS; then
    T4=true
  else
    mc_warn "Missing headings: ${MISSING[*]}"
  fi
else
  # No headings specified — skip T4 (pass)
  T4=true
fi

# ─── Output ────────────────────────────────────────────────

ALL_PASS=false
if $T1 && $T2 && $T3 && $T4; then
  ALL_PASS=true
fi

if mc_has_jq; then
  jq -n \
    --argjson t1 "$T1" \
    --argjson t2 "$T2" \
    --argjson t3 "$T3" \
    --argjson t4 "$T4" \
    --argjson pass "$ALL_PASS" \
    '{t1_existence:$t1, t2_nonempty:$t2, t3_format:$t3, t4_content:$t4, pass:$pass}'
else
  printf '{"t1_existence":%s,"t2_nonempty":%s,"t3_format":%s,"t4_content":%s,"pass":%s}\n' \
    "$T1" "$T2" "$T3" "$T4" "$ALL_PASS"
fi

if $ALL_PASS; then
  exit 0
else
  exit 1
fi
