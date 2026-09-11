# 02 — Arguments

> **Mục đích file:** 4 arguments của skill — đơn giản nhất Tier 1 nhưng có ảnh hưởng lớn đến scope.

---

## 1. Bảng arguments

| Arg | Type | Default | Required | Mô tả |
|-----|------|---------|----------|-------|
| `scope` | enum/string | `all` | Không | `all` / `business` / `[module-name]` |
| `--status` | flag | — | Không | Hiển thị tiến độ, không thực thi |
| `--resume` | flag | — | Không | Resume từ checkpoint đã lưu |
| `--session=<id>` | string | latest session | Không | Tiếp tục session cụ thể (format `YYYYMMDD-HHMMSS-hash`) |

---

## 2. Scope behavior

| Scope value | Phase 6b (workflow) | Phase 6c (stakeholder) | Phase 6d (conflict) | Departments xử lý |
|-------------|---------------------|------------------------|---------------------|-------------------|
| `all` (default) | ✅ Run | ✅ Run | ✅ Run | All departments từ registry |
| `business` | ❌ Skip | ❌ Skip | ❌ Skip | Tất cả dept |
| `[module-name]` (vd `MOD-SALES`) | ❌ Skip | ❌ Skip | ❌ Skip | Chỉ 1 dept tương ứng module |

---

## 3. Argument interactions

| Combo | Behavior |
|-------|----------|
| `--status` + `--resume` | `--status` ưu tiên — chỉ hiển thị, không resume |
| `--resume` + thiếu session | Auto-discover latest session từ `latest` pointer |
| `--resume` + `--session=<id>` | Resume specific session |
| `scope=business` + `--resume` | OK — preserve original scope từ session-state |

---

## 4. Validation rules

| Arg | Rule | Error code |
|-----|------|------------|
| `scope` | Match `^(all|business|MOD-[A-Z0-9-]+)$` HOẶC tên dept tự do | — (default) |
| `--session=<id>` | Match `^[0-9]{8}-[0-9]{6}-[a-z0-9]{4}$` (timestamp-hash) | — (warning if not found) |
| Registry | `test -f .mc-data/docs/_meta/req-registry.json` | E000 |
| Brainstorm | `test -f phase0-brainstorm/P0-01-brainstorm.md` | E016 |

---

## 5. Examples

```bash
# Full analysis (default)
/wf-analyze-requirements

# Resume latest session
/wf-analyze-requirements --resume

# Resume specific session
/wf-analyze-requirements --resume --session=20260515-143000-a1b2

# Status check
/wf-analyze-requirements --status

# Targeted single module
/wf-analyze-requirements MOD-SALES

# Business-only (skip workflow/stakeholder/conflict phases)
/wf-analyze-requirements business
```

---

## 6. Liên kết

- Error codes: [05-error-codes.md](05-error-codes.md)
- Resume flow: [`procedures/phase0-context.md`](../../../.claude/skills/workflow/wf-analyze-requirements/procedures/phase0-context.md) `--resume` handler
- Scope decision: [`procedures/phase1-scope.md`](../../../.claude/skills/workflow/wf-analyze-requirements/procedures/phase1-scope.md) §Scope behavior table
