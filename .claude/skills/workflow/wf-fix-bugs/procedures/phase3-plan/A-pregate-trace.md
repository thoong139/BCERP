# Phase 3 Group A — PRE-GATE + TRACE START (Steps 3.1 → 3.2)

> **Entry condition:** SKILL.md route đến Phase 3 (đọc index `phase3-plan.md` trước → load file này).
> **Exit condition:** Step 3.2 PASS (TRACE START event appended).
> **Next:** [phase3-plan/B-isg-partition.md](B-isg-partition.md) (ISG + Partition).
>
> **Shared protocols cần thiết:** None (PRE-GATE pure verification + TRACE delegate sang `phase-trace-start.sh`).

## Input contract (env vars có sẵn từ Phase 1/2)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR` | Session root từ Phase 1 |
| `$DIMS_ARRAY`, `$PROFILE`, `$SCOPE` | Phase 1 CLI flags |
| `$INTERFACE_TYPE`, `$MOBILE_MODE` | Phase 2 Step 2.3 outputs |

## Output contract (env vars truyền sang Group B)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `INTERFACE_TYPE`, `TOTAL_FILES`, `MODULE_COUNT` | 3.1 | Extracted từ scope-analysis.json |
| TRACE START event appended | 3.2 | session-log.json events[-1].phase = "phase3" |

---

## Step 3.1 — PRE-GATE: Verify Phase 2 Complete

**Mục đích:** Forensic PRE-GATE (CORE-011) — Phase 2 completed + scope-analysis hợp lệ.

```bash
# Verify content (không chỉ existence)
test -s "$SESSION_DIR/fix-status.json"
jq -e '.phases.phase2.status == "completed"' "$SESSION_DIR/fix-status.json"
test -s "$SESSION_DIR/phase2-scan/scope-analysis.json"
test -s "$SESSION_DIR/phase2-scan/code-inventory.json"
test -s "$SESSION_DIR/phase2-scan/doc-inventory.json"

# Extract key metrics
INTERFACE_TYPE=$(jq -r '.interface_type' "$SESSION_DIR/phase2-scan/scope-analysis.json")
TOTAL_FILES=$(jq -r '.code.total_files' "$SESSION_DIR/phase2-scan/scope-analysis.json")
MODULE_COUNT=$(jq -r '.modules | length // 0' "$SESSION_DIR/phase2-scan/scope-analysis.json")
export INTERFACE_TYPE TOTAL_FILES MODULE_COUNT
```

**VERIFY:** `interface_type ∈ {web|mobile|hybrid|api-only}` + `TOTAL_FILES ≥ 0`.

**On Failure:**

| Code | Tình huống | Hành động |
|------|-----------|-----------|
| E020 | Phase 2 chưa completed | Dừng, chạy Phase 2 hoặc `--resume` |
| E021 | scope-analysis/code-inventory/doc-inventory missing | Re-run Phase 2 |
| E023 | interface_type không hợp lệ | Re-run Phase 2 Step 2.3 |

**Cross-ref:** CORE-002, CORE-011, CORE-034.

---

## Step 3.2 — TRACE START (delegated to shared script)

> **v10.16.0:** Inline `jq events += [...]` block thay bằng `phase-trace-start.sh` (shared cho Phase 2-7).

```bash
# Delegate dual-write trace → silent on success
SESSION_DIR="$SESSION_DIR" PHASE_NUM=3 \
  PHASE_METADATA="{\"dimensions\":\"$DIMS_ARRAY\",\"profile\":\"$PROFILE\"}" \
  bash .claude/scripts/wf-fix-bugs/phase-trace-start.sh

# Verify session-local trace event appended
jq -e '.events[-1].phase == "phase3" and .events[-1].event == "START"' \
  "$SESSION_DIR/session-log.json" >/dev/null
```

**On Failure:** E001 → disk/permission check, exit 35 từ script.

**Cross-ref:** CORE-026 (Execution Trace), CORE-035 (Atomic Write).

---

## Group A POST-GATE Verify

```bash
# Phase 2 completed + extract done + TRACE START appended
jq -e '.phases.phase2.status == "completed"' "$SESSION_DIR/fix-status.json" >/dev/null && \
test -n "$INTERFACE_TYPE" && test -n "$TOTAL_FILES" && \
jq -e '.events[-1].phase == "phase3" and .events[-1].event == "START"' \
  "$SESSION_DIR/session-log.json" >/dev/null && \
  echo "Group A PASS" || echo "Group A FAIL"
```

## Next Group

→ Group B ISG + Partition — đọc [`phase3-plan/B-isg-partition.md`](B-isg-partition.md)
