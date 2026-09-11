# Findings — Code Intelligence Integration

> **Audit date:** 2026-05-06 (revised 2026-05-06 — v0.3 codebase reconciliation)
> **Reviewer:** Claude Opus 4.7
> **Scope:** Toàn bộ MCV3 workflow skills (28 `wf-*`) + 62 agent definitions + hiện trạng GitNexus/Serena + concurrency safety + multi-developer scenarios
> **Methodology:** Deep-read CLAUDE.md, GitNexus skills (6 files), Serena source code (tools/), workflow skill structure, agent definitions, actual procedure files on disk, peer review: parallel session execution, team git workflows

---

## Severity Legend

- **P0** — Critical. Skills modify code without impact analysis; CORE-020 Safety Gate dùng Grep thô sơ → false negatives.
- **P1** — High. Missing capability that significantly improves quality hoặc token efficiency.
- **P2** — Medium. Enhancement opportunity, không ảnh hưởng correctness.
- **P3** — Low. Nice-to-have, tương lai.

---

## Section A: Kiến trúc & Integration Gaps

### F1 (P0) — CORE-020 Safety Gate chỉ dùng Grep/Glob

**Evidence:** Tất cả `wf-implement-feature` procedure files không tham chiếu GitNexus hoặc Serena. Phase 0.7 Safety Gate (`phase0-7-safety-gate.md`) dùng `grep` + `glob` để tìm code hiện tại.

**Impact:** Trên codebase 169K symbols như EUREKA-2026, Grep pattern search cho ra nhiều false positives VÀ false negatives. False negative → duplicate implementation. False positive → user bị hỏi không cần thiết.

**Root cause:** Khi CORE-020 được thiết kế, GitNexus chưa được tích hợp vào MCV3.

**Desired state:** Safety Gate dùng `gitnexus_impact()` + `gitnexus_context()` cho precision, fallback về Grep khi GitNexus không available.

---

### F2 (P0) — Không có impact analysis trước khi sửa code

**Evidence:**
- `wf-fix-execute` Phase 3: sửa code trực tiếp, không có bước impact analysis
- `wf-manage-change` Phase 2: có `impact_analysis` section trong template nhưng thực hiện thủ công (Grep)
- `wf-implement-feature` Phase 3 (`phase3-tdd.md`): MODIFY scenario không tự động impact analysis

**Impact:** Sửa code mà không biết blast radius → nguy cơ break production cao, đặc biệt trên codebase lớn.

**Desired state:** Mọi code change đều có `gitnexus_impact()` trước khi sửa (khi GitNexus available).

---

### F3 (P0) — GitNexus standalone skills không connected vào workflow

**Evidence:**
- `.claude/skills/gitnexus/` có 6 skill standalone: exploring, impact-analysis, debugging, refactoring, cli, guide
- Không skill `wf-*` nào reference các GitNexus skill này
- Người dùng phải biết về GitNexus và gọi thủ công `/gitnexus-impact-analysis`

**Impact:** Người dùng không chuyên không biết GitNexus tồn tại → không dùng.

**Desired state:** Workflow skills tự động dùng GitNexus, không cần user gọi standalone skill.

---

### F4 (P1) — Agent definitions không biết GitNexus/Serena

**Evidence:**
- 62 agent files trong `.claude/agents/` — grep `gitnexus` = 0 matches
- Agents như `developer`, `architect`, `security` chuyên sửa code nhưng không dùng GitNexus impact analysis
- Agent `Explore` dùng Grep/Glob thay vì `gitnexus_query()`

**Impact:** Agents là đơn vị thực thi chính của skills. Nếu agents không biết dùng GitNexus/Serena, skills không thể tận dụng dù có protocol.

**Desired state:** Agent context được inject CI instructions qua prompt khi spawn (D5: injection-only, không sửa agent .md files). Context injection đảm bảo agents biết dùng GitNexus/Serena mà không cần modify 62 files.

---

### F5 (P1) — Không có cơ chế auto-detect code intelligence tools

**Evidence:** Không file nào trong `.claude/` check GitNexus hoặc Serena availability trên target project.

**Impact:** Mỗi skill phải tự quyết định có nên dùng GitNexus không → inconsistency. Người dùng không chuyên không thể cấu hình.

