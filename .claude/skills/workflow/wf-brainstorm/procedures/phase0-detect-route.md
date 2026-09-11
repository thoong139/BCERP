# Phase 0: Auto-Detection & Routing

> Entry point của flow. Tự động phát hiện loại dự án (NEW/LEGACY) và routing.
> Đọc file này NGAY KHI SKILL.md route vào procedures/.

**PRE-GATE:** Không có (entry point)

**INPUT:** `$ARGUMENTS` (project-name, --force)

**OUTPUT:** `$PROJECT_TYPE` (NEW/LEGACY), `$LEGACY_MODE` flag, optional `$LEGACY_CONTEXT`

---

## Step 0.1: Detect LEGACY_MODE (CORE-021)

```
LEGACY_MODE = test -f .mc-data/work/legacy-scan/project-context.md && size > 500 bytes
```

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.1.1 | Check `test -f .mc-data/work/legacy-scan/project-context.md` | Bash | File path resolved |
| 0.1.2 | Nếu file tồn tại → `wc -c` để check size > 500 bytes | Bash | Size threshold checked |
| 0.1.3 | Set `$LEGACY_MODE = true/false` theo kết quả | — | Flag set |

---

## Step 0.2: Routing Decision

```
IF $LEGACY_MODE = true:
  → $PROJECT_TYPE = LEGACY
  → Read .mc-data/work/legacy-scan/project-context.md → $LEGACY_CONTEXT
  → Thông báo: "Phát hiện dự án có sẵn (project-context.md). Chạy flow với legacy context injection."
  → Next: phase0-5-legacy-snapshot.md

ELSE IF test -d .mc-data:
  → $PROJECT_TYPE = NEW (existing .mc-data, no legacy-scan)
  → Next: phase1-collect-basic.md (PRE-GATE branch xử lý existing .mc-data)

ELSE:
  → $PROJECT_TYPE = NEW (fresh project)
  → Next: phase1-collect-basic.md
```

---

## Step 0.3: Parse Arguments

| Step | Action | Tool | Lưu vào context |
|------|--------|------|-----------------|
| 0.3.1 | Parse `$ARGUMENTS`: nếu có domain/tên dự án → lưu `project_name` | — | `project_name` |
| 0.3.2 | Detect `--force` flag trong arguments | — | `force_flag` (true/false) |

---

## Step 0.4: Append Session Log START (CORE-026)

> Shared Protocol §15 — output-only observability, best-effort (failure không block skill).

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.4.1 | `mkdir -p .mc-data/work/_trace` | Bash | Dir exists |
| 0.4.2 | Nếu `.mc-data/work/_trace/session-log.json` chưa tồn tại → tạo từ template `.claude/doc-framework/_meta/session-log.template.json` | Read + Write | File exists |
| 0.4.3 | APPEND event `START`: `{skill: "wf-brainstorm", event: "START", phase: "phase0-detect-route", project_type: "$PROJECT_TYPE", legacy_mode: $LEGACY_MODE, timestamp: NOW}` dùng atomic pattern `tmp=$(mktemp); jq '.entries += [...]' session-log.json > "$tmp" && mv "$tmp" session-log.json` | Bash | `jq '.entries | length > 0' session-log.json` |

---

## POST-GATE Phase 0

- [ ] `$PROJECT_TYPE` đã được set (NEW hoặc LEGACY)
- [ ] `$LEGACY_MODE` flag đã được set
- [ ] Nếu LEGACY: `$LEGACY_CONTEXT` đã load (project-context.md content)
- [ ] `project_name` parsed từ arguments (nếu có)
- [ ] `force_flag` parsed (nếu có)

> **Lưu ý:** Phase 0 KHÔNG ghi file. Chỉ set runtime context. `brainstorm-status.json` sẽ được tạo tại Phase 1 step 1.0b.

---

## Next Phase

| Điều kiện | Phase tiếp theo |
|------------|-----------------|
| `$LEGACY_MODE = true` | **`phase0-5-legacy-snapshot.md`** (xử lý legacy snapshot trước) |
| `$LEGACY_MODE = false` | **`phase1-collect-basic.md`** (entry vào Thu Thập) |

> Khi LEGACY: sau phase0-5-legacy-snapshot.md → vẫn về phase1-collect-basic.md để chạy chung pipeline.
