#!/usr/bin/env bash
set -euo pipefail
# wf-fix-probe-static-business.sh — Static probe: Business Logic Audit (QD2)
#
# Phat hien anti-patterns business logic trong C# CommandHandlers + Endpoints:
#  - Throw exception thay vi Result<T> (railway pattern violation per CLAUDE.md)
#  - Endpoint khong RequireAuthorization (auth gap)
#  - CommandHandler thieu Validator (validation gap)
#  - Magic strings/numbers trong domain logic
#
# OUTPUT: JSON tren stdout theo schema lane-signals-v1
# Cache policy: allowed (business logic ít thay đổi sau commit)
#
# USAGE:
#   bash wf-fix-probe-static-business.sh \
#     --session-dir <path> [--profile standard|deep|exhaustive] [--source-dir src/]
#
# EXIT CODES: 0 success, 1 error
#
# Author: CRM fix-bugs session 2026-05-04


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/wf-fix-common.sh"

# Defensive runtime cap (SB-01 v7.4.0 e2e fix): prevent hang on large codebases.
with_runtime_cap "$@"
_sha256() { sha256sum 2>/dev/null || shasum -a 256; }

SESSION_DIR=""
LANE="wf-fix-business"
PROBE_ID="P-QD2-hardcoded-value-detect"
PROBE_VERSION="v1.0"
PROFILE="standard"
SOURCE_DIR="src/"

while [ $# -gt 0 ]; do
  case "$1" in
    --session-dir) SESSION_DIR="$2"; shift 2 ;;
    --lane) LANE="$2"; shift 2 ;;
    --probe) PROBE_ID="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --source-dir) SOURCE_DIR="$2"; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg $1" >&2; exit 1 ;;
  esac
done

if [ ! -d "$SOURCE_DIR" ]; then
  jq -nc \
    --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
    --arg profile "$PROFILE" --arg now "$(iso_now)" \
    '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD2", probe_id: $probe,
      probe_version: $pver, profile: $profile, generated_at: $now,
      signals: [], skip_reason: "no_source_dir"}'
  exit 0
fi

EXCLUDE='(__tests__|test/|tests/|spec/|\.test\.|\.spec\.|fixtures/|mocks?/|node_modules|\.git/|bin/|obj/)'

EMIT() {
  local title="$1" desc="$2" severity="$3" file="$4" line="$5" suggested_action="$6"
  local fp
  fp=$(echo -n "QD2|$file|$line|$PROBE_ID|$title" | _sha256 | awk '{print "sha256:"$1}')
  jq -nc \
    --arg t "$title" --arg d "$desc" --arg s "$severity" \
    --arg f "$file" --argjson l "$line" --arg fp "$fp" --arg pid "$PROBE_ID" \
    --arg pver "$PROBE_VERSION" --arg lane "$LANE" --arg now "$(iso_now)" \
    --arg sa "$suggested_action" \
    '{
      "$schema": "signal-v2",
      dimension_id: "QD2",
      probe_id: $pid,
      probe_version: $pver,
      severity: $s,
      fixability: "agent_fix",
      domain: "backend",
      title: $t,
      description: $d,
      location: { file: $f, line: $l, column: null, selector: null, url: null },
      evidence: [{ type: "code", path: $f, description: ("Line " + ($l|tostring)) }],
      cdg_flags: [],
      fingerprint: $fp,
      remediation: { suggested_action: $sa, suggested_agent: "developer", estimated_effort: "moderate" },
      detected_at: $now,
      detected_by: ($lane + "/" + $pid)
    }'
}

SIGNALS_JSON='[]'

# ── Probe dispatch (IMP-025) ──────────────────────────────────────────
# Map canonical PROBE_ID → which checks to run.
# Unknown probe ID → fail-fast (no phantom probes).
RUN_RAILWAY=0   # throw-in-CommandHandler (P-QD2-calculation-check)
RUN_AUTH=0      # endpoint missing RequireAuthorization (P-QD2-calculation-check)
RUN_VALIDATOR=0 # Command missing Validator (P-QD2-hardcoded-value-detect)
RUN_MAGIC=0     # magic numbers in domain logic (P-QD2-hardcoded-value-detect)
RUN_TS_SENTINEL=0  # hardcoded sentinel UUIDs in TypeScript (P-QD2-hardcoded-value-detect)
RUN_TS_MUTATION=0  # useMutation without onError in TypeScript (P-QD2-calculation-check)
RUN_TS_STATS=0     # paginated data aggregation instead of server total (P-QD2-calculation-check)

