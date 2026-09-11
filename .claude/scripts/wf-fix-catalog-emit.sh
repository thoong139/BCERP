#!/usr/bin/env bash
# wf-fix-catalog-emit.sh — Emit catalog-v1 JSON from page/route discovery results
#
# IMP-020: QD1 deep-ui-traversal calls this to produce catalog-ui-pages.json
# so QD5 and QD7 can consume it without re-crawling.
#
# USAGE:
#   source wf-fix-catalog-emit.sh
#   catalog_emit --output <path> --dim-source <probe-id> --base-url <url> \
#                --pages-json '[{"url":"...","title":"..."}]'
#
# Or pipe a pages JSON array to it:
#   echo '[{"url":"/", "title":"Home"}]' | catalog_emit --output catalog.json --dim-source P-QD1-deep-ui-traversal

set -euo pipefail

catalog_emit() {
  local output_path="" dim_source="" base_url="" pages_json=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --output)      output_path="$2"; shift 2 ;;
      --dim-source)  dim_source="$2"; shift 2 ;;
      --base-url)    base_url="$2"; shift 2 ;;
      --pages-json)  pages_json="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  # Read pages from stdin if not provided
  if [[ -z "$pages_json" ]] && [[ ! -t 0 ]]; then
    pages_json=$(cat)
  fi

  # Validate pages JSON is an array
  if ! echo "$pages_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
    echo "[catalog-emit] ERROR: pages_json must be a JSON array" >&2
    return 1
  fi

  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)

  local catalog_json
  catalog_json=$(jq -nc \
    --arg schema  "catalog-v1" \
    --arg now     "$now" \
    --arg src     "${dim_source:-unknown}" \
    --arg url     "${base_url:-}" \
    --argjson pages "${pages_json:-[]}" \
    '{
      "$schema":     $schema,
      generated_at:  $now,
      dim_source:    $src,
      base_url:      $url,
      pages:         $pages
    }')

  if [[ -n "$output_path" ]]; then
    mkdir -p "$(dirname "$output_path")"
    # INT-02 fix: atomic write (tmp + mv) tránh corrupt nếu process bị kill giữa write.
    # Validate JSON trước khi swap → đảm bảo consumer (wf-fix-catalog-consume.sh) luôn đọc valid JSON.
    local tmp_file="${output_path}.tmp.$$.${RANDOM}"
    if ! echo "$catalog_json" | jq -e . > "$tmp_file" 2>/dev/null; then
      rm -f "$tmp_file" 2>/dev/null || true
      echo "[catalog-emit] ERROR: invalid JSON catalog, refusing to write" >&2
      return 1
    fi
    mv "$tmp_file" "$output_path"
    echo "[catalog-emit] Catalog written to: $output_path ($(echo "$pages_json" | jq 'length') pages)" >&2
  else
    echo "$catalog_json"
  fi
}

# Run if called directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  catalog_emit "$@"
fi
