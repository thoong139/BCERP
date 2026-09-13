# Screen Group: Handoff Bridge (shared SALES↔OPS)

Implements: FEAT-ERP-HONB-001, FEAT-ERP-HONB-002

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `honb` (MOD-HANDOFF-ONBOARD)
> **Tính năng:** FEAT-ERP-HONB-001 (góc Sales — REQ-SALES-008) + FEAT-ERP-HONB-002 (góc OPS — REQ-OPS-004)
> **Route:** `/ops/handoff`
> **Main UI-ID:** `UI-WEB-HONB-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Main UI-ID | `UI-WEB-HONB-001` |
| Route | `/ops/handoff` — menu entry ở CẢ Sales Workspace + Ops Workspace, badge `{handoff_cho_ack}` (Sales) / `{handoff_cho_ky}` (Ops) |
| Loại | Worklist + Detail pane (split view W2 — 1 surface, 2 role views) |
| Workspace | Sales + Ops (shared surface theo §2.0.4 — không nhân bản 2 page) |
| Đối tượng nghiệp vụ | Handoff Package (5 nhóm checklist) + Onboarding tasks sinh sau ký nhận |
| Vai trò chính | SALES_L1–L2 (soạn + submit) · SALES_L3/SM (ký Gate 2) · OPS_AM (nhận + ký xác nhận SLA 4h) |
| Vai trò liên quan | SALES_L4/L5 (giám sát), OPS_PLAN (capacity), OPS_ADS (TKQC), OPS_CONT/DES/EDIT (hạng mục), SYS_ADMIN |
| Workflow stage | `draft → sales_submit → ops_ack (ký 2 phía) → onboarding_tasks → completed` — map machine-state feature spec: PREPARING → SUBMITTED → PENDING_AM_CONFIRM → ACCEPTED → ONBOARDING (Day 1/7/14/30) → STABILIZED; nhánh `RETURNED` |

**Checklist ngữ cảnh (BƯỚC 0):** (A) Object = Handoff Package của 1 deal, chốt bàn giao Sales → OPS tại Gate 2/QUALIFIED. (B) Primary actors: NVKD submit, SM ký, OPS_AM xác nhận SLA 4h. (C) Related: OPS_PLAN capacity, OPS_ADS/OPS_CONT task, FIN chỉ đọc D+0. (D) Stages theo $WORKFLOW_MAP — từ lúc AM xác nhận, đồng hồ onboarding bắt đầu. (E) Cross-module: S3 (deal nguồn), S9 TKQC, S19 Portal Accounts, S14 Campaign, S15 Capacity. (F) Thông tin: % checklist, signature timeline, task owner + trạng thái, milestone Day 1/7/14/30. (G) Quyết định: submit / ký / xác nhận-từ chối / xác nhận capacity. (H) Actions: soạn, submit, ký, ack/reject, đánh giá task + mốc, quay thiếu sót về SM. (I) Exceptions: <100%, capacity = 0, SLA 4h quá → escalate TL 8h HR_L2, mốc Day 14 GATE trượt, D+0 chưa kích hoạt, D+5 lùi. (J) 1 surface chung — KHÔNG tách page theo role.

---

## 1. TRANG CHÍNH

### 1.1. Layout — split view W2 (danh sách 40% trái + detail 60% phải, chọn hàng không rời trang)

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│ Breadcrumb: Ops > Handoff Bridge            Role view: [OPS_AM]        [+ Tạo pkg] │
├──────────────────────────────┬─────────────────────────────────────────────────────┤
│ [Tìm nhanh — deal/KH……]      │ HONB-2026-0147 · Deal D-8891 · CT TNHH ABC  [→C360] │
│ (Chờ tôi ·3)(Chờ AM ·2)(SLA  │ StatusBadge: [Chờ AM xác nhận]  SLA 4h: ⏱ còn 2h15p │
│  đỏ ·1)(Trả về ·1) [Bộ lọc▾] │ WaitingOn: [avatar] Nguyễn V. (OPS_AM) — chờ 1h45p  │
│ ──────────────────────────── │ ── SIGNATURE TIMELINE (ai gửi / ai nhận / lúc nào) ─│
│ ▸ HONB-0147 · ABC            │  ● NVKD Trần A. — đã gửi      12/09 16:02 (web)     │
│   Chờ AM xác nhận · SLA 2h15p│  ● SM Lê B. — đã ký Gate 2    12/09 16:40           │
│ ▸ HONB-0146 · XYZ            │  ○ OPS_AM Nguyễn V. — CHỜ XÁC NHẬN ≤4h ⏱            │
│   Chờ SM ký · submitted 3h   │ ── Tabs ─────────────────────────────────────────── │
│ ▸ HONB-0145 · DEF            │ [Bàn giao] [Onboarding Tasks ·8] [Deploy & Lịch sử] │
│   Nháp · checklist 72% ⚠     │ Checklist 5 nhóm — 100% ▓▓▓▓▓▓▓▓▓▓                  │
│ ▸ HONB-0144 · GHI            │ (1)Hồ sơ KH ✓ (2)Tài chính ✓ (3)Kỳ vọng ✓           │
│   Bị trả về · lý do: thiếu   │ (4)Nội bộ ✓ (5)Pháp lý ✓   Capacity: OPS_PLAN ✓ 2   │
│   quyền pixel (vòng 1)       │ ┌─ ⚠ WarningIndicator ─────────────────────────────┐│
│ …                            │ │ Capacity trống = 0 — OPS_PLAN + GDKD xác nhận    ││
│                              │ │ trước khi ký. Hạn: trước submit Gate 2. [Xem]    ││
│ Phân trang ← 1 2 3 → 20/50/100│ └─────────────────────────────────────────────────┘│
│                              │ [Ký nhận tiếp nhận] (OPS_AM)  [Từ chối]  [⋯]        │
└──────────────────────────────┴─────────────────────────────────────────────────────┘
```

