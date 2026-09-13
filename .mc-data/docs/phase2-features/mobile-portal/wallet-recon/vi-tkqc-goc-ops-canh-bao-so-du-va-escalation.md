# Tính Năng: Ví TKQC Góc Ops — Cảnh Báo Số Dư & Escalation (Mobile BC Portal)

> **Dựa trên:** REQ-OPS-003 trong `phase1-business/departments/operations/operations.md` (Phần A, B.2); cross-dependency REQ-FIN-002 trong `phase1-business/departments/finance/finance.md` (ngưỡng cảnh báo nguồn FIN); ràng buộc hiển thị theo REQ-FIN-017
> **Phân hệ:** Mobile App — BC Portal (SYS-MOBILE-PORTAL)
> **Module:** Ví & Đối soát TKQC (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/departments/finance/finance.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-portal/wallet-recon/[screen-group].md`, `phase5-implementation/tasks/mobile-portal/wallet-recon/`

> **Hướng dẫn ID:** REQ-OPS-003 fan-out ra 6 hệ thống; đây là bản riêng của touchpoint **SYS-MOBILE-PORTAL**, FEAT-ID lane: **FEAT-MPO-WALLET-001**. Counterparts: SYS-CORE-BACKEND (nguồn sự thật), SYS-INTEGRATION-GW, SYS-BCERP-WEB, SYS-MOBILE-INTERNAL (bản nội bộ), SYS-PORTAL-WEB (bản đầy đủ — `FEAT-PORTAL-WALLET-001`). Mobile BC Portal là touchpoint rút gọn của Portal: thông báo, phê duyệt nhẹ (phi tài chính), xem số dư/tiến độ — phần tài chính **read-only tuyệt đối**.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| ID tính năng | FEAT-MPO-WALLET-001 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-OPS-003 (chính), REQ-FIN-002 (cross-dependency — ngưỡng cảnh báo nguồn FIN), REQ-FIN-017 (ràng buộc read-only + tenant isolation) |
| Người dùng liên quan | CUSTOMER (CLIENT_ADMIN, CLIENT_USER — người dùng duy nhất đăng nhập mobile portal); các vai OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS là chủ dữ liệu phía nội bộ (WEB/M-INT), không có tài khoản trên mobile portal |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 (theo REQ-OPS-003); phát hành theo gói hệ thống SYS-MOBILE-PORTAL (Phase 3 trong registry hệ thống) |
| Phụ thuộc | Bản CORE của REQ-OPS-003/REQ-FIN-002 (engine ADS 7 ngày rolling, bộ đếm SLA đỏ, sổ lệnh ví), GW (dữ liệu tươi ≤1h, degraded `manual`), view ví lọc tenant theo REQ-FIN-017 (dùng chung SYS-PORTAL-WEB), bản FEAT-PORTAL-WALLET-001 của portal web |
| Ghi chú Expert (A7) | Operations.md Mục A7 chờ đánh giá chính thức; yêu cầu đối chiếu chéo REQ-OPS-002/003 với finance.md — đã đối chiếu REQ-FIN-002/003/004/010/017 và CMS Domain Model (§3.5/3.6/3.8/3.10, §5) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa việc theo dõi ví tiền giữ hộ TKQC lên điện thoại của khách hàng ở dạng rút gọn: khách tự xem số dư theo loại tiền tệ, chi tiêu daily, số ngày chi dự kiến và mức cảnh báo Xanh/Vàng/Đỏ của tenant mình, đồng thời nhận **push notification** khi ví chuyển mức để chủ động nạp thêm qua AM, tránh campaign dừng đột ngột. Mọi thao tác tạo/duyệt lệnh tài chính nằm hoàn toàn ở hệ thống nội bộ — app chỉ quan sát.

**Phạm vi:**
- Bao gồm:
  - Số dư khả dụng + bị đóng băng per-khách per-tiền tệ (USD/VND tách sổ), kèm timestamp và disclaimer độ trễ 15 phút – 24 giờ.
  - Chi tiêu daily, số ngày chi dự kiến và mức Xanh/Vàng/Đỏ per TKQC/nền tảng — chỉ render kết quả engine CORE tính sẵn theo REQ-FIN-002, không tự tính trên app.
  - Push notification khi ví tenant mình chuyển mức cảnh báo; nội dung rút gọn, không kèm số dư trên lock screen.
  - Lịch sử lệnh ví chỉ đọc, bản rút gọn của portal web: dòng điều chỉnh gắn giá vốn hiển thị thành "Điều chỉnh đối soát"; deep-link sang BC Portal Web tải sổ phụ PDF có watermark.
  - Cấu hình nhận thông báo per-thiết bị (bật/tắt push, mức cảnh báo muốn nhận) của chính user khách.
- Không bao gồm:
  - Mọi hành động ghi dữ liệu tài chính: tạo/duyệt lệnh nạp-top-up, điều chỉnh số dư, đổi tỷ giá tay, hoàn tiền, bật rebate — thuộc WEB + CORE (REQ-OPS-003, REQ-FIN-001/003/004). "Phê duyệt nhẹ" của touchpoint này chỉ áp dụng cho luồng phi tài chính (ticket/xác nhận tiến độ).
  - Tính ADS, bộ đếm SLA đỏ 2h, escalation owner → TL → AM, on-call — thuộc CORE và SYS-MOBILE-INTERNAL; app không hiển thị trạng thái escalation nội bộ.
  - Đối trừ 3 số, chốt/khóa kỳ, rule engine AML T1–T6, KYC/UBO — thực thi ở CORE (REQ-FIN-004/009/010); app chỉ nhận kết quả đã lọc.
  - Xuất sổ phụ PDF trực tiếp trên mobile — delegate về Portal Web qua deep-link để giữ touchpoint rút gọn và tái dùng watermark; quản trị tài khoản portal thuộc REQ-OPS-010.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | CUSTOMER (CLIENT_USER) | Mở app thấy ngay số dư khả dụng + bị đóng băng theo từng tiền tệ (USD/VND tách biệt), kèm thời điểm cập nhật + disclaimer độ trễ | Biết quỹ còn bao nhiêu mọi lúc, không phải hỏi AM |
| 2 | CUSTOMER (CLIENT_USER) | Nhận push khi ví tenant mình chuyển xuống Vàng/Đỏ | Chủ động nạp thêm kịp, tránh campaign dừng giữa chừng |
| 3 | CUSTOMER (CLIENT_USER) | Xem chi tiêu daily và số ngày chi dự kiến per TKQC/nền tảng kèm màu cảnh báo do BC phân | Ưu tiên nạp đúng ví sắp cạn thay vì đoán |
| 4 | CUSTOMER (CLIENT_ADMIN) | Xem lịch sử rút gọn các lệnh ví đã duyệt của tenant mình (nạp, top-up, điều chỉnh đối soát, hoàn tiền) kèm trạng thái | Đối chiếu nhanh với sổ kế toán nội bộ khi di chuyển |
| 5 | CUSTOMER (CLIENT_ADMIN) | Bấm deep-link từ app sang BC Portal Web tải sổ phụ PDF có watermark | Có chứng từ đầy đủ cho kiểm toán, app vẫn gọn nhẹ |
| 6 | CUSTOMER (CLIENT_USER) | Tự bật/tắt push theo mức cảnh báo cho từng thiết bị | Nhận đúng thông báo cần, không bị phiền mức thấp |
| 7 | OPS_AM (stakeholder nội bộ, không dùng mobile portal) | Biết khách đã tự nhận push cảnh báo ví, có thể nạp trước khi tôi liên hệ | Giảm nhắc nạp thủ công, tập trung đúng khách khi ví đỏ theo SLA 2h luồng nội bộ |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Ví là **tiền giữ hộ per-khách, multi-currency** (CMS §3.5): `availableBalance`/`frozenBalance` tách theo `currency` — USD và VND là 2 sổ độc lập, **không gộp quy đổi** ở bất kỳ màn hình nào. Mọi thay đổi số dư phát sinh từ **lệnh giao dịch tiền** (nạp/top-up/reduction/điều chỉnh/hoàn) do nội bộ tạo và duyệt; snapshot fee %, VAT %, tỷ giá chốt **tại thời điểm giao dịch** (CMS §3.8), không tham chiếu sống tới Contract. App hiển thị đúng đơn vị tiền gốc. | API từ chối trả dữ liệu gộp quy đổi hoặc giao dịch không có lệnh gốc, ghi log bảo mật; app không có màn cộng tổng USD+VND |
| BR-002 | Lệnh top-up tuân **công thức k = 1 + feePercent × (1 + vatOnFeePercent) + vatOnSpendPercent** (CMS §5): nhập NSQC (NET) → grossAmount trừ ví = netAmount × k; nhập Tổng tiền (GROSS) → netAmount vào TKQC = grossAmount / k. App chỉ hiển thị các cấu phần (net, fee, VAT/phí, VAT/chi tiêu, gross) từ **snapshot đã khóa**; không có màn tính thử bằng % hiện hành của Contract. | Không có endpoint nào cho app tính với % Contract hiện tại; snapshot thiếu cấu phần → dòng giao dịch báo lỗi dữ liệu, loại khỏi statement deep-link |
| BR-003 | Mức cảnh báo do engine CORE tính theo REQ-FIN-002: average daily spend **7 ngày rolling** per TK/nền tảng; **Xanh** (đủ chi ≥3 ngày) / **Vàng** (<3 ngày) / **Đỏ** (<1 ngày hoặc dưới mức tối thiểu nền tảng). Chuỗi SLA đỏ 2h + escalation owner (0–2h) → TL (quá 2h) → AM (quá 4h) chạy ở hệ thống nội bộ (WEB/M-INT) — app **không chứa bộ đếm SLA hay nút escalation**. App nhận push khi ví tenant mình chuyển mức, phân phối **≤5 phút từ lúc sync phát hiện**; body push chỉ chứa mức + tên TK đại diện, không chứa số dư (an toàn lock screen). | App không tự tính lại ADS hay đổi màu theo logic client; push kèm số dư chi tiết là lỗi bảo mật; mất kết nối CORE → hiển thị cache kèm nhãn độ trễ, không push trạng thái suy diễn |
| BR-004 | **Điều chỉnh số dư, đổi tỷ giá tay, hoàn tiền** bắt buộc dual approval theo công tắc toàn hệ thống `SINGLE/DUAL` (CMS §3.6): `DUAL` duyệt **tuần tự** — bước 1 do kế toán viên (map **FIN_L1**), bước 2 do kế toán trưởng (map **FIN_L2**), cấm đảo thứ tự, cấm cùng 1 người duyệt cả 2 bước; `SINGLE` một người trong FIN_L1/FIN_L2/BOD_CFO_CTO duyệt 1 lần. App **chỉ hiển thị lệnh đã duyệt xong** trong lịch sử số dư; lệnh đang xử lý chỉ hiện trạng thái chờ, không đổi số dư khả dụng. | App không có nút tạo/duyệt giao dịch tài chính để bypass; gọi endpoint ghi bị chặn ở gateway (HTTP 403) + log bảo mật; hiện số tiền lệnh `PENDING`/`STEP1_APPROVED` như đã chấp nhận là lỗi |
| BR-005 | **Đối trừ 3 số tự động** (sổ ví – platform – ngân hàng) chạy ở CORE theo REQ-FIN-004, dung sai: đối nạp sai số tuyệt đối = 0/dòng/ngày; chi tiêu ≤0,5% hoặc ≤10 USD/TK/ngày; tích lũy ≤1% hoặc ≤20 USD/khách/tuần; kỳ **chốt & khóa** — sau chốt chặn sửa/xóa chứng từ ở tầng dữ liệu. App chỉ hiển thị **trạng thái đối soát mức khách** (Đã đối soát / Đang đối soát) kèm nhãn kỳ đã chốt. | App không hiển thị ticket discrepancy, con số dung sai hay người giải trình; statement deep-link ghi rõ "kỳ đã chốt" |
| BR-006 | **AML monitoring T1–T6** (rule engine ngưỡng cấu hình được, không sửa code) + khai báo **UBO ≥25%** + **hoàn tiền đúng nguồn**: lệnh hoàn chỉ trả về TK nguồn nạp trùng tên pháp nhân KYC, cấm hoàn bên thứ ba, đổi beneficiary chặn mặc định (T4 đỏ). Biên AML do FIN_L2 xử lý, BOD oversight. App không hiển thị trường cảnh báo AML, hồ sơ KYC/UBO hay ghi chú điều tra; lịch sử hoàn tiền chỉ hiện bản **đã duyệt**. | API trả thừa trường nhạy cảm về client → chặn ở view whitelist + log bảo mật; không cấu hình nào tắt được monitoring AML |
| BR-007 | **Rebate mặc định TẮT** cho toàn bộ AdAccount/Contract (CMS §3.10): Finance/Admin bật tay `rebateEnabled` per-trường-hợp, số tiền **nhập tay theo quý** (bảng tier ngân sách chỉ tham khảo, không auto-apply); rebate tách khỏi công thức top-up BR-002. App chỉ hiển thị rebate statement **đã duyệt** (kỳ, số tiền, ghi chú) của hợp đồng có bật. | Không tự tính hay gợi ý số rebate trên app; hợp đồng chưa bật rebate → mục rebate ẩn hoàn toàn thay vì hiển thị 0 |
| BR-008 | **Read-only tuyệt đối** phần tài chính (REQ-FIN-017): app không có hành động ghi dữ liệu tài chính nào. Mọi màn hình số dư/chi tiêu có **disclaimer độ trễ 15 phút – 24 giờ** kèm timestamp; ảnh statement lưu/chia sẻ từ app gắn **watermark** tenant + user + thời điểm (kế thừa portal web). | Endpoint ghi hướng vào dữ liệu ví bị chặn ở gateway — HTTP 403 + log bảo mật; thiếu disclaimer/watermark là lỗi nghiệm thu chặn release |
| BR-009 | **Tenant isolation 2 lớp**: dữ liệu cho app chỉ qua **view tổng hợp đã lọc tenant** dùng chung portal web (RLS DB + filter API), app không chạm DB nội bộ. Khách chỉ thấy số dư, chi tiêu daily, trạng thái đối soát mức khách, lịch sử lệnh của mình; **không thấy** giá vốn, chiết khấu, P&L, ghi chú nội bộ, dữ liệu tenant khác — dòng điều chỉnh giá vốn mask thành **"Điều chỉnh đối soát"**. | Truy vấn không có tenant context bị từ chối trước khi chạm view; test isolation bắt buộc ≥2 tenant trước release; rò rỉ giá vốn/chéo tenant là sự cố bảo mật nghiêm trọng nhất của module |
| BR-010 | Dữ liệu số dư/chi tiêu từ GW: tươi **≤1h** theo pull hourly; connector lỗi hoặc chưa có quyền API → dữ liệu degraded gắn nhãn **`manual`** + nguồn + timestamp (DI-007 — degraded mode là trạng thái vận hành chính thức tới khi có Business Verification). App được **cache offline** nhưng cache phải gắn nhãn "dữ liệu cũ", không cho thao tác trên cache; mở app hoặc bấm push → luôn fetch trạng thái thật từ CORE. | Hiển thị số liệu thiếu nhãn nguồn/timestamp là lỗi; push không phải nguồn sự thật — bấm push phải thấy dữ liệu fresh từ server |
| BR-011 | **Bảo mật mobile:** phiên đăng nhập gắn tenant-scoped token; mở khóa bằng sinh trắc học/PIN thiết bị; app ở background → che số dư; push token gắn `user_id` + `tenant_id`, thu hồi ngay khi user bị vô hiệu hóa hoặc đăng xuất thiết bị. | Push tới thiết bị đã đăng xuất là lỗi; screenshot app switcher lộ số dư là lỗi nghiệm thu; mất thiết bị → thu hồi phiên qua portal web (REQ-OPS-010) |

---

## 4. Phân Quyền

| Hành động | CUSTOMER (CLIENT_USER) | CUSTOMER (CLIENT_ADMIN) | OPS_* (PLAN/AM/CONT/DES/EDIT/ADS) | FIN_L1/FIN_L2 | SYS_ADMIN |
|-----------|------------------------|-------------------------|-----------------------------------|---------------|-----------|
| Xem số dư ví tenant mình (multi-currency) trên mobile | ✅ | ✅ | ❌ | ❌ | ❌ |
| Xem chi tiêu daily + số ngày chi dự kiến + mức Xanh/Vàng/Đỏ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Nhận push cảnh báo chuyển mức ví tenant mình | ✅ (tự bật/tắt) | ✅ (tự bật/tắt) | ❌ (nhận push qua M-INT — bản nội bộ) | ❌ | ❌ |
| Xem lịch sử lệnh ví tenant mình (đã mask giá vốn, bản rút gọn) | ✅ | ✅ | ❌ | ❌ | ❌ |
| Deep-link sang Portal Web tải sổ phụ PDF (watermark) | ❌ | ✅ | ❌ | ❌ | ❌ |
| Cấu hình push per-thiết bị của chính mình | ✅ | ✅ | ❌ | ❌ | ❌ |
| Tạo/duyệt lệnh ví, điều chỉnh số dư, đổi tỷ giá, hoàn tiền | ❌ | ❌ | ❌ (chỉ trên WEB/M-INT — REQ-FIN-003) | ✅ (WEB/M-INT) | ❌ |
| Cấu hình ngưỡng cảnh báo, công tắc SINGLE/DUAL, bật rebate | ❌ | ❌ | ❌ | ✅ (WEB — FIN_L2/BOD_CFO_CTO) | ✅ (WEB nội bộ) |
| Cấp/thu hồi tài khoản portal & thu hồi phiên thiết bị | ❌ | ✅ (user dưới quyền mình) | ❌ (OPS_AM cấp qua REQ-OPS-010) | ❌ | ❌ |

> Lưu ý: ô ❌ với vai OPS/FIN nghĩa là **không có quyền trên mobile portal** — vai này thao tác lệnh ví đầy đủ ở hệ thống nội bộ (WEB/SYS-MOBILE-INTERNAL, counterpart REQ-OPS-003); touchpoint khách không tồn tại nút duyệt tài chính để loại nguy cơ bypass. SYS_ADMIN cấu hình hạ tầng push nhưng không thấy dữ liệu ví tenant.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Khách có nhiều ví theo tiền tệ:** ví USD và ví VND hiển thị 2 thẻ riêng, không có màn cộng tổng theo tỷ giá; khi đổi loại dịch vụ (tất toán hợp đồng cũ — hoàn số dư trong 15 ngày làm việc — mở hợp đồng mới theo CMS §1), lịch sử lệnh vẫn gắn vẹn theo Customer.
- **Push không tới được thiết bị:** thiết bị offline, token hết hạn hoặc user tắt push → app đánh dấu thông báo "chưa đọc" trong notification center in-app; nguồn sự thật là trạng thái trên server khi fetch — không suy diễn trạng thái ví từ việc nhận/không nhận push.
- **Lệnh chưa hoàn tất duyệt:** khách thấy dòng "Chờ phê duyệt" (`PENDING`/`STEP1_APPROVED` của luồng DUAL) nhưng số dư khả dụng chỉ đổi khi lệnh `APPROVED` — app tách bạch "số dư sổ" và "lệnh đang xử lý" ở 2 khối riêng.
- **Refund khẩn (TKQC bị khóa, nạp trùng):** duyệt nhanh qua kênh khẩn nội bộ (BOD_CFO_CTO), chứng từ hợp thức hóa trong 24h; dòng hoàn tiền chỉ xuất hiện trên app khi lệnh `APPROVED`, kèm dẫn chiếu nạp gốc (mask theo BR-006).
- **Dữ liệu degraded `manual`:** số liệu nhập tay hiển thị kèm nhãn `manual` + nguồn + timestamp; disclaimer nói rõ chất lượng dữ liệu để khách không tranh chấp đối soát với AM.
- **Khách chậm nạp khi ví đỏ:** nội bộ đánh dấu rủi ro gián đoạn chi tiêu, FIN_L2 có thể tạm giữ phần giải ngân tương ứng (nguyên tắc tiền giữ hộ — BR-FIN-104); app không hiển thị trạng thái rủi ro nội bộ, khách chỉ nhận liên hệ trực tiếp từ AM theo escalation.
- **Nhiều thiết bị trên một user:** mỗi thiết bị có push token và cấu hình thông báo riêng; thu hồi một thiết bị không ảnh hưởng thiết bị khác; toàn bộ phiên thu hồi được từ portal web.
- **Giả định chờ xác nhận (không tự quyết):** cờ cảnh báo mở rộng ngoài Xanh/Vàng/Đỏ (K6–K12) chưa chốt `[KXN-20]` — chốt xong sẽ mở rộng push theo mức mới, không đổi kiến trúc read-only; mốc PAUSE non-payment 15/30 ngày chưa có trong nguồn v2.3 `[KXN-22]` — nếu được duyệt sẽ hiển thị trạng thái PAUSE ở màn ví; ranh giới scope "hiện tại – tương lai" của CMS liên quan module ví `[KXN-9]`. Các KXN còn mở khác (6, 7, 15–19, 21) thuộc proposal/HR/CRM, không ảnh hưởng spec này.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Lệnh giao dịch ví (`RechargeRequest` nạp, `TopupTransaction` top-up, `ReductionTransaction` reduction, lệnh điều chỉnh/hoàn tiền) — entity chủ của lịch sử hiển thị trên app. Mobile BC Portal là **quan sát viên chỉ đọc**; mọi chuyển trạng thái xảy ra ở CORE, app chỉ nhận kết quả.

**Sơ đồ trạng thái (chế độ DUAL):**
```
[PENDING] ──(duyệt bước 1 — FIN_L1/ACCOUNTANT)──► [STEP1_APPROVED] ──(duyệt bước 2 — FIN_L2/CHIEF_ACCOUNTANT)──► [APPROVED]
    │                                                   │
    │ (từ chối — lý do bắt buộc)                        │ (từ chối — lý do bắt buộc)
    ▼                                                   ▼
[REJECTED] ◄──────── khách khiếu nại [DISPUTED] ────────┘ (quay lại review)
```
Chế độ `SINGLE` (công tắc toàn hệ thống, cấu hình khi phòng kế toán đủ người): `PENDING → APPROVED | REJECTED` sau 1 lần duyệt bởi FIN_L1/FIN_L2/BOD_CFO_CTO.

**Bảng chuyển đổi (app chỉ nhận kết quả hiển thị):**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `PENDING` | Duyệt bước 1 (DUAL) | `STEP1_APPROVED` | FIN_L1 (ACCOUNTANT) | Người duyệt ≠ người đề xuất; ghi danh tính + timestamp |
| `STEP1_APPROVED` | Duyệt bước 2 (DUAL) | `APPROVED` | FIN_L2 (CHIEF_ACCOUNTANT) | Tuần tự đúng cấp; cấm cùng 1 người cả 2 bước |
| `PENDING` / `STEP1_APPROVED` | Từ chối | `REJECTED` | FIN_L1 / FIN_L2 | Lý do từ chối bắt buộc |
| `REJECTED` | Khách khiếu nại | `DISPUTED` | CUSTOMER (qua AM/ticket, không qua app) | Quay lại vòng review theo CMS §3.6 |
| `APPROVED` | Thực thi giao dịch | Ghi sổ ví (append-only) | Hệ thống | Snapshot fee %/tỷ giá đã khóa; app cập nhật số dư ở lần fetch kế tiếp |

**Quy tắc:**
- Không quay về trạng thái trước; `APPROVED` và `REJECTED` (hết khiếu nại) là trạng thái kết thúc.
- App chỉ hiển thị lệnh `APPROVED` trong lịch sử ảnh hưởng số dư; lệnh đang xử lý nằm ở mục riêng.
- Mọi chuyển trạng thái ghi audit log bất biến ở CORE; app không tự suy diễn trạng thái từ push hay cache.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `Wallet` | `customer_id`, `currency`, `availableBalance`, `frozenBalance` | FK → `Customer.id` | Per-khách per-currency; USD/VND tách sổ, không gộp quy đổi (CMS §3.5) |
| `WalletTransaction` | `type` (recharge/topup/reduction/adjustment/refund), `amount`, `currency`, `state`, `snapshot` (fee %, VAT %, tỷ giá), `paymentMethod` | FK → `Wallet.id`, `Contract.id` | Append-only; snapshot khóa sau ghi nhận (CMS §3.6/3.8) |
| `RechargeRequest` | `approvalMode` (SINGLE/DUAL), `state`, người đề xuất/duyệt bước 1/2, `paymentMethod` | FK → `Wallet.id` | Công tắc toàn hệ thống; DUAL tuần tự FIN_L1 → FIN_L2 (CMS §3.6) |
| `PortalWalletView` | `tenant_id`, `balance_by_currency`, `daily_spend`, `days_of_runway`, `alert_level`, `last_updated`, `data_source` (`api`/`manual`) | Đọc từ `Wallet` + engine CORE | RLS DB + filter API; dùng chung PORTAL-WEB và M-PORTAL (REQ-FIN-017) |
| `PortalAdjustmentHistoryView` | `transaction_id`, `display_type` ("Điều chỉnh đối soát"), `masked_fields[]`, `state`, `timestamp` | Đọc từ `WalletTransaction`, mask trước khi trả | Whitelist trường; watermark khi xuất statement qua portal web |
| `MobileDevice` | `user_id`, `tenant_id`, `push_token`, `platform` (iOS/Android), `push_opt_in`, `last_seen` | FK → `CLIENT_USER.id`, `tenant_id` | Thu hồi token khi đăng xuất/user bị vô hiệu hóa (BR-011) |
| `AlertNotification` | `tenant_id`, `wallet_id`, `alert_level` (XANH/VANG/DO), `channel` (push/in-app), `sent_at`, `read_at`, `payload_masked` | FK → `Wallet.id`, `MobileDevice.id` | Body push không chứa số dư chi tiết; ≤5 phút từ lúc sync phát hiện (BR-003) |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được.*
> **Ghi chú:** Acceptance Criteria được điền chi tiết ở Phase 5 (implementation tasks). Phase 2 ghi phác thảo sơ bộ.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Xem số dư multi-currency | Khách có ví USD 5.000 và ví VND 120.000.000 | CLIENT_USER mở tab ví trên app | 2 thẻ tách biệt theo tiền gốc, có timestamp + disclaimer; không tổng quy đổi; che số dư khi app background | [ ] |
| SC-002: Push chuyển mức cảnh báo | CORE phân 1 TK của tenant từ Xanh xuống Đỏ | Sync phát hiện và phân phối thông báo | Push tới thiết bị opt-in trong ≤5 phút từ lúc sync, body không chứa số dư; mở app thấy mức Đỏ đúng kết quả CORE | [ ] |
| SC-003: Mask giá vốn | Lịch sử có 1 dòng điều chỉnh giá vốn | Khách mở lịch sử lệnh trên app | Dòng hiển thị "Điều chỉnh đối soát"; không trường giá vốn/chiết khấu/P&L trả về client | [ ] |
| SC-004: Lệnh chưa duyệt không đổi số dư | 1 lệnh đang `STEP1_APPROVED` (DUAL) | Khách xem số dư + mục đang xử lý | Số dư khả dụng không đổi; lệnh hiện "Chờ phê duyệt" ở khối riêng | [ ] |
| SC-005: Tenant isolation | Tồn tại tenant A và B | CLIENT_USER của A gọi API truy chéo B từ app | HTTP 403 + log bảo mật; không bản ghi B ở mọi endpoint | [ ] |
| SC-006: Deep-link statement watermark | CLIENT_ADMIN bấm tải sổ phụ từ app | Deep-link mở Portal Web | PDF tải từ portal có watermark tenant + người tải + thời điểm; kỳ đã chốt ghi rõ | [ ] |
| SC-007: Offline cache + nhãn dữ liệu cũ | App mất mạng 3 giờ | Khách mở tab ví offline | Cache hiển thị kèm nhãn "dữ liệu cũ" + timestamp; không cho thao tác; có mạng tự fetch lại | [ ] |

> **Liên kết:** SC-001/003/005/006/007 → REQ-OPS-003 (M-PORTAL) + REQ-FIN-017; SC-002 → REQ-OPS-003 + REQ-FIN-002 (mệnh đề mobile); SC-004 → REQ-OPS-003 + REQ-FIN-003 (dual approval).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` (view `PortalWalletView`, `PortalAdjustmentHistoryView`, RLS tenant, bảng `MobileDevice`/`AlertNotification`) |
| API Endpoints | `technical-specs/api-contract.md` (endpoint mobile wallet read-only + push registration) |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (CORE → PORTAL/M-PORTAL view feed; GW freshness ≤1h; degraded `manual`; push pipeline ≤5 phút) |
| Màn hình UI | `phase4-ux/mobile-portal/wallet-recon/[screen-group].md` |
| Bản counterpart nội bộ | `phase2-features/core-backend/wallet-recon/` (engine cảnh báo, sổ lệnh), `phase2-features/integration-gw/wallet-recon/` (data plane), `phase2-features/mobile-internal/wallet-recon/` (bản nội bộ — push SLA, duyệt ngoài giờ), `phase2-features/portal-web/wallet-recon/` (bản đầy đủ — `FEAT-PORTAL-WALLET-001`) |
| Nguồn domain | `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — Wallet §3.5, RechargeRequest §3.6, TopupTransaction §3.8, Rebate §3.10, công thức §5) |
