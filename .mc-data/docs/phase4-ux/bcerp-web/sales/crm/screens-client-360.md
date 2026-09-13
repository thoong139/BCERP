# Screen Group: Client 360 (shared surface)

Implements: FEAT-ERP-CRM-001, FEAT-ERP-CRM-005 (liên kết: FEAT-ERP-CPORT-001, FEAT-ERP-QDD-001/002, FEAT-ERP-HONB-001/002, FEAT-ERP-CAMP-001/002, FEAT-ERP-CSKH-001, FEAT-ERP-ARAP-001..007)

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `crm`
> **Tính năng:** FEAT-ERP-CRM-001 + liên kết CPORT-001
> **Route:** `/sales/clients/:id`
> **Main UI-ID:** `UI-WEB-CLIENT-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

---

## Thông Tin Common

| Trường | Giá trị |
|--------|--------|
| Workspace | Mọi workspace — hub mở bằng link từ S1, S3, S4, S14, S16, S10, S19 (không mục menu); route `/sales/clients/:id` thuộc segment `/sales/*` |
| Đối tượng nghiệp vụ | Khách hàng (client) — bản ghi tổng hợp theo vòng đời: lead/deal → handoff → campaign → ticket → invoice → portal |
| Vai trò chính | SALES_L2/L3 (góc bán), OPS_AM/OPS_CONT (góc vận hành), FIN_L1/L2 (góc tiền) — 1 surface, role view theo permission |
| Workflow stage | Sau handoff/WON: khách sống ở vòng đời vận hành; tier hiện hành đọc từ `client_tiers` (chuyển nguyên trạng tại WON — BR-SALES-501) |
| A. Object đang xử lý | 1 khách hàng: tier, hard stop khớp tiền, deal/campaign/ticket/invoice/portal đang tới đâu, đang chờ ai |
| B. Primary actors | SALES (upsell, tier), OPS (campaign, ticket, portal), FIN (invoice, ví, hard stop) — mỗi vai mở surface này vì mục đích khác nhau |
| C. Related actors | GDKD (rà quý tier), BOD (qua BI — không dùng surface này), client (thấy trên portal — trust boundary riêng) |
| D. Lifecycle | Overview → Deal → Campaign → Ticket → Invoice → Portal account → Activity: đúng trình tự vòng đời khách |
| E. Cross-module | LÀ điểm neo chống nhân bản: 7 surface có khách hàng đều link vào đây (§2.0.4 shared object mapping) |
| F. Information needs | Tier + hệ quả, hard stop status, số dư ví (FIN/OPS read), danh sách deal/campaign/ticket/invoice gần nhất, portal adoption |
| G. Decisions | Đề xuất/rà soát chuyển tier; quyết định jump sang surface nào để thao tác |
| H. Actions được phép | Đọc mọi khối theo permission; đổi tier qua luồng duyệt (SALES_L2+ POST tier-review); mọi thao tác ghi khác nằm ở surface gốc |
| I. Exceptions | Hard stop chưa khớp tiền (banner, block tạo chiến dịch), aging quá hạn, SLA ticket đỏ, portal chưa kích hoạt quá Day 14, tier lệch giữa Sales/CS |
| J. Cần chuyển màn hình? | Ngược lại — surface này SINH RA để liên kết: đọc tổng hợp tại đây, thao tác ghi jump về surface module (không nhân bản dữ liệu lẫn action) |

---

## 1. TRANG CHÍNH

### 1.1. Layout — Pattern W3 (content + side context panel 360px)

```
┌──────┬──────────────────────────────────────────────────────────────────────────────┐
│ Nav  │ [Về nguồn: My Pipeline ▾]                                                    │
│ rail ├──────────────────────────────────────────────────────────────────────────────┤
│      │ Sales > Client 360 > [Khách #KH-0214 — Công ty ABC TNHH]                    │
│      ├───────────────────────────────────────────────────────┬──────────────────────┤
│      │ Tabs vòng đời:                                        │ PANEL PHẢI 360px     │
│      │ [Overview][Deal][Campaign][Ticket]                    │ Tier hiện hành: D    │
│      │ [Invoice][Portal account][Activity]                   │ (chip + hệ quả:      │
│      ├───────────────────────────────────────────────────────│ proposal Planner     │
│      │ [Header khách: tên · MST · liên hệ · owner · nguồn]   │ 15–25tr ≤4 vòng, CQ  │
│      │ [ProgressTracker vòng đời: Lead→Quote→Handoff→Khớp    │ 15]                  │
│      │  tiền→Nghiệm thu→Invoice — click stage đã có quyền]   │ ──────────────────── │
│      ├───────────────────────────────────────────────────────│ WaitingOn:           │
│      │ ⚠ HARD STOP: chưa khớp tiền — block tạo chiến dịch    │ · chờ FIN khớp tiền  │
│      │   (banner — cần FIN_L1 khớp tại Ví & Đối soát) [Mở S7]│   · 1 ngày 3 giờ     │
│      ├───────────────────────────────────────────────────────│ ──────────────────── │
│      │ [Nội dung tab đang chọn — lazy-load, bảng tối đa      │ Timeline 3 sự kiện   │
│      │  10 dòng gần nhất + count tổng]                       │ cuối (inline)        │
│      │                                                       │ ──────────────────── │
│      │                                                       │ Object liên quan:    │
│      │                                                       │ jump: S3 S4 S14 S16  │
│      │                                                       │ S10 S19 · Lead 360   │
└──────┴───────────────────────────────────────────────────────┴──────────────────────┘
```

- Mở từ surface nào, header có nút **"Về nguồn"** (quy tắc Navigation §4.2); breadcrumb theo surface hiện hành, tối đa 3 cấp.
- **ProgressTracker vòng đời** (click stage đã có quyền xem để nhảy surface: Lead → Quote → Handoff → Khớp tiền → Nghiệm thu → Invoice) — đúng quy ước Navigation §4.5.
- Panel phải collapse được (tablet → overlay); tabs lazy-load từng tab khi chọn lần đầu.
- Mobile <768px: không phải surface mobile nghiệp vụ — render EmptyState "Mở trên web" (design-system §7).

### 1.2. Nguyên tắc hub — link out, không nhân bản

| Tab hiển thị | Dữ liệu tóm tắt tại đây | Thao tác ghi nằm ở | Nút jump |
|---|---|---|---|
| Deal | 10 quotation/deal gần nhất + count | Deal Desk (S3) | "Mở Deal Desk" |
| Campaign | Campaign + deliverable đang chạy | Campaign & Deliverable (S14) | "Mở Campaigns" |
| Ticket | Queue ticket của khách + SLA | Ticket Queue (S16) | "Mở Tickets" |
| Invoice | AR invoice + HĐĐT ( FIN permission) | Công nợ & Giải ngân (S10) | "Mở Công nợ" |
| Portal account | Trạng thái account + adoption | Portal Accounts (S19) | "Mở Portal Accounts" |
| Handoff (khối trong Overview/Deal) | Trạng thái ký nhận 2 phía | Handoff Bridge (S4) | "Mở Handoff" |

Client-facing (Số dư ví, campaign view, invoice của khách) = Client Portal (SYS-PORTAL-WEB) — trust boundary riêng, KHÔNG nhân bản nội bộ ra portal và ngược lại. Dữ liệu tài chính sensitive (giá vốn, chiết khấu, health score) chỉ theo permission vai (FIN/BOD), không xuất hiện cho vai khác.

### 1.3. Header + panel phải

- **Header:** tên khách + mã nghiệp vụ, MST, người liên hệ chính, owner (avatar), nguồn lead gốc (link Lead 360 nếu còn ở pipeline), nhãn đặc biệt (partner-referral / bod-sponsored).
- **Panel phải:** tier hiện hành + nguồn (`sales/adjusted`) + hệ quả cấu hình; WaitingOn hiện tại (chờ ai, bao lâu — ví dụ "chờ FIN khớp tiền · 1 ngày 3 giờ"); timeline 3 sự kiện cuối (inline); khối object liên quan (jump grid).
- **Banner exceptions (WarningIndicator, không dismiss):** hard stop chưa khớp tiền (`lock-money`, "Mở S7"); aging vượt hạn; tier lệch giữa Sales/CS (lỗi đồng bộ — chặn WON hoàn tất).

### 1.4. States

Loading: skeleton từng tab (tab đã mở giữ nội dung khi chuyển); Empty: EmptyState per tab ("Khách chưa có campaign" + CTA jump S14 nếu có quyền); Error: banner lỗi trong tab + retry; Permission-denied: tab ẩn hẳn (PEP), không disabled.

### 1.5. Phân quyền — role views (1 surface, permission-aware)

| Tab / khối | SALES_L2/L3 | SALES_L4/L5 | OPS_AM/CONT | FIN_L1/L2 |
|---|---|---|---|---|
| Overview (profile, tier) | ✅ | ✅ (toàn Sales) | ✅ (khách phụ trách) | ✅ (tài chính) |
| Deal | ✅ | ✅ | ✅ (sau handoff) | giá trị đã ký (feed giải ngân) |
| Campaign | ✅ | ✅ | ✅ | ❌ |
| Ticket | ✅ | ✅ | ✅ | ❌ |
| Invoice / HĐĐT | ❌ (ẩn) | ❌ | ❌ | ✅ |
| Ví / hard stop | trạng thái khớp read-only | read-only | trạng thái + cảnh báo góc ops | ✅ (sổ phụ ở S7) |
| Portal account | trạng thái | trạng thái | ✅ (cấp/thu hồi ở S19) | ❌ |
| Đề xuất/rà tier | ✅ (POST) | ✅ | ❌ (đề xuất chuyển tier trong kỳ: OPS_AM qua S28 theo FEAT-CRM-005 Phase2) | ❌ |

SYS_ADMIN/BOD không dùng surface này cho nghiệp vụ (BOD qua S23 BI). Ký handoff chỉ tại S4; khớp tiền chỉ tại S7 — tại đây chỉ hiển thị trạng thái.

---

## 2. TABS (7 tab theo vòng đời khách — R7 completeness)

| Tab | UI-ID | Mục tiêu | Nguồn dữ liệu (đề xuất) |
|---|---|---|---|
| Overview | `UI-WEB-CLIENT-001-T1` | Bức tranh vòng đời + tài chính cốt lõi | composite — xem §6 [NEEDS_REVIEW] |
| Deal | `UI-WEB-CLIENT-001-T2` | Quotation/deal của khách | API-ERP-011 |
| Campaign | `UI-WEB-CLIENT-001-T3` | Campaign + deliverable | API-ERP-049 |
| Ticket | `UI-WEB-CLIENT-001-T4` | Ticket + SLA | API-ERP-058 |
| Invoice | `UI-WEB-CLIENT-001-T5` | AR + HĐĐT + aging | API-ERP-030/037 |
| Portal account | `UI-WEB-CLIENT-001-T6` | Tài khoản portal + adoption | API-ERP-055/056 |
| Activity | `UI-WEB-CLIENT-001-T7` | Lịch sử liên module | API-ERP-005 (per lead) + activity các module |

**Global context record:** header + panel phải giữ nguyên khi chuyển tab.

### Tab 1 — Overview (`-T1`)
- **Mục tiêu:** trong 5 giây trả lời: khách này đang ở giai đoạn nào, có vấn đề tiền/tiền chưa khớp không, đang chờ ai.
- **Thông tin:** profile khách + owner + nguồn; tier + hệ quả (chip + tooltip); hard stop status (API-ERP-027 — read-only, OPS_AM/FIN); số dư ví theo currency (chỉ FIN + OPS_AM đọc góc ops — API-ERP-020; SALES không thấy); handoff status; ticket mở; aging tổng; portal adoption.
- **Actions:** jump qua ProgressTracker; "Về nguồn". **Permissions:** khối ví/tiền ẩn với SALES; hard stop banner hiện cho mọi vai có khách nhưng action "Khớp tiền" chỉ ở S7.
- **Quan hệ tab khác:** mỗi số liệu là teaser trỏ tới tab tương ứng (click → chuyển tab đã lọc).

### Tab 2 — Deal (`-T2`)
- **Mục tiêu:** nhìn vòng đời thương mại của khách (quote → ký → activation).
- **Thông tin:** bảng quotation/deal: mã, giá trị (MoneyDisplay), stage quote, gate/handoff liên quan, trạng thái "chờ kích hoạt" nếu thiếu 100% NSQC; khối Handoff tóm tắt (5 nhóm %, trạng thái ký 2 phía).
- **Actions:** jump S3 (soạn/duyệt/e-sign), jump S4 (ký handoff). Không cho soạn quote tại đây. **Permissions:** SALES thấy full; FIN thấy giá trị đã ký; OPS thấy từ handoff trở đi.

### Tab 3 — Campaign (`-T3`)
- **Mục tiêu:** đang chạy gì cho khách, nghiệm thu tới đâu.
- **Thông tin:** campaign list (status: planned/in_flight/delivered/reported) + deliverable sắp/cái nghiệm thu (window 3 ngày); nhãn degraded manual nếu feed GW lỗi.
- **Actions:** jump S14; client theo dõi ở portal (P2) — nhắc link, không nhúng. **Permissions:** OPS + SALES; FIN ❌.

### Tab 4 — Ticket (`-T4`)
- **Mục tiêu:** sức khỏe phục vụ: bao nhiêu ticket mở, SLA ra sao.
- **Thông tin:** queue ticket của khách: status, priority, assignee, SLA state (warning/breach nổi đầu); count theo trạng thái.
- **Actions:** jump S16 để xử lý/assign. **Permissions:** OPS + SALES (read); FIN ❌.

### Tab 5 — Invoice (`-T5`)
- **Mục tiêu:** bức tranh công nợ + chứng từ của khách (góc FIN).
- **Thông tin:** AR invoice list: giá trị (MoneyDisplay), aging bucket 30/60/90, paid_status, dunning log count; HĐĐT trạng thái phát hành; tổng dư nợ.
- **Actions:** jump S10 (ghi nhận thanh toán, dunning, phát hành HĐĐT — KHÔNG thao tác tại đây). **Permissions:** chỉ FIN; tab ẩn với vai khác.

### Tab 6 — Portal account (`-T6`)
- **Mục tiêu:** khách đã được cấp portal chưa, dùng thế nào (Gate Day 14).
- **Thông tin:** trạng thái account (đã cấp/khóa/thu hồi), số user, adoption usage (login, ticket tạo, invoice xem — API-ERP-056).
- **Actions:** jump S19 (cấp/thu hồi/reset). **Permissions:** OPS_AM thao tác; SALES/L4/L5 + FIN read trạng thái.

### Tab 7 — Activity (`-T7`)
- **Mục tiêu:** dòng thời gian hợp nhất liên module của khách.
- **Thông tin:** ActivityFeed full: từ lead (API-ERP-005), gate chữ ký, handoff ack, campaign transition, ticket, invoice issued — mỗi entry avatar + hành động + thời gian tuyệt đối + link object nguồn; lọc theo module.
- **Actions:** chỉ đọc; click entry jump surface nguồn. **Permissions:** entry theo permission từng module (entry Fin không hiện với SALES).

---

## 3. DIALOGS

| # | Dialog | UI-ID | Loại | Mở khi nào |
|---|--------|-------|------|-----------|
| 1 | Rà soát / đề xuất chuyển tier | `UI-WEB-CLIENT-001-D1` | Form + đối chiếu cũ/mới | Panel phải → "Rà soát tier" |
| 2 | Ghi chú liên hệ khách | `UI-WEB-CLIENT-001-D2` | Form ngắn | Header → "+ Ghi chú" |

- **`-D1` Chuyển tier:** tự điền 3 căn cứ đọc từ hệ thống (doanh thu thực tế, số TKQC active — API-ERP-044 filter customer_id, health score hoặc "chưa có dữ liệu" `[KXN-9]`); đối chiếu tier cũ/mới + hệ quả đổi (template, SLA, vòng sửa, CQ); gửi vào luồng: đề xuất → SM + AM Lead đồng thuận → GDKD duyệt SLA 3 ngày (machine-state: DRAFT/PROPOSED/CO_SIGNED/APPROVED/EFFECTIVE/REJECTED/EXPIRED hiển thị trong dialog sau khi gửi). Nút lưu vô hiệu khi thiếu căn cứ. `[NEEDS_REVIEW]` API-ERP-009 POST khai `SALES_L2+` trong khi FEAT-ERP-CRM-005 quy trình là OPS_AM đề xuất + đồng thuận 2 phía + GDKD duyệt — contract hiện là "xem/sửa tier rà soát quý"; luồng đa bước cần xác nhận contract khi triển khai Phase2.
- **`-D2` Ghi chú:** tạo activity note gắn khách `[NEEDS_REVIEW: chưa có endpoint POST activity cấp khách — chỉ có GET activity per lead (API-ERP-005)]`.

## 4. SHEETS

| # | Sheet | UI-ID | Nội dung | Mở khi nào |
|---|-------|-------|----------|-----------|
| 1 | Đối chiếu hard stop + ví | `UI-WEB-CLIENT-001-S1` | Trạng thái khớp tiền 3 số (portal vs bank vs ledger — tóm tắt matched/mismatch), lịch hard stop, link "Mở Ví & Đối soát (S7)" | Click banner hard stop / khối ví trong Overview |

Ưu tiên sheet vì đối chiếu cần đọc ngay cạnh banner mà không rời tab đang mở; chỉ read-only — mọi lệnh tiền tại S7 (money-safety surface riêng).

## 5. VIEW MODES

| Mode | UI-ID | Nội dung | Ai thấy |
|---|---|---|---|
| Role view SALES (mặc định theo vai) | `UI-WEB-CLIENT-001-M1` | Tabs Overview/Deal/Campaign/Ticket; tài chính chỉ trạng thái khớp | SALES_L1–L5 |
| Role view OPS | `UI-WEB-CLIENT-001-M2` | Overview/Campaign/Ticket/Portal + handoff | OPS_AM/CONT/PLAN |
| Role view FIN | `UI-WEB-CLIENT-001-M3` | Overview (tiền)/Invoice/Ví/HĐĐT | FIN_L1/L2 |

Role view KHÔNG phải 3 page — cùng route, tab set + khối dữ liệu render theo permission (PEP ẩn tab). Create không có tại đây (khách sinh từ lead WON/handoff — không tạo tay khách trống); Edit dữ liệu khách ở surface sở hữu; Review tier = dialog `-D1` trong cùng surface.

## 6. API ENDPOINTS

| # | Endpoint | Phương thức | Gắn với | Tham số chính |
|---|----------|------------|---------|---------------|
| 1 | `/api/v1/erp/customers/{id}/tier-review` | GET (API-ERP-009) | Panel phải (tier + hệ quả) + Dialog `-D1` | GET: SALES |
| 2 | `/api/v1/erp/customers/{id}/tier-review` | POST (API-ERP-009) | Dialog `-D1` gửi đề xuất | SALES_L2+ |
| 3 | `/api/v1/erp/quotations` | GET (API-ERP-011) | Tab Deal | filter `status,tier,owner_id,period` |
| 4 | `/api/v1/erp/campaigns` | GET (API-ERP-049) | Tab Campaign | filter `status,customer_id,owner_id` |
| 5 | `/api/v1/erp/tickets` | GET (API-ERP-058) | Tab Ticket | filter `status,tier,priority,assignee_id,sla_state` |
| 6 | `/api/v1/erp/ar-invoices` | GET (API-ERP-030) | Tab Invoice | filter `aging_bucket,paid_status,customer_id,period` |
| 7 | `/api/v1/erp/einvoices` | GET (API-ERP-037) | Tab Invoice (HĐĐT) | filter `status,period,customer_id` |
| 8 | `/api/v1/erp/wallets` | GET (API-ERP-020) | Overview/S1 — số dư per currency | FIN + OPS_AM read |
| 9 | `/api/v1/erp/wallets/{customerId}/hard-stop-status` | GET (API-ERP-027) | Banner hard stop + Sheet `-S1` | read-only |
| 10 | `/api/v1/erp/handoffs` | GET (API-ERP-016) | Tab Deal — khối handoff | filter `status,customer_id,owner_id` |
| 11 | `/api/v1/erp/ad-accounts` | GET (API-ERP-044) | Dialog `-D1` (số TKQC active) | filter `platform,status,customer_id,tier,search` |
| 12 | `/api/v1/erp/portal-accounts/{customerId}/usage` | GET (API-ERP-056) | Tab Portal account | OPS_AM |
| 13 | `/api/v1/erp/leads/{id}/activity` | GET (API-ERP-005) | Tab Activity (phần lead) | per lead id |

`[NEEDS_REVIEW]` Thiếu 3 điểm contract cho hub: (1) **GET tổng hợp khách** — không có endpoint `GET /api/v1/erp/customers/{id}`/overview; Overview ghép từ nhiều list theo filter `customer_id` (nhiều round-trip) hoặc cần endpoint composite; (2) **filter `customer_id`** chưa có trên `GET /quotations` (API-ERP-011) và `GET /tickets` (API-ERP-058) — tab Deal/Ticket cần; (3) **POST activity cấp khách** cho Dialog `-D2` (chỉ có GET per lead).

## 7. UI-ID Registry

| UI-ID | Loại | Tên | Ghi chú |
|-------|------|-----|---------|
| `UI-WEB-CLIENT-001` | detail (hub) | Client 360 — shared surface | Route `/sales/clients/:id`; pattern W3; mở bằng link từ mọi surface có khách |
| `UI-WEB-CLIENT-001-T1` | tab | Overview (vòng đời + tài chính cốt lõi) | mặc định |
| `UI-WEB-CLIENT-001-T2` | tab | Deal (quote/deal + handoff) | lazy |
| `UI-WEB-CLIENT-001-T3` | tab | Campaign (+deliverable, nghiệm thu) | lazy |
| `UI-WEB-CLIENT-001-T4` | tab | Ticket (queue + SLA) | lazy |
| `UI-WEB-CLIENT-001-T5` | tab | Invoice (AR + HĐĐT + aging) | lazy; FIN only |
| `UI-WEB-CLIENT-001-T6` | tab | Portal account (+adoption) | lazy |
| `UI-WEB-CLIENT-001-T7` | tab | Activity (timeline liên module) | lazy |
| `UI-WEB-CLIENT-001-D1` | dialog | Rà soát / đề xuất chuyển tier | API-ERP-009 |
| `UI-WEB-CLIENT-001-D2` | dialog | Ghi chú liên hệ khách | `[NEEDS_REVIEW]` endpoint |
| `UI-WEB-CLIENT-001-S1` | sheet | Đối chiếu hard stop + ví (read-only) | API-ERP-020/027 |
| `UI-WEB-CLIENT-001-M1` | mode | Role view SALES | theo permission |
| `UI-WEB-CLIENT-001-M2` | mode | Role view OPS | theo permission |
| `UI-WEB-CLIENT-001-M3` | mode | Role view FIN | theo permission |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../../phase2-features` | Upstream |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system | `../../../design-system.md` | Upstream |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | Upstream |
