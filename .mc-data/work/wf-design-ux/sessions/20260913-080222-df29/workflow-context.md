# Workflow Context + Screen Inventory + Consolidation — BCERP (Step 2.0, wf-design-ux v4.1)

> Session `20260913-080222-df29` | Main conversation Step 2.0 | Nguồn: business-context.md (§1–§6, session wf-design 20260913-053848-f4d7), P3-01 §3/§9, integration-map.md, req-registry (170 FEAT).
> Scope guard CORE-006: chỉ screen cho modules/features trong registry. Thiếu → `[NEEDS_REVIEW]`.
> Đơn vị thiết kế cấp cao hơn page: **Workspace** (theo phòng ban). $WORKFLOW_MAP / $SCREEN_INVENTORY / $WORKSPACE_MAP set từ file này.

---

## §2.0.1 Workflow Map — object × stage × owner × state

> Rút gọn từ business-context.md §2 (Vòng Đời Business Object) — bản đầy đủ là nguồn chính. Ở đây chỉ liệt kê các điểm ảnh hưởng thiết kế màn hình.

| Business Object (owner module) | Stages chính | Ai đổi state | Ai xem / sửa / approve |
|---|---|---|---|
| Lead (CRM) | new → dedup → assigned → scored (Tier A–E) → Gate1 → qualified → Gate2 signed → handed_to_cs / rejected / recycled | SALES_L1 nhập (hard gate); scoring auto; Gate 1/2 do SALES_L2/L3 | SALES xem full; OPS xem sau handoff; BOD qua BI |
| Quotation/Deal (QDD) | draft → margin_check → discount_approval (vượt định mức → GM) → approved → contracting (e-sign) → signed | SALES soạn; phân cấp duyệt chiết khấu; GM duyệt vượt | SALES; FIN thấy giá trị đã ký (feed giải ngân) |
| Handoff Package (HONB) | draft → sales_submit → ops_ack (ký 2 phía) → onboarding_tasks → completed | SALES submit; OPS_AM nhận + ký | SALES + OPS (shared surface); task sinh cho ADACC/PORTAL/CAMP |
| Proposal/Plan (PROPLN) | stage-gate V6.0 `[NEEDS_REVIEW: tên gates đọc spec gốc]` | OPS_PLAN soạn + duyệt theo gate | OPS; BOD xem tổng quan qua BI |
| Campaign/Deliverable (CAMP) | planned → in_flight → delivered → reported; A/B `[NEEDS_REVIEW]` | OPS_AM lập; OPS_CONT thực hiện; nghiệm thu 3 ngày | OPS; client xem trên portal (read-only) |
| TKQC Ad Account (ADACC) | kyc_required → kyc_verified → registered → **pre_spend_hardstop_check** → active → suspended/closed | OPS registry + vòng đời; **hard stop = FIN_L1 "đã khớp tiền"** | OPS thao tác; FIN xem trạng thái khớp tiền (read-only); BOD qua BI |
| Ví & Lệnh tiền (WALLET) | entry → reconciling (3 số) → matched/mismatch → period_locked; lệnh: draft → dual_approval → executed | FIN_L1 đối trừ + khóa kỳ (FIN_L2); dual approval FIN_L1+L2 | FIN duy nhất; OPS thấy cảnh báo góc ops; client thấy số dư read-only |
| AR/AP & Lệnh chi (ARAP) | AR: invoice → aging → dunning → paid; AP: draft → ngưỡng 5/50/200tr (L2→CFO→CEO) → SoD 4 vai → disbursed; HĐĐT TT78 | FIN_L1 khởi tạo; duyệt theo ngưỡng + delegate | FIN; BOD escalation cuối; client nhận invoice qua portal |
| Timesheet/Capacity (CAPTS) | draft → submitted → reviewed (OPS ∥ HR) → approved → capacity_computed | Nhân viên nhập (mobile); OPS_AM + HR duyệt song song | Nhân viên xem của mình; OPS/HR duyệt |
| Nghỉ phép (HR-CORE) | requested → balance_check → phân cấp L1→L2 → approved/rejected | Nhân viên; HR duyệt | Nhân viên + HR |
| Hồ sơ & HĐLĐ (HR-CORE) | active → expiring (90/60/30) → renewed/expired | HR quản | HR; manager xem giới hạn; PII lương Confidential/Restricted |
| KPI/PIP (KPI) | auto_aggregate (3 trụ cột) → calibration → finalized; PIP 30-60-90 | Auto từ CAPTS/COMM/CRM; HR_L2 calibration | HR + BOD |
| Ticket (CSKH) | open → assigned → in_progress → resolved → closed (SLA timer theo tier) | OPS_CONT xử lý; SLANOT escalation | OPS; client tạo/theo dõi trên portal |
| Commission (COMM) | computed (theo thực nhận) → clawback_check → approved → paid | Auto từ ARAP+QDD; clawback khi hoàn tiền | SALES xem của mình; L2/L3 quota; FIN kiểm chứng |
| Connection (STGW) | configured → vaulted → active → degraded(manual)/disabled/revoked | CTO + SYS_ADMIN | SYS_ADMIN vận hành; BOD audit |
| TikTok Shop (TIKTOK) | connected → monitoring → alert | Auto từ API; OPS theo dõi | OPS |
| P&L / BI (DATAHUB) | ingest → reconcile → publish (≤5 phút) → alert | Auto | BOD + FIN tiêu thụ |

