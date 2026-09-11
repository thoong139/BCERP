# P-QD10-state-machine-correctness — State Machine Transition Correctness

> **Type:** static | **Profile:** exhaustive | **Cache:** allowed (static per code state)
> **Parallel class:** static → parallel (max 3 concurrent static probes)
> **Signal types:** `state_machine_illegal_transition` (HIGH), `state_machine_missing_transition` (MEDIUM)
> **Error codes:** E100 (QD10 generic), E107 (state-machine YAML parse error)

Kiem tra code co tuan thu dung cac state machine transitions duoc dinh nghia trong spec `.mc-data/docs/phase3-architecture/state-machines/*.yaml`. Voi moi entity co spec: (1) Phat hien **forbidden transitions** co the thuc thi duoc trong code (ILLEGAL — severity HIGH); (2) Phat hien **missing transition handlers** — valid transitions trong spec nhung khong co implementation tuong ung (MEDIUM). CI-ROUTE PRIMARY: **GitNexus** `query("state transition {entity}")` de trace transition logic; **Serena** `find_symbol(state_enum)` de xac minh state constants duoc khai bao. Fallback: grep switch/if patterns. YAML parsing: Python3 + PyYAML.

---

## Reuses from

| Aspect | Source | File:line | Notes |
|--------|--------|-----------|-------|
| Static pattern grep (switch/if-else state logic) | `QD2 P-QD2-calculation-check.md` | `:15-45` | Reuse pattern scan strategy: scan `**/service/**/*.{ts,js,py,java}` + `**/domain/**` for state-related patterns; classify per match |
| CI detect load (SERENA/GITNEXUS vars) | `QD9 P-QD9-spa-route-coverage.md` | `PRE-GATE step 5` | `source <(bash ci-detect.sh ...)` pattern + `SERENA_AVAILABLE/GITNEXUS_AVAILABLE` vars |
| Common variables (LANE_DIR, SIGNALS_FILE, REGISTRY_FILE) | `procedures/probes/_shared.md` (QD10) | `:7-21` | Lane path constants reused |
| Emit signal runtime integration (context_json) | `procedures/probes/_shared.md` (QD10) | `:96-134` | `emit_signal_runtime_integration` adapted for state machine context |
| Sampling + emit_sampling_note | `procedures/probes/_shared.md` (QD10) | `:176-191` | Khi spec_count > 10 entities → priority queue |
| with_runtime_cap + jq_int | `scripts/wf-fix-common.sh` | `:134, :86` | Timeout guard + CRLF-safe int parse |

**Diff so voi cac probe QD10 khac:**
- Probe duy nhat consume YAML spec tu phase3-architecture/ (khong doc registry pairs) — doc source doc lap
- YAML parsing qua Python3 (khong co YAML CLI built-in trong bash) — dung jsonschema validate truoc
- Illegal transition detection = co-occurrence grep (FROM_STATE + TO_STATE trong window 50 lines) — khong phai runtime check
- Missing transition detection = action function search — tim handler function, khong so sanh schemas
- Signals khong co provider_module/consumer_module — loc theo entity + state pair (dedup key khac)

---

## CI-ROUTE

| Task | CI Tool (Primary) | Fallback | Purpose |
|------|-------------------|----------|---------|
| Trace transition logic trong code | **GitNexus** `query("state transition {entity}")` | Grep switch/case/if-else | Tim cac implementation paths co the thay doi entity status |
| Verify state enum/constants duoc khai bao | **Serena** `find_symbol({name_path_pattern: "{Entity}Status", include_body: true})` | Grep `enum.*Status|const.*STATUS` | Xac nhan state values trong code khop spec |
| Tim transition handler function | **Serena** `find_symbol({name_path_pattern: "{action}_{entity}", include_body: true})` | Grep `function.*{action}|async.*{action}` | Locate handler cho moi valid transition action |
| Blast radius khi state enum thay doi | **GitNexus** `impact({target: "{Entity}Status", direction: "upstream"})` | Manual grep | Pre-flight truoc khi report missing state |

**Khi CI unavailable:**
```bash
if [[ "$GITNEXUS_AVAILABLE" != "true" ]]; then
  echo "WARN: GitNexus unavailable — fallback to grep for transition logic discovery" >&2
fi
if [[ "$SERENA_AVAILABLE" != "true" ]]; then
  echo "WARN: Serena unavailable — fallback to grep for state enum + handler discovery" >&2
fi
```

