# Phase 3 — Synthesis & Feature Inventory

> **Sprint 3 lazy-load refactor + Sprint 4 Q3 split.** Tổng hợp layer outputs → tạo CRUD matrix,
> business rules (3.1 — developer agent code-derived), key features tiếng Việt
> (3.2 — business-analyst agent compressed input), completeness estimate.
>
> **Q3 decision (2026-04-27):** developer agent xử lý code semantics (CRUD + validators),
> business-analyst agent xử lý ngôn ngữ user-facing (humanize features sang tiếng Việt).
> Apply Protocol 6.2 — BA nhận DIGEST từ 3.1 output, KHÔNG nhận raw L1-L4.

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §Agent Prompt Templates (business-analyst, developer)
- `_shared.md` §Helper Functions (`save_checkpoint`)

## Load Condition

Chạy sau Phase 2 POST-GATE PASS (cả 4 layers complete; nếu shallow thì chỉ L1).

---

## PRE-GATE

```
- L1_RESULT (always)
- L2_RESULT, L3_RESULT, L4_RESULT (nếu scan_depth != "shallow")
- checkpoint.json: phase_2 == "completed"
```

## INPUT

| Variable | From | Description |
|----------|------|-------------|
| `$L1_RESULT` | Phase 2 L1 | key_files |
| `$L2_RESULT` | Phase 2 L2 | endpoints |
| `$L3_RESULT` | Phase 2 L3 | screens |
| `$L4_RESULT` | Phase 2 L4 | entities |
| `$detected_tech_stack` | Phase 1 | Routing |
| `$module_name` | Phase 1 | BA agent input |
| `$scan_root` | Phase 1 | Validator file glob |
| `$compare_path` | Phase 0 | Quyết định next_phase = phase_4 vs phase_5 |

## Steps

### 3.1 — Code Synthesis (developer agent — Q3 decision)

> **Agent:** `developer` — strong ở code semantics: CRUD pattern recognition, entity relationships,
> business rules từ validators. KHÔNG dùng business-analyst ở step này (BA yếu cho code reasoning).
> Token cost: ~5K input + 3K output = ~8K (standard) | ~6K input + 5K output = ~11K (exhaustive).
>
> **Sprint 7 PHẦN C — LPM exhaustive:** Khi `$SCAN_PROFILE == "exhaustive"`:
> - Tăng business rules deep extract limit từ MAX 5 validators → MAX 15 validators
> - Documented trong agent prompt + token budget tăng accordingly

```bash
# Sprint 7 PHẦN C — Determine validators read limit theo profile
if [[ "${SCAN_PROFILE:-standard}" == "exhaustive" ]]; then
  VALIDATORS_READ_LIMIT=15
  Log: "Phase 3.1: profile=exhaustive → MAX_VALIDATORS=15 (deep business rules extract)"
else
  VALIDATORS_READ_LIMIT=5
fi
```

```
Spawn developer agent:
  Input (compressed, không raw L1-L4):
    - L1 key_files digest:
        "commands_count": <int>,
        "commands_sample": [first 30 names],
        "queries_count": <int>,
        "queries_sample": [first 30 names],
        "validators_count": <int>,
        "validators_sample": [first 10 names]
    - L2 endpoints digest:
        "endpoints_count": <int>,
        "endpoints_sample": [first 30 {method, path}]
    - L4 entities digest:
        "entities": [first 50 {name, key_fields_count, relationships_count}]
    - module_name: $module_name
    - tech_stack: $detected_tech_stack
    - validators_read_limit: $VALIDATORS_READ_LIMIT  # Sprint 7 — 5 (default) hoặc 15 (exhaustive)

  Task:
    1. Build CRUD matrix per entity (create/read/update/delete/list/search) — match commands/queries
       với entity names + verify qua endpoints (POST/GET/PUT/DELETE pattern).
    2. Extract business rules từ validator names + command/handler names. Read MAX
       $validators_read_limit validator files để extract RuleFor/Must/When/NotEmpty patterns.
       Output rule + source code reference.
       (Sprint 7 PHẦN C: exhaustive profile → 15 validators thay vì 5 → coverage rộng hơn cho
       enterprise modules với nhiều validation logic.)

  Output (JSON):
    {
      "crud_matrix": {
        "<EntityName>": {
          "create": {exists: bool, via: "<cmd_name>"},
          "read": {exists: bool, via: "<qry_name>"},
          "update": {exists: bool, via: "<cmd_name>"},
          "delete": {exists: bool, via: "<cmd_name>"},
          "list":   {exists: bool, via: "<qry_name>"},
          "search": {exists: bool, via: "<qry_name>"}
        },
        ...
      },
      "business_rules": [
        {rule: "<short EN description>", via: "<cmd/validator name>", type: "command"|"validation"}
      ]
    }
```

