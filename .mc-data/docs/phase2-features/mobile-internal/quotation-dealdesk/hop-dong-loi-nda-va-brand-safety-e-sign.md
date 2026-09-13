# Tính Năng: Hợp Đồng/LOI/NDA & Brand Safety + E-sign (Mobile Nội Bộ)

> **Dựa trên:** REQ-SALES-007 trong `phase1-business/departments/sales/sales.md` (Phần A §REQ-SALES-007, Phần B §B.7)
> **Phân hệ:** Hệ Mobile Nội Bộ (SYS-MOBILE-INTERNAL)
> **Module:** Quotation & Deal Desk (MOD-QUOTATION-DEALDESK)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/sales/sales.md`, `documents/02_Quy_trinh_Cho_thue_TKQC.md`
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/mobile-internal/quotation-dealdesk/*.md`, `phase5-implementation/tasks/mobile-internal/quotation-dealdesk/feat-mbi-qdd-002-impl.md`

> **Hướng dẫn ID:** FEAT-ID sinh từ REQ-ID theo quy tắc `REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`. REQ-SALES-007 fan-out trên 3 hệ thống; bản spec này là slice riêng cho SYS-MOBILE-INTERNAL (counterparts: SYS-CORE-BACKEND, SYS-BCERP-WEB).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-MBI-QDD-002 |
| Module | MOD-QUOTATION-DEALDESK |
| Yêu cầu nghiệp vụ | REQ-SALES-007 |
| Người dùng liên quan | SALES_L2 (NVKD chủ deal), SALES_L3 (TNKD), SALES_L4 (TPKD/SM — KXN-14), SALES_L5 (GDKD), BOD_CEO/BOD_CFO_CTO (duyệt mức cao nhất); legal review do pháp chế/luật sư ngoài 18 vai registry, gán qua cấu hình |

> **Chú thích phân biệt (P4 — KXN-14):** `SALES_L3` là vai TNKD (trưởng nhóm kinh doanh) theo `sales.md`; chức danh **SM** ánh xạ **SALES_L4 (TPKD)** — người ký/duyệt các mốc gate theo KXN-14, không còn gắn với SALES_L3.
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 (Phase 2 — kênh mobile duyệt HĐ giá trị lớn, xem checklist Brand Safety, cảnh báo archive; e-sign tích hợp hoàn chỉnh theo mốc Phase2 của REQ) |
| Phụ thuộc | Workflow hợp đồng của REQ-SALES-007 tại SYS-CORE-BACKEND (Template → Draft → Legal review → duyệt → E-sign → Archive, version lock, trạng thái chờ kích hoạt); không có cross-dependency FEAT ngoài lane |
| Ghi chú Expert (A7) | `sales.md` có mục A7 nhưng chưa ghi điều chỉnh cụ thể cho REQ-SALES-007; chuyên môn đã phản ánh tại Phần B (BR-SALES-701–705) và nguyên tắc CMS (serviceType bất biến) được đưa vào spec này |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Cho phép GDKD (SALES_L5) và BOD duyệt hợp đồng giá trị lớn ngay trên điện thoại với MFA step-up, xem kết quả checklist Brand Safety 7 tiêu chí và trạng thái NDA/LOI gắn từng khách, đồng thời nhận push cảnh báo trễ ký, chờ kích hoạt và archive trước hạn. Nhờ vậy không đoạn nào của luồng Template → Draft → Legal review → duyệt → E-sign → Archive bị treo vì người duyệt vắng mặt.

