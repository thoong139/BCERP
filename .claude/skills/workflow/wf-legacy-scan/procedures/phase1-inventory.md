# Phase 1: Inventory

> **Skill:** wf-legacy-scan
> **Stage:** 1 (sau Phase 0A Assessment hoac Phase 0.5 Maturity)
> **Mode:** DETERMINISTIC — bash scripts (no agents)
> **Load condition:** SKILL.md route vao file nay sau khi Phase 0A POST-GATE pass (va Phase 0.5 neu duoc kich hoat).

---

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §External Docs Scan Protocol
- `_shared.md` §Pipeline Data Persistence Rules
- `_shared.md` §Atomic Write Pattern
- `_shared.md` §Execution Trace (CORE-026)
- `_shared.md` §Phase Summary (CORE-028)
- `_shared.md` §Auto-Fix & Escalation Protocol (Protocol 1, 2)
- `_shared.md` §On Failure — Standard Format
- `_shared.md` §Task Planning (Protocol 9)

## Mo ta

Deterministic enumeration — liet ke moi loai artifact trong du an:
screens, API endpoints, docs, source files, dependency graph, external docs.
Tao tien de cho Stage 2 (Classify) va Stage 3 (Extract).

## PRE-GATE (Forensic — CORE-011, Protocol 10.4)

```
1. test -s .mc-data/work/legacy-scan/project-profile.json
2. jq -e '.tech_stack_verified' project-profile.json     # field exists (true hoac false + WARN)
3. jq -e '.doc_maturity.level' project-profile.json
4. jq -e '.file_counts.total >= 0' project-profile.json
5. test -s .mc-data/work/legacy-scan/ledger.json
6. jq -e '.strategy.id' ledger.json                       # strategy set (tu Phase 0A)
7. jq -e '.maturity.stage_modes' ledger.json              # stage_modes set
```

Nếu ANY fail → áp dụng `_shared.md §On Failure — Standard Format`.

## INPUT

- `project-profile.json` (tech stack, file counts)
- `$PROJECT_PATH`, `$MATURITY_LEVEL`

## OUTPUT

- `.mc-data/work/legacy-scan/inventory/screens.json`
- `.mc-data/work/legacy-scan/inventory/api-endpoints.json`
- `.mc-data/work/legacy-scan/inventory/doc-files.json`
- `.mc-data/work/legacy-scan/inventory/source-files.json`
- `.mc-data/work/legacy-scan/inventory/dependency-graph.json`
- `.mc-data/work/legacy-scan/inventory/external-docs.json` (new — FIX-06)
- `.mc-data/work/legacy-scan/inventory/ui-manifest.json` (conditional — chi khi `screens.count > 0`)
- `.mc-data/work/legacy-scan/inventory/doc-classified.json` (conditional — chi khi `$MATURITY_LEVEL == DOCS_ONLY`)
- `.mc-data/work/legacy-scan/ledger.json` (updated with `summary.total_items`)
- `.mc-data/work/legacy-scan/session-digest.md` (~300 tu)

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.0 | **[TRACE START]** Append START event vao `session-log.json` (phase=1) | Bash | Event appended |
| 1.1 | Chay `.claude/scripts/legacy-scan-inventory.sh "$PROJECT_PATH" .mc-data/work/legacy-scan/inventory .mc-data/work/legacy-scan/project-profile.json` (3 args: project-path, output-dir, profile-json) | Bash | Script exit 0 |
| 1.2-1.6 | Parse screens, APIs, docs, sources, dependencies (da handle trong script) | Bash | 5 inventory files exist |
| 1.6b | **External Docs Scan:** chay theo `_shared.md §External Docs Scan Protocol` → ghi `inventory/external-docs.json` | Read/Glob/Write | `inventory/external-docs.json` exists |
| 1.7 | **DOCS_ONLY branch:** Neu `$MATURITY_LEVEL == "DOCS_ONLY"` → **[READ-TEMPLATE]** READ `templates/inventory/doc-classified.json` → POPULATE (pre-classify docs theo type: spec/guide/api/readme/changelog) → WRITE `inventory/doc-classified.json`. Set `source-files.json = []` neu chua co. | Write | `doc-classified.json` exists (DOCS_ONLY only) |
| 1.8 | **[READ-TEMPLATE]** Re-read `ledger.json` hien co → MERGE `summary.total_items` + `stages.inventory.status=completed` (giu structure tu `templates/ledger.json` lam schema reference) → WRITE qua **Atomic Write Pattern** | Write | Ledger exists |
| 1.9 | Validate counts khop: `jq '.summary.total_items' ledger.json` == sum tu inventory files | Bash | Counts match |
| 1.9b | **Inventory Persistence Validation** (xem §Persistence Validation ben duoi) | Bash | All inventory files non-empty |
| 1.9c | **[IPS-B + WORKLOAD GATE]** Chay IPS Phase B refine + Workload Gate check (xem §Workload Gate — Detect + WARN). Neu triggered → AskUserQuestion CDG (3 options). Apply user choice (continue / downgrade / abort). | Bash + AskUserQuestion | Gate decision logged + `$PROFILE` / `$DEPTH_MAP` updated neu downgrade |
| 1.10 | **[READ-TEMPLATE]** READ `templates/session-digest.md` → POPULATE (project summary, inventory stats) → WRITE `session-digest.md` (~300 tu) | Write | Digest exists |
| 1.11 | Cap nhat `legacy-scan-status.json`: `stages.inventory.status = "completed"` (qua **Atomic Write Pattern**) | Edit | Updated |
| 1.12 | **[PHASE SUMMARY]** APPEND section "Phase 1: Inventory — PASS" vao `phase-summary.md` (note total_items + key counts) | Write | Section appended |
| 1.13 | **[TRACE COMPLETE]** Append COMPLETE event vao `session-log.json` (phase=1, metadata={total_items, screens, apis, docs, sources}) | Bash | Event appended |
| 1.14 | **[TODO UPDATE]** Mark Phase 1 = completed; mark Phase 2 = in_progress (hoac completed-skipped neu `$STAGE_MODES.classify == "skip"`) | TodoWrite | Updated |

