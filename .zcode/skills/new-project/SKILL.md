---
name: new-project
version: 4.1.0
last_updated: 2026-09-12
description: |
  Orchestrator chính cho dự án mới từ đầu — tự động chạy tuần tự 10 bước (Phase 0 → Phase 6): đọc và thực thi từng sub-skill trong .claude/skills/workflow/ theo đúng thứ tự, chờ POST-GATE sau mỗi bước, xử lý skip conditions và vòng lặp implement-feature.

  TRIGGER khi:
  - User muốn phát triển phần mềm mới từ ý tưởng đến deployment — LUÔN trigger dù không dùng từ "new project". Đây là orchestrator chính của DEVKIT.
  - Keywords: "new project", "dự án mới từ đầu", "bắt đầu xây dựng", "tạo dự án mới"
  - Gọi lệnh: /new-project [tên-dự-án] [--resume] [--from-phase N] [--status]

  KHÔNG trigger khi:
  - Dự án đã có codebase → dùng /existing-project
  - Chỉ thêm feature → dùng /feature-addition
  - Chỉ chạy 1 phase cụ thể → gọi /wf-[phase-name] trực tiếp
argument-hint: "[tên-dự-án] [--resume] [--from-phase N] [--status]"
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite
---

# /new-project: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Orchestrate toàn bộ DEVKIT workflow phát triển dự án mới — từ brainstorm đến deployment docs |
| **Prerequisites** | Không — đây là entry point |
| **Duration** | Multi-session (10 bước, có thể kéo dài nhiều session) |
| **Steps** | 10 bước orchestrator (Bước 0 → Bước 9), tương ứng DEVKIT Phase 0 → Phase 6 |
| **Input** | Tên dự án từ user (hoặc lấy từ Phase 0 brainstorm) |
| **Output** | `.mc-data/docs/` hoàn chỉnh từ Phase 0 đến Phase 6 |
| **Kiến trúc v4.0** | Tách monolithic SKILL.md thành orchestrator + 11 procedure files (phase0-init + phase1-10) + _shared.md (lazy loading per-phase, giảm context load ~65%). Backup flow cũ: `procedures/flow-legacy.md.bak` |

### Workflow Position

```
[Entry Point] → /new-project → /status (xem tiến độ bất kỳ lúc nào)
                     |
                YOU ARE HERE
                     |
          Orchestrate 10 sub-skills:
          wf-brainstorm → wf-analyze-requirements →
          wf-define-features → wf-design → wf-design-ux →
          wf-plan-modules → wf-implement-feature → wf-preflight →
          wf-verify-sync → wf-prepare-deployment
```

---

## Arguments

| Argument | Mô tả | Default |
|----------|-------|---------|
| `tên-dự-án` | Tên project (truyền cho wf-brainstorm) | Lấy từ Phase 0 |
| `--resume` | Resume từ checkpoint (đọc status.json hoặc file-based detection) | - |
| `--from-phase N` | Bắt đầu từ phase N (xem `_shared.md §--from-phase Mapping`) | `0` |
| `--status` | Hiển thị tiến độ hiện tại rồi dừng | - |

**Giá trị hợp lệ cho `--from-phase`:** `0 | 1 | 2 | 3 | 4 | 5a | 5b | 5c | verify | 6`. Chi tiết mapping và prerequisite validation: `procedures/_shared.md §--from-phase Mapping`.

---

## Protocols

> **Shared protocols (repo-wide):** `.claude/skills/protocols/`
>
> **Skill-internal shared:** `procedures/_shared.md` — Step Map, State Variables Glossary,
> Status File Schema, Resume Protocol, `--from-phase` Mapping, Error Handling Reference,
> Context & Checkpoint, Sub-Skill Invocation Pattern.

### Execution Strategy

| Condition | Mode |
|-----------|------|
| Tất cả 10 bước | **SEQUENTIAL** — mỗi bước phụ thuộc output bước trước |
| Trong mỗi sub-skill | Sub-skill tự quyết định PARALLEL/SEQUENTIAL |

Sub-skills có thể song song hóa nội bộ theo SKILL của chúng. Orchestrator tuần tự 100%.

---

## Phase 0: Orchestrator Init & Routing (BẮT BUỘC — entry point)

> Phase này **LUÔN chạy đầu tiên** để parse arguments, validate sub-skill paths,
> tạo status file, và route tới flag handler phù hợp.

```
STEP 1: Validate sub-skill paths tồn tại (xem _shared.md §Sub-Skill Paths)
  IF any path missing → E004 → STOP

STEP 2: Parse $ARGUMENTS → xác định flags (--resume, --from-phase, --status)

STEP 3: Read procedures/phase0-init.md → execute Phase 0 → return với routing decision
```

