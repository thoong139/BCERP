# Tính Năng: KYC Pháp Nhân Trước Cấp Phát TKQC

> **Dựa trên:** REQ-FIN-009 trong `phase1-business/departments/finance/finance.md` (Phần A3, Phần B.4 — BR-FIN-401/405)
> **Phân hệ:** Tài chính — Kiểm soát rủi ro & Tuân thủ (SYS-CORE-BACKEND)
> **Module:** Quản lý Tài khoản Quảng cáo — Ad Account Command Center (MOD-ADACCOUNT-CC)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `phase1-business/departments/operations/operations.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/adaccount-cc/[screen-group].md`, `phase5-implementation/tasks/core-backend/adaccount-cc/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`, do lane fan-out của `/wf-define-features` cấp. REQ-FIN-009 fan-out ra 2 systems (SYS-CORE-BACKEND, SYS-BCERP-WEB) — bản này là bản riêng cho **SYS-CORE-BACKEND** (FEAT-CORE-ADACC-001); counterpart: FEAT trên SYS-BCERP-WEB (màn nhập/đính kèm/quản lý hồ sơ). Tra `req-registry.json` để xác nhận SYS và MOD tương ứng.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-ADACC-001 |
| Module | MOD-ADACCOUNT-CC (SYS-CORE-BACKEND — BCERP Core Backend, headless API/domain service) |
| Yêu cầu nghiệp vụ | REQ-FIN-009 (KYC pháp nhân trước cấp phát TKQC) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO (chính); OPS_AM, OPS_ADS (thu thập hồ sơ, gặp gate); SYS_ADMIN (cấu hình) |
| Độ ưu tiên | Cao (HIGH · MVP · GĐ1) |
| Giai đoạn | Giai đoạn 1 |
| Phụ thuộc | Không có feature bắt buộc phải làm trước; là gate đầu vào của luồng cấp phát TKQC (FEAT-CORE-ADACC-002, FEAT-CORE-ADACC-003) — cả hai đều phải gọi gate KYC này trước khi mở khóa cấp phát |
| Ghi chú Expert (A7) | Chưa có điều chỉnh từ Expert Review — Mục A7 trong `finance.md` và `operations.md` đang ở trạng thái "chờ review"; không có nội dung điều chỉnh nào để tổng hợp tại thời điểm viết |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Định danh pháp nhân khách hàng (KYC) là điều kiện tiên quyết trước khi hệ thống cho phép cấp phát bất kỳ tài khoản quảng cáo (TKQC) nào. Feature này xây dựng **gate KYC chạy trên core backend**: lưu trữ hồ sơ pháp nhân, quản lý trạng thái xác minh do FIN_L2 gán, và chặn cứng ở tầng service mọi hành động cấp phát TKQC khi trạng thái KYC ≠ `Verified` — không phụ thuộc UI, không vai nào có nút bỏ qua.

