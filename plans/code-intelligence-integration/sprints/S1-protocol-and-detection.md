# Sprint 1: Protocol 20 + Detection Script + Lock

> **Estimate:** 3.5h | **Priority:** P0 | **Dependencies:** None
> **Revised v0.3:** lock timeout 60s (was 300s), pure bash integer arithmetic (F21), mkdir -p (F24), repo disambiguation (F22), cache schema v1→v2 migration (F26)

---

## Mục tiêu

Tạo nền móng cho toàn bộ CI integration: Protocol 20 định nghĩa cách mọi skill tương tác với code intelligence tools, detection script với lock mechanism bảo vệ cache write, per-tool TTL, và repo disambiguation.

---

## Tasks

### Task 1.1: Tạo Protocol 20 (`20-code-intelligence.md`) — 1.25h

**File:** `.claude/skills/protocols/20-code-intelligence.md`

**Nội dung (9 sections):**
```markdown
# 20 — Code Intelligence Integration

## 20.1 Detection + Lock
- Flow: check cache per-tool TTL → any stale? → acquire lock → scan → write → release
- Lock file: .mc-data/work/_meta/.ci-cache.lock
- Lock format: {pid, host, user, acquired_at, heartbeat_at}
- Stale detection: 60 giây → tự break + acquire
- NOT ACQUIRED: fallback Grep/Glob ngay (không chờ, không block)
- ACQUIRED: gọi MCP tools → write cache → release

## 20.2 Per-Tool TTL
- GitNexus available=true: 24h
- GitNexus available=false: 4h (user có thể cài GitNexus + index giữa phiên)
- Serena available=true: 24h
- Serena available=false: 1h (user có thể cài bất cứ lúc nào)
- Escape hatch: MCV3_CI_RESCAN=1

## 20.3 Index Freshness Check
- Mỗi PRE-GATE: git rev-parse HEAD vs index_commit
- git rev-list --count → 4 mức cảnh báo
- KHÔNG cache — chạy mỗi lần (<0.01s)
- Short-circuit: không phải git repo → skip check

## 20.4 Task → Tool Routing Matrix (CI-ROUTE convention)
[12 tasks mapped to primary/secondary/fallback]
CI-ROUTE là convention trong Protocol 20, không phải script riêng.

## 20.5 Graceful Degradation
- 3-tier: Primary → Secondary → Grep/Glob
- Tool unavailable → log WARNING → try secondary
- Secondary unavailable → log WARNING → fallback Grep/Glob
- Lock bị giữ → fallback Grep/Glob ngay
- KHÔNG block execution

## 20.6 Agent Context Injection
- ci-inject-context.sh: đọc cache → generate context snippet
- 4 templates: Both-OK, Both-Stale, GitNexus-only, Serena-only
- Kèm freshness warning khi index stale

## 20.7 Skill Integration Pattern
- PRE-GATE Step 0.Na: load CI capabilities (detection + lock)
- PRE-GATE Step 0.Nb: index freshness check
- PRE-EXECUTION: select tools based on task
- POST-EXECUTION: log tool usage (observability)

## 20.8 Multi-Developer Considerations
- Cache là local per máy (.mc-data/ không git-sync)
- Index freshness check bắt buộc trong team
- git pull → HEAD thay đổi → detect + warn
- Mỗi developer tự gitnexus analyze

## 20.9 Observability
- Log: tool_used, primary/secondary/fallback, task, duration_ms
- Log: freshness_behind_commits, freshness_level
- Export vào session-log.json
```

**Acceptance criteria:**
- [ ] Protocol 20 tồn tại, đúng format protocol (theo protocols/README.md)
- [ ] Chứa đầy đủ 9 sections (20.1-20.9)
- [ ] Lock mechanism được mô tả rõ (lock file format, stale detection 60s, graceful fallback)
- [ ] Per-tool TTL table đầy đủ 4 trường hợp (GitNexus-absent=4h, Serena-absent=1h)
- [ ] Index freshness check 4 mức cảnh báo + git short-circuit
- [ ] CI-ROUTE là convention (không phải script riêng)
- [ ] Routing matrix có 12 tasks với primary/secondary/fallback
- [ ] Graceful degradation rules rõ ràng (bao gồm lock fallback)
- [ ] Multi-developer considerations

