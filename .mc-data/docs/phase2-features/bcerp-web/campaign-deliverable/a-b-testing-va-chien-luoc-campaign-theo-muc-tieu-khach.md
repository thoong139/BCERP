# Tính Năng: A/B Testing & Chiến Lược Campaign Theo Mục Tiêu Khách

> **Dựa trên:** REQ-OPS-012 trong `phase1-business/departments/operations/operations.md` (Phần A — Mục A3/B.10)
> **Phân hệ:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** Campaign & Deliverable (MOD-CAMPAIGN-DELIVERABLE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase1-business/P1-02-business-workflow.md` (§3.3 — B5/B6 Luồng 3), `documents/quy-trinh-lam-viec/` (nguồn v2.3 — sample size, SLA creative), `phase0-brainstorm/policies/hop-dong-loi-nda-brand-safety.md` (§2.5 — không cam kết KPI cứng)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/campaign-deliverable/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/campaign-deliverable/feat-erp-camp-002-impl.md`
>
> **Fan-out:** REQ-OPS-012 xuất hiện ở 4 systems (SYS-CORE-BACKEND, SYS-INTEGRATION-GW, SYS-BCERP-WEB, SYS-MOBILE-INTERNAL) — đây là bản riêng cho SYS-BCERP-WEB (WEB là touchpoint thiết kế/đọc kết quả: form đăng ký thí nghiệm, dashboard kết quả theo variant, nút kết luận bắt buộc evidence, thư viện learning/playbook; dữ liệu hiệu quả theo variant lấy từ GW). Counterparts: SYS-CORE-BACKEND (đối tượng thử nghiệm, tổng hợp KPI theo variant, chặn chi ngân sách khi chưa đăng ký), SYS-INTEGRATION-GW (dữ liệu hiệu quả theo variant từ API nền tảng — nhãn `manual` khi degraded), SYS-MOBILE-INTERNAL (thông báo duyệt/kết quả/đề xuất dừng variant cho OPS_ADS). Business rule enforce ở tầng service layer của CORE; WEB render form/list/workflow UI và hiển thị đúng trạng thái machine-state.
>
> **Hướng dẫn ID:** FEAT-ERP-CAMP-002 là ID lane cấp cho REQ-OPS-012 trên module MOD-CAMPAIGN-DELIVERABLE (tra `req-registry.json` để xác nhận).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-CAMP-002 |
| Module | MOD-CAMPAIGN-DELIVERABLE |
| Yêu cầu nghiệp vụ | REQ-OPS-012 — A/B Testing & chiến lược campaign theo mục tiêu khách |
| Người dùng liên quan | OPS_ADS (đăng ký, vận hành, đề xuất kết luận), OPS_PLAN (duyệt chiến lược, đánh giá overlap, review playbook), OPS_AM (cập nhật khách), OPS_CONT, OPS_DES, OPS_EDIT (sản xuất creative theo variant) |
| Độ ưu tiên | Trung bình |
| Giai đoạn | Giai đoạn 2 (thiết kế thử nghiệm gắn campaign) → Giai đoạn 3 (phân tích chéo đầy đủ) |
| Phụ thuộc | FEAT-ERP-CAMP-001 (campaign change log bất biến + WBS/deliverable — mọi thay đổi ngân sách trong thử nghiệm đi qua change log); REQ-OPS-005 (chiến lược gắn campaign thuộc dự án theo stage-gate V6.0); REQ-OPS-008 (SLA engine áp cho nhắc hạn/thời lượng) |
| Ghi chú Expert (A7) | A7 của `operations.md` đang chờ Team Expert review; spec này giữ nguyên ranh giới liên REQ đã khai báo ở Phần B: CORE quản đối tượng thử nghiệm + chặn chi ngân sách, GW cấp dữ liệu variant (nhãn `manual` khi degraded), WEB là nơi thiết kế và đọc kết quả — WEB không tự tính significance. |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng cho phép OPS_ADS **đăng ký và vận hành thử nghiệm A/B gắn chiến dịch theo đúng mục tiêu khách** (conversion / traffic / awareness) trên BCERP Web nội bộ: soạn đăng ký đầy đủ giả thuyết — KPI chính — variant — audience — thời lượng — ngân sách, trình OPS_PLAN duyệt trước khi triển khai, theo dõi kết quả theo variant từ dữ liệu nền tảng (qua GW) và kết luận thắng/thua bắt buộc kèm evidence gắn change log. Mục tiêu cuối là biến mỗi thí nghiệm thành learning log tái sử dụng được theo khách/ngành, đưa chiến lược campaign về đúng mục tiêu khách thay vì cảm tính.

**Phạm vi:**
- Bao gồm:
  - Form đăng ký thí nghiệm: giả thuyết, metric chính duy nhất theo mục tiêu khách, danh sách variant, audience định nghĩa rõ, thời lượng, ngân sách, sample size dự kiến — thiếu trường không lưu được; trình duyệt OPS_PLAN.
  - Bản đồ thí nghiệm đang chạy theo khách: hiển thị segment audience của từng thí nghiệm active, cảnh báo chồng chéo trước khi đăng ký mới.
  - Dashboard kết quả theo variant: KPI theo variant từ GW (nhãn `manual` + nguồn + timestamp khi degraded), tiến độ sample so với ngưỡng, đề xuất dừng/khai thắng khi đạt ngưỡng đã chốt.
  - Nút kết luận (win / lose / no signal) bắt buộc evidence: số KPI theo variant, thời gian chạy, sample đạt — tạo entry change log gắn evidence; hết duration thiếu sample tự đề xuất "no signal".
  - Điều chỉnh ngân sách trong thử nghiệm: gọi form change log bất biến của FEAT-ERP-CAMP-001 (phân bậc buyer → TL → AM).
  - Thư viện learning log theo khách/ngành + soạn/cập nhật playbook chiến lược (content brief, cấu trúc campaign, audience playbook) — review quý bởi OPS_PLAN.
  - Chiến lược campaign theo mục tiêu khách: mapping objective (conversion/traffic/awareness) vào cấu trúc campaign và KPI đo mặc định từ playbook.
- Không bao gồm:
  - Đối tượng thử nghiệm, kiểm tra overlap audience, chặn chi ngân sách thí nghiệm chưa đăng ký, tổng hợp KPI theo variant — thực thi ở SYS-CORE-BACKEND.
  - Kéo dữ liệu hiệu quả theo variant từ API nền tảng — thuộc SYS-INTEGRATION-GW; chưa có quyền API developer thì dữ liệu gắn nhãn `manual` (DI-007).
  - Push thông báo duyệt/kết quả/đề xuất dừng variant — thuộc SYS-MOBILE-INTERNAL (counterpart).
  - Workflow change log engine và pipeline duyệt creative đầy đủ — thuộc FEAT-ERP-CAMP-001; tính năng này gọi và hiển thị, không tái định nghĩa.
  - Cam kết KPI đầu ra cho khách — bị chặn tuyệt đối (xem BR-008); hợp đồng chỉ cam kết đầu vào.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_ADS | Đăng ký thí nghiệm A/B gắn campaign với đủ giả thuyết, KPI chính, variant, audience, thời lượng, ngân sách | Thí nghiệm có giấy phép chạy rõ ràng, không ai chê "chạy cảm tính" sau này |
| 2 | OPS_ADS | Bị chặn lưu đăng ký khi thiếu bất kỳ trường bắt buộc nào | Đăng ký bẩn không lọt vào hệ thống, không phải sửa dở dang sau khi chi tiền |
| 3 | OPS_PLAN | Xem đăng ký mới cạnh bản đồ thí nghiệm active cùng khách để đánh giá overlap audience | Duyệt thí nghiệm mà không tạo giao thoa làm bẩn dữ liệu cả hai |
| 4 | OPS_PLAN | Duyệt/từ chối thí nghiệm kèm nhận xét chiến lược ngay trong ngữ cảnh mục tiêu khách | Chiến lược campaign bám mục tiêu khách (conversion/traffic/awareness), không chạy trôi |
| 5 | OPS_ADS | Xem dashboard KPI theo variant kèm tiến độ sample so với ngưỡng ≥20% / ≥50 clicks / ≥10 conversions | Biết lúc nào đủ dữ liệu để kết luận, không đoán sớm |
| 6 | OPS_ADS | Bấm kết luận thắng/thua chỉ khi hệ thống đã có đủ evidence gắn change log | Mỗi kết luận đối chiếu ngược được về số liệu gốc thời điểm đó |
| 7 | OPS_AM | Xem tóm tắt kết quả thí nghiệm theo ngôn ngữ mục tiêu khách để cập nhật khách | Báo cáo khách nhất quán với dữ liệu hệ thống, không phải tổng hợp tay |
| 8 | OPS_CONT | Xem variant thắng và learning log gắn deliverable mình phụ trách | Brief nội dung kế tiếp áp đúng điều đã được chứng minh |
| 9 | OPS_ADS | Khi hết thời lượng mà chưa đủ sample, được hệ thống ghi "no signal" và đề xuất gia hạn/dừng có lý do | Kết luận trung thực thay vì khai thắng tùy tiện |
| 10 | OPS_PLAN | Rà learning log theo quý và cập nhật playbook/template chiến lược thành mặc định cho proposal mới | Bài học từng khách/ngành trở thành chuẩn vận hành, không nằm trong đầu từng người |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code (validation cứng ở tầng service CORE; WEB khóa thao tác theo kết quả). Nguồn: `operations.md` B.10; số liệu sample size/SLA/vòng sửa/nghiệm thu đã chốt theo DI-005 (12/09/2026) — ưu tiên hơn mốc `[CẦN CHỐT SỐ]` cũ.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Đăng ký trước — chạy sau:** thí nghiệm bắt buộc gắn campaign và đủ trường: giả thuyết, **metric chính duy nhất** theo mục tiêu khách (conversion/traffic/awareness), variant, audience định nghĩa rõ, thời lượng, ngân sách, sample size dự kiến; OPS_PLAN duyệt trước khi triển khai. Thí nghiệm không đăng ký không được chi ngân sách. | CORE chặn chi tiêu theo campaign gắn thử nghiệm chưa ACTIVE; WEB không lưu đăng ký thiếu trường, chỉ ra đúng field còn thiếu |
| BR-002 | **Ngưỡng khai thắng đã chốt (DI-005):** winner chỉ được khai khi chênh lệch **≥20%** trên metric chính **và** sample đạt **≥50 clicks hoặc ≥10 conversions**; confidence nội bộ dùng khung đề xuất 95% `[CẦN CHỐT SỐ: confidence + ngưỡng significance nội bộ — chưa chốt chính thức, cấu hình được, không chặn thiết kế]`. | Nút kết luận "WIN" vô hiệu khi chưa đạt đồng thời 2 điều kiện; hệ thống hiển thị khoảng cách còn thiếu |
| BR-003 | **Chống giao thoa audience:** trên cùng một audience/tenant khách, mỗi thời điểm chỉ **1 thí nghiệm active**; đăng ký mới trùng segment với thí nghiệm đang chạy → chặn, bắt buộc chọn audience loại trừ (exclusion) hoặc chờ kết thúc. Exception: platform khác nhau nhưng cùng tệp mục tiêu → OPS_PLAN đánh giá rủi ro giao thoa rồi mới duyệt, ghi lý do. | Đăng ký trùng segment vào trạng thái BLOCKED_OVERLAP; exception không có lý do không được duyệt |
| BR-004 | **Kết luận bắt buộc evidence trên change log:** dừng variant/khai thắng chỉ khi đạt ngưỡng BR-002; kết luận (win/lose/no signal) tạo entry change log gắn evidence: số KPI theo variant, thời gian chạy, sample đạt. Kết thúc duration mà chưa đủ sample → kết luận "no signal" + quyết định gia hạn/dừng có lý do. | Không có đường kết luận không evidence; entry change log append-only, đối chiếu ngược về dữ liệu gốc |
| BR-005 | **Campaign & deliverable theo WBS:** deliverable phục vụ từng variant (creative, landing copy) bắt buộc gắn WBS node của dự án; task mồ côi không được tính công — cùng cơ chế FEAT-ERP-CAMP-001. | Không tạo được deliverable variant thiếu WBS node; capacity check bắt buộc trước gán |
| BR-006 | **Creative SLA theo tier cho creative variant:** duyệt nghiệp vụ AM 2h (video dài 4h, trend gấp 1h), content self-QC + Lead review 4h (chốt DI-005); áp theo ma trận tier × priority của khách — HĐ cam kết cao hơn ghi đè theo profile; tối đa 3 vòng sửa nội bộ, vòng 4 escalate AM chốt phạm vi. | SLA từng bước đếm trên từng creative variant; quá SLA nhắc, chậm 2 bước liên tiếp escalate TL; vòng 4 không escalate không nộp được |
| BR-007 | **Mọi thay đổi ngân sách trong thử nghiệm qua change log bất biến (BR-OPS-7.4):** thêm/giảm ngân sách variant, kéo dài thời lượng ảnh hưởng chi tiêu — bắt buộc reason, lưu giá trị cũ/mới, ai, khi nào; phân bậc duyệt buyer → TL → AM theo hạn mức cấu hình. Exception khẩn cấp pause trước — bổ sung reason trong 4h làm việc. | Form ngân sách của thí nghiệm gọi chung change log engine; thiếu reason bị từ chối tầng API |
| BR-008 | **Không cam kết KPI cứng cho khách ngoài hợp đồng** — chỉ cam kết đầu vào (khớp `hop-dong-loi-nda-brand-safety.md` §2.5); kết quả thí nghiệm báo khách như thông tin minh bạch, không phải bảo hành kết quả. | Template báo cáo khách không có trường "cam kết đạt KPI"; AM thấy cảnh báo khi soạn nội dung hứa hẹn kết quả |
| BR-009 | **TikTok Shop tách bạch GMV:** khi thí nghiệm/campaign liên quan TikTok Shop, GMV/settlement là chỉ số tham chiếu thuộc về khách — chặn mọi mapping vào doanh thu agency; không dùng GMV làm KPI chứng minh doanh thu của BC. | Không có đường nhập GMV vào trường doanh thu/KPI doanh thu; báo cáo tách hai nhóm chỉ số |
| BR-010 | **Portal/mobile khách chỉ thấy phần đã share, tenant isolation:** nếu AM chia kết quả thí nghiệm cho khách (phần tóm tắt theo milestone), khách chỉ thấy nội dung được share trong tenant của mình — không thấy audience raw, giá vốn, ghi chú nội bộ; nghiệm thu milestone chứa deliverable thí nghiệm giữ nguyên quy trình 3 ngày làm việc — nhắc ngày 2 — escalate ngày 4 — không "im lặng = đồng ý" (BR-OPS-7.5, chốt DI-005; escalate AD route quản lý tuyến `[KXN-19]`). | Truy vấn portal lọc bắt buộc theo `tenant_id` + `share_scope`; milestone không tự nghiệm thu khi hết hạn chờ |
| BR-011 | **Learning log + playbook:** OPS_ADS ghi learning log theo khách/ngành ngay khi kết luận, gắn thí nghiệm + change log entry; mỗi quý OPS_PLAN rà learning log → cập nhật playbook/template chiến lược (content brief, cấu trúc campaign, audience playbook) thành mặc định cho proposal mới; cập nhật template là thay đổi chính sách nội bộ — có log + OPS_PLAN duyệt. | Learning không gắn evidence không tính vào playbook review; cập nhật playbook thiếu log/duyệt bị từ chối |
| BR-012 | **Dữ liệu degraded gắn nhãn `manual`:** khi GW chưa có quyền API developer (DI-007), dữ liệu hiệu quả theo variant nhập tay gắn nhãn `manual` + nguồn + timestamp; kết luận trên dữ liệu `manual` bắt buộc ghi chú nguồn vào evidence. | Dashboard phân biệt rõ dữ liệu API và `manual`; kết luận không ghi nguồn dữ liệu `manual` không lưu được |

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry. REQ-OPS-012 không có bản portal (khách không thao tác trực tiếp trên tính năng này; trường hợp share kết quả tuân BR-010).

| Hành động | OPS_CONT/DES/EDIT | OPS_ADS | OPS_AM | OPS_PLAN | SYS_ADMIN |
|-----------|-------------------|---------|--------|----------|-----------|
| Đăng ký thí nghiệm A/B | ❌ | ✅ | ❌ | ❌ | ❌ |
| Duyệt/từ chối thí nghiệm | ❌ | ❌ | ❌ | ✅ | ❌ |
| Đánh giá exception overlap (platform khác, cùng tệp) | ❌ | ❌ | ❌ | ✅ (ghi lý do) | ❌ |
| Sản xuất creative theo variant | ✅ (theo task được gán) | ❌ | ❌ | ❌ | ❌ |
| Duyệt creative variant | ❌ | ❌ | ✅ | ✅ | ❌ |
| Thay đổi ngân sách/thời lượng thí nghiệm | ❌ | ✅ (trong hạn mức, có reason) | ✅ (vượt hạn mức dự án) | ✅ (vượt hạn mức ngày) | ❌ |
| Xem dashboard kết quả theo variant | ✅ (variant gắn deliverable mình) | ✅ | ✅ (khách mình) | ✅ (toàn bộ) | ❌ |
| Đề xuất/kết luận win/lose/no signal | ❌ | ✅ (bắt buộc evidence) | ❌ | ✅ (xác nhận khi thay đổi chiến lược) | ❌ |
| Ghi learning log | ❌ | ✅ | ✅ (bổ sung góc độ khách) | ✅ | ❌ |
| Soạn/cập nhật playbook chiến lược | ❌ | ✅ (đề xuất) | ❌ | ✅ (duyệt — thay đổi chính sách) | ❌ |
| Chỉnh sửa/sửa kết quả đã kết luận | ❌ | ❌ | ❌ | ❌ | ❌ |

**Ghi chú:** SYS_ADMIN chỉ truy cập kỹ thuật có audit log, không thao tác nghiệp vụ. Quyền "khách mình" là row-level scoping theo assignment khách — AM chỉ thấy thí nghiệm của khách mình phụ trách (CORE enforce). Nút kết luận của OPS_ADS là đề xuất có evidence; khi kết luận kéo theo thay đổi chiến lược/ngân sách, luồng đi qua phân bậc duyệt change log (BR-007).

---

## 5. Trường Hợp Đặc Biệt

- **Hết thời lượng mà chưa đủ sample:** hệ thống tự đóng đề xuất kết luận "no signal" kèm số sample đạt; OPS_ADS chọn gia hạn (qua change log có reason) hoặc dừng — không được khai thắng khi thiếu ngưỡng BR-002.
- **Hai nền tảng, một tệp mục tiêu:** thí nghiệm Meta và TikTok cùng nhắm một tệp khách — mặc định chặn như overlap; OPS_PLAN có thể duyệt exception sau khi đánh giá rủi ro giao thoa, bắt buộc lý do ghi trên đăng ký.
- **GW degraded (chưa có quyền API developer):** KPI theo variant nhập tay từ xuất khẩu nền tảng, gắn nhãn `manual` + nguồn + timestamp; dashboard hiển thị rõ dữ liệu thủ công; kết luận vẫn hợp lệ nhưng evidence bắt buộc ghi nguồn (DI-007).
- **Thí nghiệm dừng giữa chừng vì die account / brand safety:** pause theo quy trình khẩn cấp của FEAT-ERP-CAMP-001 (pause trước, reason trong 4h LV); thí nghiệm chuyển NO_SIGNAL, không tính vào learning "thua" — ghi nguyên nhân kỹ thuật.
- **Khách yêu cầu báo cáo kết quả thí nghiệm:** AM xuất bản tóm tắt theo mục tiêu khách (đã đạt/không đạt ngưỡng nội bộ) và share qua portal theo BR-010 — không bao gồm audience raw, bid, giá vốn; không dùng ngôn ngữ cam kết KPI (BR-008).
- **Variant thắng áp dụng cho deliverable đang chạy:** content/creative theo brief mới gắn lại WBS node và đi pipeline duyệt creative bình thường (SLA tier, tối đa 3 vòng sửa) — không có đường "áp luôn không duyệt".
- **Playbook cập nhật giữa quý do học hỏi lớn:** OPS_PLAN có thể triệu tập review ngoài lịch quý; cập nhật vẫn phải có log + duyệt, version playbook cũ giữ nguyên để truy vết proposal đã phát hành theo version cũ.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Experiment (thí nghiệm A/B) — trạng thái lưu/validate ở CORE; WEB hiển thị machine-state, khóa form theo trạng thái.

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit đủ trường)──► [PENDING_PLAN] ──(OPS_PLAN duyệt)──► [ACTIVE] ──(đạt ngưỡng + evidence)──► [CONCLUDED]
   ▲                               │        │                          │        │
   │ (chỉnh lại sau từ chối/       │        │ (trùng segment)          │ (hết duration, │ (từ chối —
   │  block overlap)               │        ▼                          │  thiếu sample) │  lý do bắt buộc)
   └───────────────────────────────┤  [BLOCKED_OVERLAP]                ▼                ▼
                                   └──────────────────────►         [NO_SIGNAL]      [REJECTED]
                                        (chọn exclusion/chờ)             │ (gia hạn — change log có reason)
                                                                         └──────────► [ACTIVE]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `PENDING_PLAN` | OPS_ADS | Đủ 7 trường bắt buộc (giả thuyết, KPI chính, variant, audience, thời lượng, ngân sách, sample size dự kiến) |