---

## PRE-GATE

```
1. IF profile != exhaustive:
     SKIP probe — emit note "skipped_profile_not_exhaustive"
     LOG "INFO: P-QD10-state-machine-correctness requires profile=exhaustive (state machine specs are deep phase3 artifacts)" >&2
     → exit 0

2. Glob state machine spec files:
     SPEC_FILES=$(find ".mc-data/docs/phase3-architecture/state-machines" -name "*.yaml" 2>/dev/null | sort)
     SPEC_COUNT=$(echo "$SPEC_FILES" | grep -c . 2>/dev/null || echo 0)
     IF SPEC_COUNT == 0:
       SKIP probe — emit note "skipped_no_state_machine_specs"
       emit WARN: "P-QD10-state-machine-correctness requires .mc-data/docs/phase3-architecture/state-machines/*.yaml specs. Author via /wf-design (state machine spec section) using schema .claude/doc-framework/_meta/state-machine-spec-schema.json."
       → exit 0

3. Validate YAML spec files (Python3 + jsonschema):
     SCHEMA_FILE=".claude/doc-framework/_meta/state-machine-spec-schema.json"
     for spec in $SPEC_FILES; do
       python3 -c "
import json, sys
try:
    import yaml, jsonschema
    spec = yaml.safe_load(open('$spec'))
    schema = json.load(open('$SCHEMA_FILE'))
    jsonschema.validate(spec, schema)
    print('VALID: $spec')
except Exception as e:
    print(f'INVALID: $spec — {e}', file=sys.stderr)
    sys.exit(1)
       " 2>&1 || {
         LOG "ERROR: E107 — YAML parse or schema validation failed for $spec" >&2
         exit 1
       }
     done

4. Load CI availability (REUSE: P-QD9-spa-route-coverage.md PRE-GATE step 5):
     source <(bash .claude/scripts/ci-detect.sh --project-root "$PROJECT_ROOT" 2>/dev/null) || true
     GITNEXUS_AVAILABLE="${GITNEXUS_AVAILABLE:-false}"
     SERENA_AVAILABLE="${SERENA_AVAILABLE:-false}"

5. Detect SOURCE_DIR:
     SOURCE_DIR="${SOURCE_DIR:-src}"
     IF [ ! -d "$SOURCE_DIR" ]; then
       SOURCE_DIR="apps"
     fi
     IF [ ! -d "$SOURCE_DIR" ]; then
       SOURCE_DIR="."
       LOG "WARN: source_dir_fallback=. (khong tim thay src/ hoac apps/)" >&2
     fi

6. Ensure RAW_DIR + LANE_DIR exist:
     mkdir -p "$RAW_DIR" "$LANE_DIR"
```

---

## SENSE

### S1: Load State Machine Specs

```bash
# Parse tung YAML spec voi Python3
SPECS_JSON=$(python3 - << 'PYEOF'
import yaml, json, sys, os, glob

specs = []
spec_dir = ".mc-data/docs/phase3-architecture/state-machines"
spec_files = sorted(glob.glob(f"{spec_dir}/*.yaml"))

for path in spec_files:
    try:
        with open(path) as f:
            spec = yaml.safe_load(f)
        specs.append({
            "file": path,
            "entity": spec.get("entity", ""),
            "module_id": spec.get("module_id", ""),
            "states": spec.get("states", []),
            "initial_state": spec.get("initial_state", ""),
            "terminal_states": spec.get("terminal_states", []),
            "transitions": [
                {
                    "from": t.get("from", ""),
                    "to": t.get("to", ""),
                    "action": t.get("action", ""),
                    "role": t.get("role", []) if isinstance(t.get("role", []), list) else [t.get("role", "")]
                }
                for t in spec.get("transitions", [])
            ],
            "forbidden_transitions": [
                {
                    "from": ft.get("from", ""),
                    "to": ft.get("to", ""),
                    "reason": ft.get("reason", "")
                }
                for ft in spec.get("forbidden_transitions", [])
            ]
        })
    except Exception as e:
        print(f"WARN: Could not parse {path}: {e}", file=sys.stderr)

print(json.dumps(specs))
PYEOF
)

SPEC_COUNT=$(echo "$SPECS_JSON" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
LOG "INFO: Loaded $SPEC_COUNT state machine specs" >&2
```

