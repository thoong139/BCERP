# Tính Năng: HĐLĐ & cảnh báo hết hạn 90/60/30 ngày

> **Dựa trên:** REQ-HR-002 trong `phase1-business/departments/hr/hr.md` (Phần A)
> **Phân hệ:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** Nhân sự — Lõi HR (MOD-HR-CORE)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/hr/hr.md`, `documents/03_Quy_che_KPI_HR.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/hr-core/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/hr-core/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID tạo từ REQ-ID theo `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`; REQ-HR-002 → FEAT-ERP-HRCORE-002. Đây là bản fan-out cho touchpoint SYS-BCERP-WEB; bản counterpart (job quét hằng ngày + mã hóa file scan ở service layer) nằm tại lane SYS-CORE-BACKEND.

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-HRCORE-002 |
| Module | MOD-HR-CORE |
| Yêu cầu nghiệp vụ | REQ-HR-002 — HĐLĐ & cảnh báo hết hạn 90/60/30 ngày (HIGH, MVP) |
| Người dùng liên quan | HR_L1 (nhập), HR_L2 (quản trị + nhận cảnh báo), BOD_CEO (escalation quá hạn), TL (nhận cảnh báo nhân sự nhóm) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP) |
| Phụ thuộc | FEAT-ERP-HRCORE-001 (hồ sơ nhân sự SSOT — HĐLĐ gắn vào hồ sơ, trạng thái thử việc/chính thức điều khiển luồng ký HĐ chính thức) |
| Ghi chú Expert (A7) | Team Expert (hr.md Mục A7.2) xác nhận touchpoint chính là màn hình HR trên web + job nhắc; need mobile chỉ nhận thông báo, không thao tác — nằm ngoài scope SYS-MOBILE-INTERNAL hiện tại |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Tính năng quản lý vòng đời hợp đồng lao động của nhân sự BC Agency trên web nội bộ: lưu hồ sơ HĐLĐ (loại, số, ngày ký, hiệu lực, hết hạn, nội dung chính, file scan) và tự động cảnh báo hết hạn theo 3 mốc 90/60/30 ngày cho HR_L2 và TL. Mục tiêu pháp lý là không để một hợp đồng xác định thời hạn nào "chạy quá hạn chưa tái ký" — tình huống rủi ro pháp lý cao — bằng cơ chế nhắc theo cấp độ, dashboard đỏ và escalation BOD theo tuần.

**Phạm vi:**
- Bao gồm: web form nhập/sửa HĐLĐ gắn hồ sơ nhân sự, upload file scan (mã hóa C1), danh mục loại hợp đồng (thử việc, xác định thời hạn, không xác định thời hạn), dashboard cảnh báo HR_L2 với 3 vùng 90/60/30 ngày và vùng đỏ quá hạn.
- Bao gồm: hiển thị thông báo nhắc theo mốc (90 ngày: quyết định ký tiếp hay không; 60 ngày: chuẩn bị hồ sơ tái ký; 30 ngày: phải chốt phương án) cho cả HR_L2 và TL trực tiếp của nhân sự liên quan.
- Bao gồm: luồng tái ký (tạo bản ghi HĐ mới nối tiếp, HĐ cũ giữ nguyên lịch sử), luồng chấm dứt giữa hạn (ghi căn cứ pháp lý + file quyết định), flag tắt nhắc cho HĐ không xác định thời hạn.
- Bao gồm: màn hình đánh giá hết thử việc trước khi kết thúc thử việc ≥3 ngày — đạt mới mở luồng ký HĐLĐ chính thức (nối checklist onboarding của FEAT-ERP-HRCORE-001).
- Không bao gồm: job quét hằng ngày và mã hóa/giải mã file scan — chạy ở SYS-CORE-BACKEND; web chỉ nhận kết quả quét và hiển thị trạng thái machine-state.
- Không bao gồm: ký điện tử HĐLĐ (e-sign theo Luật GDTĐT 2023 thuộc luồng khác), tính lương/thưởng theo loại hợp đồng (payroll của DEPT-FINANCE), và nội dung biểu mẫu hợp đồng (danh mục 44 template HR trong `documents/03_Quy_che_KPI_HR.md` là tham chiếu, không quản lý văn bản trong BCERP).

---

## 2. Luồng Người Dùng (User Stories)

