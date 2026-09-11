# Phase 4: Handle --fix (CONDITIONAL)

> Cũ Phase 6. CHỈ chạy khi `$HAS_FIX_FLAG = true` (`--fix`).
> Auto-add REQ-ID comment vào orphan code files + suggest W001 fixes.

> **CHECKPOINT trước Phase 4:** save gaps data + W001 list. `--fix` sẽ modify nhiều files — checkpoint đảm bảo rollback nếu cần.

**PRE-GATE:**
- `test "$HAS_FIX_FLAG" = "true"` — nếu false → SKIP toàn bộ Phase 4
- Phase 2 (`phase2-analyze.md`) POST-GATE PASS
- `test -n "$GAPS_LIST"` HOẶC `test -n "$W001_ANOMALIES"` (cần ít nhất 1 nhóm để fix)

**📥 INPUT:**
- Orphan source files (từ `$GAPS_LIST` entries có `type="orphan_code"`)
- W001 anomalies (từ `$W001_ANOMALIES`)
- Registry (tra cứu REQ-ID phù hợp + module mapping)

**📤 OUTPUT:**
- Source files (modified — thêm REQ-ID comment header)
- `$FIX_LOG` (in-memory) — array `{file, action, req_id, before, after, classification?}`

> Phase này KHÔNG ghi file output riêng. Fix log được lưu in-memory và include trong Phase 6 report.

---

## Reference Sections

