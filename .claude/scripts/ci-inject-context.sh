#!/usr/bin/env bash
# =============================================================================
# ci-inject-context.sh — Generate CI context snippet for agent prompts
# =============================================================================
# Protocol 20 implementation: agent context injection (D5 injection-only).
# 4 templates: Both-OK, Both-Stale, GitNexus-only, Serena-only.
# Each template < 600 chars (Both-Stale may be slightly larger with warning).
#
# Output: CI context text (stdout) — Markdown, ready for agent prompt injection
# Exit: 0 (context generated) | 1 (no CI tools available)
#
# Compatibility: Git Bash + WSL. Pure bash, no arithmetic required here.
# =============================================================================

set -euo pipefail 2>/dev/null || set -eu  # Graceful for bash < 4.4

CACHE_FILE=".mc-data/work/_meta/code-intelligence.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ ! -f "$CACHE_FILE" ]]; then
  exit 1
fi

GITNEXUS=$(jq -r '.gitnexus.available // false' "$CACHE_FILE" 2>/dev/null || echo "false")
SERENA=$(jq -r '.serena.available // false' "$CACHE_FILE" 2>/dev/null || echo "false")

# ── Get freshness status ──
# Exit codes 0-3 are legitimate JSON responses; only >3 or empty = true failure
set +e
FRESHNESS_JSON=$("$SCRIPT_DIR/ci-freshness-check.sh" 2>/dev/null)
FRESH_CHECK_EXIT=$?
set -e
if [[ $FRESH_CHECK_EXIT -gt 3 ]] || [[ -z "$FRESHNESS_JSON" ]]; then
  FRESHNESS_JSON='{"status":"skipped"}'
fi
FRESHNESS_STATUS=$(echo "$FRESHNESS_JSON" | jq -r '.status // "skipped"')
FRESHNESS_BEHIND=$(echo "$FRESHNESS_JSON" | jq -r '.behind // 0')
FRESHNESS_LEVEL=$(echo "$FRESHNESS_JSON" | jq -r '.level // "none"')

# ── Build freshness warning (chỉ cho GitNexus — Serena real-time) ──
FRESHNESS_WARNING=""
if [[ "$FRESHNESS_STATUS" == "warning" ]] && [[ "$GITNEXUS" == "true" ]]; then
  if [[ "$FRESHNESS_LEVEL" == "severe" ]]; then
    FRESHNESS_WARNING="WARNING: GitNexus index is $FRESHNESS_BEHIND commits behind HEAD. Impact analysis WILL BE INCOMPLETE. Strongly recommend: gitnexus analyze"
  elif [[ "$FRESHNESS_LEVEL" == "strong" ]]; then
    FRESHNESS_WARNING="WARNING: GitNexus index is $FRESHNESS_BEHIND commits behind HEAD. Impact analysis may be incomplete. Consider: gitnexus analyze"
  else
    FRESHNESS_WARNING="WARNING: GitNexus index is $FRESHNESS_BEHIND commits behind HEAD. Impact analysis may miss recent changes."
  fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# Template Selection
# ══════════════════════════════════════════════════════════════════════════════

if [[ "$GITNEXUS" == "true" ]] && [[ "$SERENA" == "true" ]]; then
  REPO=$(jq -r '.gitnexus.repo // "?"' "$CACHE_FILE")
  SYMBOLS=$(jq -r '.gitnexus.symbols // "?"' "$CACHE_FILE")
  FLOWS=$(jq -r '.gitnexus.execution_flows // "?"' "$CACHE_FILE")

  if [[ -z "$FRESHNESS_WARNING" ]]; then
    # Template: Both-OK (~810 chars)
    # Lists specific tool names (impact/query/detect_changes for GitNexus,
    # find_symbol/find_references for Serena) so downstream agents can route
    # tasks correctly. Mirrors the specificity of Templates 3 & 4.
    cat <<TEMPLATE
## Code Intelligence: GitNexus + Serena

Both GitNexus (graph: $REPO, $SYMBOLS symbols, $FLOWS flows) and Serena (LSP) are available.

Routing guideline:
- System-level → GitNexus: impact({target}), query({concept}), route_map(), context({symbol})
- Symbol-level → Serena: find_symbol, find_references, get_symbols_overview
- Refactor → Serena rename_symbol (NEVER find-and-replace)
- Pre-commit → GitNexus detect_changes()
TEMPLATE
  else
    # Template: Both-Stale (~910 chars with warning)
    cat <<TEMPLATE
## Code Intelligence: GitNexus + Serena

Both GitNexus (graph: $REPO, $SYMBOLS symbols, $FLOWS flows) and Serena (LSP) are available.

Routing guideline:
- System-level → GitNexus: impact({target}), query({concept}), route_map(), context({symbol})
- Symbol-level → Serena: find_symbol, find_references, get_symbols_overview (real-time, unaffected by index)
- Refactor → Serena rename_symbol (NEVER find-and-replace)
- Pre-commit → GitNexus detect_changes()

$FRESHNESS_WARNING
TEMPLATE
  fi

elif [[ "$GITNEXUS" == "true" ]]; then
  REPO=$(jq -r '.gitnexus.repo // "?"' "$CACHE_FILE")
  SYMBOLS=$(jq -r '.gitnexus.symbols // "?"' "$CACHE_FILE")
  FLOWS=$(jq -r '.gitnexus.execution_flows // "?"' "$CACHE_FILE")

  # Template: GitNexus-only (~430 chars without warning, ~550 with)
  cat <<TEMPLATE
## Code Intelligence: GitNexus

GitNexus is available ($REPO, $SYMBOLS symbols, $FLOWS flows).
- Before editing any symbol → gitnexus_impact({target, direction: "upstream"})
- Exploring code → gitnexus_query({query: "concept"})
- Pre-commit → gitnexus_detect_changes()
- NEVER rename with find-and-replace — use gitnexus_rename
TEMPLATE

  if [[ -n "$FRESHNESS_WARNING" ]]; then
    echo "$FRESHNESS_WARNING"
  fi

elif [[ "$SERENA" == "true" ]]; then
  # Template: Serena-only (~280 chars)
  cat <<TEMPLATE
## Code Intelligence: Serena

Serena LSP tools are available (real-time, always current).
- find_definition → precise go-to-definition
- find_references → all call sites
- rename_symbol → safe refactoring (not find-and-replace)
- get_symbols_overview → file structure
TEMPLATE

else
  exit 1
fi
