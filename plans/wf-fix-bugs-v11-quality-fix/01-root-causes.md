# Root Causes — Diagnose chi tiết với evidence

> Tài liệu này lưu lại điều tra ngày 2026-05-17 trên session `2026-05-16-module-settings-01` của EUREKA-2026. Mỗi root cause có file/line evidence + reproduction path.

## Evidence Session

```
Path: D:\Working\EUREKA-2026\.mc-data\work\wf-fix-bugs\sessions\2026-05-16-module-settings-01
Profile: exhaustive
Scope: module=settings
Total signals: 119 → Issues: 119
Fixed: 45 (per fix-status.json) / 35 (per orchestrator-summary.md) / 39 (per Phase6-report narrative)
Deferred: 62 (52%)
Pipeline status reported: DONE
```

---

## R1 — CQG-1 Leniency

**Triệu chứng**: Phase7-report.md có dòng "CQG-1 PASS (deviation fix-log.json aggregate format - substance-based CQG evaluation%)". Thực tế first-run fix 19/104 planned → deviation phải > 80%, không thể PASS với threshold 5%.

**Evidence — file/line**:
- `.claude/scripts/wf-fix-bugs/cqg1-numeric.sh:65-75` — `extract_num()` dùng `grep -oiE` với pattern alternation, lấy `head -1`
  ```bash
  extract_num() {
    local f="$1" pat="$2" val
    val=$(grep -oiE "$pat" "$f" 2>/dev/null | head -1 | grep -oE '[0-9]+' | head -1)
    echo "${val:-0}"
  }
  ```
- Line 72-74: extract từ `fix-plan.md`:
  ```bash
  EXPECTED_FIXED=$(extract_num "$FIX_PLAN" "fixed_count[: ]*[0-9]+|expected.*fix.*[0-9]+|sẽ sửa[: ]*[0-9]+|\*\*fixed:\*\* *[0-9]+|fix.*count[: ]*[0-9]+")
  ```
- Line 103-105: extract từ `fix-report.md` — TƯƠNG TỰ regex alternation

**Root cause**: Regex multi-pattern OR + `head -1` không deterministic. Trong user's fix-plan.md có hàng trăm dòng `| CRITICAL | ISS-... | fix | ...`. Regex `fix.*count[: ]*[0-9]+` có thể match dòng nào đó có "fix" gần một số → trả số sai.

**Reproduction**:
```bash
cd "D:/Working/EUREKA-2026"
SESSION_DIR=".mc-data/work/wf-fix-bugs/sessions/2026-05-16-module-settings-01" \
  bash .claude/scripts/wf-fix-bugs/cqg1-numeric.sh
# Expected: deviation > 80% → FAIL
# Actual: deviation = 0 → PASS (wrong)
```

**Lưu ý phụ**: line 117-118 có soft logic: `if exp=0 && act <= 2 → deviation=0`. Edge case nhưng không phải cause chính.

---

## R2 — Aggregation Inconsistency

**Triệu chứng**:
| Source | fixed value |
|--------|-------------|
| `fix-status.json` | 45 |
| `orchestrator-summary.md` "Lỗi đã sửa" | 35 |
| `Phase6-report.md` narrative | "19 + 10 + 10 = 39" |

**Evidence — flow truy ngược**:

1. **orchestrator-summary giá trị 35**: Template `orchestrator-summary.md:15` có `[TOTAL_FIXED]`. Script `generate-phase7-reports.sh:201` thay placeholder bằng `$FIXED_COUNT` env var.
2. **$FIXED_COUNT đến từ đâu**: Set ở `phase6-execute/E-validate-dashboard.md:57`:
   ```bash
   FIXED_COUNT=$(echo "$PHASE6_S7" | jq -r '.fixed_count')
   ```
   `$PHASE6_S7` là output của `verify-execute-outputs.sh`.
