# Tính Năng: Ticket & CSKH (Core Backend — Queue Hợp Nhất, State Machine, CSAT Engine)

> **Dựa trên:** REQ-OPS-009 trong `phase1-business/departments/operations/operations.md` (Phần A3, B.9 — BR-OPS-9.4/9.5); phối hợp cơ chế SLA của REQ-OPS-008 (BR-OPS-9.1–9.3); workflow `phase1-business/P1-02-business-workflow.md` Luồng 5 (CSKH & SLA)
> **Phân hệ:** Vận hành & Marketing nội bộ — Ticket & Chăm sóc Khách hàng (SYS-CORE-BACKEND)
> **Module:** Ticket & CSKH (MOD-TICKET-CSKH)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/P1-02-business-workflow.md`, `policies/sla-khach-hang.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/ticket-cskh/[screen-group].md`, `phase5-implementation/tasks/core-backend/ticket-cskh/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID do lane fan-out của `/wf-define-features` cấp. REQ-OPS-009 fan-out ra 5 systems — bản này là bản riêng cho **SYS-CORE-BACKEND**; counterparts: SYS-BCERP-WEB (nơi assignee xử lý chính), SYS-MOBILE-INTERNAL (assignee nhận việc + phản hồi đầu tiên, push escalation), SYS-PORTAL-WEB (khách tạo ticket/theo dõi/trả CSAT), SYS-MOBILE-PORTAL (touchpoint rút gọn cho khách). Tra `req-registry.json` để xác nhận SYS/MOD.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-CSKH-001 |
| Module | MOD-TICKET-CSKH (SYS-CORE-BACKEND — BCERP Core Backend, headless API/domain service) |
| Yêu cầu nghiệp vụ | REQ-OPS-009 (Ticket & CSKH — MEDIUM · GĐ2 · `phase1-business/departments/operations/operations.md` A3/B.9); dùng cơ chế SLA tier × priority của REQ-OPS-008 (MOD-SLA-NOTIF) |
| Người dùng liên quan | OPS_AM (đầu mối khách, gán việc, xử lý detractor); OPS_PLAN (điều phối khiếu nại nghiêm trọng, review dịch vụ theo CSAT); OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS (assignee nhận việc, phản hồi, cập nhật); CUSTOMER (CLIENT_ADMIN/CLIENT_USER tạo ticket, theo dõi, trả CSAT qua portal/mobile-portal) |
| Độ ưu tiên | Trung bình (MEDIUM · Phase2 · GĐ2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | Feature SLA & Notification Engine của MOD-SLA-NOTIF trên cùng hệ thống (REQ-OPS-008 — ma trận tier×priority, SLA clock GMT+7, pre-alert/breach, escalation engine; FEAT-ID do lane sla-notif cấp); provisioning tài khoản portal (REQ-OPS-010 — FEAT-CORE-CPORT-002, điều kiện khách đăng nhập portal để tạo ticket); RBAC + audit log nền chung (REQ-BOD-007) |
| Ghi chú Expert (A7) | Expert review Phần A `operations.md` chưa thực hiện (A7 đang chờ review — chưa có điều chỉnh áp dụng cho REQ-OPS-009). Đã chốt theo DI-006: KHÔNG lập vai OPS_CX — trách nhiệm care/điều phối gán OPS_PLAN. Chuỗi escalation đầy đủ theo BR-OPS-9.4 (assignee → AM → CS TL → OPS_PLAN → BOD) với spine bắt buộc AM → AD → BOD (AD = Account Director, cấp cao trong track OPS_AM; CS TL/AD là chức danh thuộc vai registry OPS_AM, không phải vai riêng). Hình thức gửi Client Survey định kỳ ngoài CSAT ticket còn mở `[KXN-15]` — spec tham số hóa kênh, không hardcode; Ma trận RACI chi tiết chờ xác nhận `[KXN-19]` — dùng chuỗi BR-OPS-9.4 làm mặc định; danh sách đầy đủ cờ cảnh báo K6–K12 chờ chốt `[KXN-20]` — trigger escalation cấu hình theo danh mục |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Là nguồn sự thật phía core backend cho toàn bộ vòng đời Ticket & CSKH: hợp nhất mọi yêu cầu từ các kênh chính thức (portal/email/Zalo) về **một hàng đợi duy nhất theo khách/tier**, vận hành **state machine chuẩn** của ticket, treo **SLA tier × priority** lên từng ticket, chạy **escalation bắt buộc** theo chuỗi có timestamp, và vận hành **CSAT engine** sau xử lý. Core backend là nơi mọi business rule được enforce ở tầng service — không tin UI — với audit log bất biến và tenant isolation tuyệt đối; 4 counterparts (WEB, M-INT, PORTAL, M-PORTAL) chỉ là bề mặt thao tác tiêu thụ cùng domain service.

**Phạm vi:**
- Bao gồm: intake API đa kênh (portal từ khách; email/Zalo vào qua GW webhook với degraded mode `manual` khi connector lỗi); chống trùng lặp dedupe (khách + chủ đề + tài sản) và tự tách yêu cầu ngoài scope thành change request ngoài SLA vận hành; state machine `New → Open → Pending → Resolved → Closed` với reopen trong 7 ngày giữ toàn bộ ngữ cảnh, Closed tạo ticket mới tham chiếu; gắn tier khách × priority và đồng bộ sự kiện pause/resume với SLA engine (Pending và Blocked-3rd-party có case ID pause tự động, tối đa 5 ngày LV); 5 trigger escalation bắt buộc (Critical quá First Response, bất kỳ ticket chạm 100% SLA, reopen ≥2 lần, Pending quá 3 ngày LV, khiếu nại từ CLIENT_ADMIN khách Tier D/E) với chuỗi assignee → AM → CS TL → OPS_PLAN → BOD, mỗi chặng SLA xử lý 30 phút trong giờ trực, mỗi chặng ghi timestamp; khiếu nại nghiêm trọng (khách Tier D/E, mất tiền, sai sót đối soát, đạo đức nhân viên) leo thang BOD trong 24h kèm hồ sơ đầy đủ, OPS_PLAN điều phối; CSAT engine — khảo sát tự động thang 1–5 + 1 câu mở sau Closed, nhắc tối đa 1 lần sau 48h, detractor ≤2 sinh bắt buộc việc liên hệ lại trong 48h làm việc với hành động khắc phục gắn ticket gốc, CSAT tier <4,0 hai tháng liên tiếp tự sinh review dịch vụ do OPS_PLAN chủ trì; audit log append-only + hash-chain cho mọi chuyển trạng thái/escalation/CSAT; tenant isolation 2 lớp (RLS DB + filter `tenant_id` tầng API); event push cho counterparts (ticket mới gán, escalation, breach đỏ, khiếu nại BOD).
- Không bao gồm: màn hình xử lý của assignee (SYS-BCERP-WEB), push notification và thao tác ngoài giờ (SYS-MOBILE-INTERNAL — core chỉ phát sự kiện), UI khách web/mobile (SYS-PORTAL-WEB / SYS-MOBILE-PORTAL), bản thân SLA clock engine + pre-alert 80%/breach 100% + override gia hạn (thuộc MOD-SLA-NOTIF — REQ-OPS-008; ticket service chỉ tích hợp và nhận verdict), cấp/quản lý tài khoản portal (FEAT-CORE-CPORT-002), quy trình đối soát discrepancy khi khách phản đối số liệu (REQ-FIN-004 — ticket chỉ giữ liên kết), tổng hợp SLA breach vào trụ cột KPI nhân sự (REQ-HR-007 — chỉ cấp dữ liệu đầu vào).

---

## 2. Luồng Người Dùng (User Stories)

Mọi hành động đều gọi domain service của core backend qua API; WEB/M-INT/PORTAL/M-PORTAL không giữ business logic. Khách (CUSTOMER) thao tác trên portal counterparts — dưới đây mô tả phần service phía core backend phục vụ các touchpoint đó.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_AM | Mọi yêu cầu từ portal/email/Zalo của khách mình rơi về một queue hợp nhất theo tier, đã dedupe và gán tier×priority tự động | Không sót yêu cầu rải rác nhiều kênh, ưu tiên đúng khách tier cao |
| 2 | OPS_AM | Gán/chuyển assignee trên ticket và thấy SLA clock + escalation step hiện tại | Phân phối việc minh bạch, biết ticket nào sắp breach để can thiệp trước |
| 3 | OPS_CONT / OPS_DES / OPS_EDIT / OPS_ADS | Nhận việc từ queue, ghi phản hồi đầu tiên và cập nhật tiến độ ngay trên ticket (kể cả từ mobile nội bộ) | First Response được ghi timestamp chuẩn — auto-reply không tính — để không breach oan |
| 4 | OPS_CONT / OPS_DES / OPS_EDIT / OPS_ADS | Chuyển ticket sang Pending có lý do (chờ khách / chờ platform kèm case ID) | Đồng hồ SLA pause đúng quy tắc, thời gian chờ không tính vào breach của BC |
| 5 | OPS_PLAN | Khiếu nại nghiêm trọng tự leo thang BOD trong 24h kèm hồ sơ đầy đủ, mình điều phối xử lý | Khiếu nại không "chìm" trong queue thường, trách nhiệm điều phối rõ ràng |
| 6 | OPS_PLAN | Nhận review item tự sinh khi CSAT tier <4,0 hai tháng liên tiếp | Review dịch vụ theo bằng chứng đo lường, không theo cảm tính |
| 7 | CUSTOMER (CLIENT_USER) | Tạo ticket kèm file minh chứng trên portal của tenant mình, thấy trạng thái và đồng hồ SLA song song giờ địa phương | Minh bạch tiến độ xử lý, không phải hỏi AM qua nhiều vòng |
| 8 | CUSTOMER (CLIENT_USER) | Mở lại ticket trong 7 ngày với đủ ngữ cảnh cũ nếu chưa hài lòng | Không phải kể lại vấn đề từ đầu, tránh sinh ticket trùng |
| 9 | CUSTOMER (CLIENT_USER/ADMIN) | Trả khảo sát CSAT 1–5 + câu mở sau khi ticket đóng; được liên hệ lại trong 48h nếu chấm ≤2 | Tiếng nói khách có hành động theo sau, không thu thập cho có |
| 10 | BOD (nhận điều phối từ OPS_PLAN) | Khiếu nại nghiêm trọng đến với hồ sơ đầy đủ trong 24h, push vào alert center | Ra quyết định khủng hoảng đúng thời điểm với đủ dữ liệu |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Đặc thù touchpoint core backend: mọi rule enforce ở tầng service (không tin UI), audit log hash-chain bất biến, tenant isolation tuyệt đối; không tồn tại luồng đổi trạng thái/thêm escalation ngoài API của service này.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Queue hợp nhất đa kênh + dedupe:** mọi yêu cầu từ kênh chính thức (portal/email/Zalo) hợp nhất một queue theo khách/tier; dedupe theo bộ (khách + chủ đề + tài sản) trong cửa sổ cấu hình — ticket trùng gộp về ticket gốc, các kênh gửi vào ghi nhận như nguồn bổ sung; yêu cầu ngoài scope của hợp đồng tự tách thành change request ngoài SLA vận hành, không nằm trong compliance SLA ticket. Nguồn: BR-OPS-9.4; REQ-OPS-009 A3. | Trùng lặp không gộp → cảnh báo dedupe + log; mở change request thành ticket thường → chặn "NGOAI_SCOPE_TACH_CR" |
| BR-002 | **State machine chuẩn do service độc quyền điều khiển:** `New → Open → Pending → Resolved → Closed` theo bảng chuyển đổi Mục 6; mọi chuyển trạng thái chỉ qua API service với điều kiện đầu vào đầy đủ; reopen chỉ trong 7 ngày kể từ Closed và giữ toàn bộ ngữ cảnh (thread, file, timeline SLA); Closed không reopen trực tiếp — hệ thống bắt buộc tạo ticket mới có tham chiếu ticket gốc. Nguồn: BR-OPS-9.4, REQ-OPS-009 A3. | Gọi API đổi trạng thái sai bảng → từ chối "INVALID_TRANSITION" + audit log; reopen sau 7 ngày → từ chối, gợi ý tạo ticket mới tham chiếu |
| BR-003 | **SLA tier × priority áp động:** ticket kế thừa tier khách (A thấp nhất — E cao nhất) × priority (Critical/High/Medium/Low) từ profile; hợp đồng cam kết cao hơn ma trận thì ghi đè theo profile khách; mốc tính GMT+7, giờ làm việc BC T2–T6 9:00–18:00, riêng Critical chạy 24/7; ticket service phát sự kiện pause/resume cho SLA engine: Pending pause tự động (nhắc Critical 4h/12h, mức khác 24h/48h LV), Blocked-3rd-party pause khi có case ID platform tối đa 5 ngày LV — quá hạn tự escalate AM. Nguồn: BR-OPS-9.1/9.2 (REQ-OPS-008), REQ-OPS-009. | Priority không hợp lệ theo danh mục → từ chối "PRIORITY_KHONG_HOP_LE"; Blocked thiếu case ID → không pause, clock chạy tiếp có log |
| BR-004 | **Auto-Closed "khách không phản hồi":** sau nhắc thứ 2 mà khách tiếp tục im lặng 24h (Critical) / 24h LV (mức khác) → hệ thống tự Closed với lý do chuẩn "khách không phản hồi", không tính breach cho BC; ticket này được reopen trong 7 ngày. Nguồn: BR-OPS-9.2. | Auto-Closed thiếu đủ 2 nhắc có timestamp → chặn; đánh breach cho auto-Closed → sai trạng thái, sửa lại theo job đối chiếu |
| BR-005 | **Đo FR/Res chuẩn hóa:** FR = timestamp phản hồi đầu tiên **có nội dung xử lý** của nhân viên BC (auto-reply template không tính); Res = moment chuyển `Resolved` kèm mô tả giải pháp bắt buộc (không có mô tả → không chuyển được); sự cố phụ thuộc nền tảng tính "đạt" khi đã escalate + có case ID + chu kỳ cập nhật 8 giờ — thời gian chờ platform không tính breach của BC. Nguồn: BR-OPS-9.1. | Chuyển Resolved thiếu mô tả giải pháp → từ chối "THIEU_MO_TA_GIAI_PHAP"; auto-reply ghi thành FR → engine đối chiếu loại bỏ, log điều chỉnh |
| BR-006 | **5 trigger escalation bắt buộc + chuỗi chặng 30 phút:** (1) Critical quá First Response; (2) bất kỳ ticket chạm 100% SLA; (3) reopen ≥2 lần; (4) Pending quá 3 ngày LV; (5) khiếu nại từ CLIENT_ADMIN khách Tier D/E. Kích hoạt → chuỗi **assignee → AM → CS TL → OPS_PLAN → BOD**, mỗi chặng SLA xử lý 30 phút trong giờ trực, mỗi chặng ghi timestamp; spine cam kết tối thiểu **AM → AD → BOD** (AD = Account Director — cấp cao track OPS_AM; CS TL/AD là chức danh thuộc vai registry OPS_AM, không tạo vai mới). Nguồn: BR-OPS-9.4; Notes lane REQ-OPS-009. | Trigger đủ điều kiện mà chưa sinh escalation → job quét định kỳ tự sinh + cảnh báo OPS_PLAN; bỏ qua chặng → escalation không đóng được, chặng tiếp tự kích hoạt hết 30 phút |
| BR-007 | **Khiếu nại nghiêm trọng leo thang BOD 24h:** tiêu chí bắt buộc — khách Tier D/E, mất tiền, sai sót đối soát, đạo đức nhân viên; hệ thống gắn cờ "khiếu nại nghiêm trọng", leo thang **BOD trong 24h kèm hồ sơ đầy đủ** (thread, timeline, evidence), OPS_PLAN điều phối, push alert center cho BOD; ticket giữ liên kết song song với quy trình đối soát discrepancy (REQ-FIN-004) nếu có phản đối số liệu. Nguồn: BR-OPS-9.5; P1-02 Luồng 5 B6/B7. | Cờ thiếu tiêu chí → không leo thang BOD, chỉ theo BR-006 thường; quá 24h chưa đến BOD → escalate trực tiếp + alert BOD_CEO |
| BR-008 | **CSAT engine sau xử lý:** ticket Closed → tự sinh khảo sát CSAT thang 1–5 + 1 câu mở gửi kênh portal của khách; nhắc **tối đa 1 lần sau 48h** nếu chưa phản hồi; không phản hồi ghi trạng thái "không phản hồi" — không ép điểm, không sinh nhắc thêm; điểm CSAT gắn ticket gốc + tenant + tier. Nguồn: BR-OPS-9.5. | Nhắc lần 2 → chặn "CSAT_NHAC_TOI_DA_1_LAN"; sinh khảo sát cho ticket chưa Closed → từ chối |
| BR-009 | **Detractor ≤2 có hành động bắt buộc:** CSAT ≤2 → tự sinh task "liên hệ lại trong 48h làm việc" gắn ticket gốc cho AM; ghi nội dung liên hệ và **hành động khắc phục gắn ticket gốc** — task không có hành động khắc phục thì không đóng được; detractor là đầu vào review dịch vụ. Nguồn: BR-OPS-9.5. | Đóng task detractor thiếu nội dung liên hệ/hành động khắc phục → từ chối "THIEU_HANH_DONG_KHAC_PHUC" |
| BR-010 | **Review dịch vụ theo CSAT tier:** một tier có CSAT trung bình <4,0 hai tháng liên tiếp → tự sinh review item dịch vụ do OPS_PLAN chủ trì, kèm dữ liệu ticket/CSAT/detractor của tier đó. Nguồn: BR-OPS-9.5; P1-02 B5. | Review item không sinh khi đủ điều kiện → job kiểm tra hàng tháng tự sinh + escalate OPS_PLAN |
| BR-011 | **Tenant isolation + phân quyền API:** RLS DB + filter `tenant_id` tầng API 2 lớp; CUSTOMER chỉ tạo/xem/trả lời ticket của tenant mình; nhân sự nội bộ xem theo portfolio được phân (AM — khách phụ trách; OPS_PLAN — toàn bộ); hành động nhạy cảm phía khách (thêm user, xuất dữ liệu, đổi mật khẩu — thuộc portal chung) thêm một lớp OTP; ticket service không bao giờ trả chéo dữ liệu tenant. Nguồn: BR-OPS-5.2/portal; REQ-OPS-009; Notes lane. | Thiếu `tenant_id` → từ chối; truy vấn chéo tenant → chặn + audit log bảo mật, đưa vào breach detection |
| BR-012 | **Audit log bất biến + event push:** mọi chuyển trạng thái, escalation (mỗi chặng), cờ khiếu nại, CSAT, detractor action, auto-Closed ghi append-only + hash-chain (ai, khi nào, từ/sang, căn cứ); service phát sự kiện (ticket gán, escalation, breach đỏ, khiếu nại BOD) cho alert/notification để M-INT push và PORTAL hiển thị — counterparts không tự suy diễn trạng thái. Nguồn: BR-OPS-9.4/9.5; REQ-BOD-007 nền chung. | Thiếu reason code hành động nhạy cảm → không submit; đứt hash-chain → alert CTO + BOD_CEO |

---

## 4. Phân Quyền

| Hành động | OPS_AM | OPS_PLAN | OPS_CONT/DES/EDIT/ADS | CUSTOMER (CLIENT_ADMIN) | CUSTOMER (CLIENT_USER) | SYS_ADMIN | BOD_CEO |
|-----------|--------|----------|------------------------|--------------------------|------------------------|-----------|---------|
| Tạo ticket nội bộ (thay khách theo kênh email/Zalo) | ✅ | ✅ | ✅ | ✅ (portal, tenant mình) | ✅ (portal, tenant mình) | ❌ | ❌ |
| Gán/chuyển assignee | ✅ (khách phụ trách) | ✅ (điều phối toàn bộ) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Phản hồi/cập nhật ticket | ✅ | ✅ | ✅ (ticket được gán) | ✅ (comment ticket tenant mình) | ✅ (comment ticket tenant mình) | ❌ | ❌ |
| Chuyển Pending / trả Open | ✅ | ✅ | ✅ (ticket được gán) | ❌ (chỉ phản hồi — clock pause do service xử lý) | ❌ | ❌ | ❌ |
| Resolved (kèm mô tả giải pháp) / Closed | ✅ | ✅ | ✅ (ticket được gán) | ❌ | ❌ | ❌ | ❌ |
| Reopen ≤7 ngày | ✅ | ✅ | ✅ (ticket được gán) | ✅ (tenant mình) | ✅ (tenant mình) | ❌ | ❌ |
| Xem queue + SLA clock | ✅ (portfolio mình) | ✅ (toàn bộ) | ✅ (ticket liên quan) | ✅ (ticket tenant mình) | ✅ (ticket tenant mình) | ❌ (không xem nội dung nghiệp vụ) | ✅ (tổng hợp khiếu nại) |
| Trả CSAT | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Ghi nội dung liên hệ + hành động khắc phục detractor | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Gắn cờ khiếu nại nghiêm trọng / điều phối | ✅ (đề xuất cờ) | ✅ (chốt cờ + điều phối) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Nhận hồ sơ khiếu nại nghiêm trọng | ❌ | ✅ (điều phối) | ❌ | ❌ | ❌ | ❌ | ✅ |
| Xem dashboard CSAT/SLA theo tier | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Xóa/sửa audit log ticket | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (xem) / ❌ (xóa — không tồn tại mọi vai) | ❌ |

> Ghi chú touchpoint: toàn bộ quyền enforce bằng vai + điều kiện tenant tại tầng API core backend cho cả 5 counterparts; CS TL/AD là chức danh thuộc vai OPS_AM (map escalation step, không phải vai registry); SYS_ADMIN chỉ can thiệp kỹ thuật (vận hành hệ thống) và không thao tác nghiệp vụ ticket.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Cùng yêu cầu gửi từ nhiều kênh (portal + email + Zalo):** dedupe gộp về một ticket theo bộ (khách + chủ đề + tài sản); ticket gốc ghi danh sách nguồn kênh, phản hồi từ BC đồng bộ hiển thị trên mọi kênh tham chiếu — khách không nhận thấy phân mảnh.
- **Yêu cầu ngoài scope trộn trong ticket hỗ trợ:** OPS ghi nhận ngoài-scope → hệ thống tách change request riêng tham chiếu ticket, ticket gốc tiếp tục theo SLA vận hành phần trong scope; hai đối tượng không dùng chung đồng hồ SLA.
- **Khách im lặng sau 2 nhắc Pending:** auto-Closed "khách không phản hồi" không tính breach (BR-004); nếu khách quay lại trong 7 ngày, reopen giữ nguyên ngữ cảnh; sau 7 ngày, tạo ticket mới tham chiếu ticket cũ — thread cũ chỉ đọc.
- **Blocked-3rd-party quá 5 ngày LV:** pause hết hạn tự động, clock chạy tiếp và tự escalate AM; nếu platform vẫn chưa giải quyết, chuỗi escalation tiếp tục theo chặng 30 phút — BC không bị "treo" vô hạn vì lỗi bên thứ ba.
- **Detractor chấm sau khi ticket đã Closed:** không mở lại trạng thái ticket; vòng khắc phục chạy qua task gắn ticket gốc (BR-009) — state machine và vòng lắng nghe CSAT tách bạch để không phá tính toàn vẹn lịch sử.
- **CSAT không nhận được phản hồi:** chỉ nhắc đúng 1 lần sau 48h; ghi "không phản hồi" vào chỉ số phản hồi khảo sát, tier vẫn tính trung bình trên các ticket có điểm — tỷ lệ phản hồi hiển thị kèm để tránh đọc sai CSAT tier.
- **Khiếu nại nghiêm trọng trùng phản đối số liệu:** mở song song ticket khiếu nại (leo thang BOD 24h) và quy trình đối soát discrepancy (REQ-FIN-004) với liên kết hai chiều; portal hiển thị "Đang đối soát" cho phần số liệu, AM không tự chốt số trước khi FIN đối trừ.
- **Kênh email/Zalo degraded (GW không nhận webhook):** GW import tay có cấu trúc đúng schema và gắn nhãn `manual` + nguồn + timestamp (đồng bộ DI-007); queue vẫn hợp nhất bình thường — ticket từ nguồn manual không bị loại khỏi SLA compliance.
- **Assignee xử lý từ mobile nội bộ offline:** M-INT ghi sự kiện cục bộ rồi đồng bộ qua API idempotency-key; xung đột giải quyết server-side theo thứ tự timestamp có log — FR không bị tính trùng, không mất cập nhật.
- **Danh mục cờ cảnh báo chưa chốt:** các cờ escalation ngoài 5 trigger bắt buộc cấu hình theo danh mục cảnh báo `[KXN-20]` — service đọc cấu hình, không hardcode cờ mới vào code.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Ticket (hỗ trợ/CSKH).

**Sơ đồ trạng thái:**
```
[NEW] ──(assignee nhận)──► [OPEN] ──(resolve kèm mô tả giải pháp)──► [RESOLVED] ──(đóng)──► [CLOSED]
                           │  ▲                                       │                      │
                           │  └──(khách/bên 3 phản hồi)──┐            │                      │ (reopen ≤7 ngày — giữ ngữ cảnh)
                           │                             │            │ (khách xác nhận/     ▼
                           │ (chờ khách / chờ platform   │            │  AM đóng)      [REOPENED] ──► (về OPEN)
                           │  có case ID — clock pause)  │            ▼
                           ▼                             │        [CLOSED]
                       [PENDING] ────────────────────────┘
                           │
                           │ (auto: 2 nhắc + 24h/24h LV không phản hồi)
                           ▼
                       [CLOSED — "khách không phản hồi", không tính breach]

[CLOSED] ──(sau 7 ngày)──► KHÔNG reopen — bắt buộc tạo ticket MỚI tham chiếu ticket gốc
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `NEW` | Nhận việc | `OPEN` | Hệ thống (tự gán theo queue) hoặc OPS_AM/OPS_PLAN | Có assignee; FR clock bắt đầu chạy từ lúc tạo ticket |
| `OPEN` | Chuyển Pending | `PENDING` | Assignee được gán, OPS_AM, OPS_PLAN | Lý do bắt buộc: chờ khách (pause + nhắc theo BR-003/004) hoặc chờ platform kèm case ID (pause tối đa 5 ngày LV) |
| `PENDING` | Trả lại xử lý | `OPEN` | Assignee, OPS_AM, OPS_PLAN | Có phản hồi của khách hoặc cập nhật case từ platform |
| `PENDING` | Auto-Closed | `CLOSED` | Hệ thống | Đủ 2 nhắc có timestamp + 24h (Critical) / 24h LV (mức khác) không phản hồi; lý do "khách không phản hồi"; không tính breach; được reopen trong 7 ngày |
| `OPEN` | Resolve | `RESOLVED` | Assignee được gán, OPS_AM, OPS_PLAN | Mô tả giải pháp bắt buộc; Res timestamp ghi; cảnh báo breach (nếu có) xử lý theo MOD-SLA-NOTIF |
| `RESOLVED` | Đóng | `CLOSED` | Assignee, OPS_AM, OPS_PLAN (khách xác nhận qua portal khi có phản hồi) | Sinh khảo sát CSAT (BR-008); thời điểm đóng ghi vào timeline |
| `CLOSED` | Reopen | `REOPENED` | CUSTOMER (tenant mình), OPS_AM, OPS_PLAN, assignee | Trong 7 ngày kể từ Closed; giữ toàn bộ ngữ cảnh; reopen là lần N thì ghi đếm — đạt ≥2 lần kích hoạt escalation (BR-006) |
| `CLOSED` (quá 7 ngày) | Tạo ticket mới | `NEW` (ticket mới) | Mọi vai được tạo ticket | Ticket mới bắt buộc tham chiếu ticket gốc; ticket gốc chỉ đọc vĩnh viễn |

**Quy tắc:**
- Chỉ domain service được chuyển trạng thái — UI/counterpart chỉ gửi hành động qua API; mọi chuyển đổi ghi audit log bất biến với timestamp + người hành động + căn cứ.
- `CLOSED` không bao giờ mở trực tiếp sau 7 ngày; không tồn tại đường lùi từ `RESOLVED`/`CLOSED` về `OPEN` ngoài luồng reopen có điều kiện.
- Escalation không làm đổi trạng thái ticket — escalation là lớp xử lý song song gắn ticket (entity riêng) để clock và state machine không bị lệch.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `Ticket` | `code`, `tenant_id`, `customer_contact_id`, `tier`, `priority`, `subject`, `state` (`NEW/OPEN/PENDING/RESOLVED/CLOSED/REOPENED`), `assignee_id`, `channel_sources[]`, `parent_ticket_id`, `is_critical_complaint`, `opened_at`, `closed_at` | FK → `tenants`, `users` (assignee), `customer_contacts` | State machine BR-002; dedupe qua `parent_ticket_id` + bộ (khách + chủ đề + tài sản); soft delete — thực chất không xóa |
| `TicketMessage` | `ticket_id`, `author_type` (`BC_STAFF/CUSTOMER/SYSTEM`), `channel`, `body`, `attachments[]`, `is_first_response`, `created_at` | FK → `tickets` | FR tính từ message đầu tiên có nội dung xử lý của BC (auto-reply loại trừ — BR-005) |
| `PendingRecord` | `ticket_id`, `reason` (`WAIT_CUSTOMER/WAIT_3RD_PARTY`), `platform_case_id`, `paused_at`, `resumed_at`, `reminders[]` | FK → `tickets` | Nguồn sự kiện pause/resume cho SLA engine (BR-003/004); Blocked không case ID không pause |
| `EscalationRecord` | `ticket_id`, `trigger` (`CRIT_FR_OVER/SLA_100/REOPEN_2/PENDING_3D/TIERDE_ADMIN`), `current_step` (`ASSIGNEE/AM/CS_TL/OPS_PLAN/BOD`), `step_history[]` (step, actor, timestamp), `status` | FK → `tickets` | Mỗi chặng SLA 30 phút giờ trực (BR-006); timestamp bắt buộc từng chặng |
| `CriticalComplaintFile` | `ticket_id`, `criteria[]` (`TIER_DE/MONEY_LOSS/RECON_ERROR/ETHICS`), `dossier_ref`, `bod_notified_at`, `coordinator_id` (OPS_PLAN) | FK → `tickets`, `users` | Leo thang BOD 24h kèm hồ sơ (BR-007); liên kết 2 chiều quy trình đối soát REQ-FIN-004 |
| `CsatSurvey` | `ticket_id`, `tenant_id`, `score` (1–5), `open_comment`, `reminders_sent` (tối đa 1), `no_response`, `submitted_at` | FK → `tickets`, `tenants` | Tự sinh sau Closed; nhắc 1 lần sau 48h (BR-008); gắn tier để tổng hợp review (BR-010) |
| `DetractorFollowUp` | `survey_id`, `ticket_id`, `owner_id` (OPS_AM), `contact_note`, `remediation_action`, `due_at` (48h LV), `closed_at` | FK → `csat_surveys`, `tickets`, `users` | Score ≤2 tự sinh; không đóng khi thiếu contact_note/remediation (BR-009) |
| `TicketAuditLog` | `actor_id`, `role`, `action`, `entity`, `tenant_id`, `old_value`, `new_value`, `reason_code`, `prev_hash` | FK → đối tượng log | Append-only + hash-chain; không interface xóa/sửa mọi vai (BR-012) |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ ở Phase 2 — chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-OPS-009 (`operations.md` A3/B.9 — BR-OPS-9.4/9.5).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Queue hợp nhất + dedupe (REQ-OPS-009) | Khách đã gửi ticket "campaign Meta bị từ chối" qua portal | Cùng nội dung vào tiếp qua email và Zalo | Hệ thống gộp về 1 ticket, ghi 3 nguồn kênh; phản hồi BC hiển thị đồng bộ trên cả 3 kênh tham chiếu | [ ] |
| SC-002: Ngoài scope tự tách CR (REQ-OPS-009) | Ticket hỗ trợ trong scope | Khách yêu cầu thêm tính năng ngoài hợp đồng trong thread | Hệ thống tách change request riêng tham chiếu ticket; ticket gốc vẫn chạy SLA vận hành; CR không tính compliance SLA ticket | [ ] |
| SC-003: Reopen 7 ngày giữ ngữ cảnh (REQ-OPS-009) | Ticket `CLOSED` ngày 3 trước | Khách reopen trên portal | Ticket chuyển `REOPENED` đủ thread/file/timeline cũ; đếm reopen tăng; đạt lần 2 → tự sinh escalation theo BR-006 | [ ] |
| SC-004: Closed quá 7 ngày (REQ-OPS-009) | Ticket `CLOSED` 10 ngày | Khách bấm reopen | Từ chối reopen trực tiếp; bắt buộc tạo ticket mới có tham chiếu ticket gốc; ticket gốc chỉ đọc | [ ] |
| SC-005: Auto-Closed khách không phản hồi (BR-OPS-9.2) | Ticket `PENDING` chờ khách, đã nhắc 2 lần | Hết 24h (Critical) / 24h LV (mức khác) | Tự `CLOSED` lý do "khách không phản hồi", không tính breach; vẫn reopen được trong 7 ngày | [ ] |
| SC-006: 5 trigger escalation (BR-OPS-9.4) | Bộ ticket tương ứng từng trigger | Kích hoạt từng điều kiện | Mỗi case sinh `EscalationRecord` đúng trigger; chuỗi assignee → AM → CS TL → OPS_PLAN → BOD chạy chặng 30 phút có timestamp đầy đủ | [ ] |
| SC-007: Khiếu nại nghiêm trọng BOD 24h (BR-OPS-9.5) | CLIENT_ADMIN khách Tier D/E mở khiếu nại mất tiền | Ticket tạo với cờ khiếu nại nghiêm trọng | Trong 24h hồ sơ đầy đủ đến BOD (alert center); OPS_PLAN điều phối; liên kết quy trình đối soát khi có phản đối số liệu | [ ] |
| SC-008: CSAT + nhắc đúng 1 lần (BR-OPS-9.5) | Ticket vừa `CLOSED` | Khách không trả khảo sát | Gửi 1 lần; sau 48h nhắc đúng 1 lần nữa; hết nhắc ghi "không phản hồi", không sinh thêm khảo sát | [ ] |
| SC-009: Detractor 48h có hành động (BR-OPS-9.5) | CSAT ≤2 vừa submit | AM xử lý detractor | Tự sinh task due 48h LV gắn ticket gốc; đóng task bị chặn khi thiếu nội dung liên hệ/hành động khắc phục | [ ] |
| SC-010: Tenant isolation chéo (BR-011) | CLIENT_USER tenant A | Gọi API đọc/cập nhật ticket `tenant_id` tenant B | Từ chối + audit log bảo mật; không có bất kỳ response nào lộ dữ liệu tenant B | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` (intake API đa kênh + GW webhook email/Zalo; state machine API; escalation API; CSAT API; RBAC + tenant isolation + idempotency-key enforce tầng service) |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (sự kiện pause/resume ↔ SLA engine MOD-SLA-NOTIF; event push → M-INT/alert center; webhook Zalo/email qua GW với degraded `manual`; liên kết đối soát REQ-FIN-004; dữ liệu breach → KPI REQ-HR-007) |
| Màn hình UI (WEB — assignee xử lý chính; PORTAL/M-PORTAL — khách tạo ticket/trả CSAT) | `phase4-ux/bcerp-web/ticket-cskh/[screen-group].md`, `phase4-ux/portal-web/ticket-cskh/[screen-group].md`, `phase4-ux/mobile-portal/ticket-cskh/[screen-group].md`, `phase4-ux/mobile-internal/ticket-cskh/[screen-group].md` |
| Policy nghiệp vụ | `policies/sla-khach-hang.md` §2.1 (ma trận tier×priority — REQ-OPS-008); `policies/client-portal-minh-bach-bao-mat.md` (OTP hành động nhạy cảm, tenant isolation) |
| Feature liên quan cùng hệ thống | `../client-portal/client-portal-goc-nhin-ops-cap-tai-khoan-va-monitor.md` (FEAT-CORE-CPORT-002 — khách đăng nhập portal để tạo ticket; monitor ticket góc AM); `../client-portal/du-lieu-vi-read-only-cho-client-portal.md` (FEAT-CORE-CPORT-001 — hiển thị "Đang đối soát"); feature SLA & Notification Engine của `../sla-notif/` (REQ-OPS-008 — lane song song); `../datahub-bi/alert-center-va-canh-bao-rui-ro-van-hanh.md` (alert khiếu nại/breach) |
| Workflow tổng | `phase1-business/P1-02-business-workflow.md` (Luồng 5 — CSKH & SLA: B1–B8; SLA cam kết khách §Bảng 11; KPI #6 CSAT + tỷ lệ detractor) |
