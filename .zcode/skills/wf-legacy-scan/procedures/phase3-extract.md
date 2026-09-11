# Phase 3: Extract (Agent Delegation)

> **Skill:** wf-legacy-scan
> **Stage:** 3 (sau Phase 2 Classify)
> **Mode:** Agent Delegation — bounded context (spawn business-analyst + domain-expert direct; Phase D)
> **Load condition:** SKILL.md route vao file nay sau khi Phase 2 POST-GATE pass.

> **Phase D — Depth routing:**
> - `scan-state.depth_map.L5 == "skip"` → mark `skipped_by_profile`, skip extraction (surface profile).
> - `"standard"` → spawn `business-analyst` + `domain-expert` (if IPS confidence ≥ 0.6) **parallel** per module, max 3.
> - `"deep"` → spawn **sequential** BA → DE cross-validation pass (DE reviews BA output).
> - `"exhaustive"` → deep + divergence detection (S5 equivalent).
>
> **Direct agent spawn:** không còn `general-purpose` wrapper cho Phase 3 nữa — sub-skill được
> gọi qua Agent tool nhưng agent subagent_type chỉ định trực tiếp `business-analyst` /
> `[domain]-expert` theo IPS Phase B routing.

---

## Reference Sections

- `_shared.md` §Agent Prompt Templates (Stage 2 & 3)
- `_shared.md` §Pipeline Data Persistence Rules
- `_shared.md` §Atomic Write Pattern
- `_shared.md` §Execution Trace (CORE-026)
- `_shared.md` §Phase Summary (CORE-028)
- `_shared.md` §Auto-Fix & Escalation Protocol (Protocol 1, 2)
- `_shared.md` §On Failure — Standard Format
- `_shared.md` §Task Planning (Protocol 9)

## Mo ta

Spawn Agent delegate sang `/wf-legacy-extract` de trich xuat requirements/features
tu classified files + glossary. Main context POST-GATE validate ket qua sau khi agent complete.

## SKIP CONDITION

```
$STAGE_MODES.extract == "skip"
→ Bo qua Phase 3, jump thang den Phase 4 (phase4-synthesize.md)
→ Ly do: strategy S1 (FAST-TRACK), hoac $MATURITY_LEVEL == NEAR_COMPLETE,
  hoac $MATURITY_LEVEL == DEVKIT_COMPLETE (extract da done o session truoc)
```

## PRE-GATE (Forensic — CORE-011, Protocol 10.4)

```
1. test -s .mc-data/work/legacy-scan/ledger.json
2. jq -e '.stages.classify.status == "completed" or .maturity.stage_modes.classify == "skip"' ledger.json
3. Neu classify da chay (status=completed):
   # Phan biet surface mode (auto-grouped.json) vs standard+ (batches + glossary)
   DEPTH_L4=$(jq -r '.depth_map.L4 // "standard"' "$SESSION_DIR/scan-state.json" 2>/dev/null || echo standard)
   if [ "$DEPTH_L4" = "surface" ]; then
     test -s classified/auto-grouped.json && jq '.' classified/auto-grouped.json > /dev/null
   else
     test -d classified/ && [ "$(ls classified/batch-*.json 2>/dev/null | wc -l)" -gt 0 ]
     test -s classified/glossary.json
     jq '.' classified/glossary.json > /dev/null
   fi
4. Neu classify=skip: project-profile.json + inventory/source-files.json van phai ton tai
   - test -s .mc-data/work/legacy-scan/project-profile.json
   - test -s .mc-data/work/legacy-scan/inventory/source-files.json
```

Neu FAIL → áp dụng `_shared.md §On Failure — Standard Format`.

## INPUT

- `classified/batch-*.json`, `classified/glossary.json` (tu Phase 2, neu khong skip)
- `inventory/*.json`, `project-profile.json` (tu Phase 0-1)

## OUTPUT (sau khi Agent hoan tat)

