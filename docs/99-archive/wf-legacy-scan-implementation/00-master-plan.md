# 00 — Master Plan: Dependency Graph & Timeline

> **Đọc trước:** [README.md](README.md)
> **Đọc tiếp:** [01-session-protocol.md](01-session-protocol.md), sau đó [phases/phase-A-design-closure.md](phases/phase-A-design-closure.md)

---

## 1. Dependency Graph (Phase-Level)

```
                    ┌─────────────────┐
                    │  A: Design      │  2-3 ngày
                    │  Closure        │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  B: Foundation  │  2-3 ngày
                    │  (scan-state,   │
                    │  session, lib)  │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  C: Profiles    │  3-4 ngày
                    │  + IPS + VN     │
                    │  Python module  │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  D: Agents      │  4-5 ngày  ← Critical (backward-compat)
                    │  + Sub-skill    │
                    │  Migration      │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
 ┌───────▼──────┐   ┌────────▼──────┐   ┌────────▼──────┐
 │ E: Checkpt/  │   │ F: Impact/    │   │ G: Bash       │
 │ Concurrency/ │   │ Incremental   │   │ Refactor      │
 │ Cache (3-4d) │   │ (2d)          │   │ (2-3d)        │
 └───────┬──────┘   └────────┬──────┘   └────────┬──────┘
         │                   │                   │
         └──────────┬────────┴───────────────────┘
                    │
           ┌────────▼────────┐
           │  H: Resume      │  1 ngày
           │  Routing        │
           └────────┬────────┘
                    │
           ┌────────▼────────┐
           │  I: Integration │  3-5 ngày
           │  + Testing      │
           └────────┬────────┘
                    │
           ┌────────▼────────┐
           │  J: Migration   │  1-2 ngày
           │  + Docs         │
           └─────────────────┘

TOTAL sequential: 23-32 ngày
TOTAL with parallel E/F/G: 19-26 ngày
```

---

## 2. Timeline Chi Tiết

### 2.1 Scenario 1 — Single Implementer (Sequential, 23-32 ngày)

| Tuần | Ngày | Phase | Highlights |
|------|------|-------|------------|
| **W1** | 1-3 | A: Design Closure | Sign-off 17 ADRs, tạo fixtures baseline, contract draft |
| W1-W2 | 4-6 | B: Foundation | scan-state.json, session mgmt, bash shared library skeleton |
| **W2** | 7-10 | C: Profiles + IPS + VN | Profile resolver, IPS Python module, VN keyword pool |
| W2-W3 | 11-15 | D: Agents + Sub-migration | **CRITICAL** — backward-compat lock verify, sub-skill helper migration |
| **W3** | 16-19 | E: Checkpoint + Concurrency + Cache | 4-level checkpoint, token bucket, scan cache |
| W4 | 20-21 | F: Impact + Incremental | impact-graph.json, delta processing, Workload Gate WARN |
| W4 | 22-24 | G: Bash Refactor | Refactor 5 scripts với shared library |
| W4 | 25 | H: Resume Routing | 4-level Resume Router |
| **W5** | 26-30 | I: Integration + Testing | E2E test trên 3 fixtures, crash injection, backward-compat verify |
| W5 | 31-32 | J: Migration + Docs | User guide, CLAUDE.md update, release |

### 2.2 Scenario 2 — Parallel E/F/G (19-26 ngày)

Với 2+ implementer, sau Phase D:

```
Day 15 | Phase D completed
       ↓
Day 16 | E starts │ F starts │ G starts  ← 3 implementer parallel
       ↓          ↓          ↓
Day 19 | E done  │ F done   │ G ongoing
Day 21 |                     G done
       ↓
Day 22 | Phase H starts (sequential)
...
```

Tiết kiệm 4-6 ngày.

---

## 3. Milestones & Git Tags

| Milestone | Tag | Ngày dự kiến | Blocker để release |
|-----------|-----|--------------|---------------------|
| Design approved | `design-legacy-scan-v2.1-approved` | End W1 | 17 ADRs sign-off + 3 fixtures baseline |
| Foundation ready | `v5.0-phase-B` | End W1 | scan-state template + session infra + lib skeleton |
| Profiles + IPS operational | `v5.0-phase-C` | Mid W2 | IPS Python module + VN keyword pool test pass |
| **Backward-compat verified** | `v5.0-phase-D` | End W2 | **Standard profile output ≈ v4.1 trên 3 fixtures** |
| Reliability features | `v5.0-phase-E` | Mid W3 | Crash injection test pass (mất ≤1 unit) |
| Downstream integration | `v5.0-phase-F` | Late W3 | impact-graph.json consume được bởi wf-verify-sync |
| Scripts refactored | `v5.0-phase-G` | End W3 | jq validation 100%, duplicate lines = 0 |
| Resume operational | `v5.0-phase-H` | W4 day 1 | 4-level resume test (phase/layer/batch/intra-batch) |
| E2E validated | `v5.0-phase-I` | Mid W5 | Compliance audit + all fixtures pass |
| Release ready | `v5.0.0` | End W5 | Docs published, CLAUDE.md updated |

---

## 4. Critical Path Analysis

**Critical path:** A → B → C → D → I → J (18-22 ngày)

**Phase D là cột mốc quan trọng nhất** vì:
- Backward-compat lock ADR-LS06 (standard = v4.1) phải verify.
- Sub-skill migration (v2.1 new) chưa từng test.
- Sai ở đây → downstream phases không quyết định được.

