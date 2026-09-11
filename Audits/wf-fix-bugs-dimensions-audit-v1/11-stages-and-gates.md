# 11 — Stages & Gates: Cấu Trúc Thực Thi Plan

> **Phương án:** D — Phased Plan with Evidence Gates (chốt 2026-05-08, xem [12-decisions-log.md](./12-decisions-log.md) DEC-001)
> **Mục đích:** Định nghĩa 5 stages có gate evidence-based, đảm bảo CORE-024 (downstream cần upstream evidence) và CORE-025 (parallelization an toàn).

## Nguyên tắc cốt lõi

1. **Stage N+1 KHÔNG START đến khi Gate N artifact đầy đủ + signed off.**
2. **Audit (Stage 1) parallel-ready** — mỗi dim có owner riêng, contract chung. Default: 1 owner sequential (xem DEC-002).
3. **Implementation (Stage 3) tuần tự theo priority** — không skip P0 để làm P1.
4. **Mọi findings phải có file:line evidence** trước khi vào roadmap.

---

## Stage 0 — Charter & Infrastructure (1 tuần)

**Input:**
- Plan v1.0.0 hiện tại
- 4 quyết định ở [12-decisions-log.md](./12-decisions-log.md)

**Hoạt động:**
- Lock methodology + DoD tại [13-definition-of-done.md](./13-definition-of-done.md)
- Build adapter scaffolding tại `.claude/skills/workflow/_shared/adapters/` (cho IMP-001/003/010 dùng chung)
- Build fixture skeleton (7 dims) tại `fixtures/qd<N>-test/`
- Khởi tạo pytest harness tại `tests/` (DEC-004)

**Output (G0 artifacts):**
- `12-decisions-log.md` — 4 decisions answered + rationale
- `13-definition-of-done.md` — DoD locked
- `fixtures/{README, qd1-test, ..., qd7-test}/` — skeleton folders
- `tests/{conftest.py, run-audit-tests.sh}` — pytest infra

**Gate G0 criteria:**
- [ ] `12-decisions-log.md` có ≥4 entries với rationale
- [ ] `13-definition-of-done.md` complete
- [ ] 7 fixture folders tồn tại với README mỗi cái
- [ ] `tests/conftest.py` compile + chạy được (smoke test)

---

## Stage 1 — Audit Execution (3-4 tuần)

**Default mode:** 1 owner sequential. **Parallel-ready:** mỗi dim có thể giao 1 owner riêng.

### Thứ tự sequential (mặc định, theo rủi ro)

| # | Dim | Tuần | Lý do thứ tự |
|---|---|---|---|
| 1 | QD1 hoàn thành Phase 2-4 | 1 | Đã pre-seeded Phase 1+5 |
| 2 | QD3 Security | 2 | High risk — security bugs tác động nặng |
| 3 | QD6 Data Integrity | 3 | High risk — data corruption khó recovery |
| 4 | QD2 Business | 3.5 | Agent hallucination risk — cần audit kỹ |
| 5 | QD4 Performance | 4 | Lower risk |
| 6 | QD5 UX/A11y | 4.5 | Lower risk |
| 7 | QD7 Compat | 4.5 | Ít probe nhất (5) |

### Per-dim execution: 5 phases (xem [01-audit-methodology.md](./01-audit-methodology.md))

- Phase 1: Static Review (đọc dimension.json + probe files)
- Phase 2: Code Trace (bash scripts + Python modules)
- Phase 3: Test Fixture & Accuracy Measurement (DEC-004 pytest)
- Phase 4: Cross-Probe Interaction
- Phase 5: Synthesize Findings → audit report

### Output (G1 artifacts)

- 7 audit reports đầy đủ 8 sections (files 02-08)
- `fixtures/qd<N>-test/` có ≥10 cases per dim (5 positive + 5 negative)
- `tests/test_qd<N>_probes.py` — pytest cases pass
- `audit-perf-qd<N>.json` — selective benchmarks (DEC-003: probes có cost ≥60s hoặc agent type)

### Gate G1 criteria

