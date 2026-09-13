# Tính Năng: API 7 nền tảng + Degraded Mode Manual

> **Dựa trên:** REQ-FIN-005 trong `phase1-business/departments/finance/finance.md` (Phần A, BR-FIN-205, BR-FIN-301)
> **Phân hệ:** Integration Gateway (SYS-INTEGRATION-GW)
> **Module:** Settings & Gateway Config (MOD-SETTINGS-GW)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `phase1-business/departments/bod/bod.md` (REQ-BOD-008 — hạ tầng adapter/vault), `phase1-business/P1-02-business-workflow.md`, `work/wf-analyze-requirements/deferred-issues.md` (DI-004, DI-007)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-GW-STGW-002 |
| Module | MOD-SETTINGS-GW |
| Yêu cầu nghiệp vụ | REQ-FIN-005 — API 7 nền tảng + degraded mode `manual` (HIGH, MVP GĐ1); cross-dependency: REQ-OPS-001/REQ-OPS-003 — dữ liệu platform feed Ad Account Command Center + cảnh báo số dư ví |
| Người dùng liên quan | FIN_L1 (import/nhập tay khi degraded), FIN_L2 (rà soát đối soát theo nhãn nguồn), BOD_CFO_CTO (CTO — điều hành adapter/degraded qua REQ-BOD-008); dữ liệu đầu ra tiêu thụ bởi OPS (Ad Account CC, ví ops) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — đầu vào sống của đối soát; chấm dứt ảnh chụp màn hình) |
| Phụ thuộc | FEAT-GW-STGW-001 (REQ-BOD-008) — connection profile, credentials vault, sync scheduler, cơ chế degraded/backfill của gateway; REQ-FIN-004 — quy ước nhãn nguồn `api`/`manual` cho đối trừ 3 số (BR-FIN-205 dùng chung) |
| Ghi chú Expert (A7) | finance.md Mục A7: chưa có đánh giá expert chính thức tại thời điểm viết (chờ review); ghi nhận đã xác định REQ-FIN-005 phụ thuộc tiến trình Business Verification API 7 nền tảng — vì vậy degraded mode `manual` là trạng thái khởi điểm bắt buộc, không phải nhánh ngoại lệ |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng vận hành luồng kéo số liệu số dư/chi tiêu từ 7 nền tảng quảng cáo (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) qua Integration Gateway — pull tự động theo giờ qua batch/queue chống rate limit, lưu raw payload phục vụ đối chiếu, gắn nhãn nguồn `api` — đồng thời bảo đảm khi mất quyền API (DI-007: Business Verification chưa có quyền developer) luồng vẫn sống bằng import statement chuẩn và nhập tay có cấu trúc gắn nhãn `manual`, đối soát như luồng API. Mục tiêu nghiệp vụ: chấm dứt đối soát bằng ảnh chụp màn hình, mọi số liệu đưa vào đối trừ 3 số đều có nhãn nguồn rõ ràng và có thể truy vết.

