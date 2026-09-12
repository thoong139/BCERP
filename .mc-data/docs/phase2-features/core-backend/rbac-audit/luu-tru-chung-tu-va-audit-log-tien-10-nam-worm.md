# Tính Năng: Lưu Trữ Chứng Từ & Audit Log Tiền ≥10 Năm (WORM)

> **Dựa trên:** REQ-FIN-012 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** BCERP Core Backend (SYS-CORE-BACKEND)
> **Module:** RBAC & Audit Log (MOD-RBAC-AUDIT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/rbac-audit/[screen-group].md`, `phase5-implementation/tasks/core-backend/rbac-audit/feat-core-rbac-007-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-RBAC-007 |
| Module | MOD-RBAC-AUDIT |
| Yêu cầu nghiệp vụ | REQ-FIN-012 |
| Người dùng liên quan | FIN_L1, FIN_L2 (tra cứu chứng từ, đối soát), BOD_CFO_CTO (đề xuất archive, ký change/restore, giám sát toàn vẹn); BOD_CEO duyệt xuất/archive (nối FEAT-CORE-RBAC-002); SYS_ADMIN vận hành backup (không xem nội dung tài chính) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — nền móng GĐ1, mọi module tiền phụ thuộc; kiến trúc phải có từ giao dịch tiền đầu tiên) |
| Phụ thuộc | FEAT-CORE-RBAC-005 (nền tảng RBAC & SSO/MFA); FEAT-CORE-RBAC-002 (audit log hash-chain — tính năng này định tuyến log đó vào WORM và bổ sung phần chứng từ + backup/DR + change management); FEAT-CORE-RBAC-003 (change management cho luồng tiền gắn thẩm quyền duyệt change) |
| Ghi chú Expert (A7) | finance.md Mục A7 chưa ghi điều chỉnh nào sau Expert Review — spec bám nguồn Phần B (B.5: BR-FIN-501→505) do compliance-expert viết |

---

## 1. Mô Tả Tính Năng

**Mục đích:**

Bảo đảm mọi chứng từ tài chính và audit log tiền của BCERP được lưu trữ bất biến tối thiểu 10 năm theo Luật Kế toán 2015 trên WORM storage — không đối tượng nào (kể cả Super Admin) ghi đè/xóa được trong thời hạn retention — kèm hệ thống backup mã hóa có test phục hồi định kỳ (RTO ≤4h, RPO ≤15 phút) và change management chặn mọi thay đổi luồng tiền không có hồ sơ duyệt. Đây là điều kiện tiên quyết để BC vận hành trung gian quảng cáo với dòng tiền giữ hộ của khách.

**Phạm vi:**

- Bao gồm:
  - Định tuyến log/chứng từ tiền vào WORM storage theo retention phân tầng: log tiền + hợp đồng và chứng từ đối soát ≥10 năm; HĐĐT theo TT78/2021 + NĐ 123/2020; log hệ thống ≥7 năm; KYC/AML ≥5 năm.
  - Ràng buộc bất biến: account DB chỉ INSERT/SELECT; sửa sai luôn qua reversal có reason code.
  - Backup AES-256 hằng ngày 2 nơi tách biệt, replication gần realtime cho luồng tiền; test phục hồi mỗi quý có biên bản ký; RTO ≤4h, RPO ≤15 phút.
  - Change management luồng tiền: chặn deploy thiếu change record duyệt; rollback plan bắt buộc; change khẩn P1 hậu phê duyệt ≤24h.
  - Luồng hết hạn retention: CTO đề xuất + BOD_CEO duyệt theo quý, việc xóa cũng bị log; yêu cầu pháp lý chỉ kéo dài hạn giữ (LEGAL_HOLD).
