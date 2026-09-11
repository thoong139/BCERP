# Bộ Khung Tài Liệu Dự Án Phần Mềm

Bộ templates tài liệu chuẩn dùng cho toàn bộ quá trình phát triển dự án phần mềm —
từ giai đoạn thu thập yêu cầu nghiệp vụ đến triển khai và vận hành.

Mỗi file trong bộ này là một **mẫu** (template) — có sẵn cấu trúc và hướng dẫn,
chỉ cần điền thông tin thực tế của dự án vào.

---

## Cách Sử Dụng

> **Khi dùng DEVKIT:** DEVKIT tự động đọc templates này và tạo output vào `.mc-data/docs/`.
> Không cần copy thủ công — chỉ chạy các skills (`/wf-brainstorm`, `/wf-analyze-requirements`, v.v.).
>
> **Khi dùng thủ công (không qua DEVKIT):**

1. **Copy** các file template phase cần dùng (`.md` files) vào thư mục project — **không copy** `_meta/` và `_contract.json`
2. **Đổi tên** thành `docs/` hoặc tên phù hợp với dự án
3. **Điền thông tin** vào từng file theo giai đoạn, theo đúng thứ tự 7 giai đoạn (Phase 0-6)
4. **Đổi tên** file/folder có `[...]` trong tên thành tên thực tế — ví dụ:
   - `departments/[dept-name]/` → `departments/sales/`
   - Trong folder: `[dept-name].md` → `sales.md` (Phần A: User Needs + Phần B: Workflow)
   - `phase2-features/[system-name]/` → `phase2-features/crm/`
   - `phase2-features/crm/[module-name]/` → `phase2-features/crm/customer-management/`
   - `[feature-name].md` → `customer-list.md`
   - `phase4-ux/[system-name]/` → `phase4-ux/crm/`
   - `phase4-ux/crm/Navigation-[system].md` → `phase4-ux/crm/Navigation-crm.md`
   - `phase4-ux/crm/[module-name]/` → `phase4-ux/crm/customer-management/`
   - `[screen-group].md` → `customer-list.md`

> Mỗi file đều có phần hướng dẫn viết in nghiêng `*như thế này*` — đây là hướng dẫn điền,
> không phải nội dung thực tế. **Xóa đi sau khi đã điền.**

---

## Cấu Trúc Tài Liệu

