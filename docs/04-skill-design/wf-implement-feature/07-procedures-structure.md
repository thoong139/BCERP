# 07 — Procedures Structure

> **Mục đích file:** Outline thư mục `procedures/` — 14 file lazy-load tuân thủ CORE-032. Mỗi file chỉ load khi tới phase tương ứng.

---

## 1. Layout

```
.claude/skills/workflow/wf-implement-feature/procedures/
├── _shared.md                              ← Cross-cutting concerns (NOT loaded standalone)
├── phase0-existing-analysis.md             ← Phase 0a (conditional EXTEND/MODIFY)
├── phase0-5-context-setup.md               ← Phase 0.5 (LEGACY_MODE + decision-registry)
├── phase0-6-env-profile.md                 ← Phase 0.6 (v5.1+ env detection)
├── phase1-feature-context.md               ← Phase 1 (digest loading)
├── phase0-7-safety-gate.md                 ← Phase 0.7 (CORE-020 safety + env scan + 3-mode route)
├── phase2-planning.md                      ← Phase 2 (task breakdown + batches)
├── phase2-4-populate-spec.md               ← Phase 2.4 (conditional A6-EXT populate)
├── phase2-5-contracts.md                   ← Phase 2.5 (conditional parallel mode)
├── phase3-tdd.md                           ← Phase 3 (TDD + checkpoint at 3.4)
├── phase4-5-review-fix.md                  ← Phase 4-5 (parallel review + fix loop max 3)
├── phase5a-crossval.md                     ← Phase 5a (cross-validation auto-correction)
├── phase6-finalize.md                      ← Phase 6 (registry update + reports + summary)
└── flow-multi.md                           ← Multi-feature orchestration (--features=...)
```

**Quy tắc lazy-load (CORE-032):** Mỗi procedure file CHỈ đọc khi tới phase tương ứng. SKILL.md routing table định nghĩa thứ tự load.

---

## 2. `_shared.md` content (reference-only)

`_shared.md` KHÔNG load standalone — chỉ tham chiếu section cụ thể khi cần.

| Section | Mục đích |
|---------|---------|
| **§State variables** | `$SESSION_DIR`, `$FEATURE_SLUG`, `$SYSTEM_SLUG`, `$SCENARIO`, `$PROFILE`, `$PARALLEL_MODE`, `$CONFIRMED_STRATEGY`, `$LEGACY_MODE`, `$ENV_PROFILE`, `$CI_CONTEXT`, ... |
| **§Atomic write helpers** | `atomic_write_json()`, `atomic_append_jsonl()`, `safe_write_registry()` bash functions |
| **§Error handling** | `escalate()`, `auto_fix()`, `ledger_log()` (lazy-init error-ledger.json) |
| **§CI detection** | Wrappers cho `ci-detect.sh`, `ci-freshness-check.sh`, `ci-inject-context.sh` |
| **§Agent contexts** | 8-section prompt templates cho developer, architect, code-reviewer, qa-lead, security agents |
| **§Protocols refs** | Protocol 3 (Context), 6 (Token Limit), 7 (PAR-09), 8 (CQG-11), 9 (PLN-10), 10 (POST-GATE), 12 (Decision), 13 (Test Gates) |
| **§Error Codes Reference** | Full table E1xx-E9xx + legacy alias map E001-E014 |
| **§Registry Safe-Write** | CORE-006 narrow per-field jq update pattern |
| **§Lock helpers** | `acquire_lock()`, `release_lock()`, `is_lock_stale()` |
| **§Execution Flow Between Phase Files** | State variables passed between phases (e.g., `$EXECUTABLE_SPEC` từ Phase 1 → Phase 3) |

---

## 3. Phase procedure template (4 sections)

Mỗi `phase{N}-*.md` tuân theo cấu trúc:

### Section A — Header

```markdown
# Phase {N}: {Tên phase}

**Đầu vào:** {file/state cần có}
**Đầu ra:** {file/state tạo ra}
**Auto-fix budget:** 3 retries
**Time estimate (standard profile):** {X-Y} min
**Load khi:** {condition}
```

### Section B — PRE-GATE

