---
scope: always
description: Quy tắc vận hành MCV3 — luôn áp dụng cho mọi dự án trong repo này.
---

# Project Rules

## 1. Định Vị MCV3

MCV3 là bộ công cụ hỗ trợ người không chuyên phát triển phần mềm. Output của repo này phải đủ tốt cho doanh nghiệp dùng vận hành VÀ đủ chuẩn cho AI dùng làm context phát triển tiếp.

## 2. Thứ Tự Ưu Tiên

> Xem `00-core.md` §0 (CORE-023). Output MCV3: chất lượng doanh nghiệp + chuẩn AI context. Không hy sinh correctness, completeness, security hoặc traceability để lấy tốc độ.

## 3. Definition of Done

**Code:** map được tới REQ-ID/FEAT-ID, không bỏ sót behavior đã cam kết, không có lỗi logic/build/test/bảo mật rõ ràng, docs và registry được sync lại khi cần.

## 4. Single Source of Truth

> Xem `00-core.md` §1 (CORE-004). `.mc-data/docs/_meta/req-registry.json` là SSOT.

## 5. Song Song Hóa An Toàn

Chỉ song song hóa khi: contract/interface rõ, mỗi output có đúng 1 owner, các luồng không ghi đè lẫn nhau, có checkpoint hợp nhất + verify sau merge.

Mẫu ưu tiên: song song theo department/module độc lập, frontend/backend sau khi chốt API contract, docs/code/QA cùng bám một SSOT.

## 6. File Organization

- 1 feature = 1 file trong `phase2-features/`
- Templates: `.claude/doc-framework/`
- REQ-ID: `REQ-[DEPT]-[NNN]` hoặc `REQ-[SYSTEM]-[MODULE]-[NNN]`

## 7. Monorepo Projects

```text
apps/
├── backend/         -> API server
├── frontend/        -> Web app
└── mobile/          -> Mobile app
packages/            -> Shared code (types, utils, ui-components)
```

Mỗi app có README.md riêng. Shared code trong `packages/`.
