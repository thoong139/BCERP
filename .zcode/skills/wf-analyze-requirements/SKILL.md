---
name: wf-analyze-requirements
version: 3.0.0
last_updated: 2026-04-23
description: |
  Huy dong BA + Domain Experts phan tich requirements co he thong — 14 phases chi tiet trong procedures/, tu context loading den registry update + handoff artifacts. Ho tro multi-session/resume; ca du an moi (interactive) va du an co san (legacy — doc tu extracted data). Tu dong phat hien loai du an.
  Output: Phase 1 business docs only — feature specs do /wf-define-features tao.

  TRIGGER khi:
  - User mo ta y tuong du an va can phan tich chi tiet requirements
  - De cap loai he thong: ERP / CRM / HR / Finance / Healthcare / Logistics / E-commerce
  - Keywords: "phan tich yeu cau", "analyze requirements", "can BA phan tich"
  - Sau khi /wf-brainstorm hoan thanh; goi lenh: /wf-analyze-requirements [scope] [--status] [--resume]

  LUON trigger khi user can phan tich requirements, du khong dung tu "analyze-requirements" — sau brainstorm, truoc design.

  KHONG trigger khi: chua co .mc-data/ hoac dang brainstorm y tuong → dung /wf-brainstorm truoc.
argument-hint: "[scope: all | business | functional | module-name] [--status] [--resume]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite, AskUserQuestion
---
# /wf-analyze-requirements: $ARGUMENTS

## Overview

| Mục                    | Nội dung                                                                                               |
| ----------------------- | ------------------------------------------------------------------------------------------------------- |
| **Mục đích**   | Huy động BA + Domain Experts phân tích requirements → Phase 1 business docs                        |
| **Prerequisites** | `phase0-brainstorm/` tồn tại (hoặc legacy extracted data)                                          |
| **Duration**      | Multi-session                                                                                           |
| **Phases**        | 15 phases (0 → 0.5 → 1 → 2 → 3 → 3.5(L) → 4 → 5(C) → 6 → 6b → 6c → 6d → 8 → 8b → 8c)      |
| **Session**       | Mỗi run tạo `sessions/{YYYYMMDD-HHMMSS}-{hash}/` — multi-run safe, resume chính xác (ADR-OPT-02) |
| **_shared**       | Import modules từ `_shared/`: lane, partition, aggregate, cache (xem `_shared.md §3-4`)           |
| **Input**         | Phase 0 docs + mô tả dự án                                                                          |
| **Output**        | `phase1-business/*.md` + `req-registry.json` (requirements[])                                       |
| **Procedure**     | `procedures/phaseN-*.md` (load per-phase) + `procedures/_shared.md` (protocols chung)               |

### SKILL.md ↔ procedures/ Phase Mapping

Bảng dưới đây ánh xạ SKILL.md phases (tổng quan) sang procedures/ phase files (chi tiết thực thi):

| SKILL.md Phase                              | procedures/ files                                                                                                                                                                                                                                                                                                        | Mô tả                                                                                                                                    |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| **Phase 0:** Auto-Detection           | `phase0-context.md`                                                                                                                                                                                                                                                                                                    | Detect project type, load context, registry + brainstorm                                                                                   |
| **Phase 1:** Phân tích Requirements | `phase1-scope.md` → `phase2-plan.md` → `phase3-ba-parta.md` → `phase3.5-legacy.md` (L) → `phase4-experts-partb.md` → `phase5-existing-docs.md` (C) → `phase6-consolidate.md` → `phase6b-workflow.md` (scope=all) → `phase6c-stakeholder.md` (scope=all) → `phase6d-conflict.md` (scope=all) | Scope → Plan → BA → Legacy naming → Experts → Existing docs → Consolidation → Workflow → Stakeholder Review → Conflict Resolution |
| **Phase 2:** Registry Update          | `phase8-registry.md` → `phase8b-crossval.md`                                                                                                                                                                                                                                                                        | Safe-write registry + 7-check auto-correction loop                                                                                         |
| **Phase 3:** Handoff Artifacts        | `phase8c-handoff.md`                                                                                                                                                                                                                                                                                                   | Generate digests + copy to `_meta/`                                                                                                      |

