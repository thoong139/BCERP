# 07 — Migration Plan: v4.1 → v5.0

> **Đọc trước:** [06-bash-scripts.md](06-bash-scripts.md)
> **Đọc tiếp:** [08-tradeoffs-adr.md](08-tradeoffs-adr.md)

---

## 1. Migration Principles

### 1.1 Zero Breaking Change cho User

| Aspect | Rule |
|--------|------|
| Entry point | `/wf-legacy-scan /path` — không đổi |
| Flags cũ | `--resume`, `--status`, `--re-vision`, `--batch-size` — vẫn hoạt động |
| Output locations | `.mc-data/work/legacy-scan/` — không đổi |
| Downstream contracts | Tất cả paths trong `00-core.md §4b` — không đổi |
| LEGACY_MODE | CORE-021 detection — không đổi |
| **Standard profile behaviour** | **= v4.1 behaviour** — business-analyst + 1 domain-expert per module |
| Sub-skills | wf-legacy-classify, wf-legacy-extract — MIGRATE trong Phase D (đọc scan-state.json trực tiếp, bỏ reverse-sync ledger.json). v2.1 change. |

### 1.2 Additive Changes Only

- Flags mới: `--profile`, `--layers`, `--depth`, `--session`, `--incremental`, `--since`, `--no-cache`, `--workload`, `--chunk`, `--cache-publish` — additive
- Files mới: `scan-state.json`, `domain-hints.json`, `impact-graph.json`, `sessions/`, cache — additive
- Schema mới: fields mới có default values, backward-readable
- Templates mới: thêm vào `templates/`, không xoá/đổi templates cũ

### 1.3 Phased Rollout

Migration chia thành **10 phases (A-J)**, mỗi phase independently deployable + rollbackable.

---

## 2. Phase A — Design Closure (3-5 ngày)

**Mục tiêu:** Đóng dấu thiết kế v2.0, sign-off, git tag.

**Actions:**
- Review 9 design files (đã hoàn thành)
- Resolve 3 remaining open questions (OQ-B, OQ-E, OQ-F)
- Sign-off với Owner Eureka + DEVKIT core team
- Git tag: `design-legacy-scan-v2.0-approved`
- Update CLAUDE.md với pointer tới design

**Deliverables:**
- Design v2.0 final (9 files)
- Sign-off record trong `08-tradeoffs-adr.md` §5

**Verify:**
- Tất cả ADR-LS01-LS14 marked Accepted
- 19 issues từ review v1.0 marked resolved

---

## 3. Phase B — Foundation (2-3 ngày)

**Mục tiêu:** Tạo infrastructure mới mà không thay đổi behaviour hiện tại.

### 3B.1: Bash Shared Library

**Files:**
- NEW: `.claude/scripts/legacy-scan-common.sh` (~600 dòng)

**Actions:**
- Extract shared functions từ 4 scripts
- Add `validate_json()`, `atomic_write_json()`, `has_jq()`, `cache_*`
- Add configurable constants
- Add UI detection shared functions
- Add `detect_domain_hints()`

**Verify:**
```bash
source .claude/scripts/legacy-scan-common.sh
# All functions accessible, no errors
declare -f atomic_write_json validate_json detect_domain_hints
```

### 3B.2: Session Infrastructure

**Files:**
- MODIFY: `.claude/skills/workflow/wf-legacy-scan/procedures/phase0-detection.md` (add session creation)
- NEW: `.claude/skills/workflow/wf-legacy-scan/templates/scan-state.json` (template)
- NEW: `.claude/skills/workflow/wf-legacy-scan/templates/scan-plan.md` (template, alias `legacy-scan-plan.md`)
- NEW: `.claude/skills/workflow/wf-legacy-scan/templates/phase-summary.md` (template)
- NEW: file-lock acquire/release helper

**Actions:**
- Add session directory creation vào Phase 0
- Add `scan-state.json` initialization
- Add `ledger.json` backward-compat generation (from scan-state.json)
- Add file-lock protection

**Verify:**
```bash
# Session created, scan-state.json valid
jq '.' .mc-data/work/legacy-scan/sessions/*/scan-state.json
# ledger.json still generated (backward compat)
test -f .mc-data/work/legacy-scan/ledger.json
# File lock works (start 2 concurrent — second should fail)
```

**Rollback:** Xóa `sessions/` directory + revert procedure changes; scripts vẫn chạy như v4.1.

