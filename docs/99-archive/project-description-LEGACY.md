# DEVKIT — Mô Tả Dự Án

> Bộ công cụ hỗ trợ phát triển phần mềm trên nền tảng **Claude Code**.

---

## Dự án là gì?

DEVKIT là một **bộ quy trình và công cụ** chạy trên nền tảng Claude Code, giúp người dùng biến ý tưởng thành phần mềm hoàn chỉnh — ngay cả khi họ chưa có mục tiêu rõ ràng.

DEVKIT hoạt động như một **đội ngũ chuyên gia ảo**: phân tích nhu cầu, tư vấn định hướng, xây dựng tài liệu, và triển khai phần mềm — thay mặt cho người dùng.

## Vấn đề giải quyết

- Người dùng có ý tưởng nhưng **chưa biết cần gì cụ thể** → không biết bắt đầu từ đâu
- Thiếu kiến thức chuyên môn trong lĩnh vực của mình để **định hướng dự án phần mềm**
- Ý tưởng → Code quá nhanh, **bỏ qua bước phân tích và thiết kế**
- **Mất ngữ cảnh** khi dự án phức tạp, không có quy trình chuẩn

## Cách người dùng sử dụng

Người dùng đưa ra yêu cầu ở dạng **ý tưởng sơ bộ**, ví dụ:

- *"Xây dựng phần mềm quản lý vận hành cho công ty xuất nhập khẩu"*
- *"Triển khai website cho công ty bán lẻ"*
- *"Triển khai website công ty theo tài liệu này..."*

Từ đó, DEVKIT sẽ **chủ động** hỗ trợ người dùng làm rõ yêu cầu, định hướng dự án, và dần dần hoàn thiện từ ý tưởng mơ hồ thành sản phẩm phần mềm.

## Quy trình 7 Phases (Phase 0-6)

### Phase 0: Brainstorm — Chốt khung dự án

- Người dùng mô tả ý tưởng bằng **ngôn ngữ phi kỹ thuật** (chat tự do)
- DEVKIT **brainstorm** cùng người dùng để làm rõ mục tiêu và định hướng dự án — cuộc trò chuyện ở dạng tư vấn doanh nghiệp, không đi sâu vào kỹ thuật
- **Skill:** `/wf-brainstorm`
- **Đầu ra:** `.mc-data/docs/phase0-brainstorm/P0-01-brainstorm.md`

### Phase 1: Phân tích yêu cầu nghiệp vụ

- DEVKIT huy động **đội ngũ chuyên gia ảo (AI Agents)** — đóng vai trò như những người vận hành và quản lý doanh nghiệp trong lĩnh vực của người dùng
- Đội ngũ chuyên gia có thể **thảo luận nhóm** (họp nội bộ) để cùng xây dựng và hoàn thiện các tài liệu — thay mặt cho người dùng
- Mỗi chuyên gia là một **AI Agent chuyên biệt**, được điều phối bởi một Agent Orchestrator
- **Skills:** `/wf-brainstorm` → `/wf-analyze-requirements`
- **Đầu ra:** Tổng quan dự án, phân tích nghiệp vụ, departments, requirements (REQ-IDs) trong `phase1-business/`

### Phase 2: Định nghĩa tính năng

- Chuyển requirements thành **feature specifications** chi tiết
- Mapping REQ-IDs sang FEAT-IDs, tạo user stories, business rules, permissions
- **Skill:** `/wf-define-features`
- **Đầu ra:** Feature specs theo cấu trúc `phase2-features/[system]/[module]/[feature].md`

### Phase 3: Thiết kế kiến trúc

- Từ feature specs → tạo ra các tài liệu thiết kế kỹ thuật
- **Skill:** `/wf-design`
- **Đầu ra:** Kiến trúc hệ thống, API contract, database schema, integration map, infra spec trong `phase3-architecture/`

### Phase 4: Thiết kế UX/UI (điều kiện)

- Chỉ chạy khi dự án có giao diện (web/mobile) — skip nếu API-only
- **Skill:** `/wf-design-ux`
- **Đầu ra:** Design system, navigation specs, screen groups trong `phase4-ux/`

### Phase 5: Lập kế hoạch & Triển khai code

- Phân tích dependency, xác định thứ tự implement, tạo sprint plans
- Coding theo TDD, testing, security review
- **Skills:** `/wf-plan-modules` → `/wf-implement-feature` → `/wf-verify-sync`
- **Đầu ra:** Implementation roadmap, sprint plans, task files, source code hoàn chỉnh trong `phase5-implementation/`

