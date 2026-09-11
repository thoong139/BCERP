# Sprint 2: Per-tool TTL + Index Freshness + Agent Context Injection

> **Estimate:** 2.5h | **Priority:** P0 | **Dependencies:** S1
> **Revised v0.3:** GitNexus-absent TTL 4h (was 24h), integer arithmetic (F21), 4 injection templates (was 3), lock timeout 60s (was 5min)

---

## Mục tiêu

Hoàn thiện cache layer với per-tool TTL (dùng integer arithmetic), tạo index freshness check (F16), và cập nhật agent context injection với 4 templates kèm freshness warning. Đây là prerequisite cho S3-S6.

---

## Tasks

### Task 2.1: Hoàn thiện Per-Tool TTL Cache Logic — 0.5h

**File:** `.claude/scripts/ci-detect.sh` (update từ S1)

Bổ sung logic hoàn chỉnh cho per-tool TTL (pure bash integer arithmetic, không `bc`):

```bash
# Per-tool TTL check — pure integer arithmetic (không bc — F21)
# Mỗi tool có TTL riêng — tool có thể được re-check độc lập
#
# TTL values (hours):
#   GitNexus available=true  → 24h
#   GitNexus available=false → 4h   (user có thể cài + index giữa phiên)
#   Serena   available=true  → 24h
#   Serena   available=false → 1h   (user có thể cài bất cứ lúc nào)

check_tool_ttl() {
  local tool=$1  # "gitnexus" | "serena"
  
  local available=$(jq -r ".$tool.available // false" "$CACHE_FILE" 2>/dev/null || echo "false")
  local checked_at=$(jq -r ".$tool.checked_at // \"1970-01-01T00:00:00Z\"" "$CACHE_FILE" 2>/dev/null || echo "1970-01-01T00:00:00Z")
  local ttl_hours=$(jq -r ".$tool.ttl_hours // 24" "$CACHE_FILE" 2>/dev/null || echo "24")
  
  # Convert checked_at to epoch seconds
  local checked_epoch
  if checked_epoch=$(date -d "$checked_at" +%s 2>/dev/null); then
    :  # Linux/Git Bash
  else
    echo "stale"  # Parse failed → treat as stale
    return
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

# Override: MCV3_CI_RESCAN=1 → tất cả tools đều "stale"
# Respects lock — nếu lock bị giữ, env var không override
if [[ "${MCV3_CI_RESCAN:-}" == "1" ]]; then
  echo "[ci-detect] MCV3_CI_RESCAN=1 — forcing re-scan (if lock available)"
  NEEDS_RESCAN=true
fi
```

**Acceptance criteria:**
- [ ] Per-tool TTL logic: GitNexus-present 24h, GitNexus-absent 4h, Serena-present 24h, Serena-absent 1h
- [ ] `MCV3_CI_RESCAN=1` force re-scan (không cần biết cache, respects lock)
- [ ] Stale GitNexus index warning (> 7 ngày từ `indexed_at`) — WARNING, không block
- [ ] Cache validation pass sau mỗi lần ghi: `jq -e '.'`
- [ ] Pure bash integer arithmetic — không dùng `bc` (F21)

---

### Task 2.2: Tạo `ci-freshness-check.sh` — 0.75h

**File:** `.claude/scripts/ci-freshness-check.sh`

**Mục đích:** So sánh HEAD hiện tại với `index_commit` trong cache, xuất cảnh báo theo mức độ. Chạy mỗi PRE-GATE, không cache.

