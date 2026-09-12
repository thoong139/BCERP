---
name: existing-project
version: 4.1.0
last_updated: 2026-09-12
description: |
  Orchestrator workflow cho dự án đã có codebase — scan rồi tiếp tục phát triển theo DEVKIT.
  Chuỗi: wf-legacy-scan → wf-brainstorm* → wf-analyze-requirements* → wf-define-features* → wf-design* → wf-annotate-code (conditional) → wf-design-ux* (conditional) → wf-plan-modules → wf-implement-feature → wf-preflight → wf-verify-sync → wf-prepare-deployment. (* = shared skills tự detect legacy mode theo CORE-021 và inject context.)

  TRIGGER khi:
  - Codebase đã tồn tại, muốn áp dụng DEVKIT để quản lý
  - Keywords: "existing project", "dự án có sẵn", "phân tích dự án hiện tại"
  - Gọi lệnh: /existing-project [--resume] [--from-phase N]
  - LUÔN trigger khi user có source code sẵn muốn integrate với DEVKIT workflow, kể cả không dùng đúng từ "existing-project"

  KHÔNG trigger khi:
  - Dự án hoàn toàn mới → dùng /new-project
  - Chỉ thêm feature → dùng /feature-addition
argument-hint: "[--resume] [--from-phase N]"
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite
---

# /existing-project: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Orchestrate workflow DEVKIT cho dự án đã có codebase — phân tích, tổ chức lại và tiếp tục phát triển |
| **Prerequisites** | Codebase tồn tại tại thư mục hiện tại hoặc path chỉ định |
| **Duration** | Multi-session |
| **Phases** | 13 bước (init → scan → 4×0b → annotate → ux → 5a → 5b → preflight → verify → deployment) |
| **Input** | Codebase directory |
| **Output** | `.mc-data/docs/` đầy đủ + code implemented |
| **Kiến trúc v4.0** | Tách monolithic SKILL.md thành 13 procedure files + 1 _shared.md (lazy loading per-phase, giảm context load ~75% khi execute từng phase). Backup flow cũ: `procedures/flow-legacy.md.bak` |

### Workflow Position

```
/new-project (dự án mới)
        ↓
/existing-project ← YOU ARE HERE → /feature-addition (chỉ thêm feature)
        ↓
   Onboard → cluster Phase 0-3 → Annotate → UX → Plan → Implement → Verify → Deployment
```

---

## Arguments

| Argument | Mô tả | Default |
|----------|-------|---------|
| `--resume` | Resume từ checkpoint — tự động phát hiện bước chưa hoàn thành | — |
| `--from-phase N` | Nhảy thẳng đến phase N (xem mapping trong `_shared.md §--from-phase Mapping`) | — |

**Mapping `--from-phase`:** xem `procedures/_shared.md §--from-phase Mapping`. Tóm tắt giá trị hợp lệ:
`scan | 0 | 1 | 2 | 3 | annotate | 4 | 5a | 5b | preflight | verify | 6`.

---

## Protocols

> **Shared protocols (repo-wide):** `.claude/skills/protocols/`
>
> **Skill-internal shared:** `procedures/_shared.md` — State Variables Glossary, Status File Schema,
> LEGACY_MODE Detection, Resume Protocol, `--from-phase` Mapping, Error Handling Reference,
> Sub-Skill Invocation Pattern.

### Execution Strategy

| Condition | Mode |
|-----------|------|
| Tất cả phases | **SEQUENTIAL** — mỗi phase phụ thuộc output phase trước |
| Trong mỗi phase — tùy sub-skill | **Tùy sub-skill** — wf-legacy-scan có parallel agents nội bộ |

Skill này là orchestrator tuần tự — không song song giữa các phase vì mỗi bước phụ thuộc kết quả bước trước.
Sub-skills có thể tự song song hóa nội bộ theo SKILL của chúng.

---

## Phase 0: Auto-Detection & Routing (BẮT BUỘC — entry point)

> Phase này **LUÔN chạy đầu tiên** để parse arguments, validate codebase, xử lý conflict
> `.mc-data/`, tạo status file.

```
STEP 1: Kiểm tra prerequisites (xem phase0-init.md cho chi tiết)
  (a) test -d .              → else E001
  (b) Codebase có file/folder source — heuristic warning nếu không có

STEP 2: Read procedures/phase0-init.md → execute Phase 0 → return
```

**Đặc biệt — `--resume` handler:**

```
IF $ARGUMENTS chứa "--resume":
  IF test -f .mc-data/work/existing-project/checkpoint.json:
    → READ status file
    → Xác định current_step + phases_completed[] + phases_skipped[]
    → Cross-validate với file system (xem _shared.md §Resume Protocol)
    → Jump tới phase trong current_step (xem Phase Routing Map)
  ELSE:
    → Fallback output-path inference (xem _shared.md §Status file fallback E012)
```

**`--from-phase N` handler:**

