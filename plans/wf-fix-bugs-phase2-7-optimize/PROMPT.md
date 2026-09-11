# 🎯 PROMPT — Tối ưu Phase 5-7 + _shared.md của wf-fix-bugs (kế thừa pattern v10.3 + v10.4 + v10.5 + v10.6)

> **Cách dùng:** Copy toàn bộ nội dung file này → paste vào phiên Claude Code mới trên repo `D:\Working\MCV3`.
> Prompt là self-contained — không cần context từ phiên trước.
>
> **Cập nhật:** 2026-05-16 sau khi hoàn thành Phase 4 v10.6.0 (merged commit `0a90df23`).

---

## Mission

Áp dụng pattern tối ưu v10.3 (Phase 1) + v10.4 (Phase 2) + v10.5 (Phase 3) + v10.6 (Phase 4) lên **3 phase còn lại + _shared.md** của skill `wf-fix-bugs`. Mục tiêu cuối: toàn bộ procedure files dưới ~12K tokens mỗi file (target ~5-8K), tổng pipeline có thể chạy end-to-end trên EUREKA-2026 mà không bao giờ trigger `/compact` ở bất kỳ phase nào.

---

## Trạng thái hiện tại (2026-05-16)

### Đã DONE + merged vào master — KHÔNG cần làm lại

| Phase | Version | Merge commit | Wave commits | Tag rollback | Metrics |
|-------|---------|--------------|--------------|--------------|---------|
| **1 Init** | v10.3.0 | `378d56d7` | `6325d81d` + `a291c56b` | `pre-phase1-optimize` | 25→18 steps, ~28K→~10.75K tokens (-62%) |
| **2 Scan** | v10.4.0 | `9af23c8e` | `6d5f285e` + `79ed6f3c` | `pre-phase2-scan-optimize` | 10→5 steps (-50%), ~8.4K→~3.45K tokens (-59%) |
| **3 Plan** | v10.5.0 | `8d0882d6` | `9c9787bc` + `b7c65db6` | `pre-phase3-plan-optimize` | 12→7 steps (-42%), ~10.93K→~5.24K tokens (-52%) |
| **4 Find Bugs** | v10.6.0 | `0a90df23` | `76aaf312` + `02bd3bf9` | `pre-phase4-find-bugs-optimize` | 12→9 steps (-25%), ~15.65K→~8.56K tokens (-45%) |

**Verify trạng thái master** (lệnh khởi phiên):

```bash
cd "d:/Working/MCV3"
git log --oneline -12
# Phải thấy:
#   0a90df23 Merge feature/phase4-find-bugs-optimize: wf-fix-bugs v10.6.0
#   02bd3bf9, 76aaf312 (Phase 4 commits)
#   8d0882d6 Merge feature/phase3-plan-optimize: wf-fix-bugs v10.5.0
#   b7c65db6, 9c9787bc (Phase 3 commits)
#   9af23c8e Merge feature/phase2-scan-optimize: wf-fix-bugs v10.4.0
#   79ed6f3c, 6d5f285e (Phase 2 commits)
#   378d56d7 Merge feature/phase1-optimize: wf-fix-bugs v10.3.0
#   a291c56b, 6325d81d (Phase 1 commits)

# Verify v10.6 files trên master
grep "^version" .claude/skills/workflow/wf-fix-bugs/SKILL.md   # → version: 10.6.0
jq -r '.version' .claude/skills/workflow/wf-fix-bugs/_contract.json   # → 10.6.0
wc -l .claude/skills/workflow/wf-fix-bugs/procedures/phase4-find-bugs.md   # → 740
ls .claude/scripts/wf-fix-bugs/setup-lanes.sh \
   .claude/scripts/wf-fix-bugs/create-lane-dirs.sh \
   .claude/scripts/wf-fix-bugs/verify-lane-prompt.sh \
   .claude/scripts/wf-fix-bugs/monitor-lanes.sh \
   .claude/scripts/wf-fix-bugs/validate-lane-outputs.sh \
   .claude/scripts/wf-fix-bugs/generate-phase4-report.sh \
   .claude/scripts/wf-fix-bugs/finalize-phase4.sh
```

Nếu **không** thấy các commits/files trên → có thể rollback hoặc nhầm repo. Đọc `memory/project_wf_fix_bugs_phase2_7_optimize.md` để xác nhận.

### Còn lại

