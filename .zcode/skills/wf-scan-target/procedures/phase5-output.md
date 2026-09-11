# Phase 5 — Output Generation + POST-GATE T1-T4

> **Sprint 3 lazy-load refactor.** Tạo tất cả output files từ templates, T1-T4 POST-GATE
> validation, append COMPLETE event vào trace, cleanup lock, hiển thị output report.

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §Helper Functions (`save_checkpoint`)
- `_shared.md` §Template Usage Rule (CORE-031)
- `_shared.md` §FAIL Event Handler (Protocol 15)

## Load Condition

Chạy sau Phase 3 POST-GATE PASS (Phase 4 nếu có `--compare`).

---

## PRE-GATE

```
- Phase 3 POST-GATE PASS (crud_matrix, key_features, completeness_estimate)
- IF compare_path: Phase 4 POST-GATE PASS (gap_matrix, gap_metrics)
- $L1_RESULT/$L2_RESULT/$L3_RESULT/$L4_RESULT từ Phase 2 (hoặc resume từ intermediate/)
- $RUN_SEQ set (từ Phase 0.5b)
```

## INPUT

| Variable | From | Description |
|----------|------|-------------|
| All Phase 2/3/4 state vars | Upstream | Layer outputs + synthesis + gap |
| `$SESSION_ID`, `$SESSION_DIR` | Phase 0 | Output paths |
| `$compare_path` | Phase 0 | Trigger gap-report.md |
| `$RUN_SEQ` | Phase 0.5b | Cho COMPLETE event |

## Steps

### 5.0 — Cache Hit Hydration (Sprint 6 multi-dev safety — Q2 = A)

> **Khi `$CACHE_HIT == "true"` (set ở Phase 1.5):** target-map.json đã copy từ cache vào
> $SESSION_DIR. Phase 2-4 đã skip nên state vars (L1-L4_RESULT, crud_matrix, key_features, ...)
> chưa populate. Step này hydrate state vars từ cached target-map.json để Steps 5.1+ chạy bình thường.
>
> **Khi cache miss (default):** Skip step này, dùng state vars từ Phase 2-4 đã populate.

```bash
if [[ "${CACHE_HIT:-false}" == "true" ]]; then
  TM="$SESSION_DIR/target-map.json"
  Log: "Hydrating Phase 5 state vars từ cached target-map.json"

  # Hydrate Layer results từ .layers
  L1_RESULT=$(jq -c '.layers.file_structure // {}'  "$TM")
  L2_RESULT=$(jq -c '{endpoints: (.layers.api_endpoints // []),
                      total_endpoints: ((.layers.api_endpoints // []) | length)}' "$TM")
  L3_RESULT=$(jq -c '{screens: (.layers.ui_screens // []),
                      components: (.layers.ui_components // []),
                      total_screens: ((.layers.ui_screens // []) | length),
                      total_components: ((.layers.ui_components // []) | length)}' "$TM")
  L4_RESULT=$(jq -c '{entities: (.layers.entities // []),
                      total_entities: ((.layers.entities // []) | length)}' "$TM")

  # Hydrate synthesis từ .feature_inventory
  crud_matrix=$(jq -c '.feature_inventory.crud_matrix // {}' "$TM")
  business_rules=$(jq -c '.feature_inventory.business_rules // []' "$TM")
  key_features=$(jq -c '.feature_inventory.key_features // []' "$TM")
  completeness_estimate=$(jq -r '.summary.completeness_estimate // 0' "$TM")

  # Gap matrix (nếu có)
  gap_matrix=$(jq -c '.gap_analysis.matrix // null' "$TM")
  gap_metrics=$(jq -c '.gap_analysis.metrics // null' "$TM")

  Log: "Hydrated: ${L1_RESULT:0:50}... + crud_matrix + key_features"
fi
```

### 5.1 — Write module-map.md

```
Template Usage Rule:
  READ .claude/skills/workflow/wf-scan-target/templates/module-map.md
  POPULATE:
    [MODULE_NAME]        → module_name
    [SCAN_DATE]          → now()
    [TARGET]             → target
    [TARGET_TYPE]        → target_type
    [TECH_STACK]         → detected_tech_stack.join(", ")
    [SCAN_DEPTH]         → scan_depth
    [SESSION_ID]         → SESSION_ID
    [FILE_TREE]          → format L1_RESULT.dir_structure as tree
    [TOTAL_FILES]        → L1_RESULT.total_files
    [BACKEND_COUNT]      → count .cs or .go or .py files
    [FRONTEND_COUNT]     → count .tsx or .vue files
    [TEST_COUNT]         → count test files
    [API_ENDPOINTS_TABLE] → format L2_RESULT.endpoints as markdown table
    [ENDPOINT_COUNT]     → L2_RESULT.total_endpoints
    [SCREENS_TABLE]      → format L3_RESULT.screens as markdown table
    [COMPONENT_COUNT]    → L3_RESULT.total_components
    [SCREEN_COUNT]       → L3_RESULT.total_screens
    [ENTITIES_TABLE]     → format L4_RESULT.entities as markdown table
    [ENTITY_COUNT]       → L4_RESULT.total_entities
    [CRUD_TABLE]         → format crud_matrix as markdown table
    [BUSINESS_RULES]     → format business_rules as bullet list
    [KEY_FEATURES_LIST]  → format key_features as bullet list
    [COMPLETENESS]       → completeness_estimate
    [STRENGTHS]          → infer from completeness + layer data
    [GAPS]               → infer from MISSING in crud_matrix
    [RECOMMENDATIONS]    → suggest next steps
  WRITE {SESSION_DIR}/module-map.md
```

