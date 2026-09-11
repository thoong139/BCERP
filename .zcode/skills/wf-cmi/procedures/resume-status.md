# Resume & Status — wf-cmi v3.0.0

> Procedure xử lý 3 entrypoints:
> - **`--status`** (hiển thị trạng thái session, read-only, exit 0)
> - **`--resume`** (resume pipeline từ checkpoint gần nhất, support Phase 1-10 v3.0)
> - **`--scenarios-only`** (v3.0 NEW — bypass Phase 1-7, route trực tiếp Phase 9 trên session cũ — implement chính ở `phase1-init.md` Step 1.21, file này cung cấp routing reference)
>
> Được dispatch từ Phase 1 Step 1.1.8 (Flag dispatch).
>
> **Contract:** Output paths + session data PHẢI khớp `_contract.json §outputs.working[]`.
>
> **Shared:** Đọc `_shared.md §1, §13, §16` cho State Variables, Session Lock, Session Isolation.
>
> **v3.0 changes:**
> - Phase table mở rộng từ 8 → 10 phases (Phase 9-10 conditional khi `v3_flags.exec_scenarios=true`)
> - Resume routing table thêm Phase 9 → 10 → 8 re-write loop
> - `--scenarios-only` flag được route ở phase1-init Step 1.21, KHÔNG qua file này (cross-reference only)
> - Stale check exception: `--scenarios-only` skip stale check vì user explicit re-execute Phase 9-10

---

## --status Handler

### Mục đích

Hiển thị trạng thái pipeline hiện tại (read-only), KHÔNG thực thi gì. Exit 0 sau khi hiển thị.

### 7 Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| S1 | **Find session** | Read + Bash | Session found |
| S2 | **Read integrity-status.json** | Read | Status loaded |
| S3 | **Display header** | — | Header printed |
| S4 | **Display phase table** | — | Table printed |
| S5 | **Display CI tools status** | — | CI status printed |
| S6 | **Display lane status (nếu Phase 4 đang chạy)** | — | Lane status printed |
| S7 | **Next action suggestion** | — | Suggestion printed |

### S1 — Find session

Thứ tự ưu tiên:

```bash
# (1) --session-id explicit
if [ -n "$SESSION_ID_FLAG" ]; then
  SESSION_DIR=".mc-data/work/wf-cmi/sessions/$SESSION_ID_FLAG"
  [ -d "$SESSION_DIR" ] || { echo "ERROR: Session không tồn tại: $SESSION_ID_FLAG" >&2; exit 1; }
  SESSION_ID="$SESSION_ID_FLAG"

# (2) $SESSION_DIR đã set (chạy --status sau --resume mid-pipeline)
elif [ -n "$SESSION_DIR" ]; then
  :

# (3) Tìm session gần nhất theo integrity-status.json.checkpoint_at hoặc lock heartbeat
else
  SESSION_DIR=$(ls -dt .mc-data/work/wf-cmi/sessions/*/ 2>/dev/null | head -1 | sed 's|/$||')
  [ -z "$SESSION_DIR" ] && { echo "Chưa có session nào. Chạy /wf-cmi để bắt đầu." >&2; exit 0; }
  SESSION_ID=$(basename "$SESSION_DIR")
fi

export SESSION_ID SESSION_DIR
```

### S2 — Read integrity-status.json

```bash
[ -f "$SESSION_DIR/integrity-status.json" ] \
  || { echo "ERROR: integrity-status.json không tồn tại trong $SESSION_DIR" >&2; exit 1; }

STATUS_JSON=$(cat "$SESSION_DIR/integrity-status.json")
```

### S3 — Display header

```
═══════════════════════════════════════════════════════════
  wf-cmi — Cross-Module Integrity Status
═══════════════════════════════════════════════════════════

Session ID:        2026-05-15-system-eureka-erp-01
Scope:             system (toàn dự án)
Profile:           standard (≥80% threshold)
Author:            Developer A <dev.a@erktransport.com>
Started:           2026-05-15T14:30:00+07:00
Last checkpoint:   2026-05-15T14:48:35+07:00
Pipeline status:   in_progress (Phase 4 → 5)
Final status:      (not yet)
```

