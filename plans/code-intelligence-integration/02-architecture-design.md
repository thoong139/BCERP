# Architecture Design — Code Intelligence Integration

> **Date:** 2026-05-06 (revised 2026-05-06 — v0.3 codebase reconciliation)
> **Status:** DRAFT v0.3
> **Changes v0.3:** D5 resolved (injection-only, remove §2.3 agent mods), +D11 repo disambiguation, removed ci-route.sh (làm convention), template path → `skills/templates/`, bc→pure bash int, lock timeout 60s, GitNexus-absent TTL 4h, +mkdir -p + git short-circuit, +v1→v2 migration, +non-git handling, +token measurement methodology
> **Changes v0.2:** +D8 lock-first cache write, +D9 index freshness check, +D10 per-tool TTL, +Multi-Dev scenarios (§8), updated cache schema, updated integration points

---

## 1. Component Overview

```
                        ┌──────────────────────────┐
                        │   CLAUDE.md (MCV3)        │
                        │   + GitNexus section       │
                        │   + Serena section         │
                        └────────────┬─────────────┘
                                     │
                        ┌────────────▼─────────────┐
                        │   Protocol 20             │
                        │   20-code-intelligence.md │
                        │   + CI-ROUTE convention   │
                        └────────────┬─────────────┘
                                     │
              ┌──────────────────────┼──────────────────────┐
              │                      │                      │
    ┌─────────▼─────────┐  ┌────────▼────────┐  ┌──────────▼──────────┐
    │ ci-detect.sh      │  │ ci-freshness-   │  │ ci-inject-context.sh│
    │ (detection + lock │  │ check.sh        │  │ (agent injection)   │
    │  + repo disambig) │  │ (HEAD vs index) │  └──────────┬──────────┘
    └─────────┬─────────┘  └────────┬────────┘             │
              │                      │             ┌──────────▼──────────┐
    ┌─────────▼─────────┐  ┌────────▼────────┐    │ Agent prompt        │
    │ code-intelligence │  │ Freshness JSON  │    │ augmentation        │
    │ .json (cache)     │  │ + warning level │    │ + freshness warning │
    │ .ci-cache.lock    │  └─────────────────┘    └─────────────────────┘
    └───────────────────┘

CI-ROUTE: Convention trong Protocol 20 — skill agent đọc routing matrix để chọn tool.
         KHÔNG phải script riêng.
```

## 2. File Change Map

### 2.1. New Files

| File | Purpose | Lines (est.) |
|------|---------|--------------|
| `.claude/skills/protocols/20-code-intelligence.md` | Protocol: detect, lock, route, degrade, freshness, repo disambig, multi-dev | ~220 |
| `.claude/scripts/ci-detect.sh` | Detection + lock acquire/release + repo disambig + cache write (pure bash, no bc) | ~140 |
| `.claude/scripts/ci-freshness-check.sh` | Compare HEAD vs index_commit, warn levels + git short-circuit | ~50 |
| `.claude/scripts/ci-inject-context.sh` | Generate agent context injection snippet + freshness warning | ~70 |
| `.claude/skills/templates/code-intelligence.schema.json` | Schema cho cache file (v2: +index_commit, +checked_at per tool, +repo) | ~50 |

### 2.2. Modified Files

