# Phase 0 — PRE-GATE + Setup

> **Sprint 3 lazy-load refactor.** Parse args, validate target, tạo session dir,
> init scan-status.json + checkpoint.json + intermediate/, append trace START event.
> Phase 0.0 dispatch (Resume/Status) tách riêng vào `resume-status.md` (chạy TRƯỚC phase này).

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §Helper Functions (`save_checkpoint`)
- `_shared.md` §Template Usage Rule (CORE-031)
- `_shared.md` §Error Handling Matrix

## Load Condition

Entry point cho FRESH RUN (không có `--resume` / `--status`).
Nếu `--resume` → `resume-status.md` đã dispatch → skip file này, jump trực tiếp đến phase từ checkpoint.

---

## PRE-GATE

```
- [ ] `--target` argument được cung cấp
- [ ] Target tồn tại (path exists hoặc URL reachable hoặc swagger spec parseable)
- [ ] Bash scripts available: source `.claude/scripts/scan-target-common.sh` (Sprint 4)
```

### 0.0c — Source bash helpers (Sprint 4 bash delegation)

```bash
# Source common.sh để có atomic_write_json, json_escape, slugify, resolve_session_id, ...
SCRIPTS_DIR=".claude/scripts"
[ -f "$SCRIPTS_DIR/scan-target-common.sh" ] || {
  echo "ERROR: Missing $SCRIPTS_DIR/scan-target-common.sh — Sprint 4 bash delegation requires this file"
  exit 2
}
source "$SCRIPTS_DIR/scan-target-common.sh"
```

## INPUT

| Variable | From | Description |
|----------|------|-------------|
| `$ARGUMENTS` | CLI | Raw arguments string |

## Steps

### 0.1 — Parse Arguments

```
$ARGUMENTS được cung cấp qua CLI args hoặc inline text.

Phân tích:
  target       = extract value after "--target=" | first positional arg if no flag
  module_name  = extract value after "--module=" | null (auto-detect)
  compare_path = extract value after "--compare=" | null
  scan_depth   = extract value after "--depth=" | null (resolved sau khi parse profile)
  output_dir   = extract value after "--output=" | null (use default)
  NO_CACHE     = "true" if "--no-cache" present, else "false"   # Sprint 6 cache bypass
  SCAN_PROFILE = extract value after "--profile=" | "standard"   # Sprint 7 profile system
  CLI_MAX_PAGES = extract value after "--max-pages=" | null       # Sprint 7 override
  SINCE_REF    = extract value after "--since=" | null            # Sprint 7 delta scan
  CACHE_FP_MODE = extract value after "--cache-fingerprint-mode=" | "strict"   # v2.0.1 BUG-003 fix

IF target is null:
  ERROR "Thiếu --target. Cú pháp: /wf-scan-target --target=<path|url>"
  SHOW: "Ví dụ:"
        "  /wf-scan-target --target=apps/backend/Eureka.Modules.CRM"
        "  /wf-scan-target --target=https://example.com/api"
        "  /wf-scan-target --target=apps/backend --module=crm --compare=.mc-data/docs/phase2-features/crm/crm-feat.md"
  STOP
```

### 0.1b — Argument Validation Hardening (GAP-11 — Sprint 7)

> **Sprint 7 hardening.** Validate enum values, numeric ranges, git refs, conflict detection.
> Run NGAY SAU parse (0.1) và TRƯỚC validate target type (0.2) để fail-fast khi args sai.

