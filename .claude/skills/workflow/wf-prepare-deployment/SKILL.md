---
name: wf-prepare-deployment
version: 2.1.0
last_updated: 2026-04-28
changelog:
  v2.1.0 (2026-04-28) — S9 cross-skill integration:
    - Thêm flag `--from-fix-bugs[=<session_id>]` (optional, opt-in) để consume
      `fix-impact.json` (S7) từ wf-fix-bugs session — Go/No-Go signal cho release.
    - Phase 1 PRE-GATE thêm logic **Fix-Impact Go/No-Go check** (conditional khi
      `$FIX_IMPACT_CONTEXT != null`):
      * `next_recommended_action.skill = 'wf-prepare-deployment'` + có blocking_items
        type='escalated' → BLOCK release với CDG (Critical Decision Gate).
      * `regression_check.tests_failed > 0` → BLOCK release với CDG.
      * `audit_chain.checksum_sha256` mismatch reproduce → WARN tamper risk.
    - Phase 6 deployment-guide.md: include section "Fix Impact Summary" (issues fixed,
      escalated, registry_changes count) khi `--from-fix-bugs` consume.
    - Backward compat: nếu `--from-fix-bugs` không pass → behavior cũ (no-op consume,
      không có Go/No-Go gate từ fix-bugs).
description: |
  Tao tai lieu trien khai va van hanh cho Phase 6 — deployment guide, user guide,
  account management, maintenance guide, incident response runbook, stakeholder review.
  Huy dong DevOps + Tech Writer + QA Lead + SRE + Integration Certifier + Reality Checker.

  TRIGGER khi:
  - User noi: "chuan bi deploy", "tao deployment docs", "huong dan trien khai"
  - User hoi: "deploy nhu the nao", "can gi truoc khi release"
  - Sau khi /wf-verify-sync dat sync rate >= 80%
  - Keywords: "deployment", "release", "trien khai", "van hanh", "go-live"
  - Goi lenh: /wf-prepare-deployment [--scope=...] [--status]

  LUON trigger khi user can chuan bi deployment docs, du khong dung tu "prepare-deployment".
  Day la buoc cuoi trong DEVKIT workflow — sau verify-sync, truoc release.

  KHONG trigger khi:
  - Chua co code → dung /wf-implement-feature truoc
  - Chua verify sync → dung /wf-verify-sync truoc

argument-hint: "[--scope=all | deployment | user-guide | maintenance] [--status] [--resume] [--from-fix-bugs[=<session_id>]]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite
---

# /wf-prepare-deployment: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Tạo 4 deployment docs hoàn chỉnh + stakeholder review |
| **Prerequisites** | `/wf-verify-sync` đã chạy, sync rate >= 80%, architecture docs ready |
| **Workflow position** | `/wf-verify-sync` → **/wf-prepare-deployment** ← YOU ARE HERE → Release / Go-Live |
| **Output** | `phase6-deployment/` — deployment-guide.md, user-guide.md, incident-response-runbook.md, stakeholder-review.md |
| **Phases** | 0 (flags) → 1 (prereq) → 2 ∥ 3a → 3b → 3c (checkpoint) → 4 → 4a → 5 → 5a |
| **Duration** | Single session cho dự án nhỏ; multi-session cho LPM (checkpoint/resume) |

## Arguments

| Argument | Mô tả | Default |
|----------|-------|---------|
| `--scope` | `all` / `deployment` / `user-guide` / `maintenance` | `all` |
| `--status` | Hiển thị tiến độ, không thực thi | — |
| `--resume` | Resume từ checkpoint đã lưu | — |
| `--from-fix-bugs[=<session_id>]` | **(v2.1+)** Consume `fix-impact.json` từ wf-fix-bugs session — Go/No-Go signal cho release. Phase 1 BLOCK với CDG nếu escalated > 0 hoặc tests_failed > 0. Không pass `<session_id>` → auto-resolve latest completed session. **Opt-in:** không pass flag → behavior cũ. | — |

### Template Usage Rule (CORE-031)

