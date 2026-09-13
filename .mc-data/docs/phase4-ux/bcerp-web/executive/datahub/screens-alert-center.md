# Screen Group: Alert Center

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `datahub` (MOD-DATAHUB-BI + MOD-SLA-NOTIF)
> **Tính năng:** FEAT-ERP-DHUB-003 + FEAT-ERP-SLANOT-001 (+ tín hiệu stale nguồn từ FEAT-ERP-DHUB-005)
> **Route:** `/exec/alerts`
> **Main UI-ID:** `UI-WEB-ALERT-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

Implements: FEAT-ERP-DHUB-003 (Alert Center & cảnh báo rủi ro vận hành — escalation inbox cross-module), FEAT-ERP-SLANOT-001 (SLA breach đỏ tập trung + góc dashboard compliance của web), FEAT-ERP-DHUB-005 (alert stale nguồn dữ liệu — dữ liệu hợp lệ cuối + nhãn manual trên đích deep-link).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Main UI-ID | `UI-WEB-ALERT-001` |
| Route | `/exec/alerts` (`?view=inbox\|stats\|rules`, `?severity=&type=&status=`) |
| Loại | Escalation inbox — W1 worklist + bulk + keyboard-first; khung trên W4 hàng KPI/SLA (Navigation §4.5) |
| FEAT-ID | FEAT-ERP-DHUB-003, FEAT-ERP-SLANOT-001, FEAT-ERP-DHUB-005 |
| Workspace | Executive (`/exec`) + mọi manager (role-scoped) |
| Đối tượng nghiệp vụ | Alert (`alert` — append-only: code, type, severity đỏ/vàng/xanh, state, source_ref, raised_at) + `alert_rule` + `alert_event_log` + `alert_delegate` |
| Vai trò chính | BOD_CEO, BOD_CFO_CTO (thấy full) |
| Vai trò liên quan | Manager role-scoped: SALES_L2+, HR_L2, OPS_AM, FIN_L2 (chỉ alert trong scope phòng); SYS_ADMIN (alert kỹ thuật đầy đủ; alert đỏ tài chính chỉ xem trạng thái) |
| Workflow stage | `OPEN` → (ack + reason) → `ACKNOWLEDGED` → (bắt đầu xử lý) → `IN_PROGRESS` → (resolution) → `RESOLVED`; nhánh `ESCALATED` (hệ thống khi quá SLA); re-push chu kỳ khi đỏ chưa có người nhận (state machine §6 FEAT-ERP-DHUB-003; lifecycle API: open→acknowledged→investigating→resolved) |

**Checklist workflow context (Bước 0):** (A) Object: Alert — hàng đợi trách nhiệm, append-only, không xóa; đỏ re-push đến khi có người nhận. (B) Actor chính: BOD nhận trách nhiệm alert đỏ; manager ack trong scope; SYS_ADMIN xử lý alert kỹ thuật. (C) Liên phòng: alert sinh từ mọi module — WALLET (số dư < 3 ngày chi, vàng; SLA đỏ 2h), ADACC (hard stop, die/spike/checkpoint TKQC), ARAP (aging vượt hạn), SLANOT (SLA breach đỏ, khiếu nại leo thang 24h), TIKTOK (anomaly shop), HR (HĐLĐ hết hạn 90/60/30), CORE (backup fail >30 phút, job sync fail, đứt hash-chain audit), DataHub (stale nguồn: QC >8h, ví >2h, timesheet >24h). (D) Lifecycle: OPEN→ACKNOWLEDGED→IN_PROGRESS→RESOLVED (+ESCALATED, +tái mở khi tái diễn); escalate do hệ thống khi quá SLA xử lý. (E) Cross-module: jump deep-link về object nguồn đúng surface (S6/S7/S9/S10/S16/S17/S20/S25/S27); mobile push ≤5 phút là kênh khẩn, web là nơi phân tích/xử lý đầy đủ. (F) Thông tin cần: mức nghiêm trọng, chuyện gì, ở nguồn nào, chờ ai bao lâu, đã re-push mấy lần, resolution + bằng chứng. (G) Quyết định: nhận trách nhiệm (đỏ), escalate lên cấp trên, đóng với resolution, đăng ký delegate. (H) Action được phép: acknowledge + reason (bắt buộc), bắt đầu xử lý, escalate, ghi resolution + bằng chứng, delegate (nhận thay, không xử lý thay), đề xuất chỉnh ngưỡng — KHÔNG có "bỏ qua" trống, KHÔNG xóa. (I) Exception: connector outage sinh alert hàng loạt → gộp batch theo nguồn; đỏ không người nhận → nổi đầu + re-push 15 phút; cả BOD vắng → delegate; false positive → đóng kèm nhãn thống kê. (J) 1 surface duy nhất cho BOD full + manager role-scoped — permission filter, không nhân bản page theo vai.

---

## 1. TRANG CHÍNH

### 1.1. Layout — W4 khung trên (hàng KPI/SLA) + W1 thân worklist (compact, full-width)

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│ Executive > Alert Center                                        ⏱ tự refresh 30s · 14:32 │
│ ┌──────────────┬──────────────┬──────────────┬──────────────┐                            │
│ │ ĐỎ CHƯA NHẬN │ ĐANG XỬ LÝ   │ SLA ĐỎ 24H   │ ESCALATION   │  ← W4 KPI strip            │
│ │ 3 ⛔ re-push │ 11          │ 6           │ timeout 2    │    click → lọc sẵn         │
│ └──────────────┴──────────────┴──────────────┴──────────────┘                            │
│ [Tìm mã alert / nguồn…]                          [Bộ lọc ▾]        [Cột ▾] [Views ▾]     │
│ (Đỏ chưa nhận ·3×) (Chờ tôi ack ·2×) (SLA đỏ ·6×) (Escalated ·2×) (Batch outage ·1×)     │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│ SEV │ LOẠI · TÓM TẮT                    │ NGUỒN (deep-link) │ CHỜ AI · BAO LÂU │ TRẠNG THÁI│
│─────┼───────────────────────────────────┼───────────────────┼──────────────────┼───────────│
│ ⛔đỏ │ ví_balance: Ví FMCG01 1,8tr ₫ <   │ → S7 Ví & Đối soát│ (chưa có người   │ [OPEN]    │
│     │ ngưỡng đủ chi 3 ngày — SLA đỏ 2h  │  /finance/wallet  │  nhận · re-push  │ 🔔 4 lần  │
│     │                                   │                   │  22:00/22:15/22:30│           │
│ 🟡vàng│ aging: 3 hóa đơn RET03 quá 60 ngày│ → S10 AR /finance │ FIN_L2 · 6h      │ [ACKNOWLEDGED]
│     │ (đề xuất PAUSE — mốc tạm KXN-22)  │ /ar-ap?tab=ar     │                  │           │
│ ⛔đỏ │ sla_breach: Ticket #TK-1092 vỡ    │ → S16 /ops/tickets│ OPS_CONT · 40′   │ [ESCALATED]
│     │ SLA tier P1 — leo thang BOD       │                   │                  │           │
│ 🟡vàng│ hodl: 7 HĐLĐ hết hạn ≤30 ngày    │ → S20 /hr/records │ HR_L2 · 1 ngày   │ [OPEN]    │
│ 🟡vàng│ batch: nguồn Meta DEGRADED —     │ → S27 /admin/     │ SYS_ADMIN · 25′  │ [IN_PROGRESS]
│     │ 47 widget phụ thuộc (x47 con)     │  settings         │                  │           │
│─────┼───────────────────────────────────┼───────────────────┼──────────────────┼───────────│
│ Bulk bar (khi chọn): [Đã chọn 4] [Ack hàng loạt + reason] [Escalate]                     │
│ ← 1 2 3 … 8 →   20 | 50 | 100 dòng                                Đỏ nổi đầu danh sách   │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

- **Hàng KPI/SLA (W4):** 4 ô count — mỗi ô click = áp quick-filter tương ứng. Ô "ĐỎ CHƯA NHẬN" tô `--state-sla-breach` + icon chuông khi >0 (không bao giờ im lặng — đỏ re-push).
- **Sắp xếp mặc định:** severity đỏ trước, trong cùng mức theo `raised_at` cũ nhất trước; alert đỏ re-push nổi đầu. Bulk bar trượt lên khi chọn ≥1 hàng.
- **Refresh:** poll 30s + cập nhật khi có sự kiện `alert.raised`; đồng thời với push mobile ≤5 phút (mobile là còi báo động, web là nơi xử lý).

### 1.2. Components

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| KPI StatCard ×4 | count + click lọc | Đỏ chưa nhận / Đang xử lý / SLA đỏ 24h / Escalation timeout |
| DataTable (W1) | compact 32px, sticky header, sort, column config persist, saved-views | Đỏ nổi đầu; keyboard roving-tabindex |
| Search + quick chips | server-side; chip tháo được từng cái | Chip = filter đã lưu theo vai |
| Filter panel | `severity, type, status, source_module, from, to, batch, assignee` | Theo API-CORE-043 |
| Bulk bar | [Ack hàng loạt + reason] — chỉ vàng/xanh; **đỏ không có bulk ack** | BR-002: đỏ bắt buộc người nhận trách nhiệm từng cái |
| SeverityBadge | 🔴 Đỏ / 🟡 Vàng / 🟢 Xanh — màu + icon + chữ (color-blind safe) | Đỏ tiền (ví) kèm icon ví + câu giải thích |
| StatusBadge | OPEN / Đã ghi nhận / Đang xử lý / ESCALATED / RESOLVED — token §1 | 1 badge/hàng; re-push count = chip 🔔 riêng |
| WaitingOnIndicator | chip "chờ ai · bao lâu" trong row + khối trong Sheet | Chưa có người nhận (đỏ) = "chưa có người nhận — re-push HH:MM" |
| WarningIndicator | banner đầu trang khi có đỏ chưa nhận | Không dismiss; 3 phần: chuyện gì / cần ai / hạn (SLA đỏ 2h…) |

### 1.3. Cột / Trường Hiển Thị

| Tên | Trường | Định dạng | Sắp xếp | Rộng |
|-----|--------|----------|---------|------|
| Sev | `severity` (đỏ/vàng/xanh) | SeverityBadge | Có (đỏ trước) | 70px |
| Loại · Tóm tắt | `type` + summary sinh từ rule | Icon loại + text 1 dòng ("Ví FMCG01 < ngưỡng đủ chi 3 ngày") | Không | auto |
| Nguồn (deep-link) | `source_ref` → surface đích | Link "→ S7 Ví & Đối soát" theo bảng §1.4 | Không | 200px |
| Chờ ai · bao lâu | người nhận trách nhiệm + duration | WaitingOnIndicator; chưa nhận + đỏ = "chưa có người nhận" | Có | 180px |
| SLA xử lý còn lại | sla_due_at | chip neutral → `sla-warning` ≥50% → `sla-breach` vỡ (icon chuông) | Có | 130px |
| Trạng thái | `state` | StatusBadge (bảng dưới) | Có | 140px |
| Re-push | `repush_count` + lần cuối | 🔔 4 · 22:30 | Có | 110px |
| Phát lúc | `raised_at` | dd/MM HH:mm tuyệt đối | Có (mặc định) | 130px |

**Trạng thái:** OPEN → pending; ACKNOWLEDGED → info; IN_PROGRESS → sla-warning; ESCALATED → sla-breach; RESOLVED → approved. Batch = chip "batch ×47" mở danh sách sự kiện con.

### 1.4. Bản Đồ Deep-link Về Nguồn (jump về object nguồn)

| Loại alert (`type`) | Nguồn phát | Deep-link đích | Action đích |
|---------------------|-----------|----------------|-------------|
| `ví_balance` (vàng < 3 ngày chi; SLA đỏ 2h) | WALLET | S7 `/finance/wallet?focus=client:{id}` | FIN đối trừ/khớp — S7 là bề mặt thao tác |
| `hardstop` ADACC (chờ khớp tiền quá hạn, die/spike/checkpoint TKQC) | ADACC | S9 `/ops/ad-accounts?focus={tk}` | OPS xem; action khớp tiền tại S7 |
| `ar_aging` (vượt bậc 30/60/90; đề xuất PAUSE theo mốc tạm KXN-22) | ARAP | S10 `/finance/ar-ap?tab=ar&bucket=` | FIN dunning/nhắc nợ |
| `sla_breach` đỏ (timer vỡ) + khiếu nại leo thang 24h | SLANOT | S16 `/ops/tickets?focus={tk}` | OPS_CONT xử lý/escalate |
| `tiktok_anomaly` (shop khóa, settlement lệch, baseline lệch) | TIKTOK | S17 `/ops/tiktok-shop?shop={id}` | OPS xem/ack |
| `hodl_expiring` (HĐLĐ 90/60/30) | HR-CORE | S20 `/hr/records?tab=hodl&filter=expiring` | HR gia hạn |
| `hash_chain` (đứt hash-chain audit) | CORE | S25 `/admin/audit?focus=chain` | BOD xác minh ngay |
| `backup` (>30 phút), `sync_fail`, `stale` (QC >8h, ví >2h, timesheet >24h) | CORE / DataHub | S27 `/settings?tab=connections&source=` | SYS_ADMIN backfill/replay |
| `payment_escalation` (lệnh chi ngưỡng quá hạn duyệt) | ARAP/WALLET | S6 `/finance/approvals?focus={id}` | BOD duyệt escalation cuối |
| `discount_escalation` (chiết khấu vượt định mức quá hạn) | QDD | S3 `/sales/deal-desk?filter=discount_pending` | GM duyệt |
| Nguồn lệch số BI / stale mart | DATAHUB | S23 `/exec/bi` (DataHealthStrip) | BOD/CFO xem ngữ cảnh |

Deep-link giữ breadcrumb surface đích + nút "Về nguồn" quay lại S24 (Navigation §4.2).

### 1.5. Hành Động Chính

| Sự kiện | Hành động | Kết quả |
|---------|---------|--------|
| Chọn hàng (Space) | Mở Sheet S1 chi tiết + giữ context grid | Esc đóng, focus trả về hàng |
| **A** / nút [Acknowledge] | Dialog D1 — reason bắt buộc; đỏ ghi người nhận trách nhiệm | OPEN → ACKNOWLEDGED; dừng re-push |
| [Bắt đầu xử lý] | Transition | ACKNOWLEDGED → IN_PROGRESS (investigating) |
| [Escalate] | Dialog D1 variant escalate | Ghi event + thông báo cấp trên; quá SLA hệ thống tự ESCALATED |
| [Đóng] | Dialog D2 — resolution + bằng chứng (link giao dịch/job) bắt buộc | IN_PROGRESS → RESOLVED; tái diễn trong cửa sổ cấu hình → tái mở có kiểm soát |
| Click nguồn (cột) | Jump deep-link object nguồn | Bảng §1.4; xử lý thật tại surface nguồn |
| Bulk: chọn vàng/xanh cùng loại | [Ack hàng loạt + reason chung] | N transition; đỏ bị loại khỏi bulk tự động |
| [Delegate] (BOD) | Dialog D3 | Đăng ký delegate nhận khi vắng — nhận thay, không xử lý thay |
| [Đề xuất chỉnh ngưỡng] (view M3) | Dialog D4 | Gửi luồng chính sách REQ-BOD-009 |
| `?` | Cheat-sheet phím tắt | ↑↓ Space A E Enter Esc |

### 1.6. States

- **Loading:** skeleton 10 hàng; KPI skeleton 4 ô.
- **Empty:** EmptyState "Không có cảnh báo chưa xử lý — tốt" (chip Đỏ rỗng = trạng thái đáng mong); chip có filter không khớp → "Không có alert khớp bộ lọc" + CTA xóa filter.
- **Error:** hàng lỗi + retry; transition vi phạm (đóng alert đã RESOLVED) → 409 `INVALID_STATE` toast; `SOD_VIOLATION` → toast lỗi tiền không tự đóng + banner "người sinh sự kiện không được acknowledge chính mình".
- **Mất kết nối real-time:** banner info "không cập nhật tự động —最后一次 14:20" + nút tải lại (không giả tươi).

### 1.7. Phân Quyền (PEP — action thiếu quyền bị ẨN, không disabled)

| Thành phần | BOD_CEO | BOD_CFO_CTO | SALES_L2+ / OPS_AM / HR_L2 / FIN_L2 (manager) | SYS_ADMIN |
|-----------|---------|-------------|----------------------------------------------|-----------|
| Xem alert (tất cả mức, tất cả loại) | ✅ full | ✅ full | ✅ role-scoped (chỉ alert trong scope phòng mình) | ✅ alert kỹ thuật đầy đủ; alert đỏ tài financial chỉ xem trạng thái |
| Ack + reason alert đỏ | ✅ | ✅ | ✅ (đỏ thuộc scope mình) | ❌ (ẩn — chỉ BOD/delegate; thử đóng ghi audit) |
| Ack/đóng alert kỹ thuật (backup/sync/stale/hash_chain) | ✅ | ✅ | ẩn (trừ OPS_AM với stale ops) | ✅ (mức vàng/xanh kỹ thuật) |
| Bắt đầu xử lý / escalate / ghi resolution | ✅ | ✅ | ✅ (scope mình) | ✅ (riêng alert kỹ thuật) |
| Đăng ký delegate (D3) | ✅ | ✅ | ❌ | ❌ |
| Xem/đề xuất cấu hình ngưỡng (M3) | ✅ (duyệt chính sách) | ✅ (đề xuất) | ẩn | ✅ (tạo rule kỹ thuật → BOD duyệt) |
| Xem thống kê SoD / khiếu nại leo thang (M2) | ✅ | ✅ (CFO rà định kỳ) | ❌ | ❌ (không xem nội dung rủi ro nghiệp vụ ngoài scope) |
| Giá trị nhạy cảm T3/T4 trong ngữ cảnh alert | ✅ | ✅ | theo phân cấp dữ liệu | ❌ (masked — `PII_MASKED_FIELD`) |
| Xóa bản ghi alert | **Không tồn tại ở mọi vai** — append-only, chỉ đóng có dấu vết | | | |

SoD: người sinh ra sự kiện (VD người duyệt giao dịch bị cảnh báo) không được acknowledge alert đó — hệ thống chặn + ghi vi phạm. SYS_ADMIN nhận alert kỹ thuật, không tự đóng alert đỏ của BOD (BR-007).

---

## 2. TABS

N/A — surface là 1 escalation inbox duy nhất với 3 view modes (Inbox / Thống kê / Ngưỡng & Routing, §5) chuyển bằng toggle `?view=`; phân tách BOD full vs manager role-scoped do permission filter đảm nhiệm, không phải tab. Global context (KPI strip + refresh status) giữ nguyên khi đổi view.

---

## 3. DIALOGS

| # | Dialog | UI-ID | Loại | Mở khi nào |
|---|--------|-------|------|-----------|
| 1 | Acknowledge / Escalate (+reason) | `UI-WEB-ALERT-001-D1` | Form bắt buộc reason | [Acknowledge] / [Escalate] / phím A |
| 2 | Đóng với resolution | `UI-WEB-ALERT-001-D2` | Form + link bằng chứng | [Đóng] trên Sheet S1 |
| 3 | Đăng ký delegate | `UI-WEB-ALERT-001-D3` | Form khoảng ngày | [Delegate] (BOD) |
| 4 | Đề xuất chỉnh ngưỡng cảnh báo | `UI-WEB-ALERT-001-D4` | Form | [Đề xuất chỉnh] trong view M3 |

### 3.1. D1 — Acknowledge / Escalate
- **Fields:** lý do (bắt buộc ≥10 ký tự — không có nút "bỏ qua" trống, UI chặn submit khi rỗng); khi alert đỏ: người nhận trách nhiệm (mặc định = người đang ack, dropdown chọn delegate đã đăng ký); escalate: cấp nhận + lý do.
- **SoD:** nếu người ack trùng người sinh sự kiện nguồn → chặn trước khi gọi API, hiện lý do chặn.
- **Actions:** [Xác nhận] → `POST /core/alerts/instances/:id/transitions` (API-CORE-044) body `{ "action": "acknowledge|escalate", "reason", "owner?" }`; severity CRITICAL → yêu cầu MFA step-up (`[STEP-UP]` — 401 `MFA_STEP_UP_REQUIRED` → modal shield-mfa).
- **States:** processing khóa nút chống double-submit; thành công → row cập nhật trạng thái + toast, focus chuyển hàng kế (không reload cả list).

### 3.2. D2 — Đóng với resolution
- **Fields:** resolution tóm tắt (bắt buộc ≥10 ký tự); bằng chứng (link giao dịch/job/PR — bắt buộc ≥1); nhãn "false positive" (tùy chọn — vào thống kê review ngưỡng).
- **Quy tắc:** alert đỏ BOD không thể do SYS_ADMIN đóng (nút ẩn; nếu API vẫn bị gọi → chặn + audit); alert RESOLVED không xóa — tái diễn trong cửa sổ thời gian → tái mở có kiểm soát (ACKNOWLEDGED), lịch sử cũ giữ nguyên.
- **Actions:** [Đóng] → `POST /core/alerts/instances/:id/transitions` (API-CORE-044) `{ "action": "resolve", "resolution", "evidence_refs[]" }`.

### 3.3. D3 — Đăng ký delegate
- **Fields:** delegate (Combobox vai đúng cấp — BOD_CEO delegate CFO / FIN_L2 delegate FIN theo API-CORE-023); từ ngày → đến ngày.
- **Quy tắc:** delegate **nhận thay, không xử lý thay** — delegate ack được nhưng nút Đóng (D2) vẫn khóa cho người nhận gốc khi trở lại (BR: nhận, không delegate xử lý).
- **Actions:** [Lưu] → `PUT /core/policies/delegates` (API-CORE-023, `[STEP-UP]`).

### 3.4. D4 — Đề xuất chỉnh ngưỡng cảnh báo
- **Fields:** rule (lock), ngưỡng mới, severity đề xuất, routing đề xuất, lý do (bắt buộc).
- **Quy tắc:** mọi chỉnh sửa có version; rule tắt/sửa severity là `[STEP-UP]` + audit; duyệt thuộc luồng chính sách REQ-BOD-009 (BOD_CEO duyệt); thống kê false positive theo rule là căn cứ đề xuất.
- **Actions:** [Gửi đề xuất] → `POST /core/alerts/rules` (API-CORE-041) hoặc `PUT /core/alerts/rules/:id` (API-CORE-042) với trạng thái "chờ duyệt" hiển thị rõ.

---

## 4. SHEETS

| # | Sheet | UI-ID | Vị trí | Mở khi nào |
|---|-------|-------|--------|-----------|
| 1 | Chi tiết alert + lịch sử xử lý | `UI-WEB-ALERT-001-S1` | Panel phải đẩy nội dung 720px | Chọn hàng (Enter/Space/click) |
| 2 | Batch gộp outage | `UI-WEB-ALERT-001-S2` | Panel phải 480px | Click chip "batch ×N" |

### 4.1. Sheet S1 — Chi tiết alert (720px)
- **Mục tiêu:** mọi thứ cần để quyết nhận/escalate/đóng mà không rời worklist.
- **Nội dung:** header = severity + type + trạng thái + raised_at; khối "chuyện gì" (ngữ cảnh sự kiện: giá trị chạm ngưỡng nào — MoneyDisplay cho tiền, timestamp dữ liệu hợp lệ cuối + nhãn "manual" cho stale nguồn); khối "cần ai làm gì — hạn còn lại" (WarningIndicator + WaitingOnIndicator); deep-link nguồn (bảng §1.4); Timeline event log immutable: raised / re-push (mỗi lần, kênh, người nhận push) / ack (ai, reason) / escalate / resolve — ai, lúc nào, nội dung; delegate đang hiệu lực; alert liên quan cùng nguồn/cùng cửa sổ thời gian.
- **Footer sticky:** [Acknowledge] [Escalate] [Đóng] theo quyền + trạng thái hiện tại (nút không đúng quyền/trạng thái bị ẩn).
- **States:** loading skeleton; nguồn degraded → banner manual trên đầu sheet; giá trị T3/T4 masked theo vai.

### 4.2. Sheet S2 — Batch gộp (480px)
- **Mục tiêu:** anti-flood — 1 alert "nguồn Meta DEGRADED — 47 widget phụ thuộc" thay vì 47 alert riêng (BR-004).
- **Nội dung:** root cause chung + số sự kiện con; danh sách sự kiện con (thời gian, object bị ảnh hưởng, widget/mart phụ thuộc); trạng thái batch; deep-link nguồn + S23 DataHealth.
- **Actions:** ack/đóng cấp batch (reason áp cả đợt); mở từng con để xử lý riêng khi cần.

---

## 5. VIEW MODES

| Mode | UI-ID | Icon | Hiện khi nào |
|------|-------|------|--------------|
| M1 — Inbox escalation (W1) | `UI-WEB-ALERT-001-M1` | `inbox` | Default (§1) |
| M2 — Thống kê rủi ro vận hành | `UI-WEB-ALERT-001-M2` | `bar-chart-3` | Toggle view — CFO/BOD rà định kỳ |
| M3 — Ngưỡng & Routing | `UI-WEB-ALERT-001-M3` | `settings` | Toggle view — xem/đề xuất cấu hình |

### Mode M2 — Thống kê rủi ro vận hành
- **Mục tiêu:** đánh giá xu hướng rủi ro trong họp điều hành — số dẫn tới quyết định review ngưỡng, không trừng phạt tự động (BR-006).
- **Thông tin:** vi phạm SoD bị chặn theo tháng × rule × vai (truy xuất được từng sự kiện gốc); khiếu nại nghiêm trọng leo thang BOD — đạt/trượt SLA 24h; false positive theo rule (căn cứ tinh chỉnh ngưỡng); alert đỏ không người nhận (sự cố ghi quarterly review); MTTR acknowledge→resolve theo loại.
- **Components:** bảng + biểu đồ cột đơn giản (W4 — mỗi chart click ra được danh sách alert kỳ đó); KPI StatCard hàng trên.
- **Actions:** [Xuất báo cáo kỳ] (API-CORE-039 pattern — `[NEEDS_REVIEW: thiếu endpoint thống kê SoD/khiếu nại chuyên biệt]`, xem §6).
- **States:** kỳ không có vi phạm → EmptyState "0 vi phạm trong kỳ" (báo cáo trống có nhãn giải thích, không bỏ trống); SYS_ADMIN không thấy view này.

### Mode M3 — Ngưỡng & Routing (cấu hình cảnh báo)
- **Mục tiêu:** bảng cấu hình ngưỡng minh bạch — xem được rule nào đang chạy, version nào, ai duyệt; chỉnh qua luồng có duyệt, không sửa ngầm.
- **Cột:** mã rule · mô tả ngưỡng (VD "ví < đủ chi 3 ngày — SLA đỏ 2h") · severity · kênh + người nhận (routing) · version + hiệu lực · trạng thái (ACTIVE / chờ duyệt) · false positive 30 ngày.
- **Danh mục bắt buộc BR-001** hiển thị đủ: đứt hash-chain audit; ví dưới ngưỡng đủ chi (mốc chính thức chờ chốt — nhãn "ngưỡng tạm"); die/spike/checkpoint TKQC; SLA breach đỏ; vượt hạn mức tuần nạp; backup fail >30 phút; job sync fail; stale dữ liệu (QC >8h, ví >2h, timesheet >24h); aging; HĐLĐ hết hạn; TikTok anomaly; hard stop quá hạn.
- **Actions:** [Đề xuất chỉnh] (D4 — mọi vai xem được); SYS_ADMIN [Tạo rule kỹ thuật] → BOD_CEO duyệt; `[STEP-UP]` khi đổi severity/routing.
- **States:** rule chờ duyệt → badge pending + người đề xuất; disabled rule → hàng mờ + lý do tắt + ai tắt.

---

## 6. API ENDPOINTS

Endpoints THẬT từ `phase3-architecture/technical-specs/api-contract.md` (§6.7 Alert Center, §6.2 policy delegate, §6.6 BI):

| Khi nào | Method | Endpoint | Tham số / Ghi chú |
|---------|--------|----------|-------------------|
| Tải inbox / tìm / lọc / phân trang (M1, KPI strip) | GET | `/core/alerts/instances` (API-CORE-043) | `?status=open\|acknowledged\|investigating\|resolved&severity=critical\|warning\|info&type=&source_module=&from=&to=&batch=&search=&page=&limit=20\|50\|100` — filter theo severity routing của vai (PDP); chi tiết 1 alert = `?id=` |
| Acknowledge / bắt đầu xử lý / escalate / resolve (D1, D2) | POST | `/core/alerts/instances/:id/transitions` (API-CORE-044) | Body `{ "action", "reason", "owner?", "resolution?", "evidence_refs[]" }`; lifecycle open→acknowledged→investigating→resolved; không auto-close; `[STEP-UP]` severity CRITICAL; 409 khi vi phạm state machine; `SOD_VIOLATION` khi tự ack sự kiện của mình |
| Danh sách rule + tạo rule kỹ thuật (M3) | GET/POST | `/core/alerts/rules` (API-CORE-041) | Rule trên marts + event: ví < đủ chi 3 ngày, mismatch, aging, die account, shop anomaly, DLQ depth, freshness vi phạm; Tạo: SYS_ADMIN → BOD_CEO duyệt |
| Đề xuất chỉnh / tắt rule (D4) | PUT | `/core/alerts/rules/:id` (API-CORE-042) | `[STEP-UP]` khi đổi severity/routing; audit mọi thay đổi; versioned |
| Routing severity → kênh + người nhận (M3) | GET/PUT | `/core/alerts/routing` (API-CORE-045) | SYS_ADMIN → BOD_CFO_CTO duyệt; dispatch ủy quyền MOD-SLA-NOTIF (on-call DI-005) |
| Delegate nhận alert khi vắng (D3) | GET/PUT | `/core/policies/delegates` (API-CORE-023) | `[STEP-UP]`; BOD_CEO delegate CFO, FIN_L2 delegate FIN |
| Ngữ cảnh SLA của alert ticket (S1, M2) | GET | `/api/v1/erp/sla-timers` (API-ERP-073) | `?object_type=ticket&sla_state=` — trạng thái timer per object |
| Ngữ cảnh stale nguồn (S1, S2) | GET | `/core/bi/freshness` (API-CORE-040) | `last_watermark, is_stale` per mart — hiển thị dữ liệu hợp lệ cuối trên alert stale |
| Thống kê compliance SLA (M2) | GET | `/core/bi/marts/cs_sla` (API-CORE-036) | Query mart cs_sla: filter server-side + freshness |
| Refresh real-time inbox | — | poll 30s trên API-CORE-043 + event `alert.raised` (COMP-CORE-011) | Mobile push ≤5 phút là kênh khẩn (SYS-MOBILE-INTERNAL) — web không phụ thuộc push |
| Chuyển view mode | — | client routing `/exec/alerts?view=inbox\|stats\|rules` | Không tốn endpoint riêng |

**[NEEDS_REVIEW] — endpoint thiếu trong api-contract.md, KHÔNG bịa:**
1. Thống kê vi phạm SoD bị chặn + khiếu nại leo thang BOD (`sod_violation_stat`) — M2; hiện chỉ tổng hợp được gần đúng qua mart/audit, chưa có endpoint chuyên theo kỳ × rule × vai.
2. Lịch sử re-push đầy đủ per alert (`alert_event_log` — mỗi lần re-push: thời điểm, kênh, người nhận push) — S1; list instances chỉ có count.
3. Bulk acknowledge 1 call (bulk bar) — hiện phải gọi N lần API-CORE-044; cần endpoint batch hoặc xác nhận gọi N lần trong 1 transaction.
4. Đăng ký delegate riêng cho alert (`alert_delegate` theo `principal_role`/`delegate_role`) — API-CORE-023 hiện bó trong policies (CEO→CFO, FIN_L2→FIN); mở rộng vai manager cần xác nhận.

---

## 7. UI-ID Registry

| UI-ID | Loại | Mô tả |
|-------|------|-------|
| `UI-WEB-ALERT-001` | Main Page | Alert Center — W4 KPI strip + W1 escalation inbox, route `/exec/alerts` |
| `UI-WEB-ALERT-001-M1` | View Mode | Inbox escalation (Mặc định — worklist + bulk + keyboard) |
| `UI-WEB-ALERT-001-M2` | View Mode | Thống kê rủi ro vận hành (SoD, leo thang SLA, false positive) |
| `UI-WEB-ALERT-001-M3` | View Mode | Ngưỡng & Routing (cấu hình cảnh báo — xem/đề xuất) |
| `UI-WEB-ALERT-001-D1` | Dialog | Acknowledge / Escalate — reason bắt buộc, đỏ ghi người nhận trách nhiệm |
| `UI-WEB-ALERT-001-D2` | Dialog | Đóng với resolution + bằng chứng (append-only) |
| `UI-WEB-ALERT-001-D3` | Dialog | Đăng ký delegate (nhận thay, không xử lý thay) |
| `UI-WEB-ALERT-001-D4` | Dialog | Đề xuất chỉnh ngưỡng cảnh báo (luồng chính sách REQ-BOD-009) |
| `UI-WEB-ALERT-001-S1` | Sheet | Chi tiết alert + lịch sử xử lý + deep-link nguồn (720px) |
| `UI-WEB-ALERT-001-S2` | Sheet | Batch gộp outage — root cause + sự kiện con (480px) |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../../phase2-features/bcerp-web/datahub-bi/alert-center-va-canh-bao-rui-ro-van-hanh.md` | Upstream — FEAT-ERP-DHUB-003 |
| Tính năng nghiệp vụ | `../../../../phase2-features/bcerp-web/sla-notif/sla-va-notification-engine.md` | Upstream — FEAT-ERP-SLANOT-001 |
| Tính năng nghiệp vụ | `../../../../phase2-features/bcerp-web/datahub-bi/bi-bod-dashboard-va-p-va-l-realtime.md` | Upstream — FEAT-ERP-DHUB-005 (alert stale nguồn) |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | Upstream — §6.7 Alert Center |
| Design system | `../../../design-system.md` | Upstream — W1, ApprovalCard keyboard, WarningIndicator |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | Upstream — S24 `/exec/alerts` |
| Surface liên kết | `./screens-executive-bi.md` | S23 — alert stale/nguồn lệch drill sang DataHealthStrip |
| Surface đích deep-link | `../../finance/wallet/screens-wallet-recon.md`, `../../ops/cskh/screens-tickets.md`, `../../hr/hr-core/screens-hr-records.md` | Jump về object nguồn |