---

### Task 1.2: Tạo Cache Schema (v2 — có migration) — 0.5h

**File:** `.claude/skills/templates/code-intelligence.schema.json`

**Schema (v2 — revised v0.3):**
```json
{
  "$schema": "code-intelligence-v2",
  "type": "object",
  "required": ["gitnexus", "serena", "scanned_at", "schema_version"],
  "properties": {
    "schema_version": {
      "type": "integer",
      "description": "Cache schema version. v1=no per-tool TTL, v2=per-tool checked_at+ttl_hours+index_commit. Used for auto-migration detection."
    },
    "gitnexus": {
      "type": "object",
      "required": ["available", "checked_at", "ttl_hours"],
      "properties": {
        "available": {"type": "boolean"},
        "repo": {"type": "string", "description": "GitNexus repo name matching this project (resolved via git remote get-url origin)"},
        "symbols": {"type": "integer"},
        "relationships": {"type": "integer"},
        "execution_flows": {"type": "integer"},
        "index_commit": {"type": "string", "description": "Git SHA của commit mà index dựa trên — dùng cho freshness check"},
        "indexed_at": {"type": "string", "format": "date-time"},
        "checked_at": {"type": "string", "format": "date-time", "description": "Lần cuối check availability"},
        "ttl_hours": {"type": "integer", "default": 24, "description": "24 nếu available=true, 4 nếu available=false"}
      }
    },
    "serena": {
      "type": "object",
      "required": ["available", "checked_at", "ttl_hours"],
      "properties": {
        "available": {"type": "boolean"},
        "onboarded": {"type": "boolean"},
        "languages": {"type": "array", "items": {"type": "string"}},
        "checked_at": {"type": "string", "format": "date-time"},
        "ttl_hours": {"type": "integer", "default": 24, "description": "24 nếu available=true, 1 nếu available=false"}
      }
    },
    "scanned_at": {"type": "string", "format": "date-time"},
    "scan_duration_ms": {"type": "integer"}
  }
}
```

**Acceptance criteria:**
- [ ] Schema valid JSON, `"$schema": "code-intelligence-v2"`
- [ ] Định nghĩa đủ fields cho GitNexus (có `index_commit` + `repo`) + Serena
- [ ] Mỗi tool có `checked_at` + `ttl_hours` riêng → per-tool TTL
- [ ] `schema_version: 2` cho migration detection (F26)
- [ ] `gitnexus.repo` ghi GitNexus repo name resolved từ git remote (F22)

---

### Task 1.3: Tạo `ci-detect.sh` (v2 — có lock + repo disambiguation) — 1.25h

**File:** `.claude/scripts/ci-detect.sh`

