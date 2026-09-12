# Tính Năng: KYC pháp nhân trước cấp phát TKQC

> **Dựa trên:** REQ-FIN-009 trong `phase1-business/departments/finance/finance.md` (Phần A, B.4)
> **Phân hệ:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** Quản lý TKQC — Ad Account Command Center (MOD-ADACCOUNT-CC)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-ADACC-001 |
| Module | MOD-ADACCOUNT-CC |
| Yêu cầu nghiệp vụ | REQ-FIN-009 — KYC pháp nhân trước cấp phát TKQC (HIGH, MVP) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO (chính); OPS_AM (thu thập hồ sơ — hỗ trợ) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — điều kiện tiên quyết trước giao dịch tiền đầu tiên) |
| Phụ thuộc | Cross-dependency REQ-OPS-001/REQ-OPS-002 — KYC gate đứng trước cấp phát TKQC trong vòng đời registry (FEAT-ERP-ADACC-002) và phối hợp Financial Hard Stop (FEAT-ERP-ADACC-003) |
| Ghi chú Expert (A7) | Điểm phối hợp liên phòng (finance.md Mục A7): REQ-FIN-006/009 — gate Hard Stop + KYC nằm trong vòng đời cấp phát TKQC do OPS vận hành, FIN nắm quyền xác nhận; Knockout K1–K5 ở tầng lead do SALES thực hiện nhưng không thay thế KYC |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng định danh pháp nhân khách hàng (KYC) là điều kiện tiên quyết trước khi cấp bất kỳ tài khoản quảng cáo (TKQC) nào, thực hiện trên web nội bộ BCERP cho nhân viên BC: nhập hồ sơ, đính kèm chứng từ, theo dõi và xác minh trạng thái. Trạng thái KYC là machine-state do core quản lý — gate cấp phát TKQC đọc trực tiếp trạng thái này và chỉ cho phép tạo AdAccount + Contract khi KYC = Verified, qua đó chặn rủi ro rửa tiền qua ví TKQC ngay từ cửa vào của vòng đời 2.600+ TKQC.

