# Resume & Status — wf-fix-bugs v10.18.0

> Procedure này xử lý `--status` (hiển thị trạng thái) và `--resume` (resume từ checkpoint).
> Được gọi từ Phase 1 Step 1.3 (Flag dispatch).
> **Contract:** Output paths và session data PHẢI khớp với `_contract.json §outputs.working[]`.
>
> **Shared protocols (lazy-load):**
> - [`_shared/17-session-isolation.md`](_shared/17-session-isolation.md) — Session Isolation format
>
> **KHÔNG đọc toàn bộ `_shared/` folder.**

## Lazy-Load Architecture Impact on Resume (v10.18.0)

> Đọc TRƯỚC khi xử lý --resume — quy ước cho lazy-load split (Phase 1, 3, 4, 5, 6, 7 đều có group folders).

| Aspect | Impact on resume |
|--------|------------------|
| **Entry point per phase** | `phase{N}-{name}.md` (index router) — R10 vẫn load file này, lazy-load split GIỮ entry pattern |
| **Group folder structure** | `$SESSION_DIR/phase{N}-{name}/` chứa output + có thể thêm subdirectories (vd: `lanes/` cho Phase 4) |
| **Per-lane preservation Phase 4 SPECIAL CASE** | R5 KHÔNG archive `phase4-find-bugs/lanes/QD*/` nếu `lane-status.json status='completed'` (xem §Phase 4 Selective Archive bên dưới) |
| **finalize-phase4.sh aggregation SPECIAL CASE** | Aggregate `signals_total` từ filesystem scan — KHÔNG được mất `lanes/` completed nếu không sẽ gây false E005 healthy (downstream Phase 5 thấy 0 signals → skip Phase 6/7 sai) |
| **Group-level resume hint** | R10 PHẢI đọc `phase{N}-{name}/POST-GATE.md` §Resume Logic để route vào group cuối cùng completed thay vì luôn Group A (xem §R10 Group-Level Routing bên dưới) |
| **POST-GATE markers per group** | Mỗi group có "Group X POST-GATE Verify" bash check — orchestrator có thể re-run các check để xác định group nào đã PASS |

**Quy tắc:** Lazy-load không thay đổi resume granularity (vẫn phase-level), nhưng cho phép **smart group-routing** trong phase đang in_progress, và **per-lane preservation** cho Phase 4 (11 parallel lanes — re-spawn ALL gây mất ~2.7h × quota).

---

## --status Handler

### Mục đích

Hiển thị trạng thái pipeline hiện tại (read-only), không thực thi gì.

### Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| S1 | **Find session:** Thứ tự ưu tiên: (1) `$SESSION_ID_FLAG` từ `--session=` → validate tồn tại trong `.mc-data/work/wf-fix-bugs/sessions/$SESSION_ID_FLAG/` → nếu missing: ERROR "Session không tồn tại: $SESSION_ID_FLAG" + STOP. (2) `$SESSION_DIR` đã set → dùng. (3) Tìm session gần nhất (sort by `fix-status.json.updated_at`). Nếu không có session nào → "Chưa có session nào. Chạy /wf-fix-bugs để bắt đầu." → STOP. | Read + Bash | Session found |
| S2 | **Read fix-status.json:** Load trạng thái từng phase (completed/in_progress/pending/failed). | Read | Status loaded |
| S3 | **Display header:** Session ID, scope, name, profile, pipeline_status, started_at, updated_at. | — | Header displayed |
| S4 | **Display phase table:** | — | Table displayed |

```
| Phase | Name | Status | Duration | Notes |
|-------|------|--------|----------|-------|
| 1 | Init | completed | 2m | CI: GitNexus ✓, Serena ✓ |
| 2 | Scan | completed | 5m | web, 45 files, 3 modules |
| 3 | Plan | completed | 1m | 5 dims, 2 workloads |
| 4 | Find Bugs | in_progress | — | 3/5 lanes done |
| 5 | Triage | pending | — | — |
| 6 | Execute | pending | — | — |
| 7 | Verify | pending | — | — |
```

