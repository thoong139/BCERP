# Phase 3.5: Naming Normalization (CHỈ LEGACY_MODE — OPTIONAL)

> NOTE: Producer của `classify-naming-fixes.json` là `/wf-legacy-classify` (Phase 5/6). Nếu classify không produce file (do không detect conflict) → phase này SKIP, KHÔNG FAIL.
> Phase này VERIFY và apply các fix còn lại vào Phase 1 docs.
>
> **Gate:** CHỈ chạy khi `$LEGACY_MODE = true` VÀ file fixes tồn tại non-empty. Các trường hợp khác → SKIP, tiếp tục Phase 4.

**PRE-GATE (soft):**

```bash
# Bắt buộc: LEGACY_MODE = true
test "$LEGACY_MODE" = "true" || { echo "SKIP — not LEGACY"; exit 0; }

# Optional: file tồn tại + non-empty + có ít nhất 1 fix
FIX_FILE=".mc-data/work/legacy-scan/classify-naming-fixes.json"
if ! test -s "$FIX_FILE"; then
  echo "SKIP — classify-naming-fixes.json không có (wf-legacy-classify không detect naming conflict)"
  # set phase_3_5.status = "skipped_no_fixes"
  exit 0
fi

if ! jq -e '.fixes | length > 0' "$FIX_FILE" >/dev/null 2>&1; then
  echo "SKIP — classify-naming-fixes.json rỗng (không có fix nào cần apply)"
  exit 0
fi
```

> **Không FAIL khi file vắng** — file chỉ được produce khi `/wf-legacy-classify` detect naming conflicts. Nhiều legacy projects không có conflict → đây là đường happy path.

**INPUT:** `classify-naming-fixes.json` (optional) + tất cả `[dept].md` files từ Phase 3

**OUTPUT:** `[dept].md` files UPDATED (nếu có fix) + `.mc-data/work/legacy-scan/naming-normalization-log.md`

## Steps

| Step | Action | Verify |
| ---- | ------ | ------ |
| 3.5.1 | Đọc `classify-naming-fixes.json` từ `.mc-data/work/legacy-scan/` | File loaded |
| 3.5.2 | Grep Phase 1 docs cho tên cũ (trước khi fix) | Old names found |
| 3.5.3 | Replace với tên canonical (kebab-case) | Names replaced |
| 3.5.4 | Log changes vào `.mc-data/work/legacy-scan/naming-normalization-log.md` | Log created |
| 3.5.5 | Chỉ hỏi user nếu có variant không rõ ràng (> 2 lựa chọn) | User consulted if needed |

**POST-GATE:**

```
Tất cả naming fixes đã applied HOẶC logged as skipped.
naming-normalization-log.md tồn tại (nếu phase chạy), hoặc status = "skipped_no_fixes" / "skipped_not_legacy".
```

**Status update:** `analyze-status.json` → `phase_3_5.status`:
- `"completed"` khi có fixes applied
- `"skipped_no_fixes"` khi LEGACY nhưng không có file/fixes
- `"skipped_not_legacy"` khi standard mode

**Next phase:** `phase4-experts-partb.md`
