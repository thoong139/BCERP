# Phase 1 — Init + CI PRE-GATE

> **Đầu vào:** CLI args (v2 + 7 cờ v3.0), `req-registry.json`, `phase3-architecture/*.md`, CI tools
> **Đầu ra:** `integrity-status.json`, `session-log.json`, `error-ledger.json`, `.lock` (acquired + heartbeat), `$CI_CONTEXT`, `Phase1-report.md`
> **Auto-fix budget:** 3 retries
> **Time estimate (standard profile):** 30-60s
> **Required:** ✅ (Always — entry point trừ khi `--scenarios-only` skip Phase 1-7)
> **v3.0 NEW:** Parse 7 cờ v3 (`--exec-scenarios`, `--scenarios-only`, `--show-browser`, `--mobile`, `--strict-evidence`, `--no-prompt`, `--auto-fix-source`) + Step 1.14b CDG E195b "Subset E2E Execute Confirm" + Step 1.21 `--scenarios-only` route bypass

---

## §A Header

Phase 1 là entry point của pipeline `wf-cmi`. Validate arguments, detect CI tools, init session, acquire lock, set up state cho 7 phases tiếp theo.

**Sub-handlers nội tại:**
- `--status` → route sang `procedures/resume-status.md` §--status (early exit)
- `--resume` → route sang `procedures/resume-status.md` §--resume (load existing session)
- Fresh run → execute Phase 1 Steps 1.1-1.20 dưới đây

**Shared sections cần load:**
- `_shared.md §1` (State Variables Glossary)
- `_shared.md §12` (CI Detection Pattern)
- `_shared.md §13` (Session Lock & Heartbeat)
- `_shared.md §16` (Session Isolation Protocol)
- `_shared.md §17` (Author Info)

---

## §B PRE-GATE (T1→T4 Forensic)

> **Mục đích:** Verify prerequisites NGAY TRƯỚC KHI bắt đầu Phase 1 — đảm bảo skill có đủ input để chạy.

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | `test -f .mc-data/docs/_meta/req-registry.json` | bash | **E010** — registry missing → ESCALATE `/wf-brainstorm` hoặc `/existing-project` |
| T2 | `jq -e '.requirements' registry.json` không null | jq | **E011** — registry schema invalid → ESCALATE user fix manual |
| T3 | `jq -e '.requirements \| length > 0'` | jq | **E012** — registry empty → ESCALATE |
| T4 | `test -d .mc-data/docs/phase3-architecture` + `ls *.md \| wc -l > 0` | bash | **E013** — architecture docs missing → ESCALATE `/wf-design` trước |
| T1b | CI tools detected (GitNexus + Serena, OPTIONAL) | `ci-detect.sh` | **E100** WARN — fallback Grep (non-blocking) |
| T2b | CI index freshness check | `ci-freshness-check.sh` | **E100/E101** WARN — light/strong/severe stale (non-blocking) |

**PRE-GATE pseudocode:**

```bash
# T1: Registry exists
[ -f ".mc-data/docs/_meta/req-registry.json" ] || die "E010" "Registry missing"

# T2: Registry schema valid
jq -e '.requirements' ".mc-data/docs/_meta/req-registry.json" >/dev/null \
  || die "E011" "Registry schema invalid"

# T3: Registry non-empty
[ "$(jq -e '.requirements | length' .mc-data/docs/_meta/req-registry.json)" -gt 0 ] \
  || die "E012" "Registry empty (0 requirements)"

# T4: Architecture docs exist
arch_count=$(find .mc-data/docs/phase3-architecture -name '*.md' 2>/dev/null | wc -l)
[ "$arch_count" -gt 0 ] || die "E013" "Architecture docs missing — run /wf-design first"

# T1b/T2b: CI optional — non-blocking
log_phase_start
```

---

## §C Steps (Execution Detail)

### Step 1.1 — Parse + validate CLI arguments

| # | Action | Tool | Output |
|---|--------|------|--------|
| 1.1.1 | Parse args v2 theo `_contract.json §inputs` | bash | `$SCOPE_TYPE`, `$SCOPE_NAME`, `$PROFILE`, `$DIMS_ARG`, `$SINCE_REF`, `$AUTO_SUGGEST`, `$DRY_RUN`, `$CI_MODE`, `$NO_CACHE`, `$SHOW_GRAPHS` |
| **1.1.1b (v3 NEW)** | **Parse 7 cờ v3.0** | bash | `$EXEC_SCENARIOS` (boolean, default false), `$SCENARIOS_ONLY` (boolean), `$SHOW_BROWSER` (boolean → headless flag inverse), `$MOBILE` (boolean → viewport choice), `$STRICT_EVIDENCE` (boolean), `$NO_PROMPT` (boolean → CI mode AskUserQuestion bypass), `$AUTO_FIX_SOURCE` (boolean → Phase 10 source-fix authorize) |
| 1.1.2 | Validate `--scope` regex `^(system\|module=[a-z0-9-]+\|feat=FEAT-[A-Z]+-[A-Z0-9-]+)$` | bash | PASS / E010 |
| 1.1.3 | Validate `--profile` ∈ {quick, standard, deep, exhaustive} | bash | PASS / E010 |
| 1.1.4 | Validate `--dims` (nếu set): mỗi item match `CD[1-9]\|CD[1-4][0-9]` | bash | PASS / E010 |
| 1.1.5 | Validate `--since` (nếu set): `git rev-parse --verify` | git | PASS / E014 |
| 1.1.6 | Validate args conflict v2: `--auto-suggest` + `--ci` mutually exclusive | bash | PASS / E012 |
| 1.1.7 | Validate args conflict v2: `--ci` yêu cầu env `$CI=true` hoặc `$GITHUB_ACTIONS=true` | bash | WARN E100 nếu không có (downgrade local mode) |
| **1.1.7b (v3 NEW)** | **Validate v3 mutual-exclusive combinations** (xem chi tiết bên dưới) | bash | PASS / E016b |
| 1.1.8 | Handle `--status` / `--resume` / `--scenarios-only` flag dispatch | router | Route → `resume-status.md` (--status/--resume) hoặc Step 1.21 (--scenarios-only) |

