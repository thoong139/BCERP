#!/usr/bin/env bash
# implement-snapshot.sh — Registry safe-write verify (Phase 6 step 6.5).
# So sánh registry trước/sau update để confirm CHỈ impl_status thay đổi (CORE-006).
#
# Usage:
#   bash implement-snapshot.sh --before=<path> --after=<path> --req-ids=REQ-X,REQ-Y
#
# Args:
#   --before=<path>  Snapshot trước update (registry-before.json)
#   --after=<path>   Snapshot sau update (registry-after.json hoặc registry hiện tại)
#   --req-ids=<csv>  REQ-IDs in scope — chỉ những REQ-IDs này được expected change impl_status
#
# Output (stdout): JSON
#   {
#     "passed": true|false,
#     "expected_changes": ["requirements[REQ-X].impl_status: not_started → done", ...],
#     "unexpected_changes": [],
#     "changed_fields_count": 2,
#     "checked_at": "..."
#   }
#
# Exit codes:
#   0 = passed (chỉ expected changes)
#   1 = failed (có unexpected changes)
#   2 = invalid args / missing files

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=implement-common.sh
source "$SCRIPTS_DIR/implement-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

BEFORE=""
AFTER=""
REQ_IDS=""

for arg in "$@"; do
  case "$arg" in
    --before=*)  BEFORE="${arg#*=}" ;;
    --after=*)   AFTER="${arg#*=}" ;;
    --req-ids=*) REQ_IDS="${arg#*=}" ;;
    *) log_warn "Unknown arg: $arg" ;;
  esac
done

[[ -z "$BEFORE" || -z "$AFTER" || -z "$REQ_IDS" ]] && {
  log_error "--before, --after, --req-ids đều required"
  exit 2
}

[[ ! -s "$BEFORE" ]] && { log_error "Before snapshot không tồn tại hoặc rỗng: $BEFORE"; exit 2; }
[[ ! -s "$AFTER" ]] && { log_error "After file không tồn tại hoặc rỗng: $AFTER"; exit 2; }

if ! has_jq; then
  log_error "implement-snapshot requires jq"
  exit 2
fi

# Validate JSON
jq empty "$BEFORE" 2>/dev/null || { log_error "Before file invalid JSON"; exit 2; }
jq empty "$AFTER"  2>/dev/null || { log_error "After file invalid JSON"; exit 2; }

# ─── Build expected change set ───────────────────────────────

# REQ-IDs in scope: chỉ impl_status of these được phép thay đổi
IFS=',' read -ra REQ_ARR <<< "$REQ_IDS"
REQ_IDS_JSON=$(printf '%s\n' "${REQ_ARR[@]}" | jq -R . | jq -s 'map(select(. != ""))')

# ─── Diff ───────────────────────────────────────────────────

# Top-level keys diff (skip = keys that match exactly)
TOP_KEYS_BEFORE=$(jq -r 'keys[]' "$BEFORE" | tr -d '\r' | sort)
TOP_KEYS_AFTER=$(jq -r 'keys[]' "$AFTER" | tr -d '\r' | sort)

UNEXPECTED_CHANGES=()
EXPECTED_CHANGES=()
CHANGED_COUNT=0

# Top-level keys removed → unexpected
while IFS= read -r k; do
  [[ -z "$k" ]] && continue
  if ! grep -qx "$k" <<< "$TOP_KEYS_AFTER"; then
    UNEXPECTED_CHANGES+=("Top-level key removed: $k")
  fi
done <<< "$TOP_KEYS_BEFORE"

# Top-level keys added → unexpected (registry shouldn't grow new top-level fields)
while IFS= read -r k; do
  [[ -z "$k" ]] && continue
  if ! grep -qx "$k" <<< "$TOP_KEYS_BEFORE"; then
    UNEXPECTED_CHANGES+=("Top-level key added: $k")
  fi
done <<< "$TOP_KEYS_AFTER"

# For each top-level key, compare; only requirements[].impl_status (cho REQ-IDs in scope) được phép thay đổi
COMMON_KEYS=$(comm -12 <(echo "$TOP_KEYS_BEFORE" | tr -d '\r') <(echo "$TOP_KEYS_AFTER" | tr -d '\r'))

