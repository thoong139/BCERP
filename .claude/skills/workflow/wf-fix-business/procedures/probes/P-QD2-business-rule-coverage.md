# P-QD2-business-rule-coverage: Business Rule Annotation Coverage

> **Probe ID:** P-QD2-business-rule-coverage
> **Type:** static
> **Depth:** exhaustive only
> **Design ref:** W4.5
> **Cache:** allowed (static scan — stable when references + code unchanged)
> **Side effects:** none (read-only)
> **CI-ROUTE:** Serena `find_referencing_symbols(rule_id)` PRIMARY | Grep FALLBACK

## Purpose

Parse `<!-- BIZ-RULE: id=R-XXX ... -->` annotations từ `.claude/references/team-expert/[domain]/*.md`.
Cho mỗi rule annotation, kiểm tra code có reference đến rule ID hoặc REQ-ID tương ứng không.
Flag rules không có code reference → emit `business_rule_uncovered` MEDIUM.

## BIZ-RULE Annotation Format

```html
<!-- BIZ-RULE: id=R-FINANCE-001 entity=Invoice action=approve req_id=REQ-FIN-001 severity=CRITICAL -->
```

| Attribute | Required | Ví dụ | Mô tả |
|-----------|:--------:|-------|-------|
| `id` | ✅ | `R-FINANCE-001` | Rule identifier (duy nhất trong domain) |
| `entity` | ❌ | `Invoice` | Domain entity áp dụng rule |
| `action` | ❌ | `approve` | Operation: create/approve/validate/calculate |
| `field` | ❌ | `amount` | Specific field nếu có |
| `req_id` | ❌ | `REQ-FIN-001` | REQ-ID tương ứng trong req-registry.json |
| `severity` | ❌ | `CRITICAL` | Severity nếu vi phạm: CRITICAL/HIGH/MEDIUM |

## Procedure

### PRE-GATE

```bash
# Step 1: Profile gate — exhaustive only
if [ "$PROFILE" != "exhaustive" ]; then
  echo "P-QD2-business-rule-coverage: SKIP (profile=$PROFILE, requires exhaustive)" >&2
  exit 0
fi

# Step 2: Verify reference directory exists
REF_DIR=".claude/references/team-expert"
if [ ! -d "$REF_DIR" ]; then
  echo "P-QD2-business-rule-coverage: SKIP (no team-expert reference directory found)" >&2
  exit 0
fi

# Step 3: Verify source directory exists
if [ ! -d "src" ] && [ ! -d "apps" ]; then
  echo "P-QD2-business-rule-coverage: SKIP (no src/ or apps/ directory)" >&2
  exit 0
fi

# Step 4: Scan Cache check (static probe — cache allowed)
FP=$(python -m _shared.scan_cache.fingerprint --probe-id P-QD2-business-rule-coverage \
  --probe-version 1.0.0 --dir "$REF_DIR" 2>/dev/null || echo "no-cache")
CACHE_HIT=""
if [ "$FP" != "no-cache" ]; then
  CACHE_HIT=$(python -m _shared.scan_cache.cache_lookup \
    --cache-root .mc-data/cache/wf-fix-bugs/probes/ --fingerprint "$FP" 2>/dev/null || echo "")
fi

if [ -n "$CACHE_HIT" ]; then
  echo "P-QD2-business-rule-coverage: CACHE HIT — reuse cached signals" >&2
  # Merge cached signals into lane signals.json via _shared.md protocol §1
  exit 0
fi
```

### SENSE

**S1 — Parse BIZ-RULE annotations from reference files:**