| Phase | File | Lines | Tokens (est.) | Steps | Code blocks | Priority |
|-------|------|-------|---------------|-------|-------------|----------|
| **5 Triage** | `procedures/phase5-triage.md` | 1,039 | ~10.73K | **15** (nhiều nhất) | 64 | **HIGH (NEXT)** ⭐ |
| **6 Execute** | `procedures/phase6-execute.md` | 968 | ~10.81K | 11 | 44 | MEDIUM |
| **7 Verify** | `procedures/phase7-verify.md` | 1,186 (dài nhất) | ~11.96K | 14 | 46 | MEDIUM (gần threshold) |
| **_shared.md** | `procedures/_shared.md` | 1,013 | ~12.16K | N/A | 52 | LOW (defer cuối) |

**Phase 5 tiếp theo theo pipeline order** (user đã chọn Option A từ đầu). Phase 5 có **15 steps (nhiều nhất pipeline)** + agent delegation pattern (spawn `wf-fix-triage`) — khuyến nghị dành riêng 1 phiên.

---

## Pattern đã chứng minh hiệu quả (đúc kết v10.3 + v10.4 + v10.5 + v10.6)

### Pattern v10.6 (Phase 4) — commits 76aaf312 + 02bd3bf9 ⭐ NEWEST

| Pattern (mới hoặc bổ sung) | Áp dụng Phase 4 | Kết quả |
|----------------------------|------------------|---------|
| **Gộp 2+2+2 steps thành 3 atomic blocks** | 12 → 9 steps qua 3 lần gộp: 4.2+4.3 → 4.2, 4.6+4.7 → 4.6, 4.9+4.10 → 4.9 | -25% steps |
| **GIỮ INLINE cho user interaction** | Step 4.3a Browser CDG (E090/E090b) có AskUserQuestion → KHÔNG delegate sang script | Preserve UX flow |
| **GIỮ orchestrator-side cho Agent tool calls** | Step 4.5 Dispatch Lane Agents — Agent tool calls không script được (CORE-037) | Preserve dispatch contract |
| **PRESERVE semantics khi delegate execution** | Step 4.5a 6 check points → verify-lane-prompt.sh giữ nguyên 6 check rules (v10.2 fantasy-prompt guard) | Behavior preserved |
| **Multi-script delegation cho 1 phase (cao nhất từ trước)** | 7 scripts mới cho 1 phase — phù hợp khi phase có nhiều logical groups + agent dispatch + monitor/collect | Modular, easier debug |
| **Cross-platform CRLF defensive** | `tr -d '\r'` trong setup-lanes.sh để strip Windows line endings | Git Bash + WSL compat |

**7 scripts mới (Phase 4 v10.6) — pattern cho Phase 5:**
- `scripts/wf-fix-bugs/setup-lanes.sh` (~190 dòng) — gộp Steps 4.2+4.3 (TRACE START + Load PW Metadata)
- `scripts/wf-fix-bugs/create-lane-dirs.sh` (~95 dòng) — Step 4.4 (mkdir + template populate)
- `scripts/wf-fix-bugs/verify-lane-prompt.sh` (~75 dòng) — Step 4.5a (6 check points, PRESERVE semantics)
- `scripts/wf-fix-bugs/monitor-lanes.sh` (~145 dòng) — Step 4.6 part 1 (poll + timeout + context budget CORE-038)
- `scripts/wf-fix-bugs/validate-lane-outputs.sh` (~205 dòng) — Step 4.6 part 2 (POST-GATE T1-T4)
- `scripts/wf-fix-bugs/generate-phase4-report.sh` (~110 dòng) — Step 4.8 Phase Report (CORE-031)
- `scripts/wf-fix-bugs/finalize-phase4.sh` (~125 dòng) — gộp Steps 4.9+4.10 (Update fix-status + TRACE COMPLETE)

### Patterns v10.3 / v10.4 / v10.5 (xem CHANGELOG.md để chi tiết)

