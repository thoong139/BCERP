# Tính Năng: Client Portal Góc Nhìn Ops — Cấp Tài Khoản & Monitor

> **Dựa trên:** REQ-OPS-010 trong `phase1-business/departments/operations/operations.md` (Phần A3, B.5 — BR-OPS-5.1/5.2/5.3/5.4/5.5, BR-OPS-3.2); REQ-FIN-017 trong `phase1-business/departments/finance/finance.md` (ví read-only cho portal — share model chung)
> **Phân hệ:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** Client Portal (MOD-CLIENT-PORTAL)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/departments/finance/finance.md`, `phase1-business/P1-02-business-workflow.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/client-portal/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/client-portal/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID do lane fan-out của `/wf-define-features` cấp. REQ-OPS-010 fan-out ra 5 systems — bản này là bản riêng cho **SYS-BCERP-WEB** (nơi OPS_AM thao tác cấp tài khoản và theo dõi adoption); counterparts: SYS-CORE-BACKEND (FEAT-CORE-CPORT-002 — provisioning, gate engine, tenant isolation), SYS-MOBILE-INTERNAL (push AM: ticket mới/phản hồi khách, cảnh báo trượt gate), SYS-PORTAL-WEB (trải nghiệm khách web), SYS-MOBILE-PORTAL (touchpoint rút gọn). Tra `req-registry.json` để xác nhận SYS/MOD.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| ID tính năng | FEAT-ERP-CPORT-001 |
| Module | MOD-CLIENT-PORTAL (SYS-BCERP-WEB — web nội bộ responsive Next.js: form/list/workflow UI, gọi API core, hiển thị đúng machine-state) |
| Yêu cầu nghiệp vụ | REQ-OPS-010 (Client Portal góc nhìn ops — cấp tài khoản & monitor — HIGH · Phase3/GĐ3); REQ-FIN-017 (dữ liệu ví read-only cho Client Portal — MEDIUM · GĐ3) |
| Người dùng liên quan | OPS_AM (chính — cấp/kích hoạt tài khoản portal, monitor adoption); OPS_PLAN (điều phối escalation khi trượt gate, giám sát adoption toàn team); OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS (xem adoption/phản hồi ticket của tenant mình phụ trách); CUSTOMER (CLIENT_ADMIN/CLIENT_USER — bề mặt là PORTAL/M-PORTAL, không thao tác trên web nội bộ) |
| Độ ưu tiên | Cao (HIGH · GĐ3) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | FEAT-CORE-CPORT-002 (provisioning + gate engine phía core — web chỉ là bề mặt thao tác); FEAT-CORE-CPORT-001 / bản REQ-FIN-017 (dữ liệu ví read-only — điều kiện "khách tự xem được số dư" của gate Day 14); REQ-OPS-009 (queue ticket hợp nhất — nguồn dữ liệu monitor phản hồi); REQ-OPS-004 (onboarding tự sinh dự án — milestone Day 1/7/14/30 chạy trên dự án đó); RBAC/2FA nền chung (REQ-BOD-007) |
| Ghi chú Expert (A7) | Expert review Phần A `operations.md` chưa thực hiện (chờ review); đã chốt theo DI-006: KHÔNG lập vai OPS_CX — trách nhiệm điều phối escalation/khiếu nại gán OPS_PLAN; hình thức thu feedback Day 30 (AM tay / hệ thống tự gửi Client Survey) còn mở `[KXN-15]` — spec tham số hóa, không hardcode |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Là bề mặt thao tác của OPS trên web nội bộ BCERP cho góc nhìn ops đối với Client Portal: **cấp/kích hoạt tài khoản portal đúng mốc onboarding Day 1/7/14/30** (Day 14 là gate "khách kích hoạt portal thành công") và **monitor adoption + phản hồi ticket theo từng khách** mà không phải hỏi lẻ từng người. Trạng thái gate, activation, 2FA coverage là machine-state do core quyết định — web cung cấp checklist milestone, form gửi invite và dashboard monitor, không tự tính kết luận; mọi enforcement (tenant isolation, mask dữ liệu, quota user) nằm ở service layer của core backend.