Luồng mô tả theo touchpoint SYS-BCERP-WEB — web nội bộ responsive; job quét chạy ở core mỗi ngày, web là nơi HR_L2 hành động trên kết quả cảnh báo.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | HR_L1 | Nhập HĐLĐ (loại, số, ngày ký, hiệu lực, hết hạn) và upload file scan ngay khi ký | Hồ sơ pháp lý đầy đủ, file scan được mã hóa và gắn đúng nhân sự |
| 2 | HR_L2 | Nhận cảnh báo 90/60/30 ngày trên dashboard theo từng nhân sự | Có đủ thời gian quyết định ký tiếp, chuẩn bị và chốt phương án trước khi hết hạn |
| 3 | TL | Nhận thông báo HĐLĐ nhân sự nhóm mình sắp hết hạn cùng mốc HR_L2 | Chủ động trao đổi với nhân sự về ý định tiếp tục trước khi HR chốt |
| 4 | HR_L2 | Thấy vùng đỏ "quá hạn chưa tái ký" trên dashboard với nhãn rủi ro pháp lý | Ưu tiên xử lý ngay các trường hợp rủi ro cao nhất, theo dõi đến khi khép lại |
| 5 | HR_L2 | Đánh dấu HĐ không xác định thời hạn để tắt nhắc | Dashboard không nhiễu bởi các hợp đồng không cần tái ký |
| 6 | HR_L2 | Đánh giá hết thử việc trước ngày kết thúc ≥3 ngày và mở luồng ký HĐ chính thức khi đạt | Không sót trường hợp thử việc hết mà chưa đánh giá; đạt mới ký HĐLĐ chính thức |
| 7 | HR_L2 | Tạo bản ghi tái ký nối tiếp bản cũ, giữ nguyên lịch sử | Truy vết được chuỗi hợp đồng của từng nhân sự theo thời gian |
| 8 | BOD_CEO | Nhận escalation theo tuần về các HĐ quá hạn chưa xử lý | Lãnh đạo biết rủi ro pháp lý tồn đọng và đôn đốc khép lại |

