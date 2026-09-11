# Phase 4c: Test Update

> Cập nhật tests tương ứng với code changes + optional run tests.

> **Shared:** Xem `procedures/_shared.md` — Fix Rules, Checkpoint Protocol.

---

## PRE-GATE

- Phase 4b PASSED
- `$DRY_RUN == false`
- `$SESSION_DIR/change-plan.md` chứa `test_changes` group (có thể empty)

---

## INPUT

- `$SESSION_DIR/change-plan.md` — test tasks
- `$SESSION_DIR/affected-artifacts.json.tests_affected[]`
- Source code files (để viết test reference)

---

## OUTPUT

- Updated/new test files
- Test run results (nếu `$RUN_TESTS == true`)
- `$SESSION_DIR/checkpoint.json` updated

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 4c.1 | **FOR each test task:** Update existing tests cho new behavior | Edit | Tests updated |
| 4c.2 | Add new tests cho new behavior (nếu có) | Write | Tests created |
| 4c.2.5 | **Prompt user nếu `--run-tests` chưa được set** — xem §Run-Tests Prompt | AskUserQuestion | Decision logged |
| 4c.3 | **Run tests** (nếu `$RUN_TESTS == true`): `[test-runner] --testPathPattern="[affected modules pattern]"` | Bash | Tests pass |
| 4c.4 | **Checkpoint:** READ template `templates/checkpoint.json` → POPULATE → WRITE `$SESSION_DIR/checkpoint.json` | Write | Checkpoint saved |

---

## Run-Tests Prompt (Step 4c.2.5)

```
IF NOT $RUN_TESTS:
  AskUserQuestion:
    "Tests đã được cập nhật. Bạn có muốn chạy test suite cho các modules bị ảnh hưởng ngay bây giờ không?"
    Options:
      - "Yes — chạy ngay"         → set $RUN_TESTS = true, tiếp tục Step 4c.3
      - "No — chạy sau bằng tay"  → log "Tests skipped by user — cần chạy thủ công sau."
```

---

## Test Run Protocol (Step 4c.3)

### Xác định test runner

Tìm theo thứ tự ưu tiên:

1. `package.json` → `scripts.test` (npm/yarn/pnpm)
2. `pytest.ini` / `pyproject.toml` → Python
3. `go.mod` → `go test`
4. `Cargo.toml` → `cargo test`
5. `Gemfile` → `bundle exec rspec`
6. `pom.xml` / `build.gradle` → Maven/Gradle

Nếu KHÔNG tìm thấy test runner:

> ⚠️ Không tìm thấy test runner. Tests đã được cập nhật nhưng không thể chạy tự động.
> Bạn cần chạy tests bằng tay sau khi kết thúc.

→ log warning, tiếp tục (không fail).

### Pattern filter

Chỉ chạy tests cho affected modules để tiết kiệm thời gian:

```
PATTERN = derive_test_pattern_from_code_affected($SESSION_DIR/affected-artifacts.json.code_affected[])

Ví dụ:
  code_affected = ["src/sales/order.service.ts", "src/sales/order.controller.ts"]
  PATTERN = "src/sales" hoặc "--testPathPattern=sales"
```

### Kết quả

Log vào `change-status.json.phases.phase4c.test_results`:

```json
{
  "runner": "npm test",
  "pattern": "src/sales",
  "passed": N,
  "failed": N,
  "total": N,
  "duration_seconds": N,
  "status": "pass | fail | partial"
}
```

Nếu có tests fail → WARNING (không block Phase 5 — user có thể quyết định fix sau).

---

## Empty Test Tasks Handling

Nếu `test_tasks[]` rỗng (không có test changes):

- Step 4c.1, 4c.2, 4c.3 → SKIP
- Step 4c.2.5 → vẫn hỏi user có muốn run regression tests cho affected modules không
- Step 4c.4 → vẫn save checkpoint

---

## POST-GATE

- Tất cả test tasks trong `change-plan.md.execution_order[group=test_changes].tasks[]` đã hoàn thành (hoặc SKIP nếu rỗng)
- Nếu `$RUN_TESTS == true`: test results đã được log vào `change-status.json.phases.phase4c.test_results`
- `$SESSION_DIR/checkpoint.json` saved với `current_phase = "phase5"`

**Verification (mc-postgate-check.sh):**
```bash
bash .claude/scripts/wf-manage-change/mc-postgate-check.sh \
  --file=$SESSION_DIR/checkpoint.json --type=json
# → {"pass":true} required. Nếu fail → auto-fix re-generate → retry tối đa 3 lần.
```

**Sau khi PASS:** Update `change-status.json.phases.phase4c.status = "completed"` → tiếp tục `procedures/phase5-verify.md`.
