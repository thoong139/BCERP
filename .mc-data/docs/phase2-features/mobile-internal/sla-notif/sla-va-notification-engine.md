# Tính Năng: SLA & Notification Engine — Mobile Nội Bộ

> **Dựa trên:** REQ-OPS-008 trong `phase1-business/departments/operations/operations.md` (Phần B.9)
> **Phân hệ:** Mobile nội bộ (SYS-MOBILE-INTERNAL)
> **Module:** MOD-SLA-NOTIF
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`
>
> **Fan-out:** REQ-OPS-008 nằm ở 5 systems; đây là bản riêng SYS-MOBILE-INTERNAL (React Native, offline-capable). Engine SLA thuộc bản SYS-CORE-BACKEND; WEB/PORTAL/M-PORTAL có spec counterpart.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| ID tính năng | FEAT-MBI-SLANOT-001 |
| Module | MOD-SLA-NOTIF |
| Yêu cầu nghiệp vụ | [REQ-OPS-008; REQ-BOD-006 (alert center — liên thông)] |
| Người dùng liên quan | OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; CUSTOMER chỉ nhận thông báo qua SYS-PORTAL-WEB/SYS-MOBILE-PORTAL |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | SLA engine trên SYS-CORE-BACKEND (sinh event pre-alert/breach/override); contract push CORE → M-INT; REQ-BOD-006 nhận breach đỏ |
| Ghi chú Expert (A7) | operations.md có Mục A7 nhưng đang chờ review — chưa có điều chỉnh chốt cho REQ-OPS-008; BR B.9 (call-2, marketing-expert) là căn cứ hiện hành |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa SLA và thông báo tới nhân viên OPS mọi lúc mọi nơi trên mobile nội bộ: nhận push vàng 80% và đỏ 100%, cập nhật hành động, duyệt gia hạn/override trên di động kể cả ngoài giờ hoặc mất mạng — SLA được bảo vệ không phụ thuộc việc ngồi trước WEB, đúng đặc thù AM/ADS di chuyển nhiều, theo dõi 2.600+ TKQC active.

**Phạm vi:**
- Bao gồm:
  - Nhận push pre-alert 80% / breach 100% cho đúng người (assignee, AM, on-call) theo event từ SLA engine CORE.
  - Inbox thông báo trong app (lọc theo loại, đánh dấu đã đọc, mở thẳng ticket/task).
  - Cập nhật hành động khung 80–100% và phản hồi đầu tiên khi di động (ghi mốc FR có nội dung xử lý).
  - Duyệt gia hạn/override trên di động, bắt buộc lý do; offline-capable (xếp hàng, sync khi online).
  - Push cho ca trực Critical on-call xoay vòng ngoài giờ (SLA 4h — DI-005 đã chốt).
  - Dashboard compliance FR/Res rút gọn; cấu hình cá nhân kênh nhận (in-app, email, Zalo/Telegram).
- Không bao gồm:
  - Tính clock, pause/resume, ma trận SLA, escalation chain, audit log override — thuộc SYS-CORE-BACKEND; M-INT chỉ render và gửi lại quyết định.
  - Dashboard đầy đủ, template thông báo khách, post-mortem — thuộc SYS-BCERP-WEB.
  - Đồng hồ song song giờ địa phương khách, CSAT, tạo ticket — thuộc PORTAL/M-PORTAL và REQ-OPS-009; khách chỉ nhận thông báo qua portal/mobile-portal, chỉ event tenant mình (BR-010).
  - Alert center BOD — thuộc REQ-BOD-006 (MOD-DATAHUB-BI); feature này chỉ đẩy sự kiện breach đỏ sang.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_CONT/DES/EDIT/ADS (assignee) | Nhận push vàng 80% kèm link ticket/task của mình | Chủ động xử lý trước khi breach |
| 2 | OPS_AM | Nhận push đỏ breach trong ≤5 phút dù đang gặp khách | Không bỏ sót breach, tránh vi phạm riêng "không thông báo khách" |
| 3 | OPS_AM | Trả lời phản hồi đầu tiên có nội dung xử lý ngay trên mobile | Timestamp FR được ghi nhận đúng |
| 4 | Người trực on-call Critical | Nhận push Critical 24/7 trong ca của mình, SLA 4h ngoài giờ | Sự cố TKQC được tiếp nhận cả ngoài giờ |
| 5 | OPS_AM / OPS_PLAN | Duyệt/từ chối gia hạn, override trên mobile, bắt buộc lý do | Quyết định không trễ khi không ở văn phòng |
| 6 | OPS_PLAN | Xem dashboard compliance rút gọn theo tier×priority | Nắm SLA toàn phòng khi di chuyển |
| 7 | OPS_CONT/DES/EDIT/ADS | Tự chọn kênh nhận thông báo (in-app/email/Zalo/Telegram) | Nhận đúng kênh tiện nhất, không trùng lặp |
| 8 | OPS_AM | Duyệt khi mất mạng, app tự sync khi online | Công việc không chặn khi đi thị trường |

---

## 3. Quy Tắc Nghiệp Vụ

> *Quy tắc bắt buộc — developer phải xử lý đúng trong code. Nguồn: operations.md B.9 (BR-OPS-9.1/9.2/9.3) + DI-005 + lane brief.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | SLA áp động theo **ma trận tier × priority** (`sla-khach-hang.md` §2.1; A chậm nhất, E nhanh nhất; FR = First Response, Res = Resolution; tính giờ làm việc, 1 ngày LV = 8h; riêng Critical 24/7). HĐ cam kết cao hơn ma trận → ghi đè theo profile khách trên CORE; M-INT hiển thị target theo profile đã ghi đè. | Mobile không tự tính target — chỉ đọc từ CORE; hiển thị lệch là lỗi block. |
| BR-002 | **GMT+7 là mốc tính duy nhất**; giờ BC T2–T6 9:00–18:00 (nghỉ trưa 12:00–13:00) = 8h LV/ngày; T7, CN, lễ VN không tính; **Critical chạy 24/7 mọi ngày**. Mobile lấy mốc tính từ server, không dùng giờ máy local để quyết định trạng thái. | Push sai múi giờ/giờ LV làm sai compliance; trạng thái quyết theo timestamp server. |
| BR-003 | Ca trực Critical ngoài giờ: **on-call xoay vòng, SLA 4h ngoài giờ** (DI-005 đã chốt, thay desk 24/7). Push Critical ngoài giờ tới người đang trực theo lịch rota (cấu hình trên WEB/CORE, mobile chỉ nhận). | Push nhầm người hết ca → gửi song song fallback OPS_PLAN; rota sai là lỗi cấu hình. |
| BR-004 | **Pause tự động do CORE xử lý:** Pending (chờ khách) — nhắc Critical 4h/12h, mức khác 24h/48h LV; sau nhắc thứ 2 tiếp tục 24h (Critical)/24h LV (còn lại) không phản hồi → auto-Closed "khách không phản hồi" (không tính breach, reopen trong 7 ngày). Blocked-3rd-party: pause khi có case ID platform, tối đa 5 ngày LV, quá hạn escalate AM. | Mobile không tự pause/resume; Pause thiếu điều kiện → CORE từ chối kèm lý do. |
| BR-005 | **Pre-alert 80%:** cảnh báo vàng push assignee + AM; trong khung 80–100% assignee phải có hành động/cập nhật ghi nhận trên hệ thống. | Quá 100% không có cập nhật → breach ghi nhận "không có hành động phòng ngừa" (đầu vào post-mortem/KPI). |
| BR-006 | **Breach 100%:** trong **5 phút** push đỏ tới AM + CS TL (danh sách người nhận team do OPS_PLAN quản lý), đẩy dashboard OPS_PLAN và alert center BOD (REQ-BOD-006). AM **thông báo khách trong 30 phút** theo template chuẩn (lý do, phương án khắc phục, ETA mới), xác nhận kèm bằng chứng trên hệ thống. | Không thông báo đúng 30 phút là **vi phạm riêng, độc lập breach kỹ thuật**; mobile hiển thị đếm ngược + nút xác nhận, quá hạn ghi vi phạm riêng. |
| BR-007 | **Override theo cấp, bắt buộc lý do + audit log bất biến** (ai, khi nào, cũ/mới): gia hạn Resolution lần 1 ≤50% target *trước breach* — CS TL (1 lần/ticket, 15 phút trong giờ trực); override FR mọi mức + gia hạn lần 2 — OPS_PLAN (30 phút); miễn SLA theo đợt (platform outage toàn cục, force majeure) — BOD theo đề xuất OPS_PLAN (4h). Form duyệt trên mobile chặn nút gửi khi thiếu lý do. | Không duyệt vượt cấp — UI ẩn và API từ chối ở tầng service; thiếu lý do bị từ chối tại client lẫn server. |
| BR-008 | **Post-mortem tự trigger:** ≥3 breach/khách/30 ngày hoặc ≥2 breach cùng root cause/90 ngày → post-mortem trong 5 ngày LV (CS TL review, OPS_PLAN phê duyệt); breach Tier D/E ảnh hưởng doanh thu thêm buổi review với khách do AM chủ trì. Mobile chỉ nhận push kết quả/nhiệm vụ. | Mobile không tạo/sửa quyết định post-mortem; dữ liệu lệch thì CORE là nguồn sự thật. |
| BR-009 | **Notification đa kênh:** in-app, email, Zalo/Telegram tùy cấu hình (mặc định in-app); kênh ngoài gửi qua GW/webhook; mỗi sự kiện ghi trạng thái từng kênh (sent/failed). Kênh ngoài lỗi → fallback in-app + email, retry có giới hạn. | Cấm trùng lặp cùng 1 kênh cho 1 sự kiện (dedupe event_id + channel); app hiển thị kênh thất bại để kiểm tra cấu hình. |
| BR-010 | **Tenant isolation & phạm vi khách:** khách chỉ nhận thông báo qua Portal/mobile-portal, **chỉ event của tenant mình**; staff trên mobile chỉ thấy SLA theo phạm vi được gán (assignee: việc của mình; AM: portfolio; OPS_PLAN/BOD: toàn bộ). Đồng hồ song song giờ địa phương khách ở counterpart portal. | Truy vấn/hiển thị vượt tenant bị chặn ở tầng service (không chỉ ẩn UI); test bắt buộc có case truy cập chéo tenant. |
| BR-011 | **Offline-capable & chống trùng sync:** thao tác offline xếp hàng cục bộ, sync khi online theo thứ tự, gắn idempotency-key; server chống ghi trùng; **cấm tự duyệt task của mình** (approver ≠ creator — chặn cả offline queue lẫn API). | Sync trùng bị chặn bởi idempotency; hai người duyệt cùng yêu cầu → bản đến trước theo timestamp server hợp lệ, bản kia trả lỗi "đã được xử lý". |

---

## 4. Phân Quyền

> *Chỉ dùng 18 vai registry. Vai "CS TL"/"TL" trong business rules là người được **gán nhiệm vụ duyệt lần 1** — OPS_PLAN quản lý danh sách gán (không có vai registry riêng; xem Mục 5). CUSTOMER không dùng mobile nội bộ.*

| Hành động | OPS_CONT/DES/EDIT/ADS | OPS_AM | OPS_PLAN | BOD_CEO | SYS_ADMIN |
|-----------|----------------------|--------|----------|---------|-----------|
| Nhận push SLA của việc được gán | ✅ | ✅ | ✅ | ❌ | ❌ |
| Nhận push breach của portfolio/team | ❌ | ✅ | ✅ | ✅ (qua alert center) | ❌ |
| Cập nhật hành động 80–100% / phản hồi đầu tiên (của mình) | ✅ | ✅ | ✅ | ❌ | ❌ |
| Xem dashboard compliance rút gọn | Của mình | Portfolio mình | Tất cả | Tất cả | ❌ |
| Duyệt gia hạn Resolution lần 1 (≤50%, trước breach) | ❌ | Khi được gán vai duyệt | ✅ (gán/quản lý) | ❌ | ❌ |
| Override FR mọi mức / gia hạn lần 2 | ❌ | ❌ | ✅ | ❌ | ❌ |
| Miễn SLA theo đợt (outage, force majeure) | ❌ | ❌ | Đề xuất | Phê duyệt | ❌ |
| Xem audit log override | ❌ | Phạm vi mình | ✅ | ✅ | ✅ (kỹ thuật) |
| Cấu hình kênh nhận thông báo cá nhân | ✅ | ✅ | ✅ | ✅ | ✅ |
| Cấu hình kênh/template tenant, lịch on-call, danh sách nhận breach | ❌ | ❌ | ✅ | ❌ | ✅ (hạ tầng) |
| Xóa bản ghi thông báo/audit | ❌ | ❌ | ❌ | ❌ | ❌ (audit log bất biến) |

---

## 5. Trường Hợp Đặc Biệt

- **Mất mạng khi duyệt:** thao tác lưu hàng đợi offline nhãn "chờ đồng bộ"; khi sync, nếu yêu cầu đã được người khác xử lý thì app hiển thị "đã được xử lý", không ghi đè — một yêu cầu một quyết định.
- **Xung đột vai duyệt:** người được gán duyệt lần 1 là creator của ticket/task → chặn (approver ≠ creator), tự chuyển cho OPS_PLAN; chặn tầng API, không chỉ ẩn nút.
- **Kênh Zalo/Telegram lỗi:** fallback in-app + email, ghi delivery failed kèm lý do; sự kiện vẫn nằm trong inbox, app cảnh báo để cấp lại kết nối.
- **Nhận nhầm ca on-call:** rota đổi giữa chừng khiến push tới người hết ca → gửi fallback OPS_PLAN; rà rota là việc cấu hình trên WEB.
- **Breach ngoài giờ, mức không phải Critical:** clock dừng ở giờ LV nên breach chỉ nổ trong giờ LV; riêng Critical breach nửa đêm vẫn push on-call theo SLA 4h ngoài giờ.
- **Khách có lịch làm việc riêng:** khai báo lịch trên portal → clock High/Medium/Low theo lịch đó (Critical vẫn 24/7); mobile hiển thị cả mốc GMT+7 lẫn lịch riêng của khách.
- **Giả định chưa chốt (không tự quyết):** 11 khoản KXN còn mở (6, 7, 9, 15–22 — `documents/quy-trinh-lam-viec/10 §4`) thuộc phạm vi khác (Evaluation, RACI, nhóm LOST...) — đã rà soát, không khoản nào tác động trực tiếp tới feature này. Vai **"CS TL"** không có trong 18 vai registry — spec xử lý bằng cơ chế gán người duyệt do OPS_PLAN quản lý; mapping vào registry cần xác nhận khi cấu hình.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Entity quản lý trạng thái là **Đồng hồ SLA** — state machine chạy trên CORE; mobile chỉ hiển thị và gửi lại hành động.*

**Entity:** Đồng hồ SLA (SLA Monitor) gắn ticket/task/deliverable

**Sơ đồ trạng thái:**
```
[NORMAL] ──(đạt 80%)──► [PRE_ALERT] ──(đạt 100%)──► [BREACHED] ──(AM báo khách ≤30')──► [NOTIFIED] ──(xong)──► [RESOLVED]
   │                        │                          │
   │(Pending/Blocked)       │(gia hạn Res lần 1)        │(miễn theo đợt)
   ▼                        ▼                          ▼
[PAUSED] ─(resume)─►     [EXTENDED_L1] ─(override FR/lần 2)─► [EXTENDED_L2] ─(đạt 100%)─► [BREACHED]
                                                                  [BREACHED] ─(BOD miễn)─► [EXEMPTED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `NORMAL` | Đạt 80% target | `PRE_ALERT` | Hệ thống (CORE) | Push vàng tới assignee + AM |
| `NORMAL` / `PRE_ALERT` | Gia hạn Resolution lần 1 | `EXTENDED_L1` | CS TL (người được gán duyệt) | ≤50% target, trước breach, 1 lần/ticket, lý do + audit |
| `NORMAL` / `PRE_ALERT` / `EXTENDED_L1` | Override FR mọi mức hoặc gia hạn lần 2 | `EXTENDED_L2` | OPS_PLAN | 30 phút xử lý, lý do + audit |
| `NORMAL` / `PRE_ALERT` / `EXTENDED_*` | Pending hoặc Blocked-3rd-party | `PAUSED` | Hệ thống (CORE) | Blocked phải có case ID platform; tối đa 5 ngày LV |
| `PAUSED` | Khách phản hồi / gỡ block | `NORMAL` | Hệ thống (CORE) | Thời gian pause trừ khỏi elapsed |
| `PRE_ALERT` | Đạt 100% target | `BREACHED` | Hệ thống (CORE) | Push đỏ ≤5 phút tới AM + CS TL; đẩy alert center BOD |
| `BREACHED` | AM gửi thông báo khách theo template | `NOTIFIED` | OPS_AM | Trong 30 phút, có xác nhận + bằng chứng |
| `BREACHED` | Miễn SLA theo đợt | `EXEMPTED` | BOD_CEO | Đề xuất OPS_PLAN trong 4h; outage toàn cục / force majeure |
| `NOTIFIED` / `EXTENDED_*` | Xử lý xong (Res kèm mô tả giải pháp) | `RESOLVED` | Assignee / OPS_AM | Res timestamp là mốc đo chuẩn hóa |

**Quy tắc:**
- `RESOLVED` và `EXEMPTED` kết thúc chu kỳ; reopen (trong 7 ngày — REQ-OPS-009) tạo chu kỳ đo mới, breach cũ vẫn tính thống kê.
- `EXTENDED_L1`/`EXTENDED_L2` chỉ hợp lệ **trước breach**; đã `BREACHED` chỉ còn `NOTIFIED` hoặc `EXEMPTED`.
- Mọi chuyển đổi do CORE xác nhận; CORE từ chối (duyệt trùng) thì app rollback hiển thị.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Bản CORE là nguồn sự thật; mobile cache chỉ đọc. DDL tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `sla_policy` | `tenant_id`, `tier`, `priority`, `fr_target`, `res_target`, `override_flag` | FK → `tenants.id` | Ma trận tier×priority; HĐ ghi đè theo profile khách |
| `sla_clock` | `object_ref`, `started_at`, `elapsed_working_ms`, `state`, `paused_reason`, `case_id` | FK → `sla_policy.id` | State machine Mục 6; pause có case ID, ≤5 ngày LV |
| `sla_event` | `clock_id`, `type` (pre_alert/breach/override), `fired_at`, `delivered_channels` | FK → `sla_clock.id` | Nguồn event notification |
| `notification_event` | `event_id`, `audience_user_id`, `severity`, `title`, `payload`, `read_at` | FK → `sla_event.id` | Inbox in-app; dedupe theo event_id |
| `notification_channel_config` | `user_id`, `channel` (in_app/email/zalo/telegram), `enabled`, `endpoint` | FK → `users.id` | Cá nhân; tenant-level/template do OPS_PLAN/SYS_ADMIN |
| `notification_delivery` | `event_id`, `channel`, `status`, `error_reason` | FK → `notification_event.id` | Trạng thái từng kênh; fallback in-app + email |
| `sla_override_audit` | `clock_id`, `actor_id`, `level`, `reason`, `old_value`, `new_value`, `acted_at` | FK → `sla_clock.id` | **Bất biến** — append-only |
| `oncall_rota` | `shift_start`, `shift_end`, `user_id`, `scope` | FK → `users.id` | Ca trực on-call xoay vòng 4h ngoài giờ (DI-005) |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — test được. Điền chi tiết ở Phase 5; Phase 2 ghi phác thảo sơ bộ.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Pre-alert 80% push | Ticket đang chạy, clock `NORMAL` | Elapsed đạt 80% target | Assignee + AM nhận push vàng ≤5 phút, mở được ticket | [ ] |
| SC-002: Breach 100% + alert center | Clock đạt 100% | Breach xảy ra | Push đỏ AM + CS TL ≤5 phút; có trên dashboard OPS_PLAN và alert center BOD (REQ-BOD-006) | [ ] |
| SC-003: Đếm ngược 30 phút báo khách | Trạng thái `BREACHED` | AM mở breach trên mobile | Đếm ngược 30 phút + nút xác nhận "Đã gửi thông báo khách"; quá hạn ghi vi phạm riêng | [ ] |
| SC-004: Duyệt offline | Mất mạng, có yêu cầu gia hạn lần 1 | Duyệt kèm lý do khi offline | Xếp hàng cục bộ; sync đúng 1 lần (idempotency); audit log đủ lý do | [ ] |
| SC-005: Chặn tự duyệt/duyệt trùng | Người duyệt là creator; hoặc 2 thiết bị duyệt cùng yêu cầu | Gửi quyết định | Creator bị chặn tự duyệt; yêu cầu đã xử lý trả lỗi "đã được xử lý" | [ ] |
| SC-006: Critical ngoài giờ tới đúng on-call | Ngoài 18:00 GMT+7, sự cố Critical | Push phát sinh | Người trực rota nhận push; SLA 4h ngoài giờ; rota đổi thì OPS_PLAN nhận fallback | [ ] |
| SC-007: Tenant isolation | Khách A, B cùng dùng portal | Khách A xem thông báo | Chỉ thấy event tenant A; truy cập chéo bị chặn tầng service | [ ] |
| SC-008: Kênh Telegram lỗi | Cấu hình token sai | Pre-alert phát sinh | In-app + email thành công; delivery ghi failed kèm lý do; không retry vô hạn | [ ] |

> **Liên kết:** SC-001/002/003/006/008 → REQ-OPS-008 (Mục 2); SC-002 → REQ-BOD-006; SC-004/005 → đặc thù mobile offline; SC-007 → BR-010.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Chi tiết kĩ thuật nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/sys-mobile-internal/mod-sla-notif/[screen-group].md` |
| Ma trận SLA (chính sách nguồn) | `phase0-brainstorm/policies/sla-khach-hang.md` §2.1–2.3 |
| Alert center BOD | Bản REQ-BOD-006 — MOD-DATAHUB-BI |
