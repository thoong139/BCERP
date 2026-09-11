# Resume & Status Handlers

> **Skill:** wf-legacy-scan
> **Load condition:** SKILL.md dispatch vao file nay khi arguments chua `--status` hoac `--resume`.
> **Khi nao khong load:** Fresh run (khong co flags) → bo qua, vao thang Phase 0.
> **Version:** v5.0 Phase H — 4-Level Resume Router reads scan-state.json canonical.

---

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §Context & Checkpoint
- `_shared.md` §LEGACY_MODE Detection
- Python helpers: `.claude/skills/workflow/_shared/ips/resume_router.py`, `scan_state_reader.py`
- Design: `docs/design/skills/wf-legacy-scan/03-architecture.md §2.2`, `04-data-model.md §1.1`

---

## Common Helpers

Ca --status va --resume deu doc scan-state.json canonical (v5.0). Neu scan-state.json
thieu, fallback v4.1 ledger.json de tuong thich nguoc (ADR-LS04 revised).

```bash
# Helper: run resume-router Python module, emit JSON cho bash switch.
run_resume_router() {
  local session_arg="${1:-}"
  local work_dir="${2:-.mc-data/work/legacy-scan}"
  local args=(-m ips.resume_router --work-dir "$work_dir")
  [ -n "$session_arg" ] && args+=(--session "$session_arg")

  # Run from shared root so `-m ips.resume_router` resolves.
  local shared_root=".claude/skills/workflow/_shared"
  (cd "$shared_root" && python "${args[@]}")
}

# Helper: display status từ scan-state.json (fallback legacy ledger.json nếu missing).
display_status_from_state() {
  local session_dir="$1"
  local state="$session_dir/scan-state.json"
  if [ -s "$state" ]; then
    jq '.' "$state"
    return 0
  fi
  # Fallback v4.1: doc ledger.json va render legacy format
  local legacy_ledger=".mc-data/work/legacy-scan/ledger.json"
  if [ -s "$legacy_ledger" ]; then
    log_warn "scan-state.json missing — fallback to legacy ledger.json"
    jq -r '"Legacy v4.1 session:\nStrategy: \(.strategy.id // "N/A") (\(.strategy.name // "N/A"))\nMaturity: \(.maturity.level // "N/A")\nStages: \(.stages | to_entries | map("\(.key)=\(.value.status // "unknown")") | join(", "))"' "$legacy_ledger"
    return 0
  fi
  return 1
}
```

---

## --status Handler

Hien thi TOAN BO pipeline status tu scan-state.json canonical. Fallback legacy
ledger.json neu session v5.0 chua duoc init. STOP sau khi hien thi.

### Input

- **Primary (v5.0):** `.mc-data/work/legacy-scan/sessions/<latest-in-progress>/scan-state.json`
  *(hoac `--session=ID` override)*
- **Fallback (v4.1):** `.mc-data/work/legacy-scan/ledger.json`
- `.mc-data/work/legacy-scan/legacy-scan-status.json` (pipeline-wide overview)
- `.mc-data/work/legacy-scan/sessions/<id>/error-ledger.json` (optional)

### Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| S.1 | Run `run_resume_router "$SESSION_ID_OVERRIDE"` → parse JSON into `$ACTION` | Bash | Valid JSON |
| S.2 | Neu `action_type == "no_resumable_session"` va khong co legacy ledger → hien thi "Pipeline chua bat dau. Chay `/wf-legacy-scan [project-path]`." → STOP | — | Message shown |
| S.3 | Neu action co `session_dir`: `display_status_from_state "$session_dir"` de lay canonical state | Bash | Data loaded |
| S.4 | Doc `error-ledger.json` (neu ton tai) de bo sung errors/warnings | Read | Errors loaded |
| S.5 | Hien thi theo §Display Format (v5.0) ben duoi | — | User informed |
| S.6 | STOP — KHONG tiep tuc Phase 0 | — | — |

### Display Format (v5.0 canonical)

```
Trang thai Scan — wf-legacy-scan

| Thong tin | Gia tri |
|-----------|---------|
| Session ID | 2026-04-22T10-00-00 |
| Project path | /path/to/project |
| Profile | standard |
| Strategy | S2 |
| Maturity level | NEAR_COMPLETE |
| Pipeline status | in_progress / completed / failed |
| Last completed | L3 (inventory) |

6-Layer Progress:
| Layer | Name | Depth | Status | Progress |
|-------|------|-------|--------|----------|
| L1 | Discovery | full | completed | — |
| L2 | Assessment | full | completed | — |
| L3 | Inventory | full | completed | — |
| L4 | Classification | standard | in_progress | batch 3/5 (file 12/30) |
| L5 | Extraction | standard | not_started | — |
| L6 | Synthesis | full | not_started | — |

IPS Recommendations:
| Phase | Status | Details |
|-------|--------|---------|
| Phase A | available | domain: finance (0.85), logistics (0.72) |
| Phase B | available | expert: finance-expert for billing, auth |

Resume Hint:
  /wf-legacy-scan --resume
  → Continues from: L4 batch 3 file src/billing/invoice.ts
  → Action type: resume_L4_intra_batch

Errors/Warnings: (tu error-ledger.json neu co)
```