### 5.2 — Write target-map.json (v2 schema — Sprint 5 cross-skill)

> **Sprint 5 cross-skill:** Populate target-map v2 schema bao gồm `scan_fingerprint`,
> `previous_scans[]`, `scan_diff`, `traceability`, `module_code_mapping`, `consumer_hints`.
> Backward-compat: giữ nguyên fields v1; consumers detect via `$schema` value.

```
Template Usage Rule:
  READ .claude/skills/workflow/wf-scan-target/templates/target-map.json
  POPULATE:
    # v1 fields (giữ nguyên)
    [SCAN_DATE]              → now() ISO-8601
    [SESSION_ID]             → SESSION_ID
    [TARGET]                 → target
    [TARGET_TYPE]            → target_type
    [MODULE_NAME]            → module_name
    [TECH_STACK]             → detected_tech_stack
    [SCAN_DEPTH]             → scan_depth
    [SCAN_PROFILE]           → scan_profile (default "standard"; Sprint 7 sẽ derive từ --profile)
    [LAYERS]                 → L1_RESULT + L2_RESULT + L3_RESULT + L4_RESULT
    [FEATURE_INVENTORY]      → crud_matrix + business_rules + key_features
    [GAP_ANALYSIS]           → gap_matrix + gap_metrics (nếu có --compare, else null)
    [SUMMARY]                → completeness_estimate + counts + strengths + gaps + recommendations

    # v2 fields (Sprint 5 — populate via 5.2a-e bên dưới)
    [SCAN_FINGERPRINT]       → từ Phase 1.4 ($TARGET_FINGERPRINT)
    [PREVIOUS_SCANS]         → từ scans-index.jsonl query (Step 5.2a)
    [SCAN_DIFF]              → compare với PREV_SCANS[0] target-map (Step 5.2b)
    [TRACEABILITY]           → grep REQ-ID/FEAT-ID trong scan_root (Step 5.2c)
    [MODULE_CODE_MAPPING]    → derive từ key_files paths (Step 5.2d)
    [CONSUMER_HINTS]         → populate động per consumer skill (Step 5.2e)

  WRITE {SESSION_DIR}/target-map.json
  VALIDATE: jq empty {SESSION_DIR}/target-map.json
```

#### 5.2a — Query previous scans

```bash
# scans-index.jsonl được populate bởi Sprint 6 (multi-dev safety) — Sprint 5 graceful skip
INDEX_FILE=".mc-data/work/wf-scan-target/_shared/scans-index.jsonl"

if [[ -f "$INDEX_FILE" ]]; then
  PREV_SCANS=$(jq -s --arg target "$TARGET" \
    '[.[] | select(.target == $target and .session_id != "'"$SESSION_ID"'")] |
     sort_by(.completed_at) | reverse | .[0:3] |
     map({session_id: .session_id, completed_at: .completed_at, fingerprint: .fingerprint})' \
    "$INDEX_FILE" 2>/dev/null || echo "[]")
else
  PREV_SCANS="[]"
fi
```

#### 5.2b — Compute scan_diff (chỉ khi có previous scan)

