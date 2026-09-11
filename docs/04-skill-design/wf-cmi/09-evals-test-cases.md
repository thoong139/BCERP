# 09 — Evals & Test Cases (wf-cmi)

> **Mục đích file:** Đặc tả 5+ test cases — smoke + integration + edge + resume + concurrent — match nội dung `evals/evals.json` (sẽ tạo khi implement).

---

## 1. Bảng test cases

| ID | Type | Scope | Profile | Expected output | Pass criteria |
|----|------|-------|---------|----------------|---------------|
| TC-cmi-001 | smoke | EUREKA fixture 1 module (CRM) | quick | `integrity-status.json` + 5 graphs + matrix + report | All POST-GATE PASS, exit 0, time <5 min |
| TC-cmi-002 | integration | EUREKA fixture 3 modules (CRM+Orders+Finance) | standard | Full 8 phases output + `integrity-impact.json` schema valid | All phases PASS + cross-skill artifact valid + coverage ≥80% per dim |
| TC-cmi-003 | edge | Registry corruption inject mid-Phase 3 | standard | Error E039 + ESCALATE | Auto-fix attempt → ESCALATE, exit 2 |
| TC-cmi-004 | resume | Interrupted at Phase 4 lane CD3 | standard | Resume from CD3 lane, skip CD1,2 already PASS | Continue without duplicate work, exit 0 |
| TC-cmi-005 | concurrent | 2 sessions parallel cùng máy | standard | Lock conflict E090b → CDG → resolution | Second session waits OK or graceful escalate |
| TC-cmi-006 | regression | `--since=HEAD~5` với 12 files changed | standard | Skip Phase 2 modules không đổi, Phase 6 predict 5 affected modules | Time < full scan, regression-map.json valid |
| TC-cmi-007 | --ci mode | CI fixture (no terminal, GitHub Action env) | standard | JSON output, no CDG invocation | Exit code chuẩn, no registry write |
| TC-cmi-008 | --dry-run | Full pipeline dry-run | deep | Report đầy đủ, KHÔNG ghi registry, no CDG actual write | Dry-run mode flag respected mọi phase |

---

## 2. Test case detail

### TC-cmi-001 — Smoke (EUREKA fixture 1 module CRM)

**Setup:**
```bash
# Tạo fixture minimal
mkdir -p tests/fixtures/wf-cmi/minimal/{apps/backend/Eureka.Modules.CRM/{Domain/Entities,Application/Commands,Infrastructure/Persistence/Configurations}}
mkdir -p tests/fixtures/wf-cmi/minimal/.mc-data/docs/{_meta,phase1-business,phase2-features/crm/customer-mgmt,phase3-architecture}

# Copy minimal registry với 5 requirements CRM
cp tests/fixtures/wf-cmi/minimal/req-registry.minimal.json \
   tests/fixtures/wf-cmi/minimal/.mc-data/docs/_meta/req-registry.json

# Copy 3 entity stubs (.cs files)
cp tests/fixtures/wf-cmi/minimal/entities/*.cs \
   tests/fixtures/wf-cmi/minimal/apps/backend/Eureka.Modules.CRM/Domain/Entities/
```

**Run:**
```bash
cd tests/fixtures/wf-cmi/minimal
/wf-cmi --scope=module=crm --profile=quick
```

**Expected:**
- `$SESSION_DIR/integrity-status.json` exists, JSON valid, phases_completed=[1,2,3,4,5,7,8]
- `$SESSION_DIR/phase2-discovery/entity-graph.json` có ≥3 nodes
- `$SESSION_DIR/phase4-coverage/lanes/CD1/signals.json` exists
- `$SESSION_DIR/phase5-aggregate/coverage-matrix.json` có 5 active dims (CD1,2,3,4,7)
- `$SESSION_DIR/phase8-report/integrity-report.md` exists, ≤30 dòng tiếng Việt
- `$SESSION_DIR/phase8-report/integrity-impact.json` schema valid `integrity-impact-v1`
- Phase 6 SKIPPED (no `--since`)
- Exit code 0

**Pass criteria:**
- POST-GATE T1-T4 all PASS
- Không có error trong `error-ledger.json` (hoặc chỉ INFO E100-E109)
- Context budget <50%
- Time <5 min

### TC-cmi-002 — Integration (EUREKA fixture 3 modules)

