# Phase 3 Batch 2: HIGH Issues (PARALLEL)

> Sua test failures, security issues, domain-specific issues. Chay PARALLEL (developer + security + domain expert) vi output files KHAC NHAU.
> Doc file nay khi bat dau Batch 2 (sau Batch 1 completed).

> **Protocol 7 (PAR-11):** Developer + security PHAI chay PARALLEL (output files khac nhau — khong ghi cung file).

**PRE-GATE:** Batch 1 completed (`jq -e '.phases.phase_3.batches.batch_1.status == "completed"' fix-status.json`).

### CI PRE-GATE: Pre-Fix Impact & Post-Fix Verification (Protocol 20 §20.5) — BẮT BUỘC

> **Cung pattern Batch 1:** KHI CI available → moi code change PHẢI co impact analysis truoc va detect_changes sau.
> **Graceful:** CI unavailable → skip → fix normally.

| Step | CI Task | Tool | Action |
|------|---------|------|--------|
| CI-1 | `impact_analysis` | **GitNexus** `impact({symbol}, upstream)` qua **session cache wrapper** | Truoc khi sua HIGH issues: impact analysis cho symbols se sua. HIGH/CRITICAL risk → CDG render (CORE-027). **Goi qua `wf-fix-ci-cache.sh lookup` truoc — neu HIT thi su dung; MISS/BYPASS thi invoke MCP roi `wf-fix-ci-cache.sh store` (xem mau code o batch1.md §CI Cache Wrapper Usage).** |
| CI-2 | `find_references` | **Serena** `find_references` | Verify call sites cua symbol se sua. |
| CI-3 | `detect_changes` | **GitNexus** `detect_changes()` | Sau khi fix: verify affected scope. |

### CI Tool Usage Logging (Protocol 20 §20.11) — Extended voi Cache Fields (W1.2)

Sau MOI CI tool call, append entry vao `$SESSION_DIR/fix-log.json` voi format: `{event: "CI_TOOL_USED", task, primary, secondary, fallback_used, cache_hit, cache_source, duration_ms, result_count, freshness_behind_commits, freshness_level}`. CI-1/CI-2/CI-3 moi buoc phai co log entry.

**Cache fields (W1.2):**
- `cache_hit`: `true` khi tra ket qua tu session cache, `false` khi goi MCP fresh.
- `cache_source`: `"session_tier"` khi HIT, `null` khi MISS, `"bypass_disabled"` khi `MCV3_FIX_CI_CACHE_DISABLED=1`, `"bypass_severe"` khi `freshness_level=severe`.

**Pattern CI-1 voi cache:** Xem [`phase3-batch1.md` §CI Cache Wrapper Usage](phase3-batch1.md) — pattern lookup → MCP fallback → store. Wrapper TU append CI_TOOL_USED entry (KHONG goi `jq` append thu cong).

### CI Batch Mode (W3.2 — KHI co > 3 issues cung file trong batch HIGH)

> Cung pattern Batch 1 — xem chi tiet o [`phase3-batch1.md` §CI Batch Mode](phase3-batch1.md). Orchestrator goi MOT LAN dau Batch 2 voi severity=HIGH:
>
> ```bash
> bash .claude/scripts/wf-fix-ci-batch.sh "$SESSION_DIR" 2 HIGH
> ```
>
> Output: `$SESSION_DIR/phase3-batch2/ci-batch-HIGH.json` + per-issue CI_TOOL_USED entries voi `cache_source=batch_lookup`, `parent_file`, `issue_id`. MISS files: orchestrator/agent invoke MCP roi `wf-fix-ci-cache.sh store`. Agent loop dung impact da pre-populated trong batch JSON hoac cache wrapper (high hit rate).
>
> **CDG HIGH/CRITICAL render:** Theo FILE (khong 1 CDG/issue). Issue_ids cua file co trong batch JSON.
>
> **Escape hatch:** `MCV3_FIX_CI_BATCH_DISABLED=1` → silent skip → fall back per-issue calls.

**INPUT:** `$SESSION_DIR/issue-registry.json` (severity=HIGH), domain routing info.

**OUTPUT:** Fixed files + updated `issue-registry.json` + appended `fix-log.json`.

---

## Steps