```bash
echo "Session ID:        $SESSION_ID"
echo "Scope:             $(echo "$STATUS_JSON" | jq -r '.scope.type + " (" + (.scope.name // "all") + ")"')"
echo "Profile:           $(echo "$STATUS_JSON" | jq -r '.profile')"
echo "Author:            $(echo "$STATUS_JSON" | jq -r '.author.git_user_name + " <" + .author.git_user_email + ">"')"
echo "Started:           $(echo "$STATUS_JSON" | jq -r '.started_at // .checkpoint_at')"
echo "Last checkpoint:   $(echo "$STATUS_JSON" | jq -r '.checkpoint_at')"
echo "Pipeline status:   $(echo "$STATUS_JSON" | jq -r '.pipeline_status')"
echo "Final status:      $(echo "$STATUS_JSON" | jq -r '.final_status // "(not yet)"')"
echo
```

### S4 — Display phase table (v3.0: 8 + 2 conditional Phase 9-10)

```
| Phase | Tên                    | Status     | Duration | Notes                                  |
|-------|------------------------|------------|----------|----------------------------------------|
| 1     | Init                   | completed  | 42s      | CI: GitNexus ✓ Serena ✓                |
| 2     | Discovery              | completed  | 3m12s    | 6 graphs built                         |
| 3     | Invariant              | completed  | 2m45s    | 47 invariants inferred                 |
| 4     | Coverage (3-wave)      | in_progress| —        | 5/13 lanes done (W1 done, W2 running)  |
| 5     | Aggregate              | pending    | —        | —                                      |
| 6     | Regression             | pending    | —        | —                                      |
| 7     | GAP + CDG              | pending    | —        | —                                      |
| 8     | Report                 | pending    | —        | —                                      |
| 9     | E2E Execute (v3)       | pending    | —        | (chỉ chạy nếu --exec-scenarios)        |
| 10    | E2E Resolution (v3)    | pending    | —        | (chỉ chạy nếu Phase 9 có FAIL)         |
```

```bash
echo "Phase Table:"
echo "| # | Tên                  | Status      | Duration | Notes                   |"
echo "|---|----------------------|-------------|----------|-------------------------|"

# v3.0: Detect xem session có exec_scenarios không
EXEC_SCENARIOS=$(echo "$STATUS_JSON" | jq -r '.v3_flags.exec_scenarios // false')
SCENARIOS_ONLY=$(echo "$STATUS_JSON" | jq -r '.v3_flags.scenarios_only // false')

# Determine phase range
if [ "$EXEC_SCENARIOS" = "true" ] || [ "$SCENARIOS_ONLY" = "true" ]; then
  PHASES_TO_DISPLAY="1 2 3 4 5 6 7 8 9 10"
else
  PHASES_TO_DISPLAY="1 2 3 4 5 6 7 8"
fi

for n in $PHASES_TO_DISPLAY; do
  PHASE_NAME=$(get_phase_name $n)
  STATUS=$(if echo "$STATUS_JSON" | jq -e --argjson n $n '.phases_completed | any(. == $n)' >/dev/null; then
            echo "completed"
          elif [ "$(echo "$STATUS_JSON" | jq -r '.current_phase')" = "$n" ]; then
            echo "in_progress"
          elif [ "$n" -ge 9 ] && [ "$EXEC_SCENARIOS" != "true" ] && [ "$SCENARIOS_ONLY" != "true" ]; then
            echo "skipped"
          else
            echo "pending"
          fi)
  printf "| %-2d | %-20s | %-11s | —        | —                       |\n" $n "$PHASE_NAME" "$STATUS"
done
echo
```

### S5 — Display CI tools status

```
CI Tools:
  GitNexus:        ✓ available (24h cache fresh)
  Serena:          ✓ available
  Index freshness: ok (5 commits behind HEAD)
```

