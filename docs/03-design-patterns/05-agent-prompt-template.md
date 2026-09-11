# 05 — Agent Prompt Template (8 sections)

> **Mức độ ràng buộc:** BẮT BUỘC khi spawn agent
> **Rule liên quan:** CORE-037
> **Khi nào dùng:** Mọi lần skill spawn agent qua `Agent` tool

---

## 1. Vấn đề pattern giải quyết

Trước CORE-037, agent prompts trong MCV3 thiếu nhất quán:
- Agent A nhận role + task
- Agent B nhận role + task + CI context (random)
- Agent C nhận task + output path (quên role)
- ...

**Hệ quả:**
- Agent A bỏ lỡ CI tools — perf kém
- Agent B không biết output path — ghi sai chỗ
- Agent C tự suy diễn role — output không phù hợp

**Pattern giải quyết:** Mọi agent prompt PHẢI có **8 sections** theo thứ tự cố định.

---

## 2. 8 sections bắt buộc

```
Section 1: Role declaration
Section 2: Task instruction
Section 3: Session context
Section 4: CI context injection
Section 5: Playwright context (nếu applicable)
Section 6: Output contract
Section 7: Ownership rules
Section 8: Completion criteria
```

### Section 1: Role Declaration

```markdown
## Section 1: Role

Bạn là **security engineer** cho dimension lane **QD3** trong skill **wf-fix-bugs v10.2.1**.
Mục tiêu: phát hiện security vulnerabilities (OWASP Top 10) trong scope dự án hiện tại.
```

### Section 2: Task Instruction

```markdown
## Section 2: Task

Đọc file `.claude/skills/workflow/wf-fix-security/SKILL.md` và thực thi đầy đủ 7 probes:
1. SQL injection
2. XSS
3. Authentication
4. Authorization
5. Sensitive data exposure
6. Security misconfiguration
7. Dependency vulnerabilities

Output: 1 file `signals.json` theo schema `lane-signals-v1`.
```

### Section 3: Session Context

```markdown
## Section 3: Session

SESSION_DIR: .mc-data/work/wf-fix-bugs/sessions/2026-05-15-crm-payment-01/
PROFILE: standard
SCOPE: module:crm/payment
NAME: payment-validation

Input artifacts (already available):
- preflight-impact.json: $SESSION_DIR/phase1-init/preflight-impact.json
- registry: .mc-data/docs/_meta/req-registry.json
```

### Section 4: CI Context Injection

```markdown
## Section 4: CI Context

GitNexus available: true (index commit abc123, 3 commits behind HEAD — light WARN)
Serena available: true

CI-ROUTE for your tasks:
- Find sanitize patterns → Serena.find_referencing_symbols(name="sanitize_input")
- Impact analysis on suspected functions → GitNexus.impact(target=...)
- API route map → GitNexus.route_map() to identify all endpoints
- Fallback: Grep when CI tool times out

Index may miss 3 recent commits — re-verify critical findings manually.
```

Nếu CI không available, thay bằng:
```markdown
## Section 4: CI Context

CI tools unavailable (GitNexus=false, Serena=false).
Use Grep/Glob/Read for code analysis.
Note: Impact analysis limited — flag findings as "needs-manual-review".
```

### Section 5: Playwright Context (nếu applicable)

```markdown
## Section 5: Playwright Context

Mode: assisted (browser visible, user can intervene)
Base URL: http://localhost:3000
Test credentials: load from vault via `wf-e2e-credentials`
Devices: desktop (1920x1080), mobile (iPhone 12)

Allowed actions: navigate, click, type, screenshot
Forbidden: file_upload of untrusted, run_code_unsafe
```

Skip section này nếu không cần browser.

### Section 6: Output Contract

```markdown
## Section 6: Output Contract

Ghi output vào: `$SESSION_DIR/phase4-find-bugs/lanes/QD3/signals.json`

Schema: lane-signals-v1
Required fields: lane, agent_type, status, execution_time_s, signals[]
Each signal must have: severity, category, title, evidence{file,line_range,code_snippet}, fix_recommendation

Template: `.claude/skills/workflow/wf-fix-security/templates/signals.json` (READ → POPULATE → WRITE)
```

### Section 7: Ownership Rules

