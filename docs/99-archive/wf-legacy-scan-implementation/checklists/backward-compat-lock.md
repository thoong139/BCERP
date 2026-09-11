# Checklist: Backward-Compat Lock Verification (ADR-LS06)

> **Purpose:** Verify `standard` profile của v5.0 = v4.1.0 behaviour.
> **Apply to:** Phase D Task D.9 (golden test), Phase I Task I.12 (final regression).
> **Blocking for release.**

---

## Pre-Test Setup

- [ ] 3 fixtures có v4.1 baseline output (từ Phase A.3):
  - `fixtures/small-en.baseline-v4.1/`
  - `fixtures/medium-vn.baseline-v4.1/`
  - `fixtures/large-mixed.baseline-v4.1/`
- [ ] v5.0 code at current phase checkpoint
- [ ] Branch clean, no uncommitted changes

---

## Test Execution

Run trên cả 3 fixtures:

```bash
for fx in small-en medium-vn large-mixed; do
  cd fixtures/$fx/
  rm -rf .mc-data/
  time /wf-legacy-scan . --profile=standard
  cd -
done
```

---

## Structural Comparison

Cho mỗi fixture:

- [ ] **Output files exist:**
  - [ ] `project-context.md`
  - [ ] `project-profile.json`
  - [ ] `assessment-report.json`
  - [ ] `ledger.json` (v5.0 generated at POST Phase 4)
  - [ ] `inventory/*.json` (screens, api-endpoints, source-files, dependency-graph, doc-files, external-docs)
  - [ ] `classified/batch-*.json` + `classified/glossary.json`
  - [ ] `extracted/{module}.json`
  - [ ] `module-code-mapping.json`
  - [ ] `impl-status-snapshot.json`
  - [ ] `doc-quality-map.json`

- [ ] **v5.0-specific new outputs:**
  - [ ] `sessions/{id}/scan-state.json`
  - [ ] `sessions/{id}/phase-summary.md`
  - [ ] `domain-hints.json`
  - [ ] `impact-graph.json`

- [ ] **project-context.md sections match:**
  ```bash
  diff \
    <(grep "^## " fixtures/$fx/.mc-data/work/legacy-scan/project-context.md) \
    <(grep "^## " fixtures/${fx}.baseline-v4.1/project-context.md)
  ```
  Expect: identical section names + count

---

## Content Drift Check

Cho mỗi fixture:

- [ ] **Feature count drift ≤ ±5%:**
  ```bash
  V5=$(jq -s '[.[].features // [] | length] | add' .mc-data/work/legacy-scan/extracted/*.json)
  V4=$(jq -s '[.[].features // [] | length] | add' fixtures/${fx}.baseline-v4.1/extracted/*.json)
  echo "diff: $(( (V5-V4)*100/V4 ))%"
  ```

- [ ] **Requirement count drift ≤ ±5%:**
  ```bash
  V5=$(jq -s '[.[].requirements // [] | length] | add' .mc-data/work/legacy-scan/extracted/*.json)
  V4=$(jq -s '[.[].requirements // [] | length] | add' fixtures/${fx}.baseline-v4.1/extracted/*.json)
  ```

- [ ] **Module count ±1 module tolerance:**
  ```bash
  V5=$(ls .mc-data/work/legacy-scan/extracted/*.json | wc -l)
  V4=$(ls fixtures/${fx}.baseline-v4.1/extracted/*.json | wc -l)
  ```

- [ ] **Avg confidence không degrade:**
  ```bash
  V5=$(jq -s '[.[].requirements // [] | .[].confidence // 0] | add/length' .mc-data/work/legacy-scan/extracted/*.json)
  V4=$(jq -s '[.[].requirements // [] | .[].confidence // 0] | add/length' fixtures/${fx}.baseline-v4.1/extracted/*.json)
  # V5 should be ≥ V4 (improvement expected due to direct agent spawn)
  ```

- [ ] **REQ-ID format consistent:**
  ```bash
  # No invalid IDs
  jq -r '[.. | objects | .id? // empty] | .[]' .mc-data/work/legacy-scan/extracted/*.json | \
    grep -vP '^(TMP-)?(REQ|FEAT)-[A-Z]+-\d+$' | wc -l
  # Expect: 0
  ```

---

## Agent Behaviour Check

