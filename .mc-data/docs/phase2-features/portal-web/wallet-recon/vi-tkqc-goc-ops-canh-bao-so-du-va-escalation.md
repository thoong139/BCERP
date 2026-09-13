# Tính Năng: Ví TKQC Góc Ops — Cảnh Báo Số Dư & Escalation (Client Portal)

> **Dựa trên:** REQ-OPS-003 trong `phase1-business/departments/operations/operations.md` (Phần A, B.2); cross-dependency REQ-FIN-002 trong `phase1-business/departments/finance/finance.md` (ngưỡng cảnh báo nguồn FIN); ràng buộc hiển thị theo REQ-FIN-017
> **Phân hệ:** Cổng thông tin khách hàng (SYS-PORTAL-WEB)
> **Module:** Ví & Đối soát TKQC (MOD-WALLET-RECON)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/departments/finance/finance.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/portal-web/wallet-recon/[screen-group].md`, `phase5-implementation/tasks/portal-web/wallet-recon/`

> **Hướng dẫn ID:** REQ-OPS-003 fan-out ra 6 hệ thống; đây là bản riêng của touchpoint **SYS-PORTAL-WEB**, FEAT-ID lane: **FEAT-PORTAL-WALLET-001**. Counterparts: SYS-CORE-BACKEND (nguồn sự thật), SYS-INTEGRATION-GW, SYS-BCERP-WEB, SYS-MOBILE-INTERNAL, SYS-MOBILE-PORTAL (bản khách rút gọn).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-PORTAL-WALLET-001 |
| Module | MOD-WALLET-RECON |
| Yêu cầu nghiệp vụ | REQ-OPS-003 (chính), REQ-FIN-002 (cross-dependency — ngưỡng cảnh báo nguồn FIN), REQ-FIN-017 (ràng buộc portal read-only) |
| Người dùng liên quan | CUSTOMER (CLIENT_ADMIN, CLIENT_USER); các vai OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS là chủ dữ liệu phía nội bộ (WEB/M-INT), không có tài khoản thao tác trên portal |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | Bản CORE của REQ-OPS-003/REQ-FIN-002 (engine ADS 7 ngày rolling, bộ đếm SLA đỏ, sổ lệnh ví), GW (dữ liệu số dư/chi tươi ≤1h, degraded `manual`), view ví tổng hợp lọc tenant theo REQ-FIN-017 |
| Ghi chú Expert (A7) | Operations.md Mục A7 chờ đánh giá chính thức; ghi chú hiện tại yêu cầu đối chiếu chéo REQ-OPS-002/003 với finance.md — đã đối chiếu REQ-FIN-002/003/004/017 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cho phép khách hàng tự theo dõi trên Client Portal ví tiền giữ hộ dùng để chi trả TKQC: số dư theo loại tiền tệ, chi tiêu daily, số ngày chi dự kiến và lịch sử mọi lệnh đã duyệt. Tính năng minh bạch hóa dữ liệu ví — vốn trước đây khách phải hỏi AM — mà vẫn bảo vệ tuyệt đối giá vốn và dữ liệu nội bộ của BC.

**Phạm vi:**
- Bao gồm:
  - Số dư ví per-khách per-tiền tệ (USD, VND tách biệt, không gộp quy đổi): khả dụng + bị đóng băng, kèm timestamp và disclaimer độ trễ.
  - Chi tiêu daily, số ngày chi dự kiến và mức cảnh báo Xanh/Vàng/Đỏ per TKQC/nền tảng — chỉ render kết quả engine CORE tính sẵn, không tự tính.
  - Lịch sử lệnh ví (nạp, top-up, reduction, điều chỉnh đối soát, hoàn tiền) dạng chỉ đọc, đã mask giá vốn; trạng thái đối soát mức khách; tải sổ phụ PDF có watermark + disclaimer độ trễ 15 phút – 24 giờ.
- Không bao gồm:
  - Tạo/duyệt lệnh, điều chỉnh số dư, đổi tỷ giá tay, hoàn tiền — thuộc WEB + CORE (counterpart nội bộ REQ-OPS-003, REQ-FIN-001/003/004); portal **read-only tuyệt đối**.
  - Tính ADS, bộ đếm SLA 2h, escalation owner → TL → AM, push alert — thuộc CORE và M-INT; AM liên hệ khách khi ví đỏ.
  - Đối trừ 3 số, chốt/khóa kỳ, AML T1–T6, Rebate — thực thi ở CORE (REQ-FIN-004/010); portal chỉ nhận kết quả đã lọc.
  - Bản mobile khách (SYS-MOBILE-PORTAL) viết spec riêng; cấp/thu hồi tài khoản portal thuộc REQ-OPS-010.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | CUSTOMER (CLIENT_USER) | Xem số dư ví khả dụng và bị đóng băng theo từng loại tiền tệ (USD/VND tách biệt), kèm timestamp + disclaimer độ trễ | Chủ động biết quỹ còn bao nhiêu, hiểu đúng bản chất dữ liệu gần thời gian thực, không phải hỏi AM |
| 2 | CUSTOMER (CLIENT_USER) | Xem chi tiêu daily và số ngày chi dự kiến per TKQC/nền tảng kèm mức Xanh/Vàng/Đỏ | Biết trước ví nào sắp cạn để nạp thêm, tránh campaign dừng giữa chừng |
| 3 | CUSTOMER (CLIENT_ADMIN) | Xem lịch sử lệnh ví của tenant mình (nạp, top-up, điều chỉnh đối soát, hoàn tiền) kèm trạng thái duyệt và trạng thái đối soát kỳ ở mức tổng quan | Đối chiếu nội bộ với sổ kế toán của công ty tôi, tin rằng giao dịch đã qua kiểm soát của BC |
| 4 | CUSTOMER (CLIENT_ADMIN) | Tải sổ phụ ví PDF có watermark | Lưu chứng từ cho kiểm toán nội bộ và đối soát với bên thứ ba |
| 5 | CUSTOMER (CLIENT_USER) | Thấy nhãn "Điều chỉnh đối soát" thay cho chi tiết phí/markup ở các dòng điều chỉnh | Nắm dòng tiền thay đổi số dư mà không đụng cấu phần giá vốn |
| 6 | OPS_AM (stakeholder nội bộ, không dùng portal) | Biết khách đã tự xem số dư/lịch sử ví trên portal | Giảm câu hỏi trao đổi dữ liệu thường ngày, tập trung liên hệ khách đúng lúc ví đỏ theo SLA 2h |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Ví là **tiền giữ hộ per-khách, multi-currency** (CMS §3.5): `availableBalance`/`frozenBalance` tách theo `currency` — USD và VND là 2 sổ độc lập, **không gộp quy đổi** ở bất kỳ màn hình nào. Mọi thay đổi số dư phát sinh từ **lệnh giao dịch tiền** (nạp/top-up/reduction/điều chỉnh/hoàn) do nội bộ tạo và duyệt; snapshot fee % và tỷ giá chốt tại thời điểm giao dịch (CMS §3.8). Portal hiển thị theo đúng đơn vị tiền gốc của từng sổ. | API portal từ chối render dữ liệu gộp quy đổi hoặc giao dịch không có lệnh gốc, ghi log bảo mật; giao dịch không lệnh gốc không bao giờ xuất hiện trên view khách |
| BR-002 | Lệnh top-up tuân **công thức k = 1 + feePercent × (1 + vatOnFeePercent) + vatOnSpendPercent** (CMS §5): nhập NSQC (NET) → grossAmount trừ ví = netAmount × k; nhập Tổng tiền (GROSS) → netAmount vào TKQC = grossAmount / k. Các cấu phần hiển thị chỉ lấy từ **snapshot** đã khóa, không tham chiếu sống tới Contract. | Portal không cho tính thử/phục chế bằng % hiện tại của Contract; snapshot thiếu cấu phần → dòng giao dịch báo lỗi dữ liệu và bị chặn khỏi statement xuất file |
| BR-003 | Mức cảnh báo do engine CORE tính theo REQ-FIN-002: average daily spend **7 ngày rolling** per TK/nền tảng; 3 mức **Xanh** (đủ chi ≥3 ngày) / **Vàng** (<3 ngày) / **Đỏ** (<1 ngày hoặc dưới mức tối thiểu nền tảng). Ví đỏ kích hoạt SLA **2h làm việc**: owner (OPS_ADS/OPS_AM) tạo lệnh top-up hoặc giảm ngân sách; escalation có timestamp: owner (0–2h) → TL (quá 2h) → AM (quá 4h, liên hệ khách nạp trong ngày làm việc); ngoài giờ qua on-call. Chuỗi này ở hệ thống nội bộ; portal chỉ hiển thị mức màu của tenant mình kèm thời điểm tính. | Portal không tự tính lại ADS hay đổi màu theo logic riêng; mất kết nối CORE → hiển thị dữ liệu cũ kèm nhãn độ trễ; portal không gửi yêu cầu nạp thay AM |
| BR-004 | **Điều chỉnh số dư, đổi tỷ giá tay, hoàn tiền** bắt buộc dual approval theo công tắc toàn hệ thống `SINGLE/DUAL` (CMS §3.6): `DUAL` duyệt **tuần tự** — bước 1 do kế toán viên (map vai **FIN_L1**), bước 2 do kế toán trưởng (map **FIN_L2**), cấm đảo thứ tự, cấm cùng 1 người duyệt cả 2 bước; `SINGLE` một người trong FIN_L1/FIN_L2/BOD_CFO_CTO duyệt 1 lần. Portal **chỉ hiển thị lệnh sau khi hoàn tất phê duyệt**. | Lệnh chưa hoàn tất duyệt (`PENDING`/`STEP1_APPROVED`) chỉ hiện trạng thái chờ, không hiện số tiền như đã chấp nhận; nỗ lực truy lệnh của tenant khác bị chặn ở tầng API filter |
| BR-005 | **Đối trừ 3 số tự động** (sổ ví – platform – ngân hàng) chạy ở CORE theo REQ-FIN-004, dung sai: đối nạp sai số tuyệt đối = 0/dòng/ngày; chi tiêu ≤0,5% hoặc ≤10 USD/TK/ngày; tích lũy ≤1% hoặc ≤20 USD/khách/tuần; kỳ **chốt & khóa** — sau chốt chặn sửa/xóa chứng từ ở tầng dữ liệu. Portal hiển thị **trạng thái đối soát mức khách** (Đã đối soát / Đang đối soát). | Portal không hiển thị ticket discrepancy, dung sai chi tiết hay người giải trình; kỳ đã khóa → statement xuất file phải ghi rõ "kỳ đã chốt" để khách đối chiếu bản chốt |
| BR-006 | **AML monitoring T1–T6** (ngưỡng cấu hình được, không sửa code) + khai báo **UBO ≥25%** + **hoàn tiền đúng nguồn**: chỉ trả về TK nguồn nạp trùng tên pháp nhân KYC, cấm hoàn bên thứ ba, đổi beneficiary bị từ chối mặc định. Biên AML do FIN_L2 xử lý với BOD oversight (không có vai FIN_COMPL — quyết định DI-006). Portal chỉ hiển thị hoàn tiền **đã duyệt** trong lịch sử. | Portal không expose bất kỳ trường cảnh báo AML, hồ sơ KYC/UBO hay ghi chú điều tra; API trả thừa trường nhạy cảm → chặn ở view whitelist + log bảo mật rà soát |
| BR-007 | **Rebate mặc định TẮT** cho toàn bộ AdAccount/Contract (CMS §3.10): Finance/Admin bật tay `rebateEnabled` per-trường-hợp, số tiền **nhập tay theo quý** (bảng tier ngân sách chỉ tham khảo, không auto-apply); rebate tách khỏi công thức top-up BR-002. Portal chỉ hiển thị rebate statement **đã duyệt** (kỳ, số tiền, ghi chú) của hợp đồng có bật. | Không tự tính hay gợi ý số rebate trên portal; hợp đồng chưa bật rebate → mục rebate ẩn hoàn toàn thay vì hiện 0 |
| BR-008 | Portal **read-only tuyệt đối** (REQ-FIN-017): không có hành động ghi dữ liệu tài chính nào (tạo/duyệt lệnh, sửa số dư, upload chứng từ tiền). Mọi download gắn **watermark** tenant + người tải + thời điểm; mọi màn hình số dư/chi tiêu có **disclaimer độ trễ** 15 phút – 24 giờ kèm timestamp cập nhật cuối. | Endpoint ghi hướng vào dữ liệu ví bị chặn ở gateway — HTTP 403 + log bảo mật; thiếu watermark/disclaimer là lỗi nghiệm thu chặn release |
| BR-009 | **Tenant isolation 2 lớp**: dữ liệu cấp portal chỉ qua **view tổng hợp đã lọc tenant** (RLS DB + filter API), portal không chạm DB nội bộ, tách network zone. Khách chỉ thấy số dư, chi tiêu daily, trạng thái đối soát mức khách, lịch sử lệnh của mình; **không thấy** giá vốn, chiết khấu, P&L, ghi chú nội bộ, dữ liệu tenant khác — dòng điều chỉnh giá vốn mask thành **"Điều chỉnh đối soát"**. | Truy vấn không có tenant context bị từ chối trước khi chạm view; test isolation bắt buộc ≥2 tenant trước release; rò rỉ giá vốn/chéo tenant là sự cố bảo mật nghiêm trọng nhất của module |
| BR-010 | Dữ liệu số dư/chi tiêu portal tiêu thụ từ GW: tươi **≤1h** theo vòng pull hourly; khi connector lỗi hoặc chưa có quyền API, dữ liệu degraded gắn nhãn **`manual`** + nguồn + timestamp (DI-007 — degraded mode là trạng thái vận hành chính thức tới khi có Business Verification). Portal hiển thị nhãn nguồn để khách hiểu chất lượng số liệu. | Hiển thị số liệu không kèm nhãn nguồn/timestamp là lỗi; nguồn `manual` → statement xuất file phải ghi chú nhập tay để tránh tranh chấp đối soát |

---

## 4. Phân Quyền

| Hành động | CUSTOMER (CLIENT_USER) | CUSTOMER (CLIENT_ADMIN) | OPS_* (PLAN/AM/CONT/DES/EDIT/ADS) | FIN_L1/FIN_L2 | SYS_ADMIN |
|-----------|------------------------|-------------------------|-----------------------------------|---------------|-----------|
| Xem số dư ví tenant mình (multi-currency) | ✅ | ✅ | ❌ | ❌ | ❌ |
| Xem chi tiêu daily + số ngày chi dự kiến tenant mình | ✅ | ✅ | ❌ | ❌ | ❌ |
| Xem lịch sử lệnh ví tenant mình (đã mask giá vốn) | ✅ | ✅ | ❌ | ❌ | ❌ |
| Xem trạng thái đối soát mức khách + lệnh hoàn tiền đã duyệt | ✅ | ✅ | ❌ | ❌ | ❌ |
| Tải sổ phụ ví PDF (watermark) | ❌ | ✅ | ❌ | ❌ | ❌ |
| Tạo/duyệt lệnh ví, điều chỉnh số dư, đổi tỷ giá, hoàn tiền | ❌ | ❌ | ❌ | ✅ (WEB/M-INT — REQ-FIN-003) | ❌ |
| Cấu hình ngưỡng cảnh báo, công tắc SINGLE/DUAL, bật rebate | ❌ | ❌ | ❌ | ✅ (WEB — FIN_L2/BOD_CFO_CTO) | ✅ (WEB nội bộ) |
| Cấp/thu hồi tài khoản portal | ❌ | ✅ (user dưới quyền mình) | ❌ (OPS_AM cấp qua REQ-OPS-010) | ❌ | ❌ |

> Lưu ý: các ô ❌ với vai OPS/FIN nghĩa là **không có quyền trên portal** — vai này thao tác lệnh ví đầy đủ ở hệ thống nội bộ (counterpart REQ-OPS-003); portal không tồn tại nút duyệt để loại nguy cơ bypass.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Khách có nhiều ví theo tiền tệ:** ví USD và ví VND hiển thị 2 sổ riêng, không có màn hình cộng tổng theo tỷ giá; khi đổi loại dịch vụ (tất toán hợp đồng cũ — hoàn số dư trong 15 ngày làm việc — mở hợp đồng mới theo CMS §1), lịch sử lệnh vẫn gắn vẹn theo Customer.
- **Lệnh chưa hoàn tất duyệt:** khách thấy dòng lệnh "Chờ phê duyệt" (`PENDING`/`STEP1_APPROVED` của luồng DUAL) nhưng số dư khả dụng chỉ đổi khi lệnh `APPROVED` — portal tách bạch "số dư sổ" và "lệnh đang xử lý".
- **Refund khẩn (TKQC bị khóa, nạp trùng):** duyệt nhanh qua kênh khẩn nội bộ (BOD_CFO_CTO), chứng từ hợp thức hóa trong 24h; dòng hoàn tiền chỉ xuất hiện khi lệnh `APPROVED`, kèm dẫn chiếu giao dịch nạp gốc.
- **Dữ liệu degraded `manual`:** khi GW chưa có quyền API hoặc connector lỗi, số liệu hiển thị từ nhập tay có nhãn `manual` + nguồn + timestamp; disclaimer nói rõ chất lượng dữ liệu để tránh tranh chấp đối soát.
- **Khách chậm nạp khi ví đỏ:** nội bộ đánh dấu rủi ro gián đoạn chi tiêu, FIN_L2 có thể tạm giữ giải ngân tương ứng (nguyên tắc tiền giữ hộ — BR-FIN-104); portal không hiển thị trạng thái rủi ro nội bộ, chỉ AM liên hệ khách.
- **Tenant user bị vô hiệu hóa / hết hợp đồng:** toàn bộ phiên đăng nhập kết thúc khi thu hồi user (REQ-OPS-010); dữ liệu ví còn trong view nhưng không ai đăng nhập được tới khi cấp tài khoản mới.
- **Giả định chờ xác nhận (không tự quyết):** cờ cảnh báo mở rộng ngoài Xanh/Vàng/Đỏ (K6–K12) chưa chốt `[KXN-20]`; mốc PAUSE non-payment 15/30 ngày chưa có trong nguồn v2.3 `[KXN-22]`; ranh giới scope "hiện tại – tương lai" của CMS liên quan module ví `[KXN-9]`. Các KXN còn mở khác (6, 7, 15–19, 21) thuộc proposal/HR/CRM, không ảnh hưởng spec này; khi chốt sẽ mở rộng hiển thị mức cảnh báo mà không đổi kiến trúc read-only.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Lệnh giao dịch ví (`RechargeRequest` nạp, `TopupTransaction` top-up, `ReductionTransaction` reduction, lệnh điều chỉnh/hoàn tiền) — entity chủ của lịch sử hiển thị trên portal. Portal là **quan sát viên chỉ đọc**; mọi chuyển trạng thái xảy ra ở CORE.

**Sơ đồ trạng thái (chế độ DUAL):**
```
[PENDING] ──(duyệt bước 1 — FIN_L1/ACCOUNTANT)──► [STEP1_APPROVED] ──(duyệt bước 2 — FIN_L2/CHIEF_ACCOUNTANT)──► [APPROVED]
    │                                                   │
    │ (từ chối — lý do bắt buộc)                        │ (từ chối — lý do bắt buộc)
    ▼                                                   ▼
