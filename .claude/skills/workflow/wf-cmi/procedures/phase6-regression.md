# Phase 6 — Regression Map (Predictive Impact)

> **Đầu vào:** `coverage-matrix.json` (Phase 5), 6 graphs (Phase 2), `$SINCE_REF`, GitNexus impact, git history
> **Đầu ra:** `regression-map.json`, `regression-report.md`, `Phase6-report.md`
> **Auto-fix budget:** 3 retries
> **Time estimate:** 1-3 min
> **Required:** ⚪ Optional — SKIP nếu `--profile=quick` HOẶC `--since` không set

---

## §A Header

Phase 6 build predictive regression map khi `--since=<ref>` set. Phát hiện modules/workflows/tests bị ảnh hưởng bởi changes since baseline ref.

| Mode | Behavior |
|------|---------|
| Predictive (deep/exhaustive + GitNexus available) | Full impact analysis qua GitNexus `impact({changed_files, direction:"upstream"})` với confidence per hop |
| Diff-aware (standard + GitNexus unavailable) | `git diff --name-only` + manual cross-ref module-graph |
| Skip | `profile=quick` OR `$SINCE_REF` empty |

**Mode:** SEQUENTIAL (optional `data-engineer` agent cho predictive scoring deep+).

**Shared sections cần load:**
- `_shared.md §1, §3, §12 CI Detection`

---

## §B PRE-GATE (T1→T4)

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | `coverage-matrix.json` từ Phase 5 exists | bash | **E060** — Aggregation missing → re-run Phase 5 |
| T2 | `$SINCE_REF` valid (nếu set) | `git rev-parse --verify` | **E061** — Invalid ref → ESCALATE user fix |
| T3 | GitNexus impact graph available OR fallback git log | composite | **E062** — Regression intelligence unavailable → downgrade predictive → diff-aware, WARN |
| T4 | Cross-ref: changed files thuộc scope của session | bash | **E063** — Scope mismatch → filter, WARN |

**Skip conditions (Phase 6 entirely):**

```bash
# Auto-skip rule
if [ "$PROFILE" = "quick" ] || [ -z "$SINCE_REF" ]; then
  log_phase_event "phase6" "SKIP" "{\"reason\":\"profile=quick or no --since\"}"
  # Create stub regression-map.json
  echo '{"$schema":"regression-map-v1","skipped":true,"reason":"profile=quick or no --since"}' \
    > "$SESSION_DIR/phase6-regression/regression-map.json"
  # Skip to Phase 7
  return 0
fi

# T2 — validate --since
if [ -n "$SINCE_REF" ]; then
  git rev-parse --verify "$SINCE_REF" >/dev/null 2>&1 \
    || die "E061" "Invalid --since ref: $SINCE_REF"
fi
```

---

## §C Steps

### Step 6.1 — Validate `$SINCE_REF` + load baseline commit info

```bash
SINCE_COMMIT=$(git rev-parse --verify "$SINCE_REF" 2>/dev/null)
HEAD_COMMIT=$(git rev-parse --verify HEAD 2>/dev/null)
[ -z "$SINCE_COMMIT" ] && die "E061" "Cannot resolve --since=$SINCE_REF"

log_phase_event "phase6" "INFO" \
  "{\"since_ref\":\"$SINCE_REF\",\"since_commit\":\"$SINCE_COMMIT\",\"head_commit\":\"$HEAD_COMMIT\"}"
```

### Step 6.2 — Get changed files

> Scope-aware: filter theo `$SCOPE_TYPE`.

```bash
# Build scope pattern
case "$SCOPE_TYPE" in
  system)
    SCOPE_PATTERN="."
    ;;
  module)
    SCOPE_PATTERN="apps/backend/Eureka.Modules.${SCOPE_NAME^^}* apps/erp-web/src/modules/$SCOPE_NAME*"
    ;;
  feat)
    # FEAT scope → derive code paths from registry
    SCOPE_PATTERN=$(jq -r --arg f "$SCOPE_NAME" \
      '.features[] | select(.id == $f) | .code_paths[]' \
      .mc-data/docs/_meta/req-registry.json | tr '\n' ' ')
    [ -z "$SCOPE_PATTERN" ] && SCOPE_PATTERN="."
    ;;
esac

CHANGED_FILES=$(git diff --name-only "$SINCE_COMMIT...HEAD" -- $SCOPE_PATTERN 2>/dev/null)
CHANGED_COUNT=$(echo "$CHANGED_FILES" | grep -v '^$' | wc -l)

log_phase_event "phase6" "INFO" "{\"changed_files\":$CHANGED_COUNT}"
```

