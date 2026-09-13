# Tính Năng: Ad Account Command Center — registry & vòng đời TKQC (Integration Gateway)

> **Dựa trên:** REQ-OPS-001 trong `phase1-business/departments/operations/operations.md` (Phần A, B.1) — bản touchpoint **SYS-INTEGRATION-GW** (1 trong 4 bản fan-out: CORE-BACKEND, BCERP-WEB, INTEGRATION-GW, MOBILE-INTERNAL)
> **Phân hệ:** Integration Gateway (SYS-INTEGRATION-GW)
> **Module:** Quản lý TKQC — Ad Account Command Center (MOD-ADACCOUNT-CC)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/departments/finance/finance.md` (B.4 — REQ-FIN-009), `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-GW-ADACC-001 |
| Module | MOD-ADACCOUNT-CC |
| Yêu cầu nghiệp vụ | REQ-OPS-001 — Ad Account Command Center — registry & vòng đời TKQC (HIGH, MVP) |
| Người dùng liên quan | OPS_ADS (chính), OPS_AM, OPS_PLAN, OPS_CONT, OPS_DES, OPS_EDIT (tiêu thụ dữ liệu qua WEB/M-INT), SYS_ADMIN và BOD_CFO_CTO (quản trị kết nối platform) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — không có GW thì Command Center không có dữ liệu số dư/trạng thái platform và phải chạy hoàn toàn tay) |
| Phụ thuộc | Không có cross-dependency sang module khác; phụ thuộc nội bộ: adapter framework cắm theo nền tảng, credential vault, raw payload store bất biến; tiến trình Business Verification 7 nền tảng là điều kiện mở API (đang theo dõi — DI-007) |
| Ghi chú Expert (A7) | Operations.md Mục A7: chưa có đánh giá chính thức (chờ review); ghi nhận REQ-OPS-002/003 phối hợp FIN cần đối chiếu chéo — đã phản ánh qua BR-GW-104: GW chỉ đọc trạng thái gate từ nguồn sự thật FIN/CORE, không override |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Xây dựng tầng Integration Gateway (data plane) của Ad Account Command Center — tập hợp adapter kết nối 7 nền tảng quảng cáo (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) và dịch vụ ngoài (VAS/TikTok) để đồng bộ registry hơn 2.600 TKQC: pull hourly số dư, spend limit, trạng thái platform (ACTIVE/FROZEN/BLOCKED/OUT_OF_MONEY), push lệnh điều khiển (pause campaign, nối platform ID), phát hiện die account từ trạng thái platform. GW chỉ tiêu thụ trạng thái gate từ nguồn sự thật FIN/CORE (Hard Stop khớp tiền, KYC Verified, OADS CS_APPROVED) — không bao giờ là nơi ra quyết định tài chính; khi chưa có quyền API, degraded mode "manual" là trạng thái vận hành chính thức kèm backfill và đối chiếu khi được cấp API.

