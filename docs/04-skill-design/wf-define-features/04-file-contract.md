# 04 — File Contract

> **Mục đích file:** Output paths + dual-schema `feature-briefs.json` + cross-skill produces_for + Registry append-only `features[]` + Referential Integrity exception.

---

## 1. Session directory + output layout

```
.mc-data/work/wf-define-features/
├── latest                              # Pointer text → sessions/{id}/
├── define-features-status.json
├── define-features-plan.md
├── checkpoint.json
├── cross-validation-report.md
├── define-features-report.md
├── feature-briefs.json                 # WORKING SCHEMA (Phase 1 creation)
├── deferred-findings.md                # Phase 4 → consumed by wf-design
├── ui-coverage-gaps.json               # LEGACY only
└── sessions/
    └── 20260515-143000-a1b2/
        ├── session-state.json
        ├── workload-report.md
        ├── feature-briefs.json
        ├── lanes/{module-slug}/specs-signals.json
        ├── referential-integrity-violations.json  # Phase 5.3c debug
        └── phase-summary.md
```

### Canonical docs

```
.mc-data/docs/phase2-features/
├── [sys-slug]/[mod-slug]/
│   ├── [feature-slug].md              # NEW mode kebab-case Vietnamese
│   └── FEAT-XXX-NNN.md                # LEGACY mode FEAT-ID prefix
└── stakeholder-review.md

.mc-data/docs/_meta/
├── req-registry.json                  # Append features[]
└── feature-briefs.json                # DIGEST SCHEMA (Phase 6 generated)
```

---

## 2. Dual-schema `feature-briefs.json`

**Critical:** Cùng tên file ở 2 location nhưng **SCHEMA KHÁC NHAU**:

### Working schema (`work/wf-define-features/feature-briefs.json`)

Phase 1 creation use:

```json
{
  "$schema": "feature-briefs-working-v1",
  "features": [
    {
      "feat_id": "FEAT-CRM-CUST-001",
      "title": "Quản lý khách hàng",
      "actors": ["sales-rep", "manager"],
      "business_rules": ["..."],
      "output_path": "phase2-features/sys-crm/mod-crm/quan-ly-khach-hang.md"
    }
  ]
}
```

### Digest schema (`docs/_meta/feature-briefs.json`)

Phase 6 digest (Phiên 6) → consumed by `wf-design`, `wf-implement-feature`:

```json
{
  "$schema": "feature-briefs-digest-v1",
  "features": [
    {
      "feature_id": "FEAT-CRM-CUST-001",
      "summary": "...",
      "acceptance_criteria": ["..."],
      "technical_complexity": "low | medium | high"
    }
  ]
}
```

---

## 3. PRE-GATE / POST-GATE

### Phase 5 POST-GATE (v3.1 Referential Integrity)

| Tier | Check | Auto-fix |
|------|-------|----------|
| T1 | `test -f req-registry.json` | Restore backup |
| T2 | `jq -e '.features \| length > 0'` | Re-build từ feature specs |
| T3 | `jq -e '[.features[] | .req_ids[]] - [.requirements[].req_id] | length == 0'` (referential integrity) | --auto-stub-requirements OR BLOCK E020 |
| T4 | `jq -e '.requirements \| length' KHÔNG decreased` (append-only) | Restore from session-state |

---

## 4. Cross-skill contract

### Produces for

| Skill consumer | Artifact | Path |
|---------------|---------|------|
| `wf-design` | `phase2-features/[sys]/[mod]/*.md` | Feature specs |
| `wf-design` | `deferred-findings.md` (CORE-007) | (markdown) |
| `wf-design` | `feature-briefs.json` digest schema | `_meta/feature-briefs.json` |
| `wf-design` | `req-registry.json` (features[] updated) | SSOT |
| `wf-implement-feature` | `req-registry.json` + `feature-briefs.json` | Both |
| `wf-implement-feature` (LEGACY) | `phase2-features/[sys]/[mod]/FEAT-XXX-NNN.md` | (LEGACY naming) |
| `wf-verify-sync` (CF6) | `features[].cross_feat_refs[]` (v3.3) | Registry field |