### Legacy fallback format (khi chi co ledger.json)

```
Pipeline Status — wf-legacy-scan (LEGACY v4.1 session)

Session migrated from legacy ledger.json. Canonical stages:
| Stage | Skill | Status | Chi tiet |
|-------|-------|--------|----------|
| 0 Detection | wf-legacy-scan | completed | tech_stack_verified |
| 0A Assessment | wf-legacy-scan | completed | Strategy: S2 |
| 0.5 Maturity Val | wf-legacy-scan | completed/skipped/pending | [reason] |
| 1 Inventory | wf-legacy-scan | [status] | [N] items |
| 2 Classify | wf-legacy-scan (Agent) | [status] | [details] |
| 3 Extract | wf-legacy-scan (Agent) | [status] | [details] |
| 4 Synthesize | wf-legacy-scan | [status] | → project-context.md |

Hint: Chay `/wf-legacy-scan` hoac `/wf-legacy-classify --resume` de tiep tuc
      voi scan-state.json canonical (v5.0 migration se tu dong).
```

### Edge Cases

- Khong co session VA khong co ledger.json → "Pipeline chua bat dau"
- `--session=ID` khong ton tai → "Session 'ID' not found. Kiem tra lai ID." → STOP exit 2
- scan-state.json corrupted → WARNING, hien thi ledger.json fallback + de nghi manual fix
- Layer status `skipped_by_profile` → hien thi "skipped (profile=surface)"

---

## --resume Handler

Resume tu checkpoint cuoi cung voi 4-Level Resume Router — jump den resumption
point finest-granularity (phase / layer / batch-module / intra-batch/module).

### PRE-GATE

```bash
# Kiem tra co session nao khong (v5.0 hoac legacy).
test -d .mc-data/work/legacy-scan/sessions || \
  test -f .mc-data/work/legacy-scan/ledger.json
```

Neu FAIL → "Pipeline chua bat dau. Khong the resume. Chay `/wf-legacy-scan [project-path]`." → STOP.

### Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| R.0 | Acquire lock: `flock_acquire "$WORK_DIR/.session.lock" 0` (stale auto-cleared) + **register trap:** `trap 'flock_release "$WORK_DIR/.session.lock"' EXIT INT TERM` | Bash | Lock held + trap armed |
| R.1 | Run `run_resume_router "$SESSION_ID_OVERRIDE"` → parse JSON into `$ACTION` | Bash | Valid JSON |
| R.2 | Neu `action_type == "no_resumable_session"` → hien thi hint → STOP (trap release lock) | — | Message shown |
| R.3 | Neu action co `session_id` va `$SESSION_ID_OVERRIDE` ton tai → validate equality | Bash | IDs match |
| R.4 | Export state tu scan-state.json + ledger.json (xem §Resume State Contract): `SESSION_ID`, `SESSION_DIR`, `PROFILE`, `DEPTH_MAP_JSON`, `SYNTHESIS_MODE`, `STRATEGY`, `MATURITY_LEVEL`, `STAGE_MODES`, `ACTION_TYPE`, `NEXT_LAYER`, `RESUME_UNIT_JSON` | Bash | Env set |
| R.5 | **Staleness check:** neu last scan > 7d → `.claude/scripts/legacy-scan-staleness.sh "$PROJECT_PATH" .mc-data/work/legacy-scan/ledger.json` (2 args) | Bash | Staleness report |
| R.6 | Neu stale > 30%: WARN E013, AskUserQuestion (continue / partial re-scan / full re-scan) | AskUserQuestion | User choice |
| R.7 | **4-Level Routing:** xem §Resume Routing Switch ben duoi — dispatch theo `action_type` | Read | Routing decision |
| R.8 | Hien thi progress message "Resuming from: [action_type]. [notes]" → tiep tuc phase | — | User informed |

### Resume Routing Switch

Dispatch theo `action_type` tu Resume Router JSON:

