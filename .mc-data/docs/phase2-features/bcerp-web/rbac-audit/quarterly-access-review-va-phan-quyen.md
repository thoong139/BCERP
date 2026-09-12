# Tính Năng: Quarterly Access Review & Phân Quyền

> **Dựa trên:** REQ-BOD-007 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** RBAC & Audit Log (SYS-BCERP-WEB)
> **Module:** RBAC & Audit Log (MOD-RBAC-AUDIT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/rbac-audit/[screen-group].md`, `phase5-implementation/tasks/bcerp-web/rbac-audit/feat-003-impl.md`

> **Hướng dẫn ID:** FEAT-ID được tạo từ REQ-ID theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. Bản fan-out này dùng ID lane `FEAT-ERP-RBAC-003` — bản riêng của touchpoint SYS-BCERP-WEB (các bản counterpart: SYS-CORE-BACKEND, SYS-INTEGRATION-GW).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-RBAC-003 |
| Module | MOD-RBAC-AUDIT |
| Yêu cầu nghiệp vụ | REQ-BOD-007 |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — RBAC nền GĐ1; chu kỳ review chạy từ go-live) |
| Phụ thuộc | FEAT-ERP-RBAC-005 (nền tảng RBAC & SSO/MFA — nguồn dữ liệu user × role × level) |
| Ghi chú Expert (A7) | Mục A7 của `bod.md` đang chờ đánh giá chuyên gia đầy đủ; điều chỉnh liên quan đã chốt qua stakeholder review 12/09: DI-006 gỡ OPS_CX/FIN_COMPL khỏi registry 18 vai (CX Head → OPS_PLAN, Compliance → FIN_L2 + BOD oversight) nên ma trận review không có dòng cho 2 vai đã bị từ chối; chi tiết tại `bod.md` Mục A7 và `stakeholder-review.md` Phần F.3 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Đưa chu trình kiểm soát phân quyền định kỳ lên web nội bộ: mỗi quý, ngày 1–10, hệ thống tổng hợp báo cáo user × role × level (kèm inventory credentials do GW cung cấp) để CEO đối chiếu, đánh dấu giữ/thu hồi từng dòng, quyết định gán/thu hồi role và ký xác nhận. Chu trình này bảo đảm "quyền chỉ tồn tại khi còn được kiểm chứng định kỳ" — ai không qua review thì quyền tự vô hiệu.

**Phạm vi:**
- Bao gồm: workspace review trên web — bảng đối chiếu user × role × level × phạm vi dữ liệu, đánh dấu giữ/thu hồi, phê duyệt gán/thu hồi role thuộc độc quyền CEO, chữ ký CEO lưu vào access review record; màn theo dõi trạng thái các lệnh thực thi của SYS_ADMIN sau duyệt; cảnh báo token đến hạn rotate (T-7) từ inventory GW; checklist offboarding (thu hồi + rotate ≤24h) có điểm xác nhận của CTO; hiển thị quyền tự vô hiệu khi không được review 2 quý liên tiếp; ràng buộc lifecycle người dùng (thử việc không có quyền phê duyệt, guest tối đa 90 ngày).
- Không bao gồm: sinh báo cáo và tự vô hiệu quyền (SYS-CORE-BACKEND thực thi — web hiển thị và nhận lệnh); inventory credentials/token và ngày rotate (SYS-INTEGRATION-GW — bản counterpart); quy trình offboarding HR gốc và thu hồi TKQC trên nền tảng Ads (REQ-HR-001 — ranh giới HR–OPS); thao tác quản trị vault (REQ-BOD-008).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CEO | Mở workspace review ngày 1 đầu quý, thấy toàn bộ user × role × level kèm đề xuất giữ/thu hồi từ dữ liệu sử dụng thực tế | Chốt phân quyền của toàn công ty trong 10 ngày trên một màn hình duy nhất |
| 2 | BOD_CEO | Đánh dấu giữ/thu hồi từng dòng, ký xác nhận điện tử và thấy bằng chứng ký lưu vào record | Có minh chứng kiểm soát đầy đủ cho kiểm toán nội bộ và bên ngoài |
| 3 | BOD_CEO | Duyệt các yêu cầu gán/thu hồi role do quản trị viên đề xuất | Bảo đảm không ai tự gán quyền — kể cả SYS_ADMIN cho chính mình |
| 4 | BOD_CFO_CTO | Xuất nộp báo cáo quyền của chính mình (vai CFO/CTO, phạm vi T3/T4, credentials) cho CEO review | Tuân thủ vai bị review theo compensating control REQ-BOD-002 |
| 5 | SYS_ADMIN | Xem hàng đợi lệnh thực thi (thêm/bớt role, revoke token) sau khi CEO đã duyệt | Thực thi đúng lệnh, đúng người, có dấu vết — không tự quyết |
| 6 | BOD_CFO_CTO | Nhận cảnh báo token/credentials đến hạn rotate trong 7 ngày tới | Chủ động rotate trước khi vi phạm chu kỳ ≥90 ngày |
| 7 | BOD_CEO | Xem checklist offboarding của nhân viên nghỉ việc: thu hồi quyền ERP, rotate credentials ≤24h, điểm xác nhận CTO | Bảo đảm người rời công ty không còn bất kỳ đường truy cập nào |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Sinh báo cáo, tự vô hiệu quyền và enforcement role nằm ở SYS-CORE-BACKEND; web là nơi đối chiếu, quyết định và ký.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | RBAC dùng đúng 18 vai chuẩn hóa (OPS_AD, OPS_PLAN, FIN_L2, SALES_L1–L5, ...); không dùng OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight; workspace chỉ hiển thị vai thuộc registry | Yêu cầu gán vai ngoài 18 vai bị từ chối khi lưu; dòng vai không hợp lệ không thể xuất hiện trong bảng review |
| BR-002 | Mọi thao tác trong chu trình (đánh dấu, duyệt gán/thu hồi, ký, thực thi) ghi audit log bất biến hash-chain ≥10 năm (WORM với log phân quyền); mỗi thao tác có actor + timestamp + lý do | Thiếu lý do khi đánh dấu "thu hồi" → không cho lưu dòng; attempt can thiệp log bị chặn mọi tầng |
| BR-003 | Quarterly access review bắt buộc: hoàn tất trong 10 ngày đầu quý, có bằng chứng ký CEO; quyền chưa được review 2 quý liên tiếp tự vô hiệu (CORE đặt) cho đến khi review xong; CEO ký review không ủy quyền | Hết hạn 10 ngày → nhắc escalation trên web; quyền `SUSPENDED` hiển thị rõ nguyên nhân và đường khôi phục sau review |
| BR-004 | Kiêm nhiệm CFO/CTO phải có compensating control (REQ-BOD-002): dòng quyền của BOD_CFO_CTO gắn cờ "bị review — xuất nộp bởi chính người bị review", tách khu riêng trong workspace | Thiếu khu riêng cho dòng kiêm nhiệm → workspace không đạt điều kiện mở ký; cố gắng CEO bỏ qua dòng CFO/CTO bị chặn validate |
| BR-005 | SSO/MFA tập trung: ký review và duyệt gán/thu hồi role yêu cầu phiên SSO hợp lệ; PII nhân sự trong hồ sơ user (lương, cost) hiển thị mức Confidential/Restricted — mask theo vai | Phiên hết hạn giữa lúc ký → giữ draft đánh dấu, bắt buộc xác thực lại trước khi ký |
| BR-006 | Gán/thu hồi role chỉ thực thi sau phê duyệt CEO — SYS_ADMIN không tự gán quyền kể cả cho chính mình; lệnh thực thi ghi ai thực thi, theo lệnh nào | SYS_ADMIN gọi API gán role trực tiếp → CORE từ chối, mọi attempt log |
| BR-007 | Lifecycle ràng buộc: người thử việc/freelancer không có quyền phê duyệt; guest tài khoản tối đa 90 ngày (gia hạn phải duyệt); offboarding → thu hồi quyền + rotate credentials ≤24h, checklist có xác nhận CTO; nghỉ đột xuất chạy offboarding khẩn 24h, lệch chuẩn ghi vào kỳ review | Gán quyền phê duyệt cho tài khoản trạng thái thử việc/freelancer → chặn khi lưu; guest quá 90 ngày → tự khóa, chỉ mở sau duyệt gia hạn |
| BR-008 | Quyết định tiền liên quan trong review (ví dụ hạn mức duyệt theo vai) bám khung ngưỡng 5/50/200 triệu VND đã chốt (DI-001) + escalation lên cấp trên khi vượt thẩm quyền; chi tiết định mức theo vai là tham số effective-dated do REQ-BOD-009 quản | Thiếu tham số hiệu lực cho vai → dòng đó hiển thị "chưa cấu hình" và không thể ký khối liên quan |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN | Vai khác (registry 18 vai) |
|-----------|---------|-------------|-----------|----------------------------|
| Xem workspace review (toàn bộ) | ✅ | ◐ (khu quyền của mình để xuất nộp) | ❌ | ❌ |
| Đánh dấu giữ/thu hồi từng dòng | ✅ | ❌ | ❌ | ❌ |
| Đề xuất gán/thu hồi role | ❌ | ✅ (đề xuất) | ✅ (đề xuất theo change CTO duyệt) | ❌ |
| Duyệt gán/thu hồi role | ✅ (độc quyền) | ❌ | ❌ | ❌ |
| Ký quarterly review | ✅ (không ủy quyền) | ❌ | ❌ | ❌ |
| Thực thi lệnh sau duyệt | ❌ | ❌ | ✅ (mọi thao tác log) | ❌ |
| Xem cảnh báo rotate T-7 | ✅ | ✅ | ◐ (danh sách kỹ thuật, không plaintext) | ❌ |
| Xem checklist offboarding | ✅ | ✅ (xác nhận checklist) | ◐ (phần lệnh kỹ thuật) | ❌ |

---

## 5. Trường Hợp Đặc Biệt

- CEO vắng dài ngày trong kỳ review: không ủy quyền — các quyền không được ký sẽ tự vô hiệu (an toàn theo thiết kế); khi CEO quay lại ký bổ sung, hệ thống khôi phục hàng loạt các quyền đã đánh dấu "giữ" theo draft đã lưu.
- Nghỉ đột xuất (bỏ việc, kỷ luật): offboarding khẩn 24h — web hiển thị trạng thái lệch chuẩn (sau hạn) để ghi nhận vào kỳ review tiếp theo; thu hồi TKQC trên nền tảng Ads do OPS thực thi theo ranh giới REQ-HR-001, web chỉ theo dõi SLA handoff.
- Guest/freelancer cần kéo dài dự án quá 90 ngày: tài khoản tự khóa ở ngày 91; tiếp tục làm việc chỉ khi có phê duyệt gia hạn của CEO — không có cơ chế "gia hạn ngầm" theo thời gian.
- SYS_ADMIN nghỉ việc: chính SYS_ADMIN bị offboard theo cùng checklist — không tồn tại tài khoản "admin vĩnh viễn"; credentials liên quan rotate bắt buộc ≤24h kể cả khi chưa đến chu kỳ 90 ngày.
- Gán vai cho người kiêm nhiệm (CFO+CTO): hệ thống tự gắn cờ xung đột và buộc luồng compensating control (FEAT-ERP-RBAC-001); việc tách vai sau này chỉ là cập nhật binding vai hiệu lực theo ngày, không phải dự án kỹ thuật mới.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Kỳ Quarterly Access Review

**Sơ đồ trạng thái:**
```
[NOT_STARTED] ──(ngày 1 quý)──► [OPENED] ──(CEO bắt đầu đối chiếu)──► [IN_REVIEW]
                                    │                                     │
                                    │ (hết ngày 10 chưa xong)             │ (CEO ký)
                                    ▼                                     ▼
                              [OVERDUE + escalate]                 [CEO_SIGNED]
                                                                          │
                                                              (SYS_ADMIN thực thi lệnh)
                                                                          ▼
                                                                     [EXECUTED] ──(đối soát lệnh đủ)──► [CLOSED]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `NOT_STARTED` | Job quý mở kỳ | `OPENED` | Hệ thống | Đủ dữ liệu user × role × level + inventory GW |
| `OPENED` | Bắt đầu đối chiếu | `IN_REVIEW` | BOD_CEO | Ít nhất 1 dòng được đánh dấu |
| `OPENED` / `IN_REVIEW` | Quá ngày 10 | `OVERDUE` | Hệ thống | Escalation + nhắc trên web và alert |
| `IN_REVIEW` | CEO ký | `CEO_SIGNED` | BOD_CEO (không ủy quyền) | Tất cả dòng đã có quyết định giữ/thu hồi |
| `CEO_SIGNED` | Thực thi lệnh thu hồi/gán | `EXECUTED` | SYS_ADMIN | Mỗi lệnh map 1:1 với dòng đã duyệt |
| `EXECUTED` | Đối soát đủ lệnh | `CLOSED` | Hệ thống | Không còn lệnh treo; record lưu làm bằng chứng |

**Quy tắc:**
- Kỳ `CLOSED` không mở lại — sai sót xử lý ở kỳ tiếp theo hoặc qua lệnh gán/thu hồi ad-hoc có phê duyệt CEO riêng.
- Song song, từng quyền (role binding) có chu kỳ: `ACTIVE` → `SUSPENDED` (2 quý không review — hệ thống tự đặt) → `ACTIVE` (sau review) hoặc `REVOKED`.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `access_review_cycle` | `id`, `quarter`, `state`, `opened_at`, `signed_by`, `signed_at`, `closed_at` | — | Machine-state chính của workspace |
| `access_review_line` | `id`, `cycle_id`, `user_id`, `role`, `level`, `data_scope`, `credential_ref`, `decision`, `reason_code` | FK → `access_review_cycle.id`, `users.id` | 1 dòng = 1 quyền của 1 user; dòng CFO/CTO gắn cờ kiêm nhiệm |
| `role_assignment_order` | `id`, `user_id`, `role`, `action` (grant/revoke), `approved_by`, `approved_at`, `executed_by`, `executed_at` | FK → `users.id` | Chỉ sinh sau duyệt CEO; thực thi 1:1 |
| `user_account` | `id`, `employee_code`, `account_state`, `is_probation`, `guest_expires_at` | FK → `employees.id` | Thử việc/freelancer chặn quyền duyệt; guest ≤90 ngày |
| `offboarding_checklist` | `id`, `user_id`, `revoke_erp_at`, `rotate_credentials_at`, `cto_confirmed_at`, `is_urgent`, `sla_state` | FK → `users.id` | Hạn 24h; lệch chuẩn ghi vào kỳ review |
| `credential_rotation_alert` | `id`, `credential_ref`, `due_at`, `alert_sent_at` (T-7) | FK logic → inventory GW | Nguồn GW, web hiển thị |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ — chi tiết ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Mở kỳ review đúng hạn | Quý mới bắt đầu | Job ngày 1 chạy đủ dữ liệu | Kỳ chuyển `OPENED`; CEO thấy workspace đầy đủ; nhắc lịch hoàn tất trong 10 ngày | [ ] |
| SC-002: SYS_ADMIN tự gán quyền | SYS_ADMIN có yêu cầu thay đổi role | Gọi thao tác gán trực tiếp | CORE từ chối — chỉ CEO duyệt được; attempt log; hàng đợi thực thi không sinh lệnh | [ ] |
| SC-003: Quyền tự vô hiệu | Quyền X không có record review 2 quý liên tiếp | Hệ thống chạy job cuối quý | X chuyển `SUSPENDED`; web hiển thị trạng thái vô hiệu kèm nguyên nhân; người dùng mất chức năng gắn với X | [ ] |
| SC-004: Offboarding đúng SLA | Nhân viên có ngày nghỉ việc cuối | Checklist kích hoạt | Thu hồi ERP + rotate credentials ≤24h; thiếu xác nhận CTO → checklist đỏ, ghi lệch chuẩn vào kỳ review | [ ] |

> **Liên kết:** SC-001/SC-003 → REQ-BOD-007 (chu kỳ 10 ngày + tự vô hiệu 2 quý); SC-002 → REQ-BOD-007 (BR-BOD-007.1); SC-004 → REQ-BOD-007 (offboarding ≤24h).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI | `phase4-ux/bcerp-web/rbac-audit/[screen-group].md` |
| Bản counterpart (CORE sinh báo cáo + GW inventory) | `.mc-data/docs/phase2-features/core-backend/rbac-audit/`, `.mc-data/docs/phase2-features/integration-gw/rbac-audit/` |