---

## DOCS_ONLY Note

Khi `$MATURITY_LEVEL == DOCS_ONLY`:
- `source-files.json` se empty (valid — du an chua co code)
- `doc-classified.json` pre-classify documents de `/wf-legacy-classify` co the dung docs
  lam primary source voi confidence cap `0.7`
- Downstream skills se switch sang docs-first mode

---

## Persistence Validation (Step 1.9b)

```
For each inventory file in inventory/:
  IF file size == 0 OR jq '.' file.json | empty check:
    → RETRY inventory script x3 voi broader patterns
    → Neu van empty sau 3 lan: ERROR E004, STOP
```

**Gio intent:** Dam bao khong co inventory file nao empty sau scan. Empty inventory →
downstream stages khong co du lieu de process → pipeline fail silent.

---

## Workload Gate — Detect + WARN (Step 1.9c)

> **Scope v5.0:** Detect + WARN 3 options (continue-as-is / downgrade-profile / abort).
> Partition Planner (fix-workload.json) DEFER v5.1 (ADR-LS15 v2.1).
> Reference: `05-profiles-ips.md §4`, `09-thresholds-justification.md §2.5`.
> Implementation: `_shared/ips/workload_gate.py` (Phase F Task F.5).

### Step 1.9c.1 — Run IPS Phase B (refine)

```bash
# CHU Y: `ips` package goc tai `.claude/skills/workflow/_shared/` — phai cd vao day
# truoc khi invoke. CLI flags chinh xac: --ips-a (khong phai --ips-phase-a).
# `--profile` KHONG ton tai trong CLI `phase_b` — profile da persist trong scan-state/ips-phase-a.
REPO_ROOT="$(pwd)"
INVENTORY_ABS="$(cd "$REPO_ROOT" && realpath .mc-data/work/legacy-scan/inventory)"
IPS_A_ABS="$(realpath "$SESSION_DIR/ips-phase-a.json" 2>/dev/null || echo "$SESSION_DIR/ips-phase-a.json")"
IPS_B_OUT_ABS="$(realpath "$SESSION_DIR/ips-phase-b.json" 2>/dev/null || echo "$SESSION_DIR/ips-phase-b.json")"

if ! ( cd "$REPO_ROOT/.claude/skills/workflow/_shared" && \
       python -m ips.ips_recommender phase_b \
         --inventory "$INVENTORY_ABS" \
         --ips-a     "$IPS_A_ABS" \
         --output    "$IPS_B_OUT_ABS" ) 2>>"$SESSION_DIR/ips-errors.log"; then
  log_warn "IPS Phase B failed → fallback: skip workload gate (continue as-is)"
  jq -n '{workload_estimate:{exceeds_cap:false,ratio:0,total_features_est:0,est_time_min:0,budget_min:0,module_count:0}, warnings:[{code:"W0102", message:"IPS-B module invocation failed; gate skipped"}]}' \
    > "$IPS_B_OUT_ABS"
fi
```