```bash
# Glob all reference markdown files
REFERENCE_FILES=$(find .claude/references/team-expert -name "*.md" -type f | sort)

# Python3 inline: parse BIZ-RULE annotations
BIZ_RULES=$(python3 - <<'PYEOF'
import re, sys, os, json, glob

REF_DIR = ".claude/references/team-expert"
RULE_PATTERN = re.compile(
    r'<!--\s*BIZ-RULE:\s*(.*?)\s*-->',
    re.IGNORECASE | re.DOTALL
)
ATTR_PATTERN = re.compile(r'(\w+)=([^\s]+)')

rules = []
for md_file in sorted(glob.glob(f"{REF_DIR}/**/*.md", recursive=True)):
    with open(md_file, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()
    for match in RULE_PATTERN.finditer(content):
        attrs_str = match.group(1)
        attrs = dict(ATTR_PATTERN.findall(attrs_str))
        rule_id = attrs.get("id")
        if not rule_id:
            continue  # skip malformed (no id)
        rules.append({
            "rule_id": rule_id,
            "entity": attrs.get("entity", ""),
            "action": attrs.get("action", ""),
            "field": attrs.get("field", ""),
            "req_id": attrs.get("req_id", ""),
            "severity": attrs.get("severity", "MEDIUM"),
            "source_file": md_file,
        })

print(json.dumps(rules))
PYEOF
)

RULE_COUNT=$(echo "$BIZ_RULES" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
echo "P-QD2-business-rule-coverage: found $RULE_COUNT BIZ-RULE annotations" >&2

# Step S1.2: SKIP gracefully if no annotations found
if [ "$RULE_COUNT" = "0" ]; then
  echo "P-QD2-business-rule-coverage: SKIP — no BIZ-RULE annotations found in $REF_DIR" >&2
  echo "  Hint: Add annotations using format:" >&2
  echo "  <!-- BIZ-RULE: id=R-XXX entity=Entity action=action req_id=REQ-XXX severity=HIGH -->" >&2
  exit 0
fi
```

**S2 — Detect CI capabilities (REUSE SKILL.md §CI PRE-GATE):**

```bash
SERENA_AVAILABLE="${SERENA_AVAILABLE:-false}"
GITNEXUS_AVAILABLE="${GITNEXUS_AVAILABLE:-false}"
if [ -f ".mc-data/work/_meta/code-intelligence.json" ]; then
  SERENA_AVAILABLE=$(jq -r '.serena.available // "false"' .mc-data/work/_meta/code-intelligence.json 2>/dev/null || echo "false")
fi
```

### THINK

Cho mỗi rule trong BIZ_RULES, xác định search terms:

```python
# Search terms priority order:
# 1. rule_id (e.g., "R-FINANCE-001") — direct annotation
# 2. req_id if present (e.g., "REQ-FIN-001") — REQ-ID traceability
# 3. rule_id slug (e.g., "FINANCE_001", "finance-001") — naming variations

def build_search_terms(rule):
    terms = [rule["rule_id"]]
    if rule["req_id"]:
        terms.append(rule["req_id"])
    # Slug variants (underscore, dash, no-prefix)
    raw = rule["rule_id"].replace("R-", "").replace("-", "_")
    terms.append(raw)
    return list(dict.fromkeys(terms))  # deduplicate, preserve order
```

### ACT

**A1 — Check code coverage per rule (CI-ROUTE PRIMARY: Serena):**

