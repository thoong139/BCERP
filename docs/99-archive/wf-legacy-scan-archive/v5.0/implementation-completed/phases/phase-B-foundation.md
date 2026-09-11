# Phase B — Foundation

> **Mục tiêu:** Xây dựng infrastructure foundation (scan-state.json canonical, session isolation, bash shared library) mà KHÔNG thay đổi behaviour v4.1.
> **Duration:** 2-3 ngày
> **Dependencies:** Phase A complete (design approved + fixtures + templates)
> **Tag khi xong:** `v5.0-phase-B`
> **Rollback:** Xóa `sessions/` directory + revert procedure changes; scripts vẫn chạy như v4.1.

---

## Prerequisites

- [ ] Phase A tagged `design-legacy-scan-v2.1-approved`
- [ ] 7 template skeletons từ A.6 exist
- [ ] IPS Python module skeleton từ A.7 exist
- [ ] Branch `feat/wf-legacy-scan-v5.0-phase-b` created from main

---

## Tasks Overview

| ID | Task | Priority | Duration | Status |
|----|------|----------|----------|--------|
| B.1 | Complete 7 template schemas (populate từ A.6 skeletons) | HIGH | 3-4 giờ | ⬜ |
| B.2 | Create bash shared library `legacy-scan-common.sh` | HIGH | 4-5 giờ | ⬜ |
| B.3 | Session infrastructure (file-lock, session dir creation) | HIGH | 3-4 giờ | ⬜ |
| B.4 | scan-state.json canonical write + read helpers | CRITICAL | 3-4 giờ | ⬜ |
| B.5 | ledger.json backward-compat generation (single-shot) | HIGH | 2-3 giờ | ⬜ |
| B.6 | Integration smoke test on small-en fixture | CRITICAL | 2-3 giờ | ⬜ |

---

## Task B.1 — Complete 7 Template Schemas

**Priority:** HIGH · **Duration:** 3-4 giờ · **Status:** ⬜

### Actions

Populate full schemas cho 7 templates (Phase A đã tạo skeleton):

1. **`scan-state.json`** — đã tạo full trong A.6. Verify + add example values.
2. **`domain-hints.json`** — populate với `detected_domains`, `signals`, `all_signals` structure từ [04 §2.1](../../04-data-model.md).
3. **`impact-graph.json`** — populate với `nodes`, `edges`, `circular_dependencies`, `orphan_modules`, `summary` từ [04 §2.2](../../04-data-model.md).
4. **`phase-summary.md`** — template markdown cho CORE-028.
5. **`scan-plan.md`** — template markdown cho execution plan per session.
6. **`fix-workload.json`** (stub v5.1) — minimal schema với `$schema: fix-workload-v1` + `status: deferred-v5.1`.
7. **`vietnamese-keywords.json`** — populate full với 14 domains × ~8 keywords từ [10 §2](../../10-vietnamese-keywords.md).

### Verify

```bash
# All JSON templates valid
for t in scan-state domain-hints impact-graph fix-workload; do
  jq empty .claude/skills/workflow/wf-legacy-scan/templates/${t}.json
done
jq empty .claude/skills/workflow/_shared/ips/vietnamese-keywords.json

# vietnamese-keywords.json có đủ 14 domains
jq '.domains | keys | length' .claude/skills/workflow/_shared/ips/vietnamese-keywords.json
# Expected: 14

# Total keywords
jq '[.domains[].keywords[]] | length' .claude/skills/workflow/_shared/ips/vietnamese-keywords.json
# Expected: ~110
```

### Acceptance Criteria

- [ ] 5 JSON templates valid với đầy đủ fields theo design
- [ ] 2 MD templates có structure sections
- [ ] `vietnamese-keywords.json` có 14 domains + ~110 keywords
- [ ] Sample data trong templates match examples trong design docs

---

## Task B.2 — Bash Shared Library `legacy-scan-common.sh`

**Priority:** HIGH · **Duration:** 4-5 giờ · **Status:** ⬜

### Actions

Tạo `.claude/scripts/legacy-scan-common.sh` theo [06-bash-scripts.md §2](../../06-bash-scripts.md):