```bash
echo "CI Tools:"
GN_AVAIL=$(echo "$STATUS_JSON" | jq -r '.ci_context.gitnexus_available')
SE_AVAIL=$(echo "$STATUS_JSON" | jq -r '.ci_context.serena_available')
FRESHNESS=$(echo "$STATUS_JSON" | jq -r '.ci_context.index_freshness')

echo "  GitNexus:        $([ "$GN_AVAIL" = "true" ] && echo "✓ available" || echo "✗ unavailable (fallback Grep)")"
echo "  Serena:          $([ "$SE_AVAIL" = "true" ] && echo "✓ available" || echo "✗ unavailable")"
echo "  Index freshness: $FRESHNESS"
echo
```

### S6 — Display lane status (nếu đang Phase 4)

```
Lane Status (Phase 4):
  CD1 Business        ✓ completed (12 signals, 38s)
  CD2 Entity          ✓ completed (8 signals, 45s)
  CD3 Workflow        ⟳ running (45s elapsed)
  CD4 API             ✓ completed (32 signals, 58s)
  CD5 Event           ⏸ pending
  CD6 RBAC            ⏸ pending
  CD7 Data            ⟳ running (50s elapsed)
  CD9 Regression      ⏸ pending
```

```bash
CURRENT=$(echo "$STATUS_JSON" | jq -r '.current_phase')
if [ "$CURRENT" = "4" ] || echo "$STATUS_JSON" | jq -e '.lane_status | length > 0' >/dev/null; then
  echo "Lane Status (Phase 4):"
  echo "$STATUS_JSON" | jq -r '.lane_status | to_entries[] |
                                "  \(.key)  \(.value)"'
  echo
fi
```

### S7 — Next action suggestion (v3.0: thêm scenarios-only path)

```bash
NEXT_ACTION=$(echo "$STATUS_JSON" | jq -r '.next_action // empty')
PIPELINE_STATUS=$(echo "$STATUS_JSON" | jq -r '.pipeline_status')
EXEC_SCENARIOS=$(echo "$STATUS_JSON" | jq -r '.v3_flags.exec_scenarios // false')
SESSION_HAS_SCENARIOS=$(test -f "$SESSION_DIR/phase4-coverage/lanes/CD41-e2e-synth/scenarios-manifest.json" && echo "true" || echo "false")

echo "Next action:"
case "$PIPELINE_STATUS" in
  "DONE")
    echo "  ✅ Pipeline đã hoàn thành — xem báo cáo tại $SESSION_DIR/phase8-report/integrity-report.md"
    if [ "$EXEC_SCENARIOS" != "true" ] && [ "$SESSION_HAS_SCENARIOS" = "true" ]; then
      echo "  💡 v3.0: Session đã sinh scenarios CD41 nhưng chưa execute. Để chạy Playwright runtime verify:"
      echo "    /wf-cmi --scenarios-only --session-id=$SESSION_ID --exec-scenarios"
    fi
    echo "  Consume cross-skill (artifact integrity-impact-v3):"
    echo "    /wf-verify-sync --from-cmi"
    echo "    /wf-fix-bugs --from-cmi"
    echo "    /wf-prepare-deployment --from-cmi"
    ;;
  "in_progress")
    echo "  ⟳ Chạy '/wf-cmi --resume' để tiếp tục từ $NEXT_ACTION"
    ;;
  "failed")
    echo "  ❌ Phase $CURRENT_PHASE failed — chạy '/wf-cmi --resume' để retry"
    echo "  Hoặc xem error: $SESSION_DIR/error-ledger.json"
    ;;
  "failed_phase_9_or_10")
    echo "  ❌ Phase 9/10 failed — chạy '/wf-cmi --scenarios-only --session-id=$SESSION_ID --exec-scenarios' để retry chỉ E2E"
    echo "  Hoặc xem error: $SESSION_DIR/error-ledger.json"
    ;;
esac

exit 0
```

---

## --resume Handler

### Mục đích

Resume pipeline từ checkpoint gần nhất. Smart routing dựa trên `integrity-status.json.next_action`. Stale check + lock re-acquire + PRE-GATE re-validation.

