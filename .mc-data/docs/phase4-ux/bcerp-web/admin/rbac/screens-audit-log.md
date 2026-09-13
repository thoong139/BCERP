# Screen Group: Audit Log Query

> **System:** BCERP Web nội bộ (SYS-BCERP-WEB)
> **Module:** `rbac`
> **Tính năng:** FEAT-ERP-RBAC-002, FEAT-ERP-RBAC-007
> **Route:** `/admin/audit`
> **Main UI-ID:** `UI-WEB-AUDIT-001`
> **Ngày:** 13/09/2026
>
> READS: `design-system.md`, `Navigation-bcerp-web.md`, `phase2-features/`, `phase3-architecture/technical-specs/api-contract.md`
> USED BY: `phase5-implementation/`, `phase6-deployment/user-guide.md`

**Implements:** FEAT-ERP-RBAC-002 (giám sát & truy xuất audit log — tra cứu chuỗi old→new + reason code, watermark + meta-log, sức khỏe hash-chain, xuất log có duyệt CEO ≤2 ngày), FEAT-ERP-RBAC-007 (WORM ≥10 năm — dashboard retention phân tầng, backup/DR, đề xuất xóa/archive theo quý CTO → CEO).

---

## Thông Tin Chung

| Trường                                       | Giá trị                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Workspace                                      | Platform Admin (`/admin/audit`) — BOD truy cập dùng chung route (oversight)                                                                                                                                                                                                                                                                                                                                                                 |
| Đối tượng nghiệp vụ                      | `audit_log` (read model append-only hash-chain — web chỉ SELECT), `meta_log` (ai xem gì — cũng append-only), `audit_export_request` (DRAFT → PENDING_CEO_APPROVAL → APPROVED → EXPORTED/FAILED/REJECTED), `audit_chain_status` (VALID/INVALID/STALE), `archive_proposal` + vòng đời retention (`document_archive`: ACTIVE → RETENTION_APPROACHING → RETENTION_DUE → ARCHIVE_PROPOSED → ARCHIVED / RETENTION_EXTENDED) |
| Vai trò chính (2 role views trên 1 surface) | BOD_CEO — oversight đọc toàn bộ + duyệt xuất + duyệt archive; BOD_CFO_CTO — oversight + đề xuất xóa/archive theo quý; SYS_ADMIN — vận hành: chỉ event kỹ thuật (auth/sync/job/cấu hình), KHÔNG nội dung nghiệp vụ; FIN_L2 — ◐ phạm vi tài chính theo API-CORE-029 (vào qua link từ S7/S10, cùng surface không nhân bản)                                                                                     |
| Workflow stage                                 | Chain: job kiểm tra toàn vẹn hằng ngày (`VALID` ↔ `INVALID`; `STALE` khi job trễ — không giả trạng thái OK). Xuất: duyệt ≤2 ngày làm việc, SLA sinh file trong ngày duyệt. Archive: chỉ theo quý                                                                                                                                                                                                                     |
| Liên quan                                     | S26 RBAC Admin (mọi grant/revoke/user transition tại đây truy vết được); S27 (gateway audit riêng — API-GW-035); Alert Center (đứt chuỗi + escalation REQ-BOD-006); Client 360/S7/S9 (jump về object nguồn)                                                                                                                                                                                                                       |

**Checklist workflow (Bước 0):** A. "Kính đen" của điều hành — nguồn bằng chứng duy nhất cho tranh chấp/thanh tra; append-only, kể cả Super Admin không sửa/xóa được. B. Actors: BOD_CEO (đọc + duyệt xuất/archive), BOD_CFO_CTO (oversight + đề xuất archive), SYS_ADMIN (kỹ thuật), FIN_L2 (tài chính). C. Không có department khác — mọi vai khác ❌. D. Máy trạng thái (export request, retention) do hệ thống trả về. E. Cross-module: hash-chain + meta-log do CORE thực thi (web chỉ hiển thị), Alert Center khi `INVALID`. F. Thông tin cần: actor + timestamp + old→new + reason code + seq/hash + nhánh ngưỡng 5/50/200tr của event tiền (DI-001); trạng thái chain có timestamp job. G. Quyết định: duyệt/từ chối xuất (CEO), duyệt/từ chối archive (CEO), chạy verify (SYS_ADMIN). H. Actions: filter/query, mở chi tiết, trail per object, tạo yêu cầu xuất — KHÔNG có edit/delete UI ở mọi tầng. I. Exceptions: `INVALID` (đỏ, khóa xuất), `STALE` (cam, hiện kết quả hợp lệ cuối), PII trong log masked (không nút bỏ mask), SoD tra cứu ≠ đối tượng khi duyệt xuất, job trễ. J. 1 surface nhiều role view — không tách page theo vai.

