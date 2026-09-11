# Checklist: 7 New Template Files (v2.1)

> **Purpose:** Ensure 7 new templates tạo đúng schema + populate đủ fields.
> **Apply to:** Phase A.6 (skeletons), Phase B.1 (full populate).
> **Reference:** [../04-data-model.md §5](../../04-data-model.md), CORE-031.

---

## Template Locations

| # | File | Location | Schema | Phase |
|---|------|----------|--------|-------|
| 1 | `scan-state.json` | `.claude/skills/workflow/wf-legacy-scan/templates/` | scan-state-v1 | A.6 + B.1 |
| 2 | `domain-hints.json` | `.claude/skills/workflow/wf-legacy-scan/templates/` | domain-hints-v1 | A.6 + B.1 |
| 3 | `impact-graph.json` | `.claude/skills/workflow/wf-legacy-scan/templates/` | impact-graph-v1 | A.6 + B.1 |
| 4 | `phase-summary.md` | `.claude/skills/workflow/wf-legacy-scan/templates/` | — (CORE-028) | A.6 |
| 5 | `scan-plan.md` | `.claude/skills/workflow/wf-legacy-scan/templates/` | — | A.6 |
| 6 | `fix-workload.json` (stub v5.1) | `.claude/skills/workflow/wf-legacy-scan/templates/` | fix-workload-v1 | A.6 |
| 7 | `vietnamese-keywords.json` | `.claude/skills/workflow/_shared/ips/` | vn-keywords-v1 | A.6 + B.1 |

---

## Template #1: `scan-state.json`

### Required Fields

- [ ] `$schema: "scan-state-v1"`
- [ ] `session` object: `{id, created, project_path, profile, strategy, maturity_level, workload_id, chunk_id}`
- [ ] `depth_map` object: L1, L2, L3, L4, L5, L6 (all strings)
- [ ] `synthesis_mode` (string)
- [ ] `config` object: `{batch_size, max_files_cap_*, concurrency: {global_max, per_layer_max, per_probe_max, reserved_for_synthesis, per_agent_timeout_sec, per_agent_timeout_deep_sec}, cache: {session_cache_enabled, project_cache_enabled, ttl_days}, incremental, since_ref}`
- [ ] `layers` object: L1-L6 each with `{name, status, started, completed, outputs, checkpoint}` + L4/L5 additionally `depth, batch_progress/module_progress, partial`
- [ ] `ips` object: `{phase_a: null, phase_b: null}` initial
- [ ] `workload: null` initial
- [ ] `last_completed: "init"` initial
- [ ] `status: "in_progress"` initial
- [ ] `error_log: []` initial
- [ ] `resume_hint: ""` initial
- [ ] `legacy_ledger: {generated_at: null, schema_version: "legacy-v4.1", note: "..."}`

### Placeholders (for population)

- [ ] `{{SESSION_ID}}`
- [ ] `{{CREATED_AT}}`
- [ ] `{{PROJECT_PATH}}`
- [ ] `{{STRATEGY}}`
- [ ] `{{MATURITY_LEVEL}}`

### Verify

```bash
jq empty .claude/skills/workflow/wf-legacy-scan/templates/scan-state.json
jq -e '.["$schema"]' .claude/skills/workflow/wf-legacy-scan/templates/scan-state.json
jq -e '.config.concurrency.per_agent_timeout_sec' .claude/skills/workflow/wf-legacy-scan/templates/scan-state.json
jq -e '.layers | keys | length == 6' .claude/skills/workflow/wf-legacy-scan/templates/scan-state.json
```

---

## Template #2: `domain-hints.json`

### Required Fields

- [ ] `$schema: "domain-hints-v1"`
- [ ] `detected_domains: []` array (empty initially)
- [ ] `unresolved_patterns: []`
- [ ] `all_signals: {package_deps: [], directory_names: [], import_patterns: [], file_patterns: []}`
- [ ] `scan_time: null`

### Each detected_domain entry schema

- [ ] `{domain, confidence, language, signals: [{type, value, weight, lang}], recommended_expert}`

### Verify

```bash
jq empty .claude/skills/workflow/wf-legacy-scan/templates/domain-hints.json
jq -e '.detected_domains | type == "array"' .claude/skills/workflow/wf-legacy-scan/templates/domain-hints.json
```

---

## Template #3: `impact-graph.json`

### Required Fields

- [ ] `$schema: "impact-graph-v1"`
- [ ] `synthesis_mode: null` initial (set by L6)
- [ ] `generated_at: null` initial
- [ ] `nodes: []` array
- [ ] `edges: []` array
- [ ] `circular_dependencies: []`
- [ ] `orphan_modules: []`
- [ ] `summary: {total_nodes: 0, total_edges: 0, avg_fanout: 0, max_fanout: 0}`

### Node schema

- [ ] `{id, type: "module"|"file", files_count, feat_ids: [], domain, coupling_score}`

### Edge schema

- [ ] `{from, to, relation, evidence, strength, probe_source}`
- [ ] relation types: `code_import | data_dependency | event_subscription | api_call | req_cross_ref | entity_reference`

### Verify

```bash
jq empty .claude/skills/workflow/wf-legacy-scan/templates/impact-graph.json
```

---

## Template #4: `phase-summary.md` (CORE-028)

### Structure

