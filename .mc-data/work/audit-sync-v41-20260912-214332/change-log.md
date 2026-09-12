# Change Log — audit-sync-v41-20260912-214332

## Change #1 (V2 — FIXED)

- **File:** `.mc-data/docs/phase0-brainstorm/policies/stage-gate-lifecycle-v6.md` (dòng 9)
- **Loại:** Broken reference trong metadata `READS:`
- **Trước:** `` `00-company-context.md` (bối cảnh BC Agency) `` — path không resolve được từ bất kỳ base chuẩn nào
- **Sau:** `` `docs/00-overview/00-company-context.md` (bối cảnh BC Agency) `` — đúng quy ước mà 4 policy khác (aml-kyc, doi-soat-cong-no, quan-ly-cap-phat, bang-gia) đang dùng
- **Backup:** `backup/.mc-data/docs/phase0-brainstorm/policies/stage-gate-lifecycle-v6.md`
- **Phương pháp:** backup `cp -p` → sửa bằng node (read → replace → ghi `.tmp` → `renameSync` = write-then-rename atomic)
- **Validate sau sửa:** `check-refs2.js` → `REAL_BROKEN: 0` (trước: 1); grep xác nhận dòng 9 đã có prefix đầy đủ
- **Lệnh:** xem session log; script hỗ trợ: `check-refs.js`, `check-refs2.js` (trong thư mục audit này)

## Kết quả tham chiếu V2 (sau fix)

| Phân loại | Số lượng | Diễn giải |
|---|---|---|
| RESOLVED | 167 | Path tồn tại khi resolve theo base chuẩn (repo root / `.mc-data/docs/` / phase dirs / dirname + dirname-of-dirname) |
| PLACEHOLDER | 7 | Pattern template `[dept]/[dept].md`, `[sys]/[mod]/[feat].md` — theo thiết kế DEVKIT, không phải path thật |
| FUTURE_PHASE | 22 | Forward ref tới `phase3-architecture/`, `phase4-`, `stakeholder-review.md` (phase0 output tùy chọn), `phase2-features/...` — phase chưa/không sinh output, đúng thiết kế |
| REAL_BROKEN | 0 | (trước fix: 1 — đã xử lý ở Change #1) |
