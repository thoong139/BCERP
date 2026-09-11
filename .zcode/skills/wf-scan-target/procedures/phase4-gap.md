# Phase 4 — Gap Analysis (Conditional)

> **Sprint 3 lazy-load refactor.** So sánh features found trong scan vs features trong spec file.
> Đánh dấu từng feature: FOUND | PARTIAL | MISSING.
> CHỈ chạy khi `$compare_path` được cung cấp.

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §Helper Functions (`save_checkpoint`)

## Load Condition

Chạy sau `phase3-synthesis.md` POST-GATE PASS, CHỈ khi `$compare_path` không null.
Nếu không có `--compare` → SKIP file này, vào thẳng `phase5-output.md`.

---

## PRE-GATE

```
- Phase 3 POST-GATE PASS
- $compare_path không null
- $key_features[] populated
- $crud_matrix populated
- $L1_RESULT, $L2_RESULT set
```

## INPUT

| Variable | From | Description |
|----------|------|-------------|
| `$compare_path` | Phase 0 | Spec/feature file path |
| `$key_features` | Phase 3 | List features từ BA |
| `$crud_matrix` | Phase 3 | Per-entity CRUD ops |
| `$L1_RESULT.key_files["commands"]` | Phase 2 L1 | Cross-check signals |
| `$L2_RESULT.endpoints` | Phase 2 L2 | Cross-check signals |

## Steps

### 4.1 — Read Spec File

```
IF compare_path ends with ".json":
  spec_data = Read + JSON.parse(compare_path)
  # Try to extract features từ different formats:
  IF spec_data has "features": spec_features = spec_data.features
  ELSE IF spec_data has "requirements": spec_features = spec_data.requirements
  ELSE: spec_features = spec_data (treat as list)

ELSE IF compare_path ends with ".md":
  Read compare_path → spec_markdown
  # Extract bullet points and headings as features
  Grep "^- |^## |^### " → spec_lines[]
  spec_features = [clean(line) for line in spec_lines]

ELSE:
  Read compare_path → raw_text
  spec_features = split_by_lines(raw_text)

Log: "Spec loaded: {len(spec_features)} features/requirements"
```

### 4.2 — Match & Classify

> **Sprint 7 PHẦN C — LPM exhaustive:** Khi `$SCAN_PROFILE == "exhaustive"` →
> similarity threshold relaxed từ 0.6 → 0.5 + thêm "fuzzy match" notes cho near-misses
> (similarity 0.5-0.6 được mark là PARTIAL với note "fuzzy match").

```bash
# Sprint 7 PHẦN C — Determine similarity threshold theo profile
if [[ "${SCAN_PROFILE:-standard}" == "exhaustive" ]]; then
  SIM_THRESHOLD=0.5
  Log: "Phase 4.2: profile=exhaustive → similarity threshold 0.5 (relaxed match) + fuzzy notes"
else
  SIM_THRESHOLD=0.6
fi
```

```
gap_matrix = []

FOR each spec_feat in spec_features:
  feat_normalized = normalize(spec_feat)  # lowercase, remove punctuation

  # Search in our findings
  found_in = []

  # Check key_features (Sprint 7: threshold = $SIM_THRESHOLD — 0.6 default | 0.5 exhaustive)
  FOR each found_feat in key_features:
    sim = similarity(feat_normalized, normalize(found_feat))
    IF sim > $SIM_THRESHOLD:
      match_type = "key_feature"
      # Sprint 7 fuzzy note: nếu exhaustive + similarity 0.5-0.6 → mark fuzzy
      IF $SCAN_PROFILE == "exhaustive" AND sim < 0.6:
        match_type = "key_feature_fuzzy"
      found_in.append({type: match_type, item: found_feat, similarity: sim})

  # Check commands/queries
  FOR each cmd in L1_RESULT.key_files["commands"]:
    cmd_normalized = humanize_normalize(basename(cmd))
    sim = similarity(feat_normalized, cmd_normalized)
    IF sim > $SIM_THRESHOLD:
      match_type = "command"
      IF $SCAN_PROFILE == "exhaustive" AND sim < 0.6:
        match_type = "command_fuzzy"
      found_in.append({type: match_type, item: basename(cmd), similarity: sim})

  # Check endpoints
  FOR each endpoint in L2_RESULT.endpoints:
    IF feat_normalized in normalize(endpoint.path + " " + endpoint.summary):
      found_in.append({type: "endpoint", item: endpoint.method + " " + endpoint.path})

  # Classify
  IF len(found_in) == 0:
    status = "MISSING"
  ELSE IF len(found_in) >= 2:
    status = "FOUND"
  ELSE:
    status = "PARTIAL"

  gap_matrix.append({
    spec_feature: spec_feat,
    status: status,
    found_in: found_in
  })

# Calculate metrics
gap_metrics = {
  total: len(gap_matrix),
  found: count(status == "FOUND"),
  partial: count(status == "PARTIAL"),
  missing: count(status == "MISSING"),
  coverage_pct: round((found + partial * 0.5) / total * 100)
}
```

### 4.3 — Save Checkpoint sau Phase 4 (GAP-05 — Sprint 2)

```bash
# Persist gap data cho resume
jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --argjson matrix "$gap_matrix_json" \
      --argjson metrics "$gap_metrics_json" \
      '{ generated_at: $ts, gap_matrix: $matrix, gap_metrics: $metrics }' \
   > "$SESSION_DIR/intermediate/gap.json"

save_checkpoint --phase phase_4 --status completed \
                --next-phase phase_5 --next-step output_generation \
                --intermediate-key gap_data \
                --intermediate-path "intermediate/gap.json"
```

## POST-GATE

```
- $gap_matrix populated
- $gap_metrics có total/found/partial/missing/coverage_pct
- test -s $SESSION_DIR/intermediate/gap.json
- jq empty $SESSION_DIR/intermediate/gap.json
- checkpoint.json: phase_states.phase_4 == "completed"
```

## OUTPUT (set for next phase)

| Variable | Type | Description |
|----------|------|-------------|
| `$gap_matrix` | array | [{spec_feature, status, found_in[]}] |
| `$gap_metrics` | JSON | total/found/partial/missing/coverage_pct |

## Next Phase

→ Read `procedures/phase5-output.md`