case "$PROBE_ID" in
  P-QD2-calculation-check)
    RUN_RAILWAY=1; RUN_AUTH=1; RUN_TS_MUTATION=1; RUN_TS_STATS=1 ;;
  P-QD2-hardcoded-value-detect)
    RUN_VALIDATOR=1; RUN_MAGIC=1; RUN_TS_SENTINEL=1 ;;
  P-QD2-domain-expert-review|P-QD2-domain-fixture|P-QD2-business-analyst-review)
    # Agent probes — bash script emits SPEC-ONLY-PROBE-SKIP
    jq -nc --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
      --arg profile "$PROFILE" --arg now "$(iso_now)" \
      '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD2", probe_id: $probe,
        probe_version: $pver, profile: $profile, generated_at: $now,
        signals: [], probe_status: "SPEC-ONLY-PROBE-SKIP",
        skip_reason: "agent_probe_requires_agent_runner"}'
    exit 0 ;;
  *)
    echo "ERROR: unknown PROBE_ID '$PROBE_ID' for QD2 — valid: P-QD2-calculation-check, P-QD2-hardcoded-value-detect, P-QD2-domain-expert-review, P-QD2-domain-fixture, P-QD2-business-analyst-review" >&2
    exit 1 ;;
esac

# ============================================================
# CHECK 1: CommandHandlers using `throw new InvalidOperationException`
# (Railway pattern violation per CLAUDE.md)
# ============================================================
if [ "$RUN_RAILWAY" -eq 1 ]; then
while IFS=: read -r file line match; do
  [ -z "$file" ] && continue
  [ -z "$line" ] && continue
  if echo "$file" | grep -qE "$EXCLUDE"; then continue; fi
  if ! echo "$file" | grep -qE "CommandHandler\.cs$"; then continue; fi
  s=$(EMIT "Anti-pattern: throw in CommandHandler" \
    "CommandHandler nem InvalidOperationException thay vi tra Result<T>.Failure() — vi pham railway pattern (CLAUDE.md). Khach hang nhan 500 thay vi 400 BadRequest co domain error." \
    "high" "$file" "$line" \
    "Refactor: tra ve Result<T>.Failure(new Error(code, message)) thay cho throw. Cap nhat Command return type IRequest<Result<T>> va endpoint .IsSuccess check.")
  SIGNALS_JSON=$(echo "$SIGNALS_JSON" | jq --argjson sig "$s" '. + [$sig]')
done < <(grep -rEn "throw new InvalidOperationException" "$SOURCE_DIR" --include="*.cs" 2>/dev/null)
fi # RUN_RAILWAY

# ============================================================
# CHECK 2: Endpoint files (*Endpoints.cs) without RequireAuthorization
# ============================================================
if [ "$RUN_AUTH" -eq 1 ]; then
while IFS= read -r file; do
  [ -z "$file" ] && continue
  if echo "$file" | grep -qE "$EXCLUDE"; then continue; fi
  # Endpoint file phai co MapGet/MapPost va RequireAuthorization (allow AllowAnonymous override)
  if grep -qE "Map(Get|Post|Put|Delete|Patch)" "$file" 2>/dev/null; then
    if ! grep -qE "RequireAuthorization|AllowAnonymous" "$file" 2>/dev/null; then
      s=$(EMIT "Endpoint thieu auth" \
        "File endpoint khai bao route nhung KHONG goi RequireAuthorization() hoac AllowAnonymous() — co the bi truy cap unauthenticated." \
        "critical" "$file" 1 \
        "Them .RequireAuthorization() (default) hoac .AllowAnonymous() (neu cong khai chu y) cho moi route.")
      SIGNALS_JSON=$(echo "$SIGNALS_JSON" | jq --argjson sig "$s" '. + [$sig]')
    fi
  fi
done < <(find "$SOURCE_DIR" -name "*Endpoints.cs" -type f 2>/dev/null)
fi # RUN_AUTH

