# 01 — Vision & Principles

> **Mục đích file:** Lý do tồn tại + scope + non-goals của `wf-analyze-requirements`.

---

## 1. Tóm tắt

`wf-analyze-requirements` giải quyết bài toán **"có idea brainstorm rồi, làm sao biến nó thành requirements docs có cấu trúc đủ cho thiết kế hệ thống?"** bằng cách **huy động BA + Domain Experts qua 14 phases với Lane Dispatch parallel + Workload Gate + Signal Aggregation**, sinh **`phase1-business/` business docs hoàn chỉnh** + **cập nhật registry `requirements[]`**.

Đây là **skill trung tâm** của DEVKIT workflow — output là **single source of truth cho mọi skill downstream** (`wf-define-features`, `wf-design`, `wf-plan-modules`, ...).

---

## 2. Vấn đề trước khi có skill

| Hiện trạng | Pain point |
|------------|-----------|
| BA viết requirements thủ công, không có domain expert review | Bỏ sót requirements domain-specific (vd compliance healthcare, customs logistics) |
| Spawn domain experts mà không có BA trước | Experts không biết stakeholders/scope → đoán bừa |
| Nhiều domain experts cùng update registry → race condition | Conflict + duplicate REQ-IDs |
| Không có dedup giữa departments (vd "Customer Management" trong CRM + "Customer Service" trong CSKH) | Duplicate REQ-IDs cross-dept không phát hiện |
| LEGACY_MODE: không reuse existing dept docs → overwrite | Mất công manual edit lại |
| Workload estimation không có → user không biết "phải đợi 10 phút hay 3 giờ?" | Surprise budget blow |
| Multi-run cùng project → session state ghi đè nhau | Mất context phiên trước |
| Template helper keys (`_template_notes`, `_examples`) leak vào canonical digest output | Nhiễm context downstream skills |

**Ví dụ thực tế:** ERK Transport có 5 phòng ban (Sales, Marketing, CSKH, Kế toán, Vận chuyển). Trước skill này: BA viết 5 dept docs tuần tự (~2 ngày), không expert review → bỏ sót requirements customs (HS code, VNACCS). Với skill: Phase 4 Lane Dispatch spawn 5 lanes parallel (sales-expert, marketing-expert, customer-expert, finance-expert, logistics-expert) → mỗi lane viết vào `sessions/{id}/lanes/{dept-key}/signals.json` → Phase 6 aggregator dedup REQ-IDs → 45 phút thay vì 2 ngày, requirements compliance đầy đủ.

---

## 3. Mục tiêu skill (SMART)

| # | Mục tiêu | Đo bằng |
|---|----------|--------|
| 1 | BA phân tích stakeholders + scope TRƯỚC khi spawn domain experts | Phase 3 (BA Part A) chạy trước Phase 4 (Experts Part B). Eval #1, #11 |
| 2 | Domain experts chạy parallel per department, max 3 concurrent | Phase 4 Lane Dispatch (ADR-OPT-01, `_shared/lane/dispatcher.py`). Eval #18 |
| 3 | Workload estimation TRƯỚC khi commit run dài (gate at Phase 0.5) | Phase 0.5 Workload Gate (ADR-OPT-03). 3 zones: dead_zone <0.8, warn 0.8-1.5, block >1.5. Eval #16, #17 |
| 4 | Dedup REQ-IDs cross-dept (vd "Customer" trong Sales + CSKH) | Phase 6 Signal Aggregation (ADR-OPT-04, `_shared/aggregate/aggregator.py`). Eval #19 |
| 5 | Multi-run safe — mỗi run isolated trong `sessions/{id}/` | ADR-OPT-02 Session Isolation. Eval #15 |
| 6 | LEGACY_MODE merge existing docs thay vì overwrite | Phase 3.5 Legacy + Phase 5 Existing Docs Integration. Eval #14 |
| 7 | Template strip helper keys trước khi ghi canonical digest | ADR-OPT-05 Template Strip. Eval #20 |
| 8 | CDG anti-loop khi user override workload block hoặc resolve conflict | CDG-A01 (domain ambiguity), CDG-A02 (workload override). Eval #17 |
| 9 | Resume chính xác từ checkpoint, KHÔNG re-run dept đã done | Phase 0 `--resume` handler. Eval #2, #10 |

---

## 4. Nguyên tắc thiết kế

1. **BA-first orchestration** — Spawn BA agent TRƯỚC khi spawn domain experts. BA xác định stakeholders + scope + dept list → Experts mới biết "tôi phụ trách dept nào, REQ-ID range nào". Không bao giờ spawn parallel ngay.

