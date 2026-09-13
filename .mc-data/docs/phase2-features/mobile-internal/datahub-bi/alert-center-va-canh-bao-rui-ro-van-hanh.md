# Tính Năng: Alert Center & Cảnh Báo Rủi Ro Vận Hành (Kênh Push Mobile)

> **Dựa trên:** REQ-BOD-006 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** Mobile App — BCERP Internal (SYS-MOBILE-INTERNAL)
> **Module:** DataHub & BI (MOD-DATAHUB-BI)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-internal/datahub-bi/alert-center.md`, `phase5-implementation/tasks/mobile-internal/datahub-bi/feat-mbi-dhub-003-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-DHUB-003 |
| Module | MOD-DATAHUB-BI |
| Yêu cầu nghiệp vụ | REQ-BOD-006 (Alert center & cảnh báo rủi ro vận hành) |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP: alert sync/hard stop/backup) → Giai đoạn 2 (SLA, khiếu nại) → Giai đoạn 3 (alert center BI tổng hợp) |
| Phụ thuộc | Rule engine + delivery đa kênh + phân mức nghiêm trọng của SYS-CORE-BACKEND; hạ tầng push (FCM/APNs); REQ-BOD-011 (MDM + MFA TOTP, đăng ký thiết bị); REQ-BOD-005 (alert đứt hash-chain); counterpart WEB FEAT-ERP-DHUB-003 (alert center tổng hợp) |
| Ghi chú Expert (A7) | Dept doc BOD có mục A7 nhưng chưa ghi điều chỉnh riêng cho REQ-BOD-006 — không có thay đổi phạm vi từ Expert Review |

REQ-BOD-006 fan-out ra 3 hệ thống; bản này là bản đặc tả riêng cho touchpoint **SYS-MOBILE-INTERNAL** — tính năng mà dept doc xác định **MOBILE là kênh chính**: cảnh báo khẩn push realtime ≤5 phút từ lúc phát hiện, hiển thị đỏ nổi bật. WEB (SYS-BCERP-WEB) là trung tâm tổng hợp — phân loại, drill nguồn, xử lý đầy đủ; mobile nhận tóm tắt + acknowledge + deep-link sang WEB.

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa mọi cảnh báo rủi ro nghiêm trọng của BCERP đến BOD_CEO/BOD_CFO_CTO trên điện thoại trong vòng 5 phút từ lúc phát hiện, nổi bật tương xứng mức nghiêm trọng — để không sự cố nào (đứt hash-chain audit, ví thiếu tiền chi, die account, backup thất bại) đi qua im lặng chỉ vì người có trách nhiệm không mở máy tính. Mỗi cảnh báo đỏ buộc phải có người nhận trách nhiệm qua acknowledge + reason, và hệ thống re-push liên tục cho đến khi có người nhận.

**Phạm vi:**
- Bao gồm:
  - Push realtime (≤5 phút) cho toàn bộ nhóm cảnh báo BOD bắt buộc theo BR-BOD-006.1: đứt hash-chain audit; số dư ví dưới ngưỡng đủ chi `[CẦN CHỐT SỐ — đề xuất ≥3 ngày chi bình quân]`; die/spike/checkpoint TKQC; SLA breach đỏ; vượt hạn mức tuần nạp; backup thất bại (quá 30 phút); job sync fail; stale dữ liệu nghiêm trọng.
  - Cảnh báo đỏ hiển thị nổi bật trên app (banner + badge + âm/thị giác theo mức), không thể quét nhẹ thành thông thường.
  - Luồng acknowledge từ mobile: reason bắt buộc để tắt alert; mức đỏ ghi người nhận trách nhiệm; hỗ trợ offline — acknowledge đưa vào hàng đợi mã hóa, sync khi có mạng.
  - Delegate nhận: BOD vắng cho delegate **nhận** alert (không delegate xử lý) — cấu hình trên WEB, mobile hiển thị "nhận theo ủy quyền #id".
  - Thống kê vi phạm SoD bị chặn định kỳ gửi CFO (BOD_CFO_CTO) rà.
  - Deep-link từ alert sang màn phân tích nguồn trên WEB và đúng màn liên quan trên app (ví: FEAT-MBI-DHUB-004; KPI: FEAT-MBI-DHUB-002).
  - Gộp alert khi connector outage: gộp theo nguồn, ưu tiên theo mức — không ngập người nhận.
