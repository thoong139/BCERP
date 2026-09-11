# Domain Expert Mapping

Bảng tra cứu đa chiều: phòng ban → experts, ngành → phòng ban, pattern multi-system.
Dùng cho `/wf-brainstorm` (Phase 2+5) và `/wf-analyze-requirements`.

> **Quy tắc:** `business-analyst` LUÔN được spawn trước/cùng. Domain experts bổ sung dựa vào phòng ban user chọn.

---

## Cách sử dụng

```
1. wf-brainstorm Phase 1:
   → Phát hiện keywords ngành → lookup Section 4 → detected_industries[]
   → Lookup Section 3 → pre-populate gợi ý phòng ban (step 2.2)

2. wf-brainstorm Phase 2 (sau step 2.2 — user đã chọn phòng ban):
   → Lookup từng phòng ban đã chọn trong Section 1
   → Union tất cả experts → dedup → so sánh Section 2 (Multi-System Patterns) → bổ sung nếu khớp
   → Spawn PARALLEL (tối đa 5 cùng lúc, batch nếu cần)

3. wf-analyze-requirements:
   → Đọc active_depts[] từ brainstorm output
   → Lookup Section 1 → union experts → so sánh Section 2 → spawn theo batches

4. wf-brainstorm Phase 5 (scaffolding):
   → Detect domain từ context → lookup Section 4 (keywords) → Section 3 (industry → depts)
   → Hiển thị expert recommendations trong Output Report

Quy tắc union + dedup:
- Mỗi expert chỉ spawn 1 lần dù xuất hiện trong nhiều phòng ban
- business-analyst luôn spawn đầu tiên (solo) để đề xuất phòng ban
- Tối đa 5 domain experts song song — batching nếu cần hơn
```

---

## Section 1 — Department → Expert Mapping (PRIMARY)

Mỗi Agent Expert đóng vai là **chuyên gia nội bộ** của doanh nghiệp.
Tùy chuyên môn, họ được phân công vào phòng ban phù hợp.
Cấu trúc 3 tầng: **Core** (mọi DN) → **Industry** (theo lĩnh vực) → **Extended** (mở rộng).

---

### Tầng 1 — Core Departments (Hầu hết doanh nghiệp đều có)

| Phòng ban | Primary Expert | Supporting Experts | Ghi chú |
|-----------|---------------|-------------------|---------|
| Ban lãnh đạo / BOD / Điều hành | `business-analyst` | `data-expert`, `finance-expert` | Chiến lược, quản trị, ra quyết định |
| Kế hoạch & Chiến lược / Strategy | `business-analyst` | `data-expert`, `finance-expert` | Lập kế hoạch dài hạn, OKR, KPI |
| Tài chính & Kế toán | `finance-expert` | `compliance-expert` | GL, AR, AP, ngân sách, báo cáo tài chính |
| Nhân sự / HRM / People | `hr-expert` | `legal-expert` | Tuyển dụng, payroll, performance, onboarding |
| Kinh doanh & Bán hàng / Sales | `sales-expert` | `customer-expert` | Pipeline, quotation, order management |
| Chăm sóc khách hàng / CSKH | `customer-expert` | `data-expert` | Helpdesk, ticket, NPS, after-sales support |
| Marketing & Truyền thông | `marketing-expert` | `paid-media-expert`, `data-expert` | Campaign, content, brand, SEO/SEM |
| Pháp lý & Thủ tục / Legal | `legal-expert` | `compliance-expert` | Hợp đồng, giấy phép, NDA, GDPR |
| IT & Kỹ thuật nội bộ | `business-analyst` | `sre`, `enterprise-risk-expert`, `data-expert` | Yêu cầu hệ thống nội bộ, IT governance, change management, BCP/DR |

---

### Tầng 2 — Industry Departments (Theo lĩnh vực & mô hình kinh doanh)