**Phạm vi:**
- Bao gồm: màn nhập và quản lý hồ sơ KYC pháp nhân với 5 thành phần bắt buộc (GPKD/giấy tờ tương đương, MST đối chiếu nguồn chính thức, giấy tờ người đại diện pháp luật, TK ngân hàng trùng tên pháp nhân, khai báo UBO từ 25%), kèm upload chứng từ có hash và phiên bản.
- Bao gồm: workflow xác minh của FIN_L2 (xem hồ sơ, đối chiếu, gán trạng thái Verified/Rejected kèm lý do bắt buộc) và luồng EDD (enhanced due diligence) khi khách nước ngoài, quốc gia FATF rủi ro cao hoặc lead flag Knockout K2/K4 — kèm phê duyệt BOD.
- Bao gồm: quản lý ngoại lệ TK ngân hàng không trùng tên pháp nhân (nhóm mẹ/con) với văn bản chứng thực + duyệt BOD, và danh sách pháp nhân liệt kê trắng trong hợp đồng cho khách tập đoàn nhiều pháp nhân.
- Bao gồm: nhắc review định kỳ tự động (12 tháng chuẩn / 6 tháng diện EDD), theo dõi hạn review trên dashboard, và lưu trữ hồ sơ KYC/EDD phục vụ truy xuất theo khách (retention ≥5 năm).
- Không bao gồm: rule engine giám sát giao dịch AML T1–T6 và xử lý cảnh báo (REQ-FIN-010 — bản MOD-WALLET-RECON); tính năng chỉ cung cấp trạng thái KYC làm đầu vào cấu hình ngưỡng siết 50% cho diện EDD.
- Không bao gồm: engine gate chặn cấp phát và Financial Hard Stop khớp tiền (FEAT-ERP-ADACC-003, REQ-FIN-006/OPS-002) — tính năng đảm bảo trạng thái KYC đúng, gate enforcement nằm ở service layer core và feature Hard Stop.
- Không bao gồm: luồng duyệt nội dung hồ sơ mở TKQC (OADS content review) và thao tác tạo AdAccount — thuộc FEAT-ERP-ADACC-002; tính năng này là gate đứng trước đó.

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-BCERP-WEB — web nội bộ responsive (Next.js); mọi thao tác ghi gọi API core, UI chỉ hiển thị đúng trạng thái machine-state của hồ sơ KYC và không cho sửa trạng thái trực tiếp trên form.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_AM | Nhập hồ sơ KYC của khách (5 thành phần bắt buộc) và đính kèm chứng từ scanned ngay trên web nội bộ | Khách được xét duyệt cấp phát TKQC mà không phải gửi file rời qua chat/email |
| 2 | FIN_L2 | Xem danh sách hồ sơ chờ xác minh, đối chiếu từng thành phần với nguồn chính thức rồi gán Verified/Rejected kèm lý do | Định danh pháp nhân có kiểm soát, người thu thập không tự xác minh hồ sơ của mình |
| 3 | FIN_L2 | Chuyển hồ sơ sang diện EDD khi khách nước ngoài, quốc gia FATF rủi ro cao hoặc có flag Knockout K2/K4 | Áp dụng chuẩn thẩm định sâu hơn với đúng nhóm khách rủi ro |
| 4 | BOD_CFO_CTO | Duyệt hồ sơ EDD và ngoại lệ TK ngân hàng không trùng tên (nhóm mẹ/con) có văn bản chứng thực | Quyết định ngoại lệ bằng văn bản, có vết, đúng thẩm quyền |
| 5 | FIN_L1 | Xem trạng thái KYC của khách trước khi xử lý khớp tiền cho lệnh nạp | Không khớp tiền cho khách chưa Verified, phối hợp chặt với gate cấp phát |
| 6 | FIN_L2 | Theo dõi dashboard hạn review KYC với nhắc tự động 12 tháng (chuẩn) / 6 tháng (EDD) | Hồ sơ không bị "Verified" vô thời hạn khi khách đã thay đổi pháp nhân/người đại diện |
| 7 | FIN_L2 | Ghi lý do từ chối/thu hồi Verified bằng văn bản và lưu vĩnh viễn vào hồ sơ + đồng bộ lý do về CRM | Lịch sử quyết định truy xuất được khi thanh tra hoặc khiếu nại |
| 8 | BOD_CFO_CTO | Xem báo cáo tổng hợp số khách theo trạng thái KYC (Verified/EDD/Rejected/quá hạn review) | Đánh giá rủi ro danh mục khách hàng theo định kỳ |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Gate đọc trạng thái KYC thực thi ở service layer của SYS-CORE-BACKEND; web là bề mặt nhập liệu và hiển thị machine-state.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Hồ sơ bắt buộc đủ 5 thành phần trước khi xét Verified: (1) GPKD/giấy tờ tương đương còn hiệu lực — khách nước ngoài hợp pháp hóa lãnh sự khi cần; (2) MST đối chiếu nguồn chính thức; (3) giấy tờ người đại diện pháp luật; (4) TK ngân hàng nạp/hoàn trùng tên pháp nhân; (5) khai báo UBO từ 25% sở hữu thụ hưởng (mức 25% đã chốt theo DI-001 ngày 12/09/2026 — mức mặc định do chuyên gia đề xuất). | Thiếu bất kỳ thành phần nào: form không cho submit ở trạng thái "đầy đủ", core từ chối yêu cầu xét Verified |
| BR-002 | KYC pháp nhân là gate bắt buộc trước cấp phát TKQC: chỉ khi KYC = Verified, luồng mở TKQC (OADS) mới được đi đến bước tạo AdAccount + Contract; trạng thái KYC do core quản lý, gate đọc trực tiếp — web không cho sửa trạng thái tại UI. | KYC ≠ Verified hoặc thiếu/sai: core chặn cấp phát kèm lý do ghi vào CRM; web hiển thị trạng thái chặn và lý do |
| BR-003 | SoD xác minh: OPS/AM thu thập và nhập hồ sơ; FIN_L2 là vai duy nhất xác minh và gán trạng thái; người nhập hồ sơ không được tự xác minh; BOD duyệt ngoại lệ và EDD. | Core block khi FIN_L2 xác minh hồ sơ do chính mình nhập; vi phạm log cho CFO rà định kỳ |
| BR-004 | EDD bắt buộc khi: khách nước ngoài; quốc gia/vùng rủi ro cao (danh sách FATF hoặc BOD cập nhật); lead flag Knockout K2/K4. Diện EDD yêu cầu hồ sơ sâu hơn + phê duyệt BOD, ngưỡng AML T1–T6 tự siết 50% (cấu hình ở module AML — REQ-FIN-010), review định kỳ 6 tháng thay vì 12 tháng. | Hồ sơ EDD chưa được BOD duyệt không thể chuyển Verified; hệ thống không cho tắt cờ EDD nếu chưa hết điều kiện |
| BR-005 | Ngoại lệ TK ngân hàng không trùng tên pháp nhân chỉ chấp nhận khi là pháp nhân cùng nhóm mẹ/con: bắt buộc văn bản chứng thực + BOD duyệt + cập nhật hồ sơ KYC; khách tập đoàn nhiều pháp nhân dùng danh sách pháp nhân liệt kê trắng trong hợp đồng + áp EDD. | Ngoại lệ không đủ văn bản/duyệt: core chặn TK ngân hàng đó khỏi việc khớp tiền và cấp phát |
| BR-006 | Review định kỳ: 12 tháng (chuẩn) / 6 tháng (EDD); hệ thống nhắc tự động trên web trước hạn; quá hạn mà chưa xác nhận lại → trạng thái chuyển "quá hạn review" và gate tái kích hoạt cấp phát mới (tạo AdAccount/Contract mới) bị chặn cho tới khi xác nhận lại xong. | Cố tình kéo dài trạng thái Verified quá hạn: hệ thống tự hạ trạng thái hiệu lực và ghi audit log; cấp phát mới bị chặn |
| BR-007 | Kết quả Knockout (lọc rủi ro tầng lead của SALES) không thay thế KYC và không miễn giám sát giao dịch — mọi khách vẫn phải qua KYC đầy đủ dù lead đã pass Knockout. | Dùng kết quả Knockout làm căn cứ bỏ qua KYC bị core từ chối — gate chỉ đọc trạng thái KYC |
| BR-008 | Lý do từ chối, lý do thu hồi Verified, kết luận EDD bắt buộc nhập văn bản; mọi quyết định ghi audit log bất biến (ai, khi nào, old→new, reason code) và đồng bộ lý do chặn về CRM; hồ sơ KYC/EDD lưu tối thiểu 5 năm kể từ kết thúc quan hệ khách hàng, hồ sơ thuộc phiên thanh tra đang mở giữ đến khi đóng. | Đóng trạng thái mà không có lý do: API từ chối; cấm hard-delete hồ sơ — sửa chỉ qua bản ghi reversal có reason code |
| BR-009 | Chứng từ KYC lưu evidence bất biến kèm hash và thời điểm nộp; mỗi lần chỉnh sửa hồ sơ tạo phiên bản mới giữ bản cũ — dùng đối chiếu khi có thay đổi pháp nhân giữa hai kỳ review. | Xóa/ghi đè chứng từ bị chặn ở mọi tầng; bất thường toàn vẹn hash báo cáo ngay cho BOD_CEO/CTO |
| BR-010 | Tích hợp với vòng đời TKQC (tham chiếu CMS Domain Model `documents/02_Quy_trinh_Cho_thue_TKQC.md` §3.2): OADS đi theo state machine DRAFT → CONTENT_REVIEWING → CS_REVIEWING → tạo AdAccount + Contract; bước CONTENT chỉ role cấp EXECUTIVE trở lên được duyệt; toàn bộ luồng này chỉ khởi động được khi KYC = Verified. | KYC chưa Verified: OADS không được tạo mới trên khách đó; yêu cầu tạo bị chặn kèm lý do |
| BR-011 | KYC gate và Financial Hard Stop là 2 điều kiện độc lập cùng phải thỏa trước cấp phát: KYC Verified (feature này) + xác nhận "đã khớp tiền" từ FIN_L1 (REQ-FIN-006 — FEAT-ERP-ADACC-003); thỏa một trong hai chưa đủ. | Thiếu bất kỳ gate nào: lệnh cấp phát bị chặn; không có cơ chế gộp hai điều kiện để bỏ qua một gate |
| BR-012 | Khách chỉ được xem phần trạng thái tổng quát của hồ sơ qua portal (GĐ3 — REQ-FIN-017), không xem nội dung thẩm định nội bộ; toàn bộ màn nhập/quản lý KYC thuộc web nội bộ SYS-BCERP-WEB. | Cấu hình portal lộ chi tiết thẩm định là lỗi bảo mật dữ liệu tài chính; tenant isolation bắt buộc |