**Conflict resolution rules v2:**
- `--scope=system + --profile=quick` → CDG E091 Scope×Profile Auto-Upgrade (Step 1.14)
- `--resume + --scope=X` → Resume override (`--scope` từ session cũ thắng), WARN E016
- `--dims` override profile activation matrix (vd profile=quick chỉ kích CD1,2,3,4,7 nhưng `--dims=CD1,CD8` → chỉ CD1,CD8)

**v3 mutual-exclusive combinations (Step 1.1.7b):**

| Combination | Quy tắc | Action |
|-------------|---------|--------|
| `--scenarios-only` + `--resume` | Mutual exclusive — cả hai đều resume session cũ qua khác cơ chế | **E016b STOP** — user chọn 1 |
| `--scenarios-only` (no `--session-id`) | Cần explicit session ID để định danh session cũ | **E016b STOP** — yêu cầu `--session-id=<ID>` |
| `--scenarios-only` (session DONE) | Session đã `pipeline_status=DONE` — re-execute Phase 9-10 OK | **PASS** — proceed Step 1.21 |
| `--strict-evidence` (no `--exec-scenarios`) | `--strict-evidence` chỉ có ý nghĩa với Phase 9 | **WARN E101** — ignore flag, continue |
| `--show-browser` / `--mobile` (no `--exec-scenarios`) | Chỉ áp dụng cho Phase 9 Playwright | **WARN E101** — ignore flag, continue |
| `--no-prompt` + `--auto-fix-source` | CI mode auto-confirms source-fix (skip CDG E195) | **WARN E101** — explicit log "CDG E195 auto-confirmed bởi --no-prompt" |
| `--auto-fix-source` (no `--exec-scenarios`) | Phase 10 chỉ trigger khi Phase 9 có FAIL | **WARN E101** — ignore flag (sẽ không có Phase 10 trigger) |
| `--ci` + `--exec-scenarios` (no `--no-prompt`) | CI mode cần bypass AskUserQuestion | **WARN E100** — auto-set `--no-prompt=true` |

**Validation pseudocode (Step 1.1.7b):**

```bash
validate_v3_args() {
  # --scenarios-only requires --session-id
  if [ "$SCENARIOS_ONLY" = "true" ]; then
    [ -n "$SESSION_ID_FLAG" ] || die "E016b" "--scenarios-only requires --session-id=<ID>"
    [ "$RESUME_FLAG" = "true" ] && die "E016b" "--scenarios-only và --resume mutually exclusive — chọn 1"
  fi

  # --strict-evidence requires --exec-scenarios
  if [ "$STRICT_EVIDENCE" = "true" ] && [ "$EXEC_SCENARIOS" != "true" ]; then
    log_warn "E101" "--strict-evidence chỉ có ý nghĩa với --exec-scenarios — ignore flag"
    STRICT_EVIDENCE="false"
  fi

  # --show-browser / --mobile only with --exec-scenarios
  if [ "$EXEC_SCENARIOS" != "true" ]; then
    if [ "$SHOW_BROWSER" = "true" ] || [ "$MOBILE" = "true" ]; then
      log_warn "E101" "--show-browser/--mobile chỉ áp dụng Phase 9 — ignore flags"
      SHOW_BROWSER="false"
      MOBILE="false"
    fi
  fi

  # --no-prompt + --auto-fix-source: CI auto-confirm
  if [ "$NO_PROMPT" = "true" ] && [ "$AUTO_FIX_SOURCE" = "true" ]; then
    log_warn "E101" "CDG E195 auto-confirmed bởi --no-prompt (CI mode source-fix)"
  fi

  # --auto-fix-source without --exec-scenarios is no-op (Phase 10 not triggered)
  if [ "$AUTO_FIX_SOURCE" = "true" ] && [ "$EXEC_SCENARIOS" != "true" ]; then
    log_warn "E101" "--auto-fix-source no-op khi không có --exec-scenarios"
  fi

  # --ci + --exec-scenarios → auto-set --no-prompt
  if [ "$CI_MODE" = "true" ] && [ "$EXEC_SCENARIOS" = "true" ] && [ "$NO_PROMPT" != "true" ]; then
    log_warn "E100" "CI mode + --exec-scenarios — auto-set --no-prompt=true"
    NO_PROMPT="true"
  fi

  export EXEC_SCENARIOS SCENARIOS_ONLY SHOW_BROWSER MOBILE STRICT_EVIDENCE NO_PROMPT AUTO_FIX_SOURCE
}

validate_v3_args
```

### Step 1.2 — Get author info (multi-user support)

```bash
get_git_author  # Set $AUTHOR_EMAIL, $AUTHOR_NAME
```

Reference: `_shared.md §17`.

### Step 1.3 — Generate SESSION_ID

```bash
SCOPE_SLUG="$SCOPE_TYPE"
[ "$SCOPE_TYPE" != "system" ] && SCOPE_SLUG="${SCOPE_TYPE}-$(echo "$SCOPE_NAME" | tr '[:upper:]' '[:lower:]' | tr '_/' '-')"
NAME_SLUG=$(echo "${SCOPE_NAME:-auto}" | tr '[:upper:]' '[:lower:]' | tr '_/' '-')
DATE_PREFIX=$(date +%Y-%m-%d)

# Auto-increment NN
existing_count=$(ls -1 ".mc-data/work/wf-cmi/sessions/${DATE_PREFIX}-${SCOPE_SLUG}-${NAME_SLUG}-"* 2>/dev/null | wc -l)
NN=$(printf "%02d" $((existing_count + 1)))

SESSION_ID="${DATE_PREFIX}-${SCOPE_SLUG}-${NAME_SLUG}-${NN}"
SESSION_DIR=".mc-data/work/wf-cmi/sessions/${SESSION_ID}"
export SESSION_ID SESSION_DIR
```

