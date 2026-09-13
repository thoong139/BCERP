# Navigation: Mobile App — BCERP Internal (ESS)

> **System ID:** SYS-MOBILE-INTERNAL
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `phase2-features/mobile-internal/**/*.md`, `phase3-architecture/P3-01-architecture.md`
> USED BY: `[mod]/[screen-group].md`

---

## 1. Sơ Đồ Menu (Menu Tree)

Nguyên tắc: mobile = tác vụ giao dịch ngắn, 1 màn hình là xong (research principles + design-system §7). Bottom tab bar **tối đa 5 tabs**, mọi nhân viên ESS đều thấy đủ 5 tabs — không có menu ẩn theo vai ở bản này.

```
┌─────────────────────────────────────────────────────────────────┐
│  Top app bar:  BCERP   ·   🔔 Thông báo (global, KHÔNG phải tab) │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Nội dung màn hình hiện tại (1 cột, card, scroll dọc)           │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  BOTTOM TAB BAR (nền --color-mobile-bottomnav, safe-area)       │
│   [nav-home]  [nav-attendance] [nav-timesheet] [nav-leave] [nav-profile] │
│    Home       Chấm công        Timesheet       Nghỉ phép   Tôi  │
│    /m/home    /m/attendance    /m/timesheet    /m/leave    /m/profile │
└─────────────────────────────────────────────────────────────────┘
```

- **Home (M1)** là landing sau đăng nhập: alert cá nhân (ghi timesheet chậm, cảnh báo quá tải/vùng vàng, kết quả đơn nghỉ phép) + 3 quick actions lớn: Check-in/out → M2 · Ghi giờ → M3 · Xin nghỉ → M4.
- **Thông báo** = chuông trên top app bar (hợp nhất theo §2.0.5 — S11 dropped thành global drawer), không chiếm slot tab.
- **Deep-link từ push notification** mở đúng surface theo scheme `mobile://` (bảng mapping ở §4). Deep-link không hợp quyền → fallback `/m/home` (PEP: không hiện disabled).

**M6 Duyệt nhanh (manager):** `[NEEDS_REVIEW]` — KHÔNG đưa vào menu tree chính. Kiểm tra registry (`phase2-features/mobile-internal/`): duyệt nghỉ phép trên mobile **không có** (BR-008, REQ-HR-004 duyệt chỉ trên WEB/CORE); duyệt timesheet nhóm góc OPS (TL/OPS_PLAN) **có thật** nhưng nằm trong FEAT-MBI-CAPTS-001, không phải CAPTS-002/HRCORE-004 như M6 gốc. Chi tiết ở mục "Ứng viên tương lai" cuối §2.

---

## 2. Danh Sách Screen Groups

5 screen groups (M1–M5) đúng theo inventory §2.0.3 — không thêm ngoài registry. UI-ID: `UI-MBI-[OBJ]-[NNN]`.

| SG | Tên | Screen (UI-ID) | Route / Deep-link | Mục đích | FEAT-IDs |
|----|-----|----------------|-------------------|----------|----------|
| M1 | ESS Home | UI-MBI-HOME-001 Alert + quick actions | `/m/home` · `mobile://home` | Alert cá nhân (SLANOT) + quick actions | MBI-CAPTS-001, MBI-SLANOT-001, HRCORE-005 |
| M2 | Chấm công | UI-MBI-ATT-001 Check-in/out · UI-MBI-ATT-002 Lịch chấm của tôi | `/m/attendance`, `/m/attendance/history` · `mobile://attendance` | Check-in/out theo nội quy §8, xem lịch chấm | HRCORE-002 (qua MBI-CAPTS-001) |
| M3 | Timesheet của tôi | UI-MBI-TS-001 Tuần của tôi + trạng thái duyệt · UI-MBI-TS-002 Ghi nhanh cuối ngày | `/m/timesheet`, `/m/timesheet/new` · `mobile://timesheet` | Ghi giờ offline-first, nhãn billable, theo dõi duyệt 48h | MBI-CAPTS-001 (duyệt phía WEB: ERP-CAPTS-002) |
| M4 | Nghỉ phép của tôi | UI-MBI-LEAVE-001 Số dư + đơn của tôi · UI-MBI-LEAVE-002 Tạo đơn nghỉ/công tác | `/m/leave`, `/m/leave/new` · `mobile://leave` | Xin phép theo mức báo trước §8, số dư tự động, trạng thái | HRCORE-003..004 (mobile chỉ điểm tạo đơn — BR-008) |
| M5 | Hồ sơ cá nhân | UI-MBI-PROF-001 Thông tin của tôi | `/m/profile` · `mobile://profile` | Xem thông tin bản thân, PII masking | HRCORE-001 |

