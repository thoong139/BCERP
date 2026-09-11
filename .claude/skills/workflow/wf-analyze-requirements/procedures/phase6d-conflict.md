# Phase 6d: Conflict Resolution & Document Reconciliation

> Giải quyết findings từ SO-01/02/03 **trước khi** tạo feature specs.
> Phân loại mỗi finding: AUTO-RESOLVE | EXPERT-RESOLVE | BLOCKING-RESOLVE | DEFER-TO-PHASE.
> **KHÔNG hỏi user** — domain experts tự quyết định dựa trên best practices.
> **Items KHẨN CẤP (blocking) PHẢI được resolve bởi expert agents** — không được defer.
> **Scope gate:** `$SCOPE = "all"` only. Nếu scope = business/[module] → SKIP.

**PRE-GATE:** `test "$SCOPE" = "all"` && `test -s .mc-data/docs/phase1-business/stakeholder-review.md`

**INPUT:** `stakeholder-review.md` + tất cả `[dept].md` (Phần A + Phần B)

**OUTPUT:**
- `.mc-data/work/wf-analyze-requirements/deferred-issues.md` (NEW — chỉ chứa DEFER-TO-PHASE items)
- `stakeholder-review.md` UPDATED (mark RESOLVED/BLOCKING-RESOLVED/DEFERRED)
- `[dept].md` UPDATED (apply resolutions)

## Resolution Tracks Overview

Xem chi tiết tại `_shared.md §Resolution Tracks (Phase 6d)` — bao gồm 4 tracks, Classification Logic, AI Decision Record Schema, và deferred-issues.md Schema.

## Steps

| Step | Action | Verify |
| ---- | ------ | ------ |
| 6d.1 | Đọc SO-01, SO-02, SO-03 → extract ALL findings | Findings list loaded |
| 6d.2 | Phân loại findings theo 4 resolution tracks (xem Classification Logic trong `_shared.md`) | All classified, lưu `$FINDINGS_CLASSIFIED` |
| 6d.3 | AUTO-RESOLVE: cập nhật terminology, SSOT, status values vào dept docs | Docs updated |
| 6d.4 | EXPERT-RESOLVE: spawn domain expert agents phù hợp → expert chọn recommended option → apply. **(Protocol 6 — 6.2)** Pass CHỈ sections liên quan đến conflict (không pass full dept files): trích REQ-IDs xung đột + business rules liên quan + decision options. Expert chọn option tối ưu (compliance > data integrity > operational efficiency). Conflict ≥2 domains → spawn cả 2, lấy consensus. Apply tự động, ghi lý do vào SO docs. | Decisions captured |
| 6d.5 | **BLOCKING-RESOLVE: spawn expert agents cho KHẨN CẤP items** (xem BLOCKING-RESOLVE Protocol bên dưới) → experts đề xuất giải pháp → apply vào dept docs + ghi decision record | All KHẨN CẤP resolved |
| 6d.6 | DEFER-TO-PHASE: ghi **CHỈ items thực sự cần context từ phase sau** → `.mc-data/work/wf-analyze-requirements/deferred-issues.md` (schema trong `_shared.md`) | File created |
| 6d.7 | Cập nhật `stakeholder-review.md`: mark findings RESOLVED/BLOCKING-RESOLVED/DEFERRED | File updated |
| 6d.8 | Cập nhật affected `[dept].md` (Phần B) theo resolutions | Docs consistent |
| 6d.9 | **SAVE CHECKPOINT** (xem `_shared.md §Token Budget & Checkpoint`) | Checkpoint saved |

## BLOCKING-RESOLVE Protocol (Phase 6d.5)

> Items KHẨN CẤP **KHÔNG BAO GIỜ** được defer. Expert agents đại diện cho phòng ban và có domain knowledge để đề xuất giải pháp best-practice.

### Quy trình

| Step | Action | Verify |
|------|--------|--------|
| 6d.5a | Lọc tất cả findings có severity = KHẨN CẤP hoặc blocking Phase 2 | List BLOCKING items |
| 6d.5b | Với MỖI blocking item: xác định expert agents cần thiết (theo `Phòng ban xử lý`) | Experts identified |
| 6d.5c | Spawn expert agent(s) với context: finding details + affected REQ-IDs + dept docs liên quan + yêu cầu đề xuất giải pháp cụ thể. **LEGACY_MODE:** thêm Context Injection block (xem `_shared.md`). | Agent spawned |
| 6d.5d | Expert output: giải pháp recommended + lý do + impact assessment | Solution received |
| 6d.5e | Apply giải pháp vào affected `[dept].md` (bổ sung/cập nhật requirements) | Dept docs updated |
| 6d.5f | Ghi **AI Decision Record** vào `stakeholder-review.md` Phần E (schema trong `_shared.md`) | Record saved |

### Agent Context

Xem `_shared.md §Agent Context Templates → Template BLOCKING-RESOLVE (Phase 6d.5)`.

> Nếu blocking item liên quan ≥2 domains: spawn cả 2+ experts, lấy consensus giống EXPERT-RESOLVE. Ưu tiên: compliance > data integrity > operational efficiency.

**POST-GATE:** Không còn finding nào PENDING (tất cả RESOLVED, BLOCKING-RESOLVED, hoặc DEFERRED). **Không có item KHẨN CẤP nào trong deferred-issues.md.**

**Status update:** `analyze-status.json` → `phase_6d.status = "completed"`, counts cho từng track (auto_resolve/expert_resolve/blocking_resolve/defer_to_phase).

**Next phase:** `phase8-registry.md`