| Phòng ban | Primary Expert | Supporting Experts | Lĩnh vực thường gặp |
|-----------|---------------|-------------------|---------------------|
| Kho & Vận hành / Operations | `operations-expert` | `logistics-expert`, `procurement-expert` | Sản xuất, thương mại, F&B, bán lẻ |
| Thu mua / Mua hàng / Procurement | `procurement-expert` | `operations-expert` | Sản xuất, thương mại, bệnh viện |
| Chuỗi cung ứng / Supply Chain | `operations-expert` | `logistics-expert`, `procurement-expert` | Sản xuất, FMCG, bán lẻ chuỗi |
| Sản xuất / Nhà máy / Manufacturing | `manufacturing-expert` | `operations-expert`, `procurement-expert` | Sản xuất, gia công, lắp ráp |
| Xuất nhập khẩu / Hải quan / Logistics | `logistics-expert` | `compliance-expert`, `operations-expert` | Thương mại quốc tế, XNK, giao nhận |
| Vận tải & Giao nhận / Delivery | `logistics-expert` | `operations-expert` | Logistics, courier, 3PL |
| Bán lẻ / Chuỗi cửa hàng / Retail | `retail-expert` | `sales-expert`, `operations-expert` | Chuỗi bán lẻ, siêu thị, franchise |
| Thương mại điện tử / Marketplace | `ecommerce-expert` | `marketing-expert`, `paid-media-expert` | TMĐT, marketplace, D2C |
| Quảng cáo / Paid Media / Digital Ads | `paid-media-expert` | `marketing-expert`, `data-expert` | Agency, brand có ngân sách ads lớn |
| Y tế / Lâm sàng / Clinic | `healthcare-expert` | `compliance-expert`, `legal-expert` | Bệnh viện, phòng khám, dược |
| Dược / Pharmacy | `healthcare-expert` | `compliance-expert`, `procurement-expert` | Bệnh viện, chuỗi nhà thuốc |

---

### Tầng 3 — Extended Departments (Doanh nghiệp mở rộng / đặc thù)

| Phòng ban | Primary Expert | Supporting Experts | Ghi chú |
|-----------|---------------|-------------------|---------|
| Phân tích & BI / Analytics | `data-expert` | `finance-expert`, `marketing-expert` | Báo cáo, dashboard, data-driven decisions |
| Phát triển sản phẩm / Product | `product-expert` | `data-expert`, `customer-expert` | SaaS, tech product, platform |
| Pháp chế & Kiểm toán nội bộ | `compliance-expert` | `legal-expert`, `finance-expert` | Tập đoàn, DN niêm yết, ngân hàng |
| Giáo dục & Đào tạo nội bộ / L&D | `hr-expert` | `product-expert` | Doanh nghiệp lớn, training program |
| Quan hệ đối tác / Business Dev | `sales-expert` | `marketing-expert`, `legal-expert` | Partnership, alliance, channel sales |
| Quan hệ công chúng / PR | `marketing-expert` | `data-expert` | Brand lớn, tập đoàn, DN có investor |
| Dịch vụ hậu mãi / After-sales | `customer-expert` | `operations-expert` | Warranty, maintenance, service contract |
| R&D / Nghiên cứu & Phát triển | `product-expert` | `data-expert`, `manufacturing-expert` | Công ty công nghệ, dược, sản xuất |
| Quản lý chất lượng / QA-QC | `quality-excellence-expert` | `manufacturing-expert`, `compliance-expert`, `operations-expert` | Sản xuất, dược, thực phẩm, ISO 9001/IATF |
| Quản trị rủi ro / ERM / GRC | `enterprise-risk-expert` | `compliance-expert`, `finance-expert` | Tập đoàn, ngân hàng, bảo hiểm, DN niêm yết |
| Bảo trì & Kỹ thuật / Maintenance | `manufacturing-expert` | `operations-expert` | Sản xuất, nhà máy, hạ tầng |
| Môi giới / Agency / Sales Partner | `sales-expert` | `legal-expert` | BĐS, bảo hiểm, tài chính |
| Tổng đài / Call Center | `customer-expert` | `data-expert` | Dịch vụ, telecom, ngân hàng |

---

## Section 2 — Multi-System Patterns

Khi dự án gồm nhiều phần mềm — spawn union tất cả experts bên dưới (dedup).