```bash
SCAN_DIFF="null"
PREV_COUNT=$(jq 'length' <<< "$PREV_SCANS")

if [[ "$PREV_COUNT" -gt 0 ]]; then
  PREV_SESSION_ID=$(jq -r '.[0].session_id' <<< "$PREV_SCANS")
  PREV_FP=$(jq -r '.[0].fingerprint' <<< "$PREV_SCANS")
  PREV_TARGET_MAP=".mc-data/work/wf-scan-target/sessions/$PREV_SESSION_ID/target-map.json"

  if [[ -f "$PREV_TARGET_MAP" ]] && [[ "$PREV_FP" != "$TARGET_FINGERPRINT" ]]; then
    # Diff endpoints (method+path) và entities (name)
    PREV_ENDPOINTS=$(jq -c '[.layers.api_endpoints[] | "\(.method) \(.path)"] // []' "$PREV_TARGET_MAP")
    CURR_ENDPOINTS=$(jq -c '[.layers.api_endpoints[] | "\(.method) \(.path)"] // []' <<< "$TARGET_MAP_DRAFT")
    PREV_ENTITIES=$(jq -c '[.layers.entities[]?.name] // []' "$PREV_TARGET_MAP")
    CURR_ENTITIES=$(jq -c '[.layers.entities[]?.name] // []' <<< "$TARGET_MAP_DRAFT")

    ADDED_EP=$(jq -c --argjson prev "$PREV_ENDPOINTS" '. - $prev' <<< "$CURR_ENDPOINTS")
    REMOVED_EP=$(jq -c --argjson curr "$CURR_ENDPOINTS" '. - $curr' <<< "$PREV_ENDPOINTS")
    ADDED_ENT=$(jq -c --argjson prev "$PREV_ENTITIES" '. - $prev' <<< "$CURR_ENTITIES")
    REMOVED_ENT=$(jq -c --argjson curr "$CURR_ENTITIES" '. - $curr' <<< "$PREV_ENTITIES")

    SCAN_DIFF=$(jq -n \
      --arg ps "$PREV_SESSION_ID" \
      --argjson aep "$ADDED_EP" --argjson rep "$REMOVED_EP" \
      --argjson aen "$ADDED_ENT" --argjson ren "$REMOVED_ENT" \
      '{previous_session: $ps,
        added_endpoints: $aep,
        removed_endpoints: $rep,
        added_entities: $aen,
        removed_entities: $ren,
        modified_entities: []}')
  fi
fi
# IF PREV_COUNT == 0 → SCAN_DIFF stays "null" (first scan của target này)
# IF fingerprint match → cũng giữ "null" (no change)
```

#### 5.2c — Compute traceability

```bash
# Grep REQ-ID/FEAT-ID patterns trong scan_root code files
# Lazy approach: chỉ scan code extensions chính (.cs/.ts/.tsx/.js/.jsx/.py/.go/.java/.kt/.swift/.rb/.php)

REQ_IDS=$(grep -rh -E "REQ-[A-Z]+-[0-9]+" "$SCAN_ROOT" \
  --include="*.cs" --include="*.ts" --include="*.tsx" \
  --include="*.js" --include="*.jsx" --include="*.py" \
  --include="*.go" --include="*.java" --include="*.kt" \
  --include="*.swift" --include="*.rb" --include="*.php" \
  2>/dev/null | grep -oE "REQ-[A-Z]+-[0-9]+" | sort -u || true)

FEAT_IDS=$(grep -rh -E "FEAT-[A-Z]+-[0-9A-Z]+" "$SCAN_ROOT" \
  --include="*.cs" --include="*.ts" --include="*.tsx" \
  --include="*.js" --include="*.jsx" --include="*.py" \
  --include="*.go" --include="*.java" --include="*.kt" \
  --include="*.swift" --include="*.rb" --include="*.php" \
  2>/dev/null | grep -oE "FEAT-[A-Z]+-[0-9A-Z]+" | sort -u || true)

FILES_WITH_TRACE=$(grep -rl -E "(REQ|FEAT)-[A-Z]+-[0-9A-Z]+" "$SCAN_ROOT" \
  --include="*.cs" --include="*.ts" --include="*.tsx" \
  --include="*.js" --include="*.jsx" --include="*.py" \
  --include="*.go" --include="*.java" --include="*.kt" \
  --include="*.swift" --include="*.rb" --include="*.php" \
  2>/dev/null | wc -l || echo 0)

FILES_TOTAL=$(jq -r '.total_files // 0' "$SESSION_DIR/intermediate/l1-structure.json")

TRACE_PCT=0
if [[ "$FILES_TOTAL" -gt 0 ]]; then
  TRACE_PCT=$(( FILES_WITH_TRACE * 100 / FILES_TOTAL ))
fi

REQ_IDS_JSON=$(printf '%s\n' "$REQ_IDS" | jq -R . | jq -s 'map(select(. != ""))')
FEAT_IDS_JSON=$(printf '%s\n' "$FEAT_IDS" | jq -R . | jq -s 'map(select(. != ""))')

TRACEABILITY=$(jq -n \
  --argjson req "$REQ_IDS_JSON" \
  --argjson feat "$FEAT_IDS_JSON" \
  --argjson fwt "$FILES_WITH_TRACE" \
  --argjson ft "$FILES_TOTAL" \
  --argjson pct "$TRACE_PCT" \
  '{req_ids_found_in_code: $req,
    feat_ids_found_in_code: $feat,
    files_with_traceability: $fwt,
    files_total: $ft,
    traceability_pct: $pct}')
```

#### 5.2d — Compute module_code_mapping

