#!/usr/bin/env bash
# Version snapshot cho BE/FE: git HEAD SHA + migration count.
# Dung de detect khi BE bi crash giua chung — restart inline an toan hay khong.
#
# Usage:
#   source version-snapshot.sh
#   snapshot_version <resource> <session_id>                     # ghi snapshot
#   diff_version     <resource> <session_id>                     # so sanh, print JSON
#                                                                 # exit 0 same, 1 changed, 2 no-snapshot
#
# Snapshot file: .mc-data/_global_locks/version-snapshot/{session_id}-{resource}.json

set -uo pipefail

GLOBAL_LOCKS_DIR="${MCV3_GLOBAL_LOCKS_DIR:-.mc-data/_global_locks}"
SNAPSHOT_DIR="$GLOBAL_LOCKS_DIR/version-snapshot"

_vs_iso_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

_vs_git_head() {
  git rev-parse HEAD 2>/dev/null || echo "no-git"
}

_vs_migration_count() {
  # Dem so migration file da apply trong project EUREKA.
  # Fallback ve so file .cs trong Migrations/ neu khong co dotnet.
  local count
  if [[ -d apps/backend/Eureka.Infrastructure/Persistence/Migrations ]]; then
    count=$(find apps/backend/Eureka.Infrastructure/Persistence/Migrations \
              -name "*.cs" -not -name "*ModelSnapshot*" -not -name "*.Designer.cs" 2>/dev/null | wc -l | tr -d ' ')
    echo "${count:-0}"
  else
    echo "0"
  fi
}

_vs_snapshot_file() {
  echo "$SNAPSHOT_DIR/$2-$1.json"
}

snapshot_version() {
  local resource="$1" session_id="$2"
  mkdir -p "$SNAPSHOT_DIR" 2>/dev/null || true

  local file
  file=$(_vs_snapshot_file "$resource" "$session_id")

  jq -n --arg r "$resource" --arg sid "$session_id" \
        --arg head "$(_vs_git_head)" --arg mig "$(_vs_migration_count)" \
        --arg ts "$(_vs_iso_now)" '{
    "$schema": "version-snapshot-v1",
    "resource": $r,
    "session_id": $sid,
    "git_head": $head,
    "migration_count": ($mig | tonumber),
    "captured_at": $ts
  }' > "$file"
  echo "$file"
}

# diff_version <resource> <session_id>
# Print JSON describing diff. Exit codes:
#   0 = unchanged
#   1 = changed (git_head OR migration_count khac)
#   2 = no snapshot found
diff_version() {
  local resource="$1" session_id="$2"
  local file
  file=$(_vs_snapshot_file "$resource" "$session_id")

  if [[ ! -f "$file" ]]; then
    jq -n '{status:"no_snapshot"}'
    return 2
  fi

  local cur_head cur_mig snap_head snap_mig
  cur_head=$(_vs_git_head)
  cur_mig=$(_vs_migration_count)
  snap_head=$(jq -r '.git_head' "$file")
  snap_mig=$(jq -r '.migration_count' "$file")

  if [[ "$cur_head" == "$snap_head" && "$cur_mig" == "$snap_mig" ]]; then
    jq -n --arg h "$cur_head" --arg m "$cur_mig" \
      '{status:"unchanged", git_head:$h, migration_count:($m|tonumber)}'
    return 0
  fi

  jq -n --arg sh "$snap_head" --arg ch "$cur_head" \
        --arg sm "$snap_mig" --arg cm "$cur_mig" '{
    status: "changed",
    git_head: {snapshot:$sh, current:$ch, diff:($sh != $ch)},
    migration_count: {snapshot:($sm|tonumber), current:($cm|tonumber), diff:($sm != $cm)}
  }'
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmd="${1:-help}"; shift || true
  case "$cmd" in
    snapshot_version|diff_version) "$cmd" "$@" ;;
    help|*)
      cat <<EOF
version-snapshot.sh — Snapshot git HEAD + migration count cho BE/FE

USAGE:
  bash version-snapshot.sh snapshot_version <resource> <session_id>
  bash version-snapshot.sh diff_version     <resource> <session_id>

Exit codes (diff_version):
  0 = unchanged
  1 = changed (caller may apply migrations in auto-mode hoac ESCALATE)
  2 = no snapshot
EOF
      ;;
  esac
fi
