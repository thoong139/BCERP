# QD2 Cross-Probe Protocols

> Shared protocols cho tat ca probes trong QD2 Business Correctness Lane.

## 1. Signal Emission

Moi probe emit signals bang cach append vao `$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/signals.json`.

**Signal structure (signal-v2):**
```json
{
  "probe_id": "P-QD2-{slug}",
  "dimension_id": "QD2",
  "signal_type": "calculation_error|flow_missing_step|compliance_violation|hardcoded_value|ambiguous_logic|business_rule_uncovered",
  "description": "Mo ta >= 20 ky tu",
  "target": {
    "kind": "code|config|spec",
    "file_path": "src/...",
    "line_range": [42, 58]
  },
  "suggested_severity": "critical|high|medium|low",
  "evidence": {
    "code_snippet": "...",
    "spec_ref": "...",
    "log_excerpt": "..."
  }
}
```

**Emission pattern:**
```bash
# Read existing signals, append new, write back
# F24 fix: dung temp file + --slurpfile thay vi --argjson de tranh ARG_MAX
# khi SIGNALS lon (>128KB tren Linux). Pattern nay khop voi wf-fix-probe-static-xref.sh:211-221.
TMP=$(mktemp)
SIGNALS_TMP=$(mktemp)
printf '%s' "$SIGNALS" > "$SIGNALS_TMP"
jq --slurpfile new "$SIGNALS_TMP" '.signals += $new[0]' "$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/signals.json" > "$TMP" && mv "$TMP" "$SESSION_DIR/phase4-find-bugs/lanes/QD2-business/signals.json"
rm -f "$SIGNALS_TMP"
```

## 2. Scan Cache Integration

Static probes (P-QD2-calculation-check, P-QD2-hardcoded-value-detect) wire Scan Cache:

```bash
FP=$(python -m _shared.scan_cache.fingerprint --probe-id P-QD2-{slug} --probe-version 1.0.0 --file "$FILE")
HIT=$(python -m _shared.scan_cache.cache_lookup --cache-root .mc-data/cache/wf-fix-bugs/probes/ --fingerprint "$FP")
if [ -z "$HIT" ]; then
  # Run scan, emit signals
  python -m _shared.scan_cache.cache_store store --probe-id P-QD2-{slug} --file "$FILE" --signals-file "$TMP" --cache-root .mc-data/cache/wf-fix-bugs/probes/
fi
```

**Cache policy per probe:**
| Probe | Cache | Reason |
|-------|-------|--------|
| P-QD2-domain-expert-review | skip | Agent output thay doi theo code |
| P-QD2-calculation-check | allowed | Static scan, stable |
| P-QD2-domain-fixture | skip | Runtime results thay doi |
| P-QD2-business-analyst-review | skip | Agent output thay doi |
| P-QD2-hardcoded-value-detect | allowed | Static scan, stable |

## 3. Severity Mapping

| Dieu kien | Severity | Source |
|-----------|----------|--------|
| Tinh toan sai dan den sai so tien hoac quyet dinh | CRITICAL | severity_rules.critical_triggers |
| Quy trinh skip buoc compliance (audit trail) | CRITICAL | severity_rules.critical_triggers |
| Business logic khong dung domain rules | HIGH | severity_rules.high_triggers |
| Flow buoc bi bo qua | HIGH | severity_rules.high_triggers |
| Hard-coded value nen la config | MEDIUM | severity_rules.medium_triggers |
| Ambiguous logic (agent low confidence) | LOW | default |

**Max aggregation:** Khi 1 issue bi flag boi nhieu probes → lay severity cao nhat.

## 4. Profile Selection

```
PROFILE=$2  # quick|standard|deep|exhaustive

# QD2 profile → probes mapping (tu dimension.json exit_criteria)
case "$PROFILE" in
  quick)    PROBES=() ;;  # SKIP
  standard) PROBES=("P-QD2-domain-expert-review" "P-QD2-calculation-check" "P-QD2-hardcoded-value-detect") ;;
  deep)     PROBES=("P-QD2-domain-expert-review" "P-QD2-calculation-check" "P-QD2-hardcoded-value-detect" "P-QD2-domain-fixture" "P-QD2-business-analyst-review") ;;
  exhaustive) PROBES=ALL ;;
esac
```

## 5. Agent Invocation Protocol

Domain expert agents duoc spawn qua Agent tool:

```
Agent(
  name="domain-review-{dept}",
  subagent_type="{domain}-expert",
  prompt="Review business correctness..."
)
```

**Output format bat buoc:**
```json
[{
  "type": "calculation_error|flow_missing_step|compliance_violation|hardcoded_value|ambiguous_logic",
  "description": "Mo ta >= 20 ky tu",
  "file_path": "src/...",
  "line_range": [42, 58],
  "severity": "critical|high|medium|low",
  "evidence": "Doan code hoac spec reference"
}]
```

**CORE-029 validation:**
1. Parse JSON → array
2. Moi entry: `type` non-empty, `description` >= 20 chars, `severity` in allowed values
3. Invalid entries → log WARNING, skip, note trong lane-report

## 6. Checkpoint

Sau moi probe, cap nhat lane-status.json:
```json
{
  "lane": "QD2",
  "profile": "standard",
  "status": "in_progress",
  "probes_completed": ["P-QD2-hardcoded-value-detect"],
  "probes_remaining": ["P-QD2-domain-expert-review", "P-QD2-calculation-check"],
  "signals_count": 3,
  "started_at": "...",
  "last_updated": "..."
}
```
