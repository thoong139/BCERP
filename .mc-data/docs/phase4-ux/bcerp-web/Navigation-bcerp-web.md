# Navigation: BCERP Web nội bộ

> **System ID:** SYS-BCERP-WEB
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `phase2-features/bcerp-web/**/*.md`, `phase3-architecture/P3-01-architecture.md`
> USED BY: `[ws]/Navigation-[ws].md`, `[ws]/[mod]/[screen-group].md`

> Đơn vị điều hướng cấp cao hơn page là **Workspace** (theo phòng ban — $WORKSPACE_MAP): nav rail top-level = 7 workspace — **5 workspace theo phòng ban sẽ sử dụng** (Sales, Finance, Ops, HR, Executive) + **2 workspace quản trị đặc thù** (Platform Admin — quản trị truy cập & giám sát; Settings — cấu hình tích hợp & tham số hệ thống), KHÔNG phải danh sách module. Mỗi user có **một role duy nhất** toàn hệ thống; menu và action hiển thị khác nhau theo permission (PEP — action thiếu quyền bị **ẩn**, không disabled). Mọi badge là count server-side realtime. Desktop-first, worklist-centric.
>
> **[R2 — 13/09/2026 · Workspace Reorganization]:** (1) Tách **Settings** thành workspace quản trị đặc thù riêng (`/settings`, giữ nguyên surface S27 Integration & Settings); (2) bổ sung §1.0 Workspace Map — phân bổ **19 phân hệ (module) · 170 FEAT** theo workspace phòng ban. **Không thêm/bớt surface** (CORE-006 — inventory §2 vẫn 25 dòng); thay đổi chỉ ở tầng điều hướng và phân bổ tính năng. Căn cứ: `req-registry.json` (`departments` 5 DEPT · `modules` 19 MOD · `features` 170) + workflow-context §2.0.2 ($WORKSPACE_MAP 6 → 7 workspace).
>
> **[R3 — 13/09/2026 · Workspace Folder Structure]:** Cấu trúc thư mục vật lý của `bcerp-web/` tổ chức lại theo workspace — mỗi workspace là 1 thư mục chứa các **thư mục tài liệu giao diện (module)** của một bộ phận: `sales/` (crm · qdd · comm) · `finance/` (wallet · arap) · `ops/` (honb · adacc · propln · camp · capts · cskh · tiktok · slanot · cport) · `hr/` (hr-core · kpi) · `executive/` (datahub) · `admin/` (rbac) · `settings/` (stgw). Mỗi workspace có **Navigation riêng** (`[ws]/Navigation-[ws].md` — menu, screens, phân quyền, UI notes chi tiết của workspace đó); file này giữ vai trò **Navigation tổng quan** (workspace map + inventory đầy đủ 25 surfaces). Không đổi route, không thêm/bớt surface; mọi link tương đối giữa các file đã re-resolve + verify tồn tại (220/220 ref hợp lệ).

---

## 1. Sơ Đồ Menu (Menu Tree)

### 1.0. Workspace Map — Phân Hệ Theo Phòng Ban & Phân Bổ Tính Năng

> Tính năng được tổ chức theo workspace của **phòng ban sẽ sử dụng** — 5 workspace ánh xạ 5 phòng ban trong registry (`DEPT-SALES/FINANCE/OPS/HR/BOD`) + 2 **workspace quản trị đặc thù** không thuộc phòng ban nghiệp vụ: **Platform Admin** (quản trị truy cập & giám sát toàn hệ thống) và **Settings** (cấu hình tích hợp, credentials vault, tham số & chính sách hệ thống — tách riêng tại R2 vì vòng đời cấu hình ≠ tác vụ quản trị hằng ngày). Mỗi phân hệ thuộc **đúng 1 workspace chủ**; sự dùng chéo phòng ban ghi ở cột "Ghi chú cross-workspace" (không nhân bản surface — permission quyết định ai thấy gì).

**Bảng A — 7 workspace:**

