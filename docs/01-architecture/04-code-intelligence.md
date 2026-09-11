# 04 — Code Intelligence: GitNexus + Serena

> **Mức độ ràng buộc:** Tham khảo (overview) — bám Protocol 20 ([`.claude/skills/protocols/20-code-intelligence.md`](../../.claude/skills/protocols/20-code-intelligence.md))
> **Mục đích:** Mô tả cơ chế MCV3 tự động phát hiện và dùng GitNexus + Serena khi available trên target project, với graceful degradation về Grep/Glob

---

## 1. Tại sao cần Code Intelligence?

Khi skill cần đọc/phân tích code (vd: `wf-fix-bugs` Phase 4, `wf-legacy-scan` Stage 1), 2 tool có thể cao cấp hơn Grep:

| Tool | Khả năng |
|------|----------|
| **GitNexus** | Impact analysis, execution flows, API route mapping, semantic graph |
| **Serena** | LSP-powered symbol search, find references, safe rename |
| **Grep/Glob** | Text pattern matching (fallback) |

MCV3 KHÔNG bắt user phải cài GitNexus/Serena. Cơ chế:
- **Auto-detect** tool nào available
- **Auto-route** task → tool phù hợp
- **Graceful degradation** về Grep/Glob nếu không có tool

User KHÔNG cần config gì để kích hoạt — zero-config (CORE-033).

---

## 2. Tổng quan luồng

```
Skill PRE-GATE (Phase Init):
   │
   ▼
[Na] Run ci-detect.sh
   │
   ├─ Cache fresh (per-tool TTL) → load cache, skip detection
   │
   └─ Cache stale → acquire .ci-cache.lock
                 → detect via MCP tools (GitNexus.health, Serena.check)
                 → write cache
                 → release lock
   │
   ▼
[Nb] Run ci-freshness-check.sh
   │
   ├─ behind = 0      → OK
   ├─ behind = 1-5    → light WARNING
   ├─ behind = 6-20   → strong WARNING
   └─ behind > 20     → severe WARNING (recommend reindex)
   │
   ▼
[Nc] Inject CI_CONTEXT vào agent prompts
   │
   ▼
Agent thực thi với CI-ROUTE matrix (§5)
```

---

## 3. 3-step CI PRE-GATE (CORE-033)

Mọi skill cần đọc/phân tích code BẮT BUỘC có 3 bước Na/Nb/Nc:

### Step Na: LOAD CI CAPABILITIES

```bash
bash .claude/scripts/ci-detect.sh
# Output env:
#   GITNEXUS_AVAILABLE=true|false
#   SERENA_AVAILABLE=true|false
#   GITNEXUS_INDEX_COMMIT=<sha or "">
```

**Behavior:**
- Check `.mc-data/work/_meta/code-intelligence.json` cache
- Per-tool TTL (xem §4)
- Acquire lock nếu cần re-scan
- Graceful: lock bị giữ → exit 2 → fallback Grep/Glob

### Step Nb: INDEX FRESHNESS CHECK

```bash
bash .claude/scripts/ci-freshness-check.sh
# So sánh GITNEXUS_INDEX_COMMIT vs HEAD
# behind = N commits
```

4 mức cảnh báo:
- `behind = 0` → OK
- `behind = 1-5` → light WARNING (tiếp tục dùng CI tools)
- `behind = 6-20` → strong WARNING (cân nhắc reindex)
- `behind > 20` → severe WARNING (fallback Grep an toàn hơn)

### Step Nc: AGENT CONTEXT INJECTION

```bash
if [[ $GITNEXUS_AVAILABLE == "true" ]] || [[ $SERENA_AVAILABLE == "true" ]]; then
  CI_CONTEXT=$(bash .claude/scripts/ci-inject-context.sh)
fi
```

`CI_CONTEXT` string được pass vào agent prompt qua section "CI Context Injection" (CORE-037 §4).

```markdown
## Agent Prompt Section 4: CI Context

GitNexus available: true (index at commit abc123, 3 commits behind HEAD)
Serena available: true
CI-ROUTE: Primary tools, fallback to Grep when needed
```

---

## 4. Per-Tool TTL

Mỗi tool có TTL riêng, phản ánh khả năng thay đổi thực tế:

| Tool | `available=true` TTL | `available=false` TTL | Lý do |
|------|---------------------|----------------------|-------|
| GitNexus | 24h | 4h | Đã index → hiếm gỡ. Chưa có → user có thể cài giữa session |
| Serena | 24h | 1h | LSP server stable khi đã onboard. Chưa có → cài nhanh |