| S5 | **Display CI tools status:** GitNexus available/unavailable, Serena available/unavailable, index freshness. | — | CI status displayed |
| S6 | **Display metrics (nếu có):** Signals found, issues registered, bugs fixed (từ `fix-status.json`). | — | Metrics displayed |
| S7 | **Next action suggestion:** Dựa trên pipeline_status: nếu DONE → "Chạy /wf-verify-sync hoặc /status". Nếu FAIL → "Chạy --resume để tiếp tục". Nếu in_progress → "Chạy --resume để tiếp tục từ Phase {N}". | — | Suggestion displayed |

---

## --resume Handler

### Mục đích

Resume pipeline từ checkpoint gần nhất. Smart routing dựa trên `fix-status.json`.

### Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| R1 | **Find session (P4):** Thứ tự ưu tiên: (1) `$SESSION_ID_FLAG` từ `--session=<ID>` → validate tồn tại → ERROR nếu missing. (2) `$SESSION_DIR` đã set. (3) Tìm session gần nhất (sort by `fix-status.json.updated_at`). Không có session → STOP "Không có session để resume." | Read + Bash | Session found |
| R2 | **Read fix-status.json:** Load trạng thái pipeline. Check `pipeline_status`. | Read | Status loaded |
| R3 | **Check pipeline DONE (P6 strategy-aware):** IF `pipeline_status = "DONE"`: <br>• `RESUME_STRATEGY=prompt` (default) → AskUserQuestion: Re-run / Cancel. <br>• `RESUME_STRATEGY=auto` → CANCEL silently + INFO "Pipeline đã DONE, không cần resume." <br>• `RESUME_STRATEGY=force-fresh` → tạo fresh session ngay (skip R4-R10, route Phase 1 fresh). | AskUserQuestion (prompt) hoặc Bash | Decision recorded |
| R4 | **Check pipeline FAILED (P6 strategy-aware):** IF `pipeline_status = "failed"`: <br>• `RESUME_STRATEGY=prompt` → AskUserQuestion: Resume / Fresh run / Cancel. <br>• `RESUME_STRATEGY=auto` → tự động Resume từ phase failed (đúng pattern user expect cho CI/cron). <br>• `RESUME_STRATEGY=force-fresh` → tạo fresh session ngay. | AskUserQuestion (prompt) hoặc Bash | Decision recorded |
| R5 | **Find resume point + partial output handling (F08.022 + v10.18.0 Phase 4 SPECIAL CASE):** Tìm phase cuối cùng có `status = "completed"`. Phase tiếp theo sẽ là resume point. **E005 EDGE CASE:** nếu `phase5.e005_healthy = true` → bypass "last completed" lookup, route thẳng Phase 7 (setup-triage.sh đã mark phase5+phase6=completed nhưng routing table line 92 ưu tiên flag). Nếu phase đang `in_progress` → re-run phase đó từ đầu (step-level resume không hỗ trợ). **TRƯỚC khi re-run partial outputs:** apply archive logic theo phase: <br>**Phases 1/2/3/5/6/7 (wholesale archive):** MOVE toàn bộ `$SESSION_DIR/phase{N}-{name}/` sang `$SESSION_DIR/phase{N}-{name}.partial-$(date +%Y%m%dT%H%M%S)/`. <br>**Phase 4 SPECIAL CASE (selective archive — preserve completed lanes):** scan `lanes/QD*/lane-status.json` → archive CHỈ lanes với status='failed'/'in_progress', GIỮ lanes 'completed'/'skipped' nguyên vẹn. Phase 4 POST-GATE Resume Logic sau đó skip lanes completed, chỉ re-dispatch pending. Bảo vệ `signals_total` aggregation trong finalize-phase4.sh khỏi false E005 healthy. Xem §Phase 4 Selective Archive bên dưới. | Read + Bash | Resume point found, partials archived (selective cho Phase 4) |
| R6 | **Check staleness:** Đọc `session-log.json` → tính thời gian từ CHECKPOINT cuối. IF >30% files changed since checkpoint → E013: WARN, AskUserQuestion "Code đã thay đổi đáng kể. Resume có thể không chính xác." Options: Continue / Fresh run. | Bash + AskUserQuestion | Decision recorded |
| R7 | **Check lock (PID-aware):** Đọc `.lock` JSON → lấy `pid` + `host`. **Path A (same host):** `kill -0 $pid` succeeds → **E031** "Session khác đang chạy" → STOP. PID dead → auto-release ngay, WARN. **Path B (different host hoặc thiếu pid):** Fallback mtime → age <`MCV3_LOCK_STALE_MINUTES` (default 60min) → **E031**; age ≥ threshold → **E008** auto-release, WARN. | Bash (`acquire_lock`) | Lock resolved |
| R8 | **Re-acquire lock:** Acquire lock + start heartbeat daemon (như Phase 1 Step 1.11). | Bash | Lock active |
| R9 | **Re-evaluate context:** IF `fix-status.json` có `$EXECUTION_MODE = agent_dispatch` → re-evaluate threshold (issues count hiện tại, context %). Có thể chuyển từ agent_dispatch → inline nếu conditions thay đổi. | Bash | Mode resolved |
| R9.5 | **Preserve retry budget (P5):** Đọc `error-ledger.json` → đếm entries `phase = $RESUME_PHASE` → set `$RETRY_COUNT[$RESUME_PHASE]` = count. IF count ≥ 3 → **E001 STOP** "Retry budget exhausted across resume attempts." AskUserQuestion: Re-run phase (reset budget) / Cancel. | Bash + AskUserQuestion | Budget preserved |
| R9.6 | **Re-validate prior phase outputs (P7):** Chạy lại PRE-GATE của `$RESUME_PHASE` (verify outputs của phases trước đó còn hợp lệ T1→T4). IF fail → AskUserQuestion: "Phase {N-1} output corrupt/missing. Re-run Phase {N-1} / Cancel." Nếu user chọn Re-run → set `$RESUME_PHASE = N-1` quay lại R5. | Bash + AskUserQuestion | Upstream outputs validated |
| R10 | **Route to phase (v10.18.0 lazy-load aware):** Cập nhật TodoWrite (skip completed phases, mark resume phase = in_progress). Load phase index router: `phase{N}-{name}.md`. **Nếu phase status='in_progress' (resume từ giữa phase):** sau khi load index, **đọc thêm `phase{N}-{name}/POST-GATE.md` §Resume Logic table** để xác định group cuối cùng completed (vd: Phase 6 `fix-report.md tồn tại nhưng phase6 chưa complete → Resume từ Group E`). Sau đó load chỉ group(s) cần re-execute (vd: `phase{N}-{name}/E-validate-dashboard.md`) thay vì load lại từ Group A. **Phase 4 SPECIAL CASE:** orchestrator KHÔNG cần load index khi resume — chạy Phase 4 POST-GATE Resume Logic trực tiếp (FOR each lane: skip completed, re-dispatch pending). | Read + TodoWrite | Phase loaded, group-level hint applied |

