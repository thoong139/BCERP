# Phase 3: UI-Code Coverage Check (CONDITIONAL)

> Cũ Phase 5b. Scan UI screens/routes thực tế từ codebase SAU khi implement.
> So sánh với `features[]` trong registry → phát hiện UI screens chưa có FEAT-ID.
> Áp dụng cho TẤT CẢ dự án (new + legacy) — không chỉ legacy.

**PRE-GATE:**

```
1. jq -r '.interface_type' .mc-data/docs/_meta/req-registry.json  # phải != "api-only"
   → Nếu == "api-only" → SKIP Phase 3 toàn bộ, set $UI_COVERAGE_DATA = null
2. Codebase có UI directories:
   test -d app/ || test -d pages/ || test -d src/app/ || test -d src/pages/
   → Nếu KHÔNG có UI directory → SKIP Phase 3, log warning "No UI directories found"
3. Phase 2 (`phase2-analyze.md`) POST-GATE PASS
```

**📥 INPUT:**

| File | Đường dẫn |
|------|-----------|
| Registry `features[]` | `.mc-data/docs/_meta/req-registry.json` |
| UI screens (scan) | Codebase `app/`, `pages/`, `src/app/`, `src/pages/` |

**📤 OUTPUT:**

| File | Đường dẫn |
|------|-----------|
| UI snapshot (raw scan) | `$SESSION_DIR/ui-snapshot.json` |
| UI coverage report | `$SESSION_DIR/ui-coverage-report.md` |
| In-memory | `$UI_COVERAGE_DATA` (object) |

---

## Reference Sections

- `_shared/state-variables.md` (`$UI_COVERAGE_DATA`, `$UI_SCAN_RESULTS`)

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 3.1 | **Bash delegation (v4.0+ S4):** Chạy `bash .claude/scripts/wf-verify-sync/vs-scan-ui.sh --registry .mc-data/docs/_meta/req-registry.json --interface-type $INTERFACE_TYPE --output $SESSION_DIR/ui-scan-results.json`. Script tự động detect UI directories (`app/`, `pages/`, `src/app/`, `src/pages/`) và filter theo INFRASTRUCTURE auto-skip list. Xem `vs-scan-ui.sh` source cho danh sách đầy đủ. | `test -f $SESSION_DIR/ui-scan-results.json` |
| 3.2 | Đọc `$SESSION_DIR/ui-scan-results.json` → set `$UI_SCAN_RESULTS`. Nếu `skipped=true` hoặc `empty_project=true` hoặc `screens` rỗng → log info, set `$UI_COVERAGE_DATA = null`, SKIP các bước còn lại. | `$UI_SCAN_RESULTS` loaded |
| 3.3 | Đọc `$UI_SCAN_RESULTS.matches` → extract đã có MATCHED, MISSING_FROM_FEATURES, MISSING_FROM_CODE từ `vs-scan-ui.sh` | Categories pre-computed |
| 3.4 | **GUARD — total_business_screens == 0 check:** Nếu `$UI_SCAN_RESULTS.total_business_screens == 0` → set `$UI_COVERAGE_DATA = null`, log info "No business screens found (all are infrastructure)", SKIP Steps 3.5–3.7. | Guard check done |
| 3.5 | Extract `coverage_pct`, `partial_coverage_pct` từ `$UI_SCAN_RESULTS` (đã pre-computed) | Rates extracted |
| 3.6 | **[READ-TEMPLATE]:** READ `templates/ui-coverage-report.md` → POPULATE placeholders từ `$UI_SCAN_RESULTS` → WRITE `$SESSION_DIR/ui-coverage-report.md` | Report created |
| 3.7 | Lưu vào `$UI_COVERAGE_DATA`: extract từ `$UI_SCAN_RESULTS` — `{total_screens, total_business_screens, matched_count, ..., coverage_pct, partial_coverage_pct, missing_from_features: [], missing_from_code: []}` | In-memory saved |

### vs-scan-ui.sh — Input/Output

