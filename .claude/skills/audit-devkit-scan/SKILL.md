---
name: audit-devkit-scan
version: 3.0.0
last_updated: 2026-04-19
changelog:
  v3.0.0 (2026-04-19):
    - Refactor monolithic SKILL.md (811 lines) → slim orchestrator (~280 lines).
    - Extract phase logic to `procedures/` (9 files): _shared, phase0-index, 5 wave files, phase2-merge, phase3-summary.
    - Extract JSON schemas to `templates/` (4 files): audit-index, findings, audit-scan-result, scan-status (CORE-031 compliance).
    - Update `_contract.json outputs.working[].template` paths.
    - Backward compatible: same arguments, same output paths, same audit pipeline.
  v2.0.0 (2026-04-14):
    - Add --skill=<name> focused scan + --since=<commit> delta scan
    - Add criteria S11/S12 (cross-skill contracts, output path alignment)
    - Add 2-tier dedup, circuit breaker, auto-split overflow handling
  v1.2.0: Fix batch overflow (business 25 → 2 sub-batches), add Wave 3.5 scripts scan
  v1.1.0: Add Wave 4 (7 Master Plan components — Hook 2-Tầng, Baseline Metrics, Checkpoint Digest, Digest Pipeline, A6-EXT, A7-EXT, Parallel Execution)
description: |
  Scan toàn bộ DEVKIT components, build ground truth index, và phát hiện issues theo batches nhỏ (≤20 files/batch).
  Output ra JSON files cho /audit-devkit-verify và /audit-devkit-fix sử dụng.

  TRIGGER khi:
  - Cần scan DEVKIT components để phát hiện structural issues
  - Bước đầu tiên trong audit pipeline mới (scan → verify → fix)
  - Keywords: "audit scan", "scan devkit", "audit-devkit-scan"

  KHÔNG trigger khi:
  - Cần cross-validate findings → dùng /audit-devkit-verify
  - Cần auto-fix issues → dùng /audit-devkit-fix
  - Audit dự án đang dùng MCV3 → không liên quan
  - Chỉ audit agents → dùng /audit-agents

argument-hint: "[--agents|--component=agents | --skills | --templates | --rules | --hooks | --all | --skill=<name>] [--since=<commit>] [--resume]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite
---

# /audit-devkit-scan: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Build ground truth index + scan components theo batches → JSON findings |
| **Prerequisites** | Không — đây là bước đầu tiên trong audit pipeline |
| **Duration** | Multi-session (nhiều agent batches) |
| **Phases** | 4 phases (Phase 0 → Phase 3), Phase 1 chia 5 waves |
| **Input** | `.claude/` directory (toàn bộ DEVKIT) |
| **Output** | `$SESSION_DIR/audit-index.json`, `findings-*.json`, `audit-scan-result.json` |

### Workflow Position

```
[entry point] → /audit-devkit-scan → /audit-devkit-verify → /audit-devkit-fix
                       ↑
                  YOU ARE HERE
```

### Structure (v3.0)

```
.claude/skills/audit-devkit-scan/
├── SKILL.md                          (orchestrator slim — file này)
├── _contract.json                    (outputs metadata)
├── procedures/                       (chi tiết per phase)
│   ├── _shared.md                    (Auditor prompt, criteria S1-S12, errors E001-E011, dedup rules)
│   ├── phase0-index.md               (Build Ground Truth Index)
│   ├── phase1-wave1-agents.md        (5 batches PARALLEL — agent-auditor)
│   ├── phase1-wave2-skills.md        (2 batches PARALLEL — skill-auditor + --skill mode)
│   ├── phase1-wave3-templates-rules-hooks.md  (3 batches PARALLEL + Bash hooks)
│   ├── phase1-wave3.5-scripts.md     (Bash scripts verify)
│   ├── phase1-wave4-masterplan.md    (MP-1 → MP-7 sequential)
│   ├── phase2-merge.md               (Merge + 2-tier dedup)
│   └── phase3-summary.md             (Display + finalize status)
├── templates/                        (JSON schemas — CORE-031)
│   ├── audit-index.json              (audit-index-v1)
│   ├── findings.json                 (audit-findings-v1)
│   ├── audit-scan-result.json        (audit-scan-result-v1)
│   └── scan-status.json
└── evals/evals.json
```

---

## Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `--agents` / `--component=agents` | Chỉ scan agent definitions | - |
| `--skills` / `--component=skills` | Chỉ scan skill definitions | - |
| `--templates` / `--component=templates` | Chỉ scan templates | - |
| `--rules` / `--component=rules` | Chỉ scan rules | - |
| `--hooks` / `--component=hooks` | Chỉ scan hooks | - |
| `--all` / `--component=all` | Scan tất cả components | **default** |
| `--skill=<name>` | Focused scan 1 skill cụ thể (skip Wave 1/3/3.5/4, chỉ chạy Wave 2 focused) | - |
| `--since=<commit>` | Delta scan — chỉ scan files thay đổi từ commit (`git diff --name-only <commit>..HEAD -- .claude/`) | - |
| `--resume` | Resume từ checkpoint (đọc `$SESSION_DIR/scan-status.json`) | - |

> Nếu cả `--component=X` và `--agents/--skills/...` được cung cấp đồng thời → `--component=X` higher priority (xem `_shared.md` §Error Handling — ARGUMENT_CONFLICT).

---

## Protocols & Strategy

> **Protocol chi tiết:** Xem `procedures/_shared.md` cho Auditor Prompt, Criteria S1-S12 + A1-A6 + T1-T5, Severity Mapping, Batching Strategy, Fix Rules, Error Codes E001-E011, Findings Build Helper, Dedup Rules, Session Lock.

### Execution Strategy (high-level)

| Wave | Mode | Tools |
|------|------|-------|
| Wave 1 (5 agent batches) | **PARALLEL** — 5 agents cùng lúc | Agent (×5) |
| Wave 2 (2 skill batches) | **PARALLEL** — 2 agents cùng lúc | Agent (×2) |
| Wave 3 (templates+rules+hooks) | **PARALLEL** — 3 agents + Bash | Agent (×3) + Bash |
| Wave 3.5 (scripts) | **PARALLEL với Wave 3** — Bash | Bash |
| Wave 4 (MP-1 → MP-7) | **SEQUENTIAL sau Wave 3** — Bash/Grep | Bash, Grep |
| Phase 2 (merge) | **SEQUENTIAL** sau toàn bộ Phase 1 | Read, Write |

### Batching: ≤20 files/batch — cân bằng accuracy vs spawns. Xem `_shared.md` §Batching Strategy.

---

## PRE-GATE (Entry)

```
1. IF --resume:
   - Resolve $SESSION_DIR (latest từ `ls -t .mc-data/work/audit-devkit-scan/`)
   - READ scan-status.json → continue từ next_action
   - SKIP Phase 0 nếu phase_0_index.status == "completed"
2. ELSE (fresh run):
   - Validate: `test -d .claude/` (E001 nếu fail)
   - Proceed to Phase 0
```

**FAIL ứng xử:**
- `.claude/` không tồn tại (E001) → "Không phải DEVKIT project. STOP."
- scan-status.json corrupt (E010) → rebuild từ existing findings-*.json files

---

## Execution Summary

| Step | Phase / Wave | Procedure | Output |
|------|--------------|-----------|--------|
| PRE-GATE | Validate | (inline trên) | — |
| **Phase 0** | Build Ground Truth Index | READ `procedures/phase0-index.md` | `audit-index.json`, `scan-status.json`, `.lock` |
| **Phase 1 W1** | Agent scans (5 PARALLEL) | READ `procedures/phase1-wave1-agents.md` | 5 × `findings-agents-*.json` |
| **Phase 1 W2** | Skill scans (2 PARALLEL) | READ `procedures/phase1-wave2-skills.md` | `findings-skills-{workflow,other}.json` (hoặc `findings-skills-focused.json` cho --skill) |
| **Phase 1 W3** | Templates + Rules + Hooks | READ `procedures/phase1-wave3-templates-rules-hooks.md` | `findings-templates-{a,b}.json`, `findings-rules.json`, `findings-hooks.json` |
| **Phase 1 W3.5** | Scripts verify (Bash) | READ `procedures/phase1-wave3.5-scripts.md` | `findings-scripts.json` |
| **Phase 1 W4** | Master Plan (MP-1 → MP-7) | READ `procedures/phase1-wave4-masterplan.md` | Up to 7 × `findings-masterplan-*.json` (optional) |
| **Phase 2** | Merge & 2-tier dedup | READ `procedures/phase2-merge.md` | `audit-scan-result.json` |
| **Phase 3** | Summary + finalize | READ `procedures/phase3-summary.md` | User report + `scan-status.json` (status=completed), lock release |