---

## 1. TRANG CHÍNH

### 1.1. Layout — W1 query surface (density compact, data-heavy; bảng read-only tuyệt đối)

```
┌────────────────────────────────────────────────────────────────────────────────────────────┐
│ Platform Admin > Audit Log      [Role view: BOD oversight — đọc toàn hệ thống]             │
│ Phiên xem: Nguyễn Văn A (BOD_CEO) · MỌI lượt tra cứu/mở chi tiết được ghi meta-log         │
├────────────────────────────────────────────────────────────────────────────────────────────┤
│ Tra cứu ·12.480 │ Yêu cầu xuất log ·2 │ Chuỗi & Lưu trữ │ Meta-log                          │
├────────────────────────────────────────────────────────────────────────────────────────────┤
│ ✓ Chain: VALID — job kiểm tra 13/09 02:00 (SYS_ADMIN chạy verify thủ công: nút "Verify")   │
│ [Đối tượng ▾ Ví/TKQC/Hợp đồng/Giao dịch/User] [Hành động ▾] [Người thực hiện ▾]            │
│ [Từ 01/09/2026] [Đến 13/09/2026] [Tìm]                          [+ Yêu cầu xuất log]       │
│ Chips: (Giao dịch tiền ·3.214 ×) (Phân quyền ·18 ×) (Có reason code ×) (7 ngày qua ×)      │
├────────────────────────────────────────────────────────────────────────────────────────────┤
│ 13/09 10:32:41 · ttb.fin (FIN_L1) · wallet.adjust · Điều chỉnh số dư ADJ-1042 · TK Meta    │
│   old: 0 USD → new: +2.150 USD · reason: RC-BU-TICKET-217 · nhánh ngưỡng <5tr · seq 881203 │
│ 13/09 10:45:12 · core.system (hệ thống) · approval.grant · ADJ-1042 slot 1                 │
│   old: PENDING → new: STEP1_APPROVED · seq 881204                                          │
│ 12/09 16:20:07 · sysadmin (SYS_ADMIN) · role.assign.propose · NV-0107 + SALES_L1           │
│   old: — → new: SALES_L1 · reason: "thay thế nhân sự nghỉ" · seq 880112                    │
│ 12/09 09:14:55 · lvc.hr (HR_L2) · pii.salary.edit · NV-0042                                │
│   old: ●●●●●● → new: ●●●●●● (masked — Restricted, không có nút hiện giá trị)               │
├────────────────────────────────────────────────────────────────────────────────────────────┤
│ Phân trang 20/100 (server-side)                          Tổng ước tính theo filter: 12.480 │
└────────────────────────────────────────────────────────────────────────────────────────────┘
              click hàng → SidePanel 480px (S1 chi tiết) · nút trail → 720px (S2 timeline)
```

**Loading/Empty/Error:** loading = skeleton 10 hàng; empty = EmptyState "Không có event khớp bộ lọc" + gợi ý nới thời gian; error = khối lỗi + retry. Kết quả render read-only — không row menu sửa/xóa (không tồn tại hành động đó).

### 1.2. Components

