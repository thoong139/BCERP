# MCV3 Skill Anatomy Guide

> Mô tả cấu trúc chi tiết của một skill trong MCV3 DEVKIT.
> Dùng làm tham chiếu khi tạo skill mới hoặc debug skill hiện có.

---

## Tổng quan

Mỗi skill trong MCV3 là một **thư mục tự chứa** trong `.claude/skills/workflow/[skill-name]/`.
MCV3 có 5-layer anatomy, sâu hơn CKE's 3-level model.

```
.claude/skills/workflow/[skill-name]/
├── SKILL.md             ← Layer 1: Entry point & trigger logic
├── _contract.json       ← Layer 2: Machine-readable I/O contract
├── procedures/          ← Layer 3: Step-by-step execution flows
│   └── flow-new.md
├── templates/           ← Layer 4: Output document templates
│   └── [phase]/[doc].md
└── evals/               ← Layer 5: Evaluation criteria (optional)
```

---

## Layer 1: SKILL.md — Entry Point

**Mục đích**: Định nghĩa frontmatter metadata, trigger conditions, và execution logic.

### Frontmatter schema:
```yaml
---
name: [skill-name]           # Phải match tên thư mục
version: [semver]            # e.g. 8.0.0
last_updated: [YYYY-MM-DD]
description: |               # Multi-line: mô tả + trigger conditions
  [Mô tả ngắn]
  LUÔN dùng skill này khi: [explicit trigger list]
  KHÔNG trigger khi: [anti-triggers]
argument-hint: "[args]"      # Hint cho user (optional)
allowed-tools: [tool-list]   # Write, Read, Bash, Glob, etc.
---
```

### Body sections chuẩn:
1. **Overview table** — Mục đích, prerequisites, duration, phases, I/O
2. **Workflow Position** — ASCII diagram showing position trong pipeline
3. **Phase N: [Name]** — Từng bước thực thi với POST-GATE verification
4. **POST-GATE** — Verification checklist sau mỗi phase

**So với CKE**: CKE SKILL.md chỉ có frontmatter + minimal prose. MCV3's SKILL.md dài hơn nhiều, chứa cả execution logic và workflow diagrams.

---

## Layer 2: _contract.json — Machine-Readable Contract

**Mục đích**: Cho hooks, scripts, và agents đọc để validate I/O dependencies.

### Schema:
```json
{
  "$schema": "skill-contract-v1",
  "skill": "[skill-name]",
  "version": "[semver]",
  "phase": "[phase-name]",
  "description": "[mô tả ngắn]",
  "procedure": "procedures/flow-new.md",
  "prerequisites": {
    "files": ["path/to/required/file"],
    "registry_fields": ["fields.that.must.exist"],
    "notes": "Human-readable prerequisite notes"
  },
  "inputs": [
    {
      "path": ".mc-data/...",
      "description": "[mô tả]",
      "required": true|false,
      "condition": null | "LEGACY_MODE only"
    }
  ],
  "outputs": {
    "docs": [
      {
        "path": ".mc-data/docs/...",
        "template": "phase-N/doc-name.md",
        "contract_key": "[key]",
        "required": true|false
      }
    ]
  },
  "cross_skill_contracts": {
    "produces_for": {
      "[consumer-skill]": ["paths..."]
    },
    "consumes_from": {
      "[producer-skill]": ["paths..."]
    }
  }
}
```

**Sự khác biệt vs CKE**: CKE không có `_contract.json`. MCV3 dùng contract để drive hook validation (`validate-contract-sync.sh`) và sync status tracking.

---

## Layer 3: procedures/ — Execution Flows

**Mục đích**: Step-by-step instructions cho agent execution. Tách khỏi SKILL.md để giảm token load.

### Cấu trúc chuẩn của `flow-new.md`:
```markdown
# [Skill Name] — Execution Flow

## Stage 1: [Name]
[Instructions...]

### POST-GATE Stage 1:
- [ ] Check 1
- [ ] Check 2

## Stage 2: [Name]
...
```

**Khi nào dùng procedures/**: Khi SKILL.md body vượt ~200 lines, tách execution logic ra procedures.
Hiện tại tất cả workflow skills đều dùng `procedures/flow-new.md`.

---

## Layer 4: templates/ — Output Templates

**Mục đích**: Predefined markdown templates cho các output docs được khai báo trong `_contract.json`.

### Naming convention:
```
templates/[phase-name]/[doc-key].md
```

Templates được referenced trong `_contract.json` qua `outputs.docs[].template`.
Agent điền nội dung vào template thay vì tạo free-form output.

**Lợi ích**: Đảm bảo output structure nhất quán, validate-contract-sync.sh có thể verify template compliance.

---

## Layer 5: evals/ — Evaluation Criteria (optional)

**Mục đích**: Test cases hoặc evaluation criteria cho skill output quality.
Không phải tất cả skills đều có layer này.

---

## So sánh với CKE 3-Level Model

| Level | CKE | MCV3 |
|-------|-----|------|
| L1 | SKILL.md (frontmatter + trigger) | SKILL.md (frontmatter + full execution) |
| L2 | Body prose trong SKILL.md | procedures/ (tách biệt) |
| L3 | Referenced external docs | templates/ (embedded trong skill dir) |
| MCV3-only | *(không có)* | `_contract.json` — machine contract |
| MCV3-only | *(không có)* | `evals/` — evaluation criteria |

**MCV3 additions**:
- `_contract.json` cho phép **hook-driven validation** tự động
- `templates/` đảm bảo **output determinism** — cùng skill, cùng structure
- `procedures/` cho phép **modular flow updates** mà không touch SKILL.md

---

## Lifecycle của một Skill invocation

```
User types: /wf-brainstorm
  ↓
Claude loads SKILL.md frontmatter
  ↓
Claude reads _contract.json → validate prerequisites exist
  ↓
Claude loads procedures/flow-new.md
  ↓
[Stage 1..N execution]
  ↓
Per each Write/Edit:
  → validate-requirement-sync.sh (PreToolUse)
  → update-sync-status.sh (PostToolUse)
  → validate-contract-sync.sh (PostToolUse)
  → validate-naming-convention.sh (PostToolUse)
  ↓
Session end:
  → stop-session-verify.sh (Stop hook)
```

---

## Naming Conventions

- Thư mục skill: `wf-[verb]-[noun]` (kebab-case)
- Workflow skills: prefix `wf-`
- Audit skills: prefix `audit-`
- Phases: `phase0-brainstorm` → `phase6-deployment`
- Cross-phase skills: `cross-phase` (preflight, fix-bugs, verify-sync)

---

*Document: 2026-04-12 | Reflects MCV3 v3.5.0 structure*
