# Phase 3: TDD Implementation

> Vòng lặp RED → GREEN → REFACTOR cho mỗi batch.
>
> - **Sequential Mode (default):** Batches chạy tuần tự.
> - **Parallel Mode (`--parallel`):** Phase 3 chạy theo Parallel Waves (Wave 1/2/3).
>
> **Agent:** `developer` / `frontend-developer` / `mobile-developer` — xem context + Agent Selection tại `_shared.md §Agent Context: Developer`.
>
> **Protocols:** Protocol 3 (checkpoint), Protocol 6 (token limit), Protocol 9.6 (proactive budget), Protocol 12 (decision registry), Protocol 13 (test gates).

**PRE-GATE:** `test -n "$TASK_LIST"` AND `$CONFIRMED_STRATEGY != "VERIFY_ONLY"`

**📥 INPUT:** Feature design, `impl-plan.md`, `existing-patterns.json` (nếu EXTEND/MODIFY), `contracts.json` (nếu parallel)

**📤 OUTPUT:** Source code + test files (đường dẫn tùy project structure)

---

## CI PRE-GATE: Pre-Edit Impact & Post-Edit Verification (Protocol 20 §20.5)

> **Khi CI tools available:** Mỗi code edit phải có impact analysis trước và detect_changes sau.
> **Khi index stale:** Kết quả kèm freshness caveat.

| Step | CI Task | Tool | Action |
|------|---------|------|--------|
| CI-1 | `impact_analysis` | **GitNexus** `impact({symbol}, upstream)` | Trước mỗi batch: chạy impact analysis cho symbols sẽ sửa. Nếu blast radius > 5 files → WARNING cho agent. Nếu HIGH/CRITICAL risk → CDG render (CORE-027). |
| CI-2 | `find_references` | **Serena** `find_references` | Verify tất cả call sites của symbol sẽ sửa → đảm bảo không bỏ sót. |
| CI-3 | `detect_changes` | **GitNexus** `detect_changes()` | Sau mỗi batch: verify chỉ files dự kiến bị ảnh hưởng. Mismatch → review. |

**Graceful:** CI unavailable → skip checks → TDD bình thường. Index stale → kèm caveat "Results based on index N commits behind HEAD."

---

## Agent Selection

Xem `_shared.md §Agent Context: Developer → Agent Selection Table` cho tiêu chí chọn agent.

---

## Sequential Mode (Default)

Với mỗi Batch trong `$BATCHES`:

### 3.0.B Proactive Budget Check (Protocol 9.6)

| Step | Action | Verify |
|------|--------|--------|
| 3.0.B | Chạy Protocol 9.6. Nếu `CHECKPOINT` → lưu checkpoint, thông báo user dùng `--resume`, STOP. Nếu `WARN` → tiếp tục nhưng đây là batch cuối session. | LOG `"[BUDGET] Batch N ..."` |

> **Snapshot cho Test Gate (Protocol 13.3):** Ghi danh sách files sẽ tạo/sửa vào `checkpoint.batch_snapshot.files` TRƯỚC khi bắt đầu batch.

### 3.0 Spawn Developer Agent

