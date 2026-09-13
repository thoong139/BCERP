# Tính Năng: Hợp đồng/LOI/NDA & Brand Safety + e-sign

> **Dựa trên:** REQ-SALES-007 trong `phase1-business/departments/sales/sales.md` (Phần A — Mục REQ-SALES-007; chi tiết chuyên môn tại Phần B, Mục B.7)
> **Phân hệ:** Sales — Quotation & Deal Desk (DEPT-SALES)
> **Module:** Quotation & Deal Desk — touchpoint SYS-BCERP-WEB (MOD-QUOTATION-DEALDESK)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `phase1-business/P1-02-business-workflow.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/quotation-dealdesk/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/quotation-dealdesk/FEAT-ERP-QDD-002-impl.md`

> **Fan-out note (multi-system):** REQ-SALES-007 xuất hiện ở 3 systems. File này là bản riêng cho **SYS-BCERP-WEB** — web nội bộ responsive (Next.js) cho nhân viên BC: form/list/workflow UI, gọi API core, hiển thị đúng trạng thái machine-state. Workflow phiên bản hợp đồng, lock signed, trạng thái "chờ kích hoạt", retention và audit trail thực thi ở service layer của SYS-CORE-BACKEND (counterpart của cùng REQ); duyệt HĐ giá trị lớn qua push di động thuộc SYS-MOBILE-INTERNAL (Phase2) — không mô tả ở đây.

---

## Thông Tin Chung

Tính năng này là mặt làm việc chính trên web nội bộ để soạn hợp đồng/LOI/NDA từ mẫu chuẩn, chạy checklist Brand Safety 7 tiêu chí, điều phối duyệt theo ma trận giá trị, ký điện tử (e-sign) và lưu trữ sau ký. Tính năng nhận đầu vào là quotation đã duyệt GM từ FEAT-ERP-QDD-001 và là điều kiện kích hoạt D+0 của giai đoạn triển khai.

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-QDD-002 |
| Module | MOD-QUOTATION-DEALDESK (SYS-BCERP-WEB) |
| Yêu cầu nghiệp vụ | REQ-SALES-007 |
| Người dùng liên quan | SALES_L1 (Intern), SALES_L2 (NVKD), SALES_L3 (TNKD), SALES_L4 (TPKD/SM — KXN-14), SALES_L5 (GDKD — quy hoạch, tạm BOD kiêm nhiệm); phối hợp OPS_AM (nhận ràng buộc vận hành), FIN_L1 (xác nhận nạp NSQC), BOD_CEO (duyệt HĐ giá trị lớn), SYS_ADMIN (quản mẫu hệ thống) |

> **Chú thích phân biệt (P4 — KXN-14):** `SALES_L3` là vai TNKD (trưởng nhóm kinh doanh) theo `sales.md`; chức danh **SM** ánh xạ **SALES_L4 (TPKD)** — người ký/duyệt các mốc gate theo KXN-14, không còn gắn với SALES_L3.
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — mẫu chuẩn, chặn NDA, nạp trước NSQC, version lock); e-sign tích hợp hoàn chỉnh + checklist Brand Safety gắn EVALUATION + archive alert hoàn thiện theo lộ trình REQ-SALES-007 |
| Phụ thuộc | FEAT-ERP-QDD-001 (quotation APPROVED là đầu vào soạn hợp đồng); không có cross-dependency ngoài lane |
| Ghi chú Expert (A7) | sales.md có Mục A7 (khung đánh giá expert); nội dung điều chỉnh chuyên môn hiện nằm tại Phần B — Sales Expert Review 12/09/2026 (Mục B.0, B.7): NDA mutual là điều kiện machine-checkable của Gate 1; Brand Safety fail 1/7 dừng không sang PROPOSAL; red-line diff check so template; e-sign theo Luật GDTĐT 2023 + NĐ 91/2022 với audit trail; toàn bộ điều khoản cần luật sư VN xác nhận trước khi phát hành mẫu chính thức |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa toàn bộ vòng đời HĐ/LOI/NDA về một luồng có kiểm soát trên web nội bộ — từ soạn theo mẫu đã legal duyệt, chặn rủi ro bằng Brand Safety 7 tiêu chí trước khi ký, đến ký điện tử hợp pháp và lưu trữ đủ điều kiện truy vết — bảo đảm không có cam kết pháp lý nào phát sinh ngoài hệ thống và không có chiến dịch nào kích hoạt khi chưa đủ tiền và chưa có văn bản ký.

