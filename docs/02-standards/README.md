# 02-Standards — Chuẩn Ràng Buộc Cho Phát Triển MCV3

> **Mọi skill, agent, rule, hoặc mở rộng MCV3 PHẢI tuân thủ các chuẩn trong thư mục này.** Đây là điều kiện tối thiểu — vi phạm = không merge.

---

## 1. Tại sao có thư mục này?

Trước đây, các chuẩn của MCV3 nằm rải rác:
- 38 CORE rules trong `.claude/rules/00-core.md` (dày đặc, không ví dụ)
- 22 protocols trong `.claude/skills/protocols/` (chuyên sâu, khó tra cứu nhanh)
- Skill anatomy chỉ có template ở `.claude/skills/workflow-skill.md`
- Naming/error-code/path contract không có doc tổng hợp

Hệ quả: skill mới thường vi phạm 1-2 chuẩn (path không khớp, error code trùng, naming sai). Cần đến `audit-devkit` mới phát hiện.

**`02-standards/` giải quyết bằng cách:**
1. Tổng hợp 38 CORE + 4 BHV thành index dễ tra cứu, kèm **ví dụ Pass/Fail**
2. Chốt 1 cấu trúc chuẩn cho skill (lazy-load procedures, CORE-032)
3. Cung cấp **registry chính thức** cho error codes và output paths (cải tiến chưa từng có)
4. Định nghĩa **extension checklist** — biết khi nào tạo mới vs sửa

---

## 2. Danh sách 12 chuẩn

| # | File | Mục đích | Tóm tắt 1 dòng |
|---|------|----------|----------------|
| 01 | [`01-core-rules-index.md`](01-core-rules-index.md) | Index 38 CORE + 4 BHV | Bảng tra cứu + ví dụ Pass/Fail cho 12 rule quan trọng nhất |
| 02 | [`02-skill-standard.md`](02-skill-standard.md) | Skill anatomy | Cấu trúc bắt buộc của 1 skill (CORE-032 lazy-load) |
| 03 | [`03-agent-standard.md`](03-agent-standard.md) | Agent definition | Cấu trúc agent + knowledge + procedures |
| 04 | [`04-contract-schema.md`](04-contract-schema.md) | `_contract.json` | Schema deep dive + version + cross-skill |
| 05 | [`05-quality-gates.md`](05-quality-gates.md) | PRE/POST-GATE + CDG | T1→T4 validation pattern + Critical Decision Gate |
| 06 | [`06-safe-write-protocol.md`](06-safe-write-protocol.md) | Safe-write registry | CORE-006 — mỗi skill ghi ĐÚNG fields được phân công |
| 07 | [`07-naming-conventions.md`](07-naming-conventions.md) | Naming chuẩn | kebab-case, REQ-ID, FEAT-ID, session-ID, error code |
| 08 | [`08-error-code-registry.md`](08-error-code-registry.md) | ★ Registry error codes | Bảng chính thức E001..E999 phân theo skill |
| 09 | [`09-session-checkpoint.md`](09-session-checkpoint.md) | Session + checkpoint | CORE-035 session structure + CORE-038 context budget |
| 10 | [`10-language-policy.md`](10-language-policy.md) | Ngôn ngữ | Tiếng Việt user-facing, English code identifiers |
| 11 | [`11-output-path-contract.md`](11-output-path-contract.md) | ★ Output paths | Bảng chính thức `.mc-data/` paths theo CORE-007 |
| 12 | [`12-extension-checklist.md`](12-extension-checklist.md) | Extension checklist | Khi nào tạo skill mới vs sửa cũ; DoD đầy đủ |

★ = **cải tiến mới so với trước** (chưa có registry/contract tổng hợp)

---

## 3. Thứ tự đọc cho 3 use case

### Use case 1: Tạo skill mới (full đọc)
```
01-core-rules-index → 02-skill-standard → 04-contract-schema → 05-quality-gates →
07-naming → 08-error-code-registry → 09-session-checkpoint → 11-output-path → 12-extension-checklist
```

### Use case 2: Tạo agent mới
```
01-core-rules-index → 03-agent-standard → 10-language-policy → 12-extension-checklist
```

### Use case 3: Sửa skill có sẵn
```
12-extension-checklist (mục "sửa skill cũ") → 06-safe-write-protocol → 11-output-path-contract
```

---

## 4. Mức độ ràng buộc

| Mức | Ý nghĩa | Hành động khi vi phạm |
|-----|---------|----------------------|
| **BẮT BUỘC** | Vi phạm = code không hợp lệ, audit fail | Block merge cho đến khi fix |
| **KHUYẾN NGHỊ** | Best practice — có thể bỏ qua nếu lý do chính đáng (ghi vào ADR) | WARN, đề nghị fix |
| **THAM KHẢO** | Style guide — không bắt buộc | Suggest only |

Toàn bộ 38 CORE + 4 BHV trong `01-core-rules-index.md` đều **BẮT BUỘC**. Mức độ ràng buộc của từng chuẩn được ghi trong header file tương ứng.

---

## 5. Quy trình cập nhật chuẩn

Khi muốn thay đổi 1 chuẩn:

1. **Đề xuất** — mở Issue mô tả vấn đề + đề xuất sửa
2. **ADR** — viết Architecture Decision Record (xem `04-skill-design/_template/08-tradeoffs-adr.md`)
3. **Review** — chí ít 1 reviewer signoff
4. **Cập nhật song song:**
   - File chuẩn trong `02-standards/`
   - File gốc trong `.claude/rules/` hoặc `.claude/skills/protocols/`
   - Cập nhật version trong CHANGELOG.md
5. **Migration** — nếu có skill đang vi phạm chuẩn mới → tạo plan migration trong `plans/`

---

## 6. Liên kết

- File gốc canonical: `.claude/rules/00-core.md`, `.claude/rules/00-behavioral.md`, `.claude/skills/protocols/`
- Pattern + ví dụ chi tiết: [`../03-design-patterns/`](../03-design-patterns/)
- Template skill mới: [`../04-skill-design/_template/`](../04-skill-design/_template/)
- Review checklist: [`../05-review-standards/`](../05-review-standards/)
