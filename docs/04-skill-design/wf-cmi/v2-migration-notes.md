# wf-cmi v1 → v2 Migration Notes

> **Phiên bản v2.0.0** · **Ngày phát hành:** 2026-05-16 · **Khả năng tương thích ngược:** ✅ Backward-compat preserved
>
> Hướng dẫn migration cho skill maintainers, consumer skill owners, CI/CD operators, và stakeholder populate SSOTs khi nâng cấp wf-cmi từ v1.0.0 (10 lanes) → v2.0.0 (26 lanes Gói C++ Logistics).

---

## 1. Tóm tắt thay đổi v1 → v2

| Aspect | v1.0 | v2.0 | Breaking? |
|--------|------|------|-----------|
| Số lanes active | 10 (CD1-CD10) | **26** (CD1-7, CD9, CD11, CD13, CD15-18, CD23-26, CD28-31, CD37-40) | ⚠ Breaking |
| Graphs Phase 2 | 6 core | **13** (6 core + 7 plugin FE/BE) | Forward-compat |
| Dispatcher | 1-2 wave | **3-wave** via `wave-coordinator.sh` | Forward-compat |
| Coverage matrix dims | 10 | **35** (26 active + 9 SKIPPED markers) | ⚠ Schema bump v1→v2 |
| Cross-skill artifact | `integrity-impact-v1` | **`integrity-impact-v2`** với 5 v2 fields mới | ✅ Backward-compat |
| Profile=deep duration | ~45-60 min | **~55-90 min** (+50%) | ⚠ User aware |
| SSOT files mới mandatory | 0 | **7** (rbac, ux-conventions, workflow-state-machines, mdm-canonical-entities, audit-critical-entities, compliance-mapping, ui-interactivity-spec) | ⚠ Stakeholder action |
| Error codes new range | E001-E099 | E110-E149 (lane plugins + CDG) | Forward-compat |
| SKILL.md size | ≤500 dòng | ≤500 dòng (487 hiện tại) | ✅ CORE-032 preserved |
| Pipeline 8 phase structure | 8 phase | 8 phase (cùng) | ✅ Không thay đổi |

---

## 2. Quyết định kiến trúc chính

### 2.1 Profile naming (Option A — expand `deep`)

**Quyết định:** `--profile=deep` expand từ 10 lanes → 26 lanes (breaking).

**Rationale:**
- Option A đơn giản, không cần thêm profile name mới
- Tránh confusion `deep-v1` vs `deep-v2`
- User aware via migration notes + WARN khi resume v1 session

**Tradeoff:** Thời gian deep tăng ~50% (60 min → 90 min). CI users cần adjust timeout.

### 2.2 Backward-compat strategy (Option B — schema versioning)

**Quyết định:** Bump `$schema` field nhưng GIỮ tất cả v1 fields trong v2 artifact.

**Rationale:**
- Consumer skills (wf-verify-sync, wf-fix-bugs, wf-implement-feature, wf-prepare-deployment) hiện tại đọc theo path-based jq query
- Nếu v2 artifact có đầy đủ v1 fields → v1 reader vẫn hoạt động bình thường (just ignore v2 extras)
- Forward-compat: v2 readers tự detect `$schema` để route v1 hoặc v2 logic

**Cost:** Producer (wf-cmi) phải maintain dual structure (v1 fields preserved + v2 extras added).

### 2.3 CD32-CD36 vertical lanes (Option B — skeleton trong v2.0)

**Quyết định:** v2.0 ship 26 lanes active + thêm 5 skeleton entries cho CD32-CD36 trong `_contract.json.lanes_defined[]` với `status: "skeleton-v3-deferred"`.

**Rationale:**
- Tránh wf-cmi phình to vượt 500 dòng SKILL.md
- CD32-CD36 (Doc Lifecycle, Notification, Search, MultiTenant, Operational) cần procedure design riêng → defer v3.0
- Skeleton entries cho phép `--dims=CD32` early warning user "skill v2.0 chưa support, sẽ activate v3.0"

**Risk:** Vi phạm CORE-032 ở v3.0 nếu activate đủ 5 lanes → cần restructure SKILL.md hoặc extract lane catalog sang `procedures/_lane-catalog.md` lúc đó.

### 2.4 Mobile scope (only `erp-web`)

**Quyết định:** v2.0 chỉ scan `apps/erp-web/` cho FE graphs (fe-component/fe-api-client/fe-permission/fe-route).

**Rationale:**
- EUREKA-2026 có 5 clients: erp-web + mobile-customer + mobile-staff + web-customer + smarttax-web
- Scan toàn bộ → effort Stage 2-4 tăng 5x
- Defer mobile + web-customer + smarttax-web cho v2.1+

