# Phase 3: Integration Map (SEQUENTIAL)

> Thiết kế integration points và cross-system rules — chỉ chạy **sau khi 2.1 và 2.2 hoàn thành**.
> Cross-system rules đã được merge vào integration-map.md (sections 7–9).

**PRE-GATE:**

```bash
test -s .mc-data/docs/phase3-architecture/technical-specs/api-contract.md
test -s .mc-data/docs/phase3-architecture/technical-specs/database-design.md
test -n "$SESSION_DIR"
# Verify specs-signals.json tồn tại cho mỗi active system
for sys in $ACTIVE_SYSTEMS; do test -s $SESSION_DIR/lanes/$sys/specs-signals.json; done
```

**INPUT:**
- `P3-01-architecture.md`
- `api-contract.md`
- `database-design.md`
- `phase2-features/**/*.md`
- Template `.claude/doc-framework/phase3-architecture/technical-specs/integration-map.md`

**OUTPUT:** `.mc-data/docs/phase3-architecture/technical-specs/integration-map.md`

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 3.0 | **Signal Aggregation — Phase 1 (ADR-OPT-04):** Import `_shared/aggregate` → `aggregate_lane_signals(lane_outputs=$SESSION_DIR/lanes/*/signals.json, dedup_key_fn=dedup_by_id("component_id"))`. Output: `$SESSION_DIR/aggregation-result.json` — phần `"components": [...]`. IF `conflicts[]` non-empty → log sang `$SESSION_DIR/aggregation-conflicts.json`, flag cho Phase 4. | `jq '.components \| length > 0' aggregation-result.json` |
| 3.0b | **Signal Aggregation — Phase 2 (api_id dedup):** `aggregate_lane_signals(specs-signals, dedup_by_id("api_id"))`. Merge kết quả vào `$SESSION_DIR/aggregation-result.json` — thêm phần `"apis": [...]`. | `jq 'has("apis")' aggregation-result.json → true` |
| 3.1 | **SKIP-IF-EXISTS:** `test -f integration-map.md && test -s integration-map.md` → skip, log "integration-map.md đã tồn tại — skip". Ngược lại: spawn `architect` (prompt P3 trong `_shared.md`) — truyền `$SESSION_DIR/aggregation-result.json` làm input thay vì parse per-system files. | Agent success (hoặc skip) |
| 3.2 | Verify output: `technical-specs/integration-map.md` tồn tại | `test -s integration-map.md` |
| 3.3 | **SAVE CHECKPOINT (session-state.json):** SET `phases.P3.status = "completed"`, `next_action = "phase4-crossval"`. Sync → checkpoint.json. | `jq '.phases.P3.status' session-state.json → "completed"` |

---

## Agent Prompt

Xem `_shared.md` §Agent Prompt Templates §P3 — architect (Phase 3 — Integration Map).
Nếu `$LEGACY_MODE = true`: inject LEGACY BLOCK (xem `_shared.md` §LEGACY Context Injection).

---

## POST-GATE

```bash
# T1: File existence + non-empty
test -s .mc-data/docs/phase3-architecture/technical-specs/integration-map.md

# T2: Structure — đúng template structure (integration points + cross-system rules sections 1-9)
HEADINGS=$(grep -c '^## ' .mc-data/docs/phase3-architecture/technical-specs/integration-map.md)
[ "$HEADINGS" -ge 5 ]

# T3: Content depth — >= 300 words, no placeholders
WORDS=$(wc -w < .mc-data/docs/phase3-architecture/technical-specs/integration-map.md)
[ "$WORDS" -ge 300 ]
grep -v '<!-- TODO\|TBD\|\.\.\.' .mc-data/docs/phase3-architecture/technical-specs/integration-map.md > /dev/null

# T4: Cross-reference — REQ-IDs referenced, integration points reference existing modules
grep -q 'REQ-' .mc-data/docs/phase3-architecture/technical-specs/integration-map.md
```

Nếu FAIL → retry (max 3×). Nếu vẫn fail → E006 (Integration map inconsistency).

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E003 | Agent timeout | Retry, hoặc design inline |
| E006 | Integration map inconsistency | Re-run Phase 3 |

---

## Next Phase

→ Read `procedures/phase4-crossval.md` — Cross-Validation Auto-Correction Loop
