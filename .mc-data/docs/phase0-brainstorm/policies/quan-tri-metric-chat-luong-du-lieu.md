# Quản Trị Metric & Chất Lượng/Freshness Dữ Liệu — BCERP

> **Loại tài liệu:** Phase 0 — Business Policy
> **Lĩnh vực:** Dữ liệu / Tài chính / Vận hành (cross-functional)
> **Ngày soạn:** 11/09/2026
> **Agent soạn thảo:** data-expert
> **Trạng thái:** Draft → Đã xác nhận
>
> READS: `P0-01-brainstorm.md` (Section 5.2 — trạng thái chính sách), `docs/00-overview/00-company-context.md`
> USED BY: `phase2-features/` (business rules — định nghĩa metric, freshness SLA), `phase3-architecture/` (rule engine, data pipeline, alerting), policy Kế toán & Báo cáo, policy Quản lý ví quảng cáo

---

## 1. Phạm Vi Áp Dụng

- **Áp dụng cho:** Toàn bộ chỉ số (metric) và báo cáo hiển thị trên dashboard nội bộ (BOD, PM, Finance) và Client Portal của BCERP — gồm ROAS, chi tiêu quảng cáo 7 nền tảng, Gross Margin, P&L realtime, On-time Delivery, SLA Attainment, timesheet, số dư ví quảng cáo. Áp dụng mọi nhân sự khai báo metric, nhập liệu, xây dựng hoặc sử dụng báo cáo.
- **Không áp dụng cho:** Số liệu phân tích ad-hoc cá nhân không công bố; dữ liệu thô phục vụ debug kỹ thuật chưa đưa lên dashboard.
- **Effective từ:** Ngày Go-live module BI/Dashboard; dashboard tồn tại trước đó phải đăng ký lại vào Metric Catalog trong 30 ngày.

---

## 2. Nội Dung Chính Sách

### 2.1. Metric Catalog — Định nghĩa duy nhất

Mọi metric trên dashboard nội bộ hoặc Client Portal BẮT BUỘC được khai báo trong Metric Catalog trước khi sử dụng, với đủ 4 thuộc tính: **tên** (chuẩn hóa, không trùng ngữ nghĩa), **công thức** (ví dụ: `P&L Realtime = Doanh thu DV − (Σ Giờ × Cost/Level + Outsource + Tools)`), **nguồn dữ liệu** (API 7 nền tảng Meta/Google/TikTok/Bing/X/Pinterest/Yandex, timesheet, sổ kế toán, ví quảng cáo), **owner** (một cá nhân chịu trách nhiệm).

- **Một định nghĩa duy nhất** dùng chung dashboard nội bộ và Client Portal — cấm 2 công thức cùng tên metric song song tồn tại.
- Metric client-facing (ROAS, chi tiêu) và nội bộ (Gross Margin, P&L, On-time Delivery, SLA Attainment) đều thuộc catalog, gắn nhãn phạm vi hiển thị.
- Thay đổi định nghĩa metric: chỉ **CFO** phê duyệt; hệ thống ghi **lịch sử hiệu lực** (định nghĩa cũ/mới, ngày hiệu lực, người duyệt); báo cáo hiển thị theo đúng định nghĩa có hiệu lực tại thời điểm dữ liệu.

### 2.2. Freshness SLA theo nguồn dữ liệu

| Nguồn dữ liệu | SLA freshness | Ghi chú |
|---|---|---|
| Chi tiêu quảng cáo (7 nền tảng) | ≤ 1 giờ (khi có API) | Hiện chưa có quyền API → degraded mode |
| Timesheet | Chốt hằng ngày (23:59) | Sau mốc này đóng kỳ nhập |
| Số dư ví quảng cáo | ≤ 15 phút sau giao dịch | Trừ trực tiếp khi ghi nhận giao dịch |
| P&L realtime | Tính lại ≤ 15 phút sau thay đổi đầu vào | Công thức theo Metric Catalog |

### 2.3. Degraded mode (nhập tay) & Backfill

