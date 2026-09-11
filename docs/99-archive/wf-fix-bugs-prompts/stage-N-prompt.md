# Stage N Prompt — Phase 6: v5 Removal (Legacy Code Cleanup)

## Context

Phase 5 (Cutover) hoàn tất (PASS). `--engine=v6` là default từ commit `658a29c`.
Sau grace period burn-in (≥ 4 tuần không có regression critical), tiến hành Phase 6:
xóa toàn bộ v5 code paths, legacy files, và migration helpers.

### Trạng thái kiến trúc trước Phase 6

```
DEPRECATED (se bi xoa):
├── .claude/skills/workflow/wf-fix-discover/SKILL.md     # v5 only — 5-Layer discovery
├── .claude/skills/workflow/wf-fix-discover/_contract.json
├── .claude/skills/workflow/wf-fix-discover/procedures/   # v5 procedures
├── .claude/skills/workflow/wf-fix-discover/templates/    # v5 templates
├── --engine flag references trong SKILL.md               # Khong can nua
├── v5 flow sections trong SKILL.md                       # Chay v6 unique
└── issue-v1 schema references                            # Chay issue-v2 unique

GIU LAI (khong xoa):
├── .claude/skills/workflow/wf-fix-triage/SKILL.md        # Compatible v5+v6
├── .claude/skills/workflow/wf-fix-execute/SKILL.md       # Compatible v5+v6
├── .claude/skills/workflow/wf-fix-bugs/SKILL.md          # Orchestrator (v6 only sau Phase 6)
├── .claude/skills/workflow/_shared/                       # Shared services (v6)
├── .claude/skills/workflow/wf-fix-functional/ thru wf-fix-compat/  # 7 dimension lanes
└── All design docs trong docs/design/skills/wf-fix-bugs/
```

---

## Stage N: v5 Removal

### Muc tiêu

Xoa toan bo v5 code paths va legacy files, giu lai chi v6 engine:
1. Xoa `wf-fix-discover/` skill folder (v5 5-Layer discovery)
2. Xoa `--engine` flag khoi SKILL.md (v6 la engine duy nhat)
3. Xoa v5 flow section trong SKILL.md (chi giu v6 flow)
4. Xoa v5 path references trong `00-core.md §4b`
5. Archive v5 schemas va migration helpers
6. Update design docs (README, migration plan)

### Key Constraints

1. **KHONG xoa** `wf-fix-triage/` va `wf-fix-execute/` — van dung cho v6 (compatible)
2. **KHONG xoa** `_shared/` — chi v6 code
3. **KHONG xoa** dimension lane folders (`wf-fix-functional/` thru `wf-fix-compat/`)
4. **KHONG xoa** design docs — cap gia tri lich su
5. **Backup** truoc khi xoa: archive branch hoac commit hash de rollback neu can
6. **Grep verify** sau moi buoc: dam bao khong co reference toi files da xoa

---

## Tasks

### N1: Update SKILL.md — remove --engine flag + v5 flow (CRITICAL)

File: `.claude/skills/workflow/wf-fix-bugs/SKILL.md`

Thay doi:
- Xoa `--engine` khoi `argument-hint` line
- Xoa `--engine` row khoi Arguments table
- Xoa toan bo section `### v5 Engine Flow (khi --engine=v5, **deprecated**)` va tat ca v5 sub-steps (Buoc 1 v5, Step 1.5 Workload Gate Check v5 version)
- Xoa `### v6 Engine Flow (khi --engine=v6)` header → doi thanh `### Engine Flow` (v6 la duy nhat)
- Xoa tat ca references toi `--engine=v5` hoac `--engine` flag trong toan bo file
- Cap nhat `argument-hint` line: bo `--engine=v5|v6`
- Cap nhat Version Alignment table: xoa dong `wf-fix-discover`
- Cap nhat `description` frontmatter: bo mention v5/v6 engine selection

### N2: Delete wf-fix-discover/ folder (CRITICAL)

Xoa toan bo folder:
```
.claude/skills/workflow/wf-fix-discover/
├── SKILL.md
├── _contract.json
├── procedures/
│   ├── _shared.md
│   ├── phase0-init.md
│   └── (other procedure files)
└── templates/
    └── fix-status.json
```

**Verify truoc khi xoa:**
```bash
# Dam bao khong co skill nao reference wf-fix-discover ngoai SKILL.md (se update o N1)
grep -r "wf-fix-discover" .claude/skills/ --include="*.md" -l
# Chi SKILL.md cua wf-fix-bugs duoc phep reference — se clean o N1
```

### N3: Clean 00-core.md §4b v5 paths (HIGH)

File: `.claude/rules/00-core.md`