### Resume Strategy Matrix (P6)

> `--resume-strategy=<value>` quyết định hành vi của R3/R4 (gặp pipeline DONE/FAILED/in_progress).
> Default `prompt` giữ behavior cũ; `auto`/`force-fresh` cho automation.

| Pipeline state | `prompt` (default) | `auto` | `force-fresh` |
|----------------|--------------------|--------|---------------|
| `DONE` | AskUser: Re-run / Cancel | Cancel silently (INFO) | Tạo fresh session |
| `failed` | AskUser: Resume / Fresh / Cancel | **Resume** từ phase failed | Tạo fresh session |
| `in_progress` | Continue resume (R5+) | Continue resume (R5+) | Tạo fresh session |

**Lưu ý:**
- `--resume-strategy=auto` PHÙ HỢP cho CI/cron — KHÔNG block khi gặp DONE/FAILED.
- `--resume-strategy=force-fresh` tương đương "chạy `/wf-fix-bugs` thông thường nhưng kế thừa flags" — hiếm dùng, chủ yếu cho recovery test.
- Tất cả 3 strategy đều **tôn trọng R6 Staleness Guard và R7 Lock Check** — không bypass safety rails.

### Resume Routing Table

| Last Completed | Resume Phase | Procedure File | Notes |
|---------------|-------------|----------------|-------|
| (none) | Phase 1 | `phase1-init.md` | Fresh start |
| Phase 1 | Phase 2 | `phase2-scan.md` | Scope scan |
| Phase 2 | Phase 3 | `phase3-plan.md` | Planning |
| Phase 3 | Phase 4 | `phase4-find-bugs.md` | Lane dispatch |
| Phase 4 | Phase 5 | `phase5-triage.md` | Triage (hoặc Phase 7 nếu N=0) |
| Phase 5 (E005) | Phase 7 | `phase7-verify.md` | Healthy skip |
| Phase 5 | Phase 6 | `phase6-execute.md` | Execute fixes |
| Phase 6 | Phase 7 | `phase7-verify.md` | Verify |

