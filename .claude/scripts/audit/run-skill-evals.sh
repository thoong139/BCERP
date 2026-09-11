#!/usr/bin/env bash
# run-skill-evals.sh — Lớp 3 of MCV3 Quality Audit
# Behavioral Eval Harness v2 — STUB + LLM JUDGE
#
# v2 adds LLM judge mode để resolve các assertion types mà v1 force-skip.
# Backward-compatible: --mode=stub (default) chạy y hệt v1.
#
# Modes:
#   stub  — v1 behavior: chỉ auto-check 3 types (file_exists/file_content/registry_check),
#           còn lại force-skip với reason "needs-judge". Fast + deterministic, no LLM cost.
#   judge — Với mỗi assertion thuộc {behavior, content_check, output_contains, structure,
#           registry_check} hoặc các assertion v1 đã skip, spawn LLM judge (claude -p) để
#           decide pass/fail/inconclusive dựa trên SKILL.md + _contract.json + assertion text.
#           Có cost guard (--max-judges) và cache (hash(skill+case+type+text)).
#   auto  — Chạy stub trước; assertion nào status=skip thì escalate lên judge. Recommended.
#   real  — v3: Invoke skill thật trong sandbox (claude -p + Write tool), then run assertions on
#           actual artifacts. Requires claude CLI. Sandboxed in .mc-data-eval-real/.
#           Fixture context loaded from fixtures/<skill>/case-N/real-fixture.md.
#
# Judge rationale:
#   Harness KHÔNG invoke skill thật, nên judge đánh giá "design validity": liệu SKILL.md có
#   mô tả behavior thỏa mãn assertion không. Đây là static-design review, không phải runtime
#   verification. v3 (real CLI invocation) mới verify runtime.
#
# v1 scope (vẫn giữ trong stub mode):
#   - Iterate eval cases trong .claude/skills/workflow/wf-*/evals/evals.json
#   - Mỗi case có isolated workspace .mc-data-eval/<skill>/case-<N>/
#   - Optional fixture seed từ .claude/scripts/audit/fixtures/<skill>/case-<N>/
#   - KHÔNG invoke skill thật, KHÔNG sửa .mc-data/ thật
#
# Usage:
#   ./run-skill-evals.sh wf-brainstorm
#   ./run-skill-evals.sh --all
#   ./run-skill-evals.sh --skill=wf-design --case=2
#   ./run-skill-evals.sh --all --keep-workspaces
#   ./run-skill-evals.sh wf-brainstorm --mode=judge
#   ./run-skill-evals.sh --all --mode=auto --max-judges=100
#   ./run-skill-evals.sh --all --mode=auto --clear-judge-cache
#   ./run-skill-evals.sh wf-brainstorm --mode=real          (v3: real claude -p invocation in sandbox)
#   ./run-skill-evals.sh --skill=wf-brainstorm --mode=real --case=4
#
# Output:
#   docs/audit/work/eval-results.json     (machine-readable)
#   docs/audit/reports/eval-results.md    (human report)
#
# Exit codes:
#   0 = harness ran successfully (regardless of pass/fail counts)
#   1 = harness usage/IO error
#   2 = no cases matched filter

set -uo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Setup
# ─────────────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SKILLS_DIR="$REPO_ROOT/.claude/skills/workflow"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
WORKSPACE_ROOT="$REPO_ROOT/.mc-data-eval"
REAL_WORKSPACE_ROOT="$REPO_ROOT/.mc-data-eval-real"
RESULTS_JSON="$REPO_ROOT/docs/audit/work/eval-results.json"
RESULTS_MD="$REPO_ROOT/docs/audit/reports/eval-results.md"

mkdir -p "$(dirname "$RESULTS_JSON")" "$(dirname "$RESULTS_MD")"

# CRLF safety wrapper for jq (Git Bash)
jqr() { jq "$@" | tr -d '\r'; }

# ─────────────────────────────────────────────────────────────────────────────
# Args
# ─────────────────────────────────────────────────────────────────────────────
FILTER_SKILL=""
FILTER_CASE=""
RUN_ALL=0
KEEP_WORKSPACES=0
MODE="stub"                   # stub | judge | auto
MAX_JUDGES=50
JUDGE_MODEL=""                # empty → claude -p default
CLEAR_JUDGE_CACHE=0

for arg in "$@"; do
  case "$arg" in
    --all)                  RUN_ALL=1 ;;
    --skill=*)              FILTER_SKILL="${arg#--skill=}" ;;
    --case=*)               FILTER_CASE="${arg#--case=}" ;;
    --keep-workspaces)      KEEP_WORKSPACES=1 ;;
    --mode=*)               MODE="${arg#--mode=}" ;;
    --max-judges=*)         MAX_JUDGES="${arg#--max-judges=}" ;;
    --judge-model=*)        JUDGE_MODEL="${arg#--judge-model=}" ;;
    --clear-judge-cache)    CLEAR_JUDGE_CACHE=1 ;;
    --skills-dir=*)         SKILLS_DIR="${arg#--skills-dir=}" ;;
    --help|-h)
      sed -n '2,40p' "$0"
      exit 0
      ;;
    --*)
      echo "Unknown flag: $arg" >&2
      exit 1
      ;;
    *)
      # positional → skill name
      FILTER_SKILL="$arg"
      ;;
  esac
done

if [[ $RUN_ALL -eq 0 && -z "$FILTER_SKILL" ]]; then
  echo "Usage: $0 <skill> | --all | --skill=<name> [--case=<id>] [--mode=stub|judge|auto]" >&2
  exit 1
fi

case "$MODE" in
  stub|judge|auto|real) ;;
  *) echo "ERROR: --mode must be stub|judge|auto|real (got: $MODE)" >&2; exit 1 ;;
esac

# Judge cache + counters
JUDGE_CACHE_DIR="$REPO_ROOT/.mc-data-eval/.judge-cache"
mkdir -p "$JUDGE_CACHE_DIR"
if [[ $CLEAR_JUDGE_CACHE -eq 1 ]]; then
  rm -f "$JUDGE_CACHE_DIR"/*.json 2>/dev/null || true
fi
# Counters tracked via log file because call_judge runs in $() subshells where
# parent-scope integer increments are lost. Each call_judge appends one line to
# $JUDGE_LOG with format: "<kind> <latency_ms>".  Kinds: live | cached | budget.
JUDGE_LOG="$(mktemp)"
: > "$JUDGE_LOG"
JUDGES_CALLED=0
JUDGES_CACHED=0
JUDGES_BUDGET_HIT=0
JUDGES_LATENCY_TOTAL_MS=0

# Check claude CLI availability if judge/real mode requested
HAS_CLAUDE_CLI=0
if [[ "$MODE" != "stub" ]]; then
  if command -v claude >/dev/null 2>&1; then
    HAS_CLAUDE_CLI=1
  else
    echo "WARNING: --mode=$MODE requested but 'claude' CLI not found in PATH. Falling back to stub." >&2
    MODE="stub"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Discover skills
# ─────────────────────────────────────────────────────────────────────────────
declare -a SKILLS=()
if [[ $RUN_ALL -eq 1 ]]; then
  for f in "$SKILLS_DIR"/*/evals/evals.json; do
    [[ -f "$f" ]] || continue
    SKILLS+=("$(basename "$(dirname "$(dirname "$f")")")")
  done
