# Phase 0B: Profile Resolver + IPS-A

> **Skill:** wf-legacy-scan (v5.0+)
> **Stage:** 0B (sau Phase 0A Assessment, truoc Phase 0.5 Maturity)
> **Mode:** HYBRID — Python IPS module + main-context decision + AskUserQuestion (CDG)
> **Load condition:** Luon chay sau Phase 0A POST-GATE pass.
> **Skip condition:** Nếu `--status` hoac `--resume` da dispatch — KHÔNG chay Phase 0B.

---

## Mo ta

Phase 0B la depth resolver — chuan hoa `depth_map` (L1..L6) + `synthesis_mode`
ghi vao `scan-state.json` truoc khi Phase 1 Inventory chay. Nguon quyet dinh:

1. **CLI flag `--profile=<p>`**: explicit — skip IPS recommendation.
2. **CLI flag `--layers=... --depth=...`**: per-layer override sau khi profile da set.
3. **Default (no flag)**: chay IPS Phase A de recommend profile → AskUserQuestion CDG.

Profile resolver KHONG thay doi scan-layers co ban — no chi phoi depth tung layer
theo Profile → Depth Map canonical (xem 05-profiles-ips.md §1.2).

## Reference Sections (lazy-load khi can)

- `_shared.md` §State Variables Glossary
- `_shared.md` §Atomic Write Pattern
- `_shared.md` §Execution Trace (CORE-026)
- `_shared.md` §Phase Summary (CORE-028)
- `_shared.md` §Critical Decision Gate (CORE-027)
- `_shared.md` §On Failure — Standard Format
- `05-profiles-ips.md` §1 Profiles Overview + §3 IPS Design
- `09-thresholds-justification.md` §2.1 Domain thresholds

---

## Canonical Profile → Depth Map

| Profile | L1 | L2 | L3 | L4 | L5 | L6 `synthesis_mode` |
|---------|----|----|----|----|----|---------------------|
| surface | full | full | full | surface | skip | condensed |
| standard ★ | full | full | full | standard | standard | full |
| deep | full | full | full | deep | deep | full+insights |
| exhaustive | full | full | full | deep | deep | full+divergence |

★ standard = v4.1 backward-compat lock.

**Default khi unresolved:** profile = `standard`.

---

## PRE-GATE (Forensic — CORE-011)

```
1. test -s .mc-data/work/legacy-scan/assessment-report.json
2. jq -e '.scores.code_quality.score' assessment-report.json
3. jq -e '.scores.doc_quality.score' assessment-report.json
4. test -s "$SESSION_DIR/scan-state.json"
5. jq -e '.session.id' "$SESSION_DIR/scan-state.json"
6. test -s .mc-data/work/legacy-scan/project-profile.json
7. jq -e '.file_counts.total >= 0' project-profile.json
```

Nếu ANY fail → `_shared.md §On Failure — Standard Format`.

## INPUT

- `project-profile.json` (tu Phase 0)
- `assessment-report.json` (tu Phase 0A)
- `$SESSION_DIR/scan-state.json` (tu Phase 0)
- CLI flags: `--profile`, `--layers`, `--depth`, `--no-interactive`

## OUTPUT

- `$SESSION_DIR/ips-phase-a.json` (domain-hints + profile recommendation)
- `$SESSION_DIR/scan-state.json` updated fields:
  - `session.profile` — final profile chosen
  - `depth_map` — per-layer depth
  - `synthesis_mode` — L6 mode
  - `ips.phase_a` — inline snapshot tu ips-phase-a.json
