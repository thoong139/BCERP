# Phase 4: Synthesize

> **Skill:** wf-legacy-scan
> **Stage:** 4 (sau Phase 3 Extract — phase cuoi cua pipeline)
> **Mode:** Main context — KHONG delegate sang Agent
> **Load condition:** SKILL.md route vao file nay sau khi Phase 3 POST-GATE pass.

---

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §LEGACY_MODE Detection
- `_shared.md` §Atomic Write Pattern
- `_shared.md` §Execution Trace (CORE-026)
- `_shared.md` §Phase Summary (CORE-028)
- `_shared.md` §Auto-Fix & Escalation Protocol (Protocol 1, 2)
- `_shared.md` §On Failure — Standard Format
- `_shared.md` §Task Planning (Protocol 9)

## Mo ta

Phase cuoi cua pipeline — tong hop tat ca artifacts tu Phase 1-3 va tao 3 output files:
`project-context.md`, `doc-quality-map.json`, `impl-status-snapshot.json`.
`project-context.md` la **anchor file** cho LEGACY_MODE detection (CORE-021) —
tat ca shared skills downstream se check file nay de quyet dinh inject legacy context.

Phase nay chay TRUC TIEP trong main context (khong spawn Agent) vi:
1. Can integrate knowledge tu nhieu nguon
2. Output size da duoc truncate (Size Guideline) → fit main context
3. Khong co heavy I/O — chu yeu la data synthesis + formatting

## PRE-GATE (Forensic — CORE-011, Protocol 10.4)

```
1. test -s .mc-data/work/legacy-scan/ledger.json
2. # Extract completed HOAC skip theo stage_modes HOAC skip theo depth (surface profile L5=skip)
   DEPTH_L5=$(jq -r '.depth_map.L5 // "standard"' "$SESSION_DIR/scan-state.json" 2>/dev/null || echo standard)
   jq -e '.stages.extract.status == "completed" or .maturity.stage_modes.extract == "skip" or .stages.extract.status == "skipped_by_profile"' ledger.json \
     || [ "$DEPTH_L5" = "skip" ]
3. test -s .mc-data/work/legacy-scan/project-profile.json
4. jq -e '.doc_maturity.level' project-profile.json
5. test -s .mc-data/work/legacy-scan/inventory/source-files.json
6. test -s .mc-data/work/legacy-scan/inventory/external-docs.json
7. Neu extract khong skip (status=completed):
   - test -d extracted/ && [ "$(ls extracted/*.json 2>/dev/null | wc -l)" -gt 0 ]
   - test -s module-code-mapping.json
   - jq '.' module-code-mapping.json > /dev/null
```

Nếu ANY fail → áp dụng `_shared.md §On Failure — Standard Format`.

## INPUT (Step 4.1 — Artifacts can doc)

- `project-profile.json` (tech stack, verification details)
- `inventory/source-files.json`, `inventory/screens.json`, `inventory/api-endpoints.json`
- `inventory/external-docs.json` (doc files by category)
- `classified/batch-*.json` + `classified/glossary.json` (neu classify chay)
- `extracted/{module}.json` (requirements, features, confidence — neu extract chay)
- `module-code-mapping.json` (neu extract chay)

## OUTPUT

