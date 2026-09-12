# Hoa hồng Sales L1–L5 & chỉ tiêu doanh số (Quota) — BCERP (BC Agency)

> **Loại tài liệu:** Phase 0 — Business Policy
> **Lĩnh vực:** Bán hàng / Nhân sự / Tài chính
> **Ngày soạn:** 11/09/2026
> **Agent soạn thảo:** sales-expert
> **Trạng thái:** Draft → Đã xác nhận
>
> READS: `P0-01-brainstorm.md` (Section 5.2 — trạng thái chính sách), `docs/00-overview/00-company-context.md`
> USED BY: `phase2-features/` (business rules), `phase3-architecture/` (rule engine design), policies: `bang-gia-chiet-khau-gross-margin.md`, `phan-loai-khach-hang-tier.md`

---

## 1. Phạm Vi Áp Dụng

- **Áp dụng cho:** toàn bộ đội Sales cấp **L1–L5** (L1 Sales Junior → L5 GDKD-level closer) và các khoản credit hỗ trợ của TPKD/SM; mọi deal dịch vụ của BC Agency phát sinh doanh thu từ khách hàng.
- **Không áp dụng cho:** hoa hồng/bonus của AM, CS, Planner (theo chính sách nhân sự từng khối); thưởng dự án nội bộ.
- **Effective từ:** *(chờ user xác nhận)*

---

## 2. Nội Dung Chính Sách

### 2.1. Nguyên tắc ghi nhận credit

- Credit hoa hồng tính theo **thanh toán thực nhận** (tiền khách đã về tài khoản BC, đối chiếu sổ AR) — **không tính theo ngày ký hợp đồng**.
- Chỉ deal được **ghi nhận trên PMS trước Gate 2 (LEAD)** mới đủ điều kiện hưởng hoa hồng — nguyên tắc "Không ghi nhận vào PMS = Không tồn tại". Deal nhập sau Gate 2 hoặc quản lý ngoài PMS không được tính credit.
- Deal bị khách hủy, hoàn tiền, hoặc nợ xấu → kích hoạt clawback (mục 2.3).

### 2.2. Bảng hoa hồng theo cấp L1–L5 (mức khởi tạo — user xác nhận)

| Cấp | Vai trò | % hoa hồng cơ bản (trên doanh thu thực nhận) |
|-----|---------|---------------------------------------------|
| L1 | Sales Junior | 2,5% |
| L2 | Sales | 3,5% |
| L3 | Senior Sales | 4,5% |
| L4 | TPKD / Team Lead | 5,5% khoản cá nhân + 0,5% doanh thu đội |
| L5 | GDKD / Senior closer | 6,5% khoản cá nhân + 0,5% doanh thu phòng |

**Hệ số attainment theo quý:** ≥ 100% ×1,2; 80–99% ×1,0; 70–79% ×0,9; < 70% ×0,8 — áp trên tổng credit kỳ của từng cá nhân.

### 2.3. Clawback

- Khách hủy/hoàn phí: hoàn hồi hoa hồng theo tỷ lệ tiền hoàn trên tổng tiền (hoàn 100% thì clawback 100%).
- Nợ quá hạn > 90 ngày (aging AR): clawback 100% phần chưa thu được.
- Clawback trừ vào kỳ tính hoa hồng kế tiếp (hoặc khấu trừ theo quy định lao động), luôn kèm tham chiếu hóa đơn/phiếu thu/số dư công nợ.

### 2.4. Split credit khi TNKD/TPKD hỗ trợ

- Mặc định: **chủ deal 70% – người hỗ trợ 30%** khi đóng góp được ghi nhận trước Gate 2 (giới thiệu lead, thu thập Brief, tham gia đàm phán).
- SM/TPKD hỗ trợ pre-sale: tối đa 20% credit của deal; tổng mọi khoản split **không vượt 100%**.
- Split phải ghi trên PMS **trước Gate 2**; sau Gate 2 không chấp nhận bổ sung split.

### 2.5. Quy tắc phân xử deal trùng

- Hệ thống anti-duplicate (MST/số điện thoại/domain/email) tự flag deal trùng.
- Thứ tự ưu tiên: (1) người **ghi nhận trên PMS trước** và có bằng chứng hoạt động (email, call log, meeting log); (2) hòa — SM phân xử, SLA 24h; (3) khiếu nại — **GDKD quyết định cuối cùng**, ghi audit log.

### 2.6. Quota theo cấp và pipeline coverage (mức khởi tạo — user xác nhận)

| Cấp | Quota doanh số thực nhận / quý |
|-----|-------------------------------|
| L1 | 600 triệu |
| L2 | 1,2 tỷ |
| L3 | 2,0 tỷ |
| L4 | 3,0 tỷ (cá nhân) / 6,0 tỷ (đội) |
| L5 | 5,0 tỷ (phòng) |

