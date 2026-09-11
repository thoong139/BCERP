# Stage G Prompt — Dimension Config Completion + Final Integration

## Context

Stage F hoàn tất (PASS). Probe execution integration + agent wiring đã build thành công:
- **probe_executor.py**: Đọc probe .md → execute (grep/agent) → emit Signal v2 dicts
  - GREP_PATTERNS cho 5 probe types (QD1, QD3, QD5, QD6, QD7)
  - Windows-compatible: `[ \t]` thay vì `\s`, drive-letter-aware path parsing
  - Fallback: probe có GREP_PATTERNS nhưng dimension.json thiếu tool.kind → grep+jq
  - CORE-027: CDG probes flagged với `cdg_required=True`
  - CORE-029: `Signal.from_dict()` + `validate_evidence()` cho mọi non-descriptor signal
- **lane_dispatch.py**: scan_cache integration (cache_lookup → cache_store), ADR-22 QD3 never cached
- **Golden-v6 fixture**: 12 expected signals across 5 dimensions (QD1, QD3, QD5, QD6, QD7)
- **442 tests pass** (413 existing + 29 new Stage F), 0 regression

### Audit kết quả — Dimension Config Gaps

```
QD1 (wf-fix-functional): 7 probes — OK (tool.kind đầy đủ)
QD2 (wf-fix-business):   5 probes — tool.kind non-standard: "grep" (thiếu +jq), "fixture-runner" (không trong SUPPORTED_TOOL_KINDS)
QD3 (wf-fix-security):   7 probes — OK (tool.kind đầy đủ)
QD4 (wf-fix-performance): 6 probes — ALL MISSING tool.kind
QD5 (wf-fix-ux-a11y):   7 probes — ALL MISSING tool.kind
QD6 (wf-fix-data):       6 probes — ALL MISSING tool.kind
QD7 (wf-fix-compat):     5 probes — ALL MISSING tool.kind
```

**Root cause:** 24/43 probes thiếu `tool.kind` trong dimension.json. Stage F dùng fallback (GREP_PATTERNS lookup) nhưng đây là workaround, không phải production-ready solution.

---

## Stage G: Dimension Config Completion + Final Integration

### Mục tiêu

Đóng kín toàn bộ dimension configs, complete golden fixture coverage cho tất cả 7 dimensions, và finalize end-to-end integration. Kết quả: production-ready v6 engine với 0 workaround/fallback.

### Key Constraints

1. **ADR-22 Rule 6**: QD3 probes KHÔNG BAO GIỜ cached
2. **CORE-027**: Mọi probe có `cdg: true` phải flag signals với `cdg_required`
3. **CORE-029**: Mọi signal phải pass `validate_evidence()` trước khi ghi
4. **Windows compatibility**: `[ \t]` thay vì `\s` trong regex, drive-letter path parsing
5. **Không introduce regression**: 442 existing tests phải vẫn pass sau mọi thay đổi
6. **Không xóa fallback logic** trong probe_executor — giữ làm defense-in-depth, nhưng primary path phải đúng

---

## Tasks

### G1: Fix Dimension Configs — Populate tool.kind (CRITICAL)

File locations:
```
.claude/skills/workflow/wf-fix-business/dimension.json     — QD2 (5 probes)
.claude/skills/workflow/wf-fix-performance/dimension.json  — QD4 (6 probes)
.claude/skills/workflow/wf-fix-ux-a11y/dimension.json      — QD5 (7 probes)
.claude/skills/workflow/wf-fix-data/dimension.json         — QD6 (6 probes)
.claude/skills/workflow/wf-fix-compat/dimension.json       — QD7 (5 probes)
```

**Hành động:**

1. Đọc mỗi dimension.json, thêm `"tool"` field cho probes thiếu:
   - Probe dùng regex pattern matching → `"tool": {"kind": "grep+jq"}`
   - Probe cần Agent tool → `"tool": {"kind": "agent", "agent": "security"}` (hoặc agent type phù hợp)
   - Probe cần runtime server → `"tool": {"kind": "bash+curl"}` hoặc `"tool": {"kind": "playwright"}`

2. **QD2 non-standard tool kinds** — fix:
   - `"grep"` → `"grep+jq"` (chuẩn hóa theo SUPPORTED_TOOL_KINDS)
   - `"fixture-runner"` → xem xét đổi thành `"agent"` hoặc `"bash+jq"` tùy logic

3. Verify: sau khi fix, `probe_executor.py` phải tìm được tool.kind từ dimension.json mà KHÔNG cần fallback

**Guideline cho tool.kind assignment:**

| Probe type | tool.kind | Ghi chú |
|------------|-----------|---------|
| Static pattern matching (regex) | `grep+jq` | Dùng GREP_PATTERNS |
| AST-based analysis | `grep+ast` | Phức tạp hơn, cần parser |
| Runtime API check | `bash+curl` | Cần server running |
| Browser testing | `playwright` | Cần browser runtime |
| Deep analysis / expert review | `agent` | Delegate to Agent tool |
| Bundle/build analysis | `bash+jq` | Phân tích output files |

### G2: Add GREP_PATTERNS cho QD2 + QD4 (HIGH)

File: `.claude/skills/workflow/_shared/probe_executor.py` — `GREP_PATTERNS` dict

Hiện tại chỉ có patterns cho QD1, QD3, QD5, QD6, QD7. Cần thêm cho QD2 và QD4:

