# Phase 6: Consolidate Requirements

> Consolidate requirements từ tất cả dept docs — xử lý chủ yếu in-memory.
> Detect conflicts (log cho Phase 6d xử lý), chuẩn hóa REQ-ID, detect interface_type.

**PRE-GATE:** `test -d .mc-data/docs/phase1-business/departments/`

**INPUT:** Tất cả `[dept].md` (Phần A + Phần B) + `req-registry.json` (in-memory only)

**OUTPUT:** In-memory — `$CONSOLIDATED_REQS`, `$INTERFACE_TYPE`, conflicts log

## Steps

| Step | Action | Verify |
| ---- | ------ | ------ |
| 6.1  | Đọc tất cả `[dept].md` files | All read |
| 6.2  | Detect conflicts giữa experts | Conflicts logged → **giải quyết tại Phase 6d** (scope=all only) |
| 6.2b | **Signal Aggregation (ADR-OPT-04):** Import `_shared/aggregate/aggregator.py` theo `_shared.md §_shared Module Imports`.<br>1. Đọc tất cả `$SESSION_DIR/lanes/*/signals.json` → list `lane_outputs`<br>2. Define `dedup_key_fn = dedup_by_id("req_id")` — normalize REQ-ID (lowercase, strip whitespace, detect dept-prefix mismatch)<br>3. `result = aggregate_lane_signals(lane_outputs, dedup_key_fn=dedup_key_fn)` → `AggregationResult` object<br>4. **Template Strip + Atomic Write** (theo `_shared/_shared.md §1-2`): strip `_template_notes` → tmp → validate → mv → `$SESSION_DIR/aggregation-result.json`<br>Schema: `{total_input, total_output, duplicates, conflicts[], items[]}`<br>5. NẾU `result.conflicts[]` non-empty → flag cho Phase 6d xử lý (append vào `error_log[]` với type="req_id_conflict"). | `test -s $SESSION_DIR/aggregation-result.json && jq -e '.total_input >= .total_output' aggregation-result.json` |
| 6.3  | Chuẩn hóa REQ-ID scheme theo aggregation result — loại duplicates, flag conflicts. Format `REQ-[DEPT]-[NNN]` áp dụng cho mọi item trong `result.items[]`. | All IDs unique hoặc flagged trong conflicts |
| 6.4  | Detect `$INTERFACE_TYPE` (web/mobile/desktop/api-only/web+mobile) | Type determined |
| 6.5  | **SAVE CHECKPOINT:** update `$SESSION_DIR/session-state.json`:<br>— `phases.P6.status = "completed"`<br>— `phases.P6.completed_at = <ISO>`<br>— `phases.P6.aggregation = {dedup_input_count: result.total_input, dedup_output_count: result.total_output, duplicates_removed: result.duplicates, conflict_count: len(result.conflicts)}`<br>— `next_action = "phase6b-workflow"` (nếu scope=all) hoặc `"phase8-registry"`<br>Mirror legacy `checkpoint.json`. Xem `_shared.md §Token Budget & Checkpoint`. | `jq -e '.phases.P6.status == "completed"' session-state.json` |

**POST-GATE:**

```bash
test -n "$CONSOLIDATED_REQS"  # conflicts logged + REQ-IDs chuẩn hóa
test -s $SESSION_DIR/aggregation-result.json
jq -e '.phases.P6.status == "completed"' $SESSION_DIR/session-state.json
# No _template_notes leaked
jq -e 'has("_template_notes") | not' $SESSION_DIR/aggregation-result.json
```

## Content Quality Checks (Protocol 8 — CQG-06)

```
1. COMPLETENESS: Số departments trong P1 docs (phase1-business/departments/) = số departments trong req-registry.json
2. COMPLETENESS: Số modules referenced trong dept docs = số modules trong req-registry.json
3. CONTENT DEPTH: Mỗi section trong dept files (Phần A + Phần B) có >= 2 câu nội dung thực
   (loại trừ headers, bullets rỗng, placeholders)
4. NẾU FAIL: Auto-fix theo Protocol 1 (max 3 iterations) — bổ sung dept thiếu, điền nội dung section rỗng
5. SCOPE COHERENCE (CQG-03): Departments trong Phase 1 output ⊆ departments trong Phase 0 brainstorm (P0-01-brainstorm.md Section 2).
   Nếu Phase 1 có dept không có trong P0 → WARNING + escalate to user (không tự thêm scope)
6. NO HALLUCINATION (CQG-04): Mỗi REQ-ID trong dept docs phải trace back đến user input hoặc brainstorm context.
   REQ-IDs xuất hiện trong dept docs mà KHÔNG có anchor trong P0/user input → FLAG + xóa khỏi docs + registry
```

**Status update:** `analyze-status.json` → `phase_6.status = "completed"`, `phase_6.interface_type = "$INTERFACE_TYPE"`.

**Next phase:**
- Nếu `$SCOPE = "all"` → `phase6b-workflow.md`
- Nếu không → `phase8-registry.md`
