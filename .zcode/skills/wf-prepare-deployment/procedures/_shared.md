# Shared Protocols — wf-prepare-deployment

> Cross-cutting protocols, state variables, fix rules, agent prompt templates
> được sử dụng bởi nhiều Phase trong wf-prepare-deployment.
> KHÔNG đọc file này standalone — chỉ load section cụ thể khi cần.

## Sections

- [State Variables Glossary](#state-variables-glossary)
- [Cross-Phase Data Flow](#cross-phase-data-flow)
- [Large Project Mode (LPM)](#large-project-mode-lpm)
- [Fix Rules đặc thù](#fix-rules-đặc-thù)
- [Token Limit Prevention](#token-limit-prevention)
- [Checkpoint Protocol](#checkpoint-protocol)
- [Agent Prompt Templates](#agent-prompt-templates)
- [Cross-File Write Conflict Avoidance](#cross-file-write-conflict-avoidance)

---

## State Variables Glossary

Các biến in-memory được set/đọc xuyên suốt skill execution.

| Variable | Set by Phase | Read by Phase | Description |
|----------|--------------|---------------|-------------|
| `$SCOPE` | Phase 0/1 | All | `all` / `deployment` / `user-guide` / `maintenance` |
| `$PROJECT_NAME` | Phase 1 | 2, 3a, 3b, 4, 4a, 5a (agent spawns) | Tên dự án từ registry |
| `$SYNC_RATE` | Phase 1 | 1 POST-GATE | Từ verify-sync.md hoặc registry — must >= 80% |
| `$TECH_STACK` | Phase 1 | 2, 4, 4a (agent spawns) | Tech stack từ registry |
| `$ARCHITECTURE_DIGEST` | Phase 2 (step 2.0b) | 2 (agent), fallback cho 4, 4a | Digest của P3-01 + infra-spec + database-design |
| `$FEATURE_DIGEST` | Phase 3a (step 3a.1b) | 3a (agent) | Digest của feature specs + UX + dept docs |
| `$LARGE_PROJECT` | Phase 1 (step 1.6b) | 1, 2, 3a, 4a, 5a | Boolean — `systems>=5 OR depts>=10 OR reqs>=50 OR features>=40` |
| `$LPM_PARAMS` | Phase 1 (step 1.6b) | 1, 2, 3a, 4a, 5a | Object `{compression_threshold, digest_size, skeleton_threshold, output_targets}` |
| `$CONTEXT_PERCENT` | Every phase | Every phase | Context budget usage — trigger checkpoint at 65/80/90% |
| `$AGENTS_SPAWNED` | Every phase | Output Report | Array — log agents đã spawn (name, phase, status) |
| `$RESUME_MODE` | Phase 0 (flag handler) | 2, 3a, 4a, 5a (skip-if-exists checks) | Boolean — true nếu `--resume` flag |
| `error_log[]` | All phases | Output Report | Array errors collected — dùng cho Auto-Correction Loop + report |

---

## Cross-Phase Data Flow

```
Phase 0 (flags)        → $SCOPE, $RESUME_MODE
Phase 1 (prereq+plan)  → $PROJECT_NAME, $SYNC_RATE, $TECH_STACK,
                         $LARGE_PROJECT, $LPM_PARAMS,
                         prepare-deployment-status.json, prepare-deployment-plan.md
Phase 2 (deploy-guide) → deployment-guide.md (Muc 1-8), $ARCHITECTURE_DIGEST
Phase 3a (user-guide)  → user-guide.md, $FEATURE_DIGEST
Phase 3b (acc-mgmt)    → deployment-guide.md (Muc 9) — append
Phase 3c (checkpoint)  → checkpoint.json
Phase 4 (maintenance)  → deployment-guide.md (Muc 10) — append
Phase 4a (runbook)     → incident-response-runbook.md
Phase 5 (crossval)     → auto-fix results (in-place patches)
Phase 5a (review)      → stakeholder-review.md (Phan A/B/C/D)
```

**Quy tắc:** Mỗi phase chỉ READ variables đã được SET ở phase trước. KHÔNG được SET lại variables của phase khác.

---

## Large Project Mode (LPM)

> Protocol 6.6 — Khi `$LARGE_PROJECT = true`: áp dụng compression/skeleton sớm hơn, checkpoint dày hơn.

**Trigger (Phase 1 step 1.6b):**
```
systems.length >= 5 OR depts.length >= 10 OR requirements.length >= 50 OR features.length >= 40
```

**Parameter overrides:**

| Tham số | Standard | LPM | Dùng tại |
|---------|----------|-----|----------|
| `compression_threshold` | > 3 files | > 2 files | Phase 2 (architecture digest), Phase 3a (feature digest) |
| `digest_size` | ~200 từ/file | ~300 từ/file (Extended) | Phase 2, Phase 3a |
| `skeleton_threshold` | > 3000 từ | > 2000 từ | Phase 2 (deployment-guide SKELETON-FIRST), Phase 3a (user-guide skeleton) |
| `output_targets_deploy` | 2000–3500 từ | 3500–5500 từ | Phase 2 agent |
| `output_targets_user` | 1500–2500 từ | 2500–4000 từ | Phase 3a agent |
| `output_targets_runbook` | 1000–1500 từ | 1500–2500 từ | Phase 4a agent |
| `checkpoint_strategy` | Per major phase | Per EVERY phase | Phase 1, 3c, 4, 4a, 5, 5a |

---

## Fix Rules đặc thù

| Error Type | Auto-Fix Strategy | Escalate If |
|-----------|-------------------|-------------|
| `missing_file` | Re-generate file từ source docs | Source docs unavailable |
| `incomplete_doc` | Re-run generation step với instruction bổ sung | Still incomplete sau 3 retries |
| `invalid_reference` | Fix path/link references | Cannot locate referenced file |
| `missing_section` | Add missing section từ template | Template unavailable |
| `inconsistent_content` | Re-sync từ architecture/feature docs | Source docs conflicting |
| `env_mismatch` (E011) | KHÔNG auto-fix — hiển thị bảng so sánh env vars | Luôn escalate (manual review) |

> Mỗi error PHẢI được log vào `error_log[]`. Error log được include trong Output Report.
> **Retry:** Mỗi step retry tối đa 3 lần. Nếu vẫn fail → escalate với thông báo đầy đủ.

---

## Token Limit Prevention

> Protocol 6 — Áp dụng cho Phase 2, 3a, 4, 4a.

### §Input Compression (Protocol 6.2)

```
Trước khi spawn devops/tech-writer/sre agents:
  IF input_files.length > $LPM_PARAMS.compression_threshold (Standard: 3, LPM: 2):
    FOR each input_file:
      → Grep key sections: headers, REQ-IDs, endpoints, environments, services
      → Tạo digest entry (~$LPM_PARAMS.digest_size từ — Standard: 200, LPM: 300)
    → Cache in-memory: digest
    → Agent đọc file gốc CHỈ KHI cần chi tiết cụ thể
  ELSE:
    → Skip compression, agent nhận file paths trực tiếp
```

### §Skeleton-First (Protocol 6.5)

Áp dụng cho deployment-guide.md (Phase 2) và user-guide.md (Phase 3a, nếu LPM).

```
IF estimated_output_size > $LPM_PARAMS.skeleton_threshold:
  Pass 1: spawn agent → tạo SKELETON
    - Section headers + 1-2 câu intro/section
    - ~500-600 từ total
    - Không fill chi tiết
  → Write file

  Pass 2: spawn agent → ĐIỀN CHI TIẾT từng section
    - Đọc skeleton, expand mỗi section theo minimum thresholds
    - Output full doc theo output_targets

ELSE (Standard mode HOẶC output <= threshold):
  → Spawn agent trực tiếp (1 pass)
```

### §Architecture Digest Re-use

```
Phase 2 step 2.0b:
  IF test -f .mc-data/docs/_meta/design-input-digest.json:
    → Load digest (đã tạo bởi /wf-design Phase 3 POST-GATE)
    → Set $ARCHITECTURE_DIGEST từ file này
  ELSE (Fallback — Protocol 6.2):
    → Grep key sections từ P3-01, infra-spec, database-design, registry
    → Tạo digest trong memory (~200-300 từ)
    → Set $ARCHITECTURE_DIGEST
```

---

## Checkpoint Protocol

> Save checkpoint theo chiến lược LPM hoặc Standard.

### §Trigger Conditions

| Context % | Standard | LPM |
|-----------|----------|-----|
| >= 65% | Log warning, continue | **SAVE CHECKPOINT** |
| >= 80% | **SAVE CHECKPOINT** + giảm parallel | **SAVE CHECKPOINT** + giảm parallel |
| >= 90% | **FORCE STOP** — resume với `--resume` | **FORCE STOP** |

### §Phase-Based Triggers

| Phase | Checkpoint khi | Standard | LPM |
|-------|---------------|----------|-----|
| 1 | Prereq + plan validated | — | YES |
| 3c | Sau Phase 2+3a+3b | YES | YES |
| 4 | Muc 10 written | — | YES |
| 4a | Runbook created | — | YES |
| 5 | Cross-validation done | — | YES |
| 5a | Stakeholder review done | YES | YES |

### §Checkpoint Write Protocol

```
1. READ template: `templates/checkpoint.json`
2. POPULATE fields:
   - checkpoint_id: "CHK-DEPLOY-$(date +%Y%m%d)-NNN"
   - timestamp: ISO 8601
   - trigger.reason: "context_limit | phase_complete | error"
   - trigger.context_used_pct: $CONTEXT_PERCENT
   - trigger.phase_completed: <phase number>
   - position.current_phase: <next phase>
   - progress.phases_completed[]: append current phase
   - progress.docs_created[]: append file paths
   - context_digest: deployment_session_summary, deployment_decisions,
                     docs_generated, key_architecture_context, gotchas_and_warnings
3. WRITE: `.mc-data/work/wf-prepare-deployment/checkpoint.json` (atomic)
4. Verify: `jq '.' checkpoint.json` passes
```

### §Resume Logic

```
IF $ARGUMENTS chứa "--resume":
  1. READ checkpoint.json
  2. Inject context_digest vào in-memory state
  3. SCAN .mc-data/docs/phase6-deployment/ — xác định files đã tạo:
     - deployment-guide.md tồn tại + non-empty → Phase 2 done
     - user-guide.md tồn tại + non-empty → Phase 3a done
     - deployment-guide.md chứa "## 9" → Phase 3b done
     - deployment-guide.md chứa "## 10" → Phase 4 done
     - incident-response-runbook.md tồn tại + non-empty → Phase 4a done
     - stakeholder-review.md tồn tại + non-empty → Phase 5a done
  4. Set $RESUME_MODE = true
  5. Update next_phase dựa trên filesystem THỰC TẾ (không chỉ dùng checkpoint)
  6. Log: "Reconciled: tìm thấy [N]/4 files trên disk — tiếp tục từ Phase [X]"
  7. CONTINUE từ phase chưa hoàn thành
```

---

## Agent Prompt Templates

### P2-DEVOPS — Deployment Guide Muc 1-8

```
Ban la devops. Tao Deployment Guide cho $PROJECT_NAME.

Context:
- Architecture digest: $ARCHITECTURE_DIGEST
  (tech stack, environments, services, endpoints, migration strategy)
- Neu can chi tiet cu the ve mot section, doc file goc tai path — chi section can thiet:
  * P3-01: `.mc-data/docs/phase3-architecture/P3-01-architecture.md`
  * Infra: `.mc-data/docs/phase3-architecture/technical-specs/infra-spec.md`
  * Database: `.mc-data/docs/phase3-architecture/technical-specs/database-design.md`

Task: Tao `.mc-data/docs/phase6-deployment/deployment-guide.md` (Muc 1-8)

BAT BUOC — Template: Doc va tuan thu CHINH XAC cau truc tu
  `.claude/doc-framework/phase6-deployment/deployment-guide.md`

Noi dung (Muc 1-8):
  1. Yeu cau he thong
  2. Moi truong (dev/staging/prod)
  3. Quy trinh deploy
  4. CI/CD pipeline
  5. Rollback strategy
  6. Migration commands (tu database-design.Muc5)
  7. Monitoring & Alerting
  8. Checklist go-live

Quality: Non-empty, Actionable steps, Khong co TODO/TBD.

(Protocol 6.5 — Skeleton-first):
  Neu output uoc luong > $LPM_PARAMS.skeleton_threshold:
    Pass 1: Tao skeleton (8 Muc headers + 2-3 cau mo ta scope/Muc, ~600 tu) → write file truoc
    Pass 2: Dien chi tiet lan luot tung Muc (Muc 1 → Muc 8) → update file
  Dam bao cac Muc cuoi khong bi truncate do context limit.

Output muc tieu: $LPM_PARAMS.output_targets_deploy.
Moi Muc suc tich, step-by-step, khong thua.
```

### P3a-TECHWRITER — User Guide

```
Ban la tech-writer. Tao User Guide cho $PROJECT_NAME.

Context:
- Features: $FEATURE_DIGEST.features (hoac list)
- UX (neu co): $FEATURE_DIGEST.ux (screen groups)
- Departments: $FEATURE_DIGEST.departments
- P1-01 (actors, yeu cau chat luong): $FEATURE_DIGEST.p1_01
- P1-02 (luong KD): $FEATURE_DIGEST.p1_02
- [dept].md Phan B (TO-BE workflow): $FEATURE_DIGEST.dept_workflows

Neu can chi tiet cu the ve mot section, doc file goc tai path — chi section can thiet.

Task: Tao `.mc-data/docs/phase6-deployment/user-guide.md`

BAT BUOC — Template: `.claude/doc-framework/phase6-deployment/user-guide.md`

Noi dung:
  - Muc 3 (Theo vai tro): actors tu P1-01.Muc5 → role-based guide
  - Muc 4 (Theo quy trinh): luong KD tu P1-02.Muc3 + TO-BE workflow tu [dept].md (Phan B)
                           → end-to-end workflow guide
  - Muc 7 (FAQ): yeu cau chat luong tu P1-01.Muc9 → cau hoi hieu nang

Quality: Ngon ngu de hieu cho non-technical users, Screenshots placeholders, Khong co TODO/TBD.

(Protocol 6.5 — Skeleton-first):
  Neu LPM=True VA output uoc luong >2000 tu (nhieu systems/roles):
    Pass 1: Tao skeleton (section headers + 1-2 cau/section) → write file truoc
    Pass 2: Dien chi tiet tung section → update file

Output muc tieu: $LPM_PARAMS.output_targets_user.
Ngon ngu don gian, co examples.
```

### P3b-TECHWRITER — Account Management Muc 9

```
Ban la tech-writer. Viet Muc 9 Account Management cho $PROJECT_NAME.

Context:
- P3-01 Muc 8.1: [RBAC roles]
- P1-01 Muc 5: [actors]
- Auth features: [auth specs neu co]

Task: Viet Muc 9 (Account Management) vao
  `.mc-data/docs/phase6-deployment/deployment-guide.md` (append, khong ghi de Muc 1-8)
  - Roles tu P3-01.Muc8.1
  - Actors tu P1-01.Muc5
  - Auth flow tu auth feature specs

BAT BUOC — Template (Muc 9): `.claude/doc-framework/phase6-deployment/deployment-guide.md`

Quality: Ngon ngu de hieu cho non-technical users, Khong co TODO/TBD.

Output muc tieu: ~500–800 tu.
Suc tich, du y, khong lap context da biet.
```

### P4-DEVOPS+TECHWRITER — Maintenance Muc 10

```
Ban la devops + tech-writer. Viet Muc 10 Maintenance Guide cho $PROJECT_NAME.

Context:
- Deployment Guide: da co (Muc 1-9)
- Architecture: P3-01
- Infra: infra-spec.md

Task: Viet Muc 10 (Maintenance) vao
  `.mc-data/docs/phase6-deployment/deployment-guide.md` (append)

BAT BUOC — Template (Muc 10): `.claude/doc-framework/phase6-deployment/deployment-guide.md`

Noi dung:
  - Backup & Restore
  - Database maintenance
  - Log management
  - Performance monitoring
  - Scaling
  - Security updates
  - Troubleshooting
  - Upgrade procedures
  - SLA & Support levels

Quality: Non-empty, Actionable procedures, Khong co TODO/TBD.

Output muc tieu: ~800–1200 tu.
Suc tich, du y, khong lap context da biet.
```

### P4a-SRE — Incident Response Runbook

```
Ban la SRE (Site Reliability Engineer). Tao Incident Response Runbook cho $PROJECT_NAME.

Context:
- Deployment Guide: deployment-guide.md (Muc 1-10)
- Architecture: P3-01
- Infra: infra-spec.md
- Tech Stack: $TECH_STACK

Task: Tao `.mc-data/docs/phase6-deployment/incident-response-runbook.md`

BAT BUOC — Template: Doc va tuan thu CHINH XAC cau truc tu
  `.claude/doc-framework/phase6-deployment/incident-response-runbook.md`

Noi dung:
  - Phan loai muc do (P0-P3)
  - Doi phan hoi theo severity
  - Quy trinh 5 buoc
  - Communication templates
  - Escalation matrix
  - On-Call checklist
  - Monitoring dashboards & alerts

Quality:
  - Non-empty, Actionable procedures, Khong co TODO/TBD
  - Phu hop voi monitoring/alerting trong deployment-guide Muc 10

Output muc tieu: $LPM_PARAMS.output_targets_runbook.
Focused on actionable steps.
```

### P5a-DEVOPS — Stakeholder Review Phan B + Phan D

```
Ban la DevOps engineer. Thuc hien Stakeholder Review cho Phase 6 Deployment.

Context: Tat ca deployment docs + infra-spec + architecture

Tasks:
1. Phan B: Ra soat xuyen docs trien khai
   - Xung dot configs
   - Deployment vs infra mismatch
   - User guide vs features

2. Phan D: Phan tich thieu sot
   - Rollback
   - Monitoring
   - Security hardening
   - DR (Disaster Recovery)
   - SLA

BAT BUOC — Template: `.claude/doc-framework/phase6-deployment/stakeholder-review.md`
  (Phan B va Phan D)

Quality:
  - Actionable findings
  - Severity classification (Critical/High/Medium/Low)
  - No TODO/TBD
```

### P5a-QALEAD — Stakeholder Review Phan C

```
Ban la QA Lead. Thuc hien Consistency Check cho Phase 6 Deployment.

Context: Tat ca deployment docs + Phase 2 architecture + Phase 3 implementation

Tasks:
1. Phan C: Kiem tra nhat quan
   - Phase 2 architecture alignment
   - Phase 3 implementation coverage
   - Environments, versions

BAT BUOC — Template: `.claude/doc-framework/phase6-deployment/stakeholder-review.md`
  (Phan C)

Quality:
  - Actionable findings
  - Severity classification (Critical/High/Medium/Low)
  - No TODO/TBD
```

### P5a-CERTIFIER — Production Readiness Certification

```
Ban la Integration Certifier. Danh gia Production Readiness cho deployment.

Context: Tat ca deployment docs + infra-spec + architecture + implementation

Tasks:
- Kiem tra integration points: tat ca external dependencies co fallback/retry
- Kiem tra deployment checklist: rollback plan, health checks, smoke tests
- Kiem tra monitoring: alerts, dashboards, on-call runbook
- Kiem tra security: secrets management, network policies, access controls
- Verdict: CERTIFIED / NEEDS WORK (voi danh sach blocking items)

Output:
  Tra ve certification report — merge vao stakeholder-review.md (phan Production Readiness)

Quality:
  - Evidence-based assessment
  - Blocking items phai actionable
  - No TODO/TBD
```

### P5a-REALITY — Final Reality Check

```
Ban la Reality Checker. Kiem tra thuc te cuoi cung truoc production.

Context: Tat ca deployment docs + integration-certifier report + stakeholder review

Tasks:
- Mac dinh NEEDS WORK — yeu cau bang chung ap dao de PASS
- Kiem tra: tat ca docs co consistent khong, co gaps khong
- Kiem tra: deployment steps co reproducible khong (co the chay lai tu dau)
- Kiem tra: rollback plan co thuc su hoat dong khong (khong chi ly thuyet)
- Kiem tra: monitoring va alerting da configured chua
- Verdict: READY / NEEDS WORK (voi blocking items cu the)

Output:
  Tra ve reality check report — append vao stakeholder-review.md

Quality:
  - Evidence-based
  - Ngan chan premature production releases
```

---

## Cross-File Write Conflict Avoidance

> Phase 2, 3b, 4 đều ghi vào `deployment-guide.md`. Cần tránh race condition.

**Quy tắc:**

1. **Phase 2** — tạo file từ đầu với Muc 1-8 (write)
2. **Phase 3b** — PRE-GATE check Phase 2 DONE → **Edit** (append Muc 9)
3. **Phase 4** — PRE-GATE check Phase 3b DONE → **Edit** (append Muc 10)

**KHÔNG BAO GIỜ:**
- Spawn Phase 2 và Phase 3b đồng thời
- Spawn Phase 3b và Phase 4 đồng thời
- Dùng Write (ghi đè) cho Phase 3b hoặc Phase 4 — phải dùng Edit (append)

**Phase 2 và Phase 3a song song an toàn** vì ghi vào FILE KHÁC NHAU:
- Phase 2 → `deployment-guide.md`
- Phase 3a → `user-guide.md`