### Phase 6: Triển khai & Vận hành

- Tạo tài liệu triển khai, hướng dẫn sử dụng
- **Skill:** `/wf-prepare-deployment`
- **Đầu ra:** Deployment guide, user guide trong `phase6-deployment/`

### Workflow tổng thể

```
STANDARD PATH (dự án mới):
  Idea → /wf-brainstorm → /wf-analyze-requirements → /wf-define-features →
  /wf-design → /wf-design-ux (nếu có UI) → /wf-plan-modules → /wf-implement-feature →
  /wf-preflight → /wf-verify-sync → /wf-prepare-deployment
                                                                      ↑
                                              /wf-fix-bugs (bất kỳ lúc nào sau khi có code)

EXISTING PATH (dự án có sẵn, mọi kích cỡ):
  /wf-legacy-scan (all-in-one: detect → classify → extract → synthesize) →
  /wf-brainstorm* → /wf-analyze-requirements* → /wf-define-features* → /wf-design* →
  /wf-annotate-code (nếu có annotation gaps) →
  /wf-design-ux* (nếu có UI) → /wf-plan-modules → /wf-implement-feature → ...

  * = shared skills tự detect legacy mode và inject context
```

### Skills hỗ trợ

| Skill                    | Mục đích                                                                                                                        |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| `/wf-preflight`        | Health check toàn diện — validate registry + docs + code + tests                                                                |
| `/wf-fix-bugs`         | Tìm và sửa lỗi — preflight → triage → fix → docs sync → verify                                                            |
| `/status`              | Xem tiến độ triển khai dự án                                                                                                 |
| `/audit-agents`        | Audit agent & knowledge definitions compliance                                                                                     |
| `/audit-devkit`        | MCV3 self-audit toàn diện — agents + skills + templates + workflow                                                              |
| `/audit-skill-output`  | Kiểm tra chất lượng output — so sánh actual vs SKILL.md design, auto-fix                                                     |
| `/wf-legacy-scan`      | Quét toàn diện dự án có sẵn: detect → classify → extract → synthesize → project-context.md                              |
| `/wf-legacy-classify`  | Phân loại files + glossary (standalone hoặc internal stage của wf-legacy-scan)                                                 |
| `/wf-legacy-extract`   | Trích xuất requirements/features (standalone hoặc internal stage của wf-legacy-scan)                                           |
| `/wf-annotate-code`    | Inject REQ-ID vào existing code (nếu có annotation gaps)                                                                        |
| `/wf-add-scope`        | Thêm modules + features mới vào registry (append-only, không sửa existing)                                                    |
| `/wf-manage-change`    | Xử lý yêu cầu thay đổi/bổ sung/sửa đổi tính năng — phân tích impact → thực hiện thay đổi docs + code → verify |
| `/wf-scan-target`      | **Standalone** — Quét một target (module, hệ thống, URL hoặc path source code) → `module-map.md`, `target-map.json`, `feature-inventory.md`, `gap-report.md` (khi `--compare`). Không thuộc main pipeline. Có thể consume optional bởi `/wf-add-scope`, `/wf-define-features`, `/wf-design`, `/wf-implement-feature` qua `--from-scan` |
| `/audit-devkit-scan`   | Scan DEVKIT components theo batches, build ground truth index                                                                      |
| `/audit-devkit-verify` | Cross-validate references, workflow integrity, consistency                                                                         |
| `/audit-devkit-fix`    | Auto-fix với per-fix verification                                                                                                 |
| `/ui-ux-pro-max`       | UI/UX design nâng cao (50+ styles, 97 palettes, 57 font pairings)                                                                 |

### Orchestrator Workflows

| Skill                 | Mục đích                                      |
| --------------------- | ------------------------------------------------ |
| `/new-project`      | Orchestrator: idea → deployment (dự án mới)  |
| `/feature-addition` | Thêm features vào dự án hiện có (Phase 3+) |
| `/existing-project` | Onboard codebase + full workflow                 |

## Đội ngũ AI Agents

### Năm đội chính + Orchestrator

