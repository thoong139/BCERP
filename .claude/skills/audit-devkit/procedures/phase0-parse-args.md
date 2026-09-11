# Phase 0: Parse Arguments & Determine Pipeline

> **Đọc:** `procedures/_shared.md §Argument Mapping Tables` + `§State Variables Glossary` trước khi execute.

**Mục đích:** Parse `$ARGUMENTS`, xác định pipeline mode, scope, fix/eval flags, và hiển thị pipeline plan cho user.

---

## PRE-GATE

```bash
test -d .claude/agents/          # Agents directory tồn tại
test -d .claude/skills/          # Skills directory tồn tại
test -f .claude/rules/00-core.md # Core rules tồn tại
```

Nếu fail → **STOP E001**: "Không phải DEVKIT project".

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 0.1 | Parse `$ARGUMENTS` → tách thành flags | Tokens |
| 0.2 | Map pipeline flag → `$PIPELINE_MODE`, `$STAGES[]`, `$FIX_MODE` (xem bảng dưới) | Variables set |
| 0.3 | Map scope flag → `$SCAN_ARGS`, `$VERIFY_ARGS`, `$SCOPE`, `$FOCUSED_SKILL` | Args built |
| 0.4 | Nếu có `--since=<commit>`: append ` --since=<commit>` vào `$SCAN_ARGS`. Chạy `git diff --name-only <commit>..HEAD -- .claude/`. Nếu 0 files → INFO: "Không có files thay đổi từ <commit>" + SKIP scan (loại bỏ `scan` khỏi `$STAGES[]`). | Files list |
| 0.5 | Nếu có `--evals`: `$EVAL_MODE = ON`, append `evals` vào `$STAGES[]`. Parse `--eval-mode=<x>` → `$EVAL_HARNESS_MODE` (default `stub`). Parse `--eval-skill=<name>` → `$EVAL_SKILL_FILTER`. | Eval vars set |
| 0.6 | Parse `--severity=<x>` → `$FIX_SEVERITY` (default `ALL`). VALIDATE: `x` PHẢI ∈ `{ALL, CRITICAL, MAJOR}`. Nếu `x = MINOR` hoặc giá trị khác → **STOP E002**: `"--severity=$x không hợp lệ. Hợp lệ: ALL, CRITICAL, MAJOR. Lưu ý: filter là ADDITIVE — MAJOR = CRITICAL+MAJOR; ALL = tất cả. Không có MINOR-only mode."` | Set + validated |
| 0.7 | Nếu `--fix-only`: validate prerequisite — Glob `.mc-data/work/audit-devkit-verify/*/audit-verified-result.json`. Nếu không có → **STOP E005**. **Sau khi validate**: pick latest timestamp directory → extract directory name → set `$SESSION_ID` ngay (fix-only skip Phase 1, nên không có cơ hội set qua scan). Phase 3 dùng `$SESSION_ID` này khi gọi sub-skill audit-devkit-fix. | File exists + $SESSION_ID set |
| 0.8 | Hiển thị pipeline plan cho user (xem template dưới) | Displayed |

---

## Pipeline Mode Mapping

| Argument | `$STAGES[]` | `$FIX_MODE` |
|----------|-------------|-------------|
| *(none)* hoặc `--full` | `[scan, verify, fix, master-plan]` | ON |
| `--no-fix` | `[scan, verify, master-plan]` | OFF |
| `--scan-only` | `[scan]` | OFF |
| `--quick` | `[scan]` (+ append `--agents --skills` vào `$SCAN_ARGS`) | OFF |
| `--fix-only` | `[fix]` | ON |
| `--master-plan` | `[master-plan]` | OFF |

Nếu conflict giữa 2 pipeline flags → WARNING + ưu tiên flag đầu tiên theo thứ tự trên.

**`--quick` + scope flag (Sprint 3 polish):** Nếu user pass `--quick` đồng thời với scope flag (`--agents`, `--skills`, `--templates`, `--rules`, `--hooks`, `--skill=<name>`), `--quick` mặc định append `--agents --skills` vào `$SCAN_ARGS`. Áp dụng dedup khi build args:

- Nếu scope flag đã chứa `--agents` hoặc `--skills` (hoặc cả hai) → KHÔNG append duplicate. Hiển thị WARNING:  
  `"--quick mặc định bao gồm --agents --skills; bỏ qua append duplicate vì user đã pass scope flag tương ứng. SCAN_ARGS cuối: <$SCAN_ARGS>"`
- Nếu scope flag KHÔNG chồng (vd `--templates`, `--rules`, `--hooks`, `--skill=<name>`) → append `--agents --skills` bình thường + WARNING:  
  `"--quick mặc định mở rộng scope sang agents+skills; SCAN_ARGS cuối: <$SCAN_ARGS> (vượt scope flag user truyền)"`

Mục đích: tránh truyền `--agents --skills --agents` (3 args, duplicate) và cảnh báo user khi `--quick` mở rộng scope ngoài ý muốn.

---

## Scope Mapping

| Argument | `$SCAN_ARGS` | `$VERIFY_ARGS` | `$SCOPE` |
|----------|--------------|----------------|----------|
| *(none)* | `--all` | `--all` | `all` |
| `--agents` | `--agents` | `--agents` | `agents` |
| `--skills` | `--skills` | `--skills` | `skills` |
| `--templates` | `--templates` | `--templates` | `templates` |
| `--rules` | `--rules` | `--all` (verify không có --rules focused) | `rules` |
| `--hooks` | `--hooks` | `--all` (verify không có --hooks focused) | `hooks` |
| `--skill=<name>` | `--skill=<name>` | `--skill=<name>` | `focused-skill` (+ `$FOCUSED_SKILL=<name>`) |

**Lưu ý:**
- `--since=<commit>` chỉ append vào `$SCAN_ARGS`, KHÔNG vào `$VERIFY_ARGS` (verify luôn cần toàn bộ data để cross-reference).
- `--rules` và `--hooks` (H1 fix 2026-05-10): scan sub-skill hỗ trợ 2 flags này nhưng verify sub-skill chưa có focused mode tương ứng → fallback `--all` ở verify để giữ cross-reference đầy đủ. Backward compat với SKILL.md §Lưu ý #2 được khôi phục.

---

## Pipeline Plan Display

Trước khi execute Phase 1, hiển thị cho user:

```
Pipeline: [stages đã join bằng →]. Scope: [scope]. Fix: [ON/OFF]. Eval: [ON (mode=X) / OFF].
Duration dự kiến: [15-40 min full / 2-5 min master-plan / 3-8 min focused-skill]
```

---

## POST-GATE

| Check | Required |
|-------|----------|
| `$PIPELINE_MODE` đã set | ✓ |
| `$STAGES[]` ≥1 stage | ✓ |
| `$SCOPE` đã set | ✓ |
| `$SCAN_ARGS` hoặc `$VERIFY_ARGS` non-empty (tùy stages) | ✓ |
| `orchestrator-status.json` written to `.mc-data/work/audit-devkit/` (từ template `templates/orchestrator-status.json`) | ✓ |

---

## Errors

| Code | Situation | Action |
|------|-----------|--------|
| E001 | PRE-GATE directories missing | STOP |
| E002 | Argument conflict hoặc không hợp lệ | WARNING + default `--full`. Hiển thị cho user |
| E005 | `--fix-only` thiếu prerequisite | STOP với hướng dẫn chạy scan+verify trước |
