# Workload Gate Report

## Thông tin chung
- Skill: wf-design-ux v4.1.0
- Profile: Standard → LPM override (systems=6 ≥ 5 → Large Project Mode ON, max_parallel_agents=3)
- Session: `20260913-080222-df29`
- Ngày: 2026-09-13T08:08:00+07:00

## Workload Estimate
- Tổng items (UI modules): 15 (14 SYS-BCERP-WEB + 1 SYS-PORTAL-WEB)
- Số partitions: 15 (group by module_id, max 5/partition)
- Ước lượng thời gian: **90 phút** (60 phút base × 1.5 complexity factor — avg 8.5 features/module > 3 screen_groups/module)
- Threshold: 45 phút
- Nguồn: `partition/planner.py` + `partition/workload_gate.py` (chạy thực, không fallback)

## Gate Decision
- **Status:** `block`
- **Ratio:** 2.0x

**Plan A/B/C theo procedure:**
- A. Narrow scope — chỉ 1 system
- B. Override + CDG-A02 — tiếp tục full scope với risk confirm
- C. Partition sequential — chạy từng partition một, mỗi lần 1 batch

**Quyết định áp dụng: Option C — partition sequential** (ghi `partition_sequential: true` vào session-state.json).
Lý do: user gọi skill full-scope (`all`) ngoài tương tác; C giữ nguyên scope, tuân thủ gate không cần CDG override, và trùng với chiến lược LPM checkpoint-per-system sẵn có. User có thể override bằng `--resume` + chọn B/A nếu muốn.

## Chi tiết Partitions

| # | Group Key | Items | Ước lượng (phút) |
|---|-----------|-------|-------------------|
| 1 | MOD-HR-CORE | 1 | 6.0 |
| 2 | MOD-CRM-PIPELINE | 1 | 6.0 |
| 3 | MOD-QUOTATION-DEALDESK | 1 | 6.0 |
| 4 | MOD-ADACCOUNT-CC | 1 | 6.0 |
| 5 | MOD-WALLET-RECON | 1 | 6.0 |
| 6 | MOD-ARAP-PAYMENT | 1 | 6.0 |
| 7 | MOD-HANDOFF-ONBOARD | 1 | 6.0 |
| 8 | MOD-PROPOSAL-PLANNING | 1 | 6.0 |
| 9 | MOD-CAMPAIGN-DELIVERABLE | 1 | 6.0 |
| 10 | MOD-CAPACITY-TIMESHEET | 1 | 6.0 |
| 11 | MOD-SLA-NOTIF | 1 | 6.0 |
| 12 | MOD-TICKET-CSKH | 1 | 6.0 |
| 13 | MOD-COMMISSION-QUOTA | 1 | 6.0 |
| 14 | MOD-KPI-PERFORMANCE | 1 | 6.0 |
| 15 | MOD-CLIENT-PORTAL | 1 | 6.0 |

**Ngoài partition (cross-system mobile surfaces):** SYS-MOBILE-INTERNAL (30 feat files), SYS-MOBILE-PORTAL (5 feat files) — không có module riêng; xử lý ở Phase 2 Step 2.0 screen inventory + Phase 3 lanes theo feature nhóm mobile.

## api-only Conditional Check (Step 0.5.0)
- `interface_type = "web+mobile"` ≠ api-only → KHÔNG skip, tiếp tục Phase 1.
