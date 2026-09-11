#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-static-vue.sh — Static probe: Vue Composition API checks
#
# Phase B v8 — Stack-Aware Probe Registry. Phat hien:
#  - QD1: ref()/reactive() destructure mat reactivity (.value missing)
#  - QD1: <script setup> defineEmits/defineProps thieu type
#  - QD7: $t() / t() goi i18n key khong ton tai (cross-validate vi voi messages/*.json)
#
# Probes:
#   P-QD1-vue-composition-check  → Vue Composition API contracts
#   P-QD7-vue-i18n-key-audit     → Vue i18n key existence (vue-i18n)
#
# OUTPUT: JSON stdout theo schema lane-signals-v1
# Cache policy: allowed (static analysis)


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wf-fix-common.sh"

with_runtime_cap "$@"
_sha256() { sha256sum 2>/dev/null || shasum -a 256; }

SESSION_DIR=""
LANE=""
PROBE_ID=""
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

[ -z "$LANE" ] && case "$PROBE_ID" in
  P-QD1-*) LANE="wf-fix-functional" ;;
  P-QD7-*) LANE="wf-fix-compat" ;;
  *)       LANE="wf-fix-functional" ;;
esac

case "$PROBE_ID" in
  P-QD1-*) DIMENSION="QD1" ;;
  P-QD7-*) DIMENSION="QD7" ;;
  *)       DIMENSION="QD1" ;;
esac

if [ ! -d "$SOURCE_DIR" ]; then
  jq -nc \
    --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
    --arg profile "$PROFILE" --arg now "$(iso_now)" --arg dim "$DIMENSION" \
    '{"$schema": "lane-signals-v1", lane: $lane, dimension: $dim, probe_id: $probe,
      probe_version: $pver, profile: $profile, generated_at: $now,
      signals: [], skip_reason: "no_source_dir"}'
  exit 0
fi

EXCLUDE='(node_modules|\.git/|dist/|build/|coverage/|/test/|\.spec\.|\.test\.|fixtures/)'

EMIT() {
  local title="$1" desc="$2" severity="$3" file="$4" line="$5" suggested_action="$6"
  local fp
  fp=$(echo -n "$DIMENSION|$file|$line|$PROBE_ID|$title" | _sha256 | awk '{print "sha256:"$1}')
  jq -nc \
    --arg t "$title" --arg d "$desc" --arg s "$severity" \
    --arg f "$file" --argjson l "$line" --arg fp "$fp" --arg pid "$PROBE_ID" \
    --arg pver "$PROBE_VERSION" --arg lane "$LANE" --arg now "$(iso_now)" \
    --arg sa "$suggested_action" --arg dim "$DIMENSION" \
    '{
      "$schema": "signal-v2",
      dimension_id: $dim,
      probe_id: $pid,
      probe_version: $pver,
      severity: $s,
      fixability: "agent_fix",
      domain: "frontend",
      title: $t,
      description: $d,
      location: { file: $f, line: $l, column: null, selector: null, url: null },
      evidence: { code_snippet: null, test_failure: null, screenshot: null,
                  related_signals: [], reproduction_steps: null },
      remediation: { suggested_action: $sa, test_recommendation: null,
                     references: [], estimated_effort_min: 5 },
      fingerprint: $fp,
      probe_metadata: { lane: $lane, generated_at: $now }
    }'
}

SIGNALS_FILE=$(mktemp)
trap 'rm -f "$SIGNALS_FILE"' EXIT

# ────────────────────────────────────────────────────────────
# P-QD1-vue-composition-check: ref/reactive destructure
# ────────────────────────────────────────────────────────────
if [ "$PROBE_ID" = "P-QD1-vue-composition-check" ]; then
  # Detect: const { x, y } = reactive({...}) — destructure mat reactivity
  while IFS=: read -r file line _; do
    [ -z "$file" ] && continue
    file_rel="${file#$SOURCE_DIR}"
    EMIT "Vue reactive destructure mat reactivity" \
      "Tai $file:$line co destructure tu reactive() — cac fields se mat reactivity sau khi destructure." \
      "high" "$file_rel" "$line" \
      "Dung toRefs() de giu reactivity: \`const { x, y } = toRefs(state)\`. Hoac access truc tiep qua \`state.x\`." \
      >> "$SIGNALS_FILE"
  done < <(
    grep -rEn 'const\s*\{\s*[a-zA-Z_$][a-zA-Z0-9_$,\s]*\s*\}\s*=\s*reactive\(' "$SOURCE_DIR" \
      --include='*.vue' --include='*.ts' --include='*.js' 2>/dev/null \
      | grep -vE "$EXCLUDE" \
      | head -50
  )
