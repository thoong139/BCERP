<!--
_template_notes:
  purpose: Template prompt 8 sections cho mọi `Agent({...})` call trong skill spawn agents.
  populate:
    - Đổi {agent-role}, {skill-name}, {phase}, {output-paths}
    - Giữ NGUYÊN số thứ tự 8 sections (CORE-037 enforce)
    - Mỗi section có comment ghi chú "BẮT BUỘC" hay "OPTIONAL"
    - Khi spawn nhiều agents cho 1 phase, COPY toàn bộ template này, populate riêng
  Áp dụng: BẮT BUỘC cho mọi agent spawn từ skill (CORE-037)
  độ dài: 80-150 dòng/agent prompt khi đầy đủ
-->

# Agent Prompt Template (CORE-037)

> **Mục đích file:** Template chuẩn cho mọi `Agent({subagent_type, prompt})` call trong skill `{skill-name}`. Đảm bảo 8 sections BẮT BUỘC + ownership rules + completion criteria rõ ràng.

---

## Cấu trúc 8 sections (BẮT BUỘC)

```markdown
# 1. ROLE DECLARATION (BẮT BUỘC)
Bạn là **{agent-role}** cho skill `{skill-name}` (Phase {N} — {phase-name}).

# 2. TASK INSTRUCTION (BẮT BUỘC)
Đọc file `.claude/skills/workflow/{skill-name}/SKILL.md` và thực thi đầy đủ Phase {N}
theo procedure file `.claude/skills/workflow/{skill-name}/procedures/phase{N}-{name}.md`.

KHÔNG được:
- Thay đổi scope ngoài Phase {N}
- Đọc/ghi files ngoài $SESSION_DIR (trừ SSOT registry)
- Spawn sub-agent (chỉ orchestrator được phép)

# 3. SESSION CONTEXT (BẮT BUỘC)
- SESSION_DIR: {session-dir}                    ← .mc-data/work/{skill-name}/sessions/{id}/
- PROFILE: {quick|standard|deep|exhaustive}
- SCOPE: {all|module:X|file:Y}
- NAME: {feat-id|module-id|context-name}
- TIMESTAMP: {ISO 8601}

# 4. CI CONTEXT INJECTION (CONDITIONAL — nếu CI available)
$CI_CONTEXT
# Format: GITNEXUS_AVAILABLE=true|false, SERENA_AVAILABLE=true|false,
#         INDEX_FRESHNESS=ok|light|strong|severe, FALLBACK_TOOL=Grep|Glob

Routing tool ưu tiên:
- Symbol lookup → Serena `find_symbol` (nếu available) → fallback Grep
- Impact analysis → GitNexus `impact()` (nếu available) → fallback Grep
- Execution flow → GitNexus `query()` → fallback Read+trace

# 5. PLAYWRIGHT CONTEXT (CONDITIONAL — nếu skill có UI test)
PLAYWRIGHT_MODE: {none|assisted|full}
DEVICES: {desktop|mobile|tablet|...}
BASE_URL: {URL nếu mode != none}

KHÔNG dùng Playwright nếu:
- interface_type=api-only
- PLAYWRIGHT_MODE=none
- --no-browser flag set

# 6. OUTPUT CONTRACT (BẮT BUỘC)
| # | Output path | Schema | Required | Note |
|---|-------------|--------|----------|------|
| 1 | $SESSION_DIR/phase{N}-{name}/{output1}.json | {schema-v1} | ✅ | Atomic write |
| 2 | $SESSION_DIR/phase{N}-{name}/Phase{N}-report.md | — (md) | ✅ | Tiếng Việt ≤15 dòng |
| 3 | $SESSION_DIR/phase{N}-{name}/{output3}.md | — | ⚪ | Optional |

Mọi output PHẢI:
- Atomic write pattern (.tmp.$$ → validate → mv)
- Pass POST-GATE T1→T4 (xem `04-file-contract.md` §2)
- KHÔNG ghi đè output của agent khác (1 file = 1 writer)

# 7. OWNERSHIP RULES (BẮT BUỘC)
- File này là OWNER của: {list output paths}
- KHÔNG modify: $SESSION_DIR/fix-status.json (orchestrator owns)
- KHÔNG modify: $SESSION_DIR/error-ledger.json (write qua helper `record_error()`)
- KHÔNG modify: $SESSION_DIR/session-log.json (append qua helper `log_phase_*()`)
- Registry update: chỉ orchestrator (KHÔNG được sửa req-registry.json từ agent)

# 8. COMPLETION CRITERIA (BẮT BUỘC)
Phase {N} HOÀN THÀNH khi:
- ✅ Tất cả output ở §6 tồn tại + pass POST-GATE T1→T4
- ✅ Phase{N}-report.md viết tiếng Việt ≤15 dòng (CORE-028)
- ✅ Không có error CRITICAL trong error-ledger.json
- ✅ Context budget <80% (CORE-038)

Báo cáo về orchestrator format:
```
PHASE_{N}_STATUS=PASS|FAIL
PHASE_{N}_OUTPUTS={comma-separated paths}
PHASE_{N}_NEXT={next phase name | null}
```
```

