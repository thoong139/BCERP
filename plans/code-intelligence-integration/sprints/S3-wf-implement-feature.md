# Sprint 3: wf-implement-feature Integration

> **Estimate:** 2h | **Priority:** P0 | **Dependencies:** S1+S2
> **Revised v0.3:** procedure file names corrected: phase0-7-safety-gate.md (was phase0-existing-analysis.md), phase3-tdd.md (was phase3-implementation.md) — F18

---

## Mục tiêu

Tích hợp GitNexus + Serena vào `wf-implement-feature` — skill quan trọng nhất vì nó trực tiếp tạo/sửa code.

---

## Tasks

### Task 3.1: Update SKILL.md — 0.25h

**File:** `.claude/skills/workflow/wf-implement-feature/SKILL.md`

**Thay đổi:**
- Thêm reference đến Protocol 20 trong PRE-GATE
- Thêm CI Step 0.Na (Load CI capabilities — detection + lock)
- Thêm CI Step 0.Nb (Index Freshness Check)
- Thêm CI Step 0.5 (Safety Gate — dùng CI tools)
- Thêm CI Step 3 (Implementation — impact check)
- Thêm CI Step 6 (Commit — detect_changes)

**Acceptance criteria:**
- [ ] Protocol 20 referenced trong PRE-GATE
- [ ] CI steps có 2 bước PRE-GATE: Na (detection) + Nb (freshness)
- [ ] CI steps rõ ràng, có `(CI)` marker
- [ ] Graceful degradation note: "Nếu CI tools không available → dùng Grep/Glob. Lock bị giữ → fallback ngay."

---

### Task 3.2: Update Phase 0 PRE-GATE — 0.25h

**File:** `.claude/skills/workflow/wf-implement-feature/SKILL.md` (PRE-GATE section)

**Thêm 2 bước vào PRE-GATE:**

```
### Step 0.Na: Load Code Intelligence Capabilities (CI)

1. Run `ci-detect.sh` → check per-tool TTL
   ├── Cache valid → load + continue
   ├── Stale + acquired lock → scan MCP tools → write cache → continue với CI
   └── Lock held → exit 2 → fallback Grep/Glob (current behavior, no regression)

2. Read `.mc-data/work/_meta/code-intelligence.json`
3. Set CI flags: GITNEXUS_AVAILABLE, SERENA_AVAILABLE

### Step 0.Nb: Index Freshness Check (CI)

1. Run `ci-freshness-check.sh` → compare HEAD vs index_commit
2. Parse result:
   - OK (0 behind) → continue bình thường
   - WARNING (1-5 behind) → ghi nhận, truyền vào agent context
   - STRONG (6-20 behind) → hiển thị warning cho user
   - SEVERE (>20 behind) → hiển thị strong warning + gợi ý re-index
3. Save freshness status để inject vào agent prompts
4. Short-circuit: không phải git repo → skip

**Graceful:** ci-detect.sh fail → WARNING → continue không CI
**Graceful:** ci-freshness-check.sh fail → skip check → continue
```

**Acceptance criteria:**
- [ ] PRE-GATE có 2 CI steps (Na + Nb)
- [ ] Lock held → fallback Grep (không block, không regression)
- [ ] Freshness WARNING hiển thị cho user khi > 5 behind
- [ ] Git short-circuit: không git repo → skip Nb

---

### Task 3.3: Update Phase 0.5 Safety Gate — 0.75h

**File:** `.claude/skills/workflow/wf-implement-feature/procedures/phase0-7-safety-gate.md`

> **Note (F18):** Safety gate procedure đã đổi tên từ `phase0-existing-analysis.md` thành `phase0-7-safety-gate.md` trong thực tế. CI integration target file này.

**Thay đổi cụ thể:**

