# Tính Năng: Ad Account Command Center — registry & vòng đời TKQC (bản mobile nội bộ)

> **Dựa trên:** REQ-OPS-001 trong `phase1-business/departments/operations/operations.md` (Phần A, B.1); gate liên quan REQ-FIN-009 trong `phase1-business/departments/finance/finance.md`
> **Phân hệ:** Mobile nội bộ (SYS-MOBILE-INTERNAL)
> **Module:** Ad Account Command Center (MOD-ADACCOUNT-CC)
> **Ngày:** 13/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/departments/finance/finance.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

> **Phạm vi fan-out:** REQ-OPS-001 có mặt ở 4 hệ thống. Bản này là bản riêng cho **SYS-MOBILE-INTERNAL (M-INT)** — ứng dụng React Native offline-capable cho staff di động: duyệt-on-the-go, xem dashboard, nhận cảnh báo push. Nguồn sự thật và toàn bộ enforcement nằm ở CORE (FEAT-CORE-ADACC-002); màn hình làm việc chính của OPS là WEB (FEAT-ERP-ADACC-002).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-ADACC-001 |
| Module | MOD-ADACCOUNT-CC |
| Yêu cầu nghiệp vụ | REQ-OPS-001 (chính); REQ-FIN-009 (KYC gate — chỉ đọc trạng thái) |
| Người dùng liên quan | OPS_ADS, OPS_AM, OPS_CONT, OPS_PLAN, OPS_DES, OPS_EDIT, FIN_L1 (view-only) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 (M-INT triển khai từ GĐ2 theo operations.md A3) |
| Phụ thuộc | FEAT-CORE-ADACC-002 (registry CORE), FEAT-CORE-ADACC-001 (KYC gate), FEAT-CORE-ADACC-003 (Financial Hard Stop), FEAT-ERP-ADACC-002 (Command Center web) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa registry trung tâm 2.600+ TKQC trên 7 nền tảng lên mobile nội bộ để OPS_ADS, OPS_AM và team lead OPS_PLAN theo dõi trạng thái TK, nhận cảnh báo die/thiếu owner/số dư đỏ và xử lý việc duyệt-nhanh khi không ngồi máy trạm. Mobile là kênh bổ trợ time-sensitive: mọi dữ liệu và quy tắc do CORE enforce ở tầng service, mobile chỉ phản chiếu trạng thái và gửi lệnh để CORE thẩm duyệt lại.

**Phạm vi:**
- Bao gồm: push + xem cảnh báo (die, thiếu owner/backup, owner sắp nghỉ, số dư đỏ SLA 2h, thu hồi access 24h); dashboard registry freshness ≤1h kèm nhãn `manual` khi degraded; xem chi tiết TK (vòng đời 5 bước, trạng thái platform, owner/backup, gắn dự án); duyệt-on-the-go các hành động được phép (đổi owner/backup, ghi nhận die + evidence, gán TK thay thế trong ReplacementRequest, chuyển trạng thái OADS đúng vai); tạo lệnh đề xuất top-up/giảm ngân sách từ alert đỏ ngoài giờ; queue offline cho mọi action ghi.
- Không bao gồm: xác nhận khớp tiền FIN_L1 và mọi nút Hard Stop (REQ-OPS-002 chủ ý không có bản M-INT — không tạo kênh bypass); thao tác vault/credentials (chỉ WEB với MFA — REQ-BOD-008); import Google Sheets và bulk edit (chỉ WEB); cấu hình naming đặc biệt/quyền/quota; tính công thức phí topup (CORE). Mobile không nhập liệu hàng loạt theo nguyên tắc M-INT trong P1-02.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_ADS (owner TK) | Nhận push khi TK của tôi bị die, thiếu backup hoặc số dư đỏ | Phản ứng ngay cả khi đang ngoài giờ, không chờ check web |
| 2 | OPS_ADS | Tạo lệnh đề xuất top-up/giảm ngân sách một chạm từ alert đỏ | Đáp SLA 2h trước khi escalate OPS_PLAN → OPS_AM |
| 3 | OPS_ADS | Chụp và upload evidence die ngay tại thời điểm phát hiện từ điện thoại | Evidence store bất biến ghi đúng timestamp "tại thời điểm xảy ra" |
| 4 | OPS_PLAN (TL) | Nhận push khi có TK thiếu owner/backup, yêu cầu đổi owner, hoặc TK die cần duyệt đóng | Duyệt ≤1 ngày làm việc đúng SLA không cần mở laptop |
| 5 | OPS_PLAN | Xem dashboard registry (số TK theo trạng thái/platform/khách) trên mobile | Nắm vận hành khi công tác, dữ liệu luôn gắn nguồn + freshness |
| 6 | OPS_AM | Gán TK thay thế và theo dõi ReplacementRequest trên mobile khi khách báo TK khóa không do lỗi khách | Không để khách chờ ngoài giờ vì việc gán tay phải đợi giờ hành chính |
| 7 | OPS_CONT (Executive trở lên) | Duyệt hồ sơ OADS bước CONTENT_REVIEWING từ mobile (approve/reject kèm reason + evidence) | Hồ sơ mở TKQC không kẹt khi reviewer đang di chuyển |
| 8 | FIN_L1 | Xem trạng thái TK và cờ khóa khớp tiền ở chế độ read-only | Theo dõi sau khi đã xác nhận trên WEB, không thao tác dòng tiền qua mobile |

