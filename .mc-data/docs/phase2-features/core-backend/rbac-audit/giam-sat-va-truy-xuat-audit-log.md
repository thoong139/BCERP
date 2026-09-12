# Tính Năng: Giám Sát & Truy Xuất Audit Log

> **Dựa trên:** REQ-BOD-005 trong `phase1-business/departments/bod/bod.md` (Phần A)
> **Phân hệ:** BCERP Core Backend (SYS-CORE-BACKEND)
> **Module:** RBAC & Audit Log (MOD-RBAC-AUDIT)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/core-backend/rbac-audit/[screen-group].md`, `phase5-implementation/tasks/core-backend/rbac-audit/feat-core-rbac-002-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-RBAC-002 |
| Module | MOD-RBAC-AUDIT |
| Yêu cầu nghiệp vụ | REQ-BOD-005 |
| Người dùng liên quan | BOD_CEO, BOD_CFO_CTO, SYS_ADMIN (trách nhiệm kỹ thuật lưu trữ, không xem nội dung nghiệp vụ ngoài scope) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP — nền móng GĐ1, không bổ sung sau được) |
| Phụ thuộc | FEAT-CORE-RBAC-005 (nền tảng RBAC & SSO/MFA tập trung — phân quyền xem log dựa trên RBAC engine); Phụ thuộc logic FEAT-CORE-RBAC-001 (meta-log và log compensating control ghi vào cùng audit service) |
| Ghi chú Expert (A7) | bod.md Mục A7 chưa ghi điều chỉnh nào sau Expert Review — spec bám nguồn Phần B (B5) của bod.md và BR-FIN-501/502/503 của finance.md |

---

## 1. Mô Tả Tính Năng

**Mục đích:**

Cung cấp audit service trung tâm của BCERP: ghi mọi sự kiện tiền/hợp đồng/phân quyền thành log bất biến append-only hash-chain, cho phép BOD giám sát và truy xuất theo chuỗi old → new value + reason code, đồng thời tự kiểm tra toàn vẹn chuỗi hash hằng ngày. Đây là nền móng giai đoạn 1 — một khi dữ liệu tiền đã chạy, kiến trúc WORM và hash-chain không thể bổ sung lại sau.

**Phạm vi:**

- Bao gồm:
  - Audit service ghi tự động mọi sự kiện tiền/hợp đồng/phân quyền: ai (user, role), khi nào (timestamp), làm gì, trên đối tượng nào; mọi thay đổi giá trị ghi old → new value + reason code bắt buộc.
  - Hash-chain (mỗi bản ghi chứa hash bản ghi liền trước) + job kiểm tra toàn vẹn hằng ngày; đứt chuỗi → alert ngay CTO + BOD_CEO (kênh REQ-BOD-006).
  - Meta-log: việc xem audit log cũng bị log (ai xem, xem gì, khi nào) — meta-log cũng append-only và nằm trong hash-chain.
  - API tra cứu log theo thời gian/đối tượng/người; API xuất log ngoài báo cáo chuẩn có luồng phê duyệt CEO (≤2 ngày làm việc).
  - Giám sát retention WORM: log tiền/hợp đồng ≥10 năm, log hệ thống ≥7 năm; dashboard trạng thái retention; luồng xóa/archive hết hạn do CTO đề xuất + CEO duyệt theo quý — chính việc xóa cũng bị log.
