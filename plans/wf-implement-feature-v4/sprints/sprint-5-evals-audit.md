# Sprint 5 — Evals + Audit + E2E Regression

**Goal:** Evals ≥ 10 cases + compliance audit + E2E regression test
**Estimated effort:** 2h
**Dependencies:** Sprint 1-4 complete (full v4.0 functionality)
**Output:** v4.0.0 stable — production ready

---

## Mục tiêu cụ thể

1. Mở rộng `evals/evals.json` từ ≥3 cases (current) → ≥10 cases
2. Test cases coverage: single, multi, resume, fresh, profile (4 levels), cache hit, multi-dev (simulated), error ledger, --from-impl consumer
3. `skill-compliance-audit.sh wf-implement-feature` PASS
4. `validate-schema-sync.sh wf-implement-feature` PASS
5. E2E regression với FEAT-STW-ACCT-002 (synthetic, reproducible) — match v3.4.0 baseline output
6. Update memory `project_wf-implement-feature-v4-improvement-plan.md` với metrics
7. Tạo RELEASE-NOTES-v4.0.md

---

## Steps chi tiết

### Step 5.1 — Mở rộng evals/evals.json

**File:** `.claude/skills/workflow/wf-implement-feature/evals/evals.json`

**Cases cần có:**

| # | Case | Trigger | Expected | Verify |
|---|------|---------|----------|--------|
| 1 | Single feature NEW | `/wf-implement-feature FEAT-001` | Session created, files generated, registry updated | session_dir exists, impl-status v2.0, registry impl_status=done |
| 2 | Single feature EXTEND | `/wf-implement-feature FEAT-001 --extend` | Existing patterns scanned, NEW session, code modified | scenario=EXTEND, existing-patterns.json populated |
| 3 | Multi-feature | `/wf-implement-feature --features=FEAT-001,FEAT-002` | flow-multi.md routed, dependency analyzed | multi-feature-report-*.md exists |
| 4 | Resume sau crash | Crash giữa Phase 3 → `/wf-implement-feature FEAT-001 --resume` | Continue từ checkpoint, no re-do | current.txt unchanged, phase-summary shows correct phase |
| 5 | Fresh archive | `/wf-implement-feature FEAT-001 --fresh` | Old session moved to archived/, new session start | archived/ has old session_id |
| 6 | Profile=quick | `/wf-implement-feature FEAT-001 --profile=quick` | Code-reviewer only, smoke tests | impl-status profile=quick, phase4 has 1 reviewer |
| 7 | Profile=deep | `/wf-implement-feature FEAT-001 --profile=deep` | Parallel waves, 3 reviewers | impl-status profile=deep, contracts.json exists |
| 8 | Cache hit (2 features cùng module) | Sequence: FEAT-001 then FEAT-002 (cùng module CRM) | Feature 2 cache hit, tokens saved | cache_hits.existing_patterns=true cho FEAT-002 |
| 9 | Multi-dev (simulated) | Run skill 2 lần với 2 hostname mock | History JSONL có 2 entries, no merge conflict | implementations-index.jsonl has 2 lines |
| 10 | Error ledger trigger | Force test fail → trigger E301 | error-ledger.json populated | jq query E301 entry |
| 11 | --from-impl consumer (synthetic) | Mock wf-prepare-deployment skill consume consumer_hints | hints loaded successfully | Mock script reads files_for_changelog |
| 12 | Profile auto-recommendation | No --profile, file count = 50 → auto deep | auto-detected profile | impl-status profile=deep |

**evals.json structure:**
```json
{
  "schema_version": "1.0",
  "skill": "wf-implement-feature",
  "version": "4.0.0",
  "cases": [
    {
      "id": "EVAL-001",
      "name": "Single feature NEW",
      "scenario": "...",
      "setup": ["..."],
      "trigger": "/wf-implement-feature FEAT-EVAL-001",
      "expected": ["..."],
      "verify_commands": ["..."]
    }
  ]
}
```

---

### Step 5.2-5.9 — Implement test cases

Theo bảng trên, mỗi case có setup script + verify script. Cases 1-12 viết tuần tự.

**Helper:** `tests/eval-runner.sh` — generic runner: setup → trigger → verify → cleanup.

