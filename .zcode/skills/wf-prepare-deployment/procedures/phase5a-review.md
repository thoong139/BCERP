# Phase 5a: Stakeholder Deployment Review

> Rà soát tài liệu triển khai — deployment readiness, user docs coverage, security hardening.
> Spawn 3 agents PARALLEL (devops + qa-lead + integration-certifier) + 1 agent SEQUENTIAL (reality-checker).
> Auto-correction loop max 3 iterations cho findings Critical/High.

**PRE-GATE:**
- [ ] Phase 5 Cross-Validation PASSED (zero CRITICAL errors)
- [ ] Tất cả 3 docs (deployment-guide, user-guide, runbook) non-empty

**INPUT:**

| File | Path | Mục đích |
|------|------|----------|
| Deployment guide | `.mc-data/docs/phase6-deployment/deployment-guide.md` | Rà soát procedures, Muc 9 + 10 |
| User guide | `.mc-data/docs/phase6-deployment/user-guide.md` | Rà soát coverage tính năng |
| Runbook | `.mc-data/docs/phase6-deployment/incident-response-runbook.md` | Rà soát incident procedures |
| Infra spec | `.mc-data/docs/phase3-architecture/technical-specs/infra-spec.md` | Cross-validate infra config |
| Architecture | `.mc-data/docs/phase3-architecture/P3-01-architecture.md` | Phase 2 architecture alignment |
| Template | `.claude/doc-framework/phase6-deployment/stakeholder-review.md` | Cấu trúc Phần A/B/C/D |

**OUTPUT:** `.mc-data/docs/phase6-deployment/stakeholder-review.md` (4 phần A/B/C/D)

---

## Reference Sections

- `_shared.md` §Agent Prompt Templates → P5a-DEVOPS, P5a-QALEAD, P5a-CERTIFIER, P5a-REALITY
- `_shared.md` §Checkpoint Protocol

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 5a.0 | **[SKIP-IF-EXISTS]** `IF test -f stakeholder-review.md && test -s` → SKIP Phase 5a, log | Skip flag hoặc continue |
| 5a.1 | Đọc 3 docs Phase 6 (deployment-guide, user-guide, runbook) + architecture | Context loaded |
| 5a.2 | **PARALLEL SPAWN** — xem §Parallel Agent Spawning | 3 agents success |
| 5a.3 | Merge outputs từ 3 agents vào `stakeholder-review.md` (Phần B/C/D) | Sections present |
| 5a.4 | Viết Phần A (Index/Summary) với status + issues summary | Section A present |
| 5a.5 | **SEQUENTIAL** — spawn `reality-checker` agent sau 3 agents trên | Reality check PASS |
| 5a.6 | Append reality-checker output vào `stakeholder-review.md` (Production Readiness section) | Appended |
| 5a.7 | **AUTO-CORRECTION LOOP** — fix SOURCE docs cho Critical/High findings (xem §Auto-Correction) | Zero Critical/High pending |
| 5a.8 | **SAVE CHECKPOINT** (final) | Checkpoint saved |
| 5a.9 | Update `prepare-deployment-status.json` → status="completed", completed_at, metrics | Status updated |

---

## §Parallel Agent Spawning (Step 5a.2)

**PARALLEL (single message, 3 tool calls):**

1. Agent 1: `devops` — Phần B (Deployment Review) + Phần D (Gap Analysis)
   - Prompt: Xem `_shared.md §Agent Prompt Templates → P5a-DEVOPS`
2. Agent 2: `qa-lead` — Phần C (Consistency Check)
   - Prompt: Xem `_shared.md §Agent Prompt Templates → P5a-QALEAD`
3. Agent 3: `integration-certifier` — Production Readiness Certification
   - Prompt: Xem `_shared.md §Agent Prompt Templates → P5a-CERTIFIER`

**LPM Note:** Nếu `$LPM_PARAMS.max_parallel_agents < 3` → chạy SEQUENTIAL 3 agents (devops → qa-lead → integration-certifier).

---

## §Sequential Reality Check (Step 5a.5)

Sau khi 3 agents trên hoàn thành:

```
Spawn `reality-checker` agent với prompt P5a-REALITY:
- Context: Tất cả deployment docs + 3 outputs từ agents trước
- Mặc định NEEDS WORK — yêu cầu evidence áp đảo để PASS
- Output: READY / NEEDS WORK với blocking items
```

Append output vào `stakeholder-review.md` (section "Production Readiness Final Check").

---

## §Auto-Correction Loop (Step 5a.7)

