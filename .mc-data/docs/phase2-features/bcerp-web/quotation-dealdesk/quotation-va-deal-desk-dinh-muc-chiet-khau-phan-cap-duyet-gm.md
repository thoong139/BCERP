# Tính Năng: Quotation & Deal Desk — định mức, chiết khấu phân cấp, duyệt GM

> **Dựa trên:** REQ-SALES-006 trong `phase1-business/departments/sales/sales.md` (Phần A — Mục REQ-SALES-006; chi tiết chuyên môn tại Phần B, Mục B.6)
> **Phân hệ:** Sales — Quotation & Deal Desk (DEPT-SALES)
> **Module:** Quotation & Deal Desk — touchpoint SYS-BCERP-WEB (MOD-QUOTATION-DEALDESK)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `phase1-business/P1-02-business-workflow.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/quotation-dealdesk/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/quotation-dealdesk/FEAT-ERP-QDD-001-impl.md`

> **Fan-out note (multi-system):** REQ-SALES-006 xuất hiện ở 3 systems. File này là bản riêng cho **SYS-BCERP-WEB** — web nội bộ responsive (Next.js) cho nhân viên BC: form/list/workflow UI, gọi API core, hiển thị đúng trạng thái machine-state. Toàn bộ business rule được enforce ở service layer của SYS-CORE-BACKEND (counterpart của cùng REQ); WEB chỉ trình bày dữ liệu và gọi API, không tự tính/chặn ngoài API. Kênh duyệt push trên di động thuộc SYS-MOBILE-INTERNAL (Phase2) — không mô tả ở đây.

---

## Thông Tin Chung

Tính năng này là mặt làm việc chính trên web nội bộ để lập báo giá (quotation) cho khách hàng theo định mức version hiện hành, vận hành Deal Desk chiết khấu phân cấp và luồng duyệt GM. Mọi con số hiển thị đều trace về đúng version định mức hiệu lực tại thời điểm phát hành.

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-QDD-001 |
| Module | MOD-QUOTATION-DEALDESK (SYS-BCERP-WEB) |
| Yêu cầu nghiệp vụ | REQ-SALES-006 |
| Người dùng liên quan | SALES_L1 (Intern), SALES_L2 (NVKD), SALES_L3 (SM/TNKD), SALES_L4 (TPKD), SALES_L5 (GDKD — vị trí quy hoạch, tạm BOD kiêm nhiệm); phối hợp FIN_L1 (lập theo định mức), BOD_CEO (duyệt chiết khấu >20%) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP) |
| Phụ thuộc | Không có cross-dependency bắt buộc trong lane; nghiệp vụ đọc bảng định mức version hiệu lực từ SYS-CORE-BACKEND (phối hợp DEPT-FIN theo Luồng 1 B5 của P1-02). Tính năng hợp đồng/LOI/NDA là bước kế tiếp: FEAT-ERP-QDD-002 |
| Ghi chú Expert (A7) | sales.md có Mục A7 (khung đánh giá expert); nội dung điều chỉnh chuyên môn hiện nằm tại Phần B — Sales Expert Review 12/09/2026 (Mục B.0, B.6): hard gate thực thi 2 tầng UI + API; MOBILE là kênh duyệt chính từ Phase2 với MFA step-up + token gắn device; cấm tự duyệt deal do chính mình chốt; giá vốn/GM là dữ liệu Mật; vòng sửa theo tier D/E ≤2, B/C ≤4; định mức theo tier đã chốt theo V6.0 (`[KXN-8]` resolved 12/09) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cung cấp cho nhân viên BC giao diện soạn quotation tự tính Gross Margin (GM) từ định mức version hiện hành, điều phối duyệt chiết khấu phân cấp đúng ma trận và SLA, và kiểm soát vòng đời version — bảo đảm không có báo giá nào tới tay khách khi thiếu duyệt, sai định mức hoặc hết hiệu lực.

