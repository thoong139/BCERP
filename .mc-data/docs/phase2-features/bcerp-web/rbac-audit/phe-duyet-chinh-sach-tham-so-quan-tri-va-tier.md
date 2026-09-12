# Tính Năng: Phê Duyệt Chính Sách, Tham Số Quản Trị & Tier

> **Dựa trên:** REQ-BOD-009 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** RBAC & Audit Log (SYS-BCERP-WEB)
> **Module:** RBAC & Audit Log (MOD-RBAC-AUDIT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/rbac-audit/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/rbac-audit/feat-004-impl.md`

> **Hướng dẫn ID:** FEAT-ID được tạo từ REQ-ID theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. Bản fan-out này dùng ID lane `FEAT-ERP-RBAC-004` — bản riêng của touchpoint SYS-BCERP-WEB (bản counterpart: SYS-CORE-BACKEND).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-RBAC-004 |
| Module | MOD-RBAC-AUDIT |
| Yêu cầu nghiệp vụ | REQ-BOD-009 |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP) |
| Phụ thuộc | FEAT-ERP-RBAC-005 (SSO/MFA — phiên duyệt), FEAT-ERP-RBAC-002 (audit trace cho mọi thay đổi tham số) |
| Ghi chú Expert (A7) | Mục A7 của `bod.md` đang chờ đánh giá chuyên gia đầy đủ; điều chỉnh liên quan đã chốt qua stakeholder review 12/09: DI-001 chốt ngưỡng mặc định 5/50/200 triệu VND (ma trận hạn mức không còn đánh dấu chưa chốt số); DI-002 chốt định mức theo chiều V6.0 5 tier A–E; DI-006 gỡ OPS_CX/FIN_COMPL — vai duyệt chỉ dùng registry 18 vai; chi tiết tại `bod.md` Mục A7 và `stakeholder-review.md` Phần F.3/F.5 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cung cấp trên web nội bộ một "bảng điều khiển chính sách" duy nhất: soạn thảo, trình duyệt, ký ban hành và tra cứu lịch sử hiệu lực của mọi tham số quản trị — ma trận hạn mức chi/giải ngân (5/50/200 triệu VND), định mức giá/Cost Rate Card, khung SLA theo tier, tham số Tier A–E, ngưỡng freshness dữ liệu. Mọi tham số vận hành theo mô hình effective-dated: có version, có ngày hiệu lực do người duyệt quyết, không thể sửa quá khứ, và mọi báo cáo dùng đúng phiên bản hiệu lực tại thời điểm dữ liệu.

**Phạm vi:**
- Bao gồm: trình soạn thảo version nháp kèm ngày hiệu lực đề xuất; luồng duyệt theo loại tham số (chính sách/định mức/tier → CEO; định nghĩa metric + ngưỡng freshness → CFO) với màn ký duyệt kèm ngày hiệu lực; màn tra cứu lịch sử version (version, ngày hiệu lực, người duyệt, old → new); nhắc rà soát định kỳ quý cho tham số Tier A–E; hiển thị trạng thái hiệu lực từng tham số trên web cho các phân hệ khác tham chiếu.
- Không bao gồm: lưu trữ version và chặn hiệu lực hồi tố (SYS-CORE-BACKEND enforce ở service layer — web không tự validate cục bộ); áp cấu hình xuống phân hệ (SYS_ADMIN thực thi sau duyệt — không tự chỉnh giá trị); soạn định mức chi tiết theo quy trình nghiệp vụ (thuộc phân hệ chuyên trách, ví dụ Rate Card ở REQ-HR-006); duyệt giao dịch tiền theo ngưỡng (REQ-BOD-001 — luồng phê duyệt vận hành, khác luồng duyệt tham số).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CEO | Soạn/trình duyệt ma trận hạn mức chi/giải ngân (5/50/200 triệu VND), định mức giá và tham số Tier A–E kèm ngày hiệu lực đề xuất | Ban hành chính sách có mốc hiệu lực rõ ràng, không tranh cãi "áp từ bao giờ" |
| 2 | BOD_CFO_CTO | Duyệt định nghĩa metric và ngưỡng freshness theo đúng thẩm quyền của vai CTO/CFO | Giữ một nguồn sự thật cho con số — không phân hệ nào tự định nghĩa |
| 3 | BOD_CEO/CFO | Xem lịch sử đầy đủ version của một tham số: ai duyệt, hiệu lực từ ngày, giá trị cũ → mới | Giải trình được khi báo cáo quá khứ dùng định nghĩa khác hiện tại |
| 4 | BOD_CEO | Nhắc rà soát định kỳ quý tham số Tier A–E và khung SLA theo tier | Chính sách không lỗi thời sau khi mô hình khách thay đổi |
| 5 | SYS_ADMIN | Xem các tham số đã duyệt chờ áp và trạng thái áp thành công/thất bại | Thực thi chính xác theo lệnh đã duyệt, không tự chỉnh giá trị |
| 6 | BOD_CEO/CFO | Áp gấp một chính sách giữa kỳ với mốc hiệu lực giữa tháng | Phản ứng nhanh với biến động (ví dụ phí nền tảng thay đổi) mà vẫn có mốc rõ ràng |
| 7 | Vai nghiệp vụ (FIN_L2, OPS_PLAN...) | Tra cứu tham số đang hiệu lực (hạn mức, SLA, tier) từ màn tham chiếu | Biết chắc mình đang vận hành theo phiên bản chính sách nào |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Effective-dating, versioning và chặn hồi tố enforce ở SYS-CORE-BACKEND; web trình bày đúng phiên bản và trạng thái.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | RBAC dùng đúng 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5, ...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight; tham số tier/SLA hiển thị theo vai tham chiếu | Cấu hình vai duyệt ngoài registry bị từ chối; màn soạn thảo chỉ mở cho vai có thẩm quyền |
| BR-002 | Mọi thay đổi tham số ghi audit log bất biến hash-chain (≥10 năm WORM với log phân quyền/chính sách); mỗi thao tác ghi có actor + timestamp + lý do; old → new value đầy đủ | Thiếu lý do khi soạn version nháp → không cho submit trình duyệt; trace thiếu → job chất lượng dữ liệu gắn cờ |
| BR-003 | Quarterly access review bắt buộc cho vai duyệt/thực thi tham số (REQ-BOD-007); kiêm nhiệm CFO/CTO phải có compensating control (REQ-BOD-002) — CFO không tự duyệt nhánh metric mà chính mình soạn khi trùng xung đột, phải về nhánh CEO | Vai trong trạng thái `SUSPENDED` (không review) → không thể ký duyệt tham số |
| BR-004 | SSO/MFA tập trung cho mọi phiên soạn thảo/ký duyệt; tham số chứa thông tin PII nhân sự (Cost Rate Card lồng dữ liệu lương/cost) hiển thị mức Confidential/Restricted theo ma trận REQ-HR-010 | Phiên không hợp lệ → chặn ký; dữ liệu Restricted mask theo vai, không có nút bỏ mask |
| BR-005 | Không hồi tố: tham số chỉ hiệu lực tương lai; sửa quá khứ bị chặn tuyệt đối; áp gấp giữa kỳ được phép nhưng mốc hiệu lực phải rõ ràng, có thông báo cho các phân hệ liên quan | Ngày hiệu lực trước ngày duyệt → chặn validate; hệ thống log attempt hồi tố để rà |
| BR-006 | Phân nhánh duyệt theo loại tham số: chính sách/định mức/tier → BOD_CEO; định nghĩa metric + ngưỡng freshness → BOD_CFO_CTO; SYS_ADMIN chỉ áp cấu hình sau duyệt | Vai sai nhánh → nút duyệt không xuất hiện; gọi API trực tiếp bị CORE từ chối + log |
| BR-007 | Ma trận hạn mức chi/giải ngân dùng khung 5/50/200 triệu VND đã chốt (DI-001) kèm quy tắc escalation lên cấp trên khi vượt thẩm quyền (50–200tr → FIN_L2 + CFO; >200tr/HĐ năm → CFO + CEO); các luồng giao dịch tham chiếu đúng nhánh ngưỡng tại thời điểm phát sinh | Cấu hình ma trận thiếu nhánh escalation → không cho ban hành; tham số sai cấu trúc bị validate chặn |
| BR-008 | Tham số Tier A–E rà soát định kỳ theo quý; quá hạn rà → tham số chuyển trạng thái "cần rà soát" trên web, không tự thay đổi giá trị | Quá hạn rà không chặn vận hành nhưng bắt buộc hiển thị cảnh báo ở mọi màn tham chiếu |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN | Vai khác (registry 18 vai) |
|-----------|---------|-------------|-----------|----------------------------|
| Soạn thảo version nháp | ✅ | ✅ | ❌ | ◐ (đề xuất tham chiếu qua phân hệ chuyên trách — không soạn trực tiếp) |
| Duyệt chính sách/định mức/tier | ✅ (độc quyền nhánh CEO) | ❌ | ❌ | ❌ |
| Duyệt định nghĩa metric + ngưỡng freshness | ❌ | ✅ (độc quyền nhánh CFO) | ❌ | ❌ |
| Xem lịch sử version + old → new | ✅ | ✅ | ◐ (trạng thái áp, không giá trị nhạy cảm) | ◐ (chỉ tham số công khai theo vai) |
| Xem giá trị tham số Restricted (cost rate lồng PII) | ✅ | ✅ | ❌ | ❌ (mask bắt buộc) |
| Áp cấu hình xuống phân hệ | ❌ | ❌ | ✅ (sau duyệt, log từng lệnh áp) | ❌ |
| Hồi sửa tham số đã hiệu lực (quá khứ) | ❌ | ❌ | ❌ | ❌ |

---

## 5. Trường Hợp Đặc Biệt

- Áp gấp giữa kỳ (ví dụ đổi khung SLA giữa tháng do nền tảng đổi chính sách phí): cho phép ngày hiệu lực giữa tháng, nhưng hệ thống phát thông báo cho mọi phân hệ tham chiếu và lưu điểm gắn thông báo vào audit log — không có "áp lặng lẽ".
- Hai version cùng một tham số có ngày hiệu lực chồng nhau: chặn khi duyệt version thứ hai trùng khoảng hiệu lực; bắt buộc điều chỉnh ngày hiệu lực hoặc supersede version trước.
- Cost Rate Card chứa lương/cost cá nhân (PII Restricted): luồng duyệt Rate Card phải tách khu hiển thị — CEO/CFO thấy giá trị, các màn khác chỉ thấy version + trạng thái; chi tiết dữ liệu Rate Card thuộc REQ-HR-006, tính năng này chỉ quản vòng đời tham số.
- Tham số sai sót sau khi ban hành: không sửa đè — ban hành version mới hiệu lực từ ngày mới; version sai được đánh dấu SUPERSEDED kèm reason, dữ liệu quá khứ vẫn tái lập đúng theo version từng thời điểm.
- CEO ủy quyền vắng mặt: duyệt chính sách ủy theo nguyên tắc chung B0.2 (cá nhân cụ thể, ≤14 ngày, tự hết hạn) — trừ thay đổi liên quan giao dịch do CFO khởi tạo (vô hiệu compensating control REQ-BOD-002); web hiển thị nhãn "duyệt theo ủy quyền #id" trên record.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Phiên bản tham số chính sách (parameter version)

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit trình duyệt)──► [PENDING_APPROVAL] ──(duyệt đúng nhánh)──► [APPROVED]
   ▲                                    │                                      │
   │ (soạn lại sau từ chối)             │ (từ chối)                           ▼
   └────────────────────── [REJECTED]  │                          [EFFECTIVE (từ ngày hiệu lực)]
                                                                              │
                                                       (version mới EFFECTIVE thay thế)
                                                                              ▼
                                                                        [SUPERSEDED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit trình duyệt | `PENDING_APPROVAL` | Soạn thảo (CEO/CFO tách nhánh) | Đủ giá trị + ngày hiệu lực tương lai + lý do thay đổi |
| `PENDING_APPROVAL` | Duyệt | `APPROVED` | CEO (chính sách/tier) hoặc CFO (metric/freshness) | Không trùng khoảng hiệu lực version khác; không hồi tố |
| `PENDING_APPROVAL` | Từ chối | `REJECTED` | Người duyệt đúng nhánh | Reason code bắt buộc |
| `APPROVED` | Đến ngày hiệu lực | `EFFECTIVE` | Hệ thống | Thông báo phát cho phân hệ tham chiếu |
| `EFFECTIVE` | Version mới `EFFECTIVE` | `SUPERSEDED` | Hệ thống | Giữ nguyên lịch sử; báo cáo quá khứ lookup theo ngày |
| `REJECTED` | Tạo version nháp mới | `DRAFT` | Soạn thảo | Version mới, giữ dấu vết bản bị từ chối |

**Quy tắc:**
- Không có chuyển tiếp `EFFECTIVE` → `DRAFT` — không sửa đè version đang hiệu lực; thay đổi luôn qua version mới.
- `SUPERSEDED` là trạng thái kết thúc của version (không kết thúc của tham số).
- Tham số Tier A–E quá hạn rà quý: giữ `EFFECTIVE` nhưng gắn cờ `review_overdue` hiển thị cảnh báo.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `policy_parameter` | `id`, `param_type`, `name`, `owner_role`, `review_cycle` | — | 1 dòng = 1 tham số quản trị (hạn mức, SLA, tier, freshness, metric) |
| `policy_parameter_version` | `id`, `parameter_id`, `version_no`, `payload`, `effective_from`, `state`, `reason` | FK → `policy_parameter.id` | Effective-dated; không UPDATE sau APPROVED |
| `policy_approval` | `id`, `version_id`, `approver_id`, `approver_role`, `channel`, `decided_at`, `reason_code` | FK → `policy_parameter_version.id` | Nhánh CEO/CFO theo param_type; có nhãn ủy quyền |
| `parameter_change_log` | `id`, `version_id`, `actor_id`, `action`, `old_value`, `new_value`, `occurred_at` | FK → `policy_parameter_version.id` | Bất biến hash-chain; nguồn tra cứu old → new |
| `parameter_review_flag` | `parameter_id`, `last_reviewed_quarter`, `review_overdue` | FK → `policy_parameter.id` | Nguồn cảnh báo rà soát quý (Tier A–E) |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ — chi tiết ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn hiệu lực hồi tố | CEO soạn version mới | Nhập ngày hiệu lực trước ngày hiện tại | Chặn lưu với thông báo; attempt ghi vào log; chỉ nhận ngày hiệu lực tương lai | [ ] |
| SC-002: Nhánh duyệt đúng thẩm quyền | Version tham số metric | CFO mở màn duyệt | Nút duyệt khả dụng cho CFO; CEO không thấy nút trên nhánh metric và ngược lại với nhánh chính sách | [ ] |
| SC-003: Báo cáo lookup đúng version | Tham số hạn mức đổi 5/50/200tr hiệu lực 01/10 | Chạy báo cáo giao dịch tháng 9 | Báo cáo dùng đúng version hiệu lực tại thời điểm giao dịch (bản trước đó), hiển thị phiên bản đã dùng | [ ] |
| SC-004: Cảnh báo rà soát tier quá hạn | Tham số Tier A–E không rà trong quý | Job cuối quý chạy | Tham số giữ EFFECTIVE nhưng mọi màn tham chiếu hiển thị cờ "cần rà soát"; cảnh báo về BOD | [ ] |

> **Liên kết:** SC-001/SC-003 → REQ-BOD-009 (không hồi tố + dùng đúng định nghĩa hiệu lực); SC-002 → REQ-BOD-009 (phân nhánh duyệt CEO/CFO); SC-004 → REQ-BOD-009 (rà soát quý Tier A–E).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/rbac-audit/[screen-group].md` |
| Bản counterpart (version store + enforcement) | `.mc-data/docs/phase2-features/core-backend/rbac-audit/` (SYS-CORE-BACKEND) |
