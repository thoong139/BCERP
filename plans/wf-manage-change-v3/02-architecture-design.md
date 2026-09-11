# 02 — Thiết Kế Kiến Trúc Target (v3.0)

> **Phiên bản:** v0.1 — 2026-04-29
> **Mục đích:** Schemas đầy đủ, file layout, bash script samples, session structure cho v3.0

---

## 1. File Layout Target

```
.claude/skills/workflow/wf-manage-change/
├── SKILL.md                          # UPDATE: thêm lock refs, protocol refs
├── _contract.json                    # UPDATE: bump 3.0.0, thêm change-impact.json
├── evals/
│   └── evals.json                    # UPDATE: thêm 3+ test cases
├── templates/
│   ├── index.json                    # Giữ nguyên
│   ├── change-status.json            # UPDATE: thêm fields (retry_count, legacy_mode, etc.)
│   ├── change-intake.json            # UPDATE: thêm classification_rationale
│   ├── change-analysis.md            # Giữ nguyên
│   ├── affected-artifacts.json       # Giữ nguyên
│   ├── impact-report.md              # Giữ nguyên
│   ├── change-plan.md                # UPDATE: thêm change_id vào header
│   ├── change-report.md              # Giữ nguyên
│   ├── checkpoint.json               # Giữ nguyên
│   ├── phase-summary.md              # MỚI: minimal template (CORE-031)
│   └── change-impact.json            # MỚI: cross-skill artifact template
└── procedures/
    ├── _shared.md                    # UPDATE: bỏ resume routing (tách ra)
    ├── resume-routing.md             # MỚI: tách từ _shared.md
    ├── phase0-intake.md              # UPDATE: gọi bash scripts
    ├── phase1-analyze.md             # UPDATE: gọi bash scripts
    ├── phase2-impact.md              # UPDATE: gọi bash scripts
    ├── phase3-plan.md                # UPDATE: gọi bash scripts
    ├── phase4a-registry-docs.md      # UPDATE: lock + bash scripts
    ├── phase4b-code.md               # UPDATE: lock + bash scripts
    ├── phase4c-tests.md              # UPDATE: gọi bash scripts
    ├── phase5-verify.md              # UPDATE: gọi bash scripts
    └── phase6-report.md              # UPDATE: change-impact.json + bash scripts

.claude/scripts/wf-manage-change/       # MỚI: 10 bash scripts
├── mc-common.sh
├── mc-generate-session-id.sh
├── mc-acquire-lock.sh
├── mc-release-lock.sh
├── mc-heartbeat.sh
├── mc-backup-registry.sh
├── mc-validate-registry.sh
├── mc-safety-check.sh
├── mc-index-append.sh
├── mc-change-impact-build.sh
└── mc-postgate-check.sh

.mc-data/work/wf-manage-change/         # Runtime layout
├── _index/
│   └── sessions.jsonl                  # MỚI: append-only session index
├── .locks/
│   └── registry.lock                   # MỚI: cross-session registry lock
├── index.json                          # Giữ: --status display (dual-write)
└── $CHANGE_ID/
    ├── .session.lock                   # MỚI: per-session lock
    ├── change-status.json
    ├── change-intake.json
    ├── change-analysis.md
    ├── affected-artifacts.json
    ├── impact-report.md
    ├── change-plan.md
    ├── change-report.md
    ├── phase-summary.md
    ├── checkpoint.json
    └── change-impact.json              # MỚI: cross-skill artifact
```

---

## 2. Session Structure Mới

### 2.1 Session ID Format

```
Format: CHG-YYYYMMDD-NNN
VD:     CHG-20260429-001, CHG-20260429-002
```

Giữ nguyên format hiện tại (đúng quy ước MCV3). Bổ sung retry loop trong script.

### 2.2 Lock Files

**`.session.lock` (per-session):**
```json
{
  "change_id": "CHG-20260429-001",
  "pid": 12345,
  "host": "dev-machine-01",
  "user": "alice",
  "started_at": "2026-04-29T10:30:00Z",
  "heartbeat_at": "2026-04-29T10:35:30Z",
  "heartbeat_interval_sec": 30
}
```