**Waiting-on map (ràng buộc thiết kế số 1):** OPS chờ FIN (hard stop khớp tiền) · SALES chờ GM (chiết khấu) · SALES chờ FIN (thu tiền → commission) · FIN chờ OPS (yêu cầu cấp phát) · FIN chờ khách (AR) · OPS chờ SALES (handoff submit). → Mọi object surface PHẢI hiển thị "đang chờ ai, chờ bao lâu rồi" (WaitingOnIndicator).

---

## §2.0.2 Workspace Mapping — phòng ban → workspace → nội dung

| Workspace | Vai chính | Công việc xử lý (work queues) | Alerts / exceptions | Quick actions | Cross-dept dependencies | KPI phục vụ hành động |
|---|---|---|---|---|---|---|
| **Sales Workspace** | SALES_L1/L2/L3 | Pipeline của tôi; deals chờ Gate; chờ ký handoff; chờ chiết khấu GM; commission của tôi | Lead chưa ghi nhận hết (hard gate); chiết khấu vượt định mức; handoff bị từ chối | Ghi nhận lead; tạo quote; submit handoff | Chờ OPS ký nhận; chờ FIN thu tiền (commission) | Pipeline value, win rate, tier mix |
| **Finance Workspace** | FIN_L1/L2 (+CFO/CEO escalation) | Approval inbox (dual approval, lệnh chi ngưỡng, điều chỉnh ví); đối trừ 3 số; hard stop queue; AR aging + dunning; HĐĐT | Số dư < 3 ngày chi (vàng, SLA đỏ 2h); mismatch; AML T1–T6; aging vượt hạn | Khớp tiền; approve/reject lệnh; khóa kỳ; phát hành HĐĐT | Hard stop chặn OPS (TKQC); nhắc khách qua portal | Cash runway, đối trừ backlog, aging buckets |
| **Ops Workspace** | OPS_PLAN/AM/CONT | Handoff inbox (ký nhận); proposal stage-gate; campaign/deliverable; capacity; TKQC registry; ticket queue; TikTok monitor; portal accounts | Chờ hard stop FIN; deliverable overdue; SLA sắp vỡ/đã vỡ; TikTok anomaly | Ký nhận handoff; cấp phát TKQC (khi đã khớp); lập campaign; assign ticket | Chờ SALES submit handoff; chờ FIN khớp tiền; feed portal + client | SLA compliance, capacity utilization, deliverable on-time |
| **HR Workspace** | HR_L1/L2 | Hồ sơ + HĐLĐ (90/60/30); duyệt nghỉ phép phân cấp; duyệt timesheet (∥ OPS); KPI calibration; PIP; rate card | HĐLĐ sắp hết hạn; KPI dưới chuẩn → PIP trigger | Duyệt phép; duyệt timesheet; cập nhật hồ sơ | Song song OPS (timesheet); cùng FIN thẩm định rate card | Headcount, attrition, KPI distribution |
| **Executive Workspace (BOD)** | BOD_CEO, BOD_CFO_CTO | P&L realtime; BI dashboards; Alert Center (escalation cuối); duyệt vượt 200tr; chính sách/tier; audit oversight | Mọi escalation timeout; SLA đỏ tập trung | Duyệt escalation; xem drill-down | Nhận escalation từ FIN/SALES/OPS/HR | P&L, cash, pipeline, SLA toàn công ty |
| **Platform Admin Workspace** | SYS_ADMIN + BOD_CFO_CTO (CTO) | RBAC/roles/quarterly access review; Integration Gateway (7 nền tảng + VAS); credentials vault; tham số hệ thống; audit log query | Connection degraded; credential sắp hết hạn; access review due | Cấu hình connection; nạp credential; grant/revoke role | Cấu hình cho mọi module (STGW nền cho 7 nền tảng) | Connection health, review completion |