- [ ] 7 audit reports DoD pass (xem 13-DoD §Audit Report)
- [ ] Mỗi dim ≥5 findings (FP+FN+EC) với file:line evidence
- [ ] Mỗi dim ≥3 reproducible test cases trong `fixtures/`
- [ ] Cross-cutting findings cập nhật từ ≥2 dim per theme (file 09)
- [ ] `progress.md`: 7 dim marked ✅
- [ ] Pytest pass: `tests/run-audit-tests.sh`

---

## Stage 2 — Roadmap Consolidation (1 tuần)

**Input:** Output Stage 1 + `09-cross-cutting-findings.md`

**Hoạt động:**
- Re-build cross-cutting (xác nhận 5+ themes verified từ ≥2 dim)
- Lock roadmap tại `10-improvement-roadmap.md`:
  - IMP `evidence_status: tentative` → `verified` hoặc `dropped`
  - Effort re-estimate dùng data từ fixtures
- Cross-skill impact analysis (đặc biệt IMP-002 registry schema change → coordinate với `wf-brainstorm`)
- Sync verified findings → `wf-fix-{dim}/evals/evals.json` (DEC-006)

**Output (G2 artifacts):**
- `10-improvement-roadmap.md` — IMPs locked với `evidence_status: verified|dropped`
- `wf-fix-{dim}/evals/evals.json` updated cho 7 lane skills
- Sprint allocation final (dùng effort re-estimate)

**Gate G2 criteria:**
- [ ] Tất cả IMP có `evidence_status` ∈ {verified, dropped} (không còn tentative)
- [ ] Mỗi IMP verified có acceptance test fixture path
- [ ] IMP-002 (project.locale field) có cross-skill impact analysis với `wf-brainstorm` author
- [ ] Tất cả 7 `evals.json` sync xong, schema valid

---

## Stage 3 — Implementation Sprints (~7 tuần)

**Default execution:** Tuần tự theo priority P0 → P1 → P2 → P3
**Sprint structure:** Định nghĩa ở `10-improvement-roadmap.md §Sprint Allocation`

**Output (G3 artifacts):**
- Code changes per IMP với unit test pass
- `CHANGELOG.md` updated cho mỗi IMP done
- Pytest pass `_shared/` (coverage ≥80%, hiện có gate)

**Gate G3 criteria:**
- [ ] Tất cả P0/P1 IMP có code + unit test pass
- [ ] CHANGELOG.md updated
- [ ] Re-run audit fixtures cho thấy improvement (precision/recall ↑)

---

## Stage 4 — Re-audit Verification (1 tuần)

**Input:** Stage 3 output

**Hoạt động:**
- Re-run pytest audit suite (`tests/`) trên fixtures
- So sánh precision/recall trước-sau Sprint
- Generate improvement report

**Output:**
- `improvement-report.md` — metrics so sánh per probe
- evals.json regression baseline updated

---

## Parallel Ownership Matrix (khi có >1 owner)

Tất cả 7 dim có thể parallel ở Stage 1 vì:
- Mỗi dim đọc skill khác nhau, ghi audit report khác file
- Không cross-write giữa audit reports
- Cross-cutting findings consolidate ở Stage 2 (sequential)

**Conflict map:** KHÔNG có conflict tại Stage 1.
**Stage 2-4:** Sequential bắt buộc.

---

## Effort Re-estimate

| Stage | 1 owner | 3 owners parallel | Notes |
|---|---|---|---|
| Stage 0 | 1 tuần | 1 tuần | Sequential bắt buộc |
| Stage 1 | 4 tuần | 2 tuần | Parallelize được (CORE-025) |
| Stage 2 | 1 tuần | 1 tuần | Sequential — cần consolidation |
| Stage 3 | 7 tuần | 4 tuần | Parallel theo IMP độc lập |
| Stage 4 | 1 tuần | 1 tuần | Sequential |
| **Total** | **14 tuần** | **9 tuần** | |

**So với plan gốc (12 tuần):** +2 tuần do thêm Stage 0 + Stage 2 + Stage 4 (gates + re-audit). Đánh đổi này tuân CORE-023 (chất lượng > tốc độ).

---

## Liên quan

- [00-master-plan.md](./00-master-plan.md) §5 Timeline reference file này
- [12-decisions-log.md](./12-decisions-log.md) — Quyết định DEC-001 đến DEC-006
- [13-definition-of-done.md](./13-definition-of-done.md) — DoD criteria cho mỗi gate