**`registry.lock` (cross-session):**
```json
{
  "locked_by": "CHG-20260429-001",
  "pid": 12345,
  "host": "dev-machine-01",
  "user": "alice",
  "locked_at": "2026-04-29T10:40:00Z",
  "purpose": "registry_update_phase4a"
}
```

### 2.3 sessions.jsonl

Append-only, mỗi dòng 1 JSON entry:

```jsonl
{"change_id":"CHG-20260429-001","status":"in_progress","created_at":"2026-04-29T10:30:00Z","user":"alice","host":"dev-machine-01","summary":"Thay doi cach tinh phi don hang","change_type":"MODIFY_FEATURE","risk_level":null}
{"change_id":"CHG-20260429-001","status":"completed","completed_at":"2026-04-29T11:15:00Z","risk_level":"MEDIUM","files_changed":5}
{"change_id":"CHG-20260429-002","status":"in_progress","created_at":"2026-04-29T14:00:00Z","user":"bob","host":"dev-machine-02","summary":"Bo sung xac thuc 2 lop","change_type":"ADD_FEATURE","risk_level":null}
```

**Operations:**
- Append: `echo '{...}' >> .mc-data/work/wf-manage-change/_index/sessions.jsonl`
- Lookup: `grep '"change_id":"CHG-20260429-001"' .mc-data/work/wf-manage-change/_index/sessions.jsonl`
- Status update: append new line (immutable log — không modify existing lines)

---

## 3. Bash Scripts Design

### 3.1 mc-common.sh — Shared Helpers

```bash
#!/usr/bin/env bash
# mc-common.sh — Shared helpers cho wf-manage-change scripts
set -euo pipefail

MC_ROOT=".mc-data/work/wf-manage-change"
MC_INDEX="$MC_ROOT/_index/sessions.jsonl"
MC_LOCKS_DIR="$MC_ROOT/.locks"

# Colors cho output
MC_RED='\033[0;31m'
MC_YELLOW='\033[1;33m'
MC_GREEN='\033[0;32m'
MC_NC='\033[0m'

mc_log() { echo -e "${MC_GREEN}[wf-manage-change]${MC_NC} $*"; }
mc_warn() { echo -e "${MC_YELLOW}[WARN]${MC_NC} $*" >&2; }
mc_err() { echo -e "${MC_RED}[ERROR]${MC_NC} $*" >&2; }

# Timestamp ISO-8601
mc_timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# jq wrapper — validate JSON
mc_jq_validate() {
  local file="$1"
  jq '.' "$file" > /dev/null 2>&1
}

# Registry path
mc_registry_path() { echo ".mc-data/docs/_meta/req-registry.json"; }

# Ensure directories exist
mc_ensure_dirs() {
  mkdir -p "$MC_ROOT/_index"
  mkdir -p "$MC_ROOT/.locks"
}

# Get current user/host
mc_identity() {
  local user="${USER:-${USERNAME:-unknown}}"
  local host="$(hostname 2>/dev/null || echo 'unknown')"
  echo "${user}@${host}"
}

# Get current PID
mc_pid() { echo "$$"; }
```

### 3.2 mc-generate-session-id.sh

```bash
#!/usr/bin/env bash
# mc-generate-session-id.sh — Generate unique session ID with retry loop
source "$(dirname "$0")/mc-common.sh"

mc_ensure_dirs

DATE=$(date +%Y%m%d)
MAX_RETRIES=10
SLEEP_SEC=0.05

for attempt in $(seq 1 $MAX_RETRIES); do
  CANDIDATE="CHG-${DATE}-$(printf '%03d' $attempt)"

  # Check trong sessions.jsonl
  if [ -f "$MC_INDEX" ]; then
    if grep -q "\"change_id\":\"${CANDIDATE}\"" "$MC_INDEX" 2>/dev/null; then
      continue  # Da ton tai, thu tiep
    fi
  fi

  # Check trong index.json (dual-write compat)
  if [ -f "$MC_ROOT/index.json" ]; then
    if jq -e --arg id "$CANDIDATE" '.sessions[] | select(.change_id == $id)' \
         "$MC_ROOT/index.json" > /dev/null 2>&1; then
      continue
    fi
  fi

  # Unique!
  echo "$CANDIDATE"
  exit 0
done

mc_err "Khong the generate unique session ID sau $MAX_RETRIES lan thu"
exit 1
```

