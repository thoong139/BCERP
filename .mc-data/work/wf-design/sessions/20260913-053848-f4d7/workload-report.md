# Workload Report — /wf-design BCERP

| Mục | Giá trị |
|-----|---------|
| **Session** | 20260913-053848-f4d7 |
| **Timestamp** | 2026-09-13T05:50 (+07) |
| **systems_count** | 6 (all ACTIVE — không có DEPRECATED) |
| **partitions_count** | 2 (max_per_partition=3, group_key=system) |
| **Partition 1** | SYS-BCERP-WEB, SYS-CORE-BACKEND, SYS-INTEGRATION-GW |
| **Partition 2** | SYS-PORTAL-WEB, SYS-MOBILE-INTERNAL, SYS-MOBILE-PORTAL |
| **est_minutes_per_item** | 15.0 |
| **workload_factor** | 1.0 (new project, architecture_style=standard, LEGACY_MODE=false) |
| **total_estimated_minutes** | **90** (6 × 15 × 1.0) |
| **threshold_minutes** | 45 → ratio = 2.0 |
| **gate_result** | **block** (ratio > 1.5) |
| **user_decision** | AskUserQuestion không nhận được trả lời (autonomous run) → default theo khuyến nghị gate: **C. Partition tuần tự** — thực thi Partition 1 → Partition 2 trong cùng session, checkpoint per phase + per sub-step (LPM). Nếu context ≥ 80% → FORCE SAVE, tiếp tục bằng `/wf-design --resume`. Không dùng CDG-A02 (không override rủi ro). |

## Ghi chú thực thi

- Partition 1 chạy trước: BCERP-WEB (58 FEAT/14 MOD), CORE-BACKEND (59 FEAT/2 MOD), INTEGRATION-GW (11 FEAT/2 MOD).
- Partition 2: PORTAL-WEB (7), MOBILE-INTERNAL (30), MOBILE-PORTAL (5) — thin clients, phụ thuộc API của partition 1.
- Phase 3–8 chạy sau cả 2 partition (aggregation cần signals đầy đủ).
- Lane concurrency: max 3 agents song song (LPM), checkpoint sau mỗi lane/spec.