> **BẮT BUỘC:** Mọi file có Template PHẢI được tạo bằng pattern:
> 1. **READ** template file từ `templates/` (internal) hoặc `doc-framework/phase6-deployment/` (output docs)
> 2. **POPULATE** — thay thế placeholders bằng giá trị thực tế
> 3. **WRITE** output file đến destination path
>
> **NẾU SKIP bước READ template → STOP skill.**
>
> Áp dụng cho:
> - **Internal templates** (3 files): `templates/prepare-deployment-status.json`, `templates/prepare-deployment-plan.md`, `templates/checkpoint.json`
> - **doc-framework templates** (4 files): `phase6-deployment/deployment-guide.md`, `phase6-deployment/user-guide.md`, `phase6-deployment/incident-response-runbook.md`, `phase6-deployment/stakeholder-review.md`

## Protocols

> **Protocol:** Xem `.claude/skills/protocols/` — Protocol 6 (Token Limit Prevention), Protocol 7 (PAR), Protocol 8 (CQG), Protocol 9 (PLN), Protocol 10 (POST-GATE Schema Validation), Protocol 11 (Rollback), Protocol 19 (Template Usage Rule).
>
> **Internal shared:** Xem `procedures/_shared.md` — State Variables Glossary, Fix Rules, Agent Prompt Templates, Checkpoint Protocol, LPM overrides, Cross-File Write Conflict Avoidance.

- **Accuracy Assurance** (mọi phase): POST-GATE Enforcement + Fix Rules + Error Tracking
- **Auto-Correction Loop** (Phase 5, 5a): max 3 iterations
- **Context & Checkpoint**: thresholds 65/80/90% (Phase 3c, 4, 4a, 5, 5a)
- **Parallel Execution** (Phase 2 ∥ 3a, Phase 5a): Output files khác nhau → an toàn parallel
- **Cross-File Write Conflict Avoidance**: Phase 3b + 4 PHẢI dùng Edit (append) khi ghi vào deployment-guide.md
- **Token Limit Prevention**: Architecture digest re-use (Phase 2), Feature digest (Phase 3a), Skeleton-first (>3000/2000 từ)
- **Content Quality Gate** (Phase 5): 10 Muc đầy đủ, cross-ref API, service names, section depth, registry freshness
- **Large Project Mode** (auto-detect Phase 1): `systems>=5 OR depts>=10 OR reqs>=50 OR features>=40`

## Execution Strategy

| Điều kiện | Chế độ |
|-----------|--------|
| Phase 0 (flags) | SEQUENTIAL — routing handler |
| Phase 1 (prereq + plan) | SEQUENTIAL — main conversation, không spawn agent |
| Phase 2 (deployment-guide.md Muc 1-8) ∥ Phase 3a (user-guide.md) | **PARALLEL** — output files khác nhau |
| Phase 3b (Muc 9) | SEQUENTIAL — sau Phase 2 + 3a |
| Phase 3c (checkpoint) | SEQUENTIAL — main conversation, check context % |
| Phase 4 (Muc 10) | SEQUENTIAL — 1-2 agents tuỳ context |
| Phase 4a (runbook) | SEQUENTIAL — 1 sre agent |
| Phase 5 (cross-validation) | SEQUENTIAL — auto-correction loop |
| Phase 5a (stakeholder review) | **PARALLEL** (3 agents) + SEQUENTIAL (reality-checker) |

> **Retry:** Mỗi agent retry tối đa 3 lần. Nếu vẫn fail → escalate (E009).

## Work Directory

```
.mc-data/work/wf-prepare-deployment/
├── prepare-deployment-status.json  # Runtime status
├── prepare-deployment-plan.md      # Execution plan (Phase 1)
└── checkpoint.json                 # Checkpoint cho resume
```

Templates: `.claude/skills/workflow/wf-prepare-deployment/templates/`

---

## Phase 0: Flag Handling (BẮT BUỘC — chạy trước tiên)

> Xử lý flags `--status`, `--resume`, `--from-fix-bugs` trước khi vào main flow.

```
STEP 1: Parse $ARGUMENTS
  → Capture: $SCOPE, $RESUME_MODE, $HAS_STATUS_FLAG,
             $HAS_FROM_FIX_BUGS_FLAG, $FROM_FIX_BUGS_SESSION_ID
  → `--from-fix-bugs` parse: nếu có `=<id>` → set $FROM_FIX_BUGS_SESSION_ID;
    nếu chỉ `--from-fix-bugs` (no value) → $FROM_FIX_BUGS_SESSION_ID="" (auto-resolve)

  IF chứa "--status":
    → Read procedures/phase0-flags.md §--status Handler
    → STOP sau khi hiển thị report

  IF chứa "--resume":
    → Read procedures/phase0-flags.md §--resume Handler
    → Set $RESUME_MODE = true
    → Jump tới phase tương ứng (theo Reconciliation Logic)

  ELSE (không có flag):
    → CONTINUE tới Phase 1 (prereq)
    (Phase 1 sẽ load $FIX_IMPACT_CONTEXT từ wf-fix-bugs session nếu
     $HAS_FROM_FIX_BUGS_FLAG=true, sau đó chạy Go/No-Go gate)
```