**Phạm vi:**
- Bao gồm:
  - Thư viện mẫu chuẩn: NDA (mutual), LOI/MOU, hợp đồng thuê TKQC (RENTAL) và hợp đồng chạy hộ (MANAGED) soạn theo mẫu IN/OUT of scope đã qua legal review; SYS_ADMIN quản danh mục mẫu, mọi mẫu phát hành phải có bản ghi xác nhận của luật sư VN.
  - Checklist Brand Safety 7 tiêu chí pass/fail từng tiêu chí, gắn stage EVALUATION của pipeline; nút "Từ chối vận hành" ghi tiêu chí vi phạm + notify legal + OPS (OPS_AM).
  - Workflow phiên bản: Template → Draft v0.x (WEB soạn) → Legal review → duyệt theo ma trận giá trị → Counterparty v1.x → Final v2.0 → E-sign → Signed (lock cứng) → Archive; diff check cảnh báo khi điều khoản red-line (không cam kết KPI cứng, cap trách nhiệm, miễn trừ nền tảng) bị xóa/sửa so với template.
  - Trạng thái "chờ kích hoạt": hợp đồng đã ký nhưng chưa xác nhận nạp đủ 100% NSQC → hiển thị trạng thái chờ, block tạo chiến dịch (bắt tay Financial Hard Stop); điều kiện kích hoạt D+0 là có tiền vào + LOI/HĐ đã ký, hợp đồng đầy đủ ký trong ≤7 ngày (`[KXN-5]`/`[KXN-10]` đã chốt 12/09).
  - Ràng buộc `serviceType` bất biến: 1 hợp đồng chỉ giữ 1 `serviceType` (RENTAL/MANAGED) suốt vòng đời; đổi dịch vụ = tất toán hợp đồng cũ (hoàn số dư trong 15 ngày làm việc) + mở hợp đồng mới (CMS Domain Model §1).
  - Archive và vòng đời sau ký: alert 30/60/90 ngày trước hạn, retention ≥10 năm, tiêu hủy hết hạn chỉ khi có phê duyệt + log hủy.
- Không bao gồm:
  - Engine chữ ký số (CA provider, ký số, audit trail gốc) và archive engine — tích hợp/thực thi ở SYS-CORE-BACKEND; WEB gọi API và hiển thị trạng thái.
  - Xác nhận dòng tiền nạp 100% NSQC — nguồn sự thật thuộc Financial Hard Stop (FIN/CORE); WEB chỉ đọc kết quả xác nhận.
  - Duyệt HĐ giá trị lớn qua push mobile — thuộc SYS-MOBILE-INTERNAL (Phase2).
  - Vận hành chiến dịch sau kích hoạt — thuộc DEPT-OPS; kho nguồn cung nội bộ BM/VIA/proxy — ngoài phạm vi v1 của CMS Domain Model.
  - Tính lại giá/GM trong hợp đồng — kế thừa nguyên trạng từ quotation đã duyệt (FEAT-ERP-QDD-001).

---

## 2. Luồng Người Dùng (User Stories)

