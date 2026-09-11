# 01 — Vision & Principles

> **Mục đích file:** Lý do tồn tại + scope + non-goals của orchestrator `wf-e2e-verify`.

---

## 1. Tóm tắt

`wf-e2e-verify` giải quyết bài toán **"feature đã code rồi nhưng chưa biết có chạy end-to-end không"** bằng cách **điều phối 11 sub-skills chuyên trách thành 1 pipeline test mượt** (F0 infra → F0a finding → F0b seed → F1 test → F2 browser → F3 unblock → F4 implement → F5 retest → F6 fix → F7 scenario → F8 demo), với anti-loop F6↔F5 và backward-compat hoàn toàn cho legacy flags.

Đây là **skill hồi sinh** từ monolithic `wf-e2e-verify v6.5.0` (2,424 dòng SKILL.md). v7.0.0 chia tách thành 8 sub-skills (≤500 dòng SKILL.md mỗi). v8.0.0 thêm F0/F0a/F0b foundation refactor — Tier 0 separates FIND (mapping business) khỏi LIVE TEST.

---

## 2. Vấn đề trước khi có skill

| Hiện trạng (v6.5.0) | Pain point |
|---------------------|-----------|
| Monolithic SKILL.md 2,424 dòng | Đọc 30 phút mới hiểu phase nào làm gì |
| Mọi phase trộn lẫn (find + test + fix + scenario) | Khi 1 phase fail → không biết next step, phải đọc full SKILL |
| Không có skip rule → mọi feature đều chạy đủ 8 phases | Feature đơn giản 5 phút mất 25 phút |
| Backward-compat khi đổi pipeline = breaking change | User cũ phải học lại flags |
| Anti-loop không có → fix gây regression chạy mãi | Wastes hours khi issue không thể fix surgical |
| FIND (mapping business) trộn với LIVE TEST | Context fail khi mapping lớn → cả pipeline fail |

**Ví dụ thực tế:** Trước v7.0, user gõ `/wf-e2e-verify FEAT-EW-CRM-001 --fix=path/to/issues.json` → skill chạy 30 phút cả 8 phase chỉ để fix 1 issue. v7.0 detect `--fix=<path>` → jump thẳng F6 standalone (2 phút). v8.0 thêm F0a tách FIND ra → khi mapping business cần 50% context → skill suggest `/clear + --resume` trước F1.

---

## 3. Mục tiêu skill (SMART)

| # | Mục tiêu | Đo bằng |
|---|----------|--------|
| 1 | Mỗi sub-skill ≤500 dòng SKILL.md (lazy-load CORE-032) | grep wc -l SKILL.md |
| 2 | Backward-compat 100% — legacy flags `--playwright-mcp`, `--cross-module`, `--parallel-safe`, `--fix=`, `--retest`, `--unblock-test`, `--phase=` work với silent WARN | TC-ORCH-004, TC-ORCH-005 |
| 3 | Anti-loop F6↔F5 max 3 vòng — không infinite loop khi issue không thể fix | TC-ORCH-003 |
| 4 | Resume mid-pipeline (sau crash) không re-run F1-F3 đã done | TC-ORCH-006 |
| 5 | Conditional skip — F3/F4/F6 chỉ chạy khi có signal (block-test/implement-required/issues) | TC-ORCH-002 |
| 6 | Cross-module + parallel-safe LUÔN ON (default, không cần flag) | Default behavior |
| 7 | `--strict-evidence` ON by default — screenshot bắt buộc F2/F7/F8 | Default behavior |

---

## 4. Nguyên tắc thiết kế

1. **Orchestrator KHÔNG tự test** — chỉ spawn 11 sub-skills sequential với conditional skip. Logic test live trong từng sub-skill. Orchestrator chỉ làm 4 việc: (a) init session + SSOT, (b) decide skip per signal, (c) anti-loop counter, (d) finalize summary.

2. **SSOT JSONs sharing pattern** — 4 SSOT JSONs (`issues.json`, `block-test.json`, `implement-required.json`, `manual.json`) ở session root, mỗi file có nhiều writers (F1+F2 APPEND, F3/F4/F6 UPDATE). Ownership rules rõ — xem [04-file-contract.md](04-file-contract.md) §SSOT JSONs.

