# Tính Năng: Tích hợp phần mềm kế toán VAS hiện hữu

> **Dựa trên:** REQ-FIN-013 trong `phase1-business/departments/finance/finance.md` (Phần A)
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
| ID tính năng | FEAT-ERP-ARAP-006 |
| Module | MOD-ARAP-PAYMENT |
| Yêu cầu nghiệp vụ | REQ-FIN-013 — Tích hợp phần mềm kế toán VAS hiện hữu (MEDIUM, Phase2) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Trung bình |
| Giai đoạn | Giai đoạn 2 (Phase2) — adapter qua Integration Gateway, đối chiếu sổ định kỳ |
| Phụ thuộc | REQ-BOD-008 — credentials vault & quản trị Gateway cho connector VAS (MOD-SETTINGS-GW); kèm phụ thuộc trạng thái khóa kỳ (REQ-FIN-004) |
| Ghi chú Expert (A7) | Điểm phối hợp liên phòng (finance.md Mục A7): compliance-expert phân tích khía cạnh tuân thủ tích hợp VAS trong B.6 — kết nối gửi cơ quan thuế của HĐĐT dùng chung luồng connector này (BR-FIN-601); DI-004 (12/09): không chốt vendor — connector cấu hình qua Settings (kết nối ngoại vi), vendor-agnostic |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng thiết lập và vận hành cầu nối giữa BCERP và phần mềm kế toán VAS hiện hữu theo nguyên tắc "tích hợp, không thay thế": BCERP là nguồn dữ liệu nghiệp vụ (chứng từ đối soát, lệnh chi, bút toán đề xuất, HĐĐT), sổ kế toán pháp lý vẫn nằm trên phần mềm VAS. Theo định hướng DI-004 (12/09), connector được cấu hình như một kết nối ngoại vi trong Settings (MOD-SETTINGS-GW) theo hướng vendor-agnostic — hỗ trợ import/export chuẩn schema và adapter API cắm được — kèm phương án migrate chọn lọc dữ liệu từ legacy PMS và trạng thái legacy read-only sau cutoff, để sổ VAS luôn khớp BCERP.