Quy ước xuyên suốt: nội dung file scan và số HĐ là dữ liệu C1 — chỉ HR_L2 mở được bản gốc, mọi lượt mở có audit log; thông báo gửi TL không kèm file scan.

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Job quét và mã hóa chạy ở service layer SYS-CORE-BACKEND; web hiển thị đúng trạng thái và không cho thao tác ngoài luồng.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Hồ sơ nhân sự L1–L5 + mã vai là SSOT: HĐLĐ phải gắn profile_id hợp lệ, loại HĐ và trạng thái nhân sự (thử việc/chính thức) đọc từ FEAT-ERP-HRCORE-001; nguồn domain chi tiết `documents/03_Quy_che_KPI_HR.md` (HR v3.9, 4 track Sales/Business Ops/HCNS/Marketing-Creative). | Không tạo được HĐLĐ rời hồ sơ; ký HĐ chính thức cho trạng thái chưa đạt thử việc bị chặn |
| BR-002 | Cảnh báo hết hạn 3 mốc 90/60/30 ngày cho HR_L2 + TL, sinh từ job quét hằng ngày ở core: 90 = quyết định ký tiếp, 60 = chuẩn bị, 30 = chốt phương án; HĐ xác định thời hạn quá hạn chưa tái ký → cảnh báo đỏ + escalate BOD theo tuần đến khi xử lý. | HĐ lọt qua 30 ngày không có phương án → chuyển đỏ, tăng mức escalation; dashboard HR_L2 không được ẩn vùng đỏ |
| BR-003 | HĐ không xác định thời hạn gắn flag "tắt nhắc" — không sinh cảnh báo hết hạn; mở lại nhắc chỉ khi HR_L2 bỏ flag kèm lý do. | HĐ không xác định thời hạn xuất hiện trên cảnh báo là lỗi cấu hình; hệ thống tự loại khỏi hàng đợi |
| BR-004 | Đánh giá hết thử việc phải hoàn thành trước khi kết thúc thử việc ≥3 ngày; đạt mới ký HĐLĐ chính thức (mốc 30/60 theo quy trình HR v3.9: PASS / gia hạn 30 ngày kèm PIP / STOP). | Ký HĐ chính thức trước khi có kết luận đánh giá bị chặn; quá mốc không đánh giá phát cảnh báo cho HR_L2 |
| BR-005 | Tái ký tạo bản ghi HĐ mới nối tiếp (chuỗi contract_id), bản cũ giữ nguyên lịch sử — cấm sửa đè thông tin HĐ đã ký; chấm dứt giữa hạn ghi căn cứ pháp lý (Điều 34/35/36 BLLĐ 2019) + file quyết định, đóng trạng thái. | Sửa thông tin HĐ đã ký bị từ chối; chấm dứt thiếu căn cứ pháp lý không cho phép đóng trạng thái |
| BR-006 | File scan và số HĐ là dữ liệu C1: mã hóa khi lưu/truyền, chỉ HR_L2 mở bản gốc (có audit log từng lượt), HR_L1 nhập metadata không xem lại file sau khi nộp, TL chỉ nhận thông báo không kèm nội dung. | Truy cập file scan sai quyền bị từ chối tầng API + log attempt; xuất raw C1 bị chặn (REQ-HR-010) |
| BR-007 | Hồ sơ HĐLĐ lưu theo retention pháp luật lao động; sau khi nhân sự nghỉ việc, HĐLĐ chuyển chế độ retention theo cấu hình REQ-HR-010, không xóa cứng. | Xóa cứng hồ sơ HĐLĐ bị chặn; hết retention chỉ xóa/ẩn danh có log hủy có phê duyệt |
| BR-008 | Các quy tắc nền lane áp dụng liền kề: chấm công 40h/tuần với trần 48h overtime (loại HĐ quyết định đối tượng chấm công); nghỉ phép 12 ngày/năm số dư tự động duyệt phân cấp; Cost Rate Card version hóa do HR_L2 soạn + FIN_L2 thẩm định → BOD duyệt, billable tại nguồn — thay đổi loại HĐ ảnh hưởng payroll phải khớp version Rate Card và cấu hình chấm công. | Đổi loại HĐ không đồng bộ cấu hình làm lệch payroll → discrepancy ticket bắt buộc giải trình trước khi hiệu lực |
| BR-009 | Delegate duyệt timesheet cho TL vẫn ở mức chưa chốt — assumption có tag `[KXN-DTS]` (SO3-09 nhóm D): luồng cảnh báo HĐLĐ không cấu hình delegate duyệt hộ; nguyên tắc approver ≠ người ghi giữ nguyên cho mọi workflow HR. | Không hiển thị cấu hình delegate trong bản này; yêu cầu delegate bị từ chối kèm ghi chú chờ chốt |
| BR-010 | Nghỉ phép 12 ngày/năm với số dư tự động, duyệt phân cấp, nội quy nghỉ phép + chế tài xử phạt theo `03_Quy_che_KPI_HR.md` §8: trạng thái nghỉ không phép ≥5 ngày/tháng (chấm dứt HĐLĐ theo §8) phải hiển thị lên hồ sơ HĐLĐ làm căn cứ pháp lý khi chấm dứt. | Chấm dứt HĐ theo §8 thiếu hồ sơ vi phạm gắn kèm không cho phép đóng trạng thái |

---

## 4. Phân Quyền

Quyền thực chất do RBAC engine của core kiểm tra tại API; bảng dưới là hợp đồng UI web nội bộ phải tuân thủ. TL là chức danh tổ chức gán qua trường "TL trực tiếp" trong hồ sơ (FEAT-ERP-HRCORE-001), không phải vai registry riêng.

| Hành động | HR_L1 | HR_L2 | TL | BOD_CEO |
|-----------|-------|-------|----|---------|
| Nhập/sửa metadata HĐLĐ | ✅ (tạo mới) | ✅ | ❌ | ❌ |
| Upload file scan | ✅ | ✅ | ❌ | ❌ |
| Xem metadata HĐLĐ nhân sự nhóm | ❌ | ✅ | ✅ (không file scan) | ❌ |
| Mở file scan bản gốc | ❌ | ✅ (log từng lượt) | ❌ | ❌ |
| Nhận cảnh báo 90/60/30 | ❌ | ✅ | ✅ | ❌ |
| Đánh dấu không xác định thời hạn (tắt nhắc) | ❌ | ✅ | ❌ | ❌ |
| Đánh giá hết thử việc / mở luồng ký chính thức | ✅ (soạn) | ✅ (duyệt) | ✅ (cho ý kiến đánh giá) | ❌ |
| Tạo bản ghi tái ký | ✅ (soạn) | ✅ (duyệt) | ❌ | ❌ |
| Chấm dứt giữa hạn (nhập căn cứ pháp lý) | ✅ (soạn) | ✅ (duyệt) | ❌ | ❌ |
| Nhận escalation quá hạn theo tuần | ❌ | ✅ (được escalate đến) | ❌ | ✅ |

