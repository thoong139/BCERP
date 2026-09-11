# Phase 7 Group G — TodoWrite + Completion Display (Steps 7.7 + 7.8)

> **Entry condition:** Group F POST-GATE PASS (pipeline_status=DONE + TRACE COMPLETE dual-write).
> **Exit condition:** TodoWrite marks all phases completed + UI completion display rendered.
> **Next:** [phase7-verify/POST-GATE.md](POST-GATE.md) (T1-T5 validation + fix-impact.json schema check) → END.
>
> **Shared protocols cần thiết:** None (orchestrator UI tools only).

> **⚠ GIỮ ORCHESTRATOR-SIDE — KHÔNG extract sang script:** TodoWrite + Completion Display là UI tools (CORE-037), KHÔNG script được. Cross-ref BHV-004 (Goal-Driven Execution).

## Input contract (env vars từ Group F)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$SESSION_ID`, `$PROFILE`, `$SCOPE` | Session identity |
| `$DIMS_ARRAY`, `$TOTAL_ISSUES`, `$FIXED_COUNT`, `$DEFERRED_COUNT`, `$FAILED_COUNT` | Counts |
| `$E005_HEALTHY` | Pipeline state |
| `phase7-verify/{orchestrator-summary.md, fix-impact.json, Phase7-report.md}` | Output paths cho user reference |
| `bug-dashboard.md` | Output path cho user reference |

## Output contract (passing sang POST-GATE)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| TodoWrite state | 7.7 | All 7 phases marked completed |
| Completion Display | 7.8 | UI output (text to user) |

---

## Step 7.7 — TodoWrite: Mark All Phases Complete

> **GIỮ orchestrator-side** — UI tool, không script được.

**Mục đích:** Cập nhật TodoWrite đánh dấu Phase 7 + toàn bộ pipeline hoàn thành.

**Thực thi (orchestrator gọi TodoWrite tool trực tiếp):**

```
TodoWrite: tất cả 7 phases = completed, Pipeline = DONE
```

**Cross-ref:** BHV-004 (Goal-Driven Execution), CORE-037.

---

## Step 7.8 — Completion Display

> **GIỮ orchestrator-side** — UI display, không script được.

**Mục đích:** Hiển thị summary cuối cùng cho user.

**Thực thi (UI output — orchestrator print text):**

```
✅ wf-fix-bugs pipeline HOÀN THÀNH

📊 Tổng kết phiên: $SESSION_ID
   Profile: $PROFILE | Scope: $SCOPE
   Dimensions: $(echo "$DIMS_ARRAY" | wc -w) lanes

🔍 Phát hiện: Total signals → $TOTAL_ISSUES issues
🔧 Kết quả: Đã sửa: ${FIXED_COUNT:-0} | Hoãn: ${DEFERRED_COUNT:-0} | Thất bại: ${FAILED_COUNT:-0}

📁 Outputs:
   Bug Dashboard: $SESSION_DIR/bug-dashboard.md
   Fix Impact:    $SESSION_DIR/phase7-verify/fix-impact.json
   Summary:       $SESSION_DIR/phase7-verify/orchestrator-summary.md

📋 Next steps:
   1. /wf-verify-sync --from-fix-bugs — đồng bộ requirement-to-code
   2. /status — xem tổng quan dự án
   3. git diff — review tất cả changes
```

Nếu `E005_HEALTHY=true`:

```
✅ Hệ thống HEALTHY — không phát hiện lỗi
📊 ${DIMS_COUNT} chiều kiểm tra đã chạy, không tìm thấy vấn đề.
📋 Next: /status — xem tổng quan dự án
```

**Cross-ref:** CORE-028 (tiếng Việt, cho người không chuyên), BHV-004.

---

## Group G POST-GATE Verify

```bash
# TodoWrite + Display là UI tools — không có file output để verify
# POST-GATE Group G mặc định PASS sau khi orchestrator gọi 2 tools
echo "Group G PASS (TodoWrite + Completion Display rendered)"
```

## Next: Phase 7 POST-GATE

→ Đọc [`phase7-verify/POST-GATE.md`](POST-GATE.md) để validate T1-T5 (includes fix-impact.json schema check + cross-skill artifact CORE-036).
