#!/usr/bin/env bash
set -euo pipefail
# wf-fix-flow-driver.sh — E2E Business Flow Driver (QD10)
#
# Executes one business-flow-spec.yaml sequentially:
#   SENSE: parse YAML + resolve steps
#   ACT:   prerequisites → per-step (fixture setup + HTTP call + assertions) → invariants → cleanup
#   OUTPUT: STEPS_PASS=N STEPS_FAIL=N SIGNALS_EMITTED=N on stdout (last lines)
#
# Called by P-QD10-business-flow-runtime.md probe per flow.
#
# USAGE:
#   bash wf-fix-flow-driver.sh \
#     --spec          <path/to/flow.yaml> \
#     --base-url      <http://localhost:3000> \
#     --session-dir   <path/to/session/> \
#     --signals-file  <path/to/signals.json> \
#     --checkpoint-dir <path/to/raw/> \
#     [--auth-header  "Authorization: Bearer TOKEN"] \
#     [--playwright]
#
# EXIT CODES: 0 success (even with step failures — check STEPS_FAIL), 1 fatal error
#
# Author: plan wf-fix-bugs-v9 Wave 4 W4.4

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./wf-fix-common.sh
if [ -f "$SCRIPT_DIR/wf-fix-common.sh" ]; then
  source "$SCRIPT_DIR/wf-fix-common.sh"
else
  # Minimal fallback if wf-fix-common.sh not available
  with_runtime_cap() { local _t="$1"; shift; "$@"; }
fi

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
SPEC_PATH=""
BASE_URL=""
SESSION_DIR=""
SIGNALS_FILE=""
CHECKPOINT_DIR=""
AUTH_HEADER=""
USE_PLAYWRIGHT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec)           SPEC_PATH="$2";      shift 2 ;;
    --base-url)       BASE_URL="$2";       shift 2 ;;
    --session-dir)    SESSION_DIR="$2";    shift 2 ;;
    --signals-file)   SIGNALS_FILE="$2";   shift 2 ;;
    --checkpoint-dir) CHECKPOINT_DIR="$2"; shift 2 ;;
    --auth-header)    AUTH_HEADER="$2";    shift 2 ;;
    --playwright)     USE_PLAYWRIGHT=true; shift   ;;
    *) echo "WARN: unknown arg $1" >&2;    shift   ;;
  esac
done

# ---------------------------------------------------------------------------
# Validate required args
# ---------------------------------------------------------------------------
if [ -z "$SPEC_PATH" ] || [ ! -f "$SPEC_PATH" ]; then
  echo "ERROR: --spec path not found: $SPEC_PATH" >&2
  exit 1
fi
if [ -z "$BASE_URL" ]; then
  echo "ERROR: --base-url required" >&2
  exit 1
fi
if [ -z "$SIGNALS_FILE" ]; then
  echo "ERROR: --signals-file required" >&2
  exit 1
fi
[ -z "$CHECKPOINT_DIR" ] && CHECKPOINT_DIR="${SESSION_DIR:-.}/raw"
mkdir -p "$CHECKPOINT_DIR"

# ---------------------------------------------------------------------------
# Python3 flow driver (inline — no separate .py file required)
# ---------------------------------------------------------------------------
python3 - "$SPEC_PATH" "$BASE_URL" "$SIGNALS_FILE" "$CHECKPOINT_DIR" "$AUTH_HEADER" "$USE_PLAYWRIGHT" <<'PYEOF'
import sys, os, json, re, subprocess, time, glob

SPEC_PATH      = sys.argv[1]
BASE_URL       = sys.argv[2].rstrip("/")
SIGNALS_FILE   = sys.argv[3]
CHECKPOINT_DIR = sys.argv[4]
AUTH_HEADER    = sys.argv[5] if len(sys.argv) > 5 else ""
USE_PLAYWRIGHT = sys.argv[6].lower() == "true" if len(sys.argv) > 6 else False

# ---- YAML parse ----
try:
    import yaml