- `.mc-data/work/legacy-scan/project-context.md` (key artifact — LEGACY_MODE anchor, CORE-021)
- `.mc-data/work/legacy-scan/doc-quality-map.json`
- `.mc-data/work/legacy-scan/impl-status-snapshot.json` (READ-ONLY sau khi tao — xem §impl-status Lifecycle)
- `.mc-data/work/legacy-scan/impact-graph.json` (NEW — Phase F; **skip neu** `synthesis_mode == "condensed"`; ADR-LS14; schema `impact-graph-v1`)
- `.mc-data/work/legacy-scan/ledger.json` (updated — `pipeline_status = "COMPLETE"`)

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 4.0 | **[TRACE START]** Append START event vao `session-log.json` (phase=4) | Bash | Event appended |
| 4.1 | Doc tat ca artifacts tu Phase 1-3 (xem Input list ben tren) | Read | Data loaded |
| 4.2 | Danh gia doc quality (xem §Doc Quality Assessment). Template reference: `templates/doc-quality-map.json` | Read/Bash | Quality assessed |
| 4.3 | Tao impl-status snapshot data tu extracted data (xem §impl-status Snapshot Logic). Template reference: `templates/impl-status-snapshot.json` | Read | Snapshot data ready |
| 4.4 | **[READ-TEMPLATE]** READ `templates/project-context.md` → POPULATE theo §project-context.md Format (8 sections) → WRITE `.mc-data/work/legacy-scan/project-context.md` | Write | File exists + > 500 bytes |
| 4.5 | **[READ-TEMPLATE]** READ `templates/doc-quality-map.json` → POPULATE tu Step 4.2 → WRITE `.mc-data/work/legacy-scan/doc-quality-map.json` | Read/Write | Valid JSON |
| 4.6 | **[READ-TEMPLATE]** Neu `$SYNTHESIS_MODE != "condensed"`: READ `templates/impl-status-snapshot.json` → POPULATE tu Step 4.3 → WRITE `.mc-data/work/legacy-scan/impl-status-snapshot.json`. Neu condensed → export `IMPL_SNAPSHOT_SKIPPED=true` va SKIP. | Read/Write | Valid JSON hoac skipped |
| 4.6.5 | **[IMPACT-GRAPH]** Neu `$SYNTHESIS_MODE != "condensed"` → resolve `$SYNTHESIS_MODE` (xem §Synthesis Mode Mapping) → build impact-graph (xem §Impact Graph Build) → WRITE `.mc-data/work/legacy-scan/impact-graph.json`. Neu condensed → export `IMPACT_GRAPH_SKIPPED=true` va ghi line vao phase-summary. | Bash/Write | `jq -e '."$schema" == "impact-graph-v1"' impact-graph.json` hoac skipped |
| 4.7 | Update `ledger.json`: `pipeline_status = "COMPLETE"`, `stages.synthesize.status = "completed"` qua **Atomic Write Pattern** | Edit | Ledger updated |
| 4.8 | Update `legacy-scan-status.json`: pipeline_status = COMPLETE (qua **Atomic Write Pattern**) | Edit | Status updated |
| 4.9 | **[PHASE SUMMARY]** APPEND section "Phase 4: Synthesize — PASS" vao `phase-summary.md` (note total modules, features, doc trust levels) | Write | Section appended |
| 4.10 | **[TRACE COMPLETE]** Append COMPLETE event vao `session-log.json` (phase=4, metadata={modules, features, doc_high_trust, project_context_bytes}) | Bash | Event appended |
| 4.11 | **[TODO UPDATE]** Mark Phase 4 = completed (toan bo pipeline DONE) | TodoWrite | Updated |
| 4.12 | Hien thi Completion Message (xem §Completion Message ben duoi) | — | User informed |

---

## Doc Quality Assessment (Step 4.2)

Per document (list tu `inventory/external-docs.json` + `inventory/doc-files.json`):

```
1. freshness: so sanh modified date vs last code commit date
   - > 6 thang truoc last commit → staleness_risk = HIGH
   - 1-6 thang → MEDIUM
   - < 1 thang → LOW

2. code_doc_alignment: % entities trong doc co trong code
   - >= 0.8 → trust_level = HIGH
   - 0.5-0.8 → MEDIUM
   - < 0.5 → LOW

3. doc_type: architecture-decision | requirements | roadmap | notes | api-spec | guide

4. recommended_action:
   - HIGH trust + LOW staleness → USE_AS_IS
   - MEDIUM → VERIFY_AGAINST_CODE
   - LOW → REFERENCE_ONLY
   - notes/meeting → DISCARD
```

Output tong hop vao `doc-quality-map.json`:
```json
{
  "total_docs": N,
  "by_trust_level": { "HIGH": N, "MEDIUM": N, "LOW": N },
  "by_recommended_action": { "USE_AS_IS": N, "VERIFY_AGAINST_CODE": N, "REFERENCE_ONLY": N, "DISCARD": N },
  "documents": [
    { "path": "...", "type": "...", "trust_level": "...", "staleness_risk": "...",
      "code_doc_alignment": 0.NN, "recommended_action": "..." }
  ]
}
```

---