### 10 Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| R1 | **Find session** | Read + Bash | Session found |
| R2 | **Read integrity-status.json** | Read | Status loaded |
| R3 | **Check pipeline DONE** | bash + AskUser | Decision recorded |
| R4 | **Check pipeline FAILED** | bash + AskUser | Decision recorded |
| R5 | **Find resume point + partial output archive** | Bash | Resume point found |
| R6 | **Check staleness** | Bash + AskUser | Decision recorded |
| R7 | **Check lock (PID-aware)** | Bash | Lock resolved |
| R8 | **Re-acquire lock + heartbeat** | Bash | Lock active |
| R9 | **Preserve retry budget + re-validate PRE-GATE upstream** | Bash + AskUser | Budget preserved |
| R10 | **Route to phase procedure** | Read + TodoWrite | Phase loaded |

### R1 — Find session

Same priority order như `--status` S1 (xem trên).

### R2 — Read integrity-status.json

```bash
STATUS_JSON=$(cat "$SESSION_DIR/integrity-status.json")
PIPELINE_STATUS=$(echo "$STATUS_JSON" | jq -r '.pipeline_status')
CURRENT_PHASE=$(echo "$STATUS_JSON" | jq -r '.current_phase')
NEXT_ACTION=$(echo "$STATUS_JSON" | jq -r '.next_action')
```

### R3 — Check pipeline DONE

```bash
if [ "$PIPELINE_STATUS" = "DONE" ]; then
  # AskUserQuestion:
  #   "Pipeline đã hoàn thành (final_status=$FINAL_STATUS).
  #    Options:
  #      1. Re-run từ đầu (fresh session)
  #      2. Cancel"
  # Default: Cancel

  echo "Pipeline session $SESSION_ID đã DONE. Dùng /wf-cmi fresh để chạy lại."
  exit 0
fi
```

### R4 — Check pipeline FAILED

```bash
if [ "$PIPELINE_STATUS" = "failed" ]; then
  FAILED_PHASE=$(echo "$STATUS_JSON" | jq -r '.failed_phase // .current_phase')
  # AskUserQuestion:
  #   "Phase $FAILED_PHASE failed. Options:
  #      1. Resume từ phase failed (default)
  #      2. Fresh run (tạo session mới)
  #      3. Cancel"
  # User chọn 1 → continue R5+
  # User chọn 2 → exit + suggest /wf-cmi fresh
  # User chọn 3 → exit 0

  RESUME_PHASE=$FAILED_PHASE
fi
```

### R5 — Find resume point + partial output archive

```bash
RESUME_PHASE="${RESUME_PHASE:-$CURRENT_PHASE}"
PHASE_NAME=$(get_phase_dir_name $RESUME_PHASE)
PHASE_DIR="$SESSION_DIR/phase${RESUME_PHASE}-${PHASE_NAME}"

# Check partial outputs in current phase
if [ -d "$PHASE_DIR" ] && [ -n "$(ls -A "$PHASE_DIR" 2>/dev/null)" ]; then
  # Check schema completeness
  PARTIAL=false
  for f in "$PHASE_DIR"/*.json; do
    [ -f "$f" ] || continue
    jq -e '."$schema"' "$f" >/dev/null 2>&1 || PARTIAL=true
  done

  if [ "$PARTIAL" = "true" ]; then
    ARCHIVE_TS=$(date +%Y%m%dT%H%M%S)
    PARTIAL_DIR="${PHASE_DIR}.partial-${ARCHIVE_TS}"
    mv "$PHASE_DIR" "$PARTIAL_DIR"
    mkdir -p "$PHASE_DIR"
    log_phase_event "phase${RESUME_PHASE}" "CHECKPOINT" "{\"note\":\"R5 archived partial outputs to $(basename "$PARTIAL_DIR")\"}"
  fi
fi
```

**Phase name mapping (v3.0: 8 + 2 phases):**

