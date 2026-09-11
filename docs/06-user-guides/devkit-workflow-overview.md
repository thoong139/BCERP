# DEVKIT Workflow - Tổng Quan Toàn Bộ Quy Trình

> **Phiên bản:** 4.4.0
> **Cập nhật:** 2026-05-12 (đồng bộ với wf-fix-bugs v9.1.x — 11 dimension lanes QD1–QD11)
> **Mục đích:** Mô tả toàn bộ quy trình xử lý công việc của DEVKIT, từ ý tưởng ban đầu đến triển khai thực tế — áp dụng cho cả **dự án mới** và **dự án đang phát triển**.

---

## Mục Lục

- [Tổng Quan Workflow](#tổng-quan-workflow)
- [Hai Góc Độ Sử Dụng](#hai-góc-độ-sử-dụng)
- [Giai đoạn A: Phân Tích Yêu Cầu &amp; Xây Dựng Tài Liệu](#giai-đoạn-a-phân-tích-yêu-cầu--xây-dựng-tài-liệu)
  - [Track 1: Dự Án Mới — Điểm Vào](#track-1-dự-án-mới--điểm-vào)
  - [Track 2: Dự Án Đang Phát Triển — Điểm Vào](#track-2-dự-án-đang-phát-triển--điểm-vào)
  - [Các Bước Chung (Shared)](#các-bước-chung-shared---giai-đoạn-a)
- [Giai đoạn B: Triển Khai Lập Trình](#giai-đoạn-b-triển-khai-lập-trình)
  - [Kịch Bản Dự Án Mới](#kịch-bản-dự-án-mới)
  - [Kịch Bản Dự Án Đang Phát Triển](#kịch-bản-dự-án-đang-phát-triển)
  - [Kịch Bản Dùng Chung](#kịch-bản-dùng-chung)
- [Giai đoạn C: Đóng Gói &amp; Chuẩn Bị Triển Khai (Dùng Chung)](#giai-đoạn-c-đóng-gói--chuẩn-bị-triển-khai-dùng-chung)
- [Phụ Lục](#phụ-lục)

---

## Tổng Quan Workflow

### Sơ đồ tổng thể 3 giai đoạn × 2 góc độ

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                          DEVKIT WORKFLOW TỔNG THỂ                                │
│                                                                                  │
│                    ┌────────────────────────────────┐                            │
│                    │   Người dùng có dự án          │                            │
│                    └───────────┬────────────────────┘                            │
│                                │                                                 │
│                    ┌───────────▼────────────────────┐                            │
│                    │   DỰ ÁN MỚI hay ĐANG PHÁT TRIỂN? │                         │
│                    └───────┬──────────────┬─────────┘                            │
│                            │              │                                      │
│                   MỚI      │              │   ĐANG PHÁT TRIỂN                   │
│                            │              │                                      │
│  ┌─────────────────────────▼──┐  ┌───────▼─────────────────────────────────┐    │
│  │  GIAI ĐOẠN A (Track 1)     │  │  GIAI ĐOẠN A (Track 2)                 │    │
│  │                             │  │                                         │    │
│  │  /wf-brainstorm             │  │  Tình huống 1: Chưa có .mc-data/      │    │
│  │       │                     │  │  → /wf-legacy-scan pipeline           │    │
│  │       ▼                     │  │                                         │    │
│  │  /wf-analyze-requirements   │  │  Tình huống 2: Đã có .mc-data/        │    │
│  │       │                     │  │  → /status → tiếp tục phase dang dở   │    │
│  │       ▼                     │  │                                         │    │
│  │  /wf-define-features    ◄───┼──┤  Tình huống 3: Thêm tính năng        │    │
│  │       │                     │  │  → /feature-addition                   │    │
│  │       ▼                     │  │                                         │    │
│  │  /wf-design                 │  │  Tình huống 4: Thay đổi requirements  │    │
│  │       │                     │  │  → /wf-analyze-requirements [scope]    │    │
│  │       ▼                     │  │                                         │    │
│  │  /wf-design-ux (nếu UI)    │  │  → Hội nhập vào CÁC BƯỚC CHUNG ──────┤    │
│  │       │                     │  └─────────────────────────────────────────┘    │
│  │       ▼                     │                                                 │
│  │  /wf-plan-modules           │                                                 │
│  └─────────────┬───────────────┘                                                 │
│                │                                                                  │
│                ▼                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────┐      │
│  │  GIAI ĐOẠN B: TRIỂN KHAI LẬP TRÌNH (DÙNG CHUNG)                     │      │
│  │                                                                        │      │
│  │  /wf-implement-feature ──► /wf-preflight ──► /wf-verify-sync          │      │
│  │       ▲                        │                                       │      │
│  │       └──── /wf-fix-bugs ◄─────┘  *(v9.0+: pure orchestrator; spawns    │      │
│  │                                     11 dimension lanes (QD1–QD11) →     │      │
│  │                                     wf-fix-triage → wf-fix-execute)*    │      │
│  │                                                                        │      │
│  │  Dự án mới: Tạo system, hoàn thiện module/feature                    │      │
│  │  Dự án đang PT: Thêm module, hotfix, refactor, thay đổi scope       │      │
│  └────────────────────────────────────────────────────────────────────────┘      │
│                │                                                                  │
│                ▼                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────┐      │
│  │  GIAI ĐOẠN C: ĐÓNG GÓI & CHUẨN BỊ TRIỂN KHAI (DÙNG CHUNG)         │      │
│  │                                                                        │      │
│  │  /wf-prepare-deployment ──► CI/CD ──► Staging ──► Go-Live             │      │
│  └────────────────────────────────────────────────────────────────────────┘      │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### Đội ngũ AI Agent tham gia

| Đội                      | Thành viên                                                                                                                                                                                                                                                                | Vai trò chính                               |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| **Business** (20) | business-analyst, compliance-expert, customer-expert, data-expert, ecommerce-expert, enterprise-risk-expert, finance-expert, healthcare-expert, hr-expert, legal-expert, logistics-expert, manufacturing-expert, marketing-expert, operations-expert, paid-media-expert, procurement-expert, product-expert, quality-excellence-expert, retail-expert, sales-expert | Phân tích nghiệp vụ (BA + 19 domain experts) |
| **Engineering** (13) | architect, developer, frontend-developer, mobile-developer, ai-engineer, ai-data-remediation-engineer, data-engineer, dba, devops, sre, security, tech-writer, automation-architect | Thiết kế kỹ thuật & triển khai code |
| **Design** (7) | ux-designer, ui-designer, ux-architect, brand-guardian, ux-researcher, inclusive-visuals-specialist, image-prompt-engineer | UX/UI design |
| **Testing** (9) | qa-lead, code-reviewer, api-tester, accessibility-auditor, evidence-collector, performance-benchmarker, integration-certifier, model-qa, reality-checker | Kiểm thử chất lượng |
| **Review** (6) | review-orchestrator, agent-auditor, skill-auditor, template-auditor, cross-reference-auditor, workflow-auditor | Kiểm tra chất lượng DEVKIT |
| **Orchestrator** (1) | orchestrator | Điều phối toàn bộ quy trình |

### Single Source of Truth

```
.mc-data/docs/_meta/req-registry.json    ← Nguồn chân lý duy nhất (Primary SSOT)
```

`req-registry.json` chứa toàn bộ: systems, modules, departments, requirements (REQ-IDs), features, implementation order. Mọi skill, agent, và quy trình đều đọc và ghi vào `.mc-data/`. Knowledge-base (`.mc-data/knowledge-base/`) là optional, dùng cho ghi chú bổ sung.

### Cấu trúc 7 Phases (Phase 0-6)

| Phase | Thư mục                  | Skill                                                | Nội dung                                |
| ----- | -------------------------- | ------------------------------------------------------ | ---------------------------------------- |
| 0     | `phase0-brainstorm/`     | `/wf-brainstorm`                                     | Brainstorm — chốt khung dự án        |
| 1     | `phase1-business/`       | `/wf-analyze-requirements`                           | Yêu cầu nghiệp vụ                    |
| 2     | `phase2-features/`       | `/wf-define-features`                                | Feature specifications                   |
| 3     | `phase3-architecture/`   | `/wf-design`                                         | Kiến trúc, API, DB, integration, infra |
| 4     | `phase4-ux/`             | `/wf-design-ux` (chỉ khi có UI)                    | Design system, navigation, screen groups |
| 5     | `phase5-implementation/` | `/wf-plan-modules` + `/wf-implement-feature`       | Roadmap, sprints, tasks, code            |
| 6     | `phase6-deployment/`     | `/wf-prepare-deployment`                             | Deployment guide, user guide             |

---

## Hai Góc Độ Sử Dụng

DEVKIT phục vụ **hai loại dự án** với entry points khác nhau nhưng hội tụ về cùng quy trình triển khai:

### So sánh tổng quan

| Tiêu chí | Dự Án Mới | Dự Án Đang Phát Triển |
| --- | --- | --- |
| **Điểm vào** | `/wf-brainstorm` hoặc `/new-project` | `/existing-project`, `/feature-addition`, hoặc `/status` |
| **Đã có code?** | Không | Có (toàn bộ hoặc một phần) |
| **Đã có .mc-data/?** | Không | Có thể có hoặc không |
| **Phase A** | Chạy đầy đủ Phase 0 → 5 | Tùy tình huống — có thể bắt đầu từ bất kỳ phase nào |
| **Phase B** | Triển khai toàn bộ từ đầu | Bổ sung, sửa lỗi, mở rộng, hoặc refactor |
| **Phase C** | Dùng chung | Dùng chung |

### Góc độ 1: Dự Án Mới — Quy trình đầy đủ

```
/wf-brainstorm → /wf-analyze-requirements → /wf-define-features →
/wf-design → /wf-design-ux (nếu UI) → /wf-plan-modules →
/wf-implement-feature × N → /wf-preflight → /wf-fix-bugs → /wf-verify-sync →
/wf-prepare-deployment
                                                      ↑
                                      /wf-manage-change (bất kỳ lúc nào sau khi có registry)
```

### Góc độ 2: Dự Án Đang Phát Triển — Các tình huống

| # | Tình huống | Entry Point | Quy trình |
| --- | --- | --- | --- |
| 1 | **Onboard lần đầu** — Có code/docs, chưa có `.mc-data/` | `/wf-legacy-scan` (all-in-one) | `/wf-legacy-scan` (all-in-one: detect → classify → extract → synthesize) → `/wf-brainstorm`* → `/wf-analyze-requirements`* → `/wf-define-features`* → `/wf-design`* → `/wf-annotate-code` (nếu có annotation gaps) → `/wf-design-ux`* (nếu UI) → `/wf-plan-modules` → tiếp tục |
| 2 | **Resume dự án DEVKIT** — Đã có `.mc-data/`, bị pause | `/status` | Kiểm tra tiến độ → xác định phase đang dở → tiếp tục từ đó |
| 3 | **Thêm tính năng mới** — Dự án đang chạy, cần bổ sung | `/feature-addition` | `/wf-analyze-requirements [scope]` → `/wf-define-features` → `/wf-design` → implement |
| 4 | **Thêm system mới** — Mở rộng quy mô dự án | B1 (xem Giai đoạn B) | Brainstorm system → update registry → analyze → design → implement |
| 5 | **Thay đổi requirements** — Business thay đổi yêu cầu | `/wf-manage-change` hoặc `/wf-analyze-requirements [scope]` | `/wf-manage-change` (impact analysis + code changes) hoặc Re-analyze scope → update features → update design → re-implement |
| 6 | **Production hotfix** — Fix gấp lỗi production | `/wf-fix-bugs` | Triage → fix → test → verify (minimal workflow, không qua full Phase A) |
| 7 | **Refactor / Migration** — Nâng cấp tech stack | `/wf-design` (partial) | Update architecture → implement changes → regression test → verify |
| 8 | **Security hardening** — Tăng cường bảo mật | B7 (xem Giai đoạn B) | Security audit → fix → re-audit → APPROVED |

### Các giai đoạn dùng chung

Bất kể dự án mới hay đang phát triển, các giai đoạn sau **hoạt động giống nhau**:

| Giai đoạn / Skill | Dùng chung | Ghi chú |
| --- | --- | --- |
| `/wf-analyze-requirements` | ✅ | Dự án mới: phân tích toàn bộ. Đang PT: phân tích scope bị ảnh hưởng |
| `/wf-define-features` | ✅ | Chuyển đổi REQ → FEAT (mới hoặc bổ sung) |
| `/wf-design` | ✅ | Thiết kế kiến trúc (mới hoặc cập nhật) |
| `/wf-design-ux` | ✅ | Chỉ khi có UI — mới hoặc cập nhật |
| `/wf-plan-modules` | ✅ | Lập kế hoạch triển khai (mới hoặc cập nhật) |
| `/wf-implement-feature` | ✅ | TDD implementation — giống nhau cho cả 2 |
| `/wf-preflight` | ✅ | Health check — giống nhau |
| `/wf-fix-bugs` | ✅ | Fix lỗi — giống nhau |
| `/wf-verify-sync` | ✅ | Kiểm tra đồng bộ — giống nhau |
| `/wf-prepare-deployment` | ✅ | Chuẩn bị triển khai — giống nhau |
| `/wf-manage-change` | ✅ | Xử lý thay đổi/bổ sung/sửa đổi tính năng — bất kỳ lúc nào sau khi có registry |
| `/wf-add-scope` | ✅ | Thêm modules + features vào registry (append-only) |
| `/wf-scan-target` | ✅ | **Standalone** — quét 1 module/hệ thống/URL/path → `module-map.md`, `target-map.json`, `feature-inventory.md`, `gap-report.md` (khi `--compare`). Optional input cho `/wf-add-scope`, `/wf-define-features`, `/wf-design`, `/wf-implement-feature` qua `--from-scan` |
| `/wf-brainstorm` | ✅* | Dự án mới: đầy đủ. Dự án có sẵn: detect legacy mode (CORE-021), context injection |
| `/wf-legacy-scan` | ❌ | Chỉ dự án có sẵn — detection + assessment + inventory (Stage 0-1) |
| `/wf-legacy-classify` | ❌ | Classify files theo category — pipeline step 2 |
| `/wf-legacy-extract` | ❌ | Extract requirements & features — pipeline step 3 |
| `/wf-annotate-code` | ❌ | Inject REQ-ID vào code — sau /wf-design legacy mode (conditional) |
| `/audit-skill-output` | ✅ | Kiểm tra chất lượng output của skill |

---

## Giai Đoạn A: Phân Tích Yêu Cầu & Xây Dựng Tài Liệu

### Mô tả

Giai đoạn này thực hiện **xây dựng toàn bộ tài liệu** cho dự án: từ ý tưởng ban đầu → phân tích nghiệp vụ → thiết kế kỹ thuật → kế hoạch triển khai. Mục tiêu là để giai đoạn triển khai (Giai đoạn B) có thể bám sát tài liệu và thực thi chính xác.

**Dự án mới** chạy đầy đủ từ Phase 0 → Phase 5.
**Dự án đang phát triển** bắt đầu từ entry point phù hợp, sau đó hội nhập vào các bước chung.

### Sơ đồ quy trình Giai đoạn A

```
                    ┌──────────────────────────────┐
                    │   Người dùng có dự án         │
                    └────────┬─────────────────────┘
                             │
                    ┌────────▼────────────────┐
                    │  DỰ ÁN MỚI hay          │
                    │  ĐANG PHÁT TRIỂN?        │
                    └────────┬──────┬──────────┘
                             │      │
                    MỚI      │      │    ĐANG PHÁT TRIỂN
                             │      │
              ┌──────────────▼┐    ┌▼──────────────────────────────────┐
              │ TRACK 1        │    │ TRACK 2                           │
              │                │    │                                    │
              │ A1: Brainstorm │    │ Tình huống 1: Chưa có .mc-data/  │
              │ (Bắt buộc)    │    │ → A3: Onboard → /wf-legacy-scan pipeline │
              └───────┬───────┘    │                                    │
                      │            │ Tình huống 2: Đã có .mc-data/     │
                      │            │ → /status → Resume từ phase dở    │
                      │            │                                    │
                      │            │ Tình huống 3: Thêm tính năng      │
                      │            │ → A2 (scoped) → A5b → A5          │
                      │            │                                    │
                      │            │ Tình huống 4: Thay đổi REQs       │
                      │            │ → A2 (re-analyze) → A5b → A5      │
                      │            └─────────┬────────────────────────┘
                      │                      │
                      └──────────┬───────────┘
                                 │
                      ┌──────────▼──────────┐
                      │ A2: Analyze          │  Phase 1
                      │ Requirements         │  (DÙNG CHUNG)
                      └──────────┬──────────┘
                                 │
                      ┌──────────▼──────────┐
                      │ A5b: Define Features │  Phase 2
                      │                      │  (DÙNG CHUNG)
                      └──────────┬──────────┘
                                 │
                      ┌──────────▼──────────┐
                      │ A5: Design           │  Phase 3
                      │                      │  (DÙNG CHUNG)
                      └──────────┬──────────┘
                                 │
                      ┌──────────▼──────────┐
                      │ A5c: Design UX       │  Phase 4
                      │ (chỉ khi có UI)      │  (DÙNG CHUNG)
                      └──────────┬──────────┘
                                 │
                      ┌──────────▼──────────┐
                      │ A6: Plan Modules     │  Phase 5
                      │                      │  (DÙNG CHUNG)
                      └──────────┬──────────┘
                                 │
                                 ▼
                      Chuyển sang Giai đoạn B
```

---

### Track 1: Dự Án Mới — Điểm Vào

#### A1. Brainstorm — Làm Rõ Ý Tưởng & Khởi Tạo Dự Án

**Skill:** `/wf-brainstorm`
**Khi nào dùng:** Entry point bắt buộc cho dự án mới — làm rõ ý tưởng, xác định scope, khởi tạo `.mc-data/`.
**Bắt buộc:** Không được skip (CORE-002: Không skip phases).
**Chỉ áp dụng:** Dự án mới (dự án có sẵn dùng `/wf-legacy-scan` thay thế).

##### Quy trình

```
Người dùng mô tả ý tưởng
         │
         ▼
┌─────────────────────────────────────┐
│ Phase 1: Hội thoại tự nhiên        │
│ • Hỏi 3-4 câu hỏi mở             │
│   - Lĩnh vực kinh doanh?           │
│   - Hệ thống cần xây dựng?         │
│   - Đối tượng sử dụng? Pain points?│
│   - Quy mô? (nhỏ/trung/lớn)       │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ Phase 2: Phân tích nội bộ (AI)     │
│ • Xác định loại nghiệp vụ          │
│   (Manufacturing, Retail, Finance…) │
│ • Xác định loại hệ thống           │
│   (ERP, CRM, HRM, WMS, POS…)       │
│ • Đề xuất hướng thiết kế UI/UX     │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ Phase 3: Xác nhận với user          │
│ • Trình bày tóm tắt dự án          │
│ • Đề xuất đội Expert phù hợp       │
│ • User confirm / điều chỉnh        │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ Phase 4: Lưu kết quả               │
│ • Tạo P0-01-brainstorm.md          │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ Phase 5: Khởi Tạo Cấu Trúc Dự Án   │
│ • Kiểm tra .mc-data/ đã tồn tại    │
│   → Reset / Backup / Merge / Cancel │
│ • Tạo cấu trúc .mc-data/           │
│ • Seed req-registry.json            │
└─────────────────────────────────────┘
```

##### Output

| File                    | Vị trí                             | Nội dung                                                                                       |
| ----------------------- | ------------------------------------ | ----------------------------------------------------------------------------------------------- |
| `P0-01-brainstorm.md` | `.mc-data/docs/phase0-brainstorm/` | Tổng quan dự án (tên, lĩnh vực, quy mô, pain points, mục tiêu, đội expert phù hợp) |
| Cấu trúc `.mc-data/`  | Root                               | 7 phase directories với templates đã điền thông tin                                        |

##### Chuyển tiếp

→ **Tiếp theo:** `/wf-analyze-requirements` (phân tích yêu cầu dự án)

---

### Track 2: Dự Án Đang Phát Triển — Điểm Vào

Dự án đang phát triển có **nhiều tình huống** với entry points khác nhau. Chọn tình huống phù hợp nhất:

#### Tình huống 2.1: Onboard Lần Đầu — Có Code/Docs, Chưa Có .mc-data/

**Skill:** `/wf-legacy-scan [path] [--resume] [--re-vision]` (all-in-one: detect → classify → extract → synthesize → project-context.md)
**Khi nào dùng:** Dự án đã có codebase hoặc tài liệu sẵn (mọi kích cỡ), cần DEVKIT phân tích và xây dựng `.mc-data/docs/` theo doc-framework. `/wf-legacy-scan` tự động orchestrate toàn bộ pipeline (classify + extract + synthesize) — không cần gọi `/wf-legacy-classify` hay `/wf-legacy-extract` riêng (các sub-skills vẫn có thể chạy standalone nếu cần). Sau khi scan xong, các shared skills tự detect legacy mode (CORE-021: check project-context.md) và inject context.

##### Quy trình

```
Cung cấp đường dẫn dự án có sẵn
         │
         ▼
┌─────────────────────────────────────────┐
│ Pha 1: Scan & Phân Tích (Song song)     │
│                                          │
│ WAVE 0 (2 tasks song song):             │
│ ├─ Task 0a: Root scan                   │
│ │  • Loại project (monorepo/single)     │
│ │  • Config files, README               │
│ │  • Kiểm tra .mc-data/ có sẵn          │
│ └─ Task 0b: File count                  │
│    • Đếm total/source files             │
│                                          │
│ WAVE 1 (4 agents song song):            │
│ ├─ Agent A: Tech Stack & UI             │
│ │  • Languages, frameworks, databases   │
│ │  • Build tools, Docker, env vars      │
│ ├─ Agent B: Modules & Entities          │
│ │  • Domain entities (ORM models)       │
│ │  • Relationships, module structure    │
│ ├─ Agent D: API Endpoints               │
│ │  • Routes, versioning, auth type      │
│ └─ Agent E: Tests & CI/CD               │
│    • Test frameworks, coverage          │
│    • CI/CD pipelines, Docker setup      │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ Pha 2: Tạo .mc-data/docs/ + Gap Analysis│
│ • Tạo tài liệu theo doc-framework      │
│ • Gap analysis — phát hiện thiếu sót   │
│ • Đánh dấu: [Scan] vs [Giả định]       │
└─────────────────────────────────────────┘
```

##### Output

| File                         | Vị trí | Nội dung                                       |
| ---------------------------- | -------- | ----------------------------------------------- |
| Toàn bộ `.mc-data/docs/` | Root     | Tài liệu từ code analysis theo doc-framework |

##### Chuyển tiếp

→ **Tiếp theo:** `/wf-brainstorm`* → `/wf-analyze-requirements`* → `/wf-define-features`* → `/wf-design`* → `/wf-annotate-code` (nếu có annotation gaps) → `/wf-design-ux`* (nếu UI)
> **Lưu ý:** `/wf-legacy-scan` đã tự động chạy classify + extract + synthesize bên trong. Nếu cần chạy riêng từng bước, dùng `/wf-legacy-classify` và `/wf-legacy-extract` standalone.

---

#### Tình huống 2.2: Resume Dự Án DEVKIT — Đã Có .mc-data/, Bị Tạm Dừng

**Skill:** `/status`
**Khi nào dùng:** Dự án đã chạy DEVKIT workflow trước đó nhưng bị tạm dừng (hết session, chuyển việc, v.v.). Cần xác định tiến độ hiện tại và tiếp tục.

##### Quy trình

```
/status
         │
         ▼
┌─────────────────────────────────────────┐
│ 1. Kiểm tra tiến độ hiện tại           │
│    • Đọc req-registry.json             │
│    • Đọc roadmap + sprint status       │
│    • Xác định phase nào đã hoàn thành  │
│    • Xác định phase nào đang dở dang   │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 2. Xác định điểm tiếp tục              │
│                                          │
│ Nếu Phase 1 đã xong, Phase 2 chưa:    │
│ → /wf-define-features                   │
│                                          │
│ Nếu Phase 3 đã xong, chưa code:       │
│ → /wf-plan-modules hoặc                │
│   /wf-implement-feature                 │
│                                          │
│ Nếu đang implement:                     │
│ → /wf-implement-feature [feature tiếp] │
│                                          │
│ Nếu đã implement, chưa verify:         │
│ → /wf-preflight → /wf-verify-sync      │
└──────────┬──────────────────────────────┘
           │
           ▼
  Tiếp tục workflow từ phase phù hợp
```

---

#### Tình huống 2.3: Thêm Tính Năng Mới — Dự Án Đang Chạy

**Skill:** `/feature-addition`
**Khi nào dùng:** Dự án đã có code và `.mc-data/`, cần bổ sung tính năng mới.

##### Quy trình

```
Người dùng: "Thêm tính năng X vào system Y"
         │
         ▼
┌─────────────────────────────────────────┐
│ 1. Đánh giá tác động                    │
│    • Tính năng mới cần gì từ hệ thống │
│      hiện tại?                          │
│    • Ảnh hưởng đến modules nào?        │
│    • Cần thêm REQ-IDs mới?            │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 2. Bổ sung tài liệu (Phase A — scoped) │
│    /wf-analyze-requirements [scope]     │
│    → Chỉ phân tích phần mới            │
│                                          │
│    /wf-define-features [scope]          │
│    → Tạo feature specs cho tính năng   │
│      mới                                │
│                                          │
│    /wf-design [scope]                   │
│    → Cập nhật architecture, API, DB    │
│      cho phần mới                       │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 3. Cập nhật kế hoạch                    │
│    /wf-plan-modules                     │
│    → Cập nhật roadmap + tasks          │
│    → Đánh giá ảnh hưởng đến các       │
│      modules hiện tại                   │
└──────────┬──────────────────────────────┘
           │
           ▼
  Chuyển sang Giai đoạn B
  (/wf-implement-feature)
```

---

#### Tình huống 2.4: Thay Đổi Requirements — Business Điều Chỉnh Yêu Cầu

**Khi nào dùng:** Stakeholder thay đổi yêu cầu nghiệp vụ, cần cập nhật từ requirements xuống code.

##### Quy trình

```
Stakeholder: "Thay đổi quy trình X, bổ sung rule Y"
         │
         ▼
┌─────────────────────────────────────────┐
│ 1. Xác định phạm vi thay đổi           │
│    • REQ-IDs nào bị ảnh hưởng?        │
│    • Modules nào cần cập nhật?        │
│    • Features nào cần thay đổi?       │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 2. Re-analyze (scoped)                  │
│    /wf-analyze-requirements [scope]     │
│    • Cập nhật requirements bị ảnh hưởng│
│    • Cập nhật req-registry.json        │
│    • KHÔNG tạo lại requirements không  │
│      bị ảnh hưởng                      │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 3. Cascade updates                      │
│    /wf-define-features [scope]          │
│    → Cập nhật feature specs            │
│                                          │
│    /wf-design [scope]                   │
│    → Cập nhật technical design          │
│      (API, DB nếu cần)                 │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 4. Re-implement + Regression test       │
│    /wf-implement-feature [features]     │
│    → Implement thay đổi                │
│    → Chạy regression tests             │
│    → Verify sync                        │
└─────────────────────────────────────────┘
```

---

#### Tình huống 2.5: Production Hotfix — Fix Gấp Lỗi Production

**Khi nào dùng:** Phát hiện bug nghiêm trọng trên production, cần fix nhanh nhất có thể.

##### Quy trình

```
Bug report: "Feature X bị lỗi trên production"
         │
         ▼
┌─────────────────────────────────────────┐
│ 1. Triage nhanh                         │
│    • Xác định mức độ: CRITICAL/HIGH    │
│    • Xác định REQ-IDs liên quan       │
│    • Xác định root cause               │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 2. Hotfix (minimal workflow)            │
│    /wf-fix-bugs [mô-tả-lỗi]           │
│    • Viết test reproduce bug           │
│    • Fix code (minimal change)          │
│    • Verify test passes                 │
│    • KHÔNG thay đổi architecture       │
│    • KHÔNG refactor code xung quanh    │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 3. Verify & Deploy                      │
│    • Chạy test suite liên quan          │
│    • Verify sync (scoped)              │
│    • Deploy hotfix                      │
│    • Cập nhật docs nếu behavior đổi   │
└─────────────────────────────────────────┘
```

**Lưu ý:** Hotfix có thể bỏ qua Phase A đầy đủ. Chỉ cần đảm bảo fix đúng, test pass, và docs được cập nhật nếu behavior thay đổi.

---

#### Tình huống 2.6: Refactor / Migration — Nâng Cấp Tech Stack

**Khi nào dùng:** Cần nâng cấp framework, đổi database, refactor architecture, hoặc migration lớn.

##### Quy trình

```
Yêu cầu: "Migrate từ REST → GraphQL" hoặc "Upgrade React 17 → 19"
         │
         ▼
┌─────────────────────────────────────────┐
│ 1. Impact Analysis                      │
│    • Modules nào bị ảnh hưởng?        │
│    • API contracts thay đổi?           │
│    • Database schema thay đổi?        │
│    • Breaking changes?                  │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 2. Cập nhật Architecture Design         │
│    /wf-design [scope]                   │
│    • Cập nhật P3-01-architecture.md    │
│    • Cập nhật API contract (nếu cần)  │
│    • Cập nhật database design (nếu cần)│
│    • Tạo ADR (Architecture Decision    │
│      Record) cho migration              │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 3. Migration Plan                       │
│    /wf-plan-modules                     │
│    • Chia thành migration phases       │
│    • Xác định thứ tự migration        │
│    • Backward compatibility plan       │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 4. Implement Migration                  │
│    /wf-implement-feature [migration]    │
│    • Implement theo phases              │
│    • Regression test sau mỗi phase     │
│    • Verify sync toàn bộ              │
└──────────┬──────────────────────────────┘
           │
           ▼
  /wf-preflight → /wf-verify-sync
```

---

### Các Bước Chung (Shared) — Giai Đoạn A

Sau khi hoàn thành entry point (Track 1 hoặc Track 2), tất cả dự án đều đi qua các bước chung sau:

#### A2. Analyze Requirements — Phân Tích Yêu Cầu Dự Án (DÙNG CHUNG)

**Skill:** `/wf-analyze-requirements [scope] [--status] [--resume]`
**Khi nào dùng:** Sau khi đã có thông tin cơ bản về dự án (từ brainstorm hoặc onboard).
**Bắt buộc:** Đây là bước quan trọng nhất — tạo nền tảng cho toàn bộ thiết kế và triển khai.
**Multi-session:** Hỗ trợ `--resume` để tiếp tục và `--status` để kiểm tra tiến độ.

**Khác biệt theo góc độ:**

| Dự Án Mới | Dự Án Đang Phát Triển |
| --- | --- |
| Phân tích toàn bộ dự án | Phân tích scoped — chỉ phần mới/thay đổi |
| Tạo registry từ đầu | Bổ sung vào registry hiện có |
| Tất cả REQ-IDs đều mới | REQ-IDs mới + cập nhật REQ-IDs cũ |

##### Quy trình (11 phases)

```
Đọc Phase 0 context + Registry (nếu có)
         │
         ▼
┌─────────────────────────────────────┐
│ Phase 1: Context Loading            │
│ • Đọc brainstorm output            │
│   (hoặc onboard output)            │
│ • Xác định lĩnh vực, quy mô       │
│ • Xác định phạm vi phân tích       │
│   (toàn bộ hoặc scoped)            │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ Phase 2: Huy động Domain Experts   │
│ • business-analyst (LUÔN đi đầu)   │
│ • Chọn experts theo lĩnh vực:      │
│   ERP → finance, hr, sales, ops    │
│   CRM → marketing, sales, customer │
│   Healthcare → healthcare, compliance│
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ Phase 3-5: Phân tích nghiệp vụ     │
│ • BA phân tích tổng thể            │
│ • Domain Experts phân tích chuyên   │
│   sâu (song song)                  │
│ • Tổng hợp requirements + REQ-IDs  │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ Phase 6-6d: Tạo tài liệu Phase 1   │
│ • P1-01-project-overview.md        │
│ • P1-02-business-workflow.md       │
│ • departments/[dept]/[dept].md     │
│ • stakeholder-review.md            │
│ • deferred-issues.md               │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ Phase 7-8b: Cập nhật Registry      │
│ • Tạo/cập nhật req-registry.json   │
│ • Thêm systems[], modules[],       │
│   departments[], requirements[]    │
│ • Xác định interface_type          │
└─────────────────────────────────────┘
```

##### Output

| File                           | Vị trí                                              | Nội dung                    |
| ------------------------------ | ----------------------------------------------------- | ---------------------------- |
| `P1-01-project-overview.md`  | `.mc-data/docs/phase1-business/`                    | Tổng quan dự án           |
| `P1-02-business-workflow.md` | `.mc-data/docs/phase1-business/`                    | Quy trình nghiệp vụ       |
| `[dept].md`                  | `.mc-data/docs/phase1-business/departments/[dept]/` | Yêu cầu theo phòng ban    |
| `_index.md`                  | `.mc-data/docs/phase1-business/departments/`        | Index phòng ban             |
| `stakeholder-review.md`      | `.mc-data/docs/phase1-business/`                    | Review nghiệp vụ           |
| `deferred-issues.md`         | `.mc-data/work/wf-analyze-requirements/`            | Vấn đề chưa giải quyết |
| `req-registry.json`          | `.mc-data/docs/_meta/`                              | ★ Registry (SSOT)           |

##### Agents tham gia

- **business-analyst** (luôn đi đầu)
- **Domain experts** theo lĩnh vực (chạy song song)

**Lưu ý:** `/wf-analyze-requirements` chỉ tạo tài liệu nghiệp vụ (Phase 1). Việc chuyển đổi requirements thành feature specs được thực hiện bởi `/wf-define-features` ở bước tiếp theo.

##### Chuyển tiếp

→ **Tiếp theo:** `/wf-define-features` (chuyển đổi requirements thành feature specs)

---

#### A5b. Define Features — Chuyển Đổi Requirements Thành Feature Specs (DÙNG CHUNG)

**Skill:** `/wf-define-features [scope] [--status] [--resume]`
**Khi nào dùng:** Sau khi có requirements đầy đủ (Phase 1), cần chuyển đổi thành feature specifications.
**Bắt buộc:** Phải có requirements từ `/wf-analyze-requirements` trước.

**Khác biệt theo góc độ:**

| Dự Án Mới | Dự Án Đang Phát Triển |
| --- | --- |
| Tạo tất cả feature specs từ đầu | Tạo feature specs mới + giữ nguyên features hiện tại |
| Tất cả FEAT-IDs đều mới | FEAT-IDs mới cho phần bổ sung |

##### Quy trình

```
Đọc req-registry.json + Phase 1 docs
         │
         ▼
┌─────────────────────────────────────┐
│ Bước 1: Đọc & Phân Tích Registry   │
│ • Đọc req-registry.json (SSOT)    │
│ • Liệt kê tất cả REQ-IDs         │
│ • Xác định modules & systems       │
│ • Đọc deferred-issues (nếu có)    │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ Bước 2: Map REQ-IDs → FEAT-IDs    │
│ • Nhóm requirements theo feature   │
│ • Tạo FEAT-ID cho mỗi feature     │
│   Format: FEAT-[SYSTEM]-[MODULE]-  │
│           [NNN]                     │
│ • Xác định quan hệ REQ ↔ FEAT    │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ Bước 3: Tạo Feature Specs          │
│ • User stories                      │
│ • Business rules                    │
│ • Permissions & access control     │
│ • Acceptance criteria              │
│ → Output: phase2-features/          │
│   [sys]/[mod]/[feature].md          │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ Bước 4: Cập Nhật Registry          │
│ • Thêm features[] vào registry     │
│ • Cập nhật REQ-to-FEAT mappings   │
│ • Tạo deferred-findings (nếu có)  │
└─────────────────────────────────────┘
```

##### Output

| File                      | Vị trí                                       | Nội dung                                                   |
| ------------------------- | ---------------------------------------------- | ----------------------------------------------------------- |
| `[feature].md`          | `.mc-data/docs/phase2-features/[sys]/[mod]/` | Feature spec với user stories, business rules, permissions |
| `stakeholder-review.md` | `.mc-data/docs/phase2-features/`             | Review features                                             |
| `deferred-findings.md`  | `.mc-data/work/wf-define-features/`          | Vấn đề cần xử lý sau                                  |
| Updated registry          | `.mc-data/docs/_meta/req-registry.json`      | Features[] được cập nhật                               |

##### Agents tham gia

- **business-analyst** (phân tích feature scope)
- **Domain experts** theo lĩnh vực (validation business rules)

##### Chuyển tiếp

→ **Tiếp theo:** `/wf-design` (thiết kế kiến trúc kỹ thuật)

---

#### A5. Design — Thiết Kế Kiến Trúc Kỹ Thuật (DÙNG CHUNG)

**Skill:** `/wf-design [target] [--status] [--resume]`
**Khi nào dùng:** Sau khi có feature specs đầy đủ (Phase 2), cần chuyển sang thiết kế kỹ thuật.
**Prerequisites:** Phải có features từ `/wf-define-features` trước.

**Khác biệt theo góc độ:**

| Dự Án Mới | Dự Án Đang Phát Triển |
| --- | --- |
| Thiết kế kiến trúc toàn bộ từ đầu | Cập nhật architecture cho phần mới |
| Chọn tech stack | Giữ tech stack hiện tại (trừ migration) |
| Platform/System/Module design mới | Bổ sung design cho modules/features mới |

##### Quy trình

```
Đọc req-registry.json + Phase 2 feature specs
         │
         ▼
┌─────────────────────────────────────────┐
│ Bước 1: Phân Tích & Chọn Approach       │
│                                          │
│ >1 system HOẶC >3 modules               │
│   → Platform Design (Enterprise)        │
│                                          │
│ 1 system, 2-3 modules                   │
│   → System Design (Medium)              │
│                                          │
│ 1 module                                │
│   → Module Design (Small)               │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ Bước 2: Thiết Kế (theo approach)        │
│                                          │
│ Platform Design:                         │
│ ├─ Layer 1: Platform Layer              │
│ │  • Auth & RBAC                        │
│ │  • API Standards (envelope, errors)   │
│ │  • DB Conventions                     │
│ │  • Caching Strategy                   │
│ │  • Event & Messaging                  │
│ │  • Shared Services                    │
│ │  • Cross-Cutting Concerns             │
│ └─ Layer 2: System/Module Designs       │
│                                          │
│ System Design:                           │
│ • System overview, module breakdown     │
│ • API design, database design           │
│ • Business logic, integration points    │
│                                          │
│ Module Design:                           │
│ • Module overview, API endpoints        │
│ • Data model, business logic            │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ Bước 3: Architecture Decision Records   │
│ • Ghi lại quyết định kiến trúc quan    │
│   trọng (DB selection, auth strategy,  │
│   architecture pattern...)              │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ Bước 4: Tạo Files & Stakeholder Review  │
│ • Viết tài liệu thiết kế               │
│ • Cross-reference với REQ-IDs           │
│ • Stakeholder review                    │
│ • Deferred findings (nếu có)           │
└─────────────────────────────────────────┘
```

**Lưu ý:** `/wf-design` chỉ tạo tài liệu kiến trúc kỹ thuật (Phase 3). UX/UI design được tách riêng sang `/wf-design-ux`. Implementation plans được tạo bởi `/wf-plan-modules`.

##### Agents tham gia

| Agent         | Vai trò                   | Khi nào                        |
| ------------- | -------------------------- | ------------------------------- |
| `architect` | Thiết kế platform/system | Complex systems                 |
| `dba`       | Thiết kế database        | Song song với architect        |
| `security`  | Review bảo mật           | Finance, HR, Healthcare modules |

##### Output

| File                      | Vị trí                                               | Nội dung                  |
| ------------------------- | ------------------------------------------------------ | -------------------------- |
| `P3-01-architecture.md` | `.mc-data/docs/phase3-architecture/`                 | Thiết kế kiến trúc     |
| `api-contract.md`       | `.mc-data/docs/phase3-architecture/technical-specs/` | Đặc tả API              |
| `database-design.md`    | `.mc-data/docs/phase3-architecture/technical-specs/` | Thiết kế database        |
| `integration-map.md`    | `.mc-data/docs/phase3-architecture/technical-specs/` | Bản đồ tích hợp       |
| `infra-spec.md`         | `.mc-data/docs/phase3-architecture/technical-specs/` | Đặc tả hạ tầng        |
| `stakeholder-review.md` | `.mc-data/docs/phase3-architecture/`                 | Review stakeholder         |
| `deferred-findings.md`  | `.mc-data/work/wf-design/`                           | Vấn đề cần xử lý sau |

##### Chuyển tiếp

→ **Tiếp theo:** `/wf-design-ux` (nếu dự án có UI — `interface_type != api-only`)
→ **Hoặc:** `/wf-plan-modules` (nếu dự án chỉ có API — `interface_type = api-only`)

---

#### A5c. Design UX — Thiết Kế UX/UI (DÙNG CHUNG, Có Điều Kiện)

**Skill:** `/wf-design-ux [system-name] [--status] [--resume]`
**Khi nào dùng:** Sau khi có thiết kế kiến trúc (Phase 3), khi dự án có giao diện người dùng.
**Điều kiện:** Chỉ chạy khi `interface_type != api-only` trong registry.
**Bỏ qua:** Nếu dự án chỉ có API (không có UI).

**Khác biệt theo góc độ:**

| Dự Án Mới | Dự Án Đang Phát Triển |
| --- | --- |
| Tạo design system từ đầu | Mở rộng design system hiện tại |
| Thiết kế tất cả navigation & screens | Thiết kế screens mới, giữ nguyên screens cũ |

##### Quy trình

```
Đọc Registry + Feature Specs + Architecture Design
         │
         ▼
┌─────────────────────────────────────┐
│ Bước 1: Kiểm Tra interface_type    │
│ • api-only → SKIP (không cần UX)   │
│ • web / mobile / desktop → Tiếp   │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ Bước 2: Design System              │
│ • Thiết kế design-system.md        │
│ • Color palette, typography        │
│ • Component library                │
│ • Spacing, layout rules            │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ Bước 3: Navigation & Screen Groups │
│ • Navigation specs per system      │
│ • Screen groups & user flows       │
│ • Responsive breakpoints           │
│ • Accessibility guidelines         │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│ Bước 4: Cross-Reference & Review   │
│ • Map screens → FEAT-IDs          │
│ • Map components → modules        │
│ • Stakeholder review               │
└─────────────────────────────────────┘
```

##### Agents tham gia

| Agent           | Vai trò                | Khi nào                             |
| --------------- | ----------------------- | ------------------------------------ |
| `ux-designer` | Thiết kế UX/UI system | Luôn luôn (khi skill được gọi) |

##### Output

| File                       | Vị trí                                                 | Nội dung                                      |
| -------------------------- | -------------------------------------------------------- | ---------------------------------------------- |
| `design-system.md`       | `.mc-data/docs/phase4-ux/`                             | Design system (colors, typography, components) |
| `Navigation-[system].md` | `.mc-data/docs/phase4-ux/[system-name]/`               | Navigation specs per system                    |
| `[screen-group].md`      | `.mc-data/docs/phase4-ux/[system-name]/[module-name]/` | Screen groups per module                       |
| `stakeholder-review.md`  | `.mc-data/docs/phase4-ux/`                             | Review UX/UI                                   |

##### Chuyển tiếp

→ **Tiếp theo:** `/wf-plan-modules` (lập kế hoạch triển khai)

---

#### A6. Plan Modules — Lập Kế Hoạch Triển Khai (DÙNG CHUNG)

**Skill:** `/wf-plan-modules`
**Khi nào dùng:** Sau khi có thiết kế kỹ thuật, cần xác định thứ tự triển khai tối ưu.

**Khác biệt theo góc độ:**

| Dự Án Mới | Dự Án Đang Phát Triển |
| --- | --- |
| Lập kế hoạch toàn bộ từ đầu | Cập nhật kế hoạch — thêm tasks mới |
| Tất cả modules đều chưa implement | Một số modules đã implement (giữ nguyên) |
| Topological sort toàn bộ | Re-sort chỉ phần mới, giữ nguyên thứ tự đã hoàn thành |

##### Quy trình

```
Đọc Registry + Technical Design + Feature Specs
         │
         ▼
┌─────────────────────────────────────────┐
│ Bước 1-2: Thu thập & Xác định phụ thuộc │
│ • Liệt kê tất cả modules               │
│ • Xác định data references              │
│ • Xác định API calls giữa modules      │
│ • Xác định entity references            │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ Bước 3: Phát hiện Circular Dependencies │
│ • Nếu có → Cảnh báo + đề xuất giải pháp│
│   (Event-Driven, Shared Entity, etc.)   │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ Bước 4: Topological Sort & Phasing      │
│                                          │
│ Layer 0 — Foundation (không phụ thuộc)  │
│   → Settings, SharedKernel, RBAC        │
│                                          │
│ Layer 1 — Core (phụ thuộc Layer 0)      │
│   → CRM, HR, Catalog                    │
│                                          │
│ Layer 2 — Business (phụ thuộc 0-1)      │
│   → Orders, Payroll                      │
│                                          │
│ Layer 3 — Operations (phụ thuộc 0-2)    │
│   → Logistics, QC                        │
│                                          │
│ Layer 4 — Intelligence (đọc từ tất cả)  │
│   → Reports, BI, Dashboards             │
│                                          │
│ ★ Modules cùng layer → triển khai SONG  │
│   SONG được                              │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ Bước 5-6: Impact Analysis & MVP Scope   │
│ • Phân tích ảnh hưởng khi thay đổi     │
│ • Xác định bộ modules tối thiểu cho    │
│   một business flow hoàn chỉnh          │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ Bước 7: Tạo Output                      │
│ • Implementation roadmap                │
│ • Sprint plans                          │
│ • Implementation task files             │
│ • Stakeholder review                    │
│ • Cập nhật implementation_order vào     │
│   registry                              │
└─────────────────────────────────────────┘
```

##### Output

| File                                | Vị trí                                                   | Nội dung                      |
| ----------------------------------- | ---------------------------------------------------------- | ------------------------------ |
| `P5-00-implementation-roadmap.md` | `.mc-data/docs/phase5-implementation/`                   | Roadmap triển khai tổng thể |
| `S01-sprint-template.md`          | `.mc-data/docs/phase5-implementation/sprints/`           | Sprint plans                   |
| `[feature]-impl.md`               | `.mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/` | Task files cho từng feature   |
| `stakeholder-review.md`           | `.mc-data/docs/phase5-implementation/`                   | Review kế hoạch triển khai  |

##### Chuyển tiếp

→ **Chuyển sang Giai đoạn B:** `/wf-implement-feature` (bắt đầu triển khai code)

---

### Tóm tắt Output Giai đoạn A

Khi hoàn thành Giai đoạn A, `.mc-data/` sẽ chứa:

```
.mc-data/
├── docs/
│   ├── _meta/
│   │   └── req-registry.json        ← PRIMARY SSOT
│   ├── phase0-brainstorm/
│   │   └── P0-01-brainstorm.md       (chỉ dự án mới)
│   ├── phase1-business/
│   │   ├── P1-01-project-overview.md
│   │   ├── P1-02-business-workflow.md
│   │   ├── departments/
│   │   │   ├── _index.md
│   │   │   └── [dept]/[dept].md
│   │   └── stakeholder-review.md
│   ├── phase2-features/
│   │   ├── [sys]/[mod]/[feature].md
│   │   └── stakeholder-review.md
│   ├── phase3-architecture/
│   │   ├── P3-01-architecture.md
│   │   ├── technical-specs/
│   │   │   ├── api-contract.md
│   │   │   ├── database-design.md
│   │   │   ├── integration-map.md
│   │   │   └── infra-spec.md
│   │   └── stakeholder-review.md
│   ├── phase4-ux/                    (nếu có UI)
│   │   ├── design-system.md
│   │   ├── [system-name]/
│   │   │   ├── Navigation-[sys].md
│   │   │   └── [module-name]/[screen-group].md
│   │   └── stakeholder-review.md
│   ├── phase5-implementation/
│   │   ├── P5-00-implementation-roadmap.md
│   │   ├── sprints/
│   │   ├── tasks/[sys]/[mod]/[feature]-impl.md
│   │   └── stakeholder-review.md
│   └── phase6-deployment/            (templates sẵn sàng)
│       ├── deployment-guide.md
│       ├── user-guide.md
│       └── stakeholder-review.md
├── work/                             ← Working data per skill
│   ├── legacy-scan/                 (shared by wf-legacy-scan/classify/extract/normalize/gap/ux)
│   ├── wf-analyze-requirements/
│   ├── wf-define-features/
│   ├── wf-design/
│   ├── wf-design-ux/
│   ├── wf-fix-bugs/
│   ├── wf-implement-feature/
│   ├── wf-preflight/
│   ├── existing-project/
│   └── audit-skill-output/
├── sync/                             ← REQ-ID sync tracking
└── knowledge-base/                   ← Optional ghi chú bổ sung
```

---

## Giai Đoạn B: Triển Khai Lập Trình

### Mô tả

Giai đoạn này thực hiện **triển khai code** dựa trên tài liệu đã xây dựng ở Giai đoạn A. Có thể triển khai từ đầu hoặc tiếp tục phát triển dự án có sẵn. Mỗi kịch bản đều đảm bảo: code hoạt động đúng, test đầy đủ, bảo mật, và đồng bộ với requirements.

### Sơ đồ quy trình Giai đoạn B

```
     ┌──────────────────────────────────────────────────────────────────┐
     │                CÁC KỊCH BẢN TRIỂN KHAI                          │
     ├─────────────────────────────┬────────────────────────────────────┤
     │                             │                                    │
     │  DỰ ÁN MỚI:               │  DỰ ÁN ĐANG PHÁT TRIỂN:          │
     │  B2. Hoàn thiện System ──┐ │  B1. Thêm System mới ──────────┐ │
     │  B3. Hoàn thiện Module ──┤ │  B5. Thêm Module/Feature ──────┤ │
     │  B4. Hoàn thiện Feature ─┤ │  B8. Thay đổi Requirements ────┤ │
     │                          │ │  B9. Production Hotfix ─────────┤ │
     │                          │ │  B10. Refactor/Migration ───────┤ │
     │                          │ │                                 │ │
     ├──────────────────────────┘ └─────────────────────────────────┤ │
     │                                                               │ │
     │  DÙNG CHUNG:                                                  │ │
     │  B6. Preflight + Fix lỗi ───────────────────────────────────┤ │
     │  B7. Security Review ────────────────────────────────────────┘ │
     │                                                                 │
     └───────────────────────────┬─────────────────────────────────────┘
                                 │
                                 ▼
     ┌─────────────────────────────────────────────────────────────────┐
     │              TRIỂN KHAI PIPELINE (DÙNG CHUNG)                   │
     │                                                                 │
     │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐             │
     │  │ DEVELOPER │  │ QA LEAD  │  │ SECURITY REVIEW  │             │
     │  │           │  │          │  │                  │             │
     │  │ TDD Cycle │  │ Unit     │  │ Input validation │             │
     │  │ RED→GREEN │  │ Integr.  │  │ Auth/Authz       │             │
     │  │ →REFACTOR │  │ E2E      │  │ SQL injection    │             │
     │  │           │  │ ≥80% cov │  │ XSS, CSRF        │             │
     │  └─────┬────┘  └────┬─────┘  └────────┬─────────┘             │
     │        └──────────┬──┘                 │                        │
     │                   ▼                    │                        │
     │         ┌────────────────┐             │                        │
     │         │ PREFLIGHT      │◄────────────┘                        │
     │         │ /wf-preflight  │                                      │
     │         │                │                                      │
     │         │ Health check:  │                                      │
     │         │ Registry+Docs  │                                      │
     │         │ +Code+Tests    │                                      │
     │         └───────┬────────┘                                      │
     │                 │                                                │
     │         ┌───────▼────────┐     ┌────────────────┐              │
     │         │ ISSUES FOUND?  │ YES │ FIX BUGS       │              │
     │         │                │────►│ /wf-fix-bugs   │              │
     │         └───────┬────────┘     │ Triage → Fix   │              │
     │             NO  │              │ → Docs sync    │              │
     │                 ▼              └───────┬────────┘              │
     │         ┌────────────────┐             │                        │
     │         │ VERIFY SYNC    │◄────────────┘                        │
     │         │ /wf-verify-sync│                                      │
     │         │                │                                      │
     │         │ Registry ↔     │                                      │
     │         │ Design ↔ Code  │                                      │
     │         │ sync check     │                                      │
     │         └───────┬────────┘                                      │
     │                 │                                                │
     │         ┌───────▼────────┐                                      │
     │         │ ĐẠT CHUẨN?    │                                      │
     │         │ Sync ≥90%      │                                      │
     │         │ Test ≥80%      │                                      │
     │         │ Security: PASS │                                      │
     │         └───┬───────┬───┘                                      │
     │         YES │       │ NO                                        │
     │             ▼       ▼                                           │
     │         ✅ DONE  Fix & Iterate ──► Quay lại                     │
     │                                    DEVELOPER                    │
     └─────────────────────────────────────────────────────────────────┘
```

---

### Kịch Bản Dự Án Mới

#### B2. Triển Khai Hoàn Thiện Một System

**Khi nào:** Triển khai toàn bộ code cho một system (bao gồm tất cả modules và features).

##### Quy trình

```
Kiểm tra: Technical Design + Module Plan đã có?
         │
         ▼
┌─────────────────────────────────────────────┐
│ 1. Xác định phạm vi System                  │
│    • Đọc roadmap → lấy danh sách modules   │
│    • Xác định Layer 0 → 1 → 2 → ...        │
└──────────┬──────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────┐
│ 2. Triển khai theo Layer/Phase               │
│                                              │
│ Phase 1 - Foundation (Layer 0):             │
│ ├── /wf-implement-feature [foundation-module]│
│ ├── Kiểm tra ✅ → Tiếp Phase 2             │
│ └── ❌ → Fix → Kiểm tra lại                │
│                                              │
│ Phase 2 - Core (Layer 1):                   │
│ ├── /wf-implement-feature [core-module-1]  │
│ ├── /wf-implement-feature [core-module-2]  │
│ │   (song song nếu không phụ thuộc nhau)   │
│ ├── Kiểm tra ✅ → Tiếp Phase 3             │
│ └── ❌ → Fix → Kiểm tra lại                │
│                                              │
│ ... (lặp cho từng Phase)                    │
└──────────┬──────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────┐
│ 3. Integration Testing toàn System           │
│    • Test luồng nghiệp vụ end-to-end       │
│    • Test integration giữa các modules      │
│    • Performance testing                     │
└──────────┬──────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────┐
│ 4. Verify Sync toàn System                   │
│    /wf-verify-sync --scope=system --name=[sys]│
│    • Sync Rate ≥90%                         │
│    • Test Coverage ≥80%                     │
│    • Security: PASS                          │
└─────────────────────────────────────────────┘
```

---

#### B3. Triển Khai Hoàn Thiện Một Module

**Khi nào:** Triển khai toàn bộ code cho một module cụ thể trong một system.

##### Quy trình

```
/wf-implement-feature [feature-name | REQ-ID]
         │
         ▼
┌─────────────────────────────────────────┐
│ 1. Chuẩn bị Context                     │
│    • Đọc registry, technical design     │
│    • Đọc task file ([feature]-impl.md) │
│    • Kiểm tra module dependencies       │
│      (dependencies đã implement chưa?)  │
│    • Xác định scope: backend/frontend/  │
│      DB/integrations                     │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 2. Developer Planning                    │
│    • Chia thành 3 phases:               │
│      Foundation → Core Logic →          │
│      Integration                         │
│    • Estimate complexity                 │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 3. TDD Implementation                    │
│    Với MỖI feature trong module:        │
│    ┌────────────────────────┐           │
│    │  RED:   Viết test fail │           │
│    │  GREEN: Code minimal   │           │
│    │  REFACTOR: Cải thiện   │           │
│    └────────────────────────┘           │
│    • Mọi file phải có REQ-ID           │
│    • Follow code standards              │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 4. Code Review + Security Review        │
│    (chạy song song)                      │
│    • QA: Unit tests (≥80% coverage)     │
│    • QA: Integration tests              │
│    • Security: Input validation,        │
│      Auth/Authz, SQL injection, XSS     │
│    → APPROVED / NEEDS FIXES             │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 5. Update Registry & Sync Status        │
│    • Cập nhật impl_status per REQ-ID   │
│    • Cập nhật sync tracking            │
└─────────────────────────────────────────┘
```

##### Quality Gates

| Tiêu chí         | Ngưỡng                          |
| ------------------ | --------------------------------- |
| Design match       | Phải khớp với technical design |
| Unit test coverage | ≥ 80%                            |
| Integration tests  | Critical paths covered            |
| Security review    | PASS hoặc WARNING (không FAIL)  |

---

#### B4. Triển Khai Hoàn Thiện Một Feature

**Khi nào:** Triển khai một tính năng cụ thể trong một module.

##### Quy trình

Quy trình giống B3 nhưng phạm vi nhỏ hơn (1 feature thay vì toàn bộ module).

```
/wf-implement-feature [feature-name | REQ-ID]
```

- Scope: 1 REQ-ID hoặc nhóm REQ-IDs liên quan
- TDD cycle cho feature cụ thể
- Code review + Security review (song song)
- Update impl_status trong registry

---

### Kịch Bản Dự Án Đang Phát Triển

#### B1. Thêm System Mới Vào Dự Án Đang Chạy

**Khi nào:** Người dùng muốn thêm một system hoàn toàn mới vào dự án đang phát triển.

##### Quy trình

```
Người dùng: "Tôi muốn thêm system X vào dự án"
         │
         ▼
┌─────────────────────────────────────────┐
│ 1. Brainstorm về System mới             │
│    • System này giải quyết vấn đề gì?  │
│    • Phạm vi? Modules nào cần?         │
│    • Tích hợp với systems hiện tại     │
│      như thế nào?                       │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 2. Cập nhật Registry & Docs             │
│    • Thêm system vào req-registry.json │
│    • Cập nhật phase1-business/ docs    │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 3. Phân tích Requirements cho System    │
│    /wf-analyze-requirements [system-name]│
│    • BA + Domain experts phân tích     │
│    • Tạo functional requirements       │
│      với REQ-IDs                        │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 4. Define Features + Design             │
│    /wf-define-features → /wf-design     │
│    • Feature specs, API, DB schema     │
│    • Integration points với systems    │
│      hiện tại                           │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 5. Cập nhật Plan Modules                │
│    /wf-plan-modules                     │
│    • Đánh giá ảnh hưởng                │
│    • Cập nhật thứ tự triển khai        │
└──────────┬──────────────────────────────┘
           │
           ▼
  Bắt đầu triển khai code (B2-B4)
```

---

#### B5. Thêm Module / Feature Mới Vào Hệ Thống Có Sẵn

**Khi nào:** Dự án đã có code, cần bổ sung module hoặc tính năng mới (nhưng không thêm system mới).

##### Quy trình

```
Người dùng: "Thêm module/feature X vào system Y"
         │
         ▼
┌─────────────────────────────────────────┐
│ 1. Đánh giá tác động                    │
│    • Module/feature mới cần gì từ      │
│      hệ thống hiện tại?                │
│    • Ảnh hưởng đến modules nào?        │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 2. Cập nhật tài liệu                    │
│    • Bổ sung requirements mới           │
│      (REQ-IDs mới vào registry)        │
│    • Cập nhật feature specs            │
│    • Cập nhật technical design          │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 3. Triển khai code                       │
│    /wf-implement-feature [feature/module]│
│    (Quy trình TDD như B3/B4)            │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 4. Regression Testing                    │
│    • Test tính năng mới                 │
│    • Test lại các tính năng bị ảnh     │
│      hưởng (regression)                 │
│    • Verify sync toàn bộ               │
└─────────────────────────────────────────┘
```

---

#### B8. Thay Đổi Requirements — Cập Nhật Code Theo Business Mới

**Khi nào:** Business thay đổi yêu cầu, cần cập nhật code hiện tại cho phù hợp.

##### Quy trình

```
Stakeholder: "Quy trình X thay đổi, rule Y bị bỏ, thêm rule Z"
         │
         ▼
┌─────────────────────────────────────────┐
│ 1. Xác định REQ-IDs bị ảnh hưởng      │
│    • Đọc registry hiện tại            │
│    • Map requirements → features →     │
│      code files                         │
│    • Tính toán phạm vi ảnh hưởng      │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 2. Cập nhật tài liệu cascade           │
│    • Update req-registry.json          │
│      (sửa/xóa/thêm requirements)      │
│    • Update feature specs              │
│      (phase2-features/ bị ảnh hưởng)  │
│    • Update technical design            │
│      (API, DB nếu cần)                 │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 3. Re-implement                         │
│    /wf-implement-feature [affected]     │
│    • Sửa code theo requirements mới    │
│    • Sửa/thêm tests                    │
│    • Đảm bảo backward compatibility    │
│      (hoặc migration plan nếu breaking)│
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 4. Regression + Verify                  │
│    • Chạy toàn bộ test suite           │
│    • /wf-verify-sync                    │
│    • Đảm bảo không break features khác │
└─────────────────────────────────────────┘
```

---

#### B9. Production Hotfix — Fix Gấp Lỗi Trên Production

**Khi nào:** Bug nghiêm trọng trên production, cần fix nhanh nhất có thể.

##### Quy trình

```
Bug report: "Feature X crash trên production"
         │
         ▼
┌─────────────────────────────────────────┐
│ 1. Triage nhanh (< 15 phút)            │
│    • Xác định severity: CRITICAL/HIGH  │
│    • Xác định root cause               │
│    • Xác định REQ-IDs liên quan       │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 2. Hotfix Implementation                │
│    /wf-fix-bugs [mô-tả-lỗi]           │
│    • Viết test reproduce bug           │
│    • Fix code (MINIMAL change)          │
│    • Verify test passes                 │
│    ★ KHÔNG refactor code xung quanh    │
│    ★ KHÔNG thay đổi architecture       │
│    ★ KHÔNG thêm features               │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 3. Fast Verify & Deploy                 │
│    • Chạy tests liên quan (scoped)     │
│    • Quick security check              │
│    • Deploy hotfix                      │
│    • Cập nhật docs nếu behavior đổi   │
│    • Post-mortem (tùy severity)        │
└─────────────────────────────────────────┘
```

**Lưu ý:** Hotfix có thể bỏ qua Phase A đầy đủ. Sau khi deploy xong, nên chạy `/wf-preflight` đầy đủ để kiểm tra tổng thể.

---

#### B10. Refactor / Migration — Nâng Cấp Kỹ Thuật

**Khi nào:** Cần nâng cấp framework, đổi database, refactor architecture lớn, hoặc migration tech stack.

##### Quy trình

```
Yêu cầu: "Migrate từ MongoDB → PostgreSQL" hoặc "Refactor monolith → microservices"
         │
         ▼
┌─────────────────────────────────────────┐
│ 1. Impact Analysis                      │
│    • Modules nào bị ảnh hưởng?        │
│    • API contracts thay đổi?           │
│    • Database schema thay đổi?        │
│    • Breaking changes?                  │
│    • Downtime estimate?                 │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 2. Cập nhật Architecture Design         │
│    /wf-design [scope]                   │
│    • Cập nhật P3-01-architecture.md    │
│    • Cập nhật API contract (nếu cần)  │
│    • Cập nhật database design (nếu cần)│
│    • Tạo ADR cho migration decision    │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 3. Migration Plan                       │
│    /wf-plan-modules                     │
│    • Chia thành migration phases       │
│    • Xác định thứ tự migration        │
│    • Backward compatibility plan       │
│    • Rollback plan                      │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 4. Implement Migration (từng phase)     │
│    /wf-implement-feature [migration]    │
│    • Implement theo phases              │
│    • Regression test sau mỗi phase     │
│    • Data migration scripts (nếu DB)   │
│    • Feature flags (nếu cần)           │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 5. Full Verify                          │
│    /wf-preflight --scope=all            │
│    /wf-verify-sync                      │
│    • Đảm bảo toàn bộ hệ thống hoạt   │
│      động sau migration                 │
└─────────────────────────────────────────┘
```

---

### Kịch Bản Dùng Chung

Các kịch bản sau áp dụng cho **cả dự án mới và dự án đang phát triển**.

#### B6. Preflight + Fix Lỗi (DÙNG CHUNG)

**Khi nào:** Sau khi implement, cần health check toàn diện và sửa lỗi phát hiện được.

**Skills:** `/wf-preflight` → `/wf-fix-bugs`

##### Quy trình

```
/wf-preflight [--scope=all|system|module|feature] [--name=<id>]
         │
         ▼
┌─────────────────────────────────────────┐
│ 1. PREFLIGHT — Health Check Toàn Diện   │
│    • Validate registry consistency      │
│    • Check docs completeness            │
│    • Scan code for REQ-ID coverage     │
│    • Run tests (nếu --run-tests)       │
│    → Verdict: PASS / WARN / FAIL       │
│    → Output: preflight-report.md       │
└──────────┬──────────────────────────────┘
           │ (nếu WARN/FAIL)
           ▼
/wf-fix-bugs [mô-tả-lỗi] [--scope=...] [--name=...]
         │
         ▼
┌─────────────────────────────────────────┐
│ 2. TRIAGE — Phân loại lỗi               │
│    • Đọc preflight report              │
│    • CRITICAL: Crash, data loss         │
│    • HIGH: Logic sai, security issue    │
│    • MEDIUM: UX kém, edge cases        │
│    • LOW: Cosmetic, minor issues       │
│    → Output: bug-triage.md             │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 3. FIX — Sửa theo thứ tự ưu tiên       │
│    CRITICAL → HIGH → MEDIUM → LOW      │
│    Với mỗi lỗi:                         │
│    • Viết test reproduce bug            │
│    • Fix code                            │
│    • Verify test passes                  │
│    • Docs sync (cập nhật nếu behavior  │
│      thay đổi)                          │
│    • Regression check                    │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 4. Verify toàn bộ                        │
│    • Chạy toàn bộ test suite            │
│    • Security review (nếu security fix) │
│    • Update sync status + registry      │
│    → Output: fix-report-[date].md      │
└─────────────────────────────────────────┘
```

---

#### B7. Security Review & Hardening (DÙNG CHUNG)

**Khi nào:** Trước khi release, hoặc sau khi phát hiện security issue.

##### Quy trình

```
┌─────────────────────────────────────────┐
│ 1. Security Audit                        │
│    Agent: security                       │
│    • Input validation                    │
│    • Authentication / Authorization     │
│    • SQL Injection prevention            │
│    • XSS prevention                      │
│    • CSRF protection                     │
│    • Data encryption                     │
│    • Audit logging                       │
│    • Rate limiting                       │
│    • Error message safety               │
│    • Secret management                   │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 2. Fix Security Issues                   │
│    • CRITICAL → Fix ngay                │
│    • HIGH → Fix trước release           │
│    • MEDIUM → Plan fix                  │
│    • LOW → Backlog                      │
└──────────┬──────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────┐
│ 3. Re-audit                              │
│    • Verify fixes                        │
│    • Sign-off: APPROVED                 │
└─────────────────────────────────────────┘
```

---

### Verify Sync — Kiểm Tra Đồng Bộ (DÙNG CHUNG — Xuyên suốt Giai đoạn B)

**Skill:** `/wf-verify-sync [--scope=all|system|module] [--name=<name>] [--fix]`
**Khi nào dùng:** Sau mỗi đợt triển khai, trước khi release, hoặc khi cần đánh giá tình trạng dự án.

#### Kiểm tra đồng bộ

```
req-registry.json  ◄──────────►  Design Docs  ◄──────────►  Code
     (SSOT)                      (Phase 2-4)              (Implementation)

  REQ-IDs              ↔       feature specs       ↔        src/**/*.ts
  FEAT-IDs             ↔       api-contract        ↔        controllers/
  modules              ↔       database-design     ↔        entities/
```

#### Tiêu chuẩn đạt

| Mức    | Sync Rate | Critical Issues | Test Coverage | UI Compliance |
| ------- | --------- | --------------- | ------------- | ------------- |
| PASS    | 100%      | 0               | 100%          | 100%          |
| WARNING | 70-89%    | 0               | 60-79%        | 70-89%        |
| FAIL    | < 70%     | > 0             | < 60%         | < 70%         |

**Lưu ý:** Verify-sync không downgrade `impl_status` từ "done" → giá trị khác. Nếu code scan không tìm thấy REQ-ID đã done → WARNING, hỏi user.

---

## Giai Đoạn C: Đóng Gói & Chuẩn Bị Triển Khai (Dùng Chung)

### Mô tả

Giai đoạn này chuẩn bị mọi thứ cần thiết để đưa dự án lên môi trường thực tế (production). Bao gồm tài liệu triển khai, cấu hình CI/CD, environment setup, và kiểm tra cuối cùng.

**Áp dụng cho cả dự án mới và dự án đang phát triển** — quy trình hoàn toàn giống nhau.

**Skill:** `/wf-prepare-deployment [--scope=...] [--status]`
**Prerequisites:** `/wf-verify-sync` đạt sync rate >= 80%

### Sơ đồ quy trình Giai đoạn C

```
     ┌──────────────────────────────────────────────────────┐
     │         GIAI ĐOẠN C: CHUẨN BỊ TRIỂN KHAI            │
     ├──────────────────────────────────────────────────────┤
     │                                                      │
     │  C1                C2                C3              │
     │  Tài liệu ──────► CI/CD ──────────► Staging         │
     │  triển khai        Pipeline          Environment     │
     │                                                      │
     │  C4                C5                C6              │
     │  Final ──────────► Go-Live ────────► Post-Launch     │
     │  Checklist         Deployment        Monitoring      │
     │                                                      │
     └──────────────────────────────────────────────────────┘
```

---

### C1. Tài Liệu Triển Khai

**Agents:** `tech-writer` + `devops` + `qa-lead`

#### Output

| File                      | Vị trí                             | Nội dung                                                |
| ------------------------- | ------------------------------------ | -------------------------------------------------------- |
| `deployment-guide.md`   | `.mc-data/docs/phase6-deployment/` | Hướng dẫn triển khai (environment, migration, CI/CD) |
| `user-guide.md`         | `.mc-data/docs/phase6-deployment/` | Hướng dẫn sử dụng cho end users                     |
| `stakeholder-review.md` | `.mc-data/docs/phase6-deployment/` | Review triển khai                                       |

---

### C2. CI/CD Pipeline

**Agent:** `devops`

#### Cấu hình cần thiết

```
┌─────────────────────────────────────────┐
│ CI/CD Pipeline                           │
│                                          │
│ Source ──► Build ──► Test ──► Deploy     │
│                                          │
│ ┌──────────┐                            │
│ │ Build    │ • Compile / Build          │
│ │          │ • Lint checks              │
│ │          │ • Type checks              │
│ └────┬─────┘                            │
│      ▼                                   │
│ ┌──────────┐                            │
│ │ Test     │ • Unit tests               │
│ │          │ • Integration tests        │
│ │          │ • E2E tests                │
│ │          │ • Coverage report          │
│ └────┬─────┘                            │
│      ▼                                   │
│ ┌──────────┐                            │
│ │ Security │ • Dependency scan          │
│ │          │ • Secret scan              │
│ │          │ • SAST analysis            │
│ └────┬─────┘                            │
│      ▼                                   │
│ ┌──────────┐                            │
│ │ Deploy   │ • Staging auto-deploy      │
│ │          │ • Production manual approve│
│ │          │ • Rollback capability      │
│ └──────────┘                            │
└─────────────────────────────────────────┘
```

---

### C3. Staging Environment

```
┌─────────────────────────────────────────┐
│ Staging = Bản sao của Production        │
│                                          │
│ • Cùng cấu hình infrastructure         │
│ • Cùng database schema (data test)     │
│ • Cùng environment variables           │
│ • Cùng third-party integrations        │
│   (sandbox mode)                         │
│                                          │
│ Testing trên Staging:                    │
│ • Smoke tests (luồng chính hoạt động)  │
│ • Performance tests                     │
│ • Security tests                        │
│ • UAT (User Acceptance Testing)         │
└─────────────────────────────────────────┘
```

---

### C4. Final Checklist

Trước khi Go-Live, kiểm tra toàn bộ:

```
PRE-LAUNCH CHECKLIST
═══════════════════════════════════════

Code & Testing
  □ Tất cả tests pass (unit, integration, E2E)
  □ Test coverage ≥ 80%
  □ /wf-verify-sync → PASS (sync rate ≥ 90%)
  □ Không có CRITICAL hoặc HIGH bugs

Security
  □ Security review → APPROVED
  □ SSL/TLS configured
  □ Secrets không hardcoded trong code
  □ Rate limiting enabled
  □ CORS configured properly
  □ Authentication/Authorization working
  □ Input validation on all endpoints
  □ Error messages không leak internal info

Database
  □ Migration scripts tested
  □ Rollback scripts prepared
  □ Backup procedure configured
  □ Connection pooling configured
  □ Indexes optimized

Infrastructure
  □ Load balancer configured
  □ Auto-scaling rules set
  □ Health check endpoints working
  □ Monitoring & alerting configured
  □ Log aggregation set up

Documentation
  □ API documentation complete
  □ Runbook reviewed
  □ Troubleshooting guide ready
  □ Backup/recovery procedures documented

Team
  □ On-call rotation scheduled
  □ Escalation paths defined
  □ Rollback plan reviewed by team
  □ Go/No-Go meeting completed
```

---

### C5. Go-Live Deployment

```
┌─────────────────────────────────────────┐
│ DEPLOYMENT STRATEGY                      │
│                                          │
│ Option A: Blue-Green Deployment         │
│ • Hai môi trường production             │
│ • Switch traffic ngay lập tức           │
│ • Rollback: switch lại                  │
│                                          │
│ Option B: Canary Deployment             │
│ • Deploy cho % nhỏ users trước         │
│ • Monitor metrics                       │
│ • Tăng dần nếu OK                      │
│                                          │
│ Option C: Rolling Deployment            │
│ • Update từng server/container          │
│ • Zero-downtime                         │
│                                          │
│ ROLLBACK PLAN:                           │
│ • Trigger: error rate > X%              │
│ • Action: revert to previous version    │
│ • Time: < 5 minutes                     │
└─────────────────────────────────────────┘
```

---

### C6. Post-Launch Monitoring

```
┌─────────────────────────────────────────┐
│ POST-LAUNCH (24-72 giờ đầu)            │
│                                          │
│ Monitor:                                 │
│ • Error rate                            │
│ • Response time (P50, P95, P99)         │
│ • CPU / Memory usage                    │
│ • Database connections                  │
│ • User feedback                         │
│                                          │
│ Actions if issues:                       │
│ • Hotfix → Deploy → Verify              │
│ • Rollback nếu critical                 │
│ • Communicate với stakeholders          │
└─────────────────────────────────────────┘
```

---

## Phụ Lục

### Bảng Tổng Hợp Skills & Giai Đoạn

| Skill                          | Giai đoạn | Phase | Input                    | Output                                           | Agents chính                | Dùng chung? |
| ------------------------------ | ----------- | ----- | ------------------------ | ------------------------------------------------ | ---------------------------- | ------------ |
| `/wf-brainstorm`             | A (Track 1/2) | 0   | Ý tưởng / extracted data  | `P0-01-brainstorm.md` — tự detect legacy mode | Orchestrator                 | ✅* |
| `/wf-legacy-scan`           | A (Track 2) | 0-3  | Codebase có sẵn (mọi kích cỡ) | All-in-one: detect → classify → extract → synthesize → project-context.md | Explore + BA + Domain Experts | ❌ Chỉ ĐPT |
| `/wf-legacy-classify`       | A (Track 2) | 2    | Ledger + source files  | Classified files per system/module (standalone hoặc internal stage của wf-legacy-scan) | Code Reviewer  | ❌ Chỉ ĐPT |
| `/wf-legacy-extract`        | A (Track 2) | 3    | Classified files       | Extracted requirements & features (standalone hoặc internal stage của wf-legacy-scan) | BA + Domain Experts | ❌ Chỉ ĐPT |
| `/wf-annotate-code`         | A (Track 2) | 3.5  | Registry + design (legacy) | Inject REQ-ID vào code (nếu có annotation gaps) | —                        | ❌ Chỉ ĐPT |
| `/wf-add-scope`             | A (Track 2) | —    | Registry + legacy mapping | Thêm modules + features vào registry (append-only) | —                     | ✅           |
| `/wf-manage-change`         | B (Shared)  | —    | User prompt + Registry + Docs + Code | Phân tích impact → thực hiện thay đổi docs + code → verify | BA + Domain + Dev | ✅           |
| `/wf-analyze-requirements`   | A (Shared)  | 1     | Phase 0 context          | Business docs (`phase1-business/`) + Registry  | BA + Domain Experts          | ✅           |
| `/wf-define-features`        | A (Shared)  | 2     | Registry + Phase 1       | Feature specs (`phase2-features/`)             | BA + Domain Experts          | ✅           |
| `/wf-design`                 | A (Shared)  | 3     | Features + Registry      | Architecture, API, DB (`phase3-architecture/`) | Architect, DBA, Security     | ✅           |
| `/wf-design-ux`              | A (Shared)  | 4     | Architecture + Features  | UX/UI design (`phase4-ux/`) — chỉ khi có UI | UX Designer                  | ✅           |
| `/wf-plan-modules`           | A (Shared)  | 5     | Design + Registry        | Roadmap + tasks (`phase5-implementation/`)     | Orchestrator                 | ✅           |
| `/wf-implement-feature`      | B (Shared)  | 5     | Task files + Design      | Working code + Tests                             | Developer, QA, Security      | ✅           |
| `/wf-preflight`              | B (Shared)  | —    | Registry + Docs + Code   | Health check report (PASS/WARN/FAIL)             | QA Lead, Code Reviewer       | ✅           |
| `/wf-fix-bugs`               | B (Shared)  | —    | Preflight report + Code  | Fix report, updated docs/code                    | Developer, QA, Security      | ✅           |
| `/wf-verify-sync`            | B (Shared)  | —    | Registry + Design + Code | Sync report                                      | Orchestrator                 | ✅           |
| `/wf-prepare-deployment`     | C (Shared)  | 6     | Code + Design            | Deployment docs (`phase6-deployment/`)         | DevOps, Tech Writer, QA Lead | ✅           |
| `/status`                    | Hỗ trợ    | —    | Registry + Roadmap       | Dashboard tiến độ                             | —                           | ✅           |
| `/ui-ux-pro-max`             | Hỗ trợ    | —    | UI requirements          | Advanced UI/UX design                            | —                           | ✅           |
| `/wf-scan-target`            | Standalone  | —    | `--target=<path\|url>` (+ optional `--module`, `--compare`, `--profile`, `--since`) | `module-map.md`, `target-map.json` (v2), `feature-inventory.md`, `phase-summary.md`, `gap-report.md` (khi `--compare`) | Developer + BA  | ✅           |
| `/audit-agents`              | Meta        | —    | DEVKIT agent definitions | Agent compliance report                          | Review team                  | ✅           |
| `/audit-devkit`              | Meta        | —    | DEVKIT codebase          | Full DEVKIT audit report (orchestrates scan → verify → fix) | Review team (6 agents) | ✅           |
| `/audit-devkit-scan`         | Meta        | —    | DEVKIT components        | Ground truth index, issue detection (batches ≤20 files) | Review team            | ✅           |
| `/audit-devkit-verify`       | Meta        | —    | Scan output (JSON)       | Cross-reference validation, workflow integrity check | Review team              | ✅           |
| `/audit-devkit-fix`          | Meta        | —    | Verify output            | Auto-fix với per-fix verification (Read → Edit → Verify) | Review team              | ✅           |
| `/audit-skill-output`        | Meta        | —    | Skill output + SKILL.md  | Quality audit report (7 dimensions), auto-fix    | Review team                  | ✅           |
| `/wf-legacy-*` (pipeline)    | A (Track 2) | 0-3  | Codebase có sẵn (mọi kích cỡ) | All-in-one pipeline (wf-legacy-scan orchestrates classify + extract + synthesize) | BA + Domain + Arch + QA | ❌ Chỉ ĐPT |
| `/new-project`               | Orchestrator| —    | Ý tưởng người dùng | Full workflow: idea → deployment               | Orchestrator                 | ❌ Chỉ mới |
| `/feature-addition`          | Orchestrator| —    | Existing project + idea  | Add features (Phase 3+)                          | Orchestrator                 | ❌ Chỉ ĐPT |
| `/existing-project`          | Orchestrator| —    | Existing codebase        | Onboard + full workflow                          | Orchestrator                 | ❌ Chỉ ĐPT |

### Bảng Tổng Hợp Kịch Bản Sử Dụng

#### Dự Án Mới

| Kịch bản                       | Quy trình                                                                                                                                                                          |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ý tưởng mơ hồ, cần brainstorm | `/wf-brainstorm` → `/wf-analyze-requirements` → `/wf-define-features` → `/wf-design` → `/wf-design-ux` (nếu UI) → `/wf-plan-modules` → implement |
| Yêu cầu đã rõ ràng            | `/wf-brainstorm` → `/wf-analyze-requirements` → `/wf-define-features` → `/wf-design` → `/wf-design-ux` (nếu UI) → `/wf-plan-modules` → implement |
| API-only (không có UI)           | `/wf-brainstorm` → `/wf-analyze-requirements` → `/wf-define-features` → `/wf-design` → `/wf-plan-modules` → implement (bỏ /wf-design-ux)          |
| Hoàn thiện system                | `/wf-implement-feature` × N (theo layer order) → `/wf-preflight` → `/wf-fix-bugs` → `/wf-verify-sync`                                              |
| Hoàn thiện module                | `/wf-implement-feature [feature]` → Code Review + Security → `/wf-preflight` → `/wf-verify-sync`                                                    |
| Hoàn thiện feature               | `/wf-implement-feature [feature]` → Code Review + Security → Sync update                                                                            |

#### Dự Án Đang Phát Triển

| Kịch bản                        | Entry Point | Quy trình                                                                                                     |
| --------------------------------- | ----------- | --------------------------------------------------------------------------------------------------------------- |
| Onboard lần đầu (mọi kích cỡ) | `/wf-legacy-scan` | `/wf-legacy-scan` (all-in-one: detect → classify → extract → synthesize) → `/wf-brainstorm`* → `/wf-analyze-requirements`* → `/wf-define-features`* → `/wf-design`* → `/wf-annotate-code` (nếu có annotation gaps) → `/wf-design-ux`* (nếu UI) → `/wf-plan-modules` → tiếp tục |
| Resume dự án DEVKIT (đã có .mc-data/) | `/status` | Kiểm tra tiến độ → xác định phase dở → tiếp tục từ phase đó                                  |
| Thêm tính năng mới               | `/feature-addition` | `/wf-analyze-requirements [scope]` → `/wf-define-features` → `/wf-design` → implement → verify   |
| Thêm system mới                  | B1          | Brainstorm system → Update registry → `/wf-analyze-requirements` → design → implement                         |
| Thêm module/feature nhỏ         | B5          | Impact analysis → Update docs + registry → `/wf-implement-feature` → Regression test → verify                 |
| Thay đổi/sửa tính năng            | `/wf-manage-change` | Phân tích yêu cầu → Impact assessment → Cập nhật docs + code → Verify |
| Thay đổi requirements            | B8          | Xác định scope → Update registry + docs cascade → Re-implement → Regression test → verify                     |
| Production hotfix                 | B9          | Triage → `/wf-fix-bugs` (minimal) → Test → Deploy                                                              |
| Refactor / Migration              | B10         | Impact analysis → `/wf-design` (update) → `/wf-plan-modules` → Implement → Full verify                       |
| Security audit                    | B7          | Security agent → Fix → Re-audit → APPROVED                                                                     |
| Quét 1 module/hệ thống/URL trước khi tạo mới | `/wf-scan-target` | `/wf-scan-target --target=<path\|url> [--module] [--compare]` → consume optional bởi `/wf-add-scope`, `/wf-define-features`, `/wf-design` qua `--from-scan` |

#### Dùng Chung

| Kịch bản                       | Quy trình                                                                                  |
| -------------------------------- | ------------------------------------------------------------------------------------------- |
| Preflight + Fix lỗi            | `/wf-preflight` → Triage → `/wf-fix-bugs` → Verify                                        |
| Security review                  | Security agent → Fix → Re-audit → APPROVED                                                 |
| Verify sync                      | `/wf-verify-sync [--scope] [--fix]` → Sync report                                          |
| Chuẩn bị triển khai           | `/wf-prepare-deployment` → CI/CD → Staging → Checklist → Go-Live → Monitor                |

### REQ-ID Convention

```
Format đơn giản: REQ-[DEPT]-[NNN]
Format phức tạp: REQ-[SYSTEM]-[MODULE]-[NNN]

Ví dụ:
  REQ-SALES-001        → Sales department
  REQ-FIN-001           → Finance department
  REQ-CRM-CUST-001     → Customer module trong CRM system
```

### Hooks Tự Động

| Hook                             | Loại                    | Tác dụng                                   |
| -------------------------------- | ------------------------ | -------------------------------------------- |
| `validate-requirement-sync.sh` | PreToolUse (Write/Edit)  | Kiểm tra code có REQ-ID reference          |
| `pre-bash-safety.sh`           | PreToolUse (Bash)        | Chặn lệnh nguy hiểm                       |
| `privacy-block.sh`             | PreToolUse               | Chặn rò rỉ thông tin nhạy cảm             |
| `scout-block.sh`               | PreToolUse               | Chặn truy cập tài nguyên không được phép   |
| `session-init.sh`              | Session Init             | Khởi tạo phiên làm việc                    |
| `update-sync-status.sh`        | PostToolUse (Write/Edit) | Cập nhật sync status tự động            |
| `validate-contract-sync.sh`    | PostToolUse (Write/Edit) | Validates against req-registry.json          |
| `validate-ui-component.sh`     | PostToolUse (Write/Edit) | UI quality checks                            |
| `validate-naming-convention.sh`| PostToolUse (Write/Edit) | Validates lowercase-kebab-case naming trong legacy pipeline output (CORE-016/017) |
| `validate-critical-decision.sh`| PreToolUse               | Kiểm tra Critical Decision Gate — yêu cầu user confirmation trước hành động không thể undo (CORE-027) |
| `stop-session-verify.sh`       | Stop                     | Kiểm tra sync status khi kết thúc session |

### Registry Safe-Write Protocol

Mỗi skill chỉ update ĐÚNG fields được phân công trong `req-registry.json`:

| Skill                          | Fields được phép update                                                             |
| ------------------------------ | --------------------------------------------------------------------------------------- |
| `/wf-brainstorm`             | `project`, `departments[]`, `interface_type` (initial seed — ghi 1 lần ở Phase 5.3) |
| `/wf-analyze-requirements`   | `systems[]`, `modules[]`, `departments[]`, `requirements[]`, `interface_type` |
| `/wf-define-features`        | `features[]`                                                                          |
| `/wf-design`                 | `design_status`                                                                       |
| `/wf-design-ux`              | `ux_design_status`                                                                    |
| `/wf-plan-modules`           | `implementation_order`                                                                |
| `/wf-implement-feature`      | `impl_status` (per REQ-ID)                                                            |
| `/wf-verify-sync`            | `impl_status` (per REQ-ID, safe-update only)                                          |
| `/wf-fix-bugs`               | **KHÔNG update registry** (pure orchestrator — delegate cho sub-skills)              |
| 11 dimension lanes (wf-fix-functional/business/security/performance/ux-a11y/data/compat/observability/runtime-health/integration/business-completeness) *(spawned)* | **KHÔNG update registry** (probe-only — emit signals về `lanes/QD*/signals.json`) |
| `/wf-fix-triage` *(spawned)* | **KHÔNG update registry** (triage only — không sửa code)                             |
| `/wf-fix-execute` *(spawned)* | `impl_status` (per REQ-ID, safe-update only — Phase 4a only)                        |
| `/wf-design` (legacy flow)   | `design_status` + `systems[]`, `modules[]`, `departments[]`, `requirements[]`, `features[]`, `interface_type` + `requirements[].impl_status` (**chỉ fix invalid values** → `not_started`. Xem CORE-010) |
| `/wf-annotate-code`          | Code files only (REQ-ID/FEAT-ID comments). **KHÔNG update registry** |
| `/wf-add-scope`              | `modules[]`, `features[]` (**APPEND-ONLY** — chỉ thêm entries mới, không modify/delete/rename existing) |

### Cross-Skill Output Path Contract

| Producer Skill                | Output Path                                                              | Consumer Skill                      |
| ----------------------------- | ------------------------------------------------------------------------ | ----------------------------------- |
| `/wf-analyze-requirements`  | `.mc-data/docs/phase1-business/stakeholder-review.md`                  | `/wf-define-features` (context)   |
| `/wf-analyze-requirements`  | `.mc-data/work/wf-analyze-requirements/deferred-issues.md`             | `/wf-define-features` (input)     |
| `/wf-define-features`       | `.mc-data/docs/phase2-features/[sys]/[mod]/[feat].md`                  | `/wf-design`                      |
| `/wf-define-features`       | `.mc-data/work/wf-define-features/deferred-findings.md`                | `/wf-design` (optional)           |
| `/wf-define-features`       | `req-registry.json` (features[])                                       | `/wf-design`                      |
| `/wf-design`                | `.mc-data/docs/phase3-architecture/stakeholder-review.md`              | `/wf-design-ux`                   |
| `/wf-design`                | `.mc-data/work/wf-design/deferred-findings.md`                         | `/wf-plan-modules` (blocking)     |
| `/wf-design-ux`             | `.mc-data/docs/phase4-ux/stakeholder-review.md`                        | `/wf-plan-modules`                |
| `/wf-plan-modules`          | `.mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md`  | `/wf-implement-feature`           |
| `/wf-plan-modules`          | `.mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md` | `/wf-implement-feature`           |
| `/wf-plan-modules`          | `.mc-data/docs/phase5-implementation/stakeholder-review.md`            | `/wf-implement-feature`           |
| `/wf-implement-feature`     | `req-registry.json` (impl_status)                                      | `/wf-preflight` (input)             |
| `/wf-preflight`             | `.mc-data/work/wf-preflight/preflight-report.md`                       | `/wf-fix-bugs` (input)              |
| `/wf-fix-bugs` Phase 1      | `$SESSION_DIR/fix-status.json`, `issue-registry.json`, `lanes/QD*/signals.json` (11 lanes) | `/wf-fix-triage`         |
| `/wf-fix-triage` *(spawned)* | `$SESSION_DIR/bug-triage.md`, `fix-plan.md`, `fix-log.json` (init)    | `/wf-fix-execute`                  |
| `/wf-fix-execute` *(spawned)* | `.mc-data/docs/phase2-features/[sys]/[mod]/[feat].md` (cập nhật nếu behavior đổi) | `/wf-verify-sync` (context) |
| `/wf-fix-execute` *(spawned)* | `$SESSION_DIR/fix-report.md`, `phase-summary.md`, `.mc-data/work/wf-fix-bugs/fix-history.md` | `/wf-verify-sync` (optional context) |
| `/wf-manage-change`         | `.mc-data/work/wf-manage-change/change-report-[date].md`             | `/wf-verify-sync` (optional context)|
| `/wf-manage-change`         | Updated docs + code + registry                                        | `/wf-preflight`, `/wf-verify-sync` |
| `/wf-verify-sync`           | `.mc-data/docs/_meta/verify-sync.md`                                   | `/wf-prepare-deployment` (inform)   |
| `/wf-verify-sync`           | `req-registry.json` (impl_status safe-update)                          | Release/Go-Live                     |
| `/wf-prepare-deployment`    | `.mc-data/docs/phase6-deployment/stakeholder-review.md`                | Release/Go-Live                     |
| `/wf-legacy-scan`           | `ledger.json`, `project-profile.json`, `source-files.json`             | `/wf-legacy-classify`               |
| `/wf-legacy-scan`           | `.mc-data/work/legacy-scan/inventory/external-docs.json`               | `/wf-legacy-extract`, `/wf-brainstorm` (legacy flow) |
| `/wf-legacy-scan` Stage 4   | `.mc-data/work/legacy-scan/project-context.md`                         | Tất cả shared skills (brainstorm, analyze-req, define-features, design) + plan-modules + implement-feature |
| `/wf-legacy-scan` Stage 4   | `.mc-data/work/legacy-scan/doc-quality-map.json`                       | `/wf-brainstorm` Phase 0.5, `/wf-analyze-requirements` (context injection) |
| `/wf-legacy-scan` Stage 4   | `.mc-data/work/legacy-scan/impl-status-snapshot.json`                  | `/wf-define-features` Phase 0.5 (seed impl_status, 1 lần duy nhất) |
| `/wf-legacy-classify`       | `classified/*.json`, `glossary.json`                                   | `/wf-legacy-extract`                |
| `/wf-legacy-extract`        | `extracted/*.json`, `dedup-report.json`                                | `/wf-brainstorm` (legacy flow)      |
| `/wf-legacy-extract` Stage 3.5 | `.mc-data/work/legacy-scan/module-code-mapping.json`                | `/wf-analyze-requirements` (legacy), `/wf-annotate-code`, `/wf-design` (legacy — gap analysis) |
| `/wf-brainstorm` (legacy flow) | `.mc-data/docs/phase0-brainstorm/` (P0-01, P0-02, policies/)       | `/wf-analyze-requirements`, `/wf-design-ux`, `/wf-plan-modules` |
| `/wf-analyze-requirements` (legacy flow) | `.mc-data/docs/phase1-business/`                           | `/wf-design-ux` context             |
| `/wf-define-features` (legacy flow) | `.mc-data/docs/phase2-features/**`                              | `/wf-plan-modules`                  |
| `/wf-design` (legacy flow)  | `.mc-data/docs/phase3-architecture/**` + `req-registry.json`           | `/wf-design-ux`, `/wf-plan-modules`, All downstream skills |
| `/wf-design` (legacy flow — gap analysis) | `.mc-data/work/legacy-scan/gap-report.md`                  | `/wf-plan-modules` (priority input), `/wf-annotate-code` (annotation gaps) |
| `/wf-design` (legacy flow — gap analysis) | `.mc-data/work/legacy-scan/action-items.json`               | `/wf-plan-modules` Phase 0 (machine-readable input) |
| `/wf-annotate-code`         | Annotated code files, `annotation-report.md`, `annotation-map.json`    | `/wf-design-ux`*, `/wf-plan-modules` |
| `/wf-design-ux` (legacy flow) | `.mc-data/docs/phase4-ux/existing-ui-analysis.md`                    | `/wf-plan-modules`                  |
| `/wf-design-ux` (legacy flow) | `.mc-data/work/legacy-scan/ux-checkpoint.json`                       | `/wf-design-ux` (resume — legacy flow) |

---

> **Ghi chú:** Tài liệu này mô tả workflow ở mức tổng quan. Chi tiết từng workflow skill nằm trong `.claude/skills/workflow/[skill-name]/SKILL.md`. Chi tiết từng agent nằm trong `.claude/agents/`.
