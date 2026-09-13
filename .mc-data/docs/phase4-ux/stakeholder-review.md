# Stakeholder Review — Phase 4 UX Design

> **Dự án:** BCERP | **Skill:** wf-design-ux v4.1.0 | **Session:** 20260913-080222-df29
> **Ngày review:** 13/09/2026 10:42
>
> READS: `design-system.md`, `*/Navigation-*.md`, `*/*/screens-*.md`, `phase2-features/`, `P3-01-architecture.md`, `workflow-context.md`
> USED BY: `phase5-implementation/`, `/wf-plan-modules`

---

## Phần A: Dashboard & Trạng Thái

### A.1. Trạng Thái Tài Liệu Đầu Vào

| Tài liệu | Trạng thái | Ghi chú |
|---|---|---|
| design-system.md | ✅ Hoàn thành | 8 sections + §8.1 a11y audit fixes |
| Navigation-bcerp-web.md | ✅ Hoàn thành | 25 surfaces, 6 workspaces (tại thời điểm review; R2 13/09 sau review: 7 workspaces — tách Settings + bổ sung §1.0 Workspace Map), merge ux-architect §4.5 |
| Navigation-portal-web.md | ✅ Hoàn thành | 4 surfaces + bảo mật UI |
| Navigation-mobile-internal.md | ✅ Hoàn thành | 5 surfaces ESS; M6 [NEEDS_REVIEW] |
| Navigation-mobile-portal.md | ✅ Hoàn thành | 5 surfaces mirror portal |
| Screen group specs | ✅ 39/39 files | 413 UI-ID unique, 22 lanes |
| workflow-context.md | ✅ | 34 surfaces consolidated, 5 sections Step 2.0 |

### A.2. Trạng Thái Review

| Hạng mục | Giá trị |
|---|---|
| Systems reviewed | SYS-BCERP-WEB, SYS-PORTAL-WEB, SYS-MOBILE-INTERNAL, SYS-MOBILE-PORTAL |
| Files reviewed | 44 UX docs + workflow-context + cross-validation-report |
| Reviewers | ux-designer (Phần B+C), architect (Phần D), accessibility-auditor (Phase 4.8) |

### A.3. Tổng Hợp Vấn Đề & Hành Động

| Severity | Tổng | RESOLVED | FIXABLE→FIXED | DEFERRED | PENDING |
|---|---|---|---|---|---|
| Critical | 0 | — | — | — | 0 |
| High | 4 | 2 (Phase 4.8 a11y High; F-C-04 role taxonomy) | 2 (F-D-01 Gate surface → S17 T2; F-D-05 Deal Desk cross-module panel) | 1 (F-D-02 mobile MBI push targets) | 0 |
| Medium | 12 | 8 (Phase 4.8) | — | 4 | 0 |
| Low | 11 | 2 | — | 9 | 0 |

> Ghi chú đếm: 4 High = F-C-04 (B+C), F-D-01, F-D-02, F-D-05 (D). F-C-04 + a11y High được coi RESOLVED sau fix; F-D-01/F-D-05 FIXED bằng bổ sung surface/panel; F-D-02 DEFERRED có [NEEDS_REVIEW] đề xuất.

### A.4. Xác Nhận Phase 4 Hoàn Thành

| Điều kiện | Trạng thái |
|---|---|
| Cross-validation 13/13 checks | ✅ PASS (cross-validation-report.md) |
| Zero Critical/High PENDING | ✅ (tất cả RESOLVED/FIXED/DEFERRED) |
| Mọi screen có justification | ✅ (4.11) |
| Traceability R12 | ✅ 38/38 → 39/39 sau F-D-01 (S17 T2) |

**STATUS: APPROVED_WITH_CONDITIONS** — điều kiện: danh sách DEFERRED (~70 [NEEDS_REVIEW] endpoint/role gap + 13 DEFERRED /wf-design + F-D-02 mobile push targets) chuyển cho `/wf-plan-modules` xử lý.

---

# Stakeholder Review — Phần B (SO-01 UX Cross-Review) + Phần C (SO-02 Consistency Check)

