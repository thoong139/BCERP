# Tính Năng: Commission & Quota — Hoa hồng theo thực nhận, clawback, coverage ≥3× (Mobile Nội Bộ)

> **Dựa trên:** REQ-SALES-009 trong `phase1-business/departments/sales/sales.md` (Phần A Mục 3.9, Phần B Mục B.9)
> **Phân hệ:** Mobile Nội Bộ — BCERP Internal App (SYS-MOBILE-INTERNAL)
> **Module:** Commission & Quota (MOD-COMMISSION-QUOTA)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `phase0-brainstorm/policies/hoa-hong-sales-quota.md`, `documents/03_Quy_che_KPI_HR.md`, `work/wf-analyze-requirements/deferred-issues.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/sys-mobile-internal/mod-commission-quota/*.md`, `phase5-implementation/tasks/sys-mobile-internal/mod-commission-quota/feat-mbi-comm-001-impl.md`

> **Hướng dẫn ID:** REQ-SALES-009 fan-out ra 3 systems; bản Mobile Nội Bộ mang ID quy ước lane **FEAT-MBI-COMM-001**; counterparts cùng REQ-ID nằm ở lane SYS-CORE-BACKEND và SYS-BCERP-WEB.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-COMM-001 |
| Module | MOD-COMMISSION-QUOTA |
| Yêu cầu nghiệp vụ | REQ-SALES-009 (Commission & Quota — hoa hồng theo thực nhận, clawback, coverage ≥3×) |
| Người dùng liên quan | SALES_L1 (Sales Junior), SALES_L2 (Sales), SALES_L3 (TNKD), SALES_L4 (TPKD/SM — KXN-14), SALES_L5 (GDKD) |

> **Chú thích phân biệt (P4 — KXN-14):** `SALES_L3` là vai TNKD (trưởng nhóm kinh doanh) theo `sales.md`; chức danh **SM** ánh xạ **SALES_L4 (TPKD)** — người ký/duyệt các mốc gate theo KXN-14, không còn gắn với SALES_L3.
| Độ ưu tiên | Trung bình |
| Giai đoạn | Phase3 (GĐ3 — điều kiện nền: AR thực nhận của Finance GĐ2 + pipeline coverage từ PMS GĐ1) |
| Phụ thuộc | Không có phụ thuộc chéo FEAT-ID trong lane này; khi triển khai cần credit engine và khóa kỳ đã chạy ở SYS-CORE-BACKEND, sổ AR của FIN cấp được thanh toán thực nhận |
| Ghi chú Expert (A7) | sales-expert review 12/09/2026 — `sales.md` B.9: chốt BR-SALES-901→904 (credit thực nhận đối chiếu AR, clawback >90 ngày, split 70/30 ≤100%, quota/coverage ≥3×) và nguyên tắc "CORE engine — WEB dashboard — MOBILE cảnh báo push". DI-006: không dùng OPS_CX/FIN_COMPL (compliance clawback → FIN_L2 + BOD oversight) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa hoa hồng theo thực nhận, clawback, quota và pipeline coverage ≥3× đến đội ngũ Sales L1–L5 ngay trên điện thoại, để mỗi người biết thu nhập, khoản trừ và khoảng cách tới quota mà không chờ báo cáo cuối tháng. Trên touchpoint mobile nội bộ (React Native, offline-capable), tính năng là kênh **xem read-only + cảnh báo push + duyệt-on-the-go có MFA step-up**; mọi phép tính credit/clawback/attainment do SYS-CORE-BACKEND thực hiện ở service layer, mobile chỉ hiển thị kết quả nguồn sự thật.

**Phạm vi:**
- Bao gồm:
  - "Hoa hồng của tôi": credit theo thanh toán thực nhận trong kỳ, breakdown theo deal, phần split nhận được, hệ số attainment quý.
  - "Clawback": dòng hồi hoa hồng đã duyệt/sắp phát sinh, lý do (khách hủy, hoàn phí, nợ quá hạn >90 ngày), dẫn chiếu hóa đơn/phiếu thu/công nợ, số thực lĩnh sau trừ.
  - "Quota & Coverage của tôi": quota quý theo cấp, attainment tự động, coverage trên quota kỳ kế tiếp, trạng thái on-track/vàng/đỏ.
  - Push notification: alert coverage vàng (<3×)/đỏ (<2×) hàng tuần tới SM + GDKD; thông báo attainment ≥100% kèm booster ×1,2.
  - Duyệt-on-the-go cho SALES_L5: duyệt/từ chối dòng clawback đã được FIN xác nhận, qua MFA step-up TOTP gắn device, ghi audit log bất biến phía CORE.
  - Offline-capable: xem snapshot kỳ đã sync gần nhất kèm nhãn thời điểm dữ liệu.
