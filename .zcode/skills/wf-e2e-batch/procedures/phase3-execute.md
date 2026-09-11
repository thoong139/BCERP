# Phase 3: Execute FEATs (Topology Dispatch)

> **Load khi:** Phase 2 POST-GATE PASS.
> **Input:** `dependency-matrix.json`, `feat-list.json`
> **Output:** Per-FEAT e2e-status.json (từ wf-e2e-verify), `gate-report-{N}.json`, `chain-rollback-decisions.json`

## PRE-GATE

```
T1: dependency-matrix.json tồn tại + valid JSON
T2: topology_levels ≥ 1
T3: dry_run check — nếu --dry-run → log topology plan + STOP (không dispatch)
```

## Logic Tổng Quan

```
FOR EACH level IN topology_levels (tuần tự từ level 1):
  1. Lấy FEATs trong level này
  2. CF2: 2-tier check deps từ level trước đã đạt min_completion
  3. CF4: Init per-FEAT schema namespace
  4. CF8: Cache upstream findings cho FEAT B reuse
  5. Dispatch wf-e2e-verify × N (parallel tới max-parallel)
  6. Đợi tất cả FEAT trong level hoàn tất
  7. CURRENT_FEAT_COUNT += N
  8. CF3: Orchestrator gate check nếu CURRENT_FEAT_COUNT đã qua ngưỡng 3N
  9. CF5: Chain rollback check nếu có FEAT fail
  10. Update batch-status.json

DISPATCH:
  spawn Agent("wf-e2e-verify", FEAT-ID + extra_flags)
  extra_flags = "--session=batch-{batch_id}-{feat_id} --auto={AUTO}"
```

## CF2: 2-Tier Dependency Check

```
TRƯỚC KHI DISPATCH FEAT B (có feat-to-feat dep với FEAT A):

TIER 1 — STATIC CHECK:
  registry.features[FEAT_A].impl_status ∈ {not_started, in_progress, skipped}?
  → FAIL: FEAT A chưa có code → block FEAT B
  → Action nếu --auto: spawn_auto_resolve_agent (xem procedures/auto-resolve.md §CF2)
      options: IMPLEMENT_A | SKIP_B | FORCE_DISPATCH
      IMPLEMENT_A → spawn wf-implement-feature FEAT_A --auto, rồi retry CF2 (max 1 lần)
      SKIP_B      → mark_feat_skipped FEAT_B "cf2_dep_miss_auto_skip"
      FORCE_DISPATCH → tiếp tục dispatch FEAT_B, ghi WARN
  → Action nếu không --auto: CDG AskUserQuestion:
      "FEAT B depend FEAT A nhưng FEAT A chưa implement.
       [1] Implement FEAT A trước (dùng /wf-implement-feature)
       [2] Skip FEAT B (đánh dấu blocked)
       [3] Force dispatch (chấp nhận risk)"

TIER 2 — RUNTIME CHECK:
  Tìm session gần nhất FEAT_A trong .mc-data/work/wf-e2e-verify/sessions/
  Tìm session có prefix "batch-{batch_id}-{feat_a_id}" hoặc gần nhất

  e2e-status.json.steps.f8_demo.status = "completed"?
  → FAIL: FEAT A chưa pass F8

  POLICY theo blocking_level:
    hard + min_completion=test_passed → cả 2 tier phải pass → E053 nếu fail
    hard + min_completion=impl_done  → chỉ tier 1 pass đủ
    soft → chỉ tier 1 pass đủ → log WARN nếu tier 2 fail
```

## CF3: Gate Sau Mỗi 3 FEAT