---

## 3. Migration cho Consumer Skills

### 3.1 Detect $schema field

Consumer skills (wf-verify-sync, wf-fix-bugs, wf-implement-feature, wf-prepare-deployment) khi đọc `integrity-impact.json` PHẢI detect schema version:

```bash
# Cách v1 (path-based) — vẫn hoạt động với v2 artifact:
overall_pct=$(jq -r '.coverage_matrix_summary.overall_pct' integrity-impact.json)

# Cách v2 (schema-aware):
schema=$(jq -r '.$schema' integrity-impact.json)
case "$schema" in
  integrity-impact-v1) echo "v1 artifact" ;;
  integrity-impact-v2)
    echo "v2 artifact"
    # Có thể access v2 extras
    must_count=$(jq -r '.logistics_critical_signals_count.must_severity_count' integrity-impact.json)
    wave1_status=$(jq -r '.wave_breakdown.wave_1.gate_status' integrity-impact.json)
    ;;
  *) echo "Unknown schema $schema, fallback v1 logic" ;;
esac
```

### 3.2 Recommended consumer actions (v2 extras)

| Consumer | v2 extra để consume | Logic mới |
|----------|--------------------|-----------|
| `wf-prepare-deployment` | `logistics_critical_signals_count.must_severity_count` | BLOCK release nếu > 0 |
| `wf-prepare-deployment` | `wave_breakdown.wave_X.gate_status` | BLOCK nếu bất kỳ wave FAIL_THRESHOLD |
| `wf-verify-sync` | `lanes_v2.skipped[]` | WARN user về 9 SKIPPED lanes (defer v2.1) |
| `wf-fix-bugs` | `group_breakdown.logistics.critical` | Prioritize logistics signals trong triage |
| `wf-implement-feature` | `gap_artifacts_suggested[]` (cùng v1) | Tạo artifact suggested khi implement |

### 3.3 Backward-compat verify

```bash
# Test v1 reader có đọc được v2 artifact không
for field in coverage_matrix_summary violations regression_scope \
             gap_artifacts_suggested consumers_recommended_actions \
             summary audit_chain; do
  jq -e ".${field}" integrity-impact.json > /dev/null && \
    echo "✓ v1 field $field accessible" || \
    echo "✗ MISSING v1 field $field"
done
```

Nếu tất cả PASS → consumer v1 logic hoạt động bình thường.

---

## 4. Migration cho Stakeholder (Populate SSOTs)

### 4.1 SSOT mandatory (7 files) — block lanes nếu missing

| SSOT | Block lane(s) | Người chịu trách nhiệm | Effort |
|------|---------------|--------------------------|--------|
| `rbac-permission-catalog.json` | CD15, CD38 | security + architect | 2-3 ngày (EUREKA: 91 perms × 17 modules) |
| `ux-conventions.json` | CD23, CD24, CD25 | ux-designer + brand-guardian | 2-3 ngày (design tokens, button variants, format rules) |
| `workflow-state-machines.json` | CD26 | business-analyst + architect | 3-4 ngày (9 state machines EUREKA) |
| `mdm-canonical-entities.json` | CD28 | data-engineer + BA + logistics-expert | 3-4 ngày (11 master + 8 reference data) |
| `audit-critical-entities.json` | CD29 | data-engineer + compliance-expert | 2 ngày (13 audit entities + PII access) |
| `compliance-mapping.json` | CD37 | compliance-expert + legal-expert | 4-5 ngày (5 VN + 3 CN + 3 intl regulations) |
| `ui-interactivity-spec.json` | CD38 | ux-researcher + frontend-developer + BA | 5-7 ngày (~100+ endpoints, 17 entities × 4 ops, 90+ perms) |

**Total effort estimate:** ~3-4 tuần stakeholder work song song nếu có 7 người. Sequential: ~6-7 tuần.

### 4.2 SSOT optional (2 files) — fallback heuristic

| SSOT | Fallback nếu missing | Coverage tradeoff |
|------|---------------------|----------------------|
| `error-code-catalog.json` | Grep heuristic detect raw error patterns | Mất signal MISSING_RECOVERY_ACTION + ERROR_MESSAGE_NOT_VIETNAMESE |
| `print-export-templates.json` | Filesystem scan tìm template files (.html, .liquid, .hbs, etc.) | Mất signal PRINT_TEMPLATE_DRIFT compliance (TT 78/2021) |

### 4.3 Quy trình populate