3. **`verify-execute-outputs.sh:99-104`** dùng regex MD extract từ fix-report.md:
   ```bash
   FIXED_COUNT=$(grep -oiE 'fixed[:= ]*[0-9]+|...' "$FIX_REPORT" | head -1 | grep -oE '[0-9]+' | head -1 || echo 0)
   ```
   → Pick first occurrence "Fixed: 19" → return 19. Hoặc nếu có nhiều re-run, pick cái xuất hiện đầu.
4. **fix-status.json giá trị 45**: Orchestrator (Claude itself) đã update `fix-status.json.fixed` thủ công sau re-run dựa trên narrative. KHÔNG qua script.
5. **Narrative "19+10+10=39"**: Agent (wf-fix-execute) viết theo cách tự thuật mỗi run, KHÔNG tổng hợp lại.

**Root cause**: 3 nguồn tính độc lập, không có SSOT. Khi re-run, mỗi nguồn update khác nhau.

**Note v10.11 fast-path**: `cqg1-numeric.sh:82-99` đã prefer `fix-execution-result.json` schema v2 (structured). `verify-execute-outputs.sh:206-335` đã write file này từ fix-log.json. Vậy infrastructure SSOT đã có 70%, chỉ cần:
- (a) `verify-execute-outputs.sh` dùng kết quả aggregate (line 233-253 ISSUES_JSON) để set FIXED_COUNT, thay vì regex MD
- (b) `generate-phase7-reports.sh` đọc trực tiếp từ fix-execution-result.json thay vì env var

---

## R3 — Max-Retry 3 Không Enforced

**Triệu chứng**: User mong "skill tự fix nhiều lần" nhưng Phase 6 chỉ chạy first-run + 1 re-run rồi exit.

**Evidence — file/line**:
- `phase6-execute/E-validate-dashboard.md:36-54`:
  ```bash
  RETRY_FILE="$SESSION_DIR/phase6-execute/.retry-count-step-6.5"
  RETRY_COUNT=$(cat "$RETRY_FILE" 2>/dev/null || echo 0)
  PHASE6_S7=$(bash .claude/scripts/wf-fix-bugs/verify-execute-outputs.sh) || RC=$?
  if [ "${RC:-0}" -eq 4 ]; then
    if [ "$RETRY_COUNT" -ge 1 ]; then
      echo "E060: POST-GATE FAIL sau retry — auto-fix budget exhausted (CORE-034)"
      exit 1
    fi
    echo "$((RETRY_COUNT + 1))" > "$RETRY_FILE"
  fi
  ```
- **Hardcode max 1 retry** (`>= 1`), không phải 3 như CORE-034 spec.

**Root cause**: Step 6.5 retry chỉ dùng cho POST-GATE T1-T4 FAIL (file missing/invalid sau agent spawn), KHÔNG dùng cho "tìm thêm fixable bugs để thử fix lại". Không có loop "execute → check deferred → re-execute deferred".

**CORE-034 vs Step 6.5 conflict**: Rule nói "max 3 retries / phase (tất cả tier gộp chung budget)". Implementation Step 6.5 chỉ enforce 1 retry. Đây là KHE HỞ.

---

## R4 — Quick-Fix Items Bị Defer

**Triệu chứng**: User session có 4 entity validation guards với note "Batch fix entity validation guards ≤5 phút — defense-in-depth" — nhưng bị defer.

**Evidence — flow**:

1. **wf-fix-triage SKILL.md:206-227** có **Anti-Invention Rule** rất rõ ràng:
   ```
   - `--profile=exhaustive`: TAT CA severity có fixability=AUTO_FIX/AGENT_FIX phai vao batches.
     Khong "defer to backlog".
   ```
   POST-GATE T6 enforce.
2. **wf-fix-execute** SKILL.md mô tả: "Phase 3 (Fix): CRITICAL → HIGH (PARALLEL) → MEDIUM+LOW. Source-aware routing"
3. **Agent prompt cho wf-fix-execute** (đọc trong `phase6-execute/D-spawn-execute.md:50-88`) **KHÔNG** có dòng nào nói "FORBIDDEN to defer items với fixability=AUTO_FIX/AGENT_FIX trong fix-report"
4. → Agent có quyền tự quyết: viết `result="deferred"` vào fix-log.json + ghi narrative "Deferred for sprint planning" vào fix-report.md
5. Không có post-hoc verifier cross-check fix-log result vs fixability của issue