| Workspace | Prefix | Phòng ban / vai chính | Surfaces (web nội bộ) | Trang đích | Phân hệ (module) |
|---|---|---|---|---|---|
| Sales | `/sales` | DEPT-SALES — SALES_L1–L3 (+L4/L5 [NR #8]) | S1, S2 (pane S1), S3, S5, S28; menu entry shared S4 | S1 My Pipeline | CRM-PIPELINE · QUOTATION-DEALDESK · COMMISSION-QUOTA (+ HONB shared) |
| Finance | `/finance` | DEPT-FINANCE — FIN_L1/L2 (+CFO/CEO escalation) | S6, S7, S10 | S6 Approval Inbox | WALLET-RECON · ARAP-PAYMENT |
| Ops | `/ops` | DEPT-OPS — OPS_PLAN/AM/CONT/AD (+DES/EDIT/ADS [NR #8]) | S4 (shared Sales↔Ops), S9, S13, S14, S15, S16, S17, S18, S19 | S4 Handoff Bridge | ADACCOUNT-CC · PROPOSAL-PLANNING · CAMPAIGN-DELIVERABLE · CAPACITY-TIMESHEET (∥HR) · TICKET-CSKH · TIKTOK-SHOP · SLA-NOTIF · CLIENT-PORTAL (quản trị account) |
| HR | `/hr` | DEPT-HR — HR_L1/L2 (+manager view giới hạn) | S20, S21, S22; menu entry shared S15 | S21 Leave Management | HR-CORE · KPI-PERFORMANCE (+ CAPTS duyệt song song) |
| Executive | `/exec` | DEPT-BOD — BOD_CEO, BOD_CFO_CTO | S23, S24 | S23 Executive BI | DATAHUB-BI (+ RBAC-AUDIT oversight qua S25) |
| **Platform Admin** | `/admin` | Quản trị đặc thù — SYS_ADMIN (+BOD oversight S25) | S26, S25 | S26 RBAC Admin | RBAC-AUDIT |
| **Settings** | `/settings` | Quản trị đặc thù — SYS_ADMIN (vận hành) · BOD_CFO_CTO (CTO duyệt) · BOD_CEO (chính sách ngưỡng-tier-SLA) | S27 | S27 Integration & Settings | SETTINGS-GW |

**Bảng B — 19 phân hệ → workspace (170 FEAT):**

| Phân hệ (module) | FEAT | Workspace chủ | Surfaces | Ghi chú cross-workspace |
|---|---|---|---|---|
| MOD-CRM-PIPELINE — CRM & Lead Pipeline V6.0 | 11 | Sales | S1, S2, S28 | Client 360 (S28) là hub mở từ mọi surface có khách hàng |
| MOD-QUOTATION-DEALDESK — Quotation & Deal Desk | 6 | Sales | S3 | Duyệt vượt định mức tạm SALES_L3 [NR vai — GM] |
| MOD-HANDOFF-ONBOARD — Handoff & Onboarding Bridge | 6 | Sales ↔ Ops (shared) | S4 | 1 surface 2 role views; menu entry ở cả 2 workspace |
| MOD-COMMISSION-QUOTA — Commission & Quota | 3 | Sales | S5 | FIN_L1/L2 đọc để kiểm chứng |
| MOD-WALLET-RECON — Wallet & Đối soát TKQC | 24 | Finance | S6, S7 | Trạng thái hard stop hiển thị read-only tại S9 (Ops) |
| MOD-ARAP-PAYMENT — Công nợ AR/AP & Giải ngân | 18 | Finance | S6, S10 | Client nhận invoice qua portal P3 (external view) |
| MOD-ADACCOUNT-CC — TKQC Ad Account Command Center | 8 | Ops | S9 | FIN_L1/L2 thấy trạng thái khớp tiền read-only |
| MOD-PROPOSAL-PLANNING — Proposal & Planning Workspace | 3 | Ops | S13 | — |
| MOD-CAMPAIGN-DELIVERABLE — Campaign & Deliverable Management | 10 | Ops | S14 | Client theo dõi qua portal P2 (read-only) |
| MOD-CAPACITY-TIMESHEET — Capacity & Timesheet | 5 | Ops ∥ HR (1 queue) | S15 | Menu entry cả 2 workspace, permission filter; nhân viên nhập qua mobile M3 |
| MOD-TICKET-CSKH — Ticket & CSKH | 5 | Ops | S16 | Client tạo/theo dõi ticket qua portal P4 |
| MOD-TIKTOK-SHOP — TikTok Shop Monitoring | 4 | Ops | S17 | Gate workflow TikTok Shop [NR — F-D-01] |
| MOD-SLA-NOTIF — SLA & Notification Engine | 5 | Ops | S18 | Cảnh báo tiêu thụ toàn hệ: S24 Alert Center + global drawer (không page riêng) |
| MOD-CLIENT-PORTAL — Client Portal | 7 | Ops (quản trị account nội bộ) | S19 | Bề mặt client thuộc SYS-PORTAL-WEB / SYS-MOBILE-PORTAL (P1–P4, trust boundary riêng) |
| MOD-HR-CORE — HR Core | 12 | HR | S20, S21 | Nhân viên tự phục vụ qua mobile ESS (M1–M5) |
| MOD-KPI-PERFORMANCE — KPI & Performance | 4 | HR | S22 | BOD view; manager xem team |
| MOD-DATAHUB-BI — Data Integration Hub & BI/BOD Dashboard | 15 | Executive | S23, S24 | FIN_L1/L2 đọc P&L (S23); alert role-scoped tới mọi manager |
| MOD-RBAC-AUDIT — RBAC & Audit Log | 18 | Platform Admin | S26, S25 | BOD oversight dùng chung route S25 (1 surface, 2 role views) |
| MOD-SETTINGS-GW — Settings & Integration Gateway | 6 | Settings | S27 | Nền feed cho 7 nền tảng QC + VAS; FIN_L1/L2 đọc trạng thái sync [NR]; vault CẤM mobile |

*(Kiểm tổng: 11+6+6+3+24+18+8+3+10+5+5+4+5+7+12+4+15+18+6 = **170 FEAT** = registry — không module mồ côi, không FEAT ngoài workspace.)*

### 1.1. Menu Tree

```
BCERP Web — nav rail tối 60px · topbar: tìm kiếm toàn cục · bell (drawer) · user
│
├── SALES (/sales) — quick: Ghi nhận lead · Tạo quote · Submit handoff
│   ├── My Pipeline (worklist lead/deal)      → /sales/pipeline             → sales/crm/screens-pipeline.md            [{leads_moi} {deals_cho_gate}]
│   │   └── Lead 360 (detail pane của S1)     → /sales/pipeline/leads/:id   → sales/crm/screens-lead-360.md
│   ├── Deal Desk                             → /sales/deal-desk            → sales/qdd/screens-deal-desk.md           [{quotes_cho_duyet}]
│   ├── Commission (mine / team)              → /sales/commission           → sales/comm/screens-commission.md
│   └── Client 360 (shared — mở từ link, không mục menu) → /sales/clients/:id → sales/crm/screens-client-360.md
│
├── FINANCE (/finance) — quick: Khớp tiền · Duyệt lệnh (A/R) · Khóa kỳ · Phát hành HĐĐT
│   ├── Approval Inbox                        → /finance/approvals          → finance/wallet/screens-approval-inbox.md   [{pending_approvals}]
│   ├── Ví & Đối soát (hard stop khớp tiền)   → /finance/wallet             → finance/wallet/screens-wallet-recon.md     [{mismatch} {hardstop_cho_khop}]
│   └── Công nợ & Giải ngân (tabs: AR · AP-Giải ngân · HĐĐT) → /finance/ar-ap → finance/arap/screens-ar-ap.md            [{aging_qua_han}]
│
├── OPS (/ops) — quick: Ký nhận handoff · Cấp phát TKQC (chỉ khi đã khớp tiền) · Lập campaign · Assign ticket
│   ├── Handoff Bridge (shared Sales↔Ops)     → /ops/handoff                → ops/honb/screens-handoff-bridge.md     [{handoff_cho_ky}]
│   ├── TKQC Registry (shared — FIN read-only) → /ops/ad-accounts           → ops/adacc/screens-tkqc-registry.md     [{tkqc_cho_cap_phat}]
│   ├── Proposal Stage-Gate Workspace         → /ops/proposals              → ops/propln/screens-proposal-stagegate.md
│   ├── Campaign & Deliverable                → /ops/campaigns              → ops/camp/screens-campaigns.md          [{deliverable_overdue}]
│   ├── Capacity & Timesheet (duyệt ∥ HR)     → /ops/capacity               → ops/capts/screens-capacity-timesheet.md [{timesheet_cho_duyet}] ¹
│   ├── Ticket Queue (+ Ticket 360)           → /ops/tickets                → ops/cskh/screens-tickets.md            [{sla_ve}]
│   ├── TikTok Shop Monitor                   → /ops/tiktok-shop            → ops/tiktok/screens-tiktok-monitor.md   [{tiktok_anomaly}]
│   ├── SLA Policy Rules                      → /ops/sla-policies           → ops/slanot/screens-sla-policies.md
│   └── Portal Accounts (client)              → /ops/portal-accounts        → ops/cport/screens-portal-accounts.md
│
├── HR (/hr) — quick: Duyệt phép · Duyệt timesheet · Cập nhật hồ sơ
│   ├── HR Records (tabs: Hồ sơ · HĐLĐ 90/60/30 · Rate card) → /hr/records  → hr/hr-core/screens-hr-records.md      [{hodl_sap_het_han}]
│   ├── Leave Management                      → /hr/leave                   → hr/hr-core/screens-leave.md           [{phep_cho_duyet}]
│   ├── KPI & Performance                     → /hr/kpi                     → hr/kpi/screens-kpi-performance.md
│   └── Capacity & Timesheet (role view HR)   → /ops/capacity               (cùng surface S15 — không nhân bản) ¹
│
├── EXECUTIVE (/exec) — quick: Duyệt escalation · Drill-down về nguồn
│   ├── Executive BI (tabs: P&L realtime · Phòng ban) → /exec/bi            → executive/datahub/screens-executive-bi.md
│   └── Alert Center (escalation, role-scoped) → /exec/alerts               → executive/datahub/screens-alert-center.md    [{escalation_timeout}]
│
├── PLATFORM ADMIN (/admin) — quick: Grant/revoke role · Mở access review · Tra cứu audit trail
│   ├── RBAC Admin                            → /admin/rbac                 → admin/rbac/screens-rbac-admin.md         [{access_review_due}]
│   └── Audit Log Query (BOD oversight dùng chung route) → /admin/audit     → admin/rbac/screens-audit-log.md
│
└── SETTINGS (/settings) — quick: Cấu hình connection · Nạp credential · Ban hành tham số
    └── Integration & Settings (tabs: Connections · Credentials · Tham số & Chính sách) → /settings → settings/stgw/screens-integrations-settings.md [{connection_degraded} {credential_sap_het}]
```

¹ S15 thuộc cả Ops và HR theo thiết kế duyệt song song — 1 route `/ops/capacity`, menu entry hiển thị ở cả 2 workspace với role view khác nhau (permission filter), không nhân bản surface.

- **Shared objects đứng đúng 1 chỗ:** Client 360 (S28 — hub, mở từ mọi surface có khách hàng, không mục menu), Handoff Bridge (S4 — 1 surface, 2 role views submit/nhận), TKQC Registry (S9 — FIN thấy trạng thái khớp tiền read-only; hành động khớp tiền nằm ở S7 Finance).
- **Trang đích workspace** = worklist chính của nó (Sales → S1, Finance → S6, Ops → Handoff inbox, HR → Leave, Exec → BI, Admin → RBAC, Settings → S27) — dashboard trong workspace luôn action-oriented, số liệu click ra được worklist. Không thêm surface "Home" ngoài inventory.
- **Notification = global drawer (bell)** trên mọi surface — S11 đã consolidate drop, không có page riêng.

---

## 2. Danh Sách Screen Groups

> Đủ 25 dòng tương ứng $SCREEN_INVENTORY sau consolidate (S8 Hard Stop Panel, S11 Notification, S12 Lệnh chi riêng đã drop; S28 thêm mới). Inventory §2.0.5 ghi "24 surfaces web" vì S2 được giữ ở dạng **master-detail pane của S1** (không page rời, không mục menu) — bảng dưới vẫn liệt kê S2 thành dòng riêng để traceability 1:1 UI-ID.

| # | Screen Group | Route | File | UI-ID | Module |
|---|---|---|---|---|---|
| S1 | My Pipeline (worklist lead/deal) | `/sales/pipeline` | `sales/crm/screens-pipeline.md` | `UI-WEB-LEAD-001` | MOD-CRM-PIPELINE |
| S2 | Lead 360 (detail pane của S1) | `/sales/pipeline/leads/:id` | `sales/crm/screens-lead-360.md` | `UI-WEB-LEAD-002` | MOD-CRM-PIPELINE |
| S3 | Deal Desk (quote + duyệt + e-sign) | `/sales/deal-desk` | `sales/qdd/screens-deal-desk.md` | `UI-WEB-DEAL-001` | MOD-QUOTATION-DEALDESK |
| S4 | Handoff Bridge (shared) | `/ops/handoff` | `ops/honb/screens-handoff-bridge.md` | `UI-WEB-HONB-001` | MOD-HANDOFF-ONBOARD |
| S5 | Commission (mine / team) | `/sales/commission` | `sales/comm/screens-commission.md` | `UI-WEB-COMM-001` | MOD-COMMISSION-QUOTA |
| S6 | Approval Inbox (FIN) | `/finance/approvals` | `finance/wallet/screens-approval-inbox.md` | `UI-WEB-APPR-001` | MOD-WALLET-RECON + MOD-ARAP-PAYMENT |
| S7 | Ví & Đối soát | `/finance/wallet` | `finance/wallet/screens-wallet-recon.md` | `UI-WEB-WALLET-001` | MOD-WALLET-RECON |
| S9 | TKQC Registry (Ad Account CC) | `/ops/ad-accounts` | `ops/adacc/screens-tkqc-registry.md` | `UI-WEB-ADACC-001` | MOD-ADACCOUNT-CC |
| S10 | Công nợ & Giải ngân (tabs: AR / AP-Giải ngân / HĐĐT) | `/finance/ar-ap` | `finance/arap/screens-ar-ap.md` | `UI-WEB-ARAP-001` | MOD-ARAP-PAYMENT |
| S13 | Proposal Stage-Gate Workspace | `/ops/proposals` | `ops/propln/screens-proposal-stagegate.md` | `UI-WEB-PROPLN-001` | MOD-PROPOSAL-PLANNING |
| S14 | Campaign & Deliverable | `/ops/campaigns` | `ops/camp/screens-campaigns.md` | `UI-WEB-CAMP-001` | MOD-CAMPAIGN-DELIVERABLE |
| S15 | Capacity & Timesheet (duyệt ∥ HR) | `/ops/capacity` | `ops/capts/screens-capacity-timesheet.md` | `UI-WEB-CAPTS-001` | MOD-CAPACITY-TIMESHEET |
| S16 | Ticket Queue + Ticket 360 | `/ops/tickets` | `ops/cskh/screens-tickets.md` | `UI-WEB-TICK-001` | MOD-TICKET-CSKH |
| S17 | TikTok Shop Monitor | `/ops/tiktok-shop` | `ops/tiktok/screens-tiktok-monitor.md` | `UI-WEB-TTSHOP-001` | MOD-TIKTOK-SHOP |
| S18 | SLA Policy Rules | `/ops/sla-policies` | `ops/slanot/screens-sla-policies.md` | `UI-WEB-SLA-001` | MOD-SLA-NOTIF |
| S19 | Portal Accounts (client) | `/ops/portal-accounts` | `ops/cport/screens-portal-accounts.md` | `UI-WEB-PORTAL-001` | MOD-CLIENT-PORTAL |
| S20 | HR Records (tabs: Hồ sơ / HĐLĐ / Rate card) | `/hr/records` | `hr/hr-core/screens-hr-records.md` | `UI-WEB-HRREC-001` | MOD-HR-CORE |
| S21 | Leave Management | `/hr/leave` | `hr/hr-core/screens-leave.md` | `UI-WEB-LEAVE-001` | MOD-HR-CORE |
| S22 | KPI & Performance | `/hr/kpi` | `hr/kpi/screens-kpi-performance.md` | `UI-WEB-KPI-001` | MOD-KPI-PERFORMANCE |
| S23 | Executive BI (tabs: P&L realtime / Phòng ban) | `/exec/bi` | `executive/datahub/screens-executive-bi.md` | `UI-WEB-BI-001` | MOD-DATAHUB-BI |
| S24 | Alert Center | `/exec/alerts` | `executive/datahub/screens-alert-center.md` | `UI-WEB-ALERT-001` | MOD-DATAHUB-BI + MOD-SLA-NOTIF |
| S25 | Audit Log Query | `/admin/audit` | `admin/rbac/screens-audit-log.md` | `UI-WEB-AUDIT-001` | MOD-RBAC-AUDIT |
| S26 | RBAC Admin | `/admin/rbac` | `admin/rbac/screens-rbac-admin.md` | `UI-WEB-RBAC-001` | MOD-RBAC-AUDIT |
| S27 | Integration & Settings (tabs: Connections / Credentials / Tham số & Chính sách) | `/settings` | `settings/stgw/screens-integrations-settings.md` | `UI-WEB-STGW-001` | MOD-SETTINGS-GW |
| S28 | Client 360 (shared surface) | `/sales/clients/:id` | `sales/crm/screens-client-360.md` | `UI-WEB-CLIENT-001` | MOD-CRM-PIPELINE (link MOD-CLIENT-PORTAL) |

[NEEDS_REVIEW] Trang đích workspace (landing tổng hợp work-queue từ nhiều surface) chưa có trong inventory — hiện theo nguyên tắc "landing = worklist chính" (§1). Nếu BOD muốn Home riêng mỗi workspace → phải bổ sung FEAT vào registry trước khi thêm surface, không tự thêm ở đây.

**Cơ Sở Giữ Lại Màn Hình (Screen Justification)** — rút gọn từ §2.0.5 workflow-context:

| Surface | Ai dùng — làm gì | Quyết định tại đây | Vì sao cần surface riêng (hoặc tab/mode) |
|---|---|---|---|
| S1+S2 | SALES hằng ngày — xử lý hàng đợi lead/deal theo stage | Advance/reject Gate 1–2, recycle lead, reassign | Worklist là pattern mặc định; S2 = master-detail pane, không page rời |
| S3 | SALES_L2/L3 + duyệt vượt định mức — chuỗi quote → margin check → duyệt → e-sign | Duyệt chiết khấu phân cấp; ký hợp đồng | 1 surface đa mode Create/View/Edit/Approve — tách page là nhân bản |
| S4 | SALES submit / OPS_AM nhận — ký nhận 2 phía + onboarding tasks | Ack handoff, mở tasks ADACC/PORTAL/CAMP | Cùng object, 2 role views — tách 2 page = nhân bản |
| S5 | SALES_L1 (mine) / L2-L3 (team + quota) — xem hoa hồng theo thực nhận | Drill-down deal nguồn, theo dõi clawback | 1 surface, role view filter theo permission |
| S6 | FIN_L1/L2 (+CFO/CEO escalation) — mọi lệnh chờ FIN | Approve/reject (keyboard-first), delegate, dual approval | Worklist tài chính duy nhất — tách theo loại lệnh = navigation vô ích |
| S7 | FIN — sổ phụ, đối trừ 3 số, khóa kỳ, khớp tiền TKQC | Khớp tiền (hard stop), điều chỉnh dual approval, khóa kỳ | Bề mặt tiền giữ hộ đặc thù money-safety — không trộn vào inbox |
| S9 | OPS_AM thao tác vòng đời — KYC, đăng ký, cấp phát | Cấp phát TKQC (chỉ khi đã khớp tiền), suspend/close | 1 surface permission-aware — FIN read-only, không nhân bản cho FIN |
| S10 | FIN — invoice, aging, dunning, lệnh chi, HĐĐT TT78 | Khởi tạo lệnh chi, phát hành HĐĐT, nhắc nợ | AR/AP/HĐĐT cùng dòng tiền, cùng user — tabs rõ ràng (S12 đã MERGE) |
| S13 | OPS_PLAN — soạn + duyệt proposal | Advance/duyệt stage-gate V6.0 | Chế độ làm việc riêng (soạn + gate), khác worklist thường |
| S14 | OPS_AM lập / OPS_CONT thực hiện — campaign + deliverable | Nghiệm thu (window 3 ngày), báo cáo | Core vận hành; deliverable cần bảng + trạng thái nghiệm thu |
| S15 | OPS_AM ∥ HR_L1/L2 — cùng 1 queue duyệt timesheet | Duyệt/từ chối theo vai, xem capacity team | Duyệt song song 2 phòng là THIẾT KẾ nghiệp vụ — permission quyết định ai thấy gì |
| S16 | OPS_CONT — queue theo SLA tier + ticket detail | Assign, resolve, escalate | SLA timer + tier là ngữ cảnh làm việc chính |
| S17 | OPS — monitoring TikTok Shop pull-based | Ack anomaly alert | Monitoring chuyên biệt — gộp vào campaign là sai domain (shop ≠ campaign) |
| S18 | OPS (owner) — cấu hình SLA per object + tier | CRUD rules | Config thưa, ít đổi; compliance history = tab read-only |
| S19 | OPS_AM — cấp/quản lý tài khoản client portal | Cấp/khóa account, reset | Tác vụ onboarding thật, nhỏ — gộp vào Campaign sai object |
| S20 | HR_L1/L2 — hồ sơ L1–L5, HĐLĐ 90/60/30, PII masking | CRUD hồ sơ, gia hạn HĐLĐ, rate card (thẩm định ∥ FIN) | Rate card ít đổi → MERGE thành tab (đủ, không cần page) |
| S21 | HR_L1/L2 + nhân viên (yêu cầu qua ESS mobile) | Duyệt phân cấp L1→L2 | Số dư tự động + lịch team = bề mặt riêng của HR |
| S22 | HR_L2 + quản lý + BOD xem — KPI 3 trụ cột | Calibration, PIP checkpoint 30-60-90 | Vòng đời năm/quý + calibration ≠ CRUD hồ sơ |
| S23 | BOD (+ FIN read) — P&L ≤5 phút, dashboard phòng ban | Drill-down về worklist nguồn | Ràng buộc realtime ≤5 phút nhưng cùng bề mặt tiêu thụ BI → tabs |
| S24 | BOD + mọi manager (role-scoped) — escalation cross-module | Ack, escalate, jump object nguồn | Escalation inbox là worklist, không phải chart |
| S25 | BOD (oversight) + SYS_ADMIN (vận hành) — audit WORM | Truy vết trail per object | Cùng object, khác scope filter — 1 surface permission-aware |
| S26 | SYS_ADMIN — users, roles, quarterly access review | Grant/revoke, review campaign, SSO/MFA | Quản trị RBAC riêng, audit review cần context |
| S27 | SYS_ADMIN vận hành + CTO (BOD_CFO_CTO) duyệt — 7 nền tảng + VAS | Nạp credential (duyệt), degraded, revoke | Connections/credentials/tham số cùng lifecycle STGW → MERGE tab |
| S28 | SALES/OPS/FIN (role views) — mọi thông tin 1 khách | Jump tới surface tương ứng theo nhu cầu | Hub chống nhân bản thông tin khách trên 7 surfaces |

---

## 3. Phân Quyền & Hiển Thị Menu

> 19 role (khớp business-context §1 / P3-01 §8.1): BOD_CEO · BOD_CFO_CTO · SYS_ADMIN · HR_L1 · HR_L2 · FIN_L1 · FIN_L2 · SALES_L1 · SALES_L2 · SALES_L3 · SALES_L4* · SALES_L5* · OPS_PLAN · OPS_AM · OPS_CONT · OPS_AD · OPS_DES* · OPS_EDIT* · OPS_ADS* — (* = [NEEDS_REVIEW #8: chờ BOD chốt vai mở rộng]). Một user một role; menu hiển thị theo permission của role đó, badge đếm theo scope dữ liệu được phép thấy.

| Mục menu | Route | Roles thấy | Hành động theo permission | Badge | Điều kiện hiển thị |
|---|---|---|---|---|---|
| **Workspace Sales** | `/sales/*` | SALES_L1–L3 (+L4/L5 khi chốt #8) | — | — | Có permission CRM/QDD/HONB/COMM |
| My Pipeline | `/sales/pipeline` | SALES_L1 (mine) · L2/L3 (team) | Advance/reject gate: L2/L3; reassign: L2+ | `{leads_moi}` `{deals_cho_gate}` | Luôn |
| Lead 360 | `/sales/pipeline/leads/:id` | như S1 | Gate action ẩn nếu không phải L2/L3 | — | Pane của S1 |
| Deal Desk | `/sales/deal-desk` | SALES_L1–L3 | Duyệt chiết khấu theo định mức; vượt định mức → GM [NEEDS_REVIEW: GM chưa ánh xạ trong 19 role — tạm SALES_L3, chốt cùng P3-01 §8.1]; e-sign | `{quotes_cho_duyet}` | Luôn |
| Commission | `/sales/commission` | SALES_L1 (mine) · L2/L3 (team+quota) · FIN_L1/L2 (read, kiểm chứng) | Read + drill-down deal nguồn | `{clawback}` khi có | Luôn |
| **Workspace Finance** | `/finance/*` | FIN_L1/L2 · BOD khi escalation | — | — | Có permission WALLET/ARAP |
| Approval Inbox | `/finance/approvals` | FIN_L1/L2 · BOD_CFO_CTO (CFO) · BOD_CEO (lệnh chi >200tr) | Duyệt/từ chối (A/R), delegate; dual approval khóa slot 2 đến khi đủ slot 1 | `{pending_approvals}` | Luôn |
| Ví & Đối soát | `/finance/wallet` | FIN_L1/L2 | Đối trừ 3 số, điều chỉnh (dual), khóa kỳ (L2), khớp tiền TKQC (FIN_L1) | `{mismatch}` `{hardstop_cho_khop}` | Luôn; OPS không thấy menu — chỉ nhận banner cảnh báo trong Ops |
| Công nợ & Giải ngân | `/finance/ar-ap` | FIN_L1/L2 | Duyệt theo ngưỡng 5/50/200tr + SoD 4 vai; HĐĐT; dunning | `{aging_qua_han}` | Luôn |
| **Workspace Ops** | `/ops/*` | OPS_PLAN/AM/CONT/AD (+DES/EDIT/ADS khi chốt #8); SALES chỉ thấy S4; FIN chỉ thấy S9 (read) | — | — | Có permission module Ops |
| Handoff Bridge | `/ops/handoff` | SALES_L1–L3 + toàn bộ OPS | Nút Submit (SALES) / Ký nhận (OPS_AM) theo role | `{handoff_cho_ky}` (OPS) · `{handoff_cho_ack}` (SALES) | Menu entry ở cả Sales + Ops |
| TKQC Registry | `/ops/ad-accounts` | OPS_AM (thao tác) · OPS khác (view) · FIN_L1/L2 (read-only) | KYC, yêu cầu cấp phát — nút ẩn khi chưa khớp tiền | `{tkqc_cho_cap_phat}` | Luôn |
| Proposal Stage-Gate | `/ops/proposals` | OPS_PLAN (soạn+duyệt) · OPS_AD/AM (view) · DES/EDIT/ADS contribute [NR] | Advance/duyệt gate | `{gate_cho_duyet}` | Permission PROPLN |
| Campaign & Deliverable | `/ops/campaigns` | OPS_AM (lập) · OPS_CONT (thực hiện) · DES/EDIT/ADS [NR] | Update deliverable, nghiệm thu, báo cáo | `{deliverable_overdue}` | Permission CAMP |
| Capacity & Timesheet | `/ops/capacity` | OPS_AM + HR_L1/L2 (1 queue, permission filter) | Duyệt/từ chối theo vai | `{timesheet_cho_duyet}` | Menu ở cả Ops + HR |
| Ticket Queue | `/ops/tickets` | OPS_CONT (xử lý) · OPS_AD/AM (view, reassign) | Assign, resolve, escalate | `{sla_ve}` | Permission CSKH |
| TikTok Shop Monitor | `/ops/tiktok-shop` | Toàn bộ vai OPS | Ack alert, drill-down | `{tiktok_anomaly}` | Permission TIKTOK |
| SLA Policy Rules | `/ops/sla-policies` | OPS_AM/OPS_PLAN (owner) · OPS_AD | CRUD rules | — | Permission SLANOT |
| Portal Accounts | `/ops/portal-accounts` | OPS_AM | Cấp/khóa, reset | — | Permission CPORT |
| **Workspace HR** | `/hr/*` | HR_L1/L2 · manager (view giới hạn) | — | — | Có permission HR-CORE/KPI/CAPTS |
| HR Records | `/hr/records` | HR_L1/L2 · manager các phòng (view giới hạn, PII lương masked) | CRUD hồ sơ, gia hạn HĐLĐ; rate card tab (FIN read thẩm định) | `{hodl_sap_het_han}` | Luôn |
| Leave Management | `/hr/leave` | HR_L1 → L2 (duyệt phân cấp) | Approve/reject | `{phep_cho_duyet}` | Luôn |
| KPI & Performance | `/hr/kpi` | HR_L2 (calibration) · quản lý (team) · BOD (view) | Calibration, PIP checkpoint | `{pip_dang_chay}` | Permission KPI |
| **Workspace Executive** | `/exec/*` | BOD_CEO · BOD_CFO_CTO | — | — | Role BOD |
| Executive BI | `/exec/bi` | BOD · FIN_L1/L2 (read) | Drill-down về worklist nguồn, export | — | Luôn |
| Alert Center | `/exec/alerts` | BOD · manager role-scoped (SALES_L2+, HR_L2, OPS_AM, FIN_L2) | Ack, escalate, jump object nguồn | `{escalation_timeout}` | Có escalation trong scope |
| **Workspace Platform Admin** | `/admin/*` | SYS_ADMIN · BOD (S25 oversight) | — | — | Role SYS_ADMIN/BOD |
| RBAC Admin | `/admin/rbac` | SYS_ADMIN | Grant/revoke, review campaign, SSO/MFA | `{access_review_due}` | Luôn |
| Audit Log Query | `/admin/audit` | SYS_ADMIN (vận hành) · BOD_CEO/CFO_CTO (oversight) | Filter, export, trail per object | — | 1 route, 2 role-view scope filter |
| **Workspace Settings** | `/settings/*` | SYS_ADMIN (vận hành) · BOD_CFO_CTO (CTO duyệt) · BOD_CEO (chính sách ngưỡng-tier-SLA) · FIN_L1/L2 (đọc trạng thái sync — read-only [NR]) | — | — | Permission STGW |
| Integration & Settings | `/settings` | SYS_ADMIN · BOD_CFO_CTO (duyệt credential/chính sách) | Cấu hình, nạp credential (duyệt CTO), degraded, revoke | `{connection_degraded}` `{credential_sap_het}` | Luôn; vault CẤM trên mobile (app ẩn tính năng) |

[NEEDS_REVIEW #8] SALES_L4/L5 và OPS_DES/EDIT/ADS: menu hiện ẩn toàn phần; khi BOD chốt vai → bật theo đúng matrix trên (Sales: S1–S5, S28; Ops executor: S14, S15 view, S16 view).

---

## 4. UI Notes

### 4.1. Quick Actions (Header / Command Bar)

Topbar toàn cục (mọi surface):

| Action | Icon | Phím tắt | Mở gì |
|---|---|---|---|
| Tìm kiếm toàn cục (object theo mã nghiệp vụ) | `search` | `Ctrl+K` | Global Search Dialog |
| Thông báo | `bell` | — | Global drawer (không page) — badge `{unread}` |
| Tạo mới theo ngữ cảnh | `plus` | `Ctrl+N` | Dialog tạo object của surface hiện hành |
| Duyệt nhanh keyboard | — | `A` / `R` / `↑↓` / `Enter` | Trong Approval Inbox + mọi worklist có duyệt (design-system §4.10) |
| Xác nhận MFA | `shield-mfa` | — | Modal step-up sau duyệt tiền / khóa kỳ / vault |

Quick actions theo workspace nằm ngay dưới tên workspace trên nav rail (đã liệt kê ở Menu Tree §1). Nút "Cấp phát TKQC" chỉ xuất hiện khi hard stop đã gỡ (đã khớp tiền) — ẩn, không disabled.

### 4.2. Breadcrumb Pattern

Breadcrumb theo **workflow**, không theo menu tree cứng:

```
[Workspace] > [Surface] > [Object #mã nghiệp vụ]

Ví dụ:
  Finance > Approval Inbox > [Lệnh chi #…]
  Ops > TKQC Registry > [Ad Account #…]
  Sales > My Pipeline > [Lead #…]
  Settings > Integration & Settings > [Connection: Meta Ads]
```

Quy tắc: cấp 1 = workspace hiện hành theo permission user; khi mở object từ nơi khác (Alert Center, Client 360, deep-link S7↔S9) crumb vẫn theo surface chứa object + nút "Về nguồn" bên phải header; object luôn hiển thị mã nghiệp vụ (không UUID nội bộ); tối đa 3 cấp, phần sâu hơn thu vào dropdown.

### 4.3. Quy Ước Đặt Tên

| Loại | Quy ước | Ví dụ |
|---|---|---|
| Route | kebab-case ASCII, prefix workspace, tab = `?tab=` | `/finance/ar-ap?tab=hddt` |
| File spec | `[ws]/[module]/[ten-screen].md` — thư mục workspace (R3) chứa thư mục module canonical | `finance/wallet/screens-approval-inbox.md` |
| UI-ID | `UI-WEB-[OBJ]-[NNN]` | `UI-WEB-LEAD-001` |
| Trạng thái hiển thị | Khớp token §1 design-system, tiếng Việt có dấu | Nháp · Chờ duyệt · Đã duyệt · SLA vỡ · Không khớp |

### 4.4. Icon Library

> Mọi icon thuộc thư viện **Lucide** (design-system §6: SVG inline, stroke 1.5, 12/16/20/24px, `currentColor`). Icon hành động quan trọng luôn kèm label hoặc `aria-label`.

| Menu workspace | Icon | | Icon nghiệp vụ bắt buộc (§6) | Dùng khi nào |
|---|---|---|---|---|
| Sales | `target` | | `gate` | Cổng duyệt (Gate 1/2, stage-gate) |
| Finance | `wallet` | | `signature` | Bàn giao có ký (Handoff Bridge, e-sign) |
| Ops | `workflow` | | `lock-money` | Hard stop khớp tiền |
| HR | `users` | | `clock-sla` | SLA timer / queue |
| Executive | `bar-chart-3` | | `undo-clawback` | Clawback hoa hồng |
| Platform Admin | `shield-check` | | `file-manual` | Dữ liệu thủ công (degraded mode) |
| Settings | `settings` | | `shield-mfa` | Bước xác nhận MFA |

### 4.5. Quy ước Xuyên Màn Hình

- **StatusBadge nhất quán:** 1 badge/hàng theo 10 token §1 design-system, luôn màu + icon + chữ (color-blind safe); trạng thái tiền (mismatch, hard stop, clawback) là **WarningIndicator banner + queue entry FIN**, không bao giờ chỉ là badge.
- **Owner/assignee thống nhất:** avatar + tên + phòng ban ở mọi list và detail; gán qua AssigneePicker lọc theo data-scope RBAC.
- **WaitingOnIndicator bắt buộc trên mọi object surface** (ràng buộc thiết kế số 1): chip trong row + khối trong header detail — "đang chờ ai, chờ bao lâu rồi"; màu neutral → `sla-warning` (≥50% SLA) → `sla-breach` (kèm icon chuông, tự nhảy đầu queue).
- **Quick navigation giữa related records:** Client 360 là hub — mọi surface có khách hàng link vào `/sales/clients/:id`; ProgressTracker cho phép click stage đã có quyền xem để nhảy surface (Lead → Quote → Handoff → Khớp tiền → Nghiệm thu → Invoice); Alert Center luôn có "jump về object nguồn"; deep-link 2 chiều S7 (khớp tiền) ↔ S9 (trạng thái).
- **Nút Duyệt luôn `--color-primary`** (không xanh lá); từ chối bắt buộc nhập lý do ≥10 ký tự; action thiếu quyền bị ẩn hoàn toàn (PEP).

---

### 4.5. Bố Cục & Responsive (ux-architect)

#### Kiến trúc CSS

**Naming: BEM**, mở rộng từ quy ước §6 design-system. Chọn BEM (không utility-first) vì: (a) team ERP nhỏ, surfaces là component dày đặc (datagrid vài trăm cell, split view, panel) — utility-first làm markup phình, khó review; (b) 12 component nghiệp vụ §4 map 1:1 sang block; (c) tokens đã là CSS custom properties, BEM giữ cascade đoán được. Cú pháp: `bcerp-{block}__{element}--{modifier}` (VD `bcerp-datagrid__cell--money`, `bcerp-side-panel--overlay`). Chỉ cho phép một lớp utility mỏng tiền tố `u-` (spacing, `u-numeric` bật `--font-numeric`, `u-visually-hidden`).

Tổ chức file (import theo thứ tự = thứ tự cascade):

```
src/styles/
├── tokens/        tokens.css — nơi DUY NHẤT chứa giá trị, sinh từ design-system §1–§3
├── base/          reset.css, typography.css, focus.css (focus ring 2px toàn cục)
├── layout/        app-shell.css, grid.css, containers.css
├── components/    1 file/block: datagrid, side-panel, command-bar, approval-card…
├── surfaces/      worklist.css, split-view.css, detail-360.css, dashboard.css, registry.css
└── utilities/     u-*.css
```

Khai báo `@layer tokens, base, layout, components, surfaces, utilities` — surface không bao giờ thắng component bằng specificity, chỉ bằng layer.

**Theming (light-first):** giá trị light đặt ở `:root`; hook `[data-theme="dark"]` chừa sẵn nhưng v1 không triển khai. Density là "theme" duy nhất cần ngay: attribute `data-density="compact|comfortable"` trên surface root đổi `--row-height-*` — toggle per-user trong **menu user trên topbar** (Preferences cá nhân, mọi role đều có), persist — KHÔNG nằm trong workspace `/settings` (đó là cấu hình hệ thống do SYS_ADMIN/CTO quản). **Workspace KHÔNG theme màu riêng** — token trạng thái là bắt buộc, cấm tint tự chế; bản sắc workspace chỉ qua nav rail (active icon + `--color-primary`) và breadcrumb.

#### App shell + breakpoints (desktop-first)

App shell (CSS Grid): `grid-template-columns: 60px 1fr; grid-template-rows: 48px auto auto 1fr` — nav rail (`--color-nav-rail`) | topbar (tìm kiếm toàn cục · bell → notification drawer · user), rồi page-header (breadcrumb + tiêu đề + action), CommandBar, content. Notification là global drawer, không phải page (đúng consolidation S11).

Breakpoints — base styles = desktop, chỉ dùng `max-width` queries:

| Query | Thay đổi |
|---|---|
| Base ≥1280px | Nav rail đầy đủ, split view, side panel 360px đẩy nội dung |
| `max-width: 1279px` | Nav rail thu icon; datagrid ẩn cột phụ (giữ tiền + trạng thái); SidePanel → overlay; split view → master full, detail mở như panel |
| `max-width: 767px` | Chỉ bật cho surface có nghiệp vụ mobile thật (duyệt nhanh manager, ack Alert Center, xem commission); list → card, touch ≥44px; **datagrid data-heavy không render — hiển thị EmptyState "Mở trên web"** |

Container: worklist/approval full-width max 1920px; dashboard max 1600px center; form/edit max 960px. Grid 12 cột, gutter `--space-4`, margin trang `--space-6`.

#### Surface → layout pattern (design-system §5)

| Nhóm surface (inventory) | Pattern | Density / container |
|---|---|---|
| S1 (+Lead 360 detail), S16, S15 | W2 split view 40/60: `minmax(360px, 40%) 1fr` | Compact 32px, full-width |
| S6, S21, S24 (thân escalation inbox), S10 (tabs AR/AP/HĐĐT) | W1 worklist + bulk bar + quick chips | Compact; S6 keyboard-first |
| S7, S9, S5, S17 | W1 variant standard (S7 thêm dải đối trừ 3 số) | Compact (tiền) |
| S3 Deal Desk, S28 Client 360, S14 campaign 360 | W3 content + panel phải 360px (`1fr 360px`): WaitingOn + ProgressTracker + Timeline 3 dòng | Comfortable; panel collapse được |
| S23 Executive BI | W4 dashboard grid (KPI row → widget 12 cột, widget click → worklist đã lọc) | Spacious, max 1600px |
| S24 (khung trên), S22 | W4 cho hàng KPI/SLA + thân W1 | Spacious + compact |
| S18, S19, S20, S26, S27, S25 | Registry/admin: bảng standard + edit qua SidePanel 480px; form cấu hình container 960px | Comfortable |

**CSS isolation:** mọi component chỉ style trong block của nó (cấm selector con xuyên block); surface files chỉ viết bên trong `[data-surface="{tên}"]`; cấm hex ngoài `tokens.css`; z-index theo scale token (`--z-bulk-bar < --z-panel < --z-drawer < --z-modal < --z-toast`); vendor/thư viện thứ ba bọc trong `bcerp-vendor-*`. Không Shadow DOM — phá inheritance token.

#### Keyboard-first Approval Inbox (S6)

Vùng inbox là listbox roving-tabindex: ↑↓ chuyển ApprovalCard, **A** duyệt, **R** từ chối (mở modal, focus thẳng textarea lý do ≥10 ký tự), Enter mở context (SidePanel 480px), Space chọn bulk, `?` mở cheat-sheet phím tắt. Phím tắt vô hiệu khi focus nằm trong input/combobox. Sau duyệt (kể cả MFA step-up): focus chuyển card kế tiếp, không reload danh sách. Esc đóng panel và trả focus về card/hàng vừa mở. Focus luôn visible 2px; processing state khóa nút chống double-submit; mọi đường xử lý tiền không có animation (chỉ state + toast).

## Tài Liệu Liên Quan

| Nội dung | File |
|---------|------|
| **Navigation các workspace (R3)** | `sales/Navigation-sales.md` · `finance/Navigation-finance.md` · `ops/Navigation-ops.md` · `hr/Navigation-hr.md` · `executive/Navigation-executive.md` · `admin/Navigation-admin.md` · `settings/Navigation-settings.md` |
| Thiết kế chi tiết màn hình | `[ws]/[module-name]/[screen-group].md` (theo thư mục workspace) |
| API endpoints | `../../phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `../../phase3-architecture/technical-specs/integration-map.md` |
| Design system | `../design-system.md` |
| REQ-IDs | `../../_meta/req-registry.json` |


> **[F-C-04 merge note]:** S9 TKQC Registry (`/ops/ad-accounts`) BỔ SUNG vào danh sách Ops executor surfaces; các đường thao tác OPS_ADS trên S9 đang ghi [NEEDS_REVIEW #8] — xem screens-tkqc-registry.md cuối file.
