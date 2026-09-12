# BỘ TÀI LIỆU QUY TRÌNH LÀM VIỆC BC AGENCY (Bản tái dựng)

**Mã tài liệu:** `README.md`
**Phiên bản:** 1.1 — ngày 12/09/2026 (bản 1.0 giờ chiều; cập nhật buổi tối theo quyết định chủ dự án — xem mục 5)
**Phạm vi:** Mô tả lại toàn bộ vòng đời dự án của BC Agency, phân bố công việc giữa các bộ phận, điểm gate/phê duyệt, SLA và các hằng số quy trình.
**Trạng thái:** Bản tái dựng từ nguồn sơ bộ — mọi điểm chưa được doanh nghiệp xác nhận đều gắn thẻ `[KXN-n]` và tập hợp tại tài liệu 10.

---

## 1. Nguồn và phương pháp tái dựng

Bộ tài liệu này được xây dựng lại từ 3 nguồn hiện có của doanh nghiệp:

| # | Nguồn | Nội dung | Vai trò trong bản tái dựng |
|---|-------|----------|---------------------------|
| 1 | `../BC_Agency_Project_Lifecycle (1).html` — **Project Lifecycle v2.3** | Flowchart tương tác: 33 stage chính + 39 sub-protocol ONGOING (72 entry dữ liệu, mỗi entry có 5W1H, Input/Output, Done criteria, SLA, Risk/Escalation, module PMS) | **Khung xương sống (chuẩn)** — nguồn đầy đủ nhất, phủ cả giai đoạn Triển khai |
| 2 | `../01_Quy_trinh_MKT_Tong_the.md` — **Lifecycle V6.0** | Chi tiết Sales Phase (AUTO SCORING K1–K12, trọng số CQ, Handoff Package 5 nhóm) + Operations & Proposal Phase (Brand Safety 7 tiêu chí, Weighted Scoring ≥3.5). Bị cắt cụt tại header GIAI ĐOẠN 3 | **Nguồn bổ sung** cho chi tiết Sales Phase — chèn có chú thích nguồn ở các điểm giàu thông tin hơn v2.3 |
| 3 | `../05_Co_cau_To_chuc_Va_Triet_ly_He_thong.md` | Cơ cấu tổ chức 4 khối (BOD, Back Office, Sales 5 cấp, Vận hành 6 mã vai), triết lý thiết kế ERP | **Nguồn chuẩn** cho cấu trúc tổ chức và mã vai trò |

Nguyên tắc hợp nhất (đã duyệt với chủ dự án):
1. **v2.3 là chuẩn trình tự** — số stage, thứ tự, D+ timeline, ONGOING 3 nhánh theo v2.3.
2. **Chi tiết V6.0 chèn ở nơi giàu hơn** — các cơ chế chấm điểm, knockout rules, handoff checklist của V6.0 được đưa vào làm chi tiết bổ sung, ghi rõ `[V6.0]`.
3. **Mọi mâu thuẫn không tự quyết** — chỗ hai nguồn khác nhau, bản tái dựng theo v2.3 nhưng đặt thẻ `[KXN-n]` (Khoản chờ Xác Nhận) và liệt kê đầy đủ trong tài liệu 10.

## 2. Danh mục tài liệu

| File | Nội dung | Đọc cho ai |
|------|----------|-----------|
| [01_Tong_quan_vong_doi_du_an.md](01_Tong_quan_vong_doi_du_an.md) | Vòng đời tổng thể 5 giai đoạn, sơ đồ end-to-end, nguyên tắc vận hành, D+ timeline, mô hình Tier | Mọi người — đọc đầu tiên |
| [02_Giai_doan_1_Sales.md](02_Giai_doan_1_Sales.md) | Giai đoạn 1 Sales: RAW DATA → QUALIFIED + BYPASS + LOST Management | Sales, SM |
| [03_Giai_doan_2_Danh_gia_va_De_xuat.md](03_Giai_doan_2_Danh_gia_va_De_xuat.md) | Giai đoạn 2 Đánh giá & Đề xuất: EVALUATION → WON (Proposal, Rehearsal, Pitching, Quotation, Negotiation) | BPVH (AM, Planner, AD), Accountant |
| [04_Giai_doan_3_Trien_khai_Deploy.md](04_Giai_doan_3_Trien_khai_Deploy.md) | Giai đoạn 3 Triển khai: thu thập tài nguyên ∥ chờ tiền → D+0 → Kick-off ×3 → D+5 | BPVH, Accountant |
| [05_Giai_doan_4_Van_hanh_ONGOING.md](05_Giai_doan_4_Van_hanh_ONGOING.md) | Giai đoạn 4 Vận hành: 3 nhánh EXECUTING / OPTIMIZING / REPORTING + 39 sub-protocol | Toàn bộ team vận hành |
| [06_Giai_doan_5_Ket_thuc_Closed_Renew.md](06_Giai_doan_5_Ket_thuc_Closed_Renew.md) | Giai đoạn 5 Kết thúc: Upsell, Wrap-up, Survey, Final Report, Offboarding, Retro, CLOSED/RENEW, PAUSED | AM, SE, AD |
| [07_Co_cau_To_chuc_va_Phan_cong_Cong_viec.md](07_Co_cau_To_chuc_va_Phan_cong_Cong_viec.md) | Cơ cấu tổ chức, định danh vai trò, phân công công việc theo bộ phận | Quản lý, HR |
| [08_Ma_tran_RACI_Gate_SLA.md](08_Ma_tran_RACI_Gate_SLA.md) | Ma trận RACI stage × vai trò, danh sách gate phê duyệt, bảng SLA tổng hợp | Quản lý, PMS |
| [09_Phu_luc_Hang_so_Quy_trinh.md](09_Phu_luc_Hang_so_Quy_trinh.md) | Phụ lục hằng số: tiêu chí chấm, ngưỡng tối ưu, công thức, checklist QC | Team chuyên môn |
| [10_Danh_gia_Doi_chieu_Nguon_va_Khoan_Can_Xac_nhan.md](10_Danh_gia_Doi_chieu_Nguon_va_Khoan_Can_Xac_nhan.md) | **Tài liệu đánh giá**: đối chiếu 3 nguồn, phân tích mâu thuẫn, danh sách khoản cần chủ dự án/khách hàng xác nhận | Chủ dự án |