### Anti-Staleness Guard (E013)

> **Lưu ý kỹ thuật:** `--since` là flag của `git log`, KHÔNG phải `git diff`. Phải resolve commit boundary trước rồi mới diff.

```bash
STALENESS CHECK:

# 1. Tìm CHECKPOINT event cuối cùng trong session-log.json
CHECKPOINT_TIME=$(jq -r '
  [.[] | select(.event == "CHECKPOINT")] | last | .timestamp // empty
' "$SESSION_DIR/session-log.json")

if [ -z "$CHECKPOINT_TIME" ]; then
  echo "INFO: no checkpoint event found — skip staleness check"
  # Tiếp tục resume bình thường (không có baseline để so sánh)
else
  # 2. Resolve commit boundary tại checkpoint time
  CHECKPOINT_COMMIT=$(git -C "$REPO_ROOT" log -1 --before="$CHECKPOINT_TIME" --format=%H 2>/dev/null)

  if [ -z "$CHECKPOINT_COMMIT" ]; then
    echo "WARN: no commit found before $CHECKPOINT_TIME — skip staleness check"
  else
    # 3. Đếm files thay đổi (committed + working tree)
    CHANGED=$(
      {
        git -C "$REPO_ROOT" diff --name-only "$CHECKPOINT_COMMIT" HEAD 2>/dev/null
        git -C "$REPO_ROOT" diff --name-only HEAD 2>/dev/null      # unstaged
        git -C "$REPO_ROOT" diff --name-only --cached HEAD 2>/dev/null  # staged
      } | sort -u | wc -l
    )

    # 4. Total files trong SCOPE (từ Phase 2 code-inventory)
    TOTAL=$(jq -r '.files | length // 0' \
      "$SESSION_DIR/phase2-scan/code-inventory.json" 2>/dev/null)

    # Fallback nếu code-inventory không tồn tại (resume từ Phase 1)
    if [ "${TOTAL:-0}" -eq 0 ]; then
      TOTAL=$(git -C "$REPO_ROOT" ls-files 2>/dev/null | wc -l)
    fi

    if [ "$TOTAL" -gt 0 ]; then
      PCT=$(( CHANGED * 100 / TOTAL ))
      echo "INFO: staleness — $CHANGED/$TOTAL files changed (${PCT}%)"

      if [ "$PCT" -gt 30 ]; then
        # 5. E013 WARN + AskUserQuestion
        # "~${PCT}% files đã thay đổi từ checkpoint. Kết quả scan cũ có thể không còn chính xác."
        # Options: Continue resume / Fresh run / Cancel
        true  # → AskUserQuestion ở R-handler
      fi
    fi
  fi
fi
```

**Lưu ý:** Staleness denominator phải là **files trong scope** (code-inventory.json từ Phase 2), không phải toàn repo. Nếu resume xảy ra trước Phase 2 (Phase 1 init dở), denominator dùng `git ls-files`.

---

### Partial Output Handling (R5 — F08.022 + v10.18.0 Phase 4 SPECIAL CASE)

> Phase đang `in_progress` thường để lại OUTPUT FILES KHÔNG COMPLETE (vd: `signals.json` chỉ có 3/11 lanes, `bug-triage.md` cắt giữa chừng). Re-run đè trực tiếp có thể (a) gây POST-GATE conflict (T4 cross-ref fail), (b) mất forensic data cần debug.
> Quy tắc: MOVE partials sang directory backup `partial-{timestamp}/` trước khi re-run.
> **EXCEPTION:** Phase 4 dùng selective archive (xem §Phase 4 Selective Archive bên dưới) để bảo toàn 11 parallel lane states + signals_total aggregation.

