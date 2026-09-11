# P-QD10-auth-matrix-check — Authorization Matrix Guard Coverage

> **Type:** static | **Profile:** exhaustive | **Cache:** allowed (static per code state)
> **Parallel class:** static → parallel (max 3 concurrent static probes)
> **Signal types:** `auth_matrix_missing_guard` (HIGH), `auth_matrix_over_permissive` (MEDIUM)
> **Error codes:** E100 (QD10 generic), E108 (auth-matrix YAML parse error)

Kiem tra code co role guard dung cho moi action duoc dinh nghia trong spec `.mc-data/docs/phase3-architecture/auth-matrix/*.yaml`. Voi moi action trong tung module: (1) Phat hien **missing guard** — action can phan quyen nhung khong co role check trong code (HIGH); (2) Phat hien **over-permissive guard** — code cho phep role bi cam tuong minh trong spec (MEDIUM). CI-ROUTE PRIMARY: **Serena** `find_symbol({name_path_pattern: "AuthGuard|RolesGuard|hasRole"})` de tim guard declaration; **GitNexus** `query("authorization role guard {module_id}")` de trace auth flow. Fallback: grep `@Roles(`, `hasRole(`, `@UseGuards(`, `permission_required` patterns. YAML parsing: Python3 + PyYAML.

---

## Reuses from

| Aspect | Source | File:line | Notes |
|--------|--------|-----------|-------|
| Python3 YAML parse + jsonschema validate | `P-QD10-state-machine-correctness.md` | `PRE-GATE step 3` | Python3 `yaml.safe_load()` + `jsonschema.validate()` pattern — exact reuse |
| PRE-GATE glob spec files | `P-QD10-state-machine-correctness.md` | `PRE-GATE step 2` | `find "spec_dir" -name "*.yaml"` → SKIP if 0 |
| CI detect load | `P-QD9-spa-route-coverage.md` | `PRE-GATE step 5` | `source <(bash ci-detect.sh ...)` → `SERENA_AVAILABLE/GITNEXUS_AVAILABLE` |
| Common variables (LANE_DIR, SIGNALS_FILE) | `procedures/probes/_shared.md` | `:7-21` | Lane path constants |
| emit_signal_cross_module (QD10 cross-module form) | `procedures/probes/_shared.md` | `:48-95` | Adapted: provider_module=action owner, consumer_module=role |
| Source patterns (service/domain/handler dirs) | `P-QD10-state-machine-correctness.md` | `THINK` | `SOURCE_PATTERNS` array + `EXCLUDE_RE` |
| grep candidate files (entity hint) | `P-QD10-state-machine-correctness.md` | `ACT A1` | Heuristic file discovery via grep entity name |
| Sampling + emit_sampling_note | `procedures/probes/_shared.md` | `:176-191` | When action_count > 50 → priority sampling |

**Diff so voi cac probe QD10 khac:**
- Doc spec tu `auth-matrix/` (khong phai `state-machines/` hay `business-flows/`)
- Probe kiem tra SECURITY property (role guard = authorization, khong phai state machine hay business logic)
- `roles_allowed == ['*']` = public action → probe SKIP (khong can guard)
- Signal `auth_matrix_missing_guard` la HIGH vi missing auth = security vulnerability
- Missing guard = bat ky role nao cung co the thuc hien action bi han che

---

## CI-ROUTE

| Task | CI Tool (Primary) | Fallback | Purpose |
|------|-------------------|----------|---------|
| Tim guard declaration / decorator | **Serena** `find_symbol({name_path_pattern: "AuthGuard|RolesGuard|PermissionGuard|hasRole", include_body: true})` | Grep `@UseGuards\|@Roles\|hasRole\|permission_required` | Xac minh guard class/function ton tai trong codebase |
| Trace auth flow cho module | **GitNexus** `query("authorization role guard {module_id}")` | Grep decorator patterns tren route/controller files | Tim tat ca endpoints co / khong co guard trong module |
| Tim route/controller files cua module | **Serena** `find_symbol({name_path_pattern: "{module_hint}.controller\|{module_hint}.router"})` | Glob `**/{module_hint}*.controller.{ts,js,py,java}` | Locate files chua action endpoints |
| Blast radius khi guard logic thay doi | **GitNexus** `impact({target: "RolesGuard", direction: "upstream"})` | Manual grep | Pre-flight truoc khi report |

**Khi CI unavailable:**
```bash
if [[ "$GITNEXUS_AVAILABLE" != "true" ]]; then
  echo "WARN: GitNexus unavailable — fallback to grep for guard patterns" >&2
fi
if [[ "$SERENA_AVAILABLE" != "true" ]]; then
  echo "WARN: Serena unavailable — fallback to grep for guard declarations" >&2
fi
```