**Phạm vi:**
- Bao gồm: màn hình web theo dõi connection profile VAS (trạng thái kết nối, cơ chế API hay import/export, timestamp sync gần nhất, số bút toán đã đồng bộ) — cấu hình chi tiết đặt tại MOD-SETTINGS-GW, web chỉ hiển thị trạng thái và điều hướng.
- Bao gồm: màn xuất bút toán/chứng từ — chọn kỳ/phạm vi, kiểm tra điều kiện "đã duyệt/khóa kỳ", sinh dữ liệu chuẩn schema hoặc file import/export; chỉ dữ liệu đã duyệt mới xuất được.
- Bao gồm: màn đối chiếu sổ VAS ↔ BCERP định kỳ hàng tháng — nạp sổ phụ từ VAS (qua API hoặc import file), so khớp theo bút toán, hiển thị chênh lệch và theo dõi giải trình FIN_L2 đến khi khép.
- Bao gồm: theo dõi migration legacy PMS chọn lọc (master data + dự án active + payment history 12 tháng): tiến trình từng nhóm dữ liệu, kết quả dry-run, đối soát sau migrate; sau cutoff, legacy chuyển read-only và mọi dữ liệu tham chiếu trỏ về BCERP.
- Bao gồm: quản lý lỗi đồng bộ — hàng chờ retry, alert khi connector fail, trạng thái degraded (chuyển import/export tay có kiểm soát), log mọi lượt xuất/nhập.
- Bao gồm: hiển thị kết quả dùng chung luồng kết nối cho HĐĐT (gửi mã cơ quan thuế qua cùng connector) và cho dữ liệu phí từ statement (phối hợp REQ-FIN-014).
- Không bao gồm: cấu hình credentials, connection profile, field mapping chi tiết — thuộc MOD-SETTINGS-GW (REQ-BOD-008, vault + console quản trị kết nối ngoại vi); web chỉ hiển thị trạng thái từ adapter.
- Không bao gồm: vận hành adapter bên dưới (định tuyến, vault, retry engine) — thuộc SYS-INTEGRATION-GW theo fan-out REQ-FIN-013; web không gọi thẳng VAS mà đi qua API core → GW.
- Không bao gồm: thay thế phần mềm kế toán VAS hay ghi sổ kế toán pháp lý trên BCERP; BCERP không trở thành hệ thống sổ sách pháp lý trong scope này.

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-BCERP-WEB — web nội bộ responsive; tên phần mềm kế toán cụ thể sẽ được cấu hình khi triển khai (DI-004), không chặn thiết kế.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Xem trạng thái connection profile VAS: kết nối khỏe hay degraded, sync lần cuối khi nào, bao nhiêu bút toán đã đồng bộ | Biết ngay sổ VAS đang khớp hay đang trễ trước khi chốt kỳ |
| 2 | FIN_L1 | Xuất bút toán đề xuất theo kỳ từ chứng từ đã duyệt/khóa kỳ (API hoặc file chuẩn schema) | Kế toán nhập sổ VAS mà không soạn lại tay, đúng schema từng VAS khi cấu hình |
| 3 | FIN_L2 | Chạy đối chiếu sổ VAS ↔ BCERP hàng tháng và thấy danh sách chênh lệch theo từng bút toán | Phát hiện lệch sớm, giao giải trình đúng người trước khi số liệu lan sang báo cáo |
| 4 | FIN_L2 | Ghi giải trình cho từng chênh lệch (nguyên nhân, cách xử lý, hạn khép) và theo dõi đến khi khép | Chênh lệch không treo vô chủ; bằng chứng giải trình phục vụ audit |
| 5 | BOD_CFO_CTO | Xem tiến trình migration legacy PMS: master data, dự án active, payment history 12 tháng — từng nhóm đã migrate/dry-run/đối soát thế nào | Quyết định thời điểm cutoff legacy read-only trên căn cứ dữ liệu đã kiểm chứng |
| 6 | BOD_CFO_CTO | Nhận alert khi connector fail hoặc số chênh lệch vượt ngưỡng bình thường | Can thiệp sớm trước khi ảnh hưởng chốt tháng/quý |
| 7 | SYS_ADMIN | Thực thi thay đổi cấu hình kết nối (profile/mapping) do CTO phê duyệt trên console Settings, sau đó kiểm tra sức khỏe connector trên web | Vai thực thi đúng biên — không tự ý đổi endpoint/credential hay bỏ qua phê duyệt |