**Phạm vi:**
- Bao gồm: chạy adapter 7 nền tảng pull hourly qua batch/queue chống rate limit; lưu raw payload gốc trước khi chuẩn hóa; gắn nhãn nguồn `api` trên toàn bộ dữ liệu kéo được.
- Bao gồm: degraded mode `manual` — schema import chuẩn (nền tảng, TKQC, ngày, loại giao dịch, số tiền gốc, tiền tệ, phí, mã tham chiếu) + nhập tay có cấu trúc; sai schema bị chặn ở tầng gateway; KHÔNG có cơ chế nhập tự do dạng text.
- Bao gồm: chuyển trạng thái adapter giữa api ↔ manual ↔ backfill theo cơ chế của FEAT-GW-STGW-001; backfill tự động khi được cấp quyền API/Business Verification, kèm đối soát lại các kỳ đã nhập tay.
- Bao gồm: giám sát cửa sổ sync — trạng thái từng adapter, job retry/backoff, cảnh báo job fail; nền tảng không có API statement → hạ đối soát xuống tuần, bù khớp tích lũy khi có API.
- Bao gồm: cấu hình import/export template và field mapping của luồng dữ liệu tại Settings theo nguyên tắc DI-004 (vendor-agnostic, kết nối ngoại vi tập trung — gồm cả kênh import phục vụ connector VAS của REQ-FIN-013 dùng chung cơ chế schema chặn lỗi).
- Không bao gồm: quản trị vault credentials, rotate/thu hồi, sức khỏe adapter chi tiết — thuộc FEAT-GW-STGW-001 (REQ-BOD-008); tính năng này tiêu thụ hạ tầng đó.
- Không bao gồm: đối trừ 3 số, xử lý dung sai, ticket discrepancy, snapshot tỷ giá — thuộc SYS-CORE-BACKEND (REQ-FIN-004, MOD-WALLET-RECON); gateway chỉ cung cấp dữ liệu đã gắn nhãn nguồn.
- Không bao gồm: màn hình import/nhập tay cho FIN_L1 trên web — thuộc bản counterpart SYS-BCERP-WEB của REQ-FIN-005; gateway là điểm nhận, validate schema và lưu trữ.
- Không bao gồm: cấp phát/thu hồi quyền API với các nền tảng — tiến trình Business Verification thuộc quản trị doanh nghiệp (theo dõi tại DI-007), không phải chức năng hệ thống.

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-INTEGRATION-GW — tầng gateway/adapter headless: mọi luồng dữ liệu chạy tự động do scheduler điều phối (cấu hình tại FEAT-GW-STGW-001); con người chỉ tương tác qua các API nạp dữ liệu chuẩn hóa khi degraded (được web nội bộ gọi) và qua trạng thái hệ thống. Trạng thái `manual` của từng nguồn là machine-state do gateway giữ; web hiển thị và cho FIN_L1 thao tác nhập, core tiêu thụ dữ liệu vào fact tables để đối trừ.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Khi nền tảng chưa có quyền API (degraded), nạp statement chuẩn theo schema (nền tảng, TKQC, ngày, loại giao dịch, số tiền gốc, tiền tệ, phí, mã tham chiếu) qua kênh import | Đối soát tiếp diễn như luồng API, không đối chiếu bằng ảnh chụp màn hình |
| 2 | FIN_L1 | Nhập tay có cấu trúc các giao dịch lẻ thiếu statement, hệ thống tự gắn nhãn `manual` và ghi ai nhập + căn cứ gì | Mọi số liệu đưa vào đối soát đều truy vết được nguồn và trách nhiệm |
| 3 | FIN_L1 | Bị chặn ngay khi nạp dòng sai schema kèm báo lỗi từng dòng | Sửa và nạp lại đúng dòng lỗi, không làm hỏng cả batch, không có lối nhập tự do |
| 4 | FIN_L2 | Lọc toàn bộ dữ liệu đối soát theo nhãn nguồn `api`/`manual` và khoảng thời gian backfill | Biết chính xác con số nào đến từ API gốc, con số nào là nhập tay để đánh giá độ tin cậy trước khi chốt |
| 5 | FIN_L2 | Khi API nền tảng sống lại/được cấp quyền, hệ thống backfill và đối soát lại các kỳ đã nhập tay | Các kỳ degraded được thay bằng dữ liệu gốc chuẩn, chênh lệch được phát hiện và giải trình |
| 6 | BOD_CFO_CTO | Nhận cảnh báo job sync fail / adapter degraded kèm tuổi dữ liệu từng nguồn và quyết định hạ tần suất đối soát (ngày → tuần) cho nguồn đó | Vận hành biết rõ nguồn nào đang stale, không phát hiện muộn khi chốt công nợ |
| 7 | Hệ thống (scheduler gateway) | Pull hourly số dư/chi tiêu 7 nền tảng qua batch/queue, lưu raw payload, gắn nhãn `api` | Dữ liệu đầu vào cho Ad Account CC (REQ-OPS-001) và cảnh báo số dư ví (REQ-OPS-003) luôn fresh và nhất quán |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-FIN-205a | **Nhãn nguồn bắt buộc:** mọi số liệu đưa vào đối soát phải mang nhãn nguồn `api` hoặc `manual`; nhãn do gateway gắn tại thời điểm ghi nhận, không ai được sửa tay; dữ liệu không nhãn bị core từ chối đưa vào đối trừ 3 số | Record thiếu nhãn bị reject ở tầng gateway; attempt sửa nhãn bị chặn + audit log |
| BR-FIN-205b | **Nhập tay có cấu trúc, sai schema bị chặn:** khi degraded, dữ liệu chỉ vào hệ thống qua 2 kênh chuẩn — import statement theo schema chuẩn (nền tảng, TKQC, ngày, loại giao dịch, số tiền gốc, tiền tệ, phí, mã tham chiếu) hoặc nhập tay có cấu trúc; KHÔNG có cơ chế nhập tự do dạng text; import fail schema → báo lỗi từng dòng, FIN_L1 sửa và nạp lại | Batch chứa dòng sai schema: dòng hợp lệ vẫn nhận kèm báo cáo lỗi từng dòng sai — không nhận nguyên batch mù; các lối nhập ngoài 2 kênh không tồn tại ở tầng API |
| BR-FIN-205c | **Truy vết nhập tay:** mỗi bản ghi `manual` bắt buộc gắn người nhập và căn cứ (statement file/ảnh chứng từ tham chiếu), ghi nhận trên web khi FIN_L1 thao tác; gateway lưu nguyên vẹn hai thuộc tính này | Record manual thiếu người nhập/căn cứ không được chấp nhận vào luồng đối soát |
| BR-FIN-301a | **Pull tự động hourly qua batch/queue:** adapter 7 nền tảng pull số dư/chi tiêu theo lịch hourly, chia batch/queue chống rate limit theo quota từng nền tảng; raw payload lưu trước khi chuẩn hóa để phục vụ đối chiếu và reprocess; dữ liệu chuẩn hóa ghi nhãn `api` và đẩy core vào fact tables | Job fail → retry/backoff tự động + alert; fail vượt ngưỡng → adapter degraded, không để dữ liệu đứt lặng lẽ |
| BR-FIN-301b | **Degraded mode `manual` khi mất quyền API (DI-007):** mọi integration phải có degraded mode "manual" + backfill — Business Verification 7 nền tảng chưa có quyền developer nên khởi điểm vận hành là manual; đối soát chạy như luồng API (cùng schema, cùng nhãn cơ chế); nền tảng nào không có API statement: đối soát hạ tuần, bù khớp tích lũy khi có API | Không được phép dừng đối soát chờ quyền API; dữ liệu manual phải đủ để đối trừ 3 số theo đúng chu kỳ |
| BR-FIN-301c | **Backfill khi API được cấp:** khi API nền tảng sống lại/được cấp quyền (Business Verification xong), gateway backfill tự động toàn bộ khoảng đứt quãng theo thứ tự thời gian, gắn lại nhãn `api` cho dữ liệu gốc, và kích hoạt đối soát lại các kỳ đã nhập tay; bản ghi manual đã đối soát không bị xóa — giữ làm vết so sánh, chênh lệch phát sinh xử lý qua ticket discrepancy của core | Backfill không ghi đè/xóa bản ghi manual; kết quả đối soát lại phải truy vết được kỳ nào đã recheck |
| BR-FIN-STGW-004 | **Cấu hình chuẩn hóa tại Settings (DI-004):** schema import, field mapping và import/export template của luồng dữ liệu là cấu hình trong MOD-SETTINGS-GW — vendor-agnostic, không hardcode tên nền tảng/phần mềm trong logic chuẩn hóa; thêm nền tảng nguồn mới = thêm profile + mapping, không sửa code | Chuẩn hóa theo mapping cấu hình; thiếu mapping cho trường dữ liệu → dòng bị đẩy vào hàng lỗi, không suy diễn tự do |
| BR-FIN-STGW-005 | **Tham số luồng sync chỉ ADMIN/BOD sửa:** tần suất pull, ngưỡng freshness cảnh báo, SLA sync, quota/batch size là tham số quản trị có version + ngày hiệu lực + audit log; chỉ BOD_CEO/BOD_CFO_CTO duyệt thay đổi (nối REQ-BOD-009) | FIN_L1/L2 chỉ xem và nhận alert; attempt sửa tham số bị RBAC chặn + log |