```bash
# Khi phát hiện phase $N đang in_progress tại R5:
RESUME_PHASE_NUM="$N"   # vd: 5
PHASE_NAME=""           # vd: "triage"

# Map phase number → phase name (theo Resume Routing Table)
case "$RESUME_PHASE_NUM" in
  1) PHASE_NAME="init"      ;;
  2) PHASE_NAME="scan"      ;;
  3) PHASE_NAME="plan"      ;;
  4) PHASE_NAME="find-bugs" ;;
  5) PHASE_NAME="triage"    ;;
  6) PHASE_NAME="execute"   ;;
  7) PHASE_NAME="verify"    ;;
esac

# v10.18.0 SPECIAL CASE: Phase 4 dùng selective archive — KHÔNG wholesale move
if [ "$RESUME_PHASE_NUM" = "4" ]; then
  # Delegate sang §Phase 4 Selective Archive (bên dưới)
  echo "INFO: R5 Phase 4 — delegate to selective archive (preserve completed lanes)"
  # ... (xem §Phase 4 Selective Archive bash block bên dưới)
  return 0  # Skip wholesale archive logic bên dưới
fi

PHASE_DIR="$SESSION_DIR/phase${RESUME_PHASE_NUM}-${PHASE_NAME}"

if [ -d "$PHASE_DIR" ]; then
  # Check non-empty: có ít nhất 1 file (output partial)
  if [ -n "$(ls -A "$PHASE_DIR" 2>/dev/null)" ]; then
    ARCHIVE_TS=$(date +%Y%m%dT%H%M%S)
    PARTIAL_DIR="${PHASE_DIR}.partial-${ARCHIVE_TS}"

    echo "INFO: R5 phát hiện partial outputs tại $PHASE_DIR — archive sang $PARTIAL_DIR"
    mv "$PHASE_DIR" "$PARTIAL_DIR"
    mkdir -p "$PHASE_DIR"

    # Ghi note vào session-log.json (CORE-026 output-only)
    # v10.10.1 fix: atomic .events += [...] thay vì `>>` raw — chống phá JSON wrapper
    SL="$SESSION_DIR/session-log.json"
    TMP_SL="$SL.tmp.r5.$$"
    NOTE="R5 archived partial outputs to ${PARTIAL_DIR##*/}"
    jq --argjson p "$RESUME_PHASE_NUM" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg note "$NOTE" \
       '.events += [{phase:$p, event:"CHECKPOINT", timestamp:$ts, note:$note}]' \
       "$SL" > "$TMP_SL" 2>/dev/null \
       && jq '.' "$TMP_SL" >/dev/null 2>&1 \
       && mv "$TMP_SL" "$SL" \
       || rm -f "$TMP_SL"
  fi
fi
```

**Quy tắc:**
- MOVE (không copy) — giữ disk usage thấp.
- Suffix `.partial-{timestamp}/` với `YYYYMMDDTHHMMSS` để tránh collision đa lần resume.
- KHÔNG xoá `partial-*` directories tự động — user manual clean up qua `find sessions/ -maxdepth 2 -name 'phase*.partial-*' -mtime +7 -exec rm -rf {} +`.
- Subdirectory rỗng sau MOVE → re-run phase tạo lại từ đầu (PRE-GATE pass vì phase deps vẫn còn ở phases trước).

**Verify sau MOVE:**
```bash
test -d "$PHASE_DIR" && [ -z "$(ls -A "$PHASE_DIR" 2>/dev/null)" ]  # empty ready for re-run
test -d "$PARTIAL_DIR"                                              # archive preserved
```

**Khi NÀO skip MOVE:**
- Phase đang `in_progress` nhưng subdirectory không tồn tại (chưa kịp tạo) — skip.
- User chạy `--resume-strategy=force-fresh` (R3/R4) → entire session re-created, không cần partial archive ở R5.

**Cross-ref:** CORE-035 (Phase Output Organization — phase{N}-{name}/), CORE-026 (Execution Trace event).

---

### Phase 4 Selective Archive (v10.18.0 SPECIAL CASE)

> Phase 4 dispatch 11 parallel lane agents — mỗi lane mất ~15 phút work + tốn 1 model quota. Wholesale archive khi phase đang in_progress → re-spawn ALL 11 = ~2.7h work lost + 11× quota waste.
> Quy tắc: scan `lanes/QD*/lane-status.json` → archive CHỈ lanes failed/in_progress, GIỮ completed/skipped nguyên vẹn.

