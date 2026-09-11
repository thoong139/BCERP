# Phase 0: Detection

> **Skill:** wf-legacy-scan
> **Stage:** 0 (entry point)
> **Mode:** DETERMINISTIC — bash scripts (no agents)
> **Load condition:** Entry point của pipeline. SKILL.md route vào file này ngay khi khởi động (trừ khi `--status` hoặc `--resume` — xem `resume-status.md`).

---

## Mô tả

Deterministic scan — xác định cấu trúc, tech stack, quy mô dự án. Tạo `project-profile.json`
làm nền tảng cho mọi stage downstream. KHÔNG dùng AI ở stage này.

## Reference Sections (lazy-load khi cần)

- `_shared.md` §State Variables Glossary
- `_shared.md` §LEGACY_MODE Detection
- `_shared.md` §Project Size Tiers
- `_shared.md` §Tech Stack Verification Protocol (CORE-014)
- `_shared.md` §Pipeline Data Persistence Rules
- `_shared.md` §Atomic Write Pattern
- `_shared.md` §Task Planning (Protocol 9)
- `_shared.md` §Execution Trace (CORE-026)
- `_shared.md` §Phase Summary (CORE-028)
- `_shared.md` §Auto-Fix & Escalation Protocol (Protocol 1, 2)
- `_shared.md` §On Failure — Standard Format

---

## PRE-GATE

```
test -d "$PROJECT_PATH"
```

Nếu FAIL → ERROR E001 ("Project path không tồn tại"), STOP.

## INPUT

- Argument `project-path` hoặc CWD
- Flags: `--status`, `--resume`, `--re-vision`, `--batch-size=N`, `--profile=<p>`,
  `--session=ID`, `--incremental`, `--since=<git-ref>`, `--no-cache`, `--cache-publish`

## OUTPUT

- `.mc-data/work/legacy-scan/legacy-scan-status.json` (pipeline status, init)
- `.mc-data/work/legacy-scan/legacy-scan-plan.md` (execution plan, Protocol 9)
- `.mc-data/work/legacy-scan/error-ledger.json` (error tracking, init)
- `.mc-data/work/legacy-scan/project-profile.json` (tech stack + maturity + complexity, `tech_stack_verified=true`)
- **v5.0 Phase B — Session isolation outputs:**
  - `.mc-data/work/legacy-scan/sessions/$SESSION_ID/` (session dir với `layers/L4/`, `layers/L5/`, `cache/`)
  - `.mc-data/work/legacy-scan/sessions/$SESSION_ID/scan-state.json` (canonical runtime state — xem `04-data-model.md §1.1`)
  - `.mc-data/work/legacy-scan/sessions/$SESSION_ID/session-log.json` (observability events)
  - `.mc-data/work/legacy-scan/sessions/$SESSION_ID/error-ledger.json` (per-session error tracking)
  - `.mc-data/work/legacy-scan/.session.lock` (file-lock — released on exit)