| Component                       | Cấu hình                                                                               | Ghi chú                                                                                                                  |
| ------------------------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| DataTable (§4.1)               | variant compact, sort theo thời gian DESC mặc định                                   | Không bulk action, không inline edit                                                                                    |
| Filter bar + quick chips        | 5 bộ lọc: object type, action/event, actor, khoảng thời gian, có/không reason code | Server-side (API-CORE-029); chips tháo được từng cái                                                                |
| WarningIndicator banner (§4.3) | trạng thái chain — persistent, không dismiss                                         | VALID (xanh) / STALE (cam: "kết quả hợp lệ cuối 12/09 02:00") / INVALID (đỏ: khóa nút xuất + link Alert Center) |
| Watermark bar                   | đầu trang, không ẩn được                                                          | Danh tính người xem + nhắc meta-log (BR-003); watermark in cả trên bản xuất                                       |
| StatusBadge (§4.2)             | trạng thái export request                                                              | 1 badge/hàng ở T2                                                                                                       |
| SidePanel (§4.5)               | S1 480px · S2 720px (detail sâu)                                                       | Esc đóng, focus trả về hàng                                                                                          |

### 1.3. Cột bảng kết quả

| Tên                | Trường                       | Định dạng                                             | Sắp xếp          | Rộng |
| ------------------- | ------------------------------ | -------------------------------------------------------- | ------------------ | ----- |
| Thời điểm        | `occurred_at`                | dd/MM HH:mm:ss (UTC+7, tuyệt đối)                     | Có (DESC default) | 140px |
| Người thực hiện | `actor_id`, `actor_role`   | Tên đăng nhập + vai (chip hệ thống cho actor CORE) | Có (filter)       | 180px |
| Hành động        | `event_type`                 | Text + nhóm (tiền/hợp đồng/phân quyền/hệ thống) | Filter dropdown    | 180px |
| Đối tượng       | `object_type`, `object_id` | Mã nghiệp vụ (không UUID) — link về surface nguồn | Filter             | 200px |
| Chuỗi giá trị    | `old_value → new_value`     | Mono, PII masked theo vai (Restricted không nút hiện) | Không             | auto  |
| Reason code         | `reason_code`                | Chip + tooltip lý do đầy đủ                         | Filter             | 140px |
| Seq · Hash         | `prev_hash`, `hash`        | Seq`tabular-nums` + icon ✓ (chi tiết hash ở S1)     | Không             | 120px |

Event tiền hiển thị kèm nhánh ngưỡng áp dụng (5/50/200tr + escalation path) — event thiếu nhánh được job chất lượng dữ liệu gắn cờ (BR-008 FEAT-ERP-RBAC-002).

### 1.4. Hành Động Chính

| Sự kiện                                     | Hành động                 | Kết quả                                                                 |
| --------------------------------------------- | ---------------------------- | ------------------------------------------------------------------------- |
| Nhấn "Tìm" / đổi chip                     | Query server-side            | Kết quả mới; lượt query tự ghi meta-log                             |
| Click hàng                                   | Mở S1 chi tiết event       | Cũng ghi meta-log ("xem log cũng bị log")                              |
| Nút trail trên hàng                        | Mở S2 timeline per object   | Toàn bộ event của 1 object theo thời gian                             |
| "+ Yêu cầu xuất log"                       | Mở D1                       | Nút ẩn khi chain`INVALID` (SC-004) và ẩn với vai không có quyền |
| T2 → hàng`PENDING_CEO_APPROVAL` (BOD_CEO) | Mở D2 duyệt/từ chối      | MFA step-up; SoD tra cứu ≠ đối tượng                                |
| T3 → nút "Verify chain" (SYS_ADMIN)         | Gọi verify theo khoảng seq | Kết quả + WORM ref integrity; lệch → alert HIGH                       |
| T3 → "Đề xuất archive" (BOD_CFO_CTO)      | Mở D3                       | Chỉ theo quý; chặn khi chain`INVALID`                                |

### 1.5. Phân Quyền (2 role views — 1 surface, server-side scope; PEP ẩn nút)