[REJECTED] ◄──────── khách khiếu nại [DISPUTED] ────────┘ (quay lại review)
```
Chế độ `SINGLE` (công tắc toàn hệ thống, SYS_ADMIN cấu hình khi phòng kế toán đủ người): `PENDING → APPROVED | REJECTED` sau 1 lần duyệt bởi FIN_L1/FIN_L2/BOD_CFO_CTO.

**Bảng chuyển đổi (portal chỉ nhận kết quả hiển thị):**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `PENDING` | Duyệt bước 1 (DUAL) | `STEP1_APPROVED` | FIN_L1 (ACCOUNTANT) | Người duyệt ≠ người đề xuất; ghi danh tính + timestamp |
| `STEP1_APPROVED` | Duyệt bước 2 (DUAL) | `APPROVED` | FIN_L2 (CHIEF_ACCOUNTANT) | Tuần tự đúng cấp; cấm cùng 1 người cả 2 bước |
| `PENDING` / `STEP1_APPROVED` | Từ chối | `REJECTED` | FIN_L1 / FIN_L2 | Lý do từ chối bắt buộc |
| `REJECTED` | Khách khiếu nại | `DISPUTED` | CUSTOMER (qua AM/ticket, không qua portal) | Quay lại vòng review theo CMS §3.6 |
| `APPROVED` | Thực thi giao dịch | Ghi sổ ví (append-only) | Hệ thống | Snapshot fee %/tỷ giá đã khóa tại thời điểm giao dịch |

**Quy tắc:**
- Không quay về trạng thái trước; `APPROVED` và `REJECTED` (hết khiếu nại) là trạng thái kết thúc.
- Portal chỉ hiển thị lệnh `APPROVED` trong lịch sử số dư; lệnh đang xử lý nằm ở mục riêng, không ảnh hưởng số dư khả dụng.
- Mọi chuyển trạng thái ghi audit log bất biến ở CORE; portal không tự suy diễn trạng thái từ cache.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `Wallet` | `customer_id`, `currency`, `availableBalance`, `frozenBalance` | FK → `Customer.id` | Per-khách per-currency; USD/VND tách sổ, không gộp quy đổi (CMS §3.5) |
| `WalletTransaction` | `type` (recharge/topup/reduction/adjustment/refund), `amount`, `currency`, `state`, `snapshot` (fee %, VAT %, tỷ giá), `paymentMethod` | FK → `Wallet.id`, `Contract.id` | Append-only; snapshot khóa sau ghi nhận (CMS §3.6/3.8) |
| `RechargeRequest` | `approvalMode` (SINGLE/DUAL), `state`, người đề xuất/duyệt bước 1/2, `paymentMethod` | FK → `Wallet.id` | Công tắc toàn hệ thống; DUAL tuần tự FIN_L1 → FIN_L2 (CMS §3.6) |
| `PortalWalletView` | `tenant_id`, `balance_by_currency`, `daily_spend`, `days_of_runway`, `alert_level`, `last_updated`, `data_source` (`api`/`manual`) | Đọc từ `Wallet` + engine CORE | RLS DB + filter API; portal không chạm DB nội bộ (REQ-FIN-017) |
| `PortalAdjustmentHistoryView` | `transaction_id`, `display_type` ("Điều chỉnh đối soát"), `masked_fields[]`, `state`, `timestamp` | Đọc từ `WalletTransaction`, mask trước khi trả | Whitelist trường; watermark khi xuất statement |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được.*
> **Ghi chú:** Acceptance Criteria được điền chi tiết ở Phase 5 (implementation tasks). Phase 2 ghi phác thảo sơ bộ.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Xem số dư multi-currency | Khách có ví USD 5.000 và ví VND 120.000.000 | CLIENT_USER mở trang ví | 2 sổ hiển thị tách biệt theo tiền gốc, có timestamp + disclaimer; không tổng quy đổi | [ ] |
| SC-002: Mức cảnh báo đúng nguồn CORE | CORE phân 1 TK mức Đỏ (<1 ngày chi) | Khách xem chi tiêu daily theo TK | Màu Đỏ đúng kết quả CORE kèm thời điểm tính; portal không tự tính | [ ] |
| SC-003: Mask giá vốn | Lịch sử có 1 dòng điều chỉnh giá vốn | Khách mở lịch sử lệnh | Dòng hiển thị "Điều chỉnh đối soát"; không trường giá vốn/chiết khấu/P&L trả về client | [ ] |
| SC-004: Lệnh chưa duyệt không đổi số dư | 1 lệnh đang `STEP1_APPROVED` (DUAL) | Khách xem số dư + mục đang xử lý | Số dư khả dụng không đổi; lệnh hiện "Chờ phê duyệt" | [ ] |
| SC-005: Tenant isolation | Tồn tại tenant A và B | CLIENT_USER của A gọi API truy chéo B | HTTP 403 + log bảo mật; không bản ghi B ở mọi endpoint | [ ] |
| SC-006: Statement watermark | CLIENT_ADMIN tải sổ phụ PDF | File mở ra | Mỗi trang có watermark tenant + người tải + thời điểm; kỳ đã chốt ghi rõ | [ ] |

> **Liên kết:** SC-001/003/005/006 → REQ-OPS-003 (PORTAL) + REQ-FIN-017; SC-002 → REQ-OPS-003 + REQ-FIN-002; SC-004 → REQ-OPS-003 + REQ-FIN-003.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` (view `PortalWalletView`, `PortalAdjustmentHistoryView`, RLS tenant) |
| API Endpoints | `technical-specs/api-contract.md` (nhóm endpoint portal wallet read-only) |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (CORE → PORTAL view feed; GW freshness ≤1h; degraded `manual`) |
| Màn hình UI | `phase4-ux/portal-web/wallet-recon/[screen-group].md` |
| Bản counterpart nội bộ | `phase2-features/core-backend/wallet-recon/` (engine cảnh báo, sổ lệnh), `phase2-features/integration-gw/wallet-recon/` (data plane), `phase2-features/mobile-portal/wallet-recon/` (bản M-PORTAL rút gọn) |
| Nguồn domain | `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — Wallet §3.5, RechargeRequest §3.6, TopupTransaction §3.8, Rebate §3.10, công thức §5) |