- Không bao gồm:
  - Alert center tổng hợp đầy đủ: phân loại, drill nguồn, ghi resolution, thống kê theo kỳ — thuộc SYS-BCERP-WEB (FEAT-ERP-DHUB-003).
  - Rule engine đánh giá sự kiện, phân mức, định tuyến kênh — thuộc SYS-CORE-BACKEND.
  - Đóng alert đỏ của BOD bởi SYS_ADMIN — bị cấm; SYS_ADMIN chỉ nhận alert kỹ thuật.
  - Hiển thị chi tiết credentials/vault trên mobile — cấm theo BR-BOD-008.2.
  - Tra cứu audit log chi tiết — cấm theo BR-BOD-005.3; chỉ **nhận** alert đứt chuỗi.

---

## 2. Luồng Người Dùng (User Stories)

Mobile là kênh "nghe thấy — nhận trách nhiệm — chuyển đúng nơi xử lý": các user story phản ánh đúng vai trò kênh khẩn, không thay thế phân tích trên WEB.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CEO | Nhận push đỏ trong 5 phút khi số dư ví khách sắp không đủ chi theo ngày dự kiến | Nhắc FIN/AM xử lý nạp trước khi campaign khách bị pause |
| 2 | BOD_CEO | Thấy alert đứt hash-chain audit ngay trên điện thoại, mức đỏ cao nhất | Điều phối phản ứng sự cố ghi nhận dữ liệu ngay lập tức |
| 3 | BOD_CFO_CTO | Nhấn acknowledge và nhập lý do ngay trên mobile | Chốt trách nhiệm xử lý tại thời điểm nhận, không đợi về văn phòng |
| 4 | BOD_CFO_CTO | Nhận định kỳ thống kê vi phạm SoD bị chặn | Rà mẫu hình vi phạm để hiệu chỉnh phân quyền, không chỉ xử lý sự kiện lẻ |
| 5 | BOD_CEO/BOD_CFO_CTO | Khi connector outage, nhận 1 alert gộp theo nguồn thay vì hàng chục alert lẻ | Không bị ngập thông báo mà vẫn biết nguồn nào đang sự cố |
| 6 | BOD_CEO/BOD_CFO_CTO | Nhấn deep-link từ alert sang màn WEB phân tích chi tiết | Xử lý chứng cứ đầy đủ trên màn lớn ngay sau khi nhận trách nhiệm |
| 7 | BOD_CEO | Ủy quyền cho một cá nhân cụ thể nhận alert khi công tác xa | Không có khung giờ nào alert đỏ không ai nghe thấy |
| 8 | SYS_ADMIN | Nhận alert kỹ thuật (job sync fail, backup chậm) qua kênh riêng | Xử lý phần hệ thống mà không đụng alert đỏ của BOD |

---

## 3. Quy Tắc Nghiệp Vụ

Rule engine + phân mức + định tuyến do CORE enforce; app mobile bảo đảm hành vi nhận/acknowledge đúng luật dưới đây — đặc biệt ràng buộc nội dung notification và trách nhiệm người nhận.

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Push cảnh báo khẩn đến mobile **≤5 phút từ lúc phát hiện**; toàn bộ cảnh báo BOD bắt buộc theo BR-BOD-006.1 (đứt hash-chain, ví dưới ngưỡng đủ chi `[CẦN CHỐT SỐ — đề xuất ≥3 ngày chi bình quân]`, die/spike/checkpoint TKQC, SLA breach đỏ, vượt hạn mức tuần nạp, backup thất bại 30 phút, job sync fail, stale dữ liệu nghiêm trọng) phải đi qua kênh mobile | Alert chậm quá SLA kênh → đo lường + báo cáo; sự kiện hợp lệ không push được phải có bằng chứng delivery (receipt) |
| BR-002 | **Tắt alert chỉ bằng acknowledge + reason**; thiếu reason → không submit; cảnh báo đỏ bắt buộc ghi người nhận trách nhiệm | Client gửi acknowledge không reason → API từ chối; UI không có nút ack rỗng |
| BR-003 | Mức đỏ chưa có người nhận → **re-push chu kỳ** đến khi có người nhận `[CẦN CHỐT SỐ: đề xuất 15 phút với mức đỏ]`; acknowledge offline chỉ tính khi sync lên server thành công | Trạng thái "đã đọc" local không được coi là đã nhận; hệ thống re-push đến khi record ACKNOWLEDGED trên CORE |
| BR-004 | **Không hiển thị T3/T4 và chi tiết tài chính nhạy cảm trên lock-screen**; nội dung push trung tính ("Alert đỏ: cần xác nhận — mở app"), chi tiết chỉ sau unlock + MFA step-up | Notification lộ giá trị → lỗi bảo mật P1, chặn phát hành |
| BR-005 | **SYS_ADMIN không tự đóng alert đỏ của BOD** — chỉ nhận alert kỹ thuật; alert đỏ BOD chỉ BOD_CEO/BOD_CFO_CTO (hoặc delegate nhận) acknowledge | Vai sai acknowledge → API từ chối + audit vi phạm |
| BR-006 | Connector outage → alert **gộp theo nguồn**, ưu tiên theo mức, không ngập người nhận; một nguồn lỗi sinh tối đa một luồng alert mở (cập nhật thay vì sinh mới) | Hơn 1 alert mở/nguồn/loại → rule engine phải gộp; mobile hiển thị số sự kiện con bên trong |
| BR-007 | Delegate: ủy cho cá nhân cụ thể **nhận** alert, có thời hạn, log nhãn "theo ủy quyền #id"; delegate nhận không delegate tiếp và không xử lý thay | Cấu hình ngoài luồng → WEB từ chối; acknowledge của delegate ghi đúng chủ thể + ủy quyền |
| BR-008 | Khiếu nại nghiêm trọng leo thang BOD theo SLA và đi qua kênh mobile với mức tương ứng (GĐ2) | Leo thang không push → thiếu sót kênh delivery, đo tại telemetry |
| BR-009 | Thống kê vi phạm SoD bị chặn gửi CFO rà định kỳ qua app (kèm thông báo khi có kỳ mới) | Thiếu kỳ nào → báo cáo delivery của kênh mobile phát hiện |
| BR-010 | Mọi thao tác acknowledge/reason/deep-link trên mobile ghi audit log kèm channel="mobile" + thiết bị; việc nhận alert cũng bị log | Offline → hàng đợi mã hóa flush khi có mạng; mất thiết bị → thu hồi phiên + rotate ≤24h |
| BR-011 | Mobile qua MDM + MFA TOTP bắt buộc; alert đỏ chỉ hiển thị đầy đủ trong phiên đã unlock hợp lệ | Phiên không hợp lệ → yêu cầu đăng nhập lại trước khi xem chi tiết |