```bash
# 1) Validate --depth (enum: shallow|deep) — chỉ check khi user explicit pass
if [[ -n "${CLI_DEPTH:-}" ]] && [[ "$CLI_DEPTH" != "shallow" ]] && [[ "$CLI_DEPTH" != "deep" ]]; then
  ERROR "--depth không hợp lệ: '$CLI_DEPTH'. Giá trị hợp lệ: shallow | deep"
  STOP
fi

# 2) Validate --profile (enum: quick|standard|deep|exhaustive)
case "$SCAN_PROFILE" in
  quick|standard|deep|exhaustive) ;;
  *)
    ERROR "--profile không hợp lệ: '$SCAN_PROFILE'. Giá trị hợp lệ: quick | standard | deep | exhaustive"
    STOP
    ;;
esac

# 3) Validate --max-pages (numeric 1-200)
if [[ -n "$CLI_MAX_PAGES" ]]; then
  if ! [[ "$CLI_MAX_PAGES" =~ ^[0-9]+$ ]]; then
    ERROR "--max-pages phải là số nguyên dương. Got: '$CLI_MAX_PAGES'"
    STOP
  fi
  if [[ "$CLI_MAX_PAGES" -lt 1 ]] || [[ "$CLI_MAX_PAGES" -gt 200 ]]; then
    ERROR "--max-pages phải nằm trong [1, 200]. Got: $CLI_MAX_PAGES.
            Để scan nhiều hơn 200 pages → chạy nhiều sessions với scope filter
            (hard cap 200 — Q4 quyết định, tránh DDoS target site)."
    STOP
  fi
fi

# 4) Validate --cache-fingerprint-mode (enum: strict|loose) — v2.0.1 BUG-003 fix
case "${CACHE_FP_MODE:-strict}" in
  strict|loose) ;;
  *)
    ERROR "--cache-fingerprint-mode không hợp lệ: '$CACHE_FP_MODE'. Giá trị hợp lệ: strict | loose
           strict (default): include git_dirty signal — cache invalidate khi có uncommitted changes
           loose: skip git_dirty — cache stable trên dev project chưa gitignore .mc-data/"
    STOP
    ;;
esac
```

### 0.1c — Resolve Profile + Apply Defaults (Sprint 7 profile system — Q4 = D ADAPTIVE)

> **Sprint 7 profile system.** Map `$SCAN_PROFILE` → defaults cho `$scan_depth` và `$MAX_PAGES`.
> CLI flags (`--depth`, `--max-pages`) override profile defaults.
>
> **Q4 = D ADAPTIVE (chốt từ AI auto-decisions Session 2):**
>
> | Profile | scan_depth | MAX_PAGES (URL crawl) | Use case |
> |---------|-----------|----------------------|----------|
> | `quick` | shallow | 5 | Smoke test, quick overview |
> | `standard` (default) | deep | 25 | Default scan |
> | `deep` | deep | 50 | Comprehensive scan với business rules deep extract |
> | `exhaustive` | deep | 100 | Enterprise sites, full coverage + LPM extensions |
> | (override) | từ `--depth` | từ `--max-pages` (1-200) | User control |

```bash
# Apply profile defaults
case "$SCAN_PROFILE" in
  quick)
    PROFILE_DEPTH="shallow"
    PROFILE_MAX_PAGES=5
    ;;
  standard)
    PROFILE_DEPTH="deep"
    PROFILE_MAX_PAGES=25
    ;;
  deep)
    PROFILE_DEPTH="deep"
    PROFILE_MAX_PAGES=50
    ;;
  exhaustive)
    PROFILE_DEPTH="deep"
    PROFILE_MAX_PAGES=100
    ;;
esac

# CLI override > profile default
scan_depth="${CLI_DEPTH:-$PROFILE_DEPTH}"
MAX_PAGES="${CLI_MAX_PAGES:-$PROFILE_MAX_PAGES}"

Log: "Profile: $SCAN_PROFILE (depth=$scan_depth, max_pages=$MAX_PAGES)"
```

> **Note:** `--since` validation chạy sau Step 0.2 (target type detection) — xem Step 0.2b.

### 0.2 — Validate Target & Detect Type

```
IF target starts with "http://" OR "https://":
  target_type = "url"
  → Log: "Target type: URL"

ELSE IF target ends with ".json" AND (target contains "swagger" OR "openapi"):
  target_type = "swagger-spec"
  → Log: "Target type: Swagger/OpenAPI spec"

ELSE:
  → Check path existence: test -e {target}
  IF exists:
    target_type = "local-source"
    → Log: "Target type: Local source code"
  ELSE:
    ERROR "Path không tồn tại: {target}"
    SUGGEST "Kiểm tra path tương đối từ thư mục hiện tại. Dùng ls để xác nhận."
    STOP
```

