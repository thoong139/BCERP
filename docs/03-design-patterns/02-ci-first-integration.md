# 02 — CI-First Integration

> **Mức độ ràng buộc:** KHUYẾN NGHỊ MẠNH cho skill cần đọc/phân tích code
> **Rule liên quan:** CORE-033
> **Khi nào dùng:** Skill cần impact analysis, symbol search, API route map, hoặc deep code analysis

---

## 1. Vấn đề pattern giải quyết

Khi skill cần đọc code, có 3 lớp tool:
- **GitNexus** — semantic graph, impact analysis (cao cấp)
- **Serena** — LSP symbol search, safe rename (cao cấp)
- **Grep/Glob** — text pattern matching (cơ bản, luôn có)

**Vấn đề trước CI-First:**
- Skill A hardcode "phải có GitNexus" → user không có GitNexus → skill block
- Skill B luôn dùng Grep → bỏ lỡ impact analysis quan trọng → bug miss
- 2 skills cùng detect GitNexus → race condition

**Pattern giải quyết:**
- Skill PRE-GATE detect CI tools 1 lần (cache TTL)
- Auto-route task → tool phù hợp (Primary → Fallback)
- Graceful degradation: lock conflict hoặc tool absent → Grep ngay (zero regression)

---

## 2. Pattern definition

### 2.1. 3-step CI PRE-GATE (Na/Nb/Nc)

```
Phase Init {
  Step Na: bash .claude/scripts/ci-detect.sh
           → set GITNEXUS_AVAILABLE, SERENA_AVAILABLE
           → cache .mc-data/work/_meta/code-intelligence.json

  Step Nb: bash .claude/scripts/ci-freshness-check.sh
           → check git rev-list HEAD vs cached index_commit
           → 4 mức: ok / light / strong / severe

  Step Nc: if CI available:
             CI_CONTEXT=$(bash .claude/scripts/ci-inject-context.sh)
             pass CI_CONTEXT vào agent prompts
}
```

### 2.2. CI-ROUTE Matrix

```
Task                          | Primary           | Fallback
─────────────────────────────|───────────────────|──────────
Impact analysis              | GitNexus.impact() | Manual grep
Find symbol definition       | Serena.find_def   | Grep
Find references              | Serena.find_refs  | Grep
Safe rename                  | Serena.rename     | Manual
API route map                | GitNexus.routes() | Grep
Execution flow understanding | GitNexus.query()  | Read + trace
File structure overview      | Serena.symbols    | Read
```

### 2.3. Agent prompt CI context injection

```markdown
## Section 4: CI Context (CORE-037 §4)

GitNexus available: true (index at abc123, 3 commits behind HEAD)
Serena available: true
CI-ROUTE: Primary tools; fallback Grep when needed

Tasks for you:
- Use Serena.find_symbol() for symbol lookup (NOT grep)
- Use GitNexus.impact() before suggesting fixes (assess blast radius)
```

---

## 3. Case study — wf-fix-bugs Phase 4 (Find Bugs)

```
Phase 4 init:
  Na: ci-detect.sh → GitNexus available, Serena available
  Nb: freshness check → 3 commits behind, OK
  Nc: CI_CONTEXT prepared

  Spawn 11 lane agents song song, mỗi agent prompt có Section 4 (CI Context).

QD1 (Functional) agent:
  - Đọc feature spec → tìm execution flow qua GitNexus.query()
  - Trace từ UI entry → handler → DB → response

QD3 (Security) agent:
  - Tìm input validation qua Serena.find_referencing_symbols(sanitize_input)
  - List places thiếu validation

QD4 (Performance) agent:
  - GitNexus.impact() trên function bị suspect → blast radius
  - Đánh giá risk fix

QD10 (Integration) agent:
  - GitNexus.route_map() lấy API contract
  - So sánh với feature spec → phát hiện drift
```

**Kết quả:** Lane agents nhanh hơn 3-5x so với chỉ Grep, và detect được bugs mà Grep không thể (semantic context).