```bash
#!/usr/bin/env bash
# legacy-scan-common.sh — Shared library cho wf-legacy-scan bash scripts
# Version: 1.0
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/legacy-scan-common.sh"

set -euo pipefail 2>/dev/null || set -e

# ─── Constants ───
readonly LEGACY_SCAN_COMMON_VERSION="1.0"
readonly DEFAULT_EXCLUDE_DIRS=(
  node_modules .git dist build .next .nuxt out coverage
  .cache .turbo vendor __pycache__ .venv venv .idea .vscode
  bin obj Debug Release packages .gradle .mvn target tmp
)

# Configurable caps (env var overrides)
readonly MAX_API_ENDPOINTS="${LEGACY_SCAN_MAX_API:-500}"
readonly MAX_SCREENS="${LEGACY_SCAN_MAX_SCREENS:-500}"
readonly MAX_IMPORTS_PER_FILE="${LEGACY_SCAN_MAX_IMPORTS:-20}"
readonly MAX_IMPORT_FILES="${LEGACY_SCAN_MAX_FILES:-200}"
readonly MAX_DOC_FILES="${LEGACY_SCAN_MAX_DOC_FILES:-300}"
readonly STALE_THRESHOLD_DAYS="${LEGACY_SCAN_STALE_DAYS:-180}"
readonly CACHE_TTL_DAYS="${LEGACY_SCAN_CACHE_TTL:-14}"

# Concurrency (informational — orchestrator enforces)
readonly CONCURRENCY_GLOBAL_MAX="${LEGACY_SCAN_GLOBAL_MAX:-8}"
readonly CONCURRENCY_PER_LAYER_MAX="${LEGACY_SCAN_PER_LAYER_MAX:-3}"
readonly AGENT_TIMEOUT_SEC="${LEGACY_SCAN_AGENT_TIMEOUT_SEC:-300}"
readonly AGENT_TIMEOUT_DEEP_SEC="${LEGACY_SCAN_AGENT_TIMEOUT_DEEP_SEC:-600}"

# ─── Logging ───
log_info()  { echo "[${_SCRIPT_NAME:-scan}] INFO: $*" >&2; }
log_warn()  { echo "[${_SCRIPT_NAME:-scan}] WARN: $*" >&2; }
log_error() { echo "[${_SCRIPT_NAME:-scan}] ERROR: $*" >&2; }
log_debug() { [[ "${LEGACY_SCAN_DEBUG:-0}" == "1" ]] && echo "[${_SCRIPT_NAME:-scan}] DEBUG: $*" >&2 || true; }

# ─── Path & Platform ───
has_jq() { command -v jq &>/dev/null; }
has_python3() { command -v python3 &>/dev/null; }

normalize_path() {
  # Handle Windows (C:\ → /c/), WSL, Linux, macOS
  local p="$1"
  if [[ "$p" =~ ^[A-Za-z]:\\ ]]; then
    local drive="${p:0:1}"
    echo "/${drive,,}/${p:3//\\//}"
  else
    echo "$p"
  fi
}

# ─── JSON Helpers ───
json_escape() {
  # Safe JSON string escape
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  echo "$s"
}

validate_json() {
  # Validate JSON file using jq. Returns 0 if valid, 1 otherwise.
  local f="$1"
  if has_jq; then
    jq empty "$f" &>/dev/null
  else
    log_warn "jq not available, skipping JSON validation for $f"
    return 0
  fi
}

atomic_write_json() {
  # Write JSON atomically: tmp → fsync → rename
  local target="$1"
  local content="$2"
  local tmp="${target}.tmp.$$"
  
  echo "$content" > "$tmp"
  if has_jq; then
    if ! jq empty "$tmp" &>/dev/null; then
      log_error "Invalid JSON for $target"
      rm -f "$tmp"
      return 1
    fi
  fi
  sync "$tmp" 2>/dev/null || true
  mv "$tmp" "$target"
}

# ─── File Lock ───
flock_acquire() {
  # Acquire file lock. Returns 0 if acquired, 1 if busy.
  local lockfile="$1"
  local max_wait="${2:-0}"
  local waited=0
  
  while [[ -f "$lockfile" ]]; do
    # Check stale (>1h)
    if [[ -n "$(find "$lockfile" -mmin +60 2>/dev/null)" ]]; then
      log_warn "Stale lock detected at $lockfile, removing"
      rm -f "$lockfile"
      break
    fi
    
    if [[ $waited -ge $max_wait ]]; then
      log_error "Lock busy at $lockfile (owner: $(cat "$lockfile" 2>/dev/null || echo unknown))"
      return 1
    fi
    sleep 1
    ((waited++))
  done
  
  echo "$$ $(whoami) $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$lockfile"
  return 0
}

flock_release() {
  local lockfile="$1"
  [[ -f "$lockfile" ]] && rm -f "$lockfile"
}

# ─── Domain Detection Helpers ───
# (Placeholder — Phase C will enhance)
detect_domain_hints_en() {
  # English domain detection — existing logic from v4.1
  local project_path="$1"
  local output_json="$2"
  # TODO: implement in Phase C
  echo '{"detected_domains": [], "$schema": "domain-hints-v1"}' > "$output_json"
}

detect_domain_hints_vn() {
  # Vietnamese domain detection — calls Python module
  local project_path="$1"
  local output_json="$2"
  
  if has_python3; then
    # Phase C will implement actual calls
    echo "[Phase C TODO] Call: python -m workflow._shared.ips.vietnamese_keywords --project $project_path --output $output_json"
  else
    log_warn "python3 not available — skipping VN domain detection"
  fi
}

# ─── Cache Helpers (placeholders for Phase E) ───
cache_fingerprint() {
  local probe_id="$1"; shift
  local inputs="$*"
  # Phase E will implement SHA256 fingerprint
  echo "placeholder-fingerprint"
}

cache_lookup() {
  local fingerprint="$1"
  # Phase E will implement
  return 1  # cache miss
}

cache_store() {
  local fingerprint="$1"
  local content="$2"
  # Phase E will implement
  true
}

log_info "legacy-scan-common.sh v${LEGACY_SCAN_COMMON_VERSION} loaded"
```

