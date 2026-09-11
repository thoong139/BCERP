# Sprint 4: wf-fix-bugs Family Integration

> **Estimate:** 2h | **Priority:** P0 | **Dependencies:** S1+S2
> **Revised v0.3:** Complete rewrite — wf-fix-bugs là pure orchestrator (v7.1.0), CI integration target sub-skills wf-fix-triage + wf-fix-execute (F19)

---

## Mục tiêu

Tích hợp GitNexus + Serena vào họ wf-fix-bugs. wf-fix-bugs (v7.1.0) là **pure orchestrator** — nó delegate cho wf-fix-triage (Phase 2) + wf-fix-execute (Phase 3-6). CI integration phải được phân bổ đúng:

- **wf-fix-bugs orchestrator:** PRE-GATE freshness check (Step 0.Na + 0.Nb) + lock-protected session init
- **wf-fix-triage:** Phase 2 bug investigation dùng `gitnexus_query()`
- **wf-fix-execute:** Phase 3 fix execution dùng `gitnexus_impact()` trước mỗi code change

Đặc biệt quan trọng: freshness check khi fix bug vì bug có thể nằm trong code đồng nghiệp vừa push.

---

## Tasks

### Task 4.1: Update wf-fix-bugs Orchestrator — PRE-GATE chỉ — 0.5h

**File:** `.claude/skills/workflow/wf-fix-bugs/SKILL.md`

**Vai trò:** wf-fix-bugs là orchestrator — nó KHÔNG trực tiếp sửa code. CI role của nó giới hạn ở:
- PRE-GATE detection + freshness check (Step 0.Na + 0.Nb)
- Pass CI context vào sub-skill spawn instructions (agent context injection)

**PRE-GATE additions:**
```
### Step 0.Na: Load Code Intelligence Capabilities (CI)

1. Run `ci-detect.sh` → check per-tool TTL + lock
2. Read code-intelligence.json → set GITNEXUS_AVAILABLE, SERENA_AVAILABLE
3. Graceful: lock held → fallback, no block

### Step 0.Nb: Index Freshness Check (CI)

1. Run `ci-freshness-check.sh` → compare HEAD vs index_commit
2. Save freshness status for sub-skill context injection
3. SEVERE (>20 behind) → hiển thị warning cho user (bug có thể từ code mới push)
4. Graceful: non-git → skip
```

**Sub-skill spawn adjustments:**
- Khi spawn wf-fix-triage agent: inject CI context nếu GitNexus available (cho bug investigation)
- Khi spawn wf-fix-execute agent: inject CI context nếu GitNexus available (cho impact analysis)
- Kèm freshness warning khi index stale

**Acceptance criteria:**
- [ ] Protocol 20 referenced trong PRE-GATE
- [ ] PRE-GATE có 2 CI steps (Na + Nb) — orchestrator role only
- [ ] CI context passed vào sub-skill spawn instructions
- [ ] Freshness SEVERE → user warning (bug có thể trong code mới push)
- [ ] Graceful degradation: lock held → Grep (no regression)
- [ ] Không thêm CI steps vào orchestrator procedures (lock-management.md, bash-delegation.md...) — đó là operational files

---

### Task 4.2: Update wf-fix-triage — Phase 2 Bug Investigation — 0.75h

**File:** `.claude/skills/workflow/wf-fix-triage/procedures/phase2-triage.md`

**Thay đổi cụ thể:**

```
BEFORE (Bug Investigation):
  grep -r "related_term" apps/ --include="*.cs" | head -50
  Read + manual trace execution

AFTER (Bug Investigation):
  1. CI-ROUTE understand_flow "{bug_description}"
     → GitNexus query("{bug_description}", task_context="fixing bug", 
                      goal="find execution flows related to bug")
     → Trả về processes + symbols liên quan, ranked by relevance
     ⚠ Nếu freshness behind > 0: "Results based on index N commits behind HEAD"
     → Grep + Read (fallback)
  
  2. CI-ROUTE find_definition "{suspected_function}"
     → Serena find_definition (precise location)
     → Grep (fallback)
  
  3. CI-ROUTE symbol_overview "{key_file}"
     → Serena get_symbols_overview (file structure)
     → Read file (fallback)
```

