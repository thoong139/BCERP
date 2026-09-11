# 01 — Vision & Principles

> **Mục đích file:** Lý do tồn tại + scope + non-goals của skill `wf-implement-feature`.

---

## 1. Tóm tắt

`wf-implement-feature` giải quyết bài toán **biến feature spec thành source code chạy được mà không trượt khỏi yêu cầu** bằng cách orchestrate **TDD pipeline 7-phase với parallel review + safety gate + multi-session resume**, trả về **source code + tests + impl-report + registry update**.

Đây là **skill thường được dùng nhất** trong DEVKIT — developer gõ `/wf-implement-feature FEAT-XXX` hằng ngày để code các feature đã có spec. Vì vậy mọi quyết định trong skill ưu tiên 3 thứ: **không silent overwrite code đang chạy**, **không bỏ sót REQ-ID**, **không spawn agent vô tội vạ**.

---

## 2. Vấn đề trước khi có skill

| Hiện trạng | Pain point thực tế |
|------------|-------------------|
| Developer manual đọc 3-5 file (feature spec + task + registry + existing code) trước khi code | Mất 30-60 phút/feature, dễ bỏ sót REQ-ID |
| Không có safety gate trước khi viết code mới | Đè lên code legacy đang chạy → mất giờ debug |
| Review code = chat 1-1 với reviewer (sequential) | 1 feature mất 2-3 ngày để qua review |
| Test viết sau code (test-after) | Code không testable, coverage thấp |
| Resume thủ công khi mất phiên (context full / crash) | Bỏ dở 50% công việc, phải làm lại từ đầu |
| Multi-feature implement song song = mỗi tab IDE 1 feature | Ghi đè state lẫn nhau, conflict registry |

**Ví dụ thực tế:** Một developer ERK Transport gõ `/wf-implement-feature FEAT-CRM-CUST-001`. Skill auto: (1) tìm code legacy `customer.service.ts` đã có → cảnh báo "CORE-020 found existing code, choose VERIFY_ONLY / COMPLETE_EXISTING / IMPLEMENT_NEW"; (2) đọc spec từ `phase2-features/sys-crm/mod-crm/customer-management.md`; (3) viết test trước → impl sau (TDD); (4) spawn parallel code-reviewer + qa-lead + security agents; (5) auto-fix các issue trivial; (6) update `req-registry.json impl_status=done` cho REQ-CRM-CUST-001. Tổng thời gian: 45 phút thay vì 3 ngày.

---

## 3. Mục tiêu skill (SMART)

| # | Mục tiêu | Đo bằng |
|---|----------|--------|
| 1 | Không bao giờ silent overwrite code đang chạy | CORE-020 safety gate 100% trigger trên EXTEND/MODIFY/LEGACY_MODE; eval TC-19 (Safety Scan) |
| 2 | Đảm bảo mỗi source file có REQ-ID comment | Phase 5a cross-validation auto-fix; eval #1 + #6 assertion "REQ-ID in code" |
| 3 | Cắt thời gian implement 1 feature từ 3 ngày → <1h cho feature kích thước trung bình | Profile=standard targeted 15-45 min (xem [02-arguments.md](02-arguments.md) §Profile Matrix) |
| 4 | Multi-session safe: 2 dev cùng implement 2 feature khác nhau không conflict | Per-feature lock + system-grouped layout v5; eval #12 + #17 |
| 5 | Resume khi context >80% mà không mất phiên | Checkpoint.json + context_digest injection; eval #4 |
| 6 | Test coverage ≥ threshold per profile | Phase 3 TDD enforce; Phase 4 qa-lead verify |

---

## 4. Nguyên tắc thiết kế

1. **Safety First (CORE-020) — tìm trước, viết sau** — Mọi run mới chạy lightweight existing-code search. Nếu tìm thấy code liên quan → AskUserQuestion (VERIFY_ONLY / COMPLETE_EXISTING / IMPLEMENT_NEW). LEGACY_MODE thì route theo `implementation_strategy` từ task file (CORE-019).

2. **TDD-first, không exception** — Phase 3 viết test TRƯỚC source code. Test gate (Protocol 13 GATE-13) BẮT BUỘC pass trước khi advance. Profile=quick chỉ giảm coverage (smoke only), KHÔNG bỏ TDD order.