---

## Phase Routing Map (lazy-loaded)

> SKILL.md routing block KHÔNG chứa execution steps. Toàn bộ logic chi tiết được lazy-load
> qua các phase files riêng. Read MỖI phase file CHỈ KHI tới phase tương ứng để giảm context load.

| Phase | Procedure file | Điều kiện | Mục đích |
|-------|---------------|-----------|----------|
| **0** | `procedures/phase0-flags.md` | `--status` hoặc `--resume` có trong $ARGUMENTS | Flag handlers + routing |
| **1** | `procedures/phase1-prereq.md` | Always (entry point sau Phase 0) | Prerequisites + Execution Plan + LPM detect |
| **2** | `procedures/phase2-deployment-guide.md` | Always (nếu `$SCOPE ∈ {all, deployment}`) | deployment-guide.md Muc 1-8 (PARALLEL với 3a) |
| **3a** | `procedures/phase3a-user-guide.md` | Always (nếu `$SCOPE ∈ {all, user-guide}`) | user-guide.md (PARALLEL với 2) |
| **3b** | `procedures/phase3b-account-mgmt.md` | Phase 2 + 3a DONE | Muc 9 Account Management |
| **3c** | `procedures/phase3c-checkpoint.md` | Always (sau Phase 3b) | Checkpoint + context budget check |
| **4** | `procedures/phase4-maintenance.md` | Phase 3c DONE | Muc 10 Maintenance Guide |
| **4a** | `procedures/phase4a-runbook.md` | Phase 4 DONE | incident-response-runbook.md |
| **5** | `procedures/phase5-crossval.md` | Phase 4a DONE | Cross-Validation + Content Quality Gate |
| **5a** | `procedures/phase5a-review.md` | Phase 5 PASS | Stakeholder Review (4 agents) |

**Routing flow:**

```
SKILL.md Phase 0 (flag check)
  ↓
  IF có flag → Read procedures/phase0-flags.md → execute → (STOP hoặc jump)
  ELSE → continue
  ↓
Read procedures/phase1-prereq.md → execute → return
  ↓
  IF $SCOPE covers deployment:
    Read procedures/phase2-deployment-guide.md → execute (PARALLEL) → return
  IF $SCOPE covers user-guide:
    Read procedures/phase3a-user-guide.md → execute (PARALLEL) → return
  ↓
Read procedures/phase3b-account-mgmt.md → execute → return
  ↓
Read procedures/phase3c-checkpoint.md → execute → return
  (skill có thể STOP nếu context >= 90% — resume với --resume)
  ↓
Read procedures/phase4-maintenance.md → execute → return
  ↓
Read procedures/phase4a-runbook.md → execute → return
  ↓
Read procedures/phase5-crossval.md → execute → return
  ↓
Read procedures/phase5a-review.md → execute → return → DONE
```

> **Mỗi phase file là self-contained** — chứa PRE-GATE, INPUT, OUTPUT, Steps, POST-GATE riêng.
> Phase file tham chiếu `procedures/_shared.md` cho cross-cutting: State Variables, Agent Prompts, Fix Rules, Checkpoint Protocol.

---

## Output Files

| # | File | Path | Phase | Template |
|---|------|------|-------|----------|
| 1 | deployment-guide.md (Muc 1-10) | `.mc-data/docs/phase6-deployment/` | 2 + 3b + 4 | `doc-framework/phase6-deployment/deployment-guide.md` |
| 2 | user-guide.md | `.mc-data/docs/phase6-deployment/` | 3a | `doc-framework/phase6-deployment/user-guide.md` |
| 3 | incident-response-runbook.md | `.mc-data/docs/phase6-deployment/` | 4a | `doc-framework/phase6-deployment/incident-response-runbook.md` |
| 4 | stakeholder-review.md (Phần A/B/C/D) | `.mc-data/docs/phase6-deployment/` | 5a | `doc-framework/phase6-deployment/stakeholder-review.md` |

