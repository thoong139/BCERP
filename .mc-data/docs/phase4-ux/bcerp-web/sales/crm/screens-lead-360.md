# Screen Group: Lead 360 (detail pane của My Pipeline)

Implements: FEAT-ERP-CRM-001, FEAT-ERP-CRM-002, FEAT-ERP-CRM-003, FEAT-ERP-CRM-004

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `crm`
> **Tính năng:** FEAT-ERP-CRM-001..005
> **Route:** `/sales/pipeline/leads/:id`
> **Main UI-ID:** `UI-WEB-LEAD-002`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

---

## Thông Tin Common

| Trường | Giá trị |
|--------|--------|
| Workspace | Sales Workspace — **pane 60% phải của S1** (split view master-detail 40/60), KHÔNG phải page rời |
| Đối tượng nghiệp vụ | 1 Lead/Deal + scoring records + gate approvals + duplicate disputes |
| Vai trò chính | SALES_L1–L3 (xem + cập nhật deal của mình); Gate action: SALES_L2 (Gate 1), SALES_L3 (Gate 2); phân xử trùng: SM/GDKD |
| Workflow stage | Hiển thị đúng machine-state: new → dedup_check → assigned → scored → gate1 → qualified → gate2_signed_handoff → handed_to_cs; rejected; recycled |
| A. Object đang xử lý | Hồ sơ đầy đủ 1 lead: status + progress stage, đang chờ ai (SM ký? AM xác nhận?), bước tiếp theo |
| B. Primary actors | Owner của deal — quyết định advance stage, bổ sung dữ liệu scoring, xin bypass |
| C. Related actors | SALES_L2/L3 (ký gate), SM/GDKD (phân xử trùng, thẩm định borderline D, escalate), OPS_AM (xác nhận Gate 2 — link S4), SYS_ADMIN (merge vật lý sau phân xử) |
| D. Lifecycle | Stage machine 10 stage V6.0; scoring 2 lần (autoScore → qualifiedTier khóa sau Gate 1); Gate 1/2 có chữ ký |
| E. Cross-module | Gate 2 → Handoff Bridge S4; khách → Client 360 S28; tier → rà quý (API-ERP-009) |
| F. Information needs | Điểm + lý do K1–K12, tier + hệ quả, gate status + entry criteria từng mục, timeline hoạt động, trạng thái trùng |
| G. Decisions | Advance stage hay chưa; Gate Go/No-Go (+lý do); bổ sung dữ liệu → chấm lại; xác nhận không trùng / mở tranh chấp |
| H. Actions được phép | Advance (đủ done criteria), Gate Go/No-Go (đúng vai, SM≠chủ deal), nhập brief/meeting notes, bổ sung dữ liệu scoring, reassign (nếu có quyền) |
| I. Exceptions | SLA gate vỡ (escalate tự động), knock-out → AUTO LOST, thiếu dữ liệu chặn chấm, lead trùng khóa thao tác, NDA hết hạn giữa chừng, capacity = 0 trước Gate 2, "chờ kích hoạt" thiếu 100% NSQC |
| J. Cần chuyển màn hình? | Không — mọi quyết định hằng ngày của lead tại đây; chỉ jump-out khi qua module khác (S4 handoff, S28 client) |

---

## 1. TRANG CHÍNH (pane — mở trong split view của S1)

### 1.1. Layout

```
┌───────────────────────────────────────────────────────────────────────────────┐
│ [Danh sách S1 40%] │ LEAD 360 — 60%                                          │
│                    │ ┌─────────────────────────────────────────────────────┐ │
│                    │ │ LD-1041 · Công ty ABC TNHH        [Client 360 →]    │ │
│                    │ │ Nguyễn Văn A · 0901… · referral                     │ │
│                    │ │ Stage: QUALIFIED (4/6)   Tier: D · CQ 3.2 (sơ bộ E) │ │
│                    │ │ ⏱ WaitingOn: chờ SM ký Gate 1 · còn 14h/24h         │ │
│                    │ │ Owner: Trần B (SE) · [Reassign] (nếu có quyền)      │ │
│                    │ ├─────────────────────────────────────────────────────┤ │
│                    │ │ ProgressTracker: Raw●Brief●Meeting●Qualify◐GATE◎Dep │ │
│                    │ ├─────────────────────────────────────────────────────┤ │
│                    │ │ Tabs: [Tổng quan] [Scoring K1–K12] [Gate 1/2]       │ │
│                    │ │       [Timeline]                                    │ │
│                    │ │  (nội dung tab — xem §2)                             │ │
│                    │ ├─────────────────────────────────────────────────────┤ │
│                    │ │ ⚠ Banner dedup: Trùng tiềm năng với LD-0997 [So sánh]│ │
│                    │ │ Footer sticky: [Advance stage ▾] [Gate Go/No-Go]     │ │
│                    │ └─────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────────────────┘
```

