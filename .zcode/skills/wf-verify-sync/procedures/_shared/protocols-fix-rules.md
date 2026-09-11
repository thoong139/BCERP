# Protocols & Fix Rules — wf-verify-sync

> **Protocol:** Xem `.claude/skills/protocols/`

- **Accuracy Assurance** (mọi phase): POST-GATE Enforcement + Fix Rules + Error Tracking
- **Auto-Correction Loop** (Phase 5): max 3 iterations
- **Context & Checkpoint**: thresholds 65/80/90%
- **Registry Safe-Write** (Phase 6): CHỈ update field `impl_status` per REQ-ID — **KHÔNG downgrade "done"**
- **Token Limit Prevention** (Protocol 6): Scan-based skill — N/A cho agent spawning. Phase 1 dùng bash script `vs-scan-code.sh` (v4.0+ S4). Registry safe-write thực hiện trong main conversation.
- **Parallel Execution** (Protocol 7): Phase 1 — collect REQ-IDs + scan code chạy đồng thời (groups A và B độc lập).
- **Content Quality Gate** (Protocol 8): Phase 5 — verify sync_rate tính đúng, gap list đầy đủ (CQG-12).
- **Task Planning** (Protocol 9): N/A — scan-based skill, workload dự đoán được.
- **Phase Summary** (Protocol 14, CORE-028): Phase 6 — tạo `phase-summary.md` cuối skill.
- **Session Log** (Protocol 15, CORE-026): START entry tại Phase 0, COMPLETE entry tại Phase 6.
- **Template Usage Rule** (Protocol 19, CORE-031): Mọi output có template PHẢI READ → POPULATE → WRITE.

## Fix Rules đặc thù

| Error Type | Auto-Fix Strategy | Escalate If |
|-----------|-------------------|-------------|
| `arithmetic_error` | Recalculate từ source data | Logic conflict |
| `overlap_detection` | Remove duplicate entries | Semantic conflict |
| `invalid_req_format` | Fix REQ-ID format to standard | Cannot determine correct format |
| `duplicate_id` | Merge/deduplicate | Semantic conflict |
| `missing_file` | Log warning, mark as gap | N/A (expected for gaps) |
| `stale_status` | Re-scan code file | File not found |

**Error Tracking:** Mọi error log vào `error_log[]` — include trong Output Report (Phase 6).
