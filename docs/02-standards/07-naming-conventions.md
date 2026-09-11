# 07 — Naming Conventions (BẮT BUỘC)

> **Mức độ ràng buộc:** BẮT BUỘC (CORE-005, CORE-015, CORE-016, CORE-017, CORE-018)
> **File gốc canonical:** [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §3 + §4
> **Mục đích:** Quy định cách đặt tên skill, agent, file, folder, REQ-ID, FEAT-ID, session-ID, slug — đảm bảo nhất quán toàn MCV3

---

## 1. Triết lý — tại sao cần convention?

Trong MCV3 có nhiều thực thể tham chiếu nhau qua **string ID**:
- Skill A đọc registry entry có `id: "REQ-CRM-001"` → tìm code có comment `// REQ-ID: REQ-CRM-001`
- Folder `phase2-features/[sys]/[mod]/[feat].md` — slug PHẢI khớp REQ-ID structure
- `subagent_type: "business-analyst"` (kebab-case) khớp tên file `business-analyst.md`

**Một skill viết `REQ-Sales-001`, skill khác đọc `REQ-SALES-001`** → audit fail, code không truy vết được.

CORE-015..018 chốt: **lowercase-kebab-case là chuẩn duy nhất cho mọi naming** (trừ ID có cấu trúc).

---

## 2. Skill names

### 2.1. Folder name = command name (không có `/`)

```
.claude/skills/workflow/wf-fix-bugs/SKILL.md
                       └─ folder name
```

Slash command: `/wf-fix-bugs` → folder `wf-fix-bugs/`.

### 2.2. Prefix bắt buộc

| Prefix | Loại skill | Vị trí |
|--------|-----------|--------|
| `wf-` | Workflow chính | `.claude/skills/workflow/wf-*/` |
| `wf-fix-` | Fix sub-skills (lane QD1-QD11) | `.claude/skills/workflow/wf-fix-*/` |
| `wf-e2e-` | E2E testing pipeline | `.claude/skills/workflow/wf-e2e-*/` |
| `wf-legacy-` | Legacy project handling | `.claude/skills/workflow/wf-legacy-*/` |
| (không prefix) | Standalone | `.claude/skills/workflow/{name}/` (vd: `status`) |
| (không prefix) | Orchestrator workflows | `.claude/skills/workflows/{name}/` (vd: `new-project`) |

### 2.3. Quy tắc tên

- ✅ `wf-implement-feature` (lowercase, kebab, mô tả rõ)
- ✅ `wf-fix-runtime-health` (multi-word OK với dấu `-`)
- ❌ `WF-Implement-Feature` (UPPERCASE)
- ❌ `wf_implement_feature` (snake_case)
- ❌ `wfImplementFeature` (camelCase)
- ❌ `wf-impl-feat` (viết tắt quá đà — phải đọc-hiểu được)
- ❌ `wf-implement-feature-v2` (version trong folder name — đặt vào `version` field trong SKILL.md/`_contract.json`)

### 2.4. Subagent type = file name (không `.md`)

```
.claude/agents/business/business-analyst.md
                       └─ subagent_type khi spawn
```

```typescript
Agent({
  subagent_type: "business-analyst",   // khớp tên file (không .md)
  prompt: "..."
})
```

**Quy tắc:**
- `name` field trong frontmatter PHẢI khớp tên file
- Lowercase-kebab-case bắt buộc
- Tên file = subagent_type khi skill spawn

---

## 3. Folder & file naming (CORE-015, CORE-016)

### 3.1. Lowercase-kebab-case BẮT BUỘC

```
✅ phase2-features/crm/customer-management/feat-create-customer.md
❌ Phase2-Features/CRM/CustomerManagement/Feat_Create_Customer.md
```

**Áp dụng cho:**
- Folder trong `.mc-data/docs/`, `.mc-data/work/`
- File trong `.claude/skills/`, `.claude/agents/`, `.claude/doc-framework/`
- Script files (`.sh`, `.py`)

### 3.2. Naming normalization (CORE-017)

Khi extract từ legacy code, names PHẢI normalize:

```
Input từ legacy:
  Module name: "Quản Lý Khách Hàng" (Vietnamese with diacritics)
  System name: "CRM_System_v2"
  Feature name: "Create New Customer"

Normalize:
  Module → "quan-ly-khach-hang"  (lowercase, không dấu, kebab)
  System → "crm-system-v2"        (lowercase, kebab — số được giữ)
  Feature → "create-new-customer" (lowercase, kebab)
```

**Quy tắc strip:**
- Vietnamese diacritics: `á/à/ả/ã/ạ → a`, `đ → d`, etc.
- Spaces → `-`
- Underscore `_` → `-`
- CamelCase → kebab (`CustomerManagement` → `customer-management`)
- Special chars (`@#$%&*+=`) → strip hoàn toàn
- Leading/trailing `-` → strip

### 3.3. Cross-validation (CORE-018)

Mọi name PHẢI khớp giữa:
- `req-registry.json` (`systems[].id`, `modules[].id`, `features[].id`)
- Folder structure (`phase2-features/[sys]/[mod]/[feat].md`)
- Code annotations (`// REQ-ID: REQ-[SYS]-[MOD]-001`)
- `module-code-mapping.json` (legacy flow)

**Gap analysis** ở `wf-design` phải cross-validate 4 nguồn trên.

---

## 4. REQ-ID & FEAT-ID format (CORE-003)

### 4.1. Hai dạng REQ-ID

**Dạng đơn giản** (dự án nhỏ, ≤5 department):
```
REQ-[DEPT]-[NNN]
```

Ví dụ:
- `REQ-SALES-001`
- `REQ-HR-042`
- `REQ-FIN-123`

**Dạng phức tạp** (multi-system project):
```
REQ-[SYSTEM]-[MODULE]-[NNN]
```

Ví dụ:
- `REQ-CRM-CUST-001`
- `REQ-ERP-INVENTORY-042`
- `REQ-ECOM-CART-099`

### 4.2. FEAT-ID format

```
FEAT-[SYSTEM]-[MODULE]-[NNN]
```

Ví dụ:
- `FEAT-CRM-CUST-001`
- `FEAT-ERP-INVOICE-007`

### 4.3. Quy tắc ID

- ✅ UPPERCASE cho ALL components: `REQ-CRM-CUST-001`
- ✅ Số padded 3 digits: `001`, `042`, `999`
- ✅ Tách bằng `-`
- ✅ DEPT/SYSTEM/MODULE viết tắt 3-10 ký tự
- ❌ `REQ-sales-1` (lowercase + chưa pad)
- ❌ `REQ_SALES_001` (snake)
- ❌ `req-sales-001` (lowercase)
- ❌ `REQ-SALES-0001` (4 digits pad — chỉ 3)

### 4.4. UI/API/DB trace IDs

```
UI-[SYSTEM]-[MODULE]-[NNN]    → UI-CRM-CUST-001
API-[SYSTEM]-[MODULE]-[NNN]   → API-CRM-CUST-001
DB-[SYSTEM]-[MODULE]-[NNN]    → DB-CRM-CUST-001
```

Trace flow: `REQ-CRM-CUST-001 → FEAT-CRM-CUST-001 → {UI, API, DB}-CRM-CUST-001 → code annotation`

---

## 5. Session ID format (CORE-035)

```
SESSION_ID = YYYY-MM-DD-{scope}-{slug}-{NN}
```

| Component | Mô tả | Ví dụ |
|-----------|-------|-------|
| `YYYY-MM-DD` | Ngày tạo session | `2026-05-15` |
| `{scope}` | Scope mode | `all`, `system`, `module`, `feature` |
| `{slug}` | Target name (slug-hóa) | `crm`, `customer-mgmt`, `feat-001` |
| `{NN}` | Sequence number 2 digits | `01`, `02`, `15` |

**Ví dụ thực tế:**
- `2026-05-15-all-mcv3-01` (full scope scan)
- `2026-05-15-module-customer-mgmt-03` (module scan, 3rd attempt today)
- `2026-05-14-feature-feat-crm-cust-001-01`

**Quy tắc:**
- Date dùng UTC hoặc local TZ — phải nhất quán trong cùng skill
- Slug phải normalize theo §3.2
- NN tự động increment trong cùng ngày + scope + slug

---

## 6. Slug rules (CORE-016, CORE-017)

Khi convert name → slug:

```
"Quản Lý Khách Hàng"      → "quan-ly-khach-hang"
"Customer Management"     → "customer-management"
"CRM_System"              → "crm-system"
"REQ-CRM-CUST-001"        → "req-crm-cust-001" (lowercase khi dùng làm slug filename)
"Module 1.2.3"            → "module-1-2-3" (dot → dash)
"Khách-Hàng VIP"          → "khach-hang-vip"
```

**Trong path:**
```
.mc-data/docs/phase2-features/crm/quan-ly-khach-hang/feat-tao-khach-hang-001.md
                              └ sys └─ mod ──────────└─ feat slug
```

---

## 7. Variable names trong code (CORE-005)

- Variables/functions: **English** hoặc **Vietnamese không dấu**
- Class names: **PascalCase** (theo language convention)

```typescript
// ✅ OK
const customerList: Customer[] = ...
function calculateTax(amount: number): number { ... }
const khachHang = await fetchCustomer(id);   // Vietnamese không dấu OK

// ❌ KHÔNG OK
const danh_sách_khách_hàng = ...   // có dấu
const customerlist = ...           // thiếu camelCase
```

---

## 8. Comments + docs language (CORE-005)

| Loại | Ngôn ngữ |
|------|----------|
| `.md` documentation | Tiếng Việt |
| Code comments (giải thích nghiệp vụ) | Tiếng Việt |
| Code comments REQ-ID trace | Format chuẩn (English) |
| TODO/FIXME markers | Tiếng Việt hoặc English |
| README | Tiếng Việt |
| Variable/function/file names | English hoặc Vietnamese không dấu |
| Class names | English (theo convention language) |

**Quy tắc nhất quán:** trong 1 file, không trộn 50/50 — chọn 1 ngôn ngữ chính cho comments.

---

## 9. Skill-specific file naming

| File | Format | Ví dụ |
|------|--------|-------|
| Skill entry | `SKILL.md` (UPPERCASE) | `wf-fix-bugs/SKILL.md` |
| Procedure file | `procedures/phase{N}-{name}.md` | `procedures/phase1-init.md` |
| Shared procedure | `procedures/_shared.md` | — |
| Resume handler | `procedures/resume-status.md` | — |
| Contract file | `_contract.json` | — |
| Template file | `templates/{purpose}.{ext}` | `templates/fix-status.json` |
| Phase report template | `templates/phase{N}-{name}/Phase{N}-report.md` | `templates/phase1-init/Phase1-report.md` |
| Eval cases | `evals/evals.json` | — |
| Regression test | `evals/regression-tests/test-{name}.sh` | `evals/regression-tests/test-init-status-flags.sh` |
| Script file | `scripts/{purpose}.sh` | `scripts/wf-fix-init-status.sh` |

---

## 10. Doc framework file naming

```
.mc-data/docs/phase{N}-{name}/{file-slug}.md
```

| Phase | Folder | File pattern |
|-------|--------|--------------|
| 0 | `phase0-brainstorm/` | `P0-NN-{slug}.md` (vd: `P0-01-project-brief.md`) |
| 1 | `phase1-business/` | `departments/{dept}/{feature}.md` |
| 2 | `phase2-features/` | `[sys]/[mod]/[feat].md` |
| 3 | `phase3-architecture/` | `P3-NN-{topic}.md` (vd: `P3-01-architecture.md`) |
| 4 | `phase4-ux/` | `[sys]/{topic}.md` |
| 5 | `phase5-implementation/` | `sprints/S{NN}-{name}.md`, `tasks/[sys]/[mod]/[feat]-impl.md` |
| 6 | `phase6-deployment/` | `deployment-{topic}.md` |

**Meta files (special):**
- `_meta/req-registry.json` — SSOT
- `_meta/project-digest.json` — produced by wf-brainstorm Phase 3
- `_meta/feature-briefs.json` — produced by wf-define-features Phase 3
- `_meta/design-input-digest.json` — produced by wf-design Phase 3

---

## 11. Ví dụ Pass/Fail

### ✅ PASS — Đặt tên nhất quán

```
File path:
  .mc-data/docs/phase2-features/crm/quan-ly-khach-hang/feat-tao-khach-hang-001.md

Registry entry:
  {
    "systems": [{"id": "crm", "name": "CRM"}],
    "modules": [{"id": "quan-ly-khach-hang", "system": "crm"}],
    "features": [{
      "id": "FEAT-CRM-QUAN-LY-KHACH-HANG-001",
      "module": "quan-ly-khach-hang"
    }]
  }

Code annotation:
  // REQ-ID: REQ-CRM-QUAN-LY-KHACH-HANG-001
  // FEAT-ID: FEAT-CRM-QUAN-LY-KHACH-HANG-001
```

**Tất cả 3 nguồn:** slug `quan-ly-khach-hang` khớp 100%.

### ❌ FAIL — Naming drift

```
File path:
  .mc-data/docs/phase2-features/CRM/QuanLyKhachHang/feat_001.md  ← UPPERCASE + camelCase

Registry:
  modules: [{"id": "khach-hang-management"}]   ← khác slug!

Code:
  // REQ-ID: req-crm-001   ← lowercase, không khớp UPPERCASE convention

Vi phạm:
  - CORE-015: folder không lowercase-kebab
  - CORE-018: gap analysis sẽ fail (registry vs folder mismatch)
  - CORE-016: file name format không chuẩn
  - REQ-ID không đúng UPPERCASE format
```

---

## 12. Anti-patterns — KHÔNG được làm

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| `wf_implement_feature/` (snake_case folder) | `wf-implement-feature/` |
| `Phase2-Features/CRM/Customer.md` | `phase2-features/crm/customer.md` |
| `REQ-sales-1` | `REQ-SALES-001` |
| `REQ_CRM_001` | `REQ-CRM-001` |
| `business_analyst.md` (agent file) | `business-analyst.md` |
| `subagent_type: "BusinessAnalyst"` | `subagent_type: "business-analyst"` |
| Slug có dấu: `khách-hàng` | Không dấu: `khach-hang` |
| Session ID: `2026-05-15-Module-CRM-1` | `2026-05-15-module-crm-01` |
| File name có space: `Phase 1 Report.md` | `Phase1-report.md` |
| File version trong tên: `SKILL-v2.md` | SKILL.md + version trong frontmatter |
| Vietnamese diacritics trong code variable: `var khách_hàng` | `var khachHang` hoặc English `customer` |
| Mix UPPERCASE/lowercase trong REQ-ID: `Req-Sales-001` | UPPERCASE prefix + UPPERCASE dept: `REQ-SALES-001` |

---

## 13. Compliance audit

Script `./.claude/scripts/validate-pipeline-naming.sh` kiểm tra:

- ✅ Mọi folder trong `.claude/skills/` lowercase-kebab
- ✅ Mọi file `.md`, `.json`, `.sh` lowercase (trừ `SKILL.md`, `README.md`)
- ✅ Agent file name khớp `name` field frontmatter
- ✅ REQ-ID/FEAT-ID format đúng (UPPERCASE + 3-digit pad)
- ✅ Slug trong path khớp slug trong registry

Hook `validate-naming-convention.sh` (PostToolUse Write/Edit) cảnh báo real-time khi vi phạm.

---

## 14. Khi cần exception

**Hiếm khi cần** — nhưng nếu phải:
- File system-specific (vd: `SKILL.md`, `README.md`, `CHANGELOG.md`) — UPPERCASE giữ nguyên
- Standard names (vd: `Dockerfile`, `Makefile`) — giữ nguyên
- Convention chính thức (vd: GitHub Actions `.github/workflows/{name}.yml`)
- Ngoại lệ PHẢI viết ADR trong `04-skill-design/{skill}/08-tradeoffs-adr.md`

---

## 15. Liên kết

- **Canonical rules:** [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) — CORE-005, CORE-015..018
- **Hook validation:** `.claude/hooks/validate-naming-convention.sh`
- **Script audit:** `.claude/scripts/validate-pipeline-naming.sh`
- **Related standards:**
  - [`04-contract-schema.md`](04-contract-schema.md) — `skill` field naming
  - [`09-session-checkpoint.md`](09-session-checkpoint.md) — SESSION_ID format
  - [`11-output-path-contract.md`](11-output-path-contract.md) — folder structure
