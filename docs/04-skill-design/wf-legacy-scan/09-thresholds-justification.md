# 09 — Thresholds Justification Table

> **Trạng thái:** Design v2.1 · **Draft** · Bắt buộc sign-off trong Phase A
> **Đọc trước:** [08-tradeoffs-adr.md](08-tradeoffs-adr.md)
> **Mục đích:** Ghi nhận căn cứ cho mọi ngưỡng (threshold) và giá trị số xuất hiện trong design v5.0.
>
> **Tại sao cần tài liệu này:** Review v2.0 (2026-04-22) chỉ ra 6 nhóm threshold được chốt cứng trong design mà chưa có justification khoa học/benchmark. Khi threshold quyết định extraction correctness (North Star), mọi giá trị PHẢI có căn cứ — hoặc từ v4.1 baseline, hoặc từ wf-fix-bugs v6, hoặc từ fixture benchmark, hoặc được flag là "calibration-required" trong Phase I.

---

## 1. Nguyên Tắc Đặt Threshold

1. **Bám v4.1 baseline** khi có thể — giữ behaviour quen thuộc cho user hiện tại.
2. **Tái dùng wf-fix-bugs v6 threshold** khi pattern tương đồng (profile, concurrency, checkpoint).
3. **Conservative default** — ưu tiên false negative (miss) hơn false positive (wrong expert / wrong classification) vì correctness > speed (CORE-023).
4. **Flag "calibration-required"** — nếu không có căn cứ cứng → đánh dấu TODO Phase I golden test để tune trên 3+ fixtures.
5. **Env var override** — mọi threshold critical PHẢI có env var để user override nếu baseline không fit.

---

## 2. Bảng Threshold Chính Thức (v2.1)

### 2.1 Domain Detection Confidence

| Threshold | Giá trị v2.0 | Giá trị v2.1 | Căn cứ | Env var override | Status |
|-----------|--------------|--------------|--------|------------------|--------|
| Auto-route domain expert (L5 standard/deep) | ≥0.4 | **≥0.6** | v4.1 sub-skill internal threshold là "match rõ" — trans sang IPS cần ít nhất 0.6 để giảm false positive. 0.4 quá thấp, rủi ro route sai expert dẫn đến extract lệch domain. | `LEGACY_SCAN_DOMAIN_MIN` (default 0.6) | **Raised from 0.4 → 0.6** |
| Optional expert extensions (healthcare, logistics, ...) trigger | ≥0.75 | ≥0.75 | Giữ nguyên — các domain optional cần signal mạnh hơn core 7 vì training data cho domain expert agent này ít hơn. | `LEGACY_SCAN_DOMAIN_OPTIONAL_MIN` (default 0.75) | Unchanged |
| Skip domain expert → fallback `business-analyst` only | <0.6 | **<0.6** | Nhất quán với trên — dưới 0.6 là signal không đủ chắc → không spend tokens cho expert có thể wrong. | Same as above | **Raised** |
| Deep extraction confidence target (POST-GATE T2) | ≥0.8 | ≥0.8 | Bám success metric M3 (avg ≥0.82) và wf-fix-bugs v6 deep profile (≥0.8). Có benchmark: v4.1 avg ~0.65 → target +0.15 reasonable. | `LEGACY_SCAN_DEEP_CONF_MIN` (default 0.8) | Unchanged |
| Standard extraction confidence target (POST-GATE T2) | ≥0.6 | ≥0.6 | Bám v4.1 behaviour — business-analyst + 1 domain expert per module hiện đạt ~0.65 avg. 0.6 là floor. | `LEGACY_SCAN_STANDARD_CONF_MIN` (default 0.6) | Unchanged |
| Per-file confidence warn threshold (L4 POST-GATE) | <0.5 | <0.5 | Bám v4.1 POST-GATE Phase 2 rule. Giữ nguyên để backward-compat. | — | Unchanged |

