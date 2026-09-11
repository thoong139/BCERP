<!-- Standalone template extracted from shared-protocols.md §9.2 (lines 643-670) -->
# Execution Plan Template — Task Planning & Token Budget

> Sử dụng cho Protocol 9.2 (Plan Structure). Khi skill cần lập plan trước khi thực hiện công việc lớn,
> populate template này theo scope cụ thể của phase.

---

## Khi nào dùng template này

BẮT BUỘC lập plan khi:
- Task có >= 5 output files
- Task cần spawn >= 3 agents
- Task ước lượng > 50% context window
- Task có cross-dependencies phức tạp (>= 3 dependencies)

Chi tiết trigger conditions: `.claude/skills/protocols/09-task-planning.md` §9.1

---

## Template

```markdown
## Execution Plan — [Skill Name] [Phase N]

### Scope
- Input: [danh sách files/data cần đọc]
- Output: [danh sách files sẽ tạo/update]
- Agents: [danh sách agents cần spawn]

### Execution Order
| Step | Tasks | Mode | Dependencies | Est. Token |
|------|-------|------|-------------|------------|
| 1 | Read registry + docs | SEQUENTIAL | — | ~2K |
| 2a | Create API spec | PARALLEL | Step 1 | ~5K |
| 2b | Create DB schema | PARALLEL | Step 1 | ~5K |
| 2c | Create Infra spec | PARALLEL | Step 1 | ~3K |
| 3 | Integration spec | SEQUENTIAL | 2a, 2b | ~4K |
| 4 | Validate all outputs | SEQUENTIAL | 3 | ~2K |

### Token Budget
- Estimated total: ~21K tokens
- Context limit: 200K tokens
- Safety margin: 20%
- Available for execution: 160K tokens
- Verdict: ✅ Đủ budget

### Checkpoint Strategy
- Checkpoint after: Step 2 (all parallel done), Step 4 (validation)
- Resume point: Step number + completed files
```

---

## Hướng dẫn populate

**Scope:**
- `Input` — list files/data sẽ đọc, kèm path
- `Output` — list files sẽ tạo/update, kèm path
- `Agents` — list `subagent_type` sẽ spawn (ví dụ: `business-analyst`, `architect`, `developer`)

**Execution Order table:**
- `Mode = SEQUENTIAL` khi task phụ thuộc kết quả task trước
- `Mode = PARALLEL` khi task độc lập, không ghi cùng file
- `Dependencies` — chỉ rõ task IDs cần hoàn thành trước
- `Est. Token` — ước lượng theo Protocol 9.3 token estimation formula

**Token Budget:**
- Tính theo công thức: `Σ(read_files × 2K) + Σ(agents × 10K) + Σ(output_files × 5K) + Σ(validations × 4K)`
- `Verdict`:
  - ✅ Đủ budget — nếu < 60% context limit
  - ⚠️ Vừa đủ — nếu 60-80%, cần chia batches
  - ❌ Vượt budget — nếu > 80%, đề xuất user thu hẹp scope

**Checkpoint Strategy:**
- Save sau mỗi parallel group hoàn thành
- Save sau validation step
- Save trước bất kỳ step nào ước lượng > 10K tokens

---

## Tham chiếu

- Protocol 9.3 — Token Budget Estimation
- Protocol 9.4 — Quality Degradation Prevention
- Protocol 9.6 — Proactive Budget Check (wf-implement-feature)
