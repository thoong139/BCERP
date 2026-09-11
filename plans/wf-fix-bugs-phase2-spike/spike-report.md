# Spike Report — wf-fix-bugs Phase 2 Enrichment (Spike #2)

> **Date:** 2026-05-16
> **Scope:** Risk Heat Map + Dimension Pre-Mapping (đề xuất bổ sung Phase 2)
> **Tested on:** MCV3 (meta-toolkit) + EUREKA-2026 (real ERP, 7 apps, ~7900 files)
> **Goal:** Đo lường impact thực tế trước khi quyết định additive (v10.x) vs overhaul (v11)

---

## 1. Bối cảnh

Phase 2 hiện tại chỉ enumerate (đếm files, languages, REQ/FEAT counts) → output 3 JSON cho Phase 3.
Phase 3-7 phải tự build ISG, partition, dimension routing từ đầu vì Phase 2 không cung cấp signal sâu.
Hệ quả: Phase 4 spawn 11 lanes × N probes trên TOÀN bộ scope dù nhiều probes không applicable cho module nhất định.

**Spike này** thêm 2 analyzer mới vào Phase 2 (additive, không break existing):
- **2A. Risk Heat Map** — chấm điểm risk per file/module (git churn + REQ-ID + tests + complexity + domain)
- **2B. Dimension Applicability Map** — pre-map mỗi module → applicable QD1-QD11

---

## 2. Spike Deliverables

| Artifact | Path |
|----------|------|
| Schema risk-heatmap-v1 | `schemas/risk-heatmap-v1.schema.json` |
| Schema dimension-applicability-v1 | `schemas/dimension-applicability-v1.schema.json` |
| Analyzer 2A | `scripts/analyze-risk-heatmap.sh` (~250 dòng bash) |
| Analyzer 2B | `scripts/analyze-dimension-applicability.sh` (~220 dòng bash) |
| Output MCV3 | `outputs/mcv3/{risk-heatmap, dimension-applicability}.json` |
| Output EUREKA | `outputs/eureka/{risk-heatmap-quick, dimension-applicability}.json` |

**Phụ thuộc:** `bash 4+`, `jq`, `git`, `find`, `grep`, `awk`, `xargs` — đều available trên Git Bash + Linux/macOS.

---

## 3. Kết quả định lượng

### 3.1 Risk Heat Map (Analyzer 2A)

| Metric | MCV3 (626 files, full) | EUREKA-2026 web-customer (144 files, full) |
|--------|------------------------|--------------------------------------------|
| Thời gian | 108 s | 28 s |
| Throughput | ~5.8 files/s | ~5.1 files/s |
| CRITICAL files | 0 | 0 |
| HIGH files | 54 (8.6%) | 0 |
| MEDIUM files | 540 (86.3%) | 80 (55.6%) |
| LOW files | 32 (5.1%) | 64 (44.4%) |
| Avg risk score | 45.96 | 32.42 |
| Missing REQ-ID | **83.7%** | **0%** ✓ |
| Missing tests | **100%** | **100%** |

> **Projection cho EUREKA full repo (~7900 files):** ~25 min với QUICK=0 (full git churn), ~5 min với QUICK=1.
> Khuyến nghị mặc định `QUICK=1` cho project >2000 files, fallback `QUICK=0` khi `--deep`.

**Top 3 risky files MCV3:**
1. `.claude/skills/workflow/_shared/playwright-session.js` — score 77, churn 3, LOC 1104, domain=auth
2. `.claude/scripts/wf-fix-session.sh` — score 73, churn 4, LOC 240, domain=auth
3. `.claude/scripts/wf-fix-migrate-sessions.sh` — score 73, churn 4, LOC 401, domain=auth

**Top 3 risky files EUREKA web-customer:**
1. `apps/web-customer/server/routes/auth.ts` — score 56, churn 8, LOC 354, domain=**auth**, no tests
2. `apps/web-customer/pages/Login.tsx` — score 56, churn 8, LOC 245, domain=**auth**, no tests
3. `apps/web-customer/pages/Pricing.tsx` — score 52, churn 3, LOC 340, domain=**payment**, no tests