**Phạm vi:**
- Bao gồm:
  - Form soạn quotation trên web nội bộ: chọn deal từ pipeline, khai báo loại dịch vụ (RENTAL/MANAGED theo CMS Domain Model), cấu phần giá (giá media sau chiết khấu agency, định mức giờ L1–L5, phí nền tảng, dự phòng rủi ro), hệ thống tự bind về version định mức hiệu lực tại thời điểm phát hành và hiển thị `rateCardVersionId` traceable.
  - Hiển thị GM tự tính theo nhóm dịch vụ (agency ≥15%, ads ≥20%, SEO ≥35%, web/design ≥30%) với cảnh báo đỏ khi GM dưới ngưỡng; media pass-through có giá vốn 0 GM nhưng bắt buộc tính đủ phí dịch vụ.
  - Luồng Deal Desk chiết khấu phân cấp: hàng đợi duyệt theo ma trận ≤5% / >5–15% / >15–20% / >20%, hiển thị đồng hồ SLA (TPKD 8 giờ làm việc; GDKD 1 ngày làm việc kèm nhận định chiến lược; BOD 2 ngày làm việc, quyết bằng văn bản), cảnh báo escalate khi quá hạn.
  - Version control: bản gửi khách khóa vĩnh viễn read-only; sửa = version mới + duyệt lại; đếm vòng sửa theo tier khách (D/E ≤2, B/C ≤4) với cơ chế mở exception có lý do của GDKD.
  - Quản lý hiệu lực: đồng hồ 30 ngày (tối đa 60 cho hợp đồng năm/đa giai đoạn), tự chuyển "Hết hạn", nhắc gửi khách trong tối đa 2 ngày làm việc sau khi duyệt GM.
  - Nhật ký audit hiển thị: mọi version, người duyệt, quyết định, lý do chiết khấu, thời điểm gửi khách.
- Không bao gồm:
  - Engine tính GM, approval engine, version lock và audit log WORM — thực thi ở SYS-CORE-BACKEND; WEB chỉ gọi API và hiển thị trạng thái.
  - Duyệt chiết khấu/GM qua push di động với MFA step-up — thuộc SYS-MOBILE-INTERNAL (Phase2).
  - Soạn thảo hợp đồng/LOI/NDA, checklist Brand Safety và e-sign — thuộc FEAT-ERP-QDD-002.
  - Cấu hình bảng định mức, ngưỡng GM, tham số chiết khấu (effective-dated) — quản trị tại CORE bởi FIN/BOD, WEB chỉ đọc.
  - Nạp tiền/wallet/topup TKQC và hoa hồng — thuộc module CMS tương ứng và REQ-SALES-009.

---

## 2. Luồng Người Dùng (User Stories)