---

## 3. Quy Tắc Nghiệp Vụ

> *Quy tắc bắt buộc — developer phải xử lý đúng trong code. Toàn bộ enforcement nằm ở CORE service layer; mobile chỉ gửi yêu cầu và phản chiếu kết quả.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Registry phản chiếu 2.600+ TKQC/7 nền tảng theo vòng đời 5 trạng thái (Khởi tạo → Khớp tiền → Cấp phát → Vận hành → Thu hồi/Đóng) và trạng thái platform (ACTIVE/FROZEN/BLOCKED/OUT_OF_MONEY) — CMS §3.4; naming `[ClientCode]-[Platform]-[Objective]-[Market]-[YYMM]` + UTM sinh tự động là read-only trên mobile (sửa tay bị chặn ở CORE); freshness ≤1h, số degraded gắn nhãn `manual` + nguồn + timestamp — không dùng số không nhãn để ra quyết định. | Truy vấn TK ngoài registry bị CORE từ chối; TK sai naming không được tính về dự án; hiển thị số stale quá hạn phải kèm cảnh báo "dữ liệu cũ" |
| BR-002 | Financial Hard Stop: chuyển "Khớp tiền → Cấp phát" chỉ khi FIN_L1 xác nhận "đã khớp tiền" trên CORE — không override, không trạng thái chờ duyệt, **không có nút nào trên mobile**; M-INT chỉ nhận thông tin trạng thái khóa/mở; "khách hứa chuyển" không có giá trị mở khóa. | Action mở khóa không tồn tại trong app (không chỉ ẩn UI); attempt gọi API mở khóa từ mobile bị chặn tầng service + audit log bất biến |
| BR-003 | KYC gate (REQ-FIN-009): mobile chỉ ĐỌC trạng thái KYC pháp nhân — gate thực thi ở CORE khi cấp phát; TK chờ do KYC ≠ Verified hiển thị lý do chặn (đồng bộ CRM) và đầu mối xử lý. | Không thao tác nào trên mobile đổi được trạng thái KYC; hiển thị sai gate là lỗi P0 |
| BR-004 | OADS state machine (CMS §3.2): `DRAFT → CONTENT_REVIEWING → CS_REVIEWING → CS_APPROVED` (tạo AdAccount + Contract ACTIVE); reject bắt buộc reason + evidence, về `DRAFT`; quyền bấm chuyển trạng thái trên mobile chỉ cho OPS_CONT từ EXECUTIVE trở lên (INTERN/JUNIOR chỉ xem/sửa hồ sơ qua WEB), bước CS_REVIEWING do OPS_AM; mọi action đổi trạng thái từ mobile yêu cầu MFA step-up. | Chuyển trạng thái sai vai bị CORE từ chối; MFA không pass thì không thực thi; OADS chỉ khởi động khi KYC = Verified |
| BR-005 | ReplacementRequest (CMS §3.11): OPS_AM gán tay TK thay thế (kho nguồn cung tự động để sau — `[KXN-9]` phạm vi "tương lai" CMS chưa chốt); state `PENDING → CS_ASSIGNED → BALANCE_TRANSFERRED → COMPLETED`, nhánh `REJECTED` khi lỗi do khách; `isCustomerFault` quyết định SLA miễn phí ("cấp account thay thế + chuyển số dư"); mobile cho phép gán + xác nhận `balanceTransferredAmount`, không cho sửa `isCustomerFault` sau chốt. | Sửa `isCustomerFault` sau chốt bị chặn — phải mở yêu cầu mới; thay thế ngoài lệnh hệ thống không được công nhận |
| BR-006 | Chuỗi lịch sử thay thế: `newAdAccount.replacesAdAccountId = oldAdAccountId` — 1 TK có thể bị thay nhiều lần; mobile hiển thị timeline chuỗi thay thế theo TK gốc + tần suất khóa theo platform/khách (chỉ đọc) phục vụ đánh giá rủi ro nạp mới. | Xóa/ngắt tham chiếu chuỗi bị CORE chặn — dữ liệu die/thay thế là evidence bất biến |
| BR-007 | Ownership & thu hồi 24h: mỗi TK đúng 1 khách + 1 owner + 1 backup, tối đa 2 quyền edit, cấm chia sẻ login; sự kiện nghỉ/chuyển từ HR_L1 → CORE tự revoke trong 24h + sinh task bàn giao cho backup; OPS_PLAN duyệt đổi owner/backup ≤1 ngày làm việc — được duyệt trên mobile với MFA step-up; mobile push cảnh báo thiếu owner/backup và owner sắp nghỉ cho OPS_ADS + OPS_PLAN. | Duyệt từ thiết bị không pass MFA bị chặn; quá 24h chưa revoke là sự cố bảo mật báo cáo BOD; mobile không revoke trực tiếp — chỉ nhận kết quả CORE |
| BR-008 | Die account: phát hiện qua GW sync hoặc OPS_ADS ghi nhận tay từ mobile; evidence (snapshot số dư, thông báo platform, timestamp chính xác) upload thẳng vào evidence store bất biến (hash, không sửa/xóa hậu kiểm); kích hoạt TK dự phòng (mỗi khách ≥1 TK đã khởi tạo, chưa bật chi tiêu) và chuyển hướng vận hành trong 4h làm việc — TK dự phòng vẫn đi đủ Hard Stop khớp tiền. | Die không evidence không được đóng TK; cố bypass khớp tiền khi kích hoạt dự phòng bị chặn; quá 4h escalate OPS_PLAN |
| BR-009 | Alert đỏ SLA 2h: push ≤5 phút cho owner; trong 2h làm việc owner phải tạo trên hệ thống 1 trong 2 hành động: lệnh đề xuất top-up hoặc giảm ngân sách (mobile cho phép tạo đề xuất; WEB vẫn là nơi tạo lệnh chính và nơi FIN duyệt); quá 2h escalate OPS_PLAN, quá 4h escalate OPS_AM, mỗi chặng ghi timestamp; cấm mượn chéo ví giữa khách, cấm xác nhận miệng Zalo/điện thoại. | Quá SLA không có lệnh: bộ đếm CORE tự escalate; lệnh từ mobile vẫn qua đủ luồng duyệt FIN — mobile không rút gọn bước nào |
| BR-010 | Contract (CMS §3.3/§4): mobile chỉ đọc `serviceType` (RENTAL/MANAGED) — bất biến sau tạo, đổi loại phải tất toán hợp đồng cũ và mở hợp đồng mới; `pmsProjectId` chỉ set khi MANAGED, luôn rỗng khi RENTAL; link "mở dự án PMS" chỉ hiện cho TK MANAGED và dẫn về WEB; 1 AdAccount có đúng 1 Contract ACTIVE, Contract cũ giữ TERMINATED bảo toàn lịch sử fee schedule. | Yêu cầu sửa serviceType hoặc set pmsProjectId trên RENTAL từ mobile bị CORE từ chối |
| BR-011 | Offline & queue: app đọc được offline (cache dashboard, hiển thị "dữ liệu offline tại thời điểm X"); action ghi khi offline vào hàng đợi cục bộ có timestamp, tự sync khi có mạng — CORE thẩm duyệt lại toàn bộ quyền + trạng thái tại thời điểm sync; action bị từ chối khi sync phải hiển thị rõ cho người dùng. | Queue retry vô hạn không báo người dùng là lỗi nghiêm trọng; action ghi áp dụng mà không qua thẩm duyệt lại của CORE là lỗ hổng P0 |
| BR-012 | Bảo mật kênh mobile: cấm hiển thị credentials/API key/vault (REQ-BOD-008 — vault chỉ WEB nội bộ với MFA); đăng nhập bắt buộc MFA, session timeout ngắn hơn web; push notification chỉ chứa loại cảnh báo + tên TK, không chứa số tiền nhạy cảm trên lock screen. | Credential xuất hiện trên mobile là sự cố bảo mật nghiêm trọng; cấu hình hidden-content notification khi màn hình khóa |

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry. Enforce tại CORE service layer — mobile phản chiếu ma trận này.