Mọi thao tác xuất/nạp/đối chiếu đều ghi log immutable ở core và GW; khi VAS chỉ hỗ trợ import file, luồng file chuẩn schema + log lượt xuất vẫn giữ nguyên ràng buộc "chỉ xuất dữ liệu đã duyệt".

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Connector vận hành ở GW, cấu hình tại MOD-SETTINGS-GW; web không chứa secret và không gọi thẳng VAS.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Nguyên tắc tích hợp: BCERP tích hợp, không thay thế phần mềm kế toán VAS — sổ kế toán pháp lý nằm trên VAS; BCERP xuất bút toán chuẩn từ chứng từ đã duyệt, không ghi sổ thay VAS. | Mọi nỗ lực ghi sổ pháp lý từ BCERP ra ngoài luồng export bị chặn; phạm vi tính năng bị review |
| BR-002 | Chỉ xuất dữ liệu từ chứng từ đã duyệt/khóa kỳ — không xuất bản nháp, không xuất chứng từ chờ duyệt; dữ liệu xuất mang version/snapshot để đối chiếu về sau. | Yêu cầu xuất chứa bản nháp bị core từ chối; lô xuất thiếu snapshot bị coi là lỗi P1 |
| BR-003 | Connector vendor-agnostic theo DI-004 (12/09): cấu hình kết nối ngoại vi trong Settings (MOD-SETTINGS-GW) — connection profile + field mapping + import/export template chuẩn + adapter API cắm được; không hardcode vendor; tên phần mềm cụ thể cấu hình khi triển khai. | Code tham chiếu cứng vendor bị đánh fail review; đổi VAS phải chỉ cần đổi profile/mapping |
| BR-004 | Đối chiếu sổ VAS ↔ BCERP định kỳ hàng tháng: nạp sổ phụ qua API hoặc import file, so khớp bút toán; chênh lệch phải có giải trình FIN_L2 với nguyên nhân + cách xử lý + hạn khép; chênh lệch chưa giải trình bị đánh dấu nổi bật trong báo cáo chốt kỳ. | Chốt kỳ khi còn chênh lệch chưa giải trình phát cảnh báo cho CFO; số chênh lệch không được "phẳng hóa" thủ công |
| BR-005 | Legacy PMS migrate chọn lọc: chỉ migrate master data + dự án active + payment history 12 tháng; dữ liệu ngoài phạm vi không migrate (lưu archive legacy); sau cutoff legacy chuyển read-only — mọi cập nhật chỉ xảy ra trên BCERP. | Ghi dữ liệu ngược về legacy sau cutoff bị chặn; migrate ngoài phạm vi bị từ chối ở bước dry-run |
| BR-006 | Financial Hard Stop "đã khớp tiền" FIN_L1 (WEB + MFA TOTP) là điều kiện tiên quyết của mọi giải ngân liên quan TKQC; bút toán liên quan giải ngân chỉ xuất sang VAS sau khi điều kiện Hard Stop đã thỏa trên giao dịch gốc. | Bút toán thiếu căn cứ khớp tiền không được xuất; lệch này phát hiện ở đối chiếu là lỗi dữ liệu nghiêm trọng |
| BR-007 | SoD 4 vai dòng tiền (đề xuất ≠ khớp tiền ≠ duyệt chi ≠ ghi sổ) giữ nguyên qua biên giới tích hợp: người xuất bút toán ≠ người duyệt điều chỉnh bút toán; ngưỡng giải ngân 5/50/200 triệu + delegate áp dụng trên chứng từ gốc trước khi xuất. | Vai trùng khi xuất/điều chỉnh bị core block; bút toán từ chứng từ sai ngưỡng không xuất được |
| BR-008 | Connector fail → hàng chờ retry + alert; chế độ degraded (VAS chỉ hỗ trợ import file hoặc API ngắt) chuyển import/export tay có kiểm soát — file chuẩn schema + log lượt xuất + xác nhận nạp; không ghi sổ tay đè lên luồng chuẩn. | Ghi tay không qua luồng chuẩn bị coi là vi phạm quy trình; degraded không log là sự cố P1 |
| BR-009 | Hóa đơn điện tử TT78/2021 + NĐ123/2020 dùng chung luồng kết nối này để gửi mã cơ quan thuế và đồng bộ hóa đơn sang VAS; điều chỉnh/hủy hóa đơn trên BCERP phải phản ánh nhất quán sang VAS qua cùng connector. | HĐĐT BCERP và VAS lệch trạng thái tạo chênh lệch đối chiếu bắt buộc giải trình trước chốt kỳ |
| BR-010 | Phí nền tảng & nghĩa vụ thuế: dữ liệu phí từ statement/API và hạch toán giá vốn được đồng bộ theo giao dịch gốc; nghĩa vụ thuế (VAT/FCT) theo cấu hình thuế có phê duyệt — số liệu sổ VAS dùng để kê khai phải khớp BCERP sau đối chiếu. | Số thuế kê khai lệch BCERP không được công nhận; phải giải trình và điều chỉnh trước kỳ kê khai |
| BR-011 | Credentials của connector chỉ nằm trong vault của GW (REQ-BOD-008): MFA bắt buộc khi quản trị, rotate ≥90 ngày, không bao giờ hiển thị plaintext ở giao diện nào; web chỉ hiển thị trạng thái, không truy cập secret. | Secret xuất hiện ở UI/log là sự cố bảo mật P0; thao tác vault không MFA bị chặn |
| BR-012 | Mọi lượt xuất/nạp/đối chiếu/migrate ghi audit log immutable kèm reason/phiếu; dữ liệu tài chính Restricted — truy cập theo ma trận BR-FIN-603; SYS_ADMIN chỉ thực thi cấu hình sau phê duyệt CTO, mọi hành vi quản trị log immutable. | Log thiếu lượt sync là lỗi kiểm toán; SYS_ADMIN tự đổi cấu hình không phê duyệt bị chặn + log |

