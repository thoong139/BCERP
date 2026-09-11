# P-QD1-req-registry-xref — REQ-ID Registry Cross-Reference

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD1-req-registry-xref |
| **Loai** | static |
| **Profile** | quick, standard, deep, exhaustive |
| **Muc dich** | Cross-ref REQ-ID annotations trong code voi req-registry.json. Phat hien coverage gaps. |
| **Cache** | allowed (--use-cache) |
| **Migrates from** | (v5 legacy — removed in v6) phase5-feature-coverage.md (L1.2) |

## SENSE

### B1: Delegate to bash script (S5 v7.0)

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD1-functional/raw/P-QD1-req-registry-xref.json"
mkdir -p "$(dirname "$RAW_OUT")"

if ! bash .claude/scripts/wf-fix-probe-static-xref.sh \
      --session-dir "$SESSION_DIR" \
      --lane wf-fix-functional \
      --probe P-QD1-req-registry-xref \
      --profile "$PROFILE" \
      --source-dir "${SOURCE_DIR:-src/}" \
      > "$RAW_OUT" 2>"$RAW_OUT.err"; then
  # Inline fallback — emit empty signals voi skip_reason
  echo "WARNING: bash script failed, see $RAW_OUT.err" >&2
  cat > "$RAW_OUT" <<EOF
{"\$schema":"lane-signals-v1","lane":"wf-fix-functional","dimension":"QD1",
 "probe_id":"P-QD1-req-registry-xref","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"bash_script_failed"}
EOF
fi
```

**Bash script handles:**
- Doc registry (impl_status=done OR in_progress, exclude DEPRECATED systems)
- Grep REQ-ID + FEAT-ID annotations (TS/JS/Python/Java/C#/Go/Rust)
- Build coverage gaps + orphan annotations signals theo schema signal-v2

### B2: Scan Cache check (khi --use-cache, optional ngoai bash script)

```bash
# Cache delegated rieng — KHONG inline trong bash script (D3 — Python _shared/ giu)
if [ "${USE_CACHE:-0}" -eq 1 ]; then
  python -m _shared.scan_cache.cache_lookup \
    --cache-root .mc-data/cache/wf-fix-bugs/probes/ \
    --probe-id P-QD1-req-registry-xref --probe-version 1.0.0 \
    >> "$RAW_OUT.cache" 2>/dev/null || true
fi
```

### B3: CI Enrichment (BAT BUOC khi SERENA available — canonical use case cho QD1 REQ-ID xref)

> **Muc dich:** Voi orphan annotations (REQ-ID trong code khong co trong registry), tang accuracy bang cach dung Serena de truy ve symbol thuc te. Voi coverage gaps, xac dinh code paths can them annotation.

```bash
if [[ "$SERENA_AVAILABLE" == "true" ]]; then
  # Pseudocode (orchestrator agent thuc hien):
  # FOR each signal trong $RAW_OUT.signals[]:
  #   IF signal.signal_type == "orphan_annotation":
  #     # signal.evidence chua REQ-ID lac, signal.target.file_path
  #     # Verify symbol nao chua REQ-ID nay
  #     symbols = mcp__serena__get_symbols_overview(signal.target.file_path)
  #     orphan_symbols = [s for s in symbols if has_req_id_in_body(s, signal.req_id)]
  #     signal.evidence.serena_owning_symbols = [{name: s.name, kind: s.kind, line: s.line} for s in orphan_symbols]
  #   
  #   ELIF signal.signal_type == "coverage_gap":
  #     # signal.feat_id la FEAT-ID khong tim thay trong code
  #     # Try tim symbol co ten gan voi FEAT-ID (heuristic)
  #     candidates = infer_candidate_symbols(signal.feat_id)  # vd: "FEAT-CRM-LEAD" → "Lead*"
  #     for cand in candidates:
  #       refs = mcp__serena__find_referencing_symbols(name_path=cand, relative_path=...)
  #       IF refs.length > 0:
  #         signal.evidence.suggested_annotation_targets = refs[0:5]
  #   
  #   signal.evidence.ci_meta = {gitnexus_used: false, serena_used: true, freshness_level: $FRESHNESS_LEVEL}
fi
```

**Graceful:** Serena absent → skip B3, signals giu nguyen tu B1.

## THINK

Bash script da implement logic:
1. **Coverage gaps:** feature `impl_status == "done"` HOAC `"in_progress"` ma KHONG co FEAT-ID trong code → emit signal (severity=high cho done, medium cho in_progress)
2. **Orphan annotations:** code REQ-ID KHONG ton tai trong registry → emit signal (severity=medium)
3. **Exclusion:** systems `action="DEPRECATE"` skip
4. **Dedup:** fingerprint = sha256(QD1|file|line|probe_id|signal_type|id)

## ACT

Bash script (`wf-fix-probe-static-xref.sh`) da output signals theo schema `signal-v2` voi:
- `dimension_id: "QD1"`, `probe_id`, `severity`, `fixability: "agent_fix"`, `domain: "general"`
- `evidence[]` voi description tham chieu registry/code
- `registry_refs.feat_ids[]` hoac `req_ids[]` cho cross-link

Sau khi bash script chay, **SKILL.md tu append signals vao `signals.json`** qua signal-emit.md helper:

```bash
# Trong SKILL.md / signal-emit.md helper
jq -c '.signals[]' "$RAW_OUT" | while read -r sig; do
  emit_signal_from_json "$LANE_DIR" "$sig"  # emit voi lock + dedup
done
```

## VERIFY

1. Kiem tra moi Signal co `evidence` voi it nhat 1 field non-empty
2. Kiem tra moi Signal co `target.file_path` (co the "N/A" cho registry gaps)
3. Kiem tra moi Signal co `suggested_severity` trong ["critical","high","medium","low"]
4. Kiem tra moi Signal co `signal_type` trong ["coverage_gap","orphan_annotation"]
5. Loai bo duplicates (cung REQ-ID) → giu version moi nhat

## Severity Rules

| Dieu kien | Severity |
|-----------|----------|
| impl_status=done + khong co REQ-ID trong code | HIGH |
| impl_status=in_progress + khong co REQ-ID trong code | MEDIUM |
| Code co REQ-ID khong co trong registry | MEDIUM |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Registry khong co features[] | Skip probe, note "no_features_in_registry" |
| Khong tim thay source code files | Emit signals cho tat ca features=done, note "no_source_files" |
| Scan Cache corrupt | Fallback: scan thuong, log WARNING |
| Grep khong tim thay REQ-ID annotations | Emit signals cho tat ca features=done, note "no_req_annotations_found" |
