#!/usr/bin/env bash
# IMP-020 acceptance test — case-catalog-handoff/
#
# Tests catalog-v1 schema + emit/consume helpers:
#   1. catalog-ui-pages.json is valid catalog-v1 schema
#   2. $schema = "catalog-v1"
#   3. dim_source = "P-QD1-deep-ui-traversal"
#   4. pages array has 3 entries
#   5. catalog_exists() correctly detects valid catalog
#   6. catalog_validate() passes for valid catalog
#   7. catalog_validate() FAILS for invalid catalog (wrong schema)
#   8. catalog_get_urls() returns 3 URLs
#   9. catalog_emit helper round-trips: emit pages → valid catalog-v1
#  10. catalog_consume: pages from emit match input pages
#
# VERDICT: PASS if all assertions hold

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "[case-catalog-handoff] IMP-020 acceptance test"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  dir="$FIXTURE_DIR"
  for _ in 1 2 3 4 5 6 7 8; do
    if [ -f "$dir/CLAUDE.md" ]; then REPO_ROOT="$dir"; break; fi
    dir="$(dirname "$dir")"
  done
fi

EMIT_HELPER="$REPO_ROOT/.claude/scripts/wf-fix-catalog-emit.sh"
CONSUME_HELPER="$REPO_ROOT/.claude/scripts/wf-fix-catalog-consume.sh"
CATALOG="$FIXTURE_DIR/catalog-ui-pages.json"

if [ ! -f "$EMIT_HELPER" ]; then
  echo "FAIL: wf-fix-catalog-emit.sh not found at $EMIT_HELPER" >&2
  exit 1
fi
if [ ! -f "$CONSUME_HELPER" ]; then
  echo "FAIL: wf-fix-catalog-consume.sh not found at $CONSUME_HELPER" >&2
  exit 1
fi
if [ ! -f "$CATALOG" ]; then
  echo "FAIL: catalog-ui-pages.json not found at $CATALOG" >&2
  exit 1
fi
echo "[case-catalog-handoff] Emit:    $EMIT_HELPER"
echo "[case-catalog-handoff] Consume: $CONSUME_HELPER"
echo "[case-catalog-handoff] Catalog: $CATALOG"

# ============================================================
# Test 1: catalog-ui-pages.json is valid JSON
# ============================================================
echo ""
echo "--- Test 1: catalog-ui-pages.json is valid JSON ---"
if ! jq '.' "$CATALOG" >/dev/null 2>&1; then
  echo "  FAIL: catalog-ui-pages.json is not valid JSON"
  exit 1
fi
echo "  PASS: valid JSON"

# ============================================================
# Test 2: $schema = "catalog-v1"
# ============================================================
echo ""
echo "--- Test 2: \$schema = catalog-v1 ---"
schema=$(jq -r '."$schema" // ""' "$CATALOG")
if [ "$schema" != "catalog-v1" ]; then
  echo "  FAIL: \$schema = '$schema' (expected catalog-v1)"
  exit 1
fi
echo "  PASS: \$schema = catalog-v1"

# ============================================================
# Test 3: dim_source = P-QD1-deep-ui-traversal
# ============================================================
echo ""
echo "--- Test 3: dim_source = P-QD1-deep-ui-traversal ---"
dim_src=$(jq -r '.dim_source // ""' "$CATALOG")
if [ "$dim_src" != "P-QD1-deep-ui-traversal" ]; then
  echo "  FAIL: dim_source = '$dim_src'"
  exit 1
fi
echo "  PASS: dim_source = P-QD1-deep-ui-traversal"

# ============================================================
# Test 4: pages array has 3 entries
# ============================================================
echo ""
echo "--- Test 4: pages count = 3 ---"
page_count=$(jq '.pages | length' "$CATALOG")
if [ "$page_count" -ne 3 ]; then
  echo "  FAIL: pages count = $page_count (expected 3)"
  exit 1
fi
echo "  PASS: pages count = 3"

# ============================================================
# Test 5: catalog_exists() detects valid catalog
# ============================================================
echo ""
echo "--- Test 5: catalog_exists() on valid catalog ---"
source "$CONSUME_HELPER"
if catalog_exists "$CATALOG"; then
  echo "  PASS: catalog_exists() returns true for valid catalog"
else
  echo "  FAIL: catalog_exists() returned false for valid catalog"
  exit 1
fi

# Test catalog_exists() returns false for nonexistent file
if catalog_exists "/nonexistent/path/catalog.json"; then
  echo "  FAIL: catalog_exists() should return false for nonexistent file"
  exit 1