```bash
# For each rule in BIZ_RULES:
UNCOVERED_RULES=()

echo "$BIZ_RULES" | python3 -c "
import json, sys, subprocess, os

rules = json.load(sys.stdin)
source_dirs = [d for d in ['src', 'apps'] if os.path.isdir(d)]
source_ext = '{ts,tsx,js,jsx,py,java,cs,go,rs}'

for rule in rules:
    rule_id = rule['rule_id']
    req_id = rule.get('req_id', '')
    found = False

    # CI-ROUTE PRIMARY: Serena find_referencing_symbols
    # (invoked by outer bash via mcp tool if SERENA_AVAILABLE=true)
    # --- CI tool result injected as SERENA_RESULT env var by outer harness ---
    serena_result = os.environ.get(f'SERENA_RESULT_{rule_id.replace(\"-\", \"_\")}', '')
    if serena_result and serena_result != 'NOT_FOUND':
        found = True

    if not found:
        # FALLBACK: grep code for rule_id and req_id
        for term in [rule_id, req_id] + [rule_id.replace('R-', '').replace('-', '_')]:
            if not term:
                continue
            for src_dir in source_dirs:
                result = subprocess.run(
                    ['grep', '-r', '--include=*.ts', '--include=*.tsx',
                     '--include=*.js', '--include=*.py', '--include=*.java',
                     '--include=*.cs', '--include=*.go',
                     '-l', term, src_dir],
                    capture_output=True, text=True, timeout=30
                )
                if result.returncode == 0 and result.stdout.strip():
                    found = True
                    break
            if found:
                break

    if not found:
        print(json.dumps({
            'rule_id': rule_id,
            'entity': rule.get('entity', ''),
            'action': rule.get('action', ''),
            'req_id': req_id,
            'source_file': rule.get('source_file', ''),
            'severity_annotation': rule.get('severity', 'MEDIUM'),
        }))
" | while IFS= read -r uncovered_json; do
  # A2 — Emit signal per uncovered rule (REUSE _shared.md §1 emission pattern)
  RULE_ID=$(echo "$uncovered_json" | jq -r '.rule_id')
  ENTITY=$(echo "$uncovered_json" | jq -r '.entity')
  ACTION=$(echo "$uncovered_json" | jq -r '.action')
  REQ_ID=$(echo "$uncovered_json" | jq -r '.req_id')
  SOURCE_FILE=$(echo "$uncovered_json" | jq -r '.source_file')
  SEVERITY_ANN=$(echo "$uncovered_json" | jq -r '.severity_annotation')

  # Normalize severity annotation → signal severity (cap at MEDIUM for missing coverage)
  case "$SEVERITY_ANN" in
    CRITICAL|HIGH) SIGNAL_SEVERITY="medium" ;;  # coverage gap ≠ active violation
    *) SIGNAL_SEVERITY="medium" ;;
  esac

  DESCRIPTION="BIZ-RULE $RULE_ID"
  [ -n "$ENTITY" ] && DESCRIPTION="$DESCRIPTION (entity: $ENTITY"
  [ -n "$ACTION" ] && DESCRIPTION="$DESCRIPTION, action: $ACTION"
  [ -n "$ENTITY" ] && DESCRIPTION="$DESCRIPTION)"
  DESCRIPTION="$DESCRIPTION has no code reference — rule may not be implemented"

  SIGNALS=$(cat "$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/signals.json")
  NEW_SIGNAL=$(jq -n \
    --arg pid "P-QD2-business-rule-coverage" \
    --arg st "business_rule_uncovered" \
    --arg sev "$SIGNAL_SEVERITY" \
    --arg title "Business rule $RULE_ID: no code reference found" \
    --arg desc "$DESCRIPTION" \
    --arg rule_id "$RULE_ID" \
    --arg req_id "$REQ_ID" \
    --arg src_file "$SOURCE_FILE" \
    '{
      "$schema": "signal-v2",
      probe_id: $pid,
      dimension_id: "QD2",
      signal_type: "business_rule_uncovered",
      severity: $sev,
      title: $title,
      description: $desc,
      target: {
        kind: "spec",
        file_path: $src_file,
        line_range: null
      },
      evidence: {
        rule_id: $rule_id,
        req_id: $req_id,
        code_snippet: null,
        spec_ref: $src_file
      },
      dedup_key: ("P-QD2-business-rule-coverage:business_rule_uncovered:" + $rule_id)
    }')

  # Atomic merge (REUSE _shared.md §1 F24 pattern)
  TMP=$(mktemp)
  SIG_TMP=$(mktemp)
  printf '%s' "[$NEW_SIGNAL]" > "$SIG_TMP"
  jq --slurpfile new "$SIG_TMP" '.signals += $new[0]' \
    "$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/signals.json" > "$TMP" \
    && mv "$TMP" "$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/signals.json"
  rm -f "$SIG_TMP"

  echo "  SIGNAL: business_rule_uncovered MEDIUM — $RULE_ID (no code ref)" >&2
done
```

**A3 — Per-probe summary JSON:**

```bash
COVERED=$(echo "$BIZ_RULES" | python3 -c "
import json, sys
rules = json.load(sys.stdin)
print(len(rules))
" 2>/dev/null || echo 0)

UNCOVERED=$(jq '.signals | map(select(.probe_id == "P-QD2-business-rule-coverage")) | length' \
  "$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/signals.json" 2>/dev/null || echo 0)

COVERED_COUNT=$((COVERED - UNCOVERED))

mkdir -p "$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/raw"
cat > "$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/raw/business-rule-coverage.json" <<JSON
{
  "probe_id": "P-QD2-business-rule-coverage",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "rules_found": $COVERED,
  "rules_covered": $COVERED_COUNT,
  "rules_uncovered": $UNCOVERED,
  "coverage_pct": $(echo "scale=1; $COVERED_COUNT * 100 / ($COVERED + 0.001)" | bc)
}
JSON
echo "P-QD2-business-rule-coverage: $COVERED_COUNT/$COVERED rules covered ($UNCOVERED uncovered)" >&2
```