---

## 4. Phân Quyền

Quyền do RBAC engine của core kiểm tra tại API; cấu hình connector thuộc MOD-SETTINGS-GW (REQ-BOD-008). Bảng dưới là hợp đồng UI web nội bộ.

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO | SYS_ADMIN | SYS_ADMIN (GW console) |
|-----------|--------|--------|-------------|-----------|------------------------|
| Xem trạng thái connection profile | ✅ | ✅ | ✅ | ❌ (trừ console) | ✅ |
| Xuất bút toán theo kỳ | ✅ (chuẩn schema) | ✅ (phê duyệt lô đặc biệt) | ✅ | ❌ | ❌ |
| Nạp sổ phụ VAS / import file | ✅ | ✅ | ❌ | ❌ | ❌ |
| Chạy đối chiếu hàng tháng | ✅ | ✅ | ❌ | ❌ | ❌ |
| Ghi giải trình chênh lệch | ✅ (nhập thô) | ✅ (khép giải trình) | ✅ (duyệt khép kỳ có chênh lệch) | ❌ | ❌ |
| Phê duyệt phương án migrate + cutoff legacy | ❌ | ❌ | ✅ | ❌ | ❌ |
| Thực thi migrate/dry-run | ❌ | ✅ (theo phương án duyệt) | ❌ | ✅ (thực thi kỹ thuật sau duyệt CTO) | ✅ |
| Sửa connection profile/field mapping/credentials | ❌ | ❌ | ✅ (phê duyệt — vai CTO) | ✅ (thực thi sau duyệt, MFA bắt buộc) | ✅ |
| Thu hồi khẩn connector (nghi ngờ rò rỉ) | ❌ | ❌ | ✅ | ✅ (thực thi ngay sau lệnh CTO) | ✅ |

SYS_ADMIN không tự gán quyền kể cả cho mình; thay đổi cấu hình connector luôn đi theo trình tự "CTO phê duyệt → SYS_ADMIN thực thi → kiểm tra sức khỏe" với audit log immutable từng bước.

---

## 5. Trường Hợp Đặc Biệt