| Thành phần                               | BOD_CEO                                                                                       | BOD_CFO_CTO   | SYS_ADMIN                                                                       | FIN_L2                                | Vai khác |
| ------------------------------------------ | --------------------------------------------------------------------------------------------- | ------------- | ------------------------------------------------------------------------------- | ------------------------------------- | --------- |
| Tra cứu log                               | ✅ toàn bộ                                                                                  | ✅ toàn bộ  | ◐ chỉ event kỹ thuật (auth/sync/job/cấu hình — filter cứng server-side) | ◐ phạm vi tài chính               | ❌        |
| Xem giá trị PII trong log (lương/cost) | ✅ (theo ma trận REQ-HR-010)                                                                 | ✅            | ❌ masked                                                                       | ❌ masked                             | ❌        |
| Xem dashboard chain + retention (T3)       | ✅                                                                                            | ✅            | ◐ trạng thái job kỹ thuật                                                  | ◐ phần vận hành FIN               | ❌        |
| Tạo yêu cầu xuất log (D1)              | ✅                                                                                            | ✅            | ❌ (theo FEAT-ERP-RBAC-002 §4)                                                 | ◐ (tài chính — theo API-CORE-031) | ❌        |
| Duyệt/từ chối xuất (D2)                | ✅ ≤2 ngày (SoD: không duyệt sự kiện mình liên quan — CEO liên quan → chuyển CFO) | ❌            | ❌                                                                              | ❌                                    | ❌        |
| Đề xuất xóa/archive (D3)               | ❌                                                                                            | ✅ theo quý  | ❌                                                                              | ❌                                    | ❌        |
| Duyệt xóa/archive (D4)                   | ✅ theo quý                                                                                  | ❌            | ❌                                                                              | ❌                                    | ❌        |
| Chạy verify chain                         | Xem kết quả                                                                                 | Xem kết quả | ✅ chạy                                                                        | ❌                                    | ❌        |
| Xóa/sửa log trực tiếp                  | ❌ (không tồn tại UI/API — attempt bị chặn mọi tầng + log)                            | ❌            | ❌                                                                              | ❌                                    | ❌        |

---

## 2. TABS (watermark bar + banner chain giữ nguyên khi chuyển tab)

| Tab                 | UI-ID                   | Nội dung                                                     | Hiện với vai                                                                                                |
| ------------------- | ----------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Tra cứu            | `UI-WEB-AUDIT-001-T1` | Query + kết quả (§1)                                       | BOD (toàn bộ), SYS_ADMIN (kỹ thuật), FIN_L2 (tài chính)                                                 |
| Yêu cầu xuất log | `UI-WEB-AUDIT-001-T2` | Vòng đời xuất ngoài báo cáo chuẩn                     | CEO (duyệt), CFO/SYS_ADMIN (xem yêu cầu liên quan)                                                        |
| Chuỗi & Lưu trữ  | `UI-WEB-AUDIT-001-T3` | Chain health + WORM retention + backup/DR + archive proposals | BOD, SYS_ADMIN (phần kỹ thuật), FIN_L2 (vận hành)                                                        |
| Meta-log            | `UI-WEB-AUDIT-001-T4` | Ai đã tra cứu gì — kiểm chứng "xem cũng bị log"      | CEO/CFO toàn bộ meta-log; SYS_ADMIN phần kỹ thuật; mọi vai trong scope thấy meta-log của chính mình |

**R7 tab completeness:**