Các user story diễn ra trên web nội bộ responsive; trạng thái hiển thị luôn đọc từ machine-state của SYS-CORE-BACKEND, kể cả trạng thái chờ legal, chờ duyệt giá trị, chờ ký và chờ kích hoạt.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | SALES_L2 (NVKD) | Soạn NDA mutual từ mẫu chuẩn gắn với khách hàng và gửi ký | Có NDA mutual signed trước khi nhận Full Brief 8 sections |
| 2 | SALES_L2 (NVKD) | Soạn LOI/hợp đồng từ mẫu IN/OUT of scope, tham chiếu quotation đã duyệt GM | Cam kết pháp lý khớp đúng giá và `serviceType` đã báo giá |
| 3 | SALES_L2 (NVKD) | Điền checklist Brand Safety 7 tiêu chí pass/fail từng mục khi deal ở stage EVALUATION | Chặn sớm rủi ro pháp lý/nền tảng trước khi sang PROPOSAL và trước khi ký |
| 4 | SALES_L3 (TNKD) | Xem kết quả checklist Brand Safety và dấu hiệu bypass tại deal nhóm mình | Đảm bảo không deal nào lọt sang PROPOSAL khi fail tiêu chí |
| 5 | SALES_L2 (NVKD) | Bấm "Từ chối vận hành" ghi rõ tiêu chí vi phạm và tự động notify legal + OPS_AM | Có quyết định chính thức (legal xác nhận + TP Vận hành trong 24h) thay vì xử lý miệng |
| 6 | SALES_L5 (GDKD) | Duyệt hợp đồng theo ma trận giá trị và xem cảnh báo red-line diff so với template | Không để điều khoản bảo vệ BC bị xóa/sửa mà không qua thẩm định |
| 7 | BOD_CEO | Duyệt hợp đồng giá trị lớn theo ma trận, quyết định gắn văn bản trên hệ thống | Cam kết giá trị cao có chữ ký cấp cao nhất và audit trail |
| 8 | SALES_L2 (NVKD) | Theo dõi trạng thái "chờ kích hoạt" khi hợp đồng đã ký nhưng chưa nạp đủ 100% NSQC | Biết chính xác điều kiện còn thiếu để khách kích hoạt D+0, không hứa sai |
| 9 | OPS_AM | Nhận ràng buộc vận hành từ hợp đồng (SLA, phạm vi RENTAL/MANAGED) hiển thị ở bản tóm tắt sau ký | Vận hành đúng những gì hợp đồng cam kết, không nhận việc ngoài hợp đồng |
| 10 | SALES_L1 (Intern) | Xem trạng thái hồ sơ hợp đồng/NDA của deal được hỗ trợ | Theo dõi tiến trình ký để hỗ trợ chủ deal chuẩn bị hồ sơ |
| 11 | SYS_ADMIN | Quản lý danh mục mẫu chuẩn và phiên bản mẫu trên hệ thống | Mẫu đối tác/mẫu cũ không thể được dùng khi chưa qua legal review |

---

## 3. Quy Tắc Nghiệp Vụ

