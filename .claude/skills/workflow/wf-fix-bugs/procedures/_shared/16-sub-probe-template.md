# §16 Sub-Probe Template

> **Mục đích:** Single source of truth cho prompt template dùng bởi sub-probe Agent() calls bên trong lane skills (QD1 + QD2 hiện tại — extensible cho lanes khác). Đảm bảo 8/8 CORE-037 sections cho mọi sub-probe agent.
>
> **Áp dụng cho:** 6 sub-probe Agent() calls hiện tại:
> - `wf-fix-functional/procedures/probes/P-QD1-agent-feature-verify.md`
> - `wf-fix-functional/procedures/probes/P-QD1-spec-completeness-check.md`
> - `wf-fix-business/procedures/probes/P-QD2-business-analyst-review.md`
> - `wf-fix-business/procedures/probes/P-QD2-domain-expert-review.md` (Standard Mode + Boundary Mode consumer/provider — 3 instances)
>
> **Cross-skill rule:** Sub-probe files thuộc lane skills (wf-fix-functional, wf-fix-business) NHƯNG template canonical ở wf-fix-bugs/`_shared/16-sub-probe-template.md`. Khi sửa template → các probe file PHẢI re-render prompt theo template mới (không duplicate template — F02.002 anti-pattern).

## §16.1 Template Pattern (8 CORE-037 sections — BẮT BUỘC)

```
**1. Role:** Bạn là sub-probe agent {{PROBE_ID}} cho dimension {{DIM_ID}}
({{DIM_DIR}} lane, skill {{LANE_SKILL}}). Vai trò: {{ROLE_DESCRIPTION_1_LINE}}.

**2. Task:** Đọc {{SOURCE_DOCS}} và {{SOURCE_CODE_HINT}}.
{{TASK_INSTRUCTION_BLOCK}}

**3. Session Context:**
   - SESSION_DIR: {{SESSION_DIR}}
   - PROFILE: {{PROFILE}}
   - SCOPE: {{SCOPE}} / NAME: {{NAME}}
   - DIM_DIR: {{DIM_DIR}}
   - PROBE_ID: {{PROBE_ID}}
   - TARGET_ID: {{TARGET_ID}} (feat_id / dept / pair_id tùy probe)

**4. CI Context:** {{CI_CONTEXT}}
   (Nếu available — dùng GitNexus query/impact + Serena find_symbol/find_references
   để chính xác file:line citation. Mỗi finding PHẢI có evidence với code_snippet hoặc
   gitnexus_flow + serena_refs.)

**5. Playwright Context:** {{PLAYWRIGHT_NOTE}}
   (Mặc định "KHÔNG áp dụng" cho sub-probes — chỉ lane agent cấp 2 mới có thể launch
   browser khi QD9/QD5/QD7 cần. Override = "Có, sequential slot" nếu probe yêu cầu.)

**6. Output Contract:**
   - Format: JSON array `[{type, description, file_path, line_range, severity, evidence, citation}]`
   - evidence schema: {code_snippet | gitnexus_flow | serena_refs[]} (IMP-008 enforcement)
   - citation schema: {gitnexus_flow: string, serena_symbol: string, serena_file_line: string}
   - Output target: `$SESSION_DIR/phase4-find-bugs/lanes/{{DIM_DIR}}/raw/{{PROBE_ID}}.json`
   - Severity values: critical | high | medium | low (CORE-029 spot-check enforce)

**7. Ownership Rules:**
   - CHỈ ghi vào `$SESSION_DIR/phase4-find-bugs/lanes/{{DIM_DIR}}/raw/`
   - KHÔNG ghi đè output của probe khác trong cùng lane
   - KHÔNG ghi vào `phase5-triage/` hoặc `phase6-execute/` — đó là output Phase 5/6
   - 1 file = 1 writer (CORE-025): nếu boundary mode → 2 agents ghi 2 file khác nhau
     (file_consumer.json + file_provider.json), KHÔNG cùng file

**8. Completion Criteria:**
   - Output JSON file tồn tại + parse pass (jq '.' validate)
   - Mọi finding có `type` + `description` non-empty (CORE-029 spot-check)
   - Mọi finding có `evidence` với code_snippet HOẶC citation
   - Severity ∈ {critical, high, medium, low}
   - Nếu zero finding → vẫn emit `[]` (không leave file rỗng — POST-GATE T2 fail)
```

## §16.2 Placeholder Substitution Table

