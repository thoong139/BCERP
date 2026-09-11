# Master Plan: Code Intelligence Integration — GitNexus + Serena

> **Date:** 2026-05-06 (revised 2026-05-06 — v0.3 codebase reconciliation)
> **Author:** Claude Opus 4.7
> **Trigger:** Người dùng cài GitNexus + Serena trên dự án EUREKA-2026, nhưng MCV3 workflow skills (`wf-*`) không tận dụng được hai công cụ code intelligence này.
> **Base version:** MCV3 current (2026-05-06)
> **Revision v0.3:** Codebase reconciliation — fix 26 issues từ deep-dive review: procedure file names khớp thực tế, S4 rewrite target sub-skills, D5 resolved (injection-only, không sửa agent .md), `bc` → pure bash integer arithmetic, repo disambiguation, `ci-route.sh` removed (làm convention trong Protocol 20), template path fix, lock timeout 60s, GitNexus-absent TTL 4h, `MCV3_CI_RESCAN` respects lock, v1→v2 cache migration, `mkdir -p` + git repo short-circuit, token measurement methodology defined.

---

## 1. Vấn đề (Problem Statement)

### 1.1. Hiện trạng

MCV3 có 28 workflow skills (`wf-*`) và 62 agents. Tất cả đều dùng **Grep/Glob/Read** làm công cụ khám phá code duy nhất.

Trong khi đó:
- **GitNexus** đã có 6 standalone skill trong `.claude/skills/gitnexus/` — nhưng các skill này là standalone (người dùng phải gọi thủ công), không được tích hợp vào workflow chính.
- **Serena** là MCP server mới được cài, cung cấp LSP-based semantic tools (find definition, find references, rename symbol, get symbols overview).
- **EUREKA-2026** đã được index bởi GitNexus (169K symbols, 339K relationships, 300 execution flows) và CLAUDE.md đã có block GitNexus instructions.

**Khoảng trống:** Khi người dùng chạy `/wf-implement-feature` hoặc `/wf-fix-bugs` trên EUREKA-2026, các skill này:
- Không biết GitNexus tồn tại → dùng Grep thay vì `gitnexus_impact()`
- Không biết Serena tồn tại → dùng Glob thay vì `find_references()`
- Không có cơ chế auto-detect → người dùng không chuyên không thể tự cấu hình
- Không có cơ chế lock → nhiều phiên song song cùng ghi cache → race condition
- Không kiểm tra index freshness → sau `git pull`, kết quả CI tools không phản ánh code mới
- Không phân biệt GitNexus repo nào thuộc về target project → máy có nhiều repo indexed

### 1.2. Impact

| Vấn đề | Hậu quả |
|--------|---------|
| CORE-020 Safety Gate dùng Grep | False negatives: không tìm thấy code liên quan → duplicate implementation |
| Không có impact analysis trước khi sửa | Break code không lường trước, đặc biệt trên codebase 169K symbols |
| Không tận dụng LSP cho refactoring | Rename bằng find-and-replace thủ công → bỏ sót references |
| wf-legacy-scan dùng Glob/Grep thô | Tốn token hơn, kết quả kém chính xác hơn `gitnexus_query()` |
| Người dùng không chuyên | Không biết GitNexus/Serena là gì, không biết nên dùng lúc nào |
| Nhiều phiên song song không lock | Race condition ghi cache → corrupt → mất CI capability |
| Không check index freshness | Sau `git pull`, impact analysis thiếu code đồng nghiệp vừa push |
| TTL 24h thống nhất | User cài Serena lúc 10h, skill vẫn không thấy đến 10h hôm sau |
| Nhiều GitNexus repo trên cùng máy | Skill query nhầm repo → kết quả sai hoặc rỗng |

### 1.3. Constraint: Không hard dependency

- Có những dự án không dùng GitNexus hoặc Serena
- MCV3 phải hoạt động bình thường trên mọi dự án
- Graceful degradation là bắt buộc
- Phải an toàn khi nhiều phiên chạy song song (cùng skill hoặc khác skill)
- Phải an toàn trong môi trường team (nhiều developer push/pull)
- Phải xác định đúng GitNexus repo cho target project (không query nhầm repo)
- Bash scripts phải chạy trên Git Bash + WSL (không dùng `bc`, không `pipefail` nếu bash < 4.4)