**Phạm vi:**
- Bao gồm: adapter 7 nền tảng — vòng pull hourly đủ 2.600+ TK trong ≤60 phút, retry/backoff, lưu raw payload bất biến; dữ liệu tươi ≤1h kèm freshness metadata (nguồn + timestamp + độ trễ); nhãn nguồn (`api`/`manual`) bắt buộc trên mọi bản ghi.
- Bao gồm: degraded mode "manual" — import statement chuẩn hóa + nhập tay có cấu trúc đúng schema registry; backfill tự động khi được cấp API và đối chiếu manual vs API trước khi chuyển nguồn.
- Bao gồm: thực thi qua API các lệnh được CORE phê duyệt — nối `externalAccountId`/`bindInfo` sau khi tạo TK trên platform, pause campaign không gắn dự án; validator naming/UTM ở biên GW chặn payload sai chuẩn trước khi đẩy lên platform.
- Bao gồm: quản lý kết nối platform — credentials vault mã hóa (rotate ≥90 ngày, không plaintext về UI, MFA), theo dõi Business Verification từng platform, thu hồi token/quyền trong 24h theo sự kiện HR offboarding hoặc hết hợp đồng.
- Không bao gồm: nguồn sự thật registry (mã TK, owner/backup, vòng đời 5 trạng thái, validator naming gốc, audit vòng đời) — thuộc SYS-CORE-BACKEND; GW chỉ phản chiếu và thực thi.
- Không bao gồm: giao diện Command Center, form đăng ký TK, màn nhập manual — thuộc SYS-BCERP-WEB; GW chỉ cung cấp API.
- Không bao gồm: logic Hard Stop (REQ-OPS-002), hồ sơ/trạng thái KYC (REQ-FIN-009), state machine OADS và ReplacementRequest, ví TKQC (REQ-OPS-003), TikTok Shop OAuth per-client (REQ-OPS-011) — GW chỉ nhận kết quả trạng thái từ CORE.

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-INTEGRATION-GW — adapter headless không có UI: người dùng nội bộ thao tác qua WEB/M-INT, lệnh đi xuống GW thực thi với platform, dữ liệu đi lên GW chuẩn hóa về registry. Đặc trưng touchpoint: mọi hành vi phải chạy được cả 2 chế độ — có API (tự động) và không có API (degraded "manual", gắn nhãn nguồn).

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_ADS | Hệ thống tự pull hourly số dư, spend limit, trạng thái platform của 2.600+ TK trên 7 nền tảng | Command Center luôn tươi ≤1h mà không phải vào từng Ads Manager kiểm tra tay |
| 2 | OPS_ADS | Die account (bị khóa/hạn chế) được phát hiện tự động từ sync, đẩy sự kiện kèm timestamp nguồn về registry | Khởi tạo thay thế trong 4h làm việc theo SLA thay vì phát hiện muộn khi khách khiếu nại |
| 3 | OPS_ADS | Khi chưa có quyền API, nhập/import số dư theo schema chuẩn, hệ thống gắn nhãn `manual` + nguồn + timestamp | Vận hành không tắc giai đoạn degraded mà dữ liệu vẫn truy vết được nguồn gốc |
| 4 | SYS_ADMIN | Quản lý API credentials từng platform trong vault mã hóa, MFA, rotate nhắc ≥90 ngày | Không ai giữ plaintext, truy cập platform có kiểm soát, đạt checklist Business Verification |
| 5 | OPS_PLAN | Mọi số liệu GW trả về kèm freshness metadata (nguồn, thời điểm, độ trễ) | Lập kế hoạch ngân sách không dùng số quá hạn vô thức |
| 6 | OPS_AM | Lệnh pause campaign không gắn dự án được GW đẩy thẳng qua API platform khi có quyền | Nguyên tắc "không gắn project = không tồn tại" được thực thi máy, không phụ thuộc tay |
| 7 | OPS_ADS | Khi được cấp API, backfill tự động và đối chiếu số đã nhập tay với số API | Chuyển nguồn minh bạch, lệch số được xử lý trước khi tin vào API |
| 8 | OPS_CONT / OPS_DES / OPS_EDIT | Xem trạng thái đồng bộ (thành công/lỗi/stale, lần sync cuối) của TK gắn với dự án mình | Biết lúc nào số liệu đáng tin để gắn pixel/tracking và chạy creative đúng TK |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Phạm vi GW: enforcement tại tầng adapter/gateway (kể cả degraded mode manual); rule nguồn sự thật nằm ở CORE service layer.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-GW-101 | Vòng pull hourly 7 nền tảng đủ quét 2.600+ TK trong ≤60 phút, retry/backoff theo rate limit từng platform, lưu raw payload mọi lần pull | Vòng chưa đủ hoặc lỗi kéo dài → đánh dấu `stale`, alert SYS_ADMIN và OPS_ADS; cấm trả dữ liệu cũ im lặng |
| BR-GW-102 | Mọi bản ghi số dư/spend/trạng thái bắt buộc gắn nhãn nguồn (`api`/`manual`) + timestamp; API trả dữ liệu cho WEB phải kèm freshness metadata | Payload không nhãn bị adapter từ chối; WEB/M-INT không hiển thị số thiếu timestamp (khớp BR-OPS-5.4) |
| BR-GW-103 | Degraded mode "manual" là trạng thái vận hành chính thức đến khi từng platform được cấp API (DI-007): import statement chuẩn hóa + nhập tay đúng schema registry; được cấp API → backfill tự động rồi đối chiếu manual vs api trước khi chuyển nguồn | Nhập sai schema bị từ chối; chuyển nguồn không qua đối chiếu bị chặn — lệch số phải có báo cáo lệch do OPS_ADS xử lý xong trước khi switch |
| BR-GW-104 | GW chỉ đọc trạng thái gate từ nguồn sự thật FIN/CORE — Hard Stop "Đã khớp tiền" của FIN_L1 (REQ-OPS-002), KYC = Verified (REQ-FIN-009), OADS = CS_APPROVED — và chỉ kết nối/đẩy lệnh điều khiển khi registry ở trạng thái hợp lệ; không tồn tại đường override trong adapter | Yêu cầu kết nối/điều khiển TK chưa qua gate bị từ chối cứng kèm mã lỗi gate; mọi lần từ chối ghi log bất biến |
| BR-GW-105 | Validator biên GW: payload đẩy lên platform phải khớp naming `[ClientCode]-[Platform]-[Objective]-[Market]-[YYMM]`; `utm_source`/`utm_medium`/`utm_campaign` chỉ nhận giá trị sinh từ naming | Payload sai bị chặn ở tầng adapter, không tới platform; log chặn đẩy về CORE tạo task khắc phục |
| BR-GW-106 | Lệnh pause campaign không gắn dự án (job CORE) do GW thực thi qua API platform khi có quyền; chưa có quyền API → trả lỗi "manual required" để quy trình rơi về pause tay của OPS_ADS với nhãn `manual` | GW không tự thực thi lệnh thiếu phê duyệt CORE và không nuốt lỗi im lặng — kết quả từng lệnh (thành công/thất bại/manual) phản hồi về CORE |
| BR-GW-107 | Nối platform ID (`externalAccountId`, `bindInfo` theo platform: TikTok = BC + role, Google = email, Facebook = BMID) do GW thực hiện sau khi TK được tạo trên platform và registry đã qua gate; mọi thay đổi bind ghi access log bất biến | Bind sai đối tượng hoặc bind chưa qua gate bị chặn; thay đổi không log được coi là sự cố bảo mật |
| BR-GW-108 | Credentials platform lưu vault mã hóa — chỉ SYS_ADMIN/BOD_CFO_CTO quản trị trên WEB nội bộ với MFA, rotate ≥90 ngày, không trả plaintext về bất kỳ UI nào; mobile nội bộ cấm hiển thị credentials | Trả plaintext về UI/mobile là lỗi bảo mật P0; credentials quá hạn rotate bị cảnh báo và chặn dùng cho kết nối mới |
| BR-GW-109 | Nhận sự kiện HR (nghỉ việc/chuyển dự án/thay owner) hoặc hết HĐ → thu hồi token/quyền platform trong 24h, sinh task bàn giao cho backup; đóng TK hết HĐ hỗ trợ snapshot evidence + archive trước khi ngắt | Quá 24h chưa revoke → escalation SYS_ADMIN và TL; không được giữ token hoạt động của người đã offboard |
| BR-GW-110 | Raw payload sync và sự kiện die account (trạng thái platform, timestamp nguồn) lưu bất biến append-only có hash — không sửa/xóa hậu kiểm (nguyên tắc evidence die account) | Lời gọi sửa/xóa bị từ chối ở tầng storage; phát hiện can thiệp bắn alert toàn vẹn cho BOD_CFO_CTO |