```
Input:  --registry <path>       (.mc-data/docs/_meta/req-registry.json)
        --interface-type <type> (web/mobile/web+mobile/api-only)
        --output <path>
Output: ui-scan-results.json:
        {screens[], total_screens, total_business_screens, infrastructure_count,
         empty_project, skipped, skip_reason,
         matches: {matched_count, partial_match_count, missing_from_features_count,
                   missing_from_code_count, matched[], missing_from_features[],
                   missing_from_code[]},
         coverage_pct, partial_coverage_pct}
Logic:  Scan app/, pages/, src/app/, src/pages/ → detect Next.js App Router
        special files → filter INFRASTRUCTURE auto-skip (layout, error, loading,
        template, route, etc.) → match business screens to features[] in registry
        → auto-skip api-only projects. Output JSON cho Phase 6 report.
```

---

## Categories

| Category | Điều kiện | Severity |
|----------|-----------|----------|
| MATCHED | Screen có FEAT-ID tương ứng (exact hoặc fuzzy match) | PASS |
| PARTIAL_MATCH | Feature có screen chính nhưng thiếu sub-screens (modal, tab panel), hoặc screen refactor thành component composition | INFO |
| MISSING_FROM_FEATURES | Screen có trong code nhưng KHÔNG có FEAT-ID → code vượt scope | WARNING |
| MISSING_FROM_CODE | FEAT-ID có trong registry nhưng KHÔNG tìm thấy screen → chưa implement | WARNING |
| INFRASTRUCTURE | Screen match auto-skip list: `layout`, `error`, `loading`, `template`, `default`, `global-error`, `not-found`, `head`, `middleware`, `_app`, `_document`, `opengraph-image`, `sitemap`, `robots`, `favicon`, `icon`, `apple-icon`, `route` files (`route.ts`/`route.tsx`), parallel route slot directories (`@slot`), intercepting route segments (`(.)`, `(..)`). **Next.js App Router:** Route groups `(name)/` — không phải URL segment, chỉ dùng để group. → SKIP khi matching | SKIP |

---

## Matching logic (Step 3.4)

```
CHO MỖI screen trong ui-snapshot.json:
  1. Nếu screen.is_infrastructure=true → INFRASTRUCTURE
  2. Tìm FEAT-ID trong registry features[] có:
     - file field reference screen path (substring match)
     - name field khớp screen name (fuzzy)
     - module_id khớp module_hint từ screen directory
  3. Nếu tìm thấy → MATCHED
  4. Nếu >1 FEAT-ID match → đánh dấu PARTIAL_MATCH, review_required=true
  5. Nếu KHÔNG tìm thấy → MISSING_FROM_FEATURES

CHO MỖI FEAT-ID trong registry features[]:
  1. Tìm screen trong ui-snapshot.json khớp với feature
  2. Nếu KHÔNG tìm thấy → MISSING_FROM_CODE
```

---

## Coverage calculation

```
total_business_screens = total_screens - INFRASTRUCTURE_count
coverage_pct          = (MATCHED / total_business_screens) * 100
partial_coverage_pct  = ((MATCHED + PARTIAL_MATCH) / total_business_screens) * 100

Nếu total_business_screens == 0 → coverage_pct = null, SKIP step 3.7 (không ghi report)
```

> **Lưu ý:** PARTIAL_MATCH screens vẫn là business screens — KHÔNG loại khỏi mẫu số.
> Báo cáo cả 2 metric: `coverage_pct` (full match) và `partial_coverage_pct` (bao gồm partial).

---

**POST-GATE:**
```
T1: test -f $SESSION_DIR/ui-coverage-report.md       (chỉ khi không SKIP)
T2: grep -q "^#" $SESSION_DIR/ui-coverage-report.md  (có heading)
T3: test $(wc -w < $SESSION_DIR/ui-coverage-report.md) -ge 100  (có nội dung)
```

> Nếu Phase 3 SKIP toàn bộ (api-only / no UI / empty_project): bỏ qua POST-GATE T1-T3, set `$UI_COVERAGE_DATA = null`. Phase 6 sẽ bỏ qua section UI coverage trong report.

**NEXT:** Nếu `--fix` → Load `phase4-fix.md`. Ngược lại → Load `phase5-crossval.md`.
