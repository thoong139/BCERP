# Path Registry — DEVKIT Central Path Configuration

> **Mục đích:** File này là SINGLE SOURCE OF TRUTH cho tất cả paths trong DEVKIT.
> Agents và skills tra cứu file này thay vì hardcode paths.
> Khi cấu trúc thư mục thay đổi, CHỈ CẦN SỬA FILE NÀY.

---

## 1. Project Data Root

| Alias | Path | Mô tả |
|-------|------|--------|
| `PROJECT_ROOT` | `.mc-data/` | Thư mục gốc dữ liệu dự án |

---

## 2. Document Paths (Output của các phases)

| Phase | Alias | Path |
|-------|-------|------|
| Meta / Registry | `META` | `.mc-data/docs/_meta/` |
| Registry JSON | `REQ_REGISTRY` | `.mc-data/docs/_meta/req-registry.json` |
| Phase 0 — Brainstorm | `PHASE0` | `.mc-data/docs/phase0-brainstorm/` |
| Phase 1 — Business | `PHASE1` | `.mc-data/docs/phase1-business/` |
| Phase 1 — Departments | `PHASE1_DEPTS` | `.mc-data/docs/phase1-business/departments/` |
| Phase 1 — Dept Index | `PHASE1_DEPT_INDEX` | `.mc-data/docs/phase1-business/departments/_index.md` |
| Phase 2 — Features | `PHASE2` | `.mc-data/docs/phase2-features/` |
| Phase 3 — Architecture | `PHASE3` | `.mc-data/docs/phase3-architecture/` |
| Phase 3 — Technical Specs | `PHASE3_SPECS` | `.mc-data/docs/phase3-architecture/technical-specs/` |
| Phase 4 — UX/UI | `PHASE4` | `.mc-data/docs/phase4-ux/` |
| Phase 5 — Implementation | `PHASE5` | `.mc-data/docs/phase5-implementation/` |
| Phase 5 — Tasks | `PHASE5_TASKS` | `.mc-data/docs/phase5-implementation/tasks/` |
| Phase 5 — Sprints | `PHASE5_SPRINTS` | `.mc-data/docs/phase5-implementation/sprints/` |
| Phase 6 — Deployment | `PHASE6` | `.mc-data/docs/phase6-deployment/` |

---

## 3. Work Paths (Dữ liệu làm việc của skills)

| Skill | Alias | Path |
|-------|-------|------|
| wf-analyze-requirements | `WORK_ANALYZE` | `.mc-data/work/wf-analyze-requirements/` |
| wf-define-features | `WORK_DEFINE` | `.mc-data/work/wf-define-features/` |
| wf-design | `WORK_DESIGN` | `.mc-data/work/wf-design/` |
| wf-design-ux | `WORK_DESIGN_UX` | `.mc-data/work/wf-design-ux/` |
| wf-plan-modules | `WORK_PLAN` | `.mc-data/work/wf-plan-modules/` |
| wf-implement-feature | `WORK_IMPL` | `.mc-data/work/wf-implement-feature/` |
| wf-legacy-scan | `WORK_LEGACY_SCAN` | `.mc-data/work/legacy-scan/` |
| wf-legacy-classify | `WORK_LEGACY_CLASSIFY` | `.mc-data/work/legacy-scan/` |
| wf-legacy-extract | `WORK_LEGACY_EXTRACT` | `.mc-data/work/legacy-scan/` |
| wf-brainstorm (legacy flow) | `WORK_LEGACY_BRAINSTORM` | `.mc-data/work/legacy-scan/` |
| wf-analyze-requirements (legacy flow) | `WORK_LEGACY_ANALYZE` | `.mc-data/work/legacy-scan/` |
| wf-define-features (legacy flow) | `WORK_LEGACY_DEFINE` | `.mc-data/work/legacy-scan/` |
| wf-design (legacy flow) | `WORK_LEGACY_DESIGN` | `.mc-data/work/legacy-scan/` |
| wf-design-ux (legacy flow) | `WORK_LEGACY_DESIGN_UX` | `.mc-data/work/legacy-scan/` |