Chi tiết package không rời worklist — OPS vừa duyệt queue vừa xử lý; trên mobile <768px list → card, detail mở full-width, bảng task không render (báo "xem trên web").

### 1.2. Components

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| DataTable compact | sticky header, cột SLA right-align, sort click header | Pattern W1 cho nửa trái |
| Quick filter chips | tháo được từng chip; mặc định theo role: Sales = "Chờ tôi" · "Trả về"; OPS = "Chờ tôi" · "SLA đỏ" | Chip "SLA đỏ" = `--state-sla-breach`, tự nhảy đầu danh sách |
| WaitingOnIndicator | chip trong row + khối trong header detail | Ràng buộc số 1: OPS chờ SALES submit / SALES chờ OPS_AM xác nhận — luôn "đang chờ ai, chờ bao lâu" |
| ProgressTracker stepper ngang | 5 stage: draft → sales_submit → ops_ack → onboarding_tasks → completed | Node hiển thị người giữ + số ngày chờ; stage có quyền xem → click |
| Signature timeline | vertical, avatar + vai + timestamp tuyệt đối (dd/MM HH:mm) + kênh; icon `signature` | Yêu cầu lõi: rõ ai gửi, ai nhận, đã ký lúc nào; ghi audit trail (BR-HONB-103) |
| StatusBadge | 1 badge/hàng; SLA quá gắn màu `--state-sla-breach` + icon chuông | Token §1 design-system |
| WarningIndicator banner | capacity = 0; SLA 4h quá hạn; checklist <100% | Nội dung bắt buộc 3 phần: chuyện gì — ai làm gì — hạn còn lại; SLA quá hạn không dismiss |
| Tabs | page tabs trong detail pane, count-tab cho Onboarding Tasks | T2/T3 lazy-load |

### 1.3. Cột danh sách (nửa trái)

| Tên | Trường | Định dạng | Sắp xếp | Rộng |
|-----|--------|----------|---------|------|
| Package / Deal | `handoff_package.id` + `deal_id` | Mã nghiệp vụ + link | Có | auto |
| Khách hàng | `customer.name` | Text, link Client 360 | Có | 160px |
| Trạng thái | `handoff_package.status` | Badge (bảng màu dưới) | Có | 140px |
| Checklist | `completion_pct` | % + mini progress bar | Có | 90px |
| Đang chờ | WaitingOn (role + duration) | Chip `WaitingOnIndicator` | Không | 180px |
| SLA ack 4h | `am_sla_deadline` | Countdown / "—" khi chưa tới lượt | Có (mặc định: breach đầu) | 110px |
| Owner | `owner_id` / AM nhận | Avatar + tên | Không | 120px |