# ============================================================
# CHECK 3: CommandHandler co tuong ung Validator khong?
# Heuristic: voi moi *Command.cs khong phai Handler/Validator/Result, kiem tra co Validator file ke ben.
# ============================================================
if [ "$RUN_VALIDATOR" -eq 1 ] && { [ "$PROFILE" = "deep" ] || [ "$PROFILE" = "exhaustive" ]; }; then
  while IFS= read -r cmd_file; do
    [ -z "$cmd_file" ] && continue
    if echo "$cmd_file" | grep -qE "$EXCLUDE"; then continue; fi
    base=$(basename "$cmd_file" .cs)
    # Skip non-Command files
    if echo "$base" | grep -qE "(Handler|Validator|Result|Response|Dto)$"; then continue; fi
    if ! echo "$base" | grep -qE "Command$"; then continue; fi

    dir=$(dirname "$cmd_file")
    validator="${dir}/${base}Validator.cs"
    if [ ! -f "$validator" ]; then
      s=$(EMIT "Command thieu Validator" \
        "Command $base khong co Validator file ke ben (${base}Validator.cs). MediatR FluentValidation pipeline khong validate inputs → bypass safety net." \
        "medium" "$cmd_file" 1 \
        "Tao ${base}Validator.cs implements AbstractValidator<$base> voi rules cho moi field bat buoc.")
      SIGNALS_JSON=$(echo "$SIGNALS_JSON" | jq --argjson sig "$s" '. + [$sig]')
    fi
  done < <(find "$SOURCE_DIR" -name "*Command.cs" -type f 2>/dev/null)
fi

# ============================================================
# CHECK 4: Magic numbers in business logic (heuristic: hardcoded thresholds in if/while)
# Only in deep/exhaustive profile to reduce noise
# ============================================================
if [ "$RUN_MAGIC" -eq 1 ] && [ "$PROFILE" = "exhaustive" ]; then
  while IFS=: read -r file line match; do
    [ -z "$file" ] && continue
    if echo "$file" | grep -qE "$EXCLUDE"; then continue; fi
    if ! echo "$file" | grep -qE "/(Domain|Application)/.*\.cs$"; then continue; fi
    # Skip enum default values (e.g., "= 0,") and array indices
    if echo "$match" | grep -qE "(=\s*[0-9]+\s*,\s*//?|\[[0-9]+\]|enum)"; then continue; fi
    s=$(EMIT "Magic number trong business logic" \
      "Phat hien hardcoded number ($match) trong if/while branch — neu la nguong nghiep vu, nen tach thanh constant co ten ro nghia (BR-XXX reference)." \
      "low" "$file" "$line" \
      "Extract magic number into private static readonly hoac per-priority Dictionary voi comment // BR-XXX.")
    SIGNALS_JSON=$(echo "$SIGNALS_JSON" | jq --argjson sig "$s" '. + [$sig]')
  done < <(grep -rEn "(if|while)\s*\([^)]*[><]=?\s*[0-9]{2,}" "$SOURCE_DIR" --include="*.cs" 2>/dev/null | head -30)
fi

