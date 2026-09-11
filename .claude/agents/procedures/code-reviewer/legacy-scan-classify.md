# Procedure: Legacy Scan — Classify Files

> **Type**: Agent Procedure
> **Agent**: code-reviewer
> **Skill**: wf-legacy-classify
> **Triggered by**: wf-legacy-classify khi classify mot batch files tu ledger

---

## Khi nao dung procedure nay

- Duoc goi trong `wf-legacy-classify` (Classification)
- Moi lan goi xu ly mot batch (default 100 files)
- Duoc goi lap lai cho den khi het tat ca files trong ledger

---

## Input

| Input | Source | Mo ta |
|-------|--------|-------|
| File paths batch | Ledger unclassified items | Danh sach file paths can classify trong batch nay |
| `project-profile.json` | Stage 0 output | Tech stack context, frameworks, naming conventions |
| `source-files.json` | Stage 1 output | File metadata (size, extension, last_modified) |

---

## Categories

| Category | Mo ta | Indicators chinh |
|----------|-------|-----------------|
| `screen` | UI screen, page, view, component | `pages/`, `views/`, `screens/`, `*.page.tsx`, `*.screen.tsx`, `*.vue`, `*.svelte` |
| `api` | API endpoint, controller, handler | `controllers/`, `routes/`, `handlers/`, `*.controller.ts`, `*.router.js`, `@Controller` |
| `doc` | Documentation | `*.md`, `*.mdx`, `docs/`, `*.txt` trong doc dirs, `*.rst` |
| `source` | Business logic, services, utilities | `services/`, `models/`, `utils/`, `helpers/`, `lib/`, `domain/` |
| `config` | Configuration | `*.config.*`, `.env*`, `docker*`, `*.yml` (config), `*.toml`, `*.ini` |
| `test` | Test file | `*.test.*`, `*.spec.*`, `__tests__/`, `tests/`, `e2e/` |
| `asset` | Static asset | `*.png`, `*.jpg`, `*.svg`, `*.css`, `*.scss`, `fonts/`, `public/` |
| `migration` | DB migration | `migrations/`, `*.migration.*`, `*.sql` trong migration dirs |
| `type` | Type definitions | `*.d.ts`, `types/`, `interfaces/`, `*.types.ts`, `*.interface.ts` |

Sub-categories hay gap:

| Category | Sub-category | Mo ta |
|----------|-------------|-------|
| `source` | `service` | Business service class |
| `source` | `model` | Data model / entity |
| `source` | `repository` | Data access layer |
| `source` | `middleware` | Request middleware |
| `api` | `rest` | REST controller |
| `api` | `graphql` | GraphQL resolver |
| `api` | `grpc` | gRPC handler |
| `screen` | `component` | Reusable UI component |
| `screen` | `page` | Full page/route |
| `screen` | `layout` | Layout wrapper |

---

## Procedure

### Buoc 1: Doc Context

```
1. Doc project-profile.json — hieu naming conventions va tech stack
2. Xac dinh cac patterns dac trung cua project:
   - Framework dang dung (Next.js, NestJS, Django, Spring...) → dinh huong classification
   - Naming convention (PascalCase, kebab-case, snake_case cho files)
   - Monorepo structure (apps/, packages/) neu co
   - Custom directory conventions
```

WHY: moi project co naming convention rieng — Next.js dung `pages/` cho routes, NestJS dung `*.controller.ts` cho API. Doc context truoc giup classify chinh xac hon.

### Buoc 2: Classify Tung File

Cho moi file trong batch, ap dung thu tu uu tien:

```
1. TRUOC TIEN: Xem xet file path va directory structure
   - Directory name thuo so la indicator manh nhat
   - Vi du: src/controllers/user.ts → category=api rat chac

2. NEU con ambiguous: Xem xet file extension
   - *.spec.ts → category=test (ro rang)
   - *.d.ts → category=type (ro rang)
   - *.md → category=doc (ro rang tru README trong src/)

3. NEU van ambiguous: Doc first 50 lines cua file
   - Tim imports, decorators, class names, exports
   - Vi du: "@Controller()" → category=api, "@Injectable()" → category=source
   - Chi su dung content scan khi path va extension khong du ro

4. NEU khong the xac dinh sau 3 buoc: assign "UNKNOWN" va ghi note

5. Assign confidence:
   - high: path indicator ro rang, khong co dau hieu mau thuan
   - medium: can xem xet extension hoac partial content
   - low: phai doc content va van con do nghi, hoac khong ro ràng
```

### Buoc 3: Xac Dinh System va Module

Dua vao directory structure, uoc tinh:

```
system: Thuong la top-level directory sau src/ hoac apps/
   Vi du: apps/backend/ → system="backend"
          packages/shared/ → system="shared"
          src/ (monolith) → system = ten project tu project-profile

module: Thuong la second-level directory hoac nhom theo chuc nang
   Vi du: src/modules/user/ → module="user"
          src/controllers/order/ → module="order"

Quy tac:
- Neu khong xac dinh system → dung "UNKNOWN"
- Neu khong xac dinh module → dung "UNKNOWN"
- Ghi note giai thich
- KHONG doan neu khong co du bằng chứng
```

### Buoc 4: Group va Write Output

```
1. Group ket qua theo system → module
2. Xac dinh ambiguous files (confidence = low)
3. Report files "UNKNOWN" cho skill biet
```

Ghi output vao `.mc-data/work/legacy-scan/classified/batch-N.json` (N = so batch hien tai, truyen tu skill).
Moi batch file chua tat ca items da classify trong batch do, grouped theo system/module.

```json
{
  "batch": 1,
  "classified_at": "ISO_DATE",
  "items": [
    {
      "path": "relative/path/to/file",
      "category": "source",
      "sub_category": "service",
      "system": "SYSTEM_NAME",
      "module": "MODULE_NAME",
      "confidence": "high",
      "size_bytes": 1234,
      "last_modified": "ISO_DATE",
      "notes": "optional — UNKNOWN reason, conflict, ambiguous"
    }
  ],
  "systems_found": ["SYSTEM_A", "SYSTEM_B"],
  "modules_found": ["MODULE_A", "MODULE_B"],
  "stats": {
    "total": 0,
    "by_category": {
      "screen": 0, "api": 0, "doc": 0, "source": 0,
      "config": 0, "test": 0, "asset": 0, "migration": 0, "type": 0
    },
    "low_confidence_count": 0,
    "unknown_count": 0
  }
}
```

### Buoc 5: Report Progress

Sau khi ghi xong, bao cao cho skill:

```
Batch [N] complete: Classified [X]/[Y] items
  - High confidence: [N]
  - Medium confidence: [N]
  - Low confidence: [N]  ← list paths neu > 5
  - UNKNOWN: [N]         ← list paths de skill quyet dinh
  - Systems found: [list]
  - New modules found: [list]
```

---

## Output Target

~200-400 tu metadata per batch (JSON output, khong phai prose).
Progress report ngan gon, khong verbose.

---

## Checklist truoc khi submit

```
□ 100% files trong batch da duoc assign category (ke ca UNKNOWN)
□ Moi item co confidence level ro rang
□ UNKNOWN items da duoc ghi note giai thich ly do
□ Output JSON valid — khong co trailing comma, escaping dung
□ stats.by_category tong bang stats.total
□ Progress report da duoc bao cao cho skill
□ Khong co full file content trong output — chi metadata
```

---

## Luu y

- KHONG doc full file content — chi first 50 lines neu can, va chi khi path + extension khong du
- Uu tien file path/name classification truoc, content scan chi khi ambiguous (tiep kiem token)
- Neu khong xac dinh duoc system/module → dung "UNKNOWN" va ghi note ro rang, khong doan
- Asset files (images, fonts, CSS) KHONG can doc content — classify tu extension la du
- Config files (*.env) KHONG doc content — co the chua secrets
- Report progress sau moi batch: "Classified X/Y items in batch N"
