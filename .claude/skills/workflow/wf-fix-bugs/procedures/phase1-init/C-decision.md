# Phase 1 Group C — Decision Resolution (Steps 1.7 → 1.8)

> **Entry condition:** Group B POST-GATE PASS (Wave 1 validation complete, registry+source valid).
> **Exit condition:** Step 1.8 PASS (auto-resolve E091/E092/E093 logged).
> **Next:** [phase1-init/D-session-setup.md](D-session-setup.md) (Session Setup).
>
> **Shared protocols:** None.

## Input contract (env vars từ Group B)

| Variable | Description |
|----------|-------------|
| `$PROFILE`, `$SCOPE`, `$NAME` | Flags từ Group A |
| `$NO_BROWSER`, `$SHOW_BROWSER`, `$MOBILE_MODE`, `$LLM_SCAN` | Boolean flags |
| `$DIMS_ARRAY` | Optional explicit dims |

## Output contract (env vars truyền sang Group D)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `$SCOPE` (possibly narrowed) | 1.8 | E091 auto-narrow nếu --name set + scope=all |
| `$ESTIMATED_MIN` | 1.8 | Cost estimate cho Phase1-report.md |
| `$MODULE_COUNT` | 1.8 | Phát hiện module count |
| `$AUTO_RESOLVE_NOTES` | 1.8 | Notes cho Phase1-report.md (pipe-separated lines) |

---

## Step 1.7 — Flag Conflict Detection

```bash
# Phân tích các flag combinations
if [ "$PROFILE" = "deep" ] && [ "$NO_BROWSER" = "true" ]; then
  echo "[WARN E023] --deep + --no-browser conflict — QD5/QD7/QD9 runtime probes sẽ bị skip"
fi

if [ "$LLM_SCAN" = "true" ] && [ "$PROFILE" != "deep" ] && [ "$PROFILE" != "exhaustive" ]; then
  echo "[WARN] --llm-scan recommended with deep/exhaustive profile (current: $PROFILE)"
fi

if [ "$MOBILE_MODE" = "true" ] && [ "$NO_BROWSER" = "true" ]; then
  echo "[WARN] --mobile + --no-browser conflict — mobile test cần browser, ưu tiên --no-browser"
fi

if [ -n "$DIMS_ARRAY" ]; then
  echo "[INFO] --dims explicit override: ISG auto-select bị bypass"
fi
```

**Xử lý lỗi:**

| Lỗi | Code | Hành động |
|------|------|-----------|
| `--deep` + `--no-browser` | E023 | WARN — không block, QD5/QD7/QD9 skip |
| `--llm-scan` + profile thấp | — | WARN — recommend upgrade |
| `--mobile` + `--no-browser` | — | WARN — `--no-browser` thắng |

---

## Step 1.8 — Auto-Resolve Quick Decisions (delegated to script)

> **v10.14.0:** 45 dòng inline bash extracted → `phase1-auto-resolve.sh` (~95 dòng).
>
> **v10.3 pattern:** `Auto-resolve > Default value > Warning log > CDG (last resort)`. E090/E090b DEFERRED Phase 4 Step 4.3 (just-in-time browser CDG).

```bash
# Delegate auto-resolve → eval env-style stdout
eval "$(bash .claude/scripts/wf-fix-bugs/phase1-auto-resolve.sh)"

# Verify outputs
echo "SCOPE=$SCOPE MODULE_COUNT=$MODULE_COUNT ESTIMATED_MIN=$ESTIMATED_MIN"
echo "Notes (for Phase1-report.md): $AUTO_RESOLVE_NOTES"
```

**Outputs:**
- `$SCOPE` — possibly narrowed (auto-resolve E091 nếu --name set + scope=all)
- `$ESTIMATED_MIN` — Phase 1 cost estimate cho Phase1-report.md
- `$AUTO_RESOLVE_NOTES` — Multi-line notes (pipe-separated) cho Phase1-report.md Notes section

**On Failure:** Không có failure mode — toàn bộ là auto-resolve hoặc WARN log.

**Deferred to Phase 4:** [Step 4.3 Browser CDG (E090 + E090b)](../phase4-find-bugs.md#step-43--browser-cdg-e090--e090b--gi%E1%BB%AF-inline-user-interaction).
**Removed:** E100 QD9/10/11 Recommendation Gate (duplicate Phase 3 ISG Recommender).

---

## Group C POST-GATE Verify

```bash
# Auto-resolve đã chạy, SCOPE có thể đã update
test -n "$SCOPE" && test -n "$ESTIMATED_MIN" && \
  echo "Group C PASS" || echo "Group C FAIL"
```

## Next Group

→ Group D Session Setup — đọc [`phase1-init/D-session-setup.md`](D-session-setup.md)
