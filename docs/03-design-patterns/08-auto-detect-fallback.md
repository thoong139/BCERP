# 08 — Auto-Detect + Graceful Fallback

> **Mức độ ràng buộc:** KHUYẾN NGHỊ MẠNH
> **Rule liên quan:** CORE-033
> **Khi nào dùng:** Skill phụ thuộc tool optional có thể không cài đặt sẵn

---

## 1. Vấn đề pattern giải quyết

MCV3 phục vụ nhiều môi trường:
- Dev mới — chưa cài tool gì
- Dev experienced — có GitNexus + Serena
- CI/CD — minimal toolchain
- Multi-machine — mỗi máy state khác

**Anti-pattern:** Skill hardcode "must have X" → break trên môi trường thiếu X.

**Pattern giải quyết:**
- **Auto-detect** tool availability lần đầu
- Cache result với TTL
- **Auto-route** task → tool tốt nhất hiện có
- **Graceful fallback** về tool cơ bản nếu cần
- Zero regression: skill vẫn pass eval với tool absent

---

## 2. Pattern definition

### 2.1. Detection + Cache pattern

```bash
# Lần đầu:
detect_tool() {
  if command -v gitnexus &>/dev/null; then
    echo "available"
  else
    echo "absent"
  fi
}

result=$(detect_tool)
cache_json=$(jq -n --arg avail "$result" --arg ts "$(date -Iseconds)" \
  '{tool: "gitnexus", available: $avail, checked_at: $ts}')
echo "$cache_json" > .mc-data/work/_meta/tool-availability.json

# Lần sau (trong TTL):
if file_age < TTL:
  load from cache
else:
  re-detect
```

### 2.2. TTL strategy

| Tool state | TTL ngắn | TTL dài | Lý do |
|-----------|---------|---------|-------|
| available | 24h | — | Đã có → hiếm gỡ |
| absent | 1-4h | — | User có thể cài giữa session |

### 2.3. Auto-route matrix

```
Task               | Primary  | Secondary | Fallback (always available)
───────────────────|──────────|-----------|------------------------------
Symbol search      | Serena   | GitNexus  | Grep
Impact analysis    | GitNexus | -         | Manual trace
API route map      | GitNexus | -         | Grep
File overview      | Serena   | -         | Read
Find references    | Serena   | GitNexus  | Grep
```

### 2.4. Graceful degradation principle

```
def execute_task(task):
    if PRIMARY_TOOL_AVAILABLE:
        try:
            return primary_tool.execute(task)
        except TimeoutError:
            log("Primary tool timeout, falling back")
    if SECONDARY_TOOL_AVAILABLE:
        try:
            return secondary_tool.execute(task)
        except:
            pass
    # Always works
    return fallback_tool.execute(task)
```

---

## 3. Case study — Protocol 20 (GitNexus + Serena)

**Detection flow:**
```
ci-detect.sh:
  1. Check git repo → if not, exit early
  2. Try acquire .ci-cache.lock (atomic noclobber)
  3. If lock acquired:
     - Run gitnexus.health() → set GITNEXUS_AVAILABLE
     - Run serena.check() → set SERENA_AVAILABLE
     - Write cache, release lock
  4. If lock held by peer:
     - Exit 2 immediately → caller falls back to Grep
     - NO RETRY, NO BLOCK
```

**Cache TTL:**
- GitNexus available: 24h (đã index, ổn định)
- GitNexus absent: 4h (user có thể cài)
- Serena available: 24h
- Serena absent: 1h (cài nhanh hơn)

**Route execution (per Lane Agent):**
```
Agent QD3 (Security) needs to find sanitize patterns:

if SERENA_AVAILABLE:
  result = Serena.find_referencing_symbols("sanitize_input")
elif GITNEXUS_AVAILABLE:
  result = GitNexus.query("functions calling sanitize")
else:
  result = Grep("sanitize|escape|validate", glob="**/*.ts")

# Agent KHÔNG block — luôn có result
```

**Test eval:**
```
Mock CI=absent → skill phải pass:
  - All lanes complete
  - Signals reduced (no impact analysis) but valid
  - Status = "completed (CI absent — limited analysis)"
```

---

## 4. Variations / Edge cases

### 4.1. Partial availability

```
GitNexus available, Serena absent:
  - Symbol search → fallback Grep (Serena task)
  - Impact analysis → use GitNexus
  - Mixed strategy per task
```

### 4.2. Tool degraded (slow but available)

```
GitNexus available but slow (>30s/query):
  ├─ Set timeout per query
  ├─ Timeout exceeded → fallback Grep
  └─ Log: "GitNexus slow, used fallback for query X"
```

### 4.3. False positive cache

```
Cache says "available" but tool just uninstalled
   ↓
Tool call fails (E_NOT_FOUND)
   ↓
Skill catches → invalidate cache → fallback
   ↓
Next detection cycle re-check
```

### 4.4. CI environment

```
CI runner has no GitNexus/Serena (minimal env)
   ↓
Auto-detect → both absent
   ↓
Cache absent state with short TTL
   ↓
Skill runs với Grep only — slower but functional
```

---

## 5. Anti-patterns

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Hardcode `if not GitNexus: raise Error` | Auto-fallback to Grep |
| Re-detect tool mỗi PRE-GATE | Cache + TTL |
| Block khi lock conflict (peer detecting) | Exit immediately → fallback |
| TTL 7 ngày → tool đã gỡ vẫn dùng cache | TTL hợp lý (24h tối đa available) |
| Fallback dùng tool khác cũng cần install | Fallback PHẢI luôn available (Grep/Glob là core) |
| User phải config "enable_X=true" | Zero-config auto-detect |
| Test eval không cover "tool absent" case | Phải có eval cho cả 2 states |
| Skill abort khi fallback chậm | Fallback vẫn complete, chỉ log warning |
| Cache không versioned | Cần `$schema` để evolve |
| Detect mỗi lần spawn agent (10 lane × 1 detect/lane) | Detect 1 lần ở skill PRE-GATE, share qua CI_CONTEXT |

---

## 6. Checklist áp dụng

**Khi skill phụ thuộc tool optional:**

- [ ] Tool detection function với try-catch
- [ ] Cache result tại `.mc-data/work/_meta/{tool}-cache.json`
- [ ] Cache file có `$schema` + `checked_at` timestamp
- [ ] TTL hợp lý (available 24h, absent 1-4h)
- [ ] Lock file cho concurrent detection (atomic noclobber)
- [ ] Lock conflict → exit 2 → fallback (KHÔNG retry)
- [ ] Fallback tool LUÔN available (Grep/Read là core)
- [ ] Test eval với cả tool=true và tool=false
- [ ] Document fallback strategy trong SKILL.md
- [ ] Log degradation events vào session-log.json
- [ ] Escape hatch: `MCV3_X_RESCAN=1` force re-detect
- [ ] Inject availability info vào agent prompts (CORE-037 §4)

---

## 7. Liên kết

- **Standard:** [`../01-architecture/04-code-intelligence.md`](../01-architecture/04-code-intelligence.md)
- **Rule:** CORE-033 trong [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4j
- **Protocol 20:** [`.claude/skills/protocols/20-code-intelligence.md`](../../.claude/skills/protocols/20-code-intelligence.md)
- **Scripts:** `.claude/scripts/ci-detect.sh`, `ci-freshness-check.sh`
- **Related patterns:**
  - [`02-ci-first-integration.md`](02-ci-first-integration.md) — Specialized version cho code intelligence
  - [`09-multi-session-locking.md`](09-multi-session-locking.md) — Lock pattern