> **Lưu ý:** `(L)` = chỉ chạy nếu `$LEGACY_MODE = true`. `(C)` = chỉ chạy nếu `$HAS_EXISTING_DOCS = true`.
> **Lưu ý thứ tự:** Phase 3 (Handoff) chạy **SAU** Phase 2 (Registry) vì digests phải phản ánh registry cuối cùng.

### Load-on-Demand Pattern

AI chỉ đọc phase file đang thực thi + `_shared.md` (cho protocols/templates chung) — KHÔNG đọc toàn bộ procedures/ 1 lần. Điều này tiết kiệm ~85-90% tokens so với monolithic flow-new.md cũ.

- Entry: Luôn load `procedures/phase0-context.md` + `procedures/_shared.md`
- Resume: Đọc `checkpoint.json` → `position.current_phase` → load phase file tương ứng
- Shared content (State Variables, Agent Templates, LEGACY Context Injection, Fix Rules, Resolution Tracks, Registry Schema, Error Codes, Output Report): tất cả ở `_shared.md`

### Template Usage Rule (BẮT BUỘC)

Mọi working file PHẢI tuân thủ: **ĐỌC** template từ `.claude/skills/workflow/wf-analyze-requirements/templates/` → **ĐIỀN** dữ liệu thực tế → **GHI** đến output path.

| Template                                      | Output path                                                       | Được tạo ở procedures/ Phase                                  |
| --------------------------------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------ |
| `templates/analyze-status.json`             | `.mc-data/work/wf-analyze-requirements/analyze-status.json`     | `phase0-context.md` Step 0.3                                     |
| `templates/analyze-plan.md`                 | `.mc-data/work/wf-analyze-requirements/analyze-plan.md`         | `phase2-plan.md` Step 2.5                                        |
| `templates/checkpoint.json`                 | `.mc-data/work/wf-analyze-requirements/checkpoint.json`         | `phase2-plan.md` (lần SAVE CHECKPOINT đầu)                    |
| `templates/department-digests.json`         | `.mc-data/work/wf-analyze-requirements/department-digests.json` | `phase8c-handoff.md` Step 8c.1                                   |
| `templates/phase1-handoff.json`             | `.mc-data/work/wf-analyze-requirements/phase1-handoff.json`     | `phase8c-handoff.md` Step 8c.2                                   |
| `_shared/templates/session-state.json`      | `sessions/{id}/session-state.json`                              | `phase0-context.md` Step 0.2b (session init, ADR-OPT-02)         |
| `_shared/templates/workload-report.md`      | `sessions/{id}/workload-report.md`                              | `phase0.5-workload-gate.md` Step 0.5.3 (gate report, ADR-OPT-03) |
| `_shared/templates/lane-signal.json`        | `sessions/{id}/lanes/{dept-key}/signals.json`                   | `phase4-experts-partb.md` (lane output, ADR-OPT-01)              |
| `_shared/templates/aggregation-result.json` | `sessions/{id}/aggregation-result.json`                         | `phase6-consolidate.md` Step 6.5b (aggregation, ADR-OPT-04)      |

> **Lưu ý về `_digests/` templates:** `.claude/doc-framework/_digests/*.template.json` là **tài liệu schema** (mô tả validation rules, field types) — dùng để tham khảo khi cần hiểu schema, KHÔNG dùng để tạo file. `.claude/skills/workflow/wf-analyze-requirements/templates/` là **starter files** (có placeholder values) — dùng để ĐỌC → ĐIỀN → GHI.

### Workflow Position

```
/wf-brainstorm → /wf-analyze-requirements ← YOU ARE HERE → /wf-define-features
```

---

## Phase 0: Auto-Detection & Routing (BAT BUOC — chay truoc tien)

> Tu dong phat hien loai du an va inject context phu hop.
> LEGACY_MODE detection theo CORE-021: check `project-context.md` (> 500 bytes).