### BẢNG CON — 

**File mapping (screen group files):** `hr-core/screens-ess-home.md` (M1) · `hr-core/screens-attendance.md` (M2) · `capacity-timesheet/screens-timesheet.md` (M3) · `hr-core/screens-leave.md` (M4) · `hr-core/screens-profile.md` (M5). M6 Duyệt nhanh: KHÔNG tạo file (chỉ khi [NEEDS_REVIEW] được duyệt).

Cơ Sở Giữ Lại Màn Hình

| SG | Ai dùng | Làm gì tại đây | Vì sao giữ surface riêng |
|----|---------|----------------|--------------------------|
| M1 | Mọi nhân viên | Đọc alert, bắn nhanh vào 3 tác vụ tần suất cao nhất | Điểm vào duy nhất của app; quick action giảm 2–3 lần chạm |
| M2 | Mọi nhân viên (đặc biệt field staff) | Chấm công tại chỗ, đối chiếu lịch | Tác vụ 5 giây/ngày, cần mở tức thì cả khi mạng yếu |
| M3 | Nhân viên OPS ghi giờ; tất cả nhân viên có giờ dự án | Ghi nhanh cuối ngày, sửa trước khi chốt tuần | Ghi ngoài giờ hành chính; desktop là nơi nhập chi tiết, mobile là kênh ghi nhanh — đúng fan-out REQ-OPS-007 |
| M4 | Mọi nhân viên | Tạo đơn nghỉ/công tác đúng mức báo trước, theo dõi kết quả | Tạo đơn lúc không ngồi máy; duyệt vẫn ở WEB/CORE |
| M5 | Mọi nhân viên | Xem thông tin + HĐLĐ của chính mình | Self-data duy nhất, không nhân bản dữ liệu người khác |

### Ứng viên tương lai (KHÔNG thiết kế ở bản này)

**M6 Duyệt nhanh (manager) — `[NEEDS_REVIEW]`, quyết định tại Phase 3 check 4.1.**
- Đã xác nhận trong registry: hàng đợi duyệt di động cho TL/OPS_PLAN (duyệt timesheet nhóm SLA 48h, gán vùng vàng >90%, OT trong trần 8h/tuần, correction 24h, cấm tự duyệt BR-003) — nhưng thuộc **FEAT-MBI-CAPTS-001**.
- Không xác nhận: duyệt nghỉ phép trên mobile (BR-008 loại rõ — "mobile không có nút duyệt nghỉ phép"); HR_L1/L2 không có màn hình thao tác trên M-INT.
- Đề xuất pattern khi được duyệt: **không thêm tab thứ 6** (vượt trần 5) — badge đếm "Cần tôi duyệt" trên Home + section role-scoped trong M3, theo permission filter (nguyên tắc 1 surface §2.0.4). Phê duyệt chỉ thực hiện khi online.

---

## 3. Phân Quyền & Hiển Thị Menu

| Vai | Tabs thấy | Ghi chú |
|-----|-----------|---------|
| Mọi nhân viên (18 vai registry, trừ CUSTOMER) | Cả 5 tabs M1–M5 | App cá nhân — chỉ thấy **dữ liệu của chính mình** |
| Manager (TL/OPS_PLAN, OPS_AM, HR_L1/L2…) | Cả 5 tabs, **không thêm tab nào** | Hàng đợi duyệt góc OPS có trong MBI-CAPTS-001 nhưng surface M6 `[NEEDS_REVIEW]` — chưa hiển thị; khi confirm → badge Home + section trong M3 (§2) |

