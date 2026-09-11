#!/usr/bin/env bash
# implement-detect-stack.sh — Detect tech stack (test framework, package manager, language).
# Sprint 1 bash delegation — replace inline detect logic ở Phase 2 step 2.0a (Finding #14 v3.4.0).
#
# Usage:
#   bash implement-detect-stack.sh [--cwd=$PROJECT_ROOT] [--cache=$SESSION_DIR/stack.json]
#
# Args:
#   --cwd=<path>    Project root (default: current dir)
#   --cache=<path>  If set + cache file fresh (mtime ≤ 1h) → return cached JSON
#
# Output (stdout): JSON
#   {
#     "test_framework": "jest|vitest|mocha|pytest|xunit|go-testing|cargo-test|junit|null",
#     "package_manager": "pnpm|npm|yarn|bun|pip|poetry|nuget|go-modules|cargo|maven|gradle|null",
#     "language": "typescript|javascript|python|csharp|go|rust|java|null",
#     "project_type": "monorepo|single-app|library|null",
#     "node_version": "20.x" | null,
#     "detected_at": "2026-04-28T03:58:35Z"
#   }
#
# Exit codes:
#   0 = detected (or cached)
#   1 = no project files found

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=implement-common.sh
source "$SCRIPTS_DIR/implement-common.sh"
_SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"

CWD="."
CACHE=""
for arg in "$@"; do
  case "$arg" in
    --cwd=*)   CWD="${arg#*=}" ;;
    --cache=*) CACHE="${arg#*=}" ;;
    *) log_warn "Unknown arg: $arg" ;;
  esac
done

[[ ! -d "$CWD" ]] && { log_error "CWD không tồn tại: $CWD"; exit 1; }

# Check cache (1h TTL — config files rarely change within hour)
if [[ -n "$CACHE" && -f "$CACHE" ]]; then
  if has_jq && jq empty "$CACHE" 2>/dev/null; then
    age_sec=$(( $(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || stat -f %m "$CACHE" 2>/dev/null || echo 0) ))
    if (( age_sec < 3600 )); then
      log_debug "Using cached stack: $CACHE (age=${age_sec}s)"
      cat "$CACHE"
      exit 0
    fi
  fi
fi

cd "$CWD" || exit 1

# ─── Detection logic ─────────────────────────────────────────

TEST_FRAMEWORK="null"
PACKAGE_MANAGER="null"
LANGUAGE="null"
PROJECT_TYPE="null"
NODE_VERSION="null"

# 1. Node/JS/TS detection (package.json)
if [[ -f "package.json" ]]; then
  LANGUAGE="javascript"
  if has_jq; then
    # TypeScript?
    if jq -e '.devDependencies.typescript // .dependencies.typescript // empty' package.json &>/dev/null; then
      LANGUAGE="typescript"
    fi
    # Test framework — order ưu tiên: vitest > jest > mocha
    for fw in vitest jest mocha jasmine ava; do
      if jq -e ".devDependencies[\"$fw\"] // .dependencies[\"$fw\"] // empty" package.json &>/dev/null; then
        TEST_FRAMEWORK="$fw"
        break
      fi
    done
    # Engines
    NODE_VERSION=$(jq -r '.engines.node // empty' package.json 2>/dev/null)
    [[ -z "$NODE_VERSION" ]] && NODE_VERSION="null"
  else
    # No jq — grep fallback
    grep -q '"typescript"' package.json && LANGUAGE="typescript"
    for fw in vitest jest mocha jasmine ava; do
      if grep -q "\"$fw\"" package.json; then
        TEST_FRAMEWORK="$fw"
        break
      fi
    done
  fi

  # Package manager
  if [[ -f "pnpm-lock.yaml" ]]; then
    PACKAGE_MANAGER="pnpm"
  elif [[ -f "yarn.lock" ]]; then
    PACKAGE_MANAGER="yarn"
  elif [[ -f "bun.lockb" || -f "bun.lock" ]]; then
    PACKAGE_MANAGER="bun"
  elif [[ -f "package-lock.json" ]]; then
    PACKAGE_MANAGER="npm"
  else
    PACKAGE_MANAGER="npm"
  fi

  # Monorepo?
  if [[ -d "apps" || -d "packages" ]] || \
     ( has_jq && jq -e '.workspaces // empty' package.json &>/dev/null ) || \
     [[ -f "pnpm-workspace.yaml" || -f "lerna.json" || -f "turbo.json" || -f "nx.json" ]]; then
    PROJECT_TYPE="monorepo"
  else
    PROJECT_TYPE="single-app"
  fi

# 2. Python detection
elif [[ -f "pyproject.toml" || -f "setup.py" || -f "requirements.txt" ]]; then
  LANGUAGE="python"
  if [[ -f "pyproject.toml" ]] && grep -q 'poetry' pyproject.toml 2>/dev/null; then
    PACKAGE_MANAGER="poetry"
  elif [[ -f "Pipfile" ]]; then
    PACKAGE_MANAGER="pipenv"
  else
    PACKAGE_MANAGER="pip"
  fi
  if grep -q 'pytest' pyproject.toml requirements*.txt setup.py 2>/dev/null; then
    TEST_FRAMEWORK="pytest"
  elif grep -q 'unittest' pyproject.toml requirements*.txt setup.py 2>/dev/null; then
    TEST_FRAMEWORK="unittest"
  fi
  PROJECT_TYPE="single-app"