**Badge màu:** Nháp `--state-draft` · Chờ SM ký `--state-info` · Chờ AM xác nhận `--state-pending` (SLA quá → `--state-sla-breach`) · Bị trả về `--state-rejected` · Đang onboarding `--state-info` · Hoàn tất `--state-approved`.

**Trạng thái hệ thống:** loading = skeleton 10 hàng (list) / skeleton pane (detail); empty = EmptyState theo role — Sales: "Chưa có package nào trong phạm vi" + CTA tạo từ deal WON; OPS: "Không có package chờ ký nhận"; error = hàng lỗi + retry. Không có state cục bộ — mọi state render từ machine-state do CORE trả về.

### 1.4. Hành động chính

| Sự kiện | Hành động | Kết quả |
|---------|---------|--------|
| Chọn hàng trái | Mở detail pane | Header context giữ nguyên khi chuyển tab |
| Nhấn "Trình Gate 2" (Sales, PREPARING) | Dialog D1 | Chỉ bấm được khi checklist 100% + capacity ≠ 0 — UI vô hiệu nút khi chặn (BR-HONB-102/106) |
| Nhấn "Ký Gate 2" (SM) | Gọi gate-decision Gate 2 | SUBMITTED → PENDING_AM_CONFIRM, bắt đầu đếm SLA 4h |
| Nhấn "Ký nhận tiếp nhận" (OPS_AM, PENDING_AM_CONFIRM) | Dialog D2 | ops_ack → sinh onboarding tasks + tự sinh dự án; đồng hồ onboarding bắt đầu |
| Nhấn "Từ chối" (OPS_AM) | Dialog D2 (tab từ chối) | RETURNED + credit hoa hồng tạm dừng + lý do gắn đúng mục checklist |
| Click mục checklist thiếu | Dialog D4 (Sales soạn) | Cập nhật responsible/due date; liệt kê đúng mục thiếu + nhóm + responsible |
| Click WaitingOn chip | Dialog D5 | Nhắc/nhắn người đang giữ |
| Đánh giá task/mốc (T2) | Sheet S1/S2 | PATCH trạng thái task; mốc fail → kế hoạch khắc phục owner + deadline |

Bulk actions: **không có bulk ký nhận** — mỗi lần ký là sự kiện audit trail riêng (thời gian, người ký, kênh). Bulk chỉ cho chọn + mở lần lượt.

### 1.5. Phân Quyền (hide khi không có quyền — PEP)

| Thành phần | SALES_L1–L2 | SALES_L3 (SM) | SALES_L4/L5 | OPS_AM | OPS_PLAN | OPS_ADS | OPS_CONT/DES/EDIT | SYS_ADMIN |
|-----------|----|----|----|----|----|----|----|----|
| Xem package | mình | nhóm | phòng / toàn bộ | queue + dự án mình | queue + dự án mình | dự án mình | dự án mình | toàn bộ |
| Soạn/sửa checklist (deal mình) | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (qua quy trình có log) |
| Trình Gate 2 (submit) | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Ký Gate 2 / Thu hồi | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Ký nhận / Từ chối (ops-ack) | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Xác nhận capacity (gắn Gate 2) | ❌ | ❌ | xem | ❌ | ✅ | ❌ | ❌ | ❌ |
| Đánh giá mốc Day 1/7/14/30 | xem (deal mình) | xem | xem | ✅ | xem | hạng mục phụ trách | hạng mục phụ trách | ❌ |
| PATCH onboarding task | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ (TKQC/tài nguyên) | ✅ (hạng mục mình) | ❌ |
| Cấu hình template checklist / SLA | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (có phê duyệt) |

FIN không thao tác trên surface này: hard stop / khớp tiền nằm ở S7; FIN_L1 confirm D+0 chỉ hiển thị machine-state read-only trong T3.

---

## 2. TABS

Global context (header package + signature timeline + WaitingOn) giữ nguyên khi chuyển tab. T1 tải cùng detail; T2/T3 lazy-load on-demand (performance).

