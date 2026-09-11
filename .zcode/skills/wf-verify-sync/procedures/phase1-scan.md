# Phase 1: Scan — Collect REQ-IDs + Scan Code (PARALLEL)

> Gộp Phase 2 (Collect REQ-IDs) + Phase 3 (Scan Code) — chạy đồng thời (Protocol 7).
> Output là 3 in-memory variables: `$REQ_INDEX`, `$CODE_REFS`, `$ORPHAN_LIST`.

**PRE-GATE:**
- Phase 0 (`phase0-init.md`) POST-GATE PASS
- `test -f .mc-data/docs/_meta/req-registry.json`
- `test -d src || test -d apps`

**📥 INPUT:**

| File / Path | Mục đích |
|-------------|----------|
| `.mc-data/docs/_meta/req-registry.json` | Source of truth REQ-IDs |
| `.mc-data/docs/phase2-features/**/*.md` | Cross-reference REQ-IDs trong feature specs |
| `.mc-data/docs/phase1-business/departments/**/*.md` | Cross-reference REQ-IDs trong dept docs |
| `src/`, `apps/` | Source code chứa REQ-ID comments |

**📤 OUTPUT (in-memory):**
- `$REQ_INDEX` — map REQ-ID → metadata
- `$CODE_REFS` — map REQ-ID → list source file paths
- `$ORPHAN_LIST` — array source file paths không có REQ-ID

> Phase này KHÔNG tạo file mới. Output là in-memory state cho Phase 2.

---

## Reference Sections

- `_shared/scope-filtering.md`
- `_shared/req-id-patterns.md`
- `_shared/checkpoint-protocol.md` (batch strategy cho project > 500 files)

---

## Parallel Groups

> **Protocol 7 (PAR):** Group A và Group B độc lập — chạy đồng thời.

| Group | Phase ID | Action |
|-------|----------|--------|
| **A** | 1.A | Collect REQ-IDs từ registry + docs |
| **B** | 1.B | Scan code cho REQ-ID comments + orphan discovery |

---

## Group A — Collect REQ-IDs (cũ Phase 2)

| Step | Action | Verify |
|------|--------|--------|
| 1.A.1 | Đọc `req-registry.json` → extract REQ-ID list. Nếu `$SCOPE_FILTER` (từ Phase 0): CHỈ lấy REQ-IDs thuộc scope | IDs loaded |
| 1.A.2 | Scan `phase2-features/**/*.md` + `phase1-business/departments/**/*.md` → cross-reference REQ-IDs (CHỈ docs thuộc `$SCOPE_FILTER` nếu có) | Cross-ref done |
| 1.A.3 | Deduplicate + build `$REQ_INDEX` (map REQ-ID → `{title, priority, impl_status, module_id, system_id, source: registry/docs}`) | Index built |

**REQ-ID patterns** — xem `_shared/req-id-patterns.md`.

**POST-GATE Group A:** `test -n "$REQ_INDEX"` (non-empty)

---

## Group B — Scan Code (cũ Phase 3)

> **v4.0+ S4:** Group B delegated to `vs-scan-code.sh` cho token efficiency.
> Nếu project > 500 source files: scan theo batches (module-by-module) — xem `_shared/checkpoint-protocol.md`.

| Step | Action | Verify |
|------|--------|--------|
| 1.B.1 | **Bash delegation:** Chạy `bash .claude/scripts/wf-verify-sync/vs-scan-code.sh --scope-file <(echo "$SCOPE_FILTER_JSON") --output $SESSION_DIR/scan-results.json`. Nếu `$SCOPE_FILTER.modules` non-empty → pass `--src-dirs` với module directories. | `test -s $SESSION_DIR/scan-results.json` |
| 1.B.2 | Đọc `$SESSION_DIR/scan-results.json` → set `$SCAN_RESULTS` (in-memory) | `$SCAN_RESULTS` loaded |
| 1.B.3 | Extract `$CODE_REFS` từ `$SCAN_RESULTS.req_id_map` (map REQ-ID → list of file paths) | Map extracted |
| 1.B.4 | Extract `$ORPHAN_LIST` từ `$SCAN_RESULTS.orphan_files` | Orphan list extracted |
| 1.B.5 | Verify: `test -n "$(echo '$SCAN_RESULTS' | jq -r '.scan_summary.files_scanned')"` > 0 | Scan non-empty |

### vs-scan-code.sh — Input/Output

```
Input:  --scope-file (JSON: {req_ids: [], modules: []}) [optional]
        --src-dirs (space-separated directories, default: "src apps")
        --output <path>
Output: scan-results.json:
        {req_id_map: {REQ-XXX-001: ["file1.ts", "file2.ts"], ...},
         orphan_files: ["path/to/file.ts", ...],
         total_files_scanned: N,
         scan_summary: {directories_scanned, files_scanned, req_ids_found, orphans_found}}
Logic:  grep -r "REQ-[A-Z]+-" across source dirs, apply exclude patterns
        (xem `_shared/req-id-patterns.md`), group by REQ-ID, collect files
        without REQ-ID as orphans. Monorepo-aware (apps/*/src/, packages/*/src/).
```

**Exclude patterns** + **Monorepo support** — xem `_shared/req-id-patterns.md`.

**POST-GATE Group B:** `test -n "$CODE_REFS" && test -n "$ORPHAN_LIST"` (cả hai có thể là empty array nhưng phải defined)

---

## Checkpoint Decision

> Sau khi Group A và Group B đều hoàn thành.

```
IF $CONTEXT_PERCENT > 80:
  → FORCE save checkpoint (data_snapshot.{req_index, code_refs, orphan_list})
  → STOP và yêu cầu user resume

IF $CONTEXT_PERCENT > 65:
  → Save checkpoint (advisory) — tiếp tục Phase 2
```

---

**POST-GATE Phase 1:**
- `test -n "$REQ_INDEX"` (Group A done)
- `test -n "$CODE_REFS" && test -n "$ORPHAN_LIST"` (Group B done — có thể empty arrays)
- Cập nhật `verify-sync-status.json`: `phases.phase_1.status="completed"`, `phases.phase_1.req_count`, `phases.phase_1.code_refs_count`, `phases.phase_1.orphan_count`, `parallel_execution.group_A.status="completed"`, `parallel_execution.group_B.status="completed"`

**NEXT:** Load `phase2-analyze.md`.