```
BEFORE (Step 0.5):
  grep -r "{entity_name}" apps/backend/ --include="*.cs"
  grep -r "{endpoint_path}" apps/backend/ --include="*.cs"

AFTER (Step 0.5):
  1. CI-ROUTE find_existing_code "{entity_name}"
     → Serena find_references (primary, precise)
     → GitNexus context("{entity_name}") (secondary, graph)
     → grep -r (fallback)
     ⚠ Nếu freshness behind > 0: kết quả kèm caveat

  2. CI-ROUTE impact_analysis "{entity_name}" (MODIFY scenario only)
     → GitNexus impact("{entity_name}", upstream)
     → WARNING nếu HIGH/CRITICAL → CDG render
     ⚠ Nếu freshness behind > 0: CDG thêm dòng:
       "Warning: index N commits behind. Blast radius may be incomplete."

  3. CI-ROUTE find_existing_code "{endpoint_path}"
     → GitNexus route_map("{endpoint_path}")
     → grep -r (fallback)
```

**Acceptance criteria:**
- [ ] `find_existing_code` dùng Serena → GitNexus → Grep (3-tier)
- [ ] MODIFY scenario tự động chạy `gitnexus_impact()`
- [ ] HIGH/CRITICAL risk → CDG render (CORE-027)
- [ ] CDG kèm freshness warning khi index stale
- [ ] Graceful degradation: mỗi tier fail → chuyển tier tiếp theo
- [ ] Target đúng file: `phase0-7-safety-gate.md`

---

### Task 3.4: Update Phase 3 Implementation — 0.5h

**File:** `.claude/skills/workflow/wf-implement-feature/procedures/phase3-tdd.md`

> **Note (F18):** Implementation procedure là `phase3-tdd.md` (không phải `phase3-implementation.md`).

```
BEFORE (code editing):
  Edit file, không impact check

AFTER (code editing):
  1. CI-ROUTE impact_analysis "{symbol_to_edit}"
     → GitNexus impact(symbol, upstream)
     → Nếu blast radius > 5 files → WARNING header trong edit
     ⚠ Kèm freshness caveat nếu index stale
  2. CI-ROUTE find_references "{symbol_to_edit}"
     → Serena find_references (verify all call sites)
  3. Edit file (theo TDD: test → fail → implement → pass)
  4. CI-ROUTE detect_changes
     → GitNexus detect_changes()
     → Verify only expected files affected
```

**Acceptance criteria:**
- [ ] Impact analysis trước mỗi code edit
- [ ] Blast radius WARNING khi > 5 affected files
- [ ] Post-edit detect_changes verification
- [ ] Freshness caveat hiển thị khi index stale
- [ ] Target đúng file: `phase3-tdd.md`

---

### Task 3.5: Update _contract.json — 0.25h

**File:** `.claude/skills/workflow/wf-implement-feature/_contract.json`

- Thêm `code_intelligence.integration = true`
- Thêm CI tools vào `tools_used[]`: gitnexus_impact, gitnexus_context, gitnexus_detect_changes, gitnexus_route_map, serena_find_references
- Tham chiếu Protocol 20 trong `protocols[]`

**Acceptance criteria:**
- [ ] `code_intelligence.integration = true`
- [ ] CI tools được liệt kê trong `tools_used[]`
- [ ] Protocol 20 referenced

---

### Task 3.6: Update Phase 6 Commit — 0.25h

```
BEFORE:
  git diff --stat

AFTER:
  1. CI-ROUTE pre_commit_check
     → GitNexus detect_changes()
     → Verify affected processes match expected scope
  2. git diff --stat (fallback)
```

**Acceptance criteria:**
- [ ] `gitnexus_detect_changes()` chạy trước commit
- [ ] Affected processes cross-check với feature scope

---

## Sprint 3 DoD

- [ ] SKILL.md updated với CI references (2 PRE-GATE steps + 3 execution steps)
- [ ] Phase 0 PRE-GATE: detection (Na) + freshness (Nb)
- [ ] Phase 0.5 Safety Gate (`phase0-7-safety-gate.md`) dùng 3-tier find_existing_code
- [ ] MODIFY scenario tự động impact analysis + freshness caveat
- [ ] Phase 3 Implementation (`phase3-tdd.md`) có pre-edit impact check + freshness caveat
- [ ] Phase 6 Commit có detect_changes
- [ ] _contract.json updated với code_intelligence.integration = true + CI tools
- [ ] Lock graceful fallback: lock held → Grep (no regression)
- [ ] Graceful degradation verified (test trên project không CI)
- [ ] Tất cả procedure file references khớp với thực tế (F18)