---

## 4. Phân Quyền

> *Phân quyền theo touchpoint GW: quyền kiểm soát việc gọi API gateway (thao tác qua WEB nội bộ); GW không phục vụ portal khách — khách không có đường nào tới adapter platform. OPS_CONT/OPS_DES/OPS_EDIT cùng cột read-only.*

| Hành động | OPS_ADS | OPS_AM | OPS_PLAN | OPS_CONT / OPS_DES / OPS_EDIT | SYS_ADMIN | BOD_CFO_CTO |
|-----------|---------|--------|----------|------------------------------|-----------|-------------|
| Xem trạng thái sync + freshness của TK liên quan | ✅ | ✅ | ✅ | ✅ (read-only) | ✅ | ✅ |
| Nhập tay / import dữ liệu degraded `manual` | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Kích hoạt sync tay / retry một nền tảng hoặc TK | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Xem trạng thái gate nhận về (Hard Stop, KYC, OADS) | ✅ | ✅ | ✅ | ✅ (read-only) | ✅ | ✅ |
| Xử lý báo cáo lệch manual vs API khi backfill | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Đăng ký/sửa/xóa kết nối platform + vault credentials | ❌ | ❌ | ❌ | ❌ | ✅ (MFA) | ✅ (MFA) |
| Xem access log bind + raw payload store | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| Sửa/xóa raw payload, event die, access log | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Cấu hình adapter nền tảng mới (ngoài 7 nền tảng) | ❌ | ❌ | ❌ | ❌ | ✅ | Duyệt chính sách |

