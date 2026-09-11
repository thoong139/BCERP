# Benchmark Methodology

> Cách đo lường speedup + verify quality preservation per wave.

---

## Mục Tiêu Benchmark

1. **Speedup measurement:** Đo wall-clock time per phase + total pipeline.
2. **Quality verification:** Verify mọi POST-GATE / CDG / CQG / Spot-check vẫn enforce.
3. **No regression:** Output (fixed/deferred/failed counts) bằng hoặc tốt hơn baseline.

---

## Chọn Scenario Benchmark

### Option A: `tools/integration-test.py` Scenarios

Trong `tools/scenarios/` có 8 scenarios A-H. Recommended cho wf-fix-bugs:
- **Scenario G** (nếu là large refactor — best stress test cho parallel batch)
- **Scenario H** (nếu là multi-module — best test cross-module regression)

```bash
cd tools
python integration-test.py run --scenario G --skill wf-fix-bugs --profile exhaustive
```

### Option B: Real Project (EUREKA-2026)

Theo memory: `D:\Working\EUREKA-2026` đã có session E2E từ wf-fix-bugs v7.4 (memory: `project_e2e_fixes_v74.md`). Dùng để benchmark real-world.

**Pre-requisite:** Snapshot codebase trước benchmark, restore sau.

```bash
cd D:/Working/EUREKA-2026
git stash
git checkout HEAD~5  # roll back 5 commits to create bugs
/wf-fix-bugs --profile=exhaustive --scope=all
# measure time
git stash pop
```

### Option C: Synthetic Scenario (Minimal)

Tạo project mới với fixture issues — lightest weight cho dev cycle:
```bash
mkdir /tmp/wf-fix-bench
cd /tmp/wf-fix-bench
# Init from MCV3 template + seed 20-30 bugs
/wf-brainstorm + minimal feature setup
# Inject bugs
/wf-fix-bugs --profile=exhaustive
```

> **Recommendation:** Bắt đầu **Option C** (rapid dev cycle), validate trên **Option A** (regression suite), final benchmark **Option B** (real-world).

---

## Phương Pháp Đo Lường

### Wall-Clock Timing

```bash
# Per phase
START=$(date +%s%3N)
# ... run phase ...
END=$(date +%s%3N)
echo "Phase X duration: $((END - START)) ms"

# Or use built-in trace
jq '.[] | select(.phase == "phase_6") | {event, timestamp}' "$SESSION_DIR/session-log.json"
```

### CI Tool Call Count

```bash
# Count gitnexus_impact calls
jq '[.entries[] | select(.event == "CI_TOOL_USED" and .primary == "gitnexus_impact")] | length' "$SESSION_DIR/fix-log.json"

# Cache hit ratio
HITS=$(jq '[.entries[] | select(.event == "CI_TOOL_USED" and .cache_hit == true)] | length' fix-log.json)
TOTAL=$(jq '[.entries[] | select(.event == "CI_TOOL_USED")] | length' fix-log.json)
echo "Cache hit ratio: $(echo "scale=2; $HITS / $TOTAL * 100" | bc)%"
```

### Subprocess Count (W1.3)

```bash
# Use strace to count subprocess
strace -f -c -e trace=execve bash phase6_post_gate_test.sh 2>&1 | grep "execve"
```

### Memory Profiling (W2.1 Playwright parallel)

```bash
# Track Chromium memory during parallel contexts
ps -o pid,rss,cmd -p $(pgrep -f chromium) | awk '{sum+=$2} END {print sum/1024 " MB"}'
```

---

## Benchmark Report Template

> Sau mỗi wave benchmark, tạo file `benchmarks/wave{N}-{YYYY-MM-DD}.md` theo template sau.

```markdown
# Wave {N} Benchmark Report — {date}

**Scenario:** [Option A/B/C — tên cụ thể]
**Profile:** exhaustive
**Project size:** [N issues, M files in scope]
**Machine:** [CPU cores, RAM, OS]
**Baseline branch:** [git ref before changes]
**Optimized branch:** [git ref after Wave N]

## Wall-Clock Time

| Phase | Baseline (s) | Optimized (s) | Speedup |
|-------|-------------:|--------------:|--------:|
| Phase 1 Init | | | |
| Phase 2 Scan | | | |
| Phase 3 Plan | | | |
| Phase 4 Find Bugs | | | |
| Phase 5 Triage | | | |
| Phase 6 Execute | | | |
| Phase 7 Verify | | | |
| **TOTAL** | | | |

## CI Tool Metrics (post W1.2 + W3.2)

| Metric | Baseline | Optimized | Delta |
|--------|---------:|----------:|------:|
| Total gitnexus_impact calls | | | |
| Cache hit rate | 0% | | |
| Average CI duration per issue (ms) | | | |

## Quality Verification

| Check | Baseline | Optimized | Status |
|-------|----------|-----------|--------|
| POST-GATE T1-T4 pass (every phase) | ✅ | | |
| CDG render (HIGH/CRITICAL count) | N | N | parity |
| CQG hard-enforce | PASS | PASS | parity |
| Spot-check count (≥ agent spawn count) | N | N | parity |
| fixed_count | N | N | parity |
| deferred_count | N | N | parity |
| failed_count | N | N | parity |

## Observations

- [Notes about unexpected behavior]
- [Anomalies or interesting findings]

## Recommendations

- [Should we proceed to next wave? Y/N + reasoning]
- [Any tweaks needed?]
```