```bash
# Group key_files theo module:
#   - Nếu --module được chỉ định: module_code_mapping = { $module: [path patterns from key_files] }
#   - Nếu không: derive từ Eureka.Modules.X pattern (.NET) hoặc apps/X (monorepo)

MODULE_CODE_MAPPING="{}"

if [[ -n "$module_name" && "$module_name" != "auto" ]]; then
  # Use --module value as key, key_files paths as values (deduplicate by directory)
  PATHS=$(jq -r '.layers.file_structure.key_files | to_entries[] | .value[]?' \
    <<< "$TARGET_MAP_DRAFT" 2>/dev/null | \
    sed 's|/[^/]*$|/**|' | sort -u | jq -R . | jq -s . || echo "[]")
  MODULE_CODE_MAPPING=$(jq -n --arg m "$module_name" --argjson p "$PATHS" '{($m): $p}')
else
  # Auto-derive: detect Eureka.Modules.X hoặc apps/X patterns
  PATTERNS=$(echo "$SCAN_ROOT" | grep -oE "(Eureka\.Modules\.[A-Z][a-z]+|apps/[a-z][a-z0-9-]+)" | sort -u || true)
  if [[ -n "$PATTERNS" ]]; then
    while IFS= read -r pat; do
      slug=$(echo "$pat" | sed 's|^Eureka\.Modules\.||' | sed 's|^apps/||' | tr '[:upper:]' '[:lower:]')
      MODULE_CODE_MAPPING=$(jq --arg s "$slug" --arg p "$pat/**" \
        '. + {($s): [$p]}' <<< "$MODULE_CODE_MAPPING")
    done <<< "$PATTERNS"
  fi
fi
```

#### 5.2e — Build consumer_hints

```bash
# Detect consumer skills availability
HAS_ADD_SCOPE=$(test -f .claude/skills/workflow/wf-add-scope/SKILL.md && echo true || echo false)
HAS_DEFINE_FEATURES=$(test -f .claude/skills/workflow/wf-define-features/SKILL.md && echo true || echo false)
HAS_DESIGN=$(test -f .claude/skills/workflow/wf-design/SKILL.md && echo true || echo false)
HAS_IMPL_FEATURE=$(test -f .claude/skills/workflow/wf-implement-feature/SKILL.md && echo true || echo false)

MODULES_COUNT=$(jq 'keys | length' <<< "$MODULE_CODE_MAPPING")
HAS_CRUD=$(jq -r 'if (.feature_inventory.crud_matrix // {} | keys | length) > 0 then "true" else "false" end' <<< "$TARGET_MAP_DRAFT")

# Module names cho seed
MODULES_TO_SEED=$(jq 'keys' <<< "$MODULE_CODE_MAPPING")

CONSUMER_HINTS=$(jq -n \
  --arg sid "$SESSION_ID" \
  --arg sdir "$SESSION_DIR" \
  --argjson mts "$MODULES_TO_SEED" \
  --arg has_add "$HAS_ADD_SCOPE" \
  --arg has_def "$HAS_DEFINE_FEATURES" \
  --arg has_des "$HAS_DESIGN" \
  --arg has_imp "$HAS_IMPL_FEATURE" \
  --argjson mcount "$MODULES_COUNT" \
  --arg has_crud "$HAS_CRUD" \
  '{
    "wf-add-scope": {
      ready: ($has_add == "true" and $mcount > 0),
      command: (if ($has_add == "true" and $mcount > 0)
                then "/wf-add-scope --from-scan=\($sid) --system=<SYS-ID>"
                else null end),
      modules_to_seed: $mts,
      features_to_seed: []
    },
    "wf-define-features": {
      ready: ($has_def == "true"),
      useful_for: "context-suggestion",
      feed_path: (if $has_def == "true" then "\($sdir)/feature-inventory.md" else null end)
    },
    "wf-design": {
      ready: ($has_des == "true"),
      useful_for: "gap-analysis-baseline",
      feed_path: (if $has_des == "true" then "\($sdir)/target-map.json" else null end)
    },
    "wf-implement-feature": {
      ready: ($has_imp == "true"),
      useful_for: "context-priming",
      use_crud_matrix: ($has_imp == "true" and $has_crud == "true")
    }
  }')
```

#### 5.2f — Compute delta_scan field (Sprint 7 PHẦN B — chỉ khi `--since` set)

```bash
# Sprint 7 PHẦN B — populate delta_scan field cho target-map.json khi --since set
DELTA_SCAN_FIELD="null"
if [[ "${DELTA_MODE:-false}" == "true" ]]; then
  DELTA_SCAN_FIELD=$(jq -n \
    --arg since "$SINCE_REF" \
    --arg head "$HEAD_REF" \
    --argjson total "$TOTAL_CHANGED" \
    '{since_ref: $since,
      head_ref: $head,
      total_changed_files: $total,
      scan_mode: "delta"}')
  Log: "Phase 5.2f: populate delta_scan field ($TOTAL_CHANGED files since $SINCE_REF)"
fi
```

