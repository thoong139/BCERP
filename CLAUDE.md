# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> Xem cũng **`AGENTS.md`** (root) — file cấu hình chung theo quy ước [agents.md](https://agents.md/) mà Codex, zCode, Google Antigravity và các AI coding agent khác đọc. Bối cảnh khách hàng ở §0 dưới đây khớp với §0 của `AGENTS.md`.

---

## 0. Khách Hàng Dự Án: BC Agency (BẮT BUỘC đọc trước)

Repo này dùng DEVKIT (MCV3) để xây **BCERP** — ERP nội bộ cho **BC Agency** (Công ty TNHH Truyền thông & Dịch vụ BC Việt Nam, MST 0109354342, trụ sở Hà Nội), một **digital marketing agency** 8+ năm kinh nghiệm — KHÔNG phải doanh nghiệp sản xuất/bán lẻ thông thường.

- **Mô hình kinh doanh:** trung gian (agency) quản lý tài khoản quảng cáo đa nền tảng — Meta, Google, TikTok, Bing, X, Pinterest, Yandex — cho 1.000+ khách hàng toàn cầu, 2.600+ tài khoản active; kèm Facebook/TikTok marketing, TikTok Shop, Google Ads, SEO, thiết kế web/đồ họa.
- **Khách hàng mục tiêu của BC Agency:** FMCG, F&B, Retail, Beauty, B2B. **Đối tác chính thức:** Google, TikTok, Yandex.
- **Khi chạy `/wf-brainstorm`, `/wf-analyze-requirements`, `/wf-define-features`:** ưu tiên huy động `paid-media-expert` (trung tâm), `marketing-expert`, `sales-expert`, `finance-expert`, `customer-expert`, `compliance-expert` bên cạnh `business-analyst` mặc định. Domain knowledge sẵn có tại `.claude/references/team-expert/paid-media/` và `.claude/references/team-expert/marketing/`.
- **KHÔNG tự suy diễn** ngành nghề, phạm vi module, hay mô hình thu phí — những điểm chưa xác nhận PHẢI hỏi qua `/wf-brainstorm` (xem danh sách ở §6 của file dưới đây) và chốt vào `req-registry.json` (CORE-004).

**Đọc đầy đủ trước khi phân tích nghiệp vụ:** [docs/00-overview/00-company-context.md](docs/00-overview/00-company-context.md) — hồ sơ công ty, dịch vụ, hàm ý thiết kế module ERP theo đúng nghiệp vụ agency quảng cáo.

---

## DEVKIT là gì

DEVKIT (MCV3) là **bộ công cụ hỗ trợ người không chuyên phát triển phần mềm** trên nền tảng Claude Code. Nó biến ý tưởng mơ hồ thành sản phẩm phần mềm hoàn chỉnh thông qua **đội ngũ 62 AI chuyên gia ảo** — phân tích nghiệp vụ, xây dựng tài liệu, thiết kế kiến trúc, và triển khai code.

**Định vị cốt lõi:** Output của repo này là **tài sản vận hành thật**, không phải bản nháp tạm thời. Phải đủ tốt cho doanh nghiệp dùng vận hành VÀ đủ chuẩn cho AI dùng làm context phát triển tiếp.

**Tài liệu đọc trước khi bắt đầu task** (theo thứ tự ưu tiên):

0. **[docs/00-overview/00-company-context.md](docs/00-overview/00-company-context.md)** — ★★ Bối cảnh khách hàng BC Agency — BẮT BUỘC đọc trước phân tích nghiệp vụ (xem §0 ở trên)
1. **[docs/README.md](docs/README.md)** — ★ ENTRY POINT mới (persona-driven navigation, sitemap, index 8 sections)
2. [docs/00-overview/01-project-description.md](docs/00-overview/01-project-description.md) — Mục tiêu sản phẩm + mô hình 7 phases
3. [docs/00-overview/02-positioning-priorities.md](docs/00-overview/02-positioning-priorities.md) — Khung ưu tiên vận hành
4. [docs/01-architecture/07-skills-catalog.md](docs/01-architecture/07-skills-catalog.md) — Catalog 43 skills + output paths + contracts
5. [docs/01-architecture/10-mcv3-engines-overview.md](docs/01-architecture/10-mcv3-engines-overview.md) — ★ Bản đồ 15 engines cross-cutting (skill arch, dependency, knowledge graph, governance, ...) ánh xạ vào skill/rule hiện có
6. [docs/06-user-guides/huong-dan-su-dung.md](docs/06-user-guides/huong-dan-su-dung.md) — Luồng end-to-end cho người dùng cuối
7. [docs/02-standards/](docs/02-standards/) — ★ Chuẩn ràng buộc khi mở rộng MCV3 (BẮT BUỘC đọc khi tạo skill/agent mới)
8. [AGENTS.md](AGENTS.md) — Quick reference dành cho contributors (bổ sung CLAUDE.md)
9. [CHANGELOG.md](CHANGELOG.md) — Lịch sử phát hành các skill

> **Cấu trúc `docs/` mới (sau tái cấu trúc v1 — 2026-05-15):** 8 sections (`00-overview` → `08-reference`) + `99-archive`. Xem [docs/README.md](docs/README.md) §sitemap.

---

## Thứ Tự Ưu Tiên (BẮT BUỘC)

```
1. Độ chính xác, tính nhất quán, tính đầy đủ, chất lượng kỹ thuật, bảo mật
2. Tốc độ xử lý và song song hóa — CHỈ SAU KHI mục 1 được bảo vệ
```

**Quy tắc chốt:** Nếu có xung đột giữa tốc độ và chất lượng → **Chất lượng thắng.**

- KHÔNG đánh đổi correctness, completeness, security để lấy tốc độ
- Mọi output downstream PHẢI bám upstream docs + `req-registry.json`
- Song song hóa CHỈ hợp lệ khi có owner rõ, write scope tách biệt, contract ổn định, và bước verify sau hợp nhất
- Tài liệu phải rõ để doanh nghiệp vận hành, gọn để AI không bị loãng context

Chi tiết: [docs/00-overview/02-positioning-priorities.md](docs/00-overview/02-positioning-priorities.md) (bản cũ tại [docs/99-archive/mcv3-development-priorities-LEGACY.md](docs/99-archive/mcv3-development-priorities-LEGACY.md))

---

## Lệnh Thường Dùng

```bash
# Audit skill compliance (yêu cầu jq)
./.claude/scripts/skill-compliance-audit.sh [skill-name]
./.claude/scripts/skill-compliance-audit.sh --all

# Validate _contract.json schema sync
./.claude/scripts/validate-schema-sync.sh [skill-name | --all]

# Pipeline naming validation
./.claude/scripts/validate-pipeline-naming.sh

# Python pytest cho _shared modules (wf-fix-bugs runtime + linear skills)
cd .claude/skills/workflow/_shared && ./run-tests.sh             # full + coverage gate ≥80%
cd .claude/skills/workflow/_shared && ./run-tests.sh --fast      # smoke only
cd .claude/skills/workflow/_shared && ./run-tests.sh --module=ripple  # 1 module

# Phase 5 integration test suite (8 scenarios A-H)
cd tools && python integration-test.py run --scenario A          # 1 scenario
cd tools && python integration-test.py run --scenario ALL        # full
cd tools && python integration-test.py validate --dir <path>     # validate .mc-data/ outputs
cd tools && python integration-test.py report --format md        # generate report
```

