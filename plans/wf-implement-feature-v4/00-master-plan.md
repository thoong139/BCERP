# Master Plan — wf-implement-feature v4.0

**Ngày tạo:** 2026-04-28
**Phiên bản từ:** v3.4.0 (2026-04-28)
**Phiên bản đích:** v4.0.0
**Estimated effort:** ~14h, chia 3 PRs (Sprint 1+2, Sprint 3+4, Sprint 5)

---

## 1. Mục tiêu (theo thứ tự ưu tiên — CORE-023)

### Ưu tiên 1: Độ chính xác

- Skill phải tuân thủ ĐẦY ĐỦ 19 Protocols + 31 CORE rules (đặc biệt CORE-030 session isolation)
- Output documents phải đạt POST-GATE T1-T4 (Protocol 10) — đã có ở v3.4.0
- Không có data loss khi multi-dev concurrent hoặc git-sync (cần thêm JSONL history index)
- Resume từ bất kỳ phase nào không mất progress (cần upgrade soft-resume → checkpoint primary)
- Re-implement (EXTEND/MODIFY scenario) không ghi đè state cũ (cần session subfolder)

### Ưu tiên 2: Tốc độ hoạt động

- Lazy-load procedures (đã có 10 phase files — KHÔNG đụng vào, chỉ rename optional)
- Pattern cache cho cùng module → tiết kiệm 5-10k tokens/feature khi implement multi-feature trong cùng module
- Profile-based execution: project nhỏ chạy quick mode, project lớn chạy deep mode với parallel waves
- Bash scripts thay AI inference cho enumeration tasks (slug normalize, lock acquire, framework detect, T1-T4 validate, history append)

### Ưu tiên 3: Tiết kiệm token

- Delegate ~30-40% inline bash sang scripts library (~150 dòng SKILL.md → ~50 dòng)
- Pattern cache module-level: existing-patterns scan 1 lần, reuse cho cả module
- Output v2 với consumer_hints → downstream skills không cần re-parse impl-report.md
- Profile=quick mode skip không cần thiết (review parallel, full e2e tests)

---

## 2. Scope

### Trong scope

