# Sprint 5: P1 Skills Integration

> **Estimate:** 2h | **Priority:** P1 | **Dependencies:** S1+S2
> **Revised v0.3:** Verified actual procedure file names against codebase (F18)
>
> Skills: wf-manage-change, wf-legacy-scan, wf-design

---

## Tasks

### Task 5.1: wf-manage-change Integration — 0.75h

**File:** `.claude/skills/workflow/wf-manage-change/SKILL.md`
**File:** `.claude/skills/workflow/wf-manage-change/procedures/phase2-impact.md`

**PRE-GATE additions (SKILL.md):**
```
Step 0.Na: Load CI capabilities (ci-detect.sh + lock)
Step 0.Nb: Index Freshness Check (ci-freshness-check.sh)
```

**Phase 2 (Impact Analysis) changes (`phase2-impact.md`):**
```
BEFORE: Manual trace dependencies bằng Grep/Read
AFTER:
  1. CI-ROUTE impact_analysis "{changed_symbol}"
     → GitNexus impact(changed_symbol, upstream, depth=3)
     → Tự động populate impact_analysis section
     ⚠ Freshness caveat nếu index stale
  2. CI-ROUTE find_references "{changed_symbol}"
     → Serena find_references (tất cả call sites)
  3. CI-ROUTE api_routes "{affected_route}" (nếu API thay đổi)
     → GitNexus route_map(affected_route)
```

**Acceptance criteria:**
- [ ] PRE-GATE có 2 CI steps (Na + Nb)
- [ ] Impact analysis tự động thay vì thủ công (target: `phase2-impact.md` — verified F18)
- [ ] Populate `change-impact.json` fields từ GitNexus output
- [ ] API route check khi thay đổi API
- [ ] Freshness caveat khi index stale
- [ ] Graceful degradation: manual impact như cũ

---

### Task 5.2: wf-legacy-scan Integration — 0.75h

**File:** `.claude/skills/workflow/wf-legacy-scan/SKILL.md`

**PRE-GATE additions:**
```
Step 0.Na: Load CI capabilities (ci-detect.sh + lock)
Step 0.Nb: Index Freshness Check (ci-freshness-check.sh)
```

**Stage changes (CI-Route annotations in SKILL.md flow):**
```
Stage 1 (Inventory):
  BEFORE: find apps/ -name "*.cs" | head -200
  AFTER:
    1. CI-ROUTE project_structure
       → Serena onboarding (nếu chưa onboard)
       → GitNexus clusters (functional areas)
       → Glob (fallback)

Stage 2 (Analysis):
  BEFORE: Read key files + manual trace
  AFTER:
    1. CI-ROUTE understand_flow "{key_concept}"
       → GitNexus query(key_concept)
       → Trả về execution flows + symbols
       ⚠ Freshness caveat nếu index stale
    2. CI-ROUTE symbol_overview "{key_file}"
       → Serena get_symbols_overview (cấu trúc file)

Stage 3 (Extraction):
  BEFORE: Grep REQ-ID patterns
  AFTER:
    1. CI-ROUTE find_by_annotation "REQ-"
       → GitNexus cypher (tìm tất cả REQ-ID annotations)
       → Grep (fallback)
```

**Acceptance criteria:**
- [ ] PRE-GATE có 2 CI steps (Na + Nb)
- [ ] Stage 1 dùng Serena onboarding cho cấu trúc dự án
- [ ] Stage 2 dùng GitNexus query cho execution flows + freshness caveat
- [ ] Stage 3 dùng GitNexus cypher cho REQ-ID search
- [ ] Token reduction: Stage 2 -60% to -80% (measured per methodology in master plan §4.3)
- [ ] Graceful degradation: Glob/Grep như cũ

---

### Task 5.3: wf-design Integration — 0.5h

**File:** `.claude/skills/workflow/wf-design/SKILL.md`

**PRE-GATE additions:**
```
Step 0.Na: Load CI capabilities (ci-detect.sh + lock)
Step 0.Nb: Index Freshness Check (ci-freshness-check.sh)
```

**Phase 0 (Existing Architecture Review) changes:**
```
BEFORE: Đọc từng file controller, service, repository
AFTER:
  1. CI-ROUTE api_routes
     → GitNexus route_map() (toàn bộ API routes + consumers)
  2. CI-ROUTE understand_flow "{core_domain}"
     → GitNexus query("authentication flow")
     → GitNexus query("order processing flow")
     (cho mỗi core domain concept)
     ⚠ Freshness caveat nếu index stale
  3. CI-ROUTE project_structure
     → GitNexus clusters (functional areas)
     → Serena onboarding (project structure — nếu available)
```

> **Note:** wf-design Phase 0 procedure là `phase0-context.md`. CI-ROUTE annotations áp dụng cho architecture review step trong file này.

**Acceptance criteria:**
- [ ] PRE-GATE có 2 CI steps (Na + Nb)
- [ ] API routes tự động map thay vì đọc thủ công (target: `phase0-context.md` — verified F18)
- [ ] Execution flows cho core domains từ GitNexus + freshness caveat
- [ ] Project structure từ GitNexus clusters
- [ ] Graceful degradation: đọc file như cũ

---

### Task 5.4: Update _contract.json files — 0.25h

**Files:**
- `.claude/skills/workflow/wf-manage-change/_contract.json`
- `.claude/skills/workflow/wf-legacy-scan/_contract.json`
- `.claude/skills/workflow/wf-design/_contract.json`

- Thêm `code_intelligence.integration = true`
- Thêm CI tools vào `tools_used[]` phù hợp với từng skill:
  - wf-manage-change: gitnexus_impact, gitnexus_route_map, serena_find_references
  - wf-legacy-scan: gitnexus_query, gitnexus_clusters, gitnexus_cypher, serena_onboarding, serena_get_symbols_overview
  - wf-design: gitnexus_route_map, gitnexus_query, gitnexus_clusters, serena_onboarding

**Acceptance criteria:**
- [ ] Cả 3 skills có `code_intelligence.integration = true`
- [ ] CI tools được liệt kê trong `tools_used[]` phù hợp với vai trò từng skill

---

## Sprint 5 DoD

- [ ] wf-manage-change: PRE-GATE CI steps + automated impact analysis (`phase2-impact.md`) + freshness caveat
- [ ] wf-legacy-scan: PRE-GATE CI steps + CI tools cho Stage 1-3
- [ ] wf-design: PRE-GATE CI steps + CI tools cho Phase 0 architecture review (`phase0-context.md`)
- [ ] Lock graceful fallback: lock held → Grep (no regression) — verified cho cả 3
- [ ] Token reduction verified cho wf-legacy-scan Stage 2 (per methodology in master plan §4.3)
- [ ] Graceful degradation verified cho cả 3 skills
- [ ] _contract.json updated cho cả 3 skills (Task 5.4)
- [ ] Tất cả procedure file references khớp với thực tế codebase (F18)