```
doc-framework/
│
├── README.md                                  ← File này
│
├── _meta/                                     ← Thông tin quản lý framework (dùng bởi DEVKIT — không copy vào project)
│   ├── req-registry.json                      ← Template registry — single source of truth cho tất cả IDs
│   ├── definition-of-done.md                  ← DoD checklist per phase — POST-GATE validation (quality gate reference; dùng bởi /wf-preflight và /wf-verify-sync)
│   ├── deferred-findings-template.md          ← Template ghi lại findings defer sang skill tiếp theo (dùng bởi /wf-define-features và /wf-design)
│   ├── deferred-issues-template.md            ← Template ghi lại issues mở để xử lý sau (dùng bởi /wf-analyze-requirements Phase 6d)
│   ├── dependency-graph.md                    ← Thứ tự phụ thuộc giữa các file (Mermaid)
│   └── dependency-detail-map.md               ← Chi tiết phụ thuộc & quy tắc kiểm tra field-level
│
├── phase0-brainstorm/                          ← GIAI ĐOẠN 0: Brainstorm — chốt khung dự án
│   ├── _contract.json                         ← Validation contract — required sections per template (dùng bởi DEVKIT)
│   ├── P0-01-brainstorm.md                    ← Thông tin tổ chức, phòng ban, phân hệ, đối tượng người dùng theo hệ thống, chính sách nghiệp vụ & tuân thủ
│   ├── P0-02-systems-users.md                 ← Bản đồ hệ thống, users & roles, NFR, tech stack
│   ├── policies/                              ← Chính sách nghiệp vụ do domain experts soạn (nếu còn thiếu)
│   │   └── _policy-template.md                ← Template cho policy documents
│   └── stakeholder-review.md                  ← Rà soát & đánh giá Phase 0 (Phần A-D)
│
├── phase1-business/                           ← GIAI ĐOẠN 1: Nghiệp vụ
│   ├── _contract.json                         ← Validation contract (dùng bởi DEVKIT)
│   ├── P1-01-project-overview.md              ← Tổng quan dự án
│   ├── P1-02-business-workflow.md             ← Quy trình kinh doanh tổng thể
│   ├── departments/                           ← Tài liệu theo phòng ban
│   │   ├── _index.md                          ← Tổng hợp trạng thái & nhu cầu
│   │   └── [dept-name]/                       ← Mỗi phòng ban 1 folder
│   │       └── [dept-name].md                 ← Phần A: Nhu cầu + Phần B: Quy trình
│   └── stakeholder-review.md                  ← Rà soát & đánh giá Phase 1 (Phần A-D)
│
├── phase2-features/                           ← GIAI ĐOẠN 2: Đặc tả tính năng
│   ├── _contract.json                         ← Validation contract (dùng bởi DEVKIT)
│   ├── [system-name]/                         ← Mỗi phân hệ 1 folder
│   │   └── [module-name]/                     ← Mỗi module 1 folder
│   │       └── [feature-name].md              ← Thiết kế chi tiết từng tính năng
│   └── stakeholder-review.md                  ← Rà soát & đánh giá Phase 2 (Phần A-D)
│
├── phase3-architecture/                       ← GIAI ĐOẠN 3: Kiến trúc & Đặc tả kỹ thuật
│   ├── _contract.json                         ← Validation contract (dùng bởi DEVKIT)
│   ├── P3-01-architecture.md                  ← Kiến trúc tổng thể hệ thống
│   ├── technical-specs/                       ← Đặc tả kỹ thuật
│   │   ├── api-contract.md                    ← Đặc tả API toàn hệ thống
│   │   ├── database-design.md                 ← Thiết kế cơ sở dữ liệu
│   │   ├── integration-map.md                 ← Tích hợp & quy tắc xuyên phân hệ
│   │   └── infra-spec.md                      ← Hạ tầng & môi trường
│   └── stakeholder-review.md                  ← Rà soát & đánh giá Phase 3 (Phần A-D)
│
├── phase4-ux/                                 ← GIAI ĐOẠN 4: Thiết kế UX/UI (conditional)
│   ├── _contract.json                         ← Validation contract (dùng bởi DEVKIT)
│   ├── design-system.md                       ← Hệ thống thiết kế (màu, font, layout)
│   ├── [system-name]/                         ← Mỗi phân hệ 1 folder
│   │   ├── Navigation-[system].md             ← Sơ đồ menu + danh sách screen groups
│   │   └── [module-name]/                     ← Mỗi module 1 folder
│   │       └── [screen-group].md              ← Nhóm màn hình (page + tabs + dialogs + sheets)
│   └── stakeholder-review.md                  ← Rà soát & đánh giá Phase 4 (Phần A-D)
│
├── phase5-implementation/                     ← GIAI ĐOẠN 5: Kế hoạch triển khai & theo dõi
│   ├── _contract.json                         ← Validation contract (dùng bởi DEVKIT)
│   ├── P5-00-implementation-roadmap.md        ← Lộ trình triển khai tổng thể
│   ├── sprints/                               ← Sprint planning
│   │   ├── _index.md                          ← Dashboard tiến độ sprint
│   │   └── S0X-[sprint-name].md              ← Kế hoạch từng sprint
│   ├── tasks/                                 ← Task breakdown chi tiết
│   │   └── [system]/                          ← Mỗi phân hệ 1 folder
│   │       └── [module]/                      ← Mỗi module 1 folder
│   │           └── [feature]-impl.md          ← Phần A: Kế hoạch + Phần B: Checklist
│   └── stakeholder-review.md                  ← Rà soát & đánh giá Phase 5 (Phần A-D)
│
└── phase6-deployment/                         ← GIAI ĐOẠN 6: Vận hành
    ├── _contract.json                         ← Validation contract (dùng bởi DEVKIT)
    ├── deployment-guide.md                    ← Dành cho **ops team** — hướng dẫn triển khai hạ tầng, cấu hình, rollback
    ├── user-guide.md                          ← Dành cho **end users** — hướng dẫn sử dụng tính năng, workflows, FAQ
    ├── incident-response-runbook.md           ← Dành cho **on-call engineers** — xử lý sự cố, escalation, rollback procedures
    └── stakeholder-review.md                  ← Rà soát & đánh giá Phase 6 (Phần A-D)
```

> **Lưu ý về file DEVKIT-internal:** Các file `_contract.json` (mỗi phase) và toàn bộ thư mục `_meta/` là
> dành cho DEVKIT framework sử dụng nội bộ — để validate output và track state. Khi DEVKIT
> chạy, chúng được đọc từ `.claude/doc-framework/`, **không copy** vào thư mục project.

---

## Quy Trình 7 Giai Đoạn (Phase 0-6)