> UX-designer (P5-A) | Session `20260913-080222-df29` | 13/09/2026
> Nguồn: cross-validation-report.md (Phase 4 PASSED), workflow-context.md, design-system.md, 4 Navigation, 7 screen-group mẫu (S1/S6/S7/S9/S10/S20/S23). Không lặp lại finding đã resolve ở Phase 4 (a11y 4.8, nav-sync 4.3/4.7, token 4.5, tab R7 4.12, cross-module 4.13).

## Phần B: Rà Soát Xuyên UX Specs (UX Cross-Review)

### B.1 Ma trận Feature → Screen Coverage
Nền: check 4.1 + CQG-09.1 PASS — 19/19 module UI có ≥1 screen group, 170/170 FEAT touchpoint thuộc module có screens. Consolidation 28→24 web (+6 mobile, +4 portal, +1 MPO "Tôi") có lý do KEEP/MERGE/DROP đầy đủ (workflow-context §2.0.5) — không screen dư thừa, không bước nghiệp vụ thiếu surface (R1–R4, R5 đạt: hard stop S7↔S9 hai chiều, WaitingOnIndicator bắt buộc trên mọi object, handoff 1 surface 2 role view, timesheet 1 queue duyệt song song OPS∥HR không nhân bản — checklist Workspace-duplicate đạt).

| ID | Mức | Mô tả | Vị trí | Khuyến nghị | Trạng thái |
|----|-----|-------|--------|-------------|------------|
| F-B-01 | Medium | Năng lực duyệt timesheet nhóm trên mobile (TL/OPS_PLAN, SLA 48h, vùng vàng >90%, OT trần 8h) nằm trong FEAT-MBI-CAPTS-001 nhưng surface M6 không thiết kế — không file, không menu, đẩy về "ứng viên tương lai". Duyệt vẫn làm được trên S15 web nên không phải mất surface, nhưng kênh mobile của capability đã khai báo tạm trống | Navigation-mobile-internal.md:34, 52, 64–69; workflow-context.md:96 | Chốt với owner spec: nếu giữ FEAT-MBI-CAPTS-001 phần duyệt mobile → áp pattern đã đề xuất (badge Home + section role-scoped trong M3) trước Phase 5; nếu bỏ → ghi nhận cut-scope có chủ ý | DEFERRED |
| F-B-02 | Low | MPO-03 Hóa đơn mobile không có FEAT riêng trong registry mobile-portal (giữ surface theo inventory, đánh dấu `[NEEDS_REVIEW: a]`) | Navigation-mobile-portal.md:44–48 | Gộp vào danh sách NEEDS_REVIEW Phase 5 xác nhận FEAT | DEFERRED |

### B.2 Design System Consistency (token/component)
Check 4.5 + CQG-09.2 PASS — 0 raw hex, mọi màu qua token; 7 screen mẫu đều tham chiếu đúng 12 component §4 (ApprovalCard, MoneyDisplay, WaitingOnIndicator, WarningIndicator 3 phần, StatusBadge 1 badge/hàng); density đúng nguyên tắc (tiền/queue compact, hồ sơ comfortable, BI spacious); R10 đạt (enterprise Fluent-inspired, có rào chống consumer style).

| ID | Mức | Mô tả | Vị trí | Khuyến nghị | Trạng thái |
|----|-----|-------|--------|-------------|------------|
| F-B-03 | Medium | Lệch giá trị pagination: design-system quy ước **25/50/100** (§4 dòng nền + Pattern W1) trong khi toàn bộ screen spec dùng **20/50/100** và API contract mặc định `limit=20` | design-system.md:135, 233; screens-approval-inbox.md:55; screens-wallet-recon.md:56; screens-ar-ap.md:62; screens-tkqc-registry.md:59 | Chuẩn hóa design-system về 20/50/100 (khớp API, tránh nhầm lẫn khi implement) | FIXABLE |
| F-B-04 | Medium | "Bộ icon nghiệp vụ bắt buộc" đặt tên không tồn tại trong Lucide (`gate`, `signature`, `lock-money`, `clock-sla`, `undo-clawback`, `file-manual`, `shield-mfa`) — 2 Navigation tái dùng nguyên văn → rủi ro implement lệch/tự chế icon | design-system.md:247; Navigation-bcerp-web.md:215–223 | Bổ sung bảng mapping: tên chuẩn Lucide tương ứng hoặc khai báo rõ đây là custom SVG set (kèm spec vẽ) | FIXABLE |