- Không bao gồm:
  - Màn hình tra cứu web với watermark người xem và dashboard retention — do SYS-BCERP-WEB (counterpart); bản này là API/domain service mà web gọi.
  - Mobile tra cứu log — bị cấm tuyệt đối (dữ liệu Mật/Restricted, BR-BOD-005.3); MOBILE chỉ nhận alert đứt chuỗi qua REQ-BOD-006, không có requirement riêng.
  - Lưu trữ chứng từ gốc và backup/DR toàn hệ thống — thuộc FEAT-CORE-RBAC-007 (REQ-FIN-012); bản này chia sẻ bảng retention nhưng chỉ quản lý phần audit log.
  - Business logic của các phân hệ phát sinh sự kiện — chúng chỉ gọi audit service, không định nghĩa lại log.

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint là **headless API/domain service trên core backend**: tra cứu, xuất, giám sát toàn vẹn và retention đều là API; web nội bộ chỉ render kết quả, mọi ràng buộc enforce ở service layer.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | BOD_CEO | Tra cứu log theo thời gian/đối tượng (khách, TKQC, giao dịch, hợp đồng, phân quyền)/người qua API, kết quả hiển thị chuỗi old → new value kèm reason code | Tái lập chính xác diễn biến bất kỳ giao dịch tiền nào khi cần quyết định hoặc thanh tra |
| 2 | BOD_CEO | Xuất log ra ngoài báo cáo chuẩn thông qua luồng phê duyệt ≤2 ngày làm việc | Minh chứng cho thanh tra/kiểm toán theo đúng quy trình, không ai xuất lén |
| 3 | BOD_CFO_CTO | Xem trạng thái hash-chain hằng ngày trên API dashboard (kết quả job toàn vẹn) | Biết ngay log có bị can thiệp hay không, kịp thời kích hoạt điều tra |
| 4 | BOD_CFO_CTO | Đề xuất xóa/archive log đã hết hạn retention theo quý, chờ CEO duyệt | Dữ liệu tuân thủ đúng thời hạn pháp lý mà không tự ý hủy — việc xóa cũng được ghi log |
| 5 | Hệ thống (job hằng ngày) | Tự kiểm tra toàn vẹn hash-chain và phát alert ngay khi đứt chuỗi | Phát hiện can thiệp trong vòng 1 ngày, không phụ thuộc người nhớ chạy kiểm tra |
| 6 | Hệ thống (audit service) | Ghi meta-log mỗi lần ai đó xem log, và meta-log cũng nằm trong hash-chain | Chống truy cập lén: cả hành vi giám sát cũng bị giám sát |
| 7 | SYS_ADMIN | Vận hành job toàn vẹn, backup và retention mà không xem được nội dung nghiệp vụ của log ngoài scope | Phân tách trách nhiệm kỹ thuật và thẩm định nghiệp vụ (SoD tra cứu ≠ đối tượng bị tra cứu) |
| 8 | BOD_CEO | Xem báo cáo retention định kỳ (log sắp hết hạn WORM, dung lượng) | Chủ động duyệt archive/xóa theo quý thay vì bị động khi hệ thống đầy |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service (không tin UI).*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | (Dùng chung lane) RBAC chuẩn hóa 18 vai registry (BOD_CEO, BOD_CFO_CTO, SYS_ADMIN, HR_L1, HR_L2, FIN_L1, FIN_L2, SALES_L1–L5, OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; CUSTOMER chỉ portal). KHÔNG có OPS_CX/FIN_COMPL (DI-006 bị từ chối) — CX Head gán OPS_PLAN, Compliance gán FIN_L2 + BOD oversight | API từ chối vai ngoài registry; gán vai sai bị validation chặn |
| BR-002 | (Dùng chung lane) Audit log bất biến hash-chain ≥10 năm WORM với log tiền; mọi thao tác ghi có actor + timestamp + lý do — áp nguyên vòng đời của chính tính năng này | Thiếu reason code → không submit; nỗ lực sửa/xóa log thất bại ở tầng DB |
| BR-003 | (Dùng chung lane) Quarterly access review bắt buộc; compensating control kiêm nhiệm CFO/CTO (REQ-BOD-002) — bao gồm SoD tra cứu: người duyệt xuất log không được là người liên quan sự kiện bị tra cứu | Yêu cầu xuất vi phạm SoD bị từ chối, ghi meta-log nỗ lực |
| BR-004 | (Dùng chung lane) SSO/MFA tập trung; PII nhân sự (lương) Confidential/Restricted — log chứa PII bị mask theo vai khi trả kết quả tra cứu | Kết quả API trả kèm PII cho vai không đủ tier → service tự mask, không phụ thuộc UI |
| BR-005 | (Dùng chung lane) Phê duyệt vượt ngưỡng 5/50/200 triệu VND + escalation khi vượt thẩm quyền — luồng duyệt xuất log ngoài báo cáo chuẩn chạy chung hàng đợi phê duyệt BOD | Xuất không duyệt bị chặn ở service; yêu cầu xuất ghi rõ phạm vi + mục đích |
| BR-006 | Append-only ở tầng quyền DB: ứng dụng kết nối bằng account chỉ có INSERT/SELECT trên bảng log (chặn UPDATE/DELETE); không tồn tại interface xóa/sửa ở mọi tầng (UI, API, DB, script vận hành) — kể cả Super Admin | Mọi cố gắng UPDATE/DELETE thất bại; script vận hành chứa lệnh sửa log bị cấm đưa vào repo vận hành |
| BR-007 | Mỗi bản ghi log chứa hash bản ghi liền trước (hash-chain); job kiểm tra toàn vẹn chạy hằng ngày, kết quả ghi vào bảng trạng thái; đứt chuỗi → alert ngay CTO + BOD_CEO qua REQ-BOD-006, không có ack vô lý do | Job fail/quá hạn chạy → bản thân việc fail cũng phát alert (job giám sát job) |
| BR-008 | Meta-log: mỗi lần xem log (tra cứu, xuất, drill-down) ghi meta-log ai/xem gì/khi nào; meta-log append-only và nằm trong hash-chain; áp đồng nhất mọi vai kể cả Super Admin | Không có ngoại lệ — API tra cứu tự ghi meta-log trước khi trả kết quả |
| BR-009 | Tra cứu/xuất log ngoài báo cáo chuẩn bắt buộc phê duyệt BOD_CEO ≤2 ngày làm việc; yêu cầu ghi phạm vi, mục đích; duyệt không ủy cho người liên quan sự kiện (SoD tra cứu ≠ đối tượng) | Xuất thiếu phê duyệt bị chặn; phê duyệt sai người bị validation từ chối |
| BR-010 | Retention phân tầng: log tiền/hợp đồng ≥10 năm (WORM, Luật Kế toán 2015); log hệ thống (đăng nhập, phân quyền, cấu hình, change) ≥7 năm; hồ sơ KYC/AML ≥5 năm (chi tiết lưu trữ chứng từ tại FEAT-CORE-RBAC-007) | Dữ liệu chưa hết hạn không được đưa vào đề xuất archive; retention chỉ được kéo dài, không rút ngắn |
| BR-011 | Xóa/archive log hết hạn: CTO đề xuất + BOD_CEO duyệt theo quý; chính việc xóa/archive cũng được ghi log (nội dung xóa, ai duyệt, khi nào); thanh tra/kiểm toán đang mở → giữ đến khi hồ sơ đóng | Xóa ngoài luồng/quý bị chặn; mọi thao tác hủy có phê duyệt không đúng vai bị từ chối |
| BR-012 | Sửa dữ liệu nghiệp vụ nhập sai KHÔNG sửa log/bản ghi gốc — luôn ghi giao dịch reversal có reason code, giữ dấu vết cũ → mới (khớp BR-FIN-202/BR-FIN-105) | API không cung cấp endpoint sửa bản ghi; lỗi nhập xử lý bằng bản ghi đối xứng |