**Phạm vi:**
- Bao gồm: nhận push HĐ chờ duyệt theo ma trận giá trị; xem hồ sơ (bản hiện hành, diff red-line, checklist Brand Safety 7/7, trạng thái NDA mutual); duyệt/từ chối kèm lý do với MFA step-up (TOTP gắn device, P0-02 §2.4); offline-capable (đọc hồ sơ offline, hành động duyệt xếp hàng đồng bộ); cảnh báo archive 30/60/90 ngày trước hạn; thẻ trạng thái "chờ kích hoạt" và mốc D+0; audit log mọi hành động từ mobile.
- Không bao gồm: soạn HĐ từ mẫu IN/OUT of scope và thao tác checklist pass/fail (WEB — mobile chỉ đọc); luồng chữ ký khách hàng trên nền tảng e-sign; block nhận Full Brief và block tạo chiến dịch (CORE enforce tầng máy); đổi serviceType/tất toán (chỉ WEB/CORE); hạ tầng chứng thư số CA (CORE).

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | SALES_L5 (GDKD) | Duyệt HĐ giá trị lớn trên di động: xem bản hiện hành, diff red-line, checklist Brand Safety 7/7 rồi duyệt với MFA step-up | Luồng ký không treo khi tôi đi công tác; mỗi hành động có audit trail thời gian/IP/người duyệt |
| 2 | SALES_L2 (NVKD chủ deal) | Nhận push kết quả duyệt HĐ (kèm lý do nếu trả về) và trạng thái "chờ kích hoạt" | Nhắc khách nạp đủ 100% NSQC và ký HĐ đầy đủ trong 7 ngày để kịp kích hoạt D+0 |
| 3 | BOD_CEO / BOD_CFO_CTO | Nhận push HĐ vượt ngưỡng GDKD, xem tóm tắt điều khoản red-line rủi ro và ghi quyết duyệt | Kiểm soát HĐ mức cao nhất trong SLA mà không chờ văn bản giấy |
| 4 | SALES_L3 (TNKD) | Xem dashboard HĐ nhóm: bản sắp quá SLA duyệt, bản "chờ kích hoạt" quá lâu, NDA chưa mutual | Đôn đốc trước khi deal chết ở bước giấy tờ |
| 5 | SALES_L4 (TPKD) | Xem checklist Brand Safety từng deal ở EVALUATION và cảnh báo tiêu chí fail | Không đưa deal fail vào đàm phán tiếp, tránh lãng phí vòng bán |
| 6 | SALES_L5 (GDKD) | Nhận push archive alert 30/60/90 ngày trước hạn và phê duyệt tiêu hủy sau retention | HĐ không hết hạn lặng lẽ; tiêu hủy có phê duyệt và log đầy đủ |

---

## 3. Quy Tắc Nghiệp Vụ

