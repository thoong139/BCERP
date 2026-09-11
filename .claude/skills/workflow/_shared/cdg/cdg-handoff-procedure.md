# CDG Handoff Procedure

> Dùng bởi SKILL.md reference khi cần trigger Critical Decision Gate.

## 1. Khi Nào Trigger CDG

7 CDG points theo CORE-027:

| CDG Point | Trigger | Context |
|-----------|---------|---------|
| CDG-1 | Workload override (block zone) | User chọn tiếp tục dù workload vượt threshold |
| CDG-2 | Profile downgrade cho production | User chọn quick cho production-bound project |
| CDG-3 | Skip phase trong workflow | User muốn skip phase bắt buộc |
| CDG-4 | DEPRECATE module | User muốn loại module khỏi scope |
| CDG-5 | Override safety floor | User muốn bypass safety floor rule |
| CDG-6 | Registry write outside owned fields | Skill cố ghi field không thuộc quyền |
| CDG-7 | Force-complete impl_status | User muốn mark done mà chưa verify |

## 2. AskUserQuestion Format

```python
AskUserQuestion(
    questions=[{
        "question": f"⚠️ Critical Decision — {context}. Hành động này không thể undo. Tiếp tục?",
        "header": "CDG",
        "options": [
            {"label": "Xác nhận", "description": "Tiếp tục với hành động — ghi CDG token"},
            {"label": "Từ chối", "description": "Dừng và chọn phương án khác"},
        ],
        "multiSelect": False,
    }]
)
```

## 3. Accept/Reject Handling

- **Accept**: Ghi CDG token với decision="accept", tiếp tục thực thi
- **Reject**: Ghi CDG token với decision="reject", dừng hành động, đề xuất alternative

## 4. Anti-Loop Guard

Nếu user reject cùng loại CDG ≥ 2 lần:
- Không hỏi lại → escalate (dừng workflow, báo user cần review scope)
- Anti-loop check: `check_anti_loop(cdg_id, tokens, max_rejects=2)`
- Returns: "ask" (còn room) hoặc "escalate" (cần dừng)