else
  if [[ ! -f "$SKILLS_DIR/$FILTER_SKILL/evals/evals.json" ]]; then
    echo "ERROR: $SKILLS_DIR/$FILTER_SKILL/evals/evals.json not found" >&2
    exit 2
  fi
  SKILLS+=("$FILTER_SKILL")
fi

# ─────────────────────────────────────────────────────────────────────────────
# Helpers — assertion classification + checking
# ─────────────────────────────────────────────────────────────────────────────

# Extract first .mc-data/... path from text. Empty if none.
extract_path() {
  local text="$1"
  # Match .mc-data/... paths (workflow skill outputs)
  local path
  path=$(echo "$text" | grep -oE '\.mc-data[-a-zA-Z0-9/_\.]+\.(md|json|sh|sql|yaml|yml|ts|tsx|js|jsx)' | head -1)
  if [[ -n "$path" ]]; then echo "$path"; return; fi
  # Match docs/audit/... paths (audit-devkit outputs)
  echo "$text" | grep -oE 'docs/audit[-a-zA-Z0-9/_\.]+\.(md|json)' | head -1
}

# Extract section headings ('## ...' or "## ...") from text. One per line.
extract_sections() {
  local text="$1"
  # Match '## ...' or "## ..." up to next ' or "
  echo "$text" | grep -oE "['\"]## [^'\"]+['\"]" | sed -E "s/^['\"](.*)['\"]$/\1/"
}