> **Quy tắc:** Mỗi phase load CHỈ procedure tương ứng (giảm context usage). Sau khi phase hoàn thành → procedure không cần giữ trong context.

---

## Mode Variants

### Default: `--all`
Chạy đầy đủ Wave 1 → 4. Output: ~13 files findings + audit-index + audit-scan-result + scan-status.

### Focused: `--skill=<name>`
- SKIP Wave 1, 3, 3.5, 4
- Chỉ chạy Wave 2 focused (1 skill + lightweight cross-ref đến downstream/upstream)
- Output: 1 file `findings-skills-focused.json` + audit-scan-result
- Xem `procedures/phase1-wave2-skills.md` §Focused Mode

### Delta: `--since=<commit>`
- Phase 0 lọc audit-index.json theo `git diff --name-only <commit>..HEAD -- .claude/`
- Wave 1-3.5 chỉ scan changed files (skip wave nếu không có files changed)
- Output: scan kết quả của các files thay đổi
- Xem `procedures/phase0-index.md` §Delta Scan Mode

### Component-only: `--agents` / `--skills` / `--templates` / `--rules` / `--hooks`
- Chỉ chạy Wave tương ứng + Phase 2 + Phase 3
- VD: `--agents` chỉ chạy Wave 1 + merge + summary

---

## Cross-Skill Output Path Contract

| Producer | Output Path | Consumer |
|----------|-------------|----------|
| `/audit-devkit-scan` Phase 0 | `.mc-data/work/audit-devkit-scan/[session]/audit-index.json` | `/audit-devkit-verify` (PRE-GATE) |
| `/audit-devkit-scan` Phase 2 | `.mc-data/work/audit-devkit-scan/[session]/audit-scan-result.json` | `/audit-devkit-verify` (input findings) |
| `/audit-devkit-scan` Phase 1 | `.mc-data/work/audit-devkit-scan/[session]/findings-*.json` | `/audit-devkit-verify` (raw findings, optional re-parse) |

---

## Resume Process

1. User: `/audit-devkit-scan --resume`
2. SKILL.md PRE-GATE: tìm latest session, READ `scan-status.json`
3. Đọc `next_action` → load procedure tương ứng và continue
4. KHÔNG re-run các phase đã `completed` trong status

---

## Context & Checkpoint (count-based)

> Checkpoint dựa trên số lượng items processed, KHÔNG dựa trên context-% (unreliable).

| Trigger | Hành động |
|---------|-----------|
| Sau mỗi wave hoàn thành | Update `scan-status.json` (heartbeat + progress) |
| Sau mỗi 20 findings | Flush partial findings vào session dir |
| Sau Phase 2 merge | Full checkpoint — write `scan-status.json` với `status: "completed"` |
| FORCE STOP (khi không thể tiếp tục) | Checkpoint ngay — ghi `next_action` để resume |

> `_shared.md` §Session Lock & Heartbeat: heartbeat update tại mỗi POST-GATE để tránh stale lock.

---

## Related Skills

| Skill | Relation |
|-------|----------|
| `/audit-devkit-verify` | **Next step** — nhận output để cross-validate |
| `/audit-devkit-fix` | Downstream — nhận verified findings để auto-fix |
| `/audit-devkit` | Parent orchestrator — gọi skill này như bước 1 |
| `/audit-agents` | Alternative — chỉ audit agent definitions (nhẹ hơn) |

---

## Error Handling

> Codes E001-E011 + ARGUMENT_CONFLICT chi tiết: `procedures/_shared.md` §Error Handling Codes

Quick reference: E001 (no .claude/), E002 (JSON invalid), E003 (agent timeout), E004 (text instead of JSON), E005 (batch >20), E006 (counts=0), E007 (write fail), E008 (missing findings file), E009 (dedup conflict), E010 (status corrupt), E011 (hook reject).

Circuit breaker: nếu >3 batches fail liên tiếp → PAUSE + hỏi user (PARTIAL hay STOP).

---

## Output Report

Xem `procedures/phase3-summary.md` §Output Report Template.
