# Phase 3: Bidirectional Consistency

> Kiểm tra tính nhất quán hai chiều: agent coordination symmetry, deprecated names, naming consistency.
> Áp dụng khi `$SCOPE` ∈ { `consistency`, `all`, `skill` }.

## PRE-GATE

- Phase 0 POST-GATE pass
- (nếu `$SCOPE = all` hoặc `$SCOPE = skill`) Phase 2 POST-GATE pass — workflow findings valid
- (nếu `$SCOPE = consistency`) Phase 2 không chạy — dùng chỉ index

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.1 | **Agent coordination symmetry** (xem chi tiết bên dưới) | Grep/Read | asymmetry detected |
| 3.2 | **Deprecated name sweep** (xem chi tiết bên dưới) | Grep | matches collected |
| 3.3 | **Naming consistency** (xem chi tiết bên dưới) | Grep/Read | inconsistencies found |
| 3.4 | Build findings array từ steps 3.1-3.3 | - | findings[] populated |
| 3.5 | Write `$VERIFY_DIR/findings-consistency.json` (schema `audit-findings-v1`) | Write | File created |
| 3.6 | Validate JSON | Bash | `jq '.'` pass |

## Check 3.1 — Agent Coordination Symmetry

```
Với MỖI agent A có `coordination` section liệt kê agent B:
  → Check: agent B file có nhắc đến agent A trong coordination section?
  → Nếu không → MINOR finding (asymmetric coordination)
  → Finding id prefix: F-CON-001...
```

## Check 3.2 — Deprecated Name Sweep

```
Grep TẤT CẢ deprecated names trong .claude/:
  Nguồn danh sách (ưu tiên):
  1. $INDEX.deprecated_names (từ Wave 4+ scan) — DÙNG khi có
  2. Fallback inline list:
     - `explore` (cũ) → hiện không dùng
     - Bất kỳ agent/skill tên cũ đã đổi

  Mỗi match = 1 finding
  Finding id prefix: F-CON-100...
```

**Lưu ý:** Danh sách inline có thể stale. Ưu tiên populate `audit-index.json:deprecated_names` trong scan phase (Wave 4+). Khi field có dữ liệu, dùng field thay vì inline list.

## Check 3.3 — Naming Consistency

```
Với MỖI agent trong $INDEX:
  filename (without .md) = subagent_type trong skills = tên trong CLAUDE.md

Với MỖI skill trong $INDEX:
  folder name = command name = tên trong CLAUDE.md

Mismatch = MAJOR finding
Finding id prefix: F-CON-200...
```

## Focused filter (chỉ khi `$SCOPE = skill`)

Chỉ check các items liên quan đến `$FOCUSED_SKILL`:
- Agents được skill target reference (qua `subagent_type`)
- Agents trong coordination section của skill
- Rows skill trong CLAUDE.md + rules

Skip items không liên quan.

## Finding ID Prefix Map

```
F-CON-001...: Agent coordination symmetry
F-CON-100...: Deprecated name usage
F-CON-200...: Naming inconsistency
```

## POST-GATE

- `$VERIFY_DIR/findings-consistency.json` tồn tại
- JSON valid, schema `audit-findings-v1`
- Update `verify-status.json`: mark `phase3-consistency` completed

## Routing sau Phase 3

- Nếu `$SCOPE == "consistency"` → chuyển `phase4-merge.md` (partial scope verdict)
- Nếu `$SCOPE == "skill"` → chuyển `phase4-merge.md` (skill verdict — skip 3.5)
- Nếu `$SCOPE == "all"` → tiếp tục `phase3-5-masterplan-crossvalidate.md`

## Errors liên quan

- Nếu `$INDEX.deprecated_names` không tồn tại → fallback inline list + WARNING
- Grep fail (ripgrep lỗi) → skip check + MINOR finding ghi chú

Chi tiết: `_shared.md §Error Handling Reference`.