| Pattern | Mô tả | Experts (đã dedup) |
|---------|-------|-------------------|
| **ERP toàn phần** | Finance + HR + Operations + Sales + Procurement | `finance-expert`, `hr-expert`, `operations-expert`, `sales-expert`, `procurement-expert`, `compliance-expert` |
| **ERP + CRM** | ERP + Sales pipeline + Marketing automation | Thêm: `marketing-expert`, `customer-expert`, `data-expert` |
| **ERP + Website B2B** | ERP + Cổng khách hàng / Order portal | Thêm: `ecommerce-expert` |
| **ERP + CRM + Website** | Full enterprise suite | `finance-expert`, `hr-expert`, `operations-expert`, `sales-expert`, `procurement-expert`, `marketing-expert`, `customer-expert`, `data-expert`, `ecommerce-expert`, `compliance-expert` |
| **CRM Standalone** | Sales pipeline + Marketing automation | `sales-expert`, `marketing-expert`, `customer-expert`, `data-expert`, `paid-media-expert` |
| **Digital Marketing Suite** | Ads + Analytics + CRM light | `marketing-expert`, `paid-media-expert`, `data-expert`, `customer-expert` |
| **Startup SaaS / Platform** | Product-led growth | `product-expert`, `data-expert`, `customer-expert`, `marketing-expert` |
| **Manufacturing ERP** | Sản xuất + Chuỗi cung ứng | `manufacturing-expert`, `operations-expert`, `procurement-expert`, `finance-expert`, `logistics-expert`, `quality-excellence-expert` |
| **Healthcare Platform** | EMR + Billing + Compliance | `healthcare-expert`, `finance-expert`, `compliance-expert`, `legal-expert`, `enterprise-risk-expert` |
| **Retail Chain / POS** | Chuỗi bán lẻ + Inventory + CRM | `retail-expert`, `operations-expert`, `sales-expert`, `ecommerce-expert` |
| **Logistics / XNK Platform** | WMS + TMS + Customs | `logistics-expert`, `operations-expert`, `compliance-expert` |
| **F&B Chain** | Chuỗi nhà hàng / Cafe | `retail-expert`, `operations-expert`, `procurement-expert`, `finance-expert`, `marketing-expert` |
| **Real Estate Platform** | Bán + Quản lý BĐS | `sales-expert`, `legal-expert`, `finance-expert`, `marketing-expert` |
| **EdTech / E-learning** | Platform giáo dục | `product-expert`, `customer-expert`, `data-expert`, `marketing-expert` |
| **Professional Services** | Consulting / Agency / Law firm | `finance-expert`, `legal-expert`, `hr-expert`, `sales-expert` |
| **Tập đoàn / Holding** | Multi-entity, nhiều pháp nhân | `finance-expert`, `compliance-expert`, `legal-expert`, `hr-expert`, `data-expert`, `enterprise-risk-expert`, `business-analyst` |
| **GRC Platform** | Governance, Risk, Compliance | `enterprise-risk-expert`, `compliance-expert`, `legal-expert`, `finance-expert`, `data-expert` |
| **Quality Management System** | ISO 9001, Six Sigma, FMEA | `quality-excellence-expert`, `manufacturing-expert`, `operations-expert`, `compliance-expert`, `data-expert` |

---

## Section 3 — Industry → Departments (pre-populate gợi ý phòng ban)

Khi user mô tả ngành ở Phase 1 — dùng để đề xuất phòng ban mặc định ở step 2.2.
★ = phòng ban ưu tiên gợi ý. Tầng 1 (Core) luôn hiện nhưng có thể bỏ check.

