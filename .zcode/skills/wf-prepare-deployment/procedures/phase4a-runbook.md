# Phase 4a: Incident Response Runbook

> Tạo `incident-response-runbook.md` — SRE playbook cho incident management.
> **SEQUENTIAL** — chạy sau Phase 4 (cần context Muc 10 Monitoring).

**PRE-GATE:**
- [ ] `test -s .mc-data/docs/phase6-deployment/deployment-guide.md`
- [ ] Muc 10 đã có (Phase 4 DONE)

**INPUT:**

| File | Path | Mục đích |
|------|------|----------|
| Deployment guide | `.mc-data/docs/phase6-deployment/deployment-guide.md` | Context deploy + monitoring + maintenance |
| Architecture | `.mc-data/docs/phase3-architecture/P3-01-architecture.md` | Services, dependencies cho incident triage |
| Infra spec | `.mc-data/docs/phase3-architecture/technical-specs/infra-spec.md` | Monitoring, alerting, infrastructure |
| Registry | `.mc-data/docs/_meta/req-registry.json` | Systems list, tech stack |
| Template | `.claude/doc-framework/phase6-deployment/incident-response-runbook.md` | Cấu trúc bắt buộc |

**OUTPUT:** `.mc-data/docs/phase6-deployment/incident-response-runbook.md`

---

## Reference Sections

- `_shared.md` §Agent Prompt Templates → P4a-SRE
- `_shared.md` §Token Limit Prevention
- `_shared.md` §Large Project Mode

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 4a.0 | **[SKIP-IF-EXISTS]** `IF test -f incident-response-runbook.md && test -s` → SKIP Phase 4a, log | Skip flag hoặc continue |
| 4a.1 | Đọc `deployment-guide.md` (Muc 7 Monitoring + Muc 10 Maintenance) + P3-01 + infra-spec | Context loaded |
| 4a.2 | Spawn `sre` agent với prompt P4a-SRE | Agent success |
| 4a.3 | Verify `incident-response-runbook.md` được tạo theo template | `test -s runbook.md` |
| 4a.4 | **LPM CHECKPOINT** — Nếu `$LARGE_PROJECT=true`: SAVE CHECKPOINT sau Phase 4a (all deployment docs created) | Checkpoint saved |

---

## §Agent Spawn (Step 4a.2)

**Prompt:** Xem `_shared.md §Agent Prompt Templates → P4a-SRE`.

**Substitutions:**
- `$PROJECT_NAME` → tên dự án
- `$TECH_STACK` → từ registry
- `$LPM_PARAMS.output_targets_runbook` → Standard: "1000–1500 tu", LPM: "1500–2500 tu"

---

## POST-GATE

- [ ] `test -s .mc-data/docs/phase6-deployment/incident-response-runbook.md` — file non-empty
- [ ] **[Protocol 10 — T2]** Required sections present:
  ```bash
  grep -cE "^## (Phan loai|Severity|Doi phan hoi|Quy trinh|Communication|Escalation|On-Call|Monitoring)" runbook.md >= 5
  ```
- [ ] **[Protocol 10 — T3]** Word count adequate:
  ```bash
  wc -w runbook.md >= 800
  ```
- [ ] Service names trong runbook phải match P3-01:
  ```bash
  # Grep service names tu P3-01 Muc 4 (Services)
  # Verify cac names xuat hien trong runbook.md
  ```
- [ ] Nếu FAIL → re-run `sre` agent (max 3 retries)

**Next phase:** `phase5-crossval.md`

---

## Auto-Correction

Tương tự Phase 2/3a:
1. Iteration 1-3: Re-run với instruction bổ sung
2. Sau 3 lần → E009, escalate

---

## Error Codes

Kế thừa từ phase2-deployment-guide.md (E005, E006, E009).