> **Note:** developer agent KHÔNG humanize sang tiếng Việt — đó là job của BA agent ở step 3.2.
> Business rules ở step này là code-derived (rule names tiếng Anh ngắn, tham chiếu source).

### 3.2 — Compile Key Features tiếng Việt (business-analyst agent — Q3 decision)

> **Agent:** `business-analyst` — strong ở user-facing language: humanize CreateOrder → "Tạo đơn hàng",
> aggregate features sang cấp cao tiếng Việt phù hợp cho doanh nghiệp đọc.
> Token cost: ~3K input (compressed digest) + 5K output = ~8K. Apply Protocol 6.2.
>
> **Sprint 7 PHẦN C — LPM exhaustive:** Khi `$SCAN_PROFILE == "exhaustive"`:
> - Target key_features 20-30 thay vì 10-20 (coverage rộng hơn cho enterprise modules)
> - Cross-validation check: features không duplicate + cover all entities (warn nếu coverage < 80%)
> - Token budget tăng: ~4K input + 7K output = ~11K

```bash
# Sprint 7 PHẦN C — Determine key_features target theo profile
if [[ "${SCAN_PROFILE:-standard}" == "exhaustive" ]]; then
  FEATURES_TARGET_MIN=20
  FEATURES_TARGET_MAX=30
  Log: "Phase 3.2: profile=exhaustive → key_features target 20-30 + coverage validation"
else
  FEATURES_TARGET_MIN=10
  FEATURES_TARGET_MAX=20
fi
```

```
Spawn business-analyst agent:
  Input (DIGEST từ developer output 3.1 + lightweight L3 — KHÔNG raw L1-L4):
    - crud_matrix_summary:
        "Module có {N} entities với {M} CRUD operations chính"
        "Top 10 entities: <entity names list>"
        "Top 10 operations: <Create/Update names list>"
    - business_rules_summary:
        "Module có {K} validation rules"
        "Top 10 rules: <rule names from 3.1>"
    - entities_names: $L4_RESULT.entities[].name (compact list)
    - ui_screens_names: $L3_RESULT.screens[].name (compact list, tối đa 30)
    - module_name: $module_name
    - features_target_min: $FEATURES_TARGET_MIN  # Sprint 7 — 10 (default) | 20 (exhaustive)
    - features_target_max: $FEATURES_TARGET_MAX  # Sprint 7 — 20 (default) | 30 (exhaustive)

  Task:
    Tổng hợp $features_target_min-$features_target_max key features cấp cao (tiếng Việt)
    phù hợp cho doanh nghiệp/PM đọc. KHÔNG liệt kê CRUD ops chi tiết — đã có ở 3.1.
    Tập trung capability cấp cao.

    Sprint 7 PHẦN C — Khi exhaustive: cross-validation sau khi sinh features:
    1. KHÔNG duplicate (similarity > 0.8 → merge)
    2. Cover all entities (entity name xuất hiện ≥1 lần trong features)
    3. Nếu coverage < 80% → log warning + bổ sung features cho entities chưa cover

  Output Format:
    key_features[] = [
      "Quản lý hồ sơ khách hàng (CRUD + tìm kiếm + phân loại theo segment)",
      "Theo dõi pipeline cơ hội bán hàng với 5 giai đoạn",
      "Nhật ký hoạt động cho mỗi khách hàng",
      ...
    ]
    Mỗi feature 1 dòng, bắt đầu bằng "- ", tiếng Việt rõ ràng cho non-specialist.
```

