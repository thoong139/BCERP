# Phase 7 Group D — Mobile Gate + Finalize Bug Dashboard (Step 7.4)

> **Entry condition:** Group C POST-GATE PASS (CQG-2 PASS hoặc N/A hoặc CDG ACCEPT). Hoặc trực tiếp từ Group A nếu `E005_HEALTHY=true` (skip B + C).
> **Exit condition:** `bug-dashboard.md` finalized + Mobile Gate WARN nếu thiếu evidence (không block).
> **Next:** [phase7-verify/E-reports.md](E-reports.md) (Generate 4 Reports).
>
> **Shared protocols cần thiết:**
> - [`_shared/04-error-handling.md`](../_shared/04-error-handling.md) — E045 (WARN only), E073

## Input contract (env vars từ Group C hoặc A)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$E005_HEALTHY`, `$MOBILE_MODE` | Pipeline state |
| `$FIXED_COUNT`, `$DEFERRED_COUNT`, `$FAILED_COUNT` | Counts từ Phase 6 |
| `phase4-find-bugs/Phase4-report.md` | Mobile evidence source |
| `phase6-execute/fix-report.md` | Source cho dashboard finalize (non-E005) |

## Output contract (env vars truyền sang Group E)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `$SESSION_DIR/bug-dashboard.md` | 7.4 | Final populate (session root, version counter bumped) |
| `TOTAL_ISSUES` | 7.4 | Re-exported từ finalize-dashboard.sh output |
| Mobile WARN log | 7.4 (nếu thiếu) | E045 ghi chú vào Phase7-report (Group E) |

---

## Step 7.4 — Mobile Gate + Finalize Bug Dashboard

**Mục đích:** Gộp Mobile gate check (WARN only) + finalize bug-dashboard với trạng thái cuối cùng.

```bash
export E005_HEALTHY MOBILE_MODE FIXED_COUNT DEFERRED_COUNT FAILED_COUNT
PHASE7_S4=$(bash .claude/scripts/wf-fix-bugs/finalize-dashboard.sh) || RC=$?

if [ "${RC:-0}" -ne 0 ]; then
  echo "ERROR: dashboard finalize fail (E073)" >&2
  exit "$RC"
fi

TOTAL_ISSUES=$(echo "$PHASE7_S4" | jq -r '.total_issues')
export TOTAL_ISSUES
```

Script:
1. **Mobile Gate** (CORE-011 forensic check): nếu `MOBILE_MODE=true` → check `Phase4-report.md` có mobile/device/viewport/responsive references. Zero refs → WARN E045 (không block).
2. **Dashboard Finalize**: re-generate `bug-dashboard.md` với:
   - E005=true: "Hệ thống HEALTHY — không phát hiện lỗi"
   - E005=false: Tổng/Fixed/Deferred/Failed counts + unresolved details + next steps
3. Version counter bump (v10.11.0 pattern) — HTML markers `<!-- bug-dashboard-version: N+1 -->` + `last-writer: phase-7-4`.

**VERIFY:**

```bash
test -s "$SESSION_DIR/bug-dashboard.md"
if [ "$E005_HEALTHY" = "true" ]; then
  grep -qiE "healthy|không phát hiện lỗi" "$SESSION_DIR/bug-dashboard.md"
else
  grep -qE "Tổng|Đã sửa" "$SESSION_DIR/bug-dashboard.md"
fi
```

**On Failure:**

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E045 | Mobile evidence thiếu (MOBILE_MODE=true) | WARN, ghi chú vào Phase7-report (Group E), không block |
| E073 | Dashboard write fail (exit 3) | Retry x1 → `_phase7_trace_fail "E073"` → E001 |

**Cross-ref:** CORE-011 (Forensic), CORE-031 (Template), CORE-035 (Atomic Write).

---

## Group D POST-GATE Verify

```bash
test -s "$SESSION_DIR/bug-dashboard.md" && \
test -n "$TOTAL_ISSUES" && \
  echo "Group D PASS (TOTAL_ISSUES=$TOTAL_ISSUES, E005=$E005_HEALTHY)" || echo "Group D FAIL"
```

## Next Group

→ Group E Generate 4 Reports — đọc [`phase7-verify/E-reports.md`](E-reports.md)
