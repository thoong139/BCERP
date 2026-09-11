# Procedure: Legacy Scan — Extract Requirements & Features

> **Type**: Agent Procedure
> **Agent**: business-analyst (+ domain experts)
> **Skill**: wf-legacy-extract
> **Triggered by**: wf-legacy-extract khi extract module — duoc goi voi module name va paths

---

## Khi nao dung procedure nay

- Duoc goi trong `wf-legacy-extract` (Extraction)
- Khi mot module da duoc classify xong va can extract requirements + features
- Moi lan goi xu ly mot module duy nhat (atomic per module)

---

## Input

| Input | Source | Mo ta |
|-------|--------|-------|
| Module file list (tu `module_map`) | Stage 2 batch data grouped | Danh sach files thuoc module, skill truyen qua prompt |
| `glossary.json` | Stage 2 output | Business terminology |
| `project-profile.json` | Stage 0 output | Project context, tech stack |
| Source code files | Project | Code files thuoc module |
| Doc files | Project | Documentation files thuoc module |

---

## Procedure

### Buoc 0: Check Existing Docs (Maturity-Aware)

> CHI chay khi `maturity_level` != "CODE_ONLY". Skill truyen `maturity_level` trong prompt.
> Neu `maturity_level` = "CODE_ONLY" → bo qua Buoc 0, bat dau tu Buoc 1 nhu binh thuong.

```
INPUT: maturity_level tu skill prompt + module name
FALLBACK: neu khong co maturity_level trong prompt → mac dinh "CODE_ONLY" → skip Buoc 0

Kiem tra existing DEVKIT docs cho module nay:
□ Doc .mc-data/docs/phase2-features/{system}/{module}/ — co feature docs khong?
□ Doc .mc-data/docs/phase1-business/ — co business context khong?
□ Doc .mc-data/docs/_meta/req-registry.json — co REQs cho module nay khong?
```

**Neu feature docs da ton tai va khop voi module nay:**
```
1. Dung existing docs lam PRIMARY source (thay vi code)
2. Code scan chi de VALIDATE va bo sung, khong tao moi
3. Cross-reference: moi requirement trong docs → tim code evidence
4. Confidence += 0.1 cho requirements co backing doc (max 1.0)
5. Neu requirement co trong doc nhung KHONG co code → mark "doc_only", confidence giu nguyen
6. Neu requirement co trong code nhung KHONG co doc → xu ly nhu Buoc 2-3 binh thuong
```

**Neu feature docs ton tai nhung contract fail (partial):**
```
1. Dung code lam PRIMARY source (nhu Buoc 1-3 binh thuong)
2. Existing docs lam SECONDARY context — bo sung terminology, business rules, acceptance criteria
3. Flag sections trong existing docs can update
4. Confidence += 0.05 cho requirements co partial doc backing
```

**Neu khong co existing docs cho module nay:**
```
→ Tiep tuc Buoc 1 binh thuong (backward-compatible)
```

### Buoc 0B: DOCS_ONLY Mode (neu maturity_level == "DOCS_ONLY")

> CHI chay khi `maturity_level` == "DOCS_ONLY" (du an chi co tai lieu, khong co source code).
> Neu maturity_level != "DOCS_ONLY" → bo qua Buoc 0B, tiep tuc Buoc 1 binh thuong.