# ============================================================
# CHECK 5 (TypeScript): Hardcoded sentinel UUID '00000000-...'
# Indicates business logic error: ownerId/userId not set from auth context.
# ============================================================
if [ "$RUN_TS_SENTINEL" -eq 1 ]; then
  while IFS=: read -r file line match; do
    [ -z "$file" ] && continue
    [ -z "$line" ] && continue
    if echo "$file" | grep -qE "$EXCLUDE"; then continue; fi
    # Skip test files and mock files
    if echo "$file" | grep -qE '(__tests__|\.spec\.|\.test\.|fixtures/|mocks?/)'; then continue; fi
    s=$(EMIT "Hardcoded sentinel UUID trong TypeScript" \
      "Phat hien '00000000-0000-0000-0000-000000000000' (null UUID sentinel) duoc hardcode. Co the la ownerId, userId, hoac assignment placeholder chua duoc thay bang auth context thuc. Neu persist xuong DB, record se khong co owner hop le." \
      "critical" "$file" "$line" \
      "Thay bang user ID lay tu auth context (useAuthStore, session, JWT claims). Vi du: user?.id ?? throwIfNull('ownerId required').")
    SIGNALS_JSON=$(echo "$SIGNALS_JSON" | jq --argjson sig "$s" '. + [$sig]')
  done < <(grep -rEn "['\"]00000000-0000-0000-0000-000000000000['\"]" "$SOURCE_DIR" \
    --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' 2>/dev/null || true)
fi

# ============================================================
# CHECK 6 (TypeScript): useMutation calls without onError handler
# Silent API failure — user gets no feedback when mutation fails.
# ============================================================
if [ "$RUN_TS_MUTATION" -eq 1 ] && [ -d "$SOURCE_DIR" ]; then
  # Find files that contain useMutation but not onError (simple heuristic)
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    if echo "$file" | grep -qE "$EXCLUDE"; then continue; fi
    if echo "$file" | grep -qE '(__tests__|\.spec\.|\.test\.)'; then continue; fi
    # Count useMutation vs onError in file
    mutation_count=$(grep -c 'useMutation(' "$file" 2>/dev/null || true)
    on_error_count=$(grep -c 'onError' "$file" 2>/dev/null || true)
    # If more mutations than onError handlers — likely missing some
    if [ "$mutation_count" -gt 0 ] && [ "$on_error_count" -lt "$mutation_count" ]; then
      missing=$((mutation_count - on_error_count))
      line=$(grep -n 'useMutation(' "$file" 2>/dev/null | head -1 | cut -d: -f1)
      line="${line:-1}"
      s=$(EMIT "useMutation thieu onError handler (TypeScript)" \
        "File $file co $mutation_count useMutation() nhung chi co $on_error_count onError handler (thieu $missing). Khi API call that bai, user khong nhan bat ky feedback nao — silent failure. Day la UX bug nghiem trong tren cac mutation action nhu create/update/delete." \
        "high" "$file" "$line" \
        "Them onError callback cho moi useMutation: onError: (error) => { console.error(...); } hoac show toast.error(). Neu dung react-query, co the set global mutation error handler trong QueryClient.defaultOptions.")
      SIGNALS_JSON=$(echo "$SIGNALS_JSON" | jq --argjson sig "$s" '. + [$sig]')
    fi
  done < <(grep -rl 'useMutation(' "$SOURCE_DIR" \
    --include='*.ts' --include='*.tsx' 2>/dev/null || true)
fi

# ============================================================
# CHECK 7 (TypeScript): Paginated data aggregated locally instead of server total
# Stats computed from data.items[] (1 page) instead of server-level count.
# ============================================================
if [ "$RUN_TS_STATS" -eq 1 ] && { [ "$PROFILE" = "deep" ] || [ "$PROFILE" = "exhaustive" ]; }; then
  while IFS=: read -r file line match; do
    [ -z "$file" ] && continue
    [ -z "$line" ] && continue
    if echo "$file" | grep -qE "$EXCLUDE"; then continue; fi
    if echo "$file" | grep -qE '(__tests__|\.spec\.|\.test\.)'; then continue; fi
    # Only flag if reduce/length is on .items (paginated) and result used in UI display
    if echo "$match" | grep -qE '(\.items|\.data|\.results)\.(filter|reduce|length)\b'; then
      s=$(EMIT "Possible paginated-data aggregation (TypeScript)" \
        "Tinh toan aggregate (filter/reduce/length) tren .items[] — neu day la paginated response, ket qua chi phan anh trang hien tai (max 20-50 items), khong phai tong server. Stats hien thi tren UI co the sai lech nghiem trong voi dataset lon." \
        "medium" "$file" "$line" \
        "Kiem tra API response schema: neu co totalCount, totalBudget, aggregates server-side → dung chung thay vi tinh tu .items[]. Neu khong co → them comment ro rang limitation va TODO endpoint aggregation.")
      SIGNALS_JSON=$(echo "$SIGNALS_JSON" | jq --argjson sig "$s" '. + [$sig]')
    fi
  done < <(grep -rEn '\.(filter|reduce)\(|\.items\.\(length\)' "$SOURCE_DIR" \
    --include='*.tsx' --include='*.ts' 2>/dev/null | head -50 || true)
fi

# Emit final
# Fix F1 (Windows ARG_MAX): dùng --slurpfile thay --argjson cho SIGNALS_JSON lớn (>30KB)
__SIGNALS_TMPFILE="$(mktemp)"
printf '%s' "$SIGNALS_JSON" > "$__SIGNALS_TMPFILE"
jq -nc \
  --arg lane "$LANE" --arg probe "$PROBE_ID" --arg pver "$PROBE_VERSION" \
  --arg profile "$PROFILE" --arg now "$(iso_now)" \
  --slurpfile sigs "$__SIGNALS_TMPFILE" \
  '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD2", probe_id: $probe,
    probe_version: $pver, profile: $profile, generated_at: $now,
    signals: $sigs[0]}'
__JQ_RC=$?
rm -f "$__SIGNALS_TMPFILE"
exit $__JQ_RC