**Logic:**
```bash
#!/usr/bin/env bash
# ci-detect.sh — Detect available code intelligence tools with lock protection
# Output: .mc-data/work/_meta/code-intelligence.json
# Exit: 0 (có ít nhất 1 tool) | 1 (không có tool nào) | 2 (lock bị giữ — caller nên fallback)

# Compatibility: Git Bash on Windows. Uses pure bash integer arithmetic (no bc).
# Pipefail không dùng trên Windows Git Bash — thay bằng explicit check từng lệnh.

CACHE_FILE=".mc-data/work/_meta/code-intelligence.json"
CACHE_DIR=".mc-data/work/_meta"
LOCK_FILE="$CACHE_DIR/.ci-cache.lock"
STALE_TIMEOUT_SEC=60  # 60 giây (D8)

# ── Ensure cache directory exists ──
mkdir -p "$CACHE_DIR"

# ── Hàm check schema version + migrate nếu cần ──
check_and_migrate_cache() {
  if [[ ! -f "$CACHE_FILE" ]]; then
    return 0  # No cache yet — first run
  fi
  
  local schema_version=$(jq -r '.schema_version // 1' "$CACHE_FILE" 2>/dev/null || echo "1")
  if [[ "$schema_version" == "1" ]] || [[ "$schema_version" -lt 2 ]]; then
    echo "[ci-detect] Cache schema v1 detected — forcing re-scan for v2 migration"
    rm -f "$CACHE_FILE"  # Force re-scan to populate v2 fields
  fi
}

# ── Hàm check per-tool TTL ──
# Trả về: "fresh" | "stale"
# Dùng pure bash integer arithmetic (seconds), không bc (F21)
check_tool_ttl() {
  local tool=$1  # "gitnexus" | "serena"
  
  local checked_at=$(jq -r ".$tool.checked_at // \"1970-01-01T00:00:00Z\"" "$CACHE_FILE" 2>/dev/null || echo "1970-01-01T00:00:00Z")
  local ttl_hours=$(jq -r ".$tool.ttl_hours // 24" "$CACHE_FILE" 2>/dev/null || echo "24")
  
  # Convert ISO 8601 to epoch seconds (portable: date -d on Linux, custom on macOS)
  local checked_epoch
  if checked_epoch=$(date -d "$checked_at" +%s 2>/dev/null); then
    :  # Linux/Git Bash
  else
    checked_epoch=0  # Parse failed → treat as stale
  fi
  
  local now_epoch=$(date +%s)
  local elapsed_sec=$(( now_epoch - checked_epoch ))
  local ttl_sec=$(( ttl_hours * 3600 ))
  
  if [[ $elapsed_sec -lt $ttl_sec ]]; then
    echo "fresh"
  else
    echo "stale"
  fi
}

# ── Hàm acquire lock ──
acquire_lock() {
  mkdir -p "$CACHE_DIR"
  # Atomic create via set -C (noclobber) — portable, no race condition
  if ( set -C; echo "$$|$(hostname 2>/dev/null || echo unknown)|$(whoami 2>/dev/null || echo unknown)|$(date -Iseconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)|$(date -Iseconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)" > "$LOCK_FILE" ) 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# ── Hàm check stale lock ──
is_lock_stale() {
  if [[ ! -f "$LOCK_FILE" ]]; then
    return 1  # No lock → not stale
  fi
  
  # Đọc heartbeat_at (field 5, pipe-separated)
  local heartbeat_str=$(cut -d'|' -f5 "$LOCK_FILE" 2>/dev/null || echo "1970-01-01")
  local heartbeat_epoch
  if heartbeat_epoch=$(date -d "$heartbeat_str" +%s 2>/dev/null); then
    :  # Linux/Git Bash
  else
    return 1  # Can't parse → assume not stale
  fi
  
  local now_epoch=$(date +%s)
  local age_sec=$(( now_epoch - heartbeat_epoch ))
  
  if [[ $age_sec -gt $STALE_TIMEOUT_SEC ]]; then
    return 0  # Stale
  else
    return 1  # Not stale yet
  fi
}

# ── Hàm break stale lock + re-acquire ──
break_stale_lock() {
  echo "[ci-detect] Breaking stale lock (>${STALE_TIMEOUT_SEC}s)" >&2
  rm -f "$LOCK_FILE"
  acquire_lock
}

# ── Hàm release lock ──
release_lock() {
  rm -f "$LOCK_FILE"
}

# ── Hàm resolve GitNexus repo name ──
# Match git remote URL with available GitNexus repos (F22)
resolve_gitnexus_repo() {
  local remote_url=$(git remote get-url origin 2>/dev/null || echo "")
  if [[ -z "$remote_url" ]]; then
    echo "unknown"
    return
  fi
  
  # Extract repo name from URL patterns:
  # https://github.com/user/repo.git → repo
  # git@github.com:user/repo.git → repo
  # /path/to/repo → basename
  local repo_name=$(echo "$remote_url" | sed -E 's|.*[:/]([^/]+)/([^/]+?)(\.git)?$|\2|' 2>/dev/null || basename "$remote_url" .git 2>/dev/null || echo "unknown")
  echo "$repo_name"
}

# ── Hàm write cache ──
write_cache() {
  local gitnexus_available=$1
  local serena_available=$2
  local gitnexus_repo=$3
  local gitnexus_symbols=$4
  local gitnexus_relationships=$5
  local gitnexus_flows=$6
  local index_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
  local now_iso=$(date -Iseconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
  
  local gitnexus_ttl=24
  if [[ "$gitnexus_available" != "true" ]]; then
    gitnexus_ttl=4
  fi
  
  local serena_ttl=24
  if [[ "$serena_available" != "true" ]]; then
    serena_ttl=1
  fi
  
  jq -n \
    --arg schema_version "2" \
    --argjson gitnexus_avail "$gitnexus_available" \
    --arg gitnexus_repo "$gitnexus_repo" \
    --argjson gitnexus_symbols "$gitnexus_symbols" \
    --argjson gitnexus_relationships "$gitnexus_relationships" \
    --argjson gitnexus_flows "$gitnexus_flows" \
    --arg index_commit "$index_commit" \
    --argjson gitnexus_ttl "$gitnexus_ttl" \
    --argjson serena_avail "$serena_available" \
    --argjson serena_ttl "$serena_ttl" \
    --arg now "$now_iso" \
    '{
      schema_version: ($schema_version | tonumber),
      gitnexus: {
        available: $gitnexus_avail,
        repo: $gitnexus_repo,
        symbols: $gitnexus_symbols,
        relationships: $gitnexus_relationships,
        execution_flows: $gitnexus_flows,
        index_commit: $index_commit,
        indexed_at: $now,
        checked_at: $now,
        ttl_hours: ($gitnexus_ttl | tonumber)
      },
      serena: {
        available: $serena_avail,
        onboarded: $serena_avail,
        languages: [],
        checked_at: $now,
        ttl_hours: ($serena_ttl | tonumber)
      },
      scanned_at: $now,
      scan_duration_ms: 0
    }' > "$CACHE_FILE"
  
  # Validate
  if ! jq -e '.' "$CACHE_FILE" > /dev/null 2>&1; then
    echo "[ci-detect] ERROR: Cache file validation failed" >&2
    rm -f "$CACHE_FILE"
    return 1
  fi
}

# ── CLI Mode Dispatch ──
# Two-phase detection handoff protocol (D2):
# Phase 1: ci-detect.sh (no args) → check TTL → acquire lock → signal skill agent → exit
# Phase 2: ci-detect.sh --write-cache '<json>' → skill agent passes MCP results → write cache → release lock → exit

case "${1:-}" in
  --write-cache)
    # ═══════════════════════════════════════════════
    # Phase 2: Write MCP detection results to cache
    # ═══════════════════════════════════════════════
    # $2 = JSON string from skill agent:
    #   {
    #     "gitnexus_available": true/false,
    #     "gitnexus_repo": "repo-name" | null,
    #     "gitnexus_symbols": N | 0,
    #     "gitnexus_relationships": N | 0,
    #     "gitnexus_flows": N | 0,
    #     "serena_available": true/false
    #   }
    if [[ -z "${2:-}" ]]; then
      echo "[ci-detect] ERROR: --write-cache requires JSON argument" >&2
      release_lock
      exit 1
    fi
    
    MCP_RESULT="$2"
    
    # Parse MCP detection results
    GITNEXUS_AVAIL=$(echo "$MCP_RESULT" | jq -r '.gitnexus_available // false')
    GITNEXUS_REPO=$(echo "$MCP_RESULT" | jq -r '.gitnexus_repo // "unknown"')
    GITNEXUS_SYMBOLS=$(echo "$MCP_RESULT" | jq -r '.gitnexus_symbols // 0')
    GITNEXUS_RELS=$(echo "$MCP_RESULT" | jq -r '.gitnexus_relationships // 0')
    GITNEXUS_FLOWS=$(echo "$MCP_RESULT" | jq -r '.gitnexus_flows // 0')
    SERENA_AVAIL=$(echo "$MCP_RESULT" | jq -r '.serena_available // false')
    
    # Write cache with MCP results
    if ! write_cache "$GITNEXUS_AVAIL" "$SERENA_AVAIL" "$GITNEXUS_REPO" "$GITNEXUS_SYMBOLS" "$GITNEXUS_RELS" "$GITNEXUS_FLOWS"; then
      echo "[ci-detect] ERROR: Cache write failed" >&2
      release_lock
      exit 1
    fi
    
    # Release lock
    release_lock
    
    if [[ "$GITNEXUS_AVAIL" == "true" ]] || [[ "$SERENA_AVAIL" == "true" ]]; then
      exit 0  # At least 1 CI tool available
    else
      exit 1  # No CI tools
    fi
    ;;
    
  *)
    # ═══════════════════════════════════════════
    # Phase 1: Check cache + signal skill agent
    # ═══════════════════════════════════════════
    
    # Ensure cache directory
    mkdir -p "$CACHE_DIR"
    
    # Check schema version → migrate nếu v1
    check_and_migrate_cache
    
    # Skip if not a git repo
    if ! git rev-parse HEAD >/dev/null 2>&1; then
      echo '{"status":"no_git","message":"Not a git repository — CI detection skipped"}'
      exit 1
    fi
    
    # Force re-scan via env var (respects lock in acquire_lock)
    if [[ "${MCV3_CI_RESCAN:-}" == "1" ]]; then
      echo "[ci-detect] MCV3_CI_RESCAN=1 — forcing re-scan" >&2
      NEEDS_RESCAN=true
    fi
    
    # ── Check per-tool TTL ──
    if [[ "$NEEDS_RESCAN" != "true" ]] && [[ -f "$CACHE_FILE" ]]; then
      GITNEXUS_FRESH=$(check_tool_ttl "gitnexus" || echo "stale")
      SERENA_FRESH=$(check_tool_ttl "serena" || echo "stale")
      
      if [[ "$GITNEXUS_FRESH" == "fresh" ]] && [[ "$SERENA_FRESH" == "fresh" ]]; then
        # All tools fresh → no re-scan needed
        echo "{\"status\":\"all_fresh\",\"action\":\"load_cache\"}"
        exit 0
      fi
    fi
    
    # ── Cache stale or missing → try acquire lock ──
    if acquire_lock; then
      # Lock acquired → signal skill agent to perform MCP detection
      # Skill agent will:
      #   1. Call mcp__gitnexus__list_repos + mcp__serena__check_onboarding_performed
      #   2. Call ci-detect.sh --write-cache '<json>'
      echo "{\"status\":\"needs_scan\",\"action\":\"call_mcp_tools\"}"
      exit 0
    else
      # ── Lock NOT acquired ──
      if is_lock_stale; then
        # Stale lock (>60s) → break + re-acquire
        echo "[ci-detect] Breaking stale lock (>${STALE_TIMEOUT_SEC}s)" >&2
        if break_stale_lock; then
          echo "{\"status\":\"needs_scan\",\"action\":\"call_mcp_tools\",\"note\":\"stale_lock_broken\"}"
          exit 0
        fi
      fi
      
      # Valid lock held by another session → fallback
      echo "{\"status\":\"lock_held\",\"action\":\"fallback_grep\"}"
      exit 2
    fi
    ;;
esac
```