```bash
verify_gate_after_n_feats() {
  local gate_num="$1"
  local feats_in_gate=("${@:2}")  # Array FEAT-IDs vừa hoàn thành
  local gate_pass=true
  local gate_issues=()

  log "CF3: Gate check #$gate_num cho FEATs: ${feats_in_gate[*]}"

  # CHECK 1 — Cross-REQ-ID (CF6)
  for feat_id in "${feats_in_gate[@]}"; do
    local e2e_session
    e2e_session=$(find "$WORK_DIR/wf-e2e-verify/sessions" \
      -name "e2e-status.json" -path "*${feat_id}*" 2>/dev/null | head -1)
    if [ -n "$e2e_session" ]; then
      local feat_reqs
      feat_reqs=$(jq -r --arg fid "$feat_id" \
        '.features[] | select(.id == $fid) | .req_ids // [] | .[]' \
        "$REGISTRY_PATH" 2>/dev/null)
      # Validate cross_feat_refs REQ-IDs exist
      while IFS= read -r req_id; do
        if ! jq -e --arg r "$req_id" '.requirements[] | select(.req_id == $r)' \
          "$REGISTRY_PATH" > /dev/null 2>&1; then
          gate_issues+=("CF6_MISMATCH: $feat_id REQ-ID $req_id không tồn tại trong registry")
          gate_pass=false
        fi
      done <<< "$feat_reqs"
    fi
  done

  # CHECK 2 — Data Leak (CF4 schema isolation)
  # (Delegate sang feat-schema-cleanup.sh verify — xem CF4)
  # Nếu CF4 disabled → skip check này

  # CHECK 3 — Test Stability (flaky rate)
  local total_scenarios=0 flaky_scenarios=0
  for feat_id in "${feats_in_gate[@]}"; do
    local e2e_session
    e2e_session=$(find "$WORK_DIR/wf-e2e-verify/sessions" \
      -name "e2e-status.json" -path "*${feat_id}*" 2>/dev/null | head -1)
    if [ -n "$e2e_session" ]; then
      local feat_issues_file
      feat_issues_file="$(dirname "$e2e_session")/issues.json"
      if [ -f "$feat_issues_file" ]; then
        local flaky
        flaky=$(jq '[.[] | select(.status == "flaky")] | length' "$feat_issues_file" 2>/dev/null || echo 0)
        local total
        total=$(jq 'length' "$feat_issues_file" 2>/dev/null || echo 0)
        flaky_scenarios=$((flaky_scenarios + flaky))
        total_scenarios=$((total_scenarios + total))
      fi
    fi
  done
  if [ "$total_scenarios" -gt 0 ]; then
    local flaky_rate=$(( flaky_scenarios * 100 / total_scenarios ))
    if [ "$flaky_rate" -gt 22 ]; then
      gate_issues+=("FLAKY_ALERT: Flaky rate ${flaky_rate}% > 22% threshold")
    fi
  fi

  # CHECK 4 — Performance (runtime > 150% baseline)
  # Simplified: check nếu có quá nhiều FEATs quá 150% thời gian trung bình
  # (Implement khi có baseline data)

  # CHECK 5 — Memory (connections, disk)
  # (Placeholder — implement với actual metrics khi available)

  # CHECK 6 — Aggregate Fail Rate
  local fail_count=0
  for feat_id in "${feats_in_gate[@]}"; do
    local e2e_session
    e2e_session=$(find "$WORK_DIR/wf-e2e-verify/sessions" \
      -name "e2e-status.json" -path "*${feat_id}*" 2>/dev/null | head -1)
    if [ -n "$e2e_session" ]; then
      local all_complete
      all_complete=$(jq -r '.steps | to_entries[] | .value.status' "$e2e_session" 2>/dev/null | \
        grep -c "failed" || echo 0)
      [ "$all_complete" -gt 0 ] && fail_count=$((fail_count + 1))
    fi
  done

  local n="${#feats_in_gate[@]}"
  if [ "$n" -gt 0 ]; then
    local fail_rate=$(( fail_count * 100 / n ))
    if [ "$fail_rate" -gt 40 ]; then
      gate_issues+=("HIGH_FAIL_RATE: ${fail_rate}% > 40% — ${fail_count}/${n} FEATs fail")
      gate_pass=false
    fi
  fi

  # Build gate-report JSON
  local gate_report
  gate_report=$(jq -n \
    --arg gnum "$gate_num" \
    --arg bid "$BATCH_ID" \
    --argjson feats "$(printf '%s\n' "${feats_in_gate[@]}" | jq -R . | jq -sc '.')" \
    --argjson pass "$gate_pass" \
    --argjson issues "$(printf '%s\n' "${gate_issues[@]:-}" | jq -R . | jq -sc '.')" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      gate_num: ($gnum | tonumber),
      batch_id: $bid,
      feats_checked: $feats,
      pass: $pass,
      issues: $issues,
      checked_at: $ts
    }')
  atomic_write_json "$SESSION_DIR/gate-report-${gate_num}.json" "$gate_report"

  if [ "$gate_pass" = false ]; then
    log_error "E054" "Gate check #$gate_num FAIL: ${gate_issues[*]}"
    if [ "${AUTO:-false}" = false ]; then
      # CDG: hỏi user có tiếp tục không
      echo "Gate check #$gate_num thất bại. Issues:"
      printf '  - %s\n' "${gate_issues[@]}"
      echo "Tiếp tục batch? [Y]es / [N]o (abort) / [S]kip gate (risky)"
    else
      # --auto: spawn decision agent thay vì dừng chờ user
      # (xem procedures/auto-resolve.md §CF3)
      GATE_CTX=$(jq -n \
        --arg gnum "$gate_num" \
        --argjson feats "$(printf '%s\n' "${feats_in_gate[@]}" | jq -R . | jq -sc '.')" \
        --argjson issues "$(printf '%s\n' "${gate_issues[@]:-}" | jq -R . | jq -sc '.')" \
        '{gate_num:($gnum|tonumber), feats:$feats, issues:$issues}')
      AUTO_ACTION=$(spawn_auto_resolve_agent "cf3_gate_fail" "$GATE_CTX" \
        "CONTINUE_WARN|ABORT_BATCH|SKIP_GATE")
      case "$AUTO_ACTION" in
        CONTINUE_WARN) log_event "WARN" "CF3-AUTO" "Gate #${gate_num} fail — auto-continue" ;;
        ABORT_BATCH)
          log_error "E054" "CF3-AUTO" "Auto-resolve quyết định ABORT tại gate #${gate_num}"
          finalize_batch "aborted_by_auto_resolve"; exit 1 ;;
        SKIP_GATE) log_event "WARN" "CF3-AUTO" "Gate #${gate_num} bị skip theo auto-resolve" ;;
      esac
    fi
  fi

  $gate_pass
}
```