```
FOR iteration = 1 to 3:
  findings = parse(stakeholder-review.md)  # Critical/High/Medium/Low
  critical_high_pending = findings.filter(f => f.severity in [Critical, High] && f.status == PENDING)

  IF critical_high_pending.length == 0:
    → PASS, break

  FOR each finding in critical_high_pending:
    source_doc = identify_source(finding)  # deployment-guide/user-guide/runbook
    fix_strategy = {
      "missing_rollback_plan": Re-run Phase 2 agent với instruction bổ sung,
      "security_gap": Re-run Phase 4 agent với security focus,
      "monitoring_incomplete": Re-run Phase 4a agent,
      "user_coverage_gap": Re-run Phase 3a agent,
      ...
    }
    apply_fix(fix_strategy, source_doc)
    mark_finding_as_RESOLVED(finding)
    error_log.append(...)

  # Re-run 3 agents PARALLEL + reality-checker để re-validate
  IF iteration == 3 AND critical_high_pending.length > 0:
    → STOP, E009
    → escalate với chi tiết findings còn lại
```

> **Quan trọng:** Fix SOURCE docs (deployment-guide/user-guide/runbook), KHÔNG fix `stakeholder-review.md`.
> `stakeholder-review.md` là output báo cáo, không phải doc có thể sửa trực tiếp.

---

## §Final Status Update (Step 5a.9)

Update `prepare-deployment-status.json`:

```json
{
  "status": "completed",
  "progress_pct": 100,
  "timestamps": {
    "completed_at": "<ISO 8601 hien tai>"
  },
  "phases": {
    "phase_5a": {
      "status": "completed",
      "completed_at": "<ISO 8601>",
      "iterations": <final iteration count>
    }
  },
  "output_files": {
    "deployment_guide": ".mc-data/docs/phase6-deployment/deployment-guide.md",
    "user_guide": ".mc-data/docs/phase6-deployment/user-guide.md",
    "runbook": ".mc-data/docs/phase6-deployment/incident-response-runbook.md",
    "stakeholder_review": ".mc-data/docs/phase6-deployment/stakeholder-review.md"
  },
  "metrics": {
    "agents_spawned": <count>,
    "docs_created": 4,
    "sessions_used": <count>,
    "checkpoints_saved": <count>,
    "validation_iterations": <count>
  }
}
```

---

## POST-GATE

- [ ] `test -s .mc-data/docs/phase6-deployment/stakeholder-review.md`
- [ ] **[Protocol 10 — T2]** File chứa đủ 4 phần:
  ```bash
  grep -cE "^## (Phan A|Phan B|Phan C|Phan D|Summary|Deployment Review|Consistency|Gap Analysis)" stakeholder-review.md >= 4
  ```
- [ ] Zero Critical/High findings PENDING (tất cả RESOLVED hoặc DEFERRED)
- [ ] Production Readiness: CERTIFIED hoặc user đã accept `NEEDS WORK` với blocking items cụ thể
- [ ] Status file updated với `status="completed"`

**Next phase:** Skill COMPLETE — hiển thị Output Report, chờ user action (Release/Go-Live hoặc fix issues).

---

## Output Report (on completion)

```
## Deployment Docs hoan tat!

### Files da tao
| File | Status |
|------|--------|
| deployment-guide.md (Muc 1-10) | OK |
| user-guide.md | OK |
| incident-response-runbook.md | OK |
| stakeholder-review.md (Phan A/B/C/D) | OK |

Tat ca files trong `.mc-data/docs/phase6-deployment/`

### Stakeholder Review Summary
| Review | Status | Findings |
|--------|--------|----------|
| Phan A (Summary) | OK | — |
| Phan B (Deployment Review) | OK | [N] findings (Critical: 0, High: 0) |
| Phan C (Consistency Check) | OK | [N] findings |
| Phan D (Gap Analysis) | OK | [N] findings |
| Production Readiness | CERTIFIED / NEEDS WORK | [blocking items neu co] |

### Metrics
- Agents spawned: [N]
- Docs created: 4
- Sessions used: [N]
- Checkpoints saved: [N]
- Validation iterations: [N]

**Next:** Stakeholder review hoan tat → Go-Live!
Hoac fix issues neu con findings.
Dung `/status` de xem tong quan.
```

---

## Error Codes

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E005 | Agent timeout | Retry ×3 per agent |
| E007 | Cross-validation mismatch trong review | List mismatches, user quyết định |
| E009 | Critical/High findings PENDING sau 3 iterations | STOP, escalate |
| E010 | Auto-fix regression | STOP, escalate |