- [ ] **L4 agent type:** code-reviewer (NOT general-purpose wrapper)
  ```bash
  grep -r "subagent_type=\"code-reviewer\"" .claude/skills/workflow/wf-legacy-scan/procedures/
  # Expect: found trong phase2-classify.md (or equivalent)
  
  grep -r "subagent_type=\"general-purpose\"" .claude/skills/workflow/wf-legacy-scan/procedures/
  # Expect: NOT found (except in legacy fallback comments)
  ```

- [ ] **L5 agents:** business-analyst + domain-expert (when match ≥0.6)
  - [ ] Fixture medium-vn: check extracted output có dấu hiệu của domain-expert (domain-specific terminology)

- [ ] **L5 fallback:** business-analyst only khi no domain match
  - [ ] Fixture small-en với module generic (`utils`, `helpers`): only business-analyst invoked

---

## Runtime Compare

- [ ] **Standard profile time đúng estimate:**
  | Fixture | v4.1 | v5.0 target | Actual |
  |---------|------|-------------|--------|
  | small-en | 5-10 min | ≤10 min | ??? |
  | medium-vn | 30-90 min | 20-40 min | ??? |
  | large-mixed | Context overflow | 40-90 min | ??? |

- [ ] **No context overflow** trên large-mixed (v5.0 should handle via Workload Gate WARN)

---

## Downstream Integration Check

- [ ] **LEGACY_MODE detection (CORE-021):**
  ```bash
  test -s .mc-data/work/legacy-scan/project-context.md
  wc -c .mc-data/work/legacy-scan/project-context.md
  # Expect: > 500 bytes
  ```

- [ ] **ledger.json v4.1 schema valid cho downstream:**
  ```bash
  jq empty .mc-data/work/legacy-scan/ledger.json
  jq '.pipeline_status' .mc-data/work/legacy-scan/ledger.json
  # Expect: "COMPLETE"
  
  # Required fields
  jq -e '.stages.classify.status' .mc-data/work/legacy-scan/ledger.json
  jq -e '.stages.extract.status' .mc-data/work/legacy-scan/ledger.json
  jq -e '.maturity.level' .mc-data/work/legacy-scan/ledger.json
  jq -e '.strategy.id' .mc-data/work/legacy-scan/ledger.json
  ```

- [ ] **`/wf-brainstorm` detect LEGACY_MODE:**
  ```bash
  cd fixtures/small-en/
  /wf-brainstorm
  # Expect: skill detect project-context.md + inject legacy context
  ```

- [ ] **`/wf-analyze-requirements` consume project-context.md correctly**

- [ ] **`/wf-design` legacy flow build registry từ extracted data**

---

## Verdict Per Fixture

Mỗi fixture PASS khi:
- [ ] All structural items ticked
- [ ] Drift ≤ ±5% cho feature + requirement counts
- [ ] No invalid REQ-ID
- [ ] Confidence ≥ v4.1 baseline
- [ ] Agent spawn pattern correct
- [ ] Runtime trong estimate
- [ ] Downstream skills work

Fixture FAIL nếu:
- Drift > 5%
- Invalid IDs xuất hiện
- Confidence degrade > 10%
- Downstream skills fail
- Runtime > 150% estimate

---

## Final Verdict

- [ ] **small-en:** PASS / FAIL
- [ ] **medium-vn:** PASS / FAIL
- [ ] **large-mixed:** PASS / FAIL

**Gate:** 3/3 PASS → ok to tag phase. < 3 PASS → STOP + investigate + fix.

---

## If FAIL — Root Cause Analysis

1. **Drift > 5%:**
   - Possible: v5.0 detects more/less features due to domain detection change
   - Action: review detected_domains vs baseline; if legitimate improvement (VN detection) → document exception
   
2. **Invalid REQ-ID:**
   - Possible: template bug or agent prompt ambiguity
   - Action: fix template + prompt; add CORE-029 spot-check (if not already)

3. **Confidence degrade:**
   - Possible: wrong domain expert routed
   - Action: check threshold 0.6 (09 §2.1); verify domain-hints.json accuracy

4. **Downstream fail:**
   - Possible: ledger.json schema mismatch
   - Action: re-check `generate_legacy_ledger()` function output

5. **Runtime slip:**
   - Possible: checkpoint write overhead, cache miss
   - Action: profile scan run; check write throttle 5s + cache setup
