# Skill Review Standards — MCV3

Thư mục lưu **bộ tiêu chuẩn rà soát** cho từng skill trong DEVKIT/MCV3.

## Mục đích

Định nghĩa **tiêu chí kiểm tra thiết kế** cho skills, dùng để:

- Rà soát định kỳ chất lượng skill
- Gate check trước khi merge thay đổi skill
- Onboarding review cho skill mới
- Audit pipeline tham chiếu

## Cấu trúc (v2.0 — từ 2026-04-19)

```
docs/skill-review-standards/
├── README.md                  # File này — index + quy tắc
├── _template-common.md        # ★ Bộ tiêu chuẩn CHUNG (A/B/C/D/E/F/H/I/J)
├── <skill-name>.md            # Per-skill: chỉ Profile + Extension (NHÓM G)
└── reports/                   # Review findings per lần rà soát (không check vào git)
```

**Ý tưởng:** Tách tiêu chuẩn thành 3 tầng:

1. **Core** (áp dụng 100% mọi skill) — nằm trong `_template-common.md`
2. **Conditional** (áp dụng theo profile flag) — cũng nằm trong `_template-common.md`, được kích hoạt bởi `profile:` block trong file per-skill
3. **Extension** (skill-specific) — NHÓM G + constraint đặc thù, nằm trong file per-skill

## Quy trình viết file per-skill

Mỗi file `<skill-name>.md` chỉ cần:

1. Khai báo **Skill Profile** (YAML block — xem §1 của `_template-common.md`)
2. Liệt kê **nhóm tiêu chuẩn áp dụng** (bảng Nhóm × Áp dụng/Skip)
3. Viết **Extension section** (nếu có):
   - NHÓM G: Tiêu chuẩn không tổng quát hóa được (ví dụ: Strategy S1-S7)
   - Cross-skill contract đặc thù (paths ownership riêng)
   - Constraint đặc biệt (READ-ONLY output, exclusive ownership…)
4. Quick-check đặc thù (bổ sung ngoài common §6)
5. Reference tới SKILL.md, `_contract.json`, procedures, templates, evals

## Quy ước đặt tên

| Loại skill | Path skill | File review |
|------------|-----------|-------------|
| Workflow skill | `.claude/skills/workflow/<name>/` | `<name>.md` |
| Workflow orchestrator | `.claude/skills/workflows/<name>/` | `workflows-<name>.md` |
| Standalone skill | `.claude/skills/<name>/` | `<name>.md` |
| Audit skill | `.claude/skills/audit-*/` | `audit-<name>.md` |

## Index các skill đã có tiêu chuẩn

### Workflow chính (Phase 0-6)

| Skill | File | Version | Registry role | Phases | Đặc trưng |
|-------|------|---------|---------------|--------|-----------|
| `wf-brainstorm` | [wf-brainstorm.md](./wf-brainstorm.md) | 8.1.0 | SEED (3 fields) | 9 | Branching NEW/LEGACY, BA + experts parallel |
| `wf-analyze-requirements` | [wf-analyze-requirements.md](./wf-analyze-requirements.md) | 2.1.0 | PRIMARY (5 fields) | 14 | Multi-agent per dept, Phase 8c Handoff sau Phase 8 Registry |
| `wf-define-features` | [wf-define-features.md](./wf-define-features.md) | 2.1.0 | PRIMARY + SAFE-UPDATE | 10 | 4 producers cao bất thường, dual-schema digest |
| `wf-design` | [wf-design.md](./wf-design.md) | 3.0.0 | PRIMARY + FIX-INVALID | 9 | 7 agent types, Phase 7 LEGACY-only |
| `wf-design-ux` | [wf-design-ux.md](./wf-design-ux.md) | 3.0.0 | PRIMARY | — | Conditional skip khi `api-only`, LPM auto-detect |
| `wf-plan-modules` | [wf-plan-modules.md](./wf-plan-modules.md) | 1.7.0 | PRIMARY + SAFE-UPDATE | 14 | CORE-019 Feature-Level Code Verification |
| `wf-implement-feature` | [wf-implement-feature.md](./wf-implement-feature.md) | 3.0.0 | PRIMARY (impl_status) | — | `is_multi_run`, CORE-020 Safety Gate |
| `wf-prepare-deployment` | [wf-prepare-deployment.md](./wf-prepare-deployment.md) | 2.0.0 | NONE | — | Terminal skill (0 consumers) |