### Tab T1 — Bàn giao (checklist 5 nhóm) `UI-WEB-HONB-001-T1`
- **Mục tiêu:** thấy chính xác % hoàn thiện và mục nào thiếu (nhóm nào, responsible ai, due khi nào) trước khi trình Gate 2 (BR-HONB-101/102).
- **Thông tin:** 5 nhóm bắt buộc gập/mở — (1) Hồ sơ KH; (2) Tài chính; (3) Kỳ vọng & Scope; (4) Nội bộ (phân bổ AM + xác nhận Capacity); (5) Pháp lý & Rủi ro. Mỗi mục: tên, responsible (avatar), due date, trạng thái. Tổng % + progress bar. Khối Capacity: giá trị GET capacity (vàng 90% / đỏ 100%) + trạng thái xác nhận của OPS_PLAN; = 0 → WarningIndicator chặn submit, cảnh báo GDKD + OPS_PLAN (BR-HONB-106).
- **Components:** Accordion nhóm, DataTable item, AssigneePicker (chỉnh responsible — lọc theo data-scope RBAC), ApprovalCard rút gọn khối capacity.
- **Actions:** Sales L1–L2 sửa mục (D4); SM thấy nút "Ký Gate 2"; OPS_AM thấy nút "Ký nhận/Từ chối" khi PENDING_AM_CONFIRM. Bị chặn <100%: banner liệt kê mục thiếu, nút submit vô hiệu + tooltip lý do.
- **States:** loading skeleton nhóm; empty "Template 5 nhóm chưa khởi tạo" (chỉ khi lỗi khởi tạo); error retry. Permission: item read-only cho mọi role trừ Sales L1–L2 (deal mình) khi PREPARING/RETURNED.
- **Quan hệ tab khác:** thiếu sót sau ops_ack quay về gắn đúng mục tại đây (defect_return), xem chi tiết ở T3 audit.

### Tab T2 — Onboarding Tasks `UI-WEB-HONB-001-T2`
- **Mục tiêu:** theo dõi checklist task sinh ra sau ops_ack theo Day 1/7/14/30 — mỗi task có owner + trạng thái (BR-HONB-204).
- **Thông tin:** dải milestone Day 1 → 7 → 14 (GATE portal) → 30 với tiêu chí đạt + pass/fail; bảng task nhóm theo nguồn: **ADACC** (đăng ký & map TKQC vào registry — owner OPS_ADS), **CPORT** (tạo CLIENT_ADMIN + gửi invite — owner OPS_AM), **CAMP** (lập campaign + deliverable plan — owner OPS_AM/OPS_PLAN); cột: task · nguồn · owner · due · trạng thái (Chờ/Đang làm/Hoàn tất/Trượt) · link surface (S9/S19/S14). Khu portal read-only: CLIENT_ADMIN, số user kích hoạt, ≥1 login/tuần — đọc từ CORE, Sales không có nút thao tác (BR-HONB-109).
- **Components:** DataTable + StatusBadge, ProgressTracker milestone, AssigneePicker (chuyển giao khi nghỉ — OPS_PLAN/SM duyệt), Timeline inline.
- **Actions:** PATCH trạng thái task (S1); đánh giá mốc (S2); mốc Day 14 FAIL → escalate CS TL trong 24h + kế hoạch khắc phục owner + deadline; thiếu sót Day 1–30 quay về SM gắn đúng mục package (BR-HONB-207).
- **States:** lazy-load riêng; empty = "Chưa có task — sinh sau khi OPS_AM ký nhận" (tab disabled kèm tooltip trước ops_ack); error retry từng khối.
- **Quan hệ:** task ADACC deep-link S9; CPORT deep-link S19; CAMP deep-link S14; portal usage gọi on-demand khi mở mốc Day 14.

### Tab T3 — Deploy & Lịch sử `UI-WEB-HONB-001-T3`
- **Mục tiêu:** thấy machine-state deploy D+0→D+5 và toàn bộ lịch sử ký nhận / trả về — bằng chứng tranh chấp (BR-HONB-104).
- **Thông tin:** timeline D+0 → Planning (TT→ĐH→AD trong ngày D+0) → Kick-off nội bộ D+1/D+2 → Kick-off KH D+3 (ký 6 Communication Rules — Rules 1/2/3/5 gắn nhãn "dự thảo nội bộ — chờ khách xác nhận" `[KXN-11]`) → ONGOING D+5 (lùi + lý do nếu thiếu tài nguyên trước D+4). Điều kiện D+0 dạng 3 ô điều kiện machine-state: tiền vào TK + FIN_L1 confirm ≤4h + LOI/HĐ ký; HĐ chậm 3 ngày sau D+0 → cảnh báo `hasContractWarning`. Audit trail đầy đủ: mọi chuyển trạng thái, signature event, lần trả về (vòng cũ giữ nguyên, vòng ký mới khi submit lại).
- **Components:** Timeline full, StatusBadge từng event, ActivityFeed (avatar + hành động + thời gian tuyệt đối), EmptyState.
- **Actions:** xem chi tiết signature event (S3); không có thao tác ghi tại tab này ngoài theo dõi.
- **States:** lazy-load; empty khi chưa tới ONBOARDING ("Deploy timeline hiển thị sau khi dự án được sinh"); error retry.
- **Quan hệ:** điều kiện tiền / khớp tiền xem tại S7 (link); HĐ đầy đủ liên quan S3 Deal Desk.