**Escape hatch:** `MCV3_CI_RESCAN=1` ép re-detect ngay.

```bash
# Per-tool TTL check (pure bash, không cần bc)
elapsed_seconds=$(( $(date +%s) - $(date -d "$checked_at" +%s) ))
ttl_seconds=$(( ttl_hours * 3600 ))
if (( elapsed_seconds < ttl_seconds )); then echo "fresh"; else echo "stale"; fi
```

---

## 5. CI-ROUTE Matrix

Task routing theo độ ưu tiên: **Primary → Secondary → Fallback**.

| Task | Primary | Secondary | Fallback |
|------|---------|-----------|----------|
| Impact analysis before edits | GitNexus `impact()` | — | Manual grep |
| Understand execution flow | GitNexus `query()` | Read + trace | — |
| Find symbol definition | Serena `find_definition` | — | Grep |
| Find all references | Serena `find_references` | GitNexus `context()` | Grep |
| Safe rename | Serena `rename_symbol` | GitNexus `rename` | Manual edit |
| Pre-commit check | GitNexus `detect_changes()` | — | `git diff --stat` |
| API route mapping | GitNexus `route_map()` | — | Grep |
| File structure overview | Serena `get_symbols_overview` | — | Read |
| Find by REQ-ID annotation | Both (cypher + find_refs) | — | Grep |
| Cross-module dependencies | GitNexus `query()` | — | Manual trace |
| Identify dead code | GitNexus + Serena | — | Manual |
| Refactor scope estimation | GitNexus `impact()` | — | Grep + count |

**Quy tắc:**
- KHÔNG hỏi user chọn tool — auto-detect + auto-route
- Mỗi task có ≥1 fallback (zero regression)
- Skill log routing decision vào `session-log.json`

---

## 6. Lock-Protected Cache

### 6.1. Cache file

```
.mc-data/work/_meta/code-intelligence.json
```

Schema:
```json
{
  "$schema": "code-intelligence-v1",
  "gitnexus": {
    "available": true,
    "checked_at": "2026-05-15T10:00:00+07:00",
    "index_commit": "abc123...",
    "repo_name": "MCV3"
  },
  "serena": {
    "available": true,
    "checked_at": "2026-05-15T10:00:00+07:00",
    "onboarded": true
  }
}
```

### 6.2. Lock file

```
.mc-data/work/_meta/.ci-cache.lock
```

| Field | Value |
|-------|-------|
| Format | `PID\|host\|user\|acquired_at\|heartbeat_at` |
| Acquire | `( set -C; echo "..." > "$LOCK_FILE" )` — atomic noclobber |
| Release | `rm -f "$LOCK_FILE"` |
| Stale detection | 60 giây — heartbeat > 60s → break + acquire |
| Held → fallback | exit 2 → caller dùng Grep/Glob ngay |

### 6.3. Two-Phase Detection Handoff

```
Phase 1: ci-detect.sh (no args)
  → Check per-tool TTL → signal:
     {status: "all_fresh"}     → load cache, skip MCP calls
     {status: "needs_scan"}    → proceed to MCP detection
     {status: "lock_held"}     → fallback (exit 2)
     {status: "no_git"}        → skip CI (exit 1)

Phase 2: ci-detect.sh --write-cache '<json>'
  → Pass MCP detection results → script writes cache → releases lock
```

---

## 7. Graceful Degradation

Khi tool absent hoặc lock bị giữ:

```
GitNexus unavailable + Serena unavailable
   ↓
Fallback: Grep + Glob (always available)
   ↓
Skill log: "CI tools absent, using Grep fallback"
   ↓
Tiếp tục, KHÔNG block
```

**Anti-regression test:** Mọi skill phải pass eval khi `GITNEXUS_AVAILABLE=false` + `SERENA_AVAILABLE=false`.

---

## 8. Concurrency Safety

Khi 2 sessions/devs cùng chạy skill song song:

```
Session A đang detect → acquire lock
Session B PRE-GATE → check lock → bị giữ
   ↓
Session B exit 2 → fallback Grep
Session B KHÔNG block, KHÔNG retry vô hạn
   ↓
Session A xong → release lock
Session C sau đó → acquire bình thường
```

**Multi-dev safe:** Lock chỉ chia sẻ giữa các process trên cùng máy. Multi-machine = mỗi máy có cache riêng.

---

## 9. Use cases thực tế trong MCV3

### 9.1. `wf-fix-bugs` Phase 4 (Find Bugs)

