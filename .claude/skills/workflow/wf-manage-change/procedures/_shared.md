# Shared Protocols — wf-manage-change

> Cross-cutting protocols, state variables, safe-write rules, expert selection map và agent prompt templates
> được sử dụng bởi nhiều Phase trong wf-manage-change.
> KHÔNG đọc file này standalone — chỉ load section cụ thể khi cần.

## Sections

- [State Variables Glossary](#state-variables-glossary)
- [Cross-Phase Data Flow](#cross-phase-data-flow)
- [Session Isolation (CORE-030)](#session-isolation-core-030)
- [LEGACY_MODE Detection & Injection (CORE-021/022)](#legacy_mode-detection--injection-core-021022)
- [Expert Selection Map](#expert-selection-map)
- [Registry Safe-Write Rules (CORE-006)](#registry-safe-write-rules-core-006)
- [Agent Prompt Templates (Phase 5)](#agent-prompt-templates-phase-5)
- [Checkpoint Protocol](#checkpoint-protocol)
- [Resume Logic & Routing Table](procedures/resume-routing.md) — tách sang file riêng (S5)
- [CORE-026/028 Trace & Phase Summary](#core-026028-trace--phase-summary)
- [Fix Rules](#fix-rules)

---

## State Variables Glossary

Các biến in-memory được set/đọc xuyên suốt skill execution.

| Variable | Set by Phase | Read by Phase | Description |
|----------|--------------|---------------|-------------|
| `$CHANGE_ID` | Phase 0 (0.1) | 0, 1-6, Resume | Format: `CHG-YYYYMMDD-NNN` |
| `$SESSION_DIR` | Phase 0 (0.1) | Mọi phase | `.mc-data/work/wf-manage-change/$CHANGE_ID/` |
| `$LEGACY_MODE` | Phase 0 (0.4) | Mọi phase | Boolean — true nếu `project-context.md > 500 bytes` (CORE-021) |
| `$DEPRECATED_MODULES` | Phase 0 (0.4b) | 0.8, 1, 2, 3, 4a | Array module IDs có `action="DEPRECATE"` — loại khỏi mọi match |
| `$MATURITY` | Phase 0 (0.5) | 1, 2, 3 | `docs_only` / `designed` / `implementing` / `near_done` |
| `$CHANGE_TYPE` | Phase 0 (0.9) → confirm Phase 1 | 2, 3, 4a | `MODIFY_FEATURE` / `MODIFY_REQUIREMENT` / `ADD_FEATURE` / `DELETE_FEATURE` / `CLARIFY_REQ` / `UNCLEAR` |
| `$ANALYSIS_MODE` | Phase 0 (0.10) | 1 | `quick` / `deep` |
| `$REFERENCED_ARTIFACTS` | Phase 0 (0.7, 0.8) | 1 | Array systems/modules/features/REQ-IDs extract từ prompt |
| `$DRY_RUN` | Phase 0 (args) | 4, Resume | Boolean — nếu true STOP trước Phase 4 |
| `$RUN_TESTS` | Phase 0 (args) hoặc Phase 4c | 4c | Boolean — chạy test suite sau Phase 4c |
| `$CONTEXT_PERCENT` | Mỗi phase | Mỗi phase | Context budget — trigger checkpoint tại 65/80/90% |
| `error_log[]` | Mọi phase | Phase 6 | Array errors — ghi vào change-report.md |

---

## Cross-Phase Data Flow

```
Phase 0 (intake)     → $CHANGE_ID, $SESSION_DIR, $LEGACY_MODE, $DEPRECATED_MODULES,
                       $MATURITY, $CHANGE_TYPE(preliminary), $ANALYSIS_MODE, $REFERENCED_ARTIFACTS,
                       change-status.json, change-intake.json, index.json
Phase 1 (analyze)    → change-analysis.md, affected-artifacts.json, $CHANGE_TYPE(confirmed)
Phase 2 (impact)     → impact-report.md, risk_level, USER GATE (confirm)
Phase 3 (plan)       → change-plan.md, ordered tasks, USER GATE (approve)
Phase 4a (registry+docs) → registry backup + updates, doc files updated, CDG if DELETE
Phase 4b (code)      → code files updated, REQ-IDs preserved, code backups
Phase 4c (tests)     → test files updated, test run results (optional)
Phase 5 (verify)     → preflight result, verify-sync rate, cross-validation coverage
Phase 6 (report)     → change-report.md, phase-summary.md, index.json completed
```

**Quy tắc:** Mỗi phase chỉ READ variables đã được SET ở phase trước. KHÔNG SET lại variables của phase khác.

---

## Session Isolation (CORE-030)

Mọi output của skill được cô lập theo session.

- `$CHANGE_ID` generate tại Phase 0 Step 0.1 (format: `CHG-YYYYMMDD-NNN`)
- `$SESSION_DIR = .mc-data/work/wf-manage-change/$CHANGE_ID/`
- Tất cả đường dẫn dạng `.mc-data/work/wf-manage-change/[file]` đều được hiểu là `$SESSION_DIR/[file]`
- **Ngoại lệ:** `index.json` nằm ở root `.mc-data/work/wf-manage-change/index.json`

**Cấu trúc session:**

```
.mc-data/work/wf-manage-change/
├── index.json                            # Session registry — root, không per-session
└── $CHANGE_ID/                           # = CHG-YYYYMMDD-NNN/
    ├── change-status.json                # Phase 0 — runtime state
    ├── change-intake.json                # Phase 0 — parsed prompt + classification
    ├── change-analysis.md                # Phase 1 — analysis report
    ├── affected-artifacts.json           # Phase 1 — docs_affected + code_affected
    ├── impact-report.md                  # Phase 2 — risk classification
    ├── change-plan.md                    # Phase 3 — ordered tasks
    ├── change-report.md                  # Phase 6 — final report
    ├── phase-summary.md                  # Phase 6 — CORE-028 non-specialist summary
    └── checkpoint.json                   # Any phase — resume checkpoint
```

---

## LEGACY_MODE Detection & Injection (CORE-021/022)

### Detection (CORE-021)

```
LEGACY_MODE = test -f .mc-data/work/legacy-scan/project-context.md && file_size > 500 bytes
```

KHÔNG detect bằng `ledger.json` (false positive).

### Legacy Decisions Bridge (CORE-022)

NẾU `$LEGACY_MODE == true`:

1. Read `.mc-data/work/wf-brainstorm/legacy-decisions.json`
2. Extract `$DEPRECATED_MODULES` = array các module IDs có `action == "DEPRECATE"`
3. **Enforce exclusion** tại các điểm sau:
   - Phase 0 Step 0.8: loại deprecated khỏi match results
   - Phase 1: không phân tích artifacts thuộc $DEPRECATED_MODULES
   - Phase 2: không scan code/docs của deprecated modules
   - Phase 3: không tạo tasks cho deprecated modules
   - Phase 4a: nếu `MODIFY_FEATURE` cho feature thuộc deprecated module → STOP + hỏi user

### Graceful Degradation

Nếu `legacy-decisions.json` không tồn tại:

> ⚠️ legacy-decisions.json not found — user decisions từ wf-brainstorm chưa được propagate.
> Khuyến nghị: Chạy lại /wf-brainstorm Phase 0.5 để tạo file này.
> Tiếp tục với `$DEPRECATED_MODULES = []`.

---

## Expert Selection Map

Phase 1 DEEP mode sử dụng map này để chọn domain experts.

```
MAP departments → experts:
  sales, crm           → sales-expert
  finance, kế toán     → finance-expert
  marketing            → marketing-expert
  hr, nhân sự          → hr-expert
  logistics, vận chuyển → logistics-expert
  manufacturing, sản xuất → manufacturing-expert
  retail, bán lẻ       → retail-expert
  ecommerce, TMĐT      → ecommerce-expert
  healthcare, y tế     → healthcare-expert
  insurance, bảo hiểm  → insurance-expert
  investment, đầu tư   → investment-expert
  real-estate, BĐS     → real-estate-expert
  education, giáo dục  → education-expert
  legal, pháp lý       → legal-expert
  procurement, thu mua → procurement-expert
  operations, vận hành → operations-expert
  product, sản phẩm    → product-expert
  customer, CX         → customer-expert
  data, analytics      → data-expert
  quality, chất lượng  → quality-excellence-expert
  risk, rủi ro         → enterprise-risk-expert
  strategy, chiến lược → strategy-expert

FALLBACK: Không map được → dùng `business-analyst` làm mặc định.
ALWAYS ADD: `architect` để đánh giá technical impact cross-cutting.
MAX CONCURRENT: 3 experts/lượt spawn (Protocol 7 PAR).
```

### Expert Prompt Template (Phase 1 DEEP)

Mỗi expert spawn dùng prompt template sau — đảm bảo đủ INPUT/OUTPUT/POST-GATE/error handling.

```
Agent(
  subagent_type = "{expert-name}",
  prompt = """
You are analyzing a change request from a domain expert perspective.

CHANGE CONTEXT:
- Change ID: {change_id}
- Change type: {change_type}
- User request: {user_prompt_summary}
- Affected artifacts: {referenced_artifacts list}
- Project maturity: {maturity}

INSTRUCTIONS:
1. Read these files for context:
   - .mc-data/docs/_meta/req-registry.json (project state)
   {docs_paths for referenced artifacts — max 5 paths}

2. Analyze the change from your domain perspective ({domain_name}):
   a. What business impact does this change have in your domain?
   b. What risks or edge cases should be considered?
   c. What dependencies or cross-system impacts exist?
   d. Any compliance or regulatory concerns?

3. Provide your analysis with these REQUIRED sections:
   ## Domain Assessment
   [Your evaluation of the change from {domain_name} perspective]
   ## Risks & Edge Cases
   [List specific risks with severity (HIGH/MEDIUM/LOW)]
   ## Recommendations
   [Your recommendations for safe implementation]
   ## Dependencies
   [Other systems/modules that may be affected]

4. Return format:
   - Status: DONE | DONE_WITH_CONCERNS | BLOCKED
   - If DONE_WITH_CONCERNS: note what is missing
   - If BLOCKED: explain why (no context, contradictory info, etc.)

5. Do NOT modify any files — this is a READ-ONLY analysis.
"""
)
```

**Lưu ý cho Phase 1 orchestrator:**
- Inject `{docs_paths}` từ `$REFERENCED_ARTIFACTS` — chỉ thêm paths tồn tại thực tế.
- Sau mỗi expert response, chạy CORE-029 Spot-Check (Step 1.4b) trước khi aggregate.
- Nếu expert BLOCKED → SKIP + WARNING. Nếu TẤT CẢ BLOCKED → hỏi user chuyển QUICK mode.

---

## Registry Safe-Write Rules (CORE-006)

### Fields được phép UPDATE theo change_type

| `$CHANGE_TYPE` | Fields & Action |
|----------------|-----------------|
| `MODIFY_REQUIREMENT` | `requirements[]` — UPDATE existing (description, acceptance_criteria) |
| `CLARIFY_REQ` | `requirements[]` — APPEND info vào `description/notes/acceptance_criteria`. KHÔNG đổi REQ-ID, KHÔNG đổi dependency. Nếu không có thay đổi cần thiết → SKIP registry update. |
| `ADD_FEATURE` | `features[]` — APPEND new entry |
| `MODIFY_FEATURE` | `features[]` — UPDATE existing. Nếu `impl_status == "done"` VÀ logic thay đổi thật: SET `impl_status = "in_progress"` (KHÔNG là `not_started`), note `"Modified by wf-manage-change $CHANGE_ID"`. Sau Phase 4b: SET `impl_status = "done"` lại. |
| `DELETE_FEATURE` | `features[].impl_status = "skipped"` — yêu cầu CDG (CORE-027) trước khi thực thi |
| `ADD_FEATURE/MODULE` (phụ) | `modules[]` — APPEND new. Các trường hợp phức tạp nên delegate sang `wf-add-scope`. |

### Protocol bắt buộc

1. **ĐỌC registry NGAY TRƯỚC KHI GHI** — không cache từ đầu session
2. **CHỈ MODIFY fields trong danh sách trên** — giữ nguyên mọi fields khác
3. **GHI ATOMIC** — single write operation cho toàn bộ JSON
4. **VALIDATE sau ghi** — `jq '.' req-registry.json` phải pass
5. **BACKUP trước ghi** — `cp req-registry.json req-registry.json.pre-change-$(date +%s)`

---

## Agent Prompt Templates (Phase 5)

### wf-preflight invoke

```
Agent(
  subagent_type = "qa-lead",
  prompt = """
You are executing a scoped preflight check for a managed change.

INSTRUCTIONS:
1. Read .claude/skills/workflow/wf-preflight/SKILL.md for the full preflight procedure.
2. Follow Phase 1-3 checks but scope ONLY to affected files.
   Change context: $CHANGE_ID — [change_summary from change-intake.json]
   Affected files: [code_affected[] from affected-artifacts.json]
   Change type: [change_type]
   Registry backup exists at req-registry.json.pre-change-*
3. Report PASS/WARN/FAIL for each check category.
4. Do NOT modify any files — this is a READ-ONLY check.
"""
)
```

### wf-verify-sync invoke

```
Agent(
  subagent_type = "integration-certifier",
  prompt = """
You are executing a scoped verify-sync for a managed change.

INSTRUCTIONS:
1. Read .claude/skills/workflow/wf-verify-sync/SKILL.md for the full verify-sync procedure.
2. Follow the procedure but scope ONLY to modules changed by this change.
   Affected modules: [modules list from affected-artifacts.json]
   Files modified in Phase 4b: [code_updated[] from change-status.json]
3. Verify REQ-ID → code traceability is maintained for all affected modules.
4. Calculate sync rate for affected scope.
5. Report sync rate and any mismatches.
6. Do NOT modify req-registry.json — this is a READ-ONLY verification.
"""
)
```

---

## Checkpoint Protocol

### Thresholds

| Context Usage | Hành động |
|---------------|-----------|
| < 65% | Tiếp tục bình thường |
| 65-80% | Chuẩn bị checkpoint |
| 80-90% | Lưu checkpoint ngay |
| > 90% | FORCE STOP — checkpoint bắt buộc |

### Khi save checkpoint

1. READ template `templates/checkpoint.json`
2. POPULATE:
   - `checkpoint_id`, `change_id`, `timestamp`, `session_number`
   - `trigger` (reason, context_used_pct, phase_completed)
   - `position` (current_phase, next_phase, next_action)
   - `progress` (phases_completed, docs_updated, code_updated, tests_updated)
   - `context_digest` (change_summary, decisions_made, gotchas)
   - `partial_state` (execute_group_progress nếu đang trong Phase 4)
   - `resume_instructions` (load_files, next_action, user_message)
3. WRITE `$SESSION_DIR/checkpoint.json`
4. Update `change-status.json.checkpoint` (denormalized cache)
5. Update `index.json.sessions[$CHANGE_ID].status = "paused"` (nếu STOP)

---

## Resume Logic & Routing Table

> ⚡ Tách sang `procedures/resume-routing.md` (S5 refactor — G7 fix).
> Xem `procedures/resume-routing.md` để biết đầy đủ: Resume Process (10 steps),
> lock-aware guard, re-bind state variables, Routing Table.

---

## CORE-026/028 Trace & Phase Summary

### CORE-026 Execution Trace

Mọi skill ghi START/COMPLETE/FAIL vào `.mc-data/work/_trace/session-log.json`.

```
START entry (Phase 0 Step 0.0):
  Append JSON entry {
    timestamp, skill: "wf-manage-change", action: "START",
    change_id, user_prompt_summary
  }

COMPLETE entry (Phase 6 POST-GATE):
  Append JSON entry {
    timestamp, skill: "wf-manage-change", action: "COMPLETE",
    change_id, duration_minutes, change_type, files_changed, risk_level
  }

FAIL entry (bất kỳ phase nào FAIL):
  Append JSON entry {
    timestamp, skill: "wf-manage-change", action: "FAIL",
    change_id, current_phase, error_code, error_message
  }

Dry-run COMPLETE:
  Append JSON entry với mode="dry_run", skipped_phases=[4a,4b,4c,5]
```

### CORE-028 Phase Summary

Sau Phase 6 POST-GATE, tạo `$SESSION_DIR/phase-summary.md` — tóm tắt toàn bộ quá trình thay đổi viết bằng **tiếng Việt đơn giản cho non-specialist**.

**Nội dung bắt buộc:**

- Những gì đã thay đổi (mô tả nghiệp vụ, không dùng thuật ngữ kỹ thuật)
- Tại sao cần thay đổi (context từ user prompt)
- Kết quả (PASS/WARN/FAIL từ Phase 5)
- Bước tiếp theo (khuyến nghị cho user)
- Độ dài ≤ 20 dòng, ngôn ngữ tự nhiên

---

## Fix Rules

| Error Type | Auto-Fix Strategy | Escalate If |
|-----------|-------------------|-------------|
| User prompt không rõ | AskUserQuestion làm rõ (tối đa 2 vòng) | User không phản hồi đủ sau 2 lần |
| Change type UNCLEAR | Default MODIFY_FEATURE + DEEP mode, hỏi confirm | — |
| Registry JSON invalid khi đọc | STOP — báo user fix | — |
| Artifact không tìm thấy trong code | WARNING — log + continue | Nhiều artifacts không tìm thấy (>50%) |
| Doc update fail | Retry 3 lần | Vẫn fail sau retry |
| Code update fail (compile error) | Rollback file → retry 1 lần | Vẫn fail |
| Mini-verify fail | Re-check + log | 3+ mini-verify fail liên tiếp |
| Registry update fail | Rollback từ backup → STOP | — |
| Context overflow (>80%) | Lưu checkpoint ngay → STOP — `"Dùng --resume để tiếp tục"` | — |
| Preflight fail sau execute | WARNING — present issues, hỏi user có muốn fix | — |

> **Retry:** Mỗi step retry tối đa 3 lần. Nếu vẫn fail → escalate với thông báo đầy đủ + path tới log.