**Phạm vi:**
- Bao gồm: lưu trữ hồ sơ KYC pháp nhân 5 thành phần (GPKD, MST, giấy tờ người đại diện pháp luật, TK ngân hàng trùng tên, khai báo UBO); vòng đời trạng thái hồ sơ KYC (`DRAFT → PENDING_APPROVAL → VERIFIED/REJECTED → EXPIRED`); gate đọc trạng thái KYC tại thời điểm cấp phát TKQC trong module MOD-ADACCOUNT-CC; luồng EDD (enhanced due diligence) cho khách nước ngoài/khu vực rủi ro cao/flag Knockout K2–K4; ngoại lệ tài khoản không trùng tên pháp nhân (nhóm mẹ/con); nhắc review định kỳ tự động (12 tháng chuẩn / 6 tháng EDD); retention hồ sơ; audit log bất biến toàn bộ chuyển trạng thái; tenant isolation theo khách.
- Không bao gồm: màn hình nhập/đính kèm hồ sơ cho người dùng (delegate cho counterpart trên SYS-BCERP-WEB); rule engine giám sát giao dịch AML T1–T6 và hoàn tiền đúng nguồn (REQ-FIN-010 — feature riêng); đối soát và xác nhận "đã khớp tiền" (REQ-FIN-006 / FEAT-CORE-ADACC-003); quy trình duyệt hồ sơ mở TK mới theo OADS state machine (REQ-OPS-001 / FEAT-CORE-ADACC-002); Knockout chấm lead ở tầng CRM/SALES (chỉ tiêu thụ cờ K2–K4 từ đó).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L2 | Nhận hồ sơ KYC đã được OPS_AM thu thập và nhập trên WEB, xác minh 5 thành phần (đối chiếu MST với nguồn chính thức, kiểm tra tên chủ TK ngân hàng trùng tên pháp nhân) rồi gán trạng thái `Verified` qua API của CORE | Chỉ khách đã định danh rõ ràng mới được đi tiếp vào luồng cấp phát TKQC — tôi là người giữ cổng định danh, không phải ai nhập hồ sơ cũng tự "đạt" |
| 2 | FIN_L2 | Từ chối hồ sơ thiếu/sai kèm lý do bắt buộc, và lý do này tự động ghi vào CRM gắn với khách | Bên OPS/Sales thấy ngay cần bổ sung gì, và tôi có dấu vết giải trình khi bị hỏi lại |
| 3 | FIN_L1 | Khi tạo lệnh nạp/hoàn, hệ thống tự khớp tên chủ tài khoản nhận với tên pháp nhân đã KYC và từ chối giao dịch lệch tên (trừ ngoại lệ nhóm mẹ/con đã duyệt) | Tiền chỉ luân chuyển giữa các tài khoản trùng định danh đã xác minh — giảm rủi ro rửa tiền qua ví TKQC |
| 4 | BOD_CFO_CTO | Duyệt ngoại lệ tài khoản không trùng tên (pháp nhân cùng nhóm mẹ/con, có văn bản chứng thực) và phê duyệt các hồ sơ EDD sâu | Tôi kiểm soát tập trung các ngoại lệ rủi ro cao thay vì rải quyền duyệt cho tuyến dưới |
| 5 | OPS_AM | Gửi hồ sơ khách vào quy trình KYC (đẩy từ phía thu thập), theo dõi trạng thái và được hệ thống nhắc khi hồ sơ sắp quá hạn review định kỳ | Khách của tôi không bị kẹt ở gate KYC lúc sắp khởi động chiến dịch, và hồ sơ không âm thầm hết hạn |
| 6 | OPS_ADS | Bị hệ thống chặn hành động cấp phát TKQC kèm thông báo mã lỗi rõ ràng khi khách chưa `Verified` | Tôi hiểu ngay điểm nghẽn nằm ở hồ sơ KYC của khách nào, liên hệ đúng người (FIN_L2) thay vì đoán |
| 7 | SYS_ADMIN | Cấu hình thời hạn review chuẩn/EDD và danh sách quốc gia rủi ro cao (đồng bộ FATF) mà không cần sửa code | Khi quy định AML thay đổi, vận hành điều chỉnh bằng cấu hình có audit log |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Toàn bộ rule enforce tại tầng service của core backend; UI chỉ hiển thị, không được tin là điểm kiểm soát.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Gate bắt buộc:** hành động "cấp phát TKQC" (tạo `AdAccount`/`Contract` mới trong OADS) chỉ thực thi được khi trạng thái KYC của pháp nhân khách = `Verified` tại thời điểm gọi API. Service layer tự đọc trạng thái hiện hành từ DB (không nhận tham số trạng thái từ client, không cache Verified ở UI). Nguồn: BR-FIN-401. | API trả lỗi chặn (kèm mã lý do: thiếu thành phần nào), ghi vào CRM + audit log; UI WEB hiển thị trạng thái khóa |
| BR-002 | **Hồ sơ 5 thành phần bắt buộc** trước khi FIN_L2 được xét `Verified`: (1) GPKD/giấy tờ tương đương còn hiệu lực — khách nước ngoài hợp pháp hóa lãnh sự khi cần; (2) MST đối chiếu nguồn chính thức; (3) giấy tờ người đại diện pháp luật; (4) TK ngân hàng nạp/hoàn trùng tên pháp nhân; (5) khai báo UBO từ 25% sở hữu thụ hưởng (mức mặc định đã chốt theo DI-001, chi tiết trong policy `aml-kyc-giam-sat-giao-dich.md`). | Không đủ 5/5 → API từ chối yêu cầu xét `Verified`; lý do thiếu thành phần ghi vào CRM |
| BR-003 | **Tách bạch thu thập và xác minh (SoD):** OPS_AM/OPS_ADS chỉ thu thập/nhập/đính kèm hồ sơ; **duy nhất FIN_L2** được gán/thu hồi trạng thái `Verified` qua API (hành động privileged, xác thực lại vai + quyền tại service layer, bắt buộc reason code). Người nhập hồ sơ không tự xác minh hồ sơ của mình. | API từ chối vai không đúng; sự cố ghi audit log |
| BR-004 | **EDD bắt buộc khi:** khách nước ngoài; quốc gia/vùng rủi ro cao (danh sách FATF hoặc BOD cập nhật — cấu hình được); lead flag Knockout K2/K4. Hệ quả: hồ sơ sâu hơn + phê duyệt BOD_CFO_CTO, ngưỡng AML T1–T6 tự siết 50%, chu kỳ review 6 tháng thay vì 12 tháng. | Thiếu phê duyệt BOD cho hồ sơ EDD → không được xét `Verified` |
| BR-005 | **Review định kỳ tự động:** hồ sơ `Verified` hết hạn sau 12 tháng (chuẩn) / 6 tháng (EDD) — job định kỳ của CORE chuyển trạng thái sang `Expired` và bắn nhắc cho FIN_L2; hồ sơ `Expired` làm gate KYC đóng lại (chặn cấp phát TKQC mới cho khách đó). | Gate từ chối cấp phát với mã "KYC hết hạn review" |
| BR-006 | **Ngoại lệ TK không trùng tên:** chỉ chấp nhận khi là pháp nhân cùng nhóm mẹ/con, đủ 3 điều kiện đồng thời: văn bản chứng thực + BOD_CFO_CTO duyệt qua hệ thống + cập nhật hồ sơ KYC. Ngoại lệ có thời hạn và gắn với hồ sơ KYC cụ thể. | Chưa đủ 3 điều kiện → BR-003/BR-001 tiếp tục chặn như thường lệ |
| BR-007 | **Khách tập đoàn nhiều pháp nhân:** chỉ các pháp nhân nằm trong danh sách được phép "liệt kê trắng" trong hợp đồng mới được liên kết KYC với khách đó; toàn bộ diện này bắt buộc kèm EDD. | API từ chối liên kết pháp nhân ngoài danh sách |
| BR-008 | **Knockout không thay thế KYC:** kết quả lọc lead Knockout (bất kể K1–K5) không được dùng làm căn cứ miễn KYC, và không miễn giám sát giao dịch. | Mọi nỗ lực ghi trạng thái Verified từ tín hiệu Knockout bị từ chối ở tầng domain |
| BR-009 | **Retention:** hồ sơ KYC/EDD, biên bản, quyết định lưu tập trung, truy xuất theo khách/TKQC/giao dịch, giữ **≥5 năm** kể từ kết thúc quan hệ khách hàng (mức khởi điểm theo thông lệ AML — `[CẦN CHỐT SỐ — luật sư/tư vấn AML xác nhận]`, không tự quyết trong spec này); hồ sơ thuộc phiên thanh tra/điều tra đang mở → giữ đến khi hồ sơ đóng, bất kể hết hạn retention. | Job dọn dữ liệu không được xóa bản ghi chưa đủ hạn/đang gắn hồ sơ pháp lý |
| BR-010 | **Audit log bất biến:** mọi chuyển trạng thái KYC ghi `ai (user, role) — khi nào (timestamp) — làm gì — old→new value — reason code bắt buộc`; account DB của ứng dụng chỉ INSERT/SELECT trên bảng log (không tồn tại interface xóa/sửa ở mọi tầng, kể cả Super Admin); sửa dữ liệu nhập sai = ghi giao dịch reversal, không đè bản ghi gốc. | Thiếu reason code → yêu cầu không được submit; đứt hash-chain → alert CTO + BOD_CEO |
| BR-011 | **Tenant isolation:** mọi truy vấn hồ sơ KYC scop cứng theo tenant (khách) tại tầng service; vai FIN/OPS chỉ thấy hồ sơ theo phạm vi được phân quyền; dữ liệu KYC là thông tin nhạy cảm — không trả về portal khách (SYS-PORTAL-WEB/SYS-MOBILE-PORTAL không có endpoint đọc hồ sơ KYC). | Truy vấn vượt tenant bị từ chối và ghi audit log bảo mật |

