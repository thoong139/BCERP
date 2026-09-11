# Implementation Plan

> **Mục đích:** Kế hoạch chi tiết để triển khai code cho một feature theo TDD approach.
>
> **Ai viết:** AI tự động generate khi chạy `/wf-implement-feature`
>
> **Khi viết:** Phase 2 (Planning) của implement-feature skill
>
> **Cập nhật:** Tự động cập nhật sau mỗi batch/phase hoàn thành

---

## Meta Information

| Mục | Giá trị |
|-----|---------|
| **Implementation ID** | `[IMPL-YYYYMMDD-NNN]` |
| **Feature** | `[Feature Name]` |
| **REQ-ID** | `[REQ-XXX-NNN]` |
| **Module** | `[Module Name]` |
| **System** | `[System Name]` |
| **Scenario** | `NEW / EXTEND / MODIFY` |
| **Complexity** | `Simple / Medium / Complex` |
| **Created** | `[YYYY-MM-DD HH:mm:ss]` |
| **Last Updated** | `[YYYY-MM-DD HH:mm:ss]` |
| **Status** | `🔄 In Progress` / `✅ Completed` / `❌ Error` |
| **Session** | `[N]` |

---

## 1. Feature Context

### 1.1 Source Documents

| Input | Location | Status |
|-------|----------|--------|
| req-registry.json | `.mc-data/docs/_meta/req-registry.json` | `[FOUND / NOT_FOUND]` |
| Feature Design | `.mc-data/docs/phase2-features/features/[sys]/[mod]/[feature].md` | `[FOUND / NOT_FOUND]` |
| Implementation Plan | `.mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feature]-impl.md (Phần A)` (tạo bởi `/wf-design` Phase 4) | `[FOUND / NOT_FOUND]` |
| Task Breakdown | `.mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feature]-impl.md (Phần B)` (tạo bởi `/wf-design` Phase 4) | `[FOUND / NOT_FOUND]` |
| Architecture | `.mc-data/docs/phase3-architecture/P3-01-architecture.md` | `[FOUND / NOT_FOUND]` |
| Database Design | `.mc-data/docs/phase3-architecture/technical-specs/database-design.md` | `[FOUND / NOT_FOUND]` |
| API Contract | `.mc-data/docs/phase3-architecture/technical-specs/api-contract.md` | `[FOUND / NOT_FOUND]` |

### 1.2 Requirements Covered

| REQ-ID | Description | Priority |
|--------|-------------|----------|
| `[REQ-XXX-001]` | `[Description]` | `[HIGH/MEDIUM/LOW]` |
| `[REQ-XXX-002]` | `[Description]` | `[HIGH/MEDIUM/LOW]` |
| ... | ... | ... |

---

## 2. Existing Code Analysis (EXTEND/MODIFY only)

> Bỏ qua section này nếu scenario = NEW

### 2.1 Existing Patterns

| Pattern | Value | Source |
|---------|-------|--------|
| Naming convention | `[PascalCase / camelCase / ...]` | `[Reference file]` |
| File structure | `[src/modules/[mod]/...]` | `[Reference file]` |
| Test framework | `[Jest / Vitest / ...]` | `[Reference file]` |
| Code style | `[2 spaces / tabs / ...]` | `[Reference file]` |

### 2.2 Impact Analysis (MODIFY only)

| Affected File | Impact Type | Risk | Action |
|---------------|-------------|------|--------|
| `[path/to/file1.ts]` | `[Modified]` | `[LOW/MEDIUM/HIGH]` | `[Description]` |
| `[path/to/file2.ts]` | `[Dependency]` | `[LOW/MEDIUM/HIGH]` | `[Description]` |

---

## 3. Task Breakdown

### 3.1 Tasks

| # | Task ID | Task Name | Batch | File | Status |
|---|---------|-----------|-------|------|--------|
| 1 | T001 | `[Task Name]` | 1 | `[path/to/file.ts]` | ⬜ |
| 2 | T002 | `[Task Name]` | 1 | `[path/to/file.ts]` | ⬜ |
| 3 | T003 | `[Task Name]` | 2 | `[path/to/file.ts]` | ⬜ |
| 4 | T004 | `[Task Name]` | 2 | `[path/to/file.ts]` | ⬜ |
| 5 | T005 | `[Task Name]` | 3 | `[path/to/file.ts]` | ⬜ |
| 6 | T006 | `[Task Name]` | 3 | `[path/to/file.ts]` | ⬜ |