- Header context (khách, stage, tier, WaitingOn, owner) **giữ nguyên khi chuyển tab**. Deep-link `/sales/pipeline/leads/:id` mở S1 với pane đã chọn (không page rời). Breadcrumb: `Sales > My Pipeline > [Lead #LD-1041]`.
- **ProgressTracker** ngang: node stage có trạng thái + người giữ + ngày chờ; stage đã có quyền xem click được để xem snapshot chuyển tiếp. Blocked (LOST/trùng khóa) → `--state-rejected` + icon.
- **Footer sticky** chứa 2 action chính; nút advance vô hiệu kèm lý do khi thiếu done criteria (hard gate 2 tầng — UI vô hiệu, API từ chối; kể cả bypass client, API-ERP-006 vẫn chặn).
- Tablet ≤1279px: pane mở như overlay từ danh sách; Esc đóng, focus trả về hàng vừa mở.

### 1.2. Header — trạng thái + ownership

| Khối | Nội dung |
|---|---|
| Trạng thái | Stage badge + tier chip (tooltip chú giải A tệ nhất → E tốt nhất) + 2 điểm: `qualifiedTier` nhãn "chốt" / autoScore nhãn "sơ bộ" |
| Progress | Đang stage nào, đang chờ ai, chờ bao lâu (WaitingOnIndicator — bắt buộc), bước tiếp theo + điều kiện |
| Ownership | Owner avatar + tên; nút Reassign tại chỗ nếu user có quyền (API-ERP-007); SM không thấy nút gate khi chính mình là chủ deal — hiển thị cảnh báo xung đột ký |
| Exceptions | WarningIndicator banner: dedup, SLA gate sắp vỡ/đã vỡ, WON trễ 24h, capacity = 0 trước Gate 2, "chờ kích hoạt — thiếu 100% NSQC" |

### 1.3. States

- **Loading:** skeleton pane (header + 3 tab placeholder) khi đổi hàng; **Empty:** không xảy ra (pane chỉ mở khi có hàng); **Error:** giữ nội dung cũ + banner lỗi + retry; **Locked (trùng đang tranh chấp):** toàn bộ action advance/gate/gán owner ẩn/vô hiệu + banner "đang tranh chấp — chờ SM/GDKD" (`--state-pending`).

---

## 2. TABS (panel tabs trong pane — R7 completeness)

| Tab | UI-ID | Mục tiêu | Lazy-load |
|---|---|---|---|
| Tổng quan | `UI-WEB-LEAD-002-T1` | Bức tranh hiện tại + brief/notes + dedup | Không (mặc định) |
| Scoring K1–K12 | `UI-WEB-LEAD-002-T2` | Điểm + lý do từng tiêu chí, bổ sung dữ liệu → chấm lại | Có |
| Gate 1/2 | `UI-WEB-LEAD-002-T3` | Entry criteria + ký Go/No-Go + handoff checklist | Có |
| Timeline | `UI-WEB-LEAD-002-T4` | Lịch sử hoạt động + audit chuyển stage | Có |