---

## 4. Phân Quyền

Quyền do RBAC engine của core kiểm tra tại API; bảng dưới là hợp đồng UI web nội bộ. Chỉ dùng 18 vai registry; không tồn tại vai Ops CX/Fin Compliance (đã bị từ chối theo DI-006 — trách nhiệm gán về FIN_L2 xử lý + BOD oversight).

| Hành động | OPS_AM | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN |
|-----------|--------|--------|--------|-------------|-----------|
| Nhập/đính kèm hồ sơ KYC (khách phụ trách) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Xem hồ sơ + trạng thái KYC | ✅ (khách mình) | ✅ (khách được gán) | ✅ | ✅ | ❌ |
| Xác minh và gán Verified/Rejected | ❌ | ❌ | ✅ | ❌ | ❌ |
| Chuyển diện EDD | ❌ | ❌ | ✅ | ❌ | ❌ |
| Duyệt EDD / ngoại lệ trùng tên | ❌ | ❌ | ❌ | ✅ | ❌ |
| Ghi lý do từ chối/thu hồi Verified | ❌ | ❌ | ✅ | ✅ (quyết định cấp BOD) | ❌ |
| Sửa hồ sơ sau khi Verified | ✅ (tạo phiên bản mới, đưa về chờ xác minh lại) | ❌ | ✅ | ❌ | ❌ |
| Cấu hình chu kỳ nhắc review | ❌ | ❌ | ✅ | ✅ (phê duyệt) | ❌ (thực thi sau duyệt) |
| Xem báo cáo tổng hợp trạng thái KYC | ❌ | ✅ (chuẩn) | ✅ | ✅ | ❌ |
| Xóa chứng từ/bản ghi KYC | ❌ | ❌ | ❌ | ❌ | ❌ (không tồn tại interface xóa) |

