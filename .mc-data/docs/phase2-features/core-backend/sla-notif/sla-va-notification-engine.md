# Tính Năng: SLA & Notification Engine (Core Backend)

> **Dựa trên:** REQ-OPS-008 trong `phase1-business/departments/operations/operations.md` (Phần A — Mục REQ-OPS-008; Phần B — Mục B.9, BR-OPS-9.1/9.2/9.3)
> **Phân hệ:** Vận hành (OPS) — SLA & Thông báo (SYS-CORE-BACKEND)
> **Module:** SLA & Notification Engine (MOD-SLA-NOTIF)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/P1-02-business-workflow.md`, `work/wf-analyze-requirements/deferred-issues.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/sys-core-backend/mod-sla-notif/[screen-group].md`, `phase5-implementation/tasks/sys-core-backend/mod-sla-notif/feat-core-slanot-001-impl.md`

> **Ghi chú fan-out:** REQ-OPS-008 nằm ở 5 systems; đây là **bản riêng cho SYS-CORE-BACKEND** — headless API/domain service. Counterparts: SYS-BCERP-WEB (dashboard compliance, template báo khách), SYS-MOBILE-INTERNAL (push pre-alert/breach, duyệt gia hạn), SYS-PORTAL-WEB / SYS-MOBILE-PORTAL (đồng hồ SLA khách). Mọi business rule được **enforce ở tầng service** (không tin UI), kèm **audit log bất biến** và **tenant isolation**.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-SLANOT-001 |
| Module | MOD-SLA-NOTIF |
| Yêu cầu nghiệp vụ | REQ-OPS-008 (liên thông REQ-BOD-006 — alert center BOD) |
| Người dùng liên quan | OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; CUSTOMER (Portal/M-PORTAL); BOD_CEO, BOD_CFO_CTO (nhận alert REQ-BOD-006); SYS_ADMIN (cấu hình kênh) |
| Độ ưu tiên | Cao (HIGH) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | Tier khách A–E + profile hợp đồng (REQ-OPS-004, mô hình 5 tier chốt V6.0 — DI-002/DI-008 closed); queue ticket/task phát sinh sự kiện đo thuộc REQ-OPS-009 (cùng module); alert center BOD thuộc REQ-BOD-006 — engine chỉ đẩy alert |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng là "trái tim đo giờ" của BCERP trên core backend: tự động áp ma trận SLA **tier × priority** (nguồn `sla-khach-hang.md` §2.1) lên mọi ticket/task/yêu cầu dịch vụ, chạy SLA clock theo mốc **GMT+7** với logic giờ làm việc/pause/escalation, và fan-out thông báo đa kênh (in-app, email, Zalo/Telegram tùy cấu hình) đến đúng người, đúng lúc, đúng tenant. Mục tiêu là bảo vệ cam kết dịch vụ với 1.000+ khách đa quốc gia mà không phụ thuộc việc nhân viên nhớ hạn — mọi cảnh báo và override đều do service layer thực thi, có audit log.

**Phạm vi:**
- **Bao gồm:** (1) SLA policy engine — ma trận tier×priority, ghi đè theo profile khách khi hợp đồng cam kết cao hơn; (2) SLA clock engine — mốc GMT+7 duy nhất, giờ làm việc BC T2–T6 9:00–18:00 (nghỉ trưa 12:00–13:00, 8h LV/ngày), T7/CN/lễ VN không tính, Critical 24/7; pause/resume tự động; (3) pre-alert 80% và breach 100% (phát cảnh báo ≤5 phút); (4) escalation tự động, override có lý do + audit log bất biến; (5) notification service đa kênh, chống ngập, tracking delivery; (6) API cấp dữ liệu đồng hồ/compliance cho 4 counterparts; (7) rota trực Critical on-call ngoài giờ, SLA phản hồi 4h (DI-005 đã chốt).
- **Không bao gồm:** dashboard compliance và template báo khách (SYS-BCERP-WEB); push native + duyệt gia hạn trên mobile (SYS-MOBILE-INTERNAL); đồng hồ song song giờ địa phương khách (SYS-PORTAL-WEB / SYS-MOBILE-PORTAL); queue hợp nhất, state machine ticket, CSAT engine, webhook email/Zalo inbound (REQ-OPS-009); alert center UI của BOD (REQ-BOD-006).

---

## 2. Luồng Người Dùng (User Stories)

> Touchpoint là core backend (headless API/domain service); trải nghiệm UI thuộc counterparts, phần tính toán/chặn/cảnh báo thuộc engine trong file này.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_AM | Hệ thống tự áp SLA target (FR/Res) theo tier × priority, không tra ma trận tay | Cam kết hợp đồng thực thi nhất quán |
| 2 | OPS_AM | Nhận cảnh báo vàng 80% và báo đỏ breach ≤5 phút kèm template báo khách | Kịp hành động trước breach, báo khách trong 30 phút |
| 3 | OPS_ADS / OPS_CONT / OPS_DES / OPS_EDIT | Nhận việc gán kèm mốc SLA của mình qua API push (WEB/M-INT) | First Response có nội dung xử lý đúng target tier |
| 4 | OPS_PLAN | Ghi đè SLA target theo profile hợp đồng; duyệt gia hạn/override bắt buộc lý do | Cam kết HĐ áp dụng tự động, override có kiểm soát + audit log |
| 5 | BOD_CEO / BOD_CFO_CTO | Nhận breach đỏ, khiếu nại leo thang vào alert center (REQ-BOD-006) | Nắm rủi ro realtime, không ngập alert thường |
| 6 | CUSTOMER | Xem đồng hồ SLA, nhận thông báo **chỉ sự kiện tenant mình** qua Portal/M-PORTAL; khai báo lịch làm việc riêng | Minh bạch tiến độ; SLA High/Medium/Low tính theo lịch khách, dữ liệu không lẫn tenant |
| 7 | SYS_ADMIN | Cấu hình kênh thông báo (in-app, email, Zalo/Telegram) và lịch lễ VN | Delivery chạy đúng cấu hình, không cần deploy lại |
| 8 | OPS_PLAN | Truy xuất API compliance FR/Res theo tier×priority theo khách/kỳ | Quản trị SLA toàn phòng, cung cấp dữ liệu KPI (REQ-HR-007) |
| 9 | OPS_AM | Ngoài giờ có sự cố Critical — được phân bổ rota on-call cam kết phản hồi 4h | Sự cố 24/7 luôn có người chịu trách nhiệm |

---

## 3. Quy Tắc Nghiệp Vụ

> *Quy tắc bắt buộc — developer phải xử lý đúng trong code; enforce ở tầng service, audit log bất biến, tenant isolation.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Áp động **ma trận tier × priority** theo profile tenant (chi tiết ở bảng dưới; quy ước nghịch trực giác A = chậm nhất, E = nhanh nhất). FR = First Response **có nội dung xử lý** của nhân viên BC (auto-reply không tính); Res = chuyển Resolved kèm mô tả giải pháp; 1 ngày LV = 8 giờ. Hợp đồng cam kết cao hơn ma trận → ghi đè theo profile khách | Tenant thiếu profile hợp lệ → 422, không default ẩn; cấu hình sai (target âm, thiếu priority) → chặn lưu ở service layer |
| BR-002 | SLA clock: **GMT+7 là mốc tính duy nhất**; giờ làm việc BC T2–T6 9:00–18:00 (nghỉ trưa 12:00–13:00); T7, CN, lễ VN không tính; **Critical chạy 24/7 mọi ngày**. Ngoài giờ, Critical on-call xoay vòng, **SLA phản hồi 4h** (DI-005 đã chốt) | Clock cấm tự tính theo timezone server/user gọi API — vi phạm cho kết quả đo sai toàn hệ thống |
| BR-003 | **Pause tự động:** Pending (chờ khách) tạm dừng clock — nhắc Critical sau 4h/12h, mức khác 24h/48h LV; sau nhắc thứ 2 tiếp tục 24h (Critical) / 24h LV (còn lại) không phản hồi → auto-Closed "khách không phản hồi" (không tính breach), reopen trong 7 ngày. Blocked-3rd-party: pause khi có case ID platform, tối đa 5 ngày LV, quá hạn tự escalate AM | Pause thiếu lý do hoặc Blocked không có case ID → từ chối, clock chạy tiếp; quá 5 ngày LV → tự sinh escalate |
| BR-004 | Khách khai báo lịch làm việc riêng trên portal → clock **High/Medium/Low** tính theo lịch đó (Critical vẫn 24/7); lịch lưu trong profile tenant | Lịch không hợp lệ (mốc giờ ngược, che phủ toàn tuần) → từ chối lưu, giữ lịch mặc định BC |
| BR-005 | **Pre-alert 80%** thời lượng: cảnh báo vàng cho assignee + AM; trong cửa sổ 80–100% assignee phải có hành động/cập nhật ghi nhận trên đối tượng đo | Không có hành động nào trong 80–100% → tự sinh escalation lên AM tại mốc 100% |
| BR-006 | **Breach 100%:** trong **≤5 phút** đẩy báo đỏ cho AM + OPS_PLAN; **AM thông báo khách trong 30 phút** theo template chuẩn (lý do, phương án khắc phục, ETA mới) — không báo khách là **vi phạm riêng, độc lập** breach kỹ thuật | Quá 30 phút chưa xác nhận "đã báo khách" → alert vi phạm riêng lên OPS_PLAN, đếm vào compliance cá nhân |
| BR-007 | **Override bắt buộc lý do + audit log bất biến** (ai, khi nào, giá trị cũ/mới): gia hạn Resolution lần 1 ≤50% trước breach — OPS_PLAN (đại diện cấp CS TL theo DI-006, 1 lần/đối tượng đo, 15 phút giờ trực); override FR mọi mức + gia hạn lần 2 — OPS_PLAN (30 phút); miễn SLA theo đợt (platform outage, force majeure) — **BOD** theo đề xuất OPS_PLAN (4h) | Thiếu lý do → không lưu; sai thẩm quyền → 403; sửa/xóa override → chặn cứng (append-only) |
| BR-008 | **Escalation tự động** theo chuỗi assignee → AM → OPS_PLAN → BOD, mỗi chặng 30 phút trong giờ trực; trigger bắt buộc: Critical quá First Response, bất kỳ đối tượng đo chạm 100% | Bỏ chặng → engine tự đẩy lại chặng kế và log sự kiện bỏ nhịp |
| BR-009 | **Post-mortem bắt buộc** khi ≥3 breach/khách/30 ngày **hoặc** ≥2 breach cùng root cause/90 ngày — hoàn thành trong 5 ngày LV (OPS_PLAN phê duyệt); Tier D/E breach ảnh hưởng doanh thu → thêm buổi review với khách do AM chủ trì | Chạm ngưỡng chưa có post-mortem → giữ trạng thái "chưa tuân thủ" đến khi hoàn tất |
| BR-010 | **Notification đa kênh** (in-app, email, Zalo/Telegram tùy cấu hình user/tenant), phân mức nghiêm trọng; delivery có idempotency key, retry backoff, chống ngập (gộp alert cùng nguồn, dedupe theo sự kiện + tenant); lưu trạng thái từng bản ghi delivery | Kênh fail (token hết hạn) → fallback in-app/email, gắn cờ kênh lỗi báo SYS_ADMIN, không mất thông báo cốt lõi |
| BR-011 | **Liên thông alert center BOD (REQ-BOD-006):** breach đỏ, khiếu nại leo thang, miễn SLA theo đợt được đẩy qua contract sự kiện chuẩn; alert chỉ tắt bằng acknowledge + reason phía alert center | Engine không tự đóng alert phía BOD; delivery fail → retry + log, cảnh báo đứt chuỗi |
| BR-012 | **CUSTOMER chỉ nhận thông báo sự kiện tenant mình** qua Portal/M-PORTAL — mọi API đọc bắt buộc lọc theo `tenant_id` của token, kể cả khi truyền tay tham số | `tenant_id` khác token → 403 + audit; là kiểm thử bắt buộc của tenant isolation |
| BR-013 | Đo chuẩn hóa: sự cố phụ thuộc nền tảng tính "đạt" khi đã escalate + có case ID + chu kỳ cập nhật 8 giờ — thời gian chờ platform **không tính vào breach của BC**; pause/resume ghi timestamp đầy đủ để tái lập timeline | Timeline không tái lập được (thiếu pause log) → chặn báo cáo compliance |
| BR-014 | Rota **trực Critical 24/7 follow-the-sun** theo múi giờ khách đa quốc gia: ca chính + ca phụ cấu hình theo tuần; ngoài giờ, Critical mới phân cho on-call hiện hành, SLA phản hồi 4h; nhận ca ghi nhận qua API | Rota trống → đẩy Critical thẳng AM + OPS_PLAN kèm alert đỏ REQ-BOD-006, SYS_ADMIN bù rota trong 24h |

**Ma trận tier × priority đầy đủ (BR-OPS-9.1, `sla-khach-hang.md` §2.1 — FR/Res; giờ làm việc, riêng Critical 24/7):**

| Tier | Critical (FR/Res) | High (FR/Res) | Medium (FR/Res) | Low (FR/Res) |
|---|---|---|---|---|
| E | 15 phút / 4 giờ | 30 phút / 8 giờ | 2 giờ / 1 ngày LV | 4 giờ / 2 ngày LV |
| D | 30 phút / 6 giờ | 1 giờ / 12 giờ | 3 giờ / 1,5 ngày LV | 8 giờ / 3 ngày LV |
| C | 1 giờ / 8 giờ | 2 giờ / 1 ngày LV | 4 giờ / 2 ngày LV | 8 giờ / 4 ngày LV |
| B | 2 giờ / 12 giờ | 4 giờ / 1,5 ngày LV | 8 giờ / 3 ngày LV | 1 ngày LV / 5 ngày LV |
| A | 4 giờ / 1 ngày LV | 8 giờ / 2 ngày LV | 1 ngày LV / 4 ngày LV | 2 ngày LV / 7 ngày LV |

---

## 4. Phân Quyền

> Phân quyền enforce bằng RBAC ở tầng API; UI counterparts chỉ hiển thị theo kết quả API. Vai dùng đúng 18 vai registry — "CS TL" trong policy đã quy về OPS_PLAN theo DI-006.

| Hành động | OPS_AM | OPS_CONT/DES/EDIT/ADS | OPS_PLAN | BOD_CEO / BOD_CFO_CTO | SYS_ADMIN | CUSTOMER |
|-----------|--------|----------------------|----------|----------------------|-----------|----------|
| Nhận alert SLA (in-app/email/Zalo/Telegram) | ✅ | ✅ | ✅ | ✅ (breach đỏ/khiếu nại qua REQ-BOD-006) | ❌ | ✅ (tenant mình) |
| Xem đồng hồ SLA của đối tượng được gán | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ (ticket tenant mình) |
| Cập nhật hành động trong cửa sổ 80–100% | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Ghi đè SLA target theo profile hợp đồng | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Duyệt gia hạn lần 1 (≤50%) / lần 2 / override FR | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Miễn SLA theo đợt (outage, force majeure) | Đề xuất | ❌ | Đề xuất + hồ sơ | ✅ Duyệt | ❌ | ❌ |
| Xem dashboard compliance theo tier×priority (API) | Khách phụ trách | ❌ | ✅ Toàn phòng | ✅ Tổng hợp | ❌ | ✅ (tenant mình) |
| Cấu hình kênh thông báo cá nhân | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (kênh portal) |
| Cấu hình kênh hệ thống, lịch lễ, rota on-call | ❌ | ❌ | Đề xuất rota | ❌ | ✅ | ❌ |
| Xem audit log override/pause/delivery | Phần mình | ❌ | ✅ | ✅ | ✅ | ❌ |
| Khai báo lịch làm việc riêng của công ty | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (CLIENT_ADMIN) |

---

## 5. Trường Hợp Đặc Biệt

- **Khách đa quốc gia nhiều múi giờ:** mốc tính duy nhất GMT+7, nhưng engine lưu song song mốc giờ địa phương khách trong bản ghi clock để Portal/M-PORTAL hiển thị mà không tự tính lại.
- **Hợp đồng cam kết cao hơn ma trận:** engine dùng target profile và ghi nhận nguồn (matrix/contract) trong timeline; hạ target so với ma trận phải đi luồng sửa hợp đồng, không nhập qua profile.
- **Kênh Zalo/Telegram lỗi:** xử lý theo BR-010 — retry backoff rồi fallback in-app/email; kênh lỗi gắn cờ + cảnh báo SYS_ADMIN, không âm thầm bỏ tin.
- **Platform outage toàn cục:** xử lý theo BR-007 — OPS_PLAN đề xuất, BOD duyệt miễn theo đợt cho tập khách/nền tảng; clock trong đợt chuyển `WAIVED` (không tính breach), timeline giữ nguyên.
- **Auto-Closed "khách không phản hồi"** và **Blocked-3rd-party quá 5 ngày LV:** xử lý theo BR-003 — đóng tự động không tính breach, reopen 7 ngày giữ ngữ cảnh (quá 7 ngày tạo ticket mới, queue thuộc REQ-OPS-009); Blocked hết hạn tự chạy lại clock + escalate AM.
- **Đổi tier giữa chừng (theo V6.0):** clock đang chạy giữ target tại thời điểm khởi tạo; chỉ clock mới hưởng target tier mới.
- **Rota on-call trống / on-call nghỉ đột xuất:** Critical không rơi vào khoảng trống — đẩy thẳng AM + OPS_PLAN kèm alert đỏ BOD, SYS_ADMIN bù rota trong 24h.
- **Giả định ghi nhận (không tự quyết):** [KXN-6], [KXN-7], [KXN-9], [KXN-15]–[KXN-22] còn mở thuộc quy trình Sales/CRM/TMS, không thay đổi số liệu SLA trong spec này; nếu phát hiện giao thoa → quay lại `deferred-issues.md`, không tự chốt.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> Engine quản 2 entity có trạng thái: **SLA Clock** (trạng thái đo) và **Notification** (trạng thái phát) — nội bộ của service, counterparts chỉ đọc qua API.

**Entity 1:** SLA Clock

```
[NOT_STARTED] ──(gán việc/ticket mở)──► [RUNNING] ⇄ (pause/resume) [PAUSED]
                          (chạm 80%)──► [PRE_ALERT] ──(chạm 100%)──► [BREACHED] ──(post-mortem)──► [CLOSED_BREACHED]
                          (Resolved trước 100%)──► [MET]