### 3.1. wf-fix-bugs Phase 4 khi CI absent

```
Na: ci-detect.sh → GitNexus absent, Serena absent
Nb: skip (no index)
Nc: CI_CONTEXT minimal

Lane agents prompt:
  CI tools unavailable, use Grep/Read fallback
  - QD1: trace execution qua Read + Grep
  - QD3: find sanitize patterns qua Grep -r "sanitize|escape"
  - QD4: skip impact (manual eyeball)

→ Slower nhưng KHÔNG block. Test eval: pass kể cả khi CI=false.
```

---

## 4. Variations / Edge cases

### 4.1. Mixed availability

GitNexus có, Serena absent → mỗi task route theo bảng (impact → GitNexus, symbol search → Grep).

### 4.2. Stale index

```
behind = 6-20 commits
→ STRONG WARNING: "Index 12 commits behind HEAD. Impact analysis may miss recent changes."
→ Vẫn dùng GitNexus nhưng cảnh báo user
→ behind > 20 → fallback Grep an toàn hơn
```

### 4.3. Lock conflict

```
ci-detect.sh exit 2 (lock held by peer)
→ Skill PHẢI fallback Grep ngay, KHÔNG block, KHÔNG retry
→ Lần sau lock release → cache fresh → tiếp tục dùng CI
```

### 4.4. MCV3_CI_RESCAN escape

```bash
MCV3_CI_RESCAN=1 /wf-fix-bugs ...
→ Ép re-detect, ignore TTL cache
→ Vẫn tôn trọng lock
```

---

## 5. Anti-patterns

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Hardcode `if ! GITNEXUS: exit 1` | Auto-detect + fallback |
| Re-detect mỗi PRE-GATE bất kể TTL | Cache check trước |
| Block khi lock bị giữ → retry 5 lần | Exit 2 → fallback ngay |
| Bỏ qua freshness check | Index stale → recommend Grep |
| Quên inject CI_CONTEXT vào agent | Agent không biết → bỏ lỡ optimization |
| User phải config `enable_gitnexus=true` | Zero-config auto |
| Lane agent kiểm tra `if not GITNEXUS_AVAILABLE: raise` | Agent đọc CI_CONTEXT, tự chọn tool |
| Cache không versioned | Cần `$schema` để evolve |

---

## 6. Checklist áp dụng

**Khi tạo skill cần đọc code:**

- [ ] Phase Init có step Na (call `ci-detect.sh`)
- [ ] Phase Init có step Nb (call `ci-freshness-check.sh`)
- [ ] Phase Init có step Nc (build CI_CONTEXT khi available)
- [ ] Mọi agent spawn có Section 4 (CI Context) trong prompt
- [ ] Agent prompt liệt kê CI-ROUTE matrix relevant
- [ ] Skill graceful degradation: pass eval với `GITNEXUS_AVAILABLE=false` + `SERENA_AVAILABLE=false`
- [ ] Skill log CI events vào `session-log.json` (CI_DETECT, CI_FRESHNESS, CI_FALLBACK)
- [ ] KHÔNG hardcode tool availability check trong skill logic
- [ ] Document fallback strategy trong SKILL.md

---

## 7. Liên kết

- **Standard:** [`../01-architecture/04-code-intelligence.md`](../01-architecture/04-code-intelligence.md) — overview tích hợp CI
- **Rule:** CORE-033 trong [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4j
- **Protocol 20:** [`.claude/skills/protocols/20-code-intelligence.md`](../../.claude/skills/protocols/20-code-intelligence.md) — chi tiết kỹ thuật
- **Scripts:** `.claude/scripts/{ci-detect,ci-freshness-check,ci-inject-context}.sh`
- **Related patterns:**
  - [`08-auto-detect-fallback.md`](08-auto-detect-fallback.md) — general fallback pattern
  - [`05-agent-prompt-template.md`](05-agent-prompt-template.md) — CI Context là Section 4
