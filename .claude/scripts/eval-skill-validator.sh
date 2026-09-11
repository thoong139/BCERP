#!/usr/bin/env bash
# eval-skill-validator.sh — Structural compliance validator cho MCV3 DEVKIT skills
# Usage: ./eval-skill-validator.sh --all | [skill-name]
# Output: JSON findings report to stdout
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKFLOW_DIR="$SKILLS_ROOT/skills/workflow"
ORCHESTRATOR_DIR="$SKILLS_ROOT/skills/workflows"
SKILLS_TOP="$SKILLS_ROOT/skills"

# Lane skills (use probes/ instead of procedures/, dimension.json, no outputs.docs)
LANE_SKILLS=(wf-fix-functional wf-fix-business wf-fix-security wf-fix-performance wf-fix-ux-a11y wf-fix-data wf-fix-compat)

# Utility skills (no procedures/ required)
UTILITY_SKILLS=(status ui-ux-pro-max)

is_lane_skill() {
  local s="$1" l
  for l in "${LANE_SKILLS[@]}"; do [[ "$l" == "$s" ]] && return 0; done
  return 1
}

is_utility_skill() {
  local s="$1" u
  for u in "${UTILITY_SKILLS[@]}"; do [[ "$u" == "$s" ]] && return 0; done
  return 1
}

# Find skill directory given skill name
find_skill_dir() {
  local name="$1"
  if [[ -d "$WORKFLOW_DIR/$name" ]]; then echo "$WORKFLOW_DIR/$name"; return; fi
  if [[ -d "$ORCHESTRATOR_DIR/$name" ]]; then echo "$ORCHESTRATOR_DIR/$name"; return; fi
  if [[ -d "$SKILLS_TOP/$name" ]]; then echo "$SKILLS_TOP/$name"; return; fi
  echo ""
}

