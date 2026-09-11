# Phase 3 Batch 3: MEDIUM + LOW Issues (Mixed AUTO_FIX + AGENT_FIX)

> Xu ly CA HAI loai: (1) AUTO_FIX (lint, orphan REQ-ID, format) va (2) AGENT_FIX issues o MEDIUM/LOW can tao UI component/helper moi.
> AGENT_FIX agents chay PARALLEL voi auto-fix steps de tiet kiem thoi gian.

**PRE-GATE:** Batch 2 completed (`jq -e '.phases.phase_3.batches.batch_2.status == "completed"' fix-status.json`).

### CI PRE-GATE: Pre-Fix Impact & Post-Fix Verification (Protocol 20 §20.5) — BẮT BUỘC

> **Cung pattern Batch 1-2:** KHI CI available → moi code change PHẢI co impact analysis truoc va detect_changes sau.
> **Graceful:** CI unavailable → skip → fix normally. MEDIUM/LOW issues — CI checks khuyen nghi manh me.

| Step | CI Task | Tool | Action |
|------|---------|------|--------|
| CI-1 | `impact_analysis` | **GitNexus** `impact({symbol}, upstream)` qua **session cache wrapper** | Truoc khi sua: impact analysis. HIGH/CRITICAL → CDG. MEDIUM/LOW → log warning. **Goi qua `wf-fix-ci-cache.sh lookup` truoc — neu HIT thi su dung; MISS/BYPASS thi invoke MCP roi `wf-fix-ci-cache.sh store` (xem mau code o batch1.md §CI Cache Wrapper Usage).** |
| CI-2 | `find_references` | **Serena** `find_references` | Verify call sites (neu applicable). |
| CI-3 | `detect_changes` | **GitNexus** `detect_changes()` | Sau khi fix: verify affected scope. |

### CI Tool Usage Logging (Protocol 20 §20.11) — Extended voi Cache Fields (W1.2)

Sau MOI CI tool call, append entry vao `$SESSION_DIR/fix-log.json`. Format: `{event: "CI_TOOL_USED", task, primary, secondary, fallback_used, cache_hit, cache_source, duration_ms, result_count, freshness_behind_commits, freshness_level}`. MEDIUM/LOW issues — van log CI usage day du, khong skip.

**Cache fields (W1.2):**
- `cache_hit`: `true` khi tra ket qua tu session cache, `false` khi goi MCP fresh.
- `cache_source`: `"session_tier"` khi HIT, `null` khi MISS, `"bypass_disabled"` khi `MCV3_FIX_CI_CACHE_DISABLED=1`, `"bypass_severe"` khi `freshness_level=severe`.

**Pattern CI-1 voi cache:** Xem [`phase3-batch1.md` §CI Cache Wrapper Usage](phase3-batch1.md) — pattern lookup → MCP fallback → store. Wrapper TU append CI_TOOL_USED entry (KHONG goi `jq` append thu cong).

### CI Batch Mode (W3.2 — KHI co > 3 issues cung file trong batch MEDIUM/LOW)

> Cung pattern Batch 1 — xem chi tiet o [`phase3-batch1.md` §CI Batch Mode](phase3-batch1.md). Voi Batch 3, orchestrator goi 2 LAN (MEDIUM va LOW) neu co issues cung file:
>
> ```bash
> bash .claude/scripts/wf-fix-ci-batch.sh "$SESSION_DIR" 3 MEDIUM
> bash .claude/scripts/wf-fix-ci-batch.sh "$SESSION_DIR" 3 LOW
> ```
>
> Output: `$SESSION_DIR/phase3-batch3/ci-batch-{MEDIUM,LOW}.json` + per-issue CI_TOOL_USED entries voi `cache_source=batch_lookup`, `parent_file`, `issue_id`. MEDIUM/LOW issues thuong it overlap file → batching huu ich chu yeu khi project lon co cluster bugs trong cung module.
>
> **Note auto-fix steps (3.3.1-3.3.3):** Khong can batch CI vi auto-fix khong dung gitnexus impact (lint/format/REQ-ID inject). Chi AGENT_FIX issues (3.3.0) can batch nay.
>
> **Escape hatch:** `MCV3_FIX_CI_BATCH_DISABLED=1` → silent skip → fall back per-issue calls.

**INPUT:** `$SESSION_DIR/issue-registry.json` (severity=MEDIUM or LOW, action=AUTO_FIX or AGENT_FIX).

**OUTPUT:** Fixed files + optional new component files + `fix-log.json` (final flush).

---

## Steps