---

## 4. Phase C — Profile System + IPS (2-3 ngày)

**Mục tiêu:** Thêm profile selection + IPS 2-phase, default = standard (= v4.1).

### 4C.1: Profile Resolver

**Files:**
- MODIFY: `.claude/skills/workflow/wf-legacy-scan/SKILL.md` (add profile routing block)
- NEW: `.claude/skills/workflow/wf-legacy-scan/procedures/phase0b-profile.md`

**Actions:**
- Add `--profile`, `--depth`, `--layers` flag parsing
- Add profile → depth_map resolution
- Default profile = `standard` (backward compat)
- Add AskUserQuestion for profile selection (when IPS available + no flag)

**Profile → depth_map (standard = v4.1 equivalent):**
```
standard: {
  L1: full, L2: full, L3: full,
  L4: standard,
  L5: standard,  # business-analyst + 1 domain-expert per module
  synthesis_mode: full
}
```

**Verify:**
```bash
# Without --profile: defaults to standard
# With --profile=surface: surface depth map applied
# With --profile=deep: deep depth map applied
# Standard profile produces same output as v4.1 on golden test project
```

### 4C.2: IPS Engine (2-phase)

**Files:**
- MODIFY: `.claude/skills/workflow/wf-legacy-scan/procedures/phase0a-assessment.md` (add IPS-A step)
- NEW: `.claude/skills/workflow/wf-legacy-scan/procedures/phase1-inventory.md` IPS-B step
- NEW: `.claude/skills/workflow/wf-legacy-scan/templates/domain-hints.json`
- MODIFY: `.claude/scripts/legacy-scan-assess.sh` (add domain detection enrichment)

**Actions:**
- Add domain hint detection vào assessment script (preliminary in L1, enriched in L2)
- Generate `domain-hints.json`
- Add IPS-A inline logic (sau L2)
- Add IPS-B inline logic (sau L3)
- Add AskUserQuestion với IPS recommendation (khi không --profile)

**Verify:**
```bash
# domain-hints.json generated after L2
jq '.detected_domains' .mc-data/work/legacy-scan/domain-hints.json
# IPS recommendation in scan-state.json
jq '.ips.phase_a.recommended_profile' sessions/*/scan-state.json
jq '.ips.phase_b.module_routing' sessions/*/scan-state.json
```

**Rollback:** IPS optional — nếu skip, default profile = standard (= v4.1).

---

## 5. Phase D — Domain-Aware Agent Delegation + Sub-skill Migration (4-5 ngày — v2.1 UPDATED)

**Mục tiêu:** Orchestrator truyền depth + domain context cho sub-skills. **Backward-compat lock cho standard profile.** **Migrate sub-skills đọc `scan-state.json` trực tiếp — bỏ reverse-sync ledger.json (v2.1 change).**

### 5D.0: Sub-Skill State Migration (NEW — v2.1)

**Rationale:** v2.0 plan giữ reverse-sync ledger ↔ scan-state trong Phase B-E rồi deprecate Phase F+. Review v2.0 phát hiện: reverse-sync là debt dài hạn với race condition phức tạp (file-lock + advisory lock + merge rules). v2.1 chốt migrate sub-skills ngay trong Phase D (cùng lúc với agent upgrade) để loại bỏ 1 class lỗi.

**Files:**
- MODIFY: `.claude/skills/workflow/wf-legacy-classify/SKILL.md` (read scan-state.json thay ledger.json)
- MODIFY: `.claude/skills/workflow/wf-legacy-classify/procedures/*.md` (PRE-GATE đọc scan-state)
- MODIFY: `.claude/skills/workflow/wf-legacy-extract/SKILL.md` (same)
- MODIFY: `.claude/skills/workflow/wf-legacy-extract/procedures/*.md` (same)
- NEW: `.claude/skills/workflow/_shared/scan_state_reader.py` (hoặc bash helper) — helper function `read_scan_state()` / `update_scan_state_layer()` tái dùng cho cả 2 sub-skills.

**Actions:**
- Sub-skill PRE-GATE đọc `.mc-data/work/legacy-scan/sessions/{latest}/scan-state.json` thay vì `ledger.json`.
- Sub-skill WRITE layer progress (batch_progress, module_progress) vào `scan-state.layers.L4` / `scan-state.layers.L5` qua helper.
- Helper function ensures file-lock + atomic write + state machine validation (not_started → in_progress → completed).
- Remove ledger.json write paths trong sub-skill procedures.
- Orchestrator generate ledger.json **1 lần cuối** khi synthesis hoàn tất (cho downstream skills cũ đọc legacy path). KHÔNG sync ngược.