- `_shared/protocols-fix-rules.md`
- `_shared/registry-safe-write.md` (W001 logic)

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 4.1 | **Save checkpoint trước fix:** Cập nhật `$SESSION_DIR/checkpoint.json` với `data_snapshot.{gaps_list, w001_anomalies, orphan_list}` + `position.current_phase="phase_4_fix"`. Đồng thời **backup nội dung gốc** của mỗi orphan file sẽ bị modify: lưu danh sách `{file_path, original_first_line}` vào `$PRE_FIX_BACKUP` (in-memory) để rollback manual nếu E042 xảy ra. | Checkpoint saved, backup recorded |
| 4.1b | **Scope re-validation:** Verify mỗi file trong `$GAPS_LIST` (type=orphan_code) có đường dẫn nằm trong `$SCOPE_FILTER.modules` (nếu `$SCOPE != "all"`). Nếu file nằm ngoài scope → EXCLUDE khỏi fix list, log: "⚠️ Orphan [file] nằm ngoài scope [SCOPE/NAME] — bỏ qua fix." | Scope boundary enforced |
| 4.2 | **Phân loại orphan files trước khi fix:** Với mỗi orphan file trong `$GAPS_LIST` (type=orphan_code) thuộc scope: (a) **Pre-filter: File type safety check** — tra bảng extension → comment style (xem §Comment Style Map). Nếu extension thuộc `$CANNOT_COMMENT` (`.json`, `.jsonc`, `.lock`, `.min.*`, `.bundle.*`, `.map`, binary) → skip file, log: "⚠️ [file]: extension không hỗ trợ comment — bỏ qua auto-fix." (b) Nếu file nằm trong `utils/`, `shared/`, `common/`, `lib/`, `helpers/`, `hooks/`, `constants/` → flag `shared_utility=true`, thêm vào `$SHARED_UTILITY_PENDING` list — **KHÔNG tiếp tục auto-fix cho file này**. (c) Nếu không → suggest REQ-ID từ registry bằng fuzzy match module path, thêm vào `$AUTO_FIX_QUEUE` | Files classified, unsafe extensions excluded |
| 4.2a | **User confirmation cho shared utility files:** Nếu `$SHARED_UTILITY_PENDING` non-empty → Hiển thị list cho user: "⚠️ [N] shared utility files cần REQ-ID assignment thủ công (không auto-assign vì semantic không rõ ràng): [danh sách files + suggested REQ-IDs từ registry]. Vui lòng xác nhận REQ-ID cho từng file, hoặc bỏ qua." CHỜ user response → Ghi confirmed files vào `$CONFIRMED_SHARED_UTILS`. Files không confirm → ghi vào `$SKIPPED_MANUAL_REVIEW`. | User confirmed or skipped |
| 4.3 | **W001 classification và confirmation:** Với mỗi REQ-ID trong `$W001_ANOMALIES`: (a) Detect comment format từ file extension theo bảng §Comment Style Map. (b) Fuzzy match `module_id` → candidate source file. (c) **Phân loại:** `format_mismatch` (REQ-ID có nhưng format khác chuẩn) / `code_refactored` (file đổi tên/di chuyển) / `genuine_missing` (code thực sự không có). (d) Với `genuine_missing` → KHÔNG thêm vào fix queue, log W001 + báo user "code thực sự thiếu, cần `/wf-implement-feature`". (e) Với `format_mismatch` → thêm vào `$AUTO_FIX_QUEUE` (safe to auto-fix). (f) Với `code_refactored` → **bắt buộc user confirm:** "W001 [REQ-ID]: file gốc có thể đã được đổi tên/di chuyển. Candidate: [file]. Confirm để add comment, hoặc bỏ qua." CHỜ user response trước khi thêm vào `$AUTO_FIX_QUEUE`. | W001 classified, code_refactored confirmed |
| 4.4 | Add REQ-ID comment vào đầu file cho: (a) `$AUTO_FIX_QUEUE` (non-utility orphans + format_mismatch W001 + confirmed code_refactored W001), (b) `$CONFIRMED_SHARED_UTILS`. Với mỗi file: detect comment style từ extension theo bảng §Comment Style Map. **Chỉ auto-fix files có extension trong bảng mapping** — files có extension không rõ → skip với log "⚠️ [file]: unknown extension [ext] — bỏ qua auto-fix, cần xử lý thủ công." Push vào `$FIX_LOG`: `{file, action="add_req_id", req_id, classification?, shared_utility?}` | `grep "REQ-ID:" file` returns match |
| 4.5 | **Re-verify per file:** grep từng fixed file để confirm REQ-ID comment đã được thêm đúng format. Nếu fail → ghi vào `error_log[]` với type `auto_fix_regression` (E042). Log cả `$SKIPPED_MANUAL_REVIEW` entries vào `$FIX_LOG` với `action="skipped_manual_review"` | All fixed files verified |
| 4.6 | Nếu `error_log[]` có entry `auto_fix_regression` (E042) → STOP auto-fix, log: "⛔ Auto-fix regression tại [file]. Các files đã fix trước đó: [list từ $FIX_LOG]. Rollback manual: xóa dòng REQ-ID comment đầu tiên trong các files trên." Escalate to user. | No regression |

---

## Comment Style Map

> **BẮT BUỘC:** Mọi auto-fix comment injection PHẢI dùng đúng style từ bảng này. Extension không có trong bảng → KHÔNG auto-fix.

### Single-line `// ...`

| Extensions |
|-----------|
| `.ts`, `.tsx`, `.js`, `.jsx`, `.go`, `.java`, `.cs`, `.rs`, `.swift`, `.kt`, `.kts`, `.scala`, `.dart`, `.cpp`, `.c`, `.h`, `.hpp`, `.m`, `.mm` |

**Injection format:** `// REQ-ID: REQ-XXX-NNN`

### Hash `# ...`

| Extensions |
|-----------|
| `.py`, `.rb`, `.sh`, `.bash`, `.zsh`, `.fish`, `.pl`, `.pm`, `.r`, `.yaml`, `.yml`, `.toml`, `.cfg`, `.ini`, `.conf`, `.env*`, `Dockerfile`, `Makefile` |

**Injection format:** `# REQ-ID: REQ-XXX-NNN`

### Block `/* ... */`

| Extensions |
|-----------|
| `.css`, `.scss`, `.less`, `.sass` |

**Injection format:** `/* REQ-ID: REQ-XXX-NNN */`

### SQL `-- ...` hoặc `/* ... */`

