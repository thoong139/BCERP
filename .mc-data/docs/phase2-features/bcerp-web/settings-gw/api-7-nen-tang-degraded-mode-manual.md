# Tính Năng: API 7 Nền Tảng QC + Degraded Mode Manual

> **Dựa trên:** REQ-FIN-005 trong `phase1-business/departments/finance/finance.md` (Phần A, Mục REQ-FIN-005; Phần B, BR-FIN-205 và BR-FIN-301)
> **Phân hệ:** Quản trị Cấu Hình & Integration Gateway (SYS-BCERP-WEB)
> **Module:** Quản trị Gateway & Vault (MOD-SETTINGS-GW)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/settings-gw/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/settings-gw/feat-erp-stgw-002-impl.md`

> **Fan-out:** REQ-FIN-005 xuất hiện ở 3 hệ thống — đây là bản riêng cho touchpoint **SYS-BCERP-WEB** (web nội bộ responsive Next.js cho nhân viên BC: form/list/workflow UI, gọi API core, hiển thị đúng trạng thái machine-state). Counterparts: SYS-INTEGRATION-GW (chạy adapter 7 nền tảng, sync scheduler, gắn nhãn nguồn), SYS-CORE-BACKEND (nhận dữ liệu vào fact tables, đối trừ 3 số). Business rule enforce ở service layer; WEB là bề mặt import/nhập tay và quan sát trạng thái sync.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-STGW-002 |
| Module | MOD-SETTINGS-GW (SYS-BCERP-WEB) |
| Yêu cầu nghiệp vụ | REQ-FIN-005; liên quan chéo REQ-OPS-001/REQ-OPS-003 (dữ liệu platform feed là đầu vào cho quản lý Ad Account CC + ví) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP) |
| Phụ thuộc | FEAT-ERP-STGW-001 — credentials vault phải vận hành trước khi bật sync API; REQ-FIN-004 — đối trừ 3 số là consumer chính của dữ liệu feed; REQ-OPS-001/REQ-OPS-003 — OPS tiêu thụ platform feed |
| Ghi chú Expert (A7) | A7 của `finance.md` đã flag (chờ review chính thức): REQ-FIN-005 phụ thuộc tiến trình Business Verification API 7 nền tảng (DI-007). Spec xử lý từ thiết kế bằng degraded mode `manual` + backfill tự động |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Chấm dứt đối soát bằng ảnh chụp màn hình: số dư và chi tiêu của 7 nền tảng quảng cáo (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) về hệ thống tự động qua API, có nhãn nguồn rõ ràng (`api`/`manual`) và chỉ báo freshness, để đối trừ 3 số (REQ-FIN-004) dựa trên dữ liệu đáng tin. Trong giai đoạn BC chưa có quyền API developer (DI-007), tính năng bảo đảm hoạt động tài chính không gián đoạn: FIN_L1 vẫn nhập liệu có kiểm soát qua 2 kênh chuẩn; khi API sống lại, hệ thống tự backfill và đối soát lại.

**Phạm vi:**
- Bao gồm:
  - Màn hình WEB quan sát trạng thái sync từng nguồn nền tảng: trạng thái adapter, lần pull gần nhất, freshness (tuổi dữ liệu), nhãn nguồn `api`/`manual` hiện hành.
  - Màn import statement chuẩn cho FIN_L1 với schema bắt buộc 7 trường (nền tảng, TKQC, ngày, loại giao dịch, số tiền gốc, tiền tệ, phí, mã tham chiếu) — sai schema bị chặn và báo lỗi từng dòng.
  - Form nhập tay có cấu trúc (không text tự do) gắn nhãn `manual`, bắt buộc ghi ai nhập + căn cứ gì.
  - Hiển thị tiến trình backfill khi API/Business Verification được cấp: đối soát lại kỳ đã nhập tay, so sánh chênh lệch manual vs API.
  - Cấu hình tham số sync (lịch pull hourly, ngưỡng freshness) trong Settings theo version effective-dated — chỉ BOD/ADMIN sửa, có audit.
  - Quản lý kết nối ngoại vi tập trung trong Settings theo quyết định DI-004 (12/09): connection profile, credentials vault, field mapping, import/export template cho phần mềm kế toán VAS — vendor-agnostic, không hardcode tên phần mềm.
- Không bao gồm:
  - Vận hành adapter, batch/queue chống rate limit, lưu raw payload — thuộc SYS-INTEGRATION-GW (counterpart của REQ-FIN-005).
  - Đối trừ 3 số, ticket discrepancy, chốt & khóa kỳ — thuộc REQ-FIN-004 (MOD-WALLET-RECON); tính năng này chỉ cung cấp dữ liệu đầu vào có nhãn nguồn.
  - Xác nhận "đã khớp tiền" Financial Hard Stop — thuộc REQ-FIN-006.
  - Quản trị vòng đời credentials (thêm/rotate/thu hồi) — thuộc FEAT-ERP-STGW-001.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Xem một dashboard duy nhất trạng thái sync 7 nền tảng: adapter sống/degraded, lần pull gần nhất, tuổi dữ liệu, nhãn nguồn `api`/`manual` hiện hành | Biết chắc nguồn dữ liệu dùng cho đối soát đến từ đâu và tươi đến đâu |
| 2 | FIN_L1 | Import statement chuẩn theo schema 7 trường khi nền tảng chưa có API (degraded mode `manual`) | Đối soát không gián đoạn khi BC chờ Business Verification (DI-007), dữ liệu vẫn có cấu trúc máy đọc được |
| 3 | FIN_L1 | Nhập tay có cấu trúc qua form (nền tảng, TKQC, ngày, loại giao dịch...) thay vì text tự do | Dữ liệu nhập tay sạch schema, tự động gắn nhãn `manual` và ghi vết ai nhập + căn cứ gì |
| 4 | FIN_L1 | Khi import fail schema, thấy báo lỗi chi tiết từng dòng kèm lý do | Sửa đúng dòng sai và nạp lại, không phải upload lại toàn bộ file |
| 5 | FIN_L2 | Giám sát tỷ trọng dữ liệu `manual` vs `api` và kết quả khớp sau backfill | Kiểm soát rủi ro sai số từ đầu vào nhập tay trước khi chảy vào đối trừ 3 số và báo cáo BOD |
| 6 | BOD_CFO_CTO | Duyệt phiên bản mới của tham số sync (lịch pull, ngưỡng freshness) với ngày hiệu lực rõ ràng | Thay đổi cấu hình đầu vào dữ liệu tài chính có version + audit, không hồi tố |
| 7 | FIN_L2 | Theo dõi tiến trình backfill tự động khi API nền tảng được cấp: kỳ nào đã đối soát lại, chênh lệch manual vs API | Đóng được vòng đời dữ liệu degraded — không có kỳ nào "nhập tay xong rồi quên" |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Enforcement chính nằm ở service layer (CORE/GW); WEB không được tự xử lý bỏ qua enforcement.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-STGW-201 | Quản lý kết nối ngoại vi tập trung trong Settings (quyết định DI-004 12/09): connection profile, credentials vault, field mapping, import/export template cho phần mềm kế toán VAS — vendor-agnostic, không hardcode tên phần mềm; tên vendor cụ thể được cấu hình khi triển khai | Import/export VAS chỉ chạy qua connection profile + field mapping đã cấu hình; mọi code/UI hardcode tên phần mềm kế toán bị chặn ở mức thiết kế và review |
| BR-STGW-202 | Dữ liệu 7 nền tảng QC (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) được pull hourly qua batch/queue chống rate limit; GW lưu raw payload phục vụ đối chiếu; CORE ghi vào fact tables | WEB không cho cấu hình lịch "pull toàn bộ đồng loạt" vi phạm chống rate limit; số liệu hiển thị phải truy về được raw payload gốc |
| BR-STGW-203 | Mọi integration phải có degraded mode `manual` + backfill khi mất quyền API (DI-007): chưa có quyền developer → import statement chuẩn + nhập tay có cấu trúc gắn nhãn `manual`; dữ liệu `manual` đi đối soát như luồng API; khi được cấp API/Business Verification → GW backfill tự động và đối soát lại các kỳ đã nhập tay; chênh lệch manual vs API >±0,1% đưa vào báo cáo đối soát | Không tồn tại trạng thái "nguồn không có dữ liệu" — mất quyền API phải tự chuyển degraded; số liệu `manual` không được xử lý khác biệt về mặt đối soát so với `api` |
| BR-STGW-204 | WEB chỉ cho nhập số liệu đối soát qua đúng 2 kênh chuẩn: (1) import statement theo schema, (2) nhập tay có cấu trúc — không có cơ chế nhập tự do dạng text; mọi số liệu đưa vào đối soát bắt buộc có nhãn `api` hoặc `manual` (BR-FIN-205) | Mọi đường nhập khác bị API từ chối; số liệu thiếu nhãn nguồn bị chặn khỏi fact tables đối soát |
| BR-STGW-205 | Schema import chuẩn bắt buộc: nền tảng, TKQC, ngày, loại giao dịch, số tiền gốc, tiền tệ, phí, mã tham chiếu; nhập tay bắt buộc ghi người nhập + căn cứ (sao kê/statement đính kèm); sai schema bị chặn — import fail báo lỗi từng dòng, FIN_L1 sửa và nạp lại đúng dòng | Batch có dòng lỗi không được import một phần âm thầm: dòng hợp lệ import, dòng lỗi trả về danh sách lỗi tường minh; không có "import gần đúng" |
| BR-STGW-206 | Job sync fail → retry/backoff tự động + alert; nền tảng không có API statement → đối soát hạ xuống tuần, bù khớp tích lũy khi có API; chỉ báo freshness hiển thị kèm mọi số liệu (nguyên tắc hệ thống P1-02 #10) | Số liệu quá freshness không được ngầm dùng như dữ liệu tươi — WEB phải hiển thị cảnh báo tuổi dữ liệu; không được nội suy/điền khuyết số liệu thay người dùng |
| BR-STGW-207 | Cấu hình chính sách/tham số quản trị liên quan sync (lịch pull, ngưỡng freshness, tham số cảnh báo) chỉ BOD/ADMIN sửa, theo version effective-dated: hiệu lực theo ngày duyệt, không hồi tố, mỗi version lưu người duyệt + audit (old → new) | Thay đổi không qua version có duyệt bị từ chối; SYS_ADMIN chỉ áp cấu hình sau duyệt; báo cáo tra cứu đúng phiên bản hiệu lực tại thời điểm dữ liệu |
| BR-STGW-208 | Platform feed là đầu vào chung cho REQ-FIN-004 (đối trừ 3 số) và REQ-OPS-001/REQ-OPS-003 (Ad Account CC + ví): nhãn nguồn và freshness giữ nguyên khi truyền sang hệ thống tiêu thụ, không làm mờ giữa chừng | Hệ thống tiêu thụ nhận được dữ liệu thiếu nhãn/freshness phải từ chối xử lý và báo lỗi nguồn thay vì tự gán nhãn |
| BR-STGW-209 | Cảnh báo sức khỏe nguồn dữ liệu là danh mục riêng, tách khỏi cờ cảnh báo K6–K12 của quy trình khách hàng (đang mở `[KXN-20]`): không dùng chung mã cờ cho tới khi KXN-20 chốt; khi chốt sẽ rà lại tránh trùng lặp | Tránh lai ghép 2 danh mục cảnh báo khác bản chất; mọi mapping tạm giữa 2 danh mục bị chặn trong thiết kế |

---

## 4. Phân Quyền

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN |
|-----------|--------|--------|-------------|-----------|
| Xem trạng thái sync + freshness + nhãn nguồn của 7 nền tảng | ✅ | ✅ | ✅ | ✅ |
| Import statement chuẩn (kênh 1) | ✅ | ❌ | ❌ | ❌ |
| Nhập tay có cấu trúc (kênh 2) | ✅ | ❌ | ❌ | ❌ |
| Sửa và nạp lại dòng lỗi import | ✅ | ❌ | ❌ | ❌ |
| Xem báo cáo lỗi import + lịch sử ai nhập, căn cứ gì | ✅ (của mình) | ✅ (tất cả) | ✅ | ✅ (kỹ thuật) |
| Giám sát tỷ lệ manual/api + kết quả backfill | ✅ | ✅ | ✅ | ❌ |
| Soạn phiên bản mới tham số sync (lịch, freshness) | ❌ | ❌ (đề xuất được) | ✅ | ❌ |
| Ký duyệt ban hành tham số sync effective-dated | ❌ | ❌ | ✅ | ❌ |
| Áp cấu hình kỹ thuật sau khi change được duyệt | ❌ | ❌ | ❌ | ✅ |
| Chỉnh sửa/xóa dữ liệu đã import (bất kể kênh) | ❌ | ❌ | ❌ | ❌ (chỉ qua điều chỉnh có phê duyệt theo REQ-FIN-004) |

**Ghi chú phân quyền:**
- FIN_L1 là tay nhập duy nhất trong degraded mode; FIN_L2 giám sát nhưng không nhập — tách bạch người nhập và người kiểm soát (SoD).
- Các vai OPS (OPS_PLAN, OPS_AM, OPS_ADS...) tiêu thụ platform feed qua REQ-OPS-001/REQ-OPS-003 ở màn hình nghiệp vụ của họ, không truy cập màn import FIN.
- Danh mục vai tuân thủ 18 vai registry (không tồn tại vai OPS_CX/FIN_COMPL — DI-006).

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Nền tảng chưa cấp quyền API developer (DI-007 — hiện trạng tại thời điểm spec):** cả 7 nguồn khởi động ở degraded mode `manual`; WEB vận hành trọn vẹn 2 kênh nhập ngay từ ngày đầu, không đòi hỏi API.
- **Nền tảng có statement nhưng không có API:** đối soát hạ xuống tuần; WEB hiển thị rõ chế độ này; khi API có sau đó → bù khớp tích lũy và đối soát lại các tuần đã nhập tay.
- **Import file statement sai schema hàng loạt:** hệ thống trả về báo cáo từng dòng (dòng nào lỗi, lỗi trường nào, vì sao); FIN_L1 sửa và nạp lại; cấm bỏ qua validation để import cho kịp deadline.
- **Job sync fail lặp lại nhiều lần:** retry/backoff tự động; vượt ngưỡng thì nguồn chuyển degraded + alert; WEB hiển thị lỗi kỹ thuật đủ chi tiết cho SYS_ADMIN nhưng không lộ credentials.
- **Backfill phát hiện chênh lệch >±0,1% giữa số `manual` đã nhập và số API thật:** chênh lệch ghi vào báo cáo đối soát (REQ-FIN-004 xử lý ticket discrepancy); kỳ ảnh hưởng được đánh dấu đã đối soát lại — không đè số cũ không vết.
- **Thay đổi định dạng statement từ nền tảng:** field mapping trong Settings được cập nhật version mới (vendor-agnostic theo DI-004); dữ liệu đã import theo mapping cũ giữ nguyên lịch sử phiên bản.
- **Nghỉ phép FIN_L1 kéo dài trong degraded mode:** FIN_L2 tạm phân công người nhập khác trong nhóm FIN_L1 (cùng vai, khác user); quyền không nhảy vai — người nhập mới vẫn ghi vết cá nhân.
- **Giả định mở `[KXN-20]`:** danh mục cờ K6–K12 chưa chốt; module này dùng danh mục cảnh báo riêng cho sức khỏe nguồn dữ liệu, không mapping chéo tới khi KXN-20 được xác nhận — KHÔNG tự quyết.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Nguồn dữ liệu nền tảng (PlatformFeed) — một bản ghi cho mỗi nền tảng trong 7 nền tảng QC.

**Sơ đồ trạng thái:**
```
[API_ACTIVE] ──(mất quyền API / token hết hạn / sync fail vượt ngưỡng)──► [DEGRADED_MANUAL]
     ▲                                                                        │
     │         (được cấp quyền API + adapter bật + backfill hoàn tất)         │
     └────────────────────────────────────────────────────────────────────────┘
                                        │
                                        │ (được cấp API, backfill đang chạy)
                                        ▼
                                  [BACKFILLING] ──(backfill xong, đã đối soát lại)──► [API_ACTIVE]
