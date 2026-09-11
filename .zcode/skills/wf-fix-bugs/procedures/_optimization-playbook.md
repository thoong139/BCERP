# Phase Optimization Playbook — wf-fix-bugs v10.14.0

> **Mục đích:** Canonical reference cho 10 kỹ thuật tối ưu Phase 1 (v10.11→v10.14). Áp dụng tuần tự khi optimize bất kỳ phase nào trong pipeline để giảm context load runtime + tăng tốc execution.
>
> **Đọc trước khi optimize phase mới.** Mỗi kỹ thuật có: mục đích, khi áp dụng, pattern template, ví dụ thực tế Phase 1, ước tính saving.

## Mục lục

| # | Kỹ thuật | Saving target | Risk |
|---|----------|---------------|------|
| **T1** | [Parallel Wave Dispatchers](#t1-parallel-wave-dispatchers) | -30-50% exec time | Low |
| **T2** | [Fast-Path Bash Bypass](#t2-fast-path-bash-bypass) | -200-500ms/call | Low |
| **T3** | [Caching for Idempotent Validations](#t3-caching-for-idempotent-validations) | -50-90% repeat ops | Low |
| **T4** | [Heavy Inline Bash Extraction](#t4-heavy-inline-bash-extraction) | -30-40% procedure size | Low |
| **T5** | [Shared Protocols Split](#t5-shared-protocols-split) | -80-95% shared context | Medium |
| **T6** | [Phase Lazy-Load Split](#t6-phase-lazy-load-split) | -83% initial phase context | Medium |
| **T7** | [Group Banners + Execution Flow Map](#t7-group-banners--execution-flow-map) | (clarity, no token saving) | Very Low |
| **T8** | [Smoke Test for Routing Chain](#t8-smoke-test-for-routing-chain) | (correctness gate) | Very Low |
| **T9** | [Cross-Platform Defensive Scripts](#t9-cross-platform-defensive-scripts) | (reliability) | Very Low |
| **T10** | [Versioned Schemas with Audit Trail](#t10-versioned-schemas-with-audit-trail) | (compatibility) | Low |

---

## T1: Parallel Wave Dispatchers

**Mục đích:** Group N sub-steps độc lập về dữ liệu thành 1 bash tool call, chạy parallel internally qua `&` + `wait`.

**Khi áp dụng:**
- ≥2 sub-steps cùng phase, KHÔNG phụ thuộc output lẫn nhau
- Mỗi sub-step có IO bound (file read, network call, subprocess)
- Tổng thời gian sequential >100ms (đủ để parallel có ý nghĩa)

**KHÔNG áp dụng:**
- Sub-steps có data dependency (output A → input B)
- 1 sub-step duy nhất
- CPU-bound work không có IO

**Pattern template:**

```bash
#!/usr/bin/env bash
# Wave dispatcher — N parallel workers
set -u
WAVE_TMP="${TMPDIR:-/tmp}/wave-$$"
mkdir -p "$WAVE_TMP"
trap "rm -rf '$WAVE_TMP'" EXIT INT TERM

# Worker 1
( bash worker1.sh > "$WAVE_TMP/w1.env" 2>"$WAVE_TMP/w1.err" ) &
PID1=$!

# Worker 2
( bash worker2.sh > "$WAVE_TMP/w2.env" 2>"$WAVE_TMP/w2.err" ) &
PID2=$!

# Wait + aggregate
wait $PID1; EXIT1=$?
wait $PID2; EXIT2=$?

# Output env-style for orchestrator eval
cat "$WAVE_TMP/w1.env" "$WAVE_TMP/w2.env"

# Telemetry
echo "WAVE_DURATION_MS=$(( $(date +%s%3N) - T0 ))"

# Exit aggregation
[ $EXIT1 -ne 0 ] || [ $EXIT2 -ne 0 ] && exit 1
exit 0
```

**Ví dụ Phase 1:**
- `phase1-wave1-dispatch.sh`: CI PRE-GATE + Registry + Sub-skill paths (3 workers)
- `phase1-init-bundle.sh`: State files + Bug dashboard (2 workers)

**Saving:** Bash startup overhead ~50-100ms × N saved. I/O parallelism ~40-50% wall clock reduction.

---

## T2: Fast-Path Bash Bypass

**Mục đích:** Replace Python interpreter spawn với bash hardcoded lookup cho các trường hợp đã biết.

**Khi áp dụng:**
- Python script được gọi với fixed inputs (vd: profile=quick/standard/deep)
- Output có thể compute đơn giản bằng bash (table lookup, simple math)
- Cold Python spawn >200ms (Windows/Git Bash đặc biệt nặng)

**KHÔNG áp dụng:**
- Python script làm complex logic (ML, parsing, network)
- Inputs unbounded (cannot enumerate cases)

**Pattern template:**

```bash
#!/usr/bin/env bash
# Fast-path bypass — bash lookup cho profiles chuẩn
set -eu

PROFILE="$1"

# Escape hatch: force original Python path
if [ "${MCV3_FORCE_PYTHON:-0}" = "1" ]; then
  exec python -m <module> --profile="$PROFILE"
fi

# Fast-path hardcoded lookup
case "$PROFILE" in
  quick)      echo "OUTPUT_A" ;;
  standard)   echo "OUTPUT_B" ;;
  deep)       echo "OUTPUT_C" ;;
  *)
    # Unknown → fallback Python
    exec python -m <module> --profile="$PROFILE"
    ;;
esac
```

**Ví dụ Phase 1:**
- `phase1-isg-fastpath.sh`: Profile→dimensions ~5ms vs Python ISG ~200-500ms

**Saving:** ~200-500ms/call. Cumulative đáng kể nếu Python module bị spawn nhiều lần.

---

## T3: Caching for Idempotent Validations

**Mục đích:** Cache kết quả idempotent checks (file existence, schema validation) với TTL.

**Khi áp dụng:**
- Validation chạy nhiều lần với cùng inputs
- Inputs hiếm khi thay đổi (vd: sub-skill paths chỉ thay đổi khi install)
- Validation cost >50ms (đủ để cache có ý nghĩa)

**KHÔNG áp dụng:**
- Validation cần real-time (state thay đổi liên tục)
- Inputs unbounded (cache miss rate cao)

**Pattern template:**

```bash
#!/usr/bin/env bash
# Cache wrapper
set -eu

CACHE_DIR="${MCV3_CACHE_DIR:-$HOME/.cache/mcv3-fix-bugs}"
mkdir -p "$CACHE_DIR"

# Cache key = md5 of inputs
CACHE_KEY=$(echo -n "$*" | md5sum | cut -d' ' -f1)
CACHE_FILE="$CACHE_DIR/check-$CACHE_KEY.json"
CACHE_TTL_SEC="${MCV3_CACHE_TTL:-86400}"   # 24h default

# Cache hit check
if [ -f "$CACHE_FILE" ] && [ -s "$CACHE_FILE" ]; then
  AGE=$(( $(date +%s) - $(stat -c '%Y' "$CACHE_FILE" 2>/dev/null || stat -f '%m' "$CACHE_FILE" 2>/dev/null || echo 0) ))
  if [ "$AGE" -lt "$CACHE_TTL_SEC" ] && jq -e '.' "$CACHE_FILE" >/dev/null 2>&1; then
    jq '. + {cached: true}' "$CACHE_FILE"
    exit 0
  fi
fi

# Cache miss — compute fresh + write atomic
RESULT=$(<actual validation logic>)
echo "$RESULT" > "$CACHE_FILE.tmp.$$" && mv "$CACHE_FILE.tmp.$$" "$CACHE_FILE"
echo "$RESULT" | jq '. + {cached: false}'
```

**Ví dụ Phase 1:**
- `phase1-validate-paths.sh`: Cache 24h cho 13 sub-skill paths (10ms cache hit vs 100ms cold)

**Saving:** Cache hit ~90% faster. Cache invalidates only on infrastructure change.

---

## T4: Heavy Inline Bash Extraction

**Mục đích:** Move bash code blocks ≥30 lines từ procedure markdown sang standalone script files.

**Khi áp dụng:**
- Bash block ≥30 dòng trong procedure file
- Logic độc lập, có thể test standalone
- Có thể reuse hoặc invoke từ nhiều nơi
- Orchestrator chỉ cần biết "chạy script + parse output"

**KHÔNG áp dụng:**
- Bash <20 dòng (overhead extract không đáng)
- Logic phụ thuộc shell state phức tạp (subshell isolation phá)
- User-interaction code (CDG AskUserQuestion phải INLINE)

**Pattern template:**

```bash
#!/usr/bin/env bash
# script.sh — extracted from procedure file Step X.Y
# =============================================================================
# Mục đích: <1-line description>
# Required env vars: VAR1, VAR2
# Output (stdout): env-style for `eval "$(bash script.sh)"`
#   VAR1=<value>
#   VAR2=<value>
# Exit codes:
#   0 — Success
#   1 — Required env var missing
#   2 — <specific failure>
# =============================================================================

set -u  # KHÔNG dùng -e nếu cần custom error handling

# Validate env vars
for var in VAR1 VAR2; do
  [ -z "${!var:-}" ] && { echo "ERROR: \$$var required" >&2; exit 1; }
done

# Logic ...

# Output env-style stdout
cat <<EOF
OUTPUT_VAR1=$value1
OUTPUT_VAR2=$value2
EOF
exit 0
```

**Orchestrator usage trong procedure:**

```bash
# Replace 30+ lines bash với:
eval "$(VAR1=$X VAR2=$Y bash .claude/scripts/wf-fix-bugs/script.sh)"
test -n "$OUTPUT_VAR1" || { echo "E0XX: script failed"; exit 1; }
```

**Ví dụ Phase 1:**
- `phase1-parse-flags.sh` (60→1 dòng inline)
- `phase1-auto-resolve.sh` (45→3 dòng)
- `phase1-create-session.sh` (40→5 dòng)
- `phase1-trace-start.sh` (15→5 dòng)

**Saving:** Procedure file giảm 30-40% lines. Scripts reusable + testable.

---

## T5: Shared Protocols Split

**Mục đích:** Tách monolithic `_shared.md` (1000+ dòng) thành sub-files trong `_shared/` folder; mỗi phase chỉ load section cần thiết.

**Khi áp dụng:**
- Shared file >500 dòng
- Mỗi phase chỉ dùng 1-3 sections
- Có thể identify section boundaries rõ ràng (## headers)

**Pattern template:**

```
procedures/
├── _shared.md                # Redirect file ~30 dòng (backward compat)
└── _shared/                  # Folder mới
    ├── README.md             # Index + load profile per-phase
    ├── 01-section-name.md    # 1 section per file
    ├── 02-section-name.md
    ├── ...
    └── NN-section-name.md
```

**Mỗi phase file declare loading explicit:**

```markdown
> **Shared protocols (lazy-load — chỉ đọc khi tới use-site):**
> - [`_shared/13-lock-heartbeat.md`](_shared/13-lock-heartbeat.md) — dùng ở Step X.Y
> - [`_shared/19-bug-dashboard.md`](_shared/19-bug-dashboard.md) — dùng ở Step X.Z
>
> **KHÔNG đọc toàn bộ `_shared/` folder.**
```

**Slim duplicate sections:** Sections trùng với `rules/00-core.md` (vd: State Vars, Error Handling) → pointer 1 dòng.

**Ví dụ Phase 1 v10.13:**
- `_shared.md`: 1227 dòng → 21 files trong `_shared/` (avg ~60 dòng/file)
- Phase 1 chỉ load 2 files: §13 + §19 = 106 dòng (vs 1227 cũ = **-91%**)

**Saving:** -80-95% shared context per phase invocation.

---

## T6: Phase Lazy-Load Split

**Mục đích:** Tách phase file (>500 dòng) thành index router + group sub-files; orchestrator load từng group ON-DEMAND.

**Khi áp dụng:**
- Phase file >500 dòng
- Có ≥3 group thực thi logic rõ ràng
- Mỗi group sequential, không cần preload toàn bộ
- Groups có Input/Output contract rõ ràng

**KHÔNG áp dụng:**
- Phase ngắn <300 dòng (overhead split không đáng)
- Groups phụ thuộc context chéo nhiều
- Phase có loop quay lại nhiều groups (split sẽ break flow)

**Pattern template:**

```
procedures/
├── phaseN-name.md                  # 80-120 dòng INDEX router
└── phaseN-name/                    # NEW folder
    ├── A-<group>.md                # 60-160 dòng each
    ├── B-<group>.md
    ├── ...
    └── POST-GATE.md                # T1-T5 + error reference
```

**Index file structure (~100 dòng):**

```markdown
# Phase N: <Name> v<version> (Lazy-Load Router)

> Procedure split thành 8 sub-files. Orchestrator đọc index này, sau đó load TỪNG group file khi tới execution.

## PRE-GATE
[bash pre-gate checks]

## Input / Output Contract
[summary]

## Execution Flow
[ASCII diagram]

## Group Routing Table (lazy-load)
| Group | File path | Steps | Lines | Khi đọc |
|-------|-----------|-------|-------|---------|
| A | [phaseN-name/A-xxx.md] | ... | ~120 | Sau PRE-GATE PASS |
| B | [phaseN-name/B-xxx.md] | ... | ~80 | Sau Group A POST-GATE PASS |
| ... |

## Shared Protocols (lazy-load per use-site)
[list with which group needs them]

## Orchestrator Execution Pattern
[step-by-step routing instructions]
```

**Mỗi group file structure (~100-150 dòng):**

```markdown
# Phase N Group X — <Name> (Steps N.x → N.y)

> **Entry condition:** [previous group POST-GATE pass]
> **Exit condition:** [success criteria]
> **Next:** [phaseN-name/Y-name.md OR end of Phase N]
>
> **Shared protocols cần thiết:** [list of _shared/ files]

## Input contract (env vars từ previous group)
| Variable | Description |
|----------|-------------|

## Output contract (env vars truyền sang next group)
| Variable | Description |
|----------|-------------|

## Steps
### Step N.M — <Name>
[implementation]

## Group X POST-GATE Verify
[bash verify]

## Next Group
→ Group Y — đọc [`phaseN-name/Y-name.md`](Y-name.md)
```

**Ví dụ Phase 1 v10.14:**
- `phase1-init.md`: 1106 dòng → 118 dòng index + 8 group files (~853 dòng total)
- Initial load: -83% (9K → 1.5K tokens)
- Per-group: ~500-1200 tokens

**Saving:** -83% initial context. Incremental load total similar (no overall waste).

---

## T7: Group Banners + Execution Flow Map

**Mục đích:** Visual diagrams + group section banners để clarity (KHÔNG có token saving, nhưng giảm AI confusion).

**Khi áp dụng:**
- Phase có ≥5 steps phức tạp
- Steps grouped theo logical concerns (Bootstrap, Discovery, Setup, ...)
- Parallel waves cần phân biệt với sequential steps

**Pattern template:**

```markdown
## Execution Flow Map

```
┌──────────────────────────────────────────────────────────┐
│ Group A: <Name> (Steps N.x → N.y)        SEQUENTIAL     │
│   N.x → N.y → ...                                        │
└──────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────┐
│ Group B: <Name> (Steps N.z + N.zz)       PARALLEL       │
│   ┌─ Worker 1                                            │
│   └─ Worker 2          ← script.sh                       │
└──────────────────────────────────────────────────────────┘
```

## Group A: <Name> — Sequential
[description]

### Step N.x — ...
```

**Ví dụ Phase 1:** Box diagram 7 groups + section banners trong phase1-init.md.

---

## T8: Smoke Test for Routing Chain

**Mục đích:** Verify lazy-load routing chain unbroken trước khi commit phase split.

**Khi áp dụng:**
- Sau khi áp dụng T6 (phase split)
- Trước mỗi commit thay đổi structure phase folder

**Pattern template:**

```bash
#!/usr/bin/env bash
# phaseN-routing-smoke-test.sh
# Verify:
#   1. Index file exists + đủ N group references
#   2. Mỗi group file exists + có Next pointer đúng
#   3. Routing chain unbroken: A → B → ... → POST-GATE
#   4. Mỗi group có Input/Output contract sections
#   5. Helper scripts exist + executable

PASS=0; FAIL=0; WARN=0
pass() { echo "  ✓ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $1" >&2; FAIL=$((FAIL+1)); }
warn() { echo "  ! $1" >&2; WARN=$((WARN+1)); }

# 5 check categories: index integrity, group existence,
# routing chain, structure (Input/Output), scripts ready

# Summary + exit
[ "$FAIL" -gt 0 ] && exit 1
exit 0
```

**Ví dụ Phase 1:** `phase1-routing-smoke-test.sh` (42 checks).

---

## T9: Cross-Platform Defensive Scripts

**Mục đích:** Scripts hoạt động đúng trên Git Bash (Windows), WSL, macOS, Linux.

**Patterns:**

```bash
# 1. POSIX-safe mkdir atomic (no brace expansion)
for subdir in dir1 dir2 dir3; do
  mkdir -p "$ROOT/$subdir"
done
# KHÔNG dùng: mkdir -p "$ROOT/{dir1,dir2,dir3}" (bash-only)

# 2. Portable file size check
SIZE=$(stat -c '%s' "$FILE" 2>/dev/null \
       || stat -f '%z' "$FILE" 2>/dev/null \
       || wc -c < "$FILE" | tr -d ' ')

# 3. bc absent on Git Bash → awk
VAL=$(awk -v x="$x" -v y="$y" 'BEGIN {if(y>0) printf "%d", x*100/y; else print "0"}')

# 4. grep -c | tr -d '\r' chống "0\n0" corruption
CNT=$(grep -c "pattern" "$file" 2>/dev/null | head -1 | tr -d '\r')
[ -z "$CNT" ] && CNT=0

# 5. read -ra cho POSIX-safe word split (Windows paths có space)
read -ra TOKENS <<< "${ARGUMENTS:-}"
for arg in "${TOKENS[@]}"; do
  case "$arg" in
    --flag=*) VAR="${arg#*=}" ;;
  esac
done

# 6. Atomic JSON write (CORE-035)
TMP="$TARGET.tmp.$$"
jq <filter> "$SOURCE" > "$TMP" && jq '.' "$TMP" >/dev/null && mv "$TMP" "$TARGET"
```

---

## T10: Versioned Schemas with Audit Trail

**Mục đích:** Mọi cross-skill artifact có `$schema` versioned + `audit_chain.checksum_sha256` cho integrity.

**Pattern:**

```json
{
  "$schema": "artifact-name-v2",
  "session_id": "...",
  "data": {...},
  "audit_chain": {
    "source_file": "path/to/source.json",
    "checksum_sha256": "abc123...",
    "generated_at": "ISO-8601",
    "generated_by": "script-name.sh"
  }
}
```

**Backward compat rule:** Bump version, GIỮ v1 fields top-level, thêm v2 fields. Consumer skill check `$schema` để route logic.

**Ví dụ:** `fix-impact-v2`, `coverage-report-v1`, `cdg-tokens-v1`.

---

## Áp dụng tuần tự khi optimize phase mới

**Workflow đề xuất:**

1. **Đo baseline** — `wc -l phaseN.md`, count bash blocks, identify big steps
2. **T9 + T10** — Verify scripts đã defensive + schemas đã versioned (foundation)
3. **T4** — Extract heavy inline bash (low risk, immediate -30-40% saving)
4. **T1** — Identify parallel opportunities, create wave dispatcher
5. **T2** — Identify Python spawns có thể bypass
6. **T3** — Identify idempotent validations cần cache
7. **T7** — Add group banners + flow map (improve readability)
8. **T6** — Split into group files NẾU phase >500 dòng (biggest win)
9. **T5** — Update shared protocol references nếu cần
10. **T8** — Write smoke test, run before commit

**Order matters:** T4 trước T6 (extract bash dễ hơn khi file còn nguyên), T1 trước T6 (xác định waves trước khi split groups), T8 cuối cùng (verify final structure).

## Khi NÀO không áp dụng (red flags)

- Phase <300 dòng → SKIP T6 (overhead split không đáng)
- 1-2 sub-steps → SKIP T1 (parallel không có ý nghĩa)
- Validation chạy 1 lần/session → SKIP T3 (cache miss rate 100%)
- Python script làm complex logic → SKIP T2 (bash không thể replace)
- User-interaction code (CDG, AskUserQuestion) → SKIP T4 (phải INLINE)

## Metrics đã đạt được (Phase 1, v10.11 → v10.14)

| Metric | v10.11 | v10.14 | Saving |
|--------|--------|--------|--------|
| Bash tool calls Phase 1 | ~10 | ~7 | -30% |
| Pure exec time | baseline | -500-900ms | -2-3% |
| Shared context per phase | 10K tokens | 1K | -91% |
| Phase 1 initial load | 9K | 1.5K | -83% |
| Per-group context | (all loaded) | 500-1200 tokens | -88% per group |
| **Peak context per phase invocation** | **~19K** | **~2.5K** | **-87%** |