**Backward-compat guarantee:**
- `ledger.json` vẫn được orchestrator tạo ở POST Phase 4 synthesize — cùng schema v4.1 — để downstream skills (wf-brainstorm, wf-analyze-requirements, ...) không bị break.
- Sub-skills KHÔNG ghi `ledger.json` nữa → zero race condition.

**Verify:**
```bash
# Sub-skill standalone run (không qua orchestrator)
/wf-legacy-classify --resume
# Đọc scan-state.json từ session latest, update layers.L4.batch_progress
jq '.layers.L4.batch_progress' sessions/*/scan-state.json
# ledger.json KHÔNG được sub-skill ghi (mtime unchanged during classify run)
stat -c '%Y' ledger.json  # before
/wf-legacy-classify --resume
stat -c '%Y' ledger.json  # after — same mtime expected
```

**Rollback:**
- Revert sub-skill procedure changes → quay về đọc ledger.json.
- Re-enable legacy ledger.json read+write trong orchestrator như v4.1 (rollback sub-skill migration).

### 5D.1: Classification Agent Upgrade

### 5D.1: Classification Agent Upgrade

**Files:**
- MODIFY: `.claude/skills/workflow/wf-legacy-scan/procedures/phase2-classify.md`
- MODIFY: `.claude/skills/workflow/wf-legacy-classify/SKILL.md` (depth config + IPS hints)

**Actions:**
- Replace `subagent_type="general-purpose"` với `subagent_type="code-reviewer"` direct spawn
- Add depth parameter passing trong agent prompt
- Add surface depth: heuristic grouping inline (no agent)
- Add deep depth: code-reviewer + domain-expert (glossary enrichment)
- Keep POST-GATE validation unchanged

**Agent type mapping:**
```
surface:  no agent (heuristic inline)
standard: code-reviewer (per batch) — was general-purpose, now direct
deep:     code-reviewer + domain-expert (glossary enrichment)
```

**Verify:**
```bash
# Surface: classified/auto-grouped.json exists
# Standard: classified/batch-N.json from code-reviewer (matches v4.1 output schema)
# Deep: glossary.json enriched với domain terms
# Coverage ≥95% per batch
```

### 5D.2: Extraction Agent Upgrade (BACKWARD-COMPAT LOCK)

**Files:**
- MODIFY: `.claude/skills/workflow/wf-legacy-scan/procedures/phase3-extract.md`
- MODIFY: `.claude/skills/workflow/wf-legacy-extract/SKILL.md` (domain hint routing)

**Actions:**
- Add surface depth: SKIP L5 entirely
- Standard depth: spawn `business-analyst` + 1 domain-expert per module (matches v4.1 — BACKWARD-COMPAT LOCK)
  - Domain expert chọn từ scan-state.ips.phase_b.module_routing
  - Fallback: business-analyst only nếu no domain match
- Deep depth: same + enriched prompt + cross-validation pass
- Add domain-expert selection logic from IPS

**Agent routing (CANONICAL):**
```
surface:  SKIP (no extraction)
standard: business-analyst + 1 domain-expert (if match ≥0.6 — v2.1 raised từ 0.4)
          fallback: business-analyst only
deep:     business-analyst + 1 domain-expert (enriched prompt)
          fallback: business-analyst only
```

**Verify:**
```bash
# Surface: no extracted/ files (L5 skipped)
# Standard: extracted/*.json from business-analyst + domain-expert
#   - confidence ≥0.6 per requirement
#   - Match v4.1 output for sample modules (golden test)
# Deep: extracted/*.json with confidence ≥0.8
```

**Rollback:** Agent routing fallback về business-analyst nếu domain-expert không available.

**Critical test:** Run v5.0 standard profile + v4.1 on cùng test project → outputs phải gần như identical (same modules, same REQ-IDs, comparable confidence).

---

## 6. Phase E — 4-Level Checkpoint + Concurrency + Cache (3-4 ngày)

**Mục tiêu:** Resilience + scale cho dự án lớn.

### 6E.1: 4-Level Checkpoint