### Working files

| File | Path | Phase | Template |
|------|------|-------|----------|
| prepare-deployment-status.json | `.mc-data/work/wf-prepare-deployment/` | 1 | `templates/prepare-deployment-status.json` |
| prepare-deployment-plan.md | `.mc-data/work/wf-prepare-deployment/` | 1 | `templates/prepare-deployment-plan.md` |
| checkpoint.json | `.mc-data/work/wf-prepare-deployment/` | 3c, 4, 4a, 5, 5a | `templates/checkpoint.json` |

> `deployment-guide.md` chứa tất cả nội dung: Muc 1-8 (Deployment, Phase 2), Muc 9 (Account Management, Phase 3b), Muc 10 (Maintenance, Phase 4).
> `stakeholder-review.md` chứa: Phần A (Summary), Phần B (Deployment Review), Phần C (Consistency Check), Phần D (Gap Analysis), Production Readiness Final.

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E001 | `req-registry.json` không tồn tại | STOP → chạy workflow từ đầu |
| E002 | `verify-sync.md` không tồn tại | STOP → chạy `/wf-verify-sync` trước |
| E003 | Sync rate < 80% | WARNING → hỏi user confirm |
| E004 | `P3-01-architecture.md` không tồn tại | STOP → chạy `/wf-design` trước |
| E005 | Agent timeout | Retry ×3, sau đó escalate |
| E006 | Template không tìm thấy | STOP → verify `.claude/doc-framework/` + `templates/` |
| E007 | Cross-validation mismatch (Phase 5) | List mismatches, user review trước khi finalize |
| E008 | Context > 90% sau Phase 3b | FORCE checkpoint + STOP, resume với `--resume` |
| E009 | POST-GATE fail sau 3 retries | STOP phase, escalate với chi tiết lỗi |
| E010 | Auto-fix regression | STOP auto-fix, escalate ngay lập tức |
| **E011** | **`E_DEPLOY_ENV_MISMATCH`** | **WARNING + MANUAL REVIEW:** Hiển thị bảng so sánh env vars. Không auto-fix. |
| **E012** | **Deployment-guide bị ghi đè (Phase 3b hoặc 4)** | **ROLLBACK**, re-run Phase 2 + phases sau |

---

## Agents Spawned

| Phase | Agent | Mục đích |
|-------|-------|----------|
| 2 | `devops` | deployment-guide.md Muc 1-8 |
| 3a | `tech-writer` | user-guide.md |
| 3b | `tech-writer` | Muc 9 Account Management |
| 4 | `devops` + `tech-writer` | Muc 10 Maintenance |
| 4a | `sre` | incident-response-runbook.md |
| 5a | `devops` | Phần B + Phần D |
| 5a | `qa-lead` | Phần C |
| 5a | `integration-certifier` | Production Readiness |
| 5a | `reality-checker` | Final reality check |

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `/wf-verify-sync` | Prerequisite |
| `/wf-design` | Prerequisite (architecture context) |
| `/wf-implement-feature` | Prerequisite (code must exist) |
| `/status` | Kiểm tra tiến độ |

---

## Examples

### Example 1: Happy Path (new project, small)

```
Phase 0: No flags → continue
Phase 1: prereq OK, LPM=false, $SCOPE=all
Phase 2 ∥ 3a: deployment-guide (Muc 1-8) + user-guide — PARALLEL DONE
Phase 3b: Muc 9 Account Management DONE
Phase 3c: Checkpoint saved (context 45%)
Phase 4: Muc 10 Maintenance DONE
Phase 4a: incident-response-runbook.md DONE
Phase 5: Cross-validation — 0 errors (1 iteration)
Phase 5a: Stakeholder review — APPROVED (0 Critical, 2 Medium RESOLVED)

Next: Go-Live!
```

### Example 2: Multi-Session (LPM)

```
SESSION 1: Phase 0-3c (LPM detected, 6 systems)
  → Phase 3c CHECKPOINT (Context: 72%, 3/4 docs done)
SESSION 2 (--resume): Phase 4-5a
  → Resume reconciles disk state, tiếp tục từ Phase 4
  → DONE
```

### Example 3: Sync Rate Gate

```
Phase 1: $SYNC_RATE = 65% < 80%
  → E003 WARNING
  → User: "yes" (accept low sync rate)
  → error_log appended
  → CONTINUE với các phases
```