**Dashboard principle:** dashboard trong workspace = operational/action-oriented (số → click ra worklist tương ứng), KHÔNG chỉ xem số.

---

## §2.0.3 Screen Inventory (proposed — trước consolidation)

> FEAT-IDs: prefix nhóm theo module (registry: FEAT-CORE-*/ERP-*/WEB-*/PORTAL-*/MBI-* là touchpoint cùng logic; module là owner canonical). "WS" = workspace.

| # | Screen (proposed) | Purpose | Primary role | Object | WS | Main actions | Related | FEAT-IDs |
|---|---|---|---|---|---|---|---|---|
| S1 | My Pipeline (worklist lead/deal) | Hàng đợi lead + deal của tôi theo stage | SALES_L1/L2/L3 | Lead, Deal | Sales | Filter, assign, advance gate, reject/recycle | S2, S3, Client 360 | CRM-001..005 |
| S2 | Lead 360 (detail) | Timeline, score K1–K12, tier, gate status, activities | SALES | Lead | Sales | Update, reassign, advance/reject gate, ghi nhận hoạt động | S1 | CRM-001..005 |
| S3 | Deal Desk (quote builder + approval + contracting) | Soạn quote, margin check, duyệt chiết khấu, e-sign | SALES_L2/L3 + GM | Quotation, Contract | Sales | Tạo/edit quote, submit duyệt, approve/reject (GM), e-sign | S1, S12 | QDD-001..002 |
| S4 | Handoff Bridge (shared) | Ký nhận 2 phía sales→ops + onboarding tasks | SALES submit / OPS_AM nhận | Handoff Package | Sales + Ops | Submit, ack/ký nhận, theo dõi tasks | S3, S9, S14 | HONB-001..002 |
| S5 | Commission của tôi / quota | Xem commission theo thực nhận, clawback, quota | SALES_L1 (mine) / L2-L3 (team) | Commission | Sales | Xem, drill-down deal nguồn | S1, S10 | COMM-001 |
| S6 | Approval Inbox (FIN) | Mọi lệnh chờ FIN: dual approval, lệnh chi, điều chỉnh ví, đ.gtỷ giá, hoàn tiền | FIN_L1/L2 (+CFO/CEO) | Lệnh tiền, Lệnh chi | Finance | Approve/reject (keyboard), delegate, xem context | S7, S10 | WALLET-003..006, ARAP-003..004 |
| S7 | Ví & Đối soát | Sổ phụ, đối trừ 3 số, matched/mismatch, khóa kỳ, **hard stop khớp tiền** | FIN_L1/L2 | Ví, Sổ phụ | Finance | Đối trừ, điều chỉnh (dual approval), khóa kỳ, khớp tiền TKQC | S6, S9 | WALLET-001..007 |
| S8 | ~~Hard Stop Panel~~ | — | — | — | — | Consolidated → S7 + S9 (xem §2.0.5) | — | ARAP/ADACC |
| S9 | TKQC Registry (Ad Account CC) | Vòng đời account, KYC, hard stop status, cấp phát | OPS_AM (thao tác) + FIN (trạng thái khớp tiền, read-only) | TKQC Ad Account | Ops | Đăng ký, KYC check, yêu cầu cấp phát (khi đủ điều kiện), suspend/close | S4, S7 | ADACC-001..003 |
| S10 | Công nợ & Giải ngân (tabs: AR / AP-Giải ngân / HĐĐT) | Invoice, aging, dunning, lệnh chi theo ngưỡng, HĐĐT TT78 | FIN_L1/L2 | AR, AP, HĐĐT | Finance | Tạo invoice, nhắc nợ, khởi tạo lệnh chi, phát hành HĐĐT | S6, P3 | ARAP-001..007 |
| S11 | ~~Notification Center page~~ | — | — | — | — | Consolidated → global drawer (xem §2.0.5) | — | SLANOT-001 |
| S12 | ~~Lệnh chi riêng~~ | — | — | — | — | Consolidated → tab trong S10 | — | ARAP-003..004 |
| S13 | Proposal Stage-Gate Workspace | Stage-gate V6.0 soạn + duyệt | OPS_PLAN | Proposal, Plan | Ops | Tạo/edit proposal, advance gate, duyệt gate | S14 | PROPLN-001 |
| S14 | Campaign & Deliverable | List campaign + campaign 360 + deliverable tracking + nghiệm thu | OPS_AM / OPS_CONT | Campaign, Deliverable | Ops | Lập campaign, update deliverable, nghiệm thu, báo cáo | S4, S9, S13, P2 | CAMP-001..002 |
| S15 | Capacity & Timesheet (duyệt song song OPS/HR) | Capacity board + duyệt timesheet theo role | OPS_AM + HR_L1/L2 | Timesheet, Capacity | Ops + HR | Duyệt/từ chối timesheet, xem capacity team | S22, M3 | CAPTS-001..002 |
| S16 | Ticket Queue + Ticket 360 | Queue theo SLA tier + ticket detail + timer | OPS_CONT | Ticket | Ops | Assign, xử lý, resolve, escalate | Client 360, P4 | CSKH-001 |
| S17 | TikTok Shop Monitor | Danh sách shop, trạng thái monitoring, anomaly alerts | OPS | TikTok Shop | Ops | Xem, ack alert, drill-down anomaly | S24 | TIKTOK-001 |
| S18 | SLA Policy Rules | Cấu hình SLA per loại object + tier khách | OPS (owner) | SLA Policy | Ops | CRUD rules, xem compliance history | S16, S24 | SLANOT-001 |
| S19 | Portal Accounts (client) | Cấp/quản lý tài khoản client portal | OPS_AM | Portal Account | Ops | Cấp/tạm khóa account, reset, xem hoạt động | P1 | CPORT-001 |
| S20 | HR Records (hồ sơ + HĐLĐ + rate card tab) | Hồ sơ L1–L5, HĐLĐ 90/60/30, PII masking, rate card | HR_L1/L2 | Hồ sơ, HĐLĐ | HR | CRUD hồ sơ, gia hạn HĐLĐ, duyệt rate card (∥ FIN) | S22 | HRCORE-001..006 |
| S21 | Leave Management | Duyệt nghỉ phép phân cấp + số dư + lịch | HR_L1/L2 + nhân viên (yêu cầu) | Nghỉ phép | HR | Approve/reject, xem số dư, lịch team | M4 | HRCORE-003..004 |
| S22 | KPI & Performance | KPI 3 trụ cột, calibration, PIP 30-60-90 | HR_L2 + quản lý + BOD xem | KPI, PIP | HR | Xem aggregate, calibration, PIP checkpoint | S15, S20 | KPI-001..002 |
| S23 | Executive BI (tabs: P&L realtime / theo phòng ban) | P&L ≤5 phút + dashboard action-oriented | BOD_CEO, BOD_CFO_CTO | P&L, Dashboard | Executive | Drill-down về worklist nguồn, export | S24 | DHUB-001..005 |
| S24 | Alert Center | Escalation inbox cross-module, SLA đỏ tập trung | BOD + mọi manager (role-scoped) | Alert, Exception | Executive + mọi WS | Ack, escalate, jump về object nguồn | S6, S7, S16 | DHUB-005, SLANOT-001 |
| S25 | Audit Log Query | Tra cứu audit trail WORM toàn hệ thống | BOD (oversight) + SYS_ADMIN (vận hành) | Audit Log | Admin + Executive | Filter, export, view trail per object | S26 | RBAC-006..007 |
| S26 | RBAC Admin | Users, roles, permissions, quarterly access review | SYS_ADMIN | User, Role, Permission | Admin | Grant/revoke, review campaign, SSO/MFA config | S25 | RBAC-001..005 |
| S27 | Integration & Settings (tabs: Connections / Credentials / Tham số) | Quản lý 7 nền tảng + VAS, credentials vault, tham số DI-004, degraded mode | SYS_ADMIN + BOD_CFO_CTO (CTO duyệt) | Connection, Credential | Admin | Cấu hình, nạp credential (duyệt), enable degraded, revoke | S7 (dữ liệu manual), S9 | STGW-001..002 |
| S28 | Client 360 (shared surface) | Mọi thông tin 1 khách: deal, campaign, ticket, invoice, portal account | SALES/OPS/FIN (role views) | Khách hàng | Mọi WS (linked) | Xem related records, jump tới surface tương ứng | S1, S14, S16, S10 | CRM-001, CPORT-001 (liên kết) |

