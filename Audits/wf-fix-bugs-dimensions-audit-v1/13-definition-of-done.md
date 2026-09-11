# 13 — Definition of Done (DoD)

> **Mục đích:** Định nghĩa rõ ràng "DONE" ở mỗi cấp độ để tránh false completion.
> **Nguyên tắc:** Mọi DoD đều có **acceptance criteria có thể verify** (file tồn tại, lệnh pass, số liệu đạt threshold).
> **Reference:** [11-stages-and-gates.md](./11-stages-and-gates.md), [12-decisions-log.md](./12-decisions-log.md)

## DoD cấp độ

```
Plan DONE ⊃ Stage DONE ⊃ Sprint DONE ⊃ Dim audit DONE ⊃ Phase DONE
```

5 stages map sang sprints (xem [11-stages-and-gates.md](./11-stages-and-gates.md)):
- Stage 0 (Charter) — không có sprint, infra setup
- Stage 1 (Audit) — Sprint 1-3 (QD audits)
- Stage 2 (Consolidation) — Sprint 4 (cross-cutting + roadmap)
- Stage 3 (Implementation) — Sprint 5+ (sau khi Stage 2 pass)
- Stage 4 (Re-audit) — final verification

---

## Phase-level DoD (per phase × per dim)

### Phase 1 — Static Review DONE khi:
- [ ] File `0X-qd<N>-*-audit.md` §1 (Tổng quan) được fill đầy đủ với 6 fields (dimension_id, name, owner, probes count, profile, lane_skill)
- [ ] §2 (Liệt kê probes) có bảng đầy đủ N probes với 6 cột (id, type, depth, severity, tool, cost)
- [ ] §3 (Per-probe analysis) — mỗi probe có 4 sub-sections (SENSE, THINK, ACT, VERIFY) ≥ 50 chars mỗi sub
- [ ] Đã verify đường dẫn các probe files thực sự tồn tại trong `procedures/probes/`

**Verify command:**
```bash
DIM_FILE="plans/wf-fix-bugs-dimensions-audit-v1/0X-qd<N>-*-audit.md"
grep -c "^### Probe" "$DIM_FILE"  # ≥ N probes
grep -c "^**SENSE:" "$DIM_FILE"   # ≥ N
grep -c "^**THINK:" "$DIM_FILE"   # ≥ N
grep -c "^**ACT:" "$DIM_FILE"     # ≥ N
grep -c "^**VERIFY:" "$DIM_FILE"  # ≥ N
```

### Phase 2 — Code Trace DONE khi:
- [ ] Đã đọc tối thiểu **50% probes implementation** (bash scripts trong `.claude/scripts/wf-fix-probe-*.sh`)
- [ ] Đã đọc lane dispatcher và signal aggregator
- [ ] §3 mỗi probe có dòng "Spec ↔ Implementation discrepancy" với verdict (✅ match | ⚠️ partial | ❌ mismatch)
- [ ] Nếu có discrepancy → file đã ghi rõ "Spec nói X, code làm Y, severity Z"

### Phase 3 — Test Fixture & Accuracy DONE khi:
- [ ] Folder `fixtures/qd<N>-test/` tồn tại + có `README.md` + `expected-signals.json` + `run.sh`
- [ ] Có ≥ **5 positive cases (TP)** + ≥ **5 negative cases (TN)** trong `expected-signals.json`
- [ ] Đã chạy `bash run.sh QD<N>` thành công (exit 0)
- [ ] Pytest pass: `tests/test_qd<N>_probes.py` (DEC-004)
- [ ] File `accuracy-report.md` được tạo với confusion matrix + Precision/Recall/F1
- [ ] **Precision ≥ 0.7** AND **Recall ≥ 0.6** — nếu thấp hơn → ghi finding cụ thể vào §4 (FP) hoặc §5 (FN)
- [ ] §4 (FP scenarios) có ≥ 3 scenarios documented
- [ ] §5 (FN scenarios) có ≥ 3 scenarios documented