- Giai đoạn chưa có quyền API: chi tiêu quảng cáo **nhập tay**, hệ thống gắn nhãn nguồn **"manual"** bắt buộc trên mọi điểm dữ liệu và hiển thị nhãn trên dashboard.
- Khi API được cấp: hệ thống **tự động backfill** dữ liệu manual bằng dữ liệu API cho cùng kỳ, chuyển nguồn thành "api", lưu vết lịch sử thay thế. Chênh lệch manual vs API vượt ±0,1% phải nằm trong báo cáo đối soát.

### 2.4. Data quality test tự động

Mọi nguồn cấp dashboard chạy bộ test định kỳ: **not-null** (trường bắt buộc không rỗng), **uniqueness** (khóa nghiệp vụ không trùng: mã giao dịch, dòng timesheet), **đối soát số dư** ví trên BCERP vs sổ kế toán trong dung sai **±0,1%**, đối soát tổng chi nhập tay vs chứng từ nguồn khi ở degraded mode. Kết quả fail phải tạo incident và block publish số liệu liên quan trong báo cáo chính thức.

### 2.5. Chỉ báo cập nhật & Alert

- Mọi dashboard hiển thị chỉ báo **"Dữ liệu cập nhật lúc: [timestamp + nguồn api/manual]"** ở mức dashboard và từng widget.
- Alert tự động khi: dữ liệu stale quá SLA (2.2), quality test fail, đối soát lệch quá ±0,1%.
- Stale vượt ngưỡng nghiêm trọng (chi tiêu QC > 8 giờ, số dư ví > 2 giờ, timesheet > 24 giờ) → **cảnh báo đỏ tới BOD**.

### 2.6. Runbook xử lý sự cố dữ liệu

1. **Phân loại mức:** M1 (thẩm mỹ, không ảnh hưởng quyết định), M2 (sai lệch ảnh hưởng báo cáo nội bộ), M3 (sai lệch số liệu đã gửi khách/BOD hoặc ví lệch kế toán).
2. **Xử lý & backfill có ghi nhận:** mọi chỉnh sửa ghi log ai sửa, giá trị trước/sau, lý do — cấm sửa đè không vết.
3. **Báo cáo nguyên nhân:** M2 trong 24 giờ (gửi CFO), M3 trong 4 giờ (gửi BOD) — kèm nguyên nhân gốc + biện pháp phòng ngừa.

### 2.7. Vòng đời ban hành báo cáo

Yêu cầu báo cáo → **KPI sign-off** (owner xác nhận KPI + định nghĩa) → Build → **QA số liệu ±0,1%** đối chiếu nguồn → **CFO duyệt publish** → **Theo dõi usage** (ai xem, tần suất) → báo cáo không có usage sau 90 ngày đưa vào review để nghỉ hưu (retire).

---

## 3. Ngoại Lệ & Trường Hợp Đặc Biệt

- **Nền tảng quảng cáo không cấp API:** tiếp tục degraded mode "manual", không được tắt nhãn; minh chứng (screenshot/statement) lưu kèm từng kỳ nhập.
- **API lỗi tạm thời (outage, rate limit):** giữ phiên dữ liệu hợp lệ cuối, dashboard hiển thị "stale" + timestamp, không nội suy số ẩn.
- **Khách yêu cầu định nghĩa riêng** (VD: ROAS theo attribution khác): cho phép trong phạm vi báo cáo của khách, nhưng phải đăng ký biến thể trong catalog với tên phân biệt, không ghi đè định nghĩa chuẩn.
- **Điều chỉnh số liệu quá khứ phục vụ kiểm toán:** qua quy trình backfill có ghi nhận (2.6), CFO phê duyệt.

---

## 4. Quy Trình Phê Duyệt

