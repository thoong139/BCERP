# Phase 6c: Stakeholder Review (SO-01, SO-02, SO-03)

> Rà soát chéo kết quả phân tích — phát hiện mâu thuẫn và thiếu sót giữa các departments.
> **Scope gate:** `$SCOPE = "all"` only. Nếu scope = business/[module] → SKIP.

**PRE-GATE:** `test "$SCOPE" = "all"` && `test -s .mc-data/docs/phase1-business/P1-02-business-workflow.md`

**INPUT:** Tất cả `[dept].md` (Phần A + Phần B) + P1-02 + SO template từ `doc-framework/phase1-business/stakeholder-review.md`

**OUTPUT:** `.mc-data/docs/phase1-business/stakeholder-review.md`

## Large-Doc Analysis (Protocol 6 — 6.4)

Phase này đọc TẤT CẢ dept files — bắt buộc pre-compress nếu > 5 depts.

## Steps

| Step | Action | Verify |
| ---- | ------ | ------ |
| 6c.0 | **Pre-compress:** Nếu số dept files > **3 (Standard)** hoặc > **2 (LPM)**: Main conversation Grep từng `[dept].md` lấy: headers (##), REQ-IDs, conflicts/overlaps đã ghi chú, B5 (Điểm Tiếp Xúc) → tạo digest — **~200 từ/dept (Standard)** hoặc **~300 từ/dept Extended (LPM)**. Lưu digest vào memory để pass vào agent. Nếu dưới threshold: skip, agent đọc trực tiếp. | Digest ready |
| 6c.0b | **(Protocol 6.5 — Skeleton-first)** Nếu estimated output > **3000 từ (Standard)** hoặc > **2000 từ (LPM)**: agent tạo skeleton trước (section headers + key findings summary ~500 từ), sau đó điền chi tiết per section. | Skeleton strategy determined |
| 6c.1 | Spawn `business-analyst` agent với digest (hoặc file paths nếu dưới compression threshold). Nếu skeleton-first: agent tuân thủ 2-pass pattern. **LEGACY_MODE:** thêm Context Injection block (xem `_shared.md §LEGACY_MODE Context Injection`). | Agent success |
| 6c.2 | Tạo `stakeholder-review.md` | `test -s stakeholder-review.md` |
| 6c.3 | **SAVE CHECKPOINT** (xem `_shared.md §Token Budget & Checkpoint`) | Checkpoint saved |

## Agent Context

Xem `_shared.md §Agent Context Templates → Template Stakeholder Review (Phase 6c)`.

**POST-GATE:** `test -s .mc-data/docs/phase1-business/stakeholder-review.md`

**Status update:** `analyze-status.json` → `phase_6c.status = "completed"`.

**Next phase:** `phase6d-conflict.md`