---

## 4. Supplementary Paths

| Alias | Path | Mô tả |
|-------|------|--------|
| `KNOWLEDGE_BASE` | `.mc-data/knowledge-base/` | Ghi chú bổ sung (optional) |
| `SYNC` | `.mc-data/sync/` | REQ-ID sync tracking data |

---

## 5. DEVKIT Internal Paths (Không thay đổi theo dự án)

| Alias | Path | Mô tả |
|-------|------|--------|
| `DOC_FRAMEWORK` | `.claude/doc-framework/` | Templates gốc |
| `DOC_FRAMEWORK_PHASE1` | `.claude/doc-framework/phase1-business/` | Templates Phase 1 |
| `DOC_FRAMEWORK_DEPTS` | `.claude/doc-framework/phase1-business/departments/` | Templates departments |
| `REFERENCES` | `.claude/references/` | Domain knowledge cho experts |
| `TEAM_EXPERT_REF` | `.claude/references/team-expert/` | References cho Team Expert |
| `TEAM_ENGINEERING_REF` | `.claude/references/team-expert/engineering/` | References cho Engineering Team |
| `TEAM_DESIGN_REF` | `.claude/references/team-expert/design/` | References cho Design Team |
| `TEAM_TESTING_REF` | `.claude/references/team-expert/testing/` | References cho Testing Team |
| `CROSS_DOMAIN_REF` | `.claude/references/team-expert/cross-domain/` | References liên ngành |
| `AGENT_COORDINATION` | `.claude/references/agent-coordination.md` | Agent coordination SSOT |
| `RULES` | `.claude/rules/` | Project rules |

---

## 6. Mapping: Agent Role → Input/Output

### Team Expert (Business Analysis Agents)

| Hành động | Path |
|-----------|------|
| Đọc context dự án | `PHASE0`, `PHASE1`, hoặc `KNOWLEDGE_BASE` |
| Đọc domain references | `TEAM_EXPERT_REF/[domain]/` |
| Đọc templates | `DOC_FRAMEWORK_DEPTS/[dept-name]/` |
| Ghi output | `PHASE1_DEPTS/[dept-name]/` |
| Cập nhật registry | `REQ_REGISTRY` |

### Team Tech (Technical Development Agents)

| Hành động | Path |
|-----------|------|
| Đọc requirements | `PHASE1`, `PHASE2` |
| Đọc registry | `REQ_REGISTRY` |
| Đọc architecture | `PHASE3` |
| Đọc engineering references | `TEAM_ENGINEERING_REF` |
| Ghi technical design | `PHASE3`, `PHASE3_SPECS` |
| Ghi deployment docs | `PHASE6` |

### Team Design (UX/UI Design Agents)

| Hành động | Path |
|-----------|------|
| Đọc requirements | `PHASE1`, `PHASE2` |
| Đọc architecture | `PHASE3` |
| Đọc design references | `TEAM_DESIGN_REF` |
| Ghi UX/UI design | `PHASE4` |

### Team Testing (Quality Assurance Agents)

| Hành động | Path |
|-----------|------|
| Đọc requirements | `PHASE1`, `PHASE2` |
| Đọc architecture | `PHASE3` |
| Đọc code | Source code directories |
| Đọc testing references | `TEAM_TESTING_REF` |
| Ghi test plans/reports | `PHASE5`, `PHASE6` |

### Cross-Domain (Liên ngành)

| Hành động | Path |
|-----------|------|
| Đọc cross-domain references | `CROSS_DOMAIN_REF` |
| Dùng khi phân tích liên quan nhiều domain | Sales↔Marketing, Finance↔Operations, Data↔All |

---

## 7. Quy tắc sử dụng

```
1. Agent KHÔNG hardcode paths — đọc file này hoặc nhận path từ skill
2. Skill truyền paths cụ thể khi spawn agent qua prompt
3. Nếu skill không truyền path → agent đọc file này làm fallback
4. Khi cấu trúc thay đổi → CHỈ SỬA FILE NÀY + skill prompts
```
