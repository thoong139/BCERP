# Screen Group: TKQC Registry (Ad Account Command Center)

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `adacc` (MOD-ADACCOUNT-CC)
> **Tính năng:** FEAT-ERP-ADACC-001..003
> **Route:** `/ops/ad-accounts`
> **Main UI-ID:** `UI-WEB-ADACC-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

Implements: FEAT-ERP-ADACC-001 (KYC gate), FEAT-ERP-ADACC-002 (registry & vòng đời), FEAT-ERP-ADACC-003 (Financial Hard Stop — phần hiển thị + tạo lệnh nạp; action khớp tiền nằm ở S7 `/finance/wallet`, deep-link S7↔S9).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Main UI-ID | `UI-WEB-ADACC-001` |
| Route | `/ops/ad-accounts` |
| Loại | List (registry grid R6, pattern W2 split view) + Detail pane (Ad Account 360) |
| FEAT-ID | FEAT-ERP-ADACC-001, FEAT-ERP-ADACC-002, FEAT-ERP-ADACC-003 |
| Workspace | Ops (`/ops`) |
| Đối tượng nghiệp vụ | TKQC Ad Account (registry ~2.600+ TK, 7 nền tảng: Meta, Google, TikTok, Bing, X, Pinterest, Yandex) + OadsRequest + ReplacementRequest + TopupProposal (lệnh đề xuất nạp) |
| Vai trò chính | OPS_ADS, OPS_AM (thao tác vòng đời) |
| Vai trò liên quan | OPS_PLAN (duyệt owner/backup, danh mục nền tảng, đóng TK) · OPS_CONT (soạn/duyệt OADS, EXECUTIVE+) · OPS_DES/OPS_EDIT (view-only TK gắn dự án mình) · FIN_L1/L2 (read-only — trạng thái khớp tiền) |
| Workflow stage | `kyc_required` → `kyc_verified` → `registered` → `pre_spend_hardstop_check` → `active` → `suspended/closed` |

**Checklist workflow context (Bước 0):** (A) Object: TKQC Ad Account — registry trung tâm thay 2.600+ Sheets rời rạc. (B) Actor chính: OPS_ADS/OPS_AM. (C) Liên phòng: FIN (hard stop khớp tiền — nguồn sự thật), HR (sự kiện offboard → revoke 24h), Integration GW (sync số dư hourly, nhãn `manual` khi degraded), SLANOT (alert die/thiếu owner), CAMP (campaign gắn TK), Client 360 S28. (D) Lifecycle 6 stage + 2 gate độc lập bắt buộc cùng thỏa trước cấp phát: KYC = Verified **và** Hard Stop "đã khớp tiền" (FIN_L1). (E) Dependency chéo: S7 Ví & Đối soát (action khớp tiền), S4 Handoff (task sinh TK), S14 Campaign. (F) Thông tin cần: số dư, spend limit, vòng đời, trạng thái platform (ACTIVE/FROZEN/BLOCKED/OUT_OF_MONEY), freshness, owner/backup, naming/UTM, Contract. (G) Quyết định: đăng ký TK, yêu cầu cấp phát, ghi nhận die, đề xuất thay thế, suspend/close. (H) Action: theo ma trận phân quyền FEAT-ERP-ADACC-002 §4 — KHÔNG có nút khớp tiền (S7), KHÔNG có mở khóa gate (không tồn tại), KHÔNG có xóa (không tồn tại interface xóa). (I) Exception: gate đang khóa, KYC chưa Verified, thiếu owner/backup, platform FROZEN/BLOCKED/OUT_OF_MONEY, die thiếu evidence, dữ liệu `manual`, campaign mồ côi. (J) 1 surface duy nhất cho cả OPS thao tác lẫn FIN xem read-only — không nhân bản theo vai.

---

## 1. TRANG CHÍNH

### 1.1. Layout — pattern W2 split view (registry 55% trái + Ad Account 360 pane 45% phải)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ Ops > TKQC Registry                                            [+ Đăng ký TKQC]     │
│ TKQC Registry — 2.614 TK · 7 nền tảng        freshness GW ≤1h · cập nhật 14:05      │
├─────────────────────────────────────────────────────────────────────────────────────┤
│ ⚠ 23 TK đang chờ FIN_L1 khớp tiền — nút cấp phát chỉ mở khi Hard Stop + KYC đủ     │
│ [Tìm mã TK / khách / external ID…        ] [Bộ lọc ▾]         [Cột ▾] [Views ▾]    │
│ (Chờ khớp tiền · 23×) (Platform lỗi · 8×) (Thiếu owner/backup · 5×) (Die · 12×)    │
├───────────────────────────────────────────────┬─────────────────────────────────────┤
│ MÃ TK · KHÁCH · NỀN TẢNG · VÒNG ĐỜI · SỐ DƯ…  │ AD ACCOUNT 360                       │
│───────────────────────────────────────────────│ FMCG01-META-CONV-VN-2609            │
│ FMCG01-META-CONV-VN-2609  FMCG01  Meta        │ [Đang vận hành] Platform: ACTIVE    │
│  [Đang vận hành] · ACTIVE · 84,2 tr ₫ · NV.An │ Meta · external: 12…901             │
│ F&B02-TIKTOK-CONV-VN-2609  F&B02  TikTok      │ ─────────────────────────────────── │
│  [Chờ khớp tiền] · 🔒HARD STOP · ⏳ chờ FIN_L1│ [T1 Tổng quan][T2 Vận hành]         │
│   2 ngày 4 giờ · ⚠ chưa khớp tiền — FIN xử lý │ [T3 Die & thay thế][T4 Hoạt động]   │
│   tại Ví & Đối soát · 12,5 tr ₫ (manual 13:00)│ (nội dung tab — xem §2)             │
│ RET03-GOOGLE-TRAF-US-2608  RET03  Google      │ Owner: NV.An · Backup: NV.Bình      │
│  [Đang vận hành] · OUT_OF_MONEY · 0,8 tr ₫ ⚠  │ [Đề xuất nạp] [Ghi nhận die] [⋯]    │
│───────────────────────────────────────────────│                                     │
│ ← 1 2 3 … 131 →   20 | 50 | 100 dòng   2.614 TK                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

Banner đầu trang (WarningIndicator, không dismiss) hiển thị khi tồn tại TK ở `pre_spend_hardstop_check`: "chuyện gì — FIN_L1 cần khớp tiền tại Ví & Đối soát (deep-link S7) — đã chờ bao lâu". Với FIN_L1 banner kèm nút "Mở S7 khớp tiền"; với OPS chỉ là trạng thái chờ (WaitingOnIndicator).

### 1.2. Components

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| DataTable | compact (row 32px), sticky header, sort theo header, column config persist | Density tiền/vận hành; cột tiền right-align `tabular-nums` |
| SearchInput | debounce 300ms, server-side | Tìm theo mã naming, tên khách, `externalAccountId` |
| Quick filter chips | server-side, tháo từng chip | Chip = filter đã lưu: chờ khớp tiền, platform lỗi, thiếu owner/backup, die |
| Filter panel | `platform, status (vòng đời), platform_status, customer_id, owner_id, tier` | Theo API-ERP-044 |
| Pagination | server-side, 20/50/100 | 2.600+ TK — luôn server-side |
| WaitingOnIndicator | inline trong row + khối trong pane | "chờ FIN_L1 khớp tiền 2 ngày 4 giờ" — click mở modal nhắc FIN |
| WarningIndicator | inline (row) + banner (trang/pane) | Hard stop, OUT_OF_MONEY, thiếu owner, dữ liệu `manual` — bắt buộc 3 phần: chuyện gì / ai làm / hạn |
| MoneyDisplay | plain VND + multi-currency (nguồn USD + tỷ giá + ngày áp) + nhãn freshness | Số dư/spend luôn kèm nguồn + timestamp sync; degraded = badge `manual` |
| Bulk actions | **Không dùng** | Mọi hành động ghi qua state machine + guard + audit per-object; bulk dễ vượt guard — thiết kế cố ý |

**Không có bulk bar** là quyết định thiết kế (an toàn tiền): không tồn tại thao tác "chọn nhiều TK rồi bật chi tiêu".

### 1.3. Cột / Trường Hiển Thị

| Tên | Trường | Định dạng | Sắp xếp | Rộng |
|-----|--------|----------|---------|------|
| Mã TK | `naming` (NamingUtmRecord) | Text mono — link mở pane | Có | 220px |
| Khách | `customer.name` | Text + link Client 360 (S28) | Có | 160px |
| Nền tảng | `platform` | Icon + text (7 platform) | Có | 90px |
| Vòng đời | `lifecycle_stage` | StatusBadge (bảng dưới) | Có | 130px |
| Hard stop | hard-stop-status theo khách | Icon 🔒 khóa / mở (read-only từ FIN) | Không | 90px |
| Platform status | `platform_status` (GW sync) | Badge: ACTIVE/FROZEN/BLOCKED/OUT_OF_MONEY | Có | 130px |
| Số dư | số dư + currency + freshness | MoneyDisplay + nhãn nguồn `api`/`manual` | Có | 140px |
| Owner | `owner` (+ thiếu → ⚠) | Avatar + tên; tooltip backup | Có | 120px |
| Exception | tổng hợp | WarningIndicator inline | Không | auto |

**Badge vòng đời (10 token trạng thái design-system):**

| Giá trị | Nhãn | Token |
|---------|------|-------|
| `kyc_required` | Chờ KYC | pending |
| `kyc_verified` | KYC đã xác minh | info |
| `registered` | Đã đăng ký | info |
| `pre_spend_hardstop_check` | Chờ khớp tiền | pending |
| `active` | Đang vận hành | approved |
| `suspended` | Tạm dừng | sla-warning |
| `closed` | Đã đóng | draft |

Trạng thái platform: ACTIVE → approved; FROZEN → sla-warning; BLOCKED → rejected; OUT_OF_MONEY → overdue + icon ví (đỏ tiền luôn kèm icon + câu giải thích, không chỉ màu).

### 1.4. Hành Động Chính

| Sự kiện | Hành động | Kết quả |
|---------|---------|--------|
| Chọn hàng | Mở Ad Account 360 pane phải (không rời trang) | Chi tiết + giữ context grid |
| [+ Đăng ký TKQC] | Mở Dialog D1 | Chỉ khách KYC Verified; naming/UTM tự sinh |
| [Đề xuất nạp] (pane) | Mở Dialog D2 | Tạo lệnh hệ thống gửi FIN — input duy nhất FIN chấp nhận |
| [Ghi nhận die] (pane) | Mở Dialog D3 | Revoke/die + evidence bất biến |
| [Đề xuất thay thế] (pane) | Mở Dialog D4 | ReplacementRequest gán tay TK mới |
| Row action "⋯" → Chuyển trạng thái | Dialog D6 | `transitions` — nút cấp phát ẨN khi chưa đủ 2 gate (PEP) |
| Row action "⋯" → Đề xuất đổi owner/backup | Dialog D5 | Gửi OPS_PLAN duyệt ≤1 ngày làm việc |
| Row action "⋯" → Trạng thái Hard Stop | Sheet S2 | Read-only + deep-link S7 |
| Deep-link từ S7 (`/finance/wallet?focus=ad-account:{id}`) | Focus row + mở pane | Về nguồn: breadcrumb giữ "Ops > TKQC Registry", nút "Về nguồn" |

### 1.5. States

- **Loading:** skeleton 10 hàng grid; pane skeleton 3 khối.
- **Empty:** EmptyState "Không có TK khớp bộ lọc" + CTA "Xóa bộ lọc" hoặc (chip Chờ khớp tiền rỗng) "Không có TK nào chờ khớp tiền — tốt".
- **Error:** hàng lỗi + retry per-row; lỗi gate (`HARD_STOP_ACTIVE` 409) → toast error không tự đóng + banner lý do.
- **Freshness:** header hiển thị lần sync GW cuối; dữ liệu cũ >1h hoặc `manual` gắn badge `--state-manual` vĩnh viễn trên record + dòng audit.

### 1.6. Phân Quyền (PEP — action thiếu quyền bị ẨN, không disabled)

| Thành phần | OPS_ADS | OPS_AM | OPS_PLAN | OPS_CONT | OPS_DES/EDIT | FIN_L1/L2 | SYS_ADMIN |
|-----------|---------|--------|----------|----------|--------------|-----------|-----------|
| Xem registry toàn bộ | ✅ | ✅ | ✅ | ✅ | ❌ (chỉ TK gắn dự án mình — data-scope) | ✅ read-only | ❌ |
| [+ Đăng ký TKQC] | ✅ | ✅ (theo booking) | ✅ (duyệt danh mục nền tảng) | ẩn | ẩn | ẩn | ẩn |
| [Đề xuất nạp] (D2) | ✅ | ✅ | ẩn | ẩn | ẩn | ẩn (nhận lệnh ở S7) | ẩn |
| [Ghi nhận die + evidence] (D3) | ✅ | ✅ | ✅ (duyệt đóng TK) | ẩn | ẩn | ẩn | ẩn |
| [Đề xuất thay thế] (D4) | ✅ (đề xuất) | ✅ (gán tay) | ✅ (duyệt đóng TK) | ẩn | ẩn | ẩn | ẩn |
| Chuyển trạng thái (D6) | theo state | ✅ | ✅ | ẩn | ẩn | ẩn (không thao tác) | ẩn |
| Đổi owner/backup (D5) | ✅ đề xuất | ✅ đề xuất | ✅ duyệt | ẩn | ẩn | ẩn | ẩn |
| Sửa naming/UTM tay | ẩn | ẩn | ✅ (chỉ chuẩn riêng đã duyệt) | ẩn | ẩn | ẩn | ẩn |
| Nút cấp phát / bật chi tiêu | ẨN đến khi Hard Stop mở + KYC Verified (Navigation §4.1) | same | same | ẩn | ẩn | ẩn | ẩn |
| Mở khóa gate / xóa TK | **Không tồn tại ở mọi vai** — không render, không có nhánh code kiểm tra quyền mở khóa | | | | | | |

FIN vào surface này thấy banner "Chế độ read-only — hành động khớp tiền nằm tại Ví & Đối soát" + deep-link `/finance/wallet`. Toàn bộ thao tác ghi qua API core, audit log bất biến.

---

## 2. TABS

Tabs của **Ad Account 360 pane** (panel tabs). Header context (mã TK, badge vòng đời, platform status, owner, nút action chính) giữ nguyên khi chuyển tab — global context record không mất.

| Tab | UI-ID | Nội dung | Hiện khi nào |
|-----|-------|----------|--------------|
| T1 — Tổng quan & Gates | `UI-WEB-ADACC-001-T1` | Mặc định | Luôn |
| T2 — Vận hành & Liên kết | `UI-WEB-ADACC-001-T2` | Mặc định | Luôn |
| T3 — Die & Thay thế | `UI-WEB-ADACC-001-T3` | Mặc định (badge số die) | Luôn |
| T4 — Hoạt động | `UI-WEB-ADACC-001-T4` | Mặc định | Luôn |

### Tab T1 — Tổng quan & Gates
- **Mục tiêu:** trả lời trong 5 giây "TK này đang stage nào, chờ ai, còn thiếu gate gì".
- **Thông tin:** ProgressTracker lifecycle 6 node (kyc_required → … → closed) mỗi node kèm người giữ + thời gian chờ (WaitingOnIndicator); **2 card gate bắt buộc cạnh nhau**: (1) KYC pháp nhân — trạng thái `KycProfile` của khách (Verified / đang xét / quá hạn review 12/6 tháng) + link dialog D7; (2) Financial Hard Stop — LOCKED/OPEN/LOCKED+SPEND_PAUSED **read-only từ FIN**, kèm lệnh nạp tương ứng + căn cứ khớp tiền; hệ thống tính và hiển thị "còn thiếu gì" khi 1 trong 2 gate chưa thỏa (không bao giờ gộp điều kiện). Ngân sách & chi tiêu: MoneyDisplay (ngân sách hạn mức, chi tiêu kỳ, số dư) + freshness; Ví liên kết: ví giữ hộ của khách (tên ví + số dư tham chiếu read-only + deep-link S7); Người phụ trách: owner + backup (avatar, click mở D5); Nền tảng: platform + `externalAccountId` + `bindInfo` theo payload riêng từng platform (TikTok = BC + role, Google = email, Facebook = BMID).
- **Components:** ProgressTracker, 2 ApprovalCard-style gate card (không có nút duyệt — chỉ trạng thái + link), MoneyDisplay, WarningIndicator khi gate thiếu.
- **Actions:** Đề xuất nạp (D2), Yêu cầu cấp phát/chuyển trạng thái (D6 — ẩn khi gate chưa đủ).
- **States:** gate card loading skeleton; KYC chưa có hồ sơ → EmptyState "Chưa có hồ sơ KYC — tạo ở D7" (chỉ OPS_AM thấy nút).
- **Permissions:** mọi vai xem được; action theo §1.6.
- **Quan hệ tab khác:** T3 hiển thị hệ quả die; T4 lịch sử gate.

### Tab T2 — Vận hành & Liên kết
- **Mục tiêu:** ngữ cảnh vận hành + ràng buộc cross-module của TK.
- **Thông tin:** naming/UTM (đầy đủ `utm_source/medium/campaign`, readonly — chặn sửa tay, chỉ OPS_PLAN sửa khi có ngoại lệ đã duyệt, hiển thị người duyệt + lý do trong change log); Contract hiện hành (`serviceType` RENTAL/MANAGED bất biến, `fee_percent`, `pmsProjectId` chỉ khi MANAGED, các Contract cũ TERMINATED giữ lịch sử); campaign gắn TK (từ S14 — summary: tên, trạng thái, deliverable sắp hạn; campaign không gắn project → ⚠ "mồ côi, tự pause, task 4h"); AccessGrant (ai có quyền gì — RBAC 4 mức, revoke 24h theo sự kiện HR, countdown nếu owner sắp nghỉ).
- **Components:** mô tả trường dạng definition-list, Timeline rút gọn cho change log naming, WarningIndicator campaign mồ côi.
- **Actions:** mở campaign ở S14 (deep-link), yêu cầu ngoại lệ naming (D5-pattern — gửi OPS_PLAN).
- **States:** lazy-load khi mở tab (performance);campaign rỗng → EmptyState "Chưa có campaign gắn TK".
- **Permissions:** OPS_DES/OPS_EDIT thấy tab này ở chế độ read-only cho TK gắn dự án mình.

### Tab T3 — Die & Thay thế
- **Mục tiêu:** quản lý rủi ro die + chuỗi thay thế bất biến.
- **Thông tin:** danh sách DieEvidence (loại, hash, `captured_at`, người chụp — append-only, không sửa/xóa); chuỗi thay thế `replacesAdAccountId` (TK gốc → các TK thay kế tiếp, sơ đồ line); `isCustomerFault` + `balanceTransferredAmount` từng lần thay; thống kê tần suất khóa theo platform/khách (đầu vào quyết định nạp mới của OPS_PLAN); TK dự phòng hiện có của khách (⚠ nếu thiếu — cảnh báo rủi ro cấp team).
- **Components:** Timeline evidence (icon `file-manual` cho entry hệ thống/GW), mini graph chuỗi thay thế, DataTable evidence.
- **Actions:** Ghi nhận die + upload evidence (D3), Đề xuất thay thế (D4).
- **States:** chưa từng die → EmptyState "TK chưa có sự cố die nào được ghi nhận".
- **Permissions:** OPS_DES/EDIT chỉ xem evidence của TK trong scope; FIN xem read-only.

### Tab T4 — Hoạt động
- **Mục tiêu:** audit trail đầy đủ phục vụ đối soát gate và thanh tra.
- **Thông tin:** Timeline từ audit object timeline: mọi transition (ai, khi nào, from→to, căn cứ — lệnh nạp, xác nhận FIN), mọi sự kiện gate (chặn, mở, thu hồi, yêu cầu mở khóa bị từ chối + người yêu cầu), sự kiện sync GW (icon hệ thống), event HR (offboard → revoke).
- **Components:** Timeline full; filter theo loại event; relative + absolute timestamp.
- **Actions:** chỉ đọc; "Xuất tra cứu" chuyển sang S25 Audit Log Query (không xuất tại đây).
- **States:** lazy-load 20 entry/batch; empty "Chưa có hoạt động".
- **Permissions:** FIN_L1 thấy đủ lịch sử gate; OPS thấy theo scope; event evidence hash-chain hiển thị dấu kiểm toàn vẹn.

---

## 3. DIALOGS

| # | Dialog | UI-ID | Loại | Mở khi nào |
|---|--------|-------|------|-----------|
| 1 | Đăng ký TKQC mới | `UI-WEB-ADACC-001-D1` | Form | [+ Đăng ký TKQC] |
| 2 | Đề xuất nạp (TopupProposal) | `UI-WEB-ADACC-001-D2` | Form tiền | [Đề xuất nạp] trong pane |
| 3 | Ghi nhận die + evidence | `UI-WEB-ADACC-001-D3` | Form + upload | [Ghi nhận die] |
| 4 | Đề xuất thay thế (ReplacementRequest) | `UI-WEB-ADACC-001-D4` | Form | [Đề xuất thay thế] |
| 5 | Đề xuất đổi owner/backup | `UI-WEB-ADACC-001-D5` | Form + AssigneePicker | Row "⋯" |
| 6 | Xác nhận chuyển trạng thái | `UI-WEB-ADACC-001-D6` | Confirm có ngữ cảnh | Row "⋯" → Chuyển trạng thái |
| 7 | Hồ sơ KYC của khách | `UI-WEB-ADACC-001-D7` | Read-only panel | Click card gate KYC (T1) |

### 3.1. D1 — Đăng ký TKQC mới (Form)
- **Fields:** Khách (Combobox — **chỉ liệt kê khách KYC Verified**, khách chưa Verified bị loại khỏi danh sách + footnote lý do REQ-FIN-009); Nền tảng (7 platform, theo danh mục OPS_PLAN duyệt); Loại TK (BC-managed / client-owned / internal-sandbox — sandbox không gắn khách, client-owned không BC nạp tiền); Booking/dự án; externalAccountId; currency/timezone/country; bindInfo (placeholder động theo platform); Owner + Backup (AssigneePicker — bắt buộc đủ 2, BR-002).
- **Naming:** tự sinh theo mẫu `[ClientCode]-[Platform]-[Objective]-[Market]-[YYMM]`, preview readonly + UTM 3 trường tự sinh; không có ô nhập tay (ngoại lệ chuẩn riêng chỉ OPS_PLAN làm sau khi tạo).
- **Actions:** [Tạo] → `POST /api/v1/erp/ad-accounts` (API-ERP-043); lỗi validator naming → field-level error; Hủy → đóng.
- **States:** processing khóa nút; thành công → toast + focus row mới.

### 3.2. D2 — Đề xuất nạp (Form tiền)
- **Fields:** Khách (lock theo TK đang chọn); TKQC (nếu tạo từ row); Số tiền + currency; Tỷ giá (snapshot tại thời điểm tạo); Căn cứ (text bắt buộc — booking/HĐ); checkbox "Ưu tiên khẩn" (nhắc FIN_L1 on-call SLA 4h — vẫn đầy đủ bước, không bỏ bước BR-010).
- **Quy tắc hiển thị:** mô tả "lệnh này là input duy nhất FIN_L1 đối chiếu — cấm xác nhận miệng"; sau khi gửi, trạng thái lệnh thấy ở view M3.
- **Actions:** [Gửi FIN] → tạo lệnh hệ thống — `[NEEDS_REVIEW: thiếu endpoint tạo TopupProposal bởi OPS trong api-contract.md — hiện chỉ có API-ERP-022 (FIN_L1)]`.
- **SoD:** người tạo lệnh không thể tự khớp tiền — UI không render nút nào hướng tới khớp tiền.

### 3.3. D3 — Ghi nhận die + evidence
- **Fields:** Loại sự cố (FROZEN/BLOCKED/hết tiền/phát hiện GW); Evidence: upload snapshot số dư, thông báo platform — bắt buộc ≥1 file, timestamp tự chụp tại thời điểm nộp; mô tả. Cảnh báo trong dialog: "evidence lưu bất biến (hash) — không sửa/xóa hậu kiểm".
- **Actions:** [Ghi nhận] → `POST /api/v1/erp/ad-accounts/{id}/revoke` (API-ERP-046 — đánh dấu die/thu hồi) + upload evidence `[NEEDS_REVIEW: thiếu endpoint DieEvidence upload riêng — API-ERP-046 chưa tường minh phần file]`; kích hoạt TK dự phòng = task gợi ý sau khi ghi nhận (SLA 4h).
- **Confirm:** modal xác nhận có ngữ cảnh (tên TK + hệ quả: dừng hạch toán, gợi ý thay thế).

### 3.4. D4 — Đề xuất thay thế (ReplacementRequest)
- **Fields:** TK bị khóa (lock); Lý do (bắt buộc ≥10 ký tự); `isCustomerFault` (toggle + cảnh báo: gán sai = sai lệch doanh thu, audit bắt buộc); TK thay thế (chọn từ nguồn cung nội bộ — chỉ TK registered chưa bật chi tiêu); SLA miễn phí hiển thị tự động theo `isCustomerFault`.
- **Actions:** [Tạo request] → `[NEEDS_REVIEW: thiếu endpoint ReplacementRequest]`; sau tạo: state `PENDING → CS_ASSIGNED → BALANCE_TRANSFERRED → COMPLETED` theo dõi ở tab T3.
- **Quy tắc:** TK thay thế vẫn phải qua Hard Stop khớp tiền riêng trước khi bật chi tiêu — hiển thị trong dialog.

### 3.5. D5 — Đề xuất đổi owner/backup
- **Fields:** Vị trí (owner/backup); người mới (AssigneePicker — chỉ trong dept scope); lý do. OPS_PLAN duyệt ≤1 ngày làm việc.
- **Actions:** [Gửi duyệt] → `[NEEDS_REVIEW: thiếu endpoint gán/đổi owner + duyệt]`; trạng thái chờ duyệt hiển thị bằng WaitingOnIndicator tại T1.

### 3.6. D6 — Xác nhận chuyển trạng thái (Confirm)
- **Nội dung:** trạng thái hiện tại → trạng thái đích, người thực hiện, hệ quả (bật chi tiêu/pause/đóng); **lý do bắt buộc** khi suspend/close; khi chuyển `pre_spend_hardstop_check → active` mà gate chưa đủ, nút không tồn tại — nếu API vẫn bị gọi, core trả `HARD_STOP_ACTIVE` (409) → toast lỗi tiền không tự đóng + banner.
- **Actions:** [Xác nhận] → `POST /api/v1/erp/ad-accounts/{id}/transitions` (API-ERP-045, body `{ "to_state": "...", "reason": "..." }`); Idempotency-Key cho lệnh ghi tiền; response hiển thị `guards_passed`.

### 3.7. D7 — Hồ sơ KYC của khách (Read-only panel)
- **Nội dung:** trạng thái `KycProfile` (5 thành phần bắt buộc, diện EDD, hạn review tiếp theo, lý do từ chối nếu có — bản tóm tắt cho góc OPS; giấy tờ chi tiết che mặt). Thao tác xác minh thuộc FIN_L2 (không có nút tại đây).
- **Actions:** OPS_AM: "Nhập/bổ sung hồ sơ KYC" → `[NEEDS_REVIEW: thiếu endpoint KycProfile CRUD/xác minh trong api-contract.md]`; đóng.
- **States:** khách chưa có hồ sơ → EmptyState + nút nhập (chỉ OPS_AM).

---

## 4. SHEETS

| # | Sheet | UI-ID | Vị trí | Mở khi nào |
|---|-------|-------|--------|-----------|
| 1 | Ad Account 360 | `UI-WEB-ADACC-001-S1` | Panel phải đẩy nội dung, 720px | Chọn hàng trong grid (mặc định) |
| 2 | Trạng thái Hard Stop & lịch sử gate | `UI-WEB-ADACC-001-S2` | Panel phải 480px | Row "⋯" → Trạng thái Hard Stop; click icon 🔒 |

### 4.1. Sheet: Ad Account 360 (S1)
- **Kích thước:** 720px (detail sâu), footer sticky chứa action chính (Đề xuất nạp / Ghi nhận die / ⋯).
- **Cấu trúc:** header = mã TK (mono) + badge vòng đời + platform status + nút đóng; tabs T1–T4 (§2); giữ context grid bên trái (không overlay toàn màn), Esc đóng, focus trả về hàng vừa mở.
- **States:** loading skeleton; lỗi tải → khối lỗi + retry; dữ liệu degraded → banner `manual` trên đầu sheet.

### 4.2. Sheet: Trạng thái Hard Stop & lịch sử gate (S2)
- **Kích thước:** 480px — contextual info gần ngữ cảnh quyết định.
- **Nội dung (read-only 100%):** trạng thái gate hiện tại (LOCKED / OPEN / LOCKED+SPEND_PAUSED) + `last_changed_at` + căn cứ (`basis_proposal_id` — lệnh nạp, xác nhận FIN); lệnh nạp liên quan + trạng thái từng lệnh (CREATED/WAITING_MATCH/MATCHED/REVOKED/CANCELLED); lịch sử OverrideDenialLog (yêu cầu mở khóa bị từ chối — ai, khi nào, lý do) chứng minh "không có đường mở khóa"; GateAuditLog hash-chain.
- **Actions:** FIN_L1: nút "Khớp tiền tại Ví & Đối soát" → deep-link `/finance/wallet` (action thật nằm S7, API-ERP-026); OPS: chỉ thấy "đang chờ FIN_L1 — nhắc" (modal nhắc).
- **Quy tắc:** sheet này không có bất kỳ control nào thay đổi trạng thái gate — cấm cả disabled button gợi ý khả năng.

---

## 5. VIEW MODES

| Mode | UI-ID | Icon | Hiện khi nào |
|------|-------|------|--------------|
| M1 — Registry TKQC | `UI-WEB-ADACC-001-M1` | `table` | Default (§1) |
| M2 — Yêu cầu mở TKQC (OADS) | `UI-WEB-ADACC-001-M2` | `inbox` | Toggle view — queue OPS_CONT |
| M3 — Lệnh nạp chờ khớp tiền | `UI-WEB-ADACC-001-M3` | `wallet` | Toggle view — theo dõi gate |

### Mode M2 — Queue Yêu cầu mở TKQC (OADS)
- **Mục tiêu:** worklist hồ sơ mở TK mới theo state machine `DRAFT → CONTENT_REVIEWING → CS_REVIEWING → CS_APPROVED` (reject kèm reason + evidence quay về DRAFT; CS_APPROVED tự tạo 1 AdAccount + 1 Contract ACTIVE).
- **Cột:** mã request · khách (+ badge KYC Verified/chưa — request không khởi động được khi KYC ≠ Verified) · nền tảng · stage (StatusBadge) · người giữ (WaitingOnIndicator + SLA chờ duyệt hiển thị để ép tiến độ, không bỏ bước) · reject reason gần nhất.
- **Actions:** Soạn/sửa hồ sơ (OPS_CONT mọi cấp track — INTERN/JUNIOR chỉ soạn); Duyệt/Từ chối CONTENT (chỉ EXECUTIVE+ — nút ẩn với cấp dưới, BR-009/SC-002); Thiết lập thông số CS (OPS_AM: BC, advertiser, currency, timezone, fee schedule); mọi từ chối bắt buộc reason + evidence (modal có 2 ô này).
- **States/Permissions:** empty "Không có yêu cầu nào ở stage này"; list lazy-load; OPS_ADS/PLAN xem, chỉ OPS_CONT thao tác nội dung.

### Mode M3 — Lệnh nạp chờ khớp tiền
- **Mục tiêu:** danh sách TopupProposal `WAITING_MATCH` theo khách mình phụ trách (FEAT-ERP-ADACC-003 US4) — OPS chủ động theo dõi tiến độ khớp tiền với FIN, báo khách đúng thời điểm.
- **Cột:** mã lệnh · khách · TKQC · số tiền (MoneyDisplay) · tỷ giá · created_at · trạng thái lệnh · WaitingOnIndicator "chờ FIN_L1 X giờ" (màu theo SLA; khẩn = chip on-call 4h).
- **Actions:** hủy lệnh (người tạo + OPS_PLAN, lý do bắt buộc, lệnh đã gửi không sửa — hủy + tạo mới) `[NEEDS_REVIEW: thiếu endpoint hủy TopupProposal]`; yêu cầu xử lý khẩn (nhắc FIN on-call); không có cột action khớp tiền.
- **States:** rỗng → "Không có lệnh nào chờ khớp tiền"; lệnh MATCHED/REVOKED rời queue, thấy lại trong T4/S2.

---

## 6. API ENDPOINTS

Endpoints THẬT từ `phase3-architecture/technical-specs/api-contract.md` (§6.3 COMP-ERP-003 — MOD-ADACCOUNT-CC; §6.2 ví; §COMP-CORE audit):

| Khi nào | Method | Endpoint | Tham số / Ghi chú |
|---------|--------|----------|-------------------|
| Tải grid / tìm / lọc / sort / phân trang | GET | `/api/v1/erp/ad-accounts` (API-ERP-044) | `?platform=&status=&customer_id=&tier=&search=&page=&limit=20|50|100&sort=` — response gắn trạng thái sync/manual + freshness từ GW |
| Đăng ký TKQC (D1) | POST | `/api/v1/erp/ad-accounts` (API-ERP-043) | Body: khách/platform/owner/backup/externalAccountId/bindInfo; guard KYC `kyc_required` trước khi tạo |
| Chuyển vòng đời (D6, quick "Cấp phát") | POST | `/api/v1/erp/ad-accounts/{id}/transitions` (API-ERP-045) | Body `{ "to_state", "reason?" }`; guard hard stop check API-ERP-027 tại nguồn; chưa khớp tiền → 409 `HARD_STOP_ACTIVE` |
| Ghi nhận die / thu hồi 24h (D3) | POST | `/api/v1/erp/ad-accounts/{id}/revoke` (API-ERP-046) | Phát alert SLANOT |
| Trạng thái Hard Stop (S2, card gate T1) | GET | `/api/v1/erp/wallets/{customerId}/hard-stop-status` (API-ERP-027) | Read-only; re-validate tại nguồn; render icon 🔒 grid |
| Timeline hoạt động (T4) | GET | `/core/audit/objects/:objectId/timeline` (API-CORE-030) | Feed per TKQC; mọi lượt query tự ghi audit |
| Alert die / thiếu owner (banner, chips) | GET | `/core/alerts/instances` (API-CORE-043) | `?status=open&severity=&source=adaccount` — rule die account, thiếu owner |
| Chi tiêu / sao kê TK (T1, T2) | GET | `/gw/statements` (API-GW-032) | `?platform=&adaccountRef=&windowFrom=&windowTo=` — nhãn `api|manual` immutable + freshness |
| Deep-link S7 (FIN khớp tiền — tham chiếu, action không nằm ở đây) | POST | `/api/v1/erp/wallets/{customerId}/hard-stop/confirm` (API-ERP-026) | FIN_L1 + MFA — thuộc S7 `/finance/wallet`; S9 chỉ deep-link |
| Chuyển pane view mode | — | client-side routing `/ops/ad-accounts?view=registry|oads|topups` | Không tốn endpoint riêng |

**[NEEDS_REVIEW] — endpoint thiếu trong api-contract.md, KHÔNG bịa:**
1. `TopupProposal` — tạo/hủy lệnh đề xuất nạp bởi OPS (D2, M3). Hiện chỉ có API-ERP-022 (wallet transactions, FIN_L1).
2. `OadsRequest` — CRUD + state machine OADS (M2, D7 flow).
3. `ReplacementRequest` — tạo/gán TK thay/chuyển số dư (D4, T3).
4. `DieEvidence` — upload evidence bất biến (D3) — API-ERP-046 chưa tường minh phần file/hash.
5. Gán/đổi owner + backup và duyệt bởi OPS_PLAN (D5).
6. `Contract` TKQC (serviceType/fee/pmsProjectId) — đọc + tất toán/mở HĐ mới (T2).
7. `KycProfile` — đọc trạng thái/nhập hồ sơ góc OPS (D7, card gate T1) — hiện KYC chỉ xuất hiện dưới dạng guard của API-ERP-043/045.

---

## 7. UI-ID Registry

| UI-ID | Loại | Mô tả |
|-------|------|-------|
| `UI-WEB-ADACC-001` | Main Page | TKQC Registry — split view grid + pane, route `/ops/ad-accounts` |
| `UI-WEB-ADACC-001-T1` | Tab (pane) | Tổng quan & Gates — lifecycle progress, KYC + Hard Stop card, ngân sách/chi tiêu, ví liên kết, owner, nền tảng |
| `UI-WEB-ADACC-001-T2` | Tab (pane) | Vận hành & Liên kết — naming/UTM, Contract, campaign gắn, AccessGrant |
| `UI-WEB-ADACC-001-T3` | Tab (pane) | Die & Thay thế — evidence bất biến, chuỗi replacement, thống kê die |
| `UI-WEB-ADACC-001-T4` | Tab (pane) | Hoạt động — audit timeline + lịch sử gate |
| `UI-WEB-ADACC-001-D1` | Dialog | Đăng ký TKQC mới (naming tự sinh, guard KYC) |
| `UI-WEB-ADACC-001-D2` | Dialog | Đề xuất nạp (TopupProposal — input duy nhất FIN đối chiếu) |
| `UI-WEB-ADACC-001-D3` | Dialog | Ghi nhận die + upload evidence bất biến |
| `UI-WEB-ADACC-001-D4` | Dialog | Đề xuất thay thế (ReplacementRequest, isCustomerFault) |
| `UI-WEB-ADACC-001-D5` | Dialog | Đề xuất đổi owner/backup (gửi OPS_PLAN duyệt) |
| `UI-WEB-ADACC-001-D6` | Dialog | Xác nhận chuyển trạng thái (reason bắt buộc, guard gate) |
| `UI-WEB-ADACC-001-D7` | Dialog | Hồ sơ KYC của khách (read-only góc OPS) |
| `UI-WEB-ADACC-001-S1` | Sheet | Ad Account 360 (720px panel phải, tabs T1–T4) |
| `UI-WEB-ADACC-001-S2` | Sheet | Trạng thái Hard Stop & lịch sử gate (480px, read-only, deep-link S7) |
| `UI-WEB-ADACC-001-M1` | View Mode | Registry TKQC (mặc định) |
| `UI-WEB-ADACC-001-M2` | View Mode | Queue Yêu cầu mở TKQC (OADS state machine) |
| `UI-WEB-ADACC-001-M3` | View Mode | Queue Lệnh nạp chờ khớp tiền (WAITING_MATCH) |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../../phase2-features/bcerp-web/adaccount-cc/ad-account-command-center-registry-va-vong-doi-tkqc.md` | Upstream — FEAT-ERP-ADACC-002 |
| Tính năng nghiệp vụ | `../../../../phase2-features/bcerp-web/adaccount-cc/kyc-phap-nhan-truoc-cap-phat-tkqc.md` | Upstream — FEAT-ERP-ADACC-001 |
| Tính năng nghiệp vụ | `../../../../phase2-features/bcerp-web/adaccount-cc/financial-hard-stop-chan-cap-phat-tkqc.md` | Upstream — FEAT-ERP-ADACC-003 |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | Upstream — §6.3 COMP-ERP-003 |
| Design system | `../../../design-system.md` | Upstream |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | Upstream — S9 `/ops/ad-accounts` |
| Surface đối tác (khớp tiền) | `../../finance/wallet/screens-wallet-recon.md` | S7 — deep-link S7↔S9 |


> **[NEEDS_REVIEW #8 — stakeholder F-C-04]:** các đường thao tác gán vai OPS_ADS trong file này tuân thủ NEEDS_REVIEW #8 (vai mở rộng chờ BOD chốt — menu ẩn toàn phần cho đến khi được phê duyệt). Khi BOD chốt, cập nhật đồng bộ Navigation-bcerp-web.md §3.