**Lưu ý:** Bash script xử lý lock acquire/release + cache management + git operations + repo disambiguation. Detection thực tế (gọi MCP tools `mcp__gitnexus__list_repos`, `mcp__serena__check_onboarding_performed`) được thực hiện bởi skill agent trong PRE-GATE — vì MCP tools chỉ accessible từ Claude.

**Detection handoff protocol (D2):**
- `ci-detect.sh` exit 0 với `ALL_FRESH=true`: skill đọc cache trực tiếp, không cần gọi MCP
- `ci-detect.sh` exit 0 với `NEEDS_SCAN=true`: skill gọi MCP tools → pass JSON results vào script → script write cache
- `ci-detect.sh` exit 2: lock held → skill fallback Grep/Glob ngay

**Acceptance criteria:**
- [ ] Script chạy được trên Git Bash + WSL (không bc, không pipefail — F21)
- [ ] **Two-phase CLI dispatch:** `ci-detect.sh` (Phase 1: check TTL + signal) và `ci-detect.sh --write-cache '<json>'` (Phase 2: write MCP results + release lock)
- [ ] Phase 1 output là JSON với `status`: `all_fresh` (load cache), `needs_scan` (call MCP), `lock_held` (fallback), `no_git` (skip)
- [ ] Phase 2 parse JSON từ skill agent → `write_cache()` → validate → release lock → exit 0/1
- [ ] Lock acquire: atomic (set -C noclobber), ghi PID|host|user|acquired_at|heartbeat_at
- [ ] Lock release: cleanup lock file (cả trong Phase 2 và error paths)
- [ ] Stale lock detection: heartbeat > 60 giây → break + re-acquire (D8)
- [ ] Per-tool TTL check: mỗi tool check `checked_at` + `ttl_hours` riêng (integer arithmetic)
- [ ] GitNexus-absent TTL = 4h, Serena-absent TTL = 1h (D3)
- [ ] Cache schema migration: v1 → force re-scan → v2 (F26)
- [ ] Repo disambiguation: git remote get-url origin → resolve repo name (F22)
- [ ] mkdir -p "$CACHE_DIR" trước khi ghi file (F24)
- [ ] Cache freshness quyết định: ALL fresh → no scan; ANY stale → scan
- [ ] Cache validation: `jq -e '.'` sau ghi
- [ ] Git short-circuit: not a git repo → exit 1 with `status=no_git` (D9)
- [ ] Force re-scan: `MCV3_CI_RESCAN=1` → bỏ qua TTL check (respects lock)
- [ ] Xử lý trường hợp cache file bị corrupt → re-scan
- [ ] `--write-cache` không có JSON argument → ERROR, release lock, exit 1