Không vai nào có quyền bypass gate tài chính (BR-GW-104) — kể cả SYS_ADMIN và BOD_CFO_CTO. FIN_L1/FIN_L2 không thao tác trực tiếp trên GW: họ xác nhận gate ở phía FIN/CORE, GW chỉ đọc kết quả.

---

## 5. Trường Hợp Đặc Biệt

- **Chưa có quyền API developer cho nền tảng nào (hiện trạng DI-007):** degraded mode "manual" là trạng thái vận hành chính thức, không phải giải pháp tạm vô định; tiến trình Business Verification từng platform được GW theo dõi và hiển thị trạng thái cho SYS_ADMIN.
- **Token/API hết hạn hoặc bị revoke giữa chừng:** GW dừng kéo dữ liệu mới, đánh dấu `stale`, giữ dữ liệu cuối cùng kèm timestamp; không tự xin quyền vượt phạm vi ủy quyền, alert SYS_ADMIN xử lý.
- **Rate limit hoặc platform đổi API:** backoff theo chính sách từng adapter, không bỏ vòng sync; nếu vòng 60 phút không hoàn thành thì toàn bộ dữ liệu vòng đó được đánh giá lại freshness thay vì nửa tươi nửa cũ không phân biệt.
- **Lệch số giữa dữ liệu manual và backfill API:** sinh báo cáo lệch (bản ghi, khác biệt, timestamp hai nguồn); OPS_ADS xử lý xong mới được chuyển nguồn — không ghi đè im lặng.
- **TK client-owned và TK Internal-Sandbox:** client-owned chỉ sync đo lường read-only, BC không nạp tiền/điều khiển, Hard Stop áp dụng ở mức đo lường; Internal-Sandbox không gắn khách, ngân sách ≤ mức TL duyệt, rà theo quý, gắn cờ nội bộ tránh trộn báo cáo khách.
- **Die account ngoài giờ:** vòng sync chạy 24/7 và đẩy sự kiện về registry ngay; xử lý theo ca on-call SLA 4h (DI-005 đã chốt), không chờ giờ làm việc mới ghi nhận.
- **Nền tảng mới ngoài 7 nền tảng:** adapter cắm theo cấu hình (platformId, authType, schema map), không hardcode; cần SYS_ADMIN cấu hình và BOD_CFO_CTO duyệt chính sách.
- **Phạm vi CMS trong nguồn quy trình gốc:** CMS/AdAccount Service bị đánh dấu "tương lai" trong nguồn tái dựng — việc đưa vào MVP theo registry (REQ-OPS-001, phase = MVP) là quyết định đã chốt của registry; phạm vi mở rộng dài hạn chờ `[KXN-9]`, spec này không tự quyết thêm.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Kết nối nền tảng (`PlatformConnection`) — đối tượng GW quản lý trực tiếp. GW không sở hữu vòng đời TKQC 5 trạng thái (Khởi tạo → Khớp tiền → Cấp phát → Vận hành → Thu hồi/Đóng — nguồn sự thật ở CORE); GW chỉ phản chiếu trạng thái platform (ACTIVE/FROZEN/BLOCKED/OUT_OF_MONEY) từ dữ liệu sync.