#### 5.2g — Final POPULATE + WRITE

```bash
# Combine v1 fields + v2 fields → final target-map.json
# (Pseudo-code — mỗi placeholder thay bằng giá trị tương ứng)

jq --arg sid "$SESSION_ID" \
   --arg fp "$TARGET_FINGERPRINT" \
   --arg prof "$SCAN_PROFILE" \
   --argjson prev "$PREV_SCANS" \
   --argjson diff "$SCAN_DIFF" \
   --argjson trace "$TRACEABILITY" \
   --argjson mcm "$MODULE_CODE_MAPPING" \
   --argjson hints "$CONSUMER_HINTS" \
   --argjson delta "$DELTA_SCAN_FIELD" \
   '. + {
     session_id: $sid,
     scan_fingerprint: $fp,
     scan_profile: $prof,
     previous_scans: $prev,
     scan_diff: $diff,
     traceability: $trace,
     module_code_mapping: $mcm,
     consumer_hints: $hints,
     delta_scan: $delta
   }' "$TARGET_MAP_DRAFT" > "$SESSION_DIR/target-map.json"

# Validate
jq empty "$SESSION_DIR/target-map.json" || FAIL "target-map.json invalid JSON"
```

### 5.3 — Write feature-inventory.md

```
Template Usage Rule:
  READ .claude/skills/workflow/wf-scan-target/templates/feature-inventory.md
  POPULATE: crud_matrix, business_rules, key_features
  WRITE {SESSION_DIR}/feature-inventory.md
```

### 5.4 — Write gap-report.md (conditional)

```
IF compare_path is not null:
  Template Usage Rule:
    READ .claude/skills/workflow/wf-scan-target/templates/gap-report.md
    POPULATE: gap_matrix, gap_metrics, spec info
    WRITE {SESSION_DIR}/gap-report.md
```

### 5.4b — Write phase-summary.md (GAP-02 fix — Protocol 14 / CORE-028)

> Tạo phase-summary.md tiếng Việt cho non-specialist. BẮT BUỘC sau POST-GATE structural checks pass.
> Q5 = B (KHÔNG Stakeholder Review) → chỉ thêm "Bước tiếp theo" (Actionable Next Steps).

```
Template Usage Rule (CORE-031):
  READ .claude/skills/workflow/wf-scan-target/templates/phase-summary.md
  POPULATE:
    [SCAN_DATE]          → ISO-8601 timestamp
    [STATUS]             → "HOÀN THÀNH" | "HOÀN THÀNH CÓ LƯU Ý" | "THẤT BẠI"
    [SESSION_ID]         → SESSION_ID
    [TARGET_TYPE]        → target_type
    [TARGET]             → target
    [TECH_STACK]         → detected_tech_stack.join(", ")
    [FILE_COUNT]         → L1_RESULT.total_files
    [DIR_COUNT]          → len(L1_RESULT.dir_structure)
    [ENDPOINT_COUNT]     → L2_RESULT.total_endpoints
    [SCREEN_COUNT]       → L3_RESULT.total_screens
    [ENTITY_COUNT]       → L4_RESULT.total_entities
    [FEATURE_COUNT]      → len(key_features)
    [OUTPUT_FILE_COUNT]  → 4 (hoặc 5 nếu --compare)
    [COMPLETENESS]       → completeness_estimate
    [STRENGTHS_AND_GAPS] → tiếng Việt — điểm mạnh + gap chính (≤ 5 dòng)
    [RECOMMENDATIONS]    → tiếng Việt — actionable next steps (≤ 5 dòng)
    [GAP_REPORT_LINE]    → "" hoặc "- gap-report.md cho thấy [N] features cần implement"
  WRITE {SESSION_DIR}/phase-summary.md

Display: cat {SESSION_DIR}/phase-summary.md (hiển thị nội dung cho user — Protocol 14.4)
```

### 5.5 — Update scan-status.json

```
READ {SESSION_DIR}/scan-status.json
UPDATE:
  status = "completed"
  verdict = "pass"
  completed_at = now()
  results.files_scanned = L1_RESULT.total_files
  results.endpoints_found = L2_RESULT.total_endpoints
  results.screens_found = L3_RESULT.total_screens
  results.entities_found = L4_RESULT.total_entities
  results.features_identified = len(key_features)
  results.completeness_estimate = completeness_estimate
  output_files = [module-map.md, target-map.json, feature-inventory.md, phase-summary.md, ...]
WRITE {SESSION_DIR}/scan-status.json
```

### 5.5b — POST-GATE T1-T4 Validation (GAP-08 fix — Protocol 10 / CORE-012)

> Thay POST-GATE chỉ T1 (existence) bằng full T1-T4 (Existence → Structure → Content → Cross-reference).
> Tất cả T1-T4 phải PASS trước khi skill báo COMPLETE.