| File | Change | Impact |
|------|--------|--------|
| `CLAUDE.md` | Thêm "Code Intelligence" section, cập nhật GitNexus section | MCV3 self |
| `.claude/skills/protocols/README.md` | Thêm entry cho Protocol 20 | Reference |
| `.claude/skills/workflow/wf-implement-feature/SKILL.md` | Thêm CI step references + freshness check | S3 |
| `.claude/skills/workflow/wf-implement-feature/procedures/phase0-7-safety-gate.md` | Replace Grep với CI routing + freshness check | S3 |
| `.claude/skills/workflow/wf-implement-feature/procedures/phase3-tdd.md` | Pre-edit impact analysis + post-edit detect_changes | S3 |
| `.claude/skills/workflow/wf-fix-bugs/SKILL.md` | PRE-GATE freshness check (orchestrator level) | S4 |
| `.claude/skills/workflow/wf-fix-triage/SKILL.md` | CI references trong Phase 2 (bug investigation) | S4 |
| `.claude/skills/workflow/wf-fix-execute/SKILL.md` | CI references trong Phase 3 (pre-fix impact) | S4 |
| `.claude/skills/workflow/wf-manage-change/SKILL.md` | Thêm CI step references + freshness check | S5 |
| `.claude/skills/workflow/wf-manage-change/procedures/phase2-impact.md` | Automated impact via GitNexus | S5 |
| `.claude/skills/workflow/wf-legacy-scan/SKILL.md` | Thêm CI step references + freshness check | S5 |
| `.claude/skills/workflow/wf-legacy-scan/procedures/phase1-inventory.md` | Serena onboarding + GitNexus clusters | S5 |
| `.claude/skills/workflow/wf-legacy-scan/procedures/phase3-extract.md` | GitNexus cypher REQ-ID search | S5 |
| `.claude/skills/workflow/wf-design/SKILL.md` | Thêm CI step references + freshness check | S5 |
| `.claude/skills/workflow/wf-design/procedures/phase0-context.md` | GitNexus route_map + processes | S5 |
| `.claude/skills/workflow/wf-verify-sync/SKILL.md` | Thêm CI step references + freshness check (SKILL.md flow-level — procedure files không cần modify) | S6 |
| `.claude/skills/workflow/wf-plan-modules/SKILL.md` | Thêm CI step references + freshness check | S6 |
| `.claude/skills/workflow/wf-plan-modules/procedures/phase2-deps.md` | GitNexus clusters + Serena overview | S6 |

### 2.3. Reference-Only (Context Injection — D5: KHÔNG sửa agent .md)

Tất cả agent context được inject qua prompt khi spawn. **Không sửa bất kỳ agent definition file nào.**

Context templates (3 loại) được định nghĩa trong `ci-inject-context.sh`:
- **Both available:** GitNexus + Serena guidelines
- **GitNexus-only:** impact analysis + query + detect_changes guidelines
- **Serena-only:** find_def + find_refs + rename_symbol guidelines

Mỗi template < 600 chars. Kèm freshness warning khi index stale.

---

## 3. Design Decisions

### D1: Protocol-first approach

**Decision:** Tạo Protocol 20 làm single source of truth. Skills reference protocol, không copy logic.

**Rationale:**
- Tuân thủ CORE-031 (Template Usage): mọi output phải từ template
- Tránh inconsistency giữa các skills
- Dễ update: thay đổi routing logic ở 1 nơi

**Trade-off:** Thêm 1 file protocol (~220 lines). Protocol cần được load khi skill chạy.

---

### D2: Bash scripts cho cache management + git operations (không inline)

**Decision:** `ci-detect.sh`, `ci-freshness-check.sh`, và `ci-inject-context.sh` là bash scripts.

**Rationale:**
- Bash script output là JSON → skill chỉ cần Read kết quả (~200 tokens)
- Inline detection logic trong SKILL.md tốn ~2000-3000 tokens mỗi lần chạy
- Bash script chạy được trên cả Git Bash và WSL (Windows compatibility)
- `ci-freshness-check.sh` dùng `git rev-parse` + `git rev-list` (<0.01s) — không thể làm inline rẻ hơn
- **Pure bash integer arithmetic** (không `bc`) để tương thích Git Bash

**Trade-off:** Thêm dependency vào jq (đã có sẵn trong MCV3). MCP tools chỉ accessible từ Claude agent → bash scripts xử lý cache management + git operations + repo disambiguation, detection thực tế do skill PRE-GATE thực hiện qua MCP tools.

**Detection handoff protocol:**
1. `ci-detect.sh` check per-tool TTL → nếu ANY stale → try acquire lock
2. Nếu lock acquired → exit 0 (signal cho skill: "proceed with MCP detection")
3. Skill agent gọi MCP tools (`mcp__gitnexus__list_repos`, `mcp__serena__check_onboarding_performed`)
4. Skill agent gọi `ci-detect.sh --write-cache "{json}"` để ghi kết quả + release lock
5. Nếu lock NOT acquired → exit 2 (signal: "fallback Grep/Glob")

---

### D3: Per-tool TTL (thay thế TTL 24h thống nhất)

**Decision:** Mỗi tool có TTL riêng, phản ánh khả năng thay đổi thực tế.

**TTL values (revised v0.3):**

