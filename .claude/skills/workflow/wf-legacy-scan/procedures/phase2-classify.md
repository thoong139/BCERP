# Phase 2: Classify (Agent Delegation)

> **Skill:** wf-legacy-scan
> **Stage:** 2 (sau Phase 1 Inventory)
> **Mode:** Agent Delegation — bounded context (spawn code-reviewer agent direct; Phase D)
> **Load condition:** SKILL.md route vao file nay sau khi Phase 1 POST-GATE pass.

> **Phase D — Depth routing:** Trước khi spawn, đọc `scan-state.depth_map.L4`:
> - `"skip"` → mark `skipped_by_profile`, skip Phase 2 (surface profile skip extraction equivalent).
> - `"surface"` → heuristic-only grouping (no agent spawn). Xem §Surface Depth Heuristic.
> - `"standard"` / `"deep"` → spawn `code-reviewer` agent direct (không general-purpose wrapper).
> - `"deep"` → bổ sung enriched prompt + spawn `business-analyst` bổ sung cho glossary enrichment.

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

wf-legacy-scan chuyen sang vai tro **orchestrator**. Stage 2 chay trong Agent bounded context
de tranh context overflow o main context. Agent doc va thuc thi `/wf-legacy-classify` SKILL.md
day du. Main context CHI validate ket qua via POST-GATE (KHONG tin agent output).

## SKIP CONDITION

```
$STAGE_MODES.classify == "skip"
→ Bo qua Phase 2, jump thang den Phase 3 (phase3-extract.md)
→ Ly do: strategy S1 (FAST-TRACK) hoac $MATURITY_LEVEL == NEAR_COMPLETE
```

## PRE-GATE (Forensic — CORE-011, Protocol 10.4)

```
1. test -s .mc-data/work/legacy-scan/ledger.json
2. jq -e '.stages.inventory.status == "completed"' ledger.json
3. jq -e '.summary.total_items > 0' ledger.json
4. test -s .mc-data/work/legacy-scan/project-profile.json
5. jq -e '.tech_stack_verified' project-profile.json     # field exists (true hoac false-with-warning)
6. test -s .mc-data/work/legacy-scan/inventory/source-files.json
7. jq -e '.count >= 0' .mc-data/work/legacy-scan/inventory/source-files.json
```

Neu FAIL → áp dụng `_shared.md §On Failure — Standard Format`.

## INPUT

- `ledger.json`, `inventory/*.json`, `project-profile.json` (tat ca persist tu Phase 1)

## OUTPUT (sau khi Agent hoan tat)

- `.mc-data/work/legacy-scan/classified/batch-*.json`
- `.mc-data/work/legacy-scan/classified/glossary.json`
- `.mc-data/work/legacy-scan/classified/classify-naming-fixes.json` (CORE-016)

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 2.0 | **[TRACE START]** Append START event vao `session-log.json` (phase=2). Thong bao user: "Phase 1 hoan tat. Dang chay Phase 2: Phan loai files (delegate sang /wf-legacy-classify)..." | Bash | User informed |
| 2.0b | **[PHASE D — Depth route]** `$DEPTH_L4 = read_depth_map().get("L4", "standard")`. Nếu `"skip"` → mark L4 `skipped_by_profile` + SKIP Phase 2 entirely. Nếu `"surface"` → run heuristic grouping (xem §Surface Depth Heuristic Grouping) + SKIP agent spawn. Otherwise continue | Bash (Python helper) | `$DEPTH_L4` set, route quyết định |
| 2.1 | Spawn Agent (subagent_type=`code-reviewer` **direct** — không còn `general-purpose` wrapper) với prompt từ `_shared.md §Agent Prompt Templates (Stage 2 & 3) > Stage 2 Classify Prompt`. Prompt bao gồm: depth ($DEPTH_L4), IPS Phase A domain hints (top 3 detected_domains từ `read_ips_phase_a()`), naming convention rules (CORE-016/017). Nếu `$ACTION_TYPE == "resume_L4_intra_batch"` → extract `current_batch` + `current_file` từ `$RESUME_UNIT_JSON` và pass vào prompt làm `resume_from_batch=N, resume_from_file=path` để agent tiếp tục thay vì start lại. Nếu `$DEPTH_L4 == "deep"` → sau code-reviewer hoàn thành, spawn thêm `business-analyst` cho glossary enrichment (domain-specific terminology expansion) | Agent | Agent(s) started |
| 2.2 | Agent doc va thuc thi `.claude/skills/workflow/wf-legacy-classify/SKILL.md` day du (internal to agent) | (Agent internal) | Agent completed + reported |
| 2.3 | POST-GATE Phase 2: Main context validate (xem ben duoi). KHONG tin agent output truc tiep. | Read/Bash | All checks pass |
| 2.4 | Cap nhat `ledger.json`: `stages.classify.status = "completed"` + metadata (items_classified, glossary_size) qua **Atomic Write Pattern** | Edit | Ledger updated |
| 2.5 | Cap nhat `legacy-scan-status.json`: stage=2, status=completed (qua **Atomic Write Pattern**) | Edit | Status updated |
| 2.6 | **[PHASE SUMMARY]** APPEND section "Phase 2: Classify — PASS" vao `phase-summary.md` (note items_classified, glossary_size) | Write | Section appended |
| 2.7 | **[TRACE COMPLETE]** Append COMPLETE event vao `session-log.json` (phase=2, metadata={items_classified, glossary_size, retry_count}) | Bash | Event appended |
| 2.8 | **[TODO UPDATE]** Mark Phase 2 = completed; mark Phase 3 = in_progress (hoac completed-skipped neu `$STAGE_MODES.extract == "skip"`) | TodoWrite | Updated |

