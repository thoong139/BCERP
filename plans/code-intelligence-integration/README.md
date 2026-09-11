# Plan: Code Intelligence Integration — GitNexus + Serena

> **Trạng thái:** DRAFT v0.3 (2026-05-06) — Chờ user review & approve để bắt đầu Sprint 1.
> **Trigger:** Người dùng cài GitNexus + Serena trên dự án EUREKA-2026. MCV3 workflow skills không tận dụng được hai công cụ code intelligence này.
> **Base version:** MCV3 current (2026-05-06)
> **Revision v0.3:** Codebase reconciliation — 9 plan-level findings (F18-F26) found + fixed. 17 → 26 findings. Procedure file names corrected. wf-fix-bugs architecture (orchestrator) respected. D5 injection-only confirmed. `bc`→integer arithmetic. CI-ROUTE as convention. Repo disambiguation added. Cache migration v1→v2. Lock timeout 60s.

## Cấu trúc tài liệu

| File | Trạng thái | Mục đích |
|------|------------|----------|
| [`00-master-plan.md`](./00-master-plan.md) | DRAFT v0.3 | Tổng quan: vấn đề, mục tiêu, roadmap 7 sprints, DoD |
| [`01-findings.md`](./01-findings.md) | DRAFT v0.3 | 26 findings chi tiết (6 P0, 11 P1, 8 P2, 1 P3) |
| [`02-architecture-design.md`](./02-architecture-design.md) | DRAFT v0.3 | 12 design decisions + lock/freshness/multi-dev/migration mechanisms |
| [`progress.md`](./progress.md) | ACTIVE | Tracking tiến độ triển khai (cập nhật sau mỗi sprint) |
| [`_next-session-prompt.md`](./_next-session-prompt.md) | ACTIVE | Prompt cho phiên làm việc tiếp theo |

## Tóm tắt vấn đề

MCV3 có 28 workflow skills và 62 agents. Tất cả dùng **Grep/Glob/Read** làm công cụ khám phá code. Trong khi đó:

1. **GitNexus** đã có 6 standalone skill nhưng không được tích hợp vào workflow chính
2. **Serena** mới được cài, cung cấp LSP-based semantic tools, nhưng MCV3 không biết đến nó
3. **EUREKA-2026** đã được index GitNexus (169K symbols, 300 execution flows) nhưng skills không tận dụng
4. **Người dùng không chuyên** không biết GitNexus/Serena là gì, không thể tự cấu hình
5. **Nhiều phiên song song** không có lock → race condition ghi cache → corrupt
6. **Multi-developer** git pull → index stale → impact analysis thiếu code đồng nghiệp

## Mục tiêu

| Metric | Hiện tại | Target |
|--------|----------|--------|
| Skills aware of code intelligence | 0/28 | 7/28 P0+P1 skills |
| Auto-detection | Không có | Tự động, per-tool TTL |
| Impact analysis before edits | Không có | Bắt buộc với GitNexus |
| Semantic refactoring | Find-and-replace | Serena rename khi available |
| Token efficiency (code exploration) | 100% inline Grep/Glob | -30% to -60% với CI tools |
| User prompts about tools | N/A | 0 (tự động) |
| Concurrency safety | Không có | Lock-protected cache write (60s stale) |
| Index freshness awareness | Không có | Check mỗi PRE-GATE (<0.01s) |

## Kiến trúc

```
MCV3 Skills → PRE-GATE: detection (lock) + freshness check
                   ↓
           Protocol 20 (Code Intelligence)
           CI-ROUTE convention (routing matrix)
                   ↓
       GitNexus / Serena / Grep
       (Graph)    (LSP)    (Fallback)
                   ↓
       Cache: code-intelligence.json (v2) + .ci-cache.lock
```

- **Protocol 20** định nghĩa detect → lock → freshness → route (CI-ROUTE) → degrade
- **ci-detect.sh** quản lý lock acquire/release + per-tool TTL + cache write + repo disambiguation + v1→v2 migration
- **ci-freshness-check.sh** so sánh HEAD vs index_commit mỗi PRE-GATE (git short-circuit)
- **ci-inject-context.sh** bơm CI context + freshness warning vào agent prompt (4 templates)
- **Graceful degradation** 3 tầng + lock fallback (không block, không regression)

## 12 Design Decisions

| ID | Decision | Key point |
|----|----------|-----------|
| D1 | Protocol-first | Single source of truth cho mọi skill |
| D2 | Bash scripts | Cache management + git ops, detection handoff protocol (bash exit codes → skill actions) |
| D3 | Per-tool TTL | GitNexus-present 24h, GitNexus-absent 4h, Serena-present 24h, Serena-absent 1h |
| D4 | Serena precision, GitNexus graph | Symbol-level → Serena, System-level → GitNexus |
| D5 | Agent context injection | Injection-only, KHÔNG sửa 62 agent .md files (F20 resolved) |
| D6 | Graceful degradation 3 tầng | Primary → Secondary → Grep/Glob |
| D7 | Zero-prompt design | System tự quyết định, escape hatch: `MCV3_CI_RESCAN=1` |
| D8 | Lock-first cache write | Lock file 60s stale timeout, lock held → fallback Grep (no regression) |
| D9 | Index freshness check | Mỗi PRE-GATE, 4 mức cảnh báo, không cache, git short-circuit |
| D10 | Multi-dev awareness | Freshness check bắt buộc trong team environment |
| D11 | Repo disambiguation | git remote get-url origin → match GitNexus repos → ghi `gitnexus.repo` |
| D12 | Cache schema migration | Auto-detect v1→v2 qua `schema_version` field, force re-scan |

