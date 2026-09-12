# Tính Năng: Duyệt chi/giải ngân: ngưỡng, SoD, delegate

> **Dựa trên:** REQ-FIN-008 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** Tài chính — Công nợ & Thanh toán (MOD-ARAP-PAYMENT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-ARAP-004 |
| Module | MOD-ARAP-PAYMENT |
| Yêu cầu nghiệp vụ | REQ-FIN-008 — Duyệt chi/giải ngân: ma trận ngưỡng, SoD, delegate (HIGH, Phase2) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 (Phase2) — SoD engine và chặn giải ngân đã có nền từ MVP |
| Phụ thuộc | Không có cross-dependency ngoài module; kế thừa approval engine MVP (REQ-BOD-001) và Hard Stop khớp tiền (REQ-FIN-006) |
| Ghi chú Expert (A7) | Team Expert (finance.md Mục A7) xác nhận SoD engine đặt ở CORE, duyệt là use case trọng tâm của mobile (bản fan-out SYS-MOBILE-INTERNAL); web giữ hồ sơ đầy đủ và các cấu hình — chi tiết tại BR-FIN-304 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng vận hành luồng duyệt chi/giải ngân phân cấp theo giá trị trên web nội bộ cho mọi khoản chi (nạp nền tảng, mua sắm, outsource, tạm ứng): ma trận ngưỡng 5/50/200 triệu VND (quy theo tỷ giá snapshot ngày duyệt), tách vai SoD 4 vai dòng tiền, và cơ chế delegate có kiểm soát khi FIN_L2 vắng mặt. Luồng này là cổng bắt buộc trước khi bất kỳ tiền nào rời khỏi công ty, bảo đảm "duyệt trước, bổ sung sau" không tồn tại và mọi khoản chi đều gắn được mã dự án/khách phục vụ P&L.

**Phạm vi:**
- Bao gồm: form tạo chứng từ chi trên web với kiểm tra đầu vào đầy đủ: chứng từ đính kèm (báo giá, hợp đồng, quote SaaS) upload trước khi gửi duyệt; ≥2 báo giá khi >20 triệu; mã dự án/khách bắt buộc, không gắn được phải chọn overhead kèm lý do.
- Bao gồm: hiển thị luồng duyệt theo ma trận ngưỡng (≤5tr FIN_L2; >5–50tr FIN_L2; >50–200tr FIN_L2 + CFO dual approval; >200tr hoặc hợp đồng năm CFO + CEO) với SLA nhắc duyệt 24/48/72h trên hàng đợi web.
- Bao gồm: màn hình quản lý delegate FIN_L2 (chỉ CFO ủy quyền cho cá nhân cụ thể, hạn mức ≤ FIN_L2, tối đa 14 ngày, tự hết hạn) với log nhãn "theo ủy quyền #id".
- Bao gồm: luồng nạp nền tảng định kỳ — duyệt gộp kế hoạch tuần trước đầu tuần; cảnh báo + duyệt bổ sung khi sắp vượt hạn mức tuần (FIN_L2 ≤50 triệu, CFO >50 triệu).
- Bao gồm: luồng chi khẩn (nền tảng sắp khóa TKQC, khủng hoảng cần outsource ngay) — FIN_L2 + CFO duyệt qua kênh khẩn trong hệ thống, hậu kiểm chứng từ 24h; và chi định kỳ đã cam kết (SaaS năm, retainer) duyệt 1 lần đầu năm, tự giải ngân theo lịch.
- Bao gồm: hiển thị trạng thái Hard Stop khớp tiền trên từng chứng từ liên quan TKQC và trạng thái machine-state của luồng duyệt.
- Không bao gồm: SoD engine, chặn giải ngân thiếu chữ ký/sai ngưỡng — enforcement tại SYS-CORE-BACKEND service layer; web chỉ block UI và hiển thị lỗi business từ core.
- Không bao gồm: bản duyệt mobile (use case trọng tâm của SYS-MOBILE-INTERNAL — push, MFA bắt buộc, nhắc SLA) theo fan-out REQ-FIN-008.
- Không bao gồm: hành giao dịch nạp sau duyệt (thực hiện chi) và ghi sổ — FIN_L1 thực hiện trên luồng riêng; tính năng kết thúc ở trạng thái "đã duyệt, đủ điều kiện giải ngân".

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-BCERP-WEB — web nội bộ responsive; mọi lệnh duyệt ghi kênh (web) và reason code vào audit log bất biến ở core.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L2 | Tạo chứng từ chi có checklist tự động (chứng từ, 2 báo giá nếu >20tr, mã dự án/khách, SoD) trước khi gửi duyệt | Chứng từ đạt chuẩn ngay từ đầu, không bị trả lại vì thiếu hồ sơ |
| 2 | BOD_CFO_CTO | Đồng duyệt dual approval các khoản 50–200 triệu trên web với đầy đủ ngữ cảnh chứng từ và snapshot tỷ giá | Kiểm soát chi lớn theo đúng ma trận mà không phải tra cứu ngoài hệ thống |
| 3 | FIN_L1 | Thực hiện giao dịch con của kế hoạch nạp tuần đã duyệt gộp mà không phải duyệt lại từng lệnh | Vận hành nhanh đầu tuần, vẫn nằm trong hạn mức đã được phê |
| 4 | BOD_CFO_CTO | Ủy quyền delegate cho một cá nhân FIN_L2 cụ thể (hạn mức ≤ FIN_L2, ≤14 ngày, tự hết hạn) khi tôi vắng | Luồng chi không tắc; mọi lệnh delegate duyệt vẫn gắn nhãn "theo ủy quyền #id" |
| 5 | FIN_L2 | Nhận cảnh báo khi kế hoạch nạp tuần sắp vượt hạn mức và tạo duyệt bổ sung đúng cấp (tôi ≤50 triệu, CFO >50 triệu) | Không bao giờ giải ngân vượt phần chưa được phê duyệt |
| 6 | FIN_L1 | Xem trên chứng từ liên quan TKQC trạng thái Hard Stop "đã khớp tiền" do tôi xác nhận (web + MFA TOTP) | Tránh khởi tạo giải ngân cho lệnh chưa khớp tiền, tiết kiệm vòng trả lại |
| 7 | BOD_CFO_CTO | Chạy chi khẩn qua kênh khẩn (duyệt nhanh + hậu kiểm 24h) khi nền tảng sắp khóa TKQC | Cứu chi tiêu của khách đúng thời điểm mà vẫn có bằng chứng hậu kiểm |
| 8 | BOD_CFO_CTO | Duyệt 1 lần đầu năm các chi định kỳ đã cam kết (SaaS năm, retainer) để tự giải ngân theo lịch | Giảm gánh nặng duyệt lặp cho chi đã cam kết hợp đồng |

Toàn bộ luồng tuân theo nguyên tắc: web là mặt làm việc hồ sơ đầy đủ; core là nơi enforce ma trận và SoD; mobile là kênh duyệt nhanh song song (bản fan-out riêng).

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Ma trận ngưỡng và SoD do core enforce; web phải phản ánh đúng và không cung cấp đường tắt.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Ma trận ngưỡng (đã chốt DI-001, mức 5/50/200 triệu VND): ≤5 triệu FIN_L2 duyệt; >5–50 triệu FIN_L2 duyệt; >50–200 triệu FIN_L2 + CFO (dual approval); >200 triệu hoặc hợp đồng năm → CFO + CEO; quy VND theo tỷ giá snapshot ngày duyệt. | Core từ chối route sai; web chặn submit và hiển thị đúng cấp duyệt sẽ nhận |
| BR-002 | SoD 4 vai dòng tiền: đề xuất (người tạo chứng từ) ≠ khớp tiền (FIN_L1) ≠ duyệt chi (FIN_L2/CFO/CEO) ≠ ghi sổ; dual approval cần 2 người; SoD engine block submit khi vai trùng. | Submit bị chặn + vi phạm log cho CFO rà định kỳ; không có cấu hình nào tắt SoD |
| BR-003 | Financial Hard Stop "đã khớp tiền" FIN_L1 (WEB + MFA TOTP) là điều kiện tiên quyết của mọi giải ngân liên quan TKQC — kể cả khi đã đủ chữ ký duyệt; không vai nào bypass kể cả CEO. | Chứng từ đủ chữ ký vẫn giữ "chờ Hard Stop", không thực hiện chi; yêu cầu bỏ qua bị từ chối + audit log bất biến |
| BR-004 | Cấm "duyệt trước, bổ sung sau": chứng từ (báo giá, hợp đồng, quote SaaS) upload trước khi duyệt; chi outsource/tools bắt buộc gắn mã dự án/khách phục vụ P&L, không gắn được phải chọn overhead kèm lý do. | Thiếu hồ sơ: nút Duyệt disabled + core từ chối; chứng từ chi không gắn mã không được gửi duyệt |
| BR-005 | Nạp nền tảng định kỳ: duyệt gộp kế hoạch tuần trước đầu tuần; FIN_L1 thực hiện giao dịch con không duyệt lại; sắp vượt hạn mức tuần → cảnh báo + duyệt bổ sung (FIN_L2 ≤50 triệu / CFO >50 triệu) trước khi giải ngân phần vượt. | Giải ngân vượt hạn mức tuần chưa duyệt bổ sung bị chặn cứng |
| BR-006 | Delegate FIN_L2: chỉ CFO ủy quyền cho cá nhân cụ thể, hạn mức ≤ FIN_L2, tối đa 14 ngày, tự thu hồi khi hết hạn; log mọi lệnh gắn nhãn "theo ủy quyền #id"; kiêm nhiệm CFO kiêm CTO → giao dịch vượt ngưỡng cao nhất do CEO duyệt. | Lệnh duyệt ngoài hạn mức/hạn thời gian delegate bị từ chối; cấu hình delegate không hợp lệ bị chặn |
| BR-007 | Nhắc duyệt SLA 24h/48h/72h theo ngưỡng; quá hạn escalate lên cấp trên và phát alert đỏ; chi khẩn duyệt qua kênh khẩn trong hệ thống, hậu kiểm chứng từ 24h — tồn hậu kiểm bật alert. | Khoản quá SLA nhảy lên đầu hàng đợi + alert; hậu kiểm trễ báo BOD theo REQ-BOD-006 |
| BR-008 | Chi định kỳ đã cam kết (SaaS năm, retainer): duyệt 1 lần đầu năm, tự giải ngân theo lịch; lịch giải ngân hiển thị công khai cho FIN; thay đổi giá trị/hủy cam kết cần duyệt lại theo ngưỡng tương ứng. | Tự thay đổi lịch/giá trị sau duyệt bị chặn; phải tạo chứng từ duyệt lại |
| BR-009 | Công nợ AR/AP + aging + nhắc nợ: chứng từ thanh toán AP gắn hóa đơn trong aging (REQ-FIN-007); thanh toán làm giảm dư nợ chỉ khi khớp tiền thực tế; aging phản ánh ngay sau giải ngân. | Thanh toán cho hóa đơn tranh chấp không map được bị trả về ticket; aging lệch với thực chi là lỗi dữ liệu P1 |
| BR-010 | Hóa đơn điện tử TT78/2021 + NĐ123/2020: chứng từ chi liên quan doanh thu phải đối ứng HĐĐT từ chứng từ đã khóa kỳ; phí nền tảng & nghĩa vụ thuế hạch toán vào giá vốn theo giao dịch gốc, tách khỏi doanh thu dịch vụ. | Chứng từ chi không đối ứng được hóa đơn/hồ sơ phí tạo discrepancy bắt buộc giải trình |
| BR-011 | Connector phần mềm kế toán VAS: cấu hình kết nối ngoại vi trong Settings (MOD-SETTINGS-GW, DI-004 ngày 12/09) — vendor-agnostic, import/export chuẩn + adapter API; chỉ bút toán từ chứng từ đã duyệt mới xuất về VAS; legacy PMS migrate chọn lọc (master data + dự án active + payment history 12 tháng) + legacy read-only. | Chứng từ nháp/chưa duyệt không được đồng bộ; dữ liệu sau cutoff không ghi ngược legacy |
| BR-012 | Mọi hành vi tạo/duyệt/từ chối/delegate/chi khẩn ghi audit log kèm reason code bắt buộc và kênh thao tác; người thử việc/freelancer không có quyền duyệt; MFA bắt buộc cho vai duyệt (theo nền tảng REQ-BOD-011). | Hành động thiếu reason code bị từ chối ở API; log thiếu vết coi như sự cố P1 |

---

## 4. Phân Quyền

Quyền do RBAC engine của core kiểm tra tại API; bảng dưới là hợp đồng UI web nội bộ. Chỉ dùng 18 vai registry.

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | BOD_CEO | SYS_ADMIN |
|-----------|--------|--------|-------------|---------|-----------|
| Tạo chứng từ chi | ✅ (giao dịch con kế hoạch tuần) | ✅ | ✅ (đề xuất — CEO duyệt) | ❌ | ❌ |
| Upload chứng từ/báo giá | ✅ | ✅ | ✅ | ❌ | ❌ |
| Duyệt ≤5tr / >5–50tr | ❌ | ✅ | ❌ (không nhánh) | ❌ | ❌ |
| Chữ ký thứ nhất 50–200tr | ❌ | ✅ | ❌ | ❌ | ❌ |
| Dual approval 50–200tr | ❌ | ❌ | ✅ | ❌ | ❌ |
| Duyệt >200tr / hợp đồng năm | ❌ | ❌ | ✅ (đồng duyệt) | ✅ (bắt buộc) | ❌ |
| Duyệt chi khẩn (kênh khẩn) | ❌ | ✅ | ✅ | ❌ | ❌ |
| Duyệt bổ sung hạn mức tuần | ❌ | ✅ (≤50tr) | ✅ (>50tr) | ❌ | ❌ |
| Cấu hình delegate FIN_L2 | ❌ | ❌ | ✅ | ❌ | ❌ |
| Thực hiện chi sau duyệt | ✅ (≠ người duyệt) | ❌ | ❌ | ❌ | ❌ |
| Sửa/xóa chứng từ đã duyệt | ❌ (chỉ reversal) | ❌ (chỉ reversal) | ❌ (duyệt reversal) | ❌ | ❌ |

SYS_ADMIN không duyệt/sửa lệnh chi — chỉ thực thi cấu hình sau phê duyệt của BOD. Người dùng kiêm nhiều vai không được đứng ở 2 vị trí SoD khác nhau trên cùng một chứng từ; core phát hiện và tách xung đột theo luồng.

---

## 5. Trường Hợp Đặc Biệt

- Khoản chi ngoại tệ (nạp nền tảng USD): giá trị quy VND theo snapshot tỷ giá ngày duyệt để xác định ngưỡng; snapshot lưu bất biến trên chứng từ — chênh tỷ giá sau đó không đổi cấp duyệt của chứng từ đã duyệt.
- Người duyệt duy nhất khả dụng đang vắng (FIN_L2 vắng, chưa kịp delegate): theo B0.2, hai BOD duyệt từ xa qua mobile; nếu không khả thi, lệnh treo có cảnh báo — hệ thống không hạ ngưỡng cho người không đủ hạn mức "tạm duyệt hộ".
- Chi khẩn quá 4h không có người duyệt: tự escalate + alert đỏ cho CFO/CEO; khi được duyệt muộn, chứng từ ghi nhận cả thời điểm đề nghị, thời điểm duyệt và lý do trễ phục vụ hậu kiểm.
- Hậu kiểm 24h phát hiện chứng từ khẩn thiếu/sai: trạng thái hậu kiểm "thất bại" bật alert cho CFO, chứng từ gốc giữ nguyên, xử lý bằng reversal/reject có reason code; không sửa đè hồ sơ khẩn.
- Kế hoạch nạp tuần được duyệt nhưng giữa tuần khách yêu cầu tăng đột biến: FIN_L2 tạo duyệt bổ sung đúng cấp; phần vượt chỉ giải ngân sau khi duyệt bổ sung có hiệu lực — không "giải ngân trước, trình sau".
- Chứng từ gắn overhead: bắt buộc chọn danh mục overhead + lý do; báo cáo P&L hiển thị riêng khối overhead để CFO rà tỷ lệ chi không gắn dự án; lạm dụng overhead là chỉ số theo dõi trong review định kỳ.
- Người được delegate đồng thời là người tạo chứng từ: SoD chặn — delegate chỉ duyệt chứng từ do người khác tạo; core kiểm tra chuỗi vai toàn luồng trước khi accept chữ ký.
- Dual approval có một chữ ký rút lại trước khi đủ: chứng từ quay về trạng thái chờ; chữ ký đã ký không "rút ngầm" sau khi luồng hoàn tất — chỉ hủy bằng reversal có duyệt.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Chứng từ chi/giải ngân (Disbursement Voucher) — áp dụng chung cho chi thường, chi khẩn, chi định kỳ đã cam kết và duyệt bổ sung hạn mức tuần.

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit đủ hồ sơ)──► [PENDING_APPROVAL] ──(≤50tr: FIN_L2 duyệt)──► [APPROVED] ──(Hard Stop OK)──► [READY_TO_PAY]
                    │                        │                                            │
                    │                        └─(50–200tr)──► [DUAL_PENDING] ──(CFO)───────┤
                    │                        └─(>200tr/HĐ năm)──► [CEO_PENDING] ──────────┤
                    │ (quá SLA)                              ▼                            ▼
                    ▼                                   [ESCALATED]                 [READY_TO_PAY] ──(thực hiện chi)──► [PAID] ──(hậu kiểm 24h)──► [CLOSED]
                [ESCALATED]