---

## 4. Phân Quyền

| Hành động | BOD_CEO | BOD_CFO_CTO | SYS_ADMIN |
|-----------|---------|-------------|-----------|
| Tra cứu log (theo thời gian/đối tượng/người) | ✅ | ✅ | ❌ (nội dung nghiệp vụ ngoài scope; chỉ meta-log kỹ thuật) |
| Xem trạng thái hash-chain + kết quả job toàn vẹn | ✅ | ✅ | ✅ (trạng thái kỹ thuật, không nội dung log) |
| Đề xuất xuất log ngoài báo cáo chuẩn | ✅ | ✅ | ❌ |
| Duyệt xuất log | ✅ (bắt buộc, không ủy cho người liên quan sự kiện) | ❌ | ❌ |
| Thực thi xuất log sau duyệt | ❌ | ✅ (thực thi, có meta-log) | ✅ (hạ tầng xuất, không xem nội dung) |
| Đề xuất xóa/archive log hết hạn | ❌ | ✅ | ❌ |
| Duyệt xóa/archive theo quý | ✅ | ❌ | ❌ |
| Vận hành job toàn vẹn/backup/retention (kỹ thuật) | ❌ | ✅ (change được duyệt) | ✅ (thực thi sau duyệt) |
| Sửa/xóa trực tiếp bản ghi log | ❌ | ❌ | ❌ (không tồn tại interface ở mọi tầng) |

**Ghi chú phân quyền:** chỉ dùng 18 vai registry. SYS_ADMIN chịu meta-log như mọi vai (BR-FIN-502 — không ngoại lệ). CUSTOMER không có bất kỳ quyền nào trên audit log (portal chỉ xem view tổng hợp đã lọc tenant, không chạm log nội bộ).

---

## 5. Trường Hợp Đặc Biệt