Quy tắc dưới đây bắt buộc; developer enforce qua API của SYS-CORE-BACKEND và vô hiệu hóa UI tương ứng (chặn 2 tầng theo BR-SALES-000). Bộ tiêu chí Evaluation chính thức (Brand Safety 7 + Weighted ≥3.5 của V6.0) vẫn chờ xác nhận theo `[KXN-6]` — spec hiện hành dùng Brand Safety 7 tiêu chí như nguồn chưa chốt cuối, ghi nhận như assumption, không tự quyết thay khách hàng.

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-QDD-101 | NDA mutual signed gắn khách là điều kiện nhận Full Brief 8 sections; CORE block nhận brief khi chưa có NDA; LOI/MOU đàm phán được ký trước hợp đồng chính nhưng không thay thế NDA | API từ chối nhận brief; sales không được trigger bước nhận brief; WEB hiển thị blocker rõ lý do |
| BR-QDD-102 | Brand Safety 7 tiêu chí bắt buộc pass hết trước khi ký, gắn stage EVALUATION: (1) sản phẩm/dịch vụ hợp pháp + giấy phép con; (2) không vi phạm Ads Policy nền tảng; (3) không spam/misleading; (4) quyền image/video/bản quyền hợp lệ; (5) landing page hợp pháp khớp quảng cáo; (6) dữ liệu mục tiêu có cơ sở thu thập; (7) không ngành cấm/nhạy cảm chưa duyệt nội bộ | Fail bất kỳ 1/7 → dừng, không sang PROPOSAL; checklist chưa đầy đủ → chặn mở luồng ký |
| BR-QDD-103 | Nút "Từ chối vận hành" bắt buộc ghi tiêu chí vi phạm + tự notify legal + OPS; legal xác nhận phối hợp TP Vận hành trả lời trong 24h; vi phạm knockout K1 (sản phẩm hạn chế thiếu giấy phép — Luật Quảng cáo 2012) → chấm dứt hợp đồng | Không ghi tiêu chí vi phạm → không gửi được yêu cầu; log không hợp lệ yêu cầu bổ sung |
| BR-QDD-104 | Workflow phiên bản: Draft v0.x → Counterparty v1.x → Final v2.0 → Signed (lock cứng); mọi nhảy phiên bản có audit trail người sửa/nội dung diff | Sửa trên bản Signed bị từ chối tuyệt đối; thiếu audit trail của phiên → phiên không hợp lệ |
| BR-QDD-105 | Diff check cảnh báo khi điều khoản red-line (không cam kết KPI cứng về lead/CPA/ROAS, cap trách nhiệm, miễn trừ nền tảng) bị xóa/sửa so với template; điều khoản red-line không chấp nhận xóa; dùng mẫu đối tác phải qua legal review | Phát hiện sửa red-line → chặn duyệt, bắt buộc GDKD + luật sư thẩm định 5–7 ngày làm việc trước khi tiếp tục |
| BR-QDD-106 | Duyệt theo ma trận giá trị HĐ (SM/GDKD/BOD theo ngưỡng); ngưỡng cụ thể do GDKD/BOD ban hành — `[CẦN CHỐT SỐ]` chờ policy chính thức, cấu hình effective-dated khi triển khai | Chưa đủ duyệt theo ma trận → chặn bước E-sign; quá SLA escalate + log |
| BR-QDD-107 | E-sign theo Luật Giao dịch điện tử 2023 và NĐ 91/2022: chữ ký số do tổ chức cung cấp dịch vụ chứng thực chữ ký cấp; audit trail bắt buộc gồm thời gian, IP, người ký cho mọi bên ký | Thiếu bất kỳ thành phần audit trail → chữ ký không được công nhận, hợp đồng không chuyển `SIGNED` |
| BR-QDD-108 | Kích hoạt D+0 chỉ khi có tiền vào + LOI/hợp đồng đã ký; hợp đồng đầy đủ phải ký trong ≤7 ngày (`[KXN-5]`/`[KXN-10]` resolved 12/09); chưa xác nhận nạp đủ 100% NSQC → hợp đồng "chờ kích hoạt", block tạo chiến dịch ở tầng máy (K4, bắt tay Financial Hard Stop) | Chưa đủ điều kiện → API chặn tạo chiến dịch; WEB hiển thị trạng thái "chờ kích hoạt" kèm điều kiện còn thiếu |
| BR-QDD-109 | 1 hợp đồng 1 `serviceType` bất biến trong suốt vòng đời (RENTAL hoặc MANAGED); muốn đổi dịch vụ → tất toán hợp đồng cũ (hoàn số dư trong 15 ngày làm việc) + mở hợp đồng mới; `serviceType = MANAGED` mới gắn `pmsProjectId`, RENTAL luôn null | Không cho phép sửa `serviceType` trên hợp đồng đang ACTIVE; API từ chối; WEB điều hướng mở hợp đồng mới kèm quotation mới (FEAT-ERP-QDD-001) |
| BR-QDD-110 | Archive sau ký: alert 30/60/90 ngày trước hạn; retention ≥10 năm; tiêu hủy hợp đồng hết hạn chỉ khi có phê duyệt + log hủy | Hết hạn không có phê duyệt → không được xóa/tiêu hủy; mọi thao tác archive/tiêu hủy có audit log bất biến |
| BR-QDD-111 | Mọi sự kiện hợp đồng (ký, duyệt, sửa, archive, chờ kích hoạt) ghi audit log hash-chain WORM ≥10 năm; xem log cũng bị log | Mất audit trail khi phát sinh hệ quả pháp lý → bắt buộc xử lý sự cố trước khi tiếp tục giao dịch |
| BR-QDD-112 | Toàn bộ điều khoản mẫu cần luật sư VN xác nhận trước khi phát hành mẫu chính thức; mẫu chưa legal review không xuất hiện trong danh mục khả dụng | WEB không hiển thị mẫu chưa duyệt; API từ chối soạn từ mẫu không hợp lệ |

