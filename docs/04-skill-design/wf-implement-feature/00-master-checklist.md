# 00 — Master Checklist (Skill Author)

> **Mục đích file:** Checklist 10-step BẮT BUỘC trước khi PR/commit cho skill `wf-implement-feature`. Gating cho reviewer.

---

## Checklist tổng quan

| # | Step | Trạng thái | Note |
|---|------|-----------|------|
| 1 | Quyết định template variant (standard / quick / lane / orchestrator) | [x] | **Standard + spawn agents** — không phải orchestrator (không gọi sub-skills) |
| 2 | Tạo `SKILL.md` từ `.claude/skills/workflow-skill.md` | [x] | v5.2.0, 700+ dòng (vượt CORE-032 vì lazy-load qua procedures/) |
| 3 | Tạo `procedures/` (lazy-load — CORE-032) | [x] | `phase0-*`, `phase1-*`, ..., `phase6-*`, `_shared.md`, `flow-multi.md` (multi-feature) |
| 4 | Tạo `_contract.json` + validate schema | [x] | v5.2.0, có `consumes_from.wf-fix-bugs` (cross-skill `--from-fix-bugs`) |
| 5 | Tạo `templates/` (output từ template — CORE-031) | [x] | `templates/` directory với scaffold + check-list templates |
| 6 | Tạo `evals/evals.json` ≥3 test cases + fixtures | [x] | 4 evals: smoke, integration, multi-feature, resume |
| 7 | Tạo `docs/04-skill-design/wf-implement-feature/` (9 file design canon) | [x] | 9 file + README + 00-master-checklist (file này) + agent-prompt |
| 8 | Cập nhật `CLAUDE.md` skills table + `docs/01-architecture/07-skills-catalog.md` | [x] | Có ở CLAUDE.md "Workflow chính" + skills-catalog |
| 9 | Tạo `.claude/commands/wf-implement-feature.md` (slash command entry) | [x] | Có |
| 10 | Chạy 4 audit scripts → tất cả PASS | [ ] | **TODO**: chạy `check-skill-design-populated.sh docs/04-skill-design/wf-implement-feature/` |

---

## Notes per step

### Step 1 — Variant: Standard + spawn agents

`wf-implement-feature` KHÔNG phải orchestrator (không spawn sub-skills `wf-*` khác). Nó là **standard skill spawn agents** — Phase 4 spawn 3 reviewer agents song song (code-reviewer + security + qa-lead). Có file `agent-prompt.md` riêng.

### Step 2 — SKILL.md size warning

SKILL.md hiện 700+ dòng, vượt ngưỡng CORE-032 ≤500. Lý do: skill có 7 phases (0-6), mỗi phase có nhiều flows (single-feature vs multi-feature). Mitigation: toàn bộ logic execution lazy-load qua `procedures/phase{N}-*.md`. SKILL.md chỉ là routing hub.

> **Khuyến nghị future refactor:** rút SKILL.md xuống <500 dòng bằng cách di chuyển bảng arguments chi tiết sang `02-arguments.md`.

### Step 7 — Design canon files có trong folder

| File | Trạng thái |
|------|-----------|
| `README.md` | ✅ |
| `00-master-checklist.md` | ✅ (file này) |
| `01-vision-principles.md` | ✅ |
| `02-arguments.md` | ✅ |
| `03-architecture.md` | ✅ |
| `04-contracts-data-model.md` | ✅ (legacy naming, tương đương `04-file-contract.md`) |
| `05-execution-profiles.md` | ✅ |
| `06-templates-list.md` | ✅ |
| `07-procedures-structure.md` | ✅ |
| `08-tradeoffs-adr.md` | ✅ |
| `09-evals-test-cases.md` | ✅ |
| `agent-prompt.md` | ✅ (file mới — backfill v3.1) |

### Step 10 — Validation

```bash
bash .claude/scripts/check-skill-design-populated.sh docs/04-skill-design/wf-implement-feature/
```

**Note legacy naming:** Folder dùng `04-contracts-data-model.md` (legacy) thay vì `04-file-contract.md` chuẩn template v3.1. Script sẽ FAIL T1 cho file thiếu — accept tech debt, migrate sau khi major refactor.

---

## Gating reviewer

PR sẽ **REJECT** nếu:
- Step 10 chưa tick (audit chưa chạy)
- File này còn `_template_notes` block
- File này còn placeholder gốc

---

## Liên kết

- Skill source: [`../../../.claude/skills/workflow/wf-implement-feature/SKILL.md`](../../../.claude/skills/workflow/wf-implement-feature/SKILL.md)
- Validation script: [`../../../.claude/scripts/check-skill-design-populated.sh`](../../../.claude/scripts/check-skill-design-populated.sh)
- Template canonical: [`../_template/00-master-checklist.md`](../_template/00-master-checklist.md)
