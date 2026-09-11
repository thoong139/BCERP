# Current State Analysis — wf-implement-feature v3.4.0

**Ngày phân tích:** 2026-04-28
**Phương pháp:** Đọc SKILL.md (596 dòng) + 13 procedure files (2520 dòng total) + _contract.json + so sánh với 3 peer skills (wf-fix-bugs, wf-scan-target v2.0.1, wf-legacy-scan v5.0)

---

## 1. Strengths (đã làm tốt — KHÔNG động vào)

| # | Khu vực | Trạng thái | Source |
|---|---------|-----------|--------|
| S1 | **Vietnamese-safe slug** với iconv ASCII translit + 60-char truncation + SHA1 suffix | v3.3.0 (Finding #2) | SKILL.md:200-227 |
| S2 | **Per-feature lock** với PID alive check + 1h stale detection | v3.2.0 | SKILL.md:247-319 |
| S3 | **Cross-Process Registry Mutex** với atomic `set -C`, stale detection 5 min, timeout 30s | v3.2.0 | _shared.md:96-149 |
| S4 | **A6-EXT executable spec** với STUB detection + populate gate (architect agent) | v3.3.0 (Finding #6) | phase1-feature-context.md:58, phase2-4-populate-spec.md |
| S5 | **CDG-02 file-overwrite gate** chỉ trigger cho IMPLEMENT_NEW (skip COMPLETE_EXISTING/MODIFY) | v3.3.0 (Finding #17) | phase3-tdd.md:44 |
| S6 | **POST-GATE T1-T4** đầy đủ với registry safe-write verify (Step 6.5) | Đã có | phase6-finalize.md:62-109 |
| S7 | **Adaptive Phase 4 review** (annotation_only / logic_change / new_files) | v3.3.0 (Finding #26) | _shared.md:268-277 |
| S8 | **Lazy-load 10 procedures + _shared.md ondemand** | Đã có | SKILL.md:122-136 |
| S9 | **Soft-resume fallback (A2-M1)** khi checkpoint.json chưa tạo | Đã có | SKILL.md:171-179 |
| S10 | **Decision Registry per-feature** với conflict check + Protocol 12 | Đã có | phase0-5-context-setup.md, phase3-tdd.md:82-88 |
| S11 | **Test framework auto-detect** từ project files (package.json/pyproject.toml/...) | v3.4.0 (Finding #14) | SKILL.md:24-26 |
| S12 | **Complexity derivation rule** (effort_estimate → file count → default) | v3.4.0 (Finding #5) | phase1-feature-context.md:61 |
| S13 | **Graceful registry inconsistency fallback** (description từ feature.title+notes) | v3.4.0 (Finding #1) | phase1-feature-context.md:55 |
| S14 | **CORE-026 trace** START/COMPLETE/FAIL events vào `_trace/session-log.json` | Đã có | SKILL.md:237 |
| S15 | **CORE-028 phase-summary.md** tiếng Việt cho non-specialist | Đã có | phase6-finalize.md:56 |

---

## 2. Gaps so với peer skills (cần bổ sung)

So sánh dựa trên `wf-fix-bugs v6.1.1`, `wf-scan-target v2.0.1` (vừa hoàn thành improvement plan), `wf-legacy-scan v5.0`:

### G1 — Session isolation flat (CORE-030 chưa đầy đủ) [P0]

**Hiện trạng:**
- Path: `.mc-data/work/wf-implement-feature/$FEATURE_SLUG/...`
- Tất cả files (impl-status.json, impl-plan.md, checkpoint.json, qa-review-attempt-N.md, impl-report.md, phase-summary.md, decision-registry.json, existing-patterns.json, contracts.json, cdg-tokens.json) **flat** trong cùng directory.

**Vấn đề:**
- Re-implement (EXTEND/MODIFY scenario) cho cùng feature → ghi đè state cũ. Không thể audit lịch sử implement của feature.
- Multi-Run Logic ở SKILL.md:441-468 dùng `run_history` array trong impl-status.json để track sessions, nhưng files khác (qa-review, impl-report) bị ghi đè.

**Peer reference:**
- wf-scan-target: `sessions/{YYYY-MM-DD}-{scope}[-{N}]/` (Protocol 18.2) + `.lock` + `current.txt`
- wf-legacy-scan v5.0: `sessions/{id}/` per ADR-LS05, runtime-only, có session-state.json + scan-state.json + error-ledger.json + events.jsonl
- wf-fix-bugs: `sessions/{id}/` với issue-registry.json, fix-log.json, lanes/QD*/

**Tác động:** Mất audit trail; CORE-030 không thực sự apply cho skill này.

**Ưu tiên:** P0 (Sprint 1)

---

### G2 — Bash scripts library = 0 [P0]

**Hiện trạng:**
- `.claude/scripts/`: 7 scan-target-*.sh, 24 legacy-scan-*.sh, 0 wf-implement-feature scripts
- Inline bash trong SKILL.md + procedures: ~150 dòng (slug normalize 8 dòng, per-feature lock 50+ dòng, registry mutex 50+ dòng, POST-GATE T1-T4 40+ dòng, framework detect inline)

**Vấn đề:**
- Context bloat: SKILL.md 596 dòng (vs wf-scan-target 380 dòng sau refactor)
- Khó test riêng từng pattern (lock, mutex, slug, postgate)
- Duplicate logic giữa SKILL.md và procedures (slug được derive trong SKILL.md:200 lẫn flow-multi.md)
- Khi pattern thay đổi (như Finding #16 hook fix), phải sửa nhiều nơi

**Peer reference:**
- wf-scan-target: 7 scripts, 88% token saving claim
- wf-legacy-scan: 24 scripts, source `legacy-scan-common.sh` chuẩn

**Đề xuất:** Tạo 7 scripts trong `.claude/scripts/wf-implement-feature/`:
1. `implement-common.sh` — source common (slug normalize, host shorthand, session ID generate, paths)
2. `implement-acquire-lock.sh` — per-feature lock + registry mutex (DRY pattern)
3. `implement-detect-stack.sh` — test framework, package manager, project type
4. `implement-safety-gate.sh` — CORE-020 search existing code (input: REQ-ID, output: JSON refs)
5. `implement-postgate.sh` — T1-T4 validator (input: $FEATURE_SLUG + $SESSION_ID, output: JSON pass/fail)
6. `implement-snapshot.sh` — registry diff verify (Step 6.5 Phase 6 safe-write)
7. `implement-history-index.sh` — append JSONL entry to .history/implementations-index.jsonl

**Ưu tiên:** P0 (Sprint 1)

---

### G3 — No JSONL history index → Multi-dev git-sync risk [P1]

**Hiện trạng:**
- Per-feature lock isolated (an toàn cho 1 dev). Multi-feature mode có orchestrator-only sequential write (an toàn).
- **Không có** central index liệt kê các implementation runs đã thực hiện. Thông tin chỉ trong `impl-status.json.run_history[]` per-feature.

**Vấn đề:**
- Khi 2 dev cùng làm trên repo: dev A implement FEAT-001, dev B implement FEAT-002. Cả hai commit + push.
- Branch merge: KHÔNG có conflict trên `$FEATURE_SLUG/` directories (khác feature) NHƯNG mất visibility tổng thể về "ai đã làm gì khi nào".
- Khi resolve conflict trên registry → không có audit trail bên ngoài registry.

**Peer reference:**
- wf-scan-target: `.mc-data/work/wf-scan-target/_shared/scans-index.jsonl` (1 line/scan, append-only, git-sync friendly)
- wf-scan-target: `history.jsonl` cho per-target

**Đề xuất:**
```
File: .mc-data/work/wf-implement-feature/.history/implementations-index.jsonl
Append-only, 1 line/run:
{"feature_slug":"...","feat_id":"...","session_id":"2026-04-28-103045-laptop","host":"laptop","user":"cntt","scenario":"NEW","started_at":"...","completed_at":"...","status":"completed","files_created":12,"files_modified":3,"tests_count":24,"profile":"standard","decisions_added":2}
```
- `.gitignore` ignore `sessions/` và `.locks/` và `.cache/`, **CHECK-IN** `.history/*.jsonl`
- Git merge với JSONL = trivial (newline-delimited, lexically sortable theo session_id)

**Ưu tiên:** P1 (Sprint 1)

---

### G4 — No `--profile` adaptive scaling [P1]

**Hiện trạng:**
- Flags rời rạc: `--component=entity|service|...`, `--parallel`, `--skip-tests`, `--skip-review`, `--micro-task`, `--features`
- Project nhỏ (50 files) chạy giống project lớn (5000 files): cùng review depth, cùng test scope, cùng batching strategy
- Phase 2 batching dựa trên A2.4 scope files, không adaptive theo tổng project size

**Peer reference:**
- wf-fix-bugs: `--profile=quick|standard|deep|exhaustive` driving dimension selection (ISG Recommender)
- wf-scan-target: `--profile=quick(5pages)|standard(25)|deep(50)|exhaustive(100)` page caps + LPM
- wf-legacy-scan: `--profile=surface|standard|deep|exhaustive` driving batch sizes (SMALL/MEDIUM/LARGE tier)

**Đề xuất matrix:**

| Profile | Phase 3 | Phase 4 review | Tests | Use case |
|---|---|---|---|---|
| quick | sequential, no waves | code-reviewer only | smoke only | hotfix, prototype |
| standard (default) | sequential | code+qa parallel | full unit | dev daily |
| deep | parallel waves | code+qa+security parallel | unit+integration | feature production-ready |
| exhaustive | parallel waves + e2e | code+qa+security+a11y+perf | unit+integration+e2e | release-candidate |

Profile resolver bash: count files trong A2.4 scope → recommend profile.

**Ưu tiên:** P1 (Sprint 2)

---

### G5 — No error-ledger.json + flat error codes [P2]

**Hiện trạng:**
- Error codes phẳng: E001-E014 (SKILL.md:566-582)
- Warnings chỉ track trong `impl-status.warnings[]` (v3.4.0 graceful fallback)
- Không có dedicated error file
- Khi multi-batch fail, không có centralized log

**Peer reference:**
- wf-legacy-scan v5.0 namespaced: E001-E014 (general), E015-E019 (Phase 0), E020-E029 (Phase 0B), E0101-E0199 (Phase 1), ...
- wf-legacy-scan: per-session `error-ledger.json` (orchestrator-only writer)

**Đề xuất namespace:**
- E1xx — Phase 1 (context, registry lookup, fallback)
- E2xx — Phase 2 (planning, populate-spec, contracts)
- E3xx — Phase 3 (TDD, test gate, decisions)
- E4xx — Phase 4 (review)
- E5xx — Phase 5a (cross-validation)
- E6xx — Phase 6 (registry write, finalize)
- E9xx — Cross-cutting (lock, mutex, hooks, history index)

Backward compat: alias E001-E014 cũ trong _shared.md.

**Ưu tiên:** P2 (Sprint 4)

---

### G6 — No pattern cache cho cùng module [P2]

**Hiện trạng:**
- Mỗi feature implement → phase0-existing-analysis.md scan từ đầu (EXTEND/MODIFY) → tạo `existing-patterns.json` per-feature.
- Implement FEAT-A (module CRM) xong, implement FEAT-B (cùng module CRM) → scan lại từ đầu, dù patterns không đổi (cùng commit).

**Tác động:** Tốn ~5-10k tokens/feature cho repetitive scan trong cùng module.

**Đề xuất:**
```
.mc-data/work/wf-implement-feature/.cache/{module_slug}/existing-patterns.{git_sha_short}.json
```
- TTL: max(24h, until git commit changes module path)
- Invalidation: hash của `git ls-tree -r HEAD -- $MODULE_PATH | sha1sum` thay đổi → cache miss
- `--no-cache` flag để bypass
- Phase 0 step phase0-existing-analysis: check cache trước khi scan

**Ưu tiên:** P2 (Sprint 2)

---

### G7 — No consumer hints trong impl-status.json/impl-report.md [P2]

**Hiện trạng:**
- impl-status.json schema: feature info, session, phases, files_created/modified, qa attempt
- impl-report.md: Quality Metrics, Files, Tests, Reviews
- Downstream skills (wf-preflight, wf-verify-sync) chỉ đọc registry impl_status. wf-prepare-deployment / wf-fix-bugs phải tự parse impl-report.md nếu muốn dùng.

**Peer reference:**
- wf-scan-target v2: target-map.json v2 schema có `consumer_hints` field (Sprint 5) cho `--from-scan` flag

**Đề xuất:**
```json
{
  "schema_version": "2.0",
  "consumer_hints": {
    "wf-prepare-deployment": {
      "files_for_changelog": [...],
      "breaking_changes": [...],
      "migrations_required": false
    },
    "wf-fix-bugs": {
      "scope_modules": ["crm/customer"],
      "test_files_added": [...],
      "decision_ids_new": ["D042","D043"]
    },
    "wf-verify-sync": {
      "req_ids_completed": ["REQ-..."],
      "files_with_req_id": 12
    }
  }
}
```
Cho phép skill khác `--from-impl=$FEATURE_SLUG` → đọc consumer_hints → skip re-scan.

**Ưu tiên:** P2 (Sprint 3)

---

### G8 — Phase numbering misleading [P3]

**Hiện trạng:**
- Phase orchestration table SKILL.md:327-340: phase0-existing-analysis → phase0-5-context-setup → phase1-feature-context → phase0-7-safety-gate → phase2-* → phase3 → phase4-5 → phase5a → phase6
- Phase 0.7 chạy SAU phase 1, không phải "0.7" theo nghĩa thứ tự

**Tác động:** Naming nhầm lẫn cho người đọc skill. Không phải bug correctness.

**Đề xuất rename:**
- phase0-existing-analysis → phase01-pattern-scan
- phase0-5-context-setup → phase02-context-setup
- phase1-feature-context → phase03-feature-context
- phase0-7-safety-gate → phase04-safety-gate
- phase2-planning → phase05-planning
- phase2-4-populate-spec → phase05a-populate-spec
- phase2-5-contracts → phase06-contracts
- phase3-tdd → phase07-tdd
- phase4-5-review-fix → phase08-review-fix
- phase5a-crossval → phase09-crossval
- phase6-finalize → phase10-finalize

Chỉ rename file + update SKILL.md/_contract.json/imports. Không thay đổi logic.

**Ưu tiên:** P3 (Sprint 4 — optional, có thể skip nếu user muốn giữ backward compat)

---

### G9 — Decision Registry per-feature, không cross-feature [P2]

**Hiện trạng:**
- `decision-registry.json` per-feature trong `$FEATURE_SLUG/decision-registry.json`
- Decisions ở FEAT-A KHÔNG tự inject vào FEAT-B cùng project

**Vấn đề:**
- Vi phạm Protocol 12 spirit (cross-feature consistency)
- Ví dụ: FEAT-A quyết định "soft delete cho tất cả entities" → FEAT-B implement xong, có thể dùng hard delete vì không thấy decision

**Đề xuất:**
- Promote `decision-registry.global.json` ở `.mc-data/docs/_meta/` (PRIMARY owner: wf-implement-feature, APPEND-only)
- Phase 0.5 đọc global trước khi seed feature-level
- Phase 3.5 append decisions mới với scope tag (project/module/feature)
- Cross-feature constraint reuse → không vi phạm decisions cũ

**Ưu tiên:** P2 (Sprint 3)

---

## 3. Tổng kết

| Priority | Gaps | Sprint |
|---------|------|--------|
| P0 (correctness) | G1 (session isolation), G2 (bash scripts) | Sprint 1 |
| P1 (multi-dev safety + adaptive) | G3 (history index), G4 (profile) | Sprint 1 + Sprint 2 |
| P2 (token efficiency + cross-skill utility) | G5 (error ledger), G6 (pattern cache), G7 (consumer hints), G9 (global decisions) | Sprint 2 + Sprint 3 + Sprint 4 |
| P3 (quality of life) | G8 (phase rename) | Sprint 4 (optional) |

**Tổng effort:** ~14h (5 sprints, không tính buffer cho user review)
**Backward compat:** Tất cả gaps fix là **append-only** với contracts hiện có. Không phá vỡ pipeline DEVKIT.
