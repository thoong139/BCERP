# Procedure: Phase 4 SPAWN NEXT SESSION — wf-test-business-workflow

## PRE-GATE

`status=done|blocked (not inprogress)`

## Step 4.0 — Phase Completeness Audit (BẮT BUỘC)

```
Mục đích: phát hiện step bị bỏ qua do context compaction, interrupt, hoặc lỗi logic.
Chạy TRƯỚC pre-exit verification, TRƯỚC khi ghi checkpoint.

CHECKLIST (đánh dấu true/false vào checkpoint.steps_completed):

  Phase 1:
    1.1_parse_spec          — WF spec đã được đọc?
    1.2_run_parse_script    — parse-workflow-spec.py đã chạy (hoặc manual parse)?
    1.3_resolve_accounts    — test accounts đã được map từ §3 Actors?
    1.4_naming_gap_check    — naming gaps đã được kiểm tra?
    1.5_write_analysis      — workflow-analysis.md đã được ghi?

  Phase 2:
    2.1_write_spec          — {WF-id}.spec.ts đã tồn tại tại e2e/wf/?
    2.2_first_run           — pnpm e2e đã chạy ít nhất 1 lần?
    2.3_fix_loop            — fix loop đã chạy đến khi pass/escalate?
    2.4_mcp_verify          — Playwright MCP login + happy path + ≥1 screenshot?
    2.5_record_results      — test-status.json đã được update?

  Phase 3:
    3.1_map_agent           — domain expert agent đã được xác định?
    3.2_spawn_agents        — developer + domain agent đã được spawn?
    3.3_compose_presentation — presentation.md đã được ghi?
    3.4_update_readme       — _presentations/README.md đã được update?

RULES:
  - NẾU step = false → ghi vào steps_skipped[] + skip_reasons{} trong checkpoint
  - NẾU 2.4_mcp_verify = false → BẮT BUỘC chạy ngay trước khi spawn (không được bỏ qua)
  - NẾU 3.3_compose_presentation = false → BẮT BUỘC ghi presentation trước khi spawn
  - Các step khác = false → ghi rõ lý do, tiếp tục (không block spawn)
  - NẾU steps_skipped[] không rỗng → log rõ "⚠ SKIPPED STEPS: [list]" trước khi spawn
```

## Step 4.1 — Pre-exit Verification (BẮT BUỘC)

```
NẾU status = done (PASS):
  ✓ presentation.md tồn tại + size > 500 bytes
  ✓ SESSION_DIR/playwright/evidence/{WF-id}/ có ≥1 .png
  ✓ _runs/checkpoints/{WF-id}.json tồn tại

NẾU status = blocked:
  ✓ SESSION_DIR/bugs/ có ≥1 BUG-{NNN}.json
  ✓ _runs/checkpoints/{WF-id}.json tồn tại, status=blocked

NẾU thiếu artifact → fix ngay, KHÔNG spawn trước khi đủ (E011)
```

## Step 4.2 — Ghi Checkpoint + Update progress.json

```
Checkpoint: _runs/checkpoints/{WF-id}.json (templates/checkpoint.json populated)
  - steps_completed{}, steps_skipped[], skip_reasons{}
  - session_dir, timestamps

progress.json (atomic write):
  status = done | blocked
  presentation_path set (nếu done)
  checkpoint path, completed_at = ISO8601
```

## Step 4.3 — Digest (mỗi 10 WF done)

```
NẾU done_count % 10 == 0:
  Ghi _runs/digest-{timestamp}.md với summary 10 WF vừa xong
  (WF list, test_status distribution, bugs count,escalations)
```

## Step 4.4 — Kill-switch Re-check

```
NẾU _runs/STOP tồn tại → exit ngay (không spawn)
```

## Step 4.5 — Regenerate prompt-template.md

```
1. Đọc templates/prompt-template.md
2. NẾU đang trong --set mode (tồn tại SESSION_DIR/_set.json):
     - Đọc _set.json → lấy danh sách set
     - Prompt = "/wf-test-business-workflow --set={comma-separated-list}"
   NẾU không có --set:
     - Prompt = "/wf-test-business-workflow --resume"
3. Ghi _runs/prompt-template.md với prompt đã resolved
```

## Step 4.6 — Invoke Spawn Script (BẮT BUỘC — KHÔNG được bỏ qua)

> Đây là cơ chế cốt lõi của autonomous loop. Mỗi WF xong **PHẢI** chạy script này.
> KHÔNG tự tiếp tục WF tiếp theo trong cùng session — context blow-up sau vài WF.

```
NẾU --no-spawn → bỏ qua (exit gọn, dùng khi test 1 WF đơn lẻ)
NẾU --dry-run  → bỏ qua

LUÔN chạy với -X utf8 để tránh encoding error trên Windows:
  python -X utf8 scripts/next-session.py --runs-dir .mc-data/work/wf-test-business-workflow/_runs

Script thực hiện:
  1. Kiểm tra STOP file
  2. Kiểm tra còn pending workflows
  3. Copy _runs/prompt-template.md vào clipboard
  4. Kích hoạt cửa sổ editor (VS Code/Cursor/...) → command palette (Ctrl+Shift+P)
     → "Claude Code: New Tab" → paste prompt → Enter
  5. Tab mới tự chạy WF tiếp theo

Exit 0 → spawn OK hoặc STOP → EXIT session ngay (KHÔNG làm gì thêm)
Exit 1 → FALLBACK MODE: log rõ "FALLBACK: spawn failed, continuing in-session"
          → quay lại Step 0.5 claim WF tiếp theo trong session hiện tại
          → lặp đến hết pending hoặc STOP hoặc context > 70% (E002)

Windows alternative: scripts/next-session.ps1 (PowerShell native, cùng logic).
```

## POST-GATE

`checkpoint exists && progress.json status correct && (spawned OR --no-spawn)`
