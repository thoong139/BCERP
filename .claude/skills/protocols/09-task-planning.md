<!-- From shared-protocols.md lines 620-794 (§9, EXCLUDING Plan template extracted to templates/execution-plan.template.md) -->
# Protocol 9 — Task Planning & Token Budget Protocol (BẮT BUỘC)

> Lập kế hoạch TRƯỚC khi thực hiện công việc lớn.
> Quản lý token budget để đảm bảo chất lượng output không suy giảm.

## 9.1 Khi nào cần Plan

```
BẮT BUỘC lập Plan khi:
- Task có >= 5 output files
- Task cần spawn >= 3 agents
- Task ước lượng > 50% context window
- Task có cross-dependencies phức tạp (>= 3 dependencies)

KHÔNG CẦN Plan khi:
- Task đơn giản (1-2 files, 1 agent)
- Task đã có plan từ phase trước (vd: impl-plan.md)
- Resume từ checkpoint (plan đã có)
```

## 9.2 Plan Structure

> **Standalone template:** `.claude/skills/templates/execution-plan.template.md`

```markdown
### Execution Plan — [Skill Name] [Phase N]

#### Scope
- Input: [danh sách files/data cần đọc]
- Output: [danh sách files sẽ tạo/update]
- Agents: [danh sách agents cần spawn]

#### Execution Order
| Step | Tasks | Mode | Dependencies | Est. Token |
|------|-------|------|-------------|------------|
| 1 | Read registry + docs | SEQUENTIAL | — | ~2K |
| 2a | Create API spec | PARALLEL | Step 1 | ~5K |
| 2b | Create DB schema | PARALLEL | Step 1 | ~5K |
| 2c | Create Infra spec | PARALLEL | Step 1 | ~3K |
| 3 | Integration spec | SEQUENTIAL | 2a, 2b | ~4K |
| 4 | Validate all outputs | SEQUENTIAL | 3 | ~2K |

#### Token Budget
- Estimated total: ~21K tokens
- Context limit: 200K tokens
- Safety margin: 20%
- Available for execution: 160K tokens
- Verdict: ✅ Đủ budget

#### Checkpoint Strategy
- Checkpoint after: Step 2 (all parallel done), Step 4 (validation)
- Resume point: Step number + completed files
```

## 9.3 Token Budget Estimation

```
Quy tắc ước lượng (rough):
- Đọc 1 file: ~1-3K tokens (tùy size)
- Agent spawn + output: ~5-15K tokens per agent
- Tạo 1 document: ~3-8K tokens
- Registry update: ~2K tokens
- Validation loop: ~3-5K tokens per iteration

CÔNG THỨC:
estimated_tokens = Σ(read_files * 2K) + Σ(agents * 10K) + Σ(output_files * 5K) + Σ(validations * 4K)

NẾU estimated_tokens > 60% context_limit:
  → BẮT BUỘC chia thành multiple sessions với checkpoint
  → Mỗi session xử lý 1 nhóm tasks (batch)
  → Checkpoint sau mỗi batch

NẾU estimated_tokens > 80% context_limit:
  → CẢNH BÁO user: "Task này có thể cần 2-3 sessions"
  → Đề xuất scope thu hẹp hoặc phân chia
```

## 9.4 Quality Degradation Prevention

```
NGUYÊN TẮC:
- Output quality KHÔNG ĐƯỢC giảm khi context usage tăng
- Khi context >= 65%: Ưu tiên finish current batch → checkpoint
- Khi context >= 80%: KHÔNG spawn thêm agent mới
- Khi context >= 90%: FORCE checkpoint, STOP execution

CƠ CHẾ CHỐNG SUY GIẢM:
1. Agent delegation: Công việc nặng → spawn agent (context riêng)
   - Agent có full context budget riêng
   - Main conversation chỉ nhận output summary
2. Incremental processing: Xử lý từng module/feature, validate xong mới next
3. Checkpoint discipline: Save state sau mỗi milestone, không "cố" finish
4. Explicit re-read: Khi resume, ĐỌC LẠI key files thay vì dùng cached context
```

## 9.5 Bảng áp dụng Plan theo Skill