| Đội                  | Vị trí                           | Số lượng | Vai trò                                         |
| ---------------------- | ---------------------------------- | ----------- | ------------------------------------------------ |
| **Business**     | `.claude/agents/business/`       | 25 agents   | Phân tích nghiệp vụ (BA + 24 domain experts) |
| **Engineering**  | `.claude/agents/engineering/`    | 14 agents   | Thiết kế kỹ thuật & triển khai code         |
| **Design**       | `.claude/agents/design/`         | 7 agents    | UX/UI design                                     |
| **Testing**      | `.claude/agents/testing/`        | 9 agents    | Kiểm thử chất lượng                         |
| **Review**       | `.claude/agents/review/`         | 6 agents    | Kiểm tra chất lượng DEVKIT                   |
| **Orchestrator** | `.claude/agents/orchestrator.md` | 1 agent     | Điều phối giữa các đội                    |

**Tổng cộng: 62 agents**

### Team Business — 25 chuyên gia nghiệp vụ

business-analyst (BA chính), compliance, customer, data, ecommerce, education, enterprise-risk, finance, healthcare, hr, insurance, investment, legal, logistics, manufacturing, marketing, operations, paid-media, procurement, product, quality-excellence, real-estate, retail, sales, strategy

### Team Engineering — 14 chuyên gia kỹ thuật

architect, developer, frontend-developer, mobile-developer, embedded-engineer, ai-engineer, ai-data-remediation-engineer, data-engineer, dba, devops, sre, security, tech-writer, automation-architect

### Team Design — 7 chuyên gia thiết kế

ux-designer, ui-designer, ux-architect, brand-guardian, ux-researcher, inclusive-visuals-specialist, image-prompt-engineer

### Team Testing — 9 chuyên gia kiểm thử

qa-lead, code-reviewer, api-tester, accessibility-auditor, evidence-collector, performance-benchmarker, integration-certifier, model-qa, reality-checker

### Team Review — 6 agents kiểm tra chất lượng DEVKIT

review-orchestrator, agent-auditor, cross-reference-auditor, skill-auditor, template-auditor, workflow-auditor

## Cấu trúc dữ liệu dự án

Khi DEVKIT được sử dụng, nó tạo thư mục **`.mc-data/`** chứa toàn bộ tài liệu và dữ liệu dự án. **Single Source of Truth** là file `req-registry.json`.

### Cấu trúc `.mc-data/`

```
.mc-data/
├── docs/                              # Tài liệu theo doc-framework 7 phases (Phase 0-6)
│   ├── _meta/
│   │   └── req-registry.json          # ★ SINGLE SOURCE OF TRUTH
│   ├── phase0-brainstorm/             # Brainstorm — chốt khung dự án
│   ├── phase1-business/               # Business requirements
│   ├── phase2-features/               # Feature specifications
│   ├── phase3-architecture/           # Architecture + technical specs
│   ├── phase4-ux/                     # UX/UI design (nếu có giao diện)
│   ├── phase5-implementation/         # Sprints, tasks, roadmap
│   └── phase6-deployment/            # Deployment & user guides
├── work/                              # Working data per skill (session-isolated v3.0+)
│   ├── wf-analyze-requirements/
│   │   └── sessions/{id}/             # Session-isolated run data (ADR-OPT-02)
│   ├── wf-define-features/
│   │   └── sessions/{id}/
│   ├── wf-design/
│   │   └── sessions/{id}/
│   ├── wf-design-ux/
│   │   └── sessions/{id}/
│   ├── wf-plan-modules/
│   │   └── sessions/{id}/
│   ├── wf-fix-bugs/                   # /wf-fix-bugs working files (triage, fix reports, status)
│   ├── wf-implement-feature/          # /wf-implement-feature working files
│   ├── wf-manage-change/              # /wf-manage-change working files (change reports, status)
│   ├── wf-preflight/                  # /wf-preflight working files (report, status, history)
│   ├── legacy-scan/                   # /wf-legacy-scan working files (ledger, inventory, classified, extracted)
│   └── audit-skill-output/            # /audit-skill-output audit reports
├── sync/                              # REQ-ID sync tracking
└── knowledge-base/                    # Optional — ghi chú bổ sung
```

### Nguyên tắc