## Synthesis Mode Mapping (Step 4.6.5)

Resolve `$SYNTHESIS_MODE` tu scan-state / ledger theo mapping canonical
(02-scan-layers.md §3 + §4.6.1):

| Profile / Depth nguon | synthesis_mode | Impact graph hanh vi |
|-----------------------|----------------|----------------------|
| `surface` (Phase 0b profile) | `condensed` | **SKIP** impact-graph (khong output file) |
| `standard` (default) | `full` | Basic — giu `code_import` + `data_dependency` |
| `deep` | `full+insights` | Enriched — giu ca `entity_reference`, `req_cross_ref`, `event_subscription`, `api_call` |
| `exhaustive` | `full+divergence` | Enriched + divergence refs (thong tin "code vs docs mismatch") |

Resolve bang shell helper:

```bash
# CHU Y: profile duoc luu tai `.session.profile` trong scan-state.json (nested),
# KHONG phai root-level `.profile`. Phase 0B Step 0B.8 persist vao path nay.
PROFILE=$(jq -r '.session.profile // "standard"' "$SESSION_DIR/scan-state.json" 2>/dev/null || echo standard)
case "$PROFILE" in
  surface)    SYNTHESIS_MODE="condensed" ;;
  standard)   SYNTHESIS_MODE="full" ;;
  deep)       SYNTHESIS_MODE="full+insights" ;;
  exhaustive) SYNTHESIS_MODE="full+divergence" ;;
  *)          SYNTHESIS_MODE="full" ;;
esac
export SYNTHESIS_MODE
```

Khi `$SYNTHESIS_MODE == "condensed"`:
- SKIP Step 4.6.5 impact-graph build.
- APPEND dong vao `phase-summary.md`: "Impact graph: skipped (synthesis_mode=condensed)".
- POST-GATE T2b cho impact-graph.json SKIP (xem POST-GATE rules).

---

## Impact Graph Build (Step 4.6.5)

Module `_shared/ips/impact_graph_builder` (Phase F Task F.1) doc inventory +
classified + extracted tu session dir va tong hop `impact-graph.json` theo
schema `impact-graph-v1` (04-data-model.md §2.2).

**Invocation pattern (Python inline):**

```bash
# Quoted heredoc delimiter 'PY' de disable bash expansion — moi variables goi qua os.environ.
export SESSION_DIR SYNTHESIS_MODE
python - <<'PY'
import os
import sys
from pathlib import Path

sys.path.insert(0, ".claude/skills/workflow/_shared")
from ips import impact_graph_builder as igb

session_dir = Path(os.environ["SESSION_DIR"])
synthesis_mode = os.environ.get("SYNTHESIS_MODE", "full")
payload = igb.build_from_session_dir(
    session_dir,
    synthesis_mode=synthesis_mode,
)
igb.write_impact_graph(payload, ".mc-data/work/legacy-scan/impact-graph.json")
PY
```

**6 relation types (04-data-model.md §2.2):**
- `code_import` — import/export giua modules (`inventory/dependency-graph.json`).
- `data_dependency` — FK / schema reference (`inventory/schema.json` optional).
- `event_subscription` — event bus / decorator (heuristic tu source snippets).
- `api_call` — REST/gRPC call (runtime trace neu co; defer v5.1 cho cross-module).
- `req_cross_ref` — REQ-/FEAT- ID references (quet description trong extracted).
- `entity_reference` — entity name reference khong strict FK (classified entities).

**Mode gating (do module tu lam):**
- `condensed` → skip edges (nhung nodes van co cho audit).
- `full` → giu `code_import` + `data_dependency`.
- `full+insights` / `full+divergence` → giu tat ca relations co bang chung.

**Exit condition:**
- Build FAIL (Python exception, missing artifacts) → WARN, tiep tuc phase
  (W-L6-02 non-blocking, 02-scan-layers.md §8). File khong duoc viet → POST-GATE
  T2b cho impact-graph fail → auto-fix re-run toi da 3 lan → neu van fail →
  ghi warning vao phase-summary, continue.
- Build OK → tiep Step 4.7.

---

## impl-status Snapshot Logic (Step 4.3)

Per feature (tu extracted data):

