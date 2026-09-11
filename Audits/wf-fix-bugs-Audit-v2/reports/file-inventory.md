# File Inventory Report — wf-fix-bugs Audit v2

> **Task:** 0.2 — Stage 0 Infrastructure
> **Date:** 2026-05-12
> **DoD:** All files exist, non-empty, parseable. Inventory complete.

---

## Summary

| Category | Count | Pass | Fail | Notes |
|----------|-------|------|------|-------|
| SKILL.md files | 14 | 14 | 0 | All exist, ≥10KB, have frontmatter |
| _contract.json files | 14 | 14 | 0 | All valid JSON, have `$schema: skill-contract-v1`, `skill`, `version` |
| Bash scripts (wf-fix-*.sh) | 51 | 51 | 0 | All have shebang, all ≥1.8KB |
| **TOTAL** | **79** | **79** | **0** | |

> **Note:** Task spec says "12 SKILL.md + 12 contracts" but reality is 14 each (includes wf-fix-business-completeness QD11 and wf-fix-execute as separate SKILL.md with separate contracts).

---

## 1. SKILL.md Files (14)

| # | File | Size | Frontmatter | Status |
|---|------|------|-------------|--------|
| 1 | `.claude/skills/workflow/wf-fix-bugs/SKILL.md` | 45,810 | Yes | ✅ |
| 2 | `.claude/skills/workflow/wf-fix-functional/SKILL.md` | 14,430 | Yes | ✅ |
| 3 | `.claude/skills/workflow/wf-fix-business/SKILL.md` | 10,648 | Yes | ✅ |
| 4 | `.claude/skills/workflow/wf-fix-security/SKILL.md` | 11,663 | Yes | ✅ |
| 5 | `.claude/skills/workflow/wf-fix-performance/SKILL.md` | 10,338 | Yes | ✅ |
| 6 | `.claude/skills/workflow/wf-fix-ux-a11y/SKILL.md` | 11,037 | Yes | ✅ |
| 7 | `.claude/skills/workflow/wf-fix-data/SKILL.md` | 10,344 | Yes | ✅ |
| 8 | `.claude/skills/workflow/wf-fix-compat/SKILL.md` | 11,083 | Yes | ✅ |
| 9 | `.claude/skills/workflow/wf-fix-observability/SKILL.md` | 10,839 | Yes | ✅ |
| 10 | `.claude/skills/workflow/wf-fix-runtime-health/SKILL.md` | 13,186 | Yes | ✅ |
| 11 | `.claude/skills/workflow/wf-fix-integration/SKILL.md` | 14,681 | Yes | ✅ |
| 12 | `.claude/skills/workflow/wf-fix-business-completeness/SKILL.md` | 11,907 | Yes | ✅ |
| 13 | `.claude/skills/workflow/wf-fix-triage/SKILL.md` | 32,591 | Yes | ✅ |
| 14 | `.claude/skills/workflow/wf-fix-execute/SKILL.md` | 25,329 | Yes | ✅ |

**Total SKILL.md bytes:** 274,886 (~275 KB)

### Size Distribution

| Range | Count | Files |
|-------|-------|-------|
| Small (<12KB) | 7 | business, performance, ux-a11y, data, compat, observability, business-completeness |
| Medium (12-20KB) | 4 | functional, runtime-health, integration |
| Large (20-45KB) | 3 | triage (32.5K), execute (25.3K), orchestrator (45.8K) |

---

## 2. _contract.json Files (14)