| Hành động | OPS_ADS | OPS_AM | OPS_CONT | OPS_PLAN | OPS_DES/OPS_EDIT | FIN_L1 | SYS_ADMIN |
|-----------|---------|--------|----------|----------|------------------|--------|-----------|
| Xem dashboard registry | ✅ | ✅ | ❌ | ✅ | ✅ (TK dự án mình) | ✅ | ✅ |
| Xem chi tiết TK | ✅ (TK mình + team) | ✅ | ✅ | ✅ | ✅ (TK dự án mình) | ✅ | ✅ |
| Nhận push die/thiếu owner/số dư đỏ | ✅ (owner) | ✅ (escalate) | ❌ | ✅ (escalate) | ✅ (pause dự án) | ❌ | ✅ (kỹ thuật) |
| Ghi nhận die + upload evidence | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Duyệt đóng TK die | ❌ | ❌ | ❌ | ✅ (MFA) | ❌ | ❌ | ❌ |
| Duyệt đổi owner/backup | ❌ | ❌ | ❌ | ✅ (MFA) | ❌ | ❌ | ❌ |
| Gán TK thay thế (Replacement) | ❌ | ✅ (MFA) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Xác nhận đã chuyển số dư | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Duyệt OADS CONTENT_REVIEWING | ❌ | ❌ | ✅ (EXECUTIVE+, MFA) | ❌ | ❌ | ❌ | ❌ |
| Duyệt OADS CS_REVIEWING | ❌ | ✅ (MFA) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Tạo đề xuất top-up/giảm ngân sách | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Xác nhận khớp tiền / mở khóa Hard Stop | ❌ (chỉ xem) | ❌ | ❌ | ❌ | ❌ | ❌ (không có trên mobile — chỉ WEB) | ❌ |
| Sửa `isCustomerFault` sau chốt / `serviceType` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Thao tác vault/credentials | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (chỉ WEB với MFA) |