### 3.2 File Mapping

| File Path | Action | Task IDs | REQ-IDs |
|-----------|--------|----------|---------|
| `src/modules/[mod]/entities/[Entity].ts` | CREATE | T001 | REQ-XXX-001 |
| `src/modules/[mod]/repositories/[Repo].ts` | CREATE | T002 | REQ-XXX-001 |
| `src/modules/[mod]/services/[Service].ts` | CREATE | T003, T004 | REQ-XXX-001, REQ-XXX-002 |
| `src/modules/[mod]/controllers/[Controller].ts` | CREATE | T005, T006 | REQ-XXX-001, REQ-XXX-002 |
| `tests/modules/[mod]/[Entity].test.ts` | CREATE | T001 | REQ-XXX-001 |
| `tests/modules/[mod]/[Service].test.ts` | CREATE | T003 | REQ-XXX-001 |
| `tests/modules/[mod]/[Controller].test.ts` | CREATE | T005 | REQ-XXX-001 |

---

## 4. Batch Plan

### 4.1 Batch Structure (ADAPTIVE — v3.3+ Finding #12)

> Default backend CRUD batch structure đã được thay bằng adaptive theo feature type.
> Skill code (Phase 2) chọn template variant phù hợp:

| Feature type | Detection | Default batch structure |
|--------------|-----------|--------------------------|
| Backend CRUD | Has `*Controller.cs` + `*Repository.ts/cs` + Entity | B1: Entity+Repository / B2: Service / B3: Controller / B4: Tests |
| Frontend page | Next.js/Vue/Angular page + components | B1: Types/Schemas / B2: Page+Components / B3: Hooks/State / B4: Tests |
| Auth flow | Login/register/2FA/password files | B1: Types+Schemas / B2: Server Component / B3: Form+Hooks / B4: Cookie/auth-server / B5: E2E tests |
| API integration | External API client + mappers | B1: Adapter/Client / B2: Mappers / B3: Service / B4: Tests |
| Mobile screen | iOS/Android/RN/Flutter screen | B1: Native bridges / B2: Screen / B3: Components / B4: Tests |
| Annotation fix only | Only REQ-ID/FEAT-ID changes | B1: All files (parallel-per-file) |
| Refactor | Existing code restructure | B1: Extract helpers / B2: Update callers / B3: Verify tests |

> Phase 2 step 2.0 PHẢI populate batch structure dựa trên feature type — KHÔNG hardcode.
> Nếu feature type không match → fall back to manual breakdown.

### 4.1.x Session Breakdown (ví dụ — backend CRUD pattern)

```
SESSION 1: Context & Implementation
├── Phase 0: Existing Code Analysis (EXTEND/MODIFY) ⏳ ~5 min
│   Status: ⬜ Pending / ⏭️ Skipped (NEW)
│
├── Phase 1: Feature Context ⏳ ~3 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│
├── Phase 2: Planning ⏳ ~5 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│   └── Output: impl-plan.md (this file)
│
├── Phase 3: TDD Implementation ⏳ ~20-40 min
│   ├── Batch 1: Entity + Repository ⏳ ~10 min
│   │   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│   │   ├── RED: Write failing tests
│   │   ├── GREEN: Write minimal code
│   │   └── REFACTOR: Clean up
│   │   └── CHECKPOINT ✓
│   │
│   ├── Batch 2: Service ⏳ ~10 min
│   │   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│   │   ├── RED → GREEN → REFACTOR
│   │   └── CHECKPOINT ✓
│   │
│   └── Batch 3: Controller + API ⏳ ~10 min
│       Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│       ├── RED → GREEN → REFACTOR
│       └── CHECKPOINT ✓
│
SESSION 2+ (nếu context cạn):
├── Phase 4: Parallel Reviews ⏳ ~10 min
│   ├── Code Review (qa-lead) — Parallel
│   ├── Security Review (security) — Parallel
│   └── CHECKPOINT ✓
│
├── Phase 5: Issue Resolution ⏳ ~5-10 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│
├── Phase 5a: Cross-Validation (Auto-Correction Loop) ⏳ ~5 min
│   Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
│   └── Max 3 iterations auto-fix
│
└── Phase 6: Update Status & Finalization ⏳ ~5 min
    Status: ⬜ Pending / 🔄 In Progress / ✅ Completed
    └── Output: impl-report.md
```

