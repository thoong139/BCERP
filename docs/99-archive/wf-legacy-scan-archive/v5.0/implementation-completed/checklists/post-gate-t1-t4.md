# Checklist: POST-GATE T1-T4 Verification Per Layer

> **Purpose:** Verify POST-GATE compliance theo CORE-012 cho mọi layer (L1-L6).
> **Apply to:** Mọi implementation task write output files.
> **Reference:** [02-scan-layers.md §4](../../02-scan-layers.md), `.claude/skills/protocols/10-post-gate-schema.md`.

---

## T1 Existence (File Presence)

Check file tồn tại + non-empty:

```bash
# Generic
test -s <output_file>
```

### Per Layer

#### L1 Discovery
- [ ] `project-profile.json` (T1)
- [ ] `domain-hints.json` preliminary (T1)

#### L2 Assessment + IPS-A
- [ ] `assessment-report.json` (T1)
- [ ] `domain-hints.json` enriched (T1)
- [ ] `sessions/{id}/scan-state.json` → `ips.phase_a` populated (T1)

#### L3 Inventory + IPS-B
- [ ] `inventory/screens.json` (T1)
- [ ] `inventory/api-endpoints.json` (T1)
- [ ] `inventory/source-files.json` (T1)
- [ ] `inventory/dependency-graph.json` (T1)
- [ ] `inventory/doc-files.json` (T1)
- [ ] `inventory/external-docs.json` (T1)
- [ ] `inventory/ui-manifest.json` — CONDITIONAL (if screens.count > 0)
- [ ] `sessions/{id}/scan-state.json` → `ips.phase_b` populated (T1)

#### L4 Classification
- [ ] `classified/batch-*.json` ≥ 1 file (T1)
- [ ] `classified/glossary.json` (T1) — SKIP if surface
- [ ] `classified/classify-naming-fixes.json` (T1)
- [ ] `classified/auto-grouped.json` (T1) — ONLY if surface

#### L5 Extraction
- [ ] `extracted/{module}.json` ≥ 1 module (T1)
- [ ] `module-code-mapping.json` (T1)
- [ ] `dedup-report.json` (T1)
- [ ] SKIP if surface profile

#### L6 Synthesis
- [ ] `project-context.md` > 500 bytes (T1 — CORE-021 anchor)
- [ ] `doc-quality-map.json` (T1)
- [ ] `impl-status-snapshot.json` (T1) — SKIP if condensed
- [ ] `impact-graph.json` (T1) — SKIP if condensed
- [ ] `ledger.json` (T1 — generated 1x POST-P4)
- [ ] `sessions/{id}/phase-summary.md` (T1 — CORE-028)
- [ ] `sessions/{id}/session-log.json` (T1 — CORE-026)

---

## T2 Structure (JSON Validity + Required Fields)

Check JSON parsable + schema compliance:

```bash
jq empty <file>
jq -e '.required_field_1' <file>
jq -e '.required_field_2' <file>
```

### Per Layer

#### L1
- [ ] `project-profile.json`: `.file_counts.total`, `.tech_stack_verified`, `.doc_maturity.level`
- [ ] Valid `$schema: scan-state-v1` reference (nếu applicable)

#### L2
- [ ] `assessment-report.json`: `.assessment.code_quality.score`, `.assessment.doc_quality.score`, `.assessment.alignment.score`, `.strategy.id` (S1-S7), `.maturity.stage_modes`
- [ ] `domain-hints.json`: `.detected_domains` (array, may be empty)

#### L3
- [ ] `inventory/*.json` all valid JSON
- [ ] `source-files.json`: `.files` array, `.count` int
- [ ] `dependency-graph.json`: `.nodes`, `.edges`

#### L4
- [ ] `batch-*.json`: `.files[]` với `{path, system, module, category, confidence}`
- [ ] `glossary.json`: non-empty object

#### L5
- [ ] `extracted/{module}.json`: `.requirements[]` với `{id, description, source_files, confidence}`
- [ ] `id` matches `^TMP-REQ-[A-Z]+-\d+$`
- [ ] `confidence` trong [0, 1]

#### L6
- [ ] `project-context.md` có ≥ 6 sections (`grep -c "^## "`) for full; ≥4 for condensed
- [ ] `impact-graph.json`: `.nodes`, `.edges`, `.summary`

---

## T3 Content (Minimum Content Depth)

Check content đủ depth, không rỗng formal:

### Per Layer