### S2: CI-ROUTE — Discover State Enum Declarations (Serena PRIMARY)

```bash
# For each entity, verify state enum declared in code
# CI-ROUTE PRIMARY: Serena find_symbol({name_path_pattern: "{Entity}Status"})

if [[ "$SERENA_AVAILABLE" == "true" ]]; then
  # (Pseudocode — orchestrator agent thuc hien via Serena MCP):
  # For each spec entity (Quotation, Order, Invoice, ...):
  #   ENUM_DEF = serena_find_symbol({name_path_pattern: "{entity}Status|{entity}State", include_body: true})
  #   STATE_VALUES_IN_CODE = extract enum values from ENUM_DEF.body
  #   LOG "INFO: Serena find_symbol({entity}Status) → {N} state values found" >&2
  LOG "INFO: Serena available — state enum discovery via find_symbol (orchestrator executes per entity)" >&2
else
  # Fallback: grep enum definitions
  LOG "INFO: Serena unavailable — fallback grep for state enum/const declarations" >&2
fi
```

### S3: CI-ROUTE — Trace Transition Logic (GitNexus PRIMARY)

```bash
# For each entity, discover all code paths that change entity status
# CI-ROUTE PRIMARY: GitNexus query("state transition {entity}")

if [[ "$GITNEXUS_AVAILABLE" == "true" ]]; then
  # (Pseudocode — orchestrator agent thuc hien via GitNexus MCP):
  # For each spec entity:
  #   TRANSITION_FLOWS = gitnexus_query({query: "state transition {entity}"})
  #   TRANSITION_FILES = extract unique file paths from TRANSITION_FLOWS (process-grouped)
  #   LOG "INFO: GitNexus transition flows for {entity}: {N} symbols across {M} files" >&2
  LOG "INFO: GitNexus available — transition logic discovery via query (orchestrator executes per entity)" >&2
else
  LOG "INFO: GitNexus unavailable — fallback grep for state/status assignment patterns" >&2
fi
```

---

## THINK

```bash
# Build analysis plan per spec entity
SIGNAL_COUNT=0
MAX_SIGNALS=100
ENTITIES_ANALYZED=0
ENTITIES_CLEAN=0
ENTITIES_WITH_ISSUES=0

# Source files to scan (REUSE QD2 pattern: service + domain + business logic)
SOURCE_PATTERNS=(
  "$SOURCE_DIR/**/service/**/*.{ts,js,py,java,cs,go}"
  "$SOURCE_DIR/**/services/**/*.{ts,js,py,java,cs,go}"
  "$SOURCE_DIR/**/domain/**/*.{ts,js,py,java,cs,go}"
  "$SOURCE_DIR/**/usecase/**/*.{ts,js,py,java,cs,go}"
  "$SOURCE_DIR/**/handler/**/*.{ts,js,py,java,cs,go}"
  "$SOURCE_DIR/**/controller/**/*.{ts,js,py,java,cs,go}"
)
EXCLUDE_RE="(node_modules|\.git|dist|build|__pycache__|\.spec\.|\.test\.|test/|tests/|__tests__/|mock|fixture|vendor)"

# For each entity spec: determine check targets
# - forbidden_transitions[] → ILLEGAL CHECK (A1)
# - transitions[] filtered by NOT terminal_state target → COVERAGE CHECK (A2)
# (Terminal state transitions like CANCELLED→nothing dont need handler-exit check)
LOG "INFO: THINK: $SPEC_COUNT entities to analyze" >&2
```

---

## ACT

### A1: Illegal Transition Detection (Forbidden Transitions in Code)