---

### Step 5.10 — Run skill-compliance-audit.sh

```bash
.claude/scripts/skill-compliance-audit.sh wf-implement-feature
```

**Expected output:** All checks PASS:
- SKILL.md frontmatter valid
- _contract.json schema valid
- All required fields present
- procedure[] paths exist
- Templates exist for all required outputs
- evals/evals.json ≥ 3 cases

**Fix nếu fail:** Update SKILL.md / _contract.json / templates per audit report.

---

### Step 5.11 — Run validate-schema-sync.sh

```bash
.claude/scripts/validate-schema-sync.sh wf-implement-feature
```

**Expected:** Contract schema synced với SKILL.md outputs.

**Fix:** Update _contract.json `outputs.working[]` theo SKILL.md table.

---

### Step 5.12 — E2E regression với FEAT-STW-ACCT-002

**Setup synthetic test case:**

**File:** `evals/synthetic-feat-stw-acct-002/`
```
├── setup/
│   ├── req-registry.json (snippet với FEAT-STW-ACCT-002)
│   ├── feature-spec.md (phase2-features/...)
│   └── task-impl.md (phase5-implementation/tasks/...)
├── baseline/                    ← v3.4.0 expected output
│   ├── impl-status.expected.json
│   ├── impl-report.expected.md
│   └── phase-summary.expected.md
└── compare.sh                   ← Diff actual vs baseline
```

**Run:**
```bash
cd evals/synthetic-feat-stw-acct-002
bash setup.sh                                    # Copy snippets to test workspace
claude /wf-implement-feature FEAT-STW-ACCT-002 --profile=standard
bash compare.sh                                   # Diff: tolerate timestamp/session_id differences
```