---

## PRE-GATE

```
1. IF profile != exhaustive:
     SKIP probe — emit note "skipped_profile_not_exhaustive"
     LOG "INFO: P-QD10-auth-matrix-check requires profile=exhaustive (auth matrix specs are deep security artifacts)" >&2
     → exit 0

2. Glob auth matrix spec files:
     SPEC_FILES=$(find ".mc-data/docs/phase3-architecture/auth-matrix" -name "*.yaml" 2>/dev/null | sort)
     SPEC_COUNT=$(echo "$SPEC_FILES" | grep -c . 2>/dev/null || echo 0)
     IF SPEC_COUNT == 0:
       SKIP probe — emit note "skipped_no_auth_matrix_specs"
       emit WARN: "P-QD10-auth-matrix-check requires .mc-data/docs/phase3-architecture/auth-matrix/*.yaml specs. Author via /wf-design (authorization matrix section) using schema .claude/doc-framework/_meta/authorization-matrix-schema.json."
       → exit 0

3. Validate YAML spec files (Python3 + jsonschema):
     SCHEMA_FILE=".claude/doc-framework/_meta/authorization-matrix-schema.json"
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
         LOG "ERROR: E108 — YAML parse or schema validation failed for $spec" >&2
         exit 1
       }
     done

4. Load CI availability (REUSE: P-QD9-spa-route-coverage.md PRE-GATE step 5):
     source <(bash .claude/scripts/ci-detect.sh --project-root "$PROJECT_ROOT" 2>/dev/null) || true
     GITNEXUS_AVAILABLE="${GITNEXUS_AVAILABLE:-false}"
     SERENA_AVAILABLE="${SERENA_AVAILABLE:-false}"

5. Detect SOURCE_DIR (REUSE: P-QD10-state-machine-correctness.md PRE-GATE step 5):
     SOURCE_DIR="${SOURCE_DIR:-src}"
     IF [ ! -d "$SOURCE_DIR" ]; then SOURCE_DIR="apps"; fi
     IF [ ! -d "$SOURCE_DIR" ]; then
       SOURCE_DIR="."
       LOG "WARN: source_dir_fallback=. (khong tim thay src/ hoac apps/)" >&2
     fi

6. Ensure RAW_DIR + LANE_DIR exist:
     mkdir -p "$RAW_DIR" "$LANE_DIR"
```

---

## SENSE

### S1: Load Authorization Matrix Specs

```bash
# Parse tung YAML spec voi Python3
SPECS_JSON=$(python3 - << 'PYEOF'
import yaml, json, sys, os, glob

specs = []
spec_dir = ".mc-data/docs/phase3-architecture/auth-matrix"
spec_files = sorted(glob.glob(f"{spec_dir}/*.yaml"))

for path in spec_files:
    try:
        with open(path) as f:
            data = yaml.safe_load(f)
        # Flatten modules + actions for probe processing
        modules = []
        for m in data.get("modules", []):
            module_id = m.get("module_id", "")
            actions = []
            for a in m.get("actions", []):
                actions.append({
                    "action": a.get("action", ""),
                    "description": a.get("description", ""),
                    "roles_allowed": a.get("roles_allowed", []),
                    "roles_forbidden": a.get("roles_forbidden", []),
                    "guard_hint": a.get("guard_hint", ""),
                    "public": a.get("public", False)
                })
            modules.append({
                "module_id": module_id,
                "actions": actions
            })
        specs.append({
            "file": path,
            "matrix_id": data.get("matrix_id", ""),
            "version": data.get("version", ""),
            "roles": [r.get("id", "") for r in data.get("roles", [])],
            "modules": modules
        })
    except Exception as e:
        print(f"WARN: Could not parse {path}: {e}", file=sys.stderr)

print(json.dumps(specs))
PYEOF
)

TOTAL_ACTIONS=$(echo "$SPECS_JSON" | python3 -c "
import json, sys
specs = json.load(sys.stdin)
total = sum(len(a['actions']) for s in specs for a in s['modules'])
print(total)
" 2>/dev/null || echo 0)

LOG "INFO: Loaded $SPEC_COUNT auth matrix spec(s); total actions to check: $TOTAL_ACTIONS" >&2
```

### S2: CI-ROUTE — Discover Guard Declarations (Serena PRIMARY)