fi

# ────────────────────────────────────────────────────────────
# P-QD7-vue-i18n-key-audit: Cross-validate t('key') vs messages/*.json
# ────────────────────────────────────────────────────────────
if [ "$PROBE_ID" = "P-QD7-vue-i18n-key-audit" ] && [ "$PROFILE" != "quick" ]; then
  # Find translation files
  MESSAGES_FILE=""
  for candidate in \
    "$SOURCE_DIR/locales/vi.json" \
    "$SOURCE_DIR/locales/en.json" \
    "$SOURCE_DIR/i18n/vi.json" \
    "$SOURCE_DIR/i18n/en.json" \
    "$SOURCE_DIR/lang/vi.json"
  do
    if [ -f "$candidate" ]; then
      MESSAGES_FILE="$candidate"
      break
    fi
  done

  if [ -n "$MESSAGES_FILE" ]; then
    USED_KEYS_TMP=$(mktemp)
    DEFINED_KEYS_TMP=$(mktemp)
    trap 'rm -f "$USED_KEYS_TMP" "$DEFINED_KEYS_TMP"' EXIT

    # Extract used i18n keys: t('key') / $t('key') / i18n.t('key')
    grep -rEoh "(\\\$t|\bt|i18n\.t)\(['\"][a-zA-Z][a-zA-Z0-9._-]{3,}['\"]" "$SOURCE_DIR" \
      --include='*.vue' --include='*.ts' --include='*.js' 2>/dev/null \
      | grep -oE "['\"][a-zA-Z][a-zA-Z0-9._-]+['\"]" \
      | tr -d "'\"" \
      | sort -u > "$USED_KEYS_TMP" || true

    # Extract defined keys
    jq -r 'paths(type == "string") | join(".")' "$MESSAGES_FILE" 2>/dev/null \
      | sort -u > "$DEFINED_KEYS_TMP" || true

    # Diff: used but not defined
    while IFS= read -r missing_key; do
      [ -z "$missing_key" ] && continue
      file=$(grep -rln "['\"]${missing_key}['\"]" "$SOURCE_DIR" \
        --include='*.vue' --include='*.ts' --include='*.js' 2>/dev/null | head -1)
      if [ -n "$file" ]; then
        line=$(grep -n "['\"]${missing_key}['\"]" "$file" 2>/dev/null | head -1 | cut -d: -f1)
        [ -z "$line" ] && line=1
        file_rel="${file#$SOURCE_DIR}"
        EMIT "Vue i18n key thieu trong translation file" \
          "Key \`$missing_key\` duoc dung tai $file:$line nhung khong ton tai trong $MESSAGES_FILE — runtime se hien raw key thay vi text." \
          "high" "$file_rel" "$line" \
          "Them key \`$missing_key\` vao $MESSAGES_FILE voi gia tri tieng Viet phu hop." \
          >> "$SIGNALS_FILE"
      fi
    done < <(comm -23 "$USED_KEYS_TMP" "$DEFINED_KEYS_TMP" 2>/dev/null || true)
  fi
fi

# ────────────────────────────────────────────────────────────
# Output
# ────────────────────────────────────────────────────────────
SIGNAL_COUNT=$(wc -l < "$SIGNALS_FILE" | tr -d ' ')

if [ "$SIGNAL_COUNT" -eq 0 ]; then
  jq -nc \
    --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
    --arg profile "$PROFILE" --arg now "$(iso_now)" --arg dim "$DIMENSION" \
    '{"$schema": "lane-signals-v1", lane: $lane, dimension: $dim, probe_id: $probe,
      probe_version: $pver, profile: $profile, generated_at: $now, signals: []}'
else
  jq -sc \
    --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
    --arg profile "$PROFILE" --arg now "$(iso_now)" --arg dim "$DIMENSION" \
    '{"$schema": "lane-signals-v1", lane: $lane, dimension: $dim, probe_id: $probe,
      probe_version: $pver, profile: $profile, generated_at: $now, signals: .}' \
    "$SIGNALS_FILE"
fi

exit 0
