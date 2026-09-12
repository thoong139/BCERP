# Tính Năng: Ticket & CSKH (BCERP Web Nội Bộ — Nơi Assignee Xử Lý Chính)

> **Dựa trên:** REQ-OPS-009 trong `phase1-business/departments/operations/operations.md` (Phần A3, B.9 — BR-OPS-9.4/9.5); dùng cơ chế SLA tier × priority của REQ-OPS-008 (BR-OPS-9.1–9.3); workflow `phase1-business/P1-02-business-workflow.md` Luồng 5 (CSKH & SLA — B1–B8)
> **Phân hệ:** Vận hành & Marketing nội bộ — Ticket & Chăm sóc Khách hàng (SYS-BCERP-WEB)
> **Module:** Ticket & CSKH (MOD-TICKET-CSKH)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/P1-02-business-workflow.md`, `policies/sla-khach-hang.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/ticket-cskh/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/ticket-cskh/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID do lane fan-out của `/wf-define-features` cấp. REQ-OPS-009 fan-out ra 5 systems — bản này là bản riêng cho **SYS-BCERP-WEB** (web nội bộ responsive Next.js cho nhân viên BC: form/list/workflow UI, gọi API core, hiển thị đúng trạng thái machine-state); counterparts: SYS-CORE-BACKEND (queue hợp nhất, state machine, CSAT engine — business rule enforce ở service layer), SYS-MOBILE-INTERNAL (assignee nhận việc + phản hồi đầu tiên, push escalation), SYS-PORTAL-WEB và SYS-MOBILE-PORTAL (khách tạo ticket/theo dõi/trả CSAT). Tra `req-registry.json` để xác nhận SYS/MOD.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-CSKH-001 |
| Module | MOD-TICKET-CSKH (SYS-BCERP-WEB — BCERP Web nội bộ, ứng dụng Next.js responsive cho nhân viên BC) |
| Yêu cầu nghiệp vụ | REQ-OPS-009 (Ticket & CSKH — MEDIUM · GĐ2 · `operations.md` A3/B.9); dùng cơ chế SLA tier × priority của REQ-OPS-008 (MOD-SLA-NOTIF) |
| Người dùng liên quan | OPS_AM (đầu mối khách, gán việc, xử lý detractor); OPS_PLAN (điều phối khiếu nại nghiêm trọng, review dịch vụ theo CSAT); OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS (assignee nhận việc, phản hồi, cập nhật); BOD_CEO (nhận khiếu nại nghiêm trọng, xem tổng hợp); CUSTOMER (không truy cập WEB nội bộ — thao tác trên SYS-PORTAL-WEB/SYS-MOBILE-PORTAL) |
| Độ ưu tiên | Trung bình (MEDIUM · Phase2 · GĐ2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | Không có cross-dependency FEAT khai báo trong lane. Phụ thuộc kỹ thuật–nghiệp vụ: domain service Ticket & CSKH phía core (FEAT-CORE-CSKH-001 — WEB chỉ là bề mặt gọi API); feature SLA & Notification Engine của `../sla-notif/` (REQ-OPS-008); RBAC + audit log nền chung (REQ-BOD-007) |
| Ghi chú Expert (A7) | Expert review Phần A `operations.md` chưa thực hiện (A7 chờ review — chưa có điều chỉnh cho REQ-OPS-009). Chốt theo DI-006: KHÔNG lập vai OPS_CX — trách nhiệm care/điều phối gán OPS_PLAN. Escalation theo BR-OPS-9.4 (assignee → AM → CS TL → OPS_PLAN → BOD) với spine bắt buộc AM → AD → BOD (AD/CS TL là chức danh thuộc vai registry OPS_AM, không phải vai riêng). Client Survey định kỳ ngoài CSAT ticket còn mở `[KXN-15]` — màn hình gửi khảo sát tham số hóa theo cấu hình; Ma trận RACI chờ xác nhận `[KXN-19]` — dùng chuỗi BR-OPS-9.4 làm mặc định; danh mục cờ K6–K12 chờ chốt `[KXN-20]` — màn hình cấu hình trigger đọc danh mục từ core |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cung cấp bề mặt xử lý ticket & CSKH chính cho nhân viên BC trên web nội bộ: xem queue hợp nhất theo khách/tier, thao tác toàn bộ vòng đời ticket (gán việc, phản hồi, chuyển trạng thái, escalation, khiếu nại nghiêm trọng, CSAT/detractor) và theo dõi SLA tier × priority thời gian thực. WEB là touchpoint nơi assignee xử lý chính theo phân vai trong `operations.md` — mọi business rule enforce ở service layer của core; WEB chỉ gửi hành động qua API và hiển thị đúng trạng thái machine-state, không tự suy diễn.

**Phạm vi:**
- Bao gồm: queue hợp nhất (lọc/sắp theo tier × priority, đồng hồ SLA còn lại, cờ pre-alert 80% vàng / breach 100% đỏ — số liệu từ SLA engine qua core); trang chi tiết ticket với thread đa kênh (portal/email/Zalo, nhãn nguồn, nhãn `manual` cho kênh degraded), timeline SLA và timeline escalation có timestamp; form gán/chuyển assignee theo portfolio; form chuyển trạng thái chỉ mở hành động hợp lệ theo machine-state (Resolved bắt buộc mô tả giải pháp; Pending bắt buộc lý do + case ID khi chờ platform); màn hình escalation (chuỗi assignee → AM → CS TL → OPS_PLAN → BOD, chặng 30 phút có timestamp, spine AM → AD → BOD); form gắn cờ khiếu nại nghiêm trọng + hồ sơ + countdown 24h đẩy BOD; dashboard CSAT theo tier và màn hình detractor ≤2 (nội dung liên hệ + hành động khắc phục gắn ticket gốc, due 48h LV); dashboard SLA compliance FR/Res theo tier×priority (tuần/tháng) cho OPS_AM/OPS_PLAN/BOD_CEO; hiển thị phản hồi CSAT khách từ portal trong ticket detail.
- Không bao gồm: engine queue/state machine/CSAT và validation nghiệp vụ sâu (SYS-CORE-BACKEND — FEAT-CORE-CSKH-001); push notification, thao tác ngoài giờ, offline (SYS-MOBILE-INTERNAL); UI khách tạo ticket/theo dõi/trả CSAT (SYS-PORTAL-WEB / SYS-MOBILE-PORTAL — WEB chỉ xem kết quả); SLA clock + pre-alert/breach + override gia hạn (MOD-SLA-NOTIF — REQ-OPS-008); cấp tài khoản portal (REQ-OPS-010); quy trình đối soát discrepancy (REQ-FIN-004 — chỉ hiển thị liên kết); tổng hợp breach vào KPI nhân sự (REQ-HR-007 — chỉ liên kết xem).

---

## 2. Luồng Người Dùng (User Stories)

Mọi hành động trên WEB đều gọi API core backend; WEB không giữ business logic và luôn render trạng thái do service trả về. Khách không đăng nhập web nội bộ — hành động phía khách diễn ra trên portal counterparts, kết quả hiển thị lại cho nhân viên BC tại đây.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_AM | Xem queue hợp nhất yêu cầu khách mình từ mọi kênh, đã gán tier×priority, sắp theo SLA còn lại | Ưu tiên đúng theo tier, không sót yêu cầu rải rác nhiều kênh |
| 2 | OPS_AM | Gán/chuyển assignee trên ticket, thấy đồng hồ SLA + bước escalation hiện tại | Phân phối việc minh bạch, can thiệp trước ticket sắp breach |
| 3 | OPS_CONT / OPS_DES / OPS_EDIT / OPS_ADS | Nhận việc, soạn phản hồi đầu tiên kèm file, và chuyển Pending với lý do (chờ khách / chờ platform kèm case ID) | First Response ghi timestamp chuẩn qua API; thời gian chờ pause đồng hồ, không tính breach oan |
| 4 | OPS_AM | Thấy điểm CSAT và câu mở khách trả lời trên portal ngay trong ticket detail, và xử lý detractor ≤2 bằng việc ghi nội dung liên hệ lại + hành động khắc phục gắn ticket gốc | Đáp ứng cam kết liên hệ lại trong 48h làm việc, trải nghiệm khách có hành động theo sau |
| 5 | OPS_PLAN | Gắn cờ khiếu nại nghiêm trọng (Tier D/E, mất tiền, sai sót đối soát, đạo đức nhân viên), upload hồ sơ, đẩy BOD với countdown 24h | Khiếu nại không "chìm" trong queue thường, trách nhiệm điều phối rõ ràng |
| 6 | OPS_PLAN | Xem dashboard SLA compliance FR/Res theo tier×priority + CSAT theo tier; nhận review item tự sinh khi CSAT tier <4,0 hai tháng liên tiếp; cấu hình thêm cờ/trigger đọc danh mục từ core | Đánh giá chất lượng dịch vụ theo bằng chứng đo lường, mở rộng trigger không cần sửa code |
| 7 | BOD_CEO | Nhận khiếu nại nghiêm trọng kèm hồ sơ đầy đủ trong 24h qua alert center/dashboard | Ra quyết định khủng hoảng đúng thời điểm với đủ dữ liệu |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Đặc thù touchpoint web nội bộ: mọi rule nghiệp vụ enforce ở service layer của core; WEB là form/list/workflow UI — bắt buộc hiển thị đúng trạng thái machine-state và chỉ cho phép hành động hợp lệ theo trạng thái hiện tại.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **WEB không sở hữu trạng thái:** trạng thái ticket, đồng hồ SLA, bước escalation lấy từ API core và render nguyên vẹn (badge machine-state đúng nguyên văn `NEW/OPEN/PENDING/RESOLVED/CLOSED/REOPENED`); không cache vượt TTL, không tự suy diễn từ hành động người dùng. Nguồn: REQ-OPS-009; Notes lane. | Dữ liệu lệch phiên → re-fetch từ core trước khi cho thao tác; hành động trên trạng thái cũ → core từ chối "STATE_KHONG_CON_HOP_LE", WEB bắt tải lại |
| BR-002 | **Queue hiển thị chuẩn:** ticket kế thừa tier × priority từ profile (E nhanh nhất — A chậm nhất, Critical 24/7); sắp mặc định theo SLA còn lại; cờ pre-alert 80% (vàng) và breach 100% (đỏ) do SLA engine trả về — WEB không tự tính phần trăm. Nguồn: BR-OPS-9.1/9.2 (REQ-OPS-008). | Thiếu dữ liệu SLA → hiển thị "không xác định" kèm retry, tuyệt đối không ẩn ticket khỏi queue |
| BR-003 | **Form chuyển trạng thái theo machine-state:** UI chỉ mở hành động hợp lệ theo trạng thái (bảng Mục 6); Resolved bắt buộc mô tả giải pháp; Pending bắt buộc lý do + case ID platform nếu chờ bên thứ ba; reopen chỉ trong 7 ngày kể từ Closed — quá hạn nút đổi thành "tạo ticket mới tham chiếu". Nguồn: BR-OPS-9.4; REQ-OPS-009 A3. | Thiếu trường bắt buộc → chặn submit "THIEU_MO_TA_GIAI_PHAP"/"THIEU_LY_DO"/"THIEU_CASE_ID"; đổi trạng thái sai bảng → core từ chối "INVALID_TRANSITION" |
| BR-004 | **Gán/điều phối theo portfolio:** OPS_AM gán trong portfolio khách mình; OPS_PLAN điều phối toàn bộ; assignee chỉ thấy/thao tác ticket được gán; mọi gán/chuyển ghi audit log bất biến ở core. Nguồn: BR-OPS-9.4; REQ-OPS-009 A3. | Gán ngoài portfolio → từ chối "NGOAI_PORTFOLIO"; thao tác ngoài quyền → ẩn hành động + từ chối API |
| BR-005 | **Escalation hiển thị đủ timestamp:** timeline hiển thị chuỗi assignee → AM → CS TL → OPS_PLAN → BOD, mỗi chặng SLA 30 phút trong giờ trực, timestamp bắt buộc; spine cam kết tối thiểu **AM → AD → BOD** (AD/CS TL là chức danh thuộc vai OPS_AM — hiển thị chức danh, không tạo vai mới); 5 trigger tự động do core kích hoạt — WEB chỉ hiển thị và cho OPS_AM/OPS_PLAN "đẩy chặng" theo quyền. Nguồn: BR-OPS-9.4; Notes lane. | Thiếu timestamp chặng → gắn nhãn bất thường + cảnh báo OPS_PLAN trên timeline |
| BR-006 | **Khiếu nại nghiêm trọng:** form gắn cờ chỉ mở khi chọn đủ ≥1 trong 4 tiêu chí (khách Tier D/E, mất tiền, sai sót đối soát, đạo đức nhân viên); hồ sơ (thread + timeline + evidence) bắt buộc trước khi đẩy BOD; hiển thị countdown 24h và trạng thái "đã đến BOD"; OPS_PLAN chốt cờ + điều phối; liên kết 2 chiều REQ-FIN-004 khi có phản đối số liệu. Nguồn: BR-OPS-9.5; P1-02 Luồng 5 B6/B7. | Đẩy BOD thiếu hồ sơ → chặn "THIEU_HO_SO_KHIEU_NAI"; cờ không đủ tiêu chí → chỉ chạy escalation thường |
| BR-007 | **CSAT & detractor:** điểm CSAT (1–5 + câu mở) khách trả trên portal hiển thị trong ticket detail; detractor ≤2 tự sinh task liên hệ lại due 48h LV gắn ticket gốc — OPS_AM ghi nội dung liên hệ + hành động khắc phục, thiếu một trong hai không đóng được; CSAT tier <4,0 hai tháng liên tiếp hiển thị review item do OPS_PLAN chủ trì. Nguồn: BR-OPS-9.5; P1-02 B5. | Đóng task detractor thiếu nội dung/hành động khắc phục → core từ chối "THIEU_HANH_DONG_KHAC_PHUC" |
| BR-008 | **Dashboard compliance từ số liệu core:** FR/Res theo tier×priority, breach, MTTR, breach lặp lại (tuần/tháng) và CSAT theo tier đọc trực tiếp từ core — WEB không tổng hợp riêng, không có con số tự tính; BOD_CEO xem tổng hợp, không thao tác nghiệp vụ. Nguồn: REQ-OPS-008/009; P1-02 A5 #3. | Số liệu cũ → hiển thị mốc freshness; core không phản hồi → hiển thị trạng thái lỗi, không hiện số cũ không nhãn |
| BR-009 | **Phạm vi hiển thị + ranh giới dữ liệu:** OPS_AM/assignee chỉ thấy khách trong portfolio/quyền gán; OPS_PLAN thấy toàn bộ; ghi chú nội bộ chỉ hiển thị cho nhân sự nội bộ, không đồng bộ sang portal; CUSTOMER không có tài khoản truy cập WEB nội bộ. Nguồn: REQ-OPS-010; Notes lane. | Truy cập ngoài quyền → ẩn UI + từ chối API (chặn kép); dữ liệu nhạy cảm khách (giá vốn/chiết khấu) xuất hiện sai chỗ → chặn màn hình + báo lỗi cấu hình |
| BR-010 | **Mọi thao tác qua API có audit:** đổi trạng thái, gán việc, đẩy escalation, gắn cờ, đóng detractor đều được core ghi append-only + hash-chain; WEB không có chức năng xóa/sửa log ở mọi vai. Nguồn: REQ-BOD-007; BR-OPS-9.4/9.5. | Nỗ lực ghi đè/xóa log → không tồn tại UI; gọi API xóa → từ chối + audit log bảo mật |

---

## 4. Phân Quyền

| Hành động | OPS_AM | OPS_PLAN | OPS_CONT/DES/EDIT/ADS | BOD_CEO | SYS_ADMIN | CUSTOMER |
|-----------|--------|----------|------------------------|---------|-----------|----------|
| Xem queue + SLA clock | ✅ (portfolio mình) | ✅ (toàn bộ) | ✅ (ticket được gán) | ❌ (chỉ tổng hợp) | ❌ (không xem nghiệp vụ) | ❌ (qua portal) |
| Xem chi tiết ticket + thread đa kênh | ✅ | ✅ | ✅ (ticket được gán) | ❌ | ❌ | ❌ (qua portal) |
| Gán/chuyển assignee | ✅ (portfolio mình) | ✅ (toàn bộ) | ❌ | ❌ | ❌ | ❌ |
| Phản hồi/cập nhật ticket (kèm file) | ✅ | ✅ | ✅ (ticket được gán) | ❌ | ❌ | ❌ (qua portal) |
| Chuyển Pending / trả Open | ✅ | ✅ | ✅ (ticket được gán) | ❌ | ❌ | ❌ |
| Resolved (kèm mô tả giải pháp) / Closed | ✅ | ✅ | ✅ (ticket được gán) | ❌ | ❌ | ❌ |
| Reopen ≤7 ngày | ✅ | ✅ | ✅ (ticket được gán) | ❌ | ❌ | ❌ (qua portal) |
| Tạo ticket mới tham chiếu (quá 7 ngày) | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ (qua portal) |
| Đẩy chặng escalation / nhắc chặng | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Gắn cờ khiếu nại nghiêm trọng + hồ sơ | ✅ (đề xuất cờ) | ✅ (chốt cờ + điều phối) | ❌ | ❌ | ❌ | ❌ |
| Nhận hồ sơ khiếu nại / xem tổng hợp | ❌ | ✅ (điều phối) | ❌ | ✅ | ❌ | ❌ |
| Ghi nội dung liên hệ + hành động khắc phục detractor | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Xem điểm CSAT + câu mở của khách | ✅ (portfolio mình) | ✅ | ✅ (ticket được gán) | ❌ (chỉ tổng hợp) | ❌ | ❌ (người trả) |
| Xem dashboard SLA compliance / CSAT theo tier | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ |
| Cấu hình cờ/trigger ngoài 5 trigger | ❌ | ✅ (danh mục từ core) | ❌ | ❌ | ✅ (vận hành kỹ thuật) | ❌ |
| Xóa/sửa audit log ticket | ❌ | ❌ | ❌ | ❌ | ❌ (không tồn tại ở mọi vai) | ❌ |

> Ghi chú touchpoint: quyền enforce 2 lớp — UI ẩn hành động không thuộc quyền, API core từ chối độc lập (không tin UI). CUSTOMER không truy cập web nội bộ: quyền tạo ticket, comment, reopen, trả CSAT của khách vận hành trên SYS-PORTAL-WEB/SYS-MOBILE-PORTAL (counterparts). CS TL/AD trên timeline escalation là chức danh thuộc vai OPS_AM theo chốt DI-006/registry — không phải vai registry riêng.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Mất kết nối khi đang soạn phản hồi:** draft lưu cục bộ trên trình duyệt; khi mạng trở lại submit qua API với idempotency-key — không sinh trùng phản hồi, không sai timestamp First Response.
- **Trạng thái màn hình đã cũ hoặc xung đột phiên (hai người cùng mở 1 ticket, khách vừa reopen qua portal):** mọi hành động gửi kèm phiên trạng thái + optimistic locking từ core; khi xung đột, WEB báo "trạng thái đã đổi", tự làm mới machine-state mới nhất và giữ nội dung soạn — không giữ nút hành động cho trạng thái không còn tồn tại.
- **Cùng yêu cầu vào từ nhiều kênh:** core dedupe gộp về một ticket (khách + chủ đề + tài sản); WEB hiển thị danh sách nguồn kênh trên ticket gốc, phản hồi BC được core đồng bộ mọi kênh tham chiếu.
- **Ticket nguồn kênh degraded (email/Zalo import tay):** hiển thị nhãn `manual` kèm timestamp; vẫn trong queue và tính SLA compliance bình thường (DI-007) — không bị loại khỏi báo cáo.
- **Detractor chấm sau khi ticket Closed / CSAT không có phản hồi:** không mở lại trạng thái ticket — vòng khắc phục chạy trên task gắn ticket gốc (BR-007); CSAT chỉ nhắc đúng 1 lần sau 48h do core kiểm soát, WEB hiển thị "không phản hồi" kèm tỷ lệ phản hồi của tier để không đọc sai điểm trung bình.
- **Khiếu nại trùng phản đối số liệu:** hiển thị đồng thời luồng khiếu nại BOD 24h và liên kết quy trình đối soát REQ-FIN-004 ("Đang đối soát"); AM không tự chốt số trước khi FIN đối trừ.
- **Queue quá lớn (2.600+ TKQC):** phân trang + bộ lọc bắt buộc theo tier/priority/khách; mặc định nổi nhóm sắp breach và đã breach; màn hình cấu hình cờ chỉ đọc danh mục từ core (`[KXN-20]`) — khi chốt, OPS_PLAN mở rộng trigger qua cấu hình, WEB không hardcode cờ mới.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Ticket (hỗ trợ/CSKH) — state machine sở hữu bởi core backend; WEB hiển thị đúng trạng thái machine-state và chỉ mở hành động hợp lệ.

**Sơ đồ trạng thái (hiển thị trên WEB bằng badge đúng nguyên văn):**
```
[NEW] ──(nhận việc)──► [OPEN] ──(resolve + mô tả giải pháp)──► [RESOLVED] ──(đóng)──► [CLOSED]
                        │  ▲                                    │                     │
                        │  └──(khách/bên 3 phản hồi)──┐         │                     │ (reopen ≤7 ngày — giữ ngữ cảnh)
                        │                             │         │ (khách xác nhận/    ▼
                        │ (chờ khách / chờ platform   │         │  AM đóng)     [REOPENED] ──► (về OPEN)
                        │  có case ID — SLA pause)    │         ▼
                        ▼                             │     [CLOSED]
                    [PENDING] ────────────────────────┘
                        │
                        │ (auto: 2 nhắc + 24h/24h LV không phản hồi — do core)
                        ▼
                    [CLOSED — "khách không phản hồi", không tính breach]

[CLOSED] ──(quá 7 ngày)──► KHÔNG reopen — WEB bắt buộc luồng "tạo ticket MỚI tham chiếu ticket gốc"
```

**Bảng chuyển đổi (góc thao tác trên WEB):**

| Trạng thái hiện tại | Hành động trên WEB | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|--------------------|----------------|--------------|---------------------|
| `NEW` | Nhận việc | `OPEN` | OPS_AM/OPS_PLAN (hoặc core tự gán) | Có assignee; FR clock chạy từ lúc tạo ticket |
| `OPEN` | Chuyển Pending | `PENDING` | Assignee được gán, OPS_AM, OPS_PLAN | Lý do bắt buộc: chờ khách, hoặc chờ platform kèm case ID (SLA pause do core xử lý) |
| `PENDING` | Trả lại xử lý | `OPEN` | Assignee, OPS_AM, OPS_PLAN | Có phản hồi khách hoặc cập nhật case từ platform |
| `PENDING` | Xem auto-Closed | `CLOSED` | Hệ thống (core) — WEB hiển thị kết quả | Đủ 2 nhắc có timestamp + 24h không phản hồi; lý do "khách không phản hồi"; không tính breach; vẫn reopen được trong 7 ngày |
| `OPEN` | Resolve | `RESOLVED` | Assignee được gán, OPS_AM, OPS_PLAN | Mô tả giải pháp bắt buộc; Res timestamp do core ghi; breach (nếu có) xử lý theo MOD-SLA-NOTIF |
| `RESOLVED` | Đóng | `CLOSED` | Assignee, OPS_AM, OPS_PLAN | Core tự sinh CSAT gửi portal; thời điểm đóng hiển thị trên timeline |
| `CLOSED` | Reopen | `REOPENED` | CUSTOMER (qua portal), OPS_AM, OPS_PLAN, assignee | Trong 7 ngày kể từ Closed; giữ toàn bộ ngữ cảnh; reopen lần ≥2 kích hoạt escalation (spine AM → AD → BOD) |
| `CLOSED` (quá 7 ngày) | Tạo ticket mới tham chiếu | `NEW` (ticket mới) | Mọi vai nội bộ được tạo ticket | Bắt buộc tham chiếu ticket gốc; ticket gốc chỉ đọc vĩnh viễn |

**Quy tắc:**
- WEB không tự đổi trạng thái — mọi chuyển đổi gửi qua API core, ghi audit log bất biến (ai, khi nào, từ/sang, căn cứ); badge trạng thái render nguyên văn giá trị machine-state, không phiên dịch tùy ý.
- `CLOSED` không mở trực tiếp sau 7 ngày; không tồn tại đường lùi từ `RESOLVED`/`CLOSED` về `OPEN` ngoài luồng reopen có điều kiện.
- Escalation không đổi trạng thái ticket — timeline escalation là lớp song song gắn ticket; WEB hiển thị cả hai tách bạch để đồng hồ SLA và state machine không lệch.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity/view model chính để developer nắm nhanh. Touchpoint WEB không sở hữu DDL — toàn bộ dữ liệu từ API core (DDL đầy đủ tại `database-design.md` của SYS-CORE-BACKEND, FEAT-CORE-CSKH-001).*

| Entity/ViewModel | Fields chính | Nguồn | Ghi chú |
|--------|-------------|---------|---------|
| `QueueView` | `ticket_code`, `tier`, `priority`, `sla_remaining`, `pre_alert_80`, `breach_flag`, `assignee`, `escalation_step`, `channel_sources[]` | Queue API (core) | Sắp mặc định theo SLA còn lại; không tự tính SLA phía client (BR-002) |
| `TicketDetailView` | `state`, `tier`, `priority`, `subject`, `thread[]` (author_type, channel, attachments, is_first_response), `internal_notes[]`, `pending_reason`, `platform_case_id` | Ticket API (core) | Badge `state` render nguyên văn machine-state (BR-001); `internal_notes` không đồng bộ portal (BR-009) |
| `EscalationTimelineView` | `trigger`, `current_step` (`ASSIGNEE/AM/CS_TL/OPS_PLAN/BOD`), `step_history[]` (step, actor, timestamp), `status` | Escalation API (core) | Mỗi chặng 30 phút có timestamp; spine AM → AD → BOD (BR-005) |
| `ComplaintDossierView` | `criteria[]` (`TIER_DE/MONEY_LOSS/RECON_ERROR/ETHICS`), `files[]`, `bod_notified_at`, `countdown_24h`, `coordinator` (OPS_PLAN), `recon_link` | Complaint API (core) | Đẩy BOD chặn khi thiếu hồ sơ (BR-006); liên kết 2 chiều REQ-FIN-004 |
| `CsatResultView` | `score` (1–5), `open_comment`, `reminders_sent`, `no_response`, `submitted_at` | CSAT API (core) | Khách trả trên portal — WEB chỉ hiển thị (BR-007) |
| `DetractorTaskView` | `due_at` (48h LV), `contact_note`, `remediation_action`, `closed_at` | Task API (core) | Chặn đóng khi thiếu contact_note/remediation (BR-007) |
| `ComplianceDashboard` | `fr_res_by_tier_priority`, `breach_count`, `mttr`, `repeat_breach`, `csat_by_tier`, `freshness` | Dashboard API (core) | WEB không tổng hợp riêng — hiển thị mốc freshness (BR-008) |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ ở Phase 2 — chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-OPS-009 (`operations.md` A3/B.9 — BR-OPS-9.4/9.5).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Queue đúng thứ tự SLA | OPS_AM đăng nhập, khách tier E có ticket sắp breach | Mở queue | Ticket tier E sắp breach đứng đầu; cờ vàng 80%/đỏ 100% đúng tín hiệu SLA engine; không ticket nào bị ẩn khi thiếu dữ liệu | [ ] |
| SC-002: Form trạng thái chỉ mở hành động hợp lệ | Ticket đang `NEW` | Mở menu hành động | Chỉ có "Nhận việc"; không có nút Resolve/Pending; badge hiển thị đúng `NEW` | [ ] |
| SC-003: Resolved chặn thiếu mô tả giải pháp | Assignee đang resolve ticket `OPEN` | Submit không nhập mô tả giải pháp | Chặn "THIEU_MO_TA_GIAI_PHAP"; nhập đủ thì core ghi Res timestamp, chuyển `RESOLVED` | [ ] |
| SC-004: Reopen quá hạn đổi luồng | Ticket `CLOSED` 10 ngày | OPS_AM mở ticket | Không còn nút reopen; hiển thị "tạo ticket mới tham chiếu"; ticket gốc chỉ đọc | [ ] |
| SC-005: Timeline escalation đủ timestamp | Ticket kích hoạt trigger "Pending quá 3 ngày LV" | OPS_PLAN mở timeline | Chuỗi assignee → AM → CS TL → OPS_PLAN → BOD hiện đủ với timestamp từng chặng; chặng thiếu timestamp gắn nhãn bất thường + cảnh báo | [ ] |
| SC-006: Khiếu nại nghiêm trọng đẩy BOD | OPS_PLAN gắn cờ "mất tiền" khách Tier D | Upload hồ sơ và đẩy BOD | Countdown 24h hiển thị; hồ sơ đến BOD qua alert center; thiếu hồ sơ bị chặn "THIEU_HO_SO_KHIEU_NAI" | [ ] |
| SC-007: Detractor chặn đóng thiếu hành động | CSAT ≤2 vừa submit trên portal | OPS_AM mở task detractor | Task due 48h LV gắn ticket gốc; đóng thiếu contact_note/remediation bị core từ chối "THIEU_HANH_DONG_KHAC_PHUC" | [ ] |
| SC-008: Phân quyền 2 lớp chặn truy cập chéo | OPS_CONT chỉ được gán ticket khách A | Thử mở queue khách B ngoài portfolio | Queue B không hiển thị; gọi trực tiếp API → core từ chối + audit log bảo mật | [ ] |
| SC-009: Xung đột phiên trạng thái | Assignee và OPS_AM cùng mở 1 ticket | OPS_AM resolve trước, assignee submit hành động cũ | Core từ chối "STATE_KHONG_CON_HOP_LE"; WEB thông báo, tải lại trạng thái mới, giữ nội dung soạn | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` (entity sở hữu tại core backend — WEB chỉ tiêu thụ view model) |
| API Endpoints | `technical-specs/api-contract.md` (queue/ticket/state machine/escalation/complaint/CSAT API; idempotency-key submit; optimistic locking phiên trạng thái; RBAC + tenant/portfolio scoping enforce tầng service) |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (SLA engine MOD-SLA-NOTIF — pre-alert/breach/pause; event từ M-INT/alert center; nhãn `manual` kênh degraded theo DI-007; liên kết đối soát REQ-FIN-004; dữ liệu breach → KPI REQ-HR-007) |
| Màn hình UI | `phase4-ux/bcerp-web/ticket-cskh/[screen-group].md` (queue, ticket detail, escalation timeline, khiếu nại nghiêm trọng, CSAT/detractor, dashboard compliance) |
| Policy nghiệp vụ | `policies/sla-khach-hang.md` §2.1 (ma trận tier×priority — REQ-OPS-008); `policies/client-portal-minh-bach-bao-mat.md` (ranh giới dữ liệu khách, tenant isolation) |
| Feature liên quan | Domain service core: `../../core-backend/ticket-cskh/ticket-va-cskh.md` (FEAT-CORE-CSKH-001); SLA engine: feature của `../sla-notif/` (REQ-OPS-008 — lane song song); alert center: `../datahub-bi/alert-center-va-canh-bao-rui-ro-van-hanh.md`; counterparts: feature của `../../portal-web/ticket-cskh/`, `../../mobile-portal/ticket-cskh/` (khách tạo ticket/theo dõi/trả CSAT), `../../mobile-internal/ticket-cskh/` (assignee nhận việc + push escalation) |
| Workflow tổng | `phase1-business/P1-02-business-workflow.md` (Luồng 5 — CSKH & SLA: B1–B8; RACI; handoff & SLA: breach đỏ ≤5 phút vào alert center, khiếu nại BOD 24h, post-mortem breach lặp) |