```bash
# Find guard classes/functions/decorators in codebase — evidence that auth framework exists
# CI-ROUTE PRIMARY: Serena find_symbol

if [[ "$SERENA_AVAILABLE" == "true" ]]; then
  # (Pseudocode — orchestrator agent thuc hien via Serena MCP):
  # GUARD_SYMBOLS = serena_find_symbol({
  #   name_path_pattern: "AuthGuard|RolesGuard|PermissionGuard|RoleGuard|hasRole|requireRole",
  #   include_body: false
  # })
  # GUARD_FILES = unique file paths from GUARD_SYMBOLS
  # LOG "INFO: Serena found guard declarations in {N} files" >&2
  # GUARD_FRAMEWORK = detect from symbol names:
  #   NestJS: @UseGuards, @Roles
  #   Express: requireRole, checkPermission
  #   Django/FastAPI: permission_required, Depends
  #   Spring: @PreAuthorize, @Secured
  LOG "INFO: Serena available — guard declaration discovery via find_symbol (orchestrator executes)" >&2
else
  LOG "INFO: Serena unavailable — fallback grep for guard patterns" >&2
fi
```

### S3: CI-ROUTE — Trace Authorization Flow (GitNexus PRIMARY)

```bash
# Discover which endpoints/handlers have / don't have authorization guards
# CI-ROUTE PRIMARY: GitNexus query

if [[ "$GITNEXUS_AVAILABLE" == "true" ]]; then
  # (Pseudocode — orchestrator agent thuc hien via GitNexus MCP):
  # For each module_id in spec:
  #   AUTH_FLOWS = gitnexus_query({query: "authorization role guard {module_id}"})
  #   GUARDED_FILES = extract file paths of handlers WITH guards (process-grouped)
  #   LOG "INFO: GitNexus auth flows for {module_id}: {N} guarded symbols" >&2
  LOG "INFO: GitNexus available — auth flow discovery via query (orchestrator executes per module)" >&2
else
  LOG "INFO: GitNexus unavailable — fallback grep for decorator patterns" >&2
fi
```

---

## THINK

```bash
# Build analysis plan per module per action
SIGNAL_COUNT=0
MAX_SIGNALS=100
TOTAL_CHECKED=0
TOTAL_MISSING_GUARD=0
TOTAL_OVER_PERMISSIVE=0
TOTAL_PUBLIC_SKIP=0
TOTAL_GUARD_OK=0

# Source patterns cho route/controller/handler/service files
SOURCE_PATTERNS=(
  "$SOURCE_DIR/**/controller/**/*.{ts,js,py,java,cs,go}"
  "$SOURCE_DIR/**/controllers/**/*.{ts,js,py,java,cs,go}"
  "$SOURCE_DIR/**/handler/**/*.{ts,js,py,java,cs,go}"
  "$SOURCE_DIR/**/handlers/**/*.{ts,js,py,java,cs,go}"
  "$SOURCE_DIR/**/router/**/*.{ts,js,py,java,cs,go}"
  "$SOURCE_DIR/**/routes/**/*.{ts,js,py,java,cs,go}"
  "$SOURCE_DIR/**/service/**/*.{ts,js,py,java,cs,go}"
  "$SOURCE_DIR/**/services/**/*.{ts,js,py,java,cs,go}"
)
EXCLUDE_RE="(node_modules|\.git|dist|build|__pycache__|\.spec\.|\.test\.|test/|tests/|__tests__/|mock|fixture|vendor)"

# Guard patterns by framework — multi-framework support
GUARD_PATTERNS=(
  "@Roles("           # NestJS @Roles decorator
  "@UseGuards("       # NestJS @UseGuards decorator (generic)
  "hasRole("          # Express/generic hasRole middleware
  "requireRole("      # Express/generic requireRole middleware
  "@PreAuthorize("    # Spring Security @PreAuthorize
  "@Secured("         # Spring @Secured
  "permission_required("  # Django permission_required
  "IsAdminUser"       # Django REST framework permission class
  "RolesAllowed("     # JAX-RS @RolesAllowed
  "Authorize("        # ASP.NET [Authorize]
  "[Authorize("       # ASP.NET [Authorize(Roles=...)]
  "PermissionRequired("  # Generic permission required
  "checkPermission("  # Generic check permission
)

# Priority sampling: khi TOTAL_ACTIONS > 50 → uu tien actions co roles_forbidden
# Consistent voi _shared.md sampling policy
LOG "INFO: THINK: $TOTAL_ACTIONS actions to analyze across $SPEC_COUNT spec(s)" >&2
```

---

## ACT

### A1: Missing Guard Detection (Role-Restricted Actions Without Guard)