## CF4: Per-FEAT DB Schema Namespace

```bash
init_feat_schema() {
  local feat_id="$1"
  local session_id="$2"

  # Delegate sang script
  local schema_output
  schema_output=$(bash .claude/scripts/wf-e2e-batch/feat-schema-init.sh "$feat_id" "$session_id" 2>&1)
  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    log_error "E055" "Per-FEAT schema init thất bại cho $feat_id: $schema_output"
    return 1
  fi

  # Parse schema name và new DB URL
  local schema_name new_db_url
  schema_name=$(echo "$schema_output" | grep "^SCHEMA_NAME=" | cut -d= -f2)
  new_db_url=$(echo "$schema_output" | grep "^DATABASE_URL=" | cut -d= -f2-)

  log "CF4: Schema namespace tạo cho $feat_id: $schema_name"
  echo "$schema_name:$new_db_url"
}

cleanup_feat_schema() {
  local feat_id="$1"
  local session_id="$2"
  local feat_status="$3"  # passed|failed

  local retain_flag=""
  [ "$feat_status" = "failed" ] && retain_flag="--retain-for-debug"

  bash .claude/scripts/wf-e2e-batch/feat-schema-cleanup.sh "$feat_id" "$session_id" "$retain_flag"
}
```

## CF5: Chain Rollback Policy

