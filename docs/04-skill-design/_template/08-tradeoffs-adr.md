<!--
_template_notes:
  purpose: ADR (Architecture Decision Records) cho các quyết định trong skill.
  populate:
    - §1 List ADR (ID + 1-câu tóm tắt)
    - §2-N: 1 ADR/section theo template: Context → Decision → Alternatives → Consequences → Status
    - Mỗi ADR có ID format ADR-{skill}-{NNN}
    - Status: PROPOSED | ACCEPTED | DEPRECATED | SUPERSEDED-BY-ADR-XXX
  độ dài tham khảo: 200-400 dòng
  Ví dụ hay: tham khảo wf-fix-bugs/07-tradeoffs-adr.md hoặc wf-legacy-scan/08-tradeoffs-adr.md
-->

# 08 — Tradeoffs & ADR

> **Mục đích file:** Ghi lại các quyết định kiến trúc quan trọng — Context → Decision → Alternatives → Consequences. Reviewer dùng để hiểu **tại sao** chứ không chỉ **gì**.

---

## 1. ADR Index

| ID | Tiêu đề | Status | Ngày |
|----|---------|--------|------|
| ADR-{skill}-001 | {Tên decision 1} | ACCEPTED | YYYY-MM-DD |
| ADR-{skill}-002 | {Tên decision 2} | ACCEPTED | YYYY-MM-DD |
| ADR-{skill}-003 | {Tên decision 3} | DEPRECATED (xem ADR-005) | YYYY-MM-DD |
| ADR-{skill}-004 | {Tên decision 4} | ACCEPTED | YYYY-MM-DD |
| ADR-{skill}-005 | {Tên decision 5} | SUPERSEDES-ADR-003 | YYYY-MM-DD |

---

## 2. ADR-{skill}-001: {Tên decision}

**Status:** ACCEPTED — YYYY-MM-DD
**Owner:** {role / handle}

### Context

{Bối cảnh, vấn đề cần giải quyết. 2-4 câu, cụ thể.}

Ví dụ: "Khi chạy `/wf-fix-bugs` lần đầu, skill cần phát hiện tooling đã cài đặt (GitNexus, Serena). Hiện chưa có pattern auto-detect chuẩn."

### Decision

{Quyết định chốt. 1-2 câu, dứt khoát.}

Ví dụ: "Dùng CI PRE-GATE 3-step (Na/Nb/Nc) với cache TTL per-tool, fallback Grep/Glob nếu tool absent."

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Yêu cầu user pre-config | Đơn giản | Không zero-config | Trái triết lý DEVKIT |
| B. Auto-detect mỗi run | Linh hoạt | Chậm | Cache giải quyết |
| C. CI PRE-GATE 3-step (chốt) | Zero-config + cache + fallback | Code phức tạp hơn | Best of both |

### Consequences

**Tích cực:**
- User không cần làm gì
- Performance đảm bảo qua cache 24h
- Graceful degradation khi tool absent

**Tiêu cực:**
- Code phức tạp hơn (3 step thay vì 1)
- Cache có thể stale (mitigation: TTL + freshness check)

**Risks:** {Risks còn lại}

### Related

- Rule liên quan: CORE-033
- Pattern: [`../../03-design-patterns/02-ci-first-integration.md`](../../03-design-patterns/02-ci-first-integration.md)
- File khác cùng skill bị ảnh hưởng: [03-phase-routing.md](03-phase-routing.md), [07-procedures-structure.md](07-procedures-structure.md)

---

## 3. ADR-{skill}-002: {Tên decision}

**Status:** ACCEPTED — YYYY-MM-DD
**Owner:** {role / handle}

### Context

{...}

### Decision

{...}

### Alternatives considered

{...}

### Consequences

{...}

### Related

{...}

---

{... lặp cho mỗi ADR ...}

---

## N. Liên kết

- ADR style chung: Tham khảo [Michael Nygard's ADR template](https://github.com/joelparkerhenderson/architecture-decision-record)
- Ví dụ hay trong MCV3:
  - [`../wf-fix-bugs/07-tradeoffs-adr.md`](../wf-fix-bugs/07-tradeoffs-adr.md)
  - [`../wf-legacy-scan/08-tradeoffs-adr.md`](../wf-legacy-scan/08-tradeoffs-adr.md)
