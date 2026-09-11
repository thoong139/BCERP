# Playbook: Review Requirements Completeness

> **Type**: Agent Procedure
> **Agent**: business-analyst
> **Triggered by**: Cuối Phase 1 (/wf-analyze-requirements) hoặc Phase 3 (/wf-design) — review và validate requirements trước khi chuyển phase
> **Output**: Completeness review report tại `.mc-data/docs/phase1-business/requirements-completeness-report.md`

---

## Khi nào dùng playbook này

- Cuối Phase 1 — trước khi chuyển sang `/wf-define-features` (Phase 2)
- Trong Phase 3 `/wf-design` — kiểm tra architecture alignment với requirements
- Khi stakeholder yêu cầu quality gate trước khi tiếp tục
- Khi phát hiện inconsistency hoặc gap trong requirements

---

## Procedure

### Bước 1: Đọc toàn bộ requirements documents

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE1, PHASE1_DEPTS, REGISTRY

Danh sách files cần đọc:
□ .mc-data/docs/_meta/req-registry.json — SSOT cho tất cả REQ-IDs
□ .mc-data/docs/phase1-business/business-requirements.md (nếu có)
□ .mc-data/docs/phase1-business/stakeholder-map.md (nếu có)
□ .mc-data/docs/phase1-business/[dept]-requirements.md — tất cả domain files
□ .mc-data/docs/phase0-brainstorm/P0-01-brainstorm.md — để so sánh với intent ban đầu

READ: .claude/references/team-expert/business-analysis/frameworks.md
      (Mục 4 Prioritization Methods, Mục 5 Gap Analysis)
```

### Bước 2: Kiểm tra coverage — Functional Requirements

Với mỗi system/module trong registry:

```
□ Mỗi module có ít nhất 1 REQ-ID không?
□ Core user journeys đã được cover chưa?
   - Create / Read / Update / Delete operations chính
   - Happy path + error handling
□ Mỗi role/persona có ít nhất 1 requirement liên quan chưa?
□ Integration requirements giữa các module đã explicit chưa?
□ Reporting & analytics requirements đã có chưa?
```

Sử dụng bảng tracking:

| Module | Số REQ | Core Journeys Covered | Missing Areas |
|--------|--------|-----------------------|---------------|
| [module-name] | [N] | Yes/Partial/No | [danh sách] |

### Bước 3: Kiểm tra coverage — Non-functional Requirements

```
Performance:
□ Có yêu cầu response time không? (P95 < X ms)
□ Có yêu cầu concurrent users không?
□ Có yêu cầu throughput không? (requests/giây)

Security:
□ Authentication & Authorization requirements có không?
□ Data encryption at rest và in transit có không?
□ Audit trail requirements cho sensitive data có không?
□ Compliance requirements (GDPR, PCI-DSS, HIPAA, ...) có không?

Reliability:
□ Uptime SLA có không? (99.9%?)
□ Backup & Recovery requirements có không?
□ Disaster recovery plan được đề cập chưa?

Usability:
□ Accessibility requirements (WCAG 2.1) có không?
□ Multilingual/localization requirements có không?
□ Mobile responsiveness có được yêu cầu không?

Maintainability:
□ Logging & monitoring requirements có không?
□ Integration với external systems có SLA không?
```

### Bước 4: Validate REQ-ID format và consistency

```
Dùng Grep để scan tất cả documents:

□ Mọi REQ-ID đều khớp format: REQ-[DEPT]-[NNN] hoặc REQ-[SYS]-[MOD]-[NNN]?
□ Không có duplicate REQ-ID?
□ Tất cả REQ-ID trong documents có trong req-registry.json không?
□ Tất cả REQ-ID trong registry có được document đầy đủ không?
□ Mỗi REQ có đủ 4 fields bắt buộc: Mô tả, Business Value, Acceptance Criteria, Priority?
```

### Bước 5: Kiểm tra dependencies và conflicts

```
□ Dependencies giữa các REQ có hợp lý không?
   - REQ-A depends on REQ-B → REQ-B có cùng priority hoặc cao hơn không?
   - Không có circular dependency?

□ Conflicts giữa requirements:
   - Hai REQ có mâu thuẫn nhau không? (Ví dụ: REQ-001 yêu cầu public access, REQ-002 yêu cầu restricted access)
   - Nếu có conflict → Document rõ và escalate cho stakeholders

□ Scope creep check:
   - Có REQ nào vượt ngoài phạm vi brainstorm ban đầu không?
   - Nếu có → Flag để stakeholder review
```

### Bước 6: Identify gaps và vấn đề chưa được giải quyết

Ghi lại theo 3 loại:

**Gap Type A — Thiếu requirement:**
```
"Module X được nhắc đến trong brainstorm nhưng chưa có REQ-ID nào"
"Persona Y chưa có use case nào cover"
"Integration với hệ thống Z chưa được spec"
```

**Gap Type B — Requirement chưa đủ chi tiết:**
```
"REQ-001 thiếu Acceptance Criteria measurable"
"REQ-005 chưa có Business Value rõ ràng"
"REQ-010 không rõ ai là stakeholder chính"
```

**Gap Type C — Mâu thuẫn cần giải quyết:**
```
"REQ-020 và REQ-025 có conflicting assumptions về user permission model"
"REQ-030 yêu cầu real-time nhưng budget constraint ở REQ-031 không khả thi"
```

### Bước 7: Tính điểm completeness và phân loại

Scoring tổng quát:

| Tiêu chí | Trọng số | Score (1-5) | Weighted |
|----------|----------|-------------|---------|
| Functional coverage | 30% | | |
| Non-functional requirements | 20% | | |
| REQ-ID format compliance | 15% | | |
| Acceptance criteria quality | 20% | | |
| Dependencies và consistency | 15% | | |
| **Total** | 100% | | |

Thang điểm:
- 4.5–5.0: Excellent — có thể tiếp tục Phase 2
- 3.5–4.4: Good — minor gaps, có thể tiếp tục với ghi chú
- 2.5–3.4: Fair — cần bổ sung trước khi tiếp tục
- < 2.5: Poor — cần làm lại requirements phase

### Bước 8: Ghi output completeness report

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase1-business/requirements-completeness-report.md

Cấu trúc output:
1. Executive Summary — Kết quả tổng thể và khuyến nghị
2. Coverage Analysis — Functional + Non-functional
3. REQ-ID Validation Results
4. Gaps Identified — Loại A, B, C với priority
5. Conflicts và Inconsistencies
6. Completeness Score
7. Recommended Actions — Ordered by priority
8. Go/No-Go Recommendation cho Phase tiếp theo
```

---

## Checklist trước khi submit

```
□ Đã đọc toàn bộ phase1-business documents và req-registry.json
□ Coverage check cho cả functional và non-functional requirements
□ REQ-ID format validation đã chạy
□ Dependencies và conflicts đã được check
□ Gaps được phân loại rõ Type A, B, C
□ Completeness score được tính với rationale
□ Go/No-Go recommendation rõ ràng với lý do cụ thể
□ Recommended actions có priority và owner rõ ràng
□ Đối chiếu với brainstorm document để phát hiện scope drift
```