| Step | Action | Verify |
|------|--------|--------|
| 3.0.0 | **[TLP-02] Input Compression:** IF input files > 3: Main conversation Grep key sections → tạo input digest (~200 từ/file). Developer agent nhận digest + file paths để đọc chi tiết khi cần. | Digest ready (hoặc skip nếu ≤3 files) |
| 3.0.1 | Xác định developer agent phù hợp theo Agent Selection table | Agent type set |
| 3.0.F | **[FILE PRE-CHECK — CDG-02 per Protocol 16]** Với mỗi file dự kiến trong batch: IF file đã tồn tại → route theo mode: (a) `--resume` → skip silently; (b) `$CONFIRMED_STRATEGY IN ("COMPLETE_EXISTING", "MODIFY")` (v3.3+ Finding #17) → SKIP CDG-02 (file existing là EXPECTED state, không phải decision) + log `[CDG-SKIP] $CONFIRMED_STRATEGY — file overwrite is expected behavior`; (c) `$CONFIRMED_STRATEGY == "IMPLEMENT_NEW"` AND không resume → **CDG-02 trigger (CORE-027)**: hiển thị message tiếng Việt "File đã tồn tại nhưng strategy = IMPLEMENT_NEW, sẽ bị ghi đè bởi TDD implementation" + đường dẫn + preview 5 dòng đầu. Offer **Batch Accept** cho tất cả files cùng batch (Protocol 16 §16.3 rule 6). Log decision vào `$FEATURE_DIR/cdg-tokens.json` (APPEND) VÀ `session-log.json` với event `CDG_ACCEPTED`/`CDG_REJECTED`. Reject → skip file + log lý do; Accept → proceed. Nếu tất cả files `already_done` → SKIP batch. | CDG logged hoặc skipped |
| 3.0.2 | Spawn developer agent cho batch hiện tại (inject `$EXECUTABLE_SPEC`, `$CONSTRAINT_LIST`, `$DESIGN_SUMMARY`, `existing-patterns.json`) | Agent success |
| 3.0.3 | IF domain = AI/ML → spawn `model-qa` agent (parallel) | Agent success (hoặc skip) |

### 3.1 RED — Viết failing test

| Step | Action | Verify |
|------|--------|--------|
| 3.1.1 | Viết test cho task hiện tại | `test -s [test-file]` |
| 3.1.2 | Chạy test — **PHẢI FAIL** | Test fails |
| 3.1.3 | Thêm edge cases | — |

### 3.2 GREEN — Viết minimal code

| Step | Action | Verify |
|------|--------|--------|
| 3.2.1 | Viết code tối thiểu để pass test | `test -s [source-file]` |
| 3.2.2 | **Chạy test suite và xác nhận PASS** — nếu fail: fix code (KHÔNG fix test). Đảm bảo test assertions khớp implementation (query builder aliases, mock return types, method signatures phải khớp chính xác). | All tests green |
| 3.2.3 | Thêm REQ-ID comment vào code | REQ-ID present |

### 3.3 REFACTOR — Clean up

| Step | Action | Verify |
|------|--------|--------|
| 3.3.1 | Xóa duplication, cải thiện naming | — |
| 3.3.2 | Chạy lại tests — **PHẢI VẪN PASS** | Tests pass |

### 3.4 Batch Checkpoint & Test Gate (Protocol 13)

| Step | Action | Verify |
|------|--------|--------|
| 3.4.0 | **[Template Rule]** READ `templates/checkpoint.json` → xác định fields cần populate cho checkpoint hiện tại | Template loaded |
| 3.4.1 | **[GATE-13] Test Gate:** Chạy tất cả tests trong batch (Protocol 13.2). Nếu FAIL: auto-fix max 2 lần → vẫn FAIL → Rollback batch (Protocol 13.3) → STOP + ASK USER. | All tests PASS |
| 3.4.2 | **[GATE-13] Type Check:** Nếu TypeScript → `npx tsc --noEmit`. Xử lý như test fail. | No type errors |
| 3.4.3 | Update `impl-status.json` | Status updated |
| 3.4.4 | Check context budget (Protocol 9.3) — nếu ≥ 80%: populate checkpoint template với position, progress, files_state, tests_state, next_action → WRITE `$SESSION_DIR/checkpoint.json` → STOP → thông báo user dùng `--resume`. | `test -s checkpoint.json` |
| 3.4.5 | **[PHIÊN 5] Generate Context Digest (Protocol 3.2):** Developer agent tự tóm tắt context vào `checkpoint.json.context_digest`. Digest PHẢI gồm: feature_summary (~100-200 từ), architectural_decisions[], interfaces_established{}, patterns_in_use{}, cross_batch_contracts{}, gotchas_and_warnings[]. | `jq -e '.context_digest.feature_summary' checkpoint.json` |

### 3.5 Write New Decisions (Protocol 12 — sau mỗi batch)

> **v4.0 Sprint 3:** Mỗi NEW DECISION được tag scope (`feature:` / `module:` / `project`) — quyết định nơi append.

| Step | Action | Verify |
|------|--------|--------|
| 3.5.1 | Đọc developer agent output — tìm dòng `"NEW DECISION: [category] — [rule] — vì [reason] — scope: [feature\|module\|project]"`. Default scope nếu agent không nêu rõ: `feature:$FEATURE_SLUG`. | Parsed |
| 3.5.2 | Với mỗi NEW DECISION: chạy Protocol 12.2 (conflict check chống `$CONSTRAINT_LIST` đã load Phase 0.5b → append). Append target: **per-feature** registry (`$SESSION_DIR/decision-registry.json`) — luôn append bất kể scope. | Per-feature registry updated |
| 3.5.3 | **[v4.0 Sprint 3] Global registry append (chỉ khi scope ∈ `project` hoặc `module:*`):** `bash .claude/scripts/wf-implement-feature/implement-acquire-lock.sh --type=decision-registry --timeout=30 \|\| { log E601; continue; }`. Conflict check: query existing decisions cùng scope+category trong `decision-registry.global.json`. Nếu rule contradict existing → escalate user (CDG-04 inline) + skip append. Nếu OK → atomic append entry với `id="D-GLOBAL-{N+1}"`, `added_by={skill, feature_slug, session_id, ts}`, update `last_updated`. Release lock. | Global registry updated (nếu applicable) |
| 3.5.4 | LOG: `"[D-REG] [N] decision(s) mới ghi từ Batch [M] — feature-level: [F], global: [G]"` | LOG done |

#### Append global registry — bash logic (Step 3.5.3)

```bash
GLOBAL_REG=".mc-data/docs/_meta/decision-registry.global.json"
NEW_DECISION_JSON='{...}'  # Đã parse từ agent output trong Step 3.5.1
SCOPE=$(echo "$NEW_DECISION_JSON" | jq -r '.scope')

# Skip nếu scope = feature:* (đã append per-feature ở 3.5.2)
if [[ "$SCOPE" == feature:* ]]; then
  exit 0
fi

# Lazy init nếu file chưa tồn tại
if [[ ! -f "$GLOBAL_REG" ]]; then
  TS=$(date -u +%FT%TZ)
  jq -n --arg ts "$TS" '{
    "$schema": "decision-registry-global-v1",
    schema_version: "1.0",
    created_at: $ts,
    last_updated: $ts,
    decisions: []
  }' > "$GLOBAL_REG"
fi

# Acquire lock
bash .claude/scripts/wf-implement-feature/implement-acquire-lock.sh \
  --type=decision-registry --timeout=30 \
  || { echo "[E601] Decision registry lock timeout"; exit 1; }
trap 'rm -f .mc-data/docs/_meta/.decision-registry.lock' EXIT

# Conflict check (Protocol 12.2)
NEW_CATEGORY=$(echo "$NEW_DECISION_JSON" | jq -r '.category')
NEW_RULE=$(echo "$NEW_DECISION_JSON" | jq -r '.rule')
EXISTING_RULES=$(jq -r --arg sc "$SCOPE" --arg cat "$NEW_CATEGORY" \
  '[.decisions[] | select(.scope == $sc and .category == $cat) | .rule] | join("; ")' \
  "$GLOBAL_REG")

if [[ -n "$EXISTING_RULES" ]]; then
  echo "WARN: Existing rules in scope=$SCOPE category=$NEW_CATEGORY: $EXISTING_RULES"
  echo "New rule: $NEW_RULE"
  # CDG-04 inline: log + continue (developer agent chịu trách nhiệm convergence)
  # Strict mode: escalate user (Phase 5a sẽ check)
fi

# Compute next ID
NEXT_N=$(jq '.decisions | length' "$GLOBAL_REG")
NEXT_N=$((NEXT_N + 1))
NEW_ID=$(printf "D-GLOBAL-%03d" "$NEXT_N")

# Append + update last_updated
TMP=$(mktemp)
TS=$(date -u +%FT%TZ)
jq --argjson new "$NEW_DECISION_JSON" \
   --arg id "$NEW_ID" \
   --arg ts "$TS" \
   --arg fs "$FEATURE_SLUG" \
   --arg sid "$SESSION_ID" \
   '
     .decisions += [
       $new
       + {id: $id}
       + {added_by: {skill:"wf-implement-feature", feature_slug:$fs, session_id:$sid, timestamp:$ts}}
     ]
     | .last_updated = $ts
   ' "$GLOBAL_REG" > "$TMP" \
   && mv "$TMP" "$GLOBAL_REG" \
   || { echo "[E602] Global registry write fail"; rm -f "$TMP"; exit 1; }

# Validate after write
jq -e '.decisions | length > 0' "$GLOBAL_REG" >/dev/null || exit 1

# Release lock (auto via trap)
rm -f .mc-data/docs/_meta/.decision-registry.lock
trap - EXIT
```

> **Cross-platform safety (Sprint 1+2 pattern):** `tr -d '\r'` sau `jq -r` nếu pipe sang grep/comparison.
>
> **Mutex:** Lock file `.mc-data/docs/_meta/.decision-registry.lock` — cùng pattern với Cross-Process Mutex của `_shared.md`. Reuse `implement-acquire-lock.sh --type=registry --target=decision-registry`.

---

## Parallel Mode (--parallel flag)

> **Điều kiện:** `$PARALLEL_MODE == true` AND `contracts.json` đã được tạo ở phase2-5-contracts.md.

### Parallel Waves

```
WAVE 1 (PARALLEL):
  ├── Agent A (entity):     Implement entities từ types.ts
  ├── Agent B (repository): Implement repositories từ interfaces + entities
  └── Agent C (dto):        Implement DTOs (no dependencies)
  ↓ (Đợi Wave 1 complete + Type Check pass)

WAVE 2 (PARALLEL):
  ├── Agent D (service):    Implement services từ interfaces + repositories
  └── Agent E (controller): Implement controllers từ interfaces + services
  ↓ (Đợi Wave 2 complete)

WAVE 3 (SEQUENTIAL):
  └── Agent F (test):       Implement comprehensive tests từ tất cả files
```

### Safety Rules cho Parallel Agents

| Rule | Enforcement |
|------|------------|
| **R1: Isolated Write Scope** | Mỗi agent chỉ ghi vào scope riêng (enforced bằng `contracts.json.forbidden_write_scope`). Nếu ghi ngoài scope → STOP + escalate. |
| **R2: Contract Immutability** | Không sửa files trong `src/shared/`, `src/interfaces/`, `src/dtos/`, `src/database/migrations/`. → log `"CONTRACT_MODIFICATION_ATTEMPT"` + escalate. |
| **R3: Dependency Ordering** | Wave 2 PHẢI chạy SAU Wave 1 hoàn thành + type checker pass. |
| **R4: Test Integration** | SAU Wave 2: chạy test suite để verify cross-agent compatibility. |
| **R5: Escalation on Conflict** | 2 agents cần sửa cùng 1 file → STOP + escalate. |

### Wave Task Assignment

| Wave | Files trong batch | Priority | Conditions |
|------|------------------|----------|-----------|
| Wave 1 | `entity.ts`, `dto.ts`, `repository.interface.ts` | P0 | Entity PHẢI trước repository |
| Wave 2 | `service.ts`, `controller.ts` | P1 | Sau Wave 1 |
| Wave 3 | `*.test.ts` | P2 | Sau Wave 1-2 |

---

## Integration Test (Mandatory — sau Parallel Waves HOẶC Sequential)

| Step | Action | Verify |
|------|--------|--------|
| 3.Final.1 | Chạy toàn bộ test suite (unit + integration) | All tests pass |
| 3.Final.2 | Nếu parallel mode: verify mọi agent outputs đã merge đúng (no orphaned files) | Merge artifact clean |
| 3.Final.3 | Chạy linter + formatter (prettier/black) | No style violations |
| 3.Final.4 | Type check cuối cùng (nếu TypeScript) | No type errors |
| 3.Final.5 | Commit code (git) với message liệt kê files created | Commit success |

---

## POST-GATE (Phase 3)

- Source file tồn tại (`test -s [source-file]`)
- REQ-ID present trong mọi source file (Grep `// REQ-ID:`)
- ALL tests PASS
- NO type errors (nếu có type checker)

---

## REQ-ID Format

```typescript
// REQ-ID: REQ-FIN-001
export class ChartOfAccountsService { }
```