Ghi chú: BOD_CEO/BOD_CFO_CTO không có vai duyệt nào trên mobile cho REQ-OPS-001. OPS_ADS không tự duyệt việc của mình — hành động của owner là đề xuất/thực hiện, hành động duyệt thuộc OPS_PLAN hoặc OPS_AM theo bảng.

---

## 5. Trường Hợp Đặc Biệt

- **TK Internal-Sandbox:** không gắn khách, ngân sách thật ≤ mức OPS_PLAN duyệt, rà theo quý — mobile hiển thị tách nhóm với nhãn "nội bộ", không áp alert/Replacement của khách.
- **Client-owned TK:** khách tự sở hữu, BC không nạp tiền — vẫn nằm registry với nhãn sở hữu rõ, áp naming + gắn project; alert dòng tiền BC không phát sinh.
- **Owner nghỉ đột xuất:** HR_L1 ghi sự kiện → CORE revoke trong 24h; trong chuyển giao, backup nhận quyền edit + push thay owner; mobile hiển thị trạng thái "đang chuyển giao" để tránh hai người cùng tưởng mình là owner.
- **Die hàng loạt một platform:** GW sync báo nhiều TK cùng platform khóa trong một đợt — mobile gom 1 alert tổng hợp thay vì N alert; xử lý từng TK, evidence vẫn per-TK.
- **Offline kéo dài (mạng yếu/đi nước ngoài):** queue action có thể tồn tại nhiều giờ; khi sync nếu trạng thái đã đổi (TK đã được người khác đóng), app hiển thị xung đột và yêu cầu xác nhận lại, không tự retry.
- **Mốc non-payment:** đề xuất 15 ngày → PAUSE / 30 ngày → TERMINATE `[KXN-22]` chưa được khách hàng xác nhận — trước khi chốt, mobile chỉ hiển thị cảnh báo nội bộ chậm thanh toán, KHÔNG tự pause/terminate; chốt thủ công qua WEB.
- **Hết TK dự phòng:** kho nguồn cung nội bộ (BM/VIA) chưa xây (CMS §6, `[KXN-9]`); khi không còn TK dự phòng đã khởi tạo, OPS_AM gán tay phải chọn trong TK đã khởi tạo của khách và mobile tự bắn cảnh báo rủi ro cấp team cho OPS_PLAN.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** AdAccount — vòng đời vận hành 5 trạng thái góc OPS; nguồn sự thật ở CORE, mobile phản chiếu và chỉ gửi yêu cầu cho các chuyển đổi được phép.

