# BỘ TÀI LIỆU MÔ TẢ DỊCH VỤ — BC VIỆT NAM (BC-DICH-VU)

> **Phiên bản:** v1.0 | **Ngày:** 13/09/2026 | **Trạng thái:** ĐÃ KIỂM TRA — dùng nội bộ
> **Nguồn gốc:** xây dựng lại từ bộ tài liệu vận hành tại [`documents/BC-VANHANH/`](../BC-VANHANH/) (9 tài liệu, thời điểm 9/2026).

---

## 1. Mục đích

Bộ tài liệu này trích lọc và hệ thống hóa **toàn bộ dịch vụ BC Việt Nam cung cấp cho khách hàng** thành một cấu trúc thống nhất, mọi thông tin đều có **trích dẫn nguồn theo số dòng** để đối chiếu kiểm chứng được: mô hình kinh doanh, danh mục dịch vụ, bảng giá, chính sách bán hàng, đối tượng khách hàng, cơ cấu tổ chức & chính sách nhân sự, và hệ thống SLA/cam kết dịch vụ.

## 2. Cấu trúc bộ tài liệu (10 file)

| File | Nội dung | Trả lời yêu cầu |
|---|---|---|
| [`01-mo-hinh-kinh-doanh.md`](01-mo-hinh-kinh-doanh.md) | Pháp nhân, định vị, chuyển dịch mô hình, dòng doanh thu, rủi ro | Yêu cầu 1 — hiểu mô hình kinh doanh |
| [`02-danh-muc-dich-vu.md`](02-danh-muc-dich-vu.md) | Catalog 7 gói dịch vụ + 5 USP: mô tả, phạm vi, đối tượng | Yêu cầu 2a — các loại dịch vụ |
| [`03-bang-gia-dich-vu.md`](03-bang-gia-dich-vu.md) | Bảng giá tổng hợp chung + chi tiết từng gói/tier + điều kiện | Yêu cầu 2b — bảng giá chung & theo gói |
| [`04-chinh-sach-ban-hang.md`](04-chinh-sach-ban-hang.md) | Quy trình bán, sàng lọc KH, thanh toán, hợp đồng, chiết khấu, hoàn tiền, hoa hồng | Yêu cầu 2c — chính sách bán hàng |
| [`05-doi-tuong-khach-hang.md`](05-doi-tuong-khach-hang.md) | Phân khúc, ICP, chân dung theo gói, tiêu chí từ chối | Yêu cầu 2d — đối tượng khách hàng |
| [`06-co-cau-to-chuc-nhan-su.md`](06-co-cau-to-chuc-nhan-su.md) | Org chart 3 giai đoạn, mô hình phục vụ KH, lương, thưởng, KPI, đào tạo | Yêu cầu 2e — cơ cấu tổ chức & nhân sự |
| [`07-sla-cam-ket-dich-vu.md`](07-sla-cam-ket-dich-vu.md) | ⭐ Hệ thống SLA đầy đủ: P0–P3, phản hồi theo gói, khiếu nại, vận hành, báo cáo, onboarding, cam kết hiệu quả, bảo hành | Yêu cầu 2e — SLA (trọng điểm) |
| [`08-phu-luc-mau-thuan-va-khoang-trong.md`](08-phu-luc-mau-thuan-va-khoang-trong.md) | 11 mâu thuẫn nguồn + quyết định xử lý; 18 khoảng trống thông tin; claims cần evidence pack | Yêu cầu 3 — đảm bảo logic & căn cứ |
| [`09-bao-cao-kiem-tra.md`](09-bao-cao-kiem-tra.md) | Phương pháp & kết quả kiểm chứng 3 lớp (52/53 PASS ban đầu, 5 phát hiện đã sửa) | Yêu cầu 4 — check & verify |

## 3. Nguồn & thứ tự ưu tiên khi mâu thuẫn

| Thứ tự | Viết tắt | File nguồn | Dùng cho |
|---|---|---|---|
| 1 | TH | `BC_Vietnam_Tong_Hop.md` (v2.0 — bản mới nhất đã hiệu chỉnh sau kiểm chứng) | Tên gói, thành phần, giá, đối tượng, KPI |
| 2 | SK | `BC_P4_Sales_Kit.md` | Chính sách bán, điều khoản thanh toán, BANT |
| 3 | P2 | `BC_P2_SOP_Chi_Tiet.md` | SLA vận hành, quy trình nghiệp vụ |
| 4 | P3 | `BC_P3_Tuyen_Dung_Nhan_Su.md` | Tổ chức, lương, KPI nhân sự |
| 5 | P1 | `BC_P1_Templates_Van_Hanh.md` | Checklist, bảng estimate nội bộ |
| 6 | CT | `BC_Vietnam_He_Thong_Cong_Cu_Van_Hanh.md` | Công cụ, hệ thống báo cáo |
| 7 | CL | `BC_Vietnam_Chien_Luoc_Marketing.md` | Chỉ tham chiếu (bản cũ, nhiều claim đã bị bác) |
| — | KC | `BC_Vietnam_Kiem_Chung_Thuc_Te.md` | Căn cứ xử lý mâu thuẫn + disclaimer |

**Quy ước trích dẫn:** `[VIẾT TẮT:dòng]` hoặc `[VIẾT TẮT:dòng-dòng]`, ví dụ `[TH:306]` = file Tổng Hợp, dòng 306.

**Không sử dụng trong bộ này:** `BC_Unit_Economics_Model.xlsx` + `build_model.py` (model tài chính nội bộ — ngoài phạm vi mô tả dịch vụ).

## 4. Những lưu ý quan trọng khi sử dụng

1. **Mọi mức giá là khung giá tham khảo, chưa VAT**, chốt theo từng khách sau brief/audit — không dùng như bảng giá niêm yết.
2. **Các mâu thuẫn nguồn** (ví dụ: sản lượng SEO offer vs SOP; SLA community 12h/7 ngày vs giờ hành chính; onboarding 5–7 ngày vs 3–4 tuần) đã được xử lý theo quy tắc ưu tiên và ghi công khai tại file 08 — **các quyết định này chờ Ban Giám đốc phê duyệt** trước khi dùng đối ngoại.
3. **Claims quy mô** (2.600+ tài khoản, 1.000+ khách hàng, 8+ năm, đối tác TikTok) cần evidence pack trước khi đưa vào tài liệu khách hàng.
4. Mức lương trong file 06 là **tham chiếu nội bộ bảo mật** — không đưa vào tài liệu hướng ra khách hàng.
5. Trích dẫn dòng gắn với phiên bản nguồn ngày 13/09/2026; nguồn thay đổi thì đối chiếu lại (quy trình tại file 09 mục 5).

## 5. Quy trình duy trì

- Cập nhật nguồn ở `documents/BC-VANHANH/` → cập nhật file tương ứng trong bộ này kèm trích dẫn mới → chạy lại kiểm tra theo quy trình tại [`09-bao-cao-kiem-tra.md`](09-bao-cao-kiem-tra.md) mục 5 → tăng phiên bản bộ.
- Bản rút gọn hướng khách hàng (catalog + bảng giá + SLA) nên xuất phát từ bộ này sau khi các mục "chờ BGĐ chốt" được giải quyết.

---

*BC VIỆT NAM — The Performance-First Growth Agency. Bộ BC-DICH-VU v1.0 | 13/09/2026 | Đã kiểm chứng 3 lớp (chi tiết: file 09).*