- Không bao gồm:
  - Engine tính credit, clawback, split, khóa kỳ, attainment — thuộc SYS-CORE-BACKEND (BR enforce ở service layer); mobile không có form nhập attainment (BR-SALES-904).
  - Dashboard phân tích đầy đủ, phân xử deal trùng, điều chỉnh quota giữa kỳ, báo cáo chi phí hoa hồng cho P&L — thuộc SYS-BCERP-WEB.
  - Cấu hình thang hoa hồng/quota theo cấp (commission tier, salary policy) — thuộc HR/Settings phía CORE; mobile chỉ đọc.
  - Chi tiết lương cứng của người khác ngoài phạm vi cấp bậc — mobile là kênh PII Restricted, không thay thế bảng lương HR.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | SALES_L1 / SALES_L2 | Xem hoa hồng thực nhận của chính mình theo tháng/quý, breakdown theo deal và phần split nhận được | Hiểu thu nhập theo tiền khách đã thanh toán (không theo ngày ký), đôn đốc thu đúng deal của mình |
| 2 | SALES_L1 / SALES_L2 | Thấy các dòng clawback sắp bị trừ kèm lý do và chứng từ dẫn chiếu | Hiểu vì sao hoa hồng kỳ tới bị trừ, không phải hỏi lại kế toán, tránh tranh chấp cuối kỳ |
| 3 | SALES_L4 (TPKD/SM — KXN-14) | Nhận push alert hàng tuần khi coverage nhóm xuống vàng (<3×) hoặc đỏ (<2×) so với quota kỳ kế tiếp | Kịp lập kế hoạch bổ sung lead — coverage đỏ thì SM chịu trách nhiệm |
| 4 | SALES_L4 (TPKD) | Xem bản rút gọn: attainment cá nhân + đội, hoa hồng đội, cảnh báo coverage của thành viên | Đi công tác vẫn theo dõi nhịp kinh doanh của đội không cần mở dashboard web |
| 5 | SALES_L5 (GDKD) | Duyệt/từ chối dòng clawback do FIN xác nhận số liệu ngay trên điện thoại, qua MFA step-up TOTP gắn device | Không để clawback treo quá SLA 3 ngày làm việc kể từ aging vượt 90 ngày khi tôi vắng mặt |
| 6 | Mọi cấp SALES_L1–L5 | Khi không có mạng vẫn xem snapshot hoa hồng/quota lần sync gần nhất kèm nhãn thời điểm dữ liệu | Ra quyết định trên số liệu cũ có kiểm soát, biết rõ đó chưa phải dữ liệu thời gian thực |

*Lưu ý touchpoint: mobile nội bộ không dùng cho nhập liệu hàng loạt (`sales.md` B.0) — không có user story nào tạo/sửa deal, quotation hay nhập attainment trên app.*---

## 3. Quy Tắc Nghiệp Vụ