- In-memory state: `$PROFILE`, `$DEPTH_MAP`, `$SYNTHESIS_MODE`, `$USER_OVERRODE_PROFILE`

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0B.0 | **[TRACE START]** Append START event vao `session-log.json` (phase=0B) | Bash | Event appended |
| 0B.1 | **Parse CLI flags**: extract `$CLI_PROFILE`, `$CLI_LAYERS`, `$CLI_DEPTH`, `$CLI_NO_INTERACTIVE` tu `$ARGUMENTS` | Bash | Flags captured |
| 0B.2 | **Validate `--profile`**: neu set, phai IN (`surface`, `standard`, `deep`, `exhaustive`). ERROR E020 neu invalid. | — | Valid or error |
| 0B.3 | **Run IPS-A**: xem §Run IPS Phase A ben duoi. Output: `$SESSION_DIR/ips-phase-a.json`. **SKIP** neu `LEGACY_V41_STRICT=1` env (pure v4.1 behavior — fallback recommended_profile="standard"). | Bash | File exists + valid JSON hoac skipped |
| 0B.4 | **Profile Decision**: xem §Profile Decision Logic ben duoi. Set `$PROFILE`, `$USER_OVERRODE_PROFILE`. | AskUserQuestion / — | Profile resolved |
| 0B.5 | **Build depth_map**: xem §Build Depth Map ben duoi. Set `$DEPTH_MAP`, `$SYNTHESIS_MODE`. | — | Map + mode set |
| 0B.6 | **Apply per-layer overrides** (`--layers` + `--depth`): validate + merge vao `$DEPTH_MAP`. | — | Overrides merged |
| 0B.7 | **Warnings**: detect warning conditions (xem §Warning Matrix) va hien thi cho user. | — | — |
| 0B.8 | **Persist to scan-state.json**: atomic write `session.profile`, `depth_map`, `synthesis_mode`, `ips.phase_a` (inline tom tat). | Edit | Fields updated |
| 0B.9 | **[PHASE SUMMARY]** APPEND section "Phase 0B: Profile Resolver — PASS" vao `phase-summary.md` (note profile + reasoning + overrides) | Write | Section appended |
| 0B.10 | **[TRACE COMPLETE]** Append COMPLETE event (phase=0B, metadata={profile, user_overrode, detected_domains_count}) | Bash | Event appended |
| 0B.11 | **[TODO UPDATE]** Mark Phase 0B = completed. Neu `$MATURITY_LEVEL` IN (DEVKIT_PARTIAL+/COMPLETE/NEAR_COMPLETE) mark Phase 0.5 = in_progress; nguoc lai mark Phase 0.5 = completed (skipped) + Phase 1 = in_progress. | TodoWrite | Updated |
| 0B.12 | **[DOMAIN-HINTS COPY]** Copy `$SESSION_DIR/ips-phase-a.json` → `.mc-data/work/legacy-scan/domain-hints.json` (strip session-specific fields), consumers downstream (wf-legacy-classify, wf-legacy-extract, wf-design) read standard path: `jq 'del(.run_at, .session_id) \| ."$schema" = "domain-hints-v1"' "$SESSION_DIR/ips-phase-a.json" > .mc-data/work/legacy-scan/domain-hints.json` | Bash | File exists at standard path |

---

## Run IPS Phase A

```bash
# Orchestrator shell-out sang Python IPS module.
# CHU Y: `ips` package goc tai `.claude/skills/workflow/_shared/` — phai cd vao day
# truoc khi invoke. Dung realpath de tranh paths relative break sau cd.
REPO_ROOT="$(pwd)"
PROJECT_PROFILE_ABS="$(cd "$REPO_ROOT" && realpath .mc-data/work/legacy-scan/project-profile.json)"
ASSESSMENT_ABS="$(cd "$REPO_ROOT" && realpath .mc-data/work/legacy-scan/assessment-report.json)"
IPS_A_OUT_ABS="$(realpath "$SESSION_DIR/ips-phase-a.json" 2>/dev/null || echo "$SESSION_DIR/ips-phase-a.json")"

if ! ( cd "$REPO_ROOT/.claude/skills/workflow/_shared" && \
       python -m ips.ips_recommender phase_a \
         --project-profile "$PROJECT_PROFILE_ABS" \
         --assessment     "$ASSESSMENT_ABS" \
         --output         "$IPS_A_OUT_ABS" ) 2>>"$SESSION_DIR/ips-errors.log"; then
  log_warn "IPS Phase A failed → fallback profile=standard"
  jq -n '{recommended_profile:"standard", detected_domains:[], unresolved_patterns:[], warnings:[{code:"W0B05", message:"IPS-A module invocation failed; see ips-errors.log"}], user_overrode_profile:false}' \
    > "$IPS_A_OUT_ABS"
fi
```

Output `$SESSION_DIR/ips-phase-a.json` schema (xem `templates/domain-hints.json`):

```json
{
  "run_at": "2026-04-22T14:30:00Z",
  "recommended_profile": "deep",
  "profile_reasoning": "Large/complex project (1500 files, 2 domains)",
  "detected_domains": [
    {"domain": "finance", "confidence": 0.85, "language": "en", ...},
    {"domain": "logistics", "confidence": 0.72, "language": "en", ...}
  ],
  "unresolved_patterns": [],
  "warnings": [],
  "user_overrode_profile": false
}
```

**Fallback**: neu Python module fail hoac unavailable → WARN + `recommended_profile = "standard"`.

---

## Profile Decision Logic

```
CASE 1 — `--profile=<p>` explicit:
  $PROFILE = $CLI_PROFILE
  $USER_OVERRODE_PROFILE = false  # user specified via flag, not prompt override
  Skip AskUserQuestion.
  IF IPS-A recommended a different profile with confidence >= 0.75 → WARN only (xem §Warning Matrix).

CASE 2 — `--no-interactive` set:
  $PROFILE = ips_phase_a.recommended_profile (hoac "standard" fallback)
  $USER_OVERRODE_PROFILE = false
  Skip AskUserQuestion.

CASE 3 — Default (interactive):
  Display AskUserQuestion CDG (xem §AskUserQuestion Format).
  User chooses → $PROFILE = choice.
  IF choice != ips.recommended → $USER_OVERRODE_PROFILE = true
  ELSE $USER_OVERRODE_PROFILE = false
```

