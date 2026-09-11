<!-- From shared-protocols.md lines 464-549 (§7) -->
# Protocol 7 — Parallel Execution Protocol (BẮT BUỘC)

> Tối ưu tốc độ bằng cách song song hóa các công việc độc lập.
> Mỗi skill PHẢI phân loại tasks thành PARALLEL hoặc SEQUENTIAL.

## 7.1 Nguyên tắc phân loại

```
PARALLEL khi:
- Tasks KHÔNG chia sẻ output files (không ghi cùng file)
- Tasks KHÔNG phụ thuộc kết quả của nhau
- Tasks thuộc các modules/systems khác nhau

SEQUENTIAL khi:
- Task B cần output của Task A (data dependency)
- Tasks ghi vào CÙNG file (write conflict)
- Task cần kết quả validate trước khi tiếp
```

## 7.2 Mô hình song song hóa theo cấp độ

| Cấp độ | Mô tả | Ví dụ |
|--------|-------|-------|
| **L1: Agent Parallel** | Spawn nhiều agents cùng lúc (run_in_background: true) | 5 domain experts phân tích 5 departments |
| **L2: Document Parallel** | Tạo nhiều docs độc lập song song | API contract + DB schema + Infra spec |
| **L3: Feature Parallel** | Implement nhiều features song song (khác module) | Login form + Product list + Dashboard |
| **L4: Review Parallel** | Review nhiều khía cạnh song song | code-reviewer + security + qa-lead |

## 7.3 Parallel Execution Pattern (cho skills)

```
TRƯỚC KHI THỰC THI PHASE:
1. Liệt kê TẤT CẢ tasks trong phase
2. Phân tích dependency graph giữa tasks
3. Nhóm tasks KHÔNG phụ thuộc nhau thành parallel_groups
4. Thực thi:

FOR each parallel_group IN execution_order:
  IF parallel_group.size == 1:
    → Run SEQUENTIAL (single task)
  ELSE:
    → Spawn ALL tasks trong group với run_in_background: true
    → Wait ALL complete
    → Validate ALL outputs
  ENDIF

  // Quality gate giữa groups
  run_post_group_checks()
```

## 7.4 Bảng áp dụng theo Skill

| Skill | Có thể song song | Đang song song? | Cần cải thiện |
|-------|------------------|-----------------|---------------|
| wf-brainstorm | Domain experts (L1), Docs P0-01/P0-02 (L2) | ✅ Đã có | — |
| wf-analyze-requirements | Domain experts per dept (L1) | ✅ Batch 5 | BA Phần A nên song song per dept thay vì tuần tự ALL |
| wf-define-features | Feature specs khác module (L2), Review (L4) | ⚠️ Một phần | Feature specs cùng system nên PARALLEL nếu khác module |
| wf-design | API + DB + Infra (L2), Review (L4) | ✅ Đã có | — |
| wf-design-ux | Navigation per system (L2), Architect parallel (L1) | ⚠️ Một phần | Screen groups khác system nên PARALLEL |
| wf-plan-modules | Feature file reads (L2) | ⚠️ Một phần | Phase 2 reads nên batch PARALLEL |
| wf-implement-feature | Files trong batch (L3), Review (L4) | ✅ Đã có | Thêm L3: features khác module song song |
| wf-preflight | Registry + Docs + Code + Quality (L2) | ✅ 2 cặp parallel | — |
| wf-fix-bugs | Orchestrator — Lane Dispatch (QD1-QD8 parallel) → wf-fix-triage → wf-fix-execute | ✅ Đã có | — |
| wf-fix-execute *(spawned)* | Developer + Security (L1), Batch files (L3) | ⚠️ Một phần | Batch 2 HIGH issues nên PARALLEL giữa test failures + security |
| wf-verify-sync | Collect REQ-IDs + Scan code (L2) | ✅ Đã có | — |
| wf-prepare-deployment | User Guide + Deployment Guide (L2) | ❌ Tuần tự | Phase 2 (Mục 1-8) + Phase 3 (User Guide) SONG SONG |
| wf-legacy-scan | — | ✅ Deterministic | Bash scripts only (Stage 0-1) |
| wf-legacy-classify | Stage 2 classify per batch (L1) | ✅ Sequential | 1 agent/batch |
| wf-legacy-extract | Stage 3 extract per module (L1+L2) | ✅ Parallel | Max 3 agents |
| wf-brainstorm (legacy flow) | Phase 0 docs (L2) | ✅ Đã có | Shared skill, legacy mode |
| wf-analyze-requirements (legacy flow) | Domain experts per dept (L1) | ✅ Batch 5 | Shared skill, legacy mode |
| wf-define-features (legacy flow) | Feature specs khác module (L2) | ✅ Đã có | Shared skill, legacy mode |
| wf-design (legacy flow — gap analysis) | Architect + QA-lead (L1) | ✅ 2 agents | Shared skill, legacy mode |

## 7.5 Max Concurrency Control

```
QUY TẮC:
- Tối đa 5 background agents đồng thời (tránh overwhelm context)
- Nếu cần > 5 agents: chia thành batches, mỗi batch <= 5
- Sau mỗi batch: validate outputs TRƯỚC KHI chạy batch tiếp
- Agent lớn (developer, architect): tối đa 3 đồng thời
- Agent nhẹ (reviewer, auditor): tối đa 5 đồng thời
```
