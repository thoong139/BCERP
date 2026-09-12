# Tính Năng: Giám Sát & Truy Xuất Audit Log

> **Dựa trên:** REQ-BOD-005 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** RBAC & Audit Log (SYS-BCERP-WEB)
> **Module:** RBAC & Audit Log (MOD-RBAC-AUDIT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`, `phase1-business/departments/finance/finance.md` (B.5)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/rbac-audit/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/rbac-audit/feat-002-impl.md`

> **Hướng dẫn ID:** FEAT-ID được tạo từ REQ-ID theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. Bản fan-out này dùng ID lane `FEAT-ERP-RBAC-002` — bản riêng của touchpoint SYS-BCERP-WEB (bản counterpart: SYS-CORE-BACKEND).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-RBAC-002 |
| Module | MOD-RBAC-AUDIT |
| Yêu cầu nghiệp vụ | REQ-BOD-005 |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — nền móng GĐ1, không bổ sung sau được) |
| Phụ thuộc | FEAT-ERP-RBAC-005 (SSO/MFA truy cập), FEAT-ERP-RBAC-007 (WORM & retention — quản vòng đời lưu trữ) |
| Ghi chú Expert (A7) | Mục A7 của `bod.md` đang chờ đánh giá chuyên gia đầy đủ; điều chỉnh liên quan đã chốt qua stakeholder review 12/09: DI-006 gỡ OPS_CX/FIN_COMPL khỏi registry (18 vai — Compliance gán FIN_L2 + BOD oversight), giữ nguyên yêu cầu meta-log cho mọi vai; chi tiết tại `bod.md` Mục A7 và `stakeholder-review.md` Phần F.3 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cho phép BOD giám sát và truy xuất toàn bộ dấu vết hệ thống ngay trên web nội bộ: tra cứu audit log giao dịch tiền/hợp đồng/phân quyền theo chuỗi giá trị old → new kèm reason code, theo dõi sức khỏe hash-chain hằng ngày và tình trạng retention WORM. Đây là "kính đen" của điều hành — mọi tranh chấp, thanh tra hay điều tra nội bộ đều xuất phát từ một nguồn bằng chứng duy nhất, kể cả Super Admin cũng không can thiệp được.

