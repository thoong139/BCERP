# Tính Năng: Ticket & CSKH (Mobile Nội Bộ)

> **Dựa trên:** REQ-OPS-009 trong `phase1-business/departments/operations/operations.md` (Phần A)
> **Phân hệ:** Mobile Nội Bộ BCERP (SYS-MOBILE-INTERNAL)
> **Module:** Ticket & CSKH (MOD-TICKET-CSKH)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-internal/ticket-cskh/[screen-group].md`, `phase5-implementation/tasks/mobile-internal/ticket-cskh/feat-mbi-cskh-001-impl.md`

> **Ghi chú fan-out:** REQ-OPS-009 nằm ở 5 systems; đây là **bản riêng cho SYS-MOBILE-INTERNAL** (React Native offline-capable cho staff OPS). Queue hợp nhất, state machine, CSAT engine thuộc SYS-CORE-BACKEND; màn hình xử lý đầy đủ thuộc SYS-BCERP-WEB; khách tạo ticket/trả CSAT thuộc SYS-PORTAL-WEB/SYS-MOBILE-PORTAL.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-CSKH-001 |
| Module | MOD-TICKET-CSKH |
| Yêu cầu nghiệp vụ | REQ-OPS-009 |
| Người dùng liên quan | OPS_AM, OPS_PLAN, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; CUSTOMER chỉ gián tiếp qua portal/mobile-portal |
| Độ ưu tiên | Trung bình (MEDIUM theo req-registry) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | SLA & Notification Engine (REQ-OPS-008) + queue hợp nhất trên SYS-CORE-BACKEND; không có cross-dependency lane Phase 2 khác |
| Ghi chú Expert (A7) | A7 `operations.md` "Chờ đánh giá" — chưa có điều chỉnh được duyệt (REQ-OPS-009 thuộc call-2/2 chưa viết). Spec bám Phần A + Luồng 5 P1-02; rà lại khi A7 có kết quả |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa Ticket & CSKH lên mobile nội bộ để assignee OPS và AM nhận việc, phản hồi khách và xử lý escalation mọi lúc mọi nơi, kể cả khi mạng yếu. SLA tier từng ticket được theo dõi liên tục trên di động — push 80%, báo đỏ breach, escalation AM → AD → BOD — giúp BC giữ cam kết CSKH với 1.000+ khách đa quốc gia không phụ thuộc máy tính.

**Phạm vi:**
- Bao gồm: nhận push gán việc/pre-alert/breach/escalation; xem queue cá nhân và portfolio AM; xem chi tiết ticket (tier, SLA clock, lịch sử); phản hồi từ di động; chuyển Open/Pending/Resolved; soạn offline, sync tự động; AM/OPS_PLAN duyệt gia hạn/override SLA; push detractor + ghi nhận khắc phục; dashboard compliance; BOD nhận push khiếu nại nghiêm trọng.
- Không bao gồm: queue hợp nhất đa kênh (portal/email/Zalo), dedupe, state machine, CSAT engine — thuộc SYS-CORE-BACKEND; màn hình xử lý đầy đủ — thuộc SYS-BCERP-WEB; khách tạo ticket/theo dõi/trả CSAT — thuộc SYS-PORTAL-WEB/SYS-MOBILE-PORTAL; cấu hình ma trận SLA — thuộc REQ-OPS-008; cảnh báo số dư TKQC — thuộc lane ADACCOUNT-CC.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | Assignee (OPS_ADS/CONT/DES/EDIT) | Nhận push ticket gán cho mình kèm hạn First Response theo tier | Phản hồi đúng SLA khi di chuyển |
| 2 | Assignee | Thấy countdown SLA từng ticket theo giờ LV BC, pause khi Pending/Blocked-3rd-party | Biết ticket sắp chạm 80% để ưu tiên |
| 3 | Assignee | Soạn phản hồi offline, app tự gửi khi có mạng | Không trượt First Response vì mất kết nối |
| 4 | Assignee | Chuyển Pending kèm case ID bên thứ 3 trên di động | Clock pause tự động đúng REQ-OPS-008 |
| 5 | OPS_AM | Nhận push pre-alert 80% và báo đỏ breach 100% của portfolio | Báo khách trong 30 phút theo template, không dính vi phạm riêng |
| 6 | OPS_AM | Xem queue toàn bộ ticket portfolio lọc theo khách/tier/trạng thái | Điều phối assignee, báo khách không cần máy tính |
| 7 | OPS_AM | Nhận push detractor (CSAT ≤2) và xem nội dung CSAT | Liên hệ lại trong 48h LV, gắn khắc phục vào ticket gốc |
| 8 | OPS_PLAN | Điều phối khiếu nại nghiêm trọng, leo thang AM → AD → BOD | Khiếu nại Tier D/E, mất tiền, sai sót đối soát, đạo đức tới BOD trong 24h đủ hồ sơ |
| 9 | OPS_AM / OPS_PLAN | Duyệt gia hạn/override SLA trên mobile, bắt buộc nhập lý do | Không nghẽn phê duyệt khi người duyệt vắng desk |
| 10 | OPS_AM | Xem dashboard compliance FR/Res của portfolio | Nắm breach, MTTR, cảnh báo trượt SLA theo tuần |
| 11 | CUSTOMER (gián tiếp qua portal/mobile-portal) | Mở ticket, theo dõi trạng thái, trả CSAT trên kênh của khách | Tương tác của khách hiển thị tức thời trên app nội bộ |

---

## 3. Quy Tắc Nghiệp Vụ

> *Rule queue/state machine/CSAT engine enforce ở service layer SYS-CORE-BACKEND; mobile là thin client qua API, không tự tính SLA. Giả định chờ chốt, không tự quyết: `[KXN-15]` — hình thức gửi khảo sát khách (AM tay hay hệ thống) còn mở, CSAT ở đây theo hướng hệ thống; `[KXN-19]` — RACI chính thức chưa xác nhận, phân quyền dưới dùng 18 vai registry.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Mọi ticket trên mobile gắn **SLA tier** theo ma trận tier × priority (Tier E nhanh nhất — Tier A chậm nhất; Critical 24/7 theo ca on-call xoay vòng SLA 4h ngoài giờ đã chốt tại DI-005); cam kết HĐ cao hơn ma trận ghi đè theo profile khách. Mobile hiển thị countdown theo giờ LV BC (GMT+7), pause khi Pending/Blocked-3rd-party (có case ID, tối đa 5 ngày LV), cảnh báo vàng 80% / đỏ 100% | Không xác định được tier/clock (mất kết nối CORE) → app hiển thị "dữ liệu cũ" kèm timestamp, cấm chuyển trạng thái tới khi sync |
| BR-002 | **Escalation ticket/khiếu nại nghiêm trọng đi theo lộ trình bắt buộc AM → AD (Account Director — OPS_AM cấp Senior L4–L5) → BOD**, tự động theo ngưỡng SLA, mỗi chặng ghi timestamp + lý do + audit log; giữ song song các mốc override REQ-OPS-008 (CS TL gia hạn lần 1 ≤50% → OPS_PLAN lần 2 → BOD miễn theo đợt). Khiếu nại nghiêm trọng (Tier D/E, mất tiền, sai sót đối soát, đạo đức nhân viên) tới BOD trong 24h kèm hồ sơ, OPS_PLAN điều phối | Thiếu timestamp/lý do một chặng → chặn chuyển chặng kế, push nhắc chặng hiện tại; quá 24h chưa tới BOD → push cảnh báo đỏ OPS_PLAN + BOD_CEO |
| BR-003 | **CSAT phát tự động sau Closed** (thang 1–5 + câu mở), khách trả lời qua portal/mobile-portal, nhắc tối đa 1 lần sau 48h; detractor (≤2) được liên hệ lại trong 48h LV, hành động khắc phục gắn ticket gốc. Trên mobile: AM/assignee nhận push detractor, xem CSAT, ghi nhận khắc phục; khách không trả CSAT trên kênh nội bộ. Tier khách có CSAT trung bình <4,0 hai tháng liên tiếp bị đánh dấu trên mobile để review dịch vụ do OPS_PLAN tổ chức (Luồng 5, B5 P1-02) | Detractor quá 48h LV chưa có khắc phục gắn ticket gốc → escalation tự động lên OPS_AM, đánh dấu breach CSKH trên dashboard; CSAT không đủ mẫu → hiển thị "chưa đủ dữ liệu", không tự kết luận |
| BR-004 | Trigger escalation bắt buộc push mobile: (1) Critical quá First Response; (2) ticket chạm 100% SLA — báo đỏ AM + CS TL ≤5 phút, AM báo khách trong 30 phút theo template (không báo là vi phạm riêng); (3) reopen ≥2 lần; (4) Pending quá 3 ngày LV | Push lỗi do thiết bị → fallback in-app badge + email; AM không xác nhận đã báo khách trong 30 phút → ghi vi phạm riêng vào audit log |
| BR-005 | **Offline-capable:** soạn phản hồi, ghi chú, chuyển Open/Pending được phép khi offline — lưu local queue, sync theo thứ tự thời gian khi có mạng; xung đột last-write-wins kèm audit "xử lý offline"; hành động nhạy cảm (đóng ticket, override/gia hạn, leo thang BOD) bắt buộc online | Sync thất bại/conflict → item giữ trạng thái "chờ sync" hiển thị rõ, không tự xóa; hành động nhạy cảm khi offline bị chặn kèm giải thích |
| BR-006 | Mọi thao tác từ mobile do CORE service layer xác thực phiên, kiểm tra phân quyền theo 18 vai registry, ghi audit log bất biến (ai, khi nào, từ/sang trạng thái, thiết bị); không kiểm tra phân quyền ở client | Không đủ quyền → API từ chối với mã lỗi rõ ràng, mobile chỉ hiển thị thông báo, không có bypass cục bộ |
| BR-007 | Reopen trong **7 ngày** từ Closed giữ nguyên ngữ cảnh; quá 7 ngày hoặc từ ticket Closed, tạo ticket mới tham chiếu ticket gốc; mobile hiển thị chuỗi tham chiếu | Trả lời trên ticket Closed quá hạn → app gợi ý mở ticket mới tham chiếu, nội dung chuyển thành draft, không ghi vào ticket cũ |
| BR-008 | Phản hồi đầu tiên từ mobile được CORE ghi nhận là First Response chuẩn theo timestamp server (không phải thời điểm soạn offline); template nhanh đồng bộ thư viện WEB | Chưa sync tới hạn FR → vẫn tính breach theo thời điểm sync; app cảnh báo trước khi item chờ sync quá hạn |

---

## 4. Phân Quyền

> *Chỉ dùng 18 vai registry. CUSTOMER không truy cập app nội bộ — tương tác qua SYS-PORTAL-WEB/SYS-MOBILE-PORTAL. Sau DI-006 không tồn tại OPS_CX/FIN_COMPL; trách nhiệm điều phối trải nghiệm khách gán OPS_PLAN. RACI chờ `[KXN-19]`.*

| Hành động | OPS_PLAN | OPS_AM | Assignee (OPS_CONT/DES/EDIT/ADS) | BOD_CEO | SYS_ADMIN |
|-----------|----------|--------|----------------------------------|---------|-----------|
| Xem queue cá nhân + nhận push gán việc | ✅ | ✅ | ✅ | ❌ | ❌ |
| Xem queue toàn bộ portfolio | ✅ (toàn công ty) | ✅ | ❌ | ✅ (read-only) | ❌ |
| Gửi phản hồi / cập nhật ticket được gán | ✅ | ✅ | ✅ | ❌ | ❌ |
| Chuyển Open → Pending/Resolved | ❌ | ✅ | ✅ (ticket của mình) | ❌ | ❌ |
| Đóng ticket (Closed) | ✅ | ✅ | ❌ | ❌ | ❌ |
| Reopen trong 7 ngày | ✅ | ✅ | ✅ (ticket của mình) | ❌ | ❌ |
| Duyệt gia hạn / override SLA (kèm lý do) | ✅ (lần 2) | ✅ (lần 1 ≤50%) | ❌ | ✅ (miễn theo đợt) | ❌ |
| Leo thang khiếu nại AM → AD → BOD | ✅ (điều phối) | ✅ | ❌ (báo AM) | Nhận hồ sơ | ❌ |
| Xem CSAT/detractor + ghi nhận khắc phục gắn ticket gốc | ✅ | ✅ | ✅ (ticket của mình) | ✅ (tổng hợp) | ❌ |
| Xem dashboard compliance FR/Res | ✅ | ✅ | ❌ | ✅ | ❌ |
| Cấu hình SLA / template | ❌ | ❌ | ❌ | ❌ | ✅ (trên WEB, không trên mobile) |

---

## 5. Trường Hợp Đặc Biệt

- **Mất kết nối kéo dài (roaming, máy bay):** assignee vẫn soạn phản hồi, ghi chú offline; item chờ sync hiển thị badge và countdown "sắp quá hạn First Response" theo giờ server CORE.
- **Assignee nghỉ việc/ôn nghỉ:** ticket Open/Pending được reassign; mobile hiển thị hàng đợi "ticket không có assignee hợp lệ" cho TL/OPS_AM điều phối trong ngày; clock vẫn chạy. Offboarding thu hồi phiên mobile trong 24h theo REQ-HR-001.
- **Ticket trùng lặp đa kênh (portal + email + Zalo):** dedupe do CORE thực hiện; mobile hiển thị ticket gộp kèm nhãn nguồn, phản hồi đi đúng kênh gốc.
- **Khách phản đối số liệu chi tiêu (B7 Luồng 5):** ticket gắn nhãn đối soát; AM khởi tạo đối soát với FIN trên WEB; mobile hiển thị "Đang đối soát", không cho đóng tới khi FIN kết luận.
- **Khiếu nại đạo đức nhân viên:** nội dung hiển thị theo phạm vi cần biết (AM → AD → BOD), không broadcast cho assignee khác; hồ sơ leo thang mã hoá ở tầng API.
- **Khách khai báo lịch LV riêng trên portal:** mobile hiển thị đồng hồ theo lịch đó cho tier High/Medium/Low (REQ-OPS-008) song song giờ BC.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *State machine nguồn sự thật ở SYS-CORE-BACKEND; mobile chỉ gọi API và nhận kết quả. Mọi chuyển đổi ghi audit log bất biến ở CORE.*

**Entity:** Ticket (CSKH)

**Sơ đồ trạng thái:**
```
[NEW] ──(assign + phản hồi đầu tiên)──► [OPEN] ──(resolve)──► [RESOLVED] ──(chốt)──► [CLOSED]
                                        │                       │                      │
                                        │ (pending)             │ (reopen ≤7 ngày)     │ (reopen ≤7 ngày)
                                        ▼                       ▼                      ▼
                                    [PENDING] ──(phản hồi mới)──► [OPEN]          [REOPENED → OPEN]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `NEW` | Assign + phản hồi đầu tiên | `OPEN` | CORE (auto-assign) + Assignee | First Response ghi timestamp server; Critical nằm trong hạn FR theo tier |