**Validation:** `--session-id=<ID>` (nếu user explicit set, dùng cho `--resume` ambiguous resolution) phải match regex `^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9-]+-[0-9]{2}$` (E015).

### Step 1.4 — Create session directory tree

```bash
mkdir -p \
  "$SESSION_DIR/phase1-init" \
  "$SESSION_DIR/phase2-discovery" \
  "$SESSION_DIR/phase3-invariants" \
  "$SESSION_DIR/phase4-coverage/lanes" \
  "$SESSION_DIR/phase5-aggregate" \
  "$SESSION_DIR/phase6-regression" \
  "$SESSION_DIR/phase7-gap-cdg" \
  "$SESSION_DIR/phase8-report" \
  ".mc-data/work/wf-cmi/_index" \
  ".mc-data/work/wf-cmi/_locks" \
  ".mc-data/work/_trace"

[ ! -d "$SESSION_DIR" ] && die "E017" "Session dir creation fail"
```

### Step 1.5 — Acquire session lock + spawn heartbeat daemon

> Reference: `_shared.md §13`. Atomic mkdir-guard + PID liveness check.

```bash
acquire_lock "$SESSION_DIR" || die "E018" "Peer session active — check --status"
start_heartbeat_daemon "$SESSION_DIR"
trap cleanup EXIT INT TERM
```

**Error handling:**
- E018 retry x3 với 5s delay nếu lock thuộc PID dead (auto-takeover)
- E019 nếu heartbeat daemon spawn fail → retry x1 → ESCALATE

### Step 1.6 — Append session index entry

```bash
INDEX=".mc-data/work/wf-cmi/_index/sessions.jsonl"
jq -nc --arg sid "$SESSION_ID" --arg st "$SCOPE_TYPE" --arg sn "$SCOPE_NAME" \
       --arg pr "$PROFILE" --arg ts "$(date -Iseconds)" \
       --arg ae "$AUTHOR_EMAIL" --arg an "$AUTHOR_NAME" --arg ho "$(hostname)" \
   '{session_id: $sid, scope: {type: $st, name: $sn}, profile: $pr,
     started_at: $ts, status: "active",
     author: {email: $ae, name: $an}, host: $ho}' >> "$INDEX"
```

### Step 1.7 — CI PRE-GATE Na (Load CI Capabilities)

> Reference: `_shared.md §12`. Auto-detect, không hỏi user.

```bash
bash .claude/scripts/ci-detect.sh
CI_META=".mc-data/work/_meta/code-intelligence.json"

if [ -f "$CI_META" ]; then
  GITNEXUS_AVAILABLE=$(jq -r '.gitnexus.available // false' "$CI_META")
  SERENA_AVAILABLE=$(jq -r '.serena.available // false' "$CI_META")
else
  GITNEXUS_AVAILABLE="false"
  SERENA_AVAILABLE="false"
  log_warn "E014" "CI detection skipped (graceful degrade)"
fi
export GITNEXUS_AVAILABLE SERENA_AVAILABLE
```

**Fallback:**
- Lock held → fallback Grep/Glob, WARN E100
- Both unavailable + project non-git → set freshness="severe", continue with full Grep fallback (E015)

### Step 1.8 — CI PRE-GATE Nb (Index Freshness Check)

```bash
bash .claude/scripts/ci-freshness-check.sh
INDEX_FRESHNESS=$(jq -r '.freshness // "ok"' "$CI_META" 2>/dev/null || echo "ok")
export INDEX_FRESHNESS

case "$INDEX_FRESHNESS" in
  ok)     ;;  # OK
  light)  log_warn "E101" "CI index light stale (6-20 commits)" ;;
  strong) log_warn "E101" "CI index strong stale (>20 commits) — suggest 'gitnexus analyze'" ;;
  severe) log_warn "E016" "CI index severely stale — fallback Grep"; GITNEXUS_AVAILABLE=false ;;
esac
```

### Step 1.9 — CI PRE-GATE Nc (Agent Context Injection)

```bash
if [ "$GITNEXUS_AVAILABLE" = "true" ] || [ "$SERENA_AVAILABLE" = "true" ]; then
  CI_CONTEXT=$(bash .claude/scripts/ci-inject-context.sh)
else
  CI_CONTEXT="GITNEXUS_AVAILABLE=false, SERENA_AVAILABLE=false, INDEX_FRESHNESS=$INDEX_FRESHNESS, FALLBACK_TOOL=Grep"
fi
export CI_CONTEXT
```

### Step 1.10 — Resolve profile → dims_active

> Profile activation matrix theo `docs/04-skill-design/wf-cmi/05-execution-profiles.md`.

| Profile | Lanes activated | Threshold |
|---------|-----------------|-----------|
| `quick` | CD1, CD2, CD3, CD4, CD7 | ≥60% per dim |
| `standard` (default) | CD1, CD2, CD3, CD4, CD5, CD6, CD7, CD9 | ≥80% per dim |
| `deep` | CD1-CD10 (all 10) | ≥95% per dim |
| `exhaustive` | CD1-CD10 + LLM enhance per signal | 100% per dim |