| # | File | Size | `$schema` | `skill` | `version` | Status |
|---|------|------|-----------|----------|-----------|--------|
| 1 | `wf-fix-bugs/_contract.json` | 19,830 | skill-contract-v1 | wf-fix-bugs | 9.1.0 | ✅ |
| 2 | `wf-fix-functional/_contract.json` | 6,443 | skill-contract-v1 | wf-fix-functional | 2.0.0-alpha.s6 | ✅ |
| 3 | `wf-fix-business/_contract.json` | 5,002 | skill-contract-v1 | wf-fix-business | 2.2.0 | ✅ |
| 4 | `wf-fix-security/_contract.json` | 4,560 | skill-contract-v1 | wf-fix-security | 2.0.0-alpha.s4 | ✅ |
| 5 | `wf-fix-performance/_contract.json` | 4,286 | skill-contract-v1 | wf-fix-performance | 2.0.0-alpha.s4 | ✅ |
| 6 | `wf-fix-ux-a11y/_contract.json` | 4,340 | skill-contract-v1 | wf-fix-ux-a11y | 2.0.0-alpha.s4 | ✅ |
| 7 | `wf-fix-data/_contract.json` | 4,333 | skill-contract-v1 | wf-fix-data | 2.0.0-alpha.s4 | ✅ |
| 8 | `wf-fix-compat/_contract.json` | 4,247 | skill-contract-v1 | wf-fix-compat | 2.0.0-alpha.s4 | ✅ |
| 9 | `wf-fix-observability/_contract.json` | 4,824 | skill-contract-v1 | wf-fix-observability | 1.0.0 | ✅ |
| 10 | `wf-fix-runtime-health/_contract.json` | 7,321 | skill-contract-v1 | wf-fix-runtime-health | 1.0.0 | ✅ |
| 11 | `wf-fix-integration/_contract.json` | 7,443 | skill-contract-v1 | wf-fix-integration | 1.9.0 | ✅ |
| 12 | `wf-fix-business-completeness/_contract.json` | 4,162 | skill-contract-v1 | wf-fix-business-completeness | 1.0.0 | ✅ |
| 13 | `wf-fix-triage/_contract.json` | 7,109 | skill-contract-v1 | wf-fix-triage | 1.4.0 | ✅ |
| 14 | `wf-fix-execute/_contract.json` | 15,155 | skill-contract-v1 | wf-fix-execute | 3.6.0 | ✅ |

**Total contract bytes:** 99,155 (~99 KB)

### Version Summary

| Version | Count | Skills |
|---------|-------|--------|
| 9.1.0 | 1 | wf-fix-bugs (orchestrator) |
| 3.6.0 | 1 | wf-fix-execute |
| 2.2.0 | 1 | wf-fix-business |
| 2.0.0-alpha.s6 | 1 | wf-fix-functional |
| 2.0.0-alpha.s4 | 5 | security, performance, ux-a11y, data, compat |
| 1.9.0 | 1 | wf-fix-integration |
| 1.4.0 | 1 | wf-fix-triage |
| 1.0.0 | 3 | observability, runtime-health, business-completeness |

---

## 3. Bash Scripts (51)

### Infrastructure & Utility Scripts (24)

| # | Script | Size | Status |
|---|--------|------|--------|
| 1 | `wf-fix-browser-precheck.sh` | 5,351 | ✅ |
| 2 | `wf-fix-catalog-consume.sh` | 2,108 | ✅ |
| 3 | `wf-fix-catalog-emit.sh` | 2,586 | ✅ |
| 4 | `wf-fix-common.sh` | 20,347 | ✅ |
| 5 | `wf-fix-cost-estimator.sh` | 10,380 | ✅ |
| 6 | `wf-fix-cqg-verify.sh` | 9,562 | ✅ |
| 7 | `wf-fix-deprecation-block.sh` | 2,264 | ✅ |
| 8 | `wf-fix-detect-base-url.sh` | 11,766 | ✅ |
| 9 | `wf-fix-docs-crossref.sh` | 8,141 | ✅ |
| 10 | `wf-fix-flow-driver.sh` | 27,781 | ✅ |
| 11 | `wf-fix-impact-builder.sh` | 18,973 | ✅ |
| 12 | `wf-fix-incremental-scope.sh` | 9,900 | ✅ |
| 13 | `wf-fix-init-status.sh` | 8,764 | ✅ |
| 14 | `wf-fix-merge-non-static-probes.sh` | 5,117 | ✅ |
| 15 | `wf-fix-migrate-sessions.sh` | 13,595 | ✅ |
| 16 | `wf-fix-multi-app-coordinator.sh` | 12,473 | ✅ |
| 17 | `wf-fix-phase0-init.sh` | 3,146 | ✅ |
| 18 | `wf-fix-record-probe-failure.sh` | 2,919 | ✅ |
| 19 | `wf-fix-report-builder.sh` | 7,572 | ✅ |
| 20 | `wf-fix-safety-check.sh` | 13,564 | ✅ |
| 21 | `wf-fix-session.sh` | 7,405 | ✅ |
| 22 | `wf-fix-trace-rotate.sh` | 5,679 | ✅ |
| 23 | `wf-fix-validate-gate.sh` | 8,469 | ✅ |
| 24 | `wf-fix-probe-static-signal-validate.sh` | 9,323 | ✅ |

### Probe Scripts — Static (20)

