# 04 — File Contract

> **Mục đích file:** Output paths + 7 agents conditional spawning + cross-skill produces_for/consumes_from + Sprint 5 `--from-scan`.

---

## 1. Session directory layout

```
.mc-data/work/wf-design/
├── latest                              # Pointer text → sessions/{id}/ mới nhất
├── design-status.json                  # Canonical sync từ session
├── design-plan.md                      # Execution plan
├── execution-plan.md                   # Protocol 9
├── checkpoint.json                     # Backward-compat mirror
├── design-report.md                    # Cross-validation + completion log
├── design-summary.json                 # Compressed spec (Phase 6 + canonical sync Phase 8)
├── deferred-findings.md                # Conditional — DEFERRED items cho wf-plan-modules
└── sessions/
    └── 20260515-143000-a1b2/           # Session ID format: YYYYMMDD-HHMMSS-hash4
        ├── session-state.json          # PRIMARY checkpoint (3-level L1/L2/L3)
        ├── workload-report.md          # Phase 0.5 output
        ├── feature-digest.md           # Phase 0 conditional
        ├── design-status.json          # Working (→ parent sync)
        ├── design-summary.json         # Working (→ parent sync Phase 8)
        ├── design-input-digest.json    # Working (→ `_meta/` sync Phase 8 STRIPPED)
        ├── aggregation-result.json     # Phase 3 dual-dedup output
        ├── checkpoint.json             # Backward-compat
        ├── lanes/
        │   └── {system-slug}/
        │       ├── signals.json        # Phase 1 architecture lane signals
        │       └── specs-signals.json  # Phase 2 specs lane signals
        └── phase-summary.md            # CORE-028
```

---

## 2. Canonical docs paths

```
.mc-data/docs/phase3-architecture/
├── P3-01-architecture.md
├── technical-specs/
│   ├── api-contract.md
│   ├── database-design.md
│   ├── infra-spec.md
│   └── integration-map.md
└── stakeholder-review.md

.mc-data/docs/_meta/
├── req-registry.json                  # SSOT — safe-write design_status
└── design-input-digest.json           # Phase 8 STRIPPED canonical
```

### LEGACY_MODE additional

```
.mc-data/work/legacy-scan/
├── gap-report.md
├── gap-categories.json
├── action-items.json
└── final-report.md
```

---

## 3. PRE-GATE / POST-GATE

### Phase 0 PRE-GATE

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | `test -f req-registry.json` | bash | E000 |
| T2 | `jq -e '.features \| length > 0'` | jq | E001 |
| T3 | `test -d phase2-features/` | bash | E002 |
| T4 | Forensic check phase2 (≥6 headings, ≥400 words) | bash | E002 |

### Phase 6 POST-GATE