```bash
case "$PROFILE" in
  quick)      DIMS_ACTIVE='["CD1","CD2","CD3","CD4","CD7"]' ;;
  standard)   DIMS_ACTIVE='["CD1","CD2","CD3","CD4","CD5","CD6","CD7","CD9"]' ;;
  deep)       DIMS_ACTIVE='["CD1","CD2","CD3","CD4","CD5","CD6","CD7","CD8","CD9","CD10"]' ;;
  exhaustive) DIMS_ACTIVE='["CD1","CD2","CD3","CD4","CD5","CD6","CD7","CD8","CD9","CD10"]' ;;
esac

# Override với --dims (intersection với profile activation)
if [ -n "$DIMS_ARG" ]; then
  DIMS_OVERRIDE=$(echo "$DIMS_ARG" | tr ',' '\n' | jq -R . | jq -s .)
  DIMS_ACTIVE=$(echo "$DIMS_ACTIVE $DIMS_OVERRIDE" | jq -s '.[0] - (.[0] - .[1]) | unique')
fi
export DIMS_ACTIVE
```

**Validation:** Nếu `--dims` chứa CD nằm ngoài profile activation → INFO log "lane CD{X} skipped (not in profile)".

### Step 1.11 — Validate Phase 3 architecture docs (T4 detail)

```bash
ARCH_FILES=$(find .mc-data/docs/phase3-architecture -name '*.md' -type f 2>/dev/null)
[ -z "$ARCH_FILES" ] && die "E013" "Architecture docs missing in phase3-architecture/"

# Check non-empty (size > 200 bytes)
NON_EMPTY=$(echo "$ARCH_FILES" | xargs -I{} sh -c 'test "$(wc -c < "{}")" -gt 200 && echo "{}"' | wc -l)
[ "$NON_EMPTY" -eq 0 ] && die "E013" "All architecture docs <200 bytes — re-run /wf-design"
```

### Step 1.12 — Detect consume artifacts (opt-in flags)

```bash
# --from-fix-bugs: Read fix-impact.json từ last successful wf-fix-bugs session
if [ "$FROM_FIX_BUGS" = "true" ]; then
  FIX_BUGS_IMPACT=$(find .mc-data/work/wf-fix-bugs/sessions -name 'fix-impact.json' -type f 2>/dev/null \
                    | xargs ls -t | head -1)
  [ -z "$FIX_BUGS_IMPACT" ] && log_warn "E100" "--from-fix-bugs: no fix-impact.json found, ignore"
  export FIX_BUGS_IMPACT
fi

# --from-verify-sync: similar
# --from-impl: similar (per FEAT)
```

### Step 1.13 — Detect LEGACY_MODE (CORE-021)

```bash
LEGACY_CONTEXT=".mc-data/work/legacy-scan/project-context.md"
if [ -f "$LEGACY_CONTEXT" ] && [ "$(wc -c < "$LEGACY_CONTEXT")" -gt 500 ]; then
  LEGACY_MODE="true"
  log_info "LEGACY_MODE detected (project-context.md > 500 bytes)"
else
  LEGACY_MODE="false"
fi
export LEGACY_MODE
```

### Step 1.14 — Critical Decision Gates (CDG buffer)

> Reference: `_shared.md §18`. Buffer-then-flush pattern — CDG decisions stored vào variables, flush sau Step 1.15.

#### CDG E091 — Scope × Profile Auto-Upgrade

**Trigger:** `--scope=system` + `--profile=quick`.

```
AskUserQuestion:
  "Scope=system với profile=quick có thể miss coverage (chỉ ≥60% threshold).
   Upgrade lên standard (≥80%, +CD5/CD6/CD9 lanes) hoặc giữ quick?"
  Options:
    1. Upgrade → standard (Recommended)
    2. Continue with quick (hotfix scenario)
    3. Cancel

  Default: Continue with quick (non-blocking)
```

Save: `CDG_E091_DECISION="upgrade|continue|cancel"`.

#### CDG E090b — Parallel-Session Conflict Detection

**Trigger:** Peer session đang chạy cùng scope hoặc cùng cache key (check sessions.jsonl status="active").

```bash
PEER_SESSIONS=$(jq -c --arg sc "$SCOPE_TYPE" --arg sn "$SCOPE_NAME" \
   'select(.status == "active" and .scope.type == $sc and .scope.name == $sn)' \
   .mc-data/work/wf-cmi/_index/sessions.jsonl 2>/dev/null)
```

```
IF $PEER_SESSIONS not empty:
  AskUserQuestion:
    "Phiên Y đang chạy (cùng scope=$SCOPE_TYPE:$SCOPE_NAME, owner=peer_author).
     Tiếp tục → R/W lock có thể block read-heavy phases vài giây.
     Options:
       1. Wait (Recommended for collab)
       2. Cancel
       3. Force release peer lock (RISKY)
     Default: Wait"

  Bypass cho CI: env MCV3_CMI_ALLOW_PARALLEL=1
```

Save: `CDG_E090B_DECISION="wait|cancel|force"`.

#### CDG E195b (v3.0) — Subset E2E Execute Confirm

**Trigger:** `--exec-scenarios` + `--profile` ∈ {quick, standard} + NOT `--no-prompt` + NOT `--scenarios-only`.

**Bối cảnh:** CD41 mặc định chỉ kích hoạt ở profile=deep/exhaustive. Khi user pass `--exec-scenarios` với profile=quick|standard, có 3 phương án:

```
AskUserQuestion:
  "Bạn đang chạy --exec-scenarios với profile=$PROFILE.
   Profile này mặc định KHÔNG kích CD41 (E2E Scenario Synthesizer).
   Để có scenarios chạy Playwright, cần override:

   1. Execute all — Force CD41 sinh full scenarios (MUST+HIGH violations, deep-style)
      → Effort: +5-15 phút synth + Phase 9 ~10-40 phút execute
   2. Execute MUST-only (Recommended cho quick) — Force CD41 sinh subset (chỉ MUST violations)
      → Effort: +2-5 phút synth + Phase 9 ~5-15 phút execute
   3. Cancel — Skip Phase 9-10, vẫn xuất integrity-report v3 (e2e_execution_summary=null)

   Default sau timeout: Cancel"

  Bypass cho CI/automation: --no-prompt → silent default = "Execute MUST-only" (option 2, balanced safety)
```