| Khu vực | Ảnh hưởng |
|---------|-----------|
| `.claude/skills/workflow/wf-implement-feature/SKILL.md` | UPDATE: bump to v4.0.0, thêm --profile flag, đổi path patterns sang sessions/, simplify inline bash |
| `.claude/skills/workflow/wf-implement-feature/_contract.json` | UPDATE: bump version, thêm output paths mới (sessions/, .history/, .cache/), thêm schema_version vào outputs |
| `.claude/skills/workflow/wf-implement-feature/procedures/*.md` | UPDATE: thay path `$FEATURE_SLUG/` → `$SESSION_DIR/`, thêm pattern cache logic vào phase0-existing-analysis.md, thêm profile routing vào phase2-planning.md |
| `.claude/skills/workflow/wf-implement-feature/templates/` | UPDATE: impl-status.json schema_version=2.0, impl-report.md consumer_hints section, thêm error-ledger.json template |
| `.claude/skills/workflow/wf-implement-feature/evals/` | UPDATE: thêm ≥4 test cases (multi-session, profile, cache hit, error ledger) |
| `.claude/scripts/wf-implement-feature/*.sh` | TẠO MỚI 7 scripts (common, lock, detect-stack, safety-gate, postgate, snapshot, history-index) |
| `.claude/rules/00-core.md` §4b | UPDATE: thêm 3 paths mới (sessions/, .history/index, .cache/) |
| `.gitignore` (root project + .mc-data/) | UPDATE: ignore sessions/, .locks/, .cache/; CHECK-IN .history/*.jsonl |
| Memory: `project_wf-implement-feature-v4-improvement-plan.md` | TẠO + cập nhật progress |

### Ngoài scope (KHÔNG đụng vào)

- Các skills khác (`wf-design`, `wf-plan-modules`, `wf-verify-sync`, `wf-prepare-deployment`, `wf-fix-bugs`)
  - Chỉ thêm cross-skill consume **OPTIONAL** flag `--from-impl`, không thay đổi behavior mặc định
- `req-registry.json` schema — wf-implement-feature vẫn là `registry_scope.write_role: PRIMARY` của `impl_status` (giữ nguyên)
- Pipeline DEVKIT chính — workflow position không đổi
- Existing `$FEATURE_SLUG/` directories đã có — KHÔNG xóa, migrate qua script
- 26 findings đã fix ở v3.4.0 — KHÔNG regress
- A6-EXT/A7-EXT spec format từ wf-plan-modules — chỉ consume, không define lại

---

## 3. Definition of Done — v4.0.0

| # | Tiêu chí | Sprint chịu trách nhiệm |
|---|---------|------------------------|
| 1 | Session ID format `{YYYY-MM-DD}-{HHMMSS}-{shorthost}` lưu vào `$FEATURE_SLUG/sessions/{id}/` | Sprint 1 |
| 2 | Symlink/pointer `$FEATURE_SLUG/current.txt` trỏ đến session đang chạy | Sprint 1 |
| 3 | `--resume` đọc current.txt → join session, `--fresh` archive session cũ vào `archived/` | Sprint 1 |
| 4 | 7 bash scripts trong `.claude/scripts/wf-implement-feature/` (delegate ~30-40% inline bash) | Sprint 1 |
| 5 | `implementations-index.jsonl` append-only tại `$FEATURE_SLUG/.history/` (git-sync friendly) | Sprint 1 |
| 6 | `--profile=quick\|standard\|deep\|exhaustive` flag với behavior matrix | Sprint 2 |
| 7 | Pattern cache `$MODULE_SLUG/.cache/existing-patterns.{git_sha_short}.json` (TTL 24h hoặc git-invalidate) | Sprint 2 |
| 8 | Profile resolver bash script: file_count → recommend profile | Sprint 2 |
| 9 | `impl-status.json` schema_version="2.0" + consumer_hints section | Sprint 3 |
| 10 | Global decision registry tại `.mc-data/docs/_meta/decision-registry.global.json` (APPEND-only by wf-implement-feature) | Sprint 3 |
| 11 | Cross-skill flow OPTIONAL: `--from-impl` flag cho wf-prepare-deployment / wf-fix-bugs / wf-verify-sync | Sprint 3 |
| 12 | `error-ledger.json` per session (replace + extend impl-status.warnings[]) | Sprint 4 |
| 13 | Namespaced error codes E1xx (Phase 1), E2xx (Phase 2), ..., E6xx (Phase 6), E9xx (cross-cutting) | Sprint 4 |
| 14 | Backward compat alias: E001-E014 cũ → namespace mới trong _shared.md | Sprint 4 |
| 15 | Phase summary v2 với section "Cho skill kế tiếp" liệt kê downstream actions | Sprint 4 |
| 16 | Evals ≥ 10 cases (single, multi, resume, fresh, profile-quick/standard/deep, cache hit, multi-dev, error ledger) | Sprint 5 |
| 17 | `skill-compliance-audit.sh wf-implement-feature` PASS | Sprint 5 |
| 18 | `validate-schema-sync.sh wf-implement-feature` PASS | Sprint 5 |
| 19 | E2E regression test với FEAT-STW-ACCT-002 (baseline từ v3.4.0) | Sprint 5 |
| 20 | CLAUDE.md §4b cập nhật với 3 paths mới | Sprint 1 |

---

## 4. Roadmap (5 sprints)

| Sprint | Đầu vào | Đầu ra | Effort | PR Group |
|--------|---------|--------|--------|----------|
| **1. Foundation** | v3.4.0 hiện tại | Session-isolated dirs + 7 bash scripts + JSONL history index | 4h | PR #1 |
| **2. Adaptive Profile** | Sprint 1 | --profile flag + pattern cache + profile resolver | 3h | PR #1 |
| **3. Output Utility** | Sprint 2 | impl-status.json v2.0 + consumer_hints + global decision-registry | 3h | PR #2 |
| **4. Observability** | Sprint 3 | error-ledger + namespaced codes + phase summary v2 | 2h | PR #2 |
| **5. Evals + Audit** | Sprint 4 | Evals ≥ 10 cases + compliance audit + E2E regression | 2h | PR #3 |

**PR breakdown:**
- **PR #1 (Sprint 1+2):** Foundation + Adaptive — không thay đổi output schema, backward compat
- **PR #2 (Sprint 3+4):** Output schema v2.0 + observability — minor breaking (nhưng có alias)
- **PR #3 (Sprint 5):** Evals + audit — pure QA, không thay đổi runtime

**Ngày bắt đầu (dự kiến):** Sau khi user approve `03-decisions-pending.md`
**Ngày hoàn thành (dự kiến):** Trong 3-4 phiên làm việc

---

## 5. Risk register

| Risk | Mức | Mitigation |
|------|-----|-----------|
| Migration `$FEATURE_SLUG/` cũ → `sessions/{id}/` mới có thể mất data | Cao | Migration script: move vào `sessions/{date}-migrated/`, KHÔNG xóa. Backward compat read trong --resume. |
| Pattern cache stale → bug khi code module thay đổi | Trung | TTL 24h + git SHA invalidation. `--no-cache` flag để bypass. |
| schema_version=2.0 break consumer skills cũ | Thấp | Alias trong _shared.md + downstream chỉ ĐỌC OPTIONAL, không required. |
| Bash scripts compatibility Windows | Trung | Test với Git Bash + WSL như current scripts (legacy-scan-*.sh, scan-target-*.sh). Pattern đã verified. |
| E2E regression khác v3.4.0 baseline | Cao | Sprint 5 chạy lại FEAT-STW-ACCT-002 case, so sánh output từng phase. Block PR nếu fail. |
| Multi-dev parallel chạy migration script đồng thời | Thấp | Migration idempotent + per-feature lock đã có v3.2.0 |

---

## 6. Success criteria

Plan v4.0 thành công khi:

1. ✅ 20 Definition of Done items đều đạt
2. ✅ E2E regression FEAT-STW-ACCT-002 PASS (baseline từ v3.4.0)
3. ✅ Skill compliance audit PASS
4. ✅ Token saving đo được: ≥20% giảm cho repeated features trong cùng module (pattern cache)
5. ✅ Multi-dev test: 2 developers implement 2 features khác nhau, git merge thành công không mất history
6. ✅ Documentation: CHANGELOG v4.0.0 + RELEASE-NOTES + memory entry hoàn chỉnh
7. ✅ Cross-skill smoke test: `wf-prepare-deployment --from-impl` consume được consumer_hints