| `OPEN` | Chuyển Pending | `PENDING` | Assignee (ticket của mình), OPS_AM | Bắt buộc lý do; Blocked-3rd-party phải có case ID (tối đa 5 ngày LV) |
| `PENDING` | Quay lại xử lý | `OPEN` | Assignee, OPS_AM | Có phản hồi mới từ khách/bên thứ 3; clock resume tự động |
| `OPEN` | Resolve | `RESOLVED` | Assignee (ticket của mình), OPS_AM | Bắt buộc mô tả giải pháp cho khách |
| `RESOLVED` | Close | `CLOSED` | OPS_AM, OPS_PLAN | Khách xác nhận hoặc hết thời gian chờ; đóng kích hoạt CSAT tự động (BR-003) |
| `RESOLVED` / `CLOSED` | Reopen | `OPEN` (giữ ngữ cảnh) | Assignee (ticket của mình), OPS_AM, OPS_PLAN | Trong 7 ngày từ Closed; reopen ≥2 lần kích hoạt escalation bắt buộc (BR-004) |
| Bất kỳ | Leo thang khiếu nại nghiêm trọng | `OPEN` + cờ escalated | OPS_AM, OPS_PLAN (điều phối) | Gắn hồ sơ; lộ trình AM → AD → BOD trong 24h, timestamp từng chặng (BR-002) |