SYS_ADMIN không có quyền nghiệp vụ trên hồ sơ KYC — chỉ hỗ trợ kỹ thuật hệ thống và mọi thao tác quản trị đều bị audit log; không ai (kể cả Super Admin) được xóa bản ghi KYC. Người thử việc/freelancer không được truy cập màn KYC vì chứa giấy tờ pháp lý của khách.

---

## 5. Trường Hợp Đặc Biệt

- Khách nước ngoài không có MST Việt Nam: hệ thống chấp nhận mã định nghĩa doanh nghiệp nước tương đương + hợp pháp hóa lãnh sự; FIN_L2 ghi rõ loại giấy tờ và nguồn đối chiếu vào hồ sơ — không để trống trường MST mà ghi đè bằng giá trị tương đương có chú thích.
- Khách thay đổi người đại diện pháp luật giữa hai kỳ review: hồ sơ tạo phiên bản mới, yêu cầu bổ sung giấy tờ mới; trong thời gian chờ bổ sung, trạng thái giữ Verified cũ nhưng đánh dấu "đang chờ cập nhật" — cấp phát TKQC mới vẫn cho phép, hệ thống ghi chú rủi ro.
- Tập đoàn nhiều pháp nhân với một hợp đồng khung: danh sách pháp nhân liệt kê trắng gắn vào hợp đồng, từng pháp nhân con có hồ sơ KYC riêng; một pháp nhân con bị từ chối không tự động kéo theo toàn bộ tập đoàn, nhưng buộc rà lại EDD của nhóm.
- Hồ sơ EDD chờ BOD duyệt trong lúc khách đang cần cấp phát gấp: không có đường tắt — gate giữ nguyên; OPS_AM theo dõi trạng thái trên web và chủ động phối hợp BOD, hệ thống hiển thị SLA chờ duyệt để ép tiến độ phê duyệt chứ không bỏ bước.
- Nhân viên nhập hồ sơ nghỉ việc giữa chừng: hồ sơ dở dang được OPS_AM khác tiếp nhận theo phân quyền khách phụ trách; lịch sử nhập ghi tên người nhập từng phiên bản để truy vết.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Hồ sơ KYC pháp nhân (KycProfile) — trạng thái do core quản lý, web hiển thị machine-state; gate cấp phát TKQC đọc trạng thái này theo BR-002.

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit đủ 5 thành phần)──► [SUBMITTED] ──(FIN_L2 nhận xét)──► [UNDER_REVIEW]
                                             │                              │
                                             │ (FIN_L2 từ chối + lý do)     ├─(thỏa chuẩn)──► [VERIFIED]
                                             ▼                              ├─(diện EDD)───► [EDD_REVIEW]
                                         [REJECTED]                         │                     │
                                             │  (sửa & nộp lại)             │      (BOD duyệt)    │
                                             └──────────────► [UNDER_REVIEW]◄─────────────────────┘
