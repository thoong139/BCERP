#!/bin/bash
# ============================================
# Hook: pre-bash-safety.sh
# Purpose: Block dangerous bash commands
# Trigger: PreToolUse (Bash)
# ============================================

set -euo pipefail

# ============================================
# DEPENDENCY CHECK
# ============================================

if ! command -v jq &> /dev/null; then
  # Without jq, we can't parse input safely - allow command
  exit 0
fi

# ============================================
# INPUT PARSING
# ============================================

# Read JSON input from stdin
INPUT=$(cat)

# Extract command
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

# Exit if no command
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Normalize command for checking
COMMAND_LOWER=$(echo "$COMMAND" | tr '[:upper:]' '[:lower:]')

# ============================================
# DANGEROUS PATTERNS - BLOCK
# ============================================

# Patterns that will BLOCK execution
BLOCK_PATTERNS=(
  # Filesystem destruction
  # NOTE (Finding #27, 2026-04-28): Patterns dưới phải PRECISE — chỉ match đúng destructive
  # target (root /, /* literal, ~ alone, $HOME alone). Pattern lỏng "rm -rf /" sẽ substring-match
  # cả `rm -rf /tmp/foo`; pattern "rm -rf /*" trong ERE = `rm -rf ` + 0+ slashes → match mọi
  # `rm -rf <anything>`. Dùng anchors `([[:space:]]|$)` để giới hạn về root scope thật sự.
  '(^|[[:space:]])rm[[:space:]]+-rf?[[:space:]]+/([[:space:]]|$)'
  '(^|[[:space:]])rm[[:space:]]+-rf?[[:space:]]+/\*([[:space:]]|$)'
  '(^|[[:space:]])rm[[:space:]]+-rf?[[:space:]]+~([[:space:]]|$)'
  '(^|[[:space:]])rm[[:space:]]+-rf?[[:space:]]+\$home([[:space:]]|$)'
  '(^|[[:space:]])rm[[:space:]]+-rf?[[:space:]]+\$\(pwd\)([[:space:]]|$)'
  "mkfs"
  "dd if=/dev/zero"
  "dd if=/dev/urandom"
  "> /dev/sda"
  "> /dev/hda"

  # Git force push to main/master
  "git push --force origin main"
  "git push --force origin master"
  "git push -f origin main"
  "git push -f origin master"
  "git push --force-with-lease origin main"
  "git push --force-with-lease origin master"

  # Database destruction
  "drop database"
  "drop table"
  "truncate table"
  "delete from"
  "drop schema"

  # Credential exposure
  # Match assignment patterns only (PASSWORD=value, SECRET=value), not feature/file names mentioning the word.
  "export[[:space:]]+[a-z_]*(password|secret|api_key|token|access_key|private_key)[[:space:]]*="
  # echo of credentials: only flag when value-style assignment or env var dump appears.
  "echo[[:space:]]+[\"']?\\\$(password|secret|api_key|token|access_key|private_key)[\"']?"
  "echo[[:space:]]+[\"'][^\"']*(password|secret|api_key|token)[[:space:]]*=[[:space:]]*[a-z0-9]"

  # Network attacks (pipe to shell)
  "curl.*[|].*sh"
  "wget.*[|].*sh"
  "curl.*[|].*bash"
  "wget.*[|].*bash"

  # Privilege escalation
  '(^|[[:space:]])chmod[[:space:]]+777[[:space:]]+/([[:space:]]|$)'
  '(^|[[:space:]])chmod[[:space:]]+-r[[:space:]]+777[[:space:]]+/([[:space:]]|$)'
  "chown.*-R.*root.*/"
)

for pattern in "${BLOCK_PATTERNS[@]}"; do
  if echo "$COMMAND_LOWER" | grep -qiE "$pattern"; then
    echo "" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "🚫 DEVKIT Safety: BLOCKED Dangerous Command" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    echo "Command: $COMMAND" >&2
    echo "" >&2
    echo "This command matches a dangerous pattern: $pattern" >&2
    echo "" >&2
    echo "If you really need to run this command:" >&2
    echo "1. Verify this is a legitimate operation" >&2
    echo "2. Run directly in terminal (outside DEVKIT)" >&2
    echo "3. Document the reason for using this command" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2

    # Exit code 2 = Block the tool execution
    exit 2
  fi
done

# ============================================
# WARNING PATTERNS - ALLOW WITH WARNING
# ============================================

WARNING_PATTERNS=(
  # Git operations on main/master
  "git checkout main"
  "git checkout master"
  "git merge main"
  "git merge master"
  "git rebase main"
  "git rebase master"
  "git reset --hard"

  # File deletion
  "rm -rf"
  "rm -r"
  "rmdir"

  # Database operations
  "mysql"
  "psql"
  "mongo"
  "redis-cli"

  # Package managers (global install)
  "npm install -g"
  "yarn global"
  "pip install --user"

  # System commands
  "sudo"
  "su -"
  "chmod"
  "chown"
)

for pattern in "${WARNING_PATTERNS[@]}"; do
  if echo "$COMMAND_LOWER" | grep -qiE "$pattern"; then
    echo "" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "⚠️  DEVKIT Safety: Caution - Potentially Risky Command" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2
    echo "Command: $COMMAND" >&2
    echo "" >&2
    echo "This command may have side effects. Please verify:" >&2
    echo "- You are in the correct directory" >&2
    echo "- This is the intended action" >&2
    echo "- You have necessary backups" >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "" >&2

    # Allow to proceed, just warning
    exit 0
  fi
done

# ============================================
# EXIT CODES
# 0 = Success, continue
# 2 = Block action
# ============================================
exit 0
