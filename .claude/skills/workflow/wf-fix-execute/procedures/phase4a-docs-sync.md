# Phase 4a: Docs Sync — Cap Nhat Existing Docs

> Kiem tra: fix nao thay doi behavior cua feature? Neu co → cap nhat docs.
> Doc file nay khi bat dau Phase 4a (sau Phase 3 completed).

**PRE-GATE:** Phase 3 completed (it nhat Batch 1). `jq -e '.phases.phase_3.status == "completed"' fix-status.json`.

**INPUT:** Fix log tu Phase 3, feature specs tu `phase2-features/`.

**OUTPUT:** Updated feature specs (neu behavior doi), safe-write registry impl_status.

---

## Steps

> **Loop-back detection:** Khi re-enter Phase 4 tu Phase 5 verify loop (`phases.phase_5.iterations_run > 0`), chi xu ly behavior changes tu iteration hien tai — khong process lai entries da xu ly o lan dau. Detect qua `fix-log.json entries[].iteration` field.

| Step | Action                                                                                                                                       | Verify              |
| ---- | -------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- |
| 4.1  | **READ fix-log.json:** Iterate entries, identify entries WHERE `behavior_changed == true` HOAC `api_contract_changed == true`. **Loop-back guard:** Neu `phases.phase_5.iterations_run > 0` (re-entered from Phase 5) → chi process entries WHERE `iteration == phases.phase_5.loop_state.current_iteration`. Neu first pass (iterations_run == 0) → process all entries. | Changes categorized |
| 4.1a | **CI Cross-Check REQ-IDs (BAT BUOC khi `$SERENA_AVAILABLE=true` HOAC `$GITNEXUS_AVAILABLE=true`):** Voi moi entry da changed: (a) `mcp__serena__get_symbols_overview({relative_path: <file>})` → liet ke symbols trong file. (b) Voi moi symbol → `mcp__plugin_gitnexus_gitnexus__context({name: <symbol>})` → lay REQ-ID annotation neu co. (c) **Cross-check:** so sanh REQ-IDs trong `fix-log.json.req_id` field voi REQ-IDs lay duoc tu code. **Mismatch handling:** Neu fix-log claim REQ-X nhung code khong co annotation → log warning, them REQ-X vao `pending_annotations[]`. Neu code co REQ-Y nhung fix-log thieu → bo sung vao `additional_req_ids[]`. (d) Ghi ket qua vao `$SESSION_DIR/docs-sync-ci-log.json`. CI absent → skip step (giu nguyen behavior cu, dua hoan toan vao fix-log.json claims). Xem §CI Cross-Check Logic ben duoi. | Cross-check log written |
| 4.2  | **SCOPE FILTER:** Chi cap nhat feature specs trong `phase2-features/` thuoc `$TARGET_SCOPE.systems` hoac `$TARGET_SCOPE.modules`. Doc module mapping tu `$SESSION_DIR/issue-registry.json` issues[].req_id neu can. **Bo sung tu 4.1a:** include `additional_req_ids[]` neu thuoc scope. | Scoped              |
| 4.2a | **CDG-EXEC-01 (CDG-02 overwrite) — BAT BUOC:** Hien thi list TAT CA feature specs se update + tom tat thay doi (Bug Fix Notes section). Hoi user: "AI se them 'Bug Fix Notes' vao N feature specs sau do. Dong y? (Co/Khong/Chi tiet)". **Batch accept** (Protocol 16 §16.3.6): 1 prompt cho toan bo Phase 4a. Nhung user "Khong" → skip all Phase 4a updates, ghi vao report. Xem [CORE-027 CDG](_shared.md#core-027-critical-decision-gate). | User confirmed |
| 4.3  | Voi moi behavior change (da qua CDG): doc feature spec tuong ung                                                                             | Spec loaded         |
| 4.4  | Cap nhat feature spec: ghi ro thay doi va ly do (bug fix)                                                                                    | Spec updated        |
| 4.5  | Neu fix tao code moi → verify REQ-ID comment co trong code                                                                                   | REQ-IDs present     |
| 4.6  | Update `req-registry.json`: chi field `impl_status` — **CHI cho REQ-IDs thuoc `$TARGET_SCOPE.reqs`** (safe-write). Xem [Registry Safe-Write](_shared.md#registry-safe-write). | Registry updated    |
| 4.7  | **BAT BUOC — Cap nhat fix-status.json** theo spec "Phase 4a POST-GATE" trong [`_shared.md`](_shared.md#fix-statusjson-update-contract) | `jq '.metrics.docs_synced >= 0' $SESSION_DIR/fix-status.json` |

---

## Rules Cap Nhat Docs

```
NEU fix CHI sua bug (behavior khong doi):
  → KHONG cap nhat feature spec
  → Chi log trong fix-report

NEU fix THAY DOI behavior (API response format, validation rules, etc.):
  → CAP NHAT feature spec: them section "Bug Fix Notes" voi:
    - Ngay fix
    - Mo ta thay doi
    - Ly do (bug description)
  → KHONG thay doi REQ-ID hoac feature structure

NEU fix TAO CODE MOI (utility, helper khong co trong spec):
  → Them REQ-ID comment vao code
  → KHONG tao requirement/feature moi trong registry
```

---

## CI Cross-Check Logic (Step 4.1a)

> **Muc dich:** Phat hien orphan REQ-IDs (code co annotation nhung khong dien trong fix-log) va missing annotations (fix-log claim REQ-X nhung code khong co `// REQ-ID: REQ-X`). Tang accuracy mapping REQ-ID ↔ code.
> **Graceful:** CI absent → skip toan bo logic, fallback purely fix-log.json based (zero regression).

### Pseudocode

```python
docs_sync_ci_log = []
additional_req_ids = []
pending_annotations = []

for entry in fix_log.entries:
    if not entry.behavior_changed and not entry.api_contract_changed:
        continue
    claimed_req_ids = entry.req_id or []  # tu fix-log
    actual_req_ids = []  # tu code via CI
    
    for file_path in entry.files_modified:
        # Step (a): get symbols
        if SERENA_AVAILABLE:
            symbols = mcp_serena_get_symbols_overview(file_path)
        else:
            continue
        
        # Step (b): extract REQ-IDs tu context cua moi symbol
        for sym in symbols:
            if GITNEXUS_AVAILABLE:
                ctx = mcp_gitnexus_context(name=sym.name)
                req_ids_in_ctx = parse_req_id_annotations(ctx.docstring or "")
                actual_req_ids.extend(req_ids_in_ctx)
            else:
                # Fallback: doc body symbol qua Serena
                body = mcp_serena_find_symbol(name_path=sym.name, relative_path=file_path, include_body=True)
                actual_req_ids.extend(parse_req_id_annotations(body))
    
    # Step (c): cross-check
    claimed_set = set(claimed_req_ids)
    actual_set = set(actual_req_ids)
    
    missing_in_code = claimed_set - actual_set  # claim nhung code khong co
    extra_in_code = actual_set - claimed_set    # code co nhung fix-log thieu
    
    if missing_in_code:
        pending_annotations.append({
            "entry_id": entry.id,
            "files_modified": entry.files_modified,
            "missing_req_ids": list(missing_in_code),
            "action": "agent should add // REQ-ID: ... annotation"
        })
    if extra_in_code:
        additional_req_ids.extend(extra_in_code)
    
    docs_sync_ci_log.append({
        "entry_id": entry.id,
        "claimed": list(claimed_set),
        "actual": list(actual_set),
        "missing_in_code": list(missing_in_code),
        "extra_in_code": list(extra_in_code)
    })

# Step (d): ghi log
write_json("$SESSION_DIR/docs-sync-ci-log.json", {
    "schema": "docs-sync-ci-log-v1",
    "ci_meta": {
        "gitnexus_used": GITNEXUS_AVAILABLE,
        "serena_used": SERENA_AVAILABLE,
        "freshness_level": FRESHNESS_LEVEL
    },
    "entries": docs_sync_ci_log,
    "pending_annotations": pending_annotations,
    "additional_req_ids": list(set(additional_req_ids))
})
```

### Hanh dong dua tren ket qua cross-check

| Tinh huong | Hanh vi Phase 4a |
|------------|------------------|
| `pending_annotations[]` non-empty | Step 4.5 verify se warn → escalate cho agent neu cap thiet (developer agent them annotation) |
| `additional_req_ids[]` non-empty va in scope | Step 4.2 include them, Step 4.6 update `impl_status` cho REQ-IDs nay (safe-write — chi `not_started` → `done`) |
| `additional_req_ids[]` non-empty nhung OUT of scope | Log warning, KHONG update (respect $TARGET_SCOPE.reqs) |
| Cross-check pass (claim ≡ actual) | Tiep tuc binh thuong, log "ci_xref: aligned" |
| CI absent / partial fail | Log "ci_xref: skipped" hoac "ci_xref: partial — N entries unchecked", continue voi fix-log only |

### Schema docs-sync-ci-log.json

```json
{
  "$schema": "docs-sync-ci-log-v1",
  "ci_meta": {
    "gitnexus_used": true,
    "serena_used": true,
    "freshness_level": "ok",
    "behind_commits": 0
  },
  "entries": [
    {
      "entry_id": "fix-log-entry-3",
      "claimed": ["REQ-CRM-001"],
      "actual": ["REQ-CRM-001", "REQ-CRM-002"],
      "missing_in_code": [],
      "extra_in_code": ["REQ-CRM-002"]
    }
  ],
  "pending_annotations": [],
  "additional_req_ids": ["REQ-CRM-002"]
}
```

---

## POST-GATE (CORE-012 — tiered T1-T4)

| Tier | Check | Verify |
|------|-------|--------|
| T1 | `test -f $REGISTRY` (neu co update) + `test -f` cho moi feature spec da update | Files exist |
| T2 | `test -s $REGISTRY` (neu co update) | Non-empty |
| T3 | `jq '.' .mc-data/docs/_meta/req-registry.json` PASS + feature spec co heading `# [Feature name]` | JSON + Markdown valid |
| T4 | `jq -e '.requirements[] \| select(.req_id==$REQ) \| .impl_status != null' req-registry.json` cho moi REQ-ID da safe-update + feature spec co section "Bug Fix Notes" (neu behavior_changed=true) | Required content |

Chi PASS khi TAT CA T1-T4 pass. Neu T3/T4 fail → retry (max 3) → escalate.

**Content validity (semantic):**
- Docs consistent voi code changes

**fix-status.json (BAT BUOC):**
```
phases.phase_4.sub_phases.phase_4a.status = "completed"
phases.phase_4.sub_phases.phase_4a.completed_at = NOW
metrics.docs_synced = N
docs_updated = [list]
progress_pct = 75
timestamps.last_updated = NOW
next_action = IF flags.deep THEN "phase_4b_stubs" ELSE "phase_5_verify"
```

**Next:**
- IF `flags.deep == true` → `phase4b-stubs.md`
- ELSE → `phase5-scan.md`