---

## 4. Phân Quyền

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | OPS_AM / OPS_ADS | SYS_ADMIN | CUSTOMER (portal) |
|-----------|--------|--------|-------------|------------------|-----------|-------------------|
| Xem hồ sơ KYC (theo phạm vi tenant được gán) | ✅ | ✅ | ✅ | ✅ (chỉ trạng thái + lý do bị chặn) | ✅ | ❌ (không có endpoint; chỉ cung cấp giấy tờ qua AM) |
| Nhập/đính kèm/nộp lại hồ sơ KYC | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ |
| Xác minh & gán trạng thái `Verified` | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Từ chối hồ sơ (kèm lý do ghi vào CRM) | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Duyệt ngoại lệ TK không trùng tên (nhóm mẹ/con) | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Phê duyệt hồ sơ EDD | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Cấu hình thời hạn review, danh sách quốc gia rủi ro | ❌ | ❌ | ✅ (phê duyệt thay đổi) | ❌ | ✅ (thực thi cấu hình, có audit log) | ❌ |
| Xem báo cáo AML/KYC định kỳ (tháng) | ✅ | ✅ (tổng hợp) | ✅ | ❌ | ❌ | ❌ |
| Xóa/sửa bản ghi audit log KYC | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (không tồn tại — mọi vai) |