```
GIAI ĐOẠN 0 — BRAINSTORM
  Skill: /wf-brainstorm
  Ai thực hiện: Quản lý dự án, Chủ dự án, Tech Lead
  Viết cho: Tất cả thành viên dự án (ngôn ngữ đơn giản)

     P0-01 Thông tin tổ chức & phạm vi   ← Org info, phòng ban, phân hệ, đối tượng người dùng theo hệ thống, chính sách nghiệp vụ & tuân thủ
     P0-02 Bản đồ hệ thống & người dùng  ← Systems map, users & roles, NFR, tech stack (ĐỌC P0-01 trước → P0-02 phân tích tiếp)
     policies/ Chính sách nghiệp vụ      ← Domain experts soạn cho mục "Chưa có"/"Có 1 phần" từ P0-01
     stakeholder-review.md                ← Rà soát & đánh giá Phase 0 (Phần A-D)
                    ↓
GIAI ĐOẠN 1 — NGHIỆP VỤ
  Skill: /wf-analyze-requirements
  Ai thực hiện: BA, đại diện phòng ban, Domain Experts
  Viết cho: Tất cả thành viên dự án (ngôn ngữ nghiệp vụ)

     P1-01 Tổng quan dự án
     P1-02 Quy trình kinh doanh         ← Mô hình vận hành toàn doanh nghiệp
     departments/
       [dept-name]/                   ← Tạo 1 folder / phòng ban
         [dept-name].md              ← Phần A: Nhu cầu + Phần B: Quy trình
     stakeholder-review.md             ← Rà soát & đánh giá Phase 1 (Phần A-D)
                    ↓
GIAI ĐOẠN 2 — ĐẶC TẢ TÍNH NĂNG
  Skill: /wf-define-features
  Ai thực hiện: Tech Lead, BA
  Viết cho: Developer và AI để thiết kế kỹ thuật

     phase2-features/
       [system]/[module]/
         [feature].md                 ← Đặc tả chi tiết từng tính năng
     stakeholder-review.md             ← Rà soát & đánh giá Phase 2 (Phần A-D)
                    ↓
GIAI ĐOẠN 3 — KIẾN TRÚC & ĐẶC TẢ KỸ THUẬT
  Skill: /wf-design (refactored)
  Ai thực hiện: Tech Lead, Kiến trúc sư, Developer
  Viết cho: Developer (ngôn ngữ kỹ thuật)

     P3-01 Kiến trúc hệ thống
     technical-specs/ Đặc tả API, Database, Tích hợp, Hạ tầng
     stakeholder-review.md             ← Rà soát & đánh giá Phase 3 (Phần A-D)
                    ↓
GIAI ĐOẠN 4 — UX/UI (CONDITIONAL — chỉ khi interface_type = web/mobile)
  Skill: /wf-design-ux
  Ai thực hiện: UX Designer
  Bỏ qua nếu: interface_type = api-only → nhảy thẳng sang Giai đoạn 5

     design-system.md                  ← Hệ thống thiết kế
     [system]/Navigation-[system].md   ← Sơ đồ điều hướng
     [system]/[module]/[screen].md     ← Thiết kế từng màn hình
     stakeholder-review.md             ← Rà soát & đánh giá Phase 4 (Phần A-D)
                    ↓
GIAI ĐOẠN 5 — KẾ HOẠCH TRIỂN KHAI
  Skill: /wf-plan-modules
  Ai thực hiện: Tech Lead, Developer
  Viết cho: Developer thực thi (kế hoạch chi tiết + checklist)

     P5-00 Implementation Roadmap      ← Lộ trình tổng thể
     sprints/ Sprint planning          ← Kế hoạch từng sprint
     tasks/ Task breakdown
       [system]/[module]/
         [feature]-impl.md            ← Phần A: Kế hoạch + Phần B: Checklist
     stakeholder-review.md             ← Rà soát & đánh giá Phase 5 (Phần A-D)
                    ↓
GIAI ĐOẠN 6 — VẬN HÀNH
  Skill: /wf-prepare-deployment
  Ai thực hiện: DevOps, Tech Lead, QA
  Hoàn thành khi gần đến giai đoạn triển khai

     deployment-guide (incl. Account Mgmt + Maintenance)  user-guide  incident-response-runbook
     stakeholder-review.md             ← Rà soát & đánh giá Phase 6 (Phần A-D)
```

### Skills → Phase Mapping