- **T1 Tra cứu:** mục tiêu — trả lời mọi câu hỏi "khoản này sao lại vậy" bằng chuỗi old→new + reason code, xuất phát từ một nguồn bằng chứng duy nhất. Thông tin: 7 cột §1.3 + nhánh ngưỡng event tiền. Components: filter bar, chips, bảng compact, S1/S2. Actions: query (tự ghi meta-log), mở chi tiết, trail, tạo yêu cầu xuất. States: empty/error §1.1; kết quả ngoài phạm vi vai trả rỗng + ghi attempt (BR-001 FEAT-ERP-RBAC-007). Permissions: §1.5. Quan hệ: T2 lấy scope từ filter hiện tại; T3 quyết định có được xuất hay không (chain `INVALID` khóa).
- **T2 Yêu cầu xuất log:** mục tiêu — mọi luồng dữ liệu Mật ra khỏi hệ thống có dấu vết ai xin, khi nào, cho ai; không có đường xuất trực tiếp ngoài luồng (nút xuất file độc lập không tồn tại — SC-002). Thông tin: danh sách yêu cầu (state machine `DRAFT/PENDING_CEO_APPROVAL/APPROVED/EXPORTED/FAILED/REJECTED`), người yêu cầu + phạm vi + mục đích, đếm ngược SLA duyệt 2 ngày làm việc (WaitingOnIndicator "chờ CEO 1 ngày 3 giờ"), số phần chunk khi vượt giới hạn file (tổng phần + dung lượng ghi trong log xuất), file_ref có watermark. Components: DataTable + ApprovalCard-style hàng duyệt. Actions: tạo (D1), CEO duyệt/từ chối (D2 — lý do bắt buộc khi từ chối), retry khi `FAILED` (không cần duyệt lại). States: `EXPORTED`/`REJECTED` kết thúc — yêu cầu lại tạo bản ghi mới; chuyển trạng thái cũng nằm trong meta-log. Permissions: §1.5; hệ thống chặn CEO duyệt yêu cầu liên quan trực tiếp đến sự kiện mình là đối tượng (SoD tra cứu ≠ đối tượng — đề xuất người duyệt thay thế CEO↔CFO; cả hai liên quan → leo thang quy trình điều tra). Quan hệ: file xuất ghi vào WORM (object-lock ≥10 năm với log tiền); metadata xem được ở T3.
- **T3 Chuỗi & Lưu trữ:** mục tiêu — biết ngay log còn đáng tin hay đã bị can thiệp, và vận hành nghĩa vụ pháp lý 10 năm đúng Luật Kế toán 2015. Thông tin: (a) chain status theo ngày — `VALID/INVALID/STALE` + `job_run_at` + `first_broken_seq` khi đứt; (b) retention phân tầng: tiền/hợp đồng ≥10 năm, log hệ thống ≥7 năm, KYC/AML ≥5 năm, HĐĐT theo TT78/2021 + NĐ 123/2020 (thời hạn HĐĐT chốt với tư vấn thuế `[CẦN CHỐT SỐ]` — cấu hình cho phép thời hạn riêng từng loại); (c) dữ liệu `RETENTION_APPROACHING` (<90 ngày) / `RETENTION_DUE`; (d) backup/DR: backup mã hóa 2 nơi hằng ngày, RPO ≤15 phút / RTO ≤4 giờ, biên bản test restore hằng quý — thiếu biên bản quý → trạng thái "backup không hợp lệ" + đề xuất archive bị đóng băng; (e) danh sách archive proposals theo quý. Components: hàng KPI trạng thái + bảng dữ liệu sắp hết hạn + danh sách proposals. Actions: verify (SYS_ADMIN), đề xuất archive (D3 — CTO), duyệt archive (D4 — CEO). States: `INVALID` → đỏ + link Alert Center + khóa D1/D3; `STALE` → không giả OK. Permissions: §1.5. Quan hệ: archive xong sinh deletion log (việc xóa cũng bị log); yêu cầu pháp lý kéo dài → `RETENTION_EXTENDED` (chỉ kéo dài, không rút ngắn — validate chặn). [NEEDS_REVIEW: contract §6.4 chưa có endpoint GET cho retention dashboard + archive proposals — xem §6]
- **T4 Meta-log:** mục tiêu — chứng minh "kể cả việc xem log cũng bị log", chống truy cập lén. Thông tin: viewer, scope đã xem, thời điểm, kênh — chính là nguồn watermark. Components: bảng chỉ đọc cùng format T1 (filter actor/thời gian). Actions: chỉ tra cứu. States: tra cứu không có meta-log là lỗi hệ thống (job đối chiếu phát hiện) — hiển thị cờ chất lượng. Permissions: CEO/CFO xem toàn bộ; SYS_ADMIN phần kỹ thuật; mọi vai thấy meta-log của chính mình (filter `actor=self` mặc định cho vai không có oversight). Quan hệ: dữ liệu nằm trong cùng hash-chain (không endpoint riêng — query lại API-CORE-029 với `event_type=meta_log`).