```bash
get_phase_dir_name() {
  case "$1" in
    1)  echo "init" ;;
    2)  echo "discovery" ;;
    3)  echo "invariants" ;;
    4)  echo "coverage" ;;
    5)  echo "aggregate" ;;
    6)  echo "regression" ;;
    7)  echo "gap-cdg" ;;
    8)  echo "report" ;;
    9)  echo "e2e-execute" ;;       # v3.0 NEW
    10) echo "e2e-resolution" ;;    # v3.0 NEW
  esac
}
```

### R6 — Check staleness (E013-like guard)

> So sánh `checkpoint_at` với HEAD git commit — nếu >30% files changed since checkpoint → WARN.

```bash
CHECKPOINT_TIME=$(echo "$STATUS_JSON" | jq -r '.checkpoint_at')

if [ -n "$CHECKPOINT_TIME" ] && command -v git >/dev/null 2>&1; then
  # Resolve commit boundary tại checkpoint time
  CHECKPOINT_COMMIT=$(git log -1 --before="$CHECKPOINT_TIME" --format=%H 2>/dev/null)

  if [ -n "$CHECKPOINT_COMMIT" ]; then
    CHANGED=$(git diff --name-only "$CHECKPOINT_COMMIT" HEAD 2>/dev/null | wc -l)
    TOTAL=$(git ls-files 2>/dev/null | wc -l)

    if [ "$TOTAL" -gt 0 ]; then
      PCT=$((CHANGED * 100 / TOTAL))
      if [ "$PCT" -gt 30 ]; then
        # AskUserQuestion:
        #   "~${PCT}% files đã thay đổi từ checkpoint. Kết quả scan cũ có thể không còn chính xác.
        #    Options:
        #      1. Continue resume (RISKY — partial scan)
        #      2. Fresh run (recommended)
        #      3. Cancel"
        # Default: Fresh run
        :  # Handle decision
      fi
    fi
  fi
fi
```

### R7 — Check lock (PID-aware)

```bash
LOCK="$SESSION_DIR/.lock"
if [ -f "$LOCK" ]; then
  LOCK_PID=$(jq -r '.pid' "$LOCK" 2>/dev/null)
  LOCK_HOST=$(jq -r '.host' "$LOCK" 2>/dev/null)
  CURRENT_HOST=$(hostname 2>/dev/null || echo "unknown")

  # Path A: same host — PID liveness check
  if [ "$LOCK_HOST" = "$CURRENT_HOST" ]; then
    if kill -0 "$LOCK_PID" 2>/dev/null; then
      echo "E018: Session khác đang chạy (PID $LOCK_PID)" >&2
      exit 1
    fi
    # PID dead → auto-release
    rm -f "$LOCK"
    log_phase_event "resume" "INFO" "{\"note\":\"PID $LOCK_PID dead — auto-release lock\"}"
  else
    # Path B: different host — mtime check
    AGE=$(($(date +%s) - $(stat -c %Y "$LOCK" 2>/dev/null || stat -f %m "$LOCK")))
    STALE_MIN="${MCV3_CMI_LOCK_STALE_MIN:-30}"
    if [ "$AGE" -lt $((STALE_MIN * 60)) ]; then
      echo "E018: Session khác đang chạy (other host, age=${AGE}s)" >&2
      exit 1
    fi
    # Stale → auto-release
    rm -f "$LOCK"
    log_phase_event "resume" "INFO" "{\"note\":\"Stale lock (age=${AGE}s) — auto-release (E008)\"}"
  fi
fi
```

### R8 — Re-acquire lock + heartbeat

```bash
# Reuse Phase 1 acquire_lock helper
get_git_author  # set $AUTHOR_EMAIL, $AUTHOR_NAME
acquire_lock "$SESSION_DIR" || die "E018" "Cannot re-acquire lock"
start_heartbeat_daemon "$SESSION_DIR"
trap cleanup EXIT INT TERM

log_phase_event "resume" "INFO" "{\"resume_phase\":$RESUME_PHASE}"
```

### R9 — Preserve retry budget + re-validate PRE-GATE upstream

