# Tính Năng: Commission & Quota — Hoa hồng theo thực nhận, clawback, coverage ≥3× (Core Backend)

> **Dựa trên:** REQ-SALES-009 trong `phase1-business/departments/sales/sales.md` (Phần A Mục 9, Phần B.9)
> **Phân hệ:** Engine Kinh doanh — nguồn sự thật nghiệp vụ Sales (SYS-CORE-BACKEND)
> **Module:** Commission & Quota (MOD-COMMISSION-QUOTA)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `phase1-business/P1-02-business-workflow.md`, `documents/03_Quy_che_KPI_HR.md` (§5 Salary Band, §6 Chính sách lương — KPI — hoa hồng theo vị trí)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/[sys]/[mod]/[screen-group].md`, `phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`
>
> **Phạm vi touchpoint SYS-CORE-BACKEND:** spec này mô tả **headless API / domain services** — mọi business rule hoa hồng/quota được enforce ở tầng service (không tin UI), có audit log bất biến và tenant isolation. Web nội bộ (`SYS-BCERP-WEB`) và mobile nội bộ (`SYS-MOBILE-INTERNAL`) là counterpart, chỉ là bề mặt gọi API của engine này.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-COMM-001 |
| Module | MOD-COMMISSION-QUOTA |
| Yêu cầu nghiệp vụ | [REQ-SALES-009] |
| Người dùng liên quan | SALES_L1, SALES_L2, SALES_L3, SALES_L4, SALES_L5, FIN_L1, FIN_L2, HR_L1, HR_L2, BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Trung bình (MEDIUM — Phase 3, phụ thuộc Công nợ AR GĐ2) |
| Giai đoạn | Giai đoạn 3 |
| Phụ thuộc | Công nợ AR GĐ2 (nguồn sự thật thanh toán thực nhận); Pipeline & Deal (REQ-SALES-001/002 — điều kiện hưởng credit); Handoff Gate 2 (REQ-SALES-008 — mốc khóa split, tạm dừng credit); Quotation & Deal Desk (REQ-SALES-006 — điều kiện "đã duyệt GM") |
| Ghi chú Expert (A7) | sales.md Mục A7 chưa ghi điều chỉnh nào (bước đánh giá expert chưa thực hiện) — spec bám nguyên văn business rules Phần B.9 do sales-expert review 12/09/2026 |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Xây dựng trên core backend một **credit engine hoa hồng theo thanh toán thực nhận** — tính hoa hồng cho lực lượng kinh doanh L1–L5 dựa trên tiền khách hàng thực trả, đối chiếu sổ AR (FIN là nguồn sự thật), kèm clawback tự động, kiểm soát split credit, quota quý theo cấp và pipeline coverage ≥3×. Engine chấm dứt tình trạng "đua ký rồi bỏ mặc thu tiền": hoa hồng chỉ chảy khi tiền về và tự hồi lại khi tiền bị thu hồi.

**Phạm vi:**
- Bao gồm: credit engine theo từng đợt thanh toán thực nhận; validate và lưu split credit; clawback tự động (hủy/hoàn phí, nợ quá hạn >90 ngày); quota theo cấp/quý; attainment và coverage tính tự động; khóa/mở khóa kỳ hoa hồng có phê duyệt + audit log; phiên bản hóa chính sách (effective-dated); API read-only cho sale xem hoa hồng/quota của chính mình (kể cả kênh mobile nội bộ, PII Restricted); API tổng hợp cho FIN, HR, BOD.
- Không bao gồm: dashboard coverage/attainment và luồng phân xử deal trùng trên web (counterpart `SYS-BCERP-WEB` — engine chỉ lưu kết quả và tính toán); push alert coverage vàng/đỏ trên mobile (counterpart `SYS-MOBILE-INTERNAL`); sổ cái AR và phát hành hóa đơn (module AR/AP); bảng lương/KPI template theo vị trí (module HR-CORE — engine chỉ đọc tham chiếu `salary_policy`/`commission_tier` từ HR §6 `CHÍNH_SÁCH_LƯƠNG_2026`); connector kế toán VAS (Settings — vendor-agnostic theo DI-004).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | SALES_L1/L2 (NVKD) | Gọi API `GET /api/v1/commission/me` (scope chính mình) xem credit, clawback, attainment theo kỳ | Minh bạch thu nhập, tự biết còn cách quota bao xa |
| 2 | SALES_L4 (SM) | Gọi API `POST /api/v1/deals/{id}/commission-splits` ghi trước Gate 2, engine validate tổng ≤100% | Chốt trước ai hưởng credit bao nhiêu, chặn tranh chấp phát sinh sau |
| 3 | FIN_L2 | Gọi API `POST /api/v1/commission/clawbacks/{id}/confirm` xác nhận clawback sau khi đối chiếu AR (aging, hóa đơn, phiếu thu) | Mọi dòng hồi hoa hồng dẫn chiếu được chứng từ công nợ thật |
| 4 | SALES_L5 (GDKD) | Gọi API duyệt clawback `approve` trong SLA 3 ngày làm việc kể từ khi aging vượt 90 ngày | Kiểm soát dòng trừ hoa hồng kỳ kế tiếp |
| 5 | SALES_L5 (GDKD) | Gọi API điều chỉnh quota giữa kỳ theo tỷ lệ ngày làm việc (nghỉ ốm/thai sản/chuyển vị trí) | Quota phản ánh công bằng thời gian làm việc thực tế |
| 6 | SALES_L1–L5 (qua mobile nội bộ) | Dùng API read-only `GET /api/v1/commission/me/summary` (PII Restricted — chỉ trả dữ liệu của chính người gọi) | Xem hoa hồng/quota của chính mình trên điện thoại, không can thiệp dữ liệu người khác |
| 7 | HR_L1 | Gọi API đọc attainment/quota tổng hợp theo cấp `career_level` | Đối chiếu chính sách lương §6 (bảng Level/Rank theo %KPI) với hoa hồng thực tế khi salary review Q4 |
| 8 | BOD_CFO_CTO | Gọi API báo cáo impact credit/clawback/aging ảnh hưởng hoa hồng theo tháng | Đo chi phí hoa hồng thực tế và rủi ro nợ quá hạn trước khi duyệt quỹ lương |
| 9 | SYS_ADMIN | Gọi API quản trị ban hành phiên bản chính sách hoa hồng/quota mới (effective-dated) | Đổi thang hoa hồng/quota khi có quyết định ban hành, vẫn tái hiện được con số kỳ cũ |

---

## 3. Quy Tắc Nghiệp Vụ

> *Quy tắc bắt buộc — developer phải xử lý đúng trong code. Toàn bộ enforce ở tầng service core backend (UI chỉ vô hiệu hóa nút, API phải tự từ chối), mọi thao tác ghi audit log.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | Hoa hồng tính theo **thanh toán thực nhận** đối chiếu sổ AR (FIN nguồn sự thật) — KHÔNG theo ngày ký. Deal chỉ hưởng credit khi: (a) có bản ghi pipeline trước Gate 2 ("không ghi nhận = không tồn tại"), (b) qualifiedTier hợp lệ, (c) quotation đã duyệt GM; doanh thu chỉ đếm phí dịch vụ/markup, loại pass-through NSQC | API từ chối gắn credit cho deal thiếu điều kiện (log lý do cho SALES_L5); dòng credit thiếu tham chiếu AR hoặc chưa tách pass-through bị chặn tính |
| BR-002 | Thang hoa hồng theo cấp (đã chốt theo DI-001): L1 2,5% → L5 6,5%; L4/L5 cộng 0,5% doanh thu đơn vị. Nhân hệ số attainment quý: ≥100% ×1,2; 80–99% ×1,0; 70–79% ×0,9; <70% ×0,8 | Con số chỉ lấy từ bản ghi `commission_policy` phiên bản hiệu lực tại thời điểm phát sinh, không hardcode trong code |
| BR-003 | Clawback khách hủy/hoàn phí: hồi hoa hồng **theo tỷ lệ tiền hoàn**; nợ quá hạn >90 ngày: clawback **100% phần chưa thu**; trừ vào kỳ kế tiếp; FIN_L2 xác nhận số liệu + SALES_L5 duyệt trong SLA 3 ngày làm việc kể từ khi aging vượt 90; luôn dẫn chiếu hóa đơn/phiếu thu/công nợ | Engine tự sinh dòng clawback, không cho nhập tay số tùy ý; cấm xóa dòng đã áp, sai sót chỉ xử lý bằng dòng điều chỉnh ngược có phê duyệt + audit log |
| BR-004 | Split credit: chủ deal 70% – người hỗ trợ 30%; SM/TPKD hỗ trợ pre-sale tối đa 20% credit deal; **tổng mọi split ≤100%**; ghi trước Gate 2 — sau Gate 2 chặn bổ sung cứng ở tầng service | API từ chối mọi request ghi/đổi split sau Gate 2 hoặc làm tổng vượt 100%, trả lỗi nghiệp vụ rõ ràng, ghi log attempt |
| BR-005 | Quota theo cấp/quý (đã chốt theo DI-001): L1 600 triệu → L5 5 tỷ/phòng; pipeline coverage ≥3× quota kỳ kế tiếp = on-track; <2× = đỏ — bắt buộc kế hoạch bổ sung lead, SM (SALES_L4) chịu trách nhiệm; **attainment tự động, cấm nhập tay** | Không có API ghi attainment thủ công; ngưỡng không đạt không chặn ghi nhận, chỉ gắn trạng thái vàng/đỏ cho kênh cảnh báo |
| BR-006 | Khóa kỳ hoa hồng sau khi chốt (SALES_L5 + FIN_L2 đồng chốt); mở khóa phải phê duyệt + audit log bất biến | API ghi vào kỳ `LOCKED` bị từ chối trừ clawback điều chỉnh đã duyệt; mở khóa không có phê duyệt bị chặn kể cả với SYS_ADMIN |
| BR-007 | Hợp đồng dài hạn >12 tháng: credit chia theo từng kỳ thực nhận; deal bị trả về từ Gate 2: credit **tạm dừng** đến khi handoff lại thành công | Engine tách lịch credit theo schedule thực nhận; đợt thực nhận phát sinh khi deal paused không phát sinh credit, đối soát lệch schedule alert FIN |
| BR-008 | Nghỉ ốm/thai sản/chuyển vị trí giữa kỳ: quota giảm theo **tỷ lệ ngày làm việc thực tế**, SALES_L5 duyệt | API điều chỉnh quota bắt buộc kèm ngày hiệu lực + lý do; yêu cầu thiếu phê duyệt bị từ chối và log |
| BR-009 | Tranh chấp credit deal trùng: credit thuộc người thắng phân xử theo cơ chế REQ-SALES-001 (ghi trước có bằng chứng → SM hòa giải 24h → GDKD quyết cuối 3 ngày làm việc) | Engine treo credit khi tranh chấp mở, chỉ ghi nhận kết quả đã chốt kèm audit log |
| BR-010 | Chính sách hoa hồng/quota là bản ghi phiên bản hóa effective-dated (tham chiếu bảng "Mức Level/Rank" 12 bậc theo %KPI của từng `career_level` tại HR §6): sửa chính sách = tạo phiên bản mới hiệu lực từ ngày X | Cấm UPDATE bản ghi policy đã hiệu lực trong quá khứ; API chỉ cho tạo phiên bản mới, vô hiệu hóa bản cũ từ ngày tương lai |
| BR-011 | Toàn bộ endpoint đa tenant: dữ liệu hoa hồng isolate theo tenant; người dùng chỉ đọc trong phạm vi quyền (cá nhân / nhóm / phòng / toàn công ty) | Request đọc chéo tenant hoặc vượt scope trả lỗi truy cập; kiểm thử bảo mật bao gồm case IDOR trên ID kỳ/deal/nhân sự |

---

## 4. Phân Quyền

> *Phân quyền thực thi ở tầng API core backend. GDKD = SALES_L5; SM = SALES_L4 (theo cơ cấu L1–L5, GDKD L5 quy hoạch, tạm BOD kiêm nhiệm).*

| Hành động | SALES_L1–L2 | SALES_L3–L4 | SALES_L5 (GDKD) | FIN_L2 | HR_L1 | SYS_ADMIN / BOD_CFO_CTO |
|-----------|------------|------------|-----------------|--------|-------|--------------------------|
| Xem hoa hồng/clawback/attainment của chính mình | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ |
| Xem hoa hồng người khác | ❌ | ✅ (nhóm mình — L4) | ✅ (toàn phòng) | ✅ (đối soát) | ✅ (tổng hợp gắn KPI, không PII tài chính chi tiết) | ✅ |
| Ghi split credit (chỉ trước Gate 2) | ✅ (deal của mình) | ✅ | ✅ | ❌ | ❌ | ❌ |
| Bổ sung split sau Gate 2 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Xác nhận số liệu clawback (đối chiếu AR) | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Duyệt clawback (SLA 3 ngày) | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Điều chỉnh quota giữa kỳ | ❌ | ✅ (đề xuất nhóm mình) | ✅ (duyệt) | ❌ | ❌ | ❌ |
| Khóa kỳ hoa hồng | ❌ | ❌ | ✅ | ✅ (đồng chốt) | ❌ | ❌ |
| Mở khóa kỳ (phê duyệt + log) | ❌ | ❌ | ✅ (trình duyệt) | ❌ | ❌ | ✅ (BOD_CFO_CTO duyệt) |
| Ban hành phiên bản chính sách | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (thực thi trên phê duyệt BOD_CEO) |
| Xóa dòng credit/clawback | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (chỉ dòng điều chỉnh ngược có duyệt) |

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ engine phải xử lý — đều có audit log bất biến.*

- **Nghỉ ốm/thai sản/chuyển vị trí giữa kỳ:** quota giảm theo tỷ lệ ngày làm việc thực tế, SALES_L5 duyệt trên đề xuất của SALES_L4; attainment sau đó tính trên quota đã điều chỉnh, không tính trên quota gốc.
- **Hợp đồng dài hạn >12 tháng:** credit chia theo schedule thực nhận; khách thanh toán lệch schedule thì engine ghi credit theo đợt tiền thực về và đẩy lệch sang đối soát của FIN.
- **Deal bị trả về từ Gate 2:** credit tạm dừng ngay khi handoff chuyển về "khắc phục"; handoff lại thành công thì credit tiếp tục từ đợt sau.
- **Khách hủy/hoàn phí một phần:** clawback theo đúng tỷ lệ tiền hoàn trên tổng tiền đã thực nhận; hoàn phủ toàn bộ thì clawback phủ toàn bộ credit đã chi cho deal.
- **Tranh chấp "deal credit cho ai":** treo credit khi tranh chấp mở; gán split sau khi phân xử chốt theo REQ-SALES-001; SM là đương sự thì GDKD thay thế phân xử.
- **Đối chiếu AR qua connector kế toán:** theo DI-004, kết nối phần mềm kế toán VAS là cấu hình kết nối ngoại vi vendor-agnostic trong Settings — engine chỉ tiêu thụ chuẩn dữ liệu đối chiếu (connection profile + field mapping); tên vendor cấu hình khi triển khai.
- **Mốc tạm ngừng vì không thanh toán:** đề xuất tạm ngừng vận hành khi khách không thanh toán 15 ngày (2 bậc 15/30 ngày) `[KXN-22]` chưa được khách hàng xác nhận — spec KHÔNG tự quyết: giữ nguyên clawback cứng >90 ngày đã chốt; khi `[KXN-22]` chốt, trạng thái tạm ngừng nối thêm như điều kiện tạm dừng credit mà không phá các BR hiện có.
- **Mobile nội bộ offline-capable:** API `me/summary` trả snapshot nhẹ để ứng dụng cache; cache chỉ để hiển thị, con số authoritative luôn lấy từ engine khi có mạng.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Kỳ hoa hồng (Commission Period) và dòng Clawback (Clawback Record) — trạng thái validate hoàn toàn ở tầng service.

**Sơ đồ trạng thái — Kỳ hoa hồng:**
```
[OPEN] ──(chốt số liệu + khóa kỳ)──► [LOCKED] ──(mở khóa có phê duyệt + log)──► [OPEN]
```

**Bảng chuyển đổi — Kỳ hoa hồng:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `OPEN` | Lock period | `LOCKED` | SALES_L5 + FIN_L2 | Toàn bộ payment thực nhận trong kỳ đã đối chiếu AR; clawback đã duyệt đã áp |
| `LOCKED` | Unlock | `OPEN` | SYS_ADMIN trên phê duyệt BOD_CFO_CTO | Nhập lý do; audit log ghi người duyệt, thời điểm, lý do |
| `LOCKED` | Ghi dữ liệu | `LOCKED` (từ chối) | — | Chỉ nhận clawback điều chỉnh đã duyệt trước đó |

**Sơ đồ trạng thái — Dòng Clawback:**
```
[PENDING_CONFIRM] ──(FIN xác nhận)──► [FIN_CONFIRMED] ──(GDKD duyệt)──► [APPROVED] ──(áp vào kỳ kế tiếp)──► [APPLIED]
                                                                                    │ (từ chối, nhập lý do)
                                                                                    ▼
                                                                               [REJECTED]
