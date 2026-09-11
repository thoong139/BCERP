---
name: wf-diagram
version: 2.0.0
last_updated: 2026-05-03
description: |
  Tự động sinh bộ sơ đồ thiết kế (UML + ERD) cho một module trong hệ thống, dựa trên source code có sẵn (đã chứa spec inline và DB schema). Output: file .md chứa Mermaid + file .dbml riêng cho ERD. Khi chạy --module=X thì system diagrams ghi vào modules/{X}/_system/; --scope=system-only ghi top-level _system/.

  TRIGGER khi:
  - User muốn sinh diagram (UML class, ERD, sequence, activity, state, use case, context, component) cho một module hoặc cả hệ thống từ source code có sẵn
  - User cần tài liệu thiết kế trực quan để onboard người mới hoặc review architecture
  - Gọi trực tiếp: /wf-diagram --module=<name> hoặc /wf-diagram --scope=system-only
  - "vẽ sơ đồ", "sinh diagram", "tạo UML", "tạo ERD" + có module/scope cụ thể

  KHÔNG trigger khi:
  - Chưa có source code (cần /wf-design để thiết kế từ đầu)
  - Chỉ cần xem 1 sơ đồ đơn lẻ ad-hoc (đọc file diagram có sẵn)
  - Muốn vẽ wireframe/UI mockup → dùng /wf-design-ux
argument-hint: "--module=<name> [--source-path=<path>] [--output-path=<path>] [--scope=full|module-only|system-only] [--resume] [--status] [--session=<id>]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, AskUserQuestion
---

# /wf-diagram: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Sinh bộ sơ đồ UML + ERD (Mermaid + DBML) cho module/hệ thống từ source code |
| **Prerequisites** | Source code có thật trong `--source-path` (mặc định CWD) |
| **Workflow position** | Standalone — KHÔNG thuộc main DEVKIT pipeline **[YOU ARE HERE]** |
| **Phases** | 8 phases: Setup → Pre-check → Source Analysis → Plan → System → Module → Detail → Validation |
| **Duration** | 5-15 phút tùy module size và scope |
| **Output** | Module-scoped: `modules/{module}/_system/*.md|.dbml` + `modules/{module}/class.md|erd.dbml|usecases/*.md` + N detail files. System-only: top-level `_system/*.md|.dbml`. Metadata trong `.mc-data/work/wf-diagram/sessions/{id}/` |

---

## Arguments

| Argument | Mô tả | Required | Default |
|----------|-------|----------|---------|
| `--module=<name>` | Module cần sinh diagram | **BẮT BUỘC** trừ khi `--scope=system-only` | — |
| `--source-path=<path>` | Root source code | Optional | `.` (CWD) |
| `--output-path=<path>` | Đường dẫn xuất diagrams | Optional | `.mc-data/docs/diagrams` |
| `--scope=<value>` | `full` \| `module-only` \| `system-only` | Optional | `full` |
| `--resume` | Tiếp tục session gần nhất | Optional | — |
| `--status` | Hiển thị sessions → STOP | Optional | — |
| `--session=<id>` | Resume session cụ thể (chỉ dùng cùng `--resume`) | Optional | _(auto-pick)_ |

---

## Phase 0: Entry Point (Summary)

> Chi tiết xem `procedures/phase0-setup.md`. Phần này là routing entry — compliance anchor.

**PRE-GATE:** `--module` được cung cấp HOẶC `--scope=system-only`. `--source-path` tồn tại.

| Step | Action | Tool |
|------|--------|------|
| 0.0 | Resume/Status dispatch (nếu `--resume`/`--status`) | Read |
| 0.1-0.3 | Parse + validate args → E001/E002 nếu invalid | Bash |
| 0.4-0.5 | Generate SESSION_ID + tạo dirs | Bash |
| 0.6-0.7 | Init diagram-status.json + checkpoint.json từ templates | Read+Write |
| 0.8 | Append trace START event (Protocol 15) | Read+Write |
| → | Load phase chi tiết: `procedures/phase0-setup.md` | Read |

**POST-GATE:** Session dir tồn tại, status + checkpoint non-empty, trace START appended.

**Next step:** → Phase 1 (`procedures/phase1-precheck.md`)

---

## Phase Routing Map