---

## 2. Mục tiêu (Goals)

### 2.1. Functional Goals

1. **Auto-detect:** Skills tự động phát hiện GitNexus và Serena availability trên target project, không cần user config.
2. **Intelligent routing:** Mỗi code intelligence task được route đến tool tối ưu (GitNexus, Serena, hoặc cả hai).
3. **Graceful degradation:** Thiếu tool nào → fallback về tool còn lại → fallback về Grep/Glob. Không block. Lock bị giữ → fallback ngay.
4. **Non-technical user:** Người dùng không cần biết GitNexus/Serena là gì. Hệ thống tự quyết định.
5. **Protocol-based:** Mọi skill dùng chung cơ chế qua Protocol 20, không implement riêng lẻ. "CI-ROUTE" là convention trong Protocol 20 (không phải script riêng).
6. **Concurrency-safe:** Nhiều phiên song song không gây race condition trên cache (lock mechanism).
7. **Index-aware:** Mọi PRE-GATE kiểm tra index có khớp HEAD không → cảnh báo nếu stale.
8. **Repo disambiguation:** Xác định đúng GitNexus repo cho target project qua `git remote get-url origin`.

### 2.2. Non-Functional Goals

| Metric | Hiện tại | Target |
|--------|----------|--------|
| Skills aware of code intelligence | 0/28 | 7/28 skills (3 P0 + 2 P1 + 2 P2) |
| Auto-detection | Không có | Tự động, per-tool TTL |
| Impact analysis before edits | Không có | Bắt buộc với GitNexus |
| Semantic refactoring | Find-and-replace | Serena rename khi available |
| Token efficiency (code exploration) | 100% inline Grep/Glob | -40% đến -60% với GitNexus query |
| User prompts about tools | N/A | 0 (tự động) |
| Concurrency safety | N/A | Lock-protected cache write |
| Index freshness awareness | Không có | Check mỗi PRE-GATE |

### 2.3. Out of scope

- Tạo GitNexus index cho dự án (người dùng tự chạy `gitnexus analyze`)
- Cài đặt Serena MCP server (người dùng tự cài)
- Thay đổi core logic của skills (chỉ thêm enhancement layer)
- Tích hợp vào tất cả 28 skills (chỉ P0 + P1 + P2 skills trong plan này)
- Tự động re-index GitNexus (người dùng tự chạy khi được cảnh báo)
- Sửa agent definition files (D5: context injection qua prompt, không sửa agent .md)

---

## 3. Định hướng giải pháp (Solution Direction)

### 3.1. Nguyên tắc thiết kế

1. **Surgical (BHV-003):** Thêm detection + routing vào PRE-GATE của skill, không sửa core execution logic.
2. **Protocol-first:** Tạo `protocols/20-code-intelligence.md` làm single source of truth cho mọi skill.
3. **Lock-first:** Cache write được bảo vệ bởi lock file. Lock bị giữ → fallback Grep/Glob (không block, không regression).
4. **Freshness-aware:** Mỗi PRE-GATE kiểm tra index staleness qua `git rev-parse HEAD` (<0.01s). Nếu không phải git repo → skip ngay.
5. **Per-tool TTL:** Mỗi tool có TTL riêng, phản ánh khả năng thay đổi thực tế.
6. **Tool-agnostic interface:** Skills gọi "tasks" (find_definition, impact_analysis...) — Protocol 20 routing matrix route đến tool cụ thể. "CI-ROUTE" là **convention trong Protocol 20** (không phải script riêng).
7. **Graceful degradation built-in:** Mọi routing decision có fallback path.
8. **Injection-only agents:** D5 — CI context được inject vào agent prompt khi spawn, không sửa agent definition files.

### 3.2. Kiến trúc tổng thể