- Không bao gồm:
  - Ghi audit log hash-chain và luồng xuất log có phê duyệt — thuộc FEAT-CORE-RBAC-002 (tính năng này tiêu thụ output của nó để định tuyến WORM).
  - Tra cứu/xuất chứng từ trên giao diện web — do SYS-BCERP-WEB (counterpart); bản này là API/domain service + hạ tầng storage/backup.
  - Phát hành HĐĐT (nghiệp vụ XML, kết nối thuế) — thuộc phân hệ tài chính REQ-FIN-011; bản này chỉ lưu trữ HĐĐT theo đúng tầng retention.
  - Connector phần mềm kế toán VAS — thuộc REQ-FIN-013 (MOD-SETTINGS-GW, cấu hình kết nối ngoại vi vendor-agnostic theo DI-004).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint là **headless API/domain service trên core backend**: định tuyến WORM, backup, test restore và change gate đều là dịch vụ nền; mọi phân hệ tiền (ví REC/WALLET/QUOTATION) gọi API mà không tự quản lưu trữ.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Tra cứu chứng từ đối soát theo khách/TKQC qua API, đúng bản gốc bất biến | Đối soát trên chứng từ không thể bị nghi là bản sửa |
| 2 | FIN_L2 | Sửa sai luôn có reversal old → new kèm lý do, bản ghi gốc giữ nguyên | Sổ sách tái lập được theo đúng trình tự, chuẩn kiểm toán |
| 3 | BOD_CFO_CTO | Xem trạng thái backup/replication hằng ngày và kết quả test restore quý | Backup chưa test restore không tính là backup hợp lệ |
| 4 | BOD_CFO_CTO | Đề xuất archive/xóa chứng từ, log hết hạn retention theo quý chờ CEO duyệt | Tuân thủ retention mà không phá nguyên tắc bất biến |
| 5 | SYS_ADMIN | Vận hành backup/restore theo change record duyệt, không xem nội dung chứng từ | Trách nhiệm kỹ thuật tách khỏi thẩm định tài chính |
| 6 | Hệ thống (change gate) | Chặn deploy/thay đổi production luồng tiền thiếu change record duyệt | Kể cả change khẩn cũng phải hậu phê duyệt ≤24h |
| 7 | Hệ thống (replication) | Sao chép gần realtime mọi ghi mới luồng giao dịch tiền | RPO ≤15 phút ngay cả khi mất primary giữa ngày |
| 8 | FIN_L1 | Nhận cảnh báo khi backup thất bại trong 30 phút | Kịp xử lý trước khi mất cửa sổ an toàn dữ liệu ngày |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service (không tin UI).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | (Dùng chung lane) RBAC chuẩn hóa 18 vai registry (BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1, HR_L2, FIN_L1, FIN_L2, SALES_L1–L5, OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; CUSTOMER chỉ portal). KHÔNG có OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight | Quyền tra cứu/duyệt gán cho vai ngoài registry bị chặn |
| BR-002 | (Dùng chung lane) Audit log bất biến hash-chain ≥10 năm WORM với log tiền; mọi thao tác ghi có actor + timestamp + lý do — đây là gốc của tính năng: log tiền định tuyến vào WORM ngay từ ghi đầu tiên | Bản ghi tiền không có định tuyến WORM → cấu hình sai, chặn go-live phân hệ; nỗ lực sửa/xóa trong WORM thất bại ở tầng storage |
| BR-003 | (Dùng chung lane) Quarterly access review bắt buộc; compensating control kiêm nhiệm CFO/CTO (REQ-BOD-002): change khẩn P1 do CTO thực hiện ngay bằng quyền khẩn phải hậu phê duyệt ≤24h và bổ sung hồ sơ | Change khẩn quá 24h chưa hậu phê → alert đỏ lên BOD; quyền khẩn không dùng được cho thay đổi định kỳ |
| BR-004 | (Dùng chung lane) SSO/MFA tập trung; PII nhân sự (lương) Confidential/Restricted — chứng từ chứa PII nhân sự (bảng lương, hợp đồng lao động) được mã hóa và mask theo vai khi tra cứu (nối REQ-HR-010) | Chứng từ C1 trả không mask cho vai không đủ tier → service chặn |
| BR-005 | (Dùng chung lane) Phê duyệt vượt ngưỡng 5/50/200 triệu VND + escalation khi vượt thẩm quyền — chứng từ sinh ra từ các giao dịch duyệt theo ngưỡng này được lưu nguyên trạng cùng snapshot duyệt | Chứng từ thiếu tham chiếu lệnh duyệt → đối soát báo thiếu chứng cứ, chặn khóa kỳ |
| BR-006 | Bất biến ở tầng quyền DB: account ứng dụng chỉ INSERT/SELECT trên bảng log/chứng từ đã khóa; không tồn tại interface xóa/sửa ở mọi tầng (UI, API, DB, script vận hành) — kể cả Super Admin | Mọi cố gắng UPDATE/DELETE thất bại; script chứa lệnh ghi đè bị cấm theo change management |
| BR-007 | Sửa dữ liệu nhập sai KHÔNG sửa bản ghi gốc — luôn ghi reversal có reason code giữ dấu vết cũ → mới (khớp BR-FIN-202/BR-FIN-105) | Không có endpoint sửa bản gốc; thiếu reason code → reversal không submit được |
| BR-008 | Retention phân tầng (tối thiểu): log tiền + hợp đồng và chứng từ đối soát ≥10 năm (Luật Kế toán 2015); HĐĐT theo TT78/2021 + NĐ 123/2020 (mốc cụ thể chốt với tư vấn thuế khi cấu hình); log hệ thống ≥7 năm; KYC/AML ≥5 năm | Dữ liệu chưa hết hạn không vào đề xuất archive; cấu hình retention thấp hơn tầng tối thiểu bị chặn |
| BR-009 | WORM: sau khi ghi, không đối tượng nào (kể cả Super Admin) ghi đè/xóa được trong thời hạn retention; hết hạn → CTO đề xuất + BOD_CEO duyệt theo quý, việc xóa cũng bị log; yêu cầu pháp lý chỉ kéo dài hạn giữ, không rút ngắn | Ghi đè WORM thất bại + alert; xóa ngoài quý/không duyệt bị chặn; LEGAL_HOLD ưu tiên mọi luồng xóa |
| BR-010 | Backup toàn bộ dữ liệu CORE + GW hằng ngày, AES-256, 2 nơi tách biệt (onsite + offsite khác vùng); replication gần realtime cho luồng ghi tiền; alert backup thất bại trong 30 phút; RTO ≤4h, RPO ≤15 phút | Backup fail quá 30 phút không alert → audit hạ tầng bắt sửa; RTO/RPO không đạt trong test → chặn nghiệm thu quý |
| BR-011 | Test phục hồi mỗi quý: restore tập dữ liệu thực lên môi trường test, đối chiếu hash, biên bản CTO ký báo BOD_CEO; backup chưa từng test không tính là backup hợp lệ; drill đột xuất tối đa 1 lần/năm; sự cố/drill thất bại → post-mortem 5 ngày làm việc | Quý thiếu test restore → "backup không hợp lệ" trên báo cáo BOD; post-mortem trễ → cảnh báo BOD |
| BR-012 | Change management luồng tiền: chặn deploy/thay đổi production thiếu change record duyệt; CTO duyệt, FIN lead xác nhận thêm khi ảnh hưởng luồng tiền/hợp đồng/phân quyền; window ngoài giờ cao điểm có thông báo; rollback plan bắt buộc (không khả thi thì backup điểm thời gian trước change); post-review 3 ngày làm việc; đổi cấu hình AML T1–T6 tính là change luồng tiền | Deploy thiếu record bị CI-CD chặn; đổi config nóng không phê duyệt → rollback + post-mortem |