```bash
# For each action that is NOT public AND roles_allowed != ['*']:
# Find handler/route file for action, check surrounding code for guard patterns
# Emit auth_matrix_missing_guard if no guard found

python3 - << 'PYEOF'
import json, subprocess, sys, os, re, glob

specs = json.loads(os.environ.get("SPECS_JSON", "[]"))
source_dir = os.environ.get("SOURCE_DIR", "src")
exclude_re = re.compile(r"(node_modules|\.git|dist|build|__pycache__|\.spec\.|\.test\.|test/|tests/|__tests__/|mock|fixture|vendor)")

# Guard patterns — cross-framework (reuse from THINK)
GUARD_PATTERNS = [
    r"@Roles\s*\(",
    r"@UseGuards\s*\(",
    r"hasRole\s*\(",
    r"requireRole\s*\(",
    r"@PreAuthorize\s*\(",
    r"@Secured\s*\(",
    r"permission_required\s*\(",
    r"IsAdminUser|IsAuthenticated|AllowAny",
    r"RolesAllowed\s*\(",
    r"\[?Authorize\s*\(",
    r"PermissionRequired\s*\(",
    r"checkPermission\s*\(",
    r"canActivate\s*\(",          # NestJS guard interface
    r"Depends\s*\(.*current_user|Depends\s*\(.*get_current",  # FastAPI
]
GUARD_RE = re.compile("|".join(GUARD_PATTERNS), re.IGNORECASE)

signals = []
signal_count = 0
max_signals = int(os.environ.get("MAX_SIGNALS", "100"))

for spec in specs:
    for module in spec["modules"]:
        module_id = module["module_id"]
        # Derive module hint for file discovery: MOD-CRM → crm, MOD-QUOTATION → quotation
        module_hint = module_id.replace("MOD-", "").lower().replace("-", "_")

        for action_spec in module["actions"]:
            action = action_spec["action"]
            roles_allowed = action_spec.get("roles_allowed", [])
            roles_forbidden = action_spec.get("roles_forbidden", [])
            is_public = action_spec.get("public", False)

            # Skip public actions (no guard needed)
            if is_public or roles_allowed == ["*"]:
                print(f"INFO: {module_id}/{action}: public/allow-all → SKIP guard check", file=sys.stderr)
                continue

            if signal_count >= max_signals:
                break

            # Step 1: Find candidate files for this module+action
            # Strategy 1: grep for action name in source files containing module hint
            candidate_files = []
            action_hint = action.replace("_", "[-_]?")

            try:
                result = subprocess.run(
                    ["grep", "-rl", "--include=*.ts", "--include=*.js", "--include=*.py",
                     "--include=*.java", "--include=*.cs", "--include=*.go",
                     "-E", f"{re.escape(action)}|{action_hint}",
                     source_dir],
                    capture_output=True, text=True, timeout=20
                )
                all_files = [f.strip() for f in result.stdout.splitlines()
                             if f.strip() and not exclude_re.search(f)]
                # Priority: files containing module hint
                candidate_files = [f for f in all_files if module_hint in f.lower()]
                # Fallback: controller/handler/route files among all matches
                if not candidate_files:
                    candidate_files = [f for f in all_files
                                       if any(kw in f.lower() for kw in ["controller", "handler", "router", "route", "service"])][:10]
            except Exception as e:
                print(f"WARN: grep for {module_id}/{action} candidates failed: {e}", file=sys.stderr)
                candidate_files = []

            if not candidate_files:
                # No implementation file found → skip (action may not be implemented yet)
                print(f"INFO: {module_id}/{action}: no candidate files found → SKIP (action may not be implemented)", file=sys.stderr)
                continue

            print(f"INFO: {module_id}/{action}: {len(candidate_files)} candidate files", file=sys.stderr)

            # Step 2: For each candidate file, check ±30 lines around action mention for guard pattern
            guard_found = False
            guard_file = ""
            guard_evidence = ""

            for filepath in candidate_files[:5]:  # cap at 5 files
                try:
                    with open(filepath, errors="replace") as f:
                        content = f.read()
                        lines = content.splitlines()
                except Exception:
                    continue

                # Find line with action mention
                for line_idx, line in enumerate(lines):
                    if not re.search(rf"\b{re.escape(action)}\b", line, re.IGNORECASE):
                        continue

                    # Check surrounding window (±30 lines) for guard pattern
                    window_start = max(0, line_idx - 30)
                    window_end = min(len(lines), line_idx + 5)
                    window_text = "\n".join(lines[window_start:window_end])

                    if GUARD_RE.search(window_text):
                        guard_found = True
                        guard_file = filepath
                        # Extract guard evidence line
                        for wline in lines[window_start:window_end]:
                            if GUARD_RE.search(wline):
                                guard_evidence = wline.strip()[:100]
                                break
                        break

                if guard_found:
                    break

            if not guard_found:
                # Check if the WHOLE file has any guard at all (class-level guard)
                for filepath in candidate_files[:5]:
                    try:
                        with open(filepath, errors="replace") as f:
                            full_content = f.read()
                        if GUARD_RE.search(full_content):
                            guard_found = True
                            guard_file = filepath
                            guard_evidence = "(class-level guard detected in file)"
                            break
                    except Exception:
                        continue

            if not guard_found:
                # Emit missing guard signal
                roles_str = ", ".join(roles_allowed[:5])
                signals.append({
                    "$schema": "signal-v2",
                    "probe_id": "P-QD10-auth-matrix-check",
                    "dimension_id": "QD10",
                    "signal_type": "auth_matrix_missing_guard",
                    "severity": "high",
                    "title": f"Missing role guard: {module_id}/{action} (cho phep chi: {roles_str})",
                    "description": (
                        f"Authorization matrix dinh nghia action '{action}' trong module '{module_id}' "
                        f"chi duoc phep boi roles: [{roles_str}]. "
                        f"Tuy nhien khong tim thay role guard pattern nao trong {len(candidate_files)} file(s) tim duoc. "
                        f"Day la lo hong bao mat nghiem trong — bat ky role nao cung co the thuc hien action nay."
                    ),
                    "location": {
                        "module_id": module_id,
                        "action": action,
                        "roles_required": roles_allowed,
                        "file_path": candidate_files[0] if candidate_files else None,
                        "line_range": None
                    },
                    "evidence": [
                        {
                            "type": "missing_guard",
                            "content": (
                                f"Auth matrix spec: {module_id}/{action} requires roles [{roles_str}]. "
                                f"Guard patterns searched: @Roles, @UseGuards, hasRole, requireRole, @PreAuthorize, @Secured, permission_required. "
                                f"Checked {len(candidate_files)} file(s): {', '.join(candidate_files[:3])}"
                            )
                        }
                    ],
                    "dedup_key": f"P-QD10-auth-matrix-check:auth_matrix_missing_guard:{module_id}:{action}"
                })
                signal_count += 1
                print(f"INFO: Signal auth_matrix_missing_guard: {module_id}/{action} — no guard found", file=sys.stderr)
            else:
                print(f"INFO: {module_id}/{action}: guard OK at {guard_file} — '{guard_evidence}'", file=sys.stderr)

            # Step 3: Over-permissive check (roles_forbidden defined in spec)
            if roles_forbidden and guard_found and guard_file:
                # Check if code explicitly allows a forbidden role
                # Pattern: @Roles('role_that_should_be_forbidden')
                for forbidden_role in roles_forbidden[:3]:  # cap at 3 to avoid noise
                    try:
                        with open(guard_file, errors="replace") as f:
                            file_content = f.read()
                        # Simple heuristic: guard decorator mentions forbidden role
                        # Pattern: @Roles('sales_rep') | hasRole('sales_rep') | @Secured('ROLE_SALES_REP')
                        forbidden_role_re = re.compile(
                            rf"@Roles[^)]*['\"]?{re.escape(forbidden_role)}['\"]?[^)]*\)"
                            rf"|hasRole\s*\(\s*['\"]?{re.escape(forbidden_role)}['\"]?\s*\)"
                            rf"|@Secured[^)]*['\"]?ROLE_{re.escape(forbidden_role.upper())}['\"]?",
                            re.IGNORECASE
                        )
                        if forbidden_role_re.search(file_content):
                            # Additional check: ensure this is near the action (not some other handler)
                            lines = file_content.splitlines()
                            for line_idx, line in enumerate(lines):
                                if not re.search(rf"\b{re.escape(action)}\b", line, re.IGNORECASE):
                                    continue
                                win_start = max(0, line_idx - 20)
                                win_end = min(len(lines), line_idx + 5)
                                win_text = "\n".join(lines[win_start:win_end])
                                if forbidden_role_re.search(win_text):
                                    match = forbidden_role_re.search(win_text)
                                    signals.append({
                                        "$schema": "signal-v2",
                                        "probe_id": "P-QD10-auth-matrix-check",
                                        "dimension_id": "QD10",
                                        "signal_type": "auth_matrix_over_permissive",
                                        "severity": "medium",
                                        "title": f"Over-permissive guard: {module_id}/{action} cho phep role '{forbidden_role}' bi cam trong spec",
                                        "description": (
                                            f"Authorization matrix dinh nghia role '{forbidden_role}' la FORBIDDEN cho action '{action}' trong module '{module_id}'. "
                                            f"Tuy nhien code co guard pattern cho phep role nay. "
                                            f"Co the guard logic bi cau hinh sai hoac roles_forbidden trong spec chua duoc review."
                                        ),
                                        "location": {
                                            "module_id": module_id,
                                            "action": action,
                                            "forbidden_role": forbidden_role,
                                            "file_path": guard_file,
                                            "line_range": None
                                        },
                                        "evidence": [
                                            {
                                                "type": "code_snippet",
                                                "content": match.group(0)[:100] if match else f"guard allows '{forbidden_role}' near action '{action}'"
                                            }
                                        ],
                                        "dedup_key": f"P-QD10-auth-matrix-check:auth_matrix_over_permissive:{module_id}:{action}:{forbidden_role}"
                                    })
                                    signal_count += 1
                                    print(f"INFO: Signal auth_matrix_over_permissive: {module_id}/{action} — role '{forbidden_role}' allowed in code but forbidden in spec", file=sys.stderr)
                                    break
                    except Exception as e:
                        print(f"WARN: over-permissive check for {forbidden_role} failed: {e}", file=sys.stderr)

print(json.dumps(signals))
PYEOF
```

