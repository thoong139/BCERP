# Phase 3 Batch 1: CRITICAL Issues (Sequential)

> Sua compile errors, type errors. Chay TUAN TU (developer agent mot minh) vi cac fix co the phu thuoc lan nhau.
> Doc file nay khi bat dau Batch 1 (sau Phase 2 completed, user confirmed, `flags.dry_run == false`).

> **NEU `--dry-run`: Phase 3-6 KHONG DUOC CHAY.** Skill da STOP tai Phase 2.5.

**PRE-GATE:**
- Phase 2 completed (`jq -e '.phases.phase_2.status == "completed"' fix-status.json`)
- User confirmed fix plan
- `flags.dry_run == false`

### CI PRE-GATE: Pre-Fix Impact & Post-Fix Verification (Protocol 20 §20.5) — BẮT BUỘC

> **KHI `$GITNEXUS_AVAILABLE == "true"` HOAC `$SERENA_AVAILABLE == "true"`:** Moi code change PHẢI co impact analysis truoc va detect_changes sau. Day la buoc BẮT BUỘC — KHÔNG skip.
> **Graceful:** CI unavailable → skip CI checks → fix normally (Grep/Glob fallback). Index stale → kem caveat.

| Step | CI Task | Tool | Action |
|------|---------|------|--------|
| CI-1 | `impact_analysis` | **GitNexus** `impact({symbol}, upstream)` qua **session cache wrapper** | Truoc khi sua: chay impact analysis cho symbols se sua. Bao cao blast radius: d=1 (WILL BREAK), d=2 (LIKELY AFFECTED), d=3 (MAY NEED TESTING). Neu HIGH/CRITICAL risk → CDG render (CORE-027). CDG kem freshness warning khi index stale. **Goi qua wrapper `wf-fix-ci-cache.sh lookup` truoc — neu HIT thi su dung; MISS/BYPASS thi invoke MCP roi `wf-fix-ci-cache.sh store` (xem §CI Cache Wrapper Usage ben duoi).** |
| CI-2 | `find_references` | **Serena** `find_references` | Verify tat ca call sites cua symbol se sua → dam bao khong bo sot. |
| CI-3 | `detect_changes` | **GitNexus** `detect_changes()` | Sau khi fix: verify chi files du kien bi anh huong. Mismatch → review. |

> **CDG freshness warning:** "Warning: index N commits behind HEAD. Blast radius may be incomplete."

### CI Tool Usage Logging (Protocol 20 §20.11) — Extended voi Cache Fields (W1.2)

Sau MOI CI tool call, append entry vao `$SESSION_DIR/fix-log.json`:

```json
{
  "event": "CI_TOOL_USED",
  "task": "impact_analysis",
  "primary": "gitnexus_impact",
  "secondary": null,
  "fallback_used": false,
  "cache_hit": false,
  "cache_source": null,
  "duration_ms": 340,
  "result_count": 12,
  "freshness_behind_commits": 0,
  "freshness_level": "ok"
}
```

**Fields:** `primary` = tool da dung (gitnexus_impact, serena_find_references, gitnexus_detect_changes) | `fallback_used` = true neu primary fail → secondary/fallback | `cache_hit` = true khi response tu session cache, false khi MCP fresh call | `cache_source` = `"session_tier"` khi HIT, `null` khi MISS, `"bypass_disabled"` khi escape hatch, `"bypass_severe"` khi freshness=severe | `freshness_level` = ok / light / strong / severe / unknown.

> **CI Cache Wrapper Usage (W1.2):** Wrapper `wf-fix-ci-cache.sh` tu append CI_TOOL_USED entry — KHONG goi `jq` append thu cong de tranh duplicate log.

### CI Cache Wrapper Usage (W1.2 — BAT BUOC khi co `$GITNEXUS_AVAILABLE`)

> Muc dich: Tranh duplicate `gitnexus_impact` calls cho cung (symbol, direction) trong session. Cache key = `impact:{HEAD-sha}:{target}:{direction}`. Cache scope: session-tier in-memory (process-bound). Auto-invalidate khi commit-sha thay doi.

