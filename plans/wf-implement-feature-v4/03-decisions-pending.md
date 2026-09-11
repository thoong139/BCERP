# Decisions — wf-implement-feature v4.0

**Trạng thái:** ✅ **LOCKED 2026-04-28** — Claude tự quyết định theo best practice cho skill hoạt động chính xác và tốt nhất.
**Cơ sở quyết định:** Đồng bộ pattern với peer skills (wf-scan-target v2.0, wf-fix-bugs v6.1.1, wf-legacy-scan v5.0), tuân thủ BHV-002 (Simplicity First) và CORE-023 (Priority Order: chính xác > tốc độ > token).

---

## D1 — Path migration cho data v3.x cũ

**Câu hỏi:** Đổi path từ `$FEATURE_SLUG/foo.json` (flat) sang `$FEATURE_SLUG/sessions/{id}/foo.json` (subfolder)?

### ✅ QUYẾT ĐỊNH: **Option A** — Migration script idempotent

**Lý do chọn:**
- Sạch sẽ về lâu dài: KHÔNG dual-path code phức tạp
- KHÔNG mất data: files chỉ được MOVE vào `sessions/{date}-migrated/`, không xóa
- Idempotent: chạy 2 lần không break (skip nếu đã migrate)
- Auto-trigger: SKILL.md Phase 0 step 0.0 detect old layout → chạy migration → continue
- Đồng bộ với cách wf-legacy-scan v5.0 migrate từ v4.x (file `migrate-legacy-scan-v4-to-v5.sh` đã làm tương tự)

**Loại bỏ:**
- ~~B (Backward compat dual-path)~~ — code bloat, technical debt lâu dài
- ~~C (Fresh start yêu cầu user xóa)~~ — unacceptable risk: user có thể mất state đang dở

**Thực hiện ở:** Sprint 1 step 1.8 (`implement-migrate-v3-to-v4.sh`)

---

## D2 — Profile naming convention

**Câu hỏi:** Profile tên nào?

### ✅ QUYẾT ĐỊNH: **Option A** — `quick / standard / deep / exhaustive`

**Lý do chọn:**
- Đồng bộ với 2/3 peer skills:
  - wf-scan-target v2.0: `quick / standard / deep / exhaustive` ✓
  - wf-fix-bugs v6.1.1: `quick / standard / deep / exhaustive` ✓
  - wf-legacy-scan v5.0: `surface / standard / deep / exhaustive` (chỉ "surface" khác — nhưng "surface" implies scan layer, không phù hợp implement)
- Người dùng MCV3 đã quen pattern này từ 2 skills khác
- Cross-skill consistency: user gõ `--profile=deep` nhớ một lần, áp dụng tất cả skills

**Loại bỏ:**
- ~~B (surface/...)~~ — "surface" không match nghĩa implement (không phải scan layer)
- ~~C (fast/normal/thorough/strict)~~ — không đồng bộ peer skills
- ~~D (light/medium/heavy/max)~~ — không đồng bộ peer skills

**Thực hiện ở:** Sprint 2 step 2.1 (Profile matrix definition)

---

## D3 — Pattern cache TTL strategy

**Câu hỏi:** Cache invalidation policy?

### ✅ QUYẾT ĐỊNH: **Option C** — TTL 24h + git SHA hash invalidation

**Lý do chọn:**
- **Bảo thủ — ưu tiên correctness (CORE-023)**: Hai cơ chế invalidation song song giảm tối đa risk dùng stale cache
- TTL 24h: bắt mọi thay đổi sau 1 ngày (kể cả uncommitted changes — vì code có thể có WIP files chưa commit)
- Git SHA hash (`git ls-tree -r HEAD -- $MODULE_PATH | sha1sum`): bắt commit thay đổi module ngay lập tức, không đợi 24h
- Compute hash ~50ms — không đáng kể
- `--no-cache` flag để force bypass khi user nghi ngờ
- Trace event CACHE_HIT/CACHE_MISS để observability

**Loại bỏ:**
- ~~A (TTL only)~~ — stale risk khi commit liên tục
- ~~B (Git SHA only)~~ — miss uncommitted changes (WIP files)
- ~~D (Manual only)~~ — user dễ quên, defeat mục đích cache

**Thực hiện ở:** Sprint 2 steps 2.5, 2.6 (`implement-cache-resolver.sh`)

---

## D4 — Phase rename (G8)

**Câu hỏi:** Rename phase files từ phase0/0.5/0.7/1/.../6 → phase01..phase10?

### ✅ QUYẾT ĐỊNH: **Option C** — KHÔNG rename trong v4.0