```
┌──────────────────────────────────────────────┐
│          MCV3 Skills (wf-*)                   │
│  Skills KHÔNG cần biết tool cụ thể nào         │
│  Chỉ nói: "tôi cần tìm references của X"      │
│  CI-ROUTE là convention trong Protocol 20     │
└──────────────────┬───────────────────────────┘
                   │
┌──────────────────▼───────────────────────────┐
│   Code Intelligence Protocol (Protocol 20)    │
│                                               │
│   • detect() + lock: phát hiện tools           │
│   • repo-disambiguate(): chọn đúng repo       │
│   • freshness(): check index vs HEAD          │
│   • route(task, context): chọn tool tối ưu    │
│   • merge(results): hợp nhất kết quả          │
│   • degrade(): fallback khi thiếu tool        │
└────┬──────────────────┬──────────────────┬────┘
     │                  │                  │
┌────▼──────┐   ┌───────▼──────┐   ┌──────▼──────┐
│ GitNexus  │   │   Serena     │   │ Grep/Glob   │
│ (Graph)   │   │  (LSP/IDE)   │   │ (Fallback)  │
│           │   │               │   │              │
│ • impact  │   │ • find_def   │   │ • grep       │
│ • query   │   │ • find_refs  │   │ • glob       │
│ • context │   │ • get_symbols│   │ • read       │
│ • cypher  │   │ • rename     │   │ • manual     │
│ • routes  │   │ • onboarding │   │              │
│ • changes │   │              │   │              │
└───────────┘   └───────────────┘   └──────────────┘
     │                  │                  │
     └──────────────────┴──────────────────┘
                        │
          ┌─────────────▼──────────────┐
          │  Cache Layer               │
          │  • code-intelligence.json  │
          │  • .ci-cache.lock          │
          │  • Per-tool TTL            │
          │  • Index freshness check   │
          │  • v1→v2 migration logic   │
          └────────────────────────────┘
```

### 3.3. Cơ chế chính

#### 3.3.1. Detection + Lock Flow

```
Skill PRE-GATE:
  0. Short-circuit: if not git repo → skip all CI detection, use Grep/Glob
  1. mkdir -p .mc-data/work/_meta (create if not exists)
  2. Check cache freshness (per-tool TTL)
     ├── ALL FRESH → load & skip to freshness check
     └── ANY STALE or MISSING →
         Try acquire .ci-cache.lock
         ├── ACQUIRED:
         │   a. git remote get-url origin → match với gitnexus_list_repos()
         │   b. Gọi MCP tools detect GitNexus + Serena
         │   c. git rev-parse HEAD → index_commit
         │   d. Write cache (create dir if needed) → release lock
         └── NOT ACQUIRED (lock held by peer):
             a. Check lock staleness (>60s) → break + acquire
             b. If valid lock → exit 2 → fallback Grep/Glob (no regression)
  3. ci-freshness-check.sh: compare HEAD vs index_commit (skip if not git)
  4. Inject CI context vào agent prompts (kèm freshness warning nếu có)
```

#### 3.3.2. Per-Tool TTL

| Tool | TTL | Lý do |
|------|-----|-------|
| GitNexus `available=true` | 24h | Đã index, hiếm khi gỡ |
| GitNexus `available=false` | **4h** | User có thể cài GitNexus + chạy `gitnexus analyze` giữa phiên |
| Serena `available=true` | 24h | Đã onboard, ổn định |
| Serena `available=false` | **1h** | User có thể cài Serena bất cứ lúc nào |

Escape hatch: `MCV3_CI_RESCAN=1` cho user advanced. **Respects lock** — nếu lock bị giữ, env var không override lock.

#### 3.3.3. Index Freshness Check (mỗi PRE-GATE, không cache)

```
Short-circuit: if not git repo → skip
git rev-parse HEAD → so sánh với cache.index_commit → git rev-list --count
  0 commits behind  → OK
  1-5 behind        → WARNING nhẹ
  6-20 behind       → STRONG WARNING + gợi ý re-index
  >20 behind        → SEVERE + khuyến nghị re-index trước khi tiếp tục
  unknown           → Skip check (index_commit missing / not in history)
```

#### 3.3.4. Repo Disambiguation

```
Khi GitNexus available:
  1. git remote get-url origin → extract repo name
  2. gitnexus_list_repos() → tìm repo khớp với origin
  3. Nếu 1 match → dùng repo đó
  4. Nếu >1 match → ưu tiên exact name match → ưu tiên path match với CWD
  5. Nếu 0 match → GitNexus available=false (không có index cho repo này)
  Lưu repo name vào cache: gitnexus.repo
```

