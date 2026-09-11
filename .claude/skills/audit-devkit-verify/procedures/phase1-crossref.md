# Phase 1: Cross-Reference Verification (4 Sub-Passes)

> Spawn `cross-reference-auditor` agents để verify references giữa components.
> 4 passes chia theo domain. Pass A+B chạy **song song**, Pass C+D chạy **song song**.
>
> **Chỉ áp dụng khi** `$SCOPE` ∈ { `crossref`, `all` }. Với `$SCOPE = "skill"` → dùng `phase1-focused.md`.

## PRE-GATE

- Phase 0 POST-GATE pass
- `$INDEX` loaded, `$VERIFY_DIR` tồn tại

## Auditor Prompt Template

> Xem `_shared.md §Auditor Prompt Templates → Template chung`. Mỗi pass điền:
> - `[AGENT_TYPE]` = `cross-reference-auditor`
> - `[DOMAIN]` = domain của pass (agents↔skills, skills↔templates, docs, hooks)
> - `[PREFIX]` = `XRF`
> - Paste relevant lists + checks

---

## Pass A: Agents ↔ Skills

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.1 | Trích list agents + list skills từ `$INDEX` | Read | 2 lists created |
| 1.2 | Spawn `cross-reference-auditor` với prompt: verify agents ↔ skills | Agent | Agent started |
| 1.3 | Agent kiểm tra: mỗi `subagent_type` trong skills → agent file tồn tại | Agent | Checked |
| 1.4 | Agent kiểm tra: mỗi agent có procedure path → procedure file tồn tại | Agent | Checked |
| 1.5 | Thu thập kết quả, parse JSON | Read | findings parsed |
| 1.6 | Write `$VERIFY_DIR/findings-crossref-agents-skills.json` (schema `audit-findings-v1`) | Write | File created |

## Pass B: Skills ↔ Templates

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.7 | Trích list skills + list templates từ `$INDEX` | Read | 2 lists created |
| 1.8 | Spawn `cross-reference-auditor` với prompt: verify skills ↔ templates | Agent | Agent started |
| 1.9 | Agent kiểm tra: mỗi template ref trong skill → template file tồn tại | Agent | Checked |
| 1.10 | Agent kiểm tra: mỗi template được ít nhất 1 skill reference (orphan check) | Agent | Checked |
| 1.11 | Thu thập kết quả, parse JSON | Read | findings parsed |
| 1.12 | Write `$VERIFY_DIR/findings-crossref-skills-templates.json` | Write | File created |

> **Spawn Pass A (step 1.2) + Pass B (step 1.8) ĐỒNG THỜI** — 2 Agent tool calls trong 1 message.

## Pass C: Agents ↔ Rules ↔ CLAUDE.md

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.13 | Trích agents count + skills list từ `$INDEX` | Read | data extracted |
| 1.14 | Spawn `cross-reference-auditor` với prompt: verify agents ↔ rules ↔ CLAUDE.md | Agent | Agent started |
| 1.15 | Agent kiểm tra: CLAUDE.md agent counts = actual counts từ index | Agent | Checked |
| 1.16 | Agent kiểm tra: CLAUDE.md skill table = actual skills | Agent | Checked |
| 1.17 | Agent kiểm tra: `rules/00-core.md` workflow list = actual skills | Agent | Checked |
| 1.18 | Thu thập kết quả, parse JSON | Read | findings parsed |
| 1.19 | Write `$VERIFY_DIR/findings-crossref-docs.json` | Write | File created |

## Pass D: Hooks ↔ Skills ↔ Rules

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.20 | Trích hooks + skills + rules từ `$INDEX` | Read | data extracted |
| 1.21 | Spawn `cross-reference-auditor` với prompt: verify hooks ↔ skills ↔ rules | Agent | Agent started |
| 1.22 | Agent kiểm tra: hook paths reference đúng scripts/rules | Agent | Checked |
| 1.23 | Agent kiểm tra: hooks trong `settings.json` khớp với files trong `hooks/` | Agent | Checked |
| 1.24 | Thu thập kết quả, parse JSON | Read | findings parsed |
| 1.25 | Write `$VERIFY_DIR/findings-crossref-hooks.json` | Write | File created |

> **Spawn Pass C (step 1.14) + Pass D (step 1.21) ĐỒNG THỜI** — 2 Agent tool calls trong 1 message.

---

## Pass-specific check details

### Pass A prompt specifics

```
Kiểm tra:
- Mỗi skill có `subagent_type: <agent>` → file `.claude/agents/**/<agent>.md` tồn tại
- Mỗi agent có `procedure_path: <path>` → file tồn tại
- Agent filename (không .md) = subagent_type string (case-sensitive)
```

### Pass B prompt specifics

```
Kiểm tra:
- Mỗi skill references template (ví dụ `templates/xxx.json`, `doc-framework/yyy.md`) → file tồn tại
- Mỗi template (trong templates/ hoặc doc-framework/) có ≥1 skill reference
- Orphan templates → MINOR finding
- Missing templates → CRITICAL (skill sẽ fail runtime)
```

### Pass C prompt specifics

```
Kiểm tra:
- CLAUDE.md "62 agents" matches $INDEX.counts.agents
- CLAUDE.md skill table rows == số skills trong workflow/ folder
- rules/00-core.md §2 Workflow list có chứa mọi wf-* skill hiện có
- rules/00-core.md §4b Cross-Skill Output Path Contract references đều valid paths
```

### Pass D prompt specifics

```
Kiểm tra:
- settings.json hooks[].command paths → file .claude/hooks/*.sh tồn tại
- Mọi file .claude/hooks/*.sh có ít nhất 1 entry trong settings.json
- Hook paths reference đúng scripts/rules (không hardcoded absolute path)
```

---

## POST-GATE

- 4 `findings-crossref-*.json` files tồn tại trong `$VERIFY_DIR`
- Mỗi file là valid JSON
- Mỗi file có `$schema: "audit-findings-v1"`
- Update `verify-status.json` với completed passes:
  - `phase1-pass-a`, `phase1-pass-b`, `phase1-pass-c`, `phase1-pass-d`

## Routing sau Phase 1

- Nếu `$SCOPE == "crossref"` → **STOP** tại đây (chuyển sang `phase4-merge.md` để tính verdict + report partial scope)
- Nếu `$SCOPE == "all"` → tiếp tục `phase2-workflow.md`

## Errors liên quan

- **E006** — Agent timeout → re-spawn 1 lần, sau đó skip pass + WARNING
- **E007** — Agent trả text thay vì JSON → fallback parse, nếu fail → MANUAL
- **E008** — `findings-crossref-*.json` missing → re-run missing pass, nếu fail → partial merge + WARNING

Chi tiết: `_shared.md §Error Handling Reference`.
