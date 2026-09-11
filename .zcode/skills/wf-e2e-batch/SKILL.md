---
name: wf-e2e-batch
version: 1.0.0
last_updated: 2026-05-15
description: |
  BATCH ORCHESTRATOR — điều phối N FEATs với dependency-matrix. Dispatch wf-e2e-verify
  theo topology sort. Cross-FEAT test isolation, gate sau mỗi 3 FEAT, per-FEAT DB schema namespace.
  Không test trực tiếp — orchestrate wf-e2e-verify × N FEATs.

  TRIGGER khi: "/wf-e2e-batch", "batch test", "kiểm thử nhiều feature", "test toàn bộ module".
  KHÔNG trigger: test 1 FEAT (dùng /wf-e2e-verify), audit DEVKIT.

argument-hint: "[--scope=<module>] [--feats=<ID1,ID2,...>] [--max-parallel=<N>] [--dry-run] [--auto] [--no-seed]"
disable-model-invocation: false
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, TodoWrite, AskUserQuestion, Agent
---

# /wf-e2e-batch: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | Batch Orchestrator — dispatch wf-e2e-verify × N FEATs |
| **Standalone** | YES — entry point cho batch E2E |
| **Input** | `--scope=<module>` HOẶC `--feats=ID1,ID2,...` |
| **Output** | `batch-summary.md`, `batch-impact.json`, `dependency-matrix.json` |
| **Không làm** | Không test trực tiếp — chỉ orchestrate |

## Flow Tổng Quan

```
[Input: scope/feats list]
   │
   ▼ Phase 1: DISCOVER — đọc registry, filter FEATs theo scope
   │
   ▼ Phase 2: DEPENDENCY — build dependency-matrix.json (v2)
   │   CF1: feat-to-feat, feat-to-module, feat-to-external
   │   CF7: granular phase-level dependencies
   │
   ▼ Phase 3: EXECUTE — topology sort → dispatch wf-e2e-verify × N
   │   - Parallel-safe theo level
   │   - CF8: stable upstream cache cho FEAT B reuse FEAT A findings
   │   - Gate sau mỗi 3 FEAT (CF3)
   │   - Per-FEAT DB schema namespace (CF4)
   │   - Chain rollback policy (CF5)
   │   - CF2: 2-tier dependency check trước mỗi dispatch
   │
   ▼ Phase 4: AGGREGATE — batch-summary.md + batch-impact.json
```

## Phase Routing Map

| Phase | Procedure file | Mô tả |
|-------|---------------|-------|
| P0 INIT | `procedures/_shared.md` §init | Session init, lock, parse flags, CI PRE-GATE |
| P1 DISCOVER | `procedures/phase1-discover.md` | Đọc registry, filter FEATs |
| P2 DEPENDENCY | `procedures/phase2-dependency.md` | Build dependency matrix + CF1/CF7 |
| P3 EXECUTE | `procedures/phase3-execute.md` | Topology dispatch + CF2/CF3/CF4/CF5/CF8 |
| P4 AGGREGATE | `procedures/phase4-aggregate.md` | Tổng hợp kết quả |
| RESUME/STATUS | `procedures/resume-status.md` | --resume và --status handlers |
| AUTO-RESOLVE | `procedures/auto-resolve.md` | Agent-based decision engine cho --auto mode — spawn architect agent tại mọi CDG points (cf2/cf3/cf5/verify_block), audit log tại auto-decisions.jsonl |

## Arguments

| Argument | Mô tả | Default |
|----------|-------|---------|
| `--scope=<module>` | Test tất cả FEATs trong module (vd: `fin`, `sales`) | - |
| `--feats=<IDs>` | Danh sách FEAT-ID cụ thể (comma-separated) | - |
| `--max-parallel=<N>` | Max FEATs chạy song song cùng lúc | 3 |
| `--dry-run` | Chỉ build dependency graph, không dispatch | false |
| `--auto` | Spawn decision agent tại mọi CDG points — deferred items được giải quyết tự động, không dừng chờ user (xem `procedures/auto-resolve.md`) | false |
| `--no-seed` | Bỏ qua F0b seed manifest | false |
| `--resume` | Resume batch session đang dở | false |
| `--status` | Hiển thị tiến độ batch | false |
| `--enable-chain-rollback` | Cho phép ROLLBACK_A khi FEAT B fail do FEAT A | false |

## CI PRE-GATE (CORE-033)

> CI tools auto-detect, không hỏi user. Lock held → fallback Grep/Glob.

