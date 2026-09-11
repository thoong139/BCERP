#!/usr/bin/env bash
# =============================================================================
# verify-lane-prompt.sh — Phase 4 Step 4.5a (Pre-Dispatch Verify — v10.6)
# =============================================================================
# 6 check points BẮT BUỘC trên rendered lane agent prompt — fantasy-prompt guard
# (v10.2 critical). PHẢI giữ semantics 6 checks; chỉ delegate execution.
#
# Cách dùng (orchestrator):
#   1. Render prompt vào temp file: $TMP_PROMPT
#   2. bash .claude/scripts/wf-fix-bugs/verify-lane-prompt.sh "$TMP_PROMPT"
#   3. Exit code: 0 = PASS, ≠0 = FAIL (mã = check failed)
#
# Required arg:
#   $1 — path tới file chứa rendered prompt
#
# Exit codes:
#   0 — PASS tất cả 6 checks
#   1 — C1 FAIL: missing/wrong role declaration
#   2 — C2 FAIL: unresolved {{...}} placeholder
#   3 — C3 FAIL: missing BƯỚC section
#   4 — C4 FAIL: missing shared protocol reference
#   5 — C5 FAIL: forbidden output name OR missing signals.json
#   6 — C6 FAIL: English role text detected
#   10 — Invalid arg
#
# Stdout:
#   PASS message hoặc FAIL detail (cho orchestrator log)
#
# Compatibility: Git Bash + WSL.
# =============================================================================

set -eu

PROMPT_FILE="${1:-}"

if [ -z "$PROMPT_FILE" ] || [ ! -f "$PROMPT_FILE" ]; then
  echo "ERROR: Usage: $0 <path-to-rendered-prompt>" >&2
  exit 10
fi

# C1. Role declaration đúng (tiếng Việt, "lane agent")
if ! grep -qE "^Bạn là lane agent cho dimension Q[0-9D]+" "$PROMPT_FILE"; then
  echo "FAIL C1: missing/wrong role declaration — phải bắt đầu 'Bạn là lane agent cho dimension QD<n>'" >&2
  exit 1
fi

# C2. KHÔNG còn placeholder chưa substitute
if grep -qE '\{\{[A-Z_]+\}\}' "$PROMPT_FILE"; then
  REMAINING=$(grep -oE '\{\{[A-Z_]+\}\}' "$PROMPT_FILE" | sort -u | tr '\n' ' ')
  echo "FAIL C2: unresolved placeholder(s): $REMAINING" >&2
  exit 2
fi

# C3. Đủ 8 BƯỚC (không bỏ section nào)
for n in 1 2 3 4 5 6 7 8; do
  if ! grep -q "^BƯỚC $n " "$PROMPT_FILE"; then
    echo "FAIL C3: missing BƯỚC $n" >&2
    exit 3
  fi
done

# C4. 5 file shared protocol đều được nhắc tới
for f in "/SKILL.md" "_shared/lane/_shared.md" "_shared/lane/pre-gate.md" "_shared/lane/signal-emit.md" "_shared/lane/profile-resolver.md"; do
  if ! grep -q "$f" "$PROMPT_FILE"; then
    echo "FAIL C4: missing reference to $f" >&2
    exit 4
  fi
done

# C5. Output paths đúng — KHÔNG có "findings.json", KHÔNG có "Phase4-lane-report.md"
if ! grep -q "signals.json" "$PROMPT_FILE"; then
  echo "FAIL C5a: missing 'signals.json' reference" >&2
  exit 5
fi
if grep -qE '(findings\.json|Phase4-lane-report\.md)' "$PROMPT_FILE"; then
  echo "FAIL C5b: FORBIDDEN output name detected (findings.json or Phase4-lane-report.md)" >&2
  exit 5
fi

# C6. Tiếng Việt — không có English role marker
if grep -qiE "you are a .*agent|^you are |developer agent" "$PROMPT_FILE"; then
  echo "FAIL C6: English role text detected — prompt PHẢI tiếng Việt (CORE-005)" >&2
  exit 6
fi

echo "PASS: 6/6 check points OK"
exit 0