```
status = DONE | PARTIAL | NOT_STARTED

- DONE: confidence >= 0.8 AND test files found AND tests referenced
- PARTIAL: code files found nhung confidence < 0.8 hoac gaps detected
- NOT_STARTED: khong tim thay code files lien quan
```

### Lifecycle (P8 — "Snapshot seeds, Registry owns")

```
- Tao 1 LAN DUY NHAT boi Phase 4
- READ-ONLY — KHONG BAO GIO update sau khi tao
- Dung de SEED initial impl_status vao registry trong /wf-define-features (Phase 0.5)
- Sau khi seed → registry takes over, snapshot khong con lien quan
- Khong su dung snapshot nay lam source of truth o bat ky downstream skill nao khac
```

---

## project-context.md Format

> Output template: `templates/project-context.md`. Populate theo 8 sections ben duoi.

```markdown
# Project Context — [Ten du an]
Generated: [date] | Scan Confidence: [score] | Strategy: [S1-S7]

---
## 0. Tong quan Du an

**Linh vuc:** [e.g. Logistics, E-commerce, Healthcare...]
**Mo ta:** [1-2 cau: cong ty/san pham lam gi, phuc vu ai]
**Quy mo:** [So apps] apps | [so modules] modules | [so files] files source

---
## 1. He Thong & Ung Dung (Multi-App Overview)

> Chi them section nay khi phat hien >= 2 apps rieng biet (apps/, packages/, vv.)
> Neu single-app → bo section nay, giu Module Map o Section 2.

| He thong (App) | Duong dan | Muc dich | Doi tuong su dung | Trang thai |
|----------------|-----------|----------|-------------------|------------|
| [app-name]     | apps/xxx/ | [lam gi] | [ai dung]         | [% done]   |

---
## 2. Tech Stack (Verified tu code — CORE-014)
| Layer | Tech | Nguon xac minh |
|-------|------|----------------|

---
## 3. Module Map
| Module (canonical) | He thong | Backend Project | Files | Hoan thien uoc tinh | Chat luong code |
|-------------------|----------|-----------------|-------|---------------------|-----------------|

---
## 4. Tai lieu Hien co (Doc Quality Assessment)
| File | Loai | Do tin cay | Khuyen nghi |
|------|------|-----------|-------------|

---
## 5. Features Extracted (per module, top 5 per confidence)
> Full data: extracted/{module}.json

**[Module: module-name]**
- Feature description (conf: X.XX) — code_ref

---
## 6. Implementation Status (Feature-Level)
PARTIAL ([N] modules — can attention nhat):
| Module | Features | Done est. | Partial est. | Not Started |
|--------|----------|-----------|--------------|-------------|

NOT_STARTED: [list]

---
## 7. Nhung Diem Can Chu y
1. [Critical items, gaps, risks — uu tien CRITICAL truoc]

---
## 8. Maturity & Strategy
Maturity Level: [level]
Strategy: [S1-S7]
Recommended approach: [description]

Next step: /wf-brainstorm (legacy flow)
```

### Huong dan viet Section 0 & 1

```
Section 0 — Tong quan:
- Doc tu: docs/README.md, docs/00-project-overview/*.md, root README.md
- Neu khong co docs → suy luan tu ten project + module names
- Giu ngan gon: khong qua 3 cau

Section 1 — He Thong (chi khi multi-app):
- Multi-app = phat hien >= 2 thu muc app rieng biet co source files
  (e.g. apps/backend + apps/frontend; packages/ + apps/)
- Lay thong tin tu: README.md tung app, package.json description, doc-files.json
- Truong "Doi tuong su dung": ai CHINH dung app do?
  e.g. "Nhan vien noi bo", "Khach hang", "Quan tri vien", "Cong chung"
- Truong "Trang thai": lay tu assessment hoac dem files/completion estimate
```

---

## Size Guideline (Context Window Safety)