**Desired state:** Shared detection script (`ci-detect.sh`) được gọi từ PRE-GATE của mọi skill, cache kết quả vào `.mc-data/work/_meta/code-intelligence.json`.

---

### F6 (P1) — Serena có sẵn nhưng MCV3 không tận dụng

**Evidence:**
- Serena cung cấp: `find_definition`, `find_references`, `rename_symbol`, `get_symbols_overview`, `move_symbol`, `onboarding`, `check_onboarding_performed`
- Không skill `wf-*` nào reference Serena tools
- Serena dùng LSP → kết quả chính xác hơn Grep cho symbol-level operations

**Impact:** Bỏ phí cơ hội refactoring an toàn (Serena rename_symbol) và tìm kiếm chính xác (Serena find_references).

**Desired state:** Skills dùng Serena cho precision tasks (find_def, find_refs, rename), GitNexus cho graph tasks (impact, flow).

---

## Section B: Skill-Specific Gaps

### F7 (P1) — wf-implement-feature: MODIFY scenario thiếu automated impact

**Evidence:** `phase0-7-safety-gate.md` — safety gate checks existing code nhưng không có automated impact analysis cho MODIFY.

**Desired state:** Khi GitNexus available, tự động chạy `gitnexus_impact()` cho mọi MODIFY scenario.

---

### F8 (P1) — wf-fix-bugs: bug investigation không dùng GitNexus query

**Evidence:** `wf-fix-triage` Phase 2 dùng Grep/Glob để tìm code liên quan đến bug.

**Impact:** Với bug phức tạp, Grep không đủ để hiểu execution flow. `gitnexus_query()` cho ra execution chain hoàn chỉnh.

**Desired state:** wf-fix-triage dùng `gitnexus_query({query: bug_description})` để tìm execution flows liên quan.

---

### F9 (P1) — wf-manage-change: Impact phase thủ công

**Evidence:** `phase2-impact.md` là manual process — agent đọc code và trace dependencies bằng tay.

**Impact:** Chậm + dễ bỏ sót trên codebase lớn.

**Desired state:** `gitnexus_impact()` tự động map blast radius của change.

---

### F10 (P2) — wf-legacy-scan: Code exploration dùng Glob/Grep thô

**Evidence:** Stage 1-3 dùng Glob để tìm file, Grep để tìm patterns. Token cost cao, kết quả thiếu structure.

**Desired state:** `gitnexus_query()` cho execution flows, Serena `get_symbols_overview` cho file structure.

---

### F11 (P2) — wf-design: Kiến trúc hiện tại phải đọc thủ công

**Evidence:** `phase0-context.md` yêu cầu agent đọc từng file để hiểu kiến trúc.

**Desired state:** `gitnexus://repo/{name}/processes` cho execution flows, `gitnexus_route_map()` cho API structure.

---

### F12 (P2) — wf-verify-sync: REQ-ID tracking chỉ dùng Grep

**Evidence:** `phase1-scan.md` dùng Grep để tìm REQ-ID annotations trong code.

**Desired state:** Kết hợp GitNexus cypher query (tìm tất cả references đến REQ-ID) + Serena find_references.

---

### F13 (P3) — wf-plan-modules: Dependency analysis thủ công

**Evidence:** `phase2-deps.md` dùng manual analysis để xác định dependency order.

**Desired state:** `gitnexus_impact()` hoặc cypher query để tự động map dependency graph.

---

## Section C: Token Efficiency

### F14 (P2) — Code exploration token cost quá cao

**Evidence:** Một lần Grep + Read để hiểu code flow tốn ~5000-10000 tokens. `gitnexus_query()` cho kết quả tương đương với ~1000 tokens.

**Desired state:** Ưu tiên GitNexus/Serena cho code exploration, chỉ fallback về Grep khi không available.

---

## Section D: Multi-Session & Team Gaps (phát hiện từ peer review)

> **Phát hiện ngày:** 2026-05-06 — từ phân tích các scenario người dùng thực tế chạy nhiều skill song song + team đa developer.

### F15 (P0) — Race condition khi nhiều phiên skill cùng write cache

**Evidence:** Plan thiết kế 1 file cache toàn cục `.mc-data/work/_meta/code-intelligence.json` dùng chung cho tất cả skills. Khi cache miss/stale, mỗi skill tự gọi MCP tools để detect rồi ghi đè file. Không có lock mechanism.

