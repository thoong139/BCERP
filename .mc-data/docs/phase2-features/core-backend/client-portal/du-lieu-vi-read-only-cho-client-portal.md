# Tính Năng: Dữ Liệu Ví Read-Only Cho Client Portal

> **Dựa trên:** REQ-FIN-017 trong `phase1-business/departments/finance/finance.md` (Phần A3, B.6 — BR-FIN-603/605); REQ-OPS-010 trong `phase1-business/departments/operations/operations.md` (B.5 — BR-OPS-5.2/5.3/5.4 — portal share model chung)
> **Phân hệ:** Tài chính — Dữ liệu ví đối ngoại, phối hợp Vận hành (SYS-CORE-BACKEND)
> **Module:** Client Portal (MOD-CLIENT-PORTAL)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `phase1-business/departments/operations/operations.md`, `policies/client-portal-minh-bach-bao-mat.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/client-portal/[screen-group].md`, `phase5-implementation/tasks/core-backend/client-portal/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID do lane fan-out của `/wf-define-features` cấp. REQ-FIN-017 fan-out ra 2 systems — bản này là bản riêng cho **SYS-CORE-BACKEND**; counterpart: SYS-PORTAL-WEB (trải nghiệm web phía khách). Trụ cột: khách tự xem số dư ví, chi tiêu daily mà không cần hỏi AM — nhưng chỉ thấy của mình. Tra `req-registry.json` để xác nhận SYS/MOD.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-CPORT-001 |
| Module | MOD-CLIENT-PORTAL (SYS-CORE-BACKEND — BCERP Core Backend, headless API/domain service; registry ghi primary module dưới SYS-PORTAL-WEB — đây là bản fan-out riêng cho core backend) |
| Yêu cầu nghiệp vụ | REQ-FIN-017 (Dữ liệu ví read-only cho Client Portal); REQ-OPS-010 (portal share model chung — ranh giới dữ liệu, disclaimer) |
| Người dùng liên quan | CUSTOMER (CLIENT_ADMIN/CLIENT_USER — xem dữ liệu tenant mình); FIN_L1 (đối soát — nguồn số chính thức); FIN_L2 (giám sát, xử lý tranh chấp); BOD_CFO_CTO (biên tin cậy đối ngoại, duyệt xuất không watermark) |
| Độ ưu tiên | Trung bình (MEDIUM · Phase3 · GĐ3) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | Sổ phụ ví & lệnh append-only (module ví — REQ-FIN-001/002/004); trạng thái đối soát; provisioning portal + milestone Day 1/7/14/30 (FEAT-CORE-CPORT-002); dữ liệu chi tiêu GW nhãn `api`/`manual` (REQ-FIN-005, degraded mode DI-007) |
| Ghi chú Expert (A7) | Expert review Phần A `finance.md` chưa thực hiện (chờ review); điểm phối hợp đã xác định: ranh giới dữ liệu Portal do FIN phối hợp customer-expert/legal-expert; dữ liệu ví khách = Restricted theo BR-FIN-603 — enforce 2 lớp RLS DB + filter API |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Là bản enforce phía core backend của trụ cột "minh bạch dữ liệu khách": cung cấp cho Client Portal một **view tổng hợp read-only đã lọc theo tenant** về dữ liệu ví — số dư theo từng TKQC, chi tiêu daily, trạng thái đối soát mức dành cho khách, lịch sử điều chỉnh ví, lịch nạp — để khách tự phục vụ thông tin thay vì hỏi AM. Portal **không bao giờ chạm DB nội bộ**: core backend chạy tenant isolation 2 lớp (RLS DB + filter `tenant_id` tầng API), mask dữ liệu nội bộ ở tầng service (không tin UI), ghi audit log bất biến mọi truy cập/download.

**Phạm vi:**
- Bao gồm: headless API domain service phục vụ PORTAL-WEB và MOBILE-PORTAL (dùng chung view — mobile chỉ touchpoint rút gọn: số dư, thông báo, ticket); tenant isolation tuyệt đối; mask giá vốn/chiết khấu/P&L/tỷ giá nội bộ/PII nhân sự ở tầng API; read-only tuyệt đối — không endpoint ghi lên ví từ phía khách; freshness metadata (nguồn + last-updated + độ trễ) gắn từng chỉ số; trạng thái "Đang đối soát" + số tham chiếu; watermark + log download; lịch sử điều chỉnh ví (mask giá vốn thành "điều chỉnh đối soát"); audit truy cập theo phân loại Restricted (BR-FIN-603); tiếp nhận DSAR (BR-FIN-605).
- Không bao gồm: UI web phía khách (SYS-PORTAL-WEB) và app mobile portal (SYS-MOBILE-PORTAL — chỉ tiêu dùng API); luồng lệnh nạp/rút/điều chỉnh + dual approval (module ví nội bộ — REQ-FIN-001/003); provisioning tài khoản + milestone onboarding (FEAT-CORE-CPORT-002); queue ticket & CSAT (REQ-OPS-009); pull dữ liệu chi tiêu 7 nền tảng (SYS-INTEGRATION-GW).

---

## 2. Luồng Người Dùng (User Stories)

Mọi story đi qua headless API của core backend; trải nghiệm hiển thị thuộc counterpart PORTAL-WEB / MOBILE-PORTAL, nhưng mọi điều kiện nghiệp vụ được enforce lại ở tầng service — không tin trạng thái do client gửi.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | CUSTOMER (CLIENT_USER) | Xem số dư ví read-only theo từng TKQC của mình kèm thời điểm cập nhật và độ trễ | Tự phục vụ thông tin dòng tiền QC, không phải hỏi AM |
| 2 | CUSTOMER (CLIENT_ADMIN) | Xem chi tiêu daily theo TK/campaign, lịch nạp (đã thực hiện + cam kết) và lịch sử điều chỉnh ví của tenant mình | Theo dõi ngân sách, đối chiếu nội bộ trước khi trao đổi với BC |
| 3 | CUSTOMER (CLIENT_ADMIN) | Xuất báo cáo PDF/xlsx có watermark tên user + thời điểm | Chia sẻ nội bộ mà vẫn truy vết được nguồn rò rỉ nếu có |
| 4 | CUSTOMER (CLIENT_USER) | Thấy nhãn "Đang đối soát" + số tham chiếu cho số chưa chốt | Không quyết định dựa trên số chưa chính thức |
| 5 | FIN_L1 | Chỉ số dư sau đối soát cuối ngày mới được gắn cờ "số chính thức" cho khách | Số tôi chốt là nguồn sự thật duy nhất — không có phiên bản số song song |
| 6 | FIN_L2 | Mọi truy cập dữ liệu Restricted (kể cả của tôi) được log bất biến, có meta-log khi xem phục vụ điều tra | Tuân thủ ma trận truy cập PDPA, chứng minh được với auditor |
| 7 | BOD_CFO_CTO | Chỉ BOD duyệt được xuất dữ liệu không watermark cho mục đích pháp lý | Biên tin cậy đối ngoại không bị phá bởi một thao tác download tùy tiện |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Đặc thù touchpoint core backend: mọi rule enforce ở tầng service/API (không tin UI), kèm audit log + tenant isolation; portal chỉ gọi qua Portal API Gateway riêng, đọc qua view tổng hợp đã lọc — không chạm DB nội bộ.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Tenant isolation 2 lớp, tuyệt đối:** mọi truy vấn bắt buộc điều kiện `tenant_id` ở cả RLS DB lẫn filter API; khách đa nhãn hàng: 1 pháp nhân/nhãn hàng = 1 tenant, không chia sẻ chéo; request không xác định được tenant → từ chối mặc định. Nguồn: REQ-FIN-017, BR-OPS-5.2, BR-FIN-603. | Từ chối + audit log bảo mật; không có cấu hình "nới lỏng" |
| BR-002 | **Read-only tuyệt đối từ phía khách:** không tồn tại endpoint ghi (nạp/rút/điều chỉnh số dư) cho vai CUSTOMER ở mọi tầng; mọi thay đổi số dư chỉ do nội bộ qua luồng policy ví (SoD + dual approval — module ví). Nguồn: REQ-FIN-017, policy `client-portal-minh-bach-bao-mat.md` §2.4. | API trả lỗi "READ_ONLY"; thử vi phạm ghi audit log bảo mật |
| BR-003 | **Ranh giới dữ liệu + mask ở tầng API:** khách THẤY: số dư theo TKQC của mình, chi tiêu daily, trạng thái đối soát mức khách, lịch sử điều chỉnh ví, lịch nạp. KHÔNG THẤY: giá vốn & chiết khấu nội bộ, P&L/biên lợi nhuận, tỷ giá nội bộ hoạch định, dữ liệu tenant khác, ghi chú nội bộ AM/vận hành, health score/churn, PII nhân sự BC. Mask thực thi ở tầng API — loại/mask trường trước khi rời service; lịch sử điều chỉnh hiển thị loại/thời điểm/số tiền, trường giá vốn mask thành "điều chỉnh đối soát". Nguồn: BR-OPS-5.3, REQ-FIN-017. | Payload có trường nhạy cảm không mask → chặn ở serialization + alert; truy xuất tenant khác → từ chối theo BR-001 |
| BR-004 | **Disclaimer độ trễ + freshness bắt buộc:** từng chỉ số kèm nhãn nguồn (`api`/`manual`), last-updated, độ trễ dự kiến: số dư 15 phút–24h tùy nền tảng; chi tiêu daily 3–24h (có thể điều chỉnh hồi tố theo timezone platform); tiến độ/ticket/lịch nạp realtime. Cấm trả payload số dư/chi tiêu thiếu timestamp. Nguồn: BR-OPS-5.4, policy §2.2. | Thiếu freshness → lỗi "MISSING_FRESHNESS"; không hiển thị số không timestamp |
| BR-005 | **Số chính thức vs tham chiếu vs đang tranh chấp:** cờ "chính thức" chỉ gắn sau khi đối soát cuối ngày chốt (nguồn sự thật FIN_L1); số chưa chốt hiển thị dạng tham chiếu kèm disclaimer; số tranh chấp trả "Đang đối soát" + số tham chiếu, không bao giờ như số chính thức. Nguồn: BR-OPS-5.4, P1-02 luồng 2 B10, policy §3. | Trả số chốt khi chưa set trạng thái → chặn ở service; FIN/khách phát hiện → khởi tạo đối soát REQ-FIN-004 |
| BR-006 | **Watermark + log download:** mọi file xuất gắn watermark tên user + thời điểm; mọi download ghi log bất biến (ai, khi nào, phạm vi); xuất không watermark (pháp lý/kiểm toán) chỉ khi có phê duyệt BOD gắn vào log. Nguồn: REQ-OPS-010 (BR-OPS-5.3), policy §2.4/§4. | Download không log được → chặn; thiếu phê duyệt → từ chối + audit log |
| BR-007 | **Restricted + mã hóa + audit truy cập:** số dư ví, lệnh nạp/hoàn, biên bản đối chiếu, dữ liệu khách trên portal = Restricted (C1/C2) — mã hóa khi lưu/truyền; mọi truy cập (kể cả FIN_L2/BOD) log bất biến hash-chain; FIN_L2 xem full chỉ phục vụ điều tra — mỗi lần xem có meta-log; offboard thu hồi quyền ≤24 giờ; review ma trận hằng quý. Nguồn: BR-FIN-603. | Ngoài ma trận không có phê duyệt BOD_CEO + meta-log → từ chối; đứt hash-chain → alert CTO + BOD_CEO |
| BR-008 | **DSAR — portal là điểm tiếp nhận:** yêu cầu quyền dữ liệu của khách cuối qua portal → ticket DSR SLA nội bộ 15 ngày làm việc trước hạn pháp lý 1 tháng (GDPR); BC = processor — chỉ xử lý theo chỉ dẫn controller; nghĩa vụ lưu trữ tiền/hợp đồng ≥10 năm ưu tiên hơn yêu cầu xóa — xóa phần kiểm soát được, ghi lý do; khách EU/US chưa ký DPA không được kích hoạt (cờ ở provisioning — FEAT-CORE-CPORT-002). Nguồn: BR-FIN-605. | Không xác minh được danh tính → từ chối + ghi lý do; quá SLA → escalation |
| BR-009 | **Breach notification:** rò rỉ/mất dữ liệu tài chính/khách → incident intake + timer 72 giờ (NĐ 13/2023, GDPR/DPA); portal là điểm phát hiện sự cố phía khách; thông báo mẫu A06; notify theo DPA khách EU/US. Nguồn: BR-FIN-604. | Quá hạn → escalation BOD_CEO/legal; không đóng incident thiếu hồ sơ |
| BR-010 | **Mobile-portal dùng chung view, touchpoint rút gọn:** MOBILE-PORTAL tiêu dùng cùng domain service, cùng RBAC + tenant isolation; phạm vi rút gọn cố định: số dư, thông báo, ticket — không mở thêm trường/dữ liệu; BR-001..008 áp dụng nguyên verbatim. Nguồn: REQ-FIN-017 (dùng chung view), Notes lane. | Endpoint mobile trả ngoài phạm vi → chặn ở scope filter; mở surface mới phải sửa spec này trước |
| BR-011 | **Degraded mode minh bạch:** khi GW không pull được API nền tảng (DI-007 — chưa có quyền Business Verification), dữ liệu cập nhật qua import/nhập tay gắn nhãn `manual`; freshness hiển thị nguồn và độ trễ tương ứng — không trình bày `manual` như realtime API. Nguồn: DI-007, BR-OPS-5.4. | Gán nhãn `api` cho dữ liệu nhập tay → chặn + audit log |
| BR-012 | **Trạng thái ví khi chậm thanh toán trung thực:** TKQC/khách bị tạm dừng chi tiêu vì chưa thanh toán → portal trả trạng thái tạm dừng + lý do mức tổng quát (không lộ ghi chú nội bộ đàm phán); mốc 15 ngày → PAUSE là đề xuất audit chờ khách hàng xác nhận `[KXN-22]` — tham số hóa, không hardcode. Nguồn: `[KXN-22]` file 10 §4, BR-OPS-5.3. | Lộ ghi chú nội bộ → vi phạm BR-003; hardcode mốc → chặn ở code review |

---

## 4. Phân Quyền

| Hành động | CUSTOMER — CLIENT_USER | CUSTOMER — CLIENT_ADMIN | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN |
|-----------|------------------------|--------------------------|--------|--------|-------------|-----------|
| Xem số dư / chi tiêu daily tenant mình (read-only) | ✅ (TK được gán) | ✅ (toàn bộ tenant) | ❌ (kênh nội bộ riêng) | ❌ (kênh nội bộ riêng) | ❌ (kênh nội bộ riêng) | ❌ |
| Xem lịch nạp + lịch sử điều chỉnh ví (mask giá vốn) | ✅ | ✅ | — (nguồn) | ✅ (nội bộ, không mask) | ✅ (tổng hợp) | ❌ |
| Xuất báo cáo có watermark | ❌ | ✅ (+OTP lớp 2) | ❌ | ❌ | ❌ | ❌ |
| Xuất không watermark (pháp lý) | ❌ | ❌ | ❌ | ❌ | ✅ (phê duyệt) | ❌ |
| Ghi số dư / tạo lệnh ví từ portal | ❌ (không tồn tại endpoint) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Gắn/thu hồi cờ "số chính thức" | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Xem audit log truy cập Restricted | ❌ | ❌ | ✅ (khách được gán) | ✅ (+meta-log khi điều tra) | ✅ | ✅ |
| Xóa/sửa audit log | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (không tồn tại — mọi vai) |
| Tạo yêu cầu DSAR / xử lý DSAR | ✅ (tạo qua portal) | ✅ (tạo qua portal) | ✅ (thực thi dữ liệu) | ✅ (xác minh + xử lý) | ✅ (oversight) | ❌ |

> Ghi chú touchpoint: CUSTOMER là đại diện 18-vai registry cho user phía khách; CLIENT_ADMIN/CLIENT_USER là hai role phụ do core backend RBAC enforce (số lượng theo hợp đồng — FEAT-CORE-CPORT-002). Trên MOBILE-PORTAL quyền thu về touchpoint rút gọn (số dư, thông báo, ticket) — không có hành động xuất/xem mở rộng.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Khách từ chối dùng portal (chỉ làm việc qua AM/email):** ghi ngoại lệ vào profile tenant; AM chịu trách nhiệm cung cấp báo cáo thay thế đúng cam kết (tính workload KPI AM); API vẫn giữ view read-only sẵn sàng — không tắt tenant isolation vì lý do này.
- **Khách yêu cầu ẩn bớt nhóm chỉ số (VD ẩn chi tiêu daily):** cấu hình hiển thị theo hợp đồng từng khách, bắt buộc xác nhận văn bản của CLIENT_ADMIN; service áp filter trước khi trả payload.
- **Khách phản đối số liệu:** AM khởi tạo đối soát theo REQ-FIN-004 → snapshot liên quan chuyển "Đang đối soát" + số tham chiếu; khách vẫn thấy số cũ kèm nhãn trạng thái, không xóa/ghi đè lịch sử.
- **GW degraded (DI-007):** dữ liệu về nhãn `manual` qua import; disclaimer hiển thị nguồn và độ trễ tương ứng — policy đã minh bạch nguồn nên không coi đây là lỗi hệ thống BC.
- **Xuất dữ liệu kiểm toán/pháp lý:** chỉ BOD phê duyệt; bản ghi phê duyệt gắn vào download log; bỏ watermark nhưng log mở rộng (mục đích, người duyệt, phạm vi).
- **Khách đa nhãn hàng tách tenant con:** mỗi pháp nhân/nhãn hàng 1 tenant riêng; không có cơ chế gộp view chéo tenant kể cả cho CLIENT_ADMIN chung — báo cáo hợp nhất làm phía hợp đồng, không ở tầng dữ liệu.
- **DSAR xóa trùng nghĩa vụ lưu trữ ≥10 năm:** xóa phần BC kiểm soát được (PII user phía khách), giữ chứng từ tiền/hợp đồng theo BR-FIN-503, ghi lý do trong ticket — không xóa trắng ledger.
- **Session bị khóa giữa phiên (5 lần sai mật khẩu):** token thu hồi ngay; API read-only tiếp theo từ chối đến khi luồng reset OTP hoàn tất.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Snapshot dữ liệu ví xuất portal (`WalletPortalSnapshot`) — trạng thái tin cậy của số liệu khách thấy. Dữ liệu nguồn (sổ phụ append-only) không đổi trạng thái qua feature này; state machine chỉ mô hình hóa nhãn tin cậy service gắn vào từng snapshot.

**Sơ đồ trạng thái:**
```
[REFERENCE] ──(đối soát cuối ngày chốt — FIN_L1)──► [FINALIZED]
     │                                                   │
     │ (lệch/khách phản đối → mở đối soát)               │ (phát hiện lệch sau chốt)
     ▼                                                   ▼
