# Tính Năng: Phê Duyệt Chính Sách, Tham Số Quản Trị & Tier

> **Dựa trên:** REQ-BOD-009 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** BCERP Core Backend (SYS-CORE-BACKEND)
> **Module:** RBAC & Audit Log (MOD-RBAC-AUDIT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/rbac-audit/[screen-group].md`, `phase5-implementation/tasks/core-backend/rbac-audit/feat-core-rbac-004-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-RBAC-004 |
| Module | MOD-RBAC-AUDIT |
| Yêu cầu nghiệp vụ | REQ-BOD-009 |
| Người dùng liên quan | BOD_CEO (chính sách, định mức, tier), BOD_CFO_CTO (định nghĩa metric, ngưỡng freshness), SYS_ADMIN (áp cấu hình sau duyệt) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP) |
| Phụ thuộc | FEAT-CORE-RBAC-005 (nền tảng RBAC & SSO/MFA tập trung — phân quyền soạn/duyệt/áp); FEAT-CORE-RBAC-002 (mọi thay đổi tham số trace về audit log hash-chain) |
| Ghi chú Expert (A7) | bod.md Mục A7 chưa ghi điều chỉnh nào sau Expert Review — spec bám nguồn Phần B (B9) của bod.md; ngưỡng 5/50/200 triệu VND đã chốt làm mức mặc định tại phiên duyệt 12/09 (DI-001) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**

Là cửa duyệt duy nhất cho mọi chính sách, tham số quản trị và tham số tier của BCERP: ma trận hạn mức chi/giải ngân (5/50/200 triệu VND), định mức giá/Cost Rate Card, khung SLA theo tier, tham số Tier A–E, ngưỡng freshness dữ liệu. Mọi tham số vận hành theo mô hình effective-dated — hiệu lực theo ngày đã duyệt, version hóa đầy đủ, không hồi tố — để báo cáo và luồng nghiệp vụ tại bất kỳ thời điểm nào đều dùng đúng định nghĩa hiệu lực lúc đó.

**Phạm vi:**

- Bao gồm:
  - Version store tham số: soạn thảo version nháp kèm ngày hiệu lực đề xuất → duyệt → ban hành theo ngày hiệu lực; mỗi version lưu version, ngày hiệu lực, người duyệt.
  - Phân nhánh thẩm quyền duyệt: chính sách/định mức/tier/ma trận hạn mức → BOD_CEO; định nghĩa metric + ngưỡng freshness → BOD_CFO_CTO.
  - API lookup "tham số hiệu lực tại thời điểm X" cho mọi phân hệ (quotation, dealdesk, SLA engine, alert engine, P&L).
  - Chu kỳ rà soát tham số Tier A–E theo quý, gắn vào chu kỳ access review.
  - Trace toàn bộ thay đổi (old → new) về audit log hash-chain với reason code.
- Không bao gồm:
  - Trình duyệt và ký duyệt trên giao diện web — do SYS-BCERP-WEB (counterpart); bản này là API/domain service.
  - Nội dung định nghĩa từng metric BI cụ thể — thuộc phân hệ BI/DATAHUB (REQ-BOD-004); bản này quản vòng đời version + duyệt, không định nghĩa công thức thay Metric Catalog.
  - Duyệt giao dịch tiền vượt ngưỡng (luồng lệnh chi cụ thể) — thuộc tính năng phê duyệt tài chính; bản này duyệt **ma trận ngưỡng** chứ không duyệt từng lệnh.
  - Thay đổi cấu hình hạ tầng/vault Gateway — thuộc REQ-BOD-008 và change management (BR-FIN-505).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint là **headless API/domain service trên core backend**: soạn version, duyệt, ban hành và lookup đều là API; mọi ràng buộc hiệu lực enforce ở service layer, các phân hệ không tự hard-code tham số.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CEO | Duyệt và ban hành ma trận hạn mức 5/50/200 triệu VND, định mức giá/Cost Rate Card, khung SLA theo tier với ngày hiệu lực rõ ràng | Chính sách đi vào đúng lúc công ty quyết định, có bằng chứng duyệt đầy đủ |
