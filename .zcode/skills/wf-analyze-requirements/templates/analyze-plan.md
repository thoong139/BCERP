# Requirements Analysis Plan

> **Mục đích:** Kế hoạch chi tiết để phân tích requirements với BA + Domain Experts.
>
> **Ai viết:** AI tự động generate khi chạy `/wf-analyze-requirements`
>
> **Khi viết:** Phase 2 của analyze-requirements skill
>
> **Cập nhật:** Tự động cập nhật sau mỗi phase hoàn thành

---

## Meta Information

| Mục | Giá trị |
|-----|---------|
| **Analyze ID** | `[ANALYZE-YYYYMMDD-NNN]` |
| **Project** | `[PROJECT_NAME]` |
| **Scope** | `all | business | functional | [module-name]` |
| **Created** | `[YYYY-MM-DD HH:mm:ss]` |
| **Last Updated** | `[YYYY-MM-DD HH:mm:ss]` |
| **Status** | `🔄 In Progress` / `✅ Completed` / `❌ Error` |
| **Session** | `[N]` |

---

## 1. Project Context

| Mục | Giá trị |
|-----|---------|
| **Project Name** | `[PROJECT_NAME]` |
| **Domain** | `[ERP / CRM / E-commerce / HR / Finance / Logistics / ...]` |
| **Source** | `new | onboard` |
| **Has Existing Docs** | `[YES/NO]` |
| **Registry Status** | `[VALID / INVALID / EMPTY]` |

---

## 2. Scope Definition

### 2.1 Requested Scope

| Scope | Description | Active |
|-------|-------------|--------|
| **all** | Phân tích toàn bộ (business + functional) | `[YES/NO]` |
| **business** | Chỉ business requirements | `[YES/NO]` |
| **functional** | Chỉ functional specs | `[YES/NO]` |
| **[module-name]** | Focus vào module cụ thể | `[YES/NO]` |

**Applied Scope:** `[SCOPE_NAME]`

### 2.2 Scope Boundaries

**In Scope:**
- `[Item 1]`
- `[Item 2]`
- `[Item 3]`

**Out of Scope:**
- `[Item 1]`
- `[Item 2]`

---

## 3. Domain Experts Plan

### 3.1 Experts Selection

| # | Expert | Department | Focus Area | Spawn Mode | Status |
|---|--------|------------|------------|------------|--------|
| 1 | `business-analyst` | All | Stakeholders, User Needs | Sequential (FIRST) | ⬜ |
| 2 | `[domain-expert-1]` | `[DEPT_1]` | `[FOCUS_1]` | Parallel | ⬜ |
| 3 | `[domain-expert-2]` | `[DEPT_2]` | `[FOCUS_2]` | Parallel | ⬜ |
| 4 | `[domain-expert-3]` | `[DEPT_3]` | `[FOCUS_3]` | Parallel | ⬜ |
| ... | ... | ... | ... | ... | ... |

### 3.2 Expert Batching Strategy

**Batch 1 (Sequential):**
- `business-analyst` — LUÔN chạy đầu tiên

**Batch 2 (Parallel — Checkpoint after each):**
- `[expert-1]`, `[expert-2]`, `[expert-3]`, ...

**Context Budget per Expert:** ~10,000 tokens

### 3.3 Expert Context Template

```markdown
Bạn là [expert-name]. Phân tích requirements cho [module-name].

## Context
- Project: [project-name]
- Domain: [domain]
- Department: [department]
- BA Output: [link to BA output]

## Task
Thêm Phần B vào file: .mc-data/docs/phase1-business/departments/[dept]/[dept].md

## Output Structure
# [Department] Workflow
## Quy trình nghiệp vụ
## Stakeholders
## Pain points
## Requirements (REQ-ID)

## Quality Requirements
- File PHẢI non-empty
- PHẢI có REQ-IDs theo format REQ-[DEPT]-[NNN]
- KHÔNG có placeholders (TODO, TBD, [placeholder])
```

---

## 4. Existing Documentation (If Applicable)

### 4.1 Documentation Found

| # | Document | Location | Type | Action |
|---|----------|----------|------|--------|
| 1 | `[README.md]` | `/README.md` | Project Overview | `[MERGE / SKIP]` |
| 2 | `[API Docs]` | `/docs/api/` | API Documentation | `[TRANSFORM / SKIP]` |
| 3 | `[SRS]` | `/requirements/` | Requirements | `[EXTRACT / SKIP]` |
| ... | ... | ... | ... | ... |

### 4.2 Documentation Mapping

| Existing Document | DEVKIT Target | Action | Status |
|-------------------|---------------|--------|--------|
| `/requirements/*.docx` | `departments/[dept]/[dept].md` | EXTRACT | ⬜ |
| `/docs/api/` | `departments/[dept]/[dept].md` | EXTRACT | ⬜ |
| `/README.md` | `phase1-business/P1-01-project-overview.md` | MERGE | ⬜ |

---

## 5. Phase Plan

### 5.1 Session Breakdown