### Verify

```bash
# Source test
_SCRIPT_NAME="test" source .claude/scripts/legacy-scan-common.sh
# Expected: "[test] INFO: legacy-scan-common.sh v1.0 loaded"

# Functions available
declare -F | grep -E "atomic_write_json|validate_json|flock_acquire|normalize_path" | wc -l
# Expected: 4

# Atomic write test
atomic_write_json /tmp/test-output.json '{"test": true}'
jq empty /tmp/test-output.json && echo "✓ atomic write OK"
rm /tmp/test-output.json

# File lock test
flock_acquire /tmp/test.lock 0 && echo "✓ acquire OK"
flock_acquire /tmp/test.lock 0 && echo "FAIL: should be busy" || echo "✓ busy detection OK"
flock_release /tmp/test.lock
flock_acquire /tmp/test.lock 0 && echo "✓ release OK"
flock_release /tmp/test.lock
```

### Acceptance Criteria

- [ ] File `.claude/scripts/legacy-scan-common.sh` exists ~400+ dòng
- [ ] Source without error
- [ ] 7 helper functions exported (atomic_write_json, validate_json, flock_acquire/release, normalize_path, json_escape, has_jq)
- [ ] Constants + env var defaults per [09-thresholds §2.6](../../09-thresholds-justification.md)
- [ ] Cross-platform test: source trên Git Bash + WSL (+ Linux/Mac nếu có)

---

## Task B.3 — Session Infrastructure

**Priority:** HIGH · **Duration:** 3-4 giờ · **Status:** ⬜

### Actions

Update `.claude/skills/workflow/wf-legacy-scan/procedures/phase0-detection.md` để thêm session creation logic:

```bash
# Pseudo-code cho Phase 0 init (implementation trong procedure file)

# 1. Determine SESSION_ID
SESSION_ID=$(date -u +"%Y-%m-%dT%H-%M-%S")

# 2. Acquire file-lock
source .claude/scripts/legacy-scan-common.sh
WORK_DIR=".mc-data/work/legacy-scan"
mkdir -p "$WORK_DIR"
if ! flock_acquire "$WORK_DIR/.session.lock" 0; then
  echo "Another scan session is active. Options:"
  echo "  1. Wait for it to complete"
  echo "  2. Kill the stale session (if >1h old, auto-detected)"
  echo "  3. Force unlock: rm $WORK_DIR/.session.lock"
  exit 1
fi

# 3. Create session directory
SESSION_DIR="$WORK_DIR/sessions/$SESSION_ID"
mkdir -p "$SESSION_DIR/layers/L4" "$SESSION_DIR/layers/L5" "$SESSION_DIR/cache"

# 4. Initialize scan-state.json từ template
TEMPLATE=".claude/skills/workflow/wf-legacy-scan/templates/scan-state.json"
sed \
  -e "s|{{SESSION_ID}}|$SESSION_ID|g" \
  -e "s|{{CREATED_AT}}|$(date -u +%Y-%m-%dT%H:%M:%SZ)|g" \
  -e "s|{{PROJECT_PATH}}|$PROJECT_PATH|g" \
  "$TEMPLATE" > "$SESSION_DIR/scan-state.json"

validate_json "$SESSION_DIR/scan-state.json" || { log_error "Invalid scan-state"; exit 1; }

# 5. Initialize session-log.json + error-ledger.json
echo '{"session_id": "'$SESSION_ID'", "events": []}' > "$SESSION_DIR/session-log.json"
echo '{"$schema": "error-ledger-v1", "session_id": "'$SESSION_ID'", "errors": []}' > "$SESSION_DIR/error-ledger.json"

# 6. Register cleanup trap
trap 'flock_release "$WORK_DIR/.session.lock"' EXIT

log_info "Session $SESSION_ID initialized at $SESSION_DIR"
```

### Integration Point

Sửa `.claude/skills/workflow/wf-legacy-scan/procedures/phase0-detection.md`:
- Thêm Step 0.1 "Session Init" BEFORE existing detection steps.
- Preserve all existing v4.1 behaviour downstream.

### Verify

```bash
# Test session creation trên small-en fixture
cd docs/design/skills/wf-legacy-scan/fixtures/small-en
/wf-legacy-scan .

# Check session dir created
ls -la .mc-data/work/legacy-scan/sessions/
ls -la .mc-data/work/legacy-scan/.session.lock  # should NOT exist after clean exit

# Check scan-state.json valid
jq empty .mc-data/work/legacy-scan/sessions/*/scan-state.json
jq '.session.id' .mc-data/work/legacy-scan/sessions/*/scan-state.json
```

### Acceptance Criteria

- [ ] Session dir `sessions/{timestamp-id}/` created per scan run
- [ ] Session dir có sub-folders: `layers/L4/`, `layers/L5/`, `cache/`
- [ ] scan-state.json populated với SESSION_ID, CREATED_AT, PROJECT_PATH
- [ ] session-log.json initialized (empty events array)
- [ ] error-ledger.json initialized
- [ ] File-lock acquired on start, released on exit
- [ ] 2nd concurrent run refused với clear error message
- [ ] Stale lock (>1h) auto-cleaned

---

## Task B.4 — scan-state.json Write + Read Helpers

**Priority:** CRITICAL · **Duration:** 3-4 giờ · **Status:** ⬜

### Actions

Implement Python module `.claude/skills/workflow/_shared/ips/scan_state_reader.py`:

```python
"""scan_state_reader — helper cho read/update scan-state.json atomic.

Dùng bởi orchestrator + sub-skills (Phase D migration).

Pattern: file-lock acquire → read → modify → atomic write (tmp → rename) → release.
"""

import json
import os
import time
from pathlib import Path
from typing import Any


WORK_DIR = Path(".mc-data/work/legacy-scan")


def get_active_session_dir() -> Path | None:
    """Find latest active session (status != completed)."""
    sessions_dir = WORK_DIR / "sessions"
    if not sessions_dir.exists():
        return None
    
    sessions = sorted(sessions_dir.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True)
    for s in sessions:
        state_path = s / "scan-state.json"
        if state_path.exists():
            state = json.loads(state_path.read_text())
            if state.get("status") in ("in_progress", "paused"):
                return s
    return None


def read_scan_state(session_id: str | None = None) -> dict[str, Any]:
    """Read scan-state.json.
    
    If session_id=None → use latest active session.
    """
    if session_id:
        session_dir = WORK_DIR / "sessions" / session_id
    else:
        session_dir = get_active_session_dir()
    
    if session_dir is None:
        raise FileNotFoundError("No active session found. Run /wf-legacy-scan to start.")
    
    state_path = session_dir / "scan-state.json"
    return json.loads(state_path.read_text())


def update_layer_status(layer: str, status: str, session_id: str | None = None) -> None:
    """Atomic update of scan-state.layers.<layer>.status.
    
    Enforces state machine: not_started → in_progress → completed/failed/skipped_by_profile.
    """
    valid_transitions = {
        "not_started": ["in_progress", "skipped_by_profile"],
        "in_progress": ["completed", "failed"],
        "completed": [],
        "failed": ["in_progress"],  # retry allowed
        "skipped_by_profile": [],
    }
    
    state = read_scan_state(session_id)
    current = state["layers"][layer]["status"]
    if status not in valid_transitions.get(current, []):
        raise ValueError(f"Invalid transition {current} → {status} for layer {layer}")
    
    state["layers"][layer]["status"] = status
    if status == "in_progress":
        state["layers"][layer]["started"] = _now_iso()
    elif status in ("completed", "failed"):
        state["layers"][layer]["completed"] = _now_iso()
    
    _atomic_write(session_id, state)


def update_batch_progress(layer: str, progress: dict, session_id: str | None = None) -> None:
    """Update layers.<L>.batch_progress."""
    state = read_scan_state(session_id)
    state["layers"][layer]["batch_progress"] = progress
    _atomic_write(session_id, state)


def update_module_progress(layer: str, module: str, status: str, session_id: str | None = None) -> None:
    """Update layers.<L>.module_progress cho 1 module."""
    state = read_scan_state(session_id)
    mp = state["layers"][layer].setdefault("module_progress", {"completed": [], "total": 0})
    if status == "completed" and module not in mp.get("completed", []):
        mp.setdefault("completed", []).append(module)
    state["layers"][layer]["module_progress"] = mp
    _atomic_write(session_id, state)


def append_error(layer: str, error: dict, session_id: str | None = None) -> None:
    """Append error to error_log[] and scan-state."""
    state = read_scan_state(session_id)
    state["error_log"].append({**error, "layer": layer, "timestamp": _now_iso()})
    _atomic_write(session_id, state)


def _atomic_write(session_id: str | None, state: dict) -> None:
    """Atomic write: tmp → fsync → rename."""
    if session_id:
        session_dir = WORK_DIR / "sessions" / session_id
    else:
        session_dir = get_active_session_dir()
    if session_dir is None:
        raise RuntimeError("No active session")
    
    state_path = session_dir / "scan-state.json"
    tmp_path = state_path.with_suffix(f".json.tmp.{os.getpid()}")
    tmp_path.write_text(json.dumps(state, indent=2, ensure_ascii=False))
    os.fsync(tmp_path.open().fileno()) if hasattr(os, 'fsync') else None
    tmp_path.replace(state_path)


def _now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
```

### Tests

Tạo `.claude/skills/workflow/_shared/ips/tests/test_scan_state_reader.py`:

```python
"""Tests for scan_state_reader."""

import json
import pytest
from pathlib import Path
from workflow._shared.ips import scan_state_reader


@pytest.fixture
def session_dir(tmp_path, monkeypatch):
    """Create mock session dir."""
    work_dir = tmp_path / ".mc-data" / "work" / "legacy-scan"
    session = work_dir / "sessions" / "2026-04-22T10-00-00"
    session.mkdir(parents=True)
    
    state = {
        "session": {"id": "2026-04-22T10-00-00"},
        "layers": {
            "L1": {"status": "completed"},
            "L4": {"status": "not_started", "batch_progress": None},
        },
        "status": "in_progress",
        "error_log": [],
    }
    (session / "scan-state.json").write_text(json.dumps(state))
    
    monkeypatch.setattr(scan_state_reader, "WORK_DIR", work_dir)
    return session


class TestReadScanState:
    def test_read_active_session(self, session_dir):
        state = scan_state_reader.read_scan_state()
        assert state["session"]["id"] == "2026-04-22T10-00-00"


class TestStateMachine:
    def test_valid_transition(self, session_dir):
        scan_state_reader.update_layer_status("L4", "in_progress")
        state = scan_state_reader.read_scan_state()
        assert state["layers"]["L4"]["status"] == "in_progress"
    
    def test_invalid_transition_completed_to_in_progress(self, session_dir):
        with pytest.raises(ValueError):
            scan_state_reader.update_layer_status("L1", "in_progress")
```

### Verify

