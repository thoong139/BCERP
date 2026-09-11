# Phase 2: Technical Specs (PARALLEL) — API + Database + Infra

> Ba spec chạy song song — không phụ thuộc lẫn nhau.
> **(Protocol 7 — tuân thủ)** L2: Document Parallel — 3 docs độc lập, không ghi cùng file.
> Integration map SEQUENTIAL ở Phase 3 (cần output từ Phase 2).

**PRE-GATE:**

```bash
test -s .mc-data/docs/phase3-architecture/P3-01-architecture.md
test -n "$SESSION_DIR"
# Verify lane signals từ Phase 1 tồn tại cho mỗi active system
for sys in $ACTIVE_SYSTEMS; do test -s $SESSION_DIR/lanes/$sys/signals.json; done
```

**INPUT (dùng chung cho cả 3):**
- `P3-01-architecture.md`
- `$REGISTRY_DATA`
- `phase2-features/**/*.md` (hoặc `$FEATURE_DIGEST_PATH` nếu có)
- Templates: `.claude/doc-framework/phase3-architecture/technical-specs/{api-contract,database-design,infra-spec}.md`

**OUTPUT (PARALLEL):**
- `.mc-data/docs/phase3-architecture/technical-specs/api-contract.md`
- `.mc-data/docs/phase3-architecture/technical-specs/database-design.md`
- `.mc-data/docs/phase3-architecture/technical-specs/infra-spec.md`

---

## Execution Diagram

```
Option A (ADR-OPT-01 — 1 system = 1 lane, 3 specs là sub-tasks trong lane):

  System A lane ──→ architect (P2-A: api-contract)   ──→ specs-signals.json (sys-a)
                ├── dba + architect (P2-B: database-design)
                └── devops + architect (P2-C: infra-spec)

  System B lane ──→ ... (tương tự)

3 spec files per system viết vào shared technical-specs/ với file-level naming:
  - technical-specs/api-contract.md      (aggregate từ tất cả systems)
  - technical-specs/database-design.md
  - technical-specs/infra-spec.md

Max parallel: Standard 5 agents / LPM 3 agents (xem $LPM_PARAMS.max_parallel_agents)
```

---

## Steps

> **SKIP-IF-EXISTS:** Trước khi spawn mỗi agent, check file đã tồn tại + non-empty.

| Phase | Output | Agent | Prompt ref | Template |
|-------|--------|-------|------------|----------|
| 2.1 | `technical-specs/api-contract.md` | `architect` | `_shared.md` §P2-A | `doc-framework/phase3-architecture/technical-specs/api-contract.md` |
| 2.2 | `technical-specs/database-design.md` | `dba` + `architect` | `_shared.md` §P2-B | `doc-framework/phase3-architecture/technical-specs/database-design.md` |
| 2.3 | `technical-specs/infra-spec.md` | `devops` + `architect` | `_shared.md` §P2-C | `doc-framework/phase3-architecture/technical-specs/infra-spec.md` |

### Detailed steps

| Step | Action | Verify |
|------|--------|--------|
| 2.0.1 | **SKIP-IF-EXISTS Phase 2.1:** `test -f api-contract.md && test -s api-contract.md` → skip, log "api-contract.md đã tồn tại — skip". Ngược lại: spawn `architect` (prompt P2-A) cho mỗi system (trong lane của system đó) | Agent success (hoặc skip) |
| 2.0.2 | **SKIP-IF-EXISTS Phase 2.2:** `test -f database-design.md && test -s database-design.md` → skip. Ngược lại: spawn `dba` + `architect` (prompt P2-B) cho mỗi system (trong lane) | Agent success (hoặc skip) |
| 2.0.3 | **SKIP-IF-EXISTS Phase 2.3:** `test -f infra-spec.md && test -s infra-spec.md` → skip. Ngược lại: spawn `devops` + `architect` (prompt P2-C) cho mỗi system (trong lane) | Agent success (hoặc skip) |
| 2.0.4 | Chạy 2.0.1, 2.0.2, 2.0.3 trong cùng 1 message (PARALLEL). LPM: nếu `max_parallel_agents = 3` → vẫn OK với 3 agents | All agents spawned |
| 2.0.5 | Với mỗi system: ghi `$SESSION_DIR/lanes/{sys}/specs-signals.json` — capture api_ids, db_table_ids, infra_resource_ids từ specs vừa tạo. | `test -s $SESSION_DIR/lanes/{sys}/specs-signals.json` |
| 2.0.6 | Verify cả 3 file tồn tại và non-empty | `test -s api-contract.md && test -s database-design.md && test -s infra-spec.md` |
| 2.0.7 | **SAVE CHECKPOINT (session-state.json):** SET `phases.P2.status = "completed"`, `phases.P2.batches[{sys}].status = "completed"` cho mỗi system. SET `next_action = "phase3-integration"`. Sync → checkpoint.json backward-compat. | `jq '.phases.P2.status' session-state.json → "completed"` |