Output `ips-phase-b.json` schema (one-line summary):
```json
{
  "workload_estimate": {
    "total_features_est": 145,
    "est_time_min": 150,
    "budget_min": 75,
    "ratio": 2.0,
    "exceeds_cap": true,
    "module_count": 5
  },
  "largest_module": {"name": "billing", "files": 45},
  "modules_count": 5,
  "total_files": 1500
}
```

Persist vao `scan-state.json:ips.phase_b`.

### Step 1.9c.2 — Check Gate

```bash
# Quoted heredoc delimiter 'PY' de disable bash expansion.
export SESSION_DIR
python - <<'PY'
import json, sys, os
sys.path.insert(0, ".claude/skills/workflow/_shared")
from ips.workload_gate import check_workload_gate, format_warn_message

with open(os.environ["SESSION_DIR"] + "/ips-phase-b.json") as f:
    data = json.load(f)
with open(os.environ["SESSION_DIR"] + "/scan-state.json") as f:
    state = json.load(f)

result = check_workload_gate(
    data["workload_estimate"],
    profile=state["session"]["profile"],
    modules_count=data.get("modules_count"),
    largest_module_files=(data.get("largest_module") or {}).get("files"),
    total_files=data.get("total_files"),
)

print("WORKLOAD_GATE_TRIGGERED=" + ("true" if result.triggered else "false"))
print("WORKLOAD_GATE_DOWNGRADE=" + (result.recommended_downgrade or ""))
if result.triggered:
    with open(os.environ["SESSION_DIR"] + "/workload-gate-warn.txt", "w", encoding="utf-8") as out:
        out.write(format_warn_message(result))
    # Persist structured result
    with open(os.environ["SESSION_DIR"] + "/workload-gate.json", "w", encoding="utf-8") as out:
        json.dump(result.to_dict(), out, indent=2, ensure_ascii=False)
PY
```

### Step 1.9c.3 — Gate Decision (CDG)

**Neu `WORKLOAD_GATE_TRIGGERED == false`:** SKIP (no user interaction) — tiep tuc
Step 1.10.

**Neu triggered:**

1. DISPLAY noi dung `$SESSION_DIR/workload-gate-warn.txt` cho user.
2. **AskUserQuestion** (CDG theo CORE-027):

```yaml
question: |
  ⚠️  Workload lon phat hien (xem chi tiet o tren)
  Ban muon lam gi?
options:
  - "[A] continue-as-is — Ghi WARN, giu profile, tiep tuc (dai hon ~2x budget)"
  - "[B] downgrade-profile — Giam profile de tiet kiem thoi gian (xem toc do giam)"
  - "[C] abort — STOP, user thu hep scope roi chay lai"
```

3. **Apply user choice:**
   - `[A] continue-as-is` → WARN log, `scan-state.ips.phase_b.gate_decision = "continue"`. Tiep tuc.
   - `[B] downgrade-profile` → goi `apply_user_choice("downgrade-profile", result)`, lay `new_profile`. Cap nhat:
     * `scan-state.session.profile = new_profile`
     * Re-build `depth_map` + `synthesis_mode` theo map canonical (Phase 0B `$PROFILE_DEPTH_MAP`).
     * `scan-state.ips.phase_b.gate_decision = "downgrade"`, `previous_profile`, `new_profile` logged.
     * **Re-run IPS Phase B** voi new profile context de refresh workload_estimate (tranh Phase 3 spawn theo estimate cu):
       ```bash
       # Overwrite ips-phase-b.json voi new profile — tranh Phase 3 dung workload cu
       ( cd "$REPO_ROOT/.claude/skills/workflow/_shared" && \
         python -m ips.ips_recommender phase_b \
           --inventory "$INVENTORY_ABS" --ips-a "$IPS_A_ABS" --output "$IPS_B_OUT_ABS" ) \
         2>>"$SESSION_DIR/ips-errors.log"
       jq '.ips.phase_b.rerun_after_downgrade = true' "$SESSION_DIR/scan-state.json" > "$SESSION_DIR/scan-state.json.tmp" \
         && mv "$SESSION_DIR/scan-state.json.tmp" "$SESSION_DIR/scan-state.json"
       ```
     * Tiep tuc.
   - `[C] abort` → WARN log, update `legacy-scan-status.json:pipeline_status = "aborted_by_workload_gate"`, append phase-summary, STOP (exit clean, khong loi).

### Step 1.9c.4 — Post-action logging