[DEGRADED_MANUAL] ──(nền tảng không có API statement, chỉ statement tuần)──► [MANUAL_WEEKLY]
[MANUAL_WEEKLY]  ──(API statement có sau đó)──► [BACKFILLING]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `API_ACTIVE` | Hệ thống phát hiện mất quyền API/token hết hạn | `DEGRADED_MANUAL` | Hệ thống (GW) | Tự động theo machine-state; WEB chỉ hiển thị |
| `API_ACTIVE` | Sync fail lặp lại vượt ngưỡng | `DEGRADED_MANUAL` | Hệ thống (GW) | Đã retry/backoff đúng chính sách; alert đã gửi |
| `DEGRADED_MANUAL` | Được cấp quyền API + bật adapter | `BACKFILLING` | BOD_CFO_CTO (duyệt), SYS_ADMIN (áp change) | Credentials hợp lệ trong vault (FEAT-ERP-STGW-001); hàng chờ backfill đã tạo |
| `BACKFILLING` | Backfill + đối soát lại hoàn tất | `API_ACTIVE` | Hệ thống | Chênh lệch manual vs API đã ghi báo cáo; các kỳ nhập tay đã đánh dấu đối soát lại |
| `DEGRADED_MANUAL` | Xác nhận nền tảng chỉ có statement tuần | `MANUAL_WEEKLY` | BOD_CFO_CTO | Ghi nhận chế độ đối soát tuần; hiển thị rõ trên WEB |
| `MANUAL_WEEKLY` | API statement khả dụng | `BACKFILLING` | BOD_CFO_CTO (duyệt) | Bù khớp tích lũy được lên kế hoạch trước khi chuyển |