| Step   | Action | Verify |
| ------ | ------ | ------ |
| 3.2.0  | **Pre-Batch Resume Filter (P3) + Sub-batch check:** <br>**(a)** Chay [Pre-Batch Resume Filter](_shared.md#pre-batch-resume-filter-p3--step-level-resume) voi `$BATCH_NUM=2` + HIGH issue list. IF `PENDING_ISSUES` empty → mark batch_2 `completed` voi `resumed=true`, SKIP sang Step 3.2.4 final update. <br>**(b)** Voi `$PENDING_ISSUES` non-empty: neu len > 15 → chia sub-batches (max 10 issues/sub-batch, max `$MAX_PARALLEL_AGENTS` agents — LPM: 3, standard: 5). Moi sub-batch PARALLEL internal, SEQUENTIAL giua sub-batches. | `PENDING_ISSUES` set; Sub-batches planned |
| 3.2.1  | Spawn `developer` agent (run_in_background: true): fix test failures + logic bugs | PARALLEL ↓ |
| 3.2.2  | Spawn `security` agent (run_in_background: true): fix security issues (neu co) | PARALLEL ↕ — dong thoi 3.2.1 |
| 3.2.2a | **Domain expert review (conditional):** Neu batch co issues voi `$ISSUE_DOMAIN != null` → spawn domain expert (run_in_background: true) REVIEW (khong fix). Max 1 domain expert per batch. Xem [Domain Expert Routing](_shared.md#domain-expert-routing). | PARALLEL ↑ — dong thoi 3.2.1+3.2.2 |
| 3.2.3  | Wait ALL agents complete → chay lai tests. Neu domain expert co concerns → developer agent fix lai theo feedback | All tests pass + domain validated |
| 3.2.3a | **Agent Output Spot-Check (CORE-029):** Run spot-check cho moi agent output (developer + security + domain expert) theo [Agent Output Spot-Check Protocol](_shared.md#agent-output-spot-check-protocol). Batch-level spot-check: aggregate errors truoc khi retry. ERROR → re-spawn agent do (max 3 retries) → escalate neu van fail. | Spot-check PASS per agent |
| 3.2.4  | **BAT BUOC — Cap nhat structured data + fix-status.json** (xem §Data Update Protocol ben duoi) | POST-GATE checks pass |

---

## Sub-Batch Strategy (khi > 15 issues)

```
NEU batch_2_issues.length > 15:
  sub_batches = chunk(batch_2_issues, 10)  // moi sub-batch toi da 10 issues

  FOR each sub_batch IN sub_batches:
    developer_issues = sub_batch.filter(type IN ["test_failure", "logic_bug"])
    security_issues  = sub_batch.filter(type == "security_issue")

    Spawn PARALLEL (run_in_background: true):
      - developer(developer_issues)
      - security(security_issues)

    Wait ALL complete
    Validate sub_batch outputs
    CHECKPOINT: save sub_batch progress vao fix-status.json

  // Max $MAX_PARALLEL_AGENTS agents dong thoi (LPM: 3, standard: 5 — Protocol 6.6 + 7.5)
```

---

## Data Update Protocol (Step 3.2.4)

**A. issue-registry.json** — Tuong tu Batch 1 3.1.4A, cho Batch 2 issues (set status=fixed, populate fix{}, append iteration_history[]).

**B. fix-log.json** — APPEND entries cho Batch 2:
```
{ issue_id, batch: 2, iteration: 0, agent, ... }
```

**C. fix-status.json** — UPDATE theo spec "Sau Batch 2" trong [`_shared.md`](_shared.md#fix-statusjson-update-contract). Neu co sub-batches: ghi them `sub_batch_progress`.

**D. checkpoint.json** — UPDATE (READ → ADDITIVE merge context_digest → WRITE):
```
1. READ current $SESSION_DIR/checkpoint.json
2. UPDATE: batch_2 completed, context_digest merged
3. WRITE
```

---

## POST-GATE

```bash
jq '.phases.phase_3.batches.batch_2.status == "completed"' $SESSION_DIR/fix-status.json \
  && jq '.entries | length > 0' $SESSION_DIR/fix-log.json \
  && test -s $SESSION_DIR/checkpoint.json
```

**FAIL handling:**
- Neu agent crash → retry x3, neu van fail → escalate issue do, tiep tuc issues khac
- Neu domain expert say business rule vi pham → developer fix lai theo feedback TRUOC KHI proceed

**Next:** `phase3-batch3.md` (MEDIUM+LOW + AGENT_FIX).