2. **Lane Dispatch parallel — write isolation** — Phase 4: mỗi dept-expert pair = 1 lane = 1 subdir `sessions/{id}/lanes/{dept-key}/`. Mỗi lane chỉ write vào subdir của mình → 0 race condition. Max 3 concurrent (token bucket backpressure).

3. **Workload Gate — predictable budget** — Phase 0.5 ước tính trước commit: `EST_MINUTES = departments × avg_time × complexity_factor`. 3 zones: dead_zone (silent), warn (AskUserQuestion), block (CDG-A02 override OR scope narrow).

4. **Signal Aggregation — dedup REQ-IDs** — Phase 6 đọc tất cả `lanes/*/signals.json`, merge + dedup theo REQ-ID normalized. Cross-dept duplicate có nội dung khác → flag CONFLICT, route Phase 6d resolve.

5. **Session Isolation (ADR-OPT-02)** — Multi-run safe. Mỗi run tạo `sessions/{YYYYMMDD-HHMMSS}-{hash4}/`. `latest` pointer trỏ session mới. Old sessions preserved. Cleanup giữ 5 sessions mới nhất (CORE-030).

6. **DUAL-WRITE backward-compat** — Files ghi vào `sessions/{id}/` (canonical) VÀ flat path `.mc-data/work/wf-analyze-requirements/` (backward-compat). Downstream skills chưa support session path vẫn đọc được qua `latest` pointer.

7. **Template Strip (ADR-OPT-05)** — Trước khi ghi canonical digest (`_meta/dept-digests.json`, `_meta/phase1-handoff.json`): strip `_template_notes`, `_comments`, `_examples`, `_placeholder` recursively. Tránh nhiễm context downstream.

8. **Registry Safe-Write (CORE-006)** — Skill PRIMARY owner của `systems[]`, `modules[]`, `departments[]`, `requirements[]`, `interface_type`. KHÔNG modify `features[]` (thuộc wf-define-features), `design_status` (wf-design), `impl_status` (wf-implement-feature). Narrow per-field jq update.

9. **CORE-032 Lazy-Load Procedures** — SKILL.md ~420 dòng routing hub. 16 procedure files chỉ load khi tới phase tương ứng. `_shared.md` chứa cross-cutting concerns, KHÔNG load standalone.

---

## 5. Non-goals (KHÔNG làm)

Để tránh scope creep, skill này **KHÔNG** xử lý:

- **Generate feature specs** — `/wf-define-features` làm (skill này chỉ requirements ở mức business)
- **Architectural design** (tech stack, system layout) — `/wf-design` làm
- **Module planning + dependency graph** — `/wf-plan-modules` làm
- **Implement code** — `/wf-implement-feature` làm
- **Update registry `features[]`, `design_status`, `impl_status`** — thuộc skill khác (safe-write violation)
- **Brainstorm idea từ đầu** — `/wf-brainstorm` làm (skill này chỉ phân tích KHI đã có brainstorm)
- **Scan legacy codebase** — `/wf-legacy-scan` + `/wf-legacy-extract` làm (skill này CONSUME extracted data)

---

## 6. Tham chiếu

- Patterns áp dụng:
  - [`../../03-design-patterns/01-lazy-load-procedures.md`](../../03-design-patterns/01-lazy-load-procedures.md) — 16 procedure files lazy-load
  - [`../../03-design-patterns/04-parallel-lane-dispatch.md`](../../03-design-patterns/04-parallel-lane-dispatch.md) — ADR-OPT-01 Phase 4 Lane Dispatch
  - [`../../03-design-patterns/05-agent-prompt-template.md`](../../03-design-patterns/05-agent-prompt-template.md) — 8-section prompt cho BA + experts
  - [`../../03-design-patterns/06-checkpoint-resume.md`](../../03-design-patterns/06-checkpoint-resume.md) — session-state.json multi-level checkpoint
  - [`../../03-design-patterns/10-cdg-gate.md`](../../03-design-patterns/10-cdg-gate.md) — CDG-A01/A02
  - [`../../03-design-patterns/09-multi-session-locking.md`](../../03-design-patterns/09-multi-session-locking.md) — Session isolation

- Standards áp dụng:
  - [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md)
  - [`../../02-standards/06-safe-write-protocol.md`](../../02-standards/06-safe-write-protocol.md) — PRIMARY role per fields_owned
  - [`../../02-standards/11-output-path-contract.md`](../../02-standards/11-output-path-contract.md) — sessions/{id}/ + DUAL-WRITE

- Rules: CORE-006 (Safe-Write), CORE-021 (LEGACY_MODE Detection), CORE-022 (Legacy Decisions Bridge), CORE-025 (Parallelism safety), CORE-027 (CDG), CORE-030 (Session Isolation), CORE-031 (Template Usage), CORE-032 (Lazy-Load)
