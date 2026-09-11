# Sprint 5 — Agent Spawn Quality (wf-fix-bugs v10.3)

> **Started:** 2026-05-15
> **Completed:** 2026-05-15 ✅ DONE (5 commits, single session ~1.5h)
> **Owner:** Sprint 5 — Agent Spawn Quality (CORE-037 Compliance)
> **Scope:** 5 findings (~4h estimate; actual ~1.5h)
> **Audit:** `docs/wf-fix-bugs-audit-2026-05-15.md` §Sprint 5 + §F02 cluster
> **CORE Standards:** CORE-037 (Agent Prompt Templates 8 sections), CORE-025 (Parallel Safety, max 10), CORE-007 + CORE-036 (Contract preservation)

## State Verified (2026-05-15)

| File | Lines | Block kiểm tra | Status |
|---|---|---|---|
| `wf-fix-bugs/procedures/_shared.md` | 703 | §15 Agent Prompt Templates (lines 535-628) | Triage 4/8 + Execute 4/8 sections — DUPLICATE confirmed |
| `wf-fix-bugs/procedures/phase4-find-bugs.md` | 949 | 11 Lane Agent dispatch (lines 381-388) | Lane Agent đã có template render — KHÔNG sub-probes trong file này |
| `wf-fix-bugs/procedures/phase5-triage.md` | 1028 | Step 5.7 (lines 406-475) | **7/8 sections** (thiếu Playwright N/A) + bash comment block (lines 448-453) DUPLICATE F02.004 confirmed. Audit nói 6/8 — drift nhẹ. |
| `wf-fix-bugs/procedures/phase6-execute.md` | 950 | Step 6.5 (lines 453-519) | ~5/8 sections (thiếu Role formal, Playwright N/A, Ownership explicit). Có actual `Agent({...})` call (KHÔNG bash comment) — không cùng vấn đề F02.004. |

**Sub-probe Agent() calls (F02.003) verified — 6 calls trên 4 probe files:**

| # | File | Line | Agent name | subagent_type | Current model | Mode |
|---|---|---|---|---|---|---|
| 1 | `wf-fix-functional/procedures/probes/P-QD1-agent-feature-verify.md` | 36 | `feature-verify-{feat-id}` | `general-purpose` | MISSING | Standard |
| 2 | `wf-fix-functional/procedures/probes/P-QD1-spec-completeness-check.md` | 209 | `spec-completeness-{feat_id}` | `general-purpose` | MISSING | Standard |
| 3 | `wf-fix-business/procedures/probes/P-QD2-business-analyst-review.md` | 33-50 | `ba-flow-review` | `business-analyst` | MISSING | Standard |
| 4 | `wf-fix-business/procedures/probes/P-QD2-domain-expert-review.md` | 107-123 | `domain-review-{dept}` | `{domain}-expert` | MISSING | Standard |
| 5 | `wf-fix-business/procedures/probes/P-QD2-domain-expert-review.md` | 143-148 | `boundary-...-domainA` | `{pair.domainA}-expert` | MISSING | Boundary lvl 3 (consumer) |
| 6 | `wf-fix-business/procedures/probes/P-QD2-domain-expert-review.md` | 149-154 | `boundary-...-domainB` | `{pair.domainB}-expert` | MISSING | Boundary lvl 3 (provider) |

**Concurrency state (F02.011):** Boundary mode hiện spawn 2 agents/pair song song (max 2 per §7.2). Tuy nhiên KHÔNG có guard nếu N pairs × 2 + 11 lanes parent vượt 10 concurrent.

## Decision Points Confirmed (User 2026-05-15)

1. **§3.1 F02.002 strategy:** Option 1 — Xoá hoàn toàn Triage + Execute blocks khỏi `_shared.md §15`, thay bằng pointer "Canonical: phase5-triage.md §Step 5.7" + "Canonical: phase6-execute.md §Step 6.5". Giữ Lane Agent Prompt section nguyên (không duplicate).
2. **§3.2 F02.005 location:** Option 1 — `_shared.md §16 'Sub-Probe Template'` (inline trong wf-fix-bugs/procedures/_shared.md). Cross-reference từ wf-fix-functional + wf-fix-business probe files.
3. **§3.3 F02.011 guard:** Option 2 — Throttle by depth (max 3 cấp 3 concurrent). Implement bằng wait-loop pseudocode trước spawn cấp 3.
4. **§3.4 F02.007-009 sections:** Confirm 3 sections cuối theo CORE-037 chuẩn (Role formal labeled, Playwright N/A, Ownership explicit).

## Findings & Status