### A2: Aggregate Signals + Build Summary

```bash
# Merge signals into SIGNALS_FILE (REUSE emit pattern from _shared.md)
# AUTH_SIGNALS = output of A1 Python block

MISSING_COUNT=$(echo "$AUTH_SIGNALS" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(len([s for s in d if s.get('signal_type') == 'auth_matrix_missing_guard']))
" 2>/dev/null || echo 0)

OVER_PERMISSIVE_COUNT=$(echo "$AUTH_SIGNALS" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(len([s for s in d if s.get('signal_type') == 'auth_matrix_over_permissive']))
" 2>/dev/null || echo 0)

TOTAL_SIGNALS=$(($MISSING_COUNT + $OVER_PERMISSIVE_COUNT))

# Merge AUTH_SIGNALS into SIGNALS_FILE
echo "$AUTH_SIGNALS" | python3 - << 'PYEOF'
import json, sys, os

new_signals = json.load(sys.stdin)
signals_file = os.environ.get("SIGNALS_FILE", "")
if not signals_file:
    print("ERROR: SIGNALS_FILE not set", file=sys.stderr)
    sys.exit(1)

try:
    with open(signals_file) as f:
        existing = json.load(f)
except Exception:
    existing = []

merged = existing + new_signals
# Dedup by dedup_key
seen = set()
deduped = []
for s in merged:
    dk = s.get("dedup_key", "")
    if dk and dk in seen:
        continue
    seen.add(dk)
    deduped.append(s)

with open(signals_file + ".tmp", "w") as f:
    json.dump(deduped, f, indent=2, ensure_ascii=False)
os.replace(signals_file + ".tmp", signals_file)
print(f"INFO: signals.json updated — total: {len(deduped)} (added {len(new_signals)})", file=sys.stderr)
PYEOF

LOG "INFO: A1 missing guards: $MISSING_COUNT; over-permissive: $OVER_PERMISSIVE_COUNT" >&2

# Build summary JSON
cat > "$RAW_DIR/P-QD10-auth-matrix-check-summary.json" << EOF
{
  "probe_id": "P-QD10-auth-matrix-check",
  "profile": "${PROFILE:-exhaustive}",
  "specs_analyzed": $SPEC_COUNT,
  "total_actions_checked": $TOTAL_ACTIONS,
  "missing_guards_detected": $MISSING_COUNT,
  "over_permissive_detected": $OVER_PERMISSIVE_COUNT,
  "signals_emitted": $TOTAL_SIGNALS,
  "ci_route": {
    "gitnexus_used": $([[ "$GITNEXUS_AVAILABLE" == "true" ]] && echo "true" || echo "false"),
    "serena_used": $([[ "$SERENA_AVAILABLE" == "true" ]] && echo "true" || echo "false"),
    "grep_fallback_used": $([[ "$GITNEXUS_AVAILABLE" != "true" || "$SERENA_AVAILABLE" != "true" ]] && echo "true" || echo "false")
  }
}
EOF

LOG "INFO: summary written to $RAW_DIR/P-QD10-auth-matrix-check-summary.json" >&2
```

