# Screen Group: Campaign & Deliverable

Implements: FEAT-ERP-CAMP-001, FEAT-ERP-CAMP-002

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `camp`
> **Tính năng:** FEAT-ERP-CAMP-001..002
> **Route:** `/ops/campaigns`
> **Main UI-ID:** `UI-WEB-CAMP-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Workspace | Ops Workspace (`/ops/*`) — worklist vận hành chính của đội sản xuất |
| Đối tượng nghiệp vụ | Campaign + Deliverable + Milestone nghiệm thu + thí nghiệm A/B — machine-state thực thi ở SYS-CORE-BACKEND; WEB render và khóa thao tác theo kết quả service layer |
| Vai trò chính | OPS_AM (lập campaign, đề xuất nghiệm thu, duyệt vượt hạn mức dự án, share portal) · OPS_CONT (thực hiện deliverable được gán) · OPS_PLAN/TL (duyệt vượt hạn mức ngày, duyệt A/B) · OPS_ADS (change ngân sách, đăng ký A/B) · OPS_DES/OPS_EDIT (sản xuất) `[NR #8 Navigation]` |
| Workflow stage | Campaign/Deliverable: `planned → in_flight → delivered → reported` (API-ERP-051); Milestone: `IN_PROGRESS → PENDING_CUSTOMER_CONFIRM → (REMINDED → ESCALATED) → ACCEPTED / REWORK` — nghiệm thu 3 ngày làm việc, nhắc ngày 2, escalate ngày 4, KHÔNG "im lặng = đồng ý" |
| A. Object đang xử lý | Campaign chạy theo WBS sinh từ approved proposal (S13); deliverable từng item có owner OPS_CONT + deadline; milestone chờ khách confirm nghiệm thu trong khung 3 ngày làm việc |
| B. Primary actors | OPS_AM lập/điều phối + nghiệm thu; OPS_CONT/DES/EDIT sản xuất từng deliverable; OPS_ADS vận hành ngân sách + A/B; OPS_PLAN duyệt chiến lược |
| C. Related actors | CUSTOMER (confirm nghiệm thu trên PORTAL/M-PORTAL — không thao tác trên web) · FIN (trạng thái khớp tiền TKQC — read-only qua S9) · SALES (handoff nguồn — S4) |
| D. Lifecycle | Campaign 4 stage; deliverable pipeline chi tiết Ý tưởng → Soạn → Duyệt nội dung → Sản xuất → Duyệt xuất bản → Đã xuất bản, tối đa 3 vòng sửa; milestone 7 trạng thái theo state machine FEAT-ERP-CAMP-001 §6 |
| E. Cross-module | S4 Handoff Bridge (nguồn tạo campaign) · S9 TKQC Registry (accounts chạy campaign + hard stop khớp tiền) · S13 Proposal (WBS gốc) · S15 Capacity (API-ERP-069 trước gán task) · S17 TikTok Monitor (GMV tham chiếu) · S28 Client 360 · P1/P2 Portal (share scope) |
| F. Information needs | Stage + đang chờ ai bao lâu (WaitingOn), tiến độ deliverable, overdue vàng/đỏ + SLA từng bước, đếm ngược nghiệm thu 3 ngày, vòng sửa còn lại (n/3), change log phân bậc duyệt, KPI A/B theo variant |
| G. Decisions cần quyết | Lập campaign; tạo/gán deliverable (sau capacity check); chuyển stage; đề xuất nghiệm thu; duyệt/từ chối change (TL/AM theo bậc); share portal scope; kết luận A/B |
| H. Actions được phép | Theo ma trận phân quyền FEAT-ERP-CAMP-001/002 §4 — nút ẩn khi thiếu quyền (PEP); approver ≠ creator chặn ở API |
| I. Exceptions | Deliverable overdue (vàng = trượt deadline / SLA ≥50%; đỏ = SLA vỡ — nhảy đầu queue) · milestone ESCALATED ngày 4 · change log thiếu reason (bổ sung trong 4h LV) · campaign không gắn dự án (tự pause 4h LV) · GW degraded → nhãn `manual` · hard stop TKQC chưa khớp tiền · A/B overlap segment · vòng sửa thứ 4 chưa escalate |
| J. Cần chuyển màn hình? | Không — 1 surface: worklist trái + Campaign 360 pane phải (W2); link out chỉ khi cần ngữ cảnh module khác (S4/S9/S28/P2) |

---

## 1. TRANG CHÍNH

### 1.1. Layout — Pattern W2 split view (worklist 40% + Campaign 360 pane 60%)

```
┌──────┬──────────────────────────────────────────────────────────────────────────────────────┐
│ Nav  │ Topbar: tìm kiếm toàn cục · bell (drawer) · user                                     │
│ rail ├──────────────────────────────────────────────────────────────────────────────────────┤
│ 60px │ OPS > Campaign & Deliverable                            [+ Lập campaign]             │
│      ├──────────────────────────────────────────────────────────────────────────────────────┤
│      │ CommandBar: [Lưu view ▾] [Nhóm theo stage ▾]        [Tìm nhanh…] [Bộ lọc ▾]         │
│      │ Chips: (Của tôi·12) (In flight·8) (Chờ khách NT·3) (Overdue·4) (SLA vỡ·1 ×) (A/B·2) │
│      ├───────────────────────────────────────┬──────────────────────────────────────────────┤
│      │ DANH SÁCH CAMPAIGN — 40% (compact)    │ CAMPAIGN 360 — 60% (lazy-load khi chọn hàng) │
│      │ ☐ CP-2201 Vitacare TikTok  IN_FLIGHT  │ ┌ Header: CP-2201 · Vitacare · Conversion ⚡  │
│      │    8/12 NL · chờ khách NT · còn 1 ngày│ │ ProgressTracker: planned✓ in_flight● del…  │
│      │ ☐ CP-2190 Nhà sách ABC     DELIVERED  │ │ WaitingOn: chờ khách confirm NT · 2 ngày   │
│      │    12/12 · milestone 2 ESCALATED  ⚠   │ │ Tabs: Tổng quan|Deliverables|Nghiệm thu|   │
│      │ ☐ CP-2185 Ahachoey GMV     PLANNED    │ │        A/B Testing|Change log|Timeline     │
│      │    0/6 · chờ TL duyệt change · 3h     │ │ [Đề xuất NT] [Tạo deliverable] [⋯]         │
│      │ …  row 32px · overdue đỏ nhảy đầu     │ └ (chi tiết từng tab tại §2)                 │
│      ├───────────────────────────────────────┴──────────────────────────────────────────────┤
│      │ Bulk bar (khi chọn ≥1): [Đã chọn 2] [Gán lại owner] [Pause khẩn cấp] [Bỏ chọn]      │
│      │ Pagination 20/50/100 — server-side · Tổng 46 campaign · Đã lọc còn 12               │
└──────┴──────────────────────────────────────────────────────────────────────────────────────┘
```

Chọn hàng **không rời trang** — pane phải load Campaign 360 (lazy-load theo `:id`). Nút "Mở rộng ⤢" trên pane chuyển sang chế độ full-width theo pattern **W3** đúng Navigation (content tabs + panel phải 360px: WaitingOn + ProgressTracker + Timeline 3 dòng; panel collapse được). Tablet ≤1279px: split → master full, pane mở dạng overlay. Mobile <768px: danh sách dạng card + cảnh báo overdue; thao tác tracking chi tiết báo "Mở trên web".

### 1.2. Components

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| DataTable (compact, bulk-selection, saved-views) | row 32px, header 36px sticky, server-side | Keyboard ↑↓/Space/Enter; sort theo click header |
| Quick filter chips | tháo từng chip, đếm theo scope permission | Chip "SLA vỡ" `--state-sla-breach`, tự nhảy đầu danh sách |
| CommandBar | page-level, 1 nút chính [+ Lập campaign] | Action thiếu quyền ẩn (PEP) |
| Split view W2 + mở rộng W3 | `minmax(360px, 40%) 1fr` | Pane giữ context khi chuyển hàng; W3 cho phân tích sâu |
| StatusBadge | 1 badge/hàng (stage) | Trạng thái phụ (ESCALATED, manual) đưa tooltip/cột riêng |
| WaitingOnIndicator | chip trong row + khối header pane | "chờ khách confirm NT · 2 ngày" / "chờ TL duyệt · 3h" |
| WarningIndicator | banner trong pane khi ESCALATED/hard stop | 3 phần: chuyện gì — cần ai làm gì — hạn còn lại |
| ProgressTracker | stepper ngang 4 stage trong header pane | Node hiển thị stage + người giữ + duration |
| Pagination | 20/50/100 server-side | Hiển thị tổng + số bản ghi đã lọc |

### 1.3. Cột hiển thị (list campaigns — R6)

| Cột | Trường | Định dạng | Sort | Ghi chú |
|-----|--------|----------|------|---------|
| Mã + Tên campaign | `campaigns.id`, `name` | Text mono + text | — | Không hiển thị UUID |
| Khách hàng | `customer_id` → tên | Text + link | — | Link mở S28 Client 360 |
| Mục tiêu khách | `objective` | Chip: Conversion / Traffic / Awareness | Có | Nền tảng "báo cáo theo mục tiêu khách" (FEAT-ERP-CAMP-002) |
| Stage | `status` | StatusBadge | Có | planned (draft) · in_flight (info) · delivered (pending — chờ nghiệm thu) · reported (approved) |
| Tiến độ | deliverable done/total | "8/12" `tabular-nums` | Có | Click → tab Deliverables của pane |
| Owner | `owner_id` | Avatar + tên (OPS_AM) | — | Trống + nền đỏ nhạt khi quá SLA gán |
| Đang chờ | waiting-on | WaitingOnIndicator chip | — | Chờ khách confirm NT / chờ TL·AM duyệt change / chờ duyệt A/B |
| Exception | overdue/SLA/escalated | Icon + badge | — | Vàng: trượt deadline hoặc SLA ≥50% (`--state-sla-warning`); đỏ: SLA vỡ/ESCALATED (`--state-sla-breach`); đỏ nhảy đầu queue |
| Ngày kết thúc KH | kế hoạch | Ngày dd/MM | Có | Tooltip: actual khi đã reported |
| Row actions | — | "⋯" | — | Mở 360 · Chuyển stage · Pause khẩn cấp · Reassign |

### 1.4. Quick filters + bộ lọc + quy ước vàng/đỏ

**Quick filter chips mặc định:** `Của tôi` · `Nhóm tôi` (TL) · `In flight` · `Chờ khách nghiệm thu` · `Overdue (vàng)` · `SLA vỡ (đỏ)` · `Chờ tôi duyệt` (TL/AM — change log + A/B) · `A/B đang chạy`. Chip theo phạm vi dữ liệu được phép — OPS_CONT chỉ thấy campaign có deliverable của mình (row-level scoping, CORE enforce).

**Bộ lọc đầy đủ** (khớp API-ERP-049): `status` (4 stage), `customer_id`, `owner_id` + tìm nhanh theo tên/mã `[NEEDS_REVIEW: tham số search/sort/pagination của GET campaigns chưa khai báo trong contract — đề xuất bổ sung]`.

**Quy ước overdue (BR-003/BR-005):** vàng = editorial/deliverable trượt deadline hoặc SLA bước hiện tại đã dùng ≥50% (nhắc TL + AM, AM chủ động cập nhật khách); đỏ = SLA vỡ hoặc chậm 2 bước liên tiếp (tự escalate TL, entry nhảy đầu queue + event `sla.breach`). Nghiệm thu: ngày 2 tự REMINDED (vàng), hết 3 ngày làm việc ESCALATED (đỏ, event `deliverable.acceptance_due`) — không bao giờ tự chuyển ACCEPTED.

### 1.5. States & phân quyền trên surface

- **Loading:** skeleton 10 hàng bảng + skeleton pane; **Empty:** EmptyState "Không có campaign nào khớp bộ lọc" + CTA "Xóa bộ lọc" / "+ Lập campaign" (nếu có quyền); **Error:** hàng lỗi + retry, pane giữ nội dung cũ kèm banner lỗi.
- **Phân quyền:** OPS_AM — full thao tác campaign của khách mình; OPS_PLAN — xem toàn nhóm + duyệt (hàng đợi M4); OPS_CONT/DES/EDIT — xem + thao tác deliverable được gán (các nút lập/duyệt ẩn); OPS_ADS — change ngân sách + A/B; SYS_ADMIN — không quyền nghiệp vụ. OPS_DES/EDIT/ADS hiện ẩn toàn phần menu theo `[NEEDS_REVIEW #8]` Navigation đến khi BOD chốt vai.

---

## 2. TABS — Campaign 360 pane (R7: mỗi tab thiết kế đầy đủ)

Global context (header pane: mã + tên + khách + objective + ProgressTracker 4 stage + WaitingOn + status) **giữ nguyên khi chuyển tab**. Tất cả tab lazy-load; tab có việc chờ user hiển thị count-badge.

### T1 — Tổng quan (`UI-WEB-CAMP-001-T1`)

- **Mục tiêu:** nắm bức tranh campaign trong 10 giây và quyết định việc tiếp theo.
- **Thông tin:** nguồn (link **Handoff** S4 kèm trạng thái ký 2 phía); **TKQC accounts chạy campaign** (danh sách account + platform + trạng thái khớp tiền read-only — đang hard stop thì WarningIndicator banner "TKQC chưa khớp tiền — chi phí chưa được đẩy, mở S9"); ngân sách đã duyệt vs thực tế (MoneyDisplay delta); tiến độ WBS (% node Approved); chỉ số TikTok GMV/settlement nếu campaign thuộc dịch vụ TikTok Shop (API-ERP-054, nhãn `reference_only=true` — tách bạch khỏi doanh thu agency, BR-011); nhãn `manual` khi GW degraded.
- **Components:** DescriptionList 2 cột + ProgressTracker + WarningIndicator + Timeline inline 3 sự kiện cuối.
- **Actions:** Chuyển stage (điều kiện machine-validate, ví dụ delivered yêu cầu 100% milestone ACCEPTED); Pause khẩn cấp (die account/brand safety — pause trước, reason bổ sung trong 4h LV); link **Client 360** (S28) và **Xem góc nhìn khách trên portal** (P2 — hiển thị đúng phần đã share).
- **States/Permissions:** xem theo row-level scope; nút Chuyển stage chỉ OPS_AM; campaign internal non-billable ẩn cột ngân sách khách.
- **Quan hệ tab khác:** tổng hợp số từ T2/T3; chi tiết thay đổi nằm T5.

### T2 — Deliverables (`UI-WEB-CAMP-001-T2`)

- **Mục tiêu:** tracking từng item: ai làm, đến hạn khi nào, đang kẹt bước nào.
- **Thông tin — cột bảng:** Deliverable (tên + kênh) · WBS node ref (bắt buộc — task mồ côi không tồn tại, BR-001) · **Owner (OPS_CONT, avatar)** · **Deadline** (đếm ngược) · Trạng thái pipeline (Ý tưởng → Soạn → Duyệt nội dung → Sản xuất → Duyệt xuất bản → Đã xuất bản) · Vòng sửa **n/3** (vòng 4 bị chặn nếu chưa escalate) · SLA bước hiện tại (AM 2h; video dài 4h; trend gấp 1h; self-QC + Lead review 4h — theo tier × priority) · Overdue vàng/đỏ.
- **View options:** Bảng (mặc định) · **Lịch nội dung** tháng/quý theo kênh phát hành (editorial calendar — badge cảnh báo trượt trên từng ô) `[NEEDS_REVIEW: thiếu endpoint editorial calendar]`.
- **Actions:** [+ Tạo deliverable] (dialog D2 — bulk cho WBS lớn, capacity check bắt buộc trước gán); chuyển pipeline (API-ERP-051); gán lại owner (AssigneePicker theo capacity); mở **S1 Deliverable drawer** khi click dòng.
- **States/Permissions:** OPS_CONT thao tác task được gán; nút duyệt ẩn với chính người tạo (BR-004); reject bắt buộc comment; **Empty:** "Chưa có deliverable — tạo từ WBS của proposal".

### T3 — Nghiệm thu (Milestones) (`UI-WEB-CAMP-001-T3`)

- **Mục tiêu:** điều phối nghiệm thu với khách — biết chính xác ngày nào phải escalate.
- **Thông tin — milestone card:** tên milestone + % WBS node Approved (progress bar; điều kiện đề xuất: 100% Approved nội bộ) · trạng thái (IN_PROGRESS / READY_FOR_ACCEPTANCE / PENDING_CUSTOMER_CONFIRM / REMINDED / ESCALATED / ACCEPTED / REWORK) · **đếm ngược rõ: "còn X ngày Y giờ làm việc" trên 3 ngày** từ `proposed_at`; badge "Đã nhắc khách (ngày 2)"; khi ESCALATED — WarningIndicator banner đỏ "Hết 3 ngày LV không confirm — đã escalate AD ngày 4 · cần AM liên hệ kênh khác và nhập kết quả kèm bằng chứng" (không "im lặng = đồng ý"); phạm vi share portal từng milestone.
- **Actions:** [Đề xuất nghiệm thu] (D3 — vô hiệu + tooltip khi <100%); [Share portal] (D6 — chỉ OPS_AM); [Nhập kết quả] (D5 — sau escalate: ACCEPTED/REWORK + bằng chứng trao đổi); link P2 xem đúng view khách.
- **States/Permissions:** CUSTOMER confirm chỉ trên PORTAL/M-PORTAL (web hiển thị timestamp + audit khi khách confirm); ACCEPTED là trạng thái kết thúc — REWORK mở vòng sửa mới, lịch sử giữ nguyên (append-only). Milestone gắn onboarding hiển thị ràng buộc Gate Day 14.
- **Quan hệ:** khi tất cả milestone ACCEPTED → T1 mở action "Chuyển sang reported + lập báo cáo".

### T4 — A/B Testing (`UI-WEB-CAMP-001-T4`) — FEAT-ERP-CAMP-002

- **Mục tiêu:** thí nghiệm có "giấy phép chạy" rõ ràng; kết luận có evidence, không cảm tính.
- **Thông tin:** danh sách thí nghiệm gắn campaign (giả thuyết · **metric chính duy nhất theo mục tiêu khách** · variant (control bắt buộc) · audience · thời lượng · ngân sách · sample size; trạng thái DRAFT → PENDING_PLAN → ACTIVE → CONCLUDED / NO_SIGNAL / BLOCKED_OVERLAP / REJECTED); dashboard KPI theo variant từ GW (nhãn nguồn `api`/`manual` + timestamp); thanh tiến độ sample so ngưỡng khai thắng **≥20% chênh lệch + ≥50 clicks hoặc ≥10 conversions** — hiển thị khoảng cách còn thiếu; cảnh báo overlap segment (BLOCKED_OVERLAP buộc chọn exclusion hoặc chờ); learning log gắn thí nghiệm; link playbook chiến lược.
- **Actions:** [+ Đăng ký thí nghiệm] (D7 — OPS_ADS; thiếu 1 trong 7 trường không lưu được); Duyệt/Từ chối (OPS_PLAN — từ chối bắt buộc lý do chiến lược); [Kết luận WIN/LOSE] — vô hiệu khi chưa đủ đồng thời 2 ngưỡng (SC-005); NO_SIGNAL tự sinh khi hết duration thiếu sample → chọn gia hạn (change log có reason) hoặc dừng; kết luận trên dữ liệu `manual` bắt buộc ghi nguồn vào evidence.
- **States/Permissions:** xem dashboard: OPS_ADS toàn bộ, OPS_CONT chỉ variant gắn deliverable mình, OPS_AM khách mình, OPS_PLAN toàn nhóm; chi ngân sách chỉ hợp lệ khi ACTIVE (CORE chặn — SC-002). Báo cáo khách không dùng ngôn ngữ cam kết KPI (BR-008). `[NEEDS_REVIEW: thiếu endpoint GET experiments + KPI theo variant + submit kết luận/evidence — contract chỉ có API-ERP-053 POST tạo]`.

### T5 — Change log (`UI-WEB-CAMP-001-T5`)

- **Mục tiêu:** mọi thay đổi chiến dịch để lại dấu vết đối chiếu được với chi tiêu GW.
- **Thông tin — bảng append-only (cấm sửa/xóa mọi role):** thời gian · người changed · trường (ngân sách/bid/target/audience/creative chính) · giá trị cũ → mới · **reason** · bậc duyệt (buyer tự quyết trong hạn mức / chờ TL — vượt hạn mức ngày / chờ AM — vượt hạn mức dự án / đã duyệt) · trạng thái đẩy platform (đã đẩy / **`manual`** khi GW degraded + evidence đính kèm).
- **Actions:** hàng đợi duyệt dạng ApprovalCard cho TL/AM (giá trị cũ/mới + % ngân sách tháng + nút Duyệt/Từ chối có lý do); banner vàng khi có entry khẩn cấp chưa bổ sung reason ("còn 2h/4h LV"); [Thay đổi chiến dịch] mở D4; thay đổi ngân sách phát sinh từ A/B cũng về đây (BR-007).
- **States/Permissions:** OPS_ADS tạo change trong hạn mức; OPS_PLAN duyệt bậc ngày; OPS_AM duyệt bậc dự án; chưa duyệt không đẩy xuống platform. `[NEEDS_REVIEW: thiếu endpoint GET change log entries + submit quyết định duyệt]`.

### T6 — Timeline (`UI-WEB-CAMP-001-T6`)

- **Mục tiêu:** lịch sử đầy đủ để đối chiếu khi tranh chấp với khách hoặc nội bộ.
- **Thông tin:** ActivityFeed full — chuyển stage, nộp/duyệt creative (ai, vòng nào, comment), change log entries, đề xuất/nhắc/escalate nghiệm thu, confirm của khách (timestamp + audit), event hệ thống (GW sync, degraded manual) icon riêng.
- **Actions:** filter theo loại event + actor; click entry → jump đúng tab/đối tượng nguồn. Read-only.
- **States:** loading skeleton 3 dòng; empty "Chưa có hoạt động".

---

## 3. DIALOGS

| # | Dialog | UI-ID | Loại | Mở khi nào |
|---|--------|-------|------|-----------|
| 1 | Lập campaign | `UI-WEB-CAMP-001-D1` | Form | [+ Lập campaign] |
| 2 | Tạo deliverable theo WBS (đơn + bulk) | `UI-WEB-CAMP-001-D2` | Form + capacity check | T2 [+ Tạo deliverable] |
| 3 | Đề xuất nghiệm thu milestone | `UI-WEB-CAMP-001-D3` | Confirm + checklist | T3 [Đề xuất nghiệm thu] |
| 4 | Thay đổi chiến dịch (reason bắt buộc) | `UI-WEB-CAMP-001-D4` | Form | T5 [Thay đổi chiến dịch] / T1 Pause có lý do |
| 5 | Nhập kết quả sau escalate | `UI-WEB-CAMP-001-D5` | Form + upload bằng chứng | T3 (milestone ESCALATED) |
| 6 | Cấu hình share portal | `UI-WEB-CAMP-001-D6` | Form chọn scope | T3 [Share portal] |
| 7 | Đăng ký thí nghiệm A/B | `UI-WEB-CAMP-001-D7` | Form 7 trường | T4 [+ Đăng ký thí nghiệm] |

- **D1 — Lập campaign:** khách hàng* (combobox), handoff nguồn* (chọn từ handoff đã ký 2 phía — link S4), proposal gốc* (WBS sinh theo loại dịch vụ), project type* (Client Billable / Internal Non-billable — BR-001/BR-012), mục tiêu khách* (conversion/traffic/awareness — quyết định cấu trúc KPI báo cáo), TKQC accounts chạy campaign (multi-select từ S9 — account chưa khớp tiền cảnh báo vàng ngay trong dialog), thời gian kế hoạch. Thiếu trường → không lưu (khớp API-ERP-049).
- **D2 — Tạo deliverable:** WBS node* (chỉ node còn trống), tên*, kênh*, deadline*, assignee* — **chọn assignee chạy capacity check tự động (API-ERP-069): vàng >90% phải TL duyệt, đỏ ≥100% chặn cứng với mã lỗi băng màu** (BR-002 — nút gán vô hiệu khi chưa có kết quả); bulk = lặp theo WBS node chọn sẵn, hàng lỗi hiển thị riêng. SLA + vòng sửa kế thừa theo tier khách.
- **D3 — Đề xuất nghiệm thu:** checklist machine-check "100% WBS node Approved" (không đủ → nút vô hiệu, liệt kê node chưa Approved); chọn deliverable share cho khách; xác nhận → milestone chuyển PENDING_CUSTOMER_CONFIRM, đồng hồ 3 ngày LV bắt đầu.
- **D4 — Thay đổi chiến dịch:** trường thay đổi (old hiển thị read-only) + new value + **reason bắt buộc (≥10 ký tự)**; preview bậc duyệt sẽ đến ("trong hạn mức của bạn — áp dụng ngay" / "chờ TL duyệt" / "chờ AM duyệt"); Pause khẩn cấp variant: bỏ reason nhưng sinh task bổ sung trong 4h LV + banner cảnh báo TL.
- **D5 — Nhập kết quả:** ACCEPTED / REWORK* + mô tả liên hệ + đính kèm bằng chứng trao đổi* (bắt buộc — FEAT-ERP-CAMP-001 §5); REWORK tạo vòng sửa mới cho deliverable liên quan, lịch sử giữ nguyên.
- **D6 — Share portal:** checkbox từng milestone/deliverable được khách thấy (mặc định theo D3); cảnh báo "khách không thấy giá vốn, chiết khấu, P&L, ghi chú nội bộ; download có watermark" (BR-010).
- **D7 — Đăng ký A/B:** 7 trường bắt buộc (giả thuyết, metric chính duy nhất theo objective, variant ≥2 có control, audience, thời lượng, ngân sách, sample size dự kiến) — thiếu trường nào chỉ đúng field đó; submit → PENDING_PLAN; nếu trùng segment → BLOCKED_OVERLAP + bắt buộc chọn exclusion hoặc chờ (BR-003).

---

## 4. SHEETS

| # | Sheet | UI-ID | Nội dung | Mở khi nào |
|---|-------|-------|----------|-----------|
| 1 | Deliverable drawer | `UI-WEB-CAMP-001-S1` | Drawer 720px: pipeline 6 bước (ProgressTracker dọc) với SLA đếm ngược từng bước + WaitingOn (chờ ai duyệt, còn bao lâu); nộp bản creative kèm attachment (phiên bản có dấu vết); comment reject các vòng trước; đếm vòng "còn X/3"; nút Duyệt / Request changes (comment bắt buộc) — ẩn với chính người tạo | Click dòng trong T2 |
| 2 | Milestone chờ confirm | `UI-WEB-CAMP-001-S2` | Drawer 480px: đồng hồ 3 ngày LV + mốc nhắc ngày 2 / escalate ngày 4; lịch sử nhắc; nút "Nhắc khách ngoài hệ thống" (ghi log liên hệ); link P2 xem view khách | Click milestone trong T3 |

Ưu tiên drawer để giữ ngữ cảnh worklist (pattern W2) — người xử lý không rời danh sách khi duyệt một deliverable.

---

## 5. VIEW MODES

| Mode | UI-ID | Nội dung | Ai thấy |
|---|---|---|---|
| Xem — Queue của tôi (mặc định) | `UI-WEB-CAMP-001-M1` | Campaign + deliverable trong scope: OPS_CONT (được gán), OPS_AM (khách mình), OPS_PLAN (toàn nhóm) | Mọi vai OPS |
| Xem — Nhóm theo stage | `UI-WEB-CAMP-001-M2` | Group planned / in_flight / delivered / reported kèm count + tiến độ; chọn "Danh sách phẳng" để sort thuần | Mọi vai OPS |
| Xem — Hàng đợi exception | `UI-WEB-CAMP-001-M3` | Filter preserved: overdue vàng/đỏ + SLA vỡ + milestone ESCALATED + change thiếu reason; sort đỏ trước | TL/AM thấy đầy đủ; executor thấy phần mình |
| Chế độ duyệt | `UI-WEB-CAMP-001-M4` | Count-tab "Chờ tôi duyệt": change log vượt hạn mức (TL/AM) + thí nghiệm PENDING_PLAN (OPS_PLAN) — ApprovalCard inline, keyboard A/R | OPS_PLAN · OPS_AM |

Create = Dialog `-D1`; Edit/Nghiệm thu = mode của pane + dialogs; không có trang riêng cho create/approve — đúng nguyên tắc 1 surface đa mode.

---

## 6. API ENDPOINTS

| # | Endpoint | Phương thức | Gắn với | Tham số chính |
|---|----------|------------|---------|---------------|
| 1 | `/api/v1/erp/campaigns` | GET (API-ERP-049) | DataTable chính (server-side) | filter `status, customer_id, owner_id` + `page, page_size` 20/50/100 `[NEEDS_REVIEW: tham số search/sort chưa khai báo trong contract]` |
| 2 | `/api/v1/erp/campaigns` | POST (API-ERP-049) | Dialog `-D1` Lập campaign | body: customer, handoff ref, proposal ref, project type, objective, TKQC account refs, kế hoạch |
| 3 | `/api/v1/erp/campaigns/{id}` | GET (API-ERP-049) | Campaign 360 pane lazy-load | — (header + tổng hợp; chi tiết deliverables/milestones dùng bảng dưới) |
| 4 | `/api/v1/erp/campaigns/{id}/deliverables` | POST (API-ERP-050) | Dialog `-D2` (hỗ trợ bulk) | body: wbs_node_id (bắt buộc — SC-001), name, channel, deadline, assignee; capacity check điều kiện gán |
| 5 | `/api/v1/erp/deliverables/{id}/transitions` | POST (API-ERP-051) | Pipeline deliverable + chuyển stage + Sheet `-S1` | planned→in_flight→delivered→reported; variant A/B `[NEEDS_REVIEW: state chi tiết pipeline 6 bước Ý tưởng→Đã xuất bản chưa 1-1 với contract]`; reject kèm comment bắt buộc |
| 6 | `/api/v1/erp/deliverables/{id}/acceptance` | POST (API-ERP-052) | Dialog `-D3/-D5` + tab T3 | Đề xuất nghiệm thu (điều kiện 100% Approved) + nhập kết quả sau escalate; khung 3 ngày LV — nhắc ngày 2, escalate ngày 4, không "im lặng = đồng ý" |
| 7 | `/api/v1/erp/campaigns/{id}/ab-tests` | POST (API-ERP-053) | Dialog `-D7` Đăng ký A/B | body: hypothesis, primary_kpi, variants (control bắt buộc), audience, duration, budget, sample_size_plan |
| 8 | `/api/v1/erp/capacity` | GET (API-ERP-069) | Dialog `-D2` capacity check trước gán | theo nhân sự/đội: vàng 90%, đỏ 100% |
| 9 | `/api/v1/erp/tiktok-shop/monitor` | GET (API-ERP-054) | Tab T1 — GMV/settlement tham chiếu | `reference_only=true`; nhãn api/manual khi degraded |

**[NEEDS_REVIEW] Nhóm endpoint còn thiếu so với thiết kế (không bịa):** (a) GET danh sách deliverables + milestones theo campaign kèm đồng hồ nghiệm thu; (b) GET change log entries + POST quyết định duyệt phân bậc TL/AM; (c) PUT/POST cấu hình `portal_share_scope`; (d) GET experiments + KPI theo variant + POST kết luận/evidence (chỉ có API-ERP-053 tạo); (e) editorial calendar; (f) nhắc khách / ghi log liên hệ ngoài hệ thống. Cảnh báo tự động (nhắc ngày 2, escalate, `sla.warning`, `sla.breach`, `deliverable.acceptance_due`) là job phía CORE — WEB chỉ hiển thị kết quả.

---

## 7. UI-ID Registry

| UI-ID | Loại | Tên | Ghi chú |
|-------|------|-----|---------|
| `UI-WEB-CAMP-001` | list (worklist + split view W2) | Campaign & Deliverable — trang chính | Route `/ops/campaigns`; mở rộng pane = W3 đúng Navigation |
| `UI-WEB-CAMP-001-T1` | tab | Tổng quan (nguồn handoff, TKQC, ngân sách, GMV tham chiếu) | Lazy-load |
| `UI-WEB-CAMP-001-T2` | tab | Deliverables (bảng + editorial calendar) | Count-badge theo exception |
| `UI-WEB-CAMP-001-T3` | tab | Nghiệm thu (milestones + đếm ngược 3 ngày LV) | FEAT-ERP-CAMP-001 |
| `UI-WEB-CAMP-001-T4` | tab | A/B Testing (đăng ký, dashboard variant, kết luận) | FEAT-ERP-CAMP-002 |
| `UI-WEB-CAMP-001-T5` | tab | Change log (append-only + hàng đợi duyệt) | FEAT-ERP-CAMP-001/002 |
| `UI-WEB-CAMP-001-T6` | tab | Timeline | Read-only |
| `UI-WEB-CAMP-001-D1` | dialog | Lập campaign | API-ERP-049 |
| `UI-WEB-CAMP-001-D2` | dialog | Tạo deliverable theo WBS (capacity check, bulk) | API-ERP-050, API-ERP-069 |
| `UI-WEB-CAMP-001-D3` | dialog | Đề xuất nghiệm thu milestone | API-ERP-052 |
| `UI-WEB-CAMP-001-D4` | dialog | Thay đổi chiến dịch (reason bắt buộc + phân bậc) | Change log BR-007/008 |
| `UI-WEB-CAMP-001-D5` | dialog | Nhập kết quả sau escalate (bằng chứng) | API-ERP-052 |
| `UI-WEB-CAMP-001-D6` | dialog | Cấu hình share portal | BR-010 |
| `UI-WEB-CAMP-001-D7` | dialog | Đăng ký thí nghiệm A/B (7 trường) | API-ERP-053 |
| `UI-WEB-CAMP-001-S1` | sheet | Deliverable drawer (pipeline + SLA + vòng sửa) | API-ERP-051 |
| `UI-WEB-CAMP-001-S2` | sheet | Milestone chờ confirm (đồng hồ 3 ngày) | API-ERP-052 |
| `UI-WEB-CAMP-001-M1` | mode | Queue của tôi | mặc định |
| `UI-WEB-CAMP-001-M2` | mode | Nhóm theo stage | — |
| `UI-WEB-CAMP-001-M3` | mode | Hàng đợi exception (overdue vàng/đỏ + SLA) | `{deliverable_overdue}` |
| `UI-WEB-CAMP-001-M4` | mode | Chế độ duyệt (TL/AM/OPS_PLAN) | — |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../../phase2-features` | Upstream |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system | `../../../design-system.md` | Upstream |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | Upstream |
