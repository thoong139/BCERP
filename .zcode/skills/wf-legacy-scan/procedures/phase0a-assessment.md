# Phase 0A: Assessment Framework

> **Skill:** wf-legacy-scan
> **Stage:** 0A (sau Phase 0 Detection)
> **Mode:** HYBRID — script (quantitative) + AI (qualitative)
> **Load condition:** SKILL.md route vao file nay sau khi Phase 0 POST-GATE pass.

---

## Reference Sections (lazy-load khi can)

- `_shared.md` §State Variables Glossary
- `_shared.md` §Strategy & Stage Mode Reference
- `_shared.md` §Atomic Write Pattern
- `_shared.md` §Execution Trace (CORE-026)
- `_shared.md` §Phase Summary (CORE-028)
- `_shared.md` §Auto-Fix & Escalation Protocol (Protocol 1, 2)
- `_shared.md` §On Failure — Standard Format
- `_shared.md` §Task Planning (Protocol 9)

## Mo ta

Assessment 3 chieu (code quality, doc quality, alignment) + Strategy selection.
HYBRID: Script (quantitative) tinh scores → AI (qualitative) dien giai va chon strategy.
Chay cho TAT CA du an, bat ke kich co.

## PRE-GATE (Forensic — CORE-011, Protocol 10.4)

```
1. test -s .mc-data/work/legacy-scan/project-profile.json     # T1 + non-empty
2. jq -e '.tech_stack_verified' project-profile.json           # field exists (true/false)
3. jq -e '.doc_maturity.level' project-profile.json            # maturity required
4. jq -e '.file_counts.total >= 0' project-profile.json        # counts numeric
5. test -s .mc-data/work/legacy-scan/legacy-scan-status.json
6. jq -e '.stages.detection.status == "completed"' legacy-scan-status.json
```

Nếu ANY fail → áp dụng `_shared.md §On Failure — Standard Format`.
KHÔNG dùng plain `test -f` — phải verify content tồn tại theo CORE-011.

## INPUT

- `project-profile.json` (tu Phase 0)
- `$USER_FLAG_RE_VISION` (tu Phase 0)

## OUTPUT

- `.mc-data/work/legacy-scan/assessment-scores.json` (intermediate, script output)
- `.mc-data/work/legacy-scan/assessment-report.json` (final Phase 0A output)
- `.mc-data/work/legacy-scan/ledger.json` (init + strategy + stage_modes)
- In-memory state: `$STRATEGY`, `$STAGE_MODES`

## Steps

| Step | Action | Tool | Verify |
| ---- | ------ | ---- | ------ |
| 0A.0 | **[TRACE START]** Append START event vao `session-log.json` (phase=0A) theo `_shared.md §Execution Trace (CORE-026)` | Bash | Event appended |
| 0A.1 | Chay `.claude/scripts/legacy-scan-assess.sh "$PROJECT_PATH" .mc-data/work/legacy-scan` → `assessment-scores.json` | Bash | `test -s .mc-data/work/legacy-scan/assessment-scores.json` |

> **Note:** `assessment-scores.json` la intermediate file (raw scores tu script). KHONG co template rieng — day la script output. File nay khong duoc list trong _contract.json vi no la internal processing step, KHONG phai final output. Final output la assessment-report.json (Step 0A.7).
| 0A.2 | Doc `assessment-scores.json` + `project-profile.json` → tong hop du lieu | Read | Data loaded |
| 0A.3 | Dien giai scores, xac dinh strategy theo Strategy Routing Logic (ben duoi) | — | Strategy determined |
| 0A.4 | **AskUserQuestion**: hien thi assessment + recommendation (xem format ben duoi) | AskUserQuestion | User confirmed |
| 0A.5 | Neu user override: cap nhat strategy tuong ung | — | Strategy finalized |
| 0A.6 | Map strategy → stage_modes (xem Strategy-to-Modes Mapping) | — | Modes determined |
| 0A.7 | **[READ-TEMPLATE]** READ `templates/assessment-report.json` → POPULATE (scores, levels, strategy, stage_modes) → WRITE `.mc-data/work/legacy-scan/assessment-report.json` qua **Atomic Write Pattern** | Write | Report exists |
| 0A.8 | **[READ-TEMPLATE]** READ `templates/ledger.json` (lan dau) hoac re-read `ledger.json` hien co → POPULATE/MERGE assessment + strategy + stage_modes → WRITE `.mc-data/work/legacy-scan/ledger.json` qua **Atomic Write Pattern** | Write | Ledger updated |
| 0A.9 | Cap nhat `legacy-scan-status.json`: assessment completed (qua **Atomic Write Pattern**) | Edit | Status updated |
| 0A.10 | **[PHASE SUMMARY]** APPEND section "Phase 0A: Assessment — PASS" vao `phase-summary.md` theo `_shared.md §Phase Summary (CORE-028)` (note strategy + project size) | Write | Section appended |
| 0A.11 | **[TRACE COMPLETE]** Append COMPLETE event vao `session-log.json` (phase=0A, metadata={strategy, code_score, doc_score, alignment_score}) | Bash | Event appended |
| 0A.12 | **[TODO UPDATE]** Mark Phase 0A = completed; mark Phase 0B = in_progress (LUON — Phase 0B BAT BUOC chay cho moi maturity de resolve profile + depth_map) | TodoWrite | Updated |