### Tab 1 — Tổng quan (`-T1`)
- **Thông tin:** brief sơ bộ 3 trường (Ngân sách / Sản phẩm-dịch vụ / Nhu cầu — mode edit cho owner, SLA 2h + late_flag), Full Brief 8 mục (checklist tiến độ x/8), meeting notes (bắt buộc trước QUALIFIED — thiếu → WarningIndicator), nguồn + chiến dịch, nhãn đặc biệt (partner-referral / bod-sponsored — không thay tier).
- **Dedup:** trạng thái `UNIQUE_ACTIVE / DUPLICATE_HARD / DUPLICATE_POTENTIAL / SUSPECTED / DISPUTE_OPEN / RESOLVED` + đối tác trùng (người ghi trước + bằng chứng) → nút "So sánh" mở Sheet `-S1`. Người nhập xác nhận "không trùng có lý do" hoặc mở tranh chấp (dialog `-D4`).
- **Actions:** lưu brief/notes (owner), So sánh trùng, reassign (theo quyền). States: read-only cho người không phải owner ngoài quyền; edit disable khi lead khóa (dispute/TIER_LOCKED sau Gate 1 vẫn cho đọc).
- **Permissions:** xem: mọi SALES trong scope + OPS sau handoff; edit: owner (L1–L4); gdkd xem toàn Sales.

### Tab 2 — Scoring K1–K12 (`-T2`)
- **Thông tin:** trạng thái scoring (NOT_SCORED / AUTO_SCORED / INSUFFICIENT_DATA / FLAGGED_SM_REVIEW / AUTO_LOST / QUALIFIED_TIER_SET / TIER_LOCKED); bảng 12 hàng K1–K12: kết luận + lý do + data_refs; K1–K5 đánh dấu knockout (fail bất kỳ → AUTO LOST, hiển thị rõ nhánh tư vấn K4 nếu áp dụng); K6–K12 flag → hàng đợi SM review 4h; điểm CQ (5 tiêu chí trọng số 30/25/20/15/10, thang 1–5) + tier map từ cấu hình version (không hardcode).
- **Trạng thái "Thiếu dữ liệu":** chỉ rõ tiêu chí thiếu (≥2/5), chỉ có hành động "Bổ sung dữ liệu → chấm lại" (dialog `-D3`); hiển thị quỹ chấm lại còn lại (lead cũ ≤180 ngày: đúng 1 lần). KHÔNG tồn tại nút "sửa điểm" cho bất kỳ vai nào — kể cả SYS_ADMIN.
- **Borderline Tier D (3.0–3.49):** khối thẩm định SM SLA 4h — SM thấy nút "Thẩm định" kèm lý do bắt buộc; quá hạn hiển thị "đã escalate GDKD". Tier E: SM thấy nút "Xin bypass First Meeting" (kèm lý do; không miễn Gate 1/2).
- **Actions:** Bổ sung dữ liệu (`-D3`), Thẩm định borderline / review flag (SM), Xin bypass (SM). **Permissions:** xem điểm: mọi SALES trong scope; bổ sung dữ liệu: L1–L4 owner; review/thẩm định/bypass: SM duy nhất (không thẩm định deal của chính mình); GDKD: escalate.

### Tab 3 — Gate 1/2 (`-T3`)
- **Gate 1 (Go/No-Go):** checklist entry criteria machine-checkable từng mục đạt/chưa: Full Brief 8 mục, NDA mutual signed còn hiệu lực, qualifiedTier hợp lệ, meeting notes (B/C bắt buộc; bypass D/E kèm lý do SM). Thiếu bất kỳ → nút ký vô hiệu + mục chưa đạt tô `--state-rejected` kèm hướng dẫn khắc phục. Đủ → ApprovalCard ký: SM ≠ chủ deal (kiểm tra hiển thị trước + API xác thực lại), SLA 1 ngày làm việc, quá hạn hiển thị "đã escalate GDKD → BOD" (gate_escalations). No-Go: bắt buộc lý do ≥10 ký tự; kết quả khóa qualifiedTier, lead dừng — lưu hồ sơ.
- **Gate 2 (bàn giao):** Handoff Package 5 nhóm — checklist % hoàn thành, mỗi mục chưa xong hiển thị responsible + due date; thiếu → chặn ký (SC-004). Capacity check ≠ 0 (capacity = 0 → cảnh báo GDKD + OPS_PLAN trước khi ký; ký vẫn được nếu GDKD chấp nhận rủi ro bằng văn bản — log). SM ký → trạng thái "chờ AM xác nhận · SLA 4h" (WaitingOnIndicator, link sang S4); AM từ chối → "Đã trả về SM" + danh sách mục phải khắc phục, credit tạm dừng. Sau confirm: chưa nạp 100% NSQC → banner "Chờ kích hoạt — block tạo chiến dịch" (hard stop máy).
- **Override knockout:** chỉ deal chiến lược — SM đề xuất lý do bằng văn bản → GDKD phê duyệt; hiển thị trạng thái đề xuất, không tự chấm lại.
- **Permissions:** ký Gate 1: SALES_L2; ký Gate 2: SALES_L3 `[NEEDS_REVIEW: FEAT-ERP-CRM-004 §4 giao SM (L4) ký cả 2 gate — Navigation + API-ERP-008 quy L2/L3, chốt khi triển khai]`; xác nhận Gate 2: OPS_AM (trên S4); action sai vai bị ẩn (PEP).

