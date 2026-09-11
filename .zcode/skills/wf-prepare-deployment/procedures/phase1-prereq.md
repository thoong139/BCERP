# Phase 1: Prerequisites Validation & Execution Plan

> Validate inputs, đọc registry/architecture/verify-sync, tạo execution plan + status file.
> Detect Large Project Mode để áp dụng parameter overrides cho các phase sau.

**PRE-GATE:**
- [ ] `test -f .mc-data/docs/_meta/req-registry.json` — nếu fail → E001
- [ ] `test -f .mc-data/docs/_meta/verify-sync.md` — nếu fail → E002
- [ ] **[Protocol 10.4 — Forensic]** `P3-01-architecture.md` tồn tại + >= 7 headings — nếu fail: `"P3-01-architecture.md khong dat yeu cau noi dung. Chay /wf-design de hoan thien."`

**INPUT:**

| File | Path | Mục đích |
|------|------|----------|
| Registry | `.mc-data/docs/_meta/req-registry.json` | Project info, tech stack, systems, depts, features |
| Verify sync | `.mc-data/docs/_meta/verify-sync.md` | Sync rate ≥ 80% |
| Architecture | `.mc-data/docs/phase3-architecture/P3-01-architecture.md` | Context cho plan |
| Infra spec | `.mc-data/docs/phase3-architecture/technical-specs/infra-spec.md` | Hạ tầng context |

**OUTPUT:**
- `.mc-data/work/wf-prepare-deployment/prepare-deployment-status.json` (từ template)
- `.mc-data/work/wf-prepare-deployment/prepare-deployment-plan.md` (từ template)
- In-memory state: `$PROJECT_NAME`, `$SCOPE`, `$SYNC_RATE`, `$TECH_STACK`, `$LARGE_PROJECT`, `$LPM_PARAMS`
- **(v2.1+ S9):** `$FIX_IMPACT_CONTEXT`, `$FROM_FIX_BUGS_SESSION_DIR` (object/null) — load khi `$HAS_FROM_FIX_BUGS_FLAG=true`

---

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §Large Project Mode (LPM)
- `_shared.md` §Fix Rules đặc thù

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 1.1 | Check `req-registry.json` tồn tại | `test -f` |
| 1.2 | Check `verify-sync.md` tồn tại | `test -f` |
| 1.3 | Parse `$SYNC_RATE` từ verify-sync.md (hoặc registry fallback) — set `$SYNC_RATE` | Rate captured |
| 1.3a | **[SYNC GATE]** Nếu `$SYNC_RATE < 80%` → hiển thị cảnh báo E003, hỏi user có tiếp tục (xem §Sync Rate Gate) | User confirmed |
| 1.4 | Đọc `P3-01-architecture.md` — forensic check + load context summary | Heading count >= 7 |
| 1.5 | Đọc `technical-specs/infra-spec.md` — load context | Content loaded |
| 1.6 | Parse `$SCOPE` từ `$ARGUMENTS` (default: `all`) | Scope set |
| 1.6b | **[Protocol 6.6] LPM DETECT** — xem §LPM Detection | `$LARGE_PROJECT`, `$LPM_PARAMS` set |
| 1.7 | **[READ-TEMPLATE]** READ `templates/prepare-deployment-plan.md` → POPULATE (Deploy ID, Project, Scope, Created, Prerequisites table) → WRITE `.mc-data/work/wf-prepare-deployment/prepare-deployment-plan.md` | `test -s plan.md` |
| 1.7b | **[READ-TEMPLATE]** READ `templates/prepare-deployment-status.json` → POPULATE (skill_id, project, scope, status="in_progress", started_at, arguments) → WRITE `.mc-data/work/wf-prepare-deployment/prepare-deployment-status.json` | `test -s status.json` |
| 1.8 | **LPM CHECKPOINT** — Nếu `$LARGE_PROJECT=true`: SAVE CHECKPOINT sau Phase 1 (prerequisites + plan validated) | Checkpoint saved |
| 1.9 | **(v2.1+ S9) Fix-Impact Context Loading (conditional):** IF `$HAS_FROM_FIX_BUGS_FLAG != true` → set `$FIX_IMPACT_CONTEXT = null`, `$FROM_FIX_BUGS_SESSION_DIR = null`, jump to Step 1.10. ELSE: xem §Fix-Impact Loading below — resolve session_dir, load `fix-impact.json`, validate schema fix-impact-v1. | `$FIX_IMPACT_CONTEXT` set hoặc null |
| 1.10 | **(v2.1+ S9) Fix-Impact Go/No-Go Gate (conditional):** IF `$FIX_IMPACT_CONTEXT == null` → SKIP. ELSE: xem §Fix-Impact Go/No-Go Gate — check escalated > 0 hoặc tests_failed > 0 → render CDG (Critical Decision Gate) BLOCK release; check audit_chain → WARN nếu mismatch. User reject → STOP với E013_FIX_IMPACT_BLOCK. | Gate decided |