## Strategy Routing Logic

```
INPUT: maturity_level (tu project-profile.json), scores (tu assessment-scores.json), user_flag (--re-vision)

IF user_flag == "re-vision" → S6: RE-VISION

IF maturity IN (DEVKIT_COMPLETE, NEAR_COMPLETE):
  IF alignment_level >= HIGH → S1: FAST-TRACK
  ELSE → S5: DIVERGENCE-RESOLVE

IF maturity == DOCS_ONLY:
  IF doc_level >= HIGH → S3: DOCS-FIRST
  ELSE → S4: DOCS-BRAINSTORM

IF maturity == CODE_ONLY:
  IF code_level >= MED → S2: CODE-FIRST
  IF code_level == LOW → S7: FULL-REBUILD

IF maturity == CODE_PLUS_EXTERNAL_DOCS:
  IF alignment_level >= HIGH → S1: FAST-TRACK
  IF alignment_level >= MED → S2: CODE-FIRST (docs as context)
  ELSE → S5: DIVERGENCE-RESOLVE

IF maturity == CODE_PLUS_DEVKIT_PARTIAL:
  IF alignment_level >= MED → S2: CODE-FIRST (merge mode)
  ELSE → S5: DIVERGENCE-RESOLVE

DEFAULT → S2: CODE-FIRST
```

## 7 Strategies

| ID | Name | Mo ta | Typical maturity |
|----|------|-------|-----------------|
| S1 | FAST-TRACK | Skip Stage 2-4, fast-track gap analysis | DEVKIT_COMPLETE/NEAR_COMPLETE + HIGH alignment |
| S2 | CODE-FIRST | Full pipeline, code la primary source (backward compatible) | CODE_ONLY, MED+ code |
| S3 | DOCS-FIRST | Docs la primary source, confidence cap 0.7 | DOCS_ONLY, HIGH docs |
| S4 | DOCS-BRAINSTORM | Docs + AskUserQuestion bo sung 3-5 cau | DOCS_ONLY, LOW docs |
| S5 | DIVERGENCE-RESOLVE | Detect va resolve conflicts code vs docs | EXTERNAL_DOCS + LOW alignment |
| S6 | RE-VISION | Giu code constraints, thay doi vision moi | User explicit --re-vision |
| S7 | FULL-REBUILD | Requirements from scratch, code chi lam reference | CODE_ONLY, LOW code |

## Strategy-to-Modes Mapping

| Stage | S1 | S2 | S3 | S4 | S5 | S6 | S7 |
|-------|----|----|----|----|----|----|-----|
| 0.5 Maturity | run | skip | skip | skip | skip | skip | skip |
| 2 Classify | skip | full | full | full | full | full | full |
| 3 Extract | skip | full | full | full | full | full | full |
| 4p Phase 0 | validate | create | create | create | create | create | create |
| 4a Phase 1 | validate | create | create | create | create | create | create |
| 4b Phase 2 | validate | create | create | create | create | create | create |
| 4c Phase 3 | validate | create | create* | create* | create | create | create |
| 4d Registry | validate | create | create | create | create | create | create |
| 5 Gap | fast-track | full | coverage | coverage | full | full | full |