**Logic:**

```bash
# Pre-check trigger conditions
if [ "$EXEC_SCENARIOS" = "true" ] \
   && { [ "$PROFILE" = "quick" ] || [ "$PROFILE" = "standard" ]; } \
   && [ "$NO_PROMPT" != "true" ] \
   && [ "$SCENARIOS_ONLY" != "true" ]; then

  # AskUserQuestion (3 options)
  # Capture decision into $CDG_E195B_DECISION
  # Valid values: "execute_all" | "execute_must_only" | "cancel"

  case "$CDG_E195B_DECISION" in
    execute_all)
      CD41_FORCE_ACTIVATE="true"
      CD41_FILTER_SEVERITY="MUST,HIGH"
      log_info "CDG E195b: User chọn Execute all — CD41 force-activate MUST+HIGH"
      ;;
    execute_must_only)
      CD41_FORCE_ACTIVATE="true"
      CD41_FILTER_SEVERITY="MUST"
      log_info "CDG E195b: User chọn Execute MUST-only — CD41 force-activate MUST"
      ;;
    cancel)
      EXEC_SCENARIOS="false"  # Override flag → SKIP Phase 9-10
      log_info "CDG E195b: User chọn Cancel — Phase 9-10 SKIP, vẫn xuất Phase 8 report v3 với e2e_execution_summary=null"
      ;;
  esac

elif [ "$EXEC_SCENARIOS" = "true" ] \
     && { [ "$PROFILE" = "quick" ] || [ "$PROFILE" = "standard" ]; } \
     && [ "$NO_PROMPT" = "true" ]; then
  # CI mode silent default
  CDG_E195B_DECISION="execute_must_only"
  CD41_FORCE_ACTIVATE="true"
  CD41_FILTER_SEVERITY="MUST"
  log_warn "E195b" "CI mode (--no-prompt): silent default = Execute MUST-only"
fi

export CDG_E195B_DECISION CD41_FORCE_ACTIVATE CD41_FILTER_SEVERITY
```

Save: `CDG_E195B_DECISION="execute_all|execute_must_only|cancel"`.

**Phase 4 Wave 3 dispatch sẽ đọc `$CD41_FORCE_ACTIVATE` để override profile activation matrix** (xem `procedures/phase4-coverage-dispatch.md §Wave 3 logic`).

**Phase 9 PRE-GATE T1 sẽ đọc `$CDG_E195B_DECISION` qua integrity-status.json** để biết execute_all/execute_must_only.

### Step 1.15 — Build integrity-status.json từ template (CORE-031)

```bash
# READ template
TEMPLATE=".claude/skills/workflow/wf-cmi/templates/integrity-status.json"
[ -f "$TEMPLATE" ] || die "E081" "Template integrity-status.json missing"

# POPULATE + strip _template_notes
TARGET="$SESSION_DIR/integrity-status.json"
jq 'walk(if type == "object" then with_entries(select(.key | startswith("_") | not)) else . end)' \
   "$TEMPLATE" > "$TARGET.tmp.$$"

# Set initial values (v3: include 7 cờ + CDG E195b decision cho Phase 9 PRE-GATE consume)
jq --arg sid "$SESSION_ID" --arg pr "$PROFILE" --arg st "$SCOPE_TYPE" --arg sn "$SCOPE_NAME" \
   --argjson dims "$DIMS_ACTIVE" --arg ts "$(date -Iseconds)" \
   --arg ae "$AUTHOR_EMAIL" --arg an "$AUTHOR_NAME" \
   --argjson gna "$GITNEXUS_AVAILABLE" --argjson sea "$SERENA_AVAILABLE" \
   --arg fr "$INDEX_FRESHNESS" \
   --argjson exec "$EXEC_SCENARIOS" --argjson so "$SCENARIOS_ONLY" \
   --argjson sb "$SHOW_BROWSER" --argjson mb "$MOBILE" \
   --argjson se "$STRICT_EVIDENCE" --argjson np "$NO_PROMPT" \
   --argjson afs "$AUTO_FIX_SOURCE" \
   --arg e195b "${CDG_E195B_DECISION:-not_triggered}" \
   --argjson cd41fa "${CD41_FORCE_ACTIVATE:-false}" \
   --arg cd41fs "${CD41_FILTER_SEVERITY:-}" \
   '. + {
      session_id: $sid,
      scope: {type: $st, name: $sn},
      profile: $pr,
      dims_active: $dims,
      current_phase: 1,
      phases_completed: [],
      next_action: "phase1-init",
      context_budget_used_pct: 0,
      lane_status: {},
      ci_context: {
        gitnexus_available: $gna,
        serena_available: $sea,
        index_freshness: $fr
      },
      checkpoint_at: $ts,
      lock_owner_pid: '$$',
      lock_heartbeat_at: $ts,
      author: {git_user_email: $ae, git_user_name: $an},
      pipeline_status: "in_progress",
      v3_flags: {
        exec_scenarios: $exec,
        scenarios_only: $so,
        show_browser: $sb,
        mobile: $mb,
        strict_evidence: $se,
        no_prompt: $np,
        auto_fix_source: $afs
      },
      v3_cdg: {
        e195b_decision: $e195b,
        cd41_force_activate: $cd41fa,
        cd41_filter_severity: $cd41fs
      }
    }' "$TARGET.tmp.$$" > "$TARGET"

# Validate JSON
jq '.' "$TARGET" >/dev/null || die "E081" "integrity-status.json invalid"
rm -f "$TARGET.tmp.$$"
```

