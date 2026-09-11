# Flag Handlers — wf-verify-sync

### `--status` handler

1. Đọc `.mc-data/work/wf-verify-sync/verify-sync-status.json` (nếu có) → lấy status, phase, timestamp từ checkpoint
2. Đọc `.mc-data/docs/_meta/verify-sync.md` (nếu có) → extract `sync_rate` thực tế từ file trên disk
3. Đọc `req-registry.json` → đếm `impl_status`: done / in_progress / not_started / skipped
4. Hiển thị cả hai: checkpoint state VÀ actual counts từ registry VÀ verify-sync.md date (nếu có)
5. Nếu `verify-sync.md` tồn tại nhưng `verify-sync-status.json` nói "in_progress" → hiển thị "(verify-sync.md đã có trên disk — checkpoint chưa đồng bộ)"
6. STOP

### `--resume` handler (RESUME RECONCILIATION)

1. READ `.mc-data/work/wf-verify-sync/verify-sync-status.json`
2. LOAD checkpoint data từ `checkpoint.json`
3. **(RESUME RECONCILIATION — dùng fingerprint):**
   - Tính lại `current_fingerprint`: đọc `req-registry.json` → lấy danh sách tất cả req_ids sorted → join bằng `|` → tạo hash string ngắn (ví dụ: 8 ký tự đầu của SHA-256, hoặc `"count:N:first_id:last_id"` nếu không có crypto).
   - So sánh `current_fingerprint` với `checkpoint.registry_state.fingerprint`:
     - **Khớp:** Registry không thay đổi → resume bình thường
     - **Không khớp (hoặc checkpoint fingerprint = null):** WARN: "Registry đã thay đổi kể từ checkpoint (fingerprint mismatch). Kết quả resume có thể không chính xác." → hỏi user:
       - **FULL SCAN** — chạy lại từ Phase 1 (recommended, đảm bảo chính xác)
       - **PARTIAL RESUME** — re-run Phase 1 Group A (collect REQ-IDs mới) nhưng giữ Phase 1 Group B (code scan từ checkpoint) — nhanh hơn full scan, vẫn chính xác về REQ-ID set
       - **FORCE RESUME** — tiếp tục từ checkpoint nguyên trạng (không recommended — kết quả có thể thiếu REQ-IDs mới hoặc bao gồm REQ-IDs đã xóa)
4. CONTINUE từ `next_action` trong status file