### Step 6.3 — Early exit nếu 0 files

```bash
if [ "$CHANGED_COUNT" -eq 0 ]; then
  log_phase_event "phase6" "SKIP" "{\"reason\":\"no files changed since $SINCE_REF\"}"
  # Generate minimal report
  cat > "$SESSION_DIR/phase6-regression/regression-report.md" <<EOF
## Phase 6: Regression scope — KHÔNG CÓ THAY ĐỔI
Thời gian: $(date -Iseconds)

**Đã làm:** So sánh code hiện tại với baseline ref \`$SINCE_REF\`.

**Kết quả:**
- 0 file thay đổi trong scope $SCOPE_TYPE
- Coverage Phase 5 vẫn hợp lệ (no regression detected)

**Tiếp theo:** Phase 7 GAP detection (cần thiết để báo cáo đầy đủ).
EOF
  return 0  # Skip Steps 6.4-6.9, jump Step 6.10
fi
```

### Step 6.4 — Build direct callers (CI primary OR Grep fallback)

```bash
DIRECT_CALLERS="[]"
if [ "$GITNEXUS_AVAILABLE" = "true" ]; then
  # Primary: GitNexus impact analysis
  DIRECT_CALLERS=$(echo "$CHANGED_FILES" | while read file; do
    [ -z "$file" ] && continue
    gitnexus impact --target="$file" --direction=upstream --depth=1 2>/dev/null \
      | jq --arg src "$file" '[.[] | {file: .symbol_file, source: $src, confidence: 0.95, hops: 1}]'
  done | jq -s 'add // []')
else
  # Fallback: Grep direct references
  DIRECT_CALLERS=$(echo "$CHANGED_FILES" | while read file; do
    [ -z "$file" ] && continue
    base=$(basename "$file" .cs)
    grep -rlE "\\b${base}\\b" --include='*.cs' . 2>/dev/null \
      | grep -v "^$file$" \
      | jq -nR --arg src "$file" --slurp 'split("\n") | map(select(length > 0)) |
                map({file: ., source: $src, confidence: 0.6, hops: 1})'
  done | jq -s 'add // []')
  log_warn "E062" "GitNexus unavailable — diff-aware mode, confidence reduced"
fi
```

### Step 6.5 — Build transitive callers (predictive — deep+ only)

```bash
TRANSITIVE_CALLERS="[]"
if [ "$PROFILE" = "deep" ] || [ "$PROFILE" = "exhaustive" ]; then
  if [ "$GITNEXUS_AVAILABLE" = "true" ]; then
    # Predictive transitive
    TRANSITIVE_CALLERS=$(echo "$CHANGED_FILES" | while read file; do
      [ -z "$file" ] && continue
      gitnexus impact --target="$file" --direction=upstream --depth=3 --confidence-decay=0.7 2>/dev/null \
        | jq --arg src "$file" '[.[] | select(.hops > 1) |
                                  {file: .symbol_file, source: $src, confidence: .confidence, hops: .hops}]'
    done | jq -s 'add // []')

    # Spawn data-engineer agent cho confidence scoring (optional deep)
    if [ "$PROFILE" = "exhaustive" ] && [ "$(echo "$TRANSITIVE_CALLERS" | jq 'length')" -gt 0 ]; then
      log_phase_event "phase6" "INFO" "{\"step\":\"spawn data-engineer for predictive scoring\"}"
      # Agent({subagent_type:"data-engineer", model:"opus", prompt: ...})
      # Output: refined confidence scores
    fi
  fi
fi
```