[PENDING_*/ESCALATED] ──(reject + reason)──► [REJECTED]      [DRAFT] ──(hủy)──► [CANCELLED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `PENDING_APPROVAL` | Người tạo | Đủ chứng từ + 2 báo giá nếu >20tr + mã dự án/khách (hoặc overhead + lý do); SoD hợp lệ |
| `PENDING_APPROVAL` | Approve | `APPROVED` | FIN_L2 | Giá trị ≤50tr; đúng cấp duyệt |
| `PENDING_APPROVAL` | Approve | `DUAL_PENDING` | FIN_L2 | Giá trị >50–200tr |
| `DUAL_PENDING` | Dual approve | `APPROVED` | BOD_CFO_CTO | Đủ 2 chữ ký khác người |
| `DUAL_PENDING` | Chuyển nhánh | `CEO_PENDING` | BOD_CFO_CTO | Giá trị >200tr hoặc hợp đồng năm |
| `CEO_PENDING` | Approve | `APPROVED` | BOD_CEO | Bắt buộc nhánh CFO + CEO |
| `PENDING_*` | Escalate (tự động) | `ESCALATED` | Hệ thống | Quá SLA 24/48/72h |
| `APPROVED` | Kiểm Hard Stop | `READY_TO_PAY` | Hệ thống | Khớp tiền FIN_L1 xác nhận (nếu liên quan TKQC) |
| `READY_TO_PAY` | Thực hiện chi | `PAID` | FIN_L1 (≠ người duyệt) | Đúng beneficiary; chi khẩn đặt lịch hậu kiểm 24h |
| `PAID` | Hậu kiểm xong | `CLOSED` | Hệ thống/CFO | Hậu kiểm 24h pass; alert nếu fail |
| `PENDING_*` | Reject | `REJECTED` | Người đúng cấp | Reason code bắt buộc |

**Quy tắc:**
- `CLOSED`, `REJECTED`, `CANCELLED` là trạng thái kết thúc; sửa số liệu sau duyệt chỉ qua reversal có duyệt CFO.
- Chi định kỳ đã cam kết: mỗi lần tự giải ngân tạo instance `READY_TO_PAY → PAID → CLOSED` riêng tham chiếu chứng từ duyệt năm gốc.
- Web không tự chuyển trạng thái — mọi chuyển đổi do core xác nhận; hiển thị đếm ngược SLA từ dữ liệu core.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| DisbursementVoucher | `id`, `type` (thường/khẩn/định kỳ/bổ sung), `amount`, `currency`, `fx_snapshot`, `project_code`/`overhead_reason`, `status` | FK → người tạo, attachments | SoD chain do core kiểm |
| ApprovalStep | `voucher_id`, `level`, `approver_id`, `delegate_of`, `decision`, `reason_code` | FK → voucher | Dual = 2 step; nhãn "theo ủy quyền #id" |
| WeeklyTopupPlan | `week`, `planned_amount`, `approved_by`, `supplement_amount` | FK → vouchers | Duyệt gộp trước đầu tuần |
| DelegateGrant | `grantor_id`, `grantee_id`, `max_amount`, `valid_from`, `valid_to` | FK → users | ≤14 ngày, tự hết hạn |
| PostAuditRecord | `voucher_id`, `checked_at`, `result`, `alert_id` | FK → voucher | Riêng chi khẩn, 24h |
| AR/AP Invoice (tham chiếu) | `id`, `due_date`, `status` | FK → voucher thanh toán | Aging REQ-FIN-007 |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn SoD khi tạo | Người tạo chính là FIN_L2 duyệt trên cùng chứng từ | Submit | Core block + log vi phạm; hiển thị lỗi vai trùng | [ ] |
| SC-002: Dual approval đúng cấp | Chứng từ 150 triệu, FIN_L2 đã ký | CFO đồng duyệt | `APPROVED`; 2 step khác người; snapshot tỷ giá lưu | [ ] |
| SC-003: Hard Stop giữ lệnh | Chứng từ nạp TKQC đủ chữ ký, chưa khớp tiền | Kiểm tra trước chi | Giữ `APPROVED`, không `READY_TO_PAY` đến khi FIN_L1 xác nhận khớp tiền | [ ] |
| SC-004: Delegate theo nhãn | CFO ủy quyền FIN_L2 cá nhân A, 10 ngày | A duyệt khoản 40 triệu | Được duyệt; audit log ghi "theo ủy quyền #id" | [ ] |
| SC-005: Vượt hạn mức tuần | Kế hoạch tuần sắp vượt, cần thêm 60 triệu | FIN_L2 tạo duyệt bổ sung | Core route cho CFO (>50tr); phần vượt chờ duyệt bổ sung mới giải ngân | [ ] |
| SC-006: Chi khẩn hậu kiểm | Chi khẩn duyệt 15:00, chi 15:10 | Hậu kiểm 24h phát hiện thiếu chứng từ | Hậu kiểm fail → alert CFO; không sửa đè, xử lý reversal | [ ] |
| SC-007: Định kỳ tự giải ngân | SaaS năm duyệt đầu năm | Đến lịch hàng tháng | Tự tạo instance giải ngân tham chiếu duyệt gốc, không cần duyệt lại | [ ] |

> **Liên kết:** SC-001…SC-007 map về REQ-FIN-008 (Mục 2 — ma trận ngưỡng, SoD, delegate, chi khẩn, nạp định kỳ).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/arap-payment/disbursement-approval.md` |
| Bản fan-out counterpart | `phase2-features/core-backend/arap-payment/` (SoD engine), `phase2-features/mobile-internal/arap-payment/` (duyệt mobile) |