- **PII masking:** self-data only — không có bất kỳ màn hình nào xem dữ liệu nhân viên khác; lương/PII Confidential chỉ xuất hiện (nếu chính sách ESS cho phép) trong M5 của chính người dùng, HR không thao tác qua app này. Nguyên tắc RBAC-006: người khác **không bao giờ** thấy lương của nhau trên mobile.
- **Permission = ẩn, không disabled** (mô hình PEP): action/tab không có quyền không render; deep-link ngoài quyền → `/m/home`.
- **Cấm tự duyệt (BR-003):** áp dụng cho mọi hàng đợi duyệt khi M6 được confirm — nút duyệt ẩn với chính người ghi.

---

## 4. UI Notes

**Touch & layout:** mọi control chạm được ≥44×44px, gap 8px giữa action; list render dạng card (`--mobile-card-padding: 16px`), không bảng; form 1 cột, body ≥16px (chống zoom iOS), bàn phím đúng kiểu (số cho giờ, date cho ngày); safe-area bottom; pull-to-refresh mọi màn danh sách. Bảng data-heavy (sổ phụ, aging…) không parity — hiển thị tóm tắt + CTA "Mở trên web". Vault/credential không xuất hiện trên mobile (ẩn hẳn).

**Offline-tolerant (bắt buộc cho M2/M3):** bản ghi tạo khi offline vào **hàng đợi cục bộ kèm timestamp tạo**, tự sync khi có mạng; server tái validation toàn bộ tại thời điểm sync (BR-012 — offline-first, không offline-authoritative; append-only, không ghi đè). UI state bắt buộc 4 mức, hiển thị chip trên card: `synced` (im lặng) · `syncing` (spinner nhỏ) · `pending` ("Chưa đồng bộ — sẽ gửi khi có mạng", token `--state-pending`) · `failed` ("Đồng bộ bị từ chối: [lý do] — cần hành động", giữ bản ghi, không mất dữ liệu). Mọi **quyết định duyệt chỉ khi online**; trạng thái duyệt luôn đọc từ server.

**Naming & icon:** tên màn hình/nút tiếng Việt có dấu, cấm `text-transform: uppercase` CSS; số giờ dùng `tabular-nums`. Icon Lucide tiền tố `nav-` (5 tab), `action-` (check-in, ghi giờ, xin nghỉ, duyệt), `status-`/`ui-` (bell, chip đồng bộ); icon hành động luôn kèm label hoặc `aria-label`. Animation 100–200ms, tôn trọng `prefers-reduced-motion`.

**Push notification → surface:**

| Loại push | Deep-link | Surface |
|-----------|-----------|---------|
| Nhắc ghi timesheet (chậm 3 ngày) | `mobile://timesheet` | M3 · UI-MBI-TS-001 |
| Nhắc chốt tuần trước 12:00 thứ Hai | `mobile://timesheet` | M3 |
| Cảnh báo quá tải / gán vùng vàng | `mobile://home` | M1 · UI-MBI-HOME-001 |
| Kết quả đơn nghỉ phép (duyệt/từ chối từ WEB/CORE) | `mobile://leave` | M4 · UI-MBI-LEAVE-001 |
| Nhắc chấm công | `mobile://attendance` | M2 · UI-MBI-ATT-001 |
| "Cần tôi duyệt" (TL) | `[NEEDS_REVIEW]` — chờ M6 | — |

---

### 4.5. Bố Cục & Responsive (ux-architect)

#### Kiến trúc & theming

Hướng **web-based PWA** (cài lên home screen, service worker). Lý do: toàn bộ tokens của design-system là CSS custom properties (§1) — PWA tái dùng 100% shared tokens và component semantics (StatusBadge, WarningIndicator) qua chung một file `:root`, không cần lớp mapping sang theme system native; ESS chỉ là tác vụ giao dịch ngắn (§7), API native cần dùng (geolocation check-in, camera) PWA đều đáp ứng được, và service worker cho sẵn nền tảng offline state.