---

### Task 1.4: Update `protocols/README.md` — 0.25h

**File:** `.claude/skills/protocols/README.md`

Thêm entry:
```
| 20 | Code Intelligence Integration | Detect + lock + route GitNexus/Serena/Grep, freshness check, multi-dev | §20 |
```

**Acceptance criteria:**
- [ ] Protocol 20 được liệt kê trong quick map
- [ ] Format khớp với các entry khác

---

### Task 1.5: Manual test trên EUREKA-2026 — 0.25h

1. Chạy detection logic kiểm tra GitNexus availability (EUREKA-2026 đã index)
2. Chạy detection logic kiểm tra Serena availability
3. Verify cache file được tạo đúng schema v2 (per-tool checked_at + ttl_hours + schema_version + repo)
4. Verify lock được acquire và release đúng
5. Verify per-tool TTL: thay đổi `checked_at` thủ công → verify "stale" detection
6. Verify lock graceful fallback: simulate lock held → exit 2
7. Verify repo disambiguation: git remote get-url origin → repo name match

**Acceptance criteria:**
- [ ] GitNexus detected: available=true, repo="EUREKA-2026", index_commit được ghi, schema_version=2
- [ ] Serena detected: available=true/false, checked_at được ghi đúng per-tool TTL
- [ ] Cache file valid JSON, đúng schema v2
- [ ] Lock file: PID|host|acquired_at|heartbeat_at đúng format
- [ ] Per-tool TTL: Serena-absent TTL=1h → check sau >1h → re-scan
- [ ] Lock held → exit 2, không block
- [ ] Cache schema v1 → auto-migrate → v2

---

## Sprint 1 DoD

- [ ] Protocol 20 tồn tại + referenced trong protocols/README.md (9 sections, lock 60s + per-tool TTL + freshness + CI-ROUTE convention)
- [ ] Cache schema v2 valid (per-tool checked_at + ttl_hours + index_commit + schema_version + repo)
- [ ] ci-detect.sh hoạt động với 2-phase CLI (Phase 1: check+signal / Phase 2: --write-cache) + lock acquire/release (60s stale) + per-tool TTL (integer arithmetic) + repo disambiguation + mkdir -p + v1→v2 migration
- [ ] Exit codes: 0/1/2 đúng
- [ ] Manual test trên EUREKA-2026 PASS
- [ ] Lock graceful fallback test PASS (lock held → exit 2)
- [ ] Graceful degradation: test trên project không có GitNexus/Serena → available=false
- [ ] Windows Git Bash compatibility: no bc, no pipefail