```bash
### T1 — Existence (file tồn tại + non-empty)
test -s {SESSION_DIR}/module-map.md          || FAIL "T1: module-map.md missing/empty"
test -s {SESSION_DIR}/target-map.json        || FAIL "T1: target-map.json missing/empty"
test -s {SESSION_DIR}/feature-inventory.md   || FAIL "T1: feature-inventory.md missing/empty"
test -s {SESSION_DIR}/phase-summary.md       || FAIL "T1: phase-summary.md missing/empty"
test -s {SESSION_DIR}/scan-status.json       || FAIL "T1: scan-status.json missing/empty"
IF compare_path is not null:
  test -s {SESSION_DIR}/gap-report.md        || FAIL "T1: gap-report.md missing/empty"

### T2 — Structure (required headings/keys)
required_headings_module_map=(
  "## 1\. Tổng Quan"
  "## 2\. API Endpoints"
  "## 3\. UI Screens"
  "## 4\. Entities"
  "## 5\. Feature Inventory"
  "## 6\. Summary"
)
for h in "${required_headings_module_map[@]}"; do
  grep -q "^${h}" {SESSION_DIR}/module-map.md || FAIL "T2: module-map.md missing heading: $h"
done

# target-map.json required keys
for k in layers feature_inventory summary; do
  jq -e ".$k" {SESSION_DIR}/target-map.json > /dev/null || FAIL "T2: target-map.json missing key: $k"
done

# Sprint 5 cross-skill — target-map v2 schema fields
jq -e '.["$schema"] == "target-map-v2"' {SESSION_DIR}/target-map.json > /dev/null \
  || FAIL "T2: target-map.json $schema sai (expect target-map-v2)"
for k in scan_fingerprint module_code_mapping consumer_hints traceability; do
  jq -e ".$k" {SESSION_DIR}/target-map.json > /dev/null || FAIL "T2: target-map.json thiếu key v2: $k"
done

# phase-summary.md required sections (Protocol 14)
grep -q "^## Đã làm gì"     {SESSION_DIR}/phase-summary.md || FAIL "T2: phase-summary.md missing 'Đã làm gì'"
grep -q "^## Kết quả"       {SESSION_DIR}/phase-summary.md || FAIL "T2: phase-summary.md missing 'Kết quả'"
grep -q "^## Bước tiếp theo" {SESSION_DIR}/phase-summary.md || FAIL "T2: phase-summary.md missing 'Bước tiếp theo'"

### T3 — Content depth (đảm bảo non-trivial output)
words_module_map=$(wc -w < {SESSION_DIR}/module-map.md)
[[ $words_module_map -ge 200 ]] || FAIL "T3: module-map.md too short ($words_module_map words, need ≥ 200)"

words_phase_summary=$(wc -w < {SESSION_DIR}/phase-summary.md)
[[ $words_phase_summary -ge 50 ]] || FAIL "T3: phase-summary.md too short ($words_phase_summary words, need ≥ 50)"

### T4 — Cross-reference (entities consistency JSON ↔ MD)
# Entities trong target-map.json phải xuất hiện trong module-map.md (subset check)
entities_json=$(jq -r '.layers.entities[]?.name // empty' {SESSION_DIR}/target-map.json | sort -u)
IF entities_json không rỗng:
  for entity in $entities_json:
    grep -q "$entity" {SESSION_DIR}/module-map.md \
      || WARN "T4: Entity '$entity' có trong target-map.json nhưng không có trong module-map.md"
  # Allow MD có entities nhiều hơn JSON (notes/examples) — không FAIL ở chiều ngược lại

# Tất cả T1-T4 pass → POST-GATE PASS
Log: "POST-GATE T1-T4 PASS"
```

### 5.5c — Append session-log.json COMPLETE event (GAP-03 fix — Protocol 15)

```bash
TRACE_FILE=".mc-data/work/_trace/session-log.json"

# Đếm files_created (output files thực sự ghi)
FILES_CREATED=4
[[ -n "$compare_path" ]] && FILES_CREATED=5

tmp=$(mktemp)
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg sid "$SESSION_ID" \
   --argjson fc "$FILES_CREATED" \
   --argjson rs "$RUN_SEQ" \
   '.entries += [{
      timestamp: $ts,
      skill: "/wf-scan-target",
      event: "COMPLETE",
      run_sequence: $rs,
      phase: "Phase 5",
      session_id: $sid,
      files_created: $fc,
      files_modified: 0,
      warnings: [],
      errors: [],
      decisions: []
    }]' "$TRACE_FILE" > "$tmp" && mv "$tmp" "$TRACE_FILE"
```

### 5.5d — Save Final Checkpoint + Cleanup Lock (GAP-05 — Sprint 2 / Sprint 6 hardening)