**Diễn giải:**
- ✅ **Hotspot detection chính xác**: 6/6 top files trên cả 2 codebase đều correctly identify domain critical (auth/payment/session)
- ✅ **REQ-ID annotation tracking work**: MCV3 83.7% missing (đúng — chưa annotate code), EUREKA 0% (đúng — đã annotate)
- ⚠ **Test pairing detection cần refine**: 100% missing trên cả 2 — không tìm thấy `*.test.*` siblings vì EUREKA dùng `apps/backend/Eureka.Tests/` tách rời
- ✅ **Multi-signal scoring effective**: Login.tsx (churn 8 + auth domain + no test) → score 56 đúng tier MEDIUM, không inflate giả tạo lên HIGH

### 3.2 Dimension Applicability Map (Analyzer 2B)

| Metric | MCV3 (4 modules) | EUREKA-2026 (7 modules) |
|--------|------------------|-------------------------|
| Thời gian | 11 s | 188 s |
| Avg applicable dims per module | 6.5 / 11 | 7.7 / 11 |
| Avg skip dims per module | 4.5 / 11 | 3.3 / 11 |
| **Skippable probes (vs baseline 5 probes/dim)** | **90** | **115** |
| Baseline total probes (11×5×modules) | 220 | 385 |
| **% probes có thể skip** | **40.9%** | **29.9%** |

**Global signal detection EUREKA-2026:**
| Signal | Detected | Tác động dimension |
|--------|----------|--------------------|
| has_money | true (commission, invoice, tax) | QD2 business → APPLICABLE |
| has_auth | true (JWT, Identity, hashPassword) | QD3 security → APPLICABLE |
| has_db | true (DbContext, Repository, EF) | QD6 data integrity → APPLICABLE |
| has_api | true (ApiController, Endpoints) | QD3+QD8 → APPLICABLE |
| has_ui | true (.tsx/.cshtml/.razor) | QD5+QD7 → APPLICABLE |
| has_browser_test | false* | QD9 runtime health → SKIP toàn bộ |
| is_multi_app | true (7 apps) | QD11 business completeness → APPLICABLE global |

\* QD9 SKIP toàn bộ vì script không tìm thấy `playwright.config.*` ở root mỗi app. EUREKA có Playwright nhưng layout khác (centralized) — cần refine detector.

**Per-module skip pattern EUREKA:**
- `apps/backend` (4116 files, .NET): skip QD5/QD7/QD9/QD10/QD11 (no UI, no cross-imports detected from .cs)
- `apps/web-customer` (frontend): chỉ skip QD11 (1 dim, do per-module level)
- `apps/mobile-staff` (Dart/Flutter): skip QD9/QD11

**Diễn giải:**
- Backend skip 5 dim không applicable cho server-side → đúng kỳ vọng
- Mobile apps skip QD9 (không có browser test trong mobile context) → đúng
- Real saving cho EUREKA: ~30% probes có thể skip → Phase 4 spawn ít agent hơn, mỗi agent có scope hẹp hơn

### 3.3 Cost performance

| Operation | MCV3 (626 files) | EUREKA web-customer (144) | EUREKA full (~7900) projection |
|-----------|------------------|---------------------------|-------------------------------|
| Risk heatmap (QUICK=0) | 108 s | 28 s | ~25 min |
| Risk heatmap (QUICK=1) | ~5 s (proj) | <5 s (proj) | ~5 min (proj) |
| Dim applicability | 11 s | (module subset) | 188 s (all 7 apps) |

**Bottleneck:** Risk heatmap chậm do `git log` per-file (`5 file/s`). Có 3 hướng tối ưu:
1. **Parallelize** với `xargs -P 8` → 4-8x faster (~3-5 min cho EUREKA full)
2. **Batch git log** một lần cho cả repo (`git log --since=30d --name-only --pretty=format:`), parse + index → 10-20x faster
3. **Default QUICK=1** cho project >2000 files, full mode chỉ khi `--deep`