### 3.3 mc-acquire-lock.sh

```bash
#!/usr/bin/env bash
# mc-acquire-lock.sh — Acquire lock (session or registry)
# Usage: mc-acquire-lock.sh --type=session --id=CHG-20260429-001
#        mc-acquire-lock.sh --type=registry --id=CHG-20260429-001
source "$(dirname "$0")/mc-common.sh"

TYPE=""  # session | registry
ID=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --type=*) TYPE="${1#*=}"; shift ;;
    --id=*)   ID="${1#*=}"; shift ;;
    *) shift ;;
  esac
done

if [[ -z "$TYPE" || -z "$ID" ]]; then
  mc_err "Usage: mc-acquire-lock.sh --type=session|registry --id=CHANGE_ID"
  exit 1
fi

mc_ensure_dirs

if [[ "$TYPE" == "session" ]]; then
  LOCK_FILE="$MC_ROOT/$ID/.session.lock"
  mkdir -p "$MC_ROOT/$ID"
elif [[ "$TYPE" == "registry" ]]; then
  LOCK_FILE="$MC_LOCKS_DIR/registry.lock"
else
  mc_err "Invalid lock type: $TYPE"
  exit 1
fi

STALE_MINUTES=${MCV3_LOCK_STALE_MINUTES:-60}

# Check existing lock
if [[ -f "$LOCK_FILE" ]]; then
  LOCK_AGE_MIN=$(( ( $(date +%s) - $(jq -r '.started_at // .locked_at' "$LOCK_FILE" | xargs date +%s -d 2>/dev/null || echo 0) ) / 60 ))

  if [[ $LOCK_AGE_MIN -lt $STALE_MINUTES ]]; then
    # Lock còn active
    LOCK_HOST=$(jq -r '.host // "unknown"' "$LOCK_FILE")
    LOCK_USER=$(jq -r '.user // "unknown"' "$LOCK_FILE")
    LOCK_PID=$(jq -r '.pid // 0' "$LOCK_FILE")
    mc_err "Lock active: $LOCK_FILE (owner: ${LOCK_USER}@${LOCK_HOST}, PID: $LOCK_PID, age: ${LOCK_AGE_MIN}min)"
    mc_err "Neu lock bay, xoa thu cong hoac doi $STALE_MINUTES phut"
    exit 1
  else
    mc_warn "Stale lock detected (${LOCK_AGE_MIN}min > ${STALE_MINUTES}min) — taking over"
    rm -f "$LOCK_FILE"
  fi
fi

# Write lock
IDENTITY=$(mc_identity)
PID=$(mc_pid)
TIMESTAMP=$(mc_timestamp)

LOCK_JSON=$(jq -n \
  --arg id "$ID" \
  --arg pid "$PID" \
  --arg host "$(hostname 2>/dev/null || echo 'unknown')" \
  --arg user "${USER:-${USERNAME:-unknown}}" \
  --arg ts "$TIMESTAMP" \
  --arg interval "30" \
  '{change_id: $id, pid: ($pid|tonumber), host: $host, user: $user, started_at: $ts, heartbeat_at: $ts, heartbeat_interval_sec: ($interval|tonumber)}'
)

if [[ "$TYPE" == "registry" ]]; then
  LOCK_JSON=$(echo "$LOCK_JSON" | jq --arg purpose "registry_update" '{locked_by: .change_id, pid, host, user, locked_at: .started_at, purpose: $purpose}')
fi

echo "$LOCK_JSON" > "$LOCK_FILE"
mc_log "Lock acquired: $LOCK_FILE"
```

### 3.4 mc-release-lock.sh

