# Phase 5: Existing Docs Integration (CONDITIONAL)

> Chỉ chạy khi `$HAS_EXISTING_DOCS = true` (từ Phase 1 Step 1.5).
> Merge nội dung từ existing docs vào dept docs đã tạo.

**PRE-GATE:**
```bash
test "$HAS_EXISTING_DOCS" = "true"
```

> Nếu `$HAS_EXISTING_DOCS != true` → SKIP phase này, tiếp tục Phase 6.

**INPUT:** `doc-mapping.json` + `onboard-report-*.md` + existing docs + tất cả `[dept].md` files

**OUTPUT:** Tất cả `[dept].md` files UPDATED (merged)

## Steps

| Step | Action | Verify |
| ---- | ------ | ------ |
| 5.1  | Scan existing docs (đọc `.mc-data/work/legacy-scan/doc-mapping.json`) | Docs found |
| 5.2  | Phân loại document types | Types identified |
| 5.3  | Map sang DEVKIT format | Mapping complete |
| 5.4  | Merge với expert findings (cập nhật dept docs) | No data loss |

**POST-GATE:** Tất cả existing docs đã được mapped/merged HOẶC phase skipped (nếu không có docs)

**Status update:** `analyze-status.json` → `phase_5.status = "completed"` hoặc `"skipped"`.

**Next phase:** `phase6-consolidate.md`
