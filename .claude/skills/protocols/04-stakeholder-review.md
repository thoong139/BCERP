<!-- From shared-protocols.md lines 238-262 (§4) -->
# Protocol 4 — Stakeholder Review Protocol

> Dùng cho phases tạo stakeholder-review ở mỗi Phase (1, 2, 3, 4, 5, 6).

## 4.1 Flow

1. Đọc tất cả docs của phase → load context
2. Đọc template `doc-framework/[phase]/stakeholder-review.md`
3. Spawn PARALLEL agents: 2 agents cho Phần B(SO-01)/Phần C(SO-02)/Phần D(SO-03)
4. Tạo `stakeholder-review.md` theo template (Phần A-D)
5. Cập nhật Phần A (Dashboard)
6. **AUTO-CORRECTION LOOP** (max 3 iterations) — fix source docs, KHÔNG fix SO docs
7. **SAVE CHECKPOINT**

## 4.2 Trạng thái findings

| Trạng thái | Mô tả |
|------------|-------|
| PENDING | Chưa xử lý — cần auto-fix hoặc user decision |
| RESOLVED | Đã sửa trong source docs |
| DEFERRED | User chấp nhận rủi ro — ghi lý do trong `_index.md` |

**POST-GATE:** All SO files exist, non-empty, no Critical/High findings PENDING