| Phase | Skill | Purpose | Outputs |
|-------|-------|---------|---------|
| 0 | `/wf-brainstorm` | Brainstorm — chốt khung dự án | P0-01, P0-02, policies/, stakeholder-review |
| 1 | `/wf-analyze-requirements` | Business analysis | P1-01, P1-02, departments/, stakeholder-review |
| 2 | `/wf-define-features` | Feature specifications | phase2-features/**/*, stakeholder-review |
| 3 | `/wf-design` (refactored) | Architecture + technical specs | P3-01, technical-specs/*, stakeholder-review |
| 4 | `/wf-design-ux` (conditional) | UX/UI design | design-system, Navigation-*, screens, stakeholder-review |
| 5 | `/wf-plan-modules` | Implementation planning | P5-00, sprints/, tasks/, stakeholder-review |
| 6 | `/wf-prepare-deployment` | Deployment docs | deployment-guide, user-guide, incident-runbook, stakeholder-review |

> **Phase 4 CONDITIONAL:** Chỉ chạy khi `interface_type` = `web` / `mobile` / `web+mobile`.
> Nếu `api-only` → bỏ qua Phase 4, chuyển thẳng sang Phase 5.

### Phase 5: Implementation Planning

Phase 5 là cầu nối giữa **Technical Design** và **Code Implementation**:

| Mục đích | Mô tả |
|----------|-------|
| **Kế hoạch chi tiết** | Chuyển design → tasks có thể thực hiện |
| **Context management** | Chia nhỏ công việc để AI không bị overflow |
| **Progress tracking** | Checklist trạng thái từng task |
| **Resume capability** | Có thể tiếp tục từ điểm dừng |

**Task Hierarchy (3 levels):**
```
EPIC (Feature)              ← phase2-features/
└── STORY (User Story)      ← 1 story = 1 business value
    └── TASK (Implementation) ← 1 task = 1 file/operation
```

**Workflow với implement-feature:**
```
/wf-design → /wf-define-features → [feature]-impl.md (Phần A: Plan + Phần B: Tasks)
    ↓
/wf-implement-feature FEAT-XXX
    ↓
Đọc plan → Execute batch → Update tasks → Checkpoint khi cần
```

---

## Hệ Thống Mã Theo Dõi (REQ-ID)

Mỗi yêu cầu được gán mã duy nhất để theo dõi từ tài liệu nghiệp vụ đến code:

| Loại | Định dạng | Ví dụ |
|------|----------|-------|
| Yêu cầu nghiệp vụ | `REQ-[PHÒNG_BAN]-[STT]` | `REQ-SALES-001` |
| Module kỹ thuật | `MOD-[PHÂN_HỆ]-[MODULE]` | `MOD-CRM-CUST` |
| Tính năng kỹ thuật | `FEAT-[PHÂN_HỆ]-[MODULE]-[STT]` | `FEAT-CRM-CUST-001` |
| Màn hình UI (main) | `UI-[PHÂN_HỆ]-[MODULE]-[SCREEN]-[STT]` | `UI-CRM-CUST-LIST-001` |
| Tab trong màn hình | `UI-...-SCREEN]-[STT]-T[N]` | `UI-CRM-CUST-DETAIL-001-T1` |
| Dialog/Popup | `UI-...-SCREEN]-[STT]-D[N]` | `UI-CRM-CUST-LIST-001-D1` |
| Sheet/Drawer | `UI-...-SCREEN]-[STT]-S[N]` | `UI-CRM-CUST-LIST-001-S1` |
| View Mode | `UI-...-SCREEN]-[STT]-M[N]` | `UI-CRM-PIPE-PIPE-001-M1` |
| API Endpoint | `API-[PHÂN_HỆ]-[MODULE]-V1-[STT]` | `API-CRM-CUST-V1-001` |
| Bảng dữ liệu | `DB-[PHÂN_HỆ]-[MODULE]-[STT]` | `DB-CRM-CUST-001` |

**Luồng theo dõi:**
```
REQ-SALES-001  →  FEAT-CRM-CUST-001  →  UI-CRM-CUST-LIST-001
                                      →  API-CRM-CUST-V1-001
                                      →  DB-CRM-CUST-001
                                      →  // REQ-ID: REQ-SALES-001 (trong code)
```

---

## Nguyên Tắc Của Bộ Tài Liệu

| Nguyên tắc | Giải thích |
|-----------|-----------|
| **Đúng đối tượng** | Phase 1 viết cho người nghiệp vụ — không có thuật ngữ kỹ thuật. Phase 3 viết cho developer — đầy đủ chi tiết kỹ thuật |
| **Tối giản nhưng đủ** | Chỉ ghi những gì cần thiết — không thừa, không thiếu |
| **Có thể tra cứu** | Mỗi tài liệu độc lập, dễ tìm lại thông tin cụ thể |
| **Dễ cập nhật** | Mỗi file nhỏ, tập trung 1 chủ đề — thay đổi không ảnh hưởng file khác |
| **Liên kết được** | REQ-ID giúp truy vết từ yêu cầu nghiệp vụ đến code |

---

> **Lưu ý:** File `stakeholder-review.md` là **BẮT BUỘC** trong Phase 0-6.
> Mỗi phase phải có stakeholder-review.md với Phần A (Dashboard), Phần B (Cross-Review), Phần C (Consistency Check), Phần D (Gap Analysis).
> Các skill `/wf-brainstorm`, `/wf-analyze-requirements`, `/wf-define-features`, `/wf-design`, `/wf-design-ux`, `/wf-plan-modules` và `/wf-prepare-deployment` đều tạo stakeholder-review cho phase tương ứng.

---

## AI Reading Guide

> AI phải đọc section này TRƯỚC KHI thực hiện bất kỳ task nào trong dự án.

---

### Nguyên Tắc Bắt Buộc

```
1. KHÔNG implement tính năng không có trong tài liệu phase2-features/
2. KHÔNG tạo REQ-ID mới — chỉ dùng IDs từ req-registry.json
3. KHÔNG đọc thẳng database của system khác — chỉ qua API hoặc Event
4. MỌI code file phải có REQ-ID comment ở đầu file
5. `.claude/rules/` phải đọc TRƯỚC KHI viết bất kỳ dòng code nào
```

---

### Thứ Tự Đọc Theo Task

| Task | Đọc theo thứ tự |
|------|----------------|
| **Brainstorm / Khám phá** | `README.md` (AI Reading Guide) → `P0-01-brainstorm` → `P0-02-systems-users` → `policies/*` (nếu có) → `stakeholder-review` |
| **Phân tích nghiệp vụ** | `README.md` → `P0-01` → `P1-01` → `P1-02` → `departments/[dept]/[dept].md` → `departments/_index` |
| **Stakeholder review** | `P1-01` → `P1-02` → all `departments/*/` → `stakeholder-review.md` (Phần B-D) |
| **Implement feature** | `README.md` → `P1-01` → `departments/[dept]/[dept].md` → `P3-01-architecture` → `req-registry.json` → `phase2-features/[sys]/[mod]/[feat]` → `api-contract` → `database-design` → `.claude/rules/` (auto-loaded) |
| **Design UI screen** | `P3-01-architecture` → `phase2-features/[sys]/[mod]/[feat]` → `phase4-ux/design-system` → `phase4-ux/[sys]/Navigation-[sys]` → `phase4-ux/[sys]/[mod]/[screen-group]` → `.claude/rules/` (auto-loaded) |
| **Implement i18n** | `.claude/rules/04-i18n.md` → thiết kế translation keys → implement translation hooks |
| **Add new locale** | `.claude/rules/04-i18n.md` → tạo file `messages/[locale].json` → thêm locale vào `SUPPORTED_LOCALES` config |
| **Write API** | `P3-01-architecture` → `phase2-features/[sys]/[mod]/[feat]` → `api-contract` → `integration-map` → `.claude/rules/` (auto-loaded) |
| **Setup database** | `P3-01-architecture` → `database-design` → `req-registry.json` → `phase2-features/[sys]/[mod]/*` → `.claude/rules/` (auto-loaded) |
| **Fix bug** | Tìm FEAT-ID → `phase2-features/[sys]/[mod]/[feat]` → `.claude/rules/` → fix |
| **Design navigation/menu** | `P3-01-architecture` → `req-registry.json` (systems[], modules[]) → `phase4-ux/[sys]/Navigation-[sys]` |
| **Deploy** | `phase3-architecture/technical-specs/infra-spec` → `phase6-deployment/deployment-guide` |
| **Add new system** | `P1-01` → `P3-01-architecture` → `integration-map` |
| **Add new module** | `P3-01-architecture` → `req-registry.json` → tạo `phase2-features/[sys]/[mod]/` + `phase4-ux/[sys]/[mod]/` |

---

### Markers Trong Tài Liệu

| Marker | Ý nghĩa | Hành động của AI |
|--------|---------|--------------------|
| `[REQUIRED]` | Bắt buộc implement | Luôn implement, không skip |
| `[OPTIONAL]` | Có thể bỏ qua ở MVP | Hỏi trước khi bỏ |
| `[FUTURE]` | Scope tương lai | Không implement, chỉ ghi comment |
| `[BLOCKED-BY: X]` | Phụ thuộc item X | Implement X trước |
| `⚠️ CRITICAL` | Quan trọng tuyệt đối | Đọc kỹ, không bỏ qua |
| `📌 NOTE` | Context bổ sung | Đọc và ghi nhớ |
| `🔄 INTEGRATION` | Ảnh hưởng system khác | Check integration-map.md |

---

### Convention REQ-ID Trong Code

```typescript
// ✅ ĐÚNG — comment REQ-ID đầu mỗi file code
// REQ-ID: REQ-SALES-001
// FEAT-ID: FEAT-CRM-CUST-001
export class CustomerService { ... }

// ✅ ĐÚNG — nhiều REQ-IDs nếu file cover nhiều requirements
// REQ-ID: REQ-SALES-001, REQ-SALES-002
// FEAT-ID: FEAT-CRM-CUST-001

// ❌ SAI — thiếu REQ-ID comment
export class CustomerService { ... }
```

---

### Quy Tắc Cross-System

```
✅ ĐƯỢC:  SystemA gọi REST API /internal/ của SystemB
✅ ĐƯỢC:  SystemA publish event, SystemB subscribe và xử lý
✅ ĐƯỢC:  SystemA đọc data của mình từ DB của mình

❌ CẤM:  SystemA query thẳng vào DB schema của SystemB
❌ CẤM:  SystemA import code từ SystemB (nếu là microservices)
❌ CẤM:  Duplicate business logic ở nhiều system
```

---

### Checklist Trước Khi Commit Code

```
□ SEC-001: Mọi API endpoint có auth middleware
□ SEC-004: Validate ALL inputs tại controller
□ SEC-008: Không hardcode credentials
□ SEC-010: .env không được commit
□ REQ-ID comment có mặt ở đầu mỗi file code
□ Unit tests đã viết cho business logic
□ Error handling đúng pattern trong dev-rules.md
□ API response đúng format từ api-contract.md
```

---

### Checklist Verify Sync (Phát Hiện Thiếu Sót)

> Xem chi tiết: `README.md` (Verify Sync section bên dưới)

**Trước khi chuyển Phase:**
```
□ Phase 0 → 1: P0-01 đã điền đầy đủ, P0-02 đã phân tích, policies/ đã soạn (nếu cần), stakeholder-review đã hoàn thành
□ Phase 1 → 2: REQ-IDs trong registry = REQ-IDs trong files
□ Phase 2 → 3: Mọi FEAT có API, DB mapped
□ Phase 3 → 4: Kiến trúc đã approved (conditional: có UI)
□ Phase 4 → 5: Mọi screen group có file tương ứng (conditional: có UI)
```

**Cross-reference integrity:**
```
□ Không có placeholder text (*như thế này*) chưa xóa
□ Không có link gãy (file A → file B không tồn tại)
□ Mọi ID trong registry có file tương ứng
```

**Quick check commands:**
```bash
# Tìm placeholder chưa xóa
grep -r "\*như thế này\*" --include="*.md" .

# Tìm REQ-ID không match registry
grep -roh "REQ-[A-Z]*-[0-9]*" . | sort | uniq
```

---

## Verify Sync Checklist

> ⚠️ **CRITICAL:** Chạy checklist này TRƯỚC KHI bắt đầu implement và SAU KHI hoàn thành mỗi phase.

---

### 1. Phase 0 → Phase 1 Gate

**Chạy trước khi chuyển từ Phase 0 sang Phase 1:**

```
□ P0-01-brainstorm.md đã điền đầy đủ
  □ Có ít nhất 1 phòng ban được xác định
  □ Danh sách phân hệ và phân giai đoạn đã chốt
  □ Đối tượng người dùng theo hệ thống đã xác định (Section 4 — architect + BA phân tích)
  □ Compliance & tuân thủ pháp lý đã được phân tích (legal-expert)
  □ Chính sách nghiệp vụ đã kiểm kê (Section 5.2 — user đánh dấu trạng thái)
□ P0-02-systems-users.md đã điền đầy đủ
  □ Danh sách hệ thống (số lượng app/system riêng biệt) đã chốt
  □ interface_type đã xác định (web / mobile / web+mobile / api-only)
  □ Danh sách roles toàn hệ thống đã chốt
  □ NFR cơ bản đã ước tính (scale, availability)
  □ Tech stack đề xuất hoặc ràng buộc đã ghi nhận
□ policies/ — Chính sách còn thiếu đã được agents soạn thảo
  □ Mỗi mục "Chưa có"/"Có 1 phần" trong P0-01.Section5.2 → có file policy
  □ Mỗi policy đã được user xác nhận (Section 5 trong file policy)
□ stakeholder-review.md — Đã hoàn thành 3 góc review
  □ Phần B (Cross-Document Review) — P0-01 ↔ P0-02 nhất quán
  □ Phần C (Consistency Check) — thuật ngữ, số liệu, phạm vi nhất quán
  □ Phần D (Gap Analysis) — không còn gap nghiêm trọng
  □ Tất cả vấn đề trong A.3 đã xử lý xong
```

---

### 2. Phase 1 → Phase 2 Gate

**Chạy trước khi bắt đầu đặc tả tính năng:**

#### 2.1. REQ Completeness

```bash
# Kiểm tra: Mọi REQ trong req-registry.json có file tương ứng?
grep -l "REQ-" phase1-business/departments/*/[dept].md