**Expected:** All assertions pass:
- Files created match baseline (file paths)
- Tests count match
- impl_status updated to "done"
- consumer_hints populated correctly
- Vietnamese diacritics in slug correct (regression test for Finding #2)

---

### Step 5.13 — Update memory

**File:** `C:\Users\hanoi\.claude\projects\z--Working-MCV3\memory\project_wf-implement-feature-v4-improvement-plan.md`

```markdown
---
name: wf-implement-feature v4.0 Improvement Plan
description: ✅ COMPLETED YYYY-MM-DD — skill v4.0.0. 5 sprints, ~14h. Session isolation + bash scripts library + JSONL history + profile system + pattern cache + schema v2.0 + global decisions + error ledger.
type: project
---

✅ COMPLETED YYYY-MM-DD — skill v4.0.0 released.

**Achievements:**
- 9 gaps fixed (G1-G9 except G8 if D4=C)
- 7 bash scripts created in .claude/scripts/wf-implement-feature/
- Session isolation per CORE-030
- Multi-dev safety: JSONL history index check-in, .gitignore conventions
- Profile system: quick/standard/deep/exhaustive
- Pattern cache: ~80% token saving for multi-feature in same module
- Schema v2.0 with consumer_hints for downstream skills
- Global decision registry for cross-feature consistency
- Namespaced error codes E1xx-E9xx + per-session error-ledger.json

**Effort:** ~14h actual / 14h estimated.

**E2E test:** FEAT-STW-ACCT-002 synthetic regression PASS.

**Followups:** None blocking. Optional v5.0:
- D4 phase rename if not done in v4.0
- Cross-skill flag --from-impl integration in wf-prepare-deployment / wf-fix-bugs / wf-verify-sync
```

---

### Step 5.14 — Tạo RELEASE-NOTES-v4.0.md

**File:** `plans/wf-implement-feature-v4/RELEASE-NOTES-v4.0.md`

```markdown
# wf-implement-feature v4.0 — Release Notes

**Release date:** YYYY-MM-DD
**Status:** Stable
**Effort:** ~14h actual / 14h estimated

## Highlights

### 🆕 Session-Isolated Working Directory
- Re-implement (EXTEND/MODIFY) không ghi đè state cũ
- Sessions: `$FEATURE_SLUG/sessions/{date}-{time}-{host}/`
- `current.txt` pointer cho --resume routing
- Migration script idempotent cho data v3.x

### 🆕 Bash Scripts Library
- 7 scripts trong `.claude/scripts/wf-implement-feature/`
- ~150 dòng inline bash giảm từ SKILL.md (-25% line count)
- Reusable patterns: lock acquisition, slug normalization, POST-GATE validation

### 🆕 JSONL History Index
- `.history/implementations-index.jsonl` check-in cho multi-dev visibility
- 1 line / implementation run, append-only, git-merge friendly

### 🆕 Profile System
- `--profile=quick|standard|deep|exhaustive` flag
- Auto-recommendation theo file count
- Token saving cho profile=quick (skip parallel + integration tests)

### 🆕 Pattern Cache
- `.cache/{module_slug}/existing-patterns.{git_sha}.json`
- TTL 24h + git SHA invalidation
- ~80% token saving cho multi-feature trong cùng module

### 🆕 Output Schema v2.0
- `consumer_hints` cho downstream skills
- `--from-impl` flag chuẩn cho wf-prepare-deployment / wf-fix-bugs / wf-verify-sync (OPTIONAL)

### 🆕 Global Decision Registry
- `.mc-data/docs/_meta/decision-registry.global.json`
- Cross-feature architectural consistency
- APPEND-only, mutex-protected

### 🆕 Observability
- Per-session `error-ledger.json`
- Namespaced error codes E1xx (Phase 1) → E9xx (cross-cutting)
- Backward compat alias E001-E014 → E1xx-E9xx

## Breaking Changes

⚠️ Path layout changed: `$FEATURE_SLUG/foo.json` → `$FEATURE_SLUG/sessions/{id}/foo.json`

**Migration:** Auto-run on first execution. No data loss.

⚠️ impl-status.json schema bumped to 2.0. Old skills reading flat schema continue to work (alias supported).

## Compatibility

- ✅ Backward compat: data v3.x auto-migrated
- ✅ All 26 v3.4.0 fixes preserved (regression test PASS)
- ✅ wf-design / wf-plan-modules / wf-verify-sync / wf-preflight: unchanged contracts

## Stats

- 7 bash scripts created
- ~150 dòng inline bash → script delegation
- 12 evals (vs ≥3 v3.4.0)
- 14h development effort
- 0 blocking followups

## Upgrade

```bash
git pull
# Skill auto-detects v3.x layout on first run → migrates to v4.0
```
```

---

## Definition of Done — Sprint 5

- [ ] evals/evals.json ≥ 12 cases (target ≥10, hit 12 với coverage rộng)
- [ ] Tất cả 12 evals pass
- [ ] skill-compliance-audit.sh wf-implement-feature PASS
- [ ] validate-schema-sync.sh wf-implement-feature PASS
- [ ] E2E regression FEAT-STW-ACCT-002 PASS (synthetic baseline)
- [ ] Memory entry updated
- [ ] RELEASE-NOTES-v4.0.md complete
- [ ] CHANGELOG trong SKILL.md frontmatter có v4.0.0 entry
- [ ] Plan README.md status = ✅ FINISHED
- [ ] Plan progress.md tất cả sprint = ✅

---

## Risks Sprint 5

| Risk | Mitigation |
|------|-----------|
| E2E test environment không tái lập được | Synthetic test case stand-alone, chỉ depend on registry + task file snippets |
| Compliance audit fail vì missing fields | Fix incrementally — audit report cho biết field nào missing |
| Eval cases quá phức tạp run-time | Cap timeout per case (5 min), parallelize independent cases |
| Memory limit exceed (12 evals × full project state) | Use synthetic minimal projects per eval, không full real project |

---

## Final deliverables

1. **Code:** v4.0.0 skill released
2. **Documentation:**
   - SKILL.md changelog v4.0.0
   - RELEASE-NOTES-v4.0.md
   - 5 sprint files marked complete
   - progress.md final status
3. **Tests:**
   - evals/evals.json (12 cases)
   - synthetic regression test
4. **Memory:**
   - project_wf-implement-feature-v4-improvement-plan.md updated
   - MEMORY.md index updated
5. **Compliance:**
   - skill-compliance-audit PASS
   - validate-schema-sync PASS

**Done:** Skill v4.0 stable, ready for daily use across MCV3 projects.