### Step 6.6 — Affected modules computation

```bash
# Cross-ref với module-graph
AFFECTED_MODULES=$(jq -n --argjson dc "$DIRECT_CALLERS" --argjson tc "$TRANSITIVE_CALLERS" \
  --slurpfile mg "$SESSION_DIR/phase2-discovery/module-graph.json" \
  '[($dc + $tc)[] | .file as $f |
    ($mg[0].modules[] | select($f | contains(.id // "")) | {module: .id, confidence: 0.85})] |
   group_by(.module) | map(.[0])')
```

### Step 6.7 — Affected workflows computation

```bash
AFFECTED_WORKFLOWS=$(jq -n --argjson dc "$DIRECT_CALLERS" \
  --slurpfile wg "$SESSION_DIR/phase2-discovery/workflow-graph.json" \
  '[$dc[] | .file as $f |
    ($wg[0].workflows[] | select($f | contains(.name)) | {workflow: .id, confidence: 0.9})] |
   group_by(.workflow) | map(.[0])')
```

### Step 6.8 — Test plan generation

> Find existing tests touching affected modules → build test plan.

```bash
TEST_PLAN="[]"
for mod in $(echo "$AFFECTED_MODULES" | jq -r '.[].module'); do
  # Find tests trong tests/backend/Eureka.{UnitTests,IntegrationTests,ArchitectureTests}
  TESTS=$(find tests -path "*${mod^^}*" -name '*.cs' -type f 2>/dev/null \
         | jq -nR --arg m "$mod" --slurp \
           'split("\n") | map(select(length > 0)) |
            map({test_file: ., module: $m, type: (if test("UnitTests") then "unit"
                                                  elif test("IntegrationTests") then "integration"
                                                  elif test("ArchitectureTests") then "architecture"
                                                  else "unknown" end),
                 priority: "HIGH"})')
  TEST_PLAN=$(jq -n --argjson tp "$TEST_PLAN" --argjson t "$TESTS" '$tp + $t')
done

# E066: No tests found
TEST_COUNT=$(echo "$TEST_PLAN" | jq 'length')
[ "$TEST_COUNT" -eq 0 ] && log_warn "E066" "Test plan generation: 0 tests found for affected modules"
```

### Step 6.9 — Confidence scoring per prediction

```bash
# Filter low-confidence predictions (<0.7) → mark warn
CONFIDENCE_THRESHOLD=0.7

LOW_CONF_DIRECT=$(echo "$DIRECT_CALLERS" | jq --argjson t $CONFIDENCE_THRESHOLD \
                  '[.[] | select(.confidence < $t)] | length')
LOW_CONF_TRANS=$(echo "$TRANSITIVE_CALLERS" | jq --argjson t $CONFIDENCE_THRESHOLD \
                 '[.[] | select(.confidence < $t)] | length')

TOTAL_PREDICTIONS=$(($(echo "$DIRECT_CALLERS" | jq 'length') + \
                     $(echo "$TRANSITIVE_CALLERS" | jq 'length')))
LOW_CONF_TOTAL=$((LOW_CONF_DIRECT + LOW_CONF_TRANS))

if [ "$TOTAL_PREDICTIONS" -gt 0 ]; then
  LOW_CONF_PCT=$((LOW_CONF_TOTAL * 100 / TOTAL_PREDICTIONS))
  [ "$LOW_CONF_PCT" -gt 50 ] && log_warn "E064" "Low-confidence predictions: $LOW_CONF_PCT% (>50%) — downgrade diff-aware"
fi

# E068: Affected module count > 10 (system-wide impact)
AFF_MOD_COUNT=$(echo "$AFFECTED_MODULES" | jq 'length')
[ "$AFF_MOD_COUNT" -gt 10 ] && log_warn "E068" "Affected modules > 10 (system-wide impact: $AFF_MOD_COUNT)"
```

### Step 6.10 — Build regression-map.json (Atomic Write)