- **Đứt hash-chain giữa lúc có giao dịch đang chạy:** job toàn vẹn phát hiện đứt chuỗi → alert ngay CTO + CEO; hệ thống không tự "vá" chuỗi — vùng nghi vấn bị đóng băng cho điều tra, các giao dịch tiền tiếp tục chạy nhưng được gắn cờ "chuỗi nghi vấn" để truy vết sau.
- **Thanh tra/kiểm toán yêu cầu phạm vi lớn:** dùng đúng luồng xuất có phê duyệt CEO; yêu cầu pháp lý chỉ được kéo dài thời hạn giữ log, không bao giờ rút ngắn dưới mức tối thiểu retention.
- **Log chứa PII nhân sự (tên, lương trong sự kiện phân quyền/cost):** service mask trường PII theo vai khi trả kết quả — HR_L1 không thấy giá trị lương ngay cả trong log; FIN_L2 xem khi thẩm định có log (REQ-HR-010).
- **Yêu cầu xuất log do chính người đề xuất là đối tượng bị tra cứu:** SoD tra cứu ≠ đối tượng — CEO không duyệt được cho chính mình trong trường hợp này (validation cấm), phải có người BOD còn lại duyệt.
- **Dung lượng WORM tăng nhanh do log 2.600+ TKQC:** hệ thống phân tầng theo loại sự kiện và nén lưu trữ lạnh sau 90 ngày mà không phá hash-chain (hash giữ nguyên, chỉ chuyển storage class); báo cáo retention cảnh báo trước khi gần ngưỡng dung lượng.
- **Sự kiện phát sinh với tần suất rất cao (job sync GW hourly):** audit service ghi theo batch append-only, đảm bảo thứ tự hash không đổi — batch fail thì cả batch rollback ở luồng nghiệp vụ tương ứng, không ghi nửa vời.
- **Hệ thống khôi phục sau sự cố (restore DR):** sau restore, job toàn vẹn phải đối chiếu hash từ điểm restore trở về trước; biên bản restore (FEAT-CORE-RBAC-007) đính kèm kết quả đối chiếu.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Yêu cầu xuất audit log (Audit Export Request) — luồng có phê duyệt