**Sơ đồ trạng thái:**
```
[NOT_CONFIGURED] ──(SYS_ADMIN cấu hình + credentials)──► [MANUAL]
[MANUAL] ──(được cấp API + BV xong + backfill & đối chiếu khớp)──► [API_ACTIVE]
[API_ACTIVE] ──(token hết hạn/revoke/lỗi kéo dài)──► [MANUAL] (fallback, nhãn manual)
[MANUAL]/[API_ACTIVE] ──(hết HĐ/offboarding)──► [REVOKED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `NOT_CONFIGURED` | Cấu hình kết nối | `MANUAL` | SYS_ADMIN | Credentials mã hóa vào vault; platform gắn nhãn degraded `manual` |
| `MANUAL` | Chuyển sang API | `API_ACTIVE` | SYS_ADMIN | Business Verification xong + backfill chạy + đối chiếu manual vs api có kết quả, OPS_ADS xử lý xong báo cáo lệch |
| `API_ACTIVE` | Fallback mất API | `MANUAL` | Hệ thống (tự động) | Token hết hạn/revoke/lỗi kéo dài quá ngưỡng backoff; dữ liệu mới gắn nhãn `manual` |
| `MANUAL` / `API_ACTIVE` | Thu hồi kết nối | `REVOKED` | Hệ thống (theo sự kiện HR/HĐ) + SYS_ADMIN xác nhận | Sự kiện offboarding/hết HĐ từ CORE; revoke trong 24h; snapshot + archive khi đóng TK |
| `REVOKED` | Kết nối lại | `MANUAL` | SYS_ADMIN | Cấp credentials mới từ vault, không tái sử dụng token cũ |

**Quy tắc:**
- `REVOKED` là trạng thái kết thúc — kết nối lại luôn tạo chu kỳ credentials mới, không bật lại token cũ.
- Chuyển `MANUAL → API_ACTIVE` không bỏ qua được backfill + đối chiếu — rào chống "tin số API mù quáng" và chống mất lịch sử manual.
- Mọi chuyển trạng thái ghi audit log bất biến (ai/khi nào/từ→sang/căn cứ) ở GW, đồng bộ về CORE audit core.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity GW để developer nắm nhanh — chi tiết DDL tại `database-design.md`; registry TKQC nguồn sự thật ở CORE (tham chiếu CMS Domain Model `documents/02_Quy_trinh_Cho_thue_TKQC.md` §3.4).*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `PlatformConnection` | `platformId`, `authType`, `credentialsRef` (vault), `mode`, `bvStatus`, `lastSyncAt` | 1 platform = 1 connection | GW sở hữu; audit mọi chuyển mode |
| `SyncSnapshot` (raw payload) | `adAccountId`, `platformId`, `rawPayload`, `source`, `fetchedAt`, `hash` | FK → `AdAccount` (CORE) | Append-only bất biến, dùng tái lập và đối chiếu backfill |
| `AdAccountMirror` (phản chiếu) | `externalAccountId`, `balance`, `spendLimit`, `platformStatus`, `source`, `freshnessAt` | FK → `AdAccount` | Read-only từ góc GW — CORE là nguồn sự thật |
| `ManualImportBatch` | `batchId`, `uploadedBy`, `schemaVersion`, `rowCount`, `importedAt` | 1 batch → N `SyncSnapshot` | Chỉ tạo khi connection `MANUAL` |
| `StatusChangeEvent` (die event) | `adAccountId`, `detectedBy`, `oldStatus`, `newStatus`, `evidenceRef`, `occurredAt`, `hash` | FK → `AdAccount` | Bất biến có hash — evidence không sửa hậu kiểm |
| `BindLog` | `adAccountId`, `externalAccountId`, `bindInfo` (JSON theo platform), `actorId`, `boundAt` | FK → `AdAccount` | Access log bất biến mọi thay đổi bind |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được.*
> **Ghi chú:** Acceptance Criteria được điền chi tiết ở Phase 5 (implementation tasks). Phase 2 ghi phác thảo sơ bộ.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Vòng sync hourly đạt freshness | 2.600+ TK trên 7 nền tảng, connection `API_ACTIVE` | Chạy một vòng sync đầy đủ | Hoàn thành ≤60 phút, retry/backoff hoạt động, mọi bản ghi có nhãn `api` + timestamp, raw payload đã lưu | [ ] |
| SC-002: Degraded manual đúng schema | Platform chưa có quyền API (`MANUAL`) | OPS_ADS import statement + nhập tay số dư | Dữ liệu nhận đúng schema registry, gắn nhãn `manual` + nguồn + timestamp; bản ghi sai schema bị từ chối | [ ] |
| SC-003: Backfill và đối chiếu trước chuyển nguồn | Vừa được cấp API, đã có dữ liệu manual | Kích hoạt backfill và chuyển nguồn | Backfill tự động chạy, báo cáo lệch sinh ra; chuyển `API_ACTIVE` chỉ sau khi OPS_ADS xử lý xong lệch | [ ] |
| SC-004: Phát hiện die account từ sync | Một TK bị platform khóa | Vòng sync gặp trạng thái `BLOCKED` | `StatusChangeEvent` kèm timestamp nguồn đẩy về registry trong vòng đó, evidence tham chiếu raw payload bất biến | [ ] |
| SC-005: Pause campaign theo phê duyệt | CORE đã phê duyệt pause campaign không gắn dự án | GW đẩy lệnh pause qua API platform | Thực thi thành công và phản hồi kết quả về CORE; không có quyền API → trả lỗi "manual required", task pause tay sinh cho OPS_ADS | [ ] |
| SC-006: Thu hồi quyền 24h sau offboarding | HR ghi sự kiện nghỉ việc của một owner TK | Đồng hồ 24h chạy | GW revoke token/quyền platform trong 24h, task bàn giao sinh cho backup, audit log bất biến | [ ] |

> **Liên kết:** Mỗi scenario map đến ít nhất 1 REQ — SC-001 → REQ-OPS-001 (BR-OPS-1.5); SC-002/SC-003 → REQ-OPS-001 (BR-OPS-1.8, DI-007); SC-004 → REQ-OPS-001 (BR-OPS-1.6); SC-005 → REQ-OPS-001 (BR-OPS-1.2/1.3); SC-006 → REQ-OPS-001 (BR-OPS-1.7).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` (module MOD-ADACCOUNT-CC) |
| API Endpoints (adapter gateway, webhook trạng thái) | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (7 nền tảng QC, VAS, vault, raw payload store) | `technical-specs/integration-map.md` |
| Màn hình UI (Command Center thuộc SYS-BCERP-WEB — GW không có UI) | `phase4-ux/bcerp-web/adaccount-cc/[screen-group].md` |
| Bản cùng REQ tại hệ thống khác | `phase2-features/core-backend/adaccount-cc/`, `phase2-features/bcerp-web/adaccount-cc/`, `phase2-features/mobile-internal/adaccount-cc/` |
| Domain model nguồn | `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 — §3.2 OADS, §3.3 Contract, §3.4 AdAccount, §3.11 ReplacementRequest) |