```markdown
## Section 7: Ownership

You own ONLY: `$SESSION_DIR/phase4-find-bugs/lanes/QD3/*`

DO NOT write to:
- Other lanes' folders (QD1/, QD2/, QD4/, ...)
- fix-status.json (orchestrator owns)
- registry (skill PRIMARY owners only)

1 file = 1 writer. If you discover an issue outside QD3 scope, mention it in your report but DO NOT fix.
```

### Section 8: Completion Criteria

```markdown
## Section 8: Completion Criteria

Tasks complete when:
- [ ] All 7 probes executed
- [ ] signals.json written with valid schema
- [ ] status = "completed" in signals.json
- [ ] No file written outside QD3 scope
- [ ] If timeout: status = "timeout", explain why in signals.json.errors[]

POST-GATE will run:
T1: signals.json exists
T2: jq validate structure
T3: signals[] length > 0 OR probe_results recorded
T4: $schema = "lane-signals-v1"
```

---

## 3. Case study — wf-fix-bugs Phase 4 spawn 11 lane agents

Mỗi lane có prompt theo đúng 8 sections. Khác nhau ở:
- Section 1: agent type khác nhau (developer, security, dba, ...)
- Section 2: probes list khác per lane
- Section 4: CI-ROUTE specific cho task (security cần find_references; performance cần impact)
- Section 6: output path khác (lanes/QD1/ vs QD2/ vs ...)
- Section 7: each lane chỉ own folder của nó

**Section 3, 5, 8 phần lớn similar** — dùng template generator để build.

### 3.1. Mẫu code spawn

```python
# Build prompt từ template
def build_lane_prompt(lane_id, agent_type, probes, output_path):
    return f"""
## Section 1: Role
Bạn là {agent_type} cho dimension lane {lane_id} trong wf-fix-bugs v10.2.1.
Mục tiêu: phát hiện {get_lane_focus(lane_id)} issues trong scope dự án hiện tại.

## Section 2: Task
Đọc .claude/skills/workflow/wf-fix-{lane_focus}/SKILL.md và thực thi {len(probes)} probes:
{format_probes(probes)}

## Section 3: Session
SESSION_DIR: {SESSION_DIR}
PROFILE: {PROFILE}
SCOPE: {SCOPE}
NAME: {NAME}

## Section 4: CI Context
{CI_CONTEXT}

## Section 5: Playwright Context
{PLAYWRIGHT_CONTEXT if lane_id in ['QD5', 'QD9'] else 'N/A — lane này không cần browser'}

## Section 6: Output Contract
Ghi vào: {output_path}
Schema: lane-signals-v1
Template: {template_path}

## Section 7: Ownership
You own: {SESSION_DIR}/phase4-find-bugs/lanes/{lane_id}/*

## Section 8: Completion
- All probes executed
- signals.json valid + status="completed"
"""

# Spawn parallel
for lane in active_lanes:
    Agent(
        description=f"Lane {lane.id} analysis",
        subagent_type=lane.agent_type,
        prompt=build_lane_prompt(...)
    )
```

---

## 4. Variations / Edge cases

### 4.1. Single-shot agent (không phải lane)

Agent spawn 1 lần cho task atomic (vd: code-reviewer review 1 PR):

```
- Section 1: Role (code-reviewer for PR review)
- Section 2: Task (review src/auth.ts changes)
- Section 3: Session (PR diff path)
- Section 4: CI context (recommend GitNexus.impact())
- Section 5: skip (no browser)
- Section 6: Output review.md path
- Section 7: Own only review.md
- Section 8: Done when review complete + recommendations
```

Đủ 8 sections kể cả single-shot.

### 4.2. Domain expert agent

Section 1 phải nêu domain knowledge reference:

```markdown
## Section 1: Role

Bạn là **healthcare-expert** cho Phase 1 analysis.
Reference knowledge: `.claude/references/team-expert/healthcare/` (EMR, HL7 FHIR, BHYT VN).
Procedures: `.claude/agents/procedures/healthcare-expert/`.
```

### 4.3. Agent recursive spawn — KHÔNG được

```
❌ Agent QD3 (security) tự spawn agent api-tester
→ Bypass skill orchestration

✅ Skill orchestrator spawn cả 2 song song trong Phase 4
```

---

## 5. Anti-patterns

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Thiếu Section 4 (CI Context) | Bắt buộc — kể cả khi CI unavailable, nêu "fallback Grep" |
| Section 6 không có template path | Phải có (CORE-031 — output từ template) |
| Section 7 nói "you can write anywhere" | Phải chỉ rõ scope (1 file = 1 writer) |
| Section 8 chỉ "do your best" | Phải có completion criteria + POST-GATE preview |
| Agent prompt > 2000 dòng (quá dài) | Tách reference vào agent file `.claude/agents/...md`, chỉ pass essential context |
| Section 3 thiếu SESSION_DIR | Agent không biết ghi đâu |
| Spawn agent với `subagent_type="general-purpose"` cho task chuyên biệt | Dùng agent chuyên biệt (security, dba, ...) |
| 2 agents cùng task type, cùng prompt → song song | 1 task = 1 agent (tránh duplicate work) |
| Section 5 (Playwright) nêu mode mà skill không dùng | Skip section 5 nếu không applicable |

---

## 6. Checklist áp dụng

**Khi viết spawn code:**

- [ ] Prompt có đủ 8 sections theo thứ tự
- [ ] Section 1: agent type + project context
- [ ] Section 2: task cụ thể + skill SKILL.md path
- [ ] Section 3: SESSION_DIR, PROFILE, SCOPE, NAME, input artifacts
- [ ] Section 4: CI_CONTEXT từ Protocol 20 PRE-GATE Nc
- [ ] Section 5: Playwright context nếu cần, else "N/A"
- [ ] Section 6: output path cụ thể + schema + template path
- [ ] Section 7: ownership scope + "1 file = 1 writer"
- [ ] Section 8: completion criteria + POST-GATE preview
- [ ] Spawn với `model="opus"` (nếu Sonnet quota hết)
- [ ] Max concurrency ≤10 cho parallel batch

---

## 7. Liên kết

- **Standard:** [`../02-standards/03-agent-standard.md`](../02-standards/03-agent-standard.md)
- **Rule:** CORE-037 trong [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4n
- **Related patterns:**
  - [`02-ci-first-integration.md`](02-ci-first-integration.md) — Section 4 source
  - [`04-parallel-lane-dispatch.md`](04-parallel-lane-dispatch.md) — Use case parallel spawn
  - [`07-playwright-3-modes.md`](07-playwright-3-modes.md) — Section 5 source
- **Case study:** `.claude/skills/workflow/wf-fix-bugs/procedures/phase4-find-bugs.md`