- In-memory state: `$SESSION_ID`, `$SESSION_DIR`, `$PROJECT_PATH`, `$MATURITY_LEVEL`, `$PROJECT_SIZE`, `$LPM_PARAMS`, `$TECH_STACK_VERIFIED`, `$USER_FLAG_RE_VISION`, `$BATCH_SIZE`

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.0 | **[TODOWRITE INIT]** Khởi tạo TodoWrite với 8 phases (bao gom Phase 0B) theo `_shared.md §Task Planning (Protocol 9)`. Mark Phase 0 = in_progress. | TodoWrite | 8 todos created |
| 0.0b | **[TRACE START]** Append START event vào `.mc-data/work/_trace/session-log.json` theo `_shared.md §Execution Trace (CORE-026)` (phase=0) | Bash | Event appended |
| 0.1-PRE | **[FLAG DISPATCH — PRE Session Init]** Parse các flags quan trọng `--status` và `--resume` TRƯỚC KHI chạy Session Init (A2-C1 guard). Nếu phát hiện 1 trong 2 flag này → **DISPATCH ngay** tới `resume-status.md §--status Handler` hoặc §Resume Handler → STOP. Không tạo session directory mới, không acquire file-lock. Lý do: trước đây Session Init chạy TRƯỚC khi dispatch nên mỗi lần user gọi `--status` đều tạo session rỗng + lock orphan. | Bash | Dispatch hoặc tiếp Step 0.0c |
| 0.0c | **[SESSION INIT v5.0]** CHỈ chạy khi KHÔNG phải `--status` / `--resume`. DISPATCH tới §Session Init (v5.0 Phase B) bên dưới — tạo `$SESSION_ID`, acquire file-lock, create session dir, init scan-state.json. | Bash | `$SESSION_DIR` exported + `scan-state.json` valid |
| 0.1 | Parse arguments: `project-path`, `--re-vision`, `--batch-size`, `--profile`, `--session`, `--incremental`, `--since`, `--no-cache`, `--cache-publish` — xem §CLI Flags Parsing bên dưới. Export `$USER_FLAG_RE_VISION`, `$BATCH_SIZE`, `$PROFILE_ARG`, `$INCREMENTAL`, `$SINCE_REF`, `$NO_CACHE`, `$CACHE_PUBLISH`. (Lưu ý: `--status`/`--resume` đã được xử lý ở Step 0.1-PRE.) | Bash | Arguments captured |
| 0.1b | **Resolve `$PROJECT_PATH`**: (1) argument → (2) CWD. Convert to absolute path. | Read/Bash | `$PROJECT_PATH` resolved |
| 0.1c | **Validate incremental flags** (§Incremental Flag Validation): neu `$SINCE_REF` non-empty nhưng dự án không phải git repo → ERROR E020 + STOP. Neu `$SINCE_REF` non-empty nhưng `$INCREMENTAL` = false → ERROR E021. | Bash | Flags validated |
| 0.1d | **Profile mismatch check (A6-M1 guard)**: sau khi resume đã export `$PROFILE` từ `scan-state.json`, nếu user truyền `--profile=X` khác với `$PROFILE` đã lưu → WARNING + AskUserQuestion: "Session dùng profile `$PROFILE`, bạn truyền `--profile=X`. (a) Tiếp tục profile gốc (khuyến nghị), (b) Re-run Phase 0B với profile mới (depth_map thay đổi)". Chỉ chạy cho `--resume` path (Step 0.1-PRE đã dispatch rồi, nên bước này thực ra nằm ở resume-status.md). | Bash | User choice applied |
| 0.2c | **Check existing `.mc-data/` state** TRƯỚC KHI TẠO FILE — xem §Pre-Init State Check bên dưới | Read | State confirmed |
| 0.3 | `mkdir -p .mc-data/work/legacy-scan/{inventory,classified,extracted} .mc-data/docs/{_meta,phase0-brainstorm/policies,phase1-business,phase2-features,phase3-architecture} .mc-data/sync .mc-data/work/_trace` | Bash | Dirs exist |
| 0.3b | **[READ-TEMPLATE]** READ `templates/error-ledger.json` → POPULATE (init empty) → WRITE `.mc-data/work/legacy-scan/error-ledger.json` (nếu chưa tồn tại) qua **Atomic Write Pattern** | Write | File exists |
| 0.4 | **[READ-TEMPLATE]** READ `templates/legacy-scan-status.json` → POPULATE (skill_id, phase=0, status=in_progress) → WRITE `.mc-data/work/legacy-scan/legacy-scan-status.json` qua **Atomic Write Pattern** | Write | File exists |
| 0.5 | Chạy `.claude/scripts/legacy-scan-detect.sh "$PROJECT_PATH" .mc-data/work/legacy-scan` → `project-profile.json` (template `templates/project-profile.json` là schema reference cho POST-GATE) | Bash | Profile exists |
| 0.5b | **Tech Stack Verification (CORE-014):** chạy theo `_shared.md §Tech Stack Verification Protocol`. Cập nhật `project-profile.json` với `tech_stack_verified`, `verification_method`, `confidence_per_item`, `infra_services` | Read/Bash | `project-profile.tech_stack_verified == true` (hoặc false + WARN) |
| 0.5c | Extract `$MATURITY_LEVEL`, `$PROJECT_SIZE`, `$LPM_PARAMS` từ `project-profile.json` (xem `_shared.md §Project Size Tiers`) | Read | State vars set |
| 0.6 | Nếu `--resume`: chạy `.claude/scripts/legacy-scan-staleness.sh "$PROJECT_PATH" .mc-data/work/legacy-scan/ledger.json` → staleness report (2 args) | Bash | Staleness report |
| 0.7 | Nếu stale > 30%: WARNING E013, hỏi user (continue / partial re-scan / full re-scan) | AskUserQuestion | User informed |
| 0.8 | **[READ-TEMPLATE]** READ `templates/legacy-scan-plan.md` → POPULATE (stages, strategy=TBD, estimated duration) → WRITE `.mc-data/work/legacy-scan/legacy-scan-plan.md` (v4.1 compat, deprecated v5.1) | Write | Plan exists |
| 0.8b | **[READ-TEMPLATE v5.0]** READ `templates/scan-plan.md` → POPULATE (same data, session-scoped) → WRITE `$SESSION_DIR/scan-plan.md` (Protocol 9 PLN — canonical v5.0) | Write | Session plan exists |
| 0.8c | **[READ-TEMPLATE v5.0]** READ `templates/phase-summary.md` → INIT `$SESSION_DIR/phase-summary.md` (header + placeholder for Phase 0) neu chua co | Write | Session phase-summary initialized |
| 0.9 | Cập nhật `legacy-scan-status.json`: `stages.detection.status = "completed"` qua **Atomic Write Pattern** | Edit | Updated |
| 0.10 | **[PHASE SUMMARY]** APPEND section "Phase 0: Detection — PASS" vào `.mc-data/work/legacy-scan/phase-summary.md` theo `_shared.md §Phase Summary (CORE-028)` | Write | Section appended |
| 0.11 | **[TRACE COMPLETE]** Append COMPLETE event vào `session-log.json` (phase=0, duration_ms, metadata={maturity_level, project_size}) | Bash | Event appended |
| 0.12 | **[TODO UPDATE]** Mark Phase 0 = completed, Phase 0A = in_progress trong TodoWrite | TodoWrite | Updated |

