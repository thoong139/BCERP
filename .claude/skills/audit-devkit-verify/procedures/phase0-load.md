# Phase 0: Load & Validate Ground Truth

> Đọc và validate outputs từ `/audit-devkit-scan`. Spot-check để detect stale data.
> Phase này **LUÔN chạy** cho mọi scope.

## PRE-GATE

- `.mc-data/work/audit-devkit-scan/*/audit-index.json` tồn tại (ít nhất 1 session)
- `.mc-data/work/audit-devkit-scan/*/audit-scan-result.json` tồn tại

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.1 | Parse arguments → xác định `$SCOPE` (crossref/workflow/consistency/master-plan/all/skill). Nếu `--skill=<name>` → `$SCOPE = "skill"`, lưu `$FOCUSED_SKILL = <name>`. Parse `--session=<id>` (nếu có) → lưu vào `$PINNED_SESSION_ID` (BẮT BUỘC khi gọi từ orchestrator `/audit-devkit` để chống race; optional khi standalone). | - | scope + pinned session variable set |
| 0.1b | **Session-id discovery (C3 fix — 2026-05-10):** Logic 2 nhánh: <br>**(a) CÓ `$PINNED_SESSION_ID`** (orchestrator pass `--session=<id>`): dùng đúng id đó. Validate `.mc-data/work/audit-devkit-scan/$PINNED_SESSION_ID/audit-index.json` tồn tại — nếu KHÔNG tồn tại → STOP với error: "Pinned session $PINNED_SESSION_ID không có audit-index.json. Kiểm tra `--session` flag." Set `$SESSION_ID = $PINNED_SESSION_ID`, `$SCAN_DIR = .mc-data/work/audit-devkit-scan/$SESSION_ID/`. <br>**(b) KHÔNG `--session`** (standalone call, backward-compat): Glob `.mc-data/work/audit-devkit-scan/*/audit-index.json` → pick latest timestamp directory. Multiple sessions → dùng latest. Log: "Using latest scan session $SESSION_ID (no --session pinned)". Set `$SESSION_ID`, `$SCAN_DIR`. | Glob/Read | session-id variable set |
| 0.2 | Tạo work directory `$VERIFY_DIR = .mc-data/work/audit-devkit-verify/$SESSION_ID/` nếu chưa có | Bash | `test -d $VERIFY_DIR` |
| 0.3 | Đọc `$SCAN_DIR/audit-index.json` → lưu vào `$INDEX` | Read | Content loaded, JSON valid |
| 0.4 | Validate `audit-index.json`: `jq '.' $SCAN_DIR/audit-index.json` | Bash | exit code 0 |
| 0.5 | Validate: `counts.agents > 0 AND counts.skills > 0`. Nếu một count = 0 (scan chỉ chạy partial scope): WARNING — crossref passes liên quan đến component thiếu sẽ có empty findings. Không block, nhưng log warning vào `verify-status.json` | Read | counts verified |
| 0.6 | Đọc `$SCAN_DIR/audit-scan-result.json` → lưu vào `$SCAN_RESULT` | Read | Content loaded, JSON valid |
| 0.7 | Validate `audit-scan-result.json`: `jq '.' $SCAN_DIR/audit-scan-result.json` | Bash | exit code 0 |
| 0.8 | Spot-check: random 5 files từ `$INDEX` → Glob verify vẫn tồn tại | Glob | ≥4/5 files still exist |
| 0.9 | Nếu file nào đã bị xóa/đổi tên since scan → WARNING, ghi note vào findings | - | warnings logged |
| 0.9b | Kiểm tra scan completion: Read `$SCAN_DIR/scan-status.json` → nếu `status != "completed"` → WARNING: "Scan session có thể chưa hoàn tất. Kết quả có thể không đầy đủ." Tiếp tục nhưng log warning vào `verify-status.json` | Read | scan status checked |
| 0.9c | **Delta-aware verify:** Nếu `$SCAN_DIR/audit-scan-result.json` có field `delta_mode=true` (từ --since scan) → set `$DELTA_MODE = true`. Cross-ref passes sẽ CHỈ kiểm references liên quan đến changed files (filter từ `changed_files[]` trong scan result). Workflow + consistency checks vẫn chạy full scope. Log info: "Delta-aware verify: chỉ cross-ref [N] changed files" | Read | delta mode detected |
| 0.10 | Tạo `verify-status.json` cho resume support (xem schema trong `_shared.md §Schemas`). `scope` PHẢI lấy từ `$SCOPE` (step 0.1) — KHÔNG hardcode "all". Nếu `$SCOPE = "skill"` → set `focused_skill: $FOCUSED_SKILL`. Bao gồm `completed_at: null` | Write | `test -f $VERIFY_DIR/verify-status.json` |

## POST-GATE

- `$INDEX` valid, `$SCAN_RESULT` loaded
- Spot-check pass (≥80% files still exist)
- `verify-status.json` created với đúng `scope` + `focused_skill`
- Append `phase0-load` vào `completed_phases[]`

## Routing sau Phase 0

```
Nếu $SCOPE == "crossref" → phase1-crossref.md → phase4-merge.md
Nếu $SCOPE == "workflow" → phase2-workflow.md → phase4-merge.md
Nếu $SCOPE == "consistency" → phase3-consistency.md → phase4-merge.md
Nếu $SCOPE == "master-plan" → phase3-5-masterplan-crossvalidate.md → phase4-merge.md
Nếu $SCOPE == "skill" → phase1-focused.md → phase2-workflow.md → phase3-consistency.md → phase4-merge.md
Nếu $SCOPE == "all" → phase1-crossref.md → phase2-workflow.md → phase3-consistency.md → phase3-5-masterplan-crossvalidate.md → phase4-merge.md
```

## Errors liên quan

- **E001/E002** — Files scan không tồn tại → STOP, yêu cầu chạy `/audit-devkit-scan` trước
- **E003/E004** — JSON invalid → retry 3 lần, sau đó STOP yêu cầu re-scan
- **E005** — Spot-check fail >20% → WARNING, yêu cầu re-scan

Chi tiết: `_shared.md §Error Handling Reference`.
