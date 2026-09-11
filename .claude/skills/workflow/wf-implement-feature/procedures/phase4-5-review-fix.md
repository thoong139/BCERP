# Phase 4-5: Review-Fix Loop (max 3 attempts)

> Spawn `qa-lead`, `code-reviewer`, `security` (và `api-tester` nếu có endpoints) đồng thời.
> Tối đa **3 attempts** — nếu vẫn NEEDS WORK sau 3 lần → escalate to user.
>
> **Agent contexts:** Xem `_shared.md` các sections:
> - §Agent Context: Code Reviewer
> - §Agent Context: QA Lead
> - §Agent Context: API Tester
> - §Agent Context: Security
>
> **Skip condition:** Nếu flag `--skip-review` → SKILL.md orchestrator skip file này, Phase 5a vẫn chạy.

**PRE-GATE:** `test -s "$SOURCE_FILE"` AND `--skip-review` chưa set

**📥 INPUT:** Source files + test files từ Phase 3

**📤 OUTPUT:**
- Review reports: `$SESSION_DIR/qa-review-attempt-[N].md`
- Fixed source files + test files (cùng đường dẫn Phase 3)

---

## VERIFY_ONLY Mode Route (v5.1+)

> Nếu `$CONFIRMED_STRATEGY == VERIFY_ONLY` → route sang lightweight review thay vì skip hoàn toàn.

```
IF $CONFIRMED_STRATEGY == "VERIFY_ONLY":
  Step 4-VO: VERIFY_ONLY Lightweight Review
    → Spawn code-reviewer agent (BẮT BUỘC — lightweight scan: security patterns + environment safety)
    → IF feature type = auth/payment/data → spawn security agent (BẮT BUỘC)
    → Skip qa-lead, api-tester, accessibility-auditor, performance-benchmarker (không có code changes)
    → Review scope: chỉ check existing code, không yêu cầu changes
    → Output: $SESSION_DIR/qa-review-attempt-0.md (attempt 0 = verify-only)
    → Issues found → log vào gaps_identified thay vì yêu cầu fix ngay
    → Tiếp tục phase5a-crossval.md (KHÔNG loop — chỉ 1 review pass)

  VERIFY_ONLY Agent Set:
  | Điều kiện | Agents |
  |-----------|--------|
  | Default | code-reviewer |
  | feature type ∈ {auth, payment, data} | code-reviewer + security |
  | Có UI files trong scope | code-reviewer (+ security nếu auth/payment/data) |

  VERIFY_ONLY Review Scope:
  - Environment safety patterns (E1-E5 từ phase0-7 BƯỚC 2b)
  - Hardcoded secrets / credentials
  - XSS / injection vulnerabilities
  - KHÔNG check: naming conventions, code structure, test coverage, DRY

  → Sau VERIFY_ONLY review: GOTO phase5a-crossval.md
```

---

## Review-Fix Loop Logic (non-VERIFY_ONLY)

```
SET attempt = ($QA_ATTEMPT_OFFSET + 1)   # = 1 on fresh run

WHILE attempt <= ($QA_ATTEMPT_OFFSET + 3):
  Step 4: REVIEW (parallel)
    → Spawn code-reviewer + qa-lead + security agents (+ api-tester nếu có endpoints)
    → Output: structured QA Review Reports (attempt N of 3)

  IF verdict = PASS (tất cả agents):
    → Proceed to phase5a-crossval.md
    → BREAK

  IF verdict = NEEDS WORK:
    Step 5: FIX
    → Fix tất cả CRITICAL + HIGH issues
    → Chạy lại tests
    → attempt += 1

IF attempt > 3 AND vẫn NEEDS WORK:
  → Generate Escalation Report
  → STOP — user quyết định: decompose / revise / accept / defer
```

---

## Step 4: Parallel Reviews (mỗi attempt — v3.3+ ADAPTIVE ROUTING + v4.0 PROFILE OVERLAY)