---

## CLI Flags Parsing (Step 0.1)

```bash
# Defaults
USER_FLAG_RE_VISION=false
BATCH_SIZE=100
PROFILE_ARG=""
SESSION_ID_OVERRIDE=""
INCREMENTAL=false
SINCE_REF=""
NO_CACHE=false
CACHE_PUBLISH=false
STATUS_FLAG=false
RESUME_FLAG=false

PROJECT_PATH=""

for arg in "$@"; do
  case "$arg" in
    --status)         STATUS_FLAG=true ;;
    --resume)         RESUME_FLAG=true ;;
    --re-vision)      USER_FLAG_RE_VISION=true ;;
    --batch-size=*)   BATCH_SIZE="${arg#--batch-size=}" ;;
    --profile=*)      PROFILE_ARG="${arg#--profile=}" ;;
    --session=*)      SESSION_ID_OVERRIDE="${arg#--session=}" ;;
    --incremental)    INCREMENTAL=true ;;
    --since=*)        SINCE_REF="${arg#--since=}" ;;
    --no-cache)       NO_CACHE=true ;;
    --cache-publish)  CACHE_PUBLISH=true ;;
    --*)              echo "[WARN] Unknown flag: $arg (ignored)" >&2 ;;
    *)                [ -z "$PROJECT_PATH" ] && PROJECT_PATH="$arg" ;;
  esac
done
export USER_FLAG_RE_VISION BATCH_SIZE PROFILE_ARG SESSION_ID_OVERRIDE \
       INCREMENTAL SINCE_REF NO_CACHE CACHE_PUBLISH STATUS_FLAG RESUME_FLAG PROJECT_PATH
```

**Validation rules:**
- `--batch-size=N` phai la integer > 0 (neu không → fallback 100 + WARN).
- `--profile=<p>` phải trong `{surface,standard,deep,exhaustive}` hoặc rỗng (IPS recommend).
- `--session=ID` dang `scan-*` (xem `templates/scan-state.json` schema).

---

## Incremental Flag Validation (Step 0.1c)

```bash
# Rule 1: --since yêu cầu --incremental
if [ -n "$SINCE_REF" ] && [ "$INCREMENTAL" != "true" ]; then
  log_error "ERROR E016: --since=$SINCE_REF requires --incremental flag."
  log_error "  Fix: add --incremental to your command."
  exit 1
fi

# Rule 2: --since yêu cầu git repo
if [ -n "$SINCE_REF" ]; then
  if ! git -C "$PROJECT_PATH" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_error "ERROR E015: --since=$SINCE_REF requires a git repository."
    log_error "  Project path: $PROJECT_PATH"
    log_error "  Fix options:"
    log_error "    1. Remove --since flag — mtime-based incremental still works."
    log_error "    2. Initialize git: 'cd $PROJECT_PATH && git init'."
    exit 1
  fi

  # Rule 3: --since ref phải resolve được
  if ! git -C "$PROJECT_PATH" rev-parse --verify "$SINCE_REF" >/dev/null 2>&1; then
    log_error "ERROR E017: --since=$SINCE_REF is not a valid git ref."
    log_error "  Try: --since=HEAD~5 hoặc --since=<commit-sha>."
    exit 1
  fi
fi

# Rule 4: --incremental standalone (không có --since) dùng mtime compare.
# Yêu cầu trước đó phải có scan-state.json hoặc legacy ledger.json để lấy previous_mtimes.
if [ "$INCREMENTAL" = "true" ] && [ -z "$SINCE_REF" ]; then
  if [ ! -s "$WORK_DIR/ledger.json" ] && [ ! -d "$WORK_DIR/sessions" ]; then
    log_warn "WARN E018: --incremental without previous scan → treating as full scan."
    log_warn "  All files will be classified as NEW (no baseline mtimes)."
    # Không exit — cho phép chạy, chỉ WARN.
  fi
fi
```

