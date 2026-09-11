# Canonical Conflict CDG — wf-verify-sync (Phase 6 Step 6.2c)

> Triggered khi canonical `.mc-data/docs/_meta/verify-sync.md` mtime > session_start_at + tolerance.
> Mục đích: bảo vệ canonical khỏi bị overwrite bởi phiên cũ hơn khi 2 phiên chạy concurrent.

**Tolerance:** `$MCV3_VERIFY_SYNC_CDG_TOLERANCE_SEC` (env var, default: `5` giây).

**CDG options:**
```
[!] Canonical verify-sync.md đã được cập nhật sau khi phiên này bắt đầu.
    Canonical modified: [canonical_mtime_human]
    Phiên này bắt đầu: [session_start_at]
    Session copy: $SESSION_DIR/verify-sync.md (đã ghi)

Chọn:
  [1] Override  — ghi đè canonical với report của phiên này
  [2] Skip canonical — giữ nguyên canonical, chỉ giữ session copy
  [3] Cancel  — rollback (xóa session copy, kết thúc không ghi gì)
```

**Decision log:** Ghi vào `$SESSION_DIR/checkpoint.json`.`canonical_decision` field.

**Cross-platform mtime:**
```bash
# Linux / Git Bash
canonical_mtime=$(stat -c %Y .mc-data/docs/_meta/verify-sync.md 2>/dev/null)
# macOS
canonical_mtime=$(stat -f %m .mc-data/docs/_meta/verify-sync.md 2>/dev/null)
# Python fallback
canonical_mtime=$(python3 -c "import os; print(int(os.path.getmtime('.mc-data/docs/_meta/verify-sync.md')))" 2>/dev/null)
# Use first non-empty result
```
