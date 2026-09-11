# 10 — Language Policy (BẮT BUỘC)

> **Mức độ ràng buộc:** BẮT BUỘC (CORE-005, CORE-028)
> **File gốc canonical:** [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §5, [`.claude/rules/00-behavioral.md`](../../.claude/rules/00-behavioral.md)
> **Mục đích:** Quy định ngôn ngữ sử dụng — Tiếng Việt cho user-facing, English cho code identifiers — và quy ước trộn ngôn ngữ

---

## 1. Triết lý — tại sao quy định language?

Output MCV3 phục vụ 2 đối tượng:
1. **Người không chuyên** (doanh nghiệp Việt Nam) — đọc docs, phase reports để vận hành
2. **AI Claude Code + developer** — đọc code, contract, schema để phát triển tiếp

Nếu trộn lung tung:
- User Việt thấy `"FAILED: POST-GATE T3 cross-reference mismatch"` → không hiểu, mất tin tưởng
- Developer thấy biến `khách_hàng` với dấu → break IDE autocomplete, không cross-platform an toàn
- Skill này doc tiếng Anh, skill khác doc tiếng Việt → inconsistent

CORE-005 chốt: **mỗi loại content có ngôn ngữ chính**.

---

## 2. Bảng phân loại ngôn ngữ

| Loại content | Ngôn ngữ | Lý do |
|--------------|---------|-------|
| **User-facing** | | |
| Tài liệu `.md` trong `docs/`, `.mc-data/docs/` | **Tiếng Việt** | Đối tượng đọc là doanh nghiệp VN |
| Phase reports (`Phase{N}-report.md`) | **Tiếng Việt** | CORE-028 — ≤15 dòng cho người không chuyên |
| User messages (CDG, errors) | **Tiếng Việt** | User cần hiểu để confirm/reject |
| Error descriptions trong `_contract.json` | **Tiếng Việt** | Hiển thị qua user message khi error xảy ra |
| README per skill | **Tiếng Việt** | Owner hiểu khi maintain |
| Stakeholder review docs | **Tiếng Việt** | Stakeholder VN review |
| **Code identifiers** | | |
| Variable names | **English** hoặc Vietnamese không dấu | IDE autocomplete + cross-platform |
| Function names | **English** | Convention quốc tế |
| File names | **English lowercase-kebab** | OS portable |
| Folder names | **English lowercase-kebab** | OS portable |
| Class names | **English PascalCase** | Convention language |
| **Code comments** | | |
| Inline explanation (nghiệp vụ) | **Tiếng Việt** | Đối tượng đọc đa số là VN dev |
| REQ-ID trace comments | **Format chuẩn** (UPPERCASE) | Audit tool yêu cầu |
| TODO/FIXME/NOTE markers | **Tiếng Việt hoặc English** | Tùy team |
| Docstring (Python, JSDoc) | **Tiếng Việt** | Hiển thị qua tooltip |
| **Schema + API** | | |
| JSON keys, schema fields | **English** | Convention industry |
| Enum values trong schema | **English snake_case** hoặc **English lowercase** | Vd: `"not_started"`, `"in_progress"` |
| Status enum (vd: `impl_status`) | **English** | CORE-010 chốt 4 giá trị English |
| **Tooling** | | |
| Bash script comments | **Tiếng Việt hoặc English** | Tùy team |
| Bash error messages | **Tiếng Việt** | User thấy khi script fail |
| CLI help text (`--help`) | **Tiếng Việt** | User đọc |
| Log messages (technical) | **English** | Standard tooling format |

---

## 3. Quy tắc trộn ngôn ngữ

### 3.1. Trong 1 file `.md`

```
✅ ĐÚNG:
  - Nội dung chính: Tiếng Việt
  - Code blocks: giữ nguyên (English nếu là code)
  - Path/file references: English lowercase-kebab
  - Acronym (CORE-001, REQ-ID, FEAT-ID): UPPERCASE giữ nguyên
  - Tên skill (`wf-fix-bugs`): kebab-case giữ nguyên

❌ SAI:
  - 50% tiếng Việt, 50% tiếng Anh xen kẽ ngẫu nhiên
  - "We use the AUTO-FIX strategy để retry"  ← lai tạp
```

### 3.2. Trong code file

```typescript
// REQ-ID: REQ-CRM-CUST-001        ← UPPERCASE format chuẩn
// FEAT-ID: FEAT-CRM-CUST-001

// Service quản lý khách hàng — soft-delete + audit trail
//   ↑ Comment nghiệp vụ: tiếng Việt
export class CustomerService {
  //                       ↑ Class name: English PascalCase

  async findById(id: string): Promise<Customer | null> {
    //          ↑ Function name + params: English camelCase

    // Filter ra customers chưa bị xóa (soft-delete)
    //   ↑ Comment: tiếng Việt
    return this.repo.findOne({ where: { id, deletedAt: null } });
  }
}
```

### 3.3. Trong JSON contract/schema

```json
{
  "$schema": "skill-contract-v1",
  "skill": "wf-fix-bugs",
  "description": "Mô tả tiếng Việt — what + for whom + key features",
  "outputs": {
    "working": [
      {
        "path": "$SESSION_DIR/fix-status.json",
        "notes": "SSOT pipeline state — Atomic Write pattern. Tiếng Việt OK trong notes."
      }
    ]
  },
  "errors": {
    "E001": {
      "code": "E001",
      "severity": "critical",
      "description": "POST-GATE fail sau 3 retries — DỪNG phase, escalate."
    }
  }
}
```

**Quy tắc:**
- Field keys: English (`description`, `outputs`, `path`)
- Field values dùng cho display: Tiếng Việt
- Enum values: English chuẩn (`critical`, `not_started`)
- Code references (path, schema name): English

---

## 4. Phase report (CORE-028) — bắt buộc tiếng Việt

```markdown
## Phase 4: Tìm lỗi — PASS

Thời gian: 2026-05-15T14:32:00+07:00

**Đã làm:** Quét 8 dimension (QD1-QD8) song song, phát hiện 12 vấn đề trong 5 modules.

**Kết quả:**
- 3 vấn đề nghiêm trọng (CRITICAL), 5 trung bình, 4 nhẹ
- File báo cáo: `phase4-find-bugs/Phase4-report.md`

**Tiếp theo:** Phân loại và triage vấn đề ở Phase 5.
```

**Quy tắc:**
- Tiếng Việt 100%, KHÔNG dùng jargon kỹ thuật thô
- "POST-GATE T3" → "Kiểm tra nội dung file"
- "AUTO-FIX retry 2 lần" → "Thử sửa tự động lần 2"
- "Lane dispatch 10 agents" → "Triển khai 10 chuyên gia ảo song song"
- Ngắn gọn ≤15 dòng

---

## 5. User-facing CDG message (Protocol 16 §16.4)

```
⚠️ AI dự định loại module "khach-hang-vip" khỏi dự án.

Lý do: Module được flagged DEPRECATE trong phase legacy scan.

Modules bị ảnh hưởng: customer-loyalty (depends on khach-hang-vip)
Yêu cầu liên quan sẽ bị xóa: 7 yêu cầu

Bạn có muốn loại module này không? (Có / Không)
```

**Quy tắc:**
- Tiếng Việt 100%
- KHÔNG jargon: dùng "loại module" thay "DEPRECATE module"
- Có context (lý do, modules affected) để user quyết định
- Câu hỏi cuối: lựa chọn rõ ràng "Có/Không" hoặc options đánh số

---

## 6. Vietnamese không dấu — khi nào dùng?

```
Khi:
  - File/folder names trong .mc-data/ → bỏ dấu (vd: "khach-hang" không phải "khách-hàng")
  - Slug trong path (vd: phase2-features/crm/quan-ly-khach-hang/...)
  - Variable names (vd: const khachHang = ...)
  - Session ID slug (vd: 2026-05-15-module-quan-ly-khach-hang-01)

Lý do:
  - Cross-platform safe (Windows/Linux/macOS encoding)
  - IDE autocomplete không lỗi
  - Git diff hiển thị đúng
  - Shell command không cần quote
```

**Quy tắc strip dấu:**
- `á/à/ả/ã/ạ → a`
- `é/è/ẻ/ẽ/ẹ → e`
- `í/ì/ỉ/ĩ/ị → i`
- `ó/ò/ỏ/õ/ọ → o`
- `ú/ù/ủ/ũ/ụ → u`
- `ý/ỳ/ỷ/ỹ/ỵ → y`
- `đ → d`
- + tất cả biến thể có thêm dấu mũ/ngược (ô, ê, â, ơ, ư)

---

## 7. Anglicism trong tiếng Việt — chấp nhận hay không?

```
✅ CHẤP NHẬN (đã thành thuật ngữ chuẩn):
  - "skill", "agent", "session", "checkpoint"
  - "PRE-GATE", "POST-GATE", "CDG", "REQ-ID"
  - "Atomic Write", "Auto-fix", "Lazy-load"
  - Tên tool: "GitNexus", "Serena", "Playwright"

⚠️ DÙNG KÈM GIẢI THÍCH nếu xuất hiện lần đầu trong 1 file:
  - "Lazy-load procedures (tải lười)"
  - "POST-GATE (cổng kiểm tra cuối phase)"

❌ KHÔNG NÊN:
  - "We will use the framework" (lai 50/50)
  - "Bug được fix" → "Lỗi đã được sửa"
  - "Deploy lên production" → "Triển khai lên môi trường thật"
```

**Nguyên tắc:** Ưu tiên tiếng Việt cho action verbs ("triển khai", "phân tích"), giữ English cho **danh từ kỹ thuật chuẩn quốc tế** ("session", "API", "schema").

---

## 8. Khi nào thay đổi default language?

| Tình huống | Action |
|-----------|--------|
| Skill dành cho thị trường khác (vd: English market) | Override per-skill: ghi rõ trong `_contract.json.locale` |
| Code library internationalize (i18n) | Dùng i18n key thay vì hardcode string |
| Project có `locale: "en"` trong registry | Phase reports + CDG messages → English |
| Open-source skill cho cộng đồng quốc tế | Bi-lingual: Tiếng Việt + English |

`req-registry.json` có field `locale` (default `"vi"`, auto-detect từ `wf-brainstorm`):
```json
{"locale": "vi"}   // Default
{"locale": "en"}   // Override khi project English-first
```

---

## 9. Ví dụ Pass/Fail

### ✅ PASS — Phân biệt rõ ngôn ngữ per layer

**Phase report (user-facing):**
```markdown
## Phase 5: Phân loại lỗi — PASS

Thời gian: 2026-05-15T15:00:00+07:00
**Đã làm:** Phân tích 12 lỗi, phân loại theo mức độ nghiêm trọng.
**Kết quả:** 3 CRITICAL, 5 HIGH, 4 MEDIUM. File `bug-triage.md`.
**Tiếp theo:** Sửa lỗi ở Phase 6.
```

**Code (technical):**
```typescript
// REQ-ID: REQ-CRM-CUST-001
// Service quản lý khách hàng — soft-delete pattern
export class CustomerService {
  async softDelete(id: string): Promise<void> {
    // Set deletedAt = now, không xóa thực
    await this.repo.update(id, { deletedAt: new Date() });
  }
}
```

**Contract (mixed):**
```json
{
  "$schema": "skill-contract-v1",
  "description": "Skill phân tích yêu cầu nghiệp vụ — Phase 1",
  "errors": {
    "E001": {
      "severity": "critical",
      "description": "Registry rỗng — chạy /wf-brainstorm trước."
    }
  }
}
```

### ❌ FAIL — Mix tiếng tùy tiện

**Phase report:**
```markdown
## Phase 5: Triage — PASS
Time: 2026-05-15T15:00:00+07:00
Did: Analyze 12 bugs, classify by severity.
Result: 3 CRITICAL, ... Phase 6 next.
```
Vi phạm: tiếng Anh cho user-facing report → user VN không hiểu.

**Code:**
```typescript
// REQ_ID: req-crm-cust-001  ← lowercase + underscore
// Khách-hàng service với soft-delete
const danh_sách_khách_hàng = ...;  // Vietnamese có dấu trong var name
```
Vi phạm: REQ-ID format sai, var có dấu.

---

## 10. Anti-patterns — KHÔNG được làm

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Phase report English | Tiếng Việt (CORE-028) |
| `// Khách hàng service` (comment tiếng Việt OK) + biến `khách_hàng` (var có dấu) | Comment tiếng Việt + var `khachHang` |
| User error message: "Validation failed at field X" | "Trường X chưa hợp lệ. Vui lòng kiểm tra lại." |
| `_contract.json.description` English | Tiếng Việt — sẽ hiển thị qua user message |
| Mix file names: `Phase1-Init.md` + `phase2-scan.md` | Nhất quán: `Phase{N}-report.md` (UPPERCASE phase 1 chữ cái đầu) hoặc tất cả lowercase-kebab |
| Slug có dấu: `khách-hàng-management` | Strip dấu: `khach-hang-management` |
| REQ-ID lowercase: `req-sales-001` | UPPERCASE: `REQ-SALES-001` |
| CDG message English | Tiếng Việt + tránh jargon |
| Bash error: "ERR: invalid arg" | "Lỗi: Tham số không hợp lệ" |
| Trộn comment 1 file: 50/50 VN/EN ngẫu nhiên | 1 file 1 ngôn ngữ chính cho comments |

---

## 11. Checklist khi tạo file mới

**Documentation `.md`:**
- [ ] Nội dung chính tiếng Việt
- [ ] Code blocks giữ nguyên (English nếu là code)
- [ ] File path references kebab-case
- [ ] Acronym (CORE-XX, REQ-XX) UPPERCASE giữ nguyên

**Code file:**
- [ ] REQ-ID/FEAT-ID comment ở đầu file (CORE-003)
- [ ] Variable/function names English (hoặc Vietnamese không dấu)
- [ ] Class names PascalCase
- [ ] Comments giải thích nghiệp vụ: Tiếng Việt
- [ ] File name lowercase-kebab.ts

**JSON contract/schema:**
- [ ] Field keys English
- [ ] User-facing description tiếng Việt
- [ ] Enum values English snake_case hoặc kebab

**Bash script:**
- [ ] Comment headers tiếng Việt OK
- [ ] Error messages → user: tiếng Việt
- [ ] Log messages → technical: English chấp nhận

---

## 12. Liên kết

- **Canonical:** [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §5 (CORE-005)
- **Phase Summary spec:** [`.claude/skills/protocols/14-phase-summary.md`](../../.claude/skills/protocols/14-phase-summary.md)
- **CDG message templates:** [`.claude/skills/protocols/16-critical-decision-gate.md`](../../.claude/skills/protocols/16-critical-decision-gate.md) §16.4
- **Related standards:**
  - [`07-naming-conventions.md`](07-naming-conventions.md) — Naming rules + Vietnamese không dấu
  - [`05-quality-gates.md`](05-quality-gates.md) §5 — Phase Report tiếng Việt