**Setup:**
```bash
# Fixture với 3 modules có cross-module dependencies
# CRM.Customer.SalesOwnerId → HRM.Employee.Id
# Orders.Order.CustomerId → CRM.Customer.Id
# Orders.Order.QuotationId → Quotation.Quote.Id
# Finance.Journal triggered by Order events
mkdir -p tests/fixtures/wf-cmi/realistic/
# (15-20 stub files, 30-50 REQs trong registry)
```

**Run:**
```bash
/wf-cmi --profile=standard
```

**Expected:**
- 7 active lanes (CD1,2,3,4,5,6,7,9) — KHÔNG có CD8,10
- `business-invariants.json` có ≥10 invariants với cross-module dependencies
- `coverage-matrix.json` có overall_pct ≥80%
- `integrity-impact.json` có `produces_for{}` cho 4 consumers (wf-verify-sync, wf-fix-bugs, wf-implement-feature, wf-prepare-deployment)
- `audit_chain.checksum` verify được (sha256 của `integrity-status.json`)
- Phase reports tiếng Việt ≤15 dòng/phase

**Pass criteria:**
- Mọi phase PASS
- Schema validation: `jq -e '.["$schema"] == "integrity-impact-v1"' integrity-impact.json` PASS
- Cross-module dependencies: `jq '.cross_module_dependencies | length > 5' business-invariants.json` PASS
- Time 15-30 min

### TC-cmi-003 — Edge (Registry corruption mid-Phase 3)

**Setup:**
```bash
# Hook để corrupt registry sau Phase 2 PASS, trước Phase 3 LLM call
echo '{"corrupted": true}' > $SESSION_DIR/inject/corrupt-trigger
```

**Run:**
```bash
/wf-cmi --profile=standard
# Hook corrupt registry khi Phase 3 step 3.1 load
```

**Expected:**
- Phase 3 PRE-GATE T2 fail (jq parse error trên registry)
- Auto-fix retry 1: re-read registry → vẫn corrupt → fail
- Auto-fix retry 2: re-validate registry với jq → fail
- Auto-fix retry 3: fallback đọc backup → no backup → fail
- ESCALATE AskUserQuestion: "Re-run phase / Skip (risky) / Cancel / Switch profile?"

**Pass criteria:**
- Error code E039 logged trong `error-ledger.json` với retry_count=3
- ESCALATE invoked với 4 options (CDG)
- Pipeline state preserved (resume possible)
- Exit code 2

### TC-cmi-004 — Resume (Interrupted at Phase 4)

**Setup:**
```bash
# Run original
/wf-cmi --profile=standard &
SESSION_PID=$!
sleep 60  # Vào Phase 4
kill -INT $SESSION_PID  # Ctrl+C simulate
```

**Run:**
```bash
/wf-cmi --resume
```

**Expected:**
- Lock check: age <30 min → reacquire ngay
- `integrity-status.json.current_phase=4`, `lane_status` cho thấy 6/10 lanes PASS
- Skip 6 already-PASS lanes (KHÔNG re-spawn agent)
- Re-spawn 4 pending lanes (1 RUNNING + 3 PENDING)
- Continue Phase 5-8

**Pass criteria:**
- KHÔNG redo Phase 1-3 (đã PASS)
- KHÔNG redo 6 lanes (kiểm tra qua `session-log.json` — không có START entry cho 6 lanes)
- Continue without error
- Exit 0
- `session-log.json` có RESUME entry với original session_id

### TC-cmi-005 — Concurrent (2 sessions cùng máy)

**Setup:**
```bash
# Session 1: Dev A
/wf-cmi --scope=system --profile=deep &
SA_PID=$!
sleep 30  # Vào Phase 2 Discovery

# Session 2: Dev B
/wf-cmi --scope=module=crm --profile=quick &
SB_PID=$!
```

**Expected:**
- Dev B Phase 1 PASS (different SESSION_DIR)
- Dev B Phase 2-6 read-only chạy song song với Dev A (Protocol 22 read lock)
- Khi cả 2 cùng tới Phase 7 (write registry) → second session gets E090b CDG
- CDG options: Wait / Cancel / Force release

**Pass criteria:**
- 2 sessions không corrupt state
- Read-heavy phases (Phase 2-6) chạy song song không conflict
- Write-heavy phase (Phase 7) serialize qua R/W write lock
- Heartbeat 30s update đầy đủ cho cả 2 sessions
- Cleanup: cả 2 sessions release lock đúng

### TC-cmi-006 — Regression (`--since=HEAD~5`)

**Setup:**
```bash
# Fixture với git history 5+ commits, 12 files changed across 3 modules
cd tests/fixtures/wf-cmi/regression/
git log --oneline | head -10  # verify 5+ commits
```