```
STEP 1: Detect LEGACY_MODE (CORE-021)
  LEGACY_MODE = test -f .mc-data/work/legacy-scan/project-context.md && size > 500 bytes

  IF LEGACY_MODE:
    LEGACY_CONTEXT = read .mc-data/work/legacy-scan/project-context.md
    → PROJECT_TYPE = LEGACY
    → Thong bao: "Phat hien du an co san (project-context.md). Chay flow voi legacy context injection."
    → Load procedures/_shared.md + procedures/phase0-context.md
    → [cac phase files se handle legacy-specific phases dua tren LEGACY_MODE flag]

STEP 2: Kiem tra .mc-data/
  ELSE IF test -d .mc-data:
    → PROJECT_TYPE = NEW
    → **Session Isolation (ADR-OPT-02):**
      Tạo session dir: `.mc-data/work/wf-analyze-requirements/sessions/{YYYYMMDD-HHMMSS}-{hash4}/`
      Cập nhật `latest` pointer: `.mc-data/work/wf-analyze-requirements/latest` → session dir
      Khởi tạo `session-state.json` từ template `_shared/templates/session-state.json`
      Cleanup: giữ 5 sessions mới nhất, xoá sessions cũ hơn (CORE-030)
    → Load procedures/_shared.md + procedures/phase0-context.md

STEP 3: Du an moi hoan toan
  ELSE:
    → STOP: "Chua co du an. Chay `/wf-brainstorm` de bat dau."
```

**Dac biet — `--resume` handler:**

```
IF $ARGUMENTS chua "--resume":
  IF $ARGUMENTS chua "--session=ID":
    session_dir = ".mc-data/work/wf-analyze-requirements/sessions/{ID}/"
  ELSE IF test -f .mc-data/work/wf-analyze-requirements/latest:
    session_dir = readlink .mc-data/work/wf-analyze-requirements/latest
  ELSE:
    session_dir = tìm session mới nhất trong sessions/

  IF test -f "$session_dir/session-state.json":
    state = doc session-state.json
    → next_phase = state.next_action
    → Load procedures/_shared.md + procedures/phase<next_phase>.md
      (LEGACY_MODE tu detect tu project-context.md — CORE-021)
  ELSE IF test -f .mc-data/work/wf-analyze-requirements/checkpoint.json:
    // Backward-compat: fallback to old checkpoint format
    checkpoint = doc checkpoint.json
    → Load procedures/_shared.md + procedures/phase<current_phase>.md
  ELSE:
    → STOP: "Khong tim thay session hoac checkpoint. Chay `/wf-analyze-requirements` tu dau."
```

**Dac biet — `--status` handler:**

```
IF $ARGUMENTS chua "--status":
  IF test -f .mc-data/work/wf-analyze-requirements/checkpoint.json:
    checkpoint = doc checkpoint.json
    // Filesystem reconciliation: scan actual dept files de hien thi so that
    actual_dept_files = find .mc-data/docs/phase1-business/departments/ -name "*.md" | wc -l
    // So sanh voi checkpoint.depts_completed
    // Hien thi ca hai: checkpoint state VA actual_dept_files count
    → Hien thi trang thai theo project_type (legacy hoac new):
      - Bao gom dong: "Files dept tren disk: [actual_dept_files]"
      - Neu actual_dept_files != checkpoint.depts_completed → "(checkpoint chua dong bo — chay --resume de cap nhat)"
    → STOP
  ELSE IF test -f .mc-data/work/wf-analyze-requirements/analyze-status.json:
    → Hien thi trang thai tu analyze-status.json
    → STOP
  ELSE:
    → "Chua co analyze-requirements session nao."
    → STOP
```

---

## Phase 0.5: Workload Gate (ADR-OPT-03)

> Ước tính workload trước khi commit thực thi. Cho user biết trước thời gian dự kiến.
> Chạy sau Phase 0 (context loading), trước Phase 1 (execution).
> Chi tiết thực thi: `procedures/phase0.5-workload-gate.md`.

**PRE-GATE:** Phase 0 POST-GATE PASS.