| Tool | TTL | Rationale |
|------|-----|-----------|
| GitNexus `available=true` | 24h | Đã index rồi thì hiếm khi gỡ |
| GitNexus `available=false` | **4h** | User có thể cài GitNexus + chạy `gitnexus analyze` giữa phiên |
| Serena `available=true` | 24h | Đã onboard thì ổn định |
| Serena `available=false` | **1h** | User có thể cài Serena bất cứ lúc nào |

**Implementation:** TTL stored as seconds in cache, compared with integer arithmetic:
```bash
elapsed_seconds=$(( $(date +%s) - $(date -d "$checked_at" +%s) ))
ttl_seconds=$(( ttl_hours * 3600 ))
if (( elapsed_seconds < ttl_seconds )); then echo "fresh"; else echo "stale"; fi
```

**Escape hatch:** `MCV3_CI_RESCAN=1` — user advanced có thể force re-scan. **Respects lock** — nếu lock bị giữ, env var không override.

**Rationale for GitNexus-absent change (24h→4h):**
- User có thể cài GitNexus CLI + chạy `gitnexus analyze` giữa phiên làm việc
- Nếu `available=false` với TTL 24h, user index project lúc 10h sáng nhưng skill vẫn không thấy đến 10h sáng hôm sau
- 4h đủ dài để tránh scan mỗi lần, đủ ngắn để bắt kịp user action

---

### D4: Serena ưu tiên cho precision, GitNexus cho graph

**Decision:** Routing matrix ưu tiên Serena cho symbol-level tasks (find_def, find_refs, rename), GitNexus cho system-level tasks (impact, flow, routes).

**Rationale:**
- Serena dùng LSP → kết quả chính xác ở mức symbol (không false positives)
- GitNexus dùng graph → hiểu được relationships và execution flows
- Kết hợp cả hai cho tasks như find_references: Serena cho precision, GitNexus cho context

**Trade-off:** Với find_references, có thể có sự khác biệt nhỏ giữa hai tool (GitNexus index có thể stale hơn LSP real-time). **Mitigated bởi D9 (index freshness check).**

---

### D5: Context injection qua agent prompt (KHÔNG sửa agent .md)

**Decision:** CI context được inject vào agent prompt khi spawn. **Không sửa bất kỳ agent definition file nào.**

**Rationale:**
- Không cần sửa 62 files (BHV-003: Surgical Changes)
- Context injection có thể conditional (chỉ inject khi CI available)
- Dễ update: thay đổi injection logic ở 1 nơi (`ci-inject-context.sh`)
- Có thể kèm freshness warning vào context
- Agent definition files giữ nguyên → không risk breaking existing agent behavior

**Cách thực hiện:**
```
Khi skill spawn agent:
  1. Đọc code-intelligence.json
  2. Chạy ci-freshness-check.sh → đánh giá index staleness
  3. Nếu GitNexus available → chạy ci-inject-context.sh → append context
  4. Nếu Serena available → append context
  5. Spawn agent với augmented prompt (context nằm trong task instructions)
```

**Trade-off:** Agent không tự nhớ là có GitNexus/Serena nếu context bị truncate. Nhưng đây là vấn đề chung của context injection, không riêng CI.

---

### D6: Graceful degradation 3 tầng

**Decision:** Mọi CI task có 3 tầng fallback: Primary Tool → Secondary Tool → Grep/Glob.

**Ví dụ cho `find_references`:**
```
1. Serena find_references (primary — LSP precision)
2. Nếu Serena fail/unavailable → GitNexus context() (secondary — graph)
3. Nếu cả hai fail → Grep (fallback — current behavior)
```

**Rationale:** Đảm bảo skills không bao giờ block vì thiếu tool.

---

### D7: Không hỏi user (zero-prompt design)

**Decision:** Hệ thống tự quyết định dùng tool nào. Không hỏi "Bạn có muốn dùng GitNexus không?"

**Rationale:**
- Người dùng mục tiêu là người không chuyên
- Nếu tool available → dùng. Nếu không → fallback.
- Ngoại lệ duy nhất: GitNexus index stale → 1 dòng cảnh báo (WARNING, không block)
- Escape hatch cho user advanced: `MCV3_CI_RESCAN=1` (không cần biết cache file, respects lock)

---

### D8: Lock-first cache write với graceful fallback (KHÔNG block)

