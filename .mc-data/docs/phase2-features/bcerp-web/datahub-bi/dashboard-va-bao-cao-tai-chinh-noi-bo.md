# Tính Năng: Dashboard & Báo Cáo Tài Chính Nội Bộ

> **Dựa trên:** REQ-FIN-015 trong `phase1-business/departments/finance/finance.md` (Phần A)
> **Phân hệ:** DataHub & BI — Data Integration Hub, Dashboard Tài Chính (SYS-BCERP-WEB)
> **Module:** DataHub & BI (MOD-DATAHUB-BI)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/finance/finance.md`, `phase1-business/departments/bod/bod.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/datahub-bi/dashboard-tai-chinh-noi-bo.md`, `phase5-implementation/tasks/bcerp-web/datahub-bi/feat-erp-dhub-004-impl.md`

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-DHUB-004 |
| Module | MOD-DATAHUB-BI |
| Yêu cầu nghiệp vụ | REQ-FIN-015 (Dashboard & báo cáo tài chính nội bộ) |
| Người dùng liên quan | FIN_L1, FIN_L2, BOD_CFO_CTO |
| Độ ưu tiên | Trung bình |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | Dữ liệu đối soát, discrepancy, aging AR/AP từ phân hệ FIN (REQ-FIN-001–007); nền tảng Data Integration Hub; FEAT-ERP-DHUB-005 (mở rộng star schema ở GĐ3) |
| Ghi chú Expert (A7) | Dept doc finance có mục A7 nhưng chưa ghi điều chỉnh riêng cho REQ-FIN-015 — không có thay đổi phạm vi từ Expert Review |

REQ-FIN-015 fan-out ra 3 hệ thống; bản này là bản riêng cho **SYS-BCERP-WEB** — kênh xem chính của dashboard tài chính nội bộ (form/list/workflow UI gọi API core). Counterparts: SYS-CORE-BACKEND (tổng hợp, star schema) và SYS-MOBILE-INTERNAL (dashboard rút gọn cho quản lý). Theo BR-FIN-307: Portal khách **không xem** các dashboard này — biên tin cậy nội bộ (REQ-FIN-017).

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cho phép FIN_L2 (kế toán trưởng) và CFO theo dõi sức khỏe dòng tiền hằng ngày trên web nội bộ mà không phải tổng hợp tay từ nhiều nguồn: số dư ví theo khách/nền tảng kèm ngày chi dự kiến, trạng thái đối soát, discrepancy còn tồn, aging công nợ phải thu/phải trả, hàng chờ duyệt quá SLA và hạn mức tuần nạp. FIN_L1 dùng dashboard làm bàn làm việc đối soát hằng ngày — nhìn thấy ngay khoản nào lệch, khoản nào chờ ai duyệt bao lâu rồi.

**Phạm vi:**
- Bao gồm:
  - Dashboard vận hành tài chính gồm 6 nhóm widget: (1) số dư ví theo khách/nền tảng + ngày chi dự kiến; (2) trạng thái đối soát từng khách/nền tảng; (3) discrepancy tồn (chưa khớp, quá dung sai); (4) aging AR/AP theo bậc 30/60/90 ngày; (5) hàng chờ duyệt (lệnh chi, lệnh nạp) kèm thời gian chờ vs SLA; (6) hạn mức tuần nạp: đã dùng / còn lại theo cấp duyệt.
  - Chỉ báo freshness "cập nhật lúc HH:MM" trên toàn dashboard; dữ liệu chi tiêu QC phải tươi ≤1 giờ; cảnh báo sự kiện quan trọng ≤5 phút.
  - Báo cáo tài chính nội bộ định kỳ (tuần/tháng) sinh từ dashboard: xuất Excel/PDF có log, dùng cho luồng khóa kỳ của FIN_L2.
  - Drill-down từ widget về danh sách giao dịch nguồn (lệnh nạp/rút, hóa đơn, đối chứng statement) trong phạm vi quyền.
  - Nhãn nguồn dữ liệu api/manual cho từng widget khi nguồn degraded.
- Không bao gồm:
  - Thực hiện đối soát, xác nhận "đã khớp tiền" (Hard Stop), duyệt lệnh chi — thuộc phân hệ FIN ví/đối soát (REQ-FIN-001–008); dashboard chỉ hiển thị trạng thái và deep-link sang màn hình thao tác.
  - Báo cáo tài chính chính thức theo chuẩn kế toán VAS phát hành ra ngoài — nối qua connector sổ kế toán (theo DI-004: cấu hình kết nối ngoại vi vendor-agnostic tại MOD-SETTINGS-GW).
  - P&L realtime theo dự án/khách và BI dashboard điều hành — thuộc FEAT-ERP-DHUB-005/002 (GĐ3).
  - Dashboard rút gọn cho quản lý trên mobile — thuộc SYS-MOBILE-INTERNAL.
  - Bất kỳ khung xem nào cho khách hàng qua Portal — cấm theo BR-FIN-307.

---

## 2. Luồng Người Dùng (User Stories)

Dashboard này là "bàn làm việc số" của phòng tài chính: mở máy buổi sáng là biết tiền đang ở đâu, khoản nào lệch, ai đang chậm duyệt — và đi thẳng được tới màn hình xử lý.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | FIN_L1 | Mở đầu ngày thấy số dư ví từng khách/nền tảng và ngày chi dự kiến của hôm nay | Chủ động nhắc khách nạp trước khi tài khoản cạn giữa chiến dịch |
| 2 | FIN_L1 | Xem danh sách discrepancy tồn kèm mức chênh lệch và số ngày tồn | Ưu tiên xử lý khoản lệch lớn/lâu nhất, không để tồn đọng kéo dài sang kỳ |
| 3 | FIN_L1 | Xem trạng thái đối soát từng khách (đã khớp / đang khớp / lệch) với freshness "cập nhật lúc HH:MM" | Trả lời khách và AM ngay khi được hỏi "tiền mình đang ở đâu" |
| 4 | FIN_L2 | Xem aging AR/AP theo bậc 30/60/90 và drill xuống từng hóa đơn | Quản trị công nợ chủ động, phát hiện khách chậm trả để AM can thiệp |
| 5 | FIN_L2 | Thấy hàng chờ duyệt (lệnh chi/nạp) kèm thời gian chờ so với SLA | Nhắc/escalate đúng khoản chậm duyệt, không để chặn chiến dịch của khách |
| 6 | FIN_L2 | Xuất báo cáo tài chính nội bộ tuần/tháng từ dashboard có log truy xuất | Phục vụ họp điều hành và luồng khóa kỳ mà không dựng lại bảng tính tay |
| 7 | BOD_CFO_CTO | Xem hạn mức tuần nạp đã dùng/còn lại theo cấp duyệt và cảnh báo vượt | Kiểm soát rủi ro dòng tiền khi nhiều khách nạp cùng lúc |
| 8 | FIN_L2 | Khi nguồn dữ liệu degraded, thấy nhãn "manual" kèm thời điểm hợp lệ cuối | Biết báo cáo đang dựa vào nguồn nào trước khi trình lên BOD |

---

## 3. Quy Tắc Nghiệp Vụ

Các quy tắc theo BR-FIN-307 và các business rule nguồn của phân hệ FIN; hiển thị web phải phản ánh đúng trạng thái đối soát do service layer quản lý — dashboard không tự "coi như khớp".

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Dashboard gồm đủ 6 nhóm nội dung bắt buộc (số dư ví + ngày chi dự kiến; trạng thái đối soát; discrepancy tồn; aging AR/AP; hàng chờ duyệt quá SLA; hạn mức tuần nạp) — WEB là kênh xem chính | Thiếu nhóm nội dung → không đạt nghiệm thu phạm vi REQ-FIN-015 |
| BR-002 | **Tiền giữ hộ hiển thị tách bạch khỏi doanh thu** ở mọi dashboard: số dư ví khách là nợ phải trả, không được gộp vào doanh thu công ty | Widget gộp sai → chặn publish, alert CTO theo BR tương ứng REQ-BOD-003 |
| BR-003 | Freshness: chỉ báo "cập nhật lúc HH:MM" bắt buộc; **chi tiêu QC tươi ≤1 giờ**; **cảnh báo sự kiện quan trọng ≤5 phút** (qua alert center FEAT-ERP-DHUB-003) | Widget stale quá ngưỡng → hiển thị cảnh báo đỏ, không trình số như thường |
| BR-004 | **Không nhập tay kết quả** dashboard/báo cáo — mọi số sinh tự động từ dữ liệu nguồn qua DataHub | Có chức năng nhập tay → vi phạm kiến trúc BI, chặn |
| BR-005 | Data Integration Hub gom dữ liệu từ các module + GW; **nguồn degraded gắn nhãn "manual" + disclaimer độ trễ**, kèm timestamp hợp lệ cuối; nhãn không được tắt | Hiện số manual như số api → vi phạm, log sự cố |
| BR-006 | Quy VND dùng **snapshot tỷ giá dùng chung** (REQ-FIN-004/BR-FIN-203) — không dùng tỷ giá riêng từng widget | Widget tự lấy tỷ giá khác → số tổng lệch; chặn render, ép dùng snapshot |
| BR-007 | **Portal khách không xem bất kỳ dashboard nào trong tính năng này** — biên tin cậy nội bộ; API dashboard chỉ phục vụ vai nội bộ đăng nhập realm nội bộ | API trả dữ liệu cho portal/user khách → chặn ở service layer, vi phạm bảo mật nghiêm trọng |
| BR-008 | Dữ liệu lương/PII chỉ aggregate khi được phép: aging AP hiển thị nhà thầu/nhà cung cấp ở mức tổng hợp; chi tiết cá nhân (thuế TNCN, lương) chỉ hiện ở màn hình payroll đúng quyền | Drill chạm PII không phép → chặn + ghi vi phạm audit |
| BR-009 | Mỗi lần xem/xuất báo cáo ghi **audit truy xuất** (user, thời điểm, phạm vi); BOD truy xuất dữ liệu tài chính cũng bị log; bản xuất có watermark người xuất | Xuất không log → từ chối thực hiện; meta-log thiếu → lỗi tuân thủ quarterly review |
| BR-010 | Dashboard phản ánh đúng trạng thái machine-state của đối soát (đã khớp / đang khớp / lệch — discrepancy) và Hard Stop: không hiển thị khoản "đã khớp" khi FIN_L1 chưa xác nhận | Trạng thái hiển thị lệch ledger → sửa mapping nguồn, kiểm đếm lại số khớp giữa dashboard và ledger |

---

## 4. Phân Quyền

WEB là kênh xem chính; enforcement ở service layer. Ba vai trong bảng là người dùng chính của REQ-FIN-015; vai khác (AM, OPS) không có quyền xem dashboard tài chính — dữ liệu cho AM đi qua kênh khác có kiểm soát.

| Hành động | FIN_L1 | FIN_L2 | BOD_CFO_CTO |
|-----------|--------|--------|-------------|
| Xem dashboard vận hành (ví, đối soát, discrepancy, hạn mức) | ✅ | ✅ | ✅ |
| Xem aging AR/AP toàn công ty | ✅ | ✅ | ✅ |
| Drill-down về giao dịch nguồn | ✅ (trong phạm vi đối soát của mình) | ✅ (toàn bộ) | ✅ (toàn bộ) |
| Xuất báo cáo nội bộ tuần/tháng | ✅ (bản vận hành) | ✅ (bản trình BOD, có log) | ✅ |
| Xem hàng chờ duyệt + SLA | ✅ | ✅ | ✅ |
| Duyệt lệnh chi/nạp từ dashboard (deep-link) | ❌ (xác nhận khớp tiền đúng màn hình Hard Stop có MFA) | ✅ (duyệt đúng màn hình luồng FIN) | ✅ (vượt ngưỡng theo luồng BOD) |
| Cấu hình ngưỡng cảnh báo ví/hạn mức | ❌ (đề xuất) | ✅ (đề xuất chính thức) | ✅ (duyệt chính sách) |
| Sửa dữ liệu giao dịch nguồn từ dashboard | ❌ | ❌ | ❌ (điều chỉnh chỉ qua luồng reversal có reason code ở hệ thống nguồn) |
| Xem giá vốn/giá trị T3/T4 | ❌ | ✅ (theo phân cấp dữ liệu) | ✅ |

---

## 5. Trường Hợp Đặc Biệt

- **Khách đa ví, đa nền tảng, đa tiền tệ:** số dư ví quy VND theo snapshot tỷ giá dùng chung; widget cho xem gốc ngoại tệ kèm tỷ giá snapshot; ngày chi dự kiến cộng dồn toàn bộ ví của khách trước khi cảnh báo cạn.
- **Nền tảng trừ phí thẳng vào số dư ví:** theo exception của phân hệ FIN, phí được coi là một dòng chi tiêu — dashboard hiển thị dòng "phí nền tảng trừ trực tiếp" tách khỏi chi tiêu media để không làm nhiễu số chi quảng cáo.
- **Discrepancy không map được giao dịch gốc:** theo BR-FIN-202, phát ticket discrepancy riêng — dashboard hiển thị ticket trong nhóm "discrepancy tồn" kèm trạng thái xử lý, không tự ghi giảm/ghi tăng số dư.
- **Connector sổ kế toán VAS:** theo DI-004, kết nối phần mềm kế toán là cấu hình ngoại vi vendor-agnostic tại MOD-SETTINGS-GW; khi connector lỗi, nhóm widget đối soát sổ rơi nhãn "manual" + timestamp, phần còn lại của dashboard vẫn tươi.
- **Khách chậm thanh toán kéo dài:** mốc "15 ngày → PAUSE" non-payment là đề xuất 2 bậc 15/30 ngày đang chờ khách hàng xác nhận (`[KXN-22]`); aging hiển thị theo bậc chuẩn 30/60/90 và thêm nhãn đề xuất PAUSE theo mốc tạm, đánh dấu "chờ chuẩn hóa".
- **Cuối tháng trước khi khóa kỳ:** dashboard bổ sung dải "kiểm tra trước khóa kỳ" (discrepancy còn tồn = 0? hàng chờ duyệt = 0?) để FIN_L2 rà trước khi mở khóa kỳ; sau khi khóa, các widget kỳ đó chuyển nhãn "đã chốt".
- **Cảnh báo quá SLA duyệt:** theo DI-005 đã chốt — quá hạn 24h nhắc người duyệt, quá SLA escalate lên cấp trên và phát alert đỏ; dashboard hàng chờ duyệt tô đỏ dòng đã escalate và hiển thị cấp đã nhận.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

Entity chính có trạng thái là **kỳ báo cáo tài chính nội bộ (reporting period)** — quyết định số liệu hiển thị là "tạm tính" hay "chốt"; trạng thái này FIN_L2 quản lý qua luồng khóa kỳ và dashboard phải hiển thị đúng.

**Entity:** Reporting Period (kỳ tháng tài chính dùng cho dashboard & báo cáo nội bộ)

**Sơ đồ trạng thái:**
```
[OPEN] ──(đủ điều kiện: discrepancy tồn = 0, hàng chờ duyệt = 0)──► [LOCK_PENDING] ──(FIN_L2 khóa kỳ)──► [CLOSED]
   ▲                                                                      │
   │                (phát hiện sai sót — luồng reversal có reason code)    │
   └──────────────────────────── [CLOSED] ◄───────────────────────────────┘ (không mở lại — chỉ điều chỉnh reversal)
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `OPEN` | Kiểm tra điều kiện khóa | `LOCK_PENDING` | FIN_L2 | Danh sách check trước khóa kỳ: discrepancy tồn = 0, không có hàng chờ duyệt quá hạn |
| `LOCK_PENDING` | Khóa kỳ | `CLOSED` | FIN_L2 | Nhập xác nhận khóa; ghi audit ai khóa lúc nào; widget kỳ đó gắn nhãn "đã chốt" |
| `LOCK_PENDING` | Hoàn tác kiểm tra | `OPEN` | FIN_L2 | Phát hiện còn sót hạng mục chưa xong |
| `CLOSED` | Điều chỉnh số | `CLOSED` (không đổi trạng thái) | FIN_L2 đề xuất + BOD duyệt | Chỉ qua luồng reversal có reason code; dashboard hiển thị dòng điều chỉnh riêng, không ghi đè lịch sử |