| Placeholder | Substitute by | Source |
|---|---|---|
| `{{PROBE_ID}}` | Probe ID (e.g., `P-QD1-agent-feature-verify`) | dimension.json `.probes[].id` |
| `{{DIM_ID}}` | Dimension ID (e.g., `QD1`, `QD2`) | dimension.json `.id` |
| `{{DIM_DIR}}` | Dimension dir (e.g., `QD1-functional`) | Phase 4 §Step 4.5 substitution table |
| `{{LANE_SKILL}}` | Lane skill name (e.g., `wf-fix-functional`) | dimension.json `.lane_skill` |
| `{{ROLE_DESCRIPTION_1_LINE}}` | 1-câu mô tả vai trò probe | Probe markdown §Overview |
| `{{SOURCE_DOCS}}` | Doc paths probe cần đọc | Probe markdown §ARRANGE |
| `{{SOURCE_CODE_HINT}}` | Code path hints | Probe markdown §ARRANGE |
| `{{TASK_INSTRUCTION_BLOCK}}` | Multi-line task | Probe markdown §ACT (loại bỏ Agent() call) |
| `{{SESSION_DIR}}`, `{{PROFILE}}`, `{{SCOPE}}`, `{{NAME}}` | State variables | `_shared/01-state-vars.md` |
| `{{TARGET_ID}}` | Target identifier (feat_id / dept / pair_id) | Lane runtime per-probe context |
| `{{CI_CONTEXT}}` | CI context string | CI PRE-GATE Nc (xem `_shared/12-ci-detection.md`) |
| `{{PLAYWRIGHT_NOTE}}` | Playwright note | "KHÔNG áp dụng" (default) hoặc per-probe override |

## §16.3 Reference Pattern (BẮT BUỘC trong probe markdown)

Mỗi probe file PHẢI reference template:

````markdown
## ACT — Agent Spawn

> **Template:** `wf-fix-bugs/procedures/_shared/16-sub-probe-template.md §16 Sub-Probe Template`
>
> Render prompt qua substitution table §16.2 trước khi gọi Agent tool.
> 8/8 CORE-037 sections bắt buộc — KHÔNG bỏ section nào.

```text
Agent(
  name="{{PROBE_ID}}-{{TARGET_ID}}",
  subagent_type="{{SUBAGENT_TYPE}}",  # general-purpose | business-analyst | {domain}-expert
  model="opus",                        # BẮT BUỘC per F02.003
  prompt=<rendered template từ §16.1>
)
```
````

## §16.4 Boundary Mode Concurrency Guard (F02.011)

> **Áp dụng cho:** QD2 P-QD2-domain-expert-review Boundary Mode (sub-sub-agents cấp 3).
>
> **Vấn đề:** Spawn N boundary pairs × 2 agents/pair song song có thể vượt giới hạn 10 concurrent (CORE-025) khi cộng với main lanes cấp 2.

**Pattern: Throttle by depth — max 3 cấp 3 concurrent:**

```text
# Pseudocode — runtime delegate sang _shared/concurrency/ Python module

GUARD_DEPTH_3 = 3  # max concurrent sub-sub-agents (cấp 3)
active_lvl3 = 0    # counter shared across boundary pairs trong cùng lane

FOR pair IN BOUNDARY_PAIRS:
   # Wait until slot available
   WHILE active_lvl3 >= GUARD_DEPTH_3:
     sleep(2s)
     active_lvl3 = read_counter()   # atomic read từ session-log.json

   # Acquire 2 slots (consumer + provider chạy parallel theo §7.2)
   atomic_increment(active_lvl3, +2)

   TRY:
     results_A, results_B = parallel_spawn(consumer_agent, provider_agent)
   FINALLY:
     atomic_decrement(active_lvl3, -2)
```

**Tổng concurrent cap (cấp 2 + cấp 3):**

| Cấp | Max | Ghi chú |
|---|---|---|
| Cấp 1 (orchestrator wf-fix-bugs) | 1 | Main process |
| Cấp 2 (11 lane agents) | 4 | Throttle by main pipeline (CORE-025) |
| Cấp 3 (boundary sub-sub-agents) | 3 | Throttle by depth (§16.4) |
| **Tổng concurrent** | **8** | < 10 limit (CORE-025), safe margin 2 |

**Implementation owner:** Runtime Python module `_shared/concurrency/` (lane_dispatch.py + session-log.json atomic counter). Probe markdown CHỈ document pattern, KHÔNG implement counter inline.