| `PENDING_PLAN` | Duyệt | `ACTIVE` | OPS_PLAN | Không trùng segment với thí nghiệm active cùng khách; ngân sách trong hạn mức đã duyệt |
| `PENDING_PLAN` | Từ chối | `REJECTED` | OPS_PLAN | Bắt buộc lý do chiến lược |
| `PENDING_PLAN` | Phát hiện trùng segment | `BLOCKED_OVERLAP` | Hệ thống | Có thí nghiệm ACTIVE cùng audience/tenant |
| `BLOCKED_OVERLAP` | Chọn exclusion / chỉnh audience | `DRAFT` | OPS_ADS | Audience mới không còn trùng segment |
| `ACTIVE` | Kết luận WIN/LOSE | `CONCLUDED` | OPS_ADS (đề xuất) | Đạt ≥20% + ≥50 clicks/≥10 conversions; evidence gắn change log |
| `ACTIVE` | Hết duration thiếu sample | `NO_SIGNAL` | Hệ thống | Tự chuyển khi duration kết thúc; số sample đạt ghi vào đề xuất |
| `NO_SIGNAL` | Gia hạn | `ACTIVE` | OPS_ADS | Change log có reason + ngân sách đi qua phân bậc duyệt |

**Quy tắc:**
- `CONCLUDED` và `REJECTED` là trạng thái kết thúc — muốn chạy lại phải tạo đăng ký mới (giữ nguyên lịch sử để đối chiếu).
- Chi ngân sách chỉ hợp lệ khi trạng thái `ACTIVE` — CORE chặn theo campaign gắn thử nghiệm; mọi chuyển trạng thái ghi audit log.
- Gia hạn từ `NO_SIGNAL` không giới hạn số lần nhưng mỗi lần là một entry change log riêng có reason và ngân sách được duyệt.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `ab_experiment` | `id`, `campaign_id`, `hypothesis`, `primary_kpi`, `objective` (conversion/traffic/awareness), `audience_def`, `duration`, `budget`, `sample_size_plan`, `status` | FK → `campaigns.id` | Không ACTIVE thì không chi ngân sách (CORE chặn) |
| `ab_variant` | `id`, `experiment_id`, `label`, `description`, `is_control` | FK → `ab_experiment.id` | Tối thiểu 2 variant; control bắt buộc |
| `experiment_kpi_daily` | `experiment_id`, `variant_id`, `metric`, `value`, `source` (api/manual), `captured_at` | FK → `ab_experiment.id`, `ab_variant.id` | Nguồn GW; `manual` kèm nguồn + timestamp |
| `experiment_conclusion` | `id`, `experiment_id`, `kind` (win/lose/no_signal), `evidence_json`, `change_log_entry_id`, `concluded_by`, `concluded_at` | FK → `ab_experiment.id`, `campaign_change_log.id` | Không kết luận thiếu evidence |
| `learning_log` | `id`, `experiment_id`, `industry`, `tenant_id`, `lesson`, `kind` (win/lose), `author_id` | FK → `ab_experiment.id` | Trả cứu theo khách/ngành; input review quý |
| `strategy_playbook_version` | `id`, `scope` (content_brief/campaign_structure/audience_playbook), `version`, `content`, `approved_by`, `approved_at` | — | Version giữ nguyên bản cũ; cập nhật là thay đổi chính sách (log + duyệt) |