**Mitigation:**
- Phase D có 4-5 ngày (nhiều nhất).
- Dành 1 ngày đầu chỉ để run v4.1 trên 3 fixtures và lock baseline output.
- Golden test compare phải PASS trước khi continue Phase E/F/G.

---

## 5. Resource Requirements

### 5.1 Skills Required

| Phase | Skill cần | Đóng góp ai |
|-------|-----------|-------------|
| A | DEVKIT architecture review | Owner + core team |
| B | Bash + JSON schema | DevOps |
| C | Python (pytest) + JSON + VN language | Python dev + VN speaker |
| D | Agent architecture + backward-compat testing | Senior dev + QA |
| E | Concurrency + caching | Senior dev |
| F | Graph theory (impact graph) + git diff logic | Mid dev |
| G | Bash + cross-platform scripting | DevOps |
| H | State machine + error handling | Mid dev |
| I | QA + E2E testing | QA lead |
| J | Technical writing | Tech writer |

### 5.2 Tooling Required

- `jq` (all platforms) — bash JSON validation
- `python3` + `pytest` — IPS module + VN normalize
- `git` — version control + rollback
- `bash` ≥ 4.0 (Windows Git Bash OK)
- Claude Code CLI with Agent tool

### 5.3 Fixture Storage

3 fixtures = ~100MB:
- small-en: 50 files ≈ 5MB
- medium-vn: 500 files ≈ 30MB
- large-mixed: 1,500 files ≈ 60MB

Lưu tại `docs/design/skills/wf-legacy-scan/fixtures/` (gitignore content, commit structure + README).

---

## 6. Risk Register & Mitigation

| Rủi ro | Phase | Probability | Impact | Mitigation |
|--------|-------|-------------|--------|-----------|
| Backward-compat break (standard ≠ v4.1) | D | Medium | **HIGH** | Golden test PASS trước khi continue; fixture trước code |
| Sub-skill migration helper bug | D | Medium | High | Fallback path đọc ledger.json v4.1 legacy; unit test helper |
| IPS Python module chạy chậm | C | Low | Medium | Benchmark trên 1,500 files fixture — target ≤5s phase_b |
| VN keyword pool miss important domains | C | Medium | Medium | Phase I test trên 3 VN fixtures; iterate pool |
| Concurrency deadlock | E | Low | Medium | Timeout 300s/600s; queue max wait; emergency abort |
| Cache invalidation bug | E | Medium | Medium | Conservative TTL 14d; `--no-cache` fallback; clear invalidation rules |
| Cross-platform bash issue (Windows) | G | Medium | Medium | CI test Git Bash + WSL + Linux + macOS |
| Context overflow trên large fixture | I | Medium | Low | 4-level checkpoint + resume verify |
| Timeline slip | Any | Medium | Medium | Scenario 2 parallel E/F/G; defer non-critical if cần |

---

## 7. Parallel Execution Rules (CORE-025)

Khi chạy 2+ phases song song (E/F/G sau D):

1. **Write scope tách biệt:**
   - E ghi: `_shared/checkpoint/`, `_shared/concurrency/`, cache helpers
   - F ghi: `_shared/ips/workload_estimator.py`, impact graph logic, incremental helpers
   - G ghi: bash scripts + `legacy-scan-common.sh`
2. **Contract stable:** Template schemas + helper API signatures defined TRƯỚC khi parallel start.
3. **Re-verification sau merge:** Compliance audit + E2E fixture test sau merge 3 branches.

---

## 8. Phase Transition Gate

Mỗi phase chỉ được đóng (tag `v5.0-phase-<X>`) khi:

```
[ ] All tasks trong action plan = completed
[ ] Deliverable checklist = all green
[ ] Verify commands = pass
[ ] Rollback procedure = tested (dry run OK)
[ ] Compliance audit script pass (.claude/scripts/skill-compliance-audit.sh wf-legacy-scan)
[ ] No new critical issues in risk register
[ ] Session log updated in session-logs/
[ ] Git tag v5.0-phase-<X> created
[ ] MIGRATION-PROGRESS.md updated (nếu có)
```

---

## 9. Escalation Procedure

Khi gặp blocker:

1. **Level 1 — Design conflict:** Ghi issue trong phase plan, check với [08-tradeoffs-adr.md](../08-tradeoffs-adr.md). Nếu ADR cần revise → update ADR + bump design version v2.2.
2. **Level 2 — Timeline slip >50%:** Trigger parallel execution (Scenario 2) hoặc defer non-critical feature.
3. **Level 3 — Backward-compat break (Phase D):** STOP immediately. Revert branch. Fix root cause. Re-run golden test trước khi continue.
4. **Level 4 — CORE rule violation:** STOP. Consult Owner + core team. Không proceed cho đến khi có resolution.

---

## 10. Documentation Cadence

- **Per session:** Append vào `session-logs/YYYY-MM-DD-{N}.md`.
- **Per task complete:** Update status trong phase plan.
- **Per phase complete:** Update README.md status table + tag + session log summary.
- **Per week:** Review progress vs timeline; update risk register nếu có new issue.
- **End of project:** Full release notes + archive implementation plan to `archive/v5.0/`.

---

## 11. Next Action

**Bước kế tiếp:** Đọc [01-session-protocol.md](01-session-protocol.md) để hiểu cách làm việc mỗi session, sau đó mở [phases/phase-A-design-closure.md](phases/phase-A-design-closure.md) và thực hiện từ Action 1.
