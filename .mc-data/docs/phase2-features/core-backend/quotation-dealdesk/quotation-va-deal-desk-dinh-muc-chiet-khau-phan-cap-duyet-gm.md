# Tính Năng: Quotation & Deal Desk — Định Mức, Chiết Khấu Phân Cấp, Duyệt GM

> **Dựa trên:** REQ-SALES-006 trong `phase1-business/departments/sales/sales.md` (Phần A mục A3, Phần B mục B.6)
> **Phân hệ:** Kinh Doanh — Sales (SYS-CORE-BACKEND)
> **Module:** Quotation & Deal Desk (MOD-QUOTATION-DEALDESK)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1), `phase1-business/P1-02-business-workflow.md` (khối B5)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/sys-core-backend/mod-quotation-dealdesk/*.md`, `phase5-implementation/tasks/sys-core-backend/mod-quotation-dealdesk/feats-impl.md`

> **Đặc thù touchpoint SYS-CORE-BACKEND:** tính năng là headless API/domain service; mọi business rule enforce ở tầng service, không tin UI của kênh triệu gọi nào (WEB nội bộ, MOBILE nội bộ, kênh duyệt mobile Phase2). Mọi thao tác ghi có audit log bất biến (hash-chain, WORM ≥10 năm) và tenant isolation theo tenant.

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-QDD-001 |
| Module | MOD-QUOTATION-DEALDESK |
| Yêu cầu nghiệp vụ | REQ-SALES-006 |
| Người dùng liên quan | SALES_L1, SALES_L2, SALES_L3, SALES_L4, SALES_L5, FIN_L1, FIN_L2, BOD_CEO, BOD_CFO_CTO |
| Độ ưu tiên | Cao (HIGH — MVP) |
| Giai đoạn | Giai đoạn 1 (MVP) |
| Phụ thuộc | Không có cross-dependency ngoài lane. Tham chiếu đọc-only qua API nội bộ CORE: qualifiedTier + kết quả Gate 1/Gate 2 từ CRM-PIPELINE; chi phí đầu vào định mức do FIN duy trì (REQ-FIN-008, vendor-agnostic theo DI-004). |

---

## 1. Mô Tả Tính Năng

**Mục đích:**

Cung cấp trên core backend một Deal Desk engine là nguồn sự thật duy nhất cho báo giá của phòng Kinh Doanh: tự tính giá từ định mức version theo quý, tự tính Gross Margin (GM) theo nhóm dịch vụ, thực thi ma trận duyệt chiết khấu phân cấp L2–L5 và BOD, kiểm soát vòng đời version đến khi khóa vĩnh viễn sau khi gửi khách. Tính năng tồn tại để bảo vệ biên lợi nhuận — doanh thu agency chỉ tính phí dịch vụ/markup, tiền nạp quảng cáo của khách là tiền giữ hộ — và ngăn "chiết khấu ẩn" cùng nguy cơ sửa giá sau khi khách đã nhận báo giá.

**Phạm vi:**

- Bao gồm: định mức version theo quý (effective-dated, trace đúng version hiệu lực khi phát hành); GM engine (agency ≥15%, ads ≥20%, SEO ≥35%, web/design ≥30%); ma trận duyệt chiết khấu ≤5% / 5–15% / 15–20% / >20% kèm SLA; duyệt GM dưới ngưỡng; version control khóa vĩnh viễn bản gửi khách; hiệu lực 30/60 ngày tự chuyển "Hết hạn"; vòng sửa theo tier; audit log toàn bộ version/lượt duyệt/lý do.
- Không bao gồm: màn hình soạn/gửi trên web nội bộ (SYS-BCERP-WEB); kênh duyệt di động push + MFA step-up (SYS-MOBILE-INTERNAL, qua approval engine của CORE); hợp đồng/LOI/NDA, Brand Safety, e-sign (FEAT-CORE-QDD-002); credit/hoa hồng, quota (REQ-SALES-009); ví đa tiền tệ, nạp tiền NSQC (module WALLET-RECON).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | NVKD (SALES_L2) | Gọi API tạo báo giá, dòng giá trace đúng version định mức hiệu lực; thấy GM deal mình so với ngưỡng | Khách nhận giá đúng biểu hiện hành, tôi không đề xuất chiết khấu mù |
| 2 | NVKD (SALES_L2) | Tự phê chiết khấu ≤5% ngay trên service layer khi GM đạt ngưỡng | Chốt giá nhanh không chờ duyệt nhưng không vượt hạn mức |
| 3 | TPKD (SALES_L4) | Có hàng đợi duyệt CK 5–15%, SLA 8 giờ làm việc, engine tự escalate khi quá hạn | Deal không kẹt chờ duyệt, tôi chịu trách nhiệm đúng phần của mình |
| 4 | GDKD (SALES_L5) | Duyệt CK 15–20% kèm nhận định chiến lược, ngoại lệ GM dưới ngưỡng đến 20%, exception vượt vòng sửa có lý do | Deal đặc thù có lối thoái có kiểm soát, mọi van mở đều có dấu vết audit |
| 5 | BOD_CEO / BOD_CFO_CTO | Duyệt CK >20% bằng văn bản (SLA 2 ngày) qua API của CORE | Mọi quyết định phá biên lợi nhuận do BOD ký, không chối bỏ trách nhiệm được |
| 6 | Kế toán (FIN_L1/FIN_L2) | Lập báo giá theo định mức hiện hành, xem giá vốn và GM chi tiết | Bảo vệ biên lợi nhuận từ khâu lập giá thay cho sales tự nghĩ giá |
| 7 | NVKD (SALES_L2) | Gửi bản đã đủ duyệt cho khách, hệ thống khóa vĩnh viễn read-only, log người gửi/thời điểm/nội dung | Bản khách nhận không thể sửa ngầm, tranh chấp "bản nào là cuối" kết thúc |
| 8 | Hệ thống (job + GDKD) | Tự chuyển "Hết hạn" sau 30/60 ngày, cảnh báo quá 2 ngày LV chưa gửi sau duyệt GM, báo cáo GM thực tế theo tháng | Hiệu lực do hệ thống đảm bảo; GDKD phát hiện sớm nơi phá biên |

---

## 3. Quy Tắc Nghiệp Vụ

> *Các quy tắc bắt buộc — developer phải xử lý đúng trong code. Enforce ở service layer của CORE, chặn cả API lẫn mọi kênh UI; audit log hash-chain mọi sự kiện.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-QDD-101 | Định mức là tham số version theo quý, effective-dated (không sửa quá khứ); mọi dòng giá trace đúng `catalog_version_id` hiệu lực khi phát hành; gồm giá media sau CK agency, định mức giờ L1–L5, phí nền tảng, dự phòng rủi ro; phí dịch vụ: RENTAL 1–8% chi tiêu, MANAGED 10–20% NSQC (CMS §1) | API tạo/sửa trả 400 nếu dòng giá không tham chiếu được version hiệu lực; không có đường ghi đè giá tay ngoài định mức |
| BR-QDD-102 | GM engine tự tính theo nhóm dịch vụ: agency ≥15%, ads ≥20%, SEO ≥35%, web/design ≥30%; dưới ngưỡng → cảnh báo đỏ; media pass-through có giá vốn 0 GM nhưng bắt buộc tính đủ phí dịch vụ/markup — doanh thu không đếm phần tiền nạp QC pass-through | Không chặn ngay ở bước tính nhưng đánh dấu "GM dưới ngưỡng", bắt buộc qua BR-QDD-104 trước khi gửi |
| BR-QDD-103 | Ma trận chiết khấu: NVKD (L2) ≤5% tự duyệt tức thời khi GM đạt ngưỡng; >5–15% TPKD (L4), SLA 8 giờ làm việc; >15–20% GDKD (L5), SLA 1 ngày kèm nhận định chiến lược; >20% BOD, SLA 2 ngày, quyết bằng văn bản | API gửi khách trả 403 nếu có mức CK chưa có bản ghi duyệt đúng cấp; quá SLA engine tự escalate cấp trên + log |
| BR-QDD-104 | GM dưới ngưỡng phải GDKD duyệt (đến CK 20%) hoặc BOD duyệt (vượt 20%); giá vốn/GM là dữ liệu Mật — chỉ vai có quyền nhận được trường này, NVKD không xem giá vốn | API trả 403 mã "dữ liệu Mật" cho vai không đủ quyền; duyệt thiếu cấp → vẫn chặn gửi |
| BR-QDD-105 | Chặn gửi khách khi hết hiệu lực, chưa duyệt GM hoặc chưa đủ duyệt chiết khấu; sau duyệt GM tối đa 2 ngày làm việc phải gửi khách, quá hạn cảnh báo SM + GDKD | API send trả 403 kèm lý do cụ thể; quá hạn sinh cảnh báo tự động có audit log |
| BR-QDD-106 | Bản đã gửi khách khóa vĩnh viễn (read-only) ở tầng storage/service — không có API sửa; thay đổi phải tạo version mới và duyệt lại toàn bộ; log mọi sự kiện gửi (người gửi, thời điểm, hash nội dung) | Attempt sửa version đã gửi trả 409 và ghi audit log cảnh báo |
| BR-QDD-107 | Vòng sửa theo tier (5 tier A–E chốt theo V6.0, KXN-8): tier D/E tối đa 2 vòng, B/C tối đa 4 vòng; vượt ngưỡng chặn tạo version sửa tiếp, chỉ GDKD mở exception kèm lý do bắt buộc | API tạo version mới trả 403 kèm số vòng đã dùng; exception là bản ghi riêng có lý do, không có route bỏ qua |
| BR-QDD-108 | Hiệu lực 30 ngày kể từ khi gửi (tối đa 60 cho HĐ năm/đa giai đoạn); hết hạn job tự chuyển "Hết hạn"; bán tiếp phải re-quote theo định mức hiện hành | Job tự chạy; API gửi/accept trên bản hết hạn trả 409; re-quote bắt buộc dùng catalog mới nhất |
| BR-QDD-109 | Cấm chiết khấu ẩn: mọi tặng giờ/tài nguyên/ghi giảm phải nằm trên dòng giá và đi đúng ma trận duyệt; không có "ghi chú miễn phí" ngoài dòng giá được duyệt | Service layer từ chối payload có khoản khuyến mãi ngoài dòng giá (400); đối chiếu tổng dòng giá vs tổng báo giá để phát hiện |
| BR-QDD-110 | Mọi version, lượt duyệt (người duyệt, quyết định, lý do, thời gian) ghi audit log bất biến hash-chain; tenant isolation mọi truy vấn; version dùng snapshot giá tại thời điểm phát hành (pattern CMS Domain Model) | Audit log append-only, không có API sửa/xóa; truy vấn chéo tenant trả 403 và bị log |
| BR-QDD-111 | Ngoại lệ có kiểm soát: pilot 1 tháng được GM dưới ngưỡng tối đa một kỳ, ≤60 ngày (GDKD duyệt kèm mục tiêu chuyển đổi); tái ký trong 12 tháng giữ bảng giá cũ tối đa 1 lần; tỷ giá/phí nền tảng biến động >5% → version điều chỉnh không tính vào vòng sửa; khách BOD-sponsored ngoài ma trận phải có quyết định văn bản gắn deal | Mỗi ngoại lệ là một loại bản ghi có điều kiện machine-checkable; vi phạm điều kiện → API từ chối + escalation GDKD/BOD |
| BR-QDD-112 | Chuỗi báo giá → hợp đồng (nối FEAT-CORE-QDD-002): chỉ báo giá đủ duyệt mới được ACCEPTED; kích hoạt D+0 chỉ khi có tiền vào (nạp đủ 100% NSQC — Financial Hard Stop) VÀ LOI/hợp đồng đã ký (KXN-5 — LOI đủ điều kiện D+0); HĐ đầy đủ hoàn tất ≤7 ngày (KXN-10 — Deploy v2.3 đã phê chuẩn) | Chỉ báo giá ACCEPTED mở được API khởi tạo hợp đồng; kích hoạt thiếu tiền hoặc chữ ký → service layer từ chối + log |

---

## 4. Phân Quyền

> Thực thi ở tầng API/service theo 18 vai registry (không dùng OPS_CX/FIN_COMPL). WEB/MOBILE chỉ là client; MOBILE duyệt (Phase2) bắt buộc MFA step-up token gắn device.

| Hành động | SALES_L1 | SALES_L2 | SALES_L3 | SALES_L4 | SALES_L5 | FIN_L1/L2 | BOD | SYS_ADMIN |
|-----------|----------|----------|----------|----------|----------|-----------|-----|-----------|
| Xem báo giá deal mình tham gia | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Xem theo phạm vi quản lý (nhóm/phòng/toàn Sales) | ❌ | ❌ | ✅ (nhóm) | ✅ (phòng) | ✅ (toàn Sales) | ✅ | ✅ | ❌ |
| Tạo/soạn báo giá | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ (lập theo định mức) | ❌ | ❌ |
| Tự phê CK ≤5% khi GM đạt ngưỡng | ❌ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Duyệt CK theo band: 5–15% (SLA 8h) / 15–20% kèm nhận định (1 ngày) / >20% văn bản (2 ngày) | ❌ | ❌ | ❌ | ✅ / ✅ / ❌ | ✅ / ✅ / ❌ | ❌ | ✅ / ✅ / ✅ | ❌ |
| Duyệt GM/ngoại lệ GM dưới ngưỡng | ❌ | ❌ | ❌ | ❌ | ✅ (đến 20%) | ✅ (phối hợp) | ✅ (vượt 20%) | ❌ |
| Xem giá vốn / GM deal | ❌ (giá vốn ❌) | GM deal mình | ❌ (giá vốn ❌) | ✅ | ✅ | ✅ | ✅ | ❌ |
| Gửi bản đủ duyệt cho khách (khóa vĩnh viễn) | ❌ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Tạo version sửa / mở exception vượt vòng sửa | ❌ | ✅ / ❌ | ✅ / ❌ | ✅ / ❌ | ✅ / ✅ | ✅ / ❌ | ❌ / ✅ | ❌ |
| Nạp chi phí đầu vào / cấu hình tham số kỹ thuật | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ |
| Ban hành phiên bản định mức/ma trận theo quý | ❌ | ❌ | ❌ | ❌ | ✅ (trình) | ❌ | ✅ (duyệt) | ❌ |
| Xem audit log báo giá | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ (vận hành, bị log khi xem) |

---

## 5. Trường Hợp Đặc Biệt

- **Pilot 1 tháng GM dưới ngưỡng:** tối đa một kỳ, ≤60 ngày, GDKD duyệt kèm mục tiêu chuyển đổi; hết kỳ không chuyển đổi → chặn tiếp giá pilot, escalate GDKD/BOD quyết tất toán hoặc re-quote.
- **Tái ký trong 12 tháng:** giữ bảng giá cũ tối đa 1 lần; service layer kiểm tra lịch sử tái ký theo tenant để chặn lần thứ hai, từ đó bắt buộc re-quote.
- **Tỷ giá/phí nền tảng >5%:** tạo version điều chỉnh riêng không tính vào vòng sửa — deal không "hết lượt" vì biến động vĩ mô; ngưỡng đọc từ tham số effective-dated.
- **Khách BOD-sponsored ngoài ma trận:** vẫn cần qualifiedTier và báo giá trace định mức; duyệt ngoài ma trận bằng văn bản gắn deal, không có miễn kiểm ngầm.
- **Tier đổi giữa chừng:** vòng sửa đã dùng tính theo tier tại thời điểm tạo báo giá gốc; version tạo sau khi khóa tier áp số vòng theo tier mới (V6.0, KXN-8).
- **Nhiều version song song:** chỉ một version ở trạng thái SENT tại một thời điểm; tạo version mới tự chuyển bản cũ sang SUPERSEDED. **Duyệt viên quá SLA:** engine tự escalate TPKD → GDKD → BOD và log; hết SLA không tự động coi là duyệt. **Intern (SALES_L1):** chỉ xem báo giá deal được phân công, không tạo và không đề xuất chiết khấu.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Báo giá (Quotation) — version con kế thừa vòng đời từ bản gốc.

**Sơ đồ trạng thái:**
```
[DRAFT] ──(nộp duyệt: CK >5% hoặc GM dưới ngưỡng)──► [IN_REVIEW] ──(duyệt đủ cấp)──► [APPROVED]
   │                                      │ (reject)                          │ (gửi khách)
   │ (tự duyệt: CK ≤5%, GM đạt)           ▼                                   ▼
   ▼                              [REJECTED] ──(sửa = version mới)──► [DRAFT]      [SENT] (khóa vĩnh viễn)
[APPROVED]                                                                            │
                                                                     ┌────────────┬───┴──────┬────────────┐
                                                                     ▼            ▼          ▼            ▼
                                                                [ACCEPTED]  [REJECTED]  [EXPIRED]  [SUPERSEDED]
                                                               (mở luồng HĐ)           (auto 30/60) (bản mới thay)
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `DRAFT` | Tự phê CK ≤5% khi GM đạt ngưỡng | `APPROVED` | SALES_L2 trở lên (chủ deal) | Dòng giá trace catalog hiệu lực; GM ≥ ngưỡng nhóm dịch vụ |
| `DRAFT` | Nộp hàng đợi duyệt | `IN_REVIEW` | SALES_L2 trở lên | Có CK >5% hoặc GM dưới ngưỡng; đủ lý do đề xuất |
| `IN_REVIEW` | Duyệt đủ cấp / từ chối | `APPROVED` / `REJECTED` | L4 / L5 / BOD theo band | Bản ghi duyệt đúng cấp, đúng SLA; reject bắt buộc lý do |
| `REJECTED` | Tạo version sửa | `DRAFT` | SALES_L2 trở lên | +1 vòng sửa theo tier (D/E ≤2, B/C ≤4) — BR-QDD-107 |
| `APPROVED` | Gửi khách | `SENT` | SALES_L2 trở lên | Đủ duyệt GM + CK; còn hiệu lực; quá 2 ngày LV sau duyệt GM → cảnh báo |
| `SENT` | Khách chấp nhận | `ACCEPTED` | Hệ thống (ghi nhận từ kênh bán) | Bản còn hiệu lực; mở điều kiện khởi tạo hợp đồng (BR-QDD-112) |
| `SENT` | Từ chối / hết hạn / bị thay | `REJECTED` / `EXPIRED` / `SUPERSEDED` | Người dùng / job hệ thống / SALES_L2 trở lên | 30 (tối đa 60) ngày → EXPIRED; version mới duyệt lại toàn bộ → bản cũ SUPERSEDED |

**Quy tắc:**
- `SENT`, `EXPIRED`, `SUPERSEDED` khóa vĩnh viễn ở tầng dữ liệu — chỉ đọc và audit, không có API sửa nội dung.
- `ACCEPTED` kết thúc phía báo giá và mở đầu phía hợp đồng — không quay về `DRAFT`; làm lại phải tạo báo giá mới theo định mức hiện hành.
- Không có đường `DRAFT → SENT`: mọi lượt gửi đều qua `APPROVED`, kể cả khi L2 tự duyệt.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Chi tiết DDL đầy đủ tại `technical-specs/database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `price_catalog_version` | `version_no`, `effective_from`, `effective_to`, `status` (DRAFT/ACTIVE/RETIRED), `approved_by` | 1–N `service_fee_schedule`, `quotation_version` | Effective-dated; bản đã ban hành chỉ RETIRED, không sửa |
| `service_fee_schedule` | `service_group` (agency/ads/seo/web_design), `min_gm_percent`, `rental_fee_min/max` (1–8%), `managed_fee_min/max` (10–20%), `labor_rate` L1–L5, `platform_fee`, `risk_buffer_percent` | FK → `price_catalog_version` | Ngưỡng GM và khoảng phí từ policy đã chốt (KXN-8 V6.0; CMS §1) |
| `quotation` | `code`, `deal_id`, `customer_id` (tenant), `tier_at_issue`, `current_version_id`, `status`, `revision_round_used`, `sent_at`, `valid_until` | FK → deal, customer | Tenant isolation; `tier_at_issue` chốt số vòng sửa |
| `quotation_version` | `version_no`, `line_items` (dịch vụ, số lượng, đơn giá, `catalog_item_ref`), `discount_percent`, `gm_percent`, `cost_total` (Mật), `catalog_version_id`, `content_hash`, `locked_at` | FK → `quotation`, `price_catalog_version` | Snapshot giá; khóa vĩnh viễn khi `SENT` |
| `quotation_approval` | `quotation_version_id`, `type` (DISCOUNT/GM/EXCEPTION), `band` (L4/L5/BOD), `approver_id`, `decision`, `reason`, `sla_deadline`, `decided_at` | FK → `quotation_version` | Append-only; SLA clock + escalate do approval engine quản |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ ở Phase 2 — chi tiết hóa ở Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Tự duyệt CK ≤5% | Báo giá DRAFT, CK 4%, GM đạt ngưỡng | NVKD gọi API phê duyệt mức mình | APPROVED, bản ghi `band=L2`, không cần duyệt viên khác | [ ] |
| SC-002: Chặn gửi thiếu duyệt CK | CK 12% chưa có duyệt TPKD | NVKD gọi API gửi khách | API trả 403 "thiếu duyệt 5–15%", sự kiện bị log | [ ] |
| SC-003: GM dưới ngưỡng chặn gửi | Báo giá ads GM 18% | Hệ thống tính GM | Đánh dấu "GM dưới ngưỡng"; API gửi trả 403 đến khi GDKD/BOD duyệt ngoại lệ | [ ] |
| SC-004: Khóa vĩnh viễn bản gửi | Báo giá đã SENT | Bất kỳ ai gọi API sửa version | API trả 409 + audit log attempt; chỉ tạo được version mới đi lại duyệt | [ ] |
| SC-005: Hết hạn tự động + vòng sửa theo tier | Bản SENT 31 ngày; khách tier D đã dùng 2 vòng sửa | Job định kỳ chạy; NVKD tạo version sửa thứ 3 | Bản tự EXPIRED, accept trả 409; version thứ 3 chặn 403, chỉ mở khi GDKD tạo EXCEPTION có lý do | [ ] |
| SC-006: Dữ liệu Mật không lộ giá vốn | NVKD gọi API chi tiết báo giá | Service layer trả payload | Trường giá vốn/GM bị loại theo vai; truy vấn GM deal mình được log | [ ] |

> **Liên kết:** SC-001→SC-006 map vào REQ-SALES-006 (Mục 2 — quotation theo định mức, duyệt ma trận, version lock, hiệu lực).

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints (quotation, approval, catalog) | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp xuyên hệ thống (CORE ↔ WEB ↔ MOBILE, approval engine, SLA clock) | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình web nội bộ (soạn thảo, hàng đợi duyệt) | `phase4-ux/sys-bcerp-web/mod-quotation-dealdesk/*.md` |
| Kênh duyệt di động (Phase2, MFA step-up) | `phase4-ux/sys-mobile-internal/mod-quotation-dealdesk/*.md` |
| Nguồn domain tham chiếu | `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1) |