```bash
save_checkpoint --phase phase_5 --status completed \
                --next-phase null --next-step done

# Cleanup lock file. Sprint 6: trap EXIT trong Phase 0.3c đã đảm bảo cleanup trên exit;
# explicit release_lock ở đây để release SỚM (trước khi skill print final report).
release_lock "$SESSION_DIR/.lock"
Log: "Lock released — session $SESSION_ID hoàn tất"
```

### 5.5e — Append _shared/scans-index.jsonl (Sprint 6 multi-dev safety)

> **Purpose:** Mỗi scan completed append 1 entry vào `_shared/scans-index.jsonl`.
> Consumer (Sprint 5 phase5-output Step 5.2a) query JSONL này để populate `previous_scans[]`
> trong target-map.json v2. JSONL format git-sync friendly — 2 dev cùng scan cùng target
> commit độc lập, git auto-merge không conflict.
>
> **Scope:** CHỈ append khi POST-GATE T1-T4 PASS (status=completed). Nếu skill FAIL,
> entry KHÔNG được append (FAIL handler trong `_shared.md` skip step này).

```bash
INDEX_FILE=".mc-data/work/wf-scan-target/_shared/scans-index.jsonl"

# Template Usage Rule (CORE-031): READ template → POPULATE → APPEND (không WRITE atomic vì JSONL)
TEMPLATE=".claude/skills/workflow/wf-scan-target/templates/scans-index-entry.json"

# Read metrics từ scan-status.json (đã update ở Step 5.5)
METRICS=$(jq -c '{files_scanned: .results.files_scanned // 0,
                  endpoints_found: .results.endpoints_found // 0,
                  screens_found: .results.screens_found // 0,
                  entities_found: .results.entities_found // 0,
                  completeness_pct: .results.completeness_estimate // 0}' \
            "$SESSION_DIR/scan-status.json")

TECH_STACK_JSON=$(jq -c '. // []' <<< "$DETECTED_TECH_STACK_JSON" 2>/dev/null || echo '[]')

ENTRY=$(jq -nc \
  --arg sid       "$SESSION_ID" \
  --arg target    "$target" \
  --arg ttype     "$target_type" \
  --argjson tech  "$TECH_STACK_JSON" \
  --arg mod       "${module_name:-auto}" \
  --arg depth     "$scan_depth" \
  --arg profile   "${SCAN_PROFILE:-standard}" \
  --arg fp        "$TARGET_FINGERPRINT" \
  --arg started   "$(jq -r '.started_at' "$SESSION_DIR/scan-status.json")" \
  --arg completed "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg host      "$(hostname 2>/dev/null || echo "${HOSTNAME:-unknown}")" \
  --arg user      "${USER:-unknown}" \
  --argjson metr  "$METRICS" \
  '{
    "$schema":         "scans-index-entry-v1",
    session_id:        $sid,
    target:            $target,
    target_type:       $ttype,
    tech_stack:        $tech,
    module_name:       $mod,
    scan_depth:        $depth,
    scan_profile:      $profile,
    scan_fingerprint:  $fp,
    started_at:        $started,
    completed_at:      $completed,
    status:            "completed",
    host:              $host,
    user:              $user,
    metrics:           $metr
  }')

# JSONL append qua helper từ scan-target-common.sh
append_jsonl "$INDEX_FILE" "$ENTRY"
Log: "Appended scans-index entry — $INDEX_FILE"
```

### 5.5f — Append _shared/history.jsonl (Sprint 6 — rotation log compact)

> **Purpose:** History log gọn nhẹ (chỉ session_id + completed_at + status) cho rotation
> 200-entry max ở Sprint 7. Khác scans-index.jsonl (full metadata) — history.jsonl chỉ
> dùng nội bộ để rotation/cleanup. Sprint 7 sẽ thêm logic trim khi vượt 200 entries.

```bash
HISTORY_FILE=".mc-data/work/wf-scan-target/_shared/history.jsonl"

HIST_ENTRY=$(jq -nc \
  --arg sid       "$SESSION_ID" \
  --arg completed "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{session_id: $sid, completed_at: $completed, status: "completed"}')

append_jsonl "$HISTORY_FILE" "$HIST_ENTRY"
Log: "Appended history entry — $HISTORY_FILE"
```

### 5.5g — Cache Write (Sprint 6 multi-dev safety — Q2 = A)

> **Purpose:** Sau khi scan completed (POST-GATE T1-T4 PASS), copy `target-map.json` vào
> `_shared/cache/{TARGET_FINGERPRINT}.json` để future scans cùng fingerprint hit cache.
> Atomic write qua tmp+mv pattern. Cache file là `.gitignore`'d (per-machine).
>
> **Skip condition:**
> - `NO_CACHE=true` → KHÔNG ghi cache (user yêu cầu fresh scan, không update cache)
> - `CACHE_HIT=true` → KHÔNG ghi lại cache (đã reuse, không cần overwrite chính nó)
> - `DELTA_MODE=true` (Sprint 7) → KHÔNG ghi cache (delta scan = subset, không thay thế full scan cache)

