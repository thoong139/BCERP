# DEVKIT Skills Reference — Hướng Dẫn Sử Dụng Chi Tiết

> Tài liệu mô tả chi tiết tất cả skills trong DEVKIT — cách hoạt động, cách sử dụng, trường hợp áp dụng và lưu ý quan trọng.

**Phiên bản:** 2026-05-12 (wf-fix-bugs v9.1.0 — QD11 Business Completeness & Enhancement)
**Tổng số skills:** 32 wf-* + 3 orchestrator + 8 utility = 43 lệnh (11 dimension lanes QD1–QD11)

---

## Mục Lục

- [1. Tổng Quan](#1-tổng-quan)
- [2. Workflow Skills — Dự Án Mới (Standard Path)](#2-workflow-skills--dự-án-mới-standard-path)
  - [2.1. /wf-brainstorm — Brainstorm ý tưởng](#21-wf-brainstorm--brainstorm-ý-tưởng)
  - [2.2. /wf-analyze-requirements — Phân tích yêu cầu](#22-wf-analyze-requirements--phân-tích-yêu-cầu)
  - [2.3. /wf-define-features — Định nghĩa tính năng](#23-wf-define-features--định-nghĩa-tính-năng)
  - [2.4. /wf-design — Thiết kế kiến trúc](#24-wf-design--thiết-kế-kiến-trúc)
  - [2.5. /wf-design-ux — Thiết kế UX/UI](#25-wf-design-ux--thiết-kế-uxui)
  - [2.6. /wf-plan-modules — Lập kế hoạch triển khai](#26-wf-plan-modules--lập-kế-hoạch-triển-khai)
  - [2.7. /wf-implement-feature — Viết code](#27-wf-implement-feature--viết-code)
  - [2.8. /wf-preflight — Kiểm tra sức khỏe dự án](#28-wf-preflight--kiểm-tra-sức-khỏe-dự-án)
  - [2.9. /wf-fix-bugs — Tìm và sửa lỗi](#29-wf-fix-bugs--tìm-và-sửa-lỗi)
    - [2.9.1. /wf-fix-triage — Triage engine](#291-wf-fix-triage--triage-engine-spawned)
    - [2.9.2. /wf-fix-execute — Fix + Report engine](#292-wf-fix-execute--fix--verify--report-engine-spawned)
    - [2.9.3. /wf-fix-runtime-health — Lane QD9: Runtime Health](#293-wf-fix-runtime-health--lane-qd9-runtime-health-spawned)
    - [2.9.4. /wf-fix-integration — Lane QD10: Cross-Module](#294-wf-fix-integration--lane-qd10-cross-module-integration-spawned)
  - [2.10. /wf-verify-sync — Kiểm tra truy xuất nguồn gốc](#210-wf-verify-sync--kiểm-tra-truy-xuất-nguồn-gốc)
  - [2.11. /wf-prepare-deployment — Chuẩn bị triển khai](#211-wf-prepare-deployment--chuẩn-bị-triển-khai)
- [3. Legacy Skills — Dự Án Có Sẵn (Existing Path)](#3-legacy-skills--dự-án-có-sẵn-existing-path)
  - [3.1. /wf-legacy-scan — Quét và đánh giá dự án](#31-wf-legacy-scan--quét-và-đánh-giá-dự-án)
  - [3.2. /wf-legacy-classify — Phân loại files](#32-wf-legacy-classify--phân-loại-files)
  - [3.3. /wf-legacy-extract — Trích xuất yêu cầu](#33-wf-legacy-extract--trích-xuất-yêu-cầu)
  - [3.4. /wf-annotate-code — Inject REQ-ID vào code](#34-wf-annotate-code--inject-req-id-vào-code)
  - [3.5. /wf-add-scope — Thêm modules vào registry](#35-wf-add-scope--them-modules-vao-registry)
  - [3.6. /wf-manage-change — Xử lý thay đổi tính năng](#36-wf-manage-change--xu-ly-thay-doi-tinh-nang)
- [4. Orchestrator Skills — Điều Phối Tự Động](#4-orchestrator-skills--điều-phối-tự-động)
  - [4.1. /new-project — Dự án mới từ đầu](#41-new-project--dự-án-mới-từ-đầu)
  - [4.2. /existing-project — Dự án có sẵn](#42-existing-project--dự-án-có-sẵn)
  - [4.3. /feature-addition — Thêm tính năng](#43-feature-addition--thêm-tính-năng)
- [5. Utility Skills — Công Cụ Hỗ Trợ](#5-utility-skills--công-cụ-hỗ-trợ)
  - [5.1. /status — Xem tiến độ dự án](#51-status--xem-tiến-độ-dự-án)
  - [5.2. /ui-ux-pro-max — Thiết kế UI/UX nâng cao](#52-ui-ux-pro-max--thiết-kế-uiux-nâng-cao)
  - [5.3. /wf-scan-target — Quét target standalone](#53-wf-scan-target--quét-target-standalone)
  - [5.4. /audit-agents — Kiểm tra agents](#54-audit-agents--kiểm-tra-agents)
  - [5.5. /audit-devkit — MCV3 self-audit orchestrator](#55-audit-devkit--mcv3-self-audit-orchestrator)
  - [5.6. /audit-devkit-scan — Scan DEVKIT components](#56-audit-devkit-scan--scan-devkit-components)
  - [5.7. /audit-devkit-verify — Cross-validate DEVKIT](#57-audit-devkit-verify--cross-validate-devkit)
  - [5.8. /audit-devkit-fix — Auto-fix DEVKIT issues](#58-audit-devkit-fix--auto-fix-devkit-issues)
  - [5.9. /audit-skill-output — Kiểm tra chất lượng output](#59-audit-skill-output--kiểm-tra-chất-lượng-output)
  - [5.10. /wf-diagram — Sinh sơ đồ thiết kế UML + ERD](#510-wf-diagram--sinh-sơ-đồ-thiết-kế-uml--erd)
- [6. Bảng Tra Cứu Nhanh](#6-bảng-tra-cứu-nhanh)
- [7. Thuật Ngữ](#7-thuật-ngữ)

---

## 1. Tổng Quan

### DEVKIT là gì?

DEVKIT là bộ công cụ phát triển phần mềm chạy trên Claude Code. Nó hoạt động như một **đội ngũ chuyên gia ảo** gồm 62 AI agents — phân tích nhu cầu, tư vấn, xây dựng tài liệu, thiết kế kiến trúc, và triển khai code.

### Skills là gì?

Skills là các **lệnh người dùng** (invoked bằng `/command`) — mỗi skill đảm nhận một bước trong quy trình phát triển. Khi chạy, skill sẽ:
1. Kiểm tra điều kiện tiên quyết (PRE-GATE)
2. Thực thi các bước tuần tự hoặc song song
3. Huy động AI agents chuyên biệt khi cần
4. Kiểm tra chất lượng đầu ra (POST-GATE)
5. Tạo tài liệu và cập nhật registry

### Hai luồng công việc chính

```
DỰ ÁN MỚI (Standard Path):
  Ý tưởng → /wf-brainstorm → /wf-analyze-requirements → /wf-define-features →
  /wf-design → /wf-design-ux (nếu có UI) → /wf-plan-modules →
  /wf-implement-feature → /wf-preflight → /wf-verify-sync → /wf-prepare-deployment
                                                                    ↑
                                                    /wf-fix-bugs (bất kỳ lúc nào)

DỰ ÁN CÓ SẴN (Existing Path):
  /wf-legacy-scan (all-in-one: detect → classify → extract → synthesize) →
  /wf-brainstorm* → /wf-analyze-requirements* → /wf-define-features* → /wf-design* →
  /wf-annotate-code (nếu có annotation gaps) →
  /wf-design-ux* (nếu có UI) → /wf-plan-modules → /wf-implement-feature → ...

  * = shared skills tự detect legacy mode và inject context
```

### Quy tắc quan trọng

- **Không skip phases** — mỗi phase phụ thuộc output của phase trước
- **Registry là nguồn chân lý duy nhất** — file `req-registry.json` quản lý tất cả REQ-IDs
- **Mỗi skill chỉ update fields được phân công** — không ghi đè dữ liệu của skill khác

---

## 2. Workflow Skills — Dự Án Mới (Standard Path)

### 2.1. /wf-brainstorm — Brainstorm ý tưởng

**Phiên bản:** v8.0.0 | **Phase:** 0 | **Thời lượng:** 1 session

#### Mô tả

Điểm khởi đầu của mọi dự án mới. Skill này giúp người dùng làm rõ ý tưởng kinh doanh, xác định phạm vi dự án, và tạo tài liệu Phase 0 — nền tảng cho toàn bộ quy trình phát triển.

#### Cách sử dụng

```bash
/wf-brainstorm
```

Không cần tham số. Skill sẽ bắt đầu cuộc trò chuyện tư vấn, hỏi từng câu hỏi một (không hỏi nhiều câu cùng lúc).

#### Khi nào sử dụng

- Bắt đầu dự án phần mềm mới từ ý tưởng
- Muốn làm rõ mục tiêu kinh doanh trước khi phát triển
- Chuyển từ ý tưởng mơ hồ thành khung dự án cụ thể

#### Điều kiện tiên quyết

Không có — đây là entry point.

#### Các bước thực hiện

| Bước | Mô tả |
|------|-------|
| **Phase 1: Thu thập** | Hỏi người dùng về ý tưởng kinh doanh (từng câu một) |
| **Phase 2: Phân tích** | Đánh giá độ phức tạp (SIMPLE / STANDARD / ENTERPRISE), huy động chuyên gia phân tích |
| **Phase 3: Soạn tài liệu** | Tạo tài liệu brainstorm, bản đồ hệ thống, phân tích chính sách (nếu STANDARD/ENTERPRISE) |
| **Phase 4: Khởi tạo** | Tạo cấu trúc `.mc-data/` và các thư mục cần thiết |

#### Agents được huy động

- `business-analyst` — phân tích nghiệp vụ
- Domain experts (tùy lĩnh vực) — tư vấn chuyên môn
- `legal-expert`, `compliance-expert` — phân tích chính sách (nếu cần)

#### Kết quả đầu ra

| File | Đường dẫn | Mô tả |
|------|-----------|-------|
| Brainstorm | `.mc-data/docs/phase0-brainstorm/P0-01-brainstorm.md` | Thông tin doanh nghiệp + chính sách |
| Bản đồ hệ thống | `.mc-data/docs/phase0-brainstorm/P0-02-systems-users.md` | Hệ thống, người dùng, tech stack |
| Chính sách | `.mc-data/docs/phase0-brainstorm/policies/*.md` | Định nghĩa chính sách (nếu có) |

#### Lưu ý quan trọng

1. **Hỏi từng câu một** — skill không hỏi nhiều câu cùng lúc, để người dùng dễ trả lời
2. **3 mức độ phức tạp** — SIMPLE (ít module), STANDARD (nhiều phòng ban), ENTERPRISE (hệ thống lớn) — quyết định mức độ chi tiết của phân tích
3. **Phân tích chính sách** chỉ chạy khi STANDARD/ENTERPRISE
4. **Bước tiếp theo:** `/wf-analyze-requirements`

---

### 2.2. /wf-analyze-requirements — Phân tích yêu cầu

**Phiên bản:** v2.0.0 | **Phase:** 1 | **Thời lượng:** Multi-session

#### Mô tả

Huy động đội ngũ chuyên gia ảo (Business Analyst + Domain Experts) để phân tích yêu cầu nghiệp vụ từ nhiều góc độ — tài chính, vận hành, nhân sự, marketing... Tạo tài liệu Phase 1 chi tiết cho từng phòng ban.

#### Cách sử dụng

```bash
/wf-analyze-requirements                    # Phân tích toàn bộ
/wf-analyze-requirements --scope=business   # Chỉ phân tích business
/wf-analyze-requirements --scope=functional # Chỉ phân tích functional
/wf-analyze-requirements --resume           # Tiếp tục phiên dang dở
/wf-analyze-requirements --status           # Xem trạng thái
```

#### Khi nào sử dụng

- Sau khi đã hoàn thành `/wf-brainstorm` (Phase 0)
- Cần xây dựng bộ yêu cầu nghiệp vụ đầy đủ cho dự án

#### Điều kiện tiên quyết

- `.mc-data/docs/phase0-brainstorm/` phải tồn tại (từ `/wf-brainstorm`)

#### Các bước thực hiện

| Bước | Mô tả |
|------|-------|
| **Phase 0** | Đọc tài liệu Phase 0, xác định phạm vi |
| **Phase 1** | Xây dựng kế hoạch phân tích (systems, departments) |
| **Phase 2-3** | Chạy song song: phân tích từng phòng ban bởi domain experts |
| **Phase 4-5** | Tổng hợp, giải quyết xung đột giữa các phòng ban |
| **Phase 6** | Cập nhật registry, tạo stakeholder review |
| **Phase 6d** | Ghi nhận các vấn đề tạm hoãn (deferred issues) cho Phase 2 |
| **Phase 8** | POST-GATE kiểm tra chất lượng, auto-fix nếu cần |

#### Agents được huy động

- `business-analyst` — phân tích nghiệp vụ chính
- Domain experts (finance, hr, operations, marketing, sales...) — phân tích chuyên sâu từng phòng ban
- `architect`, `compliance-expert` — stakeholder review

#### Kết quả đầu ra

| File | Đường dẫn | Mô tả |
|------|-----------|-------|
| Tài liệu phòng ban | `.mc-data/docs/phase1-business/departments/[dept]/[dept].md` | Phân tích cho từng phòng ban |
| Stakeholder review | `.mc-data/docs/phase1-business/stakeholder-review.md` | Đánh giá từ 3 góc độ |
| Registry | `.mc-data/docs/_meta/req-registry.json` | Cập nhật `requirements[]` |
| Deferred issues | `.mc-data/work/wf-analyze-requirements/deferred-issues.md` | Vấn đề chuyển sang Phase 2 |

#### Lưu ý quan trọng

1. **Multi-session** — dự án lớn có thể kéo dài nhiều phiên, dùng `--resume` để tiếp tục
2. **Song song hóa** — nhiều phòng ban được phân tích cùng lúc (tối đa 5 agents)
3. **Auto-correction** — tối đa 3 lần tự sửa nếu output chưa đạt chất lượng
4. **Registry safe-write** — chỉ update fields `requirements[]`, `systems[]`, `modules[]`, `departments[]`
5. **Bước tiếp theo:** `/wf-define-features`

---

### 2.3. /wf-define-features — Định nghĩa tính năng

**Phiên bản:** v2.0.0 | **Phase:** 2 | **Thời lượng:** Multi-session

#### Mô tả

Chuyển đổi requirements (REQ-IDs) thành feature specifications (FEAT-IDs) chi tiết — bao gồm user stories, business rules, acceptance criteria, permissions.

#### Cách sử dụng

```bash
/wf-define-features           # Định nghĩa tất cả features
/wf-define-features --resume  # Tiếp tục phiên dang dở
/wf-define-features --status  # Xem trạng thái
```

#### Khi nào sử dụng

- Sau khi đã hoàn thành `/wf-analyze-requirements` (Phase 1)
- Cần chuyển yêu cầu nghiệp vụ thành đặc tả tính năng cụ thể

#### Điều kiện tiên quyết

- `req-registry.json` phải có `requirements[]` (từ Phase 1)

#### Các bước thực hiện

| Bước | Mô tả |
|------|-------|
| **Phase 0** | Đọc registry, deferred issues từ Phase 1 |
| **Phase 1** | Mapping REQ-IDs → FEAT-IDs, phát hiện Large Project Mode |
| **Phase 2** | Tạo feature specs song song (mỗi system 3-5 agents) |
| **Phase 3** | Cross-validation: so sánh features với requirements |
| **Phase 4** | Stakeholder review bởi business-analyst + product-expert |
| **Phase 5** | Cập nhật registry `features[]`, ghi deferred findings |

#### Kết quả đầu ra

| File | Đường dẫn | Mô tả |
|------|-----------|-------|
| Feature specs | `.mc-data/docs/phase2-features/[sys]/[mod]/[feat-name].md` | 1 file / 1 feature (9 sections bắt buộc) |
| Stakeholder review | `.mc-data/docs/phase2-features/stakeholder-review.md` | Đánh giá chéo |
| Registry | `.mc-data/docs/_meta/req-registry.json` | Cập nhật `features[]` |
| Deferred findings | `.mc-data/work/wf-define-features/deferred-findings.md` | Vấn đề chuyển sang Phase 3 |

#### Lưu ý quan trọng

1. **1 feature = 1 file** — mỗi feature có file riêng, tránh trộn lẫn
2. **FEAT-ID format:** `FEAT-[SYS]-[MOD]-NNN` (ví dụ: `FEAT-CRM-CUST-001`)
3. **9 sections bắt buộc** cho mỗi feature spec — thiếu section nào sẽ fail POST-GATE
4. **Large Project Mode** — tự kích hoạt khi ≥50 requirements hoặc ≥40 features
5. **Scope expansion detection** — phát hiện nếu features vượt ngoài phạm vi Phase 1
6. **Bước tiếp theo:** `/wf-design`

---

### 2.4. /wf-design — Thiết kế kiến trúc

**Phiên bản:** v2.0.0 | **Phase:** 3 | **Thời lượng:** Multi-session

#### Mô tả

Tạo thiết kế kỹ thuật toàn diện — kiến trúc hệ thống, API contracts, database schema, integration map, infrastructure spec.

#### Cách sử dụng

```bash
/wf-design           # Thiết kế toàn bộ
/wf-design --resume  # Tiếp tục phiên dang dở
/wf-design --status  # Xem trạng thái
```

#### Khi nào sử dụng

- Sau khi đã hoàn thành `/wf-define-features` (Phase 2)
- Cần tài liệu thiết kế kỹ thuật trước khi code

#### Điều kiện tiên quyết

- `.mc-data/docs/phase2-features/` phải tồn tại với feature specs

#### Các bước thực hiện

| Bước | Mô tả |
|------|-------|
| **Phase 0** | Đọc feature specs, registry, deferred findings |
| **Phase 1** | Chọn kiến trúc (Module / System / Platform Design) |
| **Phase 2a** | Thiết kế kiến trúc tổng thể (architect) — SONG SONG |
| **Phase 2b** | Thiết kế API contract (architect) — SONG SONG |
| **Phase 2c** | Thiết kế database (dba) — TUẦN TỰ (phụ thuộc 2a) |
| **Phase 2d** | Thiết kế infra + integration (devops) — SONG SONG |
| **Phase 4a** | Stakeholder review (architect + security) |
| **Phase 4b-4c** | Ghi nhận deferred findings, cập nhật registry |

#### Agents được huy động

- `architect` — thiết kế kiến trúc chính
- `dba` — database design
- `devops` — infrastructure spec
- `security` — security review
- `code-reviewer` — review technical specs
- `ai-engineer` (điều kiện: nếu có AI/ML features)
- `data-engineer` (điều kiện: nếu có data pipeline)
- `automation-architect` (điều kiện: nếu có automation)

#### Kết quả đầu ra

| File | Đường dẫn | Mô tả |
|------|-----------|-------|
| Kiến trúc | `.mc-data/docs/phase3-architecture/P3-01-architecture.md` | Kiến trúc hệ thống (7 sections) |
| API Contract | `.mc-data/docs/phase3-architecture/technical-specs/api-contract.md` | Đặc tả API endpoints |
| Database | `.mc-data/docs/phase3-architecture/technical-specs/database-design.md` | Database schema + migrations |
| Infra | `.mc-data/docs/phase3-architecture/technical-specs/infra-spec.md` | Infrastructure + CI/CD |
| Integration | `.mc-data/docs/phase3-architecture/technical-specs/integration-map.md` | Bản đồ tích hợp |
| Stakeholder review | `.mc-data/docs/phase3-architecture/stakeholder-review.md` | Đánh giá kỹ thuật |
| Registry | `.mc-data/docs/_meta/req-registry.json` | Cập nhật `design_status` |

#### Lưu ý quan trọng

1. **Không thiết kế module ngoài registry** — chỉ thiết kế cho modules đã có trong `req-registry.json`
2. **Song song hóa** — Phase 2a + 2b + 2d chạy song song, 2c chạy sau (phụ thuộc architecture)
3. **Skeleton-first** — với tài liệu lớn (>3000 từ), tạo skeleton trước rồi điền chi tiết
4. **Registry safe-write** — chỉ update field `design_status`
5. **Bước tiếp theo:** `/wf-design-ux` (nếu có UI) hoặc `/wf-plan-modules` (nếu API-only)

---

### 2.5. /wf-design-ux — Thiết kế UX/UI

**Phiên bản:** v2.0.0 | **Phase:** 4 | **Thời lượng:** Multi-session

#### Mô tả

Thiết kế trải nghiệm người dùng — design system, navigation specs, screen groups với wireframes. Chỉ chạy khi dự án có giao diện (web/mobile).

#### Cách sử dụng

```bash
/wf-design-ux           # Thiết kế UX/UI
/wf-design-ux --resume  # Tiếp tục
/wf-design-ux --status  # Xem trạng thái
```

#### Khi nào sử dụng

- Sau khi đã hoàn thành `/wf-design` (Phase 3)
- Dự án có giao diện người dùng (web app, mobile app, desktop app)

#### Khi nào KHÔNG sử dụng

- Dự án chỉ có API (interface_type = "api-only") → tự động SKIP

#### Điều kiện tiên quyết

- `P3-01-architecture.md` phải tồn tại
- `interface_type != "api-only"` trong registry

#### Các bước thực hiện

| Bước | Mô tả |
|------|-------|
| **Phase 0** | Kiểm tra interface_type, nếu api-only → SKIP |
| **Phase 1** | Tạo Design System (colors, typography, spacing, components) |
| **Phase 2** | Tạo Navigation specs cho từng system |
| **Phase 3** | Tạo Screen Group specs song song (max 3-5 agents/batch) |
| **Phase 4** | Validation: accessibility audit, cross-validation |
| **Phase 5** | Stakeholder review, cập nhật registry |

#### Agents được huy động

- `ux-designer` — user flows, navigation
- `ui-designer` — visual design, design system
- `ux-architect` — layout architecture
- `brand-guardian` (điều kiện: nếu có brand guidelines)
- `ux-researcher` — user research context
- `accessibility-auditor` — Phase 4 validation

#### Kết quả đầu ra

| File | Đường dẫn | Mô tả |
|------|-----------|-------|
| Design System | `.mc-data/docs/phase4-ux/design-system.md` | Colors, typography, spacing, components |
| Navigation | `.mc-data/docs/phase4-ux/[sys]/Navigation-[sys].md` | Navigation specs cho từng system |
| Screen Groups | `.mc-data/docs/phase4-ux/[sys]/[mod]/[screen-group].md` | Wireframes + UI specs cho từng module |
| Stakeholder review | `.mc-data/docs/phase4-ux/stakeholder-review.md` | Đánh giá thiết kế |
| Registry | `.mc-data/docs/_meta/req-registry.json` | Cập nhật `ux_design_status` |

#### Lưu ý quan trọng

1. **Tự động skip** nếu `interface_type = "api-only"` — không cần can thiệp
2. **7 sections bắt buộc** cho mỗi screen group (layout, tabs, dialogs, sheets, view modes, API endpoints, UI-ID registry)
3. **ASCII wireframes phải THỰC** — không dùng placeholder
4. **UI-ID format:** `UI-[SYS]-[MOD]-[SCREEN]-NNN`
5. **FEAT-ID traceability** — mỗi screen phải mapping đến FEAT-IDs
6. **Bước tiếp theo:** `/wf-plan-modules`

---

### 2.6. /wf-plan-modules — Lập kế hoạch triển khai

**Phiên bản:** v1.5.0 | **Phase:** 5 (planning) | **Thời lượng:** Multi-session

#### Mô tả

Phân tích dependency giữa các modules, xác định thứ tự triển khai, tạo sprints và task files chi tiết — là bản đồ cho việc coding.

#### Cách sử dụng

```bash
/wf-plan-modules           # Lập kế hoạch
/wf-plan-modules --resume  # Tiếp tục
/wf-plan-modules --status  # Xem trạng thái
```

#### Khi nào sử dụng

- Sau khi đã hoàn thành `/wf-design` (Phase 3) và `/wf-design-ux` (Phase 4, nếu có)
- Cần roadmap triển khai trước khi bắt đầu code

#### Điều kiện tiên quyết

- `req-registry.json` phải có `modules[]`

#### Các bước thực hiện

| Bước | Mô tả |
|------|-------|
| **Phase 0** | Đọc registry, feature specs, architecture docs |
| **Phase 1-2** | Phân tích dependency giữa modules (song song) |
| **Phase 3** | Topological sort → xếp layers (Foundation/Core/Business/Operations/Intelligence) |
| **Phase 4-5** | Phát hiện MVP scope, impact analysis (điều kiện) |
| **Phase 6** | Tạo sprints, phân bổ features vào sprints |
| **Phase 7** | Tạo implementation roadmap + task files cho từng feature |
| **Phase 7.5** | Tạo task files chi tiết: `[feat]-impl.md` |
| **Phase 7b** | Stakeholder implementation review (architect + qa-lead) |

#### Kết quả đầu ra

| File | Đường dẫn | Mô tả |
|------|-----------|-------|
| Module plan | `.mc-data/docs/phase5-implementation/module-plan.md` | Dependency analysis |
| Dependency graph | `.mc-data/docs/phase5-implementation/dependency-graph.md` | Biểu đồ Mermaid |
| Roadmap | `.mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md` | Tổng quan triển khai |
| Sprint files | `.mc-data/docs/phase5-implementation/sprints/S0[N]-[name].md` | Chi tiết từng sprint |
| Task files | `.mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md` | Task cho từng feature |
| Registry | `.mc-data/docs/_meta/req-registry.json` | Cập nhật `implementation_order` |

#### Lưu ý quan trọng

1. **3 chế độ chạy:** SIMPLE (1 module), LITE (2 modules), FULL (3+ modules)
2. **Cycle detection** — phát hiện và xử lý dependency vòng lặp
3. **5 layers:** Foundation → Core → Business → Operations → Intelligence
4. **Task files** là input trực tiếp cho `/wf-implement-feature`
5. **Bước tiếp theo:** `/wf-implement-feature`

---

### 2.7. /wf-implement-feature — Viết code

**Phiên bản:** v2.0.0 | **Phase:** 5 (coding) | **Thời lượng:** Multi-session (per feature)

#### Mô tả

Viết code cho từng feature theo phương pháp TDD (Test-Driven Development) — viết test trước, code sau, review và sửa lỗi. Mỗi lần chạy implement 1 feature.

#### Cách sử dụng

```bash
/wf-implement-feature customer-management           # Implement feature cụ thể
/wf-implement-feature customer-management --resume  # Tiếp tục phiên dang dở
/wf-implement-feature --status                      # Xem trạng thái tất cả features
```

#### Khi nào sử dụng

- Sau khi đã hoàn thành `/wf-plan-modules` (có task files)
- Implement từng feature theo thứ tự trong roadmap

#### Điều kiện tiên quyết

- Task file tồn tại: `.mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`
- Architecture docs (Phase 3) tồn tại

#### Các bước thực hiện

| Bước | Mô tả |
|------|-------|
| **Phase 0** | Đọc task file, architecture docs, registry |
| **Phase 1** | Lập kế hoạch implementation (batches) |
| **Phase 2** | Chuẩn bị cấu trúc project (nếu là feature đầu tiên) |
| **Phase 3** | Chu trình TDD cho từng batch: |
| | **3.1 RED:** Viết failing tests (bao gồm edge cases) |
| | **3.2 GREEN:** Viết code tối thiểu để pass tests + REQ-ID comments |
| | **3.3 REFACTOR:** Dọn dẹp code, loại bỏ trùng lặp |
| **Phase 4-5** | Review loop: code-reviewer + qa-lead + security (max 3 vòng) |
| **Phase 5a** | Cross-validation: REQ-ID match, test coverage |
| **Phase 6** | Cập nhật registry `impl_status`, đánh dấu task done |

#### Agents được huy động

- `developer` — viết code (1 per batch)
- `code-reviewer` — review code quality
- `qa-lead` — review test coverage
- `security` — security review
- `api-tester` (điều kiện: nếu có API endpoints)
- `model-qa` (điều kiện: nếu có AI/ML features)

#### Kết quả đầu ra

| File | Đường dẫn | Mô tả |
|------|-----------|-------|
| Source code | `src/**`, `apps/**/src/**` | Code + REQ-ID comments |
| Test files | `tests/**`, `**/*.test.*` | Test suites |
| Impl status | `.mc-data/work/wf-implement-feature/$SLUG/impl-status.json` | Trạng thái implementation |
| QA reviews | `.mc-data/work/wf-implement-feature/$SLUG/qa-review-attempt-[N].md` | Review reports |
| Registry | `.mc-data/docs/_meta/req-registry.json` | Cập nhật `impl_status` per REQ-ID |

#### Lưu ý quan trọng

1. **1 lần chạy = 1 feature** — implement từng feature, không implement nhiều feature cùng lúc
2. **TDD bắt buộc** — viết test TRƯỚC, code SAU
3. **REQ-ID bắt buộc** — mọi file code phải có comment REQ-ID tham chiếu
4. **Review-Fix loop** tối đa 3 vòng — nếu vẫn fail sau 3 vòng → escalate
5. **Test coverage ratio** — `test_files / source_files >= 0.5`
6. **Multi-session** — mỗi feature có thể kéo dài nhiều phiên, dùng `--resume` để tiếp tục
7. **Bước tiếp theo:** Implement feature tiếp theo, hoặc `/wf-preflight` khi xong tất cả

---

### 2.8. /wf-preflight — Kiểm tra sức khỏe dự án

**Phiên bản:** v1.3.1 | **Phase:** Health check | **Thời lượng:** 1 session

#### Mô tả

Kiểm tra toàn diện sức khỏe dự án — registry integrity, document completeness, code-REQ sync, code quality. Cho điểm và verdict: PASS / WARN / FAIL.

#### Cách sử dụng

```bash
/wf-preflight                                    # Kiểm tra toàn bộ
/wf-preflight --scope=system --name=CRM          # Kiểm tra 1 system
/wf-preflight --scope=module --name=customer-mgmt # Kiểm tra 1 module
/wf-preflight --scope=feature --name=FEAT-CRM-001 # Kiểm tra 1 feature
/wf-preflight --fix                              # Tự động sửa lỗi tìm được
/wf-preflight --run-tests                        # Chạy cả test suite
```

| Tham số | Mô tả | Mặc định |
|---------|-------|----------|
| `--scope` | Phạm vi: `all`, `system`, `module`, `feature` | `all` |
| `--name` | Tên cụ thể (kết hợp với `--scope`) | — |
| `--fix` | Tự động sửa lỗi (JSON format, registry, orphan code) | OFF |
| `--run-tests` | Chạy test suite | OFF |

#### Khi nào sử dụng

- Sau khi implement xong features, trước khi verify
- Bất kỳ lúc nào cần health check dự án
- Trước deployment
- Khi nghi ngờ có vấn đề về tính nhất quán

#### Điều kiện tiên quyết

- Đã có code (Phase 5)

#### Các tracks kiểm tra

| Track | Trọng số | Nội dung |
|-------|----------|----------|
| Registry integrity | 20% | Format, IDs, cross-refs |
| Document completeness | 25% | Đủ tài liệu cho mỗi phase |
| Code-REQ sync | 30% | REQ-IDs trong code khớp với registry |
| Code quality | 25% | Type-check, lint, test (nếu `--run-tests`) |

#### Verdict

| Verdict | Điều kiện |
|---------|-----------|
| **PASS** | Score ≥ 80% VÀ không có CRITICAL issues |
| **WARN** | Score 60-79% HOẶC có HIGH severity issues |
| **FAIL** | Score < 60% HOẶC có CRITICAL issues |

#### Kết quả đầu ra

| File | Đường dẫn | Mô tả |
|------|-----------|-------|
| Report | `.mc-data/work/wf-preflight/preflight-report.md` | Verdict + chi tiết issues |
| Status | `.mc-data/work/wf-preflight/preflight-status.json` | Trạng thái JSON |
| History | `.mc-data/work/wf-preflight/preflight-history.md` | Lịch sử chạy (append-only) |

#### Lưu ý quan trọng

1. **Read-mostly** — chủ yếu đọc và phân tích, chỉ ghi file khi dùng `--fix`
2. **`--fix` auto-fix** — sửa JSON format, registry format, orphan code comments
3. **Re-score sau fix** — nếu dùng `--fix`, chạy lại scoring sau khi sửa
4. **Bước tiếp theo:** `/wf-verify-sync` (nếu PASS) hoặc `/wf-fix-bugs` (nếu WARN/FAIL)

---

### 2.9. /wf-fix-bugs — Tìm và sửa lỗi

**Phiên bản:** v9.1.0 | **Phase:** Bug fixing | **Thời lượng:** Multi-session

> **Lịch sử v9.x:** v9.0.0 (2026-05-10) ra mắt 10 dimension lanes (thêm QD9 + QD10) → v9.0.1 vá runtime dispatch drift (signal_bus, schemas, dimension.json cho QD9/QD10) → v9.0.2 (2026-05-10) đóng nốt 5 gap hạ tầng dùng chung → **v9.1.0 (2026-05-12, bản phát hành hiện tại)** thêm QD11 Business Completeness & Enhancement — 3-pass LLM analysis phát hiện missing business logic.

> **Lưu ý kiến trúc (v9.1):** `wf-fix-bugs` là **pure orchestrator** — thực thi 3 sub-skills + 11 dimension lanes song song:
> - `wf-fix-triage` — Phase 2 Triage (phân loại severity, fixability, generate fix-plan, phát hiện user_journey_broken)
> - `wf-fix-execute` — Phase 3 Fix + Phase 4 Docs Sync + Phase 5 Verify Loop + Phase 6 Report
> - **11 dimension lanes:** QD1-QD8 (hiện có) + **QD9 `wf-fix-runtime-health`** (Runtime Health — browser probes) + **QD10 `wf-fix-integration`** (Cross-Module Integration — static + runtime) + **QD11 `wf-fix-business-completeness`** (Business Completeness — 3-pass LLM analysis)
>
> v9.1 bổ sung: session isolation + ISG → partition → 11 dimension lanes → signal aggregation → CDG-12 (scope gate) + CDG-13 (cost gate) → triage → execute. CQG-2 pre-completion gate. QD11 enhancement suggestions qua CDG gate (user ACCEPT/REJECT).

#### Mô tả

Phát hiện lỗi trên 11 chiều chất lượng, phân loại mức độ nghiêm trọng, tự động sửa theo batch, cập nhật tài liệu nếu behavior thay đổi, verify sau khi sửa. **v9.1 thêm:** QD11 Business Completeness (3-pass LLM analysis phát hiện missing business logic). **v9.0 thêm:** kiểm tra browser runtime (QD9) và tích hợp cross-module (QD10), hỗ trợ YAML spec cho state machine và business flow, cost gate tự động.

#### Cách sử dụng

```bash
/wf-fix-bugs                                        # Tìm và sửa tất cả (11 lanes)
/wf-fix-bugs "Lỗi thanh toán trả về null"           # Mô tả lỗi cụ thể
/wf-fix-bugs --scope=module --name=payment           # Scope module cụ thể
/wf-fix-bugs --lane=QD9                             # Chỉ chạy lane QD9 (Runtime Health)
/wf-fix-bugs --lane=QD10                            # Chỉ chạy lane QD10 (Cross-Module)
/wf-fix-bugs --dims=QD1,QD9,QD10                    # Chọn nhiều lanes cụ thể
/wf-fix-bugs --since=HEAD~5                         # Chỉ kiểm tra modules có file thay đổi
/wf-fix-bugs --profile=quick                        # Profile nhanh (ít probes)
/wf-fix-bugs --profile=standard                     # Profile chuẩn (mặc định)
/wf-fix-bugs --profile=deep                         # Profile sâu (thêm agent probes)
/wf-fix-bugs --profile=exhaustive                   # Toàn diện (tất cả probes + YAML spec)
/wf-fix-bugs --dry-run                              # Chỉ phân tích, không sửa
/wf-fix-bugs --run-tests                            # Chạy tests sau khi sửa
/wf-fix-bugs --resume                               # Tiếp tục phiên dang dở
/wf-fix-bugs --migrate                              # Migrate session v6.x → v7+ format
```

| Tham số | Mô tả | Mặc định |
|---------|-------|----------|
| `mo-ta-loi` | Mô tả lỗi (tùy chọn) | — |
| `--scope` | Phạm vi: `all`, `system`, `module` | `all` |
| `--name` | Tên cụ thể | — |
| `--lane` | Chỉ chạy 1 dimension lane (QD1–QD11) | — |
| `--dims` | Chọn nhiều lanes (e.g. `QD1,QD9,QD10`) | tất cả |
| `--since` | Incremental: chỉ modules có file thay đổi từ git ref | — |
| `--profile` | `quick` / `standard` / `deep` / `exhaustive` | `standard` |
| `--dry-run` | Chỉ phân tích + triage, KHÔNG sửa | OFF |
| `--run-tests` | Chạy tests sau khi sửa | OFF |
| `--resume` | Tiếp tục phiên dang dở | — |
| `--migrate` | Migrate legacy session format | — |

#### Khi nào sử dụng

- Sau `/wf-preflight` cho kết quả WARN hoặc FAIL
- Phát hiện lỗi trong quá trình sử dụng
- Muốn kiểm tra browser/UI sau khi implement (`--lane=QD9`)
- Muốn kiểm tra tích hợp giữa các module (`--lane=QD10`)
- Bất kỳ lúc nào sau khi đã có code

#### Điều kiện tiên quyết

- Code phải tồn tại + registry phải tồn tại
- `--lane=QD9`: cần UI (interface_type=web) + dev server có thể start
- `--lane=QD10`: cần ít nhất 2 modules có `cross_module_dependencies` trong registry

#### 11 Dimension Lanes (v9.1)

| Lane | Skill | Phạm vi kiểm tra | Profile tối thiểu |
|------|-------|------------------|-------------------|
| QD1 | `wf-fix-functional` | Functional Correctness — feature đúng spec | quick |
| QD2 | `wf-fix-business` | Business Correctness — nghiệp vụ + domain rules | standard |
| QD3 | `wf-fix-security` | Security & Privacy — OWASP Top 10 | standard |
| QD4 | `wf-fix-performance` | Performance — CWV, query, bundle, memory | standard |
| QD5 | `wf-fix-ux-a11y` | Accessibility & UX — WCAG 2.2 AA + heuristics | standard |
| QD6 | `wf-fix-data` | Data Integrity — schema drift, migration | standard |
| QD7 | `wf-fix-compat` | Compatibility — deprecated API, browser, i18n | standard |
| QD8 | `wf-fix-observability` | Observability & Reliability — logging, metrics | deep |
| **QD9** | **`wf-fix-runtime-health`** | **Runtime Health — browser probes, SPA routes, form validation** | **standard** |
| **QD10** | **`wf-fix-integration`** | **Cross-Module Integration — API drift, event coverage, business flow** | **deep** |
| **QD11** | **`wf-fix-business-completeness`** | **Business Completeness — 3-pass LLM, registry gaps, missing logic** | **deep** |

#### Các bước thực hiện (orchestrator v9.1)

| Bước | Mô tả |
|------|-------|
| **Phase 0** | PRE-GATE: CDG-12 (scope gate nếu >20 modules) + CDG-13 (cost gate ước tính chi phí) + browser precheck (nếu UI) |
| **Phase 1** | ISG partition → dispatch 11 dimension lanes song song → signal aggregation |
| **Phase 2** | `wf-fix-triage`: phân loại severity + fixability + user_journey_broken detection |
| **Phase 3-5** | `wf-fix-execute`: Fix → Docs Sync → CQG-2 gate (QD9 console=0 + QD10 HIGH+=0) → Verify Loop |
| **Phase 6** | Report: fix-report.md (có Browser Verification section nếu QD9 chạy) + fix-history.md |

#### Kết quả đầu ra

Tất cả artifact trong `$SESSION_DIR = .mc-data/work/wf-fix-bugs/sessions/{YYYY-MM-DD-{scope}-{slug}-{NN}}/`:

| File | Owner | Mô tả |
|------|-------|-------|
| `fix-status.json` | Orchestrator (init) | Orchestration state + flags (since_ref, cost_estimate, browser_required) |
| `issue-registry.json` | Phase 1 → triage → execute | Danh sách issues + severity + verify results |
| `lanes/QD*/signals.json` | Mỗi lane | Signals phát hiện theo từng dimension |
| `bug-triage.md`, `fix-plan.md` | wf-fix-triage | Phân loại + kế hoạch sửa + User Journey Impact |
| `fix-log.json` | wf-fix-triage (init) → wf-fix-execute (append) | Chi tiết mọi fix |
| `fix-report.md` | wf-fix-execute Phase 6 | Báo cáo cuối (có Browser Verification nếu QD9) |
| `phase-summary.md` | wf-fix-execute Phase 6 | Summary tiếng Việt (CORE-028) |
| `.mc-data/work/wf-fix-bugs/fix-history.md` | wf-fix-execute Phase 6 | Cross-run append-only log |
| `fix-impact.json` | POST-GATE | Impact audit với checksum |
| Updated docs | wf-fix-execute Phase 4 | `.mc-data/docs/phase2-features/...` nếu behavior đổi |

#### Gates tự động (v9.0)

| Gate | Trigger | Hành động |
|------|---------|-----------|
| **CDG-12** | Scope > 20 modules | Hỏi: full-scan / scope-module / incremental / cancel |
| **CDG-13** | Ước tính chi phí > $5 | Hỏi: tiếp tục / giảm profile / hủy |
| **CQG-2** | Pre-completion check | Block nếu QD9 console_error > 0 hoặc QD10 HIGH+ tồn tại |

#### Lưu ý quan trọng

1. **`--dry-run`** — xem trước danh sách lỗi mà không sửa
2. **`--lane=QD9`** — cần dev server khởi động được; dùng khi muốn kiểm tra browser/UI nhanh
3. **`--lane=QD10`** — dùng sau khi authoring `cross_module_dependencies` trong registry
4. **`--since=HEAD~5`** — tăng tốc đáng kể khi chỉ muốn kiểm tra code vừa thay đổi
5. **`--profile=exhaustive`** — chạy YAML spec probes (state machine + business flow); yêu cầu file `.yaml` spec
6. **Cost gate** — nếu ước tính > $5, hệ thống sẽ hỏi trước khi spawn probes
7. **Bước tiếp theo:** `/wf-verify-sync`

> **Tài liệu đầy đủ v9:** Xem `docs/wf-fix-bugs-v9-guide.md` — hướng dẫn authoring YAML spec, cross-module deps, performance tips.

---

### 2.9.1. /wf-fix-triage — Triage engine (spawned)

**Phiên bản:** v1.4.0 | **Phase:** Bug triage | **Thời lượng:** 1 session

**Invocation:** `disable-model-invocation: true` — KHÔNG gọi trực tiếp từ user ngoại trừ `--resume`. Được `wf-fix-bugs` spawn sau Phase 1.

#### Mô tả

Thực thi Phase 2 Triage: đọc aggregated signals từ 11 dimension lanes → gán severity (CRITICAL/HIGH/MEDIUM/LOW) → gán fixability (AUTO_FIX/AGENT_FIX/ESCALATE/SKIP) → **phát hiện `user_journey_broken`** (khi QD10 signals ảnh hưởng cross-module flow) → generate `bug-triage.md` (human-readable, có "User Journey Impact" section) + `fix-plan.md` (batch plan) + init `fix-log.json`. KHÔNG sửa code.

#### Khi nào user gọi trực tiếp

```bash
/wf-fix-triage --resume       # Tiếp tục triage phase dang dở (session tồn tại)
```

#### Kết quả đầu ra chính

| File | Đường dẫn | Mô tả |
|------|-----------|-------|
| Bug triage | `$SESSION_DIR/bug-triage.md` | Phân loại issues + User Journey Impact |
| Fix plan | `$SESSION_DIR/fix-plan.md` | Batch plan CRITICAL → HIGH → MEDIUM |
| Issue registry | `$SESSION_DIR/issue-registry.json` | UPDATE: thêm severity + fixability |
| Fix log (init) | `$SESSION_DIR/fix-log.json` | Khởi tạo empty entries cho Phase 3 append |

---

### 2.9.2. /wf-fix-execute — Fix + Verify + Report engine (spawned)

**Phiên bản:** v2.0.0 | **Phase:** Bug fixing | **Thời lượng:** Multi-session

**Invocation:** `disable-model-invocation: true` — KHÔNG gọi trực tiếp từ user ngoại trừ `--resume`. Được `wf-fix-bugs` spawn ở Phase 3.

#### Mô tả

Thực thi Phase 3 Fix (theo batch CRITICAL → HIGH → MEDIUM) + Phase 4 Docs Sync (cập nhật feature specs nếu behavior thay đổi) + Phase 5 Verify Loop (max 3 iterations) + **CQG-2 pre-completion gate** (block nếu QD9 console_error > 0 hoặc QD10 HIGH+ còn tồn tại) + Phase 6 Report. Fix-report.md tự động thêm **"Browser Verification (QD9)"** section nếu QD9 chạy.

#### Khi nào user gọi trực tiếp

```bash
/wf-fix-execute --resume      # Tiếp tục fix/verify/report phase dang dở (session tồn tại)
```

#### Kết quả đầu ra chính

| File | Đường dẫn | Mô tả |
|------|-----------|-------|
| Fix log | `$SESSION_DIR/fix-log.json` | APPEND chi tiết mọi fix đã thực hiện |
| Fix report | `$SESSION_DIR/fix-report.md` | Báo cáo cuối (có Browser Verification nếu QD9) |
| Phase summary | `$SESSION_DIR/phase-summary.md` | Summary tiếng Việt (CORE-028) |
| Fix impact | `$SESSION_DIR/fix-impact.json` | Audit chain + checksum (POST-GATE) |
| Fix history | `.mc-data/work/wf-fix-bugs/fix-history.md` | Cross-run append-only log |
| Updated docs | `.mc-data/docs/phase2-features/...` | Cập nhật nếu behavior đổi |
| Registry updates | `req-registry.json` | `impl_status` safe-update (Phase 4a only) |

---

### 2.9.3. /wf-fix-runtime-health — Lane QD9: Runtime Health (spawned)

**Phiên bản:** v1.0.0 | **Phase:** Bug discovery (QD9) | **Thời lượng:** Varies by profile

**Invocation:** Spawned tự động bởi `wf-fix-bugs` khi QD9 nằm trong `--dims` hoặc `--lane=QD9`. Không gọi trực tiếp.

#### Mô tả

Dimension QD9 — kiểm tra runtime health qua browser probes (Playwright MCP). Chỉ chạy khi dự án có UI (interface_type=web). Gồm 7 probes theo profile:

| Probe | Profile | Mô tả |
|-------|---------|-------|
| P-QD9-dev-server-bootstrap | standard+ | Kiểm tra dev server start thành công |
| P-QD9-console-network-monitor | standard+ | Theo dõi console errors + network 4xx/5xx |
| P-QD9-auth-aware-smoke | standard+ | Smoke test sau khi đăng nhập (session/cookie) |
| P-QD9-feature-checklist-smoke | deep+ | Navigate từng feature impl_status=done |
| P-QD9-interactive-smoke | deep+ | Click tất cả CTAs (không destructive) |
| P-QD9-spa-route-coverage | deep+ | Verify mọi SPA route khai báo load được |
| P-QD9-form-validation-smoke | exhaustive | Submit form rỗng + fill invalid → kiểm tra validation |

#### Signals phát hiện

| Signal | Severity | Mô tả |
|--------|----------|-------|
| `dev_server_bootstrap_failed` | CRITICAL | Dev server không start |
| `uncaught_exception` | CRITICAL | JS exception trong console |
| `runtime_console_error` | HIGH | console.error trong browser |
| `post_auth_unauthorized` | HIGH | 401/403 sau khi đăng nhập |
| `feature_route_broken` | HIGH | Feature đã implement nhưng route không load |
| `form_validation_bypass` | HIGH | Submit form không hợp lệ không có validation |
| `spa_route_unreachable` | MEDIUM | SPA route khai báo không navigate được |
| `ui_cta_no_response` | MEDIUM | CTA click không thay đổi UI/URL |
| `form_validation_missing` | MEDIUM | Form không hiển thị error message |

---

### 2.9.4. /wf-fix-integration — Lane QD10: Cross-Module Integration (spawned)

**Phiên bản:** v1.0.0 | **Phase:** Bug discovery (QD10) | **Thời lượng:** Varies by profile

**Invocation:** Spawned tự động bởi `wf-fix-bugs` khi QD10 nằm trong `--dims` hoặc `--lane=QD10`. Không gọi trực tiếp.

#### Mô tả

Dimension QD10 — kiểm tra tích hợp giữa các modules. Yêu cầu `cross_module_dependencies[]` đã được khai báo trong registry. Gồm 10 probes theo profile:

| Probe | Profile | Mô tả |
|-------|---------|-------|
| P-QD10-cross-module-ref-static | standard+ | Kiểm tra import/type references giữa modules |
| P-QD10-api-contract-drift | standard+ | So sánh OpenAPI/GraphQL spec vs consumer DTO |
| P-QD10-event-handler-coverage | standard+ | Kiểm tra event emitted có handler tương ứng |
| P-QD10-multi-platform-entity-sync | deep+ | So sánh entity response giữa 2 platforms |
| P-QD10-state-machine-correctness | exhaustive | Verify state machine YAML spec vs code |
| P-QD10-business-flow-runtime | exhaustive | Chạy business-flow YAML spec từ đầu đến cuối |
| P-QD10-orphan-reference-runtime | deep+ (opt-in `--db-url`) | LEFT JOIN kiểm tra FK orphan records |
| P-QD10-cache-staleness-probe | exhaustive (opt-in `--test-cache-sync`) | PATCH + poll consumer kiểm tra cache sync |
| P-QD10-auth-matrix-check | exhaustive | Kiểm tra authorization matrix YAML vs code guards |

> **Điều kiện:** QD10 cần ít nhất 1 cặp `cross_module_dependencies` trong registry. Dùng `scripts/wf-detect-cross-module-deps.sh --dry-run` để auto-detect dependencies trước.

#### YAML Spec authoring (QD10 — exhaustive)

QD10 ở profile exhaustive đọc YAML spec để kiểm tra state machine và business flow:

| Spec | Schema | Mẫu |
|------|--------|-----|
| State machine | `doc-framework/_meta/state-machine-spec-schema.json` | `samples/state-machine-quotation-sample.yaml` |
| Business flow | `doc-framework/_meta/business-flow-spec-schema.json` | `samples/business-flow-quote-to-cash.yaml` |
| Authorization matrix | `doc-framework/_meta/authorization-matrix-schema.json` | `samples/authorization-matrix-erp-sample.yaml` |

---

### 2.9.5. /wf-fix-business-completeness — Lane QD11: Business Completeness (spawned)

**Phiên bản:** v1.0.0 | **Phase:** Bug discovery (QD11) | **Thời lượng:** Varies by profile

**Invocation:** Spawned tự động bởi `wf-fix-bugs` khi QD11 nằm trong `--dims` hoặc `--lane=QD11`. Không gọi trực tiếp.

#### Mô tả

Dimension QD11 — 100% LLM-based, phát hiện MISSING business logic mà static/runtime probes không thể thấy. Khác với QD1-QD10 (tìm BUG trong code hiện tại), QD11 tìm LOGIC CHƯA CÓ. Gồm 3-pass analysis:

| Pass | Probe | Profile | Mô tả |
|------|-------|---------|-------|
| Pass 1 | P-QD11-cross-module-comparison | deep+ | So sánh pattern giữa các module cùng domain (HIGH confidence) |
| Pass 2 | P-QD11-domain-heuristic | deep+ | Domain-specific heuristic analysis (MEDIUM confidence) |
| Pass 3 | P-QD11-registry-gap | deep+ | Registry gap detection — req có nhưng code chưa implement (HIGHEST confidence) |

#### Signals phát hiện (11 valid types)

| Signal | Mô tả |
|--------|-------|
| `MISSING_FIELD` | Entity thiếu field so với module cùng domain |
| `MISSING_FEATURE` | Module cùng domain thiếu feature mà module khác có |
| `TYPE_MISMATCH` | Cùng entity nhưng type khác nhau giữa 2 module |
| `VALIDATION_GAP` | Thiếu validation rule ở 1 module |
| `MISSING_DOMAIN_FIELD` | Thiếu field bắt buộc theo domain knowledge |
| `MISSING_COMPLIANCE_CHECK` | Thiếu compliance check (GDPR, audit trail...) |
| `MISSING_AUDIT_TRAIL` | Thiếu audit trail cho sensitive operation |
| `MISSING_BUSINESS_RULE` | Business rule có trong spec nhưng thiếu trong code |
| `UNIMPLEMENTED_REQ` | REQ-ID trong registry nhưng không có code |
| `ORPHAN_REQ_ID` | REQ-ID trong code nhưng không có trong registry |
| `GAP_REQ_TO_FEAT` | Requirement không được map sang feature |

#### Skip conditions

QD11 tự động SKIP khi:
- `profile=quick` (cần ít nhất deep)
- `interface_type=api-only` (cần business context)
- Single module (cần ≥2 modules để cross-module comparison)

#### Enhancement suggestions

QD11 không chỉ phát hiện gaps — nó còn đề xuất enhancement. Mỗi suggestion được đưa qua **CDG gate** cho user ACCEPT/REJECT/Defer trước khi implement.

#### Kết quả đầu ra

| File | Đường dẫn | Mô tả |
|------|-----------|-------|
| Signals | `$SESSION_DIR/lanes/QD11/signals.json` | Signals phát hiện (11 valid types) |
| Enhancement suggestions | `$SESSION_DIR/lanes/QD11/enhancements.json` | Đề xuất cải tiến (user ACCEPT/REJECT) |

---

### 2.10. /wf-verify-sync — Kiểm tra truy xuất nguồn gốc

**Phiên bản:** v1.9.0 | **Phase:** Verification | **Thời lượng:** 1 session

#### Mô tả

Kiểm tra cuối cùng trước release — verify rằng mọi requirement đều có code tương ứng (REQ-ID traceability). Tính Sync Rate và Coverage Rate.

#### Cách sử dụng

```bash
/wf-verify-sync                           # Verify toàn bộ
/wf-verify-sync --scope=system --name=CRM # Verify 1 system
/wf-verify-sync --scope=module --name=auth # Verify 1 module
```

#### Khi nào sử dụng

- Sau khi implement xong các features
- Trước khi chuẩn bị deployment
- Khi cần đánh giá mức độ hoàn thành dự án

#### Điều kiện tiên quyết

- Code phải tồn tại + registry phải tồn tại

#### Các chỉ số

| Chỉ số | Công thức | Ý nghĩa |
|--------|-----------|----------|
| **Sync Rate** | (Implemented / Total REQ-IDs) × 100% | Chỉ tính status="done" |
| **Coverage Rate** | ((Implemented + InProgress) / Total) × 100% | Tất cả code tồn tại |

| Phân loại | Mô tả |
|-----------|-------|
| Implemented | Code tồn tại + impl_status="done" |
| In Progress | Code tồn tại + impl_status ≠ "done" |
| W001 Anomaly | impl_status="done" nhưng code KHÔNG TÌM THẤY → WARNING (không downgrade) |
| Not Started | Không có code + impl_status ≠ "done" |
| Orphan Code | Code có nhưng không có REQ-ID comment |

#### Kết quả đầu ra

| File | Đường dẫn | Mô tả |
|------|-----------|-------|
| Sync report | `.mc-data/docs/_meta/verify-sync.md` | Báo cáo sync + warnings |
| Registry | `.mc-data/docs/_meta/req-registry.json` | Cập nhật `impl_status` |
| History | `.mc-data/work/wf-verify-sync/verify-sync-history.md` | Lịch sử verify |

#### Lưu ý quan trọng

1. **KHÔNG BAO GIỜ downgrade** `impl_status="done"` → giá trị khác (quy tắc quan trọng nhất)
2. **Chỉ upgrade:** `not_started → in_progress` (code found), `in_progress → done` (code + tests pass)
3. **W001 Anomaly** — nếu status="done" nhưng không tìm thấy code → log warning, KHÔNG đổi status
4. **Sync Rate ≥ 80%** → sẵn sàng cho deployment
5. **Bước tiếp theo:** `/wf-prepare-deployment` (nếu ≥80%) hoặc `/wf-fix-bugs` (nếu <80%)

---

### 2.11. /wf-prepare-deployment — Chuẩn bị triển khai

**Phiên bản:** v1.7.0 | **Phase:** 6 | **Thời lượng:** 1 session

#### Mô tả

Tạo bộ tài liệu triển khai đầy đủ — deployment guide (10 mục), user guide, incident response runbook.

#### Cách sử dụng

```bash
/wf-prepare-deployment
```

#### Khi nào sử dụng

- Sau khi `/wf-verify-sync` đạt Sync Rate ≥ 80%
- Chuẩn bị cho deployment / go-live

#### Điều kiện tiên quyết

- `/wf-verify-sync` đã passed (sync ≥ 80%)

#### Agents được huy động

- `devops` — deployment guide (10 mục kỹ thuật)
- `tech-writer` — user guide + account management
- `sre` — incident response runbook
- `qa-lead` + `integration-certifier` — stakeholder review

#### Kết quả đầu ra

| File | Đường dẫn | Mô tả |
|------|-----------|-------|
| Deployment guide | `.mc-data/docs/phase6-deployment/deployment-guide.md` | 10 mục: requirements, environments, CI/CD, rollback, monitoring... |
| User guide | `.mc-data/docs/phase6-deployment/user-guide.md` | Hướng dẫn sử dụng (role-based, workflow-based, FAQ) |
| Incident runbook | `.mc-data/docs/phase6-deployment/incident-response-runbook.md` | Quy trình xử lý sự cố |
| Stakeholder review | `.mc-data/docs/phase6-deployment/stakeholder-review.md` | Đánh giá sẵn sàng triển khai |

#### Lưu ý quan trọng

1. **Song song hóa** — Deployment guide + User guide được tạo song song
2. **10 mục Deployment Guide:** System Requirements, Environments, Deployment Process, CI/CD, Rollback, Migration, Monitoring, Go-Live Checklist, Account Management, Maintenance Guide
3. **Đây là bước cuối cùng** trong workflow Standard Path

---

## 3. Legacy Skills — Dự Án Có Sẵn (Existing Path)

Dành cho dự án đã có codebase, cần onboard vào DEVKIT để quản lý và phát triển tiếp.

```
/wf-legacy-scan (all-in-one: detect → classify → extract → synthesize) →
/wf-brainstorm* → /wf-analyze-requirements* → /wf-define-features* → /wf-design* →
/wf-annotate-code (nếu có annotation gaps) →
/wf-design-ux* (nếu có UI) → /wf-plan-modules → /wf-implement-feature → ...

* = shared skills tự detect legacy mode và inject context
```

### 3.1. /wf-legacy-scan — Quét và đánh giá dự án

**Phiên bản:** v3.1.0 | **Stage:** 0-1 | **Thời lượng:** 1 session

#### Mô tả

Bước đầu tiên khi đưa dự án có sẵn vào DEVKIT. Quét codebase, đánh giá mức độ trưởng thành, tạo inventory files, và đề xuất chiến lược xử lý (S1-S7).

#### Cách sử dụng

```bash
/wf-legacy-scan                         # Quét thư mục hiện tại
/wf-legacy-scan /path/to/project        # Quét thư mục khác
/wf-legacy-scan --resume                # Tiếp tục
/wf-legacy-scan --re-vision             # Chiến lược RE-VISION (S6)
/wf-legacy-scan --batch-size=50         # Thay đổi batch size
/wf-legacy-scan --status                # Xem trạng thái pipeline
```

#### Khi nào sử dụng

- Có codebase sẵn, muốn DEVKIT phân tích và quản lý
- Dự án có `.mc-data/` chưa hoàn chỉnh
- Dự án chỉ có tài liệu (không có code) — DOCS_ONLY mode

#### Điều kiện tiên quyết

- Thư mục dự án phải tồn tại và không rỗng

#### Các bước thực hiện

| Bước | Mô tả |
|------|-------|
| **Stage 0: Detection** | Quét cấu trúc project, tạo `project-profile.json` |
| **Stage 0A: Assessment** | Đánh giá điểm số, đề xuất chiến lược (S1-S7), hỏi user xác nhận |
| **Stage 0.5: Maturity** | Validation (điều kiện: nếu đã có `.mc-data/` một phần) |
| **Stage 1: Inventory** | Tạo inventory: screens, APIs, docs, sources, dependencies |

#### 7 Chiến lược xử lý

| Chiến lược | Điều kiện | Mô tả |
|------------|-----------|-------|
| **S1: FAST-TRACK** | DEVKIT complete + alignment cao | Nhanh nhất, chỉ kiểm tra |
| **S2: CODE-FIRST** | Chỉ có code + chất lượng khá | Mặc định cho code-only |
| **S3: DOCS-FIRST** | Chỉ có docs + chất lượng tốt | Chuẩn hóa từ tài liệu |
| **S4: DOCS-BRAINSTORM** | Chỉ có docs + chất lượng thấp | Cần brainstorm thêm |
| **S5: DIVERGENCE** | DEVKIT complete + alignment thấp | Giải quyết xung đột code ↔ docs |
| **S6: RE-VISION** | Kích hoạt bằng `--re-vision` | Tái định hướng dự án |
| **S7: FULL-REBUILD** | Code chất lượng thấp | Xây dựng lại từ đầu |

#### Kết quả đầu ra

| File | Đường dẫn | Mô tả |
|------|-----------|-------|
| Project profile | `.mc-data/work/legacy-scan/project-profile.json` | Tech stack, maturity, complexity |
| Assessment | `.mc-data/work/legacy-scan/assessment-report.json` | Điểm đánh giá + chiến lược |
| Screens | `.mc-data/work/legacy-scan/inventory/screens.json` | UI screens/pages |
| API endpoints | `.mc-data/work/legacy-scan/inventory/api-endpoints.json` | API routes |
| Doc files | `.mc-data/work/legacy-scan/inventory/doc-files.json` | Documentation |
| Source files | `.mc-data/work/legacy-scan/inventory/source-files.json` | Source code |
| Dependencies | `.mc-data/work/legacy-scan/inventory/dependency-graph.json` | Dependency analysis |
| Ledger | `.mc-data/work/legacy-scan/ledger.json` | Pipeline state machine |

#### Lưu ý quan trọng

1. **Hỏi user xác nhận** chiến lược trước khi tiếp tục
2. **3 tiers kích thước:** SMALL (<100 files), MEDIUM (100-500), LARGE (>500)
3. **Không dùng agents** — stage 0-1 hoàn toàn deterministic (scripts)
4. **`--status`** hiển thị trạng thái toàn bộ pipeline (không chỉ scan)
5. **Bước tiếp theo:** `/wf-legacy-classify`

---

### 3.2. /wf-legacy-classify — Phân loại files

**Phiên bản:** v1.4.0 | **Stage:** 2 | **Thời lượng:** 1-2 sessions

#### Mô tả

Phân loại tất cả files từ inventory vào systems/modules. Tạo glossary thuật ngữ chuyên ngành.

#### Cách sử dụng

```bash
/wf-legacy-classify                    # Phân loại
/wf-legacy-classify --resume           # Tiếp tục
/wf-legacy-classify --batch-size=50    # Thay đổi batch size (10-500)
/wf-legacy-classify --status           # Xem tiến độ
```

#### Khi nào sử dụng

- Sau khi `/wf-legacy-scan` hoàn thành

#### Agents được huy động

- `code-reviewer` — phân loại files (1 per batch, tuần tự)
- `business-analyst` — tạo glossary (1 lần, cuối cùng)

#### Kết quả đầu ra

| File | Đường dẫn | Mô tả |
|------|-----------|-------|
| Classifications | `.mc-data/work/legacy-scan/classified/batch-*.json` | Phân loại per batch |
| Glossary | `.mc-data/work/legacy-scan/classified/glossary.json` | Thuật ngữ domain |

#### Lưu ý quan trọng

1. **Tuần tự** — 1 agent/batch, checkpoint mỗi 3 batches
2. **Yêu cầu ≥95%** files được phân loại (5% margin cho ignored files)
3. **DOCS_ONLY mode** — phân loại theo doc_type thay vì source code categories
4. **Bước tiếp theo:** `/wf-legacy-extract`

---

### 3.3. /wf-legacy-extract — Trích xuất yêu cầu

**Phiên bản:** v1.3.0 | **Stage:** 3 | **Thời lượng:** 1-3 sessions

#### Mô tả

Trích xuất requirements và features từ classified modules — sử dụng domain experts phù hợp với từng module.

#### Cách sử dụng

```bash
/wf-legacy-extract                       # Trích xuất tất cả modules
/wf-legacy-extract --module=payment      # Chỉ 1 module cụ thể
/wf-legacy-extract --resume              # Tiếp tục
/wf-legacy-extract --status              # Xem tiến độ
```

#### Khi nào sử dụng

- Sau khi `/wf-legacy-classify` hoàn thành

#### Agents được huy động

- `business-analyst` — per module
- Domain experts tự động chọn theo keywords trong module:
  - `finance-expert` (invoice, payment, VAT...)
  - `hr-expert` (employee, payroll, leave...)
  - `ecommerce-expert` (product, cart, checkout...)
  - `operations-expert` (inventory, warehouse...)
  - Và các domain experts khác

#### Kết quả đầu ra

| File | Đường dẫn | Mô tả |
|------|-----------|-------|
| Extracted data | `.mc-data/work/legacy-scan/extracted/{module}.json` | REQs + features per module |
| Dedup report | `.mc-data/work/legacy-scan/extracted/dedup-report.json` | Kết quả loại bỏ trùng lặp |
| Divergences | `.mc-data/work/legacy-scan/extracted/{module}-divergences.json` | Chỉ S5: xung đột code↔docs |

#### Lưu ý quan trọng

1. **Song song** — tối đa 3 modules cùng lúc
2. **Auto domain expert** — tự chọn expert phù hợp dựa trên keywords
3. **Dedup** — tự loại bỏ requirements trùng (>85% similarity)
4. **Confidence score** — ≥0.8 (chắc chắn), 0.5-0.79 (suy luận), <0.5 (phỏng đoán)
5. **Bước tiếp theo:** `/wf-brainstorm` (sẽ tự detect legacy mode và inject context — CORE-021)

---

### 3.4. /wf-annotate-code — Inject REQ-ID vào code

**Phiên bản:** v1.1.0 | **Stage:** 5.5 (conditional) | **Thời lượng:** 1 session (small), multi-session (large)

#### Mô tả

Inject REQ-ID và FEAT-ID comments vào existing code files để thiết lập traceability. Dùng cho dự án legacy đã có code nhưng chưa có REQ-ID annotations.

#### Cách sử dụng

```bash
/wf-annotate-code                    # Annotate tất cả modules
/wf-annotate-code --module=CRM       # Chỉ 1 module cụ thể
/wf-annotate-code --dry-run          # Chỉ tạo annotation map, không ghi code
/wf-annotate-code --batch-size=30    # Giới hạn số files per batch
/wf-annotate-code --resume           # Tiếp tục từ checkpoint
/wf-annotate-code --status           # Xem trạng thái hiện tại
```

#### Khi nào sử dụng

- Sau khi `/wf-design` (legacy mode) hoàn thành VÀ có annotation gaps
- Traceability score thấp (< 50%)
- Muốn thêm REQ-ID vào code hiện có

#### Khi nào KHÔNG sử dụng

- Dự án mới — `/wf-implement-feature` tự có REQ-ID
- Chưa có `req-registry.json` hoặc `module-code-mapping.json`

#### Đầu ra

| File | Vị trí | Nội dung |
|------|--------|----------|
| Annotated code files | Source code | REQ-ID/FEAT-ID comments được inject |
| `annotation-report.md` | `.mc-data/work/legacy-scan/` | Báo cáo tổng hợp annotations |
| `annotation-map.json` | `.mc-data/work/legacy-scan/` | Map chi tiết file → REQ-IDs |

#### Lưu ý quan trọng

1. **Không modify registry** — chỉ ghi vào code files
2. **Hỗ trợ --resume** — checkpoint per batch cho dự án lớn
3. **Bước tiếp theo:**
   - Có UI → `/wf-design-ux` (sẽ tự detect legacy mode)
   - Không UI → `/wf-plan-modules`

---

### 3.5. /wf-add-scope — Thêm modules vào registry

**Phiên bản:** v1.0.0 | **Phase:** Incremental scope | **Thời lượng:** 10-30 min

#### Mô tả

Thêm modules + features mới vào registry đã có — giải quyết gap khi analyze-requirements/define-features không có path incremental. Dùng khi phát hiện orphan systems hoặc cần bổ sung scope vào dự án active.

#### Cách sử dụng

```bash
/wf-add-scope --system=<id> [--modules=<list>] [--from-mapping] [--interactive] [--dry-run] [--no-docs]
```

| Tham số | Mô tả | Mặc định |
|---------|-------|----------|
| `--system` | ID của system cần thêm (bắt buộc) | — |
| `--modules` | Danh sách modules cần thêm (phẩy) | — |
| `--from-mapping` | Đọc từ module-code-mapping.json (legacy) | OFF |
| `--interactive` | Chế độ tương tác — hỏi user xác nhận từng module | OFF |
| `--dry-run` | Chỉ hiển thị thay đổi, không ghi | OFF |
| `--no-docs` | Không tạo feature spec stubs | OFF |

#### Khi nào sử dụng

- Phát hiện orphan systems (có code nhưng chưa có trong registry)
- Cần bổ sung scope vào dự án đang active
- Sau `/wf-legacy-scan` phát hiện thêm modules cần quản lý

#### Điều kiện tiên quyết

- `req-registry.json` phải tồn tại (dự án đã qua brainstorm)

#### Kết quả đầu ra

| File | Đường dẫn | Mô tả |
|------|-----------|-------|
| Registry | `.mc-data/docs/_meta/req-registry.json` | Append: `modules[]`, `features[]` |
| Feature stubs | `.mc-data/docs/phase2-features/[sys]/[mod]/[feat].md` | Stub files để `/wf-define-features` flesh-out |

#### Lưu ý quan trọng

1. **Append-only** — chỉ thêm entries mới, không modify/delete/rename existing
2. **Idempotent** — re-run an toàn, dedup theo ID
3. **LEGACY mode nhanh hơn** — đọc từ module-code-mapping.json thay vì interactive
4. **Bước tiếp theo:** `/wf-define-features` (review/flesh-out stubs) hoặc `/wf-plan-modules` (re-run)

---

### 3.6. /wf-manage-change — Xử lý thay đổi tính năng

**Phiên bản:** v1.2.0 | **Phase:** Cross-phase | **Thời lượng:** Multi-session (30-120 min)

#### Mô tả

Xử lý yêu cầu thay đổi/bổ sung/sửa đổi tính năng trong dự án đang phát triển. Phân tích prompt người dùng → triển chuyên gia phân tích → đánh giá impact → lập kế hoạch → thực hiện thay đổi (docs + code) → verify không regression.

#### Cách sử dụng

```bash
/wf-manage-change "Thay đổi cách tính phí đơn hàng"           # Mô tả thay đổi
/wf-manage-change "Bổ sung xác thực 2 lớp" --scope=system      # Có scope
/wf-manage-change "Xóa tính năng xuất Excel" --mode=quick       # Quick mode
/wf-manage-change "Tôi muốn thay đổi..." --dry-run              # Chỉ phân tích
/wf-manage-change --status                                      # Xem tiến độ
/wf-manage-change --resume                                      # Tiếp tục
```

| Tham số | Mô tả | Mặc định |
|---------|-------|----------|
| `mo-ta-thay-doi` | Mô tả yêu cầu thay đổi bằng ngôn ngữ tự nhiên | — |
| `--scope` | Phạm vi: `all`, `system`, `module` | `all` |
| `--name` | ID của system/module khi scope hẹp | — |
| `--mode` | `quick` (AI phân tích trực tiếp) / `deep` (triển chuyên gia) | auto |
| `--dry-run` | Chỉ phân tích + impact, KHÔNG thực hiện thay đổi | OFF |
| `--resume` | Resume từ checkpoint | — |

#### Khi nào sử dụng

- Thay đổi logic/cách hoạt động của tính năng đã có
- Bổ sung thông tin/chi tiết cho yêu cầu/tính năng đã có nhưng chưa đầy đủ
- Thêm feature mới vào module đã có
- Xóa feature hoặc deprecate module
- Thay đổi yêu cầu business ảnh hưởng nhiều hệ thống
- Làm rõ/bổ sung yêu cầu khi AI làm chưa đúng ý

#### Khi nào KHÔNG sử dụng

- Dự án mới hoàn toàn → dùng `/new-project`
- Chỉ thêm feature mới hoàn toàn (đã biết rõ) → dùng `/feature-addition`
- Fix bug (code bị lỗi) → dùng `/wf-fix-bugs`
- Thêm modules mới vào registry → dùng `/wf-add-scope`

#### Điều kiện tiên quyết

- `req-registry.json` phải tồn tại (dự án đã qua brainstorm)

#### Các bước thực hiện

| Bước | Mô tả |
|------|-------|
| **Phase 0** | Intake — đọc user prompt, xác định change type |
| **Phase 1** | Analyze — phân tích yêu cầu, chọn chuyên gia phù hợp |
| **Phase 2** | Impact Assessment — đánh giá ảnh hưởng đến docs, code, registry |
| **Phase 3** | Plan — lập kế hoạch thay đổi chi tiết |
| **Phase 4** | Execute — cập nhật docs + code theo kế hoạch |
| **Phase 5** | Verify — chạy mini-verify, kiểm tra regression |
| **Phase 6** | Report — tổng hợp thay đổi, cập nhật registry |

#### Kết quả đầu ra

| File | Đường dẫn | Mô tả |
|------|-----------|-------|
| Change report | `.mc-data/work/wf-manage-change/change-report-[date].md` | Báo cáo thay đổi |
| Updated docs | `.mc-data/docs/phase1-6/` | Tài liệu đã cập nhật |
| Updated code | Source code | Code đã thay đổi |
| Registry | `.mc-data/docs/_meta/req-registry.json` | Cập nhật nếu cần |

#### Lưu ý quan trọng

1. **Bất kỳ lúc nào** — có thể gọi sau khi có registry, không cần chờ phase cuối
2. **Dry-run** — dùng `--dry-run` để xem impact trước khi quyết định
3. **Mode tự động** — `quick` cho thay đổi đơn giản, `deep` cho thay đổi phức tạp
4. **Regression check** — luôn verify không phá hỏng tính năng khác
5. **Bước tiếp theo:** `/wf-preflight` hoặc `/wf-verify-sync` (verify tổng thể)

---

## 4. Orchestrator Skills — Điều Phối Tự Động

Orchestrator skills tự động chạy nhiều workflow skills theo thứ tự đúng — người dùng chỉ cần gọi 1 lệnh.

### 4.1. /new-project — Dự án mới từ đầu

**Phiên bản:** v2.1.0 | **Thời lượng:** Multi-session (nhiều ngày)

#### Mô tả

Tự động chạy toàn bộ workflow từ ý tưởng đến deployment — 10 bước tuần tự, bao gồm skip conditions và vòng lặp implement per feature.

#### Cách sử dụng

```bash
/new-project                         # Bắt đầu dự án mới
/new-project "CRM System"            # Bắt đầu với tên dự án
/new-project --resume                # Tiếp tục từ checkpoint
/new-project --from-phase 3          # Bắt đầu từ Phase 3
/new-project --status                # Xem tiến độ
```

#### Chuỗi thực thi

```
Bước 0: /wf-brainstorm
Bước 1: Init (tạo cấu trúc project)
Bước 2: /wf-analyze-requirements
Bước 3: /wf-define-features
Bước 4: /wf-design
Bước 5: /wf-design-ux (skip nếu api-only)
Bước 6: /wf-plan-modules
Bước 7: /wf-implement-feature (lặp per feature)
Bước 8: /wf-verify-sync
Bước 9: /wf-prepare-deployment
```

#### Khi nào sử dụng

- Bắt đầu dự án phần mềm hoàn toàn mới
- Muốn DEVKIT tự điều phối toàn bộ quy trình

#### Lưu ý quan trọng

1. **Multi-session** — kéo dài nhiều phiên, dùng `--resume` để tiếp tục
2. **Auto-skip Phase 4** nếu `interface_type = "api-only"`
3. **POST-GATE per phase** — mỗi phase phải pass mới chuyển sang phase tiếp
4. **`--from-phase`** — kiểm tra prerequisites trước khi nhảy

---

### 4.2. /existing-project — Dự án có sẵn

**Phiên bản:** v3.0.0 | **Thời lượng:** Multi-session (nhiều ngày)

#### Mô tả

Tự động chạy Legacy Scan pipeline (6 bước) rồi tiếp tục phát triển dự án.

#### Cách sử dụng

```bash
/existing-project                    # Bắt đầu scan dự án hiện tại
/existing-project --resume           # Tiếp tục
/existing-project --from-phase scan  # Bắt đầu từ legacy scan
/existing-project --from-phase 5a   # Bắt đầu từ plan modules
```

#### Chuỗi thực thi

```
Bước 0: /wf-legacy-scan → /wf-legacy-classify → /wf-legacy-extract →
         /wf-brainstorm* → /wf-analyze-requirements* → /wf-define-features* → /wf-design* →
         /wf-annotate-code (nếu có annotation gaps) → /wf-design-ux* (nếu có UI)
         (* shared skills tự detect legacy mode)
Bước 1: /wf-plan-modules
Bước 2: /wf-implement-feature (lặp)
Bước 3: /wf-verify-sync
```

#### Khi nào sử dụng

- Có codebase sẵn, muốn DEVKIT quản lý và phát triển tiếp
- Codebase bất kỳ kích cỡ (từ nhỏ đến lớn)

#### Lưu ý quan trọng

1. **Backup** — nếu `.mc-data/` đã tồn tại, sẽ hỏi user trước khi ghi đè (có option backup)
2. **Pipeline phải COMPLETE** trước khi chuyển sang Plan Modules

---

### 4.3. /feature-addition — Thêm tính năng

**Phiên bản:** v2.3.0 | **Thời lượng:** Multi-session

#### Mô tả

Thêm tính năng mới vào dự án đã có architecture (Phase 3+) — gọn hơn `/new-project`.

#### Cách sử dụng

```bash
/feature-addition                          # Thêm feature mới
/feature-addition "Export PDF Reports"     # Thêm feature cụ thể
/feature-addition --resume                 # Tiếp tục
/feature-addition --from-phase 5b          # Bắt đầu từ implement
```

#### Chuỗi thực thi

```
Phase 0: Context Loading
Phase 2: /wf-define-features (feature mới)
Phase 3: /wf-design (điều kiện — nếu cần cập nhật architecture)
Phase 4: /wf-design-ux (điều kiện — nếu feature có UI)
Phase 5a: /wf-plan-modules
Phase 5b: /wf-implement-feature (lặp per feature)
Phase 7: /wf-verify-sync
```

#### Khi nào sử dụng

- Dự án đã qua Phase 3 (có architecture)
- Chỉ cần thêm features mới, không cần redo toàn bộ quy trình

#### Điều kiện tiên quyết

- `.mc-data/docs/phase3-architecture/` tồn tại
- `req-registry.json` tồn tại

#### Lưu ý quan trọng

1. **Skip Phase 3** nếu feature mới không ảnh hưởng architecture
2. **Skip Phase 4** nếu `api-only` hoặc feature không có UI
3. **Feature tracking** — lưu `existing_feature_ids` vs `new_feature_ids` để so sánh

---

## 5. Utility Skills — Công Cụ Hỗ Trợ

### 5.1. /status — Xem tiến độ dự án

**Phiên bản:** v1.3.0 | **Thời lượng:** Instant (read-only)

#### Mô tả

Dashboard hiển thị tiến độ dự án — tổng quan features, sprints, implementation coverage, và đề xuất hành động tiếp theo.

#### Cách sử dụng

```bash
/status                        # Tổng quan dự án
/status --sprint=S01           # Chi tiết sprint S01
/status --system=CRM           # Lọc theo system CRM
/status --detailed             # Hiển thị tất cả features + tasks
```

#### Khi nào sử dụng

- Bất kỳ lúc nào muốn biết tiến độ dự án
- Sau khi implement features để kiểm tra tổng thể
- Khi cần biết next action

#### Điều kiện tiên quyết

- `req-registry.json` tồn tại (tối thiểu)

#### Đặc điểm

- **Read-only** — không tạo file, không modify data
- **Không spawn agents** — xử lý trực tiếp
- **Recommended Next Action** — tự động đề xuất lệnh tiếp theo dựa trên trạng thái hiện tại
- **Graceful degradation** — hiển thị được ngay cả khi thiếu một số data sources

#### Status Icons

| Icon | Status | Ý nghĩa |
|------|--------|---------|
| ✅ | `done` | Hoàn thành |
| 🔄 | `in_progress` | Đang triển khai |
| ⬜ | `not_started` | Chưa bắt đầu |
| ⏸️ | `paused` | Tạm dừng |
| ❌ | `blocked` | Bị block |

---

### 5.2. /ui-ux-pro-max — Thiết kế UI/UX nâng cao

**Phiên bản:** v2.2.0 | **Thời lượng:** 1 session

#### Mô tả

Công cụ thiết kế UI/UX với cơ sở dữ liệu 50+ styles, 97 color palettes, 57 font pairings, hỗ trợ 9+ tech stacks. Tạo design system hoàn chỉnh từ keywords.

#### Cách sử dụng

```bash
/ui-ux-pro-max "modern SaaS dashboard"                    # Từ keywords
/ui-ux-pro-max "e-commerce fashion" --stack=react          # Cho React
/ui-ux-pro-max "healthcare portal" --design-system         # Full design system
/ui-ux-pro-max "fintech app" --domain=landing              # Landing page
/ui-ux-pro-max "luxury brand" --stack=nextjs               # Next.js
```

| Tham số | Mô tả | Mặc định |
|---------|-------|----------|
| `query` | Keywords mô tả sản phẩm/phong cách | Bắt buộc |
| `--design-system` | Tạo full design system | `false` |
| `--domain` | Lọc: style/chart/ux/typography/landing | `all` |
| `--stack` | Tech stack (html-tailwind, react, nextjs, vue, svelte, swiftui, react-native, flutter, shadcn, jetpack-compose) | `html-tailwind` |

#### Khi nào sử dụng

- Thiết kế giao diện mới (website, dashboard, landing page...)
- Cần color palette + typography phù hợp với domain
- Cần design tokens cho tech stack cụ thể
- Tham khảo best practices cho UI components

#### Khi nào KHÔNG sử dụng

- Backend logic, database design, API implementation

#### Kết quả đầu ra

- Design system document: `.mc-data/work/ui-ux-pro-max/design-system-[date].md`
- Bao gồm: color palette, typography, spacing, effects, code examples cho stack đã chọn

#### Lưu ý quan trọng

1. **Accessibility first** — contrast ≥ 4.5:1 (WCAG AA), touch targets ≥ 44×44px
2. **2-font pairing bắt buộc** — heading font ≠ body font
3. **Dark mode variant** — tự động tạo cho web projects
4. **Không dùng emojis làm icons** — sử dụng SVG icons (Heroicons, Lucide)
5. **Yêu cầu Python 3** — để chạy search scripts; fallback nếu không có

---

### 5.3. /wf-scan-target — Quét target standalone

**Phiên bản:** v2.0.0 | **Thời lượng:** 5–20 phút (tùy profile và target size)

#### Mô tả

Skill **standalone** (không thuộc main DEVKIT pipeline) — quét toàn bộ một target (module, hệ thống ERP, website, hoặc path source code) và trả về:

- `module-map.md` — bản đồ module: structure, APIs, screens, entities
- `target-map.json` — machine-readable metadata (v2 schema: scan_fingerprint, scan_diff, traceability, module_code_mapping, consumer_hints)
- `feature-inventory.md` — danh sách tính năng, CRUD ops, business rules
- `gap-report.md` — chỉ khi `--compare`, đánh dấu FOUND/MISSING/PARTIAL
- `phase-summary.md` — tóm tắt tiếng Việt (Protocol 14)

#### Khi nào dùng

- Muốn "quét module cũ" để hiểu cấu trúc trước khi tạo module mới
- Cần biết một module/hệ thống đang có những API, screens, entities nào
- Muốn so sánh module hiện tại với spec/yêu cầu mới
- Cần output dạng tài liệu để các workflow khác có thể consume qua `--from-scan`

#### Cách sử dụng

```bash
# Quét module local
/wf-scan-target --target=apps/backend/Eureka.Modules.CRM --module=crm

# Quét website
/wf-scan-target --target=https://example.com --module=dashboard

# So sánh với feature spec → tạo gap-report
/wf-scan-target --target=./old-project/src --compare=.mc-data/docs/phase2-features/crm/crm-feat.md

# Profile nhanh (smoke test, ~30s)
/wf-scan-target --target=apps/backend/Eureka.Modules.CRM --profile=quick

# Profile đầy đủ với LPM (15 validators, 20-30 features, ~30+ phút)
/wf-scan-target --target=apps/backend/Eureka.Modules.Finance --profile=exhaustive

# Delta scan: chỉ scan files thay đổi từ tag/commit
/wf-scan-target --target=. --module=crm --since=v1.5.0

# Resume / Status
/wf-scan-target --status            # Hiển thị 5 sessions gần nhất
/wf-scan-target --resume            # Tiếp tục session in_progress/paused gần nhất
```

#### Profiles

| Profile | scan_depth | MAX_PAGES (URL) | LPM | Use case |
|---------|-----------|-----------------|-----|----------|
| `quick` | shallow | 5 | — | Smoke test, ~30s |
| `standard` (default) | deep | 25 | — | Default scan, ~3-8 phút |
| `deep` | deep | 50 | — | Comprehensive scan, ~10-20 phút |
| `exhaustive` | deep | 100 | ✓ | Enterprise full coverage, ~30+ phút |

#### Tích hợp với skills khác (OPTIONAL — `--from-scan`)

| Consumer skill | Tác dụng |
|----------------|----------|
| `/wf-add-scope --from-scan=<session-id>` | Auto-seed modules + features từ `consumer_hints` + `module_code_mapping` |
| `/wf-define-features --from-scan=<session-id>` | Suggest features từ `feature-inventory.md` (không auto-import) |
| `/wf-design --from-scan=<session-id>` | Dùng làm gap-analysis baseline cho legacy design |
| `/wf-implement-feature` | Context priming khi implement |

#### Output Location

```
.mc-data/work/wf-scan-target/sessions/{YYYY-MM-DD}-{scope-label}[-{N}]/
├── module-map.md, target-map.json, feature-inventory.md
├── phase-summary.md (Protocol 14 — tiếng Việt)
├── gap-report.md (chỉ khi --compare)
├── scan-status.json, checkpoint.json
└── intermediate/ (tech-stack, l1-l4, synthesis, gap)
```

#### Lưu ý quan trọng

- **Standalone** — không cần prerequisites, có thể gọi bất kỳ lúc nào
- **Không tự update `req-registry.json`** — chỉ ghi vào working directory
- **Cache 24h** — fingerprint match → reuse kết quả; bypass bằng `--no-cache`
- **Hard cap 200** cho `--max-pages` (tránh DDoS / billing impact)
- **Delta scan** (`--since=<git-ref>`) yêu cầu target là local source trong git repo

---

### 5.4. /audit-agents — Kiểm tra agents

**Phiên bản:** v2.1.0 | **Thời lượng:** Quick

#### Mô tả

Kiểm tra agent definitions và knowledge files tuân thủ spec. Dùng cho DEVKIT development (không phải cho dự án người dùng).

#### Cách sử dụng

```bash
/audit-agents                    # Audit tất cả (mặc định --full)
/audit-agents architect          # Audit 1 agent cụ thể
/audit-agents --all              # Audit tất cả agents
/audit-agents --references       # Chỉ audit knowledge files
/audit-agents --full             # Agents + knowledge + cross-references
```

#### Khi nào sử dụng

- Sau khi thêm/sửa agent definitions
- Sau khi thêm/sửa knowledge files trong `.claude/references/`
- Cần verify tính nhất quán giữa agents ↔ knowledge ↔ procedures

#### Kết quả đầu ra

- Report: `docs/audit/reports/agent-audit-[date].md`

#### Lưu ý quan trọng

1. **10 tiêu chí per agent** (A1-A10) — frontmatter, identity, expertise, constraints...
2. **Chỉ report, KHÔNG auto-fix** — khác với `/audit-devkit`
3. **Song song hóa** — ≥3 agents → chạy batches 8-10 agents/batch

---

### 5.5. /audit-devkit — MCV3 self-audit orchestrator

**Phiên bản:** v3.1.0 | **Thời lượng:** 15-40 phút

#### Mô tả

MCV3 self-audit orchestrator — điều phối pipeline scan → verify → fix bằng cách lần lượt gọi 3 sub-skills: `/audit-devkit-scan`, `/audit-devkit-verify`, `/audit-devkit-fix`.

#### Cách sử dụng

```bash
/audit-devkit                    # Full pipeline: scan → verify → fix (mặc định)
/audit-devkit --no-fix           # Chỉ scan + verify, không fix
```

#### Khi nào sử dụng

- Trước khi release version mới của DEVKIT
- Sau khi thêm/sửa/xóa agents, skills, templates
- Phát hiện inconsistency giữa các components
- Muốn kiểm tra và tự động sửa chất lượng tổng thể

#### Chuỗi thực thi

```
Bước 1: /audit-devkit-scan   — Scan toàn bộ components, build ground truth index
Bước 2: /audit-devkit-verify — Cross-validate references, workflow integrity, consistency
Bước 3: /audit-devkit-fix    — Auto-fix issues với per-fix verification (nếu không dùng --no-fix)
```

#### Kết quả đầu ra

- Report: `docs/audit/reports/devkit-audit-[date].md`

#### Lưu ý quan trọng

1. **Orchestrator** — không tự làm gì, chỉ điều phối 3 sub-skills
2. **`--no-fix`** — chạy chỉ scan + verify, bỏ qua bước fix
3. **Verdict:** CRITICAL=0 → HEALTHY, 1-3 → NEEDS ATTENTION, >3 → BROKEN

---

### 5.6. /audit-devkit-scan — Scan DEVKIT components

**Phiên bản:** v1.1.0 | **Thời lượng:** 5-15 phút

#### Mô tả

Scan toàn bộ DEVKIT components theo batches, build ground truth index về agents, skills, rules, templates.

#### Cách sử dụng

```bash
/audit-devkit-scan
```

#### Khi nào sử dụng

- Khi cần kiểm tra tình trạng hiện tại của DEVKIT trước khi verify hoặc fix.
- Bước đầu tiên trong pipeline audit-devkit.

#### Kết quả đầu ra

- Ground truth index: `docs/audit/work/scan-index-[date].json`

---

### 5.7. /audit-devkit-verify — Cross-validate DEVKIT

**Phiên bản:** v1.1.0 | **Thời lượng:** 5-10 phút

#### Mô tả

Cross-validate references, workflow integrity, consistency giữa các components trong DEVKIT.

#### Cách sử dụng

```bash
/audit-devkit-verify
```

#### Khi nào sử dụng

- Sau `/audit-devkit-scan`, hoặc khi nghi ngờ có inconsistency.

#### Kết quả đầu ra

- Verify report: `docs/audit/work/verify-report-[date].md`

---

### 5.8. /audit-devkit-fix — Auto-fix DEVKIT issues

**Phiên bản:** v1.0.0 | **Thời lượng:** 5-15 phút

#### Mô tả

Tự động sửa các issues phát hiện bởi `/audit-devkit-scan` và `/audit-devkit-verify`, với per-fix verification.

#### Cách sử dụng

```bash
/audit-devkit-fix
```

#### Khi nào sử dụng

- Sau khi có kết quả từ `/audit-devkit-verify` và muốn auto-fix.

#### Lưu ý quan trọng

1. **Per-fix verification** — kiểm tra từng fix trước khi tiếp tục fix tiếp theo
2. **Report sau fix** — ghi lại những gì đã được sửa và kết quả

---

### 5.9. /audit-skill-output — Kiểm tra chất lượng output

**Phiên bản:** v1.6.0 | **Thời lượng:** Quick (1 skill) / Medium (--all)

#### Mô tả

Kiểm tra chất lượng output của một workflow skill đã chạy — so sánh kết quả thực tế với thiết kế trong SKILL.md theo 7 dimensions.

#### Cách sử dụng

```bash
/audit-skill-output wf-analyze-requirements       # Audit 1 skill
/audit-skill-output --all                          # Audit tất cả skills đã chạy
/audit-skill-output wf-design --no-fix             # Chỉ report, không sửa
/audit-skill-output wf-design --dimension=D1,D3    # Chỉ audit dimensions cụ thể
/audit-skill-output wf-design --verbose            # Chi tiết mọi check
/audit-skill-output --all --resume                 # Tiếp tục audit all
```

#### Khi nào sử dụng

- Vừa chạy xong 1 workflow skill, muốn kiểm tra output đúng không
- Nghi ngờ output chưa đạt chất lượng
- Trước khi chuyển sang phase tiếp theo

#### 7 Dimensions kiểm tra

| # | Dimension | Nội dung |
|---|-----------|----------|
| **D1** | File Existence | Files tồn tại, non-empty, đủ số lượng |
| **D2** | Template Compliance | Tuân thủ doc-framework templates |
| **D3** | Registry Schema | JSON valid, fields đúng type, safe-write |
| **D4** | Content Quality | Completeness, consistency (REQ-ID), traceability |
| **D5** | Cross-Phase | Counts khớp giữa phases, names consistent |
| **D6** | POST-GATE Re-execution | Chạy lại tất cả POST-GATE checks |
| **D7** | Status & Report | Status file / report đúng format |

#### Kết quả đầu ra

- Report: `.mc-data/work/audit-skill-output/audit-report-[skill]-[date].md`
- Status: `.mc-data/work/audit-skill-output/audit-skill-output-status.json`

#### Lưu ý quan trọng

1. **Auto-fix ON mặc định** — sửa structural issues trước khi audit semantic
2. **D4 và D5 chạy trong subagents riêng** — fresh context, tránh bias
3. **Verdict:** CRITICAL=0 → PASS; CRITICAL=0, MAJOR>0 → PASS_WITH_WARN; CRITICAL>0 → FAIL
4. **Skip logic** — một số dimensions tự skip cho skills cụ thể (ví dụ: D5 skip cho wf-brainstorm)

---

### 5.10. /wf-diagram — Sinh sơ đồ thiết kế UML + ERD

**Phiên bản:** v1.x (standalone) | **Thời lượng:** 5–20 phút (tùy module size)

#### Mô tả

Skill **standalone** (không thuộc main pipeline) — sinh sơ đồ thiết kế UML + ERD cho module/hệ thống từ source code có sẵn. Output: Mermaid `.md` (context, component, erd-context-map, actors, usecase, class, state, activity, sequence) + DBML `.dbml` (database tổng + ERD module).

#### Cách sử dụng

```bash
/wf-diagram --module=<name>                                  # Sinh diagrams cho module
/wf-diagram --module=crm --source-path=apps/backend/CRM      # Chỉ định source path
/wf-diagram --module=crm --output-path=./docs/diagrams        # Custom output path
/wf-diagram --module=crm --scope=full|module-only|system-only # Phạm vi sinh diagrams
/wf-diagram --resume                                          # Tiếp tục session dở
/wf-diagram --status                                          # Xem trạng thái
```

#### Quy tắc lọc nghiêm ngặt

- **Activity diagram** chỉ sinh khi flow ≥3 bước hoặc có nhánh
- **State diagram** chỉ sinh khi entity ≥3 trạng thái
- **Sequence diagram** chỉ sinh khi ≥3 components hoặc complex interaction

#### Đầu ra

- Diagrams ở `output_path/` (mặc định `./docs/diagrams/`)
- Session metadata ở `.mc-data/work/wf-diagram/sessions/{id}/`

#### Lưu ý quan trọng

1. **Standalone** — không thuộc main pipeline, gọi bất kỳ lúc nào
2. **Không update registry** — chỉ ghi vào output_path + working dir
3. **Yêu cầu source code có sẵn** trên target

---

## 6. Bảng Tra Cứu Nhanh

### Skills theo loại

| Loại | Skills | Số lượng |
|------|--------|----------|
| **Workflow (Standard)** | wf-brainstorm, wf-analyze-requirements, wf-define-features, wf-design, wf-design-ux, wf-plan-modules, wf-implement-feature, wf-preflight, wf-fix-bugs, wf-verify-sync, wf-prepare-deployment | 11 |
| **Workflow (Legacy)** | wf-legacy-scan, wf-legacy-classify, wf-legacy-extract, wf-annotate-code | 4 |
| **Workflow (Incremental)** | wf-add-scope, wf-manage-change | 2 |
| **Workflow (Spawned)** | wf-fix-triage, wf-fix-execute + **11 dimension lanes** wf-fix-functional (QD1), wf-fix-business (QD2), wf-fix-security (QD3), wf-fix-performance (QD4), wf-fix-ux-a11y (QD5), wf-fix-data (QD6), wf-fix-compat (QD7), wf-fix-observability (QD8), wf-fix-runtime-health (QD9), wf-fix-integration (QD10), wf-fix-business-completeness (QD11) *(tất cả spawned bởi wf-fix-bugs — entry point cho `--resume`)* | 13 |
| **Workflow (Standalone)** | wf-scan-target, wf-diagram | 2 |
| **Orchestrator** | new-project, existing-project, feature-addition | 3 |
| **Utility** | status, ui-ux-pro-max, audit-agents, audit-devkit, audit-devkit-scan, audit-devkit-verify, audit-devkit-fix, audit-skill-output | 8 |

> **Tổng cộng:** 11 + 4 + 2 + 13 + 2 + 3 + 8 = **43 lệnh** (32 wf-* + 3 orchestrator + 8 utility)

### Skills theo tính chất

| Tính chất | Skills |
|-----------|--------|
| **Read-only** (không tạo/sửa file) | status |
| **Quick** (1 session, nhanh) | wf-brainstorm, wf-preflight, wf-add-scope, status, audit-agents, audit-devkit-scan, audit-devkit-verify, audit-devkit-fix |
| **Multi-session** (có --resume) | wf-analyze-requirements, wf-define-features, wf-design, wf-design-ux, wf-plan-modules, wf-implement-feature, wf-fix-bugs, wf-fix-triage, wf-fix-execute, wf-manage-change, wf-legacy-scan, wf-legacy-classify, wf-legacy-extract, wf-annotate-code, wf-scan-target, wf-diagram, new-project, existing-project, feature-addition |
| **Conditional** (có thể skip) | wf-design-ux (api-only), wf-annotate-code (nếu không có annotation gaps) |
| **Auto-fix** | wf-preflight (--fix), wf-fix-bugs (via wf-fix-execute), audit-devkit, audit-skill-output |
| **Spawned** (không invoke trực tiếp ngoài --resume) | wf-fix-triage, wf-fix-execute, wf-fix-functional, wf-fix-business, wf-fix-security, wf-fix-performance, wf-fix-ux-a11y, wf-fix-data, wf-fix-compat, wf-fix-observability, wf-fix-runtime-health, wf-fix-integration, wf-fix-business-completeness |

### Registry Safe-Write — Ai update gì?

| Skill | Fields được phép update |
|-------|------------------------|
| `/wf-scan-target` | **KHÔNG update registry** (standalone — chỉ ghi vào working directory `.mc-data/work/wf-scan-target/`) |
| `/wf-brainstorm` | Khởi tạo cấu trúc |
| `/wf-analyze-requirements` | `requirements[]`, `systems[]`, `modules[]`, `departments[]` |
| `/wf-define-features` | `features[]` |
| `/wf-design` | `design_status` |
| `/wf-design-ux` | `ux_design_status` |
| `/wf-plan-modules` | `implementation_order` |
| `/wf-implement-feature` | `impl_status` (per REQ-ID) |
| `/wf-verify-sync` | `impl_status` (per REQ-ID, chỉ upgrade, KHÔNG downgrade) |
| `/wf-fix-bugs` | **KHÔNG update registry** (pure orchestrator — delegate hoàn toàn cho sub-skills) |
| 11 dimension lanes (wf-fix-functional/business/security/performance/ux-a11y/data/compat/observability/runtime-health/integration/business-completeness) *(spawned)* | **KHÔNG update registry** (probe-only — emit signals về `lanes/QD*/signals.json`) |
| `/wf-fix-triage` *(spawned)* | **KHÔNG update registry** (triage only — không sửa code) |
| `/wf-fix-execute` *(spawned)* | `impl_status` (per REQ-ID, safe-update — Phase 4a only) |
| `/wf-manage-change` | Phạm vi thay đổi — update docs + code + registry theo impact assessment |
| `/wf-add-scope` | `modules[]`, `features[]` (APPEND-ONLY — chỉ thêm entries mới) |

### "Tôi muốn..." → Dùng skill nào?

| Tôi muốn... | Skill |
|--------------|-------|
| Bắt đầu dự án mới từ ý tưởng | `/new-project` hoặc `/wf-brainstorm` |
| Đưa dự án có sẵn vào DEVKIT | `/existing-project` hoặc `/wf-legacy-scan` |
| Quét 1 module/hệ thống/URL để hiểu trước khi tạo mới | `/wf-scan-target` |
| So sánh module hiện tại với spec/yêu cầu | `/wf-scan-target --compare=<spec-path>` |
| Thêm tính năng vào dự án đã có | `/feature-addition` |
| Thêm modules mới vào registry | `/wf-add-scope` |
| Thay đổi/sửa tính năng đã có | `/wf-manage-change` |
| Xem tiến độ dự án | `/status` |
| Kiểm tra sức khỏe dự án | `/wf-preflight` |
| Sửa lỗi trong dự án | `/wf-fix-bugs` |
| Xử lý thay đổi tính năng | `/wf-manage-change` |
| Thêm scope vào registry | `/wf-add-scope` |
| Kiểm tra trước deployment | `/wf-verify-sync` |
| Thiết kế giao diện đẹp | `/ui-ux-pro-max` |
| Kiểm tra chất lượng output | `/audit-skill-output` |
| Audit DEVKIT (cho dev) | `/audit-devkit` |
| Scan DEVKIT components | `/audit-devkit-scan` |
| Cross-validate DEVKIT | `/audit-devkit-verify` |
| Auto-fix DEVKIT issues | `/audit-devkit-fix` |

---

## 7. Thuật Ngữ

| Thuật ngữ | Ý nghĩa |
|-----------|----------|
| **REQ-ID** | Mã yêu cầu: `REQ-[DEPT]-[NNN]` (VD: `REQ-FIN-001`) |
| **FEAT-ID** | Mã tính năng: `FEAT-[SYS]-[MOD]-NNN` (VD: `FEAT-CRM-CUST-001`) |
| **UI-ID** | Mã UI component: `UI-[SYS]-[MOD]-[SCREEN]-NNN` |
| **Registry** | File `req-registry.json` — nguồn chân lý duy nhất |
| **PRE-GATE** | Kiểm tra điều kiện trước khi chạy skill |
| **POST-GATE** | Kiểm tra chất lượng output sau khi chạy skill |
| **Safe-Write** | Protocol đảm bảo mỗi skill chỉ update fields được phân công |
| **SSOT** | Single Source of Truth — nguồn chân lý duy nhất |
| **impl_status** | Trạng thái triển khai: `not_started` / `in_progress` / `done` / `skipped` |
| **Sync Rate** | Tỷ lệ REQ-IDs đã implement (status="done") có code |
| **Coverage Rate** | Tỷ lệ REQ-IDs có code (bao gồm cả in_progress) |
| **W001 Anomaly** | Warning khi status="done" nhưng không tìm thấy code |
| **Orphan Code** | Code không có REQ-ID comment |
| **LPM** | Large Project Mode — tự kích hoạt khi dự án lớn |
| **TDD** | Test-Driven Development — viết test trước, code sau |
| **Agent** | AI chuyên gia ảo, đảm nhận vai trò cụ thể |
| **Checkpoint** | Điểm lưu trạng thái để resume trong phiên tiếp theo |
| **Auto-correction** | Tự sửa lỗi output (tối đa 3 lần) |
| **cross_module_dependencies** | Mảng khai báo quan hệ consumer→provider giữa các modules (dùng bởi QD10) |
| **binding_type** | Cơ chế liên kết cross-module: `foreign_key`, `api`, `event`, `denormalized_copy` |
| **QD9** | Runtime Health Verification — lane kiểm tra browser console errors, network failures |
| **QD10** | Cross-Module Integration — lane kiểm tra tính nhất quán dữ liệu giữa các modules |

---

## 8. Cross-Module Dependencies

> **Phiên bản:** v1.1 (2026-05-10) — Schema bump từ wf-fix-bugs v9 — QD10 Cross-Module Integration analysis.

### 8.1. Khái niệm

`cross_module_dependencies[]` là một mảng tùy chọn trong `req-registry.json` khai báo **quan hệ phụ thuộc dữ liệu** giữa các modules. Đây là nền tảng cho lane **QD10** phân tích tính nhất quán cross-module khi chạy `/wf-fix-bugs`.

**Ví dụ thực tế:** Module `MOD-QUOTATION` sử dụng entity `Customer` từ `MOD-CRM`. Nếu schema Customer thay đổi, QD10 sẽ phát hiện drift và cảnh báo.

### 8.2. Schema fields

| Field | Kiểu | Bắt buộc | Mô tả |
|-------|------|----------|-------|
| `id` | string | ✅ | ID duy nhất, pattern `^DEP-` (e.g. `DEP-CRM-QUO-001`) |
| `consumer_module` | string | ✅ | Module tiêu thụ (e.g. `MOD-QUOTATION`) |
| `provider_module` | string | ✅ | Module cung cấp (e.g. `MOD-CRM`) |
| `entity` | string | ✅ | Tên entity được chia sẻ (e.g. `Customer`) |
| `binding_type` | enum | ✅ | `foreign_key` \| `api` \| `event` \| `denormalized_copy` |
| `required_fields` | string[] | — | Fields bắt buộc consumer phải tiêu thụ |
| `optional_fields` | string[] | — | Fields tùy chọn consumer có thể dùng |
| `lifecycle_rules.on_provider_delete` | string | — | Hành động khi provider entity bị xóa |
| `lifecycle_rules.on_provider_update` | string | — | Hành động khi provider entity được cập nhật |
| `events_subscribed` | string[] | — | Event names (khi `binding_type=event`) |
| `consumer_features` | string[] | — | FEAT-IDs trong consumer module dùng dependency |
| `notes` | string | — | Ghi chú thêm |

### 8.3. Ví dụ khai báo

```json
"cross_module_dependencies": [
  {
    "id": "DEP-CRM-QUO-001",
    "consumer_module": "MOD-QUOTATION",
    "provider_module": "MOD-CRM",
    "entity": "Customer",
    "binding_type": "foreign_key",
    "required_fields": ["id", "name", "contact_email", "address"],
    "optional_fields": ["loyalty_tier", "credit_limit"],
    "lifecycle_rules": {
      "on_provider_delete": "restrict",
      "on_provider_update": "sync_immediately"
    },
    "consumer_features": ["FEAT-QUO-QUOTE-001", "FEAT-QUO-QUOTE-002"],
    "notes": "Quotation cần Customer.address để điền địa chỉ giao hàng"
  },
  {
    "id": "DEP-ORD-CRM-001",
    "consumer_module": "MOD-ORDERS",
    "provider_module": "MOD-CRM",
    "entity": "Customer",
    "binding_type": "api",
    "required_fields": ["id", "name"],
    "events_subscribed": ["customer.loyalty_tier_changed"]
  }
]
```

### 8.4. binding_type giải thích

| Loại | Mô tả | Khi dùng |
|------|-------|----------|
| `foreign_key` | Consumer có FK trong DB trỏ tới provider entity | DB có JOIN giữa 2 module tables |
| `api` | Consumer gọi REST/GraphQL API của provider | Data fetch qua HTTP mỗi request |
| `event` | Consumer subscribe event từ provider | Event-driven architecture |
| `denormalized_copy` | Consumer copy data từ provider vào local store | Performance optimization |

### 8.5. Cách dùng với /wf-fix-bugs

Sau khi khai báo `cross_module_dependencies[]`:

```bash
# Phân tích cross-module pair cụ thể
/wf-fix-bugs --dims=QD10 --scope=cross-module-pair --pair=MOD-CRM-MOD-QUOTATION

# Chạy full integration analysis
/wf-fix-bugs --dims=QD10 --scope=module --name=MOD-QUOTATION

# Chạy kèm runtime health
/wf-fix-bugs --dims=QD9,QD10 --scope=module --name=MOD-QUOTATION
```

### 8.6. Lưu ý Safe-Write

`cross_module_dependencies[]` là field **không thuộc bất kỳ skill hiện có nào** — phải được author thủ công bởi developer/BA. Sau này có thể dùng script `wf-detect-cross-module-deps.sh` để generate suggestions.

Schema validate: `.claude/schemas/req-registry-schema.json` (v1.1 — thêm trường này).
| **Stakeholder review** | Đánh giá chéo bởi nhiều agents từ góc nhìn khác nhau |