```
SESSION 1: Discovery & Planning
├── Phase 0: Context Loading ⏳ ~2 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│   Checkpoint: YES
│
├── Phase 1: Registry Validation & Scope ⏳ ~3 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│
└── Phase 2: Expert Planning ⏳ ~5 min
    Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
    Checkpoint: YES

SESSION 2+: Expert Analysis (Resumable)
├── Phase 3: Business Analyst ⏳ ~5-10 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│   Checkpoint: YES (after completion)
│
├── Phase 4: Domain Experts (Parallel) ⏳ ~10-20 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│   ├── Expert 1: ⬜ / 🔄 / ✅
│   ├── Expert 2: ⬜ / 🔄 / ✅
│   ├── Expert 3: ⬜ / 🔄 / ✅
│   └── Checkpoint: YES (after EACH expert)
│
└── Phase 5: Existing Docs Integration (Conditional) ⏳ ~5 min
    Status: ⬜ Pending / 🔄 In Progress / ✅ Completed / ⏭️ Skipped
    Condition: Only runs if existing docs found

SESSION N: Consolidation
├── Phase 6: Consolidate Requirements ⏳ ~5 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│   Checkpoint: YES
│
├── Phase 6b: Business Workflow (Cross-Departmental) ⏳ ~5 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│   Output: P1-02-business-workflow.md
│
├── Phase 6c: Stakeholder Review ⏳ ~5-10 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│   Output: stakeholder-review.md
│   Checkpoint: YES (after completion)
│
├── Phase 6d: Conflict Resolution & Document Reconciliation ⏳ ~5-10 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│   Tracks: AUTO-RESOLVE | EXPERT-RESOLVE | DEFER-TO-DESIGN
│   Checkpoint: YES (after completion)
│
├── Phase 8: Update Registry (Chunked — NO AGENT) ⏳ ~5 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│   Note: Main conversation trực tiếp, KHÔNG delegate cho agent
│   Checkpoint: YES
│
└── Phase 8b: Final Cross-Validation (Auto-Correction Loop) ⏳ ~5 min
    Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
    Auto-fix: Max 3 iterations, 8 validation checks
    Final: YES
```

### 5.2 Estimated Time

| Scenario | Sessions | Total Time |
|----------|----------|------------|
| Small (< 3 experts) | 1 | ~15-20 min |
| Medium (3-5 experts) | 1-2 | ~25-35 min |
| Large (> 5 experts) | 2-3 | ~40-60 min |

---

## 6. Expected Outputs

### 6.1 Department Documents

| File | Phase | Department | REQ-IDs | Status |
|------|-------|------------|---------|--------|
| `departments/[dept]/[dept].md` (Phần A) | 3 | All | N/A | ⬜ |
| `departments/[dept1]/[dept1].md` (Phần B) | 4 | `[DEPT1]` | `[COUNT]` | ⬜ |
| `departments/[dept2]/[dept2].md` (Phần B) | 4 | `[DEPT2]` | `[COUNT]` | ⬜ |
| ... | ... | ... | ... | ... |

### 6.2 Registry Updates

| Section | Action | Count |
|---------|--------|-------|
| `systems[]` | ADD/UPDATE | `[COUNT]` |
| `modules[]` | ADD/UPDATE | `[COUNT]` |
| `departments[]` | ADD/UPDATE | `[COUNT]` |
| `requirements[]` | ADD | `[COUNT]` |
| `interface_type` | SET | `[TYPE]` |

### 6.4 Status Files

| File | Description |
|------|-------------|
| `.mc-data/work/wf-analyze-requirements/analyze-status.json` | Runtime status tracking |
| `.mc-data/work/wf-analyze-requirements/checkpoint.json` | Checkpoint for resume |
| `.mc-data/work/wf-analyze-requirements/department-digests.json` | Digest ngắn theo phòng ban để giảm reread |
| `.mc-data/work/wf-analyze-requirements/phase1-handoff.json` | Handoff chuẩn cho `/wf-define-features` |

---

## 7. Checkpoint Strategy

### 7.1 Checkpoint Triggers

| Trigger | Threshold | Action |
|---------|-----------|--------|
| Context Warning | 65% | Log warning, continue |
| Context Checkpoint | 80% | Save checkpoint, suggest resume |
| Context Critical | 90% | Force checkpoint, stop gracefully |
| Phase Complete | Any | Save checkpoint with phase data |
| Expert Complete | Phase 4 only | Save checkpoint with expert data |

### 7.2 Checkpoint Data

```json
{
  "checkpoint_id": "CHK-ANALYZE-[ID]",
  "timestamp": "[TIMESTAMP]",
  "session_number": "[N]",
  "context_used_pct": "[PCT]",
  "current_phase": "[PHASE]",
  "current_expert": "[EXPERT_NAME]",
  "experts_completed": ["expert1", "expert2"],
  "experts_pending": ["expert3", "expert4"],
  "next_action": "[ACTION]",
  "trigger_reason": "[REASON]"
}
```

### 7.3 Resume Commands

```bash
# Check current status
/wf-analyze-requirements --status

# Resume from checkpoint
/wf-analyze-requirements --resume
```

---

## 8. Conflict Resolution Plan

### 8.1 Conflict Types

| Conflict Type | Resolution | Owner |
|---------------|------------|-------|
| **Priority conflict** | BA decides based on business impact | BA |
| **Scope conflict** | Present options to user, user decides | User |
| **Dependency conflict** | Defer to /wf-design for technical review | Architect |
| **Data ownership** | BA proposes, Legal/Compliance validates | BA + Legal |

### 8.2 Conflict Log

| # | Conflict | Experts Involved | Resolution | Status |
|---|----------|------------------|------------|--------|
| 1 | `[CONFLICT_1]` | `[EXPERT_1]`, `[EXPERT_2]` | `[RESOLUTION]` | ⬜ |
| ... | ... | ... | ... | ... |

---

## 9. Notes

*[Ghi chú thêm về analysis, các điểm cần lưu ý, dependencies, v.v.]*

---

*This plan was auto-generated by DEVKIT `/wf-analyze-requirements` skill.*