# So sánh với req-registry.json
```

```
□ req-registry.json có đầy đủ REQ-IDs từ các file [dept].md
□ Mọi REQ trong registry có:
  □ title
  □ dept
  □ priority
  □ mapped_features[] (nếu đã map)
□ Không có REQ trùng ID
```

#### 2.2. Department Files Completeness

```
□ Mỗi department có file [dept].md:
  □ Phần A: User Needs
  □ Phần B: Workflow
□ departments/_index.md đã tổng hợp
```

---

### 3. Phase 2 → Phase 3 Gate

**Chạy trước khi thiết kế kiến trúc:**

#### 3.1. Feature ↔ REQ Mapping

```
□ Mọi FEAT-ID trong req-registry.json có file phase2-features/[sys]/[mod]/[feat].md
□ Mọi feature file có:
  □ FEAT-ID header
  □ req_ids[] tham chiếu đến REQ hợp lệ
  □ Không circular dependency (A phụ thuộc B, B phụ thuộc A)
```

---

### 4. Phase 3 Internal Consistency

**Chạy trước khi design UX hoặc plan-modules:**

#### 4.1. API ↔ Database Mapping

```
□ Mọi API endpoint trong api-contract.md có:
  □ API-ID
  □ request/response schema
  □ database tables tham chiếu (nếu có)
