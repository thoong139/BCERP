# Tính Năng: Bảo Vệ PII Nhân Sự (Lương Confidential/Restricted)

> **Dựa trên:** REQ-HR-010 trong `phase1-business/departments/hr/hr.md` (Phần A)
> **Phân hệ:** RBAC & Audit Log (SYS-BCERP-WEB)
> **Module:** RBAC & Audit Log (MOD-RBAC-AUDIT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/hr/hr.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/rbac-audit/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/rbac-audit/feat-006-impl.md`

> **Hướng dẫn ID:** FEAT-ID được tạo từ REQ-ID theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. Bản fan-out này dùng ID lane `FEAT-ERP-RBAC-006` — bản riêng của touchpoint SYS-BCERP-WEB (bản counterpart: SYS-CORE-BACKEND).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-RBAC-006 |
| Module | MOD-RBAC-AUDIT |
| Yêu cầu nghiệp vụ | REQ-HR-010 |
| Người dùng liên quan | HR_L1, HR_L2 (các vai BOD_CEO/BOD_CFO_CTO/FIN_L2/SYS_ADMIN xuất hiện trong ma trận truy cập theo `hr.md` B10) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — security cross-cutting, áp cho mọi REQ chứa PII) |
| Phụ thuộc | FEAT-ERP-RBAC-005 (nền tảng RBAC & SSO/MFA — tier dữ liệu và mask theo vai), FEAT-ERP-RBAC-002 (audit log truy cập PII) |
| Ghi chú Expert (A7) | A7 của `hr.md` đã có kết quả review ban đầu (A7.2 liệt kê 3 điểm cần làm rõ — trong đó mobile HR ngoài scope hiện tại; A7.3 đang chờ Team Expert); điều chỉnh cấu trúc vai áp dụng cho feature này: DI-006 gỡ OPS_CX/FIN_COMPL — ma trận quyền PII chỉ dùng 18 vai registry; chi tiết tại `hr.md` Mục A7 và `stakeholder-review.md` Phần F.3 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Bảo vệ dữ liệu cá nhân nhân sự trên web nội bộ theo đúng phân loại bảo mật: lương, CCCD, tài khoản ngân hàng, dữ liệu y tế thuộc mức C1 — mã hóa khi lưu và truyền, hiển thị mask theo vai, cấm xuất raw. BCERP là hệ thống quản lý cả cost rate và hoa hồng nên ranh giới "ai được nhìn thấy gì" phải là luật của hệ thống chứ không phải thỏa thuận miệng: chỉ HR_L2 trở lên xem lương cá nhân, HR_L1 tuyệt đối không xem lương, quản lý chỉ thấy tổng cost nhóm mình, và mọi lượt xem/sửa dữ liệu C1 đều để lại dấu vết bất biến.

**Phạm vi:**
- Bao gồm: hiển thị mask/ẩn tự động theo ma trận quyền (lương cá nhân, cost/hour cá nhân, tổng cost nhóm) trên mọi màn hình HR và hồ sơ user; luồng sửa dữ liệu C1 (HR_L2) có audit log bất biến trước/sau; màn báo cáo review truy cập C1 theo quý (HR_L2 + SYS_ADMIN — nối chu trình REQ-BOD-007); luồng yêu cầu xuất dữ liệu C1 ngoại lệ (thuế/BHXH theo mẫu, log từng lần xuất); theo dõi trạng thái retention dữ liệu PII (hồ sơ ứng tuyển không trúng 12 tháng; lương/chứng từ kế toán 10 năm) với cảnh báo dữ liệu đến hạn trên web; form khai báo sự cố breach PII phối hợp legal (thông báo 72h theo NĐ 13/2023 — intake và timer hiển thị tại đây, xử lý ở quy trình sự cố).
- Không bao gồm: mã hóa C1 khi lưu/truyền và enforcement tier Restricted (SYS-CORE-BACKEND — web chỉ nhận dữ liệu đã mask và không có cơ chế bỏ mask); thu hồi quyền offboard 24h (FEAT-ERP-RBAC-003/005); quy trình tuyển dụng, chấm công, KPI (phân hệ HR-CORE chuyên trách); DSAR của khách hàng cuối (REQ-FIN-017 — scope portal/tài chính).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | HR_L2 | Xem và sửa lương, HĐLĐ, dữ liệu C1 của nhân sự với form có lý do bắt buộc | Quản trị PII đầy đủ mà mọi thay đổi đều có dấu vết kiểm soát |
| 2 | HR_L1 | Xem thông tin công việc và tổng cost nhóm mình, nhưng không bao giờ thấy lương cá nhân | Làm được việc mà không phải "tự mình né" dữ liệu nhạy cảm — hệ thống đã chặn sẵn |
| 3 | HR_L2 | Mở báo cáo review truy cập C1 mỗi quý: ai đã xem/sửa lương, có bất thường không | Phát hiện sớm truy cập bất hợp pháp và nộp minh chứng review định kỳ |
| 4 | Quản lý trực tiếp (vai SALES_L4/OPS lead trong registry 18 vai) | Xem tổng cost nhóm mình để quản trị chi phí, không thấy cost từng người | Đủ dữ liệu điều hành nhóm mà không đụng quyền riêng tư cá nhân |
| 5 | FIN_L2 | Xem lương/cost cá nhân chỉ khi thẩm định Rate Card, mỗi lần xem được log | Đối soát giá vốn đúng nhưng truy cập có kiểm soát (meta-log) |
| 6 | HR_L1 | Nhận cảnh báo hồ sơ ứng tuyển không trúng gần đủ 12 tháng để xử lý xóa/ẩn danh có phê duyệt | Tuân thủ retention mà không lưu trữ tràn dữ liệu PII vô dụng |
| 7 | HR_L2 | Khai báo sự cố rò rỉ PII qua form breach với bộ đếm 72 giờ hiển thị | Bảo đảm nghĩa vụ thông báo NĐ 13/2023 không bị bỏ lỡ vì trễ thủ tục |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Mã hóa, mã hóa tier và row-level security enforce ở SYS-CORE-BACKEND; web hiển thị theo kết quả check quyền tập trung, không tự quyết mask cục bộ.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | RBAC dùng đúng 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5, ...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight; "manager" trong ma trận PII map vào vai quản lý tương ứng của registry (ví dụ SALES_L4 cho TL sale) | Ma trận quyền cấu hình theo vai ngoài registry bị từ chối khi lưu |
| BR-002 | Mọi lượt xem/sửa lương, HĐLĐ, dữ liệu C1 ghi audit log bất biến hash-chain (ai — khi nào — giá trị trước/sau); mọi thao tác ghi có actor + timestamp + lý do; log PII giữ theo tier Confidential/Restricted ≥10 năm cho dữ liệu lương/chứng từ | Xem/sửa không log là lỗi hệ thống (job đối chiếu phát hiện); thiếu lý do khi sửa → không cho lưu |
| BR-003 | Ma trận quyền xem lương/cost (theo `hr.md` B10): HR_L2 xem + sửa lương; HR_L1 không xem lương (chỉ tổng cost nhóm); BOD (CEO/CFO) xem; FIN_L2 chỉ xem khi thẩm định Rate Card (mỗi lần log); quản lý/TL không xem lương cá nhân — chỉ tổng cost nhóm mình; SYS_ADMIN không xem giá trị (quản hạ tầng) nhưng xem log PII — xem log cũng bị log | Truy cập ngoài ma trận → trả dữ liệu masked rỗng + ghi attempt vào log; không có nút "xin xem tạm" ngoài luồng |
| BR-004 | Quarterly access review bắt buộc cho truy cập dữ liệu C1 (HR_L2 + SYS_ADMIN — nối chu trình REQ-BOD-007); kiêm nhiệm CFO/CTO phải có compensating control (REQ-BOD-002) — quyền xem PII của người kiêm nhiệm nằm trong scope review | Quyền C1 không review 2 quý → tự vô hiệu; báo cáo review thiếu phần PII → không đạt điều kiện ký |
| BR-005 | SSO/MFA tập trung: thao tác sửa dữ liệu C1 và xem báo cáo lương yêu cầu phiên SSO hợp lệ; PII nhân sự luôn ở mức Confidential/Restricted — không hiển thị plaintext cho vai không phép, kể cả trong bản xuất | Phiên hết hạn giữa lúc sửa → giữ draft, xác thực lại trước khi lưu; bản xuất cho vai sai → bị chặn sinh file |
| BR-006 | Retention PII: hồ sơ nhân sự theo pháp luật lao động; lương/chứng từ kế toán 10 năm (Luật Kế toán 2015); hồ sơ ứng tuyển không trúng 12 tháng; hết hạn → xóa/ẩn danh có phê duyệt + log hủy; nghĩa vụ lưu trữ luật định ưu tiên hơn yêu cầu xóa | Hồ sơ ứng tuyển quá 12 tháng chưa xử lý → cảnh báo đỏ trên web; xóa không phê duyệt → chặn + log |
| BR-007 | Xuất dữ liệu C1 chỉ theo mẫu chuẩn (thuế/BHXH) — cấm xuất raw; mỗi lần xuất có log ai — khi nào — cho cơ quan nào; breach PII: báo legal trong 4 giờ, thông báo A06 trong 72h theo NĐ 13/2023 | Nút "xuất Excel" tự do trên dữ liệu lương không tồn tại; cố tình dump dữ liệu → chặn tầng API + alert |
| BR-008 | Quy trình HR chi tiết (định mức, biểu mẫu, luồng duyệt nội bộ HR) vẫn chờ khách hàng xác nhận `[KXN-18]` — feature này thiết kế khung kiểm soát PII độc lập với nội dung quy trình, phần chưa chốt ghi nhận như assumption, không tự quyết; phân công vai duyệt các luồng liên quan cũng chưa được xác nhận chính thức `[KXN-19]` | Khi KXN-18/19 chốt, chỉ cấu hình lại luồng/tham số — không phải redesign khung kiểm soát PII |

---

## 4. Phân Quyền

| Hành động | HR_L1 | HR_L2 | BOD_CEO / BOD_CFO_CTO | FIN_L2 | SYS_ADMIN | Vai quản lý nhóm (SALES_L4, OPS lead) |
|-----------|-------|-------|------------------------|--------|-----------|----------------------------------------|
| Xem lương cá nhân | ❌ | ✅ | ✅ | ◐ (chỉ khi thẩm định Rate Card — log mỗi lần) | ❌ | ❌ |
| Sửa lương/dữ liệu C1 | ❌ | ✅ (lý do bắt buộc) | ❌ | ❌ | ❌ | ❌ |
| Xem cost/hour cá nhân | ❌ | ✅ | ✅ | ◐ (khi thẩm định — log) | ❌ | ❌ |
| Xem tổng cost nhóm mình | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ (chỉ nhóm mình) |
| Xem log truy cập PII | ✅ (phần liên quan nghiệp vụ mình) | ✅ | ✅ | ❌ | ✅ (xem log cũng bị log) | ❌ |
| Xuất dữ liệu C1 (mẫu thuế/BHXH) | ◐ (soạn phiếu) | ✅ (duyệt xuất) | ◐ (nhận báo cáo) | ❌ | ❌ | ❌ |
| Chạy báo cáo review truy cập C1 | ❌ | ✅ | ◐ (nhận kết quả) | ❌ | ✅ (phần kỹ thuật) | ❌ |
| Khai báo breach PII | ✅ (báo ngay khi phát hiện) | ✅ | ◐ (quyết phát hành thông báo) | ❌ | ❌ | ✅ (báo ngay khi phát hiện) |

---

## 5. Trường Hợp Đặc Biệt

- Yêu cầu xóa dữ liệu nhân sự khi còn nghĩa vụ lưu trữ (kiểm toán, luật lao động, thuế): nghĩa vụ lưu trữ luật định ưu tiên hơn yêu cầu xóa — ẩn danh hóa phần có thể, giữ phần bắt buộc, ghi nhận lý do có log; người xin xóa được thông báo rõ căn cứ.
- Sự cố rò rỉ PII do nền tảng thứ ba (hộp mail, công cụ tuyển dụng): BC vẫn khai báo breach trong phạm vi dữ liệu BC kiểm soát, phối hợp khiếu nại theo chuỗi DPA — trách nhiệm gốc thuộc nền tảng, nhưng timer 72h trên web vẫn chạy.
- Khu vực xám: cựu quản lý từng xem tổng cost nhóm khi còn làm — sau offboard quyền thu hồi 24h; lịch sử truy cập của họ trong thời gian còn làm việc vẫn nằm trong log PII và xuất hiện khi điều tra.
- Xuất dữ liệu cho cơ quan thuế/BHXH: chỉ mẫu chuẩn, HR_L2 duyệt, log từng lần; yêu cầu xuất "thêm chút dữ liệu ngoài mẫu" bị từ chối và ghi nhận như attempt bất thường.
- Quy trình HR chi tiết chưa chốt `[KXN-18]` (biểu mẫu, luồng duyệt nội bộ HR) và phân công vai duyệt chờ xác nhận `[KXN-19]`: khung mask + log + retention của feature này không phụ thuộc kết quả chốt — khi chốt xong chỉ cấu hình luồng; các điểm phụ thuộc ghi rõ trong spec để Phase 3 theo dõi.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Phiếu xuất/khám phá dữ liệu PII ngoại lệ (xuất mẫu thuế/BHXH, điều tra nội bộ)

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit)──► [PENDING_HR_L2_APPROVAL] ──(duyệt)──► [APPROVED] ──(xuất có log)──► [EXPORTED]
                            │                                    │
                            │ (từ chối)                         │ (hết thời hạn phiếu)
                            ▼                                    ▼
                       [REJECTED]                           [EXPIRED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `PENDING_HR_L2_APPROVAL` | HR_L1 / vai được phân công | Đủ: phạm vi dữ liệu, mẫu chuẩn, mục đích, cơ quan nhận |
| `PENDING_HR_L2_APPROVAL` | Duyệt | `APPROVED` | HR_L2 | Mẫu khớp danh mục mẫu chuẩn; thời hạn phiếu được đặt |
| `PENDING_HR_L2_APPROVAL` | Từ chối | `REJECTED` | HR_L2 | Reason code bắt buộc |
| `APPROVED` | Chạy xuất | `EXPORTED` | Hệ thống | File có watermark + log xuất chi tiết |
| `APPROVED` | Quá thời hạn phiếu | `EXPIRED` | Hệ thống | Phiếu hết hạn tự đóng; xuất lại tạo phiếu mới |

**Quy tắc:**
- Không có xuất trực tiếp ngoài phiếu — mọi nút xuất dữ liệu C1 đều dẫn về luồng này.
- Song song, dữ liệu PII có vòng đời retention: `ACTIVE` → `RETENTION_DUE` (đủ hạn — hệ thống gắn cờ) → `ANONYMIZED/DELETED` (có phê duyệt + log hủy) hoặc `RETAINED_LEGAL` (giữ theo nghĩa vụ luật định, lý do ghi nhận).

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `employee_pii` | `id`, `employee_id`, `pii_class` (C1/C2/C3), `salary_enc`, `id_number_enc`, `bank_account_enc` | FK → `employees.id` | Giá trị C1 mã hóa; web chỉ nhận masked view |
| `pii_access_log` | `id`, `employee_id`, `viewer_id`, `action` (view/edit), `before`, `after`, `reason`, `occurred_at` | FK → `employees.id`, `users.id` | Bất biến hash-chain; nguồn báo cáo review quý |
| `pii_export_ticket` | `id`, `requested_by`, `scope`, `template_code`, `state`, `approved_by`, `expires_at`, `file_ref` | FK → `users.id` | Machine-state của phiếu xuất ngoại lệ |
| `pii_retention_item` | `id`, `employee_id` / `application_id`, `data_group`, `due_at`, `state`, `disposed_by`, `dispose_reason` | FK logic → hồ sơ gốc | Ứng tuyển 12 tháng; lương/chứng từ 10 năm |
| `breach_incident` | `id`, `reported_by`, `detected_at`, `legal_notified_at`, `notify_due_at` (72h), `a06_ref` | — | Timer 72h hiển thị trên web; xử lý ở quy trình sự cố |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ — chi tiết ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: HR_L1 không thấy lương | HR_L1 mở hồ sơ nhân sự | Trang render | Trường lương cá nhân masked rỗng, không có nút hiện; lượt mở được ghi vào pii_access_log | [ ] |
| SC-002: FIN_L2 xem khi thẩm định | FIN_L2 mở màn thẩm định Rate Card | Xem cost cá nhân | Hiển thị được nhưng mỗi lần xem sinh log riêng (meta-log); ngoài ngữ cảnh thẩm định → masked | [ ] |
| SC-003: Cấm xuất raw | Vai bất kỳ trên màn danh sách lương | Tìm nút "xuất Excel" tự do | Không tồn tại; duy nhất luồng phiếu mẫu chuẩn (thuế/BHXH) khả dụng và phải HR_L2 duyệt | [ ] |
| SC-004: Ứng tuyển quá hạn | Hồ sơ ứng tuyển không trúng đủ 12 tháng | Job retention chạy | Cảnh báo đỏ trên web; chỉ xóa/ẩn danh sau phê duyệt; log hủy ghi rõ người — thời điểm — lý do | [ ] |
| SC-005: Timer breach 72h | Phát hiện rò rỉ PII | HR khai báo form breach | Timer 72h bắt đầu; nhắc legal 4h đầu; quá hạn chưa phát hành A06 → alert đỏ BOD | [ ] |

> **Liên kết:** SC-001/SC-002 → REQ-HR-010 (ma trận quyền lương/cost); SC-003 → REQ-HR-010 (cấm xuất raw, mẫu chuẩn có log); SC-004 → REQ-HR-010 (retention 12 tháng ứng tuyển); SC-005 → REQ-HR-010 (breach 72h NĐ 13/2023).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/rbac-audit/[screen-group].md` |
| Bản counterpart (mã hóa + tier enforcement) | `.mc-data/docs/phase2-features/core-backend/rbac-audit/` (SYS-CORE-BACKEND) |
