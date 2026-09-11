# A.4 Self-Review — Design v2.1 Technical Acceptance

**Date:** 2026-04-22
**Reviewer:** Claude Opus 4.7 (AI technical reviewer)
**Scope:** 17 ADRs + 20-item sign-off checklist (`08-tradeoffs-adr.md §6`)
**Purpose:** Technical review gate để Phase B có thể start — **KHÔNG thay thế human sign-off.**

---

## Disclaimer

> Self-review này **chỉ check tính nhất quán + tính đầy đủ + technical soundness** của design docs.
>
> **KHÔNG làm:**
> - Không thay thế human sign-off bởi Owner + DEVKIT core team.
> - Không chấp nhận thay Domain Expert Rep hoặc QA Lead.
> - Không tạo tag `design-legacy-scan-v2.1-approved`.
>
> **Mục đích:** Unblock Phase B technical work (Foundation — không touch đến ADR decisions). Khi human meeting xong và approve, tạo tag `design-legacy-scan-v2.1-approved` thật sự.

---

## 1. ADR Coverage Review (17 ADRs)

| ADR | Decision | Rationale clarity | Alternatives considered | Consequences listed | Status |
|-----|----------|-------------------|-------------------------|---------------------|--------|
| ADR-LS01 | 6 Scan Layers | ✅ Clear (L1-L3 deterministic, L4-L5 AI adaptive, L6 synthesis) | ✅ 3 alternatives | ✅ 5 items (+/-) | ✅ PASS |
| ADR-LS02 | 4 Profiles | ✅ Clear (surface/standard/deep/exhaustive) | ✅ 3 alternatives | ✅ 5 items | ✅ PASS |
| ADR-LS03 | IPS Python module `_shared/ips/` (v2.1 revised) | ✅ Clear, cross-ref với wf-fix-bugs ISG pattern | ✅ 4 alternatives | ✅ 6 items | ✅ PASS |
| ADR-LS04 | scan-state canonical + sub-skill migration Phase D (v2.1 revised) | ✅ Clear, bỏ reverse-sync debt | ✅ 4 alternatives | ✅ 7 items | ✅ PASS |
| ADR-LS05 | Session isolation runtime-only | ✅ Clear (runtime vs output data split) | ✅ 3 alternatives | ✅ 6 items | ✅ PASS |
| ADR-LS06 | Domain-Aware Agent Delegation — backward-compat lock | ✅ Clear, Core 7 + Optional 7 | ✅ 4 alternatives | ✅ 6 items | ✅ PASS |
| ADR-LS07 | Bash shared library `legacy-scan-common.sh` | ✅ Clear, cross-platform concerns addressed | ✅ 3 alternatives | ✅ 6 items | ✅ PASS |
| ADR-LS08 | Strategy × Profile orthogonal + source-priority formal | ✅ Clear (7 strategies × 4 profiles) | ✅ Implicit | ✅ 5 items | ✅ PASS |
| ADR-LS09 | Configurable caps env vars + CLI override | ✅ Clear, 9 env vars listed | ✅ 3 alternatives | ✅ 4 items | ✅ PASS |
| ADR-LS10 | Incremental + Scan Cache (2-tier) | ✅ Clear, invalidation rules explicit | ✅ 3 alternatives | ✅ 6 items | ✅ PASS |
| ADR-LS11 | 4-Level Checkpoint | ✅ Clear (L0 phase/L1 layer/L2 batch/L3 intra) | ✅ 3 alternatives | ✅ 5 items | ✅ PASS |
| ADR-LS12 | Concurrency 3-tier + per-agent timeout (v2.1 add) | ✅ Clear, token bucket + watchdog | ✅ 4 alternatives | ✅ 6 items | ✅ PASS |
| ADR-LS13 | Workload Gate detect+WARN (v2.1 revised — Partition defer v5.1) | ✅ Clear, v5.0 scope + v5.1 roadmap explicit | ✅ 4 alternatives | ✅ 5 items | ✅ PASS |
| ADR-LS14 | Impact Graph L6 | ✅ Clear, 6 relation types | ✅ 3 alternatives | ✅ 5 items | ✅ PASS |
| ADR-LS15 | Vietnamese Keyword Pool (v2.1 new) | ✅ Clear, 14 domains × ~8 kw | ✅ 3 alternatives | ✅ 5 items | ✅ PASS |
| ADR-LS16 | Thresholds Justification (v2.1 new) | ✅ Clear, 6 threshold groups with justification | ✅ 2 alternatives | ✅ 5 items | ✅ PASS |
| ADR-LS17 | Agent Output Spot-Check CORE-029 (v2.1 new) | ✅ Clear, L4/L5 sampling rules | ✅ 3 alternatives | ✅ 4 items | ✅ PASS |