| Pattern | Phase 1 v10.3 | Phase 2 v10.4 | Phase 3 v10.5 | Phase 4 v10.6 |
|---------|---------------|----------------|----------------|----------------|
| Script delegation cho inline heredocs >20 dòng | 3 scripts | 2 scripts | 3 scripts | **7 scripts** |
| Step consolidation (gộp N steps làm cùng 1 việc) | 25→18 (-28%) | 10→5 (-50%) | 12→7 (-42%) | 12→9 (-25%) |
| Markdown boilerplate compression | -30% | -30% | -30% | -33% |
| Dead code deletion | E100 duplicate | Step 2.8 TRACE | N/A | N/A |
| Just-in-time CDG (Phase 1 only) | E090/E090b → Phase 4 | N/A | N/A | N/A |
| Auto-resolve > Default > WARN > CDG | E091/E092/E093 | N/A | N/A | N/A |
| Fix CORE-031 template usage bug | N/A | Phase 2 Report | Phase 3 Report | N/A |
| Step numbering giữ gaps | 1.15-1.24 | 2.4-2.8 | 3.4, 3.7-3.9, 3.12 | **4.3, 4.7, 4.10** |
| GIỮ INLINE cho user interaction (CDG/AskUser) | N/A | N/A | CDG-11 Workload | **CDG E090/E090b Browser** |
| GIỮ orchestrator-side cho Agent tool calls | N/A | N/A | N/A | **Step 4.5 Dispatch** |
| Combined Wave 1 (W1=scripts+rewrite, W2=version+cross-files) | tách | tách | tách | tách |
| Merge --no-ff Phương án A (per phase, isolated rollback) | giống | giống | giống | giống |

---

## Bắt buộc đọc trước (BHV-001 — Think Before Coding)

**KHÔNG được refactor blind.** Phải đọc 10 files này trước khi đề xuất bất kỳ thay đổi nào:

1. `CLAUDE.md` — Định vị MCV3, BHV/CORE rules
2. `.claude/rules/00-behavioral.md` — 4 BHV principles
3. `.claude/rules/00-core.md` §4i-4o — CORE-032 → CORE-038 chuẩn skill architecture
4. `.claude/skills/workflow/wf-fix-bugs/SKILL.md` — Pipeline overview, Phase Summary table (đã updated v10.6)
5. `.claude/skills/workflow/wf-fix-bugs/_contract.json` — Cross-skill contract, outputs (đã updated v10.6)
6. `.claude/skills/workflow/wf-fix-bugs/procedures/phase1-init.md` — **Reference implementation #1 v10.3**
7. `.claude/skills/workflow/wf-fix-bugs/procedures/phase2-scan.md` — **Reference implementation #2 v10.4** (Step 2.3 gộp 5 logical phases)
8. `.claude/skills/workflow/wf-fix-bugs/procedures/phase3-plan.md` — **Reference implementation #3 v10.5** (Steps 3.3 + 3.6 + 3.11 gộp + CDG-11 inline)
9. `.claude/skills/workflow/wf-fix-bugs/procedures/phase4-find-bugs.md` — **Reference implementation #4 v10.6** ⭐ NEW (3 step gộp + CDG inline + 4.5 dispatch orchestrator-side + 4.5a semantics preserved)
10. `CHANGELOG.md` mục `[wf-fix-bugs v10.6.0]` + `[wf-fix-bugs v10.5.0]` + `[wf-fix-bugs v10.4.0]` + `[wf-fix-bugs v10.3.0]` — hiểu chi tiết changes

**Verify commits đã merge/tồn tại:**

```bash
git log --oneline --all -12
# Phải thấy: 0a90df23, 02bd3bf9, 76aaf312 (Phase 4 v10.6)
# và: 8d0882d6, b7c65db6, 9c9787bc (Phase 3 v10.5)
# và: 9af23c8e, 79ed6f3c, 6d5f285e (Phase 2 v10.4)
# và: 378d56d7, a291c56b, 6325d81d (Phase 1 v10.3)

git show 76aaf312 --stat   # Phase 4 Wave 1 — 7 scripts + procedure rewrite
git show 02bd3bf9 --stat   # Phase 4 Wave 2 — cross-files update
```

**Đọc kỹ 7 reference scripts mới (Phase 4 v10.6) — pattern cho Phase 5+:**