```bash
#!/usr/bin/env bash
# mc-release-lock.sh — Release lock
# Usage: mc-release-lock.sh --type=session --id=CHG-20260429-001
source "$(dirname "$0")/mc-common.sh"

TYPE="${1#--type=}" ; shift
ID="${1#--id=}" ; shift

if [[ "$TYPE" == "session" ]]; then
  LOCK_FILE="$MC_ROOT/$ID/.session.lock"
elif [[ "$TYPE" == "registry" ]]; then
  LOCK_FILE="$MC_LOCKS_DIR/registry.lock"
fi

if [[ -f "$LOCK_FILE" ]]; then
  rm -f "$LOCK_FILE"
  mc_log "Lock released: $LOCK_FILE"
else
  mc_warn "Lock not found: $LOCK_FILE"
fi
```

### 3.5 mc-heartbeat.sh

```bash
#!/usr/bin/env bash
# mc-heartbeat.sh — Background heartbeat daemon
# Usage: mc-heartbeat.sh --id=CHG-20260429-001 &
source "$(dirname "$0")/mc-common.sh"

ID="${1#--id=}"
LOCK_FILE="$MC_ROOT/$ID/.session.lock"
INTERVAL=30

while true; do
  sleep $INTERVAL
  if [[ -f "$LOCK_FILE" ]]; then
    TIMESTAMP=$(mc_timestamp)
    jq --arg ts "$TIMESTAMP" '.heartbeat_at = $ts' "$LOCK_FILE" > "${LOCK_FILE}.tmp"
    mv "${LOCK_FILE}.tmp" "$LOCK_FILE"
  else
    # Lock da bi xoa — stop heartbeat
    exit 0
  fi
done
```

### 3.6 mc-backup-registry.sh

```bash
#!/usr/bin/env bash
# mc-backup-registry.sh — Backup registry with timestamp + checksum
source "$(dirname "$0")/mc-common.sh"

REGISTRY=$(mc_registry_path)
TIMESTAMP=$(date +%s)
BACKUP="${REGISTRY}.pre-change-${TIMESTAMP}"

if [[ ! -f "$REGISTRY" ]]; then
  mc_err "Registry not found: $REGISTRY"
  exit 1
fi

cp "$REGISTRY" "$BACKUP"

# Compute checksum
CHECKSUM=$(sha256sum "$BACKUP" | cut -d' ' -f1)

mc_log "Registry backed up: $BACKUP"
mc_log "SHA256: $CHECKSUM"

# Output JSON cho AI consume
jq -n --arg path "$BACKUP" --arg checksum "$CHECKSUM" --arg ts "$TIMESTAMP" \
  '{backup_path: $path, checksum: $checksum, timestamp: ($ts|tonumber)}'
```

### 3.7 mc-validate-registry.sh

```bash
#!/usr/bin/env bash
# mc-validate-registry.sh — Validate registry JSON + content
source "$(dirname "$0")/mc-common.sh"

REGISTRY=$(mc_registry_path)

if [[ ! -f "$REGISTRY" ]]; then
  mc_err "Registry not found: $REGISTRY"
  exit 1
fi

# T1: File exists (pass)

# T2: Non-empty
SIZE=$(wc -c < "$REGISTRY")
if [[ $SIZE -eq 0 ]]; then
  mc_err "Registry is empty"
  exit 1
fi

# T3: Valid JSON
if ! mc_jq_validate "$REGISTRY"; then
  mc_err "Registry JSON invalid"
  exit 1
fi

# T4: Content checks
REQ_COUNT=$(jq '.requirements | length' "$REGISTRY")
if [[ $REQ_COUNT -eq 0 ]]; then
  mc_err "Registry has no requirements"
  exit 1
fi

echo "{\"valid\":true,\"requirements_count\":$REQ_COUNT,\"size_bytes\":$SIZE}"
```

### 3.8 mc-safety-check.sh