---

## Ví dụ áp dụng (concrete)

### Spawn QA agent cho phase Test Generation

```python
Agent({
  "subagent_type": "qa-lead",
  "description": "Generate test cases Phase 3",
  "prompt": """
# 1. ROLE
Bạn là **qa-lead** cho skill `wf-implement-feature` (Phase 3 — Test Generation).

# 2. TASK
Đọc `.claude/skills/workflow/wf-implement-feature/SKILL.md` và thực thi Phase 3
theo `.claude/skills/workflow/wf-implement-feature/procedures/phase3-test-gen.md`.

# 3. SESSION
SESSION_DIR=.mc-data/work/wf-implement-feature/sessions/2026-05-15-feat-cust-001-01/
PROFILE=standard
NAME=FEAT-CRM-CUST-001

# 4. CI
$CI_CONTEXT
# (đã preload bởi orchestrator, dùng Serena find_symbol để tìm existing code)

# 5. PLAYWRIGHT
PLAYWRIGHT_MODE=assisted
DEVICES=desktop,mobile
BASE_URL=http://localhost:3000

# 6. OUTPUT CONTRACT
| Path | Schema | Required |
| $SESSION_DIR/phase3-test-gen/test-plan.json | test-plan-v1 | ✅ |
| $SESSION_DIR/phase3-test-gen/test-cases.md | — (md) | ✅ |
| $SESSION_DIR/phase3-test-gen/Phase3-report.md | — (md, ≤15 dòng) | ✅ |

# 7. OWNERSHIP
OWNER: 3 file trên.
KHÔNG modify: fix-status.json, error-ledger.json, registry, code/.

# 8. COMPLETION
Báo cáo:
PHASE_3_STATUS=PASS
PHASE_3_OUTPUTS=test-plan.json,test-cases.md,Phase3-report.md
PHASE_3_NEXT=phase4-implement
"""
})
```

---

## Quy tắc spawn (CORE-025 + CORE-037)

| Quy tắc | Detail |
|---|---|
| Model | Default `opus`. Fallback `sonnet` nếu quota hết |
| Concurrency | Max 10 agents/phase (CORE-025). Vượt → batch theo wave |
| 1 file = 1 writer | KHÔNG 2 agent ghi cùng 1 file. Dùng atomic write + lock nếu thực sự cần |
| Timeout | Mỗi agent ≤5 min. Vượt → orchestrator kill + retry |
| Sub-agent | KHÔNG được — chỉ orchestrator spawn agent (tránh runaway) |

---

## Anti-patterns (KHÔNG làm)

❌ **Vague role:** "Bạn là engineer" → đổi thành cụ thể như "Bạn là frontend-developer cho phase X"
❌ **No output contract:** Agent tự quyết file ghi → đổi thành liệt kê đầy đủ §6
❌ **Modify orchestrator state:** Agent ghi fix-status.json → CHỈ orchestrator được ghi
❌ **Cross-agent file overlap:** 2 agent ghi cùng `phase3-report.md` → tách path riêng
❌ **No completion criteria:** Agent return prose dài → enforce format STATUS/OUTPUTS/NEXT

---

## Liên kết

- Rule: CORE-037 (Agent Prompt Templates), CORE-025 (Parallelization)
- Pattern: [`../../03-design-patterns/05-agent-prompt-template.md`](../../03-design-patterns/05-agent-prompt-template.md)
- Procedures section: [`07-procedures-structure.md`](07-procedures-structure.md)
- Concrete examples: [`../wf-fix-bugs/03-architecture.md`](../wf-fix-bugs/03-architecture.md) (orchestrator spawn pattern)
