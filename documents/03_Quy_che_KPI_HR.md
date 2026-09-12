# BC Agency — HR Domain Knowledge Base

### cho module TMS (HR/KPI) — BC Agency PMS

```
version: 1.0
ngày tạo: 2026-09-12
phạm vi: Module TMS (HR/KPI) trong Modular Monolith BC Agency PMS (NestJS + Next.js + PostgreSQL + Prisma)
nguồn: 4 tài liệu HR nội bộ do Nam (CEO) cung cấp — xem mục "Nguồn dữ liệu"
mục đích: Cung cấp context domain đầy đủ cho Claude Code khi thiết kế & build module TMS,
          tương tự cách CLAUDE.md / SYSTEM_DOCS.md cung cấp context cho module PMS.
```

> File này nên được đặt cùng `CLAUDE.md` / `SYSTEM_DOCS.md` trong repo (ví dụ `docs/HR_ERP_HARNESS.md`)
> và upload lại vào đầu phiên Claude Code khi làm việc trên module TMS, theo đúng session-startup
> protocol hiện tại của dự án.

---

## 0. Vai trò trong kiến trúc hệ thống

- BC Agency PMS là **Modular Monolith** gồm 3 module dùng chung DB, giao tiếp qua **EventBus**:
  **PMS** (project lifecycle — đang build) → **CMS** (thuê tài khoản quảng cáo — sau) → **TMS** (HR/KPI — sau cùng).
- Tài liệu này là nguyên liệu domain cho **TMS**: toàn bộ quy trình, biểu mẫu, chính sách lương/KPI,
  danh mục chức danh và nội quy nhân sự hiện có của BC Agency (tất cả đang vận hành thủ công trên
  Google Sheets / HTML tĩnh / PPTX — chưa có hệ thống).
- TMS cần liên kết được với PMS qua EventBus ở tối thiểu 2 điểm đã biết:
  - **Role taxonomy của PMS** (42 roles / 13 tracks, xem `[[lifecycle-and-roles]]`) cần khớp/ánh xạ với
    **career track của TMS** (Kinh doanh / Vận hành / HCNS / Marketing — xem mục 4) — đây là 2 danh sách
    chức danh được xây dựng độc lập, **cần đối chiếu và hợp nhất khi thiết kế bảng `employee`/`role`**.
  - Dữ liệu **hiệu suất/KPI cá nhân** (Tier scoring, AUTO SCORING của PMS) và **KPI nhân sự của TMS**
    (mục 3.3, 5, 6) là hai khái niệm KPI khác nhau (KPI dự án vs. KPI nhân sự) nhưng có thể cùng nguồn
    dữ liệu doanh thu/dự án — cần làm rõ ranh giới khi thiết kế schema.

## 1. Nguồn dữ liệu

| File                               | Loại                    | Nội dung chính                                                                                                 |
| ---------------------------------- | ------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| `hr_process_bc_v39.html`         | HTML tương tác, 533KB | Quy trình HR chuẩn BC Agency v3.9 — 3 Phase, 44 biểu mẫu/template nhúng sẵn                               |
| `CHÍNH_SÁCH_LƯƠNG_2026.xlsx` | Excel, 21 sheet          | Công cụ tính lương/hoa hồng/KPI theo từng vị trí (Sale, Account, HR, Planner, Kế toán, Vận hành...) |
| `WELCOME_TO_BC_-_2026.pptx`      | PPTX, 31 slide           | Bộ giới thiệu công ty cho nhân viên mới — văn hóa, nội quy, chế độ đãi ngộ                      |
| `_BC_-_Mô_tả_công_việc.zip`  | 22 file Excel            | Toàn bộ JD (job description) đang tuyển/đang dùng của BC Agency                                           |

## 2. Vòng đời nhân sự — Quy trình HR chuẩn v3.9

Quy trình gồm **3 Phase liên tục**, không phải 3 giai đoạn tách biệt: Phase 3 là vòng lặp áp dụng
song song trong suốt thời gian nhân viên làm việc.

### Phase 1 — Tuyển dụng

*Từ xác định nhu cầu → phê duyệt → sourcing → phỏng vấn → offer → pre-boarding.*
**SLA tổng: ≤ 30 ngày làm việc.** Metric: Time-to-hire ≤30 ngày · Offer acceptance ≥80% · CV phản hồi 100% trong 5 ngày · Pre-boarding 100% trước Day 1.

| #   | Bước                                       | Mô tả                                                                                                       | SLA                                                     |
| --- | -------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| 1.0 | Lập kế hoạch tuyển dụng                 | Kế hoạch năm từ phòng ban → HCNS tổng hợp → BGĐ phê duyệt · điều chỉnh hàng quý             | Tháng 11–12 (năm) · đầu mỗi quý (điều chỉnh) |
| 1.1 | Xác định nhu cầu & phê duyệt headcount | Phòng ban đề xuất — HR xác minh — Lãnh đạo phê duyệt trước khi mở tuyển                       | ≤ 3 ngày                                              |
| 1.2 | Xây dựng JD & đăng tuyển đa kênh      | Viết JD chuẩn, phân bổ kênh phù hợp từng vị trí — kích hoạt referral nội bộ ngay               | ≤ 2 ngày                                              |
| 1.3 | Sàng lọc CV & phỏng vấn các vòng       | Lọc CV → phone screen → vòng chuyên môn → scorecard → shortlist                                       | ≤ 14 ngày                                             |
| 1.4 | Reference check & background check           | Xác minh thông tin trước offer — bắt buộc từ cấp Trưởng phòng trở lên                           | ≤ 3 ngày                                              |
| 1.5 | Gửi offer & ký hợp đồng                 | Đàm phán, chốt điều khoản, ký HĐLĐ chính thức                                                     | ≤ 3 ngày                                              |
| 1.6 | Pre-boarding (★ mới)                       | Giữ liên lạc ứng viên đã ký từ lúc ký đến Day 1 — 1/5 người ký HĐ "bùng" nếu bị bỏ mặc | 1–4 tuần trước Day 1                                |

### Phase 2 — Đào tạo & Hội nhập

*Từ ngày đầu tiên đến hết năm đầu tiên — onboarding kéo dài 12 tháng.*
Metric: 90-day retention ≥90% · 1-year retention ≥80% · Training completion ≥95% · Checklist Day 1 = 100%.

| #   | Bước                                                      | Mô tả                                                                                                                                                                 | Mốc thời gian |
| --- | ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------- |
| 2.1 | Onboarding ngày đầu & Buddy program                      | Chào đón chính thức, định hướng, kích hoạt buddy — 65% cảm xúc gắn bó hình thành trong tuần đầu                                                    | Day 1           |
| 2.2 | Kế hoạch 15-30-60-90 ngày & đào tạo nghiệp vụ chung | Lộ trình học việc rõ ràng theo từng vị trí (mốc 15 ngày để phát hiện sớm vấn đề); có 3 bộ mốc riêng cho Vận hành/BO, Kinh doanh/KD, và Intern | Tuần 1–12     |
| 2.3 | Đào tạo nghiệp vụ & hệ thống nội bộ                | Đào tạo theo module phòng ban — tool và quy trình chuyên sâu                                                                                                   | Tuần 1–6      |
| 2.4 | Check-in & đánh giá thử việc                           | Đánh giá tại mốc 30 và 60 ngày — quyết định PASS / gia hạn 30 ngày kèm PIP / STOP                                                                         | Ngày 30 & 60   |
| 2.5 | Ký hợp đồng chính thức                                | Milestone hoàn thành thử việc                                                                                                                                       | Sau ngày 60    |

> Luật Lao động VN: thử việc tối đa 60 ngày (công việc cần trình độ kỹ thuật/nghiệp vụ cao),
> tối đa 30 ngày (công việc không đòi hỏi bằng cấp).

### Phase 3 — Giữ người

*Tổ chức theo vòng đời nhân viên — vòng lặp liên tục, không tuần tự.*
Metric: Annual turnover ≤15% · Engagement score ≥75/100 · Stay interview rate = 100% key people · HR touchpoint ≥95%.

**Phân quyền:** Manager = chịu trách nhiệm hiệu suất & phát triển trực tiếp (check-in tháng, review quý/6T/năm, IDP, lương). HR = thiết kế hệ thống, kiểm soát chất lượng, xử lý rủi ro/escalation, không tham gia đánh giá trực tiếp.

| Giai đoạn vòng đời | Mốc           | Trọng tâm                                                                 | Hoạt động chính                                                                                                                  |
| ----------------------- | -------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| 🌱 Phát triển         | 0–12 tháng   | Manager chủ động dẫn dắt · HR thiết kế hệ thống & xử lý rủi ro | Check-in 1-1 hàng tháng & cảnh báo hiệu suất (hàng tháng, Manager chủ trì, HR tổng hợp data không tham gia trực tiếp) |
| 🏛 Ổn định           | ≥1 năm       | Nhân viên đã hòa nhập — phát triển chuyên sâu, giữ gắn kết    | Đào tạo & phát triển liên tục (tiếp nối từ giai đoạn Phát triển, IDP cập nhật hàng năm)                            |
| 🚪 Nghỉ việc          | Khi phát sinh | Off-boarding chuyên nghiệp — học từ người rời đi                   | Exit Interview (bắt buộc với mọi trường hợp nghỉ tự nguyện, khi NV nộp đơn)                                             |

Các hoạt động khác thuộc Phase 3 (xuyên suốt, không gắn 1 mốc cố định): stay interview, review quý/6 tháng/năm,
IDP (individual development plan — mô hình 70-20-10), employee engagement survey (eNPS, ẩn danh),
off-boarding checklist & bàn giao, mobility nội bộ (stretch assignment), PIP (Performance Improvement Plan —
cam kết 2 chiều, không phải bước mở đầu sa thải), salary review năm, promotion, recognition,
văn hóa nội bộ, chương trình giới thiệu nhân sự (referral), buddy program, HR dashboard/budget,
quản lý tài sản IT khi offboard, alumni network, talent pool.

## 3. Danh mục 44 biểu mẫu / template HR

Đây là 44 template nghiệp vụ nhúng sẵn trong `hr_process_bc_v39.html` (dạng modal, mở khi click vào từng bước).
**Các cột dữ liệu trong mỗi template chính là gợi ý field cho entity/form tương ứng trong TMS.**
Nhóm theo tiền tố ID: `t1_*` = Phase 1 (Tuyển dụng) · `t2_*` = Phase 2 (Đào tạo & hội nhập) ·
`t3_*` = Phase 3 (Giữ người) · `t_*` = biểu mẫu dùng chung xuyên suốt vòng đời.

| ID                 | Tên biểu mẫu (diễn giải)                  | Các trường / bảng dữ liệu chính                                                                                                                                                                                     |
| ------------------ | ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `t1_0`           | Kế hoạch tuyển dụng năm                   | STT, Phòng ban, Vị trí, SL, Q1–Q4, Lương dự kiến, Lý do/KPI, Ưu tiên · KPI tuyển dụng năm · Ngân sách theo kênh & thời gian · Bảng phê duyệt (Tên/Ngày/Chữ ký)                                 |
| `t1_0m`          | Kế hoạch tuyển dụng THÁNG                 | Phễu tuyển dụng tháng (Vị trí, SL, CV đầu vào→phỏng vấn→onboard) · Timeline KPI theo tuần (W1–W4) · Phân tích kênh tuyển (ưu/nhược điểm, chi phí) · Danh sách nguồn ứng viên theo vị trí |
| `t1_1`           | Phiếu nhu cầu nhân sự                      | Yêu cầu chung vị trí · Mô tả tóm tắt công việc + KPI đo lường · Đãi ngộ (lương cơ bản...) · Phê duyệt (Phòng đề xuất/Ngày/Chữ ký)                                                          |
| `t1_2`           | Mẫu JD chuẩn                                 | # / Mục / Nội dung điền theo vị trí — cấu trúc chuẩn hóa từ Google Sheets JD thật của BC                                                                                                                     |
| `t1_3`           | Interview scorecard (structured interview)     | Tiêu chí đánh giá, Trọng số, thang 1/3/5, Điểm, Ghi chú+ví dụ · Khuyến nghị tổng thể (Strong Yes/Yes/Lean No/No)                                                                                          |
| `t1_3q`          | Bộ câu hỏi phỏng vấn theo STAR            | 4 tab: câu hỏi chung, Kinh doanh, Vận hành, Quản lý — mỗi câu có "dấu hiệu tốt" và "red flag"                                                                                                                |
| `t1_3e`          | Email từ chối ứng viên                     | 3 tab theo giai đoạn: từ chối sau CV / sau phỏng vấn / sau offer                                                                                                                                                     |
| `t1_4`           | Reference & background check                   | Câu hỏi xác minh + ghi chú đầy đủ (kể cả từ chối trả lời)                                                                                                                                                    |
| `t1_5`           | Thư mời nhận việc (Offer)                  | Thông tin vị trí + chi tiết offer                                                                                                                                                                                      |
| `t1_6`           | Checklist Pre-boarding                         | Hạng mục, Người phụ trách, Deadline, Trạng thái — theo từng bên (HR Recruiter, IT, Manager...)                                                                                                                  |
| `t2_1`           | Checklist onboarding Day 1                     | Khung giờ (sáng/chiều), Hoạt động, Người phụ trách, Trạng thái                                                                                                                                                 |
| `t2_2`           | Kế hoạch 15-30-60-90 ngày                   | 3 bộ mốc riêng (Vận hành/BO, Kinh doanh/KD, Intern): Mốc, Mục tiêu cốt lõi, Task, Kết quả kỳ vọng/KPI, Check-in, Đánh giá                                                                                 |
| `t2_3`           | Checklist đào tạo hệ thống nội bộ       | Module chính (Leader hướng dẫn), Tool nội bộ (Email, v.v.), tự đánh giá cuối                                                                                                                                    |
| `t2_4`           | Đánh giá thử việc (30/60 ngày)           | Tiêu chí, Self-đánh giá, Manager đánh giá, Nhận xét · câu hỏi 2 chiều · Quyết định (PASS/gia hạn/STOP)                                                                                                  |
| `t3_1`           | Check-in 1-1 hàng tháng                      | Agenda (review KPI tháng...) + ghi chú Manager                                                                                                                                                                           |
| `t3_2`           | Stay Interview                                 | Câu hỏi mở (kết nối cảm xúc, động lực) + ghi chú HR (confidential)                                                                                                                                              |
| `t3_3`           | Review hiệu suất định kỳ                  | Nội dung, Manager đánh giá, Nhân viên tự đánh giá, Ghi chú                                                                                                                                                      |
| `t3_4`           | IDP (Individual Development Plan)              | Mô hình 70-20-10: điểm mạnh, mục tiêu phát triển theo loại/70-20-10, cách thực hiện, nguồn lực, deadline, đo lường · phê duyệt Manager                                                                |
| `t3_5`           | Employee Engagement Survey                     | Câu hỏi thang 1–5 theo nhóm đo lường + 2 câu mở + cách tính eNPS + Action plan (Owner/Deadline/Status) —**ẩn danh tuyệt đối**                                                                        |
| `t3_6`           | Off-boarding checklist                         | Hạng mục bàn giao công việc & kiến thức, người phụ trách, deadline                                                                                                                                              |
| `t3_7`           | Exit survey / Exit interview                   | 2 mẫu (BM04): phiếu khảo sát nhanh + phỏng vấn sâu — lý do nghỉ, ưu tiên cải thiện, đánh giá 5 thang điểm, 5 chủ đề đào sâu                                                                       |
| `t3_q`           | Review quý                                    | KPI/Mục tiêu, Target, Thực tế, %Hoàn thành + nhận xét định tính                                                                                                                                                 |
| `t3_well`        | Wellbeing check (HR nội bộ)                  | Câu hỏi workload/năng lượng — ghi chú nội bộ, KHÔNG chia sẻ với Manager                                                                                                                                        |
| `t3_handover`    | Bàn giao công việc                          | Đầu việc/dự án đang xử lý (status, deadline, người nhận, link) + Contact key                                                                                                                                    |
| `t3_mob`         | Internal mobility                              | Stretch assignment mở (phòng ban, loại, yêu cầu) + đăng ký của nhân viên (workload, Manager approve)                                                                                                            |
| `t3_self`        | Self-review                                    | Câu hỏi tự đánh giá hiệu suất & đóng góp                                                                                                                                                                        |
| `t_pip`          | PIP (Performance Improvement Plan)             | Vấn đề cụ thể → Mục tiêu SMART → Hỗ trợ từ công ty → Check-in tuần (4 tuần) → Quyết định cuối                                                                                                         |
| `t_salband`      | Salary Band tham khảo                         | Grade, Cấp độ, Vị trí điển hình, Min/Mid/Max (triệu gross) — 3 nhóm KD/BO/HR — xem đầy đủ mục 4                                                                                                           |
| `t_annreview`    | Review năm                                    | Tiêu chí KPI/OKR (Manager+Self), phần tự luận, Compensation Decision                                                                                                                                                  |
| `t_promo`        | Thông báo điều chỉnh lương/thăng chức | Trước/Sau: mức lương, chức danh                                                                                                                                                                                      |
| `t3_6m`          | Review 6 tháng                                | Tiêu chí, Target H1/H2, Thực tế, %Đạt, Rating + phát triển 6 tháng                                                                                                                                                |
| `t_career`       | Career Path (khung tham chiếu)                | 4 track (KD/BO/HR/MKT) × cấp độ, chức danh, tiêu chí đo lường, timeline, salary band ref — xem đầy đủ mục 4                                                                                                |
| `t_promo_rec`    | Đề xuất thăng tiến                        | Bằng chứng hiệu suất (có số liệu) + phê duyệt HR Manager                                                                                                                                                          |
| `t_recognition`  | Ghi nhận nhân viên                          | (không có bảng — hướng dẫn định tính, ghi nhận phải cụ thể không chung chung)                                                                                                                               |
| `t_culture_plan` | Kế hoạch hoạt động văn hóa năm         | Tháng, Hoạt động, Mục tiêu HR, Quy mô, Ngân sách, Owner, Status + tổng kết ngân sách theo quý                                                                                                                |
| `t_culture_fb`   | Feedback hoạt động văn hóa                | Câu hỏi + điểm/trả lời + tổng kết                                                                                                                                                                                  |
| `t_referral`     | Chương trình giới thiệu nhân sự         | Thông tin ứng viên + HR tracking status — xem chính sách chi tiết mục 6                                                                                                                                            |
| `t_buddy`        | Buddy Program                                  | Profile nhân viên mới + touchpoint schedule 5 mốc/12 tuần (tối thiểu 8 lần/90 ngày) + vai trò buddy (nên/không nên)                                                                                           |
| `t_hr_dash`      | HR Dashboard                                   | Metric (headcount...), tháng này/trước/target/status + highlight                                                                                                                                                       |
| `t_hr_budget`    | Ngân sách HR                                 | Hạng mục theo Q1–Q4 + cả năm + ghi chú                                                                                                                                                                               |
| `t_it_asset`     | Bàn giao tài sản IT khi offboard            | Hạng mục, Serial/Account, tình trạng, ngày thực hiện, xác nhận 2 bên                                                                                                                                             |
| `t_alumni`       | Alumni tracking                                | Họ tên, vị trí cuối, thời gian tại BC, ngày nghỉ, lý do, relationship, re-hire?, contact, last touch + phân loại alumni                                                                                        |
| `t_addendum`     | Phụ lục hợp đồng lao động               | Nội dung điều chỉnh, theo HĐ gốc, điều chỉnh mới, hiệu lực từ (căn cứ BLLĐ 2019 Điều 22)                                                                                                                 |
| `t_talent_pool`  | Talent Pool                                    | Ứng viên tốt nhưng chưa phù hợp vị trí — Tier A/B/C rating, lý do chưa hire, salary expectation, next action                                                                                                   |

## 4. Cơ cấu chức danh & lộ trình thăng tiến (Career Path)

> Nguyên tắc BC Agency: **Career path là khung tham chiếu, không phải cam kết cứng nhắc.** Thời gian
> thực tế phụ thuộc performance và cơ hội kinh doanh thực tế.
> **⚠️ Lưu ý:** đây là 1 bộ mã track/level (KD / BO / HR / MKT) độc lập với role taxonomy 42-role/13-track
> của module PMS (`[[lifecycle-and-roles]]`) — cần đối chiếu khi thiết kế bảng `role`/`career_level` dùng chung.

### 📈 Track KINH DOANH — SALES

| Cấp | Chức danh                         | Tiêu chí đo lường được                                                                                                                                        | Timeline    | Salary band ref |
| ---- | ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- | --------------- |
| KD-1 | Sales Intern / Fresher             | Hoàn thành 100% training module/30 ngày · cold call ≥20 leads/tuần · không cần check lại với Senior cho outreach cơ bản                                  | 0–6 tháng | 3–5M           |
| KD-2 | Account Executive (Junior)         | Tự close ≥1 deal/tháng (≥[X]M) · maintain portfolio ≥15 KH không cần nhắc · báo cáo pipeline chính xác ≥90%                                            | 6T–2 năm  | 8–16M          |
| KD-3 | Senior Account Executive           | Close deal ≥[2X]M/tháng sustained 3T · KH renewal ≥70% · tự dẫn pitch KH mới không cần backup · onboard được 1 junior                                   | 2–4 năm   | 15–28M         |
| KD-4 | Sales Team Lead / Key Account Lead | Team (2–4 người) đạt ≥80% target chung · tự quyết deal ≤[X]M không cần xin phép · có ≥1 junior được promote lên Senior · forecast accuracy ≥85% | 4–6 năm   | 22–40M         |
| KD-5 | Sales Manager / Trưởng phòng KD | Team đạt ≥100% target cả năm ≥2 năm liên tiếp · build & maintain team 5+ người · revenue department ≥[Y]M/năm · tự thiết kế sales process & OKR    | 6+ năm     | 35–60M         |

### ⚙️ Track VẬN HÀNH — BUSINESS OPERATIONS

| Cấp | Chức danh                              | Tiêu chí đo lường được                                                                                                            | Timeline    | Salary band ref |
| ---- | --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ----------- | --------------- |
| BO-1 | Operations Intern / Fresher             | Xử lý 100% task đúng deadline tháng đầu · không mắc cùng 1 lỗi 2 lần · biết tất cả hệ thống nội bộ cơ bản          | 0–6 tháng | 3–5M           |
| BO-2 | Operations Executive (Junior)           | Tự xử lý 90% tình huống thường gặp không cần hỏi · SLA compliance ≥95% · phát hiện & report ≥1 issue/tháng proactively  | 6T–2 năm  | 8–14M          |
| BO-3 | Senior Operations Executive             | Tự thiết kế ≥1 SOP mới được approve · handle case phức tạp độc lập · train Junior xử lý 80% công việc thường ngày   | 2–4 năm   | 12–22M         |
| BO-4 | Operations Manager / Trưởng phòng BO | Phòng vận hành chạy trơn tru khi Manager vắng 1 tuần · giảm ≥1 điểm bottleneck đo lường được/6T · budget variance ≤5% | 4+ năm     | 25–48M         |

### 🏢 Track NHÂN SỰ — HCNS

| Cấp | Chức danh                       | Tiêu chí đo lường được                                                                                                                      | Timeline    | Salary band ref |
| ---- | -------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- | --------------- |
| HR-1 | HR Intern / Fresher              | Tự screening CV đạt ≥80% accuracy (so với Senior review) · hoàn thành toàn bộ admin HR task đúng deadline                               | 0–6 tháng | 3–5M           |
| HR-2 | HR Executive (Junior)            | Tự handle toàn bộ quy trình từ JD đến offer cho vị trí Junior · time-to-hire ≤30 ngày (non-management) · onboarding satisfaction ≥4/5 | 6T–2 năm  | 8–15M          |
| HR-3 | Senior HR Executive / HR Manager | Xây & maintain ≥2 hệ thống HR chạy không cần giám sát · turnover team phụ trách ≤15%/năm · eNPS ≥+30 ổn định qua 2 quý          | 2–4 năm   | 15–32M         |

*(HR-4 = HR Director/Head of People, xem bảng Salary Band mục 5 — chưa có tiêu chí đo lường chi tiết trong tài liệu gốc)*

### 🎨 Track MARKETING / CONTENT / CREATIVE

| Cấp | Chức danh               | Tiêu chí đo lường được                                                                                                                                            | Timeline    | Salary band ref |
| ---- | ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- | --------------- |
| MK-1 | Intern / Fresher         | Tự hoàn thành ≥3 deliverable/tuần đúng brief · revision không quá 2 lần/deliverable sau tháng đầu                                                           | 0–6 tháng | 3–5M           |
| MK-2 | Executive (Junior)       | Tự quản lý 2–3 project nhỏ song song không cần nhắc deadline · KPI campaign đạt ≥80% target (CTR, reach, engagement) · client không complain 3T liên tiếp | 6T–2 năm  | 8–16M          |
| MK-3 | Senior Executive         | Tự brief & lead project ≥[X]M không cần Senior backup · mentor 1 Junior deliver độc lập · portfolio ≥3 case study có KPI rõ ràng                             | 2–4 năm   | 14–25M         |
| MK-4 | Team Lead / Account Lead | Dẫn dắt team 3–5 người đạt ≥90% KPI chung · giữ ≥80% KH hiện tại tiếp tục hợp đồng năm sau · tự pitch & win deal mới ≥[Y]M/năm                    | 4+ năm     | 20–38M         |

## 5. Khung lương tham khảo (Salary Band) — Q2/2026

> ⚠️ Các mức lương trong bảng là **MẪU THAM KHẢO** cho ngành Marketing/Agency tại Hà Nội, Q2/2026.
> BC Agency cần điều chỉnh theo thực tế. Đơn vị: **triệu đồng gross/tháng**.

| Grade                        | Cấp độ      | Vị trí điển hình         | Min | Mid (Market 50th pct) | Max | Ghi chú                           |
| ---------------------------- | -------------- | ----------------------------- | --- | --------------------- | --- | ---------------------------------- |
| **KINH DOANH / SALES** |                |                               |     |                       |     |                                    |
| KD-1                         | Fresher/Intern | Sales Intern, BD Intern       | 3   | 4                     | 5   | Chưa kinh nghiệm hoặc <6 tháng |
| KD-2                         | Junior         | Account Executive, Sales Exec | 8   | 12                    | 16  | 1–3 năm kinh nghiệm             |
| KD-3                         | Senior         | Senior AE, Key Account        | 15  | 20                    | 28  | 3–5 năm, có track record        |
| KD-4                         | Lead/Team Lead | Sales Lead, BD Lead           | 22  | 30                    | 40  | Dẫn dắt nhóm nhỏ 2–5 người  |
| KD-5                         | Manager        | Sales Manager, BD Manager     | 35  | 45                    | 60  | Quản lý team 5+ người          |
| **VẬN HÀNH / BO**    |                |                               |     |                       |     |                                    |
| BO-1                         | Fresher        | Operations Intern             | 3   | 4                     | 5   |                                    |
| BO-2                         | Junior         | Operations Exec               | 8   | 11                    | 14  |                                    |
| BO-3                         | Senior         | Senior Ops, Project Lead      | 12  | 17                    | 22  |                                    |
| BO-4                         | Manager        | Operations Manager            | 25  | 35                    | 48  |                                    |
| **HCNS / HR**          |                |                               |     |                       |     |                                    |
| HR-1                         | Fresher        | HR Intern                     | 3   | 4                     | 5   |                                    |
| HR-2                         | Junior         | HR Executive, Recruiter       | 8   | 11                    | 15  |                                    |
| HR-3                         | Senior         | HR Manager, Senior Recruiter  | 15  | 22                    | 32  |                                    |
| HR-4                         | Lead           | HR Director, Head of People   | 30  | 45                    | 65  |                                    |

**Cách áp dụng khi ra offer:**

- Nhân viên mới hoàn toàn → offer ở Min hoặc 10–15% trên Min (chừa room tăng sau probation)
- Kinh nghiệm match 50–70% → offer 10–20% trên Min, hướng tới Mid
- Ứng viên strong, match ≥80% → offer ở Mid hoặc trên Mid, tối đa 90% Max
- **Không offer vượt Max** — ngoại lệ cần CEO approve + điều chỉnh band
- Review salary band hàng năm vào Q4, benchmark: Navigos Salary Report, Mercer, Anphabe Vietnam Report, Glassdoor VN

## 6. Chính sách lương — KPI — Hoa hồng theo từng vị trí (dữ liệu đầy đủ)

Nguồn: `CHÍNH_SÁCH_LƯƠNG_2026.xlsx` — công cụ tính lương nội bộ hiện tại của BC Agency, gồm 21 sheet,
mỗi sheet là 1 bảng lương/hoa hồng/KPI cho 1 vị trí hoặc 1 bảng tính phụ trợ (phân bổ doanh thu mục tiêu...).

**Cách đọc dữ liệu bên dưới:** mỗi dòng có dạng `R<số dòng>: <ô>=<giá trị> | <ô>=<giá trị> | ...`
— giữ nguyên tọa độ ô gốc (ví dụ `D18=21428571.43`) để không mất thông tin khi merge cell hoặc dòng
tiêu đề nhóm. Đây là dữ liệu **nguyên bản, đầy đủ**, dùng để dựng entity `salary_policy` /
`commission_tier` / `kpi_template` cho từng `career_level`.

**Cấu trúc chung lặp lại ở phần lớn các vị trí bán hàng/vận hành:**

1. Bảng điều kiện "ON/OFF" theo % hoàn thành KPI trung bình nhiều tháng liên tiếp (case 01–05) — quyết định
   nhân viên có đủ điều kiện nhận lương theo doanh thu (ON) hay quay về lương tối thiểu theo quy định (OFF).
2. Bảng trọng số KPI (Doanh Thu Thuần, Số lượng khách hàng mới...) — %Hoàn thành × Trọng số → % Quy đổi chung.
3. Bảng **"Mức Level / Rank"** — bậc thang hoa hồng theo khoảng doanh thu thuần đạt được: mỗi Level có
   Lương Cứng, %Hoa hồng, Doanh thu thuần tối thiểu tương ứng, Tổng thu nhập.