#### L2
- [ ] `assessment-report.json` ≥ 200 bytes
- [ ] `.strategy.id` matches `^S[1-7]$`
- [ ] `.maturity.stage_modes | keys | length ≥ 4`

#### L3
- [ ] Source count consistency:
  ```bash
  # Tolerance theo tier (09 §2.2)
  # SMALL (<500): ±3%
  # LARGE (≥500): ±5%
  # Hard block: >15%
  ```

#### L4
- [ ] Coverage ≥ 95%:
  ```bash
  TOTAL=$(jq '.count' inventory/source-files.json)
  CLASSIFIED=$(jq -s '[.[].files | length] | add' classified/batch-*.json)
  echo "Coverage: $(awk "BEGIN {printf \"%.2f\", $CLASSIFIED/$TOTAL*100}")%"
  # >= 95% PASS, 90-95% WARN, <90% FAIL
  ```
- [ ] Glossary ≥ 20 terms (standard) hoặc ≥ 30 terms (deep)

#### L5
- [ ] Avg confidence per module:
  - Standard: ≥ 0.6 (hard block < 0.5)
  - Deep: ≥ 0.8 (hard block < 0.7)
- [ ] Every requirement có `source_files` non-empty (CORE-024)
- [ ] Every requirement có description ≥ 20 chars (CORE-029 spot-check)

#### L6
- [ ] `project-context.md` có ≥ 2000 bytes (condensed) / ≥ 3000 (full) / ≥ 4000 (full+insights)
- [ ] `impact-graph.json` có ≥ 1 node (nếu modules > 0)

---

## T4 Cross-Reference (Cross-Artifact Consistency)

Check IDs/references nhất quán giữa artifacts:

### Per Layer

#### L2
- [ ] `strategy.id` trong `assessment-report.json` = `strategy.id` trong `scan-state.json`
- [ ] Maturity level consistent

#### L3
- [ ] UI manifest consistency:
  ```bash
  jq -e '.coverage.total_screens >= .coverage.screens_with_routes' inventory/ui-manifest.json
  ```

#### L4
- [ ] Naming convention (CORE-016/017):
  ```bash
  # All modules lowercase-kebab-case
  jq -r '.files[].module' classified/batch-*.json | grep -vP '^[a-z][a-z0-9-]*$' | wc -l
  # Expect: 0
  ```
- [ ] Coverage = 100% (sum batches = total source files)

#### L5
- [ ] `module-code-mapping.json` entries ≥ extracted modules count
- [ ] TMP-ID format:
  ```bash
  jq -r '[.. | objects | .id? // empty] | .[]' extracted/*.json | grep -vP '^TMP-REQ-' | wc -l
  # Expect: 0
  ```
- [ ] Dedup report consistent:
  ```bash
  jq -e '.duplicates_merged >= 0' dedup-report.json
  ```

#### L6
- [ ] scan-state.json last_completed = "L6" + status = "completed"
- [ ] ledger.json generated = scan-state.json field reverse-check
- [ ] impact-graph.json nodes match modules từ extracted/*.json

#### Cross-Layer
- [ ] `phase-summary.md` có sections cho mọi completed layer (CORE-028)
- [ ] `session-log.json` events có START + COMPLETE cho mọi completed layer (CORE-026)
- [ ] `error-ledger.json` errors match error_log[] trong scan-state.json

---

## Verification Script

Tạo script chạy hết T1-T4:

```bash
#!/bin/bash
# verify-post-gate.sh <layer>

LAYER="$1"
WORK_DIR="${2:-.mc-data/work/legacy-scan}"

case "$LAYER" in
  L1)
    test -s "$WORK_DIR/project-profile.json" || exit 1
    jq -e '.file_counts.total >= 0' "$WORK_DIR/project-profile.json" || exit 2
    ;;
  L2)
    test -s "$WORK_DIR/assessment-report.json" || exit 1
    jq -e '.assessment.code_quality.score' "$WORK_DIR/assessment-report.json" || exit 2
    ;;
  # ... other layers
esac

echo "POST-GATE $LAYER: PASS"
```

---

## Escalation

Nếu ANY tier fail:

1. **T1 fail (missing file):** Re-run layer script/agent. Escalate after 2 retries.
2. **T2 fail (schema):** Auto-fix Protocol 2 (max 3 retries). Review template.
3. **T3 fail (content):** 
   - 90-95% → WARN + continue
   - <90% → HARD BLOCK + retry agent 1x + escalate
4. **T4 fail (cross-ref):** Usually indicates bug in state management. Investigate + fix root cause.