```
STEP 1: Estimate workload
  Input: $REGISTRY_DATA (systems, modules, requirements, departments counts)
  Heuristic: EST_MINUTES = departments × avg_time_per_dept × complexity_factor
  - avg_time_per_dept = 3 min (standard), 1.5 min (quick), 5 min (deep)
  - complexity_factor = 1.0 (normal), 1.5 (LEGACY_MODE), 2.0 (multi-system + compliance)

  Import: _shared/partition/planner.py → plan_partitions(items, group_key="department")
  Import: _shared/partition/workload_gate.py → check_workload_gate(estimate, threshold=45)

STEP 2: Gate evaluation
  ratio = estimated_total_minutes / 45  (threshold per ADR-OPT-03 §4)

  if ratio < 0.8  → DEAD_ZONE: silent continue (không hiển thị)
  if 0.8 ≤ ratio ≤ 1.5 → WARN: hiển thị estimate, hỏi continue (AskUserQuestion)
  if ratio > 1.5 → BLOCK: hiển thị Plan A/B menu

STEP 3: Plan A/B options khi BLOCK
  Plan A-1: Narrow scope (chỉ top-N departments)
  Plan A-2: Override + CDG-A02 confirmation (xem ADR-OPT-08)
  Plan B: Partition — chạy từng workload riêng, checkpoint giữa mỗi workload

STEP 4: Ghi workload-report.md vào session dir từ template _shared/templates/workload-report.md
  Cập nhật session-state.json: phases.P0_5.status, next_action
```

**POST-GATE:** Workload estimate recorded, user acknowledged (if WARN/BLOCK).

---

## Arguments

| Argument         | Mo ta                                                  | Default        | Ap dung      |
| ---------------- | ------------------------------------------------------ | -------------- | ------------ |
| `scope`        | `all` / `business` / `[module-name]`             | `all`        | Ca hai flows |
| `--status`     | Hien thi tien do, khong thuc thi                       | —             | Ca hai flows |
| `--resume`     | Resume tu checkpoint da luu                            | —             | Ca hai flows |
| `--session=ID` | Tiep tuc session cu the (format: YYYYMMDD-HHMMSS-hash) | Latest session | Ca hai flows |

---

## Output Files

> Ca hai flows tao ra cung cau truc Phase 1 docs.

| # | File                       | Path                                                  | Mo ta                                            |
| - | -------------------------- | ----------------------------------------------------- | ------------------------------------------------ |
| 1 | P1-01-project-overview.md  | `.mc-data/docs/phase1-business/`                    | Tong quan du an (updated)                        |
| 2 | [dept].md                  | `.mc-data/docs/phase1-business/departments/[dept]/` | Phan A (BA) + Phan B (expert) per dept           |
| 3 | P1-02-business-workflow.md | `.mc-data/docs/phase1-business/`                    | Quy trinh kinh doanh xuyen phong ban (scope=all) |
| 4 | stakeholder-review.md      | `.mc-data/docs/phase1-business/`                    | Ra soat cheo ket qua phan tich (scope=all)       |
| 5 | deferred-issues.md         | `.mc-data/work/wf-analyze-requirements/`            | Issues defer sang Phase 2/3 (scope=all)          |

### Working Files

| #  | File                          | Path                                       | Mo ta                                                              |
| -- | ----------------------------- | ------------------------------------------ | ------------------------------------------------------------------ |
| 1  | analyze-status.json           | `sessions/{id}/`                         | Trang thai chi tiet tung phase                                     |
| 2  | analyze-plan.md               | `sessions/{id}/`                         | Expert → department mapping                                       |
| 3  | execution-plan.md             | `sessions/{id}/`                         | Execution plan (Protocol 9)                                        |
| 4  | analyze-report-[date].md      | `sessions/{id}/`                         | Bao cao tong ket                                                   |
| 5  | checkpoint.json               | `sessions/{id}/`                         | Checkpoint cho resume (legacy format, backward-compat)             |
| 6  | department-digests.json       | `sessions/{id}/`                         | Digest theo department cho downstream skills                       |
| 7  | phase1-handoff.json           | `sessions/{id}/`                         | Handoff chot cho `/wf-define-features`                           |
| 8  | session-state.json            | `sessions/{id}/`                         | Session isolation state machine (ADR-OPT-02)                       |
| 9  | workload-report.md            | `sessions/{id}/`                         | Workload gate estimate report (ADR-OPT-03)                         |
| 10 | aggregation-result.json       | `sessions/{id}/`                         | Signal aggregation dedup result (ADR-OPT-04)                       |
| 11 | lanes/{dept-key}/signals.json | `sessions/{id}/lanes/`                   | Per-dept lane output (ADR-OPT-01)                                  |
| 12 | phase-summary.md              | `sessions/{id}/`                         | CORE-028 phase summary (append-only)                               |
| 13 | latest                        | `.mc-data/work/wf-analyze-requirements/` | Pointer → session dir mới nhất (backward-compat cho downstream) |

