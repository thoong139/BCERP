# Phase 2: Classify — Batch Loop

> Vòng lặp tuần tự: spawn `code-reviewer` agent cho mỗi batch chưa hoàn thành.
> Mỗi batch ghi `classified/batch-N.json`. Skip-if-exists để resume deterministic.
> Checkpoint sau mỗi 3 batches. Phase nặng nhất — cần isolation context tốt.

**PRE-GATE:**
- Phase 1 POST-GATE PASS
- `$BATCH_SIZE`, `$TOTAL_BATCHES`, `$BATCH_OFFSET`, `$UNCLASSIFIED_LIST`, `$DOCS_ONLY_MODE` đã set
- `mkdir -p .mc-data/work/legacy-scan/classified/`

**INPUT:**
- `$UNCLASSIFIED_LIST` (chia thành batches theo `$BATCH_SIZE`)
- `.mc-data/work/legacy-scan/classified/batch-*.json` (existing — skip-if-exists)
- `.mc-data/work/legacy-scan/project-profile.json` (truyền vào agent)
- `.mc-data/work/legacy-scan/domain-hints.json` (v5.0 OPTIONAL — nếu exist, load `$DOMAIN_HINTS` và inject vào code-reviewer prompt với confidence >= 0.6). Graceful skip khi file vắng.

**OUTPUT:**
- `.mc-data/work/legacy-scan/classified/batch-N.json` (mỗi batch)
- `.mc-data/work/legacy-scan/checkpoint.json` (per 3 batches — từ template `templates/checkpoint.json`)
- Update `legacy-scan-status.json`: `stages.classify.completed_batches`, `stages.classify.items_classified`
- In-memory state: `$EXISTING_MODULES` (cumulative), `$ITEMS_CLASSIFIED` (cumulative), `$NEW_MODULES_LOG`

---

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §Classification Types (Source Mode)
- `_shared.md` §Classification Types (DOCS_ONLY Mode)
- `_shared.md` §Classified Item Schema
- `_shared.md` §System vs Module Detection
- `_shared.md` §Naming Convention
- `_shared.md` §Agent Prompt Templates — code-reviewer Agent
- `_shared.md` §Fix Rules
- `_shared.md` §Checkpoint Protocol

---

## Steps (Loop Structure)

```
Loop từ loop_index = 1 đến (TOTAL_BATCHES - BATCH_OFFSET):
  N = BATCH_OFFSET + loop_index    # Absolute batch number

  STEP 2.A — Skip-if-exists check
  STEP 2.B — Compile EXISTING_MODULES từ batches đã có
  STEP 2.C — Spawn code-reviewer agent (write classified/batch-N.json)
  STEP 2.D — Validate batch file
  STEP 2.E — Update ledger + status
  STEP 2.F — Checkpoint (mỗi 3 batches: N mod 3 == 0)
  STEP 2.G — Context check (nếu >= 80% → FORCE checkpoint, STOP)
```

---

## Step Detail

### Step 2.A: Skip-If-Exists

```bash
# Path tuyệt đối:
TARGET=".mc-data/work/legacy-scan/classified/batch-${N}.json"

if [ -f "$TARGET" ] && [ -s "$TARGET" ]; then
  # Validate JSON nhanh
  if jq -e '.stats.total > 0' "$TARGET" > /dev/null 2>&1; then
    LOG "Skip batch $N — file đã có trên disk, JSON valid"
    completed_batches++  # Cộng vào counter ledger
    CONTINUE  # next loop iteration
  else
    LOG "Batch $N tồn tại nhưng corrupt → xóa, re-classify (E020)"
    rm -f "$TARGET"
    error_log.append({code: "E020", batch: N, action: "deleted_for_reclassify"})
  fi
fi
```

### Step 2.B: Compile EXISTING_MODULES

```
EXISTING_MODULES = []
FOR each .mc-data/work/legacy-scan/classified/batch-*.json:
  jq -r '.items[] | "\(.system)|\(.module)"' batch-*.json
  | sort -u
  → unique (system, module) pairs

Set $EXISTING_MODULES list cho prompt agent.
```

### Step 2.C: Spawn code-reviewer Agent

| Tool | Subagent | Prompt template | Output target |
|------|----------|-----------------|---------------|
| Agent | `code-reviewer` | Xem `_shared.md §Agent Prompt Templates — code-reviewer Agent` | `classified/batch-${N}.json` |

**Inputs cho agent:**
- `batch_size = $BATCH_SIZE`
- `project_name = ledger.project.name`
- `tech_stack`, `frameworks` từ project-profile.json
- `existing_modules_list = $EXISTING_MODULES` (compile từ Step 2.B)
- Slice files cho batch N: `$UNCLASSIFIED_LIST[(loop_index-1) * batch_size : loop_index * batch_size]`
- `docs_only_mode = $DOCS_ONLY_MODE` (nếu true → dùng doc_type categories)
- `output_path = classified/batch-${N}.json`
- `batch_number = N`

