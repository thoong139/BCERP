#!/usr/bin/env bash
# Test consumer_hints jq logic from phase6-finalize.md Step 6.5b
# This file written via Write tool (raw, no JSON escape) — same as markdown source.
set -euo pipefail

TESTDIR=$(mktemp -d)
cd "$TESTDIR"

cat > sample-impl.json <<'EOF'
{
  "schema_version": "2.0",
  "feature": {
    "req_id": "REQ-CRM-CUST-001",
    "name": "Quan ly Khach hang",
    "module": "crm/customer"
  },
  "scenario": "new",
  "metrics": {
    "files_created": 3,
    "files_modified": 0,
    "files_created_list": ["src/modules/crm/customer.service.ts", "src/modules/crm/migrations/001_init.sql", "tests/crm/customer.test.ts"],
    "files_modified_list": []
  },
  "consumer_hints": {
    "wf-prepare-deployment": {},
    "wf-fix-bugs": {},
    "wf-verify-sync": {}
  }
}
EOF

cat > sample-decisions.json <<'EOF'
{
  "decisions": [
    {"id": "D-001", "category": "data_modeling", "rule": "soft delete"},
    {"id": "D-002", "category": "breaking", "rule": "API path change"}
  ]
}
EOF

DECISION_IDS_JSON=$(jq -c '[.decisions[]?.id // empty]' sample-decisions.json)
BREAKING_JSON=$(jq -c '[.decisions[]? | select(.category == "breaking" or .is_breaking == true) | .id]' sample-decisions.json)
FILES_CREATED_JSON=$(jq -c '[.metrics.files_created_list[]? // empty]' sample-impl.json)
FILES_MODIFIED_JSON=$(jq -c '[.metrics.files_modified_list[]? // empty]' sample-impl.json)
SCENARIO=$(jq -r '.scenario // "new"' sample-impl.json | tr -d '\r')
case "$SCENARIO" in
  new) STRATEGY="IMPLEMENT_NEW" ;;
  extend|modify) STRATEGY="COMPLETE_EXISTING" ;;
  *) STRATEGY="IMPLEMENT_NEW" ;;
esac

TMP=$(mktemp)
jq \
  --argjson files_created "$FILES_CREATED_JSON" \
  --argjson files_modified "$FILES_MODIFIED_JSON" \
  --argjson decision_ids "$DECISION_IDS_JSON" \
  --argjson breaking "$BREAKING_JSON" \
  --arg strategy "$STRATEGY" \
  --arg session_dir "$TESTDIR/sessions/2026-04-28-x" \
  --arg files_with_req_id "5" \
  '
    ($files_created + $files_modified) as $all_files
    | ([$all_files[] | select(test("\\.(test|spec)\\.[a-z]+$") | not)]) as $changelog_files
    | ([$files_created[] | select(test("\\.(test|spec)\\.[a-z]+$"))]) as $test_files
    | ([$all_files[] | select(test("/migrations/"))] | length > 0) as $needs_migration
    | .consumer_hints["wf-prepare-deployment"] = {
        files_for_changelog: $changelog_files,
        breaking_changes: $breaking,
        migrations_required: $needs_migration,
        feature_summary_vi: (.feature.name // "")
      }
    | .consumer_hints["wf-fix-bugs"] = {
        scope_modules: [(.feature.module // "")] | map(select(. != "")),
        test_files_added: $test_files,
        decision_ids_new: $decision_ids,
        implementation_strategy_used: $strategy
      }
    | .consumer_hints["wf-verify-sync"] = {
        req_ids_completed: [(.feature.req_id // "")] | map(select(. != "")),
        files_with_req_id: ($files_with_req_id | tonumber),
        session_dir: $session_dir
      }
  ' sample-impl.json > "$TMP" && mv "$TMP" sample-impl.json

echo "=== consumer_hints output ==="
jq '.consumer_hints' sample-impl.json

echo ""
echo "=== Verify expected fields ==="

# Test 1: files_for_changelog excludes test files, includes migration
EXPECT_CHANGELOG_LEN=2  # service.ts + migration sql, NOT test
ACTUAL=$(jq '.consumer_hints["wf-prepare-deployment"].files_for_changelog | length' sample-impl.json)
[[ "$ACTUAL" == "$EXPECT_CHANGELOG_LEN" ]] && echo "PASS: files_for_changelog = $ACTUAL (excluded test)" || { echo "FAIL: changelog len=$ACTUAL expected=$EXPECT_CHANGELOG_LEN"; exit 1; }

# Test 2: breaking_changes = ["D-002"]
ACTUAL=$(jq -c '.consumer_hints["wf-prepare-deployment"].breaking_changes' sample-impl.json)
[[ "$ACTUAL" == '["D-002"]' ]] && echo "PASS: breaking_changes = $ACTUAL" || { echo "FAIL: breaking=$ACTUAL"; exit 1; }

# Test 3: migrations_required = true (file path /migrations/)
ACTUAL=$(jq '.consumer_hints["wf-prepare-deployment"].migrations_required' sample-impl.json)
[[ "$ACTUAL" == "true" ]] && echo "PASS: migrations_required = true" || { echo "FAIL: migrations=$ACTUAL"; exit 1; }

# Test 4: scope_modules
ACTUAL=$(jq -c '.consumer_hints["wf-fix-bugs"].scope_modules' sample-impl.json)
[[ "$ACTUAL" == '["crm/customer"]' ]] && echo "PASS: scope_modules = $ACTUAL" || { echo "FAIL: scope=$ACTUAL"; exit 1; }

# Test 5: test_files_added detected
ACTUAL=$(jq '.consumer_hints["wf-fix-bugs"].test_files_added | length' sample-impl.json)
[[ "$ACTUAL" == "1" ]] && echo "PASS: test_files_added = 1" || { echo "FAIL: test_files=$ACTUAL"; exit 1; }

# Test 6: decision_ids_new
ACTUAL=$(jq -c '.consumer_hints["wf-fix-bugs"].decision_ids_new' sample-impl.json)
[[ "$ACTUAL" == '["D-001","D-002"]' ]] && echo "PASS: decision_ids_new = $ACTUAL" || { echo "FAIL: decisions=$ACTUAL"; exit 1; }

# Test 7: implementation_strategy_used
ACTUAL=$(jq -r '.consumer_hints["wf-fix-bugs"].implementation_strategy_used' sample-impl.json)
[[ "$ACTUAL" == "IMPLEMENT_NEW" ]] && echo "PASS: strategy = IMPLEMENT_NEW (scenario=new)" || { echo "FAIL: strategy=$ACTUAL"; exit 1; }

# Test 8: req_ids_completed
ACTUAL=$(jq -c '.consumer_hints["wf-verify-sync"].req_ids_completed' sample-impl.json)
[[ "$ACTUAL" == '["REQ-CRM-CUST-001"]' ]] && echo "PASS: req_ids_completed = $ACTUAL" || { echo "FAIL: req_ids=$ACTUAL"; exit 1; }

echo ""
echo "ALL 8 TESTS PASS"

# Cleanup
rm -rf "$TESTDIR"