> Chống bypass anti-loop: mỗi lần resume, `$RETRY_COUNT` không được reset về 0 ngầm.

```bash
# Read error-ledger.json — count entries for resume phase
ERR_LEDGER="$SESSION_DIR/error-ledger.json"
PHASE_KEY="phase${RESUME_PHASE}"

if [ -f "$ERR_LEDGER" ]; then
  ERR_COUNT=$(jq --arg p "$PHASE_KEY" \
              '[.errors[]? | select(.phase == $p and .event == "FAIL")] | length' \
              "$ERR_LEDGER" 2>/dev/null || echo 0)

  if [ "$ERR_COUNT" -ge 3 ]; then
    # AskUserQuestion:
    #   "Phase $PHASE_KEY đã fail $ERR_COUNT lần qua các resume trước.
    #    Tiếp tục sẽ vượt budget. Options:
    #      1. Re-run với budget reset (RISKY — có thể loop)
    #      2. Cancel (chạy /wf-cmi fresh)"
    # Default: Cancel

    echo "ERROR: Retry budget exhausted ($ERR_COUNT failures)" >&2
    exit 1
  fi
  RETRY_COUNT_PHASE=$ERR_COUNT
fi

# Re-validate upstream phase outputs (PRE-GATE simulation)
for prev_phase in $(seq 1 $((RESUME_PHASE - 1))); do
  prev_name=$(get_phase_dir_name $prev_phase)
  prev_dir="$SESSION_DIR/phase${prev_phase}-${prev_name}"

  # Required: Phase{N}-report.md exists
  [ -f "$prev_dir/Phase${prev_phase}-report.md" ] \
    || { log_warn "Upstream phase $prev_phase output incomplete — re-run recommended"; }

  # Validate JSON outputs schema
  for jf in "$prev_dir"/*.json; do
    [ -f "$jf" ] || continue
    jq -e '."$schema"' "$jf" >/dev/null 2>&1 \
      || log_warn "Upstream JSON corrupt: $(basename "$jf")"
  done
done
```

### R10 — Route to phase procedure

```bash
# Update TodoWrite — mark completed phases done, resume phase in_progress
update_todo_resume() {
  local resume=$1
  # Mark phases 1..(resume-1) = completed
  # Mark resume = in_progress
  # Mark (resume+1)..8 = pending
  # Implementation via TodoWrite tool
}
update_todo_resume "$RESUME_PHASE"

# Load procedure file
PROC_FILE="procedures/phase${RESUME_PHASE}-$(get_phase_dir_name $RESUME_PHASE).md"

# Phase 3 đặc biệt: tên `phase3-invariant-artifact.md` (không phải `phase3-invariants.md`)
[ "$RESUME_PHASE" = "3" ] && PROC_FILE="procedures/phase3-invariant-artifact.md"

# Phase 4 đặc biệt: tên `phase4-coverage-dispatch.md`
[ "$RESUME_PHASE" = "4" ] && PROC_FILE="procedures/phase4-coverage-dispatch.md"

# Phase 7 đặc biệt: tên `phase7-gap-cdg.md`
[ "$RESUME_PHASE" = "7" ] && PROC_FILE="procedures/phase7-gap-cdg.md"

echo "Resuming from Phase $RESUME_PHASE — loading $PROC_FILE..."

# Orchestrator route: Read $PROC_FILE → execute Steps
# (Implementation: lazy-load procedure file content qua Read tool)
```

### Resume Routing Table (v3.0)