**Quy tắc:**
- Không quay về trạng thái trước theo ý muốn (trừ reopen ≤7 ngày giữ ngữ cảnh); quá hạn tạo ticket mới tham chiếu (BR-007).
- `CLOSED` là trạng thái kết thúc — chỉ mở lại qua reopen trong hạn; KPI (FR/Res, MTTR, breach) tính từ log trạng thái ở CORE.
- Chuyển trạng thái khi offline chỉ áp dụng nhánh Open/Pending; Close và escalation bắt buộc online (BR-005).

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt để developer nắm nhanh — DDL đầy đủ tại `technical-specs/database-design.md` (SYS-CORE-BACKEND); mobile đọc/ghi qua API.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `ticket` | `code`, `tenant_id`, `channel`, `tier`, `priority`, `status`, `assignee_id`, `sla_due_at`, `escalation_level` | FK → `tenants.id`, `users.id` | State machine enforce ở CORE; mobile sync pull + push |
| `ticket_comment` | `ticket_id`, `author_id`, `body`, `channel_ref`, `is_first_response`, `created_offline`, `synced_at` | FK → `ticket.id` | Bản soạn offline đánh dấu `created_offline=true` + thời điểm sync |
| `sla_event` | `ticket_id`, `event_type` (pre80/breach/pause/resume), `occurred_at`, `notified_user_ids` | FK → `ticket.id` | Nguồn push pre-alert/breach; timestamp bất biến |
| `escalation_log` | `ticket_id`, `from_role`, `to_role`, `stage` (AM→AD→BOD), `reason`, `timestamp`, `actor_id` | FK → `ticket.id` | Bắt buộc lý do + timestamp từng chặng (BR-002) |
| `csat_response` | `ticket_id`, `score` (1–5), `comment`, `submitted_at`, `reminder_count` | FK → `ticket.id` | Khách gửi từ portal; mobile chỉ đọc + push detractor |
| `remediation_action` | `ticket_id`, `description`, `owner_id`, `due_at`, `status` | FK → `ticket.id` | Khắc phục detractor gắn ticket gốc (BR-003) |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết hoá ở Phase 5; dưới là phác thảo Phase 2.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Nhận push gán việc theo tier | Assignee đăng nhập mobile, có ticket mới tier High | CORE gán ticket | Push tới ≤1 phút, hiển thị hạn FR theo tier × priority | [ ] |
| SC-002: Phản hồi offline đúng FR | Assignee soạn offline trước hạn FR | Mạng trở lại, app sync | CORE ghi `is_first_response=true` theo thời điểm sync; sync trước hạn thì không breach | [ ] |
| SC-003: Báo đỏ breach | Ticket chạm 100% SLA | Hệ thống phát hiện breach | AM + CS TL nhận push đỏ ≤5 phút; app nhắc AM báo khách trong 30 phút, bỏ qua thì ghi vi phạm riêng | [ ] |
| SC-004: Leo thang khiếu nại nghiêm trọng | Khiếu nại khách Tier D/E được ghi nhận | OPS_PLAN điều phối | Hồ sơ AM → AD → BOD có timestamp từng chặng, tới BOD trong 24h | [ ] |
| SC-005: Detractor được liên hệ lại | Ticket Closed với CSAT ≤2 | Detractor ghi nhận | AM nhận push; khắc phục gắn ticket gốc trong 48h LV, quá hạn tự escalation OPS_AM | [ ] |
| SC-006: Reopen giữ ngữ cảnh | Ticket Closed 3 ngày | Khách reopen qua portal | Mobile hiển thị ticket mở lại đủ ngữ cảnh; là lần 2 thì kích hoạt escalation bắt buộc | [ ] |

> **Liên kết:** SC-001–SC-006 map REQ-OPS-009 (Mục 2) và REQ-OPS-008 (ngưỡng SLA 80%/100%).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` (SYS-CORE-BACKEND — nguồn sự thật; mobile đồng bộ qua API) |
| API Endpoints | `technical-specs/api-contract.md` (endpoint ticket/CSAT mobile nội bộ + cơ chế sync offline) |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (fan-out 5 systems REQ-OPS-009; push notification; gateway email/Zalo) |
| Màn hình UI | `phase4-ux/mobile-internal/ticket-cskh/[screen-group].md` |