---

## 4. Phân Quyền

Enforcement ở service layer CORE (rule engine + alert service); bảng dưới liệt kê hành động trên touchpoint mobile. Chỉ dùng 18 vai registry.

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN |
|-----------|---------|-------------|-----------|
| Nhận push mọi mức alert | ✅ | ✅ | ✅ (chỉ nhóm kỹ thuật) |
| Xem chi tiết alert đỏ BOD (sau unlock) | ✅ | ✅ | ❌ |
| Acknowledge + reason alert đỏ BOD | ✅ | ✅ | ❌ (cấm — BR-005) |
| Acknowledge + reason alert kỹ thuật | ❌ | ❌ | ✅ |
| Cấu hình delegate nhận alert cho mình | ✅ (thao tác trên WEB, hiệu lực cả mobile) | ✅ (như trái) | ❌ |
| Nhận alert theo ủy quyền | ❌ | ❌ | ❌ (chỉ cá nhân được ủy — vai bất kỳ theo cấu hình) |
| Nhận thống kê vi phạm SoD | ❌ | ✅ (CFO) | ❌ |
| Xem danh sách + trạng thái + deep-link nguồn | ✅ | ✅ | ✅ |
| Sửa rule/ngưỡng alert từ mobile | ❌ (chỉ trên WEB theo REQ-BOD-009) | ❌ (chỉ trên WEB) | ❌ (chỉ trên WEB) |
| Đóng/xóa alert record | ❌ | ❌ | ❌ (alert append-only, đóng = trạng thái có dấu vết) |

Nguyên tắc bổ sung: alert gửi cả hai BOD; người vắng cho delegate nhận nhưng không delegate xử lý; mọi thao tác từ kênh mobile ghi immutable audit log.

---

## 5. Trường Hợp Đặc Biệt