**Verify command:**
```bash
DIM=qd3
test -f "fixtures/${DIM}-test/expected-signals.json"
test -f "fixtures/${DIM}-test/accuracy-report.md"
jq '.expected_signals | length' "fixtures/${DIM}-test/expected-signals.json"  # ≥ 10
grep -E "Precision: [0-9]+%" "fixtures/${DIM}-test/accuracy-report.md"
```

### Phase 4 — Cross-Probe Interaction DONE khi:
- [ ] §"Phase 4" trong audit file có DAG diagram (ASCII/Mermaid)
- [ ] Đã identify ≥ 1 cross-probe interaction issue (cascade, catalog handoff, severity merge, cache conflict)
- [ ] Mỗi issue có file:line reference + reproduce
- [ ] Cross-cutting findings (file 09) đã được update với issues mới phát hiện

### Phase 5 — Synthesize DONE khi:
- [ ] §6 (Tech stack & i18n bias) có bảng support matrix với ≥ 5 stacks
- [ ] §7 (Edge cases) có ≥ 5 edge cases với severity
- [ ] §8 (Recommendations) có ≥ 3 recommendations với:
  - Priority (P0/P1/P2/P3)
  - Effort (XS/S/M/L/XL)
  - Owner (skill-author/agent-author/domain-expert)
  - Acceptance criteria (≥ 2 criteria có thể verify)
  - **YAML frontmatter chuẩn** (xem §IMP DoD bên dưới — DEC-005)
- [ ] [10-improvement-roadmap.md](./10-improvement-roadmap.md) đã được update với IMP items mới
- [ ] [09-cross-cutting-findings.md](./09-cross-cutting-findings.md) đã được update nếu có theme mới
- [ ] [progress.md](./progress.md) đã update — dim đó mark ✅

**Quy tắc thứ tự:** Phase 1 → 2 → 3 → 4 → 5. KHÔNG được mark Phase 5 done khi Phase 4 chưa xong.

---

## IMP-level DoD (per Improvement Item)

Mỗi IMP trong `10-improvement-roadmap.md` PHẢI có YAML frontmatter chuẩn (DEC-005):

```yaml
---
id: IMP-NNN              # Unique trong plan (vd IMP-001, IMP-002)
title: ...               # 1 dòng <80 chars
priority: P0|P1|P2|P3
effort: XS|S|M|L|XL
owner: skill-author|agent-author|domain-expert|user
evidence_status: verified|tentative|inferred|dropped
affected_probes: [P-QDN-..., ...]
gate: G0|G1|G2|G3        # Stage nào unlock IMP này
acceptance_test: <path/to/fixture>
dependencies: [IMP-..., ...]
cross_skill_impact: []   # Skills khác bị ảnh hưởng (vd wf-brainstorm cho schema change)
notes: ...
---
```

### `evidence_status` semantics

| Status | Khi nào dùng | Cho phép vào Sprint Stage 3? |
|---|---|---|
| `verified` | Có file:line evidence + fixture test pass | ✅ Yes |
| `tentative` | Hint từ audit nhưng chưa Phase 2/3 verify | ❌ Block đến G2 |
| `inferred` | Suy luận từ pattern, không trực tiếp evidence | ⚠️ Review trước impl |
| `dropped` | Audit Stage 1 confirm không cần thiết | — |

### Priority semantics

| Priority | Định nghĩa |
|---|---|
| **P0** Blocker | Skill không sử dụng được trên use case quan trọng |
| **P1** High | Coverage giảm > 30% hoặc false rate > 30% |
| **P2** Medium | Improvement đáng kể |
| **P3** Nice-to-have | Polish |

### Effort semantics

| Effort | Time |
|---|---|
| **XS** | < 2h |
| **S** | 2-8h |
| **M** | 1-3 ngày |
| **L** | 1-2 tuần |
| **XL** | > 2 tuần |