while IFS= read -r k; do
  [[ -z "$k" ]] && continue
  if [[ "$k" == "requirements" ]]; then
    # Requirements diff per-REQ-ID
    REQ_IDS_LIST_BEFORE=$(jq -r '.requirements[]?.req_id // empty' "$BEFORE" 2>/dev/null | tr -d '\r' | sort)
    REQ_IDS_LIST_AFTER=$(jq -r '.requirements[]?.req_id // empty' "$AFTER" 2>/dev/null | tr -d '\r' | sort)

    if [[ "$REQ_IDS_LIST_BEFORE" != "$REQ_IDS_LIST_AFTER" ]]; then
      # ADDED
      while IFS= read -r r; do
        [[ -z "$r" ]] && continue
        if ! grep -qx "$r" <<< "$REQ_IDS_LIST_BEFORE"; then
          UNEXPECTED_CHANGES+=("requirements[$r] added (not in before snapshot)")
        fi
      done <<< "$REQ_IDS_LIST_AFTER"
      while IFS= read -r r; do
        [[ -z "$r" ]] && continue
        if ! grep -qx "$r" <<< "$REQ_IDS_LIST_AFTER"; then
          UNEXPECTED_CHANGES+=("requirements[$r] removed")
        fi
      done <<< "$REQ_IDS_LIST_BEFORE"
    fi

    # Per-REQ-ID field diff
    while IFS= read -r r; do
      [[ -z "$r" ]] && continue
      BEFORE_REQ=$(jq -c --arg id "$r" '.requirements[] | select(.req_id==$id)' "$BEFORE")
      AFTER_REQ=$(jq -c --arg id "$r" '.requirements[] | select(.req_id==$id)' "$AFTER")

      [[ -z "$BEFORE_REQ" || -z "$AFTER_REQ" ]] && continue
      [[ "$BEFORE_REQ" == "$AFTER_REQ" ]] && continue

      # Check fields differ (other than impl_status)
      FIELDS_DIFFER=$(jq -nc \
        --argjson b "$BEFORE_REQ" \
        --argjson a "$AFTER_REQ" \
        '
        ($b | keys) as $bk |
        ($a | keys) as $ak |
        [($bk | unique) + ($ak | unique) | unique[]
          | select(. as $k | $b[$k] != $a[$k])]
        ')

      while IFS= read -r field; do
        [[ -z "$field" || "$field" == "null" ]] && continue
        # Strip quotes
        field=$(echo "$field" | tr -d '"' | tr -d ',' | tr -d '[' | tr -d ']' | sed 's/^ *//;s/ *$//')
        [[ -z "$field" ]] && continue

        BEFORE_VAL=$(jq -r --arg id "$r" --arg f "$field" '.requirements[] | select(.req_id==$id) | .[$f] // "null"' "$BEFORE" | tr -d '\r')
        AFTER_VAL=$(jq -r --arg id "$r" --arg f "$field" '.requirements[] | select(.req_id==$id) | .[$f] // "null"' "$AFTER" | tr -d '\r')

        if [[ "$field" == "impl_status" ]]; then
          # Check if REQ-ID is in scope
          IN_SCOPE=$(printf '%s\n' "${REQ_ARR[@]}" | grep -Fxq "$r" && echo true || echo false)
          if [[ "$IN_SCOPE" == "true" ]]; then
            EXPECTED_CHANGES+=("requirements[$r].impl_status: $BEFORE_VAL → $AFTER_VAL")
            CHANGED_COUNT=$(( CHANGED_COUNT + 1 ))
          else
            UNEXPECTED_CHANGES+=("requirements[$r].impl_status changed (REQ-ID NOT in scope $REQ_IDS): $BEFORE_VAL → $AFTER_VAL")
          fi
        else
          UNEXPECTED_CHANGES+=("requirements[$r].$field changed: $BEFORE_VAL → $AFTER_VAL (only impl_status allowed)")
        fi
      done < <(echo "$FIELDS_DIFFER" | jq -r '.[]?' 2>/dev/null)
    done <<< "$(echo -e "$REQ_IDS_LIST_BEFORE\n$REQ_IDS_LIST_AFTER" | sort -u)"
  else
    # Other top-level keys — must be byte-identical
    BEFORE_VAL=$(jq -c ".\"$k\"" "$BEFORE")
    AFTER_VAL=$(jq -c ".\"$k\"" "$AFTER")
    if [[ "$BEFORE_VAL" != "$AFTER_VAL" ]]; then
      UNEXPECTED_CHANGES+=("Top-level key '$k' changed (only requirements[].impl_status allowed)")
    fi
  fi
done <<< "$COMMON_KEYS"

# ─── Output ──────────────────────────────────────────────────

PASSED=true
(( ${#UNEXPECTED_CHANGES[@]} > 0 )) && PASSED=false

EXPECTED_JSON='[]'
UNEXPECTED_JSON='[]'
(( ${#EXPECTED_CHANGES[@]} > 0 )) && EXPECTED_JSON=$(printf '%s\n' "${EXPECTED_CHANGES[@]}" | jq -R . | jq -s .)
(( ${#UNEXPECTED_CHANGES[@]} > 0 )) && UNEXPECTED_JSON=$(printf '%s\n' "${UNEXPECTED_CHANGES[@]}" | jq -R . | jq -s .)

RESULT=$(jq -nc \
  --argjson passed "$($PASSED && echo true || echo false)" \
  --argjson expected "$EXPECTED_JSON" \
  --argjson unexpected "$UNEXPECTED_JSON" \
  --argjson count "$CHANGED_COUNT" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{
    passed: $passed,
    expected_changes: $expected,
    unexpected_changes: $unexpected,
    changed_fields_count: $count,
    checked_at: $ts
  }')

echo "$RESULT" | jq '.'
$PASSED && exit 0 || exit 1