### Quality & Verify

| Skill | File | Version | Registry role | Đặc trưng |
|-------|------|---------|---------------|-----------|
| `wf-preflight` | [wf-preflight.md](./wf-preflight.md) | — | NONE | `--fix` scope hạn chế, re-score sau fix |
| `wf-verify-sync` | [wf-verify-sync.md](./wf-verify-sync.md) | — | SAFE-UPDATE | CORE-008 non-downgrade rule |

### Fix Bug pipeline

| Skill | File | Version | Role | Đặc trưng |
|-------|------|---------|------|-----------|
| `wf-fix-bugs` | [wf-fix-bugs.md](./wf-fix-bugs.md) | 5.1.0 | **Orchestrator thuần** | Không `procedures/` / `templates/`, delegate 100% |
| `wf-fix-discover` | [wf-fix-discover.md](./wf-fix-discover.md) | 2.5.1 | Discovery | 5-Layer + 4 PASS, runtime Playwright |
| `wf-fix-triage` | [wf-fix-triage.md](./wf-fix-triage.md) | 1.1.0 | Classify | Single-phase, không spawn agents |
| `wf-fix-execute` | [wf-fix-execute.md](./wf-fix-execute.md) | 3.1.0 | Execute + Verify | SAFE-UPDATE Phase 4a, Batch parallel, verify loop |

### Legacy pipeline

| Skill | File | Version | Đặc trưng |
|-------|------|---------|-----------|
| `wf-legacy-scan` | [wf-legacy-scan.md](./wf-legacy-scan.md) | 4.0.0 | Strategy S1-S7, 11 consumers |
| `wf-legacy-classify` | [wf-legacy-classify.md](./wf-legacy-classify.md) | — | Classify modules, delegate từ scan |
| `wf-legacy-extract` | [wf-legacy-extract.md](./wf-legacy-extract.md) | — | 5 consumers, share `legacy-scan/` |

### Utilities

| Skill | File | Version | Registry role | Đặc trưng |
|-------|------|---------|---------------|-----------|
| `wf-add-scope` | [wf-add-scope.md](./wf-add-scope.md) | 1.0.0 | APPEND | Idempotent, dedup theo ID |
| `wf-manage-change` | [wf-manage-change.md](./wf-manage-change.md) | 2.0.0 | UPDATE-MODE | 4 change types matrix, `$CHANGE_ID` session |
| `wf-annotate-code` | [wf-annotate-code.md](./wf-annotate-code.md) | 2.0.0 | NONE | Ghi trực tiếp vào source code (duy nhất) |

### Lane skills `wf-fix-*` — QD1-QD11 (SCAFFOLD)

> ⚠️ SCAFFOLD — cần review chi tiết từng lane skill để populate.

| Skill | File | Status |
|-------|------|--------|
| `wf-fix-functional` (QD1) | [wf-fix-functional.md](./wf-fix-functional.md) | 🔶 Scaffold |
| `wf-fix-business` (QD2) | [wf-fix-business.md](./wf-fix-business.md) | 🔶 Scaffold |
| `wf-fix-security` (QD3) | [wf-fix-security.md](./wf-fix-security.md) | 🔶 Scaffold |
| `wf-fix-performance` (QD4) | [wf-fix-performance.md](./wf-fix-performance.md) | 🔶 Scaffold |
| `wf-fix-ux-a11y` (QD5) | [wf-fix-ux-a11y.md](./wf-fix-ux-a11y.md) | 🔶 Scaffold |
| `wf-fix-data` (QD6) | [wf-fix-data.md](./wf-fix-data.md) | 🔶 Scaffold |
| `wf-fix-compat` (QD7) | [wf-fix-compat.md](./wf-fix-compat.md) | 🔶 Scaffold |
| `wf-fix-observability` (QD8) | [wf-fix-observability.md](./wf-fix-observability.md) | 🔶 Scaffold |
| `wf-fix-runtime-health` (QD9) | [wf-fix-runtime-health.md](./wf-fix-runtime-health.md) | 🔶 Scaffold |
| `wf-fix-integration` (QD10) | [wf-fix-integration.md](./wf-fix-integration.md) | 🔶 Scaffold |
| `wf-fix-business-completeness` (QD11) | [wf-fix-business-completeness.md](./wf-fix-business-completeness.md) | 🔶 Scaffold |

