# wf-fix-bugs v11.0.0 — Quality Fix Plan

> **Mục tiêu**: Khắc phục 7 root causes phát hiện qua session E2E `2026-05-16-module-settings-01` (EUREKA-2026, module=settings, profile=exhaustive). Skill báo "DONE" nhưng chỉ fix 38% issues; 62/119 deferred trong đó nhiều items đáng lẽ phải auto-fix.

**Khởi tạo**: 2026-05-17
**Owner**: cntt@erktransport.com
**Status**: PLANNING → IMPLEMENTATION
**Version target**: v10.18.0 → v11.0.0 (major bump do thay đổi behavior Phase 6)

## Tài liệu trong plan này

| File | Mục đích |
|------|---------|
| [README.md](README.md) | Trang chủ — sitemap + status |
| [00-master-plan.md](00-master-plan.md) | Tổng quan 7 nhóm fix (G1-G7) + 3 waves + acceptance criteria |
| [01-root-causes.md](01-root-causes.md) | Diagnose chi tiết 7 root causes với file/line evidence |
| [02-wave1-ssot-counts.md](02-wave1-ssot-counts.md) | Wave 1: G1 (SSOT counts) + G7 (status honesty) — foundational |
| [03-wave2-fix-loop.md](03-wave2-fix-loop.md) | Wave 2: G2 (aggressive auto-loop) + G3 (defer validation) — biggest impact |
| [04-wave3-polish.md](04-wave3-polish.md) | Wave 3: G4 (cross-scope CDG) + G5 (false-positive filter) + G6 (Windows path) |
| [progress.md](progress.md) | Tracking per task (cập nhật mỗi session) |

## Pain points anh user báo

1. Skill phát hiện 119 issues nhưng chỉ fix 45 (38%) — 62 defer
2. Phase 6 thoát khi còn nhiều issues fixable bị defer
3. Báo "DONE" mơ hồ — user không biết còn nhiều việc chưa xong
4. Không tự xử lý cross-module issues
5. Báo cáo số liệu không nhất quán (35 vs 39 vs 45 trong cùng 1 session)

## Direction đã chốt (qua AskUserQuestion 2026-05-17)

- **Phase 6 loop strategy**: Aggressive auto-loop (skill tự quyết định, CDG chỉ hỏi khi sắp exhaust budget)
- **Implementation order**: Wave-based (3 waves, mỗi wave verify trước khi sang wave kế)

## Acceptance criteria tổng (toàn plan)

- Re-chạy session `2026-05-16-module-settings-01` (`--resume`): fixed_count tăng từ 45 lên ≥ 70 (60%+)
- Counts trong fix-status.json, orchestrator-summary.md, Phase6-report.md, fix-execution-result.json **PHẢI khớp 100%**
- CQG-1 không bao giờ "substance-based PASS" khi numeric deviation thực > 5%
- Quick-fix category trong fix-plan KHÔNG được defer (E062 nếu vi phạm)
- Cross-skill consumers (wf-verify-sync, wf-prepare-deployment) không bị break — backward-compat 100%
- Sessions cũ (v10.x) vẫn `--resume` được