```markdown
# Phase Summary — Session {{SESSION_ID}}

> Mục đích: Tổng hợp các phases đã chạy cho người không chuyên theo CORE-028.
> Ngôn ngữ: Tiếng Việt, giải thích rõ không dùng từ kỹ thuật khó.

---

## Phase 0 Detection — [STATUS]
...

## Phase 0A Assessment — [STATUS]
...

## Phase 1 Inventory — [STATUS]
...

## Phase 2 Classify — [STATUS]
...

## Phase 3 Extract — [STATUS]
...

## Phase 4 Synthesize — [STATUS]
...

---

## Tổng Kết

- Thời gian: ...
- Modules phát hiện: ...
- Features trích xuất: ...
- Issues cần xử lý: ...
```

### Placeholder checklist

- [ ] `{{SESSION_ID}}`
- [ ] Section placeholders cho mỗi phase
- [ ] Tổng kết section

---

## Template #5: `scan-plan.md`

### Structure

```markdown
# Scan Plan — Session {{SESSION_ID}}

**Created:** {{CREATED_AT}}
**Profile:** {{PROFILE}}
**Strategy:** {{STRATEGY}}
**Project:** {{PROJECT_PATH}}

## Depth Map
| Layer | Depth |
|-------|-------|
| L1 | full |
| L2 | full |
| L3 | full |
| L4 | {{L4_DEPTH}} |
| L5 | {{L5_DEPTH}} |
| L6 (synthesis_mode) | {{SYNTHESIS_MODE}} |

## Execution Order
1. L1 Discovery
2. L2 Assessment + IPS-A
3. L3 Inventory + IPS-B
4. L4 Classification
5. L5 Extraction
6. L6 Synthesis

## Estimated Time
- L1: ~30s
- L2: ~15s + IPS-A ~5s
- L3: ~90s + IPS-B ~10s
- L4: {{L4_TIME_EST}}
- L5: {{L5_TIME_EST}}
- L6: ~3min
- **Total:** {{TOTAL_TIME_EST}}
```

### Verify

- [ ] Placeholders all present
- [ ] Structure theo design spec

---

## Template #6: `fix-workload.json` (stub v5.1)

### Required Fields (minimal)

```json
{
  "$schema": "fix-workload-v1",
  "status": "deferred-to-v5.1",
  "note": "Workload Partition Planner deferred to v5.1 per ADR-LS13 (v2.1 revised). v5.0 only detects + WARN via Workload Gate, does NOT partition."
}
```

### Verify

- [ ] JSON valid
- [ ] Schema ref present
- [ ] Status = deferred

---

## Template #7: `vietnamese-keywords.json` (v2.1)

### Required Fields

- [ ] `$schema: "vn-keywords-v1"`
- [ ] `version: "1.0"`
- [ ] `last_updated` (date)
- [ ] `normalization: {strip_diacritics, lowercase, d_to_d, strip_separators}`
- [ ] `domains` object với 14 keys (finance, hr, sales, procurement, ecommerce, operations, compliance, healthcare, logistics, manufacturing, retail, legal, insurance, education)

### Each domain structure

```json
{
  "keywords": [
    {"keyword": "...", "variants": ["..."], "weight": 0.N, "exact_only": false}
  ],
  "abbreviations": [
    {"keyword": "xy", "weight": 0.N, "exact_only": true}
  ]
}
```

### Populate Targets

- [ ] 14 domains (Core 7 + Optional 7)
- [ ] ≥ 110 total keywords
- [ ] Core 7 ≥ 6 keywords each
- [ ] Optional 7 ≥ 5 keywords each
- [ ] Abbreviations exact_only=true cho viết tắt 2-3 ký tự

### Verify

```bash
jq empty .claude/skills/workflow/_shared/ips/vietnamese-keywords.json
jq '.domains | keys | length' .claude/skills/workflow/_shared/ips/vietnamese-keywords.json  # = 14
jq '[.domains[].keywords[], .domains[].abbreviations[]?] | length' \
   .claude/skills/workflow/_shared/ips/vietnamese-keywords.json  # ≥ 110

# Core 7 check
for d in finance hr sales procurement ecommerce operations compliance; do
  count=$(jq ".domains.\"$d\".keywords | length" .claude/skills/workflow/_shared/ips/vietnamese-keywords.json)
  echo "$d: $count keywords (expect ≥ 6)"
done
```

---

## Integration Checklist (CORE-031)

Mỗi template PHẢI được sử dụng qua pattern READ → POPULATE → WRITE:

- [ ] `_contract.json outputs.working[].template` references template path
- [ ] SKILL.md / procedure files ghi rõ "**[READ-TEMPLATE]** READ `templates/xxx.json` → POPULATE → WRITE"
- [ ] Audit script kiểm tra: mọi output có template reference

Verify:

```bash
# All working outputs có template field
jq '.outputs.working[] | {path, template}' \
   docs/design/skills/wf-legacy-scan/implementation/_contract-v5.0.0-draft.json
# Every entry should have non-null template (or explicit null + notes)

# Grep "từ template" hoặc "READ-TEMPLATE" trong procedure files
grep -rn "READ-TEMPLATE\|từ template\|from template" \
   .claude/skills/workflow/wf-legacy-scan/procedures/ | wc -l
# Expect: ≥ 1 per output file
```

---

## Final Verification

- [ ] 5 JSON templates valid
- [ ] 2 MD templates có structure
- [ ] vietnamese-keywords.json có 14 domains + ≥110 keywords
- [ ] All templates referenced trong _contract.json
- [ ] All templates referenced trong procedures via READ-TEMPLATE