- `.mc-data/work/legacy-scan/extracted/{module}.json` (per module)
- `.mc-data/work/legacy-scan/module-code-mapping.json` (CORE-013)
- `.mc-data/work/legacy-scan/dedup-report.json`

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.0 | **[TRACE START]** Append START event vao `session-log.json` (phase=3). Thong bao user: "Phase 2 hoan tat. Dang chay Phase 3: Trich xuat requirements (delegate sang /wf-legacy-extract)..." | Bash | User informed |
| 3.0b | **[PHASE D — Depth route]** `$DEPTH_L5 = read_depth_map().get("L5", "standard")`. Nếu `"skip"` → `update_layer_status("L5", "skipped_by_profile")` + SKIP Phase 3 entirely. Otherwise continue với depth-aware spawn (xem §Agent Routing) | Bash (Python helper) | `$DEPTH_L5` set, route quyết định |
| 3.1 | **[PHASE D — Direct agent spawn]** Sub-skill `/wf-legacy-extract` tự route spawn theo `$DEPTH_L5` + IPS Phase B module_routing (xem phase2-extraction.md). Wf-legacy-scan **không còn** dùng `general-purpose` wrapper; spawn trực tiếp sub-skill qua Agent tool với subagent_type phù hợp (`business-analyst` primary + domain expert secondary per module). Prompt từ `_shared.md §Agent Prompt Templates (Stage 2 & 3) > Stage 3 Extract Prompt`, bổ sung IPS context (detected_domains, hotspots, module_routing) | Agent | Agent(s) started |
| 3.2 | Agent doc va thuc thi `.claude/skills/workflow/wf-legacy-extract/SKILL.md` day du (internal to agent) | (Agent internal) | Agent completed + reported |
| 3.3 | POST-GATE Phase 3: Main context validate (xem ben duoi). KHONG tin agent output truc tiep. | Read/Bash | All checks pass |
| 3.4 | Cap nhat `ledger.json`: `stages.extract.status = "completed"` + metadata (modules_extracted, avg_confidence, dedup_count) qua **Atomic Write Pattern** | Edit | Ledger updated |
| 3.5 | Cap nhat `legacy-scan-status.json`: stage=3, status=completed (qua **Atomic Write Pattern**) | Edit | Status updated |
| 3.6 | **[PHASE SUMMARY]** APPEND section "Phase 3: Extract — PASS" vao `phase-summary.md` (note modules_extracted, avg_confidence) | Write | Section appended |
| 3.7 | **[TRACE COMPLETE]** Append COMPLETE event vao `session-log.json` (phase=3, metadata={modules_extracted, avg_confidence, dedup_count, retry_count}) | Bash | Event appended |
| 3.8 | **[TODO UPDATE]** Mark Phase 3 = completed; mark Phase 4 = in_progress | TodoWrite | Updated |

---

## POST-GATE Phase 3 (Tier T1→T4 — CORE-012, Protocol 10) — Main context validate

```
T1 — Existence:
  1. test -d .mc-data/work/legacy-scan/extracted/
  2. ls .mc-data/work/legacy-scan/extracted/*.json | wc -l | awk '{exit ($1 == 0)}'
  3. test -s .mc-data/work/legacy-scan/module-code-mapping.json   # CORE-013
  4. # dedup-report.json duoc wf-legacy-extract ghi vao extracted/ (khong phai root)
      test -s .mc-data/work/legacy-scan/extracted/dedup-report.json
  5. test -s .mc-data/work/legacy-scan/phase-summary.md

T2 — Structure (JSON validity + required fields):
  6. jq '.' module-code-mapping.json > /dev/null
  7. for f in extracted/*.json; do jq '.' "$f" > /dev/null || exit 1; done
  8. jq -e '.duplicates_merged // 0' extracted/dedup-report.json
  9. # Mỗi extracted/{module}.json co confidence field (bo qua dedup-report.json)
     for f in extracted/*.json; do
       [ "$(basename "$f")" = "dedup-report.json" ] && continue
       jq -e '.confidence // 0' "$f" > /dev/null || exit 1
     done

T3 — Content depth:
  10. # avg_confidence >= 0.6 (warning 0.5-0.6, hard block <0.5)
      # EXCLUDE dedup-report.json khoi confidence calc — no khong phai module.
      AVG_CONF=$(find extracted/ -maxdepth 1 -name '*.json' ! -name 'dedup-report.json' -exec cat {} + | \
                 jq -s '[.[] | .confidence // 0] | if length > 0 then (add / length) else 0 end')
      awk -v a="$AVG_CONF" 'BEGIN { exit (a < 0.5) }'   # HARD BLOCK <0.5
  11. # Tat ca modules tu classify co extracted file tuong ung (loai dedup-report)
      EXTRACTED_COUNT=$(find extracted/ -maxdepth 1 -name '*.json' ! -name 'dedup-report.json' 2>/dev/null | wc -l)
      [ "$EXTRACTED_COUNT" -gt 0 ]
  12. grep -q "Phase 3" .mc-data/work/legacy-scan/phase-summary.md

T4 — Cross-reference:
  13. jq -e '.stages.extract.status == "completed"' ledger.json
  14. jq -e '.stages.extract.status == "completed"' legacy-scan-status.json
  15. # module-code-mapping.json co entries cho cac modules da extract
      MAPPED_MODULES=$(jq '. | length' module-code-mapping.json 2>/dev/null || echo 0)
      [ "$MAPPED_MODULES" -ge "$EXTRACTED_COUNT" ] || [ "$MAPPED_MODULES" -gt 0 ]
  16. # v5.0 Dual-Status Mirror: scan-state.layers.L5 status updated
      jq -e '.layers.L5.status == "completed" or .layers.L5.status == "skipped_by_profile"' "$SESSION_DIR/scan-state.json"
  17. # CORE-028: sub-skill phase-summary (WARN khong block)
      [ -s .mc-data/work/wf-legacy-extract/phase-summary.md ] || log_warn "CORE-028 sub-skill phase-summary missing for wf-legacy-extract"
```