```bash
# Step 1: Copy template
cp plans/wf-cmi/rbac-permission-catalog.eureka-template.json \
   .mc-data/docs/_meta/rbac-permission-catalog.json

# Step 2: Strip metadata
jq 'del(._template_notes, ._instructions, ._schema_notes, ._comment)' \
   .mc-data/docs/_meta/rbac-permission-catalog.json > /tmp/clean.json
mv /tmp/clean.json .mc-data/docs/_meta/rbac-permission-catalog.json

# Step 3: Edit với giá trị thực tế EUREKA
# Đọc _instructions section trong template gốc trước khi sửa

# Step 4: Validate
jq -e '.' .mc-data/docs/_meta/rbac-permission-catalog.json > /dev/null && echo "JSON valid"
jq -e '.validation_rules.rules | length >= 5' \
   .mc-data/docs/_meta/rbac-permission-catalog.json > /dev/null && echo "Min validation_rules OK"
```

---

## 5. Migration cho CI/CD Operators

### 5.1 Timeout adjustment

| CI mode | v1 timeout | v2 timeout đề xuất |
|---------|-------------|------------------------|
| `--ci --profile=quick` | 15 min | 15 min (không đổi) |
| `--ci --profile=standard` | 45 min | 60 min (+15 min cho 3-wave overhead) |
| `--ci --profile=deep` | 90 min | **120 min** (+30 min cho 16 lanes mới) |
| `--ci --profile=exhaustive` | 240 min | 300 min |

### 5.2 GitHub Actions example

```yaml
name: WF-CMI Release Gate
on:
  pull_request:
    branches: [main]

jobs:
  cmi-deep:
    runs-on: ubuntu-latest-large  # cần RAM ≥16GB cho 26 lanes parallel
    timeout-minutes: 120  # v2.0 deep ~90 min worst case
    steps:
      - uses: actions/checkout@v4
      - name: Populate SSOTs from secrets
        run: |
          # Copy SSOT files từ secret storage (KHÔNG commit vào repo)
          cp ${{ secrets.SSOT_STORAGE }}/rbac-permission-catalog.json .mc-data/docs/_meta/
          # ... (7 mandatory SSOTs)
      - name: Run wf-cmi deep
        run: |
          /wf-cmi --ci --profile=deep --since=${{ github.event.pull_request.base.sha }}
      - name: Block release if MUST violations
        run: |
          must_count=$(jq -r '.logistics_critical_signals_count.must_severity_count' \
            .mc-data/work/wf-cmi/sessions/*/phase8-report/integrity-impact.json | head -1)
          [ "$must_count" -gt 0 ] && exit 1 || exit 0
```

### 5.3 Profile downgrade khi CI timeout

`--ci` mode tự động auto-downgrade nếu detect timeout sắp tới:

| Original profile | Auto-downgrade khi `--ci` + timeout < 30 min |
|-------------------|-----------------------------------------------|
| `deep` | → `standard` (CDG E108 WARN) |
| `exhaustive` | → ERROR E012 (chạy local) |

---

## 6. Migration cho User CLI

### 6.1 Quy trình lần đầu chạy v2.0

```bash
# Step 1: Verify SKILL.md là v2.0
jq -r '.version' .claude/skills/workflow/wf-cmi/_contract.json
# Expected: 2.0.0

# Step 2: Populate ít nhất 1 SSOT mandatory (vd rbac-permission-catalog)
# (xem §4.3 trên)

# Step 3: Run quick scan đầu tiên (subset, không cần SSOT)
/wf-cmi --profile=quick --scope=module=crm

# Step 4: Đọc integrity-report.md ≤55 dòng tiếng Việt
cat .mc-data/work/wf-cmi/sessions/*/phase8-report/integrity-report.md
```

### 6.2 Resume v1 session sau upgrade

Nếu có session v1 đang dở dang (interrupted) khi upgrade lên v2.0:

```bash
/wf-cmi --resume --session-id=<v1-session-id>
```

Pipeline v2.0 sẽ:
1. Detect session schema=v1 → WARN user
2. Hỏi qua CDG: "Continue với v1 logic (limited 10 lanes) / Re-start v2.0 (26 lanes)"
3. Default: re-start v2.0 (safer, full coverage)

### 6.3 Profile mapping (v1 → v2)

| v1 command | v2 equivalent | Note |
|-------------|----------------|------|
| `/wf-cmi --profile=quick` | `/wf-cmi --profile=quick` | Cùng 7 lanes (5 v1 + CD16/CD17 mới) |
| `/wf-cmi --profile=standard` | `/wf-cmi --profile=standard` | 13 lanes (7 v1 + CD11/CD13/CD16/CD17/CD18 + Wave 3 CD9) |
| `/wf-cmi --profile=deep` | `/wf-cmi --profile=deep` | **26 lanes** (10 v1 + 16 new) — thời gian +50% |
| `/wf-cmi --profile=exhaustive` | `/wf-cmi --profile=exhaustive` | 30+ lanes (26 + LLM enhance + deferred lanes opt-in) |