**Scenario thực tế:**
```
Terminal 1: /wf-implement-feature Checkout   (Session A)
Terminal 2: /wf-implement-feature Payment    (Session B)
Terminal 3: /wf-fix-bugs "order total bug"   (Session C)
```
3 phiên cùng PRE-GATE → cùng cache miss → cùng gọi MCP tools → cùng write `code-intelligence.json`. N-way race condition.

**Impact:**
- Cache corrupt → JSON không parse được → tất cả phiên fallback về Grep/Glob (mất toàn bộ CI capability)
- Xác suất tăng theo số phiên song song
- Đặc biệt tệ khi mỗi phiên spawn nhiều agents — mỗi agent có thể trigger detection

**Root cause:** Plan không áp dụng pattern lock file (PID + host + heartbeat + stale detection) đã proven trong MCV3 (wf-fix-bugs, wf-manage-change, wf-add-scope).

**Desired state:**
1. Lock file `.mc-data/work/_meta/.ci-cache.lock` bảo vệ write
2. Nếu lock bị giữ → skill KHÔNG chờ, fallback ngay về Grep/Glob (không regression — đây là hành vi hiện tại)
3. Lock stale detection: 60 giây → tự break + acquire
4. Skill đến sau (sau khi lock release) đọc cache đã được session đầu ghi → dùng CI tools bình thường

---

### F16 (P1) — GitNexus index stale sau mỗi lần git pull (multi-developer)

**Evidence:** Plan chỉ kiểm tra tool availability (có GitNexus không?), không kiểm tra index có phản ánh đúng code HEAD hiện tại không. Sau mỗi lần `git pull`, GitNexus index trở nên stale ngay lập tức.

**Scenario thực tế:**
```
09:00 Dev A: commit + push OrderService.cs (commit abc123)
09:05 Dev B: git pull → HEAD = abc123
           Index của Dev B: def456 (cũ, không có code của Dev A)
09:06 Dev B: /wf-implement-feature Payment → MODIFY OrderService
           gitnexus_impact("OrderService") → trả về callers CŨ, thiếu code Dev A vừa viết
           → Dev B sửa code, không biết mình đang đụng vào code mới
```

**Impact:**
- Team environment: index stale mỗi khi **bất kỳ ai push** — không kiểm soát được tần suất  
- Impact analysis thiếu → break code đồng nghiệp vừa viết  
- Tệ hơn không có CI tools: user tin vào kết quả nhưng kết quả không đầy đủ

**Root cause:** Plan gộp chung 2 khái niệm khác nhau: "tool có được cài không" và "dữ liệu có mới không" vào cùng 1 cache.

**Desired state:**
1. Thêm `index_commit` vào cache file (commit mà GitNexus index dựa trên)
2. Mỗi PRE-GATE: `git rev-parse HEAD` → so sánh với `index_commit` → `git rev-list --count`
3. Cảnh báo theo mức: 0=OK, 1-5=WARNING nhẹ, 6-20=WARNING rõ, >20=CẢNH BÁO MẠNH + gợi ý re-index
4. Index freshness check KHÔNG cache, chạy mỗi lần PRE-GATE (chỉ `git rev-parse HEAD`, <0.01s)
5. Short-circuit: nếu không phải git repo → skip check

---

### F17 (P1) — Tool availability TTL không phân biệt ngữ cảnh cài đặt

**Evidence:** Plan dùng TTL 24h thống nhất cho cả GitNexus lẫn Serena. Nhưng:

- **GitNexus:** cài 1 lần, dùng mãi. Nếu chưa cài → khả năng user cài giữa phiên thấp nhưng không phải zero (user có thể chạy `gitnexus analyze` bất cứ lúc nào).
- **Serena:** user có thể cài MCP server bất cứ lúc nào. Nếu `available=false`, cần check lại sớm hơn để không bỏ lỡ.
- **Serena đã onboard:** ổn định, ít thay đổi.

**Scenario thực tế:**
```
08:00 Session A: detect → cache (Serena=false, TTL 24h)
10:00 User: cài Serena MCP server
10:05 Session B: cache fresh (Serena=false) → MISS Serena → dùng Grep thay vì find_references
```
User vừa cài Serena chính vì muốn skill dùng nó, nhưng cache 24h khiến tất cả phiên bỏ lỡ cả ngày.