**Flag routing shortcuts:**

```
IF $ARGUMENTS chứa "--status":
  → Execute Status Check Protocol (xem _shared.md §Status Check Protocol)
  → DỪNG

IF $ARGUMENTS chứa "--resume":
  → Execute Resume Protocol (xem _shared.md §Resume Protocol)
  → Jump tới phase file tương ứng với current_step

IF $ARGUMENTS chứa "--from-phase N":
  → Validate N → else E007
  → Execute Prerequisite Validation (xem _shared.md §Prerequisite Validation)
  → Jump tới phase file tương ứng

IF không có flag:
  → phase0-init.md handle hỏi user → jump tới phase1-brainstorm.md
```

### Phase 0 Step Summary

| Step | Action | Verify |
|------|--------|--------|
| 1 | Validate sub-skill paths tồn tại (10 paths, `_shared.md §Sub-Skill Paths`) | Mọi path tồn tại; thiếu → E004 STOP |
| 2 | Parse `$ARGUMENTS` → flags `--resume`, `--from-phase N`, `--status` | Flags parse đúng; conflict `--resume`+`--from-phase` → E008 |
| 3 | Route theo flag: `--status` → Status Check Protocol (STOP); `--resume` → Resume Protocol jump; `--from-phase N` → validate (E007) + Prerequisite Validation jump | Jump đúng phase file |
| 4 | Không flag → lazy-load `procedures/phase0-init.md`, execute Phase 0 init | Routing decision tới `phase1-brainstorm.md` |

---

## Phase Routing Map (lazy-loaded)

> SKILL.md routing block KHÔNG chứa execution steps. Toàn bộ logic chi tiết được lazy-load qua các phase files riêng.
> Read MỖI phase file CHỈ KHI tới bước tương ứng để giảm context load.

| Bước | Procedure file | Sub-skill | DEVKIT phase | Conditional |
|------|---------------|-----------|--------------|-------------|
| — | `procedures/phase0-init.md` | — | — | Always (entry point) |
| **0** | `procedures/phase1-brainstorm.md` | `wf-brainstorm` | Phase 0 | Always |
| **1** | `procedures/phase2-analyze.md` | `wf-analyze-requirements` | Phase 1 | Always |
| **2** | `procedures/phase3-features.md` | `wf-define-features` | Phase 2 | Always |
| **3** | `procedures/phase4-design.md` | `wf-design` | Phase 3 | Always |
| **4** | `procedures/phase5-ux.md` | `wf-design-ux` | Phase 4 | Skip nếu `interface_type = "api-only"` |
| **5** | `procedures/phase6-plan.md` | `wf-plan-modules` | Phase 5a | Always |
| **6** | `procedures/phase7-implement.md` | `wf-implement-feature` | Phase 5b | Loop per feature |
| **7** | `procedures/phase8-preflight.md` | `wf-preflight` | Phase 5c | Always (routing PASS/WARN/FAIL) |
| **8** | `procedures/phase9-verify.md` | `wf-verify-sync` | Verify | Always |
| **9** | `procedures/phase10-deploy.md` | `wf-prepare-deployment` | Phase 6 | Always |

### Routing Flows

**Happy path (tất cả bước chạy, project web+mobile):**
```
phase0-init → phase1-brainstorm → phase2-analyze → phase3-features →
phase4-design → phase5-ux → phase6-plan → phase7-implement →
phase8-preflight → phase9-verify → phase10-deploy → DONE
```

**API-only (skip Bước 4):**
```
phase0-init → ... → phase4-design → phase5-ux (SKIP) → phase6-plan → ... → DONE
```

**Preflight FAIL → dừng sớm:**
```
phase0-init → ... → phase7-implement → phase8-preflight (FAIL) → STOP → gợi ý /wf-fix-bugs
                                                                 → resume sau fix
```

**Resume (giả sử đang dở Bước 6 — Implement):**
```
phase0-init (detect --resume) → jump thẳng phase7-implement (tiếp tục loop) → ...
```

> **Mỗi phase file là self-contained** — chứa PRE-GATE, Steps, POST-GATE, Checkpoint Update, Transition, Errors riêng.
> Phase file tham chiếu `procedures/_shared.md` cho cross-cutting concerns (state vars, schemas, errors, patterns).

---

## Output Files

