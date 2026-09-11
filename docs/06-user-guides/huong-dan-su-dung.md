# Hướng Dẫn Sử Dụng MCV3 (DEVKIT)

> Hướng dẫn đầy đủ quy trình sử dụng DEVKIT — từ ý tưởng đến sản phẩm hoàn chỉnh.

---

## Mục Lục

- [Giới Thiệu](#giới-thiệu)
- [Yêu Cầu Hệ Thống](#yêu-cầu-hệ-thống)
- [Phần A — Dự Án Mới (Standard Path)](#phần-a--dự-án-mới-standard-path)
  - [Bước 1: Brainstorm — Chốt khung dự án](#bước-1-brainstorm--chốt-khung-dự-án-phase-0)
  - [Bước 2: Phân tích yêu cầu nghiệp vụ](#bước-2-phân-tích-yêu-cầu-nghiệp-vụ-phase-1)
  - [Bước 3: Định nghĩa tính năng](#bước-3-định-nghĩa-tính-năng-phase-2)
  - [Bước 4: Thiết kế kiến trúc](#bước-4-thiết-kế-kiến-trúc-phase-3)
  - [Bước 5: Thiết kế UX/UI](#bước-5-thiết-kế-uxui-phase-4)
  - [Bước 6: Lập kế hoạch triển khai](#bước-6-lập-kế-hoạch-triển-khai-phase-5a)
  - [Bước 7: Implement code](#bước-7-implement-code-phase-5b)
  - [Bước 8: Kiểm tra toàn diện](#bước-8-kiểm-tra-toàn-diện-preflight)
  - [Bước 9: Sửa lỗi](#bước-9-sửa-lỗi-fix-bugs)
  - [Debug Nâng Cao với QD9 + QD10](#debug-nâng-cao-với-qd9--qd10)
  - [Bước 10: Xác minh đồng bộ](#bước-10-xác-minh-đồng-bộ-verify-sync)
  - [Bước 11: Tài liệu triển khai](#bước-11-tài-liệu-triển-khai-phase-6)
- [Phần B — Dự Án Có Sẵn (Existing Path)](#phần-b--dự-án-có-sẵn-existing-path)
  - [Bước 1: Quét toàn diện dự án (all-in-one)](#bước-1-quét-toàn-diện-dự-án-legacy-scan--all-in-one)
  - [Bước 1b: Phân loại files (standalone)](#bước-1b-phân-loại-files-standalone--chỉ-khi-cần)
  - [Bước 1c: Trích xuất requirements (standalone)](#bước-1c-trích-xuất-requirements-standalone--chỉ-khi-cần)
  - [Bước 2: Tiếp tục với Shared Skills (Legacy Mode)](#bước-2-tiếp-tục-với-shared-skills-legacy-mode)
  - [Bước 2.5: Inject REQ-ID vào code](#bước-25-inject-req-id-vào-code-annotate-code)
  - [Bước 3: Tiếp tục với Standard Path](#bước-3-tiếp-tục-với-standard-path)
- [Phần C — Dự Án Hybrid (Docs sẵn + Code đang phát triển)](#phần-c--dự-án-hybrid-docs-sẵn--code-đang-phát-triển)
  - [Khi nào dùng Phần C?](#khi-nào-dùng-phần-c)
  - [Bước 1: Đánh giá mức độ hoàn thiện của code](#bước-1-đánh-giá-mức-độ-hoàn-thiện-của-code)
  - [Bước 2: Lập kế hoạch triển khai](#bước-2-lập-kế-hoạch-triển-khai-wf-plan-modules)
  - [Bước 3: Đồng bộ impl_status về thực tế](#bước-3-đồng-bộ-impl_status-về-thực-tế)
  - [Bước 4: Kiểm tra toàn diện](#bước-4-kiểm-tra-toàn-diện-wf-preflight)
  - [Bước 5: Sửa lỗi phát hiện](#bước-5-sửa-lỗi-phát-hiện-wf-fix-bugs)
  - [Bước 6: Implement phần còn thiếu](#bước-6-implement-phần-còn-thiếu-wf-implement-feature)
  - [Bước 7: Xác minh đồng bộ và triển khai](#bước-7-xác-minh-đồng-bộ-và-triển-khai)
- [Orchestrator — Chạy Tự Động](#orchestrator--chạy-tự-động)
- [Công Cụ Hỗ Trợ](#công-cụ-hỗ-trợ)
- [Xử Lý Sự Cố Chung](#xử-lý-sự-cố-chung)
- [Phụ Lục](#phụ-lục)

---

## Giới Thiệu

DEVKIT (MCV3) là bộ công cụ chạy trên **Claude Code**, giúp người dùng biến ý tưởng thành phần mềm hoàn chỉnh thông qua đội ngũ 62 AI agents chuyên biệt.

DEVKIT hỗ trợ 2 luồng chính:

| Luồng                  | Đối tượng    | Mô tả                                                             |
| ----------------------- | ---------------- | ------------------------------------------------------------------- |
| **Standard Path** | Dự án mới     | Bắt đầu từ ý tưởng, đi qua 7 phases (0–6)                  |
| **Existing Path** | Dự án có sẵn | Quét code hiện có, tạo tài liệu, rồi tiếp tục phát triển |

**Sơ đồ tổng quan:**

```
DỰ ÁN MỚI (Standard Path):
  Ý tưởng
    → /wf-brainstorm            (Phase 0 — Chốt khung)
    → /wf-analyze-requirements  (Phase 1 — Phân tích nghiệp vụ)
    → /wf-define-features       (Phase 2 — Định nghĩa tính năng)
    → /wf-design                (Phase 3 — Thiết kế kỹ thuật)
    → /wf-design-ux             (Phase 4 — Thiết kế UX, nếu có UI)
    → /wf-plan-modules          (Phase 5a — Lập kế hoạch)
    → /wf-implement-feature     (Phase 5b — Viết code)
    → /wf-preflight             (Kiểm tra toàn diện)
    → /wf-fix-bugs              (Sửa lỗi, nếu cần)
    → /wf-verify-sync           (Xác minh đồng bộ)
    → /wf-prepare-deployment    (Phase 6 — Tài liệu triển khai)

DỰ ÁN CÓ SẴN (Existing Path):
  Code hiện có
    → /wf-legacy-scan           (All-in-one: detect → classify → extract → synthesize)
    → /wf-brainstorm*           (Chốt khung — detect legacy, tự chạy flow-legacy)
    → /wf-analyze-requirements* (Phân tích nghiệp vụ — legacy mode)
    → /wf-define-features*      (Định nghĩa features — legacy mode)
    → /wf-design*               (Thiết kế kỹ thuật + gap analysis — legacy mode)
    → /wf-annotate-code         (Inject REQ-ID, nếu có annotation gaps)
    → /wf-design-ux*            (Thiết kế UX — legacy mode, nếu có UI)
    → (tiếp tục Standard Path từ /wf-plan-modules)

  * = shared skills tự detect legacy mode (CORE-021) và inject context

DỰ ÁN HYBRID (Docs Phase 0–4 sẵn + Code đang phát triển song song):
  Docs đã có (Phase 0–4), code chưa được tracking trong DEVKIT
    → [Đánh giá mức độ hoàn thiện của code]   (thủ công)
    → /wf-plan-modules                         (Tạo Phase 5 roadmap — bắt buộc)
    → [Đồng bộ impl_status]                    (cập nhật registry theo thực tế)
    → /wf-preflight                            (Kiểm tra toàn diện — phát hiện lỗi & thiếu sót)
    → /wf-fix-bugs                             (Sửa lỗi phát hiện, nếu cần)
    → /wf-implement-feature                    (Implement phần còn thiếu, nếu cần)
    → /wf-verify-sync                          (Xác minh đồng bộ)
    → /wf-prepare-deployment                   (Phase 6 — Tài liệu triển khai)
```

---

## Yêu Cầu Hệ Thống

| Yêu cầu                   | Chi tiết                                                      |
| --------------------------- | -------------------------------------------------------------- |
| **Nền tảng**        | Claude Code (CLI hoặc IDE extension)                          |
| **Model**             | Claude Opus 4.6 (khuyến nghị) hoặc Sonnet 4.6               |
| **DEVKIT**            | Clone repo MCV3 vào thư mục làm việc                      |
| **Thư mục dự án** | Tạo thư mục dự án riêng, copy `.claude/` từ MCV3 vào |

**Cách cài đặt:**

```bash
# 1. Clone DEVKIT
git clone <mcv3-repo-url> MCV3

# 2. Tạo thư mục dự án mới
mkdir my-project && cd my-project

# 3. Copy DEVKIT vào dự án
cp -r ../MCV3/.claude .
cp ../MCV3/CLAUDE.md .

# 4. Mở Claude Code trong thư mục dự án
claude  # hoặc mở VS Code với Claude Code extension
```

---

## Phần A — Dự Án Mới (Standard Path)

> **QUY TẮC QUAN TRỌNG:** Không được bỏ qua bất kỳ bước nào. Mỗi bước chỉ chạy được khi bước trước đã hoàn thành.

### Bước 1: Brainstorm — Chốt Khung Dự Án (Phase 0)

**Mục đích:** Làm rõ ý tưởng, xác định phạm vi dự án, phòng ban, độ phức tạp.

**Cách chạy:**

```
/wf-brainstorm
```

Hoặc với tên dự án:

```
/wf-brainstorm my-erp-system
```

**Quá trình:**

1. DEVKIT sẽ hỏi bạn 15–20 câu hỏi về doanh nghiệp, lĩnh vực, quy mô
2. Bạn trả lời bằng ngôn ngữ tự nhiên (tiếng Việt hoặc tiếng Anh)
3. DEVKIT phân tích và tạo tài liệu brainstorm

**Kết quả tạo ra:**

```
.mc-data/
├── docs/phase0-brainstorm/
│   ├── P0-01-brainstorm.md          ← Thông tin tổ chức, phòng ban, phạm vi
│   ├── P0-02-systems-users.md       ← Bản đồ hệ thống, người dùng, NFR
│   └── policies/                    ← Chính sách domain (nếu có)
│       └── [tên-chính-sách].md
└── work/wf-brainstorm/
    └── brainstorm-notes.md          ← Ghi chú làm việc
```

**Kiểm tra sau bước 1:**

Những điểm cần xác nhận:

- [ ] File `P0-01-brainstorm.md` tồn tại và có nội dung
- [ ] File `P0-02-systems-users.md` tồn tại và có nội dung
- [ ] Các phòng ban được liệt kê đầy đủ
- [ ] Phạm vi dự án phù hợp với ý tưởng ban đầu

**Kiểm tra bằng AI (có thể chạy nhiều lần):**

```
/audit-skill-output wf-brainstorm
```

> Có thể chạy lại nhiều lần để tăng độ chính xác. Mặc định tự động sửa lỗi; thêm `--no-fix` nếu chỉ muốn xem báo cáo mà không sửa.

Lệnh này kiểm tra 7 chiều: D1 (files tồn tại và có nội dung), D2 (cấu trúc đúng template), D3 (registry nhất quán), D4 (chất lượng nội dung), D5 (nhất quán liên phase), D6 (POST-GATE validation), D7 (error tracking).

**Xử lý sự cố:**

| Vấn đề                    | Nguyên nhân                   | Cách xử lý                                             |
| ---------------------------- | ------------------------------- | --------------------------------------------------------- |
| DEVKIT không hỏi câu hỏi | Session bị mất context        | Chạy lại `/wf-brainstorm`                             |
| Tài liệu thiếu phòng ban | Thông tin cung cấp chưa đủ | Chạy lại và cung cấp thêm chi tiết                  |
| File không được tạo     | Lỗi ghi file                   | Kiểm tra quyền ghi thư mục, chạy lại                |
| Nội dung bằng tiếng Anh   | Lỗi format                     | Kết quả phải bằng tiếng Việt — chạy lại nếu sai |

---

### Bước 2: Phân Tích Yêu Cầu Nghiệp Vụ (Phase 1)

**Mục đích:** Huy động đội ngũ chuyên gia AI phân tích chi tiết yêu cầu theo từng phòng ban.

**Điều kiện:** Phase 0 (Brainstorm) đã hoàn thành.

**Cách chạy:**

```
/wf-analyze-requirements
```

Các tùy chọn:

```
/wf-analyze-requirements scope=all           # Phân tích tất cả phòng ban (mặc định)
/wf-analyze-requirements scope=business      # Chỉ phân tích nhóm business
/wf-analyze-requirements scope=sales         # Chỉ 1 module cụ thể
/wf-analyze-requirements --resume            # Tiếp tục từ checkpoint
/wf-analyze-requirements --status            # Xem tiến độ hiện tại
```

**Quá trình:**

1. Đọc và validate Phase 0 output
2. Xác định scope và danh sách phòng ban
3. Lập kế hoạch phân công chuyên gia (VD: phòng ban Sales → sales-expert)
4. Business Analyst tạo Part A cho từng phòng ban (SONG SONG)
5. Chuyên gia domain tạo Part B chi tiết (TUẦN TỰ theo loại, SONG SONG giữa phòng ban)
6. Cross-validation và cập nhật registry

**Kết quả tạo ra:**

```
.mc-data/
├── docs/
│   ├── _meta/
│   │   └── req-registry.json        ← ★ SSOT — chứa tất cả REQ-IDs
│   └── phase1-business/
│       ├── departments/
│       │   ├── sales/sales.md       ← Part A (BA) + Part B (Expert)
│       │   ├── finance/finance.md
│       │   └── ...
│       └── stakeholder-review.md    ← Báo cáo tổng hợp
└── work/wf-analyze-requirements/
    ├── analyze-plan.md              ← Kế hoạch phân tích
    └── analyze-report.md            ← Báo cáo kết quả
```

**Kiểm tra sau bước 2:**

Những điểm cần xác nhận:

- [ ] `req-registry.json` có `requirements[]` với ít nhất 1 REQ-ID
- [ ] Mỗi phòng ban có file `.md` với cả Part A và Part B
- [ ] REQ-IDs theo đúng format: `REQ-[DEPT]-[NNN]`
- [ ] `stakeholder-review.md` tồn tại

**Kiểm tra bằng AI (có thể chạy nhiều lần):**

```
/audit-skill-output wf-analyze-requirements
```

> Có thể chạy lại nhiều lần để tăng độ chính xác. Mặc định tự động sửa lỗi; thêm `--no-fix` nếu chỉ muốn xem báo cáo mà không sửa.

**Xử lý sự cố:**

| Vấn đề            | Nguyên nhân              | Cách xử lý                                               |
| -------------------- | -------------------------- | ----------------------------------------------------------- |
| "Phase 0 not found"  | Chưa chạy brainstorm     | Quay lại Bước 1                                          |
| Agent bị timeout    | Dự án quá lớn          | Dùng `--resume` để tiếp tục                          |
| Thiếu phòng ban    | Scope bị giới hạn       | Chạy lại với `scope=all`                               |
| Registry rỗng       | Lỗi ghi file              | Kiểm tra `.mc-data/docs/_meta/` tồn tại, chạy lại    |
| Phân tích bị lặp | Heavy Department Detection | DEVKIT tự động chia phòng ban lớn, không cần xử lý |

> **Lưu ý Large Project Mode:** Khi dự án có >= 5 systems, >= 10 phòng ban, >= 50 requirements, hoặc >= 40 features, DEVKIT tự động kích hoạt chế độ dự án lớn (LPM) — giảm số agent chạy song song, tăng checkpoint.

---

### Bước 3: Định Nghĩa Tính Năng (Phase 2)

**Mục đích:** Chuyển requirements (REQ-IDs) thành feature specifications chi tiết với FEAT-IDs.

**Điều kiện:** Phase 1 đã hoàn thành, registry có `requirements[]`.

**Cách chạy:**

```
/wf-define-features
```

Các tùy chọn:

```
/wf-define-features scope=all              # Tất cả (mặc định)
/wf-define-features scope=crm-system       # Chỉ 1 system
/wf-define-features scope=customer-module  # Chỉ 1 module
/wf-define-features --resume               # Tiếp tục từ checkpoint
```

**Quá trình:**

1. Đọc và validate registry (requirements phải có)
2. Map REQ-IDs → FEAT-IDs (format: `FEAT-[SYS]-[MOD]-NNN`)
3. Business Analyst tạo feature specs cho từng module (SONG SONG)
4. Cross-validation (tự động sửa, tối đa 3 vòng)

**Kết quả tạo ra:**

```
.mc-data/docs/phase2-features/
├── [system-name]/
│   └── [module-name]/
│       ├── quan-ly-khach-hang.md     ← 1 feature = 1 file
│       ├── bao-cao-doanh-thu.md
│       └── ...
└── stakeholder-review.md
```

**Kiểm tra sau bước 3:**

Những điểm cần xác nhận:

- [ ] `req-registry.json` có `features[]` đầy đủ
- [ ] Mỗi feature có file riêng trong `phase2-features/[sys]/[mod]/`
- [ ] FEAT-IDs theo format `FEAT-[SYS]-[MOD]-NNN`
- [ ] Mỗi feature file có: User Stories, Business Rules, Permissions
- [ ] `stakeholder-review.md` tồn tại

**Kiểm tra bằng AI (có thể chạy nhiều lần):**

```
/audit-skill-output wf-define-features
```

> Có thể chạy lại nhiều lần để tăng độ chính xác. Mặc định tự động sửa lỗi; thêm `--no-fix` nếu chỉ muốn xem báo cáo mà không sửa.

**Xử lý sự cố:**

| Vấn đề                 | Nguyên nhân                | Cách xử lý                                 |
| ------------------------- | ---------------------------- | --------------------------------------------- |
| "No requirements found"   | Registry thiếu requirements | Quay lại Bước 2                            |
| Feature file rỗng        | Agent bị lỗi               | Xóa file rỗng, chạy lại với `--resume` |
| FEAT-ID trùng lặp       | Lỗi numbering               | DEVKIT tự động sửa trong cross-validation |
| Cross-validation loop > 3 | Nhiều lỗi                  | Kiểm tra output, chạy lại skill            |

---

### Bước 4: Thiết Kế Kiến Trúc (Phase 3)

**Mục đích:** Tạo tài liệu thiết kế kỹ thuật — kiến trúc, API, database, infrastructure.

**Điều kiện:** Phase 2 đã hoàn thành, registry có `features[]`.

**Cách chạy:**

```
/wf-design
```

**Quá trình:**

1. Đọc registry + feature specs
2. Xác định approach (Module / System / Platform Design)
3. Architect agent tạo kiến trúc tổng thể (P3-01-architecture.md)
4. Các chuyên gia tạo tài liệu chi tiết (SONG SONG):
   - API contract (architect / ai-engineer)
   - Database design (dba / data-engineer)
   - Infra spec (devops)
5. Integration rules (TUẦN TỰ sau API + DB)
6. Stakeholder Review

**Approach tự động lựa chọn:**

| Hệ thống | Module   | Approach        |
| ---------- | -------- | --------------- |
| 1          | 1–2     | Module Design   |
| 1          | > 2      | System Design   |
| > 1        | bất kỳ | Platform Design |

**Kết quả tạo ra:**

```
.mc-data/docs/phase3-architecture/
├── P3-01-architecture.md              ← Kiến trúc tổng thể
├── technical-specs/
│   ├── api-contract.md                ← API endpoints, request/response
│   ├── database-design.md             ← ERD, schema, indexes
│   └── infra-spec.md                  ← Infrastructure & deployment
├── integration-rules.md               ← Quy tắc tích hợp giữa modules
└── stakeholder-review.md
```

**Kiểm tra sau bước 4:**

Những điểm cần xác nhận:

- [ ] `P3-01-architecture.md` có 7 sections bắt buộc (Decisions, Diagrams, Subsystems, Data Ownership, Integration, Conventions, Environments)
- [ ] `api-contract.md` có endpoints cho tất cả features
- [ ] `database-design.md` có schema/ERD
- [ ] `infra-spec.md` mô tả deployment strategy
- [ ] Registry `design_status` đã cập nhật

**Kiểm tra bằng AI (có thể chạy nhiều lần):**

```
/audit-skill-output wf-design
```

> Có thể chạy lại nhiều lần để tăng độ chính xác. Mặc định tự động sửa lỗi; thêm `--no-fix` nếu chỉ muốn xem báo cáo mà không sửa.

**Xử lý sự cố:**

| Vấn đề                     | Nguyên nhân                | Cách xử lý                               |
| ----------------------------- | ---------------------------- | ------------------------------------------- |
| "No features found"           | Registry thiếu features     | Quay lại Bước 3                          |
| Thiếu API spec               | Feature không có endpoints | Kiểm tra feature specs, bổ sung nếu cần |
| Architecture không phù hợp | DEVKIT chọn sai approach    | Cung cấp thêm context về hệ thống      |
| Design module ngoài registry | Vi phạm CORE rule           | Không xảy ra — DEVKIT tự chặn          |

---

### Bước 5: Thiết Kế UX/UI (Phase 4)

**Mục đích:** Tạo design system, navigation, và màn hình cho tất cả hệ thống có giao diện.

**Điều kiện:** Phase 3 đã hoàn thành. **Chỉ chạy khi dự án có giao diện web/mobile.**

> Nếu dự án là API-only (không có giao diện), DEVKIT tự động skip bước này và tạo placeholder file.

**Cách chạy:**

```
/wf-design-ux
```

**Quá trình:**

1. Kiểm tra `interface_type` — nếu "api-only" thì EXIT
2. UX Designer tạo Design System (màu sắc, typography, components)
3. Navigation cho từng system (TUẦN TỰ)
4. Screen Groups cho từng module (TUẦN TỰ)
5. Cross-validation
6. Stakeholder Review (UX Designer + Architect, SONG SONG)

**Kết quả tạo ra:**

```
.mc-data/docs/phase4-ux/
├── design-system.md                    ← Màu sắc, typography, components, patterns
├── [system-name]/
│   ├── Navigation-[system].md          ← Cấu trúc điều hướng
│   └── [module-name]/
│       └── [screen-group].md           ← Màn hình theo nhóm
└── stakeholder-review.md
```

**Kiểm tra sau bước 5:**

Những điểm cần xác nhận:

- [ ] `design-system.md` có 6 sections (colors, typography, spacing, components, patterns, icons)
- [ ] Mỗi system có `Navigation-[sys].md`
- [ ] Mỗi module có ít nhất 1 screen group file
- [ ] `stakeholder-review.md` tồn tại

**Kiểm tra bằng AI (có thể chạy nhiều lần):**

```
/audit-skill-output wf-design-ux
```

> Có thể chạy lại nhiều lần để tăng độ chính xác. Mặc định tự động sửa lỗi; thêm `--no-fix` nếu chỉ muốn xem báo cáo mà không sửa.

**Xử lý sự cố:**

| Vấn đề                           | Nguyên nhân                 | Cách xử lý                                          |
| ----------------------------------- | ----------------------------- | ------------------------------------------------------ |
| "API-only — skipping"              | Dự án không có UI         | Đúng, đây là hành vi bình thường              |
| Thiếu screen groups                | Module có ít tính năng UI | Kiểm tra feature specs — bổ sung UI flows nếu cần |
| Design system không có components | Kết quả chưa đầy đủ    | Chạy lại `/wf-design-ux`                           |

---

### Bước 6: Lập Kế Hoạch Triển Khai (Phase 5a)

**Mục đích:** Phân tích dependencies, tạo roadmap và sprint plans trước khi code.

**Điều kiện:** Phase 3 (và Phase 4 nếu có UI) đã hoàn thành.

**Cách chạy:**

```
/wf-plan-modules
```

Các tùy chọn:

```
/wf-plan-modules --graph        # Chỉ xem dependency graph
/wf-plan-modules --mvp          # Xác định phạm vi MVP
/wf-plan-modules --impact=auth  # Phân tích tác động của module auth
/wf-plan-modules --skip-sprints # Bỏ qua sprint plans
```

**Quá trình:**

1. Đọc registry + design docs
2. Phân tích dependency giữa các modules
3. Topological sort — xác định thứ tự implement
4. Nhóm features theo sprints
5. Tạo task files cho từng feature
6. Stakeholder Review (architect + qa-lead, SONG SONG)

**Execution mode tự động:**

| Số modules | Mode   | Sprint       |
| ----------- | ------ | ------------ |
| 1           | Simple | 1 sprint     |
| 2           | Lite   | 1–2 sprints |
| >= 3        | Full   | Multi-sprint |

**Kết quả tạo ra:**

```
.mc-data/docs/phase5-implementation/
├── P5-00-implementation-roadmap.md     ← Roadmap tổng thể
├── module-plan.md                      ← Dependency analysis
├── dependency-graph.md                 ← Sơ đồ dependencies (ASCII)
├── sprints/
│   ├── sprint-01.md                    ← Chi tiết sprint 1
│   ├── sprint-02.md
│   └── ...
├── tasks/
│   └── [system]/[module]/
│       └── [feature]-impl.md           ← Task file cho từng feature
└── stakeholder-review.md
```

**Kiểm tra sau bước 6:**

Những điểm cần xác nhận:

- [ ] `P5-00-implementation-roadmap.md` có thứ tự implement rõ ràng
- [ ] `dependency-graph.md` có sơ đồ
- [ ] Task files tồn tại cho mỗi feature
- [ ] Registry có `implementation_order[]`
- [ ] Sprint plans có danh sách features theo thứ tự ưu tiên

**Kiểm tra bằng AI (có thể chạy nhiều lần):**

```
/audit-skill-output wf-plan-modules
```

> Có thể chạy lại nhiều lần để tăng độ chính xác. Mặc định tự động sửa lỗi; thêm `--no-fix` nếu chỉ muốn xem báo cáo mà không sửa.

**Xử lý sự cố:**

| Vấn đề                | Nguyên nhân             | Cách xử lý                                           |
| ------------------------ | ------------------------- | ------------------------------------------------------- |
| Circular dependency      | Modules phụ thuộc vòng | DEVKIT cảnh báo — bạn cần quyết định cắt vòng |
| Thiếu task files        | Module chưa có features | Quay lại Bước 3 bổ sung                             |
| "No modules in registry" | Registry thiếu data      | Kiểm tra Bước 2 + 3 đã hoàn thành                |

---

### Bước 7: Implement Code (Phase 5b)

**Mục đích:** Viết code cho từng feature theo TDD, với code review và security review.

**Điều kiện:** Phase 5a (Plan Modules) đã hoàn thành.

**Cách chạy:**

```
/wf-implement-feature customer-management
```

Hoặc bằng REQ-ID:

```
/wf-implement-feature REQ-CRM-001
```

Các tùy chọn:

```
/wf-implement-feature [tên] --extend      # Mở rộng feature có sẵn
/wf-implement-feature [tên] --modify      # Sửa đổi feature có sẵn
/wf-implement-feature [tên] --skip-tests  # Bỏ qua test (không khuyến nghị)
/wf-implement-feature [tên] --skip-review # Bỏ qua review (chỉ hotfix)
/wf-implement-feature [tên] --resume      # Tiếp tục từ checkpoint
/wf-implement-feature --status            # Xem tiến độ
```

**Quá trình:**

1. Đọc task file + design docs cho feature
2. Tạo implementation plan
3. Developer agents viết code (SONG SONG theo module)
4. Code Review + Security Review (SONG SONG)
5. Tự động sửa lỗi (tối đa 3 vòng)
6. Cập nhật registry `impl_status = "done"`

**Kết quả tạo ra:**

- Source code files (trong `src/` hoặc `apps/`)
- Test files
- Registry cập nhật `impl_status`
- Working files: `impl-plan.md`, `impl-report.md`

> **QUAN TRỌNG:** Chạy `/wf-implement-feature` cho **từng feature** theo thứ tự trong roadmap. Không chạy tất cả cùng lúc.

**Kiểm tra sau mỗi feature:**

Những điểm cần xác nhận:

- [ ] Source code files được tạo đúng vị trí
- [ ] Code có REQ-ID comments
- [ ] Tests được tạo (nếu không dùng `--skip-tests`)
- [ ] Registry `impl_status` = "done" cho feature vừa implement

**Kiểm tra bằng AI (có thể chạy nhiều lần):**

```
/audit-skill-output wf-implement-feature
```

> Có thể chạy lại nhiều lần để tăng độ chính xác. Mặc định tự động sửa lỗi; thêm `--no-fix` nếu chỉ muốn xem báo cáo mà không sửa.

**Xử lý sự cố:**

| Vấn đề                        | Nguyên nhân             | Cách xử lý                                       |
| -------------------------------- | ------------------------- | --------------------------------------------------- |
| "Task file not found"            | Chưa chạy plan-modules  | Quay lại Bước 6                                  |
| Code review fail > 3 lần        | Code có nhiều lỗi      | Xem impl-report.md, sửa thủ công rồi chạy lại |
| Feature không tìm thấy        | Tên sai hoặc REQ-ID sai | Dùng `/status` xem danh sách features           |
| `--resume` không hoạt động | Checkpoint bị hỏng      | Dùng `--fresh` để bắt đầu lại              |

---

### Bước 8: Kiểm Tra Toàn Diện (Preflight)

**Mục đích:** Health check toàn diện — validate registry, docs, code, tests trước release.

**Điều kiện:** Có source code (ít nhất 1 feature đã implement).

**Cách chạy:**

```
/wf-preflight
```

Các tùy chọn:

```
/wf-preflight --scope=all                  # Kiểm tra toàn bộ (mặc định)
/wf-preflight --scope=system --name=crm    # Chỉ 1 system
/wf-preflight --scope=module --name=auth   # Chỉ 1 module
/wf-preflight --scope=feature --name=FEAT-CRM-001  # Chỉ 1 feature
/wf-preflight --fix                        # Tự động sửa lỗi nhẹ
/wf-preflight --run-tests                  # Chạy tests
```

**Quá trình:**

1. Validate registry schema
2. Kiểm tra tài liệu đầy đủ
3. Kiểm tra code có REQ-IDs
4. Kiểm tra chất lượng code
5. Chạy tests (nếu có `--run-tests`)
6. Tự động sửa (nếu có `--fix`)
7. Tạo report

**Kết quả tạo ra:**

```
.mc-data/work/wf-preflight/
└── preflight-report.md    ← Kết quả: PASS / WARN / FAIL
```

**Verdict:**

| Kết quả      | Ý nghĩa               | Hành động                       |
| -------------- | ----------------------- | ---------------------------------- |
| **PASS** | Tất cả đều tốt     | Tiếp tục Bước 10 (Verify Sync) |
| **WARN** | Có cảnh báo nhỏ     | Xem xét, có thể tiếp tục      |
| **FAIL** | Có lỗi nghiêm trọng | PHẢI sửa trước khi tiếp tục  |

**Kiểm tra sau bước 8:**

**Kiểm tra bằng AI (có thể chạy nhiều lần):**

```
/audit-skill-output wf-preflight
```

> Có thể chạy lại nhiều lần để tăng độ chính xác. Mặc định tự động sửa lỗi; thêm `--no-fix` nếu chỉ muốn xem báo cáo mà không sửa.

**Xử lý sự cố:**

| Vấn đề               | Nguyên nhân                 | Cách xử lý                                          |
| ----------------------- | ----------------------------- | ------------------------------------------------------ |
| FAIL: Missing REQ-IDs   | Code thiếu REQ-ID comments   | Chạy `/wf-preflight --fix` để tự động thêm    |
| FAIL: Registry invalid  | JSON bị hỏng                | Chạy lại `/wf-preflight --fix`                     |
| FAIL: Orphan code       | Code không liên kết REQ-ID | Xác định code thuộc requirement nào, thêm REQ-ID |
| WARN: Stale impl_status | Registry chưa cập nhật     | DEVKIT tự xử lý trong verify-sync                   |

---

### Bước 9: Sửa Lỗi (Fix Bugs)

**Mục đích:** Tìm và sửa lỗi phát sinh sau preflight hoặc trong quá trình phát triển. Từ v9.0, kiểm tra toàn diện 10 chiều chất lượng bao gồm browser runtime (QD9) và cross-module integration (QD10).

**Điều kiện:** Có source code. Có thể gọi **bất kỳ lúc nào** sau khi có code.

**Cách chạy:**

```
/wf-fix-bugs                                    # Tự động phát hiện và sửa (11 lanes)
/wf-fix-bugs "Login không hoạt động"            # Mô tả lỗi cụ thể
/wf-fix-bugs --scope=module --name=auth         # Giới hạn phạm vi
/wf-fix-bugs --lane=QD9                         # Chỉ kiểm tra browser/UI runtime
/wf-fix-bugs --lane=QD10                        # Chỉ kiểm tra cross-module integration
/wf-fix-bugs --since=HEAD~5                     # Chỉ kiểm tra code vừa thay đổi (nhanh hơn)
/wf-fix-bugs --profile=quick                    # Profile nhanh (bỏ qua probes nặng)
/wf-fix-bugs --profile=exhaustive               # Toàn diện (YAML spec probes)
/wf-fix-bugs --dry-run                          # Chỉ phát hiện, không sửa
/wf-fix-bugs --run-tests                        # Chạy tests sau khi sửa
/wf-fix-bugs --resume                           # Tiếp tục từ checkpoint
```

**Quá trình (v9.1 — 11 dimension lanes):**

1. **CDG gate tự động:** Nếu > 20 modules → hỏi giới hạn scope; nếu ước tính chi phí > $5 → hỏi tiếp tục
2. **11 lanes song song:** QD1 (chức năng) + QD2 (nghiệp vụ) + QD3 (bảo mật) + QD4 (hiệu năng) + QD5 (UX/A11y) + QD6 (dữ liệu) + QD7 (compat) + QD8 (observability) + **QD9 (browser runtime)** + **QD10 (cross-module)** + **QD11 (business completeness — LLM)**
3. Phân loại mức độ + phát hiện user_journey_broken
4. Sửa code theo batch CRITICAL → HIGH → MEDIUM
5. CQG-2 gate: đảm bảo QD9 console error = 0 và QD10 HIGH+ = 0 trước khi hoàn thành
6. Cập nhật feature specs + tạo report (có Browser Verification nếu QD9 chạy)

**Kết quả tạo ra:**

- Source code đã sửa
- Feature specs cập nhật (nếu cần)
- `$SESSION_DIR/fix-report.md` (có Browser Verification section nếu QD9 ran)
- `$SESSION_DIR/lanes/QD*/signals.json` — signals theo từng dimension

**Kiểm tra sau bước 9:**

> **Mẹo:** Sau khi sửa lỗi, LUÔN chạy lại `/wf-preflight` để đảm bảo không phát sinh lỗi mới.

**Kiểm tra bằng AI (có thể chạy nhiều lần):**

```
/audit-skill-output wf-fix-bugs
```

> Có thể chạy lại nhiều lần để tăng độ chính xác. Mặc định tự động sửa lỗi; thêm `--no-fix` nếu chỉ muốn xem báo cáo mà không sửa.

---

### Debug Nâng Cao với QD9 + QD10

> **Dành cho dự án đã có code UI và nhiều modules liên kết với nhau.** Đây là tính năng v9.0 giúp phát hiện lỗi browser runtime và tích hợp cross-module mà preflight thông thường không phát hiện được.

#### QD9 — Kiểm tra Runtime Health (Browser)

Dùng khi: phát hiện lỗi trên trình duyệt, UI không hiển thị đúng, route bị broken, form không validate.

```
# Kiểm tra nhanh browser runtime (cần dev server đang chạy)
/wf-fix-bugs --lane=QD9 --profile=standard

# Kiểm tra sâu hơn (thêm CTA smoke + form validation)
/wf-fix-bugs --lane=QD9 --profile=exhaustive
```

**QD9 phát hiện:**
- Dev server không start (`dev_server_bootstrap_failed` — CRITICAL)
- JavaScript uncaught exception (`uncaught_exception` — CRITICAL)
- Console errors sau đăng nhập (`runtime_console_error` — HIGH)
- Route feature đã implement nhưng không load (`feature_route_broken` — HIGH)
- Form submit không hợp lệ nhưng không có validation (`form_validation_bypass` — HIGH)
- SPA route khai báo nhưng navigate thất bại (`spa_route_unreachable` — MEDIUM)

#### QD10 — Kiểm tra Cross-Module Integration

Dùng khi: module A gọi API module B nhưng response sai, state machine không khớp code, business flow bị gián đoạn giữa các module.

**Bước 1 — Khai báo dependencies trong registry:**

```bash
# Auto-detect dependencies (dry-run trước)
bash .claude/scripts/wf-detect-cross-module-deps.sh --dry-run

# Ghi vào registry (sau khi review kết quả)
bash .claude/scripts/wf-detect-cross-module-deps.sh --write
```

**Bước 2 — Chạy QD10:**

```
# Kiểm tra static (import drift, API contract)
/wf-fix-bugs --lane=QD10 --profile=standard

# Kiểm tra sâu hơn (thêm entity sync, orphan refs)
/wf-fix-bugs --lane=QD10 --profile=deep

# Toàn diện (YAML spec: state machine + business flow + auth matrix)
/wf-fix-bugs --lane=QD10 --profile=exhaustive
```

**QD10 phát hiện:**
- Import/type reference drift giữa modules (`cross_module_ref_drift` — MEDIUM)
- API contract breaking change (`api_contract_breaking_change` — HIGH)
- Event emitted nhưng không có handler (`event_handler_missing` — HIGH)
- State machine illegal transition (`state_machine_illegal_transition` — HIGH)
- Business flow step thất bại (`business_flow_step_failed` — HIGH)
- Business flow invariant bị vi phạm (`business_flow_invariant_violated` — CRITICAL)
- Authorization guard thiếu (`auth_matrix_missing_guard` — HIGH)

**Bước 3 — Authoring YAML spec (profile=exhaustive):**

Tạo YAML file trong thư mục dự án (ví dụ `.mc-data/docs/phase3-architecture/`):

```yaml
# state-machine-quotation.yaml — theo schema doc-framework/_meta/state-machine-spec-schema.json
entity: "Quotation"
version: "1.0"
module_id: "MOD-QUOTATION"
states: [DRAFT, PENDING_APPROVAL, APPROVED, REJECTED, CONVERTED]
initial_state: DRAFT
terminal_states: [REJECTED, CONVERTED]
transitions:
  - from: DRAFT
    to: PENDING_APPROVAL
    action: submit_quotation
```

```yaml
# business-flow-q2c.yaml — theo schema doc-framework/_meta/business-flow-spec-schema.json
flow_id: "q2c-basic"
name: "Quote to Cash"
modules_involved: [MOD-CRM, MOD-QUOTATION, MOD-ORDERS, MOD-FINANCE]
steps:
  - step_id: create-customer
    module: MOD-CRM
    action: POST /api/v1/customers
    assertions:
      - field: status_code
        operator: equals
        value: 201
```

> **Tài liệu đầy đủ:** Xem `docs/wf-fix-bugs-v9-guide.md` — hướng dẫn chi tiết authoring YAML spec, cross-module deps, performance tips.

---

### Bước 10: Xác Minh Đồng Bộ (Verify Sync)

**Mục đích:** Kiểm tra REQ-ID ↔ Code traceability — tìm gaps và orphan code.

**Điều kiện:** Code đã implement.

**Cách chạy:**

```
/wf-verify-sync
```

Các tùy chọn:

```
/wf-verify-sync --scope=all               # Toàn bộ (mặc định)
/wf-verify-sync --scope=system --name=crm  # Chỉ 1 system
/wf-verify-sync --fix                      # Tự động thêm REQ-ID vào orphan code
```

**Quá trình:**

1. Thu thập tất cả REQ-IDs từ registry
2. Scan code tìm các REQ-ID references
3. Phân loại: synced / diverged / not_implemented / undocumented
4. Tính sync rate
5. Cập nhật registry (safe-update)

**Kết quả tạo ra:**

```
.mc-data/docs/_meta/verify-sync.md    ← Báo cáo đồng bộ
```

**Chỉ số quan trọng:**

- **Sync rate** = (REQ-IDs đã implement / Tổng REQ-IDs) × 100%
- **Yêu cầu tối thiểu để deploy:** >= 80%

**Kiểm tra sau bước 10:**

Những điểm cần xác nhận:

- [ ] Sync rate >= 80%
- [ ] Không có "not_implemented" cho các REQ-ID quan trọng
- [ ] "undocumented" code đã được review

**Kiểm tra bằng AI (có thể chạy nhiều lần):**

```
/audit-skill-output wf-verify-sync
```

> Có thể chạy lại nhiều lần để tăng độ chính xác. Mặc định tự động sửa lỗi; thêm `--no-fix` nếu chỉ muốn xem báo cáo mà không sửa.

**Xử lý sự cố:**

| Vấn đề        | Nguyên nhân              | Cách xử lý                                 |
| ---------------- | -------------------------- | --------------------------------------------- |
| Sync rate < 80%  | Nhiều REQ chưa implement | Quay lại Bước 7 implement thêm            |
| Orphan code      | Code không có REQ-ID     | Dùng `--fix` hoặc thêm REQ-ID thủ công |
| "Diverged" items | Code khác với specs      | Xem xét: cập nhật specs hoặc sửa code    |

---

### Bước 11: Tài Liệu Triển Khai (Phase 6)

**Mục đích:** Tạo tài liệu hướng dẫn triển khai, sử dụng, và bảo trì.

**Điều kiện:** Verify Sync đã hoàn thành với sync rate >= 80%.

**Cách chạy:**

```
/wf-prepare-deployment
```

**Quá trình:**

1. Validate sync rate >= 80%
2. DevOps tạo Deployment Guide (SONG SONG với bước 3)
3. Tech Writer tạo User Guide (SONG SONG với bước 2)
4. Account Management (TUẦN TỰ sau 2 + 3)
5. Maintenance Guide (DevOps + Tech Writer)
6. Incident Response Runbook (SRE)
7. Cross-validation
8. Stakeholder Review

**Kết quả tạo ra:**

```
.mc-data/docs/phase6-deployment/
├── deployment-guide.md              ← 10 mục hướng dẫn triển khai
├── user-guide.md                    ← Hướng dẫn sử dụng
├── incident-response-runbook.md     ← Quy trình xử lý sự cố
└── stakeholder-review.md
```

**Kiểm tra sau bước 11:**

Những điểm cần xác nhận:

- [ ] `deployment-guide.md` có 10 sections
- [ ] `user-guide.md` mô tả cách sử dụng cho end-user
- [ ] `incident-response-runbook.md` có quy trình xử lý sự cố
- [ ] `stakeholder-review.md` tồn tại

**Kiểm tra bằng AI (có thể chạy nhiều lần):**

```
/audit-skill-output wf-prepare-deployment
```

> Có thể chạy lại nhiều lần để tăng độ chính xác. Mặc định tự động sửa lỗi; thêm `--no-fix` nếu chỉ muốn xem báo cáo mà không sửa.

**Xử lý sự cố:**

| Vấn đề                | Nguyên nhân            | Cách xử lý                          |
| ------------------------ | ------------------------ | -------------------------------------- |
| "Sync rate < 80%"        | Chưa đạt ngưỡng     | Quay lại Bước 7–10 implement thêm |
| Thiếu infra-spec        | Phase 3 chưa đầy đủ | Quay lại Bước 4 bổ sung            |
| User guide quá sơ sài | Thiếu feature context   | Kiểm tra Phase 2 feature specs        |

---

### Tổng Kết Standard Path

```
Bước  Phase   Lệnh                          Kiểm tra chính                     Thời gian
──────────────────────────────────────────────────────────────────────────────────────────
1     0       /wf-brainstorm                P0-01, P0-02 tồn tại              15–30 phút
2     1       /wf-analyze-requirements      registry có requirements           30–90 phút
3     2       /wf-define-features           registry có features               30–60 phút
4     3       /wf-design                    architecture + API + DB docs       20–45 phút
5     4       /wf-design-ux                 design system + screens            30–90 phút
6     5a      /wf-plan-modules              roadmap + task files               15–30 phút
7     5b      /wf-implement-feature [x]     source code + tests               20–60 phút/feature
8     —       /wf-preflight                 PASS verdict                       5–15 phút
9     —       /wf-fix-bugs (nếu cần)        fix report                         15–60 phút
10    —       /wf-verify-sync               sync rate >= 80%                   5–15 phút
11    6       /wf-prepare-deployment        deployment + user docs             20–45 phút
```

---

## Phần B — Dự Án Có Sẵn (Existing Path)

> Dành cho dự án **đã có source code** (có hoặc không có tài liệu), cần onboard vào DEVKIT để tiếp tục phát triển có hệ thống.

### Bước 1: Quét Toàn Diện Dự Án (Legacy Scan — All-in-one)

**Mục đích:** Quét toàn bộ dự án trong **một lệnh duy nhất**: phát hiện cấu trúc, đánh giá độ chín muồi, phân loại files, trích xuất requirements, và tổng hợp project context.

> **Lưu ý:** Từ v3.1.0, `/wf-legacy-scan` là **all-in-one orchestrator** — tự động chạy classify và extract nội bộ. Bạn **không cần** chạy riêng `/wf-legacy-classify` hay `/wf-legacy-extract` trừ khi muốn chạy lại từng stage đơn lẻ (xem Bước 1b/1c bên dưới).

**Cách chạy:**

```
/wf-legacy-scan [đường-dẫn-dự-án]
```

Các tùy chọn:

```
/wf-legacy-scan ./my-existing-app           # Chỉ định đường dẫn
/wf-legacy-scan --resume                    # Tiếp tục từ checkpoint
/wf-legacy-scan --re-vision                 # Quét lại khi đã thay đổi vision
/wf-legacy-scan --batch-size=50             # Batch size cho classify (mặc định: 100)
```

**Quá trình (7 stages nội bộ):**

1. **Detection** — Phát hiện tech stack, frameworks, số file, cấu trúc
2. **Assessment** — Đánh giá độ chín muồi (maturity level), chọn strategy
3. **Maturity Validation** — Validate DEVKIT data hiện có (nếu có)
4. **Inventory** — Tạo inventory (liệt kê tất cả files)
5. **Classify** — Phân loại files vào systems/modules, tạo glossary (delegate nội bộ)
6. **Extract** — Trích xuất requirements và features từ code (delegate nội bộ)
7. **Synthesize** — Tổng hợp `project-context.md` và companion files

**Maturity Levels:**

| Level                               | Điều kiện                    | Chiến lược        |
| ----------------------------------- | ------------------------------- | -------------------- |
| **CODE_ONLY**                 | Có code, không có docs       | Full pipeline        |
| **CODE_PLUS_EXTERNAL_DOCS**   | Có code + docs riêng          | Full pipeline        |
| **CODE_PLUS_DEVKIT_PARTIAL**  | Có `.mc-data/` nhưng thiếu | Merge gaps           |
| **CODE_PLUS_DEVKIT_COMPLETE** | `.mc-data/` đầy đủ        | Validate + gap       |
| **NEAR_COMPLETE**             | DEVKIT đầy đủ + >75% done   | Fast-track → verify |
| **DOCS_ONLY**                 | Chỉ có docs, không có code  | Coverage analysis    |

**7 Chiến Lược (Strategies):**

| Strategy               | Điều kiện                    | Mô tả                        |
| ---------------------- | ------------------------------- | ------------------------------ |
| S1: FAST-TRACK         | DEVKIT complete + alignment cao | Chỉ validate và gap analysis |
| S2: CODE-FIRST         | Code-only (mặc định)         | Full pipeline từ code         |
| S3: DOCS-FIRST         | Docs tốt, code ít             | Tạo code từ docs             |
| S4: DOCS-BRAINSTORM    | Docs kém                       | Brainstorm lại từ docs       |
| S5: DIVERGENCE-RESOLVE | Code và docs xung đột        | Giải quyết xung đột        |
| S6: RE-VISION          | Code tốt, vision mới          | Cập nhật vision              |
| S7: FULL-REBUILD       | Code kém                       | Xây lại từ đầu            |

**Kết quả tạo ra:**

```
.mc-data/work/legacy-scan/
├── project-profile.json       ← Thông tin dự án (tech stack, frameworks)
├── assessment-report.json     ← Đánh giá maturity + scores
├── ledger.json                ← ★ Tiến độ pipeline + strategy
├── inventory/                 ← Danh sách files
│   └── batch-*.json
├── classified/                ← Files đã phân loại (từ Stage 5)
│   └── batch-*.json
├── glossary.json              ← Thuật ngữ domain (từ Stage 5)
├── extracted/                 ← Requirements + features per module (từ Stage 6)
│   ├── [module-name].json
│   └── dedup-report.json
├── project-context.md         ← ★ Tổng hợp context (từ Stage 7)
├── doc-quality-map.json       ← Đánh giá chất lượng docs hiện có
└── impl-status-snapshot.json  ← Snapshot trạng thái implement
```

**Kiểm tra sau bước 1:**

Những điểm cần xác nhận:

- [ ] `project-profile.json` có thông tin tech stack chính xác
- [ ] `assessment-report.json` có maturity level hợp lý
- [ ] `ledger.json` có strategy đã xác định và `pipeline_status`
- [ ] `inventory/` có ít nhất 1 batch file
- [ ] `classified/` có data (files đã phân loại)
- [ ] `extracted/` có data (requirements đã trích xuất)
- [ ] `project-context.md` tồn tại và > 500 bytes

**Kiểm tra bằng AI (có thể chạy nhiều lần):**

```
/audit-skill-output wf-legacy-scan
```

> Có thể chạy lại nhiều lần để tăng độ chính xác. Mặc định tự động sửa lỗi; thêm `--no-fix` nếu chỉ muốn xem báo cáo mà không sửa.

**Xử lý sự cố:**

| Vấn đề                 | Nguyên nhân                      | Cách xử lý                                     |
| ------------------------- | ---------------------------------- | ------------------------------------------------- |
| "No source code found"    | Đường dẫn sai                  | Kiểm tra đường dẫn dự án                   |
| Maturity level sai        | Dự án có cấu trúc đặc biệt | DEVKIT cho phép override trong bước tiếp theo |
| Scan quá lâu            | Dự án quá lớn                  | Dùng `--resume` nếu bị timeout               |
| Strategy không phù hợp | Đánh giá tự động sai         | Dùng `--re-vision` để quét lại với strategy mới |

---

### Bước 1b: Phân Loại Files (Standalone — Chỉ Khi Cần)

> **Bước này thường KHÔNG CẦN chạy riêng.** `/wf-legacy-scan` đã tự động chạy classify nội bộ. Chỉ dùng khi cần **chạy lại** riêng stage classify (VD: kết quả phân loại sai, hoặc bị timeout giữa chừng).

**Cách chạy:**

```
/wf-legacy-classify --resume           # Tiếp tục từ checkpoint
/wf-legacy-classify --batch-size=50    # Thay đổi batch size (mặc định: 100)
```

**Xử lý sự cố:**

| Vấn đề                | Nguyên nhân                       | Cách xử lý                                   |
| ------------------------ | ----------------------------------- | ----------------------------------------------- |
| Phân loại sai module   | Code-reviewer hiểu nhầm           | Có thể sửa thủ công trong classified files |
| Glossary rỗng           | Dự án không có domain terms rõ | Bình thường với dự án generic             |
| Bị timeout giữa chừng | Dự án lớn                        | Dùng `--resume`                              |

---

### Bước 1c: Trích Xuất Requirements (Standalone — Chỉ Khi Cần)

> **Bước này thường KHÔNG CẦN chạy riêng.** `/wf-legacy-scan` đã tự động chạy extract nội bộ. Chỉ dùng khi cần **chạy lại** riêng stage extract (VD: trích xuất thiếu module, hoặc muốn extract lại 1 module cụ thể).

**Cách chạy:**

```
/wf-legacy-extract --module=auth      # Chỉ 1 module
/wf-legacy-extract --resume           # Tiếp tục từ checkpoint
```

**Xử lý sự cố:**

| Vấn đề                | Nguyên nhân                       | Cách xử lý                                       |
| ------------------------ | ----------------------------------- | --------------------------------------------------- |
| Confidence thấp (<0.85) | Code khó đọc, thiếu context     | DEVKIT cảnh báo — bạn có thể bổ sung context |
| Nhiều trùng lặp       | Modules có chức năng tương tự | Dedup tự động xử lý                            |
| Divergences (S5)         | Code và docs khác nhau            | Sẽ được xử lý trong /wf-design (legacy mode) |

---

### Bước 2: Tiếp Tục Với Shared Skills (Legacy Mode)

**Mục đích:** Sau khi `/wf-legacy-scan` hoàn thành (pipeline_status = COMPLETE), các shared skills sẽ tự detect legacy mode (CORE-021) và inject context.

**Điều kiện:** `/wf-legacy-scan` hoàn thành — `project-context.md` tồn tại và > 500 bytes.

**Thứ tự chạy:**

```
/wf-brainstorm           # Detect legacy, chốt khung từ extracted data
/wf-analyze-requirements # Phân tích nghiệp vụ — legacy mode + context injection
/wf-define-features      # Định nghĩa features — legacy mode + context injection
/wf-design               # Thiết kế + gap analysis — legacy mode + context injection
/wf-annotate-code        # Inject REQ-ID vào code (nếu có annotation gaps)
/wf-design-ux            # Thiết kế UX — legacy mode (nếu có UI)
```

**Lưu ý:** Mỗi skill tự phát hiện legacy mode bằng CORE-021: kiểm tra `project-context.md` tồn tại và > 500 bytes. Không dùng `ledger.json` để detect.

**Kết quả tạo ra (tổng hợp cả pipeline):**

```
.mc-data/docs/
├── phase0-brainstorm/          ← P0-01, P0-02, policies/
├── phase1-business/            ← Department docs
├── phase2-features/            ← Feature specs
├── phase3-architecture/        ← Architecture + technical specs
└── _meta/
    └── req-registry.json       ← ★ Registry đầy đủ
.mc-data/work/legacy-scan/
├── gap-report.md               ← Báo cáo khoảng trống (từ /wf-design)
└── action-items.json           ← Hành động cần thực hiện (từ /wf-design)
```

**Kiểm tra sau bước 2:**

Những điểm cần xác nhận:

- [ ] Phase 0–3 docs đầy đủ
- [ ] `req-registry.json` có systems, modules, requirements, features
- [ ] JSON hoàn toàn hợp lệ (không bị lỗi syntax)
- [ ] `gap-report.md` liệt kê gaps rõ ràng
- [ ] `action-items.json` có thứ tự ưu tiên

**Xử lý sự cố:**

| Vấn đề                | Nguyên nhân                  | Cách xử lý                                             |
| ------------------------ | ------------------------------ | --------------------------------------------------------- |
| Skill không detect legacy | `project-context.md` không tồn tại hoặc < 500 bytes | Kiểm tra `/wf-legacy-scan` đã hoàn thành, chạy lại nếu cần |
| Registry thiếu data      | Extract chưa đầy đủ       | Chạy `/wf-legacy-extract --module=<tên>` để extract lại module thiếu |
| Gap analysis không chạy  | /wf-design chưa hoàn thành | Chạy lại /wf-design                                      |

---

### Bước 2.5: Inject REQ-ID Vào Code (Annotate Code)

**Mục đích:** Inject REQ-ID và FEAT-ID comments vào code files hiện có để thiết lập traceability.

**Điều kiện:** `/wf-design` (legacy mode) hoàn thành + có annotation gaps (traceability score thấp).

> **Bước này CHỈ CHẠY khi gap report cho thấy annotation gaps.** Nếu code đã có đủ REQ-ID hoặc traceability score cao, có thể skip.

**Lệnh:**

```
/wf-annotate-code
```

**Các tùy chọn:**

```
/wf-annotate-code --module=CRM       # Chỉ annotate 1 module
/wf-annotate-code --dry-run          # Xem annotation map mà không ghi code
/wf-annotate-code --batch-size=30    # Giới hạn files per batch
/wf-annotate-code --resume           # Tiếp tục từ checkpoint
/wf-annotate-code --status           # Xem trạng thái
```

**Quá trình:**

1. Đọc `req-registry.json`, `module-code-mapping.json`, `gap-report.md`
2. Xác định code files cần annotation
3. Inject REQ-ID/FEAT-ID comments vào từng file theo batch
4. Tạo annotation report và map

**Kết quả tạo ra:**

```
.mc-data/work/legacy-scan/
├── annotation-report.md    ← Báo cáo tổng hợp annotations
└── annotation-map.json     ← Map chi tiết file → REQ-IDs
```

**Kiểm tra sau bước 2.5:**

- [ ] `annotation-report.md` tồn tại
- [ ] Code files có REQ-ID comments
- [ ] Traceability score cải thiện

**Lưu ý quan trọng:**

- Skill này **KHÔNG modify registry** — chỉ ghi vào code files
- Hỗ trợ `--resume` cho dự án lớn (checkpoint per batch)
- Dùng `--dry-run` để xem trước annotation map trước khi ghi

---

### Bước 3: Tiếp Tục Với Standard Path

Sau khi hoàn thành Existing Path (Bước 1–2.5), dự án đã có đầy đủ tài liệu Phase 0–3 (và Phase 4 nếu có UI). Tiếp tục với **Standard Path** từ:

```
→ /wf-plan-modules          (Bước 6 Standard Path)
→ /wf-implement-feature     (Bước 7 Standard Path)
→ /wf-preflight             (Bước 8 Standard Path)
→ /wf-fix-bugs              (Bước 9, nếu cần)
→ /wf-verify-sync           (Bước 10 Standard Path)
→ /wf-prepare-deployment    (Bước 11 Standard Path)
```

Xem chi tiết các bước này tại [Phần A — Bước 6 trở đi](#bước-6-lập-kế-hoạch-triển-khai-phase-5a).

---

### Tổng Kết Existing Path

```
Bước  Lệnh                             Kiểm tra chính                           Thời gian
──────────────────────────────────────────────────────────────────────────────────────────────
1     /wf-legacy-scan (all-in-one)     project-context.md + classified/ +        30–90 phút
                                        extracted/ + ledger có strategy
      ┌ /wf-legacy-classify (standalone)  Chỉ khi cần chạy lại classify riêng   —
      └ /wf-legacy-extract (standalone)   Chỉ khi cần chạy lại extract riêng    —
2     Shared skills (legacy mode):      Phase 0–4 docs + registry +              60–180 phút
        /wf-brainstorm*                  gap-report.md
        /wf-analyze-requirements*
        /wf-define-features*
        /wf-design*
        /wf-design-ux* (nếu có UI)
2.5   /wf-annotate-code (nếu gaps)     annotation-report.md có data             10–30 phút
3+    (tiếp Standard Path)             Xem Phần A Bước 6+                       —
```

---

## Phần C — Dự Án Hybrid (Docs sẵn + Code đang phát triển)

> **Khi nào dùng Phần C?** Khi dự án đã có tài liệu DEVKIT đến Phase 4 (qua Standard Path hoặc Legacy Pipeline), nhưng code đã được viết song song **ngoài workflow** — tức là `impl_status` trong registry vẫn là `null` trong khi code thực tế đã tồn tại một phần hoặc toàn bộ.

### Khi Nào Dùng Phần C?

| Dấu hiệu nhận biết                                           | Xử lý                              |
| ---------------------------------------------------------------- | ------------------------------------ |
| Docs Phase 0–4 đã có, Phase 5 chưa có                      | → Đây là Hybrid Path             |
| `implementation_order` trong registry rỗng (`"order": []`)  | → Chưa chạy `plan-modules`      |
| Tất cả `impl_status` là `null` nhưng code đã tồn tại | → Registry chưa được đồng bộ |
| Không chắc code đã implement đủ và đúng chưa           | → Cần `preflight` để kiểm tra |

**Khác biệt so với Standard Path và Existing Path:**

|                | Standard Path                 | Existing Path              | **Hybrid Path**                        |
| -------------- | ----------------------------- | -------------------------- | -------------------------------------------- |
| Docs           | Tạo từ đầu trong workflow | Tạo bằng legacy pipeline | **Đã có Phase 0–4**                |
| Code           | Tạo sau khi có plan         | Đã có, reverse-engineer | **Đang phát triển song song**       |
| impl_status    | Cập nhật sau `implement`  | Scan bằng `/wf-design` (legacy) | **null — cần đồng bộ thủ công** |
| Bắt đầu từ | Brainstorm                    | legacy-scan                | **`wf-plan-modules`**                |

---

### Bước 1: Đánh Giá Mức Độ Hoàn Thiện Của Code

**Mục đích:** Xác định chiến lược phù hợp trước khi chạy DEVKIT.

**Thực hiện thủ công** — không có lệnh DEVKIT cho bước này.

Tự đánh giá theo bảng sau:

| Mức độ                           | Code đã làm                               | Chiến lược                                                              |
| ----------------------------------- | -------------------------------------------- | -------------------------------------------------------------------------- |
| **Sơ bộ** (< 30%)           | Mới bắt đầu, chủ yếu boilerplate       | Chạy `plan-modules` → dùng roadmap để guide tiếp                   |
| **Đáng kể** (30–70%)      | Một số modules done, một số đang làm   | Chạy `plan-modules` → đồng bộ `impl_status` → `preflight`      |
| **Gần hoàn thiện** (> 70%) | Hầu hết done, cần kiểm tra chất lượng | Chạy `plan-modules` → đồng bộ `impl_status` → `preflight` ngay |

> **Lưu ý:** Dù ở mức độ nào, `/wf-plan-modules` vẫn là bước **bắt buộc** vì Phase 5 docs chưa tồn tại — `plan-modules` mới tạo ra roadmap, sprint plans, và task files cần thiết cho các bước sau.

---

### Bước 2: Lập Kế Hoạch Triển Khai (`/wf-plan-modules`)

**Mục đích:** Tạo Phase 5 docs (roadmap, dependency graph, sprint plans, task files) — bước này **bắt buộc** kể cả khi code đã có.

**Điều kiện:** Phase 0–4 docs đã có. `req-registry.json` có ít nhất 1 module.

**Cách chạy:**

```
/wf-plan-modules
```

Các tùy chọn hữu ích cho Hybrid Path:

```
/wf-plan-modules --mvp           # Nếu muốn xác định scope tối thiểu cần hoàn thiện
/wf-plan-modules --skip-sprints  # Nếu chỉ cần roadmap, không cần sprint chi tiết
```

**Kết quả tạo ra:**

```
.mc-data/docs/phase5-implementation/
├── module-plan.md                       ← Kế hoạch module + layer assignment
├── dependency-graph.md                  ← Biểu đồ phụ thuộc (Mermaid)
├── P5-00-implementation-roadmap.md      ← Roadmap tổng thể
├── sprints/
│   ├── S01-foundation.md
│   └── S02+...
├── tasks/[sys]/[mod]/[feat]-impl.md     ← Task file cho từng feature
└── stakeholder-review.md                ← Review của architect + qa-lead
```

**Kiểm tra sau bước 2:**

- [ ] `phase5-implementation/` tồn tại và có đủ files
- [ ] `implementation_order` trong registry đã được cập nhật (không còn rỗng)
- [ ] Dependency graph không có circular dependency
- [ ] `stakeholder-review.md` không có findings Critical/High

**Kiểm tra bằng AI:**

```
/audit-skill-output wf-plan-modules
```

**Xử lý sự cố:**

| Vấn đề                                | Nguyên nhân                           | Cách xử lý                                            |
| ---------------------------------------- | --------------------------------------- | -------------------------------------------------------- |
| "Feature specs not found"                | `phase2-features/` thiếu files       | Kiểm tra lại Phase 2 docs                              |
| Circular dependency phát hiện          | Thiết kế module có vòng lặp        | DEVKIT đề xuất giải pháp — chọn 1 trong 3 options |
| Stakeholder review có Critical findings | Kế hoạch có vấn đề nghiêm trọng | Đọc findings, sửa theo đề xuất, chạy lại         |

---

### Bước 3: Đồng Bộ `impl_status` Về Thực Tế

**Mục đích:** Cập nhật registry để `impl_status` phản ánh đúng những gì code đã làm được — tránh việc `preflight` và `implement` xử lý lại những phần đã xong.

**Lý do cần bước này:** Registry đang có tất cả `impl_status = null`, trong khi code đã tồn tại. Nếu bỏ qua, các bước sau sẽ coi như toàn bộ chưa implement.

**Cách thực hiện:**

Xem danh sách features trong registry:

```bash
# Xem tất cả features và trạng thái hiện tại
cat .mc-data/docs/_meta/req-registry.json | jq '.features[] | {id: .id, name: .name, impl_status: .impl_status}'
```

Với mỗi feature, tự đánh giá và cập nhật `impl_status` theo bảng sau:

| Trạng thái    | Khi nào dùng                               |
| --------------- | -------------------------------------------- |
| `not_started` | Code chưa có gì cho feature này          |
| `in_progress` | Code đã có một phần, chưa xong         |
| `done`        | Code đã implement đầy đủ, logic đúng |
| `skipped`     | Chủ động không làm feature này         |

**Cập nhật trực tiếp trong file registry:**

```
.mc-data/docs/_meta/req-registry.json
```

Tìm đến block `"features"` và cập nhật `"impl_status"` cho từng feature.

> **Quy tắc bất di bất dịch:** Chỉ đánh `done` khi **chắc chắn** feature đó đã implement đúng. Nếu không chắc → dùng `in_progress`. `preflight` ở Bước 4 sẽ xác nhận lại.

> **Lưu ý:** Nếu dự án có nhiều features (>20), ít nhất phải cập nhật những features chắc chắn đã `done` hoặc `skipped`. Để nguyên `null`/`not_started` cho phần không chắc. **Nhớ rằng:** `preflight` chỉ kiểm tra code-registry sync cho các REQ có `done`/`in_progress` — nếu không cập nhật gì, phần sync check sẽ bị bỏ qua hoàn toàn và kết quả preflight sẽ không phản ánh thực tế.

**Kiểm tra sau bước 3:**

```bash
# Kiểm tra JSON hợp lệ sau khi chỉnh sửa
cat .mc-data/docs/_meta/req-registry.json | jq '.' > /dev/null && echo "JSON hợp lệ"

# Xem phân bố trạng thái
cat .mc-data/docs/_meta/req-registry.json | jq '.features[] | .impl_status' | sort | uniq -c
```

---

### Bước 4: Kiểm Tra Toàn Diện (`/wf-preflight`)

**Mục đích:** Validate rằng registry, docs, và code **nhất quán với nhau** — không phải discover những gì đã implement. `preflight` kiểm tra code KHỚP với những gì registry ghi nhận, không tự cập nhật registry.

> **Lưu ý quan trọng:** `preflight` chỉ thực hiện Code Sync check cho các REQ có `impl_status = done` hoặc `in_progress`. Nếu Bước 3 chưa được thực hiện (tất cả vẫn là `null`), phần kiểm tra code-registry sẽ bị **skip hoàn toàn** — preflight vẫn chạy nhưng không có giá trị về sync. Vì vậy Bước 3 là bắt buộc trước bước này.

**Điều kiện:** Phase 5 docs đã có (Bước 2 hoàn thành). `impl_status` đã được đồng bộ (Bước 3 hoàn thành).

**Cách chạy:**

```
/wf-preflight
```

Các tùy chọn hữu ích cho Hybrid Path:

```
/wf-preflight --fix              # Auto-fix lỗi nhẹ: JSON syntax + thêm REQ-ID comment vào orphan files
/wf-preflight --run-tests        # Chạy unit/integration tests nếu có
/wf-preflight --scope=module --name=<id>  # Kiểm tra từng module nếu dự án lớn
```

> **Giới hạn của `--fix`:** Chỉ sửa JSON syntax errors và thêm REQ-ID comments vào code files không có ID. **Không** tự cập nhật `impl_status`, không tạo docs thiếu, không sửa logic code.

**Kết quả tạo ra:**

```
.mc-data/work/wf-preflight/
└── preflight-report.md   ← PASS / WARN / FAIL + danh sách vấn đề
```

**Đọc kết quả preflight:**

| Verdict        | Ý nghĩa                                 | Hành động                             |
| -------------- | ----------------------------------------- | ---------------------------------------- |
| **PASS** | Registry, docs, code nhất quán          | Tiếp tục Bước 7                      |
| **WARN** | Có vấn đề nhỏ, không chặn          | Xem xét fix hoặc bỏ qua — tiếp tục |
| **FAIL** | Có vấn đề nghiêm trọng cần xử lý | Sang Bước 5                            |

**Các lỗi thường gặp trong Hybrid Path:**

| Lỗi                                                    | Nguyên nhân                                            | Cách xử lý                                                                           |
| ------------------------------------------------------- | -------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `Missing Phase 5 task files`                          | `plan-modules` chưa chạy                             | Quay lại Bước 2                                                                      |
| `Orphan code files`                                   | Code file không có REQ-ID comment                      | Chạy `--fix` để tự thêm (nếu xác định được REQ-ID) hoặc thêm thủ công |
| `REQ done nhưng không tìm thấy REQ-ID trong code` | Registry nói `done` nhưng code thiếu REQ-ID comment | Thêm REQ-ID comment vào code file tương ứng                                        |
| `Registry JSON invalid`                               | File bị hỏng cú pháp                                 | Chạy `--fix`                                                                         |
| `Phase 5 task file count mismatch`                    | Số features trong registry ≠ số task files            | Chạy lại `plan-modules`                                                             |
| `TypeScript / Lint errors`                            | Lỗi biên dịch hoặc code style                        | Sửa code —`--fix` không xử lý được loại này                                 |

**Kiểm tra bằng AI:**

```
/audit-skill-output wf-preflight
```

---

### Bước 5: Sửa Lỗi Phát Hiện (`/wf-fix-bugs`)

**Mục đích:** Sửa các lỗi FAIL trong báo cáo preflight.

**Điều kiện:** Có `preflight-report.md` với ít nhất 1 findings FAIL.

**Cách chạy:**

```
/wf-fix-bugs                                    # Fix tất cả lỗi từ preflight
/wf-fix-bugs "mô tả lỗi cụ thể"               # Fix lỗi cụ thể
/wf-fix-bugs --scope=module --name=<id>        # Chỉ fix 1 module
/wf-fix-bugs --dry-run                         # Xem kế hoạch fix, không thay đổi code
```

**Sau khi fix:**

```
/wf-preflight          # Chạy lại để xác nhận đã fix xong
```

> **Mẹo:** Có thể lặp Bước 4–5 nhiều lần đến khi preflight PASS hoặc chỉ còn WARN.

---

### Bước 6: Implement Phần Còn Thiếu (`/wf-implement-feature`)

**Mục đích:** Implement các features có `impl_status = not_started` hoặc `in_progress` mà preflight xác nhận là chưa có code.

**Điều kiện:** Phase 5 task files đã có (`tasks/[sys]/[mod]/[feat]-impl.md`). Bước 4 đã xác định features còn thiếu.

**Cách chạy:**

```
/wf-implement-feature <feat-id>        # Implement 1 feature cụ thể
/wf-implement-feature                  # DEVKIT hỏi feature nào cần làm
```

Ví dụ:

```
/wf-implement-feature FEAT-CRM-001
/wf-implement-feature MOD-ERP-HR       # Implement toàn bộ module
```

> **Bỏ qua bước này nếu:** Preflight PASS và tất cả features đã `done` hoặc `skipped`.

---

### Bước 7: Xác Minh Đồng Bộ Và Triển Khai

Sau khi code đã ổn định (preflight PASS):

```
/wf-verify-sync            # Xác minh requirement-to-code traceability
/wf-prepare-deployment     # Tạo Phase 6 tài liệu triển khai
```

Xem chi tiết tại [Bước 10 — Xác minh đồng bộ](#bước-10-xác-minh-đồng-bộ-verify-sync) và [Bước 11 — Tài liệu triển khai](#bước-11-tài-liệu-triển-khai-phase-6) trong Phần A.

---

### Tổng Kết Hybrid Path

```
Bước  Lệnh / Hành động                  Kiểm tra chính                         Thời gian
──────────────────────────────────────────────────────────────────────────────────────────────
1     [Thủ công] Đánh giá code           Xác định mức độ: Sơ bộ/Đáng kể/Gần xong  5–15 phút
2     /wf-plan-modules                   Phase 5 docs + implementation_order       15–30 phút
3     [Thủ công] Đồng bộ impl_status     JSON hợp lệ, phân bố status hợp lý        10–30 phút
4     /wf-preflight [--fix]              PASS hoặc chỉ còn WARN                     5–15 phút
5     /wf-fix-bugs (nếu cần)             preflight-report không còn FAIL            15–60 phút
6     /wf-implement-feature (nếu cần)    Features còn thiếu được implement          20–60 phút/feat
7     /wf-verify-sync                    sync rate >= 80%                           5–15 phút
      /wf-prepare-deployment             Phase 6 docs                              20–45 phút
```

> **Khác với Standard Path:** Thứ tự `plan-modules` → `đồng bộ` → `preflight` thay vì `plan-modules` → `implement` → `preflight`. Nguyên nhân là code đã tồn tại — cần kiểm tra thực tế trước, không implement lại từ đầu.

---

## Orchestrator — Chạy Tự Động

Thay vì chạy từng skill thủ công, bạn có thể dùng orchestrator để DEVKIT tự động chạy toàn bộ workflow.

### /new-project — Dự Án Mới Tự Động

```
/new-project
```

Các tùy chọn:

```
/new-project my-erp                  # Với tên dự án
/new-project --resume                # Tiếp tục từ checkpoint
/new-project --from-phase 3          # Bắt đầu từ Phase 3
/new-project --status                # Xem tiến độ
```

**Phase mapping cho `--from-phase`:**

| Giá trị | Phase                | Điều kiện                         |
| --------- | -------------------- | ------------------------------------ |
| 0         | Brainstorm           | Không cần                          |
| init      | Init structure       | Phase 0 xong                         |
| 1         | Analyze Requirements | Init xong                            |
| 2         | Define Features      | Phase 1 xong                         |
| 3         | Design               | Phase 2 xong                         |
| 4         | Design UX            | Phase 3 xong                         |
| 5a        | Plan Modules         | Phase 4 xong (hoặc 3 nếu api-only) |
| 5b        | Implement            | Phase 5a xong                        |
| verify    | Verify Sync          | Code xong                            |
| 6         | Prepare Deployment   | Verify xong                          |

> **Mẹo:** Nếu bị gián đoạn giữa chừng, dùng `/new-project --resume` để tiếp tục.

### /existing-project — Dự Án Có Sẵn Tự Động

```
/existing-project
```

Tự động chạy toàn bộ pipeline:

```
Scan 0   → /wf-legacy-scan (all-in-one)
Phase 0  → /wf-brainstorm*
Phase 1  → /wf-analyze-requirements*
Phase 2  → /wf-define-features*
Phase 3  → /wf-design*
Phase 4  → /wf-design-ux* (conditional)
Phase 5a → /wf-plan-modules
Phase 5b → /wf-implement-feature (lặp per feature)
Preflight→ /wf-preflight
Verify   → /wf-verify-sync

* = shared skills tự detect legacy mode (CORE-021)
```

Các tùy chọn:

```
/existing-project --resume              # Tiếp tục từ checkpoint
/existing-project --from-phase scan     # Bắt đầu từ legacy scan
/existing-project --from-phase 3        # Bắt đầu từ Phase 3 (Design)
/existing-project --from-phase preflight # Bắt đầu từ Preflight
```

**Mapping `--from-phase`:**

| Giá trị    | Bắt đầu từ              |
| ----------- | -------------------------- |
| `scan`      | Legacy Scan                |
| `1`         | Phase 1: Requirements      |
| `2`         | Phase 2: Features          |
| `3`         | Phase 3: Design            |
| `4`         | Phase 4: UX                |
| `5a`        | Phase 5a: Plan Modules     |
| `5b`        | Phase 5b: Implement        |
| `preflight` | Preflight Health Check     |
| `verify`    | Verify Sync                |

### /feature-addition — Thêm Tính Năng

```
/feature-addition
```

Yêu cầu Phase 0–3 đã hoàn thành. Bắt đầu từ định nghĩa feature mới (Phase 2), conditionally cập nhật Phase 3+, rồi implement → preflight → verify.

---

## Công Cụ Hỗ Trợ

### /status — Xem Tiến Độ

```
/status                              # Dashboard tổng quan
/status --detailed                   # Chi tiết tất cả features
/status --sprint=S01                 # Chi tiết 1 sprint
/status --system=crm                 # Lọc theo system
```

Hiển thị:

- Tổng quan dự án (systems, modules, requirements)
- Tiến độ implement (done / in_progress / not_started)
- Sprint breakdown
- Legacy pipeline status (nếu đang chạy)

### /wf-preflight — Health Check

```
/wf-preflight --fix                  # Tự động sửa lỗi nhẹ
/wf-preflight --run-tests            # Chạy tests
/wf-preflight --scope=module --name=auth  # Kiểm tra 1 module
```

### /audit-skill-output — Kiểm Tra Chất Lượng

```
/audit-skill-output wf-analyze-requirements  # Kiểm tra 1 skill
/audit-skill-output --all                    # Kiểm tra tất cả
/audit-skill-output --no-fix                 # Chỉ báo cáo, không sửa
```

7 chiều kiểm tra:

1. **D1:** Files tồn tại và có nội dung
2. **D2:** Cấu trúc theo đúng template
3. **D3:** Registry nhất quán
4. **D4:** Chất lượng nội dung
5. **D5:** Nhất quán giữa các phases
6. **D6:** POST-GATE validation
7. **D7:** Error tracking

### /audit-devkit — Tự Kiểm Tra DEVKIT

```
/audit-devkit
```

Kiểm tra toàn bộ DEVKIT: agents, skills, templates, workflow, cross-references.

---

## Xử Lý Sự Cố Chung

### 1. Session Bị Mất Context

**Triệu chứng:** DEVKIT trả lời không liên quan, quên trạng thái trước đó.

**Cách xử lý:**

```
# Kiểm tra tiến độ
/status

# Tiếp tục từ checkpoint
/wf-[tên-skill] --resume
```

### 2. Registry Bị Hỏng

**Triệu chứng:** Lỗi "JSON parse error" hoặc "Registry invalid".

**Cách xử lý:**

```
/wf-preflight --fix
```

### 3. Agent Bị Timeout

**Triệu chứng:** Skill bị treo, không có output.

**Cách xử lý:**

```
# Tiếp tục từ checkpoint
/wf-[tên-skill] --resume

# Hoặc bắt đầu lại
/wf-[tên-skill] --fresh
```

### 4. Output Thiếu Hoặc Sai

**Triệu chứng:** Files bị thiếu, nội dung không đầy đủ.

**Cách xử lý:**

```
# Kiểm tra chất lượng output
/audit-skill-output [tên-skill]

# Tự động sửa (mặc định)
/audit-skill-output [tên-skill]

# Chỉ báo cáo
/audit-skill-output [tên-skill] --no-fix
```

### 5. "Prerequisites Not Met"

**Triệu chứng:** Skill từ chối chạy vì thiếu điều kiện.

**Cách xử lý:**

- Kiểm tra bằng **điều kiện** ở từng bước trong hướng dẫn này
- Đảm bảo bước trước đã hoàn thành
- Dùng `/status` để xem trạng thái các phases

### 6. Dự Án Lớn Bị Chậm

**Triệu chứng:** Skills chạy rất lâu (>2 giờ).

**Cách xử lý:**

- DEVKIT tự động bật **Large Project Mode** khi:
  - > = 5 systems, hoặc
    >
  - > = 10 phòng ban, hoặc
    >
  - > = 50 requirements, hoặc
    >
  - > = 40 features
    >
- Dùng `--resume` thay vì chạy lại từ đầu
- Chia nhỏ scope: `scope=system --name=crm`

### 7. Hooks Bị Chặn

**Triệu chứng:** "Hook blocked" khi ghi file.

**Cách xử lý:**

- Đọc thông báo hook cung cấp
- Kiểm tra hook configuration trong `.claude/settings.json`
- Phổ biến: thiếu REQ-ID trong code file → thêm REQ-ID comment

---

## Phụ Lục

### A. Danh Sách Tất Cả Skills

| Skill                   | Lệnh                            | Mục đích                    |
| ----------------------- | -------------------------------- | ------------------------------ |
| wf-brainstorm           | `/wf-brainstorm`               | Chốt khung dự án            |
| wf-analyze-requirements | `/wf-analyze-requirements`     | Phân tích nghiệp vụ        |
| wf-define-features      | `/wf-define-features`          | Định nghĩa tính năng      |
| wf-design               | `/wf-design`                   | Thiết kế kiến trúc         |
| wf-design-ux            | `/wf-design-ux`                | Thiết kế UX/UI               |
| wf-plan-modules         | `/wf-plan-modules`             | Lập kế hoạch                |
| wf-implement-feature    | `/wf-implement-feature [name]` | Implement code                 |
| wf-preflight            | `/wf-preflight`                | Health check                   |
| wf-fix-bugs             | `/wf-fix-bugs [mô-tả]`       | Tìm và sửa lỗi (v5.0 pure orchestrator — delegate cho 3 sub-skills) |
| wf-fix-discover         | `/wf-fix-discover --resume`    | Session Init + Discovery engine *(spawned bởi wf-fix-bugs; user chỉ gọi khi `--resume`)* |
| wf-fix-triage           | `/wf-fix-triage --resume`      | Triage engine *(spawned bởi wf-fix-bugs; user chỉ gọi khi `--resume`)* |
| wf-fix-execute          | `/wf-fix-execute --resume`     | Fix + Verify + Report engine *(spawned bởi wf-fix-bugs; user chỉ gọi khi `--resume`)* |
| wf-verify-sync          | `/wf-verify-sync`              | Xác minh đồng bộ           |
| wf-prepare-deployment   | `/wf-prepare-deployment`       | Tài liệu triển khai         |
| wf-legacy-scan          | `/wf-legacy-scan [path]`       | Quét dự án có sẵn (all-in-one pipeline) |
| wf-legacy-classify      | `/wf-legacy-classify`          | Phân loại files (standalone hoặc resume) |
| wf-legacy-extract       | `/wf-legacy-extract`           | Trích xuất requirements (standalone hoặc resume) |
| wf-annotate-code        | `/wf-annotate-code [--module=<name>]` | Inject REQ-ID vào code  |
| wf-add-scope            | `/wf-add-scope --system=<id>` | Thêm modules vào registry (append-only) |
| wf-manage-change        | `/wf-manage-change "mô tả"` | Xử lý thay đổi tính năng |
| wf-scan-target          | `/wf-scan-target --target=<path\|url> [--module] [--compare] [--profile]` | **Standalone** — quét target (module/hệ thống/URL/path) → module-map, target-map.json, feature-inventory, gap-report (khi --compare) |
| new-project             | `/new-project`                 | Tự động — dự án mới     |
| existing-project        | `/existing-project`            | Tự động — dự án có sẵn |
| feature-addition        | `/feature-addition`            | Thêm tính năng              |
| status                  | `/status`                      | Xem tiến độ                 |
| audit-skill-output      | `/audit-skill-output`          | Kiểm tra chất lượng        |
| audit-devkit            | `/audit-devkit`                | Tự kiểm tra DEVKIT (orchestrator) |
| audit-devkit-scan       | `/audit-devkit-scan`           | Scan DEVKIT components theo batches |
| audit-devkit-verify     | `/audit-devkit-verify`         | Cross-validate references và workflow |
| audit-devkit-fix        | `/audit-devkit-fix`            | Auto-fix với per-fix verification |
| audit-agents            | `/audit-agents`                | Kiểm tra agents               |
| ui-ux-pro-max           | `/ui-ux-pro-max`               | UX nâng cao                   |

### B. Cấu Trúc Dữ Liệu

```
.mc-data/
├── docs/                          # Tài liệu chính thức
│   ├── _meta/
│   │   └── req-registry.json      # ★ Single Source of Truth
│   ├── phase0-brainstorm/         # Phase 0
│   ├── phase1-business/           # Phase 1
│   ├── phase2-features/           # Phase 2
│   ├── phase3-architecture/       # Phase 3
│   ├── phase4-ux/                 # Phase 4
│   ├── phase5-implementation/     # Phase 5
│   └── phase6-deployment/         # Phase 6
├── work/                          # Dữ liệu làm việc
│   └── [skill-name]/             # Working files per skill
├── sync/                          # REQ-ID tracking
└── knowledge-base/                # Ghi chú bổ sung
```

### C. REQ-ID và FEAT-ID Format

```
REQ-ID:
  Simple:  REQ-[DEPT]-[NNN]            → REQ-SALES-001
  Complex: REQ-[SYSTEM]-[MODULE]-[NNN] → REQ-CRM-CUST-001

FEAT-ID:
  FEAT-[SYS]-[MOD]-NNN                 → FEAT-CRM-CUST-001
```

Trong code file:

```typescript
// REQ-ID: REQ-SALES-001
// FEAT-ID: FEAT-CRM-001
export class CustomerService { ... }
```

### D. Các Trạng Thái impl_status

| Trạng thái    | Ý nghĩa                      |
| --------------- | ------------------------------ |
| `not_started` | Chưa bắt đầu (mặc định) |
| `in_progress` | Đang implement                |
| `done`        | Hoàn thành, tests pass       |
| `skipped`     | User chủ động bỏ qua       |

> **Quy tắc:** Không bao giờ downgrade từ "done" về trạng thái khác.

---

*Tài liệu này được tạo cho DEVKIT (MCV3). Cập nhật theo phiên bản mới nhất của bộ công cụ.*
