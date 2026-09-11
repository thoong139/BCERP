# Protocol 20 — Code Intelligence Integration

> GitNexus + Serena auto-detection, lock-protected cache, per-tool TTL, index freshness check, task routing, graceful degradation, agent context injection.
> Mọi skill dùng chung cơ chế này qua Protocol 20, không implement riêng lẻ.
> **CI-ROUTE là convention trong Protocol 20** — skill agent đọc routing matrix §20.5 để chọn tool.

---

## 20.1 Detection + Lock

### Flow

```
Skill PRE-GATE:
  0. Short-circuit: if not git repo → skip all CI detection, use Grep/Glob
  1. mkdir -p .mc-data/work/_meta (create if not exists)
  2. Check cache freshness (per-tool TTL §20.2)
     ├── ALL FRESH → load cache, skip to freshness check §20.3
     └── ANY STALE or MISSING →
         Try acquire .ci-cache.lock (atomic: set -C noclobber)
         ├── ACQUIRED:
         │   a. git remote get-url origin → disambiguate repo (§20.4)
         │   b. Gọi MCP tools detect GitNexus + Serena
         │   c. git rev-parse HEAD → index_commit
         │   d. Write cache (create dir if needed) → release lock
         └── NOT ACQUIRED (lock held by peer):
             a. Check lock staleness (>60s) → break + acquire
             b. If valid lock → exit 2 → fallback Grep/Glob (no regression)
  3. ci-freshness-check.sh: compare HEAD vs index_commit
  4. Inject CI context vào agent prompts (§20.7)
```

### Lock File

| Field | Value |
|-------|-------|
| **File** | `.mc-data/work/_meta/.ci-cache.lock` |
| **Format** | `PID\|host\|user\|acquired_at\|heartbeat_at` (pipe-separated) |
| **Acquire** | `( set -C; echo "..." > "$LOCK_FILE" )` — atomic noclobber, no race condition |
| **Release** | `rm -f "$LOCK_FILE"` |
| **Stale detection** | 60 giây — nếu `heartbeat_at` > 60s ago → break + acquire |
| **Lock held → fallback** | exit 2 → caller fallback Grep/Glob NGAY (không chờ, không block, zero regression) |

### Two-Phase Detection Handoff (D2)

```
Phase 1: ci-detect.sh (no args)
  → Check per-tool TTL → signal skill agent
     Exit 0 + JSON {status: "all_fresh"}     → load cache, skip MCP calls
     Exit 0 + JSON {status: "needs_scan"}    → proceed to MCP detection
     Exit 2 + JSON {status: "lock_held"}     → fallback Grep/Glob
     Exit 1 + JSON {status: "no_git"}        → skip CI, use Grep/Glob

Phase 2: ci-detect.sh --write-cache '<json>'
  → Skill agent passes MCP detection results → script writes cache → releases lock
     Exit 0: at least 1 CI tool available
     Exit 1: no CI tools available
```

---

## 20.2 Per-Tool TTL

Mỗi tool có TTL riêng, phản ánh khả năng thay đổi thực tế. Implementation: pure bash integer arithmetic (seconds), không `bc` (F21).

| Tool | TTL | Lý do |
|------|-----|-------|
| GitNexus `available=true` | **24h** (86400s) | Đã index, hiếm khi gỡ |
| GitNexus `available=false` | **4h** (14400s) | User có thể cài GitNexus + `gitnexus analyze` giữa phiên |
| Serena `available=true` | **24h** (86400s) | Đã onboard, ổn định |
| Serena `available=false` | **1h** (3600s) | User có thể cài Serena bất cứ lúc nào |

**Escape hatch:** `MCV3_CI_RESCAN=1` cho user advanced. **Respects lock** — nếu lock bị giữ, env var không override lock.

```bash
# Per-tool TTL check (pure bash integer arithmetic)
elapsed_seconds=$(( $(date +%s) - $(date -d "$checked_at" +%s) ))
ttl_seconds=$(( ttl_hours * 3600 ))
if (( elapsed_seconds < ttl_seconds )); then echo "fresh"; else echo "stale"; fi
```

---

## 20.3 Index Freshness Check

**Chạy mỗi PRE-GATE, không cache.** Chi phí: `git rev-parse HEAD` + `git rev-list --count` < 0.01 giây.

### Flow