- VAS chỉ hỗ trợ import/export file (không có API): GW xuất file chuẩn schema theo template cấu hình, log từng lượt xuất; FIN_L1 import thủ công trên VAS và xác nhận nạp trên web để đối chiếu biết "lô đã vào sổ" — trạng thái degraded hiển thị rõ cho cả nhóm.
- Tên VAS chưa chốt ở thời điểm thiết kế (DI-004): connector thiết kế theo profile cắm được; khi triển khai chốt vendor, chỉ cấu hình profile/mapping mới — không thay đổi luồng nghiệp vụ; nếu đổi VAS trong tương lai, migration config tương tự.
- Đổi phần mềm kế toán giữa chừng (nếu xảy ra): connection profile mới chạy song song một kỳ đối chiếu với profile cũ trước khi cắt hẳn; dữ liệu đã đồng bộ kỳ cũ giữ nguyên để truy vết.
- Migration phát hiện dữ liệu legacy bẩn (trùng master data, payment history thiếu chuỗi): dry-run báo cáo bẩn chi tiết — nhóm lỗi đưa vào danh sách làm sạch thủ công có duyệt, không migrate "nguyên trạng" làm lệch số mở đầu.
- Sau cutoff, phát hiện giao dịch legacy bị bỏ sót cần bổ sung: nhập mới trên BCERP có nhãn "dữ liệu bổ sung từ legacy" + phiếu duyệt; legacy vẫn read-only — không mở lại ghi trên legacy dưới mọi hình thức.
- Chênh lệch đối chiếu do chênh tỷ giá quy VND giữa BCERP và VAS: phân loại riêng "chênh tỷ giá" trong giải trình, xử lý theo nghiệp vụ kế toán chênh lệch tỷ giá — không trộn với chênh lệch giao dịch.
- Connector fail kéo dài qua mốc chốt tháng: kích hoạt quy trình degraded có kiểm soát (export/import tay theo template + xác nhận kép FIN_L2); kỳ vẫn chốt được nhưng báo cáo gắn nhãn "đồng bộ thủ công có kiểm soát" để audit biết biện pháp thay thế.
- Nghi ngờ rò rỉ credentials connector: thu hồi khẩn ngay theo REQ-BOD-008, connector chuyển trạng thái ngừng kết nối; luồng chuyển degraded tay cho đến khi rotate xong và kiểm tra sức khỏe lại.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Sync Job (lượt đồng bộ/đối chiếu) và Migration Batch (lô migrate legacy) — hai entity chính của tính năng này.