---

## 3. DIALOGS

| # | Dialog                        | UI-ID                   | Loại                 | Mở khi nào                        |
| - | ----------------------------- | ----------------------- | --------------------- | ----------------------------------- |
| 1 | Tạo yêu cầu xuất log      | `UI-WEB-AUDIT-001-D1` | Form                  | "+ Yêu cầu xuất log" (T1/T2)     |
| 2 | CEO duyệt/từ chối xuất    | `UI-WEB-AUDIT-001-D2` | Approve (MFA step-up) | T2 — hàng`PENDING_CEO_APPROVAL` |
| 3 | Đề xuất xóa/archive (CTO) | `UI-WEB-AUDIT-001-D3` | Form theo quý        | T3 — dữ liệu`RETENTION_DUE`    |
| 4 | CEO duyệt archive            | `UI-WEB-AUDIT-001-D4` | Approve (MFA step-up) | T3 — proposal`ARCHIVE_PROPOSED`  |
| 5 | MFA step-up (chung)           | `UI-WEB-AUDIT-001-D5` | Confirm OTP           | Trước D2/D4                       |

### 3.1. Dialog Tạo yêu cầu xuất log (D1)

**Loại:** Form. Fields: khoảng thời gian (bắt buộc), loại đối tượng + phạm vi (khách/TKQC/hợp đồng/giao dịch/user — bám filter T1), mục đích (thanh tra/kiểm toán/điều tra nội bộ — bắt buộc), định dạng (PDF/A + XML gốc kèm metadata), dự kiến số phần chunk. Điều kiện mở: chain `VALID`; vai có quyền (§1.5). Submit → `PENDING_CEO_APPROVAL`; thanh tra/kiểm toán dùng đúng luồng này — không có kênh song song.

### 3.2. Dialog CEO duyệt/từ chối xuất (D2)

**Loại:** Approval — MFA step-up (D5) bắt buộc. Nội dung: phạm vi + mục đích + người yêu cầu + dung lượng ước tính + SLA còn lại. Ràng buộc SoD: người duyệt không được liên quan trực tiếp đến sự kiện bị tra cứu — nếu CEO là đối tượng, hệ thống chuyển CFO duyệt và ngược lại. Từ chối: reason code bắt buộc. Sau duyệt: hệ thống sinh file (SLA trong ngày duyệt), file ghi watermark người duyệt + người yêu cầu.

### 3.3. Dialog Đề xuất xóa/archive (D3)

**Loại:** Form theo quý (ngoài kỳ → từ chối ở giao diện). Fields: quý, phạm vi (liệt kê từ dữ liệu `RETENTION_DUE` — số bản ghi + dung lượng theo tầng retention), lý do. Validate chặn: đề xuất rút ngắn retention dưới mức tối thiểu (chỉ được kéo dài); chain `INVALID`; backup quý chưa hợp lệ. Submit → `ARCHIVE_PROPOSED`.

### 3.4. Dialog CEO duyệt archive (D4)

**Loại:** Approval — MFA step-up. Duyệt → `ARCHIVED`, sinh deletion log riêng (việc xóa cũng bị log; hash-chain không đứt). Từ chối / yêu cầu pháp lý kéo dài → `RETENTION_EXTENDED` với lý do + thời hạn mới bắt buộc. `ACTIVE` không bao giờ chuyển thẳng `ARCHIVED` — luôn qua đề xuất + duyệt theo quý.

### 3.5. Dialog MFA step-up (D5)

**Loại:** Confirm OTP — `POST /core/auth/mfa/step-up` trước khi ghi duyệt D2/D4. [NEEDS_REVIEW: enum purpose của API-CORE-003 chưa có giá trị cho duyệt xuất log/archive (hiện: payment_approval, vault_access, policy_approval, period_lock) — đề xuất bổ sung `evidence_export`]

---

## 4. SHEETS