---

## 3. DIALOGS

| # | Dialog | UI-ID | Loại | Mở khi nào |
|---|--------|-------|------|-----------|
| 1 | Xác nhận Trình Gate 2 | `UI-WEB-HONB-001-D1` | Confirm | Sales nhấn "Trình Gate 2" |
| 2 | Ký nhận / Từ chối tiếp nhận | `UI-WEB-HONB-001-D2` | ApprovalCard | OPS_AM nhấn hành động chính |
| 3 | Thu hồi / Trả về | `UI-WEB-HONB-001-D3` | Confirm + lý do | SM thu hồi package đã ký |
| 4 | Cập nhật mục checklist | `UI-WEB-HONB-001-D4` | Form | Sales sửa responsible/due date mục thiếu |
| 5 | Nhắc người đang chờ | `UI-WEB-HONB-001-D5` | Modal nhắn | Click WaitingOnIndicator |

### 3.1. D1 — Xác nhận Trình Gate 2 (Sales)
Tóm tắt: % checklist, số mục thiếu (nếu có — khi vậy nút chính vô hiệu), trạng thái capacity check, deal + giá trị `MoneyDisplay`. Xác nhận → `POST /api/v1/erp/handoffs/{id}/sales-submit`. Nút vô hiệu khi <100% hoặc capacity = 0 — hiển thị rõ 2 điều kiện chặn nào còn thiếu (SC-001/SC-004).

### 3.2. D2 — Ký nhận / Từ chối tiếp nhận (OPS_AM, ApprovalCard)
Chứa bắt buộc: tóm tắt package + link, SLA còn lại (countdown 4h), 2 nút **Ký nhận** (primary) / **Từ chối** (outline `--color-error`). Từ chối: lý do ≥10 ký tự + chọn mục checklist thiếu (multi-select từ T1) → RETURNED, credit hoa hồng tạm dừng hiển thị trên deal. Processing: spinner + khóa nút chống double-submit. Sau ack → toast + panel tự chuyển sang T2 với task mới sinh + event `handoff.ops_ack`.

### 3.3. D3 — Thu hồi / Trả về (SM)
Lý do bắt buộc ≥10 ký tự; xác nhận → RETURNED, giữ lịch sử vòng. Sales thấy banner "đã trả về + lý do" trên package.

### 3.4. D4 — Cập nhật mục checklist (Sales, PREPARING/RETURNED)
Fields: tên mục (read-only), responsible (AssigneePicker — gợi ý đúng nhóm 1–5), due date (date, phải ≥ hôm nay), ghi chú. Lưu → cập nhật % + re-render banner thiếu. `[KXN-7]` nhóm (1) giữ cấu trúc mở cho Strategic Brief.

### 3.5. D5 — Nhắc người đang chờ
Người nhận (từ WaitingOn), tin nhắn nhanh, gửi qua kênh notification hệ thống (SLANOT — global drawer/bell); lịch sử nhắc ghi vào activity feed. Không có endpoint riêng trong hợp đồng HONB — dùng hạ tầng notification chung.

---

## 4. SHEETS

| # | Sheet | UI-ID | Vị trí | Mở khi nào |
|---|-------|-------|--------|-----------|
| 1 | Chi tiết onboarding task | `UI-WEB-HONB-001-S1` | Right 480px | Click 1 task ở T2 |
| 2 | Đánh giá mốc / kế hoạch khắc phục | `UI-WEB-HONB-001-S2` | Right 720px | Click 1 mốc Day 1/7/14/30 ở T2 |
| 3 | Audit chữ ký (signature event) | `UI-WEB-HONB-001-S3` | Right 480px | Click 1 bước signature timeline |