**Run:**
```bash
/wf-cmi --since=HEAD~5 --profile=standard
```

**Expected:**
- Phase 2 Discovery: chỉ rebuild graphs cho 3 modules đổi (skip 14 modules không đổi)
- Phase 3 Invariant: chỉ infer cho 3 domains affected
- Phase 6 Regression Map: predict 5+ affected modules (transitive)
- `regression-map.json` có `since_ref: "HEAD~5"`, `changed_files: [12 files]`, `predicted_impact.affected_modules: ≥5`
- `coverage-matrix.json.coverage_kind: "partial"`
- Total time < TC-cmi-002 (full scan)

**Pass criteria:**
- Time tiết kiệm ≥50% so với full scan
- `audit_chain.scanned_files[]` đầy đủ
- `audit_chain.skipped_phases[]` ghi rõ phases skipped (per-module)
- Consumer warning: artifact đánh dấu partial

### TC-cmi-007 — `--ci` mode

**Setup:**
```bash
export CI=true
export GITHUB_ACTIONS=true
```

**Run:**
```bash
/wf-cmi --ci --profile=standard --since=main
```

**Expected:**
- Auto-downgrade `exhaustive`/`deep` → `standard` nếu detect timeout risk (E108)
- KHÔNG invoke CDG (CI mode bypass) — auto-decision dựa threshold
- KHÔNG write sidecar artifact `business-invariants.json` (read-only)
- Output JSON đầy đủ (machine-readable)
- Exit code chuẩn: 0/1/2

**Pass criteria:**
- `--ci --auto-suggest` ERROR E012 (mutually exclusive)
- Registry KHÔNG có changes (verify via `git status .mc-data/docs/_meta/req-registry.json`)
- `integrity-impact.json` valid + ready cho CI parse
- Author info `git_user_email = github-actions-bot@erktransport.com`

### TC-cmi-008 — `--dry-run`

**Setup:** EUREKA realistic fixture (same as TC-cmi-002)

**Run:**
```bash
/wf-cmi --profile=deep --dry-run --auto-suggest
```

**Expected:**
- Full 8 phases chạy bình thường
- Phase 7 CDG E094 prompt user nhưng decision KHÔNG actual write registry
- Output: `integrity-report.md` có section "DRY-RUN — không có changes applied"
- Registry KHÔNG có changes
- `integrity-impact.json` có `dry_run: true` field

**Pass criteria:**
- Registry unchanged (verify via diff)
- CDG decisions logged nhưng không enforce
- All outputs generated (cho user review)
- Dry-run flag respect mọi phase (no side-effects)

---

## 3. Eval criteria

### Pass criteria (mỗi test case)

| Criteria | Threshold |
|----------|-----------|
| POST-GATE T1-T4 PASS | 100% |
| Error count | 0 (smoke), ≤3 với auto-fix recovery (edge) |
| Context budget | <50% (smoke quick), <80% (integration standard), <90% (deep) |
| File outputs exist | Khớp expected list trong §2 |
| Phase reports valid | Tiếng Việt, ≤15 dòng/phase, ≤30 dòng integrity-report |
| Cross-skill artifact valid | `$schema=integrity-impact-v1`, `audit_chain.checksum` verifiable |

### Fail criteria (đỏ ngay)

| Criteria | Lý do |
|----------|-------|
| Cross-skill artifact missing `$schema` | Vi phạm CORE-036 |
| Cross-skill artifact missing `audit_chain.source` / `checksum` | Vi phạm CORE-036 |
| POST-GATE T4 fail không recover | Cross-ref drift critical |
| Context budget >90% không checkpoint | Vi phạm CORE-038 |
| Registry write KHÔNG qua CDG (E094) | Vi phạm CORE-027 |
| 2 agents ghi cùng 1 file | Vi phạm CORE-037 §7 ownership |
| Lock acquire fail không retry | Vi phạm CORE-030 |
| Auto-upgrade profile KHÔNG qua CDG (E096) | Vi phạm CORE-027 |
| Phase report >15 dòng | Vi phạm CORE-028 |

---

## 4. Coverage matrix (test × args)

