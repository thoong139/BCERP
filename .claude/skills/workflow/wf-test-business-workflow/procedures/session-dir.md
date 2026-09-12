# Procedure: Session Directory & Phase 0 Dispatch — wf-test-business-workflow

> Chi tiết thực thi Phase 0. SKILL.md giữ routing table; file này chứa logic từng step.

## PRE-GATE

```
test -d .mc-data/docs/phase1-business/workflows/ && ls WF-L*.md 2>/dev/null | wc -l | grep -v ^0
```

Fail → E001: "Chưa có WF-L*.md specs. Chạy /wf-analyze-requirements trước." DỪNG.

## Step 0.0 — Kill-switch Check

```
NẾU .mc-data/work/wf-test-business-workflow/_runs/STOP tồn tại:
  - NẾU có WF đang inprogress → mark lại = pending (atomic write progress.json)
  - In: "⛔ STOP detected. Loop halted. Remove _runs/STOP to resume."
  - EXIT ngay (không spawn next)
```

## Step 0.1 — Flag Dispatch

```
--stop          → Tạo _runs/STOP file → "⛔ STOP scheduled." → exit
--status        → Đọc progress.json → in dashboard → exit (xem resume-routing.md)
--setup-machine → Chạy first-run wizard (đè config hiện tại) → exit
--resume        → Đọc test-status.json session gần nhất → route theo next_action (resume-routing.md)
--set           → Parse comma-separated WF-ID list → validate → lưu vào SESSION_DIR/_set.json
                → mark tất cả WF trong set = pending nếu chưa done
                → claim WF đầu tiên trong set có status=pending (Step 0.5)
                → NẾU tất cả trong set đã done → "✅ Set done." → exit
default         → Claim WF mới (Step 0.4)
```

## Step 0.2 — Load Machine Config

1. Đọc machine config file tại **auto-memory directory của project hiện hành**
   (path cụ thể do first-run wizard ghi — xem `first-run-wizard.md §Machine Config Path`).
2. NẾU không tồn tại HOẶC `--setup-machine` → chạy first-run wizard (`first-run-wizard.md`).
3. Đọc `_runs/.machine-mirror.json` (bản mirror cho scripts đọc được — wizard ghi cả hai nơi).

## Step 0.3 — Validate Prerequisites

```
KIỂM TRA:
  ✓ Có ≥1 file WF-L*.md tại .mc-data/docs/phase1-business/workflows/
    (glob: WF-L[0-9]-[0-9][0-9]-*.md)
  ✓ erp-web đang chạy: GET http://localhost:3000 → 200|302
  ✓ Backend đang chạy: GET http://localhost:5048/health → 200

NẾU prerequisites fail:
  - E004/E005: hướng dẫn start docker compose / pnpm dev
  - E001: hướng dẫn chạy /wf-analyze-requirements trước
  - DỪNG (không proceed)
```

> **BCERP note:** FE/BE chưa tồn tại cho đến khi Phase 5b implement xong — khi đó Step 0.3
> luôn fail với E004/E005. Đây là điều kiện chạy đúng, không phải lỗi cấu hình.

## Step 0.4 — Build/Refresh progress.json

```
1. Kiểm tra _runs/progress.json tồn tại
2. NẾU không tồn tại → chạy: python -X utf8 scripts/build-progress.py
3. NẾU tồn tại + có WF mới trong filesystem không có trong JSON → chạy lại (idempotent, preserve statuses)
```

## Step 0.5 — Claim WF

```
1. Đọc _runs/progress.json
2. Xác định target WF theo flags:
   - --workflow=WF-L{N}-{NN}: chọn WF cụ thể đó
   - --set=WF-L{A},WF-L{B},...: theo đúng thứ tự trong list.
     WF chưa có trong progress.json → thêm mới status=pending. Đã done → skip.
   - --level=L{N}: filter workflows có level=L{N}
   - --all / default: tất cả WF theo thứ tự L1-01 → L1-12 → L2-01 → ... → L6-08
3. Tìm WF đầu tiên status="pending" trong target set
4. NẾU hết pending trong target set:
   - --set mode: in "✅ Set complete: N/N workflows done." → exit
   - --all / --level mode: Đọc tất cả blocked → log summary
   - Sinh _runs/FINAL-REPORT.md (templates/final-report.template.md)
   - In: "✅ All workflows done. FINAL-REPORT.md generated."
   - EXIT (không spawn next)
5. Mark WF = inprogress, set started_at. Atomic write progress.json.
6. NẾU WF đang inprogress (conflict) + --resume: resume session đó
```

## Step 0.6 — Init Session

```
BASE_DIR    = .mc-data/work/wf-test-business-workflow
RUNS_DIR    = BASE_DIR/_runs
SESSION_ID  = YYYY-MM-DD-{WF-id}-{NN}   (auto-increment nếu collision)
SESSION_DIR = BASE_DIR/sessions/SESSION_ID
```

Tạo cấu trúc:

```
SESSION_DIR/
├── test-status.json          ← copy templates/checkpoint.json + populate WF-id, timestamps
├── workflows/                ← analysis files (Phase 1)
├── bugs/                     ← BUG-{NNN}.json
├── shared/                   ← fix-log.json, e2e-run-log.txt, test-accounts.md (optional override)
└── playwright/evidence/{WF-id}/   ← screenshots (Phase 2)
```

## POST-GATE

```
test -f _runs/progress.json && test -d $SESSION_DIR && WF status=inprogress
```