**Desired state:**
- **Per-tool TTL:** Mỗi tool có TTL riêng
  - GitNexus `available=true`: 24h (hiếm khi gỡ cài)
  - GitNexus `available=false`: **4h** (user có thể cài GitNexus + index giữa phiên)
  - Serena `available=true`: 24h (đã onboard thì ổn định)
  - Serena `available=false`: **1h** (user có thể cài bất cứ lúc nào)
- Escape hatch: `MCV3_CI_RESCAN=1` cho user muốn force re-scan ngay. **Respects lock** — nếu lock bị giữ, env var không override.

---

## Section E: Plan-Level Findings (phát hiện từ codebase reconciliation v0.3)

> **Phát hiện ngày:** 2026-05-06 — từ deep-dive review plan vs thực tế codebase MCV3.

### F18 (P0-PLAN) — Procedure file names trong plan không khớp thực tế

**Evidence:**
- Plan S3: `phase3-implementation.md` → actual: `phase3-tdd.md`
- Plan S4: `phase1-isg.md` → **không tồn tại** (wf-fix-bugs là orchestrator, không có phase-based procedures)
- Plan S4: `phase3-fix.md` → **không tồn tại**
- Plan S3: Safety Gate trong `phase0-existing-analysis.md` → actual: `phase0-7-safety-gate.md`

**Impact:** Plan không thể triển khai như viết — developer sẽ tìm file không thấy.

**Desired state:** Tất cả procedure file references khớp với thực tế codebase.

---

### F19 (P0-PLAN) — wf-fix-bugs architecture bị hiểu sai

**Evidence:** Plan S4 coi wf-fix-bugs là direct-execution skill với phase1-isg + phase3-fix. Thực tế wf-fix-bugs (v7.1.0) là **pure orchestrator** delegate cho wf-fix-triage + wf-fix-execute. Procedure files của nó là operational (lock-management, bash-delegation, agent-dispatch...), không phải phase-based.

**Impact:** Toàn bộ S4 phải viết lại để target đúng sub-skills.

**Desired state:** CI integration trong:
- `wf-fix-bugs` orchestrator: PRE-GATE freshness check
- `wf-fix-triage`: Phase 2 dùng `gitnexus_query()` cho bug investigation
- `wf-fix-execute`: Phase 3 dùng `gitnexus_impact()` trước khi fix

---

### F20 (P1-PLAN) — D5 injection-only mâu thuẫn với §2.3 agent file modifications

**Evidence:** D5 nói "context injection qua agent prompt (**không sửa agent .md**)" nhưng `02-architecture-design.md` §2.3 liệt kê 4 agent files cần modify: developer.md, architect.md, security.md, code-reviewer.md.

**Impact:** Hai approach loại trừ lẫn nhau. Nếu sửa agent files → 62 files phải check. Nếu injection-only → không cần sửa.

**Desired state:** D5 wins — injection-only. Xóa §2.3 agent file modifications khỏi architecture design.

---

### F21 (P1-PLAN) — `bc` không có trên Windows Git Bash

**Evidence:** `ci-detect.sh` dùng `bc -l` cho float comparison TTL. `bc` không included trong Git Bash for Windows.

**Impact:** Script fail trên Windows → CI detection không hoạt động.

**Desired state:** Pure bash integer arithmetic — convert TTL hours sang seconds, dùng integer comparison.

---

### F22 (P1-PLAN) — Không có GitNexus repo disambiguation

**Evidence:** MCV3 cũng được GitNexus index (5030 symbols). Trên máy có nhiều repo, `gitnexus_list_repos()` trả về nhiều repos. Plan không có cơ chế chọn đúng repo cho target project.

**Impact:** Skill query nhầm GitNexus repo → kết quả sai hoặc rỗng.

**Desired state:** `git remote get-url origin` → match với available repos → ghi `gitnexus.repo` vào cache.

---

### F23 (P2-PLAN) — `ci-route.sh` trong architecture diagram nhưng không sprint nào tạo

**Evidence:** Architecture diagram §1 có `ci-route.sh` là core component, nhưng không sprint nào tạo file này. Sprint files dùng "CI-ROUTE" như một concept không được định nghĩa.

**Impact:** Developer không biết CI-ROUTE là script hay convention.

**Desired state:** CI-ROUTE là **convention trong Protocol 20** (không phải script riêng). Xóa `ci-route.sh` khỏi architecture diagram.