[IN_RECONCILIATION] ◄────────────────────────────── [IN_RECONCILIATION]
     │
     │ (đối soát chốt lại — FIN_L1)
     ▼
[FINALIZED]  (lịch sử REFERENCE/IN_RECONCILIATION giữ nguyên — append-only)
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `REFERENCE` | Đối soát cuối ngày chốt | `FINALIZED` | FIN_L1 (hệ thống chạy theo lịch, FIN_L1 xác nhận) | Đối trừ 3 số khớp trong dung sai: statement platform + sổ phụ + lệnh |
| `REFERENCE` / `FINALIZED` | Mở đối soát (lệch/phản đối) | `IN_RECONCILIATION` | FIN_L1 / FIN_L2 | Ticket đối soát tồn tại; cấp số tham chiếu |
| `IN_RECONCILIATION` | Chốt lại sau xử lý | `FINALIZED` | FIN_L1 | Kết quả đối soát có phê duyệt (REQ-FIN-004); snapshot mới được tạo, snapshot cũ không sửa |

**Quy tắc:**
- `IN_RECONCILIATION` là hiển thị trung thực cho khách: API trả kèm số tham chiếu, tuyệt đối không trả số này với cờ "chính thức" (BR-005).
- Snapshot append-only: không có xóa/sửa — điều chỉnh phát sinh tạo snapshot mới tham chiếu snapshot cũ (khớp audit log bất biến của policy ví).
- Trạng thái chỉ được set ở tầng service từ nguồn sự thật đối soát — client không gửi được tham số trạng thái.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL tại `technical-specs/database-design.md`; ledger nguồn và luồng lệnh ví thuộc module ví (REQ-FIN-001/003/004).*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `WalletPortalSnapshot` | `tenant_id`, `ad_account_id`, `balance`, `currency`, `trust_state` (`REFERENCE/FINALIZED/IN_RECONCILIATION`), `source` (`api/manual`), `last_updated_at`, `recon_ref` | FK → `tenants`, `ad_accounts`, `reconciliation_cases` | View tổng hợp lọc tenant — entity duy nhất portal đọc; append-only |
| `WalletLedgerEntry` (nguồn) | `tenant_id`, `ad_account_id`, `tx_type`, `amount`, `fx_snapshot`, `recon_status`, `cost_basis` (Restricted) | FK → `tenants`, `ad_accounts` | Sổ phụ append-only; `cost_basis` bị loại khỏi mọi payload portal (BR-003) |
| `PortalDownloadLog` | `tenant_id`, `user_id`, `scope`, `watermarked`, `bod_approval_ref`, `downloaded_at` | FK → `tenants`, `users` | Bất biến; `watermarked=false` bắt buộc phê duyệt BOD |
| `PortalAccessAuditLog` | `actor_id`, `role`, `action`, `entity`, `tenant_id`, `prev_hash`, `meta_ref` (meta-log điều tra) | FK → đối tượng log | Append-only + hash-chain (BR-FIN-501/603); không interface xóa/sửa |
| `FreshnessMetadata` | `metric`, `source`, `last_updated_at`, `expected_latency`, `degraded` | Gắn vào payload snapshot | Thiếu metadata → service từ chối serialize (BR-004) |
| `DsrTicket` | `tenant_id`, `request_type`, `identity_verified`, `sla_due_at`, `outcome`, `retention_override_reason` | FK → `tenants` | SLA nội bộ 15 ngày LV; giữ chứng từ ≥10 năm ghi lý do (BR-008) |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ ở Phase 2 — chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-FIN-017 (`finance.md` A3/B.6) và REQ-OPS-010 (`operations.md` B.5).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Tenant isolation chặn chéo (REQ-FIN-017) | CLIENT_USER tenant A đã đăng nhập 2FA | Gọi API ví với `tenant_id` = B | Từ chối + audit log bảo mật; không tham số nào override; test chéo hằng quý | [ ] |
| SC-002: Không endpoint ghi lên ví (REQ-FIN-017) | Khách đang xem số dư tenant mình | Gọi POST/PATCH mọi endpoint ví portal | Từ chối "READ_ONLY"; số dư không đổi; sự kiện ghi log | [ ] |
| SC-003: Mask giá vốn ở tầng API (REQ-OPS-010) | Lịch sử điều chỉnh có entry gắn giá vốn | Khách tải lịch sử điều chỉnh | Hiển thị "điều chỉnh đối soát"; bắt gói tin ở gateway không thấy giá trị gốc | [ ] |
| SC-004: Disclaimer + freshness bắt buộc (REQ-OPS-010) | Dữ liệu chi tiêu nguồn `manual` do GW degraded | Portal render chỉ số | Payload kèm nguồn + last-updated + độ trễ; thiếu metadata → "MISSING_FRESHNESS" | [ ] |
| SC-005: Số tranh chấp hiển thị đúng (REQ-OPS-010) | Snapshot ở `IN_RECONCILIATION` | Khách xem số dư | Nhãn "Đang đối soát" + số tham chiếu; không hiện như số chính thức | [ ] |
| SC-006: Watermark + log download (REQ-OPS-010) | CLIENT_ADMIN xuất báo cáo xlsx | Kiểm tra file + log | File có watermark user + thời điểm; log đủ; xuất không watermark thiếu duyệt BOD bị từ chối | [ ] |
| SC-007: Audit Restricted + meta-log (REQ-FIN-017) | FIN_L2 xem ví toàn bộ khách phục vụ điều tra | Rà audit log | Mỗi lần xem có meta-log trong hash-chain; offboard test → thu hồi quyền ≤24h | [ ] |
| SC-008: Mobile touchpoint rút gọn (REQ-FIN-017) | CLIENT_USER đăng nhập MOBILE-PORTAL | Duyệt API khả dụng | Chỉ số dư, thông báo, ticket; không có trường ngoài phạm vi; dùng chung view với web | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` (headless API portal — RLS + filter `tenant_id`, scope read-only, freshness metadata bắt buộc) |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (Portal API Gateway riêng — network zone tách biệt; chi tiêu từ GW nhãn `api`/`manual`; đối soát từ module ví FIN) |
| Màn hình UI (counterpart) | `phase4-ux/portal-web/client-portal/[screen-group].md`, `phase4-ux/mobile-portal/client-portal/[screen-group].md` |
| Policy nghiệp vụ | `policies/client-portal-minh-bach-bao-mat.md` §2.1–2.5; `policies/kiem-soat-vi-tkqc-giao-dich-tien.md` (luồng điều chỉnh số dư — nội bộ); `policies/bao-ve-du-lieu-ca-nhan.md` (Restricted/DSAR) |
| Feature liên quan cùng module | `client-portal-goc-nhin-ops-cap-tai-khoan-va-monitor.md` (FEAT-CORE-CPORT-002 — provisioning + gate Day 14) |
| Workflow tổng | `phase1-business/P1-02-business-workflow.md` (Luồng 2 — B10 minh bạch khách; handoff FIN → khách #7) |
