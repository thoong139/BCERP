#!/bin/bash

hook_now_utc() {
  date -u "+%Y-%m-%dT%H:%M:%SZ"
}

hook_timer_start() {
  # Return current time in milliseconds
  date +%s%3N 2>/dev/null || echo "0"
}

hook_timer_end() {
  # Args: start_ms
  # Return: duration_ms (0 if start was 0 or unavailable)
  local start_ms="${1:-0}"
  if [[ "$start_ms" == "0" ]]; then
    echo "0"
    return 0
  fi
  local end_ms
  end_ms=$(date +%s%3N 2>/dev/null || echo "0")
  echo $(( end_ms - start_ms ))
}

hook_perf_file() {
  # Separate file cho performance/event logs (hook_log_jsonl)
  # Schema khác hook_append_metric — giữ tách biệt để tránh parser conflict
  echo "${MCV3_HOOK_PERF_FILE:-.mc-data/logs/hook-perf.jsonl}"
}

hook_log_jsonl() {
  # Args: hook_name, event, tool, target, note, dur_ms, exit_code, error
  # Write single JSON line to $MCV3_HOOK_PERF_FILE (NOT hook-metrics.jsonl)
  # Schema: {ts, hook, event, tool, target, note, dur_ms, exit_code, error}
  # Tách biệt khỏi hook_append_metric để tránh schema conflict
  local hook_name="${1:-unknown}"
  local event="${2:-}"
  local tool="${3:-}"
  local target="${4:-}"
  local note="${5:-ok}"
  local dur_ms="${6:-0}"
  local exit_code="${7:-0}"
  local error="${8:-}"
  local metric_file timestamp jq_bin

  if ! hook_metrics_enabled; then
    return 0
  fi

  jq_bin=$(hook_resolve_jq) || return 0
  metric_file=$(hook_perf_file)
  timestamp=$(hook_now_utc)

  mkdir -p "$(dirname "$metric_file")"

  "$jq_bin" -cn \
    --arg ts "$timestamp" \
    --arg hook "$hook_name" \
    --arg event "$event" \
    --arg tool "$tool" \
    --arg target "$target" \
    --arg note "$note" \
    --argjson dur "$dur_ms" \
    --argjson code "$exit_code" \
    --arg err "$error" \
    '{ts: $ts, hook: $hook, event: $event, tool: $tool, target: $target, note: $note, dur_ms: $dur, exit_code: $code, error: $err}' \
    >> "$metric_file"

  # Rotation: if > 1000 lines, keep last 500
  local line_count
  line_count=$(wc -l < "$metric_file" 2>/dev/null || echo "0")
  if [[ "$line_count" -gt 1000 ]]; then
    local tmp_file="${metric_file}.tmp"
    tail -n 500 "$metric_file" > "$tmp_file" && mv "$tmp_file" "$metric_file"
  fi
}

hook_normalize_path() {
  local raw_path="${1:-}"
  raw_path="${raw_path//$'\r'/}"
  raw_path="${raw_path//$'\n'/}"
  echo "${raw_path//\\//}"
}

hook_detect_phase_from_path() {
  local file_path
  file_path=$(hook_normalize_path "${1:-}")

  case "$file_path" in
    *"/phase0-brainstorm/"*|".mc-data/docs/phase0-brainstorm/"*) echo "phase0-brainstorm" ;;
    *"/phase1-business/"*|".mc-data/docs/phase1-business/"*) echo "phase1-business" ;;
    *"/phase2-features/"*|".mc-data/docs/phase2-features/"*) echo "phase2-features" ;;
    *"/phase3-architecture/"*|".mc-data/docs/phase3-architecture/"*) echo "phase3-architecture" ;;
    *"/phase4-ux/"*|".mc-data/docs/phase4-ux/"*) echo "phase4-ux" ;;
    *"/phase5-implementation/"*|".mc-data/docs/phase5-implementation/"*) echo "phase5-implementation" ;;
    *"/phase6-deployment/"*|".mc-data/docs/phase6-deployment/"*) echo "phase6-deployment" ;;
    *"/wf-brainstorm/"*) echo "wf-brainstorm" ;;
    *"/wf-analyze-requirements/"*) echo "wf-analyze-requirements" ;;
    *"/wf-define-features/"*) echo "wf-define-features" ;;
    *"/wf-design/"*) echo "wf-design" ;;
    *"/wf-design-ux/"*) echo "wf-design-ux" ;;
    *"/wf-plan-modules/"*) echo "wf-plan-modules" ;;
    *"/wf-implement-feature/"*) echo "wf-implement-feature" ;;
    *"/wf-preflight/"*) echo "wf-preflight" ;;
    *"/wf-fix-bugs/"*) echo "wf-fix-bugs" ;;
    *"/wf-verify-sync/"*) echo "wf-verify-sync" ;;
    *"/wf-prepare-deployment/"*) echo "wf-prepare-deployment" ;;
    *"/wf-annotate-code/"*) echo "wf-annotate-code" ;;
    *"/wf-add-scope/"*) echo "wf-add-scope" ;;
    *"/wf-manage-change/"*) echo "wf-manage-change" ;;
    *"/wf-legacy-scan/"*) echo "wf-legacy-scan" ;;
    *"/wf-legacy-classify/"*) echo "wf-legacy-classify" ;;
    *"/wf-legacy-extract/"*) echo "wf-legacy-extract" ;;
    *) echo "other" ;;
  esac
}