### Tab 4 — Timeline (`-T4`)
- **Thông tin:** ActivityFeed full (API-ERP-005): tạo/sửa/transition/assign/gate/scoring — mỗi entry: avatar actor + hành động + thời gian tuyệt đối dd/MM HH:mm + link object; sự kiện gate hiển thị chữ ký + vai; sự kiện hệ thống (scoring engine, escalate) icon riêng. Lọc theo loại (email/call/meeting/note/system).
- **Audit chuyển stage:** mỗi transition show `criteria_snapshot` (mục đã khớp lúc chuyển) — bất biến, không xóa/sửa.
- **Actions:** chỉ đọc. `[NEEDS_REVIEW: api-contract chưa có endpoint GHI lead_activity_log (chỉ API-ERP-005 GET) — ghi nhận email/call/meeting cần bổ sung POST /leads/{id}/activity]`.

---

## 3. DIALOGS

| # | Dialog | UI-ID | Loại | Mở khi nào |
|---|--------|-------|------|-----------|
| 1 | Advance stage | `UI-WEB-LEAD-002-D1` | Confirm + snapshot | Footer "Advance stage ▾" khi đủ done criteria |
| 2 | Gate Go/No-Go | `UI-WEB-LEAD-002-D2` | ApprovalCard | Tab Gate — nút ký (đúng vai, đủ entry) |
| 3 | Bổ sung dữ liệu → chấm lại | `UI-WEB-LEAD-002-D3` | Form | Tab Scoring khi INSUFFICIENT_DATA / cần dữ liệu mới |
| 4 | Phân xử / xác nhận trùng | `UI-WEB-LEAD-002-D4` | Form + lý do | Sheet so sánh `-S1` (SM/GDKD) |

- **`-D1` Advance:** hiển thị done criteria sẽ được snapshot; xác nhận → API-ERP-006; lỗi 4xx liệt kê mục thiếu (nếu UI state cũ) + refresh checklist.
- **`-D2` Gate:** tóm tắt object + tier + SLA còn lại; Go = primary; No-Go = outline `--color-error` + lý do bắt buộc ≥10 ký tự; processing spinner + khóa nút chống double-submit; sau ký: toast + cập nhật header/ProgressTracker.
- **`-D3` Chấm lại:** form dữ liệu mới per tiêu chí thiếu; gửi kích hoạt đúng 1 lần chấm lại (audit log); hiển thị quỹ chấm lại còn lại; chặn lần 2 với lead cũ (lỗi API hiển thị nguyên văn lý do).
- **`-D4` Phân xử:** chọn người thắng + lý do + đính kèm bằng chứng; SM không phân xử khi mình là đương sự (hệ thống tự đẩy GDKD — disable kèm giải thích); GDKD quyết khiếu nại SLA 3 ngày. Merge/xóa vật lý KHÔNG nằm ở đây — SYS_ADMIN chỉ thao tác sau quyết chốt, qua Audit trail.

## 4. SHEETS

| # | Sheet | UI-ID | Nội dung | Mở khi nào |
|---|-------|-------|----------|-----------|
| 1 | So sánh lead trùng | `UI-WEB-LEAD-002-S1` | 2 cột đối chiếu 4 trường định danh + người ghi trước + bằng chứng hoạt động (email/call/meeting log) + trạng thái dispute + SLA phân xử còn lại | Banner dedup → "So sánh" |

Ưu tiên dạng sheet vì bằng chứng cần nằm cạnh quyết định phân xử ngay trong pane; footer sheet chứa các action `-D4` theo vai (xác nhận không trùng / mở tranh chấp / phân xử / khiếu nại).

## 5. VIEW MODES