### 0.2b — Validate --since (Delta Scan — Sprint 7 PHẦN B)

> **Sprint 7 delta scan.** `--since=<git-ref>` chỉ áp dụng cho `target_type=local-source`
> trong git repo. Validate ref tồn tại + conflict với URL/swagger-spec target.
> Chạy SAU 0.2 vì cần `$target_type` đã resolved.
>
> **Note:** `--since` KHÔNG thuộc fingerprint composite (Q6) — fingerprint cùng target+git_HEAD
> với hoặc không `--since` sẽ giống nhau. Nhưng cache target-map.json là FULL scan, delta là
> SUBSET → mismatch → defensive skip cache khi `--since` set (xem Phase 1.5).

```bash
if [[ -n "$SINCE_REF" ]]; then
  # 1) Conflict detection: --since requires local-source target
  if [[ "$target_type" == "url" ]] || [[ "$target_type" == "swagger-spec" ]]; then
    ERROR "--since=$SINCE_REF chỉ áp dụng cho local-source target trong git repo.
            Target hiện tại type=$target_type không support delta scan."
    STOP
  fi

  # 2) Verify target trong git repo
  if ! git -C "$target" rev-parse --git-dir >/dev/null 2>&1; then
    ERROR "--since=$SINCE_REF yêu cầu target trong git repo, nhưng '$target' không phải git repo
            (hoặc không có .git directory). Hủy delta scan."
    STOP
  fi

  # 3) Verify git ref tồn tại
  if ! git -C "$target" rev-parse --verify "$SINCE_REF" >/dev/null 2>&1; then
    ERROR "Git ref '$SINCE_REF' không tồn tại trong target repo.
            Kiểm tra với: git -C $target log --oneline -5"
    STOP
  fi

  Log: "Delta scan enabled: --since=$SINCE_REF (changed files sẽ compute ở Phase 1.4b)"
fi
```

### 0.3 — Tạo Session Directory (GAP-01 fix — Protocol 18.2 / CORE-030)

> Session ID format chuẩn: `{YYYY-MM-DD}-{scope-label}[-{N}]`
> Lý do: align với Protocol 18.2 session isolation pattern (giống wf-legacy-scan v5.0).
> Format cũ `scan-{TIMESTAMP}` không đọc được, không re-run friendly, conflict với multi-dev concurrent runs.

```
DATE = $(date +%Y-%m-%d)

# 1) Resolve SCOPE_LABEL theo priority:
IF module_name is provided AND module_name != "auto":
  SCOPE_LABEL = slugify(module_name)              # lowercase-kebab-case
ELSE IF target_type == "url":
  # Extract hostname không TLD
  hostname = $(echo "{target}" | awk -F[/:] '{print $4}')
  SCOPE_LABEL = slugify(hostname | sed 's/\.[a-z]*$//')   # "api.example.com" → "api-example"
ELSE IF target_type == "swagger-spec":
  SCOPE_LABEL = slugify(swagger_data.info.title) || "swagger"
ELSE IF target_type == "local-source":
  basename = basename({target})
  # Strip prefix Eureka.Modules. nếu có
  basename_cleaned = $(echo "{basename}" | sed 's/^Eureka\.Modules\.//')
  SCOPE_LABEL = slugify(basename_cleaned)
ELSE:
  SCOPE_LABEL = "scan"                            # fallback

# slugify rule (lowercase, kebab-case, alphanumeric only):
#   "Eureka.Modules.CRM" → "crm" (sau strip prefix)
#   "Order Management"   → "order-management"
#   "user_profile"       → "user-profile"

# 2) Compose BASE_ID + auto-suffix khi trùng (multi-dev safety, re-run cùng ngày)
SESSIONS_DIR = ".mc-data/work/wf-scan-target/sessions"
BASE_ID = "{DATE}-{SCOPE_LABEL}"
SESSION_ID = BASE_ID
N = 2
WHILE test -d "{SESSIONS_DIR}/{SESSION_ID}":
  SESSION_ID = "{BASE_ID}-{N}"
  N = N + 1
END

# 3) Resolve SESSION_DIR
IF output_dir is null:
  SESSION_DIR = "{SESSIONS_DIR}/{SESSION_ID}"
ELSE:
  SESSION_DIR = output_dir
  # NOTE: --output trigger CDG-02 (xem step 0.3b) khi dir đã có nội dung

Bash: mkdir -p {SESSION_DIR}
Log: "Session ID: {SESSION_ID}"
Log: "Session directory: {SESSION_DIR}"
```