```bash
# For each state machine spec, per forbidden transition:
# Search for co-occurrence of FROM_STATE being guarded AND TO_STATE being assigned within 50-line window
# This catches code paths where status = 'TO_STATE' is reachable from FROM_STATE context

python3 - << 'PYEOF'
import json, subprocess, sys, os, re, glob

specs = json.loads(os.environ.get("SPECS_JSON", "[]"))
source_dir = os.environ.get("SOURCE_DIR", "src")
exclude_re = re.compile(r"(node_modules|\.git|dist|build|__pycache__|\.spec\.|\.test\.|test/|tests/|__tests__/|mock|fixture|vendor)")
signals = []
signal_count = 0
max_signals = int(os.environ.get("MAX_SIGNALS", "100"))

for spec in specs:
    entity = spec["entity"]
    forbidden = spec.get("forbidden_transitions", [])
    if not forbidden:
        print(f"INFO: {entity} — no forbidden_transitions defined, skip A1", file=sys.stderr)
        continue

    # Find all source files related to this entity (heuristic: filename contains entity name lowercased)
    entity_hint = entity.lower()
    try:
        result = subprocess.run(
            ["grep", "-rl", "--include=*.ts", "--include=*.js", "--include=*.py",
             "--include=*.java", "--include=*.cs", "--include=*.go",
             f"status.*{entity_hint}\\|{entity_hint}.*status\\|{entity}Status\\|{entity_hint}.status",
             source_dir],
            capture_output=True, text=True, timeout=30
        )
        candidate_files = [f.strip() for f in result.stdout.splitlines()
                          if f.strip() and not exclude_re.search(f)]
    except Exception as e:
        print(f"WARN: grep for {entity} candidates failed: {e}", file=sys.stderr)
        candidate_files = []

    # Broader fallback: grep for status = assignment pattern
    if not candidate_files:
        try:
            result = subprocess.run(
                ["grep", "-rl", "--include=*.ts", "--include=*.js", "--include=*.py",
                 f"status.*=.*['\"]\\|setStatus\\|updateStatus\\|changeStatus",
                 source_dir],
                capture_output=True, text=True, timeout=30
            )
            candidate_files = [f.strip() for f in result.stdout.splitlines()
                              if f.strip() and not exclude_re.search(f)][:20]  # cap at 20
        except Exception as e:
            print(f"WARN: broader status grep failed: {e}", file=sys.stderr)
            candidate_files = []

    print(f"INFO: {entity} — {len(candidate_files)} candidate files for A1", file=sys.stderr)

    for forbidden_t in forbidden:
        from_state = forbidden_t["from"]
        to_state = forbidden_t["to"]
        reason = forbidden_t.get("reason", "")

        if signal_count >= max_signals:
            break

        illegal_found = False
        illegal_file = ""
        illegal_line = 0
        illegal_snippet = ""

        for filepath in candidate_files:
            try:
                with open(filepath, errors="replace") as f:
                    lines = f.readlines()
            except Exception:
                continue

            # Two-pass: find lines where TO_STATE is assigned as status
            for line_idx, line in enumerate(lines):
                # Check if this line assigns TO_STATE as new status
                # Pattern: .status = 'TO_STATE' | setStatus('TO_STATE') | status: 'TO_STATE'
                if not re.search(rf"['\"]?{re.escape(to_state)}['\"]?", line):
                    continue
                if not re.search(r"status|Status|STATE|state", line):
                    continue

                # Check surrounding window (±50 lines) for FROM_STATE guard/check
                window_start = max(0, line_idx - 50)
                window_end = min(len(lines), line_idx + 10)
                window_text = "".join(lines[window_start:window_end])

                if re.search(rf"['\"]?{re.escape(from_state)}['\"]?", window_text):
                    illegal_found = True
                    illegal_file = filepath
                    illegal_line = line_idx + 1  # 1-based
                    # Build snippet: line context ±3 lines
                    snip_start = max(0, line_idx - 3)
                    snip_end = min(len(lines), line_idx + 4)
                    illegal_snippet = "".join(lines[snip_start:snip_end]).strip()[:200]
                    break

            if illegal_found:
                break

        if illegal_found:
            reason_text = f" Reason: {reason}" if reason else ""
            signals.append({
                "$schema": "signal-v2",
                "probe_id": "P-QD10-state-machine-correctness",
                "dimension_id": "QD10",
                "signal_type": "state_machine_illegal_transition",
                "severity": "high",
                "title": f"Illegal transition {from_state}→{to_state} co the thuc thi trong code: {entity}",
                "description": (
                    f"Spec dinh nghia transition {from_state}→{to_state} la FORBIDDEN cho entity '{entity}'.{reason_text} "
                    f"Tuy nhien code co doan dat status='{to_state}' trong context co the reached tu state '{from_state}'. "
                    f"Day la vi pham business rule nghiem trong — entity co the bi dua vao trang thai sai."
                ),
                "location": {
                    "entity": entity,
                    "from_state": from_state,
                    "to_state": to_state,
                    "file_path": illegal_file,
                    "line_range": [illegal_line, illegal_line]
                },
                "evidence": [
                    {
                        "type": "code_snippet",
                        "content": illegal_snippet or f"status assignment to '{to_state}' found in context with '{from_state}'"
                    }
                ],
                "dedup_key": f"P-QD10-state-machine-correctness:state_machine_illegal_transition:{entity}:{from_state}:{to_state}"
            })
            signal_count += 1
            print(f"INFO: Signal state_machine_illegal_transition: {entity} {from_state}→{to_state} at {illegal_file}:{illegal_line}", file=sys.stderr)

print(json.dumps(signals))
PYEOF
```