---

## §Sync Rate Gate (Step 1.3a)

```
IF $SYNC_RATE < 80%:
  1. Hien thi:
     "WARNING E003: Sync rate chi $SYNC_RATE%.
      Khuyen nghi chay /wf-verify-sync truoc de dat >= 80%.
      Neu van muon tiep tuc, xac nhan ro rang (yes/no)."

  2. User input:
     - "yes" → tiep tuc, append error_log entry:
         {type: "low_sync_rate", value: $SYNC_RATE, accepted_by_user: true}
     - "no" hoac khac → STOP, huong dan chay /wf-verify-sync
```

---

## §LPM Detection (Step 1.6b)

```
Doc registry va dem:
  systems_count = .systems | length
  depts_count   = .departments | length
  reqs_count    = .requirements | length
  features_count = .features | length

IF systems_count >= 5 OR depts_count >= 10 OR reqs_count >= 50 OR features_count >= 40:
  $LARGE_PROJECT = true
  $LPM_PARAMS = {
    compression_threshold: 2,
    digest_size: 300,
    skeleton_threshold: 2000,
    output_targets_deploy: "3500–5500 tu",
    output_targets_user:   "2500–4000 tu",
    output_targets_runbook: "1500–2500 tu",
    checkpoint_strategy: "per_phase"
  }
  Log: "LPM detected (systems=N, depts=N, reqs=N, features=N) — overrides applied"
ELSE:
  $LARGE_PROJECT = false
  $LPM_PARAMS = {
    compression_threshold: 3,
    digest_size: 200,
    skeleton_threshold: 3000,
    output_targets_deploy: "2000–3500 tu",
    output_targets_user:   "1500–2500 tu",
    output_targets_runbook: "1000–1500 tu",
    checkpoint_strategy: "major_phase_only"
  }
```

---

## §Execution Plan Population (Step 1.7)

Template `templates/prepare-deployment-plan.md` populate với:

```markdown
## Execution Plan — wf-prepare-deployment

### Scope
- Input: registry, verify-sync.md, P3-01-architecture.md, infra-spec.md,
         database-design.md, features/**/*.md, ux/**/*.md
- Output: deployment-guide.md, user-guide.md, incident-response-runbook.md,
          stakeholder-review.md
- Agents: devops, tech-writer, sre, qa-lead, integration-certifier, reality-checker

### Execution Order
| Step | Tasks | Mode | Dependencies | Est. Token |
|------|-------|------|-------------|------------|
| 1  | Read context + validate                            | SEQUENTIAL | —       | ~5K  |
| 2a | devops: deployment-guide Muc 1-8                   | PARALLEL   | Step 1  | ~15K |
| 2b | tech-writer: user-guide.md                         | PARALLEL   | Step 1  | ~12K |
| 3b | tech-writer: Muc 9 Account Mgmt                    | SEQUENTIAL | 2a, 2b  | ~5K  |
| 3c | Checkpoint                                         | SEQUENTIAL | 3b      | ~1K  |
| 4  | devops+tech-writer: Muc 10 Maintenance             | SEQUENTIAL | 3c      | ~8K  |
| 4a | sre: incident-response-runbook                     | SEQUENTIAL | 4       | ~10K |
| 5  | Cross-validation + Content Quality                 | SEQUENTIAL | 4a      | ~5K  |
| 5a | Stakeholder Review (3 agents parallel + reality)   | SEQUENTIAL | 5       | ~20K |

### Token Budget
- Estimated total: ~80K tokens
- Context limit: 200K tokens
- Safety margin: 20%
- Available: 160K tokens
- Verdict: Du budget (single session neu $LARGE_PROJECT=false)

### Checkpoint Strategy
- Standard: Checkpoint sau 3c (Phase 2+3a+3b done), 5a (stakeholder done)
- LPM: Checkpoint sau MOI phase — 1, 3c, 4, 4a, 5, 5a
- Khi $CONTEXT_PERCENT > 80%: giam parallel (khong spawn 2a+2b cung luc)
- Resume point: current_phase + completed files
```

