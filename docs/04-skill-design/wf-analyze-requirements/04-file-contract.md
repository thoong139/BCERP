# 04 — File Contract

> **Mục đích file:** Output paths (session isolation v2 + DUAL-WRITE) + registry safe-write + cross-skill produces_for/consumes_from + schemas.

---

## 1. Session directory layout

```
.mc-data/work/wf-analyze-requirements/
├── latest                                  # Pointer text file → sessions/{id}/ mới nhất
├── sessions/
│   ├── 20260515-143000-a1b2/              # Session ID format: YYYYMMDD-HHMMSS-hash4
│   │   ├── session-state.json              # SSOT pipeline state (ADR-OPT-02)
│   │   ├── workload-report.md              # Workload gate estimate (ADR-OPT-03)
│   │   ├── aggregation-result.json         # Phase 6 dedup result (ADR-OPT-04)
│   │   ├── lanes/
│   │   │   ├── sales/signals.json          # Phase 4 lane output (ADR-OPT-01)
│   │   │   ├── marketing/signals.json
│   │   │   └── ...
│   │   ├── analyze-status.json             # Tracking detailed phase
│   │   ├── analyze-plan.md                 # Expert → dept mapping
│   │   ├── execution-plan.md               # Protocol 9
│   │   ├── analyze-report.md               # Final report
│   │   ├── checkpoint.json                 # Legacy format backward-compat
│   │   ├── department-digests.json         # Working artifact (pre Phase 8c)
│   │   ├── phase1-handoff.json             # Working artifact (pre Phase 8c)
│   │   ├── phase-summary.md                # CORE-028 tiếng Việt
│   │   └── cdg-tokens.json                 # CDG decisions log (lazy)
│   ├── 20260515-150000-c3d4/              # Run thứ 2 — KHÔNG overwrite
│   └── ... (keep 5 most recent, CORE-030)
│
└── (DUAL-WRITE flat path - backward-compat)
    ├── analyze-status.json
    ├── analyze-plan.md
    ├── checkpoint.json
    └── ...
```

**DUAL-WRITE pattern (ADR-OPT-02):** Files ghi vào `sessions/{id}/` (canonical) VÀ dual-write flat path `.mc-data/work/wf-analyze-requirements/` (backward-compat cho downstream chưa support session path).

---

## 2. Canonical output paths (`.mc-data/docs/`)

### Phase 1 business docs

```
.mc-data/docs/phase1-business/
├── P1-01-project-overview.md
├── P1-02-business-workflow.md (scope=all)
├── stakeholder-review.md (scope=all)
└── departments/
    ├── _index.md
    ├── sales/sales.md
    ├── marketing/marketing.md
    ├── customer-service/customer-service.md
    ├── finance/finance.md
    └── logistics/logistics.md
```

### Cross-skill digests (canonical `_meta/`)

```
.mc-data/docs/_meta/
├── req-registry.json              # SSOT (registry safe-write)
├── dept-digests.json              # Phase 8c output → consumed by wf-define-features
└── phase1-handoff.json            # Phase 8c output → consumed by wf-define-features
```

---

## 3. PRE-GATE per phase

### Phase 0 — Init

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | `test -f .mc-data/docs/_meta/req-registry.json` | bash | E000 |
| T2 | `test -f .mc-data/docs/phase0-brainstorm/P0-01-brainstorm.md` | bash | E016 |
| T3 | Registry schema valid (`jq -e '.requirements'`) | jq | E000 |
| T4 | LEGACY_MODE detect (CORE-021): `project-context.md > 500 bytes` | bash | (set flag, không fail) |

### Phase 4 — Lane Dispatch

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | `_shared/lane/dispatcher.py` exists | bash | E010 |
| T2 | Departments list non-empty (from Phase 1) | jq | E020 |
| T3 | Expert mapping resolved (Phase 2) | jq | E020 |
| T4 | Lane subdir tạo được | bash | E010 |

---

## 4. POST-GATE per phase

### Phase 8 — Registry Update

| Tier | Check | Auto-fix |
|------|-------|----------|
| T1 | `jq '.' req-registry.json` valid | Re-build từ template, restore from backup |
| T2 | `jq -e '.requirements \| length > 0'` | Re-extract from dept docs |
| T3 | `jq -e '.features \| length == 0 OR (existing length preserved)'` (no rogue write) | Audit + restore |
| T4 | Each requirement có `req_id`, `systems[]` (≥1), `primary_module`, `interface_type` | Re-populate fields |

### Phase 8b — Cross-Validation (auto-correction loop max 3)

8 validation checks (8b.1 → 8b.7 + 8b.3b):
- 8b.1: Mỗi REQ-ID có source dept doc file tồn tại
- 8b.2: Mỗi REQ-ID trong dept docs có entry trong registry
- 8b.3: REQ-ID format valid (`REQ-[DEPT]-[NNN]` hoặc `REQ-[SYS]-[MOD]-[NNN]`)
- 8b.3b: REQ-ID slug normalized (lowercase, hyphen)
- 8b.4: Mỗi REQ có `systems[]` ≥1
- 8b.5: Không có duplicate REQ-IDs
- 8b.6: Tất cả departments tồn tại trong registry
- 8b.7: Cross-ref interface_type consistency

Loop max 3 iterations → PASS hoặc ESCALATE E007.

---

## 5. Cross-skill contract

### Produces for