## 3. Quy ước đọc

- **Hard Gate:** điều kiện chuyển giai đoạn bắt buộc 100% thỏa mãn — không nhảy bước. Nguyên tắc nền tảng: *"Không ghi nhận vào PMS = Không tồn tại"* `[V6.0]`.
- **D+n:** ngày thứ n kể từ ngày tiền vào tài khoản (D+0 = ngày Accountant xác nhận tiền). D+0 là **điều kiện duy nhất** kích hoạt timeline triển khai.
- **Observe mode:** nguyên tắc 2 chiều — Sales Phase: Sales thực thi, Vận hành theo dõi; từ WON: Vận hành thực thi, Sales theo dõi `[V6.0]`.
- **BPVH:** Bộ phận Vận hành — gọi tắt xuyên suốt (tương ứng "Phòng Vận Hành Dự Án & Marketing Nội Bộ" trong tài liệu 05).
- **SLA:** trình bày theo mẫu *Trigger → Thời hạn → Gia hạn*. Không có ghi chú gia hạn = không được gia hạn.
- **[KXN-n]:** khoản chờ xác nhận — nội dung chưa có nguồn chính thức hoặc hai nguồn mâu thuẫn; số `n` tra cứu ở tài liệu 10.
- **[V6.0]:** chi tiết lấy bổ sung từ tài liệu `01_Quy_trinh_MKT_Tong_the.md` (Lifecycle V6.0).

## 4. Rút gọn chức danh dùng trong bộ tài liệu

| Rút gọn | Đầy đủ | Mã vai (tài liệu 05) |
|---------|--------|----------------------|
| SE | Sales Executive | `SALES_L2` NVKD |
| SM | Sales Manager | `SALES_L4` TPKD |
| AM | Account Manager | `OPS_AM` |
| AD | Account Director | `OPS_AD` — mã vai mới (quyết định 12/09, chờ đồng bộ vào documents/05) |
| Planner | Strategic Planner | `OPS_PLAN` (kiêm Quyền Trưởng phòng Vận hành) |
| Media | Ads Specialist / Media Buyer | `OPS_ADS` |
| Content | Content Creator | `OPS_CONT` |
| Design | Designer | `OPS_DES` |
| Video | Editor / Cameraman | `OPS_EDIT` |
| KTT / Accountant | Kế toán (viên/trưởng) | `FIN_L1` / `FIN_L2` |
| KH | Khách hàng | — |

Định danh đầy đủ và các vai chưa ánh xạ được (Creative Lead, CS…) xem tại tài liệu 07 §3.

---

## 5. Lịch sử phiên bản

| Phiên bản | Ngày | Thay đổi |
|-----------|------|----------|
| 1.0 | 12/09/2026 (giờ chiều) | Bản tái dựng đầu tiên từ 3 nguồn (v2.3 + V6.0 + documents/05); 20 khoản `[KXN]` mở chờ xác nhận. |
| 1.1 | 12/09/2026 (buổi tối) | **Chủ dự án chốt 11 khoản KXN** (1, 2, 3, 4, 5, 8, 10, 11, 12, 13, 14 — nhật ký đầy đủ ở tài liệu 10 §8): mô hình tier chính thức **5 tier A–E** (V6.0), AUTO SCORING **trước** First Meeting, D+0 cần **LOI/HĐ đã ký**, định mức proposal theo chiều V6.0 (B/C = AM 8–12 trang ≤2 vòng; D/E = Planner 15–25 trang ≤4 vòng), Deploy v2.3 phê chuẩn chính thức, 4 Communication Rules còn lại có bản dự thảo duyệt nội bộ, AD có mã vai `OPS_AD`, Creative Lead = Lead Content, bỏ vai CS, SM = TPKD. Sửa 3 lỗi cross-ref (03 §2.3 → 10 §3.6; 04 §7 → 05 §4.2; 01/06 → mục UPSELL mới 06 §8). Bổ sung mục **UPSELL** (06 §8, từ entry `upsell` v2.3). Thêm 2 khoản mới `[KXN-21]`, `[KXN-22]` (audit độc lập). Còn mở: KXN-6, 7, 9, 15, 16, 17, 18, 19, 20, 21, 22. File 05 không đổi (giữ 1.0). |