### 4.2 Batch Details

| Batch | Name | Tasks | Files | Estimated Time | Dependencies |
|-------|------|-------|-------|----------------|--------------|
| 1 | Entity + Repository | T001, T002 | 3 (src + test) | ~10 min | None |
| 2 | Service | T003, T004 | 2 (src + test) | ~10 min | Batch 1 |
| 3 | Controller + API | T005, T006 | 2 (src + test) | ~10 min | Batch 2 |

### 4.3 Execution Strategy

| Điều kiện | Chế độ |
|-----------|--------|
| Phase 4: Code Review + Security Review | **PARALLEL** |
| Nhiều files trong cùng batch (độc lập) | **PARALLEL** |
| Batches có dependency | **SEQUENTIAL** |

---

## 5. TDD Strategy

### 5.1 Test Plan

| Batch | Test File | Test Cases | Coverage Target |
|-------|-----------|------------|-----------------|
| 1 | `tests/[Entity].test.ts` | `[List cases]` | ≥80% |
| 2 | `tests/[Service].test.ts` | `[List cases]` | ≥80% |
| 3 | `tests/[Controller].test.ts` | `[List cases]` | ≥80% |

### 5.2 TDD Cycle per Batch

```
RED:     Viết test → Chạy → PHẢI FAIL
GREEN:   Viết minimal code → Chạy → PHẢI PASS
REFACTOR: Clean up → Chạy lại → VẪN PASS
```

---

## 6. Review Plan

### 6.1 Code Review (qa-lead)

| Check | Focus Area |
|-------|------------|
| ✅ Code quality | Naming, structure, duplication |
| ✅ REQ-ID traceability | Mỗi file có REQ-ID comment |
| ✅ Test coverage | ≥80% |
| ✅ Error handling | Consistent patterns |

### 6.2 Security Review (security)

| Check | Focus Area |
|-------|------------|
| ✅ Input validation | User inputs sanitized |
| ✅ Authentication | Auth middleware applied |
| ✅ SQL injection | Parameterized queries |
| ✅ XSS prevention | Output encoding |
| ✅ Secrets | No hardcoded credentials |

---

## 7. Checkpoint Strategy

| Trigger | Threshold | Action |
|---------|-----------|--------|
| Context Warning | 65% | Log warning, tiếp tục |
| Context Checkpoint | 80% | Save checkpoint, suggest resume |
| Context Critical | 90% | Force checkpoint, stop gracefully |
| Batch Complete | Any | Save checkpoint with batch data |

---

## 8. Expected Outputs

| File | Phase | Description | Status |
|------|-------|-------------|--------|
| `.mc-data/work/wf-implement-feature/$SYSTEM_SLUG/$FEATURE_SLUG/impl-plan.md` | 2 | This file | ⬜ |
| `.mc-data/work/wf-implement-feature/$SYSTEM_SLUG/$FEATURE_SLUG/impl-status.json` | 1 | Runtime status tracking | ⬜ |
| `.mc-data/work/wf-implement-feature/$SYSTEM_SLUG/$FEATURE_SLUG/checkpoint.json` | 3+ | Checkpoint for resume | ⬜ |
| `.mc-data/work/wf-implement-feature/$SYSTEM_SLUG/$FEATURE_SLUG/existing-patterns.json` | 0 | Pattern analysis (EXTEND/MODIFY) | ⬜/⏭️ |
| `src/modules/[mod]/**/*.ts` | 3 | Source code | ⬜ |
| `tests/modules/[mod]/**/*.test.ts` | 3 | Test files | ⬜ |
| `.mc-data/work/wf-implement-feature/$SYSTEM_SLUG/$FEATURE_SLUG/impl-report.md` | 6 | Final report | ⬜ |

---

## 9. Notes

*[Ghi chú thêm về implementation, các điểm cần lưu ý, technical decisions, v.v.]*

---

*This plan was auto-generated by DEVKIT `/wf-implement-feature` skill.*