---

## 7. Known limitations v2.0

| Aspect | Limitation | Workaround | Plan |
|--------|------------|------------|------|
| Graph parser v1.0 (Grep-based) | Function signature types lost, dynamic permissions marked `dynamic_or_variable` | Lane runtime marks signal severity SHOULD (không MUST) cho false positive risk | v2.1 → ts-morph AST + Roslyn syntax tree |
| be-domain-graph references_entity edges | EUREKA fixture: 0 edges (parser limit) | CD16 AGGREGATE_BOUNDARY_VIOLATION coverage=0 trên EUREKA v2.0 | v2.1 Roslyn parser |
| be-db-schema-graph FK extraction | EUREKA: 0/1249 tables với declared FK (HasOne convention not extracted) | CD17 MISSING_INDEX coverage=0 | v2.1 parse OnModelCreating EntityTypeBuilder |
| Module heuristic (be-cqrs-graph) | EUREKA: handlers_without_request=1288 (namespace resolution không hoàn hảo) | CD18 mark severity SHOULD (không MUST) | v2.1 Roslyn full namespace resolution |
| Table-entity name matching | Naive PascalCase + singular drop trailing 's' fail với English irregular plurals + acronyms | CD17 SCHEMA_MISMATCH heuristic count-based | v2.1 proper English inflection library |
| Mobile scope | Chỉ scan erp-web | Mobile + web-customer defer v2.1 | v2.1 expand client scope |
| Stage 4 integration tests | Pending stakeholder populate 7 SSOTs | Run sau khi SSOTs ready | Track progress-update.md |

---

## 8. v2.1 Roadmap (preview, không commit)

| Feature | Lý do | Effort |
|---------|-------|--------|
| CD42 Carrier Integration | Logistics-critical, deferred v2.0 | 4-5 ngày |
| Re-activate CD12/CD14/CD22 (deep profile) | FE State / FE i18n / Config & Secret | 6 ngày |
| Mobile scope (mobile-customer + mobile-staff) | 2 clients còn lại | 4 ngày |
| ts-morph AST parsers (graph v2.1) | Eliminate Grep false positives | 7-10 ngày |
| Roslyn parsers cho .NET (graph v2.1) | be-domain + be-db-schema + be-cqrs accuracy | 10-14 ngày |
| Consumer wire-up `--from-cmi` | wf-verify-sync/wf-fix-bugs/wf-implement-feature/wf-prepare-deployment | 5 ngày |

---

## 9. Liên kết

- CHANGELOG v2.0.0: [`CHANGELOG.md`](../../../CHANGELOG.md)
- Skills catalog v2.0: [`docs/01-architecture/07-skills-catalog.md`](../../01-architecture/07-skills-catalog.md)
- User guide v2: [`docs/06-user-guides/per-skill/wf-cmi-v2-guide.md`](../../06-user-guides/per-skill/wf-cmi-v2-guide.md)
- Execution profiles canon v2: [`docs/04-skill-design/wf-cmi/05-execution-profiles.md`](05-execution-profiles.md)
- Architecture canon: [`docs/04-skill-design/wf-cmi/03-architecture.md`](03-architecture.md)
- Tradeoffs ADR: [`docs/04-skill-design/wf-cmi/08-tradeoffs-adr.md`](08-tradeoffs-adr.md)
- Templates SSOT: [`plans/wf-cmi/*.eureka-template.json`](../../../plans/wf-cmi/)
- Progress tracker: [`plans/wf-cmi/progress-update.md`](../../../plans/wf-cmi/progress-update.md)
- Wave coordinator script: [`.claude/scripts/wf-cmi/wave-coordinator.sh`](../../../.claude/scripts/wf-cmi/wave-coordinator.sh)
- 18 Lane procedures: [`.claude/skills/workflow/wf-cmi/procedures/lanes/CD*.md`](../../../.claude/skills/workflow/wf-cmi/procedures/lanes/)

---

## 10. Hỗ trợ

Vấn đề khi migrate? Check:
1. Troubleshooting section trong [user guide v2](../../06-user-guides/per-skill/wf-cmi-v2-guide.md#13-troubleshooting)
2. Error code reference: [`docs/04-skill-design/wf-cmi/05-error-codes.md`](05-error-codes.md)
3. Open issue tại repo MCV3 với label `wf-cmi-v2-migration`