```

**Bảng chuyển đổi — Dòng Clawback:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `PENDING_CONFIRM` | Confirm | `FIN_CONFIRMED` | FIN_L2 | Dẫn chiếu đầy đủ hóa đơn/phiếu thu/công nợ; aging xác thực từ sổ AR |
| `FIN_CONFIRMED` | Approve | `APPROVED` | SALES_L5 | Trong SLA 3 ngày làm việc kể từ khi aging vượt 90; quá SLA escalate |
| `FIN_CONFIRMED` | Reject | `REJECTED` | SALES_L5 | Phải nhập lý do; log bất biến |
| `APPROVED` | Apply | `APPLIED` | Hệ thống (tại khóa kỳ) | Kỳ kế tiếp được khóa; clawback trừ vào kỳ đã khóa |

**Quy tắc:**
- `APPLIED` và `REJECTED` là trạng thái kết thúc — không chuyển tiếp; sai sót xử lý bằng dòng điều chỉnh ngược mới có phê duyệt.
- Không nhảy cóc trạng thái (ví dụ duyệt khi chưa có FIN xác nhận) — service layer từ chối bất kể vai trò người gọi.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính để developer nắm nhanh — chi tiết DDL tại `database-design.md`. Tên đặt theo định hướng entity TMS tại `documents/03_Quy_che_KPI_HR.md` §9.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `commission_policy` | `version`, `effective_from/to`, `tier_rates` (L1–L5), `unit_revenue_bonus`, `attainment_multipliers` | 1-N → `commission_tier` | Effective-dated, append-only (BR-010) |
| `commission_tier` | `career_level` (KD-1..KD-5), `rate`, `quota_per_period`, `team_quota` | FK → `commission_policy` | Số tham chiếu bảng Level/Rank §6 `CHÍNH_SÁCH_LƯƠNG_2026` |
| `quota` | `user_id`, `period_id`, `target_amount`, `adjusted_target`, `adjust_reason` | FK → `users`, `commission_period` | `adjusted_target` chỉ ghi khi có phê duyệt SALES_L5 (BR-008) |
| `commission_period` | `code` (VD: 2026-Q3), `status` (OPEN/LOCKED), `locked_at`, `locked_by` | 1-N → `commission_credit`, `clawback_record` | Khóa kỳ có phê duyệt + audit log (BR-006) |
| `commission_credit` | `deal_id`, `user_id`, `payment_ref` (AR), `recognized_amount`, `rate_applied`, `split_ratio`, `status` (ACTIVE/PAUSED/REVERSED) | FK → `deal`, `ar_payment`, `users`, `commission_period` | 1 payment thực nhận = 1 dòng credit; pass-through NSQC loại khỏi base |
| `commission_split` | `deal_id`, `owner_user_id`, `support_user_id`, `ratio`, `recorded_at`, `gate2_passed` | FK → `deal`, `users` | Chỉ ghi trước Gate 2; tổng ≤100% validate ở service layer |
| `clawback_record` | `credit_id`, `reason` (CANCEL_REFUND/OVERDUE_90), `amount`, `invoice_ref`, `status` | FK → `commission_credit`, `ar_document` | Tự sinh theo BR-003; duyệt SLA 3 ngày làm việc |
| `attainment_snapshot` | `user_id`, `period_id`, `coverage_ratio`, `attainment_pct`, `computed_at` | FK → `users`, `quota` | Chỉ tính tự động, không có API ghi tay; nguồn cho cảnh báo vàng/đỏ |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ ở Phase 2 — điền chi tiết ở Phase 5 (implementation tasks). Mỗi scenario map về REQ-SALES-009.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Credit theo thực nhận | Deal qua Gate 2, khách thanh toán 1 đợt phí dịch vụ | Payment thực nhận khớp sổ AR | Engine sinh đúng 1 dòng credit theo rate cấp + hệ số attainment, loại pass-through NSQC | [ ] |
| SC-002: Clawback nợ quá hạn | Dòng AR aging vượt 90 ngày | Aging cập nhật từ sổ công nợ | Tự sinh clawback 100% phần chưa thu, trạng thái `PENDING_CONFIRM` chờ FIN xác nhận | [ ] |
| SC-003: Chặn split sai quy tắc | Deal có split 70%/30% | Request thêm split (vượt 100%) hoặc sửa split sau Gate 2 | API từ chối cứng ở service layer với lỗi nghiệp vụ rõ ràng, ghi log attempt | [ ] |
| SC-004: Attainment tự động | Kỳ đang mở, credit và quota có dữ liệu | Engine chạy snapshot attainment | attainment/coverage sinh tự động, không tồn tại API ghi tay, các kênh đọc được giá trị đồng nhất | [ ] |
| SC-005: Khóa kỳ và mở khóa | Kỳ hết hạn, số liệu đối chiếu xong | SALES_L5 + FIN_L2 khóa kỳ; SYS_ADMIN thử mở không phê duyệt | Khóa thành công; mở không phê duyệt bị chặn; mở có phê duyệt BOD_CFO_CTO thành công với audit log đầy đủ | [ ] |
| SC-006: Mobile đọc đúng phạm vi | Sale L1 đăng nhập qua mobile nội bộ | Gọi `GET /commission/me/summary` và thử gọi summary của người khác | Nhận đúng dữ liệu của mình; request chéo người/tenant trả lỗi truy cập (PII Restricted) | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống (đối chiếu AR, connector kế toán vendor-agnostic — DI-004) | `technical-specs/integration-map.md` |
| Màn hình UI (dashboard coverage/attainment — counterpart WEB) | `phase4-ux/bcerp-web/commission-quota/*.md` |
| Nguồn domain chính sách lương — hoa hồng theo vị trí | `documents/03_Quy_che_KPI_HR.md` (§5, §6, §9) |
| Business rules gốc REQ-SALES-009 | `phase1-business/departments/sales/sales.md` (B.9) |
