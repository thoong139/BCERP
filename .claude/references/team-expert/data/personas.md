# Data & Analytics - User Personas

> **Domain**: Data & Analytics / Dữ liệu & Phân tích
> **Last Updated**: 2026-03-19

---

## Persona 1: Data Analyst

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Data Analyst / Chuyên viên Phân tích Dữ liệu |
| **Experience** | 1-4 năm |
| **Report to** | Analytics Manager hoặc BI Team Lead |
| **Focus** | Ad-hoc analysis, dashboard creation, stakeholder reporting |

### Daily Tasks

1. Viết và tối ưu SQL queries để trích xuất dữ liệu từ data warehouse
2. Xây dựng và cập nhật dashboard trên BI tools (Tableau, Power BI, Looker, Metabase)
3. Trả lời câu hỏi ad-hoc từ business stakeholders
4. Làm sạch và chuẩn hóa dữ liệu trước khi phân tích
5. Soạn stakeholder reports theo định kỳ (daily, weekly, monthly)
6. Theo dõi data freshness và alert khi pipeline có vấn đề

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Chọn chart type cho visualization | Execute | Business question, audience type |
| Xác định metric definition cho report | Recommend | Business requirements, existing data dictionary |
| Publish dashboard lên production | Request | Stakeholder sign-off, QA checklist |
| Thêm data source mới vào analysis | Request | Data owner approval, access rights |

### Pain Points

- Dành 40-60% thời gian làm sạch dữ liệu thay vì phân tích
- Câu hỏi ad-hoc liên tục làm gián đoạn công việc có kế hoạch
- Nhiều phiên bản dashboard khác nhau gây confusion về số liệu "chính thức"
- Thiếu data dictionary dẫn đến định nghĩa metric không nhất quán giữa các team
- Query chạy chậm trên dataset lớn, mất nhiều thời gian chờ kết quả

### Must-have Features

- ✅ SQL editor với autocomplete và query history
- ✅ Self-service dashboard builder kéo thả
- ✅ Data dictionary / glossary tích hợp
- ✅ Scheduled report export (PDF, Excel, CSV)
- ✅ Alert khi metric vượt ngưỡng bất thường

---

## Persona 2: BI Engineer

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | BI Engineer / Analytics Engineer |
| **Experience** | 3-7 năm |
| **Report to** | Data Engineering Manager hoặc Head of Data |
| **Focus** | Data pipeline, warehouse modeling, ETL/ELT, data quality |

### Daily Tasks

1. Thiết kế và maintain ETL/ELT pipelines (Airflow, dbt, Fivetran, Spark)
2. Xây dựng dimensional models — fact tables, dimension tables (Kimball methodology)
3. Viết transformation logic và data tests trong dbt
4. Monitor pipeline health, xử lý failures và data incidents
5. Tối ưu query performance: indexing, partitioning, materialized views
6. Document schema changes và update data catalog

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Chọn materialization strategy (table vs view vs incremental) | Execute | Data volume, query frequency, freshness requirement |
| Thiết kế schema mới trong data warehouse | Recommend | Business requirements, source system structure |
| Thay đổi grain của fact table | Recommend | Impact analysis, consumer query patterns |
| Rollback pipeline khi có data issue | Execute | Incident severity, downstream impact assessment |
| Grant data access cho team khác | Request | Data classification, access policy |

### Pain Points

- Schema changes upstream từ source systems phá vỡ pipeline không có cảnh báo
- Khó debug data quality issues khi lineage không được document đầy đủ
- Stakeholder request thêm metric nhưng không rõ business definition
- Thiếu observability: không biết pipeline fail lúc nào cho đến khi user báo lỗi
- Technical debt từ ad-hoc queries được "productionize" mà không có review

### Must-have Features

- ✅ Data lineage tracking từ source đến dashboard
- ✅ Automated data quality tests (not null, uniqueness, referential integrity)
- ✅ Pipeline monitoring và alerting real-time
- ✅ Schema version control và migration management
- ✅ Data catalog với column-level descriptions

---

## Persona 3: Analytics Manager

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Analytics Manager / Head of Data Analytics |
| **Experience** | 7-12 năm |
| **Report to** | VP of Data, CDO, hoặc COO |
| **Focus** | KPI framework, self-service analytics strategy, data governance |

### Daily Tasks

