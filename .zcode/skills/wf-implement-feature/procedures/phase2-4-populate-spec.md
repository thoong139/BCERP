# Phase 2.4: Populate A6-EXT (BẮT BUỘC khi STUB)

> **Conditional gate** — chỉ chạy khi `$A6_EXT_NEEDS_POPULATE == true` (set ở Phase 1.6a STUB detection).
>
> **Mục đích:** Architect agent populate A6-EXT (file specs, methods, contracts, test cases)
> trước khi Developer agent vào Phase 3 → tránh ra code shallow do A6-EXT stub.
>
> **Vị trí:** Sau `phase2-planning.md`, trước `phase3-tdd.md` (hoặc `phase2-5-contracts.md` nếu parallel).

**PRE-GATE:** `$A6_EXT_NEEDS_POPULATE == true`

> Nếu `$A6_EXT_NEEDS_POPULATE == false` (A6-EXT complete hoặc absent) → orchestrator skip file này.

**📥 INPUT:**
- Task file (chứa A6-EXT STUB markers)
- Feature design (`phase2-features/[sys]/[mod]/[feat].md`)
- Architecture digest (`design-input-digest.json`)
- `$TASK_LIST`, `$BATCHES` (từ Phase 2)

**📤 OUTPUT:**
- Task file `[feat]-impl.md` updated với A6-EXT populated
- `$EXECUTABLE_SPEC` reloaded từ task file mới
- `$A6_EXT_STATE = "complete"` (sau populate)

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 2.4.0 | Snapshot task file (backup) → `$SESSION_DIR/task-file.before-populate.bak` | Backup created |
| 2.4.1 | Spawn `architect` agent (model=opus khi user chỉ định, mặc định inherit) với context: feature design + design digest + task file (full) + scope files list từ A2.4 + acceptance criteria từ A4 | Agent spawned |
| 2.4.2 | Architect output PHẢI tuân thủ structure: A6-EXT.0 Coverage Summary, A6-EXT.1 File Specifications (per-file: type, pattern, methods, signatures, REQ-IDs), A6-EXT.2 Cross-File Contracts, A6-EXT.3 Verification Checklist | Output structured |
| 2.4.3 | Validate architect output: ≥200 từ tổng, ≥1 method signature per file, no `[...]` placeholder, all 6 checklist items in A6-EXT.3 ticked | Validation pass |
| 2.4.4 | Replace A6-EXT section trong task file (preserve A1-A5, A6, A7-EXT, A8-A9 nguyên vẹn) — chỉ swap A6-EXT block | Task file updated |
| 2.4.5 | Reload `$EXECUTABLE_SPEC` từ updated task file | `$EXECUTABLE_SPEC` non-empty |
| 2.4.6 | SET `$A6_EXT_STATE = "complete"`, `$A6_EXT_NEEDS_POPULATE = false` | State updated |
| 2.4.7 | Append entry vào `decision-registry.json`: category `architecture`, rule `A6-EXT populated by architect agent at $TIMESTAMP` | Decision logged |
| 2.4.8 | Log session-log: event `A6_EXT_POPULATED`, files_modified=1 (task file) | Logged |

---

## Architect Agent Prompt

```
Bạn là Architect Agent được spawn cho Phase 2.4 Populate A6-EXT.

**Mục đích:** A6-EXT trong task file đang là STUB. Bạn cần populate đầy đủ
để Developer Agent ở Phase 3 có executable specification chi tiết.

## Context

- Feature: [FEATURE_NAME]
- REQ-ID: [REQ_ID]
- Strategy: [CONFIRMED_STRATEGY] (NEW / EXTEND / MODIFY / COMPLETE_EXISTING)

## Inputs

1. Feature design: [.mc-data/docs/phase2-features/[sys]/[mod]/[feat].md]
2. Architecture digest: [design-input-digest.json relevant entries]
3. Task file (current STUB): [.mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md]
4. Scope files (từ A2.4): [list of files]
5. Acceptance criteria (từ A4): [list of AC]
6. Gaps identified (nếu COMPLETE_EXISTING): [list]

## Output structure (BẮT BUỘC)

Tạo A6-EXT section đầy đủ với:

### A6-EXT.0 Coverage Summary
- Total files: [N]
- Methods (estimated): [N]
- Test cases (estimated): [N]
- REQ-IDs covered: [list]

### A6-EXT.1 File Specifications

Cho MỖI file trong scope (A2.4):

**File [N]:** `[absolute path]`
- Type: [Frontend Server Component / Client Component / Backend Service / Hook / Type Definition / Test / etc.]
- Pattern: [explain pattern và data flow]
- Methods:
  | Name | Signature | Purpose | REQ-IDs |
  |------|-----------|---------|---------|
  | ... | ... | ... | ... |
- Imports: [key imports — typed]
- Test cases (mapped từ AC):
  - TC-N: [input/output/expected]
- Error handling: [invariants, edge cases]

### A6-EXT.2 Cross-File Contracts

Liệt kê discriminated unions, type aliases, interface contracts dùng GIỮA các files.

### A6-EXT.3 Verification Checklist

- [ ] Coverage Summary populated
- [ ] ≥1 file spec per scope file
- [ ] Each file has methods + tests
- [ ] No `[...]` placeholders
- [ ] ≥200 words total
- [ ] A2.4 Scope Files đã consistent với spec
- [ ] All gaps from spec addressed

## Quy tắc bắt buộc

1. KHÔNG dùng placeholder `[...]` hoặc `TBD` — populate đầy đủ
2. Method signatures PHẢI typed (TypeScript/C#/etc theo language project)
3. Test cases PHẢI map về AC IDs từ A4 (e.g., AC-001, AC-002)
4. Cross-file contracts PHẢI specify file:export pairs

Output: chỉ section A6-EXT đầy đủ (không cần wrap trong markdown code fence).
```

---

## POST-GATE

```bash
# T1: A6-EXT now in task file (no STUB markers)
grep -q "STUB.*Stage 4 Phase B không spawn architect" "$TASK_FILE" && exit 1
grep -q "**STUB**" "$TASK_FILE" && exit 1

# T2: A6-EXT.1 has at least 1 file spec với method signature
awk '/^### A6-EXT.1/,/^### A6-EXT.2/' "$TASK_FILE" | grep -q "| Name | Signature |" || exit 1

# T3: Word count ≥ 200 trong A6-EXT
WC=$(awk '/^### A6-EXT/,/^### A7/' "$TASK_FILE" | wc -w)
[ "$WC" -ge 200 ] || exit 1
```

---

## Output State Variables

| Variable | Update |
|----------|--------|
| `$EXECUTABLE_SPEC` | Reloaded từ A6-EXT mới (non-empty) |
| `$A6_EXT_STATE` | `complete` |
| `$A6_EXT_NEEDS_POPULATE` | `false` |

---

## Error Handling (E204, alias E015 — A6-EXT populate failed)

```
IF architect agent timeout / fail → retry 1 lần
  → ledger_log "E204" "phase2-4-populate-spec" "warning" "A6-EXT populate retry" '{"attempt":1}' false
IF retry fail → fallback:
  → SET $EXECUTABLE_SPEC = "" (force Developer Agent đọc full Phase 1-3 docs)
  → Log WARNING: "A6-EXT populate failed sau 2 attempts. Phase 3 sẽ chậm hơn (đọc full docs)."
  → ledger_log "E204" "phase2-4-populate-spec" "warning" "A6-EXT populate fallback to full docs" '{"attempts":2}' true
  → Tiếp tục Phase 3 với fallback mode
```
