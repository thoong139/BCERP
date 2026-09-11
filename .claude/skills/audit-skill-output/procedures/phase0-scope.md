# Phase 0 — Scope Detection & Context Loading

> Xác định target skill(s), load SKILL.md specs, init status file. Detect Master Plan (D8).

**PRE-GATE:** Ít nhất 1 workflow skill có output files.

> **`--resume` EARLY EXIT:** Nếu `$ARGUMENTS` có `--resume`:
> 1. Đọc `.mc-data/work/audit-skill-output/audit-skill-output-status.json`
> 2. Đọc `.mc-data/work/audit-skill-output/checkpoint.json`
> 3. **SKIP toàn bộ Phase 0** (không re-init status) → chạy thẳng **Resume Process** (xem SKILL.md §Context & Checkpoint)
> 4. `--resume` chỉ hợp lệ với `--all`. Nếu dùng với skill-name cụ thể → ERROR: "Chỉ dùng --resume với --all"

## Steps

| Step | Action | Tool | Verify |
| ---- | ------ | ---- | ------ |
| 0.1 | Parse `$ARGUMENTS` → xác định target skill(s). Nếu có `--resume` → EARLY EXIT đến Resume Process | — | Target set |
| 0.2 | Nếu `--all`: Glob `.mc-data/work/wf-*` và `.mc-data/docs/phase*` → list skills đã chạy. **CORE-021 (LEGACY_MODE):** Kiểm tra `test -f .mc-data/work/legacy-scan/project-context.md && size > 500 bytes`. Nếu đúng, append shared skills đã hoàn thành: `test -d phase0-brainstorm` → wf-brainstorm (legacy); `test -d phase1-business` → wf-analyze-requirements (legacy); `test -d phase2-features` → wf-define-features (legacy); `test -d phase3-architecture` → wf-design (legacy); `test -d phase4-ux` → wf-design-ux (legacy). **KHÔNG dùng ledger.json** (false positive). | Bash + Glob | skills_to_audit[] |
| 0.3 | Nếu skill-name cụ thể: verify output dir tồn tại. **Legacy flow:** gap analysis → `test -f .mc-data/work/legacy-scan/gap-report.md`; Phase 0-3 docs → `test -d .mc-data/docs/phase{N}-*`; UX docs → `test -d .mc-data/docs/phase4-ux` | Bash | `test -d` passes |
| 0.4 | Đọc SKILL.md của mỗi target skill → extract expected outputs, POST-GATE checks, registry fields. **Nếu SKILL.md delegate sang procedure files** (flow-new.md, flow-legacy.md, phase*.md...) → đọc các procedure files đó để extract POST-GATE cho D6. Ghi vào `skill_spec.procedure_post_gates[]`. | Read | skill_spec loaded |
| 0.5 | Đọc `req-registry.json` | Read | registry loaded |
| 0.6 | Tạo output dir: `.mc-data/work/audit-skill-output/` | Bash | Dir exists |
| 0.6b | Init status file từ `templates/audit-status.json` → populate: `status = "in_progress"`, `skill`, `mode`, `started_at`, `flags` (no_fix/dimension/verbose), `target.skills_to_audit` (nếu --all), `target.current_skill`, `target.remaining_skills` (nếu --all), `phases.phase_0.status = "in_progress"`, `phases.phase_0.started_at`. Lưu tại `.mc-data/work/audit-skill-output/audit-skill-output-status.json` | Write | Status file exists |
| 0.7 | Parse `--dimension` nếu có → filter dimensions | — | dimensions[] set |
| 0.8 | **D8 Detection:** Kiểm tra Master Plan enabled: `test -f .mc-data/work/shared-metrics/baseline-schema.json` HOẶC `test -f .mc-data/docs/_meta/project-digest.json` (output file, KHÔNG dùng template path — template luôn tồn tại gây false positive). Nếu enabled → set `master_plan_enabled = true`. Nếu không → D8 hoàn toàn SKIP cho toàn bộ session. | Bash | `master_plan_enabled` flag |

## POST-GATE

- Target skills identified, SKILL.md specs loaded, registry loaded
- `audit-skill-output-status.json` initialized với phase_0.status = completed
- `master_plan_enabled` detected
- Update status: `phases.phase_0.status = "completed"`, `phases.phase_0.completed_at`, `master_plan_enabled`
- **CORE-026:** Append START entry to `.mc-data/work/_trace/session-log.json` (skill: `audit-skill-output`, event: `START`, target: `[skill-name]`)

## Next

→ READ `procedures/phase1-structural.md` và thực thi.