### 0.3b — CDG-02: Output Directory Conflict (GAP-04 fix — Protocol 16)

> Áp dụng khi user cung cấp `--output=<path>` và path đó đã có nội dung.
> KHÔNG trigger khi auto-resolved SESSION_DIR (đã đảm bảo unique qua suffix N).

```
IF output_dir was provided AND test -d {SESSION_DIR}:
  existing_files = $(ls -A {SESSION_DIR} 2>/dev/null | grep -v '^\.lock$' | head -10)

  IF existing_files is not empty:
    # CDG-02 trigger — yêu cầu user xác nhận overwrite
    Display:
      "⚠️ AI sắp ghi vào thư mục '{SESSION_DIR}' — thư mục này đã có nội dung từ trước.

      Files có sẵn (tối đa 10 files đầu):
      {existing_files}

      Thay đổi dự kiến:
      - Ghi mới: scan-status.json, module-map.md, target-map.json,
                 feature-inventory.md, phase-summary.md{, gap-report.md (nếu --compare)}
      - Có thể ghi đè files trùng tên

      Bạn có muốn tiếp tục cập nhật không? (Có / Không)"

    IF user trả lời "Không":
      Display: "Thư mục '{SESSION_DIR}' giữ nguyên nội dung hiện tại."
      SUGGEST: "Dùng --output=<dir-mới> hoặc bỏ --output để dùng auto session ID."
      STOP

    IF user trả lời "Có":
      Log: "User accepted CDG-02 overwrite of {SESSION_DIR}"
      Continue
```

### 0.3c — Lock File Lifecycle (Sprint 6 multi-dev safety)

> **Sprint 6 hardening.** Lock file ngăn 2 process cùng ghi vào 1 SESSION_DIR.
> Sprint 2 đã có basic create/cleanup; Sprint 6 thêm:
> - **Cross-host detection** — host trong .lock != hostname() → ERROR ngay (kill -0 cross-host không khả thi)
> - **Same-host PID alive** — ERROR "đang chạy local"
> - **Same-host PID dead** — auto cleanup + tạo lock mới
> - **trap EXIT** — đảm bảo cleanup khi exit (success/fail/Ctrl+C)
>
> Helper canonical: `check_lock_status` trong `scan-target-common.sh` (Sprint 6 added).
>
> **Note:** Phase 0.3c này CHỈ chạy với fresh run. `--resume` đi qua `resume-status.md`
> với riêng logic lock check (đã có ở Sprint 2 + được hardening cùng pattern Sprint 6).