```bash
cd .claude/skills/workflow
python -m pytest _shared/ips/tests/test_scan_state_reader.py -v
# Expected: 2+ tests pass
```

### Acceptance Criteria

- [ ] `scan_state_reader.py` implement 5 API functions: read_scan_state, update_layer_status, update_batch_progress, update_module_progress, append_error
- [ ] Atomic write: tmp → fsync → rename
- [ ] State machine enforcement (invalid transition raises ValueError)
- [ ] Unit tests pass (≥ 3 test cases)
- [ ] Session auto-discovery (latest active) works

---

## Task B.5 — ledger.json Backward-Compat Generation

**Priority:** HIGH · **Duration:** 2-3 giờ · **Status:** ⬜

### Actions

Implement function trong orchestrator (hoặc bash helper) để generate `ledger.json` ONE-SHOT tại POST Phase 4 synthesize.

Thêm vào `.claude/scripts/legacy-scan-common.sh`:

```bash
# ─── ledger.json backward-compat generation (v2.1) ───
generate_legacy_ledger() {
  # Called ONCE by orchestrator at POST Phase 4 synthesize.
  # Projects scan-state.json → ledger.json v4.1 schema.
  local session_dir="$1"
  local output_path="${2:-.mc-data/work/legacy-scan/ledger.json}"
  
  if ! has_jq; then
    log_error "jq required for ledger generation"
    return 1
  fi
  
  local scan_state="$session_dir/scan-state.json"
  if [[ ! -s "$scan_state" ]]; then
    log_error "scan-state.json not found at $scan_state"
    return 1
  fi
  
  # Project scan-state → ledger.json v4.1 schema
  jq '{
    "$schema": "ledger-v4.1",
    "generated_at": now | todate,
    "session_id": .session.id,
    "strategy": {
      "id": .session.strategy,
      "reasoning": "Generated from scan-state (v2.1 — read-only projection)"
    },
    "maturity": {
      "level": .session.maturity_level,
      "stage_modes": (.depth_map | {
        classify: (if .L4 == "skip" then "skip" else "full" end),
        extract: (if .L5 == "skip" then "skip" else "full" end)
      })
    },
    "stages": {
      "detection": { "status": "completed" },
      "assessment": { "status": (.layers.L2.status) },
      "inventory": { "status": (.layers.L3.status) },
      "classify": { "status": (.layers.L4.status) },
      "extract": { "status": (.layers.L5.status) },
      "synthesize": { "status": (.layers.L6.status) }
    },
    "summary": {
      "total_items": 0,
      "low_confidence_modules": (.layers.L5.metadata.low_confidence_modules // [])
    },
    "errors": .error_log,
    "pipeline_status": (if .status == "completed" then "COMPLETE" else "IN_PROGRESS" end)
  }' "$scan_state" > "$output_path.tmp"
  
  if ! validate_json "$output_path.tmp"; then
    log_error "Generated ledger.json invalid"
    rm -f "$output_path.tmp"
    return 1
  fi
  
  mv "$output_path.tmp" "$output_path"
  log_info "ledger.json generated (v4.1 projection) at $output_path"
}
```

### Integration

- Gọi `generate_legacy_ledger "$SESSION_DIR"` tại cuối phase 4 synthesize.
- Sub-skills (Phase D) KHÔNG gọi function này — chỉ orchestrator.

### Verify

```bash
# Manual test
source .claude/scripts/legacy-scan-common.sh

# Create mock scan-state.json
cat > /tmp/scan-state.json <<EOF
{
  "session": {"id": "test-001", "strategy": "S2", "maturity_level": "CODE_ONLY"},
  "depth_map": {"L4": "standard", "L5": "standard"},
  "layers": {
    "L2": {"status": "completed"}, "L3": {"status": "completed"},
    "L4": {"status": "completed"}, "L5": {"status": "completed"},
    "L6": {"status": "completed"}
  },
  "error_log": [],
  "status": "completed"
}
EOF

mkdir -p /tmp/session-test
cp /tmp/scan-state.json /tmp/session-test/scan-state.json

generate_legacy_ledger /tmp/session-test /tmp/generated-ledger.json

# Validate output
jq empty /tmp/generated-ledger.json && echo "✓ valid"
jq '.pipeline_status' /tmp/generated-ledger.json  # → "COMPLETE"
jq '.stages.classify.status' /tmp/generated-ledger.json  # → "completed"
```