```
┌──────────────────────────┐
│ Header: tiêu đề + bell   │  ← banner offline (khi mất mạng)
│ Content: 1 cột, scroll   │
├──────────────────────────┤
│ ⏱    🌴    📋    🔔   👤 │  ← bottom tab 56px + safe-area
└──────────────────────────┘
```

#### Khung bố cục

- **Bottom tab bar 5 mục** đúng menu tree §1: Home · Chấm công · Timesheet · Nghỉ phép · Tôi (Thông báo = chuông trên top app bar, KHÔNG chiếm tab). Nền `--color-mobile-bottomnav`, active `--color-primary`, padding-bottom `env(safe-area-inset-bottom)`.
- **M1 Home = landing screen** khi mở app; alert list rút gọn 3 mục ("Xem tất cả" → Thông báo), quick action deep-link thẳng tới tab tương ứng.
- **Stack navigation**: chi tiết/form push lên stack (slide 200ms, chỉ opacity + transform), back luôn về list gốc — không cây điều hướng sâu.
- **Single-column** toàn bộ; list render dạng card (`--mobile-card-padding: 16px`), không bảng — bảng data-heavy báo "Mở trên web" (§7).
- **Touch target ≥44×44px**, gap 8px giữa các action.
- **Form 1 màn hình, không wizard**: xin nghỉ phép (loại · từ/đến · lý do) và timesheet (project · ngày · giờ) gọn trong 1 màn; input body ≥16px chống zoom iOS, bàn phím đúng kiểu (date/số).

#### Offline state UI

- **Banner** (WarningIndicator variant banner, persistent) trên mọi màn khi mất mạng: "Mất kết nối — dữ liệu đang lưu nháp trên máy".
- **Draft local indicator**: chip `--state-draft` + icon đồng hồ trên card chưa sync; tự retry khi online, toast success sau khi sync xong.
- **Check-in/out bị chặn khi offline** — timestamp phải server-authoritative; nút chuyển trạng thái disabled kèm lý do.

#### Ranh giới component M1–M6

| Màn | Boundary |
|---|---|
| **M1 Home** | Quick action grid 2×2 (nút ≥44px + label) + Alert list (StatusBadge + WaitingOnIndicator; SLA breach đỏ xếp đầu) |
| **M2 Chấm công** | 1 nút Check-in/out full-width ~64px, trạng thái hiện tại ("Đã check-in 08:02") ngay phía trên; dưới là list card ngày theo token `--state-*` |
| **M3/M4 List + Form** | Card list, 1 StatusBadge/hàng; tap mở form 1 màn; trạng thái duyệt hiển thị "đang chờ ai" (WaitingOnIndicator chip) |
| **M6 Duyệt nhanh** (khi [NEEDS_REVIEW] được duyệt — hiện ở "Ứng viên tương lai") | Card tóm tắt (người · loại · ngày · số dư còn) + **swipe action**: phải = Duyệt (`--color-primary`), trái = Từ chối (`--color-error`, mở sheet bắt buộc lý do ≥10 ký tự); fallback nút Duyệt/Từ chối sticky footer 44px cho người không quen gesture. ESS không có lệnh tiền → không áp dụng quy tắc "không gesture ẩn cho tiền" |

#### Đồng bộ với web

Dùng chung file **shared tokens** (§1: màu, trạng thái, chữ, spacing 8px); mobile-only tokens chỉ bổ sung, không ghi đè semantics. **StatusBadge giữ nguyên 10 cặp bg/fg `--state-*`**, height 20px, luôn icon/chữ kèm màu (color-blind safe) — giống hệt web. WarningIndicator giữ đủ 3 phần (chuyện gì — cần ai làm gì — hạn); cấm `text-transform: uppercase` tiếng Việt; font Inter/Be Vietnam Pro.

## Tài Liệu Liên Quan

| Nội dung | File |
|---------|------|
| Thiết kế chi tiết màn hình | `[module-name]/[screen-group].md` |
| API endpoints | `../../phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `../../phase3-architecture/technical-specs/integration-map.md` |
| Design system | `../design-system.md` |
| REQ-IDs | `../../_meta/req-registry.json` |
