# Tính Năng: Nghỉ phép: số dư tự động & duyệt phân cấp

> **Dựa trên:** REQ-HR-004 trong `phase1-business/departments/hr/hr.md` (Phần A)
> **Phân hệ:** Nhân sự — HR Core (SYS-CORE-BACKEND)
> **Module:** MOD-HR-CORE
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/hr/hr.md`, `documents/03_Quy_che_KPI_HR.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`

> **Hướng dẫn ID:** FEAT-ID được tạo từ REQ-ID theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. Với lane này FEAT-ID đã được registry fan-out chốt là `FEAT-CORE-HRCORE-004` (system SYS-CORE-BACKEND, module MOD-HR-CORE).

> **Phạm vi fan-out (touchpoint):** REQ-HR-004 xuất hiện ở 2 hệ thống — **SYS-BCERP-WEB** (primary: form đơn nghỉ, hàng đợi duyệt) và **SYS-CORE-BACKEND** (bản spec này: tích lũy số dư tự động, validation chặn vượt số dư, routing duyệt phân cấp, tự trừ capacity tuần). Tại touchpoint core backend, mọi business rule phải được enforce ở tầng service (không tin UI — ví dụ chặn duyệt vượt số dư phải làm ở validation tầng service chứ không chỉ ẩn nút duyệt); mọi thao tác có audit log bất biến và dữ liệu luôn xử lý trong tenant isolation.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-HRCORE-004 |
| Module | MOD-HR-CORE |
| Yêu cầu nghiệp vụ | REQ-HR-004 |
| Người dùng liên quan | Toàn bộ nhân viên (18-vai registry — lập đơn qua counterpart WEB), TL (duyệt ≤5 ngày), HR_L2 (duyệt >5 ngày/nghỉ không lương), DEPT-OPS (nhận capacity khả dụng giảm tự động), HR_L1 (đối soát) |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 1 (MVP) |
| Phụ thuộc | FEAT-CORE-HRCORE-001 (hồ sơ SSOT — trạng thái làm việc, TL trực tiếp); FEAT-CORE-HRCORE-003 (nghỉ đã duyệt không tính giờ công chuẩn) |
| Ghi chú Expert (A7) | A7.2: need mobile HR (duyệt phép khi di chuyển) ngoài scope SYS-MOBILE-INTERNAL hiện tại — xem lại khi mở rộng scope. Chi tiết tại `hr.md` Mục A7.3 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Quản lý toàn bộ vòng đời đơn nghỉ phép trên core backend: tích lũy phép năm **12 ngày/năm (1 ngày/tháng) tự động**, hiển thị số dư hiện hành theo thời gian thực, thực thi duyệt phân cấp tự động (**≤5 ngày: TL duyệt trong 24h; >5 ngày hoặc nghỉ không lương: HR_L2 duyệt trong 48h**), và **chặn duyệt vượt số dư ngay ở tầng validation của service**. Khi đơn được duyệt, hệ thống tự trừ số dư và tự giảm capacity tuần của nhân sự (luồng REQ-HR-009 — DEPT-OPS thấy capacity khả dụng giảm mà không cần thông báo tay).

**Phạm vi:**
- Bao gồm: entity số dư phép + giao dịch tích lũy/trừ (ledger đối soát được); đơn nghỉ với routing phân cấp tự động (SLA 24h/48h, nhắc + escalate TL→Manager, HR_L2→BOD); validation chặn vượt số dư ở tầng service; giấy khám bệnh cho nghỉ ốm ≥3 ngày; nghỉ đột xuất retro có lý do; nghỉ không lương >30 ngày (đóng băng allocation/capacity, KPI prorate/miễn); thai sản/ốm dài prorate/miễn theo xác nhận HR_L2; nội quy đăng ký nghỉ + chế tài nghỉ không phép theo nguồn 03 §8.
- Không bao gồm: form đơn, màn hình số dư, hàng đợi duyệt (SYS-BCERP-WEB — counterpart); allocation/capacity dự án chi tiết (REQ-HR-009/REQ-OPS — chỉ phát sự kiện trừ); KPI prorate cụ thể (REQ-HR-007 — chỉ phát cờ đầu vào); tính lương ngày nghỉ (DEPT-FINANCE).

**Nguồn domain bổ sung:** `documents/03_Quy_che_KPI_HR.md` mục 8 — nội quy đăng ký nghỉ phép/công tác (nghỉ buổi ½ ngày báo trước ½ ngày; 1–dưới 3 ngày báo ≥1 ngày; ≥3 ngày báo ≥4 ngày; duyệt "Quản lý trực tiếp + HCNS"; ngày làm việc không tính T7/CN/Lễ Tết; nghỉ hết phép không duyệt nghỉ riêng trừ bất khả kháng — ốm có chứng minh, tang sự) và chế tài (nghỉ không phép ≥2 lần buổi/ngày/tháng → cảnh cáo–đình chỉ; ≥5 ngày/tháng → chấm dứt HĐLĐ). Điểm chưa chốt: cộng dồn phép năm sang năm sau hay không — đề xuất Điều 113 BLLĐ 2019 (tối đa 3 tháng, thỏa thuận được dài hơn) `[CẦN CHỐT SỐ]` — assumption có tag, không tự quyết.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | Hệ thống (job tích lũy) | Cộng 1 ngày phép vào ngày tròn mỗi tháng làm việc cho từng nhân sự | Số dư luôn cập nhật tự động, không cộng tay |
| 2 | Nhân viên | Lập đơn nghỉ online và thấy số dư hiện hành ngay khi lập | Đơn không bị từ chối vì thiếu thông tin số dư |
| 3 | Hệ thống (validation) | Chặn duyệt mọi đơn vượt số dư ngay ở tầng service | Không thể lách qua UI bằng gọi API trực tiếp |
| 4 | Hệ thống (routing) | Tự route đơn theo phân cấp: ≤5 ngày → TL (24h); >5 ngày hoặc nghỉ không lương → HR_L2 (48h) | Người duyệt đúng thẩm quyền, không cần phân phối tay |
| 5 | TL | Duyệt đơn nghỉ ≤5 ngày của thành viên trong 24h | Kế hoạch nhóm không bị đình trệ quá SLA |
| 6 | HR_L2 | Duyệt đơn >5 ngày và nghỉ không lương trong 48h; xác nhận prorate/miễn cho thai sản/ốm dài | Ngoại lệ có thẩm quyền và chứng từ đầy đủ |
| 7 | Hệ thống (escalation) | Nhắc khi quá SLA duyệt và escalate TL → Manager, HR_L2 → BOD | Đơn không treo vô chủ |
| 8 | Nhân sự DEPT-OPS | Nhận sự kiện "capacity khả dụng giảm" khi đơn được duyệt | Lên kế hoạch task tuần không bị sốc do vắng người |
| 9 | HR_L1 | Đối soát ledger số dư (tích lũy – trừ – điều chỉnh) theo kỳ | Mọi biến động số dư có vết, kiểm kê được |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code ở tầng service của SYS-CORE-BACKEND, không dựa vào validation phía UI.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-HR4-01 | Tích lũy phép năm **12 ngày/năm = 1 ngày/tháng** làm việc, tự động (ledger); số dư hiển thị là giá trị tính từ ledger, không lưu số âm thầm | Nhập số dư tay bị chặn; điều chỉnh phải qua bản ghi điều chỉnh có duyệt HR_L2 |
| BR-HR4-02 | Đơn nghỉ kế hoạch phải nộp **trước ≥3 ngày làm việc**; riêng theo nội quy 03 §8: nghỉ buổi ½ ngày báo trước ½ ngày, 1–dưới 3 ngày báo ≥1 ngày, ≥3 ngày báo ≥4 ngày; ngày làm việc không tính T7/CN/Lễ Tết | Đơn không đạt mốc báo trước chuyển luồng "đột xuất" (retro có lý do) thay vì chặn im lặng |
| BR-HR4-03 | Routing phân cấp tự động: **≤5 ngày → TL duyệt 24h; >5 ngày hoặc nghỉ không lương → HR_L2 duyệt 48h**; quá SLA → nhắc; tiếp tục quá → escalate (TL → Manager; HR_L2 → BOD) | Duyệt sai cấp bị từ chối; escalate lặp theo chu kỳ đến khi xử lý |
| BR-HR4-04 | **Chặn duyệt vượt số dư ở tầng validation** (counterpart không có nút duyệt, nhưng service phải chặn độc lập) | Gọi API duyệt trực tiếp vẫn thất bại với mã lỗi số dư |
| BR-HR4-05 | Đơn được duyệt: tự trừ số dư (ledger) và **phát sự kiện giảm capacity tuần** cho luồng REQ-HR-009 — DEPT-OPS thấy capacity khả dụng giảm tự động, không thông báo tay | Hủy đơn sau duyệt phải phát sự kiện hoàn trả số dư + capacity |
| BR-HR4-06 | Nghỉ ốm **≥3 ngày** bắt buộc đính kèm giấy khám bệnh; các loại nghỉ khác tuân theo BLLĐ 2019 | Thiếu giấy khám → đơn ở trạng thái chờ bổ sung chứng từ, không duyệt được |
| BR-HR4-07 | Nghỉ hết phép: **không duyệt đơn nghỉ riêng**, trừ bất khả kháng (ốm có chứng minh, tang sự) — chuyển sang nghỉ không lương có duyệt HR_L2 | Duyệt vượt số dư với lý do thông thường bị chặn cứng |
| BR-HR4-08 | Nghỉ không phép theo nội quy 03 §8: **≥2 lần (buổi/ngày)/tháng → cảnh cáo–đình chỉ; ≥5 ngày không phép/tháng → chấm dứt HĐLĐ** — hệ thống đếm và gắn cờ cho HR_L2 xử lý theo thủ tục | Vi phạm không tự động chấm dứt — chỉ gắn cờ + tổng hợp để con người quyết định đúng thủ tục |
| BR-HR4-09 | Nghỉ không lương **>30 ngày** → đóng băng allocation/capacity; thai sản/ốm dài: prorate/miễn KPI theo xác nhận HR_L2 (phát cờ đầu vào cho REQ-HR-007) | Không đóng băng là lỗi; cờ prorate thiếu người xác nhận HR_L2 không có hiệu lực |
| BR-HR4-10 | Phép năm chưa dùng cộng dồn sang năm sau hay không **chưa chốt** — thiết kế ledger hỗ trợ cấu hình carry-over theo năm (đề xuất Điều 113 BLLĐ 2019: tối đa 3 tháng, thỏa thuận được dài hơn) `[CẦN CHỐT SỐ-phepnam]` | Hệ thống chạy mặc định không carry-over cho đến khi chủ dự án chốt; bật carry-over chỉ qua cấu hình có log |
| BR-HR4-11 | Mọi thao tác lập/duyệt/hủy/điều chỉnh đơn có **audit log bất biến**; dữ liệu số dư + đơn nằm trong tenant isolation | Thiếu log thì giao dịch rollback |

**Quy tắc xuyên phân hệ (bắt buộc cho toàn bộ REQ-HR lane, trích từ Phase 1 — không được bỏ khi implement feature nào của MOD-HR-CORE):**

1. Hồ sơ nhân sự L1–L5 + mã vai là **SSOT**; nguồn dữ liệu bổ sung: `documents/03_Quy_che_KPI_HR.md` (HR v3.9, 4 track: Sales/Business Ops/HCNS/Marketing-Creative).
2. HĐLĐ cảnh báo hết hạn 90/60/30 ngày; chấm công 40h/tuần, trần 48h overtime (FEAT-CORE-HRCORE-002/003).
3. **Nghỉ phép 12 ngày/năm, số dư tự động, duyệt phân cấp; nội quy nghỉ phép + chế tài xử phạt theo 03 §8** (nội dung feature này).
4. Cost Rate Card version hóa (HR_L2 soạn + FIN_L2 thẩm định → BOD duyệt); billable tại nguồn (FEAT-CORE-HRCORE-006).
5. **Delegate duyệt timesheet cho TL vẫn ở mức `[KXN]` chưa chốt** — spec theo assumption có tag `[KXN-DI006]`, không tự quyết; luồng duyệt phép của chính TL do cấp quản lý trên trực tiếp xử lý cho đến khi được chốt.

---

## 4. Phân Quyền

| Hành động | Nhân viên (18-vai registry) | TL | HR_L1 | HR_L2 | BOD_CEO / BOD_CFO_CTO |
|-----------|------------------------------|-----|-------|-------|------------------------|
| Xem số dư + lịch nghỉ của mình | ✅ | ✅ | ✅ | ✅ | ✅ |
| Xem lịch nghỉ nhóm (phòng kế hoạch) | ❌ | ✅ (nhóm mình) | ✅ | ✅ | ✅ |
| Lập đơn nghỉ của mình | ✅ | ✅ | ✅ | ✅ | ✅ |
| Duyệt đơn ≤5 ngày | ❌ | ✅ (≠ người lập) | ❌ | ✅ | ❌ |
| Duyệt đơn >5 ngày / nghỉ không lương | ❌ | ❌ | ❌ | ✅ | ❌ |
| Xác nhận prorate/miễn (thai sản, ốm dài) | ❌ | ❌ | ❌ | ✅ | ❌ |
| Điều chỉnh số dư (bù/khấu trừ có lý do) | ❌ | ❌ | ✅ (đề nghị) | ✅ (duyệt) | ❌ |
| Cấu hình carry-over phép năm `[CẦN CHỐT SỐ-phepnam]` | ❌ | ❌ | ❌ | ✅ (đề xuất) | ✅ (duyệt) |
| Xem audit log đơn nghỉ | ❌ (chỉ đơn của mình) | ✅ (nhóm mình) | ✅ | ✅ | ✅ |

> Không dùng vai ngoài 18-vai registry; không tồn tại OPS_CX / FIN_COMPL (DI-006). Nguyên tắc: không ai tự duyệt đơn nghỉ của chính mình — đơn của TL do cấp quản lý trên xử lý.

---

## 5. Trường Hợp Đặc Biệt

- Nghỉ đột xuất (không đạt mốc báo trước): đơn vẫn lập được nhưng đi luồng retro có lý do; thống kê tách riêng để HR_L2 theo dõi tần suất.
- Hủy sau duyệt: số dư hoàn trả qua ledger (bản ghi ngược có lý do) + sự kiện hoàn trả capacity; nếu ngày nghỉ đã trôi qua thì xử lý như điều chỉnh công kỳ sau (nối FEAT-CORE-HRCORE-003).
- Giao nhau giữa các đơn: service từ chối khoảng thời gian trùng với đơn đã duyệt của cùng nhân sự; chọn khoảng khác hoặc chờ đơn cũ hủy.
- Nghỉ nửa ngày (buổi sáng/chiều): tính 0,5 ngày theo nội quy 03 §8; hai nửa ngày cùng ngày = 1 ngày trừ số dư.
- Nghỉ ốm dài/thai sản vượt nhiều chu kỳ: ledger vẫn tích lũy theo rule, allocation/capacity đóng băng theo BR-HR4-09; KPI kỳ nhận cờ prorate/miễn.
- Nghỉ không phép chạm ngưỡng: hệ thống gắn cờ + tổng hợp số lần/ngày trong tháng cho HR_L2; quyết định kỷ luật là của con người theo thủ tục, hệ thống không tự thực hiện.
- Tính ngày nghỉ: không tính T7/CN/Lễ Tết — service tính từ lịch làm việc cấu hình theo tenant (`work_schedule`).
- Tenant isolation: số dư và đơn nghỉ của tenant này không bao giờ xuất hiện trong truy vấn/ledger của tenant khác.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Đơn nghỉ phép (`leave_request`)

**Sơ đồ trạng thái:**
```
[NHÁP] ──(gửi)──► [CHỜ DUYỆT (TL ≤5 ngày | HR_L2 >5 ngày/không lương)] ──(duyệt)──► [ĐÃ DUYỆT] ──(hết kỳ trừ số dư)──► [HOÀN TẤT]
   │                      │                    │                                        │
   │ (hủy)                │ (từ chối)          │ (quá SLA → nhắc/escalate, vẫn CHỜ DUYỆT)│ (hủy có lý do)
   ▼                      ▼                    ▼                                        ▼