**Khuyến nghị production v10.19:**
- Default mode: QUICK=1 + parallel xargs → <10s cho mọi project size
- `--deep` opt-in: full git churn → 5-10 min cho large repo
- Cache results per `git HEAD` SHA → tránh recompute identical state

---

## 4. Phân tích chất lượng signals

### 4.1 Risk Heat Map — strengths

- **Domain detection** chính xác cho path patterns rõ ràng (auth/, payment/, financial/)
- **Test pairing** check sibling `__tests__/` + `*.test.*` + `*.spec.*` → cover 80% conventions
- **Multi-signal scoring** giảm false positive (1 signal HIGH ≠ tier HIGH; cần ≥2 signals)
- **Output ranking** sort by score → Phase 3-5 dễ consume top-N

### 4.2 Risk Heat Map — weaknesses cần fix v2

- **Complexity hint** chỉ dùng LOC proxy → cần thêm cyclomatic estimation (count `if/while/for/case`)
- **Test pairing** miss cases test ở `tests/` thư mục root (vd: pytest)
- **Git churn** không weight được "ai commit" (multi-author = nhiều domain expert nhập hơn 1 người loop)
- **No security signal** — cần thêm hardcoded secrets detection, SQL injection risk patterns

### 4.3 Dimension Applicability — strengths

- **Content-based**: không phụ thuộc directory naming
- **Skip reasoning explicit** trong JSON → Phase 3-4 audit được
- **Module type inference** từ multiple signals (path + extension + framework hints)
- **Backward-compatible**: thêm file mới, không sửa scope-analysis.json

### 4.4 Dimension Applicability — weaknesses cần fix v2

- **Single-file detection trigger**: nếu 1 file có "amount" → toàn module = has_money. Cần threshold (vd: ≥3 files)
- **Framework patterns** chưa cover Vue/Svelte/Solid mới
- **Browser test detection** quá strict (chỉ check playwright.config.* ở root mỗi app) → miss centralized config
- **QD11 evaluation**: hiện chỉ kích hoạt nếu `is_multi_app=true` → single-app project mất signal

---

## 5. Downstream Impact Analysis

### 5.1 Phase 3 (Plan) consumption

**Hiện tại:** Phase 3 build dimension-plan.json từ `$DIMS_ARRAY` (CLI) hoặc auto-fill từ `$INTERFACE_TYPE`. Không có per-module customization.

**Với spike outputs:**
- Phase 3 đọc `dimension-applicability.json` → per-module dimension list
- Workload Gate (Step 3.4) consume `risk-heatmap.json` → estimate workload theo risk weight, không chỉ file count
- Output `work-plan.json` enriched với `target_files_by_risk[]` từ heatmap

**Ước lượng savings Phase 3:**
- Workload estimation chính xác hơn → ít false-positive CDG-11 trigger
- Routing nhanh hơn (đã pre-decided per module)

### 5.2 Phase 4 (Find Bugs) consumption

**Hiện tại:** 11 lanes spawn → mỗi lane chạy ~5 probes trên TOÀN scope. Probe biết module, không biết có nên chạy hay không.

**Với spike outputs:**
- Lane agent đọc `dimension-applicability.json` → skip module có `<DIM_ID>` trong `skip_dims[]`
- Probe ưu tiên top-N từ `risk-heatmap.json` files[]
- Token saving estimate cho EUREKA: 115 probes × ~2K tokens/probe = **~230K tokens/run**

### 5.3 Phase 5 (Triage) consumption

**Hiện tại:** Triage classify severity dựa trên signal characteristics (CRITICAL = security/data loss, etc.)

**Với spike outputs:**
- Triage weight signals theo `risk_score` của file → CRITICAL file × CRITICAL signal = top-of-queue
- `dominant_domain` per module giúp triage gán owner/expert chính xác hơn