**Logic:**
```bash
#!/usr/bin/env bash
# ci-freshness-check.sh — Compare HEAD vs GitNexus index commit
# Output: freshness status (stdout) — parseable JSON
# Exit: 0 (OK) | 1 (stale — WARNING) | 2 (significantly stale — STRONG) | 3 (severely stale — SEVERE)

CACHE_FILE=".mc-data/work/_meta/code-intelligence.json"

# ── Short-circuit: không phải git repo → skip ──
if ! git rev-parse HEAD >/dev/null 2>&1; then
  echo '{"status":"skipped","reason":"not a git repository"}'
  exit 0
fi

# ── Check if GitNexus available ──
if [[ ! -f "$CACHE_FILE" ]]; then
  echo '{"status":"skipped","reason":"no cache file"}'
  exit 0
fi

GITNEXUS_AVAILABLE=$(jq -r '.gitnexus.available // false' "$CACHE_FILE" 2>/dev/null || echo "false")
if [[ "$GITNEXUS_AVAILABLE" != "true" ]]; then
  echo '{"status":"skipped","reason":"gitnexus not available"}'
  exit 0
fi

# ── Get index commit from cache ──
INDEX_COMMIT=$(jq -r '.gitnexus.index_commit // "unknown"' "$CACHE_FILE" 2>/dev/null || echo "unknown")
if [[ "$INDEX_COMMIT" == "unknown" ]] || [[ -z "$INDEX_COMMIT" ]]; then
  echo '{"status":"unknown","reason":"index_commit missing in cache"}'
  exit 0
fi

# ── Compare with HEAD ──
HEAD_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
if [[ "$HEAD_COMMIT" == "unknown" ]]; then
  echo '{"status":"skipped","reason":"cannot resolve HEAD"}'
  exit 0
fi

if [[ "$INDEX_COMMIT" == "$HEAD_COMMIT" ]]; then
  echo "{\"status\":\"ok\",\"behind\":0,\"index_commit\":\"$INDEX_COMMIT\",\"head\":\"$HEAD_COMMIT\"}"
  exit 0
fi

# ── Count commits behind (integer) ──
BEHIND=$(git rev-list --count "$INDEX_COMMIT..$HEAD_COMMIT" 2>/dev/null || echo "unknown")

if [[ "$BEHIND" == "unknown" ]]; then
  echo "{\"status\":\"unknown\",\"reason\":\"index_commit not in history (index from different branch?)\"}"
  exit 0
fi

# ── Warning levels ──
if [[ "$BEHIND" -eq 0 ]]; then
  echo "{\"status\":\"ok\",\"behind\":0}"
  exit 0
elif [[ "$BEHIND" -le 5 ]]; then
  echo "{\"status\":\"warning\",\"behind\":$BEHIND,\"level\":\"light\",\"message\":\"GitNexus index behind HEAD by $BEHIND commits. Impact analysis may miss recent changes.\"}"
  exit 1
elif [[ "$BEHIND" -le 20 ]]; then
  echo "{\"status\":\"warning\",\"behind\":$BEHIND,\"level\":\"strong\",\"message\":\"Index significantly behind ($BEHIND commits). Consider: gitnexus analyze\"}"
  exit 2
else
  echo "{\"status\":\"warning\",\"behind\":$BEHIND,\"level\":\"severe\",\"message\":\"Index is $BEHIND commits behind HEAD. Impact analysis likely incomplete. Recommend re-index before continuing.\"}"
  exit 3
fi
```

**Index staleness check (separate — GitNexus index age):**
```bash
# Kiểm tra index AGE (không phải freshness vs HEAD)
INDEXED_AT=$(jq -r '.gitnexus.indexed_at // "1970-01-01T00:00:00Z"' "$CACHE_FILE" 2>/dev/null || echo "1970-01-01T00:00:00Z")
# Nếu index > 7 ngày → WARNING: "GitNexus index is N days old. Consider re-indexing."
```

**Acceptance criteria:**
- [ ] So sánh HEAD vs `index_commit` qua `git rev-list --count` (integer)
- [ ] 4 mức: OK (exit 0), WARNING (exit 1, ≤5 behind), STRONG (exit 2, 6-20), SEVERE (exit 3, >20)
- [ ] Output là JSON (dễ parse bởi skill)
- [ ] Index age check: > 7 ngày → additional warning
- [ ] Handle edge cases: không phải git repo, index_commit missing, index_commit not in history
- [ ] Short-circuit: không phải git repo → skip check ngay (D9)
- [ ] Chạy trên Git Bash + WSL
- [ ] Thời gian chạy < 0.1s

---

### Task 2.3: Tạo `ci-inject-context.sh` (v2 — 4 templates + freshness warning) — 0.75h

**File:** `.claude/scripts/ci-inject-context.sh`

**Mục đích:** Đọc `code-intelligence.json` + kết quả freshness check → sinh context snippet để inject vào agent prompt. 4 templates (theo architecture §9): Both-OK, Both-Stale, GitNexus-only, Serena-only.

