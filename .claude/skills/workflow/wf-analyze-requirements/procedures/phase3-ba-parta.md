# Phase 3: Business Analyst — Phần A (ALWAYS FIRST)

> BA chạy trước để thiết lập stakeholder context. BA cũng cập nhật P1-01 Project Overview từ brainstorm context.
> BA tạo Phần A cho **TẤT CẢ departments trong scope** — mỗi department có file `[dept].md` riêng.
>
> **(Protocol 7 — PAR-05)** BA spawn **per department SONG SONG** (mỗi BA agent tạo Phần A cho 1 dept), batch <= `$MAX_PARALLEL_AGENTS` agents đồng thời. Departments độc lập nhau (ghi file riêng) → an toàn chạy parallel.

**PRE-GATE:** `test -n "$SCOPE"` (từ Phase 1)

**INPUT:** `phase0-brainstorm/P0-01-brainstorm.md` + registry + P1-01 template + user-needs template + dept index template

**OUTPUT:**
- `phase1-business/P1-01-project-overview.md` (UPDATED)
- `phase1-business/departments/[dept]/[dept].md` (NEW — Phần A, một file per department)

## Scope Resolution for Departments

- `scope = [module]`: chỉ 1 department (mapped từ module → dept)
- `scope = all/business`: tất cả departments trong `$ACTIVE_DEPTS`

## Steps

| Step | Action | Verify |
| ---- | ------ | ------ |
| 3.1  | `mkdir -p .mc-data/docs/phase1-business/departments/[dept]/` cho TẤT CẢ departments | `test -d departments/[dept]` |
| 3.2  | Cập nhật `P1-01-project-overview.md` — điền 9 sections từ brainstorm + context (Thông tin chung, Bối cảnh, Mục tiêu, Phạm vi, Stakeholders, Ràng buộc, Rủi ro, Timeline, Tiêu chí thành công). Nguồn: `phase0-brainstorm/P0-01-brainstorm.md` + registry + user context. | `test -s P1-01-project-overview.md` |
| 3.3  | **(PARALLEL per dept, batch <= `$MAX_PARALLEL_AGENTS`)** Chia `$ACTIVE_DEPTS` thành batches — mỗi batch tối đa **5 depts (Standard)** hoặc **3 depts (LPM)**. Mỗi dept trong batch: **TRƯỚC KHI spawn** — kiểm tra `test -f .mc-data/docs/phase1-business/departments/[dept]/[dept].md && test -s [path]`. Nếu file **đã tồn tại và non-empty** → LOG "Skip [dept] — Phần A đã có" + cộng vào `depts_completed` → **KHÔNG spawn agent**. Nếu chưa có → spawn 1 `business-analyst` agent riêng (`run_in_background: true`) tạo Phần A cho dept đó. Chờ toàn bộ batch hoàn thành → validate → batch tiếp theo. **LEGACY_MODE:** thêm Context Injection block (xem `_shared.md §LEGACY_MODE Context Injection`). | All agents success (hoặc skipped) |
| 3.4  | Verify MỖI `[dept].md` (Phần A) created | `test -s [dept].md` cho TẤT CẢ |
| 3.5  | Verify no placeholders (TODO/TBD) | `grep -rL "TODO\|TBD"` |
| 3.6  | **SAVE CHECKPOINT** (xem `_shared.md §Token Budget & Checkpoint`) | Checkpoint saved |

## Agent Context

Xem `_shared.md §Agent Context Templates → Template BA Phần A (Phase 3, per dept)`.

> **(Protocol 7)** Spawn pattern: mỗi BA agent chỉ tạo 1 dept file → không ghi cùng file → an toàn PARALLEL. Batch <= 5 agents (Standard) hoặc <= 3 agents (LPM) theo Protocol 7.5 + 6.6.

> **(Protocol 9 — PLN-03)** Context checkpoint: Khi context >= 65% → ưu tiên finish batch hiện tại → SAVE CHECKPOINT → dừng session. Khi >= 80% → KHÔNG spawn thêm agent. Khi >= 90% → FORCE STOP. (Xem `_shared.md §Token Budget & Checkpoint`)

> **Subagent context fallback:** Nếu Agent tool không khả dụng → thực hiện BA role inline. Ghi chú: "BA role executed inline (no Agent tool)."

**POST-GATE:** `test -s .mc-data/docs/phase1-business/departments/[dept]/[dept].md` cho TẤT CẢ departments

**Status update:** `analyze-status.json` → `phase_3.status = "completed"`, `phase_3.completed_at = <ISO timestamp>`

**Next phase:**
- Nếu `$LEGACY_MODE = true` → `phase3.5-legacy.md`
- Nếu không → `phase4-experts-partb.md`