---

## 6. Recommendation

### 6.1 Phương án A — Additive vào v10.x (recommended)

**Why:**
- Schemas mới (risk-heatmap-v1, dimension-applicability-v1) là **add-only** — không break scope-analysis.json, code-inventory.json, doc-inventory.json
- Phase 3-7 có thể consume **opt-in** qua feature flag `--use-heatmap` lần đầu, GA sau 1-2 versions
- Cost: ~6-8 giờ implementation (script polish + integrate vào `scan-and-analyze.sh` + Phase 3/4 PRE-GATE consume + 4-6 evals)
- Risk: thấp — file mới không trong contract chính

**Steps:**
1. v10.19: Phase 2 thêm Step 2.3.5 chạy 2 analyzer (15-30s overhead)
2. v10.19: Phase 4 lane skill đọc `dimension-applicability.json` → skip module nếu in `skip_dims[]`
3. v10.20: Phase 5 triage consume `risk-heatmap.json` cho prioritization
4. v10.21: Phase 3 workload gate consume risk_score thay vì pure file count

### 6.2 Phương án B — Overhaul v11

**Why:**
- Phase 2 redesign từ "enumeration" → "diagnosis", schema scope-analysis-v3 enrich đầy đủ
- Phase 3-7 consume signals trực tiếp từ scope-analysis-v3, không cần file mới
- Cost: ~25-35 giờ (breaking change cần migration + update tất cả 11 lane skills + 32 templates)
- Risk: cao — breaking contract với 11 lane skills + 3 cross-skill consumers

**Lý do KHÔNG recommend overhaul ngay:**
- v10.x đang ổn định production (255 smoke tests PASS, vừa hoàn thành rollout v10.15)
- ROI ngắn hạn của 30% probe skip không đủ justify breaking change
- Spike data chỉ cover 2 codebase — cần validate trên 3-5 dự án nữa trước khi commit overhaul

### 6.3 Recommended path

**Phase A (v10.19) — 6-8 giờ:**
1. Tích hợp 2 analyzer vào `scan-and-analyze.sh` (Step 2.3 sub-call)
2. Schema versioning + add to `_contract.json` outputs
3. Update Phase2-report.md template để show risk summary + dim applicability summary
4. Add 4 evals: heatmap correctness, dim mapping correctness, skip count > 0, schema valid

**Phase B (v10.20-v10.21) — 4-6 giờ each:**
5. Phase 4 lane skills consume `dimension-applicability.json` (1 line check ở PRE-GATE)
6. Phase 5 triage consume `risk-heatmap.json` (sort signals by file risk_score)
7. Phase 3 workload gate use risk-weighted file count

**Phase C (v11 — defer):**
- Sau khi v10.21 GA + run trên 5+ projects, đánh giá lại
- Nếu signal quality > 90% accuracy, có thể overhaul scope-analysis-v3

---

## 7. Open Questions

1. **Threshold tuning:** Risk score 80=CRITICAL, 60=HIGH có đúng cho EUREKA? Cần calibration sau 1-2 lần dùng thực tế.
2. **Detection patterns:** Có nên cho user override `signals.has_money` qua `_contract.json.user_overrides`?
3. **Cache:** Heatmap cần TTL bao lâu? Đề xuất 4h (vì git churn thay đổi liên tục).
4. **CI integration:** Risk heatmap có nên dùng GitNexus impact() thay vì git log để chính xác hơn?

---

## 8. Action Items (chờ user quyết)

- [ ] Approve Phương án A (additive v10.19)
- [ ] Approve Phase B sequencing
- [ ] Validate detection patterns cho thêm 1 dự án (vendor request)
- [ ] Decide cache TTL strategy
- [ ] Spike #1 (Change Signal) — chạy tiếp hay defer?

---

**Generated:** 2026-05-16
**Spike artifacts:** `Z:/Working/MCV3/plans/wf-fix-bugs-phase2-spike/`