- **Pipeline coverage ≥ 3× quota kỳ kế tiếp** là điều kiện trạng thái "on-track"; < 2× cảnh báo đỏ và bắt buộc kế hoạch bổ sung lead (SM chịu trách nhiệm).
- Attainment tính **tự động** từ PMS: doanh thu thực nhận kỳ / quota; cấm nhập tay kết quả attainment.

---

## 3. Ngoại Lệ & Trường Hợp Đặc Biệt

- Hợp đồng chiến lược dài hạn (> 12 tháng, doanh thu ghi nhận nhiều kỳ): credit chia theo từng kỳ thực nhận tương ứng.
- Khách BOD-sponsored hoặc ký gói group nội bộ: GDKD chỉ định người hưởng credit bằng văn bản trước Gate 2.
- Deal bị trả về từ Gate 2 (Handoff fail): tạm dừng tính credit đến khi handoff thành công lại; không quy trách nhiệm credit cho AM.
- Nghỉ ốm/thai sản/thay đổi vị trí giữa kỳ: quota tính theo tỷ lệ ngày làm việc thực tế, GDKD duyệt.

---

## 4. Quy Trình Phê Duyệt

| Tình huống | Người phê duyệt | Thời hạn |
|-----------|----------------|---------|
| Phân xử deal trùng (hòa) | SM | SLA 24h |
| Khiếu nại kết quả phân xử | GDKD (quyết định cuối) | SLA 3 ngày làm việc |
| Clawback phát sinh | Finance xác nhận số liệu + GDKD duyệt | SLA 3 ngày làm việc kể từ khi aging > 90 ngày |
| Split credit ngoài mặc định | SM (ghi trên PMS) | Trước Gate 2 |
| Điều chỉnh quota giữa kỳ | GDKD + BOD | SLA 5 ngày làm việc |

---

## 5. Yêu Cầu Hệ Thống Phải Thực Thi

| Yêu cầu | Loại | Module liên quan | Ưu tiên |
|---------|------|-----------------|---------|
| Chặn ghi credit cho deal không có bản ghi PMS trước Gate 2 | Validation | Commission & Quota / CRM | MUST |
| Tự động tính credit theo ngày thanh toán thực nhận (đối chiếu AR), không theo ngày ký | Validation | Commission & Quota / Finance | MUST |
| Tự tạo dòng clawback khi hủy/hoàn tiền/nợ quá hạn > 90 ngày; trừ vào kỳ kế tiếp | Validation | Commission & Quota / Finance | MUST |
| Anti-duplicate flag theo MST/số điện thoại/domain/email khi tạo deal | Validation | CRM & Lead Pipeline V6.0 | MUST |
| Chặn bổ sung split credit sau Gate 2; chặn tổng split vượt 100% | Validation | Commission & Quota | MUST |
| Audit log toàn bộ credit, split, phân xử trùng, clawback (ai, khi nào, lý do, dẫn chiếu chứng từ) | Audit Trail | Commission & Quota | MUST |
| Khóa kỳ hoa hồng sau khi chốt; mở khóa sau chốt phải có phê duyệt và ghi log | Audit Trail | Commission & Quota / Finance | MUST |
| Alert coverage < 2× quota (đỏ) và < 3× (vàng) tới SM + GDKD theo tuần | Notification | Commission & Quota / Dashboard | MUST |
| Thông báo attainment đạt 100% và hệ số booster cho cá nhân + SM | Notification | Commission & Quota | SHOULD |
| Báo cáo tháng: credit theo nhân sự, clawback, aging ảnh hưởng hoa hồng | Reporting | Dashboard GDKD / Finance | SHOULD |
| Dashboard coverage + attainment realtime theo cấp L1–L5 | Reporting | Dashboard GDKD | SHOULD |
| Dự báo chi phí hoa hồng kỳ tới phục vụ P&L dự án | Reporting | Dashboard BOD | NICE |

**Cross-policy dependencies:** `bang-gia-chiet-khau-gross-margin.md` (doanh thu tính hoa hồng chỉ đếm trên quotation đã duyệt GM hợp lệ); `phan-loai-khach-hang-tier.md` (deal phải có qualifiedTier hợp lệ); Pipeline V6.0 Gate 1/Gate 2 trong P0-01 (điểm neo thời điểm ghi credit); khối Finance — AR/đối soát (nguồn sự thật thanh toán thực nhận, immutable log).

---

## 6. Xác Nhận

| Nội dung | Xác nhận | Điều chỉnh cần thiết |
|---------|---------|---------------------|
| Phạm vi áp dụng | Đúng / Cần sửa | |
| Nội dung chính sách | Đúng / Cần sửa | |
| Ngoại lệ | Đúng / Cần sửa | |
| Quy trình phê duyệt | Đúng / Cần sửa | |
| Yêu cầu hệ thống | Đúng / Cần sửa | |

**Người xác nhận:** [Tên] — [Vai trò]
**Ngày:** [Ngày/Tháng/Năm]

---

## Lịch Sử Phiên Bản

| Phiên bản | Ngày | Người cập nhật | Thay đổi |
|-----------|------|----------------|---------|
| 1.0 | 11/09/2026 | sales-expert | Khởi tạo |