**Assumptions (ghi nhận, không tự quyết):** mốc lưu trữ HĐĐT cụ thể theo TT78/2021 + NĐ 123/2020 chốt với tư vấn thuế khi cấu hình bảng retention (BR-008) — thiết kế để được dạng cấu hình, không hard-code.

---

## 4. Phân Quyền

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN |
|-----------|--------|--------|-------------|-----------|
| Tra cứu chứng từ/log tiền theo khách/TKQC được gán | ✅ (meta-log) | ✅ (toàn bộ khách — meta-log) | ✅ (meta-log) | ❌ (không nội dung tài chính) |
| Ghi reversal sửa sai có reason code | ✅ (lệnh của mình) | ✅ | ✅ (điều chỉnh tài chính) | ❌ |
| Sửa/ghi đè chứng từ, log gốc | ❌ | ❌ | ❌ | ❌ (không tồn tại interface) |
| Đề xuất archive/xóa hết hạn retention (theo quý) | ❌ | ✅ (đề xuất kiến nghị) | ✅ (đề xuất chính thức) | ❌ |
| Duyệt archive/xóa | ❌ | ❌ | ❌ | ❌ (BOD_CEO duyệt — nối FEAT-CORE-RBAC-002) |
| Vận hành backup, restore, WORM hạ tầng | ❌ | ❌ | ✅ (theo change record duyệt) | ✅ (thực thi sau duyệt) |
| Ký biên bản test restore quý | ❌ | ❌ | ✅ (ký, báo BOD_CEO) | ❌ |
| Đề xuất duyệt change record luồng tiền | ❌ | ✅ (FIN lead xác nhận ảnh hưởng) | ✅ (duyệt change) | ✅ (đề xuất change kỹ thuật) |
| Thực thi change khẩn P1 (quyền khẩn) | ❌ | ❌ | ✅ (hậu phê duyệt ≤24h) | ✅ (hỗ trợ theo lệnh CTO, log từng bước) |
| Xem plaintext backup | ❌ | ❌ | ❌ | ❌ (backup mã hóa AES-256, không có lộ trình decrypt ngoài restore kiểm soát) |