| 2 | BOD_CEO | Rà soát tham số Tier A–E theo quý và điều chỉnh khi thị trường đổi | Tier luôn phản ánh thực tế vận hành, không "đóng khung" từ lúc go-live |
| 3 | BOD_CFO_CTO | Duyệt riêng định nghĩa metric và ngưỡng freshness dữ liệu | Số liệu P&L/BI có một nguồn định nghĩa duy nhất do CFO kiểm soát |
| 4 | Hệ thống (các phân hệ) | Lookup API trả đúng version hiệu lực tại thời điểm dữ liệu (effective-dated) | Báo cáo quá khứ tái lập được theo chính sách lúc đó, không bị chính sách mới "ăn" ngược |
| 5 | SYS_ADMIN | Nhận cấu hình đã duyệt để áp vào môi trường chạy, không được tự chỉnh giá trị | Ranh giới người quyết định và người vận hành rõ ràng, mọi áp dụng có log |
| 6 | BOD_CEO | Thấy lịch sử hiệu lực đầy đủ: version nào, ai duyệt, khi nào, hiệu lực từ ngày nào, giá trị old → new | Truy trách mọi con số từng dùng trong báo cáo/quotation về đúng quyết định duyệt |
| 7 | BOD_CEO | Cho phép một tham số áp gấp giữa kỳ nhưng với mốc hiệu lực rõ ràng | Xử lý tình huống khẩn (ví dụ đổi ngưỡng SLA giữa tháng) mà không phá nguyên tắc không hồi tố |
| 8 | Hệ thống (job quý) | Nhắc chu kỳ rà soát Tier A–E và các tham số có chu kỳ review | Tham số không bị bỏ quên sau nhiều năm không nhìn lại |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service (không tin UI).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | (Dùng chung lane) RBAC chuẩn hóa 18 vai registry (BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1, HR_L2, FIN_L1, FIN_L2, SALES_L1–L5, OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; CUSTOMER chỉ portal). KHÔNG có OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight | Soạn/duyệt tham số với vai ngoài registry bị từ chối |
| BR-002 | (Dùng chung lane) Audit log bất biến hash-chain ≥10 năm WORM với log tiền; mọi thao tác ghi có actor + timestamp + lý do — mọi thay đổi tham số trace old → new + reason code bắt buộc | Version thiếu reason code không được submit; thay đổi không vết bị chặn |
| BR-003 | (Dùng chung lane) Quarterly access review bắt buộc; compensating control kiêm nhiệm CFO/CTO (REQ-BOD-002) — riêng tham số do CFO khởi tạo liên quan giao dịch tiền (ví dụ chỉnh ngưỡng trong ma trận hạn mức), nhánh duyệt chỉ còn CEO | Xung đột đề xuất–duyệt cùng luồng bị chặn theo cơ chế FEAT-CORE-RBAC-001 |
| BR-004 | (Dùng chung lane) SSO/MFA tập trung; PII nhân sự (lương) Confidential/Restricted — Cost Rate Card chứa cost/hour cá nhân ở tier Restricted: API trả tham số có mask theo vai | Vai không đủ tier gọi lookup nhận version đã mask trường PII |
| BR-005 | (Dùng chung lane) Ngưỡng phê duyệt 5/50/200 triệu VND là tham số mặc định đã chốt (DI-001, phiên duyệt 12/09): mọi lệnh chi xếp nhánh theo ma trận này; thay đổi ma trận phải qua duyệt của tính năng này, không chỉnh tay trong code | Phân hệ nào hard-code ngưỡng → fail code review/audit cấu hình; lookup là nguồn duy nhất |
| BR-006 | Effective-dated tuyệt đối: mỗi tham số có version + ngày hiệu lực + người duyệt; KHÔNG hồi tố — chỉ hiệu lực tương lai (mốc hiệu lực phải > thời điểm duyệt); lookup "tại thời điểm X" trả version hiệu lực tại X | Version có ngày hiệu lực trong quá khứ bị validation từ chối; báo cáo lookup luôn khớp thời điểm dữ liệu |
| BR-007 | Phân nhánh thẩm quyền: chính sách/định mức/Cost Rate Card/ma trận hạn mức/khung SLA/tier → BOD_CEO duyệt; định nghĩa metric + ngưỡng freshness → BOD_CFO_CTO duyệt; người soạn không tự duyệt version của chính mình | Duyệt sai nhánh bị từ chối; tự duyệt version mình soạn bị validation chặn |
| BR-008 | Áp gấp giữa kỳ được phép nhưng mốc hiệu lực rõ ràng (ngày–giờ), có thông báo tới các phân hệ tiêu thụ; version mới ban hành tự động superseded version cũ tại mốc hiệu lực | Hai version hiệu lực song song cùng phạm vi → cấu hình bị đánh dấu bất hợp lệ, alert |
| BR-009 | Tham số Tier A–E rà soát định kỳ theo quý: job nhắc; nếu không rà phải ghi nhận "kỳ này không rà" có lý do — không âm thầm bỏ chu kỳ | Bỏ chu kỳ không ghi nhận → cảnh báo lên BOD trong báo cáo quản trị |
| BR-010 | SYS_ADMIN chỉ áp cấu hình sau duyệt (không tự chỉnh giá trị); đổi giá trị trực tiếp trên môi trường chạy không qua version store bị chặn và phát alert cấu hình drift | Drift giữa cấu hình chạy và version store được job đối chiếu phát hiện → alert CTO |
| BR-011 | Lookup API là điểm tiêu thụ duy nhất: các phân hệ (quotation, SLA engine, alert, P&L) bắt buộc gọi lookup theo thời điểm dữ liệu, cấm cache vượt quá TTL quy định và cấm hard-code | Kiểm tra kiến trúc phát hiện hard-code → defect bắt buộc sửa; cache sai TTL gây số liệu lệch version |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN |
|-----------|---------|-------------|-----------|
| Soạn version nháp (mọi nhóm tham số) | ✅ | ✅ | ✅ (chỉ soạn theo yêu cầu, giá trị do BOD quyết) |
| Duyệt chính sách/định mức/Cost Rate Card/SLA/tier/ma trận hạn mức | ✅ (duy nhất nhánh này) | ❌ | ❌ |
| Duyệt định nghĩa metric + ngưỡng freshness | ❌ | ✅ (duy nhất nhánh này) | ❌ |
| Ban hành (kích hoạt hiệu lực theo mốc đã duyệt) | ❌ | ❌ | ✅ (thực thi sau duyệt, log đầy đủ) |
| Lookup tham số hiệu lực tại thời điểm X (API đọc) | ✅ | ✅ | ✅ (kèm mask PII theo vai) |
| Xem lịch sử version + old → new + người duyệt | ✅ | ✅ | ✅ (metadata, giá trị PII masked) |
| Sửa version đã duyệt / sửa giá trị trực tiếp trên môi trường chạy | ❌ | ❌ | ❌ (chỉ tạo version mới qua luồng duyệt) |
| Ghi nhận "kỳ này không rà Tier" | ✅ | ✅ (lý do bắt buộc) | ❌ |