except ImportError:
    print("ERROR: PyYAML not installed (pip install pyyaml)", file=sys.stderr)
    sys.exit(1)

try:
    with open(SPEC_PATH, encoding="utf-8") as f:
        spec = yaml.safe_load(f)
except yaml.YAMLError as e:
    print(f"E107: YAML parse error in {SPEC_PATH}: {e}", file=sys.stderr)
    sys.exit(1)

flow_id         = spec.get("flow_id", os.path.splitext(os.path.basename(SPEC_PATH))[0])
flow_name       = spec.get("name", flow_id)
prerequisites   = spec.get("prerequisites", [])
steps           = spec.get("steps", [])
invariants      = spec.get("expected_invariants", [])
timeout_minutes = spec.get("timeout_minutes", 10)

print(f"=== DRIVER: flow={flow_id} steps={len(steps)} invariants={len(invariants)} ===", file=sys.stderr)

# ---- State ----
fixture_map   = {}  # step_id → {entity_id, response_body: dict}
step_results  = {}  # step_id → {status: pass|fail|skip, http_code, response_body, skip_reason}
cleanup_queue = []  # [{step_id, cleanup_url}]
steps_pass    = 0
steps_fail    = 0
signals_emitted = 0

# ---- Helpers ----
# CRIT-7 fix v9.0.3: chong race condition load->append->save khi nhieu flow driver
# subprocess chay dong thoi (QD10 multi-flow). Lock convention `<signals>.lock/`
# (mkdir POSIX atomic) — KHOP voi merge_signals.py va wf-fix-common.sh:acquire_signals_lock
# nen 3 writer co the chia se cung lock.
import time as _time

def _signals_lock_acquire(signals_path, timeout_sec=30, stale_sec=300):
    """Mkdir-based lock. Return True khi acquired, False khi timeout."""
    lock_dir = signals_path + ".lock"
    waited = 0
    while waited < timeout_sec:
        if os.path.isdir(lock_dir):
            try:
                age = _time.time() - os.path.getmtime(lock_dir)
            except OSError:
                age = 0
            if age > stale_sec:
                # Stale lock takeover
                try:
                    os.rmdir(lock_dir)
                except OSError:
                    pass
        try:
            parent = os.path.dirname(lock_dir) or "."
            os.makedirs(parent, exist_ok=True)
            os.mkdir(lock_dir)
            return True
        except FileExistsError:
            _time.sleep(1)
            waited += 1
        except OSError:
            return False
    return False

def _signals_lock_release(signals_path):
    lock_dir = signals_path + ".lock"
    try:
        os.rmdir(lock_dir)
    except OSError:
        pass