> **DUAL-WRITE pattern (ADR-OPT-02):** Files #1-12 ghi vào `sessions/{id}/` (canonical) **VÀ** dual-write sang flat path `.mc-data/work/wf-analyze-requirements/` (backward-compat cho downstream consumers chưa support session path). File `latest` pointer trỏ đến session dir mới nhất. Chi tiết: `procedures/_shared.md §Session State`.
>
> **Dual-location digest:** Ngoài DUAL-WRITE phía working, Phiên 6 copy digest files (`department-digests.json`, `phase1-handoff.json`) từ working dir → canonical `.mc-data/docs/_meta/` cho downstream skills (CORE-007 §4b).

### Legacy-specific Output (LEGACY_MODE — xem `procedures/phase3.5-legacy.md`)

| # | File                        | Path                           | Mo ta                               |
| - | --------------------------- | ------------------------------ | ----------------------------------- |
| 1 | naming-normalization-log.md | `.mc-data/work/legacy-scan/` | Log naming normalization (CORE-015) |

### Templates

Tat ca output theo mau tai `.claude/doc-framework/phase1-business/` va `.claude/skills/workflow/wf-analyze-requirements/templates/`.

---

## Workflow Position

```
DU AN MOI:
  /wf-brainstorm → /wf-analyze-requirements (procedures/) → /wf-define-features

DU AN CO SAN:
  /wf-legacy-scan → /wf-brainstorm → /wf-analyze-requirements (procedures/ + context injection, CORE-021) → /wf-define-features
```

---

## Protocols & Strategy

> Protocol: Xem `.claude/skills/protocols/`; logic chi tiết cross-cutting nằm trong `procedures/_shared.md`, và các phase-specific steps nằm trong `procedures/phaseN-*.md`.

### Execution Strategy

| Condition                                        | Mode                                                                             |
| ------------------------------------------------ | -------------------------------------------------------------------------------- |
| BA mở scope, xác định departments, lập plan | **SEQUENTIAL**                                                             |
| Expert phân tích theo department hoặc batch   | **PARALLEL** (Lane Dispatch — ADR-OPT-01, `_shared/lane/dispatcher.py`) |
| Consolidation, registry update, cross-validation | **HYBRID**                                                                 |

### _shared Module Usage (ADR-OPT Integration)

| Module                | Import                                                             | Phase sử dụng | Mục đích                                           |
| --------------------- | ------------------------------------------------------------------ | --------------- | ----------------------------------------------------- |
| `_shared/lane`      | `from lane import dispatch_lanes, LaneConfig`                    | Phase 4         | Dept-expert lane dispatch, max_parallel=3             |
| `_shared/partition` | `from partition import plan_partitions, check_workload_gate`     | Phase 0.5       | Workload estimation + gate evaluation                 |
| `_shared/aggregate` | `from aggregate import aggregate_lane_signals, dedup_by_id`      | Phase 6         | REQ-ID dedup giữa dept-lanes                         |
| `_shared/cache`     | `from cache import get_cached, set_cached, compute_content_hash` | Phase 0.5       | Cache check (P1, không P0)                           |
| `_shared/cdg`       | `from cdg import create_cdg_token, check_anti_loop`              | Phase 0.5, 6d   | CDG-A01 (domain ambiguity), CDG-A02 (scope narrowing) |

> Import convention theo `_shared/_shared.md §3-4`.

### Fix Rules