[VERIFIED] ──(đến hạn review 12/6 tháng)──► [REVIEW_DUE] ──(xác minh lại)──► [UNDER_REVIEW]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit hồ sơ | `SUBMITTED` | OPS_AM | Đủ 5 thành phần bắt buộc (BR-001) |
| `SUBMITTED` | Nhận xét minh | `UNDER_REVIEW` | FIN_L2 | Có hồ sơ đầy đủ, không trùng khách đang xét |
| `UNDER_REVIEW` | Duyệt Verified | `VERIFIED` | FIN_L2 | 5 thành phần hợp lệ; TK ngân hàng trùng tên (hoặc ngoại lệ BR-005 đã duyệt) |
| `UNDER_REVIEW` | Từ chối | `REJECTED` | FIN_L2 | Lý do văn bản bắt buộc, đồng bộ CRM |
| `UNDER_REVIEW` | Chuyển EDD | `EDD_REVIEW` | FIN_L2 | Đủ 1 trong 3 điều kiện EDD (BR-004) |
| `EDD_REVIEW` | Duyệt sau EDD | `VERIFIED` | BOD_CFO_CTO | Hồ sơ sâu hoàn tất + phê duyệt BOD có lý do |
| `EDD_REVIEW` | Từ chối sau EDD | `REJECTED` | BOD_CFO_CTO | Lý do văn bản bắt buộc, lưu vĩnh viễn |
| `REJECTED` | Sửa & nộp lại | `UNDER_REVIEW` | OPS_AM | Bổ sung tài liệu theo lý do từ chối |
| `VERIFIED` | Đến hạn review | `REVIEW_DUE` | Hệ thống (timer) | Hết 12 tháng (chuẩn) / 6 tháng (EDD) |
| `REVIEW_DUE` | Xác minh lại | `UNDER_REVIEW` | FIN_L2 | Không thể tạo AdAccount/Contract mới khi đang `REVIEW_DUE` |