def load_signals():
    try:
        with open(SIGNALS_FILE, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return []

def save_signals(signals):
    # Atomic: write tmp + rename. Khong truncate file goc.
    tmp = SIGNALS_FILE + ".tmp." + str(os.getpid())
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(signals, f, ensure_ascii=False, indent=2)
    os.replace(tmp, SIGNALS_FILE)

def emit_signal(signal_type, severity, title, description, evidence_content, context):
    probe_id = "P-QD10-business-flow-runtime"
    new_entry = {
        "$schema": "signal-v2",
        "probe_id": probe_id,
        "dimension_id": "QD10",
        "signal_type": signal_type,
        "severity": severity.lower(),
        "title": title,
        "description": description,
        "location": context,
        "evidence": [{"type": "api_response_diff", "content": evidence_content}],
        "dedup_key": f"{probe_id}:{signal_type}:{context.get('flow_id','')}:{context.get('step_id', context.get('invariant_index', ''))}"
    }
    # Acquire lock — load->append->save phai atomic cross-process.
    acquired = _signals_lock_acquire(SIGNALS_FILE)
    if not acquired:
        # Defense-in-depth: lock timeout van ghi (best effort), nhung log warning.
        print(f"[flow-driver WARNING] signals lock timeout, writing without lock: {SIGNALS_FILE}", file=sys.stderr, flush=True)
    try:
        signals = load_signals()
        signals.append(new_entry)
        save_signals(signals)
    finally:
        if acquired:
            _signals_lock_release(SIGNALS_FILE)
    return 1  # signals emitted count

def resolve_refs(value):
    """Replace ${step_id.field} with values from fixture_map / step_results."""
    if not isinstance(value, str):
        return value
    pattern = re.compile(r'\$\{([a-z][a-z0-9-]*)\.([a-zA-Z0-9_]+)\}')
    def replacer(m):
        sid, field = m.group(1), m.group(2)
        fm = fixture_map.get(sid, {})
        if field in ("id", "_id", "uuid"):
            return str(fm.get("entity_id", m.group(0)))
        body = fm.get("response_body", {})
        if isinstance(body, dict) and field in body:
            return str(body[field])
        return m.group(0)
    return pattern.sub(replacer, value)

def navigate_json(obj, path):
    """Navigate dotted path through JSON."""
    for part in path.split("."):
        if isinstance(obj, dict):
            obj = obj.get(part)
        elif isinstance(obj, list):
            try: obj = obj[int(part)]
            except: return None
        else:
            return None
        if obj is None:
            return None
    return obj

def http_call(method, url, body_json=None, timeout=30):
    """HTTP call via subprocess curl. Returns (int code, str body)."""
    cmd = ["curl", "-s", "-w", "\n%{http_code}", "-X", method.upper(),
           "-H", "Accept: application/json", "--max-time", str(timeout)]
    if AUTH_HEADER:
        cmd += ["-H", AUTH_HEADER]
    if method.upper() in ("POST", "PUT", "PATCH") and body_json is not None:
        cmd += ["-H", "Content-Type: application/json", "-d", json.dumps(body_json)]
    cmd.append(url)
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout + 5)
        lines = result.stdout.strip().split("\n")
        code_str = lines[-1].strip() if lines else "000"
        body = "\n".join(lines[:-1])
        try:
            return int(code_str), body
        except ValueError:
            return 0, body
    except subprocess.TimeoutExpired:
        return 0, ""
    except Exception as e:
        print(f"  WARN: curl failed: {e}", file=sys.stderr)
        return 0, ""

def evaluate_assertions(assertions, http_code, response_body_str):
    """Returns list of failure dicts for failed assertions."""
    OPERATORS = {
        "eq":          lambda a, e: str(a) == str(e),
        "ne":          lambda a, e: str(a) != str(e),
        "gt":          lambda a, e: _num(a) > _num(e),
        "lt":          lambda a, e: _num(a) < _num(e),
        "gte":         lambda a, e: _num(a) >= _num(e),
        "lte":         lambda a, e: _num(a) <= _num(e),
        "exists":      lambda a, e: a is not None,
        "not_exists":  lambda a, e: a is None,
        "contains":    lambda a, e: str(e) in str(a) if a is not None else False,
        "matches":     lambda a, e: bool(re.match(str(e), str(a))) if a is not None else False,
        "starts_with": lambda a, e: str(a).startswith(str(e)) if a is not None else False,
    }
    def _num(v):
        try: return float(v)
        except: return 0.0

    try:
        body_json = json.loads(response_body_str) if response_body_str.strip() else {}
    except:
        body_json = {}

    failures = []
    for assertion in assertions:
        if isinstance(assertion, str):
            continue  # doc-only
        field_path  = assertion.get("field", "")
        operator    = assertion.get("operator", "eq")
        expected    = resolve_refs(assertion.get("expected"))
        severity    = assertion.get("severity_on_fail", "HIGH")
        desc        = assertion.get("description", f"{field_path} {operator} {expected}")

        # Resolve actual
        actual = None
        if field_path in ("response.status", "status"):
            actual = str(http_code)
        elif field_path.startswith("body.") or field_path.startswith("response.body."):
            sub = field_path.replace("response.body.", "").replace("body.", "")
            actual = navigate_json(body_json, sub)
        elif field_path.startswith("response."):
            actual = navigate_json(body_json, field_path[len("response."):])
        else:
            actual = navigate_json(body_json, field_path)

        op_fn = OPERATORS.get(operator)
        if not op_fn:
            continue
        try:
            passed = op_fn(actual, expected)
        except:
            passed = False

        if not passed:
            failures.append({
                "description": desc,
                "field": field_path,
                "operator": operator,
                "expected": str(expected),
                "actual": str(actual),
                "severity": severity.upper()
            })
    return failures