#### 3.2b — Coverage Sanity Check (Sprint 7 PHẦN C — exhaustive only)

```bash
if [[ "${SCAN_PROFILE:-standard}" == "exhaustive" ]]; then
  # Coverage check: % entities xuất hiện trong key_features
  ENTITIES_NAMES=$(jq -r '.entities[]?.name // empty' <<< "$L4_RESULT" | sort -u)
  TOTAL_ENTITIES=$(echo "$ENTITIES_NAMES" | grep -c . || echo 0)
  FEATURES_TEXT=$(jq -r '.[] // empty' <<< "$key_features_json" | tr '\n' ' ')

  COVERED=0
  while IFS= read -r entity; do
    [[ -z "$entity" ]] && continue
    if echo "$FEATURES_TEXT" | grep -iq "$entity"; then
      COVERED=$((COVERED + 1))
    fi
  done <<< "$ENTITIES_NAMES"

  if [[ "$TOTAL_ENTITIES" -gt 0 ]]; then
    COVERAGE_PCT=$(( COVERED * 100 / TOTAL_ENTITIES ))
    Log: "Phase 3.2 exhaustive coverage: $COVERED/$TOTAL_ENTITIES entities ($COVERAGE_PCT%)"
    if [[ "$COVERAGE_PCT" -lt 80 ]]; then
      log_warn "Coverage < 80% (exhaustive expects ≥ 80%) — BA agent có thể thiếu features"
    fi
  fi
fi
```

### 3.2c — Agent Spawn Failure Graceful Degradation (v2.0.1 BUG-001 fix)

> **Critical fallback path.** Phase 3.1 + 3.2 dispatch tới `developer` + `business-analyst` agents.
> Nếu Agent tool fail (quota exhausted, agent không available, timeout, etc), Phase 3 KHÔNG được hang —
> phải gracefully degrade và tiếp tục với reduced output.
>
> **Detection patterns** từ Agent tool error response:
> - "You've hit your limit" / "rate_limited" / "quota exceeded"
> - "agent unavailable" / "agent failed to spawn"
> - Empty agent output (silent fail)
> - Timeout error (network/agent hang)

```bash
# Trigger condition: ít nhất 1 trong 2 agents (3.1 hoặc 3.2) fail
if [[ "${AGENT_31_FAILED:-false}" == "true" ]] || [[ "${AGENT_32_FAILED:-false}" == "true" ]]; then

  log_warn "Phase 3 agent(s) failed — applying graceful degradation"

  # Strategy 1: Name-based CRUD matrix (deterministic, no agent needed)
  # Match L1 commands_sample / queries_sample tên với L4 entities tên qua regex/substring.
  # Output reduced quality nhưng vẫn có CRUD signal.
  if [[ "${AGENT_31_FAILED:-false}" == "true" ]]; then
    log_warn "Phase 3.1 (developer agent) failed — falling back to name-based CRUD matrix"
    crud_matrix_json='{}'
    business_rules_json='[]'
    SYNTHESIS_DEGRADED=true
    SYNTHESIS_DEGRADATION_NOTE="3.1 developer agent unavailable — name-based CRUD matrix only, business_rules empty (cần re-run sau khi agent quota reset)"
  fi

  # Strategy 2: Generic feature stub từ L4 entity names (BA fallback)
  # Output 1 generic feature per entity name → user vẫn có outline để start.
  if [[ "${AGENT_32_FAILED:-false}" == "true" ]]; then
    log_warn "Phase 3.2 (business-analyst agent) failed — falling back to entity-derived feature stubs"
    # Generate "- Quản lý <EntityName>" cho top 20 entities
    key_features_json=$(jq -n --slurpfile l4 "$SESSION_DIR/intermediate/l4-db.json" \
      '[$l4[0].entities[0:20][] | "- Quản lý " + .name + " (CRUD operations từ code scan — cần BA review)"]')
    SYNTHESIS_DEGRADED=true
    SYNTHESIS_DEGRADATION_NOTE+="; 3.2 BA agent unavailable — entity-derived feature stubs, cần re-run cho tiếng Việt humanization"
  fi

  # Persist degradation marker vào synthesis.json + scan-status.json + phase-summary.md
  # User MUST see warning trong output để biết quality reduced.
fi
```

