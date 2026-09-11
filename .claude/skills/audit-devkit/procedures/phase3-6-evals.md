# Phase 3.6: Skill Eval Harness (opt-in)

> **Đọc:** `procedures/_shared.md §Verdict Computation §3. Eval Verdict` trước khi execute.

**Điều kiện chạy:** `evals` ∈ `$STAGES[]` (chỉ khi user truyền `--evals`).

**Mục đích:** Chạy `run-skill-evals.sh` để kiểm tra behavioral evals cho workflow skills (và/hoặc audit-devkit). Output: `$EVAL_STATUS`.

---

## Display Header

```
Phase 3.6: Running Skill Eval Harness...
```

---

## Step 3.6.1: Run Eval Harness

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.6.1a | Verify `.claude/scripts/audit/run-skill-evals.sh` tồn tại | Glob | File exists |
| 3.6.1b | Build command theo flags: | — | Command built |
|  | — Nếu `$EVAL_SKILL_FILTER` set: `bash .claude/scripts/audit/run-skill-evals.sh <name> --mode=<$EVAL_HARNESS_MODE>` | | |
|  | — Nếu không: `bash .claude/scripts/audit/run-skill-evals.sh --all --mode=<$EVAL_HARNESS_MODE>` | | |
| 3.6.1c | Run command | Bash | Exit code 0 |
| 3.6.1d | Verify output: `docs/audit/work/eval-results.json` tồn tại + JSON valid | Read | File exists + valid |
| 3.6.1e | Verify output: `docs/audit/reports/eval-results.md` tồn tại | Glob | File exists |

> **Path canonical:** Script `run-skill-evals.sh` ghi cố định ra `docs/audit/work/eval-results.json` + `docs/audit/reports/eval-results.md` (KHÔNG có session-id, KHÔNG nằm trong `.mc-data/`). Các phiên chạy đè lên nhau — đây là design của eval harness, không phải bug.

---

## Step 3.6.2: Compute Eval Verdict

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.6.2a | Đọc `eval-results.json` → extract summary counts `{pass, fail, skip, error, total_cases}` | Read | Counts extracted |
| 3.6.2b | Tính eval verdict theo bảng `_shared.md §Verdict §3`: | — | Verdict computed |
|  | — fail=0, skip=0 → **`EVAL-CLEAN`** | | |
|  | — fail=0, skip>0 → **`EVAL-PARTIAL`** | | |
|  | — fail 1-5 → **`EVAL-NEEDS-REVIEW`** | | |
|  | — fail>5 → **`EVAL-NEEDS-FIX`** | | |
| 3.6.2c | Ghi: `$EVAL_STATUS = { verdict, total_cases, pass, fail, skip, error, mode }` | — | Recorded |
| 3.6.2d | Hiển thị tóm tắt cho user: `"Evals: [pass]/[total] pass — Verdict: [verdict]"` | Output | Displayed |

---

## POST-GATE

| Check | Required |
|-------|----------|
| `$EVAL_STATUS` object populated với các fields: verdict, total_cases, pass, fail, skip, error, mode | ✓ |
| `$EVAL_STATUS.verdict` ∈ {`EVAL-CLEAN`, `EVAL-PARTIAL`, `EVAL-NEEDS-REVIEW`, `EVAL-NEEDS-FIX`, `ERROR`} | ✓ |

---

## Errors

| Code | Tình huống | Action |
|------|------------|--------|
| E010 | `run-skill-evals.sh` không tồn tại | WARNING: "Eval harness script không tồn tại", skip Phase 3.6 (không set `$EVAL_STATUS` hoặc đặt `verdict = ERROR`) |
| E010 | Script chạy nhưng exit code != 0 | WARNING: hiển thị stderr, tiếp tục Phase 4 với `$EVAL_STATUS.verdict = ERROR` |
| E010 | `eval-results.json` không tồn tại sau chạy | WARNING: "Eval harness không tạo output", skip eval verdict |
| E010 | JSON invalid | Retry read 1 lần, sau đó WARNING + skip eval verdict |

---

## Lưu ý

- **Opt-in only** — Phase 3.6 KHÔNG chạy mặc định. User phải truyền `--evals` flag.
- Không ảnh hưởng Audit verdict hay Master Plan verdict — Eval verdict là **independent**, chỉ hiển thị trong summary section riêng (Phase 4).
- Eval mode mặc định là `stub` (không dùng real API calls). `judge`/`auto`/`real` yêu cầu setup phụ — xem script docs.