| # | Finding | Effort (est → actual) | Strategy | Status | Commit |
|---|---|---|---|---|---|
| 1 | **F02.004** | 30min → ~5min | Replace bash comment block (Step 5.7 lines 448-453) với actual `Agent({subagent_type, model, prompt})` call. Match pattern phase6-execute.md Step 6.5. | ✅ DONE | `c1f4b139` |
| 2 | **F02.002 + F02.006** | 1h → ~15min | Xoá Triage block + Execute block khỏi `_shared.md §15`. Thay bằng 2 pointer subsections trỏ canonical Step 5.7 + Step 6.5. Lane Agent Prompt giữ nguyên. **703 → 672 dòng** | ✅ DONE | `80407d0b` |
| 3 | **F02.003** | 30min → ~10min | Thêm `model="opus"` vào 6 sub-probe Agent() calls (QD1×2 + QD2×4 Standard/Boundary). | ✅ DONE | `59370a89` |
| 4 | **F02.005 + F02.011** | 1h → ~30min | Tạo `_shared.md §16 'Sub-Probe Template'` với 4 subsections (Pattern 8 CORE-037 + Substitution Table + Reference Pattern + Concurrency Guard throttle by depth). Renumber §17/§18 + 7 cross-refs. Reference §16 từ 4 probe files. | ✅ DONE | `2c4ad8cd` |
| 5 | **F02.007-009** | 1h → ~20min | Step 5.7: thêm Playwright N/A + renumber 5→6, 6→7, 7→8 + mở rộng Ownership. Step 6.5: refactor prompt thành 8 labeled sections (Role formal, Task, Session, CI, Playwright N/A, Output, Ownership, Completion). | ✅ DONE | `669345b9` |

## Quality Gates (DỪNG nếu gặp)

- ❌ Sửa prompt làm mất output path → contract preservation fail
- ❌ Sub-probe template tạo dual source of truth mới (anti-pattern F02.002)
- ❌ Concurrency guard chọn pattern làm chậm pipeline > 50% (sequential lvl 3 risk — đã từ chối)
- ❌ Agent tool call format mới không khớp với Claude Code SDK syntax
- ❌ Context budget > 80% (checkpoint per CORE-038)

## Completion Criteria — ALL MET ✅

- ✅ F02.004 — Step 5.7 có actual `Agent({...})` call (không phải bash comment)
- ✅ F02.002+006 — `_shared.md §15` Triage + Execute blocks xóa, thay 2 pointer subsections; Lane Agent Prompt giữ nguyên
- ✅ F02.003 — 6 sub-probe Agent() calls có `model="opus"` parameter
- ✅ F02.005 — `_shared.md §16 'Sub-Probe Template'` tồn tại với 8 CORE-037 sections + Substitution Table + Reference Pattern
- ✅ F02.007-009 — Step 5.7 (8/8) + Step 6.5 (8/8) có đủ sections (Role formal labeled, Playwright N/A explicit, Ownership explicit)
- ✅ F02.011 — Boundary mode QD2 có concurrency guard pattern: throttle by depth (max 3 cấp 3 → tổng cap 8 < 10 CORE-025)
- ✅ Cross-skill contracts preserved (output paths `phase5-triage/` + `phase6-execute/` trong prompts grep verified)
- ✅ Plan file status DONE per finding
- ✅ Audit report append "Sprint 5 Closed 2026-05-15"

## Audit Drifts Detected (3)

1. **§15 Execute prompt sections:** Audit nói 3/8, verify thấy 4/8 (Task, Session, CI, Completion). Sai số nhỏ — không ảnh hưởng decision.
2. **Step 5.7 sections:** Audit nói 6/8, verify thấy 7/8 (labels 1-4 + 5-7 already present). Pivoted: chỉ cần thêm Playwright N/A + renumber.
3. **Boundary Mode "cấp 3" terminology:** Audit gọi sub-sub-agents là cấp 3 (3 nested levels), verify thấy actual code là max 2 song song trong cùng pair (consumer + provider). Guard pattern (throttle by depth) vẫn đúng INTENT.

**Bài học (giống Sprint 3+4):** LUÔN verify state thực tế trước khi áp dụng audit recommendation — audit có thể stale hoặc có thuật ngữ không chính xác.

## Decision Notes

**Audit drift candidate (Step 5.7 sections):** Audit nói 6/8, verify thấy 7/8 (đủ Role, Task, Session, CI, Output, Ownership, Completion — chỉ thiếu Playwright N/A). Tuy nhiên Role chưa được label rõ ràng `**1. Role:**` — đã có inline "Bạn là wf-fix-triage agent..." với label `**1. Role:**` rồi (kiểm tra lại). Confirm: 7/8 visible. Pivoted: chỉ cần thêm Playwright N/A.

**Sub-probe template scope:** Template ở `wf-fix-bugs/procedures/_shared.md §16` mặc dù probe files thuộc lane skills khác — đây là tổ chức intentional: orchestrator (wf-fix-bugs) define canonical sub-probe prompt pattern, lane skills consume. Tránh duplicate template cho mỗi lane (F02.002 anti-pattern).

**Concurrency guard implementation:** Throttle by depth chọn vì cân bằng safety + speed. Pattern pseudocode (không phải production code đầy đủ — orchestrator script là responsibility của runtime Python `_shared/concurrency/`). Document pattern trong probe markdown để runtime biết constraint.
