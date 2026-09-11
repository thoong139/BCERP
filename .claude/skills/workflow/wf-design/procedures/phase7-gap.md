# Phase 7: Gap Analysis (CHỈ LEGACY_MODE)

> Phân tích gaps giữa design mới và code hiện có.
> **CHỈ chạy khi `$LEGACY_MODE = true`**. Nếu false → SKIP phase này, đi thẳng Phase 8.

**PRE-GATE:**

```bash
# Re-detect LEGACY_MODE từ filesystem (CORE-021) thay vì tin env var — env vars không persist giữa phases.
LEGACY_MODE_DETECTED="false"
if test -f .mc-data/work/legacy-scan/project-context.md \
   && [ $(wc -c < .mc-data/work/legacy-scan/project-context.md) -gt 500 ]; then
  LEGACY_MODE_DETECTED="true"
fi

# Nếu không phải LEGACY → SKIP phase 7 hoàn toàn
if [ "$LEGACY_MODE_DETECTED" != "true" ]; then
  echo "SKIP Phase 7 — not LEGACY_MODE"
  exit 0
fi

# Phase 6 đã completed
jq -e '.design_status == "completed"' .mc-data/docs/_meta/req-registry.json

# Legacy scan data đã có
test -f .mc-data/work/legacy-scan/module-code-mapping.json
```

**INPUT:**
- `.mc-data/work/legacy-scan/module-code-mapping.json` (từ `/wf-legacy-extract` Stage 3.5)
- `.mc-data/work/legacy-scan/project-context.md`
- `.mc-data/work/wf-brainstorm/legacy-decisions.json` (`$DEPRECATED_MODULES`)
- Phase 3 architecture docs (from Phase 1-5 outputs)
- `.mc-data/work/wf-design/deferred-findings.md` (nếu tồn tại từ Phase 6)

**OUTPUT:**
- `.mc-data/work/legacy-scan/gap-report.md`
- `.mc-data/work/legacy-scan/gap-categories.json`
- `.mc-data/work/legacy-scan/action-items.json` (cho `/wf-plan-modules` Phase 0)
- `.mc-data/work/legacy-scan/final-report.md` (tổng hợp toàn pipeline)

---

## Scope Exclusion (BẮT BUỘC)

Trước khi gap analysis:

```
Đọc legacy-decisions.json → lấy module_dispositions action="DEPRECATE"
  → Loại các modules DEPRECATE ra khỏi gap analysis scope
  → Log trong gap-report.md: "Excluded from gap analysis (deprecated): [list]"
```

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 7.1 | Đọc `module-code-mapping.json` từ `.mc-data/work/legacy-scan/` | Mapping loaded |
| 7.2 | Đọc `legacy-decisions.json` → set `$DEPRECATED_MODULES` → loại khỏi scope | Scope filtered |
| 7.3 | Cross-reference architecture docs (Phase 3 output) với code hiện có | Gaps identified |
| 7.4 | Classify gaps:<br>- Missing cross-system contracts<br>- Data sync gaps<br>- Integration implementation gaps<br>- Security/auth gaps<br>- Performance optimization gaps<br>- Infrastructure gaps | Classification done |
| 7.5 | Tạo severity classification:<br>- CRITICAL: blockers cho implementation<br>- HIGH: quan trọng nhưng không blocking<br>- MEDIUM: cải thiện nên làm<br>- LOW: nice to have | — |
| 7.6 | Write `.mc-data/work/legacy-scan/gap-report.md` | File created |
| 7.7 | Write `.mc-data/work/legacy-scan/gap-categories.json` | File created |
| 7.8 | Assemble `action-items.json` theo schema. **Template Strip (ADR-OPT-05):** `jq 'del(._template_notes, ._comments)' action-items.json.tmp > action-items.json`. Write `.mc-data/work/legacy-scan/action-items.json` — cho `/wf-plan-modules` Phase 0 | `test -s action-items.json && jq 'has("_template_notes") \| not' action-items.json → true` |
| 7.9 | Update `.mc-data/work/wf-design/deferred-findings.md` với gap classification | File updated |
| 7.10 | Write `.mc-data/work/legacy-scan/final-report.md` — tổng hợp toàn pipeline: legacy scan context + design approach + gap summary + action plan | File created |

---

## POST-GATE

```bash
test -f .mc-data/work/legacy-scan/gap-report.md
test -f .mc-data/work/legacy-scan/action-items.json
jq '.' .mc-data/work/legacy-scan/action-items.json   # valid JSON
test -f .mc-data/work/legacy-scan/final-report.md
test -s .mc-data/work/legacy-scan/final-report.md

# Pipeline status
jq -e '.stages | .. | .status? == "completed"' .mc-data/work/legacy-scan/ledger.json > /dev/null 2>&1
grep -q '"pipeline_status".*"COMPLETE"' .mc-data/work/legacy-scan/ledger.json
```

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E013 | `module-code-mapping.json` không tồn tại | STOP → chạy `/wf-legacy-extract` trước |
| E014 | Gap classification fail | Retry với relaxed thresholds, escalate nếu fail |

---

## Next Phase

→ Read `procedures/phase8-digest-summary.md` — Digest + Phase Summary
