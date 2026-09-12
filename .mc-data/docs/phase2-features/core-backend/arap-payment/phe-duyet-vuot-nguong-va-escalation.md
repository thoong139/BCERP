# Tính Năng: Phê duyệt vượt ngưỡng & escalation

> **Dựa trên:** REQ-BOD-001 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** Tài chính — Kế toán & Công nợ (SYS-CORE-BACKEND)
> **Module:** AR/AP Payment — Phê duyệt & Giải ngân (MOD-ARAP-PAYMENT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/arap-payment/[screen-group].md`, `phase5-implementation/tasks/core-backend/arap-payment/feat-core-arap-001-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-ARAP-001 |
| Module | MOD-ARAP-PAYMENT |
| Yêu cầu nghiệp vụ | [REQ-BOD-001] — liên quan: REQ-FIN-008 (duyệt chi/giải ngân), REQ-FIN-006 (Financial Hard Stop), REQ-BOD-002 (compensating control kiêm nhiệm), REQ-BOD-011 (RBAC nền tảng) |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Cao (HIGH — MVP) |
| Giai đoạn | Giai đoạn 1 (approval engine) — luồng giải ngân đầy đủ hoàn thiện ở Giai đoạn 2 |
| Phụ thuộc | RBAC engine tập trung (REQ-BOD-011); tham số ma trận hạn mức effective-dated (REQ-BOD-009). Trong module: dùng chung SoD engine và luồng delegate với FEAT-CORE-ARAP-004 |
| Ghi chú Expert (A7) | `bod.md` có Mục A7 nhưng chưa ghi điều chỉnh cụ thể cho REQ-BOD-001 tại thời điểm phân tích (12/09/2026); khung ngưỡng 5/50/200 triệu VND đã được chủ dự án chốt làm mức mặc định theo DI-001 (phiên duyệt đề xuất 12/09/2026) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Xây dựng approval engine tập trung trên SYS-CORE-BACKEND, tự động phân nhánh mọi yêu cầu chi theo ma trận vai × ngưỡng × loại chi, ép dual approval khi vượt ngưỡng, escalation khi quá SLA và quản lý delegate khi người duyệt vắng mặt — đảm bảo không khoản chi nào được giải ngân thiếu chữ ký đúng thẩm quyền.

**Phạm vi:**
- Bao gồm: hàng đợi phê duyệt hợp nhất (giải ngân, chi khẩn, chiết khấu vượt biểu, hợp đồng năm) phục vụ qua headless API; quy VND theo tỷ giá snapshot ngày duyệt; tự phân nhánh ngưỡng ≤5 triệu / >5–50 triệu / >50–200 triệu / >200 triệu hoặc hợp đồng năm; dual approval tự động; escalation SLA 24/48/72h; delegate có thời hạn ≤14 ngày; audit log kèm reason code cho mọi lệnh duyệt/từ chối; kiểm tra hồ sơ đầu vào (chứng từ, ≥2 báo giá khi >20 triệu, mã dự án/khách hoặc overhead + lý do) ở tầng service.
- Không bao gồm: giao diện duyệt đầy đủ trên web (counterpart SYS-BCERP-WEB), bản duyệt di động push/MFA step-up (counterpart SYS-MOBILE-INTERNAL), hạch toán kế toán sau duyệt (FEAT-CORE-ARAP-006), ghi sổ công nợ AR/AP (FEAT-CORE-ARAP-003), các lệnh độc quyền của CFO như mở kỳ khóa (FEAT-CORE-ARAP-002).

**Đặc thù touchpoint SYS-CORE-BACKEND:** tính năng là headless API/domain service — toàn bộ business rule (ma trận ngưỡng, SoD, dual approval, SLA, delegate) phải được enforce ở tầng service, không tin UI; mọi response API là nguồn sự thật cho counterpart WEB/MOBILE hiển thị. Mỗi lệnh duyệt ghi audit log bất biến (hash-chain) kèm kênh thao tác; toàn bộ dữ liệu tài chính phân loại Restricted, bắt buộc tenant isolation và kiểm soát truy cập theo BR-FIN-603.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | Người đề nghị (mọi vai nội bộ qua counterpart web) | Submit yêu cầu chi qua API `POST /approval-requests` kèm chứng từ và mã dự án/khách | Engine tự phân nhánh đúng ngưỡng mà không phụ thuộc người nhập chọn luồng |
| 2 | BOD_CFO_CTO | Nhận danh sách yêu cầu thuộc thẩm quyền 50–200 triệu qua API hàng đợi, kèm hồ sơ chứng từ và SLA còn lại | Duyệt đúng hạn và có đủ ngữ cảnh trước khi ký |
| 3 | BOD_CEO | Duyệt các khoản >200 triệu hoặc hợp đồng năm qua API, chỉ khi đã có đủ chữ ký cấp dưới | Không duyệt "mù" khoản chưa qua cấp trung gian |
| 4 | BOD_CEO | Nhận escalation tự động khi yêu cầu quá SLA của cấp dưới | Kịp thời can thiệp các khoản chờ duyệt gây nguy cơ gián đoạn |
| 5 | BOD_CFO_CTO | Ủy quyền duyệt cho cá nhân cụ thể qua API delegate (≤14 ngày) | Luồng duyệt không tắc khi vắng mặt mà vẫn còn vết ủy quyền |
| 6 | BOD_CEO | Bị hệ thống chặn khi cố duyệt giao dịch do chính CFO khởi tạo vượt ngưỡng cao nhất | Compensating control kiêm nhiệm CFO/CTO không bị vô hiệu (nối REQ-BOD-002) |
| 7 | SYS_ADMIN | Truy vấn cấu hình ma trận ngưỡng hiện hành qua API cấu hình (read-only) | Hỗ trợ vận hành mà không tự chỉnh giá trị ngưỡng |
| 8 | BOD_CFO_CTO | Tra cứu audit log mọi lệnh duyệt/từ chối kèm reason code qua API | Phục vụ kiểm toán nội bộ và thanh tra theo REQ-FIN-012 |

**Diễn giải luồng chính (service layer):** khi nhận request tạo yêu cầu chi, service (1) xác thực vai và phạm vi dữ liệu qua RBAC, (2) chuẩn hóa số tiền về VND theo tỷ giá snapshot ngày duyệt, (3) kiểm tra tính đủ hồ sơ (chứng từ; ≥2 báo giá khi >20 triệu; mã dự án/khách hoặc overhead + lý do), (4) tra ma trận ngưỡng effective-dated để rót người duyệt, (5) khởi tạo bản ghi phê duyệt với SLA đếm ngược, (6) đăng ký job escalation. Mọi bước đều trả mã lỗi nghiệp vụ rõ ràng và ghi audit log khi có hành động ghi.

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-ARAP-101 | Ma trận ngưỡng giải ngân (chốt mặc định theo DI-001, cấu hình effective-dated qua REQ-BOD-009): ≤5 triệu VND → FIN_L2; >5–50 triệu → FIN_L2; >50–200 triệu → FIN_L2 + BOD_CFO_CTO (dual approval); >200 triệu hoặc hợp đồng năm → BOD_CFO_CTO + BOD_CEO. Quy VND theo tỷ giá snapshot ngày duyệt | Service từ chối rót sai cấp, trả lỗi `APPROVAL_ROUTE_VIOLATION`, ghi log attempt |
| BR-ARAP-102 | Cấm "duyệt trước, bổ sung sau": chứng từ phải upload và hợp lệ trước khi yêu cầu vào hàng đợi duyệt; ≥2 báo giá bắt buộc khi giá trị >20 triệu; chi outsource/tools bắt buộc gắn mã dự án/khách, không gắn được phải chọn overhead kèm lý do | Chặn submit ở tầng service (`INCOMPLETE_DOSSIER`), không có flag bỏ qua |
| BR-ARAP-103 | SoD dòng tiền 4 vai: người đề xuất ≠ người khớp tiền ≠ người duyệt ≠ người ghi sổ; người tạo yêu cầu không được tự duyệt yêu cầu đó; vi phạm bị block + log vi phạm cho BOD_CFO_CTO rà định kỳ | Trả lỗi `SOD_CONFLICT`, ghi log vi phạm immutable |
| BR-ARAP-104 | BOD_CFO_CTO là người đề xuất khoản vượt ngưỡng cao nhất → nhánh duyệt chỉ còn BOD_CEO; giao dịch do CFO khởi tạo vượt ngưỡng bị khóa "chờ CEO duyệt" (compensating control, nối REQ-BOD-002) | Chặn hard trong code, không override, không đường tắt |
| BR-ARAP-105 | SLA duyệt theo ngưỡng: 24h (≤50 triệu), 48h (50–200 triệu), 72h (>200 triệu/hợp đồng năm); quá hạn → escalation lên cấp duyệt trên + alert đỏ (nối REQ-BOD-006); chi khẩn duyệt 4h qua kênh khẩn + hậu kiểm chứng từ trong 24h, tồn hậu kiểm bật alert | Job escalation tự chuyển cấp và ghi audit log kèm timestamp từng chặng |
| BR-ARAP-106 | Delegate: chỉ BOD_CEO/BOD_CFO_CTO ủy quyền cho cá nhân cụ thể, hạn mức ≤ hạn mức người ủy theo loại chi, tối đa 14 ngày, tự hết hạn, mọi lệnh duyệt qua delegate gắn nhãn "theo ủy quyền #id"; CEO không ủy cho CFO/CTO quyết định giao dịch do chính CFO/CTO khởi tạo | Service từ chối delegate quá hạn/quá hạn mức (`DELEGATE_INVALID`), duyệt hộ không nhãn bị từ chối |
| BR-ARAP-107 | Financial Hard Stop "đã khớp tiền" FIN_L1 (REQ-FIN-006): mọi yêu cầu giải ngân liên quan tài khoản quảng cáo chỉ được chuyển trạng thái sang APPROVED khi trạng thái khớp tiền của lệnh nạp tương ứng = "Đã khớp tiền"; không nút override, không vai nào bypass — kể cả CEO/Super Admin | Service từ chối tuyệt đối (`HARD_STOP_NOT_RELEASED`), yêu cầu mở khóa thủ công bị từ chối + audit log bất biến |
| BR-ARAP-108 | Nạp nền tảng định kỳ trong hạn mức tuần đã duyệt không duyệt lại giao dịch con; sắp vượt hạn mức tuần phải duyệt bổ sung trước khi giải ngân; chi định kỳ đã cam kết (SaaS năm, retainer) duyệt 1 lần đầu năm, tự giải ngân theo lịch đã duyệt | Chặn giải ngân ngoài hạn mức (`WEEKLY_LIMIT_EXCEEDED`), cảnh báo + tạo yêu cầu bổ sung |
| BR-ARAP-109 | Mọi hành động duyệt/từ chối/escalate/delegate ghi audit log bất biến (append-only, hash-chain, ≥10 năm) kèm reason code bắt buộc khi từ chối; connector phần mềm kế toán VAS nhận lệnh đã duyệt qua cấu hình kết nối ngoại vi trong Settings (DI-004 12/09 — vendor-agnostic, import/export chuẩn + adapter API), legacy PMS chỉ read-only sau migrate chọn lọc | Ghi log bắt buộc; thiếu reason code thì transaction bị rollback ở tầng service |
| BR-ARAP-110 | Hóa đơn điện tử và thuế liên quan đến các khoản chi được duyệt tuân thủ TT78/2021 + NĐ123/2020; phí nền tảng & nghĩa vụ thuế (VAT/FCT) được nhận diện theo giao dịch gốc khi hạch toán (chi tiết tại FEAT-CORE-ARAP-005/007) | Service từ chối duyệt hồ sơ thiếu thông tin thuế bắt buộc (`TAX_INFO_MISSING`) |

---

## 4. Phân Quyền

> Phân quyền enforce tại tầng API/domain service của SYS-CORE-BACKEND; counterpart WEB/MOBILE chỉ hiển thị theo quyền đã check tập trung qua RBAC engine.

| Hành động (API) | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN |
|-----------------|---------|-------------|-----------|
| Xem hàng đợi phê duyệt của mình | ✅ | ✅ | ❌ |
| Xem toàn bộ yêu cầu chi (tổng hợp) | ✅ | ✅ | ❌ |
| Tạo yêu cầu chi (đề nghị) | ✅ | ✅ | ❌ |
| Duyệt ≤50 triệu | ❌ | ❌ (qua FIN_L2) | ❌ |
| Duyệt 50–200 triệu (dual với FIN_L2) | ✅ | ✅ | ❌ |
| Duyệt >200 triệu / hợp đồng năm | ✅ (bắt buộc có) | ✅ (đồng duyệt) | ❌ |
| Duyệt giao dịch do CFO khởi tạo vượt ngưỡng | ✅ (duy nhất) | ❌ | ❌ |
| Từ chối kèm reason code | ✅ | ✅ | ❌ |
| Tạo/thu hồi delegate | ✅ | ✅ | ❌ |
| Nhận delegate duyệt | ✅ | ❌ (không tự ủy cho mình) | ❌ |
| Sửa cấu hình ma trận ngưỡng | ✅ (duyệt ban hành) | ✅ (đề xuất) | ❌ (chỉ thực thi sau duyệt) |
| Xem cấu hình ngưỡng hiện hành | ✅ | ✅ | ✅ (read-only) |
| Tra cứu audit log phê duyệt | ✅ | ✅ | ✅ (theo phạm vi được gán) |
| Xóa/sửa bản ghi phê duyệt đã ghi | ❌ | ❌ | ❌ (không ai, kể cả Super Admin) |

---

## 5. Trường Hợp Đặc Biệt

- **Chi khẩn (nền tảng sắp khóa TKQC, khủng hoảng cần outsource ngay):** service mở luồng khẩn cho duyệt 4h với priority cao nhất, nhưng vẫn ép đủ chữ ký theo ma trận; sau giải ngân bật phiên hậu kiểm 24h — chứng từ bổ sung không nộp đúng hạn thì alert BOD và đánh dấu vi phạm quy trình.
- **Người duyệt vắng mặt không có delegate:** yêu cầu chờ đến khi quá SLA thì tự escalation lên cấp trên; với BOD_CEO vắng, theo nguyên tắc B0 — treo lệnh, không duyệt hộ; CFO/CEO vẫn có thể thao tác từ xa qua counterpart mobile với MFA step-up.
- **Người đề xuất trùng người duyệt (kiêm nhiệm):** service phát hiện vai trùng theo luồng và ép nhánh duyệt thay thế (CFO khởi tạo → CEO duyệt); không cho phép "duyệt hộ có ghi nhận" để luồng này.
- **Tỷ giá biến động giữa ngày tạo và ngày duyệt:** số tiền quy VND cố định theo snapshot ngày duyệt — yêu cầu tạo trước, duyệt sau mốc đổi tỷ giá dùng đúng snapshot ngày duyệt, không tính lại; mọi thay đổi giá trị sau submit bắt buộc tạo phiên bản yêu cầu mới.
- **Yêu cầu chi hoàn (reversal) của khoản đã duyệt:** đi qua cùng approval engine với nhãn loại chi riêng, gắn reference tới yêu cầu gốc, không sửa bản ghi gốc.
- **Multi-tenant:** mọi truy vấn hàng đợi/duyệt phải filter tenant ở tầng service và DB (RLS); không có API nào trả dữ liệu tài chính chéo tenant kể cả cho SYS_ADMIN.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Phiếu đề nghị chi / yêu cầu phê duyệt (`approval_request`)

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit)──► [SUBMITTED] ──(route)──► [PENDING_APPROVAL] ──(approve đủ chữ ký)──► [APPROVED] ──(release)──► [RELEASED]
                          │                        │           │
                          │ (withdraw)            │ (reject)  │ (quá SLA)
                          ▼                        ▼           ▼
                      [WITHDRAWN]              [REJECTED]  [ESCALATED] ──(approve)──► [APPROVED]
                                                               │
                                                               │ (reject)
                                                               ▼
                                                           [REJECTED]