> **Finding #26 — Adaptive Agent Spawning (BẮT BUỘC v3.3+):**
> Cho annotation-only batches, spawn 3-4 agents parallel = waste 100K+ tokens Opus
> vì qa-lead/api-tester không có gì để review. Thực hiện adaptive routing dựa trên batch type.
>
> **Sprint 2 — Profile Overlay (BẮT BUỘC v4.0+):**
> `$PROFILE` (resolve ở phase2-planning Step 2.0b) overlay lên batch type agent set:
> - `quick` → reduce: chỉ giữ `code-reviewer` (override mọi batch type, kể cả api_endpoints — log WARN)
> - `standard` → giữ nguyên agent set từ batch type (default v3.3+ behavior)
> - `deep` → expand: union với `[code-reviewer, qa-lead, security]` (đảm bảo security review production-ready)
> - `exhaustive` → expand: union với `[code-reviewer, qa-lead, security, accessibility-auditor, performance-benchmarker]`
>
> Annotation_only batch luôn = code-reviewer ONLY regardless of profile (token saving rule).

### Step 4.0a — Classify Batch Type

| Batch type | Detection rule | Agents (default per batch type) |
|------------|----------------|-----------------|
| `annotation_only` | `git diff --stat` chỉ thay đổi dòng `// (REQ-ID\|FEAT-ID):` | code-reviewer ONLY (locked, profile không override) |
| `auth_security` | Batch touch auth/cookie/jwt/password/csrf/auth-server/login files | code-reviewer + security |
| `api_endpoints` | Batch touch controller/routes/api files (có endpoint paths mới) | code-reviewer + qa-lead + security + api-tester |
| `frontend_only` | Batch touch *.tsx/jsx/vue files (không touch backend) | code-reviewer + qa-lead |
| `data_layer` | Batch touch entity/repository/migration/schema files | code-reviewer + security (SQL injection) |
| `logic_change` (default) | Batch có code logic change không match special types | code-reviewer + qa-lead + security |
| `mixed` | Multiple types | union of agents from matching types |

### Step 4.0b — Profile Agent Matrix

| Profile | Base agent set (apply union với batch type) |
|---------|---------------------------------------------|
| `quick` | `[code-reviewer]` — REPLACE batch type set (override). Log WARN nếu batch type cần security/qa nhưng bị skip. |
| `standard` | `[]` — KHÔNG override, dùng batch type set nguyên gốc (default behavior v3.3+) |
| `deep` | `[code-reviewer, qa-lead, security]` — UNION với batch type set |
| `exhaustive` | `[code-reviewer, qa-lead, security, accessibility-auditor, performance-benchmarker]` — UNION với batch type set |

### Step 4.0 — Setup