---

## §Fix-Impact Loading (Step 1.9 — v2.1+ S9)

```
IF $HAS_FROM_FIX_BUGS_FLAG != true:
  → SKIP (set tất cả contexts = null)

ELIF $FROM_FIX_BUGS_SESSION_ID non-empty:
  → $FROM_FIX_BUGS_SESSION_DIR=".mc-data/work/wf-fix-bugs/sessions/$FROM_FIX_BUGS_SESSION_ID"
  → Verify dir tồn tại — không thì WARNING + skip

ELSE (auto-resolve):
  → Check `test -f .mc-data/work/wf-fix-bugs/_index/sessions.jsonl`
    → Không có → WARNING "wf-fix-bugs chưa chạy hoặc index không tồn tại", skip
  → LATEST_SID=$(jq -r 'select(.status=="completed")|.session_id' _index/sessions.jsonl | sort | tail -1)
    → Empty → WARNING "Không có completed session", skip
  → $FROM_FIX_BUGS_SESSION_DIR=".mc-data/work/wf-fix-bugs/sessions/$LATEST_SID"

LOAD fix-impact.json:
  → Check `test -f $FROM_FIX_BUGS_SESSION_DIR/fix-impact.json`
    → Không có → WARNING "fix-impact.json không tồn tại — wf-fix-bugs có thể chưa hoàn tất POST-GATE step 3.5", skip
  → Validate `jq -e '."$schema" == "fix-impact-v1"' fix-impact.json`
    → Fail → WARNING "Schema mismatch", skip
  → Parse vào $FIX_IMPACT_CONTEXT (object)

LOG: "Fix-Impact loaded từ $FROM_FIX_BUGS_SESSION_DIR — escalated=$N, registry_changes=$N, tests_failed=$N"
```

---

## §Fix-Impact Go/No-Go Gate (Step 1.10 — v2.1+ S9)