3. **Conditional skip — signal-driven** — F3/F4/F6 chỉ chạy khi SSOT JSON tương ứng có entries. F2/F7/F8 default ON (chỉ skip với explicit `--skip=`). F0/F0a luôn chạy. F5 luôn chạy sau F4.

4. **Anti-loop F6↔F5** — Counter `f6_f5_loop_count` trong `e2e-status.json`. >3 → ESCALATE E004 AskUserQuestion. Issue marked `status=still_fail`. Tương tự F3↔F2 max 2.

5. **Backward-compat hoàn toàn** — Legacy flags silent accept + WARN deprecation. Map vào behavior mới: `--fix=<path>` → jump F6, `--retest` → F5 standalone, `--unblock-test` → F3 standalone, `--phase=7` → F7+F8 only. Tracked trong `e2e-status.json.legacy_flags_used[]`.

6. **CORE-032 Lazy-Load Procedures** — SKILL.md ~450 dòng routing hub. Logic execute trong 7 procedure files (`_shared`, `orchestrate`, `skip-rules`, `legacy-flags`, `resume-status`, `phase0-infra-check`, `phase1.5-seed-manifest`).

7. **CORE-034 Namespaced Error Codes** — Orchestrator E001-E009 + F0/F0a/F0b E010-E019 + delegated sub-skill errors. Sub-skill errors KHÔNG cascade — orchestrator wrap với context.

8. **Playwright 3-modes (CORE-038)** — `none` (chỉ static analysis cho Nhóm 4 — visual_inspection/requires_payment/etc), `assisted` (user vận hành), `full` (auto-start mandatory). v7.1.0 deprecated `--no-playwright` silent fallback — phải explicit `--skip=F2,F5,F7,F8` nếu CI không có browser.

---

## 5. Non-goals (KHÔNG làm)

Để tránh scope creep, orchestrator này **KHÔNG** xử lý:

- **Tự test business logic** — `wf-e2e-test` (F1) làm (code-based test DB+API+UI+Integration)
- **Tự run browser** — `wf-e2e-browser` (F2), `wf-e2e-retest` (F5), `wf-e2e-scenario` (F7), `wf-e2e-demo` (F8) làm
- **Tự implement code** — `wf-e2e-implement` (F4) delegate tới `wf-implement-feature`
- **Tự fix bugs** — `wf-e2e-fix` (F6) làm
- **Audit DEVKIT** — `/audit-devkit` làm
- **Performance/Security test riêng** — `wf-fix-bugs` lane QD3/QD4 làm
- **Unit test** — `wf-implement-feature` Phase 3 TDD làm

---

## 6. Tham chiếu

- Patterns áp dụng:
  - [`../../03-design-patterns/01-lazy-load-procedures.md`](../../03-design-patterns/01-lazy-load-procedures.md) — 7 procedures lazy-load
  - [`../../03-design-patterns/03-cross-skill-artifacts.md`](../../03-design-patterns/03-cross-skill-artifacts.md) — orchestrates[] in `_contract.json`
  - [`../../03-design-patterns/04-parallel-lane-dispatch.md`](../../03-design-patterns/04-parallel-lane-dispatch.md) — Spawn sub-skills (sequential, không parallel ở orchestrator level)
  - [`../../03-design-patterns/06-checkpoint-resume.md`](../../03-design-patterns/06-checkpoint-resume.md) — e2e-status.json + resume mid-pipeline
  - [`../../03-design-patterns/07-playwright-3-modes.md`](../../03-design-patterns/07-playwright-3-modes.md) — F2/F5/F7/F8 mode dispatch
  - [`../../03-design-patterns/09-multi-session-locking.md`](../../03-design-patterns/09-multi-session-locking.md) — Protocol 22 R/W lock cross-session
  - [`../../03-design-patterns/10-cdg-gate.md`](../../03-design-patterns/10-cdg-gate.md) — AskUserQuestion khi anti-loop trigger

- Standards áp dụng:
  - [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md) — Orchestrator pattern
  - [`../../02-standards/04-contract-schema.md`](../../02-standards/04-contract-schema.md) §orchestrates — multi-skill spawn

- Rules: CORE-032, CORE-033, CORE-034, CORE-035, CORE-026 (Execution Trace), CORE-028 (Phase Summary), Protocol 22 (R/W lock)
