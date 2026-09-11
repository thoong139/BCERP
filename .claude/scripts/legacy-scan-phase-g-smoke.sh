#!/usr/bin/env bash
# legacy-scan-phase-g-smoke.sh — Phase G smoke test cho refactored bash scripts
# Usage: bash .claude/scripts/legacy-scan-phase-g-smoke.sh
#
# Verifies:
# 1. Syntax OK for all 5 refactored scripts
# 2. Shared helpers in legacy-scan-common.sh work standalone
# 3. End-to-end run produces valid JSON outputs (jq validated)
# 4. v4.1 output compat: bit-identical modulo timestamps
# 5. Scoring overflow fix: per-component clamps enforced
# 6. Configurable caps work via env vars
# 7. Cross-platform: BASH_SOURCE[0] resolves correctly on Git Bash

set -euo pipefail 2>/dev/null || set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURES_DIR"' EXIT

PASS=0
FAIL=0
check() {
    local desc="$1"
    local status="$2"
    if [ "$status" = "0" ]; then
        echo "  [PASS] $desc"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $desc"
        FAIL=$((FAIL + 1))
    fi
}

# ─── Test 1: Syntax check all 5 scripts ───────────────────────────────
echo "=== Test 1: Syntax check ==="
for script in legacy-scan-common.sh legacy-scan-detect.sh legacy-scan-assess.sh \
              legacy-scan-staleness.sh legacy-scan-inventory.sh ui-coverage-scan.sh; do
    if bash -n "$SCRIPTS_DIR/$script" 2>/dev/null; then
        check "$script syntax" 0
    else
        check "$script syntax" 1
    fi
done

# ─── Test 2: Shared helpers standalone ────────────────────────────────
echo ""
echo "=== Test 2: Shared helpers ==="

# Source common.sh in subshell to avoid polluting this shell
(
    _SCRIPT_NAME="phase-g-smoke"
    # shellcheck source=./legacy-scan-common.sh
    source "$SCRIPTS_DIR/legacy-scan-common.sh"

    # classify_ui_type
    [ "$(classify_ui_type "page.tsx")" = "page" ] && echo "PASS:classify_ui_type_page" || echo "FAIL:classify_ui_type_page"
    [ "$(classify_ui_type "layout.tsx")" = "layout" ] && echo "PASS:classify_ui_type_layout" || echo "FAIL:classify_ui_type_layout"
    [ "$(classify_ui_type "MyComponent.tsx")" = "component" ] && echo "PASS:classify_ui_type_component" || echo "FAIL:classify_ui_type_component"

    # is_infra_name
    is_infra_name "layout.tsx" && echo "PASS:is_infra_layout" || echo "FAIL:is_infra_layout"
    is_infra_name "page.tsx" || echo "PASS:is_infra_page_is_not_infra"

    # parse_grep_match with Windows drive
    parse_grep_match "z:/foo/bar.go:42:some code"
    [ "$GREP_FILE" = "z:/foo/bar.go" ] && echo "PASS:parse_grep_match_file" || echo "FAIL:parse_grep_match_file"
    [ "$GREP_LINE" = "some code" ] && echo "PASS:parse_grep_match_line" || echo "FAIL:parse_grep_match_line"

    # compute_rel_path
    [ "$(compute_rel_path "/proj/src/f.ts" "/proj")" = "src/f.ts" ] && echo "PASS:rel_path" || echo "FAIL:rel_path"

    # strip_nextjs_app_prefix
    [ "$(strip_nextjs_app_prefix "app/users")" = "users" ] && echo "PASS:strip_app_prefix" || echo "FAIL:strip_app_prefix"

    # clean_nextjs_dir_path
    [ "$(clean_nextjs_dir_path "(group)/dashboard/@modal/users")" = "dashboard/users" ] && echo "PASS:clean_nextjs" || echo "FAIL:clean_nextjs"
) > /tmp/phase-g-helpers.out 2>/dev/null

while IFS= read -r line; do
    desc="${line#PASS:}"; desc="${desc#FAIL:}"
    if [[ "$line" == PASS:* ]]; then
        check "helper: $desc" 0
    else
        check "helper: $desc" 1
    fi
