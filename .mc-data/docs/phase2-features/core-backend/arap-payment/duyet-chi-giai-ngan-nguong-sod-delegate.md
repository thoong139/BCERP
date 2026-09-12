# Tính Năng: Duyệt chi/giải ngân: ngưỡng, SoD, delegate

> **Dựa trên:** REQ-FIN-008 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Tài chính — Kế toán & Công nợ (SYS-CORE-BACKEND)
> **Module:** AR/AP Payment — Duyệt chi & Giải ngân (MOD-ARAP-PAYMENT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/arap-payment/[screen-group].md`, `phase5-implementation/tasks/core-backend/arap-payment/feat-core-arap-004-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-ARAP-004 |
| Module | MOD-ARAP-PAYMENT |
| Yêu cầu nghiệp vụ | [REQ-FIN-008] — liên quan: REQ-FIN-006 (Financial Hard Stop), REQ-BOD-001 (approval engine/escalation), REQ-BOD-002 (compensating control), REQ-FIN-004 (snapshot tỷ giá) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Cao (HIGH — Giai đoạn 2) |
| Giai đoạn | Giai đoạn 2 (duyệt là use case trọng tâm của counterpart SYS-MOBILE-INTERNAL) |
| Phụ thuộc | FEAT-CORE-ARAP-001 (approval engine, escalation, delegate — dùng chung); snapshot tỷ giá REQ-FIN-004; FEAT-CORE-ARAP-003 (AP nền tảng cho duyệt gộp tuần); FEAT-CORE-ARAP-006 (xuất lệnh chi đã duyệt xuống sổ VAS) |
| Ghi chú Expert (A7) | `finance.md` có Mục A7 nhưng chưa thực hiện review tại thời điểm viết; khung ngưỡng 5/50/200 triệu VND đã được chủ dự án chốt làm mức mặc định theo DI-001 (12/09/2026) — business rules lấy từ BR-FIN-304 và BR-BOD-001 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa mọi khoản chi của BCERP (nạp nền tảng, mua sắm, outsource, tạm ứng) qua luồng duyệt phân cấp theo giá trị được enforce hoàn toàn ở tầng service của SYS-CORE-BACKEND: SoD engine ép 4 vai dòng tiền tách biệt (đề xuất ≠ khớp tiền ≠ duyệt ≠ thực hiện chi/ghi sổ), chặn giải ngân thiếu chữ ký hoặc sai ngưỡng, và quản lý delegate có thời hạn — không còn "duyệt trước bổ sung sau" hay lệnh chi miệng.

**Phạm vi:**
- Bao gồm: domain service duyệt chi theo ma trận ngưỡng (≤5 triệu FIN_L2; >5–50 triệu FIN_L2; >50–200 triệu FIN_L2 + CFO dual approval; >200 triệu hoặc hợp đồng năm CFO + CEO); quy VND theo tỷ giá snapshot ngày duyệt; SoD engine block submit khi vai trùng + log vi phạm; kiểm tra chứng từ upload trước khi duyệt (≥2 báo giá khi >20 triệu; mã dự án/khách hoặc overhead + lý do cho outsource/tools); duyệt gộp kế hoạch nạp tuần trước đầu tuần; chi khẩn kênh khẩn + hậu kiểm 24h; chi định kỳ đã cam kết duyệt 1 lần đầu năm; delegate CFO chỉ định cá nhân (≤14 ngày, tự thu hồi, nhãn "theo ủy quyền #id").
- Không bao gồm: màn hình tạo/duyệt trên web (counterpart SYS-BCERP-WEB), kênh duyệt mobile MFA (counterpart SYS-MOBILE-INTERNAL), ma trận escalation/hàng đợi hợp nhất đa loại chi (FEAT-CORE-ARAP-001 — feature này tiêu dùng engine đó cho luồng tài chính), lệnh độc quyền CFO (FEAT-CORE-ARAP-002), hạch toán xuống sổ (FEAT-CORE-ARAP-006).

**Đặc thù touchpoint SYS-CORE-BACKEND:** SoD engine và kiểm tra ngưỡng là service layer logic — mọi API gọi từ web/mobile đều đi qua cùng một điểm check; mobile được thiết kế làm kênh duyệt trọng tâm nên API phải trả đủ ngữ cảnh duyệt gọn (tóm tắt + trạng thái chứng từ) và chấp nhận chữ ký số kèm MFA assertion từ counterpart; mọi lệnh duyệt/đấu chi ghi audit log bất biến kèm kênh; dữ liệu giải ngân phân loại Restricted với tenant isolation; hàng đợi duyệt gộp tuần và chi khẩn chạy server-side job.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | Người đề nghị chi (FIN_L1/OPS qua counterpart web) | Tạo chứng từ chi qua API kèm file chứng từ và mã dự án/khách | Được hệ thống tự phân nhánh duyệt đúng ngưỡng, không tự chọn luồng |
| 2 | FIN_L2 | Nhận hàng đợi chi ≤50 triệu qua API kèm SLA đếm ngược | Duyệt nhanh đúng thẩm quyền, không duyệt hộ khoản lớn hơn hạn mức |
| 3 | BOD_CFO_CTO | Dual approval các khoản 50–200 triệu và đồng duyệt >200 triệu qua API | Kiểm soát khoản lớn trước khi tiền rời tài khoản |
| 4 | FIN_L1 | Thực hiện giao dịch con của kế hoạch nạp tuần đã duyệt gộp mà không phải duyệt lại từng lệnh | Giảm thao tác lặp trong khi vẫn trong hạn mức tuần đã phê |
| 5 | FIN_L2 | Đề xuất duyệt bổ sung qua API khi kế hoạch tuần sắp vượt hạn mức | Không phát sinh chi ngoài kế hoạch mà không có phê duyệt |
| 6 | BOD_CFO_CTO | Ủy quyền duyệt cho cá nhân cụ thể qua API delegate (≤14 ngày, hạn mức ≤ FIN_L2) | Luồng duyệt không tắc khi vắng, mọi lệnh vẫn gắn nhãn ủy quyền |
| 7 | FIN_L2 | Kích hoạt kênh chi khẩn qua API cho nền tảng sắp khóa TKQC (duyệt 4h cùng CFO) | Xử lý khẩn mà vẫn còn hậu kiểm 24h có vết |
| 8 | Hệ thống (SoD engine) | Tự block submit khi vai người tạo = người duyệt và log vi phạm cho CFO | Không ai tự duyệt chi của chính mình trên bất kỳ kênh nào |

**Diễn giải luồng chính (service layer):** (1) nhận request chi → validate hồ sơ + SoD + quy VND snapshot ngày duyệt; (2) route theo ma trận ngưỡng effective-dated (dùng chung approval engine của FEAT-CORE-ARAP-001); (3) chờ đủ chữ ký theo cấp — chặn hard khi thiếu; (4) trước release liên quan TKQC: kiểm tra Hard Stop "đã khớp tiền" FIN_L1; (5) release → sinh lệnh chi/ghi nhận giải ngân, trừ hạn mức tuần; (6) chi khẩn bật phiên hậu kiểm 24h. Mọi bước trả lỗi nghiệp vụ riêng và ghi audit log với reason code khi từ chối.

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-ARAP-401 | Ma trận ngưỡng duyệt chi (chốt mặc định DI-001, cấu hình effective-dated): ≤5 triệu VND → FIN_L2; >5–50 triệu → FIN_L2; >50–200 triệu → FIN_L2 + BOD_CFO_CTO (dual approval); >200 triệu hoặc hợp đồng năm → BOD_CFO_CTO + BOD_CEO (CFO là người đề xuất khi phát sinh từ tài chính). Quy VND theo tỷ giá snapshot ngày duyệt | Route sai cấp bị từ chối `APPROVAL_ROUTE_VIOLATION`; thiếu 1 chữ ký thì không giải ngân được |
| BR-ARAP-402 | SoD engine: tạo chứng từ ≠ duyệt ≠ thực hiện chi (2 người thường, 3 người dual approval); người đối soát ≠ người duyệt điều chỉnh; block submit khi vai trùng + log vi phạm cho BOD_CFO_CTO rà định kỳ; SoD 4 vai dòng tiền (đề xuất ≠ khớp tiền ≠ duyệt chi ≠ ghi sổ) | Chặn ở tầng service (`SOD_CONFLICT`), không flag bỏ qua; vi phạm ghi log immutable |
| BR-ARAP-403 | Chứng từ (báo giá, hợp đồng, quote SaaS) upload và hợp lệ trước khi duyệt — cấm "duyệt trước bổ sung sau"; ≥2 báo giá bắt buộc khi >20 triệu; chi outsource/tools bắt buộc gắn mã dự án/khách phục vụ P&L, không gắn được phải chọn overhead kèm lý do | Submit bị chặn `INCOMPLETE_DOSSIER`; thiếu reason overhead bị rollback |
| BR-ARAP-404 | Financial Hard Stop "đã khớp tiền" FIN_L1 (REQ-FIN-006) là điều kiện tiên quyết của mọi giải ngân liên quan TKQC: tiền về tài khoản BC + khớp số với lệnh nạp, evidence + timestamp; không nút override, không vai nào bypass kể cả CEO/Super Admin; "chờ duyệt"/"khách hứa chuyển" không có giá trị | Release bị từ chối `HARD_STOP_NOT_RELEASED`; yêu cầu mở khóa thủ công bị từ chối + audit log bất biến |
| BR-ARAP-405 | Nạp nền tảng định kỳ: duyệt gộp kế hoạch tuần trước đầu tuần; FIN_L1 thực hiện giao dịch con không duyệt lại trong hạn mức tuần; sắp vượt hạn mức tuần → cảnh báo + duyệt bổ sung (FIN_L2 ≤50 triệu / CFO >50 triệu); chi định kỳ đã cam kết (SaaS năm, retainer) duyệt 1 lần đầu năm, tự giải ngân theo lịch | Giao dịch con vượt hạn mức bị chặn `WEEKLY_LIMIT_EXCEEDED`; ngoài lịch định kỳ phải tạo yêu cầu mới |
| BR-ARAP-406 | Chi khẩn (nền tảng sắp khóa TKQC, khủng hoảng cần outsource ngay): FIN_L2 + CFO duyệt qua kênh khẩn trong hệ thống với SLA 4h; hậu kiểm chứng từ 24h sau giải ngân — tồn hậu kiểm bật alert; khẩn ngoài giờ vẫn phải tạo lệnh trên hệ thống trước khi xử lý | Chi khẩn không hậu kiểm đúng hạn → alert BOD + đánh dấu vi phạm quy trình |
| BR-ARAP-407 | Delegate FIN_L2: chỉ BOD_CFO_CTO ủy quyền cho cá nhân cụ thể, hạn mức ≤ FIN_L2, tối đa 14 ngày, tự thu hồi khi hết hạn, log gắn nhãn "theo ủy quyền #id"; kiêm nhiệm CFO kiêm CTO → giao dịch vượt ngưỡng cao nhất do CEO duyệt; lệnh độc quyền CFO (FEAT-CORE-ARAP-002) không delegate được | Delegate quá hạn/quá hạn mức bị từ chối `DELEGATE_INVALID`; duyệt hộ không nhãn bị chặn |
| BR-ARAP-408 | Nhắc duyệt SLA 24h/48h/72h theo ngưỡng; duyệt qua kênh mobile bắt buộc MFA; mọi duyệt/từ chối ghi audit log kèm reason code, kênh thao tác; lưu trữ WORM ≥10 năm | Thiếu reason code → rollback; log thiếu kênh → validation lỗi |
| BR-ARAP-409 | Lệnh chi đã duyệt là đầu vào duy nhất cho hạch toán: xuất bút toán xuống phần mềm kế toán VAS qua cấu hình kết nối ngoại vi trong Settings (DI-004 12/09 — vendor-agnostic, import/export chuẩn + adapter API); legacy PMS migrate chọn lọc (master data + dự án active + payment history 12 tháng) rồi legacy read-only; hóa đơn điện tử thuế liên quan khoản chi xử lý theo FEAT-CORE-ARAP-005; phí nền tảng/nghĩa vụ thuế ghi nhận theo giao dịch gốc theo FEAT-CORE-ARAP-007 | Xuất sổ từ lệnh chưa duyệt bị chặn; điều chỉnh sau duyệt phải qua reversal có duyệt |

---

## 4. Phân Quyền

> Enforce tại tầng service; ma trận phản ánh quyền gọi API domain — counterpart web/mobile hiển thị theo kết quả check tập trung.

| Hành động (API) | FIN_L1 | FIN_L2 | BOD_CFO_CTO |
|-----------------|--------|--------|-------------|
| Tạo chứng từ chi (đề nghị) | ✅ | ✅ | ✅ |
| Duyệt chi ≤50 triệu | ❌ | ✅ | ✅ (duyệt thay khi là người đề xuất) |
| Dual approval 50–200 triệu | ❌ | ✅ (cấp 1) | ✅ (cấp 2 — bắt buộc) |
| Đồng duyệt >200 triệu / hợp đồng năm | ❌ | ❌ | ✅ (cùng CEO) |
| Thực hiện giao dịch con kế hoạch tuần | ✅ | ❌ | ❌ |
| Duyệt bổ sung hạn mức tuần (≤50 triệu) | ❌ | ✅ | ❌ |
| Duyệt bổ sung hạn mức tuần (>50 triệu) | ❌ | ❌ | ✅ |
| Kích hoạt kênh chi khẩn | ❌ | ✅ (đề xuất + đồng duyệt với CFO) | ✅ |
| Hậu kiểm chi khẩn | ❌ | ✅ | ✅ |
| Tạo/thu hồi delegate cho FIN_L2 | ❌ | ❌ | ✅ |
| Duyệt theo delegate | ❌ | ✅ (kèm nhãn ủy quyền) | ❌ (không tự ủy cho mình) |
| Xem hàng đợi + trạng thái chứng từ | ✅ (phần liên quan) | ✅ | ✅ |
| Xem audit log giải ngân | ✅ (theo phạm vi) | ✅ | ✅ |
| Sửa lệnh chi sau khi đã duyệt | ❌ | ❌ (chỉ reversal có duyệt) | ❌ |
| Xóa chứng từ đã đính vào lệnh đã duyệt | ❌ | ❌ | ❌ |

---

## 5. Trường Hợp Đặc Biệt

- **Chi khẩn ngoài giờ hành chính:** vẫn phải tạo lệnh trên hệ thống trước khi xử lý — approval không được bỏ qua; kênh khẩn rút SLA còn 4h nhưng không rút bớt chữ ký; sau 24h phải nộp đủ chứng từ hậu kiểm, thiếu thì alert BOD.
- **Người đề xuất là chính CFO (chi quản trị):** nhánh >50 triệu tự động bỏ cấp CFO, chuyển thành CFO đề xuất → CEO duyệt (compensating control kiêm nhiệm); hệ thống phát hiện theo vai trong token, không cấu hình tay.
- **Tỷ giá đổi giữa ngày tạo và ngày duyệt:** giá trị quy VND khóa theo snapshot ngày duyệt; nếu người tạo sửa số tiền nguyên tệ sau submit → hủy phiên, tạo yêu cầu mới, không chấp nhận sửa đè.
- **Kế hoạch tuần được duyệt nhưng khách/nguồn tiền đổi giữa tuần:** giao dịch con vẫn trừ hạn mức tuần của kế hoạch gốc; đổi nguồn tiền vượt kế hoạch → bắt buộc duyệt bổ sung trước khi giải ngân.
- **Delegate trùng với người đã đề xuất khoản:** delegate không khắc phục vi phạm SoD — engine vẫn chặn nếu người được ủy quyền là người tạo chứng từ; delegate chỉ thay vị trí "người duyệt" hợp lệ.
- **Lệnh chi gắn dự án nhưng dự án đã đóng trước ngày duyệt:** engine cảnh báo `PROJECT_CLOSED`, yêu cầu chọn lại mã dự án hoặc overhead + lý do trước khi tiếp tục luồng duyệt.
- **Chứng từ bằng ngoại tệ:** lưu nguyên tệ + tỷ giá snapshot dùng chung REQ-FIN-004; báo cáo và hạn mức so theo VND.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Lệnh chi/giải ngân (`disbursement_order`)

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit: đủ chứng từ + SoD)──► [PENDING_APPROVAL] ──(dual approval đủ)──► [APPROVED] ──(release: Hard Stop thỏa)──► [RELEASED] ──(post-audit nếu khẩn)──► [POST_AUDITED]
                                            │                          │
                                            │ (reject / withdraw)      │ (Hard Stop chưa khớp tiền)
                                            ▼                          ▼
                                        [REJECTED]               [ON_HOLD_HARD_STOP] ──(sự kiện khớp tiền)──► [APPROVED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `PENDING_APPROVAL` | Người tạo | Chứng từ hợp lệ; ≥2 báo giá nếu >20 triệu; mã dự án/khách hoặc overhead + lý do; SoD thỏa; quy VND snapshot |
| `PENDING_APPROVAL` | Approve từng cấp | `PENDING_APPROVAL` | Vai theo ma trận ngưỡng | Audit log + kênh; dual chưa đủ chưa sang APPROVED |
| `PENDING_APPROVAL` | Reject | `REJECTED` | Vai duyệt hiện tại | Reason code bắt buộc |
| `PENDING_APPROVAL` | Chuyển chờ Hard Stop | `ON_HOLD_HARD_STOP` | Service tự động | Liên quan TKQC, lệnh nạp chưa "Đã khớp tiền" |
| `ON_HOLD_HARD_STOP` | Mở chờ | `APPROVED` (nếu đủ chữ ký) | Service tự động | Sự kiện "Đã khớp tiền" FIN_L1 — không lệnh mở tay |
| `APPROVED` | Release | `RELEASED` | Người thực hiện chi (≠ người duyệt) | SoD 4 vai; trong hạn mức tuần/lịch định kỳ |
| `RELEASED` | Hậu kiểm (chi khẩn) | `POST_AUDITED` | FIN_L2/CFO | Hoàn thành ≤24h; trễ → alert BOD |

**Quy tắc:**
- Không quay về trạng thái trước; `REJECTED`, `WITHDRAWN`, `POST_AUDITED` là kết thúc — làm lại phải tạo lệnh mới.
- Mọi chuyển trạng thái ghi audit log bất biến (old → new, actor, kênh web/mobile, timestamp).

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `disbursement_order` | `id`, `tenant_id`, `type` (nạp nền tảng/mua sắm/outsource/tạm ứng), `amount_original`, `currency`, `amount_vnd`, `fx_snapshot_id`, `project_id`/`customer_id`/`overhead_reason`, `urgent_flag`, `status` | FK → `tenants.id`, `fx_snapshots.id`, `projects.id` | Soft delete cấm; reversal có duyệt |
| `disbursement_attachment` | `order_id`, `file_id`, `type` (chứng từ/báo giá/hợp đồng), `uploaded_at` | FK → `disbursement_order.id` | Upload trước duyệt; immutable sau approve |
| `weekly_spend_plan` | `week_start`, `platform`, `planned_vnd`, `approved_by`, `limit_vnd`, `status` | FK → `tenants.id`, `platforms.id` | Duyệt gộp trước đầu tuần |
| `post_audit_case` | `order_id`, `deadline`, `evidence`, `status`, `closed_at` | FK → `disbursement_order.id` | Chi khẩn; SLA 24h |
| `delegate_assignment` | `delegator_id`, `delegate_id`, `max_amount_vnd`, `valid_from`, `valid_to`, `status` | FK → `users.id` ×2 | ≤14 ngày, tự hết hạn, nhãn "theo ủy quyền #id" |
| `sod_violation_log` | `order_id`, `conflict_roles`, `detected_at`, `reviewed_by` | FK → `disbursement_order.id` | Báo cáo định kỳ cho CFO |
| `audit_log` | Append-only + hash-chain | Polymorphic | ≥10 năm WORM |

---

## 8. Acceptance Criteria

> Phác thảo sơ bộ Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Dual approval 50–200 triệu | Lệnh chi 120 triệu đủ chứng từ | FIN_L2 duyệt cấp 1 | Chưa release; chỉ khi CFO duyệt cấp 2 mới APPROVED | [ ] |
| SC-002: SoD block | Người tạo chứng từ cố tự duyệt | Submit duyệt | Chặn `SOD_CONFLICT`, ghi log vi phạm | [ ] |
| SC-003: Chặn thiếu chứng từ | Lệnh 30 triệu chưa upload chứng từ | Submit | Bị chặn `INCOMPLETE_DOSSIER`, không vào hàng đợi | [ ] |
| SC-004: Hard Stop chặn release | Lệnh nạp TKQC APPROVED, lệnh nạp chưa khớp tiền | Gọi API release | Từ chối `HARD_STOP_NOT_RELEASED`, log bất biến | [ ] |
| SC-005: Giao dịch con trong hạn mức tuần | Kế hoạch tuần đã duyệt 300 triệu | FIN_L1 thực hiện giao dịch con 20 triệu | Không cần duyệt lại; hạn mức còn 280 triệu | [ ] |
| SC-006: Duyệt bổ sung vượt tuần | Hạn mức tuần còn 5 triệu, cần thêm 30 triệu | Đề xuất bổ sung | Route CFO (>50 triệu cumulative) — FIN_L2 không tự duyệt phần vượt | [ ] |
| SC-007: Delegate hết hạn | Delegate 14 ngày hết hạn ngày 11/09 | Người được ủy duyệt ngày 12/09 | Từ chối `DELEGATE_INVALID`, lệnh về hàng đợi người ủy | [ ] |
| SC-008: Chi khẩn hậu kiểm trễ | Chi khẩn release 13/09 08:00 | Hết 24h chưa nộp chứng từ | Alert BOD, đánh dấu vi phạm quy trình | [ ] |

> **Liên kết:** SC-001–SC-003, SC-006–SC-008 map REQ-FIN-008; SC-004 map REQ-FIN-006 (điều kiện tiên quyết mọi giải ngân TKQC); SC-005 map REQ-FIN-008 + REQ-BOD-001.

---

## Tài Liệu Kỹ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (disbursement, SoD engine, delegate) | `technical-specs/api-contract.md` |
| Tích hợp (connector VAS nhận lệnh chi, fan-out mobile) | `technical-specs/integration-map.md` |
| Màn hình UI counterpart | `phase4-ux/core-backend/arap-payment/[screen-group].md` |
| Quy tắc nguồn | `phase1-business/departments/finance/finance.md` (A3 REQ-FIN-008, BR-FIN-304), `phase1-business/departments/bod/bod.md` (B0, B1 — BR-BOD-001.1–001.4), `phase1-business/P1-02-business-workflow.md` (SoD 4 vai, bốn trụ cột) |