**v3 schema bump note:** Các fields `v3_flags{}` + `v3_cdg{}` là **OPTIONAL v3-only**. v1/v2 consumer ignore gracefully (no schema break). Phase 4 Wave 3 + Phase 9 + Phase 10 đọc qua `jq -r '.v3_flags.exec_scenarios // false'` (graceful default cho v2 session resume).

### Step 1.16 — Init session-log.json + error-ledger.json

```bash
# session-log.json from template _common/session-log.json
TPL_LOG=".claude/skills/workflow/wf-cmi/templates/_common/session-log.json"
jq 'walk(if type == "object" then with_entries(select(.key | startswith("_") | not)) else . end)' \
   "$TPL_LOG" > "$SESSION_DIR/session-log.json.tmp.$$"
jq --arg sid "$SESSION_ID" '.skill = "wf-cmi" | .session_id = $sid | .events = []' \
   "$SESSION_DIR/session-log.json.tmp.$$" > "$SESSION_DIR/session-log.json"
rm -f "$SESSION_DIR/session-log.json.tmp.$$"

# error-ledger.json from template _common/error-ledger.json
TPL_ERR=".claude/skills/workflow/wf-cmi/templates/_common/error-ledger.json"
jq 'walk(if type == "object" then with_entries(select(.key | startswith("_") | not)) else . end)' \
   "$TPL_ERR" > "$SESSION_DIR/error-ledger.json.tmp.$$"
jq --arg sid "$SESSION_ID" '.skill = "wf-cmi" | .session_id = $sid | .errors = []' \
   "$SESSION_DIR/error-ledger.json.tmp.$$" > "$SESSION_DIR/error-ledger.json"
rm -f "$SESSION_DIR/error-ledger.json.tmp.$$"
```

### Step 1.17 — Flush CDG tokens (buffered từ Step 1.14)

```bash
[ -n "$CDG_E091_DECISION" ]   && append_cdg_token "phase1-init" "E091-Scope-Profile-Upgrade" "$CDG_E091_DECISION"
[ -n "$CDG_E090B_DECISION" ]  && append_cdg_token "phase1-init" "E090b-Parallel-Session" "$CDG_E090B_DECISION"
# v3.0 NEW CDG token
[ -n "$CDG_E195B_DECISION" ] && [ "$CDG_E195B_DECISION" != "not_triggered" ] \
  && append_cdg_token "phase1-init" "E195b-Subset-E2E-Execute-Confirm" "$CDG_E195B_DECISION"
```

### Step 1.18 — TodoWrite init (Protocol 9)

> Reference: `_shared.md §11`. Init TodoWrite với 8 phase tasks.

Sử dụng `TodoWrite` tool với 8 entries (xem `_shared.md §11` template). Phase 1 mark `in_progress`, Phase 2-8 `pending`.

### Step 1.19 — Execution Trace START (CORE-026)

```bash
log_phase_event "phase1" "START" "{\"args\":\"$ARGS_RAW\"}"
```

### Step 1.20 — Write Phase1-report.md từ template (CORE-028 + CORE-031)

```bash
TPL_REPORT=".claude/skills/workflow/wf-cmi/templates/Phase1-report.md"
REPORT="$SESSION_DIR/phase1-init/Phase1-report.md"

# READ template + POPULATE placeholders
sed -e "s|\[SESSION_ID\]|$SESSION_ID|g" \
    -e "s|\[PROFILE\]|$PROFILE|g" \
    -e "s|\[SCOPE_TYPE\]|$SCOPE_TYPE|g" \
    -e "s|\[SCOPE_NAME\]|${SCOPE_NAME:-—}|g" \
    -e "s|\[DIMS_ACTIVE\]|$(echo "$DIMS_ACTIVE" | jq -r 'join(",")')|g" \
    -e "s|\[CI_GITNEXUS\]|$GITNEXUS_AVAILABLE|g" \
    -e "s|\[CI_SERENA\]|$SERENA_AVAILABLE|g" \
    -e "s|\[INDEX_FRESHNESS\]|$INDEX_FRESHNESS|g" \
    -e "s|\[AUTHOR_NAME\]|$AUTHOR_NAME|g" \
    -e "s|\[TIMESTAMP\]|$(date -Iseconds)|g" \
    -e "s|\[STATUS\]|PASS|g" \
    "$TPL_REPORT" > "$REPORT"

# Verify ≤15 dòng
[ "$(wc -l < "$REPORT")" -le 15 ] || log_warn "E087" "Phase1-report.md >15 dòng"
```

### Step 1.21 (v3.0 NEW) — `--scenarios-only` route bypass

> **Mục đích:** Khi user pass `--scenarios-only`, SKIP Phase 1-7 hoàn toàn và route trực tiếp sang Phase 9 trên session cũ. Yêu cầu `--session-id=<ID>` (đã validate Step 1.1.7b).

**Trigger:** `$SCENARIOS_ONLY = "true"` AND `$SESSION_ID_FLAG` đã set.

**Pre-conditions PHẢI verify:**

| Check | Tool | Fail action |
|-------|------|-------------|
| 1. Target session tồn tại (`$SESSION_DIR/integrity-status.json` exists) | bash | **E016b STOP** — session ID không tồn tại |
| 2. Target session `pipeline_status` ∈ {`DONE`, `failed_phase_9_or_10`} (đã hoàn thành Phase 1-8 hoặc fail tại Phase 9-10) | jq | **E016b STOP** — Phase 1-8 chưa hoàn thành, không thể skip |
| 3. Target session có `phase8-report/integrity-impact.json` exists | bash | **E016b STOP** — thiếu Phase 8 output, không phải session hợp lệ |
| 4. CD41 đã sinh ≥1 scenarios (`phase4-coverage/lanes/CD41-e2e-synth/scenarios-manifest.json` exists + non-empty) | jq | **E016b STOP** — không có scenarios để execute |