Các user story dưới đây đều diễn ra trên web nội bộ responsive; dữ liệu và validation trả về từ API của SYS-CORE-BACKEND, WEB phản ánh trung thực machine-state (kể cả trạng thái chờ duyệt, hết hạn, khóa).

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | SALES_L2 (NVKD) | Tạo quotation mới từ deal trong pipeline, chọn nhóm dịch vụ và hạng mục giá theo định mức hiện hành | Khách nhận báo giá đúng giá chuẩn, trace được về version định mức đã phát hành |
| 2 | SALES_L2 (NVKD) | Tự duyệt chiết khấu ≤5% ngay trên form khi GM vẫn đạt ngưỡng nhóm dịch vụ | Chốt deal nhỏ không phải chờ duyệt, không mất thời gian khách |
| 3 | SALES_L2 (NVKD) | Gửi yêu cầu duyệt chiết khấu >5% với lý do và được theo dõi SLA từng cấp | Deal lớn đi đúng thẩm quyền, minh bạch người duyệt và thời gian còn lại |
| 4 | SALES_L4 (TPKD) | Thấy hàng đợi chiết khấu >5–15% của phòng kèm đồng hồ SLA 8 giờ làm việc | Duyệt kịp hạn, không để deal treo quá SLA |
| 5 | SALES_L5 (GDKD) | Duyệt chiết khấu >15–20% và GM dưới ngưỡng (đến 20%) kèm nhận định chiến lược; mở exception vòng sửa/pilot có lý do | Kiểm soát biên lợi nhuận mà vẫn giữ linh hoạt cho deal chiến lược |
| 6 | BOD_CEO | Nhận yêu cầu duyệt chiết khấu >20% và quyết định bằng văn bản gắn trên hệ thống | Mọi chiết khấu vượt ngưỡng đều có chữ ký cấp cao nhất và audit log |
| 7 | FIN_L1 (Kế toán/Finances) | Lập quotation theo định mức version hiện hành thay cho NVKD khi được phối hợp | Báo giá bảo đảm đúng cấu trúc giá và GM chuẩn do FIN kiểm soát |
| 8 | SALES_L3 (SM) | Xem trạng thái quotation của nhóm, nhận cảnh báo khi bản đã duyệt GM chưa gửi trong 2 ngày làm việc | Đốc thúc thành viên gửi khách đúng hạn, không bỏ sót deal |
| 9 | SALES_L2 (NVKD) | Tạo version mới từ bản đã gửi khi khách yêu cầu chỉnh, thấy số vòng sửa còn lại theo tier | Kiểm soát đàm phán không vượt vòng sửa, vượt thì phải có exception GDKD |
| 10 | SALES_L1 (Intern) | Xem quotation gắn với deal được giao hỗ trợ | Nắm tình trạng báo giá để hỗ trợ Nuôi lead và chuẩn bị tài liệu |

---

## 3. Quy Tắc Nghiệp Vụ