```bash
#!/usr/bin/env bash
# mc-safety-check.sh — Pre-execution safety gate
# Usage: mc-safety-check.sh --session-dir=.mc-data/work/wf-manage-change/CHG-20260429-001
source "$(dirname "$0")/mc-common.sh"

SESSION_DIR=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --session-dir=*) SESSION_DIR="${1#*=}"; shift ;;
    *) shift ;;
  esac
done

GATES_PASSED=true
BLOCKERS=()
WARNINGS=()

# Check 1: Registry valid
REGISTRY=$(mc_registry_path)
if ! mc_jq_validate "$REGISTRY"; then
  BLOCKERS+=("Registry JSON invalid")
  GATES_PASSED=false
fi

# Check 2: No uncommitted changes in target files
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  if [[ -f "$SESSION_DIR/affected-artifacts.json" ]]; then
    while IFS= read -r file; do
      if git diff --quiet "$file" 2>/dev/null; then
        : # clean
      else
        WARNINGS+=("Uncommitted changes: $file")
      fi
    done < <(jq -r '.code_affected[].path' "$SESSION_DIR/affected-artifacts.json" 2>/dev/null)
  fi
fi

# Check 3: Registry xref — affected REQ-IDs exist
if [[ -f "$SESSION_DIR/affected-artifacts.json" ]]; then
  while IFS= read -r req_id; do
    if ! jq -e --arg id "$req_id" '.requirements[] | select(.id == $id)' "$REGISTRY" > /dev/null 2>&1; then
      WARNINGS+=("REQ-ID not found in registry: $req_id")
    fi
  done < <(jq -r '.registry_changes.requirements_to_update[]?' "$SESSION_DIR/affected-artifacts.json" 2>/dev/null)
fi

# Output
jq -n \
  --argjson passed "$GATES_PASSED" \
  --argjson blockers "$(printf '%s\n' "${BLOCKERS[@]}" | jq -R . | jq -s .)" \
  --argjson warnings "$(printf '%s\n' "${WARNINGS[@]}" | jq -R . | jq -s .)" \
  '{gates_passed: $passed, blockers: $blockers, warnings: $warnings}'
```

### 3.9 mc-index-append.sh

```bash
#!/usr/bin/env bash
# mc-index-append.sh — Append entry to sessions.jsonl
# Usage: mc-index-append.sh --change-id=CHG-001 --status=in_progress --summary="..."
source "$(dirname "$0")/mc-common.sh"

mc_ensure_dirs

CHANGE_ID="" STATUS="" SUMMARY="" CHANGE_TYPE="" RISK_LEVEL=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --change-id=*)    CHANGE_ID="${1#*=}"; shift ;;
    --status=*)       STATUS="${1#*=}"; shift ;;
    --summary=*)      SUMMARY="${1#*=}"; shift ;;
    --change-type=*)  CHANGE_TYPE="${1#*=}"; shift ;;
    --risk-level=*)   RISK_LEVEL="${1#*=}"; shift ;;
    *) shift ;;
  esac
done

IDENTITY=$(mc_identity)
USER=$(echo "$IDENTITY" | cut -d'@' -f1)
HOST=$(echo "$IDENTITY" | cut -d'@' -f2)
TIMESTAMP=$(mc_timestamp)

ENTRY=$(jq -n \
  --arg cid "$CHANGE_ID" \
  --arg status "$STATUS" \
  --arg ts "$TIMESTAMP" \
  --arg user "$USER" \
  --arg host "$HOST" \
  --arg summary "$SUMMARY" \
  --arg ctype "$CHANGE_TYPE" \
  --arg risk "$RISK_LEVEL" \
  '{change_id: $cid, status: $status, created_at: $ts, user: $user, host: $host, summary: $summary, change_type: $ctype, risk_level: $risk}'
)

echo "$ENTRY" >> "$MC_INDEX"
```

### 3.10 mc-change-impact-build.sh