### A2: Missing Transition Coverage (Valid Transitions Without Handler)

```bash
# For each valid transition (from, to, action): verify action handler exists in code
# Strategy: search for function/method named after action + entity hint

python3 - << 'PYEOF'
import json, subprocess, sys, os, re, glob

specs = json.loads(os.environ.get("SPECS_JSON", "[]"))
source_dir = os.environ.get("SOURCE_DIR", "src")
exclude_re = re.compile(r"(node_modules|\.git|dist|build|__pycache__|\.spec\.|\.test\.|test/|tests/|__tests__/|mock|fixture|vendor)")
signals = []
signal_count = 0
max_signals = int(os.environ.get("MAX_SIGNALS", "100"))

for spec in specs:
    entity = spec["entity"]
    entity_hint = entity.lower()
    transitions = spec.get("transitions", [])
    terminal_states = spec.get("terminal_states", [])

    # CI-ROUTE NOTE: Nếu Serena/GitNexus available, orchestrator agent đã tìm
    # transition handlers ở S2/S3. Đây là fallback grep path.

    for t in transitions:
        from_state = t["from"]
        to_state = t["to"]
        action = t.get("action", "")

        if not action:
            continue
        if signal_count >= max_signals:
            break

        # Patterns to search for action handler:
        # 1. Function name: {action}{Entity} | {entity}{Action} | {action}_{entity}
        # 2. Method decorator: @Put('{action}') | @Post | route handler
        # 3. Direct: async {action}( | function {action}( | def {action}_
        # 4. State assignment: status = '{to_state}' in entity service files

        search_patterns = [
            # Action function named after action verb
            rf"(?:async\s+|function\s+|def\s+){re.escape(action)}[\s(]",
            rf"(?:async\s+|function\s+|def\s+){re.escape(action)}[A-Z][a-zA-Z]*[\s(]",
            # Status assignment for TO_STATE (confirms transition is implemented)
            rf"['\"]?{re.escape(to_state)}['\"]?",
            # NestJS/TypeORM decorator pattern for hooks
            rf"@Before.*['\"]?{re.escape(action)}['\"]?|@After.*['\"]?{re.escape(action)}['\"]?",
        ]

        handler_found = False
        for pattern in search_patterns:
            try:
                result = subprocess.run(
                    ["grep", "-rln", "--include=*.ts", "--include=*.js", "--include=*.py",
                     "--include=*.java", "--include=*.cs", "--include=*.go",
                     "-E", pattern, source_dir],
                    capture_output=True, text=True, timeout=15
                )
                files = [f.strip() for f in result.stdout.splitlines()
                        if f.strip() and not exclude_re.search(f)
                        and (entity_hint in f.lower() or
                             # Broader: service files
                             any(kw in f.lower() for kw in ["service", "handler", "usecase", "domain"]))]
                if files:
                    handler_found = True
                    print(f"INFO: {entity} transition {from_state}→{to_state} ({action}): handler found via pattern '{pattern}' in {files[0]}", file=sys.stderr)
                    break
            except Exception as e:
                print(f"WARN: grep for action '{action}' failed: {e}", file=sys.stderr)

        if not handler_found:
            signals.append({
                "$schema": "signal-v2",
                "probe_id": "P-QD10-state-machine-correctness",
                "dimension_id": "QD10",
                "signal_type": "state_machine_missing_transition",
                "severity": "medium",
                "title": f"Missing transition handler: {entity} {from_state}→{to_state} (action: {action})",
                "description": (
                    f"Spec dinh nghia transition hop le '{action}' tu '{from_state}' sang '{to_state}' cho entity '{entity}'. "
                    f"Tuy nhien khong tim thay handler function hoac state assignment cho transition nay trong source code. "
                    f"Co the transition chua implement, bi skip, hoac naming khong theo convention. "
                    f"Developer nen verify intentional omission truoc khi confirm la bug."
                ),
                "location": {
                    "entity": entity,
                    "from_state": from_state,
                    "to_state": to_state,
                    "file_path": None,
                    "line_range": None
                },
                "evidence": [
                    {
                        "type": "spec_ref",
                        "content": f"state-machine spec {entity}: transition {from_state}→{to_state} action='{action}' — no handler found in {source_dir}/"
                    }
                ],
                "dedup_key": f"P-QD10-state-machine-correctness:state_machine_missing_transition:{entity}:{action}"
            })
            signal_count += 1
            print(f"INFO: Signal state_machine_missing_transition: {entity} {from_state}→{to_state} action={action}", file=sys.stderr)

print(json.dumps(signals))
PYEOF
```