### 4.1. S1 — Chi tiết onboarding task
Header: tên task + nguồn (ADACC/CPORT/CAMP) + StatusBadge. Nội dung: owner (avatar + phòng), due date, tiêu chí đạt, evidence (`evidence_url`), trạng thái cập nhật; footer sticky: [Cập nhật trạng thái] (PATCH API-ERP-019 — theo phân quyền bảng 1.5), [Mở surface nguồn] (S9/S19/S14). Contextual — giữ detail pane phía sau.

### 4.2. S2 — Đánh giá mốc / kế hoạch khắc phục
`criteria_json` hiển thị checklist tiêu chí từng mốc (Day 1: map 100% TKQC + CLIENT_ADMIN; Day 7: ≥1 conversion test + ≥80% portal + 2FA 100%; Day 14 GATE: ≥1 login/tuần từ ≥2 user; Day 30: review 30 ngày vs baseline). OPS_AM đánh giá PASS/FAIL + evidence; FAIL → form kế hoạch khắc phục: owner_fix (AssigneePicker) + fix_deadline; Day 14 FAIL tự động entry escalate CS TL 24h. Portal usage hiển thị read-only ngay trong sheet khi đang ở mốc Day 7/14.

### 4.3. S3 — Audit chữ ký (signature event)
Mỗi event: người ký (avatar + vai), hành động (gửi / ký Gate 2 / xác nhận tiếp nhận / từ chối), thời gian tuyệt đối + kênh (web/mobile), tham chiếu audit trail WORM (link S25 khi có quyền oversight). Đối chiếu 2 chiều vòng ký hiện tại vs vòng cũ (khi RETURNED → submit lại).

---

## 5. VIEW MODES

1 surface — 2 role views theo role đăng nhập (không tách page, §2.0.5); Create/View/Edit là MODES của cùng detail pane.

| Mode | UI-ID | Hiện khi nào | Khác biệt |
|------|-------|--------------|-----------|
| Sales view (submit) | `UI-WEB-HONB-001-M1` | Role SALES | Nhấn mạnh: checklist % + mục thiếu + capacity check; nút Soạn/Trình Gate 2 (L1–L2), Ký Gate 2 (SM); WaitingOn "chờ OPS_AM xác nhận" khi PENDING_AM_CONFIRM |
| OPS view (nhận + ký) | `UI-WEB-HONB-001-M2` | Role OPS | Nhấn mạnh: queue theo SLA 4h + ApprovalCard ký nhận; WaitingOn "chờ NVKD submit" khi PREPARING; sau ack nổi bật T2 onboarding tasks |
| Read-only viewer | — (không phải mode riêng) | SALES_L4/L5, OPS_CONT xem | Toàn bộ action ẩn (PEP), chỉ thấy machine-state + milestone |

---

## 6. API ENDPOINTS

> Endpoint thật từ `api-contract.md` §6.1 (MOD-HANDOFF-ONBOARD + liên quan). WEB gọi API core, render machine-state — không lưu state cục bộ.

| Khi nào | Method | Endpoint | Tham số / Ghi chú |
|---------|--------|----------|-------------------|
| Tải worklist | GET | `/api/v1/erp/handoffs` | filter `status,customer_id,owner_id` + `page,limit` (20/50/100, server-side); scope theo permission |
| Mở detail pane | GET | `/api/v1/erp/handoffs/{id}` | Trả detail + onboarding tasks (T1/T2); T3 lazy-load trên cùng payload |
| Tạo draft (manual, Sales) | POST | `/api/v1/erp/handoffs` | Khởi tạo 5 nhóm bắt buộc; auto-create từ event `deal.signed` — CTA chỉ khi chưa có |
| Trình Gate 2 (D1) | POST | `/api/v1/erp/handoffs/{id}/sales-submit` | draft→sales_submit; CORE chặn thiếu 5 nhóm |
| SM ký Gate 2 | POST | `/api/v1/erp/leads/{id}/gate-decision` | Body `{gate:2, decision:"go", note}` — Gate 2 gắn chữ ký handoff (API-ERP-008) |
| OPS_AM ký nhận (D2) | POST | `/api/v1/erp/handoffs/{id}/ops-ack` | ops_ack → sinh onboarding tasks + tự sinh dự án; event `handoff.ops_ack` (API-ERP-018) |
| Đọc / cập nhật task (S1) | GET/PATCH | `/api/v1/erp/handoffs/{id}/onboarding-tasks[/{taskId}]` | Checklist Day 1/7/14/30 cho ADACC/PORTAL/CAMP; PATCH trạng thái |
| Capacity check (T1) | GET | `/api/v1/erp/capacity` | Theo nhân sự/đội: vàng 90%, đỏ 100% (API-ERP-069) |
| Portal usage (mốc Day 14, on-demand) | GET | `/api/v1/erp/portal-accounts/{customerId}/usage` | Monitor adoption GATE Day 14 (API-ERP-056) |
| Task ADACC → thao tác tại S9 | POST/POST | `/api/v1/erp/ad-accounts`, `/api/v1/erp/ad-accounts/{id}/transitions` | Deep-link, không thao tác tại đây |
| Task CPORT → thao tác tại S19 | POST/DELETE | `/api/v1/erp/portal-accounts` | Deep-link cấp/thu hồi account |
| Task CAMP → thao tác tại S14 | POST/GET | `/api/v1/erp/campaigns` | CRUD campaign gắn handoff + TKQC |