## Roadmap (7 Sprints, ~15h)

```
S1 (3.5h)  Protocol 20 + Detection Script + Lock (60s) + Repo Disambig
    ↓
S2 (2.5h)  Per-tool TTL + Freshness Check + Agent Injection (4 templates)
    ↓
 ┌── S3 (2h) wf-implement-feature (phase0-7-safety-gate.md + phase3-tdd.md)
 ├── S4 (2h) wf-fix-bugs family (orchestrator + triage + execute)
 ├── S5 (2h) wf-manage-change + wf-legacy-scan + wf-design
 └── S6 (1h) wf-verify-sync + wf-plan-modules
    ↓
S7 (2h)  Documentation + Evals (≥20) + E2E + Multi-Dev Test (5 scenarios)
```

## Phạm vi thay đổi

- **12 files CREATED:** Protocol 20, 3 bash scripts (ci-detect, ci-freshness-check, ci-inject-context), 1 schema, 7 sprint files
- **17 files MODIFIED:** 9 SKILL.md (implement-feature, fix-bugs, fix-triage, fix-execute, manage-change, legacy-scan, design, verify-sync, plan-modules), 9 procedure files (phase0-7-safety-gate.md, phase3-tdd.md, phase2-triage.md, phase3-batch1.md, phase2-impact.md, phase1-inventory.md, phase3-extract.md, phase0-context.md, phase2-deps.md), CLAUDE.md, protocols/README.md, 7 _contract.json (wf-implement-feature, wf-fix-bugs, wf-fix-triage, wf-fix-execute, wf-manage-change, wf-legacy-scan, wf-design, wf-verify-sync, wf-plan-modules)
- **Skills impacted:** 9 workflow skills + 2 sub-skills (additive changes, không breaking)
- **Dependencies:** jq (đã có), git (đã có), GitNexus MCP (optional), Serena MCP (optional)
- **Compatibility:** Windows Git Bash (no bc, no pipefail), WSL, pure bash integer arithmetic

## Cách review

1. Đọc theo thứ tự:
   - `00-master-plan.md` — overview + roadmap (revised v0.3)
   - `01-findings.md` — 26 findings chi tiết (6 P0, 11 P1, 8 P2, 1 P3)
   - `02-architecture-design.md` — 12 design decisions + mechanisms
2. Phản hồi:
   - Lock mechanism (60s stale) + graceful fallback đã hợp lý chưa?
   - Per-tool TTL values (GitNexus-absent=4h, Serena-absent=1h) có cần điều chỉnh?
   - Freshness check 4 mức cảnh báo + git short-circuit đã phù hợp?
   - Multi-dev scenarios còn thiếu trường hợp nào?
   - Repo disambiguation (git remote → match) đã đủ chưa?
   - Cache migration v1→v2 approach có ổn không?
3. Sau approve → bắt đầu **Sprint 1 (Protocol 20 + Detection + Lock)** — 3.5h estimate.

## Definition of Done (toàn dự án)

- [ ] Protocol 20 created + referenced (9 sections, lock 60s + per-tool TTL + freshness + CI-ROUTE convention)
- [ ] ci-detect.sh hoạt động với lock acquire/release + per-tool TTL + repo disambiguation + v1→v2 migration (Git Bash + WSL)
- [ ] ci-freshness-check.sh hoạt động — 4 mức cảnh báo + git short-circuit
- [ ] ci-inject-context.sh hoạt động — 4 templates (Both-OK, Both-Stale, GitNexus-only, Serena-only) + freshness warning
- [ ] Cache file schema v2 defined + validated (per-tool checked_at + ttl_hours + index_commit + schema_version + repo)
- [ ] Lock mechanism: `.ci-cache.lock` (PID|host|user|acquired_at|heartbeat_at, stale 60s)
- [ ] 7 workflow skills updated với CI references (PRE-GATE Na+Nb)
- [ ] 5 procedure files updated với CI steps (correct names per F18)
- [ ] Graceful degradation verified (no GitNexus, no Serena, no both)
- [ ] Lock graceful fallback verified (lock held → Grep, no regression)
- [ ] Zero user prompt về CI tools (escape hatch: `MCV3_CI_RESCAN=1`)
- [ ] Token reduction ≥30% measured (methodology per master plan §4.3)
- [ ] E2E test: EUREKA-2026 (có cả 2) + test project (không CI)
- [ ] Multi-dev test: 5 scenarios (2 terminal song song, git pull, Serena mid-session, non-git)
- [ ] Compliance audit PASS cho tất cả modified skills
- [ ] CHANGELOG entries trong các SKILL.md
- [ ] CLAUDE.md updated với CI section
- [ ] All 26 findings addressed (6 P0, 11 P1, 8 P2, 1 P3)