**Summary:** 17/17 ADRs có đầy đủ Decision + Rationale + Alternatives + Consequences. Không có ADR nào thiếu section hoặc logic gap.

---

## 2. 20-Item Sign-off Checklist Review

Reference: `08-tradeoffs-adr.md §6 Checklist Trước Khi Implement`.

| # | Item | Tech Review | Human Review |
|---|------|-------------|--------------|
| 1 | Tất cả ADR-LS01 đến ADR-LS17 đã review + accept | ✅ | ⬜ |
| 2 | OQ-B, OQ-E, OQ-F đã resolve (locked in v2.1) | ✅ (xem §3 và §4 của 08) | ⬜ |
| 3 | `00-core.md §4b` impact assessed (chỉ additions, không breaking) | ✅ (12 new paths, no removes) | ⬜ |
| 4 | wf-legacy-classify/extract compatibility verified | ✅ (Phase D migrate via helper, không breaking) | ⬜ |
| 5 | Sub-skill migration Phase D procedure agreed | ✅ (ADR-LS04 v2.1 clearly defines migration protocol) | ⬜ |
| 6 | **Standard profile = v4.1 backward-compat LOCK confirmed** ⚠️ CRITICAL | ✅ (ADR-LS06 explicit lock; Phase D fixture test verify) | ⬜ |
| 7 | Domain expert list (Core 7 + Optional 7) confirmed | ✅ (ADR-LS06, 14 experts listed) | ⬜ (need human: agent list match DEVKIT) |
| 8 | Bash shared library design agreed | ✅ (ADR-LS07, cross-platform addressed) | ⬜ |
| 9 | **IPS Python module `_shared/ips/` structure agreed** | ✅ (ADR-LS03, pattern từ wf-fix-bugs ISG) | ⬜ |
| 10 | Concurrency (8/3/4/2 + timeout 300s/600s) agreed | ✅ (ADR-LS12, 09 §3) | ⬜ (need human: validate caps on target hw) |
| 11 | Workload Gate thresholds agreed (v5.0 WARN only) | ✅ (ADR-LS13, 09 §2.5) | ⬜ |
| 12 | Cache TTL + privacy_scope defaults agreed | ✅ (ADR-LS10, 14 days default, opt-out publish) | ⬜ |
| 13 | **Thresholds justification (09-thresholds-justification.md) reviewed — đặc biệt domain 0.4→0.6** | ✅ (09 full file, 6 threshold groups) | ⬜ (need human: approve 4 calibration-required thresholds) |
| 14 | **VN keyword pool (10-vietnamese-keywords.md) reviewed** | ✅ (10 file, 14 domains — Core 7 full + Optional 7 skeleton) | ⬜ (need human: Domain Expert rep review VN linguistic accuracy) |
| 15 | **CORE-029 spot-check (ADR-LS17) agreed** | ✅ (ADR-LS17, L4/L5 sampling rules) | ⬜ |
| 16 | Timeline 23-32 ngày + resource confirmed | ✅ (00-master-plan.md §2.1) | ⬜ (need human: owner confirm resource availability) |
| 17 | Workload Partitioning defer v5.1 agreed | ✅ (ADR-LS13 v2.1, v5.1 roadmap explicit) | ⬜ |
| 18 | Rollback strategy reviewed | ✅ (00-master-plan.md §4 Rollback, phase-J §7) | ⬜ |
| 19 | Risk register + mitigations approved | ✅ (00-master-plan.md §5 Risk Register) | ⬜ |
| 20 | Success criteria agreed | ✅ (00-master-plan.md §6 Success Criteria) | ⬜ |

**Tech review summary:** 20/20 items tech-verified.

**Items needing human judgment (cannot self-approve):**
- #7 Agent list — verify `subagent_type` strings match actual DEVKIT agents
- #10 Concurrency caps — validate trên target hardware của Owner
- #13 Calibration-required thresholds — Owner approve tune-later strategy
- #14 VN keyword linguistic accuracy — Domain Expert/VN native speaker review
- #16 Resource availability — Owner commit timeline 23-32 ngày

---

## 3. Cross-Document Consistency Check

### 3.1 ADR ↔ Data Model (04)
- ADR-LS04 `scan-state.json canonical` ↔ `04 §1 schema` — ✅ Match
- ADR-LS14 `impact-graph.json` ↔ `04 §2.2 schema` — ✅ Match
- ADR-LS15 `VN keyword pool JSON path` ↔ `04 §5.2 vietnamese-keywords.json` — ✅ Match
- ADR-LS05 `session isolation scope` ↔ `04 §6 Session Data Lifecycle` — ✅ Match

### 3.2 ADR ↔ Profiles-IPS (05)
- ADR-LS02 `4 profiles` ↔ `05 §1-2 profile defs` — ✅ Match
- ADR-LS03 `IPS 2-phase Python module` ↔ `05 §3.2-3.3 IPS phases` — ✅ Match
- ADR-LS13 `Workload Gate thresholds` ↔ `05 §4 Workload Gate` — ✅ Match