Không ai tự duyệt luồng do chính mình soạn: HR_L1 soạn tái ký/chấm dứt → HR_L2 duyệt; đánh giá thử việc của HR_L1 do HR_L2 chốt. Mọi lượt xem/sửa dữ liệu C1 ghi audit log bất biến.

---

## 5. Trường Hợp Đặc Biệt

- HĐ đến hạn trùng lúc nhân sự nghỉ việc: luồng offboarding (FEAT-ERP-HRCORE-001) ưu tiên đóng trạng thái nhân sự; HĐ không cần tái ký — hệ thống chuyển bản ghi sang "chấm dứt theo thôi việc" thay vì tiếp tục cảnh báo đỏ.
- Nhân sự nghỉ dài/không lương kéo dài qua mốc hết hạn HĐ: cảnh báo vẫn sinh cho HR_L2 vì nghĩa vụ pháp lý không tạm dừng; HR_L2 quyết định gia hạn, chấm dứt hoặc bổ sung phụ lục — hệ thống không tự im lặng theo trạng thái `LONG_LEAVE`.
- Thử việc gia hạn 30 ngày kèm PIP: bản ghi thử việc tạo phiên gia hạn mới với mốc đánh giá 30 ngày; HĐLĐ chính thức chỉ mở khi phiên gia hạn PASS.
- Đa văn phòng (Việt Nam, Cambodia, Hong Kong theo Welcome Deck 2026): loại HĐ và luật áp dụng ghi theo trường quốc gia; mốc 90/60/30 giữ nguyên cho mọi quốc gia, nội dung căn cứ pháp lý theo từng khu vực — chi tiết pháp luật nước ngoài ngoài scope, chỉ lưu metadata.
- File scan lỗi/nhiều trang: cho phép nhiều file đính kèm một HĐ; thay file phải tạo phiên bản mới kèm lý do, bản cũ giữ lại — không ghi đè.
- HĐ phụ lục (appendix): quản lý như bản ghi nối tiếp loại "phụ lục" gắn HĐ gốc; ngày hiệu lực phụ lục không được lệch ngoài khoảng hiệu lực HĐ gốc trừ khi HĐ gốc cũng được tái ký.
- Escalation BOD khi BOD vắng: cảnh báo đỏ giữ trạng thái "chờ xử lý" và nhắc lại theo tuần — không tự giảm mức rủi ro, không ai khác được đóng vùng đỏ thay HR_L2 xác nhận phương án.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Hợp đồng lao động (LaborContract) — mỗi bản ghi chạy theo vòng đời riêng; chuỗi tái ký tạo bản ghi mới.