### A3: Aggregate Signals + Build Summary

```bash
# Merge A1 + A2 signals into SIGNALS_FILE
# (Pseudocode — orchestrator merges Python output into SIGNALS_FILE)
# A1_SIGNALS = output of A1 Python block
# A2_SIGNALS = output of A2 Python block
# ALL_SIGNALS = A1_SIGNALS + A2_SIGNALS
# For each signal: emit via jq merge into SIGNALS_FILE (REUSE emit_signal_runtime_integration pattern)

ENTITIES_ANALYZED="$SPEC_COUNT"
ILLEGAL_COUNT=$(echo "$A1_SIGNALS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo 0)
MISSING_COUNT=$(echo "$A2_SIGNALS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo 0)

LOG "INFO: A1 illegal transitions detected: $ILLEGAL_COUNT; A2 missing transitions: $MISSING_COUNT" >&2

# Build summary JSON
cat > "$RAW_DIR/P-QD10-state-machine-correctness-summary.json" << EOF
{
  "probe_id": "P-QD10-state-machine-correctness",
  "profile": "${PROFILE:-exhaustive}",
  "specs_analyzed": $ENTITIES_ANALYZED,
  "illegal_transitions_detected": $ILLEGAL_COUNT,
  "missing_transitions_detected": $MISSING_COUNT,
  "signals_emitted": $(($ILLEGAL_COUNT + $MISSING_COUNT)),
  "ci_route": {
    "gitnexus_used": $([[ "$GITNEXUS_AVAILABLE" == "true" ]] && echo "true" || echo "false"),
    "serena_used": $([[ "$SERENA_AVAILABLE" == "true" ]] && echo "true" || echo "false"),
    "grep_fallback_used": $([[ "$GITNEXUS_AVAILABLE" != "true" || "$SERENA_AVAILABLE" != "true" ]] && echo "true" || echo "false")
  }
}
EOF

LOG "INFO: summary written to $RAW_DIR/P-QD10-state-machine-correctness-summary.json" >&2
```

---

## VERIFY

```
1. Kiem tra moi signal co dimension_id == "QD10" va probe_id == "P-QD10-state-machine-correctness"
2. Kiem tra moi signal co signal_type trong ["state_machine_illegal_transition", "state_machine_missing_transition"]
3. Kiem tra moi signal co evidence[] non-empty voi content >= 10 chars
4. Kiem tra dedup_key format:
   - illegal: "P-QD10-state-machine-correctness:state_machine_illegal_transition:{entity}:{from}:{to}"
   - missing: "P-QD10-state-machine-correctness:state_machine_missing_transition:{entity}:{action}"
5. Kiem tra severity mapping:
   - state_machine_illegal_transition → high
   - state_machine_missing_transition → medium
6. Kiem tra SIGNAL_COUNT <= MAX_SIGNALS (100) hoac co WARNING "max_signals_reached"
7. Kiem tra summary JSON ton tai va co fields: specs_analyzed, illegal_transitions_detected, missing_transitions_detected

Ghi result vao lane-status.json:
  jq --arg probe "P-QD10-state-machine-correctness" \
     --arg status "completed" \
     --argjson signals $(($ILLEGAL_COUNT + $MISSING_COUNT)) \
     '.probes[$probe] = {status: $status, signals_emitted: $signals}' \
     "$LANE_DIR/lane-status.json" > "$LANE_DIR/lane-status.json.tmp" && \
     mv "$LANE_DIR/lane-status.json.tmp" "$LANE_DIR/lane-status.json"
```

---

## Severity Rules

