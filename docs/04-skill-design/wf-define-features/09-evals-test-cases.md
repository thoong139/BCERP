# 09 — Evals & Test Cases

> **Mục đích file:** 6 evals match `evals/evals.json`.

---

## 1. Bảng test cases (6 evals)

| ID | Type | Mục đích |
|----|------|----------|
| TC-1 | integration | NEW project full run — Phase 0→5, kebab-case Vietnamese naming, append features[] |
| TC-2 | edge | **E020 Referential Integrity** — orphan REQ-IDs detected → BLOCK với 3 lựa chọn |
| TC-3 | integration | `--auto-stub-requirements` — auto-append stub entries với tracking |
| TC-4 | integration | **W4.7 Cross-Module Detection** — undeclared cross-module refs → AskUserQuestion 3 options |
| TC-5 | legacy | LEGACY mode — FEAT-ID file naming, Phase 2.5 feat-mapping, Phase 2.7 UI Coverage |
| TC-6 | resume | Resume mid Phase 2 lane — không re-run lanes đã done |

---

## 2. Test case detail (extract)

### TC-2 — E020 Referential Integrity

**Setup:** Feature spec `FEAT-CRM-CUST-001.md` reference `REQ-SALES-007` nhưng `REQ-SALES-007` không tồn tại trong `requirements[]`.

**Run:** `/wf-define-features` (no flag)

**Expected:**
1. Phase 5 step 5.3c compute orphan = ["REQ-SALES-007"]
2. Output `referential-integrity-violations.json` với `orphan_count=1`
3. BLOCK với E020 + display 3 lựa chọn:
   - "1. Pass `--auto-stub-requirements` flag để auto-append stub"
   - "2. Re-run `/wf-analyze-requirements` để generate đầy đủ requirements"
   - "3. Use `/wf-manage-change` để manual add REQ-SALES-007"
4. STOP, không Safe-Write features[]

**Pass criteria:**
- Registry KHÔNG bị modify (features[] empty hoặc unchanged)
- `referential-integrity-violations.json` valid JSON
- Output contains "E020"

### TC-3 — `--auto-stub-requirements`

**Setup:** Same orphan scenario như TC-2.

**Run:** `/wf-define-features --auto-stub-requirements`

**Expected:**
1. Phase 5.3c detect orphan
2. APPEND stub vào requirements[]:
   ```json
   {
     "req_id": "REQ-SALES-007",
     "description": "(auto-stub) Auto-generated from FEAT-CRM-CUST-001 reference",
     "auto_generated_by": "wf-define-features --auto-stub-requirements",
     "needs_user_review": true,
     "source": "feature_reference",
     "referenced_by": ["FEAT-CRM-CUST-001"]
   }
   ```
3. POST-GATE referential check PASS (orphan_count == 0 sau stub append)
4. Safe-Write features[] proceed

**Pass criteria:**
- `requirements[]` có entry mới với tracking flags
- POST-GATE PASS
- Registry valid

### TC-4 — W4.7 Cross-Module Detection

**Setup:** Feature `FEAT-CRM-CUST-001` (module MOD-CRM) trong description mention `MOD-SALES.OrderEntity`. Registry KHÔNG có `cross_module_dependencies[]` entry cho cặp này.

**Run:** `/wf-define-features`

**Expected:**
1. Phase 3 check 3.8 detect "MOD-SALES" ref từ MOD-CRM
2. Check registry `cross_module_dependencies[]` → undeclared
3. Interactive AskUserQuestion 3 options:
   - "Có — Add cross-module dependency"
   - "Không — Ignore"
   - "Deferred — Append to deferred-findings.md"
4. **KHÔNG block POST-GATE** (suggest only)

**Pass criteria:**
- POST-GATE Phase 3 PASS dù user chọn option nào
- Nếu chọn Deferred → `deferred-findings.md` có entry mới

### TC-5 — LEGACY mode full

**Setup:** LEGACY project với `project-context.md > 500 bytes` + `ui-manifest.json` đầy đủ.

**Run:** `/wf-define-features`

**Expected:**
1. Phase 0: `$LEGACY_MODE=true`, `$HAS_SCREENS=true`
2. Phase 0.5 Legacy Impl Seed: seed `impl_status` từ extracted data
3. Phase 2: FEAT-ID file naming (`FEAT-CRM-CUST-001.md`, không kebab-case)
4. Phase 2.5: `feat-mapping.json` valid
5. Phase 2.7: UI Coverage Cross-Check, sinh `ui-coverage-gaps.json` với classification (COVERED/INFRASTRUCTURE/GAP/AMBIGUOUS)
6. Phase 3+4+5: complete normally
7. Registry safe-write features[]

**Pass criteria:**
- File naming: `FEAT-CRM-CUST-001.md` (NOT kebab-case)
- `feat-mapping.json` exists, schema valid
- `ui-coverage-gaps.json` exists với coverage_stats.gaps >= 0

---

## 3. Eval criteria

### Pass criteria

| Criteria | Threshold |
|----------|-----------|
| Registry safe-write features[] append-only | 100% |
| Registry KHÔNG modify other fields | 100% |
| Phase 5.3c Referential Integrity enforced | 100% |
| E020 BLOCK behavior khi orphan (no flag) | 100% |
| `--auto-stub-requirements` tracking fields populated | 100% |
| W4.7 / CF6 non-blocking (POST-GATE pass dù findings) | 100% |
| LEGACY file naming FEAT-ID | 100% |
| NEW file naming kebab-case Vietnamese | 100% |
| Phase 2.7 chỉ chạy khi LEGACY + UI manifest | 100% |

### Fail criteria

| Criteria | Verdict |
|----------|---------|
| features[] entries delete/modify (không append) | FAIL |
| Orphan REQ-IDs propagate downstream (E020 bị bypass) | FAIL |
| `requirements[]` modified ngoài auto-stub case | FAIL |
| W4.7 block POST-GATE | FAIL |
| LEGACY file dùng kebab-case (sai naming) | FAIL |

---

## 4. Coverage matrix

| | NEW | LEGACY | NEW+UI | LEGACY+UI |
|---|-----|--------|--------|-----------|
| **Default** | TC-1 | TC-5 | TC-1 | TC-5 |
| **--auto-stub** | TC-3 | — | — | — |
| **Orphan REQ-IDs** | TC-2 | — | — | — |
| **W4.7** | TC-4 | — | — | — |
| **Resume** | TC-6 | — | — | — |

---

## 5. Liên kết

- Eval source: [`.claude/skills/workflow/wf-define-features/evals/evals.json`](../../../.claude/skills/workflow/wf-define-features/evals/evals.json)
- Standards: [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md) §7
- Review checklist: [`../../05-review-standards/wf-define-features.md`](../../05-review-standards/wf-define-features.md)