□ Mọi DB table trong database-design.md có:
  □ DB-ID
  □ columns với data types
  □ indexes (nếu cần)
```

---

### 5. Phase 4 Internal Consistency (Conditional)

**Chạy khi interface_type = web/mobile/web+mobile:**

#### 5.1. UI ↔ Feature Mapping

```
□ Mọi screen_group trong req-registry.json có file phase4-ux/[sys]/[mod]/[screen-group].md
□ Mọi screen-group file có:
  □ UI-ID header
  □ feat_ids[] tham chiếu đến FEAT hợp lệ
  □ api_endpoints[] (nếu có action gọi API)
```

#### 5.2. Navigation ↔ Screen Groups

```
□ Mọi screen group trong Navigation-[sys].md có file tồn tại
□ Mọi route trong Navigation có trong danh sách screen groups
□ Không có orphan screens (screen không nằm trong Navigation)
```

---

### 6. Phase 4/3 → Phase 5 Gate

**Chạy trước khi bắt đầu code:**

```
□ Tất cả FEAT có status khác PENDING trong req-registry.json
□ api-contract.md có đầy đủ endpoints cho các features cần
□ database-design.md có đầy đủ tables cho các features cần
□ (Nếu có UI) Tất cả UI screen groups đã có đầy đủ Layout, Components, Actions
```

---

### 7. Cross-Reference Integrity

**Kiểm tra links không bị gãy:**

```bash
# Tìm tất cả references đến file .md
grep -roh "\[.*\](.*\.md)" --include="*.md" | sort | uniq
```

```
□ Không có reference đến file không tồn tại
□ Không có reference đến REQ-ID / FEAT-ID / UI-ID không có trong req-registry.json
□ Navigation files không reference đến screen-group files không tồn tại
```

---

### 8. Pre-Commit Checklist

**Chạy trước mỗi commit:**

```
□ Không có file với placeholder text (*như thế này*)
□ Không có TODO / FIXME chưa xử lý
□ req-registry.json đã cập nhật nếu có ID mới
□ Cross-references không bị gãy
```

---

### Quick Validation Commands

```bash
# Tìm placeholder text chưa xóa
grep -r "\*như thế này\*\|\[VD:" --include="*.md" .

