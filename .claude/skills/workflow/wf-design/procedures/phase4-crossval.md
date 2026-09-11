# Phase 4: Cross-Validation (AUTO-CORRECTION LOOP)

> Kiểm tra toàn diện: registry nhất quán với technical specs đã tạo.
> **Tự động lặp lại** cho đến khi KHÔNG còn lỗi nào — tối đa 3 iterations.

> **Auto-Correction:** Áp dụng Auto-Correction Loop Protocol (max 3 iterations) — xem `.claude/skills/protocols/`

**PRE-GATE:** Tất cả technical spec files đã được tạo

```bash
test -s .mc-data/docs/phase3-architecture/P3-01-architecture.md
test -s .mc-data/docs/phase3-architecture/technical-specs/api-contract.md
test -s .mc-data/docs/phase3-architecture/technical-specs/database-design.md
test -s .mc-data/docs/phase3-architecture/technical-specs/integration-map.md
test -s .mc-data/docs/phase3-architecture/technical-specs/infra-spec.md
test -s $SESSION_DIR/aggregation-result.json
jq -e 'has("components") and has("apis")' $SESSION_DIR/aggregation-result.json
```

**INPUT:**
- Registry (**FRESH READ** — không cached từ Phase 0)
- `P3-01-architecture.md` + `technical-specs/*.md`
- `phase2-features/**/*.md`

**OUTPUT (auto-fix):**
- Updated `technical-specs/*.md`, `phase2-features/**/*.md` (nếu cần fix)
- `.mc-data/work/wf-design/design-report.md` (log mỗi iteration)

---

## Aggregation Conflict Resolution (TRƯỚC validation loop)

| Step | Action | Verify |
|------|--------|--------|
| 4.0 | Đọc `$SESSION_DIR/aggregation-result.json` → `conflicts[]`. Nếu rỗng → tiếp tục. Nếu có conflicts → xử lý Auto-Correction Loop (max 3 iterations per conflict): cố gắng resolve conflict (rename, merge, disambiguate). Nếu không resolve được → flag sang `$SESSION_DIR/aggregation-unresolved.json` cho Phase 5 stakeholder review. | Conflicts resolved hoặc flagged |
| 4.0b | Log conflict resolution results vào `design-report.md` — section "Aggregation Conflicts" với trạng thái từng conflict (RESOLVED / DEFERRED → Phase 5) | Log written |

---

## Validation Checks (mỗi iteration)

| Check | Action | Khi FAIL → Auto-Fix |
|-------|--------|---------------------|
| 4.1 | **FRESH READ** `req-registry.json` — KHÔNG dùng data cached từ Phase 0 (CQG-05 Freshness) | Registry data current |
| 4.2 | Verify: mỗi REQ-ID trong registry → referenced trong ít nhất 1 technical spec | Thêm REQ-ID reference vào spec phù hợp |
| 4.3 | Verify: API endpoints trong `api-contract.md` → có corresponding entities trong `database-design.md` | Tạo missing entity HOẶC fix reference |
| 4.4 | Verify: `integration-map.md` references → point to existing registry modules | Fix module reference |
| 4.5 | Verify: mỗi feature spec có đủ info cho design (stories, dependencies) | Bổ sung missing sections từ context |
| 4.6 | Verify: không có duplicate definitions across specs | Merge duplicates |
| 4.7 | Verify: mỗi error code chỉ map đúng 1 HTTP status + 1 nghĩa (không trùng code cho 2 scenarios) | Tạo error code mới, sửa references |
| 4.8 | Verify: entity/table references trong `integration-map` → tồn tại trong `database-design` | Thêm missing table/entity vào database-design |
| 4.9 | Verify: API response fields → có cột tương ứng trong `database-design` (VD: preferredLanguage → preferred_language) | Thêm missing column hoặc sửa API response |

---

## Fix Rules

Tham khảo `_shared.md` §Fix Rules đặc thù. Mỗi loại lỗi có strategy auto-fix riêng.

Các loại lỗi chính trong Phase 4:

| Loại lỗi | Auto-Fix |
|-----------|---------|
| `missing_ref` | Tìm spec phù hợp nhất → thêm reference |
| `missing_entity` | Extract từ API contract → tạo DB entity |
| `invalid_module_ref` | Lookup correct module in registry → fix ref |
| `incomplete_feature_spec` | Bổ sung missing sections từ architecture + registry context |
| `duplicate_def` | Merge vào single definition, update references |
| `duplicate_error_code` | Tạo error code mới, sửa references trong tất cả specs |
| `missing_db_entity_ref` | Thêm table/column DDL vào database-design.md |
| `api_db_field_mismatch` | Thêm missing column vào DB HOẶC sửa API response |

---

## Auto-Correction Loop (max 3 iterations)

```
FOR iteration IN 1..3:
  1. FRESH READ registry + all specs
  2. Run 8 validation checks (4.2 - 4.9)
  3. IF zero CRITICAL errors → BREAK
  4. Auto-fix detected errors theo Fix Rules
  5. Log vào design-report.md: iteration N, errors found, fixed, remaining
  6. Continue to iteration N+1

POST-LOOP:
  IF iteration = 3 AND errors > 0:
    → E009 — list mismatches → user decide
```

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 4.10 | Log validation results vào `.mc-data/work/wf-design/design-report.md` (mỗi iteration) | Report updated |
| 4.11 | Ghi tổng kết: iterations count, errors fixed, errors remaining | Summary logged |

---

## POST-GATE

```bash
# Zero CRITICAL validation errors (tất cả checks PASS) HOẶC user acknowledged remaining errors
test -s .mc-data/work/wf-design/design-report.md
grep -c 'CRITICAL.*FAIL' .mc-data/work/wf-design/design-report.md  # 0 ideally, hoặc user acknowledged
```

**(Protocol 8 — CQG-08) Content Quality Checks:**
```
1. CONSISTENCY: API endpoints trong api-contract.md khớp với features[] trong registry
   (mỗi feature có ít nhất 1 API endpoint tương ứng)
2. CONSISTENCY: DB tables trong database-design.md khớp với modules[] trong registry
   (mỗi module có ít nhất 1 table/entity tương ứng)
3. TRACEABILITY: Mỗi feature trong registry → có ít nhất 1 API endpoint trong api-contract.md
4. NẾU FAIL: Auto-fix — thêm missing endpoints/tables, hoặc escalate nếu thiếu context
```

**Checkpoint (LPM only):** Nếu `$LARGE_PROJECT = true` → SAVE session-state.json (`phases.P4.status = "completed"`, `next_action = "phase5-review"`) + sync checkpoint.json sau Phase 4.

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E009 | Cross-validation mismatch sau 3 iterations | List mismatches, retry affected specs → user decide |
| E011 | Auto-fix gây regression (lỗi mới) | Rollback fix → escalate with context |

---

## Next Phase

→ Read `procedures/phase5-review.md` — Stakeholder Technical Review
