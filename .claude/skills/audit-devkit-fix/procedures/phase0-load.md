# Phase 0: Load Verified Findings

> Đọc verified results, filter AUTO fixable, sort theo dependency order.
> Entry point của skill — chạy đầu tiên sau PRE-GATE.

**PRE-GATE:**
- `.mc-data/work/audit-devkit-verify/[session-id]/audit-verified-result.json` tồn tại
- `.mc-data/work/audit-devkit-scan/[session-id]/audit-index.json` tồn tại
- **verify-status.json phải báo `status: "completed"`** — nếu `status: "in_progress"` → WARNING: "Verify phase chưa hoàn thành. Kết quả fix có thể dựa trên dữ liệu chưa được cross-validate. Tiếp tục? [y/n]". Chỉ tiếp tục khi user confirm HOẶC khi `status = "completed"`

**📤 OUTPUT (Phase 0):**
- `.mc-data/work/audit-devkit-fix/[session-id]/fix-status.json` (template: `templates/fix-status.template.json`)

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.1 | Parse arguments → xác định mode (dry-run/live), severity filter, resume flag. Parse `--session=<id>` (nếu có) → lưu vào `$PINNED_SESSION_ID` (BẮT BUỘC khi gọi từ orchestrator `/audit-devkit` để chống race; optional khi standalone). | - | mode + severity + resume + pinned session set |
| 0.1a | **Verify-complete gate check:** Read `verify-status.json` → nếu `status != "completed"` → WARNING: "Verify phase chưa hoàn thành (status=[status]). Kết quả fix có thể dựa trên dữ liệu chưa cross-validate. Tiếp tục?" → chờ user confirm. Nếu `verify-status.json` không tồn tại → WARNING: "verify-status.json không tìm thấy — không thể xác nhận verify đã hoàn thành." → chờ user confirm. | Read | Gate passed or user confirmed |
| 0.1b | **Session-id discovery (C3 fix — 2026-05-10)** — logic 3 nhánh theo thứ tự ưu tiên: | - | session-id variable set |
| | **(a) CÓ `$PINNED_SESSION_ID`** (orchestrator pass `--session=<id>`): dùng đúng id đó. Validate `.mc-data/work/audit-devkit-verify/$PINNED_SESSION_ID/audit-verified-result.json` tồn tại — nếu KHÔNG tồn tại → STOP với error: "Pinned session $PINNED_SESSION_ID không có audit-verified-result.json. Kiểm tra `--session` flag." Set `$SESSION_ID = $PINNED_SESSION_ID`. | Read | |
| | **(b) CÓ `--resume`** (không pin): Glob `.mc-data/work/audit-devkit-fix/*/fix-status.json` → tìm session có `status: "in_progress"` → dùng session-id đó. Nếu không tìm thấy → fallback sang nhánh (c). | Glob | |
| | **(c) KHÔNG pin, KHÔNG resume** (standalone fresh): Glob `.mc-data/work/audit-devkit-verify/*/audit-verified-result.json` → pick latest timestamp directory (format `YYYYMMDD-HHMMSS`). Nếu không tìm thấy → tạo session-id mới = current timestamp. Multiple → dùng latest. Log: "Using latest verify session $SESSION_ID (no --session pinned)". | Glob | |
| 0.1c | **Ghi Execution Trace START** (Protocol §15): Append entry vào `.mc-data/work/_trace/session-log.json`: `{event: "START", skill: "audit-devkit-fix", session_id, timestamp, run_sequence}`. Nếu file chưa tồn tại → READ template `.claude/doc-framework/_meta/session-log.template.json` → POPULATE project → WRITE. | Write/Bash | entry appended, `jq '.entries \| length > 0'` passes |
| 0.2 | Tạo work directory `.mc-data/work/audit-devkit-fix/[session-id]/` và `reports/` nếu chưa có | Bash | `test -d .mc-data/work/audit-devkit-fix/[session-id]/` |
| 0.3 | Đọc `.mc-data/work/audit-devkit-verify/[session-id]/audit-verified-result.json` | Read | Content loaded, JSON valid |
| 0.4 | Validate JSON: `jq '.' .mc-data/work/audit-devkit-verify/[session-id]/audit-verified-result.json` | Bash | exit code 0 |
| 0.5 | Validate: `findings` array tồn tại và length > 0 | Read | `findings[]` non-empty |
| 0.6 | Đọc `.mc-data/work/audit-devkit-scan/[session-id]/audit-index.json` (ground truth cho re-scan) | Read | Content loaded |
| 0.7 | **Nếu `--resume`**: Đọc existing `fix-status.json` + partial `fix-log.json` → extract processed finding IDs → skip sang step 0.12 với fix_queue đã filter. | Read | processed IDs extracted |
| 0.8 | Filter findings: chỉ giữ `fix_type="AUTO"` | - | `auto_findings[]` created |
| 0.9 | Apply severity filter theo argument: | - | `filtered_findings[]` created |
|     | — `--severity=CRITICAL` → chỉ `severity="CRITICAL"` | | |
|     | — `--severity=MAJOR` → `severity="CRITICAL"` hoặc `"MAJOR"` | | |
|     | — `--severity=ALL` (default) → tất cả AUTO findings | | |
| 0.10 | Sort theo dependency order (xem `_shared.md §Fix Pattern → Priority Lookup`): | - | `fix_queue[]` sorted |
|     | **Priority 1:** Structural (missing sections, frontmatter) | | |
|     | **Priority 2:** Naming (file/component name mismatches) | | |
|     | **Priority 3:** References (broken paths, wrong references) | | |
|     | **Priority 4:** Deprecated (replace deprecated names/values) | | |
| 0.10a | **False Positive Recognition pass** (xem `_shared.md §False Positive Recognition`): Với mỗi finding trong `fix_queue`, check 4 tình huống FP (stale, description mismatch, auto-fixed already, scope mismatch) bằng cách Read/Grep file thực tế. Match → remove khỏi `fix_queue`, log vào `skipped_fps[]` với reason. | Read/Grep | FP findings filtered |
| 0.11 | Log: "Fix queue: [N] findings ([M] CRITICAL, [K] MAJOR, [L] MINOR)" | Output | Displayed |
| 0.11b | Nếu `--dry-run` → log: "DRY-RUN MODE — không thực sự sửa file" | Output | Mode confirmed |
| 0.12 | **Nếu KHÔNG --resume** (hoặc `fix-status.json` chưa tồn tại): READ template `templates/fix-status.template.json` → POPULATE `session_id`, `started_at`, `mode`, `severity_filter`, `total_in_queue`, `phases` (đặt `phase0-load` status=pending), `timestamps.started_at` → WRITE `fix-status.json` | Read, Write | `test -f .mc-data/work/audit-devkit-fix/[session-id]/fix-status.json` |
|     | **Nếu CÓ --resume** (`fix-status.json` đã tồn tại): Kiểm tra `status` — nếu `"completed"` → hỏi user có muốn re-run không. Nếu `"in_progress"` → tiếp tục. | Read | status validated |

---

## POST-GATE

- `fix_queue[]` sorted, non-empty (hoặc empty → skip Phase 1, báo "nothing to fix")
- mode (dry-run/live) confirmed
- severity filter applied
- `fix-status.json` created tại `$SESSION_DIR/fix-status.json`
- `phases.phase0-load.status = "completed"` trong `fix-status.json`

**Update `fix-status.json`:**
```
phases.phase0-load.status = "completed"
phases.phase0-load.completed_at = NOW
phases.phase1-fix.status = "pending"
timestamps.last_updated = NOW
current_phase = "phase1-fix"
```

---

## Graceful Degradation

- Nếu `audit-verified-result.json` corrupt → retry 3 lần, sau đó STOP + E003 (yêu cầu re-run verify)
- Nếu `audit-index.json` không tồn tại → STOP + E002 (yêu cầu re-run scan)
- Nếu `verify-status.json` không tồn tại → WARNING E001b, tiếp tục sau confirm