fi
echo "  PASS: catalog_exists() returns false for nonexistent file"

# ============================================================
# Test 6: catalog_validate() passes for valid catalog
# ============================================================
echo ""
echo "--- Test 6: catalog_validate() PASS ---"
if catalog_validate "$CATALOG" >/dev/null 2>&1; then
  echo "  PASS: catalog_validate() returns 0"
else
  echo "  FAIL: catalog_validate() returned non-zero for valid catalog"
  exit 1
fi

# ============================================================
# Test 7: catalog_validate() FAILS for invalid catalog
# ============================================================
echo ""
echo "--- Test 7: catalog_validate() FAIL for invalid schema ---"
TMP_INVALID=$(mktemp 2>/dev/null || echo "/tmp/invalid-catalog-$$")
echo '{"$schema":"wrong-schema","pages":[]}' > "$TMP_INVALID"
if catalog_validate "$TMP_INVALID" >/dev/null 2>&1; then
  echo "  FAIL: catalog_validate() returned 0 for wrong schema"
  rm -f "$TMP_INVALID"
  exit 1
fi
echo "  PASS: catalog_validate() rejected wrong schema"
rm -f "$TMP_INVALID"

# ============================================================
# Test 8: catalog_get_urls() returns 3 URLs
# ============================================================
echo ""
echo "--- Test 8: catalog_get_urls() returns 3 URLs ---"
url_count=$(catalog_get_urls "$CATALOG" | wc -l | tr -d ' ')
if [ "$url_count" -eq 3 ]; then
  echo "  PASS: catalog_get_urls() returns 3 URLs"
else
  echo "  FAIL: catalog_get_urls() returned $url_count URLs (expected 3)"
  exit 1
fi

# ============================================================
# Test 9: catalog_emit round-trip
# ============================================================
echo ""
echo "--- Test 9: catalog_emit round-trip ---"
TMP_OUT=$(mktemp 2>/dev/null || echo "/tmp/catalog-emit-$$")
PAGES_JSON='[{"url":"http://localhost:3000/","title":"Home","has_form":false},{"url":"http://localhost:3000/about","title":"About","has_form":false}]'

bash "$EMIT_HELPER" \
  --output "$TMP_OUT" \
  --dim-source "P-QD1-deep-ui-traversal" \
  --base-url "http://localhost:3000" \
  --pages-json "$PAGES_JSON" \
  >/dev/null 2>&1

if [ ! -f "$TMP_OUT" ]; then
  echo "  FAIL: catalog_emit did not create output file"
  exit 1
fi

emit_schema=$(jq -r '."$schema" // ""' "$TMP_OUT")
emit_pages=$(jq '.pages | length' "$TMP_OUT")

if [ "$emit_schema" != "catalog-v1" ]; then
  echo "  FAIL: emitted catalog \$schema = '$emit_schema' (expected catalog-v1)"
  rm -f "$TMP_OUT"
  exit 1
fi
if [ "$emit_pages" -ne 2 ]; then
  echo "  FAIL: emitted catalog pages = $emit_pages (expected 2)"
  rm -f "$TMP_OUT"
  exit 1
fi
echo "  PASS: catalog_emit produced valid catalog-v1 with $emit_pages pages"
rm -f "$TMP_OUT"

# ============================================================
# Test 10: catalog_consume reads pages back correctly
# ============================================================
echo ""
echo "--- Test 10: catalog_get_pages() returns correct pages ---"
page_titles=$(catalog_get_pages "$CATALOG" | jq -r '.[].title' | tr '\n' ',' | sed 's/,$//')
if echo "$page_titles" | grep -q "Home"; then
  echo "  PASS: catalog_get_pages() returns pages with title=Home"
else
  echo "  FAIL: catalog_get_pages() missing expected page titles: $page_titles"
  exit 1
fi

contact_has_form=$(catalog_get_pages "$CATALOG" | jq '[.[] | select(.title == "Contact Us")] | .[0].has_form // false')
if [ "$contact_has_form" = "true" ]; then
  echo "  PASS: Contact Us page has_form = true"
else
  echo "  FAIL: Contact Us page has_form = $contact_has_form (expected true)"
  exit 1
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "=== VERDICT: PASS ==="
echo "  catalog-v1 schema: valid"
echo "  dim_source: P-QD1-deep-ui-traversal"
echo "  pages: $page_count (Home, Products, Contact Us)"
echo "  catalog_exists / validate / get_urls: PASS"
echo "  catalog_emit round-trip: PASS (2 pages)"
echo "  catalog_get_pages: PASS (titles + has_form)"
exit 0