| Phase | Lazy-load từ | Điều kiện |
|-------|-------------|-----------|
| **Phase 0: Setup** | `procedures/phase0-setup.md` | Luôn chạy (entry point) |
| **Phase 1: Pre-check** | `procedures/phase1-precheck.md` | Luôn chạy sau Phase 0 |
| **Phase 2: Source Analysis** | `procedures/phase2-source-analysis.md` | Luôn chạy sau Phase 1 |
| **Phase 3: Plan** | `procedures/phase3-plan.md` | Luôn chạy sau Phase 2 |
| **Phase 4: System Diagrams** | `procedures/phase4-system.md` | `scope ∈ {full, system-only}` AND `plan.system_files` có entries |
| **Phase 5: Module Diagrams** | `procedures/phase5-module.md` | `scope ∈ {full, module-only}` AND `plan.module_files` có entries |
| **Phase 6: Detail Diagrams** | `procedures/phase6-detail.md` | `plan.states OR activities OR sequences` có entries |
| **Phase 7: Validation** | `procedures/phase7-validation.md` | Luôn chạy cuối |
| **Resume/Status** | `procedures/resume-routing.md` | `--resume` hoặc `--status` dispatch (Phase 0.0) |
| **Session Init** | `procedures/session-init.md` | Session init steps (0.4-0.8) — reusable by reset/restart |
| **Shared** | `procedures/_shared.md` | State vars, slugify, error matrix — lazy-load khi cần |

### Resume / Status

```
/wf-diagram --status                                # Hiển thị 5 sessions → STOP
/wf-diagram --resume                                # Tiếp tục session gần nhất
/wf-diagram --resume --session=2026-04-30-order    # Tiếp tục session cụ thể
```

---

## Filter Rules (BẮT BUỘC — Phase 3 apply)

| Loại | Điều kiện bắt buộc |
|------|-------------------|
| Activity | Process có **≥3 bước** HOẶC có **nhánh điều kiện** |
| State | Entity có **≥3 trạng thái** |
| Sequence | Endpoint gọi **≥3 service/component** HOẶC có **error handling phức tạp** HOẶC **async** |
| Use case grouping | 1 group = 1 file. Group theo: controller class → URL prefix → sub-folder. Luôn ≥1 file |

KHÔNG sinh diagram không thoả điều kiện. Ghi lý do vào `plan.skipped[]` và `phase-summary.md`.

---

## Protocols & Fix Rules

> **Protocol:** Xem `.claude/skills/protocols/` — Protocol 10 (POST-GATE Schema), Protocol 14 (Phase Summary),
> Protocol 15 (Execution Trace), Protocol 16 (CDG-02 overwrite), Protocol 18 (Session Isolation),
> Protocol 19 (Template Usage Rule / CORE-031).

### Fix Rules (Auto-Correction)

| Error Type | Auto-Fix Strategy | Escalate If |
|------------|-------------------|-------------|
| Mermaid syntax error | Re-render từ template, populate lại data | 3 retries vẫn fail → E006 |
| DBML parse fail | Re-render → ghi `// TODO` block | 1 retry fail → E007 |
| Placeholder chưa thay `[XXX]` | Re-populate từ analysis.json | 3 retries fail → ESCALATE |
| File write fail | Retry 3 lần | 3 retries fail → E008, ESCALATE |
| T1-T4 POST-GATE fail | Auto-Correction Loop (Phase 7.5, max 3 retries) | 3 retries fail → status=failed |

---

## Mermaid 8.8.0 Safety Rules (BẮT BUỘC — áp dụng khi POPULATE tất cả templates)

| ❌ KHÔNG dùng | ✅ Dùng thay thế |
|--------------|------------------|
| Single quote `'label'` trong label | Bỏ quote hoặc backtick `` `label` `` |
| Em-dash `—` (U+2014) | `--` (2 hyphen) hoặc `-` |
| Emoji + parens + space chưa quote: `[(🗄️ PG)]` | `[("PG")]` hoặc bỏ emoji |
| `<br/>` trong shape không quote | `<br>` hoặc quote: `["line1<br/>line2"]` |
| Colon `:` trong node label không quote | `A["key: value"]` |
| `&` chain: `A & B & C --> D` | 3 dòng riêng |
| `()` trong label không quote | `A["text (note)"]` |
| Reserved keywords làm node ID: `END`, `class`, `style` | Đổi: `ENDPT`, `END_NODE` |
| subgraph với multi-word chưa quote | `subgraph ID["Display Name"]` |