```
DOCS_ONLY MODE:
- Docs la PRIMARY va ONLY source (khong co code de cross-reference)
- Confidence cap tai 0.7 cho tat ca requirements (khong co code evidence)
- Source field = "doc" cho tat ca requirements
- Mark tat ca requirements "[DERIVED FROM DOCS]" trong notes
- KHONG co evidence.line (chi co evidence.file)

Quy trinh:
1. Doc tat ca doc files thuoc module (tu doc-classified.json thay vi classified/{module}.json)
2. Phan loai theo doc_type: prd → requirements truc tiep, spec → features + requirements,
   api_spec → API requirements, process_doc → workflow requirements
3. Extract requirements va features nhu Buoc 2-3 nhung:
   - confidence = min(calculated_confidence, 0.7) — khong bao gio > 0.7
   - evidence chi chua file path, khong co line/snippet code
   - notes BAT BUOC chua "[DERIVED FROM DOCS]"
4. Cross-reference giua docs: neu 2+ docs mo ta cung requirement → tang confidence (van cap 0.7)
5. Buoc 4 (Consolidate) va 5 (Domain Expert) chay binh thuong
6. Output nhu binh thuong nhung stats them: "docs_only_mode": true
```

### Buoc 1: Doc Context

```
INPUT: Paths do skill cung cap qua prompt
FALLBACK: tra .mc-data/work/legacy-scan/ cho cac file stage truoc

Can xac dinh:
□ Module name va system name
□ Tech stack tu project-profile.json
□ Business domain (de hieu terminology dung nganh)
□ Glossary terms ap dung cho module nay
```

Tai knowledge neu co domain expert duoc huy dong:
```
Finance domain  → .claude/references/team-expert/finance/
HR domain       → .claude/references/team-expert/hr/
Sales domain    → .claude/references/team-expert/sales/
Operations      → .claude/references/team-expert/operations/
```

### Buoc 2: Scan Code Files

**Input mode:** Skill cung cap `module-digest` (pre-compressed ~300 tu/file) trong prompt.
Digest chua key patterns (class/function/route/export declarations, business keywords) da duoc Grep san.

**Chien luoc doc file:**
- Bat dau tu digest de hieu tong quan module
- Chi doc file goc khi digest khong du chi tiet de extract requirement/feature cu the
- Uu tien doc file goc cho: files co business logic phuc tap, files co nhieu route/endpoint definitions

Dung danh sach files tu skill prompt (module_map data da group theo category tu classified batch files).

Uu tien thu tu scan:
1. `api` files — endpoints la boundary cua business requirements
2. `source` files — services/business logic chua rules chinh
3. `type` files — data models the hien business entities
4. `migration` files — schema history cho thay business evolution

Cho moi source file trong module:

```
1. Kiem tra module-digest truoc — neu digest du chi tiet de extract requirement → khong can doc file goc
2. Neu can chi tiet hon: doc file content (toan bo hoac first 200 lines neu file > 500 lines)
3. Tim business logic patterns:
   - Service/Controller/Repository classes va public methods cua chung
   - Business rules (if/else logic, validation, calculation)
   - Data models (entities, DTOs, value objects)
   - API endpoints (routes, handlers, decorators)
   - Constants va enums the hien business states
3. Extract tung phat hien:
   - requirement_hint: Mo ta ngan gon business requirement (<30 tu)
   - feature_hint: Mo ta ngan gon feature group
   - confidence: high (>85%) / medium (60-85%) / low (<60%)
   - evidence: snippet code va reference file:line
```

WHY scan theo thu tu nay: API files la contract ro rang nhat; business logic chua rules; types va migrations la "ground truth" cua data model.

### Buoc 2U: UI Screen Analysis (CHI khi module co screen files)

> CHI chay khi classified data cho module nay co items voi category = "screen"
> HOAC ui-manifest.json co screens voi module_hint khop voi module nay.
> Neu khong co screen files → bo qua Buoc 2U, tiep tuc Buoc 2B/3.

INPUT:
- inventory/ui-manifest.json (route mapping, screen structure)
- Screen files thuoc module (tu module_map, grouped tu classified/batch-*.json)
- project-profile.json (framework detection)

