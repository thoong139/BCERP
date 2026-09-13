# Tính Năng: Quản trị Integration Gateway & Credentials Vault (vai CTO)

> **Dựa trên:** REQ-BOD-008 trong `phase1-business/departments/bod/bod.md` (Phần A, Phần B)
> **Phân hệ:** Integration Gateway (SYS-INTEGRATION-GW)
> **Module:** Settings & Gateway Config (MOD-SETTINGS-GW)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`, `phase1-business/departments/finance/finance.md` (REQ-FIN-013 / BR-FIN-305), `phase1-business/P1-02-business-workflow.md`, `work/wf-analyze-requirements/deferred-issues.md` (DI-004, DI-007)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-GW-STGW-001 |
| Module | MOD-SETTINGS-GW |
| Yêu cầu nghiệp vụ | REQ-BOD-008 — Quản trị Integration Gateway & credentials vault (vai CTO) (HIGH, MVP); cross-dependency: REQ-FIN-013 — connector VAS là 1 kết nối ngoại vi được quản lý bởi Settings (DI-004) |
| Người dùng liên quan | BOD_CFO_CTO (CTO/Super Admin — chủ quản vault), SYS_ADMIN (thực thi sau phê duyệt), BOD_CEO (phê duyệt chính sách, oversight); FIN_L2/FIN_L1 (người tiêu thụ kết nối VAS — chỉ xem trạng thái, thuộc bản REQ-FIN-013) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — phân hệ GĐ1; vault và adapter là nền cho toàn bộ dữ liệu nền tảng) |
| Phụ thuộc | REQ-BOD-011 — nền tảng RBAC & SSO/MFA tập trung tại SYS-CORE-BACKEND (MFA TOTP là điều kiện mở vault); REQ-BOD-007 — chu kỳ rotate/offboarding gắn quarterly access review; REQ-FIN-013 — phạm vi kết nối ngoại vi VAS cấu hình tại module này (DI-004) |
| Ghi chú Expert (A7) | bod.md Mục A7: chưa có đánh giá expert chính thức tại thời điểm viết (chờ review) — không có điều chỉnh nội dung; lưu ý A0 của bod.md đã chốt yêu cầu riêng của vai CTO cho REQ-BOD-008 và **cấm touchpoint mobile cho mọi thao tác vault** (giảm bề mặt tấn công) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng cung cấp tầng quản trị tập trung của Integration Gateway (SYS-INTEGRATION-GW): vault mã hóa cho credentials của 7 nền tảng quảng cáo (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) và các kết nối ngoại vi khác, kèm điều hành vòng đời adapter (thêm/sửa/rotate/thu hồi, theo dõi sức khỏe, cấu hình sync scheduler). Đây là hiện thực hóa quyết định DI-004 (12/09): **mọi kết nối ngoại vi được quản lý tập trung trong Settings** — connection profile, credentials vault, field mapping và import/export template đều là cấu hình, vendor-agnostic, không hardcode tên bất kỳ phần mềm nào (bao gồm phần mềm kế toán VAS hiện hữu của REQ-FIN-013).

**Phạm vi:**
- Bao gồm: registry connection profile cho các hệ thống ngoại vi (7 nền tảng QC, connector kế toán VAS theo REQ-FIN-013, các nguồn khác khai báo tương tự) — mỗi profile định nghĩa loại kết nối (API adapter hoặc import/export), endpoint/phan chế môi trường, chủ sở hữu, trạng thái.
- Bao gồm: credentials vault mã hóa (encryption at rest + in transit), chính sách rotate định kỳ ≥90 ngày với cảnh báo T-7, thu hồi khẩn khi nghi ngờ rò rỉ hoặc liên quan nghỉ việc (offboarding rotate ≤24h nối REQ-BOD-007).
- Bao gồm: bảng điều khiển sức khỏe 7 adapter — thành công/thất bại/degraded, tuổi dữ liệu (freshness) từng nguồn, hạn rotate còn lại, trạng thái sync scheduler.
- Bao gồm: cấu hình sync scheduler cho 2.600+ tài khoản QC theo batch/queue chống rate limit; bật/tắt adapter; kích hoạt degraded mode gắn nhãn `manual` và theo dõi backfill khi API được cấp lại (DI-007).
- Bao gồm: quản lý cấu hình chính sách/tham số quản trị của gateway (ngưỡng cảnh báo, tier dữ liệu, SLA sync) — chỉ ADMIN/BOD sửa, mỗi thay đổi có version + ngày hiệu lực + audit log.
- Bao gồm: log immutable mọi lần gọi API ra ngoài và mọi thao tác trên vault.
- Không bao gồm: luồng kéo số liệu số dư/chi tiêu và gắn nhãn nguồn `api`/`manual` cho dữ liệu đối soát — thuộc FEAT-GW-STGW-002 (REQ-FIN-005); tính năng này cung cấp hạ tầng adapter mà FEAT-GW-STGW-002 vận hành.
- Không bao gồm: business logic đối trừ 3 số, ledger ví, financial hard stop — thuộc SYS-CORE-BACKEND (MOD-WALLET-RECON, MOD-ADACCOUNT-CC).
- Không bao gồm: console quản trị web (thêm/sửa/rotate/thu hồi credentials, cấu hình sync) — thuộc bản counterpart SYS-BCERP-WEB của REQ-BOD-008; gateway là data plane thực thi, web là mặt thao tác.
- Không bao gồm: RBAC engine, MFA TOTP infrastructure, immutable audit store — thuộc SYS-CORE-BACKEND (REQ-BOD-011, REQ-FIN-012); gateway gọi và tuân thủ, không dựng lại.

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-INTEGRATION-GW — tầng gateway/adapter headless: các hành động quản trị được phát từ console web nội bộ (bản counterpart SYS-BCERP-WEB) nhưng thực thi và enforce tại service layer của gateway; không có UI riêng ở tầng này, mọi thao tác qua API có MFA step-up và ghi audit log. REQ-BOD-008 **không có touchpoint mobile nội bộ** — quản trị vault bị cấm trên mobile để giảm bề mặt tấn công (A0 bod.md, P1-02 §nền dùng chung).

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CFO_CTO (CTO/Super Admin) | Quản trị credentials vault của 7 nền tảng QC — thêm/sửa/rotate/thu hồi qua API gateway với MFA bắt buộc | Chỉ một nơi duy nhất giữ bí mật tích hợp, không credential nào nằm rải rác trong code/cấu hình |
| 2 | BOD_CFO_CTO | Xem sức khỏe 7 adapter (thành công/thất bại/degraded) và tuổi dữ liệu từng nguồn theo thời gian thực | Phát hiện sớm adapter hỏng, biết chính xác nguồn nào đang stale để ra quyết định |
| 3 | BOD_CFO_CTO | Nhận cảnh báo token đến hạn rotate (T-7) và thu hồi khẩn credentials khi nghi ngờ rò rỉ hoặc nhân sự liên quan nghỉ việc | Chặn khe hở bảo mật trước khi bị lợi dụng; tuân thủ chu kỳ access review của REQ-BOD-007 |
| 4 | SYS_ADMIN | Cấu hình sync scheduler (lịch pull, batch size, queue, retry/backoff) cho 2.600+ TKQC theo chỉ đạo đã được CTO phê duyệt | Vận hành đồng bộ hourly ổn định không vấp rate limit, không phải can thiệp tay |
| 5 | SYS_ADMIN | Khi adapter mất quyền API, chuyển kết nối sang degraded mode gắn nhãn `manual` và theo dõi tiến độ backfill khi quyền được cấp lại | Kinh doanh không tắc nghẽn trong khi chờ Business Verification (DI-007), dữ liệu không bị mất mốc |
| 6 | BOD_CEO | Xem báo cáo tổng quan gateway (số kết nối, trạng thái, sự cố, lịch sử rotate) và ký duyệt thay đổi chính sách kết nối | Giữ oversight độc lập với người vận hành; mọi thay đổi trace được về người duyệt |
| 7 | BOD_CFO_CTO | Cấu hình connection profile + field mapping + import/export template cho connector phần mềm kế toán VAS như một kết nối ngoại vi bình thường trong Settings | REQ-FIN-013 triển khai vendor-agnostic (DI-004) — đổi phần mềm kế toán chỉ là thêm 1 profile, không sửa code |
| 8 | FIN_L2 | Xem trạng thái kết nối VAS (đang hoạt động/lỗi/hàng chờ xuất) để lên lịch đối chiếu sổ | Biết khi nào dữ liệu đã sẵn sàng cho đối soát mà không cần quyền quản trị vault |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-GW-STGW-001 | **Quản lý kết nối ngoại vi tập trung trong Settings (DI-004, quyết định 12/09):** mọi hệ thống ngoại vi (7 nền tảng QC, phần mềm kế toán VAS, nguồn khác) phải được khai báo dưới dạng connection profile trong MOD-SETTINGS-GW — gồm connection profile, credentials vault, field mapping, import/export template — theo hướng vendor-agnostic, KHÔNG hardcode tên phần mềm nào trong code; tên phần mềm kế toán cụ thể chỉ được nạp khi triển khai dưới dạng giá trị cấu hình | Từ chối tạo/kích hoạt connector nằm ngoài registry Settings; build fail/merge reject khi phát hiện vendor name hardcode trong service layer |
| BR-GW-STGW-002 | **API 7 nền tảng QC (Meta, Google, TikTok, Bing, X, Pinterest, Yandex):** mỗi nền tảng có đúng 1 adapter + credentials riêng trong vault + sync scheduler riêng; credentials được mã hóa (at rest và in transit), KHÔNG BAO GIỜ hiển thị plaintext ở bất kỳ giao diện, API response hay log nào — chỉ cho phép ghi giá trị mới và tham chiếu qua ID | Từ chối render/return giá trị credential; mọi phản hồi chỉ chứa mask (vd `****last4`) + metadata (ngày tạo, lần rotate cuối) |
| BR-GW-STGW-003 | **Degraded mode `manual` bắt buộc (DI-007):** mọi integration phải có chế độ suy giảm "manual" + cơ chế backfill khi mất quyền API — Business Verification 7 nền tảng hiện CHƯA có quyền developer, nên trạng thái khởi điểm của adapter là degraded; chuyển sang degraded phải tự động gắn nhãn nguồn dữ liệu `manual` (nối FEAT-GW-STGW-002) và khi API được cấp, backfill tự động chạy theo thứ tự thời gian, không ghi đè dữ liệu manual đã có căn cứ | Adapter không được phép ở trạng thái "fail câm" — mất quyền mà không chuyển degraded là lỗi P1; backfill không được xóa/ghi đè bản ghi `manual` đã đối soát |
| BR-GW-STGW-004 | **Cấu hình chính sách/tham số quản trị (ngưỡng, tier, SLA):** chỉ ADMIN/BOD (BOD_CEO, BOD_CFO_CTO) được sửa; mỗi thay đổi có version, ngày hiệu lực (effective-dated), người duyệt và audit log bất biến — không hồi tố sửa giá trị quá khứ (nối REQ-BOD-009) | SYS_ADMIN không có nút sửa tham số policy — chỉ xem; mọi attempt sửa ngoài vai bị RBAC chặn + log vi phạm |
| BR-GW-STGW-005 | **Độc quyền quản trị vault của CTO:** chỉ BOD_CFO_CTO (CTO/Super Admin) quản trị vault; SYS_ADMIN chỉ thực thi thao tác đã được phê duyệt; MFA TOTP bắt buộc cho mọi thao tác ghi lên vault; MOBILE-INTERNAL cấm toàn bộ thao tác vault (không có endpoint vault cho mobile) | Yêu cầu không kèm MFA hợp lệ bị từ chối; request vault từ touchpoint mobile bị từ chối ở tầng gateway + log cảnh báo bảo mật |
| BR-GW-STGW-006 | **Rotate định kỳ ≥90 ngày + thu hồi khẩn:** hệ thống theo dõi hạn rotate từng credential, cảnh báo T-7; thu hồi khẩn khi nghi ngờ rò rỉ hoặc credential liên quan nhân sự nghỉ việc — offboarding phải rotate ≤24h kèm checklist CTO xác nhận (nối REQ-BOD-007); rotate thu hồi khẩn phải vô hiệu token cũ tức thì tại nền tảng ở mức khả thi | Credential quá hạn rotate >7 ngày → adapter tự chuyển degraded + alert CTO; offboarding không rotate trong 24h → escalation CEO |
| BR-GW-STGW-007 | **Audit bất biến:** mọi thao tác vault (xem mask, tạo, sửa, rotate, thu hồi) và mọi lần gọi API ra hệ thống ngoài đều ghi audit log bất biến (append-only, hash-chain — hạ tầng dùng chung REQ-FIN-012); việc xem log cũng bị log | Không có API sửa/xóa audit entry; bất thường hash-chain kích hoạt alert BOD (REQ-BOD-005) |
| BR-GW-STGW-008 | **Sync scheduler chống rate limit:** pull cho 2.600+ TKQC chạy qua batch/queue với retry + backoff; giới hạn tốc độ theo quota từng nền tảng; job sync fail → retry tự động + alert (gộp alert theo nguồn khi connector outage để không ngập người nhận); scheduler không chạy song song 2 job cùng adapter trừ khi cấu hình cho phép | Job fail vượt số lần retry → adapter degraded + alert; phát hiện job chồng lấn → từ chối kích hoạt và ghi log |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN | FIN_L1 | FIN_L2 |
|-----------|---------|-------------|-----------|--------|--------|
| Xem báo cáo sức khỏe adapter + trạng thái kết nối | ✅ | ✅ | ✅ | ✅ | ✅ |
| Xem credentials (dạng mask, không plaintext) | ❌ | ✅ | ✅ (sau phê duyệt) | ❌ | ❌ |
| Thêm/sửa connection profile (7 nền tảng QC, VAS, nguồn mới) | ❌ | ✅ | ✅ (thực thi sau phê duyệt CTO) | ❌ | ❌ |
| Rotate credentials định kỳ | ❌ | ✅ | ✅ (thực thi sau phê duyệt) | ❌ | ❌ |
| Thu hồi khẩn credentials | ❌ (phê duyệt khẩn) | ✅ | ❌ (chỉ CTO) | ❌ | ❌ |
| Cấu hình sync scheduler (lịch, batch, retry) | ❌ | ✅ (duyệt) | ✅ (thực thi) | ❌ | ❌ |
| Kích hoạt/tắt degraded mode `manual` | ❌ | ✅ | ✅ (thực thi sau phê duyệt) | ❌ | ❌ |
| Theo dõi tiến độ backfill | ❌ | ✅ | ✅ | ✅ (xem nguồn liên quan đối soát) | ✅ |
| Sửa chính sách/tham số quản trị (ngưỡng, tier, SLA) | ✅ (duyệt/ban hành) | ✅ (đề xuất/duyệt) | ❌ | ❌ | ❌ |
| Xem cấu hình field mapping/import-export template VAS | ❌ | ✅ | ✅ | ✅ | ✅ |
| Xem audit log vault + API calls | ✅ | ✅ | ❌ (bị log khi xem qua luồng chung) | ❌ | ❌ |
| Quản trị vault từ touchpoint mobile | ❌ | ❌ (cấm — BR-GW-STGW-005) | ❌ (cấm) | ❌ | ❌ |

> Quy ước SoD theo REQ-BOD-007: SYS_ADMIN không tự gán quyền kể cả cho chính mình — mọi thao tác vault của SYS_ADMIN chỉ là thực thi sau phê duyệt của BOD_CFO_CTO; mọi thay đổi gán/thu hồi vai liên quan gateway phải qua phê duyệt BOD_CEO.

---

## 5. Trường Hợp Đặc Biệt

- **Chưa có quyền API developer (DI-007 — trạng thái hiện tại):** Business Verification với 7 nền tảng chưa hoàn tất nên adapter khởi điểm ở degraded mode `manual`; hệ thống phải vận hành đầy đủ ở trạng thái này (import/nhập tay có cấu trúc theo FEAT-GW-STGW-002) và có sẵn tiến trình theo dõi song song — khi quyền được cấp, backfill tự động kích hoạt theo thứ tự thời gian và đối soát lại các kỳ đã nhập tay `[KXN-7]` — thời điểm cấp quyền từng nền tảng chưa xác định, spec không gắn mốc cứng.
- **Nghỉ việc đột xuất của người nắm credential:** offboarding khẩn 24h — thu hồi + rotate toàn bộ credential liên quan theo checklist CTO xác nhận; lệch chuẩn ghi nhận vào kỳ quarterly access review (nối REQ-BOD-007).
- **Nghi ngờ rò rỉ credential:** thu hồi khẩn tức thì toàn bộ credential cùng nền tảng, adapter tự chuyển degraded `manual` để nghiệp vụ không tắc, điều tra bảo mật diễn ra song song; sau rotate, backfill lấy lại dữ liệu bị đứt.
- **Connector outage một nguồn:** alert được gộp theo nguồn và ưu tiên theo mức độ — không bắn từng job fail riêng lẻ làm ngập người nhận (quy tắc alert REQ-BOD-006); các nguồn còn lại hoạt động độc lập, không dây chuyền.
- **Phần mềm kế toán VAS chỉ hỗ trợ import file (không có API):** theo BR-FIN-305, connection profile khai báo loại kết nối import/export — gateway xuất file chuẩn schema + log lượt xuất; cấu hình mapping làm tại Settings không sửa code `[KXN-9]` — cơ chế kết nối chính xác của VAS chưa xác định, profile phải đủ tổng quát cho cả 2 trường hợp API và file.
- **Schema API nền tảng thay đổi (phiên bản mới):** adapter phát hiện lỗi parse → degraded + alert CTO; raw payload lưu trước khi parse (nối FEAT-GW-STGW-002) để reprocess sau khi vá mapping — mapping là cấu hình, không phải code.
- **Quy mô 2.600+ TKQC active:** batch/queue phải chia nhỏ theo quota từng nền tảng và đảm bảo hoàn tất cửa sổ hourly; nếu không kịp, ưu tiên TKQC đang active chi tiêu, TKQC tạm ngưng xếp vòng sau — cấu hình ưu tiên nằm trong Settings.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Connection Profile / Adapter (mỗi kết nối ngoại vi — 7 nền tảng QC, connector VAS, nguồn khác)

**Sơ đồ trạng thái:**
```
[DRAFT] ──(activate, MFA)──► [ACTIVE] ──(mất quyền API / job fail liên tục)──► [DEGRADED]
                                  │  ▲                                              │
                                  │  └──────(backfill hoàn tất + health OK)─────────┤
                                  │                                                │ (backfill khi được cấp quyền)
                                  ├──(disable)──► [DISABLED] ◄──(disable)──────────┘
                                  └──(thu hồi khẩn)──► [REVOKED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Activate | `ACTIVE` | BOD_CFO_CTO | Credential đã nạp vault, MFA xác thực, health check đầu tiên thành công |
| `ACTIVE` | Mark degraded | `DEGRADED` | Hệ thống (tự động) hoặc BOD_CFO_CTO | Mất quyền API / job fail vượt ngưỡng retry; tự gắn nhãn dữ liệu `manual` |
| `DEGRADED` | Backfill | `ACTIVE` | Hệ thống | Quyền API được cấp lại; backfill chạy đủ khoảng đứt quãng, không ghi đè bản ghi `manual` đã đối soát |
| `ACTIVE`/`DEGRADED` | Disable | `DISABLED` | BOD_CFO_CTO | Nhập lý do; scheduler ngưng job; dữ liệu cũ giữ nguyên |
| `ACTIVE`/`DEGRADED` | Revoke | `REVOKED` | BOD_CFO_CTO | Thu hồi khẩn — vô hiệu token tức thì; bắt buộc rotate trước khi quay lại `ACTIVE` |
| `DISABLED`/`REVOKED` | Reactivate | `ACTIVE` | BOD_CFO_CTO | Credential mới trong vault + health check thành công + audit ghi căn cứ |

**Quy tắc:**
- `REVOKED` là trạng thái an toàn bắt buộc trước khi nạp credential mới — không cho phép "thay token tại chỗ" khi đang nghi ngờ rò rỉ.
- Mọi chuyển trạng thái ghi audit log bất biến kèm người thực thi và lý do; chuyển sang `DEGRADED` do hệ thống tự động phải có trigger có thể truy vết (job id, mã lỗi API).
- Trạng thái adapter là machine-state do gateway giữ — console web và mobile chỉ hiển thị, không tự tính.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| ConnectionProfile | `code`, `external_system` (enum: META/GOOGLE/TIKTOK/BING/X/PINTEREST/YANDEX/VAS/OTHER), `connection_type` (api_adapter / import_export), `status`, `owner_role`, `config_json` | 1 profile — N credentials; FK logic → vault | Vendor-agnostic; `external_system=VAS` không gắn tên phần mềm cứng |
| CredentialVersion | `profile_id`, `masked_value`, `encrypted_blob` (tham chiếu vault), `issued_at`, `rotate_due_at`, `status` (active/revoked/expired) | FK → `ConnectionProfile.id` | Plaintext chỉ tồn tại trong vault; rotate tạo version mới, giữ lịch sử |
| SyncSchedule | `profile_id`, `cadence` (hourly mặc định), `batch_size`, `queue_config`, `retry_policy`, `priority_rules` | FK → `ConnectionProfile.id` | Phục vụ 2.600+ TKQC; cấu hình do SYS_ADMIN thực thi sau duyệt CTO |
| AdapterHealthCheck | `profile_id`, `checked_at`, `result` (success/fail/degraded), `error_code`, `data_freshness` (tuổi dữ liệu nguồn) | FK → `ConnectionProfile.id` | Nguồn cho bảng sức khỏe 7 adapter + alert |
| PolicyConfigVersion | `param_key`, `value`, `version`, `effective_from`, `approved_by`, `reason` | Độc lập — tra cứu theo key + thời điểm hiệu lực | Ngưỡng/tier/SLA; chỉ ADMIN/BOD sửa; effective-dated, không hồi tố |
| FieldMapping | `profile_id`, `source_field`, `target_field`, `transform_rule`, `template_version` | FK → `ConnectionProfile.id` | Cho import/export template VAS và chuẩn hóa schema import (BR-FIN-205) |
| GatewayAuditLog | `actor_id`, `action`, `object_type`, `object_id`, `timestamp`, `before/after`, `hash_prev` | Append-only, hash-chain | Dùng chung hạ tầng REQ-FIN-012; bao gồm cả log lần gọi API ra ngoài |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Credential không bao giờ lộ plaintext | Credential đã nạp vault | Truy vấn qua web UI, API response và xem log hệ thống | Mọi nơi chỉ trả mask + metadata; không tồn tại endpoint trả plaintext; quét log không thấy giá trị gốc | [ ] |
| SC-002: MFA bắt buộc khi thao tác vault | BOD_CFO_CTO đã đăng nhập | Gọi API rotate credential không kèm MFA hợp lệ | Từ chối, ghi log attempt; thao tác chỉ thành công sau step-up MFA TOTP | [ ] |
| SC-003: Cảnh báo T-7 và rotate đúng hạn | Credential còn 7 ngày đến hạn rotate | Hệ thống chạy job kiểm tra hạn | Alert đến CTO; nếu quá hạn >7 ngày adapter tự chuyển `DEGRADED` + escalation | [ ] |
| SC-004: Thu hồi khẩn tức thì | Phát hiện nghi ngờ rò rỉ credential nền tảng Meta | CTO kích hoạt thu hồi khẩn | Token vô hiệu, adapter chuyển `DEGRADED` gắn nhãn `manual`, alert gộp theo nguồn, audit ghi căn cứ | [ ] |
| SC-005: Degraded mode có kiểm soát (DI-007) | Chưa có quyền API developer | Adapter khởi điểm và vận hành | Toàn bộ dữ liệu đi qua kênh manual có nhãn `manual`; khi được cấp quyền, backfill tự động chạy không ghi đè bản ghi manual đã đối soát | [ ] |
| SC-006: Chính sách chỉ ADMIN/BOD sửa, có version | Tham số SLA sync đang hiệu lực v3 | SYS_ADMIN gọi API sửa tham số; sau đó BOD_CFO_CTO sửa thành v4 | SYS_ADMIN bị RBAC chặn + log; v4 có version, ngày hiệu lực, người duyệt; v3 giữ nguyên lịch sử không hồi tố | [ ] |
| SC-007: Connector VAS không hardcode vendor | Connection profile VAS cấu hình theo DI-004 | Đổi tên/cơ chế phần mềm kế toán trong cấu hình | Chỉ sửa profile + field mapping tại Settings, không thay đổi code; profile hoạt động lại không cần deploy | [ ] |
| SC-008: Mobile cấm thao tác vault | Request quản trị vault gửi từ touchpoint mobile nội bộ | Gateway nhận request | Từ chối ở tầng gateway + cảnh báo bảo mật; mobile chỉ xem được trạng thái tổng hợp không chứa credential | [ ] |

> **Liên kết:** SC-001…SC-008 map về REQ-BOD-008 (Mục 2 — vault không plaintext, MFA, rotate/thu hồi khẩn, sức khỏe adapter, degraded có kiểm soát, tham số versioned, DI-004/DI-007).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/integration-gw/settings-gw/` (console quản trị thuộc bản counterpart SYS-BCERP-WEB) |
| Bản fan-out counterpart | `phase2-features/core-backend/settings-gw/` (MFA TOTP, audit store, job queue — REQ-BOD-008/011), `phase2-features/bcerp-web/settings-gw/` (console quản trị vault/adapter/scheduler) — REQ-BOD-008 xuất hiện ở 3 systems, bản này là riêng SYS-INTEGRATION-GW |
| Tính năng liền kề trong lane | `phase2-features/integration-gw/settings-gw/api-7-nen-tang-degraded-mode-manual.md` (FEAT-GW-STGW-002 — luồng dữ liệu vận hành trên hạ tầng adapter này) |
| Nguồn cross-dependency | REQ-FIN-013 / BR-FIN-305 (`phase1-business/departments/finance/finance.md`) — connector VAS là kết nối ngoại vi quản lý tại module này (DI-004); REQ-BOD-007 — chu kỳ rotate/offboarding; `work/wf-analyze-requirements/deferred-issues.md` (DI-004, DI-007) |
