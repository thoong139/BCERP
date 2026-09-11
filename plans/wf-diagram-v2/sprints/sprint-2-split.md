# Sprint 2 — Split Monolith

**Sprint:** 2 of 6
**Effort estimate:** 3h
**Status:** 🔄 IN_PROGRESS (2026-05-03)
**Goal:** Tách `SKILL.md` (565 dòng) và `flow-new.md` (918 dòng) thành lazy-load hub + 8 phase files + `_shared.md`.

---

## Tasks

| # | Task | Status |
|---|------|--------|
| 2.0 | Tạo file này | ✅ |
| 2.1 | Backup flow-new.md → flow-legacy.md.bak | ✅ |
| 2.2 | Tạo procedures/_shared.md | ✅ |
| 2.3 | Tạo procedures/phase0-setup.md | ✅ |
| 2.4 | Tạo procedures/phase1-precheck.md | ✅ |
| 2.5 | Tạo procedures/phase2-source-analysis.md | ✅ |
| 2.6 | Tạo procedures/phase3-plan.md | ✅ |
| 2.7 | Tạo procedures/phase4-system.md | ✅ |
| 2.8 | Tạo procedures/phase5-module.md | ✅ |
| 2.9 | Tạo procedures/phase6-detail.md | ✅ |
| 2.10 | Tạo procedures/phase7-validation.md | ✅ |
| 2.11 | Refactor SKILL.md → routing hub ≤ 250 dòng | ✅ |
| 2.12 | Update _contract.json.procedure_files[] | ✅ |
| 2.13 | Smoke test baseline | ✅ PASS 12/12 CRITICAL (100%) — 1 warning: "4.5 Multiple phases" expected for routing hub |

---

## Target structure sau Sprint 2

```
.claude/skills/workflow/wf-diagram/
├── SKILL.md                        # routing hub ≤ 250 dòng (refactored)
├── _contract.json                  # procedure_files[] → 11 entries (updated)
├── procedures/
│   ├── _shared.md                  # state vars, slugify, error matrix, analysis schema (NEW)
│   ├── phase0-setup.md             # Phase 0: Setup & Arg Validation (NEW)
│   ├── phase1-precheck.md          # Phase 1: Pre-check Existing (NEW)
│   ├── phase2-source-analysis.md   # Phase 2: Source Analysis (NEW)
│   ├── phase3-plan.md              # Phase 3: Generation Plan (NEW)
│   ├── phase4-system.md            # Phase 4: System Diagrams (NEW)
│   ├── phase5-module.md            # Phase 5: Module Diagrams (NEW)
│   ├── phase6-detail.md            # Phase 6: Detail Diagrams (NEW)
│   ├── phase7-validation.md        # Phase 7: Validation & Output (NEW)
│   └── flow-legacy.md.bak          # BACKUP — original flow-new.md
├── templates/                      # 14 templates (unchanged Sprint 2)
└── evals/                          # 5 evals (unchanged Sprint 2, fix in Sprint 5)
```

---

## Definition of Done (Sprint 2)

- [ ] SKILL.md ≤ 250 dòng, là routing hub với Phase Routing Map table
- [ ] Mỗi phase file (phase0-phase7): ≤ 250 dòng, self-contained
- [ ] `_shared.md` chứa state vars + slugify + error matrix + analysis-v1 schema
- [ ] `flow-legacy.md.bak` tồn tại (backup của original)
- [ ] `_contract.json.procedure_files[]` có 11 entries
- [ ] SKILL.md `procedure` field updated → `procedures/phase0-setup.md`

---

## Risk

Nếu SKILL.md routing hub quá ngắn → mất context quan trọng (Mermaid 8.8.0 safety rules, DBML conventions).
**Mitigation:** Giữ nguyên phần "Mermaid 8.8.0 Safety Rules" và "DBML conventions" trong SKILL.md routing hub (là cross-cutting rules cho ALL phases) — phase files chỉ reference "xem SKILL.md §Mermaid 8.8.0 Safety Rules".