**Phạm vi:**
- Bao gồm: màn tra cứu log theo khoảng thời gian/đối tượng (khách, TKQC, hợp đồng, giao dịch, user)/người thực hiện; hiển thị chuỗi old → new value + reason code; dashboard trạng thái hash-chain và retention WORM (kết quả job kiểm tra toàn vẹn hằng ngày); luồng yêu cầu xuất log ngoài báo cáo chuẩn với phê duyệt BOD_CEO ≤2 ngày làm việc; hiển thị watermark người xem khi tra cứu; màn trình duyệt đề xuất xóa/archive log hết hạn (CTO đề xuất — CEO duyệt, việc xóa cũng bị log).
- Không bao gồm: ghi log và kiểm tra toàn vẹn hash-chain (SYS-CORE-BACKEND thực thi — web chỉ hiển thị kết quả job); alert đứt chuỗi đa kênh và push mobile (REQ-BOD-006 — mobile nội bộ cấm tra cứu log vì dữ liệu Mật/Restricted, chỉ nhận alert qua counterpart); định tuyến WORM storage và backup/DR (REQ-FIN-012, FEAT-ERP-RBAC-007).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CEO | Tra cứu trên web mọi thay đổi giao dịch tiền/hợp đồng/phân quyền theo chuỗi old → new value kèm reason code | Giải trình được với thanh tra, kiểm toán và tự kiểm soát điều hành bằng bằng chứng gốc |
| 2 | BOD_CEO | Thấy trạng thái hash-chain hằng ngày trên dashboard (nguyên vẹn/đứt chuỗi) | Biết ngay hệ thống log còn đáng tin hay đã bị can thiệp |
| 3 | BOD_CFO_CTO | Xem báo cáo retention: log sắp hết hạn WORM, dung lượng, và trình đề xuất xóa/archive theo quý cho CEO duyệt | Vận hành lưu trữ đúng chính sách mà không ai tự ý xóa dữ liệu |
| 4 | BOD_CFO_CTO | Yêu cầu xuất log ra file phục vụ thanh tra/kiểm toán đúng luồng có phê duyệt | Xuất dữ liệu minh bạch nhưng có dấu vết ai xuất, khi nào, cho ai |
| 5 | BOD_CEO | Duyệt/từ chối yêu cầu xuất log ≤2 ngày làm việc với ngữ cảnh đầy đủ (ai xin, tra cứu gì, mục đích) | Kiểm soát mọi luồng dữ liệu Mật ra khỏi hệ thống |
| 6 | SYS_ADMIN | Xem trạng thái kỹ thuật của job kiểm tra toàn vẹn và thời gian chạy gần nhất | Bảo đảm job vận hành ổn định mà không đọc nội dung nghiệp vụ ngoài scope |
| 7 | BOD_CEO/CFO | Khi tra cứu log, thấy watermark danh tính người xem trên màn hình và bản xuất | Nhắc trách nhiệm và chống truy cập lén — vì bản thân việc xem log cũng bị log |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Append-only và hash-chain nằm ở SYS-CORE-BACKEND; web không có bất kỳ interface xóa/sửa log nào ở mọi tầng.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | RBAC dùng đúng 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5, ...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight | Vai ngoài registry không thể cấu hình; màn truy cập log chỉ gắn cho BOD_CEO, BOD_CFO_CTO và SYS_ADMIN (phần kỹ thuật) |
| BR-002 | Audit log bất biến append-only hash-chain, lưu ≥10 năm (WORM) với log tiền (log hệ thống ≥7 năm); mọi thao tác ghi có actor + timestamp + lý do; kể cả Super Admin không sửa/xóa được log của chính mình — không tồn tại interface xóa ở mọi tầng | Attempt sửa/xóa bị chặn tầng DB (account chỉ INSERT/SELECT); web hiển thị kết quả tra cứu read-only tuyệt đối |
| BR-003 | Meta-log: mỗi lượt xem/tra cứu log đều bị ghi log (ai — xem gì — khi nào), meta-log cũng append-only và nằm trong hash-chain; màn tra cứu hiển thị watermark danh tính người xem | Tra cứu không có meta-log là lỗi hệ thống (job đối chiếu phát hiện); không có ngoại lệ cho bất kỳ vai nào |
| BR-004 | Xuất log ngoài báo cáo chuẩn bắt buộc qua phê duyệt BOD_CEO ≤2 ngày làm việc; thanh tra/kiểm toán dùng đúng luồng này; không duyệt xuất cho người liên quan trực tiếp đến sự kiện bị tra cứu (SoD tra cứu ≠ đối tượng) | Nút xuất chỉ mở khi yêu cầu ở trạng thái đã duyệt; vi phạm SoD → hệ thống chặn và ghi log |
| BR-005 | Quarterly access review bắt buộc cho quyền truy cập log; kiêm nhiệm CFO/CTO phải có compensating control (REQ-BOD-002); quyền không review 2 quý liên tiếp tự vô hiệu | Quyền tra cứu log không có record review → chuyển SUSPENDED, người dùng mất nút truy cập cho đến khi review xong |
| BR-006 | SSO/MFA tập trung cho mọi phiên truy cập log; PII nhân sự xuất hiện trong log (thu nhập, cost) hiển thị ở mức Confidential/Restricted — mask theo vai, không bao giờ hiển thị plaintext cho vai không phép | Phiên không hợp lệ → chuyển màn đăng nhập; dữ liệu Restricted trả về dạng masked, không có nút "hiện giá trị" |
| BR-007 | Việc xóa/archive log hết hạn chỉ theo quý: CTO đề xuất + CEO duyệt trên web — chính việc xóa cũng bị log; retention chỉ được kéo dài, không rút ngắn dưới mức tối thiểu | Yêu cầu xóa ngoài kỳ/quy trình bị từ chối giao diện; đề xuất rút ngắn retention bị chặn validate |
| BR-008 | Phê duyệt và luồng liên quan tuân theo khung ngưỡng 5/50/200 triệu VND đã chốt (DI-001): các sự kiện tiền trong log hiển thị kèm nhánh ngưỡng để đối chiếu escalation đúng cấp | Log thiếu nhánh ngưỡng/escalation path → gắn cờ chất lượng dữ liệu cho job kiểm tra |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN | Vai khác (registry 18 vai) |
|-----------|---------|-------------|-----------|----------------------------|
| Tra cứu log (tiền/hợp đồng/phân quyền) | ✅ | ✅ | ◐ (chỉ log kỹ thuật, không nội dung nghiệp vụ) | ❌ |
| Xem dashboard hash-chain + retention | ✅ | ✅ | ◐ (trạng thái job, không nội dung) | ❌ |
| Tạo yêu cầu xuất log | ✅ | ✅ | ❌ | ❌ |
| Duyệt yêu cầu xuất log | ✅ (≤2 ngày làm việc) | ❌ | ❌ | ❌ |
| Đề xuất xóa/archive log hết hạn | ❌ | ✅ (đề xuất theo quý) | ❌ | ❌ |
| Duyệt xóa/archive log hết hạn | ✅ | ❌ | ❌ | ❌ |
| Xem meta-log về chính mình | ✅ | ✅ | ◐ (log kỹ thuật) | ❌ |
| Xóa/sửa log trực tiếp | ❌ | ❌ | ❌ | ❌ |