[Bất kỳ trạng thái chạy] ──(BOD miễn theo đợt)──► [WAIVED];   (auto-Closed/hủy)──► [CANCELLED]
```

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `NOT_STARTED` | Gán việc / mở ticket | `RUNNING` | Hệ thống (event REQ-OPS-009) | Có assignee + tier/priority |
| `RUNNING` | Chạm 80% target | `PRE_ALERT` | Hệ thống | Có người nhận pre-alert |
| `RUNNING` / `PRE_ALERT` | Pending hoặc Blocked-3rd-party | `PAUSED` | Assignee / hệ thống | Pending: lý do; Blocked: case ID platform |
| `PAUSED` | Khách phản hồi / hết blocked | `RUNNING` | Hệ thống / assignee | Ghi timestamp resume; Blocked quá 5 ngày LV → escalate |
| `RUNNING` / `PRE_ALERT` | Chạm 100% target | `BREACHED` | Hệ thống | Báo đỏ AM + OPS_PLAN ≤5 phút; alert REQ-BOD-006 |
| `RUNNING` / `PRE_ALERT` | Resolved kèm mô tả giải pháp | `MET` | Assignee | Đủ điều kiện Res chuẩn hóa |
| `BREACHED` | Hoàn tất post-mortem | `CLOSED_BREACHED` | OPS_PLAN phê duyệt | Trong 5 ngày LV kể từ chạm ngưỡng BR-009 |
| `RUNNING` / `PRE_ALERT` / `BREACHED` | Miễn SLA theo đợt | `WAIVED` | Hệ thống (quyết định BOD) | Quyết định miễn có hiệu lực thời gian + audit log |
| Bất kỳ (trừ kết thúc) | Auto-Closed / hủy | `CANCELLED` | Hệ thống / OPS_PLAN | Auto-Closed theo BR-003; hủy tay bắt buộc lý do |

**Quy tắc:** `MET`, `CLOSED_BREACHED`, `WAIVED`, `CANCELLED` là trạng thái kết thúc — không chuyển tiếp. Từ `BREACHED` không quay về `RUNNING`/`MET` — breach đã ghi là dữ liệu KPI, chỉ có thể `WAIVED` theo quyết định BOD. Mọi chuyển trạng thái ghi audit log bất biến (ai/khi nào/from-to/lý do), kể cả do hệ thống thực hiện.

**Entity 2:** Notification — `QUEUED` → (fan-out kênh) → `SENT` → (receipt) → `DELIVERED` → (đọc/ack) → `READ`; `QUEUED`/`SENT` → (retry hết backoff) → `FAILED` → fallback kênh dự phòng + gắn cờ kênh lỗi. Chỉ hệ thống chuyển trạng thái kỹ thuật; `READ` yêu cầu người nhận; alert breach phía BOD bắt buộc acknowledge + reason.

---

## 7. Tóm Tắt Entity (Quick Reference)

> Tóm tắt entity chính — chi tiết DDL tại `technical-specs/database-design.md`. Toàn bộ bảng mang `tenant_id` phục vụ tenant isolation.

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `sla_policy_matrix` | `tier`, `priority`, `fr_target_min`, `res_target_min`, `clock_mode` | Bảng cấu hình chuẩn (BR-001) | Seed theo ma trận §2.1 |
| `client_sla_profile` | `tenant_id`, `tier`, `fr/res_override_min`, `custom_business_hours` (JSON) | FK → `tenants.id` | Ghi đè khi HĐ cao hơn; chỉ OPS_PLAN sửa |
| `sla_clock` | `subject_type/id`, `tenant_id`, `assignee_id`, `fr_state`, `res_target_min`, `elapsed_business_ms`, `state`, `breached_at` | FK → `client_sla_profile` | Trạng thái theo Mục 6; tính business-time |
| `sla_pause_log` | `clock_id`, `reason`, `case_id`, `started_at`, `ended_at` | FK → `sla_clock.id` | Bắt buộc tái lập timeline (BR-013) |
| `sla_override_log` | `clock_id`, `approver_id`, `override_type`, `old/new_target`, `reason` | FK → `sla_clock.id`, `users.id` | Append-only bất biến (BR-007) |
| `notification` | `tenant_id`, `event_type`, `severity`, `recipient_id`, `channel`, `status`, `idempotency_key`, `sent_at`, `read_at` | FK → `tenants.id`, `users.id` | Gồm `notification_preference` theo user (breach đỏ không tắt được) |
| `oncall_rota` | `period_start`, `shift`, `primary/backup_user_id`, `timezone_coverage` | FK → `users.id` | Trực Critical 24/7, SLA 4h ngoài giờ (DI-005) |
| `holiday_calendar` | `year`, `date`, `is_working_day` | Độc lập | Lịch lễ VN, SYS_ADMIN cấu hình |

---

## 8. Acceptance Criteria

> Điều kiện nghiệm thu — có thể test được; chi tiết hóa ở Phase 5. Mỗi scenario map REQ-OPS-008.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Áp đúng ma trận | Khách tier D, ticket High | Gán assignee | Clock target FR 1h / Res 12h giờ LV, nguồn "matrix" | [ ] |
| SC-002: Ghi đè theo hợp đồng | Profile hợp đồng FR 30 phút High | Ticket High khởi tạo | Dùng target profile, timeline ghi nguồn "contract" | [ ] |
| SC-003: Pause chờ khách | Clock RUNNING, ticket Pending | 24h LV sau nhắc thứ 2 không phản hồi (High) | Auto-Closed "khách không phản hồi", không breach, reopen 7 ngày | [ ] |
| SC-004: Pre-alert 80% | Clock RUNNING đạt 80% Res | Vượt ngưỡng | Cảnh báo vàng assignee + AM qua kênh cấu hình, idempotency key không trùng | [ ] |
| SC-005: Breach và báo khách | Clock PRE_ALERT | Chạm 100% | Báo đỏ AM + OPS_PLAN ≤5 phút; quá 30 phút chưa xác nhận báo khách → alert vi phạm riêng | [ ] |
| SC-006: Override có audit | Cần gia hạn lần 1 ≤50% | OPS_PLAN duyệt kèm lý do | Target mới áp dụng, override append-only; OPS_AM gọi API → 403 | [ ] |
| SC-007: Tenant isolation | CUSTOMER tenant A | Gọi API thông báo, truyền tenant_id = B | Chỉ thấy sự kiện tenant A; tenant B → 403 + audit | [ ] |
| SC-008: Critical on-call ngoài giờ | 21:00 GMT+7 thứ Bảy, Critical Tier E | Sự kiện phân bổ | Phân on-call hiện hành, cam kết 4h; rota trống → AM + OPS_PLAN + alert đỏ BOD | [ ] |
| SC-009: Fallback kênh | Zalo token hết hạn | Notification severity cao phát | Retry → fallback email/in-app, gắn cờ kênh lỗi, báo SYS_ADMIN | [ ] |
| SC-010: Ngưỡng post-mortem | Khách X breach thứ 3 trong 30 ngày | Breach thứ 3 ghi nhận | Tạo yêu cầu post-mortem, hiển thị "chưa tuân thủ" đến khi OPS_PLAN duyệt | [ ] |

> **Liên kết:** SC-001→SC-010 map REQ-OPS-008; SC-008/SC-009 hỗ trợ REQ-BOD-006.

---

## Tài Liệu Kỹ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` (mục MOD-SLA-NOTIF) |
| API Endpoints (SLA clock, notification, compliance, override) | `phase3-architecture/technical-specs/api-contract.md` (mục MOD-SLA-NOTIF) |
| Tích hợp & quy tắc xuyên hệ thống (fan-out 4 counterparts, contract sự kiện REQ-BOD-006, webhook Zalo/email thuộc REQ-OPS-009) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI counterparts | `phase4-ux/sys-bcerp-web/mod-sla-notif/` (dashboard compliance, template báo khách); `phase4-ux/sys-portal-web/mod-sla-notif/` (đồng hồ khách) |
| Nguồn nghiệp vụ gốc | `phase1-business/departments/operations/operations.md` (Mục REQ-OPS-008, B.9); policy `sla-khach-hang.md` §2.1; `P1-02-business-workflow.md` Luồng 5 |
