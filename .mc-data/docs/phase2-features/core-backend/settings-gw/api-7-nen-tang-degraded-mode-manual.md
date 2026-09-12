# Tính Năng: API 7 nền tảng + degraded mode manual

> **Dựa trên:** REQ-FIN-005 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Nền tảng Core Backend — cấu hình & tích hợp (SYS-CORE-BACKEND)
> **Module:** Quản trị Cấu hình & Integration Gateway (MOD-SETTINGS-GW)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/settings-gw/*.md`, `phase5-implementation/tasks/core-backend/settings-gw/feat-core-stgw-002-impl.md`

> **Hướng dẫn ID:** FEAT-ID được tạo từ REQ-ID theo quy tắc:
> `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`
> Tra `req-registry.json` để xác nhận SYS và MOD tương ứng.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-STGW-002 |
| Module | MOD-SETTINGS-GW |
| Yêu cầu nghiệp vụ | REQ-FIN-005 (phối hợp REQ-OPS-001, REQ-OPS-003) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Cao (HIGH · MVP — GĐ1) |
| Giai đoạn | Giai đoạn 1 |
| Phụ thuộc | FEAT-CORE-STGW-001 (connection profile + credentials vault + scheduler); REQ-FIN-012 (audit log WORM); feed phục vụ REQ-FIN-004 (đối trừ 3 số), REQ-OPS-001 (Ad Account Command Center), REQ-OPS-003 (ví TKQC góc ops) |
| Ghi chú Expert (A7) | A7 của `finance.md` chưa được expert ký xác nhận nhưng đã ghi nhận rõ: REQ-FIN-005 phụ thuộc tiến trình Business Verification API 7 nền tảng — do đó degraded mode "manual" + backfill là yêu cầu bắt buộc của thiết kế, không phải phương án dự phòng |

**Fan-out REQ-FIN-005:** REQ xuất hiện ở 3 systems (SYS-INTEGRATION-GW, SYS-CORE-BACKEND, SYS-BCERP-WEB). Bản này là bản riêng cho **SYS-CORE-BACKEND** (headless API/domain services): mọi business rule được enforce ở tầng service — không tin UI; audit log + tenant isolation bắt buộc. Counterparts: SYS-INTEGRATION-GW (adapter pull hourly, rate-limit, raw payload), SYS-BCERP-WEB (màn trạng thái sync + import/nhập tay dành cho FIN_L1).

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tiếp nhận, kiểm định và chuẩn hóa dữ liệu số dư/chi tiêu từ 7 nền tảng quảng cáo (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) vào fact tables của core backend — chấm dứt đối soát bằng ảnh chụp màn hình. Mỗi dòng dữ liệu mang nhãn nguồn (`api`/`manual`) để đối trừ 3 số có tính kiểm chứng: hệ thống biết số đến từ đâu, ai nhập, căn cứ gì.

**Phạm vi:**
- Bao gồm:
  - Domain service tiếp nhận platform feed từ GW (lịch sync cấu hình tại MOD-SETTINGS-GW) và nạp fact tables chuẩn hóa cho đối soát.
  - Service kiểm định schema import chuẩn (nền tảng, TKQC, ngày, loại giao dịch, số tiền gốc, tiền tệ, phí, mã tham chiếu) — chặn dòng sai schema, trả lỗi từng dòng.
  - Service nhập tay có cấu trúc gắn nhãn `manual` với người nhập + căn cứ — enforce hoàn toàn ở service layer.
  - Degraded mode "manual" khi mất quyền API (DI-007) + backfill tự động khi được cấp API/Business Verification, kèm đối soát lại các kỳ đã nhập tay.
  - Giám sát freshness (chi tiêu tươi ≤1h) và cảnh báo sync fail qua job queue + monitoring.
  - Cấp dữ liệu chuẩn hóa cho downstream: đối trừ 3 số (REQ-FIN-004), Ad Account CC (REQ-OPS-001), ví & cảnh báo số dư (REQ-OPS-003, REQ-FIN-002).
- Không bao gồm:
  - Adapter gọi API nền tảng, chống rate limit, lưu raw payload, scheduler pull hourly — thuộc SYS-INTEGRATION-GW.
  - Màn import/nhập tay và dashboard trạng thái sync — thuộc SYS-BCERP-WEB (UI counterpart).
  - Logic khớp 3 vế, ticket discrepancy, chốt/khóa kỳ — thuộc REQ-FIN-004.
  - Quản trị credentials và connection profile — thuộc FEAT-CORE-STGW-001.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Nhập/import statement chuẩn khi nền tảng chưa có quyền API, hệ thống gắn nhãn `manual` và ghi tên tôi + căn cứ | Luồng degraded vẫn cho dữ liệu có cấu trúc, đối soát như luồng API, không phải đối chiếu ảnh chụp màn hình |
| 2 | FIN_L1 | Nhận lỗi chi tiết từng dòng khi file import sai schema | Sửa đúng dòng lỗi và nạp lại nhanh, không đoán nguyên nhân cả file bị từ chối |
| 3 | FIN_L2 | Xem nhãn nguồn của mọi số liệu trong báo cáo đối soát (`api`/`manual`) | Biết số nào cần ưu tiên xác minh trước khi chốt kỳ |
| 4 | FIN_L2 | Nhận báo cáo chênh lệch manual vs API khi backfill xong (sai khác >±0,1%) | Truy vết nguyên nhân chênh lệch trước khi chốt số liệu nền tảng tháng |
| 5 | BOD_CFO_CTO | Theo dõi trạng thái sync 7 nền tảng (ok/fail/degraded, tuổi dữ liệu) từ tầng service | Đảm bảo dòng dữ liệu đầu vào sống của đối soát không đứt |
| 6 | FIN_L2 | Dữ liệu chi tiêu/số dư cấp tươi ≤1h cho cảnh báo ví và Ad Account CC | Cảnh báo số dư đủ chi ≥3 ngày (REQ-FIN-002/REQ-OPS-003) chạy trên dữ liệu tươi |
| 7 | Hệ thống (job service) | Tự retry/backoff khi sync fail và tự lập backfill task khi quyền API được cấp | Dữ liệu tự hồi phục theo lịch, không phụ thuộc thao tác tay |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code (enforce ở tầng service của SYS-CORE-BACKEND, không tin UI).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Quản lý kết nối ngoại vi tập trung trong Settings (quyết định DI-004 ngày 12/09):** lịch sync, connection profile, credentials của 7 nền tảng QC (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) quản lý tập trung tại MOD-SETTINGS-GW — connection profile, credentials vault, field mapping, import/export template cho phần mềm kế toán VAS cùng cơ chế vendor-agnostic, KHÔNG hardcode tên phần mềm | Feed từ nguồn không có connection profile `ACTIVE` bị từ chối nạp; cấu hình sync đặt ngoài Settings không được service công nhận |
| BR-002 | **Nhãn nguồn bắt buộc (BR-FIN-205):** mọi số liệu đưa vào đối soát phải mang nhãn `api` hoặc `manual`; dữ liệu `manual` đối soát như luồng API (cùng pipeline, cùng kiểm định); không tồn tại luồng nhập tự do dạng text | Record thiếu nhãn nguồn bị chặn trước khi vào fact tables; pipeline đối soát từ chối record không hợp lệ |
| BR-003 | **Schema import chuẩn:** bắt buộc đủ 8 trường — nền tảng, TKQC, ngày, loại giao dịch, số tiền gốc, tiền tệ, phí, mã tham chiếu; dòng sai schema bị chặn và trả lỗi từng dòng để FIN_L1 sửa rồi nạp lại; nhập tay theo schema có cấu trúc giống hệt | Import fail schema → trả lỗi từng dòng + giữ file gốc trong audit; không tự nạp "phần tốt"; nhập tay ngoài schema bị service chặn |
| BR-004 | **Degraded mode "manual" + backfill (DI-007):** Business Verification chưa có quyền API developer — 7 nền tảng vận hành degraded; khi mất quyền, service gắn nhãn `manual` cho dữ liệu; khi được cấp API, backfill tự động chạy cho các kỳ đã nhập tay và trigger đối soát lại; chênh lệch manual vs API >±0,1% đưa vào báo cáo đối soát | Cấp quyền mà không phát sinh backfill task bị cảnh báo; chênh lệch >±0,1% buộc tạo ticket đối soát, không âm thầm ghi đè |
| BR-005 | **Freshness & chống fail lặng:** dữ liệu chi tiêu cấp cho consumer phải tươi ≤1h (khớp BR-FIN-104); job sync fail → retry/backoff tự động + alert; nền tảng không có API statement → đối soát hạ tuần, bù khớp tích lũy khi có API | Dữ liệu quá hạn freshness bị gắn cờ "ổi" cho consumer; sync fail quá ngưỡng retry phát alert FIN_L2/BOD_CFO_CTO qua alert center (REQ-BOD-006) |
| BR-006 | **Hai kênh nhập duy nhất:** WEB không cho nhập số đối soát ngoài 2 kênh chuẩn (import statement / nhập tay có cấu trúc) — enforcement ở service layer; mỗi dòng nhập tay bắt buộc ghi người nhập + căn cứ (timestamp + user id + evidence) | Endpoint ngoài 2 kênh không tồn tại ở API contract; request "nhập nhanh" không evidence bị từ chối + log |
| BR-007 | **Cấu hình chính sách/tham số quản trị (ngưỡng, tier, SLA):** tham số sync (lịch pull, ngưỡng freshness, dung sai chênh lệch, SLA alert) chỉ ADMIN (SYS_ADMIN sau duyệt) và BOD sửa, bắt buộc effective-dated + version + audit; không sửa hồi tố | WRITE từ vai khác bị chặn 403; ghi thiếu version/ngày hiệu lực bị từ chối; mọi thay đổi trace về audit log bất biến |
| BR-008 | **Dữ liệu feed theo tenant:** platform feed gắn tenant qua TKQC thuộc registry Ad Account CC (REQ-OPS-001); mọi truy vấn fact tables lọc bắt buộc theo tenant context — Portal khách (REQ-FIN-017) chỉ đọc qua view tổng hợp đã lọc | Truy vấn chéo tenant trả rỗng + log vi phạm; consumer không khai báo tenant context không được cấp dữ liệu |
| BR-009 | **Raw payload là căn cứ đối chiếu:** mọi feed (kể cả manual) giữ tham chiếu raw payload/source document; audit log immutable hash-chain WORM ≥10 năm (REQ-FIN-012) | Record thiếu tham chiếu nguồn bị chặn; nỗ lực sửa/xóa audit bị chặn ở tầng dữ liệu append-only |
| BR-010 | **Audit + enforce ở service:** mọi kiểm định schema, gán nhãn, backfill, cảnh báo thực thi tại tầng service của core backend — UI chỉ hiển thị; không có logic nghiệp vụ tin vào client-side validation | Lỗi bỏ qua validation UI không ảnh hưởng tính toàn vẹn dữ liệu; code nghiệp vụ đặt ở UI bị chặn ở review kiến trúc |

---

## 4. Phân Quyền

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN | OPS/SALES/HR khác | CUSTOMER (portal) |
|-----------|--------|--------|-------------|-----------|-------------------|-------------------|
| Xem trạng thái sync & tuổi dữ liệu | ✅ | ✅ | ✅ | ✅ | ❌ (chỉ qua alert) | ❌ |
| Import statement chuẩn (kênh 1) | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Nhập tay có cấu trúc (kênh 2) | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Sửa/nạp lại dòng lỗi schema | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Xem nhãn nguồn `api`/`manual` trong báo cáo | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Duyệt báo cáo chênh lệch manual vs API | ❌ | ✅ | ✅ (vượt ngưỡng trọng yếu) | ❌ | ❌ | ❌ |
| Sửa tham số sync (lịch, freshness, dung sai) | ❌ | ❌ | ✅ (phê duyệt) | ✅ (thực thi sau duyệt) | ❌ | ❌ |
| Xem dữ liệu feed tenant mình | ❌ | ✅ | ✅ | ❌ | ❌ | ✅ (read-only, view tổng hợp đã lọc) |
| Xem raw payload/source document | ✅ | ✅ | ✅ | ✅ (kỹ thuật) | ❌ | ❌ |
| Xóa/sửa dữ liệu feed đã nạp | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (chỉ qua điều chỉnh được duyệt — REQ-FIN-003) |

> Ghi chú: màn thao tác import/nhập tay nằm ở SYS-BCERP-WEB; bảng trên mô tả quyền ở tầng service — mọi hành động ghi audit log bất biến (ai, khi nào, dòng nào, căn cứ gì). FIN_L1 import cũng ràng buộc SoD: người nhập ≠ người duyệt điều chỉnh phát sinh sau đối soát (BR-FIN-106).

---

## 5. Trường Hợp Đặc Biệt

- **Chưa có quyền API developer (hiện trạng — DI-007):** 7 nền tảng chạy degraded mode "manual"; FIN_L1 import statement chuẩn + nhập tay có cấu trúc; pipeline đối soát vẫn chạy đủ như luồng API; khi Business Verification được cấp, backfill là nghĩa vụ tự động chứ không phải dự án riêng.
- **Nền tảng không cung cấp API statement:** đối soát chuyển chu kỳ hạ tuần; số liệu bù khớp theo tích lũy khi API có sẵn — service đánh dấu riêng các kỳ "bù khớp tích lũy" để FIN_L2 không nhầm kỳ đã khớp chuẩn.
- **Import fail schema hàng loạt:** service trả lỗi từng dòng, giữ dòng hợp lệ trong staging chờ FIN_L1 sửa rồi nạp lại; không tự động "nạp phần tốt bỏ phần lỗi" — tránh số liệu nửa vời vào đối soát.
- **Số liệu manual không khớp lệnh nào:** dữ liệu vẫn vào hệ thống với nhãn `manual` và ticket chờ đối chiếu — cấm ghi "gần đúng" vào ví khách (biên giới với BR-FIN-103).
- **Consumer ngoài tài chính:** Ad Account CC (REQ-OPS-001) và cảnh báo ví (REQ-OPS-003/REQ-FIN-002) tiêu thụ fact tables qua service layer, freshness ≤1h; nguồn degraded lâu → consumer nhận cờ "dữ liệu ôi" — danh mục cờ cảnh báo đầy đủ (K6–K12) chưa chốt `[KXN-20]`: ngưỡng phát cờ cấu hình qua tham số quản trị và mở rộng khi KXN-20 được xác nhận, không tự quyết tại spec này.
- **Khách yêu cầu xuất dữ liệu tenant mình:** xuất qua view đã lọc tenant, có watermark + disclaimer độ trễ (REQ-FIN-017) — không xuất raw payload nền tảng cho khách.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Sync Job (chu kỳ pull/ tiếp nhận feed của 1 nền tảng)

**Sơ đồ trạng thái:**
```
[QUEUED] ──(đến lịch)──► [RUNNING] ──(thành công)──► [SUCCESS]
                            │  │                        │
                            │  └──(lỗi)──► [RETRYING] ──┤ (hết số lần retry / vượt SLA)
                            │                 │         ▼
                            │                 └────► [DEGRADED_ALERT] ──(khôi phục)──► [BACKFILL] ──► [SUCCESS]
                            │
                            └──(nguồn mất quyền API)──► [MANUAL_MODE] ──(được cấp API)──► [BACKFILL] ──► [SUCCESS]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `QUEUED` | Đến lịch sync | `RUNNING` | Hệ thống (scheduler) | Profile nguồn `ACTIVE` (FEAT-CORE-STGW-001) |
| `RUNNING` | Sync thành công | `SUCCESS` | Hệ thống | Feed qua kiểm định schema; record nhãn `api` |
| `RUNNING` | Lỗi tạm thời (rate limit, timeout) | `RETRYING` | Hệ thống | Retry/backoff tự động theo lịch cấu hình |
| `RETRYING` | Hết số lần retry / vượt SLA | `DEGRADED_ALERT` | Hệ thống | Alert FIN_L2/BOD_CFO_CTO; freshness gắn cờ "ổi" cho consumer |
| `RUNNING`/`QUEUED` | Nguồn mất quyền API | `MANUAL_MODE` | Hệ thống (tự động) | Dữ liệu gắn nhãn `manual`; luồng import/manual mở cho FIN_L1 |
| `MANUAL_MODE` | Được cấp API/Business Verification | `BACKFILL` | Hệ thống (tự lập task) | Backfill tạo cho các kỳ đã nhập tay; sai khác >±0,1% đẩy báo cáo đối soát |
| `DEGRADED_ALERT` | Nguồn hồi phục | `BACKFILL` → `SUCCESS` | Hệ thống | Bù khớp tích lũy các kỳ thiếu trước khi quay lại chu kỳ thường |

**Quy tắc:**
- Không quay về `SUCCESS` trực tiếp từ `MANUAL_MODE`/`DEGRADED_ALERT` — bắt buộc qua `BACKFILL` để đối soát lại các kỳ đã nhập tay.
- `SUCCESS` không vĩnh viễn: chu kỳ tiếp theo tạo job mới; record đã nạp không sửa/xóa (append-only).
- Mọi chuyển trạng thái ghi audit log bất biến; alert chỉ phát qua alert center (REQ-BOD-006).

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `platform_feed_record` | `platform` (7 enum), `ad_account_id`, `entry_date`, `entry_type`, `amount_original`, `currency`, `fee`, `ref_code`, `source_label` (api/manual), `tenant_id` | FK → `ad_accounts.id` (REQ-OPS-001), `tenants.id` | Append-only; nhãn nguồn bắt buộc |
| `import_batch` | `imported_by`, `imported_at`, `evidence_ref`, `total_lines`, `valid_lines`, `status` | FK → `users.id`; 1–N `platform_feed_record` | Kênh import; ghi ai nhập + căn cứ |
| `import_line_error` | `batch_id`, `line_no`, `error_code`, `raw_line` | FK → `import_batch.id` | Báo lỗi từng dòng |
| `manual_entry` | `entered_by`, `entered_at`, `evidence_ref`, `payload_json` (schema 8 trường) | FK → `users.id`; sinh record nhãn `manual` | Schema có cấu trúc; không nhập tự do text |
| `sync_job` | `platform`, `profile_id`, `scheduled_at`, `started_at`, `finished_at`, `status`, `retry_count` | FK → `connection_profile.id` (FEAT-CORE-STGW-001) | Trạng thái theo state machine mục 6 |
| `backfill_task` | `platform`, `period_from`, `period_to`, `status`, `recon_recheck` | FK → `sync_job.id` | Tự sinh khi cấp lại quyền API |
| `freshness_flag` | `platform`, `tenant_id`, `data_as_of`, `flag` (fresh/stale) | FK → `platform_feed_record.id` | Cấp cho consumer ≤1h; cờ "ổi" khi vượt freshness |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — phác thảo sơ bộ ở Phase 2; chi tiết hóa ở Phase 5.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Feed API gán nhãn đúng | Nền tảng có quyền API, profile `ACTIVE` | Sync job chạy thành công | Record vào fact tables nhãn `api`, tham chiếu raw payload, tenant đúng | [ ] |
| SC-002: Import sai schema bị chặn | FIN_L1 import file thiếu "mã tham chiếu" ở dòng 12 | Service kiểm định | Dòng 12 bị chặn kèm lỗi cụ thể; không dòng nào "nạp gần đúng"; sửa và nạp lại được | [ ] |
| SC-003: Nhập tay có evidence | Nền tảng ở `MANUAL_MODE` | FIN_L1 nhập tay đủ 8 trường | Record nhãn `manual`, ghi user + timestamp + căn cứ; đối soát nhận như luồng API | [ ] |
| SC-004: Backfill khi được cấp API | Các kỳ đã nhập tay ở giai đoạn manual | Quyền API được cấp | Backfill task tự sinh, đối soát lại các kỳ, sai khác >±0,1% vào báo cáo đối soát | [ ] |
| SC-005: Sync fail có alert | Job sync lỗi vượt số lần retry | Hệ thống xử lý | Retry/backoff theo lịch rồi `DEGRADED_ALERT` phát alert FIN_L2/BOD_CFO_CTO; consumer nhận cờ dữ liệu ổi | [ ] |
| SC-006: Freshness ≤1h | Dữ liệu chi tiêu tiêu thụ bởi cảnh báo ví | Consumer truy vấn | Dữ liệu trả về tuổi ≤1h hoặc gắn cờ stale rõ ràng — không trả số cũ không nhãn | [ ] |
| SC-007: Tham số chỉ BOD/ADMIN sửa | FIN_L1/OPS vai bất kỳ | Gọi API sửa lịch sync/ngưỡng freshness | Chặn 403 + log; thay đổi hợp lệ có version + ngày hiệu lực + audit | [ ] |
| SC-008: Tenant isolation | 2 khách khác nhau cùng nền tảng | Consumer truy vấn dữ liệu feed | Mỗi truy vấn chỉ thấy tenant của phiên; Portal chỉ đọc view tổng hợp đã lọc | [ ] |

> **Liên kết:** SC-001→004, SC-007 map REQ-FIN-005; SC-002/SC-003 map BR-FIN-205; SC-005/SC-006 map REQ-OPS-003/REQ-FIN-002 (dữ liệu cấp ví); SC-008 map REQ-FIN-017/REQ-OPS-001.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI (trạng thái sync, import/nhập tay — counterpart WEB) | `phase4-ux/bcerp-web/settings-gw/*.md` |
| Bản GW của cùng REQ (adapter, rate limit) | `phase2-features/integration-gw/settings-gw/*.md` |
| Tính năng Settings/vault cùng module | `phase2-features/core-backend/settings-gw/quan-tri-integration-gateway-va-credentials-vault-vai-cto.md` |
| Nguồn nghiệp vụ gốc | `phase1-business/departments/finance/finance.md` (A3 REQ-FIN-005, B.2 BR-FIN-205, B.3 BR-FIN-301) · `_meta/req-registry.json` |
| Quyết định deferred liên quan | `work/wf-analyze-requirements/deferred-issues.md` (DI-004, DI-007) |