**Phạm vi:**
- Bao gồm: form cấp CLIENT_ADMIN đầu tiên + gửi invite tại Day 1 (gọi provisioning API của core); luồng cấp/thu hồi CLIENT_ADMIN — AM đề xuất, hệ thống nhắc xác nhận danh tính POC trong 1 ngày làm việc, mọi bước ghi audit log.
- Bao gồm: checklist milestone onboarding Day 1/7/14/30 theo BR-OPS-3.2 — hiển thị pass/fail từng mốc với tiêu chí machine-checkable; cảnh báo sớm khi khách chậm kích hoạt; khi trượt gate Day 14, form ghi root cause + kế hoạch khắc phục (owner + deadline) phục vụ escalation CS TL (OPS_PLAN) trong 24h; gate hiển thị là điều kiện nghiệm thu giai đoạn onboarding của dự án.
- Bao gồm: dashboard monitor adoption theo khách — activation rate, 2FA coverage, login/tuần, số user thực tế vs quota theo hợp đồng (mặc định 2 CLIENT_ADMIN + 10 CLIENT_USER, mở rộng theo tier); monitor phản hồi ticket theo khách/tier (kéo từ queue hợp nhất REQ-OPS-009), trạng thái đối soát khi khách phản đối số liệu.
- Bao gồm: view read-only nội dung khách đang thấy trên portal (số dư ví read-only theo REQ-FIN-017, chi tiêu daily, tiến độ, ticket) để AM hỗ trợ khách đúng dữ liệu — kèm cùng disclaimer độ trễ và mask giá vốn thành "điều chỉnh đối soát"; AM không có bất kỳ action ghi số dư nào.
- Không bao gồm: provisioning engine, tenant isolation, gate engine (SYS-CORE-BACKEND — FEAT-CORE-CPORT-002); push mobile cho AM (SYS-MOBILE-INTERNAL — web chỉ là nơi xem chi tiết, mobile là kênh cảnh báo); UI portal phía khách (SYS-PORTAL-WEB / SYS-MOBILE-PORTAL); SLA clock, escalation engine và CSAT của luồng ticket (REQ-OPS-009); lệnh nạp/rút/điều chỉnh ví (MOD-WALLET-RECON — REQ-FIN-001/004/006).

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-BCERP-WEB — web nội bộ responsive: OPS_AM thao tác cấp tài khoản và theo dõi adoption; CUSTOMER xuất hiện trong ma trận chỉ để phân định biên giới — khách dùng portal riêng (PORTAL/M-PORTAL), không bao giờ đăng nhập web nội bộ. REQ-OPS-010 fan-out 5 systems: bản WEB là "bàn điều khiển" của AM, còn trải nghiệm khách thuộc counterparts portal.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_AM | Tạo CLIENT_ADMIN đầu tiên và gửi invite ngay tại Day 1 của milestone onboarding từ màn dự án | Khách có tài khoản truy cập portal từ sớm, đúng tiến trình handoff đã cam kết |
| 2 | OPS_AM | Thấy checklist Day 1/7/14/30 với trạng thái pass/fail từng mốc (activation, 2FA, login/tuần) tự cập nhật từ core | Biết khách đang ở đâu trong hành trình kích hoạt mà không phải dò tay qua email/Zalo |
| 3 | OPS_AM | Nhận cảnh báo khi khách chậm kích hoạt gần Day 14 (ví dụ Day 10 vẫn <80% user active) | Kích hoạt khách kịp trước gate thay vì phát hiện trượt sau khi gate đã qua |
| 4 | OPS_AM | Ghi root cause + kế hoạch khắc phục (owner + deadline) ngay trên web khi gate Day 14 trượt | Escalation lên CS TL trong 24h có hồ sơ đầy đủ, không gọi điện kể chuyện |
| 5 | OPS_AM | Đề xuất cấp/thu hồi CLIENT_ADMIN kèm bước xác nhận danh tính POC trong 1 ngày làm việc | Quyền quản trị portal của khách chỉ trao/nhớt đúng người có thật, có vết audit |
| 6 | OPS_PLAN | Xem dashboard adoption + tình trạng gate Day 14 của toàn bộ khách trong team | Phát hiện khách trượt gate muộn, điều phối escalation và báo cáo nghiệm thu onboarding |
| 7 | OPS_CONT / OPS_DES / OPS_EDIT / OPS_ADS | Xem adoption và phản hồi ticket của các tenant mình phụ trách (view-only) | Chủ động chăm trải nghiệm khách ở phần mình làm (content/design/edit/ads) |
| 8 | OPS_AM | Xem đúng nội dung khách đang thấy trên portal (số dư ví read-only, chi tiêu daily, ticket) kèm disclaimer độ trễ | Hỗ trợ khách bằng cùng một nguồn số, không tạo ra hai phiên bản sự thật |
| 9 | OPS_AM | Theo dõi số user portal thực tế so với quota theo hợp đồng (mặc định 2 ADMIN + 10 USER) | Báo khách khi gần chạm quota và đề xuất mở rộng theo tier khi cần |
| 10 | OPS_PLAN | Theo dõi tình trạng "Đang đối soát" của các khách đang phản đối số liệu trên portal | Biết các disputes đang mở để phối hợp FIN xử lý đúng SLA, tránh khiếu nại leo thang BOD |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Đặc thù touchpoint: web nội bộ là bề mặt thao tác + hiển thị; mọi rule được core enforce lại ở tầng service/API — web KHÔNG được chứa logic nới lỏng hoặc tự suy diễn machine-state. Nguồn: BR-OPS-3.2, BR-OPS-5.1–5.5 (`operations.md` B.3/B.5); REQ-FIN-017 (`finance.md` A3); BR-FIN-603/605 (`finance.md` B.6).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|-------------------|
| BR-001 | Milestone onboarding portal theo mốc Day 1/7/14/30 (BR-OPS-3.2/5.1): Day 1 — AM tạo CLIENT_ADMIN đầu tiên + gửi invite (WEB → CORE provisioning); Day 7 — ≥80% user kích hoạt, 2FA bật 100%; Day 14 — GATE "khách kích hoạt portal thành công" (khách tự xem được số dư + chi tiêu + ticket; ≥1 login/tuần từ ≥2 user); Day 30 — review adoption + thu feedback (hình thức `[KXN-15]` — spec tham số hóa). Checklist trên web hiển thị pass/fail từng mốc theo tiêu chí machine-checkable do core tính. | Mốc thiếu dữ liệu → hiển thị "Chưa đánh giá được", không được phép đánh pass tay; AM không có nút đè kết quả gate |
| BR-002 | Gate Day 14 trượt → escalation root cause lên CS TL (OPS_PLAN) trong 24h, kế hoạch khắc phục bắt buộc có owner + deadline (web bắt buộc nhập đủ 3 trường trước khi lưu hồ sơ trượt); gate Day 14 là điều kiện nghiệm thu giai đoạn onboarding — không nghiệm thu được khi gate còn trượt. | Thiếu owner/deadline → form không cho submit; cố nghiệm thu dự án khi gate trượt bị chặn và ghi audit log |
| BR-003 | Cấp/thu hồi CLIENT_ADMIN: AM đề xuất + hệ thống xác nhận danh tính POC trong 1 ngày làm việc trước khi hiệu lực; portal user (CLIENT_USER) do CLIENT_ADMIN tự quản trên portal — nội bộ kể cả SYS_ADMIN KHÔNG tạo hộ. Web chỉ có form đề xuất + theo dõi trạng thái, không có form tạo user thay khách. | Cố tạo user portal trực tiếp từ web → API core từ chối; mọi đề xuất cấp/thu hồi không có xác nhận danh tính POC không hiệu lực |
| BR-004 | Số user portal theo hợp đồng: mặc định 2 CLIENT_ADMIN + 10 CLIENT_USER, mở rộng theo tier; core kiểm quota khi provisioning — web hiển thị usage vs quota theo từng khách. | Đề xuất vượt quota → chặn kèm hướng dẫn quy trình mở rộng theo tier; không có nhánh "tạo vượt tạm thời" |
| BR-005 | Tenant isolation tuyệt đối: web chỉ hiển thị dữ liệu tenant mà user được gán; không bao giờ lộ dữ liệu nội bộ (giá vốn/cost, margin, P&L, tỷ giá hoạch định, health score/churn, ghi chú nội bộ AM, PII nhân sự) trên bất kỳ màn monitor nào; khách đa nhãn hàng — mỗi pháp nhân/nhãn hàng 1 tenant riêng, không chia sẻ chéo. | Truy cập tenant ngoài quyền → core từ chối ở tầng API; web nhận và hiển thị thông báo từ chối, không tự retry bằng dữ liệu cache chéo tenant |
| BR-006 | Ví read-only (REQ-FIN-017): nội dung hiển thị cho khách (số dư ví theo từng TK, chi tiêu daily, lịch nạp) web nội bộ xem ở chế độ read-only thuần — không tồn tại nút ghi số dư cho bất kỳ vai nội bộ nào; mask giá vốn hiển thị thành "điều chỉnh đối soát"; mọi download watermark (tên user + thời điểm) và log download. | Giao diện có thao tác ghi ví → coi là lỗi kiến trúc P0; download thiếu watermark/log là lỗi P1 báo SYS_ADMIN xử lý |
| BR-007 | Disclaimer độ trễ bắt buộc (BR-OPS-5.4): mọi chỉ số trên màn monitor kèm nhãn nguồn + thời điểm cập nhật + độ trễ (số dư 15 phút–24h tùy nền tảng — "số dư tham chiếu; số chính thức theo đối soát cuối ngày"; chi tiêu daily 3–24h; tiến độ/ticket/lịch nạp realtime); cấm hiển thị số dư/chi tiêu không kèm timestamp; số đang tranh chấp hiển thị "Đang đối soát" + số tham chiếu, không hiện như số chính thức. | Thiếu timestamp → component không render được số (validation ở tầng layout); số tranh chấp hiển thị như số chính thức là lỗi P1 |
| BR-008 | Monitor phản hồi ticket theo khách/tier: dữ liệu kéo từ queue hợp nhất REQ-OPS-009 (web không nhốt ticket riêng của portal); khiếu nại nghiêm trọng (khách Tier D/E, mất tiền, sai sót đối soát, đạo đức nhân viên) leo thang BOD trong 24h — OPS_PLAN điều phối, web hiển thị trạng thái escalation. | Web tự xử lý/đổi trạng thái ticket ngoài state machine của REQ-OPS-009 → bị chặn; escalation thiếu hồ sơ không cho đóng |
| BR-009 | Machine-state rule: trạng thái gate, activation, 2FA coverage, usage/quota là kết quả do core trả về; web chỉ gửi hành động hợp lệ (invite, đề xuất cấp/thu hồi, ghi root cause) và hiển thị — không tự tính, không cache quá thời gian sync cho phép, không cho phép sửa số liệu monitor. | Phát hiện web tự tính/đè machine-state → lỗi P0; giá trị hiển thị lệch core là lỗi đồng bộ, xử lý bằng re-sync chứ không sửa tay |
| BR-010 | Mọi sự kiện provisioning/milestone/escalation (tạo invite, đề xuất cấp/thu hồi CLIENT_ADMIN, xác nhận POC, ghi root cause, plan khắc phục) ghi audit log bất biến hash-chain: ai, khi nào, trên tenant nào, căn cứ gì. | Thiếu audit log cho bất kỳ hành động ghi nào → hành động không hiệu lực; đứt hash-chain là sự cố hệ thống báo CTO + BOD_CEO |
| BR-011 | Phân định touchpoint: mobile-portal là touchpoint rút gọn cho khách (số dư, thông báo, ticket) — thuộc bản SYS-MOBILE-PORTAL; web nội bộ không nhắm tới khách và không triển khai UX rút gọn thay portal; AM nhận push sự kiện qua M-INT, web là nơi xem chi tiết và thao tác. | Yêu cầu "khách dùng luôn web nội bộ" bị từ chối ở mức thiết kế — thêm kênh khách vào web nội bộ là vi phạm ranh giới biên tin cậy đối ngoại |
| BR-012 | Khách phản đối số liệu trên portal → AM khởi tạo đối soát theo quy trình REQ-FIN-004, web hiển thị trạng thái "Đang đối soát" theo machine-state của core; AM không được tự đánh "đã giải quyết" trên màn monitor mà không có kết quả đối soát tương ứng. | Trạng thái đối soát không khớp core → hiển thị theo core; đánh giải quyết tay khi chưa có kết quả là vi phạm ghi log và bị rà định kỳ |

