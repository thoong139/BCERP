# Phase 5: Cross-Validation & Auto-Correction Loop

> Kiểm tra nhất quán giữa deployment docs và source artifacts.
> Phát hiện + tự động sửa lỗi cơ học. Max 3 iterations.

**PRE-GATE:** Tất cả output files Phase 2 + 3a + 3b + 4 + 4a tồn tại.

**INPUT:**

| File | Path | Mục đích |
|------|------|----------|
| Deployment guide | `.mc-data/docs/phase6-deployment/deployment-guide.md` | Cross-validate vs architecture (bao gồm Muc 9 & 10) |
| User guide | `.mc-data/docs/phase6-deployment/user-guide.md` | Cross-validate vs features |
| Runbook | `.mc-data/docs/phase6-deployment/incident-response-runbook.md` | Cross-validate vs Muc 10 monitoring |
| Architecture | `.mc-data/docs/phase3-architecture/P3-01-architecture.md` | Source of truth cho tech stack, environments |
| Feature specs | `.mc-data/docs/phase2-features/**/*.md` | Source of truth cho features coverage |
| Registry | `.mc-data/docs/_meta/req-registry.json` | Source of truth cho systems, modules, tech_stack |

**OUTPUT:** Auto-fix các docs đã tạo (in-place patches). Không tạo file mới.

---

## Reference Sections

- `_shared.md` §Fix Rules đặc thù
- `_shared.md` §Checkpoint Protocol (LPM)

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 5.0 | Init `validation_iteration = 0`, `error_log = []` | Variables set |
| 5.1 | Chạy structural validation (xem §Structural Validation) | Results captured |
| 5.2 | Chạy Content Quality Gate Protocol 8 (xem §Content Quality Checks) | Results captured |
| 5.3 | Nếu có errors → **AUTO-FIX LOOP** (xem §Auto-Fix Loop) | Loop complete or escalated |
| 5.4 | Log validation results + iteration count vào `error_log` | Results logged |
| 5.5 | **LPM CHECKPOINT** — Nếu `$LARGE_PROJECT=true`: SAVE CHECKPOINT sau Phase 5 | Checkpoint saved |

---

## §Structural Validation (Step 5.1)

| Check | Action | Pass Condition |
|-------|--------|----------------|
| 5.1.1 | Verify tất cả output files tồn tại + non-empty | All files exist |
| 5.1.2 | Cross-check `deployment-guide.md` <-> `P3-01-architecture.md` (tech stack, environments) | No mismatches |
| 5.1.3 | Cross-check `user-guide.md` <-> `features/**/*.md` (tất cả features được cover) | All features covered |
| 5.1.4 | Verify Muc 9 + Muc 10 có trong `deployment-guide.md` | Sections present |
| 5.1.5 | Verify `runbook.md` nhất quán với `deployment-guide.md` Muc 10 (monitoring, alerting) | No mismatches |
| 5.1.6 | Verify không có broken internal links/references | No broken references |
| 5.1.7 | Verify không có placeholder content (`TODO`, `TBD`, `[placeholder]`) | No placeholders |

### Validation Commands

```bash
# 5.1.2 — Tech stack consistency
registry_tech=$(jq -r '.tech_stack[]?' req-registry.json | sort -u)
doc_tech=$(grep -iE "(node|python|go|java|rust|ruby|php)" deployment-guide.md | sort -u)
# Compare sets

# 5.1.3 — Feature coverage
registry_features=$(jq -r '.features[].feat_id' req-registry.json | sort)
user_guide_features=$(grep -oE "FEAT-[A-Z]+-[A-Z0-9-]+" user-guide.md | sort -u)
# Check registry_features ⊆ user_guide_features

# 5.1.4 — Muc 9 + 10 presence
grep -qE "^## (9\.|Muc 9|Quan ly tai khoan|Account)" deployment-guide.md
grep -qE "^## (10\.|Muc 10|Bao tri|Maintenance)" deployment-guide.md

# 5.1.7 — Placeholders
grep -nE "TODO|TBD|\[placeholder\]|\[\.\.\.\]" *.md  # Phai return empty
```

---

## §Content Quality Checks (Step 5.2 — Protocol 8)

