# Phase 0.5: Maturity Validation

> **Skill:** wf-legacy-scan
> **Stage:** 0.5 (sau Phase 0A Assessment)
> **Mode:** HYBRID — validate + score
> **Load condition:** Chi chay khi `$MATURITY_LEVEL` IN ("CODE_PLUS_DEVKIT_PARTIAL", "CODE_PLUS_DEVKIT_COMPLETE", "NEAR_COMPLETE")

---

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §Strategy & Stage Mode Reference
- `_shared.md` §Atomic Write Pattern
- `_shared.md` §Execution Trace (CORE-026)
- `_shared.md` §Phase Summary (CORE-028)
- `_shared.md` §Auto-Fix & Escalation Protocol (Protocol 1, 2)
- `_shared.md` §On Failure — Standard Format
- `_shared.md` §Task Planning (Protocol 9)

## Mo ta

Validate existing DEVKIT artifacts (.mc-data/ docs, registry) de xac dinh chinh xac muc do hoan thien.
Ket qua: `$STAGE_MODES` chinh xac cho tung downstream stage (skip/delta/merge/validate/fast-track).

## SKIP CONDITION

```
$MATURITY_LEVEL IN ("CODE_ONLY", "CODE_PLUS_EXTERNAL_DOCS", "DOCS_ONLY")
→ Skip Phase 0.5 hoan toan, dung default $STAGE_MODES tu Phase 0A
→ Jump thang den Phase 1 (phase1-inventory.md)
```

## PRE-GATE (Forensic — CORE-011, Protocol 10.4)

```
1. test -s .mc-data/work/legacy-scan/assessment-report.json
2. jq -e '.scores.code_quality.score' assessment-report.json
3. test -s .mc-data/work/legacy-scan/ledger.json
4. jq -e '.strategy.id | test("^S[1-7]$")' ledger.json
5. jq -e '.maturity.stage_modes' ledger.json
6. jq -e '.doc_maturity.level' .mc-data/work/legacy-scan/project-profile.json
```

Nếu ANY fail → áp dụng `_shared.md §On Failure — Standard Format`.
KHÔNG dùng plain `test -f` — phải verify content theo CORE-011.

## INPUT

- `project-profile.json` (doc_maturity.phase_status + registry_stats)
- `ledger.json` (strategy, initial stage_modes)

## OUTPUT

- `ledger.json` updated (maturity.validation_result + refined `$STAGE_MODES`)
- `legacy-scan-status.json` updated (maturity_validation completed)

## Steps

| Step   | Action                                                                                 | Tool       | Verify                                   |
| ------ | -------------------------------------------------------------------------------------- | ---------- | ---------------------------------------- |
| 0.5.0  | **[TRACE START]** Append START event vao `session-log.json` (phase=0.5)                 | Bash       | Event appended                           |
| 0.5.1  | Doc `project-profile.json` → lay `doc_maturity.phase_status` va `registry_stats`       | Read       | Data loaded                              |
| 0.5.2  | Validate Phase 0 (`phase0-brainstorm/`): kiem tra files ton tai, doc voi `_contract.json` | Read/Bash  | `phase0.exists` + `phase0.contract_pass` set |
| 0.5.3  | Validate Phase 1 (`phase1-business/`): kiem tra files ton tai, doc voi `_contract.json`  | Read/Bash  | `phase1.exists` + `phase1.contract_pass` set |
| 0.5.4  | Validate Phase 2 (`phase2-features/`): kiem tra feature files, doc voi `_contract.json`  | Read/Bash  | `phase2.exists` + `phase2.contract_pass` set |
| 0.5.5  | Validate Phase 3 (`phase3-architecture/`): kiem tra arch docs, doc voi `_contract.json`  | Read/Bash  | `phase3.exists` + `phase3.contract_pass` set |
| 0.5.6  | Validate Registry (`_meta/req-registry.json`): `jq '.' registry.json`, kiem tra required fields (systems, modules, requirements, features) | Bash | Registry valid/invalid |
| 0.5.7  | Tinh maturity score: dem phases pass / total phases. Cap nhat `stage_modes` dua tren ket qua (xem Scoring Logic) | — | Score + modes determined |
| 0.5.8  | **AskUserQuestion**: hien thi maturity assessment (xem format ben duoi), user xac nhan  | AskUserQuestion | User confirmed                           |
| 0.5.9  | **[READ-TEMPLATE]** Re-read `ledger.json` hien co → MERGE `maturity.validation_result` + `stage_modes` (giu structure tu `templates/ledger.json` lam schema reference) → WRITE qua **Atomic Write Pattern** | Write      | Ledger updated                           |
| 0.5.10 | Cap nhat `legacy-scan-status.json`: maturity_validation completed (qua **Atomic Write Pattern**)                       | Write      | Status updated                           |
| 0.5.11 | **[PHASE SUMMARY]** APPEND section "Phase 0.5: Maturity Validation — PASS" vao `phase-summary.md` (note maturity_score, stage_modes overrides) | Write | Section appended |
| 0.5.12 | **[TRACE COMPLETE]** Append COMPLETE event vao `session-log.json` (phase=0.5, metadata={maturity_score, phases_pass, stage_modes_changed}) | Bash | Event appended |
| 0.5.13 | **[TODO UPDATE]** Mark Phase 0.5 = completed; mark Phase 1 = in_progress | TodoWrite | Updated |