**Root cause**: Decision authority bị split:
- Triage classify fixability=AUTO_FIX → mong execute
- Execute agent vẫn được defer mà không có sanction

**Fix path**: Cần (a) update agent prompt để cấm defer items có fixability fix, (b) script verify-defer-reasons.sh check post-hoc → block POST-GATE nếu vi phạm.

---

## R5 — Cross-Module Không Auto-Spawn

**Triệu chứng**: User session deferred 8 cross-module runtime issues với action "Mở session wf-fix-bugs --scope=cross-module". Skill viết text này vào file `deferred-issues-analysis.md` (file thủ công, không phải template) nhưng không có cơ chế CDG hỏi user.

**Evidence — file**:
- `deferred-issues-analysis.md` (do orchestrator tự tạo trong session — không có trong template list)
- Không có CDG E091/E092/E093/... nào trong Phase 5 hoặc Phase 6 hiện tại dành cho cross-scope

**Root cause**: Skill không có decision point chính thức để escalate cross-scope. User phải tự đọc deferred-issues-analysis.md rồi chạy lệnh mới.

---

## R6 — False Positive 8 i18n Keys

**Triệu chứng**: 8 issues HIGH với reason "translation key giống password pattern". User confirm false positive sau khi đọc lại — đều là JSON keys trong `apps/erp-web/src/messages/`, `apps/mobile-customer/src/i18n/locales/`, `apps/web-customer/messages/`.

**Evidence**:
- 8 issue IDs: ISS-20260516-021/030/048/049/051/079/082/099
- Tất cả ở file path matching `**/messages/**` hoặc `**/i18n/**` hoặc `**/locales/**`
- Lane: QD3 security (hardcoded_secret pattern)

**Root cause**: Lane probe `wf-fix-security` không có exclusion list cho i18n/translation paths. Pattern matching đúng nhưng context sai → tạo noise.

**Tác động**: Tốn iteration/budget xử lý 8 false positives → giảm capacity fix real bugs.

---

## R7 — Path Corruption Windows

**Triệu chứng**: `safety-check.json` chứa paths có byte rác `\357\200\215`:
```
phase4-find-bugs/lanes/QD1-functional\357\200\215/lane-status.json
phase4-find-bugs/lanes/QD10-integration\357\200\215/...
```

**Evidence**:
- Bytes `\357\200\215` = `0xEF 0x80 0x8D` = U+F00D (Private Use Area, often "wrench" icon in Nerd Fonts)
- Verify lane dir thực tế CLEAN: `xxd` của tên dir chỉ thấy `5144 312d 6675 6e63 7469 6f6e 616c 0a` (= "QD1-functional\n")
- Safety-check pass: `"all_pass": true, "blockers": []`

**Root cause**: Script safety-check (chưa locate file chính xác — Phase 5 Step 5.10) parse output từ `git status` hoặc `find` và bị nhiễm PUA char khi serialize. Có thể là encoding stdout từ Git on Windows.

**Tác động**: Cosmetic only — không break pipeline, nhưng làm reports trông unprofessional và khó debug.

---

## Cumulative Impact Analysis

| Root Cause | Hậu quả nghiệp vụ |
|-----------|-------------------|
| R1 | User tin tưởng "PASS" sai → release với bugs chưa fix |
| R2 | User không biết số liệu nào đúng → mất niềm tin vào skill |
| R3 | Skill exit sớm → 50%+ bugs còn treo |
| R4 | Items quick-fix lẽ ra fix được 5 phút → user phải làm thủ công |
| R5 | Cross-module bugs ngủ quên trong file không ai đọc |
| R6 | False positives ăn iteration budget → real bugs bị bỏ qua |
| R7 | Reports trông amateur → giảm credibility |

**Cumulative**: 52% defer rate, 38% real fix rate trên một session "DONE". Đây là **defect cấp v11.0.0**.