QUY TRINH:
1. Doc ui-manifest.json → loc screens thuoc module nay
2. Cho moi screen file:
   a. Phat hien UI patterns:
      - Form fields: <input>, <select>, <textarea>, form validation rules
      - Navigation: <Link>, <NavLink>, router.push, window.location
      - Data display: tables, lists, cards, detail views
      - Actions: buttons, modals, confirmations
      - State patterns: loading, error, empty states
   b. Phat hien user flow:
      - Entry points: user navigates TO this screen tu dau
      - Exit points: user goes FROM this screen di dau
      - Conditional rendering: thay doi theo role/state
   c. Route parameters: dynamic segments va y nghia
   d. Component composition: child components, shared components
3. Tao ui_hints cho moi requirement/feature:
   {
     "screen_ref": "app/users/[id]/page.tsx",
     "screen_type": "detail|list|form|dashboard|settings|modal|other",
     "ui_patterns": ["form", "validation", "tabs"],
     "form_fields": ["name", "email", "role"],
     "navigation_targets": ["edit-user", "delete-user"],
     "conditional_elements": [{"condition": "isAdmin", "shows": "delete-button"}]
   }
4. Enrich extracted requirements voi ui_hints
5. Screens KHONG co matching requirement → tao NEW requirement voi:
   - type: "ui-screen"
   - confidence: 0.7 (inferred tu screen existence)
   - source: "ui-analysis"

OUTPUT: moi requirement co the co them field ui_hints, module-level ui_stats

### Buoc 2B: Divergence Detection (Strategy S5)

> CHI chay khi `strategy_id == "S5"` hoac `maturity_level IN ("CODE_PLUS_EXTERNAL_DOCS", "CODE_PLUS_DEVKIT_PARTIAL")`.
> Neu strategy khong phai S5 va maturity khong match → bo qua Buoc 2B, tiep tuc Buoc 3.

```
SAU KHI scan code (Buoc 2) va TRUOC scan docs (Buoc 3):

1. Luu tat ca requirements extracted tu code vao set `from_code[]`
2. Sau Buoc 3 (scan docs), luu requirements tu docs vao set `from_docs[]`
3. So sanh 2 sets theo title/description similarity:
   - SYNCED: similarity > 85% — co trong ca code va docs, noi dung khop
   - DIVERGED: similarity 40-85% — co trong ca 2 nhung mo ta khac nhau
   - UNDOCUMENTED: chi co trong from_code, khong co match trong from_docs
   - UNIMPLEMENTED: chi co trong from_docs, khong co match trong from_code
4. Ghi output: extracted/{module}-divergences.json

Output format:
{
  "module": "MODULE_NAME",
  "synced": [{"code_req": "TMP-X-001", "doc_req": "TMP-X-002", "similarity": 0.92}],
  "diverged": [{"code_req": "TMP-X-003", "doc_req": "TMP-X-004", "similarity": 0.65,
                "code_says": "...", "doc_says": "..."}],
  "undocumented": ["TMP-X-005"],
  "unimplemented": ["TMP-X-006"]
}
```

> **Luu y:** UNDOCUMENTED items tu dong include vao output (code la truth).
> DIVERGED va UNIMPLEMENTED items se duoc Stage 4p-DR xu ly (hoi user chon).

### Buoc 3: Scan Doc Files

Doc danh sach doc files tu module_map (grouped tu `classified/batch-*.json` theo module field).

Cho moi doc file trong module:

```
1. Doc toan bo file content
2. Tim cac pattern:
   - Requirements co keywords: "must", "shall", "require", "phai", "can", "bao gom"
   - Feature descriptions va user stories
   - Business rules duoc phat bieu ro rang
   - Acceptance criteria va test scenarios
   - Diagrams mo ta (flowchart text, sequence descriptions)
3. Cross-reference voi code findings:
   - Doc file confirm → tang confidence len "high"
   - Doc file mau thuan voi code → ghi note "conflict: doc vs code"
   - Doc file them context ma code khong co → ghi note "doc-only"
```

### Buoc 4: Consolidate va Dedup