| Ngành | Tầng 1 (Core) luôn có | Tầng 2 (Industry) đặc thù | Tầng 3 (Extended) nếu phù hợp |
|-------|----------------------|--------------------------|-------------------------------|
| **Xuất nhập khẩu / Thương mại quốc tế** | Tài chính, Kinh doanh, Nhân sự, Pháp lý | ★ Xuất nhập khẩu/Logistics, ★ Kho/Vận hành, Thu mua | Pháp chế/Kiểm toán, Kế hoạch & Chiến lược |
| **Sản xuất / Nhà máy** | Tài chính, Nhân sự, Pháp lý | ★ Sản xuất/Nhà máy, ★ Thu mua, ★ Kho/Vận hành | ★ Quản lý chất lượng/QMS, R&D, Bảo trì |
| **Bán lẻ / Chuỗi cửa hàng** | Tài chính, Kinh doanh, Marketing, Nhân sự | ★ Bán lẻ/Chuỗi, ★ Kho/Vận hành | Dịch vụ hậu mãi, Phân tích & BI |
| **Thương mại điện tử / TMĐT** | Tài chính, Kinh doanh, Nhân sự | ★ TMĐT/Marketplace, ★ Marketing, ★ Quảng cáo/Paid Media, Kho/Vận hành | CSKH, Phân tích & BI |
| **Tài chính / Ngân hàng / Bảo hiểm** | ★ Tài chính & Kế toán, Pháp lý, Nhân sự, BOD | ★ Pháp chế/Kiểm toán, ★ Quản trị rủi ro/ERM | Kế hoạch & Chiến lược, Phân tích & BI, Tổng đài |
| **Y tế / Bệnh viện / Phòng khám** | Tài chính, Nhân sự, Pháp lý | ★ Y tế/Lâm sàng, ★ Dược | Pháp chế/Kiểm toán, CSKH |
| **Phần mềm / SaaS / Tech** | Tài chính, Nhân sự, Kinh doanh | ★ Phát triển sản phẩm, CSKH | ★ Phân tích & BI, Marketing, R&D |
| **F&B / Nhà hàng / Chuỗi cafe** | Tài chính, Nhân sự, Marketing | ★ Kho/Vận hành, ★ Thu mua, Bán lẻ/Chuỗi | Quản lý chất lượng, Dịch vụ hậu mãi |
| **Bất động sản** | Tài chính, Pháp lý, Marketing | ★ Kinh doanh/Bán hàng, Môi giới/Agency | Kế hoạch & Chiến lược, Quan hệ đối tác |
| **Giáo dục / EdTech** | Tài chính, Nhân sự, Marketing | ★ Phát triển sản phẩm, CSKH | Giáo dục/Đào tạo nội bộ, Phân tích & BI |
| **Logistics / Vận tải / Giao nhận** | Tài chính, Nhân sự, Kinh doanh | ★ Vận tải & Giao nhận, ★ Xuất nhập khẩu, Kho/Vận hành | Pháp chế/Kiểm toán |
| **Dịch vụ chuyên nghiệp / Consulting** | ★ Tài chính, Pháp lý, Nhân sự, Kinh doanh | Quan hệ đối tác | Kế hoạch & Chiến lược, Phân tích & BI |
| **Tập đoàn / Holding / Đa ngành** | BOD, Tài chính, Nhân sự, Pháp lý | Chuỗi cung ứng | ★ Kế hoạch & Chiến lược, ★ Pháp chế/Kiểm toán, ★ Quản trị rủi ro/ERM, Phân tích & BI |
| **Agency / Creative / Media** | Tài chính, Nhân sự, Kinh doanh | ★ Marketing, ★ Quảng cáo/Paid Media | Phát triển sản phẩm, PR |
| **Đa ngành / Chưa xác định** | (business-analyst tự phân tích và đề xuất tất cả tầng phù hợp) | — | — |

---

## Section 4 — Keyword Detection (tự động phát hiện ngành từ Phase 1)

Phát hiện keywords trong câu trả lời Phase 1 để detect ngành. **Một project có thể khớp nhiều ngành** → spawn experts cho TẤT CẢ ngành khớp.

| Keywords phát hiện | Ngành | → Lookup Section 3 |
|-------------------|-------|-------------------|
| erp, quản trị doanh nghiệp, tổng thể doanh nghiệp | ERP | Xuất nhập khẩu hoặc Sản xuất (tuỳ context) |
| xuất nhập khẩu, hải quan, hs code, vnaccs, thông quan, freight, incoterms | Logistics/XNK | Xuất nhập khẩu |
| crm, sales pipeline, quản lý bán hàng, deal, opportunity, forecast | CRM/Sales | Bán lẻ hoặc Dịch vụ |
| shop, e-commerce, marketplace, tmđt, giỏ hàng, checkout, storefront | E-commerce | Thương mại điện tử |
| hr, nhân sự, payroll, tuyển dụng, chấm công, okr, onboarding | HR | Phần mềm (HR module) |
| kế toán, tài chính, invoice, gl, ap, ar, ngân sách, hóa đơn | Finance | Tài chính/Ngân hàng |
| kho, wms, warehouse, tồn kho, kiểm kho, nhập xuất kho | Logistics/Warehouse | Sản xuất hoặc Bán lẻ |
| tms, vận chuyển, giao nhận, fleet, shipping, delivery | TMS/Logistics | Logistics |
| sản xuất, nhà máy, mes, bom, mrp, work order, dây chuyền, gia công | Manufacturing | Sản xuất |
| bệnh viện, phòng khám, emr, ehr, bệnh nhân, lâm sàng, dược | Healthcare | Y tế |
| bán lẻ, siêu thị, pos, chuỗi cửa hàng, franchise, f&b | Retail | Bán lẻ |
| nhà hàng, cafe, coffee, quán ăn, menu, thực đơn | F&B | F&B |
| saas, platform, app, phần mềm b2b, subscription, api | SaaS/Product | Phần mềm |
| marketing, campaign, lead, email marketing, content, seo, brand | Marketing | Bán lẻ hoặc Phần mềm |
| quảng cáo, google ads, facebook ads, meta ads, paid, roas, cpa | AdTech | Thương mại điện tử |
| analytics, bi, dashboard, báo cáo, data warehouse, kpi, metrics | Analytics/BI | Phần mềm |
| hợp đồng, pháp lý, legal, gdpr, compliance, nda, clm | Legal/Contract | Dịch vụ chuyên nghiệp |
| bất động sản, real estate, căn hộ, dự án bds, môi giới | Real Estate | Bất động sản |
| trường học, học sinh, giáo dục, edtech, lms, khóa học, e-learning | Education/EdTech | Giáo dục |
| consulting, tư vấn, agency, dịch vụ chuyên nghiệp, professional | Professional Services | Dịch vụ chuyên nghiệp |
| tập đoàn, holding, đa ngành, conglomerate, subsidiary | Tập đoàn | Tập đoàn |
| insurance, bảo hiểm, claim, policy, underwriting | Insurance | Tài chính |
| logistics, 3pl, fulfillment, last-mile, cross-border | Logistics | Logistics |
| erm, enterprise risk, risk management, risk governance, risk appetite, kri, bcp, drp, rủi ro doanh nghiệp, quản trị rủi ro | Enterprise Risk / GRC | Tài chính/Ngân hàng hoặc Tập đoàn |
| qms, iso 9001, six sigma, dmaic, fmea, capa, quality management, quản lý chất lượng, cải tiến quy trình | Quality Management | Sản xuất hoặc F&B/Dược |
| (không khớp từ khoá nào) | Đa ngành | (business-analyst tự đề xuất) |

