# 08 — Tradeoffs & ADR

> **Mục đích file:** 6 ADR-OPT lớn — Lane Dispatch / Session Isolation / Workload Gate / Aggregator / Template Strip / BA-first.

---

## 1. ADR Index

| ID | Tiêu đề | Status | Version intro |
|----|---------|--------|---------------|
| ADR-OPT-01 | Phase 4 Lane Dispatch parallel — write isolation per dept-lane | ACCEPTED | v2.0.0 |
| ADR-OPT-02 | Session Isolation `sessions/{id}/` + `latest` pointer + DUAL-WRITE | ACCEPTED | v2.5.0 |
| ADR-OPT-03 | Phase 0.5 Workload Gate — 3 zones (dead/warn/block) + CDG-A02 | ACCEPTED | v3.0.0 |
| ADR-OPT-04 | Phase 6 Signal Aggregator — dedup REQ-IDs giữa dept-lanes | ACCEPTED | v3.0.0 |
| ADR-OPT-05 | Template Strip recursive `_*` keys trước canonical write | ACCEPTED | v3.0.0 |
| ADR-OPT-06 | BA Part A TRƯỚC Domain Experts Part B (sequential) | ACCEPTED | v1.0.0 |

---

## 2. ADR-OPT-01: Phase 4 Lane Dispatch parallel

**Status:** ACCEPTED — v2.0.0
**Owner:** DEVKIT core team

### Context

Phân tích requirements cho 5+ departments. v1.x sequential — mỗi expert chạy lần lượt → 30+ phút cho 5 departments. Domain experts độc lập (sales-expert không cần kết quả của marketing-expert) → có thể chạy song song.

### Decision

Phase 4 Lane Dispatch parallel:
- Module: `_shared/lane/dispatcher.py`
- Max concurrent: 3 (token bucket backpressure — tránh OOM agent quota)
- Mỗi lane = 1 dept-expert pair → write vào subdir riêng `sessions/{id}/lanes/{dept-key}/signals.json`
- Write isolation 100% (mỗi lane chỉ ghi subdir của mình)

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Sequential (v1.x) | Đơn giản | Chậm | Critical pain |
| B. Parallel không isolation | Nhanh | Race condition khi cùng update file | Critical risk |
| C. Parallel + write isolation (chốt) | Nhanh + an toàn | Code complex hơn | Đáng giá |
| D. Parallel max 10 | Nhanh nhất | OOM agent quota | Quá rủi ro |

### Consequences

**Tích cực:**
- 5 dept × 10 min = 50 min sequential → ~17 min parallel (3 concurrent)
- Write isolation → 0 race condition
- Aggregator (ADR-OPT-04) handle dedup post-dispatch

**Tiêu cực:**
- Code lane dispatcher phức tạp (token bucket, backpressure)
- Cần aggregation step sau parallel
- Multi-dept conflict cần Phase 6d resolve

### Related

- Pattern: [`../../03-design-patterns/04-parallel-lane-dispatch.md`](../../03-design-patterns/04-parallel-lane-dispatch.md)
- Module: `_shared/lane/dispatcher.py`
- ADR-OPT-04 (Aggregator) dependency

---

## 3. ADR-OPT-02: Session Isolation

**Status:** ACCEPTED — v2.5.0

### Context

v1.x flat working dir → re-run cùng project ghi đè state cũ. User không thể chạy 2 phân tích song song hoặc compare 2 runs. Multi-dev share working dir → conflict.

### Decision

Session isolation:
- Mỗi run tạo `sessions/{YYYYMMDD-HHMMSS}-{hash4}/` subdir
- `latest` pointer file trỏ session mới nhất
- DUAL-WRITE: files ghi cả vào `sessions/{id}/` (canonical) VÀ flat path (backward-compat cho downstream chưa support session)
- Cleanup: giữ 5 sessions mới nhất (CORE-030)

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Flat (v1.x) | Đơn giản | Multi-run overwrite | Critical pain |
| B. Session-only (no flat) | Sạch | Breaking change downstream | Phá compat |
| C. DUAL-WRITE (chốt) | Backward-compat + isolation | 2× disk space cho working files | Đáng giá (cleanup giữ 5) |

### Consequences

