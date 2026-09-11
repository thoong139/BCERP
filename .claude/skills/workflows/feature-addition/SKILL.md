---
name: feature-addition
version: 4.0.0
last_updated: 2026-04-19
description: |
  Orchestrator workflow cho việc thêm tính năng vào dự án đã có đầy đủ architecture.
  Chuỗi: wf-add-scope (conditional) → wf-define-features → wf-design (conditional) →
  wf-design-ux (conditional) → wf-plan-modules → wf-implement-feature →
  wf-preflight → wf-verify-sync.

  TRIGGER khi:
  - Dự án đã qua Phase 3, chỉ cần thêm features mới
  - Keywords: "thêm tính năng", "add feature", "feature mới", "bổ sung chức năng"
  - Gọi lệnh: /feature-addition [feature-name] [--resume] [--from-phase N]

  LUÔN trigger khi user muốn thêm tính năng vào dự án đã có architecture sẵn.

  KHÔNG trigger khi:
  - Dự án mới → dùng /new-project
  - Codebase chưa onboard → dùng /existing-project
  - Chưa có Phase 3 architecture → dùng /new-project hoặc /existing-project trước

argument-hint: "[feature-name] [--resume] [--from-phase N]"
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite
---
# /feature-addition: $ARGUMENTS

## Overview

| Mục                    | Nội dung                                                                                        |
| ----------------------- | ------------------------------------------------------------------------------------------------ |
| **Mục đích**   | Thêm tính năng mới vào dự án đã có kiến trúc sẵn — không cần làm lại từ đầu |
| **Prerequisites** | Phase 3 (Architecture) đã hoàn thành,`req-registry.json` tồn tại và hợp lệ            |
| **Duration**      | Multi-session                                                                                    |
| **Phases**        | 9 bước (0 → 1* → 2 → 3* → 4* → 5a → 5b → 6 → 7)                                        |
| **Input**         | `.mc-data/docs/_meta/req-registry.json`, `.mc-data/docs/phase3-architecture/`                |
| **Output**        | Feature docs, updated architecture, code, preflight report, verify report                        |

\* = conditional (chạy khi điều kiện đáp ứng)

### Workflow Position

```
/new-project ──────────────────────────────────┐
/existing-project ─────────────────────────────┤
                                               ▼
Phase 3 done ──→ /feature-addition ──→ /wf-verify-sync ──→ /status
                        |
                   YOU ARE HERE
```

---

## Arguments

| Argument         | Description                                                                                      | Default |
| ---------------- | ------------------------------------------------------------------------------------------------ | ------- |
| `feature-name` | Tên feature cần thêm (optional — có thể define trong Phase 2)                              | —      |
| `--resume`     | Resume từ checkpoint đã lưu                                                                  | —      |
| `--from-phase` | Nhảy đến phase cụ thể:`1`, `2`, `3`, `4`, `5a`, `5b`, `preflight`, `verify` | —      |

---

## Protocols

> **Shared protocols (repo-wide):** `.claude/skills/protocols/`
>
> **Skill-internal shared:** `procedures/_shared.md` — State Variables Glossary, Status File Schema,
> LEGACY_MODE Detection, Resume Protocol, Error Handling Reference, Sub-Skill Invocation Pattern.

### Execution Strategy

| Condition       | Mode                                                                |
| --------------- | ------------------------------------------------------------------- |
| Tất cả phases | **SEQUENTIAL** — mỗi phase phụ thuộc output phase trước |

Skill này là orchestrator tuần tự — không song song vì mỗi bước phụ thuộc kết quả bước trước.
Sub-skills có thể tự song song hóa nội bộ theo SKILL của chúng.

---

## Phase 0: Auto-Detection & Routing (BẮT BUỘC — entry point)

> Phase này **LUÔN chạy đầu tiên** để parse arguments, validate prerequisites, tạo status file.

```
STEP 1: Kiểm tra prerequisites (xem phase0-init.md cho chi tiết)
  (a) test -d .mc-data/docs/phase3-architecture/           → else E001
  (b) jq '.systems | length > 0' req-registry.json         → else E002

STEP 2: Read procedures/phase0-init.md → execute Phase 0 → return
```

**Đặc biệt — `--resume` handler:**

```
IF $ARGUMENTS chứa "--resume":
  IF test -f .mc-data/work/feature-addition/feature-addition-status.json:
    → READ status file
    → Xác định current_phase + phases_completed[] + phases_skipped[]
    → Jump tới phase trong current_phase (xem Phase Routing Map)
  ELSE:
    → STOP: "Không tìm thấy checkpoint. Chạy /feature-addition từ đầu."
```

**`--from-phase N` handler:**

```
IF $ARGUMENTS chứa "--from-phase N":
  → Validate N ∈ {1, 2, 3, 4, 5a, 5b, preflight, verify} (xem _shared.md §--from-phase Mapping)
  → Nếu invalid → E010
  → Jump tới phase tương ứng (Phase 0 init vẫn chạy để đảm bảo status file có)
```

---

## Phase Routing Map (lazy-loaded)

> SKILL.md routing block KHÔNG chứa execution steps. Toàn bộ logic chi tiết được lazy-load qua các phase files riêng.
> Read MỖI phase file CHỈ KHI tới phase tương ứng để giảm context load.