**Ghi chú phân quyền:** chỉ dùng 18 vai registry; không có CUSTOMER (portal chỉ tiêu thụ hiệu quả của khung SLA/tier hiển thị, không thấy tham số gốc). CFO soạn tham số giao dịch tiền thì CEO duyệt (BR-003 — compensating control).

---

## 5. Trường Hợp Đặc Biệt

- **Ngày hiệu lực trùng nhiều version cùng lúc:** job ban hành xử lý theo thứ tự thời điểm duyệt; version ban hành sau ghi đè (supersede) version trước cùng phạm vi; nếu hai version cùng phạm vi cùng mốc hiệu lực → cấu hình bất hợp lệ, alert CTO và chặn lookup cho phạm vi đó đến khi xử lý.
- **Tham số có cấu trúc (ma trận hạn mức nhiều loại chi):** version áp cho toàn bộ ma trận — không cho phép sửa "một ô" ngoài luồng version; mỗi lần duyệt tạo snapshot nguyên khối để lookup nguyên tố (atomic).
- **Cost Rate Card chứa cost/hour cá nhân (PII):** version duyệt theo nhánh CEO nhưng giá trị tier Restricted; lookup trả mask cho vai không đủ tier; riêng P&L dùng giá trị thật ở tầng service với log truy cập (theo REQ-HR-010/REQ-HR-006).
- **Quay lại chính sách cũ (rollback tham số):** không "hủy" version mới — ban hành version mới copy nội dung version cũ với mốc hiệu lực tương lai + lý do rollback; lịch sử giữ nguyên cả nhánh.
- **Tham số liên quan giao dịch tiền do CFO soạn:** vào nhánh khóa chờ CEO duyệt theo FEAT-CORE-RBAC-001; CFO không được duyệt version do chính mình khởi tạo liên quan luồng tiền.
- **Khách hàng hợp đồng cũ đang áp tier/tham số cũ:** hợp đồng neo theo version hiệu lực tại ngày ký (nếu điều khoản hợp đồng quy định); lookup hợp đồng truy theo ngày hiệu lực của nó — chính sách mới không tự áp ngược hợp đồng đang chạy.
- **Cần tham số tạm thời (promo SLA 2 tuần):** tạo version có ngày kết thúc hiệu lực (hiếm, phải duyệt rõ); hết hạn tự quay lại version nền; cấm dùng cơ chế tạm thời để né chu kỳ rà soát.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Version tham số chính sách (Policy Parameter Version)

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit + ngày hiệu lực đề xuất)──► [PENDING_APPROVAL] ──(duyệt đúng nhánh)──► [APPROVED] ──(đến mốc hiệu lực)──► [EFFECTIVE] ──(version mới thay)──► [SUPERSEDED]
                                                    │                                        │
                                        (từ chối + lý do)                       (người soạn rút trước duyệt)
                                                    ▼                                        ▼
                                              [REJECTED]                              [WITHDRAWN]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `PENDING_APPROVAL` | Người soạn (BOD_CEO/BOD_CFO_CTO/SYS_ADMIN theo ủy nhiệm) | Đủ giá trị + ngày hiệu lực đề xuất (> thời điểm duyệt) + reason code |