| Skill | Cần Plan? | Plan tại Phase | Nội dung Plan |
|-------|-----------|---------------|---------------|
| wf-brainstorm | ❌ | — | Nhẹ, interactive |
| wf-analyze-requirements | ✅ | Phase 2 | Expert assignment + dept mapping |
| wf-define-features | ✅ | Phase 1 | Feature → file mapping, batch strategy |
| wf-design | ✅ | Phase 1 | Architecture approach + agent selection |
| wf-design-ux | ✅ | Phase 0 | System batching + context budget |
| wf-plan-modules | ⚠️ Conditional | Phase 1 (Full mode only) | Dependency analysis scope |
| wf-implement-feature | ✅ (đã có) | Phase 2 | impl-plan.md with batches |
| wf-preflight | ❌ | — | Scan-based, predictable |
| wf-fix-bugs | ✅ | Phase 2 | Bug triage + batch strategy (orchestrator — execute chi tiết trong wf-fix-execute) |
| wf-fix-execute *(spawned)* | ✅ (kế thừa từ wf-fix-bugs) | Phase 3 start | Thực thi fix batches theo plan từ orchestrator |
| wf-verify-sync | ❌ | — | Scan-based, predictable |
| wf-prepare-deployment | ✅ | Phase 1 | Doc generation order + agent assignment |
| wf-legacy-scan | ✅ | Stage 0 | Detection + assessment + inventory (Stage 0-1) |
| wf-legacy-classify | ⚠️ Conditional | Start | Batch strategy based on project size |
| wf-legacy-extract | ✅ | Start | Module parallelization + token budget |
| wf-brainstorm (legacy flow) | ❌ | — | Shared skill, lightweight |
| wf-analyze-requirements (legacy flow) | ✅ | Phase 2 | Expert assignment + dept mapping (legacy mode) |
| wf-define-features (legacy flow) | ✅ | Phase 1 | Feature → file mapping (legacy mode) |
| wf-design (legacy flow — gap analysis) | ❌ | — | Single session, predictable |

## 9.6 Proactive Budget Check (wf-implement-feature — BẮT BUỘC trước mỗi batch)

> Predict checkpoint need TRƯỚC khi bắt đầu batch — không đợi đến 80% threshold.

```
PROACTIVE BUDGET CHECK (trước khi bắt đầu mỗi batch trong Phase 3):

1. Ước tính chi phí batch:
   Burnrate defaults (tokens):
     entity_file:     1500 (p90: 2200)
     service_file:    2800 (p90: 4000)
     controller_file: 2000 (p90: 2800)
     test_file:       2200 (p90: 3200)
     migration_file:  1200 (p90: 1800)
     other_file:      1800 (p90: 2500)

   batch_estimate = Σ(files_in_batch × burnrate[file_type])

2. So sánh với remaining budget:
   remaining = max_context - current_usage
   safety_buffer = 0.15  // 15% dự phòng
   available = remaining × (1 - safety_buffer)

3. Quyết định:
   IF batch_estimate > available:
     → CHECKPOINT NGAY (không bắt đầu batch)
     → LOG: "[BUDGET] Batch N est. ~Xk tokens, available ~Yk. CHECKPOINT."
     → Thông báo user dùng --resume để tiếp tục
     → STOP

   ELSE IF batch_estimate > available × 0.8:
     → LOG: "[BUDGET] Batch N est. ~Xk tokens, ~Yk available. WARN: sẽ là batch cuối trong session này."
     → Tiếp tục nhưng không plan thêm batch nào nữa trong session

   ELSE:
     → LOG: "[BUDGET] Batch N est. ~Xk tokens, ~Yk available. PROCEED."
     → Tiếp tục bình thường
```

**Burnrate History** (tích lũy để cải thiện accuracy):

Trước khi tính `batch_estimate` (bước 1), nếu `.mc-data/work/shared-metrics/burnrate-history.json` tồn tại:
```
READ burnrate-history.json
FOR each file_type IN [entity_file, service_file, controller_file, test_file, migration_file, other_file]:
  IF history.by_file_type[file_type].sample_count >= 5:
    burnrate[file_type] = history.by_file_type[file_type].avg  // dùng avg từ history thay defaults
  // ELSE: giữ nguyên defaults bên trên
```

Sau mỗi batch hoàn thành, ghi actual vs estimated vào `.mc-data/work/shared-metrics/burnrate-history.json`:
```json
// Append/update entry:
{ "batch": "N", "file_type": "service_file", "estimated": 2800, "actual": 3200, "date": "YYYY-MM-DD" }
// Recalculate avg, p50, p90 cho file_type đó
```