| Last Completed | Resume Phase | Procedure File | Notes |
|---------------|-------------|----------------|-------|
| (none) | Phase 1 | `phase1-init.md` | Fresh start (sẽ tạo session mới, không resume) |
| Phase 1 | Phase 2 | `phase2-discovery.md` | 6 graphs build |
| Phase 2 | Phase 3 | `phase3-invariant-artifact.md` | 3-pass LLM infer |
| Phase 3 | Phase 4 | `phase4-coverage-dispatch.md` | 26 lanes 3-wave (v3 thêm CD41 W3 nếu deep/exhaustive hoặc CDG E195b force) |
| Phase 4 | Phase 5 | `phase5-aggregate.md` | Coverage matrix v3 (35 dims = 26 + 9 SKIPPED) |
| Phase 5 (E005 healthy) | Phase 8 | `phase8-report.md` | Skip 6-7 (healthy) |
| Phase 5 | Phase 6 | `phase6-regression.md` | Hoặc skip Phase 6 nếu profile=quick |
| Phase 6 | Phase 7 | `phase7-gap-cdg.md` | GAP detect (v3 thêm Step 7.11 loop-back từ Phase 10) |
| Phase 7 | Phase 8 | `phase8-report.md` | Phase 8 report v3 với conditional E2E section |
| **Phase 8** (v3) | **Phase 9** | **`phase9-e2e-execute.md`** | **Chỉ resume nếu `v3_flags.exec_scenarios=true` AND scenarios-manifest non-empty AND Playwright MCP available** |
| **Phase 9** (v3) | **Phase 10** | **`phase10-e2e-resolution.md`** | **Chỉ resume nếu Phase 9 có ≥1 FAIL trong e2e-results.json** |
| **Phase 10** (v3) | **Phase 8 re-write** | **`phase8-report.md`** | **Re-execute Phase 8 Step 8.3.6b + Step 8.4.6b với E2E summary populate (loop-back giới hạn 1 lần — anti-loop guard)** |

---

## Resume Strategy Matrix (Future — optional)

> Default: `prompt` (AskUserQuestion). Future enhancement: `--resume-strategy=<value>` cho automation.

| Pipeline state | `prompt` (default) | `auto` (CI/cron) | `force-fresh` |
|----------------|--------------------|------------------|---------------|
| `DONE` | AskUser: Re-run / Cancel | Cancel silently | Tạo fresh session |
| `failed` | AskUser: Resume / Fresh / Cancel | Resume từ failed phase | Tạo fresh session |
| `in_progress` | Continue resume | Continue resume | Tạo fresh session |

**Note v1.0:** Chỉ implement default `prompt`. `--resume-strategy` defer cho v2.

---

## Anti-Staleness Guard (E013-like)

```bash
STALENESS_CHECK_MAX_PCT=30  # Configurable qua MCV3_CMI_STALENESS_MAX_PCT

# Pseudo: nếu >30% files changed since checkpoint → WARN + AskUser
# Default: Fresh run recommended (vì regression scan có thể stale)
```

---

## Partial Output Handling (R5 detail)

> Phase đang `in_progress` thường để lại OUTPUT FILES KHÔNG COMPLETE.
> Re-run đè trực tiếp có thể (a) gây POST-GATE conflict, (b) mất forensic data cần debug.

```bash
# Khi phát hiện phase $N đang in_progress:
RESUME_PHASE_DIR_NAME=$(get_phase_dir_name $RESUME_PHASE)
PHASE_DIR="$SESSION_DIR/phase${RESUME_PHASE}-${RESUME_PHASE_DIR_NAME}"

if [ -d "$PHASE_DIR" ] && [ -n "$(ls -A "$PHASE_DIR" 2>/dev/null)" ]; then
  ARCHIVE_TS=$(date +%Y%m%dT%H%M%S)
  PARTIAL_DIR="${PHASE_DIR}.partial-${ARCHIVE_TS}"

  log_phase_event "resume" "CHECKPOINT" "{\"note\":\"R5 archive partial → $(basename "$PARTIAL_DIR")\"}"
  mv "$PHASE_DIR" "$PARTIAL_DIR"
  mkdir -p "$PHASE_DIR"
fi
```

**Quy tắc:**
- MOVE (không copy) — giữ disk usage thấp
- Suffix `.partial-{YYYYMMDDTHHMMSS}/` tránh collision đa lần resume
- KHÔNG xoá `partial-*` directories tự động — user manual clean qua `find sessions/ -name 'phase*.partial-*' -mtime +7 -exec rm -rf {} +`

---

## Cross-References