---

## 4. Phân Quyền

Quyền do RBAC engine của core kiểm tra tại API; bảng dưới là hợp đồng UI web nội bộ. Nguyên tắc: nội bộ không ai tạo hộ user portal cho khách (CLIENT_ADMIN tự quản); không ai có action ghi số dư ví; CUSTOMER không đăng nhập web nội bộ — cột CUSTOMER liệt kê để làm rõ biên giới (khách thao tác trên PORTAL/M-PORTAL, gồm tự quản user và xem ví read-only).

| Hành động | OPS_AM | OPS_PLAN | OPS_CONT / OPS_DES / OPS_EDIT / OPS_ADS | SYS_ADMIN | CUSTOMER (qua portal) |
|-----------|--------|----------|------------------------------------------|-----------|----------------------|
| Tạo CLIENT_ADMIN đầu tiên + gửi invite (Day 1) | ✅ | ❌ | ❌ | ❌ (không tạo hộ) | ❌ |
| Đề xuất cấp/thu hồi CLIENT_ADMIN (+ xác nhận danh tính POC ≤1 ngày LV) | ✅ | ❌ (theo dõi) | ❌ | ❌ | ❌ (CLIENT_ADMIN đề xuất bên portal) |
| Xem checklist milestone Day 1/7/14/30 | ✅ (khách phụ trách) | ✅ (toàn team) | ✅ (view-only, tenant phụ trách) | ❌ | ❌ |
| Ghi root cause + kế hoạch khắc phục khi trượt gate | ✅ | ✅ (điều phối escalation) | ❌ | ❌ | ❌ |
| Xem dashboard adoption (activation, 2FA, login/tuần) | ✅ (tenant phụ trách) | ✅ (toàn team) | ✅ (view-only, tenant phụ trách) | ❌ | ❌ |
| Xem usage vs quota user theo hợp đồng | ✅ | ✅ | ❌ | ❌ | ❌ (CLIENT_ADMIN tự xem trên portal) |
| Xem monitor phản hồi ticket theo khách | ✅ | ✅ | ✅ (tenant phụ trách, view-only) | ❌ | ❌ (khách xem ticket của chính mình) |
| Tạo/sửa/xóa user portal thay khách | ❌ | ❌ | ❌ | ❌ | ✅ (CLIENT_ADMIN tự quản) |
| Xem nội dung portal read-only (ví REQ-FIN-017, chi tiêu, ticket) | ✅ | ✅ | ✅ (tenant phụ trách) | ❌ | ✅ (tenant của mình) |
| Ghi/điều chỉnh số dư ví từ màn portal | ❌ | ❌ | ❌ | ❌ | ❌ (read-only tuyệt đối) |
| Xem giá vốn/margin/P&L/ghi chú nội bộ trên màn monitor portal | ❌ | ❌ | ❌ | ❌ | ❌ (mask — "điều chỉnh đối soát") |
| Xem trạng thái "Đang đối soát" + số tham chiếu | ✅ | ✅ | ✅ (tenant phụ trách) | ❌ | ✅ (tenant của mình) |
| Xem audit log provisioning/milestone | ✅ (tenant phụ trách) | ✅ | ❌ | ❌ (chỉ vận hành hạ tầng, không xem nội dung nghiệp vụ) | ❌ |

