# wf-implement-feature v4.0 — Improvement Plan

**Ngày tạo:** 2026-04-28
**Phiên bản từ:** v3.4.0 (2026-04-28 — đã hoàn thành 26 findings từ E2E test FEAT-STW-ACCT-002)
**Phiên bản đích:** v4.0.0
**Estimated effort:** ~14h (chia 5 sprints)
**Owner:** Claude (multi-session work, theo plan này)
**Memory ref:** `project_wf-implement-feature-v4-improvement-plan.md` (sẽ tạo sau khi user approve)

---

## Mục đích plan này

Skill `wf-implement-feature` v3.4.0 đã đạt chất lượng cao sau khi fix toàn bộ 26 findings từ E2E test. Tuy nhiên so với peer skills (`wf-fix-bugs` v6.1.1, `wf-scan-target` v2.0.1, `wf-legacy-scan` v5.0), còn 9 gaps về **đồng bộ pattern kiến trúc** — không phải lỗi correctness mà là cải thiện scalability, maintainability và multi-dev safety.

Plan này:

1. Theo dõi tiến độ refactor v3.4.0 → v4.0.0 qua 5 sprints
2. Ghi lại các quyết định kỹ thuật để các phiên làm việc sau tiếp tục được
3. Đảm bảo skill tuân thủ:
   - **Session isolation đầy đủ (CORE-030)** — multi-run preservation, audit trail
   - **Multi-developer concurrency** — JSONL history index, cross-process mutex (đã có) + pattern cache
   - **Git-sync safety** — append-only history, .gitignore conventions chuẩn
   - **Resume support** — checkpoint primary thay vì soft-resume fallback
   - **Token efficiency** — bash scripts library, pattern cache, lazy-load procedures (đã có)
   - **Cross-skill thực dụng** — output v2 với consumer_hints, OPTIONAL `--from-impl` flag

---

## Cấu trúc thư mục plan

```
plans/wf-implement-feature-v4/
├── README.md                       ← BẠN ĐANG ĐỌC (overview + status)
├── 00-master-plan.md               ← Mục tiêu, scope, roadmap, priorities
├── 01-current-state-analysis.md    ← Hiện trạng v3.4.0 + 9 gaps + so sánh peer skills
├── 02-architecture-design.md       ← Cấu trúc thư mục mới, session ID, bash scripts, profile system
├── 03-decisions-pending.md         ← 5 open questions cần user xác nhận
├── progress.md                     ← Live progress tracker (cập nhật mỗi session)
└── sprints/
    ├── sprint-1-foundation.md          ← Session isolation + bash script library + history index
    ├── sprint-2-adaptive-profile.md    ← --profile (quick/standard/deep/exhaustive) + pattern cache
    ├── sprint-3-output-utility.md      ← impl-status.json v2.0 schema + consumer_hints + global decision-registry
    ├── sprint-4-observability.md       ← error-ledger.json + namespaced error codes (E1xx-E9xx)
    └── sprint-5-evals-audit.md         ← Evals mở rộng (≥10 cases) + compliance audit + E2E test
```

---

## Quick Status

| Sprint | Mục tiêu | Status | Ngày bắt đầu | Ngày hoàn thành | E2E Tested |
|--------|----------|--------|--------------|-----------------|------------|
| 1 | Foundation: session isolation + bash scripts + JSONL history | ⏳ NOT STARTED | — | — | — |
| 2 | Adaptive: --profile flag + pattern cache | ⏳ NOT STARTED | — | — | — |
| 3 | Output utility: schema v2 + consumer_hints + global decision-registry | ⏳ NOT STARTED | — | — | — |
| 4 | Observability: error-ledger + namespaced codes | ⏳ NOT STARTED | — | — | — |
| 5 | Evals + compliance audit + E2E regression | ⏳ NOT STARTED | — | — | — |

**Plan status:** ⏳ **AWAITING USER APPROVAL** trên 5 decisions trong `03-decisions-pending.md` trước khi start Sprint 1.

---

## Cách dùng plan này qua nhiều phiên

**Phiên đầu tiên** (sau khi user approve decisions):
1. Đọc `00-master-plan.md` để nắm scope tổng thể
2. Đọc `02-architecture-design.md` để hiểu giải pháp kỹ thuật
3. Bắt đầu Sprint 1 từ `sprints/sprint-1-foundation.md`
4. Cập nhật `progress.md` sau khi hoàn thành mỗi step

**Phiên tiếp theo** (resume):
1. Đọc `progress.md` để biết sprint nào đang dở
2. Đọc sprint file tương ứng để biết step nào tiếp theo
3. Tiếp tục từ đó, cập nhật `progress.md` real-time

**Khi bị blocked:**
- Ghi blocker vào `progress.md` section "Blockers"
- Nếu cần user input → ghi vào `03-decisions-pending.md` (kèm context)
- KHÔNG tiếp tục với assumption — escalate (BHV-001)

---

## Liên quan

- Skill hiện tại: [.claude/skills/workflow/wf-implement-feature/](../../.claude/skills/workflow/wf-implement-feature/)
- Skill peer: [wf-scan-target/](../../.claude/skills/workflow/wf-scan-target/), [wf-fix-bugs/](../../.claude/skills/workflow/wf-fix-bugs/), [wf-legacy-scan/](../../.claude/skills/workflow/wf-legacy-scan/)
- Plan tham chiếu: [plans/wf-scan-target-v2/](../wf-scan-target-v2/) — completed 2026-04-28, ~17h actual / 27.5h estimated
- Memory: `project_wf-implement-feature-e2e-2026-04-28.md` — v3.4.0 release context (26 findings closed)
