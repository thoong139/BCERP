# Shared Protocols — audit-devkit-fix

> Cross-cutting protocols, rules và error codes được dùng bởi nhiều Phase của skill.
> **KHÔNG đọc file này standalone** — chỉ load section cụ thể khi cần.

## Sections

- [Execution Strategy](#execution-strategy)
- [Fix Rules (Error Handling)](#fix-rules-error-handling)
- [Auto-Fix Limits (BẮT BUỘC)](#auto-fix-limits-bắt-buộc)
- [False Positive Recognition](#false-positive-recognition)
- [Fix Pattern → Priority Lookup](#fix-pattern--priority-lookup)
- [Error Codes](#error-codes)

---

## Execution Strategy

| Condition | Mode |
|-----------|------|
| Phase 0 (load + sort) | **SEQUENTIAL** — phải hoàn thành trước khi fix |
| Phase 1 (per-fix loop) | **SEQUENTIAL** — mỗi fix phải verify xong mới tiếp tục |
| Phase 2 (re-scan) | **PARALLEL** — agent-auditor + skill-auditor cho changed files đồng thời |
| Phase 3 (report) | **SEQUENTIAL** — cần tất cả data trước |

---

## Fix Rules (Error Handling)

| Error Type | Auto-Fix Strategy | Escalate If |
|-----------|-------------------|-------------|
| Verified result JSON invalid | Re-read + validate. Nếu corrupt → yêu cầu re-run verify | Parse fail sau 3 lần |
| File bị lock/permission denied | Retry 3 lần với delay | Vẫn fail → skip finding + WARNING |
| Edit conflict (old_string không tìm thấy) | Re-read file, tìm context mới | Content đã thay đổi quá nhiều → MANUAL |
| Revert fail (cannot restore original) | Log CRITICAL warning + stop processing file | Ngay lập tức |
| Agent timeout trong re-scan | Re-spawn 1 lần | Fail lần 2 → skip re-scan + WARNING |
| Agent trả text thay vì JSON | Fallback parse: extract JSON từ text | Parse fail → log raw + skip |

---

## Auto-Fix Limits (BẮT BUỘC)

```
AUTO-FIX ĐƯỢC PHÉP:
  ✓ Sửa text/content trong file hiện có (Edit)
  ✓ Cập nhật paths, names, references
  ✓ Sửa frontmatter fields
  ✓ Thay thế deprecated names/terminology
  ✓ Sửa SKILL.md structural: thêm PRE-GATE/POST-GATE markers, steps, error codes (FP7)
  ✓ Sửa agent structural: thêm/đổi section headers (FP8)
  ✓ Cập nhật documentation text: counts, descriptions, cross-refs (FP9)

AUTO-FIX KHÔNG ĐƯỢC PHÉP:
  ✗ Tạo file mới (Write file chưa tồn tại) — trừ FP3 exception
  ✗ Xóa file
  ✗ Thay đổi cấu trúc thư mục
  ✗ Fix manual findings (giữ nguyên — user phải xác nhận)

Vi phạm bất kỳ giới hạn nào → move finding sang MANUAL list.
```

**NGOẠI LỆ — FP3 (Digest Templates):** Được phép dùng `Write` để tạo digest template files
trong `.claude/doc-framework/_digests/` NẾU:
- (a) File chưa tồn tại
- (b) Nội dung được tạo hoàn toàn từ chuẩn trong Master Plan Section 4.3
- (c) User đã confirm (HIGH-RISK prompt bắt buộc trước khi apply)

---

## False Positive Recognition

Khi Phase 0 hoặc Phase 1 phát hiện finding có thể là false positive, áp dụng các check dưới đây trước khi fix. Nếu match → move finding sang SKIPPED (ghi lý do rõ ràng vào `fix-log.json`).

| Tình huống FP | Dấu hiệu nhận biết | Hành động |
|--------------|-------------------|-----------|
| **Stale finding** | File tồn tại và đúng content, nhưng scan dùng cached state từ session cũ | Re-read file thực tế → nếu issue không còn → SKIP, log `stale: true` |
| **Description mismatch** | Mô tả finding nói "X bị thiếu" nhưng thực tế file có X với tên/format khác | Kiểm tra bằng Grep với pattern linh hoạt hơn → nếu tìm thấy → SKIP, log `reason: description_mismatch` |
| **Auto-fixed already** | Finding có `fix_type=AUTO` nhưng fix đã được apply trong session trước | Kiểm tra file modified time vs finding created time → nếu file mới hơn → SKIP, log `reason: already_fixed` |
| **Scope mismatch** | Finding chỉ ra file trong `.mc-data/` nhưng đó là runtime data (không phải DEVKIT component) | Xác nhận path → nếu là runtime data → SKIP, log `reason: out_of_scope` |

> **Nguyên tắc:** Khi nghi ngờ false positive, ưu tiên READ file thực tế trước khi fix. Fix sai còn nguy hiểm hơn bỏ sót.

---

## Fix Pattern → Priority Lookup

Khi Phase 0 sort findings theo dependency order, áp dụng priority sau cho Master Plan findings:

| Pattern | Priority | Lý do |
|---------|---------|-------|
| FP9 (Doc Count Sync) | Priority 2 (Naming) | Text fix đơn giản, chạy sau structural |
| FP7 (SKILL.md Structural) | Priority 1 (Structural) | Skill structure phải đúng trước khi naming |
| FP8 (Agent Section Fix) | Priority 1 (Structural) | Agent structure phải đúng |
| FP2 (Checkpoint Schema) | Priority 1 (Structural) | Schema phải đúng trước khi skill dùng nó |
| FP5 (Task Template A6/A7) | Priority 1 (Structural) | Template là foundation cho generated content |
| FP1 (Hook 2-Tầng) | Priority 1 (Structural) | Hook phải đúng trước khi validate file writes |
| FP3 (Digest Templates) | Priority 1 (Structural) | Templates phải tồn tại trước khi PRODUCER chạy |
| FP4 (Skill Digest Steps) | Priority 1 (Structural) | Skill steps phải đúng sau khi templates đã có |
| FP6 (Parallel Flags) | Priority 1 (Structural) | Documentation phải đúng trước khi feature dùng |

### Dependency Order — Tại sao quan trọng

```
Structural PHẢI fix trước vì:
  → Naming fix có thể phụ thuộc vào frontmatter đã đúng
  → Reference fix cần file structure ổn định
  → Deprecated name fix cần biết tên hiện tại đã chuẩn

Ví dụ:
  1. Fix frontmatter thiếu "name" field (structural)
  2. Fix "name" value không khớp filename (naming)
  3. Fix skill reference sai agent path (reference)
  4. Fix deprecated agent/skill name → tên hiện tại (deprecated/standardization)
```

---

## Error Codes

> **Error code prefix:** FIX- (VD: FIX-E001, FIX-E002). Dùng khi log/display để phân biệt với errors từ scan/verify/orchestrator.

| Code | Situation | Action |
|------|-----------|--------|
| E001 | PRE-GATE fail — `audit-verified-result.json` không tồn tại | STOP — chạy `/audit-devkit-verify` trước |
| E001b | **Verify-complete gate:** `verify-status.json` báo `status: "in_progress"` hoặc không tồn tại | WARNING + hỏi user confirm trước khi tiếp tục. Log warning vào fix-log.json |
| E002 | PRE-GATE fail — `audit-index.json` không tồn tại | STOP — chạy `/audit-devkit-scan` trước |
| E003 | `audit-verified-result.json` JSON invalid | Retry read 3 lần. Nếu vẫn invalid → STOP, yêu cầu re-run verify |
| E004 | Revert fail — không thể restore file về original content | CRITICAL WARNING — STOP processing file này. Log chi tiết. User phải kiểm tra thủ công |
| E005 | File permission denied / file locked | Retry 3 lần. Nếu vẫn fail → skip finding + WARNING |
| E006 | Edit conflict — old_string không tìm thấy trong file | Re-read file. Nếu content đã thay đổi (bởi fix trước) → recalculate. Nếu vẫn fail → MANUAL |
| E007 | Agent timeout / không trả output trong re-scan | Re-spawn agent 1 lần. Fail lần 2 → skip re-scan cho batch đó + WARNING |
| E008 | Agent trả text thay vì JSON trong re-scan | Fallback parse: extract JSON từ text. Nếu fail → log raw text + skip |
| E009 | `fix-log.json` write fail | Retry 3 lần, sau đó escalate to user |
| E010 | Verify report không tồn tại tại `.mc-data/work/audit-devkit-verify/reports/` | Tạo report mới tại `.mc-data/work/audit-devkit-fix/reports/` mà không cần context từ verify report |
| E011 | Resume: `fix-status.json` corrupt | Rebuild status từ existing `fix-log.json` (nếu có) |
| E012 | Regression detected trong re-scan | Log WARNING + hiển thị chi tiết. KHÔNG revert (quá phức tạp) |
| E013 | Grep toàn bộ `.claude/` timeout (Phase 1 Step 1.10) | Fallback: grep từng subdirectory riêng (`.claude/agents/`, `.claude/skills/`, `.claude/references/`) tuần tự |
| E014 | Revert fail (Phase 1 Step 1.13) — file bị lock hoặc không thể restore về `original_content` | CRITICAL STOP — log đường dẫn file + `original_content`. Dừng xử lý file này. User phải kiểm tra và restore thủ công |

---

## Context & Checkpoint

| Context Usage | Hành động |
|---------------|-----------|
| < 65% | Tiếp tục bình thường |
| 65-80% | Chuẩn bị checkpoint — log progress vào `fix-status.json` |
| 80-90% | Lưu checkpoint ngay — write partial `fix-log.json` |
| > 90% | FORCE STOP — checkpoint bắt buộc, write tất cả data |

### Resume Process

1. READ `fix-status.json` từ `.mc-data/work/audit-devkit-fix/[session-id]/`
2. LOAD `audit-verified-result.json` + `audit-index.json`
3. LOAD partial `fix-log.json` (nếu có) — biết findings nào đã processed
4. CONTINUE từ finding tiếp theo chưa processed trong `fix_queue`