```bash
TARGET="$SESSION_DIR/phase6-regression/regression-map.json"
TPL=".claude/skills/workflow/wf-cmi/templates/regression-map.json"
strip_template_metadata "$TPL" "$TARGET"

CHANGED_FILES_JSON=$(echo "$CHANGED_FILES" | grep -v '^$' | jq -R . | jq -s .)

jq --argjson cf "$CHANGED_FILES_JSON" \
   --argjson dc "$DIRECT_CALLERS" --argjson tc "$TRANSITIVE_CALLERS" \
   --argjson am "$AFFECTED_MODULES" --argjson aw "$AFFECTED_WORKFLOWS" \
   --argjson tp "$TEST_PLAN" \
   --arg sr "$SINCE_REF" --arg sid "$SESSION_ID" --arg ts "$(date -Iseconds)" \
   --argjson ct "$CONFIDENCE_THRESHOLD" \
   '. + {
      session_id: $sid, generated_at: $ts,
      since_ref: $sr, changed_files: $cf,
      predicted_impact: {
        direct_callers: $dc,
        transitive_callers: $tc,
        affected_modules: $am,
        affected_workflows: $aw,
        test_plan: $tp
      },
      confidence_threshold: $ct,
      mode: "'"$([ "$GITNEXUS_AVAILABLE" = "true" ] && echo "predictive" || echo "diff-aware")"'",
      audit_chain: {source: "git+gitnexus", checksum: ""}
    }' "$TARGET" > "$TARGET.tmp.$$" && mv "$TARGET.tmp.$$" "$TARGET"

# Validate
jq '.' "$TARGET" >/dev/null || die "E055" "regression-map.json invalid"
```

### Step 6.11 — Write regression-report.md + Phase6-report.md

```bash
# regression-report.md (≤15 dòng tiếng Việt, CORE-028)
TPL_REG=".claude/skills/workflow/wf-cmi/templates/regression-report.md"

sed -e "s|\[CHANGED_COUNT\]|$CHANGED_COUNT|g" \
    -e "s|\[SINCE_REF\]|$SINCE_REF|g" \
    -e "s|\[AFFECTED_MOD_COUNT\]|$(echo "$AFFECTED_MODULES" | jq 'length')|g" \
    -e "s|\[AFFECTED_WF_COUNT\]|$(echo "$AFFECTED_WORKFLOWS" | jq 'length')|g" \
    -e "s|\[TEST_COUNT\]|$(echo "$TEST_PLAN" | jq 'length')|g" \
    -e "s|\[MODE\]|$([ "$GITNEXUS_AVAILABLE" = "true" ] && echo "predictive" || echo "diff-aware")|g" \
    -e "s|\[TIMESTAMP\]|$(date -Iseconds)|g" \
    "$TPL_REG" > "$SESSION_DIR/phase6-regression/regression-report.md"

# Phase6-report.md
TPL_PH=".claude/skills/workflow/wf-cmi/templates/Phase6-report.md"

sed -e "s|\[CHANGED_COUNT\]|$CHANGED_COUNT|g" \
    -e "s|\[AFFECTED_MOD_COUNT\]|$(echo "$AFFECTED_MODULES" | jq 'length')|g" \
    -e "s|\[TEST_COUNT\]|$(echo "$TEST_PLAN" | jq 'length')|g" \
    -e "s|\[MODE\]|$([ "$GITNEXUS_AVAILABLE" = "true" ] && echo "predictive" || echo "diff-aware")|g" \
    -e "s|\[TIMESTAMP\]|$(date -Iseconds)|g" \
    -e "s|\[STATUS\]|PASS|g" \
    "$TPL_PH" > "$SESSION_DIR/phase6-regression/Phase6-report.md"
```

---

## §D POST-GATE (T1→T4 + Auto-Fix)

| Tier | Check | Auto-fix (max 3) |
|------|-------|------------------|
| T1 | `regression-map.json` exists (kể cả `skipped:true`) | Re-build |
| T2 | Schema valid (`predicted_impact{}`, `changed_files[]`, `confidence_threshold`) | Re-build từ template |
| T3 | Mỗi `predicted_module` có `confidence ∈ [0, 1]` | Re-score |
| T4 | Cross-ref với git diff: scanned_files khớp `--since` scope | Re-scope |