|                          | quick | standard | deep | exhaustive |
|--------------------------|:-----:|:--------:|:----:|:----------:|
| `--scope=system`         | — | TC-cmi-002 | — | — |
| `--scope=module=X` | TC-cmi-001 | — | — | — |
| `--scope=feat=X`         | — | — | — | — (overkill — auto-downgrade) |
| `--resume`               | — | TC-cmi-004 | — | — |
| Error injection          | — | TC-cmi-003 | — | — |
| Concurrent               | — | TC-cmi-005 | — | — |
| `--since` regression     | — | TC-cmi-006 | — | — |
| `--ci` mode              | — | TC-cmi-007 | — | — |
| `--dry-run`              | — | — | TC-cmi-008 | — |

**Coverage gap (v2 add):**
- Profile `exhaustive` end-to-end (cost cao, defer v2)
- Multi-user collaboration với git branch isolation (TC-cmi-009 planned v2)
- LLM API timeout (TC-cmi-010 planned v2)

---

## 5. Eval execution

```bash
# Chạy 1 test case
./.claude/scripts/audit/run-skill-evals.sh wf-cmi --test-id=TC-cmi-001

# Chạy tất cả
./.claude/scripts/audit/run-skill-evals.sh wf-cmi --all

# Chạy chỉ smoke + integration (CI quick gate)
./.claude/scripts/audit/run-skill-evals.sh wf-cmi --type=smoke,integration
```

**Output:** `evals/results/TC-cmi-{ID}-{timestamp}.json`

```json
{
  "test_id": "TC-cmi-001",
  "type": "smoke",
  "started_at": "2026-05-15T15:00:00+07:00",
  "completed_at": "2026-05-15T15:03:42+07:00",
  "duration_sec": 222,
  "result": "PASS",
  "expected_outputs_found": 10,
  "expected_outputs_missing": 0,
  "post_gate_failures": 0,
  "error_count": 0,
  "context_budget_max_pct": 35,
  "phase_reports_compliance": {"all_under_15_lines": true, "vietnamese": true}
}
```

---

## 6. Test fixtures

Cấu trúc fixtures tại `tests/fixtures/wf-cmi/`:

```
tests/fixtures/wf-cmi/
├── minimal/                          # TC-cmi-001 smoke
│   ├── apps/backend/Eureka.Modules.CRM/   # 3 entity stubs, 1 command, 1 validator
│   └── .mc-data/                          # Minimal registry + 3 phase docs
├── realistic/                        # TC-cmi-002, TC-cmi-004, TC-cmi-008 integration
│   ├── apps/backend/Eureka.Modules.{CRM,Orders,Finance}/  # 30-50 file stubs
│   └── .mc-data/                          # 30-50 REQs + cross-module dependencies
├── corrupt/                          # TC-cmi-003 edge
│   ├── registry-corruption/
│   ├── missing-template/
│   └── lock-stale/
├── concurrent/                       # TC-cmi-005
│   └── (uses realistic fixture + concurrent runner)
├── regression/                       # TC-cmi-006
│   ├── apps/backend/Eureka.Modules.{CRM,Orders,Finance}/
│   ├── .mc-data/
│   └── .git/                              # Git history với 5+ commits, 12 files changed
└── ci/                               # TC-cmi-007
    └── (uses realistic fixture + CI=true env)
```

**Helper script:**
```bash
# Generate fixture stubs
.claude/scripts/wf-cmi/generate-fixtures.sh --type=minimal
.claude/scripts/wf-cmi/generate-fixtures.sh --type=realistic --modules=crm,orders,finance
```

---

## 7. CI integration (sẽ thêm khi implement skill)

```yaml
# .github/workflows/wf-cmi-evals.yml (sample)
name: wf-cmi Evals
on: [pull_request]
jobs:
  smoke:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run smoke test
        run: ./.claude/scripts/audit/run-skill-evals.sh wf-cmi --test-id=TC-cmi-001
  integration:
    runs-on: ubuntu-latest
    needs: smoke
    steps:
      - name: Run integration test
        run: ./.claude/scripts/audit/run-skill-evals.sh wf-cmi --test-id=TC-cmi-002
        timeout-minutes: 30
```

---

## 8. Liên kết

- Eval schema: [`.claude/scripts/audit/EVAL-SCHEMA.md`](../../../.claude/scripts/audit/EVAL-SCHEMA.md)
- Eval source: [`.claude/skills/workflow/wf-cmi/evals/evals.json`](../../../.claude/skills/workflow/) (sẽ tạo)
- Fixture helper template: [`eval-fixtures-sample.md`](../_template/eval-fixtures-sample.md)
- Standards: [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md) §7 (compliance audit)
- Review checklist: [`../../05-review-standards/wf-cmi.md`](../../05-review-standards/) (sẽ tạo)
