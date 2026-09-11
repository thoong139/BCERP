# 00 — Master Checklist (Skill Author)

> **Mục đích file:** Checklist 10-step BẮT BUỘC trước khi PR/commit cho skill `wf-e2e-verify`. Gating cho reviewer.

---

## Checklist tổng quan

| # | Step | Trạng thái | Note |
|---|------|-----------|------|
| 1 | Quyết định template variant | [x] | **Orchestrator** — spawn 11 sub-skills wf-e2e-* (KHÔNG spawn agent trực tiếp) |
| 2 | Tạo `SKILL.md` từ `.claude/skills/workflow-skill.md` | [x] | v8.0.0, ~600 dòng (vượt CORE-032 vì routing 11 sub-skills) |
| 3 | Tạo `procedures/` (lazy-load — CORE-032) | [x] | `phase{N}-*.md` per F0-F8, `_shared.md`, `flow-*.md` |
| 4 | Tạo `_contract.json` + validate schema | [x] | v8.0.0, có `orchestrates[]` (11 sub-skills) + `produces_for/consumes_from` |
| 5 | Tạo `templates/` (output từ template — CORE-031) | [x] | `e2e-status.json.template`, `orchestrator-summary.md.template` |
| 6 | Tạo `evals/evals.json` ≥3 test cases + fixtures | [x] | 5 evals: smoke FEAT-001, integration cross-module, resume, --auto, --no-playwright |
| 7 | Tạo `docs/04-skill-design/wf-e2e-verify/` (9 file design canon) | [x] | 9 file + README + 00-master-checklist + agent-prompt + **08-user-scenarios.md** (bắt buộc orchestrator) |
| 8 | Cập nhật `CLAUDE.md` skills table + `docs/01-architecture/07-skills-catalog.md` | [x] | "E2E Testing Pipeline (9 skills)" section |
| 9 | Tạo `.claude/commands/wf-e2e-verify.md` (slash command entry) | [x] | Có |
| 10 | Chạy 4 audit scripts → tất cả PASS | [ ] | **TODO**: chạy `check-skill-design-populated.sh docs/04-skill-design/wf-e2e-verify/` |

---

## Notes per step

### Step 1 — Variant: Orchestrator

`wf-e2e-verify` là **orchestrator** đặc biệt — spawn **sub-skills** (`wf-e2e-finding`, `wf-e2e-test`, `wf-e2e-browser`, ...) chứ KHÔNG spawn agent trực tiếp. Mỗi sub-skill là 1 skill độc lập có `SKILL.md` + `_contract.json` riêng.

→ File `agent-prompt.md` ở folder này thay vì template prompt agent → lưu **sub-skill invocation patterns** (cách orchestrator gọi sub-skill).

### Step 4 — Cross-skill orchestrates[]

`_contract.json` có 11 entries trong `orchestrates[]`:
- `wf-e2e-finding` (F0a, mandatory)
- `wf-e2e-credentials` (F0a sub-step, conditional)
- `wf-e2e-seed-manifest` (F0b, conditional nếu `--no-seed`)
- `wf-e2e-test` (F1, mandatory)
- `wf-e2e-browser` (F2, mandatory)
- `wf-e2e-unblock` (F3, conditional)
- `wf-e2e-implement` (F4, conditional)
- `wf-e2e-retest` (F5, mandatory)
- `wf-e2e-fix` (F6, conditional)
- `wf-e2e-scenario` (F7)
- `wf-e2e-demo` (F8)

### Step 7 — Design canon files

| File | Trạng thái |
|------|-----------|
| `README.md` | ✅ |
| `00-master-checklist.md` | ✅ (file này) |
| `01-vision-principles.md` | ✅ |
| `02-arguments.md` | ✅ |
| `03-architecture.md` | ✅ (orchestrator pattern doc) |
| `04-contracts-data-model.md` | ✅ (legacy naming) |
| `05-execution-profiles.md` | ✅ |
| `06-templates-list.md` | ✅ |
| `07-procedures-structure.md` | ✅ |
| `08-tradeoffs-adr.md` | ✅ |
| `08-user-scenarios.md` | ✅ (file mới — orchestrator BẮT BUỘC theo template v3.1) |
| `09-evals-test-cases.md` | ✅ |
| `agent-prompt.md` | ✅ (file mới — sub-skill invocation patterns) |

---

## Gating reviewer

PR sẽ **REJECT** nếu:
- Step 10 chưa tick
- File này còn `_template_notes` block hoặc placeholder gốc
- Sub-skill nào trong `orchestrates[]` không có folder design canon riêng (tech debt acceptable: chỉ Tier 1 mới có)

---

## Liên kết

- Skill source: [`../../../.claude/skills/workflow/wf-e2e-verify/SKILL.md`](../../../.claude/skills/workflow/wf-e2e-verify/SKILL.md)
- Sub-skills: [`../../../.claude/skills/workflow/wf-e2e-*/`](../../../.claude/skills/workflow/) (11 folders)
- Validation script: [`../../../.claude/scripts/check-skill-design-populated.sh`](../../../.claude/scripts/check-skill-design-populated.sh)
- Template canonical: [`../_template/00-master-checklist.md`](../_template/00-master-checklist.md)