---

## POST-GATE Phase 2 (Tier T1→T4 — CORE-012, Protocol 10) — Main context validate

```
T1 — Existence:
  1. test -d .mc-data/work/legacy-scan/classified/
  2. ls .mc-data/work/legacy-scan/classified/batch-*.json | wc -l | awk '{exit ($1 == 0)}'
  3. test -s .mc-data/work/legacy-scan/classified/glossary.json
  4. # classify-naming-fixes.json la OPTIONAL — chi tao neu co fixes (CORE-016).
      # Clean project khong can fixes → file co the missing. Chap nhan absent.
      [ ! -e .mc-data/work/legacy-scan/classified/classify-naming-fixes.json ] || \
        test -s .mc-data/work/legacy-scan/classified/classify-naming-fixes.json
  5. test -s .mc-data/work/legacy-scan/phase-summary.md

T2 — Structure (JSON validity):
  6. jq '.' classified/glossary.json > /dev/null
  7. for f in classified/batch-*.json; do jq '.' "$f" > /dev/null || exit 1; done
  8. # classify-naming-fixes.json optional — chi validate khi ton tai
      [ ! -f classified/classify-naming-fixes.json ] || jq -e '.naming_fixes // []' classified/classify-naming-fixes.json

T3 — Content depth:
  9. ITEMS_CLASSIFIED=$(jq -s '[.[] | .items // [] | length] | add' classified/batch-*.json)
     TOTAL=$(jq '.summary.total_items' ledger.json)
     # >= 95% threshold; 90-95% WARNING; <90% HARD BLOCK
     awk -v c="$ITEMS_CLASSIFIED" -v t="$TOTAL" 'BEGIN { exit (t > 0 && c/t < 0.90) }'
  10. # Glossary la OBJECT (term → def). length > 0 = it nhat 1 key. Schema ref: templates/glossary.schema.json
      jq -e 'if type == "object" then (keys | length > 0) elif type == "array" then (length > 0) else false end' classified/glossary.json
  11. grep -q "Phase 2" .mc-data/work/legacy-scan/phase-summary.md

T4 — Cross-reference:
  12. jq -e '.stages.classify.status == "completed"' ledger.json
  13. jq -e '.stages.classify.status == "completed"' legacy-scan-status.json
  14. # items_classified <= total_items (sanity)
      [ "$ITEMS_CLASSIFIED" -le "$TOTAL" ]
  15. # v5.0 Dual-Status Mirror: scan-state.layers.L4 status updated
      jq -e '.layers.L4.status == "completed" or .layers.L4.status == "skipped_by_profile"' "$SESSION_DIR/scan-state.json"
  16. # CORE-028: sub-skill phase-summary (WARN khong block — chi canh bao)
      [ -s .mc-data/work/wf-legacy-classify/phase-summary.md ] || log_warn "CORE-028 sub-skill phase-summary missing for wf-legacy-classify"
```

Nếu ANY tier fail → áp dụng `_shared.md §Auto-Fix & Escalation Protocol`:
- T3 fail (90-95%) → WARNING + AskUserQuestion (tiep tuc hay re-run?)
- T3 fail (<90%) → HARD BLOCK, retry agent x1, sau do escalate
- T1/T2/T4 fail → re-spawn agent x1, sau do escalate

## On Failure

