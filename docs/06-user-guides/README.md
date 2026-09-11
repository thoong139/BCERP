# 06 — User Guides

> **Mục đích:** Tài liệu hướng dẫn **dành cho end-user** (người không kỹ thuật) muốn dùng DEVKIT để biến ý tưởng thành phần mềm hoàn chỉnh.
> **Ngôn ngữ:** 100% tiếng Việt.

---

## 1. Đọc theo persona

| Bạn là ai? | Đọc trước |
|-----------|-----------|
| **Người không kỹ thuật, muốn bắt đầu dự án mới** | [`huong-dan-su-dung.md`](huong-dan-su-dung.md) |
| **Đã hiểu workflow, cần tổng quan các phase** | [`devkit-workflow-overview.md`](devkit-workflow-overview.md) |
| **Đang dùng một skill cụ thể, cần hướng dẫn chi tiết** | [`per-skill/`](per-skill/) |

---

## 2. Files trong folder

### Tổng quan (2 files)

| File | Mục đích | Độ dài |
|------|----------|--------|
| [`huong-dan-su-dung.md`](huong-dan-su-dung.md) | End-to-end flow — idea → deployment, không cần biết code | Đầy đủ |
| [`devkit-workflow-overview.md`](devkit-workflow-overview.md) | Tóm tắt 7 phases workflow, 3 paths (STANDARD/EXISTING/HYBRID) | Trung bình |

### Per-skill manuals — [`per-skill/`](per-skill/)

| File | Skill | Trạng thái |
|------|-------|-----------|
| [`per-skill/wf-fix-bugs-huong-dan.md`](per-skill/wf-fix-bugs-huong-dan.md) | wf-fix-bugs | ✅ Full guide |
| [`per-skill/wf-legacy-scan-v5-guide.md`](per-skill/wf-legacy-scan-v5-guide.md) | wf-legacy-scan v5 | ✅ Full guide |

**Còn thiếu:** wf-brainstorm, wf-analyze-requirements, wf-implement-feature, wf-preflight, ... Sẽ bổ sung theo yêu cầu user.

---

## 3. Khi viết user guide mới

**Nguyên tắc cốt lõi (BHV-001 + BHV-002):**
- Viết cho người **không kỹ thuật** — KHÔNG dùng jargon (REQ-ID, POST-GATE, atomic write) ở phần đầu
- Mỗi step có **ví dụ thực tế** (screenshot CLI output, sample dialog)
- Câu hỏi "Khi nào dùng skill này?" phải trả lời ở 5 dòng đầu
- Có **happy path** dài + **troubleshooting** section riêng cho edge cases

**Cấu trúc đề xuất:**

```markdown
# {Skill display name} — Hướng dẫn sử dụng

## 1. Khi nào dùng skill này?
{5-10 dòng, có ví dụ tình huống cụ thể}

## 2. Trước khi chạy (chuẩn bị)
{Pre-requisites: dự án phải có gì? đã chạy skill nào chưa?}

## 3. Chạy như thế nào
### 3.1. Lệnh đơn giản nhất
### 3.2. Các tùy chọn thường dùng
### 3.3. Ví dụ output

## 4. Hiểu kết quả
{Đọc output files ở đâu, ý nghĩa từng phần}

## 5. Troubleshooting
{Lỗi thường gặp + cách xử lý}

## 6. Câu hỏi thường gặp (FAQ)
```

---

## 4. Liên kết

- **Kiến trúc DEVKIT (cho developer):** [`../01-architecture/`](../01-architecture/)
- **Catalog skills:** [`../01-architecture/07-skills-catalog.md`](../01-architecture/07-skills-catalog.md)
- **Vận hành & runbooks:** [`../07-operations/`](../07-operations/)
- **Cheatsheets:** [`../08-reference/`](../08-reference/)