| Tình huống | Người phê duyệt | Thời hạn |
|-----------|----------------|---------|
| Khai báo metric mới vào catalog | CFO (owner đề xuất) | 2 ngày làm việc |
| Thay đổi định nghĩa metric hiện hữu | CFO | 2 ngày làm việc |
| Publish báo cáo mới (sau QA ±0,1%) | CFO | 3 ngày làm việc |
| Backfill/điều chỉnh dữ liệu đã công bố (M2) | CFO | 1 ngày làm việc |
| Điều chỉnh sự cố M3 / cảnh báo đỏ | BOD | 4 giờ |
| Thay đổi ngưỡng SLA freshness | CFO + data-expert review | 5 ngày làm việc |

---

## 5. Yêu Cầu Hệ Thống Phải Thực Thi

| Yêu cầu | Loại | Module liên quan | Ưu tiên |
|---------|------|-----------------|---------|
| Metric Catalog CRUD (tên, công thức, nguồn, owner); block dashboard dùng metric chưa đăng ký | Validation | BI/Dashboard | MUST |
| Versioning + audit trail lịch sử hiệu lực định nghĩa metric, duyệt change bằng CFO | Audit Trail | BI/Dashboard | MUST |
| Gắn nhãn nguồn "manual"/"api" trên mọi điểm dữ liệu chi tiêu QC, hiển thị trên dashboard | Validation | Ads Integration | MUST |
| Backfill tự động manual → API khi có quyền, log chênh lệch so ngưỡng ±0,1% | Integration | Ads Integration | MUST |
| Scheduler freshness theo SLA (QC ≤1h, timesheet hằng ngày, ví ≤15 phút) + ghi timestamp cập nhật | Automation | Data Pipeline | MUST |
| Quality test tự động: not-null, uniqueness, đối soát ví vs kế toán ±0,1% | Validation | Data Pipeline | MUST |
| Chỉ báo "Dữ liệu cập nhật lúc [timestamp + nguồn]" trên mọi dashboard/widget | UI | BI/Dashboard, Client Portal | MUST |
| Alert stale/fail theo mức; cảnh báo đỏ BOD khi vượt ngưỡng nghiêm trọng | Notification | Data Pipeline | MUST |
| Runbook incident: log backfill (ai, trước/sau, lý do), workflow báo cáo nguyên nhân M2/M3 | Audit Trail | Data Pipeline, Workflow | MUST |
| Block publish báo cáo chính thức khi quality test đang fail | Validation | BI/Dashboard | MUST |
| Workflow vòng đời báo cáo: yêu cầu → KPI sign-off → build → QA → CFO publish → usage tracking | Workflow | BI/Dashboard | SHOULD |
| Usage analytics dashboard (lượt xem, người xem, báo cáo không dùng 90 ngày) | Reporting | BI/Dashboard | NICE |

**Cross-policy dependencies:** Phụ thuộc **Kế toán & Báo cáo** (định nghĩa đối soát ví vs sổ kế toán, công thức Gross Margin/P&L dùng chung); **Quản lý ví quảng cáo** (luồng giao dịch, mốc 15 phút); **Timesheet & Chấm công** (quy tắc chốt 23:59 hằng ngày); **Phân quyền & Bảo mật dữ liệu** (quyền sửa metric CFO-only, quyền publish); **SLA khách hàng** (On-time Delivery và SLA Attainment dùng định nghĩa từ catalog này).

---

## 6. Xác Nhận

| Nội dung | Xác nhận | Điều chỉnh cần thiết |
|---------|---------|---------------------|
| Phạm vi áp dụng | Đúng / Cần sửa | |
| Nội dung chính sách | Đúng / Cần sửa | |
| Ngoại lệ | Đúng / Cần sửa | |
| Quy trình phê duyệt | Đúng / Cần sửa | |
| Yêu cầu hệ thống | Đúng / Cần sửa | |

**Người xác nhận:** [Tên] — [Vai trò: CFO/CEO BC Agency]
**Ngày:** [Ngày/Tháng/Năm]

---

## Lịch Sử Phiên Bản

| Phiên bản | Ngày | Người cập nhật | Thay đổi |
|-----------|------|----------------|---------|
| 1.0 | 11/09/2026 | data-expert | Khởi tạo |