| Skill consumer | Artifact | Schema | Path |
|---------------|---------|--------|------|
| `wf-define-features` | `stakeholder-review.md` | (markdown) | `phase1-business/stakeholder-review.md` |
| `wf-define-features` | `deferred-issues.md` | (markdown) | `work/wf-analyze-requirements/deferred-issues.md` |
| `wf-define-features` | `dept-digests.json` | `dept-digests-v1` | `docs/_meta/dept-digests.json` |
| `wf-define-features` | `phase1-handoff.json` | `phase1-handoff-v1` | `docs/_meta/phase1-handoff.json` |
| `wf-define-features` | `req-registry.json` (updated `requirements[]`) | `req-registry-v1` | `docs/_meta/req-registry.json` |
| `wf-add-scope` | `req-registry.json` | `req-registry-v1` | `docs/_meta/req-registry.json` |

### Consumes from

| Skill producer | Artifact | Schema | Path |
|---------------|---------|--------|------|
| `wf-brainstorm` | `P0-01-brainstorm.md`, `P0-02-systems-users.md`, `policies/` | (markdown) | `docs/phase0-brainstorm/` |
| `wf-brainstorm` | `req-registry.json` (seed) | `req-registry-v1` | `docs/_meta/req-registry.json` |
| `wf-brainstorm` | `project-digest.json` | `project-digest-v1` | `docs/_meta/project-digest.json` |
| `wf-brainstorm` | `legacy-decisions.json` (LEGACY_MODE only, CORE-022) | `legacy-decisions-v1` | `work/wf-brainstorm/legacy-decisions.json` |
| `wf-legacy-extract` | `{module}.json`, `module-code-mapping.json` (LEGACY_MODE only) | extract-v1 | `work/legacy-scan/extracted/` |

---

## 6. Registry Safe-Write (CORE-006)

**write_role:** PRIMARY
**fields_owned:**
- `systems[]` (enrich, không overwrite user_roles/touchpoints/related_departments/phase)
- `systems.module_ids` (bổ sung)
- `modules[]`, `modules.system`, `modules.department_ids`
- `departments[]`
- `requirements[]`, `requirements.systems[]` (≥1), `requirements.primary_module`
- `interface_type`

**KHÔNG modify:** `features[]` (wf-define-features), `design_status` (wf-design), `ux_design_status` (wf-design-ux), `implementation_order` (wf-plan-modules), `impl_status` (wf-implement-feature).

```bash
# Narrow per-field jq update (vd thêm 1 requirement):
TMP=$(mktemp)
jq --argjson new_req "$REQ_JSON" '.requirements += [$new_req]' \
   .mc-data/docs/_meta/req-registry.json > "$TMP" && mv "$TMP" .mc-data/docs/_meta/req-registry.json
```

---

## 7. Artifact schemas

### `session-state.json` (ADR-OPT-02)

Xem [03-phase-routing.md](03-phase-routing.md) §7.

### `lane-signal.json` (ADR-OPT-01)

```json
{
  "$schema": "lane-signal-v1",
  "lane_key": "sales",
  "expert": "sales-expert",
  "department": "Kinh doanh / Sales",
  "items": [
    {
      "req_id": "REQ-SALES-001",
      "title": "Quản lý khách hàng",
      "description": "...",
      "rationale": "...",
      "stakeholders": ["..."],
      "priority": "P0|P1|P2"
    }
  ],
  "status": "in_progress | completed | failed",
  "started_at": "ISO 8601",
  "completed_at": "ISO 8601 | null"
}
```

### `aggregation-result.json` (ADR-OPT-04)

```json
{
  "$schema": "aggregation-result-v1",
  "total_input": 47,
  "total_output": 42,
  "duplicates": 5,
  "conflicts": [
    {
      "req_id": "REQ-CUST-001",
      "dept_a": "sales",
      "dept_b": "customer-service",
      "content_a": "...",
      "content_b": "..."
    }
  ],
  "aggregated_at": "ISO 8601"
}
```

### `dept-digests.json` (canonical, Phase 8c)

```json
{
  "$schema": "dept-digests-v1",
  "departments": {
    "sales": {
      "name_vi": "Kinh doanh / Bán hàng",
      "stakeholders": ["..."],
      "req_ids": ["REQ-SALES-001", "..."],
      "primary_modules": ["MOD-CRM-SALES"],
      "summary_vi": "..."
    }
  }
}
```

---

## 8. Atomic write pattern + Template Strip

```bash
# Step 1: build content vào tmp
echo "$populated" > "$file.tmp.$$"

# Step 2: strip template metadata (ADR-OPT-05)
jq 'walk(if type == "object" then with_entries(select(.key | startswith("_") | not)) else . end)' \
   "$file.tmp.$$" > "$file.tmp.stripped.$$"

# Step 3: validate JSON
jq '.' "$file.tmp.stripped.$$" > /dev/null || { rm "$file.tmp.*"; exit 1; }

# Step 4: atomic move
mv "$file.tmp.stripped.$$" "$file"
```

Strip áp dụng recursively cho nested objects/arrays. Helpers ở `_shared/_shared.md §1`.

---

## 9. Liên kết

- Standards: [`../../02-standards/06-safe-write-protocol.md`](../../02-standards/06-safe-write-protocol.md) §wf-analyze-requirements (PRIMARY role)
- Standards: [`../../02-standards/04-contract-schema.md`](../../02-standards/04-contract-schema.md) §Cross-skill
- Standards: [`../../02-standards/11-output-path-contract.md`](../../02-standards/11-output-path-contract.md) §DUAL-WRITE
- Pattern: [`../../03-design-patterns/03-cross-skill-artifacts.md`](../../03-design-patterns/03-cross-skill-artifacts.md)
- Source `_contract.json`: [`.claude/skills/workflow/wf-analyze-requirements/_contract.json`](../../../.claude/skills/workflow/wf-analyze-requirements/_contract.json)