| Step   | Action | Verify |
| ------ | ------ | ------ |
| 3.3.PRE | **Pre-Batch Resume Filter (P3):** Chay [Pre-Batch Resume Filter](_shared.md#pre-batch-resume-filter-p3--step-level-resume) voi `$BATCH_NUM=3` + MEDIUM/LOW/AGENT_FIX issue list. IF `PENDING_ISSUES` empty → mark batch_3 `completed` voi `resumed=true`, SKIP sang Step 3.3.4 final update. ELSE → pass `$PENDING_ISSUES` (thay vi BATCH_ISSUES) cho cac sub-steps duoi day. | `PENDING_ISSUES` set |
| 3.3.0  | **AGENT_FIX issues (conditional — PARALLEL voi 3.3.1-3.3.3):** NEU `$PENDING_ISSUES` co issue nao voi `action = AGENT_FIX` (VD: tao UI dialog, helper function, utility component co spec ro): (a) Group AGENT_FIX issues theo agent type (frontend-developer / developer), (b) Spawn moi group (run_in_background: true) voi context: `"Tao [component/helper] theo spec: [mo ta tu triage]. File dich de xuat: [target file]. REQ-ID: [REQ-ID neu co]. Quy tac: co REQ-ID comment, khong modify files ngoai $TARGET_DIRS."` Max `$MAX_PARALLEL_AGENTS` agents dong thoi. Ghi agents da spawn vao `checkpoint.json`. | AGENT_FIX agents spawned (hoac skip neu khong co) |
| 3.3.1  | Auto-fix lint errors (eslint --fix, prettier, etc.) — chay PARALLEL voi 3.3.0 agents | Lint clean     |
| 3.3.2  | Them REQ-ID comments vao orphan files — chay PARALLEL voi 3.3.0 agents | REQ-IDs added  |
| 3.3.3  | Fix registry format errors — chay PARALLEL voi 3.3.0 agents | Format valid   |
| 3.3.0a | **Wait AGENT_FIX agents complete (conditional):** NEU co agents tu 3.3.0 → wait ALL complete. Verify: files duoc tao/modified theo spec (check file existence + non-empty). NEU agent fail → LOG warning, chuyen issue sang ESCALATE, tiep tuc. | Agent outputs verified hoac escalated |
| 3.3.0b | **Agent Output Spot-Check (CORE-029) cho AGENT_FIX outputs:** Run spot-check theo [Agent Output Spot-Check Protocol](_shared.md#agent-output-spot-check-protocol) — kiem tra schema + file existence + scope + content sanity cho moi agent output. Bo qua AUTO_FIX steps (3.3.1-3.3.3) — auto-fix khong can spot-check vi khong co agent. ERROR → re-spawn agent (max 3 retries) → escalate neu van fail. | Spot-check PASS per AGENT_FIX output |
| 3.3.4  | **BAT BUOC — Cap nhat structured data + fix-status.json** (xem §Data Update Protocol ben duoi) | POST-GATE checks pass |
| 3.4    | **BAT BUOC — Fix log flush** (xem §Fix Log Flush ben duoi) | Log count matches fixed count |

> **CHECKPOINT sau moi batch.** Neu context > 80% → save checkpoint, thong bao user dung `--resume`.
> **LPM + scope=all:** Khi `$LARGE_PROJECT = True` VA `--scope=all`, them checkpoint sau moi system trong batch (group issues by system → fix per system → checkpoint). Ly do: du an lon nhieu systems, mat progress 1 system = mat nhieu cong.

---

## Data Update Protocol (Step 3.3.4)

**A. issue-registry.json** — Tuong tu Batch 1 3.1.4A, cho Batch 3 issues.

**B. fix-log.json** — APPEND entries cho Batch 3:
```
{ issue_id, batch: 3, iteration: 0, agent, ... }
```

**C. fix-status.json** — UPDATE theo spec "Sau Batch 3" trong [`_shared.md`](_shared.md#fix-statusjson-update-contract) (phase_3.status="completed", progress_pct=65).

**D. checkpoint.json** — UPDATE voi batch_3 completed + context_digest merged (ADDITIVE).

---

## Fix Log Flush (Step 3.4 — BAT BUOC sau tat ca batches)

> Verify fix-log.json duoc populate day du truoc khi chuyen sang Phase 4/5.

**Muc dich:** Day la "flush" operation — dam bao khong co fix data bi mat giua agent context va disk.

| Step | Action | Verify |
| ---- | ------ | ------ |
| 3.4  | (1) READ `$SESSION_DIR/fix-log.json`. (2) VERIFY: `jq '.entries \| length' fix-log.json` == so luong issues co `status == "fixed"` trong issue-registry.json. (3) NEU mismatch → APPEND missing entries tu agent outputs. (4) VERIFY: moi entry phai co `issue_id`, `files_modified` (non-empty), `summary` (non-null). (5) NEU entry khong hop le → LOG warning, skip entry. (6) WRITE `$SESSION_DIR/fix-log.json` updated. | `jq '[.issues[] \| select(.status=="fixed")] \| length' $SESSION_DIR/issue-registry.json == jq '.entries \| length' $SESSION_DIR/fix-log.json` |

---

## POST-GATE (CORE-012 — tiered T1-T4)

| Tier | Check | Verify |
|------|-------|--------|
| T1 | `test -f $SESSION_DIR/fix-log.json && test -f $SESSION_DIR/fix-status.json && test -f $SESSION_DIR/issue-registry.json && test -f $SESSION_DIR/checkpoint.json` | Files exist |
| T2 | `test -s $SESSION_DIR/fix-log.json && test -s $SESSION_DIR/fix-status.json && test -s $SESSION_DIR/issue-registry.json` | Non-empty |
| T3 | `jq '.' $SESSION_DIR/fix-log.json && jq '.' $SESSION_DIR/fix-status.json && jq '.' $SESSION_DIR/issue-registry.json && jq '.' $SESSION_DIR/checkpoint.json` | All JSON valid |
| T4 | `jq -e '.phases.phase_3.status == "completed"' fix-status.json && jq -e '.progress_pct >= 65' fix-status.json && jq -e '.entries \| length >= 0' fix-log.json` | Required content present |

Chi PASS POST-GATE khi TAT CA T1-T4 pass. FAIL bat ky tier → rollback + retry (max 3) → escalate.

**SCOPE CHECK:** Verify ALL modified files thuoc `$TARGET_DIRS`. Neu co file ngoai scope bi modify → ROLLBACK file do + log WARNING. Xem [Scope Boundary Rule](_shared.md#scope-boundary-rule).

**Context Digest:** Sau POST-GATE, merge `context_digest` vao `checkpoint.json`. Xem [Context Digest Generation](_shared.md#context-digest-generation).

**Next:** `phase4a-docs-sync.md` (docs sync).