**Sơ đồ trạng thái:**
```
[DRAFT] ──(submit đủ phạm vi + mục đích)──► [PENDING_CEO_APPROVAL] ──(CEO duyệt)──► [APPROVED] ──(service xuất)──► [EXPORTED]
                                                 │                                     │
                                     (CEO từ chối + lý do)                 (hủy bởi người đề xuất)
                                                 ▼                                     ▼
                                            [REJECTED]                            [WITHDRAWN]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Submit | `PENDING_CEO_APPROVAL` | BOD_CEO, BOD_CFO_CTO | Ghi rõ phạm vi (khoảng thời gian, đối tượng), mục đích; SoD tra cứu ≠ đối tượng hợp lệ |
| `PENDING_CEO_APPROVAL` | Duyệt | `APPROVED` | BOD_CEO | MFA TOTP hợp lệ; ≤2 ngày làm việc SLA; quá hạn escalate + alert |
| `PENDING_CEO_APPROVAL` | Từ chối | `REJECTED` | BOD_CEO | Bắt buộc reason code |
| `PENDING_CEO_APPROVAL` | Hủy | `WITHDRAWN` | Người đề xuất | Ghi meta-log |
| `APPROVED` | Thực thi xuất | `EXPORTED` | Hệ thống (service) | File xuất có watermark người xem; meta-log ghi nội dung xuất |

**Quy tắc:** `EXPORTED`, `REJECTED`, `WITHDRAWN` là trạng thái kết thúc; tái xuất cùng phạm vi phải tạo yêu cầu mới. Toàn bộ chuyển tiếp nằm trong audit log hash-chain.

**Entity phụ:** Đề nghị archive/xóa retention (Disposal Proposal): `PROPOSED` (CTO, theo quý) → `APPROVED` (CEO) → `DISPOSED` (hệ thống thực thi, việc xóa tự ghi log) hoặc `LEGAL_HOLD` (đóng băng khi có thanh tra/điều tra — không được xóa, chỉ được kéo dài giữ).

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL đầy đủ tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `audit_event` | `event_id`, `actor`, `actor_role`, `timestamp`, `action`, `object_type`, `object_ref`, `old_value`, `new_value`, `reason_code`, `prev_hash`, `hash`, `channel` (web/api/mobile) | Độc lập trung tâm, được mọi service ghi | Append-only INSERT/SELECT only; WORM ≥10 năm với sự kiện tiền/hợp đồng, ≥7 năm log hệ thống |
| `meta_log` | `meta_id`, `viewer`, `viewed_event_scope`, `viewed_at`, `purpose` | Ghi mỗi lần truy cập `audit_event` | Append-only, nằm trong hash-chain; áp mọi vai kể cả Super Admin |
| `audit_export_request` | `request_id`, `requested_by`, `scope`, `purpose`, `status`, `approved_by`, `approved_at`, `file_ref` | FK → `audit_event` (theo phạm vi), `user_account` | SLA duyệt ≤2 ngày làm việc; watermark người xem trên file |
| `integrity_check_result` | `check_date`, `status` (`OK`/`BROKEN`), `broken_at_event_id`, `notified` | Tham chiếu `audit_event` | Job hằng ngày; BROKEN → alert CTO + CEO ngay |
| `retention_schedule` | `data_class`, `min_years`, `legal_basis` | Định tuyến `audit_event` vào WORM | Chỉ được kéo dài; căn cứ Luật Kế toán 2015, chính sách nội bộ |
| `disposal_proposal` | `proposal_id`, `proposed_by`, `scope`, `status`, `approved_by`, `disposed_at` | FK → `audit_event` hết hạn | Chạy theo quý; việc xóa tự ghi log |

---

## 8. Acceptance Criteria

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Ghi log có đủ 4 thành phần | Audit service hoạt động | Mọi sự kiện tiền/hợp đồng/phân quyền phát sinh | Bản ghi có actor (user+role), timestamp, action+đối tượng, old→new value + reason code; thiếu reason code → giao dịch nguồn không submit được | [ ] |
| SC-002: Chặn sửa/xóa log ở tầng DB | Kết nối DB dùng account ứng dụng | Gọi UPDATE/DELETE trên `audit_event` | Lệnh thất bại (quyền chỉ INSERT/SELECT); nỗ lực ghi vết trong meta-log; kể cả Super Admin không có đường khác | [ ] |
| SC-003: Meta-log áp mọi vai | BOD_CEO/CFO/SYS_ADMIN tra cứu log | Xem bất kỳ phạm vi nào | Meta-log ghi ai/xem gì/khi nào; meta-log cũng nằm trong hash-chain | [ ] |
| SC-004: Job toàn vẹn + alert đứt chuỗi | Có bản ghi bị can thiệp ngoài luồng (thử nghiệm kiểm soát) | Job hằng ngày chạy | Kết quả `BROKEN` với `broken_at_event_id`; alert đến CTO + CEO ngay qua REQ-BOD-006; alert không tắt nếu thiếu acknowledge + reason | [ ] |
| SC-005: Xuất log có phê duyệt | Yêu cầu xuất ngoài báo cáo chuẩn | Submit → CEO duyệt trong 2 ngày làm việc | File xuất có watermark người xem; quá hạn → escalate; duyệt không ủy cho người liên quan sự kiện | [ ] |
| SC-006: Retention WORM theo tầng | Log tiền đã ≥10 năm / log hệ thống ≥7 năm | CTO đề xuất archive, CEO duyệt | Việc xóa được thực hiện và chính việc xóa cũng bị log; log chưa hết hạn không xuất hiện trong đề xuất | [ ] |
| SC-007: Mask PII theo vai | Log chứa giá trị lương (từ sự kiện phân quyền cost) | HR_L1 gọi API tra cứu | Giá trị PII bị mask ở tầng service; HR_L2/BOD thấy đủ và lượt xem bị meta-log | [ ] |

> **Liên kết:** SC-001→003 map REQ-BOD-005 (bất biến + meta-log); SC-004 map REQ-BOD-005/REQ-BOD-006 (toàn vẹn); SC-005→006 map REQ-BOD-005 (xuất có duyệt + retention); SC-007 map REQ-BOD-005 + REQ-HR-010 (PII trong log).

---

## Tài Liệu Kĩ Thuật Liên Quan

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (tra cứu, xuất, trạng thái hash-chain, retention) | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (alert REQ-BOD-006, WORM storage FEAT-CORE-RBAC-007) | `technical-specs/integration-map.md` |
| Màn hình UI (tra cứu log, dashboard hash-chain, dashboard retention — counterpart WEB) | `phase4-ux/core-backend/rbac-audit/[screen-group].md` |
| Touchpoint counterpart | SYS-BCERP-WEB (fan-out cùng REQ-BOD-005); MOBILE không có touchpoint — chỉ nhận alert |
