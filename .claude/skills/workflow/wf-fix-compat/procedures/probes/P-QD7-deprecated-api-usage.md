# P-QD7-deprecated-api-usage — Deprecated API Usage Detection

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD7-deprecated-api-usage |
| **Loai** | static |
| **Profile** | quick, standard, deep, exhaustive |
| **Muc dich** | Phat hien su dung deprecated browser APIs, deprecated library methods, va deprecated Node.js APIs trong source code. |
| **Cache** | **allowed** |
| **Migrates from** | Stage D (new) |

## PRE-GATE

```
IF khong co source code (Glob src/**/*.{ts,tsx,js,jsx} tra 0 results):
  SKIP probe, note "skipped_no_source_code"
```

## SENSE

### B1: Delegate to bash script (S5 v7.0)

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD7-compat/raw/P-QD7-deprecated-api-usage.json"
mkdir -p "$(dirname "$RAW_OUT")"

if ! bash .claude/scripts/wf-fix-probe-static-deprecated.sh \
      --session-dir "$SESSION_DIR" \
      --lane wf-fix-compat \
      --probe P-QD7-deprecated-api-usage \
      --profile "$PROFILE" \
      --source-dir "${SOURCE_DIR:-src/}" \
      --package-json "${PACKAGE_JSON:-package.json}" \
      > "$RAW_OUT" 2>"$RAW_OUT.err"; then
  # Inline fallback — emit empty signals
  echo "WARNING: bash deprecated probe failed, see $RAW_OUT.err" >&2
  cat > "$RAW_OUT" <<EOF
{"\$schema":"lane-signals-v1","lane":"wf-fix-compat","dimension":"QD7",
 "probe_id":"P-QD7-deprecated-api-usage","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"bash_script_failed"}
EOF
fi
```

**Bash script handles:**
- 17 browser/React/Node deprecated API patterns (document.execCommand, componentWillMount, new Buffer, ...)
- 3 deprecated CSS patterns (zoom, -webkit-box-flex, word-break)
- 7 deprecated package patterns (moment, request, node-uuid, jade, ...)
- Replacement mapping → `remediation.suggested_action`

### B2: CI Enrichment (BAT BUOC khi SERENA available — canonical use case cho deprecated API discovery)

> **Muc dich:** `find_referencing_symbols` cho deprecated function la canonical use case. Severity bug deprecated phu thuoc vao bao nhieu noi goi: 1 noi → low, 5 noi → medium, 20+ noi → high (migration cost lon).

```bash
if [[ "$SERENA_AVAILABLE" == "true" ]]; then
  # Pseudocode (orchestrator agent thuc hien):
  # FOR each signal trong $RAW_OUT.signals[] (top 50 theo severity):
  #   IF signal.signal_type IN ("deprecated_api_usage", "deprecated_lifecycle", "deprecated_package_import"):
  #     deprecated_name = signal.evidence.api_name  # vd: "componentWillMount"
  #     
  #     # Find ALL call sites cross-file
  #     refs = mcp__serena__find_referencing_symbols(name_path=deprecated_name, relative_path=signal.target.file_path)
  #     signal.evidence.serena_refs_count = refs.length
  #     signal.evidence.serena_refs_top = refs[0:10]
  #     
  #     # Severity dua tren so call sites
  #     IF refs.length == 1:
  #       signal.suggested_severity = "low"  # 1 noi — easy migrate
  #     ELIF refs.length <= 5:
  #       signal.suggested_severity = "medium"
  #     ELIF refs.length <= 20:
  #       signal.suggested_severity = "high"
  #     ELSE:
  #       signal.suggested_severity = "critical"  # 20+ call sites → migration project lon
  #     signal.evidence.severity_bump_reason = f"deprecated API used in {refs.length} call sites"
  #   
  #   ELIF signal.signal_type == "deprecated_lib_import":
  #     # GitNexus impact for lib bump
  #     IF GITNEXUS_AVAILABLE:
  #       impact = mcp__plugin_gitnexus_gitnexus__impact(target=signal.evidence.lib_name, direction="upstream")
  #       signal.evidence.gitnexus_callers = impact.direct_callers_count
  #       signal.evidence.gitnexus_processes = impact.affected_processes
  #   
  #   signal.evidence.ci_meta = {gitnexus_used: $GITNEXUS_AVAILABLE, serena_used: true, freshness_level: $FRESHNESS_LEVEL}
fi
```

**Graceful:** Serena absent → skip B2, signals giu severity tu B1 (default rules).

## THINK

1. **Severity assessment**:
   - API da bi REMOVE khoi browsers → CRITICAL (code se fail)
   - API da bi DEPRECATED nhung van hoat dong → HIGH (can migration plan)
   - API deprecated trong library nhung van hoat dong → MEDIUM
   - Deprecated CSS can vendor prefix replacement → LOW
2. **Replacement mapping**:
   - `document.execCommand('copy')` → `navigator.clipboard.writeText()`
   - `componentWillMount` → `useEffect` hoac `componentDidMount`
   - `new Buffer()` → `Buffer.alloc()` hoac `Buffer.from()`
   - `moment` → `date-fns` hoac `dayjs`
   - `request` → `node-fetch` hoac `axios`
3. **Impact scoring**: Dem so lan xuat hien cua moi deprecated API → frequent usage = higher priority

## ACT

### Emit signals cho tung deprecated usage

```json
{
  "probe_id": "P-QD7-deprecated-api-usage",
  "probe_version": "1.0.0",
  "emitted_at": "<ISO>",
  "lane": "wf-fix-compat",
  "dimension_id": "QD7",
  "signal_type": "deprecated_api",
  "target": {
    "kind": "code",
    "file_path": "src/components/CopyButton.tsx",
    "line_range": [24, 26]
  },
  "description": "Su dung document.execCommand('copy') — deprecated API, khong ho tro tren HTTPS cross-origin. Thay bang navigator.clipboard.writeText()",
  "evidence": {
    "code_snippet": "document.execCommand('copy');",
    "replacement": "navigator.clipboard.writeText(text)",
    "mdn_status": "deprecated"
  },
  "suggested_severity": "high",
  "dedup_hints": ["deprecated:document.execCommand:src/components/CopyButton.tsx"]
}
```

### Write raw signals

```bash
cat > "$SESSION_DIR/phase4-find-bugs/lanes/QD7-compat/raw/P-QD7-deprecated-api-usage.json" << 'EOF'
{
  "$schema": "lane-signals-v1",
  "lane": "wf-fix-compat",
  "dimension": "QD7",
  "generated_at": "<ISO>",
  "signals": []
}
EOF
```

## VERIFY

- [ ] Moi Signal co `dimension_id = "QD7"`
- [ ] Moi Signal co `evidence.code_snippet` non-empty
- [ ] Moi Signal co `evidence.replacement` (replacement API)
- [ ] `suggested_severity` trong [CRITICAL, HIGH, MEDIUM, LOW]
- [ ] `probe_id` match `^P-QD7-[a-z0-9-]+$`
- [ ] `dedup_hints` chua file-specific key de tranh duplicate

## Severity Rules

| Pattern | Severity |
|---------|----------|
| API da bi REMOVE khoi modern browsers | CRITICAL |
| API deprecated, van hoat dong, khong co replacement plan | HIGH |
| Deprecated library method voi replacement available | MEDIUM |
| Deprecated CSS property co vendor prefix fallback | LOW |
| Deprecated package dependency (moment, request) | MEDIUM |

## Fallback

| Tinh huong | Xu ly |
|-----------|-------|
| Khong co source code | Skip probe, emit 0 signals |
| Parse error tren files | Log warning per file, continue |
| False positive tren comment strings | THINK step filter: chi emit neu trong executable code context |
