# Phase J — Migration & Documentation (Release)

> **Mục tiêu:** User-facing docs, release notes, v4.1 → v5.0 migration helper, final sign-off.
> **Duration:** 1-2 ngày
> **Dependencies:** Phase I complete (all tests pass)
> **Tag khi xong:** `v5.0.0` (release)

---

## Prerequisites

- [ ] Phase I tagged `v5.0-phase-I`
- [ ] All 12 E2E tests PASS
- [ ] Backward-compat golden test PASS
- [ ] Branch `feat/wf-legacy-scan-v5.0-phase-j`

---

## Tasks Overview

| ID | Task | Priority | Duration | Status |
|----|------|----------|----------|--------|
| J.1 | User guide `docs/wf-legacy-scan-v5-guide.md` | HIGH | 3-4 giờ | ⬜ |
| J.2 | Update CLAUDE.md (skill version + new flags) | HIGH | 1-2 giờ | ⬜ |
| J.3 | Release notes `docs/wf-legacy-scan-v5.0.0-release-notes.md` | HIGH | 2-3 giờ | ⬜ |
| J.4 | Migration helper script `scripts/migrate-legacy-scan-v4-to-v5.sh` | MEDIUM | 2-3 giờ | ⬜ |
| J.5 | Update `.claude/skills/workflow/wf-legacy-scan/README.md` | MEDIUM | 1-2 giờ | ⬜ |
| J.6 | Update `.claude/rules/00-core.md §4b` (new paths) | HIGH | 30' | ⬜ |
| J.7 | Example outputs committed to `docs/design/skills/wf-legacy-scan/examples/` | LOW | 2 giờ | ⬜ |
| J.8 | Final sign-off meeting + tag v5.0.0 | CRITICAL | 1 giờ | ⬜ |
| J.9 | Archive implementation plan | LOW | 30' | ⬜ |

---

## Task J.1 — User Guide

**Duration:** 3-4 giờ

### Content

Tạo `docs/wf-legacy-scan-v5-guide.md` (tiếng Việt):

### Sections

1. **Giới thiệu** — wf-legacy-scan là gì, khi nào dùng
2. **Chọn profile phù hợp** — Decision matrix theo project size, domain, timeline
3. **4 Profiles chi tiết:**
   - surface (khi nào, hạn chế)
   - standard (default, = v4.1)
   - deep (domain experts)
   - exhaustive (audit)
4. **CLI flags reference** — all 13 flags với examples
5. **IPS + Domain Detection** — EN + VN keyword pool, làm thế nào user biết domain được detect đúng
6. **Incremental re-scan** — `--incremental`, `--since`, cache
7. **Resume sau crash** — 4-level resume
8. **Workload Gate** — khi nào trigger, 3 options
9. **Troubleshooting** — common errors + solutions
10. **Migration từ v4.1** — không cần làm gì cho default usage

### Acceptance Criteria

- [ ] Guide ≥ 1,500 dòng (comprehensive)
- [ ] 20+ examples
- [ ] All 13 flags documented
- [ ] Vietnamese-language appropriate for non-specialist

---

## Task J.2 — Update CLAUDE.md

**Duration:** 1-2 giờ

### Actions

Update `CLAUDE.md`:

- Skill `wf-legacy-scan` bump 4.1.0 → 5.0.0
- Add new flags trong Arguments
- Update Fix & Quality table
- Link to new user guide

### Acceptance Criteria

- [ ] Version updated
- [ ] New flags documented
- [ ] User guide linked

---

## Task J.3 — Release Notes

**Duration:** 2-3 giờ

### Content

`docs/wf-legacy-scan-v5.0.0-release-notes.md`:

```markdown
# wf-legacy-scan v5.0.0 Release Notes

**Release date:** YYYY-MM-DD
**Compatibility:** Backward-compat with v4.1 (default profile = v4.1 behaviour)

## Highlights

- 🆕 4 Profiles (surface/standard/deep/exhaustive)
- 🆕 IPS 2-phase domain detection (EN + Vietnamese)
- 🆕 Session isolation + 4-level checkpoint
- 🆕 Concurrency controller + per-agent timeout
- 🆕 Scan cache (content-addressable)
- 🆕 Impact graph cho downstream verify-sync + fix-bugs R5
- 🆕 Workload Gate detect (partition defer v5.1)
- 🔄 Migrated sub-skills to scan-state.json canonical
- 🔧 Refactored 5 bash scripts (shared library, jq validation)

## Breaking Changes

None for default usage.

## Migration Guide

For users currently using `/wf-legacy-scan`:
- No action needed — default profile = v4.1 behaviour.
- Optional: try `--profile=deep` for complex projects.

For sub-skill direct users (rare):
- `/wf-legacy-classify` + `/wf-legacy-extract` now read scan-state.json.
- Helper auto-migrates v4.1 ledger.json if exists.

## Performance

(Measured trên 3 fixtures Phase I benchmark)

| Metric | v4.1 | v5.0 |
|--------|------|------|
| Standard profile 500 files | 30-90 min | 20-40 min |
| Deep extraction confidence | ~0.65 | ≥0.82 |
| Re-scan 20% changes | 100% | ≤30% |
| Cache hit rate | 0% | ≥60% |

## Deferred to v5.1

- Full Workload Partition Planner + multi-session aggregate
- ledger.json deprecation
- ML domain detection

## Credits

DEVKIT core team + Owner Eureka + VN keyword pool contributors.
```

### Acceptance Criteria

- [ ] Release notes published
- [ ] Metrics from Phase I included
- [ ] Migration guide clear

---

## Task J.4 — Migration Helper Script

**Duration:** 2-3 giờ

### Actions

Tạo `.claude/scripts/migrate-legacy-scan-v4-to-v5.sh`:

```bash
#!/usr/bin/env bash
# migrate-legacy-scan-v4-to-v5.sh
# Convert existing v4.1 ledger.json → v5.0 scan-state.json (one-time use).

source "$(dirname "${BASH_SOURCE[0]}")/legacy-scan-common.sh"

PROJECT_PATH="${1:-.}"
WORK_DIR="$PROJECT_PATH/.mc-data/work/legacy-scan"

if [[ ! -s "$WORK_DIR/ledger.json" ]]; then
  log_error "No v4.1 ledger.json found at $WORK_DIR"
  exit 1
fi

log_info "Migrating v4.1 → v5.0 at $WORK_DIR"

# 1. Create session dir
SESSION_ID="migrated-$(date -u +%Y-%m-%dT%H-%M-%S)"
SESSION_DIR="$WORK_DIR/sessions/$SESSION_ID"
mkdir -p "$SESSION_DIR/layers/L4" "$SESSION_DIR/layers/L5"

# 2. Project ledger.json → scan-state.json (inverse of generate_legacy_ledger)
jq --arg sid "$SESSION_ID" '{
  "$schema": "scan-state-v1",
  session: {
    id: $sid,
    created: (now | todate),
    project_path: ".",
    profile: "standard",
    strategy: .strategy.id,
    maturity_level: .maturity.level
  },
  depth_map: {L1:"full",L2:"full",L3:"full",L4:"standard",L5:"standard",L6:"full"},
  synthesis_mode: "full",
  layers: {
    L1: {status: "completed"},
    L2: {status: (.stages.assessment.status)},
    L3: {status: (.stages.inventory.status)},
    L4: {status: (.stages.classify.status), depth: "standard"},
    L5: {status: (.stages.extract.status), depth: "standard"},
    L6: {status: (.stages.synthesize.status)}
  },
  status: (if .pipeline_status == "COMPLETE" then "completed" else "in_progress" end),
  last_completed: (if .pipeline_status == "COMPLETE" then "L6" else "L3" end),
  error_log: .errors,
  resume_hint: "Migrated from v4.1 ledger.json"
}' "$WORK_DIR/ledger.json" > "$SESSION_DIR/scan-state.json"

validate_json "$SESSION_DIR/scan-state.json" || exit 1

log_info "Migration complete. Session: $SESSION_ID"
log_info "Test: /wf-legacy-scan --status"
```