**Bypass routing logic:**

```bash
if [ "$SCENARIOS_ONLY" = "true" ]; then
  TARGET_SESSION_DIR=".mc-data/work/wf-cmi/sessions/$SESSION_ID_FLAG"

  # Pre-conditions verify
  [ -f "$TARGET_SESSION_DIR/integrity-status.json" ] \
    || die "E016b" "--scenarios-only: target session không tồn tại: $SESSION_ID_FLAG"

  TARGET_STATUS=$(jq -r '.pipeline_status' "$TARGET_SESSION_DIR/integrity-status.json")
  case "$TARGET_STATUS" in
    DONE|failed_phase_9_or_10) ;;
    *) die "E016b" "--scenarios-only: target session pipeline_status=$TARGET_STATUS (cần DONE hoặc failed_phase_9_or_10)" ;;
  esac

  [ -f "$TARGET_SESSION_DIR/phase8-report/integrity-impact.json" ] \
    || die "E016b" "--scenarios-only: target session thiếu Phase 8 output"

  MANIFEST="$TARGET_SESSION_DIR/phase4-coverage/lanes/CD41-e2e-synth/scenarios-manifest.json"
  [ -f "$MANIFEST" ] \
    || die "E016b" "--scenarios-only: target session thiếu CD41 scenarios-manifest.json"
  SCENARIOS_COUNT=$(jq -r '.total_valid // 0' "$MANIFEST")
  [ "$SCENARIOS_COUNT" -gt 0 ] \
    || die "E016b" "--scenarios-only: scenarios-manifest.json total_valid=0"

  # Inherit session context from target
  SESSION_ID="$SESSION_ID_FLAG"
  SESSION_DIR="$TARGET_SESSION_DIR"

  # Re-acquire lock on target session (lock TTL 30 min stale auto-release)
  acquire_lock "$SESSION_DIR" || die "E018" "Cannot acquire lock on target session"
  start_heartbeat_daemon "$SESSION_DIR"
  trap cleanup EXIT INT TERM

  # Override v3 flags on target session (UPDATE integrity-status.json)
  jq --argjson exec "$EXEC_SCENARIOS" --argjson so true \
     --argjson sb "$SHOW_BROWSER" --argjson mb "$MOBILE" \
     --argjson se "$STRICT_EVIDENCE" --argjson np "$NO_PROMPT" \
     --argjson afs "$AUTO_FIX_SOURCE" \
     '.v3_flags = (.v3_flags // {}) + {
        exec_scenarios: $exec,
        scenarios_only: $so,
        show_browser: $sb,
        mobile: $mb,
        strict_evidence: $se,
        no_prompt: $np,
        auto_fix_source: $afs
     } | .next_action = "phase9-e2e-execute" | .current_phase = 9' \
     "$SESSION_DIR/integrity-status.json" > "$SESSION_DIR/integrity-status.json.tmp.$$"
  mv "$SESSION_DIR/integrity-status.json.tmp.$$" "$SESSION_DIR/integrity-status.json"

  # Log execution trace
  log_phase_event "phase1" "BYPASS" "{\"reason\":\"--scenarios-only\",\"target_session\":\"$SESSION_ID\",\"scenarios_count\":$SCENARIOS_COUNT}"

  # Route trực tiếp sang Phase 9 (skip Phase 1 POST-GATE, skip Phase 2-8)
  echo "✓ --scenarios-only mode: bypass Phase 1-7, route to Phase 9 with $SCENARIOS_COUNT scenarios"
  echo "→ Read procedures/phase9-e2e-execute.md"
  exit 0  # Orchestrator sẽ load Phase 9 procedure tiếp theo
fi
```

**Lưu ý quan trọng:**

- `--scenarios-only` KHÔNG tạo session mới — REUSE session cũ qua `$SESSION_ID_FLAG`
- v3 flags từ command-line UPDATE vào target session's `integrity-status.json.v3_flags` (override session cũ)
- Lock re-acquire trên target session (Protocol 22 R/W lock) — nếu peer session holding lock → wait/escalate per E018
- Phase 9 PRE-GATE T1 sẽ verify scenarios-manifest non-empty + Playwright available
- Phase 9 sau khi PASS → Phase 10 (nếu có FAIL) → Phase 8 re-write v3 E2E section (giữ logic v3 đầy đủ)

---

## §D POST-GATE (T1→T4 + Auto-Fix)

| Tier | Check | Auto-fix retry (max 3) |
|------|-------|------------------------|
| T1 | `test -f $SESSION_DIR/integrity-status.json` | Retry write step 1.15 |
| T2 | `jq '.' integrity-status.json` valid + có `$schema = integrity-status-v1` | Re-build từ template `templates/integrity-status.json` |
| T3 | `jq -e '.session_id != null and .current_phase == 1 and .dims_active != null'` | Re-generate session ID + reset state |
| T4 | Lock acquired (`.lock` exists + JSON valid + PID match `$$`) + heartbeat daemon active | Re-acquire lock (kill stale daemon, restart heartbeat) |

**POST-GATE pseudocode:**

```bash
post_gate_phase1() {
  local target="$SESSION_DIR/integrity-status.json"
  local retry=0
  while [ "$retry" -lt 3 ]; do
    # T1
    [ -f "$target" ] || { retry_step_1_15; retry=$((retry+1)); continue; }
    # T2
    jq -e '."$schema" == "integrity-status-v1"' "$target" >/dev/null \
      || { rebuild_from_template; retry=$((retry+1)); continue; }
    # T3
    jq -e '.session_id != null and .current_phase == 1 and .dims_active != null' "$target" >/dev/null \
      || { reset_state; retry=$((retry+1)); continue; }
    # T4
    [ -f "$SESSION_DIR/.lock" ] && jq -e ".pid == $$" "$SESSION_DIR/.lock" >/dev/null \
      && kill -0 "$(cat "$SESSION_DIR/.heartbeat.pid" 2>/dev/null)" 2>/dev/null \
      || { reacquire_lock; retry=$((retry+1)); continue; }
    # All passed
    return 0
  done
  die "E001" "Phase 1 POST-GATE fail after 3 retries"
}
```

