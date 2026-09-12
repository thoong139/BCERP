# Tính Năng: Lưu Trữ Chứng Từ & Audit Log Tiền ≥10 Năm (WORM)

> **Dựa trên:** REQ-FIN-012 trong `phase1-business/departments/finance/finance.md` (Phần A; chi tiết business rule B.5 — BR-FIN-501..505)
> **Phân hệ:** RBAC & Audit Log (SYS-BCERP-WEB)
> **Module:** RBAC & Audit Log (MOD-RBAC-AUDIT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/rbac-audit/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/rbac-audit/feat-007-impl.md`

> **Hướng dẫn ID:** FEAT-ID được tạo từ REQ-ID theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. Bản fan-out này dùng ID lane `FEAT-ERP-RBAC-007` — bản riêng của touchpoint SYS-BCERP-WEB (bản counterpart: SYS-CORE-BACKEND).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-RBAC-007 |
| Module | MOD-RBAC-AUDIT |
| Yêu cầu nghiệp vụ | REQ-FIN-012 |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO (BOD_CEO duyệt xóa/archive — luồng ký tại FEAT-ERP-RBAC-002/003) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — nền móng GĐ1: WORM + hash-chain phải có từ giao dịch tiền đầu tiên, không bổ sung sau được) |
| Phụ thuộc | FEAT-ERP-RBAC-002 (tra cứu audit log — tính năng này quản vòng đời lưu trữ phía sau), FEAT-ERP-RBAC-005 (SSO/MFA truy cập) |
| Ghi chú Expert (A7) | A7 của `finance.md` được phân tích bởi compliance-expert (call-2 — B.5: BR-FIN-501..505 là nền móng GĐ1, kiến trúc phải có từ ngày đầu); điểm phối hợp A7 đã xác định: REQ-FIN-012 phụ thuộc hạ tầng chứ không phụ thuộc tiến trình Business Verification API; điều chỉnh vai: DI-006 gỡ FIN_COMPL — vai Compliance gán FIN_L2 + BOD oversight; chi tiết tại `finance.md` Mục A7 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Bảo đảm mọi bằng chứng tài chính của BC Agency — audit log giao dịch tiền/hợp đồng và chứng từ đối soát — được lưu trữ bất biến tối thiểu 10 năm trên WORM storage theo Luật Kế toán 2015, sẵn sàng cho thanh tra, kiểm toán bất cứ lúc nào. Trên web nội bộ, FIN_L1/FIN_L2 tra cứu audit log và chứng từ theo khách/TKQC/giao dịch, theo dõi sức khỏe lưu trữ (hash-chain, retention, backup/DR), còn BOD_CFO_CTO đề xuất xử lý dữ liệu hết hạn — mọi thao tác đều để lại dấu vết, kể cả ở cấp Super Admin.

**Phạm vi:**
- Bao gồm: màn tra cứu audit log và chứng từ theo khách/TKQC/giao dịch (chuỗi old → new + reason code, nước dùng chung FEAT-ERP-RBAC-002); dashboard lưu trữ cho FIN/BOD: tình trạng WORM theo tầng retention (tiền/hợp đồng ≥10 năm; log hệ thống ≥7 năm; KYC/AML ≥5 năm; HĐĐT theo TT78/2021 + NĐ 123/2020), dung lượng, dữ liệu sắp hết hạn; luồng trình duyệt xóa/archive theo quý (CTO đề xuất — CEO duyệt, việc xóa cũng log); hiển thị trạng thái backup/DR phục vụ bằng chứng (RTO ≤4h/RPO ≤15 phút, kết quả test restore quý — biên bản xem được); luồng sửa dữ liệu tài chính sai sót qua giao dịch reversal có reason code (không hard-delete) hiển thị dấu vết cũ → mới.
- Không bao gồm: ứng dụng append-only/hash-chain và định tuyến WORM storage (SYS-CORE-BACKEND — BR-FIN-501/503); chạy backup và test restore (SYS_ADMIN vận hành hạ tầng, web chỉ hiển thị biên bản/trạng thái); luồng tra cứu + xuất log và meta-log chi tiết (FEAT-ERP-RBAC-002 — chuyên trách tra cứu); phát hành HĐĐT (REQ-FIN-011); đối soát ví (REQ-FIN-002).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Tra cứu chứng từ đối soát và audit log của khách/TKQC mình phụ trách theo giao dịch cụ thể | Trả lời ngay câu hỏi "khoản này sao lại vậy" mà không phải lục mail/file nội bộ |
| 2 | FIN_L2 | Xem dấu vết điều chỉnh tài chính theo chuỗi cũ → mới kèm reason code | Kiểm soát ghi sổ không có "sửa đè không vết" — mọi sai sót đi qua reversal có lý do |
| 3 | BOD_CFO_CTO | Xem dashboard lưu trữ: dung lượng WORM, dữ liệu sắp hết hạn retention, trạng thái hash-chain gần nhất | Chủ động vận hành lưu trữ và trình đề xuất xóa/archive đúng quý |
| 4 | BOD_CFO_CTO | Trình đề xuất xóa/archive log/chứng từ hết hạn retention cho CEO duyệt | Tuân thủ chính sách "xóa cũng phải có duyệt và bị log" mà không giữ dữ liệu vô hạn |
| 5 | FIN_L2 | Xem biên bản test restore DR hằng quý và trạng thái backup gần nhất | Yên tâm rằng bằng chứng 10 năm thực sự khôi phục được — backup chưa test không tính là hợp lệ |
| 6 | FIN_L1 | Theo dõi trạng thái chứng từ đã gắn với từng lệnh giao dịch (nạp/hoàn/điều chỉnh) | Biết ngay lệnh nào thiếu chứng từ để bổ sung trước khi khóa kỳ |
| 7 | BOD_CEO/CFO (qua màn chia sẻ của FIN) | Xem báo cáo retention định kỳ (log sắp hết hạn, dung lượng WORM) | Giám sát nghĩa vụ pháp lý 10 năm ở cấp điều hành |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Append-only, hash-chain, WORM routing và backup enforce ở SYS-CORE-BACKEND + hạ tầng; web trình bày trạng thái và không cung cấp bất kỳ đường can thiệp nào.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | RBAC dùng đúng 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5, ...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — vai Compliance gán FIN_L2 + BOD oversight; FIN_L1 xem phạm vi khách được gán, FIN_L2 toàn bộ khách | Tra cứu vượt phạm vi gán → trả rỗng + ghi attempt; cấu hình phạm vi theo vai ngoài registry bị từ chối |
| BR-002 | Audit log bất biến append-only hash-chain, lưu ≥10 năm (WORM) với log tiền — chứng từ đối soát + hợp đồng cùng ≥10 năm (Luật Kế toán 2015); mọi thao tác ghi có actor + timestamp + lý do; kể cả Super Admin không sửa/xóa được — không tồn tại interface xóa ở mọi tầng | Attempt sửa/xóa bị chặn tầng DB (chỉ INSERT/SELECT); web read-only tuyệt đối với bản ghi gốc |
| BR-003 | Quarterly access review bắt buộc cho quyền tra cứu lưu trữ (nối REQ-BOD-007); kiêm nhiệm CFO/CTO phải có compensating control (REQ-BOD-002) — hành vi lưu trữ của Super Admin nằm trong immutable audit | Quyền không review 2 quý → tự vô hiệu; đề xuất xóa/archive của CFO không đi qua luồng CEO duyệt → bị chặn |
| BR-004 | SSO/MFA tập trung; dữ liệu lương/cost cá nhân xuất hiện trong chứng từ (Rate Card, hoa hồng) ở mức Confidential/Restricted — mask theo vai; chứng từ khách (biên bản đối soát) ở mức Restricted theo REQ-FIN-017 | Phiên không hợp lệ → chặn; giá trị Restricted trả masked, không có nút bỏ mask |
| BR-005 | Sửa dữ liệu tài chính nhập sai: không sửa bản ghi gốc — chỉ qua giao dịch reversal có reason code, giữ dấu vết cũ → mới; lệnh chi/hoàn bám khung ngưỡng 5/50/200 triệu VND đã chốt (DI-001) với escalation lên cấp trên khi vượt thẩm quyền; điều chỉnh vượt thẩm quyền phải đi đúng nhánh duyệt | Thiếu reason code → reversal không submit; điều chỉnh không qua reversal → chặn tầng API + alert |
| BR-006 | Retention phân tầng và chỉ kéo dài không rút ngắn: yêu cầu pháp lý (thanh tra/kiểm toán) chỉ gia tăng thời hạn giữ; xóa/archive hết hạn theo quý — CTO đề xuất + CEO duyệt, chính việc xóa cũng bị log; HĐĐT lưu theo TT78/2021 + NĐ 123/2020 (thời hạn cụ thể chốt với tư vấn thuế — đánh dấu trong cấu hình) | Đề xuất rút ngắn retention → chặn validate; xóa ngoài kỳ/không duyệt → từ chối + log attempt |
| BR-007 | Backup mã hóa hằng ngày 2 nơi tách biệt + replication gần realtime cho luồng tiền (RPO ≤15 phút, RTO ≤4 giờ); test phục hồi hằng quý có biên bản ký; backup chưa từng test restore không tính là backup hợp lệ; alert backup thất bại trong 30 phút | Test restore trễ/quá hạn → dashboard đỏ; thiếu biên bản quý → trạng thái "không hợp lệ" hiển thị cho BOD |
| BR-008 | Meta-log áp dụng đồng nhất: mọi truy cập lưu trữ (kể cả của FIN/BOD) nằm trong hash-chain; truy xuất/xuất ngoài báo cáo chuẩn cần duyệt BOD_CEO ≤2 ngày làm việc (luồng chi tiết tại FEAT-ERP-RBAC-002) | Truy cập không có meta-log → job đối chiếu gắn cờ; không có ngoại lệ cho bất kỳ vai nào |

---

## 4. Phân Quyền

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN | BOD_CEO |
|-----------|--------|--------|-------------|-----------|---------|
| Tra cứu log/chứng từ phạm vi khách được gán | ✅ | ✅ (toàn bộ khách) | ✅ | ❌ (không nội dung nghiệp vụ) | ✅ |
| Xem dấu vết reversal old → new | ✅ (phạm vi mình) | ✅ | ✅ | ❌ | ✅ |
| Tạo giao dịch reversal (sửa sai có lý do) | ◐ (đề xuất) | ✅ (duyệt theo ngưỡng) | ◐ (đề xuất — giao dịch CFO khởi tạo khóa chờ CEO, FEAT-ERP-RBAC-001) | ❌ | ❌ |
| Xem dashboard lưu trữ (WORM, retention, hash-chain) | ◐ (phần vận hành hằng ngày) | ✅ | ✅ | ◐ (trạng thái kỹ thuật) | ✅ |
| Xem biên bản test restore DR | ❌ | ✅ | ✅ (ký biên bản, báo CEO) | ✅ (vận hành) | ✅ |
| Đề xuất xóa/archive hết hạn | ❌ | ❌ | ✅ (theo quý) | ❌ | ❌ |
| Duyệt xóa/archive hết hạn | ❌ | ❌ | ❌ | ❌ | ✅ (theo quý) |
| Chạy backup/test restore (hạ tầng) | ❌ | ❌ | ❌ | ✅ (theo change CTO duyệt) | ❌ |
| Xóa/sửa bản ghi gốc trực tiếp | ❌ | ❌ | ❌ | ❌ | ❌ |

---

## 5. Trường Hợp Đặc Biệt

- Thanh tra/kiểm toán yêu cầu bản cứng hồ sơ 10 năm ngược: xuất qua đúng luồng duyệt BOD_CEO (FEAT-ERP-RBAC-002); dữ liệu WORM bảo đảm đọc được xuyên suốt các version phần mềm — chứng từ lưu định dạng chuẩn (PDF/A + XML gốc) kèm metadata, không phụ thuộc ứng dụng đọc.
- Chứng từ thiếu/hỏng file scan sau khi khóa kỳ: bổ sung chứng từ là một giao dịch bổ sung có reason code (không sửa bản ghi lệnh gốc); thiếu chứng từ khi chốt kỳ → cảnh báo chặn chốt cho đến khi đủ.
- Yêu cầu "xóa sạch dữ liệu khách X" khi chấm dứt hợp tác: nghĩa vụ lưu trữ chứng từ tiền/hợp đồng 10 năm ưu tiên hơn yêu cầu xóa — chỉ anonymize phần định danh có thể, phần bắt buộc giữ nguyên, lý do ghi nhận có log (khớp BR-FIN-605).
- Thảm họa mất trung tâm dữ liệu: theo BR-FIN-504 — replication gần realtime cho luồng tiền giữ RPO ≤15 phút; sau khôi phục, đối chiếu hash-chain toàn bộ bản ghi từ thời điểm backup gần nhất để chứng minh không có khoảng trống log; web hiển thị báo cáo đối chiếu cho BOD.
- Dữ liệu HĐĐT: XML gốc + bản trình bày lưu theo quy định TT78/2021 + NĐ 123/2020 — thời hạn cụ thể đang chốt với tư vấn thuế `[CẦN CHỐT SỐ]`; thiết kế tầng retention cho phép cấu hình thời hạn riêng từng loại tài liệu mà không đổi kiến trúc.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Bản ghi lưu trữ (audit log/chứng từ) — vòng đời retention

**Sơ đồ trạng thái:**
```
[ACTIVE] ──(gần hết hạn retention)──► [RETENTION_APPROACHING] ──(đủ hạn)──► [RETENTION_DUE]
                                                                            │
                                                            (CTO đề xuất theo quý)
                                                                            ▼
                                                                   [ARCHIVE_PROPOSED] ──(CEO duyệt)──► [ARCHIVED]
                                                                            │                               (việc xóa cũng log)
                                                                            │ (CEO từ chối — gia hạn giữ)
                                                                            ▼
                                                                      [RETENTION_EXTENDED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `ACTIVE` | Job retention gắn cờ gần hạn | `RETENTION_APPROACHING` | Hệ thống | Còn dưới 90 ngày hết hạn tầng retention |
| `RETENTION_APPROACHING` | Đủ hạn | `RETENTION_DUE` | Hệ thống | Không có yêu cầu pháp lý kéo dài đang hiệu lực |
| `RETENTION_DUE` | CTO đề xuất | `ARCHIVE_PROPOSED` | BOD_CFO_CTO | Gói đề xuất theo quý, liệt kê phạm vi + dung lượng |
| `ARCHIVE_PROPOSED` | CEO duyệt | `ARCHIVED` | BOD_CEO | Việc xóa/archive ghi log riêng; hash-chain không đứt |
| `ARCHIVE_PROPOSED` | CEO từ chối / yêu cầu pháp lý kéo dài | `RETENTION_EXTENDED` | BOD_CEO | Lý do + thời hạn mới ghi rõ; chỉ kéo dài không rút ngắn |

**Quy tắc:**
- `ACTIVE` không bao giờ chuyển trực tiếp `ARCHIVED` — bắt buộc qua đề xuất + duyệt theo quý.
- `ARCHIVED` là trạng thái kết thúc; `RETENTION_EXTENDED` quay lại chu kỳ với thời hạn mới.
- Song song, trạng thái hash-chain (`VALID`/`INVALID`/`STALE`) của FEAT-ERP-RBAC-002 áp cho toàn bộ kho lưu trữ này — `INVALID` làm đóng băng mọi đề xuất archive.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `document_archive` | `id`, `doc_type`, `ref_transaction_id`, `ref_customer_id`, `file_ref` (PDF/A + XML), `retention_tier`, `retention_until`, `state` | FK → giao dịch/khách gốc | WORM object; không UPDATE/DELETE vật lý |
| `retention_policy` | `tier`, `min_years`, `legal_basis` (Luật Kế toán 2015, TT78/2021...) | — | Tiền/HĐ 10 năm; hệ thống 7 năm; KYC/AML 5 năm; HĐĐT cấu hình riêng |
| `archive_proposal` | `id`, `quarter`, `proposed_by`, `scope_summary`, `state`, `approved_by`, `executed_at` | FK → `users.id` | Theo quý; `ARCHIVED` sinh deletion log |
| `reversal_transaction` | `id`, `original_transaction_id`, `before_value`, `after_value`, `reason_code`, `created_by`, `approved_by` | FK → giao dịch gốc | Duy nhất đường sửa dữ liệu tài chính |
| `dr_test_record` | `id`, `quarter`, `tested_scope`, `rto_measured`, `rpo_measured`, `hash_check_passed`, `signed_by`, `record_state` | FK → `users.id` (signed_by) | Thiếu bản bản quý → trạng thái "không hợp lệ" |
| `backup_status` | `date`, `location` (onsite/offsite), `encrypted`, `result`, `alert_sent_at` | — | Hằng ngày; alert thất bại 30 phút |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ — chi tiết ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Tra cứu theo đối tượng | FIN_L1 đăng nhập (phạm vi khách gán) | Tra cứu chứng từ theo TKQC + giao dịch | Kết quả hiển thị chuỗi old→new + reason code; ngoài phạm vi → rỗng + log attempt; lượt xem meta-log | [ ] |
| SC-002: Reversal thiếu lý do | FIN_L2 tạo giao dịch điều chỉnh | Submit không nhập reason code | Không cho submit; sau khi nhập, bản gốc giữ nguyên và chuỗi old→new hiển thị ở tra cứu | [ ] |
| SC-003: Xóa hết hạn đúng luồng | Dữ liệu ở `RETENTION_DUE` trong kỳ quý | CTO đề xuất, CEO duyệt | Chuyển `ARCHIVED`; deletion log sinh tự động; đề xuất rút ngắn retention ở bất kỳ bước nào bị chặn validate | [ ] |
| SC-004: Thiếu test restore quý | Quý trôi qua không có biên bản DR | Dashboard cập nhật | Trạng thái lưu trữ hiển thị "backup không hợp lệ" cho BOD; alert đỏ; đề xuất archive bị đóng băng | [ ] |
| SC-005: Yêu cầu pháp lý kéo dài | Thanh tra yêu cầu giữ thêm dữ liệu đã đến hạn | Đánh dấu yêu cầu pháp lý | Trạng thái chuyển `RETENTION_EXTENDED` (không bao giờ rút ngắn); căn cứ pháp lý lưu kèm log | [ ] |

> **Liên kết:** SC-001 → REQ-FIN-012 (tra cứu theo khách/TKQC/giao dịch); SC-002 → REQ-FIN-012 (chỉ qua reversal có reason code); SC-003 → REQ-FIN-012 (CTO đề xuất + CEO duyệt theo quý, xóa cũng log); SC-004/SC-005 → REQ-FIN-012 (BR-FIN-503/504 — retention và backup/DR).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/rbac-audit/[screen-group].md` |
| Bản counterpart (audit core + WORM routing) | `.mc-data/docs/phase2-features/core-backend/rbac-audit/` (SYS-CORE-BACKEND — BR-FIN-501..505) |