Quy tắc dưới đây là bắt buộc; phía developer phải gọi đúng API của SYS-CORE-BACKEND để enforce, WEB vô hiệu hóa nút/khiến form không hợp lệ theo cùng điều kiện (chặn 2 tầng theo BR-SALES-000).

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-QDD-001 | Quotation phải trace về đúng version định mức hiệu lực tại thời điểm phát hành (giá media sau chiết khấu agency, định mức giờ L1–L5, phí nền tảng, dự phòng rủi ro); định mức theo tier khách hàng đã chốt theo mô hình 5 tier A–E V6.0 (`[KXN-8]` resolved 12/09, mức mặc định số liệu chốt theo DI-001) | API từ chối phát hành quotation không có `rateCardVersionId` hợp lệ; WEB hiển thị lỗi và chặn nút gửi duyệt |
| BR-QDD-002 | GM engine tính theo nhóm dịch vụ: agency ≥15%, ads ≥20%, SEO ≥35%, web/design ≥30%; GM dưới ngưỡng → cảnh báo đỏ; media pass-through giá vốn 0 GM nhưng phải tính đủ phí dịch vụ | WEB hiển thị cảnh báo đỏ và chỉ cho submit vào luồng duyệt GM (GDKD đến 20%, vượt 20% là BOD) |
| BR-QDD-003 | Ma trận chiết khấu phân cấp: NVKD ≤5% tự duyệt (GM đạt ngưỡng, tức thời); >5–15% TPKD SLA 8 giờ làm việc; >15–20% GDKD SLA 1 ngày làm việc kèm nhận định chiến lược; >20% BOD SLA 2 ngày làm việc, quyết bằng văn bản | Chưa đủ tầng duyệt tương ứng → chặn gửi khách ở cả UI và API; quá SLA escalate cấp trên + log |
| BR-QDD-004 | Cấm tự duyệt deal do chính mình chốt; người duyệt phải khác NVKD chủ deal; chữ ký gate không ủy thác hàng loạt | API từ chối request khi approver trùng chủ deal; WEB ẩn nút duyệt và ghi log hành vi |
| BR-QDD-005 | Bản gửi khách khóa vĩnh viễn read-only kèm log người gửi/thời điểm/nội dung; sửa = tạo version mới và duyệt lại toàn bộ | Mọi thao tác ghi trên bản đã gửi bị từ chối; chỉnh sửa chỉ cho phép qua version mới |
| BR-QDD-006 | Vòng sửa theo tier khách: D/E ≤2, B/C ≤4; vượt ngưỡng bị chặn, GDKD mở exception bắt buộc có lý do; biến động tỷ giá/phí nền tảng >5% tạo version điều chỉnh và không tính vào vòng sửa | Khi vượt vòng sửa, API từ chối version mới nếu chưa có exception; WEB hiển thị số vòng còn lại theo tier |
| BR-QDD-007 | Hiệu lực quotation 30 ngày (tối đa 60 cho hợp đồng năm/đa giai đoạn); hệ thống tự chuyển "Hết hạn"; tiếp tục bán phải re-quote theo định mức hiện hành | Quá hạn → chặn gửi khách; NVKD phải tạo quotation mới theo rate card mới |
| BR-QDD-008 | Sau khi duyệt GM, tối đa 2 ngày làm việc phải gửi khách; quá hạn cảnh báo SM + GDKD | WEB gửi cảnh báo cho SM và GDKD; log trễ gửi phục vụ rà soát quản trị |
| BR-QDD-009 | Cấm "chiết khấu ẩn": tặng giờ/tài nguyên không ghi giá không qua duyệt; giá vốn/GM là dữ liệu Mật — NVKD không xem giá vốn | Form không có trường tặng kèm không định giá; API không trả giá vốn cho vai không đủ quyền |
| BR-QDD-010 | Ngoại lệ có kiểm soát: pilot 1 tháng được GM dưới ngưỡng tối đa một kỳ và ≤60 ngày (GDKD duyệt kèm mục tiêu chuyển đổi); tái ký trong 12 tháng giữ bảng giá cũ tối đa 1 lần; khách BOD-sponsored ngoài ma trận phải có văn bản | Không có phê duyệt tương ứng → API chặn; WEB hiển thị trạng thái chờ phê duyệt đặc biệt |
| BR-QDD-011 | Mọi version, người duyệt, lý do chiết khấu, thời điểm gửi đều ghi audit log bất biến (WORM, hash-chain) ở CORE; xem log cũng bị log | Thiếu audit trail khi phát hành/duyệt → giao dịch không hợp lệ, bắt buộc xử lý sự cố kỹ thuật trước khi tiếp tục |
| BR-QDD-012 | Kết nối về hợp đồng: quotation APPROVED là điều kiện đầu vào để soạn hợp đồng/LOI (FEAT-ERP-QDD-002); `serviceType` khai trên quotation phải khớp hợp đồng sinh ra — 1 hợp đồng 1 `serviceType` bất biến (RENTAL/MANAGED), đổi dịch vụ = tất toán hợp đồng cũ + mở hợp đồng mới kèm quotation mới | API hợp đồng từ chối khi không tham chiếu quotation đã duyệt hoặc `serviceType` lệch; WEB hướng dẫn mở quotation mới |

---

## 4. Phân Quyền

Phân quyền quy về 18 vai registry; GDKD (SALES_L5) là vị trí quy hoạch tạm do BOD kiêm nhiệm — hệ thống duyệt theo mã vai nên tách vai sau này không phải redesign. Giá vốn/GM bị che với vai không đủ quyền ngay ở tầng API, WEB chỉ nhận trường được phép hiển thị.

