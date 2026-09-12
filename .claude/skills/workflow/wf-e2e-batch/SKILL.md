---
name: wf-e2e-batch
version: 1.1.0
last_updated: 2026-09-12
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
| **Prerequisites** | Registry tồn tại + ≥1 FEAT-ID resolvable từ `--scope`/`--feats` (PRE-GATE T1-T2); code các FEAT đã implement |
| **Standalone** | YES — entry point cho batch E2E |
| **Input** | `--scope=<module>` HOẶC `--feats=ID1,ID2,...` |
| **Output** | `batch-summary.md`, `batch-impact.json`, `dependency-matrix.json` |
| **Không làm** | Không test trực tiếp — chỉ orchestrate |

### Workflow Position

```
/wf-implement-feature (code xong N features)
        │
        ▼
/wf-e2e-batch  ← YOU ARE HERE — dispatch /wf-e2e-verify × N FEATs
        │
        ▼
/wf-verify-sync (consume batch results) → /wf-prepare-deployment
```

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

## Phase 0: INIT (BẮT BUỘC — entry point)

> Chi tiết: `procedures/_shared.md §init`. Tóm tắt bước thực thi:

| Step | Action | Verify |
|------|--------|--------|
| 1 | Parse flags (`--scope`/`--feats`, `--max-parallel`, `--dry-run`, `--auto`, `--resume`, `--status`) | Flags hợp lệ; thiếu scope/feats → E002 |
| 2 | Session init + lock + heartbeat trong `sessions/{batch-id}/` | Lock acquired; conflict → E003 |
| 3 | CI PRE-GATE Na-Nc (detect + freshness + inject context) | CI flags + `$CI_CONTEXT` set |
| 4 | PRE-GATE T1-T2: registry valid + FEATs resolvable | ≥1 FEAT-ID; E001/E050 → STOP |

## Phase Routing Map

| # | Phase | Procedure file | Mô tả |
|---|-------|---------------|-------|
| **0** | P0 INIT | `procedures/_shared.md` §init | Session init, lock, parse flags, CI PRE-GATE |
| **1** | P1 DISCOVER | `procedures/phase1-discover.md` | Đọc registry, filter FEATs |
| **2** | P2 DEPENDENCY | `procedures/phase2-dependency.md` | Build dependency matrix + CF1/CF7 |
| **3** | P3 EXECUTE | `procedures/phase3-execute.md` | Topology dispatch + CF2/CF3/CF4/CF5/CF8 |
| **4** | P4 AGGREGATE | `procedures/phase4-aggregate.md` | Tổng hợp kết quả |
| **R** | RESUME/STATUS | `procedures/resume-status.md` | --resume và --status handlers |
| **A** | AUTO-RESOLVE | `procedures/auto-resolve.md` | Agent-based decision engine cho --auto mode — spawn architect agent tại mọi CDG points (cf2/cf3/cf5/verify_block), audit log tại auto-decisions.jsonl |

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

## Error Handling

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

### Fix Rules

| Error Type | Auto-Fix | Escalate khi |
|------------|----------|--------------|
| FEAT B fail do FEAT A chưa đạt min_completion (E053, CF2) | Re-queue FEAT B vào level kế tiếp theo topology; 2-tier dependency check lại trước dispatch | FEAT A fail terminally → áp dụng chain rollback policy (CF5) hoặc hỏi user |
| Gate check fail sau 3 FEATs (E054, CF3) | Dừng dispatch FEATs kế tiếp, giữ kết quả đã có trong batch-status.json | User quyết định continue (note trong audit_chain) hay abort batch |
| Upstream cache hash mismatch (E058, CF8) | Invalidate cached findings của FEAT A, re-dispatch F0a rồi cho FEAT B consume lại | Findings thay đổi lần 2 — STOP, báo data instability |
| Circular dependency (E051) | Không auto-fix — hiển thị cycle path cho user gỡ node | User không gỡ được → abort batch |
| Per-FEAT schema namespace fail (E055) | Retry tạo namespace ×1 (Docker có thể chậm start) | Vẫn fail → giảm --max-parallel, hỏi user |
| Session lock conflict (E003) | Retry acquire ×3 với backoff | Vẫn conflict → báo session khác đang chạy, STOP |

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

> **Next:** batch xong → `/wf-verify-sync` (consume batch results) → `/wf-prepare-deployment`; FEAT fail xem `batch-summary.md` + chạy `/wf-e2e-fix`.

> **Protocol:** Xem `.claude/skills/protocols/` — Protocol 10 (POST-GATE Schema), Protocol 14 (Phase Summary), Protocol 15 (Session Log), Protocol 16 (CDG), Protocol 19 (Template Usage Rule), Protocol 20 (Code Intelligence).
