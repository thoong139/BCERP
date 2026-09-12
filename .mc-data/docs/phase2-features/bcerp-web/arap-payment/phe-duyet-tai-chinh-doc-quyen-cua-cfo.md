# Tính Năng: Phê duyệt tài chính độc quyền của CFO

> **Dựa trên:** REQ-BOD-010 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** Tài chính — Công nợ & Thanh toán (MOD-ARAP-PAYMENT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-ARAP-002 |
| Module | MOD-ARAP-PAYMENT |
| Yêu cầu nghiệp vụ | REQ-BOD-010 — Phê duyệt tài chính độc quyền của CFO (MEDIUM, MVP → Phase2) |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Trung bình |
| Giai đoạn | Giai đoạn 1 (MVP — hạn mức tín dụng TKQC) → Giai đoạn 2 (period unlock, gắn đối soát GĐ2) |
| Phụ thuộc | Không có cross-dependency ngoài module; enforcement dựa nền tảng RBAC (REQ-BOD-011) và trạng thái khóa kỳ từ đối soát (REQ-FIN-004) |
| Ghi chú Expert (A7) | Team Expert (bod.md Mục A7) xác nhận nhóm lệnh tài chính độc quyền chỉ CFO có, tần suất thấp → chỉ web, không requirement riêng cho mobile; chi tiết điều chỉnh tại Phần B (BR-BOD-010.1–010.4) |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng cung cấp trên web nội bộ nhóm màn hình duyệt dành riêng cho CFO với ngữ cảnh đầy đủ (kỳ số liệu, chênh lệch đối soát, lý do bắt buộc), bao gồm: duyệt hạn mức tín dụng TKQC theo nền tảng/khách, mở lại kỳ kế toán đã khóa, duyệt backfill/điều chỉnh M2 và đồng quyết với CEO sự cố M3/cảnh báo đỏ trong 4h. Nhóm lệnh này được core enforce cứng là CFO-only — mọi vai khác gọi API đều bị từ chối và log — nhằm bảo đảm trách nhiệm tài chính cuối cùng tập trung ở một người, không phân mảnh, không ủy quyền.

**Phạm vi:**
- Bao gồm: workspace web "Lệnh tài chính CFO" — danh sách lệnh chờ (hạn mức tín dụng, mở kỳ, backfill, quyết M3), form duyệt với ngữ cảnh đầy đủ: kỳ số liệu liên quan, chênh lệch đối soát hiện tại, đề xuất từ FIN_L2 và ô lý do bắt buộc.
- Bao gồm: màn duyệt hạn mức tín dụng TKQC theo nền tảng/khách với hiệu lực effective-dated, version hóa và lịch sử duyệt.
- Bao gồm: luồng mở lại kỳ kế toán đã khóa (FIN_L2 đề xuất → CFO duyệt) và nhắc "chốt lần hai có ghi nhận" sau khi xử lý xong.
- Bao gồm: màn duyệt backfill/điều chỉnh M2 trong 1 ngày làm việc, hiển thị ai sửa, giá trị trước/sau, lý do; cùng màn đồng quyết M3/cảnh báo đỏ với CEO trong 4h (CEO ký trên web, mobile chỉ nhận push).
- Bao gồm: hiển thị machine-state từng lệnh (đề xuất → chờ CFO → đã duyệt/treo/từ chối → đã thực thi/đã chốt lần hai) đúng như API core trả về.
- Không bao gồm: enforcement vai CFO-only và log bất biến — thực thi tại SYS-CORE-BACKEND service layer; web chỉ ẩn/hiện menu theo quyền và hiển thị lỗi từ chối do core trả về.
- Không bao gồm: bản di động (REQ-BOD-010 không có requirement riêng — tần suất thấp, thực hiện trên web; SYS-MOBILE-INTERNAL chỉ nhận push thông báo quyết M3).
- Không bao gồm: bản thân giao dịch điều chỉnh số dư/đổi tỷ giá/hoàn tiền (dual approval ví — REQ-FIN-003) và duyệt chi thường (FEAT-ERP-ARAP-004); tính năng này chỉ sở hữu 4 nhóm lệnh độc quyền nêu trên.

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-BCERP-WEB — web nội bộ responsive; mọi lệnh duyệt ghi kênh thao tác và lý do vào audit log bất biến ở core.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CFO_CTO | Duyệt hạn mức tín dụng TKQC theo từng nền tảng/khách trên một màn hình có lịch sử hạn mức đã cấp | Kiểm soát tổng rủi ro tín dụng cấp cho khách, tránh cấp trùng hoặc vượt trần theo nền tảng |
| 2 | BOD_CFO_CTO | Mở lại kỳ kế toán đã khóa với form yêu cầu: kỳ cần mở, lý do bắt buộc, phạm vi (khách/chứng từ) | Xử lý điều chỉnh hợp lệ sau chốt mà vẫn để lại vết duyệt rõ ràng, không ai khác mở được |
| 3 | FIN_L2 | Gửi đề xuất mở kỳ/backfill lên CFO kèm hồ sơ chênh lệch đối soát | Điều chỉnh được số liệu sai sau chốt theo đúng trình tự — chỉ CFO mới có quyền duyệt |
| 4 | BOD_CFO_CTO | Duyệt backfill/điều chỉnh M2 trong 1 ngày làm việc, thấy ai sửa, giá trị trước/sau, lý do | Quyết toán lại số liệu cũ phục vụ kiểm toán mà không đụng bản ghi gốc |
| 5 | BOD_CEO | Tham gia đồng quyết sự cố M3/cảnh báo đỏ cùng CFO trong 4h trên web | Hai người đứng đầu cùng chịu trách nhiệm quyết định khẩn, mobile chỉ là kênh báo động |
| 6 | SYS_ADMIN | Cấp/thu hồi quyền truy cập workspace CFO-only sau phê duyệt, không can thiệp nội dung lệnh | Vai thực thi đúng biên — không tự gán quyền kể cả cho mình, không thao tác thay CFO |
| 7 | BOD_CFO_CTO | Xem danh sách lệnh bị treo khi mình vắng mặt (không ủy quyền được) và xử lý từ xa khi quay lại | Minh bạch phần tồn đọng, không ai "duyệt hộ" lệnh độc quyền |

Toàn bộ các story trên đi theo nguyên tắc: web là mặt làm việc, core là nơi enforce. Khi CFO vắng, lệnh treo đúng nguyên tắc "không ủy quyền lệnh độc quyền (kể cả cho CEO)" — luồng chỉ tiếp tục khi CFO thao tác từ xa.

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Enforcement CFO-only nằm ở service layer SYS-CORE-BACKEND; web không có đường tắt UI nào né luật.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | CFO-only enforcement: duyệt hạn mức tín dụng TKQC, mở lại kỳ đã khóa, duyệt backfill/điều chỉnh M2 chỉ role BOD_CFO_CTO thực thi được; lệnh đi kèm log + lý do bắt buộc. | Vai khác gọi API bị core từ chối; mọi attempt (kể cả CEO, SYS_ADMIN) được log immutable |
| BR-002 | Lệnh độc quyền CFO không ủy quyền — kể cả cho CEO; CFO vắng → lệnh treo đến khi CFO thao tác từ xa; không tồn tại delegate cho nhóm lệnh này. | Nút/tham số delegate không hiển thị; yêu cầu ủy quyền bị core từ chối + log |
| BR-003 | Financial Hard Stop "đã khớp tiền" (FIN_L1, WEB + MFA TOTP) là điều kiện tiên quyết của mọi giải ngân liên quan TKQC; hạn mức tín dụng được duyệt không thay thế điều kiện khớp tiền — hai gate độc lập, đều phải thỏa. | Giải ngân trước khi khớp tiền bị chặn cứng + audit log bất biến, kể cả khi hạn mức đã được CFO duyệt |
| BR-004 | Kỳ mở lại phải chốt lần hai có ghi nhận: sau khi CFO duyệt mở kỳ và FIN xử lý xong, luồng bắt buộc bước chốt lại kỳ lần 2 kèm người/chừng thời điểm/lý do. | Kỳ ở trạng thái "đã mở" quá lâu không chốt lần hai phát cảnh báo cho CFO; báo cáo không nhận kỳ ở trạng thái mở |
| BR-005 | Cấm sửa đè không vết: điều chỉnh luôn qua giao dịch ngược (reversal) có reason code; backfill ghi ai sửa, giá trị trước/sau, lý do — không hard-delete, không UPDATE đè. | Yêu cầu sửa trực tiếp bản ghi gốc bị core từ chối; web chỉ đọc bản ghi gốc + bản reversal |
| BR-006 | Quyết toán lại quý cũ phục vụ kiểm toán đi qua backfill có phê duyệt (CFO duyệt trong 1 ngày làm việc), không đụng bản ghi gốc; điều chỉnh M3/cảnh báo đỏ do CFO cùng BOD_CEO quyết trong 4h. | Điều chỉnh ngoài luồng backfill không được ghi nhận vào sổ; quyết M3 quá 4h phát alert đỏ cho cả hai |
| BR-007 | SoD 4 vai dòng tiền (đề xuất ≠ khớp tiền ≠ duyệt chi ≠ ghi sổ) áp dụng cho chuỗi hình thành lệnh: FIN_L2 đề xuất mở kỳ/backfill, CFO duyệt, FIN_L1 ghi sổ — CFO không tự đề xuất rồi tự duyệt cùng một lệnh trong cùng luồng. | Core block khi phát hiện vai trùng trong chuỗi; vi phạm SoD log cho rà soát định kỳ |
| BR-008 | Dữ liệu cho quyết định phải là nguồn sự thật: chênh lệch đối soát hiển thị trong ngữ cảnh duyệt lấy trực tiếp từ đối trừ 3 số (REQ-FIN-004) và ledger ví (REQ-FIN-001); dữ liệu degraded mode gắn nhãn "manual" kèm timestamp. | Ngữ cảnh duyệt không được dùng số nội suy/tổng hợp tay; thiếu nguồn → web hiển thị "không đủ căn cứ duyệt" |
| BR-009 | Hạn mức tín dụng effective-dated: mỗi lần duyệt tạo version mới với ngày hiệu lực, người duyệt, không hồi tố sửa quá khứ; báo cáo dùng đúng version hiệu lực tại thời điểm dữ liệu. | Yêu cầu sửa version đã hiệu lực bị từ chối — chỉ tạo version mới có hiệu lực tương lai |
| BR-010 | Connector phần mềm kế toán VAS: cấu hình kết nối ngoại vi trong Settings (MOD-SETTINGS-GW, DI-004 ngày 12/09) — vendor-agnostic, import/export chuẩn + adapter API; legacy PMS migrate chọn lọc (master data + dự án active + payment history 12 tháng) + legacy read-only; kỳ mở lại/backfill sau khi đồng bộ VAS phải phản ánh nhất quán cả hai phía sổ. | Chênh lệch BCERP ↔ VAS sau điều chỉnh tạo discrepancy ticket bắt buộc giải trình FIN_L2 |
| BR-011 | Hóa đơn điện tử TT78/2021 + NĐ123/2020 chỉ phát hành trên doanh thu từ chứng từ đã khóa kỳ; mở kỳ/backfill ảnh hưởng chứng từ đã phát hành HĐĐT phải đi kèm nghiệp vụ điều chỉnh/thay thế hóa đơn chuẩn, không xóa/sửa XML đã phát hành. | Nghiệp vụ điều chỉnh thiếu hóa đơn điều chỉnh/biên bản bị chặn trước khi chốt lần hai |
| BR-012 | Phí nền tảng hạch toán vào giá vốn theo giao dịch gốc, nghĩa vụ thuế (VAT/FCT) theo cấu hình thuế có phê duyệt; lệnh backfill chạm dữ liệu phí/thuế phải kèm đối chiếu nghĩa vụ thuế cập nhật. | Backfill làm lệch nghĩa vụ thuế không cho phép chốt lần hai; tạo ticket thuế bắt buộc xử lý trước |

---

## 4. Phân Quyền

Quyền thực chất do RBAC engine của core kiểm tra tại API; bảng dưới là hợp đồng UI web nội bộ phải tuân thủ. Nhóm lệnh độc quyền không ủy quyền, không có bản mobile.

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN | FIN_L2 | FIN_L1 |
|-----------|---------|-------------|-----------|--------|--------|
| Xem workspace lệnh CFO (theo phạm vi) | ✅ (đồng quyết M3) | ✅ | ❌ | ✅ (lệnh mình đề xuất) | ✅ (read-only liên quan ghi sổ) |
| Duyệt hạn mức tín dụng TKQC | ❌ | ✅ (độc quyền) | ❌ | ❌ (chỉ đề xuất) | ❌ |
| Mở lại kỳ kế toán đã khóa | ❌ | ✅ (độc quyền) | ❌ | ✅ (gửi đề xuất) | ❌ |
| Duyệt backfill/điều chỉnh M2 | ❌ | ✅ (trong 1 ngày LV) | ❌ | ✅ (gửi đề xuất) | ❌ |
| Đồng quyết sự cố M3/cảnh báo đỏ | ✅ (cùng CFO, 4h) | ✅ | ❌ | ❌ | ❌ |
| Chốt lần hai kỳ đã mở | ❌ | ✅ (ký xác nhận) | ❌ | ✅ (thực hiện chốt) | ✅ (cập nhật sổ) |
| Ủy quyền lệnh độc quyền | ❌ | ❌ (bị chặn) | ❌ | ❌ | ❌ |
| Gán/thu hồi quyền workspace | ✅ (phê duyệt) | ✅ (đề xuất) | ✅ (thực thi sau duyệt) | ❌ | ❌ |

SYS_ADMIN không tự gán quyền kể cả cho chính mình — chỉ thực thi sau phê duyệt; mọi attempt truy cập API CFO-only từ vai khác đều bị log immutable để CFO/BOD rà định kỳ.

---

## 5. Trường Hợp Đặc Biệt

- CFO vắng mặt dài ngày: toàn bộ lệnh độc quyền treo có nhãn rõ ràng "chờ CFO"; nếu trùng khủng hoảng M3, CEO nhận push và hai người xử lý từ xa — hệ thống không mở cơ chế duyệt hộ cho bất kỳ vai nào.
- Quyết toán lại quý cũ phục vụ kiểm toán: mọi điều chỉnh đi qua backfill có phê duyệt; bản ghi gốc giữ nguyên, báo cáo kiểm toán đọc được cả giá trị trước/sau và reason code của từng lần backfill.
- Backfill chạm chứng từ đã phát hành HĐĐT: luồng bắt buộc xử lý song song nghiệp vụ hóa đơn điều chỉnh/thay thế theo TT78/2021 + NĐ123/2020 trước khi cho phép chốt lần hai; web hiển thị checklist hai việc này ràng buộc nhau.
- Kỳ mở lại nhưng phát hiện phạm vi đề xuất chưa đủ (thiếu khách/chứng từ liên quan): CFO có thể duyệt mở với phạm vi hẹp hơn đề xuất, ghi lý do; phần mở rộng cần đề xuất bổ sung của FIN_L2 — không tự ý mở toàn bộ kỳ.
- Tranh chấp chênh lệch đối soát khi duyệt hạn mức: nếu ngữ cảnh hiển thị discrepancy chưa giải trình, web cảnh báo "căn cứ chưa sạch"; CFO vẫn duyệt được nhưng lệnh ghi nhận rõ việc duyệt trên dữ liệu có chênh lệch tồn — tăng trách nhiệm giải trình sau này.
- Hệ thống đối soát đang degraded mode (dữ liệu "manual"): lệnh duyệt vẫn hoạt động nhưng ngữ cảnh hiển thị nhãn nguồn + timestamp dữ liệu hợp lệ cuối; không nội suy số ẩn để "cho đủ căn cứ".
- Người dùng kiêm nhiệm CFO kiêm CTO thao tác lệnh: hệ thống vẫn yêu cầu MFA step-up và ghi nhận vai thực thi; compensating control (CEO duyệt giao dịch do CFO khởi tạo) của REQ-BOD-002 áp dụng song song cho giao dịch tiền vượt ngưỡng, tách bạch với nhóm lệnh độc quyền này.
- Xuất dữ liệu lệnh phục vụ audit: xuất ngoài báo cáo chuẩn cần phê duyệt BOD_CEO (theo REQ-BOD-005); web chỉ mở kênh xuất sau khi có phê duyệt.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Lệnh tài chính CFO (CFO Financial Command — gồm 4 loại: hạn mức tín dụng, mở kỳ, backfill, quyết M3).

**Sơ đồ trạng thái:**
```
[PROPOSED] ──(submit FIN_L2)──► [PENDING_CFO] ──(CFO duyệt)──► [APPROVED] ──(thực thi FIN)──► [EXECUTED]
                                    │                                │
                                    │ (CFO từ chối)                  │ (riêng mở kỳ)
                                    ▼                                ▼
                                [REJECTED]                      [PERIOD_REOPENED] ──(chốt lần hai)──► [RECLOSED]
[PENDING_CFO] ──(CFO vắng, không delegate)──► [SUSPENDED] ──(CFO thao tác từ xa)──► [PENDING_CFO]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `PROPOSED` | Submit | `PENDING_CFO` | FIN_L2 | Đủ hồ sơ: kỳ/phạm vi, chênh lệch đối soát, lý do đề xuất |
| `PENDING_CFO` | Approve | `APPROVED` | BOD_CFO_CTO (độc quyền) | Reason code bắt buộc; MFA step-up |
| `PENDING_CFO` | Reject | `REJECTED` | BOD_CFO_CTO | Reason code bắt buộc |
| `PENDING_CFO` | Treo (không delegate) | `SUSPENDED` | Hệ thống/CFO | CFO vắng; nhãn "chờ CFO thao tác" |
| `APPROVED` | Thực thi | `EXECUTED` | FIN (ghi sổ ≠ duyệt) | Áp dụng theo loại lệnh (hạn mức hiệu lực tương lai) |
| `APPROVED` (mở kỳ) | Mở kỳ | `PERIOD_REOPENED` | FIN_L2 (thực hiện) | Ghi nhận người mở, phạm vi, thời điểm |
| `PERIOD_REOPENED` | Chốt lần hai | `RECLOSED` | CFO ký + FIN_L2 chốt | Đủ điều chỉnh/reversal; xử lý HĐĐT liên quan xong |
| `APPROVED` (backfill) | Thực hiện | `EXECUTED` | FIN (trong 1 ngày LV) | Ghi ai sửa, trước/sau, lý do; bản gốc không đổi |

**Quy tắc:**
- `RECLOSED`, `REJECTED` là trạng thái kết thúc; kỳ đã `RECLOSED` xem như chốt bình thường, mở lại tiếp phải tạo lệnh mới.
- `SUSPENDED` không có thời hạn tự đóng — duy trì cảnh báo cho CFO đến khi xử lý; không ai khác chuyển trạng thái thay.
- Mọi chuyển trạng thái ghi audit log bất biến kèm kênh thao tác (web) và reason code.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| CFOCommand | `id`, `type` (credit_limit/period_reopen/backfill/M3_decision), `scope`, `status`, `reason_code` | FK → `users` (đề xuất/duyệt) | Chỉ role CFO được approve ở API |
| CreditLimitVersion | `platform`, `client_id`, `limit_amount`, `effective_from`, `approved_by` | FK → `cfo_command.id`; FK → khách/nền tảng | Effective-dated, version hóa, không hồi tố |
| PeriodLock | `period`, `status` (OPEN/LOCKED/REOPENED/RECLOSED), `reopened_by`, `reclosed_by` | FK → `cfo_command.id` | Chốt lần hai bắt buộc có ghi nhận |
| BackfillRecord | `target_record`, `before_value`, `after_value`, `reason_code`, `executed_by` | FK → bản ghi gốc (read-only) | Giao dịch ngược, không UPDATE đè |
| AuditLog (tham chiếu) | `object`, `old_value`, `new_value`, `reason_code`, `channel` | Append-only, hash-chain | Bất biến; xem log cũng bị log |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn vai không phải CFO | FIN_L2 đăng nhập web | Gọi trực tiếp API duyệt mở kỳ | Core trả 403 + log attempt immutable; UI không hiển thị nút duyệt | [ ] |
| SC-002: Mở kỳ → chốt lần hai | Kỳ 08/2026 đã khóa, có chênh lệch chưa giải trình | CFO duyệt mở, FIN xử lý, chốt lại | Trạng thái `RECLOSED`; lịch sử mở/chốt đầy đủ người + lý do | [ ] |
| SC-003: Backfill có vết | Cần điều chỉnh số liệu quý cũ phục vụ kiểm toán | CFO duyệt backfill trong 1 ngày LV | Bản gốc không đổi; bản ghi before/after + reason hiển thị được cho audit | [ ] |
| SC-004: Không ủy quyền lệnh độc quyền | CFO nghỉ phép 5 ngày | SYS_ADMIN thử cấu hình delegate cho lệnh CFO | Core từ chối; lệnh giữ `SUSPENDED` đến khi CFO thao tác từ xa | [ ] |
| SC-005: Đồng quyết M3 trong 4h | Cảnh báo đỏ M3 phát sinh 14:00 | CFO + CEO ký trên web trước 18:00 | Quyết định ghi nhận đủ 2 chữ ký + lý do; mobile chỉ nhận push | [ ] |
| SC-006: Hard Stop độc lập với hạn mức | Khách còn hạn mức tín dụng CFO duyệt, lệnh nạp chưa khớp tiền | Yêu cầu giải ngân TKQC | Bị chặn do thiếu xác nhận "đã khớp tiền" của FIN_L1 dù hạn mức hợp lệ | [ ] |

> **Liên kết:** SC-001…SC-006 map về REQ-BOD-010 (Mục 2 — hạn mức tín dụng, mở kỳ, backfill/M2, đồng quyết M3).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/arap-payment/cfo-command-workspace.md` |
| Bản fan-out counterpart | `phase2-features/core-backend/arap-payment/` (enforcement CFO-only) |