[HỦY]                 [TỪ CHỐI]             (vòng lặp nhắc)                        [HỦY SAO DUYỆT — hoàn trả số dư]
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| Nháp | Gửi | Chờ duyệt | Người lập | Ngày nghỉ không giao nhau với đơn đã duyệt; đạt mốc báo trước (hoặc khai báo đột xuất + lý do) |
| Chờ duyệt | Duyệt | Đã duyệt | TL (≤5 ngày, SLA 24h) hoặc HR_L2 (>5 ngày/không lương, SLA 48h) | Số dư đủ — chặn cứng ở service nếu vượt; giấy khám đính kèm nếu ốm ≥3 ngày |
| Chờ duyệt | Từ chối | Từ chối | Người duyệt đúng cấp | Ghi lý do từ chối |
| Chờ duyệt | Quá SLA | Chờ duyệt (+ nhắc/escalate) | Hệ thống | Nhắc lần 1 khi quá SLA; escalate cấp trên nếu tiếp tục quá |
| Đã duyệt | Hủy | Hủy sau duyệt | Người lập (trước ngày nghỉ) hoặc HR_L2 | Bắt buộc lý do; hoàn trả số dư qua ledger + phát sự kiện hoàn trả capacity |
| Đã duyệt | Kết thúc kỳ nghỉ | Hoàn tất | Hệ thống | Số dư đã trừ; dữ liệu chốt cho đối soát |