| Extensions |
|-----------|
| `.sql` |

**Injection format:** `-- REQ-ID: REQ-XXX-NNN`

### XML/HTML `<!-- ... -->`

| Extensions |
|-----------|
| `.xml`, `.csproj`, `.vbproj`, `.xaml`, `.axml`, `.svg`, `.html`, `.htm`, `.cshtml`, `.md`, `.mdx`, `.props`, `.targets`, `.resx`, `.config` (XML-based), `.fxml` |

**Injection format:** `<!-- REQ-ID: REQ-XXX-NNN -->`

### CANNOT COMMENT — TUYỆT ĐỐI KHÔNG auto-fix

| Extensions | Lý do |
|-----------|-------|
| `.json`, `.jsonc`, `.jsonl` | JSON không hỗ trợ comment (`.jsonc` có nhưng fragile) |
| `.lock`, `.min.js`, `.min.css`, `.bundle.*` | Generated/minified |
| `.d.ts`, `.d.cts`, `.d.mts` | Declaration files |
| `.map`, `.js.map`, `.css.map` | Source maps |
| `.png`, `.jpg`, `.jpeg`, `.gif`, `.ico`, `.woff`, `.woff2`, `.ttf`, `.eot`, `.pdf`, `.zip`, `.tar`, `.gz`, `.mp4`, `.webm`, `.exe`, `.dll`, `.so`, `.dylib` | Binary files |
| `.pb.ts`, `*_pb.ts`, `*_grpc_pb.ts` | Generated protobuf |

### Unknown Extensions — KHÔNG auto-fix

Bất kỳ extension nào không nằm trong các bảng trên → skip + log WARNING: "⚠️ [file]: unknown extension [ext] — bỏ qua auto-fix, cần xử lý thủ công."

---

## Ví dụ fix

**TypeScript:**
```typescript
// REQ-ID: REQ-FIN-001
export class ChartOfAccountsService { ... }
```

**Python:**
```python
# REQ-ID: REQ-FIN-001
def calculate_ledger():
    pass
```

**C# (.cs file, KHÔNG phải .csproj):**
```csharp
// REQ-ID: REQ-FIN-001
public class LedgerService { ... }
```

**XML (.csproj, .config, etc.):**
```xml
<!-- REQ-ID: REQ-FIN-001 -->
<Project Sdk="Microsoft.NET.Sdk">
```

---

## W001 Classification

| Classification | Triệu chứng | Suggested Fix |
|----------------|-------------|---------------|
| `format_mismatch` | File chứa REQ-ID nhưng format khác chuẩn (vd `// REQID: X` thay vì `// REQ-ID: X`) | Update comment về format chuẩn |
| `code_refactored` | File gốc đã rename/move; tìm thấy candidate qua fuzzy match | Suggest user xác nhận candidate file rồi add comment |
| `genuine_missing` | Module không có code nào liên quan đến REQ-ID | KHÔNG add comment — báo user code thực sự thiếu, có thể cần chạy `/wf-implement-feature` |

---

**POST-GATE:**
- `$HAS_FIX_FLAG != "true"` → SKIP gate (Phase 4 không chạy)
- `$HAS_FIX_FLAG == "true"`:
  - `$FIX_LOG` phải được defined (có thể là empty array `[]` nếu không có gì để fix — không fail)
  - Không có entry `auto_fix_regression` trong `error_log[]`
  - Nếu có `$SHARED_UTILITY_PENDING` non-empty: verify user đã confirm hoặc skip từng file (không còn "pending" state)
- Cập nhật `verify-sync-status.json`: `phases.phase_4.status="completed"`, `phases.phase_4.files_fixed=count($FIX_LOG where action="add_req_id")`, `phases.phase_4.files_skipped_manual=count($SKIPPED_MANUAL_REVIEW)`, `phases.phase_4.w001_genuine_missing=count(W001 genuine_missing entries)`

**NEXT:** Load `phase5-crossval.md`.