```
1. Short-circuit: if not git repo (git rev-parse fails) → skip, exit 0
2. current=$(git rev-parse HEAD)
3. indexed=$(jq -r '.gitnexus.index_commit' code-intelligence.json)
4. behind=$(git rev-list --count $indexed..$current 2>/dev/null || echo "unknown")

5. Cảnh báo theo mức:
   behind = 0      → OK, dùng CI tools bình thường
   behind = 1-5    → WARNING: "GitNexus index behind HEAD by N commits.
                     Impact analysis may miss recent changes."
   behind = 6-20   → STRONG WARNING: "Index significantly behind (N commits).
                     Consider: gitnexus analyze"
   behind > 20     → SEVERE: "Index is 20+ commits behind HEAD. Impact analysis
                     likely incomplete. Recommend re-index before continuing."
   behind = unknown → Skip check (index_commit missing / not in history)
```

### Non-git project

Nếu `git rev-parse HEAD` fails → không phải git repo → skip toàn bộ freshness check (exit 0, status="skipped", reason="not a git repository").

---

## 20.4 Repo Disambiguation

Khi máy có nhiều GitNexus-indexed repos, skill phải xác định đúng repo cho target project.

### Flow

```
Khi GitNexus available (trong MCP detection phase):
  1. git remote get-url origin → extract repo name từ URL
     https://github.com/user/eureka-2026.git → "eureka-2026"
     git@github.com:user/eureka-2026.git → "eureka-2026"
  2. gitnexus_list_repos() → danh sách available repos
  3. Match logic:
     a. Exact name match với repo name từ origin → dùng repo đó
     b. Partial match (repo name chứa origin name hoặc ngược lại) → dùng repo đó
     c. Multiple matches → ưu tiên exact match → ưu tiên path match với CWD
     d. Zero matches → GitNexus available=false (không có index cho repo này)
  4. Lưu repo name vào cache: gitnexus.repo
  5. Tất cả gitnexus_*() calls sau đó dùng `repo: "REPO_NAME"`
```

---

## 20.5 Task → Tool Routing Matrix (CI-ROUTE Convention)

**CI-ROUTE là convention** — skill agent đọc matrix này để chọn tool. KHÔNG phải script riêng.

| CI Task | Tool chính | Tool bổ trợ | Fallback |
|---------|-----------|-------------|----------|
| `find_definition` | **Serena** `find_definition` | — | Grep |
| `find_references` | **Serena** `find_references` | GitNexus `context()` | Grep |
| `impact_analysis` | **GitNexus** `impact()` | Serena `find_references` | Manual grep |
| `understand_flow` | **GitNexus** `query()` | Serena `get_symbols_overview` | Read + trace |
| `safe_rename` | **Serena** `rename_symbol` | GitNexus `rename()` | Manual |
| `detect_changes` | **GitNexus** `detect_changes()` | — | `git diff` |
| `project_structure` | **Serena** `onboarding` | GitNexus `clusters` | Glob |
| `api_routes` | **GitNexus** `route_map()` | — | Grep |
| `symbol_overview` | **Serena** `get_symbols_overview` | — | Read |
| `pre_commit_check` | **GitNexus** `detect_changes()` | — | `git diff --stat` |
| `find_by_annotation` | **Both** — GitNexus cypher + Serena find_refs | — | Grep REQ-ID |
| `index_freshness` | **Git** `rev-parse HEAD` vs `index_commit` | — | Skip check |

---

## 20.6 Graceful Degradation

3-tier fallback: **Primary → Secondary → Grep/Glob**

```
QUY TẮC:
- Tool unavailable → log WARNING → try secondary
- Secondary unavailable → log WARNING → fallback Grep/Glob
- Lock bị giữ → fallback Grep/Glob ngay (không block, zero regression)
- Non-git project → skip all CI, use Grep/Glob
- Tool MCP error → log ERROR → fallback
- KHÔNG block execution trong bất kỳ trường hợp nào
- KHÔNG hỏi user (D7: zero-prompt design)
```

Tất cả fallback path đều dẫn về hành vi Grep/Glob hiện tại của MCV3 → **zero regression**.

---

## 20.7 Agent Context Injection

CI context được inject vào agent prompt khi spawn. **Không sửa bất kỳ agent definition file nào (D5).**

Context templates (4 loại):

### Template 1: Both Available + Freshness OK

```
## Code Intelligence: GitNexus + Serena

Both GitNexus (graph: {repo}, {symbols} symbols, {flows} flows) and
Serena (LSP: {languages}) are available. Index up to date (HEAD).

GUIDELINE:
- System-level (impact, flows, routes) → GitNexus
- Symbol-level (def, refs, rename) → Serena
- Pre-commit → GitNexus detect_changes()
```

### Template 2: Both Available + Index Stale

```
## Code Intelligence: GitNexus + Serena

Both GitNexus (graph: {repo}, {symbols} symbols, {flows} flows) and
Serena (LSP: {languages}) are available.

WARNING GitNexus index is {N} commits behind HEAD.
Impact analysis and query results may be incomplete.
Recommend: `gitnexus analyze` to refresh index.

GUIDELINE:
- System-level (impact, flows, routes) → GitNexus (with caveat)
- Symbol-level (def, refs, rename) → Serena (unaffected by index)
```