```
IF $ARGUMENTS chứa "--from-phase N":
  → Validate N ∈ {scan, 0, 1, 2, 3, annotate, 4, 5a, 5b, preflight, verify, 6} (_shared.md §--from-phase Mapping)
  → Nếu invalid → E010
  → Kiểm tra prerequisites của phase đích → nếu chưa đủ → E011
  → Jump tới phase tương ứng (Phase 0 init vẫn chạy để đảm bảo status file có)
```

### Phase 0 Step Summary

| Step | Action | Verify |
|------|--------|--------|
| 1 | Kiểm tra prerequisites: codebase directory + source files (heuristic) | Codebase tồn tại; thiếu → E001 STOP |
| 2 | Parse `$ARGUMENTS` → flags `--resume`, `--from-phase N` | Flags parse đúng giá trị mapping |
| 3 | `--resume` handler: đọc checkpoint.json, cross-validate filesystem (_shared.md §Resume Protocol) | current_step + phases_completed[] khớp disk; thiếu file → E012 fallback |
| 4 | `--from-phase N` handler: validate N (E010) + prerequisite phase đích (E011) | Jump đúng phase file sau Phase 0 init |
| 5 | Không flag → lazy-load `procedures/phase0-init.md` (conflict `.mc-data/` menu, status file) | Routing decision tới `phase-scan.md` |

---

## Phase Routing Map (lazy-loaded)

> SKILL.md routing block KHÔNG chứa execution steps. Toàn bộ logic chi tiết được lazy-load qua các phase files riêng.
> Read MỖI phase file CHỈ KHI tới phase tương ứng để giảm context load.

| # | Phase ID | Procedure file | Sub-skill | Điều kiện chạy | Mục đích |
|---|----------|---------------|-----------|----------------|----------|
| **0** | phase0 | `procedures/phase0-init.md` | (init) | Always (entry point) | PRE-GATE, args parsing, conflict menu, status file |
| **1** | scan | `procedures/phase-scan.md` | `wf-legacy-scan` | Always (skip nếu pipeline COMPLETE từ run trước) | Detect → classify → extract → synthesize codebase |
| **2** | brainstorm | `procedures/phase-brainstorm.md` | `wf-brainstorm` | Always | Phase 0 docs + legacy-decisions.json |
| **3** | analyze-req | `procedures/phase-analyze-req.md` | `wf-analyze-requirements` | Always | Phase 1 docs + registry seed |
| **4** | define-features | `procedures/phase-define-features.md` | `wf-define-features` | Always | Phase 2 specs + impl_status inheritance |
| **5** | design | `procedures/phase-design.md` | `wf-design` | Always | Phase 3 architecture + registry rebuild + gap analysis |
| **6** | annotate | `procedures/phase-annotate.md` | `wf-annotate-code` | Conditional — có annotation gaps + có code | Inject REQ-ID vào existing code |
| **7** | phase4 | `procedures/phase4-ux.md` | `wf-design-ux` | Conditional — `interface_type != "api-only"` AND UI thay đổi | UX/UI design |
| **8** | phase5a | `procedures/phase5a-plan.md` | `wf-plan-modules` | Always | Implementation roadmap + task files |
| **9** | phase5b | `procedures/phase5b-implement.md` | `wf-implement-feature` | Always (loop per feature) | TDD code implementation |
| **10** | preflight | `procedures/phase-preflight.md` | `wf-preflight` | Always | Health check toàn diện (PASS/WARN/FAIL routing) |
| **11** | verify | `procedures/phase-verify.md` | `wf-verify-sync` | Always (trừ khi Preflight FAIL) | Traceability sync check |
| **12** | deployment | `procedures/phase6-deployment.md` | `wf-prepare-deployment` | Always | Deployment docs + user guides |

### Routing Flows

**Happy path (tất cả conditional phases chạy):**
```
phase0 → scan → brainstorm → analyze-req → define-features → design →
annotate → phase4 → phase5a → phase5b → preflight (PASS) → verify → deployment → DONE
```

**Pipeline đã COMPLETE từ run trước + api-only + DOCS_ONLY:**
```
phase0 (legacy_pipeline_done=true) → scan (skip) → brainstorm (skip) →
analyze-req (skip) → define-features (skip) → design (skip) →
annotate (skip docs-only) → phase4 (skip api-only) → phase5a → phase5b →
preflight → verify → deployment → DONE
```

**Code-first (S2) project có UI:**
```
phase0 → scan → brainstorm → analyze-req → define-features → design →
annotate → phase4 → phase5a → phase5b → preflight → verify → deployment → DONE
```

**Preflight FAIL → dừng sớm:**
```
phase0 → ... → phase5b → preflight (FAIL) → STOP → gợi ý /wf-fix-bugs
```

> **Mỗi phase file là self-contained** — chứa PRE-GATE, Steps, POST-GATE, Status File Update, Errors riêng.
> Phase file tham chiếu `procedures/_shared.md` cho cross-cutting concerns.

---

## Output Files

