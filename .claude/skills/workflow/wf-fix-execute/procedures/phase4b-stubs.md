# Phase 4b: Stub Docs Creation (--deep only)

> Tach rieng khoi Phase 4a (Docs Sync) vi ban chat khac: Phase 4a cap nhat existing docs, Phase 4b tao NEW stub files.
> **Data source:** Doc `$ORPHAN_UI_ISSUES[]` tu `$SESSION_DIR/checkpoint.json` field `partial_state.deep_scan_state.orphan_ui_issues_accumulated` (LUON doc tu checkpoint, ke ca trong session lien tuc — dam bao consistency).
> Chi chay khi `flags.deep == true` VA `$ORPHAN_UI_ISSUES` khong rong.

**PRE-GATE:**
- Phase 4a completed
- `fix-status.json.flags.deep == true`
- `$ORPHAN_UI_ISSUES` non-empty

**IF `flags.deep == false`:** SKIP toan bo Phase 4b.

**INPUT:** `$SESSION_DIR/checkpoint.json` (orphan_ui_issues_accumulated), `$SESSION_DIR/issue-registry.json`.

**OUTPUT:** Stub files trong `.mc-data/docs/phase2-features/` va `.mc-data/docs/phase4-ux/`.

---

## Phase 3→4b Invalidation Logic

**Muc dich:** Loai bo orphan issues da duoc Phase 3 Fix giai quyet → tranh tao stub docs trung lap.

**Precondition:**
- wf-fix-bugs Lane Dispatch (QD6/QD7) da populate `matched_feature_id`, `matched_module_id`, `orphan_type` trong moi issue khi phat hien orphan UI elements.
- Phase 3 da UPDATE issue-registry.json: set `status = "fixed"` cho issues da xu ly.

**Logic (3 cases):**

```
LOAD $ORPHAN_UI_ISSUES = jq '[.issues[] | select(.orphan_type != null)]' issue-registry.json

FOR each orphan in $ORPHAN_UI_ISSUES:
  CASE 1 — Orphan da co matched_feature_id VA Phase 3 da fix feature do:
    # Phase 3 fix feature nay → khong can stub them
    MATCHED_ISSUES = jq '[.issues[] | select(.req_id == orphan.req_id and .status == "fixed")]'
    IF MATCHED_ISSUES.length > 0:
      INVALIDATE orphan (remove from Phase 4b stub creation list)
      LOG: "Orphan $issue_id invalidated — feature $matched_feature_id already fixed"

  CASE 2 — Orphan khong co matched_feature_id (truly orphan):
    # Khong co feature tuong ung trong registry → Phase 4b se tao stub moi
    KEEP orphan in stub creation list

  CASE 3 — Orphan co matched_feature_id NHUNG Phase 3 khong fix:
    # Feature ton tai trong docs nhung UI element chua duoc handle → van can update feature doc
    → Route sang Phase 4a (UPDATE existing feature spec), KHONG tao stub
    REMOVE from Phase 4b list, ADD to Phase 4a update list
```

**Update checkpoint.json:** SET `partial_state.deep_scan_state.orphan_ui_issues_accumulated` (loai bo CASE 1 entries) TRUOC khi Phase 4b chay.

**Output:** Filtered `$ORPHAN_UI_ISSUES_FOR_STUB` — chi nhung items qua Phase 4b stub creation (CASE 2 only).

**Short-circuit:** Neu sau invalidation `$ORPHAN_UI_ISSUES_FOR_STUB` rong → skip Phase 4b, LOG "All orphan UI issues resolved by Phase 3 fixes or routed to Phase 4a update".

---

## CORE-027 Critical Decision Gate (BAT BUOC — CDG-EXEC-03)