# Validate a single skill — output JSON to temp file
validate_skill() {
  local skill_name="$1"
  local skill_dir
  skill_dir="$(find_skill_dir "$skill_name")"
  local tmpfile="$2"
  local lane=false
  is_lane_skill "$skill_name" && lane=true
  local utility=false
  is_utility_skill "$skill_name" && utility=true

  if [[ -z "$skill_dir" ]]; then
    echo "{\"skill\":\"$skill_name\",\"status\":\"NOT_FOUND\",\"summary\":{\"critical\":1,\"major\":0,\"minor\":0},\"findings\":[{\"check\":\"directory\",\"severity\":\"CRITICAL\",\"message\":\"Skill directory not found\"}]}" > "$tmpfile"
    return
  fi

  local findings="[]"
  local critical_count=0 major_count=0 minor_count=0

  add_finding() {
    local check="$1" severity="$2" message="$3"
    findings="$(echo "$findings" | jq -c --arg c "$check" --arg s "$severity" --arg m "$message" \
      '. += [{"check":$c,"severity":$s,"message":$m}]')"
    case "$severity" in
      CRITICAL) ((critical_count++)) || true ;;
      MAJOR)    ((major_count++))    || true ;;
      MINOR)    ((minor_count++))    || true ;;
    esac
  }

  # ──── 1. SKILL.md ────
  if [[ ! -f "$skill_dir/SKILL.md" ]]; then
    add_finding "skill_md" "CRITICAL" "SKILL.md not found"
  elif [[ ! -s "$skill_dir/SKILL.md" ]]; then
    add_finding "skill_md" "CRITICAL" "SKILL.md is empty (0 bytes)"
  fi

  # ──── 2. _contract.json ────
  local contract="$skill_dir/_contract.json"
  local contract_data=""
  if [[ ! -f "$contract" ]]; then
    add_finding "contract" "CRITICAL" "_contract.json not found"
  elif [[ ! -s "$contract" ]]; then
    add_finding "contract" "CRITICAL" "_contract.json is empty"
  else
    if ! contract_data="$(jq '.' "$contract" 2>/dev/null)"; then
      add_finding "contract" "CRITICAL" "_contract.json is not valid JSON"
    else
      # $schema
      local schema
      schema="$(echo "$contract_data" | jq -r '.["$schema"] // empty')"
      if [[ -z "$schema" ]]; then
        add_finding "contract_schema" "MAJOR" "Missing \$schema field"
      elif [[ "$schema" != "skill-contract-v1" ]]; then
        add_finding "contract_schema" "MAJOR" "\$schema='$schema' (expected 'skill-contract-v1')"
      fi

      # Required fields (skip procedure for lane skills — uses different structure)
      for field in skill version phase description outputs registry_scope; do
        local val
        val="$(echo "$contract_data" | jq -r ".$field // empty")"
        if [[ -z "$val" || "$val" == "null" ]]; then
          add_finding "contract_field" "MAJOR" "Missing required field: $field"
        fi
      done
      # procedure required for non-lane, non-utility
      if [[ "$lane" == false && "$utility" == false ]]; then
        local proc_val
        proc_val="$(echo "$contract_data" | jq -r '.procedure // empty')"
        if [[ -z "$proc_val" || "$proc_val" == "null" ]]; then
          add_finding "contract_field" "MAJOR" "Missing required field: procedure"
        fi
      fi

      # outputs.docs — required for non-lane skills
      if [[ "$lane" == false ]]; then
        if [[ "$(echo "$contract_data" | jq '.outputs | has("docs")')" != "true" ]]; then
          add_finding "contract_outputs" "MAJOR" "outputs missing 'docs' array"
        fi
      fi
      # outputs.working — required for all
      if [[ "$(echo "$contract_data" | jq '.outputs | has("working")')" != "true" ]]; then
        add_finding "contract_outputs" "MAJOR" "outputs missing 'working' array"
      fi

      # registry_scope.fields_owned type
      local fo_type
      fo_type="$(echo "$contract_data" | jq -r '.registry_scope.fields_owned | type' 2>/dev/null || echo 'missing')"
      if [[ "$fo_type" != "array" && "$fo_type" != "missing" ]]; then
        add_finding "contract_registry" "MAJOR" "registry_scope.fields_owned is $fo_type (expected array)"
      fi

      # cross_skill_contracts
      if [[ "$(echo "$contract_data" | jq 'has("cross_skill_contracts")')" == "true" ]]; then
        if [[ "$(echo "$contract_data" | jq '.cross_skill_contracts | has("produces_for")')" != "true" ]]; then
          add_finding "contract_cross" "MINOR" "cross_skill_contracts missing produces_for"
        fi
        if [[ "$(echo "$contract_data" | jq '.cross_skill_contracts | has("consumes_from")')" != "true" ]]; then
          add_finding "contract_cross" "MINOR" "cross_skill_contracts missing consumes_from"
        fi
      fi

      # Template reference resolution (strip \r for Windows)
      local tpl_refs
      tpl_refs="$(echo "$contract_data" | jq -r '[[.outputs.docs[] // [], .outputs.working[] // []] | .[] | .template // empty] | map(select(. != null and . != "")) | .[]' 2>/dev/null | tr -d '\r' || true)"
      while IFS= read -r tpl; do
        tpl="$(echo "$tpl" | tr -d '\r')"
        [[ -z "$tpl" ]] && continue
        if [[ ! -f "$skill_dir/$tpl" && ! -f "$SKILLS_ROOT/doc-framework/$tpl" ]]; then
          add_finding "template_ref" "MINOR" "Template not resolved: $tpl"
        fi
      done <<< "$tpl_refs"

      # Procedure / probe files validation
      local proc_type
      proc_type="$(echo "$contract_data" | jq -r '.procedure | type' 2>/dev/null || echo 'missing')"
      if [[ "$proc_type" == "string" ]]; then
        # Standard: procedure is a single entry point
        local proc_entry
        proc_entry="$(echo "$contract_data" | jq -r '.procedure // empty' | tr -d '\r')"
        if [[ -n "$proc_entry" && ! -f "$skill_dir/$proc_entry" ]]; then
          add_finding "procedure_entry" "MAJOR" "Procedure entry not found: $proc_entry"
        fi
        # Check procedure_files array
        local pf_count
        pf_count="$(echo "$contract_data" | jq '.procedure_files | length' 2>/dev/null || echo 0)"
        if [[ "$pf_count" -gt 0 ]]; then
          local pf_missing=0
          for ((i=0; i<pf_count; i++)); do
            local pf
            pf="$(echo "$contract_data" | jq -r ".procedure_files[$i]" | tr -d '\r')"
            [[ ! -f "$skill_dir/$pf" ]] && ((pf_missing++)) || true
          done
          [[ $pf_missing -gt 0 ]] && add_finding "procedure_files" "MAJOR" "$pf_missing/$pf_count procedure_files not found on disk"
        fi
      elif [[ "$proc_type" == "array" ]]; then
        # Lane: procedure is array of probe files
        local arr_len
        arr_len="$(echo "$contract_data" | jq '.procedure | length')"
        local arr_missing=0
        for ((i=0; i<arr_len; i++)); do
          local pf
          pf="$(echo "$contract_data" | jq -r ".procedure[$i]" | tr -d '\r')"
          [[ ! -f "$skill_dir/$pf" ]] && ((arr_missing++)) || true
        done
        [[ $arr_missing -gt 0 ]] && add_finding "procedure_files" "MAJOR" "$arr_missing/$arr_len procedure/probe files not found on disk"
      fi
    fi
  fi

  # ──── 3. evals/evals.json ────
  local evals_file="$skill_dir/evals/evals.json"
  if [[ ! -f "$evals_file" ]]; then
    add_finding "evals" "CRITICAL" "evals/evals.json not found"
  elif [[ ! -s "$evals_file" ]]; then
    add_finding "evals" "CRITICAL" "evals/evals.json is empty"
  else
    local evals_data
    if ! evals_data="$(jq '.' "$evals_file" 2>/dev/null)"; then
      add_finding "evals" "CRITICAL" "evals/evals.json is not valid JSON"
    else
      local evals_type
      evals_type="$(echo "$evals_data" | jq -r 'type')"
      if [[ "$evals_type" == "array" ]]; then
        add_finding "evals_format" "MAJOR" "Root is array (expected object with skill_name + evals)"
        local arr_count
        arr_count="$(echo "$evals_data" | jq 'length')"
        if [[ $arr_count -lt 3 ]]; then
          add_finding "evals_count" "MAJOR" "Has $arr_count evals (needs >= 3)"
        fi
      elif [[ "$evals_type" == "object" ]]; then
        local eval_key="" eval_count=0
        if [[ "$(echo "$evals_data" | jq 'has("evals")')" == "true" ]]; then
          eval_key="evals"
          eval_count="$(echo "$evals_data" | jq '.evals | length')"
        elif [[ "$(echo "$evals_data" | jq 'has("test_cases")')" == "true" ]]; then
          eval_key="test_cases"
          eval_count="$(echo "$evals_data" | jq '.test_cases | length')"
        fi
        if [[ -z "$eval_key" ]]; then
          add_finding "evals_format" "MAJOR" "No 'evals' or 'test_cases' array found"
        elif [[ $eval_count -lt 3 ]]; then
          add_finding "evals_count" "MAJOR" "Has $eval_count entries in $eval_key (needs >= 3)"
        fi
      fi
    fi
  fi

  # ──── 4. procedures/ or probes/ directory ────
  if [[ "$utility" == false ]]; then
    if [[ "$lane" == true ]]; then
      # Lane skills use probes/
      if [[ ! -d "$skill_dir/probes" ]]; then
        add_finding "probes_dir" "MAJOR" "Lane skill missing probes/ directory"
      fi
    else
      # Standard skills use procedures/
      if [[ ! -d "$skill_dir/procedures" ]]; then
        add_finding "procedures_dir" "MAJOR" "procedures/ directory not found"
      fi
    fi
  fi

  # ──── 5. dimension.json for lane skills ────
  if [[ "$lane" == true ]]; then
    if [[ ! -f "$skill_dir/dimension.json" ]]; then
      add_finding "dimension" "MAJOR" "Lane skill missing dimension.json"
    elif ! jq '.' "$skill_dir/dimension.json" >/dev/null 2>&1; then
      add_finding "dimension" "MAJOR" "dimension.json is not valid JSON"
    fi
  fi

  # ──── 6. Naming convention ────
  if [[ ! "$skill_name" =~ ^[a-z][a-z0-9-]*$ ]]; then
    add_finding "naming" "MINOR" "Not lowercase-kebab-case: $skill_name"
  fi

  # ──── Build result ────
  local status="PASS"
  [[ $critical_count -gt 0 ]] && status="FAIL"

  jq -n \
    --arg name "$skill_name" \
    --arg dir "$skill_dir" \
    --arg status "$status" \
    --argjson findings "$findings" \
    --argjson crit "$critical_count" \
    --argjson maj "$major_count" \
    --argjson min "$minor_count" \
    '{skill:$name, directory:$dir, status:$status, summary:{critical:$crit, major:$maj, minor:$min}, findings:$findings}' \
    > "$tmpfile"
}