```
Phase 4: dispatch 11 lane agents (QD1-QD11) song song
   ↓
Mỗi agent có CI_CONTEXT trong prompt
   ↓
QD1 (Functional) dùng GitNexus.query() tìm execution flow của feature
QD3 (Security) dùng Serena.find_references() tìm input validation
QD4 (Performance) dùng GitNexus.impact() đánh giá blast radius
QD10 (Integration) dùng GitNexus.route_map() check API contract
```

### 9.2. `wf-legacy-scan` Stage 1 (Inventory)

```
Stage 1: extract source files, dependencies, screens, APIs
   ↓
Nếu GitNexus available → dùng route_map() lấy API endpoints
Nếu chỉ có Serena → dùng get_symbols_overview() lấy file structure
Nếu cả 2 absent → fallback Grep + heuristics
```

### 9.3. `wf-implement-feature` Phase 0.5b (Safety Check)

```
Trước khi viết code mới, search code hiện tại:
   ↓
Serena.find_definition(feature_name) → tìm có code cũ không
GitNexus.impact() trên file sẽ sửa → đánh giá rủi ro
   ↓
Nếu phát hiện code có sẵn → CDG hỏi user: overwrite | merge | skip
```

---

## 10. Reference matrix tools

| Resource | Mục đích |
|----------|----------|
| `gitnexus://repo/{name}/context` | Codebase overview, check index freshness |
| `gitnexus://repo/{name}/clusters` | Functional areas |
| `gitnexus://repo/{name}/processes` | Execution flows |
| `gitnexus://repo/{name}/process/{name}` | Step-by-step execution trace |

| Serena tool | Dùng cho |
|-------------|----------|
| `get_symbols_overview` | High-level file structure |
| `find_symbol(name_path, include_body=true)` | Đọc 1 symbol cụ thể |
| `find_referencing_symbols` | Tìm callers/importers |
| `replace_symbol_body` | Edit function/class body |
| `insert_before_symbol`, `insert_after_symbol` | Thêm code mới |
| `rename_symbol` | Safe rename across codebase |
| `get_diagnostics_for_file` | LSP errors/warnings |

---

## 11. Anti-patterns

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Hardcode `MUST have GitNexus` trong skill | Auto-detect + fallback (CORE-033) |
| Re-detect mỗi PRE-GATE bất kể TTL | Cache check trước, detect chỉ khi stale |
| Block khi lock bị giữ | Exit 2 → fallback Grep ngay (no block) |
| Bỏ qua freshness check | Phải chạy mỗi PRE-GATE — index có thể stale |
| Quên inject CI_CONTEXT vào agent | Agent không biết CI có sẵn → bỏ lỡ optimization |
| Skill tự gọi GitNexus.* trực tiếp | Đi qua ci-detect → ci-inject-context handoff |
| User phải config `enable_gitnexus=true` | Zero-config auto-detect |
| Cache không có version field | Cần `$schema` để evolve |

---

## 12. Compliance & debugging

### 12.1. Manual check

```bash
# Xem cache hiện tại:
cat .mc-data/work/_meta/code-intelligence.json | jq

# Force re-detect:
MCV3_CI_RESCAN=1 bash .claude/scripts/ci-detect.sh

# Check freshness:
bash .claude/scripts/ci-freshness-check.sh

# Tìm skills dùng CI:
grep -l "ci-detect.sh" .claude/skills/workflow/*/SKILL.md
grep -l "ci-detect.sh" .claude/skills/workflow/*/procedures/*.md
```

### 12.2. Logging

CI events được log vào `session-log.json`:
```jsonl
{"ts":"...","skill":"wf-fix-bugs","event":"CI_DETECT","gitnexus":true,"serena":true}
{"ts":"...","skill":"wf-fix-bugs","event":"CI_FRESHNESS","behind":3,"level":"light"}
{"ts":"...","skill":"wf-fix-bugs","event":"CI_FALLBACK","reason":"lock_held"}
```

---

## 13. Liên kết

- **Canonical Protocol 20:** [`.claude/skills/protocols/20-code-intelligence.md`](../../.claude/skills/protocols/20-code-intelligence.md)
- **CORE-033:** [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4j
- **Pattern (auto-detect + fallback):** [`../03-design-patterns/08-auto-detect-fallback.md`](../03-design-patterns/08-auto-detect-fallback.md)
- **Pattern (CI-first integration):** [`../03-design-patterns/02-ci-first-integration.md`](../03-design-patterns/02-ci-first-integration.md)
- **Scripts:** `.claude/scripts/ci-detect.sh`, `ci-freshness-check.sh`, `ci-inject-context.sh`