> *Quy tắc bắt buộc — developer xử lý đúng trong code. Block và version lock enforce ở SYS-CORE-BACKEND; mobile là kênh duyệt và hiển thị, không có quyền ghi đè.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-MBI-QDD-201 | NDA mutual signed gắn khách là điều kiện nhận Full Brief 8 sections — CORE block tầng máy; LOI/MOU đàm phán không thay thế NDA | Mọi kênh bị vô hiệu nút nhận brief; mobile hiển thị "NDA chưa mutual — nhận Full Brief bị chặn"; không có override |
| BR-MBI-QDD-202 | Brand Safety 7 tiêu chí bắt buộc trước khi ký, checklist pass/fail từng tiêu chí gắn EVALUATION: (1) SP hợp pháp + giấy phép con; (2) không vi phạm Ads Policy nền tảng; (3) không spam/misleading; (4) quyền image/video/bản quyền hợp lệ; (5) landing page hợp pháp khớp quảng cáo; (6) dữ liệu mục tiêu có cơ sở thu thập; (7) không ngành cấm/nhạy cảm chưa duyệt nội bộ. Fail bất kỳ → dừng, không sang PROPOSAL; nút "Từ chối vận hành" ghi tiêu chí vi phạm + notify legal + OPS (xác nhận 24h); vi phạm knockout K1 → chấm dứt HĐ. Giả định `[KXN-6]`: bộ tiêu chí Evaluation chính thức (7 tiêu chí + weighted) còn chờ xác nhận — dùng 7 tiêu chí làm baseline, không tự thêm scoring | Deal fail bị chặn chuyển stage; mobile hiển thị tiêu chí fail; luồng ký chỉ mở khi 7/7 pass |
| BR-MBI-QDD-203 | Một hợp đồng giữ đúng một `serviceType` bất biến suốt vòng đời: RENTAL (khách tự chạy, phí 1–8% trên chi tiêu) hoặc MANAGED (BC chạy, phí 10–20% theo NSQC, gắn `pmsProjectId`); đổi dịch vụ = tất toán HĐ cũ (hoàn số dư trong 15 ngày làm việc) + mở HĐ mới | Sửa serviceType trên HĐ hiệu lực bị từ chối mọi kênh; mobile không cung cấp hành động này, hiển thị hướng dẫn luồng tất toán + HĐ mới |
| BR-MBI-QDD-204 | Version control: Draft v0.x → Counterparty v1.x → Final v2.0 → Signed khóa cứng; diff check cảnh báo khi điều khoản red-line (không cam kết KPI cứng — lead/CPA/ROAS, cap trách nhiệm, miễn trừ nền tảng) bị xóa/sửa so template; dùng mẫu đối tác hoặc đụng red-line → GDKD + luật sư duyệt 5–7 ngày làm việc | HĐ có cảnh báo red-line chưa giải trình không chuyển sang Final; mobile gắn nhãn "red-line rủi ro", chặn duyệt thường, chỉ cho gửi lại luồng 5–7 ngày |
| BR-MBI-QDD-205 | Duyệt HĐ theo ma trận giá trị: SALES_L4 mức thấp, SALES_L5 mức lớn (MFA step-up bắt buộc trên mobile), BOD mức cao nhất; ngưỡng ma trận do GDKD/BOD ban hành — con số chưa chốt `[CẦN CHỐT SỐ]`, cấu hình effective-dated không hardcode | Duyệt ngoài thẩm quyền bị API từ chối; UI ẩn nút; thiếu cấu hình ngưỡng → chặn an toàn (fail-closed) + alert SYS_ADMIN |
| BR-MBI-QDD-206 | E-sign theo Luật GDTĐT 2023 và NĐ 91/2022: chữ ký số CA cấp bởi tổ chức chứng thực, audit trail thời gian/IP/người ký; duyệt nội bộ từ mobile ghi device, IP, thời điểm, kết quả MFA vào cùng audit trail | Thiếu MFA hoặc thiếu metadata → từ chối ghi nhận; audit log WORM, không ai sửa/xóa |
| BR-MBI-QDD-207 | Kích hoạt dịch vụ: HĐ "chờ kích hoạt" khi chưa nạp đủ 100% NSQC (hard stop K4, block tạo chiến dịch tầng máy); D+0 kích hoạt khi có tiền vào + LOI/HĐ đã ký (KXN-5, KXN-10 đã chốt); HĐ đầy đủ ký tối đa trong 7 ngày kể từ D+0 theo LOI | Tạo chiến dịch khi chưa đủ 100% NSQC bị từ chối tầng API; thẻ trạng thái mobile hiển thị điều kiện còn thiếu (tiền/chữ ký) |
| BR-MBI-QDD-208 | Archive: alert 30/60/90 ngày trước hạn (push mobile); retention ≥10 năm; tiêu hủy hết hạn chỉ khi có phê duyệt + log hủy | Không có phê duyệt → nút tiêu hủy không tồn tại mọi kênh; quá mốc 30 ngày chưa xử lý → escalate SALES_L4/SALES_L5 (SM/GDKD — KXN-14) |
| BR-MBI-QDD-209 | Cấm dùng mẫu đối tác khi chưa qua legal review; điều khoản cần luật sư VN xác nhận trước khi phát hành mẫu chính thức | HĐ từ mẫu chưa legal duyệt bị chặn ở Draft; mobile hiển thị nguồn mẫu và trạng thái legal review |
| BR-MBI-QDD-210 | Mobile là kênh duyệt/xem/ký duyệt nội bộ, không soạn/upload HĐ hàng loạt (sales.md B.0); offline chỉ áp dụng cho đọc hồ sơ và hành động duyệt đã qua MFA | Request soạn/upload từ mobile bị API từ chối, hướng dẫn sang WEB |
| BR-MBI-QDD-211 | Hard gate "không ghi nhận = không tồn tại": mọi trạng thái NDA/LOI/HĐ, checklist, chữ ký phải có bản ghi hệ thống trước khi phát sinh hệ quả (nhận brief, sang PROPOSAL, kích hoạt D+0, hoàn dư tất toán) | Xác nhận miệng qua chat/Zalo không được công nhận; mobile chỉ phản ánh bản ghi CORE |