**Files:**
- MODIFY: All phase procedure files (add checkpoint hooks)
- NEW: Checkpoint helper functions trong `_shared.md`

**Actions:**
- L0 Phase checkpoint: scan-state.last_completed update mỗi phase boundary
- L1 Layer checkpoint: scan-state.layers.<L>.status = in_progress/completed
- L2 Batch/Module checkpoint: batch_progress / module_progress
- L3 Intra-batch checkpoint: layers/<L>/partial.json (sau mỗi file/feature)

**Verify:**
- Crash injection test: kill orchestrator at random points → --resume continues từ correct unit
- Lost units ≤1 (file or feature)

### 6E.2: Concurrency Controller

**Files:**
- NEW: Concurrency controller logic trong SKILL.md (inline) + helper functions
- MODIFY: phase2-classify.md, phase3-extract.md (use controller)

**Actions:**
- Token bucket: global=8, per_layer=3, per_probe=4, reserve=2
- Per-spawn check: acquire token before Agent call, release after
- Queue if cap reached

**Verify:**
- Spawn 5 modules concurrent → only 3 active (per_layer=3 cap)
- Total agents ≤8 globally
- No OOM on large project test

### 6E.3: Scan Cache

**Files:**
- NEW: Cache helper functions trong `legacy-scan-common.sh`
- MODIFY: phase1-inventory.md, phase2-classify.md, phase3-extract.md (cache check)
- NEW: `.gitignore` entry for session cache

**Actions:**
- Compute fingerprint per probe input
- 2-tier cache: session (`sessions/{id}/cache/`) + project (`.mc-data/cache/wf-legacy-scan/`)
- Invalidation rules (file hash, dep closure, probe version, TTL)
- `--no-cache` flag override
- `--cache-publish` flag for project cache commit

**Verify:**
- Re-scan unchanged project: ≥80% cache hit
- Re-scan with 20% file changes: ~30% time savings
- `--no-cache` forces full re-run

---

## 7. Phase F — Impact Graph + Incremental (2 ngày — v2.1 REDUCED)