```bash
# Phase 4 v10.6 scripts (làm template cho Phase 5+)
.claude/scripts/wf-fix-bugs/setup-lanes.sh                # ~190 dòng — gộp 2 logical sub-steps
.claude/scripts/wf-fix-bugs/create-lane-dirs.sh           # ~95 dòng — FOR loop template populate
.claude/scripts/wf-fix-bugs/verify-lane-prompt.sh         # ~75 dòng — semantic-preserving execution delegate
.claude/scripts/wf-fix-bugs/monitor-lanes.sh              # ~145 dòng — poll loop + context budget CORE-038
.claude/scripts/wf-fix-bugs/validate-lane-outputs.sh      # ~205 dòng — POST-GATE T1-T4 4 tiers
.claude/scripts/wf-fix-bugs/generate-phase4-report.sh     # ~110 dòng — Phase Report CORE-031
.claude/scripts/wf-fix-bugs/finalize-phase4.sh            # ~125 dòng — gộp Update + TRACE
```

---

## Methodology — Quy trình BẮT BUỘC

### Bước 1: Discovery (đọc + đo, KHÔNG sửa)

Cho mỗi phase target:

```bash
# Đo metrics hiện tại
PHASE="phase5-triage"   # thay bằng phase đang xử lý
F=".claude/skills/workflow/wf-fix-bugs/procedures/${PHASE}.md"
wc -l "$F"
echo "Tokens: ~$(($(wc -c < "$F") / 4))"
grep -n "^### Step" "$F"
```

Đọc file đầy đủ (KHÔNG được skim) → lập **bản đồ trách nhiệm**:
- Phase này có bao nhiêu mục đích atomic? (1 phase = 1 mục đích — BHV-004)
- Step nào làm cùng 1 việc và có thể gộp? (vd Phase 4 v10.6: 2+2+2 → 3 atomic blocks)
- Step nào có "step pollution" — tồn tại chỉ vì design sai?
- CDG nào premature/duplicate?
- Step nào có user interaction → **GIỮ INLINE** (không delegate)
- Step nào dispatch Agent tool → **GIỮ orchestrator-side** (không script được)
- Bash heredoc nào lớn (>20 dòng) có thể move sang script?
- Template nào không được dùng đúng CORE-031?

### Bước 2: Phân tích (trình bày cho user TRƯỚC khi sửa)

Trình bày 3 thông tin cho user và **ĐỢI XÁC NHẬN** (hoặc user delegate AI choice):

1. **Mục tiêu CỐT LÕI của phase này** (1 câu)
2. **Bản đồ trách nhiệm** (bảng: việc / có cần ở phase này không / có thể defer/auto-resolve/gộp không / có user interaction không)
3. **Đề xuất 3 options** với trade-off rõ:
   - Option A: Quick wins (script delegation + compression) — low risk
   - Option B: Quick wins + step consolidation — medium risk (recommended cho most phases)
   - Option C: A + B + structural change (vd: tách thành sub-phases) — high risk

   Phải recommend 1 option với justification (sweet spot diminishing returns).

⚠️ **KHÔNG được tự ý chọn Option C và làm.** Wait for user approval. Nếu user delegate → chọn Option B.

### Bước 3: Setup branch (BẮT BUỘC trước khi sửa)

```bash
cd "d:/Working/MCV3"
git checkout master
git pull origin master    # đảm bảo có v10.6 (đã merge ở commit 0a90df23)
# Nếu CHƯA push lên origin (Phase 1+2+3+4 vẫn ở local): bỏ git pull
git checkout -b "feature/${PHASE}-optimize"
git tag "pre-${PHASE}-optimize"
```

Master đã có v10.6 base (Phase 1+2+3+4 merged). Branch mới xuất phát từ master clean.

### Bước 4: Implementation (theo waves)

**Wave 1 — Script delegation + step consolidation + behavior preserved** (~45-90 phút tùy phase complexity):
- Tạo scripts mới trong `.claude/scripts/wf-fix-bugs/` (reuse pattern từ 7 scripts Phase 4)
- Replace inline bash heredocs với script calls
- Step consolidation (gộp N steps làm cùng việc → 1 atomic block) — match pattern v10.6
- Step numbering giữ gaps (tránh churn cross-refs)
- Compress markdown boilerplate (-30% dòng/step)
- Delete dead code nếu có
- **GIỮ INLINE cho user interaction** (CDG/AskUser) — KHÔNG delegate
- **GIỮ orchestrator-side cho Agent tool calls** — KHÔNG delegate
- **PRESERVE semantics khi delegate execution** (vd Phase 4 Step 4.5a 6 check points)
- **VERIFY commit Wave 1** trước khi đi Wave 2