| # | File | Path | Phase | Required |
|---|------|------|-------|----------|
| 1 | Status tracking | `.mc-data/work/existing-project/checkpoint.json` | phase0 | Always |
| 2 | Legacy scan output | `.mc-data/work/legacy-scan/` (project-context.md, ledger.json, ...) | scan | Always |
| 3 | Phase 0 docs | `.mc-data/docs/phase0-brainstorm/` | brainstorm | Always |
| 4 | Phase 1 docs | `.mc-data/docs/phase1-business/` | analyze-req | Always |
| 5 | Phase 2 docs | `.mc-data/docs/phase2-features/` | define-features | Always |
| 6 | Phase 3 docs + registry | `.mc-data/docs/phase3-architecture/` + `_meta/req-registry.json` | design | Always |
| 7 | Annotation report | `.mc-data/work/legacy-scan/annotation-report.md` | annotate | Conditional |
| 8 | UX design | `.mc-data/docs/phase4-ux/` | phase4 | Conditional |
| 9 | Implementation plan | `.mc-data/docs/phase5-implementation/` | phase5a | Always |
| 10 | Preflight report | `.mc-data/work/wf-preflight/preflight-report.md` | preflight | Always |
| 11 | Verify report | `.mc-data/docs/_meta/verify-sync.md` | verify | Khi preflight không FAIL |
| 12 | Deployment docs | `.mc-data/docs/phase6-deployment/` | deployment | Khi verify pass |

---

## Error Handling

Chi tiết đầy đủ (bảng E001–E017 + xử lý): `procedures/_shared.md §Error Handling Reference`.

Tóm tắt:

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E001 | Codebase không tồn tại | STOP — "Không tìm thấy codebase" |
| E002 | Backup `.mc-data/` fail | Backup `_mc-data-backup-YYYYMMDD-HHMMSS/` trước khi overwrite |
| E003 | POST-GATE fail sau 3 retries | STOP + hỏi user |
| E004 | Sub-skill SKILL.md thiếu | STOP (không auto-fix), báo path |
| E005 | `req-registry.json` thiếu sau shared skills cluster | Hướng dẫn chạy lại skill chưa xong |
| E006 | `jq` không khả dụng | Fallback python one-liner |
| E007 | User dừng giữa vòng lặp 5b | Checkpoint + `--resume` |
| E008 | Feature POST-GATE fail | Hỏi user: skip hay retry |
| E009 | Verify fail | Retry ×2, rồi WARNING + user confirm |
| E010 | `--from-phase` invalid | Hiển thị mapping |
| E011 | `--from-phase` prerequisites chưa sẵn sàng | Gợi ý chạy từ phase trước |
| E012 | Registry thiếu required fields | Rebuild qua `/wf-design` (tối đa 1 lần) |
| E013 | Preflight report thiếu sau retry | Cho phép skip với user xác nhận |
| E014 | Sub-skill fail sau retry | STOP + hỏi user: retry/skip/abort |
| E015 | Preflight FAIL | Gợi ý `/wf-fix-bugs` |
| E016 | Status file corrupt | Rebuild từ output paths (E012 fallback) |
| E017 | Module DEPRECATED (LEGACY_MODE) | Sub-skill enforce CORE-022 |

### Fix Rules

| Error Type | Auto-Fix | Escalate khi |
|------------|----------|--------------|
| `jq` không khả dụng (E006) | Fallback `python -c "import json; ..."` cho mọi lệnh đọc registry | Python cũng thiếu — STOP yêu cầu cài đặt |
| Status file corrupt (E016) | Rebuild state từ output paths trên disk (Resume Protocol §Status file fallback) | Output paths không đủ kết luận phases_completed |
| Registry thiếu required fields (E012) | Chạy lại `/wf-design` legacy flow rebuild registry — tối đa 1 lần | Vẫn thiếu fields sau 1 lần rebuild — hỏi user |
| Verify POST-GATE fail (E009) | Retry tối đa 2 lần | Vẫn fail — WARNING + user confirm tiếp tục |
| Preflight report thiếu (E013) | Retry 1 lần | Vẫn thiếu — cho phép skip với user xác nhận |
| Sub-skill fail (E003/E014) | Sub-skill tự retry tối đa 3 (Protocol 2) trước khi báo orchestrator | Hết retries — STOP, hỏi user retry/skip/abort |

---

## Context & Checkpoint

| Context Usage | Hành động |
|---------------|-----------|
| < 65% | Tiếp tục bình thường |
| 65–80% | Chuẩn bị checkpoint |
| 80–90% | Lưu checkpoint ngay |
| > 90% | FORCE STOP — checkpoint bắt buộc, thông báo user dùng `--resume` |

Checkpoint schema: `procedures/_shared.md §Status File Schema + §Context & Checkpoint`.

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `/new-project` | Workflow cho dự án mới hoàn toàn |
| `/feature-addition` | Workflow gọn — chỉ thêm feature khi đã có architecture |
| `/wf-fix-bugs` | Fix bugs — chạy bất kỳ lúc nào sau khi có code |
| `/wf-preflight` | Health check — kiểm tra sức khỏe dự án |
| `/status` | Xem tiến độ bất kỳ lúc nào |
| `/wf-legacy-scan` | Sub-skill — bước đầu tiên của workflow này |

> **Next:** Sau khi hoàn thành → dùng `/status` để xem tổng quan, hoặc `/feature-addition` để thêm features mới.