**Sơ đồ trạng thái:**
```
[Khởi tạo] ──(FIN_L1 khớp tiền + KYC Verified — chỉ WEB/CORE)──► [Khớp tiền]
[Khớp tiền] ──(gate Hard Stop mở)──► [Cấp phát] ──(bật chi tiêu)──► [Vận hành]
[Vận hành] ──(die / kết thúc HĐ)──► [Thu hồi/Đóng]
[Vận hành] ──(FIN_L1 thu hồi xác nhận)──► [Khớp tiền — tạm dừng chi tiêu]
```

**Bảng chuyển đổi (mobile actions vs CORE):**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| Khởi tạo | Chỉ xem trên mobile | Khớp tiền | FIN_L1 trên WEB | Đã khớp tiền + KYC Verified — không có action mobile |
| Khớp tiền | Cấp phát | Cấp phát | CORE tự mở khi gate thỏa | Hard Stop "đã khớp tiền" — mobile không có nút |
| Cấp phát | Bật chi tiêu | Vận hành | OPS_ADS (WEB chính; mobile chỉ đề xuất) | Naming/UTM hợp lệ, gắn project |
| Vận hành | Ghi nhận die + evidence | Cờ die — chờ duyệt đóng | OPS_ADS/OPS_AM trên mobile | Evidence bắt buộc, timestamp tại thời điểm xảy ra |
| Vận hành (cờ die) | Duyệt đóng TK | Thu hồi/Đóng | OPS_PLAN trên mobile (MFA) | Evidence đủ; TK dự phòng đã kích hoạt trong 4h làm việc |
| Vận hành | Thu hồi xác nhận khớp tiền | Khớp tiền (tạm dừng chi tiêu) | FIN_L1 trên WEB — mobile chỉ nhận push | FIN_L1 phát hiện khớp sai; không có action mobile |

**ReplacementRequest (CMS §3.11):** `PENDING → CS_ASSIGNED → BALANCE_TRANSFERRED → COMPLETED`; nhánh `REJECTED` (lỗi do khách). Mobile: OPS_AM chuyển `CS_ASSIGNED` (gán TK mới) và `BALANCE_TRANSFERRED` (xác nhận số dư); `COMPLETED` do hệ thống chốt khi đối soát khớp.

**OadsRequest (CMS §3.2):** `DRAFT → CONTENT_REVIEWING → CS_REVIEWING → CS_APPROVED`; reject kèm reason + evidence, về `DRAFT`. Mobile chỉ cho vai duyệt bấm chuyển trạng thái; soạn/sửa hồ sơ là việc của WEB.

**Quy tắc chung:** mọi chuyển trạng thái ghi audit log bất biến ở CORE (ai, khi nào, từ/sang, kênh thiết bị, căn cứ); action mobile ghi `channel=mobile` phục vụ điều tra bảo mật; không trạng thái quay lùi ngoài các nhánh đã liệt kê.

---

## 7. Tóm Tắt Entity (Quick Reference)

> Mobile không sở hữu entity — chỉ tiêu thụ API của CORE. DDL đầy đủ tại `database-design.md` của SYS-CORE-BACKEND.