---

## 5. Trường Hợp Đặc Biệt

- Khách đa nhãn hàng/pháp nhân: mỗi pháp nhân/nhãn hàng là 1 tenant riêng với bộ tài khoản portal riêng — web hiển thị theo từng tenant, không gộp số dư/adoption chéo tenant; AM phụ trách nhiều tenant của cùng một tập đoàn vẫn xem từng tenant riêng lẻ theo quyền gán.
- Khách EU/US chưa ký DPA: theo BR-FIN-605, cờ "khách EU/US" chưa có DPA signed thì hệ thống chặn kích hoạt dịch vụ — checklist Day 1 hiển thị trạng thái chặn kèm lý do; AM không thể gửi invite trước khi DPA được ghi nhận đã ký.
- POC khách thay đổi người giữa chừng: đề xuất thu hồi CLIENT_ADMIN cũ + cấp ADMIN mới chạy như luồng chuẩn — bắt buộc xác nhận danh tính POC mới trong 1 ngày làm việc; hai luồng có thể chạy song song nhưng không cho phép thời điểm "không còn ADMIN nào active" kéo dài quá bước xác nhận.
- Trượt gate do lỗi kỹ thuật (khách đã dùng nhưng core chưa ghi nhận — ví dụ sự kiện login mất do sync): root cause ghi loại "lỗi kỹ thuật", kế hoạch khắc phục gắn ticket hệ thống; gate chỉ được đánh lại PASSED khi core xác nhận lại dữ liệu — AM không tự đổi kết quả.
- Khách cố tình không adopting (đã có tài khoản nhưng chỉ làm việc qua Zalo/email): Day 30 feedback ghi nguyên nhân adoption thấp; AM dùng dữ liệu monitor làm căn cứ thuyết phục; nếu khách từ chối portal, escalation lên SM/OPS_PLAN ghi nhận ngoại lệ theo hợp đồng — web không có nút "miễn gate".
- Nhân viên BC phụ trách khách nghỉ việc/thay owner: dashboard hiển thị theo gán quyền hiện hành — sau handoff, AM mới thấy tenant; dữ liệu monitor không bị xóa; offboard thu hồi quyền trong 24 giờ theo BR-FIN-603.
- Quota user đầy khi khách bổ sung nhân sự mới: CLIENT_ADMIN tự gỡ user không hoạt động hoặc yêu cầu mở rộng theo tier qua ticket — AM đề xuất mở rộng; không có cơ chế "mượn slot" giữa 2 khách.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Milestone onboarding portal (gắn với cặp dự án onboarding × tenant) — machine-state do gate engine của core quyết định từ dữ liệu activation/2FA/login; web gửi hành động hợp lệ và hiển thị. Lifecycle tài khoản portal user (INVITED → ACTIVE → SUSPENDED/REVOKED) do core quản lý, liệt kê ở Tóm Tắt Entity.