```text
##### SHEET: NV Sale không BHXH #####
R2: A2=NV CHÍNH THỨC | B2=A = KPI
R3: A3=Hạng Mục | B3=ĐIỀU KIỆN | C3=TIÊU CHÍ ĐÁNH GIÁ | F3=LƯƠNG CỨNG THEO DTT | G3=RANK
R11: A11=Chức Vụ | B11=Nhân sự / Mục Tiêu | C11=Trọng Số | D11=Đơn Vị  | E11=Mức Tham Chiếu | F11=Mô Tả | G11=Thực Tế | H11=Tỷ Lệ Hoàn Thành | I11=% Quy Đổi Chung
R12: A12=Kỹ năng chuyên môn (100%) | B12=Doanh Thu Thuần | C12=0.7 | D12=VNĐ | E12=50000000.0 | F12=DTT toàn bộ dịch vụ | G12=50000000.0 | H12=1 | I12=1
R13: B13=Số Lượng Khách Hàng Mới từ sale | C13=0.3 | D13=Khách Hàng | E13=3.0 | F13=Số lượng KH mới do sale tự tìm | G13=3.0 | H13=1
R15: A15=MỨC COM THEO RANK TƯƠNG LAI
R16: A16=THỬ VIỆC | B16=Doanh thu thuần giả định với các chỉ số khác đạt 100% | C16=Tính trong 6 tháng
Sau 6 tháng áp dụng chính sách tỷ lệ 50 50 | D16=% DTT từ tài khoản N | E16=% hoa hồng thực nhận | F16=CPCĐ | G16=5497007.0
R17: D17=<=60% | E17=1.0
R18: D18=>60% | E18=0.7
R19: A19=Mức Level | B19=Khoảng Cách | C19=% Hoa hồng | D19=DOANH THU THUẦN 
TỐI THIỂU | E19=Lương Cứng  | F19=% DTT từ TK N | G19=% hoa hồng thực tế | H19=Hoa hồng | I19=Tổng TN | J19=Tỷ trọng lương/ DTT | K19=Tỷ trọng chi phí/ DTT
R20: A20=Level 01 | B20=(%KPI) < 52% | C20=0.0 | D20=500000.0 | E20=1500000.0 | F20=0.6 | G20=0 | H20=0 | I20=1500000 | J20=3 | K20=13.994014 | L20=0.49
R21: A21=Level 02 | B21=52% <= KPI < 70% | C21=0.0 | D21=15714285.71 | E21=3000000.0 | F21=0.6 | G21=0 | H21=0 | I21=3000000 | J21=0.1909090909 | K21=0.5407186273 | L21=0.52
R22: A22=Level 03 | B22=70% <= (%KPI) <85% | C22=0.08 | D22=28571428.57 | E22=5310000.0 | F22=0.6 | G22=0.08 | H22=2285714.286 | I22=7595714.286 | J22=0.26585 | K22=0.458245245 | L22=0.7
R23: A23=Level 04 | B23=85% <= (%KPI) < 100% | C23=0.1 | D23=39285714.29 | E23=6000000.0 | F23=0.6 | G23=0.1 | H23=3928571.429 | I23=9928571.429 | J23=0.2527272727 | K23=0.3926510873 | L23=0.85
R24: A24=Level 05 | B24=100% <= (%KPI) <125% | C24=0.1 | D24=50000000 | E24=8000000.0 | F24=0.6 | G24=0.1 | H24=5000000 | I24=13000000 | J24=0.26 | K24=0.36994014 | L24=1.0
R25: A25=Level 06 | B25=125% <= (%KPI) <150% | C25=0.11 | D25=67857142.86 | E25=8000000.0 | F25=0.6 | G25=0.11 | H25=7464285.714 | I25=15464285.71 | J25=0.2278947368 | K25=0.3089032611 | L25=1.25
R26: A26=Level 07 | B26=150% <= (%KPI) <200% | C26=0.12 | D26=85714285.71 | E26=9000000.0 | F26=0.6 | G26=0.12 | H26=10285714.29 | I26=19285714.29 | J26=0.225 | K26=0.2891317483 | L26=1.5
R27: A27=Level 08 | B27=200% <= (%KPI) <400% | C27=0.13 | D27=121428571.4 | E27=10000000.0 | F27=0.6 | G27=0.13 | H27=15785714.29 | I27=25785714.29 | J27=0.2123529412 | K27=0.2576224106 | L27=2.0
R28: A28=Level 09 | B28=400% <= (%KPI) <600% | C28=0.14 | D28=264285714.3 | E28=12000000.0 | F28=0.6 | G28=0.14 | H28=37000000 | I28=49000000 | J28=0.1854054054 | K28=0.2062048914 | L28=4.0
R29: A29=Level 10 | B29=600% <= (%KPI) <800% | C29=0.16 | D29=407142857.1 | E29=12000000.0 | F29=0.6 | G29=0.16 | H29=65142857.14 | I29=77142857.14 | J29=0.1894736842 | K29=0.2029751049 | L29=6.0
R30: A30=Level 11 | B30=800% <= (%KPI) <1000% | C30=0.18 | D30=550000000 | E30=12000000.0 | F30=0.6 | G30=0.18 | H30=99000000 | I30=111000000 | J30=0.2018181818 | K30=0.21181274 | L30=8.0
R31: A31=Level 12 | B31=1000% <= KPI | C31=0.2 | D31=692857142.9 | E31=12000000.0 | F31=0.6 | G31=0.2 | H31=138571428.6 | I31=150571428.6 | J31=0.2173195876 | K31=0.2252534122 | L31=10.0


##### SHEET: Sale intern #####
R2: A2=Hạng Mục | B2=DTT THÁNG | C2=TIÊU CHÍ ĐÁNH GIÁ | F2=LƯƠNG CỨNG THEO DTT | G2=RANK
R3: A3=CASE 01 | B3=A < 5.000.000 | C3=Trung bình 3 tháng < 8tr | E3=Off | F3=P1+P2: 3.000.000 | G3=0% (P1+P2)
R4: A4=CASE 02 | B4=5.000.000 <= A < 8.000.000 | F4=P1+P2: 3.000.000 | G4=50% (P1+P2)
R5: A5=CASE 03 | B5=8.000.000 <= A < 10.000.000 | C5=8<=Trung bình 3 tháng <10 | E5=- Tiếp tục học việc tối đa 2 tháng
- Sau 2 tháng học việc tiếp theo, DTT trung bình >=10tr: ON | F5=P1+P2: 3.000.000 | G5=100% (P1+P2)
R6: A6=CASE 04 | B6=A >=10.000.000 | C6=Trung bình 3 tháng >= 10tr | E6=ON | F6=P1+P2: 3.000.000 | G6=100% (P1+P2)
R10: A10=Ví dụ về KPI
R11: A11=Chức Vụ | B11=Nhân sự / Mục Tiêu | C11=Trọng Số | D11=Đơn Vị  | E11=Mức Tham Chiếu | F11=Mô Tả | G11=Thực Tế | H11=Tỷ Lệ Hoàn Thành | I11=% Quy Đổi Chung
R12: A12=HỌC VIỆC KINH DOANH | C12=1.0
R13: A13=Kỹ năng chuyên môn | B13=Doanh Thu Thuần | C13=1.0 | D13=VNĐ | E13=10000000.0 | G13=25000000.0 | H13=2.5 | I13=2.5
R17: A17=TRƯỜNG HỢP CÓ DOANH THU ĐƯỢC ÁP DỤNG NHƯ SAU:
R18: A18=Ví dụ về thu nhập của vị trí Học việc
R19: A19=Mức Level | B19=Khoảng Cách | C19=% hoa hồng | D19=DOANH THU THUẦN  | E19=Mức hỗ trợ | F19=Hoa Hồng | G19=Tổng
R20: A20=Level 01 | B20=(%KPI) <50% | C20=0.0 | D20=4000000.0 | E20=0.0 | F20=0.0 | G20=0 | H20=0.0 | I20=0.5
R21: A21=Level 02 | B21=0.5 | C21=0.0 | D21=5001000.0 | E21=1500000.0 | F21=0.0 | G21=1500000 | H21=0.2499500099980004 | I21=0.5001
R22: A22=Level 03 | B22=0.7 | C22=0.05 | D22=7000000.0 | E22=1500000.0 | F22=350000.0 | G22=1850000 | H22=0.40714285714285714 | I22=0.7
R23: A23=Level 04 | B23=0.85 | C23=0.08 | D23=8500000.0 | E23=3000000.0 | F23=680000.0 | G23=3680000 | H23=0.37411764705882355 | I23=0.85
R24: A24=Level 05 | B24=1.0 | C24=0.1 | D24=10000000.0 | E24=3000000.0 | F24=1000000.0 | G24=4000000 | H24=0.35 | I24=1.0
R25: A25=Level 06 | B25=1.25 | C25=0.11 | D25=12500000.0 | E25=3000000.0 | F25=1375000.0 | G25=4375000 | H25=0.37666666666666665 | I25=1.25
R26: A26=Level 07 | B26=1.5 | C26=0.12 | D26=15000000.0 | E26=3000000.0 | F26=1800000.0 | G26=4800000 | H26=0.3422222222222222 | I26=1.5
R27: A27=Level 08 | B27=2.0 | C27=0.13 | D27=20000000.0 | E27=3000000.0 | F27=2600000.0 | G27=5600000 | H27=0.33 | I27=2.0
R28: A28=Level 09 | B28=4.0 | C28=0.14 | D28=40000000.0 | E28=3000000.0 | F28=5600000.0 | G28=8600000 | H28=0.24416666666666667 | I28=4.0
R29: A29=Level 10 | B29=6.0 | C29=0.16 | D29=60000000.0 | E29=3000000.0 | F29=9600000.0 | G29=12600000 | H29=0.22944444444444445 | I29=6.0
R30: A30=Level 11 | B30=8.0 | C30=0.18 | D30=80000000.0 | E30=3000000.0 | F30=14400000.0 | G30=17400000 | H30=0.23208333333333334 | I30=8.0
R31: A31=Level 12 | B31=10.0 | C31=0.2 | D31=100000000.0 | E31=3000000.0 | F31=20000000.0 | G31=23000000 | H31=0.24166666666666667 | I31=10.0
R35: A35=TRƯỜNG HỢP KHÔNG CÓ DOANH THU ĐƯỢC ÁP DỤNG NHƯ SAU:
R37: A37=Điều kiện | C37=Số brief | D37=Mức Hỗ trợ
R38: A38=Số brief meeting với khách hàng Lần thứ 2 | C38=4.0 | D38=2.000.000đ
R39: A39=Số Pitching với khách hàng Lần thứ nhất (Nếu không có meeting Lần thứ 2) | C39=4.0 | D39=2.000.000đ


##### SHEET: Sale #####
R1: A1=NV CHÍNH THỨC | B1=A = KPI
R2: A2=Hạng Mục | B2=ĐIỀU KIỆN | C2=TIÊU CHÍ ĐÁNH GIÁ | F2=LƯƠNG CỨNG THEO DTT | G2=RANK
R3: A3=CASE 01 | B3=A<60% | C3=02 tháng gần nhất liên tiếp A<60% | D3=Trong 03 tháng gần nhất có 02 tháng A < 60% | E3=OFF | F3=Theo quy định lương
R4: A4=CASE 02 | B4=60% < = A < 80% | C4=Trong 03 tháng gần nhất có ít nhất 02 tháng A < 80% và trung bình 03 tháng A < 80% | E4=OFF
R5: A5=CASE 03 | B5=80% <= A < 90% | C5=03 tháng gần nhất liên tiếp A<90% | D5=Trong 04 tháng gần nhất có 03 tháng A < 90% và trung bình 04 tháng A < 90% | E5=OFF
R6: A6=CASE 04 | B6=90% <= A < 100% | C6=04 tháng gần nhất liên tiếp <100% | D6=Trong 06 tháng gần nhất, có >=4 tháng A< 100% và trung bình 6 tháng A < 100% | E6=OFF
R7: A7=CASE 05 | B7=A >= 100% | D7=ON
R10: A10=Chức Vụ | B10=Nhân sự / Mục Tiêu | C10=Trọng Số | D10=Đơn Vị  | E10=Mức Tham Chiếu | F10=Mô Tả | G10=Thực Tế | H10=Tỷ Lệ Hoàn Thành | I10=% Quy Đổi Chung
R11: A11=Kỹ năng chuyên môn (100%) | B11=Doanh Thu Thuần | C11=0.7 | D11=VNĐ | E11=50000000.0 | F11=DTT toàn bộ dịch vụ | G11=50000000.0 | H11=1 | I11=1
R12: B12=Số Lượng Khách Hàng Mới | C12=0.3 | D12=Khách Hàng | E12=3.0 | F12=Số lượng KH mới | G12=3.0 | H12=1
R13: E13=Trong 03 tháng đầu thay đổi cơ chế
R14: A14=MỨC COM THEO RANK TƯƠNG LAI
R15: A15=CHÍNH THỨC | B15=Doanh thu thuần giả định với các chỉ số khác đạt 100% | C15=Tính trong 6 tháng
Sau 6 tháng áp dụng chính sách tỷ lệ 50 50 | F15=CPCĐ | G15=6267835
R16: D16=<=60% | E16=1.0
R17: A17=Mức Level | B17=Khoảng Cách | C17=% Hoa hồng | D17=DOANH THU THUẦN 
TỐI THIỂU | E17=Lương Cứng  | F17=% DTT từ TK N | G17=% hoa hồng thực tế | H17=Hoa hồng | I17=Tổng TN | J17=Tỷ trọng lương/ DTT | K17=Tỷ trọng chi phí/ DTT
R18: A18=Level 01 | B18=0.6 | C18=0.0 | D18=21428571.43 | E18=6000000.0 | F18=0.6 | G18=0 | H18=0 | I18=6000000 | J18=0.28 | K18=0.5724989667 | L18=0.6
R19: A19=Level 02 | B19=0.7 | C19=0.0 | D19=28571428.57 | E19=6000000.0 | F19=0.6 | G19=0 | H19=0 | I19=6000000 | J19=0.21 | K19=0.429374225 | L19=0.7
R20: A20=Level 03 | B20=0.8 | C20=0.05 | D20=35714285.71 | E20=7000000.0 | F20=0.6 | G20=0.05 | H20=1785714.286 | I20=8785714.286 | J20=0.246 | K20=0.42149938 | L20=0.8
R21: A21=Level 04 | B21=0.9 | C21=0.08 | D21=42857142.86 | E21=7000000.0 | F21=0.6 | G21=0.08 | H21=3428571.429 | I21=10428571.43 | J21=0.2433333333 | K21=0.3895828167 | L21=0.9
R22: A22=Level 05 | B22=1.0 | C22=0.1 | D22=50000000 | E22=8000000.0 | F22=0.6 | G22=0.1 | H22=5000000 | I22=13000000 | J22=0.26 | K22=0.3853567 | L22=1
R23: A23=Level 06 | B23=1.25 | C23=0.11 | D23=67857142.86 | E23=8500000.0 | F23=0.6 | G23=0.11 | H23=7464285.714 | I23=15964285.71 | J23=0.2352631579 | K23=0.3276312526 | L23=1.25
R24: A24=Level 07 | B24=1.5 | C24=0.12 | D24=85714285.71 | E24=9000000.0 | F24=0.6 | G24=0.12 | H24=10285714.29 | I24=19285714.29 | J24=0.225 | K24=0.2981247417 | L24=1.5
R25: A25=Level 08 | B25=2.0 | C25=0.13 | D25=121428571.4 | E25=10000000.0 | F25=0.6 | G25=0.13 | H25=15785714.29 | I25=25785714.29 | J25=0.2123529412 | K25=0.2639704059 | L25=2
R26: A26=Level 09 | B26=3.0 | C26=0.14 | D26=192857142.9 | E26=12000000.0 | F26=0.6 | G26=0.14 | H26=27000000 | I26=39000000 | J26=0.2022222222 | K26=0.2347221074 | L26=3
R27: A27=Level 10 | B27=4.0 | C27=0.15 | D27=264285714.3 | E27=12000000.0 | F27=0.6 | G27=0.15 | H27=39642857.14 | I27=51642857.14 | J27=0.1954054054 | K27=0.2191215378 | L27=4
R28: A28=Level 11 | B28=5.0 | C28=0.16 | D28=335714285.7 | E28=12000000.0 | F28=0.6 | G28=0.16 | H28=53714285.71 | I28=65714285.71 | J28=0.1957446809 | K28=0.2144148277 | L28=5
R29: A29=Level 12 | B29=6.0 | C29=0.17 | D29=407142857.1 | E29=12000000.0 | F29=0.6 | G29=0.17 | H29=69214285.71 | I29=81214285.71 | J29=0.1994736842 | K29=0.2148683667 | L29=6


##### SHEET: HR2 #####
R2: A2=2. CÁC CHỈ SỐ KPIs
R3: A3=KPI | B3=Cách tính KPI | C3=Trọng Số Chi Tiết | D3=Đơn Vị tính | E3=Mức Tham Chiếu | F3=Thực Tế | G3=Tỷ Lệ Hoàn Thành | H3=Tổng KPI
R4: A4=Số lượng ứng viên đến phỏng vấn/kế hoạch | C4=0.2 | D4=% | E4=0.9 | F4=1.0 | G4=1 | H4=1
R5: A5=Tỷ lệ ứng viên đạt phỏng vấn | C5=0.2 | D5=% | E5=0.4 | F5=1.0 | G5=1
R6: A6=Tỷ lệ ứng viên đến nhận việc | C6=0.2 | D6=% | E6=0.8 | F6=1.0 | G6=1
R7: A7=Tỷ lệ hoàn thành kế hoạch đào tạo | B7=Số chương trình đào tạo hoàn thành/ Tổng chương trình đào tạo theo kế hoạch tháng | C7=0.15 | D7=% | E7=1.0 | F7=1.0 | G7=1
R8: A8=Điểm đánh giá về chất lượng đào tạo | B8=100% nhân sự hoàn tất bài tập sau đào tạo | C8=0.1 | D8=% | E8=1.0 | F8=1.0 | G8=1
R9: B9=80% nhân sự đạt điểm từ 8 trở lên | C9=0.15 | D9=% | E9=1.0 | F9=1.0 | G9=1


##### SHEET: Account #####
R1: A1=Nhiệm Vụ | B1=Mô Tả Chi Tiết | C1=Bộ phận phối hợp
R2: A2=Tiếp nhận và phát triển yêu cầu từ khách hàng | B2=Làm việc trực tiếp với khách hàng để tiếp nhận, làm rõ và phát triển yêu cầu liên quan đến chiến dịch/truyền thông/dịch vụ agency.
R3: B3=Phân tích mục tiêu kinh doanh, mục tiêu marketing, ngân sách, timeline và các ràng buộc của dự án.
R4: B4=Chuyển hoá yêu cầu khách hàng thành brief nội bộ rõ ràng, đầy đủ và khả thi cho các bộ phận liên quan (Creative, Media, Production, Tech…).
R5: B5=Phối hợp cùng các team để đề xuất giải pháp phù hợp, đảm bảo bám sát mục tiêu và kỳ vọng của khách hàng.
R6: A6=Quản lý và triển khai dự án | B6=Phối hợp với Account Lead/Creative/Planner xây dựng proposal và kế hoạch triển khai dự án.
R7: B7=Tham gia xây dựng proposal: Insight – Strategy – Big Idea – Media Plan – KPI – Timeline – Budget.
R8: B8=Đại diện agency trình bày proposal với khách hàng; giải đáp thắc mắc, tiếp nhận phản hồi và điều chỉnh phương án khi cần.
R9: B9=Theo dõi tiến độ dự án, kiểm soát chất lượng đầu ra và đảm bảo các hạng mục được triển khai đúng cam kết.
R10: A10=Chăm sóc khách hàng | B10=Là đầu mối liên hệ chính giữa khách hàng và agency trong suốt vòng đời dự án.
R11: B11=Chủ động cập nhật tiến độ, xử lý các yêu cầu phát sinh và quản lý kỳ vọng của khách hàng.
R12: B12=Thực hiện báo cáo định kỳ hoặc báo cáo tổng kết chiến dịch (performance, kết quả, đánh giá).
R13: B13=Đảm bảo mức độ hài lòng của khách hàng và góp phần duy trì, mở rộng hợp tác lâu dài.
R14: A14=Phối hợp nội bộ | B14=Điều phối công việc giữa các phòng ban, đảm bảo thông tin được truyền đạt chính xác, thống nhất và kịp thời.
R15: B15=Chủ động phát hiện rủi ro trong quá trình triển khai và đề xuất phương án xử lý.
R16: B16=Tham gia các buổi brainstorm, họp nội bộ để đóng góp góc nhìn từ phía khách hàng và định hướng dự án.
R18: A18=KPI đánh giá | B18=Mô tả | C18=Trọng Số (Vũ) | D18=Mức Tham Chiếu | E18=Mức Tham Chiếu | F18=Mức Tham Chiếu | G18=Trọng Số (Vy)
R19: A19=Tỷ lệ dự án chốt thành công | B19=Tỷ lệ chốt (%) = Số proposal ký hợp đồng / Tổng proposal đã gửi 
Chỉ tính proposal:
- Đã gửi chính thức cho khách hàng.
- Có ngân sách và scope rõ ràng.
Tối đa 100% | C19=0.0 | D19=0.3 | E19=0.35 | F19=0.4 | G19=0.6
R20: A20=Tỷ lệ re-new | B20=Tỷ lệ re-new (%) = Số KH tái ký / Số KH đến hạn kết thúc hợp đồng
Tối đa 100% | C20=0.3 | D20=0.4 | E20=0.45 | F20=0.5 | G20=0.0
R21: A21=Hoàn thành task đúng deadline | C21=0.7 | D21=1.0 | E21=1.0 | F21=1.0 | G21=0.4
R22: A22=Lương cứng | D22=8000000.0 | E22=10000000.0 | F22=12000000.0
R23: A23=Lương KPI | D23=2000000.0 | E23=3000000.0 | F23=4000000.0
R24: A24=Tổng thu nhập | D24=10000000 | E24=13000000 | F24=16000000
R25: D25=Junior | E25=Executive | F25=Senior
R27: A27=Ví dụ
R28: A28=KPI đánh giá | B28=Mô tả | C28=Trọng Số | D28=Đơn Vị tính | E28=Mức tham chiếu | F28=Thực Tế | G28=Tỷ Lệ Hoàn Thành
R29: A29=Doanh thu | B29=Mô tả: Doanh thu thuần từ khách hàng do Account trực tiếp quản lý.

Giải thích rõ:
Là doanh thu thực nhận của agency sau khi:
- Trừ hoàn phí, chiết khấu, rebate cho khách hàng (nếu có).
- Không tính ngân sách ads chuyển thẳng cho nền tảng (nếu mô hình không ghi nhận doanh thu ads).
- Trừ tất cả chi phí phải outsource 

Doanh thu được ghi nhận khi:
Hợp đồng đã ký và Khách đã thanh toán (hoặc theo mốc thanh toán quy định).
Vượt 100% | C29=0.4 | D29=triệu đồng | E29=100000000.0 | F29=170000000.0 | G29=1.7
R30: A30=Tỷ lệ dự án chốt thành công | B30=Tỷ lệ chốt (%) = Số proposal ký hợp đồng / Tổng proposal đã gửi 
Chỉ tính proposal:
- Đã gửi chính thức cho khách hàng.
- Có ngân sách và scope rõ ràng.
Tối đa 100% | C30=0.35 | D30=% | E30=0.3 | F30=0.3 | G30=1
R31: A31=Tỷ lệ re-new | B31=Tỷ lệ re-new (%) = Số KH tái ký / Số KH đến hạn kết thúc hợp đồng
Tối đa 100% | C31=0.25 | D31=% | E31=0.55 | F31=0.55 | G31=1
R33: A33=Senior
R34: A34=Chính sách thu nhập  | E34=số lượng content, tài liệu nội bộ | F34=truyền thông nội bộ | G34=video
R35: A35=Lương cứng | B35=Mức hoàn thành KPI | C35=Mức thưởng P3
R36: A36=12000000.0 | B36=<70% | C36=0.0
R37: B37=70% <= A < 85% | C37=2000000.0
R38: B38=85% <= A < 100% | C38=3000000.0
R39: B39=100% = A  | C39=4000000.0
R40: A40=Lương cứng | B40=Mức hoàn thành KPI | C40=Mức lương KPI | D40=Thu nhập
R41: A41=12000000.0 | B41=0.7 | C41=2000000.0 | D41=14000000
R42: B42=0.85 | C42=3000000.0 | D42=15000000
R43: B43=1.0 | C43=4000000.0 | D43=16000000
R45: A45=Executive
R46: A46=Chính sách thu nhập  | E46=số lượng content, tài liệu nội bộ | F46=truyền thông nội bộ | G46=video
R47: A47=Lương cứng | B47=Mức hoàn thành KPI | C47=Mức thưởng P3
R48: A48=10000000.0 | B48=<70% | C48=0.0
R49: B49=70% <= A < 85% | C49=1000000.0
R50: B50=85% <= A < 100% | C50=2000000.0
R51: B51=100% = A  | C51=3000000.0
R52: A52=Lương cứng | B52=Mức hoàn thành KPI | C52=Mức lương KPI | D52=Thu nhập
R53: A53=10000000.0 | B53=0.7 | C53=1000000.0 | D53=11000000
R54: B54=0.85 | C54=2000000.0 | D54=12000000
R55: B55=1.0 | C55=3000000.0 | D55=13000000
R57: A57=Junior
R58: A58=Chính sách thu nhập  | E58=số lượng content, tài liệu nội bộ | F58=truyền thông nội bộ | G58=video
R59: A59=Lương cứng | B59=Mức hoàn thành KPI | C59=Mức thưởng P3
R60: A60=8000000.0 | B60=<70% | C60=0.0
R61: B61=70% <= A < 85% | C61=1000000.0
R62: B62=85% <= A < 100% | C62=1500000.0
R63: B63=100% = A  | C63=2000000.0
R64: A64=Lương cứng | B64=Mức hoàn thành KPI | C64=Mức lương KPI | D64=Thu nhập
R65: A65=8000000.0 | B65=0.7 | C65=1000000.0 | D65=9000000
R66: B66=0.85 | C66=1500000.0 | D66=9500000
R67: B67=1.0 | C67=2000000.0 | D67=10000000
R69: A69=Định nghĩa số lượng renew trong tháng | B69=Tổng số lượng khách hàng dự kiến renew trong tháng hiện tại
Khách hàng renew: là khách hàng tái ký hợp đồng sau khi kết thúc hợp đồng giai đoạn trước. | C69=Đầu tháng:
Sale gửi lại HR 
- Danh sách KH dự kiến renew tháng hiện tại và các tháng sau
- Danh sách đã renew, không renew được, những trường hợp loại trừ, delay tháng trước
- HR tổng kết, tính tỷ lệ renew 
R70: B70=Trừ những trường hợp sau sẽ được tính loại trừ trên tổng  
- Kết quả vận hành tốt nhưng vì lí do khách quan nên KH không renew (vì nội bộ khách hàng vận hành không tốt, giấy tờ sản phẩm chưa có, sản phẩm của KH khó bán...)
R71: A71=Thời điểm xác nhận ý định renew của KH | B71=- Giai đoạn thử nghiệm: Ngày đầu tiên của 7 ngày cuối cùng trong giai đoạn thử nghiệm phải xác định được KH có renew hay không và thời điểm renew dự kiến
- Giai đoạn vận hành: Ngay sau khi ký hợp đồng giai đoạn trước

Output: trả lời 2 câu hỏi
- KH có dự định renew hay không?
- Khi nào? (Ngày tháng nào) (Nếu KH không báo chính xác ngày thì sẽ tính từ ngày 01 của tháng đó) | D71=loại trừ khi
1. KH ngay từ đầu đã báo là làm thử, ko renew 
2. KH dừng business (ví dụ như case Umikai)

Còn lại những trường hợp khác vẫn tính tỷ lệ
KH báo tạm dừng nhưng ko nói rõ lí do hoặc lí do chung chung kiểu ko muốn làm nữa thì vẫn bị tính
R72: A72=Thời gian ghi nhận renew | B72=Thời gian bắt đầu tính là thời điểm ở output
Trong vòng 45 ngày, khách hàng thanh toán hợp đồng tại thời điểm tháng nào thì sẽ được tính tỷ lệ renew của tháng đó.
Nếu quá 45 ngày, khách hàng thanh toán hợp đồng thì dự án đó vẫn tính là dự án cần renew trong tháng nhưng sẽ không được ghi nhận là dự án renew thành công trong tháng. (vẫn được ghi nhận doanh thu nhưng không được ghi nhận tỷ lệ renew)
R74: A74=TỶ LỆ CHỐT | B74=Định nghĩa: Tỷ lệ dự án chốt thành công là số lượng KH thanh toán hợp đồng mới / số lượng dự án khả thi trong tháng
R75: B75=Trường hợp dự án có trạng thái on hold và cancel (mà không nằm trong phase của bộ phận vận hành) sẽ không được tính là dự án khả thi và các lý do khách quan khác
R76: A76=Thời gian ghi nhận | B76=Thời gian bắt đầu tính là thời điểm đầu tiên được ghi nhận khi bắt đầu chuyển sang các stage của phase bộ phận vận hành (làm hàm ghi nhận trong file public quản lý dự án)
Trong vòng 45 ngày, khách hàng thanh toán hợp đồng tại thời điểm tháng nào thì sẽ được tính tỷ lệ chốt của tháng đó.
Nếu quá 45 ngày, khách hàng thanh toán hợp đồng thì dự án đó vẫn tính là dự án cần chốt trong tháng nhưng sẽ không được ghi nhận là chốt thành công trong tháng. (vẫn được ghi nhận doanh thu, nhưng không được ghi nhận tỷ lệ chốt)
R77: A77=yếu tố ảnh hưởng | B77=proposal ko giải quyết đc vấn đề của KH
R78: B78=cách làm việc của sale với KH, chưa bám sát KH 
R79: B79=khách quan từ KH, chưa cấp thiết (sale cần khai thác đc để dự trù từ đầu)
R80: B80=quy trình của KH về việc check điều khoản hđ (sale cần khai thác đc để dự trù từ đầu)
R81: A81=Thưởng dự án
R82: A82=Tỷ lệ hoàn thành mục tiêu dự án | B82=Dự án đạt được các chỉ số theo mục tiêu đã cam kết với KH theo hợp đồng
Cách 1: Tính trọng số từng chỉ tiêu tính theo tỷ trọng DTT của hạng mục đó/ DTT tổng dự án
Chia theo tỷ lệ khối lượng công việc để tính được DTT từng tháng

Cách 2: tính theo KPI từng dự án, chia trung bình theo số lượng dự án đang vận hành trong tháng
Ví dụ: dự án 1 đạt 90%, dự án 2 đạt 80%, trung bình hiệu quả dự án =(90+80)/2=85%
R83: A83=Ví dụ
R84: A84=Chỉ số KPI | B84=Kênh | C84=Mục tiêu tháng 1 | D84=Trọng số
R85: A85=Page Likes / Followers mới | B85=Facebook (số like) | C85=1000.0 | D85=tính theo tỷ lệ doanh thu từng hạng mục/ tổng doanh thu tháng của KH
R86: A86=TikTok Followers mới | B86=TikTok (số follow) | C86=500.0
R87: A87=Reach (Facebook Ads) | B87=Facebook (lượt reach) | C87=300000.0
R88: A88=Engagement Rate | B88=Facebook | C88=0.05
R89: A89=Video Views Rate (TikTok Ads) | B89=TikTok | C89=0.15
R90: A90=Click-through Rate (FB Ads) | B90=Facebook | C90=0.02
R92: A92=Dữ liệu cần có mỗi dự án | B92=Mỗi dự án phải có file checklist theo quy trình
Đến bước proposal thì có phần check duyệt của leader 
R93: B93=Các hạng mục công việc phải có cột deadline và cột sản phẩm hoặc cột thời gian hoàn thành thực tế


##### SHEET: Leader Sale #####
R1: A1=KPI TNKD
R2: A2=Nhân sự / Mục Tiêu | B2=Trọng Số | C2=Đơn Vị  | D2=Mức Tham Chiếu | E2=Mô Tả | F2=Thực Tế | G2=Tỷ Lệ Hoàn Thành | H2=% Quy Đổi Chung
R3: A3=Doanh Thu Thuần  | B3=0.8 | C3=Vnđ | D3=200000000.0 | E3=DTT cơ bản/cá nhân + DTT kỳ vọng/cá nhân | F3=200000000.0 | G3=1 | H3=1
R4: A4=Tỷ lệ nhân sự đạt DTT tiêu chuẩn theo từng vị trí | B4=0.2 | C4=Thành viên | D4=70% | E4= Chia theo cấp độ: NV chính thức
Full chỉ tiêu là 100%, tính theo tỷ lệ hoàn thành | F4=0.7 | G4=1
R5: A5=Định phí trung bình tháng | B5=Chi phí bình quân đầu người | C5=Số nhân sự
R6: A6=73733585.0 | B6=6144945.0 | C6=25.0
R7: A7=Cố định doanh thu 1 sale
R8: A8=CƠ CẤU DOANH THU | D8=6.0 | T8=Chi phí 1 người | U8=0.043
R9: A9=DTT toàn team (gồm cả TP) | B9=Số lượng sale | C9=Số lượng vận hành DVQC | D9=Số lượng vận hành và hỗ trợ | E9=Doanh thu 1 sale | F9=% hoa hồng team | G9=Hoa hồng TN | H9=% KPI cá nhân sale | I9=% hoa hồng sale | J9=hoa hồng cá nhân sale | K9=Tổng hoa hồng TEAM | L9=Lương cứng TN | M9=Lương cứng 1 sale | N9=Tổng lương cứng 1 team KD | O9=Tổng thu nhập trả cho 1 team KD | P9=Tỷ trọng TN team/ DTT 1 team | Q9=Tổng thu nhập TN | R9=Tỷ trọng TN TP/ DTT team | S9=Tổng chi phí cả team / DTT | U9=Chi phí bán hàng | V9=Chi phí THỰC TẾ cho team | W9=Lương vận hành | X9=Chi phí toàn công ty | Y9=Tỷ trọng chi phí | Z9=Lỗ/ lãi
R10: A10=97500000 | B10=3.9 | C10=10.0 | D10=16 | E10=25000000.0 | F10=0 | G10=0 | H10=2.5 | I10=0.13 | J10=3250000 | K10=12675000 | L10=8000000 | M10=3000000 | N10=19700000 | O10=32375000 | P10=0.3320512821 | Q10=8000000 | R10=0.08205128205 | S10=0.8181748909 | T10=9672867.727 | U10=4192500 | V10=0.8611748909 | W10=170500000 | X10=405037935.5 | Y10=4.154235236 | Z10=-307537935.5
R11: A11=100000000 | B11=4 | C11=10.0 | D11=16 | E11=25000000 | F11=0 | G11=0 | H11=2.5 | I11=0.13 | J11=3250000 | K11=13000000 | L11=10000000 | M11=3000000 | N11=22000000 | O11=35000000 | P11=0.35 | Q11=10000000 | R11=0.1 | S11=0.8328034048 | T11=9656068.095 | U11=4300000 | V11=0.8758034048 | W11=170500000 | X11=408277430 | Y11=4.0827743 | Z11=-308277430
R12: A12=125000000 | B12=5 | C12=10.0 | D12=16 | E12=25000000 | F12=0 | G12=0 | H12=2.5 | I12=0.13 | J12=3250000 | K12=16250000 | L12=10000000 | M12=3000000 | N12=25000000 | O12=41250000 | P12=0.33 | Q12=10000000 | R12=0.08 | S12=0.7858306364 | T12=9496471.591 | U12=5375000 | V12=0.8288306364 | W12=170500000 | X12=420672375 | Y12=3.365379 | Z12=-295672375
R13: A13=150000000 | B13=6 | C13=10.0 | D13=16 | E13=25000000 | F13=0.005 | G13=750000 | H13=2.5 | I13=0.13 | J13=3250000 | K13=20250000 | L13=10000000 | M13=3000000 | N13=28000000 | O13=48250000 | P13=0.3216666667 | Q13=10750000 | R13=0.07166666667 | S13=0.758035142 | T13=9350753.043 | U13=6450000 | V13=0.801035142 | W13=184500000 | X13=447817320 | Y13=2.9854488 | Z13=-297817320
R14: A14=175000000 | B14=7 | C14=10.0 | D14=16 | E14=25000000 | F14=0.005 | G14=875000 | H14=2.5 | I14=0.13 | J14=3250000 | K14=23625000 | L14=10000000 | M14=3000000 | N14=31000000 | O14=54625000 | P14=0.3121428571 | Q14=10875000 | R14=0.06214285714 | S14=0.7334995524 | T14=9217177.708 | U14=7525000 | V14=0.7764995524 | W14=184500000 | X14=460337265 | Y14=2.630498657 | Z14=-285337265
R15: A15=200000000 | B15=8 | C15=10.0 | D15=16 | E15=25000000 | F15=0.01 | G15=2000000 | H15=2.5 | I15=0.13 | J15=3250000 | K15=28000000 | L15=12000000 | M15=3000000 | N15=36000000 | O15=64000000 | P15=0.32 | Q15=14000000 | R15=0.07 | S15=0.729242978 | T15=9094288.4 | U15=8600000 | V15=0.772242978 | W15=184500000 | X15=475857210 | Y15=2.37928605 | Z15=-275857210
R16: A16=250000000 | B16=10 | C16=10.0 | D16=16 | E16=25000000 | F16=0.01 | G16=2500000 | H16=2.5 | I16=0.13 | J16=3250000 | K16=35000000 | L16=12000000 | M16=3000000 | N16=42000000 | O16=77000000 | P16=0.308 | Q16=14500000 | R16=0.058 | S16=0.6985360148 | T16=8875818.519 | U16=10750000 | V16=0.7415360148 | W16=194000000 | X16=510647100 | Y16=2.0425884 | Z16=-260647100
R17: A17=300000000 | B17=12 | C17=10.0 | D17=16 | E17=25000000 | F17=0.01 | G17=3000000 | H17=2.5 | I17=0.13 | J17=3250000 | K17=42000000 | L17=12000000 | M17=3000000 | N17=48000000 | O17=90000000 | P17=0.3 | Q17=15000000 | R17=0.05 | S17=0.6764575713 | T17=8687482.414 | U17=12900000 | V17=0.7194575713 | W17=194000000 | X17=535936990 | Y17=1.786456633 | Z17=-235936990
R18: A18=350000000 | B18=14 | C18=12.0 | D18=18 | E18=25000000 | F18=0.015 | G18=5250000 | H18=2.5 | I18=0.13 | J18=3250000 | K18=50750000 | L18=12000000 | M18=3000000 | N18=54000000 | O18=104750000 | P18=0.2992857143 | Q18=17250000 | R18=0.04928571429 | S18=0.6583984026 | T18=8379296.061 | U18=15050000 | V18=0.7013984026 | W18=232000000 | X18=613266770 | Y18=1.752190771 | Z18=-263266770
R19: A19=400000000 | B19=16 | C19=13.0 | D19=19 | E19=25000000 | F19=0.015 | G19=6000000 | H19=2.5 | I19=0.13 | J19=3250000 | K19=58000000 | L19=12000000 | M19=3000000 | N19=60000000 | O19=118000000 | P19=0.295 | Q19=18000000 | R19=0.045 | S19=0.6432067559 | T19=8193100.139 | U19=17200000 | V19=0.6862067559 | W19=232000000 | X19=644951605 | Y19=1.612379013 | Z19=-244951605
R20: A20=450000000 | B20=18 | C20=13.0 | D20=19 | E20=25000000 | F20=0.015 | G20=6750000 | H20=2.5 | I20=0.13 | J20=3250000 | K20=65250000 | L20=12000000 | M20=3000000 | N20=66000000 | O20=131250000 | P20=0.2916666667 | Q20=18750000 | R20=0.04166666667 | S20=0.6330461056 | T20=8085302.5 | U20=19350000 | V20=0.6760461056 | W20=232000000 | X20=670491495 | Y20=1.4899811 | Z20=-220491495
R22: A22=Mức Level | B22=Khoảng Cách | C22=Mức lương | D22=Mức doanh thu thực cả team | E22=% com | F22=Thưởng | G22=Thu nhập
R23: A23=Level 01 | B23=0.59 | C23=8000000.0 | D23=97500000 | E23=0.0 | F23=0 | G23=8000000
R24: A24=Level 02 | B24=0.6 | C24=10000000.0 | D24=100000000 | E24=0.0 | F24=0 | G24=10000000
R25: A25=Level 03 | B25=0.7 | C25=10000000.0 | D25=125000000 | E25=0.0 | F25=0 | G25=10000000
R26: A26=Level 04 | B26=0.8 | C26=10000000.0 | D26=150000000 | E26=0.005 | F26=750000 | G26=10750000
R27: A27=Level 05 | B27=0.9 | C27=10000000.0 | D27=175000000 | E27=0.005 | F27=875000 | G27=10875000
R28: A28=Level 06 | B28=1.0 | C28=12000000.0 | D28=200000000 | E28=0.01 | F28=2000000 | G28=14000000
R29: A29=Level 07 | B29=1.2 | C29=12000000.0 | D29=250000000 | E29=0.01 | F29=2500000 | G29=14500000
R30: A30=Level 08 | B30=1.4 | C30=12000000.0 | D30=300000000 | E30=0.01 | F30=3000000 | G30=15000000
R31: A31=Level 09 | B31=1.6 | C31=12000000.0 | D31=350000000 | E31=0.015 | F31=5250000 | G31=17250000
R32: A32=Level 10 | B32=1.8 | C32=12000000.0 | D32=400000000 | E32=0.015 | F32=6000000 | G32=18000000
R33: A33=Level 11 | B33=2.0 | C33=12000000.0 | D33=450000000 | E33=0.015 | F33=6750000 | G33=18750000


##### SHEET: HR teamlead #####
R1: A1=1. MÔ TẢ CÔNG VIỆC 
R2: A2=Phân bổ | B2=Nhiệm Vụ | C2=Mô Tả Chi Tiết
R3: A3=Định biên nhân sự | B3=Hoạch định nguồn nhân lực | C3=Phân tích thực trạng nguồn nhân lực trong tổ chức
R4: C4=Xác định nhu cầu về nguồn nhân lực theo ngắn hạn, trung hạn và dài hạn đáp ứng tốc độ phát triển của tổ chức
R5: C5=Xây dựng và triển khai kế hoạch đảm bảo nguồn nhân lực trong tổ chức
R6: B6=Xây dựng mô tả công việc và định biên nhân sự cho từng vị trí chức danh | C6=Xây dựng và điều chỉnh mô tả công việc
R7: C7=Xây dựng định biên nhân sự từng phòng ban chức năng
R8: A8=Tuyển dụng | B8=Xây dựng hệ thống tuyển dụng: Quy trình, tiêu chuẩn tuyển dụng; hệ thống đánh giá ứng viên (kịch bản PV, bộ câu hỏi tuyển dụng, chân dung ứng viên, hệ thống đánh giá) | C8=Xây dựng quy trình và chính sách tuyển dụng tuyển dụng nhân sự
R9: C9=Xây dựng chân dung ứng viên cho từng vị trí để đảm bảo tuyển chọn đúng người phù hợp về chuyên môn và văn hóa của tổ chức
R10: C10=Xây dựng tiêu chuẩn tuyển dụng cho từng vị trí
R11: C11=Xây dựng kịch bản phỏng vấn
R12: C12=Xây dựng bộ câu hỏi phỏng vấn và đánh giá ứng viên
R13: C13=Xây dựng hành trình trải nghiệm ứng viên để đảm bảo tối ưu các điểm trạm để thu hút và chiêu mộ ứng viên giúp gia tăng hiệu quả tuyển dụng và giữ chân nhân sự
R14: C14=Thiết kế và điều chỉnh trải nghiệm tại từng điểm trạm trên hành trình ứng viên
R15: B15=Xây dựng kế hoạch tuyển dụng | C15=Xây dựng kế hoạch tuyển dụng theo tháng/quý/năm đảm bảo đáp ứng nhu cầu nhân lực cho hoạt động của tổ chức
R16: B16=Xây dựng thương hiệu tuyển dụng | C16=Xây dựng và phát triển hệ thống kênh tuyển dụng đảm bảo thu hút đối tượng ứng viên tiềm năng cho các vị trí tuyển dụng
R17: B17=Xây dựng, quản lý và kiểm soát ngân sách tuyển dụng | C17=Xây dựng ngân sách tuyển dụng
R18: C18=Thông kê, theo dõi ngân sách tuyển dụng trên từng kênh, từng vị trí
R19: C19=Kiểm soát,ngân sách tuyển dụng trên từng kênh, từng vị trí
R20: C20=Báo cáo chi phí tuyển dụng đã sử dụng (từng vị trí, từng kênh) và đánh giá hiệu quả từng kênh tuyển dụng trên chi phí
R21: B21=Triển khai hoạt động tuyển dụng | C21=Phối hợp với phòng ban chuyên môn phỏng vấn ứng viên cấp bậc nhân viên trở lên
R22: C22=Thỏa thuận về chế độ chính sách ứng viên
R23: B23=Báo cáo và đánh giá hiệu quả hoạt động tuyển dụng | C23=Làm các báo tuyển dụng để đánh giá hiệu quả và phân tích các cơ hội đột phá
R24: A24=Đào tạo và phát triển | B24=Xây dựng bộ khung năng lực | C24=Phối hợp phòng ban để phân tích yêu cầu công việc từng vị trí và xác định bộ khung năng lực tiêu chuẩn
R25: B25=Xây dựng chương trình và lộ trình đào tạo, phát triển năng lực | C25=Đánh giá thực trạng năng lực từng nhân sự mỗi vị trí, xác định điểm GAP
R26: C26=Thiết kế chương trình đào tạo cho từng năng lực, nhóm năng lực phù hợp với mục tiêu công việc các vị trí
R27: C27=Thiết kế lộ trình phát triển phù hợp với năng lực từng cá nhân
R28: B28=Quản lý và triển khai hoạt động đào tạo | C28=Lập kế hoạch đào tạo và triển khai các chương trình đạo theo khung năng lực
R29: C29=Theo dõi, báo cáo và đánh giá hiệu quả đào tạo sau mỗi chương trình
R30: A30=Chính sách lương và phúc lợi | B30=Xây dựng hệ thống chính sách: Quy trình, tiêu chuẩn làm việc; Nội quy, quy định; Chính sách phúc lợi | C30=Xây dựng quy trình tính lương, thưởng, phúc lợi
R31: C31=Xây dựng chính sách phúc lợi ngắn hạn, trung hạn và dài hạn
R32: B32=Xây dựng hệ thống lương, thưởng: Quy chế lương (cơ cấu lương); Thang bảng lương | C32=Xây dựng hệ thống thang bảng lương
R33: C33=Xây dựng quy chế lương, thưởng, phúc lợi đảm bảo công bằng và tạo động lực cho nhân sự
R34: C34=Xây dựng cơ chế lương cho từng bộ phận
R35: B35=Xây dựng và kiểm soát ngân sách lương thưởng, phúc lợi, BHXH | C35=Xây dựng và kiểm soát ngân sách lương đảm bảo quỹ lương theo định mức
R36: B36=Triển khai hoạt động tính toán và chi trả lương, thưởng, phúc lợi, BHXH | C36=Tiếp nhận và xử lý các đề xuất về lương, thưởng, phúc lợi cho nhân viên
R37: C37=Kiểm soát tính toán tiền lương và tổng hợp bảng lương một cách chính xác cho toàn công ty
R38: C38=Kiểm soát kê khai và xử lý các chế độ BHXH cho CBNV
R39: B39=Báo cáo công tác lương thưởng, phúc lợi, BHXH | C39=Kiểm soát chi phí lương trên từng điểm bán
R40: C40=Kiểm soát việc tính toán và chi trả các khoản thưởng và phúc lợi trong công ty
R41: C41=Đo lường và đánh giá sự hải lòng của nhân viên về chế độ phúc lợi công ty
R42: C42=Báo cáo các chỉ số lương, thưởng, BHXH; phân tích sự cố và cơ hội đột phá
R43: A43=Quản lý hiệu suất | B43=Quản lý và đánh giá hiệu suất làm việc của nhân viên | C43=Xây dựng hệ thống đánh giá hiệu suất công việc (KPI) cấp công ty/phòng ban/cá nhân
R44: C44=Theo dõi và tổng hợp kết quả KPI
R45: C45=Đo lường và đánh giá hiệu suất làm việc định kỳ tháng/quý/năm thông qua chỉ tiêu hoàn thành KPI
R46: A46=Hợp đồng và quan hệ lao động | B46=Quản lý thông tin nhân sự | C46=Quản trị data nhân sự để cung và đánh giá dữ liệu thông tin nhân sự
R47: B47=Quản lý hợp đồng lao động và hồ sơ nhân sự | C47=Kiểm soát việc theo dõi, ký kết, thanh lý hợp đồng lao động trong công ty
R48: C48=Theo dõi và quản lý hồ sơ nhân sự chính thức
R49: B49=Triển khai hoạt động về quan hệ lao động | C49=Kiểm soát việc thực hiện hoạt động về quan hệ lao động
R50: B50=Giải quyết các vấn để về quan hệ lao động | C50=Giải quyết các vấn đề về quan hệ lao động xảy ra trong tổ chức
R51: B51=Báo cáo và đánh giá hiệu quả thực hiện quan hệ lao động trong tổ chức | C51=Báo cáo và đánh giá hiệu quả thực hiện quan hệ lao động trong tổ chức
R52: A52=Truyền thông nội bộ | B52=Xây dựng kế hoạch truyền thông | C52=Xây dựng kế hoạch truyền thông tháng/quý/năm
R53: B53=Xây dựng, quản lý và kiểm soát ngân sách truyền thông | C53=Xây dựng và kiểm soát ngân sách truyển thông đảm bảo theo định mức
R54: B54=Triển khai hoạt động truyền thông văn hóa | C54=Tổ chức hoạt động/chương trình gắn kết đội ngũ để truyển thông về văn hóa trong tổ chức
R55: C55=Kiểm soát thực hiện, triển khai hoạt động truyền thông văn hóa
R56: B56=Báo cáo và đánh giá hiệu quả hoạt động truyền thông văn hóa | C56=Kiểm soát báo cáo về đánh giá hiệu quả của hoạt động truyền thông văn hóa
R57: A57=Công tác hành chính | B57=Xây dựng hệ thống hành chính: Quy trình, quy định hành chính; Hướng dẫn các thủ tục hành chính | C57=Xây dựng các quy trình, quy định hành chính trong tổ chức
R58: B58=Xây dựng, quản lý và kiểm soát ngân sách hành chính | C58=Quản lý và kiểm soát ngân sách
R59: B59=Đảm bảo về công tác hậu cần: Trang thiết bị làm việc; Môi trường làm việc; ... | C59=Xây dựng tiêu chuẩn sử dụng và cấp phát tài sản, TTB làm việc trong công ty theo từng vị trí chức danh
R61: A61=2. CÁC CHỈ SỐ KPIs
R62: A62=Nhóm KPI | B62=KPI | C62=Mô tả đo lường | D62=Trọng số nhóm | E62=Trọng Số Chi Tiết | F62=Đơn Vị tính | G62=Mức Tham Chiếu | H62=Thực Tế | I62=Tỷ Lệ Hoàn Thành | J62=Tổng KPI
R63: A63=Tuyển dụng và cơ cấu nhân sự | B63=Tỷ lệ đáp ứng nhu cầu nhân sự | C63=Số nhân sự tuyển được / tổng số nhân sự cần tuyển trong tháng | D63=0.7 | E63=0.2 | G63=0.9
R64: B64=Chất lượng ứng viên | C64=Số lượng ứng viên pass đánh giá trong tháng/ Tổng số UV đến kỳ hạn đánh giá (tính toàn bộ phận) | E64=0.2 | G64=0.7
R65: A65=Đào tạo | B65=Tỷ lệ hoàn thành kế hoạch đào tạo | C65=Số chương trình đào tạo hoàn thành/ Tổng chương trình đào tạo theo kế hoạch tháng | E65=0.15 | G65=1.0
R66: B66=Điểm đánh giá về chất lượng đào tạo | C66=100% nhân sự hoàn tất bài tập sau đào tạo | E66=0.15 | G66=1.0
R67: C67=80% nhân sự đạt điểm từ 8 trở lên | E67=0.15 | G67=0.8
R68: A68=Quản trị hiệu suất | B68=Hoàn thành review đúng hạn | C68=Tỷ lệ nhân sự được review KPI trong tháng của các bộ phận
Cách tính: Nhân sự hoàn tất review / Tổng nhân sự thuộc kỳ | E68=0.15 | G68=1.0
R69: A69=Tỷ lệ nghỉ việc | B69=Turnover rate | C69=Kinh doanh: Số NS nghỉ trong quý / ((số nhân sự đầu kỳ + số nhân sự cuối kỳ)/2) | D69=0.3 | E69=0.5 | G69=Sale <=35%
R70: C70=Vận hành: Số NS nghỉ trong quý / ((số nhân sự đầu kỳ + số nhân sự cuối kỳ)/2) | E70=0.5 | G70=BO <= 15%
R71: A71=Kiểm soát chi phí | B71=Tối ưu hóa chi phí nhân sự | C71=Doanh thu/(chi phí lương + thưởng + bảo hiểm + tuyển dụng + đào tạo) | E71=Mục tiêu công ty, theo dõi theo quý | G71=Nghiên cứu thêm


##### SHEET: Sale teamlead #####
R1: A1=1. MÔ TẢ CÔNG VIỆC 
R2: A2=Phân bổ | B2=Nhiệm Vụ | C2=Mô Tả Chi Tiết
R3: B3=Tìm kiếm, phát triển khách hàng | C3=- Tìm kiếm, duy trì và phát triển mạng lưới khách hàng và đối tác tiềm năng.
- Tìm hiểu nhu cầu và mục tiêu của khách hàng để tư vấn và đề xuất giải pháp phù hợp.
- Tiếp nhận và xử lý yêu cầu từ khách hàng, phối hợp với các bộ phận nội bộ để triển khai các chiến dịch marketing (digital/branding/media...).
- Thực hiện đầy đủ các chỉ số yêu cầu cơ bản được giao theo từng bộ phận của công ty (Chỉ số tiếp cận khách hàng,...).
- Trực tiếp thực hiện, ký kết hợp đồng.
R4: B4=Quản lý và điều phối team Sale | C4=- Quản lý, đào tạo và phát triển đội ngũ Sale (Intern, Fresher).
- Phân công công việc, giám sát tiến độ và hiệu quả làm việc của team.
- Đảm bảo đội ngũ thực hiện đúng quy trình tư vấn, chăm sóc và triển khai dịch vụ.
R5: B5=Quản lý và hỗ trợ khách hàng | C5=- Giám sát tiến độ dự án, quản lý & báo cáo hiệu quả chiến dịch với khách hàng
- Báo cáo kết quả chiến dịch, phân tích hiệu quả và đề xuất phương án tối ưu.
- Tham gia vào quá trình lên kế hoạch, báo giá và đàm phán hợp đồng với khách hàng.
- Tiếp nhận và xử lý các khiếu nại của khách hàng.
R6: B6=Các nhiệm vụ khác | C6=- Báo cáo lên các cấp quản lý về nhu cầu, vấn đề, mối quan tâm của khách hàng, hoạt động của đối thủ cạnh tranh và tiềm năng.
- Báo cáo với cấp trên về tiến độ & kết quả kinh doanh hàng ngày, tuần theo quy định.
R8: A8=2. CÁC CHỈ SỐ KPIs
R9: A9=KPI | B9=Mô tả đo lường | C9=Trọng Số Chi Tiết | D9=Đơn Vị tính | E9=Mục tiêu | F9=Thực Tế | G9=Tỷ Lệ Hoàn Thành | H9=Tổng KPI
R10: A10=Tỷ lệ brief đạt chuẩn team sale | B10=Số brief đạt chuẩn / tổng số brief
Briefing đầy đủ thông tin: Định nghĩa lại rõ ràng, hiện đang chưa xác định đc  | C10=0.5 | E10=0.9
R11: A11=Tỷ lệ chuyển đổi từ brief thành pitching | B11=Số brief đủ điều kiện lên proposal / tổng brief | C11=0.5 | E11=0.5
R12: A12=Tỷ lệ intern có deal chốt
deal chốt là đem về doanh thu, khả năng thực tế để giúp intern chốt và đem về doanh thu không cao, có thể hỗ trợ ở phần brief nhưng khả năng chốt sale chưa tốt, cần có SM hỗ trợ | B12=Số intern có ít nhất 1 KHM / tổng intern | C12=0.0 | E12=0.5
R14: A14=% hoàn thành KPI | B14=Mức thưởng KPI
R15: A15=50 - 70% | B15=1000000.0
R16: A16=70% - 90% | B16=2000000.0
R17: A17=90%< | B17=3000000.0
R19: A19=- Về phần này tỉ lệ brief đạt chuẩn cụ thể sẽ tính từ khâu briefing (Briefing là  tính từ lúc các em bắt đầu điền thông tin lên brief và trao đổi với KH).
- Lead in: khi mới bắt đầu tiếp cận khách hàng - thường trao đổi qua lại >4 lần (Data raw)
R21: A21=. Tỉ lệ chuyển đổi 
- những case mà đến phần handover - evaluation mà team vận hành cancel thì sẽ không tính vào mục chuyển đổi thành pitching (Vì KH có pitching nhưng cancel không process dự án do rủi ro tiềm ẩn - cái này sẽ phải note rõ lý do thì mới được tính là hợp lệ - ví dụ sản phẩm không có giấy tờ, KH theo dạng quá chợ quá, nội bộ phức tạp chả hạn)

R22: A22=KPI tháng 7 | B22=Mô tả đo lường | C22=Trọng Số Chi Tiết | D22=Đơn Vị tính | E22=Mục tiêu | F22=Thực Tế | G22=Tỷ Lệ Hoàn Thành | H22=Tổng KPI
R23: A23=Tỷ lệ brief đạt chuẩn team sale | B23=Số brief đạt chuẩn / tổng số brief  | C23=0.5 | E23=0.9 | F23=0.9 | G23=1 | H23=0.8333
R24: A24=Tỷ lệ chuyển đổi từ brief thành pitching | B24=Số brief đủ điều kiện lên proposal / tổng brief | C24=0.5 | E24=0.5 | F24=0.3333 | G24=0.6666
R26: A26=KPI tháng 8 | B26=Mô tả đo lường | C26=Trọng Số Chi Tiết | D26=Đơn Vị tính | E26=Mục tiêu | F26=Thực Tế | G26=Tỷ Lệ Hoàn Thành | H26=Tổng KPI
R27: A27=Tỷ lệ brief đạt chuẩn team sale | B27=Số brief đạt chuẩn / tổng số brief  | C27=0.5 | E27=0.9 | F27=0.9 | G27=1 | H27=0.8181818182
R28: A28=Tỷ lệ chuyển đổi từ brief thành pitching | B28=Số brief đủ điều kiện lên proposal / tổng brief | C28=0.5 | E28=0.5 | F28=0.3181818182 | G28=0.6363636364


##### SHEET: Planner - Chốt #####
R1: A1=1. MÔ TẢ CÔNG VIỆC 
R2: A2=Phân bổ | B2=Nhiệm Vụ | C2=Mô Tả Chi Tiết
R3: A3=Nộ bộ công ty | B3=Lập kế hoạch Marketing tổng thể, kế hoạch Marketing chi tiết theo từng mục tiêu cụ thể của công ty | C3=Nghiên cứu thị trường và đối thủ cạnh tranh, xu hướng ngành và khách hàng mục tiêu để xây dựng kế hoạch Marketing.
R4: C4=Thu thập và phân tích dữ liệu để xác định các insight khách hàng và thị trường
R5: C5=Phối hợp với bộ phận Content và Design để biến insight thành ý tưởng sáng tạo
R6: C6=Đề xuất ý tưởng kế hoạch và định hướng sáng tạo cho các chiến dịch truyền thông/marketing.
R7: C7=Xây dựng dự báo ngân sách dựa trên mục tiêu công ty
R8: B8=Quản lý và tối ưu ngân sách Marketing | C8=Theo dõi và phân bổ ngân sách hiệu quả cho từng hoạt động cụ thể
R9: C9=Đánh giá độ chính xác của dự báo ngân sách và đề xuất điều chỉnh kịp thời để tối ưu ROAS
R10: B10=Đảm bảo tiến độ và chất lượng kế hoạch | C10=Đảm bảo tỷ lệ hoàn thành kế hoạch đúng hạn
R11: C11=Đề xuất và điều chỉnh kế hoạch nhanh chóng dựa trên phản hồi từ quản lý
R12: C12=Đảm bảo tính khả thi, chi tiết và rõ ràng trong kế hoạch để hỗ trợ các bộ phận triển khai
R13: B13=Quản trị website công ty | C13=Xây dựng landingpage các dịch vụ bao gồm: Nội dung, ý tưởng, dựng thành phẩm
R14: C14=Viết bài dịch vụ & bài SEO
R15: C15=Phối hợp với designer triển khai các idea thiết kế trên web
R16: B16=Phối hợp và hỗ trợ triển khai chiến dịch | C16=Phối hợp các bộ phận Content, Design, Ads trong việc triển khai chiến dịch dựa trên kế hoạch đã đề xuất.
R17: C17=Giám sát và điều chỉnh chiến dịch để đạt được hiệu quả cao nhất, đảm bảo tính nhất quán với mục tiêu đề ra.
R18: C18=Đảm bảo sự hài lòng của khách hàng với kế hoạch và kết quả đạt được.
R19: B19=Báo cáo theo dõi định kỳ | C19=Giám sát tiến độ thực hiện task của các bộ phận 
R20: C20=Đề xuất cải thiện chiến dịch khi triển khai
R21: C21=Báo cáo hoạt động MKT theo tháng, quý, năm
R22: A22=Khách hàng | B22=Lập kế hoạch truyền thông tổng thể, kế hoạch truyền thông chi tiết theo từng mục tiêu cụ thể của khách hàng | C22=Nghiên cứu thị trường và đối thủ cạnh tranh, xu hướng ngành và khách hàng mục tiêu để xây dựng kế hoạch Marketing.
R23: C23=Thu thập và phân tích dữ liệu để xác định các insight khách hàng và thị trường. Đảm bảo các insight được áp dụng vào kế hoạch triển khai nhằm tối ưu hóa hiệu quả chiến dịch
R24: C24=Phối hợp với bộ phận Content và Design để biến insight thành ý tưởng sáng tạo
R25: C25=Đề xuất ý tưởng kế hoạch và định hướng sáng tạo cho các chiến dịch truyền thông/marketing.
R26: B26=Quản lý và tối ưu ngân sách Marketing | C26=Xây dựng dự báo ngân sách dựa trên mục tiêu của khách hàng
R27: C27=Theo dõi và phân bổ ngân sách hiệu quả cho từng hoạt động cụ thể
R28: C28=Đánh giá độ chính xác của dự báo ngân sách và đề xuất điều chỉnh kịp thời để tối ưu ROAS
R29: B29=Đảm bảo tiến độ và chất lượng kế hoạch | C29=Đảm bảo tỷ lệ hoàn thành kế hoạch đúng hạn
R30: C30=Đề xuất và điều chỉnh kế hoạch nhanh chóng dựa trên phản hồi từ khách hàng
R31: C31=Đảm bảo tính khả thi, chi tiết và rõ ràng trong kế hoạch để hỗ trợ các bộ phận triển khai
R32: B32=Báo cáo theo dõi định kỳ | C32=Giám sát tiến độ thực hiện task của các bộ phận 
R33: C33=Đề xuất cải thiện chiến dịch khi triển khai
R34: C34=Báo cáo hoạt động MKT theo tháng, quý, năm
R36: A36=2. CÁC CHỈ SỐ KPIs
R37: A37=Phân bổ | B37=KPI | C37=Mô tả đo lường | D37=Trọng số nhóm | E37=Trọng Số Chi Tiết | F37=Đơn Vị tính | G37=Mức Tham Chiếu | H37=Thực Tế | I37=Tỷ Lệ Hoàn Thành | J37=Tổng KPI
R38: A38=Nội bộ | B38=Chi phí/ 1 CPA đạt mục tiêu | C38=Mess, lead, conversion... đạt kế hoạch đề ra (giá/ 1 CPA), theo kế hoạch tháng | D38=0.3 | E38=1.0 | F38=% | G38=1000000.0 | H38=1000000.0 | I38=1 | J38=0.79
R39: A39=Khách hàng | B39=Doanh thu thuần | C39=Chỉ tính KH phát sinh DT trong tháng | D39=0.7 | E39=0.3 | F39=triệu | G39=300000000.0 | H39=0.0 | I39=0
R40: B40=Tỷ lệ plan được chốt | C40=SL KH chốt/ tổng số lượng KH | E40=0.2 | F40=% | G40=0.3 | H40=0.3 | I40=1
R41: B41=Tỷ lệ dự án đạt mục tiêu | C41=Dự án đạt được các chỉ số theo mục tiêu | E41=0.3 | F41=% | G41=0.6 | H41=0.6 | I41=1
R42: B42=Tỷ lệ renew dự án | C42=Tỷ lệ khách hàng tái sử dụng dịch vụ | E42=0.2 | F42=% | G42=0.55 | H42=0.55 | I42=1
R43: A43=Executive
R44: A44=Phân bổ | B44=KPI | C44=Mô tả đo lường | D44=Trọng số nhóm | E44=Trọng Số Chi Tiết | F44=Đơn Vị tính | G44=Mức Tham Chiếu | H44=Thực Tế | I44=Tỷ Lệ Hoàn Thành | J44=Tổng KPI
R45: A45=Nội bộ | B45=Chi phí/ 1 CPA đạt mục tiêu | C45=Mess, lead, conversion... đạt kế hoạch đề ra (giá/ 1 CPA) | D45=0.3 | E45=1.0 | F45=% | G45=1000000.0 | H45=1000000.0 | I45=1 | J45=1.2
R46: A46=Khách hàng | B46=Doanh thu thuần | C46=Chỉ tính KH phát sinh DT trong tháng | D46=1.0 | E46=0.2 | F46=triệu | G46=300000000.0 | H46=150000000.0 | I46=0.5
R47: B47=Tỷ lệ plan được chốt | C47=SL KH về tiền / tổng số lượng KH gửi proposal/ pitching | E47=0.5 | F47=% | G47=0.35 | H47=0.35 | I47=1
R48: B48=Tỷ lệ dự án đạt mục tiêu | C48== dự án hoàn thành đủ hạng mục cam kết/ tổng số dự án đang vận hành
Dự án đạt được các chỉ số theo mục tiêu đã cam kết với KH
Nếu có bất kỳ chỉ số nào không đạt thì dự án đó được coi là không đạt | E48=0.3 | F48=% | G48=0.7 | H48=0.7 | I48=1
R50: B50=KPI | C50=Junior | D50=Executive | E50=Senior
R51: B51=Doanh thu thuần | C51=300000000.0 | D51=500000000.0 | E51=1000000000.0
R52: B52=Tỷ lệ plan được chốt | C52=0.3 | D52=0.35 | E52=0.4
R53: B53=Tỷ lệ dự án đạt mục tiêu khi bắt đầu dự án | C53=0.6 | D53=0.7 | E53=0.8
R54: B54=Tỷ lệ renew dự án | C54=0.55 | D54=0.6 | E54=0.65
R55: A55=3. YÊU CẦU CÔNG VIỆC
R56: A56=Kiến thức chuyên môn | B56=1. Tốt nghiệp Đại học các chuyên ngành liên quan (MKT, Báo chí, Thương mại,  ngoại thương, ngôn ngữ,..)
2. Có ít nhất 02 năm kinh nghiệm ở vị trí tương đương (ưu tiên có kinh nghiệm trong ngành TMĐT, truyền thông, bán lẻ,..)  
3.  Kỹ năng lập kế hoạch và quản lý dự án tốt.  
R57: A57=Kỹ năng | B57=1. Kỹ năng lập kế hoạch
2. Nghiên cứu thị trường
3. Làm việc nhóm  
4. Tư duy sáng tạo
5. Kỹ năng viết
6. Kỹ năng thuyết phục, đàm phán
R58: A58=Yêu cầu khác | B58=1. Nữ, tuổi...
2. Kiên trì vì mục tiêu chung
3. Kỷ luật, trách nhiệm
R60: A60=4. CHÍNH SÁCH LƯƠNG
R61: A61=Lương cơ bản | B61=Lương KPI | D61=Commission | E61=Thưởng kinh doanh toàn công ty
R62: B62=Mức hoàn thành | C62=Mức thưởng | E62=Căn cứ:
- Theo DTT công ty
- Tỷ trọng từng sản phẩm, dịch vụ
- Tỷ trọng KH từ công ty/ sale
- Tỷ trọng tham gia của từng bộ phận trong quy trình vận hành
- Mức hoàn thành KPI cá nhân
R63: A63=14000000.0 | B63=<70% | C63=0.0
R64: B64=70% <= A < 85% | C64=1000000.0
R65: B65=85% <= A < 100% | C65=2000000.0
R66: B66=100% = A  | C66=3000000.0
R67: B67=Từ 100% trở lên tính theo tỷ lệ
R69: C69=Junior
R70: A70=Junior | B70=Mức hoàn thành KPI | C70=Lương KPI | D70=DTT tối thiểu tương ứng | E70=Thu nhập | F70=CP cố định 1 người | G70=Tổng CP/ DTT
R71: A71=12000000.0 | B71=0.69 | C71=0.0 | D71=500000.0 | E71=12000000 | F71=7532872.0 | G71=39.065744
R72: B72=0.7 | C72=1000000.0 | D72=1000000.0 | E72=13000000 | F72=7532872.0 | G72=20.532872
R73: B73=0.85 | C73=2000000.0 | D73=85714285.71 | E73=14000000 | F73=7532872.0 | G73=0.25121684
R74: B74=1.0 | C74=3000000.0 | D74=300000000 | E74=15000000 | F74=6882281.0 | G74=0.07294093667
R75: B75=1.2 | C75=6000000.0 | D75=585714285.7 | E75=18000000 | F75=5738139.0 | G75=0.04052853
R76: B76=1.5 | C76=10000000.0 | D76=1014285714 | E76=22000000 | F76=4871365.0 | G76=0.02649289507
R77: B77=2.0 | C77=15000000.0 | D77=1728571429 | E77=27000000 | F77=4871365.0 | G77=0.01843797975
R79: A79=Executive | B79=Mức hoàn thành KPI | C79=Lương KPI | D79=DTT tối thiểu tương ứng | E79=Thu nhập | F79=CP cố định 1 người | G79=Tổng CP/ DTT DV MKT
R80: A80=15000000.0 | B80=0.69 | C80=0.0 | D80=500000.0 | E80=15000000 | F80=10217848.19047619 | G80=50.43569638
R81: B81=0.7 | C81=0.0 | D81=1000000.0 | E81=15000000 | F81=10217848.19047619 | G81=25.21784819
R82: B82=0.8 | C82=0.0 | D82=-450000000 | E82=15000000 | F82=10217848.19047619 | G82=-0.05603966265
R83: B83=0.9 | C83=500000.0 | D83=-300000000 | E83=15500000 | F83=10217848.19047619 | G83=-0.08572616063
R84: B84=1.0 | C84=1000000.0 | D84=-150000000 | E84=16000000 | F84=8280676.827586207 | G84=-0.1618711789
R85: B85=1.2 | C85=2000000.0 | D85=150000000 | E85=17000000 | F85=7408949.714285715 | G85=0.1627263314
R86: B86=1.5 | C86=5000000.0 | D86=600000000 | E86=20000000 | F86=6333201.361702127 | G86=0.04388866894
R88: A88=Senior | B88=Mức hoàn thành KPI | C88=Lương KPI | D88=DTT tối thiểu tương ứng | E88=Thu nhập | F88=CP cố định 1 người | G88=Tổng CP/ DTT
R89: A89=20000000.0 | B89=0.69 | C89=0.0 | D89=500000.0 | E89=20000000 | F89=7532872.0 | G89=55.065744
R90: B90=0.7 | C90=0.0 | D90=1000000.0 | E90=20000000 | F90=7532872.0 | G90=27.532872
R91: B91=0.8 | C91=2000000.0 | D91=47619047.62 | E91=22000000 | F91=7532872.0 | G91=0.620190312
R92: B92=0.9 | C92=7000000.0 | D92=523809523.8 | E92=27000000 | F92=7532872.0 | G92=0.065926392
R93: B93=1.0 | C93=15000000.0 | D93=1000000000 | E93=35000000 | F93=6882281.0 | G93=0.041882281
R94: B94=1.1 | C94=25000000.0 | D94=1476190476 | E94=45000000 | F94=6205136.0 | G94=0.03468735019
R95: B95=1.2 | C95=40000000.0 | D95=1952380952 | E95=60000000 | F95=5738139.0 | G95=0.03367075412
R98: A98=Senior
R99: A99=Phân bổ | B99=KPI | C99=Mô tả đo lường | D99=Trọng số nhóm | E99=Trọng Số Chi Tiết | F99=Đơn Vị tính | G99=Mức Tham Chiếu | H99=Thực Tế | I99=Tỷ Lệ Hoàn Thành | J99=Tổng KPI
R100: A100=Nội bộ | B100=Chi phí/ 1 CPA đạt mục tiêu | C100=Mess, lead, conversion... đạt kế hoạch đề ra (giá/ 1 CPA) | D100=0.3 | E100=1.0 | F100=% | G100=1000000.0 | H100=1000000.0 | I100=1 | J100=0.811
R101: A101=Khách hàng | B101=Doanh thu thuần | C101=Chỉ tính KH phát sinh DT trong tháng | D101=0.7 | E101=0.3 | F101=triệu | G101=1000000000.0 | H101=100000000.0 | I101=0.1
R102: B102=Tỷ lệ plan được chốt | C102=SL KH chốt/ tổng số lượng KH | E102=0.2 | F102=% | G102=0.4 | H102=0.4 | I102=1
R103: B103=Tỷ lệ dự án đạt mục tiêu | C103=Dự án đạt được các chỉ số theo mục tiêu | E103=0.3 | F103=% | G103=0.8 | H103=0.8 | I103=1
R104: B104=Tỷ lệ renew dự án | C104=Tỷ lệ khách hàng tái sử dụng dịch vụ | E104=0.2 | F104=% | G104=0.65 | H104=0.65 | I104=1
R106: A106=Phân bổ | B106=KPI | C106=Mô tả đo lường | D106=Trọng số nhóm | E106=Trọng Số Chi Tiết | F106=Đơn Vị tính | G106=Mức Tham Chiếu | H106=Thực Tế | I106=Tỷ Lệ Hoàn Thành | J106=Tổng KPI
R107: A107=Nội bộ | B107=Chi phí/ 1 CPA đạt mục tiêu | C107=Mess, lead, conversion... đạt kế hoạch đề ra (giá/ 1 CPA) | D107=0.3 | E107=1.0 | F107=% | G107=1000000.0 | H107=1000000.0 | I107=1 | J107=#REF!
R108: A108=Khách hàng | B108=% dự án đạt hiệu quả | C108=Số lượng dự án đạt hiệu quả 80%/ tổng số dự án đang vận hành trong tháng | D108=0.7 | E108=1.0 | F108=% | G108=0.8 | H108=0.8 | I108=1


##### SHEET: Kế Toán #####
R1: A1=Hạng Mục Công Việc | C1=Nội dung | D1=Tần suất | E1=Yêu cầu
R2: A2=Mảng TKQC INVOICE (FB, GG, TikTok, Bing,...) | B2=Phối hợp nội bộ | C2=Đối soát ngân sách khả dụng còn lại trong ví của công ty tại các đầu đối tác đang hợp tác.  | D2=Đặt lịch hàng ngày | E2=chính xác
đúng công thức
check hàng ngày và nhập báo cáo
R3: C3=Cập nhật các giao dịch chuyển sang các đối tác trong ngày. Update lên file đối tác các giao dịch chuyển tiền. | E3=nhanh chóng và chính xác
cập nhật trong báo cáo
R4: C4=Check số dư ví ở các tài khoản của công ty.  | E4=chính xác
R5: C5=Update toàn bộ giao dịch phát sinh theo ngày vào file kế toán. Đối chiếu số liệu với các file lẻ từ bộ phận CSKH & Kinh Doanh. | E5=nhanh chóng và chính xác
R6: C6=Check file Refund hàng ngày để xử lý đúng hạn nếu không có phát sinh đặc biệt. | E6=nhanh chóng và chính xác
R7: C7=Check & yêu cầu thu phí QLTK với các NVKD. | E7=chính xác
R8: B8=Tương tác Khách hàng | C8=Rà soát, kiểm tra và xác nhận các khoản giao dịch phát sinh mới, refund... trong các nhóm Khách Hàng. Cập nhật trạng thái xác nhận lên các file lẻ chung
R9: A9=Mảng TKQC TK Nolimit | B9=Phối hợp nội bộ | C9=Update toàn bộ giao dịch phát sinh theo ngày vào file kế toán. Đối chiếu số liệu với các file lẻ từ bộ phận CSKH & Kinh Doanh. | D9=Đặt lịch hàng ngày
R10: C10=Check file Refund hàng ngày để xử lý đúng hạn nếu không có phát sinh đặc biệt.
R11: B11=Tương tác Khách hàng | C11=Rà soát, kiểm tra và xác nhận các khoản giao dịch phát sinh mới, refund... trong các nhóm Khách Hàng. Cập nhật trạng thái xác nhận lên các file lẻ chung.
R12: A12=Mảng Nguyên liệu ADS   | B12=Phối hợp nội bộ | C12=Kiểm tra và xác nhận giao dịch trên file đặt hàng chung | D12=Đặt lịch hàng ngày
R13: C13=Update toàn bộ giao dịch phát sinh theo ngày vào file kế toán. Đối chiếu số liệu với các file lẻ từ bộ phận CSKH & Kinh Doanh.
R14: C14=Check file Refund hàng ngày để xử lý đúng hạn nếu không có phát sinh đặc biệt.
R15: C15=Cập nhật giao dịch mua hàng nguyên liệu ADS từ các đầu đối tác, theo dõi công nợ và check thanh toán
R16: A16=Đối soát giao dịch | C16=Đối soát giao dịch theo ngày
Tổng hợp báo cáo và nhập file theo dõi
R17: A17=Nội bộ | B17=Tổng hợp doanh thu | C17=1. Thống kê doanh số các mảng
2. Thống kê và đối khoản rebate dự kiến và phân bổ vào các tháng (Cần làm thêm file thống kê tự động). | D17=Mùng 03 hàng tháng
R18: B18=Tổng hợp chi phí | C18=1. Tổng hợp và phân bổ các chi phí lớn dài hạn: chuyển tiền sang nước ngoài và văn phòng đại diện, chi phí du lịch, mua máy móc thiết bị...
2. Tổng hợp chi phí marketing (lấy số liệu từ MKT)
3. Tổng hợp chi phí nhập nguyên liệu: BM2500, BM350... (Ms.An tạo file tự động đổ chi phí NVL)
R19: C19=Check thống kê chi tiêu thực tế từ tất cả KH để trả hoa hồng cho CTV, đại lý hoặc cashback cho KH.
R20: B20=Báo cáo kinh doanh | C20=BÁO CÁO CHUNG: 
1. KẾT QUẢ KINH DOANH TỪNG MẢNG (Chi phí, doanh thu, lỗ lãi...)
2. KẾT QUẢ KINH DOANH TỔNG

R21: B21=Tổng Hợp Số Liệu Tính Lương | C21=Hàng tháng | D21=Mùng 05 hàng tháng
R22: B22=- Tập hợp hồ sơ chứng từ thuế (hoá đơn chứng từ đi kèm)
- Lập và nộp báo cáo thuế. | C22=Hàng quý | D22=Mùng 10 của tháng kế tiếp quý cần nộp báo cáo
R23: A23=KPI đánh giá | C23=Trọng Số | D23=Mô tả | F23=Đơn Vị tính | G23=Mức Tham Chiếu | H23=Thực Tế | I23=Tỷ Lệ Hoàn Thành | J23=% Quy Đổi Chung
R24: A24=Tỷ lệ chính xác trong việc đối soát các giao dịch | D24=< 1% sai sót | G24=0.01
R25: A25=Số lỗi sai sót trong báo cáo kinh doanh | D25=1 lần | G25=1 lần
R26: A26=Tỷ lệ đối soát và cập nhật giao dịch đúng hạn trong ngày | D26=số giao dịch được cập nhật/ số giao dịch phát sinh trong ngày | G26=1.0
R27: A27=Đối soát giao dịch | D27=Hoàn thành đối soát giao dịch trong ngày, trừ ngày nghỉ, T7, CN thì phải hoàn thành trong ngày làm việc tiếp theo | G27=1.0
R28: A28=Hoàn thành các đầu việc nội bộ được giao đúng hạn | D28=Thực hiện các công việc nội bộ theo yêu cầu từ quản lý | G28=1.0


##### SHEET: NV Thử việc #####
R1: A1=I. KPI NHÂN VIÊN KINH DOANH THỬ VIỆC
R3: A3=Chức Vụ | B3=Nhân sự / Mục Tiêu | C3=Trọng Số | D3=Đơn Vị  | E3=Mức Tham Chiếu | F3=Mô Tả | G3=Thực Tế | H3=Tỷ Lệ Hoàn Thành | I3=% Quy Đổi Chung | L3=Tiêu chí | M3=Điểm | N3=Hành vi quan sát | O3=Tổng điểm | P3=Đánh giá
R4: A4=Kỹ năng chuyên môn (100%) | B4=Doanh Thu Thuần | C4=0.7 | D4=VNĐ | E4=50000000.0 | F4=DTT toàn bộ dịch vụ | G4=50000000.0 | H4=1 | I4=1 | L4=Chủ động
Mức độ chủ động trong việc học sản phẩm, tiếp cận khách hàng và xử lý công việc. | M4=1.0 | N4=Bị động, chờ giao việc, ít hỏi | O4=16 – 20 | P4=Rất tiềm năng
R5: B5=Số Lượng Khách Hàng Mới | C5=0.3 | D5=Khách Hàng | E5=3.0 | F5=Số lượng KH mới | G5=3.0 | H5=1 | M5=2.0 | N5=Làm khi được giao nhưng ít chủ động tìm hiểu | O5=12 – 15 | P5=Có thể đào tạo
R6: M6=3.0 | N6=Có hỏi khi chưa rõ, đôi khi chủ động làm | O6=8 – 11 | P6=Cần cân nhắc
R7: A7=II. MỨC COM THEO RANK | M7=4.0 | N7=Chủ động tìm hiểu sản phẩm, chủ động nhắn khách | O7=Na | P7=Không phù hợp
R8: A8=THỬ VIỆC | B8=Doanh thu thuần giả định với các chỉ số khác đạt 100% | M8=5.0 | N8=Rất chủ động, tự tìm khách, đề xuất cách làm
R9: A9=Mức Level | B9=Khoảng Cách | C9=% Hoa hồng | D9=DOANH THU THUẦN 
TỐI THIỂU | E9=Lương Cứng  | F9=Hoa Hồng | G9=Tổng | L9=Tiếp thu & học nhanh
Khả năng tiếp nhận góp ý và cải thiện sau training. | M9=1.0 | N9=Góp ý nhiều lần vẫn lặp lỗi
R10: A10=Level 01 | B10=0.6 | C10=0.0 | D10=21428571.42857143 | E10=6000000.0 | F10=0 | G10=6000000 | M10=2.0 | N10=Có sửa nhưng tiến bộ chậm
R11: A11=Level 02 | B11=0.7 | C11=0.0 | D11=28571428.57142857 | E11=6000000.0 | F11=0 | G11=6000000 | M11=3.0 | N11=Có cải thiện sau khi được góp ý
R12: A12=Level 03 | B12=0.8 | C12=0.05 | D12=35714285.71428572 | E12=7000000.0 | F12=1785714.286 | G12=8785714.286 | M12=4.0 | N12=Tiếp thu nhanh, sau 1–2 lần góp ý sửa được
R13: A13=Level 04 | B13=0.9 | C13=0.08 | D13=42857142.857142866 | E13=7000000.0 | F13=3428571.429 | G13=10428571.43 | M13=5.0 | N13=Học rất nhanh, ghi chép và tổng hợp lại kiến thức
R14: A14=Level 05 | B14=1.0 | C14=0.1 | D14=50000000.0 | E14=8000000.0 | F14=5000000 | G14=13000000 | L14=Chăm chỉ & kỷ luật
Thái độ làm việc và sự kiên trì trong công việc sale. | M14=1.0 | N14=Hay trì hoãn, phải nhắc nhiều
R15: A15=Level 06 | B15=1.25 | C15=0.11 | D15=67857142.85714287 | E15=8500000.0 | F15=7464285.714 | G15=15964285.71 | M15=2.0 | N15=Làm việc thiếu ổn định
R16: A16=Level 07 | B16=1.5 | C16=0.12 | D16=85714285.71428572 | E16=9000000.0 | F16=10285714.29 | G16=19285714.29 | M16=3.0 | N16=Hoàn thành công việc cơ bản
R17: A17=Level 08 | B17=2.0 | C17=0.13 | D17=121428571.42857145 | E17=10000000.0 | F17=15785714.29 | G17=25785714.29 | M17=4.0 | N17=Chăm chỉ, chủ động nhắn và follow khách
R18: A18=Level 09 | B18=3.0 | C18=0.14 | D18=192857142.8571429 | E18=12000000.0 | F18=27000000 | G18=39000000 | M18=5.0 | N18=Rất chăm, kiên trì, làm việc ổn định
R19: A19=Level 10 | B19=4.0 | C19=0.15 | D19=264285714.28571433 | E19=12000000.0 | F19=39642857.14 | G19=51642857.14 | L19=Giao tiếp / Sale instinct
Tố chất giao tiếp và khả năng tương tác với khách hàng. | M19=1.0 | N19=Nói chuyện rời rạc, khó hiểu nhu cầu khách
R20: A20=Level 11 | B20=5.0 | C20=0.16 | D20=335714285.7142858 | E20=12000000.0 | F20=53714285.71 | G20=65714285.71 | M20=2.0 | N20=Giao tiếp còn gượng
R21: A21=Level 12 | B21=6.0 | C21=0.17 | D21=407142857.1428572 | E21=12000000.0 | F21=69214285.71 | G21=81214285.71 | M21=3.0 | N21=Nói chuyện được nhưng chưa dẫn dắt
R22: M22=4.0 | N22=Giao tiếp tự nhiên, hiểu nhu cầu khách
R23: A23=III. ĐÁNH GIÁ HÀNG THÁNG | C23=A = DTT | M23=5.0 | N23=Khai thác nhu cầu tốt, có tố chất sale
R24: A24=Hạng Mục | B24=Thời Gian | C24=ĐIỀU KIỆN | D24=TIÊU CHÍ ĐÁNH GIÁ | F24=PHƯƠNG ÁN | G24=LƯƠNG CỨNG THEO DTT | H24=Note
R25: A25=THÁNG 1 | B25=Trong vòng 02 tuần đầu tiên | C25=MT: 20tr | D25=03 data KH tiềm năng, có tạo nhóm | F25=ON | G25=Theo chính sách lương | H25=Mục tiêu: Đánh giá mức độ "vừa vặn" với văn hóa và khả năng học hỏi sản phẩm.

- Về Năng lực (40%):
Phải đạt mức 3 trở lên ở tiêu chí Tiếp thu & Học nhanh.

Hoàn thành bài test kiến thức sản phẩm (Invoice, Nolimit, Nguyên liệu...).

- Về Hiệu suất (60%):
1. KPI Activity: Tiếp cận ít nhất 200 khách hàng tiềm năng.
2. Funnel: Có ít nhất 03 data khách hàng tiềm năng và đã tạo nhóm (Zalo/Tele) trao đổi.
3. Doanh thu: Mục tiêu 5tr
R26: B26=Trong vòng 01 tháng | D26=A>=12tr | F26=ON | H26=Mục tiêu: Đánh giá khả năng chuyển đổi và tính kỷ luật.

- Về Năng lực (40%):
+ Trọng tâm vào Tính chủ động và Chăm chỉ/Kỷ luật.
+ Kỹ năng giao tiếp phải đạt mức 3 (Bắt đầu dẫn dắt được khách hàng).

- Về Hiệu suất (60%):
1. KPI Activity: Tổng tiếp cận lũy kế đạt  tối thiểu > 400 khách (đảm bảo effort).
2. Doanh thu (A): 
A ≥ 12tr: Trạng thái ON (Tiếp tục thử việc).
A < 12tr: Trạng thái OFF (Dừng thử việc) hoặc xem xét cực kỳ kỹ nếu điểm Năng lực đạt tối đa.
3. Chất lượng: Tỷ lệ phản hồi/chốt bắt đầu tiệm cận mức 5-10%.
R27: D27=A< 12tr | F27=OFF
R28: A28=THÁNG 2 | B28=Trong vòng 01 tháng | C28=MT: 30tr | D28=DTT trung bình 2 tháng >=25tr | F28=Pass thử việc | H28=Mục tiêu: Khẳng định năng lực tạo ra dòng tiền bền vững.

- Về Năng lực (40%):
+ Tổng điểm năng lực phải đạt từ 12 - 15 điểm (Mức "Có thể đào tạo" trở lên).
+ Tiêu chí Sale instinct phải đạt mức 4 (Hiểu nhu cầu khách).

- Về Hiệu suất (60%):
1. Doanh thu trung bình 2 tháng: Phải đạt ≥ 25tr/tháng.
2. Dựa trên bảng doanh thu trung bình/khách hàng của bạn:
+ Nếu sale mảng Nguyên liệu: Cần chốt ~2 khách/tháng.
+ Nếu sale mảng Nolimit/Invoice: Cần chốt ~8-15 khách/tháng.
3. Tỷ lệ chốt: Đạt ≥ 10% trên tổng số khách quan tâm.
R29: D29=DTT trung bình 2 tháng < 25tr | F29=OFF


##### SHEET: Sale TV #####
R2: A2=NV CHÍNH THỨC | B2=A = KPI
R3: A3=Hạng Mục | B3=ĐIỀU KIỆN | C3=TIÊU CHÍ ĐÁNH GIÁ | F3=LƯƠNG CỨNG THEO DTT | G3=RANK
R4: A4=Tháng 1 | B4=A<60% (DTT <12tr) | E4=OFF | F4=Theo quy định lương
R5: A5=Trung bình 2 tháng | B5=TB 2 tháng <25tr | E5=OFF
R7: A7=Chức Vụ | B7=Nhân sự / Mục Tiêu | C7=Trọng Số | D7=Đơn Vị  | E7=Mức Tham Chiếu | F7=Mô Tả | G7=Thực Tế | H7=Tỷ Lệ Hoàn Thành | I7=% Quy Đổi Chung
R8: A8=Kỹ năng chuyên môn (100%) | B8=Doanh Thu Thuần | C8=0.7 | D8=VNĐ | E8=20000000.0 | F8=DTT toàn bộ dịch vụ | G8=13000000.0 | H8=0.65 | I8=0.605
R9: B9=Số Lượng Khách Hàng Mới | C9=0.3 | D9=Khách Hàng | E9=2.0 | F9=Số lượng KH mới | G9=1.0 | H9=0.5
R10: E10=17000000
R11: A11=MỨC COM THEO RANK TƯƠNG LAI
R12: A12=THỬ VIỆC | B12=Doanh thu thuần giả định với các chỉ số khác đạt 100% | C12=Tính trong 6 tháng
Sau 6 tháng áp dụng chính sách tỷ lệ 50 50 | D12=% DTT từ tài khoản N | E12=% hoa hồng thực nhận | F12=CPCĐ | G12=5574104.741935484 | H12=5310000.0 | I12=17814059.44
R13: D13=<=60% | E13=1.0 | F13=CP vận hành (DTT 600tr) | G13=0.38901603083333336
R14: D14=>60% | E14=0.7
R15: A15=Mức Level | B15=Khoảng Cách | C15=% Hoa hồng | D15=DOANH THU THUẦN 
TỐI THIỂU | E15=Lương Cứng  | F15=% DTT từ TK N | G15=% hoa hồng thực tế | H15=Hoa hồng | I15=Tổng TN | J15=Tỷ trọng lương/ DTT | K15=Tỷ trọng chi phí/ DTT
R16: A16=Level 01 | B16=0.6 | C16=0.0 | D16=8571428.571 | E16=5310000.0 | F16=0.6 | G16=0 | H16=0 | I16=5310000 | J16=0.6195 | K16=1.26981222 | L16=0.6
R17: A17=Level 02 | B17=0.7 | C17=0.07 | D17=11428571.43 | E17=5310000.0 | F17=0.6 | G17=0.07 | H17=800000 | I17=6110000 | J17=0.534625 | K17=1.022359165 | L17=0.7
R18: A18=Level 03 | B18=0.8 | C18=0.08 | D18=14285714.29 | E18=5310000.0 | F18=0.6 | G18=0.08 | H18=1142857.143 | I18=6452857.143 | J18=0.4517 | K18=0.8418873319 | L18=0.8
R19: A19=Level 04 | B19=0.9 | C19=0.09 | D19=17142857.14 | E19=5310000.0 | F19=0.6 | G19=0.09 | H19=1542857.143 | I19=6852857.143 | J19=0.39975 | K19=0.7249061099 | L19=0.9
R20: A20=Level 05 | B20=1.0 | C20=0.1 | D20=20000000 | E20=#REF! | F20=0.6 | G20=0.1 | H20=2000000 | I20=#REF! | J20=#REF! | K20=#REF! | L20=1
R21: A21=Level 06 | B21=1.25 | C21=0.11 | D21=27142857.14 | E21=#REF! | F21=0.6 | G21=0.11 | H21=2985714.286 | I21=#REF! | J21=#REF! | K21=#REF! | L21=1.25
R22: A22=Level 07 | B22=1.5 | C22=0.12 | D22=34285714.29 | E22=#REF! | F22=0.6 | G22=0.12 | H22=4114285.714 | I22=#REF! | J22=#REF! | K22=#REF! | L22=1.5
R23: A23=Level 08 | B23=2.0 | C23=0.13 | D23=48571428.57 | E23=#REF! | F23=0.6 | G23=0.13 | H23=6314285.714 | I23=#REF! | J23=#REF! | K23=#REF! | L23=2
R24: A24=Level 09 | B24=3.0 | C24=0.14 | D24=77142857.14 | E24=#REF! | F24=0.6 | G24=0.14 | H24=10800000 | I24=#REF! | J24=#REF! | K24=#REF! | L24=3
R25: A25=Level 10 | B25=4.0 | C25=0.16 | D25=105714285.7 | E25=#REF! | F25=0.6 | G25=0.16 | H25=16914285.71 | I25=#REF! | J25=#REF! | K25=#REF! | L25=4
R26: A26=Level 11 | B26=5.0 | C26=0.18 | D26=134285714.3 | E26=#REF! | F26=0.6 | G26=0.18 | H26=24171428.57 | I26=#REF! | J26=#REF! | K26=#REF! | L26=5
R27: A27=Level 12 | B27=6.0 | C27=0.2 | D27=162857142.9 | E27=#REF! | F27=0.6 | G27=0.2 | H27=32571428.57 | I27=#REF! | J27=#REF! | K27=#REF! | L27=6


##### SHEET: Phân bổ doanh thu mục tiêu #####
R1: B1=0.6
R2: A2=Doanh thu mục tiêu | B2=DT Nolimit | C2=Doanh thu còn lại (gồm invoice, quảng cáo, nguyên liệu, khác...)
R3: A3=500000000.0 | B3=300000000 | C3=200000000
R4: B4=Tháng 1 | C4=Tháng 2 | D4=Tháng 3 | E4=Tháng 4 | F4=Tháng 5 | G4=Tháng 6 | H4=Tháng 7 | I4=Tháng 8 | J4=Tháng 9 | K4=Tháng 10 | L4=Tháng 11 | M4=Tháng 12
R5: A5=Tổng năm | B5=5950000000
R6: A6=Tổng quý | B6=850000000 | E6=1450000000 | H6=1800000000 | K6=1850000000
R7: A7=Hàng tháng | B7=300000000.0 | C7=250000000.0 | D7=300000000.0 | E7=400000000.0 | F7=500000000.0 | G7=550000000.0 | H7=600000000.0 | I7=600000000.0 | J7=600000000.0 | K7=650000000.0 | L7=600000000.0 | M7=600000000.0
R8: A8=Nolimit
R9: A9=Khác


##### SHEET: Intern #####
R1: A1=THÁNG ĐÀO TẠO: KHÔNG HỖ TRỢ LƯƠNG
R2: A2=NHÂN VIÊN HỌC VIỆC | B2=03 THÁNG HỌC VIỆC
R4: A4=Hạng Mục | B4=DTT THÁNG | C4=TIÊU CHÍ ĐÁNH GIÁ | F4=LƯƠNG CỨNG THEO DTT | G4=RANK
R5: A5=CASE 01 | B5=A < 5.000.000 | C5=Trung bình 3 tháng < 8tr | E5=Off | F5=P1+P2: 3.000.000 | G5=0% (P1+P2)
R6: A6=CASE 02 | B6=5.000.000 <= A < 8.000.000 | F6=P1+P2: 3.000.000 | G6=50% (P1+P2)
R7: A7=CASE 03 | B7=8.000.000 <= A < 10.000.000 | C7=8<=Trung bình 3 tháng <10 | E7=- Tiếp tục học việc tối đa 2 tháng
- Sau 2 tháng học việc tiếp theo, DTT trung bình >=10tr: ON | F7=P1+P2: 3.000.000 | G7=100% (P1+P2)
R8: A8=CASE 04 | B8=A >=10.000.000 | C8=Trung bình 3 tháng >= 10tr | E8=ON | F8=P1+P2: 3.000.000 | G8=100% (P1+P2)
R11: A11=Ví dụ về thu nhập của vị trí Học việc | D11=10000000.0
R12: A12=Mức Level | B12=Khoảng Cách | C12=% hoa hồng | D12=DOANH THU THUẦN  | E12=Mức hỗ trợ | F12=Hoa Hồng | G12=Tổng
R13: A13=Level 01 | B13=(%KPI) <= 50% | C13=0.0 | D13=4900000 | E13=0.0 | F13=0 | G13=0 | H13=0 | I13=0.49
R14: A14=Level 02 | B14=50% < (%KPI) < 70% | C14=0.0 | D14=5000000 | E14=1500000.0 | F14=0 | G14=1500000 | H14=0.3 | I14=0.5
R15: A15=Level 03 | B15=70% <= (%KPI) <85% | C15=0.05 | D15=7000000 | E15=1500000.0 | F15=350000 | G15=1850000 | H15=0.2642857143 | I15=0.7
R16: A16=Level 04 | B16=85% <= (%KPI) < 100% | C16=0.08 | D16=8500000 | E16=3000000.0 | F16=680000 | G16=3680000 | H16=0.4329411765 | I16=0.85
R17: A17=Level 05 | B17=100% <= (%KPI) <125% | C17=0.1 | D17=10000000 | E17=3000000.0 | F17=1000000 | G17=4000000 | H17=0.4 | I17=1.0
R18: A18=Level 06 | B18=125% <= (%KPI) <150% | C18=0.11 | D18=12500000 | E18=3000000.0 | F18=1375000 | G18=4375000 | H18=0.35 | I18=1.25
R19: A19=Level 07 | B19=150% <= (%KPI) <200% | C19=0.12 | D19=15000000 | E19=3000000.0 | F19=1800000 | G19=4800000 | H19=0.32 | I19=1.5
R20: A20=Level 08 | B20=200% <= (%KPI) <400% | C20=0.13 | D20=20000000 | E20=3000000.0 | F20=2600000 | G20=5600000 | H20=0.28 | I20=2.0
R21: A21=Level 09 | B21=400% <= (%KPI) <600% | C21=0.14 | D21=40000000 | E21=3000000.0 | F21=5600000 | G21=8600000 | H21=0.215 | I21=4.0
R22: A22=Level 10 | B22=600% <= (%KPI) <800% | C22=0.16 | D22=60000000 | E22=3000000.0 | F22=9600000 | G22=12600000 | H22=0.21 | I22=6.0
R23: A23=Level 11 | B23=800% <= (%KPI) <1000% | C23=0.18 | D23=80000000 | E23=3000000.0 | F23=14400000 | G23=17400000 | H23=0.2175 | I23=8.0
R24: A24=Level 12 | B24=1000% <= KPI | C24=0.2 | D24=100000000 | E24=3000000.0 | F24=20000000 | G24=23000000 | H24=0.23 | I24=10.0


##### SHEET: Mục tiêu KD #####
R1: B1=KPI TPKD | C1=Quý 2 | O1=Chính sách thu nhập TP
R2: B2=Nhân sự / Mục Tiêu | C2=Trọng Số | D2=Đơn Vị  | E2=Mức Tham Chiếu | G2=Mô Tả | H2=Thực Tế | I2=Tỷ Lệ Hoàn Thành | J2=% Quy Đổi Chung | L2=Doanh thu mục tiêu | N2=A | O2=B + C < A | Q2=- Không có com team
- Không có com cá nhân
R3: B3=Doanh Thu Thuần  | C3=0.8 | D3=Vnđ | E3=600000000.0 | G3=DTT cơ bản/cá nhân + DTT kỳ vọng/cá nhân | H3=412500000.0 | I3=0.6875 | J3=0.75 | L3=Doanh thu nhân viên | N3=B | O3=B + C >= A | Q3=B >= A | T3=B < A
R4: B4=Tỷ lệ nhân sự đạt DTT tiêu chuẩn theo từng vị trí | C4=0.2 | D4=Thành viên | E4=70% | G4= Chia theo cấp độ: NV chính thức
Full chỉ tiêu là 100%, tính theo tỷ lệ hoàn thành | H4=0.7 | I4=1 | L4=Doanh thu cá nhân TP | N4=C | Q4=- Com team 3% phần doanh thu chênh lệch của nhóm (không gồm TP) so với DTT mục tiêu của nhóm
- Com cá nhân theo chính sách đang áp dụng | T4=- Không có com team
- Com cá nhân theo phần còn lại sau khi đã bù DT cho team để đạt DT mục tiêu nhóm
R5: Q5=Com team:
= 3%* (B - A) | T5=Com team: không có
R6: B6=Định phí trung bình tháng | C6=Biến phí trung bình tháng | Q6=Com cá nhân:
tính theo C | T6=Com cá nhân:
tính theo E 
E = C - (A - B)
R7: B7=73733585.0 | C7=3195602.0 | D7=25.0
R9: B9=Cố định doanh thu 1 sale
R10: B10=CƠ CẤU DOANH THU | O10=HOA HỒNG CÁ NHÂN | AD10=Chi phí 1 người | AE10=0.043
R11: A11=Tăng trưởng | B11=DTT toàn team (gồm cả TP) | C11=DT từ TKQC | D11=DT từ DVQC | E11=Số lượng sale | F11=Số lượng vận hành DVQC | G11=Số lượng vận hành | H11=Doanh thu cá nhân TP | I11=DTT  cá nhân thực của TP | J11=Doanh thu 1 sale | K11=Doanh thu nhân viên | L11=DTT TEAM (ko tính TP) | M11=% hoa hồng team | N11=Hoa hồng TP từ team | O11=% KPI cá nhân TP | P11=% hoa hồng TP | Q11=hoa hồng cá nhân của TP | R11=% KPI cá nhân sale | S11=% hoa hồng sale | T11=hoa hồng cá nhân sale | U11=Tổng hoa hồng TEAM | V11=Lương cứng TP | W11=Lương cứng 1 sale | X11=Tổng lương cứng toàn PKD | Y11=Tổng thu nhập trả cho PKD | Z11=Tỷ trọng TN team/ DTT team | AA11=Tổng thu nhập TP | AB11=Tỷ trọng TN TP/ DTT team | AC11=Tổng chi phí cả team / DTT | AE11=Chi phí bán hàng | AF11=Chi phí THỰC TẾ cho team | AG11=Lương vận hành | AH11=Chi phí toàn công ty | AI11=Tỷ trọng chi phí | AJ11=Lỗ/ lãi | AK11=% KPI TP
R12: B12=400000000 | C12=300000000.0 | D12=100000000.0 | E12=8 | F12=5.0 | G12=13.0 | H12=0.0 | I12=0 | J12=50000000 | K12=400000000 | L12=400000000 | M12=0 | N12=0 | O12=0.3 | P12=0 | Q12=0 | R12=1 | S12=0.1 | T12=5000000 | U12=40000000 | V12=10000000 | W12=8000000 | X12=74000000 | Y12=114000000 | Z12=0.285 | AA12=10000000 | AB12=0.025 | AC12=0.4323103933 | AD12=6547128.591 | AE12=17200000 | AF12=0.4753103933 | AG12=159500000.0 | AH12=434736829 | AI12=1.086842073 | AJ12=-34736829 | AK12=0.7333333333
R13: A13=0.75 | B13=700000000 | C13=450000000.0 | D13=250000000.0 | E13=14 | F13=6.0 | G13=14.0 | H13=0.0 | I13=0 | J13=50000000 | K13=700000000 | L13=700000000 | M13=0.03 | N13=3000000 | O13=0.3 | P13=0 | Q13=0 | R13=1 | S13=0.1 | T13=5000000 | U13=73000000 | V13=18000000 | W13=8000000 | X13=130000000 | Y13=203000000 | Z13=0.29 | AA13=21000000 | AB13=0.03 | AC13=0.4129601303 | AD13=5738139.414 | AE13=30100000 | AF13=0.4559601303 | AG13=173000000.0 | AH13=572506043 | AI13=0.8178657757 | AJ13=127493957 | AK13=1.133333333
R14: A14=0.4285714286 | B14=1000000000 | C14=500000000.0 | D14=500000000.0 | E14=20 | F14=11.0 | G14=19.0 | H14=0.0 | I14=0 | J14=50000000 | K14=1000000000 | L14=1000000000 | M14=0.035 | N14=14000000 | O14=0.3 | P14=0 | Q14=0 | R14=1 | S14=0.1 | T14=5000000 | U14=114000000 | V14=18000000 | W14=8000000 | X14=178000000 | Y14=292000000 | Z14=0.292 | AA14=32000000 | AB14=0.032 | AC14=0.3978177741 | AD14=5038941.625 | AE14=43000000 | AF14=0.4408177741 | AG14=234000000.0 | AH14=770557665 | AI14=0.770557665 | AJ14=229442335 | AK14=1.533333333
R15: A15=0.2 | B15=1200000000 | C15=600000000.0 | D15=600000000.0 | E15=24 | F15=12.0 | G15=20.0 | H15=0.0 | I15=0 | J15=50000000 | K15=1200000000 | L15=1200000000 | M15=0.04 | N15=24000000 | O15=0.3 | P15=0 | Q15=0 | R15=1 | S15=0.1 | T15=5000000 | U15=144000000 | V15=18000000 | W15=8000000 | X15=210000000 | Y15=354000000 | Z15=0.295 | AA15=42000000 | AB15=0.035 | AC15=0.3957109606 | AD15=4834126.111 | AE15=51600000 | AF15=0.4387109606 | AG15=265000000.0 | AH15=888135675 | AI15=0.7401130625 | AJ15=311864325 | AK15=1.8
R16: Z16=0.2923333333
R17: B17=Mức Level | C17=Khoảng Cách KPI | D17=Mức lương | E17=Mức doanh thu thực cả team | F17=Lương cứng | H17=Thu nhập TP | I17=Tổng CP/ DTT
R18: B18=Level 01 | C18=0.6 | D18=10000000 | E18=300000000 | F18=10000000.0 | G18=0.0 | H18=10000000.0 | I18=1.3068187500000004
R19: B19=Level 02 | C19=0.7 | D19=10000000 | E19=375000000 | F19=10000000.0 | G19=0.0 | H19=10000000.0 | I19=1.114837408
R20: B20=Level 03 | C20=0.8 | D20=10000000 | E20=450000000 | F20=10000000.0 | G20=0.0 | H20=10000000.0 | I20=0.9868498466666666
R21: B21=Level 04 | C21=0.9 | D21=14000000 | E21=525000000 | F21=14000000.0 | G21=0.0 | H21=14000000.0 | I21=0.8926541203738317
R22: B22=Level 05 | C22=1.0 | D22=18000000 | E22=600000000 | F22=18000000.0 | G22=0.03 | H22=18000000.0 | I22=0.8401987283333333
R23: B23=Level 06 | C23=1.2 | D23=18000000 | E23=750000000 | F23=18000000.0 | G23=0.0325 | H23=22875000.0 | I23=0.790562996
R24: B24=Level 07 | C24=1.4 | D24=18000000 | E24=900000000 | F24=18000000.0 | G24=0.035 | H24=28500000.0 | I24=0.75219473
R25: B25=Level 08 | C25=1.6 | D25=18000000 | E25=1050000000 | F25=18000000.0 | G25=0.0375 | H25=34875000.0 | I25=0.73407454
R26: B26=Level 09 | C26=1.8 | D26=18000000 | E26=1200000000 | F26=18000000.0 | G26=0.04 | H26=42000000.0 | I26=0.7327760641666666
R27: B27=Level 10 | C27=2.0 | D27=18000000 | E27=1350000000 | F27=18000000.0 | G27=0.0425 | H27=49875000.0 | I27=0.714399025925926
R28: B28=Level 11 | C28=2.5 | D28=18000000 | E28=1725000000 | F28=18000000.0 | G28=0.045 | H28=68624999.99999999 | I28=0.6941891605797101
R29: B29=Level 12 | C29=3.0 | D29=18000000 | E29=2100000000 | F29=18000000.0 | G29=0.05 | H29=92999999.99999999 | I29=0.6786375804761906


##### SHEET: TPKD-1 #####
R1: B1=KPI TPKD | C1=Quý 2 | O1=Chính sách thu nhập TP
R2: B2=Nhân sự / Mục Tiêu | C2=Trọng Số | D2=Đơn Vị  | E2=Mức Tham Chiếu | G2=Mô Tả | H2=Thực Tế | I2=Tỷ Lệ Hoàn Thành | J2=% Quy Đổi Chung | L2=Doanh thu mục tiêu | N2=A | O2=B + C < A | Q2=- Không có com team
- Không có com cá nhân
R3: B3=Doanh Thu Thuần  | C3=0.8 | D3=Vnđ | E3=500000000.0 | G3=DTT cơ bản/cá nhân + DTT kỳ vọng/cá nhân | H3=412500000.0 | I3=0.825 | J3=0.86 | L3=Doanh thu nhân viên | N3=B | O3=B + C >= A | Q3=B >= A | T3=B < A
R4: B4=Tỷ lệ nhân sự đạt DTT tiêu chuẩn theo từng vị trí | C4=0.2 | D4=Thành viên | E4=70% | G4= Chia theo cấp độ: NV chính thức
Full chỉ tiêu là 100%, tính theo tỷ lệ hoàn thành | H4=0.7 | I4=1 | L4=Doanh thu cá nhân TP | N4=C | Q4=- Com team 3% phần doanh thu chênh lệch của nhóm (không gồm TP) so với DTT mục tiêu của nhóm
- Com cá nhân theo chính sách đang áp dụng | T4=- Không có com team
- Com cá nhân theo phần còn lại sau khi đã bù DT cho team để đạt DT mục tiêu nhóm
R5: Q5=Com team:
= 3%* (B - A) | T5=Com team: không có
R6: B6=Định phí trung bình tháng | C6=Biến phí trung bình tháng | Q6=Com cá nhân:
tính theo C | T6=Com cá nhân:
tính theo E 
E = C - (A - B)
R7: B7=73733585.0 | C7=3195602.0 | D7=25.0
R9: B9=Cố định doanh thu 1 sale
R10: B10=CƠ CẤU DOANH THU | C10=0.6 | D10=0.4 | G10=6.0 | O10=HOA HỒNG CÁ NHÂN | AD10=Chi phí 1 người | AE10=0.043
R11: A11=Tăng trưởng | B11=DTT toàn team (gồm cả TP) | C11=DT từ TKQC | D11=DT từ DVQC | E11=Số lượng sale | F11=Số lượng vận hành DVQC | G11=Số lượng vận hành | H11=Doanh thu cá nhân TP | I11=DTT  cá nhân thực của TP | J11=Doanh thu 1 sale | K11=Doanh thu nhân viên | L11=DTT TEAM (ko tính TP) | M11=% hoa hồng team | N11=Hoa hồng TP từ team | O11=% KPI cá nhân TP | P11=% hoa hồng TP | Q11=hoa hồng cá nhân của TP | R11=% KPI cá nhân sale | S11=% hoa hồng sale | T11=hoa hồng cá nhân sale | U11=Tổng hoa hồng TEAM | V11=Lương cứng TP | W11=Lương cứng 1 sale | X11=Tổng lương cứng 1 team KD | Y11=Tổng thu nhập trả cho 1 team KD | Z11=Tỷ trọng TN team/ DTT 1 team | AA11=Tổng thu nhập TP | AB11=Tỷ trọng TN TP/ DTT team | AC11=Tổng chi phí cả team / DTT | AE11=Chi phí bán hàng | AF11=Chi phí THỰC TẾ cho team | AG11=Lương vận hành | AH11=Chi phí toàn công ty | AI11=Tỷ trọng chi phí | AJ11=Lỗ/ lãi | AK11=% KPI TP | AL11=CP vận hành/ DTT
R12: B12=249999999.99999997 | C12=150000000 | D12=100000000 | E12=5 | F12=5.0 | G12=11 | H12=0.0 | I12=0 | J12=50000000.0 | K12=250000000 | L12=250000000 | M12=0 | N12=0 | O12=0 | P12=0 | Q12=0 | R12=1 | S12=0.1 | T12=5000000 | U12=25000000 | V12=10000000 | W12=8000000 | X12=50000000 | Y12=75000000 | Z12=0.3 | AA12=10000000 | AB12=0.04 | AC12=0.4807889209 | AD12=7532871.706 | AE12=10750000 | AF12=0.5237889209 | AG12=148500000.0 | AH12=369841690.7 | AI12=1.479366763 | AJ12=-119841690.7 | AK12=0.6 | AL12=0.9555778419
R13: B13=312499999.99999994 | C13=187500000 | D13=125000000 | E13=6.25 | F13=5.0 | G13=11 | H13=0.0 | I13=0 | J13=50000000 | K13=312500000 | L13=312500000 | M13=0 | N13=0 | O13=0 | P13=0 | Q13=0 | R13=1 | S13=0.1 | T13=5000000 | U13=31250000 | V13=10000000 | W13=8000000 | X13=60000000 | Y13=91250000 | Z13=0.292 | AA13=10000000 | AB13=0.032 | AC13=0.4598705238 | AD13=7235798.438 | AE13=13437500 | AF13=0.5028705238 | AG13=148500000.0 | AH13=392476619.9 | AI13=1.255925184 | AJ13=-79976619.94 | AK13=0.7 | AL13=0.75305466
R14: B14=375000000.00000006 | C14=225000000 | D14=150000000 | E14=7.5 | F14=5.0 | G14=11 | H14=0.0 | I14=0 | J14=50000000 | K14=375000000 | L14=375000000 | M14=0 | N14=0 | O14=0 | P14=0 | Q14=0 | R14=1 | S14=0.1 | T14=5000000 | U14=37500000 | V14=10000000 | W14=8000000 | X14=70000000 | Y14=107500000 | Z14=0.2866666667 | AA14=10000000 | AB14=0.02666666667 | AC14=0.444807727 | AD14=6976811.487 | AE14=16125000 | AF14=0.487807727 | AG14=148500000.0 | AH14=415149635.5 | AI14=1.107065695 | AJ14=-40149635.49 | AK14=0.8 | AL14=0.6192579676
R15: B15=437499999.99999994 | C15=262500000 | D15=175000000 | E15=8.75 | F15=5.0 | G15=11 | H15=0.0 | I15=0 | J15=50000000 | K15=437500000 | L15=437500000 | M15=0 | N15=0 | O15=0 | P15=0 | Q15=0 | R15=1 | S15=0.1 | T15=5000000 | U15=43750000 | V15=12000000 | W15=8000000 | X15=82000000 | Y15=125750000 | Z15=0.2874285714 | AA15=12000000 | AB15=0.02742857143 | AC15=0.4378354763 | AD15=6749027.783 | AE15=18812500 | AF15=0.4808354763 | AG15=148500000.0 | AH15=439853854.3 | AI15=1.005380238 | AJ15=-2353854.283 | AK15=0.9 | AL15=0.5245447621
R16: B16=500000000.0 | C16=300000000 | D16=200000000 | E16=12.0 | F16=6.0 | G16=12 | H16=0.0 | I16=0 | J16=50000000 | K16=500000000 | L16=500000000 | M16=0.03 | N16=0 | O16=0 | P16=0 | Q16=0 | R16=1 | S16=0.1 | T16=5000000 | U16=60000000 | V16=15000000 | W16=8000000 | X16=111000000 | Y16=171000000 | Z16=0.342 | AA16=15000000 | AB16=0.03 | AC16=0.5017685804 | AD16=6144945.4 | AE16=21500000 | AF16=0.5447685804 | AG16=148500000.0 | AH16=500768580.4 | AI16=1.001537161 | AJ16=-768580.4 | AK16=1 | AL16=0.4567685804
R17: B17=625000000.0 | C17=375000000 | D17=250000000 | E17=12.5 | F17=6.0 | G17=12 | H17=0.0 | I17=0 | J17=50000000 | K17=625000000 | L17=625000000 | M17=0.0325 | N17=4062500 | O17=0 | P17=0 | Q17=0 | R17=1 | S17=0.1 | T17=5000000 | U17=66562500 | V17=18000000 | W17=8000000 | X17=118000000 | Y17=184562500 | Z17=0.2953 | AA17=22062500 | AB17=0.0353 | AC17=0.426781687 | AD17=6087115.137 | AE17=26875000 | AF17=0.469781687 | AG17=148500000.0 | AH17=521246051.1 | AI17=0.8339936818 | AJ17=103753948.9 | AK17=1.2 | AL17=0.3642119949
R18: B18=749999999.9999999 | C18=450000000 | D18=300000000 | E18=15 | F18=6.0 | G18=12 | H18=0.0 | I18=0 | J18=50000000 | K18=750000000 | L18=750000000 | M18=0.035 | N18=8750000 | O18=0 | P18=0 | Q18=0 | R18=1 | S18=0.1 | T18=5000000 | U18=83750000 | V18=18000000 | W18=8000000 | X18=138000000 | Y18=221750000 | Z18=0.2956666667 | AA18=26750000 | AB18=0.03566666667 | AC18=0.4200174789 | AD18=5828944.321 | AE18=32250000 | AF18=0.4630174789 | AG18=148500000.0 | AH18=571539385.3 | AI18=0.7620525138 | AJ18=178460614.7 | AK18=1.4 | AL18=0.2990350349
R19: B19=875000000.0 | C19=525000000 | D19=350000000 | E19=17.5 | F19=7.0 | G19=13 | H19=0.0 | I19=0 | J19=50000000 | K19=875000000 | L19=875000000 | M19=0.0375 | N19=14062500 | O19=0 | P19=0 | Q19=0 | R19=1 | S19=0.1 | T19=5000000 | U19=101562500 | V19=18000000 | W19=8000000 | X19=158000000 | Y19=259562500 | Z19=0.2966428571 | AA19=32062500 | AB19=0.03664285714 | AC19=0.4136971297 | AD19=5536350.73 | AE19=37625000 | AF19=0.4566971297 | AG19=148500000.0 | AH19=625618898.7 | AI19=0.7149930271 | AJ19=249381101.3 | AK19=1.6 | AL19=0.2582958974
R20: B20=1000000000.0 | C20=600000000 | D20=400000000 | E20=20 | F20=7.0 | G20=13 | H20=0.0 | I20=0 | J20=50000000 | K20=1000000000 | L20=1000000000 | M20=0.04 | N20=20000000 | O20=0 | P20=0 | Q20=0 | R20=1 | S20=0.1 | T20=5000000 | U20=120000000 | V20=18000000 | W20=8000000 | X20=178000000 | Y20=298000000 | Z20=0.298 | AA20=38000000 | AB20=0.038 | AC20=0.4106489739 | AD20=5364236.853 | AE20=43000000 | AF20=0.4536489739 | AG20=148500000.0 | AH20=677248289.9 | AI20=0.6772482899 | AJ20=322751710.1 | AK20=1.8 | AL20=0.2235993159
R21: B21=1125000000.0 | C21=675000000 | D21=450000000 | E21=22.5 | F21=8.0 | G21=14 | H21=0.0 | I21=0 | J21=50000000 | K21=1125000000 | L21=1125000000 | M21=0.0425 | N21=26562500 | O21=0 | P21=0 | Q21=0 | R21=1 | S21=0.1 | T21=5000000 | U21=139062500 | V21=18000000 | W21=8000000 | X21=198000000 | Y21=337062500 | Z21=0.2996111111 | AA21=44562500 | AB21=0.03961111111 | AC21=0.4074360239 | AD21=5161830.933 | AE21=48375000 | AF21=0.4504360239 | AG21=148500000.0 | AH21=732667990.9 | AI21=0.6512604364 | AJ21=392332009.1 | AK21=2 | AL21=0.2008244124
R22: B22=1437499999.9999998 | C22=862500000 | D22=575000000 | E22=28.75 | F22=8.0 | G22=15 | H22=0.0 | I22=0 | J22=50000000 | K22=1437500000 | L22=1437500000 | M22=0.045 | N22=42187500 | O22=0 | P22=0 | Q22=0 | R22=1 | S22=0.1 | T22=5000000 | U22=185937500 | V22=18000000 | W22=8000000 | X22=248000000 | Y22=433937500 | Z22=0.3018695652 | AA22=60187500 | AB22=0.04186956522 | AC22=0.4021044009 | AD22=4843279.877 | AE22=61812500 | AF22=0.4451044009 | AG22=148500000.0 | AH22=865830054.4 | AI22=0.6023165596 | AJ22=571669945.6 | AK22=2.5 | AL22=0.1572121586
R23: B23=1749999999.9999998 | C23=1050000000 | D23=700000000 | E23=35 | F23=9.0 | G23=16 | H23=0.0 | I23=0 | J23=50000000 | K23=1750000000 | L23=1750000000 | M23=0.05 | N23=62500000 | O23=0 | P23=0 | Q23=0 | R23=1 | S23=0.1 | T23=5000000 | U23=237500000 | V23=18000000 | W23=8000000 | X23=298000000 | Y23=535500000 | Z23=0.306 | AA23=80500000 | AB23=0.046 | AC23=0.4009074286 | AD23=4613555.558 | AE23=75250000 | AF23=0.4439074286 | AG23=148500000.0 | AH23=1003768445 | AI23=0.5735819683 | AJ23=746231555.4 | AK23=3 | AL23=0.1296745397
R24: Z24=0.304386275
R25: B25=Mức Level | C25=Khoảng Cách | D25=Mức lương | E25=Mức doanh thu thực cả team | F25=Lương cứng | G25=% com | H25=Thu nhập TP | I25=Tổng CP/ DTT | J25=KPI 55tr
R26: B26=Level 01 | C26=0.6 | D26=10000000.0 | E26=250000000 | F26=10000000 | G26=0.0 | H26=10000000.0 | I26=1.3068187500000004 | J26=1.2732812918181822
R27: B27=Level 02 | C27=0.7 | D27=10000000.0 | E27=312500000 | F27=10000000.0 | G27=0.0 | H27=10000000.0 | I27=1.114837408 | J27=1.0842999498181818
R28: B28=Level 03 | C28=0.8 | D28=10000000.0 | E28=375000000 | F28=10000000.0 | G28=0.0 | H28=10000000.0 | I28=0.9868498466666665 | J28=0.9583123884848483
R29: B29=Level 04 | C29=0.9 | D29=12000000.0 | E29=437500000 | F29=12000000.0 | G29=0.0 | H29=14000000.0 | I29=0.9030492076190477 | J29=0.8759403208658009
R30: B30=Level 05 | C30=1.0 | D30=15000000.0 | E30=500000000 | F30=15000000.0 | G30=0.03 | H30=18000000.0 | I30=0.8401987283333333 | J30=0.8141612701515151
R31: B31=Level 06 | C31=1.2 | D31=18000000.0 | E31=625000000 | F31=18000000.0 | G31=0.0325 | H31=22875000.0 | I31=0.7683021933333334 | J31=0.7437647351515152
R32: B32=Level 07 | C32=1.4 | D32=18000000.0 | E32=750000000 | F32=18000000.0 | G32=0.035 | H32=28500000.0 | I32=0.7212045033333334 | J32=0.6976670451515151
R33: B33=Level 08 | C33=1.6 | D33=18000000.0 | E33=875000000 | F33=18000000.0 | G33=0.0375 | H33=34875000.0 | I33=0.7027495838095238 | J33=0.6799264113419913
R34: B34=Level 09 | C34=1.8 | D34=18000000.0 | E34=1000000000 | F34=18000000.0 | G34=0.04 | H34=42000000.0 | I34=0.6895333941666667 | J34=0.6672459359848485
R35: B35=Level 10 | C35=2.0 | D35=18000000.0 | E35=1125000000 | F35=18000000.0 | G35=0.0425 | H35=49875000.0 | I35=0.6685536896296296 | J35=0.6466828981144781
R36: B36=Level 11 | C36=2.5 | D36=18000000.0 | E36=1437500000 | F36=18000000.0 | G36=0.045 | H36=68624999.99999999 | I36=0.6183102017391304 | J36=0.5971640479051384
R37: B37=Level 12 | C37=3.0 | D37=18000000.0 | E37=1750000000 | F37=18000000.0 | G37=0.05 | H37=92999999.99999999 | I37=0.5886893880952381 | J37=0.5680090727705628


##### SHEET: TPKD - chốt #####
R1: B1=KPI TPKD | C1=Quý 2 | O1=Chính sách thu nhập TP
R2: B2=Nhân sự / Mục Tiêu | C2=Trọng Số | D2=Đơn Vị  | E2=Mức Tham Chiếu | G2=Mô Tả | H2=Thực Tế | I2=Tỷ Lệ Hoàn Thành | J2=% Quy Đổi Chung | L2=Doanh thu mục tiêu | N2=A | O2=B + C < A | Q2=- Không có com team
- Không có com cá nhân
R3: B3=Doanh Thu Thuần  | C3=0.8 | D3=Vnđ | E3=500000000.0 | G3=DTT cơ bản/cá nhân + DTT kỳ vọng/cá nhân | H3=412500000.0 | I3=0.825 | J3=0.86 | L3=Doanh thu nhân viên | N3=B | O3=B + C >= A | Q3=B >= A | T3=B < A
R4: B4=Tỷ lệ nhân sự đạt DTT tiêu chuẩn theo từng vị trí | C4=0.2 | D4=Thành viên | E4=70% | G4= Chia theo cấp độ: NV chính thức
Full chỉ tiêu là 100%, tính theo tỷ lệ hoàn thành | H4=0.7 | I4=1 | L4=Doanh thu cá nhân TP | N4=C | Q4=- Com team 3% phần doanh thu chênh lệch của nhóm (không gồm TP) so với DTT mục tiêu của nhóm
- Com cá nhân theo chính sách đang áp dụng | T4=- Không có com team
- Com cá nhân theo phần còn lại sau khi đã bù DT cho team để đạt DT mục tiêu nhóm
R5: Q5=Com team:
= 3%* (B - A) | T5=Com team: không có
R6: B6=Định phí trung bình tháng | C6=Biến phí trung bình tháng | D6=Số nhân sự | Q6=Com cá nhân:
tính theo C | T6=Com cá nhân:
tính theo E 
E = C - (A - B)
R7: B7=73733585.0 | C7=3195602.0 | D7=25.0
R9: B9=Cố định doanh thu 1 sale
R10: B10=CƠ CẤU DOANH THU | G10=6.0 | O10=HOA HỒNG CÁ NHÂN | AD10=Chi phí 1 người | AE10=0.043
R11: A11=Tăng trưởng | B11=DTT toàn team (gồm cả TP) | C11=DT từ TKQC | D11=DT từ DVQC | E11=Số lượng sale | F11=Số lượng vận hành DVQC | G11=Số lượng vận hành và hỗ trợ | H11=Doanh thu cá nhân TP | I11=DTT  cá nhân thực của TP | J11=Doanh thu 1 sale | K11=Doanh thu nhân viên | L11=DTT TEAM (ko tính TP) | M11=% hoa hồng team | N11=Hoa hồng TP từ team | O11=% KPI cá nhân TP | P11=% hoa hồng TP | Q11=hoa hồng cá nhân của TP | R11=% KPI cá nhân sale | S11=% hoa hồng sale | T11=hoa hồng cá nhân sale | U11=Tổng hoa hồng TEAM | V11=Lương cứng TP | W11=Lương cứng 1 sale | X11=Tổng lương cứng 1 team KD | Y11=Tổng thu nhập trả cho 1 team KD | Z11=Tỷ trọng TN team/ DTT 1 team | AA11=Tổng thu nhập TP | AB11=Tỷ trọng TN TP/ DTT team | AC11=Tổng chi phí cả team / DTT | AE11=Chi phí bán hàng | AF11=Chi phí THỰC TẾ cho team | AG11=Lương vận hành | AH11=Chi phí toàn công ty | AI11=Tỷ trọng chi phí | AJ11=Lỗ/ lãi | AK11=% KPI TP | AL11=CP vận hành/ DTT
R12: B12=249999999.99999997 | C12=150000000 | D12=100000000 | E12=5 | F12=6.0 | G12=12 | H12=0.0 | I12=0 | J12=50000000.0 | K12=250000000 | L12=250000000 | M12=0 | N12=0 | O12=0.3 | P12=0 | Q12=0 | R12=1 | S12=0.1 | T12=5000000 | U12=25000000 | V12=10000000 | W12=8000000 | X12=50000000 | Y12=75000000 | Z12=0.3 | AA12=10000000 | AB12=0.04 | AC12=0.4750058947 | AD12=7291912.278 | AE12=10750000 | AF12=0.5180058947 | AG12=#REF! | AH12=#REF! | AI12=#REF! | AJ12=#REF! | AK12=0.6 | AL12=#REF!
R13: B13=312500000.0 | C13=162500000 | D13=150000000.0 | E13=6.25 | F13=6.0 | G13=12 | H13=0.0 | I13=0 | J13=50000000 | K13=312500000 | L13=312500000 | M13=0 | N13=0 | O13=0.3 | P13=0 | Q13=0 | R13=1 | S13=0.1 | T13=5000000 | U13=31250000 | V13=12000000 | W13=8000000 | X13=62000000 | Y13=93250000 | Z13=0.2984 | AA13=12000000 | AB13=0.0384 | AC13=0.4614013 | AD13=7025918.104 | AE13=13437500 | AF13=0.5044013 | AG13=#REF! | AH13=#REF! | AI13=#REF! | AJ13=#REF! | AK13=0.7 | AL13=#REF!
R14: B14=375000000.0 | C14=175000000 | D14=200000000.0 | E14=7.5 | F14=8.0 | G14=14 | H14=0.0 | I14=0 | J14=50000000 | K14=375000000 | L14=375000000 | M14=0 | N14=0 | O14=0.3 | P14=0 | Q14=0 | R14=1 | S14=0.1 | T14=5000000 | U14=37500000 | V14=12000000 | W14=8000000 | X14=72000000 | Y14=109500000 | Z14=0.292 | AA14=12000000 | AB14=0.032 | AC14=0.438713405 | AD14=6472650.222 | AE14=16125000 | AF14=0.481713405 | AG14=#REF! | AH14=#REF! | AI14=#REF! | AJ14=#REF! | AK14=0.8 | AL14=#REF!
R15: B15=437500000.0 | C15=187500000 | D15=250000000.0 | E15=8.75 | F15=8.0 | G15=14 | H15=0.0 | I15=0 | J15=50000000 | K15=437500000 | L15=437500000 | M15=0 | N15=0 | O15=0.3 | P15=0 | Q15=0 | R15=1 | S15=0.1 | T15=5000000 | U15=43750000 | V15=12000000 | W15=8000000 | X15=82000000 | Y15=125750000 | Z15=0.2874285714 | AA15=12000000 | AB15=0.02742857143 | AC15=0.4278324491 | AD15=6300174 | AE15=18812500 | AF15=0.4708324491 | AG15=#REF! | AH15=#REF! | AI15=#REF! | AJ15=#REF! | AK15=0.9 | AL15=#REF!
R16: B16=500000000.0 | C16=200000000 | D16=300000000.0 | E16=12.0 | F16=8.0 | G16=14 | H16=0.0 | I16=0 | J16=50000000 | K16=500000000 | L16=500000000 | M16=0.03 | N16=0 | O16=0.3 | P16=0 | Q16=0 | R16=1 | S16=0.1 | T16=5000000 | U16=60000000 | V16=15000000 | W16=8000000 | X16=111000000 | Y16=171000000 | Z16=0.342 | AA16=15000000 | AB16=0.03 | AC16=0.4960883635 | AD16=5926475.519 | AE16=21500000 | AF16=0.5390883635 | AG16=#REF! | AH16=#REF! | AI16=#REF! | AJ16=#REF! | AK16=1 | AL16=#REF!
R17: B17=625000000.0 | C17=275000000 | D17=350000000.0 | E17=12.5 | F17=8.0 | G17=14 | H17=0.0 | I17=0 | J17=50000000 | K17=625000000 | L17=625000000 | M17=0.0325 | N17=4062500 | O17=0.3 | P17=0 | Q17=0 | R17=1 | S17=0.1 | T17=5000000 | U17=66562500 | V17=18000000 | W17=8000000 | X17=118000000 | Y17=184562500 | Z17=0.2953 | AA17=22062500 | AB17=0.0353 | AC17=0.4222393827 | AD17=5876823.273 | AE17=26875000 | AF17=0.4652393827 | AG17=#REF! | AH17=#REF! | AI17=#REF! | AJ17=#REF! | AK17=1.2 | AL17=#REF!
R18: B18=750000000.0 | C18=350000000 | D18=400000000.0 | E18=15 | F18=8.0 | G18=14 | H18=0.0 | I18=0 | J18=50000000 | K18=750000000 | L18=750000000 | M18=0.035 | N18=8750000 | O18=0.3 | P18=0 | Q18=0 | R18=1 | S18=0.1 | T18=5000000 | U18=83750000 | V18=18000000 | W18=8000000 | X18=138000000 | Y18=221750000 | Z18=0.2956666667 | AA18=26750000 | AB18=0.03566666667 | AC18=0.4162722809 | AD18=5653388.167 | AE18=32250000 | AF18=0.4592722809 | AG18=#REF! | AH18=#REF! | AI18=#REF! | AJ18=#REF! | AK18=1.4 | AL18=#REF!
R19: B19=875000000.0 | C19=425000000 | D19=450000000.0 | E19=17.5 | F19=8.0 | G19=14 | H19=0.0 | I19=0 | J19=50000000 | K19=875000000 | L19=875000000 | M19=0.0375 | N19=14062500 | O19=0.3 | P19=0 | Q19=0 | R19=1 | S19=0.1 | T19=5000000 | U19=101562500 | V19=18000000 | W19=8000000 | X19=158000000 | Y19=259562500 | Z19=0.2966428571 | AA19=32062500 | AB19=0.03664285714 | AC19=0.4121743569 | AD19=5464327.692 | AE19=37625000 | AF19=0.4551743569 | AG19=#REF! | AH19=#REF! | AI19=#REF! | AJ19=#REF! | AK19=1.6 | AL19=#REF!
R20: B20=1000000000.0 | C20=500000000 | D20=500000000.0 | E20=20 | F20=11.0 | G20=17 | H20=0.0 | I20=0 | J20=50000000 | K20=1000000000 | L20=1000000000 | M20=0.04 | N20=20000000 | O20=0.3 | P20=0 | Q20=0 | R20=1 | S20=0.1 | T20=5000000 | U20=120000000 | V20=18000000 | W20=8000000 | X20=178000000 | Y20=298000000 | Z20=0.298 | AA20=38000000 | AB20=0.038 | AC20=0.4058551495 | AD20=5135959.5 | AE20=43000000 | AF20=0.4488551495 | AG20=#REF! | AH20=#REF! | AI20=#REF! | AJ20=#REF! | AK20=1.8 | AL20=#REF!
R21: B21=1125000000.0 | C21=575000000 | D21=550000000.0 | E21=22.5 | F21=11.0 | G21=17 | H21=0.0 | I21=0 | J21=50000000 | K21=1125000000 | L21=1125000000 | M21=0.0425 | N21=26562500 | O21=0.3 | P21=0 | Q21=0 | R21=1 | S21=0.1 | T21=5000000 | U21=139062500 | V21=18000000 | W21=8000000 | X21=198000000 | Y21=337062500 | Z21=0.2996111111 | AA21=44562500 | AB21=0.03961111111 | AC21=0.4043936286 | AD21=5016184.346 | AE21=48375000 | AF21=0.4473936286 | AG21=230000000.0 | AH21=818592966 | AI21=0.727638192 | AJ21=306407034 | AK21=2 | AL21=0.2802445634
R22: B22=1437500000.0 | C22=837500000 | D22=600000000.0 | E22=28.75 | F22=11.0 | G22=18 | H22=0.0 | I22=0 | J22=50000000 | K22=1437500000 | L22=1437500000 | M22=0.045 | N22=42187500 | O22=0.3 | P22=0 | Q22=0 | R22=1 | S22=0.1 | T22=5000000 | U22=185937500 | V22=18000000 | W22=8000000 | X22=248000000 | Y22=433937500 | Z22=0.3018695652 | AA22=60187500 | AB22=0.04186956522 | AC22=0.3999620071 | AD22=4739760.848 | AE22=61812500 | AF22=0.4429620071 | AG22=#REF! | AH22=#REF! | AI22=#REF! | AJ22=#REF! | AK22=2.5 | AL22=#REF!
R23: B23=1750000000.0 | C23=1050000000 | D23=700000000 | E23=35 | F23=12.0 | G23=19 | H23=0.0 | I23=0 | J23=50000000 | K23=1750000000 | L23=1750000000 | M23=0.05 | N23=62500000 | O23=0.3 | P23=0 | Q23=0 | R23=1 | S23=0.1 | T23=5000000 | U23=237500000 | V23=18000000 | W23=8000000 | X23=298000000 | Y23=535500000 | Z23=0.306 | AA23=80500000 | AB23=0.046 | AC23=0.3993163742 | AD23=4536212.636 | AE23=75250000 | AF23=0.4423163742 | AG23=#REF! | AH23=#REF! | AI23=#REF! | AJ23=#REF! | AK23=3 | AL23=#REF!
R24: Z24=0.304386275
R25: B25=Mức Level | C25=Khoảng Cách | D25=Mức lương | E25=Mức doanh thu thực cả team | F25=Lương cứng | G25=% com | H25=Thu nhập TP | I25=Tổng CP/ DTT
R26: B26=Level 01 | C26=0.6 | D26=10000000.0 | E26=250000000 | F26=10000000 | G26=0.0 | H26=10000000.0 | I26=0.9414463550588238
R27: B27=Level 02 | C27=0.7 | D27=12000000.0 | E27=312500000 | F27=12000000 | G27=0.0 | H27=12000000.0 | I27=0.7427001050301373
R28: B28=Level 03 | C28=0.8 | D28=12000000.0 | E28=375000000 | F28=12000000 | G28=0.0 | H28=12000000.0 | I28=0.6113198036239316
R29: B29=Level 04 | C29=0.9 | D29=12000000.0 | E29=437500000 | F29=12000000 | G29=0.0 | H29=12000000.0 | I29=0.5182612699759038
R30: B30=Level 05 | C30=1.0 | D30=15000000.0 | E30=500000000 | F30=15000000 | G30=0.03 | H30=15000000.0 | I30=0.45247868960000004
R31: B31=Level 06 | C31=1.2 | D31=18000000.0 | E31=625000000 | F31=18000000 | G31=0.0325 | H31=22062500.0 | I31=0.3608726106352941
R32: B32=Level 07 | C32=1.4 | D32=18000000.0 | E32=750000000 | F32=18000000 | G32=0.035 | H32=26749999.999999996 | I32=0.3052631091428572
R33: B33=Level 08 | C33=1.6 | D33=18000000.0 | E33=875000000 | F33=18000000 | G33=0.0375 | H33=32062500.0 | I33=0.30682578227664403
R34: B34=Level 09 | C34=1.8 | D34=18000000.0 | E34=1000000000 | F34=18000000 | G34=0.04 | H34=38000000.0 | I34=0.2662350790882353
R35: B35=Level 10 | C35=2.0 | D35=18000000.0 | E35=1125000000 | F35=18000000 | G35=0.0425 | H35=44562500.0 | I35=0.25134722939259263
R36: B36=Level 11 | C36=2.5 | D36=18000000.0 | E36=1437500000 | F36=18000000 | G36=0.045 | H36=60187499.999999985 | I36=0.20358205089142578
R37: B37=Level 12 | C37=3.0 | D37=18000000.0 | E37=1750000000 | F37=18000000 | G37=0.05 | H37=80500000.0 | I37=0.17589536509890114


##### SHEET: Vận hành PFM #####
R1: J1=100000000.0 | L1=200000000.0 | N1=500000000.0
R2: B2=DTT | C2=Designer | D2=Editor | E2=Ads | F2=Content | G2=VH sàn | H2=Leader | I2=Tổng | J2=Junior | K2=Số ng vận hành | L2=Executive | M2=Số ng vận hành | N2=Senior | O2=Số ng vận hành
R3: B3=100000000.0 | C3=1.0 | D3=1.0 | E3=1.0 | F3=1.0 | G3=0.0 | H3=1.0 | I3=5 | J3=1 | K3=6 | L3=0.5 | M3=5.5 | N3=1.0 | O3=6
R4: B4=200000000.0 | C4=1.0 | D4=1.0 | E4=1.0 | F4=1.0 | G4=1.0 | H4=1.0 | I4=6 | J4=2 | K4=7 | L4=1 | M4=6 | N4=1.0 | O4=6
R5: B5=350000000.0 | C5=1.0 | D5=1.0 | E5=1.0 | F5=1.0 | G5=1.0 | H5=1.0 | I5=6 | J5=3.5 | K5=8.5 | L5=1.75 | M5=6.75 | N5=0.7 | O5=5.7
R6: B6=500000000.0 | C6=1.0 | D6=2.0 | E6=1.0 | F6=2.0 | G6=1.0 | H6=1.0 | I6=8 | J6=5 | K6=10 | L6=2.5 | M6=7.5 | N6=1 | O6=6
R7: B7=1000000000.0 | C7=2.0 | D7=2.0 | E7=2.0 | F7=3.0 | G7=1.0 | H7=1.0 | I7=11 | J7=10 | K7=15 | L7=5 | M7=10 | N7=2 | O7=7
R8: A8=Executive | B8=Lương cứng | C8=8000000.0 | D8=10000000.0 | E8=8000000.0 | F8=9000000.0 | G8=7000000.0 | H8=12000000.0 | J8=6000000.0 | L8=10000000.0 | N8=14000000.0
R9: B9=KPI | C9=3000000.0 | D9=3000000.0 | E9=3000000.0 | F9=3000000.0 | G9=3000000.0 | H9=7000000.0 | J9=3000000.0 | L9=4000000.0 | N9=6000000.0
R10: A10=Senior | B10=Lương cứng | C10=11000000.0 | D10=13000000.0 | E10=10000000.0 | F10=11000000.0 | G10=9000000.0 | H10=18000000.0
R11: B11=KPI | C11=4000000.0 | D11=4000000.0 | E11=4000000.0 | F11=4000000.0 | G11=4000000.0
R12: B12=500000000.0 | C12=1.0 | D12=2.0 | E12=1.0 | F12=2.0 | G12=1.0 | H12=1.0 | I12=11 | J12=1.0 | L12=2.0
R13: B13=Thu nhập | C13=exe 8- 9tr + bonus | D13=Senior 12tr+bonus | E13=exe 8tr+ bonus | F13=senior: 10 +bonus | G13=exe 7 - 8tr+ bonus | M13=2026-03-02 00:00:00 | N13=2026-03-01 00:00:00 | O13=2026-03-02 00:00:00 | Q13=2026-02-01 00:00:00
R14: C14=Thu nhập: 11- 12tr (hoàn thành đủ số lượng) | D14=Junior 7-8tr+bonus | F14=junior 7tr+ bonus | J14=9000000 | L14=14000000 | N14=20000000
R15: C15=8000000.0 | D15=12000000.0 | E15=8000000.0 | F15=10000000.0 | G15=7000000.0 | J15=0.09 | L15=0.07 | N15=0.04
R16: C16=3000000.0 | D16=3000000.0 | E16=3000000.0 | F16=3000000.0 | G16=3000000.0
R17: D17=7000000.0 | F17=7000000.0
R18: D18=3000000.0 | F18=3000000.0
R19: B19=1000000000.0 | C19=1 se 1 ju | E19=1 se 1 ex | F19=1 ex 1 se 1 ju | G19=1 ex 1 ju
R20: C20=10000000.0 | E20=12 - 15
R21: C21=3000000.0
R22: C22=7 - 10
R23: B23=DTT | C23=Designer | D23=Editor | E23=Ads | F23=Content | G23=VH sàn | H23=Leader | I23=Acc | J23=Tổng | K23=Designer | L23=Editor | M23=Ads | N23=Content | O23=VH sàn | P23=Leader | Q23=Acc | R23=Tổng lương VH
R24: A24=Ju | B24=500000000.0 | D24=1.0 | F24=1.0 | I24=1.0 | J24=11 | K24=11000000 | L24=22000000 | M24=11000000 | N24=20000000 | O24=10000000 | P24=20000000 | Q24=37000000 | R24=131000000
R25: A25=Ex | C25=1.0 | E25=1.0 | G25=1.0 | H25=1.0 | I25=2.0
R26: A26=Se | D26=1.0 | F26=1.0
R27: A27=Ju | B27=1000000000.0 | C27=1.0 | D27=1.0 | F27=1.0 | G27=1.0 | I27=1.0 | J27=16 | K27=22000000 | L27=22000000 | M27=26000000 | N27=32500000 | O27=17000000 | P27=30000000 | Q27=57000000 | R27=206500000
R28: A28=Ex | E28=1.0 | F28=1.0 | G28=1.0 | I28=2.0
R29: A29=Se | C29=1.0 | D29=1.0 | E29=1.0 | F29=1.0 | H29=1.0 | I29=1.0
R30: A30=Ju | B30=Thu nhập | C30=7000000.0 | D30=7000000.0 | E30=9000000.0 | F30=7000000.0 | G30=7000000.0 | I30=9000000.0
R31: A31=Ex | C31=11000000.0 | D31=13000000.0 | E31=11000000.0 | F31=12500000.0 | G31=10000000.0 | H31=20000000.0 | I31=14000000.0
R32: A32=Se | C32=15000000.0 | D32=15000000.0 | E32=15000000.0 | F32=13000000.0 | G32=10000000.0 | H32=30000000.0 | I32=20000000.0
R33: A33=Ju | B33=200000000.0 | E33=1.0 | I33=2.0 | J33=6 | K33=0 | L33=0 | M33=9000000 | N33=0 | O33=0 | P33=0 | Q33=18000000 | R33=70500000
R34: A34=Ex | C34=1.0 | F34=1.0 | H34=1.0 | K34=11000000 | L34=0 | M34=0 | N34=12500000 | O34=0 | P34=20000000 | Q34=0
R35: A35=Se | K35=0 | L35=0 | M35=0 | N35=0 | O35=0 | P35=0 | Q35=0
R36: B36=100000000.0 | C36=1.0 | F36=1.0 | H36=1.0 | I36=2.0 | J36=5 | K36=13000000.0 | N36=12500000.0 | P36=20000000.0 | Q36=18000000.0 | R36=63500000
R39: B39=DTT Mục Tiêu
R40: M40=15000000.0 | N40=0.0 | O40=24000000.0 | P40=35000000.0 | Q40=15000000.0 | R40=89000000
R41: B41=DTT PFM | C41=Số sale | D41=Lương kinh doanh | E41=Tỷ lệ TN KD/ DTT | F41=số người vận hành dịch vụ | G41=Lương vận hành | H41=Tỷ lệ CP VH/ DTT | I41=Chi phí chung/ 1 người/ tháng | J41=Tổng chi phí/ DTT | K41=Tỷ lệ CP Acc/ DTT | M41=Kế toán | N41=CS | O41=HR | P41=BGĐ | Q41=KT | R41=Tổng NS | S41=Designer | T41=Editor | U41=Ads | V41=Content | W41=VH sàn | X41=Leader | Y41=CP BO | Z41=Tổng CP/ DTT | AA41=CP cứng BO | AB41=Tổng CP
R44: B44=500000000.0 | C44=10.0 | D44=145000000.0 | E44=0.4182367751 | F44=11 | G44=131000000 | H44=0.3902367751 | I44=5828944.321 | J44=0.8084735501 | K44=0.1089736659 | M44=1.0 | N44=0.0 | O44=2.0 | P44=2.0 | Q44=1.0 | R44=28 | S44=#REF! | T44=#REF! | U44=#REF! | V44=#REF! | W44=#REF! | X44=#REF! | Y44=52929814.4 | Z44=0.914333179 | AA44=34973665.93 | AB44=528210441
R45: B45=1000000000.0 | C45=17.0 | D45=290000000.0 | E45=0.3807009493 | F45=16 | G45=206500000 | H45=0.287123066 | I45=5038941.625 | J45=0.6678240153 | K45=0.2266557665 | M45=1.0 | N45=0.0 | O45=2.0 | P45=2.0 | Q45=1.0 | R45=40 | S45=#REF! | T45=#REF! | U45=#REF! | V45=#REF! | W45=#REF! | X45=#REF! | Y45=50296472.08 | Z45=0.7181204873 | AA45=30233649.75
R47: A47=ACC | B47=JUNIOR
R48: B48=DTT PFM | C48=Số sale | D48=Lương kinh doanh | E48=Tỷ lệ TN KD/ DTT | F48=số người vận hành dịch vụ | G48=Lương vận hành | H48=Tỷ lệ CP VH/ DTT | I48=Chi phí chung/ 1 người/ tháng | J48=Tổng chi phí/ DTT | K48=Tỷ lệ CP Acc/ DTT | M48=Kế toán | N48=CS | O48=HR | P48=BGĐ | Q48=KT | R48=Tổng NS | S48=Designer | T48=Editor | U48=Ads | V48=Content | W48=VH sàn | X48=Leader | Y48=CP BO | Z48=Tổng CP/ DTT
R49: B49=100000000.0 | C49=2.0 | D49=29000000.0 | E49=0.53333523 | F49=6 | G49=75000000 | H49=1.23667046 | I49=8111174.333 | J49=1.77000569 | K49=0.1711117433 | M49=1.0 | N49=0.0 | O49=2.0 | P49=2.0 | Q49=1.0 | R49=15 | S49=0.1911117433 | T49=0.2111117433 | U49=0.1911117433 | V49=0.2011117433 | W49=0 | X49=0.2711117433 | Y49=60537247.78 | Z49=2.375378168
R50: B50=200000000.0 | C50=4.0 | D50=55000000.0 | E50=0.4572978069 | F50=7 | G50=94000000 | H50=0.7252169297 | I50=7291912.278 | J50=1.182514737 | K50=0.1629191228 | M50=1.0 | N50=0.0 | O50=2.0 | P50=2.0 | Q50=1.0 | R50=18 | S50=0.09145956139 | T50=0.1014595614 | U50=0.09145956139 | V50=0.09645956139 | W50=0.08645956139 | X50=0.1314595614 | Y50=57806374.26 | Z50=1.471546608
R51: B51=350000000.0 | C51=7.0 | D51=94000000.0 | E51=0.4165177194 | F51=8.5 | G51=107500000 | H51=0.4643357911 | I51=6472650.222 | J51=0.8808535105 | K51=0.1547265022 | M51=1.0 | N51=0.0 | O51=2.0 | P51=2.0 | Q51=1.0 | R51=22.5 | S51=0.04992185778 | T51=0.05563614349 | U51=0.04992185778 | V51=0.05277900063 | W51=0.04706471492 | X51=0.07277900063 | Y51=55075500.74 | Z51=1.038212084
R52: B52=500000000.0 | C52=10.0 | D52=145000000.0 | E52=0.4182367751 | F52=10 | G52=146000000 | H52=0.4085788864 | I52=5828944.321 | J52=0.8268156615 | K52=0.1482894432 | M52=2.0 | N52=0.0 | O52=2.0 | P52=2.0 | Q52=1.0 | R52=28 | S52=0.03365788864 | T52=0.07531577729 | U52=0.03365788864 | V52=0.07131577729 | W52=0.03165788864 | X52=0.04965788864 | Y52=52929814.4 | Z52=0.9326752903
R53: B53=1000000000.0 | C53=20.0 | D53=305000000.0 | E53=0.4081170672 | F53=15 | G53=225000000 | H53=0.298655048 | I53=4910336.535 | J53=0.7067721153 | K53=0.1391033653 | M53=2.0 | N53=0.0 | O53=2.0 | P53=2.0 | Q53=1.0 | R53=43 | S53=0.03182067307 | T53=0.03582067307 | U53=0.03182067307 | V53=0.0507310096 | W53=0.01491033653 | X53=0.02391033653 | Y53=49867788.45 | Z53=0.7566399037
R55: A55=ACC | B55=EXECUTIVE
R56: B56=DTT PFM | C56=Số sale | D56=Lương kinh doanh | E56=Tỷ lệ TN KD/ DTT | F56=số người vận hành dịch vụ | G56=Lương vận hành | H56=Tỷ lệ CP VH/ DTT | I56=Chi phí chung/ 1 người/ tháng | J56=Tổng chi phí/ DTT | K56=Tỷ lệ CP Acc/ DTT | M56=Kế toán | N56=CS | O56=HR | P56=BGĐ | Q56=KT | R56=Tổng NS | S56=Designer | T56=Editor | U56=Ads | V56=Content | W56=VH sàn | X56=Leader | Z56=Tổng CP/ DTT
R57: B57=100000000.0 | C57=2.0 | D57=29000000.0 | E57=0.53333523 | F57=5.5 | G57=73000000 | H57=1.185437226 | I57=8280676.828 | J57=1.72385753 | K57=0.1114033841 | M57=1.0 | N57=0.0 | O57=2.0 | P57=2.0 | Q57=1.0 | R57=14.5 | S57=0.1928067683 | T57=0.2128067683 | U57=0.1928067683 | V57=0.2028067683 | W57=0 | X57=0.2728067683 | Z57=2.329230008
R58: B58=200000000.0 | C58=4.0 | D58=55000000.0 | E58=0.4572978069 | F58=6 | G58=90000000 | H58=0.6759861512 | I58=7532871.706 | J58=1.139307944 | K58=0.1076643585 | M58=1.0 | N58=0.0 | O58=2.0 | P58=2.0 | Q58=1.0 | R58=17 | S58=0.09266435853 | T58=0.1026643585 | U58=0.09266435853 | V58=0.09766435853 | W58=0.08766435853 | X58=0.1326643585 | Z58=1.428339815
R59: B59=350000000.0 | C59=7.0 | D59=94000000.0 | E59=0.4165177194 | F59=6.75 | G59=100500000 | H59=0.4173026787 | I59=6749027.783 | J59=0.8401375994 | K59=0.1037451389 | M59=1.0 | N59=0.0 | O59=2.0 | P59=2.0 | Q59=1.0 | R59=20.75 | S59=0.05071150795 | T59=0.05642579367 | U59=0.05071150795 | V59=0.05356865081 | W59=0.04785436509 | X59=0.07356865081 | Z59=0.997496173
R60: B60=500000000.0 | C60=10.0 | D60=145000000.0 | E60=0.4182367751 | F60=7.5 | G60=136000000 | H60=0.3633067271 | I60=6087115.137 | J60=0.7872232601 | K60=0.1004355757 | M60=2.0 | N60=0.0 | O60=2.0 | P60=2.0 | Q60=1.0 | R60=25.5 | S60=0.03417423027 | T60=0.07634846055 | U60=0.03417423027 | V60=0.07234846055 | W60=0.03217423027 | X60=0.05017423027 | Z60=0.8930828889
R61: B61=1000000000.0 | C61=20.0 | D61=305000000.0 | E61=0.4081170672 | F61=10 | G61=205000000 | H61=0.256359595 | I61=5135959.5 | J61=0.6692147445 | K61=0.0956797975 | M61=2.0 | N61=0.0 | O61=2.0 | P61=2.0 | Q61=1.0 | R61=38 | S61=0.032271919 | T61=0.036271919 | U61=0.032271919 | V61=0.0514078785 | W61=0.0151359595 | X61=0.0241359595 | Z61=0.7190825329
R63: B63=SENIOR
R64: B64=DTT PFM | C64=Số sale | D64=Lương kinh doanh | E64=Tỷ lệ TN KD/ DTT | F64=số người vận hành dịch vụ | G64=Lương vận hành | H64=Tỷ lệ CP VH/ DTT | I64=Chi phí chung/ 1 người/ tháng | J64=Tổng chi phí/ DTT | K64=Tỷ lệ CP Acc/ DTT | M64=Kế toán | N64=CS | O64=HR | P64=BGĐ | Q64=KT | R64=Tổng NS | S64=Designer | T64=Editor | U64=Ads | V64=Content | W64=VH sàn | X64=Leader | Z64=Tổng CP/ DTT
R65: B65=100000000.0 | C65=2.0 | D65=29000000.0 | E65=0.5384203048 | F65=6 | G65=86000000 | H65=1.311972302 | I65=7532871.706 | J65=1.827958454 | K65=0.2153287171 | M65=1.0 | N65=1.0 | O65=2.0 | P65=2.0 | Q65=2.0 | R65=17 | S65=0.1853287171 | T65=0.2053287171 | U65=0.1853287171 | V65=0.1953287171 | W65=0 | X65=0.2653287171 | Z65=2.433330931
R66: B66=200000000.0 | C66=4.0 | D66=55000000.0 | E66=0.4633217926 | F66=6 | G66=96000000 | H66=0.69228951 | I66=7076317 | J66=1.144197435 | K66=0.105381585 | M66=1.0 | N66=1.0 | O66=2.0 | P66=2.0 | Q66=2.0 | R66=19 | S66=0.090381585 | T66=0.100381585 | U66=0.090381585 | V66=0.095381585 | W66=0.085381585 | X66=0.130381585 | Z66=1.433229306
R67: B67=350000000.0 | C67=7.0 | D67=94000000.0 | E67=0.4228349208 | F67=5.7 | G67=90000000 | H67=0.3645221127 | I67=6593463.06 | J67=0.7838012683 | K67=0.04118692612 | M67=1.0 | N67=1.0 | O67=2.0 | P67=2.0 | Q67=2.0 | R67=21.7 | S67=0.05026703731 | T67=0.05598132303 | U67=0.05026703731 | V67=0.05312418017 | W67=0.04740989446 | X67=0.07312418017 | Z67=0.9411598419
R68: B68=500000000.0 | C68=10.0 | D68=145000000.0 | E68=0.423916533 | F68=6 | G68=121000000 | H68=0.3157393448 | I68=6144945.4 | J68=0.7409281436 | K68=0.0402898908 | M68=1.0 | N68=1.0 | O68=2.0 | P68=2.0 | Q68=2.0 | R68=25 | S68=0.0342898908 | T68=0.0765797816 | U68=0.0342898908 | V68=0.0725797816 | W68=0.0322898908 | X68=0.0502898908 | Z68=0.8467877724
R69: B69=1000000000.0 | C69=20.0 | D69=305000000.0 | E69=0.4128551495 | F69=7 | G69=175000000 | H69=0.2117063 | I69=5243757.139 | J69=0.6268251999 | K69=0.03848751428 | M69=1.0 | N69=1.0 | O69=2.0 | P69=2.0 | Q69=2.0 | R69=36 | S69=0.03248751428 | T69=0.03648751428 | U69=0.03248751428 | V69=0.05173127142 | W69=0.01524375714 | X69=0.02424375714 | Z69=0.6766929883
R71: B71=Số người dự kiến | C71=Định phí trung bình tháng | D71=Biến phí trung bình tháng | E71=Chi phí bình quân đầu người | F71=Tổng chi phí tháng
R72: B72=25.0 | C72=73733585.0 | D72=3195602.0 | E72=6144945.0 | F72=153623625
R73: C73=10.0 | F73=6.0 | G73=159500000 | I73=6144945.4 | L73=14 | M73=1.0 | N73=1.0 | O73=2.0 | P73=2.0 | Q73=2.0 | R73=25
R74: C74=10.0 | F74=5.0 | G74=152500000 | I74=6267834.708 | L74=13 | M74=1.0 | N74=1.0 | O74=2.0 | P74=2.0 | Q74=2.0 | R74=24
R75: G75=295500000
R76: G76=220000000


##### SHEET: Vận hành DVMKT #####
R1: F1=MỨC LƯƠNG DỰ KIẾN CÁC VỊ TRÍ VẬN HÀNH | H1=Nhân viên | J1=Level | K1=Designer | M1=Editor | O1=Ads | Q1=Content | S1=VH sàn | U1=Planner | W1=Acc
R2: K2=P1 + P2 | L2=P3 | M2=P1 + P2 | N2=P3 | O2=P1 + P2 | P2=P3 | Q2=P1 + P2 | R2=P3 | S2=P1 + P2 | T2=P3 | U2=P1 + P2 | V2=P3 | W2=P1 + P2 | X2=P3
R3: J3=Ju | K3=8000000.0 | L3=1000000.0 | M3=10000000.0 | N3=1000000.0 | O3=8000000.0 | P3=1000000.0 | Q3=7000000.0 | R3=1000000.0 | S3=9000000.0 | W3=8000000.0 | X3=2000000.0
R4: J4=Ex | K4=10000000.0 | L4=1000000.0 | M4=12000000.0 | N4=1000000.0 | O4=10000000.0 | P4=2000000.0 | Q4=8000000.0 | R4=2000000.0 | S4=11000000.0 | U4=15000000.0 | V4=5000000.0 | W4=10000000.0 | X4=3000000.0
R5: J5=Se | K5=13000000.0 | L5=2000000.0 | M5=15000000.0 | N5=2000000.0 | O5=11000000.0 | P5=4000000.0 | Q5=10000000.0 | R5=3000000.0 | S5=13000000.0 | U5=20000000.0 | V5=10000000.0 | W5=12000000.0 | X5=4000000.0
R6: H6=Quản lý | J6=Pre-leader | Q6=10000000.0 | R6=2500000.0 | U6=15000000.0 | V6=5000000.0
R7: J7=Leader | Q7=12000000.0 | R7=3000000.0 | U7=18000000.0 | V7=5000000.0
R8: C8=CƠ CẤU NHÂN SỰ VẬN HÀNH | K8=LƯƠNG VẬN HÀNH
R9: A9=Level | B9=DTT | C9=Designer | D9=Editor | E9=Ads | F9=Content | G9=VH sàn | H9=Planner | I9=Acc | J9=Tổng số người | K9=Designer | L9=Editor | M9=Ads | N9=Content | O9=VH sàn | P9=Planner | Q9=Acc | R9=Tổng lương VH
R10: A10=Ju | B10=100000000.0 | I10=1.0 | J10=7 | K10=0 | L10=0 | M10=0 | N10=0 | O10=0 | P10=0 | Q10=10000000 | R10=84500000
R11: A11=Ex | C11=1.0 | D11=1.0 | E11=1.0 | F11=1.0 | K11=11000000 | L11=13000000 | M11=12000000 | N11=8000000.0 | O11=0 | P11=0 | Q11=0
R12: A12=Leader | F12=1.0 | H12=1.0 | K12=0 | L12=0 | M12=0 | N12=12500000.0 | O12=0 | P12=18000000.0 | Q12=0
R13: A13=Ju | B13=200000000.0 | F13=1.0 | I13=2.0 | J13=9 | K13=0 | L13=0 | M13=0 | N13=4000000.0 | O13=0 | P13=0 | Q13=20000000 | R13=98500000
R14: A14=Ex | C14=1.0 | D14=1.0 | E14=1.0 | F14=1.0 | K14=11000000 | L14=13000000 | M14=12000000 | N14=8000000.0 | O14=0 | P14=0 | Q14=0
R15: A15=Leader | F15=1.0 | H15=1.0 | K15=0 | L15=0 | M15=0 | N15=12500000.0 | O15=0 | P15=18000000.0 | Q15=0
R16: A16=Ju | B16=350000000.0 | F16=1.0 | I16=1.0 | J16=9 | K16=0 | L16=0 | M16=0 | N16=8000000 | O16=0 | P16=0 | Q16=10000000 | R16=108000000
R17: A17=Ex | C17=1.0 | D17=1.0 | E17=1.0 | F17=1.0 | I17=1.0 | K17=11000000 | L17=13000000 | M17=12000000 | N17=10000000 | O17=0 | P17=0 | Q17=13000000
R18: A18=Se | F18=1.0 | H18=1.0 | K18=0 | L18=0 | M18=0 | N18=13000000 | O18=0 | P18=18000000.0 | Q18=0
R19: A19=Ju | B19=500000000.0 | C19=1.0 | F19=1.0 | I19=1.0 | J19=12 | K19=9000000 | L19=0 | M19=0 | N19=8000000 | O19=0 | P19=0 | Q19=10000000 | R19=146000000
R20: A20=Ex | C20=1.0 | D20=1.0 | E20=1.0 | F20=1.0 | G20=1.0 | I20=2.0 | K20=11000000 | L20=13000000 | M20=12000000 | N20=10000000 | O20=11000000 | P20=0 | Q20=26000000
R21: A21=Se | F21=1.0 | H21=1.0 | K21=0 | L21=0 | M21=0 | N21=13000000 | O21=0 | P21=23000000.0 | Q21=0
R22: A22=Ju | B22=1000000000.0 | C22=1.0 | D22=1.0 | E22=1.0 | F22=1.0 | G22=1.0 | I22=1.0 | J22=16 | K22=9000000 | L22=11000000 | M22=9000000 | N22=8000000 | O22=9000000 | P22=0 | Q22=10000000 | R22=209000000
R23: A23=Ex | F23=1.0 | G23=1.0 | I23=2.0 | K23=0 | L23=0 | M23=0 | N23=10000000 | O23=11000000 | P23=0 | Q23=26000000
R24: A24=Se | C24=1.0 | D24=1.0 | E24=1.0 | F24=1.0 | H24=1.0 | I24=1.0 | K24=15000000 | L24=17000000 | M24=15000000 | N24=13000000 | O24=0 | P24=30000000 | Q24=16000000
R26: B26=KHỐI HỖ TRỢ | C26=Kế toán | D26=HCNS | E26=Kỹ thuật | F26=BGĐ | G26=Tổng nhân sự
R27: C27=1.0 | D27=2.0 | E27=1.0 | F27=2.0 | G27=6
R28: C28=15000000.0 | D28=26000000.0 | E28=15000000.0 | F28=30000000.0 | G28=86000000
R29: C29=2026-03-02 00:00:00 | D29=2026-03-02 00:00:00 | E29=2026-02-01 00:00:00
R32: B32=DTT PFM | C32=Số sale | D32=Lương NV kinh doanh | E32=Số người vận hành dịch vụ | F32=Lương vận hành | G32=Tỷ lệ lương VH/ DTT | H32=Tổng số nhân sự cho mảng dịch vụ | I32=Tổng chi phí/ 1 người | J32=Chi phí khối hỗ trợ | K32=Tổng chi phí/ DTT | L32=Lương toàn vận hành + hỗ trợ cho mảng dịch vụ MKT
R33: B33=100000000.0 | C33=2 | D33=26000000 | E33=7 | F33=84500000 | G33=0.845 | H33=11.5 | I33=9607218.087 | J33=52446566.49 | K33=2.590187474 | L33=170500000
R34: B34=200000000.0 | C34=4 | D34=52000000 | E34=9 | F34=98500000 | G34=0.4925 | H34=15.5 | I34=7952607.484 | J34=49413113.72 | K34=1.556248092 | L34=184500000
R35: B35=350000000.0 | C35=7 | D35=91000000 | E35=9 | F35=108000000 | G35=0.3085714286 | H35=18.5 | I35=7181201.189 | J35=47998868.85 | K35=1.054512254 | L35=194000000
R36: B36=500000000.0 | C36=10 | D36=130000000 | E36=12 | F36=146000000 | G36=0.292 | H36=24.5 | I36=6205136.082 | J36=46209416.15 | K36=0.9298550921 | L36=232000000
R37: B37=1000000000.0 | C37=20 | D37=260000000 | E37=16 | F37=209000000 | G37=0.209 | H37=38.5 | I37=5110760.052 | J37=44203060.1 | K37=0.702301182 | L37=295000000
R39: B39=Số người dự kiến | C39=Định phí trung bình tháng | D39=Biến phí trung bình tháng | E39=Chi phí bình quân đầu người
R40: B40=25.0 | C40=73733585.0 | D40=3195602.0 | E40=6144945.0


##### SHEET: Doanh thu TB #####
R1: A1=2025.0
R2: A2=Nhóm sản phẩm | B2=Mã nhóm | C2=Số khách hàng | D2=Doanh thu từ tháng 1 - 8 | E2=Doanh thu T9- 12 | F2=Tổng | G2=Trung bình chi tiêu/ 1 KH/ năm
R3: A3=Invoice | B3=DV1 | C3=97.0 | D3=743628262.0 | E3=564471147.0 | F3=1308099409.0 | G3=13485561.0
R4: A4=Nolimit | B4=DV2 | C4=93.0 | D4=1391854133.0 | E4=669803413.0 | F4=2061657546.0 | G4=22168361.0
R5: A5=Quảng cáo | B5=DV3 | C5=9.0 | D5=47191749.0 | E5=4180410.0 | F5=51372159.0 | G5=5708018.0
R6: A6=Nguyên liệu | B6=DV4 | C6=29.0 | D6=78403677.0 | E6=0.0 | F6=78403677.0 | G6=2703575.0
R7: A7=Khác | B7=DV5 | C7=1.0 | D7=807000.0 | E7=0.0 | F7=807000.0 | G7=807000.0
R8: F8=3448967632
R9: F9=313542512
R11: A11=2024.0
R12: A12=Nhóm sản phẩm | C12=Số KH | F12=Tổng | G12=Trung bình chi tiêu/ 1 KH/ năm
R13: A13=Invoice | C13=185.0 | F13=1639150109.0 | G13=8860270.859
R14: A14=Nolimit | C14=70.0 | F14=2690344145.0 | G14=38433487.79
R15: A15=Nguyên liệu | C15=39.0 | F15=5335629418.0 | G15=136811010.7
R16: A16=GB | C16=29.0 | F16=13398713.24 | G16=462024.5945
R17: A17=TikTok | C17=56.0 | F17=248107877.0 | G17=4430497.804
R18: A18=Quản trị, khác... | F18=66421500.0
R19: A19=Quảng cáo | F19=16167061.0


##### SHEET: Planner #####
R1: A1=1. MÔ TẢ CÔNG VIỆC 
R2: A2=Phân bổ | B2=Nhiệm Vụ | C2=Mô Tả Chi Tiết
R3: A3=Nộ bộ công ty | B3=Lập kế hoạch Marketing tổng thể, kế hoạch Marketing chi tiết theo từng mục tiêu cụ thể của công ty | C3=Nghiên cứu thị trường và đối thủ cạnh tranh, xu hướng ngành và khách hàng mục tiêu để xây dựng kế hoạch Marketing.
R4: C4=Thu thập và phân tích dữ liệu để xác định các insight khách hàng và thị trường
R5: C5=Phối hợp với bộ phận Content và Design để biến insight thành ý tưởng sáng tạo
R6: C6=Đề xuất ý tưởng kế hoạch và định hướng sáng tạo cho các chiến dịch truyền thông/marketing.
R7: C7=Xây dựng dự báo ngân sách dựa trên mục tiêu công ty
R8: B8=Quản lý và tối ưu ngân sách Marketing | C8=Theo dõi và phân bổ ngân sách hiệu quả cho từng hoạt động cụ thể
R9: C9=Đánh giá độ chính xác của dự báo ngân sách và đề xuất điều chỉnh kịp thời để tối ưu ROAS
R10: B10=Đảm bảo tiến độ và chất lượng kế hoạch | C10=Đảm bảo tỷ lệ hoàn thành kế hoạch đúng hạn
R11: C11=Đề xuất và điều chỉnh kế hoạch nhanh chóng dựa trên phản hồi từ quản lý
R12: C12=Đảm bảo tính khả thi, chi tiết và rõ ràng trong kế hoạch để hỗ trợ các bộ phận triển khai
R13: B13=Quản trị website công ty | C13=Xây dựng landingpage các dịch vụ bao gồm: Nội dung, ý tưởng, dựng thành phẩm
R14: C14=Viết bài dịch vụ & bài SEO
R15: C15=Phối hợp với designer triển khai các idea thiết kế trên web
R16: B16=Phối hợp và hỗ trợ triển khai chiến dịch | C16=Phối hợp các bộ phận Content, Design, Ads trong việc triển khai chiến dịch dựa trên kế hoạch đã đề xuất.
R17: C17=Giám sát và điều chỉnh chiến dịch để đạt được hiệu quả cao nhất, đảm bảo tính nhất quán với mục tiêu đề ra.
R18: C18=Đảm bảo sự hài lòng của khách hàng với kế hoạch và kết quả đạt được.
R19: B19=Báo cáo theo dõi định kỳ | C19=Giám sát tiến độ thực hiện task của các bộ phận 
R20: C20=Đề xuất cải thiện chiến dịch khi triển khai
R21: C21=Báo cáo hoạt động MKT theo tháng, quý, năm
R22: A22=Khách hàng | B22=Lập kế hoạch truyền thông tổng thể, kế hoạch truyền thông chi tiết theo từng mục tiêu cụ thể của khách hàng | C22=Nghiên cứu thị trường và đối thủ cạnh tranh, xu hướng ngành và khách hàng mục tiêu để xây dựng kế hoạch Marketing.
R23: C23=Thu thập và phân tích dữ liệu để xác định các insight khách hàng và thị trường. Đảm bảo các insight được áp dụng vào kế hoạch triển khai nhằm tối ưu hóa hiệu quả chiến dịch
R24: C24=Phối hợp với bộ phận Content và Design để biến insight thành ý tưởng sáng tạo
R25: C25=Đề xuất ý tưởng kế hoạch và định hướng sáng tạo cho các chiến dịch truyền thông/marketing.
R26: B26=Quản lý và tối ưu ngân sách Marketing | C26=Xây dựng dự báo ngân sách dựa trên mục tiêu của khách hàng
R27: C27=Theo dõi và phân bổ ngân sách hiệu quả cho từng hoạt động cụ thể
R28: C28=Đánh giá độ chính xác của dự báo ngân sách và đề xuất điều chỉnh kịp thời để tối ưu ROAS
R29: B29=Đảm bảo tiến độ và chất lượng kế hoạch | C29=Đảm bảo tỷ lệ hoàn thành kế hoạch đúng hạn
R30: C30=Đề xuất và điều chỉnh kế hoạch nhanh chóng dựa trên phản hồi từ khách hàng
R31: C31=Đảm bảo tính khả thi, chi tiết và rõ ràng trong kế hoạch để hỗ trợ các bộ phận triển khai
R32: B32=Báo cáo theo dõi định kỳ | C32=Giám sát tiến độ thực hiện task của các bộ phận 
R33: C33=Đề xuất cải thiện chiến dịch khi triển khai
R34: C34=Báo cáo hoạt động MKT theo tháng, quý, năm
R36: A36=2. CÁC CHỈ SỐ KPIs
R37: A37=Phân bổ | B37=KPI | C37=Mô tả đo lường | D37=Trọng số nhóm | E37=Trọng Số Chi Tiết | F37=Đơn Vị tính | G37=Mức Tham Chiếu | H37=Thực Tế | I37=Tỷ Lệ Hoàn Thành | J37=Tổng KPI
R38: A38=Nội bộ | B38=Chi phí/ 1 CPA đạt mục tiêu | C38=Mess, lead, conversion... đạt kế hoạch đề ra (giá/ 1 CPA), theo kế hoạch tháng | D38=0.3 | E38=1.0 | F38=% | G38=1000000.0 | H38=1000000.0 | I38=1 | J38=0.79
R39: A39=Khách hàng | B39=Doanh thu thuần | C39=Chỉ tính KH phát sinh DT trong tháng | D39=0.7 | E39=0.3 | F39=triệu | G39=300000000.0 | H39=0.0 | I39=0
R40: B40=Tỷ lệ plan được chốt | C40=SL KH chốt/ tổng số lượng KH | E40=0.2 | F40=% | G40=0.3 | H40=0.3 | I40=1
R41: B41=Tỷ lệ dự án đạt mục tiêu | C41=Dự án đạt được các chỉ số theo mục tiêu | E41=0.3 | F41=% | G41=0.6 | H41=0.6 | I41=1
R42: B42=Tỷ lệ renew dự án | C42=Tỷ lệ khách hàng tái sử dụng dịch vụ | E42=0.2 | F42=% | G42=0.55 | H42=0.55 | I42=1
R43: A43=Executive
R44: A44=Phân bổ | B44=KPI | C44=Mô tả đo lường | D44=Trọng số nhóm | E44=Trọng Số Chi Tiết | F44=Đơn Vị tính | G44=Mức Tham Chiếu | H44=Thực Tế | I44=Tỷ Lệ Hoàn Thành | J44=Tổng KPI
R45: A45=Nội bộ | B45=Chi phí/ 1 CPA đạt mục tiêu | C45=Mess, lead, conversion... đạt kế hoạch đề ra (giá/ 1 CPA) | D45=0.3 | E45=1.0 | F45=% | G45=1000000.0 | H45=1000000.0 | I45=1 | J45=0.804
R46: A46=Khách hàng | B46=Doanh thu thuần | C46=Chỉ tính KH phát sinh DT trong tháng | D46=0.7 | E46=0.35 | F46=triệu | G46=500000000.0 | H46=100000000.0 | I46=0.2
R47: B47=Tỷ lệ plan được chốt | C47=SL KH chốt/ tổng số lượng KH | E47=0.3 | F47=% | G47=0.35 | H47=0.35 | I47=1
R48: B48=Tỷ lệ dự án đạt mục tiêu | C48=Dự án đạt được các chỉ số theo mục tiêu | E48=0.35 | F48=% | G48=0.7 | H48=0.7 | I48=1
R50: B50=KPI | C50=Junior | D50=Executive | E50=Senior
R51: B51=Doanh thu thuần | C51=300000000.0 | D51=500000000.0 | E51=1000000000.0
R52: B52=Tỷ lệ plan được chốt | C52=0.3 | D52=0.35 | E52=0.4
R53: B53=Tỷ lệ dự án đạt mục tiêu khi bắt đầu dự án | C53=0.6 | D53=0.7 | E53=0.8
R54: B54=Tỷ lệ renew dự án | C54=0.55 | D54=0.6 | E54=0.65
R55: A55=3. YÊU CẦU CÔNG VIỆC
R56: A56=Kiến thức chuyên môn | B56=1. Tốt nghiệp Đại học các chuyên ngành liên quan (MKT, Báo chí, Thương mại,  ngoại thương, ngôn ngữ,..)
2. Có ít nhất 02 năm kinh nghiệm ở vị trí tương đương (ưu tiên có kinh nghiệm trong ngành TMĐT, truyền thông, bán lẻ,..)  
3.  Kỹ năng lập kế hoạch và quản lý dự án tốt.  
R57: A57=Kỹ năng | B57=1. Kỹ năng lập kế hoạch
2. Nghiên cứu thị trường
3. Làm việc nhóm  
4. Tư duy sáng tạo
5. Kỹ năng viết
6. Kỹ năng thuyết phục, đàm phán
R58: A58=Yêu cầu khác | B58=1. Nữ, tuổi...
2. Kiên trì vì mục tiêu chung
3. Kỷ luật, trách nhiệm
R60: A60=4. CHÍNH SÁCH LƯƠNG
R61: A61=Lương cơ bản | B61=Lương KPI | D61=Commission | E61=Thưởng kinh doanh toàn công ty
R62: B62=Mức hoàn thành | C62=Mức thưởng | E62=Căn cứ:
- Theo DTT công ty
- Tỷ trọng từng sản phẩm, dịch vụ
- Tỷ trọng KH từ công ty/ sale
- Tỷ trọng tham gia của từng bộ phận trong quy trình vận hành
- Mức hoàn thành KPI cá nhân
R63: A63=14000000.0 | B63=<70% | C63=0.0
R64: B64=70% <= A < 85% | C64=1000000.0
R65: B65=85% <= A < 100% | C65=2000000.0
R66: B66=100% = A  | C66=3000000.0
R67: B67=Từ 100% trở lên tính theo tỷ lệ
R69: C69=Junior
R70: A70=Junior | B70=Mức hoàn thành KPI | C70=Lương KPI | D70=DTT tối thiểu tương ứng | E70=Thu nhập | F70=CP cố định 1 người | G70=Tổng CP/ DTT
R71: A71=12000000.0 | B71=0.69 | C71=0.0 | D71=500000.0 | E71=12000000 | F71=7532872.0 | G71=39.065744
R72: B72=0.7 | C72=1000000.0 | D72=1000000.0 | E72=13000000 | F72=7532872.0 | G72=20.532872
R73: B73=0.85 | C73=2000000.0 | D73=85714285.71 | E73=14000000 | F73=7532872.0 | G73=0.25121684
R74: B74=1.0 | C74=3000000.0 | D74=300000000 | E74=15000000 | F74=6882281.0 | G74=0.07294093667
R75: B75=1.2 | C75=6000000.0 | D75=585714285.7 | E75=18000000 | F75=5738139.0 | G75=0.04052853
R76: B76=1.5 | C76=10000000.0 | D76=1014285714 | E76=22000000 | F76=4871365.0 | G76=0.02649289507
R77: B77=2.0 | C77=15000000.0 | D77=1728571429 | E77=27000000 | F77=4871365.0 | G77=0.01843797975
R79: A79=Executive | B79=Mức hoàn thành KPI | C79=Lương KPI | D79=DTT tối thiểu tương ứng | E79=Thu nhập | F79=CP cố định 1 người | G79=Tổng CP/ DTT
R80: A80=15000000.0 | B80=0.69 | C80=0.0 | D80=500000.0 | E80=15000000 | F80=7532872.0 | G80=45.065744
R81: B81=0.7 | C81=0.0 | D81=1000000.0 | E81=15000000 | F81=7532872.0 | G81=22.532872
R82: B82=0.8 | C82=2000000.0 | D82=91836734.69 | E82=17000000 | F82=7532872.0 | G82=0.2671357173
R83: B83=0.9 | C83=3000000.0 | D83=295918367.3 | E83=18000000 | F83=5738139.413793104 | G83=0.08021854009
R84: B84=1.0 | C84=5000000.0 | D84=500000000 | E84=20000000 | F84=6882281.0 | G84=0.053764562
R85: B85=1.1 | C85=10000000.0 | D85=704081632.7 | E85=25000000 | F85=6205136.0 | G85=0.04432033809
R86: B86=1.2 | C86=15000000.0 | D86=908163265.3 | E86=30000000 | F86=5738139.0 | G86=0.03935210811
R88: A88=Senior | B88=Mức hoàn thành KPI | C88=Lương KPI | D88=DTT tối thiểu tương ứng | E88=Thu nhập | F88=CP cố định 1 người | G88=Tổng CP/ DTT
R89: A89=20000000.0 | B89=0.69 | C89=0.0 | D89=500000.0 | E89=20000000 | F89=7532872.0 | G89=55.065744
R90: B90=0.7 | C90=0.0 | D90=1000000.0 | E90=20000000 | F90=7532872.0 | G90=27.532872
R91: B91=0.8 | C91=2000000.0 | D91=47619047.62 | E91=22000000 | F91=7532872.0 | G91=0.620190312
R92: B92=0.9 | C92=7000000.0 | D92=523809523.8 | E92=27000000 | F92=7532872.0 | G92=0.065926392
R93: B93=1.0 | C93=15000000.0 | D93=1000000000 | E93=35000000 | F93=6882281.0 | G93=0.041882281
R94: B94=1.1 | C94=25000000.0 | D94=1476190476 | E94=45000000 | F94=6205136.0 | G94=0.03468735019
R95: B95=1.2 | C95=40000000.0 | D95=1952380952 | E95=60000000 | F95=5738139.0 | G95=0.03367075412
R98: A98=Senior
R99: A99=Phân bổ | B99=KPI | C99=Mô tả đo lường | D99=Trọng số nhóm | E99=Trọng Số Chi Tiết | F99=Đơn Vị tính | G99=Mức Tham Chiếu | H99=Thực Tế | I99=Tỷ Lệ Hoàn Thành | J99=Tổng KPI
R100: A100=Nội bộ | B100=Chi phí/ 1 CPA đạt mục tiêu | C100=Mess, lead, conversion... đạt kế hoạch đề ra (giá/ 1 CPA) | D100=0.3 | E100=1.0 | F100=% | G100=1000000.0 | H100=1000000.0 | I100=1 | J100=0.811
R101: A101=Khách hàng | B101=Doanh thu thuần | C101=Chỉ tính KH phát sinh DT trong tháng | D101=0.7 | E101=0.3 | F101=triệu | G101=1000000000.0 | H101=100000000.0 | I101=0.1
R102: B102=Tỷ lệ plan được chốt | C102=SL KH chốt/ tổng số lượng KH | E102=0.2 | F102=% | G102=0.4 | H102=0.4 | I102=1
R103: B103=Tỷ lệ dự án đạt mục tiêu | C103=Dự án đạt được các chỉ số theo mục tiêu | E103=0.3 | F103=% | G103=0.8 | H103=0.8 | I103=1
R104: B104=Tỷ lệ renew dự án | C104=Tỷ lệ khách hàng tái sử dụng dịch vụ | E104=0.2 | F104=% | G104=0.65 | H104=0.65 | I104=1


##### SHEET: CP thuê ngoài #####
R1: B1=Doanh thu (đã trừ thuê mẫu và thiết bị) | C1=Số lượng vid | D1=Tổng phí thuê editor | E1=Chi phí thuê/ 1 vid | F1=Tỷ lệ
R2: A2=Hiện tại | B2=47000000.0 | C2=25.0 | D2=3250000.0 | E2=130000 | F2=0.06914893617
R3: A3=Dự kiến | B3=112800000 | C3=60 | D3=18000000.0 | E3=300000.0 | F3=0.1595744681
```