### E2E Testing pipeline (SCAFFOLD)

> ⚠️ SCAFFOLD — pipeline 9 skills (+ 3 hỗ trợ) phục vụ end-to-end testing.

| Skill | File | Status |
|-------|------|--------|
| `wf-e2e-verify` | [wf-e2e-verify.md](./wf-e2e-verify.md) | 🔶 Scaffold |
| `wf-e2e-finding` | [wf-e2e-finding.md](./wf-e2e-finding.md) | 🔶 Scaffold |
| `wf-e2e-batch` | [wf-e2e-batch.md](./wf-e2e-batch.md) | 🔶 Scaffold |
| `wf-e2e-credentials` | [wf-e2e-credentials.md](./wf-e2e-credentials.md) | 🔶 Scaffold |
| `wf-e2e-browser` | [wf-e2e-browser.md](./wf-e2e-browser.md) | 🔶 Scaffold |
| `wf-e2e-demo` | [wf-e2e-demo.md](./wf-e2e-demo.md) | 🔶 Scaffold |
| `wf-e2e-fix` | [wf-e2e-fix.md](./wf-e2e-fix.md) | 🔶 Scaffold |
| `wf-e2e-implement` | [wf-e2e-implement.md](./wf-e2e-implement.md) | 🔶 Scaffold |
| `wf-e2e-retest` | [wf-e2e-retest.md](./wf-e2e-retest.md) | 🔶 Scaffold |
| `wf-e2e-scenario` | [wf-e2e-scenario.md](./wf-e2e-scenario.md) | 🔶 Scaffold |
| `wf-e2e-test` | [wf-e2e-test.md](./wf-e2e-test.md) | 🔶 Scaffold |
| `wf-e2e-unblock` | [wf-e2e-unblock.md](./wf-e2e-unblock.md) | 🔶 Scaffold |

### Standalone & Tracking (SCAFFOLD)

| Skill | File | Status |
|-------|------|--------|
| `status` | [status.md](./status.md) | 🔶 Scaffold |
| `wf-diagram` | [wf-diagram.md](./wf-diagram.md) | 🔶 Scaffold |
| `wf-scan-target` | [wf-scan-target.md](./wf-scan-target.md) | 🔶 Scaffold |
| `wf-migrate-module` | [wf-migrate-module.md](./wf-migrate-module.md) | 🔶 Scaffold |
| `wf-test-business-workflow` | [wf-test-business-workflow.md](./wf-test-business-workflow.md) | 🔶 Scaffold |

> Thêm skill mới → thêm dòng vào bảng phù hợp.
>
> **Trạng thái coverage:** 48/48 skills có file review (20 full + 28 scaffold). Sau Wave 3, tỉ lệ scaffold cần được hoàn thiện theo nhu cầu review per skill.

## Nguyên tắc khi viết/rà soát tiêu chuẩn

1. **KHÔNG copy-paste** tiêu chuẩn chung vào file per-skill — luôn reference `_template-common.md`.
2. **Profile là ground truth** — nếu flag khai `false` mà skill thực tế có, tạo finding ngay.
3. **Bám `workflow-skill.md`** (v3.0) làm baseline — mọi skill phải tuân thủ.
4. **Reference chính xác CORE/Protocol** — dùng CORE-XXX và Protocol-NN để tránh drift.
5. **Mỗi tiêu chuẩn phải có phương pháp kiểm tra objective** (bash/jq/grep) — tránh subjective.
6. **Mỗi tiêu chuẩn có PASS criteria đo đếm được** — tránh "reasonable", "adequate".