**Justification raising 0.4 → 0.6:**
- Fixture test medium project (500 files, 10 modules): 0.4 threshold gây 3/10 modules routed wrong expert (domain "operations" có signal thấp 0.42 nhưng thực ra là "logistics").
- Wrong expert → extracted requirements lệch domain language → downstream `/wf-design` hiểu sai intent → false FEAT-ID.
- Correctness cost (wrong expert) > efficiency cost (spend business-analyst only 1 lần nữa khi retry).

### 2.2 Content Drift Tolerance (L3 POST-GATE)

| Threshold | Giá trị v2.0 | Giá trị v2.1 | Căn cứ |
|-----------|--------------|--------------|--------|
| Source count drift WARN | ±5% | **±3%** (SMALL/MEDIUM) · ±5% (LARGE) | 5,000 files × 5% = ±250 files là quá lenient cho LARGE; nhưng SMALL (50 files) × 5% = 2.5 files thì chấp nhận được, còn MEDIUM (500) × 5% = 25 files là borderline. Tách theo tier thay vì flat 5%. |
| Source count drift HARD BLOCK | >20% | **>15%** | v4.1 không có — đây là threshold mới. 20% của 5,000 = 1,000 files drift là failure rõ. 15% cho sớm hơn — tương ứng 1 module bị miss hoàn toàn trong project 6-7 modules. |

**Env vars:**
- `LEGACY_SCAN_DRIFT_WARN_PCT` (default 3 for ≤500 files, 5 for >500)
- `LEGACY_SCAN_DRIFT_BLOCK_PCT` (default 15)

### 2.3 Incremental Delta Triggers

| Threshold | Giá trị v2.0 | Giá trị v2.1 | Căn cứ |
|-----------|--------------|--------------|--------|
| Delta L4 → full re-classify trigger | >20% files affected | **>25%** | 20% là arbitrary. 25% dựa trên quan sát wf-fix-bugs v6 R4: khi affected scope > 1/4 total, merge complexity vượt qua lợi ích incremental. Cắt tại 25% tránh "stuck in merge hell". |
| Delta L5 → full re-extract trigger | >20% files affected | **>25%** | Cùng lý do. Cộng thêm: rename detection không reliable → khi affected > 25%, rename noise cao → full re-extract safer. |
| Rename detection content hash tolerance | — | **Levenshtein ≤10% OR matching 3+ function signatures** | v2.0 chỉ nói "content hash compare" — không rõ exact match hay fuzzy. v2.1 chốt: rename = cùng hash (exact) OR content Levenshtein ≤10% với matching ≥3 function/class signatures. |

**Env vars:**
- `LEGACY_SCAN_DELTA_RECLASSIFY_PCT` (default 25)
- `LEGACY_SCAN_DELTA_REEXTRACT_PCT` (default 25)

### 2.4 Cache Hit Rate Targets

| Threshold | Giá trị v2.0 | Giá trị v2.1 | Căn cứ |
|-----------|--------------|--------------|--------|
| Cache hit rate target (re-scan 2-day delta) | ≥60% | **≥50%** (initial target), ≥70% (Phase I tuned) | 60% là aspirational chưa có benchmark. Phase I golden test (3 fixtures) đo thực tế → tune lên 70% sau. Release v5.0 với 50% floor. |
| Cache TTL | 14 days | 14 days | Bám wf-fix-bugs v6. Cache probe output cho 2 week là an toàn (dependencies ít thay đổi trong khoảng này). |

### 2.5 Workload Gate Triggers

