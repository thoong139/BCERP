# Tính Năng: Ad Account Command Center — registry & vòng đời TKQC

> **Dựa trên:** REQ-OPS-001 trong `phase1-business/departments/operations/operations.md` (Phần A, B.1)
> **Phân hệ:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** Quản lý TKQC — Ad Account Command Center (MOD-ADACCOUNT-CC)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-ADACC-002 |
| Module | MOD-ADACCOUNT-CC |
| Yêu cầu nghiệp vụ | REQ-OPS-001 — Ad Account Command Center — registry & vòng đời TKQC (HIGH, MVP) |
| Người dùng liên quan | OPS_ADS (chính), OPS_AM, OPS_PLAN, OPS_CONT, OPS_DES, OPS_EDIT |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — thay thế quản lý 2.600+ TKQC rời rạc bằng registry trung tâm) |
| Phụ thuộc | Không có cross-dependency ngoài module; trong module phối hợp chặt với FEAT-ERP-ADACC-001 (KYC gate) và FEAT-ERP-ADACC-003 (Hard Stop gate) tại bước chuyển "Khớp tiền → Cấp phát" |
| Ghi chú Expert (A7) | Operations.md Mục A7: chưa có đánh giá chính thức (chờ review); ghi nhận REQ-OPS-002/003 phối hợp FIN cần đối chiếu chéo khi department file khác hoàn tất — đã phản ánh qua cross-dependency với FEAT-ERP-ADACC-003 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Xây dựng Command Center trên web nội bộ BCERP — registry trung tâm quản lý hơn 2.600 tài khoản quảng cáo (TKQC) trên 7 nền tảng (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) với vòng đời 5 trạng thái (Khởi tạo → Khớp tiền → Cấp phát → Vận hành → Thu hồi/Đóng), ownership chặt (1 khách + 1 owner + 1 backup), naming/UTM chuẩn hóa, die account tracking kèm evidence bất biến và thu hồi access 24h. Đồng thời tính năng bao phủ luồng yêu cầu mở TKQC mới (OADS) theo state machine của CMS Domain Model và cơ chế thay thế tài khoản (ReplacementRequest) khi TK bị khóa.

