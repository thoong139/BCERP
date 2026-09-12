# Tính Năng: Quản trị Integration Gateway & Credentials Vault (vai CTO)

> **Dựa trên:** REQ-BOD-008 trong `phase1-business/departments/bod/bod.md` (Phần A, Mục REQ-BOD-008; Phần B, Mục B8)
> **Phân hệ:** Quản trị Cấu Hình & Integration Gateway (SYS-BCERP-WEB)
> **Module:** Quản trị Gateway & Vault (MOD-SETTINGS-GW)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/settings-gw/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/settings-gw/feat-erp-stgw-001-impl.md`

> **Fan-out:** REQ-BOD-008 xuất hiện ở 3 hệ thống — đây là bản riêng cho touchpoint **SYS-BCERP-WEB** (web nội bộ responsive Next.js cho nhân viên BC: form/list/workflow UI, gọi API core, hiển thị đúng trạng thái machine-state). Counterparts: SYS-INTEGRATION-GW (vận hành vault + adapter + sync scheduler), SYS-CORE-BACKEND (MFA TOTP, audit log bất biến, enforcement phân quyền). Business rule enforce ở service layer; WEB chỉ là bề mặt thao tác có kiểm soát và hiển thị trạng thái.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-STGW-001 |
| Module | MOD-SETTINGS-GW (SYS-BCERP-WEB) |
| Yêu cầu nghiệp vụ | REQ-BOD-008; liên quan chéo REQ-FIN-013 (connector VAS là một kết nối ngoại vi được quản lý bởi Settings — DI-004) |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO (CTO/Super Admin), SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP) |
| Phụ thuộc | REQ-BOD-011 — RBAC & SSO/MFA tập trung (MFA TOTP và nền phân quyền phải có trước khi mở console vault) |
| Ghi chú Expert (A7) | A7 của `bod.md` chưa có điều chỉnh chính thức (chờ expert review). Các kết luận đã chốt ở Phần B (B8) được giữ nguyên trong spec này: MFA bắt buộc mọi tài khoản quản trị vault (BR-BOD-008.1), MOBILE cấm toàn bộ thao tác vault (BR-BOD-008.2), degraded mode có kiểm soát kèm backfill khi được cấp quyền API (BR-BOD-008.3) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cung cấp console quản trị trên web nội bộ để BOD_CFO_CTO (vai CTO/Super Admin) quản trị vòng đời kết nối ngoại vi của BCERP: credentials vault cho API 7 nền tảng quảng cáo, connection profile cho các kết nối ngoài (trong đó có phần mềm kế toán VAS), sync scheduler, cùng cấu hình chính sách/tham số quản trị — với nguyên tắc credentials là tài sản tương đương tiền, không bao giờ lộ plaintext và mọi thao tác đều để lại vết audit bất biến.

**Phạm vi:**
- Bao gồm:
  - Console web quản trị credentials 7 nền tảng QC (Meta, Google, TikTok, Bing, X, Pinterest, Yandex): thêm/sửa/rotate/thu hồi, theo dõi hạn rotate, cảnh báo đến hạn T-7.
  - Bảng sức khỏe 7 adapter (thành công/thất bại/degraded) + tuổi dữ liệu (freshness) từng nguồn, trạng thái sync scheduler trên 2.600+ tài khoản quảng cáo active.
  - Quản lý kết nối ngoại vi tập trung trong Settings theo quyết định DI-004 (12/09): connection profile, field mapping, import/export template cho phần mềm kế toán VAS — vendor-agnostic, không hardcode tên phần mềm; tên vendor cụ thể chỉ được cấu hình khi triển khai (DI-004 — giả định không chặn thiết kế).
  - Cấu hình chính sách/tham số quản trị (ngưỡng, tier, SLA) theo mô hình version effective-dated: chỉ BOD/ADMIN sửa, có ngày hiệu lực, có audit, không hồi tố.
  - Thu hồi khẩn credentials khi nghi ngờ rò rỉ hoặc liên quan nghỉ việc (revoke + rotate ≤24h, checklist xác nhận CTO).
  - Trình duyệt immutable audit log mọi thao tác vault và mọi lần gọi API nền tảng.
- Không bao gồm:
  - Vận hành adapter/queue/scheduler và lưu trữ vault thật sự — thuộc SYS-INTEGRATION-GW (counterpart riêng của REQ-BOD-008).
  - Enforcement MFA TOTP, hash-chain audit log, workflow duyệt change — thuộc SYS-CORE-BACKEND.
  - Luồng import statement/nhập tay dữ liệu đối soát và trạng thái sync phục vụ FIN — là FEAT-ERP-STGW-002 (REQ-FIN-005).
  - Bất kỳ thao tác vault nào trên mobile — MOBILE bị cấm tuyệt đối (BR-BOD-008.2), chỉ nhận alert sức khỏe adapter theo REQ-BOD-006.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CFO_CTO (CTO/Super Admin) | Đăng nhập console web với MFA TOTP và thêm/sửa/rotate/thu hồi credentials của 7 nền tảng QC ngay trong vault | Kiểm soát tập trung tài sản tương đương tiền mà giá trị secret không bao giờ hiển thị plaintext ở bất kỳ giao diện nào |
| 2 | BOD_CFO_CTO | Xem một màn hình duy nhất sức khỏe 7 adapter (thành công/thất bại/degraded) kèm tuổi dữ liệu từng nguồn và ngày rotate đến hạn của từng token | Chủ động phát hiện nguồn dữ liệu sắp đứt gãy trước khi số liệu đối soát sai |
| 3 | BOD_CFO_CTO | Thu hồi khẩn (revoke + rotate) credentials khi nghi ngờ rò rỉ hoặc khi nhân viên liên quan nghỉ việc, kèm checklist trong ≤24h | Chặn ngay rủi ro mất quyền điều hành ngân sách quảng cáo của khách hàng |
| 4 | SYS_ADMIN | Nhận change đã được CTO duyệt và thực thi cấu hình (connection profile, sync scheduler, tham số) sau phê duyệt | Tách bạch người soạn/thao tác vault và người thực thi cấu hình đúng change management, không tự ý gán hay sửa kể cả cho chính mình |
| 5 | SYS_ADMIN | Cấu hình kết nối ngoại vi kế toán VAS trong Settings (connection profile + field mapping + import/export template, vendor-agnostic) | Khi BC đổi phần mềm kế toán chỉ cần cấu hình lại, không phải phát hành lại code (DI-004 12/09) |
| 6 | BOD_CEO | Duyệt và ban hành phiên bản mới của chính sách/tham số quản trị (ngưỡng, tier, SLA) kèm ngày hiệu lực rõ ràng | Mọi thay đổi có version, có người duyệt, trace về audit log và không bao giờ hồi tố sửa quá khứ |
| 7 | BOD_CEO | Tra cứu immutable audit log mọi thao tác vault và mọi lần gọi API nền tảng ngay trên console | Giám sát độc lập hoạt động của CTO/SYS_ADMIN như một compensating control |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Enforcement chính nằm ở service layer (CORE/GW); WEB không được tự xử lý bỏ qua enforcement.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-STGW-101 | Quản lý kết nối ngoại vi tập trung trong Settings (quyết định DI-004 12/09): connection profile, credentials vault, field mapping, import/export template cho phần mềm kế toán VAS — vendor-agnostic, không hardcode tên phần mềm kế toán vào code hay UI | Console chỉ cho phép tạo kết nối theo danh mục loại connection profile đã định nghĩa; mọi yêu cầu hardcode vendor bị từ chối ở mức thiết kế và bị lint/review chặn |
| BR-STGW-102 | API 7 nền tảng QC (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) quản lý tập trung qua credentials vault + sync scheduler; rotate định kỳ ≥90 ngày; hệ thống cảnh báo token đến hạn rotate tại mốc T-7 | Không cho phép lưu credentials ngoài vault (kể cả config file, biến môi trường của web app); token quá hạn rotate bị đánh dấu `EXPIRING/EXPIRED` và hiển thị cảnh báo trên console |
| BR-STGW-103 | MFA TOTP bắt buộc cho mọi phiên đăng nhập console quản trị vault (BR-BOD-008.1); enforcement ở CORE, WEB thu step-up xác thực trước khi mở chức năng nhạy cảm | Phiên không qua MFA bị từ chối mở các màn vault/tham số; hành động vault từ phiên chưa step-up bị API chặn và ghi audit |
| BR-STGW-104 | Credentials chỉ tồn tại trong vault mã hóa của GW — WEB/API không bao giờ nhận hay hiển thị plaintext; UI chỉ hiển thị giá trị masked (vd: `••••last4`), trạng thái và ngày rotate | Bất kỳ endpoint nào trả secret dạng rõ ràng là lỗi nghiêm trọng (security defect chặn release); GET secret chỉ trả metadata |
| BR-STGW-105 | Mọi thao tác vault (thêm/sửa/rotate/thu hồi) và mọi lần gọi API nền tảng ghi immutable audit log (CORE hash-chain); hành vi quản trị vault không được ủy quyền | Thao tác không ghi được audit phải fail-closed (từ chối thực hiện); audit log không cho sửa/xóa, chỉ tra cứu và xuất có duyệt |
| BR-STGW-106 | SYS_ADMIN không tự gán/thay đổi cấu hình kể cả cho chính mình — chỉ thực thi sau khi change được CTO duyệt (change management); SYS_ADMIN thao tác qua API có log và không thấy plaintext | Yêu cầu thực thi không kèm change ID đã duyệt bị từ chối; attempt tự gán quyền bị log và đẩy vào kỳ quarterly access review (REQ-BOD-007) |
| BR-STGW-107 | Thu hồi khẩn khi nghi ngờ rò rỉ hoặc người liên quan nghỉ việc: revoke + rotate ≤24h theo checklist có xác nhận CTO; offboarding đột xuất chạy quy trình khẩn 24h; lệch chuẩn ghi nhận vào kỳ review | Không cho đóng checklist khẩn thiếu xác nhận CTO; quá 24h chưa hoàn tất bị cảnh báo đỏ cho BOD_CEO |
| BR-STGW-108 | Mọi integration phải có degraded mode `manual` + backfill khi mất quyền API (DI-007: Business Verification 7 nền tảng chưa có quyền developer); dữ liệu degraded gắn nhãn `manual`; chênh lệch manual vs API >±0,1% đưa vào báo cáo đối soát | Adapter không được phép ở trạng thái "đứng im không dữ liệu" — mất quyền API phải tự chuyển degraded và WEB hiển thị đúng trạng thái machine-state đó |
| BR-STGW-109 | Cấu hình chính sách/tham số quản trị (ngưỡng, tier, SLA) chỉ BOD/ADMIN được sửa, theo mô hình version effective-dated: hiệu lực theo ngày đã duyệt, không sửa quá khứ, mỗi version lưu người duyệt + trace audit (old → new) | Yêu cầu hiệu lực hồi tố bị CORE chặn tuyệt đối; SYS_ADMIN chỉ áp cấu hình sau duyệt, không tự chỉnh giá trị; tham số hiệu lực được báo cáo tra cứu đúng phiên bản tại thời điểm dữ liệu |
| BR-STGW-110 | MOBILE cấm toàn bộ thao tác vault (BR-BOD-008.2): console quản trị vault chỉ tồn tại trên SYS-BCERP-WEB; MOBILE chỉ nhận alert sức khỏe adapter, không hiển thị chi tiết credentials | Không phát hành bất kỳ endpoint mobile nào phục vụ thao tác vault; yêu cầu từ mobile bị API chặn ở tầng quyền bất kể client nào gọi |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN | Vai khác (nội bộ) |
|-----------|---------|-------------|-----------|--------------------|
| Xem danh sách kết nối + sức khỏe 7 adapter + freshness | ✅ | ✅ | ✅ | ❌ |
| Thêm/sửa connection profile, field mapping, import/export template (soạn thảo) | ❌ | ✅ | ✅ (chỉ soạn, theo change được duyệt) | ❌ |
| Quản trị credentials: thêm/sửa/rotate/thu hồi trong vault | ❌ | ✅ | ❌ | ❌ |
| Thực thi change đã duyệt (áp cấu hình lên môi trường) | ❌ | ❌ | ✅ | ❌ |
| Thu hồi khẩn credentials (revoke + rotate ≤24h) | ❌ | ✅ (ra lệnh + xác nhận checklist) | ✅ (thực thi sau lệnh CTO, có log) | ❌ |
| Xem giá trị credentials dạng plaintext | ❌ | ❌ | ❌ | ❌ (cấm tuyệt đối với mọi vai) |
| Soạn phiên bản mới chính sách/tham số (ngưỡng, tier, SLA) | ✅ (chính sách/định mức/tier) | ✅ (metric/ngưỡng freshness) | ❌ | ❌ |
| Ký duyệt ban hành version tham số effective-dated | ✅ | ✅ (theo phạm vi metric/freshness) | ❌ | ❌ |
| Xem audit log thao tác vault + log gọi API | ✅ | ✅ | ✅ (thao tác do mình thực hiện) | ❌ |

**Ghi chú phân quyền:**
- Chỉ 3 vai trên có quyền truy cập console; FIN_L1/FIN_L2 và các vai nghiệp vụ khác tiêu thụ dữ liệu integration một cách gián tiếp (qua dữ liệu đã sync), không có quyền quản trị vault hay kết nối.
- Nguyên tắc SoD: CTO soạn+duyệt change và thao tác vault; SYS_ADMIN thực thi cấu hình nhưng không thấy plaintext; BOD_CEO giám sát qua audit log và quarterly access review.
- Danh mục vai tuân thủ 18 vai registry (không tồn tại vai OPS_CX/FIN_COMPL — DI-006).

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Nghi ngờ rò rỉ token nền tảng:** CTO ra lệnh thu hồi khẩn từ console → revoke + rotate trong ≤24h theo checklist có xác nhận; mọi token dùng chung tài khoản đăng nhập nền tảng phải được rotate theo để không để lại quyền treo.
- **Nhân viên liên quan credentials nghỉ việc (kể cả đột xuất):** offboarding khẩn 24h — thu hồi quyền + rotate mọi credentials liên quan; checklist xác nhận CTO; nghỉ đột xuất vẫn chạy đúng quy trình khẩn, lệch chuẩn được ghi nhận vào kỳ access review quý.
- **Hãng thu hồi/quyết không cấp quyền API developer (DI-007 đang theo dõi):** adapter rơi vào degraded mode `manual` có kiểm soát — console hiển thị đúng trạng thái này và giữ lịch backfill tự động để kích hoạt khi được cấp quyền; không cho xóa connection profile chỉ vì mất quyền.
- **Đổi phần mềm kế toán VAS:** tạo connection profile mới + field mapping + import/export template mới trong Settings, không sửa code (vendor-agnostic theo DI-004); mapping/template cũ giữ nguyên ở tầng lịch sử để đối chiếu dữ liệu đã import theo profile cũ.
- **Sync 2.600+ tài khoản quảng cáo active:** scheduler phải chạy theo batch/queue chống rate limit; console hiển thị tiến độ và độ trễ từng đợt sync, không cho phép cấu hình "sync toàn bộ đồng loạt" gây vạ rate limit từ nền tảng.
- **Token đến hạn rotate khi CTO vắng:** cảnh báo T-7 phải đến được BOD_CEO (escalate) nếu quá hạn rotate mà chưa có thao tác; token hết hạn không tự xóa — giữ trạng thái `EXPIRED` để trace lịch sử.
- **SYS_ADMIN là đối tượng offboarding:** CTO (hoặc CEO nếu CTO vắng) thực hiện thu hồi quyền theo checklist; vì SYS_ADMIN không thấy plaintext nên thu hồi quyền không làm lộ secret; toàn bộ thao tác vẫn ghi audit bất biến.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Kết nối ngoại vi (IntegrationConnection) — áp dụng cho cả kết nối nền tảng QC lẫn kết nối kế toán VAS.

**Sơ đồ trạng thái:**
```
[ACTIVE] ──(mất quyền API / token hết hạn / adapter fail liên tiếp)──► [DEGRADED_MANUAL]
   ▲                                                                        │
   │                      (được cấp quyền API + backfill hoàn tất)          │
   └────────────────────────────────────────────────────────────────────────┘
   │
   ├──(thu hồi khẩn: nghi ngờ rò rỉ / offboarding)──► [REVOKED]
   └──(đình chỉ tạm thời do change/vệ trì)──► [SUSPENDED] ──(kích hoạt lại)──► [ACTIVE]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `ACTIVE` | Hệ thống phát hiện mất quyền API / token hết hạn | `DEGRADED_MANUAL` | Hệ thống (GW) | Adapter fail/token revoked — tự động, không cần thao tác người |