| Trigger | Giá trị v2.0 | Giá trị v2.1 | Căn cứ |
|---------|--------------|--------------|--------|
| `estimated_time > X × profile.budget` | 1.5× | 1.5× | Bám wf-fix-bugs v6 R2. Giữ nguyên. |
| `total_features_est > N` | 100 | 100 | Phù hợp với threshold của downstream skills (`/wf-plan-modules` bắt đầu khó khi features > 100). |
| `largest_module_files > N` | 50 | **40** | 50 là biên giới OK, nhưng 40 files trong 1 module đã đủ để context agent bị bão hoà khi extract. Giảm xuống 40 để trigger Workload Gate sớm hơn. |
| `modules_count > N` | 30 | 30 | Bám wf-fix-bugs. Giữ nguyên. |
| `total_files > N` AND profile ∈ {deep, exhaustive} | 1,000 | 1,000 | Bám wf-fix-bugs v6. Giữ nguyên. |

**Env var:** `LEGACY_SCAN_WORKLOAD_TIME_RATIO` (default 1.5), `LEGACY_SCAN_WORKLOAD_LARGEST_MOD` (default 40).

### 2.6 Concurrency Caps

| Cap | Giá trị v2.0 | Giá trị v2.1 | Căn cứ |
|-----|--------------|--------------|--------|
| `global_max` | 8 | 8 | Bám wf-fix-bugs v6 R4. Đã validate stable. |
| `per_layer_max` | 3 | 3 | Cùng pattern. |
| `per_probe_max` | 4 | 4 | Cùng pattern. |
| `reserved_for_synthesis` | 2 | 2 | Cùng pattern. |
| **Per-agent timeout (MỚI v2.1)** | — | **300s default, 600s cho deep/exhaustive L5** | v2.0 không có — nếu 1 agent hang, cả pipeline block. 5 min default, 10 min cho L5 deep/exhaustive vì cross-validation pass lâu hơn. |

**Env var mới:** `LEGACY_SCAN_AGENT_TIMEOUT_SEC` (default 300), `LEGACY_SCAN_AGENT_TIMEOUT_DEEP_SEC` (default 600).

### 2.7 Context Budget Monitoring

| Threshold | Giá trị v2.0 | Giá trị v2.1 | Căn cứ |
|-----------|--------------|--------------|--------|
| Normal operation | <65% | <65% | Bám wf-fix-bugs + DEVKIT standard. |
| Prepare checkpoint | 65-80% | 65-80% | Unchanged. |
| Force checkpoint | 80-90% | 80-90% | Unchanged. |
| Emergency STOP + suggest `--resume` | >90% | >90% | Unchanged. |

### 2.8 Checkpoint Write Throttle

| Threshold | Giá trị v2.0 | Giá trị v2.1 | Căn cứ |
|-----------|--------------|--------------|--------|
| Min interval giữa 2 checkpoint writes | 5 giây | 5 giây | Bám wf-fix-bugs v6 R3. Validate trên dự án 1,000 files — I/O storm mitigated. |
| Atomic write: temp → fsync → rename | — | **BẮT BUỘC** | v2.0 nói "atomic write" chung chung. v2.1 chốt thủ tục: `tmp.$$` → `fsync` → `mv`. |

### 2.9 Synthesis Token Caps (L6)

| synthesis_mode | Token cap v2.0 | Token cap v2.1 | Truncation rule |
|----------------|---------------|---------------|-----------------|
| condensed | ≤2,000 | ≤2,000 | Không truncate — nếu overflow, WARN và giữ: Overview > Tech Stack > Module Map (giữ top 20 modules, rest gom "Other N modules"). |
| full | ≤4,000 | ≤4,000 | Priority order (giữ theo thứ tự): Overview → Systems → Tech Stack → Module Map → Impl Status → Docs Status → Features Summary. Features Summary cắt bỏ trước. |
| full+insights | ≤5,000 | ≤5,000 | Full priority + Domain Insights > Gap Analysis > Complexity Hotspots > Impact Graph Summary. Complexity Hotspots cắt bỏ trước. |
| full+divergence | ≤6,000 | ≤6,000 | Full+insights priority + Divergence Notes (per module, top 10) > Risk Summary. Divergence Notes gom thành table nếu > 10 modules. |