**A4 — Scan Cache store (static probe — cache MISS path):**

```bash
if [ -n "$FP" ] && [ "$FP" != "no-cache" ]; then
  python -m _shared.scan_cache.cache_store store \
    --probe-id P-QD2-business-rule-coverage \
    --file "$REF_DIR" \
    --signals-file "$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/raw/business-rule-coverage.json" \
    --cache-root .mc-data/cache/wf-fix-bugs/probes/ 2>/dev/null || true
fi
```

### CI-ROUTE Primary: Serena `find_referencing_symbols`

Per SKILL.md §CI-ROUTE + 03-reuse-ci-parallelism.md §3.3:

Khi `$SERENA_AVAILABLE == "true"`, cho mỗi rule_id:

```
# CI-ROUTE PRIMARY (per probe):
mcp__serena__find_referencing_symbols({
  name_path: "{rule_id}",     # e.g., "R-FINANCE-001"
  relative_path: null          # search entire codebase
})
→ IF symbols_found → rule IS covered (code references rule ID)
→ IF empty → proceed to Grep FALLBACK
```

Nếu Serena trả về symbols → rule covered → KHÔNG emit signal.
Nếu Serena rỗng → Grep FALLBACK → nếu Grep không thấy → emit signal.

**Fallback table:**

| Tình huống | Hành vi |
|------------|---------|
| Serena unavailable | Grep FALLBACK cho tất cả rules |
| Rule ID không match naming convention | Try slug variants (underscores, no prefix) |
| req_id có → rule_id không có code ref | Check req_id trong code trước khi emit |
| No source dirs (src/ apps/) | SKIP probe, note in summary |
| Reference dir không tồn tại | SKIP gracefully |
| Annotation malformed (no `id=`) | Skip annotation với warning |
| Scan Cache HIT | Reuse signals, không re-scan |
| 0 BIZ-RULE annotations found | SKIP — không emit error (valid if no annotations yet) |

### VERIFY

```bash
# V1: signals.json valid JSON
jq '.' "$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/signals.json" > /dev/null 2>&1 || {
  echo "ERROR: signals.json invalid JSON after P-QD2-business-rule-coverage" >&2
  exit 1
}

# V2: All signals have required fields
jq -e '[.signals[] | select(.probe_id == "P-QD2-business-rule-coverage") |
  select(.signal_type != "business_rule_uncovered" or .dedup_key == null)] | length == 0' \
  "$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/signals.json" > /dev/null 2>&1 || {
  echo "WARNING: Some signals missing required fields" >&2
}

# V3: Each signal has spec_ref (evidence.spec_ref) pointing to reference file
jq -e '[.signals[] |
  select(.probe_id == "P-QD2-business-rule-coverage") |
  select(.evidence.spec_ref == null or .evidence.spec_ref == "")] | length == 0' \
  "$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/signals.json" > /dev/null 2>&1 || {
  echo "WARNING: Some signals missing spec_ref evidence" >&2
}

# V4: rule_id dedup — same rule should not appear twice
jq -e '([.signals[] | select(.probe_id == "P-QD2-business-rule-coverage") |
  .dedup_key] | length) ==
  ([.signals[] | select(.probe_id == "P-QD2-business-rule-coverage") |
  .dedup_key] | unique | length)' \
  "$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/signals.json" > /dev/null 2>&1 || {
  echo "WARNING: Duplicate dedup_keys detected — check dedup logic" >&2
}

# V5: Update lane-status.json (REUSE _shared.md §6 checkpoint)
jq --arg probe "P-QD2-business-rule-coverage" \
   '.probes_completed += [$probe] |
    .probes_remaining -= [$probe] |
    .last_updated = (now | todate)' \
  "$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/lane-status.json" > /tmp/ls_tmp.json \
  && mv /tmp/ls_tmp.json "$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/lane-status.json"
```

## Output