hook_detect_scope_from_path() {
  local file_path
  file_path=$(hook_normalize_path "${1:-}")

  case "$file_path" in
    *"/.mc-data/docs/_meta/"*|".mc-data/docs/_meta/"*) echo "meta" ;;
    *"/.mc-data/docs/"*|".mc-data/docs/"*) echo "docs" ;;
    *"/.mc-data/work/"*|".mc-data/work/"*) echo "work" ;;
    *"/.claude/hooks/"*|".claude/hooks/"*) echo "hooks" ;;
    *"/.claude/skills/workflow/"*|".claude/skills/workflow/"*) echo "workflow-skill" ;;
    *) echo "other" ;;
  esac
}

hook_resolve_jq() {
  if command -v jq &> /dev/null; then
    command -v jq
    return 0
  fi

  if command -v jq.exe &> /dev/null; then
    command -v jq.exe
    return 0
  fi

  return 1
}

hook_metrics_enabled() {
  [[ "${MCV3_HOOK_METRICS_ENABLED:-0}" == "1" ]] && hook_resolve_jq &> /dev/null
}

hook_metric_file() {
  echo "${MCV3_HOOK_METRICS_FILE:-.mc-data/logs/hook-metrics.jsonl}"
}

hook_metric_file_exists() {
  local metric_file
  metric_file=$(hook_metric_file)
  [[ -f "$metric_file" ]]
}

hook_render_metrics_summary() {
  local metric_file jq_bin

  if ! hook_metrics_enabled; then
    return 1
  fi

  metric_file=$(hook_metric_file)
  [[ -f "$metric_file" ]] || return 1

  jq_bin=$(hook_resolve_jq) || return 1

  "$jq_bin" -sr '
    reduce .[] as $event (
      {
        total_events: 0,
        post_write_invocations: 0,
        incremental_contract_checks: 0,
        full_contract_checks: 0,
        sync_updates: 0,
        skipped_events: 0,
        phases_touched: [],
        last_event: null
      };
      .total_events += 1
      | .post_write_invocations += (
          if ($event.hook == "update-sync-status"
            or $event.hook == "validate-contract-sync"
            or $event.hook == "validate-ui-component"
            or $event.hook == "validate-naming-convention")
          then 1 else 0 end
        )
      | .incremental_contract_checks += (
          if ($event.hook == "validate-contract-sync" and $event.mode == "incremental-doc")
          then 1 else 0 end
        )
      | .full_contract_checks += (
          if ($event.hook == "validate-contract-sync" and $event.mode == "full-doc-scan")
          then 1 else 0 end
        )
      | .sync_updates += (
          if ($event.hook == "update-sync-status" and $event.status == "completed")
          then 1 else 0 end
        )
      | .skipped_events += (if $event.status == "skipped" then 1 else 0 end)
      | .phases_touched += (
          if ($event.phase != null and $event.phase != "" and $event.phase != "other")
          then [$event.phase] else [] end
        )
      | .last_event = $event
    )
    | .phases_touched |= (unique | sort)
  ' "$metric_file"
}

hook_detect_phase_boundary() {
  # Phát hiện phase boundary từ environment variable hoặc trigger condition
  # Nếu MCV3_PHASE_BOUNDARY=true → chúng ta đang tại phase boundary
  if [[ "${MCV3_PHASE_BOUNDARY:-0}" == "true" ]]; then
    echo "true"
    return 0
  fi
  echo "false"
  return 0
}

hook_detect_tier_mode() {
  # Hệ thống 2 tầng:
  # - Tier 1 (per-file): chạy mỗi file write, nhanh, chỉ check file vừa thay đổi
  # - Tier 2 (full-tree): chạy tại phase boundaries, chậm, check toàn project
  #
  # Nếu MCV3_HOOK_TIER được set → dùng cái đó
  # Nếu không, detect từ phase boundary
  # Default: Tier 1 (safe mode)

  local explicit_tier="${MCV3_HOOK_TIER:-}"

  if [[ -n "$explicit_tier" && "$explicit_tier" =~ ^[12]$ ]]; then
    echo "$explicit_tier"
    return 0
  fi

  # Detect từ phase boundary
  if [[ "$(hook_detect_phase_boundary)" == "true" ]]; then
    echo "2"
    return 0
  fi

  # Default: Tier 1
  echo "1"
  return 0
}

hook_append_metric() {
  local hook_name="$1"
  local status="$2"
  local mode="$3"
  local file_path="${4:-}"
  local count="${5:-0}"
  local tier="${6:-}"
  local normalized_path phase scope metric_file timestamp jq_bin

  if ! hook_metrics_enabled; then
    return 0
  fi

  normalized_path=$(hook_normalize_path "$file_path")
  phase=$(hook_detect_phase_from_path "$normalized_path")
  scope=$(hook_detect_scope_from_path "$normalized_path")
  metric_file=$(hook_metric_file)
  timestamp=$(hook_now_utc)
  jq_bin=$(hook_resolve_jq) || return 0

  # Nếu tier không được cung cấp, detect
  if [[ -z "$tier" ]]; then
    tier=$(hook_detect_tier_mode)
  fi

  mkdir -p "$(dirname "$metric_file")"

  "$jq_bin" -cn \
    --arg timestamp "$timestamp" \
    --arg hook "$hook_name" \
    --arg status "$status" \
    --arg mode "$mode" \
    --arg file_path "$normalized_path" \
    --arg phase "$phase" \
    --arg scope "$scope" \
    --argjson count "${count:-0}" \
    --argjson tier "$tier" \
    '{
      timestamp: $timestamp,
      hook: $hook,
      status: $status,
      mode: $mode,
      file_path: $file_path,
      phase: $phase,
      scope: $scope,
      count: $count,
      tier: $tier
    }' >> "$metric_file"
}