**Phạm vi:**
- Bao gồm: màn hình Command Center — danh sách registry toàn bộ TKQC với số dư, spend limit, trạng thái vòng đời và trạng thái platform (ACTIVE/FROZEN/BLOCKED/OUT_OF_MONEY), bộ lọc theo khách/platform/owner, freshness của dữ liệu đồng bộ.
- Bao gồm: form đăng ký TKQC mới, gán owner/backup ngay từ đăng ký, sinh mã theo naming convention `[ClientCode]-[Platform]-[Objective]-[Market]-[YYMM]` với UTM tự sinh và chặn sửa tay; import mở sổ từ Google Sheets có kiểm soát.
- Bao gồm: die account tracking — upload evidence (snapshot số dư, thông báo platform, timestamp) vào evidence store bất biến, kích hoạt TK dự phòng; thu hồi access 24h khi nhận sự kiện nghỉ/chuyển từ HR.
- Bao gồm: luồng OADS (yêu cầu mở TKQC) theo state machine DRAFT → CONTENT_REVIEWING → CS_REVIEWING → tạo AdAccount + Contract ACTIVE (duyệt CONTENT chỉ cấp EXECUTIVE trở lên, từ chối kèm reason + evidence); ReplacementRequest do CS/AM gán tay với chuỗi lịch sử thay thế qua `replacesAdAccountId`, `isCustomerFault` quyết định SLA miễn phí; quản lý Contract với `serviceType` (RENTAL/MANAGED) bất biến, `pmsProjectId` chỉ set khi MANAGED.
- Không bao gồm: engine chặn Financial Hard Stop và xác nhận khớp tiền (FEAT-ERP-ADACC-003 — REQ-OPS-002/REQ-FIN-006); Command Center chỉ hiển thị trạng thái gate và tiêu thụ kết quả.
- Không bao gồm: hồ sơ KYC pháp nhân và trạng thái Verified (FEAT-ERP-ADACC-001 — REQ-FIN-009); luồng OADS chỉ khởi động khi KYC gate đã mở.
- Không bao gồm: đồng bộ số dư hourly 7 nền tảng qua Integration Gateway và ví TKQC góc ops (REQ-FIN-005, REQ-OPS-003 — bản GW và MOD-WALLET-RECON); web chỉ hiển thị dữ liệu đã đồng bộ kèm nhãn nguồn.

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-BCERP-WEB — web nội bộ responsive (Next.js): form/list/workflow UI cho nhân viên BC, gọi API core và hiển thị đúng trạng thái machine-state (vòng đời TKQC, OADS, ReplacementRequest); dữ liệu số dư/spend do GW đồng bộ, web không nhập trực tiếp.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_ADS | Xem toàn bộ 2.600+ TKQC trong một registry với số dư, spend limit, vòng đời, lọc theo khách/platform/owner | Quản lý danh mục TK tập trung thay vì Sheets rời rạc và tra cứu trong vài giây |
| 2 | OPS_ADS | Đăng ký TKQC mới qua form chuẩn (khách/platform/dự án/owner/backup) với mã naming tự sinh | TK mới luôn đúng chuẩn ngay từ đầu, không ai đặt tên tùy tiện |
| 3 | OPS_CONT | Soạn và đẩy hồ sơ mở TKQC (OADS) qua các bước duyệt nội dung theo cấp bậc của mình | Hồ sơ ngành hàng/giấy phép được kiểm soát chất lượng trước khi lên cấp EXECUTIVE+ duyệt |
| 4 | OPS_CONT (từ EXECUTIVE trở lên) | Bấm duyệt/từ chối OADS kèm reason + evidence khi ở bước CONTENT_REVIEWING | Chỉ người đủ cấp ra quyết định compliance theo whitelist ngành |
| 5 | OPS_AM | Tạo ReplacementRequest gán tay TK thay thế khi TK bị khóa không do lỗi khách, ghi nhận isCustomerFault | Khách nhận account thay thế + chuyển số dư đúng cam kết SLA và biết trường hợp nào miễn phí |
| 6 | OPS_ADS | Ghi nhận die account và upload evidence (snapshot số dư, thông báo platform, timestamp) ngay trên web | Bằng chứng die chụp tại thời điểm xảy ra, dùng khi khiếu nại platform và đánh giá rủi ro nạp mới |
| 7 | OPS_DES / OPS_EDIT | Xem danh sách TKQC gắn với dự án mình phụ trách (read-only) | Biết TK nào đang chạy để gắn pixel/tracking và phối hợp chạy creative đúng TK |
| 8 | OPS_ADS | Import mở sổ từ Google Sheets có kiểm soát (validate schema, preview, ghi nhận nguồn) | Chuyển đổi từ quản lý thủ công sang registry mà không mất dữ liệu lịch sử |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Registry, vòng đời, naming validator và state machine thực thi ở service layer SYS-CORE-BACKEND; web chặn sớm ở form nhưng không phải lớp enforcement chính. Nguồn domain: CMS Domain Model (`documents/02_Quy_trinh_Cho_thue_TKQC.md` §3.2–§3.4, §3.11, §4) + policy `quan-ly-cap-phat-tkqc-financial-hard-stop.md` §2.2–2.4.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Registry trung tâm quản lý mọi TKQC trên 7 nền tảng với vòng đời 5 trạng thái: Khởi tạo → Khớp tiền → Cấp phát → Vận hành → Thu hồi/Đóng; song song hiển thị trạng thái platform (ACTIVE/FROZEN/BLOCKED/OUT_OF_MONEY); mọi chuyển trạng thái ghi audit log bất biến (ai, khi nào, từ/sang trạng thái nào, căn cứ). | TK không nằm trong registry không được nạp tiền/chạy campaign; sửa trạng thái ngoài luồng bị core từ chối |
| BR-002 | Ownership: mỗi TK đúng 1 khách + 1 owner + 1 backup, tối đa 2 quyền edit; cấm dùng chung email/mật khẩu/2FA; cảnh báo TK thiếu owner/backup và owner sắp nghỉ; đổi owner/backup do OPS_PLAN (TL) duyệt trong ≤1 ngày làm việc. | Vi phạm chia sẻ login: thu hồi quyền ngay + ghi kỷ luật; TK thiếu owner quá ngưỡng bật cảnh báo cho OPS_PLAN |
| BR-003 | RBAC 4 mức trên TKQC: edit (owner + backup) / view-only (TL, AM, FIN) / billing (FIN_L1 — thao tác tài chính, không sửa ngân sách chiến dịch) / admin (quản trị, không chỉnh chi tiêu). | Truy cập vượt mức quyền bị core chặn; gán quyền sai mức phải qua OPS_PLAN duyệt |
| BR-004 | Naming bắt buộc `[ClientCode]-[Platform]-[Objective]-[Market]-[YYMM]` (VD `FMCG01-META-CONV-VN-2609`); `utm_source`/`utm_medium`/`utm_campaign` sinh tự động từ naming — chặn sửa tay ở cả form web và khi GW đẩy qua API platform; khách yêu cầu chuẩn riêng → OPS_PLAN duyệt ≤1 ngày làm việc, ghi lý do vào change log. | Tạo/sửa naming sai chuẩn bị validator chặn ở tầng API; campaign sai naming không được tính về dự án |
| BR-005 | Campaign bắt buộc gắn project: campaign không gắn dự án bị tự pause (thực thi qua GW khi có quyền API platform) và tạo task gắn dự án trong 4h làm việc; cấm report/hạch toán chi tiêu về khách tới khi gắn xong; degraded mode chưa có API → task pause tay cho OPS_ADS, dữ liệu gắn nhãn `manual`. | Chi tiêu về campaign mồ côi không được hạch toán; vượt 4h không khắc phục escalate OPS_PLAN |
| BR-006 | Die account tracking: phát hiện qua GW sync hoặc ghi nhận tay của OPS_ADS; evidence chụp tại thời điểm xảy ra (snapshot số dư, thông báo platform, timestamp chính xác) lưu evidence store bất biến (hash, không sửa/xóa hậu kiểm); mỗi khách duy trì ≥1 TK dự phòng đã khởi tạo trên platform chính chưa bật chi tiêu; thay thế qua Hard Stop khớp tiền và chuyển hướng vận hành trong 4h làm việc. | Thiếu evidence die: không đóng TK; không có TK dự phòng là cảnh báo rủi ro cấp team cho OPS_PLAN |
| BR-007 | Thu hồi access 24h: sự kiện nghỉ việc/chuyển dự án từ HR_L1 → core tự revoke quyền TKQC trong 24h + sinh task bàn giao cho backup; SYS_ADMIN rotate credentials trong vault (MFA bắt buộc, chỉ thao tác trên web nội bộ); đóng TK kết thúc HĐ cần OPS_PLAN + FIN_L1 xác nhận hết dư nợ trong 2 ngày làm việc trước khi archive. | Quá 24h chưa revoke là sự cố bảo mật báo cáo BOD; đóng TK còn dư nợ bị chặn |
| BR-008 | Số dư/spend/trạng thái hiển thị với freshness ≤1h (GW pull hourly); dữ liệu degraded gắn nhãn `manual` + nguồn + timestamp; import Sheets có kiểm soát — validate đúng schema registry, ghi nhận nguồn và không duy trì song song sau go-live. | Số không nhãn nguồn không được dùng để ra quyết định; import sai schema bị loại toàn bộ ở bước preview |
| BR-009 | OADS state machine: `DRAFT → CONTENT_REVIEWING → CS_REVIEWING → CS_APPROVED` (tạo 1 AdAccount mới + 1 Contract ACTIVE); reject ở bước nào cũng kèm reason + evidence và quay về `DRAFT` sửa & nộp lại; quyền duyệt ở bước CONTENT_REVIEWING chỉ dành cho OPS_CONT cấp EXECUTIVE trở lên (mapping track 5 cấp CONTENT_INTERN → CONTENT_LEADER), INTERN/JUNIOR chỉ soạn và sửa nội dung hồ sơ; CS_REVIEWING do OPS_AM (vai CS) thiết lập thông số (BC, advertiser, currency, timezone, fee schedule). | Chuyển trạng thái sai vai bị core từ chối; OADS chỉ khởi động khi KYC = Verified (FEAT-ERP-ADACC-001) |
| BR-010 | ReplacementRequest (TK bị khóa không do lỗi khách): đi theo pattern OADS — CS/AM gán tay account thay thế từ nguồn cung nội bộ (kho tự động để giai đoạn sau); state machine `PENDING → CS_ASSIGNED (gán AdAccount mới) → BALANCE_TRANSFERRED → COMPLETED`, nhánh `REJECTED` khi không đủ điều kiện — lỗi do khách; `isCustomerFault` quyết định có áp dụng SLA miễn phí ("cấp account thay thế + chuyển số dư") hay không; số dư chuyển ghi `balanceTransferredAmount` để đối soát; Contract hiện tại không đổi, fee schedule giữ nguyên. | Replacement không qua lệnh hệ thống không được công nhận; gán nhầm isCustomerFault=false cho lỗi khách là sai lệch doanh thu — audit bắt buộc reason |
| BR-011 | Chuỗi lịch sử thay thế: `newAdAccount` giữ tham chiếu `replacesAdAccountId = oldAdAccountId` — 1 account có thể bị thay nhiều lần; web cung cấp view chuỗi thay thế theo TK gốc và thống kê tần suất khóa theo platform/khách phục vụ đánh giá rủi ro nạp mới. | Xóa/ngắt tham chiếu chuỗi bị chặn — dữ liệu die/thay thế là evidence bất biến |
| BR-012 | Contract tách riêng khỏi AdAccount: `serviceType` (RENTAL/MANAGED) bất biến sau khi tạo — muốn đổi loại dịch vụ phải tất toán hợp đồng cũ (hoàn số dư trong 15 ngày làm việc) + mở hợp đồng mới; `pmsProjectId` chỉ set khi `serviceType = MANAGED`, luôn `null` khi RENTAL; 1 AdAccount có đúng 1 Contract ACTIVE tại một thời điểm, các Contract cũ giữ TERMINATED để bảo toàn lịch sử fee schedule. | Sửa serviceType trên HĐ ACTIVE bị core từ chối; set pmsProjectId trên HĐ RENTAL bị validator chặn |
| BR-013 | TK Internal-Sandbox không gắn khách (ngân sách thật ≤ mức OPS_PLAN duyệt, rà soát theo quý); client-owned TK vẫn áp naming + gắn project và ghi rõ quyền sở hữu — BC không nạp tiền. | TK Sandbox gắn khách là lỗi cấu hình nghiêm trọng; client-owned bị BC nạp tiền là sai quy trình dòng tiền |
| BR-014 | Chuyển "Khớp tiền → Cấp phát" trong vòng đời chỉ xảy ra khi cả 2 gate thỏa: KYC = Verified (FEAT-ERP-ADACC-001) và Financial Hard Stop "đã khớp tiền" từ FIN_L1 (FEAT-ERP-ADACC-003); non-payment xử lý theo mốc 15 ngày → PAUSE / 30 ngày → TERMINATE `[KXN-22]` (đề xuất chờ khách hàng xác nhận — trước khi chốt chỉ chạy cảnh báo nội bộ, không tự TERMINATE). | Gate chưa thỏa mà chuyển Cấp phát: core chặn; mốc KXN-22 chưa chốt không được cài thành hành động tự động |