**On POST-GATE PASS:**
1. Append session-log event `COMPLETE` (Phase 1 done)
2. Update `integrity-status.json`:
   - `.phases_completed = [1]`
   - `.current_phase = 2`
   - `.next_action = "phase2-discovery"`
   - `.checkpoint_at = <now>`
3. Update TodoWrite: Phase 1 = completed, Phase 2 = in_progress
4. Mark `$RETRY_COUNT[phase1] = 0`

---

## §E Phase Report Template (CORE-028)

Output file: `$SESSION_DIR/phase1-init/Phase1-report.md` (từ template `templates/Phase1-report.md`).

**Sample rendered content (tiếng Việt, ≤15 dòng):**

```markdown
## Phase 1: Khởi tạo + CI PRE-GATE — PASS
Thời gian: 2026-05-15T14:30:42+07:00

**Đã làm:**
- Kiểm tra đầu vào (registry, tài liệu kiến trúc) — đầy đủ
- Phát hiện công cụ phân tích code: GitNexus ✓, Serena ✓, index fresh
- Khởi tạo phiên ID: 2026-05-15-system-eureka-erp-01 (do Developer A)

**Kết quả:**
- Profile: standard | Scope: system (toàn dự án)
- Đo coverage 8 chiều: CD1,CD2,CD3,CD4,CD5,CD6,CD7,CD9
- Đã khóa phiên + kích hoạt heartbeat 30s

**Tiếp theo:**
- Phase 2 — Quét code dựng 6 bản đồ phụ thuộc (5-10 phút)
```

---

## §F Error Code Quick Reference (Phase 1 namespace E010-E019 + v3 E016b/E195b)

| Code | Severity | Description | Auto-fix |
|------|---------|-------------|----------|
| E010 | critical | Registry missing | ESCALATE → `/wf-brainstorm` |
| E011 | critical | Registry schema invalid | ESCALATE user fix manual |
| E012 | high | Registry empty / args conflict v2 | ESCALATE |
| E013 | high | Architecture docs missing | ESCALATE → `/wf-design` |
| E014 | high | `--since` invalid ref | ESCALATE user fix |
| E015 | medium | `--session-id` format invalid | Re-generate auto, WARN |
| E016 | medium | Args conflict v2 (priority resolve) | Resolve, WARN |
| **E016b** | **high** | **v3 mutual-exclusive flag combinations invalid** (--scenarios-only + --resume / --scenarios-only thiếu --session-id / target session không hợp lệ) | **STOP, hướng dẫn user fix** |
| E017 | high | Session dir creation fail | Retry x3 → ESCALATE |
| E018 | high | Lock acquire fail (peer active) | Retry x3 + 5s delay → ESCALATE |
| E019 | high | Heartbeat daemon spawn fail | Retry x1 → ESCALATE |
| E090b | medium | Parallel-session conflict CDG | AskUser: Wait/Cancel/Force |
| E091 | medium | Scope×Profile upgrade CDG | AskUser: Upgrade/Continue |
| **E195b** | **info** | **v3 Subset E2E Execute Confirm CDG** (--exec-scenarios + profile=quick\|standard) | **AskUser: Execute all/Execute MUST-only/Cancel; --no-prompt → silent default Execute MUST-only** |
| E100 | low | CI tool absent / CI mode flag adjust — fallback Grep | LOG, continue |
| E101 | low | CI index stale / v3 flag conflict warning | LOG, ignore conflicting flag, continue |

---

## §G Cross-References

| Reference | Section |
|-----------|---------|
| `_shared.md` | §1 State Vars, §3 Atomic Write, §12 CI Detection, §13 Session Lock, §17 Author |
| `_error-quick-lookup.md` | §Quick Lookup Table — đầy đủ 30+ codes E001-E199 (v3.0) |
| `procedures/phase4-coverage-dispatch.md` | §Wave 3 logic — đọc `v3_cdg.cd41_force_activate` để override profile activation |
| `procedures/phase9-e2e-execute.md` | §B PRE-GATE T1 — đọc `v3_flags.exec_scenarios` + `v3_cdg.cd41_filter_severity` |
| `procedures/resume-status.md` | §--scenarios-only Handler — hỗ trợ resume từ Phase 9 (v3.0 NEW) |
| `docs/04-skill-design/wf-cmi/03-phase-routing.md` | §1 Routing map (v3 thêm Phase 9-10 + --scenarios-only bypass) |
| `docs/04-skill-design/wf-cmi/04-file-contract.md` | §1 PRE-GATE Phase 1, §2 POST-GATE Phase 1 |
| `docs/04-skill-design/wf-cmi/05-error-codes.md` | E010-E019 + E016b/E195b namespace detail |
| `.claude/scripts/ci-detect.sh` | CI detection helper |
| `.claude/scripts/ci-freshness-check.sh` | Index freshness helper |
| `.claude/scripts/ci-inject-context.sh` | CI context builder |

---

## §H Next

| Condition | Next phase | Procedure file |
|-----------|-----------|----------------|
| Phase 1 PASS (default flow) | Phase 2 Discovery | `procedures/phase2-discovery.md` |
| `--scenarios-only` (Step 1.21 bypass) | Phase 9 E2E Execute | `procedures/phase9-e2e-execute.md` |
| `--resume` (route từ Step 1.1.8) | last checkpoint phase | `procedures/resume-status.md` §--resume |
| `--status` (route từ Step 1.1.8) | Display + exit 0 | `procedures/resume-status.md` §--status |
