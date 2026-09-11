# 06 — Protocols Overview ★

> **Mức độ ràng buộc:** Tham khảo (overview) — **cải tiến kiến trúc**: tổng hợp 22 protocols rải rác thành 1 bảng quick map
> **Mục đích:** Quick reference 22 shared protocols MCV3 — biết khi nào dùng protocol nào, ai owns

---

## 1. Protocols là gì?

**Protocol** = pattern/quy ước dùng chung giữa các skills. Khác với **rule** (constraint cứng) và **standard** (cấu trúc bắt buộc):

| Khái niệm | Đặc tính | Ví dụ |
|----------|----------|-------|
| Rule (CORE-NNN) | Constraint cứng — vi phạm = lỗi | "Không skip phase" (CORE-002) |
| Standard | Cấu trúc bắt buộc cho artifact | "SKILL.md ≤500 dòng" |
| **Protocol** | Pattern/quy ước dùng chung | "T1→T4 POST-GATE", "CDG flow" |

Trước refactor (v1.0 — 2026-04-19): toàn bộ protocols nằm trong `shared-protocols.md` (74KB, 1609 dòng). Sau refactor: **22 file riêng** + index.

**Lợi ích split:**
- Skill chỉ load protocol cần → giảm 55-92% context per skill
- Mỗi protocol có owner + version riêng → dễ evolve
- Backward compat: `shared-protocols.md` vẫn redirect

---

## 2. Quick Map — 22 Protocols

| # | Protocol | Mục đích ngắn | Khi nào dùng | Scope |
|---|----------|---------------|--------------|-------|
| **01** | [Accuracy Assurance](../../.claude/skills/protocols/01-accuracy-assurance.md) | POST-GATE enforcement, fix rules, error tracking, Agent Status (DONE/CONCERNS/BLOCKED/CONTEXT) | Mọi skill validate output; mọi agent kết thúc task | Mọi skill + agent |
| **02** | [Auto-Correction](../../.claude/skills/protocols/02-auto-correction.md) | Auto-Correction Loop max 3 retries | Validation phase fail → auto retry | Validation phases |
| **03** | [Context Checkpoint](../../.claude/skills/protocols/03-context-checkpoint.md) | Context digest, checkpoint thresholds, resume | Multi-session skills cần --resume | Multi-session skills |
| **04** | [Stakeholder Review](../../.claude/skills/protocols/04-stakeholder-review.md) | SO doc flow + findings status | Phases tạo `stakeholder-review.md` | P1/P3/P4/P5 |
| **05** | [Registry Safe-Write](../../.claude/skills/protocols/05-registry-safe-write.md) | Field ownership table + atomic write registry | Mọi skill ghi `req-registry.json` | Skills ghi registry |
| **06** | [Token Limit](../../.claude/skills/protocols/06-token-limit.md) | Compression, output targets, digest, Large Project Mode | Skills xử lý nhiều input/output | Skills heavy I/O |
| **07** | [Parallel Execution](../../.claude/skills/protocols/07-parallel-execution.md) | L1-L4 parallel patterns + max concurrency | Spawn agents song song | Mọi skill |
| **08** | [Content Quality Gate](../../.claude/skills/protocols/08-content-quality-gate.md) | Content quality dimensions + CQG Registry | POST-GATE check chất lượng content | POST-GATE |
| **09** | [Task Planning](../../.claude/skills/protocols/09-task-planning.md) | Plan structure, token budget, burnrate | Skills lớn cần execution plan | Skills lớn |
| **10** | [POST-GATE Schema](../../.claude/skills/protocols/10-post-gate-schema.md) | T1-T4 validation tiers + forensic PRE-GATE | Mọi POST-GATE + PRE-GATE | Gates |
| **11** | [Rollback](../../.claude/skills/protocols/11-rollback.md) | L1-L3 rollback levels + registry backup | Recovery scenarios | Skills modify state |
| **12** | [Decision Registry](../../.claude/skills/protocols/12-decision-registry.md) | LOAD/WRITE/VERIFY decisions across sessions | Cross-session decision tracking | wf-implement-feature, wf-fix-bugs |
| **13** | [Test Gate](../../.claude/skills/protocols/13-test-gate.md) | Test gate per batch + rollback mechanism | Implementation skills | wf-implement-feature |
| **14** | [Phase Summary](../../.claude/skills/protocols/14-phase-summary.md) | `phase-summary.md` content rules (tiếng Việt) | Mọi skill phase kết thúc | Mọi skill |
| **15** | [Execution Trace](../../.claude/skills/protocols/15-execution-trace.md) | `session-log.json` APPEND-only observability | Mọi skill log events | Mọi skill |
| **16** | [Critical Decision Gate](../../.claude/skills/protocols/16-critical-decision-gate.md) | CDG-01 to CDG-13 + confirmation templates | User decision points | Mọi skill có CDG |
| **17** | [Agent Spot-Check](../../.claude/skills/protocols/17-agent-spotcheck.md) | Schema-based agent output spot-check | Sau khi spawn agent | Skills có agents |
| **18** | [Session Isolation](../../.claude/skills/protocols/18-session-isolation.md) | Session directory structure + ID format | Multi-run skills | Multi-run skills |
| **19** | [Template Usage](../../.claude/skills/protocols/19-template-usage.md) | READ → POPULATE → WRITE | Tạo output file | Mọi skill |
| **20** | [Code Intelligence](../../.claude/skills/protocols/20-code-intelligence.md) | Auto-detect GitNexus/Serena + lock + route + freshness | Skills cần đọc code | Skills phân tích code |
| **21** | [Cross-Skill Output Path Contract](../../.claude/skills/protocols/21-cross-skill-output-path-contract.md) | Producer→consumer path mapping | Mọi skill có output cross-skill | Mọi skill |
| **22** | [Infrastructure R/W Lock](../../.claude/skills/protocols/22-infrastructure-rw-lock.md) | Cross-session R/W lock cho BE/FE/DB/Playwright — multi-reader + single-writer + priority | Skills cần live infra | wf-e2e-* skills |