| Hành động | SALES_L1 | SALES_L2 | SALES_L3 | SALES_L4 | SALES_L5 | FIN_L1 | BOD_CEO |
|-----------|----------|----------|----------|----------|----------|--------|---------|
| Xem quotation của deal mình được gán/hỗ trợ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Xem toàn bộ quotation nhóm/phòng/công ty | ❌ | ❌ | ✅ (nhóm) | ✅ (phòng) | ✅ (toàn bộ) | ✅ | ✅ |
| Soạn/tạo quotation theo định mức | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ (phối hợp) | ❌ |
| Tự duyệt chiết khấu ≤5% (GM đạt ngưỡng) | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Duyệt chiết khấu >5–15% | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Duyệt chiết khấu >15–20% + GM dưới ngưỡng (đến 20%) + exception vòng sửa/pilot | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Duyệt chiết khấu >20% + ngoài ma trận (BOD-sponsored) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Gửi khách (khóa bản gửi) | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Xem giá vốn và biên GM chi tiết | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Xem báo cáo GM tổng hợp theo phòng/quý | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Cấu hình định mức/ngưỡng GM/ma trận chiết khấu | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (FIN_L2/BOD làm tại CORE — WEB chỉ đọc) |

---

## 5. Trường Hợp Đặc Biệt

- **Pilot GM dưới ngưỡng:** deal pilot 1 tháng được chấp nhận GM dưới ngưỡng nhóm dịch vụ tối đa một kỳ và ≤60 ngày; GDKD duyệt kèm mục tiêu chuyển đổi bằng văn bản; WEB hiển thị nhãn "Pilot" + ngày hết hạn đặc biệt để theo dõi chuyển đổi.
- **Tái ký trong 12 tháng:** khách tái ký được giữ bảng giá cũ tối đa 1 lần; lần tái kế tiếp phải re-quote theo định mức hiện hành; WEB cảnh báo khi NVKD chọn "giữ bảng giá cũ" lần thứ hai.
- **Biến động tỷ giá/phí nền tảng >5%:** tạo version điều chỉnh không tính vào vòng sửa; WEB phải ghi rõ lý do version "FX/fee adjustment" để bộ đếm vòng sửa không tăng.
- **Hợp đồng năm/đa giai đoạn:** hiệu lực quotation tối đa 60 ngày thay vì 30; WEB cho phép chọn loại hiệu lực mở rộng kèm tham chiếu hợp đồng đa giai đoạn.
- **GDKD kiêm nhiệm BOD (hiện trạng tổ chức):** khi SALES_L5 và BOD_CEO là cùng người, deal vượt 20% phải chuyển BOD_CFO_CTO hoặc BOD_CEO khác duyệt để tránh tự duyệt deal của mình; WEB phát hiện trùng vai và điều hướng người duyệt thay thế.
- **Quotation cho RENTAL vs MANAGED:** phí RENTAL là 1–8% trên chi tiêu, MANAGED là 10–20% theo NSQC (CMS Domain Model); WEB phải tách cấu phần phí theo `serviceType` ngay từ lúc soạn để tránh quotation sai khung giá; đổi `serviceType` sau này buộc tất toán hợp đồng cũ và mở quotation — hợp đồng mới.
- **Đa tiền tệ:** khách toàn cầu có thể báo giá USD hoặc VND; version định mức bind theo currency của rate card, không quy đổi chéo tùy tiện; tỷ giá chỉ xuất hiện trong điều chỉnh >5% theo BR-QDD-006.
- **Intern soạn nháp:** SALES_L1 có thể chuẩn bị dữ liệu đầu vào nhưng không tạo quotation chính thức; bản nháp phải được SALES_L2 xác nhận và phát hành dưới danh nghĩa của mình.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Quotation (mỗi bản gửi khách là 1 QuotationVersion; trạng thái hiển thị trên WEB phải khớp machine-state do CORE trả về).

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit duyệt)──► [PENDING_APPROVAL] ──(duyệt đủ ma trận + GM)──► [APPROVED] ──(gửi khách)──► [SENT - khóa read-only]
   ▲                              │                        │                                            │
   │ (tạo version mới + duyệt lại)│ (từ chối)              │ (auto quá 30/60 ngày)                      ├──(khách chấp nhận)──► [ACCEPTED]
   └──────────────────────────────┴── [REJECTED]           └──────────► [EXPIRED] ◄─────(auto quá hạn)──┘
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit duyệt | `PENDING_APPROVAL` | SALES_L2 chủ deal (hoặc FIN_L1 phối hợp) | Đủ cấu phần giá; trace `rateCardVersionId` hợp lệ; `serviceType` khai rõ |
| `DRAFT` | Tự duyệt ≤5% | `APPROVED` | SALES_L2 chủ deal | Chiết khấu ≤5% và GM đạt ngưỡng nhóm dịch vụ — chấp nhận tức thời |
| `PENDING_APPROVAL` | Duyệt đủ theo ma trận | `APPROVED` | SALES_L4 (>5–15%, SLA 8h LV) / SALES_L5 (>15–20% + GM dưới ngưỡng đến 20%, SLA 1 ngày) / BOD_CEO (>20%, SLA 2 ngày, văn bản) | Đủ mọi tầng duyệt; lý do/nhận định ghi bắt buộc; người duyệt khác chủ deal |
| `PENDING_APPROVAL` | Từ chối | `REJECTED` | Cấp duyệt tương ứng | Bắt buộc nhập lý do từ chối |
| `APPROVED` | Gửi khách | `SENT` | SALES_L2 chủ deal | Còn hiệu lực; khóa vĩnh viễn read-only; log người gửi/thời điểm/nội dung |
| `APPROVED` / `SENT` | Auto hết hạn | `EXPIRED` | Hệ thống | Quá 30 ngày (60 cho hợp đồng năm/đa giai đoạn) kể từ phát hành |
| `SENT` | Ghi nhận khách chấp nhận | `ACCEPTED` | SALES_L2 chủ deal | Điều kiện mở luồng hợp đồng/LOI — FEAT-ERP-QDD-002 |
| `SENT` / `REJECTED` | Tạo version mới | Về `DRAFT` (version mới) | SALES_L2 chủ deal | Duyệt lại toàn bộ; vòng sửa theo tier D/E ≤2, B/C ≤4; vượt cần exception GDKD có lý do |