- **Alert xảy ra khi thiết bị offline/tắt:** hệ thống coi alert là chưa nhận, re-push theo chu kỳ và gửi fallback theo cấu hình (email) `[CẦN CHỐT SỐ: kênh fallback ngoài push — đề xuất email + cuộc gọi cho mức đỏ]`; khi mở app, alert chưa nhận tải về ngay và bắt buộc acknowledge trước khi xem màn khác nếu có alert đỏ tồn tại.
- **Acknowledge offline (mất mạng ngay khi bấm):** reason + danh tính được ký, lưu hàng đợi mã hóa, hiển thị "đã ghi — chờ đồng bộ"; server vẫn re-push đến khi bản ghi sync thành công — tránh tranh chấp "tôi đã bấm rồi".
- **Connector outage tạo bão alert:** rule engine gộp theo nguồn (một luồng alert mở mỗi nguồn/loại, cập nhật số sự kiện con); mobile hiển thị thẻ gộp với badge đếm — đúng BR-BOD-006.2.
- **Cờ cảnh báo K6–K12 chưa chốt:** danh sách đầy đủ cờ cảnh báo TMKD đang chờ khách hàng xác nhận `[KXN-20]` — rule engine khởi tạo với bộ alert BOD bắt buộc theo REQ-BOD-006 và các ngưỡng stale đã chốt; cờ K6–K12 bổ sung sau khi `[KXN-20]` chốt, không tự phát minh ngưỡng.
- **Alert đứt hash-chain audit:** mức đỏ cao nhất, người nhận bắt buộc cả CEO và CTO; mobile chỉ hiển thị tóm tắt — tra cứu log chi tiết không trên mobile (BR-BOD-005.3), deep-link đưa về WEB đúng màn tra cứu có phê duyệt.
- **Alert sức khỏe adapter GW:** chỉ kèm trạng thái kỹ thuật (nguồn, lỗi, từ khi), không kèm giá trị credentials; thao tác vault chỉ trên WEB theo BR-BOD-008.2.
- **Cả hai BOD đều không acknowledge:** delegate nhận tiếp nhận; nếu vẫn không ai nhận sau các chu kỳ re-push, hệ thống escalate kênh khẩn `[CẦN CHỐT SỐ: mốc escalate cuối — đề xuất sau 3 chu kỳ]` và ghi sự cố "alert không có người nhận" vào báo cáo kỳ.
- **Máy BOD bị mất khi có alert đỏ đang mở:** remote wipe MDM + thu hồi thiết bị + rotate token ≤24h; alert đỏ tiếp tục re-push qua thiết bị còn lại và delegate — không có khung giờ mù thông tin.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

Entity lõi là **Alert** — vòng đời từ phát sinh đến đóng có trách nhiệm; mobile tham gia trực tiếp chuyển đổi acknowledge, còn lại do hệ thống. WEB render cùng state machine ở dạng bảng tổng hợp.

**Entity:** Alert (cảnh báo rủi ro vận hành)

