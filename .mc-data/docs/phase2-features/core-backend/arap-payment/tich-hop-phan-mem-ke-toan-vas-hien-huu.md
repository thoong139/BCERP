# Tính Năng: Tích hợp phần mềm kế toán VAS hiện hữu

> **Dựa trên:** REQ-FIN-013 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Tài chính — Kế toán & Công nợ (SYS-CORE-BACKEND)
> **Module:** AR/AP Payment — Tích hợp kế toán (MOD-ARAP-PAYMENT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/arap-payment/[screen-group].md`, `phase5-implementation/tasks/core-backend/arap-payment/feat-core-arap-006-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-ARAP-006 |
| Module | MOD-ARAP-PAYMENT |
| Yêu cầu nghiệp vụ | [REQ-FIN-013] — liên quan: REQ-BOD-008 (quản trị Integration Gateway & credentials vault — cross-dependency), REQ-FIN-004/006 (chứng từ khóa kỳ), REQ-FIN-011 (HĐĐT dùng chung luồng kết nối), REQ-FIN-012 (audit log) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO (SYS_ADMIN thực thi cấu hình sau phê duyệt) |
| Độ ưu tiên | Trung bình (MEDIUM — Giai đoạn 2) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | **Cross-dependency: REQ-BOD-008 — credentials vault & quản trị GW cho connector VAS**; FEAT-CORE-ARAP-003 (số dư công nợ), FEAT-CORE-ARAP-004 (lệnh chi đã duyệt), FEAT-CORE-ARAP-005 (luồng kết nối HĐĐT dùng chung); cấu hình kết nối ngoại vi đặt tại MOD-SETTINGS-GW |
| Ghi chú Expert (A7) | `finance.md` có Mục A7 nhưng chưa thực hiện review tại thời điểm viết; theo DI-004 (12/09) chủ dự án không chốt tên vendor — connector thiết kế vendor-agnostic, tên phần mềm cụ thể được cấu hình khi triển khai, không chặn thiết kế |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cho phép BCERP **tích hợp, không thay thế** phần mềm kế toán VAS hiện hữu: domain service xuất bút toán/chứng từ/HĐĐT chuẩn từ dữ liệu đã duyệt/khóa kỳ xuống sổ VAS qua connector vendor-agnostic (adapter API hoặc import/export chuẩn), đối chiếu sổ VAS với BCERP định kỳ và migrate dữ liệu legacy PMS chọn lọc — sao cho sổ kế toán pháp lý nằm trên VAS mà số liệu hai bên khớp nhau, chênh lệch thì có giải trình.

**Phạm vi:**
- Bao gồm: service xuất bút toán chuẩn từ chứng từ đã duyệt/khóa kỳ; định nghĩa connection profile + field mapping + schema xuất nhập (import/export template + adapter API cắm được) — cấu hình toàn bộ tại MOD-SETTINGS-GW theo DI-004 (12/09), không hardcode vendor; job đồng bộ/đối chiếu sổ VAS ↔ BCERP hàng tháng với báo cáo chênh lệch và luồng giải trình FIN_L2; hàng chờ retry + alert khi connector fail; migrate chọn lọc từ legacy PMS (master data + dự án active + payment history 12 tháng) một chiều vào BCERP, sau đó legacy chuyển read-only.
- Không bao gồm: vận hành kết nối mạng, quản trị credentials/vault và hạ tầng GW (REQ-BOD-008 — thuộc SYS-INTEGRATION-GW, counterpart integration-gw của REQ này); màn đối chiếu sổ trên web (counterpart SYS-BCERP-WEB); thay thế chức năng kế toán của VAS; phát hành HĐĐT (FEAT-CORE-ARAP-005 — chỉ dùng chung luồng kết nối).

**Đặc thù touchpoint SYS-CORE-BACKEND:** đây là feature cầu nối dữ liệu — BCERP là nguồn dữ liệu nghiệp vụ (chứng từ đối soát, lệnh chi, bút toán đề xuất), mọi xuất/nhập đi qua domain service có schema validate; connector chạy ở GW nhưng dữ liệu và luồng nghiệp vụ thuộc CORE (xuất từ đâu, đối chiếu thế nào, chênh lệch xử lý ra sao được quyết ở service layer); mọi lượt xuất/nhập/import ghi audit log bất biến; dữ liệu sổ kế toán phân loại Restricted — tenant isolation tuyệt đối, credentials không bao giờ nằm trong CORE (tham chiếu vault của REQ-BOD-008).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Gọi API xuất bút toán theo kỳ cho các chứng từ đã duyệt/khóa kỳ | Đưa số liệu BCERP xuống sổ VAS đúng chu kỳ không phải nhập tay |
| 2 | BOD_CFO_CTO | Duyệt connection profile + field mapping qua API cấu hình (trước khi bản ghi tới MOD-SETTINGS-GW kích hoạt) | Kết nối đổi vendor mà không sửa code, luôn có vết duyệt |
| 3 | FIN_L2 | Xem báo cáo đối chiếu sổ VAS ↔ BCERP hàng tháng qua API kèm danh mục chênh lệch | Giải trình từng chênh lệch trước khi chốt sổ |
| 4 | FIN_L2 | Ghi giải trình chênh lệch qua API (lý do + điều chỉnh tương ứng nếu có) | Cơ sở kiểm toán có vết cho mọi khác biệt sổ |
| 5 | Hệ thống (job) | Tự retry các lượt xuất thất bại và alert FIN/BOD khi connector fail | Luồng chuẩn không bị "ghi sổ tay" đè lên khi sự cố |
| 6 | FIN_L1 | Import file chuẩn schema (khi VAS chỉ hỗ trợ import/export file) qua API import có validate | Vẫn chạy được connector khi không có API bên VAS |
| 7 | BOD_CFO_CTO | Duyệt phạm vi migrate legacy PMS qua API (master data + dự án active + payment history 12 tháng) | Dữ liệu quá khứ đủ dùng mà không kéo rác vào hệ thống mới |
| 8 | SYS_ADMIN | Thực thi kích hoạt/vô hiệu connection profile sau khi đã được CFO duyệt | Tách vai quyết định và vai vận hành theo nguyên tắc SoD (REQ-BOD-011) |

**Diễn giải luồng chính (service layer):** (1) job/lượt xuất theo kỳ → truy vấn bút toán từ chứng từ đã duyệt/khóa kỳ (không xuất bản nháp); (2) map theo field mapping của profile đang active; (3) gọi adapter (API hoặc sinh file chuẩn schema) — cơ chế do profile quyết; (4) ghi `export_log` với hash payload; (5) thất bại → đưa vào retry queue với backoff, quá ngưỡng thì alert; (6) hàng tháng, job đối chiếu số dư/bút toán hai bên → sinh báo cáo chênh lệch; FIN_L2 giải trình từng dòng qua API; (7) migrate legacy chạy một lần theo phạm vi duyệt, ghi lại mapping id legacy → mới.

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-ARAP-601 | BCERP tích hợp, không thay thế phần mềm kế toán VAS: BCERP là nguồn dữ liệu nghiệp vụ (chứng từ đối soát, lệnh chi, bút toán đề xuất); sổ kế toán pháp lý nằm trên VAS — cấm cấu hình ghi đè sổ VAS từ BCERP, cấm VAS ghi ngược số liệu nghiệp vụ vào CORE ngoài luồng import có validate | Vi phạm hướng ghi → từ chối `WRITE_DIRECTION_VIOLATION` + log |
| BR-ARAP-602 | Chỉ xuất dữ liệu từ chứng từ đã duyệt/khóa kỳ — không xuất bản nháp; lệnh chi phải ở trạng thái đã qua đủ chữ ký (FEAT-CORE-ARAP-004); giải ngân liên quan TKQC phải đã qua Hard Stop "đã khớp tiền" FIN_L1 (REQ-FIN-006) | Có dòng chưa điều kiện trong lô xuất → cả lô bị giữ `EXPORT_HELD`, không xuất một phần im lặng |
| BR-ARAP-603 | Connector vendor-agnostic theo DI-004 (12/09): connection profile + field mapping + import/export template chuẩn + adapter API cắm được; cấu hình tại MOD-SETTINGS-GW (kết nối ngoại vi), tên phần mềm cụ thể cấu hình khi triển khai; credentials nằm ở vault REQ-BOD-008 — CORE chỉ giữ tham chiếu, không lưu plaintext | Thiếu profile/mapping → từ chối `CONNECTION_NOT_CONFIGURED`; phát hiện secret trong payload → chặn + alert bảo mật |
| BR-ARAP-604 | Đối chiếu sổ VAS ↔ BCERP định kỳ hàng tháng: báo cáo chênh lệch sinh tự động, từng chênh lệch phải có giải trình FIN_L2 (lý do + điều chỉnh tương ứng nếu có); chênh lệch chưa giải trình chặn cảnh báo chốt kỳ | Chốt kỳ còn chênh lệch chưa giải trình → từ chối `UNRECONCILED_DIFF` |
| BR-ARAP-605 | Connector fail → hàng chờ retry (backoff) + alert FIN/BOD; cấm ghi sổ tay đè lên luồng chuẩn; mọi lượt xuất/import ghi `export_log`/`import_log` với hash payload + người thực hiện | Cố ghi ngoài luồng → từ chối `BYPASS_BLOCKED`; log thiếu hash → job toàn vẹn báo lỗi |
| BR-ARAP-606 | Legacy PMS migrate chọn lọc một chiều: master data + dự án active + payment history 12 tháng; phạm vi do BOD_CFO_CTO duyệt; sau go-live legacy chuyển **read-only** — tra cứu qua tham chiếu, cấm ghi hai chiều; mọi bản ghi import giữ id mapping legacy → mới để truy vết | Cố ghi vào legacy sau go-live → chặn `LEGACY_READONLY`; import ngoài phạm vi duyệt bị từ chối |
| BR-ARAP-607 | SoD dữ liệu kế toán: người đối soát ≠ người duyệt điều chỉnh (BR-FIN-304); SYS_ADMIN không tự gán/thay đổi connection profile — chỉ thực thi sau phê duyệt CFO; SYS_ADMIN không thấy giá trị tài chính chi tiết ngoài phạm vi (BR-BOD-003) | Gán sai vai → từ chối + log vi phạm SoD |
| BR-ARAP-608 | Dữ liệu trao đổi với VAS phân loại Restricted: tenant isolation ở mọi payload (không trộn tenant trong một lô), audit log bất biến ≥10 năm; HĐĐT đi qua cùng luồng kết nối tuân thủ FEAT-CORE-ARAP-005 (TT78/2021 + NĐ123/2020); phí nền tảng/thuế trong bút toán ghi nhận theo giao dịch gốc theo FEAT-CORE-ARAP-007 | Payload trộn tenant → chặn lô `TENANT_MIX_BLOCKED`; thiếu audit log → rollback |

---

## 4. Phân Quyền

> Enforce tại tầng service; GW vận hành kết nối theo profile được CORE/GW duyệt — vai thực thi cấu hình tách vai quyết định.

| Hành động (API) | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN |
|-----------------|--------|--------|-------------|-----------|
| Xuất bút toán theo kỳ | ✅ | ✅ (phê duyệt lô) | ❌ | ❌ |
| Xem trạng thái lượt xuất/import | ✅ | ✅ | ✅ | ✅ (vận hành, không thấy chi tiết giá trị) |
| Tạo/sửa connection profile + field mapping (đề xuất) | ❌ | ✅ | ✅ | ❌ |
| Duyệt connection profile (ban hành) | ❌ | ❌ | ✅ | ❌ |
| Kích hoạt/vô hiệu profile sau duyệt | ❌ | ❌ | ❌ | ✅ (thực thi sau duyệt) |
| Import file chuẩn schema | ✅ | ✅ | ❌ | ❌ |
| Xem báo cáo đối chiếu + chênh lệch | ✅ | ✅ | ✅ | ❌ |
| Ghi giải trình chênh lệch | ❌ | ✅ (lý do bắt buộc) | ✅ (oversight) | ❌ |
| Duyệt phạm vi migrate legacy PMS | ❌ | ❌ | ✅ | ❌ |
| Thực thi job migrate theo phạm vi đã duyệt | ❌ | ✅ | ❌ | ✅ (vận hành) |
| Xem/expose credentials VAS | ❌ | ❌ | ❌ (chỉ vault REQ-BOD-008) | ❌ (không ai đọc plaintext) |
| Xóa log xuất/import | ❌ | ❌ | ❌ | ❌ (append-only) |

---

## 5. Trường Hợp Đặc Biệt

- **VAS chỉ hỗ trợ import/export file (không có API):** profile cấu hình adapter dạng file chuẩn schema — CORE sinh file + log lượt xuất; file import từ VAS phải qua validate schema + đối soát trước khi nhận; quy trình hai bên vẫn giữ luồng chuẩn có vết.
- **Connector fail kéo dài (VAS bảo trì/DTO):** retry queue giữ lô với timestamp; alert leo thang sau ngưỡng retry; FIN_L1 không được xuất file tay thay thế — chờ luồng chuẩn, mọi ngoại lệ phải có phê duyệt CFO và ghi nhận như một lượt xuất có vết.
- **Đổi vendor kế toán giữa chừng:** tạo profile mới song song, chạy đối chiếu cross-check một kỳ trước khi cắt; profile cũ chuyển `SUSPENDED` (không xóa) — lịch sử export/import giữ nguyên để truy vết.
- **Dữ liệu legacy không khớp cấu trúc mới (thiếu mã dự án, trùng id khách):** import record lỗi vào bảng staging kèm báo cáo; chỉ bản ghi qua validate mới vào hệ thống chính; bản rớt được giải trình trong báo cáo migrate — không tự sửa im lặng.
- **VAS có pháp nhân đơn vị kế toán khác (nhiều sách):** connection profile gắn pháp nhân/tenant; xuất theo pháp nhân, không gộp chéo pháp nhân trong một profile.
- **Khóa kỳ trong khi lô xuất đang chờ retry:** lô giữ tham chiếu kỳ tại thời điểm tạo; nếu kỳ bị mở lại (FEAT-CORE-ARAP-002) sau khi xuất, sinh ghi chú chênh lệch đối chiếu kỳ sau — không tự xuất lại đè lô cũ.
- **Giờ cao điểm khóa ghi:** lô xuất lớn chạy ngoài giờ cao điểm theo cấu hình; ưu tiên xuất AP trước hạn (nối cảnh báo FEAT-CORE-ARAP-003) để không trễ thanh toán nền tảng.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Connection profile kết nối VAS (`connection_profile` — bản ghi nghiệp vụ tại CORE, cấu hình kỹ thuật tại MOD-SETTINGS-GW)

**Sơ đồ trạng thái:**
```
[DRAFT] ──(CFO duyệt)──► [APPROVED] ──(SYS_ADMIN kích hoạt)──► [ACTIVE] ──(vô hiệu sau duyệt)──► [SUSPENDED]
                            │                                      │
                            │ (CFO từ chối)                        │ (đổi vendor, thay thế)
                            ▼                                      ▼
                        [REJECTED]                             [RETIRED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Duyệt | `APPROVED` | BOD_CFO_CTO | Field mapping + schema hoàn chỉnh; credentials tham chiếu vault |
| `DRAFT` | Từ chối | `REJECTED` | BOD_CFO_CTO | Reason code bắt buộc |
| `APPROVED` | Kích hoạt | `ACTIVE` | SYS_ADMIN | Thực thi sau duyệt; test connection pass |
| `ACTIVE` | Vô hiệu tạm | `SUSPENDED` | SYS_ADMIN sau duyệt CFO | Lô đang chạy được xử lý dứt điểm; alert FIN |
| `ACTIVE`/`SUSPENDED` | Nghỉ hưu (đổi vendor) | `RETIRED` | SYS_ADMIN sau duyệt CFO | Profile mới đã ACTIVE + cross-check pass; lịch sử giữ nguyên |

**Quy tắc:**
- Không quay về `ACTIVE` từ `RETIRED` — tạo profile mới có dẫn chiếu.
- Mỗi tenant/pháp nhân chỉ một profile `ACTIVE` cho cùng mục đích (VAS sổ pháp lý).
- Mọi chuyển trạng thái ghi audit log bất biến; job xuất chỉ chạy trên profile `ACTIVE`.

Song song, entity `export_batch` có vòng đời: `CREATED` → `MAPPED` → `SENT` → `ACKNOWLEDGED`/`FAILED` (→ retry → `SENT` hoặc `DEAD_LETTER` + alert).

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `connection_profile` | `id`, `purpose`, `vendor_placeholder`, `adapter_type` (API/FILE), `field_mapping_ref`, `legal_entity`, `status` | Tham chiếu MOD-SETTINGS-GW | Vendor-agnostic (DI-004); duyệt CFO — kích hoạt SYS_ADMIN |
| `export_batch` | `period`, `tenant_id`, `entry_count`, `payload_hash`, `status`, `attempts`, `next_retry_at` | FK → `tenants.id` | Chỉ từ chứng từ đã duyệt/khóa kỳ |
| `export_log` / `import_log` | `batch_id`, `actor`, `direction`, `hash`, `created_at`, `result` | FK → `export_batch.id` | Append-only; hash payload bắt buộc |
| `reconciliation_report` | `period`, `book_balance_vas`, `book_balance_bcerp`, `diff_vnd`, `status` | Độc lập theo kỳ | Hàng tháng; chênh lệch cần giải trình |
| `reconciliation_explanation` | `report_id`, `diff_line`, `reason`, `adjustment_ref`, `explained_by` | FK → `reconciliation_report.id` | FIN_L2; lý do bắt buộc |
| `legacy_migration_run` | `scope` (master data/active projects/payment history 12M), `approved_by`, `stats`, `status` | Độc lập | Một chiều; id mapping legacy → mới |
| `audit_log` | Append-only + hash-chain | Polymorphic | ≥10 năm WORM |

---

## 8. Acceptance Criteria

> Phác thảo sơ bộ Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Xuất chỉ từ chứng từ khóa kỳ | Lô chứa 1 dòng từ chứng từ nháp | Tạo lô xuất | Cả lô `EXPORT_HELD`, không xuất một phần im lặng | [ ] |
| SC-002: Profile chưa cấu hình | Không có profile ACTIVE cho kỳ | Gọi API xuất | Từ chối `CONNECTION_NOT_CONFIGURED` | [ ] |
| SC-003: Retry khi connector fail | Adapter trả lỗi mạng | Job xử lý | Lô vào retry với backoff; quá ngưỡng alert FIN/BOD | [ ] |
| SC-004: Đối chiếu có chênh lệch | Số dư VAS ≠ BCERP cuối tháng | Job đối chiếu chạy | Báo cáo chênh lệch sinh đúng; chốt kỳ chặn khi chưa giải trình | [ ] |
| SC-005: Legacy read-only | Migration đã hoàn tất, legacy chuyển read-only | Cố ghi vào legacy | Chặn `LEGACY_READONLY`, log attempt | [ ] |
| SC-006: Tenant mix bị chặn | Lô chứa dòng của 2 tenant | Validate | Chặn `TENANT_MIX_BLOCKED`, tách lô theo tenant | [ ] |
| SC-007: SoD cấu hình | SYS_ADMIN cố tự ban hành profile | Gọi API duyệt | Từ chối `APPROVAL_ROLE_REQUIRED`, log vi phạm | [ ] |

> **Liên kết:** SC-001–SC-004 map REQ-FIN-013; SC-005 map REQ-FIN-013 + DI-004; SC-006–SC-007 map REQ-FIN-013 + REQ-BOD-011/REQ-BOD-008.

---

## Tài Liệu Kỹ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (export/reconciliation/migration) | `technical-specs/api-contract.md` |
| Tích hợp (adapter qua SYS-INTEGRATION-GW, vault REQ-BOD-008) | `technical-specs/integration-map.md` |
| Màn hình UI counterpart | `phase4-ux/core-backend/arap-payment/[screen-group].md` |
| Quy tắc nguồn | `phase1-business/departments/finance/finance.md` (A3 REQ-FIN-013, BR-FIN-305), `phase1-business/P1-02-business-workflow.md` (bên ngoài #6 VAS — hằng tháng), `.mc-data/work/wf-analyze-requirements/deferred-issues.md` (DI-004 resolved 12/09) |