Ghi nhận RESOLVED từ Phase 4 (không tính finding mở): phím tắt A/R đơn ký tự (High, WCAG 2.1.4) đã fix bằng bind container-level + toggle Settings (design-system §8.1 A1; screens-approval-inbox.md:226).

### B.3 Navigation Completeness
Check 4.3/4.7/4.11 PASS — 39/39 refs khớp, bidirectional 0 orphan, 4/4 Navigation có bảng "Cơ Sở Giữ Lại Màn Hình", mọi screen có route. Route đặc biệt được biện minh rõ: S15 1 route `/ops/capacity` 2 menu (footnote ¹), S25 1 route 2 role-view, S2 route deep-link dù là pane.

| ID | Mức | Mô tả | Vị trí | Khuyến nghị | Trạng thái |
|----|-----|-------|--------|-------------|------------|
| F-B-05 | Low | Trang đích workspace tổng hợp (Home mỗi workspace) chưa có trong inventory — đang theo nguyên tắc "landing = worklist chính", đánh dấu NEEDS_REVIEW | Navigation-bcerp-web.md:97 | Giữ NEEDS_REVIEW; chỉ thêm surface khi BOD bổ sung FEAT vào registry | DEFERRED |
| F-B-06 | Low | Handoff Bridge có menu entry ở Sales nhưng route prefix `/ops/handoff` — SALES điều hướng sang prefix workspace khác; quy tắc breadcrumb "cấp 1 = workspace hiện hành" chưa nói rõ trường hợp surface liên workspace | Navigation-bcerp-web.md:31, 146, 200 | Ghi rõ: breadcrumb Handoff theo workspace người mở (Sales → "Sales > Handoff Bridge") hoặc chấp nhận prefix /ops — chốt 1 cách viết | FIXABLE |

### B.4 API Endpoint References
Đã verify ở Phase 4 (check 4.4) — tổng kết: **0 endpoint bịa**; mọi ref API-* tồn tại trong api-contract.md; gap không bịa mà ghi `[NEEDS_REVIEW]`.

| ID | Mức | Mô tả | Vị trí | Khuyến nghị | Trạng thái |
|----|-----|-------|--------|-------------|------------|
| F-B-07 | Low | ~70 mục NEEDS_REVIEW endpoint (gap thật giữa UI spec và contract v1, không phải lỗi UX): thiếu GET list approvals cho web, GET detail ar-invoice/einvoice, list payment-orders, dunning-policy, disputes, einvoice batch/adjustment/attachment, TopupProposal, OADS, ReplacementRequest, DieEvidence, owner-assign, Contract TKQC, KycProfile, publish/metric/layout/lineage BI, phiếu mở kỳ, ticket discrepancy, beneficiary KYC, thống kê funnel | screens-wallet-recon.md:190–192; screens-ar-ap.md:182–199; screens-tkqc-registry.md:303–310; screens-executive-bi.md:255–260; screens-approval-inbox.md:182; screens-pipeline.md:196 | Đã theo kế hoạch: tổng hợp thành danh sách DEFERRED đưa `/wf-plan-modules` bổ sung vào API contract trước khi code | DEFERRED |

## Phần C: Kiểm Tra Tính Nhất Quán (Consistency Check)

### C.1 Với Feature Specs (Phase 2)