```bash
apply_chain_rollback_policy() {
  local feat_b="$1"
  local feat_a="$2"
  local blocking_level="$3"
  local min_completion="$4"
  local feat_b_status="$5"  # failed

  local policy
  if [ "$blocking_level" = "hard" ] && [ "$min_completion" = "test_passed" ]; then
    policy="MARK_A_SUSPECT"
  elif [ "$blocking_level" = "hard" ] && [ "$min_completion" = "impl_done" ]; then
    policy="CONTINUE_A_STANDALONE"
  else
    policy="CONTINUE_A_STANDALONE"
  fi

  # MARK_A_SUSPECT: tag trong FEAT A's e2e-status
  if [ "$policy" = "MARK_A_SUSPECT" ]; then
    local feat_a_session
    feat_a_session=$(find "$WORK_DIR/wf-e2e-verify/sessions" \
      -name "e2e-status.json" -path "*${feat_a}*" 2>/dev/null | head -1)
    if [ -n "$feat_a_session" ]; then
      local updated
      updated=$(jq --arg fb "$feat_b" '.suspect_downstream += [$fb]' "$feat_a_session")
      atomic_write_json "$feat_a_session" "$updated"
    fi
    log "CF5: $feat_a đánh dấu SUSPECT — $feat_b fail có thể do $feat_a"
  fi

  # ROLLBACK_A: chỉ khi --enable-chain-rollback + user confirm (hoặc auto-resolve)
  if [ "${ENABLE_CHAIN_ROLLBACK:-false}" = "true" ] && [ "$policy" = "MARK_A_SUSPECT" ]; then
    if [ "${AUTO:-false}" = false ]; then
      echo "CF5: FEAT $feat_b fail, phụ thuộc hard vào FEAT $feat_a."
      echo "Bạn có muốn rollback FEAT $feat_a (restore schema + mark in_progress)? [Y/N]"
      # User confirm → execute rollback
    else
      # --auto: spawn decision agent (xem procedures/auto-resolve.md §CF5)
      CF5_CTX=$(jq -n \
        --arg fb "$feat_b" --arg fa "$feat_a" \
        --arg fbs "$feat_b_status" --arg bl "$blocking_level" --arg mc "$min_completion" \
        '{feat_ids:[$fb,$fa], feat_b_status:$fbs,
          blocking_level:$bl, min_completion:$mc}')
      AUTO_ACTION=$(spawn_auto_resolve_agent "cf5_rollback" "$CF5_CTX" \
        "ROLLBACK_A|CONTINUE_SUSPECT|SKIP_FEAT_B")
      case "$AUTO_ACTION" in
        ROLLBACK_A)
          bash .claude/scripts/wf-e2e-batch/feat-schema-cleanup.sh \
            "$feat_a" "batch-${BATCH_ID}-${feat_a}" --rollback
          log_event "ROLLBACK" "CF5-AUTO" "Auto-rollback ${feat_a} theo quyết định agent" ;;
        CONTINUE_SUSPECT)
          log_event "WARN" "CF5-AUTO" "${feat_a} giữ trạng thái SUSPECT, tiếp tục batch" ;;
        SKIP_FEAT_B)
          mark_feat_skipped "$feat_b" "cf5_auto_skip_after_a_suspect" ;;
      esac
    fi
  fi

  # Log decision
  local decision
  decision=$(jq -n \
    --arg fb "$feat_b" --arg fa "$feat_a" \
    --arg bl "$blocking_level" --arg mc "$min_completion" \
    --arg fbs "$feat_b_status" --arg pol "$policy" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{feat_b: $fb, feat_a: $fa, dependency_type: "feat-to-feat",
      blocking_level: $bl, min_completion: $mc,
      feat_b_status: $fbs, policy_applied: $pol, executed_at: $ts}')

  # Append to chain-rollback-decisions.json
  if [ -f "$SESSION_DIR/chain-rollback-decisions.json" ]; then
    local existing
    existing=$(cat "$SESSION_DIR/chain-rollback-decisions.json")
    local updated
    updated=$(echo "$existing" | jq --argjson d "$decision" '.decisions += [$d]')
    atomic_write_json "$SESSION_DIR/chain-rollback-decisions.json" "$updated"
  else
    local init
    init=$(jq -n --arg bid "$BATCH_ID" --argjson d "$decision" \
      '{"$schema": "chain-rollback-policy-v1", batch_id: $bid, decisions: [$d]}')
    atomic_write_json "$SESSION_DIR/chain-rollback-decisions.json" "$init"
  fi
}
```

## CF8: Stable Upstream Cache

```bash
cache_upstream_findings() {
  local feat_a_session="$1"
  local feat_b_session="$2"

  local findings_a="$WORK_DIR/wf-e2e-verify/sessions/${feat_a_session}/findings/"
  local upstream_cache="$WORK_DIR/wf-e2e-verify/sessions/${feat_b_session}/upstream-cache/"

  if [ ! -d "$findings_a" ]; then
    log "CF8: Không có findings từ FEAT A session $feat_a_session — skip cache"
    return 0
  fi

  mkdir -p "$upstream_cache"
  cp -r "${findings_a}"* "$upstream_cache/" 2>/dev/null || true

  # Tag với hash để detect stale
  find "$upstream_cache" -type f -exec sha256sum {} \; > "${upstream_cache}/.cache-manifest"
  echo "upstream_cache_from=$feat_a_session" > "${upstream_cache}/.cache-meta"

  log "CF8: Cached findings từ $feat_a_session → $feat_b_session/upstream-cache/"
}

verify_upstream_cache_freshness() {
  local feat_b_session="$1"
  local cache_dir="$WORK_DIR/wf-e2e-verify/sessions/${feat_b_session}/upstream-cache/"

  if [ ! -f "${cache_dir}/.cache-manifest" ]; then
    return 0  # Không có cache → OK
  fi

  # Verify hash của source findings vẫn khớp
  local source_session
  source_session=$(grep "upstream_cache_from=" "${cache_dir}/.cache-meta" | cut -d= -f2)
  local source_findings="$WORK_DIR/wf-e2e-verify/sessions/${source_session}/findings/"

  # Compare manifest vs current state
  local current_manifest
  current_manifest=$(find "$source_findings" -type f -exec sha256sum {} \; 2>/dev/null)
  local cached_manifest
  cached_manifest=$(cat "${cache_dir}/.cache-manifest")

  if [ "$current_manifest" != "$cached_manifest" ]; then
    log_error "E058" "CF8: Upstream cache stale — FEAT A findings đã thay đổi. Refreshing..."
    # Auto-refresh cache
    cp -r "${source_findings}"* "$cache_dir/" 2>/dev/null || true
    find "$cache_dir" -type f -exec sha256sum {} \; > "${cache_dir}/.cache-manifest"
  fi
}
```