# 3. C# / .NET
elif compgen -G "*.csproj" >/dev/null 2>&1 || compgen -G "*.sln" >/dev/null 2>&1; then
  LANGUAGE="csharp"
  PACKAGE_MANAGER="nuget"
  CS_FILES="$(ls *.csproj *.sln 2>/dev/null)"
  if echo "$CS_FILES" | xargs grep -l 'xunit' 2>/dev/null | head -1 >/dev/null; then
    TEST_FRAMEWORK="xunit"
  elif echo "$CS_FILES" | xargs grep -l 'NUnit' 2>/dev/null | head -1 >/dev/null; then
    TEST_FRAMEWORK="nunit"
  elif echo "$CS_FILES" | xargs grep -l 'MSTest' 2>/dev/null | head -1 >/dev/null; then
    TEST_FRAMEWORK="mstest"
  fi
  PROJECT_TYPE=$(compgen -G "*.sln" >/dev/null 2>&1 && echo "monorepo" || echo "single-app")

# 4. Go
elif [[ -f "go.mod" ]]; then
  LANGUAGE="go"
  PACKAGE_MANAGER="go-modules"
  TEST_FRAMEWORK="go-testing"
  PROJECT_TYPE="single-app"

# 5. Rust
elif [[ -f "Cargo.toml" ]]; then
  LANGUAGE="rust"
  PACKAGE_MANAGER="cargo"
  TEST_FRAMEWORK="cargo-test"
  if [[ -f "Cargo.toml" ]] && grep -q '^\[workspace\]' Cargo.toml 2>/dev/null; then
    PROJECT_TYPE="monorepo"
  else
    PROJECT_TYPE="single-app"
  fi

# 6. Java
elif [[ -f "pom.xml" ]]; then
  LANGUAGE="java"
  PACKAGE_MANAGER="maven"
  if grep -q 'junit-jupiter' pom.xml 2>/dev/null; then
    TEST_FRAMEWORK="junit5"
  elif grep -q 'junit' pom.xml 2>/dev/null; then
    TEST_FRAMEWORK="junit4"
  fi
  PROJECT_TYPE="single-app"
elif [[ -f "build.gradle" || -f "build.gradle.kts" ]]; then
  LANGUAGE="java"
  PACKAGE_MANAGER="gradle"
  if grep -q 'jupiter' build.gradle build.gradle.kts 2>/dev/null; then
    TEST_FRAMEWORK="junit5"
  else
    TEST_FRAMEWORK="junit4"
  fi
  if [[ -f "settings.gradle" || -f "settings.gradle.kts" ]] && grep -q 'include' settings.gradle settings.gradle.kts 2>/dev/null; then
    PROJECT_TYPE="monorepo"
  else
    PROJECT_TYPE="single-app"
  fi

else
  log_warn "Không tìm thấy project files (package.json/pyproject.toml/.csproj/go.mod/Cargo.toml/pom.xml/build.gradle)"
fi

cd - > /dev/null || true

# ─── Build output JSON ───────────────────────────────────────

if has_jq; then
  RESULT=$(jq -nc \
    --arg tf "$TEST_FRAMEWORK" \
    --arg pm "$PACKAGE_MANAGER" \
    --arg lang "$LANGUAGE" \
    --arg pt "$PROJECT_TYPE" \
    --arg nv "$NODE_VERSION" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      test_framework: (if $tf == "null" then null else $tf end),
      package_manager: (if $pm == "null" then null else $pm end),
      language: (if $lang == "null" then null else $lang end),
      project_type: (if $pt == "null" then null else $pt end),
      node_version: (if $nv == "null" then null else $nv end),
      detected_at: $ts
    }')
else
  # Fallback raw JSON
  RESULT=$(printf '{"test_framework":%s,"package_manager":%s,"language":%s,"project_type":%s,"node_version":%s,"detected_at":"%s"}' \
    "$([[ $TEST_FRAMEWORK == null ]] && echo null || echo \"$TEST_FRAMEWORK\")" \
    "$([[ $PACKAGE_MANAGER == null ]] && echo null || echo \"$PACKAGE_MANAGER\")" \
    "$([[ $LANGUAGE == null ]] && echo null || echo \"$LANGUAGE\")" \
    "$([[ $PROJECT_TYPE == null ]] && echo null || echo \"$PROJECT_TYPE\")" \
    "$([[ $NODE_VERSION == null ]] && echo null || echo \"$NODE_VERSION\")" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)")
fi

# Write cache nếu có --cache flag
if [[ -n "$CACHE" ]]; then
  safe_write_json "$CACHE" "$RESULT" || log_warn "Không thể ghi cache: $CACHE"
fi

echo "$RESULT"
exit 0