### Acceptance Criteria

- [ ] Script converts ledger.json → scan-state.json
- [ ] Test trên fixture: migrate v4.1 baseline → valid v5.0 state
- [ ] `/wf-legacy-scan --status` works after migration

---

## Task J.5-J.6 — Skill README + 00-core.md

**Duration:** 1-2 giờ + 30'

### Actions

- Update `.claude/skills/workflow/wf-legacy-scan/README.md` (nếu tồn tại) với v5.0 architecture overview
- Update `.claude/rules/00-core.md §4b` với new paths:
  - `sessions/{id}/scan-state.json`
  - `sessions/{id}/scan-plan.md`
  - `sessions/{id}/phase-summary.md`
  - `domain-hints.json`
  - `impact-graph.json`

### Acceptance Criteria

- [ ] Skill README reflects v5.0
- [ ] 00-core.md §4b contract updated

---

## Task J.7 — Example Outputs

**Duration:** 2 giờ

### Actions

Commit sanitized example outputs từ 3 fixtures vào `docs/design/skills/wf-legacy-scan/examples/`:

```
examples/
├── small-en-standard/
│   ├── scan-state.json (sanitized)
│   ├── project-context.md
│   ├── domain-hints.json
│   └── impact-graph.json
├── medium-vn-standard/
│   └── ...
└── large-mixed-deep/
    └── ...
```

### Acceptance Criteria

- [ ] 3 example outputs committed
- [ ] Sanitized (no secrets, no PII)
- [ ] Linked từ user guide

---

## Task J.8 — Final Sign-off + Release Tag

**Priority:** CRITICAL · **Duration:** 1 giờ

### Actions

1. Meeting với Owner + DEVKIT core team.
2. Review:
   - All exit criteria from Phases A-I
   - Success metrics achievement
   - Known limitations
   - v5.1 roadmap
3. If approved:
   - Merge all phase branches to main
   - Tag `v5.0.0`
   - Push

```bash
git checkout main
for phase in a b c d e f g h i j; do
  git merge feat/wf-legacy-scan-v5.0-phase-$phase
done

git tag -a v5.0.0 -m "wf-legacy-scan v5.0.0 release — $(date +%Y-%m-%d)"
git push origin main v5.0.0
```

### Acceptance Criteria

- [ ] Owner sign-off
- [ ] All branches merged
- [ ] `v5.0.0` tag pushed
- [ ] MIGRATION-PROGRESS.md: Phase J ✅, overall ✅

---

## Task J.9 — Archive Implementation Plan

**Duration:** 30'

### Actions

Move implementation docs to archive:

```bash
mkdir -p docs/design/skills/wf-legacy-scan/archive/v5.0/
mv docs/design/skills/wf-legacy-scan/implementation/session-logs/ \
   docs/design/skills/wf-legacy-scan/archive/v5.0/session-logs/

# Keep phase plans for reference
cp -r docs/design/skills/wf-legacy-scan/implementation/ \
      docs/design/skills/wf-legacy-scan/archive/v5.0/implementation-completed/
```

### Acceptance Criteria

- [ ] Session logs archived
- [ ] Phase plans kept in archive for audit
- [ ] `implementation/` folder có note pointing to archive

---

## Exit Criteria (RELEASE)

- [ ] All 9 tasks ✅
- [ ] User guide published
- [ ] CLAUDE.md updated
- [ ] Release notes published
- [ ] Migration helper tested
- [ ] Owner sign-off
- [ ] **`v5.0.0` tag pushed** 🎉
- [ ] MIGRATION-PROGRESS.md: ALL ✅

## Post-Release

Monitor 2 weeks cho critical bugs. Nếu có:

- Hotfix branch `hotfix/v5.0.x`
- Fast-track through Phase I subset
- Tag `v5.0.x`

After 2 weeks stable → start v5.1 planning (Workload Partition).