**Quy tắc:**
- `VERIFIED` là trạng thái duy nhất mở KYC gate cho cấp phát TKQC; `REVIEW_DUE` tạm khóa cấp phát mới (TKQC đang chạy không tự dừng — chỉ chặn tạo mới, khác với thu hồi Hard Stop).
- `REJECTED` là trạng thái có thể quay lại được (sửa & nộp lại); mọi chuyển trạng thái ghi audit log bất biến old→new + reason code.
- Trạng thái `EDD_REVIEW` chỉ được xử lý bởi BOD khi FIN_L2 đã hoàn tất phần thẩm định — FIN_L2 không tự duyệt hồ sơ diện EDD.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| KycProfile | `id`, `customer_id`, `legal_name`, `tax_code`, `status`, `edd_flag`, `verified_at`, `verified_by`, `next_review_at` | FK → khách hàng (Customer) | Trạng thái là nguồn sự thật cho KYC gate |
| KycDocument | `profile_id`, `doc_type`, `file_ref`, `hash`, `uploaded_at`, `uploaded_by`, `version` | FK → `kyc_profile.id` | Evidence bất biến, versioned, không xóa |
| UboDeclaration | `profile_id`, `owner_name`, `ownership_percent`, `declared_at` | FK → `kyc_profile.id` | Ngưỡng khai báo ≥25% (DI-001) |
| KycReviewLog | `profile_id`, `action`, `old_status`, `new_status`, `reason`, `actor_id`, `acted_at` | FK → `kyc_profile.id` | Append-only, hash-chain theo chuẩn audit log |
| KycException | `profile_id`, `type` (trùng tên nhóm mẹ/con), `evidence_ref`, `approved_by`, `approved_at` | FK → `kyc_profile.id`, FK → BOD approver | Chỉ có hiệu lực khi BOD duyệt |
| WhitelistedLegalEntity | `contract_id`, `entity_name`, `tax_code` | FK → hợp đồng | Danh sách pháp nhân liệt kê trắng cho tập đoàn + EDD |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Thiếu thành phần không submit | Hồ sơ thiếu khai báo UBO | OPS_AM bấm submit | Form chặn, liệt kê thiếu thành phần; không tạo yêu cầu xét Verified | [ ] |
| SC-002: Gate chặn cấp phát | KYC khách = `UNDER_REVIEW` | Luồng OADS đi đến bước tạo AdAccount + Contract | Core chặn kèm lý do, ghi vào CRM; web hiển thị trạng thái chặn | [ ] |
| SC-003: EDD siết ngưỡng | Khách nước ngoài diện EDD được Verified | Core áp cấu hình AML | Ngưỡng T1–T6 của khách tự siết 50%; chu kỳ review = 6 tháng | [ ] |
| SC-004: SoD xác minh | OPS_AM vừa nhập hồ sơ | Cùng tài khoản cố gắng gán Verified | Bị core từ chối với lý do tách vai; vi phạm được log | [ ] |
| SC-005: Ngoại lệ trùng tên | TK ngân hàng tên công ty mẹ | FIN_L2 duyệt không có văn bản | Chặn — chỉ mở khi có văn bản chứng thực + BOD duyệt; hồ sơ cập nhật | [ ] |
| SC-006: Quá hạn review | Verified 12 tháng không xác minh lại | Timer chuyển trạng thái | Trạng thái `REVIEW_DUE`; tạo AdAccount/Contract mới bị chặn; nhắc hiển thị trên web | [ ] |
| SC-007: Lý do bắt buộc | FIN_L2 từ chối hồ sơ | Đóng mà không nhập lý do | API từ chối; audit log không ghi nhận quyết định thiếu lý do | [ ] |

> **Liên kết:** SC-001…SC-007 map về REQ-FIN-009 (Mục 2 — 5 thành phần hồ sơ, gate trước cấp phát, EDD, ngoại lệ, review định kỳ).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/adaccount-cc/kyc-phap-nhan.md` |
| Bản fan-out counterpart | `phase2-features/core-backend/adaccount-cc/` (KYC gate engine, KYC profile service) — REQ-FIN-009 xuất hiện ở 2 systems (SYS-CORE-BACKEND + SYS-BCERP-WEB) |
| Nguồn domain | `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — §3.1 Customer, §3.2 OadsRequest) |