**Ghi chú phân quyền:** chỉ dùng 18 vai registry; BOD_CEO duyệt qua các feature nối (FEAT-CORE-RBAC-002/003) nên không lặp cột; meta-log áp mọi vai — tra cứu chứng từ/log cũng bị log.

---

## 5. Trường Hợp Đặc Biệt

- **Giao dịch nhập sai phát hiện sau khóa kỳ:** xử lý bằng reversal có phê duyệt; quyết toán lại quý cũ phục vụ kiểm toán chạy backfill có phê duyệt CFO (REQ-BOD-010), kỳ mở lại phải chốt lần hai có ghi nhận.
- **Thanh tra thuế/kiểm toán yêu cầu chứng từ nhiều năm:** xuất qua luồng có phê duyệt; LEGAL_HOLD tự kích hoạt cho phạm vi thuộc phiên điều tra — mọi luồng xóa/archive tạm dừng đến khi hồ sơ đóng.
- **Backup thất bại lúc nửa đêm:** alert trong 30 phút đến SYS_ADMIN + CTO; fail liên tiếp 2 ngày → cảnh báo BOD vì vi phạm biên an toàn RPO.
- **Drill restore thất bại (RTO vượt 4h):** biên bản thất bại + post-mortem 5 ngày làm việc; báo cáo BOD ghi rõ "backup không hợp lệ" cho đến khi đạt lại.
- **Change khẩn P1 giữa giờ cao điểm (adapter lỗi làm sai dòng tiền):** CTO thực hiện ngay bằng quyền khẩn, change record dạng "khẩn — hậu phê duyệt" hoàn tất ≤24h; mọi bước ghi log bất biến.
- **Dung lượng WORM lớn (10 năm × 2.600+ TKQC):** storage class phân tầng (nóng 90 ngày → lạnh/lưu trữ) không phá tính bất biến — hash giữ nguyên khi chuyển tầng; báo cáo dung lượng định kỳ cho BOD.
- **Migration dữ liệu legacy (hướng C migrate chọn lọc theo DI-004):** nhập vào WORM một lần qua luồng import có change record + đối chiếu hash; import đè dữ liệu đã có là lỗi chặn.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Đối tượng lưu trữ WORM (Chứng từ / log tiền — WORM Object)