```bash
case "$ACTION_TYPE" in
  start_L1)
    # L1 chua bat dau — route vao phase1-inventory.md (L1 Discovery).
    # Phase 0-0A-0B-0.5 da xong (scan-state.last_completed=init nghia la Phase 0-0B done,
    # L1 chinh la Phase 1 Inventory Discovery sub-layer).
    # Xu ly: jump vao phase1-inventory.md, bat dau L1.
    message="L1 Discovery se start — chua co layer nao complete."
    target_file="phase1-inventory.md"
    ;;

  start_L2_rerun_ips_a)
    # L1 xong, L2 chua. Re-run IPS Phase A (Phase 0B orchestrator) — KHONG re-run Phase 0A
    # vi Phase 0A AskUserQuestion strategy da duoc confirm roi.
    message="L1 da xong. Re-run IPS Phase A (Phase 0B)."
    target_file="phase0b-profile.md"  # Re-run IPS-A, khong re-confirm strategy
    ;;

  start_L3)
    # L2 xong, L3 chua. Route vao inventory.
    message="L2 Assessment da xong. Start L3 Inventory."
    target_file="phase1-inventory.md"
    ;;

  start_L4_rerun_ips_b_if_missing)
    # L3 xong, L4 chua. Neu IPS Phase B thieu → re-run truoc.
    message="L3 Inventory da xong. Start L4 Classification."
    target_file="phase2-classify.md"
    ;;

  resume_L4_batch|resume_L4_intra_batch)
    # L4 dang do dang. phase2-classify.md se doc partial.json + batch_progress.
    message="Resuming L4 Classification tu batch $(jq -r .current_batch <<<"$RESUME_UNIT_JSON")"
    target_file="phase2-classify.md"
    ;;

  start_L5)
    # L4 xong, L5 chua.
    message="L4 Classification da xong. Start L5 Extraction."
    target_file="phase3-extract.md"
    ;;

  resume_L5_module|resume_L5_intra_module)
    # L5 dang do dang.
    message="Resuming L5 Extraction tu module $(jq -r .current_module <<<"$RESUME_UNIT_JSON")"
    target_file="phase3-extract.md"
    ;;

  start_L6|resume_L6_regenerate)
    # L5 xong, L6 synthesize. Idempotent — regenerate project-context.md.
    message="Starting/Resuming L6 Synthesis (regenerate project-context.md)."
    target_file="phase4-synthesize.md"
    ;;

  session_already_completed)
    echo "Pipeline da hoan tat. Dung --re-vision de re-scan voi vision moi."
    exit 0
    ;;

  session_aborted_by_workload_gate)
    echo "Session truoc da bi abort tai Workload Gate (user chon C)."
    echo "Scope du an qua lon cho budget profile hien tai."
    echo ""
    echo "Options:"
    echo "  1. Thu nho scope (exclude huge modules) roi chay moi: /wf-legacy-scan [path]"
    echo "  2. Dung profile nhe hon: /wf-legacy-scan [path] --profile=surface"
    echo "  3. Tang budget: LEGACY_SCAN_BUDGET_MIN=600 /wf-legacy-scan [path]"
    exit 0
    ;;

  delegate_legacy_subskill)
    echo "Session migrated tu v4.1 ledger.json. Sub-skill dang chay."
    echo "  /wf-legacy-classify --resume  # neu classify dang in_progress"
    echo "  /wf-legacy-extract --resume   # neu extract dang in_progress"
    exit 0
    ;;

  fallback_legacy_ledger)
    # scan-state.json missing nhung legacy ledger.json ton tai.
    # Delegate cho init_or_load_session migration — route vao phase0-detection.md
    # voi flag de force migrate + continue.
    #
    # ATOMIC MIGRATION (v5.0 fix + A2-H1 seed state):
    # 1. Backup legacy ledger truoc khi bat dau (non-destructive):
    if [ -f "$WORK_DIR/ledger.json" ]; then
      BACKUP="$WORK_DIR/ledger.json.bak.$(date -u +%Y%m%dT%H%M%SZ)"
      cp "$WORK_DIR/ledger.json" "$BACKUP"
      log_info "Backup legacy ledger: $BACKUP"
    fi
    # 2. A2-H1 fix: extract seed state TU ledger.json TRUOC KHI dispatch sang phase0-detection.
    # Neu khong seed, phase0 se init scan-state.json voi STRATEGY=unknown + all layers=not_started
    # → L1-L3 bi re-run dù ledger.json cho thay da hoan thanh.
    if [ -f "$WORK_DIR/ledger.json" ]; then
      LEGACY_SEEDED_STRATEGY=$(jq -r '.strategy // "unknown"' "$WORK_DIR/ledger.json")
      LEGACY_SEEDED_MATURITY=$(jq -r '.maturity_level // "unknown"' "$WORK_DIR/ledger.json")
      # Map stages.* (v4.1) → layers.* (v5.0): detection/assessment/inventory/classify/extract/synthesize
      # → L0/L0A/L1/L2/L3/L4 status. Export as JSON cho phase0-detection consume.
      LEGACY_SEEDED_LAYERS=$(jq -c '{
        L0: (.stages.detection.status // "not_started"),
        L0A: (.stages.assessment.status // "not_started"),
        L0B: (.stages.maturity.status // "not_started"),
        L1: (.stages.inventory.status // "not_started"),
        L2: (.stages.classify.status // "not_started"),
        L3: (.stages.extract.status // "not_started"),
        L4: (.stages.synthesize.status // "not_started"),
        L5: "not_started",
        L6: "not_started"
      }' "$WORK_DIR/ledger.json")
      export LEGACY_SEEDED_STRATEGY LEGACY_SEEDED_MATURITY LEGACY_SEEDED_LAYERS
      log_info "Seed from ledger.json: strategy=$LEGACY_SEEDED_STRATEGY maturity=$LEGACY_SEEDED_MATURITY"
    fi
    # 3. Export env flag cho phase0-detection xu ly LEGACY_MIGRATE mode:
    #    Phase0-detection §Session Init CHECK LEGACY_SEEDED_* env vars → nếu set,
    #    khoi tao scan-state.json voi seed values thay vi defaults (avoid re-run L1-L3).
    message="Legacy v4.1 session detected. Migrating to scan-state.json (backup taken, state seeded from ledger)..."
    export LEGACY_MIGRATE=true
    target_file="phase0-detection.md"
    ;;

  session_invalid)
    # A6-H3 fix: actionable recovery options instead of vague message
    SID=$(jq -r '.session_id // ""' <<<"$ACTION")
    echo "ERROR: Session khong resume duoc."
    jq -r '.notes[]' <<<"$ACTION"
    echo ""
    echo "Recovery options (chon 1):"
    echo "  [a] Safe reset (giu project-profile.json + ledger.json, chi xoa scan-state corrupt):"
    echo "      rm -f .mc-data/work/legacy-scan/sessions/$SID/scan-state.json"
    echo "      /wf-legacy-scan --resume"
    echo ""
    echo "  [b] Full session restart (xoa toan bo session dir, giu legacy outputs):"
    echo "      rm -rf .mc-data/work/legacy-scan/sessions/$SID/"
    echo "      /wf-legacy-scan [project-path]"
    echo ""
    echo "  [c] Full pipeline reset (xoa TAT CA, start from scratch — mat toan bo progress):"
    echo "      rm -rf .mc-data/work/legacy-scan/"
    echo "      /wf-legacy-scan [project-path]"
    echo ""
    echo "  [d] Fallback to legacy ledger (neu ledger.json non-empty):"
    echo "      (auto: resume router se detect va dispatch fallback_legacy_ledger)"
    echo ""
    echo "Xem chi tiet state: /wf-legacy-scan --status"
    exit 1
    ;;

  no_resumable_session)
    echo "Khong tim thay active session nao de resume."
    jq -r '.notes[] // empty' <<<"$ACTION"
    echo ""
    echo "Goi y:"
    echo "  - Neu muon bat dau scan moi: /wf-legacy-scan [project-path] (bo --resume)"
    echo "  - Neu pipeline da aborted: xem error-ledger.json de biet ly do"
    exit 0
    ;;

  *)
    echo "ERROR: Unknown action_type '$ACTION_TYPE'."
    exit 1
    ;;
esac

echo "Resuming: $message"
echo "Routing to: procedures/$target_file"
# SKILL.md se tu Read target_file va tiep tuc.
```