| Reference | Section |
|-----------|---------|
| `_shared.md` | §1 State Vars, §13 Session Lock, §16 Session Isolation |
| `docs/04-skill-design/wf-cmi/07-procedures-structure.md` | §5 resume-status.md outline |
| `_contract.json §resume_routing` | Stale threshold, session ID format |

---

## Helper: get_phase_name (human-friendly, v3.0)

```bash
get_phase_name() {
  case "$1" in
    1)  echo "Init" ;;
    2)  echo "Discovery" ;;
    3)  echo "Invariant" ;;
    4)  echo "Coverage" ;;
    5)  echo "Aggregate" ;;
    6)  echo "Regression" ;;
    7)  echo "GAP + CDG" ;;
    8)  echo "Report" ;;
    9)  echo "E2E Execute (v3)" ;;
    10) echo "E2E Resolution (v3)" ;;
  esac
}
```

---

## --scenarios-only Handler (v3.0 NEW — cross-reference)

> **Implementation chính:** `phase1-init.md §Step 1.21 --scenarios-only route bypass`
>
> File này chỉ cung cấp routing reference. Khi user pass `--scenarios-only`, dispatch ở `phase1-init.md` Step 1.1.8 sẽ route trực tiếp sang Step 1.21 bypass thay vì qua resume-status.md.

**Use cases hợp lệ cho `--scenarios-only`:**

1. **Re-execute Phase 9-10 sau khi fix lỗi:**
   - Session cũ Phase 9 fail (vd: lint scenarios fail) → user sửa scenarios → re-execute via `--scenarios-only`
   - Command: `/wf-cmi --scenarios-only --session-id=2026-05-17-system-foo-01 --exec-scenarios`

2. **Chạy lại E2E sau khi update FE/BE:**
   - Session cũ DONE đầy đủ Phase 1-8 + Phase 9-10 → developer push fix → re-execute để xem có regression không
   - Command: `/wf-cmi --scenarios-only --session-id=<ID> --exec-scenarios --strict-evidence`

3. **Chạy Playwright lần đầu trên session cũ (chưa từng exec):**
   - Session cũ chạy với profile=deep nhưng không có `--exec-scenarios` → CD41 sinh scenarios xong, Phase 9 SKIP
   - User muốn execute lại: `/wf-cmi --scenarios-only --session-id=<ID> --exec-scenarios`

**Routing flow (--scenarios-only):**

```
/wf-cmi --scenarios-only --session-id=<ID> [--exec-scenarios] [--no-prompt] [...]
    ↓
phase1-init.md Step 1.1 parse args
    ↓
phase1-init.md Step 1.1.7b validate v3 combinations
    ├── --scenarios-only thiếu --session-id → E016b STOP
    ├── --scenarios-only + --resume → E016b STOP (mutual exclusive)
    └── --scenarios-only + --session-id valid → continue
    ↓
phase1-init.md Step 1.1.8 dispatch
    ├── --status → resume-status.md §--status (early exit)
    ├── --resume → resume-status.md §--resume
    └── --scenarios-only → phase1-init.md Step 1.21 bypass
    ↓
phase1-init.md Step 1.21 verify target session pre-conditions
    ├── Target session integrity-status.json exists
    ├── Target session pipeline_status ∈ {DONE, failed_phase_9_or_10}
    ├── Target session phase8-report/integrity-impact.json exists
    └── Target session scenarios-manifest.json non-empty
    ↓
Inherit SESSION_DIR + re-acquire lock + UPDATE v3_flags
    ↓
Route trực tiếp Phase 9 → phase9-e2e-execute.md
    ↓
Phase 9 PASS → Phase 10 (nếu FAIL) → Phase 8 re-write v3 E2E section
    ↓
DONE
```

**Stale check exception:**

`--scenarios-only` SKIP stale check (R6) vì user explicit muốn re-execute. Tuy nhiên Phase 9 PRE-GATE T1 sẽ verify scenarios-manifest.json file mtime — nếu manifest > 30 ngày, WARN E170 (stale-registry warning, không block).