---

## 8. Acceptance Criteria

> Điều kiện nghiệm thu phác thảo — chi tiết hóa ở Phase 5.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Đăng ký thiếu trường | Form đăng ký mở | OPS_ADS lưu thiếu sample size dự kiến | Không lưu được; hiển thị đúng field còn thiếu | [ ] |
| SC-002: Chặn chi khi chưa đăng ký | Thí nghiệm đang `PENDING_PLAN` | Chi tiêu phát sinh trên campaign gắn thử nghiệm | CORE chặn; cảnh báo hiển thị trên dashboard | [ ] |
| SC-003: Chặn overlap segment | Đã có thí nghiệm ACTIVE cùng audience | Đăng ký mới trùng segment được submit | Chuyển `BLOCKED_OVERLAP`; buộc chọn exclusion hoặc chờ | [ ] |
| SC-004: Khai thắng đủ ngưỡng | Variant A đạt chênh ≥20% và ≥50 clicks | OPS_ADS bấm kết luận WIN | Lưu được; entry change log sinh với evidence KPI/thời gian/sample | [ ] |
| SC-005: Chặn khai thắng thiếu ngưỡng | Variant chênh 10%, sample 30 clicks | OPS_ADS bấm kết luận WIN | Nút vô hiệu; hiển thị khoảng cách còn thiếu so với ngưỡng | [ ] |
| SC-006: No signal tự động | Duration kết thúc, sample chưa đạt | Job kết thúc duration chạy | Trạng thái `NO_SIGNAL`; đề xuất gia hạn/dừng kèm số liệu | [ ] |
| SC-007: Dữ liệu manual có nguồn | GW degraded, KPI nhập tay | OPS_ADS kết luận trên dữ liệu `manual` | Bắt buộc ghi nguồn vào evidence; dashboard gắn nhãn `manual` | [ ] |

> **Liên kết:** SC-001/002/003 map REQ-OPS-012 (B.10 — BR-OPS-10.1/10.2); SC-004/005/006 map BR-OPS-10.3 + ngưỡng chốt DI-005; SC-007 map DI-007 (degraded mode `manual`).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (KPI theo variant từ GW nhãn `manual`, chặn chi ngân sách CORE, counterpart M-INT) |
| Màn hình UI | `phase4-ux/bcerp-web/campaign-deliverable/[screen-group].md` |
| Nguồn domain | `documents/quy-trinh-lam-viec/` (nguồn v2.3 — sample size, SLA creative, vòng sửa) |
| Policy nguồn | `phase0-brainstorm/policies/hop-dong-loi-nda-brand-safety.md` §2.5 |
| Feature cùng module | `phase2-features/bcerp-web/campaign-deliverable/campaign-va-deliverable-management.md` (change log, WBS, nghiệm thu) |