```bash
post_gate_phase6() {
  local target="$SESSION_DIR/phase6-regression/regression-map.json"
  local retry=0
  while [ "$retry" -lt 3 ]; do
    # T1
    [ -f "$target" ] || { rebuild_regression_map; retry=$((retry+1)); continue; }

    # Check if skipped (early exit OK)
    if jq -e '.skipped == true' "$target" >/dev/null; then
      return 0  # Skip rest of POST-GATE
    fi

    # T2
    jq -e '."$schema" == "regression-map-v1" and (.predicted_impact | type == "object")' "$target" >/dev/null \
      || { rebuild_from_template; retry=$((retry+1)); continue; }

    # T3
    invalid_conf=$(jq '[.predicted_impact.affected_modules[]?.confidence |
                       select(. != null and (. < 0 or . > 1))] | length' "$target")
    [ "$invalid_conf" -gt 0 ] && { rescore_confidence; retry=$((retry+1)); continue; }

    # T4
    actual_changed=$(jq '.changed_files | length' "$target")
    [ "$actual_changed" -eq "$CHANGED_COUNT" ] || { rescope; retry=$((retry+1)); continue; }

    return 0
  done
  die "E001" "Phase 6 POST-GATE fail after 3 retries"
}
```

**On PASS:**
1. Append `session-log.json` event `COMPLETE` Phase 6 (hoặc SKIP)
2. Update `integrity-status.json`:
   - `.phases_completed += [6]`
   - `.current_phase = 7`
3. TodoWrite: Phase 6 = completed, Phase 7 = in_progress

---

## §E Phase Report Template (CORE-028)

```markdown
## Phase 6: Phân tích regression scope — PASS
Thời gian: 2026-05-15T14:51:25+07:00

**Đã làm:**
- So sánh code hiện tại với baseline ref `main` (45 file thay đổi)
- Dùng GitNexus phân tích phụ thuộc lan tỏa cấp 2-3

**Kết quả:**
- File thay đổi: 45 (chế độ predictive)
- Module bị ảnh hưởng: 6 (Orders, Finance, CRM, ...)
- Workflow bị ảnh hưởng: 12
- Test plan đề xuất: 28 test (unit + integration + e2e)

**Tiếp theo:**
- Phase 7 — Phát hiện GAP + đề xuất artifact bổ sung (2-5 phút)
```

---

## §F Error Code Quick Reference (Phase 6 namespace E060-E069)

| Code | Severity | Description | Auto-fix |
|------|---------|-------------|----------|
| E060 | high | Aggregation missing | Re-run Phase 5 |
| E061 | high | --since invalid ref | ESCALATE user fix |
| E062 | medium | GitNexus unavailable, git fallback | Downgrade predictive → diff-aware, WARN |
| E063 | medium | Scope mismatch (files outside scope) | Filter, WARN |
| E064 | medium | Predictive confidence too low (>50% predictions) | Downgrade diff-aware, WARN |
| E065 | low | No changed files since ref | EXIT 0 với "no changes" report |
| E066 | medium | Test plan generation fail (no test files) | Skip test plan, WARN |
| E067 | low | Cross-module prediction confidence threshold | Filter low-confidence |
| E068 | medium | Affected module count > 10 (system-wide) | WARN, log all but cap report |
| E069 | low | Git log history limited (<5 commits) | Use partial, WARN |

---

## §G Cross-References

| Reference | Section |
|-----------|---------|
| `_shared.md` | §1, §3, §12 CI Detection (GitNexus impact + detect_changes) |
| `docs/04-skill-design/wf-cmi/03-phase-routing.md` | §6 Regression-aware skipping |
| `docs/04-skill-design/wf-cmi/04-file-contract.md` | §4.4 regression-map-v1 schema |
| `templates/regression-map.json`, `regression-report.md` | Templates |
| `_contract.json §outputs.working[]` | Phase 6 paths |

---

## §H Next

Phase 6 PASS → Read `procedures/phase7-gap-cdg.md` cho GAP detection + CDG decisions.
