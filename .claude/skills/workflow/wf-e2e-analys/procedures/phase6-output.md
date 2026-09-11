# Phase 6: OUTPUT — Chi tiết procedure

## 6.1 — Tổng hợp findings

Trước khi sinh output, đọc lại:
- `findings/business-understanding.md` → actors, flow, business rules
- `findings/api-mapping.md` → endpoints, permissions
- `findings/ui-mapping.md` → pages, hooks
- `integration-test-report.md` → pass/fail per action

## 6.2 — Sinh test-scenario.md

Template: `test-scenario.template.md`

Sinh ít nhất:
- **1 Happy path scenario**: full flow từ đầu đến cuối với dữ liệu hợp lệ
- **1 Validation error scenario**: nhập dữ liệu sai, verify error message
- **1 Permission scenario**: user không có quyền, verify bị block
- **Edge case scenarios** từ business rules (mỗi BR quan trọng → 1 scenario)

Format per scenario:
```markdown
## Kịch bản {N}: {Tên mô tả ngắn}

**Loại:** Happy path | Validation error | Auth error | Edge case
**Precondition:** {điều kiện phải có trước}
**Actors:** {role cần thiết, vd "Finance Manager"}
**Dữ liệu test:** {từ seed data Phase 2, vd "Bản ghi #3 từ db-seed-data.md"}

| Bước | Hành động | Kết quả mong đợi | Kết quả thực tế | Pass/Fail |
|------|-----------|-----------------|-----------------|-----------|
| 1    | ...       | ...             | (để trống — người test điền) | - |
| 2    | ...       | ...             | | - |

**Ghi chú:** {nếu có}
```

## 6.3 — Sinh user-guide.md

Template: `user-guide.template.md`

Viết tiếng Việt, rõ ràng cho người dùng cuối không có kỹ thuật:

```markdown
# Hướng Dẫn Sử Dụng: {Tên tính năng}

> Phiên bản: 1.0 | Cập nhật: {date} | Module: {module name}

## Giới thiệu

{1-2 câu mô tả tính năng phục vụ gì}

## 1. {Tên hành động chính — dùng động từ}

**Điều kiện:** {role cần có, vd "Cần quyền Finance Manager"}

**Các bước:**

1. Truy cập menu **{tên menu}** → chọn **{tên mục}**
2. Nhấn nút **[{tên nút}]** ở góc {vị trí}
3. Điền thông tin vào form:
   - **{Tên trường}** _(bắt buộc)_: {mô tả, ví dụ định dạng}
   - **{Tên trường}** _(tuỳ chọn)_: {mô tả}
4. Nhấn **[Lưu]** để xác nhận

**Kết quả:** Hệ thống hiển thị thông báo "_[tên toast message]_" và danh sách được cập nhật.

**Lỗi thường gặp:**
- _{lỗi 1}_: {nguyên nhân và cách xử lý}
```

## 6.4 — Phase summary (CORE-028)

Đọc template `.claude/doc-framework/_meta/phase-summary.template.md`.
Điền: feature name, phases chạy, kết quả tổng, vấn đề phát hiện, action items.
Ghi `phase-summary.md`.

## 6.5 — CORE-026 COMPLETE trace

```bash
echo "{\"event\":\"COMPLETE\",\"skill\":\"wf-e2e-verify\",\"session\":\"$SESSION_ID\",\"feat_id\":\"$FEAT_ID\",\"ts\":\"$(date -Iseconds)\"}" \
  >> .mc-data/work/_trace/session-log.json
```

## 6.6 — Update status.json

```json
{
  "phase_6_status": "done",
  "current_phase": 6,
  "sub_state": "DONE"
}
```

## 6.7 — Stop heartbeat daemon + release locks (v1.2.0)

```bash
# Chỉ stop nếu F1 standalone start daemon (không qua orchestrator).
# Khi spawn qua wf-e2e-verify, orchestrator stop daemon ở finalize step.
if [ -f "$SESSION_DIR/_locks/global-lock-daemon.meta.json" ]; then
  STARTED_BY=$(jq -r '.started_by_orchestrator // false' "$SESSION_DIR/_locks/global-lock-daemon.meta.json" 2>/dev/null || echo false)
  if [ "$STARTED_BY" != "true" ]; then
    bash .claude/scripts/wf-e2e-shared/lock-daemon.sh stop "$SESSION_DIR"
  fi
fi
```

Daemon stop sẽ release tất cả reader/writer locks của session khỏi `.mc-data/_global_locks/*.lock`.

## Kết thúc — Thông báo user

```
✅ /wf-e2e-verify hoàn thành cho {FEAT-ID}: {tên feature}

📁 Session: {SESSION_DIR}
📋 Kịch bản test: outputs/test-scenario.md ({N} kịch bản)
📖 Hướng dẫn: outputs/user-guide.md
🗄️ Seed data: findings/db-seed-data.md (~20 bản ghi)

Phase results:
  Phase 1 (Business): ✅ Verified bởi user ({N} bổ sung)
  Phase 2 (DB):       ✅ {N} tables mapped, {M} bản ghi seed
  Phase 3 (API):      ✅ {N} endpoints tested
  Phase 4 (UI):       ✅ {N} components analyzed
  Phase 5 (Integration): ✅ {N}/{M} actions PASS
```