| Check | Action | Verify |
|-------|--------|--------|
| 5.2.1 | **CQG-01 Deployment guide completeness:** Verify 10 Muc đầy đủ (Muc 1 → Muc 10) | All 10 sections present |
| 5.2.2 | **CQG-02 User guide API cross-ref:** Verify endpoints trong user-guide phải tồn tại trong `api-contract.md` (Phase 3) | No phantom endpoints |
| 5.2.3 | **CQG-03 Runbook service names:** Verify service names reference đúng từ P3-01 | Service names match |
| 5.2.4 | **CQG-04 Cross-doc consistency:** Tech stack + environment + service names nhất quán giữa 3 docs | No mismatches |
| 5.2.5 | **CQG-05 Section content depth:** Mỗi Muc/section có >= 2 câu nội dung thực (loại trừ headers/bullets rỗng) | All sections adequate |
| 5.2.6 | **CQG-06 Registry freshness:** Re-read `req-registry.json` — compare systems/modules/tech_stack với deployment docs | Registry data matches |

### Content Quality Commands

```bash
# 5.2.1 — 10 sections
grep -cE "^## (Muc |)[1-9][\.\b]|^## 10[\.\b]" deployment-guide.md  # >= 10

# 5.2.2 — API endpoints
api_endpoints=$(grep -oE "(GET|POST|PUT|DELETE) /[a-z0-9/{}\-]+" api-contract.md | sort -u)
user_endpoints=$(grep -oE "(GET|POST|PUT|DELETE) /[a-z0-9/{}\-]+" user-guide.md | sort -u)
# Check user_endpoints ⊆ api_endpoints

# 5.2.5 — Content depth
# Mỗi section phải có >= 2 câu thực tế — dùng awk để split theo section và count sentences
# Sentences = số dấu `.`, `!`, `?` (loại trừ code blocks)
```

---

## §Auto-Fix Loop (Step 5.3)

```
FOR iteration = 1 to 3:
  errors = collect_errors_from_structural + content_quality

  IF errors.length == 0:
    → PASS, break loop

  FOR each error in errors:
    error_type = classify(error)  # missing_file, missing_section, invalid_reference, inconsistent_content

    fix_strategy = lookup(error_type)  # từ _shared.md §Fix Rules
    apply_fix(fix_strategy)
    error_log.append({iteration, error_type, fix_strategy, status})

  # Re-validate sau khi fix
  errors = collect_errors_from_structural + content_quality

  IF errors.length == 0:
    → PASS, break loop
  ELSE IF iteration == 3:
    → STOP phase, E009
    → escalate to user với chi tiết errors còn lại

# Safety: Auto-fix regression
IF fix_tạo_ra_error_moi:
  → STOP auto-fix ngay lập tức (E010)
  → escalate to user
```

---

## §Fix Strategies (chi tiết)

| Error Type | Strategy |
|-----------|----------|
| `missing_section` | Re-run agent tương ứng phase (P2/P3a/P3b/P4/P4a) với instruction bổ sung section thiếu |
| `invalid_reference` | Grep reference đích, tự động sửa path trong doc (Edit tool) |
| `inconsistent_content` | Xác định source of truth (registry/P3-01) → update doc để match source |
| `missing_file` | Spawn agent tương ứng phase để re-generate file |
| `placeholder_content` | Identify section chứa TODO/TBD → re-run agent với focused instruction |
| `phantom_endpoint` | Remove endpoint khỏi user-guide hoặc add vào api-contract (hỏi user) |
| `service_name_mismatch` | Normalize theo P3-01 (source of truth), update runbook |

---

## POST-GATE

- [ ] Zero CRITICAL mismatches
- [ ] Tất cả output files trong `phase6-deployment/` tồn tại + non-empty
- [ ] Auto-Correction Loop PASS (hoặc escalated)
- [ ] `error_log` đã được populate với validation results + iterations

**Next phase:** `phase5a-review.md`

---

## Error Codes

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E007 | Cross-validation mismatch | List mismatches, cho user review trước khi finalize |
| E009 | POST-GATE fail sau 3 iterations | STOP phase, escalate |
| E010 | Auto-fix regression (fix 1 lỗi gây ra lỗi mới) | STOP auto-fix, escalate ngay lập tức |
| E011 | Env mismatch | WARNING + Manual Review (không auto-fix) |