1. Định nghĩa và align KPI framework với business objectives (OKR mapping)
2. Prioritize analytics backlog từ business stakeholder requests
3. Review và approve dashboard trước khi publish chính thức
4. Xây dựng data governance policies: ownership, quality standards, access tiers
5. Báo cáo analytics ROI và adoption metrics lên leadership
6. Đánh giá và lựa chọn BI tools, data stack cho organization

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Approve KPI definition thay đổi | Approve | Business impact analysis, affected reports list |
| Quyết định self-service analytics roadmap | Approve | Tool adoption rate, user feedback, cost analysis |
| Approve data access tier cho team mới | Approve | Data classification, business justification |
| Publish dashboard thành "official" source | Approve | QA sign-off, stakeholder review checklist |
| Ngân sách BI tooling | Recommend | Usage metrics, ROI analysis, vendor proposals |

### Pain Points

- Mỗi department tự tạo metric definitions riêng dẫn đến "single source of truth" không tồn tại
- Khó đo lường ROI của analytics initiatives
- Business stakeholders bypass analytics team, tự pull data sai methodology
- Dashboard adoption thấp vì UX phức tạp hoặc không align với workflow người dùng
- Governance policies khó enforce khi team tăng trưởng nhanh

### Must-have Features

- ✅ Centralized metric catalog với official definitions
- ✅ Dashboard adoption tracking (views, unique users, export counts)
- ✅ Role-based access control theo data classification tier
- ✅ Approval workflow cho dashboard publication
- ✅ Audit log: ai xem gì, khi nào, export gì

---

## Persona 4: Business Stakeholder (Data Consumer)

### Profile

| Thuộc tính | Giá trị |
|------------|---------|
| **Role** | Department Manager, Executive, hoặc Business Analyst |
| **Experience** | Không cần technical background — domain expert |
| **Report to** | C-level hoặc VP |
| **Focus** | Xem dashboards, yêu cầu reports, ra quyết định dựa trên dữ liệu |

### Daily Tasks

1. Xem executive dashboards buổi sáng để nắm tình hình tổng quan
2. Slice và filter data theo dimension cần thiết (region, product, time period)
3. Export report ra Excel/PDF để dùng trong meetings
4. Gửi yêu cầu ad-hoc data requests đến analytics team
5. Theo dõi KPI alerts khi metric vượt ngưỡng
6. Ra quyết định operational dựa trên trend data

### Key Decisions

| Decision | Authority Level | Data Needed |
|----------|-----------------|-------------|
| Điều chỉnh budget dựa trên performance data | Approve | Revenue vs target, cost breakdown, trend |
| Yêu cầu thêm metric vào dashboard | Request | Business justification, use case |
| Chia sẻ report ra ngoài organization | Request | Data classification approval |
| Đặt target KPI cho quarter tiếp theo | Approve | Historical trend, benchmark data |

### Pain Points

- Số liệu trên các báo cáo khác nhau không khớp nhau
- Dashboard quá phức tạp, cần training mới dùng được
- Phải chờ analytics team hàng ngày để có data cơ bản
- Không biết data được cập nhật lần cuối lúc nào (data freshness không hiển thị)
- Export ra Excel bị mất format hoặc thiếu data

### Must-have Features

- ✅ Executive summary dashboard — KPI cards, traffic light status
- ✅ Bộ lọc (filter) trực quan: date range, region, product category
- ✅ Export one-click ra PDF và Excel với format chuẩn
- ✅ Data freshness indicator rõ ràng (cập nhật lúc nào)
- ✅ Email subscription tự động gửi report định kỳ

---

## Quick Reference: Access Matrix

| Data / Function | Data Analyst | BI Engineer | Analytics Manager | Business Stakeholder |
|----------------|:------------:|:-----------:|:-----------------:|:--------------------:|
| Raw source tables | ✅ | ✅ | ⚠ Read-only | ❌ |
| Data warehouse (curated) | ✅ | ✅ | ✅ | ❌ |
| Data marts / reporting layer | ✅ | ✅ | ✅ | ✅ |
| PII / sensitive fields | ⚠ Masked | ⚠ Masked | ⚠ Role-based | ❌ |
| Dashboard builder | ✅ | ✅ | ✅ | ❌ |
| Dashboard viewer | ✅ | ✅ | ✅ | ✅ |
| Report export | ✅ | ✅ | ✅ | ✅ |
| Pipeline management | ❌ | ✅ | ⚠ Monitor only | ❌ |
| Access grant | ❌ | ❌ | ✅ | ❌ |
| Metric definition edit | ❌ | ❌ | ✅ | ❌ |
| Schema changes | ❌ | ✅ | ⚠ Approve only | ❌ |
| Audit logs | ❌ | ✅ | ✅ | ❌ |

<!-- ✅ = Full access, ❌ = No access, ⚠ = Conditional — xem điều kiện ghi chú trong ô -->