**Mobile nội bộ (SYS-MOBILE-INTERNAL, features cross-system):**

| # | Screen | Purpose | Primary role | FEAT-IDs |
|---|---|---|---|---|
| M1 | ESS Home | Alert cá nhân + quick actions (chấm công, timesheet, nghỉ phép) | Mọi nhân viên | HRCORE-005, CAPTS-001 |
| M2 | Chấm công | Check-in/out, lịch chấm của tôi | Mọi nhân viên | HRCORE-002 |
| M3 | Timesheet của tôi | Nhập + theo dõi trạng thái duyệt | Mọi nhân viên | CAPTS-001..002 |
| M4 | Nghỉ phép của tôi | Xin phép, số dư, trạng thái | Mọi nhân viên | HRCORE-003..004 |
| M5 | Hồ sơ cá nhân | Xem thông tin (PII mask) | Mọi nhân viên | HRCORE-001 |
| M6 | Duyệt nhanh (manager) | Approve/reject nghỉ phép + timesheet từ mobile | Manager (HR/OPS) `[NEEDS_REVIEW: xác nhận features có duyệt mobile]` | CAPTS-002, HRCORE-004 |

**Client Portal (SYS-PORTAL-WEB + SYS-MOBILE-PORTAL, external trust boundary, read-heavy):**