**Quy tắc:**
- Chuyển `API_ACTIVE → DEGRADED_MANUAL` là quyết định hệ thống (machine-state): WEB không có nút "tắt" degraded nếu không qua chuỗi backfill đầy đủ.
- `BACKFILLING` là trạng thái trung gian bắt buộc — cấm bật thẳng `DEGRADED_MANUAL → API_ACTIVE` mà bỏ qua đối soát lại.
- Mọi chuyển trạng thái ghi audit log bất biến kèm actor (hoặc `SYSTEM`), timestamp, lý do; nhãn nguồn và freshness của dữ liệu giữ nguyên khi truyền sang REQ-FIN-004 và REQ-OPS-001/003.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `platform_feed` | `id`, `platform` (7 nền tảng), `feed_state` (API_ACTIVE/DEGRADED_MANUAL/BACKFILLING/MANUAL_WEEKLY), `last_sync_at`, `freshness_threshold` | 1-N → `sync_job`, `import_batch` | Nguồn sự thật của machine-state hiển thị trên WEB |
| `sync_job` | `id`, `platform_feed_id`, `window_from`, `window_to`, `status`, `attempt`, `error` | FK → `platform_feed.id` | Chạy hourly theo batch/queue; retry/backoff theo chính sách |
| `raw_payload` | `id`, `sync_job_id`, `payload`, `received_at` | FK → `sync_job.id` | Append-only, phục vụ đối chiếu; không sửa/xóa |
| `import_batch` | `id`, `platform_feed_id`, `schema_version`, `channel` (import/manual), `status` (VALIDATED/REJECTED/IMPORTED), `imported_by`, `basis_ref`, `imported_at` | FK → `platform_feed.id` | `basis_ref` = căn cứ (statement/sao kê); bắt buộc khi nhập tay |
| `import_line` | `id`, `import_batch_id`, `platform`, `ad_account_code`, `txn_date`, `txn_type`, `amount_original`, `currency`, `fee`, `reference_code`, `line_status`, `error` | FK → `import_batch.id` | Schema chuẩn 7 trường nội dung + trạng thái từng dòng |
| `source_label` | `id`, `fact_ref`, `label` (api/manual), `labeled_at` | Gắn trên mọi fact dữ liệu đầu vào đối soát | Bắt buộc có trước khi ghi fact tables; giữ nguyên khi truyền sang REQ-FIN-004 |
| `integration_connection` | (tham chiếu FEAT-ERP-STGW-001) | FK logic → connection profile VAS | Import/export template + field mapping dùng chung cơ chế vendor-agnostic |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Điền chi tiết ở Phase 5; dưới đây là phác thảo sơ bộ Phase 2.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Khởi động degraded từ ngày đầu | BC chưa có quyền API developer (DI-007) | Triển khai tính năng | Cả 7 nguồn hiển thị `DEGRADED_MANUAL` trên WEB; 2 kênh nhập (import/manual) hoạt động trọn vẹn ngay không cần API | [ ] |
| SC-002: Import statement đúng schema | FIN_L1 có statement nền tảng X | FIN_L1 import file đúng 7 trường schema | Batch chuyển `IMPORTED`; mọi dòng gắn nhãn `manual`; ghi `imported_by` + `basis_ref`; dashboard cập nhật | [ ] |
| SC-003: Import sai schema báo lỗi từng dòng | FIN_L1 import file có 3 dòng sai định dạng | Hệ thống validate | Dòng hợp lệ được import; 3 dòng lỗi trả về danh sách lỗi tường minh từng trường; FIN_L1 sửa và nạp lại đúng dòng; không có "import âm thầm một phần" | [ ] |
| SC-004: Chặn kênh nhập trái phép | Người dùng cố POST số liệu đối soát qua endpoint ngoài 2 kênh chuẩn | Request đến API | API từ chối; không có số liệu nào vào fact tables thiếu nhãn nguồn | [ ] |
| SC-005: Backfill khi API được cấp | Nguồn X đang `DEGRADED_MANUAL`, BC vừa được cấp quyền API | BOD_CFO_CTO duyệt bật adapter | Nguồn chuyển `BACKFILLING`; đối soát lại các kỳ nhập tay xong → `API_ACTIVE`; chênh lệch >±0,1% ghi vào báo cáo đối soát | [ ] |
| SC-006: Tham số sync effective-dated | BOD_CFO_CTO soạn ngưỡng freshness mới | CFO/CTO duyệt với ngày hiệu lực | Phiên bản mới áp đúng từ ngày hiệu lực; phiên bản cũ còn nguyên lịch sử; báo cáo tra cứu đúng phiên bản theo thời điểm dữ liệu; audit ghi old → new | [ ] |
| SC-007: Nhãn nguồn giữ nguyên khi truyền đi | Dữ liệu `manual` đã vào fact tables | REQ-FIN-004 chạy đối trừ 3 số | Dữ liệu tiêu thụ vẫn mang nhãn `manual` + freshness; không có bước nào làm mờ nhãn giữa chừng | [ ] |

> **Liên kết:** SC-001→SC-004, SC-007 map REQ-FIN-005 (Mục 2); SC-005 map REQ-FIN-005 + BR-FIN-301; SC-006 map REQ-FIN-005 + REQ-BOD-009.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (adapter 7 nền tảng, nhãn api/manual, platform feed → đối trừ 3 số) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI (dashboard sync + màn import FIN) | `phase4-ux/bcerp-web/settings-gw/[screen-group].md` |
| Bản counterpart của cùng REQ | FEAT của REQ-FIN-005 tại SYS-INTEGRATION-GW và SYS-CORE-BACKEND |