```markdown
## PRE-GATE (T1→T4 forensic)

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | {file/state exists} | `test -f` | E{XXX} |
| T2 | {structure valid} | `jq` | E{XXX} |
| T3 | {content non-empty} | `jq` | E{XXX} |
| T4 | {cross-ref upstream} | bash | E{XXX} |
```

### Section C — Steps

```markdown
## Steps

| # | Mô tả | Tool/Agent | Output |
|---|------|-----------|--------|
| {N}.1 | Read template | Read | content |
| {N}.2 | Populate | Edit/Agent | tmp file |
| {N}.3 | Validate | Bash (jq) | pass/fail |
| {N}.4 | Atomic write | Bash | output file |

### Detail per step
{detail}
```

### Section D — POST-GATE

```markdown
## POST-GATE (T1→T4)

| Tier | Check | Auto-fix retry |
|------|-------|----------------|
| T1 | {exists} | Re-run step {N}.4 |
| T2 | {structure} | Re-build từ template |
| T3 | {content depth} | Re-generate |
| T4 | {cross-ref upstream} | Re-read source |
```

### Section E — Phase Report (CORE-028)

```markdown
## Phase Report Template

```markdown
## Phase {N}: {Tên} — PASS|FAIL
Thời gian: {ISO 8601}
**Đã làm:** {1-2 câu tiếng Việt}
**Kết quả:** {Số liệu chính} + {File đầu ra}
**Tiếp theo:** {Phase kế tiếp / hành động user}
```
```

---

## 4. Procedure summaries (per phase)

| File | Key responsibility |
|------|-------------------|
| `phase0-existing-analysis.md` | Scan existing patterns (naming, file_structure, code_style, entity/service/test patterns) → `existing-patterns.json`. Pattern cache (per-module + per-commit hash, TTL 24h) |
| `phase0-5-context-setup.md` | LEGACY_MODE detect (CORE-021: `project-context.md > 500 bytes`) + Decision Registry load (Protocol 12) + constraints list |
| `phase0-6-env-profile.md` | (v5.1+) Detect env profile (dev/staging/prod) từ env vars + config files + ENV_CONTEXT (NODE_ENV, etc.) → `$ENV_PROFILE` |
| `phase1-feature-context.md` | Load feature spec từ `phase2-features/[sys]/[mod]/<feat>.md` + digest từ `feature-briefs.json`. Step 1.10/1.11 consume `fix-impact.json` (v5.2+). A6-EXT detect |
| `phase0-7-safety-gate.md` | CORE-020 search existing code → AskUserQuestion (VERIFY_ONLY/COMPLETE_EXISTING/IMPLEMENT_NEW). Bước 2b Env Safety Scan (v5.1+ với 5 patterns E1-E5). LEGACY_MODE → route theo `implementation_strategy` từ task file |
| `phase2-planning.md` | Task breakdown từ A1-A6 sections + complexity derivation + batch plan (theo dependency) → `impl-plan.md`, `$TASK_LIST`, `$BATCHES`. Profile resolver chạy Step 2.0b |
| `phase2-4-populate-spec.md` | Spawn architect agent populate A6-EXT khi STUB detected → re-read feature spec sau populate |
| `phase2-5-contracts.md` | Contract-first generation (parallel mode): shared types/interfaces/DTOs → `contracts.json`. Spawn architect agent |
| `phase3-tdd.md` | Sequential hoặc parallel waves. Test file TRƯỚC source file (TDD order check). Test gate GATE-13 BẮT BUỘC. Checkpoint at 3.4 (per batch). Decision detect at 3.5 (append decision-registry per-feature + global nếu scope=project/module) |
| `phase4-5-review-fix.md` | Spawn parallel review agents (set theo profile). Fix iterations max 3 (sequential). Mandatory security agent cho auth_security/data_layer batches (v5.1). Agent Output Spot-Check (CORE-029) |
| `phase5a-crossval.md` | Auto-correction loop max 3 iterations. Check REQ-ID in code, test files exist, tests pass, no critical issues, no placeholders, status consistent. Auto-fix obvious issues |
| `phase6-finalize.md` | POST-GATE T1→T4 via `implement-postgate.sh`. Registry update `impl_status=done` per REQ-ID (narrow jq). Append `decision-registry.global.json`. Write `phase-summary.md` (CORE-028 tiếng Việt). History index append. Lock release |
| `flow-multi.md` | Multi-feature orchestration. Build dependency graph từ A7-EXT. Topo-sort levels. Spawn parallel per level (Protocol 7 PAR-09). Aggregate per-feature impl-status → multi-feature report |