```bash
LOCK_FILE="$SESSION_DIR/.lock"

# 1) Check existing lock (chỉ khi SESSION_DIR đã tồn tại — output= override)
if [[ -f "$LOCK_FILE" ]]; then
  # Sprint 6 — extended status với cross-host detection
  LOCK_INFO=$(check_lock_status "$LOCK_FILE" || true)
  LOCK_STATUS=$?

  case $LOCK_STATUS in
    0)  # alive_local — process đang chạy trên cùng máy
      LOCK_PID=$(echo "$LOCK_INFO" | cut -d'|' -f2)
      LOCK_STARTED=$(echo "$LOCK_INFO" | cut -d'|' -f4)
      ERROR "Session đang chạy local (PID $LOCK_PID, started $LOCK_STARTED).
              Đợi process kết thúc, hoặc dùng --output=<dir-mới> tạo session khác."
      STOP
      ;;
    3)  # alive_cross_host — lock từ máy khác, KHÔNG cleanup được
      LOCK_PID=$(echo "$LOCK_INFO" | cut -d'|' -f2)
      LOCK_HOST=$(echo "$LOCK_INFO" | cut -d'|' -f3)
      LOCK_STARTED=$(echo "$LOCK_INFO" | cut -d'|' -f4)
      ERROR "Session đang chạy trên máy khác (host=$LOCK_HOST, PID=$LOCK_PID, started=$LOCK_STARTED).
              Không thể verify cross-host PID — dùng --output=<dir-mới> tạo session độc lập,
              hoặc đợi user trên $LOCK_HOST hoàn tất rồi xoá thủ công nếu cần."
      STOP
      ;;
    2)  # dead_local — PID dead trên cùng máy, cleanup an toàn
      LOCK_PID=$(echo "$LOCK_INFO" | cut -d'|' -f2)
      log_warn "Cleaning up stale lock (PID $LOCK_PID dead on local host)"
      release_lock "$LOCK_FILE"
      ;;
    1)  # no_lock hoặc malformed — coi như no lock, tiếp tục
      ;;
  esac
fi

# 2) Tạo lock mới với metadata đầy đủ (pid, host, user, started_at, skill, session_id)
create_lock "$LOCK_FILE" "$SESSION_ID"

# 3) Setup trap để cleanup khi exit (Sprint 6 — fix trường hợp Ctrl+C / FAIL bỏ quên lock)
#    EXIT trap chạy cho cả normal exit, error exit, và signal SIGINT/SIGTERM.
trap 'release_lock "$LOCK_FILE" 2>/dev/null || true' EXIT

Log: "Lock acquired — $LOCK_FILE (PID $$ on $HOSTNAME)"
```

### 0.4 — Khởi Tạo scan-status.json

```
Template Usage Rule (CORE-031):
  READ .claude/skills/workflow/wf-scan-target/templates/scan-status.json
  POPULATE:
    session_id   = SESSION_ID
    target       = target
    target_type  = target_type
    module_name  = module_name || "auto"
    scan_depth   = scan_depth
    status       = "in_progress"
    started_at   = now()
    target_fingerprint = null   # sẽ populate ở 0.4b sau khi detect tech_stack
    checkpoint_ref = "checkpoint.json"
    intermediate_dir = "intermediate/"
    lock_file = ".lock"
  WRITE {SESSION_DIR}/scan-status.json

Bash: mkdir -p "$SESSION_DIR/intermediate"   # GAP-05 — chuẩn bị thư mục cho partial outputs
```

### 0.4b — Khởi Tạo checkpoint.json (GAP-05 — Sprint 2)

> Tạo checkpoint.json từ template ngay sau scan-status.json. target_fingerprint
> sẽ populate sau Phase 1 khi đã có tech_stack (compute_fingerprint cần tech_stack).

```
Template Usage Rule (CORE-031):
  READ .claude/skills/workflow/wf-scan-target/templates/checkpoint.json
  POPULATE:
    {{CHECKPOINT_ID}}        → "CP-SCAN-{SESSION_ID}-001"
    {{SESSION_ID}}           → SESSION_ID
    {{SKILL_VERSION}}        → "1.3.0"
    {{TARGET}}               → target
    {{TARGET_FINGERPRINT}}   → "" (populate sau Phase 1)
    {{CREATED_AT_ISO8601}}   → now() ISO-8601 UTC
    {{UPDATED_AT_ISO8601}}   → now() ISO-8601 UTC

    args_snapshot.target     → target
    args_snapshot.module     → module_name || null
    args_snapshot.compare    → compare_path || null
    args_snapshot.depth      → scan_depth
    args_snapshot.output     → output_dir || null

    next_action.phase        → "phase_1"
    next_action.layer        → null
    next_action.step         → "tech_stack_detection"

  WRITE {SESSION_DIR}/checkpoint.json
  VALIDATE: jq empty {SESSION_DIR}/checkpoint.json
```

### 0.5 — Thông báo bắt đầu

```
Output:
"🔍 /wf-scan-target bắt đầu scan..."
"  Target:     {target}"
"  Type:       {target_type}"
"  Module:     {module_name || 'auto-detect'}"
"  Depth:      {scan_depth}"
"  Session:    {SESSION_DIR}"
```

### 0.5b — Append session-log.json (GAP-03 fix — Protocol 15 / CORE-026)

