# Screen Group: Portal Accounts (client)

Implements: FEAT-ERP-CPORT-001 (phụ thuộc: FEAT-CORE-CPORT-002 provisioning + gate engine, FEAT-CORE-CPORT-001 ví read-only; liên kết S4 HONB, S28 Client 360)

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `cport`
> **Tính năng:** FEAT-ERP-CPORT-001 — scaffold ghi `FEAT-WEB-CPORT-001` nhưng req-registry + feature spec SYS-BCERP-WEB đều cấp `FEAT-ERP-CPORT-001` → dùng ID registry
> **Route:** `/ops/portal-accounts`
> **Main UI-ID:** `UI-WEB-PORTAL-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

---

## Thông Tin Common

| Trường | Giá trị |
|--------|--------|
| Workspace | Ops (`/ops/portal-accounts` — mục menu chỉ hiện với permission CPORT) |
| Đối tượng nghiệp vụ | Tài khoản client portal (CLIENT_ADMIN/CLIENT_USER, trạng thái INVITED→ACTIVE→SUSPENDED/REVOKED) + milestone onboarding Day 1/7/14/30 — machine-state do gate engine của core quyết định (BR-009) |
| Vai trò chính | OPS_AM — cấp CLIENT_ADMIN đầu tiên + invite Day 1, đề xuất cấp/thu hồi CLIENT_ADMIN, ghi root cause khi trượt gate |
| Workflow stage | Sau `handoff.ops_ack` (S4) → onboarding tasks ADACC/PORTAL/CAMP; gate Day 14 là điều kiện nghiệm thu giai đoạn onboarding của dự án |
| A. Object | 1 tenant (khách/pháp nhân) × {portal accounts, quota, milestone, adoption}; khách đa nhãn hàng = nhiều tenant riêng, không gộp chéo |
| B. Primary actors | OPS_AM (thao tác); OPS_PLAN (xem toàn team + điều phối escalation khi MISSED) |
| C. Related actors | OPS_CONT/DES/EDIT/ADS (view-only tenant phụ trách); CLIENT_ADMIN (tự quản CLIENT_USER bên portal); FIN (số dư ví nguồn read-only) |
| D. Lifecycle | Milestone: NOT_STARTED → IN_PROGRESS → PASSED/MISSED/BLOCKED → REVIEWED (§6 feature spec); web KHÔNG có nút đè kết quả gate |
| E. Cross-module | S4 Handoff Bridge (task PORTAL Day 1), S28 Client 360 (tab Portal account link vào đây), REQ-OPS-009 (monitor phản hồi ticket), REQ-FIN-017 (ví read-only), S25 Audit (ngoài scope vai OPS) |
| F. Information needs | Gate pass/fail từng mốc, activation rate, 2FA coverage, login/tuần, usage vs quota (mặc định 2 ADMIN + 10 USER), trạng thái invite/POC confirm, "Đang đối soát" |
| G. Decisions | Gửi invite Day 1 hay không (DPA signed?), đề xuất cấp/thu hồi CLIENT_ADMIN, nhập root cause + plan khi MISSED, đề xuất mở rộng quota theo tier |
| H. Actions được phép | POST/DELETE `/api/v1/erp/portal-accounts` (OPS_AM); PATCH task onboarding (S4); ghi root cause/plan. CẤM: tạo/sửa user portal thay khách (BR-003), ghi số dư ví (BR-006), đánh pass/fail tay (BR-001) |
| I. Exceptions | Gate MISSED (escalation CS TL ≤24h), BLOCKED do DPA chưa ký (EU/US), gần Day 14 chưa đạt ngưỡng (Day 10 <80% active), invite hết hạn, quota đầy, vượt quota chặn kèm hướng dẫn mở rộng |
| J. Cần chuyển màn hình? | Danh sách + chi tiết tenant trong 1 surface (SidePanel); thao tác ghi qua dialog; jump S4/S28/S16 khi cần context — không tách page |

**Trust boundary (bắt buộc đọc):** tài khoản được cấp tại đây quyết định khách THẤY GÌ trên portal P1–P4 (P1 Home/ví read-only, P2 campaign, P3 invoice, P4 ticket) — sai cấp nhầm tenant là lộ dữ liệu chéo khách. Ràng buộc: (1) tenant isolation tuyệt đối — web chỉ hiển thị tenant được gán, truy cập chéo bị core từ chối `TENANT_CROSS_ACCESS` (BR-005); (2) CLIENT_USER do CLIENT_ADMIN tự quản trên portal, nội bộ kể cả SYS_ADMIN không tạo hộ (BR-003, SC-004); (3) mọi dữ liệu hiển thị từ portal kèm nhãn nguồn + timestamp + độ trễ (BR-007); (4) giá vốn/margin/P&L không bao giờ xuất hiện — mask thành "điều chỉnh đối soát" (BR-006).

---

## 1. TRANG CHÍNH

### 1.1. Layout — Registry list + SidePanel chi tiết 480px (Navigation §4.5 nhóm S19; density comfortable)

```
┌──────┬──────────────────────────────────────────────────────────────────────────────────┐
│ Nav  │ Ops > Portal Accounts > [Công ty ABC TNHH]                        [Về nguồn: S4] │
│ rail ├───────────────────────────────────────────────────────────────────┬──────────────┤
│      │ Portal Accounts (client)                     [+ Cấp CLIENT_ADMIN] │ PANEL 480px  │
│      ├───────────────────────────────────────────────────────────────────│ [Tên tenant] │
│      │ [Tìm khách/tenant…]                    [Bộ lọc ▾]   [Sắp xếp ▾]   │ Gate D14:    │
│      │ Chips: (Gate trượt ·2×)(Gần Day 14 ·3×)(Chưa cấp ·5×)(DPA chặn ·1×)│ ⚠ MISSED     │
│      ├───────────────────────────────────────────────────────────────────│ Chờ OPS_PLAN │
│      │ Khách (tenant)      │Tier│Gate D14 │Active│2FA │Quota    │Đang chờ      │ escalation│
│      │ Công ty ABC TNHH    │ D  │⚠MISSED  │4/12  │100%│4/2+10   │⏱ 1 ngày 3 giờ│ ─────────── │
│      │ Nhãn hàng XYZ (MN)  │ C  │✓ PASSED │9/12  │100%│12/2+10⚠ │—             │ Tabs:       │
│      │ Công ty MNP TNHH    │ E  │…IN_PROG │3/12  │ 67%│3/2+10   │Chờ khách D10 │ [T1][T2]    │
│      │ (hàng lỗi: retry)   │    │         │      │    │         │              │ [T3][T4]    │
│      ├───────────────────────────────────────────────────────────────────│ Footer:      │
│      │ Pagination 20/50/100 · server-side · trang 1/8                     │ action chính │
└──────┴──────────────────────────────────────────────────────────────────────────────────┘
```

- **LIST theo R6:** tìm nhanh (tên khách/tenant), bộ lọc (tier, gate state, trạng thái account, AM owner), sort theo cột, pagination server-side 20/50/100. **Quick filter chips** tháo được từng chip: Gate trượt (MISSED) · Gần Day 14 chưa đạt · Chưa cấp (NOT_STARTED) · BLOCKED (DPA) · Đang đối soát. Mỗi hàng: khách (mã nghiệp vụ + tên tenant), tier, Gate Day 14 (StatusBadge machine-state), active/quota `tabular-nums`, 2FA coverage, WaitingOnIndicator ("chờ khách kích hoạt D10", "chờ OPS_PLAN escalation").
- **Bulk actions:** không có — mọi hành động gắn 1 tenant và có bước xác nhận riêng (POC, root cause); bulk cấp/thu hồi là rủi ro trust boundary.
- **Row actions:** Xem chi tiết (mở SidePanel) · Gửi lại invite (nếu EXPIRED — đề xuất re_invite, ghi audit) · Đề xuất thu hồi CLIENT_ADMIN (D2).
- **Nút chính `+ Cấp CLIENT_ADMIN`** chỉ hiện OPS_AM (PEP — ẩn với vai khác); khi tenant chưa có trong CRM hợp lệ hoặc DPA chưa ký → mở D1 và hiển thị lý do chặn ngay trong form.
- **States:** loading = skeleton 10 hàng; empty = EmptyState "Chưa có tenant nào được cấp portal — bắt đầu từ checklist Handoff" + CTA mở S4; error = hàng lỗi + retry; permission-denied = ẩn nút, không disabled.

### 1.2. Exceptions nhận biết ngay (WarningIndicator banner đầu danh sách, không dismiss)

- **Gate MISSED:** "Gate Day 14 trượt — cần ai: OPS_AM nhập root cause + plan (owner + deadline) trong 24h cho escalation CS TL (OPS_PLAN)" [Mở D3].
- **BLOCKED DPA:** "Khách EU/US chưa ký DPA — không thể gửi invite (BR-FIN-605)" — hiện trên hàng + trong D1.
- **Cảnh báo sớm Day 10** (activation <80%): chip "Gần Day 14" — dữ liệu máy từ core, không phải web tự tính.

---

## 2. TABS — 4 panel tabs trong SidePanel chi tiết (R7: mỗi tab đầy đủ)

Global context (tên tenant, tier, gate state, WaitingOn) giữ nguyên trong header panel khi chuyển tab; tab lazy-load lần đầu chọn.

### T1 `UI-WEB-PORTAL-001-T1` — Tài khoản & quota

- **Mục tiêu:** thấy toàn bộ portal account của tenant và thao tác đúng biên giới (chỉ CLIENT_ADMIN thuộc quyền nội bộ).
- **Thông tin:** bảng account — email (masked một phần), role (CLIENT_ADMIN/CLIENT_USER), trạng thái (INVITED/ACTIVE/SUSPENDED/REVOKED — StatusBadge), 2FA bật/tắt, last login (kèm timestamp — BR-007), invite: sent_by/sent_at/expires_at/accepted_at; thanh usage vs quota (2 ADMIN + 10 USER, mở rộng theo tier) — gần đầy chuyển warning.
- **Components:** DataTable (comfortable), ProgressTracker quota, StatusBadge.
- **Actions:** OPS_AM — "Cấp CLIENT_ADMIN đầu tiên" (D1, chỉ khi tenant chưa có ADMIN active), "Đề xuất cấp/thu hồi CLIENT_ADMIN" (D2, kèm xác nhận danh tính POC ≤1 ngày làm việc); với CLIENT_USER **không có nút ghi** — inline note "CLIENT_USER do CLIENT_ADMIN tự quản trên portal (BR-003)"; invite EXPIRED → "Gửi lại invite".
- **States/permissions:** OPS_AM thao tác; OPS_PLAN + OPS khác read-only; hết ADMIN active kéo dài quá bước xác nhận POC → banner cảnh báo.
- **Quan hệ tab khác:** quota dùng chung nguồn T3; hành động ghi audit → T4.

### T2 `UI-WEB-PORTAL-001-T2` — Milestone Day 1/7/14/30

- **Mục tiêu:** theo dõi gate onboarding theo machine-state, xử lý đúng quy trình khi trượt.
- **Thông tin:** ProgressTracker 4 mốc Day 1/7/14/30 — mỗi mốc: pass/fail/chưa đánh giá + tiêu chí machine-checkable (Day 7: ≥80% active + 2FA 100%; Day 14: khách tự xem được số dư + chi tiêu + ticket, ≥1 login/tuần từ ≥2 user); trạng thái milestone (NOT_STARTED/IN_PROGRESS/PASSED/MISSED/BLOCKED/REVIEWED); BLOCKED hiển thị lý do (DPA chưa ký…); hồ sơ `gate_remediation` nếu MISSED (root cause, owner, deadline, status).
- **Actions:** MISSED → "Nhập root cause + kế hoạch khắc phục" (D3 — 3 trường bắt buộc, thiếu không cho submit; escalation CS TL tự sinh ≤24h); link "Task PORTAL trên Handoff #…" mở S4 (API-ERP-019); Day 30 review + feedback (hình thức `[KXN-15]` tham số hóa). **Không có nút đánh pass/fail tay** (BR-001) — mốc thiếu dữ liệu hiển thị "Chưa đánh giá được".
- **States:** OPS_AM ghi hồ sơ; OPS_PLAN xem + điều phối; gate chỉ đánh lại PASSED khi core xác nhận lại dữ liệu.

### T3 `UI-WEB-PORTAL-001-T3` — Adoption & portal read-only

- **Mục tiêu:** monitor adoption + hỗ trợ khách bằng đúng nguồn số khách đang thấy.
- **Thông tin:** KPI adoption (activation rate, 2FA coverage, login/tuần, user thực tế vs quota) — mỗi số kèm nhãn nguồn + timestamp + độ trễ (BR-007); monitor phản hồi ticket theo tenant (kéo từ queue hợp nhất REQ-OPS-009 — read-only, jump S16); trạng thái "Đang đối soát" + số tham chiếu khi khách phản đối số liệu (không hiện như số chính thức).
- **Actions:** "Xem đúng nội dung khách thấy" → mở Sheet S1 (ví read-only, chi tiêu daily — mask "điều chỉnh đối soát", watermark download); "Mở Tickets" jump S16. **Không có nút ghi số dư bất kỳ vai nào** (BR-006 — lỗi kiến trúc P0 nếu xuất hiện).
- **Permissions:** OPS_AM/OPS_PLAN xem; OPS_CONT/DES/EDIT/ADS view-only tenant phụ trách; SYS_ADMIN ❌.

### T4 `UI-WEB-PORTAL-001-T4` — Hoạt động & audit

- **Mục tiêu:** vết audit bất biến cho mọi sự kiện provisioning/milestone/escalation (BR-010).
- **Thông tin:** Timeline per object (API-CORE-030): tạo invite, đề xuất cấp/thu hồi + POC confirm, ghi root cause, plan khắc phục — ai/khi nào/tenant/căn cứ; hash-chain integrity indicator.
- **Actions:** read-only; truy vết sâu hơn jump S25 Audit Log Query (OPS_AM không có quyền query toàn cục — chỉ thấy timeline object mình sở hữu).
- **States:** loading skeleton 3 dòng; empty "Chưa có hoạt động".

---

## 3. DIALOGS

### D1 `UI-WEB-PORTAL-001-D1` — Cấp CLIENT_ADMIN đầu tiên + gửi invite (Day 1)

Modal 960px (form container chuẩn). Trường: khách/tenant (combobox search từ khách CRM — picker nguồn `[NEEDS_REVIEW: thiếu GET /api/v1/erp/customers list]`), POC khách (tên + chức danh), email invite, hạn invite; hiển thị kiểm tra tự động: DPA signed (EU/US — chặn kèm lý do), tenant hợp lệ, quota ADMIN còn suất. Submit → POST `API-ERP-055` → account trạng thái INVITED + audit log; checklist Day 1 (S4) chuyển "đã làm". Confirm có ngữ cảnh: "Bạn đang cấp quyền quản trị portal cho khách {tenant} — khách sẽ thấy P1–P4 của tenant này".

### D2 `UI-WEB-PORTAL-001-D2` — Đề xuất cấp/thu hồi CLIENT_ADMIN + xác nhận danh tính POC

Modal: hành động (cấp mới/thu hồi), account đích, lý do; hệ thống mở bước "xác nhận danh tính POC trong 1 ngày làm việc" — trạng thái chờ hiển thị ở T1; không có xác nhận POC → không hiệu lực (BR-003). Thu hồi → DELETE `API-ERP-055`. Chặn "không còn ADMIN nào active" kéo dài quá bước xác nhận (banner). Vượt quota → chặn kèm hướng dẫn mở rộng theo tier (không có nhánh "tạo vượt tạm thời").

### D3 `UI-WEB-PORTAL-001-D3` — Root cause + kế hoạch khắc phục (khi MISSED)

Modal: root cause (select: khách chậm/lỗi kỹ thuật/khác + mô tả), owner (AssigneePicker trong scope), deadline (date); 3 trường bắt buộc — thiếu không cho submit (BR-002). Lỗi kỹ thuật → gắn ticket hệ thống. Endpoint ghi hồ sơ `[NEEDS_REVIEW: thiếu endpoint POST gate_remediation / milestone root-cause — hiện chỉ có API-ERP-056 đọc usage]`.

---

## 4. SHEETS

### S1 `UI-WEB-PORTAL-001-S1` — Portal read-only preview (nhìn bằng mắt khách)

SidePanel 720px: nội dung portal tenant đang thấy — số dư ví theo TKQC (per-currency, không quy đổi), chi tiêu daily, lịch nạp, tiến độ campaign, ticket — **thuần read-only, không nút ghi**; mọi số kèm nhãn nguồn + timestamp + độ trễ ("số dư tham chiếu 15 phút–24h; số chính thức theo đối soát cuối ngày" — BR-007); giá vốn hiển thị "điều chỉnh đối soát"; download watermark (tên user + thời điểm) + log. Đóng bằng Esc, trả focus về T3.

---

## 5. VIEW MODES

N/A — mọi thao tác ghi là dialog (D1–D3) và xem sâu là panel tabs (T1–T4) trên cùng registry surface; không có mode Create/View/Edit/Approve riêng vì hành động ghi ở đây chỉ có 3 loại đóng gói sẵn, đều cần confirm ngữ cảnh riêng.

---

## 6. API ENDPOINTS

> Endpoint THẬT từ `api-contract.md`; pagination server-side `page/limit` (20/50/100, max 100).

| Nút/Tab | Endpoint | Method | Quyền | Ghi chú |
|---|---|---|---|---|
| Danh sách tenant + gate/quota | `[NEEDS_REVIEW: thiếu GET /api/v1/erp/portal-accounts (list tenant + milestone + quota) — hiện chỉ có POST/DELETE (API-ERP-055) và usage per customer (API-ERP-056)]` | GET | OPS_AM/OPS_PLAN | Filter `tier,gate_state,status,owner_id,search`; sort `gate_day14,created_at` |
| T1 Tài khoản & quota | `/api/v1/erp/portal-accounts/{customerId}/usage` (API-ERP-056) | GET | OPS_AM (OPS_PLAN toàn team, OPS khác tenant phụ trách) | adoption_metric + usage/quota; snapshot_at kèm timestamp |
| D1 Cấp / D2 thu hồi CLIENT_ADMIN | `/api/v1/erp/portal-accounts` (API-ERP-055) | POST / DELETE | OPS_AM | Phát lệnh sang SYS-PORTAL-WEB; idempotent; audit hash-chain (BR-010) |
| T2 Task PORTAL Day 1 | `/api/v1/erp/handoffs/{id}/onboarding-tasks[/{taskId}]` (API-ERP-019) + `/api/v1/erp/handoffs`, `/handoffs/{id}` (API-ERP-016) | GET / PATCH | OPS_AM/OPS_CONT | Checklist Day 1/7/14/30; PATCH task PORTAL; link S4 |
| D3 Root cause/plan | `[NEEDS_REVIEW: thiếu endpoint onboarding_milestone + gate_remediation (đọc machine-state + ghi root cause/owner/deadline)]` | GET/POST | OPS_AM ghi, OPS_PLAN xem | Gate chấm bởi core — web chỉ ghi hồ sơ |
| T3 Monitor ticket | `/api/v1/erp/tickets` (API-ERP-058) | GET | OPS | Filter `customer_id,status` — read-only trong tab này |
| T4 Audit timeline | `/core/audit/objects/:objectId/timeline` (API-CORE-030) | GET | Owner object + SYS_ADMIN | Feed provisioning/milestone events |
| S1 Portal preview | `[NEEDS_REVIEW: thiếu endpoint nội bộ đọc portal read-model theo tenant — hiện chỉ có publish service-to-service /internal/erp/portal-read-model/publish]` | GET | OPS_AM/OPS_PLAN/OPS khác | Mask + freshness bắt buộc |
| Hoạt động đăng nhập chi tiết | `[NEEDS_REVIEW: thiếu endpoint đọc portal login activity per account (portal_access_log) — nội bộ chỉ có aggregate logins_per_week (API-ERP-056)]` | GET | — | |

Lưu ý biên giới: reset mật khẩu/MFA **không nằm trên màn này** — khách tự phục vụ qua portal (OTP: API-PORTAL-005/006/009/010; CLIENT_ADMIN unlock/re_invite qua API-PORTAL-015). Nội bộ chỉ thấy trạng thái 2FA/LOCKED và hướng dẫn khách (BR-003, SC-004).

---

## 7. UI-ID Registry

| UI-ID | Thành phần | Loại | Ghi chú |
|---|---|---|---|
| `UI-WEB-PORTAL-001` | Registry list tenant portal | list | Route `/ops/portal-accounts`, Pattern registry + SidePanel |
| `UI-WEB-PORTAL-001-T1` | Tab Tài khoản & quota | detail-tab | Actions: D1, D2, re_invite |
| `UI-WEB-PORTAL-001-T2` | Tab Milestone Day 1/7/14/30 | detail-tab | Machine-state; action D3 |
| `UI-WEB-PORTAL-001-T3` | Tab Adoption & portal read-only | detail-tab | Mở S1; jump S16 |
| `UI-WEB-PORTAL-001-T4` | Tab Hoạt động & audit | detail-tab | API-CORE-030; jump S25 |
| `UI-WEB-PORTAL-001-D1` | Dialog cấp CLIENT_ADMIN đầu tiên + invite | form-dialog | POST API-ERP-055 |
| `UI-WEB-PORTAL-001-D2` | Dialog đề xuất cấp/thu hồi + POC confirm | form-dialog | POST/DELETE API-ERP-055 |
| `UI-WEB-PORTAL-001-D3` | Dialog root cause + plan khắc phục | form-dialog | `[NEEDS_REVIEW]` endpoint |
| `UI-WEB-PORTAL-001-S1` | Sheet portal read-only preview | sheet-720 | Read-only tuyệt đối + watermark |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../../phase2-features/bcerp-web/client-portal/client-portal-goc-nhin-ops-cap-tai-khoan-va-monitor.md` | Upstream (FEAT-ERP-CPORT-001) |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system | `../../../design-system.md` | Upstream |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | Upstream (S19) |
| Handoff Bridge (task onboarding) | `../honb/screens-handoff-bridge.md` | S4 — checklist Day 1 |
| Client 360 (tab Portal account) | `../../sales/crm/screens-client-360.md` | S28 — hub liên kết |