> Ghi chú touchpoint: mọi quyền trên enforce bằng kiểm tra vai tại tầng API của core backend (headless); counterpart trên SYS-BCERP-WEB chỉ render theo kết quả ủy quyền, không quyết định. Vai "TL (Team Lead)" trong policy quy trình được ánh xạ vào **OPS_PLAN** theo registry 18 vai; trong feature này OPS_PLAN không có quyền thao tác hồ sơ KYC.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Khách nước ngoài:** giấy tờ tương đương GPKD phải hợp pháp hóa lãnh sự khi cần; hệ thống lưu cờ quốc gia → tự kích hoạt EDD và siết ngưỡng AML 50% theo BR-004; không có luồng "đặc cách" bỏ bước xác minh.
- **Tập đoàn nhiều pháp nhân:** chỉ pháp nhân nằm trong danh sách liệt kê trắng của hợp đồng được gắn KYC với khách; pháp nhân mới phát sinh phải thêm vào hợp đồng + EDD trước khi được cấp phát TKQC.
- **TK ngân hàng không trùng tên:** mặc định chặn; chỉ mở khi thỏa BR-006 (nhóm mẹ/con + văn bản + BOD duyệt). Trường hợp lệch tên do lỗi nhập → FIN_L1 đối chiếu tay, kết quả ghi reason code, không tự khớp.
- **Flag Knockout K2–K4 từ CRM:** CORE tiêu thụ cờ, không đọc lại lead — nếu cờ tồn tại thì mọi luồng xét `Verified` bắt buộc đi qua BOD (BR-004); việc lead đã "pass" Knockout không tự mở gate.
- **Hồ sơ hết hạn giữa chừng quan hệ khách hàng:** khi hồ sơ chuyển `Expired`, khách đang có TKQC hoạt động không bị cắt ngay, nhưng mọi yêu cầu **cấp phát mới** và lệnh nạp mới bị gate giữ lại cho đến khi FIN_L2 hoàn tất review lại.
- **Hồ sơ trùng lặp/nhiều pháp nhân cùng MST:** hệ thống phát hiện MST trùng giữa 2 khách → chuyển rà thủ công FIN_L2, cấm tự động gộp hồ sơ; kết quả xử lý ghi audit log.
- **Người nhập hồ sơ nghỉ việc sau khi nộp:** hồ sơ vẫn nằm trong hàng chờ xác minh của FIN_L2 (không phụ thuộc người nhập); dữ liệu tenant không bị chuyển mất theo nhân sự.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Hồ sơ KYC pháp nhân (`KycProfile` — 1 khách có thể có nhiều phiên hồ sơ theo từng đợt review; trạng thái "hiện hành" của khách = trạng thái phiên mới nhất)

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit)──► [PENDING_APPROVAL] ──(verify)──► [VERIFIED] ──(hết hạn review)──► [EXPIRED]
                            │                            │                                  │
                            │ (reject + reason)          │ (revoke + reason)                │ (nộp lại)
                            ▼                            ▼                                  ▼
                        [REJECTED]                   [REVOKED]                      [PENDING_APPROVAL]