> Ghi START event vào trace log để observability. Append-only, không block skill execution nếu fail.
> File này là OUTPUT-ONLY — KHÔNG bao giờ Read lại làm input context (Protocol 15.3).

```bash
TRACE_FILE=".mc-data/work/_trace/session-log.json"
mkdir -p "$(dirname $TRACE_FILE)"

# Khởi tạo từ template nếu chưa có
IF NOT test -f "$TRACE_FILE":
  cp .claude/doc-framework/_meta/session-log.template.json "$TRACE_FILE"
  # Reset entries[] sau khi copy template
  tmp=$(mktemp)
  jq '.entries = [] | .project = ""' "$TRACE_FILE" > "$tmp" && mv "$tmp" "$TRACE_FILE"

# Tính run_sequence cho /wf-scan-target
RUN_SEQ=$(jq '[.entries[] | select(.skill == "/wf-scan-target")] | length + 1' "$TRACE_FILE")

# Atomic append START event
tmp=$(mktemp)
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg sid "$SESSION_ID" \
   --argjson rs "$RUN_SEQ" \
   --arg tgt "$target" \
   --arg tt "$target_type" \
   '.entries += [{
      timestamp: $ts,
      skill: "/wf-scan-target",
      event: "START",
      run_sequence: $rs,
      phase: "Phase 0",
      session_id: $sid,
      details: {target: $tgt, target_type: $tt},
      files_created: 0,
      files_modified: 0,
      warnings: [],
      errors: [],
      decisions: []
    }]' "$TRACE_FILE" > "$tmp" && mv "$tmp" "$TRACE_FILE"

# Best-effort: nếu append fail, log warning nhưng KHÔNG block (Protocol 15.3 rule 5)
```

### 0.6 — Save Checkpoint sau Phase 0 (GAP-05 — Sprint 2)

```bash
save_checkpoint --phase phase_0 --status completed --next-phase phase_1 --next-step tech_stack_detection
# Phase 0 đánh dấu completed; next = Phase 1
```

## POST-GATE

```
- test -d $SESSION_DIR
- test -f $SESSION_DIR/scan-status.json
- test -f $SESSION_DIR/checkpoint.json
- test -d $SESSION_DIR/intermediate
- test -f $SESSION_DIR/.lock              # Sprint 6 — lock acquired
- target_type IN [local-source, url, swagger-spec]
- $RUN_SEQ set (cho Phase 5 COMPLETE event)
- trap 'release_lock' EXIT đã setup (Sprint 6)
- $SCAN_PROFILE IN [quick, standard, deep, exhaustive]   # Sprint 7
- $MAX_PAGES là số nguyên trong [1, 200]                  # Sprint 7
- IF $SINCE_REF non-empty: target trong git repo + ref valid (Sprint 7)
```

## OUTPUT (set for next phase)

| Variable | Type | Description |
|----------|------|-------------|
| `$target` | string | Target path/URL |
| `$target_type` | enum | local-source / url / swagger-spec |
| `$module_name` | string\|null | Module name (input or auto) |
| `$compare_path` | string\|null | Spec file path |
| `$scan_depth` | enum | shallow / deep (resolved từ profile + CLI override — Sprint 7) |
| `$SESSION_ID` | string | Session ID format chuẩn |
| `$SESSION_DIR` | path | Session directory |
| `$RUN_SEQ` | int | Sequence cho session-log entries |
| `$NO_CACHE` | bool | Sprint 6 — true nếu user pass `--no-cache` |
| `$SCAN_PROFILE` | enum | Sprint 7 — quick / standard / deep / exhaustive (default `standard`) |
| `$MAX_PAGES` | int | Sprint 7 — URL crawl page cap (5/25/50/100 theo profile, hoặc `--max-pages` override 1-200) |
| `$SINCE_REF` | string\|null | Sprint 7 — git ref cho delta scan (null = full scan) |
| `$CACHE_FP_MODE` | enum | v2.0.1 BUG-003 — strict (default) / loose. strict include git_dirty signal; loose skip để cache stable trên dev project chưa gitignore .mc-data/ |

## Next Phase

→ Read `procedures/phase1-detect.md`