---

## VERIFY

```
1. Kiem tra moi signal co dimension_id == "QD10" va probe_id == "P-QD10-auth-matrix-check"
2. Kiem tra moi signal co signal_type trong ["auth_matrix_missing_guard", "auth_matrix_over_permissive"]
3. Kiem tra moi signal co evidence[] non-empty voi content >= 10 chars
4. Kiem tra dedup_key format:
   - missing_guard: "P-QD10-auth-matrix-check:auth_matrix_missing_guard:{module_id}:{action}"
   - over_permissive: "P-QD10-auth-matrix-check:auth_matrix_over_permissive:{module_id}:{action}:{role}"
5. Kiem tra severity mapping:
   - auth_matrix_missing_guard → high
   - auth_matrix_over_permissive → medium
6. Kiem tra SIGNAL_COUNT <= MAX_SIGNALS (100) hoac co WARNING "max_signals_reached"
7. Kiem tra summary JSON ton tai va co fields: specs_analyzed, total_actions_checked, missing_guards_detected

Ghi result vao lane-status.json:
  jq --arg probe "P-QD10-auth-matrix-check" \
     --arg status "completed" \
     --argjson signals $TOTAL_SIGNALS \
     '.probes[$probe] = {status: $status, signals_emitted: $signals}' \
     "$LANE_DIR/lane-status.json" > "$LANE_DIR/lane-status.json.tmp" && \
     mv "$LANE_DIR/lane-status.json.tmp" "$LANE_DIR/lane-status.json"
```