**Quy tắc:**
- `SENT`, `ACCEPTED`, `EXPIRED`, `REJECTED` là trạng thái khóa nội dung — mọi thay đổi chỉ được thực hiện qua version mới, không sửa đè.
- `EXPIRED` không quay lại `APPROVED`; tiếp tục bán buộc re-quote theo định mức hiện hành.
- Quá hạn 2 ngày làm việc chưa gửi sau duyệt GM không đổi trạng thái nhưng kích hoạt cảnh báo SM + GDKD và ghi log trễ.
- WEB không được tự đoán trạng thái — mọi nhãn trạng thái render từ field machine-state do API CORE trả về.

---

## 7. Tóm Tắt Entity (Quick Reference)

Các entity nghiệp vụ lưu và thực thi tại SYS-CORE-BACKEND; trên WEB chúng xuất hiện dưới dạng view/form gọi API, không có store riêng lệch nguồn sự thật.

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `Quotation` | `id`, `dealId`, `serviceType` (RENTAL/MANAGED), `currency`, `status`, `validUntil`, `maxValidDays`, `discountPercent`, `gmPercent`, `gmThreshold` | FK → deal (MOD-CRM-PIPELINE); FK → `RateCardVersion` | Trạng thái theo machine-state §6 |
| `QuotationVersion` | `quotationId`, `versionNo`, `payloadSnapshot` (JSON cấu phần giá), `sentBy`, `sentAt`, `locked`, `revisionRound` | FK → `Quotation` | Bản gửi khóa vĩnh viễn; đếm vòng sửa theo tier |
| `DiscountApproval` | `quotationVersionId`, `level` (≤5 / 5–15 / 15–20 / >20), `approverRole`, `decision`, `reason`, `slaDeadline`, `decidedAt` | FK → `QuotationVersion` | SLA 8h LV / 1 ngày / 2 ngày; escalate khi quá hạn |
| `RateCardVersion` (định mức — CORE sở hữu, WEB chỉ đọc) | `versionNo`, `tier`, `currency`, `effectiveFrom`, `effectiveTo`, `mediaRate`, `agencyDiscount`, `hourRateL1–L5`, `platformFee`, `riskBuffer`, `gmThresholdByService` | effective-dated, không sửa quá khứ | Mức mặc định số liệu đã chốt theo DI-001; định mức theo tier V6.0 (`[KXN-8]`) |
| `AuditLogEntry` (tham chiếu) | `actor`, `action`, `entityRef`, `reason`, `timestamp`, `hashChain` | append-only WORM ≥10 năm | Xem log cũng bị log |

