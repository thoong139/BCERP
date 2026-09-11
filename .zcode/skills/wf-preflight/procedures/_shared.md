# Shared Protocols — wf-preflight

> Cross-cutting protocols, state variables glossary, scoring formulas, checkpoint save protocol,
> error handling matrix và fix rules được tham chiếu bởi nhiều Phase trong wf-preflight.
> KHÔNG đọc file này standalone — chỉ load section cụ thể khi cần.

## Sections

- [Session Glossary (v3.0+)](#session-glossary-v30)
- [State Variables Glossary](#state-variables-glossary)
- [Cross-Phase Data Flow](#cross-phase-data-flow)
- [Scope Resolution Logic](#scope-resolution-logic)
- [Severity Mapping](#severity-mapping)
- [Scoring Formulas](#scoring-formulas)
- [NULL Redistribution Algorithm](#null-redistribution-algorithm)
- [Verdict Calculation](#verdict-calculation)
- [Checkpoint Save Protocol](#checkpoint-save-protocol)
- [Fix Rules (Skill-specific)](#fix-rules-skill-specific)
- [Error Handling Matrix](#error-handling-matrix)
- [Error Escalation Matrix](#error-escalation-matrix)

---

## Session Glossary (v3.0+)

| Term | Định nghĩa |
|------|-----------|
| **SESSION_ID** | `{YYYY-MM-DD}-{scope-slug}-{NN}` — e.g. `2026-05-03-all-01`, `2026-05-03-sys-erp-02` |
| **SESSION_DIR** | `.mc-data/work/wf-preflight/sessions/$SESSION_ID/` — thư mục cô lập cho một run |
| **scope-slug** | `all` / `sys-{name}` / `mod-{name}` / `feat-{name}` — lowercase, kebab-case |
| **NN** | 2-digit counter `01`-`99`, tăng theo số runs cùng scope cùng ngày |
| **sessions.jsonl** | Append-only index tại `.mc-data/work/wf-preflight/_index/sessions.jsonl`. 2 entries/session: `in_progress` (lúc init) + `completed`/`failed` (lúc kết thúc) |
| **Stale threshold** | 60 phút không heartbeat → lock takeover cho phép (biến: `MCV3_LOCK_STALE_MINUTES`, default 60) |
| **Heartbeat** | pf-heartbeat.sh chạy background, update `.session.lock.heartbeat_at` mỗi 30s |
| **preflight-impact-v1** | Cross-skill artifact: `$SESSION_DIR/preflight-impact.json`. Consumers: `/wf-verify-sync`, `/wf-prepare-deployment`. Schema: `templates/preflight-impact.schema.md` |

**Session file layout:**
```
.mc-data/work/wf-preflight/
├── _index/
│   └── sessions.jsonl              ← 2 entries per session
├── .locks/
│   └── registry.lock               ← Phase 6.1 --fix registry writes
├── sessions/
│   ├── _legacy-v2/                 ← v2 flat data archive (auto-created once)
│   └── {SESSION_ID}/
│       ├── .session.lock           ← acquired in SI.8, released in 7.I
│       ├── preflight-status.json   ← v3 schema
│       ├── preflight-report.md
│       ├── preflight-impact.json   ← Phase 7.E
│       ├── checkpoint.json
│       ├── phase-summary.md        ← Phase 7.8
│       └── file_snapshots/         ← Phase 6 --fix rollback
└── preflight-history.md            ← flat, append-only (giữ path qua các version)
```

---

## State Variables Glossary

Các biến in-memory được set/đọc xuyên suốt skill execution.

| Variable | Set by Phase | Read by Phase | Description |
|----------|--------------|---------------|-------------|
| `$LEGACY_MODE` | Phase 0 (SKILL.md) | 1-7 | Boolean — true nếu `project-context.md > 500 bytes` (CORE-021) |
| `$SCOPE_TYPE` | Phase 1 | 1-7 | `all` / `system` / `module` / `feature` |
| `$SCOPE_NAME` | Phase 1 | 1-7 | ID của system/module/feature khi scope hẹp |
| `$HAS_FIX_FLAG` | Phase 1 | 6, 6.5 | Boolean — true nếu `--fix` |
| `$HAS_RUN_TESTS_FLAG` | Phase 1 | 5a | Boolean — true nếu `--run-tests` |
| `$INTERFACE_TYPE` | Phase 1 | 3 | String — `ui` / `api-only` / `hybrid` — đọc từ `registry.interface_type`. Dùng trong Phase 3 để quyết định check Phase 4 UX docs |
| `$TARGET_SYSTEMS` | Phase 1 | 2, 3, 4, 5, 5b | Array system IDs trong scope |
| `$TARGET_MODULES` | Phase 1 | 2, 3, 4, 5, 5b | Array module IDs trong scope |
| `$TARGET_FEATURES` | Phase 1 | 3, 4, 5, 5b | Array feature IDs trong scope |
| `$TARGET_REQS` | Phase 1 | 2, 4, 5b | Array REQ IDs trong scope |
| `$TECH_STACK` | Phase 1 | 5, 5a | Object — languages/frameworks detected |
| `$REGISTRY_ISSUES` | Phase 2 | 5b, 6, 7 | Array issues từ Registry Integrity check |
| `$DOC_ISSUES` | Phase 3 | 5b, 7 | Array issues từ Docs Completeness check |
| `$SYNC_ISSUES` | Phase 4 | 5b, 6, 7 | Array issues từ Code-REQ Sync check |
| `$QUALITY_ISSUES` | Phase 5 | 5b, 7 | Array issues từ Code Quality check |
| `$TEST_RESULTS` | Phase 5a | 5b, 7 | Object — passed/failed/skipped counts + coverage |
| `$SCORES` | Phases 2-5a | 5b, 6.5, 7 | Object `{registry, docs, sync, quality, test}` |
| `$PRE_FIX_SCORES` | Phase 5b (--fix only) | 6.5 | Snapshot scores TRƯỚC Phase 6 |
| `$POST_FIX_SCORES` | Phase 6.5 | 7 | Snapshot scores SAU fix |
| `$FIX_LOG` | Phase 6 | 6.5, 7 | Array fixes đã apply |
| `$OVERALL_SCORE` | Phase 7 | 7 | Weighted score cuối cùng |
| `$VERDICT` | Phase 7 | 7 | `PASS` / `WARN` / `FAIL` |
| `$CONTEXT_PERCENT` | Every phase | Every phase | Context budget usage — trigger checkpoint at 65/80% (behavioral estimate, không deterministic) |
| `error_log[]` | All phases | Phase 7 | Array errors collected — dùng cho report |

---

## Cross-Phase Data Flow

```
Phase 1 (setup)          → $SCOPE_*, $TARGET_*, $TECH_STACK, preflight-status.json
Phase 2 (registry)   ─┐
                      ├──→ PARALLEL GROUP A → $REGISTRY_ISSUES, $DOC_ISSUES
Phase 3 (docs)       ─┘
Phase 4 (code sync)  ─┐
                      ├──→ PARALLEL GROUP B → $SYNC_ISSUES, $QUALITY_ISSUES
Phase 5 (quality)    ─┘
Phase 5a (tests)     → $TEST_RESULTS                [conditional --run-tests]
Phase 5b (crossval)  → validated issues + $PRE_FIX_SCORES (nếu --fix)
Phase 6 (autofix)    → $FIX_LOG                     [conditional --fix]
Phase 6.5 (rescore)  → $POST_FIX_SCORES             [conditional --fix]
Phase 7 (report)     → preflight-report.md, preflight-status.json, preflight-history.md
```

**Quy tắc:** Mỗi phase chỉ READ variables đã SET ở phase trước. KHÔNG được SET lại variables của phase khác.

---

## Scope Resolution Logic

Dùng trong Phase 1 để resolve scope targets từ `--scope` + `--name`.

```
IF --scope == "all":
  target_systems  = registry.systems[*].id
  target_modules  = registry.modules[*].id
  target_features = registry.features[*].id
  target_reqs     = registry.requirements[*].id

ELIF --scope == "system":
  VALIDATE --name exists in registry.systems[*].id → nếu không: STOP + list valid system IDs
  target_systems  = [--name]
  target_modules  = registry.modules[? system_id == --name].id
  target_features = registry.features[? module_id IN target_modules].id

  # Resolve target_reqs: ưu tiên system_id field trước, fallback sang prefix
  IF registry.requirements[].system_id field tồn tại:
    target_reqs = registry.requirements[? system_id == --name].id
  ELIF system.prefix tồn tại AND system.prefix != null AND system.prefix != "":
    target_reqs = registry.requirements[? id STARTS WITH system.prefix].id
  ELSE:
    # Không có prefix hoặc system_id field → fallback scan toàn bộ requirements
    # và filter theo modules thuộc system này
    target_reqs = registry.requirements[? module_id IN target_modules].id
    LOG WARNING "system.prefix absent for [--name] — resolved reqs via module_id fallback"

ELIF --scope == "module":
  VALIDATE --name exists in registry.modules[*].id → nếu không: STOP + list valid module IDs
  target_modules  = [--name]
  target_features = registry.features[? module_id == --name].id
  target_reqs     = registry.requirements[? module_id == --name].id

ELIF --scope == "feature":
  VALIDATE --name exists in registry.features[*].id → nếu không: STOP + list valid feature IDs
  target_features = [--name]
  target_reqs     = feature.req_ids (nếu có) hoặc []
```

**Kiểm tra đặc biệt:** Nếu scope hẹp nhưng `--name` không được cung cấp → STOP với thông báo:

```
Thiếu --name. Ví dụ:
  /wf-preflight --scope=system --name=SYS-ERP
  /wf-preflight --scope=module --name=MOD-ERP-FIN

Các IDs hợp lệ trong registry:
  Systems:  SYS-WEB, SYS-ERP, SYS-CORE, ...
  Modules:  (chạy /wf-preflight --scope=all để xem đầy đủ)
```

---

## Severity Mapping

### Registry issues (Phase 2)

| Issue | Severity |
|-------|---------|
| JSON invalid / missing required fields | CRITICAL |
| Duplicate IDs | CRITICAL |
| Invalid ID format | HIGH |
| Dangling cross-reference | HIGH |
| Invalid status value | MEDIUM |

### Code Quality issues (Phase 5)

| Severity | Loại lỗi | Impact |
|----------|----------|--------|
| CRITICAL | Compile errors, type errors (blocking) | Verdict FAIL |
| HIGH | Lint errors (error level) | Verdict WARN |
| MEDIUM | Lint warnings | INFO only |

---

## Scoring Formulas

### registry_score (Phase 2)

```
registry_score = max(0, 100 - (CRITICAL×30 + HIGH×15 + MEDIUM×5))

Ví dụ:
  0 issues                         → 100
  1 CRITICAL                       → max(0, 100-30) = 70
  1 CRITICAL + 2 HIGH              → max(0, 100-30-30) = 40
  2 CRITICAL + 1 HIGH + 3 MEDIUM   → max(0, 100-60-15-15) = 10
```

### docs_score (Phase 3)

```
docs_score = (existing_required_docs / total_required_docs) × 100

Ví dụ:
  10/10 docs present → 100
  7/10 docs present  → 70
  3/10 docs present  → 30
```

### sync_score (Phase 4)

```
reqs_expected_in_code = target_reqs WHERE impl_status IN ("done", "in_progress")
  (KHÔNG đếm "not_started" — chưa implement là đúng trạng thái)
  (impl_status = "skipped" → KHÔNG expected in code, KHÔNG tính vào denominator)
reqs_found_in_code   = reqs_expected_in_code WHERE code file chứa REQ-ID

sync_score = (reqs_found_in_code / reqs_expected_in_code) × 100

NULL cases:
  Case 1: Không có src/ hoặc apps/ → PRE-GATE skip → sync_score = null
  Case 2: reqs_expected_in_code == 0 (tất cả REQ là not_started hoặc skipped)
          → sync_score = null (không có REQ nào cần check)

Lý do: REQ "not_started" mà không có code KHÔNG phải lỗi sync.
REQ "skipped" (deprecated) cũng KHÔNG phải lỗi sync.
Chỉ REQ "done"/"in_progress" mà không tìm thấy trong code mới là gap thực sự.

Ví dụ:
  10 REQs done/in_progress, 8 tìm thấy → 80%
  5 REQs done/in_progress, 5 tìm thấy  → 100%
  0 REQs done/in_progress               → null (case 2)
```

### quality_score (Phase 5)

```
IF không có tooling nào khả dụng (E005) → quality_score = null
  (null = skip hợp lệ → redistribute weight sang phase khác)
  ⚠️ KHÔNG set quality_score = 100 khi skip — 100 nghĩa là "đã check, không có lỗi"

IF CRITICAL errors > 0 → quality_score = 0
ELIF HIGH errors > 0   → quality_score = 50
ELIF có warnings > 0   → quality_score = 80
ELSE (clean run)       → quality_score = 100

Ví dụ:
  Không có node/npm (E005)    → null (redistribute)
  2 compile errors (CRITICAL) → 0
  1 lint error (HIGH)         → 50
  3 lint warnings (MEDIUM)    → 80
  Clean run                   → 100
```

### test_score (Phase 5a)

```
test_score = (passed / (passed + failed)) × 100

NOTE: test_score là BONUS — KHÔNG tính vào overall_score weighted average.
Hiển thị riêng trong report. null nếu không chạy.
```

---

## NULL Redistribution Algorithm

Áp dụng khi tính `overall_score` (Phase 7) hoặc re-score (Phase 6.5).

```
Base weights:
  registry_score × 0.20
  docs_score     × 0.25
  sync_score     × 0.30
  quality_score  × 0.25

IF any score = null:
  remaining_weights = sum(weights của non-null scores)
  FOR each non-null score:
    adjusted_weight = weight / remaining_weights
  overall_score = sum(score × adjusted_weight)

Ví dụ 1 — quality_score = null (E005: no tooling):
  remaining = 0.20 + 0.25 + 0.30 = 0.75
  registry_adj = 0.20/0.75 = 0.267
  docs_adj     = 0.25/0.75 = 0.333
  sync_adj     = 0.30/0.75 = 0.400
  overall = registry×0.267 + docs×0.333 + sync×0.400

Ví dụ 2 — sync_score = null + quality_score = null:
  remaining = 0.20 + 0.25 = 0.45
  registry_adj = 0.20/0.45 = 0.444
  docs_adj     = 0.25/0.45 = 0.556
  overall = registry×0.444 + docs×0.556
```

---

## Verdict Calculation

**Thứ tự ưu tiên (priority order — áp dụng tuần tự từ trên xuống, dừng khi match):**

```
1. FAIL   ← overall_score < 60% HOẶC có bất kỳ CRITICAL issue nào
2. WARN   ← overall_score 60-79% HOẶC có HIGH severity issues
3. PASS   ← overall_score >= 80% VÀ không có CRITICAL VÀ không có HIGH issues
```

**Tie-breaking rule:** FAIL > WARN > PASS — nếu score 80%+ nhưng có HIGH issue → kết quả là WARN (không phải PASS). WARN luôn takes precedence over PASS.

**Bổ sung: test_score force-WARN**
```
IF test_score < 50% (khi $HAS_RUN_TESTS_FLAG = true VÀ test_score không null):
  → force verdict ≥ WARN, ngay cả khi overall_score >= 80% và không có HIGH issues
  → ghi reason "Test failure rate cao (test_score < 50%) — code có thể bị broken"
  → KHÔNG force FAIL nếu chưa có CRITICAL issues (nhưng luôn block PASS)
```

**Coverage disclaimer:**
```
IF số dimensions có giá trị (non-null) < 2:
  → Thêm NOTE vào report: "⚠️ Chưa đủ coverage: chỉ [N]/4 dimension(s) được đo. Verdict không phản ánh toàn bộ health."
IF sync_score = null VÀ quality_score = null (không có code nào được check):
  → Thêm NOTE: "⚠️ Code chưa được kiểm tra (không có src/ hoặc tooling). PASS/WARN chỉ phản ánh registry và docs."
```

---

## Checkpoint Save Protocol

> Template: `templates/checkpoint.json`

```
KHI NÀO lưu checkpoint:
  1. Context usage > 80%          → FORCE checkpoint
  2. TRƯỚC Phase 6 (--fix)        → BẮT BUỘC (để rollback nếu fix gây lỗi mới)
  3. Sau mỗi parallel group xong  → BEST-EFFORT (Group A, Group B)

CÁCH lưu:
  1. READ templates/checkpoint.json
  2. POPULATE:
     - session_id: $SESSION_ID  (v3.0+ — thêm trường này)
     - trigger: reason + context_used_pct
     - position: current_phase + next_action
     - progress: phases_completed + parallel groups done + issues_found
     - partial_state:
       * scores_snapshot: registry_score, docs_score, sync_score, quality_score, test_score
       * issues_snapshot: registry_issues[], doc_issues[], sync_issues[], quality_issues[] (ALL 4 arrays)
       * fix_state: pre_fix_scores, fixes_applied[], fix_log[]
       * file_snapshots: { "<file_path>": "<original_content>" } (chỉ khi trigger = "pre_fix" — bắt buộc cho E010 rollback)
     - context_summary: scope_type, scope_name, fix_flag, run_tests_flag, interface_type, target_counts
     - resume_instructions: load_files + resume_from_phase + state_restore_steps + user_message
  3. WRITE $SESSION_DIR/checkpoint.json

TRẠNG THÁI RESTORE KHI RESUME:
  Khi resume từ checkpoint, PHẢI rebuild in-memory state:
  1. Đọc $SESSION_DIR/checkpoint.json
  2. Đọc partial_state.scores_snapshot → gán lại $SCORES
  3. Đọc partial_state.issues_snapshot → gán lại $REGISTRY_ISSUES, $DOC_ISSUES, $SYNC_ISSUES, $QUALITY_ISSUES
  4. Đọc context_summary.scope_type/scope_name/interface_type → gán lại $SCOPE_TYPE, $SCOPE_NAME, $INTERFACE_TYPE
  5. Re-resolve $TARGET_* từ registry (đọc lại req-registry.json) — KHÔNG dùng cached targets vì registry có thể đã thay đổi
  6. Đọc position.next_action → tiếp tục từ đó

VERIFY sau ghi: test -s $SESSION_DIR/checkpoint.json
```

---

## Fix Rules (Skill-specific)

| Error Type                                   | Auto-Fix Strategy                                             | Escalate If                                 |
| -------------------------------------------- | ------------------------------------------------------------- | ------------------------------------------- |
| `registry_json_invalid`                      | Fix syntax error                                              | Structure corruption không parse được       |
| `orphan_code_file` (service/controller)      | **HIGH** — Thêm REQ-ID comment (chỉ khi `--fix`)              | Không xác định được REQ-ID phù hợp          |
| `orphan_code_file` (utility/helper/shared)   | **MEDIUM** — Thêm REQ-ID comment (chỉ khi `--fix`)            | Utility files có thể chung nhiều REQ        |
| `id_format_error`                            | Chuẩn hóa format → `REQ-[DEPT]-[NNN]`                         | ID ambiguous                                |
| `missing_doc`                                | Log + link skill tạo doc                                      | Không auto-create (quá phức tạp)            |
| `test_failure`                               | Log chi tiết                                                  | Always escalate — không auto-fix code       |
| `type_error`                                 | Log chi tiết                                                  | Always escalate — không auto-fix code       |
| `duplicate_id`                               | Cảnh báo, KHÔNG tự remove                                     | User phải quyết định                        |
| `stale_impl_status`                          | Không tự downgrade "done"                                     | Always escalate                             |

---

## Error Handling Matrix

> **Execution Trace (CORE-026):** Mọi START/COMPLETE/FAIL event ghi vào `.mc-data/work/_trace/session-log.json` (output-only observability). Xem Phase 1 step 1.8 (START) và Phase 7 steps 7.8-7.9 (COMPLETE/FAIL).

| Code | Tình huống                                                           | Xử lý                                                   |
| ---- | -------------------------------------------------------------------- | ------------------------------------------------------- |
| E001 | `req-registry.json` không tồn tại                                    | STOP → chạy `/wf-brainstorm` trước                      |
| E002 | Registry JSON hoàn toàn invalid (không parse được)                   | STOP → hướng dẫn fix JSON syntax                        |
| E003 | `--scope` có `--name` nhưng ID không tồn tại trong registry          | STOP → liệt kê valid IDs                                |
| E004 | `--scope` hẹp nhưng không có `--name`                                | STOP → hướng dẫn thêm `--name`                          |
| E005 | Code tool không tồn tại (không có `node`, `npm`, etc.)               | Skip Phase 5, log WARNING "Tooling not found", set quality_score = null |
| E006 | Tests chạy quá 5 phút                                                | FORCE STOP tests + log WARNING "Timeout exceeded"       |
| E007 | File read errors                                                     | Log warning, tiếp tục với data có sẵn                   |
| E008 | Context > 90% (behavioral estimate)                                  | FORCE checkpoint → `--resume` để tiếp tục               |
| E009 | POST-GATE fail sau 3 retries                                         | STOP phase, escalate to user với báo cáo chi tiết       |
| E010 | `--fix` gây ra lỗi mới trong file                                    | Rollback file từ `file_snapshots` trong checkpoint, log "Fix regression", escalate |
| E011 | Không chạy từ project root (không có `.mc-data/`)                    | Phase 0 PRE-GATE fail → yêu cầu `cd` đến project root  |
| E012 | Scope = all nhưng registry trống (0 systems/modules)                 | WARN + NOTE "Registry empty — chạy /wf-analyze-requirements", tiếp tục với degraded checks |
| E013 | Test runner exit code ≠ 0 nhưng không có readable output             | Log raw output, mark as FAIL                            |
| E014 | `jq` không được cài đặt trên hệ thống                               | STOP tại Phase 0 PRE-GATE → "jq là required dependency. Cài đặt: brew install jq / apt install jq / choco install jq" |

---

## Error Escalation Matrix

| Error Code | Xử lý | Ghi chú |
|------------|-------|---------|
| E001–E004, E014 | **STOP** (hard gate) | Điều kiện không thể tiếp tục |
| E005–E007  | **LOG WARNING** + continue với degraded checks | null scores, redistribute weight |
| E008       | **FORCE checkpoint** (token limit approaching) | Dùng `--resume` để tiếp tục |
| E009–E010  | **Log** + append to report, escalate to user sau khi hoàn thành | Không block execution |
| E011       | **STOP** tại Phase 0 PRE-GATE | Detect bằng `test -d .mc-data/` — nếu không tìm thấy → E011 |
| E012       | **LOG WARNING** + continue | Set registry_score thấp, docs_score tính với denominator = 0 (special case) |
| E013       | **LOG** + mark test phase as error | Test runner broken, không phải code logic fail |