```bash
#!/usr/bin/env bash
# mc-change-impact-build.sh — Build change-impact.json artifact
# Usage: mc-change-impact-build.sh --session-dir=$SESSION_DIR
source "$(dirname "$0")/mc-common.sh"

SESSION_DIR=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --session-dir=*) SESSION_DIR="${1#*=}"; shift ;;
    *) shift ;;
  esac
done

# Read session data
CHANGE_ID=$(jq -r '.change_id' "$SESSION_DIR/change-status.json")
CHANGE_TYPE=$(jq -r '.intake.change_type_confirmed // .intake.change_type_preliminary' "$SESSION_DIR/change-status.json")
RISK_LEVEL=$(jq -r '.impact_summary.risk_level // "UNKNOWN"' "$SESSION_DIR/change-status.json")

# Build registry_changes from affected-artifacts.json
REGISTRY_CHANGES=$(jq '{
  requirements_updated: (.registry_changes.requirements_to_update // []),
  requirements_added: (.registry_changes.requirements_to_add // []),
  features_updated: (.registry_changes.features_to_update // []),
  features_added: (.registry_changes.features_to_add // []),
  features_deleted: (.registry_changes.features_to_delete // []),
  impl_status_changes: (.registry_changes.impl_status_updates // [])
}' "$SESSION_DIR/affected-artifacts.json" 2>/dev/null || echo '{}')

# Build files_modified from change-status
FILES_MODIFIED=$(jq -r '.phase4b.files_updated // [] | if type == "array" then . else [] end' "$SESSION_DIR/change-status.json" 2>/dev/null || echo '[]')

# Build docs_modified
DOCS_MODIFIED=$(jq -r '.phase4a.files_updated // [] | if type == "number" then [] else . end' "$SESSION_DIR/change-status.json" 2>/dev/null || echo '[]')

# Checksum
REGISTRY=$(mc_registry_path)
CHECKSUM_POST=""
if [[ -f "$REGISTRY" ]]; then
  CHECKSUM_POST=$(sha256sum "$REGISTRY" | cut -d' ' -f1)
fi

# Find backup
BACKUP_PATH=$(ls -t "${REGISTRY}.pre-change-"* 2>/dev/null | head -1)
CHECKSUM_PRE=""
if [[ -n "$BACKUP_PATH" ]]; then
  CHECKSUM_PRE=$(sha256sum "$BACKUP_PATH" | cut -d' ' -f1)
fi

# Build output
jq -n \
  --arg schema "change-impact-v1" \
  --arg cid "$CHANGE_ID" \
  --arg ctype "$CHANGE_TYPE" \
  --arg risk "$RISK_LEVEL" \
  --argjson reg_changes "$REGISTRY_CHANGES" \
  --argjson files "$FILES_MODIFIED" \
  --argjson docs "$DOCS_MODIFIED" \
  --arg pre_checksum "$CHECKSUM_PRE" \
  --arg post_checksum "$CHECKSUM_POST" \
  --arg backup "$BACKUP_PATH" \
  '{
    "$schema": $schema,
    change_id: $cid,
    change_type: $ctype,
    risk_level: $risk,
    registry_changes: $reg_changes,
    files_modified: $files,
    docs_modified: $docs,
    verify_evidence: { preflight_status: null, sync_rate: null, cross_validation_coverage: null },
    regression_check: { tests_passed: null, tests_failed: null, tests_total: null },
    audit_chain: { checksum_pre: $pre_checksum, checksum_post: $post_checksum, backup_path: $backup },
    generated_at: (now | todate)
  }' > "$SESSION_DIR/change-impact.json"

mc_log "change-impact.json built: $SESSION_DIR/change-impact.json"
```

### 3.11 mc-postgate-check.sh

