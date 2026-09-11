# §12 CI Detection Pattern (Protocol 20)

> Protocol 20 §20.8. CI tools auto-detect, không hỏi user. Lock held → fallback Grep/Glob.

## CI PRE-GATE (3-step — Phase 1)

| Step | Action | Verify |
|------|--------|--------|
| Na | **Load CI Capabilities:** Run `bash .claude/scripts/ci-detect.sh` → check per-tool TTL. Read `.mc-data/work/_meta/code-intelligence.json` → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. Graceful: lock held → fallback Grep/Glob. | CI flags set |
| Nb | **Index Freshness Check:** Run `bash .claude/scripts/ci-freshness-check.sh` → so sánh HEAD vs index_commit. Parse 4 mức (ok/light/strong/severe). | Freshness status set |
| Nc | **Agent Context Injection:** IF CI available → `bash .claude/scripts/ci-inject-context.sh` → inject vào `$CI_CONTEXT`. | CI context ready |

> **v10.3+ optimization:** Na+Nb+Nc gộp thành 1 wrapper script `.claude/scripts/wf-fix-bugs/ci-pregate.sh`. Cache hit → cả 3 chạy trong ~300ms.

## CI-ROUTE Matrix (Protocol 20 §20.5)

| CI Task | Primary Tool | Secondary | Fallback |
|---------|-------------|-----------|----------|
| `project_structure` | **Serena** `onboarding` | **GitNexus** `clusters` | Glob |
| `understand_flow` | **GitNexus** `query({key_concept})` | **Serena** `get_symbols_overview` | Grep + Read |
| `api_routes` | **GitNexus** `route_map()` | — | Grep |
| `find_by_annotation` | **GitNexus** `cypher` + **Serena** `find_refs` | — | Grep REQ-ID |
| `symbol_overview` | **Serena** `get_symbols_overview` | — | Read |
| `impact_analysis` | **GitNexus** `impact({target, direction:"upstream"})` | — | Grep |

## Cache TTL

| Tool | Available TTL | Absent TTL |
|------|--------------|------------|
| GitNexus | 24h | 4h |
| Serena | 24h | 1h |
