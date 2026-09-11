<!--
_template_notes:
  purpose: Checklist 10-step end-to-end TỪ ĐẦU đến commit cho 1 skill mới.
  populate:
    - Đổi mọi `{skill-name}` thành tên skill thực tế (lowercase-kebab-case)
    - Tick [x] khi hoàn thành step (KHÔNG xóa step nào kể cả đã skip)
    - Step nào skip ghi rõ lý do tại cột "Note"
    - Khi commit: file này phải còn checklist (không xóa)
  Mục tiêu: NGĂN CONTRIBUTOR BỎ SÓT step (CLAUDE.md update, slash command, audit script)
  độ dài: cố định 10 step, không mở rộng
-->

# 00 — Master Checklist (Skill Author)

> **Mục đích file:** Checklist 10-step BẮT BUỘC trước khi PR/commit skill mới `{skill-name}`. Gating cho reviewer.

---

## Checklist tổng quan

| # | Step | Trạng thái | Note |
|---|------|-----------|------|
| 1 | Quyết định template variant (standard / quick / lane / orchestrator) | [ ] | — |
| 2 | Tạo `SKILL.md` từ `.claude/skills/workflow-skill.md` | [ ] | — |
| 3 | Tạo `procedures/` (lazy-load — CORE-032) | [ ] | — |
| 4 | Tạo `_contract.json` + validate schema | [ ] | — |
| 5 | Tạo `templates/` (output từ template — CORE-031) | [ ] | — |
| 6 | Tạo `evals/evals.json` ≥3 test cases + fixtures | [ ] | — |
| 7 | Tạo `docs/04-skill-design/{skill-name}/` (10 file design canon — gồm 03-architecture + 03-phase-routing) | [ ] | — |
| 8 | Cập nhật `CLAUDE.md` skills table + `docs/01-architecture/07-skills-catalog.md` | [ ] | — |
| 9 | Tạo `.claude/commands/{skill-name}.md` (slash command entry) | [ ] | — |
| 10 | Chạy 4 audit scripts → tất cả PASS | [ ] | — |

---

## Chi tiết từng step

### Step 1 — Quyết định variant

| Loại skill | Phases | Spawn agents? | Variant |
|---|---|---|---|
| **Quick** | 1-2 | ❌ | Bỏ Phase 0, Context/Checkpoint, Registry; chỉ cần 4 file design |
| **Standard** | 3-5 | Có thể | `_template/` đầy đủ (10 file: 01, 02, 03-architecture, 03-phase-routing, 04..09) |
| **Lane/Probe** | 1-2 | Spawn từ orchestrator | Thay `02-arguments.md` → `02-quality-dimensions.alt.md` + thêm `05-execution-profiles.alt.md` |
| **Orchestrator** | 5-7 | ≥3 lanes | `_template/` đầy đủ + thêm `08-user-scenarios.alt.md` |

**Output step 1:** Ghi variant vào `docs/04-skill-design/{skill-name}/README.md` §2.

### Step 2 — Tạo `SKILL.md`

```bash
mkdir -p .claude/skills/workflow/{skill-name}
cp .claude/skills/workflow-skill.md .claude/skills/workflow/{skill-name}/SKILL.md
# Edit: đổi name, version, description, arguments theo variant đã chọn ở Step 1
```

**Verify:**
- `wc -l SKILL.md` ≤ 500 dòng (CORE-032)
- Frontmatter có `name`, `version`, `description`, `argument-hint`
- Có ít nhất 1 `[skill-name]` placeholder đã đổi

### Step 3 — Tạo `procedures/`

```bash
mkdir -p .claude/skills/workflow/{skill-name}/procedures
touch _shared.md phase1-init.md ... phaseN-report.md resume-status.md
```

**Verify:** Mỗi `phase{N}-*.md` có 4 sections (Header, PRE-GATE, Steps, POST-GATE). Xem `07-procedures-structure.md`.

### Step 4 — `_contract.json`

```bash
# Copy từ workflow-skill.md §Sample, đổi tên + version
# Validate:
bash .claude/scripts/validate-schema-sync.sh {skill-name}
```

**Verify:** Required 8 top-level fields đầy đủ + `outputs.working[].template` không null trừ khi có lý do.

### Step 5 — `templates/`

```bash
mkdir -p .claude/skills/workflow/{skill-name}/templates
# Tạo template cho mỗi output có schema (status.json, Phase{N}-report.md, ...)
```

**Verify:** `_contract.json` `outputs.working[].template` paths tồn tại thật.

### Step 6 — `evals/evals.json`

**Tối thiểu 3 test cases:** smoke + integration + edge. Xem `09-evals-test-cases.md` cho structure. Thêm fixtures vào `tests/fixtures/{skill-name}/` (xem `eval-fixtures-sample.md`).

### Step 7 — Design canon

```bash
cp -r docs/04-skill-design/_template docs/04-skill-design/{skill-name}
# Populate 9-10 file (tuỳ variant)
# Xóa toàn bộ _template_notes blocks
```

**Verify:** `bash .claude/scripts/check-skill-design-populated.sh docs/04-skill-design/{skill-name}/`

### Step 8 — Cập nhật catalog

| File | Cập nhật gì |
|------|-------------|
| `CLAUDE.md` | Bảng "Workflow chính" hoặc "Hỗ trợ & Quality" — thêm row skill mới |
| `docs/01-architecture/07-skills-catalog.md` | Thêm skill + output paths + contracts |
| `docs/05-review-standards/{skill-name}.md` | Tạo review checklist riêng |

### Step 9 — Slash command

```bash
# Copy template từ skill cùng loại
cp .claude/commands/wf-preflight.md .claude/commands/{skill-name}.md
# Edit: tên, mô tả, arguments
```

**Verify:** `/{skill-name}` xuất hiện trong slash command list.

### Step 10 — Audit scripts

Chạy **TẤT CẢ 4** scripts dưới — phải PASS hết:

```bash
# 1. Skill compliance (structure check)
./.claude/scripts/skill-compliance-audit.sh {skill-name}

# 2. Schema sync (contract validation)
./.claude/scripts/validate-schema-sync.sh {skill-name}

# 3. Pipeline naming (kebab-case enforcement)
./.claude/scripts/validate-pipeline-naming.sh

# 4. Design canon populated (template metadata stripped)
bash .claude/scripts/check-skill-design-populated.sh docs/04-skill-design/{skill-name}/
```

---

## Gating reviewer

PR sẽ **REJECT** nếu:
- Bất kỳ step nào trong bảng tổng quan `[ ]` (chưa tick) mà không có Note giải thích
- Bất kỳ audit script nào FAIL
- File này (`00-master-checklist.md`) còn chứa `{skill-name}` placeholder hoặc `_template_notes` block

---

## Liên kết

- Skill source template: [`.claude/skills/workflow-skill.md`](../../../.claude/skills/workflow-skill.md)
- Validation script: [`.claude/scripts/check-skill-design-populated.sh`](../../../.claude/scripts/check-skill-design-populated.sh)
- README design canon: [`../README.md`](../README.md)
- Standard skill anatomy: [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md)