---

## 4. Phân Quyền

Quyền do RBAC engine của core kiểm tra tại API; bảng dưới là hợp đồng UI web nội bộ. Ánh xạ vai CMS sang 18 vai registry: CONTENT → OPS_CONT (giữ track 5 cấp bên trong), CS → OPS_AM, Internal-Sandbox duyệt → OPS_PLAN; chỉ dùng vai registry, không tạo vai mới.

| Hành động | OPS_ADS | OPS_AM | OPS_CONT | OPS_PLAN | OPS_DES / OPS_EDIT | SYS_ADMIN |
|-----------|---------|--------|----------|----------|--------------------|-----------|
| Xem registry toàn bộ (số dư, vòng đời) | ✅ | ✅ | ✅ (phần duyệt OADS) | ✅ | ❌ (chỉ TK gắn dự án mình) | ❌ |
| Đăng ký TKQC mới | ✅ | ✅ (đề xuất theo booking) | ❌ | ✅ (duyệt danh mục nền tảng) | ❌ | ❌ |
| Gán/đổi owner + backup | ✅ (đề xuất) | ✅ (đề xuất) | ❌ | ✅ (duyệt ≤1 ngày) | ❌ | ❌ |
| Soạn hồ sơ OADS | ❌ | ❌ | ✅ (mọi cấp track) | ❌ | ❌ | ❌ |
| Duyệt/từ chối OADS bước CONTENT | ❌ | ❌ | ✅ (chỉ EXECUTIVE+) | ❌ | ❌ | ❌ |
| Thiết lập thông số CS_REVIEWING | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Tạo ReplacementRequest + gán TK thay | ✅ (đề xuất) | ✅ (CS gán tay) | ❌ | ✅ (duyệt đóng TK) | ❌ | ❌ |
| Ghi nhận die + upload evidence | ✅ | ✅ | ❌ | ✅ (duyệt đóng TK) | ❌ | ❌ |
| Import mở sổ từ Sheets | ✅ | ❌ | ❌ | ✅ (phê duyệt import) | ❌ | ❌ |
| Sửa naming/UTM tay | ❌ | ❌ | ❌ | ✅ (chỉ khi khách có chuẩn riêng đã duyệt) | ❌ | ❌ |
| Xóa TK/Contract/evidence | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (không tồn tại interface xóa) |