---

## 3. Phân nhóm theo chủ đề

### 3.1. Quality & Validation (5 protocols)

- **01 — Accuracy Assurance** — POST-GATE enforcement
- **02 — Auto-Correction** — Retry loop
- **08 — Content Quality Gate** — Content quality dimensions
- **10 — POST-GATE Schema** — T1→T4 tiers
- **17 — Agent Spot-Check** — Agent output validation

### 3.2. State & Session (4 protocols)

- **03 — Context Checkpoint** — Resume + digest
- **15 — Execution Trace** — session-log.json
- **18 — Session Isolation** — Session directory structure
- **22 — Infrastructure R/W Lock** — Cross-session lock

### 3.3. Data & Registry (3 protocols)

- **05 — Registry Safe-Write** — Field ownership
- **12 — Decision Registry** — Cross-session decisions
- **21 — Cross-Skill Output Path Contract** — Producer/consumer paths

### 3.4. Execution Strategy (4 protocols)

- **06 — Token Limit** — Compression + Large Project Mode
- **07 — Parallel Execution** — L1-L4 patterns
- **09 — Task Planning** — Execution plan
- **13 — Test Gate** — Per-batch test gate

### 3.5. Workflow Control (3 protocols)

- **04 — Stakeholder Review** — SO flow
- **14 — Phase Summary** — Phase reports
- **16 — Critical Decision Gate** — CDG points

### 3.6. Recovery & Output (3 protocols)

- **11 — Rollback** — L1-L3 rollback
- **19 — Template Usage** — READ→POPULATE→WRITE
- **20 — Code Intelligence** — CI detection + routing

---

## 4. Khi tạo skill mới — Protocol cần load

```
Skill type        | Protocols bắt buộc load
─────────────────|──────────────────────────────────────────────────
MỌI SKILL         | 01, 10, 14, 15, 19, 21
Multi-session     | + 03, 18
Spawn agents      | + 07, 17
Có CDG            | + 16
Modify registry   | + 05
Đọc code          | + 20
Live infra (e2e)  | + 22
Heavy I/O         | + 06
Implementation    | + 12, 13
Có stakeholder    | + 04
```

**Pattern reference từ skill mới:**