| Mode | UI-ID | Nội dung | Ai thấy |
|---|---|---|---|
| View (mặc định) | `UI-WEB-LEAD-002-M1` | Đọc toàn bộ hồ sơ; action theo vai | SALES trong scope; OPS sau handoff (read) |
| Edit brief/notes | `UI-WEB-LEAD-002-M2` | Inline edit 3 trường brief + 8 mục Full Brief + meeting notes (owner) | Owner deal (L1–L4) |

Create không có (lead tạo từ S1 `-D1`); Approve = action `-D2` trong cùng surface, không mode riêng. Review/thẩm định của SM là action trong Tab Scoring/Gate, không phải mode.

## 6. API ENDPOINTS

| # | Endpoint | Phương thức | Gắn với | Ghi chú |
|---|----------|------------|---------|---------|
| 1 | `/api/v1/erp/leads/{id}` | GET (API-ERP-004) | Toàn bộ pane khi chọn hàng | K1–K12, tier, gate history, owner, dedup status |
| 2 | `/api/v1/erp/leads/{id}/activity` | GET (API-ERP-005) | Tab Timeline | Filter theo loại activity; phân trang |
| 3 | `/api/v1/erp/leads/{id}/transitions` | POST (API-ERP-006) | Dialog `-D1`, brief/notes save-advance | State machine; thiếu điều kiện → 4xx liệt kê mục thiếu |
| 4 | `/api/v1/erp/leads/{id}/gate-decision` | POST (API-ERP-008) | Dialog `-D2` | `{gate: 1\|2, decision: go\|no_go, note}`; Gate 2 gắn chữ ký handoff |
| 5 | `/api/v1/erp/leads/{id}/assign` | POST (API-ERP-007) | Nút Reassign header | Ghi assignment_history |
| 6 | `/api/v1/erp/customers/{id}/tier-review` | GET (API-ERP-009) | Tab Tổng quan (khối tier + hệ quả) | Read cho SALES |
| 7 | Gate 2 checklist + onboarding | GET `/api/v1/erp/handoffs` (API-ERP-016) | Tab Gate 2 — tóm tắt checklist | Chi tiết ký nhận tại S4; không nhân bản thao tác |

Không có endpoint riêng cho: chấm lại scoring (nút `-D3` — gọi transitions/đính kèm dữ liệu `[NEEDS_REVIEW: thiếu endpoint POST scoring re-score, ví dụ POST /leads/{id}/scoring]`), ghi activity log (Tab Timeline), và cập nhật checklist Handoff Package (thuộc S4/API-ERP-019 PATCH onboarding-tasks — link out, không thao tác tại đây).

## 7. UI-ID Registry

| UI-ID | Loại | Tên | Ghi chú |
|-------|------|-----|---------|
| `UI-WEB-LEAD-002` | detail (pane) | Lead 360 — pane 60% của S1 | Route `/sales/pipeline/leads/:id`; pattern W2 |
| `UI-WEB-LEAD-002-T1` | tab | Tổng quan (brief + notes + dedup + tier) | mặc định |
| `UI-WEB-LEAD-002-T2` | tab | Scoring K1–K12 (knockout, flag, borderline, bypass) | lazy |
| `UI-WEB-LEAD-002-T3` | tab | Gate 1/2 (entry criteria, ký, handoff, activation) | lazy |
| `UI-WEB-LEAD-002-T4` | tab | Timeline + audit chuyển stage | lazy |
| `UI-WEB-LEAD-002-D1` | dialog | Advance stage (+snapshot done criteria) | API-ERP-006 |
| `UI-WEB-LEAD-002-D2` | dialog | Gate Go/No-Go (lý do bắt buộc với No-Go) | API-ERP-008 |
| `UI-WEB-LEAD-002-D3` | dialog | Bổ sung dữ liệu → chấm lại | `[NEEDS_REVIEW]` endpoint |
| `UI-WEB-LEAD-002-D4` | dialog | Phân xử / xác nhận trùng | SM/GDKD |
| `UI-WEB-LEAD-002-S1` | sheet | So sánh lead trùng + bằng chứng | từ banner dedup |
| `UI-WEB-LEAD-002-M1` | mode | View | mặc định |
| `UI-WEB-LEAD-002-M2` | mode | Edit brief/meeting notes | owner |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../../phase2-features` | Upstream |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system | `../../../design-system.md` | Upstream |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | Upstream |