---

## 4. Phân Quyền

> *Chỉ dùng 18 vai registry. Bước Legal review do pháp chế/luật sư ngoài registry — trên hệ thống là người duyệt gán qua cấu hình luồng, không tạo vai mới.*

| Hành động (trên mobile) | SALES_L1 | SALES_L2 | SALES_L3 | SALES_L4 | SALES_L5 | BOD (CEO/CFO_CTO) | SYS_ADMIN |
|---------------------------|----------|----------|----------|----------|----------|--------------------|-----------|
| Xem HĐ/LOI/NDA gắn deal của mình, trạng thái NDA, checklist Brand Safety, diff red-line | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Duyệt HĐ theo ma trận giá trị (MFA step-up) | ❌ | ❌ | ❌ | ✅ (mức thấp) | ✅ (mức lớn) | ✅ (cao nhất) | ❌ |
| Duyệt luồng mẫu đối tác/red-line (5–7 ngày LV) | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ |
| Từ chối vận hành (ghi tiêu chí vi phạm, notify legal + OPS) | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Xem thẻ trạng thái D+0 / chờ kích hoạt | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Phê duyệt tiêu hủy HĐ hết retention | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Xem dashboard HĐ | ❌ | ❌ | ✅ (nhóm) | ✅ (phòng) | ✅ (toàn Sales) | ✅ | ❌ |
| Soạn HĐ, checklist pass/fail, tất toán đổi serviceType | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (chỉ WEB/CORE) |
| Sửa/xóa audit trail e-sign | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

Ghi chú: SALES_L1 (Intern) không tham gia luồng hợp đồng trên mobile. SYS_ADMIN cấu hình kỹ thuật (device enrollment, kênh push, kết nối e-sign provider) nhưng không duyệt nghiệp vụ, không xem nội dung HĐ, không can thiệp audit trail.

---

## 5. Trường Hợp Đặc Biệt

- **LOI đã ký nhưng chưa có NDA mutual:** deal vẫn bị chặn nhận Full Brief dù đủ tiền kích hoạt D+0; mobile hiển thị đồng thời "đủ tiền + có LOI" và "NDA chưa mutual" để sales phân biệt điều kiện vận hành với điều kiện pháp lý.
- **HĐ đầy đủ chưa ký đến hạn 7 ngày sau D+0:** đếm ngược từ ngày kích hoạt theo LOI; ngày 5–6 push nhắc SALES_L2, ngày 7 escalate SALES_L4/L5 (SM/GDKD — KXN-14); quá mốc đánh dấu vi phạm để đối soát với OPS — quyết định xử lý (không tự rollback dịch vụ) thuộc GDKD.
- **Mất mạng khi GDKD đang duyệt:** hành động đã qua MFA được ký local, xếp hàng đồng bộ; server đối chiếu version + trạng thái — nếu HĐ đã đổi trạng thái (khách sửa bản, legal trả về) thì kết quả "không áp dụng", không ghi hai lần.
- **Khách yêu cầu sửa sau Final v2.0:** quay lại luồng Counterparty với version mới; mọi cấp duyệt trước hết hạn hiệu lực và phải duyệt lại từ đầu; hàng đợi mobile tự làm mới, bản cũ đánh dấu "bị thay thế".
- **Brand Safety fail phát hiện sau khi đã ký:** xử lý theo knockout K1 → chấm dứt HĐ; mobile hiển thị sự kiện chấm dứt, tiêu chí vi phạm và trạng thái hoàn dư tất toán (hoàn trong 15 ngày làm việc theo CMS doc §1).
- **Đổi dịch vụ RENTAL ↔ MANAGED:** cấm sửa trực tiếp — tất toán HĐ cũ (theo dõi tiến độ hoàn dư 15 ngày LV trên mobile) rồi mở HĐ mới; hai HĐ song song trong thời gian chuyển tiếp với trạng thái rõ ràng.
- **Thiết bị mới/mất MFA/người duyệt vắng dài:** GDKD phải re-enroll TOTP gắn device theo P0-02 §2.4 trước khi nút duyệt bật lại — dữ liệu offline không đổi được trạng thái enroll; SM phân quyền thay thế cùng cấp trở lên qua WEB, cấm duyệt hộ chéo cấp hay chia sẻ thiết bị.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