**Sơ đồ trạng thái:**
```
[OPEN] ──(acknowledge + reason)──► [ACKNOWLEDGED] ──(bắt đầu xử lý)──► [IN_PROGRESS] ──(ghi resolution)──► [RESOLVED]
   │                                      │                                │
   │ (re-push khi đỏ chưa có người nhận)   │ (escalate quá SLA xử lý)       │ (xác minh lại thất bại — tái mở)
   ▼                                      ▼                                ▼
[OPEN] (re-push chu kỳ)               [ESCALATED] ──(cấp trên nhận)──► [IN_PROGRESS]            [ACKNOWLEDGED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `OPEN` | Acknowledge | `ACKNOWLEDGED` | BOD (alert đỏ) / SYS_ADMIN (alert kỹ thuật); delegate nhận được phép | Reason bắt buộc; mức đỏ ghi người nhận trách nhiệm; sync lên CORE thành công |
| `OPEN` | Re-push (hệ thống) | `OPEN` (chu kỳ lại) | Hệ thống | Mức đỏ chưa có người nhận; chu kỳ theo cấu hình (đề xuất 15 phút) |
| `ACKNOWLEDGED` | Bắt đầu xử lý | `IN_PROGRESS` | Người nhận trách nhiệm | Ghi đầu xử lý/kế hoạch |
| `IN_PROGRESS` | Đóng với resolution | `RESOLVED` | Người nhận trách nhiệm; alert đỏ BOD không do SYS_ADMIN đóng | Resolution + bằng chứng (link giao dịch/job) |
| `IN_PROGRESS` | Escalate quá SLA | `ESCALATED` | Hệ thống | SLA xử lý của mức vượt hạn; thông báo lên cấp trên |
| `RESOLVED` | Tái mở khi tái diễn | `ACKNOWLEDGED` | BOD | Sự kiện lặp trong cửa sổ cấu hình; lịch sử alert cũ giữ nguyên |

**Quy tắc:**
- Không có đường nào đến "xóa" — alert record append-only; `RESOLVED` là kết thúc có đầy đủ dấu vết, tái diễn sinh tái mở có kiểm soát chứ không xóa lịch sử.
- Trên mobile, chuyển đổi khả dụng chỉ là acknowledge (+reason) và xem; phân tích/đóng resolution đầy đủ diễn ra trên WEB.
- Acknowledge chỉ có hiệu lực khi record sync lên CORE — trạng thái trên thiết bị luôn phản ánh trạng thái server, không trạng thái local tự phong.

---

## 7. Tóm Tắt Entity (Quick Reference)

Entity do CORE sở hữu (alert service); mobile tiêu thụ qua push + API sync. DDL đầy đủ tại technical spec CORE.

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `alert` | `code`, `severity` (red/amber/info), `source`, `category`, `state`, `fired_at`, `payload_json` | FK → `alert_rule`, 1-N → `alert_event` | Append-only; payload không chứa T3/T4/credentials |
| `alert_rule` | `code`, `condition_json`, `severity`, `channels`, `repush_minutes`, `enabled` | 1-N → `alert` | Ngưỡng cấu hình được; thay đổi qua WEB theo REQ-BOD-009 |
| `alert_acknowledgement` | `alert_id`, `user_id`, `reason`, `delegation_id`, `device_id`, `client_at`, `server_at` | FK → `alert`, `users` | Ghi cả thời điểm thiết bị và thời điểm sync; nhãn ủy quyền |
| `alert_delegation` | `from_user`, `to_user`, `valid_from`, `valid_to`, `status` | FK → `users` | Cấu hình trên WEB; chỉ cho "nhận", không cho "xử lý" |
| `push_delivery_log` | `alert_id`, `device_id`, `sent_at`, `delivered_at`, `provider_receipt` | FK → `device_registry` | Bằng chứng delivery ≤5 phút; thiếu receipt → fallback kênh |
| `sod_violation_stat` | `period`, `attempt_count`, `blocked_count`, `by_role` | — | Sinh định kỳ gửi CFO qua app |

---

## 8. Acceptance Criteria

> Điều kiện nghiệm thu phác thảo ở Phase 2; chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-BOD-006 (Mục 2) và business rules Mục 3.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Push đúng SLA 5 phút | Số dư ví khách rơi dưới ngưỡng đủ chi | Rule engine bắn alert | Push đến thiết bị BOD trong ≤5 phút; có `push_delivery_log` receipt; lock-screen trung tính, không số | [ ] |
| SC-002: Acknowledge bắt buộc reason | Alert đỏ hiển thị trên app | Nhấn acknowledge | Không submit được khi thiếu reason; sau khi nhập, trạng thái ACKNOWLEDGED trên CORE, re-push dừng | [ ] |
| SC-003: Re-push khi chưa nhận | Alert đỏ không ai acknowledge 15 phút | Hệ thống chạy chu kỳ | Push lại với mức tăng cảnh báo; tiếp tục cho đến khi có người nhận; mọi lần re-push ghi log | [ ] |
| SC-004: Gộp alert connector outage | 20 job sync cùng nguồn fail liên tiếp | Rule engine xử lý | Chỉ 1 alert gộp theo nguồn đang mở với badge "20 sự kiện"; không sinh 20 push riêng | [ ] |
| SC-005: SYS_ADMIN không đóng alert đỏ | SYS_ADMIN mở alert đỏ của BOD | Cố acknowledge | API từ chối + audit vi phạm; chỉ thao tác được alert nhóm kỹ thuật | [ ] |
| SC-006: Delegate nhận đúng chủ thể | CEO ủy quyền nhận cho cá nhân X | X acknowledge alert | Bản ghi ghi user X + "theo ủy quyền #id"; hết hạn ủy quyền → X không nhận push mới | [ ] |
| SC-007: Acknowledge offline sync | Mất mạng ngay khi bấm acknowledge | Mạng trở lại | Hàng đợi mã hóa flush; record ACKNOWLEDGED trên CORE với cả client_at và server_at; re-push dừng sau sync | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách; file này giữ ở mức đặc tả nghiệp vụ cho touchpoint mobile nội bộ.

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu alert, rule, acknowledgement, delivery log | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (alert sync, acknowledge, delegate, push registration) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp rule engine CORE ↔ FCM/APNs ↔ MDM; fallback kênh | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI alert center mobile (React Native push + banner đỏ) | `phase4-ux/mobile-internal/datahub-bi/alert-center.md` |
| Bản counterpart: alert center tổng hợp + phân tích (WEB) | `phase2-features/bcerp-web/datahub-bi/alert-center-va-canh-bao-rui-ro-van-hanh.md` (FEAT-ERP-DHUB-003) |
| Bản counterpart: rule engine + delivery đa kênh (CORE) | `phase2-features/core-backend/datahub-bi/` (FEAT tương ứng REQ-BOD-006) |
| Dashboard tiêu thụ trạng thái nguồn/stale phát alert | `phase2-features/mobile-internal/datahub-bi/bi-dashboard-dieu-hanh.md` (FEAT-MBI-DHUB-002) |