### Lane output schema (`specs-signals.json`)

```json
{
  "lane_type": "system",
  "system_slug": "{system-slug}",
  "api_items": [
    { "api_id": "API-SYS-001", "method": "POST", "path": "/orders", "module": "order" }
  ],
  "db_items": [
    { "db_table_id": "TBL-SYS-001", "table_name": "orders", "module": "order" }
  ],
  "infra_items": [
    { "infra_resource_id": "INFRA-SYS-001", "type": "container", "name": "api-server" }
  ]
}
```

**Write-scope isolation:** Mỗi system lane ghi vào `technical-specs/` với content tổng hợp per-system → aggregation step ở Phase 3 sẽ dedup theo `api_id`.

---

## Agent Prompt References

Các prompts đầy đủ trong `_shared.md` §Agent Prompt Templates:
- **P2-A** — architect → API Contract
- **P2-B** — dba + architect → Database Design
- **P2-C** — devops + architect → Infra Spec

Nếu `$LEGACY_MODE = true`: mỗi agent prompt PHẢI inject LEGACY BLOCK (xem `_shared.md` §LEGACY Context Injection).

---

## POST-GATE (mỗi phase)

```bash
# T1: File existence + non-empty
test -s .mc-data/docs/phase3-architecture/technical-specs/api-contract.md
test -s .mc-data/docs/phase3-architecture/technical-specs/database-design.md
test -s .mc-data/docs/phase3-architecture/technical-specs/infra-spec.md

# T2: Structure — mỗi file có đúng template sections (grep required headings từ template)
grep -q '^## ' .mc-data/docs/phase3-architecture/technical-specs/api-contract.md
grep -q '^## ' .mc-data/docs/phase3-architecture/technical-specs/database-design.md
grep -q '^## ' .mc-data/docs/phase3-architecture/technical-specs/infra-spec.md

# T3: Content depth — mỗi file >= 300 từ, không placeholder
WORDS_API=$(wc -w < .mc-data/docs/phase3-architecture/technical-specs/api-contract.md)
WORDS_DB=$(wc -w < .mc-data/docs/phase3-architecture/technical-specs/database-design.md)
WORDS_INFRA=$(wc -w < .mc-data/docs/phase3-architecture/technical-specs/infra-spec.md)
[ "$WORDS_API" -ge 300 ] && [ "$WORDS_DB" -ge 300 ] && [ "$WORDS_INFRA" -ge 300 ]
grep -v '<!-- TODO\|TBD\|\.\.\.' .mc-data/docs/phase3-architecture/technical-specs/api-contract.md > /dev/null

# T4: Cross-reference — REQ-IDs referenced, modules match registry
grep -q 'REQ-' .mc-data/docs/phase3-architecture/technical-specs/api-contract.md
```

Nếu bất kỳ file nào FAIL → retry tối đa 3 lần agent đó. Các agents PASS giữ nguyên.

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E003 | Agent timeout / không trả output | Re-spawn 1 lần; nếu vẫn fail → skip + WARNING |
| E007 | Phase verification failed | Retry phase (max 3×) |
| E008 | Max retries exceeded | Escalate với error details |

---

## Next Phase

→ Read `procedures/phase3-integration.md` — Integration Map SEQUENTIAL