| ID | Mức | Mô tả | Vị trí | Khuyến nghị | Trạng thái |
|----|-----|-------|--------|-------------|------------|
| F-C-01 | Medium | FEAT mapping giữa 2 surface mirror lệch nhau: MPO-02 gắn `CAMP-001`, P2 gắn `CPORT-001, CAMP-002` — theo dõi campaign/deliverable phía client thuộc CAMP-002; ngoài ra tiêu đề cột ghi "FEAT-MPO-*" nhưng giá trị dùng FEAT-ERP-* | Navigation-mobile-portal.md:43, 50; Navigation-portal-web.md:38 | Sửa MPO-02 thành `CPORT-001, CAMP-002`; thống nhất cách ghi prefix FEAT trong bảng traceability | FIXABLE |
| F-C-02 | Medium | Mapping tier → khối hiển thị portal chưa định nghĩa trong spec nào (NEEDS_REVIEW ghi ở cả 2 Navigation portal) | Navigation-portal-web.md:61; Navigation-mobile-portal.md:70 | Cần business-context chốt trước Phase 5; tạm hiển thị theo mặc định tối giản đã mô tả | DEFERRED |
| F-C-03 | Medium | Lệch phân quyền lead giữa nguồn (đã ghi NEEDS_REVIEW trong file, chưa chốt): API-ERP-007 cho L2+ gán owner vs FEAT-ERP-CRM-002 chỉ L4/L5; API-ERP-008 Gate 1=L2/Gate 2=L3 vs FEAT giao SM ký cả 2 gate; GM duyệt chiết khấu không có trong 19 vai | screens-pipeline.md:131; Navigation-bcerp-web.md:137, 139 | Chốt một nguồn với P3-01 §8.1 + spec FEAT khi triển khai; UI hiện theo mức Navigation (an toàn hơn) | DEFERRED |

### C.2 Với Architecture (Phase 3 — roles, state machines)
Điểm đạt: state machine render nguyên văn, không UI suy diễn — `PENDING→STEP1_APPROVED→APPROVED` (S6), lệnh chi `DRAFT→…→READY_TO_PAY→PAID→CLOSED` theo ngưỡng 5/50/200tr + SoD 4 vai (S10-T2), khớp tiền `CHỜ KHỚP→ĐÃ KHỚP TIỀN` (S7-T4), ADACC 6 stage + 2 gate độc lập (S9), HĐLĐ 90/60/30 + rate card `DRAFT→FIN_REVIEW→PENDING_BOD→PUBLISHED` (S20) — khớp §2.0.1 và machine-state P3-01.

| ID | Mức | Mô tả | Vị trí | Khuyến nghị | Trạng thái |
|----|-----|-------|--------|-------------|------------|
| F-C-04 | **High** | Xung đột taxonomy vai trên surface hard-stop gate: 19-role registry dùng `OPS_AD` và xếp `OPS_ADS*` vào nhóm NEEDS_REVIEW #8 "menu ẩn toàn phần chờ BOD chốt", trong khi screens-tkqc-registry dùng **OPS_ADS làm vai chính thao tác** (đăng ký, đề xuất nạp, ghi nhận die) — nếu vai chính bị ẩn menu, S9 mất actor vận hành; danh sách "Ops executor" của NEEDS_REVIEW #8 cũng không liệt kê S9 | Navigation-bcerp-web.md:132, 145–147, 167; adacc/screens-tkqc-registry.md:27–28, 132–143 | Đồng bộ tên vai + ma trận S9 với P3-01 §8.1 trước implement (chọn OPS_AD hoặc OPS_ADS, đưa S9 vào danh sách bật khi chốt); đây là lệch mới, check 4.6 Phase 4 chỉ bắt 2 lệch khác | FIXABLE |
| F-C-05 | Medium | "GM" duyệt chiết khấu vượt định mức xuất hiện trong workflow map và Deal Desk nhưng không ánh xạ trong 19 vai — tạm SALES_L3 | Navigation-bcerp-web.md:139; workflow-context.md §2.0.1 | Gộp vào NEEDS_REVIEW vai (cùng F-C-03) chốt với P3-01 | DEFERRED |
| F-C-06 | Medium | Mâu thuẫn nguồn đếm: nguyên tắc hệ thống "mọi badge là count server-side realtime" vs My Pipeline tính đếm chip + conversion rate client-side trên trang hiện tại (đã NEEDS_REVIEW thiếu endpoint funnel) — chip count sai khi lọc nhiều trang | Navigation-bcerp-web.md:9; screens-pipeline.md:196 | Bổ sung endpoint aggregate đếm theo filter, hoặc hạ nguyên tắc thành "badge duyệt = server-side; chip filter = ước lượng trang hiện tại" | FIXABLE |
| F-C-07 | Low | Thẩm định rate card: API-ERP-067 ghi FIN_L1 vs spec screen giao FIN_L2 — đã ghi NEEDS_REVIEW từ check 4.6, chưa có bên chốt | hr-core/screens-hr-records.md:114 | Vào danh sách DEFERRED vai với P3 | DEFERRED |