OPS_DES/OPS_EDIT có quyền view-only trên TK gắn dự án phụ trách (mức RBAC view-only); FIN_L1/L2 xem registry ở mức view-only theo RBAC nhưng là quyền của bản counterpart (không thuộc actors lane này). Mọi thao tác ghi qua API core với audit log; vault credentials chỉ SYS_ADMIN/CTO quản trị với MFA trên web nội bộ, không bao giờ trả plaintext về UI.

---

## 5. Trường Hợp Đặc Biệt

- Khách có nhiều TK trên cùng platform (BM khác nhau): registry phân biệt qua `externalAccountId` (advertiser ID/BM ID) và `bindInfo` theo payload riêng từng platform (TikTok = BC + role, Google = email, Facebook = BMID); naming phân biệt qua các thành phần chuẩn (ClientCode/Market/YYMM), không cho trùng naming trong registry.
- TK die có còn dư số dư: sau khi evidence được ghi nhận, refund từ platform xử lý theo luồng tài chính (FIN_L1 khớp tiền hoàn về và ghi có theo giao dịch gốc — MOD-WALLET-RECON); registry chỉ ghi trạng thái và tham chiếu luồng hoàn.
- Owner sắp nghỉ việc: cảnh báo phát từ sự kiện HR trước ngày hiệu lực; OPS_PLAN gán backup mới trước khi HR_L1 ghi sự kiện offboard — khi sự kiện ghi nhận, core revoke trong 24h là cơ chế bắt buộc, không đợi bàn giao tay.
- Platform khóa toàn bộ BM (die hàng loạt nhiều TK cùng platform): OPS_ADS ghi nhận từng TK có evidence riêng; hệ thống gộp cảnh báo theo platform để OPS_PLAN quyết định chiến lược nạp mới dựa trên lịch sử die theo platform (BR-011).
- Khách client-owned yêu cầu tự chạy lại sau khi BC chạy hộ (RENTAL → MANAGED hoặc ngược lại): không sửa `serviceType` trên HĐ ACTIVE — tất toán HĐ cũ (hoàn số dư 15 ngày làm việc) + mở HĐ mới đúng serviceType; các campaign đang chạy chuyển gắn HĐ mới.
- ReplacementRequest bị REJECTED do isCustomerFault = true: khách không được SLA miễn phí; AM trao đổi với khách ngoài hệ thống nhưng mọi quyết định gán/đổi phải qua lệnh ReplacementRequest mới — cấm sửa lý do trên request đã COMPLETED.
- Import Sheets trùng TK đã có trong registry (khớp externalAccountId): hệ thống gợi ý merge có kiểm soát, giữ bản ghi registry làm nguồn sự thật và lưu dữ liệu Sheets vào lịch sử — không tạo bản ghi trùng lặp.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** TKQC trong registry (vòng đời 5 trạng thái — chính) + OadsRequest (mở TK mới) + ReplacementRequest (thay thế). Trạng thái do core quản lý; web hiển thị machine-state và chỉ gửi hành động hợp lệ.