**Pattern thay vi goi MCP truc tiep:**

```bash
# Buoc 1: thu cache lookup
CACHED=$(bash .claude/scripts/wf-fix-ci-cache.sh lookup "$SESSION_DIR" "$SYMBOL" "upstream" 2>/dev/null || true)

if [ -n "$CACHED" ]; then
  # HIT — wrapper da log CI_TOOL_USED voi cache_hit=true
  IMPACT_JSON="$CACHED"
else
  # MISS hoac BYPASS (escape hatch / freshness=severe) — invoke MCP roi store
  START_MS=$(date +%s%3N 2>/dev/null || echo 0)
  IMPACT_JSON=$(mcp__plugin_gitnexus_gitnexus__impact "{\"target\": \"$SYMBOL\", \"direction\": \"upstream\"}")
  END_MS=$(date +%s%3N 2>/dev/null || echo 0)
  DURATION=$((END_MS - START_MS))
  # Wrapper se cache (neu khong bypass) va log CI_TOOL_USED voi cache_hit=false
  bash .claude/scripts/wf-fix-ci-cache.sh store "$SESSION_DIR" "$SYMBOL" "upstream" "$IMPACT_JSON" "$DURATION"
fi
```

**Escape hatch:**
- `export MCV3_FIX_CI_CACHE_DISABLED=1` → bypass cache hoan toan, moi call la MCP fresh; log entry van duoc append voi `cache_source=bypass_disabled`.
- Freshness=severe (>20 commits behind HEAD) → auto-bypass cache de tranh stale data.

**Guard:** CDG HIGH/CRITICAL van trigger nhu cu — data tu cache identical voi MCP fresh response cho cung commit-sha.

### CI Batch Mode (W3.2 — KHI co > 3 issues cung file trong batch)

> Muc dich: Khi nhieu issue cung 1 file (target.file_path), tranh duplicate `gitnexus_impact` cho cung file. Orchestrator goi `wf-fix-ci-batch.sh` MOT LAN dau batch → script gom issues theo primary file (`target.file_path` / `location.file` / `files_modified[0]`) → cho moi file: thuc hien cache lookup (qua wrapper `wf-fix-ci-cache.sh`). HIT → impact da co; MISS → caller invoke MCP + `store` cho file do. Sau khi batch script chay xong, agent loop chi can lookup cache (high hit rate, da pre-populated).

**Pattern goi batch script (orchestrator, MOT LAN dau Batch 1):**

```bash
# Step 0 (truoc khi spawn developer agents): pre-warm CI cache theo file
bash .claude/scripts/wf-fix-ci-batch.sh "$SESSION_DIR" 1 CRITICAL
# Output:
#   $SESSION_DIR/phase3-batch1/ci-batch-CRITICAL.json
#     Schema: [{file, impact|null, cache_status: hit|miss, issue_ids: [...]}]
#   $SESSION_DIR/fix-log.json: APPEND 1 CI_TOOL_USED entry/issue voi
#     cache_source="batch_lookup", parent_file=<file>, issue_id=<id>

# Step MISS handling (orchestrator/agent, cho moi MISS file):
jq -c '.[] | select(.cache_status == "miss")' "$SESSION_DIR/phase3-batch1/ci-batch-CRITICAL.json" | while read -r entry; do
  FILE=$(echo "$entry" | jq -r '.file')
  # Agent invoke MCP impact tool voi target=$FILE
  START_MS=$(date +%s%3N 2>/dev/null || echo 0)
  IMPACT_JSON=$(mcp__plugin_gitnexus_gitnexus__impact "{\"target\": \"$FILE\", \"direction\": \"upstream\"}")
  END_MS=$(date +%s%3N 2>/dev/null || echo 0)
  # Store vao cache (wrapper auto-log MCP fresh entry)
  bash .claude/scripts/wf-fix-ci-cache.sh store "$SESSION_DIR" "$FILE" "upstream" "$IMPACT_JSON" "$((END_MS - START_MS))"
done

# Step agent loop: voi moi issue, lookup impact tu ci-batch.json HOAC cache wrapper
# (cache da pre-populated → high hit rate, khong duplicate MCP calls)
```

