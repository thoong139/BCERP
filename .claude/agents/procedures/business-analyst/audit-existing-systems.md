# Playbook: Audit Hệ Thống Hiện Có

> **Type**: Agent Procedure
> **Agent**: business-analyst
> **Triggered by**: /wf-legacy-scan — khi dự án đã có hệ thống cũ cần phân tích và migrate vào DEVKIT
> **Output**: `.mc-data/docs/phase1-business/as-is-analysis.md`

---

## Khi nào dùng playbook này

- Được gọi trong `/wf-legacy-scan`
- Khi doanh nghiệp đã có hệ thống cũ (legacy system, spreadsheet, ERP cũ, custom-built app)
- Khi cần hiểu hệ thống hiện tại trước khi thiết kế hệ thống mới
- Khi cần xác định migration scope và dependencies
- Khi stakeholder yêu cầu gap analysis giữa hệ thống hiện tại và best practices

---

## Procedure

### Bước 1: Đọc codebase overview và context dự án

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, KNOWLEDGE_BASE

READ: .claude/references/team-expert/business-analysis/frameworks.md
      (Mục 5 Gap Analysis Framework — dùng xuyên suốt playbook này)

Scan codebase để hiểu hệ thống hiện tại:
□ Đọc README.md và tài liệu có sẵn
□ Xem cấu trúc thư mục tổng thể (Glob pattern scan)
□ Xác định tech stack hiện tại (languages, frameworks, databases)
□ Tìm schema database nếu có (migrations, models, entity files)
□ Tìm API endpoints nếu có (routes, controllers)
□ Tìm config files để hiểu integrations
```

### Bước 2: Map các tính năng hiện có của hệ thống

Tạo feature inventory từ codebase:

```
Scan theo thứ tự:
1. Controllers / Route handlers → Xác định use cases
2. Database models / Schemas → Xác định data entities
3. Service layer → Xác định business logic
4. UI screens (nếu có) → Xác định user-facing features
5. API specs (nếu có) → Xác định integrations

Với mỗi feature tìm thấy:
□ Tên tính năng
□ Module/Phòng ban liên quan
□ Actors sử dụng
□ Dữ liệu xử lý
□ Integrations với feature khác
□ Trạng thái: Active / Deprecated / Broken
```

Ghi thành Feature Inventory Table:

| Feature | Module | Actor | Status | Notes |
|---------|--------|-------|--------|-------|
| [feature-name] | [module] | [user-role] | Active/Deprecated | [ghi chú] |

### Bước 3: Identify pain points của hệ thống hiện tại

Phân tích theo 4 chiều:

**Performance & Reliability:**
```
□ Có complaints về tốc độ không? (code patterns: N+1 query, missing index)
□ Hệ thống có downtime thường xuyên không?
□ Có error handling thích hợp không?
□ Logging và monitoring có không?
```

**Maintainability & Technical Debt:**
```
□ Code structure có tuân theo SOLID principles không?
□ Có test coverage không? (unit tests, integration tests)
□ Dependencies có outdated không?
□ Có hardcoded values cần config không?
□ Documentation level của code hiện tại
```

**Business Process Alignment:**
```
□ Có workarounds nào trong code báo hiệu business process bị bẻ gãy không?
□ Có TODO/FIXME comments quan trọng không?
□ Có tính năng nào bị disable hoặc commented out không?
□ Có manual steps nào trong quy trình không được tự động hóa không?
```

**Security & Compliance:**
```
□ Authentication/Authorization có đúng chuẩn không?
□ Sensitive data có được encrypt không?
□ SQL injection, XSS, CSRF protections có không?
□ Secrets/API keys có bị hardcode không?
```

### Bước 4: Gap analysis so với best practices

Dùng Gap Analysis Framework (frameworks.md mục 5):

**Current State** — Hệ thống hiện tại đang làm gì:
```
□ Tài liệu hóa toàn bộ tính năng hiện có
□ Ghi nhận quy trình hiện tại (as-is process)
□ Xác định data models và relationships hiện có
```

**Future State** — Hệ thống mới nên như thế nào:
```
□ Dựa trên brainstorm document (Phase 0)
□ Dựa trên industry best practices cho loại hệ thống này
□ Dựa trên stakeholder expectations
```

**Gap Identification** — Phân chia theo 3 chiều:

| Gap ID | Chiều | Current State | Future State | Mức độ | Ưu tiên |
|--------|-------|---------------|-------------|--------|---------|
| GAP-001 | Process | [mô tả hiện tại] | [mục tiêu] | Critical/Major/Minor | High/Med/Low |
| GAP-002 | Technology | | | | |
| GAP-003 | People/Data | | | | |

### Bước 5: Document as-is state đầy đủ

```
Với mỗi module/domain quan trọng:

□ Business process as-is (mô tả bằng text hoặc BPMN-style notation)
□ Data model hiện tại (entities, relationships chính)
□ Integrations hiện tại (APIs, webhooks, file imports)
□ User roles và permissions hiện tại
□ Known bugs hoặc limitations đang ảnh hưởng đến business
□ Dữ liệu lịch sử cần migrate (volume, format, quality)
```

### Bước 6: Đề xuất cải tiến và migration strategy

Dựa trên gaps đã identify:

```
□ Phân loại gaps:
  - Quick wins: Ít effort, high value → làm ngay trong Phase 1 sprint
  - Strategic improvements: Cần redesign → plan cho Phase 3-5
  - Technical debt: Cần refactor → schedule riêng

□ Migration considerations:
  - Data migration: Volume? Format conversion cần không? Data quality issues?
  - Feature parity: Tính năng nào PHẢI có trước khi go-live?
  - Parallel run: Có cần chạy song song cả hai hệ thống không?
  - Rollback plan: Nếu hệ thống mới có vấn đề → quay lại thế nào?

□ Risk assessment:
  - Business continuity risk (downtime trong migration)
  - Data loss risk
  - User adoption risk
  - Integration risk với third-party systems
```

### Bước 7: Ghi output as-is analysis

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/as-is-analysis.md

Cấu trúc output:
1. Executive Summary — Tổng quan hệ thống hiện tại và key findings
2. System Overview — Tech stack, architecture overview, scale
3. Feature Inventory — Bảng tất cả tính năng hiện có
4. As-Is Business Processes — Mô tả quy trình hiện tại theo module
5. Current Data Model — Entities chính và relationships
6. Pain Points & Issues — Phân loại theo Performance/Maintainability/Process/Security
7. Gap Analysis Table — Current vs Future state với priority
8. Recommendations — Quick wins + strategic improvements + technical debt
9. Migration Considerations — Data, feature parity, risks
10. Open Questions — Cần stakeholder clarify trước khi proceed
```

---

## Checklist trước khi submit

```
□ Đã scan toàn bộ codebase structure (không chỉ đọc README)
□ Feature inventory đầy đủ với status (Active/Deprecated/Broken)
□ Pain points phân tích từ 4 chiều (Performance/Maintainability/Process/Security)
□ Gap analysis dùng đúng template (Current/Future/Gap/Priority)
□ As-is processes được document ở mức đủ để team hiểu
□ Data migration considerations đã được flag
□ Quick wins đã được tách riêng khỏi strategic improvements
□ Security issues (nếu có) được flag rõ với severity
□ Open questions về business logic không rõ trong code đã được list
□ Recommendations có priority và estimated effort
```