| Error Type                | Auto-Fix Strategy                           | Escalate If                                |
| ------------------------- | ------------------------------------------- | ------------------------------------------ |
| `missing_dept_doc`      | Tạo lại file từ context Phase 0 và plan | Thiếu nguồn sự thật                    |
| `expert_conflict`       | Resolve theo flow 6d và log decision       | Cần stakeholder quyết định             |
| `registry_schema_error` | Chuẩn hóa field names, ghi lại atomic    | JSON vẫn invalid sau 3 lần               |
| `traceability_gap`      | Bổ sung link REQ-ID từ source docs        | Không xác định được anchor hợp lệ |

---

## Phase 1: Thực Thi Phân Tích Requirements

> Chi tiết thực thi: `procedures/phase0-context.md` → `phase1-scope.md` → `phase2-plan.md` → `phase3-ba-parta.md` → `phase3.5-legacy.md` (L) → `phase4-experts-partb.md` → `phase5-existing-docs.md` (C) → `phase6-consolidate.md` → `phase6b-workflow.md` → `phase6c-stakeholder.md` → `phase6d-conflict.md`.

**PRE-GATE:** `phase0-brainstorm/` và `req-registry.json` đã tồn tại.

### PRE-GATE Digest Loading (procedures/phase0-context.md)

| Step | Action                                                                                             | Tool | Verify                                                                 |
| ---- | -------------------------------------------------------------------------------------------------- | ---- | ---------------------------------------------------------------------- |
| 0.1  | Kiểm tra project-digest.json tồn tại ở `.mc-data/docs/_meta/`                                | Bash | Nếu tồn tại → đọc; nếu không → fallback read full phase0 docs |
| 0.2  | Nếu digest có → inject context vào flow; nếu không → tiếp tục với phase0 docs đầy đủ | Read | Context sẵn sàng (gọn từ digest hoặc đầy đủ từ docs)         |

### Main Phase 1 Execution (11 phase files)

| Step | Action                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | Tool          | Verify                                              |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- | --------------------------------------------------- |
| 1.1  | Load `_shared.md` + `phase0-context.md`, tạo `analyze-status.json` từ template, sau đó load `phase1-scope.md` + `phase2-plan.md` để lập `analyze-plan.md`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | Read + Write  | Tracking files được tạo                         |
| 1.2  | Thực thi tuần tự per phase file: BA (`phase3-ba-parta.md`) → legacy (`phase3.5-legacy.md` nếu LEGACY_MODE) → experts (**Lane Dispatch ADR-OPT-01**: `phase4-experts-partb.md` — mỗi dept-expert chạy song song, mỗi lane viết vào `sessions/{id}/lanes/{dept-key}/signals.json`, `max_parallel=3`, token bucket backpressure) → existing docs (`phase5-existing-docs.md` nếu có) → consolidation (**Signal Aggregator ADR-OPT-04**: `phase6-consolidate.md` — dedup REQ-ID giữa dept-lanes bằng `_shared/aggregate/aggregator.py`, key=REQ-ID normalized, flag CONFLICT cho cross-dept duplicates) → workflow (`phase6b-workflow.md` scope=all) → stakeholder (`phase6c-stakeholder.md` scope=all) → conflict (`phase6d-conflict.md` scope=all) | Agent + Write | Dept docs, workflow doc và review doc được tạo |

**POST-GATE:** Dept docs Phase 1, `P1-01-project-overview.md` và các working files chính đã được tạo hoặc cập nhật.

---

## Phase 2: Registry Update & Cross-Validation

> Chi tiết thực thi: `procedures/phase8-registry.md` → `procedures/phase8b-crossval.md`.

**PRE-GATE:** Phase 1 POST-GATE PASS.

| Step | Action                                                                                                                                                                                      | Tool                | Verify                    |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- | ------------------------- |
| 2.1  | Safe-update `req-registry.json` theo scope được phép — chỉ modify: `systems[]`, `modules[]`, `departments[]`, `requirements[]`, `interface_type` (`phase8-registry.md`) | Read + Write        | Registry valid sau ghi    |
| 2.2  | Cross-Validation auto-correction loop — tối đa 3 iterations, 7 checks (`phase8b-crossval.md`)                                                                                          | Grep + Edit + Write | Không còn lỗi blocking |