```
Trạng thái `Customer` ở tầng CMS (`documents/02_Quy_trinh_Cho_thue_TKQC.md` §3.1: `PENDING_APPROVAL | APPROVED | REJECTED`) đồng bộ theo: `VERIFIED` ⇔ `APPROVED`, `REJECTED` ⇔ `REJECTED`.

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `PENDING_APPROVAL` | OPS_AM / OPS_ADS | Đủ 5 thành phần hồ sơ + file đính kèm theo BR-002 |
| `PENDING_APPROVAL` | Verify | `VERIFIED` | FIN_L2 | 5/5 thành phần hợp lệ; MST khớp nguồn chính thức; TK ngân hàng trùng tên pháp nhân (hoặc ngoại lệ BR-006 đã BOD duyệt); diện EDD đã có phê duyệt BOD_CFO_CTO |
| `PENDING_APPROVAL` | Reject | `REJECTED` | FIN_L2 | Bắt buộc nhập lý do — tự động ghi vào CRM gắn khách |
| `VERIFIED` | Revoke | `REVOKED` | FIN_L2 (khi phát hiện hồ sơ sai/gian lận) | Reason code bắt buộc; gate KYC đóng lại ngay; các giao dịch liên quan chuyển xử lý theo luồng AML |
| `VERIFIED` | Expire | `EXPIRED` | Hệ thống (job định kỳ) | Quá 12 tháng (chuẩn) / 6 tháng (EDD) kể từ ngày Verify; hệ thống nhắc FIN_L2 trước hạn |
| `EXPIRED` / `REJECTED` | Re-submit | `PENDING_APPROVAL` | OPS_AM / OPS_ADS | Bổ sung/đính chính hồ sơ; không kế thừa kết quả xác minh cũ |

**Quy tắc:**
- Gate cấp phát TKQC chỉ đọc đúng một trạng thái: `VERIFIED` hiện hành — mọi trạng thái khác (`DRAFT`, `PENDING_APPROVAL`, `REJECTED`, `EXPIRED`, `REVOKED`) đều chặn (BR-001).
- `REVOKED` và `EXPIRED` không quay lại `VERIFIED` trực tiếp — bắt buộc đi lại `PENDING_APPROVAL` để FIN_L2 xác minh lại trên hồ sơ mới.
- Mọi chuyển trạng thái ghi audit log bất biến theo BR-010; không có trạng thái "chờ duyệt" trung gian, không có nút override, không có đường tắt nào từ `REJECTED`/`REVOKED` sang `VERIFIED`.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `KycProfile` | `customer_id`, `status` (`DRAFT/PENDING_APPROVAL/VERIFIED/REJECTED/EXPIRED/REVOKED`), `edd_flag`, `risk_country`, `knockout_flag`, `verified_by`, `verified_at`, `review_due_at` | FK → `customers.id` | 1 khách nhiều phiên; gate đọc phiên hiện hành |
| `KycDocument` | `kyc_profile_id`, `doc_type` (`GPKD/MST/LEGAL_REP/BANK_ACCOUNT/UBO`), `file_ref`, `verified_at`, `note` | FK → `kyc_profiles.id` | File lưu object store; bản ghi chỉ thêm/đảo chiều logic, không xóa |
| `KycExemption` | `kyc_profile_id`, `type` (`SAME_GROUP_NON_MATCHING_BANK`), `doc_ref`, `approved_by` (BOD), `valid_until` | FK → `kyc_profiles.id` | Ngoại lệ BR-006; hết hạn → gate đóng lại |
| `Customer` (CMS) | `status` (`PENDING_APPROVAL/APPROVED/REJECTED`), `industry`, `tax_code`, `company_info` | 1-n `KycProfile` | Theo `documents/02_Quy_trinh_Cho_thue_TKQC.md` §3.1; đồng bộ trạng thái với KYC |
| `KycAuditLog` | `actor_id`, `role`, `timestamp`, `entity`, `old_value`, `new_value`, `reason_code`, `prev_hash` | FK → đối tượng log | Append-only, hash-chain (BR-010) |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ ở Phase 2 — chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-FIN-009 (Mục 2 `finance.md`, BR-FIN-401/405).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn cấp phát khi chưa Verified (REQ-FIN-009) | Khách có `KycProfile` ở `PENDING_APPROVAL` | OPS_ADS gọi API cấp phát TKQC | API từ chối với mã lý do thiếu thành phần, ghi CRM + audit log; không tạo được `AdAccount` | [ ] |
| SC-002: Chỉ FIN_L2 gán Verified (REQ-FIN-009) | Hồ sơ đủ 5 thành phần, do OPS_AM nhập | OPS_AM tự gọi API xác minh; sau đó FIN_L2 gọi | Lời gọi của OPS_AM bị từ chối (SoD BR-003); lời gọi FIN_L2 thành công, `review_due_at` = 12/6 tháng theo cờ EDD | [ ] |
| SC-003: EDD siết ngưỡng và rút ngắn review (REQ-FIN-009) | Khách nước ngoài có cờ Knockout K2 | FIN_L2 xác minh | Bắt buộc có phê duyệt BOD_CFO_CTO trước khi `Verified`; `review_due_at` = 6 tháng; ngưỡng AML đặt mức siết 50% | [ ] |
| SC-004: Ngoại lệ nhóm mẹ/con (REQ-FIN-009) | TK ngân hàng lệch tên với pháp nhân | Kiểm tra điều kiện BR-006 | Chưa đủ văn bản + BOD duyệt → chặn; đủ 3 điều kiện → `KycExemption` tạo thành công với `valid_until`, gate mở trong hạn | [ ] |
| SC-005: Hết hạn review chặn cấp phát mới (REQ-FIN-009) | Hồ sơ `VERIFIED` quá `review_due_at` | Job định kỳ chạy | Trạng thái → `EXPIRED`; nhắc FIN_L2; API cấp phát mới của khách này bị chặn với mã "KYC hết hạn" | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (đồng bộ cờ Knockout từ CRM, ghi lý do chặn vào CRM) |
| Màn hình UI (counterpart WEB) | `phase4-ux/bcerp-web/adaccount-cc/[screen-group].md` |
| Domain model nguồn | `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — §3.1 `Customer`) |
| Policy nghiệp vụ | `policies/aml-kyc-giam-sat-giao-dich.md`, `policy quan-ly-cap-phat-tkqc-financial-hard-stop.md` |
| Feature liên quan cùng module | `kyc` gate tiêu thụ bởi `ad-account-command-center-registry-va-vong-doi-tkqc.md` (FEAT-CORE-ADACC-002) và `financial-hard-stop-chan-cap-phat-tkqc.md` (FEAT-CORE-ADACC-003) |
