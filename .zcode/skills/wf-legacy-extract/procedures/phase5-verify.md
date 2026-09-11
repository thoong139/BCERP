# Phase 5: Verification & Completion

> Post-Stage verification (self-diagnostic), auto-fix loops cho missing modules,
> POST-GATE T1-T4 checks, update ledger + legacy-scan-status.json,
> generate phase-summary.md (CORE-028), close session log.

**PRE-GATE:**
- [ ] Phase 4 POST-GATE PASS (hoặc jump từ Phase 0 nếu `$MATURITY_MODE == "skip"`)
- [ ] Nếu `$MATURITY_MODE != "skip"`: `extracted/dedup-report.json` và `module-code-mapping.json` tồn tại
- [ ] `$EXTRACTED_MODULES`, `$LOW_CONFIDENCE_MODULES`, `$DEDUP_STATS`, `$MODULE_CODE_MAPPING` đã set (hoặc empty cho skip mode)

**INPUT:**
- `.mc-data/work/legacy-scan/extracted/*.json`
- `.mc-data/work/legacy-scan/module-code-mapping.json`
- `$EXTRACTED_MODULES`, `$LOW_CONFIDENCE_MODULES`, `$DEDUP_STATS`

**OUTPUT:**
- Ledger updated (`stages.extract.status = "completed"`, summary stats)
- `legacy-scan-status.json` updated (`stages.extract.*`, `current_stage = "normalize"`)
- `.mc-data/work/wf-legacy-extract/phase-summary.md` (CORE-028)
- Session-log COMPLETE entry (CORE-026)
- Output report cho user

---

## Reference Sections

- `_shared.md` §Registry Safe-Write
- `_shared.md` §Error Code Reference (E020, E022)
- `.claude/skills/protocols/` §14 Phase Summary Protocol
- `.claude/skills/protocols/` §15 Session Log Protocol

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 5.0 | **Skip mode shortcut:** Nếu `$MATURITY_MODE == "skip"` → chỉ chạy Steps 5.5 (ledger update với note `skipped_maturity`), 5.7 (phase-summary), 5.8 (session log). Skip các steps verification | — | Skip mode handled |
| 5.1 | **Self-diagnostic verification:** Xem §Self-Diagnostic | Read/Bash | Verification pass |
| 5.2 | **Auto-fix missing modules (max 3 iterations):** Nếu phát hiện thiếu `extracted/{module}.json` → re-run Phase 2 extraction cho modules đó. Max 3 attempts. Xem §Auto-Fix Loop | Agent | Missing modules resolved hoặc E020 |
| 5.3 | **Confidence check:** Tính `avg_confidence` across tất cả modules. Nếu < 0.6 → WARNING E022, log `$LOW_CONFIDENCE_MODULES`. Nếu < 0.4 → ESCALATE | — | Confidence evaluated |
| 5.4 | **POST-GATE T1-T4 checks:** Xem §POST-GATE Tiered Validation | Bash | All gates pass |
| 5.5 | **Update ledger.json (safe-write):** `stages.extract.status = "completed"`, `stages.extract.completed_at`, `summary.by_stage.extracted = total_reqs_extracted`, `summary.reqs_extracted`, `summary.features_extracted`, `summary.low_confidence_modules[]`. Xem §Ledger Update | Read/Write | `jq '.' ledger.json` pass |
| 5.6 | **Update legacy-scan-status.json (safe-write):** `stages.extract.status = "completed"`, `stages.extract.completed_at`, `stages.extract.modules_completed`, `stages.extract.modules_total`, `current_stage = "normalize"`, `next_action = "Stage 4: Normalize"` | Read/Write | File updated |
| 5.6b | **[PHASE D — Scan-state dual-write]** Mark L5 completed qua helper: `update_layer_status("L5", "completed")`. Skip mode: `"skipped_by_profile"`. Failure path (E022 < 0.4 escalate): `"failed"` + `append_error("L5", {code: "E022", ...})`. Defensive: nếu helper throw (missing session), log WARNING và tiếp tục. Xem `_shared.md §Scan-State Integration` | Bash (Python helper) | `scan-state.layers.L5.status` updated |
| 5.7 | **Generate phase-summary.md (CORE-028):** READ `.claude/doc-framework/_meta/phase-summary.template.md` → POPULATE theo format tiếng Việt, <= 15 dòng, non-specialist → WRITE `.mc-data/work/wf-legacy-extract/phase-summary.md` | Read/Write | File non-empty |
| 5.8 | **Close session log (CORE-026):** Append COMPLETE entry → `.mc-data/work/_trace/session-log.json` với stats (modules_extracted, reqs_count, features_count, duration) | Write | Entry appended |
| 5.9 | **Display output report:** Xem §Output Report Format | — | Report shown |