# Tìm REQ-ID không có trong registry
grep -roh "REQ-[A-Z]*-[0-9]*" phase1-business/ | sort | uniq > /tmp/reqs_in_files.txt
jq -r '.requirements[].id' _meta/req-registry.json > /tmp/reqs_in_registry.txt
diff /tmp/reqs_in_files.txt /tmp/reqs_in_registry.txt

# Tìm FEAT-ID không có trong registry
grep -roh "FEAT-[A-Z]*-[A-Z]*-[0-9]*" phase2-features/ | sort | uniq > /tmp/feats_in_files.txt
jq -r '.features[].id' _meta/req-registry.json > /tmp/feats_in_registry.txt
diff /tmp/feats_in_files.txt /tmp/feats_in_registry.txt

# Tìm UI-ID không có trong registry
grep -roh "UI-[A-Z]*-[A-Z]*-[A-Z]*-[0-9]*" phase4-ux/ | sort | uniq > /tmp/uis_in_files.txt
jq -r '.screen_groups[].id' _meta/req-registry.json > /tmp/uis_in_registry.txt
diff /tmp/uis_in_files.txt /tmp/uis_in_registry.txt

# Tìm broken links
grep -roh '\[.*\](.*\.md)' --include="*.md" . | grep -v "http" | while read link; do
  file=$(echo "$link" | sed 's/.*(\(.*\.md\))/\1/')
  if [ ! -f "$file" ]; then
    echo "Broken link: $file"
  fi