**Error codes:**
| Code | Ý nghĩa | Exit |
|------|---------|------|
| E015 | `--since` nhưng không phải git repo | 1 |
| E016 | `--since` nhưng thiếu `--incremental` | 1 |
| E017 | `--since=<ref>` không resolve được bởi git | 1 |
| E018 | `--incremental` standalone nhưng chưa có baseline | 0 (WARN only) |

---

## Session Init (v5.0 Phase B — Step 0.0c)

> Mục đích: tạo session isolation + file-lock để ngăn 2 scan chạy song song.
> Reference: `docs/design/skills/wf-legacy-scan/04-data-model.md §1.1, §6.1` và `06-bash-scripts.md §2`.

```bash
# Source shared library — orchestrator luon chay tu repo root (DEVKIT convention).
# KHONG dung BASH_SOURCE pattern (BASH_SOURCE[0] rong khi chay inline bash snippets).
if [ ! -f .claude/scripts/legacy-scan-common.sh ]; then
  echo "ERROR: Phai chay tu repo root (.claude/scripts/legacy-scan-common.sh not found from CWD)" >&2
  exit 1
fi
# shellcheck disable=SC1091
source .claude/scripts/legacy-scan-common.sh
_SCRIPT_NAME="wf-legacy-scan"

WORK_DIR=".mc-data/work/legacy-scan"
mkdir -p "$WORK_DIR"

# 1) Acquire file-lock (no wait — refuse nếu đã có scan khác chạy).
LOCK_FILE="$WORK_DIR/.session.lock"
if ! flock_acquire "$LOCK_FILE" 0; then
  log_error "Another scan session is active. Options:"
  log_error "  1. Wait for it to complete (check lock owner trong file)"
  log_error "  2. Wait LOCK_STALE_MINUTES (mặc định 60) → auto-cleaned"
  log_error "  3. Force unlock: rm $LOCK_FILE"
  exit 1
fi

# 2) Register cleanup trap — release lock on exit (any code path).
trap 'flock_release "$LOCK_FILE"' EXIT INT TERM

# 3) Generate SESSION_ID + tạo session directory.
SESSION_ID="$(generate_session_id)"
SESSION_DIR="$(init_session_dir "$WORK_DIR" "$SESSION_ID")"
export SESSION_ID SESSION_DIR

# 4) Init scan-state.json từ template.
TEMPLATE=".claude/skills/workflow/wf-legacy-scan/templates/scan-state.json"
init_scan_state \
  "$TEMPLATE" \
  "$SESSION_DIR/scan-state.json" \
  "$SESSION_ID" \
  "${PROJECT_PATH:-$(pwd)}" \
  "${STRATEGY:-unknown}" \
  "${MATURITY_LEVEL:-unknown}"

# 5) Init session-log.json + error-ledger.json trong session.
init_session_aux_files "$SESSION_DIR" "$SESSION_ID"

log_info "Session $SESSION_ID initialized at $SESSION_DIR"
```

**Acceptance:**
- `$SESSION_DIR/scan-state.json` valid (jq empty) với fields `session.id`, `session.created`, `session.project_path`.
- `$SESSION_DIR/layers/{L4,L5}/`, `$SESSION_DIR/cache/` tồn tại.
- `.session.lock` hiện diện trong khi scan chạy, cleaned up on exit.
- Concurrent scan thứ 2 bị refused với clear error message.

**Backward-compat note:** Legacy output paths (`legacy-scan-status.json`, `legacy-scan-plan.md`, `project-profile.json`, `error-ledger.json` tại root `$WORK_DIR`) vẫn được tạo như v4.1. `ledger.json` sẽ được generate 1-shot tại POST Phase 4 synthesize (xem `generate_legacy_ledger` trong shared library) — consumers `/wf-brainstorm` legacy flow vẫn đọc được.

---

## Pre-Init State Check (Step 0.2c)