```bash
#!/usr/bin/env bash
# mc-postgate-check.sh — T1→T4 validation cho bất kỳ phase
# Usage: mc-postgate-check.sh --file=$SESSION_DIR/change-status.json --type=json
#        mc-postgate-check.sh --file=$SESSION_DIR/change-report.md --type=markdown --headings="## Summary,## Changes Made"
source "$(dirname "$0")/mc-common.sh"

FILE="" TYPE="" HEADINGS=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --file=*)     FILE="${1#*=}"; shift ;;
    --type=*)     TYPE="${1#*=}"; shift ;;
    --headings=*) HEADINGS="${1#*=}"; shift ;;
    *) shift ;;
  esac
done

RESULTS=()
ALL_PASS=true

# T1: File exists
if [[ ! -f "$FILE" ]]; then
  echo '{"t1_existence":false,"t2_nonempty":false,"t3_format":false,"t4_content":false,"pass":false,"error":"File not found"}'
  exit 1
fi
RESULTS+=('"t1_existence":true')

# T2: Non-empty
SIZE=$(wc -c < "$FILE")
if [[ $SIZE -eq 0 ]]; then
  RESULTS+=('"t2_nonempty":false')
  ALL_PASS=false
else
  RESULTS+=('"t2_nonempty":true')
fi

# T3: Format
if [[ "$TYPE" == "json" ]]; then
  if mc_jq_validate "$FILE"; then
    RESULTS+=('"t3_format":true')
  else
    RESULTS+=('"t3_format":false')
    ALL_PASS=false
  fi
elif [[ "$TYPE" == "markdown" ]]; then
  RESULTS+=('"t3_format":true')  # MD format check via headings below
fi

# T4: Content (headings for markdown, fields for JSON)
if [[ -n "$HEADINGS" ]]; then
  T4_PASS=true
  MISSING=()
  IFS=',' read -ra HEADS <<< "$HEADINGS"
  for h in "${HEADS[@]}"; do
    if ! grep -q "$h" "$FILE"; then
      MISSING+=("$h")
      T4_PASS=false
    fi
  done
  if $T4_PASS; then
    RESULTS+=('"t4_content":true')
  else
    RESULTS+=('"t4_content":false')
    ALL_PASS=false
    mc_warn "Missing headings: ${MISSING[*]}"
  fi
else
  RESULTS+=('"t4_content":true')  # Skip T4 if no headings specified
fi

# Output
if $ALL_PASS; then
  RESULTS+=('"pass":true')
else
  RESULTS+=('"pass":false')
fi

echo "{${RESULTS[*]}}"
```

---

## 4. change-impact.json Schema (MỚI)

```json
{
  "$schema": "change-impact-v1",
  "change_id": "CHG-YYYYMMDD-NNN",
  "change_type": "MODIFY_FEATURE | MODIFY_REQUIREMENT | ADD_FEATURE | DELETE_FEATURE | CLARIFY_REQ",
  "risk_level": "LOW | MEDIUM | HIGH",

  "registry_changes": {
    "requirements_updated": ["REQ-SALES-001"],
    "requirements_added": [],
    "features_updated": ["FEAT-CRM-CUST-001"],
    "features_added": [],
    "features_deleted": [],
    "impl_status_changes": [
      {
        "feat_id": "FEAT-CRM-CUST-001",
        "from": "done",
        "to": "in_progress",
        "reason": "Modified fee calculation logic"
      }
    ]
  },

  "files_modified": [
    "src/sales/order.service.ts",
    "src/sales/fee-calculator.service.ts"
  ],

  "docs_modified": [
    ".mc-data/docs/phase2-features/sales/orders/fee-calculation.md",
    ".mc-data/docs/phase3-architecture/..."
  ],

  "verify_evidence": {
    "preflight_status": "PASS | WARN | FAIL",
    "sync_rate": 0.97,
    "cross_validation_coverage": 0.95
  },

  "regression_check": {
    "tests_passed": 12,
    "tests_failed": 0,
    "tests_total": 12
  },

  "audit_chain": {
    "checksum_pre": "sha256:abcdef...",
    "checksum_post": "sha256:fedcba...",
    "backup_path": ".mc-data/docs/_meta/req-registry.json.pre-change-1745900000"
  },

  "generated_at": "2026-04-29T11:15:00Z"
}
```

**Cross-skill consumers:**

| Consumer | Fields consumed | Flag |
|----------|----------------|------|
| `/wf-verify-sync` | `registry_changes`, `files_modified` | `--from-manage-change[=<id>]` |
| `/wf-preflight` | `files_modified`, `verify_evidence` | (inform) |
| `/wf-implement-feature` | `files_modified` | (Phase 0 context priming) |

---

## 5. Template Updates

### 5.1 templates/phase-summary.md (MỚI)