**Logic:**
```bash
#!/usr/bin/env bash
# ci-inject-context.sh — Generate CI context snippet for agent prompts
# Output: CI context text (stdout) — Markdown, <600 chars per template
# Exit: 0 (context generated) | 1 (no CI tools available)

CACHE_FILE=".mc-data/work/_meta/code-intelligence.json"

if [[ ! -f "$CACHE_FILE" ]]; then
  exit 1
fi

GITNEXUS=$(jq -r '.gitnexus.available // false' "$CACHE_FILE" 2>/dev/null || echo "false")
SERENA=$(jq -r '.serena.available // false' "$CACHE_FILE" 2>/dev/null || echo "false")

# ── Get freshness status ──
FRESHNESS_JSON=$(.claude/scripts/ci-freshness-check.sh 2>/dev/null || echo '{"status":"skipped"}')
FRESHNESS_STATUS=$(echo "$FRESHNESS_JSON" | jq -r '.status // "skipped"')
FRESHNESS_BEHIND=$(echo "$FRESHNESS_JSON" | jq -r '.behind // 0')
FRESHNESS_LEVEL=$(echo "$FRESHNESS_JSON" | jq -r '.level // "none"')

# ── Build freshness warning (nếu cần) ──
FRESHNESS_WARNING=""
if [[ "$FRESHNESS_STATUS" == "warning" ]]; then
  if [[ "$FRESHNESS_LEVEL" == "severe" ]]; then
    FRESHNESS_WARNING="⚠️ GitNexus index is $FRESHNESS_BEHIND commits behind HEAD. Impact analysis WILL BE INCOMPLETE. Strongly recommend: \`gitnexus analyze\`"
  elif [[ "$FRESHNESS_LEVEL" == "strong" ]]; then
    FRESHNESS_WARNING="⚠️ GitNexus index is $FRESHNESS_BEHIND commits behind HEAD. Impact analysis may be incomplete. Consider: \`gitnexus analyze\`"
  else
    FRESHNESS_WARNING="⚠️ GitNexus index is $FRESHNESS_BEHIND commits behind HEAD. Impact analysis may miss recent changes."
  fi
fi

# ── 4 Templates ──
if [[ "$GITNEXUS" == "true" ]] && [[ "$SERENA" == "true" ]]; then
  REPO=$(jq -r '.gitnexus.repo' "$CACHE_FILE")
  SYMBOLS=$(jq -r '.gitnexus.symbols' "$CACHE_FILE")
  FLOWS=$(jq -r '.gitnexus.execution_flows' "$CACHE_FILE")

  if [[ -z "$FRESHNESS_WARNING" ]]; then
    # Template: Both-OK
    cat <<TEMPLATE
## Code Intelligence: GitNexus + Serena

Both GitNexus (graph: $REPO, $SYMBOLS symbols, $FLOWS flows) and Serena (LSP) are available.
- System-level (impact, flows, routes) → GitNexus
- Symbol-level (def, refs, rename) → Serena
- Pre-commit → GitNexus detect_changes()
TEMPLATE
  else
    # Template: Both-Stale
    cat <<TEMPLATE
## Code Intelligence: GitNexus + Serena

Both GitNexus (graph: $REPO, $SYMBOLS symbols, $FLOWS flows) and Serena (LSP) are available.
- System-level (impact, flows, routes) → GitNexus
- Symbol-level (def, refs, rename) → Serena (real-time, unaffected by index freshness)
- Pre-commit → GitNexus detect_changes()

$FRESHNESS_WARNING
TEMPLATE
  fi

elif [[ "$GITNEXUS" == "true" ]]; then
  REPO=$(jq -r '.gitnexus.repo' "$CACHE_FILE")
  SYMBOLS=$(jq -r '.gitnexus.symbols' "$CACHE_FILE")
  FLOWS=$(jq -r '.gitnexus.execution_flows' "$CACHE_FILE")
  cat <<TEMPLATE
## Code Intelligence: GitNexus

GitNexus is available ($REPO, $SYMBOLS symbols, $FLOWS flows).
- Before editing any symbol → gitnexus_impact({target, direction: "upstream"})
- Exploring code → gitnexus_query({query: "concept"})
- Pre-commit → gitnexus_detect_changes()
- NEVER rename with find-and-replace — use gitnexus_rename

$FRESHNESS_WARNING
TEMPLATE

elif [[ "$SERENA" == "true" ]]; then
  cat <<TEMPLATE
## Code Intelligence: Serena

Serena LSP tools are available (real-time, always current).
- find_definition → precise go-to-definition
- find_references → all call sites
- rename_symbol → safe refactoring (not find-and-replace)
- get_symbols_overview → file structure
TEMPLATE

else
  exit 1
fi
```

