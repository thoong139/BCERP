# Phase 5a: Test Execution (Conditional — chỉ khi `--run-tests`)

> **Protocol:** Xem `.claude/skills/protocols/`
> **Shared:** Xem `procedures/_shared.md` — State Variables, Scoring Formulas, Error Handling

Chạy actual unit tests + integration tests nếu được cấu hình.

---

## PRE-GATE

```
test "$HAS_RUN_TESTS_FLAG" = "true" && (test -d src || test -d apps)
```

Nếu `$HAS_RUN_TESTS_FLAG != "true"` → SKIP phase, `$TEST_RESULTS = null`, set status `"skipped"` với `skip_reason = "--run-tests not provided"`.

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 5a.1 | Detect test framework (Jest, Vitest, Go test, pytest, etc.) từ `package.json` scripts hoặc `$TECH_STACK` | Framework detected |
| 5a.2 | Build test filter pattern theo scope (xem bảng dưới) | Filter ready |
| 5a.3 | Run tests với timeout 5 phút: `npm test -- [filter] 2>&1` hoặc equivalent | Tests executed |
| 5a.4 | Parse kết quả: passed / failed / skipped từ test output → set `$TEST_RESULTS` | Results parsed |
| 5a.5 | Nếu có coverage report: spawn `qa-lead` agent để phân tích coverage. Output mục tiêu: ~300-500 từ. Súc tích, chỉ coverage gaps và recommendations. | Coverage analyzed |
| 5a.6 | Tính `test_score` theo công thức (xem `_shared.md` §Scoring Formulas) | Score calculated |

---

## Test Filter theo Scope

| Scope | Jest/Vitest filter | Go test | pytest |
|-------|-------------------|---------|--------|
| `all` | (không filter) | `./...` | (không filter) |
| `system --name=SYS-ERP` | `--testPathPattern=erp` | `./apps/erp/...` | `-k erp` |
| `module --name=MOD-ERP-FIN` | `--testPathPattern=finance` | `./apps/erp/finance/...` | `-k finance` |
| `feature --name=FEAT-ERP-FIN-001` | `--testPathPattern=FEAT-ERP-FIN-001` | `-run TestFEAT` | `-k FEAT_ERP_FIN_001` |

---

## Xử lý Timeout (E006)

Nếu tests chạy > 5 phút → FORCE STOP tests, ghi WARNING "Test timeout exceeded" vào `error_log`.

---

## Scoring

```
test_score = (passed / (passed + failed)) × 100
```

**NOTE:** `test_score` là **BONUS** — KHÔNG tính vào `overall_score` weighted average. Hiển thị riêng trong report. `null` nếu không chạy.

> Xem `_shared.md` §Scoring Formulas — test_score — đầy đủ.

---

## POST-GATE

Test execution completed hoặc timed out (dù có failures — log, không STOP).

- `$TEST_RESULTS` = `{passed, failed, skipped, coverage?}` hoặc `null` (nếu skipped)
- `$SCORES.test_score` ∈ [0, 100] hoặc `null`
- Status file `preflight-status.json`: `phases.phase_5a.status = "completed"` / `"skipped"` / `"error"`

---

## Output → Next Phase

- `$TEST_RESULTS` (in-memory) — đọc bởi Phase 5b, 7
- `$SCORES.test_score` — đọc bởi Phase 7 (hiển thị riêng, không weighted)

**Next:** Phase 5b (Cross-Validation).