**[NEEDS_REVIEW] các điểm thiếu endpoint:**
- `[NEEDS_REVIEW: thiếu endpoint PATCH checklist item (responsible, due_date) khi soạn package — hiện chỉ có POST tạo draft API-ERP-015; D4 cần nó]`
- `[NEEDS_REVIEW: thiếu endpoint riêng cho từ chối tiếp nhận / SM thu hồi (luồng RETURNED) — API-ERP-018 chỉ mô tả ops-ack ký nhận; D2 (tab từ chối) và D3 cần nó]`
- `[NEEDS_REVIEW: thiếu endpoint deploy timeline D+0→D+5 + 6 Communication Rules (entity deploy_timeline_event, communication_rules_acceptance) — T3 giả định nằm trong payload detail API-ERP-016]`
- `[NEEDS_REVIEW: thiếu endpoint xác nhận capacity gắn Gate 2 của OPS_PLAN — hiện chỉ có GET /api/v1/erp/capacity (API-ERP-069)]`

---

## 7. UI-ID Registry

| UI-ID | Loại | Mô tả |
|-------|------|-------|
| `UI-WEB-HONB-001` | Main Page | Handoff Bridge — split view worklist + detail (shared SALES↔OPS), route `/ops/handoff` |
| `UI-WEB-HONB-001-T1` | Tab | Bàn giao — checklist 5 nhóm + capacity check |
| `UI-WEB-HONB-001-T2` | Tab | Onboarding Tasks — task ADACC/CPORT/CAMP + milestone Day 1/7/14/30 |
| `UI-WEB-HONB-001-T3` | Tab | Deploy & Lịch sử — D+0→D+5, 6 Rules, audit trail |
| `UI-WEB-HONB-001-D1` | Dialog | Xác nhận Trình Gate 2 (Sales) |
| `UI-WEB-HONB-001-D2` | Dialog | Ký nhận / Từ chối tiếp nhận (OPS_AM — ApprovalCard) |
| `UI-WEB-HONB-001-D3` | Dialog | Thu hồi / Trả về (SM) |
| `UI-WEB-HONB-001-D4` | Dialog | Cập nhật mục checklist (responsible + due date) |
| `UI-WEB-HONB-001-D5` | Dialog | Nhắc người đang chờ (từ WaitingOnIndicator) |
| `UI-WEB-HONB-001-S1` | Sheet | Chi tiết onboarding task (right 480px) |
| `UI-WEB-HONB-001-S2` | Sheet | Đánh giá mốc / kế hoạch khắc phục (right 720px) |
| `UI-WEB-HONB-001-S3` | Sheet | Audit chữ ký — signature event detail (right 480px) |
| `UI-WEB-HONB-001-M1` | View Mode | Sales view — soạn + submit + ký Gate 2 |
| `UI-WEB-HONB-001-M2` | View Mode | OPS view — queue tiếp nhận + ký nhận + tasks |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ (góc Sales) | `../../../../phase2-features/bcerp-web/handoff-onboard/handoff-va-onboarding-bridge.md` | FEAT-ERP-HONB-001 |
| Tính năng nghiệp vụ (góc OPS) | `../../../../phase2-features/bcerp-web/handoff-onboard/handoff-va-onboarding-bridge-ops-004.md` | FEAT-ERP-HONB-002 |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | §6.1 MOD-HANDOFF-ONBOARD |
| Design system | `../../../design-system.md` | Tokens + 12 components |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | S4, menu Sales + Ops |