**CDG (CORE-027):** Profile selection la critical decision — user PHAI explicit confirm.
Default button = IPS recommendation. [Enter] = accept.

---

## AskUserQuestion Format

```
question: |
  ## Phase 0B: Chon Profile Scan

  Phan tich ban dau (IPS-A):
  - Du an: <project_name>
  - Kich thuoc: <file_count> files (<languages>)
  - Maturity: <maturity_level>
  - Domain phat hien: <domain1> (<conf1>), <domain2> (<conf2>), ...

  Khuyen nghi: **<recommended_profile>**
    Ly do: <reasoning>

  Chon profile scan:

options:
  - "surface — Overview nhanh (~5-10 min, KHONG extraction)"
  - "standard — Onboarding chuan (~20-40 min, = v4.1 behaviour) ★ DEFAULT"
  - "deep — Phan tich chuyen sau (~45-90 min, domain experts enriched)"
  - "exhaustive — Audit toan dien (~90-180 min, + divergence detection)"
  - "Huy — khong tiep tuc"
```

Implementation: orchestrator uses `AskUserQuestion` tool. Pre-select option khop voi
`ips_phase_a.recommended_profile` (hien UI cue "← Khuyen nghi").

---

## Build Depth Map

```
$PROFILE_DEPTH_MAP = {
  "surface":    {L1: "full", L2: "full", L3: "full", L4: "surface",  L5: "skip",     L6: "condensed"},
  "standard":   {L1: "full", L2: "full", L3: "full", L4: "standard", L5: "standard", L6: "full"},
  "deep":       {L1: "full", L2: "full", L3: "full", L4: "deep",     L5: "deep",     L6: "full+insights"},
  "exhaustive": {L1: "full", L2: "full", L3: "full", L4: "deep",     L5: "deep",     L6: "full+divergence"}
}

$DEPTH_MAP = $PROFILE_DEPTH_MAP[$PROFILE]
$SYNTHESIS_MODE = $DEPTH_MAP.L6   # L6 value la synthesis mode
```

## Per-Layer Overrides

```
IF $CLI_LAYERS set AND $CLI_DEPTH set:
  FOR layer IN $CLI_LAYERS.split(","):
    IF layer NOT IN (L1..L6) → ERROR E021, STOP.
    IF $CLI_DEPTH NOT IN ("surface", "standard", "deep", "full", "skip", "condensed",
                          "full+insights", "full+divergence") → ERROR E022, STOP.
    $DEPTH_MAP[layer] = $CLI_DEPTH

IF ONLY $CLI_LAYERS set OR ONLY $CLI_DEPTH set:
  ERROR E023: "--layers and --depth must be used together".

Post-validate: L1-L3 PHAI IN (full, skip) — cac layer deterministic (bash).
  Neu set sai (vd L3=deep) → ERROR E024, STOP.
```

---

## Warning Matrix

| Condition | Warning code | Message |
|-----------|--------------|---------|
| `$CLI_PROFILE=surface` AND `file_count > 1000` | W0B01 | "Surface profile khong full coverage cho du an lon (>1000 files). Consider --profile=standard." |
| `$CLI_PROFILE=surface` AND `ips.detected_domain.confidence >= 0.85` | W0B02 | "Surface skip extraction nhung detected <domain> voi confidence <conf> — co the miss context." |
| `$CLI_PROFILE=standard` AND `ips.recommended_profile=deep` AND any domain `>= 0.75` | W0B03 | "Standard profile co the miss domain-specific requirements (detected: <domains>)." |
| Override via `--layers` lam L5=skip | W0B04 | "L5 skip se KHONG co extraction output (features/requirements)." |
| IPS-A Python module failed | W0B05 | "IPS recommender failed — falling back to 'standard' profile." |

Warnings la informational, KHONG block. Persist vao `scan-state.ips.phase_a.warnings[]`.

---

## Error Codes (Phase 0B specific)

| Code | Message | Remedy |
|------|---------|--------|
| E020 | Invalid profile value (`--profile=<x>`) | List valid options, STOP |
| E021 | Invalid layer ID (`--layers=<x>`) | List valid L1..L6, STOP |
| E022 | Invalid depth value (`--depth=<x>`) | List valid depth values, STOP |
| E023 | `--layers` requires `--depth` (and vice versa) | Report usage, STOP |
| E024 | L1/L2/L3 depth must be full or skip | Report constraint, STOP |
| E025 | IPS-A output missing required field (`recommended_profile`) | Re-run IPS Python module (auto-fix x1) |

