# Phase 5: Code Quality Check (PARALLEL với Phase 4)

> **Protocol:** Xem `.claude/skills/protocols/`
> **Shared:** Xem `procedures/_shared.md` — State Variables, Severity Mapping, Scoring Formulas, Error Handling

Chạy type-check và lint để phát hiện lỗi biên dịch trước khi test. Chỉ chạy nếu source code tồn tại.

---

## PRE-GATE

```
test -d src || test -d apps
```

`$TECH_STACK` (từ Phase 1) đã detect tooling.

> **Nếu không có code:** SKIP, set `$SCORES.quality_score = null`, `$QUALITY_ISSUES = []`.

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 5.1 | Detect tooling từ `$TECH_STACK` (tsconfig.json, .eslintrc* hoặc eslint.config.*, go.mod, etc.) | Tools confirmed |
| 5.2 | **TypeScript** (nếu có `tsconfig.json`): `npx tsc --noEmit 2>&1` | Exit code captured |
| 5.3 | **ESLint** (nếu có `.eslintrc*` hoặc `eslint.config.*`): `npx eslint src/ --max-warnings=0 2>&1` hoặc `npx eslint apps/ --max-warnings=0` | Exit code captured |
| 5.4 | **Go** (nếu có `go.mod`): `go build ./... 2>&1` | Exit code captured |
| 5.5 | **Python** — detect bằng: (`requirements.txt` OR `setup.py` OR `pyproject.toml`) AND tồn tại ít nhất 1 file `.py` trong `src/` hoặc `apps/`. Nếu không có file `.py` → skip step này dù `requirements.txt` tồn tại. Nếu có: `python -m py_compile $(find src apps -name "*.py" 2>/dev/null) 2>&1` | Exit code captured (hoặc skipped nếu no .py files) |
| 5.6 | Collect tất cả errors + warnings, phân loại severity | Quality issues list |
| 5.7 | Tính `quality_score` theo công thức (xem `_shared.md` §Scoring Formulas) | Score calculated |

---

## Severity Classification

| Severity | Loại lỗi | Impact |
|----------|----------|--------|
| CRITICAL | Compile errors, type errors (blocking) | Verdict FAIL |
| HIGH | Lint errors (error level) | Verdict WARN |
| MEDIUM | Lint warnings | INFO only |

---

## Scope-Aware Scan

- Nếu scope hẹp hơn `all`: scope lint/tsc vào `apps/[system-prefix]/` hoặc `src/[module]/`
- Nếu không có tool phù hợp: skip bước đó, log NOTE, set `quality_score = null` (không phải 100)

---

## Scoring — ĐẦY ĐỦ 5 CASES

```
IF không có tooling nào khả dụng (E005) → quality_score = null
  ⚠️ KHÔNG set quality_score = 100 khi skip — 100 nghĩa là "đã check, không có lỗi"

IF CRITICAL errors > 0 → quality_score = 0
ELIF HIGH errors > 0   → quality_score = 50
ELIF có warnings > 0   → quality_score = 80
ELSE (clean run)       → quality_score = 100
```

**Ví dụ:**
- Không có node/npm (E005) → `null` (redistribute weight)
- 2 compile errors (CRITICAL) → `0`
- 1 lint error (HIGH) → `50`
- 3 lint warnings (MEDIUM) → `80`
- Clean run → `100`

> Xem `_shared.md` §Scoring Formulas — quality_score — đầy đủ.

---

## POST-GATE

Tool execution completed (dù có errors — chỉ log, không STOP).

- `$QUALITY_ISSUES` = array (có thể rỗng `[]`)
- `$SCORES.quality_score` ∈ {0, 50, 80, 100} hoặc `null` (skip hợp lệ)
- Status file `preflight-status.json`: `phases.phase_5.status = "completed"` hoặc `"skipped"` với `skip_reason`

---

## Output → Next Phase

- `$QUALITY_ISSUES` (in-memory) — đọc bởi Phase 5b, 7
- `$SCORES.quality_score` — đọc bởi Phase 7

**Parallel Note:** Phase 5 chạy ĐỒNG THỜI với Phase 4. Phase 5 spawn subprocess (tsc/eslint/go build), Phase 4 scan strings → khác resource, không conflict.

**Next:** Sau khi Group B (Phases 4+5) hoàn thành → chạy sequential Phase 5a (nếu `--run-tests`) → Phase 5b (Cross-Validation).