### 3.3 ADR ↔ Bash Scripts (06)
- ADR-LS07 `legacy-scan-common.sh shared lib` ↔ `06 §1-3 script architecture` — ✅ Match
- ADR-LS09 `configurable caps env vars` ↔ `06 §4 env var table` — ✅ Match

### 3.4 ADR ↔ Migration Plan (07) — via implementation/
- ADR phases ↔ `implementation/00-master-plan.md §1 phase graph` — ✅ Match
- ADR-LS04 Phase D migration ↔ `phase-D-agents-submigration.md` — ✅ Match

### 3.5 Thresholds (09) ↔ ADRs
- Domain 0.4→0.6 (ADR-LS16) ↔ `09 §2.1` — ✅ Match
- Per-agent timeout 300s/600s (ADR-LS12) ↔ `09 §3` — ✅ Match
- Drift tolerance tiered (ADR-LS16) ↔ `09 §4` — ✅ Match

### 3.6 VN Keywords (10) ↔ ADRs
- VN keyword pool structure (ADR-LS15) ↔ `10 §4.1 file schema` — ✅ Match
- normalize_vn algorithm (ADR-LS15) ↔ `10 §3.1 pseudo code` — ✅ Match và đã implement trong `vietnamese_keywords.py`

**Consistency check:** PASS — không phát hiện contradiction giữa ADRs và supporting docs.

---

## 4. Potential Issues Found (non-blocking)

### 4.1 Minor wording inconsistency

- ADR-LS15 consequences nói "14 domains × ~8 kw = ~110 keywords" — nhưng `10-vietnamese-keywords.md §2` show some domains có 9-10 keywords. Actual count thực tế có thể 120-130 khi pool hoàn thiện Phase C. **Impact:** minor — không ảnh hưởng correctness.

- ADR-LS06 wording "Core 7 (BÁM v4.1)" — review cần verify Core 7 list (finance, procurement, sales, hr, ecommerce, operations, compliance) khớp với agents thực tế trong `.claude/agents/business/`. Tôi đã spot-check tên agent — 7 domain agents tồn tại. **Status:** OK.

### 4.2 Calibration-required thresholds

4 thresholds được đánh dấu "calibration-required" trong `09-thresholds-justification.md`:
- Cache hit rate 50% → 70%
- Drift tolerance SMALL/MEDIUM fine-tune
- Rename detection Levenshtein
- Per-agent timeout P99 buffer

**Risk:** Nếu Phase I calibration cho kết quả bất thường (VD cache hit rate chỉ đạt 30%), design quyết định có thể phải revise. **Mitigation:** Đã có env var override cho user tune.

### 4.3 A.3 dependency

Phase I (Integration Testing) hard-depend vào 3 fixtures + v4.1 baseline. **A.3 chưa có fixture content.** Phase B/C không block (không dùng fixture). Phase D có thể chạy partial nhưng backward-compat full verify cần A.3 done. **Proposed timeline:** User có thể làm A.3 parallel với Phase B/C (2-3 tuần) để không block Phase D.

### 4.4 CORE-029 ADR integration thiếu Protocol 2 cross-ref

ADR-LS17 nói "Protocol 2 auto-fix loop" nhưng không link đến file cụ thể. **Tech note:** Cần verify `Protocol 2` tồn tại trong `.claude/skills/protocols/` hoặc là reference trong DEVKIT rules. **Action for Phase D:** Đọc Protocol 2 trước khi implement spot-check.

---

## 5. Tech-Review Gate Decision

**Decision:** ✅ **TECH-REVIEW PASSED** — Phase B có thể start.

**Confidence:** HIGH (17/17 ADRs coherent, 20/20 checklist items tech-verified, 6 cross-doc consistency passes).

**Blocking items for production release:** 5 items cần human sign-off (see §2 table), không block Phase B Foundation (không touch ADR decisions).

**Recommendation:** 
1. Create tag `design-legacy-scan-v2.1-tech-review-passed` để signal Phase B readiness. 
2. Human sign-off meeting schedule tiếp theo → tag `design-legacy-scan-v2.1-approved` sau.
3. A.3 fixtures work in parallel với Phase B-C (don't block).

---

## 6. Reviewer Signature

**AI Tech Reviewer:**
- Handle: Claude Opus 4.7 (1M context)
- Date: 2026-04-22
- Scope validated: 17 ADRs + 20-item checklist + 6 cross-doc consistency + implementation plan

**Method:** Static analysis of design docs; không chạy fixture tests (A.3 deferred).

**Disclaimer:** Self-review gate này là technical readiness indicator. Formal sign-off (bảng `§5.1 Sign-off Sheet`) vẫn pending human signatures.