### C.3 UI-ID Nhất Quán
Check 4.2 PASS — 413 owned IDs, 0 trùng; scheme prefix nhất quán `UI-WEB-/UI-MBI-/UI-PWEB-/UI-MPO-`; sample đối chiếu khớp bảng Navigation (UI-WEB-APPR-001, UI-WEB-WALLET-001, UI-WEB-ARAP-001, UI-WEB-LEAD-001, UI-WEB-ADACC-001, UI-WEB-HRREC-001, UI-WEB-BI-001).

| ID | Mức | Mô tả | Vị trí | Khuyến nghị | Trạng thái |
|----|-----|-------|--------|-------------|------------|
| F-C-08 | Low | Lỗi cấu trúc/cosmetic: 3 Navigation cùng có 2 mục đánh số "4.5" (tham chiếu §4.5 mơ hồ); tiêu đề rỗng "BẢNG CON —" (mobile-internal); typo nhỏ: "quyết địnhadvance", "Filterpreserved" (pipeline), "Tabinbox" (approval-inbox), ";Publish"/";anomaly" thiếu dấu cách (executive-bi); menu tree portal minh họa bằng emoji thay vì icon Lucide đã khai | Navigation-bcerp-web.md:235; Navigation-portal-web.md:126; Navigation-mobile-portal.md:128; Navigation-mobile-internal.md:50; screens-pipeline.md:34, 178; screens-approval-inbox.md:109; screens-executive-bi.md:159, 165 | Sửa số mục + typos trong 1 lượt dọn spec; thay emoji bằng tên icon Lucide trong sơ đồ | FIXABLE |

Ghi nhận RESOLVED từ Phase 4 (không tính finding mở): reference row `UI-WEB-LEAD-002` trong screens-pipeline.md đã relabel thành `(ref)` giữ traceability 1:1 mà không đăng ký trùng.

---

## Phần D: Phân Tích Thiếu Sót (Gap Analysis)

> Nguồn đối chiếu: cross-validation-report.md (Phase 4 PASSED — không lặp findings đã resolve), workflow-context.md §2.0.1–2.0.5, P3-01 §3/§9, integration-map.md §7.A–7.C + RULE-X001, Navigation 3 kênh, 30 file screens, deferred-findings.md (13 DEFERRED Phase 3).

## D.1 Gap về Screen Coverage

**Đối chiếu (e) — R12 traceability:** 24 web + 5 M-INT + 5 MPO + 4 portal surfaces đều truy được business process → stage → role → workspace → screen (khối "Checklist Bước 0" trong mọi file); 0 orphan (check 4.7 PASS). Ngoại lệ liệt kê bên dưới.

**F-D-01 · High · FIXABLE** — Vòng đời TikTok Shop 3-Gate thiếu working surface cho 3/6 stage. S17 chỉ monitor `operating/degraded`; mục 2 tự tuyên bố "Gate workflow thao tác (checklist Gate 1, ký Gate 2, đối soát Gate 3) KHÔNG thuộc S17" nhưng không surface nào nhận phần việc này: đề xuất shop (OPS_AM, state `proposed` — EmptyState S17 bảo "đăng ký do OPS_AM thực hiện" nhưng S17 cấm thao tác thêm/sửa), checklist Gate 1 (chip S17 hiển thị "chờ FIN_L1 đối chiếu pháp lý" trong khi FIN không có chỗ làm việc này), ký Gate 2 (SALES_L4). API-GW-039 (transitions approve/reject/go_live) có trong contract nhưng 0 UI tiêu thụ; GW arch-draft ghi rõ "màn duyệt kết nối SALES_L4 thuộc SYS-BCERP-WEB". Liên quan F-C-02 (đã chú thích đúng nguồn chính thống trong S17) và F-B-05/NEEDS_REVIEW #8 (SALES_L4 chờ BOD). *Khuyến nghị:* khi F-C-02 chốt, bổ sung mode thao tác Gate trong S17 (hoặc pane tại S27) + deep-link từ WaitingOn; nếu BOD không duyệt vai mở rộng → ghi DECISION drop stage.