| Nguyên tắc                   | Lý do                                                                  |
| ------------------------------ | ----------------------------------------------------------------------- |
| **1 feature = 1 file**   | Dễ đọc, dễ sửa, tránh context overload                            |
| **1 skill = 1 phase**    | Mỗi skill chỉ tạo tài liệu trong phạm vi 1 phase                  |
| **Registry là SSOT**    | `req-registry.json` là nguồn chân lý duy nhất cho REQ-IDs        |
| **Cấu trúc mở rộng** | Thêm system/module/feature chỉ cần thêm file mới                   |
| **Safe-Write Protocol**  | Mỗi skill chỉ update đúng fields được phân công trong registry |

## Cấu trúc DEVKIT

```
.claude/
├── agents/                 # Agent definitions (62 agents)
│   ├── orchestrator.md     # Điều phối trung tâm
│   ├── business/           # 25 agents — BA + 24 domain experts
│   ├── engineering/        # 14 agents — architect, developer, devops, embedded, etc.
│   ├── design/             # 7 agents — UX/UI design
│   ├── testing/            # 9 agents — QA, code review, performance, etc.
│   ├── review/             # 6 agents — DEVKIT self-quality
│   └── procedures/         # Agent Procedures — HOW chi tiết per task, per agent
│       └── [agent-name]/   # 230+ procedure files across 61 agent folders
├── skills/                 # Skills — user-facing workflow steps (42 lệnh tổng)
│   ├── workflow/           # 31 workflow skills (wf-*) — gồm 13 spawned dimension lanes (QD1–QD11) + wf-scan-target/wf-diagram standalone
│   ├── workflows/          # 3 orchestrator workflows (new-project, existing-project, feature-addition)
│   └── (root)              # 8 utility skills (audit-agents, audit-devkit, audit-devkit-scan/verify/fix, audit-skill-output, status, ui-ux-pro-max)
├── hooks/                  # 11 Pre/Post tool hooks (+ _hook-utils.sh shared)
├── rules/                  # 9 rule files (00-behavioral, 00-core, 01-coding → 07-project)
├── references/             # 162 domain knowledge files cho experts
│   └── team-expert/        # 29 domain folders
├── doc-framework/          # 40 document templates + 20 schema files (Phase 0-6)
└── scripts/                # 100+ utility scripts (compliance audit, schema sync, legacy-scan helpers, scan-target helpers, wf-fix-* helpers, ci-* helpers)
```

## Cải tiến Hiệu năng — ADR-OPT (v3.0+)

Bộ 10 quyết định kiến trúc (ADR-OPT-01 đến ADR-OPT-10) được áp dụng cho 5 workflow skills chính (wf-analyze-requirements, wf-define-features, wf-design, wf-design-ux, wf-plan-modules):

| Cải tiến | Mô tả | Lợi ích |
|----------|-------|---------|
| **Session Isolation** (ADR-OPT-02) | Mỗi lần chạy skill tạo session directory riêng `sessions/{id}/` | Không mất dữ liệu khi resume; chạy lại không ghi đè session cũ |
| **Workload Gate** (ADR-OPT-03) | Ước lượng khối lượng công việc trước khi thực thi; cảnh báo hoặc chặn nếu vượt ngưỡng | Ngăn chặn skill timeout giữa chừng; user chủ động quyết định scope |
| **Lane Dispatch** (ADR-OPT-01) | Chạy song song nhiều agents theo modules/departments | Tăng tốc độ xử lý dự án lớn (nhiều modules) |
| **Signal Aggregation** (ADR-OPT-04) | Dedup và hợp nhất outputs từ parallel lanes trước khi ghi canonical | Tránh trùng lặp và xung đột khi lanes hoàn thành không đồng bộ |
| **Template Strip** (ADR-OPT-05) | Loại bỏ `_template_notes` khỏi digest artifacts trước khi handoff | Digest sạch — downstream skills không đọc nhầm metadata |
| **CDG Tokens** (ADR-OPT-08) | Critical Decision Gate — user confirm trước hành động không thể undo | Ngăn xóa/skip module do AI tự quyết định sai |

**Kết quả:** 5 skills đã rollout ADR-OPT đầy đủ (Phase 2-3 signoff hoàn tất 2026-04-23). Xem chi tiết tại `docs/design/skills/ADR-downstream-skills-optimization-signoff.md`.

## Nền tảng công nghệ

- Chạy trên **Claude Code** (CLI & IDE)
- Tuân thủ Claude Code conventions: `.claude/`, agents, skills, hooks, rules
- Documentation & comments: **Tiếng Việt**
- File names, variables, functions: **English** hoặc tiếng Việt không dấu