| # | Screen | Purpose | FEAT-IDs |
|---|---|---|---|
| P1 | Portal Home | Số dư ví read-only, campaign đang chạy, tickets, invoices — summary | CPORT-001 |
| P2 | Campaign theo dõi (client view) | Trạng thái campaign + deliverable đã nghiệm thu | CPORT-001, CAMP-002 |
| P3 | Billing / Invoices | Xem + nhận invoice, lịch thanh toán | CPORT-002, ARAP-001 |
| P4 | Ticket (client) | Tạo + theo dõi ticket | CPORT-001, CSKH-001 |

---

## §2.0.4 Shared Object Mapping

| Shared object | Surfaces xuất hiện | Surface DUY NHẤT giữ (role-aware) | Các nơi khác hiển thị thế nào |
|---|---|---|---|
| Khách hàng | S1, S3, S14, S16, S10, S19, P1–P4 | **S28 Client 360** (owner: CRM) | Các surface khác link/pane tới Client 360; client-facing = portal (trust boundary riêng, KHÔNG nhân bản nội bộ) |
| Handoff Package | Sales + Ops | **S4 Handoff Bridge** (2 role views: submit/nhận) | — |
| TKQC Ad Account | Ops (thao tác) + Finance (hard stop) | **S9 TKQC Registry** | Trạng thái khớp tiền hiển thị read-only trong S9; hành động khớp tiền nằm ở S7 (FIN workspace) |
| Invoice | Finance + Portal client | **S10 tab AR** (nội bộ) / **P3** (external view) | Client KHÔNG thấy dữ liệu nội bộ khác invoice của mình |
| Timesheet | Nhân viên (nhập) + OPS/HR (duyệt) | **S15** (duyệt, role-scoped) / **M3** (cá nhân) | Duyệt KHÔNG nhân bản page cho OPS và HR — 1 surface, permission filter |
| Ticket | OPS + client | **S16** (nội bộ) / **P4** (external) | Khác trust boundary → 2 surfaces hợp lệ |
| Commission | SALES (mine/team) | **S5** (role view) | — |