> *Quy tắc bắt buộc — developer xử lý đúng trong code. BR-SALES-901→904 kế thừa `sales.md` B.9 và policy `hoa-hong-sales-quota.md`; BR-SALES-905→909 bổ sung cho mobile. Engine enforce ở service layer CORE; mobile enforce hiển thị/hành vi app.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-SALES-901 | Credit tính theo **thanh toán thực nhận** đối chiếu sổ AR (FIN nguồn sự thật), không theo ngày ký; chỉ deal có bản ghi PMS trước Gate 2 + qualifiedTier hợp lệ + quotation đã duyệt GM mới hưởng; doanh thu chỉ đếm phí dịch vụ/markup, không đếm pass-through NSQC. Mobile read-only, ghi rõ nguồn "đối chiếu AR ngày...". | Credit deal vi phạm bị ẩn kèm trạng thái "không đủ điều kiện hưởng"; mọi ghi dữ liệu credit từ client bị API từ chối |
| BR-SALES-902 | Clawback: khách hủy/hoàn phí → hồi hoa hồng theo tỷ lệ tiền hoàn; nợ quá hạn >90 ngày (aging AR) → clawback 100% phần chưa thu; trừ vào kỳ kế tiếp; FIN xác nhận + GDKD duyệt trong SLA 3 ngày làm việc kể từ khi aging vượt 90; luôn dẫn chiếu hóa đơn/phiếu thu/công nợ. Mobile hiển thị trạng thái từng dòng (chờ FIN xác nhận / chờ GDKD duyệt / đã duyệt / đã từ chối) và đếm ngược SLA. | Không duyệt được khi thiếu chứng từ; quá SLA → push escalation; mobile chặn duyệt khi offline |
| BR-SALES-903 | Split credit: chủ deal 70% – người hỗ trợ 30%; SM/TPKD hỗ trợ pre-sale tối đa 20%; tổng split ≤100%; ghi trước Gate 2, sau Gate 2 chặn bổ sung cứng. Mobile chỉ hiển thị breakdown split, không thao tác tạo/sửa. | Ghi/sửa split từ client bị API CORE từ chối; split tổng vượt 100% (dòng lỗi từ engine) → cảnh báo + push alert SYS_ADMIN |
| BR-SALES-904 | Quota theo cấp/quý — mức khởi tạo đã chốt theo policy (DI-001 resolved 12/09): L1 600 triệu; L2 1,2 tỷ; L3 2,0 tỷ; L4 3,0 tỷ cá nhân / 6,0 tỷ đội; L5 5,0 tỷ/phòng. Coverage ≥3× quota kỳ kế tiếp = on-track; <2× = đỏ, bắt buộc kế hoạch bổ sung lead (SM chịu trách nhiệm). Attainment tự động (thực nhận kỳ / quota), hệ số quý ≥100% ×1,2; 80–99% ×1,0; 70–79% ×0,9; <70% ×0,8 — cấm nhập tay; mobile không render input nào. | Dữ liệu attainment/quota gửi tay bị API từ chối + audit log; app gắn nhãn "tự động từ PMS+AR" |
| BR-SALES-905 | Mobile là kênh **PII Restricted**: L1–L3 chỉ xem của chính mình; L4 xem tổng hợp đội (không lương cứng chi tiết thành viên); L5 xem tổng hợp phòng. Dữ liệu hoa hồng/lương là PII nhạy cảm — app mask khi ở background, mở lại yêu cầu sinh trắc/PIN local. | Truy cập ngoài phạm vi bị chặn cả UI lẫn API (chặn 2 tầng); không cấp xem chi tiết lương người khác |
| BR-SALES-906 | Offline-capable có kiểm soát: snapshot đã sync gần nhất hiển thị kèm nhãn thời điểm, chỉ tải trong phạm vi được phép; mọi hành động ghi (duyệt clawback) yêu cầu online. | Offline → nút duyệt vô hiệu; dữ liệu cũ >24h có cảnh báo vàng "dữ liệu có thể đã thay đổi" |
| BR-SALES-907 | Duyệt giá trị cao trên mobile (duyệt clawback) yêu cầu **MFA step-up TOTP với token gắn device** theo `P0-02 §2.4`; thiết bị mới/mất device phải đăng ký lại và vô hiệu token cũ; toàn bộ duyệt ghi audit log bất biến phía CORE (ai, khi nào, nội dung, thiết bị). | Thiếu MFA → API từ chối; token không khớp device → buộc đăng ký lại |
| BR-SALES-908 | Trạng thái kỳ hiển thị trung thực: kỳ **đã khóa** = số liệu cuối; kỳ **đang mở** = số tạm tính; mở khóa sau chốt chỉ ở CORE/WEB qua phê duyệt + log, mobile chỉ phản ánh sau sync. | Mobile không có thao tác khóa/mở kỳ; snapshot chứa kỳ mở khóa thiếu log phê duyệt → cảnh báo + alert SYS_ADMIN |
| BR-SALES-909 | Thang hoa hồng theo vị trí nạp từ commission tier đã cấu hình phía CORE (nguồn `documents/03_Quy_che_KPI_HR.md` §6 — `CHÍNH_SÁCH_LƯƠNG_2026.xlsx`, sheet Sale / Leader Sale / TPKD: bậc Level 01–12 theo khoảng doanh thu thuần, % hoa hồng, lương cứng; kèm điều kiện ON/OFF lương doanh thu theo % KPI trung bình nhiều tháng). Mobile hiển thị theo bảng cấu hình tại thời điểm phát sinh, không hardcode % trong app. | Không có hằng số hoa hồng trong code; cấu hình đổi thì kỳ cũ hiển thị theo version policy đúng thời điểm (trace theo version) |

