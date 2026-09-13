# Screen Group: KPI & Performance (kỳ quý 3 trụ cột + calibration + PIP 30-60-90)

Implements: FEAT-ERP-KPI-001 (KPI 3 trụ cột tự tổng hợp + calibration), FEAT-ERP-KPI-002 (PIP 30-60-90)

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `kpi` (MOD-KPI-PERFORMANCE)
> **Tính năng:** FEAT-ERP-KPI-001/002 — bản fan-out cho touchpoint SYS-BCERP-WEB (registry giữ FEAT-ID canonical `FEAT-ERP-KPI-*`; không có tiền tố `FEAT-WEB-*` trong req-registry). Engine tổng hợp + validation cứng nằm ở SYS-CORE-BACKEND — WEB chỉ hiển thị machine-state và nhập phần được phép (chấm tay, nhận xét, biên bản).
> **Route:** `/hr/kpi`
> **Main UI-ID:** `UI-WEB-KPI-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|---------|
| Main UI-ID | `UI-WEB-KPI-001` |
| Route | `/hr/kpi` — HR Workspace, badge `{pip_dang_chay}` (Navigation S22, permission KPI) |
| Loại | Dashboard W4 (hàng KPI tổng quan) + thân W1; tab bar 5 tab: T1 Tổng quan · T2 Điểm & dữ liệu gốc (list R6 + drill-down cá nhân) · T3 Calibration & chốt · T4 PIP 30-60-90 · T5 Cấu hình kỳ |
| Workspace | HR — quản lý (TL/SALES_L4–L5, Lead track) vào view team; BOD vào view duyệt; KHÔNG nhân bản surface theo phòng |
| Đối tượng nghiệp vụ | `kpi_cycle` (kỳ quý — machine-state) + `kpi_score` (3 trụ cột read-only + chấm tay + weighted_total) + `kpi_weight_config` (SCD2 theo Level) + `kpi_rubric`/`manual_score_entry` + `kpi_dispute` (window 3 ngày LV) + `calibration_minutes` + `overload_flag` + `pip`/`pip_milestone`/`pip_coaching_session`/`pip_conclusion` (Restricted) |
| Vai trò chính | HR_L2 (cấu hình, calibration + biên bản, trình BOD, duyệt PIP, xác nhận mốc 90, kết luận) · TL/Manager (SALES_L4–L5, Lead track — review team, chấm tay, chốt L1–L3, đề xuất PIP, coaching) |
| Vai trò liên quan | Nhân sự (xem điểm + 100% dữ liệu gốc của mình, gửi thắc mắc trong 3 ngày LV) · HR_L1 (mở/đóng kỳ, theo dõi chu kỳ, cờ quá tải; PIP chỉ thấy trạng thái) · BOD_CEO/BOD_CFO_CTO (chốt L4–L5 ≤15 ngày LV, duyệt đổi trọng số, duyệt loại trừ dự án khẩn, quyết định khi PIP không đạt) · SYS_ADMIN (trạng thái kỳ + audit log, không xem dữ liệu cá nhân) |
| Workflow stage | Kỳ KPI: `OPEN → AGGREGATED → REVIEW_WINDOW ⇄ DISPUTE → CALIBRATION → (BOD_APPROVAL) → FINALIZED → LOCKED` — không quay về, không CRUD khi đã khóa · PIP: `SUGGESTED → PROPOSED → ACTIVE ⇄ SUSPENDED → PASSED / ESCALATED → CLOSED_TRANSFERRED / CLOSED_DEMOTED / CLOSED_TERMINATED`; `REJECTED`/`DISMISSED` kết thúc |

**Checklist ngữ cảnh (BƯỚC 0):** (A) Object = chu kỳ KPI quý (vòng đời năm/quý ≠ CRUD) + hồ sơ PIP; điểm 3 trụ cột do CORE tự tổng hợp khi đóng kỳ từ dữ liệu gốc đã khóa. (B) Primary actors: HR_L2 điều phối chất lượng, Manager review/chốt team. (C) Related: nhân sự (minh bạch + thắc mắc), BOD (chốt cấp cao + quyết định hành chính), HR_L1 (điều phối), SYS_ADMIN (log), OPS (nguồn SLA — handoff B8, chỉ đọc). (D) Stages: 2 machine-state độc lập (kỳ KPI và PIP — mô tả trên). (E) Cross-module: CAPTS (utilization/on-time), COMM + CRM (output/theo thực nhận), OPS (SLA breach), S15 (timesheet duyệt ∥), S20 (hồ sơ SCD2 — Level hiện hành lúc đóng kỳ), S23 (BI phân bố điểm), S24 (escalate SLA chốt quá hạn), M1/M3 (ESS xem điểm cá nhân). (F) Thông tin cần: trạng thái kỳ + còn bao nhiêu ngày SLA chốt, điểm 3 trụ cột + nguồn, điểm chờ chốt của ai, outlier, cờ quá tải, mốc 30/60/90 + nhịp coaching. (G) Quyết định: chốt L1–L3 (Manager ≤10 ngày LV), chốt L4–L5/biên (BOD ≤15 ngày LV), duyệt trọng số mới, loại trừ dự án khẩn, duyệt PIP, kết luận PIP, quyết định điều chuyển/hạ Level/chấm dứt HĐLĐ. (H) Actions: mở/đóng/công bố kỳ, calibrate, lập biên bản, chốt, trình BOD, chấm tay, phản hồi luồng PIP, coaching. (I) Exceptions: thiếu dữ liệu OPS → kỳ không sang `AGGREGATED`, thắc mắc chưa phản hồi → không sang calibration, thiếu biên bản → chặn trình BOD, quá SLA chốt → nhắc + escalate, outlier tự đánh dấu, trễ nhịp coaching ≤2 tuần, mốc trễ → cảnh báo đỏ, lương luôn masked. (J) 1 surface `/hr/kpi`, 5 tab — điểm cá nhân drill-down qua Sheet, không page rời.

---

## 1. TRANG CHÍNH

### 1.1. Layout — hàng W4 tổng quan trên cùng (theo kỳ đang chọn) + tab bar; T2 là tab mặc định với Manager, T1 với HR

```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│ Breadcrumb: HR > KPI & Performance     Kỳ [Q3-2026 ▾]  [CALIBRATION]  Còn 6 ngày LV chốt L1–L3 │
│                                    [+ Mở kỳ] [Đóng kỳ] [Công bố] [Chạy calibration] [Trình BOD]│
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ ┌ Trạng thái kỳ ──┬ Đã chốt ────────┬ Outlier chờ calib ┬ Cờ quá tải ───┬ PIP đang chạy ────┐│
│ │ CALIBRATION     │ 86/142 (61%)    │ 7 điểm · 4 team   │ 4 NV · >100%  │ 9 · 2 trễ mốc     ││
│ │ Q3-2026 · 4/9   │ SLA L4–L5: 8 NLV│ tự động đánh dấu  │ ≥2 tuần · MTOP│ 2 chờ HR_L2 duyệt ││
│ └─────────────────┴─────────────────┴───────────────────┴───────────────┴───────────────────┘│
│ Tabs: [Tổng quan] [Điểm & dữ liệu gốc ·142] [Calibration & chốt ·7] [PIP 30-60-90 ·11] [Cấu hình]│
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ ── TAB T2: ĐIỂM & DỮ LIỆU GỐC (mặc định lọc theo scope: team của tôi / toàn kỳ) ─────────── │
│ (Outlier ·7×)(Có thắc mắc ·3×)(Chờ Manager chốt ·21×)(Chờ BOD ·5×)(Quá tải ·4×) [Tìm][Lọc ▾] │
│ ┌──────────────────────────────────────────────────────────────────────────────────────────┐ │
│ │ Mã NV  Họ tên        Track·Level On-time Output SLA/Trg Chấm tay  Tổng   Trạng thái  Chờ  ││
│ │ NV-0142 Phạm Thu A.  KD-3        88     76     92       85       84,1  [Đã chốt]           ││
│ │ NV-0157 Lê Văn B.    BO-2        64     58 ⚠    71       —        63,9  [Outlier] chờ L2   ││
│ │ NV-0163 Trần Thị C.  MK-1        90     83     95       88       89,3  [Chờ chốt] 2 ngày  ││
│ │ … (cột nguồn trụ cột: tooltip "CAPTS · COMM/CRM · OPS SLA — khóa 12/09")                  │ │
│ │ Phân trang ← 1 2 … 8 →   20/50/100                                                        │ │
│ └──────────────────────────────────────────────────────────────────────────────────────────┘ │
│ Row actions: Xem (S1) · Chấm tay (D4) · Nhận xét · Chốt (D7) · ⋯                              │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```

Global context: kỳ đang chọn (`Q3-2026`) + bộ lọc team giữ nguyên khi chuyển tab; header trạng thái kỳ thay đổi theo machine-state — nút hành động trên header chỉ hiện đúng trạng thái (Đóng kỳ chỉ khi `OPEN`; Công bố chỉ khi `AGGREGATED`; Chạy calibration chỉ khi `REVIEW_WINDOW` sạch thắc mắc; Trình BOD chỉ khi `CALIBRATION` có biên bản). Mobile <768px: bảng không render — ESS xem điểm cá nhân qua M1/M3, báo "quản lý kỳ trên web".

### 1.2. Components

| Component | Cấu hình | Ghi chú |
|-----------|---------|---------|
| KPI row (W4) | 5 ô số lớn + nhãn phụ, click → worklist đã lọc (dashboard principle — không card trang trí) | Trạng thái kỳ → T3; Đã chốt → T2 lọc; Outlier → T3; Quá tải → Sheet S4; PIP → T4 |
| Tabs | page tabs + count-tab (Calibration, PIP); T3/T4/T5 lazy-load | Count server-side realtime |
| DataTable | row compact 32px (worklist), header 36px sticky, sort click header, pagination server-side 20/50/100, column config persist | R6; cột điểm `tabular-nums` right-align |
| Quick filter chips | tháo từng chip; chip "Có thắc mắc"/"Outlier"/"Quá tải" tự hiện khi count > 0 | Chip = filter tương ứng |
| StatusBadge | 1 badge/hàng — bảng trạng thái §1.4 | Token §1 design-system |
| WarningIndicator | inline + banner: SLA chốt cận hạn, thắc mắc chưa phản hồi chặn calibration, thiếu biên bản chặn trình BOD, mốc PIP trễ, coaching trễ nhịp | 3 phần: chuyện gì — ai làm — hạn còn lại |
| WaitingOnIndicator | chip cột "Chờ": chờ Manager chốt (SLA 10 NLV), chờ BOD (15 NLV), chờ HR_L2 duyệt PIP (5 NLV) — màu theo ngưỡng SLA | Bắt buộc theo ràng buộc thiết kế số 1 |
| ProgressTracker | lifecycle kỳ `OPEN→…→LOCKED` ở T3 (stepper ngang, node click được theo quyền); mốc 30/60/90 ở Sheet S2 | aria-current; stage có quyền xem mới click |
| MaskedField | tham chiếu thu nhập/khung lương §6 luôn masked (BR-KPI-012/BR-PIP-011) | Mask rule từ `/core/pii/mask-configs` |

### 1.3. Cột danh sách T2

| Tên | Trường | Định dạng | Sắp xếp | Ghi chú |
|-----|--------|----------|---------|---------|
| Mã NV | `employee_id` → mã NV | Text, tabular | Có | Mã nghiệp vụ, không UUID |
| Họ tên | `full_name` | Avatar + tên | Có | Click → Sheet S1 |
| Track · Level | `career_track`/`career_level` (SCD2 lúc đóng kỳ) | `KD-3`, tooltip version SCD2 | Có | Map lệch 4 track ↔ taxonomy PMS → chặn phát hành kỳ (BR-KPI-011) |
| On-time | `on_time_score` | Số /100, read-only | Có | Nguồn CAPTS + OPS — tooltip ghi nguồn + thời điểm khóa |
| Output Volume | `output_score` | Số /100, read-only | Có | Nguồn COMM/CRM (theo thực nhận) |
| SLA/Target | `sla_score` | Số /100, read-only | Có | Nguồn OPS SLA breach qua CORE (chỉ đọc, handoff B8) |
| Chấm tay | `manual_score` (tổng rubric ×15%) | Số /100 | Có | "—" nếu chưa có; thiếu metadata người chấm/ngày/nhận xét → từ chối lưu (BR-KPI-004) |
| Tổng | `weighted_total` | Số /100 bold + w hiện hành tooltip (`L3 20/30/35/15`) | Có | Công thức BR-KPI-002 — tính bởi CORE, UI không tự tính |
| Trạng thái điểm | `status` | StatusBadge §1.4 | Có | Theo tiến độ chốt |
| Chờ | derived | WaitingOnIndicator | Không | Chờ ai + bao lâu + ngưỡng SLA |
| Cờ | derived | Icon cảnh báo (outlier ⚠ / quá tải / thắc mắc) | Không | Chi tiết trong S1 |

### 1.4. Trạng thái & badge

Kỳ KPI: `OPEN` `--state-info` · `AGGREGATED` `--state-manual` ("đã khóa dữ liệu gốc") · `REVIEW_WINDOW` `--state-pending` · `DISPUTE` `--state-sla-warning` · `CALIBRATION` `--state-pending` · `BOD_APPROVAL` `--state-sla-warning` · `FINALIZED` `--state-approved` · `LOCKED` `--state-approved` + icon khóa. Điểm: Chờ chốt `--state-pending` · Đã chốt `--state-approved` · Outlier `--state-sla-warning` ⚠ · Có thắc mắc `--state-info` · Quá tải miễn phạt on-time `--state-manual`. PIP: `SUGGESTED` `--state-info` · `PROPOSED` `--state-pending` · `ACTIVE` `--state-manual` · `SUSPENDED` `--state-draft` · `PASSED` `--state-approved` · `ESCALATED` `--state-overdue` · `CLOSED_*` `--state-manual` · `REJECTED`/`DISMISSED` `--state-rejected`/`--state-draft`.

**Trạng thái hệ thống:** loading = skeleton 10 hàng; empty T2 = "Kỳ chưa có điểm — kỳ chuyển AGGREGATED sau khi CORE tổng hợp"; thiếu dữ liệu OPS đến hạn đóng kỳ → banner (không dismiss): "Thiếu dữ liệu SLA kỳ Q3 — chờ OPS cung cấp, đầu mối: [AM] — kỳ không thể đóng" (BR-KPI-014); error = hàng lỗi + retry. Mọi mốc SLA/countdown render từ job CORE — UI không tự tính ngày làm việc.

### 1.5. Phân Quyền (hide khi không có quyền — PEP; CORE kiểm tra tại API)

| Thành phần | Nhân sự | TL/Manager | HR_L1 | HR_L2 | BOD | SYS_ADMIN |
|-----------|---------|------------|-------|-------|-----|-----------|
| Xem điểm + 100% dữ liệu gốc của mình | ✅ (S1) | ✅ | ✅ | ✅ | ✅ | ❌ (không dữ liệu cá nhân) |
| Xem điểm team mình | ❌ | ✅ | ✅ (toàn kỳ) | ✅ | ✅ | ❌ |
| Gửi thắc mắc (D1, trong 3 ngày LV, của mình) | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Ghi nhận xét / nhập chấm tay (D4) | ❌ | ✅ (team, được chỉ định) | ❌ | ✅ | ❌ | ❌ |
| Mở/đóng kỳ, công bố, theo dõi chu kỳ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Cấu hình trọng số + rubric (D2), soạn đề xuất đổi trọng số (D3) | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Duyệt đổi trọng số / loại trừ dự án khẩn | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Chạy calibration + biên bản (D5) | ❌ | ❌ | ❌ (xem biên bản) | ✅ | ❌ | ❌ |
| Chốt L1–L3 (D7, ≤10 NLV) | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ |
| Trình BOD (D6) / chốt L4–L5 (≤15 NLV) | ❌ | ❌ | ❌ | ✅ (trình) | ✅ (chốt) | ❌ |
| Đề xuất PIP (D9) / coaching (D15) / mốc 30–60 (D11) | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ |
| Duyệt/từ chối/bỏ qua PIP (D10), tạm dừng/khôi phục (D14), mốc 90 + kết luận (D12) | ❌ | ❌ (soạn D14) | ❌ | ✅ | ❌ | ❌ |
| Quyết định khi PIP không đạt (D13) | ❌ | ❌ | ❌ | ✅ (trình) | ✅ | ❌ |
| Xem hồ sơ PIP nội dung (Restricted) | ✅ (của mình) | ✅ (team mình) | ❌ (chỉ trạng thái danh sách) | ✅ | ✅ | ❌ |
| Xem lương từ tham chiếu §6 trên màn KPI | ❌ (masked) | ❌ (masked) | ❌ (masked) | ✅ | ✅ | ❌ |
| Xem trạng thái kỳ + audit log điều chỉnh | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ |

Cấm tự duyệt luồng của mình: Manager chốt điểm người mình chấm tay vẫn qua calibration HR_L2; HR_L2 đề xuất trọng số → BOD duyệt; HR_L2 trình PIP không đạt → BOD quyết định (SoD, không ai chiếm 2 bước). Sửa/xóa kỳ đã khóa: không tồn tại nút — chỉ điều chỉnh có biên bản + audit log sau `FINALIZED` theo quyết định BOD.

---

## 2. TABS

Global context (kỳ đang chọn + filter team) giữ nguyên khi chuyển tab; T3/T4/T5 lazy-load.

### Tab T1 — Tổng quan `UI-WEB-KPI-001-T1`
- **Mục tiêu:** ảnh trạng thái chu kỳ theo quý — mọi con số click ra được worklist đã lọc (dashboard principle), cho HR_L1 điều phối đúng hạn và HR_L2 thấy điểm cần xử lý.
- **Thông tin:** (1) hàng W4 §1.1; (2) widget phân bố điểm theo bậc (histogram ≥3 lớp màu token, click → T2 sort theo tổng); (3) widget top/bottom 10 (chỉ khi kỳ ≥ `CALIBRATION` — đối tượng bắt buộc calibration BR-KPI-007, click → T2 lọc outlier); (4) widget queue "chờ chốt của ai" (group theo Manager + SLA còn lại — click → T2 lọc + WaitingOn); (5) widget cờ quá tải (utilization >100% ≥2 tuần, từ `/api/v1/erp/capacity` — click → Sheet S4); (6) widget PIP tóm tắt (mới gợi ý/đang chạy/trễ mốc — click → T4).
- **Components/actions/states:** KPI row + widget grid 12 cột; không có action ghi trực tiếp trên T1 — mọi widget dẫn tới tab đích; empty (chưa mở kỳ) = EmptyState + CTA "Mở kỳ" (chỉ HR_L1/L2); dữ liệu widget lazy-load từng khối, error retry từng widget.
- **Permissions:** nhân sự thường KHÔNG thấy T1 (mặc định rơi vào T2 lọc "của mình"); SYS_ADMIN thấy duy nhất khối trạng thái kỳ + link audit (S26 `/admin/audit`).
- **Quan hệ tab khác:** T1 là điểm vào; chọn nhân sự bất kỳ → mở Sheet S1 giữ context T1 khi đóng.

### Tab T2 — Điểm & dữ liệu gốc `UI-WEB-KPI-001-T2`
- **Mục tiêu:** bề mặt minh bạch — 100% dữ liệu gốc của từng điểm tra cứu được, nguồn ghi rõ, thắc mắc gửi đúng window 3 ngày LV; là worklist chốt điểm của Manager.
- **Thông tin:** bảng §1.3; Sheet S1 (KPI cá nhân 360) chứa: 3 khối trụ cột — mỗi khối nêu **nguồn** (On-time ← CAPTS utilization + deadline OPS; Output ← COMM theo thực nhận + CRM target; SLA/Target ← OPS SLA breach qua CORE, chỉ đọc) + trạng thái "đã khóa" kỳ; bảng dữ liệu gốc đầy đủ (theo từng giao dịch/task/deal tổng hợp); phần chấm tay theo rubric (người chấm, ngày, nhận xét — BR-KPI-004); luồng thắc mắc (gửi D1, trạng thái đối chiếu của CORE); nhận xét review của Manager; history điều chỉnh sau calibration (audit trước/sau).
- **Components/actions/states:** DataTable + Sheet S1 720px + MaskedField; row actions theo trạng thái kỳ: `REVIEW_WINDOW` cho nhân sự nút "Gửi thắc mắc" (của mình, hết window → ẩn + tooltip "hết 3 ngày làm việc"); Manager thấy "Chấm tay" (D4) + "Chốt" (D7) khi `CALIBRATION`; warning khi kỳ còn `DISPUTE` — badge cờ trên hàng tương ứng.
- **Permissions:** theo §1.5 — lương masked trừ HR_L2/BOD; nhân sự chỉ thấy hàng của mình (mặc định filter khóa); SYS_ADMIN không thấy bảng.
- **Quan hệ tab khác:** chốt xong → T3 cập nhật count; điểm <60/100 hoặc 2 quý dưới kỳ vọng → CORE sinh gợi ý PIP (event `kpi.below_threshold`) hiện ở T4; hồ sơ track/level đọc từ S20.

### Tab T3 — Calibration & chốt `UI-WEB-KPI-001-T3`
- **Mục tiêu:** công bằng chéo team — outlier không bỏ sót, biên bản bắt buộc, chốt đúng SLA 10/15 ngày LV, kỳ chỉ `LOCKED` khi 100% đã chốt.
- **Thông tin:** (1) ProgressTracker lifecycle kỳ (node: trạng thái + người giữ + số ngày chờ); (2) khối "chưa phản hồi thắc mắc" (chặn sang calibration — BR-KPI-006) dạng WarningIndicator banner có nút "Xem thắc mắc" (→ T2 lọc); (3) bảng so sánh chéo team: điểm trung bình/phân bố theo Manager + outlier tự đánh dấu (hàng tô `--state-sla-warning`, không tắt được); (4) danh sách biên bản calibration (xem S3, lập D5 — người dự, quyết định, lý do); (5) queue chốt: nhóm L1–L3 chờ Manager (SLA 10 NLV) và nhóm L4–L5/top-bottom/biên chờ BOD (SLA 15 NLV) — mỗi nhóm count + countdown + nút hành động; (6) queue loại trừ dự án khẩn (BOD duyệt trước hoặc trong 24h — D8).
- **Components/actions/states:** ApprovalCard cho D6 (trình BOD) và D7 (chốt); WarningIndicator khi quá SLA ("quá hạn → nhắc + escalate" — escalation vào S24 Alert Center); nút "Chạy calibration" (POST `/calibrate`) chỉ HR_L2, khóa khi còn thắc mắc chưa phản hồi; empty "Không còn điểm chờ chốt" = trạng thái tốt.
- **Permissions:** nhân sự/manager thường thấy read-only phần lifecycle + queue team mình; HR_L2 thao tác; BOD nhận duyệt (D6 bước chốt, D8).
- **Quan hệ tab khác:** calibration chỉnh điểm → ghi audit trước/sau tự động (BR-KPI-007); chốt L4–L5 xong → kỳ tiến `FINALIZED`; 100% chốt → CORE tự khóa `LOCKED` (job — run history ở API-ERP-075).

### Tab T4 — PIP 30-60-90 `UI-WEB-KPI-001-T4`
- **Mục tiêu:** trọn vòng đời PIP — gợi ý (chỉ gợi ý, không tự mở) → đề xuất → duyệt ≤5 ngày LV → chạy với mốc + coaching ≥2 tuần/lần → kết luận đúng luồng; Restricted bảo vệ nội dung.
- **Thông tin:** (1) hàng đợi gợi ý (`SUGGESTED` từ `kpi.below_threshold`: điểm <60/100 · 2 quý dưới kỳ vọng · SLA nghiêm trọng đã xác nhận — mỗi gợi ý hiển thị mã điều kiện + kỳ nguồn, link T2); (2) danh sách PIP: NV, Manager, lý do (`reason_code`), mốc hiện tại (30/60/90 + due date + còn X ngày), nhịp coaching (đạt/trễ X ngày), StatusBadge, WaitingOn (chờ HR_L2 duyệt / chờ BOD); (3) Sheet S2 chi tiết: mục tiêu đo được, 3 mốc với tiêu chí + kết quả + người đánh giá, nhật ký coaching (ngày, người, nội dung, thỏa thuận, xác nhận nhân sự — cam kết 2 chiều BR-PIP-009), lịch sử tạm dừng/khôi phục (mốc tính lại từ ngày trở lại), timeline + audit truy cập; (4) khối cảnh báo: mốc trễ (đỏ — BR-PIP-004), coaching trễ nhịp >2 tuần (BR-PIP-012), hồ sơ chưa được nhân sự xác nhận đã nhận kế hoạch, đề xuất bị từ chối lặp cùng lý do (chống lặp BR-PIP-005 Mục 5).
- **Components/actions/states:** DataTable + Sheet S2 720px; row actions theo trạng thái: Đề xuất (D9 — Manager, từ gợi ý hoặc từ hàng T2), Duyệt/từ chối/bỏ qua (D10 — HR_L2), Đánh giá mốc (D11), Xác nhận mốc 90 + kết luận (D12), Quyết định BOD (D13 — chỉ `ESCALATED`), Tạm dừng/khôi phục (D14), Coaching (D15); badgeRestricted: HR_L1 thấy count + trạng thái KHÔNG mở được S2 (nút ẩn — PEP); thử việc → nút Đề xuất PIP ẩn (BR-PIP-008).
- **Permissions:** theo §1.5; mọi lượt xem nội dung Restricted của Manager/HR_L2/BOD ghi audit (xem log cũng bị log với SYS_ADMIN).
- **Quan hệ tab khác:** kỳ nguồn của gợi ý link về T2; hạ Level theo D13 → tạo version SCD2 mới ở S20 (chặn nếu không tạo); BOD nhận hàng đợi quyết định qua S24 khi escalate quá hạn.

### Tab T5 — Cấu hình `UI-WEB-KPI-001-T5`
- **Mục tiêu:** khung đánh giá đúng trước khi kỳ mở — thiếu rubric thì không mở được kỳ (BR-KPI-004), trọng số version hóa theo Level, khung vị trí map đúng 4 track.
- **Thông tin:** (1) bảng trọng số theo Level (`L1 20/50/15 → L5 20/10/55` + cột Chấm tay 15% cố định) với version hiện hành + hiệu lực từ–đến (SCD2, không sửa đè — BR-KPI-003); (2) rubric chấm tay (mã, tiêu chí, trọng số, nội dung, ngày khai báo — D2 soạn); (3) lịch kỳ (quý, ngày đóng dự kiến, trạng thái mở/đóng); (4) khung KPI theo vị trí nguồn `03_Quy_che_KPI_HR.md` §5–§6 — bảng ON/OFF + trọng số quy đổi, kèm cảnh báo đối chiếu 4 track ↔ role taxonomy PMS (map lệch → chặn phát hành kỳ, BR-KPI-010/011); (5) đề xuất đổi trọng số đang chờ BOD (D3 — hiệu lực đầu năm tài chính, version hóa).
- **Components/actions/states:** bảng cấu hình comfortable 40px + edit qua dialog (không inline-edit); ApprovalCard D3; empty khi chưa cấu hình → chặn "Mở kỳ" ở header bằng WarningIndicator (không phải disabled mờ).
- **Permissions:** chỉ HR_L2 soạn; BOD duyệt trọng số; HR_L1 + BOD read-only; vai khác không thấy tab.
- **Quan hệ tab khác:** kỳ `OPEN` dùng version trọng số hiệu lực tại thời điểm đóng kỳ (đổi Level giữa kỳ không tính lại quá khứ — SCD2); rubric thiếu → D5 "Mở kỳ" bị chặn với danh sách thiếu.

---

## 3. DIALOGS

| # | Dialog | UI-ID | Loại | Mở khi nào |
|---|--------|-------|------|-----------|
| 1 | Gửi thắc mắc điểm | `UI-WEB-KPI-001-D1` | Form + attach dẫn chứng | T2/S1 — "Gửi thắc mắc" (nhân sự, của mình, window 3 NLV) |
| 2 | Cấu hình khung kỳ (trọng số + rubric + lịch) | `UI-WEB-KPI-001-D2` | Form 2 cột (max 960px) | T5 — "Chỉnh rubric/lịch" (HR_L2, trước kỳ) |
| 3 | Đề xuất đổi trọng số → BOD duyệt | `UI-WEB-KPI-001-D3` | ApprovalCard 2 bước | T5 — "Đề xuất đổi trọng số" |
| 4 | Nhập điểm chấm tay + nhận xét | `UI-WEB-KPI-001-D4` | Form theo rubric | T2 row action "Chấm tay" (Manager/HR_L2) |
| 5 | Lập/sửa biên bản calibration | `UI-WEB-KPI-001-D5` | Form + bảng quyết định | T3 — "Lập biên bản" |
| 6 | Trình BOD + chốt L4–L5/top-bottom/biên | `UI-WEB-KPI-001-D6` | ApprovalCard | T3 — "Trình BOD" (HR_L2) / BOD chốt |
| 7 | Chốt điểm L1–L3 | `UI-WEB-KPI-001-D7` | ApprovalCard nhẹ + nhận xét | T2/T3 — "Chốt" (Manager, ≤10 NLV) |
| 8 | Duyệt loại trừ dự án khẩn | `UI-WEB-KPI-001-D8` | ApprovalCard + ngữ cảnh | T3 queue loại trừ (BOD; trước hoặc trong 24h) |
| 9 | Đề xuất mở PIP | `UI-WEB-KPI-001-D9` | Form dài (mục tiêu + 3 mốc + lịch coaching) | T4 gợi ý / T2 — "Đề xuất PIP" (Manager) |
| 10 | Duyệt / từ chối / bỏ qua PIP | `UI-WEB-KPI-001-D10` | ApprovalCard + tab quyết định | T4 hàng `PROPOSED`/`SUGGESTED` (HR_L2) |
| 11 | Đánh giá mốc 30/60 | `UI-WEB-KPI-001-D11` | Form kết quả + nhận xét | S2/T4 — mốc đến hạn (Manager/HR_L2) |
| 12 | Xác nhận dữ liệu mốc 90 + kết luận | `UI-WEB-KPI-001-D12` | ApprovalCard 2 nhánh | S2 — mốc 90 (HR_L2): Đạt → `PASSED` / Không đạt → `ESCALATED` |
| 13 | Quyết định BOD khi không đạt | `UI-WEB-KPI-001-D13` | ApprovalCard + khuyến nghị HR_L2 | T4 hàng `ESCALATED` (BOD): điều chuyển / hạ Level / chấm dứt HĐLĐ |
| 14 | Tạm dừng / khôi phục PIP | `UI-WEB-KPI-001-D14` | Form + hồ sơ nghỉ đính kèm | S2 (HR_L2 duyệt; Manager soạn) — tính lại mốc khi khôi phục |
| 15 | Ghi nhận buổi coaching + xác nhận nhân sự | `UI-WEB-KPI-001-D15` | Form + ack | S2 — "Ghi coaching" (Manager/HR_L2; nhân sự xác nhận) |

Chi tiết trọng yếu:
- **D1:** chỉ nhận trong 3 ngày làm việc kể từ công bố (hết window → ẩn + tooltip; HR_L2 mở ngoại lệ kèm lý do lưu hồ sơ — BR-KPI-006); bắt buộc chọn điểm/trụ cột + nội dung + dẫn chứng (file/link dữ liệu gốc); gửi → kỳ hàng đó sang `DISPUTE`, phản hồi đối chiếu do CORE thực hiện và hiển thị lại trong S1.
- **D2:** thiếu rubric bất kỳ → lưu được nhưng khi "Mở kỳ" bị chặn kèm danh sách thiếu (BR-KPI-004); mỗi rubric bắt buộc mã + tiêu chí + trọng số (tổng trọng số rubric = 100% của thành phần 15%); lịch kỳ theo quý, không chồng kỳ.
- **D3:** bước 1 HR_L2 soạn (w1/w2/w3 theo Level + hiệu lực đầu năm tài chính + căn cứ); bước 2 BOD duyệt/từ chối (lý do bắt buộc ≥10 ký tự); duyệt → version mới, không sửa đè version cũ; áp dụng chưa qua BOD bị CORE từ chối.
- **D4:** form theo rubric đã khai báo — mỗi dòng điểm bắt buộc người chấm (tự điền), ngày chấm, nhận xét; thiếu 1 trong 3 → không lưu được (CORE từ chối); tổng rubric × 15% hiển thị preview; điểm 3 trụ cột KHÔNG có ô nhập (BR-KPI-001 — form không render).
- **D5:** người dự (multi-select), quyết định từng điểm điều chỉnh (giá trị trước/sau — chỉ đọc từ hệ thống), lý do từng quyết định bắt buộc; lưu → biên bản bất biến, là điều kiện bật "Trình BOD" (D6); điều chỉnh ngoài biên bản không tồn tại trong UI.
- **D6:** ngữ cảnh: điểm đối tượng, nhóm (L4–L5/top/bottom/biên), biên bản đính kèm (chưa có → nút trình khóa kèm lý do); BOD thấy khuyến nghị HR_L2 + dữ liệu chuẩn hóa; **Duyệt chốt** (≤15 NLV, có countdown) / **Từ chối** (lý do ≥10 ký tự — trả về calibration).
- **D7:** chốt từng người hoặc bulk theo team (bulk bar khi chọn ≥1 hàng — cùng lý do nhận xét được); SLA 10 NLV countdown trên nút; quá hạn → nhắc + escalate (vi phạm SLA ghi nhận, SC-004).
- **D9:** thành phần bắt buộc: lý do (`reason_code` prefill từ điều kiện gợi ý), mục tiêu đo được, 3 mốc (30 — nhận diện vấn đề + hướng dẫn; 60 — đo tiến bộ + coaching tăng cường; 90 — tiêu chí kết luận), lịch coaching (hệ thống validate ≥2 tuần/lần); thiếu 1 → nút gửi khóa + liệt kê còn thiếu (SC-003); trình bày ngôn ngữ "kế hoạch cải thiện 2 chiều" (BR-PIP-009).
- **D10:** duyệt (≤5 NLV sau công bố KPI — countdown; quá → nhắc + escalate SC-002) / từ chối (lý do bắt buộc → `REJECTED`) / bỏ qua gợi ý (lý do bắt buộc → `DISMISSED`, chỉ HR_L2); sau duyệt mốc tính từ ngày kích hoạt.
- **D11:** kết quả mốc (đạt một phần/đạt/không đạt) + nhận xét + dẫn chứng; mốc trễ → cảnh báo đỏ tự hiện ở T4/S2 (BR-PIP-004); đang `SUSPENDED` → đánh giá bị chặn (BR-PIP-007).
- **D12:** điều kiện bật: dữ liệu mốc 90 đã HR_L2 xác nhận; nhánh Đạt → `PASSED` (thoát PIP); nhánh Không đạt → bắt buộc khuyến nghị (điều chuyển/hạ Level/chấm dứt) → `ESCALATED` + hàng đợi BOD.
- **D13:** chỉ BOD; quyết định + lý do + `legal_note` bắt buộc; hạ Level → hệ thống nhắc tạo version SCD2 ở S20 (chặn hoàn tất nếu chưa — BR-PIP-010); chưa quyết định → hồ sơ treo `ESCALATED` với WarningIndicator (không tự suy kết quả hành chính).
- **D14:** tạm dừng bắt buộc đính kèm hồ sơ nghỉ dài; khôi phục → hệ thống tính lại toàn bộ mốc 30/60/90 + lịch coaching từ ngày làm việc đầu tiên (hiển thị diff mốc cũ → mới trước khi xác nhận).
- **D15:** ngày, người coaching, nội dung, thỏa thuận; gửi → yêu cầu xác nhận của nhân sự (ack) — chưa ack → cảnh báo HR_L2; nhịp đo tự động, trễ >2 tuần → cảnh báo Manager + HR_L2 + ghi vi phạm vào hồ sơ (BR-PIP-012).

---

## 4. SHEETS

| # | Sheet | UI-ID | Vị trí | Mở khi nào |
|---|-------|-------|--------|-----------|
| 1 | KPI cá nhân 360 (điểm + dữ liệu gốc + thắc mắc) | `UI-WEB-KPI-001-S1` | Right 720px | Click 1 hàng T2 (hoặc "Xem") |
| 2 | PIP chi tiết (kế hoạch + mốc + coaching) | `UI-WEB-KPI-001-S2` | Right 720px | Click 1 hàng T4 |
| 3 | Biên bản calibration | `UI-WEB-KPI-001-S3` | Right 480px | Click 1 biên bản trong T3 |
| 4 | Cờ quá tải (utilization + miễn phạt on-time) | `UI-WEB-KPI-001-S4` | Right 480px | Click widget cờ quá tải / icon cờ T2 |

- **S1:** header: avatar + tên + mã NV + track·level (tooltip SCD2) + trạng thái điểm kỳ. Khối: (1) 3 panel trụ cột — mỗi panel hiển thị điểm + **nguồn ghi rõ** ("Nguồn: CAPTS — đã khóa 12/09 17:00") + link mở rộng dữ liệu gốc (bảng giao dịch/task/deal đã tổng hợp — 100% minh bạch, BR-KPI-006); (2) công thức tổng (`On-time×w1 + Output×w2 + SLA×w3 + Chấm tay×15%`) với trọng số Level hiện hành; (3) chấm tay theo rubric (người chấm + ngày + nhận xét); (4) luồng thắc mắc: lịch sử gửi → trạng thái đối chiếu CORE → phản hồi; (5) nhận xét review + history điều chỉnh sau calibration (audit trước/sau); (6) status trụ cột ngoại lệ: "định tính/prorate/loại trừ" (mới <30 ngày, nghỉ ≥1 tháng, dự án khẩn — BR-KPI-013); (7) nếu có gợi ý/PIP đang chạy → khối link sang S2. Footer sticky theo quyền: [Gửi thắc mắc] (nhân sự, trong window) · [Chấm tay] [Chốt] (Manager) · [Đánh dấu xử lý outlier] (HR_L2).
- **S2:** header: tên + manager + StatusBadge + mốc hiện tại. Khối: (1) lý do + kỳ KPI nguồn (link T2); (2) mục tiêu đo được; (3) 3 mốc 30/60/90 — mỗi node: due date, tiêu chí, kết quả, người đánh giá, ngày; mốc trễ → WarningIndicator đỏ; (4) nhật ký coaching (timeline — thiếu ack nhân sự tô cảnh báo); (5) lịch sử tạm dừng/khôi phục + mốc tính lại; (6) timeline audit (mọi lượt xem/sửa — Restricted); (7) khối kết luận khi có (`pip_conclusion` — outcome, quyết định BOD, legal_note). Footer sticky theo quyền: [Đề xuất] [Duyệt/Từ chối] [Ghi coaching] [Đánh giá mốc] [Tạm dừng] — Esc đóng, trả focus về hàng. HR_L1: mở S2 bị chặn — chỉ thấy hàng trạng thái trong T4 (PEP ẩn, không disabled).
- **S3:** metadata phiên (ngày, người lập, người dự), bảng quyết định từng điểm (trước → sau + lý do), link tới từng S1 tương ứng, audit trail điều chỉnh.
- **S4:** từng cờ: nhân sự, khoảng tuần `week_from/to`, utilization % (biểu đồ mini từ `/api/v1/erp/capacity` — vàng 90%, đỏ 100%), trạng thái miễn phạt on-time (`exempt_on_time`), TL giải trình + deadline tái cân bằng 5 NLV (WaitingOn), count cờ/quý — ≥3 cờ → banner "HR_L2 xem xét headcount" (BR-KPI-009).

---

## 5. VIEW MODES

1 surface `/hr/kpi` — role views khác nhau ở scope dữ liệu + nút (Navigation: "HR_L2 calibration · quản lý team · BOD view").

| Mode | UI-ID | Hiện khi nào | Khác biệt |
|------|-------|--------------|-----------|
| Nhân sự | `UI-WEB-KPI-001-M1` | Role thường (SALES_L1–L3, OPS_*, FIN_L1…) | Mặc định T2 khóa filter "của mình"; chỉ S1 của mình + gửi thắc mắc trong window; T1/T3/T5 ẩn; T4 chỉ PIP của mình (read + xác nhận coaching D15) |
| TL/Manager | `UI-WEB-KPI-001-M2` | SALES_L4–L5, Lead track | T2 scope team mình: chấm tay (D4), nhận xét, chốt L1–L3 (D7); T3 read-only + queue team; T4: đề xuất (D9), coaching (D15), mốc 30/60 (D11), soạn tạm dừng (D14); không thấy T5 |
| HR_L1 | `UI-WEB-KPI-001-M3` | Role HR_L1 | Mở/đóng kỳ, công bố, theo dõi tiến độ + cờ quá tải (T1 + header actions); toàn kỳ read; T4 chỉ trạng thái danh sách (không mở S2 — Restricted); không chấm tay/không chốt |
| HR_L2 | `UI-WEB-KPI-001-M4` | Role HR_L2 | Full: cấu hình (D2/D3), calibration + biên bản (D5), trình BOD (D6), duyệt PIP (D10), mốc 90 + kết luận (D12), tạm dừng/khôi phục (D14); thấy lương từ tham chiếu §6 (REQ-HR-010); mặc định T3 khi có outlier |
| BOD | `UI-WEB-KPI-001-M5` | BOD_CEO/BOD_CFO_CTO | Nhận duyệt: trọng số (D3 bước 2), chốt L4–L5 (D6), loại trừ dự án khẩn (D8), quyết định PIP không đạt (D13); view T1/T3/T4 read + S3; không thao tác soạn |
| SYS_ADMIN | `UI-WEB-KPI-001-M6` | Role SYS_ADMIN | Chỉ khối trạng thái kỳ machine-state + link `/admin/audit` (truy vết audit điều chỉnh/không xem dữ liệu cá nhân); mọi tab dữ liệu ẩn |

---

## 6. API ENDPOINTS

> Endpoint thật từ `api-contract.md` §6.5 (COMP-ERP-005 — API-ERP-062/069/070/071), §6.7 (API-ERP-075/076), §7 (event `kpi.below_threshold`) + CORE (audit/PII). WEB render machine-state từ CORE; pagination server-side 20/50/100 cho mọi list; cấm nhập điểm tay 3 trụ cột (BR-KPI-001 — không có endpoint ghi, đúng thiết kế).

| Khi nào | Method | Endpoint | Tham số / Ghi chú |
|---------|--------|----------|-------------------|
| Chi tiết kỳ + trạng thái machine-state (header, T1) | GET | `/api/v1/erp/kpi-periods/{id}` | HR/quản lý — kèm mốc thời gian `opened_at/closed_at/published_at/locked_at` — API-ERP-070 |
| Đóng kỳ / công bố / chuyển calibration (header actions) | POST | `[NEEDS_REVIEW: thiếu POST /api/v1/erp/kpi-periods/{id}/transitions]` | `OPEN→AGGREGATED→REVIEW_WINDOW→CALIBRATION`; API-ERP-070 chỉ khai GET + calibrate/finalize |
| Chạy calibration (T3, HR_L2 + ban điều hành) | POST | `/api/v1/erp/kpi-periods/{id}/calibrate` | Chỉ nhận khi sạch thắc mắc chưa phản hồi — API-ERP-070 |
| Chốt kỳ / khóa khi 100% chốt (T3, HR_L2) | POST | `/api/v1/erp/kpi-periods/{id}/finalize` | `→ FINALIZED → LOCKED` — API-ERP-070 |
| Danh sách kỳ (chọn kỳ trên header) | GET | `[NEEDS_REVIEW: thiếu GET /api/v1/erp/kpi-periods]` | Cần filter `period,status` + sort |
| Bảng điểm kỳ (T2) + dữ liệu gốc (S1) | GET | `[NEEDS_REVIEW: thiếu GET /api/v1/erp/kpi-periods/{id}/scores]` | 3 trụ cột read-only + weighted_total + `status`; filter `team,track,status,outlier,has_dispute,overload`; sort; pagination; kèm nguồn tổng hợp per trụ cột |
| Điểm cá nhân + luồng thắc mắc (S1) | GET | `[NEEDS_REVIEW: thiếu GET /api/v1/erp/kpi-scores/{id}]` | 100% dữ liệu gốc + rubric chấm tay + history audit |
| Gửi thắc mắc (D1) | POST | `[NEEDS_REVIEW: thiếu POST /api/v1/erp/kpi-scores/{id}/disputes]` | Window 3 NLV enforce ở CORE; ngoài window → 409 |
| Kết quả đối chiếu thắc mắc (S1) | GET | `[NEEDS_REVIEW: thiếu GET disputes + phản hồi CORE]` | Entity `kpi_dispute` (`content,response,resolved_at`) |
| Chấm tay + nhận xét (D4) | POST | `[NEEDS_REVIEW: thiếu POST /api/v1/erp/kpi-scores/{id}/manual-scores]` | Entity `manual_score_entry` — bắt buộc scorer + ngày + nhận xét |
| Biên bản calibration (D5/S3) | GET/POST | `[NEEDS_REVIEW: thiếu GET/POST /api/v1/erp/kpi-periods/{id}/calibration-minutes]` | Entity `calibration_minutes` — điều kiện trình BOD |
| Trọng số theo Level + version (T5) | GET/POST | `[NEEDS_REVIEW: thiếu GET/POST /api/v1/erp/kpi-weight-configs]` | SCD2, hiệu lực đầu năm tài chính, đề xuất → BOD duyệt (cần transitions) |
| Rubric chấm tay (D2/T5) | GET/POST | `[NEEDS_REVIEW: thiếu GET/POST /api/v1/erp/kpi-rubrics]` | Khai báo trước kỳ — điều kiện mở kỳ |
| Hàng đợi gợi ý PIP (T4) | GET | `/api/v1/erp/pips?status=SUGGESTED` | `[NEEDS_REVIEW: thiếu GET /api/v1/erp/pips — contract chỉ khai POST/PATCH]` — nguồn event `kpi.below_threshold` |
| Đề xuất mở PIP (D9) | POST | `/api/v1/erp/pips` | Đủ hồ sơ (mục tiêu + 3 mốc + lịch coaching) — API-ERP-071 `[NEEDS_REVIEW: lệch vai — contract ghi HR_L2, spec §4 cho Manager đề xuất; cần chốt]` |
| Duyệt/từ chối/bỏ qua/tạm dừng/khôi phục/kết luận/trình BOD (D10–D14) | PATCH | `/api/v1/erp/pips/{id}` | Transitions machine-state §6 FEAT-ERP-KPI-002 — API-ERP-071 |
| Đánh giá mốc 30/60/90 (D11/D12) | POST | `/api/v1/erp/pips/{id}/checkpoints` | Mốc 90 bắt buộc HR_L2 xác nhận trước kết luận — API-ERP-071 |
| Danh sách + chi tiết PIP (T4/S2) | GET | `[NEEDS_REVIEW: thiếu GET /api/v1/erp/pips/{id}]` | Restricted — scope theo vai; audit từng lượt xem |
| Ghi coaching + ack nhân sự (D15) | POST/GET | `[NEEDS_REVIEW: thiếu /api/v1/erp/pips/{id}/coaching-sessions]` | Entity `pip_coaching_session` — nhịp ≥2 tuần đo ở CORE |
| Utilization cờ quá tải (S4) | GET | `/api/v1/erp/capacity` | Filter nhân sự/đội; vàng 90% đỏ 100% — API-ERP-069 `[NEEDS_REVIEW: entity overload_flag + exempt_on_time chưa có endpoint riêng]` |
| Track/Level/vai chính hiện hành (T2/S1) | GET | `/api/v1/erp/employees/{id}` | SCD2; lương masked theo classification — API-ERP-062 |
| Nhắc SLA chốt + escalation (header, T3) | GET | `/api/v1/erp/notifications` | Role sở hữu object — API-ERP-074 |
| Run history job KPI aggregate (T1, read-only) | GET | `/api/v1/erp/jobs` | Job "KPI aggregate" trong registry — API-ERP-075 |
| Re-run aggregate (SYS_ADMIN) | POST | `/api/v1/erp/jobs/{key}/trigger` | Idempotency key; audit `triggered_by=manual` — API-ERP-076 |
| Audit điều chỉnh sau calibration (S1/S2/S3) | GET | `/core/audit/objects/:objectId/timeline` | Theo vai sở hữu object — API-CORE-030 |
| Mask rule lương (render masked) | GET | `/core/pii/mask-configs` | API-CORE-034 — BR-KPI-012/BR-PIP-011 |

**[NEEDS_REVIEW] các điểm thiếu endpoint (KHÔNG bịa — cần bổ sung vào api-contract):**
- `[NEEDS_REVIEW: thiếu GET /api/v1/erp/kpi-periods (danh sách kỳ) + POST transitions đóng kỳ/công bố/chuyển calibration — API-ERP-070 chỉ khai GET + calibrate/finalize]`
- `[NEEDS_REVIEW: thiếu GET /api/v1/erp/kpi-periods/{id}/scores (bảng điểm kỳ 3 trụ cột + trạng thái chốt, filter/sort/pagination) và GET /api/v1/erp/kpi-scores/{id} (100% dữ liệu gốc + audit)]`
- `[NEEDS_REVIEW: thiếu endpoint disputes (POST gửi trong window 3 NLV + GET trạng thái đối chiếu/phản hồi CORE — entity kpi_dispute)]`
- `[NEEDS_REVIEW: thiếu POST manual-scores (chấm tay — entity manual_score_entry bắt buộc scorer + ngày + nhận xét)]`
- `[NEEDS_REVIEW: thiếu GET/POST calibration-minutes (biên bản — điều kiện chặn trình BOD)]`
- `[NEEDS_REVIEW: thiếu endpoint kpi-weight-configs (version SCD2 + đề xuất → BOD duyệt) và kpi-rubrics (khai báo trước kỳ)]`
- `[NEEDS_REVIEW: thiếu GET /api/v1/erp/pips và GET /api/v1/erp/pips/{id} (danh sách + chi tiết Restricted) — API-ERP-071 chỉ khai POST/PATCH]`
- `[NEEDS_REVIEW: thiếu /api/v1/erp/pips/{id}/coaching-sessions (ghi + ack nhân sự + đo nhịp 2 tuần)]`
- `[NEEDS_REVIEW: thiếu endpoint overload_flag (cờ >100% ≥2 tuần + exempt_on_time + TL giải trình) — GET /capacity chỉ trả utilization]`
- `[NEEDS_REVIEW: lệch vai tạo PIP — API-ERP-071 ghi permission HR_L2, FEAT-ERP-KPI-002 §4 cho Manager trực tiếp đề xuất (HR_L2 duyệt); cần chốt trong contract]`

---

## 7. UI-ID Registry

| UI-ID | Loại | Mô tả |
|-------|------|-------|
| `UI-WEB-KPI-001` | Main Page | KPI & Performance — 1 surface 5 tab, route `/hr/kpi`, badge `{pip_dang_chay}`, chọn kỳ trên header |
| `UI-WEB-KPI-001-T1` | Tab | Tổng quan — dashboard W4: trạng thái kỳ, đã chốt, outlier, cờ quá tải, PIP; widget click → worklist |
| `UI-WEB-KPI-001-T2` | Tab | Điểm & dữ liệu gốc — bảng R6 3 trụ cột (nguồn ghi rõ) + Sheet S1 minh bạch + thắc mắc 3 NLV |
| `UI-WEB-KPI-001-T3` | Tab | Calibration & chốt — lifecycle kỳ, so sánh chéo team, biên bản, SLA 10/15 NLV, loại trừ dự án khẩn |
| `UI-WEB-KPI-001-T4` | Tab | PIP 30-60-90 — hàng đợi gợi ý, duyệt ≤5 NLV, mốc 30/60/90, coaching ≥2 tuần, kết luận + BOD |
| `UI-WEB-KPI-001-T5` | Tab | Cấu hình — trọng số theo Level (SCD2), rubric, lịch kỳ, khung vị trí §5–§6, đề xuất đổi trọng số |
| `UI-WEB-KPI-001-D1` | Dialog | Gửi thắc mắc điểm (window 3 NLV, dẫn chứng, CORE đối chiếu) |
| `UI-WEB-KPI-001-D2` | Dialog | Cấu hình khung kỳ — trọng số + rubric + lịch (thiếu rubric chặn mở kỳ) |
| `UI-WEB-KPI-001-D3` | Dialog | Đề xuất đổi trọng số → BOD duyệt (version hóa, hiệu lực đầu năm tài chính) |
| `UI-WEB-KPI-001-D4` | Dialog | Nhập điểm chấm tay + nhận xét (scorer + ngày + nhận xét bắt buộc; không có ô 3 trụ cột) |
| `UI-WEB-KPI-001-D5` | Dialog | Lập biên bản calibration (người dự, quyết định trước/sau, lý do) |
| `UI-WEB-KPI-001-D6` | Dialog | Trình BOD + chốt L4–L5/top-bottom/biên (≤15 NLV, cần biên bản) |
| `UI-WEB-KPI-001-D7` | Dialog | Chốt L1–L3 (Manager, ≤10 NLV, bulk theo team) |
| `UI-WEB-KPI-001-D8` | Dialog | Duyệt loại trừ dự án khẩn (BOD, trước hoặc trong 24h) |
| `UI-WEB-KPI-001-D9` | Dialog | Đề xuất mở PIP (mục tiêu đo được + 3 mốc + lịch coaching ≥2 tuần) |
| `UI-WEB-KPI-001-D10` | Dialog | Duyệt / từ chối / bỏ qua PIP (HR_L2, ≤5 NLV, lý do bắt buộc) |
| `UI-WEB-KPI-001-D11` | Dialog | Đánh giá mốc 30/60 (Manager/HR_L2; chặn khi SUSPENDED) |
| `UI-WEB-KPI-001-D12` | Dialog | Xác nhận mốc 90 + kết luận (Đạt → PASSED / Không đạt → ESCALATED) |
| `UI-WEB-KPI-001-D13` | Dialog | Quyết định BOD khi không đạt (điều chuyển / hạ Level SCD2 / chấm dứt HĐLĐ) |
| `UI-WEB-KPI-001-D14` | Dialog | Tạm dừng / khôi phục PIP (đóng băng mốc; khôi phục tính lại 30/60/90) |
| `UI-WEB-KPI-001-D15` | Dialog | Ghi nhận buổi coaching + xác nhận nhân sự (cam kết 2 chiều) |
| `UI-WEB-KPI-001-S1` | Sheet | KPI cá nhân 360 — 3 trụ cột + nguồn + dữ liệu gốc + thắc mắc + audit (right 720px) |
| `UI-WEB-KPI-001-S2` | Sheet | PIP chi tiết — mốc 30/60/90, coaching log, suspend history, audit Restricted (right 720px) |
| `UI-WEB-KPI-001-S3` | Sheet | Biên bản calibration (right 480px) |
| `UI-WEB-KPI-001-S4` | Sheet | Cờ quá tải — utilization, miễn phạt on-time, giải trình TL 5 NLV, ≥3 cờ → headcount (right 480px) |
| `UI-WEB-KPI-001-M1` | View Mode | Nhân sự — điểm của mình + thắc mắc; PIP của mình read |
| `UI-WEB-KPI-001-M2` | View Mode | TL/Manager — team view: chấm tay, chốt L1–L3, đề xuất PIP, coaching, mốc 30/60 |
| `UI-WEB-KPI-001-M3` | View Mode | HR_L1 — điều phối kỳ + cờ quá tải; PIP chỉ trạng thái (Restricted) |
| `UI-WEB-KPI-001-M4` | View Mode | HR_L2 — full: cấu hình, calibration, trình BOD, duyệt PIP, mốc 90, kết luận |
| `UI-WEB-KPI-001-M5` | View Mode | BOD — duyệt trọng số, chốt L4–L5, loại trừ khẩn, quyết định PIP không đạt |
| `UI-WEB-KPI-001-M6` | View Mode | SYS_ADMIN — trạng thái kỳ + audit log, không dữ liệu cá nhân |

---

## Tài Liệu Liên Quan

| Nội dung | File | Ghi chú |
|---------|------|---------|
| Tính năng: KPI 3 trụ cột + calibration | `../../../../phase2-features/bcerp-web/kpi-performance/kpi-3-tru-cot-tu-tong-hop-calibration.md` | FEAT-ERP-KPI-001 |
| Tính năng: PIP 30-60-90 | `../../../../phase2-features/bcerp-web/kpi-performance/pip-30-60-90.md` | FEAT-ERP-KPI-002 |
| API chi tiết | `../../../../phase3-architecture/technical-specs/api-contract.md` | §6.5 COMP-ERP-005 (API-ERP-070/071) + jobs + event `kpi.below_threshold` |
| Design system | `../../../design-system.md` | Tokens + W4 dashboard + ApprovalCard + WaitingOnIndicator |
| Navigation tổng quan | `../../Navigation-bcerp-web.md` | S22 — `/hr/kpi`, badge `{pip_dang_chay}` |
| Screen liên quan | `../hr-core/screens-hr-records.md` | S20 — hồ sơ SCD2 (Level hiện hành lúc đóng kỳ), hạ Level PIP tạo version mới |
| Screen liên quan | `../../ops/capts/screens-capacity-timesheet.md` | S15 — nguồn CAPTS + duyệt timesheet ∥ HR |
| Mobile counterpart | `../../../mobile-internal` | M1 ESS Home — xem điểm cá nhân, xác nhận coaching |