| # | File | Path | Bước | Required |
|---|------|------|------|----------|
| 1 | Status tracking | `.mc-data/work/new-project/status.json` | phase0-init | Always |
| 2 | Brainstorm | `.mc-data/docs/phase0-brainstorm/` | 0 | Always |
| 3 | Requirements | `.mc-data/docs/phase1-business/` | 1 | Always |
| 4 | Features | `.mc-data/docs/phase2-features/` | 2 | Always |
| 5 | Architecture | `.mc-data/docs/phase3-architecture/` | 3 | Always |
| 6 | UX/UI | `.mc-data/docs/phase4-ux/` | 4 | Conditional (skip api-only) |
| 7 | Implementation | `.mc-data/docs/phase5-implementation/` | 5, 6 | Always |
| 8 | Preflight report | `.mc-data/work/wf-preflight/preflight-report.md` | 7 | Always |
| 9 | Verify report | `.mc-data/docs/_meta/verify-sync.md` | 8 | Always |
| 10 | Deployment | `.mc-data/docs/phase6-deployment/` | 9 | Always |
| 11 | Registry | `.mc-data/docs/_meta/req-registry.json` | All | SSOT |

---

## Error Handling

Chi tiết đầy đủ (bảng E001–E015 + xử lý): `procedures/_shared.md §Error Handling Reference`.

Tóm tắt:

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E001 | POST-GATE fail sau 3 retries | STOP phase, hiển thị lỗi, hỏi user |
| E002 | User dừng giữa bước | Checkpoint + resume note (`--resume`) |
| E003 | registry.json không tồn tại | Kiểm tra Phase 0 output, chạy lại nếu cần |
| E004 | Sub-skill SKILL.md thiếu | STOP (không auto-fix), báo path cụ thể |
| E005 | Implement loop gián đoạn | Checkpoint per-feature, user resume |
| E006 | Context > 90% | Force checkpoint |
| E007 | `--from-phase` invalid | Hiển thị mapping, chọn lại |
| E008 | `--resume` + `--from-phase` conflict | Hỏi user chọn 1 |
| E009 | status.json corrupt | Xóa file, fallback file-based detection |
| E010 | `--from-phase` prerequisite missing | Đề xuất chạy phase trước |
| E011 | `--resume`/`--status` khi `.mc-data/` chưa có | STOP: "Chưa có dự án nào" |
| E012 | `jq` không có | Fallback python one-liner |
| E013 | Context overflow giữa sub-skills | FORCE STOP + checkpoint |
| E014 | Sub-skill timeout/partial | Retry 1 lần → escalate |
| E015 | Preflight FAIL | Gợi ý `/wf-fix-bugs` trước verify |

### Fix Rules

| Error Type | Auto-Fix | Escalate khi |
|------------|----------|--------------|
| Sub-skill timeout / partial output (E014) | Retry sub-skill 1 lần với cùng arguments | Fail lần 2 — escalate kèm stage name + last known state |
| POST-GATE fail (E001) | Sub-skill tự retry tối đa 3 lần (Protocol 2) trước khi báo orchestrator | Hết 3 retries — STOP phase, hỏi user |
| status.json corrupt (E009) | Xóa status file → file-based detection (quét `.mc-data/docs/` per-phase markers) | File-based detection không kết luận được bước hiện tại |
| `jq` không khả dụng (E012) | Fallback `python -c "import json; ..."` cho mọi lệnh đọc registry | Python cũng không có — STOP, yêu cầu cài đặt |
| Flag conflict (E007/E008/E010) | Không auto-fix — hiển thị mapping/prerequisite rồi hỏi user chọn | User chọn xong vẫn không hợp lệ |

---

## Context & Checkpoint

| Context Usage | Hành động |
|---------------|-----------|
| < 65% | Tiếp tục bình thường |
| 65–80% | Chuẩn bị checkpoint |
| 80–90% | Lưu checkpoint ngay |
| > 90% | FORCE STOP — checkpoint bắt buộc (E013) |

Checkpoint schema: `procedures/_shared.md §Status File Schema + §Context & Checkpoint`.

**Ghi checkpoint SAU MỖI BƯỚC hoàn thành** — không chờ đến cuối workflow.

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `/existing-project` | Workflow cho dự án có sẵn (alternative entry point) |
| `/feature-addition` | Workflow thêm feature (alternative — khi đã có architecture) |
| `/wf-fix-bugs` | Fix bugs — chạy bất kỳ lúc nào sau khi có code |
| `/wf-preflight` | Health check — Bước 7 (có thể chạy độc lập) |
| `/status` | Xem tiến độ bất kỳ lúc nào (complementary) |
| `wf-brainstorm` → `wf-prepare-deployment` | 10 sub-skills được orchestrate |

> **Next:** Sau khi hoàn thành → dùng `/status` để xem tổng quan, hoặc `/feature-addition` để thêm features mới.