**Lý do chọn:**
- **BHV-002 (Simplicity First)**: KHÔNG refactor code đang work nếu không cần thiết. Naming confusing là minor cosmetic, không phải bug correctness.
- **BHV-003 (Surgical Changes)**: Chỉ đổi đúng những gì cần. Rename 11 files + update tất cả internal refs trong _shared.md, SKILL.md, _contract.json, plus git history blame impact — effort ~1h cho cosmetic.
- **Risk hedging**: Sprint 1-3 đã có nhiều breaking changes (path migration, schema bump, bash delegation). Thêm rename trong Sprint 4 sẽ tăng surface area cho regression bugs.
- **Defer cleanly**: Rename có thể làm trong v5.0 sau khi v4.0 stable. Naming hiện tại đã document rõ trong SKILL.md table, người đọc skill tài liệu sẽ hiểu thứ tự thực tế.
- **Backward compat**: Giữ nguyên file names = 0 risk break consumer references trong external docs/memory/plans.

**Loại bỏ:**
- ~~A (Rename tất cả)~~ — effort cao, risk regression cho cosmetic gain
- ~~B (Rename selective)~~ — vẫn confusion vì half-renamed

**Thực hiện ở:** Sprint 4 step 4.6 — **SKIP** (giữ nguyên phase file names hiện tại)
**Tracked for v5.0:** Ghi vào memory followups khi v4.0 release.

---

## D5 — Sprint sequencing & PR strategy

**Câu hỏi:** Thứ tự sprint và cách chia PR?

### ✅ QUYẾT ĐỊNH: **Option A** — Sequential S1→S5, 3 PRs

**Lý do chọn:**
- **Dependency tự nhiên**: S2 (profile) build trên session structure từ S1; S3 (consumer_hints) thêm field vào schema sau S2 profile field; S4 (error ledger) populate from all phases; S5 evals test toàn bộ.
- **PR breakdown logic**:
  - **PR #1 (S1+S2)**: Foundation + Adaptive — thay đổi infrastructure (paths, scripts, profile) nhưng KHÔNG break output schema → reviewer dễ verify backward compat
  - **PR #2 (S3+S4)**: Output schema v2.0 + observability — minor breaking với alias support → reviewer focus vào schema migration safety
  - **PR #3 (S5)**: Pure QA (evals + audit + E2E) → reviewer focus vào test coverage
- **Ít PR overhead** so với 5 PRs riêng biệt: tiết kiệm ~2h review/merge time
- **Rollback granularity ổn**: 3 PRs đủ để rollback từng logical group nếu cần

**Loại bỏ:**
- ~~B (5 PRs riêng)~~ — overhead review cao, mỗi PR phải tự-contain documentation
- ~~C (Test sớm S5 partial)~~ — eval framework cần tất cả features ready mới có nghĩa
- ~~D (Skip sprint)~~ — tất cả 5 sprints có giá trị độc lập, không nên skip

**Thực hiện ở:** Toàn plan — sprint files đã viết theo thứ tự này.

---

## Q1 — Backward compat consumer skills (--from-impl flag)

**Câu hỏi:** Sprint 3 có modify 3 consumer skills (wf-prepare-deployment, wf-fix-bugs, wf-verify-sync) để add `--from-impl` flag không?

### ✅ QUYẾT ĐỊNH: **Current scope** — CHỈ tạo schema v2.0 + consumer_hints, KHÔNG modify 3 skills khác

**Lý do chọn:**
- **Tuân thủ scope `00-master-plan.md §2 Ngoài scope`**: 3 skills khác là OUTSIDE scope của plan này
- **Single-skill focus**: v4.0 plan focus 100% vào wf-implement-feature. Modify 3 skills khác = scope creep, tăng risk regression cho 3 skills hiện đang stable.
- **Producer-first pattern**: Theo wf-scan-target v2.0 đã làm — Sprint 5 produce schema v2.0 + consumer_hints, các skill khác sẽ tự consume sau khi cần (có thể ở plan riêng cho từng consumer skill).
- **Output đủ dùng**: Consumer skills có thể tự đọc impl-status.json bất cứ lúc nào — không cần wait flag added.
- **Tracking followup**: Ghi vào memory `project_wf-implement-feature-v4-improvement-plan.md` final note: "Optional v5.0 followup: --from-impl integration trong wf-prepare-deployment / wf-fix-bugs / wf-verify-sync".

**Thực hiện ở:** Sprint 3 — produce schema only, không touch consumer skills.

---