---

### F24 (P2-PLAN) — `.mc-data/work/_meta/` không tồn tại, scripts không có `mkdir -p`

**Evidence:** Scripts ghi vào `.mc-data/work/_meta/` nhưng directory này không tồn tại. Không có `mkdir -p` logic.

**Impact:** Script fail ở lần chạy đầu tiên.

**Desired state:** Tất cả scripts có `mkdir -p` trước khi ghi file.

---

### F25 (P2-PLAN) — Template path sai convention

**Evidence:** Plan tạo `protocols/templates/code-intelligence.schema.json`. Convention hiện tại: templates ở `.claude/skills/templates/` (được protocols/README.md reference là `../templates/`).

**Impact:** Inconsistency với cấu trúc hiện tại.

**Desired state:** Schema đặt ở `.claude/skills/templates/code-intelligence.schema.json`.

---

### F26 (P2-PLAN) — Không có cache schema migration v1→v2

**Evidence:** Cache v2 thêm `checked_at` + `ttl_hours` + `index_commit`. Nếu cache v1 tồn tại từ session trước, schema cũ không có fields này → `jq` queries fail.

**Impact:** Cache cũ → parse error → fallback Grep (mất CI capability).

**Desired state:** `ci-detect.sh` detect schema version → nếu v1 → force re-scan.

---

## Summary

| ID | Severity | Area | Description |
|----|----------|------|-------------|
| F1 | P0 | Architecture | CORE-020 Safety Gate chỉ dùng Grep/Glob |
| F2 | P0 | Architecture | Không có impact analysis trước khi sửa code |
| F3 | P0 | Integration | GitNexus standalone skills không connected vào workflow |
| **F15** | **P0** | **Concurrency** | **Race condition khi nhiều phiên cùng write cache (không lock)** |
| **F18** | **P0-PLAN** | **Plan Accuracy** | **Procedure file names trong plan không khớp thực tế** |
| **F19** | **P0-PLAN** | **Plan Accuracy** | **wf-fix-bugs architecture bị hiểu sai (orchestrator, không direct)** |
| F4 | P1 | Agents | Agent definitions không biết GitNexus/Serena |
| F5 | P1 | Architecture | Không có cơ chế auto-detect |
| F6 | P1 | Integration | Serena available nhưng không được dùng |
| F7 | P1 | wf-implement-feature | MODIFY scenario thiếu automated impact |
| F8 | P1 | wf-fix-bugs | Bug investigation không dùng GitNexus query |
| F9 | P1 | wf-manage-change | Impact phase thủ công |
| **F16** | **P1** | **Multi-Dev** | **Index stale sau git pull — không có freshness check** |
| **F17** | **P1** | **Detection** | **Per-tool TTL không phân biệt — bỏ lỡ tool mới cài giữa phiên** |
| **F20** | **P1-PLAN** | **Design** | **D5 injection-only mâu thuẫn với §2.3 agent file modifications** |
| **F21** | **P1-PLAN** | **Compat** | **`bc` không có trên Windows Git Bash** |
| **F22** | **P1-PLAN** | **Architecture** | **Không có GitNexus repo disambiguation** |
| F10 | P2 | wf-legacy-scan | Code exploration dùng Glob/Grep thô |
| F11 | P2 | wf-design | Kiến trúc hiện tại phải đọc thủ công |
| F12 | P2 | wf-verify-sync | REQ-ID tracking chỉ dùng Grep |
| F14 | P2 | Token Efficiency | Code exploration token cost cao |
| **F23** | **P2-PLAN** | **Architecture** | **`ci-route.sh` trong diagram nhưng không được tạo** |
| **F24** | **P2-PLAN** | **Robustness** | **`.mc-data/work/_meta/` không tồn tại, thiếu `mkdir -p`** |
| **F25** | **P2-PLAN** | **Convention** | **Template path sai convention (protocols/templates/ → skills/templates/)** |
| **F26** | **P2-PLAN** | **Migration** | **Không có cache schema migration v1→v2** |
| F13 | P3 | wf-plan-modules | Dependency analysis thủ công |

**Tổng: 6 P0 (4 code + 2 plan), 11 P1 (8 code + 3 plan), 8 P2 (4 code + 4 plan), 1 P3 = 26 findings**
