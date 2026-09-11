<!--
_template_notes:
  purpose: Liệt kê các template files skill dùng (READ→POPULATE→WRITE).
  populate:
    - §1 Bảng templates: path, output target, fields populate
    - §2 Metadata stripping rules (xóa _template_notes, _schema_notes)
    - §3 Template versioning
    - §4 Validation: schema JSON cho template output
  độ dài tham khảo: 100-200 dòng
-->

# 06 — Templates List

> **Mục đích file:** Danh sách templates skill dùng để tạo output files. Tuân thủ CORE-031 (mọi output từ template).

---

## 1. Bảng templates

| # | Template path | Output target | Fields populate | Schema |
|---|--------------|--------------|-----------------|--------|
| 1 | `.claude/skills/workflow/{skill-name}/templates/fix-status.json` | `$SESSION_DIR/fix-status.json` | session_id, current_phase, ... | `fix-status-v1` |
| 2 | `.claude/skills/workflow/{skill-name}/templates/Phase{N}-report.md` | `$SESSION_DIR/phase{N}-*/Phase{N}-report.md` | timestamp, summary, result | — (markdown) |
| 3 | `.claude/skills/workflow/{skill-name}/templates/{output}.md` | {path} | {fields} | {schema} |
| {...} | {...} | {...} | {...} | {...} |

---

## 2. Metadata stripping rules (CORE-031.b)

Mọi template có metadata blocks ở đầu cần được **strip** trước khi write:

```yaml
# Template gốc
_template_notes:
  ...
_schema_notes:
  ...

# Sau khi populate + write → 2 blocks này bị xóa
```

Script tham chiếu: `.claude/scripts/strip-template-metadata.sh` (nếu có).

---

## 3. Template versioning

| Template | Version | Khi nào bump |
|----------|---------|--------------|
| `fix-status.json` | v1.0 | Khi thêm/đổi field |
| `Phase{N}-report.md` | v1.0 | Khi đổi structure markdown |
| `{output}.md` | v1.0 | Khi đổi semantic |

**Quy tắc:** Bump major version (v1→v2) khi breaking change → consumer phải migrate.

---

## 4. Validation cho output

Mỗi output từ template phải pass T1→T4 validation (xem [04-file-contract.md](04-file-contract.md) §2).

Đặc biệt T2 (structure) check:
```bash
jq -e '.session_id and .current_phase and .phases_completed' fix-status.json > /dev/null
```

---

## 5. Liên kết

- Pattern: [`../../03-design-patterns/01-lazy-load-procedures.md`](../../03-design-patterns/01-lazy-load-procedures.md)
- Rules: CORE-031 (Template Usage Rule)
- Protocol: [`.claude/skills/protocols/19-template-usage.md`](../../../.claude/skills/protocols/19-template-usage.md)
- File contract: [04-file-contract.md](04-file-contract.md)