```
Scenario-based routing dựa trên trạng thái hiện tại của .mc-data/:

(A) Pipeline COMPLETE (pipeline_status = "COMPLETE" trong ledger.json):
    - Nếu $USER_FLAG_RE_VISION == true:
        → auto-bypass E005, tiếp tục re-scan với strategy S6
    - Nếu không:
        → ERROR E005 ASK: "Pipeline đã hoàn tất trước đó. Re-scan hay cancel?"

(B) Pipeline IN_PROGRESS (có ledger.json nhưng pipeline_status != "COMPLETE"):
    → INFO: "Phát hiện pipeline đang dở. Dùng --resume để tiếp tục hoặc xóa .mc-data/work/legacy-scan/ để bắt đầu mới."
    → STOP

(C) Registry tồn tại (req-registry.json):
    → WARNING E016 ASK: "Registry đã tồn tại. Ghi đè (hủy dữ liệu cũ) hay cancel?"

(D) Fresh state (không có file nào):
    → Tiếp tục bình thường
```

---

## POST-GATE (Tier T1→T4 — CORE-012, Protocol 10)

```
T1 — Existence (file tồn tại + non-empty):
  1. test -s .mc-data/work/legacy-scan/project-profile.json
  2. test -s .mc-data/work/legacy-scan/legacy-scan-plan.md
  3. test -s .mc-data/work/legacy-scan/legacy-scan-status.json
  4. test -s .mc-data/work/legacy-scan/error-ledger.json
  5. test -s .mc-data/work/legacy-scan/phase-summary.md
  5a. test -s "$SESSION_DIR/scan-state.json"                        # v5.0 Phase B
  5b. test -d "$SESSION_DIR/layers/L4" -a -d "$SESSION_DIR/layers/L5" -a -d "$SESSION_DIR/cache"
  5c. test -s "$SESSION_DIR/session-log.json" -a -s "$SESSION_DIR/error-ledger.json"

T2 — Structure (required sections / fields):
  6. jq -e '.doc_maturity.level' project-profile.json     # maturity field present
  7. jq -e '.file_counts.total' project-profile.json      # counts field present
  8. jq -e '.structure' project-profile.json              # structure field present
  9. jq -e '.tech_stack_verified' project-profile.json    # verification flag (true/false)
  9a. jq -e '.session.id' "$SESSION_DIR/scan-state.json"  # v5.0 — scan-state có session.id
  9b. jq -e '.layers.L1' "$SESSION_DIR/scan-state.json"   # v5.0 — layers L1..L6 populated

T3 — Content depth (minimum thresholds):
  10. wc -c < project-profile.json | awk '{exit ($1 < 200)}'   # ≥200 bytes
  11. jq -e '.file_counts.total >= 0' project-profile.json     # numeric, ≥0
  12. wc -l < legacy-scan-plan.md | awk '{exit ($1 < 10)}'     # plan ≥10 dòng
  13. grep -q "Phase 0" .mc-data/work/legacy-scan/phase-summary.md   # summary có section Phase 0

T4 — Cross-reference (consistency giữa files):
  14. jq -e '.stages.detection.status == "completed"' legacy-scan-status.json
  15. MATURITY_PROFILE=$(jq -r '.doc_maturity.level' project-profile.json)
      MATURITY_STATUS=$(jq -r '.stages.detection.maturity // empty' legacy-scan-status.json)
      [ -z "$MATURITY_STATUS" ] || [ "$MATURITY_PROFILE" = "$MATURITY_STATUS" ]
  16. # v5.0 Dual-Status Mirror: session-scoped layer status khop legacy
      jq -e '.layers.L1.status == "completed"' "$SESSION_DIR/scan-state.json"
```

Nếu ANY tier fail → áp dụng `_shared.md §Auto-Fix & Escalation Protocol` (max 1 retry per tier).
Sau retry vẫn fail → đi qua `_shared.md §On Failure — Standard Format`.

## On Failure

Theo `_shared.md §On Failure — Standard Format`. Cụ thể Phase 0:
- T1 fail (project-profile.json missing) → re-run Step 0.5 (`legacy-scan-detect.sh`) x1
- T2 fail (.doc_maturity.level missing) → re-run Step 0.5b Tech Stack Verification
- T3 fail (file too short) → log warning, escalate
- T4 fail (status mismatch) → re-run Step 0.9 (sync ledger)
- Sau 3 attempts vẫn fail → STOP, AskUserQuestion: "Manual fix / Cancel / Open issue"

## Completion Log

Ghi vào `legacy-scan-status.json`:
```json
{
  "stages": {
    "detection": {
      "status": "completed",
      "maturity": "$MATURITY_LEVEL",
      "project_size": "$PROJECT_SIZE",
      "tech_stack_verified": true
    }
  }
}
```

## Next Phase

→ **Phase 0A** (`phase0a-assessment.md`) — Assessment scoring + strategy selection.
