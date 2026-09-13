# Screen Group: Integration & Settings (tabs: Connections / Credentials / Tham số)

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `stgw`
> **Tính năng:** FEAT-CORE-STGW-001..002 (touchpoint web: FEAT-ERP-STGW-001..002)
> **Route:** `/settings`
> **Main UI-ID:** `UI-WEB-STGW-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

**Implements:** FEAT-ERP-STGW-001 (Quản trị Integration Gateway & Credentials Vault vai CTO — REQ-BOD-008: console quản trị vòng đời kết nối ngoại vi, vault mask-only + MFA TOTP, rotate ≥90 ngày cảnh báo T-7, thu hồi khẩn ≤24h, tham số effective-dated, audit bất biến), FEAT-ERP-STGW-002 (API 7 nền tảng QC + Degraded Mode Manual — REQ-FIN-005: quan sát trạng thái sync/freshness/nhãn nguồn `api`/`manual` của Meta, Google, TikTok, Bing, X, Pinterest, Yandex + connection VAS kế toán vendor-agnostic theo DI-004; 2 kênh nhập manual thuộc S7 Wallet D6, tại đây chỉ hiển thị trạng thái và điều phối backfill).

---

## Thông Tin Chung

| Trường                  | Giá trị                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Workspace                 | **Settings** (`/settings/*`) — workspace quản trị đặc thù riêng (R2 13/09: tách khỏi Platform Admin); surface "Integration & Settings" là mục menu duy nhất = trang đích workspace                                                                                                                                                                                                                                                                                                                                                         |
| Đối tượng nghiệp vụ | `integration_connection` (lifecycle CONFIGURED → VAULTED → ACTIVE → DEGRADED_MANUAL / SUSPENDED / DISABLED / REVOKED — REVOKED là kết thúc, không hồi sinh), `credential_entry` (ACTIVE → EXPIRING T-7 → EXPIRED → REVOKED; rotate ≥90 ngày), `platform_feed` (API_ACTIVE ↔ DEGRADED_MANUAL ↔ BACKFILLING ↔ MANUAL_WEEKLY), `field_mapping` + `import_export_template` (version, vendor-agnostic DI-004), `sync_schedule`, `policy_parameter` (effective-dated, không hồi tố), `gateway_audit_event` (immutable, hash-chain) |
| Vai trò chính           | SYS_ADMIN (vận hành: soạn connection profile/mapping, thực thi cấu hình theo change đã duyệt — KHÔNG thấy plaintext, KHÔNG tự gán kể cả cho mình) · BOD_CFO_CTO (CTO: duyệt + thao tác vault thêm/rotate/revoke, transitions, cập nhật schedule, ban hành tham số metric/freshness) · BOD_CEO (soạn/duyệt chính sách ngưỡng-tier-SLA; oversight audit)                                                                                                                                                                          |
| Workflow stage            | Connection:`configured → vaulted → active → degraded(manual)/disabled/suspended/revoked`; chuyển sang DEGRADED luôn là machine-state (GW tự chuyển) — WEB chỉ hiển thị, không có nút "tắt degraded" ngoài chuỗi backfill. PlatformFeed: `API_ACTIVE ↔ DEGRADED_MANUAL ↔ BACKFILLING ↔ MANUAL_WEEKLY` — BACKFILLING là trung gian bắt buộc, cấm bật thẳng manual → active                                                                                                                                                        |
| Liên quan                | S7 Ví & Đối soát (2 kênh nhập manual của FIN_L1 — D6 import; dữ liệu feed đầu vào đối trừ 3 số); S9 TKQC Registry (feed đầu vào cấp phát account); S25 Audit Log Query (oversight toàn hệ thống); S24 Alert Center (degraded, credential quá hạn escalate BOD_CEO); S26 RBAC (MFA TOTP bắt buộc — nền của phiên console vault)                                                                                                                                                                                                  |

**Checklist workflow (Bước 0):** A. Credentials = tài sản tương đương tiền của khách: quản lý tập trung trong Settings (DI-004), không bao giờ lộ plaintext, mọi thao tác có vết. B. Primary actors: CTO quyết + thao tác vault; SYS_ADMIN thực thi sau duyệt; BOD_CEO soạn/duyệt chính sách + giám sát. C. Related: FIN_L1/L2 tiêu thụ feed (xem trạng thái sync read-only); OPS tiêu thụ qua màn nghiệp vụ. D. Hai máy trạng thái do GW trả về nguyên văn — web không suy diễn, không tự "sửa" trạng thái degraded. E. Cross-module: MFA step-up dùng chung API-CORE-003; audit hash-chain ở CORE; alert sức khỏe nguồn là danh mục RIÊNG, tách khỏi cờ K6–K12 quy trình khách (`[KXN-20]` đang mở — không mapping chéo). F. Thông tin cần: sức khỏe 7 adapter + VAS, tuổi dữ liệu (freshness), nhãn nguồn hiện hành, ngày rotate đến hạn, trạng thái vault, lịch sử version tham số. G. Quyết định: nạp/rotate/revoke credential (CTO + MFA), transition kết nối (CTO + MFA), ban hành version tham số (BOD), cập nhật schedule/mapping (CTO duyệt → SYS_ADMIN áp). H. Actions được phép: tạo profile, nạp/rotate/revoke credential, transitions, kích hoạt sync on-demand + retry, kích hoạt backfill, cập nhật mapping/template, export VAS, tra cứu gateway audit. I. Exceptions: connection degraded, credential EXPIRING/EXPIRED (T-7), token quá hạn rotate chưa xử lý → escalate BOD_CEO, thu hồi khẩn quá 24h → cảnh báo đỏ CEO, sync fail lặp (retry/backoff tự động), mapping đổi version — dữ liệu cũ giữ lịch sử. J. Không chuyển màn — 1 surface 3 tab, chi tiết qua SidePanel; vault CẤM tuyệt đối trên mobile (BR-BOD-008.2, app ẩn tính năng).

[NEEDS_REVIEW: Navigation §3 liệt kê route `/settings` (workspace Settings — R2) cho SYS_ADMIN + BOD_CFO_CTO — FEAT-ERP-STGW-002 §4 cấp FIN_L1/FIN_L2 quyền "xem trạng thái sync + freshness + nhãn nguồn" (read-only T1, không thấy T2 vault); đề nghị bổ sung FIN_L1/L2 vào cột Roles thấy với scope read-only]

---

## 1. TRANG CHÍNH

### 1.1. Layout — Registry/Admin (bảng standard + SidePanel 480px, density comfortable, form cấu hình container 960px)

```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ Settings > Integration & Settings           Scheduler: hoạt động · đợt sync 13:00 ✓           │
│                                              [+ Kết nối mới]  [Chạy sync on-demand]           │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ Connections ·8 │ Credentials Vault ·9 │ Tham số & Chính sách                                 │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ ⚠ 2 nền tảng DEGRADED manual (Pinterest 41 ngày, Yandex weekly) — FIN đang nhập tay tại S7,  │
│   chờ cấp quyền API (DI-007) · 1 credential đến hạn rotate: Meta còn 5 ngày (T-7) — quá hạn  │
│   chưa rotate → escalate BOD_CEO                                                             │
│ Chips: (Degraded ·2 ×) (Credential T-7 ·1 ×) (Manual weekly ·1 ×) (VAS ·1 ×) (Active ·5 ×)   │
│ [Tìm kết nối________]  [Loại ▾] [Trạng thái ▾] [Nền tảng ▾]                   [Sắp xếp ▾]    │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ Kết nối              Loại          Trạng thái      Health   Freshness  Nguồn   Rotate đến hạn│
│ Meta Ads             api_adapter   ● ACTIVE        ✓ OK     12 phút    api     18/09 (5n) ⚠ │
│ Google Ads           api_adapter   ● ACTIVE        ✓ OK     18 phút    api     21/10       │
│ TikTok Ads           api_adapter   ● ACTIVE        ✓ OK     25 phút    api     02/12       │
│ Microsoft Bing Ads   api_adapter   ● ACTIVE        ⚠ 2 fail 44 phút    api     14/11       │
│   → job 13:00 retry lần 2/5 — backoff 8 phút (job J-8841)                                 │
│ X Ads                api_adapter   ○ CONFIGURED    —        —          —       —           │
│   → chưa nạp credential — CTO thêm token để activate (chuyển qua VAULTED)                 │
│ Pinterest Ads        api_adapter   ◐ DEGRADED      ✗ fail   —          manual  —           │
│   → degraded 41 ngày — nhập tay 2 kênh chuẩn tại S7; khi có API → BACKFILLING tự động     │
│ Yandex Ads           api_adapter   ◐ MANUAL_WEEKLY —        6 ngày     manual  —           │
│   → nền tảng chỉ có statement tuần — đối soát hạ tuần, bù khớp tích lũy khi có API        │
│ Kế toán VAS (vendor cấu hình tại triển khai — DI-004)  import_export  ● ACTIVE  ✓ OK  2 giờ │
│   → field mapping v3 · template xuất chuẩn schema — đổi vendor = tạo profile mới          │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ Phân trang 20/50/100 (server-side)                                              8 kết nối   │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
                        click hàng → SidePanel 480px đẩy content (S1)
```

**Loading/Empty/Error:** loading = skeleton 10 hàng + skeleton banner; empty = EmptyState "Không có kết nối khớp bộ lọc" + chip tháo lọc (danh mục 7 nền tảng + VAS là bộ khởi tạo, không bao giờ rỗng toàn phần); error = khối lỗi + retry. Lỗi nghiệp vụ (`INVALID_STATE`, `MFA_REQUIRED`, `CREDENTIAL_LOCKED`, `MOBILE_VAULT_FORBIDDEN`) là toast không tự đóng kèm giải thích điều kiện thoát. Freshness vượt ngưỡng hiển thị WarningIndicator kèm mọi số liệu — KHÔNG nội suy/điền khuyết số thay người dùng (BR-STGW-206).

### 1.2. Components

| Component                       | Cấu hình                                    | Ghi chú                                                                              |
| ------------------------------- | --------------------------------------------- | ------------------------------------------------------------------------------------- |
| DataTable (§4.1)               | standard, row 40px comfortable, saved-views   | Sort theo click header; filter server-side                                            |
| WarningIndicator banner (§4.3) | persistent — degraded + rotate T-7           | 3 phần bắt buộc: chuyện gì — ai cần làm gì — hạn còn lại; không dismiss |
| StatusBadge (§4.2)             | token §1 — xem bảng 1.3                    | Degraded dùng`--state-manual` "Dữ liệu thủ công" hiển thị vĩnh viễn        |
| Quick chips                     | tháo được từng chip                      | Nguồn: filter server-side`status`, `connection_type`, `rotateDueBefore`        |
| WaitingOnIndicator (§4.11)     | "chờ cấp quyền API DI-007 — 41 ngày"     | Chờ hệ thống/bên ngoài: icon gear / icon ngoài                                  |
| SidePanel (§4.5)               | 480px (720px khi xem mapping), footer sticky  | Chi tiết kết nối — xem §4                                                        |
| Timeline (§4.8)                | inline 3 sự kiện trong S1; full trong audit | Event hệ thống (degraded, sync fail) icon riêng`status-gear`                     |

### 1.3. Cột bảng Connections

| Tên               | Trường                     | Định dạng                                                           | Sắp xếp | Rộng |
| ------------------ | ---------------------------- | ---------------------------------------------------------------------- | --------- | ----- |
| Kết nối          | `name`, `vendor_key`     | Tên + nền tảng (vendor-agnostic — không hardcode, DI-004)         | Có       | auto  |
| Loại              | `connection_type`          | `api_adapter` / `import_export` (badge info)                       | Có       | 120px |
| Trạng thái       | `status`                   | Badge — xem dưới                                                    | Có       | 140px |
| Health             | `/health`                  | ✓ OK / ⚠ N fail / ✗ fail + link job lỗi                            | Có       | 110px |
| Freshness          | `data_freshness`           | Tuổi dữ liệu ("12 phút", "6 ngày"); vượt ngưỡng → warning    | Có       | 110px |
| Nguồn hiện hành | `platform_feed.feed_state` | Nhãn`api` / badge `--state-manual` "manual"                       | Có       | 90px  |
| Rotate đến hạn  | `rotate_due_at`            | Ngày + countdown; còn ≤7 ngày → chip vàng T-7; quá hạn → đỏ | Có       | 140px |
| Hành động       | —                           | Row menu`⋯`                                                         | —        | 48px  |

**Badge trạng thái kết nối:** `CONFIGURED` = Nháp (`--state-draft`) · `VAULTED` = Info (`--state-info`, credential đã vào vault chưa activate) · `ACTIVE` = Đã duyệt (`--state-approved`) · `DEGRADED_MANUAL`/`MANUAL_WEEKLY` = `--state-manual` (kèm icon `file-manual`) · `SUSPENDED`/`DISABLED` = Chờ (`--state-pending`) · `REVOKED` = muted đậm — trạng thái kết thúc, chỉ tạo connection mới.

### 1.4. Hành Động Chính

| Sự kiện                            | Hành động                                          | Kết quả                                                                                                                   |
| ------------------------------------ | ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| Nhấn "+ Kết nối mới"             | Mở D6 (profile vendor-agnostic + mapping + template) | Chọn từ danh mục loại profile đã định nghĩa — connector ngoài registry bị chặn (`CONNECTOR_NOT_IN_REGISTRY`) |
| Nhấn "Chạy sync on-demand"         | Mở D7 (chọn nền tảng + window)                    | API-GW-014 — chỉ CTO; không cho "sync toàn bộ đồng loạt" (chống rate limit, BR-STGW-202)                           |
| Click hàng                          | Mở S1 (chi tiết kết nối)                          | Giữ context danh sách                                                                                                     |
| Row menu → "Chuyển trạng thái"   | Mở D1 (transitions)                                  | activate / mark_degraded / disable / revoke / reactivate — MFA step-up                                                     |
| Row menu → "Health chi tiết"       | Gọi API-GW-006                                       | Health + freshness + rotate_due trong S1                                                                                    |
| Chip "Credential T-7 ·1" (với CTO) | Lọc + nhảy T2                                       | Rotate trước khi quá hạn; quá hạn đã escalate BOD_CEO                                                               |
| Chip "Degraded ·2"                  | Lọc nguồn degraded                                  | Link "Mở kênh nhập S7" cho FIN; link "Kích hoạt backfill" (API-GW-026) khi đã có API                                |

### 1.5. Phân Quyền (PEP — thiếu quyền thì ẩn, không disabled)

| Thành phần                                             | SYS_ADMIN                               | BOD_CFO_CTO (CTO)     | BOD_CEO                            | FIN_L1/L2                            |
| -------------------------------------------------------- | --------------------------------------- | --------------------- | ---------------------------------- | ------------------------------------ |
| Xem danh sách kết nối + sức khỏe + freshness        | ✅                                      | ✅                    | ✅                                 | ✅ read-only (FEAT-ERP-STGW-002 §4) |
| Thêm/sửa connection profile, mapping, template (soạn) | ✅ (theo change được duyệt)         | ✅ (duyệt)           | ❌                                 | ❌                                   |
| Thực thi change đã duyệt lên môi trường          | ✅ (mọi thao tác log)                 | ❌                    | ❌                                 | ❌                                   |
| Quản trị vault: nạp/rotate/revoke credential`[MFA]` | ❌ (ẩn — SoD, không thấy plaintext) | ✅ độc quyền       | ❌                                 | ❌                                   |
| Chuyển trạng thái kết nối`[MFA]`                  | ❌                                      | ✅ (revoke chỉ CTO)  | ❌                                 | ❌                                   |
| Chạy sync on-demand / retry / backfill`[MFA]`         | ❌                                      | ✅                    | ❌                                 | ❌                                   |
| Cập nhật sync schedule                                 | ◐ thực thi sau duyệt                 | ✅                    | ❌                                 | ❌                                   |
| Soạn version tham số (ngưỡng, tier, SLA)             | ❌                                      | ✅ (metric/freshness) | ✅ (chính sách/định mức/tier) | ❌ (FIN_L2 đề xuất được)       |
| Ký duyệt ban hành version tham số                    | ❌                                      | ✅ (theo phạm vi)    | ✅                                 | ❌                                   |
| Xem giá trị plaintext                                  | ❌ cấm tuyệt đối — mọi vai        | ❌                    | ❌                                 | ❌                                   |
| Xem gateway audit + API call log                         | ◐ thao tác do mình                   | ✅                    | ✅                                 | ❌                                   |

---

## 2. TABS (global context — banner sức khỏe + scheduler giữ nguyên khi chuyển tab)

| Tab                     | UI-ID                  | Nội dung                                                                              | Hiện với vai                                             |
| ----------------------- | ---------------------- | -------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Connections             | `UI-WEB-STGW-001-T1` | 7 nền tảng QC + VAS: lifecycle, health, freshness, nhãn nguồn, sync jobs, backfill | SYS_ADMIN, BOD, FIN (read-only)                            |
| Credentials Vault       | `UI-WEB-STGW-001-T2` | Vault mask-only: nạp/rotate/revoke`[MFA]`, T-7, audit thao tác vault               | BOD_CFO_CTO (tab ẩn với vai khác — mobile ẩn cả app) |
| Tham số & Chính sách | `UI-WEB-STGW-001-T3` | `policy_parameter` effective-dated + sync schedule + lịch sử version               | BOD (soạn/duyệt), SYS_ADMIN (xem + thực thi)            |

**R7 tab completeness:**

- **T1 Connections:** mục tiêu — một màn hình duy nhất trả lời "dữ liệu đối soát đến từ đâu, tươi đến đâu, đứt gãy ở đâu" cho cả SYS_ADMIN/CTO lẫn FIN. Thông tin: 8 kết nối (7 nền tảng + VAS) theo bảng §1.3; job sync gần đây (status queued/running/success/failed/retrying, attempt, error_code — không lộ credential); backfill runs + progress + trạng thái đối soát lại kỳ manual; nhãn nguồn và freshness giữ nguyên khi truyền sang REQ-FIN-004/REQ-OPS-001/003 (BR-STGW-208). Components: DataTable + S1 + chips + WarningIndicator. Actions: D1 transitions, D7 sync on-demand/retry, kích hoạt backfill (D7 — `{platform, gapFrom, gapTo}`, chỉ theo sự kiện cấp quyền, không đặt lịch), link "Mở kênh nhập S7" cho FIN khi degraded. States: machine-state chỉ hiển thị — không có nút tắt degraded ngoài chuỗi backfill (WEB chặn, backend `INVALID_STATE`); X Ads `CONFIGURED` hiển thị CTA "CTO nạp credential"; hàng lỗi có link raw payload (parse_status) cho SYS_ADMIN. Permissions: §1.5 — FIN không thấy nút hành động nào (read-only toàn tab). Quan hệ: kết nối VAS dùng chung cơ chế với import/export S7; dữ liệu manual đã nhập hiển thị kỳ nào đã đối soát lại sau backfill.
- **T2 Credentials Vault:** mục tiêu — quản trị tài sản tương đương tiền với nguyên tắc mask-only + mọi thao tác có vết. Thông tin: danh sách credential (API-GW-007): kết nối, version, `masked_hint` (`••••a1b2`), `issued_at`, `rotate_due_at`, trạng thái ACTIVE/EXPIRING/EXPIRED/REVOKED; token EXPIRED không tự xóa — giữ để trace lịch sử. Components: DataTable (row comfortable) + ApprovalCard-style confirm từng thao tác + Timeline audit vault. Actions: nạp credential mới (D2), rotate (D3 — version mới giữ lịch sử, reset rotate_due ≥90 ngày), thu hồi khẩn (D4 — checklist ≤24h, SYS_ADMIN thực thi sau lệnh CTO có log); việc XEM chi tiết credential cũng ghi audit (API-GW-008). States: T-7 → chip vàng; quá hạn chưa rotate → đỏ + "đã escalate BOD_CEO"; connection REVOKED → khóa nạp token mới (`CREDENTIAL_LOCKED` — phải revoke credential trước). Permissions: CHỈ BOD_CFO_CTO — SYS_ADMIN/BOD_CEO/FIN không thấy tab (PEP ẩn); bước MFA step-up bắt buộc trước khi mở chức năng nhạy cảm (phiên chưa step-up → mọi nút vault không render, không disabled giả). Quan hệ: MFA nền từ S26 (API-CORE-003 purpose `vault_access`); audit thao tác + API call log tại cuối tab (API-GW-035) — oversight đầy đủ qua S25.
- **T3 Tham số & Chính sách:** mục tiêu — mọi ngưỡng/tier/SLA/lịch pull đổi theo version effective-dated, không hồi tố, trace old → new. Thông tin: bảng tham số (`param_key`, giá trị hiệu lực tại thời điểm `?at=`, `effective_from`, `approved_by`, version); lịch sử version từng tham số + reason; sync schedule hiện hành (cron_expr, batch_size, rate_limit_policy — hiển thị read-only, không cho cấu hình "pull toàn bộ đồng loạt"). Components: DataTable + form cấu hình container 960px (soạn version mới) + Timeline version. Actions: soạn version mới (D5) — BOD_CEO (chính sách/định mức/tier) hoặc BOD_CFO_CTO (metric/ngưỡng freshness); ký ban hành với `effective_from` trong tương lai — thử hiệu lực hồi tố bị chặn tuyệt đối; SYS_ADMIN áp cấu hình sau duyệt (không tự chỉnh giá trị). States: version chưa đến hạn hiển thị "sắp hiệu lực từ dd/MM"; báo cáo tra cứu đúng phiên bản hiệu lực tại thời điểm dữ liệu (API-GW-018 `?at=`). Permissions: §1.5; FIN_L2 thấy nút "Đề xuất" (tạo nháp chờ BOD) nhưng không ký. Quan hệ: tham số freshness/lịch pull điều khiển hành vi hiển thị cảnh báo ở T1; ngưỡng dùng chung S7 (dung sai đối trừ) — một tham số một nơi duy nhất, không nhân bản form cấu hình.

---

## 3. DIALOGS

| # | Dialog                                 | UI-ID                  | Loại                                | Mở khi nào                             |
| - | -------------------------------------- | ---------------------- | ------------------------------------ | ---------------------------------------- |
| 1 | Chuyển trạng thái kết nối         | `UI-WEB-STGW-001-D1` | Confirm + MFA step-up                | Row menu → Chuyển trạng thái (T1/S1) |
| 2 | Nạp credential mới                   | `UI-WEB-STGW-001-D2` | Form + MFA step-up                   | T2 — "+ Nạp credential" / S1           |
| 3 | Rotate credential                      | `UI-WEB-STGW-001-D3` | Confirm + MFA step-up                | T2 — row menu credential                |
| 4 | Thu hồi khẩn credential              | `UI-WEB-STGW-001-D4` | Form lý do + checklist 24h + MFA    | T2 — "Thu hồi khẩn"                   |
| 5 | Ban hành version tham số             | `UI-WEB-STGW-001-D5` | Form (old → new + ngày hiệu lực) | T3 — "+ Version mới"                   |
| 6 | Tạo/sửa connection profile + mapping | `UI-WEB-STGW-001-D6` | Form cấu hình 960px                | "+ Kết nối mới" / S1 (VAS)            |
| 7 | Sync on-demand / retry / backfill      | `UI-WEB-STGW-001-D7` | Form window                          | T1 — command bar / row menu job         |

### 3.1. Dialog Chuyển trạng thái kết nối (D1)

**Loại:** Confirm có ngữ cảnh + MFA step-up (header `X-MFA-Step-Up`, purpose `vault_access`). Hiển thị máy trạng thái hiện tại → đích theo API-GW-005: `activate/reactivate` yêu cầu credential active trong vault + health check đầu tiên OK; `mark_degraded` ghi rõ là machine-state (hệ thống tự chuyển — nút này chỉ cho CTO chủ động khi mất quyền, kèm lý do); `disable`/`revoke` bắt buộc lý do; `revoke` là trạng thái kết thúc — chỉ tạo connection mới, không hồi sinh. Submit → response trả `{status, changedAt, changedBy, auditRef}`; lỗi `409 INVALID_STATE` / `403 MFA_REQUIRED` hiển thị điều kiện thoát.

### 3.2. Dialog Nạp credential mới (D2)

**Loại:** Form (CTO + MFA). Fields: kết nối (chỉ connection ở trạng thái đủ điều kiện — REVOKED bị chặn `CREDENTIAL_LOCKED`), secret (paste một lần — gửi thẳng vault-service dạng `secretRef` envelope, WEB không lưu, không log, không hiển thị lại), `masked_hint` tự sinh (`••••last4`), `rotate_due_at` mặc định issued + 90 ngày (BR-STGW-102). Sau submit: connection chuyển `VAULTED` (nếu `CONFIGURED`), T2 thêm dòng mới masked; không có bất kỳ response nào chứa plaintext — nếu thấy plaintext là security defect chặn release.

### 3.3. Dialog Rotate credential (D3)

**Loại:** Confirm + nhập secret mới (cơ chế như D2) + MFA. Tạo version mới giữ đầy đủ lịch sử; reset `rotate_due_at` (≥90 ngày); credential cũ chuyển hết hạn theo lịch sử — không xóa. Chip T-7 trên T1 tự nhả sau khi rotate.

### 3.4. Dialog Thu hồi khẩn credential (D4)

**Loại:** Form lý do + checklist + MFA. Kịch bản: nghi ngờ rò rỉ hoặc nhân viên liên quan nghỉ việc (kể cả đột xuất). Sau lệnh của CTO: vô hiệu token tức thì ở mức khả thi (API-GW-011), mở checklist khẩn với đồng hồ 24h — các điểm: revoke credential, rotate mọi token dùng chung tài khoản đăng nhập nền tảng (không để lại quyền treo), xác nhận CTO từng điểm. SYS_ADMIN thực thi có log, không thấy plaintext. Quá 24h chưa hoàn tất → cảnh báo đỏ cho BOD_CEO (Alert Center). Không cho đóng checklist thiếu xác nhận CTO.

### 3.5. Dialog Ban hành version tham số (D5)

**Loại:** Form. Hiển thị old value → new value, `param_key`, `effective_from` (bắt buộc ≥ ngày duyệt — validate chặn hồi tố trước khi gửi), reason. Người soạn ≠ bắt buộc người duyệt: version vào hàng chờ ký (BOD_CEO hoặc BOD_CFO_CTO theo phạm vi tham số); ký bằng phiên hợp lệ + MFA (purpose `policy_approval`); mỗi version lưu người duyệt + audit old → new. Không có đường sửa version đã ban hành — chỉ ban hành version mới.

### 3.6. Dialog Tạo/sửa connection profile + mapping (D6)

**Loại:** Form cấu hình container 960px. Fields: tên, `connection_type` (`api_adapter` | `import_export`), platform (enum 7 nền tảng hoặc loại VAS/other), endpoint + môi trường + owner; cho VAS: field mapping (`source_field` → `target_field`, transform_rule) + import/export template (schema_version, column_spec) — vendor-agnostic: chọn loại connector từ registry, tên phần mềm kế toán là dữ liệu cấu hình nhập khi triển khai, KHÔNG có trong code/UI. SYS_ADMIN soạn theo change được CTO duyệt; đổi vendor = tạo profile mới, mapping/template cũ giữ nguyên ở tầng lịch sử. Cập nhật mapping phát hành version mới — dữ liệu đã import theo version cũ giữ nguyên lịch sử.

### 3.7. Dialog Sync on-demand / retry / backfill (D7)

**Loại:** Form window. Ba chế độ: (a) sync on-demand `{platform, windowFrom, windowTo}` — hiển thị cảnh báo rate limit, không cho chọn "toàn bộ 2.600+ account đồng loạt"; (b) retry job sau khi hết retry tự động (API-GW-017); (c) kích hoạt backfill `{platform, gapFrom, gapTo}` — chỉ khả dụng khi nền tảng vừa được cấp quyền API; hệ thống tự tạo hàng chờ đối soát lại kỳ manual, chênh lệch >±0,1% ghi báo cáo đối soát. Chỉ CTO `[MFA]`.

---

## 4. SHEETS

| # | Sheet               | UI-ID                  | Vị trí                             | Mở khi nào   |
| - | ------------------- | ---------------------- | ------------------------------------ | -------------- |
| 1 | Chi tiết kết nối | `UI-WEB-STGW-001-S1` | Right panel 480px (mapping → 720px) | Click hàng T1 |

### 4.1. Sheet: Chi tiết kết nối (S1)

**Kích thước:** 480px; Esc đóng, focus trả về hàng vừa mở.
**Nội dung (khối cuộn):** (a) *Trạng thái & sức khỏe* — badge lifecycle + ProgressTracker nhánh hiện tại (active → degraded → backfilling → active), health lần check cuối (API-GW-006), freshness so ngưỡng hiệu lực, `degraded_since` + WaitingOnIndicator ("chờ cấp quyền API DI-007 — 41 ngày"); (b) *Credential hiện hành* — masked hint + version + `rotate_due_at` (CTO thấy; SYS_ADMIN/FIN thấy trạng thái mask rút gọn "đã vault · hạn 18/09"); (c) *Sync* — schedule hiện hành, 5 job gần nhất (status, attempt, error_code, link raw payload cho SYS_ADMIN), nút D7; (d) *VAS: mapping & template* — bảng `source_field → target_field` + version, template xuất (panel mở rộng 720px), nút "Xuất file chuẩn schema" (API-GW-023, log lượt xuất); (e) *Timeline* — chuyển trạng thái + thao tác vault + job fail, mỗi entry actor/timestamp/lý do + `auditRef`. **Footer sticky:** [Chuyển trạng thái] (D1) + [Vault] (D2/D3/D4 — chỉ render cho CTO) + [Trail audit] → mở S25 filter object = connection này.

---

## 5. VIEW MODES

| Mode                            | UI-ID                  | Mô tả                                                                                                                                                                                                                                         | Hiện khi nào                                         |
| ------------------------------- | ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| Bảng Connections (mặc định) | `UI-WEB-STGW-001-M1` | DataTable §1 — vận hành hằng ngày                                                                                                                                                                                                         | Default                                                |
| Tổng quan sức khỏe Gateway   | `UI-WEB-STGW-001-M2` | Mở rộng banner thành dashboard strip (API-GW-024): 8 ô adapter (✓/⚠/✗ + freshness), scheduler state, đợt sync gần nhất, tỷ trọng manual/api trong 30 ngày (đếm từ API-GW-032 theo`sourceLabel`) — mỗi ô click lọc về M1 | Toggle command bar — dùng cho họp oversight CTO/BOD |

---

## 6. API ENDPOINTS

Endpoint thật từ `api-contract.md` — nhóm SYS-INTEGRATION-GW §6.1 (MOD-SETTINGS-GW), base như contract. Enforcement ở service layer (GW/CORE); WEB không tự xử lý bỏ qua. Mọi thao tác ghi gateway audit bất biến (hash-chain ở CORE); mobile trúng `/gw/vault/*` hoặc transitions → `403 MOBILE_VAULT_FORBIDDEN`.

| Khi nào                                        | Method | Endpoint                                                             | Tham số / Ghi chú                                                                                                            |
| ----------------------------------------------- | ------ | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Tải danh sách kết nối (T1)                  | GET    | `/gw/connections` (API-GW-001)                                     | Filter`platform, status, connection_type`; server-side                                                                       |
| Tạo profile vendor-agnostic (D6)               | POST   | `/gw/connections` (API-GW-002)                                     | CTO; platform enum,`api_adapter\|import_export`                                                                               |
| Chi tiết kết nối (S1)                        | GET    | `/gw/connections/:id` (API-GW-003)                                 | Kèm credential version hiện tại (mask)                                                                                      |
| Cập nhật config (D6)                          | PUT    | `/gw/connections/:id` (API-GW-004)                                 | Endpoint, môi trường, owner                                                                                                 |
| Chuyển trạng thái (D1)                       | POST   | `/gw/connections/:id/transitions` (API-GW-005) `[MFA]`           | `activate/mark_degraded/disable/revoke/reactivate` + reason + trigger; lỗi `409 INVALID_STATE`, `423 CREDENTIAL_LOCKED` |
| Health + freshness + rotate_due (S1/M2)         | GET    | `/gw/connections/:id/health` (API-GW-006)                          | Poll theo nhịp widget                                                                                                         |
| Aggregate sức khỏe (M2/banner)                | GET    | `/gw/health` (API-GW-024)                                          | 7 adapter + freshness + scheduler state                                                                                        |
| Danh sách credential (T2)                      | GET    | `/gw/vault/credentials` (API-GW-007)                               | JWT+CTO; filter`profileId, status, rotateDueBefore` — mask-only                                                             |
| Chi tiết credential (T2/S1)                    | GET    | `/gw/vault/credentials/:id` (API-GW-008)                           | JWT+CTO; việc XEM cũng ghi audit                                                                                             |
| Nạp credential (D2)                            | POST   | `/gw/vault/credentials` (API-GW-009) `[MFA]`                     | `{maskedHint, secretRef (envelope), rotateDueAt}` — response không plaintext                                               |
| Rotate (D3)                                     | POST   | `/gw/vault/credentials/:id/rotate` (API-GW-010) `[MFA]`          | Version mới giữ lịch sử; reset rotate_due ≥90 ngày                                                                       |
| Thu hồi khẩn (D4)                             | POST   | `/gw/vault/credentials/:id/revoke` (API-GW-011) `[MFA]`          | Vô hiệu tức thì; offboarding ≤24h                                                                                         |
| Sync schedules (T3/S1)                          | GET    | `/gw/sync/schedules` (API-GW-012)                                  | Cadence, batch_size, retry_policy                                                                                              |
| Cập nhật schedule (T3)                        | PUT    | `/gw/sync/schedules/:id` (API-GW-013)                              | CTO duyệt → SYS_ADMIN thực thi sau                                                                                          |
| Sync on-demand (D7)                             | POST   | `/gw/sync/jobs` (API-GW-014)                                       | `{platform, windowFrom, windowTo}`                                                                                           |
| Job list / detail (T1/S1)                       | GET    | `/gw/sync/jobs` (API-GW-015) · `/gw/sync/jobs/:id` (API-GW-016) | Filter`profileId, status`; detail + attempt + raw payload refs                                                               |
| Retry tay (D7)                                  | POST   | `/gw/sync/jobs/:id/retry` (API-GW-017)                             | Sau khi hết retry tự động                                                                                                  |
| Tham số hiệu lực (T3)                        | GET    | `/gw/policies` (API-GW-018)                                        | `?at=` — đúng phiên bản tại thời điểm dữ liệu                                                                     |
| Lịch sử version (T3)                          | GET    | `/gw/policies/:paramKey/versions` (API-GW-019)                     | Người duyệt + reason                                                                                                        |
| Ban hành version mới (D5)                     | POST   | `/gw/policies/:paramKey` (API-GW-020)                              | JWT+BOD (BOD_CEO/BOD_CFO_CTO); không hồi tố                                                                                 |
| Mapping + template (S1 VAS)                     | GET    | `/gw/mappings` (API-GW-021)                                        | Theo profile                                                                                                                   |
| Cập nhật mapping (D6)                         | PUT    | `/gw/mappings/:id` (API-GW-022)                                    | DI-004 — thêm nguồn = thêm profile, không sửa code                                                                       |
| Export chuẩn schema VAS (S1)                   | POST   | `/gw/exports` (API-GW-023)                                         | Sinh file + log lượt xuất                                                                                                   |
| Trạng thái degraded/backfill (T1)             | GET    | `/gw/degraded/status` (API-GW-025)                                 | MANUAL ↔ API ↔ BACKFILL + tuổi dữ liệu per-platform                                                                       |
| Kích hoạt backfill (D7)                       | POST   | `/gw/backfill/runs` (API-GW-026)                                   | `{platform, gapFrom, gapTo}` — theo sự kiện cấp quyền                                                                   |
| Backfill runs (T1)                              | GET    | `/gw/backfill/runs` (API-GW-027)                                   | Progress + recheck_status kỳ manual                                                                                           |
| Statement gắn nhãn (M2 tỷ trọng; nguồn S7) | GET    | `/gw/statements` (API-GW-032)                                      | Filter`platform, adaccountRef, window, sourceLabel` — nhãn immutable                                                       |
| Raw payload (S1 — SYS_ADMIN)                   | GET    | `/gw/raw-payloads` (API-GW-033)                                    | Theo job/batch + parse_status                                                                                                  |
| Reprocess sau khi mapping đổi                 | POST   | `/gw/raw-payloads/:id/reprocess` (API-GW-034)                      | Raw lưu trước parse                                                                                                         |
| Gateway audit + API call log (T2/T3)            | GET    | `/gw/audit-logs` (API-GW-035)                                      | JWT (CTO/CEO); việc xem cũng bị log                                                                                         |
| MFA step-up (D1–D4, D5 ký, D7)                | POST   | `/core/auth/mfa/step-up` (API-CORE-003)                            | `purpose: "vault_access" \| "policy_approval"` — TTL 5 phút, một lần dùng                                                |

**[NEEDS_REVIEW] thiếu endpoint cho:** (1) hàng đợi change management — BR-STGW-106 yêu cầu SYS_ADMIN thực thi theo "change ID đã CTO duyệt" nhưng contract chưa có entity/endpoint list + approve change (`POST /gw/changes` tương đương); các nút "Gửi duyệt"/"Thực thi theo change" hiện render theo dữ liệu có sẵn và gắn cờ chờ contract; (2) checklist thu hồi khẩn ≤24h với điểm xác nhận CTO + đồng hồ (D4) — hiện chỉ có API-GW-011 revoke, checklist chưa có contract lưu trạng thái; (3) POST tạo mới `field_mapping` / `import_export_template` — API-GW-021 chỉ GET, API-GW-022 chỉ PUT `:id`; tạo mapping lần đầu cho profile mới chưa có đường; (4) aggregate tỷ trọng manual/api tổng hợp (M2) — hiện đếm client-side từ API-GW-032 theo window, chưa có endpoint thống kê. KHÔNG bịa endpoint — các khối UI này render theo dữ liệu có sẵn và chờ bổ sung contract.

---

## 7. UI-ID Registry

| UI-ID                  | Loại     | Mô tả                                                                                          |
| ---------------------- | --------- | ------------------------------------------------------------------------------------------------ |
| `UI-WEB-STGW-001`    | Main Page | Integration & Settings — registry/admin 3 tab, bảng + SidePanel 480px                          |
| `UI-WEB-STGW-001-T1` | Tab       | Connections — 7 nền tảng QC + VAS: lifecycle, health, freshness, nhãn nguồn, sync/backfill  |
| `UI-WEB-STGW-001-T2` | Tab       | Credentials Vault — mask-only, nạp/rotate/revoke`[MFA]`, T-7, audit vault (chỉ CTO)         |
| `UI-WEB-STGW-001-T3` | Tab       | Tham số & Chính sách —`policy_parameter` effective-dated + sync schedule + version history |
| `UI-WEB-STGW-001-D1` | Dialog    | Chuyển trạng thái kết nối (transitions, MFA step-up, reason bắt buộc disable/revoke)      |
| `UI-WEB-STGW-001-D2` | Dialog    | Nạp credential mới (secretRef envelope, rotate_due ≥90 ngày, không plaintext)               |
| `UI-WEB-STGW-001-D3` | Dialog    | Rotate credential (version mới giữ lịch sử, reset T-7)                                       |
| `UI-WEB-STGW-001-D4` | Dialog    | Thu hồi khẩn credential (lý do + checklist 24h + xác nhận CTO)                              |
| `UI-WEB-STGW-001-D5` | Dialog    | Ban hành version tham số (old → new, effective_from tương lai, không hồi tố)             |
| `UI-WEB-STGW-001-D6` | Dialog    | Tạo/sửa connection profile + field mapping + template (vendor-agnostic, 960px)                 |
| `UI-WEB-STGW-001-D7` | Dialog    | Sync on-demand / retry / kích hoạt backfill (window, chống rate limit)                        |
| `UI-WEB-STGW-001-S1` | Sheet     | Chi tiết kết nối 480px (sức khỏe · credential mask · sync · mapping VAS · timeline)     |
| `UI-WEB-STGW-001-M1` | View Mode | Bảng Connections (mặc định)                                                                  |
| `UI-WEB-STGW-001-M2` | View Mode | Tổng quan sức khỏe Gateway (8 ô adapter + scheduler + tỷ trọng manual/api)                 |

---

## Tài Liệu Liên Quan

| Nội dung               | File                                                                | Ghi chú |
| ----------------------- | ------------------------------------------------------------------- | -------- |
| Tính năng nghiệp vụ | `../../../../phase2-features`                                     | Upstream |
| API chi tiết           | `../../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system           | `../../../design-system.md`                                       | Upstream |
| Navigation tổng quan   | `../../Navigation-bcerp-web.md`                                   | Upstream |