**Decision:** Dùng lock file `.mc-data/work/_meta/.ci-cache.lock` bảo vệ ghi cache. Khi lock bị giữ, skill KHÔNG chờ — fallback ngay về Grep/Glob.

**Cơ chế lock:**

```
File: .mc-data/work/_meta/.ci-cache.lock
Format: {
  "pid": 12345,
  "host": "DESKTOP-XXX",
  "user": "hanoi",
  "acquired_at": "2026-05-06T10:00:00Z",
  "heartbeat_at": "2026-05-06T10:00:01Z"
}
Stale detection: 60 giây (detection takes ~3-5s, so 60s is generous but not excessive)
```

**Flow khi cache miss/stale:**

```
Skill PRE-GATE:
  0. mkdir -p .mc-data/work/_meta (create if not exists)
  1. Check if git repo → if not, skip all CI, use Grep/Glob
  2. Check cache → MISS or STALE
  3. Try acquire .ci-cache.lock
     ├── ACQUIRED:
     │   a. git remote get-url origin → disambiguate repo
     │   b. Gọi MCP tools detect GitNexus + Serena
     │   c. git rev-parse HEAD → ghi index_commit
     │   d. Write code-intelligence.json (v2 schema, create dir if needed)
     │   e. Release lock
     │   f. Continue với CI tools enabled
     │
     └── NOT ACQUIRED:
         a. Check lock staleness (> 60s) → break + acquire
         b. If valid lock → exit 2
         c. Log "CI detection in progress by another session"
         d. Fallback Grep/Glob (hành vi hiện tại — không regression)
         e. Lần chạy sau sẽ đọc cache đã được session kia ghi
```

**Timeline thực tế:**

```
0s    Skill A: check cache → MISS → mkdir -p → acquire lock → scan (3-5s) → write → release
5s    Skill B: check cache → HIT (Skill A vừa ghi) → CI tools enabled ✓
7s    Skill C: check cache → HIT (fresh) → CI tools enabled ✓
```

**Rationale:**
- Lock chỉ được giữ ~3-5 giây (thời gian detection)
- Skill đến sau (5-10s) sẽ thấy cache đã có → dùng CI tools bình thường
- Trường hợp duy nhất fallback: 2+ skill cùng đến PRE-GATE detection step trong cùng 3-5 giây
- Kể cả khi fallback: skill hoạt động y hệt MCV3 hiện tại → **zero regression**
- Tuân thủ pattern lock file đã proven trong MCV3 (wf-fix-bugs, wf-manage-change, wf-add-scope)
- Lock timeout 60s (không 5 min) — detection takes 3-5s, crashed process không nên giữ lock lâu

---

### D9: Index Freshness Check — mỗi PRE-GATE, không cache

**Decision:** Mỗi lần skill PRE-GATE, chạy `ci-freshness-check.sh` để so sánh HEAD hiện tại với `index_commit` trong cache. Kết quả cảnh báo theo mức độ.

**Cơ chế:**

```
Mỗi skill PRE-GATE (sau CI detection):
  0. Short-circuit: if not git repo → skip, exit 0
  1. current=$(git rev-parse HEAD)
  2. indexed=$(jq -r '.gitnexus.index_commit' code-intelligence.json)
  3. behind=$(git rev-list --count $indexed..$current 2>/dev/null || echo "unknown")

  4. Cảnh báo theo mức:
     behind = 0      → OK, dùng CI tools bình thường
     behind = 1-5    → WARNING: "GitNexus index behind HEAD by N commits.
                       Impact analysis may miss recent changes."
     behind = 6-20   → STRONG WARNING: "Index significantly behind (N commits).
                       Consider: gitnexus analyze"
     behind > 20     → SEVERE: "Index is 20+ commits behind. Impact analysis
                       likely incomplete. Recommend re-index before continuing."
     behind = unknown → Không so sánh được (index_commit missing) → skip check
```

**Tần suất:** Chạy MỖI LẦN PRE-GATE, không cache. Chi phí: `git rev-parse HEAD` + `git rev-list --count` < 0.01 giây.

**Non-git handling:** Nếu `git rev-parse HEAD` fails → không phải git repo → skip toàn bộ freshness check (exit 0, status="skipped", reason="not a git repository").