| # | Script | Size | Status |
|---|--------|------|--------|
| 25 | `wf-fix-probe-static-a11y.sh` | 12,238 | ✅ |
| 26 | `wf-fix-probe-static-api-smoke.sh` | 12,667 | ✅ |
| 27 | `wf-fix-probe-static-business.sh` | 15,248 | ✅ |
| 28 | `wf-fix-probe-static-compat.sh` | 12,104 | ✅ |
| 29 | `wf-fix-probe-static-cta.sh` | 11,889 | ✅ |
| 30 | `wf-fix-probe-static-data.sh` | 11,664 | ✅ |
| 31 | `wf-fix-probe-static-deprecated.sh` | 21,690 | ✅ |
| 32 | `wf-fix-probe-static-depvuln.sh` | 8,804 | ✅ |
| 33 | `wf-fix-probe-static-go.sh` | 6,753 | ✅ |
| 34 | `wf-fix-probe-static-infra-preflight.sh` | 8,695 | ✅ |
| 35 | `wf-fix-probe-static-orm.sh` | 5,737 | ✅ |
| 36 | `wf-fix-probe-static-perf.sh` | 17,725 | ✅ |
| 37 | `wf-fix-probe-static-python.sh` | 8,286 | ✅ |
| 38 | `wf-fix-probe-static-react.sh` | 8,688 | ✅ |
| 39 | `wf-fix-probe-static-route.sh` | 7,195 | ✅ |
| 40 | `wf-fix-probe-static-sast.sh` | 7,479 | ✅ |
| 41 | `wf-fix-probe-static-schema-drift.sh` | 11,340 | ✅ |
| 42 | `wf-fix-probe-static-secret.sh` | 7,411 | ✅ |
| 43 | `wf-fix-probe-static-vue.sh` | 8,080 | ✅ |
| 44 | `wf-fix-probe-static-xref.sh` | 11,209 | ✅ |

### Probe Scripts — Dynamic/Browser (2)

| # | Script | Size | Status |
|---|--------|------|--------|
| 45 | `wf-fix-probe-playwright-axe.sh` | 5,915 | ✅ |
| 46 | `wf-fix-probe-playwright-cwv.sh` | 10,288 | ✅ |

### Probe Scripts — Cross-Module (2)

| # | Script | Size | Status |
|---|--------|------|--------|
| 47 | `wf-fix-probe-contract-drift.sh` | 21,473 | ✅ |
| 48 | `wf-fix-probe-cross-module-ref.sh` | 8,774 | ✅ |

### Other Probe Scripts (1)

| # | Script | Size | Status |
|---|--------|------|--------|
| 49 | `wf-fix-probe-dev-server.sh` | 10,220 | ✅ |

### QD11-Specific Scripts (2)

| # | Script | Size | Status |
|---|--------|------|--------|
| 50 | `wf-fix-qd11-signals-validate.sh` | 2,483 | ✅ |
| 51 | `wf-fix-qd11-skip-check.sh` | 1,812 | ✅ |

**Total bash script bytes:** ~487 KB

---

## 4. Observations & Notes

### OBS-001: Actual count differs from spec
Task spec states "12 SKILL.md + 12 contracts" but reality is 14 each. The extra 2 are:
- `wf-fix-business-completeness` (QD11) — added in v9.1.0, listed in CLAUDE.md
- The count of "10 lanes" in the spec may have excluded QD11 (newest) or counted triage+execute differently

### OBS-002: QD11 scripts untracked in git
Both `wf-fix-qd11-signals-validate.sh` and `wf-fix-qd11-skip-check.sh` show as untracked (`??` in git status). They exist on disk but are not committed. This is a git hygiene issue.

### OBS-003: Version skew across lane skills
- Core lanes (QD1-QD7) are at 2.0.0-alpha.s4-s6
- Newer lanes (QD8-QD11) are at 1.0.0-1.9.0
- Orchestrator at 9.1.0 is significantly ahead
- Triage at 1.4.0, Execute at 3.6.0

### OBS-004: 3 largest files
1. `wf-fix-bugs/SKILL.md` (45.8 KB) — orchestrator, largest by far
2. `wf-fix-triage/SKILL.md` (32.6 KB) — triage phase
3. `wf-fix-flow-driver.sh` (27.8 KB) — largest bash script

### OBS-005: All contracts have `$schema: skill-contract-v1`
Verified for all 14 contracts. Consistent with CLAUDE.md requirement.

---

## 5. DoD Verification

- [x] 14/14 SKILL.md files exist, non-empty (≥10KB), have YAML frontmatter
- [x] 14/14 _contract.json files exist, valid JSON, have `$schema`, `skill`, `version`
- [x] 51/51 bash scripts exist, have shebang, non-empty (≥1.8KB)
- [x] Inventory report written to `reports/file-inventory.md`
- [x] Total: 79 files verified, 0 failures

**Task 0.2 — COMPLETE**