def write_checkpoint(step_id, status):
    cp_file = os.path.join(CHECKPOINT_DIR, f"P-QD10-flow-{flow_id}-checkpoint.json")
    try:
        if os.path.exists(cp_file):
            with open(cp_file, encoding="utf-8") as f:
                cp = json.load(f)
        else:
            cp = {"flow_id": flow_id, "steps_done": [], "status": "in_progress",
                  "started_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
        if step_id not in cp["steps_done"]:
            cp["steps_done"].append(step_id)
        cp["last_step"] = step_id
        cp["last_step_status"] = status
        with open(cp_file, "w", encoding="utf-8") as f:
            json.dump(cp, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"  WARN: checkpoint write failed: {e}", file=sys.stderr)

# ---- A0: Checkpoint init ----
cp_file = os.path.join(CHECKPOINT_DIR, f"P-QD10-flow-{flow_id}-checkpoint.json")
with open(cp_file, "w", encoding="utf-8") as f:
    json.dump({"flow_id": flow_id, "steps_done": [], "status": "in_progress",
               "started_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}, f)

# ---- A1: Check prerequisites ----
for prereq in prerequisites:
    check = prereq.get("check", "")
    setup_if_missing = prereq.get("setup_if_missing", False)
    description = prereq.get("description", "")

    if not check:
        continue

    parts = check.strip().split()
    if len(parts) >= 2 and parts[0].upper() in ("GET", "POST"):
        method, path = parts[0].upper(), parts[1]
        expected_code = int(parts[-1]) if len(parts) >= 3 and parts[-1].isdigit() else 200
        code, body = http_call(method, f"{BASE_URL}{path}")

        if code != expected_code:
            if not setup_if_missing:
                print(f"  SKIP flow={flow_id}: prerequisite not satisfied — {description} (HTTP {code} expected {expected_code})", file=sys.stderr)
                # Write summary and exit cleanly
                print("STEPS_PASS=0")
                print("STEPS_FAIL=0")
                print("SIGNALS_EMITTED=0")
                sys.exit(0)
            # else: setup_if_missing=true → assume fixture step will handle it

# ---- A2-A5: Step execution loop ----
flow_start = time.time()
flow_timeout = timeout_minutes * 60

for step in steps:
    step_id   = step.get("id", "unknown")
    module    = step.get("module", "")
    action    = step.get("action", step_id)
    api_ep    = step.get("api_endpoint", "")
    fixture   = step.get("fixture", {})
    assertions = step.get("assert", [])
    wait_for  = step.get("wait_for", {})
    skip_if   = step.get("skip_if", "")
    cleanup   = step.get("cleanup", False)

    # Flow timeout check
    if time.time() - flow_start > flow_timeout:
        print(f"  E112: flow={flow_id} timeout after {timeout_minutes}min at step={step_id}", file=sys.stderr)
        signals_emitted += emit_signal(
            "business_flow_step_failed", "high",
            f"Flow {flow_id}: step {step_id} ({action}) FAILED — flow timeout",
            f"Business flow '{flow_id}' exceeded timeout of {timeout_minutes}min at step '{step_id}'.",
            f"Flow timeout after {timeout_minutes} minutes at step {step_id}",
            {"flow_id": flow_id, "step_id": step_id, "action": action}
        )
        steps_fail += 1
        break

    # skip_if evaluation
    if skip_if:
        skip_ref = re.match(r"steps\.([a-z][a-z0-9-]*)\.skipped\s*==\s*true", skip_if.strip())
        if skip_ref:
            ref_id = skip_ref.group(1)
            if step_results.get(ref_id, {}).get("status") == "skip":
                print(f"  SKIP step={step_id} (skip_if={skip_if})", file=sys.stderr)
                step_results[step_id] = {"status": "skip", "skip_reason": f"skip_if={skip_if}"}
                write_checkpoint(step_id, "skip")
                continue

    # Resolve fixture data refs
    fixture_data = {}
    if fixture and fixture.get("data"):
        for k, v in fixture["data"].items():
            fixture_data[k] = resolve_refs(v) if isinstance(v, str) else v

    # Determine HTTP method + path from api_endpoint
    if not api_ep:
        if USE_PLAYWRIGHT:
            print(f"  SKIP step={step_id} via Playwright (not implemented in CLI driver)", file=sys.stderr)
        else:
            print(f"  SKIP step={step_id}: no api_endpoint, Playwright unavailable", file=sys.stderr)
        step_results[step_id] = {"status": "skip", "skip_reason": "no_api_endpoint"}
        write_checkpoint(step_id, "skip")
        continue

    # Resolve api_endpoint template refs (e.g. /api/customers/${create-customer.id})
    api_ep = resolve_refs(api_ep)
    parts = api_ep.strip().split()
    if len(parts) >= 2:
        method, path = parts[0].upper(), parts[1]
    elif len(parts) == 1:
        method, path = "GET", parts[0]
    else:
        print(f"  SKIP step={step_id}: unparseable api_endpoint={api_ep!r}", file=sys.stderr)
        step_results[step_id] = {"status": "skip", "skip_reason": "unparseable_endpoint"}
        write_checkpoint(step_id, "skip")
        continue

    url = f"{BASE_URL}{path}"

    # Fixture setup: POST to create entity before step execution
    if fixture and fixture.get("entity_type") and method not in ("GET", "DELETE"):
        reuse_from = fixture.get("reuse_from_step")
        if reuse_from and reuse_from in fixture_map:
            # Reuse entity from prior step
            fixture_map.setdefault(step_id, {}).update(fixture_map[reuse_from])
        elif fixture_data:
            # POST to create fixture entity
            fix_path = path.split("/")
            # Derive fixture create endpoint: take base resource path
            fix_ep = "/" + "/".join(p for p in fix_path[1:] if not re.match(r'\d+|[0-9a-f-]{36}', p))
            fix_url = f"{BASE_URL}{fix_ep}" if fix_ep != "/" else url
            fix_code, fix_body = http_call("POST", fix_url, body_json=fixture_data)
            if fix_code < 200 or fix_code >= 300:
                # E111: fixture setup failed
                print(f"  E111: fixture setup failed step={step_id} code={fix_code} url={fix_url}", file=sys.stderr)
                signals_emitted += emit_signal(
                    "business_flow_step_failed", "high",
                    f"Flow {flow_id}: step {step_id} ({action}) FAILED — fixture setup E111",
                    f"Fixture setup for step '{step_id}' failed. POST {fix_url} returned HTTP {fix_code}.",
                    f"POST {fix_url} → HTTP {fix_code} {fix_body[:200]}",
                    {"flow_id": flow_id, "step_id": step_id, "action": action}
                )
                steps_fail += 1
                step_results[step_id] = {"status": "fail", "http_code": fix_code}
                write_checkpoint(step_id, "fail")
                continue

            # Extract entity ID from fixture response
            try:
                fix_json = json.loads(fix_body) if fix_body.strip() else {}
            except:
                fix_json = {}
            entity_id = (fix_json.get("id") or fix_json.get("_id") or
                         fix_json.get("uuid") or
                         navigate_json(fix_json, "data.id") or "")
            if fixture.get("cleanup_after_flow", True):
                if entity_id:
                    cleanup_queue.append({
                        "step_id": step_id,
                        "cleanup_url": f"{BASE_URL}{fix_ep}/{entity_id}"
                    })
            fixture_map[step_id] = {"entity_id": str(entity_id), "response_body": fix_json}

    # Re-resolve api_endpoint after fixture_map updated
    api_ep = resolve_refs(api_ep)
    parts = api_ep.strip().split()
    if len(parts) >= 2:
        method, path = parts[0].upper(), parts[1]
    url = f"{BASE_URL}{path}"

    # Execute step HTTP call
    print(f"  STEP {step_id}: {method} {url}", file=sys.stderr)
    body_for_call = fixture_data if method in ("POST", "PUT", "PATCH") else None
    code, body = http_call(method, url, body_json=body_for_call)
    print(f"  STEP {step_id}: HTTP {code}", file=sys.stderr)

    # wait_for async polling
    if wait_for and wait_for.get("condition"):
        cond      = wait_for["condition"]
        wf_timeout = wait_for.get("timeout_seconds", 30)
        wf_interval = wait_for.get("poll_interval_seconds", 2)
        print(f"  STEP {step_id}: polling condition='{cond}' timeout={wf_timeout}s", file=sys.stderr)
        deadline = time.time() + wf_timeout
        satisfied = False
        while time.time() < deadline:
            poll_code, poll_body = http_call("GET", url)
            # Simple "field == VALUE" condition
            m = re.match(r'(\S+)\s*==\s*(\S+)', cond)
            if m:
                field_part = m.group(1).split(".", 1)[-1]
                expected_val = m.group(2)
                try:
                    pb = json.loads(poll_body) if poll_body.strip() else {}
                except:
                    pb = {}
                actual_val = navigate_json(pb, field_part)
                if str(actual_val) == expected_val:
                    satisfied = True
                    break
            time.sleep(wf_interval)

        if not satisfied:
            print(f"  E112: step={step_id} wait_for timeout after {wf_timeout}s", file=sys.stderr)
            signals_emitted += emit_signal(
                "business_flow_step_failed", "high",
                f"Flow {flow_id}: step {step_id} ({action}) FAILED — wait_for timeout",
                f"Step '{step_id}' wait_for condition '{cond}' not satisfied after {wf_timeout}s.",
                f"Polled {url} for {wf_timeout}s — condition '{cond}' never true",
                {"flow_id": flow_id, "step_id": step_id, "action": action}
            )
            steps_fail += 1
            step_results[step_id] = {"status": "fail", "http_code": code, "response_body": {}, "skip_reason": "wait_for_timeout"}
            write_checkpoint(step_id, "fail")
            # Skip remaining steps in flow on timeout
            break

    # Store step response in fixture_map for cross-step references
    try:
        resp_json = json.loads(body) if body.strip() else {}
    except:
        resp_json = {}
    if step_id not in fixture_map:
        entity_id = (resp_json.get("id") or resp_json.get("_id") or
                     navigate_json(resp_json, "data.id") or "")
        fixture_map[step_id] = {"entity_id": str(entity_id), "response_body": resp_json}

    # Cleanup registration for step-level cleanup
    if cleanup and fixture_map.get(step_id, {}).get("entity_id"):
        cleanup_queue.append({
            "step_id": step_id,
            "cleanup_url": f"{url}/{fixture_map[step_id]['entity_id']}"
        })

    # Evaluate assertions
    failures = evaluate_assertions(assertions, code, body)

    # Also check HTTP success (2xx) as implicit assertion
    http_ok = 200 <= code < 300
    if not http_ok and not assertions:
        failures = [{
            "description": f"HTTP response should be 2xx",
            "field": "response.status",
            "operator": "gte",
            "expected": "200",
            "actual": str(code),
            "severity": "HIGH"
        }]

    if failures:
        for failure in failures:
            sev = failure.get("severity", "HIGH").lower()
            evidence = (f"{method} {url} → HTTP {code}\n"
                        f"Assertion: {failure['description']}\n"
                        f"Expected: {failure['expected']} Actual: {failure['actual']}\n"
                        f"Response: {body[:300]}")
            signals_emitted += emit_signal(
                "business_flow_step_failed", sev,
                f"Flow {flow_id}: step {step_id} ({action}) FAILED",
                f"Business flow step '{step_id}' in flow '{flow_id}' failed. "
                f"Action: {action}. Reason: {failure['description']} — actual: {failure['actual']}",
                evidence,
                {"flow_id": flow_id, "step_id": step_id, "action": action}
            )
        steps_fail += 1
        step_results[step_id] = {
            "status": "fail",
            "http_code": code,
            "response_body": resp_json,
            "assertions_failed": failures
        }
        write_checkpoint(step_id, "fail")
    else:
        steps_pass += 1
        step_results[step_id] = {"status": "pass", "http_code": code, "response_body": resp_json}
        write_checkpoint(step_id, "pass")
        print(f"  STEP {step_id}: PASS", file=sys.stderr)

# ---- A7: Check global invariants ----
for idx, invariant in enumerate(invariants):
    if isinstance(invariant, str):
        continue  # doc-only string
    description = invariant.get("description", "")
    check       = invariant.get("check", "")
    severity    = invariant.get("severity_on_fail", "CRITICAL")

    if not check:
        continue

    # Parse: "GET /api/path returns 200"
    parts = check.strip().split()
    if len(parts) >= 2 and parts[0].upper() == "GET":
        method = "GET"
        path   = resolve_refs(parts[1])
        expected_code = int(parts[-1]) if len(parts) >= 3 and parts[-1].isdigit() else 200
        inv_url = f"{BASE_URL}{path}"
        code, body = http_call(method, inv_url, timeout=20)
        satisfied = (code == expected_code)

        if not satisfied:
            evidence = f"GET {inv_url} → HTTP {code} (expected {expected_code}). Response: {body[:300]}"
            print(f"  INVARIANT [{idx}]: VIOLATED — {description}", file=sys.stderr)
            signals_emitted += emit_signal(
                "business_flow_invariant_violated", severity.lower(),
                f"Flow {flow_id}: invariant '{description}' VIOLATED",
                f"Global invariant check failed after flow '{flow_id}' completed. "
                f"Invariant: '{description}'. Check: {check}",
                evidence,
                {"flow_id": flow_id, "invariant": description, "invariant_index": idx}
            )
        else:
            print(f"  INVARIANT [{idx}]: PASS — {description}", file=sys.stderr)

# ---- A6: Cleanup fixtures ----
cleanup_ok = 0
cleanup_fail = 0
for item in cleanup_queue:
    curl_cmd = ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
                "-X", "DELETE", "-H", "Accept: application/json"]
    if AUTH_HEADER:
        curl_cmd += ["-H", AUTH_HEADER]
    curl_cmd += [item["cleanup_url"], "--max-time", "15"]
    try:
        result = subprocess.run(curl_cmd, capture_output=True, text=True, timeout=20)
        del_code = int(result.stdout.strip()) if result.stdout.strip().isdigit() else 0
        if 200 <= del_code < 300 or del_code == 404:
            cleanup_ok += 1
        else:
            print(f"  WARN: cleanup DELETE failed code={del_code} url={item['cleanup_url']}", file=sys.stderr)
            cleanup_fail += 1
    except Exception as e:
        print(f"  WARN: cleanup error: {e}", file=sys.stderr)
        cleanup_fail += 1

# ---- Finalize checkpoint ----
try:
    with open(cp_file, encoding="utf-8") as f:
        cp = json.load(f)
    cp["status"] = "fail" if steps_fail > 0 else "pass"
    cp["completed_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    cp["cleanup"] = {"ok": cleanup_ok, "fail": cleanup_fail}
    with open(cp_file, "w", encoding="utf-8") as f:
        json.dump(cp, f, ensure_ascii=False, indent=2)
except Exception as e:
    print(f"  WARN: final checkpoint write failed: {e}", file=sys.stderr)

# ---- Output metrics (parsed by bash caller) ----
print(f"STEPS_PASS={steps_pass}")
print(f"STEPS_FAIL={steps_fail}")
print(f"SIGNALS_EMITTED={signals_emitted}")
print(f"DRIVER: flow={flow_id} steps_pass={steps_pass} steps_fail={steps_fail} signals={signals_emitted} cleanup_ok={cleanup_ok} cleanup_fail={cleanup_fail}", file=sys.stderr)

PYEOF