**Quy tắc:**
- Kỳ `CLOSED` không mở lại — mọi thay đổi là dòng reversal có dấu vết; dashboard so sánh giữa các kỳ luôn dùng số đã chốt.
- Trạng thái kỳ hiển thị trên mọi widget theo tháng: người xem phải biết mình đang nhìn số tạm tính hay số chốt.
- Hành vi khóa kỳ không có trên mobile (counterpart rút gọn chỉ xem) — thao tác khóa chỉ trên WEB theo nguyên tắc touchpoint thao tác.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `wallet_balance_view` | `client_id`, `platform_id`, `currency`, `balance_vnd`, `expected_spend_date`, `as_of` | FK → `dim_client`, `dim_platform` | View tổng hợp do CORE cung cấp; WEB read-only |
| `reconciliation_status` | `client_id`, `period`, `state` (matched/in_progress/discrepancy), `last_check_at` | FK → `discrepancy` | Trạng thái đối soát hiển thị trên dashboard |
| `discrepancy` | `ticket_no`, `type`, `amount`, `currency`, `age_days`, `state` | FK → `reconciliation_status` | Map theo BR-FIN-202 |
| `ar_ap_aging` | `invoice_id`, `direction` (AR/AP), `bucket` (30/60/90), `outstanding_vnd` | FK → hóa đơn nguồn | Cộng dồn theo kỳ |
| `approval_queue_item` | `request_id`, `type` (chi/nạp), `submitted_at`, `sla_due_at`, `escalated_to` | FK → luồng duyệt FIN | Tô đỏ khi quá SLA |
| `weekly_topup_quota` | `approval_level`, `quota_vnd`, `used_vnd`, `week_no` | — | Hạn mức tuần nạp theo cấp duyệt |
| `reporting_period` | `period_month`, `state` (OPEN/LOCK_PENDING/CLOSED), `locked_by`, `locked_at` | 1-N → widget kỳ | State machine Mục 6 |
| `export_log` | `user_id`, `exported_at`, `report_ref`, `filter_json` | FK → `users` | Immutable audit |