```
MUC TIEU: project-context.md <= 4000 tokens (~2700 tu)

Truncation Rules (ap dung khi du an lon):
- Section 1 (He thong): Liet ke TAT CA apps — khong truncate (toi da 10)
- Section 3 (Module Map): Toi da 20 modules. Neu > 20:
  → Liet ke top 20 theo so files (giam dan), them "+ [N] modules khac"
- Section 5 (Features): Toi da 5 features per module (theo confidence giam dan)
  → Chi show cac BUSINESS modules (bo noise — xem Noise Module Filter)
  → Tat ca business modules phai co mat — khong truncate theo modules
- Section 6 (Impl Status): Toi da 30 entries. Neu > 30:
  → Group theo status: DONE ([N]), PARTIAL ([M]), NOT_STARTED ([K])
  → Chi liet ke chi tiet PARTIAL (can attention nhat)
- Section 4 (Tai lieu): Chi giu HIGH + MEDIUM trust. DISCARD entries → bo.
- Section 7 (Diem Chu y): Toi da 10 items, uu tien CRITICAL truoc.
```

### Noise Module Filter cho Section 5

```
Loai bo cac module sau khi render Section 5:
- backup, scripts, test, testing, config, core, errors, qc, support,
  layout, navigation, state, i18n, ui-components, shared, persistence,
  infrastructure, api, shared-kernel
- Cac module co REQs <= 1

Giu lai:
- Cac module co >= 2 REQs
- Cac module duoc liet ke trong project docs
```

---

## POST-GATE (Tier T1→T4 — CORE-012, Protocol 10)

```
T1 — Existence (file ton tai + non-empty):
  1. test -s .mc-data/work/legacy-scan/project-context.md
  2. test -s .mc-data/work/legacy-scan/doc-quality-map.json
  3. # impl-status-snapshot required TRU condensed mode
      [ "${IMPL_SNAPSHOT_SKIPPED:-false}" = "true" ] || test -s .mc-data/work/legacy-scan/impl-status-snapshot.json
  4. test -s .mc-data/work/legacy-scan/phase-summary.md

T2 — Structure (JSON validity + required headers):
  5. jq '.' doc-quality-map.json > /dev/null
  6. jq '.' impl-status-snapshot.json > /dev/null
  7. jq -e '.total_docs // 0' doc-quality-map.json
  8. jq -e '.by_trust_level' doc-quality-map.json
  9. # project-context.md co cac section bat buoc (0-8)
     for h in "## 0." "## 2." "## 3." "## 7." "## 8."; do
       grep -q "$h" .mc-data/work/legacy-scan/project-context.md || exit 1
     done

T2b — Impact Graph Schema (skip neu synthesis_mode=condensed hoac build failed):
  if [ "$SYNTHESIS_MODE" != "condensed" ] && [ "${IMPACT_GRAPH_SKIPPED:-false}" != "true" ]; then
    9a. test -s .mc-data/work/legacy-scan/impact-graph.json
    9b. jq -e '."$schema" == "impact-graph-v1"' impact-graph.json
    9c. jq -e '.synthesis_mode | test("^(full|full\\+insights|full\\+divergence)$")' impact-graph.json
    9d. jq -e '.nodes | type == "array"' impact-graph.json
    9e. jq -e '.edges | type == "array"' impact-graph.json
    9f. jq -e '.circular_dependencies | type == "array"' impact-graph.json
    9g. jq -e '.orphan_modules | type == "array"' impact-graph.json
    9h. jq -e '.summary.total_nodes != null and .summary.total_edges != null' impact-graph.json
    9i. # Moi edge su dung relation trong allow-list
        jq -e '[.edges[].relation] - (.relation_types_allowed // []) | length == 0' impact-graph.json
  fi

T3 — Content depth (LEGACY_MODE anchor — CORE-021 yeu cau > 500 bytes):
  10. test $(wc -c < .mc-data/work/legacy-scan/project-context.md) -gt 500
  11. wc -l < .mc-data/work/legacy-scan/project-context.md | awk '{exit ($1 < 30)}'   # ≥30 dong
  12. # impl-status-snapshot la OBJECT voi field .features[] — skip neu condensed mode
      [ "${IMPL_SNAPSHOT_SKIPPED:-false}" = "true" ] || \
        jq -e '(.features // []) | length >= 0' impl-status-snapshot.json
  13. grep -q "Phase 4" .mc-data/work/legacy-scan/phase-summary.md

T4 — Cross-reference (consistency giua synthesized files va source data):
  14. jq -e '.pipeline_status == "COMPLETE"' ledger.json
  15. jq -e '.stages.synthesize.status == "completed"' ledger.json
  16. # Tech stack tu project-profile.json phai xuat hien trong project-context.md Section 2
      # Template fields: .frameworks.backend[] (array) va .languages.primary (string).
      MAIN_TECH=$(jq -r '(.frameworks.backend[0] // .languages.primary // empty)' project-profile.json)
      [ -z "$MAIN_TECH" ] || grep -qi "$MAIN_TECH" .mc-data/work/legacy-scan/project-context.md
  17. # Strategy tu ledger phai duoc note trong project-context.md Section 8
      STRATEGY=$(jq -r '.strategy.id' ledger.json)
      grep -q "$STRATEGY" .mc-data/work/legacy-scan/project-context.md
  18. # impl-status-snapshot READ-ONLY contract: only Phase 4 writes (P8 lifecycle)
      # Verify timestamp set during Phase 4 (skip neu condensed)
      [ "${IMPL_SNAPSHOT_SKIPPED:-false}" = "true" ] || \
        jq -e '.generated_at // .created_at // empty' impl-status-snapshot.json
  19. # Impact graph consistency (skip neu condensed hoac build failed)
      if [ "$SYNTHESIS_MODE" != "condensed" ] && [ "${IMPACT_GRAPH_SKIPPED:-false}" != "true" ]; then
        # Moi node id trong edges phai ton tai trong nodes[]
        jq -e '
          (.nodes | map(.id)) as $ids
          | [.edges[] | (.from, .to)] | unique - $ids | length == 0
        ' impact-graph.json
        # Circular deps references phai la node hop le
        jq -e '
          (.nodes | map(.id)) as $ids
          | [.circular_dependencies[][]] - $ids | length == 0
        ' impact-graph.json
      fi
```