| `DRAFT`/`PENDING_APPROVAL` | Rút | `WITHDRAWN` | Người soạn | Ghi lý do |
| `PENDING_APPROVAL` | Duyệt | `APPROVED` | BOD_CEO (chính sách/tier/hạn mức) hoặc BOD_CFO_CTO (metric/freshness) | MFA TOTP; đúng nhánh thẩm quyền; soạn ≠ duyệt |
| `PENDING_APPROVAL` | Từ chối | `REJECTED` | Người duyệt | Bắt buộc reason code |
| `APPROVED` | Đến mốc hiệu lực | `EFFECTIVE` | Hệ thống (job ban hành) | Thông báo tới phân hệ tiêu thụ; superseded version cũ cùng phạm vi |
| `EFFECTIVE` | Version mới thay | `SUPERSEDED` | Hệ thống | Version mới `EFFECTIVE`; lịch sử giữ nguyên |

**Quy tắc:** `SUPERSEDED`, `REJECTED`, `WITHDRAWN` là trạng thái kết thúc; không có đường từ `EFFECTIVE` về `DRAFT` (rollback = version mới copy cũ). Mọi chuyển tiếp nằm trong audit log hash-chain.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `policy_parameter` | `param_code`, `param_group`, `approval_lane` (`CEO`/`CFO`), `review_cadence` (QUARTERLY/ANNUAL/NONE), `description` | 1-N → `policy_parameter_version` | Nhóm: LIMIT_MATRIX, RATE_CARD, SLA_FRAME, TIER, FRESHNESS, METRIC_DEF |
| `policy_parameter_version` | `version_id`, `param_code`, `payload` (JSON snapshot), `effective_from`, `effective_to` (nullable), `status`, `created_by`, `approved_by`, `approved_at` | FK → `policy_parameter` | Snapshot nguyên khối nguyên tố; ngày hiệu lực chỉ tương lai; `SUPERSEDED` ghi `effective_to` |
| `approval_record` | `approval_id`, `version_id`, `approver_role`, `decided_at`, `decision`, `reason_code` | FK → `policy_parameter_version` | Soạn ≠ duyệt; MFA bắt buộc; log hash-chain |
| `parameter_notice` | `notice_id`, `version_id`, `notified_services`, `sent_at` | FK → `policy_parameter_version` | Thông báo phân hệ tiêu thụ khi vào `EFFECTIVE` |
| `config_drift_check` | `check_id`, `service_ref`, `store_version`, `runtime_value_hash`, `status` | Tham chiếu version | Job đối chiếu cấu hình chạy vs version store; drift → alert |

