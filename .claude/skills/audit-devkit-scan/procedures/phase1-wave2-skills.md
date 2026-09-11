# Phase 1 — Wave 2: Skill Scans (2 batches PARALLEL)

> Spawn `skill-auditor` để scan SKILL.md + _contract.json theo 2 batches song song.

**PRE-GATE:** `$SESSION_DIR/audit-index.json` tồn tại + Wave 1 hoàn thành (hoặc skip Wave 1 nếu --skill mode)

**📤 OUTPUT:** 2 files `findings-skills-*.json` (template: `templates/findings.json`)

---

## Batch Plan (default)

| Batch | Auditor | Scope | Max Files | Output |
|-------|---------|-------|-----------|--------|
| 1.2a | `skill-auditor` | `workflow/**/SKILL.md` | ≤15 | `findings-skills-workflow.json` |
| 1.2b | `skill-auditor` | non-workflow `SKILL.md` (audit-*, status, ui-ux-pro-max) | ≤10 | `findings-skills-other.json` |

> **2 batches SPAWN PARALLEL.**

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.2.1 | Đọc `audit-index.json` → lọc `components.skills[]` theo `category` (workflow vs other) | Read | 2 lists ready |
| 1.2.2 | **Spawn 2 skill-auditor batches PARALLEL.** Prompt theo `_shared.md` §Auditor Prompt Template. Criteria: S1-S12 (xem `_shared.md` §Skill Criteria) | Agent (×2) | 2 agents started |
| 1.2.3 | Thu thập 2 results, parse JSON | - | Parsed |
| 1.2.4 | E004 fallback nếu cần | Bash/Read | JSON extracted |
| 1.2.5 | WRAP results vào schema `audit-findings-v1` (xem `_shared.md` §Findings JSON Build Helper) → WRITE `$SESSION_DIR/findings-skills-{workflow|other}.json` | Read+Write | 2 files written |
| 1.2.6 | Validate: `node -e "JSON.parse(...)"` | Bash | OK |
| 1.2.7 | UPDATE `scan-status.json`: `wave_2_skills.completed_batches` += 2, `wave_2_skills.status = "completed"`, `metrics.agent_spawns += 2` | Edit | status updated |

---

## Focused Mode (`--skill=<name>`)

> Khi user pass `--skill=<name>` ở Phase 0, **SKIP** Wave 1, 3, 3.5, 4. Chỉ chạy Wave 2 focused:

| Step | Action |
|------|--------|
| F.1 | Spawn 1 `skill-auditor` cho `[name]/SKILL.md` + `_contract.json` |
| F.2 | Đọc `cross_skill_contracts.{produces_for, consumes_from}` từ `_contract.json` của skill đó |
| F.3 | Lightweight cross-ref: cho mỗi downstream/upstream skill, verify path tồn tại + paths trong SKILL.md khớp `00-core.md §4b` |
| F.4 | WRITE `$SESSION_DIR/findings-skills-focused.json` |
| F.5 | Skip thẳng đến Phase 2 (merge với chỉ 1 input file) |

---

## Delta Mode (`--since=<commit>`)

> Trong delta mode, Wave 2 chỉ scan skills có file thay đổi trong git diff:

1. Filter `components.skills[]` theo `path` xuất hiện trong `git diff --name-only <commit>..HEAD -- .claude/`
2. Nếu skill thuộc `workflow/` → batch 1.2a, ngược lại → 1.2b
3. Nếu cả 2 batches đều rỗng → skip Wave 2 entirely + WARNING

---

## Auditor Prompt — Skeleton cho `skill-auditor`

```
Bạn là skill-auditor. Audit các SKILL.md files sau:
[paths từ batch — ≤20 files]

Cho mỗi SKILL.md, KIỂM TRA cả `_contract.json` cùng folder.

Kiểm tra theo criteria S1-S12:
- S1: Frontmatter (name, version, description, argument-hint, allowed-tools, TRIGGER)
- S2: _contract.json sync (tồn tại, $schema đúng, fields khớp SKILL.md)
- S3: Phase structure (PRE-GATE + EXECUTION + POST-GATE)
- S4: Shared protocols reference
- S5: Registry Safe-Write nếu update registry
- S6: Cross-skill referenced paths tồn tại
- S7: evals/ với ≥3 test cases
- S8: Template references tồn tại
- S9: POST-GATE T1 minimum
- S10: Error handling section/codes
- S11: Cross-skill contract completeness (cross_skill_contracts.produces_for/consumes_from)
- S12: Output path alignment vs 00-core.md §4b

OUTPUT FORMAT: JSON array theo schema audit-findings-v1.
component = "skill" cho mọi finding.
```

---

## Error Handling

- **E003/E004:** xem Wave 1 cho retry logic
- **--skill not found:** Glob suggest closest match (Levenshtein distance) → user chọn

**POST-GATE:**
- 2 files (hoặc 1 file `findings-skills-focused.json` nếu --skill mode) tồn tại + valid JSON
- `scan-status.json.phases.phase_1_scan.waves.wave_2_skills.status == "completed"`

---

## Cross-references

- Auditor prompt template: `_shared.md` §Auditor Prompt Template
- Criteria S1-S12: `_shared.md` §Skill Criteria
- Findings schema: `templates/findings.json`
- Next wave: `phase1-wave3-templates-rules-hooks.md`