---

## POST-GATE (Tier T1→T4 — CORE-012)

```
T1 — Existence:
  1. test -s "$SESSION_DIR/ips-phase-a.json"
  2. test -s "$SESSION_DIR/scan-state.json"
  3. test -s .mc-data/work/legacy-scan/phase-summary.md

T2 — Structure:
  4. jq -e '.recommended_profile' "$SESSION_DIR/ips-phase-a.json"
  5. jq -e '.detected_domains' "$SESSION_DIR/ips-phase-a.json"
  6. jq -e '.session.profile' "$SESSION_DIR/scan-state.json"
  7. jq -e '.depth_map' "$SESSION_DIR/scan-state.json"
  8. jq -e '.synthesis_mode' "$SESSION_DIR/scan-state.json"
  9. jq -e '.ips.phase_a' "$SESSION_DIR/scan-state.json"

T3 — Content depth:
  10. jq -e '.depth_map | keys | length == 6' "$SESSION_DIR/scan-state.json"  # all 6 layers
  11. jq -e '.session.profile | test("^(surface|standard|deep|exhaustive)$")' "$SESSION_DIR/scan-state.json"
  12. grep -q "Phase 0B" .mc-data/work/legacy-scan/phase-summary.md

T4 — Cross-reference:
  13. PROFILE_STATE=$(jq -r '.session.profile' "$SESSION_DIR/scan-state.json")
      L6_MODE=$(jq -r '.synthesis_mode' "$SESSION_DIR/scan-state.json")
      # surface → condensed; standard → full; deep → full+insights; exhaustive → full+divergence
      case "$PROFILE_STATE" in
        surface)    [ "$L6_MODE" = "condensed" ] ;;
        standard)   [ "$L6_MODE" = "full" ] ;;
        deep)       [ "$L6_MODE" = "full+insights" ] || true ;;   # override cho phep
        exhaustive) [ "$L6_MODE" = "full+divergence" ] || true ;;
      esac
  14. # IPS-A recommendation persisted
      jq -e '.ips.phase_a.recommended_profile' "$SESSION_DIR/scan-state.json"
```

Nếu ANY tier fail → `_shared.md §Auto-Fix & Escalation Protocol` (max 1 retry per tier).

## On Failure

Theo `_shared.md §On Failure — Standard Format`. Cụ thể Phase 0B:
- T1 fail (ips-phase-a.json missing) → re-run Step 0B.3 x1
- T2 fail (.recommended_profile missing) → re-run IPS-A module
- T3 fail (profile invalid) → prompt user re-select
- T4 fail (depth_map inconsistent) → re-run Step 0B.5 build logic

---

## Completion Log

Ghi vao `legacy-scan-status.json`:

```json
{
  "stages": {
    "profile": {
      "status": "completed",
      "profile": "$PROFILE",
      "user_overrode_profile": "$USER_OVERRODE_PROFILE",
      "detected_domains_count": N
    }
  }
}
```

## Next Phase

- Neu `$MATURITY_LEVEL` IN (`CODE_PLUS_DEVKIT_PARTIAL`, `CODE_PLUS_DEVKIT_COMPLETE`, `NEAR_COMPLETE`):
  → **Phase 0.5** (`phase05-maturity.md`) — Maturity Validation
- Neu khong:
  → **Phase 1** (`phase1-inventory.md`) — Inventory (skip Phase 0.5)

---

## Examples

### Example 1: Default (no flag) — IPS recommends standard

```bash
/wf-legacy-scan fixtures/small-en/
```
→ IPS-A: detected sales (0.75), recommend = standard.
→ AskUserQuestion hien thi 4 options, user [Enter] xac nhan standard.
→ `depth_map = {L1: full, L2: full, L3: full, L4: standard, L5: standard, L6: full}`
→ `synthesis_mode = "full"`.

### Example 2: Explicit `--profile=deep`

```bash
/wf-legacy-scan fixtures/medium-vn/ --profile=deep
```
→ IPS-A chay nhung skip AskUserQuestion.
→ `depth_map.L4 = "deep"`, `depth_map.L5 = "deep"`, `L6 = "full+insights"`.

### Example 3: Explicit profile + per-layer override

```bash
/wf-legacy-scan fixtures/large-mixed/ --profile=standard --layers=L5 --depth=deep
```
→ Base = standard, then override L5 → deep.
→ `depth_map = {L1: full, L2: full, L3: full, L4: standard, L5: deep, L6: full}`.

### Example 4: Invalid profile

```bash
/wf-legacy-scan fixtures/small-en/ --profile=medium
```
→ ERROR E020: "Invalid profile 'medium'. Valid: surface, standard, deep, exhaustive."
→ STOP.