## Main Execute Loop

```
SETUP:
  topology = load dependency-matrix.json .topology_levels
  feat_results = {}
  gate_feats_buffer = []  # FEATs để gate check
  GATE_COUNTER = 0

FOR EACH level IN topology (level 1, 2, ...):
  feats_in_level = level.feats
  log "Đang dispatch level $level_num: ${feats_in_level[*]}"

  # Parallel dispatch (tối đa MAX_PARALLEL)
  CHUNK feats_in_level BY max-parallel:
    FOR EACH chunk:
      FOR EACH feat_id IN chunk:
        1. CF2: check_dependencies_tier1_tier2(feat_id) → fail → log + skip/block
        2. CF4: schema_name = init_feat_schema(feat_id, "batch-${BATCH_ID}-${feat_id}")
        3. Tìm FEAT A sessions để CF8 cache (nếu có feat-to-feat dep)
        4. Spawn Agent(wf-e2e-verify):
           - FEAT-ID: $feat_id
           - extra args: "--session=batch-${BATCH_ID}-${feat_id} --auto=${AUTO}"
           - CF8 context: upstream-cache path nếu có

      WAIT for all agents in chunk to complete

      FOR EACH feat_id IN chunk:
        - Read e2e-status.json → determine PASS/FAIL
        - CF5: nếu fail → apply_chain_rollback_policy
        - AUTO-RESOLVE: nếu fail + --auto → spawn_auto_resolve_agent "verify_block"
            options: SKIP_FEAT | RETRY_ONCE | FAIL_BATCH
            (xem procedures/auto-resolve.md §verify_block)
        - CF4: cleanup_feat_schema (retain nếu fail)
        - Update feat_results[feat_id]
        - gate_feats_buffer += feat_id
        - Update batch-status.json

      # CF3: gate check sau mỗi 3 FEATs
      IF length(gate_feats_buffer) >= 3:
        GATE_COUNTER++
        verify_gate_after_n_feats($GATE_COUNTER, gate_feats_buffer)
        gate_feats_buffer = []

  # Cuối level: nếu còn FEATs trong buffer chưa gate
  # (sẽ được check ở cuối hoặc tiếp tục accumulate vào level tiếp)

# Cuối batch: gate check cho phần còn lại
IF length(gate_feats_buffer) > 0:
  GATE_COUNTER++
  verify_gate_after_n_feats($GATE_COUNTER, gate_feats_buffer)
```

## POST-GATE

```
T1: batch-status.json updated với feats_completed + feats_failed + feats_blocked
T2: Mỗi FEAT trong feat-list có entry trong feat_results
T3: chain-rollback-decisions.json tạo nếu có CF5 triggers
T4: gate-report-{N}.json tạo cho mỗi gate trigger
```

## Phase 3 Report (CORE-028)

```markdown
## Phase 3: Execute FEATs — PASS|PARTIAL|FAIL

Thời gian: {ISO-8601}
**Đã làm:** Dispatch {N} FEATs theo {M} topology levels, {G} gate checks.
**Kết quả:** PASS={pass_count}, FAIL={fail_count}, BLOCKED={blocked_count}
**Tiếp theo:** Phase 4 Aggregate
```

## NEXT → `procedures/phase4-aggregate.md`