---

## Dim Audit-level DoD (per dim)

Một dim audit DONE khi:
- [ ] Tất cả 5 phases (1-5) DONE theo DoD ở trên
- [ ] File `0X-qd<N>-*-audit.md` ≥ 200 dòng (đảm bảo nội dung thực chất)
- [ ] **Findings count đạt minimum:**
  - FP scenarios ≥ 3
  - FN scenarios ≥ 3
  - Edge cases ≥ 5
  - Recommendations ≥ 3
- [ ] Test fixture đầy đủ với accuracy report
- [ ] Selective benchmark (DEC-003): nếu dim có probes ≥60s hoặc agent type → có `audit-perf-qd<N>.json`
- [ ] Sprint report mention dim đó với highlights

**Verify command:**
```bash
DIM_FILE="plans/wf-fix-bugs-dimensions-audit-v1/0X-qd<N>-*-audit.md"
LINES=$(wc -l < "$DIM_FILE")
test "$LINES" -ge 200 || echo "FAIL: file < 200 lines"
grep -c "^| \*\*FP-" "$DIM_FILE"  # ≥ 3
grep -c "^| \*\*FN-" "$DIM_FILE"  # ≥ 3
grep -c "^| \*\*EC-" "$DIM_FILE"  # ≥ 5
grep -c "^| \*\*IMP-" "$DIM_FILE"  # ≥ 3
```

---

## Sprint-level DoD (Stage 1 sub-units)

### Sprint 1 DONE khi (Stage 1, tuần 1-2):
- [ ] QD1 hoàn thành Phase 2-4 (đã pre-seeded Phase 1+5)
- [ ] QD3 audit DONE per Dim DoD
- [ ] Sprint report `reports/sprint-1-report.md` được tạo với:
  - Findings count summary
  - Blockers (nếu có) + resolution
  - Decisions made (cập nhật vào [12-decisions-log.md](./12-decisions-log.md))
  - Next sprint plan adjustments
- [ ] [progress.md](./progress.md) update đầy đủ (✅ cho QD1, QD3)
- [ ] [10-improvement-roadmap.md](./10-improvement-roadmap.md) có ≥ 8 IMP items mới

### Sprint 2 DONE khi (Stage 1, tuần 2-3):
- [ ] QD6 + QD2 audit DONE
- [ ] Tổng IMP items ≥ 14

### Sprint 3 DONE khi (Stage 1, tuần 3-4):
- [ ] QD4, QD5, QD7 audit DONE
- [ ] Tổng IMP items ≥ 22
- [ ] Stage 1 G1 gate pass (xem §Stage Gate DoD)

### Sprint 4 DONE khi (Stage 2, tuần 5):
- [ ] [09-cross-cutting-findings.md](./09-cross-cutting-findings.md) consolidate ≥ 7 themes
- [ ] [10-improvement-roadmap.md](./10-improvement-roadmap.md) priority-sorted, có sprint allocation
- [ ] Tất cả IMP có `evidence_status` ∈ {verified, dropped} (G2 gate)
- [ ] Sync findings → `wf-fix-{dim}/evals/evals.json` (DEC-006)
- [ ] Stakeholder review session done với decisions ghi vào [12-decisions-log.md](./12-decisions-log.md)
- [ ] Final report `reports/final-report.md` được tạo

---

## Stage Gate DoD

| Gate | Stage | Pass criteria | Verify command |
|---|---|---|---|
| **G0** | 0 → 1 | Charter + infra ready | Xem [11 §G0](./11-stages-and-gates.md) |
| **G1** | 1 → 2 | 7 audit reports DoD pass | `scripts/check-audit-dod.sh` |
| **G2** | 2 → 3 | Roadmap locked, evidence_status ∈ {verified, dropped} | `scripts/check-roadmap-locked.sh` |
| **G3** | 3 → 4 | P0/P1 IMPs done, re-audit shows improvement | `tests/run-audit-tests.sh --compare-baseline` |

