# Tính Năng: KPI 3 trụ cột tự tổng hợp + calibration

> **Dựa trên:** REQ-HR-007 trong `phase1-business/departments/hr/hr.md` (Phần A — Mục REQ-HR-007; Phần B — B7)
> **Phân hệ:** Nhân sự — Hiệu suất & KPI (SYS-BCERP-WEB)
> **Module:** KPI & Performance (MOD-KPI-PERFORMANCE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/hr/hr.md`, `documents/03_Quy_che_KPI_HR.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/kpi-performance/*.md`, `phase5-implementation/tasks/bcerp-web/kpi-performance/kpi-001-impl.md`

> **Hướng dẫn ID:** FEAT-ID cấp bởi orchestrator lane `bcerp-web--KPI-PERFORMANCE`. Đây là bản riêng cho touchpoint **SYS-BCERP-WEB** của REQ-HR-007 (fan-out 2 hệ thống; counterpart: **SYS-CORE-BACKEND** — nơi chạy tổng hợp tự động và validation cứng; WEB là lớp UI/workflow gọi API core).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-KPI-001 |
| Module | MOD-KPI-PERFORMANCE |
| Yêu cầu nghiệp vụ | REQ-HR-007 — KPI 3 trụ cột tự tổng hợp + calibration |
| Người dùng liên quan | Toàn bộ nhân sự BC (xem điểm của mình qua ESS), TL/Manager — SALES_L4–L5 và Lead các track (review, chốt L1–L3), HR_L1 (điều phối kỳ, cờ quá tải), HR_L2 (cấu hình, calibration, trình BOD), BOD_CEO / BOD_CFO_CTO (chốt L4–L5 và trường hợp biên), SYS_ADMIN (trạng thái kỳ, log) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 3 (Phase3 — theo `_meta/req-registry.json`) |
| Phụ thuộc | REQ-HR-001 (hồ sơ SCD2 — tra Level hiện hành khi đóng kỳ), REQ-HR-009 và dữ liệu DEPT-OPS (task/deliverable/SLA — chỉ đọc qua CORE), REQ-HR-010 (lương Confidential); kết quả kỳ là đầu vào gợi ý PIP của FEAT-ERP-KPI-002 |
| Ghi chú Expert (A7) | hr.md có Mục A7 nhưng A7.3 chưa có nội dung điều chỉnh (chờ Team Expert review); A7.2 chỉ flag REQ-HR-006/009. `[KXN-18]` (quy trình HR trong lifecycle) còn mở — ghi nhận như assumption tại Mục 5, không tự quyết |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cung cấp trên web nội bộ BCERP (Next.js, responsive) toàn bộ giao diện vận hành chu kỳ KPI 3 trụ cột theo quý: cấu hình khung KPI, hiển thị điểm tự tổng hợp từ dữ liệu gốc, tiếp nhận thắc mắc, chạy calibration và chốt điểm. Mọi phép tính và validation cứng do SYS-CORE-BACKEND thực thi ở service layer; WEB chỉ nhập phần được phép (chấm tay, nhận xét, biên bản), điều phối workflow và hiển thị đúng trạng thái machine-state của kỳ.

**Phạm vi:**
- Bao gồm:
  - Cấu hình: trọng số theo Level (w1/w2/w3 + 15% chấm tay), rubric chấm tay, lịch kỳ, khung KPI theo vị trí gắn tier/level của 4 track (nguồn cấu hình biểu mẫu: `documents/03_Quy_che_KPI_HR.md` §5–§6).
  - Đóng kỳ: hiển thị kết quả tự tổng hợp 3 trụ cột (On-time Delivery, Output Volume, Project Target/SLA) và trạng thái khóa dữ liệu kỳ — không có ô nhập điểm tay.
  - ESS minh bạch: nhân sự xem điểm + 100% dữ liệu gốc; gửi thắc mắc trong 3 ngày làm việc; theo dõi phản hồi đối chiếu.
  - Review TL/Manager: phỏng vấn, ghi nhận xét; calibration HR_L2 (so sánh chéo team, outlier, chuẩn hóa thang, biên bản).
  - Chốt điểm theo SLA 10/15 ngày làm việc; trình BOD cho L4–L5 và trường hợp biên.
  - Cờ quá tải (>100% liên tục ≥2 tuần) kèm miễn phạt điểm On-time; báo cáo tổng hợp KPI & phân bố điểm theo quý.
- Không bao gồm:
  - Engine tổng hợp, công thức, validation cứng, khóa dữ liệu — do SYS-CORE-BACKEND (spec counterpart cùng REQ).
  - Workflow PIP 30-60-90 — FEAT-ERP-KPI-002 (tách KPI/PIP: dữ liệu vs. workflow; PIP chỉ nhận gợi ý từ kết quả KPI).
  - Quản trị lương, hoa hồng, salary band, connector tính lương — REQ-HR-006 và chính sách §6 (màn KPI chỉ mask và tham chiếu).
  - Hạ tầng PII (mã hóa, audit log nền, retention) — REQ-HR-010; ghi task/deliverable/timesheet — DEPT-OPS.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | Nhân sự (SALES_L1–L3, OPS_*, FIN_L1) | Xem điểm KPI 3 trụ cột cùng 100% dữ liệu gốc của mình khi kỳ được công bố | Tự kiểm tra tính minh bạch, không bị đánh giá "hộp đen" |
| 2 | Nhân sự | Gửi thắc mắc kèm dẫn chứng trong 3 ngày làm việc | Được CORE đối chiếu dữ liệu gốc và phản hồi trước khi chốt |
| 3 | TL/Manager (SALES_L4–L5, Lead track) | Xem KPI team, phỏng vấn review và ghi nhận xét trên WEB | Đánh giá có ngữ cảnh, lưu vết lời giải thích cho từng điểm |
| 4 | HR_L1 | Mở/đóng kỳ, theo dõi tiến độ review–calibration và cờ quá tải | Điều phối đúng hạn chu kỳ, kịp báo HR_L2 xử lý |
| 5 | HR_L2 | Cấu hình trọng số + rubric trước kỳ, soạn đề xuất đổi trọng số trình BOD | Khung đánh giá bám khung KPI theo vị trí và salary band Q2/2026 hiện hành |
| 6 | HR_L2 | Chạy calibration và lập biên bản trên WEB | Bảo đảm công bằng chéo team, mọi quyết định có biên bản |
| 7 | BOD_CEO / BOD_CFO_CTO | Xem hồ sơ calibration, điểm L4–L5 và top/bottom, chốt trong 15 ngày làm việc | Quyết định cuối dựa trên dữ liệu đã chuẩn hóa, đúng SLA |
| 8 | SYS_ADMIN | Xem trạng thái machine-state các kỳ và audit log điều chỉnh | Vận hành kỹ thuật, truy vết sự cố không cần xem dữ liệu cá nhân |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Enforce chính ở service layer của SYS-CORE-BACKEND; WEB là bề mặt hiển thị + nhập liệu được phép.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-KPI-001 | Cấm nhập điểm tay cho 3 trụ cột (On-time Delivery, Output Volume, Project Target/SLA) — điểm chỉ do CORE tự tổng hợp từ dữ liệu gốc khi đóng kỳ. | CORE từ chối ghi (validation cứng); WEB không hiển thị ô nhập cho 3 trụ cột. |
| BR-KPI-002 | Công thức: `KPI kỳ = On-time×w1 + Output Volume×w2 + SLA/Target×w3 + Chấm tay×15%`; w1–w3 theo Level hiện hành tại thời điểm đóng kỳ, đọc từ hồ sơ SCD2 (L1 20/50/15 → L5 20/10/55). | Sai/không tra được trọng số hoặc Level → chặn chuyển sang chốt; cảnh báo HR_L2. |
| BR-KPI-003 | Đổi trọng số: HR_L2 đề xuất → BOD duyệt; hiệu lực đầu năm tài chính; version hóa, không sửa đè version cũ. | WEB chỉ cho soạn đề xuất; áp trọng số mới chưa qua BOD bị CORE từ chối. |
| BR-KPI-004 | Thành phần chấm tay phải khai báo trọng số + rubric trước kỳ; mỗi điểm chấm tay có người chấm, ngày chấm, nhận xét. | Thiếu rubric trước kỳ → không mở được kỳ; điểm thiếu metadata → từ chối lưu. |
| BR-KPI-005 | Khi đóng kỳ, CORE tự tổng hợp và khóa dữ liệu gốc của kỳ (machine-state `AGGREGATED`). | WEB hiển thị "đã khóa"; ghi dữ liệu gốc quá khứ bị từ chối và ghi log. |
| BR-KPI-006 | Công bố minh bạch: nhân sự xem trước điểm + 100% dữ liệu gốc trên ESS; thắc mắc chỉ nhận trong 3 ngày làm việc; CORE đối chiếu và phản hồi. | Hết window → form đóng; kỳ không sang calibration khi còn thắc mắc chưa phản hồi. |
| BR-KPI-007 | Calibration HR_L2 bắt buộc trước khi trình BOD (so sánh chéo team, xử lý outlier, chuẩn hóa thang chấm tay) cho L4–L5 và top/bottom; biên bản (người dự, quyết định, lý do) lưu hệ thống; điều chỉnh sau calibration phải qua audit log. | Không có biên bản → không chuyển sang chốt; điều chỉnh không log bị từ chối. |
| BR-KPI-008 | Chốt sau calibration: L1–L3 do Manager chốt trong 10 ngày làm việc; L4–L5 và trường hợp biên do BOD chốt trong 15 ngày làm việc. | Quá hạn → nhắc + escalate; kỳ không khóa khi còn điểm chưa chốt. |
| BR-KPI-009 | Quá tải: Utilization >100% liên tục ≥2 tuần → cờ tự động và miễn phạt điểm On-time cho trễ do quá tải; TL giải trình + tái cân bằng trong 5 ngày làm việc; ≥3 cờ/quý → HR_L2 xem xét headcount. | Trễ do quá tải mà bị trừ điểm → nhân sự khiếu nại; xác nhận xong bắt buộc hoàn trả điểm. |
| BR-KPI-010 | Khung KPI theo từng vị trí + salary band Q2/2026 (`documents/03_Quy_che_KPI_HR.md` §5–§6) là nguồn cấu hình biểu mẫu KPI: bảng ON/OFF theo % hoàn thành KPI trung bình nhiều tháng, bảng trọng số KPI (%Hoàn thành × Trọng số → % Quy đổi chung), bậc Mức Level/Rank hoa hồng — theo từng vị trí (21 sheet nguồn). | Biểu mẫu kỳ không map khung vị trí §5–§6 → không phát hành kỳ; phải đối chiếu lại nguồn. |
| BR-KPI-011 | Đánh giá gắn tier/level theo 4 track: KD (KD-1..5), BO (BO-1..4), HR (HR-1..4), MKT (MK-1..4); trọng số và biểu mẫu theo career_level hiện hành. | Gán sai track/level → chặn chốt, yêu cầu HR_L2 sửa hồ sơ (SCD2) trước. |
| BR-KPI-012 | Dữ liệu lương mức Confidential (REQ-HR-010): màn KPI không hiển thị lương cá nhân; thành phần thu nhập/hoa hồng tham chiếu §6 luôn masked; HR_L1 không xem lương. | Truy vấn gỡ mask → CORE chặn + audit log bất biến (ai — khi nào). |
| BR-KPI-013 | Ngoại lệ: mới <30 ngày — định tính; nghỉ dài ≥1 tháng — prorate/miễn; dự án khẩn — BOD duyệt loại trừ (trước hoặc trong 24h); thử việc chỉ áp Output Volume + tuân thủ (70/30), không PIP. | Trụ cột thiếu dữ liệu với đối tượng ngoại lệ → đánh dấu "định tính/prorate/loại trừ", loại khỏi tổng hợp. |
| BR-KPI-014 | Đầu vào trụ cột 3 (Project Target/SLA) đọc từ dữ liệu dự án và SLA breach của DEPT-OPS qua CORE — HR chỉ đọc (handoff B8: OPS → HR dữ liệu SLA cho kỳ KPI). | Thiếu dữ liệu SLA kỳ → không đóng kỳ; cảnh báo trễ cho HR_L1 và đầu mối OPS. |

---

## 4. Phân Quyền

| Hành động | Nhân sự (SALES_L1–L3, OPS_*, FIN_L1) | TL/Manager (SALES_L4–L5) | HR_L1 | HR_L2 | BOD (BOD_CEO/BOD_CFO_CTO) | SYS_ADMIN |
|-----------|--------------------------------------|--------------------------|-------|-------|----------------------------|-----------|
| Xem điểm + dữ liệu gốc của mình | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Xem điểm team mình | ❌ | ✅ | ✅ (toàn công ty) | ✅ | ✅ | ❌ |
| Gửi thắc mắc (trong 3 ngày LV) | ✅ (của mình) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Ghi nhận xét / nhập điểm chấm tay | ❌ | ✅ (team mình, được chỉ định) | ❌ | ✅ | ❌ | ❌ |
| Mở/đóng kỳ, theo dõi chu kỳ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ |
| Soạn đề xuất đổi trọng số + rubric | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Duyệt đổi trọng số | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Chạy calibration + lập biên bản | ❌ | ❌ | ❌ (xem biên bản) | ✅ | ❌ | ❌ |
| Chốt L1–L3 (≤10 ngày LV) | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ |
| Chốt L4–L5 / biên (≤15 ngày LV) | ❌ | ❌ | ❌ | ✅ (trình) | ✅ | ❌ |
| Duyệt loại trừ dự án khẩn | ❌ | ✅ (soạn) | ❌ | ✅ (trình) | ✅ | ❌ |
| Xuất báo cáo tổng hợp KPI (không chứa lương) | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ |
| Xem lương cá nhân từ màn KPI | ❌ (masked) | ❌ (masked) | ❌ | ✅ (REQ-HR-010) | ✅ (REQ-HR-010) | ❌ |
| Sửa/xóa kỳ đã khóa | ❌ | ❌ | ❌ | ❌ (chỉ điều chỉnh có biên bản + audit log) | ❌ | ❌ |

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- Điểm outlier chéo team → bắt buộc qua calibration HR_L2 kèm lý do ghi biên bản; hệ thống tự đánh dấu outlier để HR_L2 không bỏ sót.
- Dữ liệu OPS (task/deliverable/SLA) trễ/thiếu đến hạn đóng kỳ → kỳ không chuyển `AGGREGATED`; cảnh báo trễ cho HR_L1 và đầu mối OPS.
- Nhân sự nghỉ việc giữa kỳ → điểm prorate đến ngày làm việc cuối; kỳ vẫn chốt; hồ sơ gắn trạng thái nhân sự tương ứng.
- Đổi Level giữa kỳ → trọng số theo Level hiện hành tại thời điểm đóng kỳ (SCD2), không tính lại quá khứ.
- Kiêm nhiều vai → HR_L2 chọn vai chính để áp biểu mẫu; chưa chọn → không phát hành kỳ cho nhân sự đó (assumption của spec, HR_L2 xác nhận khi cấu hình, không tự quyết thay chủ dự án).
- Thắc mắc quá hạn 3 ngày làm việc → form đóng; chỉ HR_L2 mở ngoại lệ có lý do lưu hồ sơ.
- Thử việc → chỉ hiển thị Output Volume + tuân thủ (70/30); không sinh PIP từ kỳ này (nối FEAT-ERP-KPI-002).
- Bộ mã 4 track (KD/BO/HR/MKT) độc lập với role taxonomy 42-role/13-track của PMS (`03_Quy_che_KPI_HR.md` §4) → cần bảng đối chiếu khi cấu hình; map lệch → chặn phát hành kỳ.
- `[KXN-18]` (còn mở): vị trí quy trình HR trong lifecycle v2.3 chưa chốt (nguồn 07 §3.3 ghi HR vận hành capacity settings và KPI 3 trụ cột, không xuất hiện trong lifecycle) — spec thiết kế theo hr.md B7; khi `[KXN-18]` chốt phải rà lại mapping nguồn dữ liệu, KHÔNG tự quyết thay.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Kỳ KPI (`kpi_cycle`) — WEB hiển thị đúng machine-state ở mọi màn hình (badge trạng thái, nút hành động theo từng trạng thái).

**Sơ đồ trạng thái:**
```
[OPEN] ──(đóng kỳ: CORE tự tổng hợp + khóa dữ liệu gốc)──► [AGGREGATED]
[AGGREGATED] ──(công bố)──► [REVIEW_WINDOW]
[REVIEW_WINDOW] ──(thắc mắc)──► [DISPUTE] ──(CORE đối chiếu + phản hồi)──► [REVIEW_WINDOW]
[REVIEW_WINDOW] ──(hết 3 ngày làm việc)──► [CALIBRATION]
[CALIBRATION] ──(chốt L1–L3 bởi Manager, ≤10 ngày LV)──► [FINALIZED]
[CALIBRATION] ──(trình BOD: L4–L5 / top-bottom / biên)──► [BOD_APPROVAL] ──(BOD chốt, ≤15 ngày LV)──► [FINALIZED]
[FINALIZED] ──(khóa kỳ khi 100% điểm đã chốt)──► [LOCKED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `OPEN` | Đóng kỳ (tự tổng hợp) | `AGGREGATED` | Hệ thống (CORE job) | Đủ dữ liệu 3 trụ cột + rubric đã khai báo trước kỳ |
| `AGGREGATED` | Công bố | `REVIEW_WINDOW` | HR_L1, HR_L2 | Điểm + 100% dữ liệu gốc hiển thị đủ trên ESS |
| `REVIEW_WINDOW` | Gửi thắc mắc | `DISPUTE` | Nhân sự (của mình) | Trong 3 ngày làm việc kể từ công bố |
| `DISPUTE` | Phản hồi đối chiếu | `REVIEW_WINDOW` | Hệ thống (CORE) | Có câu trả lời cho từng thắc mắc |
| `REVIEW_WINDOW` | Hết window → calibration | `CALIBRATION` | HR_L2 | Không còn thắc mắc chưa phản hồi |
| `CALIBRATION` | Chốt L1–L3 | `FINALIZED` | Manager (SALES_L4–L5) | Có biên bản calibration; trong 10 ngày làm việc |
| `CALIBRATION` | Trình BOD | `BOD_APPROVAL` | HR_L2 | Áp dụng L4–L5, top/bottom, trường hợp biên |
| `BOD_APPROVAL` | Chốt | `FINALIZED` | BOD_CEO / BOD_CFO_CTO | Quyết định + lý do lưu hồ sơ; trong 15 ngày làm việc |
| `FINALIZED` | Khóa kỳ | `LOCKED` | Hệ thống (CORE job) | 100% nhân sự thuộc kỳ đã có điểm chốt |

**Quy tắc:**
- Không quay về trạng thái trước; `LOCKED` là trạng thái kết thúc — chỉ đọc và báo cáo.
- Từ `CALIBRATION` trở đi, mọi điều chỉnh điểm kèm biên bản/audit log (ai — khi nào — giá trị trước/sau); sửa sau `FINALIZED` chỉ theo quyết định BOD có biên bản riêng.
- `REVIEW_WINDOW` không rút ngắn; `DISPUTE` không kéo dài window (thắc mắc muộn xử lý theo ngoại lệ Mục 5).

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `kpi_cycle` | `id`, `period`, `status`, `opened_at`, `closed_at`, `published_at`, `locked_at` | — | Machine-state theo Mục 6 |
| `kpi_weight_config` | `career_level`, `w_on_time`, `w_output`, `w_sla`, `w_manual`, `effective_from/to`, `approved_by` | FK → `career_level` | SCD2; hiệu lực đầu năm tài chính |
| `kpi_score` | `employee_id`, `cycle_id`, `on_time_score`, `output_score`, `sla_score`, `manual_score`, `weighted_total`, `status` | FK → `kpi_cycle`, `employee` | 3 trụ cột read-only, CORE tổng hợp |
| `kpi_rubric` | `code`, `criterion`, `weight`, `content`, `declared_at` | — | Khai báo trước kỳ |
| `manual_score_entry` | `kpi_score_id`, `rubric_id`, `scorer_id`, `score`, `comment`, `scored_at` | FK → `kpi_score`, `kpi_rubric` | Bắt buộc người chấm + ngày + nhận xét |
| `kpi_dispute` | `kpi_score_id`, `employee_id`, `raised_at`, `content`, `response`, `resolved_at` | FK → `kpi_score` | Window 3 ngày làm việc |
| `calibration_minutes` | `cycle_id`, `attendees`, `decision`, `reason`, `created_by`, `created_at` | FK → `kpi_cycle` | Bắt buộc với L4–L5, top/bottom |
| `overload_flag` | `employee_id`, `week_from/to`, `utilization_pct`, `exempt_on_time`, `resolved_at` | FK → `employee` | >100% ≥2 tuần; ≥3 cờ/quý → xem headcount |
| `career_track` / `career_level` | `track` (KD/BO/HR/MKT), `level_code`, `salary_band_ref` | — | Nguồn `03_Quy_che_KPI_HR.md` §4–§6; đối chiếu role taxonomy PMS |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được.*
> **Ghi chú:** Acceptance Criteria được điền chi tiết ở Phase 5 (implementation tasks). Bảng dưới là phác thảo sơ bộ Phase 2.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Tổng hợp tự động, cấm điểm tay | Kỳ `OPEN`, đủ dữ liệu OPS + rubric đã khai báo | HR_L1 đóng kỳ | CORE tự tổng hợp 3 trụ cột; WEB không có ô nhập điểm tay; kỳ sang `AGGREGATED` | [ ] |
| SC-002: Thắc mắc trong window | Kỳ `REVIEW_WINDOW`, ngày thứ 2 từ công bố | Nhân sự gửi thắc mắc | Chuyển `DISPUTE`; CORE đối chiếu và phản hồi | [ ] |
| SC-003: Calibration bắt buộc | Kỳ có điểm L4–L5 hoặc top/bottom | HR_L2 trình BOD không có biên bản | Hệ thống chặn, yêu cầu lập biên bản | [ ] |
| SC-004: Chốt đúng SLA | Kỳ `CALIBRATION` | Manager chốt L1–L3 ngày thứ 11 | Đã nhắc/escalate; ghi nhận vi phạm SLA chốt | [ ] |
| SC-005: Quá tải miễn phạt On-time | Utilization >100% ≥2 tuần, có trễ deadline | Đóng kỳ | Cờ sinh tự động; On-time không bị trừ phần trễ do quá tải | [ ] |
| SC-006: Lương luôn masked | Màn KPI có tham chiếu thu nhập §6 | Nhân sự bất kỳ (kể cả HR_L1) mở màn | Thu nhập masked; truy vấn gỡ mask bị chặn + log | [ ] |

> **Liên kết:** SC-001 đến SC-006 đều map đến REQ-HR-007 (Mục 2); SC-006 liên quan thêm REQ-HR-010.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (dữ liệu OPS/SLA, handoff B8, counterpart CORE) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/kpi-performance/*.md` |
| Nguồn domain khung KPI + salary band Q2/2026 | `documents/03_Quy_che_KPI_HR.md` §5–§6 |
| Nguồn REQ + workflow chi tiết | `phase1-business/departments/hr/hr.md` (REQ-HR-007, B7) |
| Spec counterpart (SYS-CORE-BACKEND) | File feature REQ-HR-007 của hệ thống CORE — fan-out cùng REQ |
| Feature liên quan trong module | FEAT-ERP-KPI-002 — PIP 30-60-90 (`pip-30-60-90.md`, cùng thư mục) |