Xoa tat ca path entries co chua `wf-fix-discover`:
- `| /wf-fix-discover Phase 0 (Init — scope=all) |` ...
- `| /wf-fix-discover Phase 0 (Init — scope=system/module) |` ...
- `| /wf-fix-discover Phase 1c PASS 1 |` ...
- `| /wf-fix-discover Layer 1 |` ...
- `| /wf-fix-discover Layer 4 |` ...
- `| /wf-fix-discover POST-GATE |` ...
- `| /wf-fix-discover Scan Cache layer |` ...
- `| /wf-fix-discover Layer 0 |` ...
- `| /wf-fix-discover Phase 0 (Workload Estimator |` ...
- `| /wf-fix-discover Phase 1 (runtime) |` ...

**GIU LAI** tat ca entries lien quan toi `wf-fix-bugs`, `wf-fix-triage`, `wf-fix-execute`, `_shared/`.

### N4: Clean CLAUDE.md references (HIGH)

File: `CLAUDE.md`

Kiem tra va cap nhat:
- Xoa `wf-fix-discover` khoi skill list table (neu co)
- Xoa `--engine` flag mention (neu co)
- Update `wf-fix-bugs` description: bo "v5 engine", chi mention v6

### N5: Update design docs (MEDIUM)

Files:
- `docs/design/skills/wf-fix-bugs/README.md`:
  - Update §11: Phase 6 COMPLETE
  - Add Stage N vao stage table
  - Update Next Actions: Phase 6 done, khong con next actions
  - Add sign-off entry
- `docs/design/skills/wf-fix-bugs/06-migration-plan.md`:
  - Update §9 Phase 6 status: COMPLETE

### N6: Archive v5 schemas (LOW)

Archive (move, khong xoa) cac files sau vao `docs/archives/`:
- `issue-v1` schema references (neu co standalone files)
- Migration helper `migrate-v1-to-v2.sh` (neu co)

---

## Verification Checklist (POST-GATE)

Sau khi hoan thanh tat ca tasks:

```bash
# N1: Khong con --engine references trong SKILL.md
grep -c "engine=v5\|--engine" .claude/skills/workflow/wf-fix-bugs/SKILL.md
# Expected: 0

# N2: wf-fix-discover khong ton tai
test -d .claude/skills/workflow/wf-fix-discover && echo "FAIL" || echo "PASS"

# N3: Khong con wf-fix-discover references trong 00-core.md
grep -c "wf-fix-discover" .claude/rules/00-core.md
# Expected: 0

# N4: Khong con wf-fix-discover references trong CLAUDE.md
grep -c "wf-fix-discover" CLAUDE.md
# Expected: 0

# N5: Khong con v5 references repo-wide (ngoai archives va design docs)
grep -r "wf-fix-discover\|--engine=v5\|engine_version.*v5" .claude/ --include="*.md" --include="*.json" -l
# Expected: chi design docs (docs/) va archives — KHONG co .claude/skills/ hoac .claude/rules/

# N6: Tat ca _shared/ tests van pass
cd .claude/skills/workflow/_shared && python -m pytest tests/ -q
# Expected: ~507 tests pass, 0 failures
```

---

## File Summary

### Files to DELETE

| File/Folder | Ly do |
|------------|-------|
| `.claude/skills/workflow/wf-fix-discover/` (toan bo folder) | v5 5-Layer discovery — thay the bo v6 lane dispatch |

### Files to MODIFY

| File | Thay doi |
|------|----------|
| `.claude/skills/workflow/wf-fix-bugs/SKILL.md` | Xoa --engine flag, v5 flow, wf-fix-discover references |
| `.claude/rules/00-core.md` | Xoa wf-fix-discover path entries khoi §4b |
| `CLAUDE.md` | Xoa wf-fix-discover references, update skill list |
| `docs/design/skills/wf-fix-bugs/README.md` | Update Phase 6 COMPLETE |
| `docs/design/skills/wf-fix-bugs/06-migration-plan.md` | Update Phase 6 status |

### Files to ARCHIVE (move, not delete)

| File | Destination |
|------|------------|
| `issue-v1` schema files (neu co standalone) | `docs/archives/schemas/` |

---

## Success Criteria

1. `grep -r "wf-fix-discover" .claude/` tra ve 0 match
2. `grep -r "--engine" .claude/skills/workflow/wf-fix-bugs/SKILL.md` tra ve 0 match
3. `test -d .claude/skills/workflow/wf-fix-discover` fail (folder khong ton tai)
4. ~507 tests van pass
5. SKILL.md chi co v6 flow (khong co v5 section)
6. 00-core.md §4b khong con wf-fix-discover paths
7. CLAUDE.md khong con wf-fix-discover references

---

## Rollback

**Khong rollback duoc sau Phase 6.** Dam bao:
- Phase 5 burn-in du dai (≥ 4 tuan)
- Khong co regression critical duoc bao cao
- Backup branch: `git branch backup/pre-phase6-removal` truoc khi thuc hien