**Sơ đồ trạng thái:**
```
[ACTIVE] ──(gần hạn retention, job quét)──► [NEAR_EXPIRY] ──(CTO đề xuất, gom quý)──► [DISPOSAL_PROPOSED] ──(BOD_CEO duyệt)──► [DISPOSAL_APPROVED] ──(thực thi, xóa cũng bị log)──► [DISPOSED]
    │                                            │
    │ (yêu cầu pháp lý)                          │ (kéo dài hạn giữ)
    ▼                                            ▼
[LEGAL_HOLD] ──(hồ sơ pháp lý đóng)──► [ACTIVE]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `ACTIVE` | Ghi vào WORM | `ACTIVE` | Hệ thống (service ghi) | Định tuyến đúng tầng retention; hash-chain gắn kèm |
| `ACTIVE` | Job quét hạn | `NEAR_EXPIRY` | Hệ thống | Còn <90 ngày đến hạn tối thiểu (cấu hình) |
| `ACTIVE`/`NEAR_EXPIRY` | Yêu cầu pháp lý | `LEGAL_HOLD` | Hệ thống khi có phiên thanh tra/điều tra | Giữ đến khi hồ sơ đóng; chặn mọi đề xuất xóa |
| `NEAR_EXPIRY` | Đề xuất archive/xóa | `DISPOSAL_PROPOSED` | BOD_CFO_CTO | Gom theo quý; liệt kê phạm vi + căn cứ hết hạn |
| `DISPOSAL_PROPOSED` | Duyệt | `DISPOSAL_APPROVED` | BOD_CEO | MFA; việc duyệt nằm trong audit log |
| `DISPOSAL_APPROVED` | Thực thi xóa/archive | `DISPOSED` | SYS_ADMIN thực thi / hệ thống | Chính việc xóa được ghi log; chỉ áp dụng cho đối tượng đã hết hạn tối thiểu |

**Quy tắc:** `DISPOSED` là trạng thái kết thúc; `LEGAL_HOLD` đè ưu tiên mọi chuyển tiếp về xóa; retention chỉ được kéo dài — không chuyển tiếp nào rút ngắn hạn giữ. Mọi chuyển tiếp nằm trong audit log hash-chain.

**Entity phụ:** Change Record (luồng tiền): `DRAFT → PENDING_APPROVAL → APPROVED → IN_WINDOW → COMPLETED → POST_REVIEWED` hoặc `REJECTED`; nhánh khẩn: `EMERGENCY_EXECUTED → POST_APPROVAL(≤24h) → POST_REVIEWED`.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `voucher_document` | `voucher_id`, `type` (đối soát/hợp đồng/hóa đơn), `transaction_ref`, `file_hash`, `worm_object_ref`, `status` | FK → giao dịch nguồn | Bản gốc bất biến; có hash đối chiếu; chứa PII thì mask theo vai |
| `worm_object` | `object_id`, `storage_class` (HOT/COLD), `retention_until`, `legal_hold`, `content_hash`, `status` | N-1 từ `voucher_document`, `audit_event` | Chặn ghi đè/xóa ở tầng storage đến `retention_until` |
| `retention_schedule` | `data_class`, `min_years`, `legal_basis` | Định tuyến `worm_object` | 10 năm tiền/HĐ; 7 năm log hệ thống; 5 năm KYC; HĐĐT theo TT78/NĐ123 |
| `disposal_proposal` | `proposal_id`, `proposed_by` (CTO), `scope`, `status`, `approved_by` (CEO), `disposed_at` | N-N → `worm_object` | Chạy theo quý; việc xóa tự ghi log |
| `backup_job` | `job_id`, `type` (DAILY/REPLICA), `target_zone`, `status`, `started_at`, `failed_at`, `alerted` | Độc lập | AES-256; 2 nơi; alert fail ≤30 phút |
| `restore_test_record` | `test_id`, `quarter`, `dataset`, `hash_match`, `rto_actual`, `rpo_actual`, `signed_by` (CTO) | Tham chiếu `backup_job` | Quý thiếu bản ghi → "backup không hợp lệ" trên báo cáo BOD |
| `change_record` | `change_id`, `scope` (tiền/hợp đồng/phân quyền), `proposed_by`, `approved_by`, `rollback_plan`, `window`, `status`, `emergency` | Độc lập | CI-CD chặn deploy thiếu record APPROVED; khẩn hậu phê ≤24h |

---

## 8. Acceptance Criteria

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Định tuyến WORM đúng tầng | Giao dịch tiền đầu tiên phát sinh | Log/chứng từ ghi | Định tuyến WORM với `retention_until` ≥10 năm; hash-chain gắn; không cấu hình nào cho phép tầng thấp hơn tối thiểu | [ ] |
| SC-002: Không ai ghi đè WORM | Super Admin (CTO) có quyền cao nhất | Cố gắng UPDATE/DELETE đối tượng WORM | Thất bại ở tầng quyền DB và storage; nỗ lực ghi log + alert | [ ] |
| SC-003: Sửa sai qua reversal | Chứng từ nhập sai số liệu | Ghi reversal có reason code | Bản gốc giữ nguyên; reversal old → new có log; khóa kỳ không bị phá | [ ] |
| SC-004: Backup + alert 30 phút | Job backup hằng ngày | Backup thất bại | Alert trong 30 phút đến SYS_ADMIN + CTO; replication luồng tiền giữ RPO ≤15 phút | [ ] |
| SC-005: Test restore quý | Kết thúc quý | Chạy restore tập thực lên môi trường test | Đối chiếu hash khớp; biên bản CTO ký; RTO ≤4h, RPO ≤15 phút ghi nhận; thiếu bản ghi → báo cáo BOD "backup không hợp lệ" | [ ] |
| SC-006: Change gate chặn deploy | Không có change record APPROVED | Deploy thay đổi luồng tiền | CI-CD chặn; có record → chỉ chạy trong window có thông báo, rollback plan bắt buộc | [ ] |
| SC-007: Change khẩn hậu phê duyệt | Sự cố P1 giờ cao điểm | CTO thực thi quyền khẩn | Change record "khẩn" tạo kèm; hậu phê duyệt + hồ sơ ≤24h; quá hạn → alert đỏ BOD | [ ] |
| SC-008: Archive theo quý + LEGAL_HOLD | Chứng từ hết hạn 10 năm; đồng thời có phiên thanh tra | CTO đề xuất archive | Phiên thanh tra → LEGAL_HOLD chặn xóa; hết phiên → CEO duyệt theo quý; việc xóa cũng bị log; không rút ngắn hạn nào | [ ] |

> **Liên kết:** SC-001→003 map REQ-FIN-012 (BR-FIN-501); SC-004→005 map REQ-FIN-012 (BR-FIN-504); SC-006→007 map REQ-FIN-012 (BR-FIN-505) + REQ-BOD-002 (quyền khẩn); SC-008 map REQ-FIN-012 (BR-FIN-503).

---

## Tài Liệu Kĩ Thuật Liên Quan

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (voucher lookup, disposal, backup status, change gate) | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (audit service FEAT-CORE-RBAC-002, CI-CD gate, alert REQ-BOD-006) | `technical-specs/integration-map.md` |
| Màn hình UI (dashboard retention, backup health, change console — counterpart WEB) | `phase4-ux/core-backend/rbac-audit/[screen-group].md` |
| Touchpoint counterpart | SYS-BCERP-WEB (fan-out cùng REQ-FIN-012) |