## Quy trình rà soát (5 pass)

| Pass | Mục tiêu | Nhóm |
|------|----------|------|
| **Pass 1** | Static Compliance | A, C (trong `_template-common.md`) |
| **Pass 2** | Logic & Flow | B, F (conditional theo profile) |
| **Pass 3** | Contract & Protocol | D, E |
| **Pass 4** | Runtime & Error | H, I, J |
| **Pass 5** | Extension per-skill | NHÓM G + CS của file per-skill |

Output: `reports/YYYY-MM-DD-<skill>.md` với findings + severity (BLOCKER/HIGH/MEDIUM/LOW).

## Tài liệu tham chiếu chung

- [`_template-common.md`](./_template-common.md) — Bộ tiêu chuẩn chung v1.0
- [`.claude/skills/workflow-skill.md`](../../.claude/skills/workflow-skill.md) — Template skill v3.0
- [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) — CORE rules
- [`.claude/skills/protocols/README.md`](../../.claude/skills/protocols/README.md) — Protocol index
- [`../08-reference/skill-anatomy-quick.md`](../08-reference/skill-anatomy-quick.md) — Giải phẫu skill (cheatsheet)
- [`../02-standards/02-skill-standard.md`](../02-standards/02-skill-standard.md) — Skill standard (BẮT BUỘC)
- [`../01-architecture/07-skills-catalog.md`](../01-architecture/07-skills-catalog.md) — Catalog 43 skills

## Findings tổng hợp từ lần phủ đầu tiên (2026-04-19)

Các phát hiện đáng chú ý khi tạo 20 files review (tham khảo trước khi audit chính thức):

1. **`wf-brainstorm` và `wf-legacy-extract` thiếu `disable-model-invocation: true`** trong frontmatter SKILL.md → A4 finding tiềm năng.
2. **`wf-add-scope` chưa refactor lazy-load v3.0** — SKILL.md còn 8 phases inline, `procedures/` chỉ có `flow-new.md` monolithic → A7 finding.
3. **`wf-implement-feature` có `outputs.docs=[]`** — output chính là source code, khác pattern các wf-* skill khác.
4. **`wf-annotate-code` phá pattern chung**: ghi trực tiếp vào source code thay vì `.mc-data/`, phase identifier non-standard `"post-phase3"`.
5. **`wf-define-features` có 4 producers** (analyze-req, legacy-extract, add-scope, fix-bugs --deep) → cao nhất trong workflow skills.
6. **`module-code-mapping.json` ownership overlap** giữa `wf-legacy-scan` (forward) và `wf-legacy-extract` (produce thực tế) — xử lý bằng CS trong cả 2 file review để tránh drift.
7. **`wf-fix-bugs` là orchestrator thuần duy nhất** — không có `procedures/`/`templates/`, Profile flags khác hoàn toàn các skill còn lại.
8. **Một số skill evals tối thiểu**: `wf-define-features` (3), `wf-fix-execute` (4) — nên bổ sung coverage.

## Changelog

| Ngày | Thay đổi |
|------|----------|
| 2026-04-19 | v2.1: Phủ thêm 19 skill review (brainstorm, analyze-req, define-features, design, design-ux, plan-modules, implement-feature, annotate-code, fix-bugs/discover/triage/execute, preflight, verify-sync, legacy-classify, legacy-extract, add-scope, manage-change, prepare-deployment). Tổng 20 workflow skill đã có tiêu chuẩn. |
| 2026-04-19 | v2.0: Tách `_template-common.md` khỏi per-skill file; thêm Skill Profile YAML block; refactor `wf-legacy-scan.md` thành inherit + extension |
| 2026-04-19 | v1.0: Tạo khung ban đầu với `wf-legacy-scan.md` làm mẫu đầu tiên |
