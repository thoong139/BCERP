# Shared Protocols — audit-agents

> Cross-cutting state variables, anti-pattern tables, fix rules, schemas, auditor prompt templates
> được dùng bởi nhiều Phase trong audit-agents v3.0.0.
> KHÔNG đọc file này standalone — chỉ load section cụ thể khi phase cần.

## Sections

- [State Variables Glossary](#state-variables-glossary)
- [Cross-Phase Data Flow](#cross-phase-data-flow)
- [Fix Rules](#fix-rules)
- [Auditor Prompt Templates](#auditor-prompt-templates)
- [Finding ID Prefixes](#finding-id-prefixes)
- [Anti-pattern Tables](#anti-pattern-tables)
- [Criteria Detail Tables](#criteria-detail-tables)
- [Schemas](#schemas)
- [Checkpoint & Resume](#checkpoint--resume)
- [Error Handling Reference](#error-handling-reference)
- [Verdict Computation](#verdict-computation)

---

## State Variables Glossary

| Variable | Set by Phase | Read by Phase | Description |
|----------|-------------|---------------|-------------|
| `$SCOPE` | 0 | 0, 1, 2, 3, 4, 5 | `full` / `agents` / `procedures` / `references` / `single` |
| `$TARGET_AGENT` | 0 | 1, 4 | Tên agent khi scope=`single` (VD: `sales-expert`). NULL khi scope khác |
| `$SESSION_ID` | 0 | All | Timestamp-based: `YYYYMMDD-HHMMSS` |
| `$SESSION_DIR` | 0 | All | `.mc-data/work/audit-agents/$SESSION_ID/` |
| `$REPORT_DATE` | 0 | 5 | `YYYY-MM-DD` cho filename report |
| `$SPEC` | 0 | 1, 2, 3 | Content of `.claude/agents/spec/README.md` (criteria section) |
| `$AGENT_TEMPLATE` | 0 | 1 | Content of `agent-definition-template.md` |
| `$KNOWLEDGE_TEMPLATE` | 0 | 3 | Content of `knowledge-template.md` |
| `$AGENT_FILES[]` | 0 | 1, 4 | List of agent files trong scope |
| `$PROCEDURE_FILES[]` | 0 | 2, 4 | List of procedure files |
| `$KNOWLEDGE_DIRS[]` | 0 | 3, 4 | List of knowledge domain directories |
| `$KNOWLEDGE_FILES[]` | 0 | 3, 4 | List of knowledge files |
| `$BATCH_INDEX` | 1 | 1 | Index của batch hiện tại (0-based) |
| `$FINDINGS_FILES[]` | 1-4 | 5 | Danh sách findings JSON files đã tạo |

---

## Cross-Phase Data Flow

```
Phase 0 (init)         → $SCOPE, $SESSION_ID, $SESSION_DIR, $SPEC, $AGENT_FILES, ...
                        → status.json (initial)
Phase 1 (agents)       → findings-agents.json (per-batch append)
                        → status.json (completed_batches[])
Phase 2 (procedures)   → findings-procedures.json
Phase 3 (knowledge)    → findings-knowledge.json
Phase 4 (crossref)     → findings-crossref.json
Phase 5 (report)       → audit-result.json (merged)
                        → docs/audit/reports/agent-audit-[date].md
                        → status.json (completed)
```

**Quy tắc:** Mỗi phase chỉ READ variables đã được SET ở phase trước. POST-GATE của phase N cập nhật `status.json.completed_phases[]`.

---

## Fix Rules

| Error Type | Auto-Fix Strategy | Escalate If |
|-----------|-------------------|-------------|
| Agent file thiếu section | Không auto-fix — chỉ report | Luôn escalate |
| Knowledge file > 400 dòng | Suggest split points | User xác nhận |
| Procedure file > 200 dòng | Suggest split into separate task types | User xác nhận |
| Broken knowledge routing path | Suggest correct path | Path ambiguous |
| Orphan knowledge/procedure file | Suggest agent nào nên routing | Nhiều candidates |
| Name mismatch (frontmatter vs filename) | Suggest rename | Luôn escalate |
| Agent-auditor sub-agent timeout | Retry ×3 | Fail lần 3 → fallback kiểm tra trực tiếp |
| Agent-auditor trả text thay vì JSON | Fallback parse: extract JSON từ text | Parse fail → log raw + MANUAL |

---

## Auditor Prompt Templates

### Template chung (Phase 1 — agent batch audit)

```
Bạn là agent-auditor. Audit batch các agent files theo spec.

Spec (đã load):
[paste relevant criteria from .claude/agents/spec/README.md]

Agent files cần audit:
[list 5 files với paths]

Kiểm tra theo các tiêu chí A1-A10 (xem spec):
- A1: Frontmatter (name, version, last_updated, description, tools, model, permissionMode)
- A2: Identity — Vai trò (≤5 dòng, có perspective)
- A3: Expertise (5-10 items, ≤1 dòng/item)
- A4: Cognitive Framework (named perspectives)
- A5: Workflow (3-7 bước, có READ instructions)
- A6: Knowledge Routing (business agents — paths chính xác)
- A7: Coordination (referenced agents tồn tại)
- A8: Constraints (3-6 "Bắt buộc" + 3-6 "Không được")
- A9: Kích thước (≤250 dòng)
- A10: Anti-patterns AP-1 đến AP-7

Exemptions:
- orchestrator.md: skip A3, A4, A6; soft limit A9 = 400
- review/*.md: skip A6
- README.md: skip all

Output format: JSON array theo schema trong `_shared.md §Schemas — Finding Object`.
Chỉ trả JSON, không markdown.
```

### Template Phase 2 — procedure audit

```
Bạn là agent-auditor. Audit procedure files theo spec Section 5.

Procedure files:
[list files]

Kiểm tra TC-P0 đến TC-P6:
- P0: Folder structure (folder name = agent name, file name kebab-case)
- P1: Header metadata (Type, Agent, Triggered when, Output)
- P2: Trigger conditions ("Khi nào dùng procedure này")
- P3: Step quality (actionable, có READ instructions)
- P4: Knowledge references (paths trỏ đúng files)
- P5: Kích thước (≤200 dòng, ≤10 procedures/agent)
- P6: Anti-patterns PP-1 đến PP-6

Output: JSON array theo Finding Object schema. Chỉ JSON.
```

### Template Phase 3 — knowledge audit

```
Bạn là agent-auditor. Audit knowledge files theo spec Section 6.

Knowledge domain: [domain-name]
Files: [list]

Kiểm tra TC-K0 đến TC-K3 + TC-KG + TC-KP:
- K0: Cấu trúc (personas.md, operations.md/processes.md, controls.md)
- K1: Personas (3-6 personas với subsections)
- K2: Operations (Processes, KPIs, Integration)
- K3: Controls (Approval, Access, Audit Trail)
- KG: General (Header, ≤400 dòng, facts-only)
- KP: Anti-patterns KP-1 đến KP-7

Domain type:
- Business (1:1): Full K0-K3 checks
- Engineering/Testing (N:1): Chỉ TC-KG + TC-KP
- Cross-domain: Chỉ TC-KG + TC-KP

Output: JSON array theo Finding Object schema. Chỉ JSON.
```

---

## Finding ID Prefixes

| Phase | Prefix | Example |
|-------|--------|---------|
| 1 (agent) | `AGT-` | `AGT-001` (agent finding #1) |
| 2 (procedure) | `PRC-` | `PRC-001` |
| 3 (knowledge) | `KNW-` | `KNW-001` |
| 4 (crossref) | `XRF-` | `XRF-001` |

---

## Anti-pattern Tables

### AP-1 đến AP-7 (Agent anti-patterns)

| AP # | Anti-pattern | Severity | Cách detect |
|------|-------------|----------|-------------|
| AP-1 | Knowledge Dump — section >30 dòng chứa tables/data | MAJOR | `wc -l` per section |
| AP-2 | Workflow trống — không có bước cụ thể | MAJOR | Check `### Bước` |
| AP-3 | No Routing — không có Knowledge Routing table | MAJOR | Check `## Knowledge References` |
| AP-4 | Constraint thiếu — <3 "Bắt buộc" hoặc <3 "Không được" | MAJOR | Count constraint items |
| AP-5 | Island Agent — không có Coordination section | MAJOR | Check `## Coordination` |
| AP-6 | Redundant Standards — copy bảng Standards chi tiết | MINOR | Compare with knowledge files |
| AP-7 | Vague Identity — chỉ "Chuyên gia về X" không có perspective | MAJOR | Check for perspective keywords |

### PP-1 đến PP-6 (Procedure anti-patterns)

| PP # | Anti-pattern | Severity | Cách detect |
|------|-------------|----------|-------------|
| PP-1 | Fact Dump — chứa domain facts thay vì READ instruction | MAJOR | Tìm data tables, formulas |
| PP-2 | God Procedure — 1 file cho mọi task types | MAJOR | File >200 dòng hoặc cover >1 task |
| PP-3 | Missing Trigger — không có "Khi nào dùng" | MAJOR | Check trigger section |
| PP-4 | Vague Steps — bước không actionable | MAJOR | Scan cho "phân tích kỹ", "làm tốt" |
| PP-5 | Orphan Procedure — agent file không pointer | MAJOR | Check agent file for procedure refs |
| PP-6 | Wrong Location — file không trong `agents/procedures/[agent-name]/` | MAJOR | Check file path |

### KP-1 đến KP-7 (Knowledge anti-patterns)

| KP # | Anti-pattern | Severity | Cách detect |
|------|-------------|----------|-------------|
| KP-1 | Behavior Leak — "bạn nên", "luôn luôn", "PHẢI" | MAJOR | Grep behavioral keywords |
| KP-2 | Stale Data — không có last_updated header | MINOR | Check header format |
| KP-3 | Monolith File — 1 file > 400 dòng | MAJOR | `wc -l` > 400 |
| KP-4 | Orphan File — knowledge file không agent nào pointer | MAJOR | Set difference: files - routing refs |
| KP-5 | Missing Personas — domain không có personas file | MAJOR | Check file existence |
| KP-6 | Abstract Facts — chỉ lý thuyết, không template/example | MINOR | Check for tables, templates |
| KP-7 | Mixed Topics — 1 file chứa nhiều topics không liên quan | MINOR | Check heading structure |

---

## Criteria Detail Tables

### TC-A1 Frontmatter checks

| Check ID | Kiểm tra | Severity |
|----------|----------|----------|
| A1.1 | `name` khớp filename (bỏ `.md`) | CRITICAL |
| A1.2 | `version` đúng SemVer | MAJOR |
| A1.3 | `last_updated` format YYYY-MM-DD | MAJOR |
| A1.4 | `description` có "Proactively invoke khi..." | MAJOR |
| A1.5 | `tools` hợp lệ | MINOR |
| A1.6 | `model` hợp lệ (sonnet/opus/haiku) | MAJOR |
| A1.7 | `permissionMode` hợp lệ | MAJOR |

### Exemptions (agents đặc biệt)

| Agent | Skip checks | Lý do |
|-------|-------------|-------|
| `orchestrator.md` | A3, A4, A6 | Điều phối, không phân tích domain |
| `orchestrator.md` | A9 (soft limit → 400) | Cần nhiều routing tables |
| `review/*.md` | A6 | Review agents không cần external knowledge |
| Engineering utility (không có references) | A6 | Dùng code knowledge |
| `README.md` | Tất cả | Không phải agent definition |

### Non-business knowledge domains

| Domain type | Pattern | Audit approach |
|------------|---------|----------------|
| Business (1:1) | 1 agent = 1 domain folder | Full K0-K3 checks |
| Engineering (N:1) | N agents share 1 folder | Chỉ TC-KG + TC-KP |
| Cross-domain | Shared reference files | Chỉ TC-KG + TC-KP |

---

## Schemas

### Finding Object (dùng chung cho mọi phase)

```json
{
  "id": "AGT-001",
  "phase": "agents",
  "severity": "CRITICAL | MAJOR | MINOR",
  "target": "path/to/file.md",
  "target_type": "agent | procedure | knowledge | crossref",
  "check": "TC-A1.1 | AP-3 | TC-X4 | ...",
  "title": "Short title",
  "description": "Mô tả chi tiết vấn đề",
  "evidence": "Line number hoặc quote",
  "suggestion": "Đề xuất sửa",
  "auto_fixable": false
}
```

### status.json (checkpoint + resume)

```json
{
  "session_id": "20260419-110000",
  "scope": "full | agents | procedures | references | single",
  "target_agent": "sales-expert | null",
  "started_at": "2026-04-19T11:00:00Z",
  "completed_at": null,
  "completed_phases": ["phase0-init", "phase1-agents"],
  "pending_phases": ["phase2-procedures", "phase3-knowledge", "phase4-crossref", "phase5-report"],
  "phase1_state": {
    "total_agents": 62,
    "batch_size": 5,
    "total_batches": 13,
    "completed_batches": 3,
    "current_batch_index": 3
  },
  "counts": {
    "agents": 62,
    "procedures": 24,
    "knowledge_domains": 29,
    "knowledge_files": 162
  },
  "findings_files": [
    "findings-agents.json"
  ]
}
```

### audit-result.json (Phase 5 merged output)

```json
{
  "session_id": "20260419-110000",
  "scope": "full",
  "generated_at": "2026-04-19T11:30:00Z",
  "spec_version": "2.2.0",
  "summary": {
    "agents_audited": 62,
    "procedures_audited": 24,
    "knowledge_domains_audited": 29,
    "critical": 2,
    "major": 15,
    "minor": 8,
    "compliance_rate": 87.5
  },
  "findings": [ /* all Finding objects, sorted by severity */ ],
  "report_path": "docs/audit/reports/agent-audit-2026-04-19.md"
}
```

---

## Checkpoint & Resume

**Checkpoint triggers:**
- Mỗi khi phase hoàn thành → update `status.json.completed_phases[]`
- Phase 1 sau mỗi batch → update `phase1_state.completed_batches`
- Context usage > 80% → FORCE checkpoint + STOP

**Resume flow (`--resume`):**
1. Discover latest session dir: Glob `.mc-data/work/audit-agents/*/status.json` → pick latest
2. Read `status.json` → xác định `completed_phases[]` + `pending_phases[]`
3. IF `completed_at != null` → "Session đã hoàn tất, không cần resume"
4. Jump tới `pending_phases[0]`
5. Nếu đang ở Phase 1 (batching) → đọc `phase1_state.current_batch_index`, tiếp tục từ batch tiếp theo

---

## Error Handling Reference

| Code | Situation | Action |
|------|-----------|--------|
| E001 | Spec file không tồn tại | STOP → verify `.claude/agents/spec/README.md` |
| E002 | Không tìm thấy agent files | STOP → verify `.claude/agents/` directory |
| E003 | Knowledge path broken (routing → file not found) | Log CRITICAL finding, continue audit |
| E004 | Agent file corrupt (no frontmatter) | Log CRITICAL finding, skip agent |
| E005 | Glob timeout (quá nhiều files) | Retry với narrower scope |
| E006 | Agent-auditor sub-agent timeout | Retry ×3, fallback kiểm tra trực tiếp |
| E007 | CLAUDE.md counts mismatch | Log MAJOR finding, suggest update |
| E008 | Procedure file không có agent tương ứng | Log MAJOR finding (orphan), continue |
| E009 | Knowledge domain không map 1:1 với agent | Log MINOR finding (multi-agent domain), continue |
| E010 | status.json corrupt khi resume | STOP, yêu cầu chạy lại từ đầu |
| E011 | Agent trả text thay JSON | Fallback parse → nếu fail log raw + MANUAL |
| E012 | Phase 1 batch fail > 3 lần | Log MAJOR, tiếp tục batch kế tiếp |

---

## Verdict Computation

Áp dụng tại Phase 5 (report generation):

```
compliance_rate = 100 * (total_checks - total_findings_weighted) / total_checks
total_findings_weighted = critical*3 + major*2 + minor*1

verdict:
  compliance_rate >= 95 AND critical = 0  → "EXCELLENT"
  compliance_rate >= 85 AND critical = 0  → "GOOD"
  compliance_rate >= 70                    → "ACCEPTABLE"
  compliance_rate < 70 OR critical > 0     → "NEEDS ATTENTION"
```
