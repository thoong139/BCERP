# §15 Agent Prompt Templates

## Lane Agent Prompt (Phase 4)

> **Canonical template:** [`templates/phase4-find-bugs/lane-agent-prompt.md`](../../templates/phase4-find-bugs/lane-agent-prompt.md)
>
> Orchestrator PHẢI dùng pattern **READ → POPULATE (substitute `{{...}}`) → STRIP HTML comment block → CALL Agent tool** theo §10 (CORE-031). KHÔNG được tự viết prompt ad-hoc.
>
> **subagent_type bắt buộc:** `"claude"` cho TẤT CẢ lane agents.
> - Chỉ "claude" type có MCP tools (GitNexus, Serena, Playwright, Context7).
> - Domain agent types (`developer`, `qa-lead`, `frontend-developer`, ...) bị giới hạn Read/Write/Grep/Glob/Bash → KHÔNG được dùng.
> - Domain context + quy trình được inject qua prompt template — không cần domain agent type.
>
> **Bảng substitution canonical:** Xem `procedures/phase4-find-bugs.md §Step 4.5` (Bảng Substitution).
> **Verify checklist trước dispatch:** Xem `procedures/phase4-find-bugs.md §Step 4.6` (Pre-Dispatch Verify).
>
> **Tóm tắt nội dung template** (chi tiết đầy đủ trong file template):
> - Role declaration tiếng Việt ("Bạn là lane agent cho dimension {{DIM_ID}}...")
> - 7 section context: THÔNG TIN PHIÊN, DIM_DIR MAPPING, CI TOOLS, PLAYWRIGHT, QUY TRÌNH 8 BƯỚC, QUY TẮC BẮT BUỘC, FORBIDDEN PATTERNS, SIGNAL EMIT PATTERN, PROBE COMPLETION MARKER, RESUME SUPPORT
> - 8 BƯỚC bắt buộc:
>   1. ĐỌC SUB-SKILL & 4 SHARED PROTOCOL files
>   2. PRE-GATE (5 checks: SESSION_DIR, req-registry, source, probe subset từ profile-resolver, tạo lane-status từ template)
>   3. TẠO CẤU TRÚC THƯ MỤC (5 subdirs: raw/, evidence/, static-scan/, runtime/, llm-scan/)
>   4. CHẠY SONG SONG 2 TRACK (Track A static với bash script, Track B runtime/LLM với CI tools)
>   5. MERGE & VALIDATE (3 file signals.json riêng biệt, từ template)
>   6. TẠO LANE REPORT ({{DIM_DIR}}-report.md từ template QD-report.md)
>   7. CẬP NHẬT LANE STATUS (status, signals counts, probes_executed[], probes_failed[])
>   8. BÁO CÁO VỀ ORCHESTRATOR

<!--
Đoạn template gốc đã được tách ra `templates/phase4-find-bugs/lane-agent-prompt.md` (CORE-031).
KHÔNG paste lại nội dung template ở đây để tránh duplicate source-of-truth.
Mọi sửa đổi template PHẢI làm trên file template, không sửa ở §15.
-->

```text
# Render flow (BẮT BUỘC — KHÔNG được skip)
READ templates/phase4-find-bugs/lane-agent-prompt.md
  ↓
SUBSTITUTE {{VAR}} placeholders (xem bảng tại phase4-find-bugs.md §Step 4.5)
  ↓
STRIP HTML comment header (giữ từ "Bạn là lane agent..." trở đi)
  ↓
VERIFY rendered prompt (phase4-find-bugs.md §Step 4.6 — 6 check points)
  ↓
Agent(subagent_type="claude", prompt=<rendered_text>)
```

## Triage Agent Prompt (Phase 5)

> **Canonical:** [`phase5-triage.md §Step 5.5`](../phase5-triage.md#step-55--spawn-wf-fix-triage-agent)
>
> Toàn bộ prompt template (8 CORE-037 sections: Role, Task, Session Context, CI Context, Playwright Context, Output Contract, Ownership, Completion Criteria) sống trong Step 5.5 — đó là **single source of truth**. KHÔNG duplicate nội dung prompt tại §15 để tránh dual SoT drift (F02.002 anti-pattern).
>
> Khi cần đọc prompt cụ thể: mở `phase5-triage.md` Step 5.5 → READ block prompt giữa `**1. Role:**` và Completion Criteria.

## Execute Agent Prompt (Phase 6)

> **Canonical:** [`phase6-execute.md §Step 6.4`](../phase6-execute.md#step-64--spawn-wf-fix-execute-agent)
>
> Toàn bộ prompt template (8 CORE-037 sections) sống trong Step 6.4 — đó là **single source of truth**. KHÔNG duplicate nội dung prompt tại §15 để tránh dual SoT drift (F02.002 anti-pattern).
>
> Khi cần đọc prompt cụ thể: mở `phase6-execute.md` Step 6.4 → READ block prompt trong `Agent({...})` call.