Nếu ANY tier fail → áp dụng `_shared.md §Auto-Fix & Escalation Protocol` (per-phase budget 3):
- T1/T2 fail → re-run Step 4.4-4.6 (re-write tu template) — tang retry counter
- T2b fail (impact-graph) → re-run Step 4.6.5 (rebuild graph) — tang retry counter.
  Neu van fail sau budget het → WARN + ghi "Impact graph build failed (non-blocking)" vao phase-summary,
  xoa file trong session, **export IMPACT_GRAPH_SKIPPED=true** de T4 step 19 skip; POST-GATE pass (W-L6-02 non-blocking).
- T3 fail (< 500 bytes hoac too short) → re-populate sections, re-write (tang retry counter)
- T4 fail (cross-ref mismatch) → re-read source artifacts, re-render Section 2/8 (tang retry counter)
- T4 step 19 fail (impact-graph id mismatch) → re-run Step 4.6.5 hoac export IMPACT_GRAPH_SKIPPED=true + WARN (non-blocking).
- Sau $RETRY_COUNT[phase4] >= 3 vẫn fail → STOP, KHONG bao pipeline COMPLETE

## On Failure

Theo `_shared.md §On Failure — Standard Format`. Cụ thể Phase 4:
- T3 fail nghiem trong (project-context.md < 200 bytes) → check input artifacts (Phase 1-3 data) co day du khong
- T4 fail (tech stack/strategy mismatch) → re-read project-profile.json + ledger.json, re-render
- Sau 3 attempts vẫn fail → STOP, AskUserQuestion: "Manual edit project-context.md / Re-run Phase 4 / Cancel"
- KHONG mark pipeline_status = COMPLETE neu T1-T4 chua pass — tranh false positive cho LEGACY_MODE detection downstream

---

## Completion Message (Step 4.12)

Sau khi POST-GATE Phase 4 PASS, hien thi:

```
Legacy Scan hoan tat!
Da scan: [N] files, [M] modules, [K] features
Tech stack: [detected]
Tai lieu: [N] docs ([X] HIGH, [Y] MEDIUM trust)
Confidence trung binh: [score]

→ project-context.md da san sang
→ Buoc tiep theo: /wf-brainstorm
```

## Next Skill

→ `/wf-brainstorm` (legacy flow) — shared skills tu detect LEGACY_MODE tu `project-context.md` (CORE-021).