### Quality Gate Scripts (executable)

**`scripts/check-audit-dod.sh`:**
```bash
#!/usr/bin/env bash
PLAN_DIR="plans/wf-fix-bugs-dimensions-audit-v1"
SECTIONS=("Tổng quan" "Liệt kê probes" "Per-probe Analysis" "False Positive" "False Negative" "Tech Stack" "Edge Cases" "Recommendations")

EXIT=0
for f in "$PLAN_DIR"/0[2-8]-qd*.md; do
  for s in "${SECTIONS[@]}"; do
    grep -q "## .*${s}" "$f" || { echo "MISS: $f / $s"; EXIT=1; }
  done
done
exit $EXIT
```

**`scripts/check-roadmap-locked.sh`:**
```bash
#!/usr/bin/env bash
ROADMAP="plans/wf-fix-bugs-dimensions-audit-v1/10-improvement-roadmap.md"
INVALID=$(grep -E "^evidence_status: (tentative|inferred)" "$ROADMAP" | wc -l)
if [ "$INVALID" -gt 0 ]; then
  echo "FAIL: $INVALID IMPs còn tentative/inferred (cần verify hoặc drop)"
  exit 1
fi
echo "PASS: tất cả IMPs verified hoặc dropped"
```

---

## Plan-level DoD (toàn bộ)

Plan DONE khi:
- [ ] **All 5 stages DONE** per Stage Gate DoD (G0 → G1 → G2 → G3 → Stage 4 verification)
- [ ] **7/7 dim audits DONE** per Dim DoD
- [ ] **All 4 sprints DONE** per Sprint DoD
- [ ] **Tổng deliverables:**
  - 7 audit reports (file 02-08), mỗi file ≥ 200 dòng
  - 1 cross-cutting findings (file 09), ≥ 7 themes
  - 1 improvement roadmap (file 10), ≥ 20 IMP items với YAML frontmatter
  - 7 test fixtures với accuracy reports
  - 4 sprint reports + 1 final report + 1 improvement-report.md (Stage 4)
  - Decision log (file 12)
- [ ] **Findings count tối thiểu:**
  - 21+ FP scenarios (≥ 3 per dim)
  - 21+ FN scenarios
  - 35+ Edge cases (≥ 5 per dim)
  - 21+ Recommendations
  - Tổng ≥ 100 findings
- [ ] **Quality gate:**
  - Tất cả findings có file:line + reproduce steps
  - ≥ 80% recommendations có acceptance criteria verifiable
  - Cross-cutting findings consolidate ≥ 7 themes
  - Roadmap priority distribution: P0 ≤ 20%, P1 ~ 35%, P2 ~ 30%, P3 ≤ 15%
- [ ] **Stakeholder approval:**
  - PM/team-lead reviewed final report
  - Skill-author team committed cho ≥ Sprint 1 của roadmap
  - Decisions pending từ master plan đã có answers (xem [12-decisions-log.md](./12-decisions-log.md))