---

## Severity Rules

| Dieu kien | Severity | Ly do |
|-----------|----------|-------|
| Action can phan quyen (roles_allowed != ['*'] va khong public) nhung khong tim thay guard pattern trong code | **HIGH** | Security vulnerability ro rang — bat ky user nao cung co the thuc hien action bi han che |
| Code co guard pattern nhung cho phep role bi cam tuong minh trong spec (roles_forbidden) | **MEDIUM** | Over-permissive guard — co the la intentional (spec sai) hoac bug; can developer review |
| Action duoc danh dau public=true hoac roles_allowed=['*'] | SKIP | Khong can guard |
| File implementation khong tim thay | SKIP + WARN | Action chua implement hoac naming convention khac biet; KHONG emit HIGH vi false positive risk cao |

> **Rationale HIGH cho missing guard:** Authorization spec la security contract tuong minh. Missing guard = direct security vulnerability (Broken Access Control — OWASP Top 10 #1). Probe nay KHONG bao gio downgrade HIGH.
> **Rationale MEDIUM cho over-permissive:** Can developer confirm — spec co the outdated; code co the dung (e.g. legacy role name). Developer review truoc khi close.
> **Rationale SKIP khi khong tim thay file:** Probe chi kiem tra code co implement; neu action chua implement → false positive nếu emit. Probe uu tien correctness (P1) over recall.

---

## Dedup Hints

| Signal Type | Dedup Key Pattern |
|-------------|------------------|
| `auth_matrix_missing_guard` | `P-QD10-auth-matrix-check:auth_matrix_missing_guard:{module_id}:{action}` |
| `auth_matrix_over_permissive` | `P-QD10-auth-matrix-check:auth_matrix_over_permissive:{module_id}:{action}:{forbidden_role}` |

Cross-probe dedup: `auth_matrix_missing_guard` co the overlap voi `business_flow_step_failed` (W4.4) neu flow that bai vi authorization error. Aggregator dedup by dedup_key.

---

## Signal Schema Examples

### auth_matrix_missing_guard

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD10-auth-matrix-check",
  "dimension_id": "QD10",
  "signal_type": "auth_matrix_missing_guard",
  "severity": "high",
  "title": "Missing role guard: MOD-FINANCE/approve_invoice (cho phep chi: manager, sysadmin)",
  "description": "Authorization matrix dinh nghia action 'approve_invoice' trong module 'MOD-FINANCE' chi duoc phep boi roles: [manager, sysadmin]. Tuy nhien khong tim thay role guard pattern nao trong 3 file(s) tim duoc. Day la lo hong bao mat nghiem trong — bat ky role nao cung co the phe duyet hoa don.",
  "location": {
    "module_id": "MOD-FINANCE",
    "action": "approve_invoice",
    "roles_required": ["manager", "sysadmin"],
    "file_path": "apps/finance/src/controllers/invoice.controller.ts",
    "line_range": null
  },
  "evidence": [
    {
      "type": "missing_guard",
      "content": "Auth matrix spec: MOD-FINANCE/approve_invoice requires roles [manager, sysadmin]. Guard patterns searched: @Roles, @UseGuards, hasRole, requireRole, @PreAuthorize, @Secured, permission_required. Checked 3 file(s): apps/finance/src/controllers/invoice.controller.ts"
    }
  ],
  "dedup_key": "P-QD10-auth-matrix-check:auth_matrix_missing_guard:MOD-FINANCE:approve_invoice"
}
```

### auth_matrix_over_permissive

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD10-auth-matrix-check",
  "dimension_id": "QD10",
  "signal_type": "auth_matrix_over_permissive",
  "severity": "medium",
  "title": "Over-permissive guard: MOD-QUOTATION/approve_quotation cho phep role 'sales_rep' bi cam trong spec",
  "description": "Authorization matrix dinh nghia role 'sales_rep' la FORBIDDEN cho action 'approve_quotation' trong module 'MOD-QUOTATION'. Tuy nhien code co guard pattern cho phep role nay. Co the guard logic bi cau hinh sai.",
  "location": {
    "module_id": "MOD-QUOTATION",
    "action": "approve_quotation",
    "forbidden_role": "sales_rep",
    "file_path": "apps/quotation/src/controllers/quotation.controller.ts",
    "line_range": null
  },
  "evidence": [
    {
      "type": "code_snippet",
      "content": "@Roles('sales_rep', 'sales_manager', 'admin')"
    }
  ],
  "dedup_key": "P-QD10-auth-matrix-check:auth_matrix_over_permissive:MOD-QUOTATION:approve_quotation:sales_rep"
}
```