Nếu ANY tier fail → áp dụng `_shared.md §Auto-Fix & Escalation Protocol`:
- T3 fail (avg_confidence 0.5-0.6) → WARNING + tiep tuc
- T3 fail (<0.5) → HARD BLOCK, re-spawn agent x1 voi prompt nhan manh confidence calibration
- T1/T2/T4 fail → re-spawn agent x1, sau do escalate

## On Failure

Theo `_shared.md §On Failure — Standard Format`. Cụ thể Phase 3:
- **TRUOC khi re-spawn Agent:** BACKUP + CLEAN `extracted/` + `module-code-mapping.json`:
  ```bash
  if [ -d extracted/ ] && [ "$(ls extracted/*.json 2>/dev/null | wc -l)" -gt 0 ]; then
    BACKUP_DIR="extracted.failed.$(date -u +%Y%m%dT%H%M%SZ)"
    mv extracted/ "$BACKUP_DIR/"
    mkdir -p extracted/
    [ -f module-code-mapping.json ] && mv module-code-mapping.json "$BACKUP_DIR/"
    log_warn "Partial extract output moved to $BACKUP_DIR for forensics"
  fi
  ```
- Re-spawn Agent x1 voi prompt nhan manh schema requirements + dedup quality (fresh start)
- Neu van fail → STOP, AskUserQuestion: "Re-run /wf-legacy-extract --resume / Skip Phase 3 (synthesize voi limited data) / Cancel"
- Huong dan user re-run standalone: `/wf-legacy-extract` (co the dung `--resume`)

## Agent Routing (Phase D)

> Sub-skill `/wf-legacy-extract` là single source of truth cho per-module routing.
> Phase 3 orchestrator (this file) chỉ:
> 1. Set context (depth, IPS Phase B payload cache).
> 2. Delegate `/wf-legacy-extract` qua Agent tool một lần.
> 3. POST-GATE validate output (không trust agent report).

### Depth → Spawn Strategy

| `$DEPTH_L5` | Strategy | Parallel cap | Confidence target | Agent timeout |
|-------------|----------|--------------|-------------------|---------------|
| `skip` | N/A (mark skipped, không spawn) | 0 | — | — |
| `surface` | BA-only, 1 agent per module | 3 | ≥ 0.6 | 300s |
| `standard` | BA + DE (if conf ≥ 0.6) parallel | 3 | ≥ 0.7 | 300s |
| `deep` | BA → DE sequential cross-validation | 2 | ≥ 0.8 | 600s |
| `exhaustive` | deep + from_code vs from_docs divergence | 2 | ≥ 0.85 | 600s |

### IPS Phase B Payload

Phase 3 agent prompt bao gồm:
```
IPS Phase B Routing:
- module_routing: {billing: {expert: finance-expert, confidence: 0.85}, ...}
- complexity_hotspots: [{module: billing, files: 42, coupling: 7}, ...]
- workload_estimate: {total_features_est: 85, est_time_min: 125, ...}
```

Sub-skill sử dụng `get_domain_expert_for_module()` helper để route per-module — threshold 0.6
(ADR-LS06 §2.1).

### CORE-029 Spot-Check (ADR-LS17)

Sau mỗi module extract, sub-skill runs 3-random-sample spot-check trên `extracted/{module}.json`:
- TMP-ID format: `^TMP-REQ-[A-Z]+-\d+$`
- `source_files[]` non-empty + paths exist
- `confidence ∈ [0, 1]`
- `description.length >= 20`

Fail → 1 re-try với re-enriched prompt; 2nd fail → log E022 + WARNING.

---

## Next Phase

→ **Phase 4** (`phase4-synthesize.md`) — Synthesize project-context.md.