**Rationale:**
- Single-dev: index stale sau mỗi lần tự code/commit
- Multi-dev: index stale sau mỗi lần `git pull` (đồng nghiệp push)
- Nếu không check, CI tools âm thầm trả về kết quả không đầy đủ → **tệ hơn không có CI tools** vì user tin vào kết quả
- `git rev-parse` rẻ hơn gọi MCP tools hàng nghìn lần

---

### D10: Multi-developer awareness — index freshness là bắt buộc

**Decision:** Trong môi trường team, developer B không kiểm soát được khi nào developer A push code. Index freshness check (D9) trở thành **bắt buộc** (không optional).

**Scenario tiêu biểu:**

```
09:00  Dev A: commit + push OrderService.cs (abc123)
09:05  Dev B: git pull → HEAD = abc123
             Index vẫn ở def456 (cũ, không có code của Dev A)
09:06  Dev B: /wf-implement-feature Payment → MODIFY OrderService
             PRE-GATE freshness check: behind = 3 commits
             → WARNING hiển thị
             → gitnexus_impact("OrderService") vẫn chạy
             → Nhưng kèm caveat: "Results based on index at def456 (3 commits behind HEAD)"
```

**Cache và git sync:**
- `.mc-data/` KHÔNG được git-sync (là local data)
- `code-intelligence.json` là local per máy
- Mỗi developer có GitNexus index riêng trên máy của họ
- Index freshness check dùng `git rev-parse HEAD` → luôn phản ánh đúng working copy hiện tại

---

### D11: GitNexus Repo Disambiguation

**Decision:** Khi máy có nhiều GitNexus-indexed repos, skill phải xác định đúng repo cho target project.

**Cơ chế:**

```
Khi GitNexus available (trong MCP detection phase):
  1. git remote get-url origin → extract repo name từ URL
     Ví dụ: "https://github.com/user/eureka-2026.git" → "eureka-2026"
  2. gitnexus_list_repos() → danh sách available repos
  3. Match logic:
     a. Exact name match với repo name từ origin → dùng repo đó
     b. Partial match (repo name chứa origin name hoặc ngược lại) → dùng repo đó
     c. Multiple matches → ưu tiên exact match → ưu tiên path match với CWD
     d. Zero matches → GitNexus available=false (không có index cho repo này)
  4. Lưu repo name vào cache: gitnexus.repo
  5. Tất cả gitnexus_*() calls sau đó dùng `repo: "EUREKA-2026"`
```

**Edge cases handled:**
- Multiple repos indexed → disambiguation logic
- No matching repo → treat as GitNexus unavailable
- Non-git project → skip disambiguation, GitNexus unavailable

---

### D12: Cache Schema Migration v1→v2

**Decision:** `ci-detect.sh` tự động detect schema version và migrate.

```bash
SCHEMA_VERSION=$(jq -r '.["$schema"] // "code-intelligence-v0"' "$CACHE_FILE")
if [[ "$SCHEMA_VERSION" != "code-intelligence-v1" ]]; then
  echo "[ci-detect] Cache schema outdated ($SCHEMA_VERSION) — forcing re-scan"
  NEEDS_RESCAN=true
fi
```

Cache v0 (không có `$schema` field) hoặc schema cũ → tự động re-scan.

---

## 4. Protocol 20 Structure