## 7. Danh mục Job Description hiện có (22 file)

Nguồn: 22 file Excel JD đang dùng/đang tuyển của BC Agency (trừ 1 file mẫu trắng và 1 file checklist
công việc nội bộ, được ghi chú riêng ở cuối bảng). Format JD chuẩn của BC gồm 4 phần cố định:
**#. Thông tin chung → 1. Mô tả công việc → 2. Yêu cầu → 3. Quyền lợi → 4. Thông tin liên hệ**, cộng thêm
phần giới thiệu công ty lặp lại giống hệt nhau ở mọi JD (đã lược bỏ khỏi bảng dưới vì trùng lặp — xem mục 8
cho nội dung giới thiệu công ty).

| Chức danh                                      | Track/Bộ phận    | Báo cáo cho                     | Loại                          | Nhiệm vụ chính (tóm tắt)                                                                                                                           | Yêu cầu chính                                                                                   | Thu nhập tham khảo                                       |
| ----------------------------------------------- | ------------------ | --------------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Chuyên viên Account (Account Executive)       | KD — Account      | Trưởng phòng Bộ phận         | Full-time                      | Tìm kiếm/phát triển KH, tư vấn giải pháp, ký hợp đồng, quản lý & báo cáo hiệu quả chiến dịch, xử lý khiếu nại                   | ĐH Quản trị KD/Marketing, 1–3 năm KN agency/client-side, tiếng Anh thành thạo, có laptop  | 8–20tr+++ (lương theo doanh thu khi đạt KPI)          |
| Trưởng phòng kinh doanh (HCM — Remote)      | KD                 | Giám đốc                       | Full-time, remote              | Lập KH kinh doanh, phân bổ chỉ tiêu, quản lý KH & thị trường, quản lý/tuyển dụng đội ngũ KD, báo cáo Giám đốc                     | ĐH liên quan, 3–5 năm KN KD (≥2 năm quản lý nhóm)                                         | Lương cứng + hoa hồng, upto 100M++                     |
| Trưởng phòng kinh doanh (Hà Nội)           | KD                 | CEO                               | Full-time                      | Tương tự trên — phạm vi Hà Nội, thêm quyền đề xuất tuyển dụng/khen thưởng/kỷ luật                                                    | ĐH liên quan, 1–2 năm KN vị trí tương đương + thành tích dẫn dắt đội ngũ         | 20–25tr + %DT, TN upto 80M                                |
| Giám đốc kinh doanh                          | KD                 | CEO                               | Full-time                      | Chiến lược KD ngắn/trung/dài hạn, quản trị hệ thống KD, key account, quản lý tài chính/chi phí, xây tổ chức phòng KD                 | ĐH liên quan, ≥5 năm KN quản lý KD cấp cao                                                  | Lương cứng + hoa hồng, upto 150M++                     |
| Sale Team Lead                                  | KD                 | Giám đốc                       | Full-time                      | Tìm KH + quản lý/đào tạo team Sale (Intern/Fresher/Junior) + giám sát dự án KH                                                                | CĐ/ĐH liên quan, 1–2 năm KN sale/CSKH + có KN leader                                         | 15–30tr++ (theo KPI) + %DT team                           |
| Account Intern (chuyên Planner)                | KD/MKT — Account  | Trưởng nhóm                    | Full-time (intern)             | Hỗ trợ vận hành (plan, pitching), chuẩn hóa tài liệu đào tạo, hành chính bộ phận                                                         | Năm cuối/mới TN CĐ/ĐH Marketing, ưu tiên có KN MKT                                         | Hỗ trợ lương 3.000.000đ                               |
| Cộng tác viên Kinh doanh                     | KD                 | Trưởng Bộ phận / Sale Manager | Remote/Freelance               | Tìm & phát triển KH, quản lý & hỗ trợ KH, phối hợp kế toán công nợ                                                                         | 1 năm KN sale/telesale/CSKH                                                                       | 8tr – không giới hạn (theo hiệu quả + %hoa hồng)    |
| Nhân viên sàng lọc khách hàng tiềm năng | KD/CSKH            | Trưởng Bộ phận                | Part-time, theo ca             | Trực page/hotline, phân loại KH từ data quảng cáo, CSKH cũ, remarketing                                                                          | Sinh viên ĐH/CĐ, không yêu cầu KN, tiếng Anh cơ bản                                       | 2.000.000–4.000.000đ                                     |
| Account MKT                                     | MKT — Account     | Giám đốc                       | Full-time                      | Tiếp nhận brief, tư vấn giải pháp branding/MKT, viết proposal, quản lý dự án đa kênh, báo cáo hiệu quả                                 | ĐH liên quan, 1–2 năm KN Marketing/Planner/Account, hiểu digital ads (Meta/Google/GDN/TikTok) | 10–13tr (theo năng lực)                                 |
| MKT Planner                                     | MKT                | Giám đốc                       | Full-time                      | Strategic planning, viết proposal (insight-strategy-idea-media plan-KPI-budget), triển khai & theo dõi chiến dịch                                  | ĐH liên quan, 2–3 năm KN Marketing/Planner/Account, đọc hiểu ROAS/ROI/CPM/CPA/CTR           | 13–17tr (lương cứng + KPI + %hoa hồng)                |
| Marketing Teamlead                              | MKT — Branding    | Giám đốc                       | Full-time                      | Xây thương hiệu nội bộ BC, tư vấn/triển khai dự án branding cho KH, quản lý team Marketing                                                 | ĐH liên quan, 2–3 năm KN Marketing/Branding/Account, đọc hiểu chỉ số MKT                  | 15–18tr (theo năng lực, KPI)                            |
| Marketing Manager                               | MKT                | Giám đốc                       | Full-time                      | Chiến lược Marketing tổng thể, MKT nội bộ (brand BC quốc tế), quản lý nhân sự/ngân sách phòng, điều phối dự án Performance của KH | ĐH liên quan, ≥5 năm KN Marketing (≥2 năm quản lý tại agency)                             | 25–30tr+++ (theo năng lực, KPI)                         |
| Digital Marketing Executive                     | MKT — Performance | Giám đốc Công nghệ           | Full-time (+ online T7)        | Triển khai dự án Digital Marketing (TikTok/FB/Google/Bing), lên KH & tối ưu campaign theo KPI, tư vấn hỗ trợ KH dùng TKQC                    | ĐH Marketing/CNTT/kỹ thuật, ≥1 năm KN chạy Ads 1 trong 3 nền tảng                          | KHÔNG GIỚI HẠN, TB 12–20tr (lương cứng + hoa hồng) |
| Nhân viên Content Marketing                   | MKT — Content     | Trưởng Bộ phận                | Full-time                      | Lập KH nội dung định kỳ, sản xuất content social/blog, kiểm duyệt nội dung ads cho KH, phối hợp Account/Planner                             | ĐH liên quan, ≥6 tháng KN Content Marketing                                                    | 7–10tr                                                    |
| Thực tập sinh Content MKT (TTS content)       | MKT — Content     | Trưởng nhóm                    | Full-time/Part-time linh hoạt | Content tuyển dụng/văn hóa nội bộ trên FB & TikTok, hoặc content dự án KH, edit video CapCut cơ bản, thiết kế đơn giản                 | SV năm 4/mới TN Marketing/Truyền thông                                                         | Hỗ trợ lương 3.500.000–4.000.000đ                    |
| Nhân viên Designer                            | MKT — Creative    | Trưởng Bộ phận                | Full-time                      | Thiết kế ảnh/ấn phẩm digital & in ấn, logo/nhận diện thương hiệu, edit video cơ bản                                                        | CĐ/ĐH Thiết kế/Marketing, ≥1 năm KN thiết kế tại agency, thạo Ai/Ps                      | 10–12tr (theo năng lực)                                 |
| CTV Content                                     | MKT — Content     | Trưởng Bộ phận                | Remote                         | Viết bài theo yêu cầu, phối hợp design/account/planner sản xuất nội dung                                                                       | Không yêu cầu bằng cấp/KN, ưu tiên có KN Content agency                                    | Thỏa thuận theo sản phẩm/bài viết                    |
| CTV Designer                                    | MKT — Creative    | Trưởng Bộ phận                | Remote                         | Thiết kế sản phẩm digital, edit video/ấn phẩm media theo yêu cầu                                                                                | Không yêu cầu bằng cấp, ưu tiên có KN thiết kế/edit                                      | Thỏa thuận theo sản phẩm                               |
| Nhân viên HCNS                                | HR                 | Trưởng Bộ phận                | Full-time                      | Tuyển dụng (lập KH, sourcing, tracking, báo cáo), truyền thông thương hiệu tuyển dụng, đào tạo, văn hóa nội bộ                       | ĐH Quản trị nhân lực/Kinh tế/QTKD, 2 năm KN HCNS/tuyển dụng                               | 9–10tr + KPI (TN 10–12tr)                                |
| Kế toán nội bộ                              | Kế toán          | Giám đốc                       | Full-time                      | Kiểm soát giao dịch KH/đối tác, đối soát doanh thu các mảng, tổng hợp & xử lý chi phí, báo cáo thu chi                                | CĐ/ĐH Kế toán/Kiểm toán, 1.5–2 năm KN tương đương                                     | 9–10tr LC + KPI (10–12tr gross)                          |