**Sơ đồ trạng thái:**
```
[NOT_STARTED] ──(Day 1: invite CLIENT_ADMIN đầu tiên)──► [IN_PROGRESS]
      │                                                     │
      │                                                     │ (Day 14: đủ tiêu chí)
      │                                                     ▼
      │                                                 [PASSED] ──(Day 30 review)──► [REVIEWED]
      │                                                     │
      │                                                     │ (Day 14: trượt tiêu chí)
      │                                                     ▼
      │                                                [MISSED] ──(root cause + plan, hoàn thành khắc phục)──► [REVIEWED]
      │                                                     │
      └──(khách chưa kích hoạt gì tới hạn)──► [BLOCKED — chặn lý do: DPA chưa ký...]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `NOT_STARTED` | Gửi invite CLIENT_ADMIN đầu tiên (Day 1) | `IN_PROGRESS` | OPS_AM | Tenant đã tạo, khách hợp lệ; khách EU/US phải có DPA signed |
| `NOT_STARTED` | Ghi nhận lý do chặn | `BLOCKED` | Hệ thống (tự động) | Điều kiện chặn machine-checkable (DPA chưa ký, tenant đóng...) |
| `IN_PROGRESS` | Gate Day 14 đạt (khách tự xem được số dư + chi tiêu + ticket; ≥1 login/tuần từ ≥2 user; 2FA 100%) | `PASSED` | Hệ thống (gate engine core) | Tất cả tiêu chí machine-checkable thỏa tại thời điểm chấm gate |
| `IN_PROGRESS` | Gate Day 14 trượt | `MISSED` | Hệ thống (gate engine core) | Tự sinh escalation CS TL trong 24h |
| `MISSED` | Hoàn thành kế hoạch khắc phục + gate đạt lại | `REVIEWED` (kết quả gate ghi nhận tại thời điểm đạt) | OPS_AM ghi hồ sơ, core xác nhận | Root cause + owner + deadline đã nhập; core xác nhận tiêu chí gate thỏa |
| `PASSED` | Hoàn tất Day 30 review + feedback | `REVIEWED` | OPS_AM | Báo cáo review gửi khách; feedback ghi nhận (hình thức `[KXN-15]`) |
| `BLOCKED` | Gỡ lý do chặn | `NOT_STARTED` | Hệ thống (khi điều kiện chặn hết hiệu lực) | Điều kiện chặn được core xác nhận đã hết |

**Quy tắc:**
- Kết quả gate chỉ do gate engine của core quyết định — web không có hành động "đánh pass/fail tay" cho bất kỳ vai nào.
- `MISSED` không phải trạng thái kết thúc: phải chuyển tiếp qua khắc phục; hồ sơ trượt không có owner + deadline không được coi là đã xử lý.
- `REVIEWED` là trạng thái kết thúc của milestone — điều kiện nghiệm thu giai đoạn onboarding chỉ thỏa khi gate Day 14 đạt tại thời điểm ghi nhận.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`; entities khai báo tại core, web chỉ tiêu thụ qua API.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `tenant` | `tenant_id`, `company_name`, `tier`, `dpa_signed`, `status` | 1 tenant ↔ 1 pháp nhân/nhãn hàng | Cơ sở tenant isolation; khách đa nhãn hàng = nhiều tenant |
| `portal_account` | `account_id`, `tenant_id`, `role` (CLIENT_ADMIN/CLIENT_USER), `status` (INVITED/ACTIVE/SUSPENDED/REVOKED), `two_fa_enabled`, `last_login` | FK → `tenant.id` | Nội bộ không tạo hộ; quota theo hợp đồng (mặc định 2 ADMIN + 10 USER) |
| `portal_invite` | `invite_id`, `account_id`, `sent_by`, `sent_at`, `accepted_at`, `expires_at` | FK → `portal_account.id` | Đề xuất cấp/thu hồi CLIENT_ADMIN kèm xác nhận danh tính POC |
| `onboarding_milestone` | `milestone_id`, `project_id`, `tenant_id`, `day` (1/7/14/30), `criteria_result`, `state` (NOT_STARTED/IN_PROGRESS/PASSED/MISSED/BLOCKED/REVIEWED) | FK → project + tenant | Machine-state do gate engine core; gate Day 14 = điều kiện nghiệm thu onboarding |
| `gate_remediation` | `remediation_id`, `milestone_id`, `root_cause`, `owner`, `deadline`, `status` | FK → `onboarding_milestone.id` | Bắt buộc khi MISSED; escalation CS TL (OPS_PLAN) trong 24h |
| `adoption_metric` | `tenant_id`, `activation_rate`, `two_fa_coverage`, `logins_per_week`, `quota_used`, `quota_total`, `snapshot_at` | FK → `tenant.id` | Snapshot theo thời gian; web chỉ đọc, không sửa |
| `portal_download_log` | `log_id`, `viewer_id`, `object`, `watermark`, `downloaded_at` | FK → account/user | Bất biến; watermark tên user + thời điểm mọi download |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết được điền đầy đủ ở Phase 5 (implementation tasks); dưới đây là phác thảo sơ bộ.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Cấp CLIENT_ADMIN Day 1 (REQ-OPS-010) | Tenant đã tạo, DPA signed (nếu EU/US) | OPS_AM gửi invite CLIENT_ADMIN đầu tiên từ màn dự án | Core tạo account trạng thái INVITED, gửi invite, ghi audit log; checklist Day 1 chuyển "đã làm" | [ ] |
| SC-002: Gate Day 14 đạt (REQ-OPS-010) | ≥2 user active, 2FA 100%, khách tự xem được số dư + chi tiêu + ticket | Gate engine chấm gate tại Day 14 | Milestone chuyển PASSED, không cần thao tác tay từ web | [ ] |
| SC-003: Gate Day 14 trượt + escalation (REQ-OPS-010) | Tiêu chí gate chưa thỏa tại Day 14 | Gate chuyển MISSED | Web bắt buộc nhập root cause + owner + deadline trước khi lưu; escalation CS TL tạo trong 24h | [ ] |
| SC-004: Nội bộ không tạo hộ user (REQ-OPS-010) | Bất kỳ vai nội bộ nào | Gọi API tạo user portal trực tiếp | Core từ chối; chỉ CLIENT_ADMIN tạo được user trên portal | [ ] |
| SC-005: Không lộ dữ liệu nội bộ (REQ-FIN-017, BR-OPS-5.3) | OPS xem màn portal read-only | Kiểm tra nội dung hiển thị | Giá vốn/chiết khấu/margin/P&L không xuất hiện ở mọi vai; trường gắn giá vốn hiển thị "điều chỉnh đối soát" | [ ] |
| SC-006: Ví read-only + watermark (REQ-FIN-017) | AM xem số dư ví tenant mình | Thử thao tác ghi số dư và download báo cáo | Không tồn tại nút ghi (API từ chối mọi write); file download có watermark tên user + thời điểm và được log | [ ] |
| SC-007: Disclaimer độ trễ (BR-OPS-5.4) | Dashboard monitor hiển thị số dư/chi tiêu | Render màn hình | Mọi số kèm nhãn nguồn + timestamp + độ trễ; số tranh chấp hiển thị "Đang đối soát" + số tham chiếu | [ ] |
| SC-008: Tenant isolation (BR-OPS-5.2) | OPS chỉ được gán tenant A | Truy cập dữ liệu tenant B qua URL/API | Core từ chối ở tầng API; web hiển thị thông báo từ chối, không lộ dữ liệu | [ ] |

> **Liên kết:** SC-001→004 map REQ-OPS-010; SC-005→008 map REQ-FIN-017 + BR-OPS-5.2/5.3/5.4.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/client-portal/[screen-group].md` |
| Bản core backend của cùng REQ | `phase2-features/core-backend/client-portal/client-portal-goc-nhin-ops-cap-tai-khoan-va-monitor.md` (FEAT-CORE-CPORT-002) |
| Dữ liệu ví read-only (REQ-FIN-017) | `phase2-features/core-backend/client-portal/du-lieu-vi-read-only-cho-client-portal.md` (FEAT-CORE-CPORT-001) |