> `create*` DOCS_ONLY (S3/S4): Phase 3 limited — khong co code de analyze architecture chi tiet.

## AskUserQuestion Format (Step 0A.4)

```
question: |
  ## Assessment Du an

  | Chieu danh gia | Score | Level |
  |----------------|-------|-------|
  | Code Quality | [score]/100 | [HIGH/MED/LOW/NONE] |
  | Doc Quality | [score]/100 | [HIGH/MED/LOW/NONE] |
  | Alignment | [score]/100 | [HIGH/MED/LOW/NONE] |

  | Thong tin | Gia tri |
  |-----------|---------|
  | Maturity Level | [level] |
  | Project Size | [SMALL/MEDIUM/LARGE] ([N] files) |
  | Strategy de xuat | [S1-S7]: [name] |

  **Mo ta strategy:** [1-2 cau mo ta]

  Ban muon tiep tuc voi strategy nay?
options:
  - "Dong y — tiep tuc voi [strategy name]"
  - "Thay doi strategy: [list alternatives]"
  - "Huy — khong tiep tuc"
```

## POST-GATE (Tier T1→T4 — CORE-012, Protocol 10)

```
T1 — Existence:
  1. test -s .mc-data/work/legacy-scan/assessment-report.json
  2. test -s .mc-data/work/legacy-scan/ledger.json
  3. test -s .mc-data/work/legacy-scan/phase-summary.md

T2 — Structure:
  4. jq -e '.scores.code_quality.score' assessment-report.json
  5. jq -e '.scores.doc_quality.score' assessment-report.json
  6. jq -e '.scores.alignment.score' assessment-report.json
  7. jq -e '.strategy.id' ledger.json                      # strategy set
  8. jq -e '.maturity.stage_modes' ledger.json             # stage_modes map set

T3 — Content depth:
  9. jq -e '.strategy.id | test("^S[1-7]$")' ledger.json    # strategy ID hop le
  10. jq -e '.maturity.stage_modes | keys | length >= 4' ledger.json  # ≥4 stages mapped
  11. wc -c < assessment-report.json | awk '{exit ($1 < 200)}'         # ≥200 bytes
  12. grep -q "Phase 0A" .mc-data/work/legacy-scan/phase-summary.md

T4 — Cross-reference:
  13. STRATEGY_REPORT=$(jq -r '.strategy.id // empty' assessment-report.json)
      STRATEGY_LEDGER=$(jq -r '.strategy.id' ledger.json)
      [ -z "$STRATEGY_REPORT" ] || [ "$STRATEGY_REPORT" = "$STRATEGY_LEDGER" ]
  14. jq -e '.stages.assessment.status == "completed"' legacy-scan-status.json
  15. # User confirmed qua AskUserQuestion Step 0A.4 (in-memory state $USER_CONFIRMED == true)
```

Nếu ANY tier fail → áp dụng `_shared.md §Auto-Fix & Escalation Protocol` (max 1 retry per tier).
Sau retry vẫn fail → đi qua `_shared.md §On Failure — Standard Format`.

## On Failure

Theo `_shared.md §On Failure — Standard Format`. Cụ thể Phase 0A:
- T1 fail (assessment-report.json missing) → re-run Step 0A.7
- T2 fail (.score missing) → re-run Step 0A.1 (`legacy-scan-assess.sh`)
- T3 fail (strategy invalid) → re-run Step 0A.3-0A.6
- T4 fail (strategy mismatch) → re-run Step 0A.7-0A.8
- Sau 3 attempts vẫn fail → STOP, AskUserQuestion options

## Next Phase

→ **Phase 0B** (`phase0b-profile.md`) — Profile Resolver + IPS-A (LUON chay, khong phu thuoc maturity)

> **QUAN TRONG:** Phase 0B BAT BUOC chay sau Phase 0A de resolve `$PROFILE`, `$DEPTH_MAP`, `$SYNTHESIS_MODE` vao `scan-state.json`. Bo qua Phase 0B se lam `--profile` CLI flag mat tac dung va depth routing v5.0 gay. Phase 0.5 Maturity Validation se duoc Phase 0B route den sau neu $MATURITY_LEVEL IN (CODE_PLUS_DEVKIT_PARTIAL, CODE_PLUS_DEVKIT_COMPLETE, NEAR_COMPLETE).