---

## 5. Trường Hợp Đặc Biệt

- Đứt hash-chain: dashboard chuyển đỏ, cấm tương tác xuất log cho đến khi điều tra xong; chi tiết điều tra xử lý ở counterpart CORE — web chỉ hiển thị trạng thái INVALID và liên kết sang alert center (REQ-BOD-006).
- Thanh tra nhà nước yêu cầu xuất lượng log lớn vượt giới hạn file: cho phép xuất chia phần (chunk) trong cùng một yêu cầu đã duyệt, tổng số phần và dung lượng ghi rõ trong log xuất.
- Người liên quan trực tiếp đến giao dịch bị tra cứu là chính người duyệt xuất log: hệ thống chặn theo SoD tra cứu ≠ đối tượng, yêu cầu chuyển sang người duyệt thay thế (nếu là CEO → chuyển CFO và ngược lại; nếu cả hai liên quan → leo thang theo quy trình điều tra).
- Log chứa PII nhân sự (lương, cost của người kiêm nhiệm CFO/CTO): mask bắt buộc ở mức Confidential/Restricted; chỉ vai được phép theo ma trận REQ-HR-010 (FEAT-ERP-RBAC-006) mới thấy giá trị — kể cả trong log.
- Job kiểm tra toàn vẹn trễ/không chạy (sự cố hạ tầng): dashboard hiển thị "stale + timestamp kết quả hợp lệ cuối", không giả mạo trạng thái OK — BR "không nhìn thấy con số không biết tuổi".

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Yêu cầu xuất audit log (ngoài báo cáo chuẩn)

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit)──► [PENDING_CEO_APPROVAL] ──(duyệt ≤2 ngày)──► [APPROVED] ──(export chạy)──► [EXPORTED]
                            │                                        │
                            │ (từ chối)                             │ (lỗi sinh file)
                            ▼                                        ▼
                        [REJECTED]                               [FAILED] ──(retry)──► [APPROVED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `PENDING_CEO_APPROVAL` | BOD_CEO / BOD_CFO_CTO | Đủ: khoảng thời gian, đối tượng, mục đích, định dạng |
| `PENDING_CEO_APPROVAL` | Duyệt | `APPROVED` | BOD_CEO | Không trùng vai với người liên quan sự kiện (SoD tra cứu) |
| `PENDING_CEO_APPROVAL` | Từ chối | `REJECTED` | BOD_CEO | Reason code bắt buộc |
| `APPROVED` | Chạy xuất | `EXPORTED` | Hệ thống | File ghi watermark + log xuất; SLA trong ngày duyệt |
| `APPROVED` | Lỗi sinh file | `FAILED` | Hệ thống | Ghi lỗi; retry không cần duyệt lại |
| `EXPORTED` / `REJECTED` | — | Trạng thái kết thúc | — | Bản thân chuyển trạng thái cũng nằm trong meta-log |

**Quy tắc:**
- Không có nhánh bỏ qua duyệt — kể cả Super Admin.
- `EXPORTED` và `REJECTED` là trạng thái kết thúc; yêu cầu lại tạo bản ghi mới.

**Trạng thái phụ — sức khỏe hash-chain (entity `audit_chain_status`):** `VALID` ↔ `INVALID` (đứt chuỗi — chỉ hệ thống đặt qua job hằng ngày); `STALE` khi job trễ — không bao giờ tự gán `VALID` khi thiếu kết quả job mới nhất.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `audit_log` (read model) | `id`, `event_type`, `actor_id`, `actor_role`, `object_type`, `object_id`, `old_value`, `new_value`, `reason_code`, `occurred_at`, `prev_hash`, `hash` | FK logic → đối tượng nghiệp vụ | Append-only, hash-chain; web chỉ SELECT |
| `meta_log` | `id`, `viewer_id`, `viewed_scope`, `viewed_at`, `channel` | FK → `users.id` | Append-only, nằm trong hash-chain; nguồn watermark |
| `audit_export_request` | `id`, `requested_by`, `scope`, `purpose`, `state`, `approved_by`, `approved_at`, `file_ref` | FK → `users.id` | Machine-state hiển thị trên web |
| `archive_proposal` | `id`, `quarter`, `proposed_by`, `proposal_payload`, `approved_by`, `executed_at`, `deletion_log_id` | FK → `users.id`, FK → `audit_log` (phạm vi) | Chỉ theo quý; việc xóa cũng log |
| `audit_chain_status` | `date`, `integrity_state`, `job_run_at`, `first_broken_seq` | — | Nguồn dashboard; STALE khi job trễ |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ — chi tiết ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Tra cứu có meta-log | BOD_CEO mở màn tra cứu log | Lọc theo giao dịch + khoảng thời gian | Kết quả hiển thị chuỗi old→new + reason code, watermark người xem; một bản ghi meta-log được ghi tự động | [ ] |
| SC-002: Xuất log thiếu duyệt | Người dùng có quyền xem log | Thử xuất trực tiếp file ngoài luồng | Nút xuất bị vô hiệu; chỉ mở khi yêu cầu ở trạng thái `APPROVED` | [ ] |
| SC-003: Chặn xóa log | Bất kỳ vai nào (kể cả Super Admin) | Gọi API xóa/sửa bản ghi log | Từ chối ở mọi tầng; attempt ghi vào log bảo mật; UI không hiển thị nút xóa | [ ] |
| SC-004: Đứt chuỗi | Job hằng ngày phát hiện hash lệch | Job cập nhật trạng thái | Dashboard đỏ `INVALID`; liên kết alert CTO + CEO; khóa luồng xuất log | [ ] |

> **Liên kết:** SC-001 → REQ-BOD-005 (meta-log); SC-002 → REQ-BOD-005 (xuất cần duyệt CEO); SC-003 → REQ-BOD-005 (append-only); SC-004 → REQ-BOD-005 (job toàn vẹn hằng ngày).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/rbac-audit/[screen-group].md` |
| Bản counterpart (audit service + hash-chain) | `.mc-data/docs/phase2-features/core-backend/rbac-audit/` (SYS-CORE-BACKEND) |
