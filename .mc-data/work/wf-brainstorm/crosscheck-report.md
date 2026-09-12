# Crosscheck Report — Phase 0 Brainstorm BCERP (Protocol 8)

**Ngày:** 2026-09-11
**Runner:** node check-phase4.js (contract-driven, `_contract.json` loaded OK)
**Kết quả chung:** **PASS — 0 lỗi blocking**

## 1. Structural Check

| File | Tồn tại | Bytes |
|------|---------|-------|
| `.mc-data/docs/phase0-brainstorm/P0-01-brainstorm.md` | ✓ | (đủ 6 sections + metadata) |
| `.mc-data/docs/phase0-brainstorm/P0-02-systems-users.md` | ✓ | (đủ 4 sections + metadata) |

## 2. Contract-Driven Section Check

- **P0-01:** 6/6 required sections khớp startswith (`## 1. Thông Tin Cơ Bản` → `## 6. Chốt Khung Dự Án`), mọi section có nội dung thực (≥2 dòng). Metadata READS + USED BY: có.
- **P0-02:** 4/4 required sections khớp (`## 1. Bản Đồ Hệ Thống` → `## 4. Tech Stack Đề Xuất`), nội dung thực. Metadata READS + USED BY: có.

## 3. Policy Files (20/20)

| Kiểm tra | Kết quả |
|----------|---------|
| Số file trong `policies/` | 20/20 — không thiếu, không thừa (stray = 0) |
| 6 required sections mỗi file | 20/20 PASS |
| Metadata READS/USED BY mỗi file | 20/20 PASS |
| Dung lượng | 8.2KB – 12.5KB/file (không có file rỗng/placeholder) |
| Ghi đúng path | Có — không có file nào nhầm trong `.mc-data/work/wf-brainstorm/policies/` (thư mục không tồn tại) |

## 4. Cross-Document Verification

| # | Kiểm tra | Kết quả |
|---|----------|---------|
| 4 | Policy file count khớp P0-01 §5.3 | ✓ 20 = 20 |
| 5 | Policy filename mapping (kebab-case không dấu) | ✓ 20/20 filename trong P0-01 §5.3 tồn tại trong `policies/` |
| 6 | Systems consistency registry ↔ P0-01 §4 ↔ P0-02 §1 | ⏭ Registry not yet seeded — ERP/Client Portal/Mobile nhất quán giữa P0-01 ↔ P0-02; verify vs registry lại ở **Phase 5 Step 5.3b** |
| 7 | Departments consistency registry ↔ P0-01 §2 | ⏭ Như trên — 5 phòng ban (BOD, HR, Tài chính-Kế toán, Kinh doanh, Vận hành) có đủ trong P0-01 §2 |
| 8 | Cross-policy thresholds nhất quán | ✓ Spot-check: ngưỡng chiết khấu NVKD ≤5% / TPKD 10–15% / GDKD >15% nhất quán P0-01 §5.2 ↔ policy `bang-gia-chiet-khau-gross-margin.md` ↔ P0-02 §2.3; quy ước tier A=thấp nhất/E=tốt nhất được policy `sla-khach-hang.md` tham chiếu chéo đúng sang `phan-loai-khach-hang-tier.md`; SoD 4 vai nhất quán P0-02 §2.3 ↔ `kiem-soat-vi-tkqc-giao-dich-tien.md` ↔ `han-muc-chi-giai-ngan-sod.md` |

## 5. Lỗi phát hiện & xử lý

- Không có lỗi blocking. Không cần re-run agent nào.
- Ghi chú (không chặn): (a) `stakeholder-review.md` không tạo ở Phase 0 theo thiết kế skill; (b) các điểm `[Cần làm rõ]` (tên phần mềm kế toán, PMS cũ, ngưỡng duyệt VND cụ thể, định mức nền giờ/cost-rate/SLA) đã được ghi dấu tường minh trong P0-01/P0-02/policies để Phase 1 làm rõ; (c) policy files để Section 6 (Xác Nhận) ở trạng thái Draft chờ chủ dự án xác nhận — đúng quy trình.

**Verdict: PASS — handoff sang Phase 5 (seed registry) sẵn sàng.**

## 6. Phụ lục — Về script `phase0-cross-check.sh` (SKILL.md Utility Scripts)

Đã chạy `bash .claude/scripts/phase0-cross-check.sh .mc-data` sau khi hoàn tất Phase 0. Script báo ERROR nhưng **đã xác nhận là false positive do script hard-code cho dự án mẫu cũ (Eureka XNK & Thương Mại)**, không phải lỗi của BCERP:

| Báo cáo của script | Nguyên nhân | Kết luận |
|---|---|---|
| `stakeholder-review.md MISSING` | Script yêu cầu file này ở Phase 0 — nhưng phase4 procedure hiện hành ghi rõ: "Phase 0 KHÔNG tạo stakeholder-review.md — file đó chỉ xuất hiện từ Phase 1 trở đi" | Theo skill hiện tại: KHÔNG tạo — đúng thiết kế |
| `Policy files: 0 matches P0-01 index (0)` | Script chỉ đếm file `cs-*.md` và grep dòng tổng kết "kết theo mức" — định dạng của dự án Eureka; wf-brainstorm hiện hành quy định tên kebab-case không dấu và kiểm count qua Protocol 8 contract-driven | Đã verify bằng Protocol 8: 20/20 file ↔ 20/20 tham chiếu §5.3 |
| CHECK 3 dừng sớm, không ra summary | `set -euo pipefail` + `grep -oE 'CS-[A-Z]+-[0-9]{3}'` không khớp dòng nào (P0-01 BCERP không dùng ID dạng CS-XXX-NNN) → exit 1 dừng script | Đặc thù Eureka, không áp dụng cho BCERP |

Validation chính thức áp dụng cho wf-brainstorm hiện hành là **Protocol 8 contract-driven** (`_contract.json` + `check-phase4.js`) — **PASS 0 lỗi** — cùng POST-GATE Phase 5 (10/10 PASS) và Phase 6 (8/8 PASS).