## Q2 — E2E regression test environment

**Câu hỏi:** Sprint 5 E2E test dùng project EUREKA-2026 hay synthetic?

### ✅ QUYẾT ĐỊNH: **Synthetic** — Tạo test case trong `evals/synthetic-feat-stw-acct-002/`

**Lý do chọn:**
- **Reproducible**: Synthetic case stand-alone, không depend EUREKA-2026 access. Bất kỳ developer nào pull repo cũng chạy được.
- **Self-contained**: Setup/baseline/compare scripts trong cùng folder. Test = `bash setup.sh && claude /wf-implement-feature ... && bash compare.sh`.
- **CI-friendly**: Không cần access external project = có thể tích hợp vào CI sau này (nếu MCV3 muốn).
- **Reflect v3.4.0 baseline**: Snippets của FEAT-STW-ACCT-002 (registry entry, feature spec, task file) sao chép từ EUREKA-2026 thực tế làm baseline → test verify rằng v4.0 không regress với case real đã được fix v3.4.0.
- **Đồng bộ pattern**: wf-scan-target v2.0 evals dùng synthetic projects cho 8 cases.

**Loại bỏ:**
- ~~EUREKA-2026 dependency~~ — fragile, có thể break khi EUREKA-2026 thay đổi

**Thực hiện ở:** Sprint 5 step 5.12 (`evals/synthetic-feat-stw-acct-002/`)

---

## Tóm tắt quyết định (cho phiên sau resume nhanh)

| ID | Quyết định | Sprint thực hiện |
|----|-----------|-------------------|
| **D1** | A — Migration script idempotent (move flat → sessions/{date}-migrated/) | Sprint 1 |
| **D2** | A — `quick / standard / deep / exhaustive` | Sprint 2 |
| **D3** | C — TTL 24h + git SHA hash dual invalidation | Sprint 2 |
| **D4** | C — KHÔNG rename phase files trong v4.0 (defer v5.0) | Sprint 4 SKIP |
| **D5** | A — Sequential S1→S5, 3 PRs (S1+S2 / S3+S4 / S5) | Toàn plan |
| **Q1** | Current scope — CHỈ schema v2.0, KHÔNG modify 3 consumer skills | Sprint 3 |
| **Q2** | Synthetic — `evals/synthetic-feat-stw-acct-002/` self-contained | Sprint 5 |

---

## Constraints áp dụng cho mọi sprint (từ quyết định trên)

1. **Backward compat ưu tiên**: Migration script idempotent (D1), schema v2.0 với alias E001-E014 (Sprint 4), KHÔNG rename file names (D4=C).
2. **Cross-skill safety**: KHÔNG touch 3 consumer skills (Q1). KHÔNG break wf-design / wf-plan-modules / wf-verify-sync / wf-preflight contracts.
3. **Reproducibility**: Synthetic E2E test (Q2), không depend external project.
4. **CORE-023 priority**: Correctness > Speed > Token. Khi xung đột (e.g. cache TTL aggressive vs conservative) → bảo thủ với correctness (D3).
5. **BHV-002 Simplicity**: Không refactor cosmetic (D4=C). Surgical changes only.

---

## Followups tracked cho v5.0 (sau khi v4.0 stable)

1. **Phase rename** (D4=A): rename phase files thành phase01..phase10 cho thứ tự rõ ràng
2. **Consumer integration** (Q1 extend): add `--from-impl` flag vào:
   - `/wf-prepare-deployment` — auto-generate CHANGELOG từ consumer_hints
   - `/wf-fix-bugs` — focus scope từ consumer_hints.scope_modules
   - `/wf-verify-sync` — skip re-scan dùng consumer_hints.req_ids_completed
3. **CI integration**: Tích hợp eval-runner.sh vào GitHub Actions
4. **Cross-skill global registry**: Mở rộng `decision-registry.global.json` cho skills khác (wf-design phase architecture decisions, wf-plan-modules phase planning decisions)

Các followups này KHÔNG block v4.0 release — purely additive enhancements.

---

## Trạng thái plan sau khi lock decisions

✅ **READY TO START Sprint 1** — không còn blocker.

**Hành động kế tiếp:**
1. Tạo memory entry `project_wf-implement-feature-v4-improvement-plan.md`
2. Cập nhật `progress.md`: tick decisions = LOCKED + status Sprint 1 = READY
3. Bắt đầu Sprint 1 — Foundation (4h estimated)

Phiên làm việc tiếp theo có thể resume bằng cách đọc `README.md` → `progress.md` → `sprints/sprint-1-foundation.md`.