---

## 4. Phân Quyền

> *Chỉ dùng 18 vai registry (không OPS_CX/FIN_COMPL — DI-006). Trên mobile, FIN_L2/BOD không có màn hình chuyên dụng — tác vụ của họ ở WEB/CORE.*

| Hành động (trên Mobile Nội Bộ) | SALES_L1 | SALES_L2 | SALES_L3 (TNKD) | SALES_L4 (TPKD/SM) | SALES_L5 (GDKD) | SYS_ADMIN |
|--------------------------------|:--------:|:--------:|:-------------:|:---------------:|:---------------:|:---------:|
| Xem hoa hồng của chính mình (thực nhận + clawback + split nhận) | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Xem quota/attainment/coverage của chính mình | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Xem tổng hợp hoa hồng/quota của nhóm/đội | ❌ | ❌ | ✅ (nhóm) | ✅ (đội) | ❌ (dùng view phòng) | ❌ |
| Xem tổng hợp hoa hồng/quota của phòng | ❌ | ❌ | ❌ | ❌ | ✅ (phòng) | ❌ |
| Nhận push alert coverage vàng/đỏ hàng tuần | ❌ | ❌ | ✅ | ✅ (cc đội) | ✅ | ❌ |
| Nhận thông báo attainment ≥100% + booster | ✅ (cá nhân) | ✅ (cá nhân) | ✅ (nhóm) | ✅ (đội) | ✅ (phòng) | ❌ |
| Duyệt/Từ chối dòng clawback (MFA step-up) | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Xác nhận số liệu clawback (FIN_L2) / oversight (BOD) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (WEB/CORE) |
| Tạo/sửa split, nhập attainment, điều chỉnh quota, khóa/mở kỳ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (WEB/CORE) |
| Đăng ký/quản lý token MFA của chính mình | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |

*Ghi chú: FIN_L2 xác nhận số liệu clawback và BOD oversight (DI-006) nằm ở WEB/CORE — không tạo màn hình tương đương trên mobile, giữ nguyên tắc "mobile = cảnh báo + duyệt tuyến kinh doanh". SYS_ADMIN không xem hoa hồng cá nhân trên mobile; chỉ nhận alert kỹ thuật (dữ liệu lỗi, sync bất thường).*

---

## 5. Trường Hợp Đặc Biệt

- **Nghỉ ốm/thai sản/chuyển vị trí giữa kỳ:** quota tính lại theo tỷ lệ ngày làm việc sau khi GDKD duyệt (WEB/CORE); mobile hiển thị quota đã điều chỉnh kèm lịch sử; đang chờ duyệt thì hiển thị quota gốc + huy hiệu "có đề xuất đang chờ".
- **Hợp đồng dài hạn >12 tháng:** credit chia theo từng kỳ thực nhận; mobile hiển thị lịch credit theo kỳ, để sale hiểu vì sao tháng này chưa thấy tiền deal lớn.
- **Deal bị trả về từ Gate 2 (Handoff fail):** credit tạm dừng đến khi handoff lại thành công; dòng credit hiển thị "tạm dừng" + lý do, không cộng attainment kỳ đang mở đến khi CORE kích hoạt lại.
- **Thiết bị mất/mua mới:** token MFA gắn device cũ bị vô hiệu, đăng ký lại trên thiết bị mới; snapshot cục bộ chứa PII Restricted được remote wipe.
- **Mất kết nối kéo dài (>24h):** vẫn xem được snapshot nhưng cảnh báo dữ liệu cũ ở mọi màn hình; alert tuần không tính "đã nhận" cho SLA cho đến khi online và đồng bộ.
- **Nhân viên nghỉ việc:** tài khoản mobile vô hiệu ngay tại ngày nghỉ; lịch sử hoa hồng/clawback nằm ở CORE để xử lý clawback phát sinh sau (truy cập qua WEB bởi GDKD/FIN, không qua mobile).
- **Dòng clawback bị GDKD từ chối:** trả về FIN xử lý lại trên WEB/CORE; mobile hiển thị "đã từ chối — chờ FIN xử lý", dòng vẫn trong đếm SLA đến khi có quyết định cuối.