**Acceptance criteria:**
- [ ] ISG / bug investigation dùng `gitnexus_query()` để tìm execution flows liên quan
- [ ] `find_definition` dùng Serena cho precision
- [ ] `symbol_overview` dùng Serena cho cấu trúc file
- [ ] Freshness caveat hiển thị khi index stale
- [ ] Graceful degradation: mỗi tool fail → fallback
- [ ] Target đúng file: `phase2-triage.md` (F19)

---

### Task 4.3: Update wf-fix-execute — Phase 3 Fix Execution — 0.5h

**File:** `.claude/skills/workflow/wf-fix-execute/procedures/phase3-batch1.md`

> Các file `phase3-batch2.md` và `phase3-batch3.md` dùng cùng pattern.

```
BEFORE (Fix):
  Edit file trực tiếp

AFTER (Fix — thêm CI bước trước khi sửa):
  1. CI-ROUTE impact_analysis "{symbol_to_fix}"
     → GitNexus impact(symbol, upstream, depth=3)
     → Báo cáo blast radius:
       d=1 (WILL BREAK): N files
       d=2 (LIKELY AFFECTED): M files
     → Nếu HIGH/CRITICAL → CDG render (CORE-027)
     ⚠ CDG thêm dòng khi freshness behind > 0:
       "Warning: index N commits behind. Blast radius may be incomplete."
  
  2. CI-ROUTE find_references "{symbol_to_fix}"
     → Serena find_references (tất cả call sites)
     → Verify fix không bỏ sót call site nào
  
  3. Execute fix
  
  4. CI-ROUTE pre_commit_check
     → GitNexus detect_changes()
     → Verify chỉ files dự kiến bị ảnh hưởng
```

**Acceptance criteria:**
- [ ] Pre-fix impact analysis bắt buộc (trong `phase3-batch1.md`)
- [ ] Blast radius report với depth levels
- [ ] HIGH/CRITICAL → CDG render
- [ ] CDG kèm freshness warning khi index stale
- [ ] Post-fix detect_changes verification
- [ ] Graceful degradation (kể cả khi CDG render)
- [ ] Target đúng files: `phase3-batch1.md` (primary), `phase3-batch2.md` + `phase3-batch3.md` (same pattern) (F19)

---

### Task 4.4: Update _contract.json files — 0.25h

**Files:**
- `.claude/skills/workflow/wf-fix-bugs/_contract.json`
- `.claude/skills/workflow/wf-fix-triage/_contract.json`
- `.claude/skills/workflow/wf-fix-execute/_contract.json`

- Thêm `code_intelligence.integration = true`
- Thêm CI tools vào `tools_used[]` (gitnexus_query, gitnexus_impact, gitnexus_detect_changes, serena_find_definition, serena_find_references, serena_get_symbols_overview)

**Acceptance criteria:**
- [ ] Cả 3 skills có `code_intelligence.integration = true`
- [ ] CI tools được liệt kê trong `tools_used[]` phù hợp với vai trò từng skill
- [ ] wf-fix-bugs (orchestrator): tools_used chứa ci-detect, ci-freshness-check
- [ ] wf-fix-triage: tools_used chứa gitnexus_query, serena_find_definition, serena_get_symbols_overview
- [ ] wf-fix-execute: tools_used chứa gitnexus_impact, serena_find_references, gitnexus_detect_changes

---

## Sprint 4 DoD

- [ ] wf-fix-bugs orchestrator SKILL.md: PRE-GATE CI steps (Na + Nb) + pass CI context to sub-skills
- [ ] wf-fix-triage `phase2-triage.md`: bug investigation dùng GitNexus query + Serena find_definition + freshness caveat
- [ ] wf-fix-execute `phase3-batch1.md`: pre-fix impact analysis + post-fix detect_changes + freshness caveat
- [ ] Blast radius report với depth levels
- [ ] CDG render khi HIGH/CRITICAL risk + freshness warning
- [ ] Lock graceful fallback: lock held → Grep (no regression) — verified cho cả 3 skills
- [ ] Graceful degradation verified
- [ ] _contract.json updated cho cả 3 skills
- [ ] Kiến trúc orchestrator được tôn trọng: CI logic trong sub-skills, không phải orchestrator procedures (F19)
