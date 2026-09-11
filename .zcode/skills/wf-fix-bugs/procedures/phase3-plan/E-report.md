# Phase 3 Group E — Phase Report (Step 3.6)

> **Entry condition:** Group D POST-GATE PASS (work-plan + dimension-plan written).
> **Exit condition:** `Phase3-report.md` tiếng Việt ≤15 dòng written từ template.
> **Next:** [phase3-plan/F-finalize.md](F-finalize.md) (Finalize state).
>
> **Shared protocols cần thiết:** None (script delegation only).

## Input contract (env vars từ Group D)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$SESSION_ID` | Session identity |
| `$STATUS_PASS` | Orchestrator set FAIL nếu POST-GATE fail (default "PASS") |
| `work-plan.json`, `workload-gate.json` | Inputs cho report population |

## Output contract (env vars truyền sang Group F)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `Phase3-report.md` written | 3.6 | `$SESSION_DIR/phase3-plan/Phase3-report.md` ≤15 dòng |

---

## Step 3.6 — Phase Report (delegated to generate-phase3-report.sh — CORE-028)

**Mục đích:** Tạo `Phase3-report.md` tiếng Việt ≤15 dòng (CORE-028). Đọc từ `work-plan.json` + `workload-gate.json`, populate template qua sed.

**Fix v10.5:** Trước v10.5 dùng inline heredoc — vi phạm CORE-031 (template không được sử dụng). v10.5+ fix bằng `generate-phase3-report.sh` đọc template + sed populate.

```bash
export SESSION_DIR SESSION_ID
export STATUS_PASS="${STATUS_PASS:-PASS}"   # orchestrator set FAIL nếu POST-GATE fail

bash .claude/scripts/wf-fix-bugs/generate-phase3-report.sh
```

**VERIFY:**

```bash
test -s "$SESSION_DIR/phase3-plan/Phase3-report.md"
test "$(wc -l < "$SESSION_DIR/phase3-plan/Phase3-report.md")" -le 15
grep -q "PASS\|FAIL" "$SESSION_DIR/phase3-plan/Phase3-report.md"
# Verify no placeholders left
! grep -qE '\[[A-Z_]+\]' "$SESSION_DIR/phase3-plan/Phase3-report.md"
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|-----------|-----------|
| E035 | Template missing | Script exit 3 → Re-run x1, escalate |
| E001 | Write fail | Retry x1 → escalate |

**Cross-ref:** CORE-028 (tiếng Việt ≤15 dòng), CORE-031 (Template Usage Rule — fix v10.5).

---

## Group E POST-GATE Verify

```bash
test -s "$SESSION_DIR/phase3-plan/Phase3-report.md" && \
test "$(wc -l < "$SESSION_DIR/phase3-plan/Phase3-report.md")" -le 15 && \
grep -q "PASS\|FAIL" "$SESSION_DIR/phase3-plan/Phase3-report.md" && \
  echo "Group E PASS" || echo "Group E FAIL"
```

## Next Group

→ Group F Finalize — đọc [`phase3-plan/F-finalize.md`](F-finalize.md)