# ──── Main ────
SKILLS=()

if [[ "${1:-}" == "--all" ]]; then
  while IFS= read -r d; do
    bn="$(basename "$d")"
    [[ "$bn" == "_shared" ]] && continue
    SKILLS+=("$bn")
  done < <(find "$WORKFLOW_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)

  while IFS= read -r d; do
    SKILLS+=("$(basename "$d")")
  done < <(find "$ORCHESTRATOR_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)

  for d in "$SKILLS_TOP"/*/; do
    bn="$(basename "$d")"
    [[ -d "$WORKFLOW_DIR/$bn" || -d "$ORCHESTRATOR_DIR/$bn" ]] && continue
    [[ -f "$d/SKILL.md" ]] && SKILLS+=("$bn")
  done
elif [[ -n "${1:-}" ]]; then
  SKILLS+=("$1")
else
  echo "Usage: $0 --all | [skill-name]" >&2
  exit 1
fi

# Temp dir for results
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

idx=0
for s in "${SKILLS[@]}"; do
  validate_skill "$s" "$TMPDIR/$idx.json"
  ((idx++)) || true
done

# Merge all results + compute summary
jq -s '{
  timestamp: (now | todate),
  total_skills: length,
  summary: {
    total: length,
    pass: [.[] | select(.status=="PASS")] | length,
    fail: [.[] | select(.status=="FAIL")] | length,
    not_found: [.[] | select(.status=="NOT_FOUND")] | length,
    total_critical: [.[] | .summary.critical] | add,
    total_major: [.[] | .summary.major] | add,
    total_minor: [.[] | .summary.minor] | add
  },
  skills: [.[] | {skill, status, summary, findings}]
}' "$TMPDIR"/*.json