**POST-GATE:** Registry PASS (`jq '.'` valid), zero blocking validation errors.

---

## Phase 3: Generate Handoff Artifacts (`procedures/phase8c-handoff.md`)

> Tạo department-digests.json và phase1-handoff.json từ Phase 1+2 output để downstream skills load nhanh.
> **Chạy SAU Phase 2** vì digests phải phản ánh registry cuối cùng.
> **Template Strip (ADR-OPT-05):** Trước khi ghi digest, strip `_template_notes`, `_comments`, `_examples`, `_placeholder` — tránh nhiễm context downstream. Atomic write: ghi temp → validate → rename.

**PRE-GATE:** Phase 2 POST-GATE PASS.

| Step | Action                                                                                                                                                                                      | Tool  | Verify                                                                      |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- | --------------------------------------------------------------------------- |
| 3.1  | Đọc dept docs, requirements, stakeholder-review.md, deferred-issues.md                                                                                                                    | Read  | Context sẵn sàng                                                          |
| 3.2  | Sinh `department-digests.json` từ template → **strip `_template_notes`** (ADR-OPT-05, `_shared/_shared.md §1`) → **atomic write** (`_shared/_shared.md §2`)        | Write | Digest hợp lệ JSON, không chứa `_template_notes`, ~150 words per dept |
| 3.3  | Sinh `phase1-handoff.json` từ template → **strip `_template_notes`** → **atomic write**                                                                                  | Write | Digest hợp lệ JSON, không chứa `_template_notes`                      |
| 3.4  | Sync working copies sang canonical `_meta/` paths: `cp department-digests.json .mc-data/docs/_meta/dept-digests.json && cp phase1-handoff.json .mc-data/docs/_meta/phase1-handoff.json` | Write | Cả 4 files tồn tại, readable                                             |

**Fallback:** Nếu digest generation fail → log warning, tiếp tục (backward compatible — consumer skill sẽ đọc full docs).

---

## Registry Update (Conditional)

> Registry Safe-Write áp dụng cho `/wf-analyze-requirements`.

- Chỉ modify các fields được phép: `systems[]`, `modules[]`, `departments[]`, `requirements[]`, `interface_type`.
- Không modify: `features[]`, `design_status`, `ux_design_status`, `implementation_order`, `impl_status`.
- Luôn đọc registry ngay trước khi ghi, ghi atomic một lần và validate bằng `jq` sau ghi.

---

## Output Report

- Phase 1 docs: `.mc-data/docs/phase1-business/`
- Registry updated: `.mc-data/docs/_meta/req-registry.json`
- Handoff: `.mc-data/work/wf-analyze-requirements/phase1-handoff.json`

Next: /wf-define-features

---

## Related Skills

| Skill                   | Quan he                                       |
| ----------------------- | --------------------------------------------- |
| `/wf-brainstorm`      | Prerequisite (cả hai flows)                  |
| `/wf-legacy-extract`  | Upstream (legacy flow) — tạo extracted data |
| `/wf-define-features` | **Next step**                           |
| `/status`             | Kiểm tra tiến độ                          |

---

## Error Handling

| Code | Tình huống                               | Hành động                                                        |
| ---- | ------------------------------------------ | ------------------------------------------------------------------- |
| E001 | PRE-GATE fail — brainstorm docs chưa có | STOP — hướng dẫn chạy `/wf-brainstorm` trước               |
| E002 | req-registry.json không tồn tại         | Tạo mới với schema rỗng — đây là bước khởi tạo registry |
| E003 | Agent timeout / không trả output         | Re-spawn 1 lần; nếu vẫn fail → skip + WARNING                   |
| E004 | Conflict giữa expert outputs              | Ghi nhận cả hai quan điểm, flag để user quyết định         |
| E005 | Output file write fail                     | Retry 3 lần, sau đó escalate to user                             |
| E006 | User cancel giữa workflow                 | Lưu checkpoint, hướng dẫn dùng `--resume`                    |