```
1. Gop ket qua tu code scan va doc scan thanh mot danh sach
2. Dedup:
   - Similarity > 85% ve mo ta → merge thanh 1 requirement
   - Giu evidence tu ca hai nguon (code + doc)
   - Mark source = "both" khi co tu ca hai
3. Assign preliminary REQ-IDs:
   - Format: TMP-[MODULE]-[NNN] (bat dau tu 001, VD: TMP-AUTH-001)
   - Dung prefix TMP- de phan biet voi REQ-ID chinh thuc
   - Stage 4d se re-map TMP-* thanh REQ-[DEPT]-[NNN] khi build registry
4. Assign preliminary FEAT-IDs:
   - Format: TMPF-[MODULE]-[NNN] (VD: TMPF-AUTH-001)
   - Group requirements lien quan vao cung mot feature
```

Gioi han: toi da 50 requirements + 30 features per module.
Neu vuot → tach module thanh sub-modules va bao cao cho skill.

### Buoc 5: Domain Expert Review (neu duoc huy dong)

```
□ Domain expert xem xet danh sach requirements
□ Bo sung domain-specific requirements bi bo sot (vi code khong explicit)
□ Chinh sua terminology theo dung nganh
□ Flag requirements co rui ro compliance (finance audit, HR legal, etc.)
□ Diem confidence co the tang len "high" neu expert confirm
```

### Buoc 6: Ghi Output

Ghi `extracted/{module}.json` vao `.mc-data/work/legacy-scan/extracted/`:

```json
{
  "module": "MODULE_NAME",
  "system": "SYSTEM_NAME",
  "extracted_at": "ISO_DATE",
  "requirements": [
    {
      "req_id": "TMP-MODULE-001",
      "title": "...",
      "description": "...",
      "priority": "high|medium|low",
      "confidence": 0.85,
      "evidence": [{"file": "...", "line": 42, "snippet": "..."}],
      "source": "code|doc|both",
      "notes": "optional — conflict, doc-only, inferred, etc.",
      "ui_hints": {
        "screen_ref": "path/to/screen.tsx",
        "screen_type": "detail",
        "ui_patterns": ["form", "validation"],
        "form_fields": ["field1", "field2"]
      }
    }
  ],
  "features": [
    {
      "feat_id": "TMPF-MODULE-001",
      "name": "...",
      "description": "...",
      "requirements": ["TMP-MODULE-001"],
      "confidence": 0.90,
      "evidence": [{"file": "...", "line": 10, "snippet": "..."}]
    }
  ],
  "stats": {
    "files_scanned": 0,
    "requirements_found": 0,
    "features_found": 0,
    "avg_confidence": 0.0,
    "low_confidence_count": 0
  },
  "ui_stats": {
    "screens_analyzed": 0,
    "screens_with_requirements": 0,
    "orphan_screens": []
  }
}
```

---

## Output Target

~500-800 tu cho `extracted/{module}.json` (tuy do phuc tap module).
Suc tich, day du, khong lap lai context da biet tu project-profile.json.

---

## Checklist truoc khi submit

```
□ Tat ca files thuoc module (tu module_map, grouped tu classified/batch-*.json) da duoc scan
□ Moi requirement co evidence ro rang (file + line hoac snippet)
□ Requirements co confidence < 60% van duoc ghi, mark "low"
□ Khong co REQ-ID ngoai scope module nay (cross-module refs de lai Stage 4)
□ Dedup da chay — khong co requirements trung lap > 85% similarity
□ stats.avg_confidence duoc tinh chinh xac
□ Output JSON valid (no trailing commas, proper escaping)
□ Neu > 50 requirements → da bao cao skill de tach sub-module
```

---

## Luu y

- KHONG tao REQ-ID ngoai scope module nay — cross-module dependencies de lai cho Stage 4
- KHONG doc full file neu file > 500 lines va category = "asset" hoac "config" — skip
- Neu conflict giua doc va code: uu tien code la "what was implemented", doc la "what was intended"
- Max output: 50 requirements + 30 features per module — enforce nghiem tuc de giu quality