**Sơ đồ vòng đời TKQC:**
```
[Khởi tạo] ──(FIN_L1 xác nhận đã khớp tiền)──► [Khớp tiền] ──(2 gate thỏa: KYC + Hard Stop)──► [Cấp phát]
                     │                                                            │
                     │                                                            ▼
                     │                                                       [Vận hành]
                     │                                                            │
                     │                    (thu hồi access 24h / hết HĐ / die đóng TK)│
                     └──────────────────────────────────────────────► [Thu hồi/Đóng]◄┘
```

**Bảng chuyển đổi vòng đời:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `Khởi tạo` | Đăng ký TK mới | `Khởi tạo` (bản ghi tạo) | OPS_ADS/OPS_AM | Đủ owner + backup; naming hợp lệ; KYC khách đã Verified |
| `Khởi tạo` | Xác nhận khớp tiền | `Khớp tiền` | Hệ thống (từ xác nhận FIN_L1 — REQ-FIN-006) | Lệnh nạp tương ứng đã khớp |
| `Khớp tiền` | Mở gate cấp phát | `Cấp phát` | Hệ thống (2 gate) | KYC = Verified + Hard Stop mở; owner nhận quyền |
| `Cấp phát` | Bật chi tiêu, chạy campaign | `Vận hành` | OPS_ADS (owner) | Campaign gắn project; naming/UTM chuẩn |
| `Vận hành` | Thu hồi/đóng TK | `Thu hồi/Đóng` | OPS_PLAN + FIN_L1 | Hết dư nợ (2 ngày làm việc); evidence archive; access revoked 24h |
| `Vận hành` | Die account | `Vận hành` + cờ die | OPS_ADS ghi / GW phát hiện | Evidence bất biến bắt buộc; kích hoạt TK dự phòng trong 4h |