# Run a single assertion → echoes "status|detail"
# status ∈ {pass, fail, skip}
run_assertion() {
  local workspace="$1"
  local atype="$2"
  local atext="$3"

  case "$atype" in
    behavior|output_contains)
      echo "skip|needs-judge ($atype)"
      return
      ;;

    file_exists)
      local path
      path="$(extract_path "$atext")"
      if [[ -z "$path" ]]; then
        echo "skip|cannot-extract-path"
        return
      fi
      # Resolve path: .mc-data/... → workspace-relative; docs/... → repo-root-relative
      local resolved
      if [[ "$path" == .mc-data/* ]]; then
        resolved="$workspace/${path#.mc-data/}"
      else
        resolved="$REPO_ROOT/$path"
      fi
      if [[ -e "$resolved" ]]; then
        echo "pass|$path"
      else
        # For repo-root paths (docs/audit), skip if path may not yet exist (no real run)
        if [[ "$path" != .mc-data/* ]]; then
          echo "skip|repo-path-not-found: $path"
          return
        fi
        # Only FAIL if workspace has fixture files; otherwise SKIP (empty workspace)
        local ws_file_count
        ws_file_count=$(find "$workspace" -type f 2>/dev/null | head -1 | wc -l)
        if [[ $ws_file_count -gt 0 ]]; then
          echo "fail|missing: $path"
        else
          echo "skip|empty-workspace: $path"
        fi
      fi
      ;;

    file_content|content_check|structure)
      local path
      path="$(extract_path "$atext")"
      if [[ -z "$path" ]]; then
        echo "skip|cannot-extract-path"
        return
      fi
      # Resolve path: .mc-data/... → workspace-relative; docs/... → repo-root-relative
      local resolved
      if [[ "$path" == .mc-data/* ]]; then
        resolved="$workspace/${path#.mc-data/}"
      else
        resolved="$REPO_ROOT/$path"
      fi
      if [[ ! -f "$resolved" ]]; then
        # For repo-root paths (docs/audit), skip if not yet created
        if [[ "$path" != .mc-data/* ]]; then
          echo "skip|repo-path-not-found: $path"
          return
        fi
        # Only FAIL if workspace has fixture files; otherwise SKIP
        local ws_file_count
        ws_file_count=$(find "$workspace" -type f 2>/dev/null | head -1 | wc -l)
        if [[ $ws_file_count -gt 0 ]]; then
          echo "fail|file-missing: $path"
        else
          echo "skip|empty-workspace: $path"
        fi
        return
      fi
      # Try section-heading style first
      local sections
      sections="$(extract_sections "$atext")"
      if [[ -n "$sections" ]]; then
        local missing=0 first_miss=""
        while IFS= read -r section; do
          [[ -z "$section" ]] && continue
          if ! grep -Fq "$section" "$resolved" 2>/dev/null; then
            missing=$((missing + 1))
            [[ -z "$first_miss" ]] && first_miss="$section"
          fi
        done <<< "$sections"
        if [[ $missing -eq 0 ]]; then
          echo "pass|all-sections-present"
        else
          echo "fail|$missing section(s) missing (first: $first_miss)"
        fi
      else
        # No structured pattern → mark as needs-judge
        echo "skip|needs-judge (no parseable pattern in text)"
      fi
      ;;

    registry_check)
      local registry="$workspace/docs/_meta/req-registry.json"
      if [[ ! -f "$registry" ]]; then
        # Only FAIL if workspace has fixture files; otherwise SKIP
        local ws_file_count
        ws_file_count=$(find "$workspace" -type f 2>/dev/null | head -1 | wc -l)
        if [[ $ws_file_count -gt 0 ]]; then
          echo "fail|registry-missing"
        else
          echo "skip|empty-workspace: registry"
        fi
        return
      fi
      # Without structured rules, mark needs-judge
      echo "skip|needs-judge (registry assertion text not structured)"
      ;;

    *)
      echo "skip|unknown-type: $atype"
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Judge helpers (v2)
# ─────────────────────────────────────────────────────────────────────────────

# Load trimmed SKILL.md + _contract.json excerpt for a skill (cached per run).
# Echoes combined text; cap total size ~18000 chars to keep judge prompts manageable.
# v3.3: section-level extraction replaces head -c truncation for large skills.
#       Cache key includes assertion text hash for assertion-aware extraction.
declare -A SKILL_CTX_CACHE=()
load_skill_context() {
  local skill="$1" atext="${2:-}"
  local cache_key="${skill}__$(printf '%s' "$atext" | sha256sum 2>/dev/null | awk '{print $1}')"
  if [[ -n "${SKILL_CTX_CACHE[$cache_key]:-}" ]]; then
    printf '%s' "${SKILL_CTX_CACHE[$cache_key]}"
    return
  fi
  local skill_md="$SKILLS_DIR/$skill/SKILL.md"
  local contract="$SKILLS_DIR/$skill/_contract.json"
  local out=""
  if [[ -f "$skill_md" ]]; then
    local skill_size
    skill_size=$(wc -c < "$skill_md" 2>/dev/null || echo 0)
    if [[ $skill_size -le 20000 ]]; then
      out+="=== SKILL.md (full, ${skill_size} bytes) ===
"
      out+="$(cat "$skill_md")"
    else
      out+="=== SKILL.md (section-level extraction from ${skill_size} bytes) ===
"
      out+="$(extract_relevant_sections "$skill_md" "$atext")"
    fi
    out+="
"
  fi
  if [[ -f "$contract" ]]; then
    out+="
=== _contract.json (compact) ===
"
    out+="$(jqr -c '{skill,version,phase,description,registry_scope,outputs}' "$contract" 2>/dev/null || head -c 1500 "$contract")"
    out+="
"
  fi
  # Cap total to 30000 chars (large skills like wf-fix-bugs have Phase 0 > 20K alone)
  out="$(printf '%s' "$out" | head -c 30000)"
  SKILL_CTX_CACHE[$cache_key]="$out"
  printf '%s' "$out"
}

# Extract sections from SKILL.md relevant to an assertion.
# Always includes: frontmatter + Arguments + Phase 0 + Execution Strategy.
# Plus: phase sections referenced in assertion text + adjacent phases (±1).
# Cap: 26000 chars total (v3.4: was 14000 — Phase 0 on large skills exceeds 14K alone).
# v3.3: replaces extract_assertion_supplement with section-level extraction.
extract_relevant_sections() {
  local skill_md="$1" atext="$2"
  local total_cap=26000

  # 1. Extract phase references from assertion text
  local phases=""
  phases=$(printf '%s' "$atext" | grep -oE 'Phase [0-9]+[a-z]*' | sort -u | \
           sed 's/Phase //g' | tr '\n' ' ')

  # 2. Always-include sections (frontmatter + Arguments + Phase 0 + Execution Strategy)
  local always=""
  always=$(awk '
    /^---$/ { fm++; if(fm<=2) { print; next } }
    /^## Arguments/ { inc=1 }
    /^## Phase 0/ { inc=1 }
    /^## Execution/ { inc=1 }
    /^## Phase [0-9]/ && !/^## Phase 0/ { inc=0 }
    /^## / && inc && !/^## Arguments/ && !/^## Phase 0/ && !/^## Execution/ { inc=0 }
    inc { print }
  ' "$skill_md" 2>/dev/null)

  # 3. Phase-specific sections based on assertion references + ±1 adjacent
  local phase_sections=""
  if [[ -n "$phases" ]]; then
    for p in $phases; do
      local base_p="${p%%[a-z]*}"  # Strip letter suffix: "3b" → "3"
      local prev_p=$((base_p - 1))
      local next_p=$((base_p + 1))

      local section
      section=$(awk -v bp="$base_p" -v pp="$prev_p" -v np="$next_p" -v exact="$p" '
        /^## Phase [0-9]/ {
          ph = $0
          gsub(/^## Phase /, "", ph)
          gsub(/[^0-9a-z].*$/, "", ph)
          inc = (ph == exact || ph == bp || ph == pp || ph == np)
        }
        /^## / && !/^## Phase [0-9]/ { inc = 0 }
        inc { print }
      ' "$skill_md" 2>/dev/null)

      phase_sections+="$section
"
    done
  fi

  # 4. Combine + cap
  local combined="${always}

${phase_sections}"
  printf '%s' "$combined" | head -c "$total_cap"
}

# Compute hash key for judge cache.
judge_cache_key() {
  local skill="$1" case_id="$2" atype="$3" atext="$4"
  printf '%s\0%s\0%s\0%s' "$skill" "$case_id" "$atype" "$atext" \
    | sha256sum 2>/dev/null | awk '{print $1}'
}

# Call LLM judge for a single assertion. Echoes "status|detail".
# Uses cache; honors budget; returns skip on budget/error with explicit reason.
call_judge() {
  local skill="$1" case_id="$2" atype="$3" atext="$4"

  local key cache_file
  key=$(judge_cache_key "$skill" "$case_id" "$atype" "$atext")
  cache_file="$JUDGE_CACHE_DIR/$key.json"

  # Cache hit
  if [[ -f "$cache_file" ]]; then
    local v r
    v=$(jqr -r '.verdict // "inconclusive"' "$cache_file" 2>/dev/null)
    r=$(jqr -r '.reason // ""' "$cache_file" 2>/dev/null)
    echo "cached 0" >> "$JUDGE_LOG"
    case "$v" in
      pass)         echo "pass|judge(cached): $r" ;;
      fail)         echo "fail|judge(cached): $r" ;;
      inconclusive) echo "skip|judge(cached,inconclusive): $r" ;;
      *)            echo "skip|judge(cached,invalid)" ;;
    esac
    return
  fi

  # Budget check — count live calls in log (lines starting with "live ")
  local live_so_far
  live_so_far=$(awk '/^live / {c++} END {print c+0}' "$JUDGE_LOG")
  if [[ $live_so_far -ge $MAX_JUDGES ]]; then
    echo "budget 0" >> "$JUDGE_LOG"
    echo "skip|judge-budget-exhausted (max=$MAX_JUDGES)"
    return
  fi

  # Build judge prompt — assertion-aware skill context (section-level extraction for large skills)
  local skill_ctx prompt
  skill_ctx=$(load_skill_context "$skill" "$atext")

  prompt=$(cat <<EOF
You are a strict evaluation judge for a workflow skill named "$skill". Your job is to decide whether an assertion about the skill's behavior/output is satisfied by the skill's DESIGN as documented in its SKILL.md and _contract.json.

ASSERTION
Type: $atype
Text: $atext

SKILL DESIGN EVIDENCE
$skill_ctx

RUBRIC
- pass: The SKILL.md/contract clearly specifies behavior/outputs that would satisfy the assertion if the skill runs correctly. Direct textual evidence exists.
- fail: The SKILL.md/contract clearly contradicts the assertion, specifies something incompatible, or explicitly excludes it.
- inconclusive: Evidence is ambiguous, missing, or the assertion requires runtime state the design cannot prove.

Be strict. Prefer "inconclusive" over an uncertain pass/fail. Keep reason under 200 chars. No markdown, no prose — output EXACTLY one line of JSON.

OUTPUT (strict single-line JSON, no code fence):
{"verdict":"pass","reason":"...","confidence":0.0}
EOF
)

  # Call claude -p with timeout
  local t0 t1 raw model_flag=""
  [[ -n "$JUDGE_MODEL" ]] && model_flag="--model $JUDGE_MODEL"
  t0=$(date +%s%3N 2>/dev/null || date +%s)
  # shellcheck disable=SC2086
  raw=$(printf '%s' "$prompt" | timeout 90 claude -p $model_flag 2>/dev/null || true)
  t1=$(date +%s%3N 2>/dev/null || date +%s)
  local dur=$((t1 - t0))
  echo "live $dur" >> "$JUDGE_LOG"

  if [[ -z "$raw" ]]; then
    echo "skip|judge-empty-response"
    return
  fi

  # Extract JSON line — handle nested braces in reason field
  local json
  # Try strict single-line match first (no nested braces)
  json=$(printf '%s' "$raw" | grep -oE '\{[^{}]*"verdict"[^{}]*\}' | head -1)
  if [[ -z "$json" ]]; then
    # Fallback: extract from first { to matching } allowing nested quotes
    json=$(printf '%s' "$raw" | python3 -c "
import sys, re, json
raw = sys.stdin.read()
# Find first JSON object with 'verdict' key
for m in re.finditer(r'\{[^{}]*\}', raw):
    try:
        obj = json.loads(m.group())
        if 'verdict' in obj:
            print(json.dumps(obj, ensure_ascii=False))
            break
    except: pass
else:
    # Try greedy match for objects with nested content in reason
    depth = 0; start = None
    for i, ch in enumerate(raw):
        if ch == '{':
            if depth == 0: start = i
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0 and start is not None:
                candidate = raw[start:i+1]
                try:
                    obj = json.loads(candidate)
                    if 'verdict' in obj:
                        print(json.dumps(obj, ensure_ascii=False))
                        break
                except: pass
                start = None
" 2>/dev/null)
  fi
  if [[ -z "$json" ]]; then
    echo "skip|judge-unparseable: $(printf '%s' "$raw" | head -c 80 | tr '\n' ' ')"
    return
  fi

  local verdict reason
  verdict=$(printf '%s' "$json" | jqr -r '.verdict // "inconclusive"' 2>/dev/null)
  reason=$(printf '%s' "$json"  | jqr -r '.reason // ""' 2>/dev/null)
  [[ -z "$verdict" ]] && verdict="inconclusive"

  # Write cache
  printf '%s' "$json" > "$cache_file"

  case "$verdict" in
    pass)         echo "pass|judge: $reason" ;;
    fail)         echo "fail|judge: $reason" ;;
    inconclusive) echo "skip|judge-inconclusive: $reason" ;;
    *)            echo "skip|judge-invalid-verdict: $verdict" ;;
  esac
}

# Wrapper: run stub assertion, then escalate to judge based on mode.
evaluate_assertion() {
  local workspace="$1" atype="$2" atext="$3" skill="$4" case_id="$5"

  local stub_result stub_status
  stub_result=$(run_assertion "$workspace" "$atype" "$atext")
  stub_status="${stub_result%%|*}"

  case "$MODE" in
    stub)
      echo "$stub_result"
      ;;
    auto)
      if [[ "$stub_status" == "skip" ]]; then
        call_judge "$skill" "$case_id" "$atype" "$atext"
      else
        echo "$stub_result"
      fi
      ;;
    judge)
      # Judge-first for types that typically need semantic understanding;
      # keep stub results for deterministic file_exists (cheap ground truth).
      if [[ "$atype" == "file_exists" && "$stub_status" != "skip" ]]; then
        echo "$stub_result"
      else
        call_judge "$skill" "$case_id" "$atype" "$atext"
      fi
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Real-run helpers (v3 / --mode=real)
# ─────────────────────────────────────────────────────────────────────────────

# Build a condensed execution prompt for headless skill simulation.
# Feeds SKILL.md output spec + fixture context → Claude creates files via Write tool.
# v3.2: When fixture has "Files to Create" section, skip SKILL.md excerpt to reduce prompt size.
build_exec_prompt() {
  local skill="$1" case_prompt="$2" fixture_content="$3"

  # v3.2: Only include SKILL.md excerpt if fixture doesn't have explicit file list
  local skill_excerpt=""
  if ! printf '%s' "$fixture_content" | grep -q "Files to Create"; then
    local skill_md="$SKILLS_DIR/$skill/SKILL.md"
    if [[ -f "$skill_md" ]]; then
      skill_excerpt=$(awk '/^## Output Files/,/^---/' "$skill_md" 2>/dev/null | head -c 1500 || true)
      if [[ -z "$skill_excerpt" ]]; then
        skill_excerpt=$(head -c 1500 "$skill_md")
      fi
    fi
  fi

  local output_spec_block=""
  if [[ -n "$skill_excerpt" ]]; then
    output_spec_block="### Output Specification (from SKILL.md)
$skill_excerpt"
  fi

  cat <<ENDPROMPT
# Headless Skill Execution: /$skill

You are Claude Code executing a workflow skill in headless (non-interactive) mode.
All interactive phases are pre-completed. Your sole task is to create ALL required output files using the Write tool.

## Skill: $skill

$output_spec_block

## Project Context (pre-filled)
$fixture_content

## Instructions
1. Use Write tool to create EVERY file listed in the Output Files tables or Files to Create section above.
2. Use Bash tool for: mkdir -p <dir> before writing if directory doesn't exist.
3. All file paths start with .mc-data/ (relative to current directory).
4. Fill content based on the Project Context above. Generate realistic, complete content — not stubs.
5. Do NOT ask questions — all context is pre-provided.
6. After writing all files, output exactly one summary line:
   CREATED: <comma-separated list of files written>

User request: $case_prompt

Begin creating files now.
ENDPROMPT
}

# Load real-fixture.md for a case. Returns content or empty if not found.
load_real_fixture() {
  local skill="$1" case_id="$2"
  local fixture_file="$FIXTURES_DIR/$skill/case-$case_id/real-fixture.md"
  if [[ -f "$fixture_file" ]]; then
    cat "$fixture_file"
  else
    # Generic fallback fixture
    echo "Project: test project for eval case $case_id. Complexity: STANDARD. Use generic content."
  fi
}

# Invoke skill in sandbox via claude -p. Returns captured stdout.
# sandbox: path to isolated workspace directory (files created at sandbox/.mc-data/...)
run_real_skill_invocation() {
  local sandbox="$1" exec_prompt="$2"
  local raw_output=""

  if [[ $HAS_CLAUDE_CLI -eq 0 ]]; then
    echo "REAL-RUN-SKIP: claude CLI not available"
    return
  fi

  # Run in sandbox directory with tool access, 5 min timeout
  raw_output=$(
    (
      cd "$sandbox" || exit 1
      printf '%s' "$exec_prompt" | timeout 300 claude -p \
        --allowedTools "Write,Read,Bash,Glob" \
        2>&1
    ) || true
  )

  printf '%s' "$raw_output"
}

# Evaluate a single assertion using real-run artifacts.
# workspace: path to $sandbox/.mc-data (or $sandbox if files landed there)
# stdout: captured output from real skill invocation
evaluate_assertion_real() {
  local workspace="$1" atype="$2" atext="$3" skill="$4" case_id="$5" stdout="$6"

  # output_contains: check actual stdout
  if [[ "$atype" == "output_contains" ]]; then
    if [[ -z "$stdout" ]]; then
      echo "skip|real: no stdout captured"
      return
    fi
    # Heuristic: look for slash command suggestions or Vietnamese next-step phrases
    if printf '%s' "$stdout" | grep -qiE '(wf-analyze-requirements|wf-implement|bước tiếp|tiếp theo|/wf-)'; then
      echo "pass|real: stdout contains next-step hint"
    else
      # Call judge with stdout as evidence
      local augmented_text="Assertion: $atext
STDOUT evidence (first 800 chars):
$(printf '%s' "$stdout" | head -c 800)"
      call_judge "$skill" "$case_id" "$atype" "$augmented_text"
    fi
    return
  fi

  # All other types: run stub check on real workspace, then real-content scan, then judge
  local stub_result stub_status
  stub_result=$(run_assertion "$workspace" "$atype" "$atext")
  stub_status="${stub_result%%|*}"

  if [[ "$stub_status" == "skip" ]]; then
    # v3.2: Try real-mode content scanning before falling back to judge
    local real_scan=""
    real_scan=$(real_content_scan "$workspace" "$atype" "$atext")
    if [[ -n "$real_scan" ]]; then
      echo "$real_scan"
    else
      call_judge "$skill" "$case_id" "$atype" "$atext"
    fi
  else
    echo "$stub_result"
  fi
}

# v3.2: Scan real workspace files for assertion patterns.
# Returns "pass|..." or "fail|..." or "" (empty = unable to determine, fall back to judge).
real_content_scan() {
  local workspace="$1" atype="$2" atext="$3"

  # Only scan if workspace has files
  local file_count
  file_count=$(find "$workspace" -type f -name "*.md" -o -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$file_count" -eq 0 ]]; then
    return
  fi

  local atext_lower
  atext_lower=$(printf '%s' "$atext" | tr '[:upper:]' '[:lower:]')

  # Pattern 1: FEAT-ID format check (e.g., "FEAT-IDs dung format FEAT-CRM-[MOD]-NNN")
  if printf '%s' "$atext_lower" | grep -qE 'feat-?ids?.*(format|prefix)|format.*feat-?ids?|prefix.*feat'; then
    # Extract expected prefixes from assertion (e.g., FEAT-CRM, FEAT-WMS, FEAT-WEB, FEAT-MOB)
    local feat_prefixes=""
    feat_prefixes=$(printf '%s' "$atext" | grep -oE 'FEAT-[A-Z]+' | sort -u)
    if [[ -n "$feat_prefixes" ]]; then
      local all_found=1 prefix_count=0
      while IFS= read -r feat_prefix; do
        [[ -z "$feat_prefix" ]] && continue
        prefix_count=$((prefix_count + 1))
        # Check for files with FEAT- prefix in filename (in phase2-features/ only)
        local feat_count
        feat_count=$(find "$workspace" -path "*/phase2-features/*" -type f -name "${feat_prefix}*" 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$feat_count" -eq 0 ]]; then
          # Also check content in phase2-features/ files only
          feat_count=$(find "$workspace" -path "*/phase2-features/*" -type f -exec grep -l -- "$feat_prefix" {} \; 2>/dev/null | wc -l | tr -d ' ')
        fi
        if [[ "$feat_count" -eq 0 ]]; then
          all_found=0
        fi
      done <<< "$feat_prefixes"
      if [[ $all_found -eq 1 && $prefix_count -gt 0 ]]; then
        echo "pass|real-scan: all FEAT-ID prefixes found in output files"
        return
      elif [[ $prefix_count -gt 0 ]]; then
        echo "fail|real-scan: some FEAT-ID prefixes not found in output files"
        return
      fi
    fi
  fi

  # Pattern 2: Section presence check (e.g., "Moi feature spec co section Phan Quyen")
  if printf '%s' "$atext_lower" | grep -qE 'section|co (du )?[0-9]+ section'; then
    # Extract section name(s) — use English keywords which appear in both assertion and file
    local sections_raw=""
    sections_raw=$(printf '%s' "$atext" | grep -oEi '(User Stories|Business Rules|Permissions|Mô tả|Mo ta|Luồng Người Dùng)' | sort -u)
    if [[ -z "$sections_raw" ]]; then
      # Fallback: match on key English/Vietnamese words present in headings
      sections_raw=$(printf '%s' "$atext" | grep -oEi '(Stories|Rules|Permissions|Quyen|Nghiep|User|Business)' | sort -u)
    fi
    if [[ -n "$sections_raw" ]]; then
      local missing=0
      local md_files
      md_files=$(find "$workspace" -type f -name "*.md" ! -name "stakeholder-review.md" 2>/dev/null | head -20)
      if [[ -z "$md_files" ]]; then
        return  # no feature spec files to check
      fi
      while IFS= read -r section; do
        [[ -z "$section" ]] && continue
        local files_with_section=0
        # Search for the extracted section keyword
        while IFS= read -r f; do
          [[ -z "$f" ]] && continue
          # Check for exact match, or Vietnamese equivalent mapping
          if grep -qi -- "$section" "$f" 2>/dev/null; then
            files_with_section=$((files_with_section + 1))
          # Vietnamese equivalent mappings for common section names
          elif printf '%s' "$section" | grep -qi "permissions" && grep -qiE 'Ph.n Quy.n|phan quyen' "$f" 2>/dev/null; then
            files_with_section=$((files_with_section + 1))
          elif printf '%s' "$section" | grep -qi "business rules" && grep -qiE 'Quy.Tac|Nghiep.Vu|quy.*tac.*nghiep' "$f" 2>/dev/null; then
            files_with_section=$((files_with_section + 1))
          elif printf '%s' "$section" | grep -qi "user stories" && grep -qiE 'Lu.ng.*Ngu.i|L.ng.Ng.i|luong nguoi dung' "$f" 2>/dev/null; then
            files_with_section=$((files_with_section + 1))
          fi
        done <<< "$md_files"
        if [[ "$files_with_section" -eq 0 ]]; then
          missing=$((missing + 1))
        fi
      done <<< "$sections_raw"
      if [[ $missing -eq 0 ]]; then
        echo "pass|real-scan: all sections found in feature specs"
        return
      fi
    fi
  fi

  # Pattern 3: REQ-ID mapping check (e.g., "Tat ca 5 REQ-IDs duoc map")
  if printf '%s' "$atext_lower" | grep -qE 'req-?ids?.*map|tat ca.*req|map.*req-?ids?'; then
    local req_count
    req_count=$(grep -rohE 'REQ-[A-Z]+-[0-9]+' "$workspace" 2>/dev/null | sort -u | wc -l | tr -d ' ')
    # Extract expected count from assertion
    local expected_count
    expected_count=$(printf '%s' "$atext" | grep -oE '[0-9]+' | head -1)
    if [[ -n "$expected_count" && "$req_count" -ge "$expected_count" ]]; then
      echo "pass|real-scan: found $req_count unique REQ-IDs (expected >= $expected_count)"
      return
    elif [[ -n "$expected_count" && "$req_count" -lt "$expected_count" ]]; then
      echo "fail|real-scan: found $req_count unique REQ-IDs (expected >= $expected_count)"
      return
    fi
  fi

  # Pattern 4: YAML front-matter absence (e.g., "Khong co YAML front-matter")
  # v3.2 fix: only check first 3 lines of each file (not mid-file --- separators)
  if printf '%s' "$atext_lower" | grep -qE 'khong co yaml|no yaml|front-matter'; then
    local yaml_count=0
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      # Check if first line is "---" (YAML front-matter starts with --- on line 1)
      if head -1 "$f" 2>/dev/null | grep -qx '---'; then
        yaml_count=$((yaml_count + 1))
      fi
    done < <(find "$workspace" -type f -name "*.md" 2>/dev/null)
    if [[ "$yaml_count" -eq 0 ]]; then
      echo "pass|real-scan: no YAML front-matter found in any .md file"
      return
    else
      echo "fail|real-scan: YAML front-matter found in $yaml_count .md files"
      return
    fi
  fi

  # Pattern 5: features[] count check (e.g., "features[] co >= 3 entries")
  if printf '%s' "$atext_lower" | grep -qE 'features\[\].*>=|features.*entries'; then
    local registry="$workspace/docs/_meta/req-registry.json"
    if [[ -f "$registry" ]]; then
      local feat_entries
      feat_entries=$(jqr '.features // [] | length' "$registry" 2>/dev/null | tr -d ' ')
      local expected_min
      expected_min=$(printf '%s' "$atext" | grep -oE '[0-9]+' | head -1)
      if [[ -n "$expected_min" && -n "$feat_entries" && "$feat_entries" -ge "$expected_min" ]]; then
        echo "pass|real-scan: features[] has $feat_entries entries (>= $expected_min)"
        return
      fi
    fi
  fi

  # Pattern 6: Business rules content (e.g., "FIFO, khong am kho, duyet phieu")
  if printf '%s' "$atext_lower" | grep -qE 'business rules|quy tac.*phan anh|rules.*include|phan anh'; then
    # Extract keywords after the last colon in the assertion
    local keywords=""
    keywords=$(printf '%s' "$atext" | awk -F': ' '{print $NF}' | xargs)
    if [[ -z "$keywords" ]]; then
      keywords=$(printf '%s' "$atext" | sed -E 's/.*: *//' | head -1)
    fi
    if [[ -n "$keywords" ]]; then
      # Split by comma and check each keyword
      local found=0 total=0
      IFS=',' read -ra kws <<< "$keywords"
      for kw in "${kws[@]}"; do
        kw=$(printf '%s' "$kw" | xargs)  # trim
        [[ -z "$kw" ]] && continue
        total=$((total + 1))
        if grep -rqil -- "$kw" "$workspace" 2>/dev/null; then
          found=$((found + 1))
        fi
      done
      if [[ $total -gt 0 && $found -eq $total ]]; then
        echo "pass|real-scan: all business rule keywords found ($found/$total)"
        return
      elif [[ $total -gt 0 && $found -gt 0 ]]; then
        echo "fail|real-scan: only $found/$total business rule keywords found"
        return
      fi
    fi
  fi

  # Pattern 7: Cross-system references (e.g., "cross_system", "FEAT-WEB-* va FEAT-MOB-*")
  if printf '%s' "$atext_lower" | grep -qE 'cross.system|lien ket'; then
    # Check if files exist in both systems
    local sys1="" sys2=""
    sys1=$(printf '%s' "$atext" | grep -oE 'FEAT-[A-Z]+' | head -1)
    sys2=$(printf '%s' "$atext" | grep -oE 'FEAT-[A-Z]+' | tail -1)
    if [[ -n "$sys1" && -n "$sys2" && "$sys1" != "$sys2" ]]; then
      local c1 c2
      c1=$(find "$workspace" -type f -name "${sys1}*" 2>/dev/null | wc -l | tr -d ' ')
      c2=$(find "$workspace" -type f -name "${sys2}*" 2>/dev/null | wc -l | tr -d ' ')
      if [[ "$c1" -gt 0 && "$c2" -gt 0 ]]; then
        echo "pass|real-scan: files found for both $sys1 ($c1) and $sys2 ($c2)"
        return
      fi
    fi
  fi

  # Pattern 8: Stakeholder review content check
  if printf '%s' "$atext_lower" | grep -qE 'stakeholder.review'; then
    if find "$workspace" -type f -name "stakeholder-review.md" 2>/dev/null | head -1 | grep -q .; then
      local sr_file
      sr_file=$(find "$workspace" -type f -name "stakeholder-review.md" 2>/dev/null | head -1)
      # Check if the assertion text keywords appear in the file
      local kw
      kw=$(printf '%s' "$atext" | grep -oEi '(cross-system|dependencies|nhan dien)' | head -1)
      if [[ -n "$kw" ]] && grep -qi -- "$kw" "$sr_file" 2>/dev/null; then
        echo "pass|real-scan: stakeholder-review.md contains '$kw'"
        return
      fi
    fi
  fi

  # No pattern matched → return empty (caller falls back to judge)
  return
}

# ─────────────────────────────────────────────────────────────────────────────
# Main loop
# ─────────────────────────────────────────────────────────────────────────────
TMP_RESULTS="$(mktemp)"
trap 'rm -f "$TMP_RESULTS" "$JUDGE_LOG"' EXIT

echo '[]' > "$TMP_RESULTS"

TOTAL_CASES=0
TOTAL_ASSERTIONS=0
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0
START_TIME=$(date +%s)

for skill in "${SKILLS[@]}"; do
  evals_file="$SKILLS_DIR/$skill/evals/evals.json"
  case_count=$(jqr '.evals | length' "$evals_file")

  for ((i=0; i<case_count; i++)); do
    case_id=$(jqr -r ".evals[$i].id" "$evals_file")

    if [[ -n "$FILTER_CASE" && "$case_id" != "$FILTER_CASE" ]]; then
      continue
    fi

    TOTAL_CASES=$((TOTAL_CASES + 1))
    case_start=$(date +%s%3N 2>/dev/null || date +%s)

    # Workspace setup — use safe cleanup (rename + recreate to avoid "device busy" errors)
    if [[ "$MODE" == "real" ]]; then
      workspace="$REAL_WORKSPACE_ROOT/$skill/case-$case_id"
    else
      workspace="$WORKSPACE_ROOT/$skill/case-$case_id"
    fi
    # Safe cleanup: move aside first, then remove (avoids "device busy" on Windows)
    if [[ -d "$workspace" ]]; then
      old_ws="${workspace}._old_$(date +%s)"
      mv "$workspace" "$old_ws" 2>/dev/null || true
      rm -rf "$old_ws" 2>/dev/null &
    fi
    mkdir -p "$workspace"

    # Optional fixture seed — real mode also seeds if fixture has docs/ subdirectory
    fixture="$FIXTURES_DIR/$skill/case-$case_id"
    seeded=0
    if [[ "$MODE" == "real" && -d "$fixture/docs" ]]; then
      # v3.2: Seed upstream docs into sandbox for real mode — reduces claude -p burden
      mkdir -p "$workspace/.mc-data"
      cp -r "$fixture/docs/" "$workspace/.mc-data/docs/"
      seeded=1
    elif [[ "$MODE" != "real" && -d "$fixture" ]]; then
      cp -r "$fixture/." "$workspace/"
      seeded=1
    fi

    # Real-mode: invoke skill in sandbox and capture stdout
    REAL_STDOUT=""
    REAL_WS=""  # workspace for assertions (points to .mc-data inside sandbox)
    if [[ "$MODE" == "real" ]]; then
      case_prompt_text=$(jqr -r ".evals[$i].prompt" "$evals_file")
      fixture_content=$(load_real_fixture "$skill" "$case_id")
      exec_prompt=$(build_exec_prompt "$skill" "$case_prompt_text" "$fixture_content")
      printf "  [%s] case %s — invoking real skill (sandbox: %s)...\n" "$skill" "$case_id" "$workspace"
      REAL_STDOUT=$(run_real_skill_invocation "$workspace" "$exec_prompt")
      # Determine assertion workspace: prefer .mc-data subdir if claude wrote there
      if [[ -d "$workspace/.mc-data" ]]; then
        REAL_WS="$workspace/.mc-data"
      else
        REAL_WS="$workspace"
      fi
      seeded=1
    fi

    # Iterate assertions — tolerate schema drift:
    #   - field name: `assertions` (most) OR `expectations` (wf-preflight)
    #   - item shape: object {type,text} OR plain string (wf-add-scope, wf-plan-modules, wf-preflight)
    a_field=$(jqr -r "if (.evals[$i].assertions // null) then \"assertions\" else \"expectations\" end" "$evals_file")
    a_count=$(jqr ".evals[$i].$a_field // [] | length" "$evals_file")
    case_pass=0; case_fail=0; case_skip=0
    assertion_results='[]'

    for ((j=0; j<a_count; j++)); do
      a_kind=$(jqr -r ".evals[$i].$a_field[$j] | type" "$evals_file")
      if [[ "$a_kind" == "string" ]]; then
        atype="behavior"
        atext=$(jqr -r ".evals[$i].$a_field[$j]" "$evals_file")
      else
        atype=$(jqr -r ".evals[$i].$a_field[$j].type // \"unknown\"" "$evals_file")
        atext=$(jqr -r ".evals[$i].$a_field[$j].text // \"\"" "$evals_file")
      fi

      if [[ "$MODE" == "real" ]]; then
        result=$(evaluate_assertion_real "$REAL_WS" "$atype" "$atext" "$skill" "$case_id" "$REAL_STDOUT")
      else
        result=$(evaluate_assertion "$workspace" "$atype" "$atext" "$skill" "$case_id")
      fi
      status="${result%%|*}"
      detail="${result#*|}"

      case "$status" in
        pass) case_pass=$((case_pass + 1)); TOTAL_PASS=$((TOTAL_PASS + 1)) ;;
        fail) case_fail=$((case_fail + 1)); TOTAL_FAIL=$((TOTAL_FAIL + 1)) ;;
        skip) case_skip=$((case_skip + 1)); TOTAL_SKIP=$((TOTAL_SKIP + 1)) ;;
      esac
      TOTAL_ASSERTIONS=$((TOTAL_ASSERTIONS + 1))

      assertion_results=$(echo "$assertion_results" | jqr \
        --arg type "$atype" \
        --arg text "$atext" \
        --arg status "$status" \
        --arg detail "$detail" \
        '. + [{type: $type, text: $text, status: $status, detail: $detail}]')
    done

    case_end=$(date +%s%3N 2>/dev/null || date +%s)
    duration=$((case_end - case_start))

    # Determine case-level status
    if [[ $case_fail -gt 0 ]]; then
      case_status="fail"
    elif [[ $case_pass -gt 0 ]]; then
      case_status="pass"
    else
      case_status="skip"
    fi

    # Cleanup workspace if pass and not keeping
    if [[ "$case_status" == "pass" && $KEEP_WORKSPACES -eq 0 ]]; then
      rm -rf "$workspace"
    fi

    # Append to results
    cur=$(cat "$TMP_RESULTS")
    echo "$cur" | jqr \
      --arg skill "$skill" \
      --argjson case_id "$(echo "$case_id" | jqr -R 'tonumber? // .')" \
      --arg status "$case_status" \
      --argjson seeded "$seeded" \
      --argjson pass "$case_pass" \
      --argjson fail "$case_fail" \
      --argjson skip "$case_skip" \
      --argjson duration "$duration" \
      --argjson assertions "$assertion_results" \
      '. + [{skill: $skill, case_id: $case_id, status: $status, fixture_seeded: ($seeded == 1), counts: {pass: $pass, fail: $fail, skip: $skip}, duration_ms: $duration, assertions: $assertions}]' \
      > "$TMP_RESULTS"

    # Progress
    printf "  [%s] case %s — %s (pass=%d fail=%d skip=%d)\n" \
      "$skill" "$case_id" "$case_status" "$case_pass" "$case_fail" "$case_skip"
  done
