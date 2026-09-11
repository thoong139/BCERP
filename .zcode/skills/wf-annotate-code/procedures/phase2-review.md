# Phase 2: Review & Confirm

> Hiển thị annotation map cho user, cho phép điều chỉnh mapping, xử lý `--dry-run` exit.
> **KHÔNG chỉnh sửa code** trong phase này — chỉ update annotation-map.json theo quyết định user.

**PRE-GATE:**
- [ ] Phase 1 POST-GATE PASS (`annotation-map.json` non-empty, schema valid)
- [ ] `$ANNOTATION_MAP` đã load trong memory

**INPUT:**
- `.mc-data/work/legacy-scan/annotation-map.json` (từ Phase 1)
- `$DRY_RUN` (in-memory)

**OUTPUT:**
- `.mc-data/work/legacy-scan/annotation-map.json` (updated sau user confirm)
- In-memory: `$USER_CONFIRMED_MAP`
- **Nếu `$DRY_RUN = true`:** `annotation-report.md` (dry-run preview variant) + skill EXIT

---

## Reference Sections

- `_shared.md` §State Variables Glossary

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 2.1 | Hiển thị annotation map cho user theo table format | Output | Displayed |
| 2.2 | Hiển thị summary: total files, unique REQ-IDs, modules affected, confidence breakdown (high/medium/low) | Output | Summary shown |
| 2.3 | **[USER REVIEW]** AskUserQuestion: "Có muốn điều chỉnh mapping không?" → options: `[APPROVE_ALL, ADJUST, SKIP_LOW_CONFIDENCE, CANCEL]` | AskUserQuestion | User answered |
| 2.4 | Xử lý theo lựa chọn user (xem §Decision Matrix) | Edit/Write | Map adjusted |
| 2.5 | **[DRY-RUN BRANCH]** Nếu `$DRY_RUN = true`: xem §Dry-Run Exit, STOP skill | Write | Dry-run report created |
| 2.6 | GHI `annotation-map.json` với final confirmed mappings (thêm `user_confirmed: true`, `confirmed_at: ISO_DATE`) | Write | Map updated |
| 2.7 | Set `$USER_CONFIRMED_MAP` = loaded map (in-memory) | — | Map cached |
| 2.8 | Cập nhật `annotate-status.json`: `phases.phase_2.status = "completed"`, `phases.phase_2.user_decision`, `phases.phase_2.adjustments_count` | Edit | Status updated |

---

## Display Format (Step 2.1)

```
## Annotation Map — [total] files

| # | File | REQ-IDs | FEAT-ID | Confidence | Module |
|---|------|---------|---------|------------|--------|
| 1 | src/Services/CustomerService.cs | REQ-SALES-001, REQ-SALES-002 | FEAT-ERP-CRM-001 | high | customer-management |
| 2 | src/Controllers/OrderController.cs | REQ-SALES-010 | FEAT-ERP-ORD-001 | medium | order-processing |
| ... |

## Summary
- Total files: [N]
- Unique REQ-IDs: [N]
- Unique FEAT-IDs: [N]
- Modules: [list]
- Confidence: high=[N], medium=[N], low=[N]
- Deprecated modules skipped: [list]
- Unsupported languages skipped: [count]
```

---

## Decision Matrix (Step 2.4)

| User chọn | Hành động |
|-----------|-----------|
| `APPROVE_ALL` | Không thay đổi map, tiếp tục Step 2.5 |
| `ADJUST` | AskUserQuestion detail: "Files nào cần đổi/remove? Format: `file_path → new_req_ids` hoặc `file_path → REMOVE`". Parse user input, update map in-memory, display lại (loop tối đa 3 vòng), sau đó confirm `APPROVE_ADJUSTED` |
| `SKIP_LOW_CONFIDENCE` | Loại mọi entry có `confidence = "low"` khỏi map. Log số entries removed. |
| `CANCEL` | Update `annotate-status.json.status = "cancelled"`, cleanup checkpoint. STOP skill với message "Annotate cancelled theo yêu cầu user." |

---

## Dry-Run Exit (Step 2.5)

Nếu `$DRY_RUN = true`:

```
(1) READ template templates/annotation-report.md
(2) POPULATE với banner:
    # DRY-RUN: NO FILES MODIFIED
    
    > Đây là preview. Chưa có code file nào thay đổi.
    > Chạy lại không có --dry-run để thực thi annotation.
(3) POPULATE:
    - Summary counts (files SẼ annotate, REQ-IDs SẼ inject)
    - Module breakdown
    - Traceability score (current baseline + projected)
    - Planned diffs per file (pseudo-diff format):
        [file_path]
        + [comment REQ-ID/FEAT-ID theo format language]
        [next 3 lines of original code]
(4) WRITE .mc-data/work/legacy-scan/annotation-report.md
(5) Cập nhật annotate-status.json:
    - status = "dry_run_completed"
    - phases.phase_2.status = "completed"
    - phases.phase_3.status = "skipped"
    - phases.phase_4.status = "skipped"
(6) CORE-026: Append DRY_RUN_COMPLETE event vào session-log.json
(7) Hiển thị:
    "Dry-run hoàn tất. Xem .mc-data/work/legacy-scan/annotation-report.md.
     Chạy lại không có --dry-run để thực thi."
(8) STOP skill — KHÔNG chuyển Phase 3
```

---

## POST-GATE

- [ ] `annotation-map.json` có `user_confirmed: true` và `confirmed_at` populated
- [ ] `$USER_CONFIRMED_MAP` loaded in-memory
- [ ] `annotate-status.json.phases.phase_2.status = "completed"` (hoặc `cancelled`/`dry_run_completed`)
- [ ] Nếu `$DRY_RUN = true` → skill đã STOP với `annotation-report.md` dry-run variant

**Next phase:**
- Nếu `$DRY_RUN = true` → SKILL EXIT
- Nếu user chọn `CANCEL` → SKILL EXIT
- Ngược lại → `phase3-inject.md`