---

## §2.0.5 Consolidation Pass — quyết định KEEP/MERGE/DROP + lý do

| Screen | Quyết định | Lý do (ai dùng / làm gì / tần suất / quyết định gì / vì sao cần surface riêng) |
|---|---|---|
| S1, S2 | KEEP (detail = master-detail của S1, không page rời) | SALES dùng hằng ngày; quyết định advance gate tại đây; worklist là pattern mặc định |
| S3 | KEEP | Deal desk = chuỗi quote→duyệt→e-sign; Create/View/Edit/Approve chung 1 surface đa mode (R: mặc định không tách page) |
| S4 | KEEP (gộp bản SALES + bản OPS thành 1 surface 2 role views) | Cùng object, ký nhận 2 phía — tách 2 page = nhân bản; permission phân biệt nút submit/nhận |
| S5 | KEEP (1 surface, role view mine/team) | L2/L3 xem team + quota; L1 xem mine — cùng object, filter theo permission |
| S6 | KEEP | Approval inbox = worklist tài chính duy nhất; keyboard-first; tách theo loại = thêm navigation vô ích |
| S7 | KEEP | Bề mặt tiền giữ hộ đặc thù money-safety (dual approval, khóa kỳ) — không trộn vào inbox |
| S8 Hard Stop Panel | **DROP** → status field trong S9 + action trong S7 | Không có người dùng riêng: FIN khớp tiền tại S7, OPS thấy trạng thái tại S9 — panel riêng = nhảy page không cần thiết |
| S9 | KEEP | OPS thao tác vòng đời tại đây; FIN read-only theo permission (1 surface, không nhân bản cho FIN) |
| S10 | KEEP + **MERGE lệnh chi (S12) thành tab** + HĐĐT tab | Cùng FIN users, cùng dòng tiền; AR/AP/HĐĐT tabs rõ ràng, tránh 3 page gần giống |
| S11 Notification page | **DROP** → Notification = global drawer (bell) | Notification cần thấy ở MỌI surface; page riêng ép rời khỏi ngữ cảnh |
| S13 | KEEP | Stage-gate V6.0 có chế độ làm việc riêng (soạn + duyệt gate) |
| S14 | KEEP | Core vận hành; deliverable tracking cần bảng + trạng thái nghiệm thu 3 ngày |
| S15 | KEEP (1 surface, OPS ∥ HR cùng duyệt theo role) | Duyệt song song 2 phòng là THIẾT KẾ nghiệp vụ — 1 queue, permission quyết định ai thấy gì |
| S16 | KEEP | SLA timer + queue theo tier là ngữ cảnh làm việc chính của OPS_CONT |
| S17 | KEEP (lightweight) + **thêm Tab Gate-Workflow T2** (post-review F-D-01) | Monitoring chuyên biệt pull-based; gộp vào campaign sẽ sai domain (shop ≠ campaign). Vòng đời 3-Gate cần bề mặt thao tác — nhận vào S17 dạng tab, vai ký Gate 2 [NEEDS_REVIEW #8] |
| S18 | KEEP (chỉ policy rules) | Cấu hình SLA thưa (ít đổi); compliance history = read-only tab |
| S19 | KEEP (nhỏ) | Cấp portal account là tác vụ ops thật (onboarding); gộp vào Campaign sai object |
| S20 | KEEP + **MERGE rate card thành tab** | Rate card ít thay đổi + thẩm định HR∥FIN → tab là đủ |
| S21 | KEEP | Duyệt phân cấp + số dư tự động + lịch = bề mặt riêng của HR |
| S22 | KEEP | Vòng đời năm/quý + calibration ≠ CRUD hồ sơ |
| S23 | KEEP (tabs P&L realtime + dashboards phòng ban) | Ràng buộc ≤5 phút là dashboard riêng nhưng cùng bề mặt tiêu thụ BI |
| S24 | KEEP | Alert Center = escalation inbox cross-module — worklist cho CEO/manager, không phải chart |
| S25 | KEEP (1 surface: BOD oversight + admin query role views) | Cùng object audit log; khác chỉ ở scope filter — permission-aware 1 surface |
| S26 | KEEP | Quản trị RBAC là tác vụ quản trị riêng, audit review cần context |
| S27 | KEEP + **MERGE Settings thành tab** | Connections/credentials/tham số cùng lifecycle config (STGW); tách page = điều hướng thừa |
| S28 Client 360 | KEEP (shared surface mới theo §2.0.4) | Ngăn nhân bản thông tin khách trên 7 surfaces; mỗi surface link vào đây |
| M1–M5 | KEEP | ESS transactional ngắn 1 màn hình — đúng research (mobile ≠ desktop parity) |
| M6 Duyệt nhanh | KEEP `[NEEDS_REVIEW: xác nhận feature duyệt mobile trong registry]` | Manager cần duyệt không迟 tại máy — nếu features không có → DROP ở Phase 3 check 4.1 |
| P1–P4 | KEEP; Ví chi tiết = drill-down từ P1 (không page riêng) | External read-only, tối giản tuyệt đối (trust boundary); 4 surfaces đủ phủ CPORT-001/002 |

**Kết quả consolidate:** 28 proposed → **24 surfaces web nội bộ** (S8, S11, S12 drop; S28 thêm) + 6 mobile + 4 portal (+mobile portal cùng spec) ≈ **34 screen-group specs**.

**Kiểm tra ngược (bỏ screen thì workflow có hỏng không):** mỗi KEEP đều gắn 1 bước trong happy spine (§2.0.1) hoặc 1 exception path (business-context §5) — không có screen "đẹp mà thừa"; không có bước nghiệp vụ thiếu working surface.

---

## State variables set từ file này

- `$WORKFLOW_MAP` = §2.0.1 (object × stage × owner + waiting-on map)
- `$WORKSPACE_MAP` = §2.0.2 (6 workspaces: Sales, Finance, Ops, HR, Executive, Platform Admin)
- `$SCREEN_INVENTORY` = §2.0.3 + §2.0.5 (24 web + 6 mobile + 4 portal surfaces, đã consolidate)