**Entity:** Hồ sơ hợp đồng (Contract Document — gồm NDA/LOI/HĐ chính; `serviceType` của HĐ dịch vụ bất biến theo BR-MBI-QDD-203).

**Sơ đồ trạng thái:**
```
[TEMPLATE] ──(soạn, WEB)──► [DRAFT v0.x] ──► [LEGAL_REVIEW] ──(pass)──► [VALUE_APPROVAL] ──(đủ cấp)──► [COUNTERPARTY v1.x]
                                 ▲                │ (fail)                      │ (trả về)                          │ (khách sửa: version mới)
                                 └────────────────┴─────────────────────────────┴◄─────────────────────────────────┘
                                                                                                                        │ (chốt bản cuối)
                                                                                                                        ▼
                       [ARCHIVED] ◄── [SIGNED — khóa cứng] ──(chưa nạp 100% NSQC)──► [PENDING_ACTIVATION] ──(đủ tiền+ký)──► [ACTIVE]
                          │                                │                                                                │
                    (phê duyệt tiêu hủy)          (vi phạm K1 / tất toán đổi serviceType)                                    │
                          ▼                                ▼                                                                │
                     [DESTROYED]                    [TERMINATED] ◄────────────────────────────────────────────────────────┘
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `TEMPLATE` | Soạn HĐ | `DRAFT v0.x` | SALES_L2 chủ deal (WEB) | Mẫu đã qua legal review (BR-MBI-QDD-209) |
| `DRAFT v0.x` | Nộp legal review | `LEGAL_REVIEW` | SALES_L2 (WEB) | Đủ điều khoản bắt buộc, diff red-line đã chạy |
| `LEGAL_REVIEW` | Pass / trả về | `VALUE_APPROVAL` / `DRAFT v0.x` | Legal (gán qua cấu hình) | Fail phải kèm nhận xét pháp lý |
| `VALUE_APPROVAL` | Duyệt theo ma trận giá trị | `COUNTERPARTY v1.x` | SALES_L4 (thấp), SALES_L5 (lớn), BOD (cao nhất) — mobile hoặc WEB | MFA step-up trên mobile; HĐ red-line rủi ro phải qua GDKD + luật sư 5–7 ngày LV |
| `COUNTERPARTY v1.x` | Khách sửa | `COUNTERPARTY v1.x` mới | Counterparty | Mỗi thay đổi tạo version mới, diff cập nhật |
| `COUNTERPARTY v1.x` | Chốt bản cuối | `FINAL v2.0` | SALES_L2 (WEB) + xác nhận cấp duyệt | Checklist Brand Safety 7/7; NDA mutual gắn khách |
| `FINAL v2.0` | E-sign | `SIGNED` | Counterparty ký (nền tảng e-sign); cấp duyệt nội bộ mobile đã xong | Chữ ký số CA hợp lệ; audit trail; khóa cứng sau ký |
| `SIGNED` | Đánh dấu chờ kích hoạt | `PENDING_ACTIVATION` | Hệ thống | Chưa nạp đủ 100% NSQC (K4) — block tạo chiến dịch tầng máy |
| `PENDING_ACTIVATION` | Kích hoạt | `ACTIVE` | Hệ thống (theo bản ghi tiền vào + ký) | D+0: có tiền vào + LOI/HĐ ký; HĐ đầy đủ ≤7 ngày (KXN-5/KXN-10) |
| `ACTIVE` / `SIGNED` | Archive | `ARCHIVED` | Hệ thống + alert 30/60/90 ngày | Push SALES_L5; hồ sơ read-only |
| `ACTIVE` | Chấm dứt | `TERMINATED` | GDKD/BOD (WEB) | Vi phạm K1, tất toán đổi serviceType (hoàn dư ≤15 ngày LV), theo điều khoản — ghi `terminationReason` |
| `ARCHIVED` | Tiêu hủy | `DESTROYED` | BOD phê duyệt | Hết retention ≥10 năm; có phê duyệt + log hủy riêng |

**Quy tắc:** `SIGNED` khóa cứng — không sửa nội dung, chỉ phát sinh phụ lục qua version mới; `PENDING_ACTIVATION` không phải trạng thái hoạt động, mọi hệ quả vận hành bị chặn tầng máy đến khi `ACTIVE`; `DESTROYED`/`TERMINATED` là trạng thái kết thúc, lịch sử version và audit trail giữ nguyên theo retention. Mobile chỉ kích hoạt chuyển đổi tại `VALUE_APPROVAL` và phê duyệt tiêu hủy.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `ContractDocument` | `id`, `customer_id`, `deal_id`, `doc_type` (NDA/LOI/CONTRACT), `service_type` (bất biến), `version_no`, `state`, `matrix_level`, `pms_project_id` (chỉ MANAGED), `start/end_date` | FK → `customer.id`, `deal.id` | 1 HĐ 1 serviceType; đổi dịch vụ tạo `TERMINATED` + HĐ mới |
| `ContractVersion` | `id`, `contract_document_id`, `file_ref`, `redline_diff`, `is_partner_template`, `locked_at` | FK → `ContractDocument.id` | Bản `SIGNED` khóa cứng; diff red-line hiển thị trên mobile |
| `BrandSafetyChecklist` | `id`, `deal_id`, `stage` (EVALUATION), `criterion_1..7` (pass/fail), `evidence_refs`, `rejected_operation_note` | FK → `deal.id` | 7/7 pass mới mở luồng ký; bộ tiêu chí chính thức chờ `[KXN-6]` |
| `SignatureRecord` | `id`, `contract_version_id`, `signer_type` (nội bộ/khách), `signer_id`, `signed_at`, `ip`, `device_id`, `mfa_verified`, `ca_cert_ref` | FK → `ContractVersion.id` | Theo Luật GDTĐT 2023 + NĐ 91/2022; WORM |
| `NdaRecord` | `id`, `customer_id`, `signed_at`, `mutual` (bool), `file_ref` | FK → `customer.id` | 1 bản mutual signed gắn khách là điều kiện nhận Full Brief |
| `ActivationMilestone` | `id`, `contract_document_id`, `payment_confirmed_at`, `full_contract_signed_at`, `d0_date`, `full_contract_deadline` (D+7) | FK → `ContractDocument.id` | Nguồn thẻ trạng thái D+0/chờ kích hoạt trên mobile |
| `ArchiveAlert` | `id`, `contract_document_id`, `alert_at` (-30/-60/-90), `destroy_approval_id` | FK → `ContractDocument.id` | Push mobile; tiêu hủy cần phê duyệt BOD + log riêng |

---

## 8. Acceptance Criteria

> *Phác thảo sơ bộ — chi tiết hóa ở Phase 5. Mỗi scenario map về REQ-SALES-007.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: GDKD duyệt HĐ giá trị lớn trên mobile | HĐ qua legal review, Brand Safety 7/7, đúng ngưỡng GDKD | SALES_L5 mở push, MFA step-up, bấm duyệt | Chuyển trạng thái đúng luồng; audit trail ghi đủ thời gian/IP/device; SLA clock dừng | [ ] |
| SC-002: Chặn nhận Full Brief khi chưa NDA mutual | Khách có LOI ký nhưng chưa NDA mutual | Sales cố nhận Full Brief 8 sections | API từ chối tầng CORE; mobile hiển thị "NDA chưa mutual"; không có override | [ ] |
| SC-003: Brand Safety fail dừng deal | Deal ở EVALUATION, tiêu chí (5) landing page fail | Checklist ghi nhận fail | Không sang PROPOSAL; "Từ chối vận hành" ghi tiêu chí vi phạm, notify legal + OPS (24h) | [ ] |
| SC-004: Block tạo chiến dịch khi chưa nạp 100% NSQC | HĐ `SIGNED` chưa xác nhận nạp đủ 100% NSQC | Yêu cầu tạo chiến dịch | API từ chối tầng máy; thẻ trạng thái mobile: "chờ kích hoạt — thiếu nạp NSQC" | [ ] |
| SC-005: Red-line bị sửa chuyển luồng 5–7 ngày | Diff phát hiện điều khoản cap trách nhiệm bị xóa | SALES_L2 yêu cầu chuyển Final | Chặn luồng thường; yêu cầu GDKD + luật sư duyệt 5–7 ngày LV; mobile gắn nhãn red-line | [ ] |
| SC-006: Đổi serviceType bị chặn, đi luồng tất toán | HĐ RENTAL đang `ACTIVE`, khách muốn MANAGED | Yêu cầu sửa serviceType trực tiếp | Từ chối; hướng dẫn tất toán (hoàn dư ≤15 ngày LV, theo dõi mobile) + mở HĐ mới | [ ] |
| SC-007: Kích hoạt D+0 đủ điều kiện | Có bản ghi tiền vào + LOI ký, HĐ đầy đủ chưa ký | Hệ thống xác nhận điều kiện | Đánh dấu kích hoạt D+0, đếm ngược HĐ đầy đủ ≤7 ngày; ngày 5–7 push nhắc rồi escalate SALES_L4/L5 (SM/GDKD — KXN-14) | [ ] |
| SC-008: Archive alert 30/60/90 ngày | HĐ `ACTIVE` còn 30 ngày hết hạn | Job alert chạy | Push SALES_L5 kèm hồ sơ; không xử lý → escalate; tiêu hủy sau retention cần phê duyệt BOD + log | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints (duyệt mobile, push archive alert, đồng bộ offline) | `technical-specs/api-contract.md` |
| Tích hợp xuyên hệ thống (CORE block tầng máy, e-sign provider, MFA step-up P0-02 §2.4) | `technical-specs/integration-map.md` |
| Màn hình UI (hồ sơ HĐ, checklist Brand Safety, thẻ D+0) | `phase4-ux/mobile-internal/quotation-dealdesk/contract-approval.md` |
| Domain nguồn (serviceType bất biến, hoàn dư 15 ngày) | `documents/02_Quy_trinh_Cho_thue_TKQC.md` (CMS Domain Model v1 §1, §3.3) |
| Spec cùng REQ tại hệ khác | `phase2-features/core-backend/quotation-dealdesk/*.md`, `phase2-features/bcerp-web/quotation-dealdesk/*.md`, cùng lane `quotation-va-deal-desk-dinh-muc-chiet-khau-phan-cap-duyet-gm.md` (FEAT-MBI-QDD-001) |
| Ghi chú P4: SM ánh xạ SALES_L4 theo KXN-14 (đồng bộ stakeholder review 12/09) | `phase1-business/stakeholder-review.md` (F.5 — Quyết định 12/09/2026) |