```markdown
---
$schema: phase-summary-v1
change_id: CHG-YYYYMMDD-NNN
skill: wf-manage-change
---

# Tom tat thay doi — {CHANGE_ID}

## Da thay doi gi?
[Mo ta ngan bang ngon ngu nghiep vu — KHONG dung thuat ngu ky thuat]
<!-- POPULATE: Mo ta cu the nhung gi da thay doi -->

## Tai sao can thay doi?
[Context tu user prompt ban dau]
<!-- POPULATE: Copy tu change-intake.json.user_prompt -->

## Ket qua kiem tra
- Preflight: [PASS/WARN/FAIL]
- Traceability: [sync_rate %]
- Cross-validation: [coverage %]
<!-- POPULATE: Tu change-status.json.phase5 -->

## Nhung file bi anh huong
- [N] tai lieu cap nhat
- [N] file code cap nhat
- [N] test cap nhat
<!-- POPULATE: Tu change-status.json.metrics -->

## Buoc tiep theo
[Khuyen nghi cu the cho user]
<!-- POPULATE: Tu Phase 6 Next Step Recommendation -->
```

### 5.2 templates/change-plan.md — thêm change_id

Thêm dòng vào header table:
```markdown
| **Change ID** | $CHANGE_ID |
```

### 5.3 templates/change-status.json — thêm fields

```json
{
  ...existing fields...,
  "phase2_retry_count": 0,
  "intake": {
    ...existing fields...,
    "deprecated_modules": [],
    "legacy_mode": false,
    "referenced_artifacts": {
      "systems": [],
      "modules": [],
      "features": [],
      "req_ids": []
    }
  }
}
```

### 5.4 templates/change-impact.json (MỚI)

Xem §4 phía trên — full schema.

---

## 6. Phase File Update Patterns

### 6.1 Pattern: Inline → Script Call

**TRƯỚC (inline trong phase0-intake.md):**
```markdown
| 0.1 | Generate session ID: CHANGE_DATE=$(date +%Y%m%d) → đếm sessions
       → NNN = count + 1 → CHANGE_ID = CHG-$CHANGE_DATE-$(printf "%03d" $NNN)
       → Anti-collision check... | Bash | ...
```

**SAU (script delegation):**
```markdown
| 0.1 | **Generate session ID:** `CHANGE_ID=$(bash .claude/scripts/wf-manage-change/mc-generate-session-id.sh)` | Bash | $CHANGE_ID non-empty, unique |
```

### 6.2 Pattern: Lock Guard around Registry Write

**TRƯỚC (phase4a-registry-docs.md Step 4a.5):**
```markdown
| 4a.5 | Registry update (nếu cần): ĐỌC registry → apply safe-write → atomic write → jq validate | Read/Write | ...
```

**SAU (lock-guarded):**
```markdown
| 4a.5a | **Acquire registry lock:** `bash .claude/scripts/wf-manage-change/mc-acquire-lock.sh --type=registry --id=$CHANGE_ID` | Bash | Lock acquired |
| 4a.5b | **Registry update:** ĐỌC registry → apply safe-write → `bash .claude/scripts/wf-manage-change/mc-validate-registry.sh` → atomic write | Read/Write | jq valid |
| 4a.5c | **Release registry lock:** `bash .claude/scripts/wf-manage-change/mc-release-lock.sh --type=registry --id=$CHANGE_ID` | Bash | Lock released |
```

### 6.3 Pattern: T1-T4 Delegation

**TRƯỚC (inline trong mỗi phase POST-GATE):**
```markdown
T1: test -f $SESSION_DIR/change-status.json
T2: test -s $SESSION_DIR/change-status.json
T3: jq '.' $SESSION_DIR/change-status.json
T4: jq -e '.change_type_preliminary != null' $SESSION_DIR/change-intake.json
```

**SAU (script call):**
```markdown
bash .claude/scripts/wf-manage-change/mc-postgate-check.sh \
  --file=$SESSION_DIR/change-status.json --type=json
bash .claude/scripts/wf-manage-change/mc-postgate-check.sh \
  --file=$SESSION_DIR/change-intake.json --type=json
```