**Quy tắc vàng:** MỌI label có chứa space, special char, hoặc HTML PHẢI wrap trong `["..."]`.

---

## DBML Conventions (BẮT BUỘC — áp dụng khi populate DBML templates)

- 1 bảng = 1 block `Table`
- Group module: `TableGroup {module_name} { table1 table2 }`
- Khóa ngoại: dùng cú pháp `Ref:` cuối file (KHÔNG inline)
- Comment bảng: dùng `Note:` ngay trong block
- Bảng "external" (ngoài module): comment `// External: from <module>` + chỉ show PK

---

## Output Files

### Real diagrams (user-facing — trong `output_path/`)

> **Path resolution (v1.2.0):**
> - `$system_dir = $output_path/modules/$module/_system` khi `$scope ∈ {full, module-only}`
> - `$system_dir = $output_path/_system` khi `$scope = system-only`

| # | File | Bắt buộc |
|---|------|----------|
| 1 | `$system_dir/context.md` | scope ∈ {full, system-only} |
| 2 | `$system_dir/component.md` | scope ∈ {full, system-only} |
| 3 | `$system_dir/erd-context-map.md` | scope ∈ {full, system-only} |
| 4 | `$system_dir/actors.md` | scope ∈ {full, system-only} |
| 5 | `$system_dir/database.dbml` | scope ∈ {full, system-only} |
| 6 | `modules/{module}/usecases/{group}.md` | scope ∈ {full, module-only} — N files |
| 7 | `modules/{module}/class.md` | scope ∈ {full, module-only} |
| 8 | `modules/{module}/erd.dbml` | scope ∈ {full, module-only} |
| 9 | `modules/{module}/states/{entity}.md` | Conditional (≥3 states) |
| 10 | `modules/{module}/activities/{process}.md` | Conditional (≥3 steps hoặc branch) |
| 11 | `modules/{module}/sequences/{scenario}.md` | Conditional (≥3 components/complex) |

### Session metadata (`.mc-data/work/wf-diagram/sessions/{id}/`)

| File | Template |
|------|----------|
| `diagram-status.json` | `templates/diagram-status.json` |
| `checkpoint.json` | `templates/checkpoint.json` |
| `phase-summary.md` | `templates/phase-summary.md` |
| `analysis.json` | inline schema (analysis-v1, xem `procedures/_shared.md`) |

---

## Error Handling

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E001 | `--module` không cung cấp + `--scope != system-only` | Message yêu cầu, STOP |
| E002 | `--source-path` không tồn tại | ERROR + suggest ls, STOP |
| E003 | Module diagrams đã tồn tại | CDG-02 (Protocol 16) |
| E004 | Module không tìm thấy trong source | WARN + scan toàn project, ASK |
| E005 | DB schema không tìm thấy | WARN + skip ERD |
| E006 | Mermaid syntax invalid sau 3 retries | ESCALATE |
| E007 | File missing/empty sau generate | Retry x3 |
| E008 | File write fail | Retry x3 → ESCALATE |
| E009 | User reject CDG-02 | Skip module, continue |

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `/wf-design` | Sinh kiến trúc TRƯỚC khi có code (skill này sinh từ code đã có) |
| `/wf-scan-target` | Scan source để hiểu cấu trúc — có thể chạy trước `/wf-diagram` |
| `/wf-design-ux` | Sinh UI mockup (khác mục đích) |

---

## Output Report (hiển thị sau Phase 7)

```
| Module          | {module}  |
| Scope           | {scope}   |
| Session         | {id}      |
| System diagrams | N files   |
| Module diagrams | N files   |
| Detail diagrams | states=X, activities=Y, sequences=Z |
| Skipped         | N — xem phase-summary.md |
| Verification    | T1-T4 PASS |

Diagrams: {output_path}/
Metadata: .mc-data/work/wf-diagram/sessions/{id}/
```

**Next step:** Review diagrams tại `{output_path}/`, render Mermaid tại https://mermaid.live hoặc DBML tại https://dbdiagram.io.
