# Phase 6b: Business Workflow (CROSS-DEPARTMENTAL)

> Tổng hợp tất cả department workflows thành **quy trình kinh doanh xuyên phòng ban**.
> **Scope gate:** `$SCOPE = "all"` only. Nếu scope = business/[module] → SKIP.

**PRE-GATE:** `test "$SCOPE" = "all"` && tất cả `[dept].md` (Phần B) files đã được tạo ở Phase 4

**INPUT:** Tất cả `[dept].md` (Phần B) + P1-02 template (`doc-framework/phase1-business/P1-02-business-workflow.md`)

**OUTPUT:** `.mc-data/docs/phase1-business/P1-02-business-workflow.md`

## Large-Doc Analysis Pattern (Protocol 6 — 6.4)

Khi có > 5 depts: Main conversation pre-compress TRƯỚC KHI spawn agent.

## Steps

| Step | Action | Verify |
| ---- | ------ | ------ |
| 6b.0 | **Pre-compress:** Nếu số dept files > **3 (Standard)** hoặc > **2 (LPM)**: Main conversation Grep từng `[dept].md` lấy section B1 (Tổng Quan Quy Trình) + B5 (Điểm Tiếp Xúc) → tạo digest nội bộ — **~200 từ/dept (Standard)** hoặc **~300 từ/dept Extended (LPM)**. Nếu dưới threshold: skip, agent đọc trực tiếp. | Digest ready |
| 6b.0b | **(Protocol 6.5 — Skeleton-first)** Nếu estimated output > **3000 từ (Standard)** hoặc > **2000 từ (LPM)**: agent tạo skeleton trước (section headers + 1-2 câu/section ~500 từ), sau đó điền chi tiết. | Skeleton strategy determined |
| 6b.1 | Spawn `business-analyst` — tổng hợp end-to-end cross-dept workflow từ digest (hoặc files trực tiếp nếu dưới compression threshold). Nếu skeleton-first: agent tuân thủ 2-pass pattern. **LEGACY_MODE:** thêm Context Injection block (xem `_shared.md §LEGACY_MODE Context Injection`). | Agent success |
| 6b.2 | **SAVE CHECKPOINT** (xem `_shared.md §Token Budget & Checkpoint`) | Checkpoint saved |

## Agent Context

Xem `_shared.md §Agent Context Templates → Template P1-02 Cross-Dept Workflow (Phase 6b)`.

**Agent:** `business-analyst`. Template: `.claude/doc-framework/phase1-business/P1-02-business-workflow.md`. Quality: Mermaid diagrams, No TODO/TBD.

**POST-GATE:** `test -s .mc-data/docs/phase1-business/P1-02-business-workflow.md`

**Status update:** `analyze-status.json` → `phase_6b.status = "completed"`.

**Next phase:** `phase6c-stakeholder.md`