**Verify command (full plan):**
```bash
cd plans/wf-fix-bugs-dimensions-audit-v1

# 1. Files exist
for f in 00-master-plan 01-audit-methodology 02-qd1-functional-audit 03-qd2-business-audit \
         04-qd3-security-audit 05-qd4-performance-audit 06-qd5-ux-a11y-audit \
         07-qd6-data-audit 08-qd7-compat-audit 09-cross-cutting-findings \
         10-improvement-roadmap 11-stages-and-gates 12-decisions-log 13-definition-of-done; do
  test -f "${f}.md" || echo "MISSING: ${f}.md"
done
test -f README.md && test -f progress.md
test -f fixtures/README.md

# 2. Audit files quality
for f in 02-qd1*.md 03-qd2*.md 04-qd3*.md 05-qd4*.md 06-qd5*.md 07-qd6*.md 08-qd7*.md; do
  LINES=$(wc -l < "$f")
  test "$LINES" -ge 200 || echo "SHORT: $f ($LINES lines)"
done

# 3. Findings count
TOTAL_FP=$(grep -h "^| \*\*FP-" 0[2-8]*.md | wc -l)
TOTAL_FN=$(grep -h "^| \*\*FN-" 0[2-8]*.md | wc -l)
TOTAL_IMP=$(grep -hcE "^id: IMP-" 10-*.md)

test "$TOTAL_FP" -ge 21 || echo "FAIL: FP < 21 ($TOTAL_FP)"
test "$TOTAL_FN" -ge 21 || echo "FAIL: FN < 21 ($TOTAL_FN)"
test "$TOTAL_IMP" -ge 20 || echo "FAIL: IMP < 20 ($TOTAL_IMP)"

# 4. Fixtures
for d in qd{1,2,3,4,5,6,7}; do
  test -f "fixtures/${d}-test/accuracy-report.md" || echo "MISSING fixture: $d"
done

# 5. Sprint reports
for n in 1 2 3 4; do
  test -f "reports/sprint-${n}-report.md" || echo "MISSING: sprint-${n}-report.md"
done
test -f "reports/final-report.md" || echo "MISSING: final-report.md"
test -f "reports/improvement-report.md" || echo "MISSING: improvement-report.md (Stage 4)"

# 6. Roadmap evidence_status check (G2 gate)
INVALID=$(grep -cE "^evidence_status: (tentative|inferred)" 10-improvement-roadmap.md)
test "$INVALID" -eq 0 || echo "FAIL: $INVALID IMPs còn tentative/inferred"

echo "DoD check complete."
```

---

## Anti-patterns (KHÔNG được mark DONE)

- ❌ "Audit xong rồi" mà không có file:line cho findings — phải có specific evidence
- ❌ Test fixture chỉ có 2-3 cases — không đủ statistical significance
- ❌ Recommendations chỉ là "improve X" — phải có YAML frontmatter + acceptance criteria
- ❌ IMP có `evidence_status: tentative` mà mark Stage 2 done — vi phạm G2 gate
- ❌ Cross-cutting findings chỉ liệt kê dim mà không identify root cause
- ❌ Roadmap toàn P0 — đã violate priority distribution
- ❌ Skip Phase 3 (test fixture) "vì không có thời gian" — Precision/Recall là baseline metric quan trọng
- ❌ Mark Phase 5 done khi Phase 4 chưa xong — vi phạm thứ tự methodology
- ❌ Mark dim DONE khi audit file < 200 lines — nội dung quá mỏng
- ❌ Sprint report không có blockers section — không thể không có blocker nào trong 1-2 tuần audit
- ❌ Decision log trống — mọi audit đều phải có ít nhất 3-5 quyết định cần ghi nhận
- ❌ Stage 3 IMP impl mà chưa qua G2 gate — fix trên evidence chưa đủ (vi phạm CORE-024)

---

## Sign-off Process

Khi mark Plan DONE:
1. Run verify command (cuối §"Plan-level DoD")
2. Self-review checklist
3. Peer review (nếu có team)
4. Stakeholder review session — ghi minutes vào [12-decisions-log.md](./12-decisions-log.md)
5. Final commit + tag: `git tag plan-wf-fix-bugs-dimensions-audit-v1-DONE`
6. Kickoff meeting cho Sprint Stage 3 của roadmap

## Liên quan

- [11-stages-and-gates.md](./11-stages-and-gates.md) — Khi nào đạt mỗi DoD (Stage architecture)
- [12-decisions-log.md](./12-decisions-log.md) — Quyết định DEC-001 đến DEC-006
- [fixtures/README.md](./fixtures/README.md) — Spec để pass Phase 3 DoD
- [01-audit-methodology.md](./01-audit-methodology.md) — Phương pháp để đạt phase DoD