| Step | Action | Verify |
|------|--------|--------|
| 4.0a | **Classify batch type** dùng `git diff` + filename heuristic → `$BATCH_TYPE` | Type set |
| 4.0b | **Compute base agent set** từ `$BATCH_TYPE` table → `$BATCH_AGENT_SET` (list) | Set computed |
| 4.0b2 | **[v4.0 Profile Overlay + v5.1 Mandatory Security]** Apply profile rule: <br>• `$BATCH_TYPE == annotation_only` → `$AGENT_SET = [code-reviewer]` (locked, ignore profile). <br>• `$PROFILE == quick` → `$AGENT_SET = [code-reviewer]`; **NHƯNG:** nếu `$BATCH_TYPE ∈ {auth_security, data_layer}` → giữ `security` agent (mandatory): `$AGENT_SET = [code-reviewer, security]`. Nếu `$BATCH_AGENT_SET` chứa `security` hoặc `api-tester` (non-auth/data) → log WARN `"[PROFILE-OVERRIDE] $BATCH_TYPE typically needs $SKIPPED but profile=quick"`. <br>• `$PROFILE == standard` → `$AGENT_SET = $BATCH_AGENT_SET`; **BỔ SUNG:** nếu `$BATCH_TYPE ∈ {auth_security, data_layer}` và `security ∉ $BATCH_AGENT_SET` → `$AGENT_SET = $BATCH_AGENT_SET ∪ [security]` + log `"[MANDATORY-SECURITY] Security agent mandatory for $BATCH_TYPE batch (CORE-020 enhanced)"`. <br>• `$PROFILE == deep` → `$AGENT_SET = $BATCH_AGENT_SET ∪ [code-reviewer, qa-lead, security]` (dedup). <br>• `$PROFILE == exhaustive` → `$AGENT_SET = $BATCH_AGENT_SET ∪ [code-reviewer, qa-lead, security, accessibility-auditor, performance-benchmarker]` (dedup). | `$AGENT_SET` finalized |
| 4.0c | LOG: `"[ADAPTIVE-SPAWN] Batch=$BATCH_TYPE Profile=$PROFILE → Spawning agents: $AGENT_SET. Skipped: $SKIPPED_AGENTS"` | Logged |
| 4.0d | **[Finding #23 — Adaptive Template v3.4+]** Select template theo batch type: <br>• `$BATCH_TYPE == annotation_only` → READ `templates/qa-review-report-annotation.md` (focused: header format, REQ-ID match, scope discipline, broad-scan). <br>• ELSE → READ `templates/qa-review-report.md` (full: code quality, security, tests, acceptance criteria). <br>Inject template structure vào agent contexts. Set `$REVIEW_TEMPLATE`. | Template loaded |

### Step 4.1-4.4 — Spawn (only agents in $AGENT_SET)

| Step | Action | Condition |
|------|--------|-----------|
| 4.1 | Spawn `code-reviewer` agent (parallel) — xem `_shared.md §Agent Context: Code Reviewer` | ALWAYS (mọi batch type cần code review) |
| 4.2 | Spawn `security` agent (parallel) — xem `_shared.md §Agent Context: Security` | `security ∈ $AGENT_SET` |
| 4.3 | Spawn `qa-lead` agent (parallel) — xem `_shared.md §Agent Context: QA Lead` | `qa-lead ∈ $AGENT_SET` |
| 4.4 | Spawn `api-tester` agent (parallel) — xem `_shared.md §Agent Context: API Tester` | `api-tester ∈ $AGENT_SET` |
| 4.4a | **[Sprint 2 — exhaustive profile]** Spawn `accessibility-auditor` agent (parallel) — context tham chiếu agent definition `.claude/agents/testing/accessibility-auditor.md`; review WCAG 2.2 AA, ARIA, keyboard nav cho UI files trong batch | `accessibility-auditor ∈ $AGENT_SET` (chỉ profile=exhaustive khi có UI files) |
| 4.4b | **[Sprint 2 — exhaustive profile]** Spawn `performance-benchmarker` agent (parallel) — context tham chiếu `.claude/agents/testing/performance-benchmarker.md`; benchmark Core Web Vitals, query performance, bundle size cho files trong batch | `performance-benchmarker ∈ $AGENT_SET` (chỉ profile=exhaustive) |
| 4.5 | Chờ tất cả agents → consolidate vào QA Review Report | Report generated |
| 4.6 | Populate template sections (metadata, verdict, issues, checklist, summary, next_action) → WRITE `$SESSION_DIR/qa-review-attempt-[N].md`. Note ô `agents_skipped` với lý do. | `test -s qa-review-attempt-[N].md` |

### Token saving estimate

| Batch type | Old (4 agents) | New (adaptive) | Saving |
|------------|----------------|----------------|--------|
| annotation_only | ~200K | ~50K | 75% |
| auth_security | ~200K | ~120K | 40% |
| frontend_only | ~200K | ~120K | 40% |
| data_layer | ~200K | ~120K | 40% |
| api_endpoints | ~200K | ~200K | 0% (cần đầy đủ) |
| logic_change | ~200K | ~170K | 15% |

---

## Step 5: Issue Resolution (mỗi attempt khi NEEDS WORK)

| Step | Action | Verify |
|------|--------|--------|
| 5.1 | Fix tất cả issues CRITICAL/SECURITY | Issues fixed |
| 5.2 | Fix tất cả issues HIGH | Issues fixed |
| 5.3 | Chạy lại tests | Tests pass |
| 5.4 | Log fixes vào QA Review Report (Failure History section) | History updated |

---

## Escalation (attempt = 3 và vẫn NEEDS WORK)

| Step | Action | Verify |
|------|--------|--------|
| 5.E1 | Điền Escalation Report section trong `qa-review-attempt-3.md` | Report complete |
| 5.E2 | Phân tích root cause | Root cause documented |
| 5.E3 | Đề xuất resolution: decompose / revise / accept / defer | Options listed |
| 5.E4 | STOP — thông báo user quyết định | User notified |

---

## Step 4.7: Agent Output Spot-Check (v5.1+ — CORE-029)

> Chạy SAU khi tất cả agents hoàn thành + review report đã tạo. Quét nhanh các pattern phổ biến
> mà agent có thể bỏ sót trong modified files.

### Spot-Check Patterns

| # | Check | Method | Action on hit |
|---|-------|--------|---------------|
| S1 | `process\.env\.(?!NODE_ENV)` trong browser files | `git diff --name-only HEAD` → grep `*.tsx,*.jsx` không trong `server/` | WARNING → auto-fix hoặc escalate |
| S2 | `'(dev-secret\|admin123\|password\|changeme)'` | grep tất cả modified files | ERROR → block merge, yêu cầu fix |
| S3 | `console\.log\(` (trừ test files) | grep modified files `*.ts,*.tsx` trừ `*.test.*`, `*.spec.*` | WARNING → log, suggest remove |
| S4 | `\.replace\(['\"][^/]` (non-regex replace) | grep modified `*.ts,*.tsx` | INFO → log, agent tự check |

### Steps

| Step | Action | Verify |
|------|--------|--------|
| 4.7.1 | Get modified files: `MODIFIED_FILES=$(git diff --name-only HEAD -- '*.ts' '*.tsx' '*.js' '*.jsx' \| grep -v '\.test\.' \| grep -v '\.spec\.')` | Files list |
| 4.7.2 | Run S1: echo "$MODIFIED_FILES" \| grep -E '\.(tsx\|jsx)$' \| grep -v '/server/' \| xargs -r grep -n 'process\.env\.' 2>/dev/null \| grep -v 'NODE_ENV' → `$SPOT_WARNINGS` | S1 done |
| 4.7.3 | Run S2: echo "$MODIFIED_FILES" \| xargs -r grep -nE "(dev-secret\|admin123\|password\|changeme)" 2>/dev/null → `$SPOT_ERRORS` | S2 done |
| 4.7.4 | Run S3: echo "$MODIFIED_FILES" \| grep -E '\.(ts\|tsx)$' \| xargs -r grep -n 'console\.log(' 2>/dev/null → append `$SPOT_WARNINGS` | S3 done |
| 4.7.5 | Run S4: echo "$MODIFIED_FILES" \| grep -E '\.(ts\|tsx)$' \| xargs -r grep -n '\.replace(['"'"'"'"]' 2>/dev/null \| grep -v '/g' → `$SPOT_INFO` | S4 done |
| 4.7.6 | Compile `$SESSION_DIR/agent-spot-check.json` (schema: `{passed: bool, warnings: [{file, line, match, check}], errors: [{file, line, match, check}]}`) | File written |

### Decision

```
IF ${#SPOT_ERRORS[@]} > 0:
  → BLOCK POST-GATE → hiển thị errors → yêu cầu agent fix
  → Append errors vào qa-review-attempt-[N].md Issues section
  → Re-run review loop (nếu attempt < 3) HOẶC escalate

IF ${#SPOT_WARNINGS[@]} > 0:
  → WARNING trong review report
  → Log vào agent-spot-check.json
  → KHÔNG block (agent tự check và fix ở attempt sau)
```

### Output

| File | Schema |
|------|--------|
| `$SESSION_DIR/agent-spot-check.json` | `{passed: bool, timestamp, warnings: [], errors: [], modified_files_count: N}` |

---

## POST-GATE (non-VERIFY_ONLY)

Verdict = PASS từ tất cả agents, HOẶC user acknowledged escalation. **(v5.1+):** `agent-spot-check.json.errors` rỗng.

> **[Protocol 10 — T4 Cross-ref]:** Sau review PASS: Grep tất cả REQ-IDs trong source files → cross-check với registry → mỗi REQ-ID phải tồn tại. Nếu mismatch → WARNING (không block) — log vào `impl-report.md`.

---

## Agent Timeout Handling (E401, alias E010)

Nếu agent timeout trong Phase 4:
1. Retry 1 lần. Log: `ledger_log "E401" "phase4-5-review-fix" "warning" "Agent timeout, retrying" '{"agent":"$AGENT_NAME"}' false`
2. Vẫn timeout → skip agent đó, log warning vào review report + ledger (auto_resolved=true), tiếp tục với agents còn lại. Log: `ledger_log "E401" "phase4-5-review-fix" "warning" "Agent skipped after retry" '{"agent":"$AGENT_NAME"}' true`
3. Nếu ≥2 agents timeout → STOP + escalate. Log: `ledger_log "E401" "phase4-5-review-fix" "error" "Multiple agent timeouts" '{"timeouts":$N}' false true`

Nếu critical/security issues từ review → log E402 (alias E009): `ledger_log "E402" "phase4-5-review-fix" "error" "Critical issues unfixed after 3 attempts" '{"attempts":3}' false true`.