```bash
# Append to phase-summary.md
cat >> .mc-data/work/legacy-scan/phase-summary.md <<EOF

### Workload Gate
- Triggered: $WORKLOAD_GATE_TRIGGERED
- Decision: $GATE_DECISION
- Profile before: $PROFILE_BEFORE
- Profile after: $PROFILE_AFTER
- Triggers: (see $SESSION_DIR/workload-gate.json)
EOF
```

### Error Codes

| Code | Meaning |
|------|---------|
| W0101 | Gate triggered, user chose continue-as-is — WARN only |
| I0101 | Gate triggered, user chose downgrade — INFO |
| W0102 | Gate not applicable (IPS-B estimate missing) — skip, continue |
| E0101 | User chose abort — clean exit (NOT an error; pipeline_status=aborted_by_workload_gate) |

### Defer Notice — v5.1

> **KHONG** phat sinh `fix-workload.json` trong v5.0. Partition Planner +
> multi-session `--workload=` / `--chunk=` flags defer v5.1. Khi user chon
> downgrade, chi re-build depth_map tu profile moi — khong partition.

---

## POST-GATE (Tier T1→T4 — CORE-012, Protocol 10)

```
T1 — Existence (file ton tai + non-empty):
  1. test -s inventory/screens.json
  2. test -s inventory/api-endpoints.json
  3. test -s inventory/doc-files.json
  4. test -s inventory/source-files.json
  5. test -s inventory/dependency-graph.json
  6. test -s inventory/external-docs.json
  7. test -s session-digest.md
  8. test -s phase-summary.md
  9. find inventory/ -type f -size 0 | wc -l | awk '{exit ($1 != 0)}'   # zero empty files

T2 — Structure (required JSON fields):
  10. jq -e '.count // 0' inventory/screens.json
  11. jq -e '.count // 0' inventory/api-endpoints.json
  12. jq -e '.count // 0' inventory/source-files.json
  13. # dependency-graph.json khong co .count — schema co dependencies, import_groups, circular
      jq -e '.dependencies != null and .import_groups != null and .circular != null' inventory/dependency-graph.json
  14. jq -e '.total_docs // 0' inventory/external-docs.json
  15. jq -e '.summary.total_items' ledger.json

T3 — Content depth:
  16. jq -e '.summary.total_items > 0' ledger.json
  17. wc -w < session-digest.md | awk '{exit ($1 < 100)}'   # digest >=100 tu
  18. grep -q "Phase 1" .mc-data/work/legacy-scan/phase-summary.md
  19. # DOCS_ONLY branch: test -s inventory/doc-classified.json (chi khi $MATURITY_LEVEL == DOCS_ONLY)
  20. # ui-manifest conditional:
      if [ "$(jq '.count // 0' inventory/screens.json)" -gt 0 ]; then
        test -s inventory/ui-manifest.json
        jq -e '.total_screens >= 0' inventory/ui-manifest.json
        jq -e '.frameworks | length > 0' inventory/ui-manifest.json
      fi

T4 — Cross-reference:
  21. # total_items khop tong count tu inventory files
      TOTAL_LEDGER=$(jq -r '.summary.total_items' ledger.json)
      SCREENS_C=$(jq -r '.count // 0' inventory/screens.json)
      API_C=$(jq -r '.count // 0' inventory/api-endpoints.json)
      SRC_C=$(jq -r '.count // 0' inventory/source-files.json)
      DOC_C=$(jq -r '.count // 0' inventory/doc-files.json)
      [ "$TOTAL_LEDGER" -ge "$((SCREENS_C + API_C + SRC_C + DOC_C))" ]   # tolerance allowed
  22. jq -e '.stages.inventory.status == "completed"' legacy-scan-status.json
  23. # LEGACY_MODE anchor preview: ledger.summary.total_items > 0 → ready for Phase 2/3
```

Nếu ANY tier fail → áp dụng `_shared.md §Auto-Fix & Escalation Protocol` (max 1 retry per tier).
Sau retry vẫn fail → đi qua `_shared.md §On Failure — Standard Format`.

## On Failure

Theo `_shared.md §On Failure — Standard Format`. Cụ thể Phase 1:
- T1 fail (inventory file missing/empty) → re-run Step 1.1 (`legacy-scan-inventory.sh`) x1 với verbose logging
- T2/T3 fail (count fields wrong) → broaden patterns trong script + re-run x1
- T4 fail (counts mismatch) → re-run Step 1.8-1.9 sync ledger
- Sau 3 attempts vẫn fail → ERROR E004, STOP, AskUserQuestion

## Next Phase

→ **Phase 2** (`phase2-classify.md`) — Classify via Agent Delegation.