```bash
if [[ "${NO_CACHE:-false}" != "true" ]] \
   && [[ "${CACHE_HIT:-false}" != "true" ]] \
   && [[ "${DELTA_MODE:-false}" != "true" ]]; then
  CACHE_DIR=".mc-data/work/wf-scan-target/_shared/cache"
  CACHE_FILE="$CACHE_DIR/${TARGET_FINGERPRINT}.json"
  mkdir -p "$CACHE_DIR"

  # Atomic write: cp → sync → mv
  cp "$SESSION_DIR/target-map.json" "$CACHE_FILE.tmp.$$"
  sync "$CACHE_FILE.tmp.$$" 2>/dev/null || true
  mv "$CACHE_FILE.tmp.$$" "$CACHE_FILE"

  Log: "Cache write — $CACHE_FILE (fingerprint ${TARGET_FINGERPRINT:0:16}..., TTL 24h)"
else
  Log: "Cache write skipped (NO_CACHE=${NO_CACHE:-false}, CACHE_HIT=${CACHE_HIT:-false}, DELTA_MODE=${DELTA_MODE:-false})"
fi
```

### 5.6 — Output Report

```
Display to user:

## /wf-scan-target Hoàn tất! ✓

| Mục | Giá trị |
|-----|---------|
| Target | {target} |
| Module | {module_name} |
| Tech Stack | {detected_tech_stack.join(", ")} |
| Files scanned | {L1_RESULT.total_files} |
| API Endpoints | {L2_RESULT.total_endpoints} |
| UI Screens | {L3_RESULT.total_screens} |
| Entities | {L4_RESULT.total_entities} |
| Features identified | {len(key_features)} |
| Completeness est. | {completeness_estimate}% |
| Session | {SESSION_DIR} |

### Output Files
- 📄 Module Map:      {SESSION_DIR}/module-map.md
- 📊 JSON Metadata:   {SESSION_DIR}/target-map.json
- 📋 Feature Inv.:    {SESSION_DIR}/feature-inventory.md
{- 🔍 Gap Report:     {SESSION_DIR}/gap-report.md}  ← nếu --compare

### Bước tiếp theo
- Đọc module-map.md để xem overview đầy đủ
- target-map.json có thể dùng làm input cho /wf-implement-feature hoặc /wf-define-features
{- gap-report.md cho thấy {gap_metrics.missing} features cần implement}
```

## POST-GATE

```
- T1-T4 đã PASS (5.5b)
- scan-status.json: status=completed, verdict=pass
- checkpoint.json: phase_5=completed, next_phase=null
- .lock file đã release_lock
- session-log.json có entry COMPLETE
- _shared/scans-index.jsonl có 1 entry mới (Sprint 6)
- _shared/history.jsonl có 1 entry mới (Sprint 6)
- _shared/cache/{fingerprint}.json đã ghi (Sprint 6 — chỉ khi NO_CACHE != true)
```

## OUTPUT (final)

| File | Path |
|------|------|
| `module-map.md` | `{SESSION_DIR}/module-map.md` |
| `target-map.json` | `{SESSION_DIR}/target-map.json` |
| `feature-inventory.md` | `{SESSION_DIR}/feature-inventory.md` |
| `phase-summary.md` | `{SESSION_DIR}/phase-summary.md` |
| `gap-report.md` | `{SESSION_DIR}/gap-report.md` (chỉ khi `--compare`) |
| `scan-status.json` | `{SESSION_DIR}/scan-status.json` (status=completed) |
| `checkpoint.json` | `{SESSION_DIR}/checkpoint.json` (final state) |
| `scans-index.jsonl` (append) | `_shared/scans-index.jsonl` (Sprint 6 — git-sync friendly) |
| `history.jsonl` (append) | `_shared/history.jsonl` (Sprint 6 — compact rotation log) |
| cache file (per-machine) | `_shared/cache/{TARGET_FINGERPRINT}.json` (Sprint 6 — `.gitignore`'d, TTL 24h) |

## Next Phase

→ STOP (DONE). Skill execution complete.

---

## Failure Path

> Nếu T1-T4 fail sau 3 retries hoặc gặp E001/E002 không recoverable, route đến FAIL handler.
> Xem `_shared.md §FAIL Event Handler (Protocol 15)` cho full procedure:
> 1. Append FAIL event vào session-log.json
> 2. Tạo phase-summary.md với STATUS = "THẤT BẠI"
> 3. Update scan-status.json: status="failed", verdict="fail"
> 4. Update checkpoint.json: phase_states[CURRENT_PHASE]="failed"
> 5. GIỮ NGUYÊN .lock file (--resume sẽ cleanup nếu PID dead)