---

## 8. Acceptance Criteria

> Phác thảo Phase 2, chi tiết hóa ở Phase 5. Map về REQ-FIN-015.

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Đủ 6 nhóm widget REQ-FIN-015 | Dashboard triển khai xong | FIN_L2 mở dashboard tài chính | Thấy đủ: ví + ngày chi dự kiến; trạng thái đối soát; discrepancy tồn; aging AR/AP; hàng chờ duyệt; hạn mức tuần nạp — mỗi widget có "cập nhật lúc HH:MM" | [ ] |
| SC-002: Chi tiêu QC tươi ≤1h | GW vừa pull chi tiêu mới | So sánh thời điểm dữ liệu widget chi QC | Dữ liệu cũ hơn 1 giờ → cảnh báo đỏ; trong 1 giờ → hiển thị bình thường | [ ] |
| SC-003: Cảnh báo ≤5 phút | Sự kiện số dư ví chạm ngưỡng diễn ra | Đo thời gian tới khi dashboard/alert phản ánh | Cảnh báo hiển thị/đẩy trong ≤5 phút từ lúc phát hiện | [ ] |
| SC-004: Tiền giữ hộ tách bạch | Khách có số dư ví 500 triệu | Xem widget tổng hợp | 500 triệu nằm ở nhóm tiền giữ khách (nợ phải trả); không cộng vào doanh thu | [ ] |
| SC-005: Portal không truy cập được | User portal khách gọi API dashboard tài chính | Gửi request | Bị từ chối 403 ở service layer; ghi audit vi phạm truy cập | [ ] |
| SC-006: Khóa kỳ đúng điều kiện | Còn 1 discrepancy tồn | FIN_L2 thử khóa kỳ | Hệ thống chặn, liệt kê hạng mục chưa xong; kỳ giữ trạng thái OPEN | [ ] |
| SC-007: Định mức PAUSE tạm theo KXN-22 | Khách nợ quá 15 ngày theo mốc đề xuất | Xem aging AR | Dòng có nhãn "đề xuất PAUSE (mốc tạm chờ chuẩn hóa)"; nhãn biến mất/cập nhật khi KXN-22 chốt và cấu hình version mới | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (views tài chính, aging, quota, reporting period) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (dashboard feed, drill-down, export, lock period) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp DataHub ↔ FIN modules ↔ GW; connector VAS ngoại vi | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI dashboard tài chính (web nội bộ responsive) | `phase4-ux/bcerp-web/datahub-bi/dashboard-tai-chinh-noi-bo.md` |
| Business rule nguồn BR-FIN-307 và phân hệ ví/đối soát | `phase1-business/departments/finance/finance.md` (Phần B) |
| Counterpart MOBILE (dashboard rút gọn cho quản lý) | `phase2-features/mobile-internal/datahub-bi/` (FEAT tương ứng REQ-FIN-015) |