- Signals emitted to `$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/signals.json` (signal_type: `business_rule_uncovered` MEDIUM)
- Raw summary: `$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/raw/business-rule-coverage.json` (rules_found, rules_covered, coverage_pct)
- Cache store: `.mc-data/cache/wf-fix-bugs/probes/` (TTL per scan-cache policy)

## Signal Schema Example

```json
{
  "$schema": "signal-v2",
  "probe_id": "P-QD2-business-rule-coverage",
  "dimension_id": "QD2",
  "signal_type": "business_rule_uncovered",
  "severity": "medium",
  "title": "Business rule R-FINANCE-001: no code reference found",
  "description": "BIZ-RULE R-FINANCE-001 (entity: Invoice, action: approve) has no code reference — rule may not be implemented",
  "target": {
    "kind": "spec",
    "file_path": ".claude/references/team-expert/finance/controls.md",
    "line_range": null
  },
  "evidence": {
    "rule_id": "R-FINANCE-001",
    "req_id": "REQ-FIN-001",
    "code_snippet": null,
    "spec_ref": ".claude/references/team-expert/finance/controls.md"
  },
  "dedup_key": "P-QD2-business-rule-coverage:business_rule_uncovered:R-FINANCE-001"
}
```

## Dedup Hints

- Key: `P-QD2-business-rule-coverage:business_rule_uncovered:{rule_id}` (1 signal per rule ID — không dedup-merge nếu same rule uncovered after code change)
- Nếu rule covered sau fix → signal sẽ không xuất hiện trong run tiếp theo (static probe, cache invalidate khi code thay đổi)

## Profile-Resolver Entry

```yaml
probe: P-QD2-business-rule-coverage
class: static
profiles:
  quick: SKIP
  standard: SKIP
  deep: SKIP
  exhaustive:
    run: true
    max_rules: unlimited  # BIZ-RULE annotations thường ít (< 100)
cache_policy: allowed     # stable khi references + code không thay đổi
parallel_safe: true       # read-only, independent của other QD2 probes
requires_api: false
mutation: false
```

## Acceptance Tests

```bash
# AT1: 0 BIZ-RULE annotations → SKIP (no signal, no error)
# AT2: 1 annotation + code ref exists → 0 signals emitted
# AT3: 1 annotation + NO code ref → 1 signal emitted (business_rule_uncovered MEDIUM)
# AT4: req_id present → check req_id in code (alternative to rule_id)
# AT5: Malformed annotation (no id=) → skip annotation, no crash
# AT6: Scan Cache HIT → reuse signals, no re-scan (cache MISS path runs first)

# Minimal acceptance test (inject 1 uncovered rule):
# 1. Add to any reference .md:
#    <!-- BIZ-RULE: id=R-TEST-999 entity=TestEntity action=test severity=MEDIUM -->
# 2. Run probe → expect signal: business_rule_uncovered MEDIUM for R-TEST-999
# 3. Add comment "// R-TEST-999" to any .ts file in src/
# 4. Run probe again → expect 0 signals for R-TEST-999 (covered)
```

## Annotation Convention Guide

> **Đặt ở đầu mục (section) trong reference file, TRƯỚC đoạn mô tả rule.**

```markdown
## Payment Authorization Limits

<!-- BIZ-RULE: id=R-FINANCE-002 entity=Payment action=approve
     req_id=REQ-FIN-002 severity=CRITICAL -->
Payment > 50M VND requires CFO approval. Payment > 200M VND requires CFO + CEO.
```

**Quy ước đặt tên rule ID:**

| Domain | Prefix | Ví dụ |
|--------|--------|-------|
| Finance | R-FINANCE-NNN | R-FINANCE-001 |
| HR | R-HR-NNN | R-HR-001 |
| Logistics | R-LOG-NNN | R-LOG-001 |
| Compliance | R-COMP-NNN | R-COMP-001 |
| Sales | R-SALES-NNN | R-SALES-001 |
| Inventory | R-INV-NNN | R-INV-001 |

**Code reference pattern** (cách implement để probe nhận ra):

```typescript
// BIZ-RULE: R-FINANCE-002
// REQ-ID: REQ-FIN-002
if (payment.amount > 50_000_000 && !approvals.cfo) {
  throw new BusinessRuleViolation('R-FINANCE-002: CFO approval required');
}
```
