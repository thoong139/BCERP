# Shared Protocols — wf-migrate-module v1.1

> Cross-cutting protocols, state variables, safe-write rules, expert selection map
> duoc su dung boi nhieu Phase trong wf-migrate-module.
> KHONG doc file nay standalone — chi load section cu the khi can.

## Sections

- [State Variables Glossary](#state-variables-glossary)
- [Cross-Phase Data Flow](#cross-phase-data-flow)
- [Session Isolation (CORE-030)](#session-isolation-core-030)
- [LEGACY_MODE Detection & Injection (CORE-021/022)](#legacy_mode-detection--injection-core-021022)
- [Registry Safe-Write Rules (CORE-006)](#registry-safe-write-rules-core-006)
- [CDG — Critical Decision Gates](#cdg---critical-decision-gates)
- [Auto-Approve Mode](#auto-approve-mode)
- [Sub-Skill Invocation Pattern](#sub-skill-invocation-pattern)
- [Sub-Skill Pre-Flight Check](#sub-skill-pre-flight-check)
- [Rollback Protocol](#rollback-protocol)
- [CI-ROUTE: Code Intelligence Stages](#ci-route-code-intelligence-stages)
- [Automated Feature Parity (Phase 6)](#automated-feature-parity-phase-6)
- [Resume Logic & Routing](#resume-logic--routing)
- [CORE-026/028 Trace & Phase Summary](#core-026028-trace--phase-summary)
- [Cross-Validation Protocol](#cross-validation-protocol)
- [Fix Rules](#fix-rules)
- [Error Handling Matrix](#error-handling-matrix)

---

## State Variables Glossary

Cac bien in-memory duoc set/doc xuyen suot skill execution.

| Variable | Set by Phase | Read by Phase | Description |
|----------|--------------|---------------|-------------|
| `$MIGRATE_ID` | Phase 0 | Moi phase | Format: `MIG-YYYYMMDD-NNN` |
| `$SESSION_DIR` | Phase 0 | Moi phase | `.mc-data/work/wf-migrate-module/$MIGRATE_ID/` |
| `$SCAN_SESSION_ID` | Phase 0 (args) | 0, 1 | Session ID cua wf-scan-target |
| `$SCAN_SESSION_DIR` | Phase 0 | 0, 1 | `.mc-data/work/wf-scan-target/sessions/$SCAN_SESSION_ID/` |
| `$TARGET_SYSTEM` | Phase 0 (args) | Moi phase | System ID dich (VD: `SYS-BACKEND`) |
| `$TARGET_MODULE` | Phase 0 (args) | Moi phase | Module ID dich (VD: `MOD-CRM`) |
| `$USER_PROMPT` | Phase 0 (args) | 1 | Mo ta yeu cau cua nguoi dung |
| `$AUTO_APPROVE` | Phase 0 (args) | 1 | Boolean — true neu `--auto-approve` duoc pass |
| `$DRY_RUN` | Phase 0 (args) | 1 | Boolean — true neu `--dry-run` duoc pass, STOP sau Phase 1 |
| `$AUTO_ROLLBACK` | Phase 0 (args) | 6, 7 | Boolean — true neu `--auto-rollback` duoc pass, tu dong revert khi E017 |
| `$RESUME_TASK` | Phase 0 (args) | 6 | Integer — task number de resume tu task cu the trong Phase 6 |
| `$TASK_CHECKPOINT_INTERVAL` | Phase 0 | 6 | Integer — interval ghi checkpoint per task (default: 1 = moi task) |
| `$LEGACY_MODE` | Phase 0 | Moi phase | Boolean — true neu `project-context.md > 500 bytes` (CORE-021) |
| `$DEPRECATED_MODULES` | Phase 0 | 1 | Array module IDs co `action="DEPRECATE"` — loai khoi match |
| `$SKIP_PHASES` | Phase 0 (args) | 4, 5, 6 | Array phase names to skip |
| `$CI_CAPABILITIES` | Phase 0 | 1, 6 | Object `{gitnexus: bool, serena: bool}` — set tu CI detect |
| `$SOURCE_FEATURES` | Phase 1 | 2, 3 | Array features extracted tu scan docs + CI analysis |
| `$STRATEGY_MATRIX` | Phase 1 | 2, 3, 7 | `{feature: strategy}` — Keep/Redesign/Deprecate/Merge |
| `$ENTITY_MAPPING` | Phase 1 | 4, 6 | Array entity mappings cu → moi |
| `$REGISTRY_SNAPSHOT` | Phase 2 | 6, rollback | Snapshot registry sau khi add-scope |
| `$CODE_SNAPSHOTS` | Phase 6 | rollback | Array `{task_id, changed_files[], commit_hash?}` |
| `$PREFLIGHT_RESULTS` | Phase 0 | 2, 3, 4, 5, 6 | Object chua pre-flight check results per sub-skill |
| `$IMPLEMENT_RESULTS` | Phase 6 | 7 | Ket qua implement — tasks completed, parity check |
| `$CONTEXT_PERCENT` | Moi phase | Moi phase | Context budget — trigger checkpoint tai 65/80/90% |
| `error_log[]` | Moi phase | Phase 7 | Array errors — ghi vao migrate-report.md |
| `$ROLLBACK_SNAPSHOTS[]` | Phase 2, 6 | Phase 7 | Array snapshot metadata cho rollback-guide |

---

## Cross-Phase Data Flow

```
Phase 0 (intake)       → $MIGRATE_ID, $SESSION_DIR, $SCAN_SESSION_DIR,
                         $TARGET_SYSTEM, $TARGET_MODULE, $USER_PROMPT,
                         $AUTO_APPROVE, $CI_CAPABILITIES, $PREFLIGHT_RESULTS,
                         $LEGACY_MODE, $DEPRECATED_MODULES, $SKIP_PHASES,
                         migrate-status.json, index.json

Phase 1 (gap analysis) → $SOURCE_FEATURES, $STRATEGY_MATRIX, $ENTITY_MAPPING,
                         gap-analysis.md, strategy-matrix.md, entity-mapping.md,
                         CI code analysis (GitNexus + Serena),
                         CDG user duyet (hoac auto-approve skip)

Phase 2 (add-scope)    → $REGISTRY_SNAPSHOT (registry sau khi append),
                         Pre-flight check wf-add-scope,
                         Sub-skill: /wf-add-scope --from-scan

Phase 3 (define-feat)  → feature specs docs,
                         Pre-flight check wf-define-features,
                         Sub-skill: /wf-define-features --from-scan

Phase 4 (design)       → design docs,
                         Pre-flight check wf-design,
                         Sub-skill: /wf-design

Phase 5 (plan-modules) → task files,
                         Pre-flight check wf-plan-modules,
                         Sub-skill: /wf-plan-modules

Phase 6 (implement)    → $IMPLEMENT_RESULTS, $CODE_SNAPSHOTS[], code files,
                         Automated parity check per feature,
                         Pre-flight check wf-implement-feature,
                         Sub-skill: /wf-implement-feature

Phase 7 (report)       → migrate-report.md, phase-summary.md, rollback-guide.md
```

**Quy tac:** Moi phase chi READ variables da duoc SET o phase truoc. KHONG SET lai variables cua phase khac.

---

## Session Isolation (CORE-030)

Moi output cua skill duoc co lap theo session.

- `$MIGRATE_ID` generate tai Phase 0 (format: `MIG-YYYYMMDD-NNN`)
- `$SESSION_DIR = .mc-data/work/wf-migrate-module/$MIGRATE_ID/`
- Tat ca duong dan dang `.mc-data/work/wf-migrate-module/[file]` deu duoc hieu la `$SESSION_DIR/[file]`
- **Ngoai le:** `index.json` nam o root `.mc-data/work/wf-migrate-module/index.json`
- **Snapshots:** `$SESSION_DIR/snapshots/` — registry snapshots + changed-files lists

**Cau truc session:**

```
.mc-data/work/wf-migrate-module/
├── index.json                            # Session registry — root, khong per-session
└── $MIGRATE_ID/                          # = MIG-YYYYMMDD-NNN/
    ├── migrate-status.json               # Phase 0 — runtime state
    ├── gap-analysis.md                   # Phase 1 — ket qua phan tich gap
    ├── strategy-matrix.md                # Phase 1 — ma tran chien luoc
    ├── entity-mapping.md                 # Phase 1 — anh xa entity
    ├── checkpoint.json                   # moi phase — checkpoint
    ├── migrate-report.md                 # Phase 7 — bao cao tong ket
    ├── phase-summary.md                  # Phase 7 — tom tat tieng Viet
    ├── rollback-guide.md                 # Phase 7 — huong dan rollback
    ├── parity-check-{feature}.md         # Phase 6 — per-feature parity reports
    └── snapshots/                        # Rollback snapshots
        ├── registry-phase2-{timestamp}.json
        ├── changed-files-task{n}-{timestamp}.txt
        └── registry-phase6-task{n}-{timestamp}.json
```

---

## LEGACY_MODE Detection & Injection (CORE-021/022)

### Detection (CORE-021)

```bash
LEGACY_MODE=false
if test -f .mc-data/work/legacy-scan/project-context.md; then
  size=$(wc -c < .mc-data/work/legacy-scan/project-context.md)
  if [ "$size" -gt 500 ]; then
    LEGACY_MODE=true
  fi
fi
```

### Legacy Decisions Bridge (CORE-022)

Neu `$LEGACY_MODE == true`:
- Doc `.mc-data/work/wf-brainstorm/legacy-decisions.json`
- Set `$DEPRECATED_MODULES[]` = danh sach module co `action="DEPRECATE"`
- Loai bo moi feature thuoc `$DEPRECATED_MODULES` khoi `$SOURCE_FEATURES`

Neu file khong ton tai → WARNING, tiep tuc voi `$DEPRECATED_MODULES=[]`.

---

## Registry Safe-Write Rules (CORE-006)

`/wf-migrate-module` la **pure orchestrator** — role **NONE**, KHONG truc tiep ghi registry.

Sub-skills ghi theo role cua chung:

| Sub-skill | Field | Role |
|-----------|-------|------|
| `/wf-add-scope` | `modules[]`, `features[]` | APPEND |
| `/wf-define-features` | `features[]`, `impl_status` | PRIMARY / SAFE-UPDATE |
| `/wf-design` | `design_status` | PRIMARY |
| `/wf-plan-modules` | `implementation_order`, `impl_status` | PRIMARY / SAFE-UPDATE |
| `/wf-implement-feature` | `impl_status` | PRIMARY |

**Orchestrator chi doc registry de verify** — khong modify.

---

## CDG — Critical Decision Gates

### CDG-1: Strategy Confirmation (Phase 1)

```
SAU KHI AI de xuat strategy per feature:

NEU $AUTO_APPROVE == true:
  → Skip CDG-1. Dung AI-suggested strategy. Ghi log: "CDG-1: AUTO-APPROVED."
NEU $AUTO_APPROVE == false:
  AskUserQuestion:
    Header: "Chien luoc migration"
    Question: "AI de xuat chien luoc cho tung feature. Ban dong y hay muon chinh sua?"
    Options:
      - "Dong y het — tiep tuc"
      - "Xem chi tiet tung feature roi quyet dinh" → hien thi strategy matrix
      - "Toi muon tu quyet dinh strategy" → hoi tung feature mot
```

### CDG-2: Entity Mapping Confirmation (Phase 1)

```
SAU KHI AI de xuat entity mapping cu → moi:

NEU $AUTO_APPROVE == true:
  → Skip CDG-2. Dung AI-suggested entity mapping. Ghi log: "CDG-2: AUTO-APPROVED."
NEU $AUTO_APPROVE == false:
  AskUserQuestion:
    Header: "Entity mapping"
    Question: "AI de xuat anh xa entity cu sang moi. Ban dong y hay muon chinh sua?"
    Options:
      - "Dong y — tiep tuc"
      - "Xem chi tiet tung entity mapping"
      - "Toi muon chinh sua mapping"
```

### CDG-3: Scope Confirmation (sau Phase 1)

```
TRUOC KHI chay add-scope:

NEU $AUTO_APPROVE == true:
  → Skip CDG-3. Dung AI-suggested scope. Ghi log: "CDG-3: AUTO-APPROVED."
NEU $AUTO_APPROVE == false:
  AskUserQuestion:
    Header: "Xac nhan pham vi"
    Question: "Se seed [N] features vao registry. Tiep tuc?"
    Options:
      - "Tiep tuc" — chay Phase 2
      - "Thu hep pham vi" — chon features cu the
      - "Dung de xem lai" — STOP + checkpoint
```

---

## Auto-Approve Mode

Khi user pass `--auto-approve` flag:

1. **Skip tat ca CDG gates** (CDG-1, CDG-2, CDG-3)
2. **Dung AI-suggested strategy** — khong hoi user duyet
3. **Van ghi log** moi quyet dinh vao `migrate-status.json.flags.auto_approved = true`
4. **Van tao checkpoint** sau moi phase de co the resume + audit

**When to use:** Module don gian (vai CRUD), module da co design san, hoac user muon chay nhanh de xem ket qua.

**When NOT to use:** Module phuc tap (>10 features), module co business logic nhieu, LEGACY_MODE (can user duyet deprecate).

---

## Sub-Skill Invocation Pattern

Moi lan goi sub-skill, tuan theo pattern:

```
1. PRE-FLIGHT: Doc _contract.json cua sub-skill de xac nhan input/output paths + args compatibility
2. Build argument string voi cac flag can thiet
3. Invoke Skill tool voi skill name + args
4. Doi ket qua
5. Verify output files ton tai (POST-GATE T1)
6. Doc ket qua (neu can)
7. Luu checkpoint
```

**Quy tac:**
- KHONG invoke sub-skill parallel (sequential dependency)
- LUON chay pre-flight check truoc moi sub-skill invocation
- LUON verify output sau moi sub-skill
- Neu sub-skill fail → retry 1 lan → neu van fail → checkpoint + STOP

---

## Sub-Skill Pre-Flight Check

**Truoc moi lan goi sub-skill** (Phase 2-6), chay pre-flight:

| Step | Action | Verify |
|------|--------|--------|
| PF.1 | Doc `_contract.json` cua sub-skill tu `.claude/skills/workflow/[sub-skill]/_contract.json` | File exists |
| PF.2 | Xac minh sub-skill `inputs[]` — tat ca `required: true` inputs co du lieu san | Khong missing |
| PF.3 | Xac minh sub-skill `prerequisites.required_files[]` ton tai | Files exist |
| PF.4 | Xac minh sub-skill version tuong thich (MAJOR version match expected) | Version OK |
| PF.5 | Neu mismatch → **E016**: ghi log + hoi user — "Sub-skill [name] da thay doi. Tiep tuc hay dung?" | User confirmed |

**Neu pre-flight fail:**
- Ghi vao `$PREFLIGHT_RESULTS[sub_skill] = {status: "fail", reason: ...}`
- Hoi user — continue (risk) hoac STOP

---

## Rollback Protocol

### Snapshot Creation

| Trigger | Snapshot | Vi tri |
|---------|----------|--------|
| Phase 2 — sau khi add-scope | `registry-phase2-{ts}.json` | `$SESSION_DIR/snapshots/` |
| Phase 6 — truoc moi task | `registry-phase6-task{n}-{ts}.json` | `$SESSION_DIR/snapshots/` |
| Phase 6 — sau moi task | `changed-files-task{n}-{ts}.txt` | `$SESSION_DIR/snapshots/` |
| Phase 6 — sau moi task complete | `code-snapshot` (git diff) | `$SESSION_DIR/snapshots/` |

### Snapshot Format

```json
{
  "snapshot_id": "SNAP-{phase}-{timestamp}",
  "phase": "phase2 | phase6",
  "trigger": "post-add-scope | pre-task-{n} | post-task-{n}",
  "timestamp": "ISO8601",
  "registry_state": { "...": "full registry JSON copy" },
  "changed_files": ["path1", "path2"],
  "rollback_command": "cp snapshots/registry-...json .mc-data/docs/_meta/req-registry.json"
}
```

### Rollback Guide Generation (Phase 7)

Phase 7 doc `$ROLLBACK_SNAPSHOTS[]` → populate `templates/rollback-guide.md` → WRITE `$SESSION_DIR/rollback-guide.md`.

---

## CI-ROUTE: Code Intelligence Stages

CI tools duoc auto-detect tai Phase 0 (CI PRE-GATE). Khong hoi user.

| Stage | CI Task | Primary Tool | Fallback |
|-------|---------|-------------|----------|
| Phase 0 (Intake) | `ci_detect` | `bash .claude/scripts/ci-detect.sh` | Manual flag |
| Phase 1 (Gap Analysis) | `understand_target` | **GitNexus** `query` (target module) + **Serena** `find_symbol` | Grep + Read |
| Phase 1 (Gap Analysis) | `impact_check` | **GitNexus** `impact` (system dich) | Grep |
| Phase 1 (Gap Analysis) | `existing_code_search` | **Serena** `find_symbol` + `find_referencing_symbols` | Grep + Glob |
| Phase 6 (Implement) | `pre_edit_impact` | **GitNexus** `impact` + **Serena** `find_referencing_symbols` | Grep |
| Phase 6 (Implement) | `detect_changes` | **GitNexus** `detect_changes` | `git diff` |
| Phase 6 (Parity) | `compare_shapes` | **GitNexus** `shape_check` (API route response) | Manual Read |

### Phase 1 CI Integration (NEW — v1.1)

**Step 1.1a — CI Code Analysis (truoc khi spawn agents):**

```
1. Neu $GITNEXUS_AVAILABLE:
   a. gitnexus_query({query: "$TARGET_MODULE functionality", task_context: "migrating from legacy system", goal: "understand existing EUREKA code for gap analysis"})
   b. gitnexus_impact({target: "$TARGET_SYSTEM", direction: "downstream"}) — assess dependencies
   → Set $CI_SOURCE_ANALYSIS = {existing_processes: [...], affected_modules: [...]}

2. Neu $SERENA_AVAILABLE:
   a. find_symbol({name_path_pattern: "$TARGET_MODULE"}) — tim existing symbols
   b. find_referencing_symbols({name_path: "...", relative_path: "apps/backend/"})
   → Set $CI_EXISTING_SYMBOLS = [...]

3. NEU CI NOT AVAILABLE → fallback:
   Grep "$TARGET_MODULE" trong apps/backend/
   Glob "**/$TARGET_MODULE*.cs" trong apps/backend/
```

Output tu CI analysis duoc feed vao agent prompts o Step 1.2 de agents co context day du ve ca module cu VA code EUREKA hien co.

---

## Automated Feature Parity (Phase 6)

### Step 6.4 — Automated Parity Check (NEW — v1.1)

Sau moi feature implement, chay automated parity:

```
1. NEU strategy = "Keep":
   a. Doc response shape tu target-map.json (old API)
   b. Neu $GITNEXUS_AVAILABLE → gitnexus_shape_check({route: new_endpoint}) — so sanh response keys
   c. Neu $SERENA_AVAILABLE → find_symbol new endpoint → find_referencing_symbols de verify callers
   d. So sanh thu cong: entity fields, business rules, edge cases
   e. Ghi ket qua vao templates/parity-check.md → $SESSION_DIR/parity-check-{feature}.md

2. NEU strategy = "Redesign":
   a. Verify moi business rule trong gap-analysis.md co implementation tuong ung
   b. Verify entity mapping khop thuc te (entity-mapping.md vs actual code)

3. NEU strategy = "Merge":
   a. Verify khong trung lap API/entity voi module khac
   b. Verify references toi module goc van hoat dong
```

### Parity Verdict

| Dieu kien | Verdict | Hanh dong |
|-----------|---------|-----------|
| Tat ca muc PASS | PASS | Tiep tuc task tiep |
| PARTIAL 1-3 | PARTIAL | Ghi log + tiep tuc (non-blocking) |
| FAIL > 3 | FAIL | STOP + hoi user — E009 |
| FAIL > 5 | CRITICAL | Trigger rollback protocol |

---

## Auto-Rollback Protocol

Khi user pass `--auto-rollback` flag hoac E017 CRITICAL xay ra:

### Trigger Conditions

| Trigger | Condition | Action |
|---------|-----------|--------|
| `--auto-rollback` flag set + E017 | Parity >5 FAIL trong Phase 6 | Auto revert registry + code, KHONG hoi user |
| E017 WITHOUT `--auto-rollback` | Parity >5 FAIL | Hoi user — revert hoac tiep tuc |
| Manual rollback request | User goi rollback thu cong | Doc rollback-guide.md → thuc hien theo huong dan |

### Auto-Rollback Execution (Phase 6 Step 6.4b)

```
NEU $AUTO_ROLLBACK == true VA E017 triggered:

1. Xac dinh snapshot moi nhat:
   - Registry: snapshot gan nhat trong $SESSION_DIR/snapshots/registry-phase6-pre-*.json
   - Code: changed-files-task{n}-*.txt

2. Revert Registry:
   cp $SESSION_DIR/snapshots/registry-phase6-pre-{latest_ts}.json .mc-data/docs/_meta/req-registry.json
   → Verify: jq -e '.requirements | length > 0' registry

3. Revert Code (theo thu tu task):
   for file in $(cat $SESSION_DIR/snapshots/changed-files-task{latest_n}-*.txt); do
     git checkout -- "$file"
   done
   → Verify: git status — khong con uncommitted changes tu migration

4. Ghi log:
   { "phase": "phase6", "event": "AUTO_ROLLBACK", "trigger": "E017", "snapshots_used": [...], "files_reverted": [...] }

5. Cap nhat migrate-status.json:
   - status = "error"
   - phases.phase6.status = "rolled_back"
   - rollback.auto_triggered = true

6. Thong bao user:
   "AUTO-ROLLBACK da duoc kich hoat: [N] files reverted, registry restored tu snapshot [SNAP-ID].
    Xem $SESSION_DIR/rollback-guide.md de biet them chi tiet."
   → STOP
```

### Rollback Verification

Sau rollback, verify:

```bash
# Registry integrity
jq -e '.requirements | length > 0' .mc-data/docs/_meta/req-registry.json

# Code clean — khong con files tu migration
git diff --name-only | grep -E "(REQ-ID related)" | wc -l | grep -q "^0$"

# Snapshot integrity
ls $SESSION_DIR/snapshots/ | wc -l
```

---

## Error Log Schema

Moi error/warning trong qua trinh migration duoc ghi vao `error_log[]` trong `migrate-status.json` voi cau truc:

```json
{
  "error_code": "E017",
  "severity": "CRITICAL | ERROR | WARNING | INFO",
  "phase": "phase6",
  "timestamp": "ISO8601",
  "message": "Mo ta ngan gon bang tieng Viet",
  "details": "Chi tiet ky thuat — stack trace, context, affected files",
  "action_taken": "auto_rollback | user_prompt | retry | logged | skipped",
  "recoverable": true
}
```

### Severity Levels

| Severity | Meaning | Default Action |
|----------|---------|---------------|
| `CRITICAL` | Data loss risk, system instability | STOP + auto-rollback (neu enabled) |
| `ERROR` | Feature broken, parity fail | STOP + hoi user |
| `WARNING` | Non-blocking issue | Log + continue |
| `INFO` | Informational (CDG decisions, auto-approve log) | Log only |

### Writing to Error Log

Moi phase ghi error vao `migrate-status.json.error_log[]` bang append:

```
1. Doc migrate-status.json
2. Append error object vao error_log[]
3. Write lai migrate-status.json
```

**QUY TAC:**
- KHONG ghi de error_log — luon append
- Moi error co `error_code` tu bang E001-E019
- `action_taken` phai ro rang de audit trail
- `recoverable: true` neu co the tiep tuc sau khi fix

---

## Resume Logic & Routing

### `--status` Handler

```
IF test -f .mc-data/work/wf-migrate-module/index.json:
  → Doc index.json
  → Hien thi: active_session + bang tat ca sessions (migrate_id, status, source_module, target_module, created_at)
  → STOP
ELSE:
  → "Chua co session wf-migrate-module nao." → STOP
```

### `--resume` Handler

```
IF test -f .mc-data/work/wf-migrate-module/index.json:
  → Doc index.json → $MIGRATE_ID = active_session → $SESSION_DIR
  → IF test -f $SESSION_DIR/checkpoint.json:
      → Doc checkpoint.json
      → Route den phase tuong ung (dua tren current_phase)
      → Tiep tuc tu step tiep theo
  → ELSE: STOP "Khong tim thay checkpoint. Chay /wf-migrate-module tu dau."
ELSE:
  → STOP: "Khong tim thay session nao. Chay /wf-migrate-module tu dau."
```

### `--resume-task=<n>` Handler (NEW v1.1)

```
IF test -f .mc-data/work/wf-migrate-module/index.json:
  → Doc index.json → $MIGRATE_ID = active_session → $SESSION_DIR
  → IF test -f $SESSION_DIR/checkpoint.json:
      → Doc checkpoint.json
      → IF current_phase == "phase6" VA partial_state.phase6 exists:
          → Set $RESUME_TASK = n (task number de resume)
          → Route den Phase 6 Step 6.0b (--resume-task routing)
          → Skip tasks 0..n-1, bat dau tu task n
          → Doc $SESSION_DIR/snapshots/ de xac dinh registry state truoc task n
      → ELSE: STOP "Session khong o Phase 6. Dung --resume de tiep tuc binh thuong."
  → ELSE: STOP "Khong tim thay checkpoint."
ELSE:
  → STOP: "Khong tim thay session nao."
```

**Per-task checkpoint format trong checkpoint.json:**

```json
"partial_state": {
  "phase6": {
    "current_task": 3,
    "tasks_completed": [0, 1, 2],
    "tasks_remaining": [3, 4, 5, 6, 7],
    "last_completed_task_id": "task-crm-003",
    "registry_snapshot_before_current": "registry-phase6-task3-pre-{ts}.json"
  }
}
```

Khi resume tu task n:
1. Khoi phuc registry tu `registry-phase6-task{n}-pre-{ts}.json` (neu co)
2. Skip tasks 0..n-1 (da hoan thanh)
3. Bat dau implement tu task n
4. Ghi log: `"RESUME: Phase 6 resumed tu task [n] — [M] tasks remaining."`

---

## CORE-026/028 Trace & Phase Summary

### CORE-026 — Execution Trace

Moi phase ghi START/COMPLETE vao `.mc-data/work/_trace/session-log.json`:

```json
{"session": "$MIGRATE_ID", "skill": "wf-migrate-module", "phase": "phase1", "event": "START", "timestamp": "..."}
{"session": "$MIGRATE_ID", "skill": "wf-migrate-module", "phase": "phase1", "event": "COMPLETE", "timestamp": "..."}
```

### CORE-028 — Phase Summary

Tao `phase-summary.md` o Phase 7, tieng Viet, cho non-specialist. Tom tat toan bo qua trinh migration.

---

## Dry-Run Protocol

Khi user pass `--dry-run` flag:

1. **Phase 0** — Parse args binh thuong, set `$DRY_RUN = true`
2. **Phase 1** — Chay gap analysis DAY DU: CI code analysis + spawn agents + strategy matrix + entity mapping
3. **CDG gates bi skip** — KHONG hoi user duyet (vi day la preview)
4. **Hien thi Dry-Run Preview** thay vi CDG:
   ```
   ## Dry-Run Preview — /wf-migrate-module

   | Muc | Gia tri |
   |-----|---------|
   | Module cu | [SOURCE_MODULE] |
   | Module moi | [TARGET_MODULE] |
   | Tong features | [N] |
   | Keep | [K] |
   | Redesign | [R] |
   | Deprecate | [D] |
   | Merge | [M] |

   **Se duoc goi:**
   - /wf-add-scope --from-scan=... (Phase 2)
   - /wf-define-features --from-scan=... (Phase 3)
   - /wf-design --from-scan=... (Phase 4)
   - /wf-plan-modules --module=... (Phase 5)
   - /wf-implement-feature --task=... (Phase 6 — [N] tasks)

   **Output files se duoc tao:**
   - .mc-data/work/wf-migrate-module/{session}/gap-analysis.md
   - .mc-data/work/wf-migrate-module/{session}/strategy-matrix.md
   - .mc-data/work/wf-migrate-module/{session}/entity-mapping.md
   - [va cac output khac...]

   Chay lai KHONG co --dry-run de thuc thi.
   ```
5. **STOP** — KHONG chuyen sang Phase 2, KHONG ghi registry, KHONG goi sub-skill
6. **Van luu** strategy-matrix.md + entity-mapping.md + gap-analysis.md vao `$SESSION_DIR` de tham khao

**Khi DUNG:** User muon xem truoc chien luoc truoc khi thuc su chay migration.

**Khi KHONG dung:** Da xac nhan muon chay that (da co strategy ro rang).

---

## Cross-Validation Protocol

**Phase 7 Step 7.0** — Kiem tra tinh nhat quan giua tat ca cac phase TRUOC khi tao report.

### Checks

| # | Check | Source A | Source B | Verify | Severity |
|---|-------|----------|----------|--------|----------|
| CV-1 | Entity mapping vs code | `entity-mapping.md` (new entity column) | Actual entity classes in `apps/backend/` | Entity classes exist, field names match mapping | MAJOR |
| CV-2 | Feature specs vs implementation | Registry `features[]` with `impl_status=done` | Feature spec files in `.mc-data/docs/phase2-features/` | Spec file exists per implemented feature | MAJOR |
| CV-3 | Strategy vs parity | `strategy-matrix.md` (Keep features) | `parity-check-*.md` files | Every Keep feature has a parity report | MAJOR |
| CV-4 | Registry vs git (orphan files) | Registry — all FEAT-ID | `git diff --name-only` changed files | Every new code file has a REQ-ID referencing a registry feature | MAJOR |
| CV-5 | Snapshot integrity | `$ROLLBACK_SNAPSHOTS[]` | Actual files in `$SESSION_DIR/snapshots/` | Every snapshot in array still exists on disk | MINOR |
| CV-6 | Design vs code structure | Design docs (Phase 4) | Actual project structure | Module folders match design, no missing/wrong namespaces | MINOR |

### Verdict

| Mismatch count | Verdict | Action |
|---------------|---------|--------|
| 0 | PASS | Tiep tuc Step 7.1 |
| 1-3 | WARNING | Ghi error_log, tiep tuc |
| > 3 | FAIL | STOP — hoi user xac nhan |
| > 5 | CRITICAL | STOP — khong tao report, bao user investigate |

---

## Fix Rules

| Error Type | Auto-Fix Strategy | Escalate If |
|-----------|-------------------|-------------|
| `scan_session_not_found` | Hoi user xac nhan lai `--from-scan` | User khong tim thay |
| `registry_conflict` | Doc lai registry, de xuat ten module khac (them suffix) | Van conflict |
| `sub_skill_fail` | Retry sub-skill 1 lan, log warning vao error_log | Van fail |
| `sub_skill_preflight_fail` | Hoi user — continue (risk) hoac STOP | User chon STOP |
| `cdg_user_no_response` | Dung, cho user phan hoi | — |
| `feature_parity_fail` | Log chi tiet sai lech vao parity-check-{feat}.md, hoi user | >3 FAIL hoac user khong chap nhan |
| `parity_critical` (>5 FAIL) | Trigger rollback protocol — snapshot + hoi user revert | User chon tiep tuc |
| `context_overflow` | Luu checkpoint → STOP | — |
| `checkpoint_corrupt` | Fallback doc migrate-status.json de route | Khong doc duoc ca 2 |
| `ci_not_available` | Fallback Grep/Glob/Read — ghi WARNING | — |

---

## Error Handling Matrix

| Code | Tinh huong | Hanh dong |
|------|------------|-----------|
| E001 | PRE-GATE fail: thieu registry | STOP — *"Chay `/wf-brainstorm` truoc."* |
| E002 | Scan session khong ton tai | STOP — hoi user `--from-scan` |
| E003 | Scan session chua completed | STOP — *"Doi scan xong."* |
| E004 | `--to-system` khong co trong registry | AskUserQuestion — tao moi hoac nhap lai |
| E005 | `$USER_PROMPT` trong | STOP — hoi user mo ta |
| E006 | Registry JSON invalid | STOP — bao user fix |
| E007 | Sub-skill fail | Retry 1 lan → checkpoint + STOP |
| E008 | CDG user khong dong y | Quay lai dieu chinh |
| E009 | Feature parity fail (1-5) | Log chi tiet vao parity-check → hoi user |
| E010 | Context > 80% | Checkpoint + STOP |
| E011 | `--skip-phase` khong hop le | STOP — liet ke phase hop le |
| E012 | Template missing (CORE-031) | STOP — bao thieu file |
| E013 | Sub-skill timeout | Retry 1 lan, scope nho hon → STOP |
| E014 | Circular dependency | WARNING + log → tiep tuc |
| E015 | Entity mapping incomplete | STOP — hoi user bo sung |
| **E016** | **Sub-skill pre-flight fail** | **Hoi user — continue (risk) hoac STOP** |
| **E017** | **Parity CRITICAL (>5 FAIL)** | **Trigger rollback protocol — snapshot + hoi user revert** |
| **E018** | **Rollback snapshot write fail** | **WARNING + retry 3 lan → log + tiep tuc** |
| **E019** | **Cross-validation CRITICAL (>5 mismatches)** | **STOP — hien thi mismatches, bao user investigate** |