```markdown
> **Protocol:** Xem `.claude/skills/protocols/` — `01-accuracy-assurance`, `10-post-gate-schema`, `14-phase-summary`, `15-execution-trace`, `19-template-usage`, `21-cross-skill-output-path-contract`.
```

Hoặc per-protocol full path:

```markdown
> **Protocol:** Xem [.claude/skills/protocols/16-critical-decision-gate.md](.claude/skills/protocols/16-critical-decision-gate.md) §16.3 (CDG-07 implementation safety).
```

---

## 5. Cải tiến: Protocols thiếu overview cấp cao

Trước file này, người mới khó nắm:
- Có bao nhiêu protocol?
- Protocol nào liên quan task của tôi?
- Khi tạo skill mới, load protocol nào?

File này **giải quyết 3 câu hỏi đó**.

### 5.1. Pattern map theo phase

```
Phase 0 (Brainstorm)
   ├─ 04 Stakeholder Review (output có SO doc)
   ├─ 05 Registry Safe-Write (init registry)
   └─ 14 Phase Summary

Phase 1-5 (Standard flow)
   ├─ 01 Accuracy + 10 POST-GATE
   ├─ 04 Stakeholder Review
   ├─ 14 Phase Summary
   ├─ 15 Execution Trace
   ├─ 19 Template Usage
   └─ 21 Output Path Contract

Phase 4 (UX)
   └─ + 17 Agent Spot-Check (multi-design agents)

Phase 5 (Implementation)
   └─ + 12, 13, 20 (decision, test gate, code intelligence)

Phase 6 (Deployment)
   └─ + 11 Rollback (pre-deploy safety)

E2E pipeline
   └─ + 22 R/W Lock (live infra)
```

### 5.2. Khi nào protocol "kích hoạt"

| Trigger | Protocol kích hoạt |
|---------|---------------------|
| Skill load | 15 (trace) auto-start |
| Tool call Write/Edit | 19 (template) bắt buộc |
| PRE-GATE | 10 (T1→T4 forensic) |
| POST-GATE | 10 (T1→T4) + 01 (auto-correction nếu fail) |
| Spawn agent | 07 (parallel) + 17 (spot-check after) |
| User decision needed | 16 (CDG flow) |
| Registry write | 05 (safe-write) |
| Multi-session run | 03 (checkpoint) + 18 (session isolation) |
| Code analysis | 20 (CI detect) |
| Error recovery | 11 (rollback) + 02 (auto-correction) |

---

## 6. Evolution history

| Version | Ngày | Thay đổi |
|---------|------|----------|
| v1.0 | 2026-04-19 | Initial split: 22 sections → 22 protocol files + 2 templates. `shared-protocols.md` giữ làm INDEX redirect. |

---

## 7. Anti-patterns

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Skill load toàn bộ 22 protocols | Chỉ load protocol cần — xem bảng §4 |
| Inline protocol logic vào SKILL.md | Reference protocol file — KHÔNG copy nội dung |
| 2 skills tự định nghĩa T1→T4 khác nhau | Bám Protocol 10 (đồng nhất) |
| Protocol thay đổi không update version | Mỗi protocol có version riêng |
| Skill mới không reference protocol nào | PHẢI ít nhất reference 01, 10, 14, 15, 19, 21 |

---

## 8. Templates extracted

Các template tách ra khỏi protocols:

| File | Used by | Source |
|------|---------|--------|
| [`.claude/skills/templates/digest.template.md`](../../.claude/skills/templates/digest.template.md) | Protocol 06 (Large Doc Analysis) | Was inline 06 |
| [`.claude/skills/templates/execution-plan.template.md`](../../.claude/skills/templates/execution-plan.template.md) | Protocol 09 (Plan Structure) | Was inline 09 |

---

## 9. Liên kết

- **Protocols index canonical:** [`.claude/skills/protocols/README.md`](../../.claude/skills/protocols/README.md)
- **Skill standard (yêu cầu reference):** [`../02-standards/02-skill-standard.md`](../02-standards/02-skill-standard.md)
- **Quality gates (Protocol 10):** [`../02-standards/05-quality-gates.md`](../02-standards/05-quality-gates.md)
- **Templates:** [`.claude/skills/templates/`](../../.claude/skills/templates/)