---

## Self-Diagnostic (Step 5.1)

```
VERIFICATIONS:
1. Module completeness:
   - Đọc classified/batch-*.json → group theo module → danh sách ALL_MODULES
   - IF $MODULE_FILTER set: ALL_MODULES = [$MODULE_FILTER] only
   - FOR each module IN ALL_MODULES:
     verify test -f extracted/{module}.json && test -s extracted/{module}.json
   - Collect missing_modules[]
   
2. File integrity:
   - FOR each extracted/{module}.json:
     jq '.' file → must pass (valid JSON)
     jq '.requirements | type == "array"' → must pass
     jq '.features | type == "array"' → must pass
     jq '.stats' → must exist
   
3. Core outputs:
   - test -f extracted/dedup-report.json (non-empty, valid JSON)
   - test -f module-code-mapping.json (non-empty, valid JSON)
   - jq '.mappings | length > 0' module-code-mapping.json
   
4. Status files:
   - test -s extract-status.json
   - jq '.' extract-status.json pass
   - test -s extract-plan.md

5. S5 divergence (conditional):
   IF $STRATEGY_ID == "S5" OR $MATURITY_LEVEL IN (CODE_PLUS_*):
     FOR each module IN $EXTRACTED_MODULES:
       verify test -f extracted/{module}-divergences.json
```

---

## Auto-Fix Loop (Step 5.2)

```
attempt = 0
WHILE missing_modules != [] AND attempt < 3:
  attempt += 1
  Log: "Auto-fix attempt [attempt]/3 — re-extracting [N] missing modules"
  
  FOR module IN missing_modules:
    # Re-run Phase 2 extraction logic cho module này
    READ $MODULE_DIGESTS[module]
    spawn Agent(subagent_type=$DOMAIN_EXPERTS[module] or "business-analyst", ...)
    result = agent.result()
    
    IF result.success:
      [READ-TEMPLATE] templates/extracted-module.json
      POPULATE + WRITE extracted/{module}.json
      remove module từ missing_modules
    ELSE:
      Log: "Auto-fix attempt [attempt] failed for [module]"

IF missing_modules != []:
  WARNING E020: "Sau 3 auto-fix attempts, vẫn thiếu: [missing_modules]"
  AskUserQuestion: "Continue without these modules? (Y/N)"
  IF N: STOP với error report
  IF Y: log vào warnings, tiếp tục POST-GATE
```

---

## POST-GATE Tiered Validation (Step 5.4)

**Áp dụng Protocol 10 — T1→T4 checks:**

```
# T1: File existence
test -f .mc-data/work/legacy-scan/extract-status.json
test -f .mc-data/work/legacy-scan/extract-plan.md
test -f .mc-data/work/legacy-scan/extracted/dedup-report.json
test -f .mc-data/work/legacy-scan/module-code-mapping.json
IF $MODULE_FILTER set:
  test -f extracted/{$MODULE_FILTER}.json
ELSE:
  FOR each module IN $EXTRACTED_MODULES:
    test -f extracted/{module}.json

# T2: File non-empty
test -s .mc-data/work/legacy-scan/extract-status.json
test -s .mc-data/work/legacy-scan/extract-plan.md
test -s .mc-data/work/legacy-scan/extracted/dedup-report.json
test -s .mc-data/work/legacy-scan/module-code-mapping.json
FOR each module file: test -s

# T3: Format valid
jq '.' extract-status.json > /dev/null
jq '.' extracted/dedup-report.json > /dev/null
jq '.' module-code-mapping.json > /dev/null
FOR each module file: jq '.' > /dev/null

# T4: Required content present
jq -e '.mappings | length > 0' module-code-mapping.json
jq -e '.merged' extracted/dedup-report.json  # field exists
FOR each module file:
  jq -e '.requirements | type == "array"' file
  jq -e '.features | type == "array"' file
  jq -e '.stats' file
  jq -e '.module' file

# Additional checks
avg_confidence >= 0.6 (WARNING E022 nếu thấp hơn)
Tất cả module names trong extracted/*.json filenames PHẢI match normalized names từ Phase 1
IF $STRATEGY_ID == "S5": test -f extracted/{module}-divergences.json cho mỗi module

# T5 (v5.0): Session Scan-State Layer Check
SESSION_DIR=".mc-data/work/legacy-scan/sessions/$SESSION_ID"
if test -f "$SESSION_DIR/scan-state.json"; then
  L5_STATUS=$(jq -r '.layers.L5.status // "unknown"' "$SESSION_DIR/scan-state.json")
  if [ "$L5_STATUS" != "completed" ] && [ "$L5_STATUS" != "skipped_by_profile" ]; then
    WARN: "scan-state.layers.L5.status = $L5_STATUS (expected: completed/skipped_by_profile)"
    # KHÔNG FAIL — chỉ WARN để orchestrator biết session có thể stale
  fi
fi

IF ANY T1-T4 check fail → STOP, KHÔNG mark stages.extract.status = completed
```