---

## 8. Acceptance Criteria

Phác thảo nghiệm thu sơ bộ ở Phase 2; chi tiết đầy đủ sẽ khóa tại Phase 5 (implementation tasks). Mỗi scenario map về REQ-SALES-006 trong Mục 2 của sales.md.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Trace version định mức | Rate card version vQ3 hiệu lực | NVKD phát hành quotation | Bản ghi lưu đúng `rateCardVersionId` hiệu lực tại thời điểm phát hành, hiển thị trên WEB | [ ] |
| SC-002: Cảnh báo đỏ GM | GM ads tính ra 17% | NVKD mở form quotation | WEB hiển thị cảnh báo đỏ và chỉ cho submit vào luồng duyệt GM theo BR-QDD-002 | [ ] |
| SC-003: Chặn gửi thiếu duyệt | Chiết khấu 12% chưa có quyết định TPKD | NVKD bấm gửi khách | UI vô hiệu nút và API từ chối (chặn 2 tầng); log ghi lần cố gắng | [ ] |
| SC-004: Khóa bản gửi | Quotation đã gửi khách | Ai đó cố sửa nội dung bản gửi | Hệ thống từ chối; chỉ cho phép tạo version mới và duyệt lại | [ ] |
| SC-005: Vòng sửa theo tier | Khách tier B đã sửa 4 lần | NVKD tạo version thứ 5 không có exception | API chặn; WEB hiển thị yêu cầu exception GDKD kèm lý do | [ ] |
| SC-006: Auto hết hạn | Quotation phát hành 31 ngày trước | Đến ngày thứ 31 | Hệ thống tự chuyển `EXPIRED`; chặn gửi; đề nghị re-quote theo định mức hiện hành | [ ] |
| SC-007: Che giá vốn | NVKD mở chi tiết quotation | Xem cấu phần giá | Trường giá vốn/GM chi tiết không trả về cho vai SALES_L2 ở tầng API | [ ] |

> **Liên kết:** Mỗi scenario map đến REQ-SALES-006 (sales.md Mục 2/Phần B.6).

---

## Tài Liệu Kĩ Thuật Liên Quan

Chi tiết kĩ thuật (data model, API, integration) nằm tại các file chuyên trách dưới đây; file này chỉ chốt yêu cầu nghiệp vụ của touchpoint web nội bộ.

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (quotation, approval, version) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (fan-out 3 systems của REQ-SALES-006) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI (form soạn, hàng đợi duyệt, dashboard GM) | `phase4-ux/bcerp-web/quotation-dealdesk/[screen-group].md` |
| Bản counterpart SYS-CORE-BACKEND (GM engine, approval engine, version lock) | `phase2-features/core-backend/quotation-dealdesk/` (cùng fan-out REQ-SALES-006) |
| Bản counterpart SYS-MOBILE-INTERNAL (duyệt push Phase2) | `phase2-features/mobile-internal/quotation-dealdesk/` (cùng fan-out REQ-SALES-006) |
| Nguồn domain CMS (serviceType, phí RENTAL/MANAGED) | `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1) |