done
```

---

## Glossary

> Điền vào bảng này khi dự án có thuật ngữ domain-specific.
> AI phải đọc section này để hiểu đúng ngữ nghĩa của các từ trong tài liệu.

---

### Thuật Ngữ Framework (Cố định — không thay đổi)

| Thuật ngữ | Định nghĩa |
|-----------|-----------|
| **System** | Một subsystem/service trong dự án (VD: CRM, ERP, HRM) |
| **Module** | Nhóm tính năng liên quan trong một system (VD: Customer, Order) |
| **Feature** | Một tính năng cụ thể có thể implement (VD: Customer CRUD) |
| **REQ-ID** | ID duy nhất của một business requirement (VD: REQ-SALES-001) |
| **FEAT-ID** | ID duy nhất của một feature spec (VD: FEAT-CRM-001) |
| **Actor** | Người dùng hoặc vai trò tương tác với hệ thống |
| **Business Rule (BR)** | Quy tắc nghiệp vụ bắt buộc phải tuân theo |
| **Acceptance Criteria (AC)** | Điều kiện để requirement được coi là hoàn thành |
| **Soft delete** | Xóa bằng cách set deleted_at, không xóa thật khỏi DB |
| **Internal API** | API chỉ dùng giữa các services, không expose ra ngoài |
| **Event** | Thông điệp async khi có sự kiện xảy ra (VD: order.created) |
| **Owner system** | System có quyền write data, các system khác chỉ được read |

---

### Thuật Ngữ Dự Án (Điền theo từng dự án)

| Thuật ngữ | Định nghĩa | Hệ thống |
|-----------|-----------|---------|
| `[TERM_1]` | [Định nghĩa] | [SYS-XX] |
| `[TERM_2]` | [Định nghĩa] | [SYS-XX] |

**Ví dụ:**

| Thuật ngữ | Định nghĩa | Hệ thống |
|-----------|-----------|---------|
| KH | Khách hàng | CRM |
| ĐH | Đơn hàng | CRM, ERP |
| CLOSED_WON | Deal đã chốt thành công, tạo invoice | CRM |
| Pipeline | Luồng theo dõi deal từ lead → close | CRM |
| GL | General Ledger — sổ cái kế toán | ERP |

---

### Enums Dùng Chung (Shared Enums)

> ⚠️ CRITICAL: Các enum này phải được dùng GIỐNG NHAU ở mọi system.
> Không tự đặt enum values khác nhau ở từng system.

| Enum | Values | Ghi chú |
|------|--------|---------|
| `[ENUM_NAME]` | `VALUE_1 \| VALUE_2 \| VALUE_3` | [Mô tả] |

**Ví dụ:**

| Enum | Values |
|------|--------|
| `OrderStatus` | `PENDING \| CONFIRMED \| PAID \| SHIPPING \| DELIVERED \| CANCELED` |
| `UserRole` | `ADMIN \| MANAGER \| STAFF \| VIEWER` |
| `Priority` | `HIGH \| MEDIUM \| LOW` |
| `Currency` | `VND \| USD` |

---

### Viết Tắt

| Viết tắt | Đầy đủ |
|----------|--------|
| CRM | Customer Relationship Management |
| ERP | Enterprise Resource Planning |
| HRM | Human Resource Management |
| MVP | Minimum Viable Product |
| BR | Business Rule |
| AC | Acceptance Criteria |
| REQ | Requirement |
| FEAT | Feature |
| NFR | Non-Functional Requirement |
| DDL | Data Definition Language (SQL CREATE TABLE) |
| ADR | Architecture Decision Record |
| [Thêm viết tắt dự án vào đây] | |