| Tier | Check | Auto-fix |
|------|-------|----------|
| T1 | `test -f .mc-data/docs/phase3-architecture/P3-01-architecture.md` | Re-spawn architect Phase 1 |
| T2 | All 4 technical-specs/*.md exist | Re-spawn Phase 2 lanes |
| T3 | stakeholder-review.md status APPROVED hoặc HAS_DEFERRED | Re-spawn Phase 5 |
| T4 | Registry `design_status` updated cho mỗi feature in scope | Re-write registry |

---

## 4. Cross-skill contract

### Produces for

| Skill consumer | Artifact | Path |
|---------------|---------|------|
| `wf-design-ux` | `phase3-architecture/P3-01-architecture.md` + `technical-specs/*.md` | (markdown) |
| `wf-plan-modules` | `phase3-architecture/` + `req-registry.json` (design_status updated) + `deferred-findings.md` | (markdown + JSON) |
| `wf-implement-feature` | `design-summary.json` + `_meta/design-input-digest.json` | `design-input-digest-v1` |
| `wf-plan-modules` (LEGACY) | `action-items.json` từ Phase 7 gap | `action-items-v1` |

### Consumes from

| Skill producer | Artifact | Path |
|---------------|---------|------|
| `wf-define-features` | `phase2-features/[sys]/[mod]/*.md` + `feature-briefs.json` | (markdown + digest) |
| `wf-define-features` | `deferred-findings.md` (CORE-007) | (markdown) |
| `wf-analyze-requirements` | `req-registry.json` (features[] populated) | `req-registry-v1` |
| `wf-brainstorm` | `legacy-decisions.json` (LEGACY) | `legacy-decisions-v1` |
| `wf-legacy-scan` | `project-context.md` (LEGACY) | (markdown) |
| `wf-legacy-extract` | `module-code-mapping.json` (LEGACY Phase 7) | `module-code-mapping-v1` |
| **`wf-scan-target`** | `target-map.json` (Sprint 5 `--from-scan`) | `target-map-v1` |

---

## 5. Registry Safe-Write (CORE-006)

**write_role:** PRIMARY
**fields_owned:** `["design_status"]`

```bash
# Narrow per-feature update:
jq --arg id "$FEAT_ID" --arg status "completed" \
   '(.features[] | select(.feat_id == $id) | .design_status) = $status' \
   .mc-data/docs/_meta/req-registry.json > tmp && mv tmp ...
```

**KHÔNG modify:** `systems[]`, `modules[]`, `features[]` (definitions), `impl_status`.

---

## 6. 7 agents conditional spawning

| Phase | Agent | Mandatory? | Condition |
|-------|-------|-----------|-----------|
| 1 | `architect` | YES | Always (Phase 1, 2, 3, 5) |
| 1 | `ai-engineer` | Conditional | `$HAS_AI_ML == true` |
| 1 | `data-engineer` | Conditional | `$HAS_DATA_PIPELINE == true` |
| 1 | `automation-architect` | Conditional | `$HAS_AUTOMATION == true` |
| 2 | `dba` | YES | Always (DB design with architect) |
| 2 | `devops` | YES | Always (Infra spec with architect) |
| 3 | `architect` | YES | Integration Map |
| 5 | `architect` | YES | Cross-Review + Consistency |
| 5 | `security` | YES | Gap Analysis (security review) |

---

## 7. Artifact schemas

### `design-summary.json` (Phase 6 output)

```json
{
  "$schema": "design-summary-v1",
  "session_id": "...",
  "target": "platform",
  "systems_designed": ["crm", "smarttax", "eureka"],
  "components_count": 47,
  "api_endpoints_count": 156,
  "entities_count": 89,
  "design_status_features_updated": ["FEAT-CRM-CUST-001", "..."],
  "stakeholder_review_status": "APPROVED | HAS_DEFERRED",
  "compressed_at": "ISO 8601"
}
```

### `design-input-digest.json` (Phase 8 canonical, STRIPPED)

```json
{
  "$schema": "design-input-digest-v1",
  "summary_vi": "Tổng thiết kế project ERK Transport — 3 systems...",
  "systems": [...],
  "key_decisions": [...],
  "for_implement_feature": {
    "tech_stack": "...",
    "primary_modules": [...]
  }
}
```

---

## 8. Atomic write + Template Strip

Phase 8 áp dụng strip recursive trước khi ghi canonical `_meta/design-input-digest.json`:

```bash
jq 'walk(if type == "object" then with_entries(select(.key | startswith("_") | not)) else . end)' \
   sessions/{id}/design-input-digest.json > _meta/design-input-digest.json.tmp \
  && mv _meta/design-input-digest.json.tmp _meta/design-input-digest.json
```

---

## 9. Liên kết

- Standards: [`../../02-standards/06-safe-write-protocol.md`](../../02-standards/06-safe-write-protocol.md) §wf-design (PRIMARY `design_status`)
- Standards: [`../../02-standards/11-output-path-contract.md`](../../02-standards/11-output-path-contract.md)
- Pattern: [`../../03-design-patterns/03-cross-skill-artifacts.md`](../../03-design-patterns/03-cross-skill-artifacts.md)
- Source `_contract.json`: [`.claude/skills/workflow/wf-design/_contract.json`](../../../.claude/skills/workflow/wf-design/_contract.json)