*Giả định mở còn lại (không tự quyết, theo dõi tại `documents/quy-trinh-lam-viec/10 §4`): quy trình HR làm nền cho dữ liệu quota/hoa hồng theo vị trí còn mở `[KXN-18]`; Ma trận RACI phê duyệt (GDKD/FIN/BOD trong luồng clawback, điều chỉnh quota) chưa xác nhận `[KXN-19]` — hiện GDKD là người duyệt theo policy, rà lại khi RACI chốt; nếu mốc cảnh báo sớm non-payment 15/30 ngày `[KXN-22]` được duyệt, mobile thêm bậc cảnh báo trước clawback 90 ngày.*

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Kỳ hoa hồng (Commission Period) — mobile hiển thị trạng thái (khóa/mở kỳ do CORE quản lý, mobile read-only).

**Sơ đồ trạng thái:**
```
[OPEN] ──(chốt kỳ: GDKD xác nhận sau đối chiếu AR)──► [LOCKED]
   ▲                                                   │
   │      (mở khóa: GDKD + BOD duyệt, log WORM)        │
   └────────────────── (re-lock) ──────────────────────┘
Dòng clawback trong kỳ: [PENDING] → (GDKD duyệt) → [APPLIED] / (từ chối) → [REJECTED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `OPEN` | Chốt kỳ | `LOCKED` | CORE (lịch chốt) + GDKD xác nhận | Credit/clawback kỳ đã đối chiếu AR; attainment đã tính tự động |
| `LOCKED` | Mở khóa | `OPEN` (reopened) | GDKD + BOD phê duyệt (WEB/CORE) | Nhập lý do + audit log bất biến; mobile phản ánh sau sync |
| `LOCKED` | Áp clawback | `CLAWBACK_APPLIED` (trên dòng) | FIN xác nhận + GDKD duyệt | Đủ dẫn chiếu hóa đơn/phiếu thu/công nợ; trừ kỳ kế tiếp |
| `LOCKED` | Từ chối clawback | `CLAWBACK_REJECTED` (trên dòng) | GDKD | Nhập lý do; dòng trả về FIN xử lý lại |
| `OPEN` (reopened) | Chốt lại | `LOCKED` | CORE + GDKD xác nhận | Điều chỉnh đã tính lại; kỳ mang version mới, payroll liên quan đối chiếu lại |

**Quy tắc:**
- Mobile không phát sinh chuyển trạng thái — mọi transition do CORE thực thi; app chỉ render trạng thái + timestamp từ sync.
- `LOCKED` không tuyệt đối: mở khóa phải qua phê duyệt + log; chốt lại thì kỳ mang version mới để đối chiếu payroll.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL tại `database-design.md` (Phase 3). Đây là entity phía CORE mà mobile đọc qua API; mobile chỉ có cache snapshot.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `commission_period` | `id`, `year`, `quarter`, `status` (OPEN/LOCKED), `locked_by`, `version` | 1 kỳ → N credit, N clawback | Khóa/mở kỳ có audit log WORM; mobile read-only |
| `commission_credit` | `id`, `period_id`, `deal_id`, `user_id`, `realized_amount`, `rate`, `commission_amount`, `split_share`, `ar_ref`, `state` (ACTIVE/SUSPENDED) | FK → period, deal, user | Theo thanh toán thực nhận; deal trả về Gate 2 → `SUSPENDED` |
| `commission_clawback` | `id`, `period_id`, `user_id`, `reason` (CANCEL/REFUND/AR_OVERDUE_90), `amount`, `doc_refs`, `fin_confirmed_by`, `gdkd_status`, `sla_due_at` | FK → period, user | SLA 3 ngày làm việc kể từ aging >90; trừ kỳ kế tiếp |
| `quota_target` | `id`, `user_id`, `period_id`, `role_level` (L1–L5), `amount`, `adjusted_amount`, `adjust_reason`, `approved_by` | FK → user, period | Khởi tạo theo policy (L1 600tr → L5 5 tỷ/phòng); điều chỉnh GDKD duyệt, prorate ngày làm việc |
| `attainment_snapshot` | `id`, `user_id`, `period_id`, `realized_total`, `attainment_pct`, `multiplier` (1,2/1,0/0,9/0,8), `computed_at` | FK → user, period | Tự động, cấm nhập tay; nguồn hiển thị mobile |
| `coverage_status` | `id`, `owner_id`, `scope` (SELF/TEAM/DEPT), `next_period_quota`, `coverage_ratio`, `band` (ON_TRACK/YELLOW<3×/RED<2×) | FK → user | Nguồn alert tuần push tới SM + GDKD |
| `mobile_push_alert` | `id`, `user_id`, `type` (COVERAGE_WEEKLY/ATTAINMENT_BOOSTER/CLAWBACK_SLA), `payload`, `sent_at`, `acked_at` | FK → user | Lưu vết đã gửi/đã nhận phục vụ SLA và audit |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết điền ở Phase 5; dưới đây là phác thảo sơ bộ Phase 2.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Sale xem hoa hồng của chính mình | SALES_L2 đăng nhập, có credit thực nhận kỳ hiện tại | Mở "Hoa hồng của tôi" | Đúng số từ CORE, breakdown deal + split; không thấy dữ liệu người khác | [ ] |
| SC-002: Clawback quá hạn 90 ngày | Dòng AR quá hạn >90 ngày, FIN đã xác nhận | GDKD nhận push, mở dòng clawback | Đủ lý do + chứng từ + đếm SLA; duyệt qua MFA step-up; sau duyệt trừ kỳ kế tiếp | [ ] |
| SC-003: Alert coverage đỏ | Coverage nhóm SM xuống <2× quota kỳ kế tiếp | Hệ thống chạy alert tuần | SM + GDKD nhận push đỏ kèm "bắt buộc kế hoạch bổ sung lead"; phản ánh ở màn hình quota | [ ] |
| SC-004: Xem offline | App đã sync snapshot, thiết bị mất mạng | Mở app | Xem snapshot kèm nhãn thời điểm; nút duyệt vô hiệu kèm thông báo cần mạng | [ ] |
| SC-005: Chặn vượt phạm vi PII | SALES_L1 đăng nhập | Gọi API xem hoa hồng SALES_L2 khác | API CORE từ chối + audit log; app không hiển thị dữ liệu ngoài phạm vi | [ ] |
| SC-006: Attainment chạm booster | Cá nhân attainment ≥100% | Engine tính lại attainment | Cá nhân + SM/GDKD nhận thông báo hệ số ×1,2; không có input tay trên app | [ ] |

> **Liên kết:** cả 6 scenario map vào REQ-SALES-009 (credit thực nhận; clawback >90 ngày; coverage ≥3× alert vàng/đỏ + booster attainment; mobile offline-capable; PII Restricted; attainment tự động).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` (phần MOD-COMMISSION-QUOTA) |
| API Endpoints | `technical-specs/api-contract.md` (endpoint read-only commission/quota, push token, MFA step-up) |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (luồng AR từ Finance → credit engine CORE → snapshot mobile; fan-out 3 systems của REQ-SALES-009) |
| Màn hình UI | `phase4-ux/sys-mobile-internal/mod-commission-quota/` (Hoa hồng của tôi, Clawback, Quota & Coverage, Notifications) |
| Policy nguồn (thang hoa hồng, quota, clawback, split, phân xử) | `phase0-brainstorm/policies/hoa-hong-sales-quota.md` |
| Domain chi tiết theo vị trí (salary/KPI/commission tier, sheet Sale/Leader Sale/TPKD) | `documents/03_Quy_che_KPI_HR.md` §6 (CHÍNH_SÁCH_LƯƠNG_2026), §5 (salary band), §9 (đề xuất entity TMS) |
| Business rules nguồn | `phase1-business/departments/sales/sales.md` B.0, B.9 |
| Vấn đề deferred đã resolve/còn mở | `work/wf-analyze-requirements/deferred-issues.md` (DI-001, DI-004, DI-006; KXN-18/19/22) |
| Ghi chú P4: SM ánh xạ SALES_L4 theo KXN-14 (đồng bộ stakeholder review 12/09) | `phase1-business/stakeholder-review.md` (F.5 — Quyết định 12/09/2026) |