```bash
# Khi RESUME_PHASE_NUM=4 + phase4.status='in_progress':
PHASE_DIR="$SESSION_DIR/phase4-find-bugs"
LANES_ROOT="$PHASE_DIR/lanes"
ARCHIVE_TS=$(date +%Y%m%dT%H%M%S)
PARTIAL_DIR_BASE="${PHASE_DIR}.lanes-partial-${ARCHIVE_TS}"

# Track lanes archived vs preserved cho session-log
ARCHIVED_LANES=()
PRESERVED_LANES=()

if [ -d "$LANES_ROOT" ]; then
  for LANE_DIR in "$LANES_ROOT"/QD*/; do
    [ -d "$LANE_DIR" ] || continue
    LANE_NAME=$(basename "$LANE_DIR")
    LANE_STATUS_FILE="$LANE_DIR/lane-status.json"

    if [ ! -f "$LANE_STATUS_FILE" ]; then
      # Lane chưa khởi tạo → safe to leave (Phase 4 setup-lanes.sh sẽ tạo lại)
      continue
    fi

    LANE_STATUS=$(jq -r '.status // "pending"' "$LANE_STATUS_FILE" 2>/dev/null)

    case "$LANE_STATUS" in
      completed|skipped)
        # PRESERVE — Phase 4 POST-GATE Resume Logic sẽ skip lanes này
        PRESERVED_LANES+=("$LANE_NAME:$LANE_STATUS")
        ;;
      failed|in_progress|pending)
        # ARCHIVE — Phase 4 POST-GATE Resume Logic sẽ re-dispatch lane này
        mkdir -p "$PARTIAL_DIR_BASE"
        mv "$LANE_DIR" "$PARTIAL_DIR_BASE/$LANE_NAME"
        ARCHIVED_LANES+=("$LANE_NAME:$LANE_STATUS")
        ;;
      *)
        echo "WARN: lane $LANE_NAME có status không hợp lệ ($LANE_STATUS) — archive an toàn"
        mkdir -p "$PARTIAL_DIR_BASE"
        mv "$LANE_DIR" "$PARTIAL_DIR_BASE/$LANE_NAME"
        ARCHIVED_LANES+=("$LANE_NAME:invalid")
        ;;
    esac
  done

  echo "INFO: R5 Phase 4 selective archive — preserved=${#PRESERVED_LANES[@]}, archived=${#ARCHIVED_LANES[@]}"
  [ ${#PRESERVED_LANES[@]} -gt 0 ] && echo "  PRESERVED: ${PRESERVED_LANES[*]}"
  [ ${#ARCHIVED_LANES[@]} -gt 0 ]  && echo "  ARCHIVED:  ${ARCHIVED_LANES[*]}"

  # Ghi note vào session-log.json
  SL="$SESSION_DIR/session-log.json"
  if [ -s "$SL" ]; then
    TMP_SL="$SL.tmp.r5p4.$$"
    NOTE="R5 Phase 4 selective archive: preserved=${#PRESERVED_LANES[@]} archived=${#ARCHIVED_LANES[@]}"
    jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg note "$NOTE" \
       '.events += [{phase:4, event:"CHECKPOINT", timestamp:$ts, note:$note}]' \
       "$SL" > "$TMP_SL" 2>/dev/null \
       && jq '.' "$TMP_SL" >/dev/null 2>&1 \
       && mv "$TMP_SL" "$SL" \
       || rm -f "$TMP_SL"
  fi
fi

# CRITICAL: KHÔNG archive top-level files (Phase4-report.md, phase4-summary.json, cdg-tokens.json)
# Phase 4 POST-GATE sẽ regenerate sau khi re-dispatch xong. Top-level non-lane files giữ nguyên cho debug.
```

**Quy tắc bảo vệ:**
- ✅ Preserve `lanes/QD*-*/` với status='completed'/'skipped' — Phase 4 POST-GATE skip
- ✅ Archive `lanes/QD*-*/` với status='failed'/'in_progress'/'pending' (or invalid)
- ✅ KHÔNG touch `phase4-find-bugs/Phase4-report.md`, `phase4-summary.json`, `cdg-tokens.json` (top-level outputs) — regenerated sau resume hoàn tất
- ✅ Archive directory: `$SESSION_DIR/phase4-find-bugs.lanes-partial-{ts}/QDN-name/` (chỉ contain archived lanes)
- ❌ KHÔNG dùng wholesale archive (`mv phase4-find-bugs/ → phase4-find-bugs.partial-{ts}/`) — mất completed lanes + phá `signals_total` aggregation