**Wave 2 — Cross-files update + version bump** (~15-20 phút):
- Update SKILL.md (version + header description + Phase Summary table row)
- Update `_contract.json` (version + description paragraph)
- Update `CHANGELOG.md` (entry mới ở top)
- Verify schema-sync ngay sau

### Bước 5: Verification (BẮT BUỘC trước mỗi commit)

```bash
# 1. Schema sync
bash .claude/scripts/validate-schema-sync.sh wf-fix-bugs

# 2. JSON validity
jq '.' .claude/skills/workflow/wf-fix-bugs/_contract.json > /dev/null && echo "JSON OK"

# 3. Smoke test scripts mới trên synthetic SESSION_DIR
SESSION_DIR=/tmp/wf-fix-bugs-test/sessions/test-XX
mkdir -p "$SESSION_DIR/phase{N}-{name}"
# ... export required env vars ...
bash .claude/scripts/wf-fix-bugs/<new-script>.sh

# 4. POST-GATE T1-T4 simulation
for f in <output files>; do
  test -s "$SESSION_DIR/phase{N}/$f" && echo "T1 OK: $f"
done
jq -e '<required structure>' <output>.json && echo "T2/T3 OK"
grep -q '<cross-ref token>' <report>.md && echo "T4 OK"

# 5. No leftover placeholders sau template populate
grep -E '\[[A-Z_]+\]|\{\{[A-Z_]+\}\}' "$SESSION_DIR/phase{N}/<report>.md" && echo "FAIL" || echo "OK"

# 6. Final metrics
wc -l ".claude/skills/workflow/wf-fix-bugs/procedures/${PHASE}.md"

# 7. Cross-file consistency
grep -c "<new-script>\.sh" .claude/skills/workflow/wf-fix-bugs/SKILL.md
grep -c "<new-script>\.sh" CHANGELOG.md

# 8. Version consistency
grep -E "^version" .claude/skills/workflow/wf-fix-bugs/SKILL.md
jq -r '.version' .claude/skills/workflow/wf-fix-bugs/_contract.json
```

### Bước 6: Documentation update (CORE-024 — traceability)

Mỗi Wave commit PHẢI update (nếu Wave touches cross-files):
- `CHANGELOG.md` — thêm entry `[wf-fix-bugs v10.X.0] — 2026-MM-DD`
- `SKILL.md` — version bump + Phase Summary table updated (cập nhật `last_updated`)
- `_contract.json` — version bump + description updated (mô tả changes phase này)
- `_shared.md` — nếu có pattern mới hoặc thay đổi shared section
- Step Dependency Chain trong phase file
- OUTPUT section trong phase file (in-memory state changes)

### Bước 7: Merge plan (BẮT BUỘC trình bày trước khi merge)

Sau khi commit 2 waves xong, **trình bày Merge Plan** cho user với 2 phương án:

**Phương án A — Merge ngay** (giống Phase 1+2+3+4 pattern):
```bash
git checkout master
git merge --no-ff feature/${PHASE}-optimize -m "Merge feature/${PHASE}-optimize: wf-fix-bugs v10.X.0 — Phase N optimization"
git branch -d feature/${PHASE}-optimize
# KHÔNG push lên origin (giữ chờ user)
```

**Phương án B — Giữ branch, batch sau Phase 7** (chained branches).

Khuyến nghị: Phương án A (isolated rollback per phase).

---

## Acceptance criteria per phase

| Tiêu chí | Threshold | Cách verify |
|----------|-----------|-------------|
| Procedure file tokens | <12K (target ~5-10K) | `wc -c $file / 4` |
| Procedure file lines | <1100 (target ~400-900) | `wc -l $file` |
| Steps count | Giảm ≥20% (vd: 15 → 12 hoặc tốt hơn) | `grep -c "^### Step"` |
| Inline bash heredocs >20 dòng | Tối đa 5 | `awk '/^\`\`\`/{...}'` size check |
| CDG questions ở phase | Justified by data có sẵn ở phase đó | Đọc cross-ref Phase N→N+1 |
| Schema sync | PASS 0 errors | `validate-schema-sync.sh wf-fix-bugs` |
| Cross-skill artifact contract | Unchanged hoặc bump schema version | Check `_contract.json` |
| Sessions đang dở | Vẫn `--resume` được | State file schemas KHÔNG breaking change |

---

## Phases & strategy đề xuất sơ bộ

> Đây là **gợi ý**, AI phải verify qua đọc file trước khi confirm.

