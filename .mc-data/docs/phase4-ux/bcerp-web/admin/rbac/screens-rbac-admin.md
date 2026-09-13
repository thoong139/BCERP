# Screen Group: RBAC Admin

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `rbac`
> **Tính năng:** FEAT-ERP-RBAC-001, FEAT-ERP-RBAC-003, FEAT-ERP-RBAC-005 (liên quan FEAT-ERP-RBAC-004, 006)
> **Route:** `/admin/rbac`
> **Main UI-ID:** `UI-WEB-RBAC-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

**Implements:** FEAT-ERP-RBAC-005 (nền tảng RBAC & SSO/MFA tập trung — users, 19 vai registry, đăng ký MFA TOTP, chính sách phiên theo tier), FEAT-ERP-RBAC-003 (quarterly access review — campaign, ký CEO, lệnh thực thi, offboarding checklist, cảnh báo rotate T-7), FEAT-ERP-RBAC-001 (compensating control kiêm nhiệm CFO/CTO — cờ SoD, khu review quyền BOD_CFO_CTO, truy cập khẩn T3/T4). Liên quan: FEAT-ERP-RBAC-004 (tham số quản trị — thuộc tab "Tham số" của S27), FEAT-ERP-RBAC-006 (mask rule PII — cấu hình tại T4).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| Workspace | Platform Admin (`/admin/*`) — landing mặc định của SYS_ADMIN |
| Đối tượng nghiệp vụ | `user_account` (lifecycle CREATED → PROBATION → ACTIVE → SUSPENDED/OFFBOARDING → DEACTIVATED), `role_binding` (19 vai × Level × data scope C1/C2/C3/T1–T4, SCD2 effective-dated), `provisioning_order` (gán/thu hồi chỉ thực thi sau duyệt CEO), `access_review_cycle` (kỳ quý ngày 1–10), `sod_conflict_flag`, `mfa_enrollment`, `session_policy` |
| Vai trò chính | SYS_ADMIN (vận hành: đề xuất, thực thi lệnh sau duyệt) · BOD_CEO (duyệt gán/thu hồi vai — độc quyền; ký quarterly review — không ủy quyền) · BOD_CFO_CTO (đề xuất thay đổi; xuất nộp quyền của mình vào khu review riêng) |
| Workflow stage | User: `CREATED → PROBATION → ACTIVE → OFFBOARDING → DEACTIVATED` (+`SUSPENDED` khi vi phạm/không review 2 quý). Kỳ review: `NOT_STARTED → OPENED → IN_REVIEW → CEO_SIGNED → EXECUTED → CLOSED`, nhánh `OVERDUE` khi quá ngày 10 |
| Liên quan | S25 Audit Log (mọi thao tác tại đây bị log WORM — link trail từng user); S27 Integration & Settings (vault credential, tham số); S6 Approval Inbox (giao dịch CFO khởi tạo khóa `LOCKED_PENDING_CEO`); Alert Center (escalation review quá hạn) |

**Checklist workflow (Bước 0):** A. Quản trị danh tính + phân quyền tập trung — quyền chỉ tồn tại khi còn được kiểm chứng định kỳ. B. Primary actors: SYS_ADMIN vận hành, BOD_CEO quyết, BOD_CFO_CTO đề xuất/bị review. C. Related: HR phát lệnh thử việc→chính thức, CTO xác nhận offboarding checklist. D. Hai máy trạng thái (user, kỳ review) do CORE trả về — web không suy diễn. E. Cross-module: PDP check tập trung (web cấm check cục bộ), audit hash-chain, GW inventory credentials, Alert Center. F. Thông tin cần: vai × level × data scope, trạng thái lifecycle + MFA, kỳ review còn bao nhiêu ngày, lệnh chờ CEO, cờ SoD. G. Quyết định: đề xuất grant/revoke (lý do bắt buộc), duyệt (CEO), đánh dấu giữ/thu hồi + ký (CEO), thực thi (SYS_ADMIN). H. Actions: tạo user, transition trạng thái, revoke session `[STEP-UP]`, reset MFA, ký review `[STEP-UP]`, mở truy cập khẩn. I. Exceptions: SoD xung đột, kiêm nhiệm CFO+CTO, quyền `SUSPENDED` 2 quý không review, guest quá 90 ngày, offboarding lệch SLA 24h, session policy tier cao. J. Không chuyển màn — mọi thao tác trên 1 surface registry, chi tiết qua SidePanel.

[NEEDS_REVIEW: Navigation §3 hiện liệt kê route `/admin/rbac` chỉ cho SYS_ADMIN — cần bổ sung BOD_CEO (duyệt vai + ký review) và BOD_CFO_CTO (khu xuất nộp) vào cột "Roles thấy" theo FEAT-ERP-RBAC-003/005 §4; badge `{access_review_due}` hiển thị khi kỳ đang mở/quá hạn hoặc có lệnh chờ duyệt]

---

## 1. TRANG CHÍNH

### 1.1. Layout — Registry/Admin (bảng standard + SidePanel 480px, density comfortable, form cấu hình 960px)

```
┌────────────────────────────────────────────────────────────────────────────────────────────┐
│ Platform Admin > RBAC Admin     Kỳ Q3/2026: OPENED — còn 6/10 ngày   [+ Đề xuất thay đổi] │
├────────────────────────────────────────────────────────────────────────────────────────────┤
│ Users ·142 │ Vai & Phân quyền ·19 │ Access Review Q3 ·49 chờ │ Xác thực & Chính sách phiên │
├────────────────────────────────────────────────────────────────────────────────────────────┤
│ ⚠ Kỳ review Q3 đang mở: 118/167 dòng đã quyết · CEO CHƯA KÝ · 2 lệnh chờ CEO duyệt         │
│   (ngày 11 → OVERDUE tự escalate Alert Center — quyền không ký 2 quý tự SUSPENDED)         │
│ Chips: (Chờ CEO duyệt ·2 ×) (SUSPENDED ·3 ×) (Thử việc ·5 ×) (SoD xung đột ·1 ×) (Guest ×) │
│ [Tìm người / mã NV____]  [Phòng ▾] [Trạng thái ▾] [Vai ▾]                    [Sắp xếp ▾]   │
├────────────────────────────────────────────────────────────────────────────────────────────┤
│ NV-0042 · Trần Thị B · Tài chính   FIN_L1 · C2 · MFA ✓ · Review Q2: Giữ            ACTIVE │
│ NV-0107 · Lê Văn C · Kinh doanh    SALES_L1 · C1 · MFA ✗ chưa đăng ký        [PROBATION]  │
│           → thử việc: mọi quyền phê duyệt bị khóa theo lifecycle                           │
│ NV-0011 · Phạm Thị D · BOD         CFO + CTO ● KIÊM NHIỆM — compensating control,        │
│           tách khu review; giao dịch tiền do người này tạo → khóa chờ CEO (S6)     ACTIVE │
│ NV-0089 · Guest · Đối tác QC       Guest · hết hạn 12/10/2026 (còn 29/90 ngày)  [ACTIVE] │
├────────────────────────────────────────────────────────────────────────────────────────────┤
│ Phân trang 20/50/100 (server-side)                                          Tổng: 142 users│
└────────────────────────────────────────────────────────────────────────────────────────────┘
                          click hàng → SidePanel 480px đẩy content (S1)
```

**Loading/Empty/Error:** loading = skeleton 10 hàng; empty = EmptyState "Không có user khớp bộ lọc" + chip tháo lọc; error = khối lỗi + retry. Lỗi SoD/đủ duyệt là lỗi nghiệp vụ — toast không tự đóng.

### 1.2. Components

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| DataTable (§4.1) | variant standard, row 40px comfortable, saved-views | Cột trạng thái 120px; sort theo click header |
| WarningIndicator banner (§4.3) | persistent — trạng thái kỳ review | "Chuyện gì — ai làm gì — hạn còn lại"; không dismiss khi kỳ đang mở |
| Quick chips | tháo được từng chip | Nguồn filter server-side (`status`, `sod_flag`, `mfa_state`) |
| StatusBadge (§4.2) | token §1 — xem bảng badge 1.3 | 1 badge/hàng cho lifecycle; MFA/review là cột riêng |
| WaitingOnIndicator (§4.11) | chip "chờ CEO duyệt 2 ngày 4 giờ" | Dòng lệnh grant/revoke chờ duyệt; `sla-breach` khi kỳ quá ngày 10 |
| SidePanel (§4.5) | 480px đẩy content, footer sticky | Hồ sơ user — xem §4 |

### 1.3. Cột bảng Users

| Tên | Trường | Định dạng | Sắp xếp | Rộng |
|-----|--------|----------|---------|------|
| Người dùng | `employee_code`, `full_name` | Mã NV + tên | Có | auto |
| Phòng ban | `dept` | Text | Có | 120px |
| Vai · Level · Scope | `role_binding.role/level/data_scope` | Text + tooltip chi tiết (SCD2 hiệu lực theo ngày) | Có | 200px |
| Trạng thái | `account_state` | Badge | Có | 120px |
| MFA | `mfa_state` | ✓ registered / ✗ chưa (icon `shield-mfa` + chữ) | Không | 80px |
| Review gần nhất | `access_review_line.decision` | Giữ / Thu hồi / Chưa (qúy) | Có | 120px |
| Cờ SoD | `sod_conflict_flag` | Chip xung đột khi có (click → chi tiết cặp vai) | Không | 120px |
| Hành động | — | Row menu `⋯` | — | 48px |

**Badge trạng thái tài khoản:** `CREATED` = Nháp (`--state-draft`) · `PROBATION` = Info (`--state-info`) · `ACTIVE` = Đã duyệt (`--state-approved`) · `OFFBOARDING` = Chờ (`--state-pending`) · `SUSPENDED`/`LOCKED` = Quá hạn (`--state-overdue`) · `DEACTIVATED` = muted (kết thúc — không tái kích hoạt).

### 1.4. Hành Động Chính

| Sự kiện | Hành động | Kết quả |
|---------|---------|--------|
| Nhấn "+ Đề xuất thay đổi" | Mở D1 (đề xuất gán/thu hồi vai / tạo user) | Preflight SoD (API-CORE-022) chạy trước khi gửi; thiếu lý do → không cho submit |
| Click hàng | Mở SidePanel S1 (hồ sơ user) | Giữ context danh sách |
| Row menu → "Chuyển trạng thái" | Mở D2 | Transition lifecycle có điều kiện (API-CORE-013) |
| Row menu → "Thu hồi mọi session" | Confirm + MFA step-up | API-CORE-050 `[STEP-UP]` — nghi ngờ compromise |
| Row menu → "Reset MFA" | Mở D3 | Reset có lý do + log; không có đường bỏ MFA vĩnh viễn |
| Chip "Chờ CEO duyệt ·2" (với BOD_CEO) | Lọc hàng đợi lệnh chờ duyệt | Duyệt/từ chối qua D4 |
| Click chip SoD xung đột | Mở chi tiết cặp xung đột | Kiến nghị tách luồng duyệt; cặp tiền báo thống kê SoD cho CFO |

### 1.5. Phân Quyền (PEP — thiếu quyền thì ẩn, không disabled)

| Thành phần | SYS_ADMIN | BOD_CEO | BOD_CFO_CTO | Vai khác |
|-----------|-----------|---------|-------------|----------|
| Xem users + chi tiết | ✅ | ✅ | ✅ | ◐ phạm vi nhóm mình |
| Tạo user / chuyển trạng thái | ✅ (theo lệnh đã duyệt) | ❌ | ❌ | ❌ |
| Thu hồi mọi session `[STEP-UP]` | ✅ | ❌ | ❌ | ❌ |
| Xem lương/cost trong hồ sơ (Restricted) | ❌ (masked — không nút bỏ mask) | ✅ | ✅ | ❌ |
| Đề xuất gán/thu hồi vai | ✅ | ❌ (CEO không đề xuất) | ✅ | ❌ |
| Duyệt gán/thu hồi vai (D4) | ❌ | ✅ độc quyền | ❌ | ❌ |
| Đánh dấu giữ/thu hồi + ký review | ❌ | ✅ (không ủy quyền) | ❌ | ❌ |
| Thực thi lệnh sau duyệt | ✅ (mọi thao tác log) | ❌ | ❌ | ❌ |
| Quản trị cấu hình realm Keycloak / session policy | ◐ thực thi change CTO duyệt | ❌ | ✅ (MFA bắt buộc) | ❌ |
| Mở truy cập khẩn T3/T4 + khai lý do 24h | ❌ | ◐ nhận alert | ✅ | ❌ |

---

## 2. TABS (global context — banner kỳ review + người dùng giữ nguyên khi chuyển tab)

| Tab | UI-ID | Nội dung | Hiện với vai |
|-----|-------|---------|--------------|
| Users | `UI-WEB-RBAC-001-T1` | Danh sách + lifecycle + MFA + session (§1) | SYS_ADMIN, BOD (view) |
| Vai & Phân quyền | `UI-WEB-RBAC-001-T2` | 19 vai registry, ma trận Role×Permission×Scope, bản đồ SoD | CEO/CFO toàn bộ; SYS_ADMIN phần kỹ thuật |
| Access Review | `UI-WEB-RBAC-001-T3` | Kỳ quý: bảng dòng review, ký CEO, lệnh thực thi, offboarding, rotate T-7 | CEO (quyết + ký), CFO (khu riêng), SYS_ADMIN (thực thi) |
| Xác thực & Chính sách phiên | `UI-WEB-RBAC-001-T4` | SSO 2 realms, MFA enrollment, session policy theo tier, mask PII, break-glass | CFO (quản trị), SYS_ADMIN (thực thi) |

**R7 tab completeness:**

- **T1 Users:** mục tiêu — quản lý lifecycle tài khoản đúng ràng buộc (thử việc không có quyền duyệt, guest ≤90 ngày, offboarding thu hồi ≤24h). Thông tin: định danh + phòng, binding vai hiệu lực theo ngày, MFA state, session active, review history. Components: DataTable + SidePanel S1 + chips. Actions: tạo user (khởi điểm `PROBATION`), transition (D2), revoke-all session `[STEP-UP]`, reset MFA (D3). States: loading/empty/error §1.1; guest ngày 90 tự khóa — hiển thị cảnh báo còn <7 ngày. Permissions: §1.5. Quan hệ: grant vai thực hiện từ T2/T3; trail thao tác → S25 (API-CORE-030 object=user).
- **T2 Vai & Phân quyền:** mục tiêu — hiển thị và đề xuất thay đổi phân quyền, thực thi sau duyệt CEO; KHÔNG thêm vai cục bộ (DI-006: registry 19 vai cố định, vai mới phải qua quyết định stakeholder). Thông tin: danh mục 19 vai (API-CORE-015), ma trận vai × permission × dept × data-scope (read-only), danh sách binding từng vai + `effective_from/to` (SCD2), cờ xung đột SoD + `combined_role` (CFO+CTO). Components: bảng ma trận + panel chi tiết vai. Actions: đề xuất sửa permission set (API-CORE-016 — SYS_ADMIN đề xuất → CEO duyệt), preflight SoD khi soạn gán. States: vai mở rộng SALES_L4/L5, OPS_DES/EDIT/ADS đánh dấu [NEEDS_REVIEW #8] — ẩn hành động cho tới khi BOD chốt. Quan hệ: duyệt tại T3 khu "Chờ CEO duyệt"; snapshot vai của kỳ review lấy từ tab này.
- **T3 Access Review:** mục tiêu — chốt phân quyền toàn công ty trong 10 ngày đầu quý trên một màn hình; quyền không được review 2 quý liên tiếp tự vô hiệu. Thông tin: trạng thái kỳ (`OPENED/IN_REVIEW/OVERDUE/CEO_SIGNED/EXECUTED/CLOSED`), bảng dòng review (user × role × level × scope × credential — API-CORE-025, filter dept/role/đặc quyền nhạy cảm), KHU RIÊNG quyền BOD_CFO_CTO gắn cờ "bị review — xuất nộp bởi chính người bị review" (compensating control REQ-BOD-002 — thiếu khu này không đạt điều kiện mở ký), hàng đợi lệnh thực thi SYS_ADMIN (1 lệnh ↔ 1 dòng đã duyệt), checklist offboarding (SLA 24h, điểm xác nhận CTO, lệch chuẩn ghi vào kỳ), cảnh báo credential rotate T-7 (từ inventory GW). Components: bảng review + ApprovalCard-style dòng quyết định + ProgressTracker trạng thái kỳ. Actions: CEO đánh dấu giữ/thu hồi từng dòng (thu hồi bắt buộc reason code — API-CORE-026 `[STEP-UP]` với đặc quyền nhạy cảm), ký (D5), SYS_ADMIN thực thi rồi đóng campaign (API-CORE-027 — SYS_ADMIN đóng, CEO xác nhận). States: hết ngày 10 → banner `OVERDUE` + escalate Alert Center; quyền `SUSPENDED` hiển thị nguyên nhân + đường khôi phục sau review. Permissions: đánh dấu/ký chỉ CEO; CFO chỉ thao tác khu của mình. Quan hệ: lệnh sau duyệt tạo binding mới ở T1/T2; bằng chứng ký đóng gói vào WORM (cùng đường API-CORE-031).
- **T4 Xác thực & Chính sách phiên:** mục tiêu — một điểm cấu hình xác thực tập trung, không phân hệ nào tự dựng SSO riêng. Thông tin: trạng thái 2 realm Keycloak (nội bộ MFA TOTP bắt buộc / portal OTP — chỉ trạng thái + policy, không plaintext credential), danh sách user chưa đăng ký MFA (vai tài chính/BOD/SYS_ADMIN bị chặn thao tác đến khi enroll xong — `MFA_ENROLLMENT_REQUIRED`), session policy theo tier dữ liệu (T1–T4: session TTL, refresh TTL, step-up bắt buộc tier cao — không "ghi nhớ máy"), mask rule PII theo vai (API-CORE-033/034 — SYS_ADMIN quản trị, HR_L2 đồng duyệt với PII lương), yêu cầu break-glass T3/T4 (mở có giờ, alert CEO ngay, khai lý do trong 24h, tự đóng khi hết hạn). Components: form cấu hình container 960px + bảng enrollment. Actions: chỉnh policy (CFO — sau duyệt SYS_ADMIN áp), reset MFA (D3), mở break-glass (D6). States: thiếu MFA → khối cảnh báo; [NEEDS_REVIEW: chưa có endpoint GET/PUT session_policy và cấu hình realm trong api-contract — entity session_policy tồn tại ở feature spec]. Quan hệ: step-up dùng chung API-CORE-003 cho mọi surface tiền/vault/policy.

---

## 3. DIALOGS

| # | Dialog | UI-ID | Loại | Mở khi nào |
|---|--------|-------|------|-----------|
| 1 | Đề xuất gán/thu hồi vai | `UI-WEB-RBAC-001-D1` | Form + preflight | "+ Đề xuất thay đổi" / row menu T1 |
| 2 | Chuyển trạng thái tài khoản | `UI-WEB-RBAC-001-D2` | Confirm | Row menu → Chuyển trạng thái |
| 3 | Reset MFA | `UI-WEB-RBAC-001-D3` | Form lý do | Row menu → Reset MFA |
| 4 | CEO duyệt/từ chối vai | `UI-WEB-RBAC-001-D4` | Approve (MFA step-up) | Hàng đợi "Chờ CEO duyệt" (T3) |
| 5 | Ký quarterly review | `UI-WEB-RBAC-001-D5` | Confirm ký (MFA step-up) | T3 — mọi dòng đã có quyết định |
| 6 | Truy cập khẩn T3/T4 (break-glass) | `UI-WEB-RBAC-001-D6` | Form có giờ | T4 — sự cố cần quyền Restricted |

### 3.1. Dialog Đề xuất gán/thu hồi vai (D1)
**Loại:** Form. Fields: người dùng (combobox theo data-scope), hành động (grant/revoke), vai (chỉ 19 vai registry — vai ngoài không có trong dropdown), lý do (bắt buộc — BR: "mỗi thao tác có actor + timestamp + lý do"). Khi mở: gọi `POST /core/pdp/sod-check` — có xung đột → chặn gán cặp vai cấm cùng luồng hoặc hiển thị cảnh báo `combined_role` + buộc tách luồng duyệt. Submit → tạo provisioning order `PENDING_CEO_APPROVAL`; SYS_ADMIN không thể tự thực thi (backend từ chối — `SOD_VIOLATION`/409 khi cố gán trực tiếp).

### 3.2. Dialog Chuyển trạng thái tài khoản (D2)
**Loại:** Confirm có ngữ cảnh. Hiển thị máy trạng thái hiện tại → đích, hệ quả (thử việc→chính thức mở quyền theo SCD2; offboarding → kích hoạt checklist 24h: thu hồi vai + revoke session + rotate credential ≤24h, xác nhận CTO). `DEACTIVATED` là trạng thái kết thúc — không có đường tái kích hoạt (quay lại làm việc = tài khoản mới, lịch sử SCD2 giữ nguyên).

### 3.3. Dialog Reset MFA (D3)
**Loại:** Form lý do bắt buộc sau xác minh danh tính. Reset ghi log; sau reset user bắt buộc đăng ký lại TOTP (API-CORE-004) trước khi vào chức năng nội bộ — không tồn tại "bỏ MFA vĩnh viễn".

### 3.4. Dialog CEO duyệt/từ chối vai (D4)
**Loại:** Approval — MFA step-up bắt buộc (purpose `policy_approval`). Nội dung: ngữ cảnh đầy đủ (người đề xuất, vai, lý do, kết quả preflight SoD, binding hiện tại). Từ chối: lý do ≥10 ký tự. Cùng người đề xuất và duyệt → backend `SOD_VIOLATION`; không có nút override ở bất kỳ vai nào.

### 3.5. Dialog Ký quarterly review (D5)
**Loại:** Confirm ký. Điều kiện mở: TẤT CẢ dòng có quyết định giữ/thu hồi + khu quyền CFO/CTO đã xử lý (validate chặn CEO bỏ qua dòng kiêm nhiệm). Ký bằng phiên SSO hợp lệ + MFA step-up; không ủy quyền (CEO vắng vẫn tự ký — không ký các quyền tự vô hiệu theo thiết kế). Chữ ký + timestamp lưu vào access review record làm bằng chứng kiểm toán.

### 3.6. Dialog Truy cập khẩn T3/T4 (D6)
**Loại:** Form có thời hạn. Fields: phạm vi dữ liệu T3/T4, thời hạn mở, lý do (khai báo trong 24h kể từ lúc mở — quá hạn → alert đỏ CEO + quyền tự đóng). Mở xong → alert CEO ngay; mọi lượt đọc trong cửa sổ khẩn ghi audit bắt buộc. Submit → `POST /core/pii/break-glass-requests` (duyệt CEO `[STEP-UP]`).

---

## 4. SHEETS

| # | Sheet | UI-ID | Vị trí | Mở khi nào |
|---|-------|-------|--------|-----------|
| 1 | Hồ sơ user | `UI-WEB-RBAC-001-S1` | Right panel 480px (đẩy content) | Click hàng Users / kết quả tìm kiếm |

### 4.1. Sheet: Hồ sơ user (S1)
**Kích thước:** 480px; Esc đóng, focus trả về hàng vừa mở.
**Nội dung (tabs trong panel):** (a) *Định danh & lifecycle* — mã NV, phòng, trạng thái + ProgressTracker lifecycle (node hiện tại + ai giữ bước kế), guest hết hạn; (b) *Vai & quyền* — binding hiện tại (role × level × data scope, effective-dated), lịch sử SCD2 thu gọn, cờ SoD; (c) *Bảo mật* — MFA state + thiết bị, session active (nút thu hồi từng session / revoke-all `[STEP-UP]`), break-glass đang mở (nếu có); (d) *Review* — quyết định các kỳ gần nhất + reason code, link vào kỳ đang mở (T3). PII lương/cost hiển thị masked theo vai — SYS_ADMIN không thấy giá trị, không có nút bỏ mask; lượt mở hồ sơ chứa PII ghi `pii_access_log`. **Footer sticky:** [Đề xuất thay đổi] (D1) + [Trail audit] → mở S25 với filter object = user này (API-CORE-030).

---

## 5. VIEW MODES

| Mode | UI-ID | Mô tả | Hiện khi nào |
|------|-------|-------|--------------|
| Bảng Users (mặc định) | `UI-WEB-RBAC-001-M1` | DataTable §1 — vận hành hằng ngày | Default |
| Bản đồ vai × Level × Scope | `UI-WEB-RBAC-001-M2` | Ma trận đọc 19 vai × permission × data-scope, tô ô cờ SoD xung đột + `combined_role` — nhìn tổng thể rủi ro lạm quyền trước kỳ review | Toggle trong T2 (CEO/CFO; SYS_ADMIN xem phần kỹ thuật không PII) |

---

## 6. API ENDPOINTS

Endpoint thật từ `api-contract.md` (base `/api/v1`). Enforcement RBAC nằm ở SYS-CORE-BACKEND (PDP) — web không tự check quyền cục bộ. Mọi thao tác ghi tự append audit hash-chain.

| Khi nào | Method | Endpoint | Tham số / Ghi chú |
|---------|--------|----------|-------------------|
| Tải danh sách Users (T1) | GET | `/core/users` (API-CORE-009) | `role`, `dept`, `status`, `page`, `limit` (20/100, server-side) |
| Tạo user | POST | `/core/users` (API-CORE-010) | Trạng thái khởi điểm `probation` — không có quyền phê duyệt |
| Mở hồ sơ user (S1) | GET | `/core/users/:id` (API-CORE-011) | Roles, sessions, MFA state |
| Cập nhật hồ sơ định danh | PUT | `/core/users/:id` (API-CORE-012) | Không đụng credential (thuộc IdP) |
| Chuyển trạng thái (D2) | POST | `/core/users/:id/transitions` (API-CORE-013) | `probation→active→suspended→locked→deactivated`; offboarding thu hồi session + rotate ≤24h |
| Thu hồi mọi session | POST | `/core/users/:id/sessions/revoke-all` (API-CORE-050) `[STEP-UP]` | Nghi ngờ compromise; ghi audit + evidence WORM |
| Ma trận vai (T2/M2) | GET | `/core/roles` (API-CORE-015) | Danh mục 19 vai + Role×Permission×Dept×Data-scope |
| Đề xuất sửa vai/permission | POST/PUT | `/core/roles` (API-CORE-016) | SYS_ADMIN đề xuất → BOD_CEO duyệt |
| Gán vai (thực thi sau duyệt) | POST | `/core/roles/:id/assignments` (API-CORE-017) | Preflight SoD — `SOD_VIOLATION` khi trùng cặp cấm; set cờ `combined_role` |
| Thu hồi vai | DELETE | `/core/roles/:id/assignments/:userId` (API-CORE-018) | Effective ngay + revoke session liên quan |
| Catalog permission | GET/POST/PUT | `/core/permissions` (API-CORE-019) | `resource:action` gắn state guard |
| Preflight SoD (D1) | POST | `/core/pdp/sod-check` (API-CORE-022) | Trả violation list: xung đột, self-approve, combined-role |
| Kỳ review (T3) | GET/POST | `/core/access-reviews/campaigns` (API-CORE-024) | SYS_ADMIN tạo/mở; tự trigger ngày 1 quý + recertification khi đổi vai/phòng/kiêm nhiệm |
| Dòng review (T3) | GET | `/core/access-reviews/campaigns/:id/items` (API-CORE-025) | Filter `dept`, `role`, đặc quyền nhạy cảm (vault CTO, Restricted) |
| Quyết định giữ/thu hồi (T3) | POST | `/core/access-reviews/items/:id/decisions` (API-CORE-026) `[STEP-UP]` | `approve/revoke/extend` + lý do; revoke thực thi ngay |
| Đóng campaign (T3) | POST | `/core/access-reviews/campaigns/:id/close` (API-CORE-027) | SYS_ADMIN đóng → CEO xác nhận; decision log đóng gói → WORM |
| MFA step-up (D4/D5) | POST | `/core/auth/mfa/step-up` (API-CORE-003) | `purpose: "policy_approval"` |
| Đăng ký MFA (hướng dẫn user) | POST | `/core/auth/mfa/enrollments` (API-CORE-004) | TOTP — provisioning URI + QR; verify đầu tiên hoàn tất |
| Session active (S1) | GET/DELETE | `/core/auth/sessions` (API-CORE-006) | DELETE `/:sessionId` thu hồi 1 session |
| Delegate khi vắng | GET/PUT | `/core/policies/delegates` (API-CORE-023) `[STEP-UP]` | CEO delegate CFO; FIN_L2 delegate FIN (tham chiếu — duyệt vai thì không ủy quyền) |
| Mask rule PII (T4) | GET/POST/PUT | `/core/pii/classifications` (API-CORE-033) · `/core/pii/mask-configs` (API-CORE-034) | SYS_ADMIN quản trị; HR_L2 đồng duyệt với PII lương |
| Break-glass T3/T4 (D6) | POST | `/core/pii/break-glass-requests` (API-CORE-035) | Đề xuất mọi vai; duyệt BOD_CEO `[STEP-UP]`; mở có giờ + audit mọi lượt đọc |

**[NEEDS_REVIEW] thiếu endpoint cho:** (1) GET danh sách lệnh provisioning (`provisioning_order` / `role_assignment_order`) chờ CEO duyệt và chờ SYS_ADMIN thực thi — hiện chỉ có POST/DELETE assignments; (2) GET/PUT offboarding checklist + điểm xác nhận CTO (`offboarding_checklist`); (3) GET danh sách credential đến hạn rotate T-7 (`credential_rotation_alert` — inventory thuộc GW); (4) GET/PUT `session_policy` theo tier + cấu hình realm Keycloak (T4 — entity tồn tại ở feature spec nhưng chưa có contract); (5) POST reset MFA phía admin (`mfa_enrollment.reset_history` — API-CORE-004 chỉ self-enrollment). KHÔNG bịa endpoint — các khối UI này render theo dữ liệu có sẵn và chờ bổ sung contract.

---

## 7. UI-ID Registry

| UI-ID | Loại | Mô tả |
|-------|------|-------|
| `UI-WEB-RBAC-001` | Main Page | RBAC Admin — registry/admin, bảng + SidePanel 480px |
| `UI-WEB-RBAC-001-T1` | Tab | Users — lifecycle, MFA, session |
| `UI-WEB-RBAC-001-T2` | Tab | Vai & Phân quyền — 19 vai registry + ma trận + SoD |
| `UI-WEB-RBAC-001-T3` | Tab | Access Review — kỳ quý, ký CEO, lệnh thực thi, offboarding, rotate |
| `UI-WEB-RBAC-001-T4` | Tab | Xác thực & Chính sách phiên — SSO realms, MFA, session policy, mask, break-glass |
| `UI-WEB-RBAC-001-D1` | Dialog | Đề xuất gán/thu hồi vai (preflight SoD, lý do bắt buộc) |
| `UI-WEB-RBAC-001-D2` | Dialog | Chuyển trạng thái tài khoản (lifecycle + offboarding 24h) |
| `UI-WEB-RBAC-001-D3` | Dialog | Reset MFA (lý do bắt buộc, không bỏ MFA vĩnh viễn) |
| `UI-WEB-RBAC-001-D4` | Dialog | CEO duyệt/từ chối gán/thu hồi vai (MFA step-up) |
| `UI-WEB-RBAC-001-D5` | Dialog | Ký quarterly review (không ủy quyền) |
| `UI-WEB-RBAC-001-D6` | Dialog | Truy cập khẩn T3/T4 break-glass (có giờ, lý do 24h) |
| `UI-WEB-RBAC-001-S1` | Sheet | Hồ sơ user 480px (định danh · vai · bảo mật · review) |
| `UI-WEB-RBAC-001-M1` | View Mode | Bảng Users (mặc định) |
| `UI-WEB-RBAC-001-M2` | View Mode | Bản đồ vai × Level × Scope (cờ SoD) |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../../phase2-features` | Upstream |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system | `../../../design-system.md` | Upstream |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | Upstream |