**QD2 (Business Logic):**
```python
"P-QD2-hardcoded-value-detect": [
    r"[Tt][Aa][Xx][_-]?[Rr][Aa][Tt][Ee]\s*=",
    r"[Cc][Oo][Mm][Mm][Ii][Ss][Ss][Ii][Oo][Nn]\s*=",
    r"= 0\.[0-9]+",  # hardcoded decimals
],
"P-QD2-calculation-check": [
    r"\.reduce\(",
    r"parseFloat\(",
    r"parseInt\(",
    r"Math\.(floor|ceil|round)",
],
```

**QD4 (Performance):**
```python
"P-QD4-bundle-size-audit": [
    r"import.*from\s+['\"]lodash['\"]",
    r"import.*from\s+['\"]moment['\"]",
    r"import \*",
],
"P-QD4-db-query-analysis": [
    r"SELECT \*",
    r"find\(\s*\)",      # MongoDB unfiltered
    r"\.all\(\)",        # Django/SQLAlchemy load all
],
```

**Lưu ý:** Dùng `[ \t]` thay vì `\s` cho Windows compatibility. Patterns nên match được nội dung trong golden-v6 fixture.

### G3: Extend Golden-v6 Fixture (HIGH)

File: `.claude/skills/workflow/_shared/tests/fixtures/golden-v6/`

Hiện tại golden-v6 chỉ trigger signals cho QD1, QD3, QD5, QD6, QD7. Cần thêm nội dung cho QD2 và QD4:

**Thêm vào `src/orders.ts`:**
```typescript
// QD2: Hardcoded business values
private TAX_RATE = 0.1;
private COMMISSION_RATE = 0.05;

// QD2: Calculation
calculateTotal(items: any[]): number {
    const subtotal = items.reduce((sum, item) => sum + item.price * item.qty, 0);
    return subtotal * (1 + this.TAX_RATE);
}
```

**Thêm file mới `src/api/users.ts`:**
```typescript
// QD4: Performance issues
import _ from 'lodash';
import moment from 'moment';

export async function getAllUsers() {
    // QD4: Unfiltered DB query
    return db.query('SELECT * FROM users');
}
```

**Update `expected-signals.json`:** thêm expected counts cho QD2 và QD4.

### G4: Verify All 7 Dimensions End-to-End (HIGH)

Test file: `.claude/skills/workflow/_shared/tests/test_e2e_stage_f.py`

1. Update `test_golden_dispatch_all_dims` để dispatch tất cả 7 dimensions (không chỉ 5 grep dims)
2. Verify ≥6 dimensions có signals (QD4 runtime probes có thể 0 signals vì không có server)
3. Verify aggregation tạo issue-registry.json với correct issue count

### G5: Final Regression Suite (CRITICAL)

```bash
cd "z:/Working/MCV3/.claude/skills/workflow/_shared"
python -m pytest tests/ --tb=short
```

**Target:** 450+ tests, 0 failures, 0 regression.

Run sequence:
1. Run Stage G specific tests trước
2. Run full suite sau
3. Verify no circular imports: `python -c "import probe_executor; import lane_dispatch; import signal_aggregator"`

### G6: Cleanup (MEDIUM)

1. Xóa hoặc comment fallback code trong `probe_executor.py` nếu tất cả dimension.json đã có tool.kind đúng — hoặc giữ nhưng thêm comment "defense-in-depth, nên không cần nếu dimension.json đúng"
2. Verify `SUPPORTED_TOOL_KINDS` trong probe_executor.py khớp với tất cả tool.kind values thực tế trong 7 dimension.json files
3. Run `pyright` hoặc `mypy` check nếu có

---

## File Summary

### Files to MODIFY (in `.claude/skills/workflow/`)

| File | Thay đổi |
|------|----------|
| `_shared/probe_executor.py` | Thêm GREP_PATTERNS cho QD2, QD4 |
| `wf-fix-business/dimension.json` | Fix tool.kind: "grep"→"grep+jq", "fixture-runner"→? |
| `wf-fix-performance/dimension.json` | Thêm tool.kind cho 6 probes |
| `wf-fix-ux-a11y/dimension.json` | Thêm tool.kind cho 7 probes |
| `wf-fix-data/dimension.json` | Thêm tool.kind cho 6 probes |
| `wf-fix-compat/dimension.json` | Thêm tool.kind cho 5 probes |
| `_shared/tests/fixtures/golden-v6/src/orders.ts` | Thêm QD2 patterns |
| `_shared/tests/fixtures/golden-v6/src/api/users.ts` | Thêm QD4 patterns (file mới) |
| `_shared/tests/fixtures/golden-v6/expected-signals.json` | Update expected counts |
| `_shared/tests/test_e2e_stage_f.py` | Extend cho 7 dims |

### Files KHÔNG thay đổi

| File | Lý do |
|------|-------|
| `_shared/signal_bus/` | Stage E complete, stable |
| `_shared/lane_dispatch.py` | Stage F complete, stable |
| `_shared/scan_cache/` | Stage E complete, stable |
| `_shared/dimension_registry.py` | Stage E complete, stable |

---

## Success Criteria

1. ✅ Tất cả 43 probes trong 7 dimension.json có tool.kind hợp lệ (trong SUPPORTED_TOOL_KINDS)
2. ✅ GREP_PATTERNS cover QD2 + QD4 (7 dimensions total)
3. ✅ Golden-v6 fixture trigger signals cho ≥6 dimensions
4. ✅ 450+ tests pass, 0 failures, 0 regression
5. ✅ No circular imports
6. ✅ `execute_probe()` tìm được tool.kind từ dimension.json KHÔNG cần GREP_PATTERNS fallback