**Sơ đồ trạng thái:**
```
[ACTIVE] ──(còn 90/60/30 ngày)──► [EXPIRING] ──(tái ký duyệt)──► [RENEWED] (kết thúc, nối bản mới)
[ACTIVE (không XĐ thời hạn)] ──(flag tắt nhắc)──► [PERMANENT_NO_REMIND]
[EXPIRING] ──(quá ngày hết hạn chưa tái ký)──► [EXPIRED_RED] ──(HR_L2 chốt phương án)──► [RESOLVED]
[ACTIVE] ──(chấm dứt giữa hạn được duyệt)──► [TERMINATED_EARLY]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `ACTIVE` | Job quét phát hiện còn ≤90 ngày | `EXPIRING` | Hệ thống | Ghi nhận mốc nhắc hiện hành (90/60/30) |
| `ACTIVE` | HR_L2 gắn flag không xác định thời hạn | `PERMANENT_NO_REMIND` | HR_L2 | Loại HĐ = không xác định thời hạn |
| `EXPIRING` | Tái ký được duyệt | `RENEWED` | HR_L2 duyệt, HR_L1 soạn | Bản ghi HĐ mới nối tiếp đã tạo |
| `EXPIRING` | Quá ngày hết hạn chưa tái ký | `EXPIRED_RED` | Hệ thống | Cảnh báo đỏ dashboard + escalate BOD theo tuần |
| `EXPIRED_RED` | Chốt phương án (tái ký khẩn/chấm dứt) | `RESOLVED` | HR_L2 | Phương án + lý do ghi nhận; bản nối tiếp hoặc quyết định chấm dứt gắn kèm |
| `ACTIVE` | Chấm dứt giữa hạn | `TERMINATED_EARLY` | HR_L1 soạn, HR_L2 duyệt | Căn cứ pháp lý Điều 34/35/36 + file quyết định |

**Quy tắc:**
- `RENEWED`, `RESOLVED`, `TERMINATED_EARLY`, `PERMANENT_NO_REMIND` là trạng thái kết thúc của bản ghi — không chuyển tiếp; tái ký tiếp theo tạo bản ghi mới.
- `EXPIRED_RED` không tự xóa khi qua thời gian — chỉ HR_L2 chuyển sang `RESOLVED` bằng phương án có văn bản.
- Mọi chuyển trạng thái ghi audit log bất biến; mốc nhắc hiển thị trên web đúng kết quả quét của core (không tính lại phía UI).

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| LaborContract | `profile_id`, `contract_no`, `type`, `signed_date`, `effective_from`, `effective_to`, `status`, `no_remind_flag` | FK → `EmployeeProfile.id` | Chuỗi tái ký qua `renewed_from_id`; C1 mã hóa |
| ContractScanFile | `contract_id`, `file_uri`, `version`, `uploaded_by` | FK → `LaborContract.id` | Mã hóa lưu trữ; chỉ HR_L2 giải mã |
| RemindLog | `contract_id`, `milestone` (90/60/30), `sent_at`, `recipients` | FK → `LaborContract.id` | Sinh từ job quét core hằng ngày |
| ProbationReview | `profile_id`, `review_date`, `result` (PASS/EXTEND/STOP), `notes` | FK → `EmployeeProfile.id` | Trước hết hạn thử việc ≥3 ngày |
| TerminationRecord | `contract_id`, `legal_basis`, `decision_file`, `approved_by` | FK → `LaborContract.id` | Điều 34/35/36 BLLĐ 2019 |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Nhắc đủ 3 mốc | HĐ hết hạn 01/12 | Chạy job quét tại 03/09, 02/10, 01/11 | HR_L2 + TL nhận thông báo lần lượt ở mốc 90/60/30, nội dung theo mục đích từng mốc | [ ] |
| SC-002: Cảnh báo đỏ quá hạn | HĐ hết hạn 01/09 chưa tái ký | Đến 05/09 | HĐ chuyển `EXPIRED_RED`, dashboard đỏ, escalation BOD sinh theo tuần | [ ] |
| SC-003: Tắt nhắc HĐ không xác định thời hạn | HĐ không xác định thời hạn | HR_L2 gắn flag tắt nhắc | Không sinh cảnh báo nữa; bỏ flag yêu cầu lý do | [ ] |
| SC-004: Chặn ký chính thức trước đánh giá | NV còn 1 ngày thử việc chưa đánh giá | HR_L1 mở luồng ký HĐ chính thức | Bị chặn với lý do "chưa có kết luận đánh giá hết thử việc" | [ ] |
| SC-005: Tái ký nối tiếp có lịch sử | HĐ A sắp hết hạn | Tái ký tạo HĐ B | HĐ A `RENEWED` giữ nguyên; chuỗi A→B hiển thị trên timeline hồ sơ | [ ] |
| SC-006: Bảo vệ file scan | TL nhận thông báo HĐLĐ nhân sự nhóm | Cố mở file scan | Từ chối tầng API + log attempt; thông báo không chứa file | [ ] |

> **Liên kết:** SC-001…SC-006 map về REQ-HR-002 (Mục 2 — lưu HĐLĐ, nhắc 90/60/30, cảnh báo đỏ, thử việc, tái ký, chấm dứt giữa hạn).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/hr-core/hdld-canh-bao.md` |
| Bản fan-out counterpart | `phase2-features/core-backend/hr-core/` (job quét hằng ngày + mã hóa C1) |
| Nguồn domain | `documents/03_Quy_che_KPI_HR.md` (HR v3.9, quy trình thử việc, §8 nội quy) |