**F-D-02 · High · FIXABLE** — Kênh mobile internal thiếu surface cho FIN/OPS/BOD. P3-01 §3.1 (COMP-MBI-005–020) cam kết 16 surface (approval inbox, wallet, BI, gates, ticket, shop alert); integration-map §7.B quy định propagation realtime nhận tại "approval inbox MBI-005/006, alert center MBI-007/017/018". UX chỉ thiết kế 5 màn ESS (M1–M5); bảng push §4 mobile-nav không có đích deep-link cho push duyệt/alert dù API-MBI-034 được trích làm kênh dispatch. Khoảng cách registry ↔ P3-01 không được đánh dấu [NEEDS_REVIEW]/DEFERRED. *Khuyến nghị:* chốt phạm vi bằng văn bản — thêm surface mobile duyệt/alert (pattern M6 có sẵn), hoặc DECISION "duyệt chỉ trên web + push fallback web" và điều chỉnh §7.B.

**F-D-03 · Medium · FIXABLE** — Portal web thiếu surface tự quản tài khoản CLIENT_ADMIN. P3-01 §9.2: Portal Account "invited → active (2FA) → locked/disabled — CLIENT_ADMIN tự quản"; portal-web chỉ có P1–P4 (đọc), sheet quản lý user chỉ có trên mobile (MPO-05/S3) — tác vụ admin bị ép lên kênh mobile. *Khuyến nghị:* bổ sung tab "Người dùng" trong portal-web, tái dùng spec MPO-05-S3.

**F-D-04 · Medium · FIXABLE** — M6 Duyệt nhanh được nhận diện đúng nguyên nhân (BR-008 cấm duyệt phép trên mobile; FEAT trong inventory gốc sai — đúng ra là FEAT-MBI-CAPTS-001), nhưng hàng đợi duyệt timesheet nhóm trên mobile là feature CÓ THẬT trong registry mà chưa có surface; [NEEDS_REVIEW] đang treo không chủ. *Khuyến nghị:* pattern đã đề xuất (badge Home + section M3) đưa vào điểm chốt check 4.1 của /wf-plan-modules.

## D.2 Gap về UX Components

**F-D-05 · High · FIXABLE** — Deal Desk (S3) thiếu cross-module status theo integration-map §7.A (Deal 360): AR invoice + payment status (API-ERP-030) và commission theo deal (API-ERP-039/042) không xuất hiện ở tab/mode nào của S3; aggregation-result.json không wire các API này (0 hit) — nghịch với ghi chú §7.A "đã có trong aggregation-result". Waiting-on số 1 "SALES chờ FIN thu tiền → commission" vì vậy không hiển thị tại nơi ra quyết định duyệt/ký. *Khuyến nghị:* thêm khối read-only "Thanh toán & hoa hồng" vào S3 mode M5 hoặc pane phải W3.

**F-D-06 · Medium · FIXABLE** — Ví & Đối soát (S7) thiếu 2 vế của Ví/KH 360 (§7.A): AR aging của khách (API-ERP-030/032) và portal accounts (API-ERP-055/056); FIN quyết hoàn tiền/khớp tiền phải rời S7 sang S10/S28 mới thấy dunning. Các vế còn lại (nhãn nguồn GW, gate ADACC, freshness) đã đủ. *Khuyến nghị:* thêm chip aging + link portal account vào customer-context của S7.

**F-D-07 · Medium · FIXABLE** — "Tìm kiếm toàn cục" trên topbar (Navigation §1, mọi workspace) không có spec: không component, không phạm vi object, không permission-scope PDP, không API server-side. Là entry chính của nav nên rủi ro lộ dữ liệu vượt quyền hoặc tìm hụt là thực tế. *Khuyến nghị:* bổ sung spec component trước khi implement.

**F-D-08 · Low · DEFERRED** — DPA lifecycle (DF-013/F-D-21): UX nhận diện đúng phía chặn (S19 chips "DPA chặn", BR-FIN-605) nhưng không có indicator xem DPA đã ký/sắp hết hạn — DPA hết hạn sau ký sẽ không phát cảnh báo nào. Giữ DEFERRED theo DF-013; cần ghi [NEEDS_REVIEW] tại S19.