**Why this matters (Issue 1+2 v10.18.0 fix):**
- finalize-phase4.sh aggregate `signals_total` từ `lanes/QD*/{static-scan,runtime,llm-scan}/signals.json` filesystem scan
- Mất `lanes/QD*/` → aggregate return 0 → `fix-status.signals_total = 0`
- Downstream Phase 5 setup-triage.sh thấy 0 signals → trigger E005 healthy path **INCORRECTLY** → SKIP Phase 6/7 → false PASS (bug không được fix nhưng pipeline mark DONE)

**Manual cleanup:** `find sessions/ -maxdepth 2 -name 'phase4-find-bugs.lanes-partial-*' -mtime +7 -exec rm -rf {} +`

**Cross-ref:** Phase 4 POST-GATE.md §Resume Logic, finalize-phase4.sh §aggregate signals_total, CORE-026 (Execution Trace).

---

### R10 Group-Level Routing (v10.18.0 Lazy-Load Aware)

> Khi resume phase với status='in_progress', dùng group-level POST-GATE markers từ `phase{N}-{name}/POST-GATE.md §Resume Logic` để route vào group cuối cùng completed thay vì luôn Group A.

**Pattern flow:**

```
R10 dispatch:
  1. Load index router: phase{N}-{name}.md (KHÔNG load group files)
  2. IF phase status='in_progress':
     a. Load phase{N}-{name}/POST-GATE.md §Resume Logic table
     b. Apply table logic theo state files hiện tại:
        - Phase 4: per-lane logic (KHÔNG cần group hint — xem §Phase 4 Selective Archive)
        - Phase 5: check issue-registry.json/bug-triage.md/fix-plan.md exist → route Group B/C/D/E
        - Phase 6: check fix-report.md exist → route Group E (validate + dashboard)
        - Phase 7: check orchestrator-summary/fix-impact/phase-summary exist → route Group E/F
     c. Load chỉ group(s) cần re-execute từ resume point đến cuối phase
  3. IF phase status='not_started': load Group A bình thường (fresh phase entry)
  4. IF phase status='completed': skip phase → advance next phase
```

**Group resume hints per phase (extracted từ POST-GATE.md §Resume Logic):**

| Phase | Detection rule | Resume from |
|-------|----------------|-------------|
| **Phase 1** | `phase1-init/G-finalize.md` outputs (`fix-status.json` initialized + lock acquired) | Last completed group hint từ fix-status.phase1.last_group (nếu có) |
| **Phase 2** | KHÔNG split (5 steps, grandfathered) — re-run từ Step 2.1 nếu in_progress | N/A |
| **Phase 3** | `dimension-plan.json` exists | Group D (Route + Write) hoặc E (Report) |
| **Phase 4** | **SPECIAL CASE per-lane logic** (xem §Phase 4 Selective Archive) | Per-lane skip/redispatch, KHÔNG dùng group routing |
| **Phase 5** | `issue-registry.json` exists nhưng phase5 chưa complete | Group C/D (Step 5.4-5.5 CDG critical + Spawn triage) |
| **Phase 6** | `fix-report.md` exists nhưng phase6 chưa complete | Group E (validate + dashboard) |
| **Phase 7** | `orchestrator-summary.md`/`fix-impact.json`/`phase-summary.md`/`Phase7-report.md` exist | Group E/F (Reports/Finalize) |

**Quy tắc:**
- Orchestrator KHÔNG hardcode group routing logic — luôn delegate sang `phase{N}-{name}/POST-GATE.md §Resume Logic`
- Mỗi phase POST-GATE.md OWNS resume logic của phase đó (CORE-007 — output path contract)
- Resume Logic table là canonical reference — nếu mâu thuẫn với R10, POST-GATE table thắng

**Cross-ref:** CORE-032 (Skill Architecture lazy-load), CORE-036 (Cross-Skill Artifact Contract), `phase{N}-{name}/POST-GATE.md §Resume Logic` per phase.

---

### Retry Budget Preservation (R9.5)

> Chống bypass anti-loop: mỗi lần `--resume`, `$RETRY_COUNT` không được reset về 0 ngầm.

