# Registry Safe-Write Rule — wf-verify-sync

> Áp dụng cho Phase 6 khi update `req-registry.json`.

**Schema reference:**

```json
{
  "project_name": "string",
  "systems": [{ "id": "string", "name": "string" }],
  "modules": [{ "id": "string", "name": "string", "system_id": "string" }],
  "requirements": [{
    "id": "REQ-XXX-NNN",
    "title": "string",
    "priority": "high|medium|low",
    "impl_status": "not_started|in_progress|done|skipped"  // ← CHỈ update field này
  }],
  "features": [...],
  "implementation_order": [...]
}
```

```
QUY TẮC BẤT DI BẤT DỊCH (CORE-008):
- KHÔNG downgrade impl_status = "done" thành giá trị khác — TUYỆT ĐỐI, KHÔNG NGOẠI LỆ
- Nếu code scan không tìm thấy REQ-ID đã done → LOG WARNING (W001) nhưng GIỮ NGUYÊN status
- Chỉ UPDATE các REQ-IDs có status KHÁC "done" (not_started, in_progress)
- Nếu code scan miss REQ-ID do format comment khác biệt → GIỮ NGUYÊN status cũ

Logic safe-update (Phase 6):
  FOR mỗi REQ-ID trong registry:
    IF registry.impl_status == "done" AND code_scan KHÔNG tìm thấy REQ-ID:
      → Đánh dấu WARNING (W001) trong report, KHÔNG tự động downgrade
      → Yêu cầu user xác nhận trước khi thay đổi
    ELIF registry.impl_status == "not_started" AND code_scan TÌM THẤY REQ-ID:
      → UPGRADE: set impl_status = "in_progress"
    ELIF registry.impl_status == "in_progress" AND code_scan TÌM THẤY REQ-ID:
      → UPGRADE: set impl_status = "done"
    ELIF registry.impl_status != "done":
      → GIỮ NGUYÊN status nếu không có evidence để thay đổi

  // $W001_ANOMALIES được tính tại Phase 2 — Phase 6 chỉ DÙNG dữ liệu này cho safe-update.
```
