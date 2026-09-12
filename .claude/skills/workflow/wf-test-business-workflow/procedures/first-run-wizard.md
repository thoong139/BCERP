# Procedure: First-Run Wizard — wf-test-business-workflow

> Chạy khi machine config chưa tồn tại hoặc user gọi `--setup-machine`.
> Hỏi user từng cấu hình, ghi 2 nơi: auto-memory (nguồn chính) + `_runs/.machine-mirror.json` (cho scripts).

## Machine Config Path

- **Nguồn chính:** file `wf-test-business-workflow-machine.md` trong **auto-memory directory của
  project hiện hành**. Đường dẫn tuyệt đối phụ thuộc máy — lấy từ memory dir đang chạy session này
  (trên máy hiện tại: `C:\Users\Admin\.zcode\cli\memories\projects\bc-working-b53f93206c3319df\memory\`).
- **Mirror (bắt buộc):** `.mc-data/work/wf-test-business-workflow/_runs/.machine-mirror.json` —
  scripts (`next-session.py`, `next-session.ps1`) đọc file này vì không truy cập được auto-memory.
- Hai nơi PHẢI đồng bộ; wizard ghi cả hai, Step 0.2 đọc auto-memory trước, fallback mirror.

## Wizard Steps

```
W1. FE base URL:
    "erp-web đang chạy ở URL nào? [default: http://localhost:3000]"
    → $FE_BASE_URL

W2. Backend health endpoint:
    "backend health check URL? [default: http://localhost:5048/health]"
    → $BE_HEALTH_URL

W3. Backend rebuild wait (giây, sau khi sửa code backend):
    "Đợi bao lâu sau rebuild backend? [default: 90]"
    → $BE_REBUILD_WAIT_SEC

W4. VS Code app process name (dùng cho spawn):
    "Tiến trình editor đang chạy Claude Code? [candidates: Code | Cursor | Windsurf | Antigravity] [default: Code]"
    → $VSCODE_APP

W5. Test accounts location:
    "File test accounts (tùy chọn)? [default: {SESSION_DIR}/shared/test-accounts.md — sinh trống nếu chưa có]"
    → $TEST_ACCOUNTS_PATH

W6. Verify:
    - GET $FE_BASE_URL → 200|302?
    - GET $BE_HEALTH_URL → 200?
    Cả hai fail → WARN (ghi config vẫn, chạy thật sẽ E004/E005)
```

## Ghi Config

```
.machine-mirror.json (bắt buộc):
{
  "fe_base_url": "...",
  "be_health_url": "...",
  "be_rebuild_wait_sec": 90,
  "vscode_app": "Code",
  "test_accounts_path": "...",
  "setup_at": "<ISO8601>"
}

wf-test-business-workflow-machine.md (auto-memory, human-readable):
  Tựa + bảng các giá trị trên + ngày setup.
```

## Exit

- In: "✅ Machine config saved." → quay lại Step 0.2 (load config) hoặc exit nếu `--setup-machine`.
