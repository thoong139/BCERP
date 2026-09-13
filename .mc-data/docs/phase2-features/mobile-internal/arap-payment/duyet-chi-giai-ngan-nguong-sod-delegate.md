# Tính Năng: Duyệt chi/giải ngân — ngưỡng, SoD, delegate (Mobile Nội Bộ)

> **Dựa trên:** REQ-FIN-008 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** Mobile Nội Bộ BCERP (SYS-MOBILE-INTERNAL)
> **Module:** Công nợ AR/AP & Giải ngân (MOD-ARAP-PAYMENT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-internal/arap-payment/[screen-group].md`, `phase5-implementation/tasks/mobile-internal/arap-payment/FEAT-MBI-ARAP-002-impl.md`

> **Hướng dẫn ID:** FEAT-ID khai báo trong registry lane của `/wf-define-features`: REQ-FIN-008 (hệ thống đích SYS-MOBILE-INTERNAL) → FEAT-MBI-ARAP-002. REQ fan-out ở 3 hệ thống; bản WEB (hồ sơ đầy đủ) và bản CORE (SoD engine, ledger) là counterpart. Mobile là kênh duyệt giải ngân trọng tâm của DEPT-FINANCE.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-ARAP-002 |
| Module | MOD-ARAP-PAYMENT — Công nợ AR/AP & Giải ngân |
| Yêu cầu nghiệp vụ | REQ-FIN-008 (Duyệt chi/giải ngân: ngưỡng, SoD, delegate); phối hợp REQ-FIN-006/007 (Hard Stop, AR/AP) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO (BOD_CEO tham gia nhánh >200 triệu và duyệt thay khi CFO là người đề xuất) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 (Phase2) |
| Phụ thuộc | SoD engine + ledger tại SYS-CORE-BACKEND (cross-dependencies: không có FEAT chéo lane); hạ tầng push/MFA dùng chung FEAT-MBI-ARAP-001; RBAC/SSO/MFA (REQ-BOD-011) |
| Ghi chú Expert (A7) | Mục A7 của `finance.md` chưa có kết quả đánh giá Expert tại thời điểm viết spec (bảng A7 trống chờ finance-expert review) — cập nhật khi có điều chỉnh, chi tiết tại `finance.md` Mục A7 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa toàn bộ chuỗi duyệt chi/giải ngân (nạp nền tảng, mua sắm, outsource, tạm ứng) lên kênh di động nội bộ — use case trọng tâm của SYS-MOBILE-INTERNAL theo REQ-FIN-008 — để FIN_L2 và BOD_CFO_CTO duyệt phân cấp theo giá trị ngay khi di chuyển, với MFA bắt buộc, nhắc SLA 24/48/72 giờ và SoD engine ép tách vai ở tầng CORE. Tính năng bảo đảm không khoản chi nào giải ngân sai ngưỡng, thiếu chữ ký, thiếu chứng từ hay vi phạm tách bạch vai.

**Phạm vi:**
- Bao gồm:
  - Hàng đợi lệnh chi dạng tóm tắt trên mobile (React Native, offline-capable): số tiền quy VND theo tỷ giá snapshot ngày duyệt, nhánh ngưỡng, trạng thái chữ ký, SLA đếm ngược.
  - Duyệt/từ chối kèm reason code với MFA TOTP; dual approval >50–200 triệu; ngữ cảnh aging AR/AP và hạn AP nền tảng.
  - Duyệt gộp kế hoạch nạp tuần trước đầu tuần; cảnh báo + duyệt bổ sung khi sắp vượt hạn mức; FIN_L1 thực hiện giao dịch con không duyệt lại.
  - Delegate FIN_L2 do CFO ủy (hạn mức ≤ FIN_L2, ≤14 ngày, tự thu hồi); chi khẩn FIN_L2 + CFO hậu kiểm 24h; chi định kỳ đã cam kết duyệt một lần đầu năm.
  - Bút toán sau duyệt đồng bộ về phần mềm kế toán VAS qua connector cấu hình tại Settings; theo dõi trạng thái đến ghi sổ.
  - Xem offline read-only; mọi lệnh duyệt chỉ thực thi online.
- Không bao gồm:
  - Tạo lệnh chi, upload chứng từ, màn đối chiếu sổ VAS — thuộc SYS-BCERP-WEB.
  - Enforcement ngưỡng, SoD engine, snapshot tỷ giá, chặn thiếu chữ ký — thuộc SYS-CORE-BACKEND.
  - Xác nhận "Đã khớp tiền" Hard Stop — chỉ WEB với MFA (REQ-FIN-006); mobile chỉ alert/xem.
  - Xuất HĐĐT (REQ-FIN-011) và tính nghĩa vụ thuế (REQ-FIN-014) — feature riêng; mobile chỉ xem trạng thái sau duyệt.
  - Chấm công/timesheet (module CAPACITY-TIMESHEET); dashboard tài chính đầy đủ (REQ-FIN-015).
---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L2 | Duyệt khoản ≤50 triệu trên điện thoại với MFA, kèm cảnh báo nếu vai trùng vai tạo chứng từ | Không dồn duyệt cuối ngày; tự chặn xung đột vai |
| 2 | FIN_L2 | Xem aging AR/AP và hạn AP nền tảng ngay trên màn tóm tắt | Ước lượng áp lực dòng tiền trước khi ký |
| 3 | BOD_CFO_CTO | Nhận push nhắc SLA 24/48/72 giờ và đồng duyệt >50–200 triệu trên mobile | Dual approval không chậm khi tôi vắng văn phòng |
| 4 | BOD_CFO_CTO | Ủy quyền duyệt của FIN_L2 cho một nhân sự khi tôi vắng ≤14 ngày | Luồng ≤50 triệu không tắc; hạn mức ủy ≤ FIN_L2 |
| 5 | FIN_L1 | Nhận alert trạng thái khớp tiền và thực hiện giao dịch con theo kế hoạch tuần đã duyệt | Biết khoản nào đủ điều kiện chi |
| 6 | BOD_CFO_CTO | Duyệt gộp kế hoạch nạp tuần trên mobile trước đầu tuần | Nạp định kỳ cả tuần không duyệt từng giao dịch |
| 7 | BOD_CFO_CTO | Nhận cảnh báo "sắp vượt hạn mức tuần" kèm duyệt bổ sung (tôi duyệt phần >50 triệu) | Không giao dịch con nào treo giữa tuần |
| 8 | BOD_CFO_CTO | Rà danh sách vi phạm SoD được log định kỳ trên mobile | Giám sát tách vai dòng tiền không cần mở web |
| 9 | FIN_L2 | Duyệt chi khẩn FIN_L2 + CFO qua kênh khẩn trong 4 giờ | Nền tảng sắp khóa TKQC được xử lý kịp, hậu kiểm 24h vẫn bảo đảm |

---
## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-201 | Ma trận ngưỡng (5/50/200 triệu chốt theo DI-001, 12/09; quy VND theo tỷ giá snapshot ngày duyệt): ≤5 triệu → FIN_L2; >5–50 triệu → FIN_L2; >50–200 triệu → FIN_L2 + BOD_CFO_CTO (dual); >200 triệu/hợp đồng năm → BOD_CFO_CTO + BOD_CEO. CFO là người đề xuất khoản vượt ngưỡng cao nhất → CEO duyệt thay (compensating control kiêm nhiệm CFO/CTO) | CORE chặn giải ngân khi thiếu/sai chữ ký; mobile hiển thị nhánh ngưỡng và người duyệt bắt buộc |
| BR-202 | SoD engine (tầng CORE): người tạo ≠ người duyệt ≠ người thực hiện chi (2 người thường, 3 người dual approval); người đối soát ≠ người duyệt điều chỉnh; SoD 4 vai dòng tiền: đề xuất ≠ khớp tiền ≠ duyệt chi ≠ ghi sổ | Block submit khi vai trùng + log vi phạm cho CFO rà định kỳ; mobile ẩn nút duyệt cho vai xung đột |
| BR-203 | Chứng từ (báo giá, hợp đồng, quote SaaS) upload trước khi duyệt — cấm "duyệt trước, bổ sung sau"; chi outsource/tools bắt buộc gắn mã dự án/khách phục vụ P&L, không gắn được phải chọn overhead kèm lý do | Lệnh thiếu chứng từ/mã không vào hàng đợi; nút Duyệt disabled kèm mục thiếu |
| BR-204 | Nạp nền tảng định kỳ: duyệt gộp kế hoạch tuần trước đầu tuần; FIN_L1 thực hiện giao dịch con trong hạn mức không duyệt lại; sắp vượt hạn mức tuần → cảnh báo + duyệt bổ sung (FIN_L2 phần ≤50 triệu, CFO phần >50 triệu) trước khi giải ngân tiếp | Giao dịch con vượt hạn mức bị chặn; mobile push cảnh báo kèm số tiền đề nghị bổ sung |
| BR-205 | Chi khẩn (nền tảng sắp khóa TKQC, khủng hoảng cần outsource ngay): FIN_L2 + CFO duyệt qua kênh khẩn trong hệ thống, hậu kiểm 24h; khẩn rút ngắn SLA nhưng không bỏ duyệt, không bỏ Hard Stop | Quá 24h chưa hậu kiểm → alert đỏ; khoản đánh dấu riêng đến khi đóng hậu kiểm |
| BR-206 | Chi định kỳ đã cam kết (SaaS năm, retainer): duyệt một lần đầu năm theo nhánh ngưỡng giá trị năm, tự giải ngân theo lịch | Lịch tự giải ngân vượt giá trị/định mức đã duyệt → chặn, yêu cầu duyệt bổ sung như BR-204 |
| BR-207 | Delegate FIN_L2: chỉ CFO ủy quyền cho cá nhân cụ thể, hạn mức ≤ FIN_L2, tối đa 14 ngày, tự thu hồi khi hết hạn; lệnh theo ủy quyền log nhãn "theo ủy quyền #id" | Delegate hết hạn tự vô hiệu; lệnh vượt hạn mức ủy bị chặn; vai khác không được ủy quyền duyệt |
| BR-208 | Nhắc duyệt SLA 24/48/72 giờ theo nhánh ngưỡng; quá SLA escalate lên cấp duyệt trên (mốc escalate chi tiết cấu hình theo chính sách hạn mức chi — đang dùng mặc định đề xuất expert, chốt khi BOD duyệt chính sách; assumption ngoài nhóm KXN đang mở) | Khoản quá hạn tự đẩy lên hàng đợi cấp trên mobile + web; log escalation có timestamp |
| BR-209 | Financial Hard Stop: mọi giải ngân liên quan TKQC điều kiện tiên quyết là lệnh nạp tương ứng đã được FIN_L1 xác nhận "Đã khớp tiền" (chỉ WEB + MFA; MOBILE chỉ alert/xem — REQ-FIN-006); chặn cứng trong code, không vai nào override kể cả CEO/Super Admin | Thiếu khớp tiền → CORE từ chối chuyển sang chi; mobile hiển thị "chờ khớp tiền" |
| BR-210 | Công nợ AR/AP + aging + nhắc nợ (REQ-FIN-007): aging bucket 0–30/31–60/61–90/>90 ngày; hàng đợi duyệt hiển thị aging + lịch sử nhắc nợ của khách liên quan; nhắc tự động AR quá hạn theo lịch cấu hình; AR >90 ngày là căn cứ clawback hoa hồng 100%; chính sách PAUSE TK khi non-payment (đề xuất 2 bậc 15/30 ngày) chờ khách hàng xác nhận `[KXN-22]` | Thiếu dữ liệu aging (lỗi nguồn) → khoản vẫn duyệt được nhưng gắn cảnh báo dữ liệu; không tự chặn chi AP vì rủi ro gián đoạn TKQC |
| BR-211 | Bút toán lệnh chi đã duyệt đồng bộ phần mềm kế toán VAS qua connector cấu hình tại Settings — MOD-SETTINGS-GW (DI-004 12/09): vendor-agnostic (connection profile + field mapping + import/export chuẩn schema + adapter API cắm được); chỉ xuất từ chứng từ đã duyệt/khóa kỳ. Legacy PMS migrate chọn lọc (master data + dự án active + payment history 12 tháng), phần còn lại legacy read-only | Connector fail → hàng chờ retry + alert, không ghi sổ tay đè luồng chuẩn; bản nháp không bao giờ xuất |
| BR-212 | Lệnh chi đã duyệt là căn cứ hạch toán phí nền tảng và nghĩa vụ thuế (REQ-FIN-014 — dữ liệu phí từ statement/API); HĐĐT theo TT78/2021 + NĐ123/2020 chỉ phát hành trên doanh thu dịch vụ từ chứng từ đã khóa kỳ, không xuất cho dòng tiền giữ hộ (REQ-FIN-011) | Chứng từ chưa khóa kỳ bị chặn phát hành HĐĐT |
| BR-213 | Mobile: MFA TOTP bắt buộc mọi lệnh duyệt; offline chỉ xem (read-only cache); thiết bị qua MDM; mọi thao tác ghi audit log bất biến kèm kênh và reason code khi từ chối | Thiết bị ngoài MDM/chưa MFA → chặn kênh duyệt; thiếu reason code → từ chối thao tác |

---

## 4. Phân Quyền

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | BOD_CEO | SYS_ADMIN |
|-----------|--------|--------|-------------|---------|-----------|
| Xem hàng đợi/lệnh chi trên mobile | ✅ (alert + trạng thái) | ✅ | ✅ | ✅ (nhánh của mình) | ❌ |
| Tạo đề nghị chi | ✅ (giao dịch con kế hoạch tuần) | ✅ | ✅ | ❌ | ❌ |
| Duyệt ≤50 triệu | ❌ | ✅ | ❌ | ✅ (mọi ngưỡng khi cần) | ❌ |
| Đồng duyệt (dual) >50–200 triệu | ❌ | ✅ (chữ ký cấp một) | ✅ (chữ ký hai) | ✅ | ❌ |
| Duyệt >200 triệu / hợp đồng năm | ❌ | ❌ | ✅ | ✅ (bắt buộc) | ❌ |
| Duyệt thay khi CFO là người đề xuất | ❌ | ❌ | ❌ (cấm tự duyệt) | ✅ | ❌ |
| Duyệt chi khẩn kênh khẩn | ❌ | ✅ | ✅ | ✅ | ❌ |
| Gán delegate cho FIN_L2 | ❌ | ❌ (đối tượng được ủy) | ✅ | ❌ | ❌ |
| Xác nhận "Đã khớp tiền" (Hard Stop) | ✅ — chỉ WEB + MFA | ❌ | ❌ | ❌ | ❌ |
| Thực hiện chi sau duyệt | ✅ | ❌ | ❌ | ❌ | ❌ |
| Xem log vi phạm SoD | ❌ | ❌ | ✅ | ✅ | ❌ |
| Sửa/xóa lệnh chi đã duyệt | ❌ | ❌ | ❌ | ❌ | ❌ |

> Ghi chú: bảng phản ánh RACI hiện hành của bước B8 "Duyệt chi" trong `finance.md`/`bod.md` (A ngưỡng cao = BOD); RACI gốc chờ xác nhận chính thức `[KXN-19]` — rà lại khi KXN-19 đóng.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- Lệnh chi ngoại tệ (nạp nền tảng USD): so ngưỡng theo quy VND tỷ giá snapshot ngày duyệt; tỷ giá biến động thì ngưỡng áp dụng theo mốc ngày duyệt.
- Người đề nghị chi chính là FIN_L2/CFO nắm vai duyệt: SoD engine tự khóa nhánh duyệt của người đó và log vi phạm tiềm ẩn; khoản phải qua người duyệt khác (CFO đề xuất → CEO duyệt thay).
- FIN_L2 vắng khi kế hoạch tuần đến hạn: CFO dùng delegate hoặc duyệt trực tiếp phần ≤50 triệu; phần >50 triệu vẫn phải CFO/CEO — delegate không nâng hạn mức.
- Chi khẩn khi FIN_L2/CFO đang offline: kênh khẩn vẫn yêu cầu online + MFA; lệnh chờ trong app, xử lý ngay khi có kết nối — không có kênh ngoài hệ thống được công nhận.
- AP nền tảng đến hạn trong khi AR liên quan chưa thu: aging cảnh báo hai chiều; quyết định vẫn theo luồng duyệt chuẩn, không tự dừng nạp vì rủi ro gián đoạn TKQC.
- Mã dự án bị đóng/khóa kỳ giữa chừng: chọn lại mã dự án active hoặc chuyển overhead kèm lý do trước khi duyệt.
- Connector VAS gián đoạn vào kỳ chốt: lệnh đã duyệt xếp hàng retry có timestamp; FIN_L2 theo dõi trên mobile, không ghi sổ tay thay thế.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Entity chính là Lệnh chi/giải ngân; CORE hợp lệ hóa mọi chuyển trạng thái, mobile là kênh gửi lệnh duyệt.*

**Entity:** Lệnh chi/giải ngân (payment_order)

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit, WEB)──► [PENDING_DUYET] ──(duyệt ≤50tr)──► [APPROVED]
                              │    │                             │
                              │    └─(cấp 1, >50tr)─► [CHO_CHU_KY_2]
                              │                            │
                              │(từ chối)         (từ chối)│      ├─(chi, TKQC: qua Hard Stop)─► [DISBURSED]
                              ▼                            ▼      │
                         [TU_CHOI]                    [TU_CHOI]   ├─(chi định kỳ theo lịch)─► [DISBURSED]
                                                                  ▼
                                                            [DANG_DOI_SOAT] ──(đối trừ + sync VAS đạt)──► [HOAN_TAT]
[APPROVED, chi khẩn] ──(hậu kiểm 24h)──► [HAU_KIEM] ──(đạt)──► [HOAN_TAT]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `PENDING_DUYET` | Người đề nghị (WEB) | Đủ chứng từ, mã dự án/khách hoặc overhead + lý do, SoD tạo ≠ duyệt (BR-203) |
| `PENDING_DUYET` | Duyệt (nhánh 1 chữ ký ≤50 triệu) | `APPROVED` | FIN_L2 (hoặc delegate hợp lệ) | MFA; đúng vai; SLA 24h nhắc |
| `PENDING_DUYET` | Duyệt cấp một (>50–200 triệu) | `CHO_CHU_KY_2` | FIN_L2 | Không trùng người tạo; SLA 48h |
| `CHO_CHU_KY_2` | Chữ ký hai | `APPROVED` | BOD_CFO_CTO (>50–200 triệu) hoặc BOD_CEO (>200 triệu/hợp đồng năm) | Đủ 2 chữ ký khác nhau; CFO đề xuất thì chỉ CEO |
| `PENDING_DUYET` / `CHO_CHU_KY_2` | Từ chối | `TU_CHOI` | Người duyệt đúng vai | Bắt buộc reason code |
| `APPROVED` | Thực hiện chi | `DISBURSED` | FIN_L1 / hệ thống (lịch chi định kỳ) | Khoản TKQC: lệnh nạp tương ứng "Đã khớp tiền" (BR-209); trong hạn mức tuần đã duyệt |
| `APPROVED` (chi khẩn) | Mở hậu kiểm | `HAU_KIEM` | Hệ thống | Hậu kiểm 24h; tồn quá hạn bật alert (BR-205) |
| `DISBURSED` | Đối trừ 3 số + sync VAS | `DANG_DOI_SOAT` → `HOAN_TAT` | Hệ thống | Dung sai đối soát theo cấu hình; sync connector VAS đạt (BR-211) |
| `PENDING_DUYET` / `CHO_CHU_KY_2` | Hủy bởi người đề nghị | `DA_HUY` | Người đề nghị | Chưa có chữ ký nào; đã có → luồng từ chối |

**Quy tắc:**
- Không quay về trạng thái trước; lệnh bị từ chối tạo lại bằng lệnh mới.
- `HOAN_TAT`, `TU_CHOI`, `DA_HUY` là trạng thái kết thúc — không chuyển tiếp.
- Mọi chuyển trạng thái ghi audit log bất biến kèm kênh (WEB/MOBILE); chi định kỳ tự động ghi đích danh kế hoạch đã duyệt làm căn cứ.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `payment_order` | `id`, `type` (nạp nền tảng/mua sắm/outsource/tạm ứng), `amount`, `currency`, `fx_snapshot`, `project_code`, `customer_id`, `status`, `sla_deadline` | FK → `projects`, `customers` | Bắt buộc `project_code` hoặc `overhead_reason` |
| `payment_approval_step` | `order_id`, `step_no`, `required_role`, `approver_id`, `delegate_ref`, `decision`, `reason_code`, `channel` | FK → `payment_order.id` | Dual approval = 2 dòng; nhãn "theo ủy quyền #id" |
| `weekly_topup_plan` | `week_no`, `total_limit`, `approved_by`, `status`, `consumed_amount` | FK → `payment_order.id` (giao dịch con) | Duyệt gộp đầu tuần; cảnh báo sắp vượt hạn mức |
| `arap_ledger_entry` | `party_type` (AR/AP), `party_id`, `due_date`, `aging_bucket`, `reminder_history` | FK → `payment_order.id` (bên AP) | Aging 4 bucket; nguồn clawback AR >90 ngày |
| `vas_sync_queue` | `order_id`, `payload`, `status` (pending/retry/synced), `attempt_count`, `last_error` | FK → `payment_order.id` | Chỉ nhận lệnh đã duyệt/khóa kỳ; retry + alert khi fail |
| `audit_log` | `actor_id`, `entity`, `entity_id`, `action`, `reason_code`, `channel`, `timestamp` | Polymorphic | Append-only, WORM ≥10 năm (REQ-FIN-012) |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — có thể test được.*
> **Ghi chú:** Chi tiết điền ở Phase 5; Phase 2 ghi phác thảo sơ bộ.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Duyệt 30 triệu trên mobile với MFA | Lệnh 30 triệu `PENDING_DUYET`, FIN_L2 trên thiết bị MDM | FIN_L2 xác thực MFA và bấm Duyệt | `APPROVED`; audit log ghi kênh MOBILE; push xác nhận | [ ] |
| SC-002: Block vai trùng (SoD) | FIN_L2 vừa tạo lệnh 20 triệu | FIN_L2 mở lệnh do chính mình tạo để duyệt | Nút Duyệt disabled kèm cảnh báo SoD; vi phạm log cho CFO | [ ] |
| SC-003: Dual approval đủ 2 chữ ký | Lệnh 120 triệu `CHO_CHU_KY_2` sau chữ ký FIN_L2 | CFO duyệt trên mobile với MFA | `APPROVED`; 2 dòng `payment_approval_step` của 2 người khác nhau | [ ] |
| SC-004: Chặn giải ngân khi chưa khớp tiền | Lệnh nạp TKQC `APPROVED` nhưng lệnh nạp tương ứng chưa được FIN_L1 xác nhận khớp tiền | Hệ thống/nhân viên thực hiện chi | Chặn cứng; nhãn "chờ khớp tiền"; không có nút override | [ ] |
| SC-005: Delegate hết hạn tự thu hồi | Delegate FIN_L2 của CFO hết hạn 14 ngày | Người được ủy duyệt sau thời điểm hết hạn | Từ chối vai delegate; lệnh quay về hàng đợi CFO | [ ] |
| SC-006: Duyệt bổ sung khi sắp vượt hạn mức tuần | `weekly_topup_plan` đã tiêu thụ 90% hạn mức | Giao dịch con sắp vượt hạn mức | Push cảnh báo tới người duyệt kế hoạch; giao dịch vượt bị chặn đến khi duyệt bổ sung | [ ] |
| SC-007: Chi khẩn hậu kiểm 24h | Chi khẩn đã `APPROVED` qua kênh khẩn | 24 giờ trôi qua không hậu kiểm | Alert đỏ phát; khoản đánh dấu "tồn hậu kiểm" | [ ] |

> **Liên kết:** SC-001/SC-003 map REQ-FIN-008 (duyệt mobile, dual approval); SC-002/SC-005/SC-006/SC-007 map REQ-FIN-008 (SoD, delegate, hạn mức, chi khẩn); SC-004 map REQ-FIN-006/008 (Hard Stop).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (mobile — payment queue, duyệt, offline sync, push SLA) | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (SoD engine CORE, connector VAS qua MOD-SETTINGS-GW, Hard Stop REQ-FIN-006) | `technical-specs/integration-map.md` |
| Màn hình UI (mobile — hàng đợi lệnh chi, dual approval, aging context) | `phase4-ux/mobile-internal/arap-payment/payment-approval.md` |
| Feature counterpart cùng REQ (WEB, CORE) | `phase2-features/bcerp-web/arap-payment/`, `phase2-features/core-backend/arap-payment/` |