**Acceptance criteria:**
- [ ] 4 templates: Both-OK, Both-Stale, GitNexus-only, Serena-only
- [ ] Each template < 600 chars
- [ ] Freshness warning được append tự động khi index stale (3 mức: light/strong/severe)
- [ ] Serena-only template notes "real-time, always current" (không bị ảnh hưởng bởi index freshness)
- [ ] Exit 1 khi không có tool nào → skill không inject
- [ ] Output text có thể inject trực tiếp vào agent prompt (Markdown)

---

### Task 2.4: Cập nhật PRE-GATE Pattern cho Tất Cả Skills — 0.25h

**Cập nhật Protocol 20 §20.7 với pattern 2 bước:**

```markdown
### PRE-GATE CI Integration Pattern (Áp dụng cho mọi skill)

#### Step 0.Na: Load Code Intelligence Capabilities

1. `ci-detect.sh` → check per-tool TTL
   ├── ALL fresh → load cache, exit 0
   ├── ANY stale → acquire lock → scan MCP tools → write cache → release, exit 0
   └── Lock held → exit 2 → fallback Grep/Glob (current behavior, no regression)

2. Read `.mc-data/work/_meta/code-intelligence.json`
3. Set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`

#### Step 0.Nb: Index Freshness Check

1. `ci-freshness-check.sh` → so sánh HEAD vs index_commit
2. Parse exit code + JSON output
3. Lưu freshness status để inject vào agent context
4. Nếu SEVERE (>20 behind) → hiển thị cảnh báo cho user
5. Short-circuit: không phải git repo → skip

#### Step 0.Nc: Agent Context Injection

1. Nếu CI available → `ci-inject-context.sh` → append vào agent spawn instructions
2. Nếu no CI → continue with Grep/Glob (current behavior)
3. Kèm freshness warning trong agent context (Both-Stale template khi index stale)

**Graceful:**
- ci-detect.sh fail → WARNING → continue without CI tools
- ci-freshness-check.sh fail → skip freshness check → continue
- Lock held → fallback Grep/Glob → no regression
```

**Acceptance criteria:**
- [ ] PRE-GATE pattern có 3 sub-steps: Na (detection), Nb (freshness), Nc (injection)
- [ ] Graceful degradation cho tất cả các điểm failure
- [ ] Mỗi skill chỉ thêm ~10-15 dòng vào PRE-GATE
- [ ] Git short-circuit: không git repo → skip Ng (D9)

---

### Task 2.5: Manual test — Full detection + freshness + injection — 0.25h

1. Chạy `ci-detect.sh` trên EUREKA-2026 → verify cache + lock
2. Chạy `ci-freshness-check.sh` → verify đúng exit code (0 nếu HEAD == index_commit)
3. Simulate stale index: chỉnh `index_commit` về commit cũ → verify exit 1/2/3 (integer arithmetic)
4. Chạy `ci-inject-context.sh` → verify output đúng format + freshness warning
5. Verify output text < 600 chars cho tất cả templates
6. Simulate lock held → verify exit 2 + fallback behavior

**Acceptance criteria:**
- [ ] Both-OK template < 600 chars
- [ ] Both-Stale template < 700 chars (freshness warning thêm)
- [ ] GitNexus-only template < 500 chars
- [ ] Serena-only template < 400 chars
- [ ] Freshness check: exit 0 khi HEAD == index_commit
- [ ] Freshness check: exit 1/2/3 tương ứng với behind count (integer comparison)
- [ ] Agent injection có freshness warning khi index stale
- [ ] Lock graceful fallback: ci-detect exit 2 → skill dùng Grep

---

## Sprint 2 DoD

- [ ] Per-tool TTL hoạt động đúng cho 4 trường hợp (GitNexus-absent=4h, Serena-absent=1h)
- [ ] `MCV3_CI_RESCAN=1` force re-scan (respects lock)
- [ ] ci-freshness-check.sh hoạt động — 4 mức cảnh báo + git short-circuit
- [ ] ci-inject-context.sh sinh context + freshness warning đúng cho 4 scenarios (Both-OK, Both-Stale, GitNexus-only, Serena-only)
- [ ] PRE-GATE integration pattern documented (3 sub-steps Na/Nb/Nc)
- [ ] Agent injection manual test PASS (có + không có freshness warning)
- [ ] Lock graceful fallback manual test PASS
- [ ] All scripts chạy trên Git Bash + WSL (integer arithmetic, no bc)
