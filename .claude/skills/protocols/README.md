# Protocols Index — DEVKIT Shared Protocols

> Refactored từ `.claude/skills/shared-protocols.md` (74KB, 1609 dòng) — split thành 20 protocol files để giảm context load 55-92% per skill.
>
> **Backward compatibility:** `shared-protocols.md` vẫn tồn tại làm INDEX/redirect cho mọi skills cũ chưa migrate.

---

## Quick Map — Protocol → File

| Protocol | File | Mô tả ngắn | Scope |
|----------|------|------------|-------|
| §1 | [01-accuracy-assurance.md](01-accuracy-assurance.md) | POST-GATE enforcement, fix rules, error tracking | Mọi skill |
| §1b | [01-accuracy-assurance.md](01-accuracy-assurance.md) | Agent Status Protocol (DONE/CONCERNS/BLOCKED/CONTEXT) | Mọi agents |
| §2 | [02-auto-correction.md](02-auto-correction.md) | Auto-Correction Loop (max 3 retries) | Validation phases |
| §3 | [03-context-checkpoint.md](03-context-checkpoint.md) | Context digest, checkpoint thresholds, resume | Multi-session skills |
| §4 | [04-stakeholder-review.md](04-stakeholder-review.md) | Stakeholder review flow + findings status | Phases có SO docs |
| §5 | [05-registry-safe-write.md](05-registry-safe-write.md) | Field ownership table + atomic write | Skills ghi registry |
| §6 | [06-token-limit.md](06-token-limit.md) | Compression, output targets, digest, Large Project Mode | Skills heavy I/O |
| §7 | [07-parallel-execution.md](07-parallel-execution.md) | L1-L4 parallel patterns + max concurrency | Mọi skill |
| §8 | [08-content-quality-gate.md](08-content-quality-gate.md) | Content quality dimensions + CQG Registry (§8.5) | POST-GATE checks |
| §9 | [09-task-planning.md](09-task-planning.md) | Plan structure, token budget, burnrate | Skills lớn |
| §10 | [10-post-gate-schema.md](10-post-gate-schema.md) | T1-T4 validation tiers + forensic PRE-GATE | POST-GATE / PRE-GATE |
| §11 | [11-rollback.md](11-rollback.md) | L1-L3 rollback levels + registry backup | Recovery scenarios |
| §12 | [12-decision-registry.md](12-decision-registry.md) | LOAD/WRITE/VERIFY decisions across sessions | wf-implement-feature |
| §13 | [13-test-gate.md](13-test-gate.md) | Test gate per batch + rollback mechanism | wf-implement-feature |
| §14 | [14-phase-summary.md](14-phase-summary.md) | phase-summary.md content rules (tiếng Việt) | Mọi skill |
| §15 | [15-execution-trace.md](15-execution-trace.md) | session-log.json append-only observability | Mọi skill |
| §16 | [16-critical-decision-gate.md](16-critical-decision-gate.md) | CDG-01 to CDG-07 + confirmation templates | Mọi skill |
| §17 | [17-agent-spotcheck.md](17-agent-spotcheck.md) | Schema-based agent output spot-check | Skills có agents |
| §18 | [18-session-isolation.md](18-session-isolation.md) | Session directory structure + ID format | Multi-run skills |
| §19 | [19-template-usage.md](19-template-usage.md) | READ → POPULATE → WRITE rule | Mọi skill |
| §20 | [20-code-intelligence.md](20-code-intelligence.md) | Detect + lock + route GitNexus/Serena/Grep, per-tool TTL, freshness check, multi-dev | Mọi skill |
| §21 | [21-cross-skill-output-path-contract.md](21-cross-skill-output-path-contract.md) | Cross-Skill Output Path Contract — producer→consumer path mapping (mirror của 00-core.md §4b) | Mọi skill |
| §22 | [22-infrastructure-rw-lock.md](22-infrastructure-rw-lock.md) | Cross-session R/W lock cho BE/FE/DB/Playwright — multi-reader + single-writer + writer priority + heartbeat | Mọi skill cần live infrastructure (wf-e2e-*) |

---

## Templates (extracted)

| File | Used by | Source |
|------|---------|--------|
| [../templates/digest.template.md](../templates/digest.template.md) | Protocol 6.4 (Large Doc Analysis) | Was inline lines 379-397 |
| [../templates/execution-plan.template.md](../templates/execution-plan.template.md) | Protocol 9.2 (Plan Structure) | Was inline lines 643-670 |

---

## Cách reference từ skills mới

**Recommended pattern (gọn):**
```markdown
> **Protocol:** Xem `.claude/skills/protocols/` — `06-token-limit`, `07-parallel-execution`, `08-content-quality-gate`.
```

**Per-protocol full path (rõ ràng):**
```markdown
> **Protocol:** Xem [.claude/skills/protocols/06-token-limit.md](.claude/skills/protocols/06-token-limit.md) §6.6 (Large Project Mode).
```

---

## Lịch sử refactor

| Version | Ngày | Thay đổi |
|---------|------|----------|
| v1.0 | 2026-04-19 | Initial split: 22 sections → 20 protocol files + 2 templates. Fix §13.5 numbering bug → §8.5. Backward compatible: shared-protocols.md giữ làm index. |

---

## Audit reference

Audit báo cáo refactor: `.mc-data/work/shared-protocols-refactor-audit/audit-report.md`