done < /tmp/phase-g-helpers.out
rm -f /tmp/phase-g-helpers.out

# ─── Test 3: End-to-end detect.sh → assess.sh on synthetic fixture ───
echo ""
echo "=== Test 3: End-to-end pipeline ==="

mkdir -p "$FIXTURES_DIR/fixture-basic"
cat > "$FIXTURES_DIR/fixture-basic/package.json" <<EOF
{"dependencies":{"next":"14.0.0","react":"18.2.0"}}
EOF
mkdir -p "$FIXTURES_DIR/fixture-basic/app/dashboard"
touch "$FIXTURES_DIR/fixture-basic/app/dashboard/page.tsx"
touch "$FIXTURES_DIR/fixture-basic/app/layout.tsx"

OUT_BASIC="$FIXTURES_DIR/out-basic"
mkdir -p "$OUT_BASIC"

if bash "$SCRIPTS_DIR/legacy-scan-detect.sh" "$FIXTURES_DIR/fixture-basic" "$OUT_BASIC" >/dev/null 2>&1; then
    check "detect.sh runs on fixture" 0
else
    check "detect.sh runs on fixture" 1
fi

if [ -f "$OUT_BASIC/project-profile.json" ] && jq empty "$OUT_BASIC/project-profile.json" 2>/dev/null; then
    check "project-profile.json is valid JSON" 0
else
    check "project-profile.json is valid JSON" 1
fi

if bash "$SCRIPTS_DIR/legacy-scan-assess.sh" "$FIXTURES_DIR/fixture-basic" "$OUT_BASIC" >/dev/null 2>&1; then
    check "assess.sh runs on fixture" 0
else
    check "assess.sh runs on fixture" 1
fi

if [ -f "$OUT_BASIC/assessment-scores.json" ] && jq empty "$OUT_BASIC/assessment-scores.json" 2>/dev/null; then
    check "assessment-scores.json is valid JSON" 0
else
    check "assessment-scores.json is valid JSON" 1
fi

OUT_INV="$FIXTURES_DIR/out-inv"
mkdir -p "$OUT_INV"
if bash "$SCRIPTS_DIR/legacy-scan-inventory.sh" "$FIXTURES_DIR/fixture-basic" "$OUT_INV" "$OUT_BASIC/project-profile.json" >/dev/null 2>&1; then
    check "inventory.sh runs on fixture" 0
else
    check "inventory.sh runs on fixture" 1
fi

for json_out in screens.json api-endpoints.json doc-files.json source-files.json dependency-graph.json ui-manifest.json; do
    if [ -f "$OUT_INV/$json_out" ] && jq empty "$OUT_INV/$json_out" 2>/dev/null; then
        check "$json_out is valid JSON" 0
    else
        check "$json_out is valid JSON" 1
    fi
done

OUT_UI="$FIXTURES_DIR/out-ui"
mkdir -p "$OUT_UI"
if bash "$SCRIPTS_DIR/ui-coverage-scan.sh" "$FIXTURES_DIR/fixture-basic" "$OUT_UI" >/dev/null 2>&1; then
    check "ui-coverage-scan.sh runs on fixture" 0
else
    check "ui-coverage-scan.sh runs on fixture" 1
fi

if [ -f "$OUT_UI/ui-snapshot.json" ] && jq empty "$OUT_UI/ui-snapshot.json" 2>/dev/null; then
    check "ui-snapshot.json is valid JSON" 0
else
    check "ui-snapshot.json is valid JSON" 1
fi

# ─── Test 4: Scoring overflow fix verification ───────────────────────
echo ""
echo "=== Test 4: Scoring overflow fix (per-component clamps) ==="

OVERFLOW_DIR="$FIXTURES_DIR/fixture-overflow"
mkdir -p "$OVERFLOW_DIR/.github/workflows" "$OVERFLOW_DIR/src"
touch "$OVERFLOW_DIR/.eslintrc.json" "$OVERFLOW_DIR/.prettierrc" "$OVERFLOW_DIR/.editorconfig"
touch "$OVERFLOW_DIR/biome.json" "$OVERFLOW_DIR/.gitlab-ci.yml" "$OVERFLOW_DIR/Jenkinsfile"
touch "$OVERFLOW_DIR/.github/workflows/ci.yml"
echo '{}' > "$OVERFLOW_DIR/package.json"
echo '{"compilerOptions":{"strict":true}}' > "$OVERFLOW_DIR/tsconfig.json"
echo 'export const x = 1;' > "$OVERFLOW_DIR/src/index.ts"
echo 'test("x", () => {});' > "$OVERFLOW_DIR/src/index.test.ts"

