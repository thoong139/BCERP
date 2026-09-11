# Phase 4: Code-REQ Sync Check (PARALLEL với Phase 5)

> **Protocol:** Xem `.claude/skills/protocols/`
> **Shared:** Xem `procedures/_shared.md` — State Variables, Scoring Formulas

Kiểm tra code đã implement đủ requirements cho scope chưa. Chỉ chạy nếu `src/` hoặc `apps/` tồn tại.

---

## PRE-GATE

```
test -d src || test -d apps
```

`$TARGET_REQS`, `$TARGET_FEATURES` (từ Phase 1) đã set.

> **Nếu không có code:** SKIP phase này, set `$SCORES.sync_score = null` (case 1 trong Scoring Formulas), ghi NOTE "No source code found" vào `$SYNC_ISSUES` metadata, set `$SYNC_ISSUES = []`.

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 4.1 | Xác định code paths theo scope (xem bảng Code Path Mapping bên dưới) | Paths determined |
| 4.2 | Scan code files trong scope → tìm REQ-ID + FEAT-ID comments (regex: `(REQ-[A-Z]+-\d+\|REQ-[A-Z]+-[A-Z]+-\d+\|FEAT-[A-Z]+-[A-Z]+-\d+)`) | Code refs built |
| 4.3 | Match `$TARGET_REQS` vs code_refs → categorize: done / in_progress / not_started | Match map built |
| 4.4 | Identify orphan files (source files không có REQ-ID comments) trong scope | Orphan list built |
| 4.5 | Tính `sync_score` theo công thức (xem `_shared.md` §Scoring Formulas) | Score calculated |

---

## Code Path Mapping theo Scope

| Scope | Code paths scan |
|-------|----------------|
| `all` | `src/**` + `apps/**` + `packages/**` (toàn bộ, bao gồm monorepo shared code) |
| `system --name=SYS-ERP` | `apps/erp/**` hoặc scan theo system prefix |
| `module --name=MOD-ERP-FIN` | Scan tìm files chứa REQ-IDs của module |
| `feature --name=FEAT-ERP-FIN-001` | Scan tìm files chứa FEAT-ID hoặc REQ-IDs của feature |

---

## REQ-ID Patterns trong Code (hỗ trợ mọi ngôn ngữ)

```
// REQ-ID: REQ-FIN-001             ← TypeScript, JS, Go, Java, C#
/* REQ-ID: REQ-FIN-001 */
# REQ-ID: REQ-FIN-001              ← Python, Ruby, shell
[Description("REQ-API-FIN-001")]   ← C# attribute
```

**Exclude patterns (không scan):** `*.config.*`, `*.d.ts`, `*.test.*`, `*.spec.*`, `*.min.js`, `*.bundle.*`, `node_modules/`, `dist/`, `build/`

> **Lưu ý:** `index.ts` và `types.ts` KHÔNG bị exclude — có thể chứa REQ-ID references (barrel exports, type definitions).

---

## Scoring

```
reqs_expected_in_code = $TARGET_REQS WHERE impl_status IN ("done", "in_progress")
  (KHÔNG đếm "not_started" — chưa implement là đúng trạng thái)
  (impl_status = "skipped" → KHÔNG expected in code, KHÔNG tính vào denominator)
reqs_found_in_code   = reqs_expected_in_code WHERE code file chứa REQ-ID

sync_score = (reqs_found_in_code / reqs_expected_in_code) × 100
```

**NULL cases:**
- **Case 1:** Không có `src/` hoặc `apps/` → PRE-GATE skip → `sync_score = null`
- **Case 2:** `reqs_expected_in_code == 0` (tất cả REQ là not_started hoặc skipped) → `sync_score = null`

**Lý do:** REQ có `impl_status="not_started"` mà không có code KHÔNG phải lỗi sync. REQ có `impl_status="skipped"` (deprecated) cũng KHÔNG phải lỗi sync. Chỉ REQ đã "done"/"in_progress" mà không tìm thấy trong code mới là gap thực sự.

**Ví dụ số học:**
- 10 REQs done/in_progress, 8 tìm thấy → `sync_score = 80%`
- 5 REQs done/in_progress, 5 tìm thấy → `sync_score = 100%`
- 0 REQs done/in_progress (tất cả not_started) → `sync_score = null` (case 2)

> Xem `_shared.md` §Scoring Formulas — sync_score — đầy đủ.

---

## POST-GATE

```
test -n "$SYNC_ISSUES"   # Phải set (dù 0 issues)
```

- `$SYNC_ISSUES` = array (có thể rỗng `[]`)
- `$SCORES.sync_score` ∈ [0, 100] hoặc `null` (skip hợp lệ)
- Status file `preflight-status.json`: `phases.phase_4.status = "completed"` hoặc `"skipped"` với `skip_reason`

---

## Output → Next Phase

- `$SYNC_ISSUES` (in-memory) — đọc bởi Phase 5b, 6, 7
- `$SCORES.sync_score` — đọc bởi Phase 7
- Orphan files list — dùng trong Phase 6 nếu `--fix`

**Parallel Note:** Phase 4 chạy ĐỒNG THỜI với Phase 5 (Code Quality). Phase 4 scan comments, Phase 5 chạy tooling → khác I/O path, không conflict.