**2 file bổ sung (không phải JD cá nhân):**

- `BC - JD mẫu.xlsx` — **template JD chuẩn** (sheet "CVQLKH" trống hoàn toàn để điền mới; sheet "Performance
  Digital Marketing E" trùng nội dung với JD "Digital marketing (nháp)"). Dùng làm khuôn mẫu khi HR tạo JD mới —
  nên map trực tiếp thành form tạo JD trong TMS (field giống hệt cấu trúc 4 phần đã nêu ở đầu mục 7).
- `Danh mục công việc PKD - Hạnh.xlsx` — **checklist nhiệm vụ nội bộ của Trưởng phòng KD** (không phải JD tuyển
  dụng): 6 nhóm việc (Kế hoạch KD, Quản trị hệ thống & vận hành, Quản lý tài chính & chi phí, Quản lý nhân sự KD,
  Văn hóa & định hướng tổ chức), một số dòng có gắn người phụ trách cụ thể (Ms. Trang, Ms. Ngọc). Đây là nguồn
  tham khảo tốt cho việc thiết kế entity `job_task_checklist` hoặc RACI theo vai trò quản lý.

**Ghi chú chung mọi JD:** tất cả áp dụng chung 1 bộ Quyền lợi cơ bản (không lặp lại trong bảng trên):
du lịch năm trong/ngoài nước, CLB thể thao offline cuối tuần, hỗ trợ gửi xe, quà Lễ/Tết/sinh nhật, BHXH/nghỉ
phép/nghỉ lễ theo quy định, happy hour chiều thứ 6. Địa điểm làm việc chuẩn: Tầng 2, CT3, Chung cư X2, đường
Trần Hòa, Đại Kim – Hoàng Mai – Hà Nội (8h00–17h30, nghỉ trưa 12h00–13h30, một số vị trí HCM làm remote).

## 8. Văn hóa — Nội quy — Phúc lợi (Welcome Deck 2026, 31 slide)

### Giới thiệu công ty

- **BC Agency (Brand Companion Agency)**: công ty truyền thông quảng cáo đa quốc gia, 3 văn phòng —
  Việt Nam, Cambodia, Hong Kong.
- Thành lập **26/09/2020**; 10/2023 trở thành **TikTok Marketing Partner** & **TikTok Shop Partner**; 5+ năm kinh nghiệm.
- Sứ mệnh: đồng hành cùng doanh nghiệp tháo gỡ vấn đề, biến ngân sách Marketing thành tăng trưởng thực chất.
- Tầm nhìn: trở thành Agency tăng trưởng hàng đầu nhờ tư duy chiến lược may đo, năng lực phân tích dữ liệu, minh bạch kết quả.
- Giá trị cốt lõi: **TÍN – Uy Tín · TÂM – Tận Tâm · TRÍ – Trí Tuệ · NHÂN – Con Người**.

### Giờ làm việc

Sáng 08h30–12h00 · Nghỉ trưa 12h00–13h00 · Chiều 13h00–17h30 (lưu ý: một số JD ghi 08h00–17h30, nghỉ trưa
12h00–13h30 — **có sai lệch giữa 2 tài liệu**, cần Nam xác nhận giờ chuẩn khi build entity `work_schedule`).

### Quy định đăng ký nghỉ phép / công tác

| Nội dung                   | Quy định thông báo trước | Phê duyệt                  |
| --------------------------- | ------------------------------ | ---------------------------- |
| Nghỉ buổi Sáng/Chiều    | ½ ngày                       | Quản lý trực tiếp + HCNS |
| Nghỉ 1 – dưới 3 ngày   | ≥1 ngày                      | Quản lý trực tiếp + HCNS |
| Nghỉ từ 3 ngày trở lên | ≥4 ngày                      | Quản lý trực tiếp + HCNS |
| Đi công tác              | 2 tiếng                       | Quản lý trực tiếp + HCNS |

Ngày làm việc không tính T7/CN/Lễ Tết. Nghỉ hết phép → không được duyệt đơn xin nghỉ riêng trừ bất khả kháng
(ốm đau có chứng minh, gia đình có tang sự).

### Chế tài xử phạt

**Đi muộn/về sớm (Nhân viên, Intern vận hành):**

| Thời gian đi muộn/về sớm | Mức phạt                    |
| ----------------------------- | ----------------------------- |
| ≤5 phút                     | 0đ                           |
| 6–10 phút                   | 20.000đ                      |
| 11–30 phút                  | 30.000đ                      |
| 31–45 phút                  | 50.000đ                      |
| 46–60 phút                  | 70.000đ                      |
| Từ 61 phút                  | ½ ngày công                |
| Đi muộn lần thứ 4/tháng  | x2 mức phạt theo mốc trên |

**Quên chấm vân tay:** 2 lần đầu/tháng — có HCNS xác nhận đến/về đúng giờ: không áp dụng chế tài, vẫn tính công;
có xác nhận đi làm nhưng muộn/sớm: áp dụng chế tài đi muộn. Từ lần thứ 3: không tính công buổi/ngày đó.

**Nghỉ không phép:** ≥2 lần (buổi/ngày) không phép/tháng → cảnh cáo – đình chỉ. ≥5 ngày không phép/tháng →
chấm dứt HĐLĐ. Công tác quên đăng ký: 3 lần đầu nhắc nhở, từ lần thứ 4 phạt 100.000đ.

**Cấp Quản lý:** nhân đôi (x2) mọi mức chế tài trên. **Intern Kinh doanh:** không áp dụng chế tài. Toàn bộ
tiền phạt nộp quỹ công ty, dùng cho hoạt động chung/phúc lợi.

### Chính sách thu nhập

Khấu trừ 10% thuế TNCN mỗi tháng với vị trí Hợp đồng Thử việc và Hợp đồng Học việc.

### Thưởng Lễ – Tết hàng năm

| Dịp                             | Mức thưởng                                   |
| -------------------------------- | ----------------------------------------------- |
| Tết Dương lịch 01/01         | 300.000đ/người                               |
| Tết Nguyên đán               | Theo chính sách công ty                      |
| Quốc tế phụ nữ 8/3           | Quà hoặc 200.000đ (nữ)                      |
| QT thiếu nhi 1/6                | Quà hoặc 200.000đ/cháu (con CBNV <15 tuổi) |
| 30/4 & 1/5                       | 300.000đ/người                               |
| Quốc khánh 2/9                 | 300.000đ/người                               |
| Tết Trung thu                   | Quà tặng gia đình mỗi nhân sự            |
| Sinh nhật                       | 300.000đ/người                               |
| Ngày phụ nữ 20/10             | Quà hoặc 200.000đ (nữ)                      |
| Ngày Quốc tế đàn ông 19/11 | Quà hoặc 200.000đ (nam)                      |
| Ngày văn hóa VN 24/11         | (chưa ghi rõ mức)                            |

Nhân viên Thử việc & Chính thức hưởng đầy đủ các chế độ trên. Intern hưởng tất cả trừ chế độ Sinh nhật.

### Chính sách giới thiệu nhân sự (Referral)

| Vị trí          | Mức thưởng          | Lịch thanh toán                                                             |
| ----------------- | ---------------------- | ----------------------------------------------------------------------------- |
| Sale Intern       | 1.000.000đ/ứng viên | 30% sau 1 tháng đi làm · 30% sau 3 tháng · 40% khi ký HĐ chính thức |
| Nhân viên Sale  | 2.000.000đ/ứng viên | 30% khi bắt đầu đi làm · 70% khi ký HĐ chính thức                   |
| Account Marketing | 3.000.000đ/ứng viên | 30% khi bắt đầu đi làm · 70% khi ký HĐ chính thức                   |

*(Slide 5–13, 17–22 của deck chủ yếu là hình ảnh minh họa dịch vụ/hoạt động văn hóa, không có nội dung text
trích xuất được — nếu cần, có thể xem trực tiếp file gốc.)*

## 9. Đề xuất mô hình dữ liệu (entity) cho module TMS

Gợi ý ban đầu dựa trên toàn bộ dữ liệu ở trên — **cần Nam review lại trước khi đưa vào schema.prisma thật**,
vì đây là suy luận từ tài liệu nghiệp vụ, chưa phải quyết định thiết kế chính thức.

| Nhóm                 | Entity gợi ý                                                                                                                                                                                                   | Nguồn gốc trong tài liệu                                                                                           |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Tổ chức             | `department`, `career_track` (KD/BO/HR/MKT), `career_level` (KD-1..5, BO-1..4, HR-1..4, MK-1..4)                                                                                                           | Mục 4 — cần đối chiếu với role taxonomy PMS                                                                     |
| Tuyển dụng          | `headcount_plan`, `recruitment_request` (phiếu nhu cầu nhân sự), `job_description`, `candidate`, `interview_scorecard`, `reference_check`, `offer`, `preboarding_checklist`, `talent_pool` | Templates`t1_0`, `t1_0m`, `t1_1`, `t1_2`, `t1_3`, `t1_3q`, `t1_4`, `t1_5`, `t1_6`, `t_talent_pool` |
| Onboarding            | `onboarding_checklist` (Day 1), `training_plan_15_30_60_90`, `probation_review` (mốc 30/60)                                                                                                               | `t2_1`, `t2_2`, `t2_3`, `t2_4`                                                                                 |
| Hiệu suất           | `checkin_monthly`, `performance_review` (quý/6T/năm), `idp` (individual dev plan), `pip`                                                                                                               | `t3_1`, `t3_3`, `t3_q`, `t3_6m`, `t_annreview`, `t3_4`, `t_pip`                                          |
| Lương thưởng      | `salary_band`, `salary_policy` (theo career_level, gồm KPI weight + commission tier), `salary_review`, `promotion_record`, `contract_addendum`                                                        | Mục 5, 6,`t_salband`, `t_promo`, `t_promo_rec`, `t_addendum`                                                  |
| Gắn kết & văn hóa | `stay_interview`, `engagement_survey` (eNPS), `culture_activity`, `culture_feedback`, `recognition_record`, `buddy_assignment`, `internal_mobility_opportunity`                                    | `t3_2`, `t3_5`, `t_culture_plan`, `t_culture_fb`, `t_recognition`, `t_buddy`, `t3_mob`                   |
| Nghỉ việc           | `exit_interview`, `handover_checklist`, `it_asset_return`, `alumni`                                                                                                                                      | `t3_6`, `t3_7`, `t3_handover`, `t3_well`, `t_it_asset`, `t_alumni`                                         |
| Vận hành HR         | `referral_bonus`, `hr_dashboard_metric`, `hr_budget`, `leave_request`, `attendance_violation`                                                                                                          | Mục 6 (referral),`t_hr_dash`, `t_hr_budget`, mục 8 (nghỉ phép, chế tài)                                      |

**Điểm cần làm rõ với Nam trước khi thiết kế schema chính thức:**

1. Role taxonomy PMS (42 role/13 track) vs. Career track TMS (KD/BO/HR/MKT, 4 track) — có map 1-1 được không,
   hay TMS cần một bảng `career_track` hoàn toàn riêng chỉ dùng cho lương/thăng tiến?
2. Giờ làm việc lệch nhau giữa Welcome Deck (08h30–17h30) và JD (08h00–17h30, nghỉ trưa 12h00–13h30).
3. Công thức tính hoa hồng trong file Excel là **bảng tra cứu theo Level** (không phải công thức liên tục) —
   cần quyết định: TMS lưu bảng tra cứu tĩnh theo `career_level` + `month`, hay implement công thức động?
4. Salary Band (mục 5) là **band tham khảo thị trường** (generic theo track/level), còn dữ liệu Excel mục 6
   là **bảng lương/hoa hồng thực tế đang áp dụng** theo từng vị trí cụ thể — hai nguồn này có thể lệch nhau,
   cần API/dữ liệu để đối chiếu định kỳ (Q4 theo quy trình `t_salband`).

---

*Tài liệu này tổng hợp từ 4 nguồn nêu ở mục 1, do Claude trích xuất và biên tập ngày 2026-09-12. Số liệu
lương/KPI/JD phản ánh đúng nguyên bản các file gốc tại thời điểm trích xuất — khi các file gốc được cập nhật,
cần tạo lại phiên bản mới của tài liệu này (đặt tên `HR_ERP_HARNESS_v2.md`, ... theo đúng quy ước versioning
hiện tại của dự án).*