---

## 4. Phân Quyền

Phân quyền theo 18 vai registry; không có vai legal riêng trong registry nên hành động "legal review" được ghi nhận trên hệ thống do SALES_L5 (GDKD) thực hiện khi phối hợp luật sư bên ngoài — hệ thống lưu bằng chứng review, người ký quyết định pháp lý vẫn là GDKD/BOD theo ma trận giá trị.

| Hành động | SALES_L1 | SALES_L2 | SALES_L3 | SALES_L4 | SALES_L5 | OPS_AM | FIN_L1 | SYS_ADMIN | BOD_CEO |
|-----------|----------|----------|----------|----------|----------|--------|--------|-----------|---------|
| Xem hồ sơ HĐ/LOI/NDA của deal mình được gán | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (bản tóm tắt ràng buộc) | ✅ (trạng thái nạp) | ✅ | ✅ |
| Soạn NDA/LOI/hợp đồng từ mẫu chuẩn | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Điền checklist Brand Safety 7 tiêu chí | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Review/đóng kết quả checklist tại EVALUATION | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Bấm "Từ chối vận hành" + notify legal/OPS | ❌ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Duyệt hợp đồng theo ma trận giá trị (ngưỡng thấp/trung) | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Duyệt HĐ giá trị lớn / đụng red-line / mẫu đối tác | ❌ | ❌ | ❌ | ❌ | ✅ (trình GDKD + luật sư 5–7 ngày) | ❌ | ❌ | ❌ | ✅ |
| Thực hiện bước legal review (ghi nhận bằng chứng) | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Ký e-sign đại diện BC | ❌ | ❌ | ✅ (theo ủy quyền giá trị) | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ |
| Cấu hình danh mục mẫu/version mẫu | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (sau legal review) | ❌ |
| Phê duyệt tiêu hủy hợp đồng hết hạn | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

---

## 5. Trường Hợp Đặc Biệt

- **Mẫu đối tác đưa vào:** khách yêu cầu dùng mẫu của họ — bắt buộc GDKD + luật sư duyệt trong 5–7 ngày làm việc; trong thời gian chờ, luồng ký bị treo ở `LEGAL_REVIEW`, WEB hiển thị đếm ngày thẩm định.
- **Red-line bị đề nghị sửa:** bêncounterpart đàm phán xóa/cụ thể hóa lại cap trách nhiệm hay miễn trừ nền tảng — diff check bật cảnh báo, không ai được duyệt qua email; mọi kết quả thẩm định phải quay lại gắn trên phiên bản hợp đồng.
- **LOI ký trước, hợp đồng chưa xong:** LOI đủ để kích hoạt D+0 theo `[KXN-5]` nhưng hợp đồng đầy đủ phải ký trong ≤7 ngày; WEB đếm ngược 7 ngày và escalate GDKD khi cận hạn; vẫn cấm nhận Full Brief nếu chưa có NDA bất kể LOI đã ký.
- **Đổi serviceType giữa chừng:** khách RENTAL muốn chuyển MANAGED (hoặc ngược lại) — hợp đồng cũ tất toán, hoàn số dư trong 15 ngày làm việc, mở hợp đồng mới với `serviceType` mới; WEB hiển thị cảnh báo rằng không thể sửa `serviceType` trên hợp đồng ACTIVE và điều hướng mở quotation + hợp đồng mới.
- **Nhiều TKQC một hợp đồng:** một hợp đồng có thể phủ nhiều tài khoản quảng cáo cùng khách nhưng tại một thời điểm mỗi AdAccount chỉ có đúng 1 hợp đồng ACTIVE; thay thế tài khoản (ReplacementRequest) không đổi hợp đồng, fee schedule giữ nguyên.
- **GDKD kiêm nhiệm BOD:** khi người GDKD và BOD_CEO trùng nhau (hiện trạng tổ chức), hợp đồng thuộc ngưỡng BOD phải chuyển BOD_CFO_CTO duyệt để tránh tự duyệt; WEB phát hiện trùng vai và điều hướng.
- **E-sign sự cố kỹ thuật:** CA provider lỗi hoặc audit trail thiếu thành phần (IP/thời gian) → hợp đồng quay lại `E_SIGNING` để ký lại; không có cơ chế "coi như đã ký".
- **Khách chậm nạp sau ký:** hợp đồng `SIGNED` nhưng chưa xác nhận nạp đủ 100% NSQC kéo dài — WEB giữ trạng thái "chờ kích hoạt", nhắc định kỳ NVKD; tuyệt đối không mở khóa tạo chiến dịch bằng tay.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Hợp đồng (Contract — bao gồm NDA/LOI dùng cùng workflow rút gọn); trạng thái hiển thị trên WEB render trực tiếp từ machine-state của CORE.