---

## 4. Phân Quyền

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN | OPS (OPS_AM/OPS_ADS) |
|-----------|--------|--------|-------------|-----------|----------------------|
| Xem trạng thái sync + nhãn nguồn + tuổi dữ liệu từng nền tảng | ✅ | ✅ | ✅ | ✅ | ✅ (chỉ nguồn feed TKQC của mình) |
| Nạp import statement chuẩn (kênh 1) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Nhập tay có cấu trúc (kênh 2) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Nạp lại dòng lỗi sau khi sửa schema | ✅ | ❌ | ❌ | ❌ | ❌ |
| Lọc/xuất dữ liệu đối soát theo nhãn `api`/`manual` | ✅ | ✅ | ✅ | ❌ | ❌ |
| Kích hoạt đối soát lại kỳ đã nhập tay sau backfill | ✅ (đề xuất) | ✅ (phê duyệt) | ❌ | ❌ | ❌ |
| Bật/tắt degraded mode `manual` cho nguồn | ❌ | ❌ | ✅ (thực thi qua REQ-BOD-008) | ✅ (thực thi sau phê duyệt CTO) | ❌ |
| Theo dõi tiến độ backfill | ✅ (xem) | ✅ (xem) | ✅ | ✅ | ❌ |
| Sửa schema import/field mapping/import-export template | ❌ | ❌ | ✅ (duyệt) | ✅ (thực thi sau phê duyệt) | ❌ |
| Sửa tham số sync (tần suất, freshness, SLA, batch) | ❌ | ❌ | ✅ (version + audit) | ❌ (chỉ xem) | ❌ |
| Nhận alert job fail / adapter degraded | ✅ (nguồn liên quan đối soát) | ✅ | ✅ | ✅ | ✅ (alert TKQC của mình qua REQ-OPS-003) |