### Template 3: GitNexus-only

```
## Code Intelligence: GitNexus

GitNexus is available ({repo}, {symbols} symbols, {flows} flows).
- Before editing any symbol → gitnexus_impact({target, direction: "upstream"})
- Exploring code → gitnexus_query({query: "concept"})
- Pre-commit → gitnexus_detect_changes()
- NEVER rename with find-and-replace — use gitnexus_rename
```

### Template 4: Serena-only

```
## Code Intelligence: Serena

Serena LSP tools are available ({languages}).
- find_definition → precise go-to-definition
- find_references → all call sites
- rename_symbol → safe refactoring (not find-and-replace)
- get_symbols_overview → file structure
```

---

## 20.8 Skill Integration Pattern

### PRE-GATE CI Integration Pattern (Áp dụng cho mọi skill)

3 sub-steps tại PRE-GATE:

#### Step 0.Na: Load Code Intelligence Capabilities

```
1. ci-detect.sh → check per-tool TTL
   ├── ALL fresh → load cache, exit 0 (check_index_age: WARNING stderr nếu > 7 ngày)
   ├── ANY stale → acquire lock → scan MCP tools → write cache → release, exit 0
   └── Lock held → exit 2 → fallback Grep/Glob (current behavior, no regression)

2. Read .mc-data/work/_meta/code-intelligence.json
3. Set $GITNEXUS_AVAILABLE, $SERENA_AVAILABLE
```

**Graceful:**
- ci-detect.sh fail → WARNING → continue without CI tools
- Lock held → fallback Grep/Glob ngay (không chờ, không block)
- Non-git project → exit 1 → skip all CI, use Grep/Glob

#### Step 0.Nb: Index Freshness Check

```
1. ci-freshness-check.sh → so sánh HEAD vs index_commit
2. Parse exit code + JSON output:
   exit 0 (ok)       → continue with full CI
   exit 1 (light, ≤5) → continue, slight warning in context
   exit 2 (strong, 6-20) → continue, prominent warning in context
   exit 3 (severe, >20)  → continue, urgent warning; suggest re-index
3. Lưu freshness status để inject vào agent context
4. Nếu SEVERE (>20 behind) → hiển thị cảnh báo cho user
5. Short-circuit: không phải git repo → skip (exit 0, status="skipped")
```

**Graceful:**
- ci-freshness-check.sh fail → skip freshness check → continue
- Git short-circuit (D9): không git repo → skip Nb

#### Step 0.Nc: Agent Context Injection

```
1. Nếu CI available → ci-inject-context.sh → append vào agent spawn instructions
   4 templates được chọn tự động:
   - Both-OK: GitNexus + Serena available, index fresh
   - Both-Stale: GitNexus + Serena available, index stale (kèm freshness warning)
   - GitNexus-only: Chỉ GitNexus, kèm freshness warning nếu stale
   - Serena-only: Chỉ Serena (real-time, không bị ảnh hưởng bởi index)
2. Nếu no CI → ci-inject-context.sh exit 1 → continue with Grep/Glob (current behavior)
3. Kèm freshness warning trong agent context (Both-Stale/GitNexus-only khi index stale)
```

**Graceful:**
- ci-inject-context.sh exit 1 → no CI context injected → agent dùng Grep/Glob
- Mỗi template < 600 chars (Both-Stale ~520 chars với warning)
- Không sửa agent .md files (D5 injection-only)

### Skill execution flow với CI

```
PRE-GATE:
  Step 0.Na: Load CI capabilities (ci-detect.sh)
  Step 0.Nb: Index Freshness Check (ci-freshness-check.sh)
  Step 0.Nc: Agent Context Injection (ci-inject-context.sh)

PRE-EXECUTION:
  Select tools based on CI-ROUTE matrix (§20.5)
  Inject CI context vào agent prompt (§20.7, khi spawn agents)

POST-EXECUTION:
  Log tool usage: tool_used, primary/secondary/fallback, task, duration_ms
  Log freshness: behind_commits, freshness_level, repo
  Export vào session-log.json (CORE-026)
```

### Pattern variations per skill architecture

| Skill type | CI integration point |
|------------|---------------------|
| **Direct execution** (wf-implement-feature) | PRE-GATE 3-step (Na/Nb/Nc); safety gate + TDD dùng CI-ROUTE |
| **Orchestrator** (wf-fix-bugs) | PRE-GATE freshness check (Na/Nb); sub-skills (triage, execute) tự inject CI context (Nc) |
| **Phase-based** (wf-manage-change, wf-design) | PRE-GATE detection + freshness (Na/Nb/Nc); phase execution dùng CI-ROUTE |
| **Stage-based** (wf-legacy-scan) | PRE-GATE detection + freshness (Na/Nb/Nc); stages dùng CI tools cho inventory/extract |
| **Flow-only** (wf-verify-sync) | CI-ROUTE annotations trong SKILL.md flow, không modify procedure files |