---

## Ledger Update (Step 5.5 — Safe-Write)

```
# ĐỌC ledger NGAY TRƯỚC KHI GHI (không cache)
ledger = jq '.' .mc-data/work/legacy-scan/ledger.json

# CHỈ modify fields được phân công (CORE-006)
ledger.stages.extract.status = "completed"
ledger.stages.extract.completed_at = ISO_8601_NOW
ledger.stages.extract.modules_completed = len($EXTRACTED_MODULES)
ledger.stages.extract.modules_total = len($MODULE_MAP)

total_reqs = sum(r.stats.total_requirements for each extracted/*.json)
total_features = sum(r.stats.total_features for each extracted/*.json)

ledger.summary.by_stage.extracted = total_reqs
ledger.summary.reqs_extracted = total_reqs
ledger.summary.features_extracted = total_features

IF $LOW_CONFIDENCE_MODULES không rỗng:
  ledger.summary.low_confidence_modules = $LOW_CONFIDENCE_MODULES

IF $MATURITY_MODE == "skip":
  ledger.stages.extract.note = "skipped_maturity"

# GHI ATOMIC (single write)
write ledger.json

# VALIDATE sau ghi
jq '.' ledger.json > /dev/null  # must pass
```

---

## Output Report Format (Step 5.9)

```markdown
## /wf-legacy-extract Hoàn tất!

| Mục | Giá trị |
|-----|---------|
| Modules processed | [done]/[total] |
| Requirements extracted | [count] |
| Features extracted | [count] |
| Avg confidence | [score] |
| Low confidence items | [count] (< 0.5) |
| Low confidence modules | [count] (avg < 0.85) |
| Dedup merges | [count] |
| Dedup ambiguous | [count] |
| Divergences (S5) | [count] |
| Cross-cutting flags | [count] |
| Phantom modules | [count] |
| Errors | [count] |

### Output Files

| # | File | Path | Purpose |
|---|------|------|---------|
| 1 | extracted/{module}.json | .mc-data/work/legacy-scan/extracted/ | Requirements + features per module |
| 2 | dedup-report.json | .mc-data/work/legacy-scan/extracted/ | Dedup results |
| 3 | {module}-divergences.json | .mc-data/work/legacy-scan/extracted/ | Divergences (S5 only) |
| 4 | module-code-mapping.json | .mc-data/work/legacy-scan/ | Module ↔ code project mapping |
| 5 | phase-summary.md | .mc-data/work/wf-legacy-extract/ | CORE-028 summary |

### Warnings

[List low-confidence modules nếu có]
[List cross-cutting warnings nếu có]
[List ambiguous dedup pairs nếu có]

Next: `/wf-brainstorm` (legacy flow)
```

---

## POST-GATE (Phase 5 exit)

- [ ] `ledger.json` — `stages.extract.status == "completed"`
- [ ] `legacy-scan-status.json` — `stages.extract.status == "completed"`, `current_stage == "normalize"`
- [ ] `extract-status.json` — `status == "completed"`
- [ ] `phase-summary.md` tồn tại, non-empty, tiếng Việt
- [ ] Session-log COMPLETE entry appended
- [ ] Output report displayed cho user

**Next step:** Skill completed — user chạy `/wf-brainstorm` (legacy flow) tiếp theo.