### Consumes from

| Skill producer | Artifact | Path |
|---------------|---------|------|
| `wf-analyze-requirements` | `phase1-business/` + `req-registry.json` (requirements[]) | SSOT |
| `wf-analyze-requirements` | `dept-digests.json` + `phase1-handoff.json` | `_meta/` |
| `wf-analyze-requirements` | `deferred-issues.md` | (markdown) |
| `wf-brainstorm` | `legacy-decisions.json` (LEGACY) | `legacy-decisions-v1` |
| `wf-legacy-extract` | `extracted/{module}.json`, `ui-manifest.json` (LEGACY) | extract-v1, ui-manifest-v1 |
| **`wf-scan-target`** | `feature-inventory.md`, `target-map.json` (Sprint 5 `--from-scan`) | (markdown + JSON) |

---

## 5. Registry Safe-Write (CORE-006)

**write_role:** PRIMARY
**fields_owned:**
- `features[]` (append-only)
- `impl_status` per REQ-ID (only "skipped" for DEPRECATED modules)
- **EXCEPTION (v3.1):** `requirements[]` APPEND-ONLY khi `--auto-stub-requirements` (narrow exception cho stubs)
- **(CF6 v3.3):** `features[].cross_feat_refs[]` đề xuất qua AskUserQuestion + append

```bash
# Append features (narrow):
jq --argjson new_feats "$FEATS_JSON" '.features += $new_feats' \
   req-registry.json > tmp && mv tmp ...

# Auto-stub requirements (narrow exception v3.1):
jq --argjson stubs "$STUBS_JSON" '.requirements += $stubs' \
   req-registry.json > tmp && mv tmp ...
```

**KHÔNG modify:** `requirements[]` (except stub exception), `systems[]`, `modules[]`, `design_status`, `ux_design_status`, `implementation_order`.

---

## 6. `referential-integrity-violations.json` schema (Phase 5.3c debug)

```json
{
  "$schema": "referential-integrity-violations-v1",
  "checked_at": "ISO 8601",
  "total_features": 25,
  "orphan_req_ids": ["REQ-SALES-007", "REQ-CRM-005"],
  "orphan_count": 2,
  "features_with_orphans": [
    {
      "feat_id": "FEAT-CRM-CUST-001",
      "referenced_orphans": ["REQ-SALES-007"]
    }
  ],
  "action_taken": "BLOCKED | AUTO_STUBBED",
  "stubs_appended": 0 // hoặc số stubs nếu --auto-stub-requirements
}
```

---

## 7. Cross-FEAT ref schema (CF6 v3.3)

```json
"features": [
  {
    "feat_id": "FEAT-CRM-CUST-001",
    "cross_feat_refs": [
      {
        "target_req_id": "REQ-SALES-010",
        "target_feat_id": "FEAT-SALES-ORD-001",
        "relationship": "consume | produce | coordinate",
        "reason": "Customer Order phụ thuộc Customer entity",
        "blocking_level": "hard | soft",
        "min_completion": "test_passed | impl_done"
      }
    ]
  }
]
```

---

## 8. Atomic write + Template Strip

Phase 6 (digest) áp dụng strip recursive trước khi ghi canonical `_meta/feature-briefs.json`.

---

## 9. Liên kết

- Standards: [`../../02-standards/06-safe-write-protocol.md`](../../02-standards/06-safe-write-protocol.md) §wf-define-features (PRIMARY + append-only + v3.1 exception)
- Standards: [`../../02-standards/04-contract-schema.md`](../../02-standards/04-contract-schema.md)
- Pattern: [`../../03-design-patterns/03-cross-skill-artifacts.md`](../../03-design-patterns/03-cross-skill-artifacts.md)
- Source: [`.claude/skills/workflow/wf-define-features/_contract.json`](../../../.claude/skills/workflow/wf-define-features/_contract.json)