| Phase        | Procedure file                      | Điều kiện chạy                                                | Mục đích                                                           |
| ------------ | ----------------------------------- | ----------------------------------------------------------------- | --------------------------------------------------------------------- |
| **0**  | `procedures/phase0-init.md`       | Always (entry point)                                              | Context loading, status file, PRE-GATE, LEGACY_MODE detect            |
| **1**  | `procedures/phase1-scope.md`      | Conditional — module mới cần thêm                             | `wf-add-scope` append module vào registry                          |
| **2**  | `procedures/phase2-features.md`   | Always (main value step)                                          | `wf-define-features` thêm features mới                            |
| **3**  | `procedures/phase3-design.md`     | Conditional — architecture có thay đổi                        | `wf-design` cập nhật architecture + luôn read `interface_type` |
| **4**  | `procedures/phase4-ux.md`         | Conditional —`interface_type != "api-only"` AND feature có UI | `wf-design-ux` thiết kế UX                                        |
| **5a** | `procedures/phase5a-plan.md`      | Always                                                            | `wf-plan-modules` tạo roadmap + task files                         |
| **5b** | `procedures/phase5b-implement.md` | Always (loop)                                                     | Loop `wf-implement-feature` per feature                             |
| **6**  | `procedures/phase6-preflight.md`  | Always (có thể skip nếu không có feature done)               | `wf-preflight` health check + routing PASS/WARN/FAIL                |
| **7**  | `procedures/phase7-verify.md`     | Always (trừ khi Preflight FAIL)                                  | `wf-verify-sync` + final report                                     |

### Routing Flows

**Happy path (tất cả conditional phases chạy):**

```
Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5a → Phase 5b → Phase 6 → Phase 7 → DONE
```

**Module đã tồn tại + api-only:**

```
Phase 0 → Phase 1 (skip) → Phase 2 → Phase 3 → Phase 4 (skip api-only) → Phase 5a → Phase 5b → Phase 6 → Phase 7 → DONE
```

**Feature nhỏ, không đổi architecture, có UI:**

```
Phase 0 → Phase 1 (skip) → Phase 2 → Phase 3 (skip) → Phase 4 → Phase 5a → Phase 5b → Phase 6 → Phase 7 → DONE
```

**Preflight FAIL → dừng sớm:**

```
Phase 0 → ... → Phase 5b → Phase 6 (FAIL) → STOP → gợi ý /wf-fix-bugs
```

> **Mỗi phase file là self-contained** — chứa PRE-GATE, Steps, POST-GATE, Errors riêng.
> Phase file tham chiếu `procedures/_shared.md` cho cross-cutting concerns.

---

## Output Files

| # | File                 | Path                                                            | Phase | Required          |
| - | -------------------- | --------------------------------------------------------------- | ----- | ----------------- |
| 1 | Status tracking      | `.mc-data/work/feature-addition/feature-addition-status.json` | 0     | Always            |
| 2 | Feature specs        | `.mc-data/docs/phase2-features/[sys]/[mod]/[feat].md`         | 2     | Always            |
| 3 | Updated architecture | `.mc-data/docs/phase3-architecture/`                          | 3     | Conditional       |
| 4 | UX design            | `.mc-data/docs/phase4-ux/`                                    | 4     | Conditional       |
| 5 | Implementation plan  | `.mc-data/docs/phase5-implementation/`                        | 5a    | Always            |
| 6 | Preflight report     | `.mc-data/work/wf-preflight/preflight-report.md`              | 6     | Always            |
| 7 | Verify report        | `.mc-data/docs/_meta/verify-sync.md`                          | 7     | Khi Phase 7 chạy |

---

## Error Handling

Xem `procedures/_shared.md §Error Handling Reference` cho danh sách đầy đủ E001–E015.

Tóm tắt:

- **E001** — Thiếu `phase3-architecture` → STOP, chạy `/new-project` hoặc `/existing-project` trước
- **E002** — Registry không hợp lệ → STOP, chạy `/wf-analyze-requirements`
- **E003** — POST-GATE fail sau 3 retries → STOP + hỏi user
- **E004** — Sub-skill SKILL.md thiếu → STOP (không auto-fix)
- **E005** — `jq` không khả dụng → fallback python
- **E006** — Không có feature cần implement → skip Phase 5b
- **E007** — User dừng giữa vòng lặp 5b → checkpoint + resume
- **E008** — Feature individual POST-GATE fail → skip/retry
- **E009** — Verify fail → WARNING, user confirm tiếp tục
- **E010** — `--from-phase` invalid → hiển thị mapping, chọn lại
- **E011** — Context overflow → force checkpoint
- **E012** — Status file corrupt → rebuild fallback
- **E013** — Module DEPRECATED (LEGACY_MODE) → STOP
- **E014** — `wf-add-scope` fail → retry/skip/manual
- **E015** — Preflight FAIL → gợi ý `/wf-fix-bugs`

---

## Context & Checkpoint

| Context Usage | Hành động                        |
| ------------- | ----------------------------------- |
| < 65%         | Tiếp tục bình thường           |
| 65–80%       | Chuẩn bị checkpoint               |
| 80–90%       | Lưu checkpoint ngay                |
| > 90%         | FORCE STOP — checkpoint bắt buộc |

Checkpoint schema: `procedures/_shared.md §Status File Schema + §Context & Checkpoint`.

---

## Related Skills

| Skill                 | Quan hệ                                               |
| --------------------- | ------------------------------------------------------ |
| `/new-project`      | Workflow dự án mới hoàn toàn                      |
| `/existing-project` | Workflow onboard + phát triển                        |
| `/wf-add-scope`     | Safe-append modules + features vào registry (Phase 1) |
| `/wf-fix-bugs`      | Fix bugs — chạy bất kỳ lúc nào sau khi có code  |
| `/wf-preflight`     | Health check — Phase 6                                |
| `/status`           | Xem tiến độ bất kỳ lúc nào                      |
| `/wf-verify-sync`   | Traceability — Phase 7                                |