**Sơ đồ trạng thái:**
```
Sync Job:
[PENDING] ──(runner nhận)──► [RUNNING] ──(thành công)──► [SUCCESS] ──(đối chiếu khép)──► [RECONCILED]
                                │
                                ├─(lỗi tạm thời)──► [RETRY_WAITING] ──(retry)──► về [RUNNING]
                                └─(lỗi kéo dài / VAS ngắt)──► [DEGRADED_MANUAL] ──(nạp tay xác nhận kép)──► [RECONCILED]

Migration Batch:
[PLANNED] ──(duyệt phương án CFO/CTO)──► [DRY_RUN] ──(PASS)──► [MIGRATING] ──(xong)──► [VERIFYING] ──(đối soát đạt)──► [CUTOFF_DONE]
                                              │ (FAIL: báo cáo dữ liệu bẩn)             │ (FAIL)
                                              ▼                                        ▼
                                         [CLEANUP_NEEDED] ──(làm sạch có duyệt)──► về [DRY_RUN]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `PENDING` | Runner nhận | `RUNNING` | Hệ thống | Profile active; credentials hợp lệ trong vault |
| `RUNNING` | Thành công | `SUCCESS` | Hệ thống | Số bút toán/nhật ký sync ghi đầy đủ |
| `RUNNING` | Lỗi tạm thời | `RETRY_WAITING` | Hệ thống | Theo chính sách retry; alert sau N lần fail |
| `RETRY_WAITING` | Retry | `RUNNING` | Hệ thống | Kết nối hồi phục |
| `RUNNING` | Fail kéo dài | `DEGRADED_MANUAL` | Hệ thống + FIN_L2 xác nhận | Chuyển quy trình tay có kiểm soát; nhãn rõ trên báo cáo |
| `SUCCESS` | Đối chiếu khép | `RECONCILED` | FIN_L2 | Không còn chênh lệch chưa giải trình |
| `PLANNED` | Duyệt phương án | `DRY_RUN` | BOD_CFO_CTO + CTO | Phạm vi: master data + dự án active + payment history 12 tháng |
| `DRY_RUN` | PASS | `MIGRATING` | SYS_ADMIN thực thi | Báo cáo dry-run đạt; danh sách exception đã xử lý |
| `MIGRATING` | Xong | `VERIFYING` | Hệ thống | Đối soát số lượng/checksum từng nhóm dữ liệu |
| `VERIFYING` | Đạt | `CUTOFF_DONE` | BOD_CFO_CTO ký | Legacy chuyển read-only; thông báo toàn FIN |

**Quy tắc:**
- `CUTOFF_DONE` và `RECONCILED` là trạng thái kết thúc chu kỳ; không quay lại — chu kỳ sau tạo job/batch mới.
- `DEGRADED_MANUAL` không tự hết — chỉ thoát khi sync tự động phục hồi và một chu kỳ SUCCESS liên tiếp được xác nhận.
- Mọi chuyển trạng thái ghi log immutable ở core/GW; web hiển thị đúng machine-state, không tự đánh giá "thành công" phía client.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| ConnectionProfile (MOD-SETTINGS-GW sở hữu) | `vendor_ref`, `mode` (API/import-export), `mapping_ref`, `status` | Được tham chiếu bởi sync job | Vendor-agnostic; secret nằm vault GW |
| SyncJob | `id`, `profile_id`, `period`, `direction`, `status`, `stats`, `log_ref` | FK → connection profile | Chỉ chạy trên dữ liệu đã duyệt |
| ReconciliationBatch | `id`, `period`, `matched`, `diffs[]`, `closed_at` | FK → sync jobs | Chênh lệch phải có giải trình FIN_L2 |
| DiscrepancyItem | `batch_id`, `voucher_ref`, `amount_delta`, `reason`, `resolution`, `due_date` | FK → reconciliation batch | Trạng thái mở/khép riêng từng item |
| MigrationBatch | `id`, `scope` (master/projects/payment-12m), `dry_run_report`, `status` | FK → legacy refs | Cutoff → legacy read-only |
| JournalExport (tham chiếu) | `voucher_id`, `entry_snapshot`, `version` | FK → chứng từ đã duyệt | Snapshot bất biến để đối chiếu |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn xuất chứng từ nháp | Lô xuất chứa 1 chứng từ chờ duyệt | FIN_L1 chạy xuất | Chứng từ nháp bị loại; lô chỉ xuất phần đã duyệt; cảnh báo liệt kê phần bị loại | [ ] |
| SC-002: Đối chiếu phát hiện chênh lệch | Sổ VAS tháng 08 lệch 2 bút toán | Chạy đối chiếu | 2 discrepancy item tạo với trạng thái mở; báo cáo chốt kỳ gắn cảnh báo cho đến khi khép | [ ] |
| SC-003: Migration đúng phạm vi | Legacy PMS có payment history 25 tháng | DRY_RUN | Chỉ 12 tháng gần nhất vào lô migrate; phần còn lại ghi nhận archive; báo cáo dry-run thể hiện rõ | [ ] |
| SC-004: Legacy read-only sau cutoff | Đã CUTOFF_DONE | Cố ghi dữ liệu về legacy | Bị chặn; mọi tham chiếu đọc từ BCERP; attempt được log | [ ] |
| SC-005: Degraded manual có kiểm soát | API VAS ngắt 2 ngày | Chuyển export file tay | File đúng template, log lượt xuất, xác nhận nạp kép FIN_L2; báo cáo gắn nhãn thủ công | [ ] |
| SC-006: Secret không lộ UI | SYS_ADMIN xem console connector | Mở chi tiết profile | Không có plaintext credential ở bất kỳ màn hình/log nào; chỉ thấy trạng thái + ngày rotate | [ ] |
| SC-007: Hard Stop trước khi xuất | Bút toán liên quan giải ngân TKQC chưa khớp tiền | Thêm vào lô xuất | Bị loại với lý do "chưa thỏa Hard Stop"; không vào sổ VAS | [ ] |

> **Liên kết:** SC-001…SC-007 map về REQ-FIN-013 (Mục 2 — adapter GW, đối chiếu sổ, migrate chọn lọc, degraded mode).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/arap-payment/vas-connector.md` |
| Bản fan-out counterpart | `phase2-features/integration-gw/arap-payment/` (adapter/vault/retry), `phase2-features/core-backend/arap-payment/` (bút toán chuẩn), `phase2-features/bcerp-web/settings-gw/` (REQ-BOD-008 console) |