### Resume State Contract (exported env vars)

Sau khi `--resume` dispatch thanh cong, cac env vars sau duoc export cho phase files.
**QUAN TRONG (v5.0 fix):** `$STAGE_MODES`, `$MATURITY_LEVEL`, `$SYNTHESIS_MODE` cung phai
duoc export — neu thieu, Phase 2/3 khong biet skip condition + Phase 4 khong biet synthesis mode.

| Variable | Value | Source |
|----------|-------|--------|
| `$SESSION_ID` | Session ID (eg `2026-04-22T10-00-00`) | `$ACTION.session_id` |
| `$SESSION_DIR` | Absolute path den session dir | `$ACTION.session_dir` |
| `$PROFILE` | Profile name (surface/standard/deep/exhaustive) | `$ACTION.profile` (hoac `jq '.session.profile' scan-state.json`) |
| `$STRATEGY` | Strategy ID (S1-S7) | `$ACTION.strategy` (hoac `jq '.strategy.id' ledger.json`) |
| `$DEPTH_MAP_JSON` | JSON string cua depth_map | `$ACTION.depth_map` |
| `$SYNTHESIS_MODE` | Synthesis mode (condensed/full/...) | `jq -r '.synthesis_mode' "$SESSION_DIR/scan-state.json"` |
| `$MATURITY_LEVEL` | Maturity level | `jq -r '.maturity.level // .maturity_level' ledger.json` |
| `$STAGE_MODES` | JSON of stage_modes map | `jq -c '.maturity.stage_modes' ledger.json` |
| `$ACTION_TYPE` | Routing action enum | `$ACTION.action_type` |
| `$NEXT_LAYER` | Layer can resume/start (L1..L6 hoac null) | `$ACTION.next_layer` |
| `$RESUME_UNIT_JSON` | JSON cua resume_unit (batch/module/partial) | `$ACTION.resume_unit` |
| `$IPS_PHASE_A_AVAILABLE` | "true"/"false" | `$ACTION.ips_phase_a_available` |
| `$IPS_PHASE_B_AVAILABLE` | "true"/"false" | `$ACTION.ips_phase_b_available` |