**Quy tắc:**
- "Từ chối", "Hủy", "Hoàn tất" là trạng thái kết thúc; muốn nghỉ lại phải tạo đơn mới.
- Việc duyệt và trừ số dư phải là một giao dịch nguyên tử — không tồn tại trạng thái "đã duyệt nhưng chưa trừ".

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `leave_balance_ledger` | `employee_id`, `entry_type` (ACCRUE/DEDUCT/ADJUST/EXPIRE), `days`, `reason`, `at`, `ref_request_id` | FK → `employee` | Ledger bất biến; số dư = tổng có hướng |
| `leave_request` | `employee_id`, `leave_type`, `from_date`, `to_date`, `days`, `reason`, `attachment_ref`, `status`, `route_level` (TL/HR_L2) | FK → `employee` | Tính days theo lịch làm việc tenant (không T7/CN/Lễ) |
| `leave_approval` | `request_id`, `approver_id`, `decision`, `decided_at`, `sla_hours`, `escalated_to` | FK → `leave_request` | Approver ≠ requester; SLA 24h/48h |
| `leave_policy_config` | `tenant_id`, `annual_days` (12), `accrual_per_month` (1), `carry_over_days` `[CẦN CHỐT SỐ-phepnam]`, `notice_rules` (mốc 03 §8) | — | Cấu hình theo tenant, đổi có log |
| `capacity_impact_event` | `request_id`, `employee_id`, `week_start`, `delta_hours`, `kind` (DEDUCT/RESTORE) | FK → `leave_request` | Tiêu thụ bởi luồng REQ-HR-009/OPS |
| `attendance_violation` | `employee_id`, `type` (NGHỈ_KHÔNG_PHÉP), `occurrences`, `month` | FK → `employee` | Gắn cờ ≥2 lần/tháng; ≥5 ngày/tháng → cờ nghiêm trọng cho HR_L2 |
| `audit_log` | `actor_id`, `entity`, `before/after`, `at`, `tenant_id` | — | Bất biến, tenant isolated |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu phác thảo ở Phase 2 — chi tiết đầy đủ được điền ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Chặn vượt số dư qua API | Nhân viên còn 2 ngày phép | Gọi trực tiếp API duyệt đơn 3 ngày | Service từ chối mã lỗi vượt số dư; không trừ ledger; có log lần gọi vi phạm | [ ] |
| SC-002: Routing đúng phân cấp | Đơn 7 ngày nghỉ phép năm | Job routing chạy | Đơn vào hàng đợi HR_L2 với SLA 48h; TL không thấy nút duyệt ở counterpart và API cũng từ chối nếu TL gọi | [ ] |
| SC-003: Trừ capacity tự động | Đơn 3 ngày được duyệt | Giao dịch duyệt hoàn tất | Ledger trừ 3 ngày; sự kiện capacity phát đúng tuần; OPS thấy capacity khả dụng giảm không cần thao tác | [ ] |
| SC-004: Tích lũy tự động 1 ngày/tháng | Nhân sự làm việc đủ tháng 10 | Job tích lũy ngày 1/11 chạy | Ledger cộng đúng 1 ngày, idempotent khi chạy lại; tổng năm 12 ngày | [ ] |
| SC-005: Ốm ≥3 ngày thiếu giấy khám | Đơn nghỉ ốm 4 ngày không có file đính kèm | Người duyệt cố duyệt | Service chặn với lý do thiếu chứng từ; đơn ở trạng thái chờ bổ sung | [ ] |
| SC-006: Cờ nghỉ không phép | 2 lần nghỉ không phép trong tháng | Job đếm vi phạm chạy | Ghi `attendance_violation` + gắn cờ cho HR_L2; hệ thống không tự ra quyết định kỷ luật | [ ] |

> **Liên kết:** Các scenario map đến REQ-HR-004 (`hr.md` Mục A3/B4) và BR-HR4-01..11 ở Mục 3.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` |
| Màn hình UI (counterpart SYS-BCERP-WEB) | `phase4-ux/core-backend/hr-core/nghi-phep.md` |
| Nguồn domain nội quy nghỉ phép/chế tài | `documents/03_Quy_che_KPI_HR.md` (mục 8, 9) |