---

## Section 5 — Expert Cheat Sheet (tóm tắt vai trò)

Tham chiếu nhanh mỗi expert đảm nhận gì trong doanh nghiệp.

| Agent Expert | Vai trò trong doanh nghiệp | Domain chính |
|-------------|--------------------------|-------------|
| `business-analyst` | Chuyên gia phân tích nghiệp vụ toàn doanh nghiệp, cầu nối giữa business và IT | Cross-functional |
| `finance-expert` | CFO/Kế toán trưởng — quản lý tài chính, kế toán, ngân sách | Finance & Accounting |
| `hr-expert` | CHRO/Trưởng Nhân sự — tuyển dụng, payroll, phát triển nhân lực | Human Resources |
| `legal-expert` | Giám đốc Pháp lý — hợp đồng, giấy phép, tuân thủ pháp luật | Legal & Compliance |
| `compliance-expert` | Trưởng Kiểm toán nội bộ — kiểm soát nội bộ, audit, risk management | Audit & Compliance |
| `sales-expert` | Sales Director — pipeline, quota, commission, sales ops | Sales & Business Dev |
| `customer-expert` | Head of CX/CS — helpdesk, NPS, customer journey, support | Customer Experience |
| `marketing-expert` | CMO — campaign, content, brand, growth marketing | Marketing |
| `paid-media-expert` | Head of Paid — Google/Meta/TikTok Ads, ROAS, media buying | Digital Advertising |
| `data-expert` | Head of Data/BI — analytics, dashboard, data warehouse, KPI | Analytics & BI |
| `operations-expert` | COO/Ops Manager — vận hành kho, quy trình, supply chain | Operations |
| `procurement-expert` | Trưởng Thu mua — vendor management, RFQ, PO, sourcing | Procurement |
| `manufacturing-expert` | Giám đốc Sản xuất — MES, BOM, MRP, quality control | Manufacturing |
| `logistics-expert` | Giám đốc Logistics — XNK, hải quan, TMS, Incoterms, 3PL | Logistics & Customs |
| `healthcare-expert` | Giám đốc Y tế/Dược — EMR, clinical workflow, pharmacy | Healthcare |
| `retail-expert` | Retail Director — POS, store ops, inventory, franchise | Retail |
| `ecommerce-expert` | Head of E-commerce — marketplace, cart, fulfillment, D2C | E-commerce |
| `product-expert` | CPO/Product Manager — roadmap, backlog, user story, MVP | Product Management |
| `enterprise-risk-expert` | CRO/Risk Manager — ERM framework, risk governance, KRI, BCP/DRP (COSO ERM 2017, ISO 31000) | Enterprise Risk Management |
| `quality-excellence-expert` | Quality Director/Black Belt — QMS, ISO 9001, Six Sigma DMAIC, FMEA, CAPA | Quality Management |