```bash
# Đọc error-ledger.json — đếm entries có phase = resume phase
RESUME_PHASE="phase${N}"  # vd: "phase5"

ERR_LEDGER="$SESSION_DIR/error-ledger.json"
[ -f "$ERR_LEDGER" ] || ERR_LEDGER_COUNT=0

ERR_LEDGER_COUNT=$(jq --arg ph "$RESUME_PHASE" '
  [.[] | select(.phase == $ph and (.event // "FAIL") == "FAIL")] | length
' "$ERR_LEDGER" 2>/dev/null || echo 0)

# Restore vào state variable (sẽ được dùng bởi §5 Auto-Fix Protocol)
RETRY_COUNT_PHASE="$ERR_LEDGER_COUNT"

if [ "$RETRY_COUNT_PHASE" -ge 3 ]; then
  # E001 STOP — budget exhausted across resume attempts
  # AskUserQuestion: "Phase $RESUME_PHASE đã fail $RETRY_COUNT_PHASE lần qua các session/resume trước.
  #   Tiếp tục sẽ vượt budget. Bạn muốn:
  #   1) Re-run phase với budget reset (RỦI RO — có thể loop vô hạn)
  #   2) Cancel (chạy /wf-fix-bugs fresh session để re-triage)"
  # User chọn 1 → reset RETRY_COUNT_PHASE=0, append note "budget reset by user at <ts>" vào error-ledger
  # User chọn 2 → STOP với hướng dẫn
  true
fi
```

---

### PRE-GATE Re-validation (R9.6)

> Bảo vệ resume khỏi corrupted upstream outputs (manual edit, `.mc-data/` git checkout mất file, ...).

```bash
# v10.10.0: BASH 3.0+ required (array syntax). Git Bash + WSL + macOS bash OK.
# POSIX sh fallback: nếu chạy /bin/sh strict, dùng space-separated string thay vì array
# (vd: PRIOR_PHASES="phase1 phase2 phase3"; for ph in $PRIOR_PHASES; do ...; done).
RESUME_PHASE_NUM="$N"  # vd: 5 (resume Phase 5 = Triage)
PRIOR_PHASES=()
for i in $(seq 1 $((RESUME_PHASE_NUM - 1))); do
  PRIOR_PHASES+=("phase${i}")
done

VALIDATION_FAILED=()

for ph in "${PRIOR_PHASES[@]}"; do
  PH_DIR=$(find "$SESSION_DIR" -maxdepth 1 -type d -name "${ph}-*" -print -quit)
  [ -z "$PH_DIR" ] && { VALIDATION_FAILED+=("$ph:missing_dir"); continue; }

  # T1 (existence) — Phase{N}-report.md tồn tại
  REPORT="$PH_DIR/Phase${ph#phase}-report.md"
  [ -f "$REPORT" ] || { VALIDATION_FAILED+=("$ph:missing_report"); continue; }

  # T2 (structure) — Validate JSON outputs (theo _contract.json §outputs.working[])
  # Pattern: mỗi *.json trong PH_DIR phải parse được
  for jf in "$PH_DIR"/*.json; do
    [ -f "$jf" ] || continue
    jq '.' "$jf" >/dev/null 2>&1 || VALIDATION_FAILED+=("$ph:corrupt_json:$(basename "$jf")")
  done

  # T3 (content depth) — phase-specific spot check
  # vd: Phase 2 → code-inventory.json phải có .files non-empty (trừ khi E020)
  # vd: Phase 5 → issue-registry.json phải có .issues field
done

if [ "${#VALIDATION_FAILED[@]}" -gt 0 ]; then
  # AskUserQuestion: "Phát hiện ${#VALIDATION_FAILED[@]} vấn đề trong outputs phases trước:
  #   ${VALIDATION_FAILED[*]}
  #   Options:
  #   1) Re-run phase {N-1} để regenerate (an toàn nhất)
  #   2) Continue resume (RỦI RO — có thể fail downstream)
  #   3) Cancel"
  # User chọn 1 → set RESUME_PHASE = N-1, quay lại R5
  # User chọn 2 → ghi WARN vào error-ledger, tiếp tục
  # User chọn 3 → STOP
  true
fi
```

**Cross-ref:** Tier T1→T4 schema theo Protocol 10 (`.claude/skills/protocols/10-post-gate-schema.md`).