```markdown
# 20 — Code Intelligence Integration

## 20.1 Detection + Lock
- Flow: check cache per-tool TTL → any stale? → mkdir -p → acquire lock → scan → write → release
- Lock file: .mc-data/work/_meta/.ci-cache.lock
- Lock format: {pid, host, user, acquired_at, heartbeat_at}
- Stale detection: 60 giây → tự break + acquire
- NOT ACQUIRED: fallback Grep/Glob ngay (không chờ, không block)
- ACQUIRED: git remote → disambiguate repo → gọi MCP tools → write cache → release

## 20.2 Per-Tool TTL
- GitNexus available=true: 24h
- GitNexus available=false: 4h (user có thể index giữa phiên)
- Serena available=true: 24h
- Serena available=false: 1h (user có thể cài bất cứ lúc nào)
- Implementation: pure bash integer arithmetic (seconds), no `bc`
- Escape hatch: MCV3_CI_RESCAN=1 (respects lock)

## 20.3 Repo Disambiguation
- git remote get-url origin → extract repo name
- gitnexus_list_repos() → match với origin
- Multiple matches → ưu tiên exact → path match
- Zero matches → GitNexus unavailable
- Lưu repo name vào cache

## 20.4 Index Freshness Check
- Mỗi PRE-GATE: git rev-parse HEAD vs index_commit
- Short-circuit: non-git → skip
- git rev-list --count → 4 mức cảnh báo
- KHÔNG cache — chạy mỗi lần (<0.01s)

## 20.5 Task → Tool Routing Matrix (CI-ROUTE Convention)
[12 tasks mapped to primary/secondary/fallback]
CI-ROUTE là convention: skill agent đọc matrix này để chọn tool.
KHÔNG phải script riêng.

## 20.6 Graceful Degradation
- 3-tier: Primary → Secondary → Grep/Glob
- Tool unavailable → log WARNING → try secondary
- Secondary unavailable → log WARNING → fallback Grep/Glob
- Lock bị giữ → fallback Grep/Glob ngay
- Non-git project → skip all CI, use Grep/Glob
- KHÔNG block execution

## 20.7 Agent Context Injection
- ci-inject-context.sh: đọc cache → generate context snippet
- 3 templates: GitNexus-only, Serena-only, Both
- Kèm freshness warning khi index stale
- D5: injection-only, KHÔNG sửa agent .md files

## 20.8 Skill Integration Pattern
- PRE-GATE Step 0.Na: load CI capabilities (detection + lock + repo disambig)
- PRE-GATE Step 0.Nb: index freshness check
- PRE-EXECUTION: select tools based on CI-ROUTE convention
- POST-EXECUTION: log tool usage (observability)
- Pattern thay đổi theo skill architecture (orchestrator vs direct vs stage-based)

## 20.9 Multi-Developer Considerations
- Cache là local per máy (.mc-data/ không git-sync)
- Index freshness check bắt buộc trong team
- git pull → HEAD thay đổi → detect + warn
- Mỗi developer tự gitnexus analyze

## 20.10 Observability
- Log: tool_used, primary/secondary/fallback, task, duration_ms
- Log: freshness_behind_commits, freshness_level, repo
- Export vào session-log.json (CORE-026)

## 20.11 Cache Schema & Migration
- Schema v2: per-tool checked_at + ttl_hours + index_commit + repo
- Migration: detect v0/v1 → force re-scan
- Validate: jq -e '.' sau mỗi lần ghi
```

---

## 5. Task → Tool Routing Matrix (CI-ROUTE Convention)

CI-ROUTE là convention trong Protocol 20 §20.5. Skill agent đọc matrix này để chọn tool. **Không phải script riêng.**

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

## 6. Cache Schema (v2)

```json
{
  "$schema": "code-intelligence-v1",
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
    "languages": ["csharp", "typescript", "javascript"],
    "checked_at": "2026-05-06T10:00:00Z",
    "ttl_hours": 24
  },
  "scanned_at": "2026-05-06T10:00:00Z",
  "scan_duration_ms": 1200
}
```

**Key fields:**
- `gitnexus.index_commit` — commit SHA mà index dựa trên → dùng cho freshness check
- `gitnexus.repo` — GitNexus repo name (từ disambiguation) → dùng cho mọi gitnexus_* calls
- `gitnexus.checked_at` + `ttl_hours` — per-tool TTL
- `serena.checked_at` + `ttl_hours` — per-tool TTL
- `$schema` — "code-intelligence-v1" → dùng cho migration detection

---

## 7. Integration Points per Skill

Mỗi skill có PRE-GATE pattern riêng, phản ánh architecture của skill đó:

### 7.1. wf-implement-feature (S3) — Direct execution, 7 PRE-GATE phases