| Step | Action | Verify |
|------|--------|--------|
| **Na** | Load CI Capabilities: `bash .claude/scripts/ci-detect.sh` → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE` | CI flags set |
| **Nb** | Index Freshness Check: `bash .claude/scripts/ci-freshness-check.sh` → ok/light/strong/severe | Freshness status set |
| **Nc** | Agent Context Injection: `bash .claude/scripts/ci-inject-context.sh` → `$CI_CONTEXT` | CI context ready |

## PRE-GATE (CORE-011)

```
T1: Registry tồn tại + valid JSON (jq '.' pass)
T2: ≥1 FEAT-ID tìm được từ --scope hoặc --feats
T3: Không circular dependency trong dependency graph (sau Phase 2)
T4: Docker Compose available nếu max-parallel > 2
```

## POST-GATE (CORE-012)

```
Sau mỗi phase: ghi batch-status.json (atomic write)
Sau P3: gate-report-{N}.json sau mỗi 3 FEAT
Sau P4: batch-summary.md (CORE-028, tiếng Việt ≤20 dòng)
Toàn batch: batch-impact.json (schema e2e-batch-v1, audit_chain)
```

## Session Structure

```
.mc-data/work/wf-e2e-batch/
├── _index/sessions.jsonl                  ← APPEND-only index
└── sessions/{batch-id}/                   ← Per-batch isolation (CORE-035)
    ├── batch-status.json                  ← Pipeline SSOT (atomic write)
    ├── session-log.json                   ← CORE-026 APPEND-only
    ├── error-ledger.json                  ← CORE-034 APPEND-only
    ├── .lock                              ← Lock + heartbeat
    ├── feat-list.json                     ← Phase 1 output
    ├── dependency-matrix.json             ← Phase 2 output (schema v2)
    ├── batch-summary.md                   ← Phase 4 output (CORE-028)
    ├── batch-impact.json                  ← Phase 4 output (schema e2e-batch-v1)
    ├── gate-report-{N}.json               ← Phase 3 (sau mỗi 3 FEAT)
    └── chain-rollback-decisions.json      ← Phase 3 CF5 decisions
```

## Output Files

| File | Path | Phase | Template |
|------|------|-------|---------|
| feat-list.json | `sessions/{id}/feat-list.json` | P1 | - |
| dependency-matrix.json | `sessions/{id}/dependency-matrix.json` | P2 | `templates/dependency-matrix.template.json` |
| batch-summary.md | `sessions/{id}/batch-summary.md` | P4 | `templates/batch-summary.template.md` |
| batch-impact.json | `sessions/{id}/batch-impact.json` | P4 | `templates/batch-impact.template.json` |

## Error Codes

| Code | Mô tả |
|------|-------|
| E001 | Registry không tồn tại hoặc invalid JSON |
| E002 | --scope hoặc --feats không được cung cấp |
| E003 | Session lock conflict |
| E004 | Context >90% — FORCE STOP (CORE-038) |
| E050 | --scope hoặc --feats không tìm được FEAT nào trong registry |
| E051 | Circular dependency phát hiện trong dependency graph |
| E052 | Topology sort thất bại |
| E053 | FEAT B dispatch fail do FEAT A chưa đạt min_completion (CF2) |
| E054 | Gate check thất bại sau N FEATs (CF3) |
| E055 | Per-FEAT schema namespace tạo thất bại (CF4) |
| E056 | Chain rollback policy conflict (CF5) |
| E057 | Cross-REQ-ID mismatch (CF6) |
| E058 | Upstream cache hash mismatch — FEAT A findings đã thay đổi (CF8) |

## Parallelism Architecture

`wf-e2e-batch` đạt throughput cao nhờ 2 cơ chế kết hợp:

| Cơ chế | Vai trò | Ghi chú |
|--------|---------|---------|
| **Docker per-FEAT (CF4)** | Mỗi FEAT chạy trong DB schema namespace riêng biệt → nhiều FEAT run song song an toàn | `--max-parallel=N` (default 5) |
| **Playwright Queue (serialized)** | Mọi browser jobs được enqueue + process tuần tự bởi `wf-playwright-runner` → tránh race condition MCP Playwright | Cross-session, persistent |

**Kết quả:** N FEATs chạy song song (Docker-isolated) + MCP Playwright có xác suất thực thi cao vì queue đảm bảo không bao giờ có 2 browser context cùng lúc.

## Playwright Queue (Centralized Dispatch)

`wf-e2e-batch` sở hữu Playwright queue — điều phối browser jobs từ mọi wf-e2e-verify session:

| File | Mô tả |
|------|-------|
| `procedures/playwright-queue.md` | Queue protocol, schema, functions (`enqueue_playwright_job`, `process_playwright_queue`, `check_playwright_results`, `load_playwright_results`) |
| `procedures/playwright-runner.md` | Entry point `wf-playwright-runner` — xử lý queue tuần tự |

**Flow:** wf-e2e-verify (F2/F7/F8) `source` queue từ `wf-e2e-batch/procedures/playwright-queue.md`
→ enqueue job → `wf-playwright-runner` process ONE at a time → wf-e2e-verify `--resume` apply results.

**Queue path:** `.mc-data/work/playwright-queue/queue.json` (cross-session, persistent)

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `wf-e2e-verify` | Được dispatch × N FEATs; source playwright-queue từ batch |
| `wf-e2e-test` (F1) | Sub-skill của wf-e2e-verify |
| `wf-verify-sync` | Downstream — consume batch results |
| `/status` | Xem tiến độ skill |
| `/wf-playwright-runner` | Standalone runner — xử lý Playwright queue |

> **Protocol:** Xem `.claude/skills/protocols/` — Protocol 10 (POST-GATE Schema), Protocol 14 (Phase Summary), Protocol 15 (Session Log), Protocol 16 (CDG), Protocol 19 (Template Usage Rule), Protocol 20 (Code Intelligence).