### Acceptance Criteria

- [ ] `generate_legacy_ledger()` function added to shared library
- [ ] Generates valid ledger.json v4.1 schema
- [ ] Called ONCE tại POST Phase 4 synthesize (orchestrator only)
- [ ] Downstream skill (`/wf-brainstorm` legacy) still read ledger.json successfully
- [ ] Sub-skills KHÔNG call function này

---

## Task B.6 — Integration Smoke Test

**Priority:** CRITICAL · **Duration:** 2-3 giờ · **Status:** ⬜

### Actions

Run wf-legacy-scan v5.0 foundation trên `small-en` fixture và verify:

1. Session dir tạo đúng.
2. scan-state.json valid + updated qua các phases.
3. File-lock hoạt động (no corruption).
4. ledger.json generated cuối cùng.
5. Downstream skill (`/wf-brainstorm` legacy mode) vẫn detect project-context.md.

### Steps

```bash
# 1. Clean state
rm -rf docs/design/skills/wf-legacy-scan/fixtures/small-en/.mc-data/

# 2. Run v5.0 Phase B foundation (no profile flags yet — will use default standard behaviour v4.1-ish)
cd docs/design/skills/wf-legacy-scan/fixtures/small-en
/wf-legacy-scan .

# 3. Verify session
ls .mc-data/work/legacy-scan/sessions/
# → 1 directory (timestamp-id)

jq '.' .mc-data/work/legacy-scan/sessions/*/scan-state.json | head -30
# Verify layer statuses match expected progression

# 4. Verify ledger.json generated
jq empty .mc-data/work/legacy-scan/ledger.json
jq '.pipeline_status' .mc-data/work/legacy-scan/ledger.json

# 5. Verify lock released
test ! -f .mc-data/work/legacy-scan/.session.lock

# 6. Run /wf-brainstorm (legacy mode) — should detect project-context.md
/wf-brainstorm
# Verify skill detects LEGACY_MODE (CORE-021)
```

### Acceptance Criteria

- [ ] Run completes without error
- [ ] Session dir created với full structure
- [ ] scan-state.json valid + có layer status progression
- [ ] ledger.json generated at end (valid v4.1 schema)
- [ ] `.session.lock` released on exit
- [ ] `/wf-brainstorm` legacy mode vẫn hoạt động (unchanged behaviour)
- [ ] **Output compare với `small-en.baseline-v4.1/` — structure identical, values trong ±5% drift tolerance**

---

## Post-Phase Verification

```bash
# 1. Compliance audit
powershell -ExecutionPolicy Bypass -File .claude/scripts/run-devkit-bash.ps1 \
  .claude/scripts/skill-compliance-audit.sh wf-legacy-scan

# 2. Schema sync check
powershell -ExecutionPolicy Bypass -File .claude/scripts/run-devkit-bash.ps1 \
  .claude/scripts/validate-schema-sync.sh wf-legacy-scan

# 3. Python tests
cd .claude/skills/workflow
python -m pytest _shared/ips/tests/ -v
# Expected: test_vietnamese_keywords (normalize_vn) + test_scan_state_reader = 5+ pass

# 4. Tag phase
git tag -a v5.0-phase-B -m "Phase B Foundation complete — $(date +%Y-%m-%d)"
```

## Exit Criteria

- [ ] All 6 tasks ✅
- [ ] Compliance audit PASS
- [ ] Schema sync PASS
- [ ] Python tests PASS
- [ ] Smoke test trên small-en fixture PASS
- [ ] Output compare với v4.1 baseline: structure OK, values drift ≤ 5%
- [ ] `v5.0-phase-B` tag pushed
- [ ] MIGRATION-PROGRESS.md updated

## Rollback

Nếu Phase B fail:

```bash
git checkout main
git branch -D feat/wf-legacy-scan-v5.0-phase-b
git tag -d v5.0-phase-B

# Restore skill directory từ backup
cp -r .claude/skills/workflow/.v4.1.bak/wf-legacy-scan/. \
      .claude/skills/workflow/wf-legacy-scan/
```

v4.1 behaviour fully restored.

## Next Phase

→ [phase-C-profiles-ips-vn.md](phase-C-profiles-ips-vn.md)