> Ranh giới: hạ tầng adapter/vault do BOD_CFO_CTO điều hành theo REQ-BOD-008 (FEAT-GW-STGW-001); FIN_L1/L2 là người dùng dữ liệu và kênh manual — không có quyền gì trên credentials; dữ liệu đầu ra cho OPS chỉ là trạng thái số dư/chi tiêu phục vụ REQ-OPS-001/REQ-OPS-003, không gồm chi tiết kênh nhập.

---

## 5. Trường Hợp Đặc Biệt

- **Khởi điểm toàn bộ 7 nền tảng ở manual (DI-007 — hiện trạng):** chưa có quyền API developer nên giai đoạn đầu luồng API chưa chạy; hệ thống phải vận hành full luồng manual từ ngày đầu (import + nhập tay có cấu trúc), progress Business Verification theo dõi song song ở cấp doanh nghiệp `[KXN-7]` — mốc thời gian cấp quyền từng nền tảng chưa xác định, spec không đặt giả định thời gian.
- **Nền tảng có API nhưng không có endpoint statement:** với nguồn không lấy được statement qua API, đối soát hạ xuống chu kỳ tuần và khi API statement có mặt thực hiện bù khớp tích lũy (cumulative reconciliation) thay vì khớp từng ngày — chênh lệch timing xử lý qua khoản FX/quy tắc dung sai của core (REQ-FIN-004), gateway chỉ cung cấp mốc số.
- **Job sync fail kéo dài một nguồn:** retry/backoff tự động; nếu fail vượt ngưỡng, adapter degraded và alert gộp theo nguồn; trong thời gian đứt, FIN_L1 nạp statement thủ công kèm nhãn manual để không bỏ kỳ đối soát.
- **Import file statement lớn/lỗi rải rác:** hệ thống nhận các dòng hợp lệ, trả về báo cáo lỗi từng dòng (số dòng, mã lỗi, trường vi phạm); FIN_L1 sửa file và nạp lại chỉ các dòng lỗi — không yêu cầu nạp lại toàn bộ, không tạo bản ghi trùng (khóa tự nhiên: nền tảng + TKQC + ngày + loại giao dịch + mã tham chiếu).
- **Backfill chồng lên kỳ đã chốt:** nếu kỳ đã được FIN_L2 chốt công nợ nền tảng tháng mà backfill phát hiện chênh lệch — không tự sửa số đã chốt (khóa kỳ thuộc core/REQ-FIN-004); chênh lệch đưa thành ticket discrepancy giải trình FIN_L2 theo quy trình hiện hành `[KXN-15]` — tương tác giữa backfill và khóa kỳ chưa có quy định riêng, spec chọn hướng an toàn: backfill ghi dữ liệu gốc, core quyết định xử lý chênh lệch.
- **Nhiều người nhập cùng kỳ degraded:** ghi nhận người nhập cuối + giữ lịch sử các lần nạp; hệ thống cảnh báo dòng trùng khóa tự nhiên và yêu cầu xác nhận ghi đè có căn cứ — không tự hợp nhất số liệu nhập tay.
- **Tỷ giá đa tiền tệ:** statement gốc có thể ở USD; gateway lưu số tiền gốc + tiền tệ nguyên vẹn theo schema, việc quy VND dùng snapshot tỷ giá thực hiện ở core (REQ-FIN-004) — gateway không tự quy đổi.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Nguồn dữ liệu nền tảng (Data Feed per platform) — trạng thái luồng kéo/nhận số liệu của từng nền tảng trong 7 nguồn; hạ tầng adapter dùng chung state machine ConnectionProfile của FEAT-GW-STGW-001, bản này định nghĩa ngữ nghĩa dữ liệu.

