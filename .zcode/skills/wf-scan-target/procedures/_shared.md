# Shared Procedures — wf-scan-target

> **Sprint 3 lazy-load refactor.** Cross-cutting protocols, state variables glossary,
> helper functions, agent prompt templates, error handling matrix, FAIL event handler
> được sử dụng bởi nhiều Phase trong wf-scan-target.
> KHÔNG đọc file này standalone — chỉ load section cụ thể khi phase file chỉ định.

## Sections

- [State Variables Glossary](#state-variables-glossary)
- [Cross-Phase Data Flow](#cross-phase-data-flow)
- [Helper Functions](#helper-functions)
- [Agent Prompt Templates](#agent-prompt-templates)
- [Error Handling Matrix](#error-handling-matrix)
- [FAIL Event Handler (Protocol 15)](#fail-event-handler-protocol-15)
- [Template Usage Rule (CORE-031)](#template-usage-rule-core-031)
- [Concurrency Model (Sprint 6)](#concurrency-model-sprint-6)
- [Concurrency Test Scenarios (Sprint 6)](#concurrency-test-scenarios-sprint-6)

---

## State Variables Glossary

Các biến in-memory được set/đọc xuyên suốt skill execution.

| Variable | Type | Set by | Used by | Description |
|----------|------|--------|---------|-------------|
| `$ARGUMENTS` | string | Entry | Phase 0.0, 0.1 | Raw arguments từ CLI |
| `$target` | string | Phase 0.1 | All | Path/URL của target |
| `$target_type` | enum | Phase 0.2 | All | `local-source` / `url` / `swagger-spec` |
| `$module_name` | string | Phase 0.1, 1.2 | All | Resolved module name (input or auto) |
| `$compare_path` | string\|null | Phase 0.1 | Phase 4 | Spec file path (nếu `--compare`) |
| `$scan_depth` | enum | Phase 0.1 | Phase 2 | `shallow` / `deep` |
| `$output_dir` | string\|null | Phase 0.1 | Phase 0.3, 0.3b | Custom output dir nếu `--output` |
| `$detected_tech_stack` | array | Phase 1.1 | Phase 2-3 | Tech stacks phát hiện |
| `$dotnet_pattern` | string | Phase 1.1 | Phase 2 | `ddd-cqrs` / `standard` (nếu .NET) |
| `$swagger_data` | object | Phase 1.1 | Phase 2 L2 | Parsed swagger spec (nếu có) |
| `$swagger_available` | boolean | Phase 1.1 | Phase 2 L2 | True nếu URL có swagger endpoint |
| `$scan_root` | path | Phase 1.3 | Phase 2 | Resolved scan directory (sub-module hoặc target) |
| `$SESSION_ID` | string | Phase 0.3 | All | Format: `{YYYY-MM-DD}-{scope-label}[-{N}]` (Protocol 18.2) |
| `$SESSION_DIR` | path | Phase 0.3 | All | Full path tới session dir |
| `$TARGET_FINGERPRINT` | sha256 | Phase 1.4 | Phase 0.0 (resume verify) | Composite hash (path+tech+depth+git_HEAD+git_dirty+manifests) |
| `$L1_RESULT`, `$L2_RESULT`, `$L3_RESULT`, `$L4_RESULT` | JSON | Phase 2 | Phase 3-5 | Layer outputs |
| `$crud_matrix` | JSON | Phase 3.1 | Phase 5 | CRUD ops per entity |
| `$business_rules` | array | Phase 3.2 | Phase 5 | Rule signals từ commands/validators |
| `$key_features` | array | Phase 3.3 | Phase 5 | High-level features (BA agent output) |
| `$completeness_estimate` | number | Phase 3.4 | Phase 5 | 0-100 based on layer signals |
| `$gap_matrix` | JSON | Phase 4.2 | Phase 5 | Spec vs found mapping |
| `$gap_metrics` | JSON | Phase 4.2 | Phase 5 | Total/found/partial/missing counts |
| `$RUN_SEQ` | int | Phase 0.5b | Phase 5.5c, FAIL handler | Sequence cho session-log entries |
| `$STALE_TARGET_WARNING` | boolean | Phase 0.0 (resume) | Phase 5 | True nếu user resume despite fingerprint mismatch |
| `$SCAN_PROFILE` | enum | Phase 0.1 | Phase 0.1c, 2 (L3), 3, 4, 5 | Sprint 7 — quick / standard / deep / exhaustive (default `standard`) |
| `$MAX_PAGES` | int | Phase 0.1c | Phase 2 L3 | Sprint 7 — URL crawl page cap (5/25/50/100 theo profile, hoặc `--max-pages` 1-200 override) |
| `$SINCE_REF` | string\|null | Phase 0.1 | Phase 0.2b, 1.4b, 1.5, 5 | Sprint 7 — git ref cho delta scan |
| `$DELTA_MODE` | bool | Phase 1.4b | Phase 1.5, 2.L1-L4, 5.5g | Sprint 7 — true nếu `--since` set + có ≥1 file thay đổi |
| `$TOTAL_CHANGED` | int | Phase 1.4b | Phase 5.2f | Sprint 7 — số file thay đổi (chỉ set khi `$DELTA_MODE == true`) |
| `$HEAD_REF` | string | Phase 1.4b | Phase 5.2f | Sprint 7 — git HEAD commit (cho target-map.delta_scan field) |
| `$URL_MAX_DEPTH` | int | Phase 2 L3 | Phase 2 L3 (CDG-07) | Sprint 7 — hardcoded = 2 (URL crawl: root + 1 level deep, không recursive) |

---

## Cross-Phase Data Flow

```
Phase 0 (setup)         → SESSION_DIR/, scan-status.json, checkpoint.json,
                            intermediate/, .lock, trace START
Phase 1 (detect)        → tech-stack.json (intermediate), TARGET_FINGERPRINT,
                            checkpoint.next_action=phase_2
Phase 2 L1 (structure)  → l1-structure.json (intermediate), L1_RESULT
Phase 2 L2 (api)        → l2-api.json (intermediate), L2_RESULT
Phase 2 L3 (ui)         → l3-ui.json (intermediate), L3_RESULT (CDG-07 cho URL crawl)
Phase 2 L4 (db)         → l4-db.json (intermediate), L4_RESULT
Phase 3 (synthesis)     → synthesis.json (intermediate), crud_matrix, business_rules,
                            key_features, completeness_estimate
Phase 4 (gap, optional) → gap.json (intermediate), gap_matrix, gap_metrics
Phase 5 (output)        → module-map.md, target-map.json, feature-inventory.md,
                            phase-summary.md, [gap-report.md], scan-status.json
                            (status=completed), trace COMPLETE, cleanup lock
```

---

## Helper Functions

> **Sprint 4 bash delegation:** các helpers này đã được extract thành bash scripts thực tế.
> Phase files giờ gọi bash trực tiếp thay vì pseudo-code inline. Pseudo-code dưới đây giữ lại
> làm REFERENCE để hiểu logic — KHÔNG copy/paste vào phase files mới.
>
> **Bash scripts (canonical implementation):**
> - `compute_fingerprint(target, tech_csv, depth)` → `.claude/scripts/scan-target-fingerprint.sh`
> - `atomic_write_json`, `validate_json`, `json_escape`, `slugify`, `normalize_path`,
>   `compute_rel_path`, `create_lock`, `check_lock`, `release_lock`, `resolve_session_id`
>   → `.claude/scripts/scan-target-common.sh`
>
> **Source pattern khi cần dùng helpers từ markdown procedure:**
> ```bash
> SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)/.claude/scripts"
> source "$SCRIPTS_DIR/scan-target-common.sh"
> # Giờ có thể gọi: atomic_write_json, json_escape, slugify, ...
> ```
>
> Helpers `save_checkpoint`, `trace_resume_event`, `elapsed` chưa migrated sang bash
> (Sprint 4 chỉ delegate enumeration scripts — phase 1-2). Có thể migrate sau ở Sprint 6.

### `compute_fingerprint(target, tech_csv, depth)` (GAP-12 — Q6 composite) — REFERENCE ONLY

> **Sprint 4:** Implementation moved to `.claude/scripts/scan-target-fingerprint.sh`.
> Pseudo-code dưới đây giữ làm reference, KHÔNG dùng inline — gọi bash thay thế:
> ```bash
> TARGET_FINGERPRINT=$(bash .claude/scripts/scan-target-fingerprint.sh "$target" "$tech_csv" "$scan_depth")
> ```

> Composite hash: path + tech_stack + depth + git_HEAD + git_dirty + manifests mtime.
> Output: hex sha256 string.

```bash
function compute_fingerprint() {
  local target="$1"
  local tech_csv="$2"
  local depth="$3"

  # 1) target absolute path (normalized — Unix forward slashes)
  local target_abs
  if [ -d "$target" ] || [ -f "$target" ]; then
    target_abs=$(cd "$(dirname "$target")" 2>/dev/null && pwd)/$(basename "$target")
  else
    # URL hoặc swagger-spec
    target_abs="$target"
  fi
  target_abs=$(echo "$target_abs" | tr '\\' '/')

  # 2) git HEAD (nếu trong git repo)
  local git_head="no-git"
  local git_dirty="clean"
  if [ -d "$target" ]; then
    if (cd "$target" && git rev-parse --git-dir >/dev/null 2>&1); then
      git_head=$(cd "$target" && git rev-parse HEAD 2>/dev/null || echo "no-head")
      # Q6 — git_dirty signal: nếu có uncommitted changes → fingerprint khác
      if [ -n "$(cd "$target" && git status --porcelain 2>/dev/null)" ]; then
        git_dirty="dirty"
      fi
    fi
  fi

  # 3) Manifest mtime (package.json, *.csproj, pom.xml, go.mod, requirements.txt, pyproject.toml)
  local manifest_mtimes=""
  if [ -d "$target" ]; then
    manifest_mtimes=$(find "$target" -maxdepth 3 \
      \( -name "package.json" -o -name "*.csproj" -o -name "pom.xml" \
         -o -name "go.mod" -o -name "requirements.txt" -o -name "pyproject.toml" \
         -o -name "composer.json" -o -name "Cargo.toml" \) \
      -not -path "*/node_modules/*" -not -path "*/vendor/*" -not -path "*/bin/*" \
      -exec stat -c "%Y %n" {} \; 2>/dev/null \
      | sort | sha256sum | cut -d' ' -f1)
  fi

  # 4) Compose composite input string
  local input="${target_abs}|${tech_csv}|${depth}|${git_head}|${git_dirty}|${manifest_mtimes}"

  # 5) Hash
  echo -n "$input" | sha256sum | cut -d' ' -f1
}
```

### `save_checkpoint(...)` (GAP-05 — atomic update)

> Atomic update của `$SESSION_DIR/checkpoint.json` + sync `phase_states`/`layer_states`
> sang `$SESSION_DIR/scan-status.json`. Idempotent — gọi nhiều lần an toàn.

```bash
function save_checkpoint() {
  # Args: --phase X --layer Y --status Z --next-phase A --next-step B \
  #       --intermediate-key K --intermediate-path P
  local phase="" layer="" status=""
  local next_phase="" next_step=""
  local intermediate_key="" intermediate_path=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --phase) phase="$2"; shift 2 ;;
      --layer) layer="$2"; shift 2 ;;
      --status) status="$2"; shift 2 ;;
      --next-phase) next_phase="$2"; shift 2 ;;
      --next-step) next_step="$2"; shift 2 ;;
      --intermediate-key) intermediate_key="$2"; shift 2 ;;
      --intermediate-path) intermediate_path="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local cp="$SESSION_DIR/checkpoint.json"
  local ss="$SESSION_DIR/scan-status.json"

  [ -s "$cp" ] || return 1   # checkpoint.json chưa init → skip

  # Atomic update checkpoint.json
  local tmp=$(mktemp)
  jq --arg ts "$ts" \
     --arg phase "$phase" \
     --arg layer "$layer" \
     --arg status "$status" \
     --arg np "$next_phase" \
     --arg ns "$next_step" \
     --arg ik "$intermediate_key" \
     --arg ip "$intermediate_path" \
     '.updated_at = $ts
      | (if $phase != "" and $status != "" then .phase_states[$phase] = $status else . end)
      | (if $layer != "" and $status != "" then .layer_states[$layer] = $status else . end)
      | (if $np != "" then .next_action.phase = $np else . end)
      | (if $ns != "" then .next_action.step = $ns else . end)
      | (if $ik != "" and $ip != "" then .intermediate_outputs[$ik] = $ip else . end)' \
     "$cp" > "$tmp" && mv "$tmp" "$cp"

  # Sync sang scan-status.json (chỉ phase_states + layer_states)
  if [ -s "$ss" ]; then
    tmp=$(mktemp)
    jq --arg phase "$phase" --arg layer "$layer" --arg status "$status" \
       '(if $phase != "" and $status != "" then .phases[$phase].status = $status else . end)
        | (if $layer != "" and $status != "" then .layer_states[$layer] = $status else . end)' \
       "$ss" > "$tmp" && mv "$tmp" "$ss"
  fi
}
```

### `trace_resume_event(session_id, target)` (GAP-03 + GAP-05)

> Append RESUME event vào session-log.json (Protocol 15). Best-effort.

```bash
function trace_resume_event() {
  local sid="$1"
  local tgt="$2"
  local TRACE_FILE=".mc-data/work/_trace/session-log.json"

  [ -f "$TRACE_FILE" ] || return 0

  local rs=$(jq '[.entries[] | select(.skill == "/wf-scan-target")] | length + 1' "$TRACE_FILE")

  local tmp=$(mktemp)
  jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     --arg sid "$sid" \
     --argjson rs "$rs" \
     --arg tgt "$tgt" \
     '.entries += [{
        timestamp: $ts,
        skill: "/wf-scan-target",
        event: "RESUME",
        run_sequence: $rs,
        phase: "Phase 0",
        session_id: $sid,
        details: {target: $tgt},
        files_created: 0,
        files_modified: 0,
        warnings: [],
        errors: [],
        decisions: []
      }]' "$TRACE_FILE" > "$tmp" && mv "$tmp" "$TRACE_FILE" 2>/dev/null || true
}
```

### `elapsed(start_iso, end_iso)` (helper cho --status display)

```bash
function elapsed() {
  local start_iso="$1"
  local end_iso="$2"
  # Best-effort: dùng date -d (Linux) hoặc fallback "—" nếu không parse được
  local start_s end_s
  start_s=$(date -d "$start_iso" +%s 2>/dev/null) || { echo "—"; return 0; }
  end_s=$(date -d "$end_iso" +%s 2>/dev/null) || { echo "—"; return 0; }
  local diff=$((end_s - start_s))
  if [ "$diff" -lt 60 ]; then
    echo "${diff}s"
  elif [ "$diff" -lt 3600 ]; then
    echo "$((diff / 60))m"
  else
    echo "$((diff / 3600))h $((diff % 3600 / 60))m"
  fi
}
```

---

## Agent Prompt Templates

### developer — Code Synthesis (Phase 3.1, Q3 — Sprint 4)

> Strong ở code semantics: CRUD pattern matching, validator extraction, entity relationships.
> KHÔNG dùng cho Vietnamese description — đó là job của BA agent.

```
Agent(developer):
  Input (compressed digest, không raw L1-L4):
    - L1 commands_sample (top 30 names)
    - L1 queries_sample (top 30 names)
    - L1 validators_sample (top 10 names)
    - L2 endpoints_sample (top 30 {method, path})
    - L4 entities (top 50 {name, key_fields_count, relationships_count})
    - module_name + tech_stack
  Task:
    1. Build CRUD matrix per entity (create/read/update/delete/list/search)
    2. Extract business rules từ validator names + read MAX 5 validator files
       (RuleFor/Must/When/NotEmpty patterns)
  Output: { crud_matrix: {...}, business_rules: [...] }
  Token budget: ~8K (5K input + 3K output)
```

### business-analyst — Compile Key Features tiếng Việt (Phase 3.2, Q3 — Sprint 4)

> Strong ở user-facing language: humanize technical names → tiếng Việt, aggregate features
> sang cấp cao. Apply Protocol 6.2 — nhận DIGEST từ developer 3.1, KHÔNG raw L1-L4.

```
Agent(business-analyst):
  Input (DIGEST từ 3.1 + L3 screens names):
    - crud_matrix_summary: "Module có {N} entities với {M} CRUD operations chính"
    - business_rules_summary: "{K} validation rules: <top 10>"
    - entities_names: $L4_RESULT.entities[].name (compact list)
    - ui_screens_names: $L3_RESULT.screens[].name (compact list, tối đa 30)
    - module_name: $module_name
  Task:
    Tổng hợp 10-20 key features cấp cao (tiếng Việt) cho non-specialist.
    KHÔNG liệt kê CRUD chi tiết — đã có ở 3.1.
  Output: key_features[] = ["- Quản lý hồ sơ khách hàng (...)", ...]
  Token budget: ~8K (3K input + 5K output)
```

---

## Error Handling Matrix

| Code | Trigger | Response |
|------|---------|----------|
| E001 | --target missing | Hiển thị usage, suggest examples, STOP |
| E002 | Local path not found | ERROR + suggest `ls` to verify, STOP |
| E003 | URL unreachable | WARNING "URL không accessible" + continue with available layers |
| E004 | Unknown tech stack | Run generic scan (file tree only), note in output |
| E005 | --compare path not found | WARNING + skip gap analysis, continue |
| E006 | Layer agent timeout | Use direct tool scan (no agent), log warning |
| E007 | Output write fail | Retry 3x, then ERROR + show path for manual debug |
| E008 | Target too large (>10k files) | WARN + limit to --module scope if provided, else top 500 files |
| E009 | Module not found in target | WARN + scan entire target instead |

---

## FAIL Event Handler (Protocol 15)

> Khi POST-GATE fail sau 3 iterations hoặc gặp lỗi không recoverable, ghi FAIL event vào trace log
> + tạo phase-summary.md với trạng thái "THẤT BẠI" (Protocol 14.1).

```bash
# Khi skill quyết định FAIL (sau khi exhaust retries hoặc gặp E001/E002):

TRACE_FILE=".mc-data/work/_trace/session-log.json"

# 1) Append FAIL event vào session-log.json
tmp=$(mktemp)
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg sid "$SESSION_ID" \
   --argjson rs "$RUN_SEQ" \
   --arg ph "$CURRENT_PHASE" \
   --arg err "$ERROR_MESSAGE" \
   '.entries += [{
      timestamp: $ts,
      skill: "/wf-scan-target",
      event: "FAIL",
      run_sequence: $rs,
      phase: $ph,
      session_id: $sid,
      files_created: 0,
      files_modified: 0,
      warnings: [],
      errors: [$err],
      decisions: []
    }]' "$TRACE_FILE" > "$tmp" && mv "$tmp" "$TRACE_FILE"

# 2) BẮT BUỘC tạo phase-summary.md với trạng thái THẤT BẠI (Protocol 14.1)
#    KHÔNG bỏ qua summary khi fail — user cần biết phase dừng ở đâu + lỗi gì
Template Usage Rule:
  READ .claude/skills/workflow/wf-scan-target/templates/phase-summary.md
  POPULATE:
    [STATUS]    → "THẤT BẠI"
    [STRENGTHS_AND_GAPS] → "Skill dừng ở $CURRENT_PHASE. Lỗi: $ERROR_MESSAGE"
    [RECOMMENDATIONS]    → suggest action (xem path nào không tồn tại, retry, ...)
  WRITE {SESSION_DIR}/phase-summary.md

# 3) Update scan-status.json: status = "failed", verdict = "fail"
# 4) Update checkpoint.json: phase_states[CURRENT_PHASE] = "failed", trigger.reason = "error"
# 5) GIỮ NGUYÊN .lock file để --resume detect và cleanup (kill -0 check sẽ pass nếu PID đã chết)
#    Sprint 6 sẽ thêm trap-based cleanup an toàn hơn.
```

---

## Template Usage Rule (CORE-031)

| Output File | Template Path |
|-------------|---------------|
| `module-map.md` | `templates/module-map.md` |
| `target-map.json` | `templates/target-map.json` |
| `feature-inventory.md` | `templates/feature-inventory.md` |
| `phase-summary.md` | `templates/phase-summary.md` |
| `gap-report.md` | `templates/gap-report.md` |
| `scan-status.json` | `templates/scan-status.json` |
| `checkpoint.json` | `templates/checkpoint.json` |
| `scans-index.jsonl` (1 entry) | `templates/scans-index-entry.json` (Sprint 6 — append-only JSONL) |

> **BẮT BUỘC:** mọi output file PHẢI được tạo bằng pattern: READ template → POPULATE values → WRITE output.
> KHÔNG viết từ đầu — luôn đọc template trước để đảm bảo đúng schema.
> Intermediate JSON files (`intermediate/*.json`) dùng inline schema (Sprint 4 sẽ chuẩn hoá).
> `scans-index.jsonl` / `history.jsonl` dùng `append_jsonl` helper (Sprint 6) — KHÔNG dùng atomic_write_json
> (vì pattern khác: 1 file nhiều entries, mỗi entry 1 dòng độc lập).

---

## Concurrency Model (Sprint 6)

> **Sprint 6 multi-dev safety.** Đảm bảo nhiều dev cùng chạy `/wf-scan-target` trên cùng máy
> hoặc khác máy không corrupt dữ liệu, sync github không conflict.

### 1. Atomic JSON Write (cho status JSONs)

Mọi write vào file JSON cấu trúc dùng pattern tmp-then-mv:

```bash
function atomic_write_json() {  # canonical: scan-target-common.sh
  local target="$1" content="$2"
  local tmp="${target}.tmp.$$"
  printf '%s' "$content" > "$tmp"
  jq empty "$tmp" || { rm "$tmp"; return 1; }   # validate JSON
  sync "$tmp" 2>/dev/null || true               # fsync best-effort
  mv "$tmp" "$target"                           # atomic on POSIX same fs
}
```

**Sprint 6 wrapper:** `safe_write_json` — pretty-print qua jq trước khi atomic_write_json.

**Files dùng atomic write:**
- `scan-status.json`, `checkpoint.json`, `target-map.json`
- `intermediate/*.json` (per-layer outputs)
- `_trace/session-log.json` (Protocol 15 — append qua atomic update vì là JSON array)
- Cache files `_shared/cache/{fingerprint}.json` (Sprint 6 — TTL 24h)

### 2. JSONL Append (cho multi-dev shared logs)

Files dùng JSONL format (newline-delimited JSON, mỗi entry 1 dòng):

```bash
function append_jsonl() {  # canonical: scan-target-common.sh
  local file="$1" entry="$2"
  jq empty <<<"$entry"     # validate
  echo "$entry" | jq -c '.' >> "$file"   # compact 1 dòng + atomic append
}
```

**Files dùng JSONL append:**
- `_shared/scans-index.jsonl` — full metadata mỗi scan completed
- `_shared/history.jsonl` — compact log (session_id + completed_at + status)

**Ưu điểm JSONL cho multi-dev:**
- **Atomic single write < 4KB:** POSIX guarantee — append 1 dòng < 4KB không bị xen kẽ
- **Git auto-merge:** mỗi entry 1 dòng độc lập → 2 dev append cùng file → git merge dễ dàng (line-based merge, không có conflict marker)
- **Forward-only:** không cần lock global vì mỗi append là idempotent + ordered by line
- **Reading:** dùng `jq -s '.'` cho array semantics khi cần aggregate

### 3. Lock File Lifecycle (Sprint 6 hardening)

Lock file format (JSON với metadata):

```json
{
  "pid": 12345,
  "host": "dev-machine-01",
  "user": "alice",
  "started_at": "2026-04-28T10:30:45Z",
  "skill": "wf-scan-target",
  "session_id": "2026-04-28-crm"
}
```

**Lifecycle:**
- **Tạo:** Phase 0.3c (`create_lock`) — sau khi resolve SESSION_DIR + check existing lock
- **Check:** `check_lock_status` (Sprint 6) trả về 1 trong 4 states:
  - `0 alive_local` → ERROR "đang chạy local", STOP
  - `1 no_lock` → tạo lock mới
  - `2 dead_local` → cleanup auto, tạo lock mới
  - `3 alive_cross_host` → ERROR "đang chạy trên máy khác", KHÔNG cleanup (kill -0 cross-host không khả thi)
- **Cleanup explicit:** Phase 5.5d (`release_lock`) — sau final checkpoint
- **Cleanup tự động:** `trap 'release_lock' EXIT` setup ở Phase 0.3c — đảm bảo cleanup khi normal exit / Ctrl+C / fail

### 4. Cache Strategy (Q2 = A — `.gitignore`)

Cache lưu kết quả scan đã tính theo fingerprint, TTL 24h, per-machine:

```
.mc-data/work/wf-scan-target/_shared/cache/{TARGET_FINGERPRINT}.json
```

**Lý do per-machine (KHÔNG sync git):**
- Fingerprint dependency on absolute path: component "target absolute path" KHÁC giữa các máy (`Z:\Working\...` vs `/home/user/...` vs `/Users/...`) → sync cache → fingerprint mismatch → cache không reusable cross-machine. Sync chỉ tăng repo size mà không có lợi.
- Stale cache từ máy khác có thể confuse user → debug nightmare.

**Cache hit:** Phase 1.4 (sau compute fingerprint) check cache → hit → skip Phase 2-4, jump Phase 5.
**Cache write:** Phase 5.5g — atomic write cache file (giống pattern atomic_write_json).
**Cache bypass:** `--no-cache` flag — fresh scan, vẫn write cache mới (override).

`.gitignore` entries:
```
.mc-data/work/wf-scan-target/_shared/cache/
.mc-data/work/wf-scan-target/sessions/*/.lock
```

KHÔNG ignore: `scans-index.jsonl`, `history.jsonl`, session folders → team chia sẻ lịch sử scan.

---

## Concurrency Test Scenarios (Sprint 6)

> Document các kịch bản chính để verify multi-dev safety. Sprint 8 evals sẽ thêm automated tests.

### Scenario 1 — 2 dev cùng scan cùng target (cùng máy)

**Setup:**
```
T+0  Dev A: /wf-scan-target --target=apps/backend/Eureka.Modules.CRM
T+5s Dev B: /wf-scan-target --target=apps/backend/Eureka.Modules.CRM
```

**Expected:**
- Dev A: SESSION_ID = `2026-04-28-crm` (lần đầu trong ngày)
- Dev B: SESSION_ID = `2026-04-28-crm-2` (suffix tự tăng — Phase 0.3 logic)
- 2 sessions chạy độc lập, lock files riêng biệt (cùng host, khác PID + khác SESSION_ID)
- 2 entries riêng biệt trong `scans-index.jsonl`

### Scenario 2 — 2 dev sync git sau scan (khác máy)

**Setup:**
```
Dev A (machine-01): scan → commit session folder + scans-index.jsonl → push
Dev B (machine-02): scan → commit → pull → merge
```

**Expected:**
- 2 session folders coexist (khác SESSION_ID hoặc cùng nếu khác ngày)
- `scans-index.jsonl` auto-merge: mỗi line độc lập, git merge line-based không tạo conflict marker
- `_shared/cache/` KHÔNG sync (`.gitignore`'d) — mỗi máy có cache riêng
- `*.lock` KHÔNG sync (`.gitignore`'d) — không kế thừa lock cross-machine

### Scenario 3 — Lock cleanup (PID dead vs cross-host)

**Setup A (PID dead local):**
```
Dev A: scan → kill -9 process giữa Phase 2
Dev A: /wf-scan-target --resume   # hoặc fresh scan cùng SESSION_DIR
```
→ `check_lock_status` returns `2 dead_local` → auto cleanup → tiếp tục resume / fresh

**Setup B (cross-host):**
```
Dev A (machine-01): /wf-scan-target → đang chạy
Dev B (machine-02): pull repo có session-folder + .lock của Dev A
Dev B: /wf-scan-target --resume --session=2026-04-28-crm
```
→ `check_lock_status` returns `3 alive_cross_host` → ERROR + suggest dùng session mới
→ KHÔNG cleanup (vì kill -0 không verify được PID alive trên machine khác)

### Scenario 4 — Delta scan + cache interaction (Sprint 7)

**Setup:**
```
Dev A: /wf-scan-target --target=apps/backend/Eureka.Modules.CRM
       → cache write _shared/cache/{fp}.json (full scan)

Dev A: /wf-scan-target --target=apps/backend/Eureka.Modules.CRM --since=HEAD~5
       → DELTA_MODE=true
       → Phase 1.5 skip cache lookup (delta = subset, cache = full → mismatch)
       → Phase 5.5g skip cache write (không thay thế full scan cache bằng delta)
       → target-map.json có delta_scan field {since_ref, head_ref, total_changed_files, scan_mode: "delta"}
```

**Expected:**
- Cache file _shared/cache/{fp}.json giữ nguyên (full scan từ run trước)
- Delta scan output session độc lập, KHÔNG hit/write cache
- `--since` KHÔNG thuộc fingerprint composite (Q6) → cùng target+git_HEAD vẫn cùng fingerprint
- Defensive: Skip cache nhằm đảm bảo cache luôn đại diện full scan; user muốn refresh full → bỏ `--since`

**Logic:**
- Phase 1.5: `if [[ DELTA_MODE == true ]]; then CACHE_HIT=false; skip lookup; fi`
- Phase 5.5g: skip write khi `DELTA_MODE=true` (cùng pattern với NO_CACHE / CACHE_HIT skip)
- Documented: delta scan = ephemeral output, không tham gia cache lifecycle

### Phase 2 Parallel Execution (v2.0.1 BUG-002 fix)

Trước v2.0.1, caller phải tự viết chain `bash script1 & bash script2 & wait` — pattern này
gây args parsing fail khi mix với `&&` chain (test phát hiện trong BUG-002).

**v2.0.1 fix:** dùng helper `run_phase2_parallel` từ `scan-target-common.sh`:

```bash
source .claude/scripts/scan-target-common.sh

# Tất cả 4 layers parallel (default)
run_phase2_parallel "$SESSION_DIR/intermediate/" \
                    "$SESSION_DIR/intermediate/tech-stack.json" \
                    "$scan_root"

# Hoặc subset (vd: shallow mode chỉ chạy L1)
run_phase2_parallel "$SESSION_DIR/intermediate/" \
                    "$SESSION_DIR/intermediate/tech-stack.json" \
                    "$scan_root" \
                    l1

# Hoặc skip L3 (backend-only target)
run_phase2_parallel "$SESSION_DIR/intermediate/" \
                    "$SESSION_DIR/intermediate/tech-stack.json" \
                    "$scan_root" \
                    l1 l2 l4
```

**Helper guarantees:**
- Mỗi script chạy trong subshell riêng (isolate args + env)
- Logs riêng `$output_dir/.{l1,l2,l3,l4}.log` cho debug
- `wait` cho tất cả PIDs trước khi return
- Exit code = số scripts failed (0 = all success)

**Lý do tách helper:** chain bash directly trong markdown procedure dễ bug do escape rules
khác giữa shells. Centralize logic vào 1 helper an toàn hơn.

## Cross-Platform Notes

| Tool / API | Compatibility |
|-----------|---------------|
| `mktemp ${target}.tmp.$$` | Cross-platform (Git Bash + WSL + Linux + macOS) — pattern dùng PID suffix tránh `mktemp -p` BSD/GNU divergence |
| `stat -c %Y` (GNU) / `stat -f %m` (BSD) | Helper `compute_fingerprint` đã handle (xem `scan-target-fingerprint.sh`) |
| `hostname` | POSIX, portable |
| `kill -0 <pid>` | POSIX, portable — chỉ check same-host |
| `mv` atomic | POSIX guarantee SAME filesystem; `.mc-data/` luôn cùng fs với working dir |
| `jq -c` compact output | Cần `jq` ≥ 1.5 (mọi platform supported) |