| # | Sheet             | UI-ID                   | Vị trí                        | Mở khi nào                          |
| - | ----------------- | ----------------------- | ------------------------------- | ------------------------------------- |
| 1 | Chi tiết event   | `UI-WEB-AUDIT-001-S1` | Right panel 480px               | Click hàng T1                        |
| 2 | Trail theo object | `UI-WEB-AUDIT-001-S2` | Right panel 720px (detail sâu) | Nút "Xem trail" trên hàng / từ S1 |

### 4.1. Sheet: Chi tiết event (S1)

**Kích thước:** 480px. Nội dung: full `old_value → new_value` (PII vẫn masked theo vai), reason code + lý do đầy đủ, actor + IP + user_agent + correlation_id, `prev_hash`/`hash`/`seq` (chuỗi minh bạch để đối chiếu verify), nhánh ngưỡng + escalation path với event tiền, link object nguồn (Client 360 / S7 ví / S9 TKQC / S26 user). Chú thích cố định cuối panel: "Lượt mở chi tiết này cũng được ghi vào meta-log". Không có nút sửa/xóa.

### 4.2. Sheet: Trail theo object (S2)

**Kích thước:** 720px. Nội dung: timeline dọc toàn bộ event của 1 object (API-CORE-030) — mỗi entry: thời gian tuyệt đối + actor + hành động + old→new thu gọn; marker giai đoạn (draft→duyệt→thực thi) màu theo token trạng thái; sự kiện hệ thống (sync, degraded manual) icon riêng. Filter nhanh theo nhóm event. "Xuất trail này" → mở D1 với scope đã điền sẵn. Đóng bằng Esc, focus trả về hàng gốc.

---

## 5. VIEW MODES

| Mode                          | UI-ID                   | Mô tả                                                                                     | Hiện khi nào                 |
| ----------------------------- | ----------------------- | ------------------------------------------------------------------------------------------- | ------------------------------ |
| Bảng kết quả (mặc định) | `UI-WEB-AUDIT-001-M1` | DataTable §1 — rà soát/số lượng lớn                                                 | Default                        |
| Timeline trail per object     | `UI-WEB-AUDIT-001-M2` | Chế độ đọc dọc theo vòng đời 1 object (mở từ S2; giữ filter object khi chuyển) | Khi đã chọn object cụ thể |

---

## 6. API ENDPOINTS

Endpoint thật từ `api-contract.md` (base `/api/v1`). Ghi đường append (API-CORE-028) là internal service token — web KHÔNG gọi; không tồn tại endpoint update/delete audit (409 `AUDIT_IMMUTABLE` / 405 `AUDIT_MUTATION_NOT_SUPPORTED`).