**Log entry schema (batch_lookup, mot entry/issue):**

```json
{
  "event": "CI_TOOL_USED",
  "task": "impact_analysis",
  "primary": "gitnexus_impact",
  "secondary": null,
  "fallback_used": false,
  "cache_hit": true,                  // false khi cache MISS (caller se invoke MCP sau)
  "cache_source": "batch_lookup",     // CO DINH cho batch entries
  "parent_file": "src/auth/login.ts", // BAT BUOC — file ma issue thuoc ve
  "issue_id": "ISS-001",              // BAT BUOC — issue ID
  "batch": 1,
  "severity": "CRITICAL",
  "duration_ms": 5,
  "result_count": 12,
  "freshness_behind_commits": 0,
  "freshness_level": "ok",
  "timestamp": "2026-05-14T..."
}
```

> **Phan biet voi wrapper entries:** Wrapper `wf-fix-ci-cache.sh lookup` auto-log entries voi `cache_source=session_tier|null|bypass_*` (KHONG co `parent_file`/`issue_id`). Batch script entries CO `parent_file`+`issue_id` → guard rail verify `cache_source == "batch_lookup"` → `has("parent_file")` PASS.

**CDG HIGH/CRITICAL render:** Theo FILE (khong theo issue). Neu 1 file co multiple issues va cache impact cho file do la HIGH/CRITICAL → render 1 CDG cho file do (KHONG render N CDG/issue) — tranh spam user. Issue_ids cua file co trong batch JSON de user tham khao.

**Escape hatch + guard rails:**
- `export MCV3_FIX_CI_BATCH_DISABLED=1` → batch script silent skip (exit 0 som, khong tao ci-batch.json) → agent loop fall back per-issue CI calls (hanh vi cu).
- Freshness=severe → batch script chay nhung CACHE LOOKUP MISS hoan toan (wrapper bypass) → cache_status="miss" cho moi file, `cache_hit=false` cho moi log entry.
- `MCV3_FIX_CI_CACHE_DISABLED=1` → wrapper bypass cache, batch script ghi nhan miss (giong nhu severe).