| Dieu kien | Severity | Ly do |
|-----------|----------|-------|
| Forbidden transition co the thuc thi trong code (FROM→TO co-occurrence trong 50-line window) | **HIGH** | Vi pham business rule ro rang — entity co the bi dua vao trang thai sai lam anh huong toan bo workflow |
| Valid transition trong spec nhung khong tim thay handler function hoac state assignment | **MEDIUM** | Co the la bug (transition chua implement) hoac intentional omission — can developer confirm |
| Terminal state bi override sang non-terminal (VD: CANCELLED→DRAFT) | **HIGH** | Terminal state bi assign transition ra = vi pham contract nghiem trong — tuy FORBIDDEN check |
| State enum value trong code khong khop spec states[] (extra/missing state) | **MEDIUM** | Schema drift giua spec va code — emit neu Serena/grep tim thay enum values khac spec |

> **Rationale HIGH cho illegal transition:** forbidden_transitions trong spec la tuong minh business rule (khong phai suy luan). Code path cho phep thuc thi = definite bug, khong can developer review.
> **Rationale MEDIUM cho missing transition:** may be intentional partial implementation (e.g. admin-only flows not in standard code path, or feature flagged).

---

## Dedup Hints

| Signal Type | Dedup Key Pattern |
|-------------|------------------|
| `state_machine_illegal_transition` | `P-QD10-state-machine-correctness:state_machine_illegal_transition:{entity}:{from_state}:{to_state}` |
| `state_machine_missing_transition` | `P-QD10-state-machine-correctness:state_machine_missing_transition:{entity}:{action}` |

Cross-probe dedup: `state_machine_illegal_transition` tu W4.3 co the overlap voi `business_flow_step_unreachable` tu W4.4 khi cung entity bị chặn. Aggregator dedup boi dedup_key (probe_id+signal_type+entity+transition).

---

## Signal Schema Examples

### state_machine_illegal_transition

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD10-state-machine-correctness",
  "dimension_id": "QD10",
  "signal_type": "state_machine_illegal_transition",
  "severity": "high",
  "title": "Illegal transition CONVERTED→DRAFT co the thuc thi trong code: Quotation",
  "description": "Spec dinh nghia transition CONVERTED→DRAFT la FORBIDDEN cho entity 'Quotation'. Reason: Sau khi bao gia da duoc chuyen sang don hang (CONVERTED), khong the edit lai. Tuy nhien code co doan dat status='DRAFT' trong context co the reached tu state 'CONVERTED'. Day la vi pham business rule nghiem trong.",
  "location": {
    "entity": "Quotation",
    "from_state": "CONVERTED",
    "to_state": "DRAFT",
    "file_path": "apps/quotation/src/services/quotation.service.ts",
    "line_range": [142, 142]
  },
  "evidence": [
    {
      "type": "code_snippet",
      "content": "if (quotation.status === 'CONVERTED') {\n  // Admin override — should not be possible\n  quotation.status = 'DRAFT';\n  await this.quotationRepo.save(quotation);\n}"
    }
  ],
  "dedup_key": "P-QD10-state-machine-correctness:state_machine_illegal_transition:Quotation:CONVERTED:DRAFT"
}
```

### state_machine_missing_transition

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD10-state-machine-correctness",
  "dimension_id": "QD10",
  "signal_type": "state_machine_missing_transition",
  "severity": "medium",
  "title": "Missing transition handler: Quotation ACCEPTED→CONVERTED (action: convert_to_order)",
  "description": "Spec dinh nghia transition hop le 'convert_to_order' tu 'ACCEPTED' sang 'CONVERTED' cho entity 'Quotation'. Tuy nhien khong tim thay handler function hoac state assignment cho transition nay trong source code. Co the transition chua implement hoac naming khong theo convention.",
  "location": {
    "entity": "Quotation",
    "from_state": "ACCEPTED",
    "to_state": "CONVERTED",
    "file_path": null,
    "line_range": null
  },
  "evidence": [
    {
      "type": "spec_ref",
      "content": "state-machine spec Quotation: transition ACCEPTED→CONVERTED action='convert_to_order' — no handler found in apps/"
    }
  ],
  "dedup_key": "P-QD10-state-machine-correctness:state_machine_missing_transition:Quotation:convert_to_order"
}
```

---

## Fallback Table