**F-D-09 · Low · FIXABLE** — Rate limit per-tenant (DF-006/F-D-04): Consumer Notes Phase 3 cảnh báo ảnh hưởng UX portal/mobile nhưng outputs chưa định nghĩa state 429/throttle (chỉ BI export có rate limit 5 req/phút). *Khuyến nghị:* bổ sung empty/error state chuẩn cho portal, chờ ma trận tier #20.

**Đối chiếu (c) — server-side: PASS.** Pagination server-side 20/50/100 là quy ước chung (S1, S7, S9, S10, S17, S19, S25…), audit log bắt buộc window; không có list volume lớn nào chạy client-side. **Đối chiếu (d) — ownership/progress: PASS** trừ F-D-05/06/08: WaitingOnIndicator phủ 25/30 screens; Handoff (% checklist + signature timeline), TKQC (ProgressTracker + 2 gate), Commission (stepper + clawback), PIP (mốc 30-60-90) đều hiển thị người giữ việc + thời gian chờ.

## D.3 Gap về Accessibility

**F-D-10 · Low · FIXABLE** — Verify a11y theo mẫu: audit iteration 2 đã fix 1 High + 7 Medium + 2 Low vào design-system §8.1 (A1–A8, WCAG 2.1 AA) và sửa trực tiếp pipeline/approval-inbox/executive-bi; ~20 screens web + 10 mobile/portal còn lại chỉ áp rule gián tiếp, chưa verify từng file. *Khuyến nghị:* chạy lại accessibility-auditor quét full trước code-freeze.

**F-D-11 · Low · DEFERRED** — MFA recovery (DF-001/F-D-02): không có UX state "tài khoản khóa/mất thiết bị" ở kênh nào; scope auth thuộc CORE IdP nên chấp nhận hoãn theo DF-001, nhưng S26 RBAC Admin cần note flow unlock hỗ trợ.

**F-D-12 · Low · FIXABLE** — F-D-17 jailbreak detection (DF-011): deferred record yêu cầu "đưa vào thiết kế mobile chi tiết" — thiết kế mobile chi tiết giờ đã tồn tại nhưng không file mobile nào carry ràng buộc này (không trạng thái "thiết bị không an toàn", không note ảnh hưởng offline-queue). *Khuyến nghị:* thêm ghi chú ràng buộc vào Navigation-mobile + design-system §7; bản thân detection giữ DEFERRED sprint mobile.

## D.4 Tổng Kết Gap Analysis

| Severity | Count | FIXABLE | DEFERRED |
|---|---|---|---|
| Critical | 0 | — | — |
| High | 3 | 3 (F-D-01, 02, 05) | 0 |
| Medium | 4 | 4 (F-D-03, 04, 06, 07) | 0 |
| Low | 5 | 3 (F-D-09, 10, 12) | 2 (F-D-08, 11) |
| **Tổng** | **12** | **10** | **2** |

**Xác nhận cuối — đếm findings:** 0 Critical · 3 High · 4 Medium · 5 Low = **12 findings** (10 FIXABLE, 2 DEFERRED).

**Đánh giá 13 DEFERRED Phase 3:** nhận diện đúng — F-C-02 (chú thích nguồn chính thống 3-Gate trong S17), F-B-05/NEEDS_REVIEW #8 (menu ẩn toàn phần + ma trận vai đủ SALES_L4/L5 trong Navigation và screens; điểm hở duy nhất nằm ở F-D-01), DF-013 (chặn DPA phía S19); nhận diện thiếu — DF-006 (F-D-09), DF-001 (F-D-11), DF-011/F-D-17 (F-D-12). 8 mục còn lại (DF-002/003/005/007/008/009/010/012) là infra/security ngoài bề mặt UX — đúng phạm vi hoãn, không cần touchpoint UX.

**Kết luận:** không có Critical; 3 High đều là "thiếu ở điểm nối" (gate ops TikTok, kênh mobile duyệt/alert, Deal 360) chứ không phải sai nền thiết kế — nền worklist, consolidation và WaitingOn của Phase 4 vững, mọi gap đều fix được bằng bổ sung spec có chủ đích chứ không cần redesign.