### Phase 5 (Triage) — Priority HIGH ⚠️ (NEXT ⭐)
- **Nhiều steps nhất pipeline (15 steps)**, 1039 dòng, ~10.73K tokens, 64 code blocks
- Agent delegation pattern: spawn `wf-fix-triage` (Phase 5 delegate)
- **CDG Pre-Execute Handoff** là legit CDG, **KHÔNG defer**
- Step 5.12 bug-dashboard generate có thể reuse `_shared.md §19` pattern (giống Phase 1 Step 1.22)
- **Khả năng:**
  - Gộp Step 5.4 (CORE-029 Spot-Check) + 5.5 (Process Integrity PI1-PI5) + 5.6 (Evaluate Violations) → 1 atomic `validate-and-triage.sh`
  - Step 5.11 (Coverage Report) + 5.12 (Bug Dashboard) + 5.13 (Phase Report) đều là "generate report" — có thể gộp 1 script `generate-phase5-reports.sh`
  - Spawn `wf-fix-triage` agent — phần này không script được (giữ orchestrator-side như Step 4.5 Phase 4 v10.6)
- ⚠️ **GIỮ INLINE CDG Pre-Execute Handoff** (user ACCEPT/REJECT)
- ⚠️ **GIỮ orchestrator-side spawn wf-fix-triage** (Agent tool call, không script)
- Expected metrics target: 15 → ~10-12 steps, ~10.73K → ~5-6K tokens

### Phase 6 (Execute) — Priority MEDIUM
- 968 dòng, 11 steps, 44 code blocks, ~10.81K tokens, agent delegation pattern (spawn `wf-fix-execute`)
- Step "CI-ROUTE impact analysis" có thể gộp với agent prompt
- **Khả năng:** Tạo `prepare-execute-context.sh` cho Steps 6.3 + 6.4
- Step "POST-GATE T1-T4 validate fix-report + docs-sync-report" giữ inline (hoặc delegate `validate-execute-outputs.sh`)
- Expected target: 11 → ~7 steps, ~10.81K → ~5K tokens

### Phase 7 (Verify) — Priority MEDIUM
- **Dài nhất (1186 dòng)**, 14 steps, 46 code blocks, ~11.96K tokens (gần threshold)
- CQG-1 numeric + CQG-2 browser/integration là legit gates, **KHÔNG defer**
- **Khả năng:**
  - Tạo `generate-summaries.sh` cho 3 output files (orchestrator-summary, fix-impact, phase-summary)
  - Step 7.5 (Mobile Gate) + 7.5b (Finalize Dashboard) — có thể gộp
- ⚠️ CQG-1/CQG-2 giữ inline (user-facing gate, kết quả critical)
- Expected target: 14 → ~9 steps, ~11.96K → ~5.5K tokens

### _shared.md — Defer cuối cùng
- 1013 dòng, 52 code blocks, ~12.16K tokens
- Chỉ update khi có pattern mới từ phases (vd: §19 đã có sẵn, có thể bổ sung §21 cho lane dispatch pattern v10.x, §22 cho "atomic-call wrapper" pattern của v10.4/v10.5/v10.6)
- **KHÔNG động §15 Lane Agent Prompt (v10.2 canonical)**
- Mục tiêu: KHÔNG bắt buộc giảm tokens, chỉ document pattern mới + cleanup nếu có deadcontent

---

## Quy tắc bảo toàn (BHV-003 — Surgical Changes)

❌ **KHÔNG làm:**
- Đổi tên agent (`subagent_type`) đã có trong SKILL.md
- Đổi output paths đã có trong `_contract.json` (CORE-007)
- Đổi schema của artifact cross-skill (vd: `fix-impact-v1`) — chỉ bump version nếu cần
- Refactor `_shared.md §15` (Lane Agent Prompt — v10.2 critical guard)
- Refactor `templates/phase4-find-bugs/lane-agent-prompt.md` (v10.2 canonical)
- Delete CDG gates có data thật (vd: Phase 5 CDG Pre-Execute, Phase 7 CQG-1/CQG-2)
- Delegate user interaction sang script (CDG-11 Workload Gate Phase 3 v10.5 + CDG E090/E090b Phase 4 v10.6 đã chứng minh — phải GIỮ INLINE)
- Delegate Agent tool calls sang script (Step 4.5 Phase 4 v10.6 chứng minh — phải GIỮ orchestrator-side)
- Skip phase reports (CORE-028 — tiếng Việt ≤15 dòng cho mỗi phase)
- Phá vỡ pipeline state schema (Phase N+1 đọc field từ Phase N)
- Trộn pre-existing bug fix vào commit optimize (giống cách Phase 3 v10.5 defer Python CLI bug)

