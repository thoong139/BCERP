# Plan: Tái cấu trúc `docs/` thành chuẩn MCV3

**Trạng thái:** 📋 PLANNED — chưa khởi động Wave 1
**Khởi tạo:** 2026-05-15
**Ước lượng:** 4 waves × nhiều phiên làm việc

## Mục tiêu

Tái cấu trúc thư mục `D:\Working\MCV3\docs\` thành **bộ tài liệu chuẩn hóa** cho phát triển MCV3:

1. Tài liệu nền tảng cho developer mở rộng MCV3 (kiến trúc, thiết kế, pattern)
2. **Bộ chuẩn ràng buộc** khi phát triển/mở rộng MCV3 — mọi skill, agent, rule mới phải tuân theo
3. Phát hiện kiến trúc chưa tốt → cải tiến và đưa vào chuẩn

**Constraint:** KHÔNG sửa file trong `.claude/**`. Refs từ `.claude/**` → `docs/` sẽ stale sau khi move (xử lý trong wave riêng).

## Đọc theo thứ tự

1. [00-master-plan.md](./00-master-plan.md) — Vision + 4 waves + DoD + cấu trúc đích
2. [progress.md](./progress.md) — Trạng thái hiện tại + checkpoint resume
3. Khi vào wave nào → đọc file wave đó trong [waves/](./waves/)

## Khi resume phiên mới

```
1. Đọc plans/docs-restructure-v1/progress.md trước
2. Xác định wave hiện tại + file đang dở
3. Đọc tiếp file wave tương ứng
4. Tiếp tục từ checkpoint cuối
```
