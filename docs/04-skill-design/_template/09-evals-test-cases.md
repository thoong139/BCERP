<!--
_template_notes:
  purpose: Eval test cases ≥3 (smoke/integration/edge) — match file `.claude/skills/workflow/{skill}/evals/evals.json`.
  populate:
    - §1 Bảng test cases với ID, type, scope, expected outputs
    - §2 Per-test-case detail (1 section per case)
    - §3 Eval criteria: pass/fail rules
    - §4 Coverage matrix: arguments × phases × profiles
    - §5 Eval execution
  độ dài tham khảo: 100-200 dòng
-->

# 09 — Evals & Test Cases

> **Mục đích file:** Đặc tả ≥3 test cases — smoke + integration + edge — match nội dung `evals/evals.json`.

---

## 1. Bảng test cases

| ID | Type | Scope | Profile | Expected output | Pass criteria |
|----|------|-------|---------|----------------|---------------|
| TC-{skill}-001 | smoke | minimal fixture | quick | `fix-status.json` + `Phase1-report.md` | All POST-GATE PASS |
| TC-{skill}-002 | integration | realistic fixture | standard | Full pipeline output | All phases PASS + cross-skill artifact valid |
| TC-{skill}-003 | edge | error injection | standard | Error E0{XX} + AUTO-FIX | Auto-fix recover ≤3 retries |
| TC-{skill}-004 | resume | interrupted session | standard | Resume from phase X | Continue without duplicate work |
| TC-{skill}-005 | concurrent | 2 sessions parallel | standard | Lock conflict E001 | Second session waits/escalates |

---

## 2. Test case detail

### TC-{skill}-001 — Smoke (minimal fixture)

**Setup:**
```bash
# Tạo fixture
mkdir -p .mc-data-test/docs/_meta
cp tests/fixtures/{skill-name}/minimal/req-registry.json .mc-data-test/docs/_meta/
```

**Run:**
```bash
/{skill-name} --profile=quick --scope=all
```

**Expected:**
- `$SESSION_DIR/fix-status.json` exists, JSON valid
- `$SESSION_DIR/phase1-init/Phase1-report.md` exists, ≤15 dòng tiếng Việt
- Exit code 0

**Pass criteria:**
- POST-GATE T1-T4 all PASS
- Không có error trong `error-ledger.json`
- Context budget <50%

### TC-{skill}-002 — Integration (realistic fixture)

**Setup:** {realistic fixture với multiple modules, có cross-references}

**Run:** `/{skill-name} --profile=standard`

**Expected:**
- Mọi phase PASS
- Cross-skill artifact `{skill}-impact.json` valid với `$schema` field
- `audit_chain.checksum` khớp với source file

**Pass criteria:** {...}

### TC-{skill}-003 — Edge (error injection)

**Setup:** Corrupt `req-registry.json` ở Phase 2

**Expected:**
- Phase 2 detect E020
- Auto-fix retry (max 3)
- Nếu vẫn fail → ESCALATE AskUserQuestion

**Pass criteria:** {...}

{... lặp cho mỗi TC ...}

---

## 3. Eval criteria

### Pass criteria (mỗi test case)

| Criteria | Threshold |
|----------|-----------|
| POST-GATE T1-T4 PASS | 100% |
| Error count | 0 (smoke), ≤3 with auto-fix recovery (edge) |
| Context budget | <80% (smoke), <90% (integration) |
| File outputs exist | Khớp expected list |
| Phase reports valid | Tiếng Việt, ≤15 dòng |

### Fail criteria (đỏ ngay)

| Criteria | Threshold |
|----------|-----------|
| Cross-skill artifact missing `$schema` | FAIL |
| Cross-skill artifact missing `audit_chain` | FAIL |
| POST-GATE T4 fail không recover | FAIL |
| Context budget >90% không checkpoint | FAIL |

---

## 4. Coverage matrix

|              | quick | standard | deep | exhaustive |
|--------------|-------|----------|------|-----------|
| `--scope=all` | TC-001 | TC-002 | — | — |
| `--scope=module:X` | — | TC-006 | — | — |
| `--resume` | — | TC-004 | — | — |
| Error injection | — | TC-003 | — | — |
| Concurrent | — | TC-005 | — | — |

---

## 5. Eval execution

```bash
# Chạy 1 test case
./.claude/scripts/audit/run-skill-evals.sh {skill-name} --test-id=TC-{skill}-001

# Chạy tất cả
./.claude/scripts/audit/run-skill-evals.sh {skill-name} --all
```

**Output:** `evals/results/TC-{skill}-{ID}-{timestamp}.json`

---

## 6. Test fixtures

Mọi test case BẮT BUỘC có fixture tương ứng tại `tests/fixtures/{skill-name}/`. Cấu trúc + sample helper script: xem [`eval-fixtures-sample.md`](eval-fixtures-sample.md).

| TC | Fixture path | Type |
|----|-------------|------|
| TC-{skill}-001 | `tests/fixtures/{skill-name}/minimal/` | smoke (dataset nhỏ nhất) |
| TC-{skill}-002 | `tests/fixtures/{skill-name}/realistic/` | integration (3-5 modules, 30-50 REQs) |
| TC-{skill}-003 | `tests/fixtures/{skill-name}/corrupt/{variation}/` | edge (error injection) |
| TC-{skill}-004 | `tests/fixtures/{skill-name}/realistic/` + simulated interrupt | resume |
| TC-{skill}-005 | `tests/fixtures/{skill-name}/concurrent/` | lock conflict |

---

## 7. Liên kết

- Fixture sample structure: [`eval-fixtures-sample.md`](eval-fixtures-sample.md)
- Eval schema: [`.claude/scripts/audit/EVAL-SCHEMA.md`](../../../.claude/scripts/audit/EVAL-SCHEMA.md)
- Eval source: [`.claude/skills/workflow/{skill-name}/evals/evals.json`](../../../.claude/skills/workflow/)
- Standards: [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md) §7 (compliance audit)
- Review checklist: [`../../05-review-standards/{skill-name}.md`](../../05-review-standards/)