**Retry on timeout/fail (E006):**
- Attempt 1: `batch_size = $BATCH_SIZE` (vd: 100)
- Attempt 2: `batch_size = $BATCH_SIZE / 2` (vd: 50) — chia files thành 2 sub-batches, ghi vào batch-N.json (gộp)
- Attempt 3: `batch_size = $BATCH_SIZE / 4` (vd: 25)
- Stop nếu `batch_size < 10` → STOP toàn skill, escalate

### Step 2.D: Validate Batch File

```
1. test -f classified/batch-${N}.json && test -s classified/batch-${N}.json
2. jq '.' classified/batch-${N}.json > /dev/null  (JSON valid)
3. jq -e '.batch_number == '${N} classified/batch-${N}.json
4. jq -e '.stats.total > 0' classified/batch-${N}.json
5. Verify: sum(.stats.by_category[]) == .stats.total

NẾU FAIL bất kỳ check nào:
  → E020, xóa file, re-classify batch N (max 2 retries)
  → Nếu vẫn fail sau 2 retries → log error_log, ASK user
```

### Step 2.E: Update Ledger + Status + Scan-State

```
ledger.stages.classify.completed_batches = (count(classified/batch-*.json valid))

batch_count = jq '.stats.total' classified/batch-${N}.json
$ITEMS_CLASSIFIED += batch_count

UPDATE legacy-scan-status.json:
  stages.classify.completed_batches = ledger value
  stages.classify.items_classified = $ITEMS_CLASSIFIED
  stages.classify.last_batch_completed_at = ISO_NOW
```

**[PHASE D — Scan-state dual-write]**

```
# Append output path to scan-state.layers.L4.outputs[]
append_layer_output("L4", "classified/batch-${N}.json")

# Update batch_progress (used for orchestrator UI + resume)
update_batch_progress("L4", {
  current: N,
  total: $TOTAL_BATCHES,
  completed_batches: list(1..N từ filesystem scan)
})
```

Xem `_shared.md §Scan-State Integration` cho helper signatures.
Nếu helper call fail (missing session, IO error) → log WARNING, tiếp tục (không block).

### Step 2.F: Checkpoint (mỗi 3 batches)

```
IF (N mod 3 == 0):
  # Đọc template checkpoint.json (CORE-031)
  READ .claude/skills/workflow/wf-legacy-classify/templates/checkpoint.json

  POPULATE:
    checkpoint_id = "CP-CLASSIFY-${YYYYMMDD}-${N:03}"
    timestamp = ISO_NOW
    trigger.reason = "batch_complete"
    position.current_phase = "phase2-classify"
    position.current_batch = N
    position.next_action = "Resume từ batch " + (N+1)
    progress.batches_completed = list batches 1..N
    progress.items_classified = $ITEMS_CLASSIFIED
    state.maturity_mode = $MATURITY_MODE
    state.docs_only_mode = $DOCS_ONLY_MODE
    state.batch_size = $BATCH_SIZE
    state.existing_modules = $EXISTING_MODULES (compact list)
    resume_instructions.command = "/wf-legacy-classify --resume"

  WRITE .mc-data/work/legacy-scan/checkpoint.json
```

### Step 2.G: Context Budget Check

```
IF $CONTEXT_PERCENT >= 80%:
  → FORCE checkpoint (Step 2.F bất kể N mod 3)
  → STOP với message: "Context >= 80%, đã checkpoint sau batch ${N}.
     Chạy /wf-legacy-classify --resume để tiếp tục."

IF $CONTEXT_PERCENT >= 90%:
  → FORCE STOP (không cố ghi thêm)
  → User phải resume manual
```

---

## Phase 2 POST-GATE

```
1. Loop kết thúc bình thường (đã chạy hết TOTAL_BATCHES - BATCH_OFFSET iterations)
   HOẶC: STOP do context limit (đã checkpoint)
2. Mọi classified/batch-*.json (đã spawn) là valid JSON
3. ledger.stages.classify.completed_batches == actual count batch files trên disk
4. $ITEMS_CLASSIFIED đã cumulative đúng
5. $EXISTING_MODULES đã update từ tất cả batches
```

> **Lưu ý:** Phase 2 POST-GATE KHÔNG kiểm tra >= 95% — đó là Phase 4. Phase 2 chỉ verify mechanics của loop.

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E006 | Agent timeout/fail per batch | Giảm batch_size / 2 (100→50→25→12). Stop nếu < 10 |
| E020 | Batch JSON corrupt | Xóa file, re-classify batch N (max 2 retries) |

---

**Next phase:** `phase3-glossary.md`