✅ **PHẢI làm:**
- Mỗi Wave 1 commit riêng, Wave 2 commit riêng (rollback-able)
- Version bump SKILL.md + _contract.json mỗi major change
- Update CHANGELOG.md per release
- Verify cross-file consistency (SKILL.md ↔ _contract.json ↔ procedure files ↔ scripts ↔ CHANGELOG)
- Test trên synthetic SESSION_DIR (như Phase 1+2+3+4 đã làm) — không cần dự án thật cho structural changes
- Step numbering giữ gaps khi gộp steps (vd: Phase 4 v10.6 gộp 4.2+4.3 → giữ 4.2, gap 4.3)
- Document pre-existing bugs phát hiện trong Discovery → CHANGELOG "DEFER" section (không fix trong scope)
- Cross-platform CRLF defensive: `tr -d '\r'` khi parse JSON Windows từ heredoc tests

---

## Rollback plan

```bash
# Nếu Wave 1 fail
git reset --hard pre-${PHASE}-optimize

# Nếu Wave 2 fail (Wave 1 đã commit)
git reset --hard HEAD~1   # rollback Wave 2 only

# Nếu cần discard toàn bộ branch
git checkout master
git branch -D feature/${PHASE}-optimize
git tag -d pre-${PHASE}-optimize

# Nếu đã merge vào master và cần rollback hoàn toàn
git reset --hard pre-${PHASE}-optimize
# (cảnh báo: chỉ làm khi chưa push lên origin)
```

---

## Deliverable kỳ vọng (per phase)

1. **Branch** `feature/${PHASE}-optimize` với 2 commits (Wave 1 + Wave 2)
2. **Tag** `pre-${PHASE}-optimize` (rollback point)
3. **CHANGELOG entry** `[wf-fix-bugs v10.X.0]` với metrics before/after
4. **Verification log** (schema-sync PASS, scripts smoke test, wc -l final)
5. **Trình bày user merge plan** giống Phase 1+2+3+4 — KHÔNG tự push lên origin (hoặc auto-merge nếu user delegate)

---

## Khởi đầu phiên mới (Phase 5 — pipeline order)

User đã chọn **pipeline order** (Option A từ phiên trước). Phase tiếp theo là **Phase 5 Triage**.
Phase 4 đã merged vào master — branch Phase 5 xuất phát từ master clean.

**Bước đầu phiên:**

1. **Verify master state** (1 command):
   ```bash
   cd "d:/Working/MCV3" && git log --oneline -12
   # Phải thấy 0a90df23 (Merge Phase 4 v10.6.0) ở top
   ```

2. **Đọc memory entry để biết trạng thái + lessons learned:**
   ```bash
   cat "C:/Users/Vu Minh Tu/.claude/projects/d--Working-MCV3/memory/project_wf_fix_bugs_phase2_7_optimize.md"
   ```

3. **Đọc 10 files bắt buộc** (mục "Bắt buộc đọc trước" — phase1-init.md + phase2-scan.md + phase3-plan.md + phase4-find-bugs.md là 4 reference implementations chính)

4. **Đọc 7 reference scripts mới Phase 4 v10.6** (`setup-lanes.sh`, `create-lane-dirs.sh`, `verify-lane-prompt.sh`, `monitor-lanes.sh`, `validate-lane-outputs.sh`, `generate-phase4-report.sh`, `finalize-phase4.sh`) để hiểu pattern multi-script delegation

