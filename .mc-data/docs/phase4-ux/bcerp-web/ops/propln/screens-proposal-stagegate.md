# Screen Group: Proposal Stage-Gate Workspace V6.0

Implements: FEAT-ERP-PROPLN-001

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `propln`
> **Tính năng:** FEAT-ERP-PROPLN-001
> **Route:** `/ops/proposals`
> **Main UI-ID:** `UI-WEB-PROPLN-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| Workspace | Ops Workspace (`/ops/*`) — surface soạn + duyệt stage-gate V6.0 của BPVH |
| Đối tượng nghiệp vụ | Deal/Proposal theo stage-gate V6.0 (machine-state thực thi ở SYS-CORE-BACKEND gate engine) + ProposalRevision + StrategicBrief + WBSNode + ABTest + CampaignChangeLog |
| Vai trò chính | OPS_PLAN (chủ trì tier D/E, duyệt nghiệp vụ, duyệt TP OPS) · OPS_AM (soạn tier B/C, gửi khách, declare winner A/B) |
| Workflow stage | EVALUATION → SECOND_MEETING → PROPOSAL_INTERNAL → REHEARSAL → PROPOSAL v1.0 → PROPOSAL_REVIEW → PITCHING → QUOTATION → NEGOTIATION → WON → DEPLOY (D+0→D+5) → ONGOING; nhánh phụ PAUSED / LOST (tên stage lấy NGUYÊN VĂN từ feature spec §6 — toàn vòng đời 30 stage thuộc policy `stage-gate-lifecycle-v6.md` bảng 2.1, workspace chỉ render đoạn phụ trách EVALUATION → ONGOING) |
| A. Object đang xử lý | Proposal/deal đang chờ gate: checklist done-criteria chưa đủ, chờ duyệt giá, chờ vòng sửa, chờ confirm WON/D+0 |
| B. Primary actors | OPS_PLAN + OPS_AM — soạn, advance gate, quyết định trong thẩm quyền |
| C. Related actors | OPS_CONT/DES/EDIT/ADS (brief + QC + change log hạn mức) · SALES_L4 SM (escalate, confirm WON, đề xuất override) · SALES_L5 GDKD + BOD (duyệt giá/giá cuối/Gross Margin, vượt vòng) · FIN_L1 (confirm tiền → D+0) · SYS_ADMIN (template/định mức/SLA) |
| D. Lifecycle | 12 stage đoạn phụ trách + PAUSED/LOST một chiều; bản ProposalRevision chạy DRAFT → INTERNAL_REVIEW (≤3 vòng) → REHEARSAL_APPROVED → SENT_TO_CLIENT → CLIENT_REVIEW (≤2 vòng tier B/C, ≤4 vòng tier D/E) → FINAL_PITCHED |
| E. Cross-module | Gate engine CORE (hard block tầng API — UI chỉ phản chiếu) · QUOTATION gắn S3 Deal Desk · WON tự sinh dự án → S14 Campaign & Deliverable · capacity check từ CAPTS (S15) · tiền vào + LOI/HĐ từ FIN (S7/S10) · duyệt concept di động M-INT · khách theo dõi PORTAL |
| F. Information needs | Stage hiện tại + gate tiếp theo + criteria còn thiếu (tách máy tự kiểm / phán đoán người), đồng hồ SLA từng gate, vòng sửa còn lại theo tier, đang chờ ai bao lâu, validator định mức trang |
| G. Decisions | Advance gate · duyệt giá sơ bộ/giá cuối/Gross Margin · Request changes · quyết vượt vòng sửa (3 lựa chọn) · PAUSED/LOST (lý do bắt buộc) · Từ chối vận hành Brand Safety · declare winner A/B |
| H. Actions được phép | Soạn/chỉnh proposal theo tier, advance gate, duyệt đa vai (cấm tự duyệt), tạo/điều chỉnh WBS, ghi change log (trong hạn mức), kê khai A/B, gửi proposal v1.0 (duy nhất OPS_AM sau e-approval) |
| I. Exceptions | Brand Safety fail 1/7 → LOST không ngoại lệ · Weighted borderline 3,0–3,49 → hàng đợi thẩm định 4h · chạm trần vòng sửa → chặn + escalate · KH im 3 ngày nhắc / 5 ngày escalate SM · HĐ cảnh báo ngày 3 (≤7 ngày) · AM vắng >4h → backup chain · SLA gate vỡ → tự escalate |
| J. Cần chuyển màn hình? | Không — mọi quyết định gate thực hiện ngay trong pane phải (split view W2 40/60); liên kết sang S14 (campaign), S3 (quotation), S28 (client), S7/S10 (hard stop D+0) khi cần |

---

## 1. TRANG CHÍNH

### 1.1. Layout — Pattern W2 split view (master-detail 40/60)

```
┌──────┬──────────────────────────────────────────────────────────────────────────────────────┐
│ Nav  │ Topbar: tìm kiếm toàn cục · bell (drawer) · user                                      │
│ rail ├──────────────────────────────────────────────────────────────────────────────────────┤
│ 60px │ OPS > Proposal Stage-Gate                  [+ Tạo proposal]  [Chế độ gate review ▾]   │
│      ├──────────────────────────────────────────────────────────────────────────────────────┤
│      │ CommandBar: [Lưu view ▾] [Nhóm theo stage ▾]        [Tìm nhanh…] [Bộ lọc ▾]          │
│      │ Chips: (Của tôi ·12) (Chờ duyệt giá ·3) (SLA vỡ ·1 ×) (Borderline ·2) (Vượt vòng ·1×)│
│      ├────────────────────────────────────┬─────────────────────────────────────────────────┤
│      │ DANH SÁCH PROPOSAL — 40% (compact) │ WORKSPACE DEAL — 60% (lazy-load theo :id)       │
│      │ PR-2210 Cty ABC   REHEARSAL  D     │ PR-2210 · Cty ABC · Tier D · v0.3 · vòng 2/3    │
│      │  ⏱ chờ GDKD duyệt giá · 5h         │ ✓EVALUATION─✓SECOND_MEETING─✓PROPOSAL_INTERNAL  │
│      │ PR-2207 Cty XYZ   EVALUATION C     │ ──●REHEARSAL─○PROPOSAL─○PITCHING─○…─○ONGOING    │
│      │  ⚠ Brand Safety 6/7                │ Gate tiếp theo: REHEARSAL → PROPOSAL v1.0       │
│      │ PR-2195 Cty LMN   WON        E     │ Thiếu: (1) giá cuối chưa duyệt — SALES_L5       │
│      │  ✅ D+0 chờ FIN confirm            │        (2) pitch chưa ghi lần nào               │
│      │ …  row 32px, SLA vỡ tự nhảy đầu    │ Tabs: Gate│Proposal│WBS│A/B & Log│Timeline       │
│      ├────────────────────────────────────┴─────────────────────────────────────────────────┤
│      │ Bulk bar (khi chọn ≥1): [Đã chọn 2]  [Nhắc duyệt giá]  [Bỏ chọn]                     │
│      │ Pagination 20/50/100 — server-side · Tổng 47 proposal · Đã lọc từ 128                 │
└──────┴──────────────────────────────────────────────────────────────────────────────────────┘
```

Chọn hàng trái **không rời trang** — pane phải load workspace của deal (lazy-load). Tablet ≤1279px: pane mở dạng panel overlay; mobile <768px: chỉ xem danh sách dạng card + ProgressTracker compact chip-line (chỉ current + tổng) + cảnh báo SLA — không advance gate trên mobile (advance gate là quyết định desktop; duyệt nhanh concept thuộc M-INT).

### 1.2. Components

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| DataTable (compact, saved-views) | row 32px, header 36px sticky, server-side | Keyboard ↑↓/Space/Enter; sort theo click header |
| Quick filter chips | tháo được từng chip, đếm theo scope | "SLA vỡ" màu `--state-sla-breach` tự nhảy đầu danh sách |
| **ProgressTracker** (stepper ngang) | 12 node đoạn EVALUATION → ONGOING; node 20px, cuộn ngang khi hẹp | Mỗi node: trạng thái + người giữ + ngày chờ (gắn WaitingOnIndicator); node có quyền xem → click mở criteria; `aria-current` cho stage hiện tại; hiển thị rõ **stage hiện tại + gate tiếp theo** |
| ApprovalCard | card duyệt giá/giá cuối/margin: tóm tắt + delta so định mức + SLA còn lại | 2 nút Duyệt (primary) / Từ chối (outline `--color-error`); Từ chối bắt buộc lý do ≥10 ký tự |
| WaitingOnIndicator | chip trong row + khối trong header pane | "chờ GDKD duyệt giá · 5h"; chờ client dùng icon ngoài (KH im 3/5 ngày) |
| WarningIndicator | banner đầu pane cho exception | Brand Safety fail, vượt vòng sửa, HĐ warning ngày 3, override chờ phê duyệt — bắt buộc đủ 3 phần: chuyện gì — ai làm gì — hạn còn lại |
| StatusBadge | 1 badge/hàng (stage) | Token chuẩn: draft/pending/approved/rejected/sla-breach; PAUSED = `--state-manual`, LOST = `--state-rejected` |
| Bulk bar | trượt lên khi chọn ≥1 | Chỉ hiện action theo quyền (nhắc duyệt giá) |

### 1.3. Cột hiển thị

| Cột | Trường | Định dạng | Sort | Ghi chú |
|-----|--------|----------|------|---------|
| Mã proposal | `proposals.id` (mã nghiệp vụ) | Text mono | — | Link mở Client 360 (S28) từ tên khách |
| Khách hàng | `customer_id` → tên + tier | Text + chip tier | — | Tier đọc `qualifiedTier` đã khóa sau Gate 1 — cấm hardcode (BR-004) |
| Stage | `deals.stage` | StatusBadge | Có | Tên stage nguyên văn spec §6 |
| Bản / vòng | `version_no` + `revision_count`/trần tier | "v0.3 · 2/3" `tabular-nums` | Có | Trần: nội bộ ≤3; client B/C ≤2, D/E ≤4; đỏ khi chạm trần |
| Gate tiếp theo | gate kế + % criteria pass | Chip "→ PROPOSAL · 80%" | — | Nút advance nằm trong pane, không trong row |
| Đang chờ ai | waiting-on | WaitingOnIndicator chip | — | Chờ người / chờ client / chờ FIN (D+0) phân biệt icon |
| SLA gate | `sla_clocks` | Đếm giờ làm việc GMT+7 | — | ≥50% → sla-warning; vỡ → sla-breach + chuông |
| Owner | `owner_id` | Avatar + tên | — | AM vắng >4h giờ làm việc → badge backup chain (OPS_PLAN backup #1) |
| Cảnh báo | override / contract / escalate | Icon inline | — | Override knockout chờ GM/BOD duyệt; HĐ cảnh báo ngày 3 |

### 1.4. Quick filters + phân quyền surface

**Quick filter chips mặc định:** `Của tôi` · `Chờ duyệt giá` (e-approval SLA 1 ngày LV) · `Chờ confirm WON/D+0` · `SLA vỡ` · `Borderline 3,0–3,49` (hàng đợi thẩm định 4h) · `Vượt vòng sửa` · `Override chờ phê duyệt` · `Tier D–E`.

**Bộ lọc đầy đủ** (khớp API-ERP-047): `stage`, `owner_id`, `customer_id` + pagination server-side `[NEEDS_REVIEW: contract chưa khai filter tier/search/round — bổ sung khi CORE chốt enum list]`.

**Phân quyền (rút từ ma trận §4 feature spec — áp dụng trên CẢ list lẫn pane):**

| Thành phần | OPS_AM | OPS_PLAN | CONT/DES/EDIT/ADS | SALES_L4 | SALES_L5 | FIN_L1 | BOD | SYS_ADMIN |
|---|---|---|---|---|---|---|---|---|
| Xem | deal phụ trách | deal phụ trách + tất cả | deal phụ trách | tất cả | tất cả | deal phụ trách | tất cả | tất cả |
| + Tạo proposal / soạn / chỉnh | ✅ (tier B/C) | ✅ (chủ trì D/E) | ẩn | ẩn | ẩn | ẩn | ẩn | ẩn |
| Request changes + comment | ✅ | ✅ | ✅ (feedback) | ẩn | ẩn | ẩn | ẩn | ẩn |
| Duyệt giá sơ bộ/giá cuối/Gross Margin | ẩn | ẩn | ẩn | ẩn | ✅ | ẩn | ✅ | ẩn |
| Gửi proposal v1.0 cho khách | ✅ (sau duyệt) | ẩn | ẩn | ẩn | ẩn | ẩn | ẩn | ẩn |
| Quyết vượt vòng sửa | ẩn | ẩn | ẩn | ẩn | ✅ | ẩn | ✅ | ẩn |
| WBS tạo/điều chỉnh | ✅ | ✅ | ẩn | ẩn | ẩn | ẩn | ẩn | ẩn |
| Kê khai A/B · Declare winner | ✅ / ✅ | ẩn | ✅ / ẩn | ẩn | ẩn | ẩn | ẩn | ẩn |
| Change log trong hạn mức | ✅ | ✅ | ✅ | ẩn | ẩn | ẩn | ẩn | ẩn |
| Từ chối vận hành (đề xuất / duyệt TP) | đề xuất | duyệt | ẩn | ẩn | ẩn | ẩn | ẩn | oversight |
| Confirm tiền + LOI/HĐ → D+0 | ẩn | ẩn | ẩn | ẩn | ẩn | ✅ | ẩn | ẩn |
| Override knockout (đề xuất / duyệt lại) | ẩn | ẩn | ẩn | đề xuất | ẩn | ẩn | duyệt lại | ẩn |
| Cấu hình template/định mức/SLA | ẩn | ẩn | ẩn | ẩn | ẩn | ẩn | ẩn | ✅ |

Action thiếu quyền **ẩn** (không disabled) theo mô hình PEP. Không tách màn hình theo role — 1 surface, permission quyết định nút nào hiện.

**States:** loading = skeleton 10 hàng + skeleton pane; empty = EmptyState "Không có proposal nào khớp bộ lọc" + CTA "Tạo proposal" (nếu có quyền); error = hàng lỗi + retry, pane giữ nội dung cũ kèm banner lỗi.

---

## 2. TABS

Tabs nằm trong pane phải (global context deal giữ nguyên ở header pane khi chuyển tab). Lazy-load từng tab, secondary data theo yêu cầu.

### Tab T1 — Gate & Tiến trình (mặc định)

- **Mục tiêu:** trả lời "đang stage nào, gate tiếp theo chặn ở đâu, thiếu gì, chờ ai".
- **Thông tin:** ProgressTracker 12 node; khối **gate tiếp theo** liệt kê done-criteria từng mục, tách 2 nhóm đúng BR-001: *hệ thống tự kiểm* (validation, % checklist, Weighted, e-approval, SLA — hiển thị pass/fail tức thời) và *thuần phán đoán con người* (bắt buộc có bản ghi — evidence_ref); đồng hồ SLA từng gate; Brand Safety 7 tiêu chí + điểm Weighted 9 tiêu chí (borderline 3,0–3,49 → banner hàng đợi thẩm định 4h, người thẩm định do SM chỉ định, kết luận bắt buộc kèm lý do); escalation đã kích hoạt.
- **Components:** ProgressTracker, WarningIndicator (banner), checklist machine-checkable với evidence link, ApprovalCard cho duyệt giá, nút advance.
- **Actions — BẢNG QUYẾT ĐỊNH GATE (ai được duyệt, từ chối ra sao):**

| Gate / quyết định | Ai duyệt | Điều kiện | Khi từ chối / fail |
|---|---|---|---|
| EVALUATION pass | Hệ thống (machine) | Brand Safety 7/7 + Weighted ≥3,5 + 2 meeting đủ 5 output | Fail 1/7 → LOST chủ động, **không có nút ngoại lệ**; borderline → thẩm định 4h |
| SECOND_MEETING → PROPOSAL_INTERNAL | OPS_AM | Strategic Brief 16 sections ≥80% + notes + 5 output | Nút khóa, hiển thị mục thiếu |
| Giá sơ bộ / giá cuối / Gross Margin (e-approval SLA 1 ngày LV) | SALES_L5 (GDKD) hoặc BOD | Trước Rehearsal (sơ bộ), tại Rehearsal (cuối + điều khoản) | Từ chối bắt buộc lý do ≥10 ký tự; quá SLA tự escalate |
| REHEARSAL → PROPOSAL v1.0 | OPS_AM | Pitch ≥1 lần (ghi hệ thống) + giá cuối đã duyệt + v1.0 link + Q&A script | Chưa đạt → lùi PROPOSAL_INTERNAL sửa v0.x (duy nhất nhánh được lùi, trong trần 3 vòng, ghi audit) |
| Gửi khách (PROPOSAL → PROPOSAL_REVIEW) | OPS_AM duy nhất | E-approval đủ + gửi ≤1 ngày sau Rehearsal | Thiếu duyệt → API từ chối + khóa nút (SC-004) |
| Vòng sửa mới (Request changes) | OPS_AM / reviewer | Comment bắt buộc; trong trần tier (nội bộ ≤3, client B/C ≤2, D/E ≤4) | Chạm trần → chặn + mở escalation `-D4` |
| QUOTATION → NEGOTIATION | SALES_L5/BOD duyệt margin + FIN_L1 tính giá | Giá theo định mức; duyệt trước gửi; SLA 2 ngày | Từ chối → quotation ở S3, hiển thị trạng thái |
| NEGOTIATION → WON | OPS_AM + SM (SALES_L4) xác nhận | HĐ/LOI ký 2 bên + reporting frequency; cập nhật 24h | WON một chiều — không revert |
| WON → DEPLOY (D+0) | FIN_L1 (tiền vào + confirm 4h LV + LOI/HĐ) + OPS_AM (capacity) + hệ thống | Đủ điều kiện D+0 | Thiếu → mốc hiển thị "bị chặn" + lý do cụ thể |
| PAUSED / LOST | OPS_AM đề xuất + SM/AD duyệt | Lý do bắt buộc; PAUSED review 2 tuần/lần, 60 ngày im → LOST nhóm A | Ghi 24h, lý do theo enum `[KXN-21]` |
| Override knockout K1–K5 | SM đề xuất + GM/BOD phê duyệt lại | Lý do văn bản + log bất biến | Thiếu chữ ký → "override chờ phê duyệt", không hiệu lực |
| Từ chối vận hành Brand Safety | OPS_AM/OPS_PLAN đề xuất → legal-expert xác nhận + OPS_PLAN (TP OPS) duyệt 24h | Khách đang vi phạm 1/7 tiêu chí | Khóa trạng thái HĐ + notify legal + ops |

- **States:** gate mở (nút advance enable khi 100% criteria pass — hệ thống tự validate qua API-ERP-048 trước khi cho chuyển); gate khóa (nút vô hiệu + liệt kê mục thiếu — SC-001/002/004); gate chờ người (WaitingOn); escalate (banner đỏ). Nỗ lực advance khi thiếu criteria → API từ chối + ghi audit (BR-001).
- **Quan hệ tab khác:** criteria "bản proposal đúng định mức" dẫn sang T2; WBS/capacity sang T3; bằng chứng lịch sử sang T5.

### Tab T2 — Proposal (soạn & vòng sửa)

- **Mục tiêu:** soạn proposal đúng định mức tier ngay từ bản đầu, vòng sửa có kỷ luật.
- **Thông tin:** editor soạn từ **template theo `qualifiedTier`** (B/C: 8–12 trang, OPS_AM soạn; D/E: 15–25 trang, OPS_PLAN chủ trì; tier E tự thêm section Team Bios + bảo mật dữ liệu + Brand Safety + rà soát điều khoản HĐ, validator tính vào hạn mức mở rộng); **validator đếm trang** realtime — lệch định mức → nút gửi/gửi duyệt khóa + báo lỗi cụ thể (SC-002); Strategic Brief 16 sections với completion % (done ≥80%); vòng sửa: version timeline DRAFT → INTERNAL_REVIEW → REHEARSAL_APPROVED → SENT_TO_CLIENT → CLIENT_REVIEW → FINAL_PITCHED, mỗi vòng hiển thị reviewer + comment bắt buộc + số vòng còn lại; feedback KH qua Zalo/Email bắt buộc nhập lại kèm dẫn chứng gốc — chưa nhập không tính vòng (BR-002).
- **Components:** editor + validator banner, ProgressTracker thu gọn cho version lifecycle, comment thread mỗi vòng, AssigneePicker (chọn reviewer).
- **Actions:** lưu nháp, gửi duyệt nội bộ, Request changes (`-D3`), nhập feedback ngoài hệ thống, gửi khách (chỉ OPS_AM, nút ẩn cho vai khác, khóa khi thiếu e-approval hoặc sai định mức).
- **States:** draft / đang review (khóa chỉnh, hiện comment) / approved / sent; chạm trần vòng → toàn khối "tạo vòng mới" khóa + banner escalation.
- **Permissions:** soạn/chỉnh AM + PLAN; CONT/DES/EDIT/ADS chỉ feedback; duyệt giá là ApprovalCard ở T1 (không trộn vào editor).
- **Quan hệ:** gate giá sơ bộ/giá cuối ở T1 điều kiện mở sent; phiên bản gửi khách khớp QUOTATION ở S3.

### Tab T3 — WBS & Triển khai (mở đầy đủ sau WON)

- **Mục tiêu:** điều phối WBS sinh từ approved proposal sau WON + timeline D+0 → D+5.
- **Thông tin:** WBS tree — mỗi deliverable map ≥1 node (node mồ côi cảnh báo — task không gắn node không tính công); dependency mặc định finish-to-start, overlap phải duyệt có lý do; project_type (Khách hàng/Nội bộ) khóa tập nhãn timesheet; capacity check từng gán (kết quả check từ REQ-OPS-007 — không tính lại tại đây); hàng đợi duyệt creative đa vai: OPS_CONT → OPS_DES/OPS_EDIT → OPS_PLAN/OPS_AM, SLA từng bước (OPS_AM 2h, video dài 4h, trend gấp 1h; content self-QC + Lead review 4h), cấm tự duyệt (approver ≠ creator — SC-005), tối đa 3 vòng sửa/deliverable, vòng 4 escalate AM/TL chốt phạm vi bằng văn bản; timeline D+0 (Planning TT→ĐH→AD trong ngày) → D+1/D+2 kick-off nội bộ không lùi → D+3 khách ký 6 Communication Rules → D+5 ONGOING; mốc bị chặn hiển thị + lý do (BR-011).
- **Components:** tree table WBS, AssigneePicker, ApprovalCard duyệt creative, timeline ngang D+0→D+5 với trạng thái từng mốc.
- **States:** trước WON tab hiển thị preview mờ + banner "WBS mở sau khi WON"; gán vượt capacity → chặn tầng API, UI báo trước.
- **Permissions:** WBS AM + PLAN; duyệt creative AM + PLAN (ẩn với CONT/DES/EDIT); deliverable lifecycle chi tiết nằm ở S14 Campaign & Deliverable — tab này chỉ điều phối + duyệt.
- **Quan hệ:** WON tại T1 mở tab này; task gán sang CAPTS; campaign chạy thật sang S14.

### Tab T4 — A/B test & Change log

- **Mục tiêu:** thay đổi chiến dịch truy vết 100%, quyết định A/B theo ngưỡng thống kê.
- **Thông tin:** bảng A/B test — variable (1 variable/test), ngày chạy (2–7 ngày), budget ratio ≥2–3× CPL target/ngày/ad set, sample clicks/conversions, lift %; **cảnh báo chưa đủ sample**: winner chỉ declare khi ≥50 clicks HOẶC ≥10 conversions và chênh ≥20% (SC-007); quá 7 ngày chưa đủ sample → cảnh báo quyết gia hạn/dừng; change log append-only — mọi dòng: field, giá trị cũ → mới, reason, actor, approval_level (phân bậc: OPS_ADS trong hạn mức ngày do TL cấu hình → vượt ngày → OPS_PLAN, vượt dự án → OPS_AM), timestamp; khẩn cấp pause trước — bổ sung reason trong 4h làm việc, quá 4h escalate.
- **Components:** DataTable change log (chỉ đọc, filter theo campaign/field), dialog ghi change log `-D7`, thẻ A/B với nút declare.
- **Actions:** kê khai A/B (`-D7` variant A/B), declare winner (duy nhất OPS_AM, hệ thống chặn khi thiếu sample), ghi change log bắt buộc reason; tắt toàn bộ campaign là quyền AM, OPS_ADS chỉ tắt ad set đơn lẻ.
- **States:** thiếu reason → submit bị chặn với lỗi cụ thể (SC-006); dòng khẩn cấp chưa có reason sau 4h → WarningIndicator escalate.
- **Permissions:** kê khai AM + ADS; declare AM; change log AM/PLAN/ADS trong hạn mức; duyệt vượt hạn mức PLAN (ngày) / AM (dự án).
- **Quan hệ:** change log gắn campaign sinh từ dự án ở T3; winner ghi evidence vào change log.

### Tab T5 — Timeline & Audit

- **Mục tiêu:** nguồn sự thật lịch sử — "Không ghi nhận vào PMS = Không tồn tại" (BR-002).
- **Thông tin:** ActivityFeed bất biến: mọi chuyển stage, override, escalation, vòng sửa, quyết định gate — ai, khi nào (dd/MM HH:mm GMT+7), giá trị cũ/mới; lịch sử ProposalRevision đầy đủ; attempt bị chặn (thiếu criteria, tự duyệt) cũng ghi audit; LOST ghi trong 24h kèm nhóm LOST A/B/C/D.
- **Components:** Timeline full, filter theo loại event, link object nguồn.
- **Actions:** chỉ đọc; export không tại đây (audit export thuộc S25).
- **Permissions:** xem theo data-scope; không có vai nào sửa/xóa (append-only).
- **Quan hệ:** bằng chứng cho mọi quyết định ở T1–T4; audit trail hệ thống chi tiết ở S25.

---

## 3. DIALOGS

| # | Dialog | UI-ID | Loại | Mở khi nào |
|---|--------|-------|------|-----------|
| 1 | Tạo proposal từ template | `UI-WEB-PROPLN-001-D1` | Form | Nút "+ Tạo proposal" |
| 2 | Advance gate (confirm chuyển stage) | `UI-WEB-PROPLN-001-D2` | Confirm + evidence | Nút advance ở T1 |
| 3 | Request changes (vòng sửa mới) | `UI-WEB-PROPLN-001-D3` | Form | Nút "Request changes" ở T2 |
| 4 | Escalation vượt vòng sửa | `UI-WEB-PROPLN-001-D4` | Decision | Banner khi chạm trần vòng |
| 5 | Tạm dừng / LOST | `UI-WEB-PROPLN-001-D5` | Confirm + lý do | Row/pane action "PAUSED/LOST" |
| 6 | Từ chối vận hành (Brand Safety) | `UI-WEB-PROPLN-001-D6` | Form đa bước | Row/pane action "Từ chối vận hành" |
| 7 | Ghi change log / kê khai A/B | `UI-WEB-PROPLN-001-D7` | Form | Tab T4 |

**D1 — Tạo proposal:** chọn deal (combobox theo scope) → hệ thống đọc `qualifiedTier` đã khóa (hiển thị readonly, cấm sửa tay — BR-004) → chọn template đúng tier (D/E hiện template chiến lược; tier E tự thêm Team Bios). Sai vai soạn theo tier (AM soạn D/E) → cho tạo nhưng cảnh báo "lệch quy trình" + ghi log (BR-004).

**D2 — Advance gate:** tóm tắt stage hiện tại → mục tiêu `to_stage` → danh sách criteria kèm trạng thái pass/fail; hệ thống đã tự validate — thiếu bất kỳ mục nào nút confirm **vô hiệu kèm lý do từng mục** (không confirm-empty); trường `criteria_evidence` tự đi từ checklist, mục phán đoán con người bắt buộc đính evidence_ref. Lỗi API → toast lỗi + giữ dialog; nỗ lực bị chặn ghi audit (BR-001).

**D3 — Request changes:** comment **bắt buộc** (≥10 ký tự), chọn vòng (nội bộ/client), hiển thị "còn X/trần Y vòng theo tier"; trần đã đủ → dialog tự chuyển thành `-D4`.

**D4 — Escalation vượt vòng:** 3 lựa chọn đúng BR-005 — (1) chốt gửi bản hiện có, (2) gia hạn có lý do (tối đa 1 lần/proposal, GM duyệt, log bất biến), (3) dừng deal; người quyết: SALES_L5/BOD (nút ẩn với vai khác);AM + Planner + người duyệt giá thấy khối họp nhanh "chọn version tốt nhất vào Rehearsal".

**D5 — PAUSED/LOST:** lý do bắt buộc (LOST theo enum đề xuất `[KXN-21]`, nhóm LOST A/B/C/D); cảnh báo một chiều (WON/LOST không revert; LOST chỉ tái kích hoạt qua nurture/re-qualify riêng); PAUSED nhắc review 2 tuần/lần, 60 ngày im → LOST nhóm A; khách tái ký (parentProjectId) → checklist rút gọn nhưng Gate 1/2 vẫn bắt buộc (BR-013).

**D6 — Từ chối vận hành:** 2 bước — (1) mô tả vi phạm + bằng chứng, legal-expert xác nhận; (2) OPS_PLAN (TP OPS) duyệt trong 24h → khóa trạng thái HĐ + notify legal + ops; SYS_ADMIN oversight. Đơn chờ duyệt hiển thị "override/đình chỉ chờ phê duyệt" trên hàng.

**D7 — Change log / A/B:** field thay đổi (select), giá trị cũ (readonly), giá trị mới, **reason bắt buộc**; kê khai A/B: variable (1), start/end (2–7 ngày, cảnh báo ngoài biên), budget ratio (cảnh báo <2× CPL), mục tiêu; submit thiếu reason/sample → chặn kèm lỗi cụ thể (SC-006/007).

---

## 4. SHEETS

| # | Sheet | UI-ID | Mở khi nào |
|---|-------|-------|-----------|
| 1 | Chi tiết gate criteria + bằng chứng | `UI-WEB-PROPLN-001-S1` | Click node ProgressTracker / chip "% criteria" |
| 2 | Xem trước proposal + kết quả validator | `UI-WEB-PROPLN-001-S2` | Nút "Xem trước" ở T2 |

**S1:** panel phải 480px liệt kê toàn bộ criteria của gate được chọn — nhóm *hệ thống tự kiểm* (icon gear, trạng thái live) và *phán đoán con người* (icon người, evidence_ref link); ai checked, lúc nào (GateCriteriaCheck bất biến); SLA của gate + escalate đã kích hoạt. Giữ context worklist, Esc đóng, focus trả về hàng vừa mở.

**S2:** panel 720px render bản proposal (định mức trang hiện tại/trần theo tier, kết quả validator từng section, section thiếu theo Strategic Brief 16 phần); không cho chỉnh trong sheet — chỉnh ở T2.

Không dùng sheet cho duyệt giá — quyết định tài chính nằm ở ApprovalCard trong T1 (gần ngữ cảnh gate), đúng nguyên tắc đặt action gần điểm quyết định.

---

## 5. VIEW MODES

| Mode | UI-ID | Nội dung | Ai thấy |
|---|---|---|---|
| Xem — Worklist của tôi (mặc định) | `UI-WEB-PROPLN-001-M1` | Queue proposal mình sở hữu/phụ trách, mọi stage; chips mặc định "Của tôi" | OPS_AM, OPS_PLAN, CONT/DES/EDIT/ADS, FIN_L1 |
| Gate review mode | `UI-WEB-PROPLN-001-M2` | T1 phóng to làm bề mặt chính: danh sách lọc "Chờ duyệt giá / Chờ gate", ApprovalCard inline, keyboard A duyệt / R từ chối / Enter mở context | SALES_L5, BOD (duyệt giá) · OPS_PLAN (duyệt TP, thẩm định) · SM (WON, override) · FIN_L1 (D+0) |
| Soạn mode | `UI-WEB-PROPLN-001-M3` | T2 editor full-width (editor tối đa diện tích, list thu thành rail trái hẹp) | OPS_AM, OPS_PLAN |
| Xem — Tổng quan tất cả | `UI-WEB-PROPLN-001-M4` | Toàn bộ proposal kèm "Nhóm theo stage" + conversion giữa stage; read-only trừ nút đúng vai | OPS_PLAN, SALES_L4, SALES_L5, BOD, SYS_ADMIN |

Create/Edit/Review/Approve là MODES của cùng surface (không tách page). Chuyển mode không mất global context (header deal + ProgressTracker luôn hiển thị).

---

## 6. API ENDPOINTS

| # | Endpoint | Phương thức | Gắn với | Tham số chính |
|---|----------|------------|---------|---------------|
| 1 | `/api/v1/erp/proposals` | GET (API-ERP-047) | DataTable chính (server-side) | filter `stage, owner_id, customer_id`; `page, page_size` 20/50/100 `[NEEDS_REVIEW: contract chưa khai filter tier/search/vòng — cần bổ sung cho chips "Tier D–E", tìm nhanh]` |
| 2 | `/api/v1/erp/proposals/{id}` | GET (API-ERP-047) | Pane phải lazy-load khi chọn hàng | stage machine-state, tier, version/vòng, waiting-on `[NEEDS_REVIEW: chi tiết checklist GateCriteriaCheck + StrategicBrief + ProposalRevision chưa liệt kê trong contract — giả định gộp trong detail response, xác nhận với P3]` |
| 3 | `/api/v1/erp/proposals` | POST (API-ERP-047) | Dialog `-D1` Tạo proposal | body: deal_id, template theo `qualifiedTier`; sai định mức/vai → lỗi cụ thể (BR-004) |
| 4 | `/api/v1/erp/proposals/{id}` | POST (API-ERP-047 — CRUD) | Lưu nháp/chỉnh nội dung v0.x ở T2 | `[NEEDS_REVIEW: contract khai POST/GET — method cập nhật (PUT/PATCH) chưa tường minh]` |
| 5 | `/api/v1/erp/proposals/{id}/stage-transitions` | POST (API-ERP-048) | Dialog `-D2` advance gate + mọi quyết định gate (PAUSED/LOST, WON confirm, D+0) | body `{ "to_stage": string, "criteria_evidence": object }`; thiếu criteria → 4xx liệt kê mục thiếu + audit; contract giữ generic — tên stage theo feature spec §6 `[NEEDS_REVIEW: enum đủ 30 stage thuộc policy stage-gate-lifecycle-v6.md, CORE chốt khi implement]` |
| 6 | `/api/v1/erp/campaigns/{id}/ab-tests` | POST (API-ERP-053) | Dialog `-D7` kê khai A/B ở T4 | variable, start/end, budget ratio `[NEEDS_REVIEW: contract ghi permission OPS_CONT, feature spec §4 quy OPS_ADS/OPS_AM kê khai — lệch nguồn, chốt lại; declare winner chưa có endpoint]` |
| 7 | `/api/v1/erp/campaigns/{id}/deliverables` | POST (API-ERP-050) | T3 sinh deliverable theo WBS node (bulk) | redirect sâu sang S14 sau tạo |
| 8 | `/api/v1/erp/quotations` + `/{id}/transitions` | GET/POST (API-ERP-010/011/012) | Stage QUOTATION → NEGOTIATION (margin duyệt) | quotation gắn proposal đã duyệt; bề mặt chính ở S3 Deal Desk — T1 chỉ hiển thị trạng thái + link |

**Chức năng chưa có endpoint trong api-contract — KHÔNG bịa, đánh [NEEDS_REVIEW]:**
- Request changes / đếm vòng (ProposalRevision + comment bắt buộc) — giả định nằm trong POST #4, cần endpoint tường minh.
- E-approval duyệt giá sơ bộ/giá cuối/Gross Margin trên **web** (SALES_L5/BOD) — inbox duyệt MBI (`/api/v1/mbi/approvals*`) bị chặn trên web (mobile-only); cần endpoint web hoặc mở rộng inbox.
- WBS node CRUD + capacity check (API-ERP-050 chỉ tạo deliverable).
- CampaignChangeLog (append-only, reason, approval_level) — chỉ có tạo A/B test, thiếu endpoint ghi/đọc change log.
- Escalate/nhắc (SLA gate, KH im 3/5 ngày, AM vắng) — kỳ vọng qua SLANOT, chưa thấy endpoint.
- Đếm quick chips / thống kê funnel stage — tính client-side từ GET list trang hiện tại, không tuyên bố là số toàn cục.

---

## 7. UI-ID Registry

| UI-ID | Loại | Tên | Ghi chú |
|-------|------|-----|---------|
| `UI-WEB-PROPLN-001` | list (worklist + split view) | Proposal Stage-Gate Workspace — trang chính | Route `/ops/proposals`; pattern W2 40/60; main UI-ID khớp Navigation |
| `UI-WEB-PROPLN-001-T1` | tab | Gate & Tiến trình (ProgressTracker + quyết định gate) | mặc định |
| `UI-WEB-PROPLN-001-T2` | tab | Proposal (soạn & vòng sửa + validator) | lazy-load |
| `UI-WEB-PROPLN-001-T3` | tab | WBS & Triển khai (D+0→D+5, duyệt creative) | mở đầy đủ sau WON |
| `UI-WEB-PROPLN-001-T4` | tab | A/B test & Change log | append-only |
| `UI-WEB-PROPLN-001-T5` | tab | Timeline & Audit | append-only |
| `UI-WEB-PROPLN-001-D1` | dialog | Tạo proposal từ template theo tier | API-ERP-047 |
| `UI-WEB-PROPLN-001-D2` | dialog | Advance gate (criteria_evidence) | API-ERP-048 |
| `UI-WEB-PROPLN-001-D3` | dialog | Request changes (comment bắt buộc) | `[NEEDS_REVIEW: thiếu endpoint]` |
| `UI-WEB-PROPLN-001-D4` | dialog | Escalation vượt vòng sửa (3 lựa chọn) | SALES_L5/BOD |
| `UI-WEB-PROPLN-001-D5` | dialog | Tạm dừng / LOST (lý do bắt buộc) | API-ERP-048 |
| `UI-WEB-PROPLN-001-D6` | dialog | Từ chối vận hành (Brand Safety, 2 bước) | legal + TP OPS 24h |
| `UI-WEB-PROPLN-001-D7` | dialog | Ghi change log / kê khai A/B | API-ERP-053 `[NEEDS_REVIEW: change log]` |
| `UI-WEB-PROPLN-001-S1` | sheet | Chi tiết gate criteria + bằng chứng | click node ProgressTracker |
| `UI-WEB-PROPLN-001-S2` | sheet | Xem trước proposal + validator | 720px |
| `UI-WEB-PROPLN-001-M1` | mode | Worklist của tôi (mặc định) | mọi vai OPS |
| `UI-WEB-PROPLN-001-M2` | mode | Gate review mode | SALES_L5/BOD/OPS_PLAN/SM/FIN_L1 |
| `UI-WEB-PROPLN-001-M3` | mode | Soạn mode (editor full-width) | OPS_AM/OPS_PLAN |
| `UI-WEB-PROPLN-001-M4` | mode | Tổng quan tất cả (Nhóm theo stage) | OPS_PLAN+ |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng nghiệp vụ | `../../../../phase2-features` | Upstream |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system | `../../../design-system.md` | Upstream |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | Upstream |