3. **Parallel review, sequential fix** — Phase 4-5 spawn parallel review agents (code-reviewer + qa-lead + security tùy profile). Phase 5 fix iterations chạy sequential — tránh 2 agent ghi đè cùng file. Max 3 fix attempts → escalate.

4. **Lazy-load procedures (CORE-032)** — SKILL.md là routing hub ~600 dòng. 14 procedure files chỉ load khi tới phase tương ứng. Giảm 70% context so với monolithic.

5. **Cross-skill artifact contract (CORE-036)** — `--from-fix-bugs` opt-in consume `fix-impact.json` để prioritize features có code_files trùng. Producer-consumer schema versioned (`fix-impact-v1`). Không pass flag → behavior cũ (zero regression).

6. **Registry Safe-Write (CORE-006) — narrow per-field jq update** — Skill là PRIMARY owner của `impl_status` per REQ-ID. CHỈ update field này, KHÔNG ghi đè `.requirements[]` array. Không downgrade từ `done`.

7. **Multi-session isolation v5.0 — system-grouped layout** — Mỗi session lưu trong `$SYSTEM_SLUG/$FEATURE_SLUG/sessions/{id}/`. 2 dev cùng implement 2 feature khác nhau ở 2 machine → 0 conflict (per-feature lock + per-system cache).

8. **Vietnamese phase summary (CORE-028)** — Phase 6 luôn tạo `phase-summary.md` bằng tiếng Việt cho non-specialist. Có "Cho skill kế tiếp" section reference consumer_hints schema v2.0.

---

## 5. Non-goals (KHÔNG làm)

Để tránh scope creep, skill này **KHÔNG** xử lý:

- **Generate feature spec** từ idea — `/wf-define-features` làm
- **Architectural design** (system layout, tech stack choice) — `/wf-design` làm
- **Module planning + dependency graph** — `/wf-plan-modules` làm
- **Find & fix bugs trên code đã ship** — `/wf-fix-bugs` làm (skill này CHỈ implement feature, không debug)
- **Verify traceability cross-skill (REQ-ID ↔ code)** — `/wf-verify-sync` làm (skill này chỉ update `impl_status`, không cross-check)
- **Deploy / build artifacts / generate release notes** — `/wf-prepare-deployment` làm
- **E2E test với real browser** — `/wf-e2e-verify` làm (skill này chỉ unit + integration tests)
- **Scan codebase legacy** — `/wf-legacy-scan` làm

---

## 6. Tham chiếu

- Patterns áp dụng:
  - [`../../03-design-patterns/01-lazy-load-procedures.md`](../../03-design-patterns/01-lazy-load-procedures.md) — 14 procedure files lazy-load
  - [`../../03-design-patterns/02-ci-first-integration.md`](../../03-design-patterns/02-ci-first-integration.md) — CI PRE-GATE 3-step (Na/Nb/Nc) auto-detect GitNexus/Serena
  - [`../../03-design-patterns/04-parallel-lane-dispatch.md`](../../03-design-patterns/04-parallel-lane-dispatch.md) — Phase 4 parallel review agents
  - [`../../03-design-patterns/05-agent-prompt-template.md`](../../03-design-patterns/05-agent-prompt-template.md) — 8-section prompt cho developer/reviewer agents
  - [`../../03-design-patterns/06-checkpoint-resume.md`](../../03-design-patterns/06-checkpoint-resume.md) — checkpoint.json + context_digest
  - [`../../03-design-patterns/08-auto-detect-fallback.md`](../../03-design-patterns/08-auto-detect-fallback.md) — CI tools auto-detect + fallback Grep

- Standards áp dụng:
  - [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md) — Skill anatomy chuẩn
  - [`../../02-standards/06-safe-write-protocol.md`](../../02-standards/06-safe-write-protocol.md) — PRIMARY owner của `impl_status`
  - [`../../02-standards/11-output-path-contract.md`](../../02-standards/11-output-path-contract.md) — System-grouped paths

- Rules liên quan: CORE-019 (Feature-Level Code Verification), CORE-020 (Pre-Implementation Safety Gate), CORE-006 (Registry Safe-Write), CORE-008 (No impl_status downgrade), CORE-028 (Phase Summary tiếng Việt), CORE-032 (Lazy-Load Procedures), CORE-036 (Cross-Skill Artifact Contract), CORE-038 (Context Budget); BHV-001..004