done

END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

# ─────────────────────────────────────────────────────────────────────────────
# Write results JSON
# ─────────────────────────────────────────────────────────────────────────────
results=$(cat "$TMP_RESULTS")

# Aggregate judge counters from the append-only log.
# Use awk everywhere — grep -c exits 1 on zero matches which corrupts capture.
JUDGES_CALLED=$(awk '/^live /   {c++} END {print c+0}' "$JUDGE_LOG")
JUDGES_CACHED=$(awk '/^cached / {c++} END {print c+0}' "$JUDGE_LOG")
JUDGES_BUDGET_HIT=$(awk '/^budget / {c++} END {print c+0}' "$JUDGE_LOG")
JUDGES_LATENCY_TOTAL_MS=$(awk '/^live / { sum += $2 } END { print sum+0 }' "$JUDGE_LOG")
JUDGES_AVG_MS=0
if [[ $JUDGES_CALLED -gt 0 ]]; then
  JUDGES_AVG_MS=$((JUDGES_LATENCY_TOTAL_MS / JUDGES_CALLED))
fi
echo "$results" | jqr \
  --arg generated "$(date -Iseconds 2>/dev/null || date)" \
  --arg mode "$MODE" \
  --argjson total_cases "$TOTAL_CASES" \
  --argjson total_assertions "$TOTAL_ASSERTIONS" \
  --argjson pass "$TOTAL_PASS" \
  --argjson fail "$TOTAL_FAIL" \
  --argjson skip "$TOTAL_SKIP" \
  --argjson duration_s "$TOTAL_DURATION" \
  --argjson judges_called "$JUDGES_CALLED" \
  --argjson judges_cached "$JUDGES_CACHED" \
  --argjson judges_budget "$MAX_JUDGES" \
  --argjson judges_budget_hit "$JUDGES_BUDGET_HIT" \
  --argjson judges_avg_ms "$JUDGES_AVG_MS" \
  '{generated: $generated, harness_version: "v2", mode: $mode, summary: {total_cases: $total_cases, total_assertions: $total_assertions, pass: $pass, fail: $fail, skip: $skip, duration_seconds: $duration_s, judges: {called: $judges_called, cached: $judges_cached, budget: $judges_budget, budget_hit: $judges_budget_hit, avg_latency_ms: $judges_avg_ms}}, results: .}' \
  > "$RESULTS_JSON"