> **v2.1 change:** Workload Partitioning (Gate + Partition Planner + multi-session aggregate) DEFER sang **v5.1** (Phase F'). Lý do: aggregate merge semantic chưa rõ ràng cho conflict REQ-ID + project-context.md; cần fixture benchmark trước khi lock contract. v5.0 chỉ phát hiện workload lớn (IPS-B) và WARN user → gợi ý giảm profile hoặc scope, KHÔNG auto-partition.
>
> v5.0 scope giữ lại:
> - Impact graph (ADR-LS14) — downstream consumers cần.
> - Incremental mode (ADR-LS10) — phần base, không có aggregate multi-chunk.
> - Workload Gate detection + WARN (không partition).

**Mục tiêu:** Impact graph cho downstream + incremental base mode.

### 7F.1: Workload Gate (Detect + WARN only — v2.1 REDUCED)

**Files:**
- NEW: `.claude/skills/workflow/wf-legacy-scan/procedures/workload-gate.md` (detect + WARN logic — không partition)
- MODIFY: phase1-inventory.md (thêm IPS-B workload estimate + Gate trigger)

**Actions:**
- Workload Gate trigger sau IPS-B theo threshold §2.5 09-thresholds-justification.md.
- Hiển thị WARN + AskUserQuestion (CDG): `continue-as-is / downgrade-profile / abort`.
- **KHÔNG** generate `fix-workload.json`, KHÔNG partition, KHÔNG multi-session.
- User chọn `downgrade-profile` → apply depth_map mới, tiếp tục.
- User chọn `continue-as-is` → log warning, tiếp tục.
- User chọn `abort` → STOP + suggest re-run với smaller scope hoặc wait v5.1 Workload Partitioning.

**Verify:**
- Trigger Workload Gate on test project >1,000 files → WARN hiển thị.
- User chọn downgrade → profile đổi từ deep → standard, execution tiếp tục.
- KHÔNG có fix-workload.json được tạo.

### 7F.1-future: Workload Partitioning (v5.1 — DEFERRED)

**Defer to v5.1:** Full Partition Planner + multi-session aggregate sẽ thiết kế riêng trong v5.1:
- Aggregate merge semantic cho REQ-ID conflict.
- project-context.md merge strategy (section-wise union + dedup).
- Chunk dependency graph cho topological execution.
- Benchmark trên 3+ ERP fixtures trước khi release.

### 7F.2: Impact Graph

**Files:**
- NEW: `.claude/skills/workflow/wf-legacy-scan/templates/impact-graph.json`
- MODIFY: phase4-synthesize.md (add impact graph build)

**Actions:**
- Build impact-graph.json từ dependency-graph + code analysis + REQ cross-refs
- Detect circular deps + orphan modules
- Output for downstream `/wf-verify-sync` + `/wf-fix-bugs`

**Verify:**
- impact-graph.json có nodes + edges + relations
- Schema validates với jq
- `/wf-verify-sync` consume successfully

### 7F.3: Incremental Mode

**Files:**
- MODIFY: SKILL.md (add `--incremental`, `--since` flags)
- MODIFY: phase1-inventory.md (add staleness check + delta processing)
- MODIFY: `legacy-scan-staleness.sh`

**Actions:**
- `--incremental --since=<git-ref>` → git diff scope
- `--incremental` (no since) → mtime + content hash compare với previous scan
- Delta processing per layer (xem [02 §7](02-scan-layers.md))

**Verify:**
- Re-scan with `--incremental --since=HEAD~5`: only re-process diff files
- Output merged correctly với cache hits

---

## 8. Phase G — Bash Script Refactor (2-3 ngày)

**Mục tiêu:** Refactor 4 scripts với shared library + jq validation + configurable caps.

### 8G.1: Refactor Order

```
1. legacy-scan-detect.sh (simplest)
2. legacy-scan-assess.sh (medium)
3. legacy-scan-staleness.sh (small)
4. ui-coverage-scan.sh (UI deduplication target)
5. legacy-scan-inventory.sh (largest, most risk)
```

**Files:**
- MODIFY: All 5 scripts (source common.sh)

**Actions per script:**
- Source `legacy-scan-common.sh`
- Replace duplicated functions với shared
- Add `atomic_write_json` for all JSON outputs
- Make caps configurable (env vars)
- Add jq validation post-write

**Verify:**
```bash
# All scripts run without error
.claude/scripts/legacy-scan-detect.sh /path/to/project /tmp/test
# JSON outputs valid
for f in /tmp/test/*.json /tmp/test/inventory/*.json; do
  jq empty "$f" || echo "INVALID: $f"
done
# Compare with v4.1 baseline outputs (should match)
```

---

## 9. Phase H — Resume Routing (1 ngày — v2.1 REDUCED)

**Mục tiêu:** Implement 4-level Resume Router trên scan-state.json canonical (v2.1 — sub-skills đã migrate trong Phase D, không còn reverse-sync logic).

### 9H.1: Resume Router dựa trên scan-state.json

**Files:**
- MODIFY: SKILL.md (Resume Router 4-level inline logic)
- MODIFY: `.claude/skills/workflow/wf-legacy-scan/procedures/resume-status.md`

**Actions:**
- scan-state.json là canonical read target cho resume.
- 4-level routing (phase / layer / batch / intra-batch) theo 03-architecture §2.2.
- Ledger.json generation logic (1 lần POST Phase 4) đã implement trong Phase B foundation + orchestrator Phase 4 synthesize — Phase H không cần thêm.
- File-lock for concurrent protection (đã implement Phase B).

**Verify:**
```bash
# scan-state.json là single source of truth cho resume
jq '.last_completed, .layers.L4.batch_progress, .layers.L5.module_progress' sessions/*/scan-state.json

# Resume tiếp tục từ đúng unit cuối cùng
# Test: kill mid-L4 batch 3/5 → --resume continues from batch 4
# Test: kill mid-L5 module 3/8 → --resume continues from module 4
# Test: kill mid-L5 module 3 feature 5/12 → --resume continues from feature 6

# Standalone sub-skill run fallback (helper auto-init session từ ledger.json v4.1 legacy)
/wf-legacy-classify --resume  # session tự tạo nếu chưa có
```

### 9H.2: 4-Level Resume Router

**Files:**
- MODIFY: `.claude/skills/workflow/wf-legacy-scan/procedures/resume-status.md`

**Actions:**
- Add unified resume routing via scan-state.json
- 4-level routing (phase / layer / batch / intra-batch)
- Keep backward compat: if scan-state.json missing, fall back to ledger.json
- Add `--session=ID` flag for specific session resume

**Verify:**
- Kill scan mid-L4 batch 3 of 5 → --resume continues from batch 4
- Kill scan mid-L5 module 3 of 8 → --resume continues from module 4
- Kill scan mid-L5 module 3 feature 5 of 12 → --resume continues from feature 6

---

## 10. Phase I — Integration & Testing (3-5 ngày)

### 10I.1: SKILL.md Integration

**Files:**
- MODIFY: `.claude/skills/workflow/wf-legacy-scan/SKILL.md` (full v5.0)
- MODIFY: `.claude/skills/workflow/wf-legacy-scan/_contract.json` (version bump 5.0.0, new outputs)

### 10I.2: Sub-skill Updates

**Files:**
- MODIFY: `.claude/skills/workflow/wf-legacy-classify/SKILL.md` (depth support — backward-compat)
- MODIFY: `.claude/skills/workflow/wf-legacy-classify/_contract.json` (add IPS hint inputs)
- MODIFY: `.claude/skills/workflow/wf-legacy-extract/SKILL.md` (domain routing — backward-compat lock)
- MODIFY: `.claude/skills/workflow/wf-legacy-extract/_contract.json` (add IPS hint inputs)

### 10I.3: Cross-Skill Contract Updates

**Files:**
- MODIFY: `.claude/rules/00-core.md` §4b (add new paths)
- MODIFY: `CLAUDE.md` (update wf-legacy-scan version + flags)

**New paths:**
- `.mc-data/work/legacy-scan/sessions/{id}/scan-state.json`
- `.mc-data/work/legacy-scan/sessions/{id}/scan-plan.md`
- `.mc-data/work/legacy-scan/sessions/{id}/phase-summary.md`
- `.mc-data/work/legacy-scan/domain-hints.json`
- `.mc-data/work/legacy-scan/impact-graph.json`
- `.mc-data/work/legacy-scan/workloads/{workload-id}/fix-workload.json`
- `.mc-data/cache/wf-legacy-scan/probes/`

### 10I.4: E2E Validation

**Test fixtures:**
- Small project: 50 files, 3 modules, healthy
- Medium project: 500 files, 10 modules, finance domain
- Large project: 1,500 files, 30 modules, finance + logistics
- Very large project: 5,000 files, 60+ modules, ERP

**Test scenarios:**
```bash
# Compliance audit
./.claude/scripts/skill-compliance-audit.sh wf-legacy-scan
./.claude/scripts/skill-compliance-audit.sh wf-legacy-classify
./.claude/scripts/skill-compliance-audit.sh wf-legacy-extract

# Schema sync
./.claude/scripts/validate-schema-sync.sh --all

# Profile tests
/wf-legacy-scan /path/small --profile=surface     # ~5 min
/wf-legacy-scan /path/medium --profile=standard   # ~25 min
/wf-legacy-scan /path/large --profile=deep        # ~75 min
/wf-legacy-scan /path/erp --profile=exhaustive    # Workload Gate triggered

# Backward-compat
/wf-legacy-scan /path/medium  # default standard
# Compare output với v4.1 baseline → should match

# Resume
/wf-legacy-scan /path/large --profile=deep
# Kill mid-L5
/wf-legacy-scan /path/large --resume
# Verify resume from correct module + feature

# Incremental
/wf-legacy-scan /path/medium  # initial
git checkout some-changes
/wf-legacy-scan /path/medium --incremental --since=HEAD~3
# Verify only changed files re-processed

# Workload partitioning
/wf-legacy-scan /path/erp --profile=deep
# Workload Gate triggered → choose Plan A
/wf-legacy-scan --workload=wl-erp-... --chunk=ch-001  # parallel
/wf-legacy-scan --workload=wl-erp-... --chunk=ch-002  # parallel
/wf-legacy-scan --workload=wl-erp-... --aggregate
```

---

## 11. Phase J — Migration & Documentation (1-2 ngày)

### 11J.1: User Documentation

**Files:**
- NEW: `docs/wf-legacy-scan-v5-guide.md` (user guide)
- UPDATE: `CLAUDE.md` (skill description + flags)
- UPDATE: skill examples directory

**Content:**
- New profile selection guide
- Workload partitioning guide
- Cache + incremental usage
- Migration from v4.1 (no action needed for default usage)

### 11J.2: Developer Documentation

**Files:**
- UPDATE: `.claude/skills/workflow/wf-legacy-scan/README.md` (architecture overview)
- NEW: `docs/wf-legacy-scan-architecture.md` (technical deep dive)

### 11J.3: Migration Script (optional)

**Files:**
- NEW: `.claude/scripts/migrate-legacy-scan-v4-to-v5.sh`

**Purpose:**
- Convert existing `ledger.json` → `scan-state.json`
- One-time use cho projects đã scanned bởi v4.1

---

## 12. Timeline Summary (v2.1 UPDATED)

| Phase | Duration | Dependencies | Risk | Parallelizable? |
|-------|----------|-------------|------|----------------|
| **A: Design Closure** | 2-3 ngày | None | Low | No |
| **B: Foundation** | 2-3 ngày | A | Low | No |
| **C: Profiles + IPS (+ VN keywords)** | 3-4 ngày | B | Low-Medium | No |
| **D: Agent Upgrade + Sub-skill Migration** | 4-5 ngày | A, B, C | **High** (backward-compat critical + sub-skill migration) | No |
| **E: Checkpoint + Concurrency + Cache** | 3-4 ngày | B, D | Medium | Yes (with G) |
| **F: Impact Graph + Incremental (NO workload partition)** | 2 ngày | E | Low | Yes (with G) |
| **G: Bash Refactor** | 2-3 ngày | B | Low | Yes (with E, F) |
| **H: Resume Routing (reverse-sync bỏ — v2.1)** | 1 ngày | E | Low | No |
| **I: Integration + Testing** | 3-5 ngày | A-H | High | No |
| **J: Migration + Docs** | 1-2 ngày | I | Low | No |
| **Total (sequential)** | **23-32 ngày** | — | — | — |
| **Total (with parallel E/F/G)** | **19-26 ngày** | — | — | — |

**v2.1 Delta:**
- Phase A giảm 1 ngày (resolve OQs đã chốt trong 09/10).
- Phase C tăng 1 ngày (VN keywords).
- Phase D tăng 1 ngày (sub-skill migration — bỏ reverse-sync debt).
- Phase F giảm 1 ngày (workload partition defer v5.1).
- Phase H giảm 1 ngày (bỏ reverse-sync protocol logic).
- **Net:** tương đương timeline v2.0 nhưng loại bỏ reverse-sync debt + thêm VN support.

**Critical path:** A → B → C → D → I → J

**Parallelizable:** Phases E, F, G có thể chạy song song nếu ≥2 implementer.

---

## 13. Backward Compatibility Matrix

| Feature | v4.1 Behavior | v5.0 Behavior | Compat? |
|---------|--------------|---------------|---------|
| `/wf-legacy-scan /path` | Full pipeline | Standard profile (= v4.1 behavior) | ✅ Same |
| `--resume` | Read ledger.json | Read scan-state.json, fallback ledger.json (4-level routing) | ✅ Better |
| `--status` | Read ledger.json | Read scan-state.json, fallback ledger.json | ✅ Same |
| `--re-vision` | Trigger S6 strategy | Trigger S6 strategy + apply to selected profile | ✅ Same |
| `--batch-size=N` | Pass to classify | Pass to classify (unchanged) + scan-state.config.batch_size | ✅ Same |
| Output file locations | `.mc-data/work/legacy-scan/` | Same locations | ✅ Same |
| project-context.md format | Full synthesis | Full synthesis (standard profile) | ✅ Same |
| ledger.json | Created by scan (read+write by sub-skills) | Generated **1 lần** bởi orchestrator tại POST Phase 4; sub-skills KHÔNG ghi nữa (v2.1). Downstream skills cũ vẫn đọc được. | ✅ Compatible (read-only legacy projection) |
| Sub-skill API | classify/extract reads+writes ledger | classify/extract reads+writes **scan-state.json** qua helper; không touch ledger.json (v2.1) | ⚠️ Internal API change — sub-skill procedures update trong Phase D |
| L4 agent | code-reviewer (via general-purpose wrapper) | code-reviewer direct (better) | ✅ Same output |
| L5 agent | business-analyst + 1 domain-expert | business-analyst + 1 domain-expert | ✅ **LOCKED SAME** |
| `--profile` | N/A | New flag, default=standard | ✅ Additive |
| `--depth` | N/A | New flag | ✅ Additive |
| `--session` | N/A | New flag | ✅ Additive |
| `--incremental --since=...` | N/A | New flag | ✅ Additive |
| `--workload=... --chunk=...` | N/A | New flag | ✅ Additive |
| `--no-cache` | N/A | New flag | ✅ Additive |
| `--cache-publish` | N/A | New flag | ✅ Additive |

**Critical guarantee:** `/wf-legacy-scan /path` (no flags) on cùng project → output v5.0 ≈ v4.1 (same modules, same REQ-IDs, same impl-status).

---

## 14. Rollback Strategy

Mỗi phase independently rollbackable.

| Phase | Rollback Action | Data Impact |
|-------|----------------|-------------|
| A | Revert design git tag | None |
| B | Xóa `legacy-scan-common.sh` + `sessions/` directory; revert procedure changes | Scripts vẫn chạy v4.1 mode |
| C | Xóa profile routing; default = standard always; xóa IPS code | Behavior = v4.1 |
| D | Revert agent type back to general-purpose; remove depth/domain context | Sub-skills run with v4.1 default |
| E | Disable concurrency controller; revert checkpoint to phase-level only; disable cache | Performance = v4.1 |
| F | Disable workload gate; remove --workload/--chunk flags; remove impact graph | Functional = v4.1 (no scale features) |
| G | Revert scripts to inline functions (no shared library) | Bash = v4.1 |
| H | Revert state management to ledger.json only | Resume = phase-level (v4.1) |
| I | Full revert via git branch | Complete v4.1 restore |
| J | Update docs to reflect rollback | Communication |

**Git strategy:**
- Each phase on separate feature branch
- Merge to main only after PASS compliance audit + E2E test
- Tag main after each phase complete: `v5.0-phase-B`, `v5.0-phase-C`, etc.

**Hot-rollback procedure:**
```bash
# If issue found in production:
git revert <phase-merge-commit>
# OR
git checkout v5.0-phase-<previous>
```

---

## 15. Risk Register

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Standard profile output differs from v4.1 | Medium | **HIGH** (breaks downstream) | Phase D critical path; golden test cases; output comparison; lock backward-compat in spec |
| ~~Reverse-sync ledger ↔ scan-state race condition~~ | ~~Low~~ | ~~High~~ | **v2.1 ELIMINATED** — sub-skills migrate đọc scan-state trực tiếp trong Phase D; ledger.json chỉ generate 1 lần bởi orchestrator. |
| Sub-skill migration breaks standalone `/wf-legacy-classify` run | Medium | Medium (user friction) | Helper function (`scan_state_reader.py`) có fallback: nếu scan-state.json không tồn tại → tự init session hoặc đọc legacy ledger.json |
| Cache invalidation bug | Medium | Medium (stale data) | Conservative TTL (14 days); --no-cache fallback; clear invalidation rules |
| Workload Gate UX confusion | Low | Low (user friction) | Clear UI mockup; default to safe Plan; --no-interactive bypass |
| Concurrency controller deadlock | Low | Medium (hang) | Token timeout; queue with max wait; emergency abort |
| File-lock contention | Low | Low (forced wait) | Stale lock detection (mtime > 1h); `--force-unlock` flag |
| 4-level checkpoint overhead | Low | Low (slight slowdown) | Throttle 5s minimum between writes; only write on complete units |
| Cross-platform bash incompat | Medium | Medium (Windows users) | CI test matrix (Linux/Mac/Windows Git Bash/WSL) |
| Domain expert agent unavailable | Low | Low (degraded extraction) | Graceful fallback to business-analyst |
| Migration helper bug | Low | Medium (cannot resume v4.1 sessions) | Optional helper; v4.1 ledger.json read still supported |

---

## 16. Success Criteria

Migration considered successful khi:

1. **Backward-compat verified:** Standard profile output ≈ v4.1 output trên 5+ test projects (same modules, same REQ-IDs, same impl-status; ±5% confidence drift acceptable).
2. **All metrics M1-M11 hit target** (xem [README §7](README.md)).
3. **0 regressions** trên existing user workflows.
4. **3+ ERP projects scanned successfully** with workload partitioning.
5. **CI tests 100% pass** trên all 4 platforms.
6. **Documentation complete** + user guide published.
7. **Performance baseline:**
   - Surface profile: ≤10 min cho 500 files
   - Standard profile: ≤40 min cho 500 files
   - Re-scan với cache: ≤30% full scan time
8. **No critical bugs** trong 2 weeks production usage.
