# Screen Group: HR Records (tabs: Hồ sơ / HĐLĐ / Rate card)

Implements: FEAT-ERP-HRCORE-001 (hồ sơ L1–L5 + mã vai), FEAT-ERP-HRCORE-002 (HĐLĐ & cảnh báo 90/60/30), FEAT-ERP-HRCORE-006 (Cost Rate Card version hóa, thẩm định finance)

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `hr-core` (MOD-HR-CORE)
> **Tính năng:** FEAT-ERP-HRCORE-001/002/006 — bản fan-out cho touchpoint SYS-BCERP-WEB (registry giữ FEAT-ID canonical `FEAT-ERP-HRCORE-*`; không có tiền tố `FEAT-WEB-*` trong req-registry)
> **Route:** `/hr/records`
> **Main UI-ID:** `UI-WEB-HRREC-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Main UI-ID | `UI-WEB-HRREC-001` |
| Route | `/hr/records` — HR Workspace, badge `{hodl_sap_het_han}` (Navigation S20) |
| Loại | Danh sách hồ sơ (R6 data grid) + tab bar 3 tab: T1 Hồ sơ (master-detail W2) · T2 HĐLĐ (queue cảnh báo 90/60/30 + đỏ) · T3 Rate card (version lifecycle 3 chặn HR∥FIN∥BOD) |
| Workspace | HR — manager các phòng vào view giới hạn (PII lương masked), không nhân bản surface |
| Đối tượng nghiệp vụ | EmployeeProfile (SSOT L1–L5) + EmployeeRoleVersion (SCD2 hiệu lực từ–đến) + LaborContract (chuỗi tái ký `renewed_from_id`) + RateCardVersion/RateCardLine (cost/hour theo Level) |
| Vai trò chính | HR_L1 (tạo/sửa hồ sơ, nhập metadata HĐLĐ — C1 masked, KHÔNG xem lương) · HR_L2 (full truy cập C1/Restricted, duyệt luồng HR, soạn Rate Card) |
| Vai trò liên quan | Manager/TL (view giới hạn nhóm mình, nhận cảnh báo HĐLĐ nhóm — không file scan) · BOD_CEO/BOD_CFO_CTO (duyệt đổi Level/vai, duyệt phát hành Rate Card, nhận escalation HĐLĐ đỏ theo tuần) · FIN_L2 (thẩm định Rate Card — đọc có log, chỉ trong giai đoạn thẩm định) · SYS_ADMIN (thực thi lệnh cấp/thu hồi RBAC — không xem giá trị nghiệp vụ) · OPS_AM (xác nhận thu hồi TKQC khi offboarding) |
| Workflow stage | Hồ sơ: `PROBATION → OFFICIAL → (LONG_LEAVE) → TERMINATION_PENDING → TERMINATED` — mọi thay đổi mã vai/Level/trạng thái tạo version SCD2 mới, cấm sửa đè · HĐLĐ: `ACTIVE → EXPIRING (90/60/30) → RENEWED` · `EXPIRING → EXPIRED_RED → RESOLVED` · `ACTIVE → TERMINATED_EARLY / PERMANENT_NO_REMIND` · Rate card: `DRAFT → FIN_REVIEW → PENDING_BOD → PUBLISHED → ACTIVE → CLOSED / REJECTED` |

**Checklist ngữ cảnh (BƯỚC 0):** (A) Object = hồ sơ nhân sự SSOT — mọi phân hệ (RBAC, hoa hồng, P&L, KPI, nghỉ phép, chấm công) đọc từ đây; mỗi hồ sơ mang vai hiện hành (version SCD2), chuỗi HĐLĐ và rate áp dụng. (B) Primary actors: HR_L1 nhập, HR_L2 quản trị + duyệt. (C) Related: BOD (duyệt đổi Level, escalation đỏ), FIN_L2 (thẩm định rate ∥ HR), TL (cảnh báo nhóm), SYS_ADMIN (thực thi lệnh RBAC), OPS (thu hồi TKQC offboarding). (D) Stages: 3 machine-state độc lập (hồ sơ / HĐLĐ / rate card — mô tả trên). (E) Cross-module: S15 (timesheet duyệt ∥ HR), S21 (nghỉ phép đọc hồ sơ), S22 (KPI đọc vai/Level), S23 (P&L × rate card), S24 (escalation HĐLĐ đỏ), S26 (RBAC admin), M5 (hồ sơ cá nhân masked). (F) Thông tin cần: vai hiện hành + khoảng hiệu lực, mốc hết hạn HĐLĐ, checklist on/offboarding, trạng thái lệnh RBAC, rate đang hiệu lực + % lệch payroll. (G) Quyết định: duyệt requisition/thôi việc/đổi Level; ký tiếp hay chấm dứt HĐ; phát hành rate version. (H) Actions: CRUD hồ sơ (thường), sửa C1 (L2), tái ký/chấm dứt HĐ, soạn/thẩm định/duyệt rate, gắn flag tắt nhắc. (I) Exceptions: HĐLĐ quá hạn chưa tái ký (đỏ + escalate BOD theo tuần), thử việc sắp hết chưa đánh giá (≥3 ngày), checklist offboarding quá 24h, rate lệch payroll >±10% `[CẦN CHỐT SỐ]`, khoảng hở version. (J) 1 surface `/hr/records`, 3 tab — rate card là tab (không page riêng, §2.0.5 S20 KEEP + MERGE).

---

## 1. TRANG CHÍNH

### 1.1. Layout — tab bar trên cùng; T1 là tab mặc định (danh sách R6 + mở chi tiết qua Sheet S1)

```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ Breadcrumb: HR > HR Records        ⚠ {hodl_sap_het_han} ·5       [+ Tạo hồ sơ]  [Cập nhật ▾] │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ Tabs: [Hồ sơ ·148] [HĐLĐ — hết hạn ·5] [Rate card — v04 hiệu lực]                            │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ ── TAB T1: HỒ SƠ NHÂN SỰ ────────────────────────────────────────────────────────────────── │
│ (Thử việc ·4×)(Chờ thôi việc ·2×)(Nghỉ không lương ·1×)(HĐLĐ <90 ngày ·5×)  [Tìm nhanh…][Lọc▾]│
│ ┌────────────────────────────────────────────────────────────────────────────────────────┐   │
│ │ Mã NV   Họ tên         Phòng    Mã vai·Level   TL trực tiếp  Trạng thái       Cảnh báo │   │
│ │ NV-0142 Nguyễn Văn A.  OPS      OPS_EDIT · L2  Phạm D.       [Chính thức]    ⚠ HĐ còn 45││
│ │ NV-0157 Lê Thị B.      HR       HR_L1 · L1     Nguyễn T.     [Thử việc]      ⚠ ĐG thử││
│ │ NV-0089 Trần C.        SALES    SALES_L2 · L3  —             [Chờ thôi việc] ⚠ TKQC ││
│ │ NV-0163 Hoàng E.       MKT      MKT_DES · L1   Lê F.         [Nghỉ không lương]     ││
│ │ …                                                                                      │   │
│ │ Bulk: [Đã chọn 2] [Gán lại TL trực tiếp] [Xuất danh sách (không C1)] [⋯]               │   │
│ │ Phân trang ← 1 2 … 12 →   20/50/100                                                    │   │
│ └────────────────────────────────────────────────────────────────────────────────────────┘   │
│ Row actions: Xem (S1) · Sửa (D1) · Đề xuất đổi Level/vai (D3) · Thôi việc (D4) · ⋯           │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```

Global context: tab đang chọn + filter phòng ban giữ nguyên khi chuyển tab; header ẩn đi khi mở Sheet S1 (context hồ sơ chuyển xuống sheet). Mobile <768px: bảng không render — báo "quản lý hồ sơ trên web" (A7.2: quản trị hồ sơ chỉ web); ESS đọc qua M5.

### 1.2. Components

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| DataTable | row comfortable 40px (hồ sơ = nhập liệu), header 36px sticky, sort click header, pagination server-side 20/50/100, column config persist | R6; bulk-selection |
| Quick filter chips | tháo từng chip; mặc định theo mùa vụ: "HĐLĐ <90 ngày" hiện khi badge `{hodl_sap_het_han}` > 0 | Chip nguồn = filter tương ứng |
| StatusBadge | 1 badge/hàng — bảng trạng thái §1.4 | Token §1 design-system |
| WarningIndicator | inline trong cột cảnh báo: HĐLĐ sắp hết hạn (mốc 90/60/30), sắp đến hạn đánh giá thử việc, offboarding quá SLA 24h | 3 phần: chuyện gì — ai làm — hạn còn lại |
| Tabs | page tabs + count-tab cho T2 | T2/T3 lazy-load |
| MaskedField + reveal | trường C1 render masked (●●●● ●●34); nút "Xem" per-field mở D2 | Field-level security là trải nghiệm — xem §1.5 |

### 1.3. Cột danh sách T1

| Tên | Trường | Định dạng | Sắp xếp | Ghi chú |
|-----|--------|----------|---------|---------|
| Mã NV | `employee_code` | Text, tabular | Có | Tự sinh, không tái sử dụng (BR-002) |
| Họ tên | `full_name` | Avatar + tên | Có | Trùng CCCD chặn ở D1 |
| Phòng ban | `department` | Chip | Có | Filter chính |
| Mã vai · Level | EmployeeRoleVersion hiện hành | `OPS_EDIT · L2` + khoảng hiệu lực tooltip | Có | Nhiều vai → chip đầu + "+n"; SCD2 |
| TL trực tiếp | `direct_tl_id` | Avatar + tên | Có | Chức danh tổ chức, không phải vai registry |
| Trạng thái | `status` | StatusBadge | Có | Bảng §1.4 |
| Cảnh báo | derived | Icon WarningIndicator inline | Không | HĐLĐ / thử việc / offboarding SLA |

### 1.4. Trạng thái & badge

Nháp/Thử việc `--state-draft` · Chính thức `--state-approved` · Nghỉ không lương (LONG_LEAVE) `--state-info` · Chờ thôi việc (TERMINATION_PENDING) `--state-sla-warning` · Nghỉ việc (TERMINATED — retention, không xóa cứng) `--state-manual`. HĐLĐ (T2): Hiệu lực `--state-approved` · Sắp hết hạn 90 `--state-info` · 60 `--state-sla-warning` · 30 `--state-pending` · Quá hạn đỏ `--state-overdue` + icon chuông · Không XĐ thời hạn (tắt nhắc) `--state-manual`. Rate card (T3): Dự thảo `--state-draft` · Chờ thẩm định FIN `--state-pending` · Chờ BOD `--state-sla-warning` · Đã phát hành `--state-approved` · Hiệu lực `--state-approved` + icon gear · Đã đóng/Từ chối `--state-manual`/`--state-rejected`.

**Trạng thái hệ thống:** loading = skeleton 10 hàng; empty T1 = "Chưa có hồ sơ — tạo hồ sơ đầu tiên" (CTA D1, ẩn với manager); error = hàng lỗi + retry. Mọi mốc nhắc render đúng kết quả quét job CORE — UI không tự tính lại ngày.

### 1.5. PII masking — field-level security là trải nghiệm (bắt buộc lane)

- **Mask mặc định:** mọi trường phân loại Confidential/Restricted (lương, CCCD, TK ngân hàng, dữ liệu y tế, số HĐ + file scan, cost/hour cá nhân) render masked cho vai không đủ quyền — KHÔNG đợi lỗi 403: mask rule đọc từ `/core/pii/mask-configs` (API-CORE-034), áp ở API layer, UI chỉ phản chiếu.
- **Ma trận:** HR_L1 masked vĩnh viễn (không xem lương — BR-007 FEAT-ERP-HRCORE-001) · HR_L2 + BOD thấy full · Manager/TL/SYS_ADMIN masked · FIN_L2 chỉ mở cột cost trong giai đoạn thẩm định rate card (log, hết giai đoạn quay về mask) · HR_L2 mở file scan HĐLĐ có audit từng lượt; TL chỉ nhận thông báo không file.
- **Reveal có audit:** nút "Xem" trên từng trường mở D2 — xác nhận mục đích (lý do ngắn), hiển thị bản gốc trong phiên, tự re-mask sau 60 giây hoặc khi blur; mỗi lượt = 1 entry audit bất biến (ai — khi nào — trường nào — lý do). Không có reveal "dính" vĩnh viễn; xuất raw C1 không tồn tại trong UI.
- **Khẩn (break-glass):** truy cập Restricted ngoài phạm vi → đề xuất qua `/core/pii/break-glass-requests`, BOD_CEO duyệt `[STEP-UP]`, mở có giờ + audit bắt buộc (API-CORE-035).

### 1.6. Phân Quyền (hide khi không có quyền — PEP; RBAC CORE kiểm tra tại API)

| Thành phần | HR_L1 | HR_L2 | Manager/TL | BOD_CEO/BOD_CFO_CTO | FIN_L2 | SYS_ADMIN |
|-----------|-------|-------|------------|---------------------|--------|-----------|
| Xem hồ sơ (trường thường) | ✅ | ✅ | ✅ nhóm mình | ✅ (theo báo cáo) | ❌ | ❌ (mask giá trị) |
| Xem/reveal C1 | ❌ (mask) | ✅ (+ audit) | ❌ (mask) | ✅ | ❌ (chỉ cost khi thẩm định, log) | ❌ (mask) |
| Tạo/sửa hồ sơ thường | ✅ | ✅ | ❌ (đề xuất qua D3) | ❌ | ❌ | ❌ |
| Sửa trường C1 | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Đề xuất đổi Level/vai | ❌ | ✅ (thẩm định + trình) | ✅ (nhóm mình — đề xuất) | ❌ (nhận duyệt) | ❌ | ❌ |
| Duyệt đổi Level/vai | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Duyệt requisition headcount | ❌ | ✅ (vượt kế hoạch → BOD) | ❌ | ✅ (vượt kế hoạch năm) | ❌ | ❌ |
| Tạo/duyệt hồ sơ thôi việc | ✅ tạo | ✅ duyệt | ❌ | ❌ | ❌ | ❌ |
| Nhập metadata HĐLĐ + upload scan | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Mở file scan bản gốc | ❌ | ✅ (log từng lượt) | ❌ | ❌ | ❌ | ❌ |
| Gắn flag tắt nhắc / chốt phương án vùng đỏ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Soạn Rate Card / import mở sổ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Thẩm định Rate Card (đối chiếu payroll) | ❌ | ❌ | ❌ | ❌ | ✅ (giai đoạn thẩm định, log) `[NEEDS_REVIEW: API-ERP-067 ghi FIN_L1]` | ❌ |
| Duyệt phát hành Rate Card | ❌ | ❌ | ❌ | ✅ (không delegate) | ❌ | ❌ |
| Xem timeline version + audit log | ✅ | ✅ | ❌ (nhóm mình: metadata) | ✅ | ✅ (metadata) | ✅ (xem log cũng bị log) |

Cấm tự duyệt luồng do mình soạn: HR_L1 tạo hồ sơ → HR_L2 duyệt; HR_L2 soạn rate → FIN thẩm định → BOD duyệt (SoD 3 vai, không ai chiếm 2 bước). Không delegate trong mọi luồng Rate Card `[KXN-DTS]` — vắng người luồng treo có nhãn chờ.

---

## 2. TABS

Global context (filter phòng ban + role view) giữ nguyên khi chuyển tab; T2/T3 lazy-load.

### Tab T1 — Hồ sơ `UI-WEB-HRREC-001-T1`
- **Mục tiêu:** quản lý SSOT L1–L5: tạo đúng 1 hồ sơ/người, thay đổi vai/Level/trạng thái luôn qua version SCD2, offboarding chặt 24h.
- **Thông tin:** danh sách + chi tiết theo §1; checklist onboarding (ký HĐLĐ, tài khoản, buddy, mục tiêu thử việc — 100% là điều kiện đánh giá hết thử việc) và offboarding (RBAC ≤24h, thu hồi TKQC OPS xác nhận ≤24h, chốt phép/công/timesheet) hiển thị dạng progress trong S1.
- **Components/actions/states:** theo §1.2–1.6; hành động chính: D1 tạo/sửa, D2 reveal, D3 đổi Level/vai, D4 thôi việc, gán lại TL (bulk), xem S1/S2.
- **Quan hệ tab khác:** hồ sơ mới hiệu lực → T2 nhận HĐLĐ đầu tiên (thử việc); đổi Level giữa năm → T3 rate áp version mới từ ngày hiệu lực (SCD2); thôi việc duyệt → T2 chuyển HĐ sang "chấm dứt theo thôi việc" thay vì cảnh báo đỏ.

### Tab T2 — HĐLĐ: cảnh báo 90/60/30 + gia hạn `UI-WEB-HRREC-001-T2`
- **Mục tiêu:** không để hợp đồng xác định thời hạn nào "chạy quá hạn chưa tái ký" — xử lý hết vùng đỏ, chốt phương án trước 30 ngày.
- **Thông tin:** dải 4 vùng tổng quan (W4, click → queue lọc sẵn): **Quá hạn (đỏ)** `EXPIRED_RED` — escalate BOD theo tuần, nhãn rủi ro pháp lý · **≤30 ngày** — phải chốt phương án · **≤60 ngày** — chuẩn bị hồ sơ tái ký · **≤90 ngày** — quyết định ký tiếp hay không. Dưới dải: bảng HĐ — NV, loại HĐ (thử việc/XĐ thời hạn/không XĐ), số HĐ (C1 masked), ngày ký, hiệu lực từ–đến, còn X ngày (Countdown), StatusBadge, chuỗi tái ký (A→B), cảnh báo. Riêng khối "Sắp hết hạn thử việc chưa đánh giá (≥3 ngày)" tách trên đầu — chặn luồng ký HĐ chính thức khi chưa có kết luận (BR-004).
- **Components:** DataTable compact + vùng tổng quan dạng 4 card số lớn; WarningIndicator banner cho vùng đỏ (không dismiss, có nút "Chốt phương án"); ApprovalCard cho tái ký (D6) và chấm dứt (D7); WaitingOn cho HĐ đang soạn tái ký chờ HR_L2 duyệt.
- **Actions:** nhập HĐLĐ + upload scan (D5); tái ký — tạo bản ghi nối tiếp, bản cũ `RENEWED` giữ lịch sử (D6); chấm dứt giữa hạn — căn cứ Điều 34/35/36 BLLĐ 2019 + file quyết định (D7); gắn flag không XĐ thời hạn tắt nhắc / bỏ flag kèm lý do (trong D5, chỉ HR_L2); đánh giá hết thử việc PASS/gia hạn 30 ngày + PIP/STOP (D8); mở file scan (S3 — HR_L2, audit).
- **States:** lazy-load; empty "Không có HĐLĐ trong vùng này"; vùng đỏ trống = trạng thái tốt — hiển thị "Không có HĐ quá hạn"; error retry từng vùng. Mốc nhắc 90/60/30 và escalation render từ job quét CORE (`RemindLog`), không tính phía UI.
- **Quan hệ:** cảnh báo đồng thời gửi TL nhân sự nhóm (không kèm file); HĐ NV nghỉ việc → chuyển "chấm dứt theo thôi việc" (ưu tiên offboarding T1); `EXPIRED_RED` → S24 Alert Center nhận escalation tuần; nghỉ không lương kéo qua mốc vẫn cảnh báo (nghĩa vụ pháp lý không dừng).

### Tab T3 — Rate card (lương công khai nội bộ theo vai/cấp — thẩm định HR ∥ FIN) `UI-WEB-HRREC-001-T3`
- **Mục tiêu:** quản lý cost/hour chuẩn theo Level, vòng đời 3 chặn HR_L2 soạn → FIN thẩm định → BOD duyệt; version phát hành bất biến, P&L chọn đúng version theo ngày ghi giờ.
- **Thông tin:** (1) Header: version đang **ACTIVE** (số version, hiệu lực từ–đến, người duyệt + timestamp) + bảng cost/hour theo Level (MoneyDisplay, `tabular-nums`) + nhãn "duyệt lại chu kỳ năm". (2) Timeline versions: DRAFT/FIN_REVIEW/PENDING_BOD/PUBLISHED/ACTIVE/CLOSED/REJECTED — mỗi node: người soạn/thẩm định/duyệt, số vòng trả về, ngày hiệu lực; version tương lai nhãn "chờ hiệu lực". (3) Bảng đối chiếu payroll (khi FIN_REVIEW): proposed vs payroll thực tế theo Level + % lệch — vượt ±10% `[CẦN CHỐT SỐ]` tô `--state-sla-warning` + yêu cầu FIN trả về kèm lý do. (4) Khối migration mở sổ (chỉ hiện khi chưa có version): import khung từ payroll → BOD xác nhận phát hành; trước đó mọi báo cáo cost hiển thị "chưa có Rate Card hiệu lực", không bao giờ 0. (5) Hàng đợi cờ dữ liệu "khoảng hở version" (FIN thúc phát hành).
- **Components:** DataTable + MoneyDisplay (cost); ProgressTracker 3 chặn; ApprovalCard D10/D11; Timeline; WarningIndicator cho % lệch quá ngưỡng và cờ thiếu version.
- **Actions:** soạn dự thảo (D9 — HR_L2); trả về kèm lý do (D10 — FIN, lý do bắt buộc kèm % lệch); duyệt phát hành (D11 — BOD, không delegate); tra cứu version theo khoảng thời gian (lookup theo ngày ghi giờ — chỉ đọc). Không có nút sửa version đã phát hành — chỉ tạo version mới.
- **States:** lazy-load; HR_L1/manager thấy metadata version KHÔNG có cột cost (mask Restricted — ghi chú "cost đã ẩn theo quyền"); manager chỉ tổng cost nhóm; empty khi chưa mở sổ → khối migration.
- **Quan hệ:** hồ sơ thăng Level (T1, SCD2) → giờ sau ngày hiệu lực tự nhân rate mới; giờ chỉ nhân khi timesheet APPROVED (S15) và trừ ngày nghỉ đã duyệt (S21); P&L/BI (S23) consume version theo ngày ghi giờ; cờ hở version → FIN thấy hàng đợi.

---

## 3. DIALOGS

| # | Dialog | UI-ID | Loại | Mở khi nào |
|---|--------|-------|------|-----------|
| 1 | Tạo/sửa hồ sơ nhân sự | `UI-WEB-HRREC-001-D1` | Form 2 cột (max 960px) | [+ Tạo hồ sơ] / "Sửa" trên hàng |
| 2 | Reveal trường C1 | `UI-WEB-HRREC-001-D2` | Confirm + lý do | Nút "Xem" trên 1 trường masked |
| 3 | Đổi Level/vai (đề xuất → thẩm định → duyệt) | `UI-WEB-HRREC-001-D3` | ApprovalCard 3 bước | Row action "Đề xuất đổi Level/vai" |
| 4 | Hồ sơ thôi việc + checklist | `UI-WEB-HRREC-001-D4` | Form + checklist | Row action "Thôi việc" |
| 5 | Nhập/sửa HĐLĐ + file scan + flag | `UI-WEB-HRREC-001-D5` | Form + upload | T2 — "Nhập HĐLĐ" / "Sửa" |
| 6 | Tái ký HĐLĐ | `UI-WEB-HRREC-001-D6` | ApprovalCard | T2 — "Tái ký" trên 1 HĐ |
| 7 | Chấm dứt giữa hạn | `UI-WEB-HRREC-001-D7` | Form + upload | T2 — "Chấm dứt" trên 1 HĐ |
| 8 | Đánh giá hết thử việc | `UI-WEB-HRREC-001-D8` | Form kết luận | T2 — khối thử việc / T1 |
| 9 | Soạn dự thảo Rate Card | `UI-WEB-HRREC-001-D9` | Bảng soạn theo Level | T3 — "Tạo dự thảo" |
| 10 | Thẩm định FIN (đối chiếu payroll) | `UI-WEB-HRREC-001-D10` | ApprovalCard + bảng lệch | T3 — version FIN_REVIEW |
| 11 | Duyệt phát hành Rate Card (BOD) | `UI-WEB-HRREC-001-D11` | ApprovalCard + ngữ cảnh | T3 — version PENDING_BOD |

Chi tiết trọng yếu:
- **D1:** mã NV tự sinh (read-only); kiểm tra trùng CCCD/tên–ngày sinh realtime — trùng → hiển thị hồ sơ nghiêm trùng để đối chiếu, chặn tạo; thật sự 2 người → HR_L2 mở khóa kèm ghi chú. Freelancer → chặn với lý do "tính chi phí dịch vụ, không tạo hồ sơ". Sửa mã vai/Level/trạng thái KHÔNG nằm ở D1 — chuyển sang D3 (version mới); D1 chỉ sửa trường thường. Lưu → lệnh cấp RBAC phát tự động theo mã vai (không cấp tay).
- **D2:** hiện trường bị mask + lý do (select: "Tính payroll", "Đối chiếu hồ sơ", "Xử lý khiếu nại"…); nút "Xem trong 60 giây"; footer ghi chú "Lượt xem ghi audit bất biến: ai — khi nào — trường — lý do". Sai quyền → 403 `PII_ACCESS_DENIED` + log attempt, toast lỗi không tự đóng.
- **D3:** bước 1 (Manager/HR_L2 đề xuất): Level/mã vai mới + ngày hiệu lực + căn cứ chuẩn năng lực + KPI 2 chu kỳ liên tiếp (attach); bước 2 (HR_L2 thẩm định — ApprovalCard); bước 3 (BOD duyệt). Duyệt → version mới hiệu lực từ ngày quyết định, version cũ đóng; chặn nhảy bước; cùng 1 người không chiếm 2 bước.
- **D4:** ngày hiệu lực + căn cứ pháp lý (Điều 34/35/36 BLLĐ 2019 — select bắt buộc) + checklist sinh tự động: vô hiệu hóa ERP/RBAC ≤24h (SYS_ADMIN thực thi theo lệnh), thu hồi TKQC → OPS thực thi + xác nhận ≤24h (queue ở S2, HR quản SLA), chốt phép, chốt công/timesheet, handover. Chưa đủ xác nhận → không đóng `TERMINATED`.
- **D5:** loại HĐ, số HĐ (masked sau lưu), ngày ký/hiệu lực/hết hạn, quốc gia (VN/KH/HK — mốc 90/60/30 giữ nguyên), nhiều file scan (thay file = phiên bản mới + lý do, không ghi đè). Flag "không XĐ thời hạn — tắt nhắc" chỉ HR_L2; bỏ flag bắt buộc lý do.
- **D6:** sao giá trị HĐ cũ (read-only) + hiệu lực mới; tạo bản ghi nối tiếp `renewed_from_id`; HĐ cũ chuyển `RENEWED` giữ nguyên lịch sử. HR_L1 soạn → HR_L2 duyệt (không tự duyệt).
- **D8:** kết luận PASS / gia hạn 30 ngày (kèm PIP) / STOP; điều kiện: checklist onboarding 100%, trước ngày kết thúc thử việc ≥3 ngày; TL cho ý kiến đánh giá. PASS → mở luồng ký HĐ chính thức (D6); chặn ký khi chưa có kết luận.
- **D9/D10/D11:** D9 soạn cost/hour theo mọi Level + khoảng hiệu lực (thiếu Level → không submit); D10 bảng đối chiếu + nút **Duyệt thẩm định** / **Trả về** (lý do + % lệch bắt buộc); D11 ngữ cảnh đầy đủ (đối chiếu + lịch sử version) — **Duyệt phát hành** / **Từ chối** (lý do). Phát hành → số version tự tăng + timestamp; trùng khoảng hiệu lực version đã phát hành bị chặn (trừ thay thế).

---

## 4. SHEETS

| # | Sheet | UI-ID | Vị trí | Mở khi nào |
|---|-------|-------|--------|-----------|
| 1 | Hồ sơ 360 nhân viên | `UI-WEB-HRREC-001-S1` | Right 720px | Click 1 hàng T1 (hoặc "Xem") |
| 2 | Offboarding: lệnh RBAC + thu hồi TKQC | `UI-WEB-HRREC-001-S2` | Right 480px | Click khối checklist offboarding trong S1 |
| 3 | Chuỗi HĐLĐ + file scan | `UI-WEB-HRREC-001-S3` | Right 480px | Click chuỗi HĐ trong S1 hoặc 1 hàng T2 |

- **S1:** header: avatar + tên + mã NV + StatusBadge + vai hiện hành (`mã vai · Level`, tooltip khoảng hiệu lực). Khối: (1) thông tin liên hệ/phòng/TL — trường C1 masked + nút "Xem" (D2); (2) vai đã có (nhiều dòng version SCD2 from–to); (3) HĐLĐ tóm tắt + mốc nhắc hiện hành; (4) checklist onboarding/offboarding (progress %); (5) Timeline version (mọi thay đổi) + activity (audit — API-CORE-030). Footer sticky theo quyền: [Sửa] [Đổi Level/vai] [Thôi việc] — Esc đóng, trả focus về hàng.
- **S2:** từng mục checklist offboarding với thời điểm + người xác nhận; lệnh `RbacProvisioningCommand` (grant/revoke, trạng thái, SYS_ADMIN thực thi); handoff thu hồi TKQC — nhãn SLA 24h, quá hạn → WarningIndicator + escalate HR_L2; chốt phép/công/timesheet. Không đóng hồ sơ khi còn quyền TKQC sống.
- **S3:** chuỗi tái ký A→B→C (node: loại, số HĐ masked, hiệu lực); metadata bản đang chọn; khối file scan — danh sách phiên bản file, nút "Mở bản gốc" chỉ hiện HR_L2 (mỗi lần mở = 1 audit entry); TL thấy metadata không có khối file.

---

## 5. VIEW MODES

1 surface `/hr/records` — role views khác nhau chỉ ở phạm vi dữ liệu + nút (Navigation: "manager các phòng view giới hạn, PII lương masked").

| Mode | UI-ID | Hiện khi nào | Khác biệt |
|------|-------|--------------|-----------|
| HR_L1 | `UI-WEB-HRREC-001-M1` | Role HR_L1 | Tạo/sửa hồ sơ thường, nhập HĐLĐ, soạn tái ký/chấm dứt/đánh giá thử việc (chờ L2 duyệt); C1 masked vĩnh viễn — cột lương/scan ẩn cả trong D1; không thấy nút duyệt |
| HR_L2 | `UI-WEB-HRREC-001-M2` | Role HR_L2 | Full: reveal C1 (D2), duyệt hồ sơ mới/tái ký/chấm dứt, chốt phương án vùng đỏ, soạn Rate Card (D9), duyệt requisition; mặc định T2 khi có cảnh báo |
| Manager/TL | `UI-WEB-HRREC-001-M3` | Chức danh TL/Manager (theo trường TL trực tiếp) | Chỉ nhân sự nhóm mình; read-only trừ "Đề xuất đổi Level/vai" (D3 bước 1); nhận cảnh báo HĐLĐ nhóm (không file scan); C1 masked; không thấy T3 cột cost |
| BOD | `UI-WEB-HRREC-001-M4` | BOD_CEO/BOD_CFO_CTO | Nhận duyệt: đổi Level/vai (D3 bước 3), phát hành Rate Card (D11), requisition vượt kế hoạch; escalation vùng đỏ HĐLĐ theo tuần (link S24); không thao tác CRUD |

---

## 6. API ENDPOINTS

> Endpoint thật từ `api-contract.md` §6.5 (COMP-ERP-005) + §PII/RBAC/Audit (COMP-CORE). WEB render machine-state từ CORE. Pagination server-side 20/50/100 cho mọi list.

| Khi nào | Method | Endpoint | Tham số / Ghi chú |
|---------|--------|----------|-------------------|
| Danh sách hồ sơ (T1) | GET | `/api/v1/erp/employees` | Filter `q, department, role_code, level, status, has_expiring_contract`; `sort, page, limit` — API-ERP-062 |
| Xem/sửa 1 hồ sơ | GET/PUT | `/api/v1/erp/employees/{id}` | Mask theo classification; thiếu quyền → 403 `PII_ACCESS_DENIED` — API-ERP-062 |
| Tạo hồ sơ (D1) | POST | `/api/v1/erp/employees` | Mã NV tự sinh; trùng → `DUPLICATE` + hồ sơ nghiêm trùng; freelancer bị chặn — API-ERP-062 |
| Đổi Level/vai, thử việc→chính thức, LONG_LEAVE, thôi việc (D3/D4/D8) | POST | `[NEEDS_REVIEW: thiếu POST /api/v1/erp/employees/{id}/transitions]` | State machine hồ sơ (§6 FEAT-ERP-HRCORE-001) + tạo version SCD2; hiện API-ERP-062 chỉ POST/GET/PUT |
| Checklist onboarding/offboarding (S1/S2) | GET/POST | `[NEEDS_REVIEW: thiếu endpoint checklist]` | OnboardingChecklist/OffboardingChecklist + xác nhận thu hồi TKQC của OPS |
| HĐLĐ của 1 nhân viên (S3) | GET | `/api/v1/erp/employees/{id}/contracts` | Trạng thái expiring 90/60/30 (sweep CORE) — API-ERP-063 |
| Nhập HĐLĐ / tái ký (D5/D6) | POST | `/api/v1/erp/employees/{id}/contracts` | `renewed_from_id` nối chuỗi; chấm dứt kèm `legal_basis` — API-ERP-063 |
| Queue HĐLĐ toàn công ty theo mốc (T2) | GET | `[NEEDS_REVIEW: thiếu GET /api/v1/erp/contracts]` | Cần filter `expiring_in=90|60|30|overdue, type, department, profile_id` + sort + pagination; API-ERP-063 chỉ gắn theo employee |
| Mở file scan bản gốc (S3) | GET | `[NEEDS_REVIEW: thiếu endpoint tải file scan có audit]` | Chỉ HR_L2; mỗi lượt tải = audit entry; contract hiện không khai download C1 file |
| Tạo dự thảo Rate Card (D9) | POST | `/api/v1/erp/rate-cards` | Đủ cost/hour theo mọi Level + khoảng hiệu lực — API-ERP-067 |
| Thẩm định FIN (D10) | POST | `/api/v1/erp/rate-cards/{id}/finance-endorse` | `[NEEDS_REVIEW: lệch vai — contract ghi endorse FIN_L1, spec FEAT-ERP-HRCORE-006 §4 ghi FIN_L2 thẩm định]` — API-ERP-067 |
| Duyệt phát hành / trả về (D11) | POST | `[NEEDS_REVIEW: thiếu POST /api/v1/erp/rate-cards/{id}/transitions]` | Machine `DRAFT→FIN_REVIEW→PENDING_BOD→PUBLISHED→ACTIVE→CLOSED`; API-ERP-067 chỉ khai POST + endorse |
| Timeline version + bảng hiệu lực (T3) | GET | `[NEEDS_REVIEW: thiếu GET /api/v1/erp/rate-cards]` | Lookup theo ngày ghi giờ; bảng đối chiếu payroll của 1 version cũng thiếu shape riêng |
| Trạng thái mask/classification (render masked) | GET | `/core/pii/classifications` · `/core/pii/mask-configs` | API-CORE-033/034 (quản trị tại S26 — HR_L2 đồng duyệt rule) |
| Reveal khẩn Restricted (break-glass) | POST | `/core/pii/break-glass-requests` | Đề xuất mọi vai → BOD_CEO duyệt `[STEP-UP]`, mở có giờ + audit — API-CORE-035 |
| Timeline audit 1 hồ sơ (S1) | GET | `/core/audit/objects/:objectId/timeline` | Theo vai sở hữu object — API-CORE-030; query tổng hợp: API-CORE-029 |
| Log nhắc 90/60/30 + escalation (T2) | GET | `/api/v1/erp/notifications` | Role sở hữu object — API-ERP-074 |
| Run history job quét HĐLĐ (read-only) | GET | `/api/v1/erp/jobs` | Job "HĐLĐ 90/60/30" trong registry — API-ERP-075 |

**[NEEDS_REVIEW] các điểm thiếu endpoint (KHÔNG bịa — cần bổ sung vào api-contract):**
- `[NEEDS_REVIEW: thiếu POST /api/v1/erp/employees/{id}/transitions — state machine hồ sơ (PROBATION→OFFICIAL→LONG_LEAVE→TERMINATION_PENDING→TERMINATED) + tạo version SCD2 khi đổi Level/vai]`
- `[NEEDS_REVIEW: thiếu endpoint checklist onboarding/offboarding (xem progress + tick + OPS xác nhận thu hồi TKQC)]`
- `[NEEDS_REVIEW: thiếu GET /api/v1/erp/contracts — hàng đợi HĐLĐ toàn công ty theo mốc hết hạn (90/60/30/đỏ) với filter/sort/pagination]`
- `[NEEDS_REVIEW: thiếu endpoint tải file scan HĐLĐ có audit từng lượt (chỉ HR_L2)]`
- `[NEEDS_REVIEW: thiếu GET /api/v1/erp/rate-cards (timeline version, lookup theo ngày ghi giờ) + GET đối chiếu payroll theo version + POST transitions phát hành (BOD duyệt)]`
- `[NEEDS_REVIEW: lệch vai thẩm định Rate Card — API-ERP-067 ghi finance-endorse FIN_L1, FEAT-ERP-HRCORE-006 §3/§4 ghi FIN_L2 thẩm định; cần chốt trong contract]`
- `[NEEDS_REVIEW: thiếu endpoint requisition headcount (duyệt HR_L2/BOD) — user story 1 FEAT-ERP-HRCORE-001 không có API thật]`

---

## 7. UI-ID Registry

| UI-ID | Loại | Mô tả |
|-------|------|-------|
| `UI-WEB-HRREC-001` | Main Page | HR Records — 1 surface 3 tab, route `/hr/records`, badge `{hodl_sap_het_han}` |
| `UI-WEB-HRREC-001-T1` | Tab | Hồ sơ L1–L5 + mã vai (SSOT, SCD2, checklist, offboarding) |
| `UI-WEB-HRREC-001-T2` | Tab | HĐLĐ — 4 vùng 90/60/30/đỏ, gia hạn/tái ký/chấm dứt, flag tắt nhắc, đánh giá thử việc |
| `UI-WEB-HRREC-001-T3` | Tab | Rate card — version 3 chặn HR∥FIN∥BOD, đối chiếu payroll, migration mở sổ, cờ hở version |
| `UI-WEB-HRREC-001-D1` | Dialog | Tạo/sửa hồ sơ (trùng CCCD, mã NV tự sinh, chặn freelancer) |
| `UI-WEB-HRREC-001-D2` | Dialog | Reveal trường C1 (lý do + audit, re-mask 60 giây) |
| `UI-WEB-HRREC-001-D3` | Dialog | Đổi Level/vai — 3 bước đề xuất/thẩm định/duyệt BOD (version SCD2) |
| `UI-WEB-HRREC-001-D4` | Dialog | Hồ sơ thôi việc + checklist thu hồi (RBAC 24h, TKQC OPS 24h) |
| `UI-WEB-HRREC-001-D5` | Dialog | Nhập/sửa HĐLĐ + file scan + flag tắt nhắc |
| `UI-WEB-HRREC-001-D6` | Dialog | Tái ký HĐLĐ (bản ghi nối tiếp, HR_L1 soạn → HR_L2 duyệt) |
| `UI-WEB-HRREC-001-D7` | Dialog | Chấm dứt giữa hạn (căn cứ Điều 34/35/36 + file quyết định) |
| `UI-WEB-HRREC-001-D8` | Dialog | Đánh giá hết thử việc (PASS/gia hạn 30 + PIP/STOP, ≥3 ngày trước) |
| `UI-WEB-HRREC-001-D9` | Dialog | Soạn dự thảo Rate Card (cost/hour theo Level + hiệu lực) |
| `UI-WEB-HRREC-001-D10` | Dialog | Thẩm định FIN — đối chiếu payroll, trả về kèm lý do + % lệch |
| `UI-WEB-HRREC-001-D11` | Dialog | Duyệt phát hành Rate Card (BOD, không delegate) |
| `UI-WEB-HRREC-001-S1` | Sheet | Hồ sơ 360 — C1 masked, vai SCD2, checklist, timeline + audit (right 720px) |
| `UI-WEB-HRREC-001-S2` | Sheet | Offboarding — lệnh RBAC + thu hồi TKQC SLA 24h (right 480px) |
| `UI-WEB-HRREC-001-S3` | Sheet | Chuỗi HĐLĐ + file scan (mở bản gốc HR_L2 có audit) (right 480px) |
| `UI-WEB-HRREC-001-M1` | View Mode | HR_L1 — nhập + soạn, C1 masked vĩnh viễn |
| `UI-WEB-HRREC-001-M2` | View Mode | HR_L2 — full, duyệt mọi luồng, soạn rate card |
| `UI-WEB-HRREC-001-M3` | View Mode | Manager/TL — nhóm mình, read-only + đề xuất đổi Level, masked |
| `UI-WEB-HRREC-001-M4` | View Mode | BOD — duyệt đổi Level/rate card, escalation đỏ |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng: hồ sơ L1–L5 | `../../../../phase2-features/bcerp-web/hr-core/ho-so-nhan-su-trung-tam-l1-l5-ma-vai.md` | FEAT-ERP-HRCORE-001 |
| Tính năng: HĐLĐ 90/60/30 | `../../../../phase2-features/bcerp-web/hr-core/hdld-va-canh-bao-het-han-90-60-30-ngay.md` | FEAT-ERP-HRCORE-002 |
| Tính năng: Cost Rate Card | `../../../../phase2-features/bcerp-web/hr-core/cost-rate-card-version-hoa-tham-dinh-finance.md` | FEAT-ERP-HRCORE-006 |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | §6.5 COMP-ERP-005 (API-ERP-062/063/067) + PII/RBAC/Audit |
| Design system | `../../../design-system.md` | Tokens + MaskedField pattern + W2/W4 |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | S20 — `/hr/records`, badge `{hodl_sap_het_han}` |
| Screen liên quan | `./screens-leave.md` | S21 — nghỉ phép đọc hồ sơ SSOT |
| Mobile counterpart | `../../../mobile-internal` | M5 Hồ sơ cá nhân (masked, read-only) |