```
IF $FIX_IMPACT_CONTEXT == null:
  → SKIP (no gate)

# Check 1: Escalated blockers (next_recommended_action.skill = wf-prepare-deployment + escalated)
ESCALATED=$(jq -r '.fix_summary.escalated' <<< "$FIX_IMPACT_CONTEXT")
NEXT_SKILL=$(jq -r '.next_recommended_action.skill' <<< "$FIX_IMPACT_CONTEXT")
HAS_ESCALATED_BLOCKING=$(jq -r '.next_recommended_action.blocking_items[]? | select(.type=="escalated") | .count' <<< "$FIX_IMPACT_CONTEXT")

IF [ "$NEXT_SKILL" == "wf-prepare-deployment" ] AND [ -n "$HAS_ESCALATED_BLOCKING" ] AND [ "$HAS_ESCALATED_BLOCKING" -gt 0 ]:
  → RENDER CDG (Critical Decision Gate — Protocol 16):
    "❌ BLOCK RELEASE: wf-fix-bugs session $SESSION_DIR có $HAS_ESCALATED_BLOCKING escalated issue(s)
     cần stakeholder review trước Go-Live. fix-impact.json next_recommended_action.skill='wf-prepare-deployment'
     báo blocking. Tiếp tục bất chấp gate? (yes / no — recommend NO)"
  → User "yes" + escalation rationale → log error_log {type: 'fix_impact_escalated_override', accepted_by_user}, CONTINUE
  → User "no" → STOP với E013_FIX_IMPACT_BLOCK, recommend "Resolve escalated issues qua /wf-fix-bugs --resume hoặc manual review"

# Check 2: Regression tests failed
TESTS_FAILED=$(jq -r '.regression_check.tests_failed' <<< "$FIX_IMPACT_CONTEXT")
IF [ "$TESTS_FAILED" -gt 0 ]:
  → RENDER CDG: "❌ BLOCK RELEASE: regression_check báo $TESTS_FAILED tests failed sau fix.
     IDs: $(jq -r '.regression_check.tests_failed_ids[]' <<< "$FIX_IMPACT_CONTEXT" | head -5)
     Tiếp tục? (yes / no — recommend NO)"
  → Same accept/reject pattern

# Check 3: Audit chain tamper detection (D4)
EXPECTED_CHECKSUM=$(jq -r '.audit_chain.checksum_sha256' <<< "$FIX_IMPACT_CONTEXT")
IF [ -f "$FROM_FIX_BUGS_SESSION_DIR/fix-log.json" ]:
  ACTUAL=$(jq -Sc 'sort_by(.issue_id)' "$FROM_FIX_BUGS_SESSION_DIR/fix-log.json" | sha256sum | cut -d" " -f1)
  IF [ "$EXPECTED_CHECKSUM" != "$ACTUAL" ]:
    → WARN: "audit_chain.checksum_sha256 mismatch — possible tamper hoặc fix-log diverged. KHÔNG block,
       nhưng deployment-guide section sẽ note 'audit chain compromised'"
    → Set $AUDIT_CHAIN_TAMPERED=true (Phase 6 dùng cho section)

LOG: "Go/No-Go gate: ALL CHECKS PASSED (hoặc user override)"
```

---

## POST-GATE

- [ ] `test -s .mc-data/docs/phase3-architecture/P3-01-architecture.md`
- [ ] `test -s .mc-data/work/wf-prepare-deployment/prepare-deployment-status.json`
- [ ] `test -s .mc-data/work/wf-prepare-deployment/prepare-deployment-plan.md`
- [ ] `$PROJECT_NAME`, `$SCOPE`, `$SYNC_RATE`, `$LARGE_PROJECT`, `$LPM_PARAMS` set in-memory
- [ ] Nếu `$LARGE_PROJECT=true`: checkpoint saved
- [ ] **(v2.1+ S9):** `$FIX_IMPACT_CONTEXT` set (object hoặc null), `$FROM_FIX_BUGS_SESSION_DIR` set, Go/No-Go gate đã chạy nếu context non-null

**Next phase:**
- Song song: `phase2-deployment-guide.md` + `phase3a-user-guide.md` (nếu `$SCOPE` ∈ {all, deployment+user-guide})
- Chỉ deployment: `phase2-deployment-guide.md`
- Chỉ user-guide: `phase3a-user-guide.md`

---

## Error Codes

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E001 | `req-registry.json` không tồn tại | STOP → chạy workflow từ đầu |
| E002 | `verify-sync.md` không tồn tại | STOP → chạy `/wf-verify-sync` trước |
| E003 | Sync rate < 80% | WARNING → hỏi user confirm (xem §Sync Rate Gate) |
| E004 | `P3-01-architecture.md` không tồn tại | STOP → chạy `/wf-design` trước |
| E006 | Template không tìm thấy | STOP → verify `.claude/doc-framework/` + `templates/` |
| **E013_FIX_IMPACT_BLOCK** | **(v2.1+ S9)** Fix-Impact Go/No-Go gate BLOCK (escalated > 0 hoặc tests_failed > 0), user reject override | STOP — recommend resolve escalated issues qua `/wf-fix-bugs --resume` hoặc manual review fix-impact.json |