```
Phase 0 PRE-GATE (sau phase0-5-context-setup):
  Step 0.Na: Load CI capabilities
    1. ci-detect.sh → check cache → lock+scan nếu cần
    2. Read code-intelligence.json
  Step 0.Nb: Index Freshness Check
    1. ci-freshness-check.sh → compare HEAD vs index_commit
    2. WARNING nếu behind > 0

Phase 0.7 Safety Gate (phase0-7-safety-gate.md):
  BEFORE: grep -r "CreateOrder" apps/backend/
  AFTER:  CI-ROUTE find_existing_code "CreateOrder"
           → Serena find_references (primary) → GitNexus context() (secondary) → Grep (fallback)
           ⚠ Nếu freshness behind > 0: kết quả kèm caveat

Phase 3 TDD (phase3-tdd.md):
  BEFORE: Edit file, không impact check
  AFTER:  CI-ROUTE impact_analysis "{symbol_to_edit}"
           → GitNexus impact(symbol, upstream) → blast radius report
           → HIGH/CRITICAL → CDG render (CORE-027)
           ⚠ Nếu freshness behind > 0: CDG thêm caveat
           CI-ROUTE detect_changes → GitNexus detect_changes()

Phase 6 Commit:
  BEFORE: git diff --stat
  AFTER:  CI-ROUTE pre_commit_check → GitNexus detect_changes()
```

### 7.2. wf-fix-bugs + Sub-skills (S4) — Orchestrator + delegates

```
wf-fix-bugs orchestrator PRE-GATE:
  Step 0.Na: Load CI capabilities (detection + lock)
  Step 0.Nb: Index Freshness Check

wf-fix-triage Phase 2 (bug investigation):
  BEFORE: grep -r "related_term" apps/ | head -50
  AFTER:  CI-ROUTE understand_flow "{bug_description}"
           → GitNexus query(bug_description)
           ⚠ Freshness caveat nếu index stale
           → Grep + Read (fallback)

wf-fix-execute Phase 3 (fix execution):
  BEFORE: Edit file trực tiếp
  AFTER:  CI-ROUTE impact_analysis "{symbol_to_fix}"
           → GitNexus impact(symbol, upstream, depth=3) → blast radius
           → HIGH/CRITICAL → CDG render + freshness caveat
           CI-ROUTE find_references → Serena find_references
           CI-ROUTE detect_changes → GitNexus detect_changes()
```

### 7.3. wf-manage-change (S5) — Linear phase-based

```
PRE-GATE: Step 0.Na (detection) + Step 0.Nb (freshness)
Phase 2 Impact (phase2-impact.md):
  BEFORE: Manual trace dependencies
  AFTER:  CI-ROUTE impact_analysis → GitNexus impact() → auto-populate impact section
           CI-ROUTE find_references → Serena find_references
           CI-ROUTE api_routes → GitNexus route_map() (nếu API thay đổi)
```

### 7.4. wf-legacy-scan (S5) — Stage-based

```
PRE-GATE: Step 0.Na (detection) + Step 0.Nb (freshness)
Stage 1 Inventory (phase1-inventory.md):
  CI-ROUTE project_structure → Serena onboarding + GitNexus clusters → Glob (fallback)
Stage 3 Extract (phase3-extract.md):
  CI-ROUTE find_by_annotation → GitNexus cypher + Serena find_refs → Grep (fallback)
```

### 7.5. wf-design (S5) — Phase-based with workload gate

```
PRE-GATE: Step 0.Na (detection) + Step 0.Nb (freshness)
Phase 0 Context (phase0-context.md):
  CI-ROUTE api_routes → GitNexus route_map()
  CI-ROUTE understand_flow → GitNexus query() cho core domains
  CI-ROUTE project_structure → GitNexus clusters
```

### 7.6. wf-verify-sync (S6) — Linear phase-based

```
PRE-GATE: Step 0.Na (detection) + Step 0.Nb (freshness)
Phase 1 Scan (phase1-scan.md):
  CI-ROUTE find_by_annotation → GitNexus cypher + Serena find_refs → Grep (fallback)
Phase 2 Analyze (phase2-analyze.md):
  Cross-validation CI vs Grep results → report discrepancies
```

### 7.7. wf-plan-modules (S6) — Complex phase-based

```
PRE-GATE: Step 0.Na (detection) + Step 0.Nb (freshness)
Phase 2 Dependencies (phase2-deps.md):
  CI-ROUTE impact_analysis → GitNexus impact() cho mỗi module entry point
  CI-ROUTE project_structure → GitNexus clusters + Serena overview
```

---

## 8. Multi-Developer Scenarios

### 8.1. Dev A push, Dev B chưa re-index

```
Dev A: commit + push abc123 (OrderService.cs mới)
Dev B: git pull → HEAD=abc123, index=def456 (cũ)
Dev B: /wf-implement-feature Payment
       PRE-GATE freshness: behind=3 → WARNING
       gitnexus_impact("OrderService") → thiếu code mới của Dev A
       → Agent được cảnh báo: "Results may be incomplete"
```