# ─────────────────────────────────────────────────────────────────────────────
# Preserve <!-- MANUAL --> ... <!-- /MANUAL --> blocks from previous MD report
# ─────────────────────────────────────────────────────────────────────────────
PRESERVED_MANUAL=""
if [[ -f "$RESULTS_MD" ]]; then
  PRESERVED_MANUAL=$(awk '
    /<!-- MANUAL -->/        { capture=1 }
    capture                  { print }
    /<!-- \/MANUAL -->/      { capture=0; print "" }
  ' "$RESULTS_MD" 2>/dev/null || true)
fi

# ─────────────────────────────────────────────────────────────────────────────
# Write Markdown report
# ─────────────────────────────────────────────────────────────────────────────
harness_label="v2"
[[ "$MODE" == "real" ]] && harness_label="v3"
{
  echo "# Eval Results — Lớp 3 Behavioral Harness ($harness_label, mode=$MODE)"
  echo
  echo "_Generated: $(date -Iseconds 2>/dev/null || date)_"
  echo "_Harness: \`run-skill-evals.sh\` v2 — mode=\`$MODE\`_"
  echo
  echo "## Summary"
  echo
  echo "| Metric                | Value |"
  echo "|-----------------------|-------|"
  echo "| Cases run             | $TOTAL_CASES |"
  echo "| Assertions evaluated  | $TOTAL_ASSERTIONS |"
  echo "| Pass                  | $TOTAL_PASS |"
  echo "| Fail                  | $TOTAL_FAIL |"
  echo "| Skip (needs-judge)    | $TOTAL_SKIP |"
  echo "| Duration              | ${TOTAL_DURATION}s |"
  echo "| Judge calls (live)    | $JUDGES_CALLED |"
  echo "| Judge calls (cached)  | $JUDGES_CACHED |"
  echo "| Judge budget          | $MAX_JUDGES (hit: $JUDGES_BUDGET_HIT) |"
  echo "| Judge avg latency     | ${JUDGES_AVG_MS}ms |"
  echo
  echo "## Per-skill breakdown"
  echo
  echo "| Skill | Cases | Pass | Fail | Skip |"
  echo "|-------|-------|------|------|------|"
  jqr -r '
    .results
    | group_by(.skill)
    | map({
        skill: .[0].skill,
        cases: length,
        pass: ([.[] | select(.status=="pass")] | length),
        fail: ([.[] | select(.status=="fail")] | length),
        skip: ([.[] | select(.status=="skip")] | length)
      })
    | .[]
    | "| \(.skill) | \(.cases) | \(.pass) | \(.fail) | \(.skip) |"
  ' "$RESULTS_JSON"
  echo
  echo "## Failed cases (top 20)"
  echo
  fail_count=$(jqr '[.results[] | select(.status=="fail")] | length' "$RESULTS_JSON")
  if [[ "$fail_count" == "0" ]]; then
    echo "_(none)_"
  else
    jqr -r '
      .results
      | map(select(.status=="fail"))
      | .[:20]
      | .[]
      | "- **\(.skill)** case \(.case_id) — \(.counts.fail) failed assertion(s)\n  - First failures: " +
        ([.assertions[] | select(.status=="fail") | "  - [\(.type)] \(.detail)"] | .[0:3] | join("\n"))
    ' "$RESULTS_JSON"
  fi
  echo
  echo "## Coverage analysis"
  echo
  echo "v1 STUB harness only auto-checks 5 of 7 assertion types:"
  echo
  echo "| Type | Auto-checkable in v1? |"
  echo "|------|----------------------|"
  echo "| file_exists      | YES |"
  echo "| file_content     | YES (when section/path parseable) |"
  echo "| content_check    | PARTIAL (text often unstructured) |"
  echo "| structure        | PARTIAL |"
  echo "| registry_check   | PARTIAL (needs structured rules) |"
  echo "| behavior         | NO — needs LLM judge or real run |"
  echo "| output_contains  | NO — needs real skill stdout |"
  echo
  echo "## Roadmap"
  echo
  echo "### v2 — LLM judge integration"
  echo
  echo "- Wire \`behavior\` and \`output_contains\` assertions through Claude as judge."
  echo "- Pass: assertion text + relevant workspace files → ask judge \"does this hold?\""
  echo "- Cache judge results by hash(assertion_text + workspace_state) to keep runs cheap."
  echo "- Target: convert ~345 needs-judge assertions to pass/fail."
  echo
  echo "### v3 — Real Claude Code CLI invocation ✓ IMPLEMENTED (Phiên 20)"
  echo
  echo "- Flag \`--mode=real\` invokes \`claude -p --allowedTools Write,Read,Bash,Glob\` in sandbox."
  echo "- Sandbox: \`.mc-data-eval-real/<skill>/case-N/\`; fixture context from \`fixtures/<skill>/case-N/real-fixture.md\`."
  echo "- Captures stdout → checks \`output_contains\` via heuristic + judge; file assertions on actual artifacts."
  echo "- Tested: wf-brainstorm (4 cases, pass=6/22). Extend to: wf-plan-modules, wf-preflight (high-fail skills)."
  echo "- Limitation: behavior assertions about internal agent spawning remain inconclusive (~73% skip for wf-brainstorm)."
  echo
  echo "### CI integration"
  echo
  echo "- v1 stub: run on every PR that touches \`.claude/skills/workflow/**\` (fast, deterministic)."
  echo "- v2 judge: nightly + on PR with skill changes (rate-limited)."
  echo "- v3 real: pre-release gate only (slow + expensive)."
  echo
  echo "## Files"
  echo
  echo "- Harness: [.claude/scripts/audit/run-skill-evals.sh](../../.claude/scripts/audit/run-skill-evals.sh)"
  echo "- Schema: [.claude/scripts/audit/EVAL-SCHEMA.md](../../.claude/scripts/audit/EVAL-SCHEMA.md)"
  echo "- Results JSON: [docs/audit/work/eval-results.json](../work/eval-results.json)"
  echo "- Workspaces (failed only): \`.mc-data-eval/<skill>/case-<id>/\`"
  echo "- Judge cache: \`.mc-data-eval/.judge-cache/\`"
  if [[ -n "$PRESERVED_MANUAL" ]]; then
    echo
    echo "## Manual notes (preserved from prior run)"
    echo
    printf '%s\n' "$PRESERVED_MANUAL"
  else
    echo
    echo "<!-- MANUAL -->"
    echo "## Manual notes"
    echo
    echo "_Add manual analysis here; wrapped in MANUAL comments so regenerate won't wipe it._"
    echo "<!-- /MANUAL -->"
  fi
} > "$RESULTS_MD"

# ─────────────────────────────────────────────────────────────────────────────
# Console summary
# ─────────────────────────────────────────────────────────────────────────────
echo
echo "Behavioral Eval Harness v2 — complete (mode=$MODE)"
echo "  Cases run:     $TOTAL_CASES"
echo "  Assertions:    $TOTAL_ASSERTIONS (pass=$TOTAL_PASS fail=$TOTAL_FAIL skip=$TOTAL_SKIP)"
echo "  Judges:        called=$JUDGES_CALLED cached=$JUDGES_CACHED budget=$MAX_JUDGES hit=$JUDGES_BUDGET_HIT avg=${JUDGES_AVG_MS}ms"
echo "  Duration:      ${TOTAL_DURATION}s"
echo "  JSON: $RESULTS_JSON"
echo "  MD:   $RESULTS_MD"