| Khi nào                                      | Method | Endpoint                                                  | Tham số / Ghi chú                                                                                                                                                                                                                                               |
| --------------------------------------------- | ------ | --------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tra cứu log (T1/T4)                          | GET    | `/core/audit/events` (API-CORE-029)                     | Filter`actor`, `object`, `time_from/time_to`, `action`; `page/limit` 20/100 server-side; scope theo vai server-side; MỌI lượt query tự ghi audit (meta-log)                                                                                         |
| Trail per object (S2/M2)                      | GET    | `/core/audit/objects/:objectId/timeline` (API-CORE-030) | Theo vai sở hữu object + SYS_ADMIN                                                                                                                                                                                                                              |
| Tạo yêu cầu xuất (D1)                     | POST   | `/core/audit/export-requests` (API-CORE-031)            | Yêu cầu: FIN_L2/SYS_ADMIN/BOD theo contract; duyệt BOD_CEO`[STEP-UP]`; export vào WORM object-lock ≥10 năm với log tiền. [NEEDS_REVIEW: mâu thuẫn permission — FEAT-ERP-RBAC-002 §4 chặn SYS_ADMIN tạo yêu cầu xuất; đồng bộ trước build] |
| Verify chain (T3)                             | GET    | `/core/audit/chain/verify` (API-CORE-032)               | Khoảng seq; SYS_ADMIN chạy, BOD_CEO xem kết quả; lệch → alert HIGH                                                                                                                                                                                          |
| Gateway audit (T3 — nguồn riêng GW)        | GET    | `/gw/audit-logs` (API-GW-035)                           | JWT CTO/CEO; việc xem cũng bị log; link sang thay vì trộn 2 nguồn                                                                                                                                                                                           |
| Tham chiếu dữ liệu raw đối trừ (từ S7) | —     | API-GW-032 hợp đồng dữ liệu                          | Nhãn `api                                                                                                                                                                                                                                                        |

**[NEEDS_REVIEW] thiếu endpoint cho T2/T3:** (1) GET `/core/audit/export-requests` — danh sách + trạng thái yêu cầu xuất (API-CORE-031 chỉ có POST; tab T2 hiện không có nguồn list); (2) GET dashboard retention/WORM (`retention_policy`, `document_archive`, phân tầng + dung lượng + `RETENTION_APPROACHING/DUE`); (3) POST/GET/duyệt `archive_proposal` (D3/D4 — CTO đề xuất, CEO duyệt); (4) GET `dr_test_record` + `backup_status` (biên bản test restore quý, backup hằng ngày); (5) trạng thái job toàn vẹn hằng ngày `audit_chain_status` dưới dạng read-model riêng (hiện chỉ có verify on-demand API-CORE-032 — dashboard cần kết quả job hằng ngày). KHÔNG bịa endpoint — các khối T3 đánh dấu render theo contract bổ sung.

---

## 7. UI-ID Registry

| UI-ID                   | Loại     | Mô tả                                                                                                   |
| ----------------------- | --------- | --------------------------------------------------------------------------------------------------------- |
| `UI-WEB-AUDIT-001`    | Main Page | Audit Log Query — 1 surface, 2 role views (BOD oversight / SYS_ADMIN vận hành), read-only tuyệt đối |
| `UI-WEB-AUDIT-001-T1` | Tab       | Tra cứu log (filter object/actor/thời gian/hành động + chips)                                        |
| `UI-WEB-AUDIT-001-T2` | Tab       | Yêu cầu xuất log (state machine, SLA duyệt ≤2 ngày, chunk)                                          |
| `UI-WEB-AUDIT-001-T3` | Tab       | Chuỗi & Lưu trữ (chain health, WORM retention, backup/DR, archive proposals)                           |
| `UI-WEB-AUDIT-001-T4` | Tab       | Meta-log (ai đã tra cứu gì)                                                                           |
| `UI-WEB-AUDIT-001-D1` | Dialog    | Tạo yêu cầu xuất log (scope, mục đích, định dạng, chunk)                                        |
| `UI-WEB-AUDIT-001-D2` | Dialog    | CEO duyệt/từ chối xuất (MFA step-up + SoD tra cứu ≠ đối tượng)                                  |
| `UI-WEB-AUDIT-001-D3` | Dialog    | Đề xuất xóa/archive theo quý (CTO)                                                                   |
| `UI-WEB-AUDIT-001-D4` | Dialog    | CEO duyệt archive (→ deletion log; từ chối → RETENTION_EXTENDED)                                     |
| `UI-WEB-AUDIT-001-D5` | Dialog    | MFA step-up OTP                                                                                           |
| `UI-WEB-AUDIT-001-S1` | Sheet     | Chi tiết event 480px (old→new, hash, watermark meta-log)                                                |
| `UI-WEB-AUDIT-001-S2` | Sheet     | Trail theo object 720px (timeline API-CORE-030)                                                           |
| `UI-WEB-AUDIT-001-M1` | View Mode | Bảng kết quả (mặc định)                                                                             |
| `UI-WEB-AUDIT-001-M2` | View Mode | Timeline trail per object                                                                                 |

---

## Tài Liệu Liên Quan

| Nội dung               | File                                                                | Ghi chú |
| ----------------------- | ------------------------------------------------------------------- | -------- |
| Tính năng nghiệp vụ | `../../../../phase2-features`                                     | Upstream |
| API chi tiết           | `../../../../phase3-architecture/technical-specs/api-contract.md` | Upstream |
| Design system           | `../../../design-system.md`                                       | Upstream |
| Navigation tổng quan   | `../../Navigation-bcerp-web.md`                                   | Upstream |