| Entity | Fields chính (mobile quan tâm) | Quan hệ | Ghi chú |
|--------|-------------------------------|---------|---------|
| `AdAccount` | `status` (5 bước + platform), `platformId`, `externalAccountId`, `ownerId`, `backupId`, `projectId` | FK → `Customer`, `Contract`, `Platform` | 2.600+ TK; mobile cache theo phân quyền |
| `Contract` | `serviceType` (bất biến), `pmsProjectId` (chỉ MANAGED), `status` | FK → `AdAccount` | Mobile chỉ đọc |
| `OadsRequest` | `status` (state §3.2), `rejectReason`, `rejectEvidence` | FK → `Customer` | Duyệt: OPS_CONT EXECUTIVE+ / OPS_AM |
| `ReplacementRequest` | `oldAdAccountId`, `newAdAccountId`, `isCustomerFault`, `balanceTransferredAmount`, `status` | FK → `AdAccount` (cũ/mới qua `replacesAdAccountId`) | Chuỗi thay thế bất biến |
| `DieEvidence` | `snapshotUrl`, `platformNotice`, `capturedAt`, `hash` | FK → `AdAccount` | Bất biến; upload từ camera mobile |
| `AlertNotification` | `type` (die/owner_missing/balance_red/pause), `severity`, `escalationLevel`, `readAt` | FK → `AdAccount`, `Employee` | Push ≤5 phút; rút gọn trên lock screen |

---

## 8. Acceptance Criteria

> Phác thảo Phase 2 — chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-OPS-001 (Mục 2).

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Push die + evidence | OPS_ADS là owner TK META đang Vận hành | GW báo die; OPS_ADS chụp evidence upload từ mobile | Evidence vào store bất biến đúng timestamp; TK sang cờ die chờ OPS_PLAN duyệt | [ ] |
| SC-002: Không có nút Hard Stop | TK ở Khớp tiền, chưa có xác nhận FIN_L1 | OPS_ADS tìm mọi màn hình mobile tìm action cấp phát | Không tồn tại action (không chỉ ẩn UI); attempt API bị chặn + audit log | [ ] |
| SC-003: Duyệt OADS đúng vai | Hồ sơ ở CONTENT_REVIEWING; OPS_CONT SENIOR nhận push | Bấm CONTENT_APPROVED với MFA step-up | Chuyển CS_REVIEWING; audit log `channel=mobile`; INTERN thử bấm bị từ chối | [ ] |
| SC-004: Gán TK thay thế offline | OPS_AM offline, khách báo TK khóa không do lỗi khách | Gán TK mới offline; có mạng, queue sync | CORE thẩm duyệt lại khi sync; hợp lệ → CS_ASSIGNED; `isCustomerFault=false` mở SLA miễn phí | [ ] |
| SC-005: Alert đỏ ngoài giờ | Số dư TK xuống đỏ lúc 21h | OPS_ADS tạo đề xuất top-up từ mobile | Lệnh vào sổ CORE đúng luồng; SLA 2h dừng đếm; FIN_L1 thấy lệnh trên WEB để khớp tiền | [ ] |
| SC-006: Thu hồi access 24h | HR_L1 ghi sự kiện nghỉ việc của owner | CORE revoke trong 24h, sinh task bàn giao | Backup nhận push; OPS_PLAN thấy task; quá 24h → cảnh báo BOD | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` (SYS-CORE-BACKEND — registry, evidence store, audit log) |
| API Endpoints | `technical-specs/api-contract.md` (CORE API cho M-INT; offline sync contract) |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (GW pull hourly, degraded `manual`, push notification service) |
| Màn hình UI | `phase4-ux/mobile-internal/adaccount-cc/` (dashboard, alert inbox, chi tiết TK, duyệt OADS/Replacement) |
| Nguồn domain chi tiết | `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — §3.2, §3.3, §3.4, §3.11, §4) |
| Bản counterparts | `phase2-features/core-backend/adaccount-cc/` (FEAT-CORE-ADACC-001/002/003), `phase2-features/bcerp-web/adaccount-cc/` (FEAT-ERP-ADACC-002), `phase2-features/integration-gw/adaccount-cc/` |