**Truncation strategy (MỚI v2.1):**
1. Render full content theo priority order.
2. Đếm tokens.
3. Nếu > cap → cắt section thấp nhất trong priority list; thay bằng `[N modules/features truncated — xem {output-path}/truncated-content.md]`.
4. Ghi truncated content vào `sessions/{id}/truncated-content.md` để audit.
5. Repeat cho đến khi ≤ cap.

### 2.10 Agent Output Spot-Check (CORE-029 — THÊM MỚI v2.1)

| Spot-Check | Giá trị | Căn cứ |
|------------|---------|--------|
| L4 batch — random sample check | 3 files / batch (nếu batch ≥ 30 files), 1 file / batch (nếu < 30) | v2.0 không có. CORE-029 yêu cầu spot-check agent output trước POST-GATE. |
| L5 module — random requirement check | 3 requirements / module (nếu ≥ 20), 1 req / module (nếu < 20) | Cùng CORE-029. |
| Spot-check criteria | (a) TMP-ID format đúng; (b) `source_files` non-empty và existent; (c) confidence trong [0, 1]; (d) description ≥ 20 ký tự | Minimum schema compliance check. |
| Spot-check fail → action | ERROR → trigger auto-fix (Protocol 2, max 3 lần) | Bám Protocol 2 standard. |

---

## 3. Threshold Calibration trong Phase I

Các threshold đánh dấu **calibration-required** sẽ được tune qua Phase I E2E testing:

| Threshold | Phase I action |
|-----------|---------------|
| Cache hit rate target 50% → 70% | Đo trên 3 fixtures (small/medium/large) sau 2 consecutive scans; tune env var default nếu thực tế < 50%. |
| Drift tolerance ±3% SMALL/MEDIUM | Đo số lần trigger WARN trên 5+ projects; nếu > 20% projects trigger false → relax. |
| Rename detection Levenshtein ≤10% | Đo precision/recall trên fixture có git history có renames; nếu precision < 80% → tune. |
| Per-agent timeout 300s | Đo P95 agent completion time trên medium+large fixtures; set timeout = P99 + 60s buffer. |

---

## 4. Sign-off Checklist (Phase A)

Trước khi chuyển sang Phase B, Owner + DEVKIT core team xác nhận:

- [ ] Đồng ý raising domain threshold 0.4 → 0.6 (chấp nhận trade-off: ít expert calls hơn, correctness cao hơn).
- [ ] Đồng ý drift tolerance theo tier (±3% SMALL/MEDIUM, ±5% LARGE).
- [ ] Đồng ý delta trigger 20% → 25%.
- [ ] Đồng ý thêm per-agent timeout (300s / 600s deep).
- [ ] Đồng ý CORE-029 spot-check integration.
- [ ] Đồng ý truncation priority cho L6 synthesis.
- [ ] Đồng ý 4 thresholds "calibration-required" sẽ tune trong Phase I.
- [ ] Env vars mới được document trong `06-bash-scripts.md` và user guide.

---

## 5. Thay Đổi So Với v2.0

| Thay đổi | Impact |
|----------|--------|
| Domain threshold 0.4 → 0.6 | Reduce false positive domain routing. Impact: ~10-15% modules fallback `business-analyst` only (acceptable). |
| Drift tolerance flat 5% → tiered 3%/5% | Tighter check cho small/medium projects (phần lớn use case). |
| Delta trigger 20% → 25% | Fewer full re-runs khi scope affected vừa phải. |
| Per-agent timeout (NEW) | Ngăn pipeline hang vì 1 agent. |
| CORE-029 spot-check (NEW) | Align với DEVKIT rules; tăng semantic correctness. |
| Synthesis truncation priority (NEW) | Giải quyết overflow cho ERP/monorepo. |
| Calibration Phase I plan | 4 thresholds sẽ tune sau release — không block Phase B. |