**Sơ đồ trạng thái:**
```
[TEMPLATE] ──(soạn)──► [DRAFT v0.x] ──(legal review pass)──► [VALUE_APPROVAL] ──(duyệt đủ ma trận)──► [COUNTERPARTY v1.x]
                            │ (fail/red-line)                      │ (từ chối)                                  │ (chốt nội dung 2 bên)
                            ▼                                      ▼                                            ▼
                    quay DRAFT sửa & nộp lại                    [REJECTED]                          [FINAL v2.0] ──(e-sign đủ 2 bên)──► [SIGNED - lock cứng]
                                                                                                                          │
                                                                     ┌──(nạp đủ 100% NSQC + trong ≤7 ngày)──────────────┤
                                                                     ▼                                                   ▼
                                                                 [ACTIVE] ◄────────────────────────────── [AWAITING_ACTIVATION - chờ kích hoạt]
                                                                     │
                                                        (tất toán/đổi serviceType/hết hạn)
                                                                     ▼
                                                              [TERMINATED] ──(archive ≥10 năm)──► [ARCHIVED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `TEMPLATE` | Soạn từ mẫu | `DRAFT v0.x` | SALES_L2 chủ deal | Mẫu đã legal review + có tham chiếu quotation APPROVED (FEAT-ERP-QDD-001) |
| `DRAFT v0.x` | Nộp legal review | `LEGAL_REVIEW` | SALES_L2 | Nội dung hoàn chỉnh; diff check đã chạy, cảnh báo red-line được ghi nhận |
| `LEGAL_REVIEW` | Duyệt giá trị | `VALUE_APPROVAL` | SALES_L5 (ghi nhận legal review) rồi SM/GDKD/BOD theo ma trận | Đụng red-line/mẫu đối tác → GDKD + luật sư 5–7 ngày làm việc |
| `VALUE_APPROVAL` | Chuyển cho counterpart | `COUNTERPARTY v1.x` | SALES_L2 | Đủ duyệt ma trận giá trị; lý do/điều kiện kèm theo |
| `COUNTERPARTY v1.x` | Chốt nội dung | `FINAL v2.0` | SALES_L2 + GDKD | Hai bên nhất trí nội dung; phiên bản freeze trước khi ký |
| `FINAL v2.0` | Ký e-sign | `SIGNED` | Đại diện BC (theo ủy quyền) + đại diện khách | Audit trail đầy đủ thời gian/IP/người ký theo Luật GDTĐT 2023; xong → lock cứng |
| `SIGNED` | Xác nhận điều kiện kích hoạt | `AWAITING_ACTIVATION` → `ACTIVE` | Hệ thống (đọc FIN/CORE) | Có tiền vào + LOI/HĐ đã ký; hợp đồng đầy đủ ký trong ≤7 ngày; chưa nạp đủ 100% NSQC thì giữ "chờ kích hoạt" và block tạo chiến dịch |
| `ACTIVE` | Tất toán/đổi serviceType/hết hạn | `TERMINATED` | SALES_L5 + BOD_CEO (phê duyệt) | Ghi `terminationReason`; đổi dịch vụ → hoàn số dư 15 ngày làm việc + mở hợp đồng mới |
| `TERMINATED` | Lưu trữ | `ARCHIVED` | SYS_ADMIN (thực thi) theo phê duyệt | Retention ≥10 năm; alert 30/60/90 ngày trước hạn; tiêu hủy chỉ khi có phê duyệt + log hủy |

**Quy tắc:**
- `SIGNED` là trạng thái khóa cứng nội dung — mọi thay đổi sau ký chỉ qua phụ lục/hợp đồng mới, không sửa đè.
- `AWAITING_ACTIVATION` không có đường tắt sang `ACTIVE`: thiếu tiền hoặc thiếu văn bản ký là không kích hoạt, không phân biệt lý do.
- `REJECTED` và `TERMINATED` là trạng thái kết thúc cho phiên bản/hợp đồng đó; deal tiếp tục bằng tài liệu mới, không hồi trạng thái.
- NDA/LOI dùng machine rút gọn (soạn → ký → hết hiệu lực) nhưng chia sẻ chung kho mẫu và audit trail với hợp đồng chính.

---

## 7. Tóm Tắt Entity (Quick Reference)

Entity nghiệp vụ lưu và thực thi tại SYS-CORE-BACKEND; trên WEB là form/list gọi API, không có bản sao dữ liệu lệch nguồn sự thật.

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `ContractTemplate` | `id`, `type` (NDA/LOI/CONTRACT_RENTAL/CONTRACT_MANAGED), `versionNo`, `legalApprovedBy`, `legalApprovedAt`, `redLineClauses[]` | — | Chỉ mẫu đã legal review mới khả dụng; SYS_ADMIN quản danh mục |
| `Contract` | `id`, `customerId`, `serviceType` (RENTAL/MANAGED — bất biến), `status`, `startDate`, `endDate`, `feePercent`, `quotationId`, `pmsProjectId` (chỉ MANAGED), `terminationReason`, `refundAmount` | FK → Customer; FK → `Quotation` (FEAT-ERP-QDD-001); 1 AdAccount có đúng 1 Contract ACTIVE | serviceType không cho sửa trên ACTIVE |
| `ContractVersion` | `contractId`, `versionKind` (v0.x/v1.x/v2.0), `payloadSnapshot`, `diffReport`, `createdBy` | FK → `Contract` | v2.0 freeze trước ký; diff red-line gắn trên phiên |
| `BrandSafetyChecklist` | `contractId`/`dealId`, `criteria1–7` (pass/fail + bằng chứng), `stage` (EVALUATION), `rejectedCriteria[]`, `notifyLog` | FK → deal/Contract | Fail 1/7 dừng; assumption `[KXN-6]` chờ bộ tiêu chí Evaluation chính thức |
| `SignatureEvent` | `contractId`, `signerName`, `signerRole`, `signedAt`, `ip`, `caProvider`, `auditTrailHash` | FK → `Contract` | Theo Luật GDTĐT 2023 + NĐ 91/2022; thiếu thành phần → ký lại |
| `ArchiveRecord` | `contractId`, `archivedAt`, `expiryAlerts30/60/90`, `retentionUntil` (≥10 năm), `disposalApproval`, `disposalLog` | FK → `Contract` | Tiêu hủy chỉ khi có phê duyệt + log |
| `AuditLogEntry` (tham chiếu) | `actor`, `action`, `entityRef`, `timestamp`, `hashChain` | append-only WORM | Xem log cũng bị log |

---

## 8. Acceptance Criteria

Phác thảo nghiệm thu sơ bộ ở Phase 2; chi tiết đầy đủ khóa tại Phase 5. Mỗi scenario map về REQ-SALES-007 (sales.md Mục 2/Phần B.7).

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-101: Chặn brief khi chưa NDA | Khách chưa có NDA mutual signed | SM/NVKD trigger nhận Full Brief 8 sections | UI vô hiệu và API từ chối; WEB hiển thị blocker "chưa NDA mutual" | [ ] |
| SC-102: Brand Safety fail 1/7 | Checklist EVALUATION có 1 tiêu chí fail | NVKD cố mở luồng PROPOSAL/ký | Hệ thống dừng; ghi nhận tiêu chí fail; đề xuất nút "Từ chối vận hành" notify legal + OPS | [ ] |
| SC-103: Red-line diff cảnh báo | Draft xóa điều khoản cap trách nhiệm so template | Lưu phiên bản v0.x | WEB hiển thị cảnh báo diff; luồng chuyển sang yêu cầu GDKD + luật sư 5–7 ngày làm việc | [ ] |
| SC-104: Lock sau ký | Hợp đồng đã `SIGNED` | Ai đó cố sửa nội dung | API từ chối tuyệt đối; chỉ cho phép phụ lục/hợp đồng mới có audit trail | [ ] |
| SC-105: Chờ kích hoạt | Hợp đồng `SIGNED`, chưa nạp đủ 100% NSQC | Kiểm tra trạng thái | WEB hiển thị "chờ kích hoạt"; API chặn tạo chiến dịch ở tầng máy | [ ] |
| SC-106: Kích hoạt D+0 | Có tiền vào + LOI/HĐ đã ký trong hạn ≤7 ngày | Hệ thống đối chiếu điều kiện | Hợp đồng chuyển `ACTIVE`, mở được chiến dịch; log đầy đủ điều kiện kích hoạt | [ ] |
| SC-107: serviceType bất biến | Hợp đồng RENTAL đang `ACTIVE` | Yêu cầu sửa thành MANAGED | API từ chối; WEB điều hướng tất toán + mở hợp đồng mới (hoàn số dư 15 ngày làm việc) | [ ] |
| SC-108: Archive alert | Hợp đồng còn 30/60/90 ngày trước hạn | Đến mốc alert | WEB gửi cảnh báo đúng mốc; tiêu hủy sau hạn chỉ thực thi khi có phê duyệt + log | [ ] |

> **Liên kết:** Mỗi scenario map đến REQ-SALES-007 trong Mục 2 của sales.md.

---

## Tài Liệu Kĩ Thuật Liên Quan

Chi tiết kĩ thuật (data model, API, integration) nằm tại các file chuyên trách; file này chỉ chốt yêu cầu nghiệp vụ của touchpoint web nội bộ.

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (contract workflow, checklist, e-sign, archive) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (CA provider, Financial Hard Stop, fan-out 3 systems của REQ-SALES-007) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI (thư viện mẫu, checklist Brand Safety, luồng ký, trạng thái chờ kích hoạt) | `phase4-ux/bcerp-web/quotation-dealdesk/[screen-group].md` |
| Bản counterpart SYS-CORE-BACKEND (workflow engine, version lock, retention) | `phase2-features/core-backend/quotation-dealdesk/` (cùng fan-out REQ-SALES-007) |
| Bản counterpart SYS-MOBILE-INTERNAL (duyệt HĐ giá trị lớn Phase2) | `phase2-features/mobile-internal/quotation-dealdesk/` (cùng fan-out REQ-SALES-007) |
| Nguồn domain CMS (Contract serviceType bất biến, quan hệ AdAccount/PMS) | `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1, §1/§3.3/§4) |
| Ghi chú P4: SM ánh xạ SALES_L4 theo KXN-14 (đồng bộ stakeholder review 12/09) | `phase1-business/stakeholder-review.md` (F.5 — Quyết định 12/09/2026) |
