# Sprint 6: P2 Skills Integration

> **Estimate:** 1h | **Priority:** P2 | **Dependencies:** S1+S2
> **Revised v0.3:** Verified actual procedure references (F18)
>
> Skills: wf-verify-sync, wf-plan-modules

---

## Tasks

### Task 6.1: wf-verify-sync Integration — 0.5h

**File:** `.claude/skills/workflow/wf-verify-sync/SKILL.md`

**PRE-GATE additions:**
```
Step 0.Na: Load CI capabilities (ci-detect.sh + lock)
Step 0.Nb: Index Freshness Check (ci-freshness-check.sh)
```

**Phase 2 (Code Scan - REQ-ID Search) changes:**
```
BEFORE: grep -rn "REQ-ID:" apps/ --include="*.cs"
AFTER:
  1. CI-ROUTE find_by_annotation "REQ-ID:"
     → GitNexus cypher: MATCH (f:Function) WHERE f.name CONTAINS "REQ-ID" ...
     → Serena find_references (tìm references đến REQ-ID constants)
     → grep -rn (fallback)
  2. Cross-validate: GitNexus results ∩ Grep results
     → Report discrepancies
     ⚠ Freshness caveat nếu index stale: cypher results có thể thiếu REQ-ID mới

Phase 3 (Cross-reference):
  BEFORE: Manual check từng REQ-ID
  AFTER:
    1. CI-ROUTE find_references "{REQ-ID}"
       → Serena find_references (tất cả nơi reference REQ-ID)
       → GitNexus context (callers của function có REQ-ID)
       ⚠ Serena results chính xác (real-time LSP), GitNexus có thể stale
```

> **Note:** wf-verify-sync đã có session isolation (v4.0.0) với procedure files riêng. CI-ROUTE annotations được thêm vào Phase 2 (code scanning) và Phase 3 (cross-reference) của SKILL.md flow — các procedure files của verify-sync (như `vs-impact-build.sh`) không cần modify.

**Acceptance criteria:**
- [ ] PRE-GATE có 2 CI steps (Na + Nb)
- [ ] REQ-ID search dùng GitNexus cypher + Serena
- [ ] Cross-validation giữa CI tools và Grep
- [ ] Freshness caveat cho GitNexus results (Serena unaffected — real-time LSP)
- [ ] Graceful degradation: Grep như cũ

---

### Task 6.2: wf-plan-modules Integration — 0.5h

**File:** `.claude/skills/workflow/wf-plan-modules/SKILL.md`

**PRE-GATE additions:**
```
Step 0.Na: Load CI capabilities (ci-detect.sh + lock)
Step 0.Nb: Index Freshness Check (ci-freshness-check.sh)
```

**Phase 4 (Dependency Analysis) changes:**
```
BEFORE: Manual dependency analysis
AFTER:
  1. CI-ROUTE impact_analysis cho mỗi module entry point
     → GitNexus impact(module_entry, upstream, depth=2)
     → Tự động map cross-module dependencies
     ⚠ Freshness caveat nếu index stale
  2. CI-ROUTE project_structure
     → GitNexus clusters (module grouping)
     → Serena get_symbols_overview (per-module symbols — nếu available)
```

> **Note:** wf-plan-modules đã có session isolation (v3.3.0). CI-ROUTE annotations được thêm vào Phase 4 (dependency analysis) của SKILL.md flow.

**Acceptance criteria:**
- [ ] PRE-GATE có 2 CI steps (Na + Nb)
- [ ] Cross-module dependency map từ GitNexus impact
- [ ] Module grouping từ GitNexus clusters
- [ ] Freshness caveat khi index stale
- [ ] Graceful degradation: manual analysis như cũ

---

### Task 6.3: Update _contract.json files — 0.25h

**Files:**
- `.claude/skills/workflow/wf-verify-sync/_contract.json`
- `.claude/skills/workflow/wf-plan-modules/_contract.json`

- Thêm `code_intelligence.integration = true`
- Thêm CI tools vào `tools_used[]` phù hợp với từng skill:
  - wf-verify-sync: gitnexus_cypher, serena_find_references
  - wf-plan-modules: gitnexus_impact, gitnexus_clusters, serena_get_symbols_overview

**Acceptance criteria:**
- [ ] Cả 2 skills có `code_intelligence.integration = true`
- [ ] CI tools được liệt kê trong `tools_used[]` phù hợp với vai trò từng skill

---

## Sprint 6 DoD

- [ ] wf-verify-sync: PRE-GATE CI steps + CI-enhanced REQ-ID search + freshness caveat
- [ ] wf-plan-modules: PRE-GATE CI steps + CI-enhanced dependency analysis + freshness caveat
- [ ] Lock graceful fallback: lock held → Grep (no regression) — verified cho cả 2
- [ ] Graceful degradation verified cho cả 2 skills
- [ ] _contract.json updated cho cả 2 skills (Task 6.3)