Theo `_shared.md §On Failure — Standard Format`. Cụ thể Phase 2:
- **TRUOC khi re-spawn Agent:** BACKUP + CLEAN `classified/` de tranh merge partial output cu:
  ```bash
  if [ -d classified/ ] && [ "$(ls classified/*.json 2>/dev/null | wc -l)" -gt 0 ]; then
    BACKUP_DIR="classified.failed.$(date -u +%Y%m%dT%H%M%SZ)"
    mv classified/ "$BACKUP_DIR/"
    mkdir -p classified/
    log_warn "Partial classify output moved to $BACKUP_DIR for forensics"
  fi
  ```
- Re-spawn Agent x1 voi prompt nhan manh schema requirements (fresh start)
- Neu van fail → STOP, AskUserQuestion: "Re-run /wf-legacy-classify --resume / Skip Phase 2 (risky) / Cancel"
- Huong dan user re-run standalone: `/wf-legacy-classify` (co the dung `--resume`)

**Ly do KHONG tin agent output:** Agent co the bao "completed" nhung files thuc te khong duoc ghi,
hoac ghi khong day du. Main context la single source of truth cho quyet dinh pipeline advance.

## Surface Depth Heuristic Grouping (Phase D — D.6)

> Khi `$DEPTH_L4 == "surface"`: **không spawn agent.** Thực hiện grouping heuristic no-AI,
> kết quả ghi vào `classified/auto-grouped.json` (không batches).
> Reference: `docs/design/skills/wf-legacy-scan/02-scan-layers.md §4.4.1`.

### Algorithm

```
non_module_dirs = {"src", "lib", "app", "tests", "config", "public", "static",
                    "dist", "build", "scripts", "node_modules", "vendor", ".git",
                    "target", "bin", "obj", "out", ".next", ".nuxt"}

files = read inventory/source-files.json
groups = {}  # module → files[]

FOR each file in files:
  parts = path.parts (exclude filename)
  module = None
  FOR part in parts:
    IF part.lower() NOT IN non_module_dirs:
      module = part.lower()  # first meaningful dir
      BREAK
  IF module IS None:
    module = "uncategorized"
  groups.setdefault(module, []).append(file.path)

# Naming normalization (CORE-016/017): lowercase-kebab-case
normalized = {}
FOR name, paths in groups:
  norm = normalize_module_name(name)  # PascalCase→kebab, spaces→dashes
  normalized.setdefault(norm, []).extend(paths)

# Write output (skip-if-exists respect)
output = {}
FOR name, paths in normalized:
  output[name] = {"files": paths, "confidence": 1.0, "source": "heuristic"}

WRITE classified/auto-grouped.json (atomic)
append_layer_output("L4", "classified/auto-grouped.json")
```

### Runtime Budget

- Target: ≤ 10 giây cho 500 files.
- Python pure logic — không AI, không spawn.

### POST-GATE Variation (Surface)

```
T1 — Existence:
  1. test -s classified/auto-grouped.json   # thay batch-*.json + glossary
T2 — Structure:
  2. jq '.' auto-grouped.json
  3. jq 'to_entries | .[0].value | has("files") and has("confidence") and has("source")' auto-grouped.json
T3 — Content:
  4. jq '[.[]| .files | length] | add' auto-grouped.json >= classified_count * 0.9
T4 — Cross-reference:
  5. jq '. | length > 0' auto-grouped.json
```

Surface profile KHÔNG yêu cầu glossary — skip T1.3, T2.2, T3.2 của standard POST-GATE.

---

## Deep Depth Enriched Prompt (Phase D — D.7)

> Khi `$DEPTH_L4 == "deep"`, prompt `code-reviewer` được mở rộng với:

```
[STANDARD PROMPT as-is]

### DEEP MODE ENRICHMENT
- IPS Phase A detected domains: [top 3 với confidence]
- IPS Phase A hot-signal file paths: [unresolved_patterns từ ips.phase_a]
- Confidence target: ≥ 0.85 (vs 0.75 standard). Nếu < 0.85 → re-classify với broader
  context (sibling directory structure).
- Naming normalization: apply CORE-016/017 aggressive (fuzzy Levenshtein ≤ 2 dedup).

### After code-reviewer hoàn thành
Spawn secondary `business-analyst` agent:
- Input: classified/batch-*.json + glossary.json draft
- Task: Enrich glossary với domain-specific terminology từ IPS Phase A (detected domains + VN pool)
- Output: augmented glossary.json (same path, merged terms, cross-validated với domain expertise).
```

Exhaustive profile thêm divergence detection trigger — xem 05-profiles-ips.md §4.3.

---

## Next Phase

→ **Phase 3** (`phase3-extract.md`) — Extract via Agent Delegation.