## Scoring Logic

```
phases_checked = [phase0, phase1, phase2, phase3]
phases_exist = count(p for p in phases_checked if p.exists)
phases_pass = count(p for p in phases_checked if p.contract_pass)
registry_valid = registry passes jq + has required fields

maturity_score = phases_pass / 4

# Cap nhat stage_modes dua tren ket qua thuc te:
FOR each phase P in [phase0, phase1, phase2, phase3]:
  IF P.contract_pass → stage_modes[P] = "validate"   # Chi can validate, khong tao lai
  IF P.exists AND NOT P.contract_pass → stage_modes[P] = "merge"  # Co nhung thieu/sai → merge
  IF NOT P.exists → stage_modes[P] = "create"         # Chua co → tao moi

# Registry:
IF registry_valid → stage_modes.registry = "validate"
IF registry exists AND NOT valid → stage_modes.registry = "merge"
IF NOT registry exists → stage_modes.registry = "create"

# Classify/Extract: dua tren so phases can tao/merge
IF phases_pass >= 3 → stage_modes.classify = "delta", stage_modes.extract = "delta"
IF phases_pass == 4 AND maturity == NEAR_COMPLETE → stage_modes.classify = "skip", stage_modes.extract = "skip"
ELSE → stage_modes.classify = "full", stage_modes.extract = "full"

# Gap Analysis:
IF maturity == NEAR_COMPLETE AND phases_pass == 4 → stage_modes.gap_analysis = "fast-track"
ELSE → stage_modes.gap_analysis = "full"
```

## AskUserQuestion Format (Step 0.5.8)

```
question: |
  ## Maturity Validation

  | Phase | Ton tai | Contract Pass | Stage Mode |
  |-------|---------|---------------|------------|
  | Phase 0 (Brainstorm) | [Yes/No] | [Pass/Fail/N/A] | [validate/merge/create] |
  | Phase 1 (Business) | [Yes/No] | [Pass/Fail/N/A] | [validate/merge/create] |
  | Phase 2 (Features) | [Yes/No] | [Pass/Fail/N/A] | [validate/merge/create] |
  | Phase 3 (Architecture) | [Yes/No] | [Pass/Fail/N/A] | [validate/merge/create] |
  | Registry | [Valid/Invalid/N/A] | — | [validate/merge/create] |

  | Thong tin | Gia tri |
  |-----------|---------|
  | Maturity Score | [N]/4 phases pass |
  | Classify mode | [skip/delta/full] |
  | Extract mode | [skip/delta/full] |
  | Gap Analysis mode | [fast-track/full] |

  **De xuat:** [Mo ta hanh dong tiep theo dua tren ket qua]

  Ban muon tiep tuc?
options:
  - "Dong y — tiep tuc voi stage_modes nhu tren"
  - "Thay doi — [chi dinh mode can thay]"
  - "Re-scan — chay lai tu Stage 0"
  - "Huy — khong tiep tuc"
```

## POST-GATE (Tier T1→T4 — CORE-012, Protocol 10)

```
T1 — Existence:
  1. test -s .mc-data/work/legacy-scan/ledger.json
  2. test -s .mc-data/work/legacy-scan/phase-summary.md

T2 — Structure:
  3. jq -e '.maturity.validation_result' ledger.json
  4. jq -e '.maturity.stage_modes' ledger.json
  5. jq -e '.maturity.validation_result.maturity_score' ledger.json

T3 — Content depth:
  6. jq -e '.maturity.stage_modes | keys | length >= 4' ledger.json    # ≥4 stages
  7. jq -e '.maturity.validation_result.phases_checked | length == 4' ledger.json
  8. grep -q "Phase 0.5" .mc-data/work/legacy-scan/phase-summary.md

T4 — Cross-reference:
  9. jq -e '.stages.maturity_validation.status == "completed"' legacy-scan-status.json
  10. # User confirmed qua AskUserQuestion Step 0.5.8 (in-memory $USER_CONFIRMED == true)
  11. # stage_modes downstream consistency: classify mode hop le voi maturity score
      MATURITY_SCORE=$(jq -r '.maturity.validation_result.maturity_score' ledger.json)
      CLASSIFY_MODE=$(jq -r '.maturity.stage_modes.classify' ledger.json)
      # NEAR_COMPLETE (score=1.0) → classify=skip; phases_pass>=3 → delta; ELSE → full
      # (Logic check tuy thuoc implementation thuc te — gate khuyen nghi log warning neu inconsistent)
```

Nếu ANY tier fail → áp dụng `_shared.md §Auto-Fix & Escalation Protocol` (max 1 retry per tier).
Sau retry vẫn fail → đi qua `_shared.md §On Failure — Standard Format`.

## On Failure

Theo `_shared.md §On Failure — Standard Format`. Cụ thể Phase 0.5:
- T1/T2 fail → re-run Step 0.5.9 (re-write ledger)
- T3 fail (stage_modes thieu) → re-run Step 0.5.7 (re-compute scoring)
- T4 fail (status mismatch) → re-run Step 0.5.10
- Sau 3 attempts vẫn fail → STOP, AskUserQuestion: "Manual fix / Skip phase 0.5 (use default modes) / Cancel"

## Next Phase

→ **Phase 1** (`phase1-inventory.md`) — Inventory scan.