**Tích cực:**
- Multi-run safe (eval #15)
- Compare 2 runs dễ
- Downstream skills (chưa migrate) vẫn đọc qua `latest` pointer

**Tiêu cực:**
- DUAL-WRITE tốn disk
- Cleanup cần (5 sessions × ~10 MB = 50 MB per project)

### Related

- Rule: CORE-030 (Working Directory Session Isolation)
- File: [04-file-contract.md](04-file-contract.md) §1

---

## 4. ADR-OPT-03: Workload Gate

**Status:** ACCEPTED — v3.0.0

### Context

User không biết "chạy phân tích này mất 5 phút hay 3 giờ?". Project lớn (≥10 dept, ≥50 req) chạy 90+ phút → user Ctrl+C giữa chừng → mất công.

### Decision

Phase 0.5 Workload Gate:
- Estimate: `EST_MINUTES = departments × avg_time × complexity_factor`
- 3 zones:
  - `dead_zone` (< 0.8) — silent continue
  - `warn` (0.8 ≤ ratio ≤ 1.5) — AskUserQuestion continue/abort
  - `block` (> 1.5) — Plan A (narrow scope) / Plan B (CDG-A02 Override) / Cancel

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Không có gate | Đơn giản | Surprise budget blow | Critical pain |
| B. Warning only | Đơn giản | User dễ ignore | Không đủ với project lớn |
| C. 3-zone gate (chốt) | Cân bằng | Complex hơn | Đáng giá |
| D. Hard limit (block > 60 min) | An toàn | Quá nghiêm | Trái BHV-002 |

### Consequences

**Tích cực:**
- User biết trước budget
- Block zone bắt user confirm CDG-A02 trước khi commit run dài

**Tiêu cực:**
- Estimation không hoàn toàn chính xác (mitigation: WARN zone hiển thị estimate, user judgement)
- CDG-A02 token cần audit chain

### Related

- Module: `_shared/partition/workload_gate.py`
- File: [05-error-codes.md](05-error-codes.md) §CDG-A02

---

## 5. ADR-OPT-04: Signal Aggregator

**Status:** ACCEPTED — v3.0.0

### Context

Phase 4 Lane Dispatch parallel → 5 lanes có thể cùng produce REQ-ID giống nhau (vd "Customer Management" trong Sales lane + CSKH lane). Không dedup → registry có duplicate.

### Decision

Phase 6 Signal Aggregator:
- Read all `sessions/{id}/lanes/*/signals.json`
- Merge + dedup theo REQ-ID normalized (lowercase, normalize hyphens)
- Flag CONFLICT khi 2 lanes có cùng REQ-ID nhưng content khác
- Output `aggregation-result.json` với `duplicates`, `conflicts[]`
- Conflicts route Phase 6d EXPERT-RESOLVE

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Không dedup | Đơn giản | Duplicate REQ-IDs | Critical |
| B. Last-write-wins | Đơn giản | Mất data từ lane đầu | Risky |
| C. Aggregator + conflict flag (chốt) | An toàn | Cần Phase 6d xử lý conflicts | Đáng giá |

### Consequences

**Tích cực:**
- 0 duplicate REQ-IDs trong registry
- Conflicts explicit (Phase 6d resolve)

**Tiêu cực:**
- Phase 6d cần logic resolve (EXPERT/DEFER)

### Related

- Module: `_shared/aggregate/aggregator.py`
- File: [04-file-contract.md](04-file-contract.md) §aggregation-result schema

---

## 6. ADR-OPT-05: Template Strip recursive

**Status:** ACCEPTED — v3.0.0

### Context

Template files (`_digests/*.template.json`, skill-local `templates/*.json`) chứa helper keys (`_template_notes`, `_comments`, `_examples`, `_placeholder`) để hướng dẫn skill author. Nếu KHÔNG strip trước khi ghi canonical output → keys leak vào downstream consumer (`wf-define-features`) → nhiễm context.

### Decision

Phase 8c strip recursive trước khi ghi canonical:
- Walk JSON recursively, remove mọi key bắt đầu với `_`
- Áp dụng cho `_meta/dept-digests.json` + `_meta/phase1-handoff.json`
- Working artifacts (sessions/{id}/department-digests.json) GIỮ helper keys (không leak)
- Helper: `_shared/_shared.md §1 strip_template_metadata()`

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Không strip | Đơn giản | Leak helper keys downstream | Critical |
| B. Strip top-level only | Đơn giản | Miss nested helpers | Không đủ |
| C. Strip recursive (chốt) | An toàn | Walk JSON cost | Đáng giá |

### Consequences

**Tích cực:**
- 0 leak helper keys downstream
- Downstream skills (`wf-define-features`) có canonical data sạch

**Tiêu cực:**
- Walk JSON cost (negligible với jq)

### Related

- Rule: CORE-031 (Template Usage Rule)
- File: [06-templates-list.md](06-templates-list.md) §Template Strip

---

## 7. ADR-OPT-06: BA Part A TRƯỚC Domain Experts Part B

**Status:** ACCEPTED — v1.0.0 (foundational)

### Context

Domain experts cần biết "tôi phụ trách dept nào, REQ-ID range nào, stakeholders là ai" mới phân tích được. Nếu spawn experts trước khi BA chạy → experts đoán bừa → quality thấp.

### Decision

BA-first orchestration:
- Phase 3: spawn `business-analyst` agent TRƯỚC
- BA tạo Phần A cho TẤT CẢ departments (stakeholders, scope, dept list)
- Phase 4: SAU KHI Phase 3 PASS, spawn domain experts parallel cho Part B
- Experts đọc Phần A của dept mình → mới phân tích Part B

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Parallel BA + Experts từ đầu | Nhanh | Experts đoán bừa | Quality thấp |
| B. BA → Experts sequential (chốt) | Quality cao | Chậm hơn 5-10 min | Đáng giá |
| C. Skip BA, dùng template Phần A | Nhanh | Generic không bám project | Trái BHV-001 |

### Consequences

**Tích cực:**
- Experts có context đầy đủ → quality cao
- Phần A reusable khi --resume Phase 4 fail

**Tiêu cực:**
- Phase 3 sequential bottleneck (mitigation: BA single agent đủ nhanh)

### Related

- Rule: BHV-001 (Ask Before Assume)
- File: [03-phase-routing.md](03-phase-routing.md) §Flow diagram

---

## 8. Liên kết

- ADR style: [Michael Nygard's template](https://github.com/joelparkerhenderson/architecture-decision-record)
- Ví dụ:
  - [`../wf-fix-bugs/07-tradeoffs-adr.md`](../wf-fix-bugs/07-tradeoffs-adr.md)
  - [`../wf-e2e-verify/08-tradeoffs-adr.md`](../wf-e2e-verify/08-tradeoffs-adr.md)
- Plans (lịch sử): [`plans/wf-analyze-requirements-v3-opt/`](../../../plans/) (nếu có)