### 8.2. Cả hai developer cùng chạy skill song song (khác máy)

```
Dev A (Windows): /wf-implement-feature Checkout
                 PRE-GATE: cache miss → acquire lock → scan → write → CI tools ✓
                 
Dev B (WSL):    /wf-fix-bugs "order bug"
                 PRE-GATE: cache miss → acquire lock → scan → write → CI tools ✓
                 
Không conflict vì .mc-data/ là local per máy, không git-sync.
```

### 8.3. Cùng máy, 2 terminal

```
Terminal 1: /wf-implement-feature Cart    (Session A)
Terminal 2: /wf-fix-bugs "login crash"    (Session B)

Session A: check cache → MISS → mkdir -p → acquire lock → scan (3-5s) → write → release
Session B: check cache → MISS → lock BỊ GIỮ → exit 2 → fallback Grep (current behavior)
           ↓
           Lần chạy sau của Session B: cache HIT → CI tools ✓
```

### 8.4. Team lead review sau khi team push cả ngày

```
Team lead (cuối ngày): /wf-verify-sync
  PRE-GATE freshness: behind=47 → SEVERE
  → "Index is 47 commits behind HEAD. Impact analysis likely incomplete.
     Recommend: gitnexus analyze"
  → Vẫn tiếp tục, nhưng kết quả có caveat rõ ràng
```

### 8.5. Non-git project

```
User: /wf-implement-feature Test (project không có .git)
  PRE-GATE: git rev-parse → fail → skip all CI detection
  → Dùng Grep/Glob (current behavior, zero regression)
```

---

## 9. Agent Context Injection Templates

### 9.1. Both Available + Freshness OK

```
## Code Intelligence: GitNexus + Serena

Both GitNexus (graph: {repo}, {symbols} symbols, {flows} flows) and
Serena (LSP: {languages}) are available. Index up to date (HEAD).

GUIDELINE:
- System-level (impact, flows, routes) → GitNexus
- Symbol-level (def, refs, rename) → Serena
- Pre-commit → GitNexus detect_changes()
```

### 9.2. Both Available + Index Stale

```
## Code Intelligence: GitNexus + Serena

Both GitNexus (graph: {repo}, {symbols} symbols, {flows} flows) and
Serena (LSP: {languages}) are available.

⚠ GitNexus index is {N} commits behind HEAD.
Impact analysis and query results may be incomplete.
Recommend: `gitnexus analyze` to refresh index.

GUIDELINE:
- System-level (impact, flows, routes) → GitNexus (with caveat)
- Symbol-level (def, refs, rename) → Serena (unaffected by index)
```

### 9.3. GitNexus-only

```
## Code Intelligence: GitNexus

GitNexus is available ({repo}, {symbols} symbols, {flows} flows).
- Before editing any symbol → gitnexus_impact({target, direction: "upstream"})
- Exploring code → gitnexus_query({query: "concept"})
- Pre-commit → gitnexus_detect_changes()
- NEVER rename with find-and-replace — use gitnexus_rename
```

### 9.4. Serena-only

```
## Code Intelligence: Serena

Serena LSP tools are available.
- find_definition → precise go-to-definition
- find_references → all call sites
- rename_symbol → safe refactoring (not find-and-replace)
- get_symbols_overview → file structure
```

---

## 10. Token Measurement Methodology

Đo lường token savings bằng cách so sánh context token count:

1. **Chọn operation chuẩn:** "Find all references to CreateOrder in the codebase"
2. **Baseline (Grep/Glob):** Chạy operation với Grep/Glob → ghi nhận `usage.input_tokens` từ API response
3. **CI (GitNexus/Serena):** Chạy cùng operation với CI tools → ghi nhận `usage.input_tokens`
4. **Tính savings:** `savings_pct = (baseline_tokens - ci_tokens) / baseline_tokens * 100`
5. **Lặp 3 lần**, lấy trung bình
6. **Loại bỏ outlier** nếu 1 lần chạy lệch > 50% so với 2 lần còn lại

**Operations đo lường (tối thiểu 3):**
- Find references (precision task → Serena primary)
- Understand execution flow (graph task → GitNexus primary)
- Find definition (symbol task → Serena primary)