### 3.4. Task → Tool Routing Matrix

"CI-ROUTE" là convention: skill agent đọc routing matrix này từ Protocol 20 để chọn tool.

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
| `index_freshness` | **Git** `rev-parse HEAD` | — | Skip check |

### 3.5. Agent Context Injection (D5: injection-only, không sửa agent .md)

Khi skills spawn agents, context về available code intelligence tools được inject vào prompt. **Không sửa bất kỳ agent definition file nào.**

```
Agent prompt bổ sung (khi GitNexus available):
  "GitNexus is available on this project ({repo}, {symbols} symbols).
   Before editing any symbol, run gitnexus_impact({target, direction: "upstream"})
   to understand blast radius. Use gitnexus_query({query: "concept"}) for
   execution flow exploration."

Agent prompt bổ sung (khi Serena available):
  "Serena is available on this project.
   Use find_definition and find_references for precise symbol lookup.
   Use rename_symbol for safe refactoring instead of find-and-replace."

Khi index stale (N commits behind):
  "⚠ GitNexus index is {N} commits behind HEAD.
   Impact analysis and query results may be incomplete."
```

---

## 4. Roadmap (7 Sprints, ~16h)

| Sprint | Title | Effort | Priority | Dependencies |
|--------|-------|--------|----------|--------------|
| S1 | Protocol 20 + Detection + Lock + Repo Disambiguation | 4h | P0 | — |
| S2 | Per-tool TTL + Freshness Check + Agent Injection | 2.5h | P0 | S1 |
| S3 | wf-implement-feature Integration | 2.5h | P0 | S1+S2 |
| S4 | wf-fix-bugs + Sub-skills Integration | 2.5h | P0 | S1+S2 |
| S5 | wf-manage-change + wf-legacy-scan + wf-design Integration | 2h | P1 | S1+S2 |
| S6 | wf-verify-sync + wf-plan-modules Integration | 1h | P2 | S1+S2 |
| S7 | Documentation + Evals + E2E + Multi-Dev Test | 2h | P1 | All |

### 4.1. Critical path

```
S1 (Protocol + Detection + Lock + Repo) ──→ S2 (TTL + Freshness + Injection) ──┬──→ S3 (implement-feature) ──┐
                                                                                  ├──→ S4 (fix-bugs+subs)      ├──→ S7 (Docs+E2E+Multi-Dev)
                                                                                  ├──→ S5 (manage+scan+design) ──┘
                                                                                  └──→ S6 (verify+plan)
```

S1 là prerequisite cho tất cả. S2 là prerequisite cho S3-S6. S3-S6 có thể chạy song song sau S2.

### 4.2. Token savings estimate (post-integration)

| Operation | Before (Grep/Glob) | After (GitNexus/Serena) | Savings |
|-----------|-------------------|------------------------|---------|
| Find references | ~2000-4000 tokens (multi-file Grep) | ~500 tokens (single API call) | -75% |
| Impact analysis | Không làm được | ~800 tokens | New capability |
| Understand flow | ~5000-10000 tokens (Read + trace) | ~1000 tokens (query) | -80% |
| Find definition | ~1000-2000 tokens (Grep + Read) | ~300 tokens (Serena) | -70% |
| Safe rename | ~3000-6000 tokens (find-replace + verify) | ~500 tokens (rename_symbol) | -85% |
| Freshness check | Không có | ~0 tokens (bash) | New capability |

### 4.3. Token measurement methodology

Đo bằng cách so sánh context token count trước và sau integration:
1. Chọn 1 operation chuẩn (VD: "find all references to CreateOrder")
2. Chạy với Grep/Glob (baseline) → ghi nhận token count từ API response
3. Chạy với GitNexus/Serena → ghi nhận token count
4. Tính: `savings = (baseline - ci) / baseline * 100`
5. Lặp lại 3 lần, lấy trung bình

---