**BAT BUOC khi bat dau Phase 3:** Cap nhat fix-status.json theo spec "Phase 3 BAT DAU" trong [`_shared.md`](_shared.md#fix-statusjson-update-contract).

**INPUT:** `bug-triage.md`, `$SESSION_DIR/issue-registry.json` (status=discovered, severity=CRITICAL), source code, feature specs.

**OUTPUT:** Fixed source files + updated `issue-registry.json` + appended `fix-log.json`.

### v9.2.0 Source-Aware Fix Routing (BAT BUOC)

Truoc khi fix, xac dinh fix mode dua tren `source` field cua issue:

```
FOR each issue in batch:
  IF issue.dimension_id == "QD11" → SKIP (E044), set fixability="escalate"
  IF issue.source == "static-scan" → FIX INLINE (Edit/Bash), KHONG spawn agent
  IF issue.source == "runtime" → SPAWN AGENT (developer/frontend-developer)
  IF issue.source == "llm-scan" → VERIFY EVIDENCE TRUOC:
    - Check file_path cu the? description ro rang? target.kind != "logical"?
    - Neu mo ho → escalate (E045)
    - Neu ro rang → spawn agent fix
  IF issue.source == null → DEFAULT heuristic (spawn agent)
```

Static-scan issues thuong la lint/type/format errors → fix inline, khong can agent context.
LLM-scan issues can evidence re-verification → kiem tra file_path + code snippet truoc khi spawn agent.

---

---

## Steps

| Step   | Action                                                                 | Verify              |
| ------ | ---------------------------------------------------------------------- | ------------------- |
| 3.1.0  | **Pre-Batch Resume Filter (P3):** Chay [Pre-Batch Resume Filter](_shared.md#pre-batch-resume-filter-p3--step-level-resume) voi `$BATCH_NUM=1` + CRITICAL issue list. IF `PENDING_ISSUES` empty → mark batch_1 `completed` voi metadata `resumed=true`, SKIP sang Step 3.1.4 final update. ELSE → pass `$PENDING_ISSUES` (thay vi BATCH_ISSUES) vao Step 3.1.1 agent prompt. | `PENDING_ISSUES` set; `SKIPPED_COUNT` logged |
| 3.1.0b | **Build Dependency Groups (W2.2):** Chay `bash .claude/scripts/wf-fix-dep-graph.sh "$SESSION_DIR"`. Script doc `issue-registry.json`, filter `severity=CRITICAL` (intersect `$PENDING_ISSUES`), build union-find groups dua tren overlap files (`target.file_path` / `location.file` / `files_modified[]`) HOAC cung `target.symbol`. Output: `$SESSION_DIR/phase3-batch1/dep-groups.json` (schema: `{groups, total_critical, total_groups, max_parallel_agents, escape_hatch_active}`). **Doc giai thich:** Issues KHAC group → khac file/symbol → spawn parallel SAFELY (CORE-025 owner ro, write scope tach biet). Issues CUNG group → sequential trong group. **Escape hatch:** `export MCV3_FIX_BATCH1_PARALLEL_DISABLED=1` → script tra ve 1 group all (fall back sequential cu). | `dep-groups.json` created, JSON valid, `total_groups >= 0` |
| 3.1.1  | **Spawn developer agents PER GROUP (PARALLEL):** Doc `dep-groups.json` → FOR each group in `groups[]`: spawn 1 developer agent (chon theo [Developer Selection](_shared.md#developer-selection-protocol)) voi `run_in_background: true`. Moi agent nhan TRON BO issue_ids cua group lam input list — agent xu ly issues TRONG group SEQUENTIAL (vi co the share file/symbol). Toi da `$MAX_PARALLEL_AGENTS` agents dong thoi (LPM: 3, standard: 5). NEU `total_groups == 1` HOAC `escape_hatch_active == true` → fall back hanh vi cu (1 agent sequential cho all CRITICAL). **Agent prompt phai co du 8 sections (CORE-037)** — xem [Agent Context Template](_shared.md#agent-context-template). | Agents spawned theo so groups (max `$MAX_PARALLEL_AGENTS`) |
| 3.1.1a | **Route mapping helper (SAU moi issue fix, PER AGENT):** Moi agent: FOR moi issue da fix: (a) Derive `route_map` tu file path convention: `grep -E 'router\.(push\|replace)\|<Link\|href='` trong fixed file. (b) Map file path → route tu `$TARGET_DIRS` structure (VD: `src/app/orders/page.tsx` → `/orders`). (c) Luu `route_map` vao fix entry. **Muc dich:** Phase 5.14 Playwright verify + Phase 4 docs sync dung route_map nay — KHONG can ad-hoc derive. | Routes mapped per agent |
| 3.1.1b | **Wait ALL agents + Agent Output Spot-Check (CORE-029, PER AGENT):** Wait tat ca background agents complete. FOR moi agent output: chay spot-check theo [Agent Output Spot-Check Protocol](_shared.md#agent-output-spot-check-protocol) — schema + file existence + scope + content sanity LUON CHAY (Protocol 17). **Aggregate errors PER AGENT** truoc khi retry (khong retry cross-agent). ERROR → re-spawn rieng agent do (max 3 retries) → escalate neu van fail. **CORE-025 verify:** confirm 2 agents KHONG modify cung 1 file (cross-reference `fix-log.json` entries voi `dep-groups.json` — file overlap chi duoc xay ra trong cung group). | Spot-check PASS per agent; no cross-group file overlap |
| 3.1.2  | Verify: chay `tsc --noEmit` hoac equivalent (aggregate cho tat ca files agents da sua) | Zero compile errors |
| 3.1.3  | **(Removed — gop vao 3.1.2)** Buoc verify compile errors da chay o 3.1.2. | — |
| 3.1.4  | **BAT BUOC — Cap nhat structured data + fix-status.json** (xem §Data Update Protocol ben duoi). **Race condition prevention:** Moi agent commit data cua MINH (issue updates + fix-log entries cua group do) RIENG BIET — orchestrator merge cuoi cung qua atomic write (CORE-035). | POST-GATE checks pass |

> Agent context: Xem [Agent Context Template](_shared.md#agent-context-template). Scope check: Xem [Scope Boundary Rule](_shared.md#scope-boundary-rule).
> **Escape hatch parallel:** `export MCV3_FIX_BATCH1_PARALLEL_DISABLED=1` → Step 3.1.0b emit 1 group all → Step 3.1.1 spawn 1 agent sequential (hanh vi v3.7.0).

---

## Data Update Protocol (Step 3.1.4)

> **Race condition prevention (W2.2 PARALLEL groups):** Khi co nhieu agents PARALLEL trong Batch 1 (Step 3.1.1):
> - Moi agent CHI ghi data cua MINH (issue updates cua group + fix-log entries cua group) vao TMP files trung gian (vd: `fix-log.batch1.group-{N}.tmp.json`).
> - Sau khi tat ca agents complete (Step 3.1.1b), orchestrator MERGE tmp files vao SSOT (`fix-log.json`, `issue-registry.json`) qua atomic write pattern (CORE-035): build tmp → validate JSON → mv tmp → target.
> - **KHONG cho 2 agents append truc tiep vao cung `fix-log.json`** — gay race condition mat entries.
> - issue-registry.json: moi group cap nhat doc-lap issue IDs cua minh (no overlap theo dep-graph thiet ke).

**A. issue-registry.json** — FOR moi issue vua fix:
```
UPDATE $SESSION_DIR/issue-registry.json:
  SET issues[ID].status = "fixed"
  POPULATE issues[ID].fix = {
    agent,
    completed_at,
    files_modified,
    fix_summary,
    route_map  # tu 3.1.1a
  }
  APPEND issues[ID].iteration_history[]:
    { iteration: 0, action: "fixed", timestamp }
```

**B. fix-log.json** — Neu chua ton tai:
```
1. READ template ../wf-fix-bugs/templates/phase5-triage/fix-log.json (canonical schema fix-log-v2 sau Sprint 3 XF-03)
2. STRIP `_*` metadata fields (jq walk pattern — xem _shared.md §10)
3. REPLACE placeholder `{{SESSION_ID}}` voi session_id thuc
4. WRITE to $SESSION_DIR/fix-log.json
```

Sau do APPEND entries cho moi issue:
```
{
  issue_id,
  batch: 1,
  iteration: 0,
  agent,
  source: "static-scan|runtime|llm-scan",  // v9.2.0 BAT BUOC
  files_modified,
  files_created,
  change_type,
  behavior_changed,
  route_map,
  summary,
  timestamp
}
```

**C. fix-status.json** — UPDATE theo spec "Sau Batch 1" trong [`_shared.md`](_shared.md#fix-statusjson-update-contract).

**D. checkpoint.json** — UPDATE voi:
- `batch_1` completed
- `context_digest` merged (ADDITIVE — xem [Context Digest Generation](_shared.md#context-digest-generation))

---

## POST-GATE

```bash
jq '.phases.phase_3.batches.batch_1.status == "completed"' $SESSION_DIR/fix-status.json \
  && jq '[.issues[] | select(.status=="fixed")] | length > 0' $SESSION_DIR/issue-registry.json \
  && test -s $SESSION_DIR/checkpoint.json
```

**FAIL handling:**
- Neu compile errors persist → ESCALATE, KHONG proceed Batch 2
- Neu agent spawn that bai → retry x3, neu van fail → LOG E005, escalate

**Next:** `phase3-batch2.md` (HIGH issues, PARALLEL).
