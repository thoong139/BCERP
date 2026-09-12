# Tính Năng: KPI 3 Trụ Cột Tự Tổng Hợp + Calibration (Core Backend)

> **Dựa trên:** REQ-HR-007 trong `phase1-business/departments/hr/hr.md` (Phần A)
> **Phân hệ:** Nhân sự & Hiệu suất (SYS-CORE-BACKEND) — bản fan-out riêng cho Core Backend; counterpart màn hình: SYS-BCERP-WEB
> **Module:** KPI & Performance (MOD-KPI-PERFORMANCE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/hr/hr.md`, `documents/03_Quy_che_KPI_HR.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/kpi-performance/[screen-group].md`, `phase5-implementation/tasks/core-backend/kpi-performance/FEAT-CORE-KPI-001-impl.md`

> **Hướng dẫn ID:** FEAT-ID được tạo từ REQ-ID theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. Tra `req-registry.json`: REQ-HR-007 có system SYS-CORE-BACKEND, module MOD-KPI-PERFORMANCE — FEAT-ID lane: **FEAT-CORE-KPI-001**.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-KPI-001 |
| Module | MOD-KPI-PERFORMANCE |
| Yêu cầu nghiệp vụ | REQ-HR-007 (KPI 3 trụ cột tự tổng hợp + calibration) |
| Người dùng liên quan | HR_L1, HR_L2; mở rộng: BOD_CEO/BOD_CFO_CTO, quản lý trực tiếp (mã vai registry ở Level L4–L5), toàn bộ nhân viên (đọc qua self-service API) |
| Độ ưu tiên | Cao (HIGH theo req-registry) |
| Giai đoạn | Giai đoạn 3 (Phase3) |
| Phụ thuộc | REQ-HR-001 (hồ sơ nhân sự SCD2 — Level/track hiện hành), REQ-OPS-007 và REQ-HR-009 (dữ liệu task, deliverable, timesheet đã duyệt làm nguồn 3 trụ cột), REQ-HR-010 (RBAC Restricted + audit log bất biến) |
| Ghi chú Expert (A7) | `hr.md` có mục A7 nhưng A7.3 (Điều chỉnh sau đánh giá) đang chờ Team Expert review — chưa có điều chỉnh áp cho REQ-HR-007; 3 điểm A7.2 không đụng trực tiếp REQ này. Áp dụng "quy ước nền Phần B" của HR: SCD2 version hóa, audit log bất biến, lương/cost cá nhân Restricted (REQ-HR-010). |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Domain service headless trên Core Backend tự tổng hợp điểm KPI quý của từng nhân viên từ dữ liệu vận hành khách quan theo công thức "3 trụ cột + chấm tay", loại bỏ triệt để KPI chấm cảm tính. Service đồng thời vận hành luồng review quý minh bạch — đối chiếu thắc mắc — calibration HR_L2 — chốt và khóa dữ liệu kỳ, phục vụ client (WEB/ESS); mọi business rule enforce tại tầng service, không tin UI.

**Phạm vi:**
- Bao gồm:
  - Tự tổng hợp 3 trụ cột theo nhân viên × quý: (1) On-time Delivery từ task deadline; (2) Output Volume từ deliverable đạt QC; (3) Project Target/SLA từ dữ liệu dự án — nguồn đọc-only từ hệ thống OPS, cấm nhập điểm tay ở mọi API.
  - Cấu hình công thức `KPI kỳ = On-time×w1 + Output Volume×w2 + SLA/Target×w3 + Chấm tay×15%` với trọng số theo Level hiện hành tại thời điểm đóng kỳ (chi tiết BR-KPI-002); gắn tier/level theo 4 track nghề KD/BO/HR/MKT, ánh xạ salary band Q2/2026 — nguồn cấu hình biểu mẫu KPI theo vị trí: `documents/03_Quy_che_KPI_HR.md` §5–§6.
  - Quản lý rubric thành phần chấm tay: khai báo trọng số + rubric trước kỳ; mỗi điểm có người chấm, ngày chấm, nhận xét.
  - Luồng review quý: đóng kỳ snapshot khóa → công bố điểm kèm 100% dữ liệu gốc → nhận thắc mắc 3 ngày làm việc → đối chiếu và phản hồi có lưu vết.
  - Calibration HR_L2: so sánh chéo team, xử lý outlier, chuẩn hóa thang chấm tay; bắt buộc với L4–L5 và top/bottom; biên bản (người dự, quyết định, lý do) lưu hệ thống.
  - Chốt điểm: Manager chốt L1–L3 trong 10 ngày làm việc; BOD chốt L4–L5 và biên trong 15 ngày làm việc; khóa dữ liệu kỳ sau hạn chốt.
  - Cờ quá tải: utilization >100% liên tục ≥2 tuần → gắn cờ tự động, miễn phạt điểm On-time; cấp tín hiệu headcount cho HR_L2.
- Không bao gồm:
  - Màn hình WEB/ESS — thuộc SYS-BCERP-WEB (counterpart REQ-HR-007); service vẫn tự enforce mọi rule, client chỉ hiển thị.
  - Workflow PIP 30-60-90 — tách sang FEAT-CORE-KPI-002 (REQ-HR-008).
  - Ghi nhận task, deliverable, timesheet nguồn — thuộc DEPT-OPS (REQ-OPS-007); service chỉ đọc qua interface đọc-only.
  - Quản lý hồ sơ nhân sự, Level, vai (REQ-HR-001) và Cost Rate Card (REQ-HR-006).
  - Tính lương/hoa hồng từ kết quả KPI — service chỉ cung cấp điểm (module lương/thưởng).
  - KPI dự án (Tier scoring PMS) — khái niệm khác; chỉ dùng chung nguồn dữ liệu qua interface đọc `[KXN-9]`.

---

## 2. Luồng Người Dùng (User Stories)

> Touchpoint SYS-CORE-BACKEND: các "hành động" là headless API/domain service; người dùng tương tác qua client (WEB/ESS) nhưng điều kiện nghiệp vụ và quyền hạn do service phán quyết.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | Nhân viên (toàn bộ mã vai registry) | Xem điểm KPI quý và 100% dữ liệu gốc (task, deliverable, SLA) qua API self-service | Kiểm chứng rằng điểm đến từ dữ liệu khách quan, không phải chấm cảm tính |
| 2 | Nhân viên | Gửi thắc mắc trong 3 ngày làm việc sau công bố | Được đối chiếu lại dữ liệu gốc và phản hồi có lưu vết |
| 3 | Quản lý trực tiếp (mã vai registry ở Level L4–L5) | Chấm thành phần định tính đúng rubric đã khai báo trước kỳ, kèm nhận xét | Mỗi điểm chấm tay đều kiểm toán được (người chấm, ngày, nhận xét) |
| 4 | Quản lý trực tiếp | Lấy bảng KPI nhóm mình sau khi tổng hợp | Review quý, phỏng vấn và ghi nhận xét trên client với dữ liệu chuẩn từ service |
| 5 | HR_L2 | Khởi tạo, đóng kỳ và công bố KPI theo chu kỳ quý | Đóng băng snapshot dữ liệu nguồn, chặn thay đổi nguồn làm sai lệch điểm đã công bố |
| 6 | HR_L2 | Chạy calibration: so sánh chéo team, xử lý outlier, chuẩn hóa thang chấm tay | Điểm giữa các team tương đồng trước khi trình BOD; biên bản lưu hệ thống |
| 7 | BOD_CEO/BOD_CFO_CTO | Chốt điểm L4–L5 và trường hợp biên sau calibration; duyệt thay đổi trọng số | Quyết định nhân sự cấp cao dựa trên dữ liệu đã chuẩn hóa và có biên bản |
| 8 | Hệ thống (job định kỳ) | Gắn cờ quá tải utilization >100% ≥2 tuần, miễn phạt điểm On-time tương ứng | Trễ do quá tải không trừng phạt sai cá nhân; HR_L2 có tín hiệu headcount |
| 9 | HR_L1 | Tra cứu, tổng hợp điểm KPI đã công bố phục vụ vận hành hồ sơ | Hỗ trợ TPHR mà không được sửa điểm và không nhìn thấy dữ liệu lương/cost cá nhân |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Mọi rule enforce ở tầng service của Core Backend; client vi phạm nhận lỗi API.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-KPI-001 | Cấm nhập điểm tay 3 trụ cột: On-time Delivery, Output Volume, Project Target/SLA chỉ được sinh tự động từ dữ liệu nguồn tại service layer (validation cứng trên mọi ghi) | API trả 422 + security log; client WEB không hiển thị ô nhập tương ứng nhưng rule vẫn chặn tại service |
| BR-KPI-002 | Công thức: `KPI kỳ = On-time×w1 + Output Volume×w2 + SLA/Target×w3 + Chấm tay×15%`; w1–w3 theo Level hiện hành **tại thời điểm đóng kỳ** đọc từ hồ sơ SCD2 (L1 20/50/15 → L5 20/10/55) | Sai bộ trọng số so với ngày đóng kỳ → chặn phát hành kết quả, bắt tổng hợp lại từ snapshot |
| BR-KPI-003 | Đổi trọng số 3 trụ cột: HR_L2 đề xuất → BOD duyệt; hiệu lực đầu năm tài chính; cấu hình version hóa SCD2, không sửa đè | Cấu hình chưa được BOD duyệt không áp dụng; API cấu hình trả 403 nếu người gọi không đúng vai |
| BR-KPI-004 | Thành phần chấm tay phải khai báo trọng số + rubric trước kỳ; mỗi điểm phải có người chấm, ngày chấm, nhận xét | Kỳ thiếu rubric cho thành phần nào thì thành phần đó không được dùng trong kỳ (tổng hợp chặn, 422); điểm thiếu nhận xét bị từ chối ghi |
| BR-KPI-005 | Đóng kỳ tạo snapshot bất biến và khóa dữ liệu kỳ; công bố kèm 100% dữ liệu gốc cho nhân viên; thắc mắc chỉ nhận trong 3 ngày làm việc; phản hồi đối chiếu phải có log | Dữ liệu nguồn thay đổi sau khi khóa không ảnh hưởng kỳ đã khóa; thắc mắc quá hạn trả 422 kèm lý do rõ ràng |
| BR-KPI-006 | Calibration HR_L2 bắt buộc trước khi trình BOD với L4–L5 và top/bottom; so sánh chéo team, xử lý outlier, chuẩn hóa thang chấm tay; biên bản (người dự, quyết định, lý do) lưu CORE | Thiếu biên bản calibration → chặn trình BOD (422); kỳ không qua calibration bị đánh dấu bất thường trong báo cáo |
| BR-KPI-007 | Mọi điều chỉnh điểm sau calibration phải đi qua audit log bất biến (ai — khi nào — giá trị trước/sau) | Cập nhật ngoài luồng bị cấm; phát hiện can thiệp trực tiếp dữ liệu → security incident, khóa phiên và escalate SYS_ADMIN/HR_L2 |
| BR-KPI-008 | Chốt điểm: L1–L3 do Manager chốt sau calibration trong 10 ngày làm việc; L4–L5 và trường hợp biên do BOD chốt trong 15 ngày làm việc | Quá hạn → escalate BOD/HR_L2 và ghi nhận SLA breach của người chốt vào báo cáo tổng hợp |
| BR-KPI-009 | Utilization >100% liên tục ≥2 tuần → gắn cờ quá tải tự động; trễ do quá tải được miễn phạt điểm On-time; TL giải trình + tái cân bằng trong 5 ngày làm việc; ≥3 cờ/quý → HR_L2 xem xét headcount | Cờ chưa được giải trình đúng hạn → nhắc tự động lặp; miễn phạt chỉ áp dụng đúng khoảng thời gian có cờ |
| BR-KPI-010 | Ngoại lệ tính điểm: nhân sự mới <30 ngày (đánh giá định tính); nghỉ dài ≥1 tháng (prorate/miễn); dự án khẩn do BOD duyệt loại trừ (duyệt trước hoặc trong 24h kể từ phát sinh); thử việc chỉ áp Output Volume + Tuân thủ (70/30), không PIP | Loại trừ không có phê duyệt BOD không được áp dụng (422); kỳ của nhân viên thử việc cấu hình khác 70/30 bị chặn tổng hợp |
| BR-KPI-011 | Điểm KPI gắn tier/level theo 4 track nghề (KD/BO/HR/MKT) và salary band Q2/2026 là dữ liệu Confidential; API không bao giờ trả lương/cost cá nhân; ánh xạ track–level giữ dạng cấu hình, không hardcode | Truy cập không đúng vai → 403 + audit log (xem log cũng bị log); response luôn lọc bỏ trường thu nhập |
| BR-KPI-012 | Dữ liệu nguồn 3 trụ cột đọc từ hệ thống OPS qua interface đọc-only (HR không ghi nội dung task/deliverable); mọi API áp tenant isolation theo tổ chức | Ghi chéo sang nguồn OPS bị từ chối; truy vấn chéo tenant trả 403 + security log |

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry (không có OPS_CX/FIN_COMPL). "Quản lý L4–L5" = các mã vai registry ở Level L4–L5 đang là quản lý trực tiếp hiện hành theo hồ sơ REQ-HR-001.

| Hành động | HR_L1 | HR_L2 | BOD_CEO/BOD_CFO_CTO | Quản lý L4–L5 | Nhân viên (L1–L3) | SYS_ADMIN |
|-----------|-------|-------|---------------------|---------------|-------------------|-----------|
| Xem điểm KPI của mình + dữ liệu gốc | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Xem điểm KPI toàn công ty (sau công bố) | ✅ (mức điểm) | ✅ | ✅ | ❌ (chỉ nhóm mình) | ❌ (chỉ của mình) | ❌ |
| Xem dữ liệu gốc 3 trụ cột của nhân sự khác | ❌ | ✅ | ✅ | ✅ (nhóm mình) | ❌ | ❌ |
| Nhập điểm tay 3 trụ cột | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Chấm thành phần định tính theo rubric | ❌ | ✅ (HR team/backup) | ❌ | ✅ (nhóm mình) | ❌ | ❌ |
| Khai báo rubric + trọng số chấm tay trước kỳ | ❌ | ✅ | ✅ (duyệt) | ❌ | ❌ | ❌ |
| Đề xuất đổi trọng số 3 trụ cột | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Duyệt đổi trọng số 3 trụ cột | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Khởi tạo / đóng kỳ / công bố | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Phản hồi thắc mắc, đối chiếu dữ liệu gốc | ❌ | ✅ | ❌ | ✅ (nhận xét chuyên môn) | ❌ | ❌ |
| Thực hiện calibration + lập biên bản | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Chốt điểm kỳ | ❌ | ❌ | ✅ (L4–L5 + biên, 15 ngày LV) | ✅ (L1–L3 nhóm mình, 10 ngày LV) | ❌ | ❌ |
| Điều chỉnh sau calibration (bắt buộc audit log) | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Xóa / sửa đè dữ liệu kỳ đã khóa | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

Ghi chú: SYS_ADMIN không xem giá trị điểm chi tiết (nhất quán ma trận REQ-HR-010); mọi lượt xem dữ liệu nhạy cảm đều bị log, kể cả lượt xem log.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà service phải xử lý đúng.*

- Nhân sự mới vào <30 ngày trong kỳ → không sinh điểm 3 trụ cột tự động, chuyển đánh giá định tính qua review của quản lý; kỳ lưu với nhãn riêng để báo cáo headcount đủ.
- Nghỉ dài ≥1 tháng (nghỉ phép/ốm đã duyệt) trong kỳ → prorate theo số ngày làm việc thực tế hoặc miễn đánh giá kỳ đó; HR_L2 chọn khi đóng kỳ, lựa chọn ghi log.
- Dự án khẩn → chỉ loại trừ khỏi trụ cột On-time/SLA của cá nhân liên quan khi BOD duyệt trước hoặc trong 24h kể từ phát sinh; không có duyệt thì tính bình thường.
- Nhân viên thử việc → kỳ chỉ tổng hợp Output Volume + Tuân thủ 70/30; không phát sinh gợi ý PIP từ kỳ này (khớp FEAT-CORE-KPI-002).
- Nhân viên đổi Level giữa kỳ → trọng số áp theo Level tại thời điểm đóng kỳ (SCD2); điểm các tháng trước không tính lại retroactive.
- Cờ quá tải ≥3 lần/quý → cảnh báo headcount cho HR_L2 trong báo cáo tổng hợp KPI; hệ thống không tự mở requisition tuyển dụng.
- Thắc mắc chưa phản hồi khi hết hạn → kỳ treo ở trạng thái tranh chấp, chặn chuyển sang calibration, tránh chốt trên dữ liệu đang tranh chấp.
- `[KXN-18]` "Quy trình HR" (file 07 §3.3) còn mở — luồng review/calibration hiện hành theo `hr.md` B7; khi chốt cần đối chiếu lại spec, không tự sửa.
- `[KXN-9]` Ranh giới KPI nhân sự vs. Tier scoring dự án (PMS) chưa được xác nhận — thiết kế giữ interface đọc + bảng ánh xạ 4 track cấu hình được.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Kỳ KPI nhân viên (`kpi_period` — một bản ghi cho mỗi nhân viên × kỳ quý).

**Sơ đồ trạng thái:**
```
[OPEN] ──(job đóng kỳ)──► [AGGREGATED] ──(HR_L2 công bố)──► [PUBLISHED] ──(hết cửa sổ 3 ngày LV)──► [CALIBRATION] ──(chốt đủ)──► [FINALIZED] ──(job khóa kỳ)──► [LOCKED]
                                                            │  ▲
                                                            │  └──(HR_L2 phản hồi đối chiếu xong)
                                                            └──(nhân viên thắc mắc trong 3 ngày LV)──► [DISPUTE_REVIEW]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `OPEN` | Đóng kỳ | `AGGREGATED` | Hệ thống (job) | Snapshot dữ liệu nguồn chốt; bộ trọng số theo Level tại ngày đóng kỳ đã bám vào từng dòng điểm |
| `AGGREGATED` | Công bố | `PUBLISHED` | HR_L2 | Điểm 3 trụ cột hợp lệ; cờ quá tải đã gắn; không còn thành phần thiếu rubric |
| `PUBLISHED` | Ghi thắc mắc | `DISPUTE_REVIEW` | Nhân viên (của mình) | Trong 3 ngày làm việc kể từ công bố; nội dung thắc mắc bắt buộc nhập |
| `DISPUTE_REVIEW` | Phản hồi đối chiếu | `PUBLISHED` | HR_L2 | Kết luận + căn cứ dữ liệu gốc lưu audit log; không sửa điểm nếu dữ liệu gốc đúng |
| `PUBLISHED` | Mở calibration | `CALIBRATION` | Hệ thống (hết cửa sổ) | Không còn thắc mắc đang mở |
| `CALIBRATION` | Chốt | `FINALIZED` | Manager (L1–L3, 10 ngày LV); BOD (L4–L5 + biên, 15 ngày LV) | Biên bản calibration đã lưu trước với L4–L5/top/bottom; mọi điều chỉnh qua audit log |
| `FINALIZED` | Khóa kỳ | `LOCKED` | Hệ thống (job) | Hết hạn chốt; kỳ phát hành dữ liệu cho báo cáo và đầu vào gợi ý PIP |

**Quy tắc:**
- Không thể quay về trạng thái trước; `LOCKED` là trạng thái kết thúc — chỉnh sau khóa chỉ bằng quy trình điều chỉnh có BOD duyệt + audit log, không sửa đè quá khứ.
- Engine gợi ý PIP (FEAT-CORE-KPI-002) chỉ đọc kỳ ở trạng thái `FINALIZED`/`LOCKED`; kỳ đang tranh chấp không kích hoạt gợi ý.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `kpi_period` | `id`, `employee_id`, `period_year`, `period_quarter`, `status`, `published_at`, `locked_at` | FK → `employee` (REQ-HR-001) | 1 nhân viên × quý; trạng thái theo mục 6 |
| `kpi_pillar_score` | `kpi_period_id`, `pillar_code` (`ON_TIME`/`OUTPUT_VOLUME`/`PROJECT_SLA`), `raw_value`, `normalized_score`, `source_refs`, `weight_snapshot` | FK → `kpi_period`; nguồn qua interface đọc OPS | Read-only service, cấm ghi tay (BR-KPI-001) |
| `kpi_manual_score` | `kpi_period_id`, `criterion`, `rubric_id`, `scorer_id`, `score`, `comment`, `scored_at` | FK → `kpi_period`, `kpi_rubric`, `users` | Bắt buộc người chấm + ngày + nhận xét (BR-KPI-004) |
| `kpi_rubric` | `code`, `criterion`, `weight`, `rubric_content`, `effective_from`, `approved_by`, `version` | — | Khai báo trước kỳ; version hóa |
| `kpi_weight_config` | `career_track`, `career_level`, `w_on_time`, `w_output`, `w_sla`, `w_manual`, `effective_from`, `approved_by` | FK → `career_level` (4 track KD/BO/HR/MKT) | SCD2; thay đổi do BOD duyệt (BR-KPI-003); tham chiếu salary band Q2/2026 (03_Quy_che_KPI_HR.md §5–§6) |
| `kpi_calibration_minutes` | `kpi_period_id`, `attendees`, `decision`, `reason`, `created_by`, `created_at` | FK → `kpi_period` | Bất biến; điều kiện trình BOD (BR-KPI-006) |
| `workload_flag` | `employee_id`, `week_start`, `utilization_pct`, `flag_reason`, `resolved_at` | FK → `employee` | Nguồn từ capacity đã duyệt; cơ sở miễn phạt On-time (BR-KPI-009) |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Chi tiết đầy đủ điền ở Phase 5; dưới đây là phác thảo sơ bộ bắt buộc.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Cấm nhập tay điểm trụ cột | Kỳ ở trạng thái `AGGREGATED` | Gọi API ghi trực tiếp giá trị điểm cho `kpi_pillar_score` | HTTP 422 + security log; điểm không đổi | [ ] |
| SC-002: Trọng số theo Level tại ngày đóng kỳ | Nhân viên đổi Level L2→L3 giữa kỳ | Job đóng kỳ chạy | Công thức dùng bộ trọng số của L3 đọc từ SCD2, không dùng L2 | [ ] |
| SC-003: Cửa sổ thắc mắc 3 ngày | Kỳ `PUBLISHED` được 1 ngày làm việc | Nhân viên gửi thắc mắc ngày 2; HR_L2 đối chiếu và phản hồi | Kỳ sang `DISPUTE_REVIEW` rồi về `PUBLISHED`; kết luận có log trong hạn 3 ngày LV | [ ] |
| SC-004: Calibration bắt buộc L4–L5 | Kỳ của nhân viên Level L5 chưa có biên bản | Trình BOD chốt | API 422 + cảnh báo HR_L2; không thể chốt | [ ] |
| SC-005: Miễn phạt điểm quá tải | Utilization 105% liên tục 3 tuần, cờ đã gắn | Tính điểm On-time kỳ đó | Trễ trong giai đoạn có cờ không bị trừ điểm; cờ hiển thị trong báo cáo HR_L2/BOD | [ ] |
| SC-006: Tenant isolation + bảo vệ Confidential | Request chéo tenant hoặc response KPI | Gọi API KPI | 403 + audit log cho chéo tenant; response không chứa lương/cost cá nhân | [ ] |
| SC-007: Thử việc 70/30 | Nhân viên đang thử việc | Job đóng kỳ | Kỳ chỉ có 2 thành phần Output + Tuân thủ (70/30); không phát sinh gợi ý PIP | [ ] |

> **Liên kết:** SC-001→BR-KPI-001, SC-002→BR-KPI-002, SC-003→BR-KPI-005, SC-004→BR-KPI-006, SC-005→BR-KPI-009, SC-006→BR-KPI-011/012, SC-007→BR-KPI-010 — map về REQ-HR-007 (`req-registry.json`, Mục 2).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI (client WEB/ESS — counterpart) | `phase4-ux/bcerp-web/kpi-performance/[screen-group].md` |
| Nguồn domain biểu mẫu KPI/salary band theo vị trí | `documents/03_Quy_che_KPI_HR.md` §5–§6 |
