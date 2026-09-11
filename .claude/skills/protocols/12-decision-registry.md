<!-- From shared-protocols.md lines 943-1003 (§12 — scope: wf-implement-feature) -->
# Protocol 12 — Decision Registry Protocol (BẮT BUỘC — wf-implement-feature)

> Đảm bảo các quyết định kiến trúc được persist và enforce across sessions.
> Ngăn Decision Drift — inconsistency giữa các implement sessions.

## 12.1 LOAD (đầu mỗi session — Phase 0.5)

```
IF .mc-data/work/wf-implement-feature/decision-registry.json EXISTS:
  READ toàn bộ decisions[]
  BUILD constraint_list = decisions.map(d => `${d.id}: ${d.rule}`)
  INJECT vào Developer Agent system context:
    "Quy tắc bắt buộc (từ Decision Registry): [constraint_list]"

IF NOT EXISTS:
  CREATE từ template `templates/decision-registry.json` với feature_slug đúng
  constraint_list = []  // fresh start, không có decisions cũ
```

## 12.2 WRITE (khi phát hiện decision mới — Phase 3.5)

```
READ decision-registry.json (fresh read — KHÔNG dùng cache từ đầu session)

// Conflict check trước khi append
FOR each existing_decision IN decisions:
  IF new_decision contradicts existing_decision:
    LOG: "Conflict: [new_rule] vs [existing_id]: [existing_rule]"
    ASK USER quyết định nào ưu tiên
    IF user không respond → giữ nguyên existing, skip new → STOP write

APPEND decision mới:
  {
    "id": "D" + (decisions.length + 1 padded to 3 digits),
    "category": "data" | "api" | "naming" | "security" | "infra",
    "rule": "[mô tả quyết định ngắn gọn, rõ ràng]",
    "reason": "[lý do — constraint, pattern, hoặc requirement]",
    "applies_to": ["*"] hoặc ["module-name"],
    "exceptions": [],
    "session_created": $SESSION_NUMBER,
    "created_at": "[ISO timestamp]"
  }

WRITE atomic
LOG: "[D-REG] D[NNN] ghi: [rule] — vì [reason]"
```

## 12.3 VERIFY (Phase 5a Cross-Validation)

```
FOR each implemented file IN batch:
  FOR each decision IN decisions WHERE file matches applies_to AND NOT in exceptions:
    CHECK: file content respects decision.rule
    IF FAIL:
      LOG: "File [path] vi phạm decision [id]: [rule]"
      AUTO-FIX nếu rõ ràng (vd: thêm soft_delete column)
      ESCALATE nếu không fix được (logic thay đổi lớn)
```

**Template:** `.claude/skills/workflow/wf-implement-feature/templates/decision-registry.json`