---

## 5. `resume-status.md` handlers (inline trong SKILL.md)

Mode `--resume` và `--status` được handle inline trong SKILL.md (không tách procedure file riêng):

| Mode | Behavior |
|------|----------|
| `--resume` | Đọc `checkpoint.json` → load → re-validate PRE-GATE phase tiếp theo → route đến `checkpoint.next_action`. Soft-resume fallback: `impl-status.json.status in [in_progress|paused|error]` mà chưa có checkpoint → AskUserQuestion |
| `--status` | Đọc `impl-status.json` → render summary (current phase, batch progress, % done, context budget, lock owner) → exit 0 |

Stale check: lock age >60min → auto-release. Migration chain v3→v4→v5 chạy idempotent ở Phase 0.0.

---

## 6. SKILL.md routing → procedures (lazy-load contract)

`SKILL.md` (lean routing hub ~600 dòng) chứa bảng routing:

```markdown
## Phase Orchestration (Single-Feature)

| # | File | Load khi | Mục đích |
|---|------|----------|---------|
| 1 | procedures/phase0-existing-analysis.md | $SCENARIO != "new" | Scan existing patterns |
| 2 | procedures/phase0-5-context-setup.md | Always | LEGACY_MODE + Decision Registry |
| 3 | procedures/phase0-6-env-profile.md | Always | Environment profile |
| 4 | procedures/phase1-feature-context.md | Always | Feature context + digest |
| 5 | procedures/phase0-7-safety-gate.md | Always | Safety gate + env scan |
| 6 | procedures/phase2-planning.md | $CONFIRMED_STRATEGY != VERIFY_ONLY | Task + batch plan |
| ... | ... | ... | ... |
```

**Quy tắc:** `SKILL.md` KHÔNG chứa execution logic — chỉ routing + summaries + arguments + error codes quick lookup. Logic chi tiết LIVE trong `procedures/phase{N}-*.md`.

---

## 7. Helper scripts (bash delegation)

Các logic phức tạp được delegate sang bash scripts để giảm SKILL.md size:

| Script | Mục đích |
|--------|---------|
| `implement-common.sh` | Source-able functions (normalize_slug, resolve_session_dir, derive_system_slug, atomic_write_json, ledger_log, trace_event, ...) |
| `implement-migrate-v3-to-v4.sh` | Idempotent migrate flat v3.x → `sessions/{date}-migrated/` |
| `implement-migrate-v4-to-v5.sh` | Idempotent migrate flat `$FEATURE_SLUG/` → `$SYSTEM_SLUG/$FEATURE_SLUG/` |
| `implement-acquire-lock.sh` | Per-feature lock với PID check + heartbeat + stale detection |
| `implement-resolve-profile.sh` | Auto-resolve profile từ scope file count |
| `implement-cache-resolver.sh` | Pattern cache validate + read/write với git SHA invalidation |
| `implement-history-index.sh` | Append-only history JSONL với atomic write |
| `implement-postgate.sh` | Phase 6 POST-GATE T1→T4 delegated logic |

Source: [`.claude/scripts/wf-implement-feature/`](../../../.claude/scripts/wf-implement-feature/)

---

## 8. Liên kết

- Pattern: [`../../03-design-patterns/01-lazy-load-procedures.md`](../../03-design-patterns/01-lazy-load-procedures.md)
- Pattern: [`../../03-design-patterns/11-bash-utility-design.md`](../../03-design-patterns/11-bash-utility-design.md) — bash vs Python decision
- Rules: CORE-032 (Lazy-Load Procedures), CORE-035 (Phase Output Organization), CORE-037 (Agent Prompt Templates)
- Standards: [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md) §3-4
- Source SKILL.md: [`.claude/skills/workflow/wf-implement-feature/SKILL.md`](../../../.claude/skills/workflow/wf-implement-feature/SKILL.md)