5. **Thực hiện Bước 1 (Discovery) cho Phase 5** — KHÔNG nhảy vào code ngay
   - Đọc full `procedures/phase5-triage.md` (1039 dòng, 15 steps — nhiều nhất)
   - Lập bản đồ trách nhiệm
   - Identify:
     - **GIỮ INLINE:** CDG Pre-Execute Handoff (user ACCEPT/REJECT), CDG Safety Check (CORE-020)
     - **GIỮ orchestrator-side:** Spawn wf-fix-triage agent (Phase 5 delegate, Agent tool call)
     - Logical groups có thể gộp:
       - Step 5.4 (CORE-029 Spot-Check) + 5.5 (Process Integrity PI1-PI5) + 5.6 (Evaluate Violations) — validation block
       - Step 5.11 (Coverage Report) + 5.12 (Bug Dashboard) + 5.13 (Phase Report) — report generation block
       - Steps đầu (5.1 PRE-GATE + 5.2 TRACE START) — init block
       - Steps cuối (Update fix-status + TRACE COMPLETE) — finalize block
     - N=0 healthy jump (E005) logic: keep inline (early-exit gate)

6. **Trình bày Bước 2 (Phân tích + 3 Options A/B/C)** — đợi user approve

7. **Sau khi approve** → Bước 3 (setup `feature/phase5-triage-optimize` từ master) → Wave 1 → Verify → Commit → Wave 2 → Verify → Commit → Merge plan

---

## Reference commits (Phase 1-4 — cả 4 đã merged vào master)

```
# Phase 1 v10.3 (merged 2026-05-16)
6325d81d refactor(wf-fix-bugs): Wave 1 — Phase 1 procedure compression (-58% tokens)
a291c56b feat(wf-fix-bugs): Wave 2 — just-in-time CDG negotiation (v10.3.0)
378d56d7 Merge feature/phase1-optimize: wf-fix-bugs v10.3.0

# Phase 2 v10.4 (merged 2026-05-16)
6d5f285e refactor(wf-fix-bugs): Wave 1 — Phase 2 procedure compression (-58% tokens)
79ed6f3c feat(wf-fix-bugs): Wave 2 — Phase 2 step consolidation (v10.4.0)
9af23c8e Merge feature/phase2-scan-optimize: wf-fix-bugs v10.4.0 — Phase 2 optimization

# Phase 3 v10.5 (merged 2026-05-16)
9c9787bc refactor(wf-fix-bugs): Wave 1 — Phase 3 procedure compression (-56% lines)
b7c65db6 feat(wf-fix-bugs): Wave 2 — Phase 3 cross-files update (v10.5.0)
8d0882d6 Merge feature/phase3-plan-optimize: wf-fix-bugs v10.5.0 — Phase 3 optimization

# Phase 4 v10.6 (merged 2026-05-16)
76aaf312 refactor(wf-fix-bugs): Wave 1 — Phase 4 procedure compression (-33% lines)
02bd3bf9 feat(wf-fix-bugs): Wave 2 — Phase 4 cross-files update (v10.6.0)
0a90df23 Merge feature/phase4-find-bugs-optimize: wf-fix-bugs v10.6.0 — Phase 4 optimization
```

Xem `git show <hash>` để học cách Wave 1 và Wave 2 được structure. Đặc biệt cho Phase 5:

```bash
# Pattern multi-script delegation (Phase 4 v10.6 — gần Phase 5 nhất về complexity + agent dispatch)
git show 76aaf312 -- .claude/scripts/wf-fix-bugs/setup-lanes.sh
git show 76aaf312 -- .claude/scripts/wf-fix-bugs/finalize-phase4.sh
git show 76aaf312 -- .claude/scripts/wf-fix-bugs/validate-lane-outputs.sh

# Pattern step consolidation + GIỮ INLINE cho CDG + GIỮ orchestrator-side cho Agent
git show 76aaf312 -- .claude/skills/workflow/wf-fix-bugs/procedures/phase4-find-bugs.md

# Pattern cross-files update Wave 2
git show 02bd3bf9 -- .claude/skills/workflow/wf-fix-bugs/SKILL.md
git show 02bd3bf9 -- .claude/skills/workflow/wf-fix-bugs/_contract.json
git show 02bd3bf9 -- CHANGELOG.md
```

---

## Memory bank update cho phiên mới

Trong phiên mới, sau khi đọc xong CLAUDE.md + rules, **CẬP NHẬT** memory entry (không tạo mới):

- **Project memory `project_wf_fix_bugs_phase2_7_optimize.md`:** Update Progress bảng với Phase 5 trạng thái (in_progress → completed)
- **Feedback memory:** Lưu thêm pattern mới phát hiện ở Phase 5 (vd: nếu spawn agent có thể pre-stage qua script + Agent tool call sau)

---

**END OF PROMPT — Paste toàn bộ nội dung trên vào phiên Claude Code mới.**
