# Tính Năng: Alert center & cảnh báo rủi ro vận hành

> **Dựa trên:** REQ-BOD-006 trong `phase1-business/departments/bod/bod.md` (Phần A — Mục REQ-BOD-006; Phần B — Mục B6)
> **Phân hệ:** Data Integration Hub & Analytics — BI/BOD Dashboard (SYS-CORE-BACKEND)
> **Module:** Data Integration Hub & Analytics — BI/BOD Dashboard (MOD-DATAHUB-BI)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/datahub-bi/*.md`, `phase5-implementation/tasks/core-backend/datahub-bi/feat-core-dhub-003-impl.md`

> **Hướng dẫn ID:** FEAT-CORE-DHUB-003 được tạo từ REQ-BOD-006 theo quy tắc chung trong req-registry (SYS=CORE-BACKEND, MOD=DATAHUB-BI). REQ này fan-out trên 3 systems — file này là bản riêng cho SYS-CORE-BACKEND (rule engine + delivery đa kênh); counterparts: SYS-BCERP-WEB (alert center tổng hợp — đã/chưa xử lý, drill về nguồn), SYS-MOBILE-INTERNAL (kênh chính cảnh báo khẩn — push realtime ≤5 phút).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-DHUB-003 |
| Module | MOD-DATAHUB-BI (SYS-CORE-BACKEND) |
| Yêu cầu nghiệp vụ | REQ-BOD-006 — Alert center & cảnh báo rủi ro vận hành (HIGH · MVP sync/hard stop/backup → Phase2 SLA, khiếu nại → Phase3 alert center BI) |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP: alert sync/hard stop/backup) → Phase2 (SLA, khiếu nại) → Phase3 (alert center BI) |
| Phụ thuộc | Hash-chain audit (REQ-BOD-005), số dư ví + hạn mức tuần nạp (REQ-FIN-002/001), trạng thái TKQC die/spike/checkpoint (OPS), backup & job sync (vận hành hệ thống), stale dữ liệu từ FEAT-CORE-DHUB-001/002, khiếu nại SLA (Luồng 5, REQ-OPS-008) |
| Ghi chú Expert (A7) | Dept doc `bod.md` có Mục A7 nhưng chưa ghi điều chỉnh đã chốt (chờ expert review) — spec hiện hành theo Phần A/B; khi A7 có điều chỉnh sẽ cập nhật dòng này |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Xây dựng trên core backend rule engine đánh giá sự kiện vận hành theo ngưỡng cấu hình được, phân mức nghiêm trọng và delivery đa kênh để cảnh báo rủi ro đến đúng người trong thời gian cho phép — MOBILE push ≤5 phút từ lúc phát hiện là kênh chính cho cảnh báo khẩn, WEB là nơi phân tích/xử lý đầy đủ. Alert center bảo đảm không có rủi ro nào "nổ lặng": mọi cảnh báo đỏ phải có người nhận trách nhiệm và chỉ tắt khi có acknowledge + reason.

**Phạm vi:**
- Bao gồm: rule engine ngưỡng cấu hình (không hardcode); bộ cảnh báo bắt buộc cho BOD (đứt hash-chain; số dư ví dưới ngưỡng đủ chi; die/spike/checkpoint TKQC; SLA breach đỏ; vượt hạn mức tuần nạp; backup thất bại 30 phút; job sync fail; stale dữ liệu nghiêm trọng); leo thang khiếu nại nghiêm trọng từ khách lên BOD theo SLA; gộp alert theo nguồn khi connector outage để không ngập người nhận; acknowledge + reason; re-push đến khi có người nhận trách nhiệm; thống kê vi phạm SoD bị chặn gửi CFO rà định kỳ; API phục vụ alert center WEB và push MOBILE.
- Không bao gồm: UI tổng hợp alert (counterpart SYS-BCERP-WEB), bản push mobile và deep-link (counterpart SYS-MOBILE-INTERNAL), phát hiện đứt hash-chain và chạy job kiểm tra toàn vẹn (sở hữu bởi phân hệ RBAC-AUDIT — tính năng này tiêu thụ sự kiện), chất dữ liệu nền của cảnh báo (FEAT-CORE-DHUB-001/002 phát sự kiện), xử lý khiếu nại nghiệp vụ (OPS sở hữu — tính năng này chỉ leo thang theo SLA).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CEO | Nhận push khẩn ≤5 phút khi có đứt hash-chain, die account hàng loạt, backup thất bại | Phản ứng rủi ro trong giờ, không đợi báo cáo ngày hôm sau |
| 2 | BOD_CFO_CTO | Nhận cảnh báo số dư ví dưới ngưỡng đủ chi và vượt hạn mức tuần nạp | Chủ động điều phối dòng tiền trước khi TKQC khách chết vì hết tiền |
| 3 | BOD_CEO | Tắt alert chỉ khi nhập acknowledge + reason | Mọi cảnh báo có dấu vết trách nhiệm, không ai "vuốt ve" cho hết đỏ |
| 4 | BOD_CFO_CTO | Xem thống kê vi phạm SoD bị chặn theo kỳ | Rà định kỳ xem có pattern lừa duyệt hay phân quyền sai cần xử lý |
| 5 | SYS_ADMIN | Nhận alert kỹ thuật (job sync fail, backup thất bại, connector outage) với mức ưu tiên đúng | Xử lý hạ tầng sớm mà không bị nhầm vào alert đỏ thuộc trách nhiệm BOD |
| 6 | Hệ thống (rule engine CORE) | Tự gộp alert theo nguồn khi connector outage và ưu tiên theo mức | Người nhận không bị ngập hàng trăm alert trùng gốc trong lúc sự cố |
| 7 | BOD_CEO | Nhận leo thang khiếu nại nghiêm trọng từ khách vượt ngưỡng SLA | Can thiệp thương mại trước khi khách rời bỏ |

**Đặc thù touchpoint SYS-CORE-BACKEND:** toàn bộ logic phân mức, gộp, re-push, acknowledge được enforce ở service layer — WEB/MOBILE chỉ là kênh hiển thị/nhận; alert không thể bị xóa hay đánh dấu xử lý bằng cách gọi thẳng API kênh hiển thị; mọi thao tác acknowledge/resolve ghi audit log; Portal khách không liên quan tính năng này (cảnh báo nội bộ, không lộ rủi ro vận hành ra ngoài tenant khách).

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code, toàn bộ enforce ở service layer của CORE.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-BOD-006.1 | Bộ cảnh báo BOD bắt buộc: đứt hash-chain audit; số dư ví dưới ngưỡng đủ chi `[CẦN CHỐT SỐ — đề xuất mặc định ≥3 ngày chi bình quân]`; die/spike/checkpoint TKQC; SLA breach đỏ; vượt hạn mức tuần nạp; backup thất bại (30 phút); job sync fail; stale dữ liệu nghiêm trọng (chi QC >8h, ví >2h, timesheet >24h) | Rule thiếu so với danh sách này bị audit cấu hình bắt; sự kiện khớp rule phải sinh alert, không được mute theo nguồn |
| BR-BOD-006.2 | Connector outage → gộp alert theo nguồn, ưu tiên theo mức nghiêm trọng, không ngập người nhận | Rule engine tự dedupe/gộp; nếu vẫn vượt ngưỡng dồn ứ thì phát một alert tổng kèm số liệu đếm |
| BR-BOD-006.3 | Khiếu nại nghiêm trọng từ khách leo thang BOD theo SLA (khiếu nại 24h; breach đỏ ≤5 phút — Luồng 5) | Quá SLA leo thang không phát → audit phát hiện việc bỏ sót; alert leo thang không được hủy bởi OPS |
| BR-BOD-006.4 | Thống kê vi phạm SoD bị chặn (theo REQ-BOD-002) gửi CFO rà định kỳ | Báo cáo thống kê sinh tự động theo kỳ; không có cơ chế tắt thống kê |
| BR-DHUB-301 | Alert chỉ tắt bằng acknowledge + reason; cảnh báo đỏ bắt buộc có người nhận trách nhiệm; re-push đến khi có người nhận `[CẦN CHỐT SỐ — đề xuất chu kỳ 15 phút với mức đỏ]` | Tắt alert không reason bị service từ chối; alert đỏ không người nhận tiếp tục re-push và lên đầu hàng đợi |
| BR-DHUB-302 | Phân kênh delivery: MOBILE push tóm tắt + deep-link về WEB; phân mức nghiêm trọng 3 mức (đỏ/vàng/xanh); push ≤5 phút từ lúc phát hiện cho mức đỏ; không hiển thị dữ liệu T3/T4 trên lock-screen | Gửi sai kênh/sai mức được đo lường delivery SLA; nội dung nhạy cảm bị mask trước khi đẩy kênh mobile |
| BR-DHUB-303 | Data Integration Hub gom sự kiện từ modules + GW; khi thiếu nguồn/connector outage, hệ thống chuyển degraded mode — phát alert "nguồn mù" thay vì im lặng | Không được coi "không có dữ liệu" là "không có rủi ro"; mất telemetry nguồn là bản thân nó một alert |
| BR-DHUB-304 | Dữ liệu lương/PII không xuất hiện trong nội dung alert; nếu rule liên quan (ví dụ cost rate) thì chỉ truyền mức tổng hợp; mọi acknowledge/resolve/escalate của BOD ghi audit log (meta-log — truy xuất cũng bị log) | Rule chứa trường PII bị chặn khi lưu cấu hình; thao tác không log bị chặn ở service |
| BR-DHUB-305 | Ngưỡng alert cấu hình được (không hardcode), thay đổi ngưỡng ghi audit + ai đổi; danh sách đầy đủ cờ cảnh báo K6–K12 từ quy trình khách hàng chưa chốt `[KXN-20 — danh sách cờ còn mở]` — cấu hình theo danh sách hiện hành, bổ sung khi khách chốt | Đổi ngưỡng ngoài luồng cấu hình bị từ chối; cờ mới của khách được thêm qua cấu hình không cần phát hành lại code |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN |
|-----------|---------|-------------|-----------|
| Nhận alert mọi mức (đỏ/vàng/xanh) | ✅ | ✅ | ✅ (chỉ alert kỹ thuật) |
| Acknowledge + reason alert đỏ của BOD | ✅ | ✅ | ❌ (không tự đóng alert đỏ của BOD) |
| Acknowledge alert kỹ thuật (sync, backup, connector) | ✅ | ✅ | ✅ |
| Ghi nhận người xử lý + resolution (qua WEB) | ✅ | ✅ | ✅ (alert kỹ thuật) |
| Cấu hình ngưỡng/phân mức rule | ✅ (duyệt chính sách) | ✅ (đề xuất theo chính sách) | ❌ (thực thi sau duyệt, bị log) |
| Delegate nhận alert khi vắng (không delegate xử lý) | ✅ | ✅ | ❌ |
| Xóa alert / sửa lịch sử alert | ❌ | ❌ | ❌ (append-only) |

> Ghi chú: người vắng cho delegate nhận — không delegate xử lý (theo B6); mọi thao tác acknowledge bị meta-log; CUSTOMER/Portal không liên quan.

---

## 5. Trường Hợp Đặc Biệt

- Connector outage kéo dài nhiều giờ: hàng trăm job sync fail cùng gốc → rule engine gộp thành một alert tổng theo nguồn, kèm số đếm và mốc bắt đầu; khi nguồn hồi phục, alert tổng tự đính kèm báo cáo số job bỏ lỡ cần backfill (nối DI-007).
- Alert đỏ phát lúc nửa đêm: re-push theo chu kỳ `[CẦN CHỐT SỐ — 15 phút đề xuất]` đến khi có người nhận; nếu cả hai BOD đều không nhận trong khung thời gian cấu hình, escalate lên delegate đã khai báo — không có trạng thái "không ai nhận" kết thúc im lặng.
- Khiếu nại khách leo thang: alert kèm hồ sơ khiếu nại (nguồn OPS) theo SLA 24h; breach đỏ thì kênh 5 phút; alert không thể bị đóng bởi bên bị khiếu nại — SoD tra cứu ≠ đối tượng.
- Đứt hash-chain audit: alert ngay cho CTO + CEO; nội dung chỉ chứa định danh chuỗi và mốc — không hiển thị chi tiết log nghiệp vụ trên kênh mobile (dữ liệu Mật/Restricted, nối REQ-BOD-005).
- Số dư ví sát ngưỡng vào cuối tuần: rule tính theo ngày chi dự kiến (từ FEAT-CORE-DHUB-004) nên cảnh báo sớm trước kỳ nghỉ; ngưỡng dùng mặc định ≥3 ngày chi `[CẦN CHỐT SỐ]` cho đến khi FIN chốt số cấu hình.
- Backup thất bại lần 1 ở cụm phụ: cảnh báo mức vàng cho SYS_ADMIN; thất bại vượt 30 phút hoặc cụm chính → mức đỏ cho BOD.
- Cảnh báo từ bộ cờ K6–K12 của quy trình khách hàng: chỉ kích hoạt những cờ đã có nguồn dữ liệu xác định; các cờ còn chốt `[KXN-20]` để chỗ trống cấu hình — không hardcode giả định.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Alert (sự kiện cảnh báo)

**Sơ đồ trạng thái:**
```
[OPEN] ──(acknowledge + reason)──► [ACKNOWLEDGED] ──(bắt đầu xử lý)──► [IN_PROGRESS]
   │                                                              │
   │ (re-push chu kỳ nếu đỏ, chưa ai nhận)                        │ (resolve kèm minh chứng)
   ▼                                                              ▼
[OPEN] (vẫn OPEN cho đến khi có acknowledge)                   [RESOLVED] ──(BOD xác nhận đóng)──► [CLOSED]
                                       [ESCALATED] ◄──(quá SLA xử lý)── [ACKNOWLEDGED/IN_PROGRESS]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `OPEN` | Acknowledge | `ACKNOWLEDGED` | BOD_CEO/BOD_CFO_CTO (đỏ), SYS_ADMIN (kỹ thuật) | Bắt buộc nhập reason; alert đỏ ghi người nhận trách nhiệm |
| `ACKNOWLEDGED` | Bắt đầu xử lý | `IN_PROGRESS` | Người nhận trách nhiệm | Ghi kế hoạch xử lý |
| `IN_PROGRESS` | Resolve | `RESOLVED` | Người nhận trách nhiệm | Kèm minh chứng xử lý + resolution note |
| `RESOLVED` | Xác nhận đóng | `CLOSED` | BOD (mức đỏ) / SYS_ADMIN (kỹ thuật) | Người đóng ≠ người gây ra sự kiện (SoD) |
| `ACKNOWLEDGED`/`IN_PROGRESS` | Quá SLA xử lý | `ESCALATED` | Hệ thống | Theo SLA cấu hình; escalate lên cấp trên của người nhận |

**Quy tắc:**
- `OPEN` mức đỏ re-push chu kỳ `[CẦN CHỐT SỐ — 15 phút]` đến khi có acknowledge — không tự hết hạn.
- Không xóa/sửa alert đã phát; mọi chuyển trạng thái append-only + meta-log.
- `CLOSED` là trạng thái kết thúc — không quay lại; rủi ro tái phát sinh alert mới.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `alert_rule` | `rule_id`, `event_source`, `threshold_config`, `severity`, `channels`, `owner_role`, `active` | N-1 → nguồn sự kiện | Ngưỡng cấu hình được; đổi cấu hình bị audit; `[KXN-20]` cờ K6–K12 mở rộng qua cấu hình |
| `alert_event` | `alert_id`, `rule_id`, `fired_at`, `severity`, `payload_ref`, `dedupe_key`, `status` | FK → `alert_rule` | Dedupe/gộp theo nguồn khi outage; append-only |
| `alert_action` | `action_id`, `alert_id`, `actor`, `action_type` (ack/resolve/escalate/delegate), `reason`, `at` | FK → `alert_event`, `users` | Thiếu reason → không submit; meta-log đầy đủ |
| `alert_delivery` | `delivery_id`, `alert_id`, `channel` (push/web), `sent_at`, `delivered_at`, `ack_latency` | FK → `alert_event` | Đo SLA push ≤5 phút mức đỏ; re-push scheduler |
| `sod_violation_stat` | `period`, `blocked_attempts`, `actor_role`, `rule_ref` | FK → audit log nguồn | Thống kê gửi CFO rà định kỳ (BR-BOD-006.4) |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết điền đầy đủ ở Phase 5; dưới đây là phác thảo sơ bộ.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Push ≤5 phút | Mức đỏ phát hiện lúc 14:00:00 | Đo thời điểm push đến MOBILE | Push gửi ≤14:05:00 với tóm tắt + deep-link; không hiển thị T3/T4 | [ ] |
| SC-002: Ack bắt buộc reason | Alert đỏ `OPEN` | Acknowledge không nhập reason | Service từ chối; alert giữ `OPEN`, tiếp tục re-push | [ ] |
| SC-003: Gộp alert outage | Connector X fail → 120 job sync fail | Rule engine đánh giá | Chỉ 1 alert tổng theo nguồn + số đếm; không dồn 120 alert riêng lẻ | [ ] |
| SC-004: Leo thang khiếu nại | Khiếu nại nghiêm trọng từ khách tạo lúc 09:00 | Đến 09:00 ngày hôm sau chưa xử lý | Alert leo thang BOD phát tự động theo SLA 24h | [ ] |
| SC-005: Thống kê SoD | Có 7 lần duyệt bị chặn vì xung đột vai trong quý | Hết kỳ | Báo cáo thống kê sinh gửi CFO; không thể tắt | [ ] |

> **Liên kết:** Mỗi scenario map về REQ-BOD-006 (Phần A/B `bod.md`) và BR-BOD-006.x / BR-DHUB-30x ở Mục 3.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) — alert rule/event/action/delivery | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints — rule config, alert query, acknowledge/resolve | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống — nguồn sự kiện modules + GW, push mobile, degraded mode | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI (counterpart WEB/MOBILE) | `phase4-ux/bcerp-web/datahub-bi/*.md`, `phase4-ux/mobile-internal/datahub-bi/*.md` |
| Feature liên quan cùng module | FEAT-CORE-DHUB-001/002 (nguồn sự kiện stale), FEAT-CORE-DHUB-004 (ngưỡng ví/ngày chi dự kiến), FEAT-CORE-DHUB-005 (alert dòng tiền) |
