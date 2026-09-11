#!/usr/bin/env bash
# wf-fix-catalog-consume.sh — Consume catalog-v1 JSON for QD5/QD7 skip-crawl logic
#
# LƯU Ý: KHÔNG dùng `set -euo pipefail` vì file này là library (caller `source`).
# Sourced library với `set -e` sẽ làm caller exit ngay khi function trả non-zero (intent là check return code).
#
# IMP-020: QD5 ui-traversal-deep and QD7 device-breakpoint-test source this
# helper to check if a valid catalog exists and skip re-crawling.
#
# USAGE:
#   source wf-fix-catalog-consume.sh
#
#   # Check if catalog exists and is valid
#   if catalog_exists "$SESSION_DIR/lanes/QD1/catalog-ui-pages.json"; then
#     PAGES=$(catalog_get_pages "$SESSION_DIR/lanes/QD1/catalog-ui-pages.json")
#     echo "Using catalog: $(echo "$PAGES" | jq 'length') pages (skip re-crawl)"
#   fi
#
#   # Get page URLs for viewport testing
#   catalog_get_urls "$CATALOG_FILE"  # returns newline-separated URLs

catalog_exists() {
  local catalog_path="$1"
  [[ -f "$catalog_path" ]] || return 1
  jq -e '."$schema" == "catalog-v1" and (.pages | type == "array")' "$catalog_path" >/dev/null 2>&1
}

catalog_get_pages() {
  local catalog_path="$1"
  jq '.pages // []' "$catalog_path" 2>/dev/null || echo "[]"
}

catalog_get_urls() {
  local catalog_path="$1"
  jq -r '.pages[].url // empty' "$catalog_path" 2>/dev/null || true
}

catalog_get_source() {
  local catalog_path="$1"
  jq -r '.dim_source // "unknown"' "$catalog_path" 2>/dev/null || echo "unknown"
}

catalog_page_count() {
  local catalog_path="$1"
  jq '.pages | length' "$catalog_path" 2>/dev/null || echo 0
}

# Validate catalog schema
catalog_validate() {
  local catalog_path="$1"
  if [[ ! -f "$catalog_path" ]]; then
    echo "[catalog-consume] ERROR: catalog not found: $catalog_path" >&2
    return 1
  fi
  if ! jq -e '."$schema" == "catalog-v1"' "$catalog_path" >/dev/null 2>&1; then
    echo "[catalog-consume] ERROR: invalid catalog schema (expected catalog-v1)" >&2
    return 1
  fi
  if ! jq -e '.pages | type == "array"' "$catalog_path" >/dev/null 2>&1; then
    echo "[catalog-consume] ERROR: catalog.pages must be an array" >&2
    return 1
  fi
  local page_count
  page_count=$(catalog_page_count "$catalog_path")
  echo "[catalog-consume] Valid catalog-v1: $page_count pages from $(catalog_get_source "$catalog_path")" >&2
  return 0
}