---

## 8. Acceptance Criteria

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Duyệt đúng nhánh thẩm quyền | Version khung SLA (nhánh CEO) | CFO gọi API duyệt | Từ chối — sai nhánh; CEO duyệt thành công với MFA; log ghi quyết định | [ ] |
| SC-002: Không hồi tố | Version mới với `effective_from` trong quá khứ | Submit | Validation từ chối với thông báo "chỉ hiệu lực tương lai" | [ ] |
| SC-003: Lookup tại thời điểm dữ liệu | Có 2 version (cũ/mới) ở 2 mốc hiệu lực | Gọi lookup với ngày trong quá khứ và ngày hiện tại | Trả đúng version hiệu lực tại từng thời điểm; báo cáo quá khứ tái lập khớp | [ ] |
| SC-004: Áp gấp giữa kỳ | Cần đổi ngưỡng SLA giữa tháng | Duyệt với mốc hiệu lực ngày–giờ rõ ràng | Version vào `EFFECTIVE` đúng mốc, `parameter_notice` gửi phân hệ, version cũ `SUPERSEDED` có `effective_to` | [ ] |
| SC-005: Soạn ≠ duyệt | CFO soạn version chỉnh ma trận hạn mức giao dịch tiền | CFO duyệt | Chặn theo compensating control (FEAT-CORE-RBAC-001); chỉ CEO duyệt được | [ ] |
| SC-006: Phát hiện cấu hình drift | Ai đó đổi giá trị trực tiếp trên môi trường chạy | Job đối chiếu chạy | Drift phát hiện → alert CTO; giá trị runtime phải đưa về version store duyệt | [ ] |
| SC-007: Nhắc rà soát Tier quý | Đến quý mới | Job nhắc | Thông báo rà soát Tier A–E; nếu không rà phải ghi nhận có lý do, bỏ im → cảnh báo BOD | [ ] |
| SC-008: Mask PII trong Rate Card | Lookup Rate Card bởi vai không đủ tier | API trả kết quả | Trường cost/hour cá nhân masked ở service layer; vai đủ tier (theo REQ-HR-010) thấy đủ và có meta-log | [ ] |

> **Liên kết:** SC-001→002 map REQ-BOD-009 (thẩm quyền + effective-dated); SC-003→004 map REQ-BOD-009 (lookup + áp gấp); SC-005 map REQ-BOD-002/REQ-BOD-009 (SoD tham số tiền); SC-006→007 map REQ-BOD-009 (drift + chu kỳ rà); SC-008 map REQ-BOD-009 + REQ-HR-010 (PII trong tham số).

---

## Tài Liệu Kĩ Thuật Liên Quan

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (version store, duyệt, lookup, notice) | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (phân hệ tiêu thụ lookup, alert drift) | `technical-specs/integration-map.md` |
| Màn hình UI (trình duyệt + ký + lịch sử hiệu lực — counterpart WEB) | `phase4-ux/core-backend/rbac-audit/[screen-group].md` |
| Touchpoint counterpart | SYS-BCERP-WEB (fan-out cùng REQ-BOD-009); MOBILE không có touchpoint (duyệt chính sách cần hồ sơ đầy đủ trên web) |