**Windows users**: Chạy bash scripts qua Git Bash, WSL, hoặc PowerShell wrapper:
```powershell
powershell -ExecutionPolicy Bypass -File .claude/scripts/run-devkit-bash.ps1 .claude/scripts/skill-compliance-audit.sh --all
```

**Lưu ý chính**: DEVKIT framework KHÔNG có build truyền thống. Validation 3-tier:
1. **Structural**: skill-compliance-audit + validate-schema-sync
2. **Unit/integration**: pytest cho `_shared/` (Python utilities)
3. **End-to-end**: 8 integration scenarios trong `tools/scenarios/`

---

## Kiến Trúc: Hai Lớp Chính

### Lớp 1: Skills (`.claude/skills/`) — Người dùng gọi qua `/command`

Mỗi skill orchestrate một phase của development workflow. Khi user chạy `/wf-analyze-requirements`:
```
User → SKILL.md loads → spawn agents (subagent_type="business-analyst", ...) → Agents tạo docs vào .mc-data/docs/
```

- Workflow skills: `.claude/skills/workflow/` — 47 skills `wf-*` (gồm 12 `wf-e2e-*` skills cho end-to-end testing pipeline; `wf-scan-target`, `wf-diagram`, `wf-cmi` standalone — không thuộc main pipeline; `wf-migrate-module` và `wf-test-business-workflow` cho migration và business testing; v8.2.0 thêm lane `wf-fix-observability` (QD8); v9.0.2 thêm lanes `wf-fix-runtime-health` (QD9) + `wf-fix-integration` (QD10); v9.1.0 thêm lane `wf-fix-business-completeness` (QD11); v10.0: wf-fix-bugs kiến trúc lại toàn bộ với lazy-load procedures, CI PRE-GATE, 32 templates, Playwright 3 modes; v1.0.0 (2026-05-16): `wf-cmi` Cross-Module Integrity Orchestrator standalone — 8 phases, 10 lanes CD1-CD10 song song, sidecar `business-invariants.json` Engine #4 không bump registry; v2.0.0 (2026-05-16): `wf-cmi` mở rộng Gói C++ Logistics → 26 lanes (CD1-7, CD9, CD11, CD13, CD15-18, CD23-26, CD28-31, CD37-40), 3-wave dispatch via wave-coordinator.sh, 7 graph builders mới (4 FE + 3 BE plugins), 9 SSOT templates, integrity-impact.json schema v1→v2 backward-compat; **v3.0.0 (2026-05-17): `wf-cmi` E2E Scenario Engine — ADD-ONLY thêm lane CD41 "E2E Scenario Synthesizer" (Wave 3, profile=deep\|exhaustive) + Phase 9 "E2E Execute & Verify" (opt-in `--exec-scenarios`) + Phase 10 "E2E Resolution" (auto-run nếu FAIL) + 7 cờ mới (`--exec-scenarios`, `--scenarios-only`, `--show-browser`, `--mobile`, `--strict-evidence`, `--no-prompt`, `--auto-fix-source`) + integrity-impact.json schema v2→v3 (readable_by=[v1,v2,v3]) — backward-compat 100% Phase 1-8 routing identical, consumer skills không cần update**) + `status` + thư mục `_shared/` (Python utilities, KHÔNG phải skill)
- Orchestrator skills: `.claude/skills/workflows/` — `new-project`, `existing-project`, `feature-addition`
- Template cho skill mới: `.claude/skills/workflow-skill.md` (v3.0)
- Shared protocols: `.claude/skills/protocols/` (22 protocol files 01-22 + README, lazy-loaded). Index: [protocols/README.md](.claude/skills/protocols/README.md) — `shared-protocols.md` còn lại làm redirect backward-compat. Protocol 22 (R/W lock cross-session cho BE/FE/DB/Playwright) áp dụng cho wf-e2e-* parallel-safe.
- Runtime utilities: `.claude/skills/workflow/_shared/` — Python package (`isg/`, `signal_bus/`, `concurrency/`, `scan_cache/`, `workload_estimator/`, `cdg/`, `cache/`, `lane/`, `partition/`, `aggregate/`, `profiles/`) cho `wf-fix-bugs` v7.x + linear skills. Coverage gate ≥80%.

### Lớp 2: Agents (`.claude/agents/`) — Thực thi analysis, design, implementation

Skills gọi agents qua `Agent` tool với `subagent_type` = tên file agent (không `.md`).

| Đội | Vị trí | Vai trò |
|-----|--------|---------|
| **Business** | `agents/business/` | 25 agents — BA + 24 domain experts |
| **Engineering** | `agents/engineering/` | 14 agents — architect, developer, devops, security, embedded-engineer, ... |
| **Design** | `agents/design/` | 7 agents — UX/UI design |
| **Testing** | `agents/testing/` | 9 agents — QA, code review, performance, ... |
| **Review** | `agents/review/` | 6 agents — DEVKIT self-quality |
| **Orchestrator** | `agents/orchestrator.md` | Điều phối giữa các đội |

Domain knowledge: `.claude/references/team-expert/[domain]/` (162 files, 29 domains)
Agent procedures: `.claude/agents/procedures/[agent-name]/` (61 procedure directories — HOW chi tiết per task)

---

## Workflow & Skills

### Ba Path chính

```
STANDARD PATH (dự án mới):
  Idea → /wf-brainstorm → /wf-analyze-requirements → /wf-define-features →
  /wf-design → /wf-design-ux (nếu có UI) → /wf-plan-modules → /wf-implement-feature →
  /wf-preflight → /wf-verify-sync → /wf-prepare-deployment
                                                                      ↑
                                          /wf-fix-bugs (bất kỳ lúc nào sau khi có code)

EXISTING PATH (dự án có sẵn):
  /wf-legacy-scan → /wf-legacy-classify → /wf-legacy-extract → /wf-brainstorm* →
  /wf-analyze-requirements* → /wf-define-features* → /wf-design* →
  /wf-annotate-code (nếu có gaps) → /wf-design-ux* (nếu có UI) →
  /wf-plan-modules → /wf-implement-feature → ...

  * = shared skills tự detect LEGACY_MODE (CORE-021: check project-context.md > 500 bytes)

HYBRID PATH (dự án có code + idea mới, kết hợp cả 2 path trên):
  /wf-legacy-scan → /wf-brainstorm* → /wf-analyze-requirements* → /wf-define-features* →
  /wf-design* → /wf-annotate-code → /wf-design-ux* → /wf-plan-modules →
  /wf-implement-feature → ...

  * = shared skills tự detect HYBRID_MODE từ context
```

**KHÔNG skip phases.** Chưa có output phase trước → KHÔNG chạy phase sau.

### Danh sách Skills

**Workflow chính (Phase 0-6):**

| Skill | Lệnh | Mục đích | Ước lượng |
|-------|------|----------|-----------|
| wf-brainstorm | `/wf-brainstorm` | Chốt khung dự án + init `.mc-data/` | 15-30 min |
| wf-analyze-requirements | `/wf-analyze-requirements` | Multi-agent phân tích nghiệp vụ → Phase 1 docs | 30-90 min |
| wf-define-features | `/wf-define-features` | Requirements → Feature specs → Phase 2 | 30-60 min |
| wf-design | `/wf-design` | Architecture, API, DB design → Phase 3 | 20-45 min |
| wf-design-ux | `/wf-design-ux` | UX/UI design (skip nếu api-only) → Phase 4 | 30-90 min |
| wf-plan-modules | `/wf-plan-modules` | Dependency analysis + impl plans → Phase 5 | 15-30 min |
| wf-implement-feature | `/wf-implement-feature [name]` | TDD code implementation + review | 20-60 min/feat |
| wf-prepare-deployment | `/wf-prepare-deployment` | Deployment docs → Phase 6 | 20-45 min |

**Hỗ trợ & Quality:**

| Skill | Lệnh | Mục đích |
|-------|------|----------|
| wf-preflight | `/wf-preflight [--scope] [--fix] [--run-tests]` | Health check → PASS/WARN/FAIL |
| wf-fix-bugs | `/wf-fix-bugs [mô-tả] [--scope] [--dims=QD1,..] [--profile=quick\|standard\|deep\|exhaustive] [--dry-run] [--resume] [--migrate]` | **Pure orchestrator v10.9.1** (2026-05-16): lazy-load procedures (CORE-032), CI PRE-GATE (CORE-033 — v10.3 gộp Na/Nb/Nc thành 1 wrapper `ci-pregate.sh`), namespaced error codes E001-E109 (CORE-034), session subdirectories phase{N}-{name}/ (CORE-035), cross-skill artifact contract (CORE-036), 8-section agent prompt templates (CORE-037), context budget management (CORE-038). Session isolation `sessions/{YYYY-MM-DD-{scope}-{slug}-{NN}}/` + atomic mkdir SESSION_ID claim + lock canonical helper + heartbeat atomic + `_index/sessions.jsonl`. ISG → partition → 11 dimension lanes (QD1-QD11) → signal aggregation → workload gate → CDG → triage → execute. **36 templates**. Playwright 3 modes (headless/visible/mobile). Quality gates: Phase 5 Step 5.10 Safety Check, Phase 7 Step 7.2 CQG-1 Numeric, Phase 7 Step 7.3 CQG-2 Browser+Integration (v10.9.1 structured fix-log check thay grep keyword). POST-GATE → `fix-impact.json` (schema fix-impact-v1 — `$schema` + audit_chain.checksum sha256 pre-finalize). Cross-skill: `--from-fix-bugs` wired vào wf-verify-sync, wf-prepare-deployment, wf-implement-feature; `--from-cmi` (opt-in) consume integrity-impact.json. Migration v6.x→v7.0 qua `--migrate` hoặc `scripts/wf-fix-migrate-sessions.sh`. **Optimization waves: v10.3 (Phase 1 18 steps), v10.4 (Phase 2 5 steps), v10.5 (Phase 3 7 steps), v10.6 (Phase 4 9 steps), v10.7 (Phase 5 10 steps), v10.8 (Phase 6 7 steps), v10.9 (Phase 7 8 steps)** — Pipeline ~5-6K tokens/phase, không trigger /compact trên dự án lớn. **v10.9.1 fix wave** (2026-05-16): E010-E013 namespace conflict, E090b stale ref, lock TOCTOU race, session-log raw append, SESSION_ID atomic claim, CQG-2 keyword fragility, CDG aggregation cross-phase Phase 6 PRE-GATE, max-retry enforcement Step 6.5, fix-impact checksum pre-finalize, CRITICAL_COUNT structured. Deprecation BLOCK (v7.1): legacy `run-NNN-*` paths blocked với CDG override; escape hatch `MCV3_FIX_BUGS_LEGACY_DEPRECATED_OK=1`. |
| wf-fix-triage | (spawned bởi /wf-fix-bugs) | Phase 2 Triage — classify severity, fixability, generate fix-plan.md + bug-triage.md |
| wf-fix-execute | (spawned bởi /wf-fix-bugs) | Phase 3-5 Fix + Docs Sync + Verify loop + Phase 6 Report |
| wf-fix-functional | (lane QD1 — spawned bởi /wf-fix-bugs) | Functional Correctness — 7 probes kiểm tra feature đúng spec |
| wf-fix-business | (lane QD2 — spawned bởi /wf-fix-bugs) | Business Correctness — 5 probes kiểm tra nghiệp vụ + domain rules |
| wf-fix-security | (lane QD3 — spawned bởi /wf-fix-bugs) | Security & Privacy — 7 probes OWASP Top 10, không dùng scan cache |
| wf-fix-performance | (lane QD4 — spawned bởi /wf-fix-bugs) | Performance & Efficiency — 6 probes CWV, query, bundle, memory |
| wf-fix-ux-a11y | (lane QD5 — spawned bởi /wf-fix-bugs) | Accessibility & UX — 7 probes WCAG 2.2 AA + UX heuristics |
| wf-fix-data | (lane QD6 — spawned bởi /wf-fix-bugs) | Data Integrity & Resilience — 6 probes schema drift, migration, constraints |
| wf-fix-compat | (lane QD7 — spawned bởi /wf-fix-bugs) | Compatibility — 5 probes deprecated API, browser, responsive, i18n |
| wf-fix-observability | (lane QD8 — spawned bởi /wf-fix-bugs, v8.2.0) | Observability & Reliability — 7 probes retry/circuit-breaker, timeout, log coverage, metrics, health-check, trace propagation, alert rule (owner: sre + devops; CDG-RELIABILITY-RISK trên payment/auth) |
| wf-fix-runtime-health | (lane QD9 — spawned bởi /wf-fix-bugs, v9.0.2) | Runtime Health Verification — 7 probes (3 core Wave 1 + 4 deep Wave 1.5) phát hiện bugs chỉ thấy được qua browser runtime: console errors, network failures, uncaught exceptions, broken auth flows, SPA routes unreachable, CTAs không hoạt động, form validation thiếu (owner: qa-lead + frontend-developer; SKIP nếu `interface_type=api-only` hoặc `--no-browser`) |
| wf-fix-integration | (lane QD10 — spawned bởi /wf-fix-bugs, v9.0.2) | Cross-Module Integration — phát hiện cross-module reference drift, API contract violations, event handler coverage gaps, orphan FK references, multi-platform entity sync, cache staleness, state machine errors, business flow violations, auth matrix violations (owner: architect + data-engineer + domain experts; SKIP nếu không có `cross_module_dependencies[]` hoặc profile=quick) |
| wf-fix-business-completeness | (lane QD11 — spawned bởi /wf-fix-bugs, v9.1.0) | Business Completeness & Enhancement — 3-pass LLM analysis phát hiện missing business logic: cross-module pattern comparison (Pass 1), domain heuristic analysis (Pass 2, deep+), registry gap detection (Pass 3). Signal types: MISSING_FIELD, MISSING_FEATURE, TYPE_MISMATCH, VALIDATION_GAP, MISSING_DOMAIN_FIELD, MISSING_COMPLIANCE_CHECK, MISSING_AUDIT_TRAIL, MISSING_BUSINESS_RULE, UNIMPLEMENTED_REQ, ORPHAN_REQ_ID, GAP_REQ_TO_FEAT. Enhancement suggestions qua CDG gate (user ACCEPT/REJECT). (owner: business-analyst + domain experts + architect; SKIP nếu single module, api-only, hoặc profile=quick) |
| wf-e2e-verify | `/wf-e2e-verify <FEAT-ID> [--no-playwright] [--auto] [--resume] [--legacy]` | **v8.0.0** Pipeline F0→F0a→F0b→F1-F8 (11 steps): F0 infra health check → F0a business/DB/API/UI finding (spawns wf-e2e-finding) → F0b seed manifest → F1-F8 live test cycle. Features: B1 Cross-Module Gap Detection, B2 DECISION-REQUIRED Queue, B3 Credential Vault, --auto expert dispatch, per-severity anti-loop (CRITICAL=5/HIGH=4/MEDIUM=3/LOW=2), G1 flakiness elimination, G2 --no-playwright degrade mode (status="degraded", không skip). |
| wf-e2e-finding | `/wf-e2e-finding <FEAT-ID>` | F0a — Phân tích business + mapping (KHÔNG live test). Spawned tự động bởi wf-e2e-verify. Output: 8 finding files (business-rules, db-schema, api-contracts, ui-flows, cross-module-gaps, seed-requirements, test-scenarios, edge-cases). |
| wf-e2e-batch | `/wf-e2e-batch [--scope=<module>] [--feats=IDs]` | Batch orchestrator N FEATs với dependency graph. Topo-sort → parallel dispatch per level → gate check sau mỗi level. |
| wf-e2e-credentials | (spawned bởi wf-e2e-verify F0) | Credential Vault — OS keychain integration, secure credential storage cho test environments. |
| wf-verify-sync | `/wf-verify-sync` | Verify requirement-to-code traceability |
| wf-legacy-scan | `/wf-legacy-scan [path] [--profile=surface\|standard\|deep\|exhaustive] [--layers=L1,...] [--depth=surface\|standard\|deep] [--session=ID] [--status] [--resume] [--re-vision] [--batch-size=N] [--incremental] [--since=<git-ref>] [--no-cache] [--cache-publish]` | Scan toàn diện dự án hiện có (v5.0: 4 profiles + IPS 2-phase + session isolation + 4-level checkpoint + incremental + cache). Xem: [User Guide](docs/06-user-guides/per-skill/wf-legacy-scan-v5-guide.md) |
| wf-legacy-classify | `/wf-legacy-classify` | Phân loại modules theo business value vs technical health |
| wf-legacy-extract | `/wf-legacy-extract` | Trích xuất knowledge từ legacy codebase |
| wf-annotate-code | `/wf-annotate-code [--module] [--dry-run]` | Inject REQ-ID vào existing code |
| wf-add-scope | `/wf-add-scope --system=<id> [...]` | Thêm modules/features (append-only) |
| wf-manage-change | `/wf-manage-change [mô-tả] [--scope=all\|system\|module] [--name=<id>] [--mode=quick\|deep] [--dry-run] [--run-tests] [--resume] [--status]` | Xử lý thay đổi/bổ sung/sửa đổi tính năng — analyze → impact → plan → execute → verify. **v3.0.0**: 11 bash scripts, session+registry lock/heartbeat, sessions.jsonl concurrent-safe, change-impact.json cross-skill artifact (wf-verify-sync/wf-preflight/wf-implement-feature). |
| wf-migrate-module | `/wf-migrate-module [--source=<path>] [--target=<name>] [--dry-run]` | Di chuyển module giữa các system, cập nhật registry, docs, và code references |
| wf-test-business-workflow | `/wf-test-business-workflow [--scenario=<name>] [--all]` | Kiểm thử business workflow end-to-end, validate logic nghiệp vụ qua multi-step scenarios |
| status | `/status` | Xem tiến độ dự án |

**E2E Testing Pipeline (9 skills):**

| Skill | Lệnh | Mục đích |
|-------|------|----------|
| wf-e2e-scenario | `/wf-e2e-scenario [--name=<id>] [--all]` | Định nghĩa và quản lý E2E test scenarios |
| wf-e2e-browser | `/wf-e2e-browser [--scenario=<id>] [--headless]` | Browser-based E2E testing qua Playwright |
| wf-e2e-test | `/wf-e2e-test [--scenario=<id>] [--all] [--parallel]` | Thực thi E2E tests, thu thập kết quả |
| wf-e2e-demo | `/wf-e2e-demo [--scenario=<id>]` | Demo scenario với dữ liệu mẫu |
| wf-e2e-verify | `/wf-e2e-verify [--scenario=<id>] [--all]` | Verify E2E test results against expectations |
| wf-e2e-fix | `/wf-e2e-fix [--scenario=<id>] [--auto]` | Auto-fix E2E test failures |
| wf-e2e-implement | `/wf-e2e-implement [--scenario=<id>]` | Implement code changes dựa trên E2E results |
| wf-e2e-unblock | `/wf-e2e-unblock [--scenario=<id>]` | Xử lý blocked E2E scenarios |
| wf-e2e-retest | `/wf-e2e-retest [--scenario=<id>] [--all]` | Re-run failed E2E tests sau khi fix |

E2E shared infrastructure: `.claude/scripts/wf-e2e-shared/` — 4 scripts (`ensure-infra.sh`, `global-rw-lock.sh`, `lock-daemon.sh`, `version-snapshot.sh`). Protocol 22 (cross-session R/W lock) được áp dụng cho toàn bộ E2E pipeline.

**Standalone Skills:**

| Lệnh | Mục đích |
|------|----------|
| `/ui-ux-pro-max` | Professional UI/UX design system — colors, typography, icons, stacks (standalone, không trong workflow/) |
| `/wf-scan-target [--target=<path\|url>] [--module=<name>] [--compare=<spec>] [--profile=quick\|standard\|deep\|exhaustive] [--since=<git-ref>] [--resume] [--status]` | Quét một target (module, hệ thống, URL, hoặc path source code) → `module-map.md`, `target-map.json`, `feature-inventory.md`, `gap-report.md` (khi `--compare`). Standalone — KHÔNG thuộc main pipeline. Có thể consume optional bởi `/wf-add-scope`, `/wf-define-features`, `/wf-design`, `/wf-implement-feature` qua `--from-scan` |
| `/wf-diagram --module=<name> [--source-path=<path>] [--output-path=<path>] [--scope=full\|module-only\|system-only] [--resume] [--status]` | Sinh sơ đồ thiết kế UML + ERD cho module/hệ thống từ source code có sẵn. Output: Mermaid `.md` (context, component, erd-context-map, actors, usecase, class, state, activity, sequence) + DBML `.dbml` (database tổng + ERD module). Tuân thủ quy tắc lọc nghiêm ngặt: chỉ sinh activity ≥3 bước/có nhánh, state ≥3 trạng thái, sequence ≥3 components/complex. Standalone — KHÔNG thuộc main pipeline. Diagrams ở `output_path/` (default `./docs/diagrams/`), session metadata ở `.mc-data/work/wf-diagram/sessions/{id}/` |
| `/wf-cmi [--scope=system\|module=<id>\|feat=<id>] [--profile=quick\|standard\|deep\|exhaustive] [--dims=CD1,CD11,CD28,CD41,...] [--since=<git-ref>] [--from-fix-bugs] [--from-verify-sync] [--from-impl] [--auto-suggest] [--dry-run] [--ci] [--resume] [--status] [--session-id=<ID>] [--no-cache] [--show-graphs] [--exec-scenarios] [--scenarios-only] [--show-browser] [--mobile] [--strict-evidence] [--no-prompt] [--auto-fix-source]` | **v3.0.0 (2026-05-17) — E2E Scenario Engine ADD-ONLY 26 lanes + lane CD41 + Phase 9-10** Cross-Module Integrity Orchestrator — system-wide ERP integrity check + E2E test orchestration. Pipeline 8 phases v2 + **Phase 9-10 v3 opt-in**: Init → Discovery (**13 graphs**: 6 core + 7 plugin fe-component/fe-api-client/fe-permission/fe-route/be-domain/be-db-schema/be-cqrs) → Invariant Artifact (3-pass LLM) → **Coverage Dispatch 3-WAVE** (Wave 1 = 10 lanes graphs-only / Wave 2 = 10 lanes cross-layer / Wave 3 = 6 lanes final cross-ref **+CD41 nếu deep/exhaustive**, qua `.claude/scripts/wf-cmi/wave-coordinator.sh`) → Aggregate (35-36 dim matrix; threshold quick60/std80/deep95/exhaust100) → Regression Map → GAP + CDG → Report v3 (E2E Summary section conditional) → **Phase 9 E2E Execute (opt-in `--exec-scenarios`)** Playwright orchestration với lint 7 rules + 5x flakiness + stable-registry TTL 30d + quarantine → **Phase 10 E2E Resolution (auto-run nếu FAIL)** failure analyzer 7-type + Phase A browser-fix 5 strategies + Phase B source-fix (CDG E195 + spawn agents 8-section CORE-037) + loop-back gap-suggestions APPEND `kind='e2e_scenario_fix'` (anti-loop guard). Output: `integrity-report.md` (tiếng Việt ≤55 v2 / ≤70 v3 max bound) + `coverage-matrix.json` (schema **coverage-matrix-v3** với 36 dims) + sidecar `business-invariants.json` (Engine #4 KHÔNG bump registry) + `regression-map.json` + cross-skill `integrity-impact.json` (schema **integrity-impact-v3** với 2 v3 fields mới: e2e_execution_summary{12 fields} + scenarios_artifacts[] per-scenario; `readable_by=[integrity-impact-v1, integrity-impact-v2, integrity-impact-v3]` — ALL v1+v2 fields preserved 100% backward-compat) + Phase 9-10 outputs (`e2e-execution-report.md` + `e2e-results.json` v1 + `lint-report.json` v1 + `stable-registry.json` v1 + `quarantine-report.json` v1 + `resolution-report.md` + screenshots/). **26 active lanes v2** (CD1-CD7, CD9, CD11, CD13, CD15-CD18, CD23-CD26, CD28-CD31, CD37-CD40) **+ 1 v3 lane** (CD41 E2E Synth, Wave 3, profile=deep/exhaustive) + 9 SKIPPED + 5 skeleton CD32-36. **4 profiles**: quick (≥60%, 7 lanes Wave 1) / standard (≥80%, 13 lanes W1+2+3 subset) / deep (≥95%, **27 lanes full 3-wave + CD41**, 55-90 min v2 / 65-120 min nếu `--exec-scenarios`) / exhaustive (100%, all 27 + LLM enhance, 120-180 min v2 / 150-240 min nếu `--exec-scenarios`). **7 cờ v3 mới**: `--exec-scenarios` (bật Phase 9, default OFF), `--scenarios-only` (bypass Phase 1-8, re-execute Phase 9-10 trên session DONE đã có manifest), `--show-browser` (Playwright headed), `--mobile` (mobile emulation), `--strict-evidence` (100% coverage thay vì 80%), `--no-prompt` (CI bypass CDG), `--auto-fix-source` (Phase B source-fix, cần CDG E195 confirm). CDG mới: E195 source-fix confirm + E195b subset E2E execute confirm (3 options Execute all / Execute MUST-only Recommended / Cancel; `--no-prompt` silent default = `execute_must_only`). Browser unavailable → SKIP Phase 9-10 với E150 WARN graceful (CORE-033), vẫn xuất integrity-report v3 với `e2e_execution_summary=null`. Multi-session safe (Protocol 22 R/W lock). Cross-skill consumers (opt-in `--from-cmi`): wf-verify-sync, wf-fix-bugs, wf-implement-feature, wf-prepare-deployment, wf-design, wf-add-scope. ★★★ Logistics-critical lanes (CD28 MDM + CD30 Time & Numbering + CD31 Money & Tax + CD37 Regulatory Compliance + CD38 UI Coverage + CD39 Error UX + CD40 Print & Export). Migration v2→v3: xem `docs/04-skill-design/wf-cmi/v3-migration-notes.md` (BREAKING: NONE — ADD-ONLY 100% backward-compat). Architecture deep-dive: `docs/04-skill-design/wf-cmi/12-e2e-engine-arch.md`. User guide v3: `docs/06-user-guides/per-skill/wf-cmi-v3-guide.md`. Standalone — KHÔNG thuộc main pipeline. |

**Orchestrator (meta-workflows):**

| Lệnh | Mục đích |
|------|----------|
| `/new-project` | Full workflow: idea → deployment (dự án mới) |
| `/existing-project` | Onboard codebase + full workflow |
| `/feature-addition` | Thêm features (Phase 3+) |

**Self-audit:**

| Lệnh | Mục đích |
|------|----------|
| `/audit-devkit` | MCV3 self-audit: scan → verify → fix |
| `/audit-devkit-scan` | Scan components, build ground truth |
| `/audit-devkit-verify` | Cross-validate references + consistency |
| `/audit-devkit-fix` | Auto-fix với per-fix verification |
| `/audit-skill-output` | Kiểm tra output chất lượng vs SKILL.md design |
| `/audit-agents` | Audit agent/knowledge definitions compliance |

---

## Single Source of Truth

**`req-registry.json`** (`.mc-data/docs/_meta/req-registry.json`) là nguồn chân lý duy nhất cho mọi REQ-ID, FEAT-ID, và trạng thái triển khai.

**Quy tắc bắt buộc:**
- ĐỌC registry + docs trước khi thiết kế/code
- KHÔNG thêm tính năng ngoài registry
- Mỗi skill CHỈ update đúng fields được phân công (Safe-Write Protocol, CORE-006)
- `impl_status` chỉ có 4 giá trị: `not_started` | `in_progress` | `done` | `skipped`
- KHÔNG downgrade `impl_status` từ `done` → giá trị khác
- POST-GATE validation: T1 (file tồn tại) → T2 (không rỗng) → T3 (format đúng) → T4 (content required)

Chi tiết Safe-Write + Cross-Skill Output Path Contract: `.claude/rules/00-core.md` §4.

---

## REQ-ID Tracking

Mọi code file PHẢI có REQ-ID tham chiếu requirements:

```typescript
// REQ-ID: REQ-SALES-001
// FEAT-ID: FEAT-CRM-CUST-001
export class CustomerService { ... }
```

**Format:**
- Requirement: `REQ-[DEPT]-[NNN]` → `REQ-SALES-001`
- Complex: `REQ-[SYSTEM]-[MODULE]-[NNN]` → `REQ-CRM-CUST-001`

**Luồng truy vết:** `REQ-SALES-001` → `FEAT-CRM-CUST-001` → `UI-...` + `API-...` + `DB-...` → code comment

---

## Cấu Trúc Dữ Liệu Dự Án

Khi DEVKIT chạy trên dự án, nó tạo `.mc-data/`:

```
.mc-data/
├── docs/                          # Tài liệu 7 phases (Phase 0-6)
│   ├── _meta/
│   │   └── req-registry.json      # ★ SINGLE SOURCE OF TRUTH
│   ├── phase0-brainstorm/         # Khung dự án
│   ├── phase1-business/           # Nghiệp vụ
│   ├── phase2-features/           # Đặc tả tính năng ([sys]/[mod]/[feat].md)
│   ├── phase3-architecture/       # Kiến trúc + đặc tả kỹ thuật
│   ├── phase4-ux/                 # UX/UI (conditional)
│   ├── phase5-implementation/     # Sprints, tasks, roadmap
│   └── phase6-deployment/         # Deployment & user guides
├── work/                          # Working data per skill (checkpoints, status)
├── sync/                          # REQ-ID sync tracking
└── knowledge-base/                # Optional ghi chú bổ sung
```

Templates: `.claude/doc-framework/` — Xem [doc-framework/README.md](.claude/doc-framework/README.md)

---

## Cấu Trúc Thư Mục DEVKIT

```
.claude/
├── agents/                 # 62 agent definitions (5 teams + orchestrator)
│   ├── spec/               # Agent & Knowledge Construction Specification
│   └── procedures/         # Agent Procedures — HOW chi tiết per task (61 directories)
├── commands/               # 36 slash command definitions (entry points cho skills)
├── skills/
│   ├── workflow/           # 47 wf-* skills + status + _shared/ (Python utilities)
│   ├── workflows/          # 3 orchestrator workflows
│   ├── workflow-skill.md   # ★ TEMPLATE cho skill mới (v3.0)
│   ├── shared-protocols.md # Pure redirect (34 dòng) — backward-compat
│   ├── protocols/          # ★ 22 Protocol files (01-22) + README
│   ├── gitnexus/           # GitNexus skill files (exploring, impact, debugging, refactoring, guide, cli)
│   └── templates/          # 2 standalone templates (digest, execution-plan)
├── hooks/                  # 12 Pre/Post tool hooks (+ _hook-utils.sh + README)
├── rules/                  # 9 rule files (00-behavioral, 00-core, 01-07; path-scoped)
├── references/             # Domain knowledge (162 files, 29 domains)
├── doc-framework/          # 40 document templates (Phase 0-6) + 20 schema files
├── schemas/                # JSON schemas dùng chung
└── scripts/                # 160+ utility scripts (bash + 1 PowerShell wrapper + 1 JS)
    ├── audit/              # contract-conformance.sh, run-skill-evals.sh, EVAL-SCHEMA.md
    ├── tests/              # Smoke tests cho scripts
    ├── wf-add-scope/       # 12 as-*.sh helpers cho /wf-add-scope v3.0
    ├── wf-e2e-shared/      # 4 E2E infrastructure scripts (ensure-infra, global-rw-lock, lock-daemon, version-snapshot)
    ├── wf-implement-feature/  # Helpers cho /wf-implement-feature v4.0
    ├── wf-manage-change/   # 11 helpers cho /wf-manage-change v3.0
    ├── wf-preflight/       # Helpers cho /wf-preflight v3.x
    └── wf-verify-sync/     # Helpers cho /wf-verify-sync
    # + 7 scan-target-*.sh, 15 legacy-scan-*.sh, 15 wf-fix-*.sh, run-devkit-bash.ps1
```

**Root level**:
- `tools/` — Phase 5 integration test harness (Python pytest, 8 scenarios A-H, validators, fixtures)
- `scripts/` — Repo-level scripts (e.g., `sync-claude-to-eureka.sh` mirror config sang EUREKA-2026)
- `plans/` — Active improvement plans per skill version (wf-fix-bugs-v9, wf-implement-feature-v4, wf-cross-module-integrity/wf-cmi.md — spec skill toàn vẹn liên module cho EUREKA-2026, ...)
- `docs/` — Bộ tài liệu chuẩn hóa (sau tái cấu trúc v1, 2026-05-15) gồm 8 sections: `00-overview/` (định vị), `01-architecture/` (high-level), `02-standards/` (★ chuẩn ràng buộc), `03-design-patterns/` (11 patterns), `04-skill-design/` (canon per-skill), `05-review-standards/` (review checklist), `06-user-guides/` (end-user), `07-operations/` (vận hành), `08-reference/` (tra cứu nhanh) + `99-archive/` (superseded). Entry point: [docs/README.md](docs/README.md)
- `.mc-data/` — Runtime artifacts (gitignored). `.claude/` là read-only trong runtime
- `AGENTS.md` — Quick reference cho contributors (đọc cùng CLAUDE.md)

---

## Rules (`.claude/rules/`)

| Rule | Scope | Auto-load khi |
|------|-------|---------------|
| `00-behavioral` | Luôn | Mọi conversation — 4 BHV principles (Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution) |
| `00-core` | Luôn | Mọi conversation — 38 CORE rules (CORE-001 → CORE-038) |
| `01-coding` | `**/*.{ts,tsx,js,jsx,py,java,cs,go,rs}` | Source code |
| `02-api` | `**/*.controller.ts`, `**/api/**` | API/controller |
| `03-security` | Same as 01-coding | Source code |
| `04-i18n` | `**/*.{tsx,jsx,vue,svelte}`, `**/messages/**` | UI/i18n |
| `05-database` | `**/*.{repository,migration,schema,entity,model}.ts`, `**/*.sql` | DB-related |
| `06-domain` | Luôn | Mọi conversation |
| `07-project` | Luôn | Mọi conversation |

**Quy tắc bắt buộc khi sửa skills/agents** (BHV-003 + CORE-007):
- Giữ nguyên output paths, gate markers, contract với `.mc-data/` trừ khi chủ ý đổi workflow
- Khi đổi tên agent: kiểm tra chéo `subagent_type` ở mọi `Agent({...})` calls trong skills
- Mỗi `_contract.json` sửa đổi → chạy `validate-schema-sync.sh` ngay sau

---

## Chuẩn Skill MCV3 (CORE-032 → CORE-039)

Khi tạo mới hoặc sửa đổi skill trên MCV3, PHẢI tuân thủ 8 chuẩn kiến trúc sau (đúc kết từ wf-fix-bugs v10.0, wf-legacy-scan v5.0, và wf-cmi v2.0):

### CORE-032: Lazy-Load Procedures — Skill Architecture

```
SKILL.md là lean routing hub (≤500 dòng, KHÔNG chứa code thực thi):
  - Overview, arguments, phase routing map (bảng + flow diagram)
  - Condensed summaries per phase (input → output → steps overview)
  - PRE-GATE / POST-GATE file contract table
  - Output files table với template paths
  - Error codes quick lookup
  - Context & checkpoint thresholds

TOÀN BỘ execution logic trong procedure files riêng:
  - procedures/_shared.md — cross-cutting concerns
  - procedures/phase{N}-{name}.md — chi tiết từng phase
  - procedures/resume-status.md — --resume & --status handlers

QUY TẮC:
  - Mỗi procedure file CHỈ đọc khi tới phase tương ứng (lazy-load)
  - Phase transition qua PRE-GATE → execute → POST-GATE
  - Pipeline state update atomic sau mỗi POST-GATE
  - KHÔNG nhúng bash script inline
```

### CORE-033: CI-First Integration

```
CI PRE-GATE (3-step, chạy tại Phase Init):
  Na. LOAD CI CAPABILITIES — ci-detect.sh, check per-tool TTL
  Nb. INDEX FRESHNESS CHECK — ci-freshness-check.sh (4 mức)
  Nc. AGENT CONTEXT INJECTION — pass CI_CONTEXT vào spawned agents

CI-ROUTE: Primary tool → Secondary → Fallback (Grep/Glob)
KHÔNG hỏi user chọn tool — auto-detect + graceful degradation
```

### CORE-034: Namespaced Error Codes & Auto-Fix Budget

```
Error code ranges: E001-E009 (pipeline/session), E010-E019 (Phase 1), ...
  E090-E099 (CDG gates), E100-E109 (warnings)
Auto-fix budget: max 3 retries/phase, hết → ESCALATE (AskUserQuestion)
Error ledger: APPEND-only JSONL, output-only (không đọc lại làm input)
```

### CORE-035: Phase Output Organization

```
Session subdirectories: phase{N}-{name}/
Phase report: Phase{N}-report.md (tiếng Việt, ≤15 dòng, cho người không chuyên)
Atomic write: build tmp → validate JSON → mv tmp → target
Session ID: YYYY-MM-DD-{scope}-{slug}-{NN}
```

### CORE-036: Cross-Skill Artifact Contract

```
_contract.json có: orchestrates[], produces_for{}, consumes_from{}
Artifact phải schema versioned + audit_chain checksum
Consumer validate artifact ở PRE-GATE (T1→T2→T3)
```

### CORE-037: Agent Prompt Templates

```
Mỗi agent prompt PHẢI có 8 sections:
  1. Role declaration  2. Task instruction  3. Session context
  4. CI context injection  5. Playwright context (nếu applicable)
  6. Output contract  7. Ownership rules  8. Completion criteria
Spawn model="opus", max concurrency 10, 1 file = 1 writer
```

### CORE-038: Context Budget Management

```
< 65%    → Tiếp tục bình thường
65-80%   → Chuẩn bị checkpoint (lưu state files)
80-90%   → Lưu checkpoint, STOP sau phase hiện tại → hướng dẫn --resume
> 90%    → FORCE STOP (E009) — checkpoint bắt buộc
```

### CORE-039: Parallelization Strategy

```
Triết lý: sau khi đảm bảo accuracy + quality (Priority §0 mục 1),
thiết kế skill PHẢI CHỦ ĐỘNG tối ưu thời gian bằng song song hóa các bước
an toàn — không mặc định sequential.

BẮT BUỘC trong SKILL.md (skill mới hoặc khi overhaul):
  Section "Parallelization Strategy" — bảng phase-by-phase:
  | Phase/Step | Mode (PARALLEL/SEQUENTIAL/HYBRID) | Owner | Write scope | Lý do an toàn | Merge checkpoint |

  - Nếu 100% sequential → ghi rõ một dòng lý do
  - Ưu tiên pattern parallel-safe: lane parallel, wave dispatch, read-then-merge, bash parallel
  - Điều kiện cứng (CORE-025): contract rõ + 1 file = 1 writer + scope tách biệt + merge checkpoint

GRANDFATHERED: skill hiện có (trước 2026-05-16) không bị fail audit,
nhưng KHUYẾN NGHỊ bổ sung khi có cơ hội overhaul.
```

> Chi tiết đầy đủ: [`.claude/rules/00-core.md`](.claude/rules/00-core.md) §4i-4p.

---

## Hooks

| Hook | Trigger | Mục đích |
|------|---------|----------|
| `session-init.sh` | SessionStart | Khởi tạo session context |
| `privacy-block.sh` | PreToolUse (Read) | Chặn đọc sensitive files |
| `scout-block.sh` | PreToolUse (Glob) | Chặn scan ngoài scope |
| `validate-requirement-sync.sh` | PreToolUse (Write\|Edit) | Cảnh báo nếu code thiếu REQ-ID |
| `validate-critical-decision.sh` | PreToolUse (Write\|Edit) | WARNING cho hành động CDG — không block, chỉ cảnh báo |
| `pre-bash-safety.sh` | PreToolUse (Bash) | Chặn lệnh nguy hiểm |
| `update-sync-status.sh` | PostToolUse (Write\|Edit) | Cập nhật sync tracking |
| `validate-contract-sync.sh` | PostToolUse (Write\|Edit) | Validate với registry |
| `validate-ui-component.sh` | PostToolUse (Write\|Edit) | UI quality checks |
| `validate-naming-convention.sh` | PostToolUse (Write\|Edit) | lowercase-kebab-case (CORE-016/017) |
| `stop-session-verify.sh` | Stop | Verify sync trước khi kết thúc session |

---

## Mở Rộng DEVKIT

### Tạo Skill Mới

1. Copy `.claude/skills/workflow-skill.md` làm template
2. Tạo folder `.claude/skills/workflow/[skill-name]/SKILL.md`
3. **Áp dụng CORE-032:** SKILL.md ≤500 dòng (lean routing hub), logic thực thi trong `procedures/phase{N}-{name}.md`
4. **Áp dụng CORE-033:** Tích hợp CI PRE-GATE 3-step (Na/Nb/Nc) nếu skill cần đọc/analyze code
5. **Áp dụng CORE-034:** Định nghĩa error code namespace cho skill (phase-based ranges), error-ledger.json APPEND-only
6. **Áp dụng CORE-035:** Tổ chức output theo session subdirectories `phase{N}-{name}/`, Phase{N}-report.md ≤15 dòng tiếng Việt
7. **Áp dụng CORE-036:** Định nghĩa `produces_for`/`consumes_from` trong `_contract.json`, schema version cho artifact
8. **Áp dụng CORE-037:** Mọi agent spawn phải có 8-section prompt template (role, task, session, CI, playwright, output, ownership, completion)
9. **Áp dụng CORE-038:** Implement context budget checkpoint ở mỗi phase transition
10. **Áp dụng CORE-039:** Section **"Parallelization Strategy"** trong SKILL.md — bảng phase-by-phase với mode (PARALLEL/SEQUENTIAL/HYBRID), owner, write scope tách biệt, lý do an toàn, merge checkpoint. Nếu 100% sequential ghi rõ lý do. Triết lý: sau khi đảm bảo accuracy, **chủ động** tối ưu thời gian — không mặc định sequential. Ưu tiên pattern lane parallel/wave dispatch/read-then-merge/bash parallel.
11. Tuân thủ Quality Gate: PRE-GATE → EXECUTION → POST-GATE
12. Tạo `_contract.json` cùng `SKILL.md` — có `"$schema": "skill-contract-v1"` + fields: `skill`, `version`, `phase`, `description`, `registry_scope.fields_owned[]`, `outputs.working[].template`
13. Tạo `evals/evals.json` với ≥3 test cases
14. Tham chiếu shared protocols: `> **Protocol:** Xem \`.claude/skills/protocols/\` — \`NN-...\`` (xem [protocols/README.md](.claude/skills/protocols/README.md) cho quick map)
15. Chạy compliance audit + schema sync check

### Tạo Agent Mới

**Spec:** `.claude/agents/spec/README.md`

1. Đọc spec + dùng template `.claude/agents/spec/agent-definition-template.md`
2. Tạo Knowledge files TRƯỚC: `.claude/agents/spec/knowledge-template.md`
3. Đặt agent trong `.claude/agents/[category]/` (business/engineering/design/testing/review)
4. Thêm domain knowledge trong `.claude/references/team-expert/[domain]/`
5. Tên file (không `.md`) = giá trị `subagent_type`
6. Validate bằng Agent Checklist + Knowledge Checklist

### Sửa Đổi Skill Hiện Có

Khi sửa đổi skill:
- **Giữ nguyên output paths** — KHÔNG thay đổi contract với downstream skills (CORE-007, CORE-036)
- **Giữ nguyên gate markers** — PRE-GATE/POST-GATE validation phải tiếp tục hoạt động
- **Cập nhật _contract.json** nếu thay đổi output → chạy `validate-schema-sync.sh` ngay
- **Cập nhật version** trong SKILL.md và _contract.json
- **Kiểm tra cross-skill impact** — nếu skill sản xuất artifact được skill khác consume, verify schema version compatibility (CORE-036)
- **Chạy compliance audit** trước khi commit

---

## Ngôn Ngữ

| Loại | Ngôn ngữ |
|------|----------|
| Tài liệu, comments | **Tiếng Việt** |
| File names, variables, functions | **English** hoặc tiếng Việt không dấu |

---

## Environment

`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` enabled trong `.claude/settings.json` — cho phép agent team coordination. Hook metrics cũng được bật (`MCV3_HOOK_METRICS_ENABLED=1`).

Permissions được auto-approve cho Read/Write/Edit/Bash/Glob/Grep/WebFetch/WebSearch/Task/TodoWrite/NotebookEdit. Block Write cho `.env`, credentials, secrets, `.git/`, system paths. Block Bash cho destructive commands.

---

## Code Intelligence Integration

MCV3 tự động phát hiện và sử dụng GitNexus + Serena khi available trên target project. Cơ chế này được định nghĩa trong Protocol 20 ([.claude/skills/protocols/20-code-intelligence.md](.claude/skills/protocols/20-code-intelligence.md)).

| Tool | Purpose | When used |
|------|---------|-----------|
| GitNexus | Impact analysis, execution flows, API routes | System-level questions |
| Serena | Find definition, find references, rename symbol | Symbol-level operations |

**Auto-detection:** Skills tự động phát hiện qua `ci-detect.sh` → cache per-tool TTL tại `.mc-data/work/_meta/code-intelligence.json`.
**Index freshness:** Mỗi PRE-GATE kiểm tra index có khớp HEAD không qua `ci-freshness-check.sh` → cảnh báo nếu stale (4 mức: light ≤5, strong 6-20, severe >20 commits behind).
**Concurrency:** Lock-protected cache write (60s stale timeout). Lock bị giữ → fallback Grep (không block).
**Graceful degradation:** Thiếu tool → tự động fallback về Grep/Glob (zero regression).
**Zero-config:** Người dùng không cần làm gì để kích hoạt. Advanced: `MCV3_CI_RESCAN=1`.

### CI-ROUTE Quick Reference

| Task | Primary Tool | Fallback |
|------|-------------|----------|
| Impact analysis before edits | GitNexus `impact()` | Manual grep |
| Understand execution flow | GitNexus `query()` | Read + trace |
| Find symbol definition | Serena `find_definition` | Grep |
| Find all references | Serena `find_references` | Grep |
| Safe rename | Serena `rename_symbol` | Manual |
| Pre-commit check | GitNexus `detect_changes()` | `git diff --stat` |
| API route mapping | GitNexus `route_map()` | Grep |
| File structure overview | Serena `get_symbols_overview` | Read |
| Find by REQ-ID annotation | Both (cypher + find_refs) | Grep |

### Cache TTL

| Tool | Available TTL | Absent TTL |
|------|--------------|------------|
| GitNexus | 24h | 4h |
| Serena | 24h | 1h |

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **MCV3** (5030 symbols, 5584 relationships, 6 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/MCV3/context` | Codebase overview, check index freshness |
| `gitnexus://repo/MCV3/clusters` | All functional areas |
| `gitnexus://repo/MCV3/processes` | All execution flows |
| `gitnexus://repo/MCV3/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->

<!-- serena:start -->
# Serena — In-File Code Intelligence & Symbolic Editing

Serena provides LSP-powered code navigation and precise symbolic editing within files. It complements GitNexus: GitNexus answers "what breaks if I change X across the codebase?" while Serena answers "where is X defined, what does it do, and let me edit it surgically."

**Line numbers from Serena tools are 0-based** (unlike editor display which is 1-based).

## Reading Code (token-efficient)

```
PRIORITY ORDER (Serena-first):
1. get_symbols_overview({relative_path})         → High-level structure of a file
2. find_symbol({name_path_pattern, relative_path, include_body=true}) → Read a specific symbol
3. find_referencing_symbols({name_path, relative_path}) → Find all callers/importers
4. Read (built-in)                                → ONLY for non-code files or raw text
```

Never use Read for code discovery — use `get_symbols_overview` then `find_symbol` with `include_body=true` for the symbols you need.

## Editing Code (symbolic-first)

| Task | Serena Tool |
|------|-------------|
| Replace a function/method/class body | `replace_symbol_body({name_path, relative_path, body})` |
| Insert new code before a symbol | `insert_before_symbol({name_path, relative_path, body})` |
| Insert new code after a symbol | `insert_after_symbol({name_path, relative_path, body})` |
| Regex/string replacement within a file | `replace_content({relative_path, needle, repl, mode})` |
| Rename a symbol across codebase | `rename_symbol({name_path, relative_path, new_name})` |
| Safe delete (checks for references) | `safe_delete_symbol({name_path_pattern, relative_path})` |

For symbol-level edits, **always** use Serena tools instead of built-in Edit — they are more precise and token-efficient. Use `replace_content` for surgical changes within a symbol (e.g., changing a few lines inside a large function).

## Diagnostics

```bash
get_diagnostics_for_file({relative_path, min_severity}) → LSP errors/warnings/hints
```

## Project Memories

Serena maintains persistent project memories (separate from Claude's auto-memory at `~/.claude/projects/`). These store code insights across sessions:

- `list_memories()` → See what's stored
- `read_memory({memory_name})` → Load a specific memory
- `write_memory({memory_name, content})` → Save new insights

Current memories: `project_overview`, `suggested_commands`, `code_style_and_conventions`, `project_structure`, `task_completion_checklist`.

## Tool Selection Quick Reference

| Scenario | Tool to Use |
|----------|-------------|
| "What's in this file?" | Serena `get_symbols_overview` |
| "Show me function X" | Serena `find_symbol` with `include_body=true` |
| "Who calls X?" | GitNexus `context` or Serena `find_referencing_symbols` |
| "What breaks if I change X?" | GitNexus `impact` (cross-file blast radius) |
| "How does the auth flow work?" | GitNexus `query` (execution flows) |
| "Edit function X" | Serena `replace_symbol_body` |
| "Rename X everywhere" | GitNexus `rename` (graph-based, safer) |
| "Add method before Y" | Serena `insert_before_symbol` |
| "Check for LSP errors" | Serena `get_diagnostics_for_file` |
| "Find X by regex" | Grep (discovery) → then Serena for reading |

<!-- serena:end -->