**POST-GATE relaxation khi degraded:**
- `$key_features[]` có thể chứa entity stubs (vẫn phải non-empty — fallback đảm bảo ≥ 1 entry)
- `$crud_matrix` có thể `{}` empty (fallback strategy 1)
- `phase-summary.md` PHẢI hiển thị warning "⚠️ Phase 3 degraded mode" + recommendation re-run

**Resume path:** Lần resume sau khi quota reset, user có thể dùng `--resume --session=<id>`. Skill detect synthesis.json có flag `degraded=true` → re-run Phase 3 (KHÔNG skip).

### 3.3 — Completeness Estimate

```
total_score = 0
max_score = 0

# Score by completeness signals
IF L1_RESULT.total_files > 0: total_score += 25; max_score += 25  # Has code
IF L2_RESULT.total_endpoints > 0: total_score += 25; max_score += 25  # Has APIs
IF L3_RESULT.total_screens > 0: total_score += 25; max_score += 25  # Has UI
IF L4_RESULT.total_entities > 0: total_score += 25; max_score += 25  # Has data model

# Penalty for missing pieces
crud_complete_count = count entities with all 4 basic CRUD ops
crud_total_count = count entities in crud_matrix
crud_ratio = crud_complete_count / max(crud_total_count, 1)

completeness = round((total_score / max_score) * 100 * crud_ratio)
```

### 3.4 — Save Checkpoint sau Phase 3 (GAP-05 — Sprint 2)

```bash
# Persist synthesis data cho resume (giúp Phase 5 không re-compute nếu treo giữa Phase 5)
# v2.0.1 BUG-001 fix: thêm degraded flag + degradation_note để Phase 5 hiển thị warning
jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --argjson crud "$crud_matrix_json" \
      --argjson rules "$business_rules_json" \
      --argjson features "$key_features_json" \
      --argjson completeness "$completeness" \
      --argjson degraded "${SYNTHESIS_DEGRADED:-false}" \
      --arg note "${SYNTHESIS_DEGRADATION_NOTE:-}" \
      '{ generated_at: $ts, crud_matrix: $crud, business_rules: $rules,
         key_features: $features, completeness_estimate: $completeness,
         degraded: $degraded, degradation_note: $note }' \
   > "$SESSION_DIR/intermediate/synthesis.json"

# Mark phase_3 status — completed nếu pass, completed_degraded nếu fallback path
PHASE_3_STATUS="completed"
[[ "${SYNTHESIS_DEGRADED:-false}" == "true" ]] && PHASE_3_STATUS="completed_degraded"

NEXT_PHASE_AFTER_3="phase_4"
[ -z "$compare_path" ] && NEXT_PHASE_AFTER_3="phase_5"

save_checkpoint --phase phase_3 --status "$PHASE_3_STATUS" \
                --next-phase "$NEXT_PHASE_AFTER_3" --next-step output_generation \
                --intermediate-key synthesis_data \
                --intermediate-path "intermediate/synthesis.json"
```

## POST-GATE

```
- $crud_matrix populated (≥ 1 entity nếu L4_RESULT có entities) — RELAXED khi degraded=true (có thể {})
- $key_features[] không rỗng (≥ 1 entry — kể cả khi degraded fallback đảm bảo entity stubs)
- $completeness_estimate là number 0-100
- test -s $SESSION_DIR/intermediate/synthesis.json
- jq empty $SESSION_DIR/intermediate/synthesis.json
- checkpoint.json: phase_states.phase_3 IN [completed, completed_degraded]
- IF synthesis.json.degraded == true: phase-summary.md PHẢI hiển thị "⚠️ Phase 3 degraded mode"
```

## OUTPUT (set for next phase)

| Variable | Type | Description |
|----------|------|-------------|
| `$crud_matrix` | JSON | CRUD ops per entity |
| `$business_rules` | array | Rule signals (max 50) |
| `$key_features` | array | High-level features (BA output) |
| `$completeness_estimate` | int | 0-100 |

## Next Phase

- IF `$compare_path` set → Read `procedures/phase4-gap.md`
- ELSE → Read `procedures/phase5-output.md`
