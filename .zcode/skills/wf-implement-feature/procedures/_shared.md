# Shared Protocols & Agent Contexts — wf-implement-feature

> Cross-cutting protocols, agent contexts, và reference data dùng bởi nhiều Phase.
> KHÔNG đọc file này standalone — chỉ load section cụ thể khi cần.

## Sections

- [Protocol References](#protocol-references)
- [Retry & Fix Rules](#retry--fix-rules)
- [Template Usage Rule (CORE-031)](#template-usage-rule-core-031)
- [Registry Safe-Write (CORE-006)](#registry-safe-write-core-006)
- [Agent Context: Developer](#agent-context-developer)
- [Agent Context: Code Reviewer](#agent-context-code-reviewer)
- [Agent Context: QA Lead](#agent-context-qa-lead)
- [Agent Context: API Tester](#agent-context-api-tester)
- [Agent Context: Security](#agent-context-security)
- [Agent Context: Architect (Contracts)](#agent-context-architect-contracts)
- [Error Codes Reference](#error-codes-reference)
- [Execution Flow Between Phase Files](#execution-flow-between-phase-files)

---

## Protocol References

Toàn bộ protocol definitions nằm trong `.claude/skills/protocols/`.
Phase files chỉ nêu tên protocol + section áp dụng — KHÔNG duplicate logic.

| Protocol | Mục đích | Sử dụng ở |
|----------|---------|-----------|
| Protocol 3 | Context & Checkpoint + Digest (threshold 65/80/90%) | Phase 3.4, Phase 1 (resume) |
| Protocol 6 | Token Limit Prevention (>3 input files → pre-compress) | Phase 3.0.0 |
| Protocol 7 (PAR-09) | Multi-feature parallel khi không share source files | flow-multi.md |
| Protocol 8 (CQG-11) | REQ-ID match + test coverage ratio + architecture compliance | Phase 5a |
| Protocol 9 (PLN-10) | Token estimates + proactive budget check (9.6) | Phase 2, Phase 3.0.B |
| Protocol 10 | POST-GATE Schema Validation (T1→T4) | Mọi POST-GATE |
| Protocol 12 | Decision Registry (conflict check + append) | Phase 0.5b, Phase 3.5, Phase 5a.D |
| Protocol 13 | Test Gates (GATE-13 — tests PHẢI PASS trước khi tiếp tục) | Phase 3.4 |

---

## Retry & Fix Rules

| Loại lỗi | Auto-Fix | Escalate nếu |
|-----------|----------|---------------|
| File thiếu/rỗng | Tạo từ template / re-run | Không đủ context / vẫn rỗng |
| REQ-ID thiếu | Thêm REQ-ID comment | Không xác định vị trí |
| Tests fail | Re-run, fix nếu rõ | Logic error cần user |
| JSON invalid | Fix syntax | Structure corruption |
| Missing test | Tạo test stub | Complex logic cần user |

**Retry cap:** Mỗi step retry tối đa 3 lần. Nếu vẫn fail → escalate với thông báo đầy đủ.

---

## Template Usage Rule (CORE-031)

Mọi output file PHẢI theo quy trình: **READ template → POPULATE data → WRITE output**.

| Output | Template |
|--------|----------|
| `existing-patterns.json` | `templates/existing-patterns.json` |
| `impl-status.json` | `templates/impl-status.json` |
| `impl-plan.md` | `templates/impl-plan.md` |
| `checkpoint.json` | `templates/checkpoint.json` |
| `qa-review-attempt-[N].md` (default) | `templates/qa-review-report.md` |
| `qa-review-attempt-[N].md` (annotation_only batch) | `templates/qa-review-report-annotation.md` (Finding #23 — adaptive) |
| `decision-registry.json` | `templates/decision-registry.json` |
| `impl-report.md` | `templates/impl-report.md` |

Phase files dùng chú thích `**[Template Rule]** READ templates/...` khi load template.

---

## Registry Safe-Write (CORE-006)

- CHỈ MODIFY field `impl_status` per REQ-ID (khi skill này ghi registry — Phase 6)
- Đọc registry NGAY TRƯỚC KHI GHI (không cache)
- GHI ATOMIC (single write operation)
- VALIDATE sau ghi: `jq '.' req-registry.json` phải pass
- KHÔNG downgrade `impl_status` từ "done" → giá trị khác

`feature.req_id` trong `impl-status.json` PHẢI chỉ chứa REQ-ID của feature đang implement
(từ registry `features[].req_id`). KHÔNG bao gồm REQ-IDs của features khác trong cùng module.

### Cross-Process Mutex (v4.0 — delegated to bash)

> **Lý do:** User có thể mở nhiều phiên Claude Code chạy `/wf-implement-feature` song song.
> Nếu 2 sessions cùng đọc-rồi-ghi `req-registry.json` → race condition → lost write.
>
> **v4.0:** Mutex logic delegated to `implement-acquire-lock.sh`. SKILL.md inline ~50 dòng → 2 dòng call.

**Mutex protocol — áp dụng cho MỌI registry write operation trong Phase 6:**

```bash
# Acquire registry mutex (timeout 30s, stale > 5min)
LOCK_FILE=$(bash .claude/scripts/wf-implement-feature/implement-acquire-lock.sh \
  --type=registry --timeout=30) || {
  echo "ERROR: Registry lock timeout — kiểm tra session khác đang giữ" >&2
  exit 1
}
trap "rm -f .mc-data/docs/_meta/.registry.lock" EXIT

# ... narrow per-field jq update ...
# ... atomic mv ...

# Release ngay sau khi mv (KHÔNG giữ lock qua I/O không cần thiết)
rm -f .mc-data/docs/_meta/.registry.lock
trap - EXIT
```

Script handle: atomic create với `set -C`, stale detection (PID dead OR age > 5min cho registry / 60min cho feature), cross-host detection. Xem `.claude/scripts/wf-implement-feature/implement-acquire-lock.sh`.

**QUY TẮC:**
1. MỌI Phase 6 Step 6.1 (registry update) PHẢI acquire lock TRƯỚC khi đọc registry
2. PHẢI release lock ngay sau khi mv tmp → registry.json (KHÔNG giữ lock qua I/O không cần thiết)
3. Stale detection (script handle automatically) — tránh deadlock khi process crash
4. Cùng pattern áp dụng cho `decision-registry.json` (`--type=decision-registry`)
5. `_trace/session-log.json` append KHÔNG cần lock — single-line entry < 4KB là atomic POSIX write
6. Multi-feature mode (`--features`) đã có orchestrator-only sequential write — orchestrator vẫn dùng lock để safe với external sessions

---

## Agent Context: Developer

Dùng ở Phase 3 (TDD) — spawn `developer` / `frontend-developer` / `mobile-developer` tùy project type.

```
Bạn là Developer. Implement feature [FEATURE_NAME] theo TDD approach.

**[PHIÊN 7 - A6-EXT FIRST]**
IF $EXECUTABLE_SPEC không rỗng AND $A6_EXT_STATE == "complete":
  ĐỌC A6-EXT TRƯỚC (file paths, REQ-IDs, imports, method signatures, test cases, error handling).
  KHÔNG đọc Phase 1-3 docs liên tiếp — chỉ đọc full files khi A6-EXT không đủ chi tiết.
  $EXECUTABLE_SPEC: [FULL A6-EXT CONTENT]
ELIF $A6_EXT_STATE == "stub" OR "absent":
  Fallback: Đọc A1-A6 sections từ task file + Phase 1-3 design docs bình thường.
  WARNING vào output: "A6-EXT là [stub/absent] — fallback đến full docs (chậm hơn). Đề xuất: chạy phase2-4-populate-spec lần tới."

**[PARTIAL-FIX STATE — Finding #9]**
IF $ANNOTATION_STATE_PER_FILE non-empty:
  Mỗi file trong batch có thể có annotation HIỆN TẠI khác nhau (do partial-fix lịch sử).
  Sử dụng map sau để biết từng file cần đổi từ gì sang gì:
  $ANNOTATION_STATE_PER_FILE: [JSON map]
  KHÔNG assume tất cả files có cùng annotation cũ — verify per file trước khi edit.

**[EDGE CASE HANDLING — Finding #21]**
- ARCHITECTURAL decision (new pattern, new dep, new config): ghi "NEW DECISION: [category] — [rule] — vì [reason]"
- MINOR ambiguity (cleanup, naming, format): auto-decide với conservative default + log "AUTO-DECIDED: [decision] — vì [reason]"
- SCOPE-CHANGING decision (modify out-of-scope file): KHÔNG decide, ESCALATE với note "OUT-OF-SCOPE: [file] — [reason]"

**[REQ-ID Annotation Rules — Finding #19, #20]**
- Header (top of file): EXACTLY 2 dòng `// REQ-ID: REQ-XXX-NNN` + `// FEAT-ID: FEAT-XXX-NNN` (mỗi cái 1 dòng)
- Duplicate header lines (e.g. 2x `// REQ-ID:`, hoặc `// REQ-ID: null` thừa): NORMALIZE → giữ 1 đúng, xóa duplicate/invalid
- REQ-ID value invalid (`null`, `undefined`, `[REQ-XXX]`, empty string): treat as missing → fix về REQ-ID đúng từ registry
- Section dividers/inline references (e.g. `─── Module — FEAT-ID ───`): PRESERVE unchanged trong annotation-only batches; có thể cleanup trong logic_change batches

[C2 - Decision Registry] Quy tắc bắt buộc:
[constraint_list — ví dụ:
  D001: Tất cả deletions là soft delete (thêm deleted_at column)
  D002: UUID v4 cho tất cả primary keys
  D003: Response envelope { data, meta, errors }]

[C1 - Design Context] Architecture summary (CHỈ khi A6-EXT không đầy đủ):
[$DESIGN_SUMMARY hoặc input digest từ api-contract + database-design + integration-map]

Batch: [M] of [N] — Tasks: [TASK_LIST_FOR_BATCH]
Scenario: [NEW/EXTEND/MODIFY]

Tasks:
1. RED: Viết failing test cho mỗi task trong batch
2. GREEN: Viết minimal code để pass test
3. REFACTOR: Clean up, xóa duplication, cải thiện naming
4. Thêm REQ-ID comment vào MỌI source file: `// REQ-ID: [REQ_ID]`
5. Tuân thủ existing patterns từ existing-patterns.json
6. Khi phát hiện quyết định kiến trúc mới → ghi cuối output: "NEW DECISION: [category] — [rule] — vì [reason]"

Output: Source files + test files
Quality: Tests pass, REQ-ID present, no TODO/FIXME, follows conventions, Decision Registry respected
Output mục tiêu: ~500–1500 từ code + comments per batch.
```

### Agent Selection Table

| Điều kiện | Agent | Lý do |
|-----------|-------|-------|
| Default (backend, fullstack) | `developer` | Agent coding chính |
| Frontend-heavy (React/Vue/Angular) | `frontend-developer` | Chuyên frontend patterns |
| Mobile app (iOS/Android/RN/Flutter) | `mobile-developer` | Chuyên mobile platform APIs |
| AI/ML features | `developer` + `model-qa` (optional) | Developer viết code, model-qa validate pipeline |

---

## Agent Context: Code Reviewer

Dùng ở Phase 4 — spawn parallel với qa-lead + security (theo adaptive routing — xem §Phase 4 Adaptive Agent Spawning).

```
Bạn là Code Reviewer. Code Review chi tiết cho feature [FEATURE_NAME]. Attempt: [N] of 3.
Batch type: [annotation_only | logic_change | new_files] — xem §Batch Type Classification.

Tasks (áp dụng theo batch type):
1. Review code quality: naming, structure, DRY, SOLID, clean code
   → SKIP nếu batch_type == annotation_only
2. Review patterns: consistency với existing-patterns.json, anti-patterns detection
3. Verify REQ-ID tracking: mỗi source file có REQ-ID comment đúng format
4. Check coding conventions theo project rules
5. Import style consistency: ES module vs CommonJS — phải dùng cùng một style
   → SKIP nếu batch_type == annotation_only

**Verification techniques theo batch type (BẮT BUỘC v3.3+ — Finding #24):**
- annotation_only: dùng `git diff --stat HEAD -- [files]` để verify size delta
  ngắn (< 5 lines/file). Đọc 10 dòng đầu mỗi file thay vì full file.
- logic_change: read full file + check tests pass + diff sized review
- new_files: read template compliance + REQ-ID present + structure check

**Broad-scan dirty artifacts (BẮT BUỘC v3.3+ — Finding #22):**
SAU khi review batch chính, BROAD-SCAN cùng app cho similar artifacts:
- Annotation batch: grep `// REQ-ID: null`, `// REQ-ID: \[`, `// REQ-ID: TBD` trong cùng module/app
- Logic batch: grep `TODO`, `FIXME`, `XXX` còn lại trong scope module
- Báo cáo: số count + file list (max 20 entries) + suggest follow-up batch

Output: STRUCTURED theo template `templates/qa-review-report.md`
  - Verdict: PASS hoặc NEEDS WORK
  - Issues: Danh sách với severity (CRITICAL/HIGH/MEDIUM/LOW)
  - Mỗi issue: file:line, description, expected, actual, fix instruction
  - **Section "Out-of-scope dirty state"** (mới — v3.3+): list artifacts found in broad-scan
Output mục tiêu:
  - annotation_only: ~300-500 từ (focused, không cần full review)
  - logic_change: ~500-1000 từ
  - new_files: ~600-1200 từ
```

### Batch Type Classification

Skill caller (Phase 4 step 4.0) PHẢI classify batch type trước khi spawn:

| Batch type | Detection rule |
|------------|----------------|
| `annotation_only` | Tất cả changes trong git diff đều thuộc dòng comment có pattern `// (REQ-ID\|FEAT-ID):` |
| `logic_change` | Có changes trong code (function bodies, exports, imports) |
| `new_files` | ≥1 file mới được tạo (status A trong git diff) |
| `mixed` | Combination — fall back to `logic_change` (most strict) |

---

## Agent Context: QA Lead

```
Bạn là QA Lead. Test Coverage & Quality Review cho [FEATURE_NAME]. Attempt: [N] of 3.
Tasks:
1. Review test coverage: edge cases, error paths, boundary conditions
2. Verify test quality: assertions meaningful, no false positives
3. Check integration points: API contracts, data flow consistency
4. Validate acceptance criteria: feature design requirements met
Output: STRUCTURED theo template `templates/qa-review-report.md`
Output mục tiêu: ~500–1000 từ. Focus test gaps và acceptance criteria.
```

---

## Agent Context: API Tester

Conditional — chỉ khi feature có API endpoints.

```
Bạn là API Tester. API Testing cho [FEATURE_NAME]. Attempt: [N] of 3.
Tasks:
1. Contract testing: endpoints match API contract specification
2. Input validation: boundary values, invalid inputs, empty payloads
3. Error responses: correct HTTP status codes, error format consistency
4. Integration testing: data flow between API endpoints
Output: STRUCTURED theo template `templates/qa-review-report.md`
Output mục tiêu: ~500–1000 từ. Focus contract mismatches và edge cases.
```

---

## Agent Context: Security

```
Bạn là Security Engineer. Security Review cho [FEATURE_NAME]. Attempt: [N] of 3.
Tasks:
1. OWASP Top 10: injection, XSS, CSRF, auth bypass, SSRF
2. Input validation: sanitization, type checking, boundary checks
3. Data protection: sensitive data exposure, encryption, logging
4. Access control: authorization checks, privilege escalation
Output: STRUCTURED theo template `templates/qa-review-report.md`
  - Issues severity: CRITICAL/SECURITY/HIGH/MEDIUM/LOW
  - Mỗi issue: file:line, description, expected, actual, fix instruction, CWE reference nếu có
Output mục tiêu: ~300–800 từ. Focus vulnerabilities found.
```

---

## Agent Context: Architect (Contracts)

Chỉ dùng ở Phase 2.5 (--parallel mode).

```
Bạn là Architect. Tạo implementation contracts cho feature [FEATURE_NAME].
Nhiệm vụ: Đọc feature design + Phase 3 API contract + DB schema → tạo 4 files.
Contracts PHẢI: đầy đủ, rõ ràng, ổn định (immutable), consistent với Phase 3.
Mỗi file PHẢI có REQ-ID reference + named exports + TypeScript annotations.
Nếu phát hiện gap → ghi "CONTRACT_GAP: [description]" → escalate.
Output mục tiêu: ~200-500 dòng/file.
```

---

## Error Codes Reference (v4.0+ namespaced)

> **v4.0 Sprint 4:** Error codes đổi sang namespace E1xx-E9xx theo phase. File `error-ledger.json` per-session dùng namespaced code. Backward compat: bảng alias bên dưới ánh xạ E001-E014 (v3.x) → mã mới.

### Namespace

| Range | Phase | Examples |
|-------|-------|----------|
| E1xx | Phase 1 (context, registry, pattern scan) | E101 (cache miss), E102 (registry inconsistent / not found / re-run), E103 (req-id not found) |
| E2xx | Phase 2 (planning, populate-spec, contracts) | E201 (task file missing), E202 (A6-EXT stub / feature design missing), E203 (task list gen failed), E204 (A6-EXT populate failed) |
| E3xx | Phase 3 (TDD, test gate, decisions) | E301 (test gate fail), E302 (decision conflict), E303 (source file gen failed), E304 (REQ-ID missing), E305 (auto-fix regression) |
| E4xx | Phase 4 (review) | E401 (agent timeout), E402 (critical/security issues unfixed) |
| E5xx | Phase 5a (cross-validation) | E501 (validation auto-correction loop > 3) |
| E6xx | Phase 6 (registry write, finalize) | E601 (registry mutex timeout), E602 (POST-GATE T1-T4 fail) |
| E9xx | Cross-cutting | E901 (per-feature lock busy / session lifecycle), E902 (history index append fail), E904 (error-ledger truncated) |

### Severity → Action

| Severity | Behavior |
|----------|----------|
| `info` | Log only, no user notification |
| `warning` | Log + display in `phase-summary.md` Errors & Warnings section |
| `error` | Log + retry up to 3 times, then escalate |
| `critical` | Log + immediate escalate (no retry) |

### Code reference (namespaced)

| Code | Tình huống | Xử lý |
|------|------------|-------|
| E101 | Pattern cache miss / pattern scan failed | Full scan triggered (auto-resolve) |
| E102 | `req-registry.json` không tìm thấy hoặc inconsistent / re-run không có flag | Chạy `/wf-analyze-requirements` hoặc hỏi scenario EXTEND/MODIFY |
| E103 | Không xác định được feature/REQ-ID (thiếu name hoặc lookup fail) | Hỏi user / Retry Phase 1 |
| E201 | Task file không tồn tại | Xem `phase1-feature-context.md` Step 1.6 — tự generate stub hoặc chạy `/wf-plan-modules` |
| E202 | Feature design không tồn tại / A6-EXT stub detected | Chạy `/wf-design` trước, hoặc populate spec |
| E203 | Task list generation failed | Retry Phase 2 |
| E204 | A6-EXT populate failed | Retry Phase 2.4 với context, hoặc fallback to A6 (full file) |
| E301 | Tests failing (test gate fail) | Debug và fix → retry up to 3 attempts |
| E302 | Decision conflict (Protocol 12) | Resolve theo precedence rule, escalate nếu cross-feature |
| E303 | Source file không tạo được | Retry với error context |
| E304 | Thiếu REQ-ID trong source code | Thêm REQ-ID comment |
| E305 | Auto-fix gây regression | Rollback fix → escalate with context |
| E401 | Agent timeout trong Phase 4 | Retry 1 lần. Vẫn timeout → skip agent đó, log warning, tiếp tục với agents còn lại. |
| E402 | Critical/Security issues từ review | Fix trong Review-Fix Loop (max 3 attempts) → escalate |
| E501 | Cross-validation auto-correction loop > 3 | STOP — escalate với context auto-correction history |
| E601 | Registry mutex timeout | Kiểm tra session khác đang giữ lock — wait hoặc force release nếu stale |
| E602 | POST-GATE T1-T4 fail sau 3 retries | STOP — báo cáo chi tiết → user quyết định |
| E901 | Per-feature lock busy / session lifecycle (fresh archive) | Wait, hoặc xóa impl-status.json, impl-plan.md, checkpoint.json trong $SESSION_DIR |
| E902 | History index append fail | Retry với atomic write, escalate nếu disk full |
| E904 | error-ledger.json truncated (>100 entries) | Auto-resolve (warning only) |

### Backward Compatibility (v3.x → v4.0)

| Old (v3.x) | New (v4.0) | Description |
|-----------|-----------|-------------|
| E001 | E103 | Missing feature name / REQ-ID |
| E002 | E102 | `req-registry.json` không tìm thấy |
| E003 | E103 | Không xác định được feature/REQ-ID |
| E004a | E202 | Feature design không tồn tại |
| E004b | E201 | Task file không tồn tại |
| E005 | E203 | Task list generation failed |
| E006 | E303 | Source file creation failed |
| E007 | E304 | REQ-ID missing |
| E008 | E301 | Tests failing |
| E009 | E402 | Critical/Security issues |
| E010 | E401 | Agent timeout |
| E011 | E602 | POST-GATE fail |
| E012 | E305 | Auto-fix regression |
| E013 | E901 | Session lifecycle (fresh) |
| E014 | E102 | Re-run without flag |
| E015 | E204 | A6-EXT populate failed |

Skill code uses NEW codes (E1xx-E9xx). User-facing messages reference both for clarity:
> "Error E301 (was E008): Tests failing"

Helper: `ledger_log` trong `implement-common.sh` (Sprint 4) — dùng để append entries vào `error-ledger.json` per-session. Lazy-init: file chỉ tạo lần đầu khi có error đầu tiên.

---

## Execution Flow Between Phase Files

Thứ tự load phase files từ SKILL.md Phase 0 orchestration:

```
SKILL.md Phase 0 (session-log START, FLAG parsing, FEATURE_SLUG derivation, LEGACY_MODE detect)
  ↓
  IF --features flag → Load flow-multi.md → STOP
  ELSE → Tuần tự load phase files:
    ↓
  phase0-existing-analysis.md        (EXTEND/MODIFY only — SKIP nếu NEW)
    ↓
  phase0-5-context-setup.md          (LEGACY_MODE + Decision Registry — LUÔN chạy)
    ↓
  phase1-feature-context.md          (Feature Context + digest loading)
    ↓
  phase0-7-safety-gate.md            (Safety Gate — cần task file từ Phase 1)
    ↓
  IF $CONFIRMED_STRATEGY == VERIFY_ONLY → nhảy thẳng phase6-finalize.md
  ELSE:
    ↓
  phase2-planning.md                 (Task breakdown + batch plan)
    ↓
  IF $PARALLEL_MODE == true → phase2-5-contracts.md
    ↓
  phase3-tdd.md                      (TDD implementation — sequential hoặc waves)
    ↓
  IF --skip-review != true → phase4-5-review-fix.md
    ↓
  phase5a-crossval.md                (Auto-correction loop)
    ↓
  phase6-finalize.md                 (Update registry, reports, phase-summary)
```

### State Variables Passed Between Phases

| Variable | Set ở | Read ở |
|----------|-------|--------|
| `$FEATURE_SLUG` | SKILL.md Phase 0.2b | Tất cả phase files |
| `$LEGACY_MODE` | phase0-5 (0.5a.2-3) | phase1, phase2, phase3 |
| `$ENV_PROFILE` | phase0-6 (0.6.5) | phase0-7 (BƯỚC 2b), phase2, phase3, phase4-5 (agent contexts) |
| `$ENV_CONTEXT` | phase0-6 (0.6.11) | Tất cả agent spawn contexts |
| `$DEPRECATED_MODULES` | phase0-5 (0.5a.4) | phase1 (1.7a) |
| `$SCENARIO` | phase1 (1.7) | phase2, phase3 |
| `$EXECUTABLE_SPEC` | phase1 (1.6a) | phase3 (agent context) |
| `$DESIGN_SUMMARY` | phase1 (1.9) | phase3 (agent context) |
| `$CONFIRMED_STRATEGY` | phase0-7 (BƯỚC 3) | phase2+ (routing) |
| `$FOUND_CODE_REFS` | phase0-7 (BƯỚC 2) | phase0-7 (BƯỚC 3) |
| `$TASK_LIST` / `$BATCHES` | phase2 (2.1-2.4) | phase3 (3.0+) |
| `$PARALLEL_MODE` | SKILL.md Phase 0 (flag parsing) | phase2-5, phase3 |
| `$QA_ATTEMPT_OFFSET` | Multi-Run Logic (SKILL.md) | phase4-5 |
| `$CONSTRAINT_LIST` | phase0-5 (0.5b.2) | phase3 (agent context), phase5a (5a.D) |

---

## REQ-ID Format Reminder

```typescript
// REQ-ID: REQ-FIN-001
export class ChartOfAccountsService { }
```

- Simple: `REQ-[DEPT]-[NNN]` → `REQ-SALES-001`
- Complex: `REQ-[SYSTEM]-[MODULE]-[NNN]` → `REQ-CRM-CUST-001`

Mọi source file phải có `// REQ-ID: [ID]` comment ở đầu file hoặc đầu class chính.