**Sơ đồ trạng thái:**
```
[MANUAL] ──(cấp quyền API + backfill xong)──► [API]
    ▲                                            │
    └──(mất quyền / fail vượt ngưỡng)────────────┘
    ▲
    └──[BACKFILL] ◄──(API sống lại, có khoảng đứt)── [API]
                         │
                         └──(backfill hoàn tất)──► [API]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `MANUAL` (khởi điểm) | Cấp quyền API + chuyển luồng | `API` | BOD_CFO_CTO | Credential hợp lệ trong vault, health check thành công, schema API map đủ trường bắt buộc |
| `API` | Mark degraded | `MANUAL` | Hệ thống (tự động) hoặc BOD_CFO_CTO | Mất quyền / fail vượt ngưỡng retry; dữ liệu mới từ kênh import/nhập tay gắn nhãn `manual` |
| `API`/`MANUAL` | Start backfill | `BACKFILL` | Hệ thống | API sống lại và tồn tại khoảng đứt chưa có dữ liệu nhãn `api` |
| `BACKFILL` | Hoàn tất backfill | `API` | Hệ thống | Đã phủ đủ khoảng đứt theo raw payload; đối soát lại kỳ manual đã kích hoạt; bản ghi manual giữ làm vết |
| `API`/`MANUAL` | Disable nguồn | `DISABLED` | BOD_CFO_CTO | Nhập lý do; ngưng cả 2 kênh; dữ liệu lịch sử giữ nguyên |

**Quy tắc:**
- Nhãn nguồn gắn theo trạng thái tại thời điểm ghi nhận từng bản ghi — một kỳ có thể chứa hỗn hợp bản ghi `api` và `manual`; truy vấn đối soát luôn lọc theo nhãn trên từng bản ghi, không theo kỳ.
- `BACKFILL` không nhận dữ liệu nhập tay mới trừ khi khoảng đứt vượt quá khả năng backfill (thiếu raw payload) — khi đó FIN_L1 nạp bù kèm cảnh báo nguồn không gốc.
- Mọi chuyển trạng thái ghi audit log bất biến kèm trigger (job id / mã lỗi / người thao tác).

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| PlatformStatement | `platform` (META/GOOGLE/TIKTOK/BING/X/PINTEREST/YANDEX), `adaccount_ref`, `txn_date`, `txn_type`, `amount_original`, `currency`, `fee`, `reference_code`, `source_label` (`api`/`manual`), `entered_by`, `evidence_ref` | FK logic → AdAccount registry (REQ-OPS-001) | Schema chuẩn bắt buộc 8 trường theo BR-FIN-205; khóa tự nhiên chống trùng |
| RawPayload | `platform`, `pulled_at`, `payload_blob`, `job_id`, `parse_status` | FK → SyncJob.id | Lưu trước chuẩn hóa — căn cứ đối chiếu và reprocess khi mapping đổi |
| SyncJob | `profile_id`, `window_from`, `window_to`, `status` (queued/running/success/failed/retrying), `attempt`, `error_code` | FK → ConnectionProfile.id (FEAT-GW-STGW-001) | Batch/queue hourly; retry/backoff; alert khi fail |
| BackfillRun | `platform`, `gap_from`, `gap_to`, `records_restored`, `recheck_status`, `started_at`, `finished_at` | FK → PlatformStatement (qua khoảng thời gian) | Không xóa bản ghi manual; kích hoạt đối soát lại |
| ImportBatch | `platform`, `file_ref`, `total_rows`, `accepted_rows`, `error_report`, `imported_by`, `imported_at` | 1 batch — N PlatformStatement (manual) | Báo lỗi từng dòng; không nhận batch mù |
| FieldMapping (dùng chung) | `profile_id`, `source_field`, `target_field`, `transform_rule`, `template_version` | FK → ConnectionProfile.id | Cấu hình tại Settings theo DI-004 — vendor-agnostic |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Pull hourly gắn nhãn `api` | Adapter Meta ở `ACTIVE`, quyền API hợp lệ | Scheduler chạy cửa sổ hourly | Số dư/chi tiêu về hệ thống, raw payload lưu, dữ liệu chuẩn hóa gắn nhãn `api`, đẩy core vào fact tables | [ ] |
| SC-002: Sai schema bị chặn theo dòng | FIN_L1 nạp file import có 3/100 dòng sai schema | Gateway xử lý batch | 97 dòng hợp lệ nhận, 3 dòng trả lỗi chi tiết từng dòng; không tạo record hỏng; FIN_L1 nạp lại 3 dòng đã sửa thành công | [ ] |
| SC-003: Không có lối nhập tự do | Degraded mode, FIN_L1 cần ghi số liệu ngoài 2 kênh chuẩn | Cố gửi payload dạng text tự do qua API | Từ chối — chỉ nhận schema chuẩn (import) hoặc form có cấu trúc (manual); attempt ghi audit log | [ ] |
| SC-004: Manual truy vết người nhập + căn cứ | FIN_L1 nhập tay một giao dịch | Record ghi vào hệ thống | Bản ghi mang nhãn `manual`, `entered_by` = FIN_L1, `evidence_ref` bắt buộc; thiếu căn cứ không lưu được | [ ] |
| SC-005: Backfill không ghi đè manual | Kỳ T1 nhập tay nhãn `manual` và đã đối soát; quyền API được cấp | Backfill chạy cho khoảng T1 | Bản ghi manual giữ nguyên làm vết; dữ liệu `api` bù vào; đối soát lại kích hoạt; chênh lệch → ticket discrepancy của core | [ ] |
| SC-006: Job fail → retry + alert, không đứt lặng lẽ | Adapter Google gặp lỗi 5xx liên tục | Job sync thất bại vượt số lần retry | Retry/backoff thực hiện; hết ngưỡng → nguồn chuyển `MANUAL` + alert gộp theo nguồn; FIN_L1 nạp statement bù | [ ] |
| SC-007: Nguồn không có API statement → hạ tuần | Nền tảng X không cung cấp API statement | Cấu hình chu kỳ nguồn | Đối soát nguồn này chạy tuần, khi có API thực hiện bù khớp tích lũy; tham số chu kỳ là policy versioned chỉ ADMIN/BOD sửa | [ ] |
| SC-008: Dữ liệu feed cho OPS | Số dư TKQC cập nhật từ luồng API | REQ-OPS-001/REQ-OPS-003 truy vấn | Ad Account CC và cảnh báo số dư ví dùng dữ liệu đã gắn nhãn + freshness hiển thị; bản mobile nội bộ chỉ xem không nhập | [ ] |

> **Liên kết:** SC-001…SC-008 map về REQ-FIN-005 (Mục 2 — luồng API hourly, degraded manual 2 kênh chuẩn, schema chặn lỗi, backfill + đối soát lại, retry/alert, hạ tuần nguồn không API, feed cho REQ-OPS-001/003).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/settings-gw/` (màn import/nhập tay FIN_L1, trạng thái sync — thuộc bản counterpart SYS-BCERP-WEB của REQ-FIN-005) |
| Bản fan-out counterpart | `phase2-features/core-backend/settings-gw/` (fact tables, đối trừ 3 số tiêu thụ dữ liệu), `phase2-features/bcerp-web/settings-gw/` (màn import/nhập tay, trạng thái sync) — REQ-FIN-005 xuất hiện ở 3 systems, bản này là riêng SYS-INTEGRATION-GW |
| Tính năng liền kề trong lane | `phase2-features/integration-gw/settings-gw/quan-tri-integration-gateway-va-credentials-vault-vai-cto.md` (FEAT-GW-STGW-001 — hạ tầng adapter/vault/scheduler mà luồng này vận hành) |
| Nguồn cross-dependency | REQ-FIN-004 / BR-FIN-205 (`phase1-business/departments/finance/finance.md`) — nhãn nguồn và dung sai đối soát; REQ-OPS-001/REQ-OPS-003 — Ad Account CC + ví ops tiêu thụ platform feed; `work/wf-analyze-requirements/deferred-issues.md` (DI-004, DI-007) |