| Tinh huong | Hanh vi |
|------------|---------|
| profile != exhaustive | SKIP probe, emit note "skipped_profile_not_exhaustive" → exit 0 |
| Khong co `.mc-data/docs/phase3-architecture/state-machines/*.yaml` | SKIP probe, emit WARN "skipped_no_state_machine_specs" → exit 0 |
| YAML parse error / jsonschema validation fail | ERROR E107 + exit 1 — invalid spec la blocker (P1 Correctness) |
| Python3 unavailable | ERROR: "python3 required for YAML parsing" + suggest `pip install pyyaml jsonschema` → exit 1 |
| PyYAML package unavailable | ERROR E107 + suggest `pip install pyyaml` → exit 1 |
| SOURCE_DIR khong ton tai | WARN + fallback SOURCE_DIR=./ — probe tiep tuc voi reduced coverage |
| GitNexus unavailable | LOG WARN — fallback grep, khong block |
| Serena unavailable | LOG WARN — fallback grep for state enum, khong block |
| Entity trong spec khong tim thay trong source code | LOG WARN "entity_not_in_source:{entity}" — skip coverage check cho entity, tiep tuc |
| forbidden_transitions[] rong trong spec | Skip A1 cho entity, tiep tuc A2 — khong phai error |
| > 100 signals | Stop emitting, LOG WARN "max_signals_reached (100)" |
| summary JSON write fail | LOG WARN — khong block probe |

---

## Cache Policy

**allowed** — probe nay la pure static analysis (grep + YAML parse — KHONG co browser, DB, or live API call).

Cache TTL: 24h (per `plans/wf-fix-bugs-v9/03-reuse-ci-parallelism.md` §3.5).

Ly do: State machine spec + source code khong thay doi tru khi co git commit. Cache hieu qua khi chay exhaustive consecutively. Key: `{PROJECT_ROOT_SHA}:{spec_dir_mtime}:{source_dir_mtime}`.

---

## Profile-Resolver Entry

```yaml
# Trong procedures/probes/_shared.md (QD10 Profile-Resolver section):
P-QD10-state-machine-correctness:
  quick: skip
  standard: skip
  deep: skip
  exhaustive: run
  parallel_class: static
  optional: false
  requires: [".mc-data/docs/phase3-architecture/state-machines/*.yaml"]
  note: "Requires YAML spec files authored during /wf-design phase. Skip if no specs exist."
```

---

## Acceptance Test

**Synthetic test:**

1. Tao spec `.mc-data/docs/phase3-architecture/state-machines/quotation-test.yaml`:
   ```yaml
   entity: Quotation
   version: "1.0.0"
   states: [DRAFT, SUBMITTED, ACCEPTED, CONVERTED, REJECTED]
   initial_state: DRAFT
   terminal_states: [CONVERTED, REJECTED]
   transitions:
     - {from: DRAFT, to: SUBMITTED, action: submit, role: sales_rep}
     - {from: SUBMITTED, to: ACCEPTED, action: approve, role: sales_manager}
     - {from: ACCEPTED, to: CONVERTED, action: convert_to_order, role: sales_rep}
   forbidden_transitions:
     - {from: CONVERTED, to: DRAFT, reason: "Sau khi convert, khong the edit lai"}
   ```

2. Tao synthetic source file `apps/quotation/src/services/quotation.service.ts` voi illegal path:
   ```typescript
   if (quotation.status === 'CONVERTED') {
     quotation.status = 'DRAFT';  // illegal: forbidden transition
   }
   ```

3. Chay probe voi `--profile=exhaustive`

4. **Expected:**
   - Signal `state_machine_illegal_transition` HIGH cho `CONVERTED→DRAFT` → **PASS**
   - Signal `state_machine_missing_transition` MEDIUM cho `submit`, `approve` (neu handlers khong exist)
   - `jq 'select(.signal_type == "state_machine_illegal_transition") | .severity' "$SIGNALS_FILE"` → `"high"`

**EUREKA acceptance (W4.6 / W4.E2E):**
- Run `/wf-fix-bugs --lane=QD10 --profile=exhaustive` tren EUREKA co Quotation spec
- Expect: Probe phat hien >= 1 check (either clean PASS hoac signal voi evidence ro rang)
- Expect: Summary JSON co `specs_analyzed >= 1`
- Performance: probe complete trong <= 3 phut cho 3 entity specs (static — nhanh)