| `ACTIVE` | Thu hồi khẩn | `REVOKED` | BOD_CFO_CTO (ra lệnh), SYS_ADMIN (thực thi) | Checklist thu hồi khẩn có xác nhận CTO, hoàn tất ≤24h |
| `ACTIVE` | Đình chỉ tạm thời | `SUSPENDED` | BOD_CFO_CTO | Nhập lý do + phạm vi; ghi audit |
| `SUSPENDED` | Kích hoạt lại | `ACTIVE` | BOD_CFO_CTO (duyệt), SYS_ADMIN (áp) | Credentials hợp lệ trong vault, change đã duyệt |
| `DEGRADED_MANUAL` | Được cấp quyền API + bật adapter + backfill | `ACTIVE` | BOD_CFO_CTO (duyệt), SYS_ADMIN (áp) | Credentials mới hợp lệ; dữ liệu `manual` trong thời gian degraded đã đưa vào hàng chờ backfill |
| `REVOKED` | Tạo kết nối thay thế | `ACTIVE` (connection mới) | BOD_CFO_CTO | Connection mới có credentials vault riêng; connection `REVOKED` là trạng thái kết thúc, không khôi phục |

**Quy tắc:**
- Không thể quay về trạng thái trước tùy tiện: `REVOKED` là trạng thái kết thúc — chỉ tạo connection mới, không "hồi sinh" connection cũ.
- Chuyển sang `DEGRADED_MANUAL` luôn là chuyển trạng thái hệ thống (machine-state), WEB chỉ hiển thị — không ai được "tắt" trạng thái degraded bằng tay mà không qua backfill.
- Mọi chuyển trạng thái ghi audit log bất biến kèm actor, timestamp, lý do.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `integration_connection` | `id`, `connection_type` (ad_platform / vas_accounting / other), `vendor_key`, `name`, `status`, `degraded_since` | 1-N → `credential_entry`, `field_mapping`, `sync_schedule` | Vendor-agnostic; `vendor_key` là cấu hình không phải code |
| `credential_entry` | `id`, `connection_id`, `vault_ref`, `masked_hint`, `issued_at`, `rotate_due_at`, `status` (ACTIVE/EXPIRING/EXPIRED/REVOKED) | FK → `integration_connection.id` | Giá trị secret chỉ nằm trong vault GW; DB không chứa plaintext |
| `field_mapping` | `id`, `connection_id`, `source_field`, `target_field`, `transform_rule`, `version` | FK → `integration_connection.id` | Version + audit; dùng cho import/export VAS và statement |
| `import_export_template` | `id`, `connection_id`, `template_type`, `schema_version`, `column_spec` | FK → `integration_connection.id` | Vendor-agnostic; dùng chung cơ chế với FEAT-ERP-STGW-002 |
| `sync_schedule` | `id`, `connection_id`, `cron_expr`, `batch_size`, `rate_limit_policy`, `enabled` | FK → `integration_connection.id` | Chỉ sửa qua change được duyệt; log audit |
| `policy_parameter` | `id`, `param_key`, `value`, `effective_from`, `approved_by`, `version` | 1 version-N history | Effective-dated; không hồi tố; khóa theo ngày hiệu lực |
| `gateway_audit_event` | `id`, `actor_id`, `action`, `object_type`, `object_id`, `before`, `after`, `occurred_at` | Tham chiếu mọi entity trên | Immutable, hash-chain ở CORE; không UPDATE/DELETE |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được. Điền chi tiết ở Phase 5; dưới đây là phác thảo sơ bộ Phase 2.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Thêm credentials qua vault | CTO đã đăng nhập WEB với MFA TOTP | CTO thêm token API của 1 nền tảng trong số 7 nền tảng | Token lưu vào vault mã hóa; UI chỉ hiển thị masked hint; audit log ghi hành động; không có plaintext trong response bất kỳ API nào | [ ] |
| SC-002: Cảnh báo rotate T-7 | Một token có `rotate_due_at` còn 7 ngày | Hệ thống chạy job kiểm tra hạn | Console hiển thị trạng thái `EXPIRING`; alert gửi đúng người; nếu quá hạn chưa rotate → escalate BOD_CEO | [ ] |
| SC-003: Thu hồi khẩn ≤24h | CTO nghi ngờ rò rỉ token | CTO ra lệnh revoke + rotate | Connection chuyển `REVOKED`; checklist khẩn mở với đồng hồ 24h; SYS_ADMIN thực thi có log; hoàn tất phải có xác nhận CTO | [ ] |
| SC-004: SYS_ADMIN thực thi theo change | Có change được CTO duyệt | SYS_ADMIN áp cấu hình connection profile | Hệ thống chỉ chấp nhận khi có change ID hợp lệ; SYS_ADMIN không thấy plaintext; thao tác ghi audit | [ ] |
| SC-005: Tham số effective-dated không hồi tố | BOD_CEO soạn version mới của 1 tham số SLA | CEO duyệt với `effective_from` trong tương lai | Version mới chỉ áp dụng từ ngày hiệu lực; báo cáo tra cứu đúng phiên bản theo thời điểm dữ liệu; thử hiệu lực hồi tố bị chặn | [ ] |
| SC-006: Cấu hình VAS vendor-agnostic | Chưa có connection profile kế toán VAS | SYS_ADMIN tạo profile + field mapping + template mới trong Settings | Hoàn tất không cần deploy lại code; đổi vendor chỉ là tạo profile khác; dữ liệu lịch sử theo profile cũ còn nguyên | [ ] |
| SC-007: MOBILE bị chặn thao tác vault | Người dùng gửi request thao tác vault từ mobile client | Request đến API | API từ chối ở tầng quyền bất kể vai; alert sức khỏe adapter trên mobile không chứa chi tiết credentials | [ ] |

> **Liên kết:** SC-001→003, SC-007 map REQ-BOD-008 (Mục 2); SC-004 map REQ-BOD-008 + REQ-BOD-007; SC-005 map REQ-BOD-009; SC-006 map REQ-FIN-013 (DI-004).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (vault GW, adapter 7 nền tảng, connector VAS) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI (console quản trị Settings — Gateway) | `phase4-ux/bcerp-web/settings-gw/[screen-group].md` |
| Bản counterpart của cùng REQ | FEAT của REQ-BOD-008 tại SYS-INTEGRATION-GW và SYS-CORE-BACKEND |