Xem [CORE-027 CDG](_shared.md#core-027-critical-decision-gate) (map voi Protocol 16 skill-specific). Truoc khi tao bat ky stub nao, PHAI hien thi summary va hoi user xac nhan (batch accept pattern theo Protocol 16 §16.3.6):

```
Phat hien [N] UI elements khong co docs:
  - [X] orphan actions (feature specs)
  - [Y] orphan screens (UX docs)
  - [Z] orphan flows (flow docs)

Tao [N] stub docs trong .mc-data/docs/? (yes/no/review)
  - "yes": Tao tat ca stubs
  - "no": Bo qua, chi ghi vao report
  - "review": Hien thi chi tiet tung orphan de user chon
```

- User "no" → skip Phase 4b, ghi orphan issues vao report (Phase 6)
- User "review" → hien thi table orphan issues, user tick chon → chi tao stubs cho items duoc chon

---

## Stub Creation Rules

| Orphan Type | Stub Path | Template |
|-------------|-----------|----------|
| `ORPHAN_UI_ACTION` | `.mc-data/docs/phase2-features/[sys]/[mod]/[slug].md` | Feature spec stub |
| `ORPHAN_UI_SCREEN` | `.mc-data/docs/phase4-ux/[sys]/[mod]/screens-[slug].md` | UX screen stub |
| `ORPHAN_UI_FLOW` | `.mc-data/docs/phase2-features/[sys]/[mod]/flow-[slug].md` | Flow doc stub |

Moi stub co frontmatter:

```yaml
status: stub
needs_review: true
source: wf-fix-bugs --deep (auto-discovered)
discovered_at: YYYY-MM-DD
related_feature_id: null  # hoac FEAT-ID neu gap analysis match duoc
related_req_id: null  # hoac REQ-ID neu gap analysis match duoc
```

### Slug Generation Logic

1. Uu tien: `element.text` (hoac `suggested_name`) → normalize: lowercase, strip diacritics (normalize NFD + remove combining marks), replace spaces/special chars with hyphens, truncate 50 chars, remove leading/trailing hyphens
2. Fallback (element.text empty): `orphan-{type_short}-{sequence_number}` (VD: `orphan-action-001`)
3. Anti-collision: Append hash suffix (4 chars, simple hash tu `page_url + element_identifier`). VD: `submit-order-a3f2.md`
4. Type prefix cho flows: Flow stubs luon co prefix `flow-`. VD: `flow-checkout-process-b7e1.md`

**QUAN TRONG:** KHONG tao REQ-ID moi, KHONG them features[] vao registry. Stubs chi la markers cho `/wf-define-features` hoac `/wf-design-ux` xu ly sau.

**Unmapped module fallback:** Neu orphan element thuoc page_url KHONG match module nao trong registry → tao stub tai `.mc-data/docs/phase2-features/_unmapped/[slug].md` voi frontmatter bo sung: `system: null, module: null, unmapped: true, original_page_url: [url]`.

**LEGACY_MODE filter:** Doc `$DEPRECATED_MODULES` tu `legacy-decisions.json` (neu LEGACY_MODE). Loai bo orphan issues thuoc deprecated modules TRUOC khi tao stubs.

---

## POST-GATE (CORE-012 — tiered T1-T4)

| Tier | Check | Verify |
|------|-------|--------|
| T1 | `test -f` cho moi stub file tao moi | File exists |
| T2 | `test -s` cho moi stub file | File non-empty |
| T3 | `grep "status: stub"` trong moi stub file | YAML frontmatter valid |
| T4 | `grep "needs_review: true"` + `grep "source: wf-fix-bugs"` + `grep "discovered_at:"` | Required content present |

Neu T1-T4 FAIL cho bat ky stub → LOG warning voi filename, tiep tuc voi stubs con lai. KHONG block toan bo Phase 4b neu 1 stub fail.

**BAT BUOC:** Update fix-status.json theo spec "Phase 4b POST-GATE" trong [`_shared.md`](_shared.md#fix-statusjson-update-contract).

**Next:** `phase5-scan.md` (full regression scan + playwright verify).