**Sơ đồ OadsRequest (CMS §3.2):**
```
[DRAFT] ──(submit)──► [CONTENT_REVIEWING] ──(EXECUTIVE+ duyệt)──► [CONTENT_APPROVED]
                          │ (reject + reason + evidence)                 │
                          ▼                                             ▼
                        [DRAFT] ──────────────► [CS_REVIEWING] ──(duyệt)──► [CS_APPROVED]
                                                     │ (reject + reason + evidence)
                                                     ▼
                                                   [DRAFT] (sửa & nộp lại)
CS_APPROVED → tự tạo 1 AdAccount mới + 1 Contract (ACTIVE)
```

**Sơ đồ ReplacementRequest (CMS §3.11):**
```
[PENDING] ──(gán AdAccount mới thủ công)──► [CS_ASSIGNED] ──(chuyển số dư)──► [BALANCE_TRANSFERRED] ──► [COMPLETED]
                │ (không đủ điều kiện — lỗi do khách)
                ▼
             [REJECTED]
```

**Quy tắc:**
- `Thu hồi/Đóng` và `COMPLETED` là trạng thái kết thúc; mở lại chỉ qua quy trình đăng ký mới/replacement, không revert trực tiếp; mọi reject của OADS/Replacement bắt buộc reason + evidence, không cho nhảy bước.
- CS_APPROVED tự tạo 1 AdAccount mới + 1 Contract ACTIVE; ReplacementRequest đổi AdAccount gắn Contract nhưng không đổi Contract/fee schedule.
- Trạng thái platform (ACTIVE/FROZEN/BLOCKED/OUT_OF_MONEY) là dữ liệu đồng bộ từ GW, tách biệt với vòng đời registry — cấm ghi đè tay trừ khi gắn nhãn `manual` kèm nguồn + timestamp.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| AdAccount | `id`, `platform_id`, `ad_account_type_id`, `external_account_id`, `currency`, `timezone`, `country`, `bind_info`, `pixel_id`, `current_contract_id`, `status`, `lifecycle_stage`, `owner_id`, `backup_id` | FK → Platform, Contract; FK → Employee (owner/backup) | Registry trung tâm; status platform tách vòng đời registry |
| OadsRequest | `id`, `customer_id`, `platform_id`, `ad_account_type_id`, `business_info`, `license_docs[]`, `status`, `reject_reason`, `reject_evidence` | FK → Customer, AdAccount tạo ra | State machine §3.2; CONTENT chỉ EXECUTIVE+ duyệt |
| Contract | `id`, `ad_account_id`, `service_type`, `fee_percent`, `vat_on_fee_percent`, `vat_on_spend_percent`, `pms_project_id`, `status`, `start_date`, `end_date`, `refund_amount` | FK → AdAccount | serviceType bất biến; pmsProjectId chỉ khi MANAGED |
| ReplacementRequest | `id`, `old_ad_account_id`, `new_ad_account_id`, `reason`, `is_customer_fault`, `balance_transferred_amount`, `status` | FK → AdAccount (old/new) | newAdAccount giữ `replaces_ad_account_id` cho chuỗi lịch sử |
| DieEvidence | `id`, `ad_account_id`, `evidence_type`, `file_ref`, `hash`, `captured_at`, `captured_by` | FK → AdAccount | Immutable store — không sửa/xóa hậu kiểm |
| NamingUtmRecord | `ad_account_id`, `naming`, `utm_source`, `utm_medium`, `utm_campaign`, `custom_approved_by` | FK → AdAccount | Validator chặn sai chuẩn; ngoại lệ chỉ khi OPS_PLAN duyệt |
| AccessGrant | `ad_account_id`, `employee_id`, `rbac_level`, `granted_at`, `revoked_at` | FK → AdAccount, Employee | Thu hồi 24h theo sự kiện HR; RBAC 4 mức |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Naming sai bị chặn | OPS_ADS nhập naming thủ công sai chuẩn | Lưu form đăng ký TK | Validator chặn ở tầng API; mã chỉ chấp nhận mẫu `[ClientCode]-[Platform]-[Objective]-[Market]-[YYMM]` | [ ] |
| SC-002: OADS sai cấp duyệt | OADS ở `CONTENT_REVIEWING`, tài khoản track JUNIOR | Bấm CONTENT_APPROVED | Core từ chối — chỉ EXECUTIVE+ được duyệt; JUNIOR chỉ sửa được nội dung hồ sơ | [ ] |
| SC-003: CS_APPROVED sinh TK + HĐ | OADS đã qua 2 bước duyệt | OPS_AM duyệt CS_APPROVED | Hệ thống tự tạo 1 AdAccount + 1 Contract ACTIVE; KYC gate kiểm tra trước đó đã thỏa | [ ] |
| SC-004: Replacement giữ chuỗi | TK A die (không do lỗi khách), thay bằng TK B | Tạo ReplacementRequest COMPLETED | B có `replaces_ad_account_id = A`; isCustomerFault=false áp SLA miễn phí; balanceTransferredAmount ghi nhận | [ ] |
| SC-005: serviceType bất biến | Contract RENTAL đang ACTIVE | Yêu cầu sửa thành MANAGED trực tiếp | Core từ chối; bắt buộc tất toán HĐ cũ + mở HĐ mới | [ ] |
| SC-006: pmsProjectId chỉ MANAGED | Contract serviceType = RENTAL | Set pmsProjectId | Validator chặn; trường giữ null | [ ] |
| SC-007: Thu hồi 24h | HR_L1 ghi sự kiện nghỉ việc của owner | Đồng hồ 24h chạy | Core tự revoke quyền TKQC + sinh task bàn giao cho backup; audit log ghi thời điểm | [ ] |
| SC-008: Evidence die bất biến | TK bị platform khóa | OPS_ADS upload snapshot + timestamp | Evidence lưu hash, không sửa/xóa được; lịch sử die theo platform cập nhật | [ ] |

> **Liên kết:** SC-001…SC-008 map về REQ-OPS-001 (Mục 2 — registry, naming/UTM, vòng đời, ownership, die tracking, replacement, contract bất biến).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/adaccount-cc/command-center-registry.md` |
| Bản fan-out counterpart | `phase2-features/core-backend/adaccount-cc/` (registry engine, state machine); `phase2-features/integration-gw/adaccount-cc/` (đồng bộ hourly 7 nền tảng, nhãn `manual`); `phase2-features/mobile-internal/adaccount-cc/` (push cảnh báo die/thiếu owner — từ GĐ2) — REQ-OPS-001 xuất hiện ở 4 systems |
| Nguồn domain | `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — §3.2 OadsRequest, §3.3 Contract, §3.4 AdAccount, §3.11 ReplacementRequest, §4 quan hệ PMS) |