---

## Acceptance Threshold Per Wave

| Wave | Speedup Min | Quality |
|------|------------:|---------|
| W1 (after 1.4) | ≥25% | 0 regression, all guard rails enforced |
| W2 (after 2.3) | +15% cumulative ≥40% | 0 race conditions, parallel safe |
| W3 (after 3.4) | +10% cumulative ≥50% | All checks pass, full delivery |

**Nếu speedup < target:** STOP. Phân tích bottleneck mới. KHÔNG advance wave tiếp theo cho đến khi resolve.

**Nếu quality regression:** STOP IMMEDIATELY. Rollback (git revert hoặc escape hatch env). Re-run baseline.

---

## Smoke Test Suite (Quick Verification Per Task)

Sau mỗi task, chạy smoke test trước khi mark COMPLETED:

```bash
# 1. Compliance audit
bash .claude/scripts/skill-compliance-audit.sh wf-fix-bugs
bash .claude/scripts/skill-compliance-audit.sh wf-fix-execute

# 2. Schema sync
bash .claude/scripts/validate-schema-sync.sh wf-fix-bugs
bash .claude/scripts/validate-schema-sync.sh wf-fix-execute

# 3. Pipeline naming
bash .claude/scripts/validate-pipeline-naming.sh

# 4. Python tests (nếu chạm _shared)
cd .claude/skills/workflow/_shared && ./run-tests.sh --fast

# 5. Dry-run pipeline (no real fix)
/wf-fix-bugs --dry-run --profile=exhaustive
```

Toàn bộ pass → mark task COMPLETED. Bất kỳ FAIL → fix trước khi advance.

---

## Real-World Benchmark Plan

### Phase 1: Baseline (no optimization)
```bash
# Trên project test
git checkout main
git tag wf-fix-bugs-v10.0.1-baseline
/wf-fix-bugs --profile=exhaustive --scope=all 2>&1 | tee baseline-run.log

# Record metrics
SESSION=$(ls -t .mc-data/work/wf-fix-bugs/sessions | head -1)
cp -r ".mc-data/work/wf-fix-bugs/sessions/$SESSION" benchmarks/baseline-$SESSION
```

### Phase 2: Per-wave benchmark
```bash
# Sau Wave 1
git checkout feat/wf-fix-bugs-v10-speedup-wave1
/wf-fix-bugs --profile=exhaustive --scope=all 2>&1 | tee wave1-run.log

# Compare
python tools/benchmark-compare.py --baseline benchmarks/baseline-* --optimized .mc-data/work/wf-fix-bugs/sessions/[new] > benchmarks/wave1-report.md
```

### Phase 3: Final benchmark
```bash
# Same with Wave 2 + Wave 3 merged
git checkout feat/wf-fix-bugs-v10-speedup-final
/wf-fix-bugs --profile=exhaustive --scope=all 2>&1 | tee final-run.log
```

---

## Anti-Patterns to Avoid

### ❌ Cheating speedup by skipping work

- Skip POST-GATE → speedup +10% but quality compromised
- Skip Spot-check → speedup +5% but agent errors leak
- Skip CDG → speedup +2% but user safety bypass

**Defense:** Compliance matrix (`01-guard-rails.md`) enforces — every speedup must preserve guard rails.

### ❌ Benchmarking với scenario nhỏ

Scenario A (10 issues) → speedup không đại diện. Profile exhaustive cần ≥30 issues across ≥5 files để stress-test parallel + cache.

### ❌ Benchmarking ONLY once

Variance giữa runs có thể ±10%. Chạy ít nhất 3 runs, report median.

```bash
for i in 1 2 3; do
  /wf-fix-bugs --profile=exhaustive --scope=all > run-$i.log
done
# Median = second-fastest of 3
```

---

## Stretch Goals (Beyond v10.1.0)

Nếu Wave 3 đạt ≥50% speedup, có thể consider future v10.2.0 improvements:
- Distributed dimension scan (Phase 4 parallel hơn nữa)
- Pre-warmed agent context (template caching)
- Persistent disk-tier cache cho CI impact across sessions

KHÔNG implement trong scope plan này — defer to next plan.