## 5. Risk Analysis

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| GitNexus index stale | **High** (mỗi lần code/git pull) | **High** (impact analysis thiếu) | Index freshness check mỗi PRE-GATE (D9) |
| Race condition multi-session | Medium (cần timing) | High (cache corrupt) | Lock file + graceful fallback (D8); lock timeout 60s |
| User cài tool mới giữa phiên | Medium (Serena: High, GitNexus: Medium) | Medium (bỏ lỡ tool) | Per-tool TTL: Serena-absent 1h, GitNexus-absent 4h (D3) |
| GitNexus index quá cũ | Medium | Medium | Auto-detect staleness; suggest re-index (1 dòng, không block) |
| Serena LSP crash | Low | Medium | Graceful degrade về GitNexus hoặc Grep |
| Token cost of detection | Low | Low | Cache per-tool TTL; detection script là bash (không token) |
| User project không có GitNexus/Serena | High | None | Graceful degradation — hành vi y hệt hiện tại |
| Protocol quá phức tạp, agent không tuân thủ | Medium | Medium | Protocol viết ngắn gọn; inject context trực tiếp vào agent prompt |
| Conflict giữa GitNexus và Serena results | Low | Low | Serena ưu tiên cho precision tasks; GitNexus cho graph tasks |
| Multi-dev: 2 người cùng chạy skill trên cùng máy | Low | Low | Lock phân biệt PID+user; fallback nếu lock bị giữ |
| Query nhầm GitNexus repo | Medium (máy có nhiều repo indexed) | High (kết quả sai/rỗng) | Repo disambiguation qua `git remote get-url origin` |
| `bc` unavailable trên Windows | **High** (Git Bash không có `bc`) | Medium (script fail) | Pure bash integer arithmetic (seconds-based TTL) |
| Cache schema v1→v2 migration | Medium (cache cũ từ session trước) | Low (mất cache, re-scan) | Migration logic trong ci-detect.sh: detect v1 → re-scan |
| Non-git project chạy freshness check | Medium | Low (git error noise) | Short-circuit: `git rev-parse` fail → skip all git-based checks |

---

## 6. Definition of Done (Project-level)

- [ ] **Protocol 20:** `protocols/20-code-intelligence.md` created — detect, lock, route, degrade, freshness, multi-dev, repo disambiguation
- [ ] **Detection script:** `scripts/ci-detect.sh` — lock acquire/release + repo disambiguation + per-tool TTL (pure bash, no `bc`) + v1→v2 migration + `mkdir -p`
- [ ] **Freshness script:** `scripts/ci-freshness-check.sh` — HEAD vs index_commit → warning levels; short-circuit non-git
- [ ] **Injection script:** `scripts/ci-inject-context.sh` — 3 templates + freshness warning
- [ ] **Cache layer:** `.mc-data/work/_meta/code-intelligence.json` produced with per-tool TTL + index_commit + repo
- [ ] **Lock mechanism:** `.mc-data/work/_meta/.ci-cache.lock` with PID+host+heartbeat, stale detection 60s
- [ ] **Agent injection:** Agent spawn instructions include CI context + freshness warning (D5: injection-only, không sửa agent .md)
- [ ] **wf-implement-feature:** Phase 0.7 Safety Gate (`phase0-7-safety-gate.md`) + Phase 3 TDD (`phase3-tdd.md`) dùng CI tools + freshness check
- [ ] **wf-fix-bugs orchestrator:** PRE-GATE freshness check
- [ ] **wf-fix-triage (sub-skill):** Phase 2 dùng GitNexus query cho bug investigation + freshness check
- [ ] **wf-fix-execute (sub-skill):** Phase 3 dùng GitNexus impact trước khi fix + freshness check
- [ ] **wf-manage-change:** Phase 2 Impact (`phase2-impact.md`) dùng GitNexus impact + freshness check
- [ ] **wf-legacy-scan:** Stage 1-3 dùng GitNexus query + Serena symbols + freshness check
- [ ] **wf-design:** Phase 0 (`phase0-context.md`) dùng GitNexus processes + route_map + freshness check
- [ ] **wf-verify-sync:** Phase 1-2 (`phase1-scan.md`, `phase2-analyze.md`) dùng GitNexus cypher + Serena find_refs + freshness check
- [ ] **wf-plan-modules:** Phase 2 (`phase2-deps.md`) dùng GitNexus clusters + Serena overview + freshness check
- [ ] **Graceful degradation:** Tất cả 7 skills + 2 sub-skills hoạt động bình thường khi không có GitNexus/Serena
- [ ] **Lock graceful fallback:** Lock bị giữ → fallback Grep (không block, không regression)
- [ ] **User prompt = 0:** Không hỏi người dùng về GitNexus/Serena. Escape hatch: `MCV3_CI_RESCAN=1` (respects lock)
- [ ] **Compliance:** `skill-compliance-audit.sh` PASS cho tất cả modified skills
- [ ] **E2E test:** Chạy trên EUREKA-2026 (có cả hai tools) + một dự án không có tools
- [ ] **Multi-dev test:** 2 terminal song song (cùng skill + khác skill) — verify lock + no corrupt
- [ ] **Index stale test:** git pull → verify freshness warning xuất hiện, không block
- [ ] **Non-git project test:** Verify short-circuit hoạt động, không error
- [ ] **Token measurement:** Code exploration token giảm ≥30% (methodology: §4.3)
- [ ] **CHANGELOG:** Entry trong mỗi modified SKILL.md
- [ ] **00-core.md:** Updated §4b với new cross-skill paths (nếu có)
- [ ] **_contract.json:** Updated cho mỗi modified skill (thêm `code_intelligence.integration = true`)
- [ ] **All 17 findings addressed** (4 P0, 8 P1, 4 P2, 1 P3)

