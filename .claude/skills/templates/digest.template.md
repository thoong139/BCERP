<!-- Standalone template extracted from shared-protocols.md §6.4 (lines 379-397) -->
# Digest Template — Large Doc Analysis Pattern

> Sử dụng cho Protocol 6.4 (Large Doc Analysis Pattern). Khi spawn agent cần đọc >5 files,
> main conversation pre-compress mỗi file thành digest theo template này.

---

## Tier chọn theo độ phức tạp doc

| Doc Size | Digest Target | Format |
|----------|--------------|--------|
| < 1000 từ | ~150 từ/file | Standard (rút gọn) |
| 1000–3000 từ | ~200 từ/file | **Standard** |
| > 3000 từ HOẶC Large Project Mode | ~300 từ/file | **Extended** |

---

## Standard Digest Format (~200 từ)

```markdown
## Digest: [name]
- REQ-IDs: REQ-[X]-001 (Bắt buộc), REQ-[X]-002 (Quan trọng), ...
- Quy trình chính: [tên QT-1], [tên QT-2], [tên QT-3]
- Điểm giao với depts khác: [dept-a] (gửi đi), [dept-b] (nhận về)
- Vấn đề nổi bật: [bullet 1-2 câu]
- Nguồn: [file path]
```

**Khi populate:**
- `[name]` → tên dept hoặc tên doc
- `REQ-IDs` → list REQ-IDs có trong file kèm priority (Bắt buộc/Quan trọng/Tùy chọn)
- `Quy trình chính` → 2-4 quy trình quan trọng nhất, chỉ tên không mô tả chi tiết
- `Điểm giao` → list inter-dept dependencies (gửi/nhận)
- `Vấn đề nổi bật` → 1-2 issues cần lưu ý (gaps, conflicts, risks)
- `Nguồn` → đường dẫn file gốc để agent reference khi cần xác nhận

---

## Extended Digest Format (~300 từ — Large Project Mode hoặc docs >3000 từ)

```markdown
## Digest: [name] — Extended
- REQ-IDs: REQ-[X]-001 (BẮT BUỘC), REQ-[X]-002 (QUAN TRỌNG), ... [kèm priority]
- Quy trình chính: [QT-1 (~N bước, mô tả ngắn)], [QT-2], [QT-3]
- Điểm giao: [dept-a → gửi X, trigger Y], [dept-b → nhận Z, phụ thuộc W]
- Constraints: [compliance rules, data invariants, performance SLAs nếu có]
- Vấn đề nổi bật: [Issue 1 (Critical/High)], [Issue 2 (Medium)]
- Tech implications: [external APIs, integration points, system dependencies]
- Nguồn: [file path]
```

**Field bổ sung so với Standard:**
- `Constraints` → compliance/regulation rules, business invariants, NFRs (performance, security, availability)
- `Tech implications` → external dependencies (APIs, third-party services), integration touchpoints

---

## Khi nào dùng template này

- Phase 6b (Cross-dept workflow) khi >5 dept files
- Phase 6c (Stakeholder review) khi >5 dept files
- Bất kỳ stakeholder review nào đọc nhiều docs
- Chi tiết trigger conditions: `.claude/skills/protocols/06-token-limit.md` §6.4