---

## 20.9 Multi-Developer Considerations

- **Cache là local per máy:** `.mc-data/` không được git-sync → mỗi developer có cache riêng
- **Index freshness là bắt buộc trong team:** sau `git pull`, `HEAD` thay đổi → freshness check phát hiện stale index
- **Mỗi developer tự re-index:** `gitnexus analyze` + `serena onboarding` là trách nhiệm per-developer
- **Lock không cross-host:** mỗi máy có lock file riêng → không conflict giữa các developer
- **Cùng máy, 2 terminal:** lock bảo vệ cache write → session thứ 2 fallback Grep/Glob ngay → lần chạy sau cache HIT

### Scenario: Dev A push, Dev B chưa re-index

```
Dev A: commit + push abc123 (OrderService.cs mới)
Dev B: git pull → HEAD=abc123, index=def456 (cũ)
Dev B: /wf-implement-feature Payment
       PRE-GATE freshness: behind=3 → WARNING
       gitnexus_impact("OrderService") → thiếu code mới của Dev A
       → Agent được cảnh báo: "Results may be incomplete"
```

---

## 20.10 Cache Schema & Migration

### Schema v2

```json
{
  "schema_version": 2,
  "gitnexus": {
    "available": true,
    "repo": "EUREKA-2026",
    "symbols": 169028,
    "relationships": 339036,
    "execution_flows": 300,
    "index_commit": "2ee602bb",
    "indexed_at": "2026-05-01T00:00:00Z",
    "checked_at": "2026-05-06T10:00:00Z",
    "ttl_hours": 24
  },
  "serena": {
    "available": true,
    "onboarded": true,
    "languages": ["csharp", "typescript"],
    "checked_at": "2026-05-06T10:00:00Z",
    "ttl_hours": 24
  },
  "scanned_at": "2026-05-06T10:00:00Z",
  "scan_duration_ms": 1200
}
```

### Migration v1→v2

`ci-detect.sh` tự động detect schema version và migrate:

```bash
SCHEMA_VERSION=$(jq -r '.schema_version // 1' "$CACHE_FILE" 2>/dev/null || echo "1")
if [[ "$SCHEMA_VERSION" == "1" ]] || [[ "$SCHEMA_VERSION" -lt 2 ]]; then
  echo "[ci-detect] Cache schema v1 detected — forcing re-scan for v2 migration"
  rm -f "$CACHE_FILE"
fi
```

Cache v0 (không có `schema_version` field) hoặc v1 → tự động re-scan → v2.

### Validate

```bash
jq -e '.' "$CACHE_FILE" > /dev/null 2>&1 || { rm -f "$CACHE_FILE"; return 1; }
```

---

## 20.11 Observability

Mỗi CI tool usage được log vào session-log.json (CORE-026):

```json
{
  "event": "CI_TOOL_USED",
  "task": "find_references",
  "primary": "serena_find_references",
  "secondary": null,
  "fallback_used": false,
  "duration_ms": 340,
  "result_count": 12,
  "freshness_behind_commits": 0,
  "freshness_level": "ok"
}
```

Fields:
- `primary`: tool được sử dụng (serena_find_references, gitnexus_impact, etc.)
- `secondary`: tool bổ trợ (nếu có)
- `fallback_used`: true nếu primary/secondary fail → fallback Grep
- `freshness_behind_commits`: số commits index behind HEAD
- `freshness_level`: ok | warning | strong_warning | severe | unknown

---

## Quick Reference

| Section | Topic |
|---------|-------|
| §20.1 | Detection + Lock (flow, lock file, two-phase handoff) |
| §20.2 | Per-Tool TTL (GitNexus 24h/4h, Serena 24h/1h) |
| §20.3 | Index Freshness Check (4 mức cảnh báo, non-git short-circuit) |
| §20.4 | Repo Disambiguation (git remote → match GitNexus repos) |
| §20.5 | CI-ROUTE Routing Matrix (12 tasks → primary/secondary/fallback) |
| §20.6 | Graceful Degradation (3-tier, lock fallback, zero regression) |
| §20.7 | Agent Context Injection (4 templates, D5 injection-only) |
| §20.8 | Skill Integration Pattern (PRE-GATE 2-step + variations) |
| §20.9 | Multi-Developer Considerations |
| §20.10 | Cache Schema & Migration (v2 schema, v1→v2 auto-migrate) |
| §20.11 | Observability (CI_TOOL_USED log event) |