---

## 7. Files Changed Summary

| Loại | Files |
|------|-------|
| **CREATED** | `protocols/20-code-intelligence.md`, `scripts/ci-detect.sh`, `scripts/ci-freshness-check.sh`, `scripts/ci-inject-context.sh`, `skills/templates/code-intelligence.schema.json` |
| **MODIFIED** | 9 SKILL.md files (implement-feature, fix-bugs, fix-triage, fix-execute, manage-change, legacy-scan, design, verify-sync, plan-modules), 9 procedure files, `protocols/README.md`, `CLAUDE.md` |
| **REFERENCED (injection only)** | 0 agent definition files modified (D5: injection-only). Context templates trong `ci-inject-context.sh` |

### 7.1. Procedure files actually modified (mapped to reality)

| Skill | Actual procedure file | Change |
|-------|----------------------|--------|
| wf-implement-feature | `procedures/phase0-7-safety-gate.md` | CI-ROUTE find_existing_code (F1) |
| wf-implement-feature | `procedures/phase3-tdd.md` | Pre-edit impact analysis (F2) |
| wf-fix-triage | `procedures/phase2-triage.md` | gitnexus_query cho bug investigation (F8) |
| wf-fix-execute | `procedures/phase3-batch1.md` (cùng pattern cho batch2/batch3) | Pre-fix impact analysis + post-fix detect_changes (F2) |
| wf-manage-change | `procedures/phase2-impact.md` | Automated impact via GitNexus (F9) |
| wf-legacy-scan | `procedures/phase1-inventory.md` | Serena onboarding + GitNexus clusters (F10) |
| wf-legacy-scan | `procedures/phase3-extract.md` | GitNexus cypher REQ-ID search (F10) |
| wf-design | `procedures/phase0-context.md` | GitNexus route_map + processes (F11) |
| wf-verify-sync | — (SKILL.md flow-level only) | CI-ROUTE annotations trong SKILL.md flow Phase 2+3 (F12). Procedure files không cần modify — đây là skill session-based (v4.0.0), CI logic nằm ở flow-level instructions. |

---

## 8. Sprint Details

Xem các file sprint riêng:

| Sprint | File |
|--------|------|
| S1 | [`sprints/S1-protocol-and-detection.md`](./sprints/S1-protocol-and-detection.md) |
| S2 | [`sprints/S2-cache-and-injection.md`](./sprints/S2-cache-and-injection.md) |
| S3 | [`sprints/S3-wf-implement-feature.md`](./sprints/S3-wf-implement-feature.md) |
| S4 | [`sprints/S4-wf-fix-bugs.md`](./sprints/S4-wf-fix-bugs.md) |
| S5 | [`sprints/S5-p1-skills.md`](./sprints/S5-p1-skills.md) |
| S6 | [`sprints/S6-p2-skills.md`](./sprints/S6-p2-skills.md) |
| S7 | [`sprints/S7-docs-evals-e2e.md`](./sprints/S7-docs-evals-e2e.md) |