---

## Fallback Table

| Tinh huong | Hanh vi |
|------------|---------|
| profile != exhaustive | SKIP probe, emit note "skipped_profile_not_exhaustive" → exit 0 |
| Khong co `.mc-data/docs/phase3-architecture/auth-matrix/*.yaml` | SKIP probe, emit WARN "skipped_no_auth_matrix_specs" → exit 0 |
| YAML parse error / jsonschema validation fail | ERROR E108 + exit 1 — invalid spec la blocker (P1 Correctness) |
| Python3 unavailable | ERROR: "python3 required for YAML parsing" + suggest `pip install pyyaml jsonschema` → exit 1 |
| PyYAML package unavailable | ERROR E108 + suggest `pip install pyyaml` → exit 1 |
| SOURCE_DIR khong ton tai | WARN + fallback SOURCE_DIR=./ — probe tiep tuc voi reduced coverage |
| GitNexus unavailable | LOG WARN — fallback grep, khong block |
| Serena unavailable | LOG WARN — fallback grep for guard declarations, khong block |
| Action file khong tim thay trong source | SKIP action + LOG INFO "no implementation file found" — KHONG emit signal (avoid false positive) |
| roles_allowed == ['*'] hoac action.public=true | SKIP action — no guard needed (intentionally open) |
| > 100 signals | Stop emitting, LOG WARN "max_signals_reached (100)" |
| summary JSON write fail | LOG WARN — khong block probe |

---

## Cache Policy

**allowed** — probe nay la pure static analysis (grep + YAML parse — KHONG co browser, DB, or live API call).

Cache TTL: 24h (per `plans/wf-fix-bugs-v9/03-reuse-ci-parallelism.md` §3.5).

Ly do: Auth matrix spec + source code khong thay doi tru khi co git commit. Key: `{PROJECT_ROOT_SHA}:{spec_dir_mtime}:{source_dir_mtime}`.

---

## Profile-Resolver Entry

```yaml
# Trong procedures/probes/_shared.md (QD10 Profile-Resolver section):
P-QD10-auth-matrix-check:
  quick: skip
  standard: skip
  deep: skip
  exhaustive: run
  parallel_class: static
  optional: false
  requires: [".mc-data/docs/phase3-architecture/auth-matrix/*.yaml"]
  note: "Requires YAML spec files authored during /wf-design phase. Skip if no specs exist. Security check — HIGH severity for missing guards."
```

---

## Acceptance Test

**Synthetic test:**

1. Tao spec `.mc-data/docs/phase3-architecture/auth-matrix/auth-test.yaml`:
   ```yaml
   matrix_id: auth-test-v1
   version: "1.0.0"
   modules:
     - module_id: MOD-FINANCE
       actions:
         - action: approve_invoice
           roles_allowed: [manager, sysadmin]
           roles_forbidden: [accountant]
   ```

2. Tao synthetic controller file `apps/finance/src/controllers/invoice.controller.ts`:
   ```typescript
   // NO guard decorator — missing guard case
   async approveInvoice(id: string): Promise<Invoice> {
     return this.invoiceService.approve(id);
   }
   ```

3. Chay probe voi `--profile=exhaustive`

4. **Expected:**
   - Signal `auth_matrix_missing_guard` HIGH cho `MOD-FINANCE/approve_invoice` → **PASS**
   - `jq 'select(.signal_type == "auth_matrix_missing_guard") | .severity' "$SIGNALS_FILE"` → `"high"`
   - Summary JSON co `specs_analyzed: 1`, `missing_guards_detected: 1`

5. Them `@Roles('manager', 'sysadmin')` vao controller → re-run → **0 signals** (guard detected)

**EUREKA acceptance (W5.E2E):**
- Author `.mc-data/docs/phase3-architecture/auth-matrix/auth-erp-v1.yaml` (sample: `.claude/doc-framework/_meta/samples/authorization-matrix-erp-sample.yaml`)
- Run `/wf-fix-bugs --lane=QD10 --profile=exhaustive` tren EUREKA
- Expect: Probe phat hien 1+ checks (either clean PASS cho modules co guard hoac signals ro rang)
- Performance: probe complete trong <= 5 phut cho 20+ actions (static — nhanh)