**Load pattern cho Step R.4** (sau khi resume_router chay xong):
```bash
export SESSION_ID="$(jq -r '.session_id' <<<"$ACTION")"
export SESSION_DIR="$(jq -r '.session_dir' <<<"$ACTION")"
export PROFILE="$(jq -r '.profile // "standard"' <<<"$ACTION")"
export STRATEGY="$(jq -r '.strategy // "unknown"' <<<"$ACTION")"
export DEPTH_MAP_JSON="$(jq -c '.depth_map' <<<"$ACTION")"
export ACTION_TYPE="$(jq -r '.action_type' <<<"$ACTION")"
export NEXT_LAYER="$(jq -r '.next_layer // empty' <<<"$ACTION")"
export RESUME_UNIT_JSON="$(jq -c '.resume_unit // {}' <<<"$ACTION")"
export IPS_PHASE_A_AVAILABLE="$(jq -r '.ips_phase_a_available // false' <<<"$ACTION")"
export IPS_PHASE_B_AVAILABLE="$(jq -r '.ips_phase_b_available // false' <<<"$ACTION")"

# v5.0 fix — bat buoc load tu files goc de phase 2/3/4 hoat dong dung:
export SYNTHESIS_MODE="$(jq -r '.synthesis_mode // "full"' "$SESSION_DIR/scan-state.json" 2>/dev/null || echo full)"
export MATURITY_LEVEL="$(jq -r '.maturity.level // .maturity_level // "unknown"' .mc-data/work/legacy-scan/ledger.json 2>/dev/null || echo unknown)"
export STAGE_MODES="$(jq -c '.maturity.stage_modes // {}' .mc-data/work/legacy-scan/ledger.json 2>/dev/null || echo '{}')"
```

Target phase file se doc cac env vars nay + load scan-state.json truc tiep neu can
chi tiet hon.

### Edge Cases

- `--session=ID` resolve được → resume đúng session đó (không auto-discover).
- `--session=ID` không tồn tại → Router trả `action_type="no_resumable_session"`, exit code 2.
- Nhiều session in_progress → Router auto-picks latest by mtime (an toàn vì lock ngăn concurrent scan).
- Lock bị giữ bởi scan khác đang chạy → flock_acquire fail, hiển thị lock owner + options.
- scan-state.json corrupted nhưng ledger.json hợp lệ → fallback `delegate_legacy_subskill` hoặc `fallback_legacy_ledger`.

---

## CLI Usage Examples

```bash
# Xem status session moi nhat.
/wf-legacy-scan --status

# Xem status session cu the.
/wf-legacy-scan --status --session=2026-04-22T10-00-00

# Resume session moi nhat (auto-discover).
/wf-legacy-scan --resume

# Resume session cu the.
/wf-legacy-scan --resume --session=2026-04-22T10-00-00

# Resume va re-run stale layer.
/wf-legacy-scan --resume --re-vision
```

---

## Exit Codes

| Code | Nghia |
|------|-------|
| 0 | Status hien thi xong, hoac resume bat dau thanh cong, hoac session da complete |
| 1 | scan-state.json invalid va khong co legacy ledger — can manual fix |
| 2 | `--session=ID` duoc cung cap nhung session khong ton tai |