[APPROVED] ──(thiếu Hard Stop khớp tiền)──► [ON_HOLD_HARD_STOP] ──(khớp tiền xong)──► [APPROVED]
[RELEASED] ──(hậu kiểm chi khẩn)──► [POST_AUDITED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `SUBMITTED` | Người đề nghị | Đủ chứng từ; ≥2 báo giá nếu >20 triệu; mã dự án/khách hoặc overhead + lý do; không vi phạm SoD |
| `SUBMITTED` | Route theo ma trận | `PENDING_APPROVAL` | Service tự động | Ngưỡng, loại chi, vai duyệt hợp lệ; quy VND theo snapshot |
| `PENDING_APPROVAL` | Approve (một cấp) | `PENDING_APPROVAL` | Vai duyệt theo ngưỡng | Ghi audit log + kênh thao tác; dual approval chưa đủ thì chưa sang APPROVED |
| `PENDING_APPROVAL` | Reject | `REJECTED` | Vai duyệt theo ngưỡng | Reason code bắt buộc |
| `PENDING_APPROVAL` | Escalate (quá SLA) | `ESCALATED` | Service tự động | Timestamp từng chặng; alert đỏ cho cấp trên |
| `PENDING_APPROVAL` | Chuyển chờ Hard Stop | `ON_HOLD_HARD_STOP` | Service tự động | Yêu cầu liên quan TKQC mà lệnh nạp chưa "Đã khớp tiền" |
| `ON_HOLD_HARD_STOP` | Mở chờ | `APPROVED` (nếu đủ chữ ký) | Service tự động | Sự kiện "Đã khớp tiền" FIN_L1 xác nhận — không có lệnh mở thủ công |
| `PENDING_APPROVAL`/`ESCALATED` | Approve đủ chữ ký | `APPROVED` | Vai duyệt cuối theo ma trận | Hard Stop đã thỏa (nếu liên quan TKQC); dual approval đủ |
| `APPROVED` | Release giải ngân | `RELEASED` | Người thực hiện chi (≠ người duyệt) | Thỏa SoD 4 vai; nằm trong hạn mức tuần/định kỳ |
| `RELEASED` | Hậu kiểm chi khẩn | `POST_AUDITED` | FIN_L2/CFO | Hoàn thành trong 24h; tồn hậu kiểm → alert |

**Quy tắc:**
- Không quay về trạng thái trước; sửa nội dung sau submit = hủy + tạo phiên bản mới.
- `REJECTED`, `WITHDRAWN`, `POST_AUDITED` là trạng thái kết thúc — không chuyển tiếp; muốn làm lại phải tạo phiếu mới.
- Mọi chuyển trạng thái ghi audit log bất biến (old → new, actor, kênh, timestamp) theo REQ-FIN-012.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `approval_request` | `id`, `tenant_id`, `type` (giải ngân/chi khẩn/chiết khấu/chi định kỳ), `amount_original`, `currency`, `amount_vnd`, `fx_snapshot_id`, `cost_type` (project/customer/overhead), `overhead_reason`, `status` | FK → `tenants.id`, FK → `fx_snapshots.id` | Soft delete cấm — chỉ reversal có reason code |
| `approval_step` | `request_id`, `seq`, `required_role`, `approver_id`, `channel` (web/mobile/api), `decision`, `reason_code`, `decided_at`, `sla_deadline` | FK → `approval_request.id` | Dual approval = ≥2 step bắt buộc; immutable |
| `approval_route_rule` | `threshold_min`, `threshold_max`, `cost_type`, `annual_contract_flag`, `required_roles[]`, `sla_hours`, `effective_from`, `effective_to`, `version` | Độc lập, effective-dated | Không hồi tố; đổi qua REQ-BOD-009 |
| `delegate_assignment` | `delegator_id`, `delegate_id`, `cost_type_scope`, `max_amount_vnd`, `valid_from`, `valid_to`, `status` | FK → `users.id` ×2 | Tối đa 14 ngày, tự hết hạn; log "theo ủy quyền #id" |
| `escalation_log` | `request_id`, `from_step`, `to_role`, `triggered_at`, `sla_breach_hours` | FK → `approval_request.id` | Sinh bởi job escalation |
| `audit_log` | `entity`, `entity_id`, `actor`, `old_value`, `new_value`, `reason_code`, `channel`, `hash_prev`, `hash_self` | Polymorphic | Append-only, hash-chain, ≥10 năm WORM |

---

## 8. Acceptance Criteria

> Phác thảo sơ bộ Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Phân nhánh đúng ngưỡng | Yêu cầu chi 80 triệu VND hợp lệ hồ sơ | Service nhận submit | Rót FIN_L2 + CFO (dual), SLA 48h, không cho 1 người duyệt đủ | [ ] |
| SC-002: Chặn thiếu báo giá | Yêu cầu 25 triệu, chỉ 1 báo giá | Submit | Bị chặn `INCOMPLETE_DOSSIER`, không vào hàng đợi | [ ] |
| SC-003: CFO khởi tạo → CEO duyệt | Giao dịch >200 triệu do CFO tạo | Kiểm tra nhánh duyệt | Chỉ CEO trong danh sách duyệt; CFO không thấy nút duyệt chính mình | [ ] |
| SC-004: Escalation quá SLA | Yêu cầu 50–200 triệu chờ >48h | Job escalation chạy | Chuyển `ESCALATED`, alert cấp trên, log timestamp | [ ] |
| SC-005: Hard Stop chặn giải ngân | Yêu cầu nạp TKQC APPROVED đủ chữ ký, lệnh nạp chưa "Đã khớp tiền" | Gọi API release | Từ chối `HARD_STOP_NOT_RELEASED`, log bất biến, không có lối override | [ ] |
| SC-006: Delegate hết hạn | Delegate 14 ngày đã quá hạn | Người được ủy duyệt | Bị từ chối `DELEGATE_INVALID`, lệnh trả về hàng đợi người ủy | [ ] |
| SC-007: Tenant isolation | SYS_ADMIN gọi API hàng đợi của tenant khác | Truy vấn | Trả rỗng/403; attempt ghi meta-log | [ ] |

> **Liên kết:** SC-001–SC-004 map REQ-BOD-001; SC-005 map REQ-FIN-006/REQ-FIN-008; SC-006–SC-007 map REQ-BOD-001 + REQ-BOD-011.

---

## Tài Liệu Kỹ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (approval engine) | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (fan-out WEB/MOBILE) | `technical-specs/integration-map.md` |
| Màn hình UI counterpart | `phase4-ux/core-backend/arap-payment/[screen-group].md` |
| Quy tắc nguồn | `phase1-business/departments/bod/bod.md` (B0, B1 — BR-BOD-001.1–001.4), `phase1-business/departments/finance/finance.md` (BR-FIN-304), `phase1-business/P1-02-business-workflow.md` (bốn trụ cột — Financial Hard Stop) |