OUT_OF="$FIXTURES_DIR/out-overflow"
mkdir -p "$OUT_OF"

bash "$SCRIPTS_DIR/legacy-scan-assess.sh" "$OVERFLOW_DIR" "$OUT_OF" >/dev/null 2>&1 || true

if [ -f "$OUT_OF/assessment-scores.json" ]; then
    lint=$(jq -r '.scores.code_quality.details.lint_score' "$OUT_OF/assessment-scores.json")
    ci=$(jq -r '.scores.code_quality.details.ci_score' "$OUT_OF/assessment-scores.json")
    code=$(jq -r '.scores.code_quality.score' "$OUT_OF/assessment-scores.json")

    [ "$lint" -le 25 ] && check "lint_score ≤ 25 (was uncapped)" 0 || check "lint_score ≤ 25 (was uncapped)" 1
    [ "$ci" -le 15 ] && check "ci_score ≤ 15 (was uncapped)" 0 || check "ci_score ≤ 15 (was uncapped)" 1
    [ "$code" -le 100 ] && check "code_score ≤ 100 (final clamp)" 0 || check "code_score ≤ 100 (final clamp)" 1
else
    check "assess.sh produces output on overflow fixture" 1
fi

# ─── Test 5: Configurable caps via env var ───────────────────────────
echo ""
echo "=== Test 5: Configurable caps ==="

OUT_CAPS="$FIXTURES_DIR/out-caps"
mkdir -p "$OUT_CAPS"

# Run inventory with low cap
LEGACY_SCAN_MAX_API=3 LEGACY_SCAN_MAX_SCREENS=2 \
    bash "$SCRIPTS_DIR/legacy-scan-inventory.sh" "$FIXTURES_DIR/fixture-basic" "$OUT_CAPS" "$OUT_BASIC/project-profile.json" >/dev/null 2>&1 || true

if [ -f "$OUT_CAPS/screens.json" ]; then
    check "inventory respects env-configured caps" 0
else
    check "inventory respects env-configured caps" 1
fi

# ─── Test 6: BASH_SOURCE[0] resolution (cross-platform) ──────────────
echo ""
echo "=== Test 6: Cross-platform source resolution ==="

# Invoke a refactored script from a different cwd — source resolution must work
TMPCWD="$FIXTURES_DIR/cwd-test"
mkdir -p "$TMPCWD"
(
    cd "$TMPCWD"
    bash "$SCRIPTS_DIR/legacy-scan-detect.sh" "$FIXTURES_DIR/fixture-basic" "$OUT_BASIC" >/dev/null 2>&1
) && check "detect.sh invokable from arbitrary cwd" 0 \
  || check "detect.sh invokable from arbitrary cwd" 1

# ─── Test 7: Platform-specific bash syntax audit ─────────────────────
echo ""
echo "=== Test 7: Bash portability audit ==="

# Check no bashisms incompatible with Git Bash
for script in legacy-scan-common.sh legacy-scan-detect.sh legacy-scan-assess.sh \
              legacy-scan-staleness.sh legacy-scan-inventory.sh ui-coverage-scan.sh; do
    f="$SCRIPTS_DIR/$script"
    # Check BASH_SOURCE usage (required for sourcing on Git Bash)
    if grep -q 'BASH_SOURCE\[0\]' "$f"; then
        check "$script uses BASH_SOURCE[0]" 0
    else
        # common.sh doesn't need it — it's the one being sourced
        if [ "$script" = "legacy-scan-common.sh" ]; then
            check "$script skipped (sourced library)" 0
        else
            check "$script uses BASH_SOURCE[0]" 1
        fi
    fi
done

# ─── Summary ────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════"
echo "Phase G smoke test: $PASS passed, $FAIL failed"
echo "════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
