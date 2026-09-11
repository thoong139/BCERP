# Phase 7: Generate Preflight Report

> **Protocol:** Xem `.claude/skills/protocols/` — POST-GATE T1→T4 (Protocol 10)
> **Shared:** Xem `procedures/_shared.md` — Verdict Calculation, NULL Redistribution

Tổng hợp tất cả issues, tính `overall_score`, xác định verdict, ghi 3 output files.

---

## PRE-GATE

```
test -n "$REGISTRY_ISSUES" && test -n "$DOC_ISSUES"
# $SYNC_ISSUES và $QUALITY_ISSUES có thể rỗng nếu skip hợp lệ (PRE-GATE Phase 4/5 không đạt)
```

`$SCORES` (hoặc `$POST_FIX_SCORES` nếu `--fix` đã apply) có đủ values hoặc `null`.

## 📤 OUTPUT

| File | Đường dẫn |
|------|-----------|
| Preflight report | `$SESSION_DIR/preflight-report.md` |
| Session status | `$SESSION_DIR/preflight-status.json` |
| Preflight impact artifact | `$SESSION_DIR/preflight-impact.json` |
| Phase summary | `$SESSION_DIR/phase-summary.md` |
| History log (flat, append-only) | `.mc-data/work/wf-preflight/preflight-history.md` |
| Sessions index | `.mc-data/work/wf-preflight/_index/sessions.jsonl` |

---

## Verdict Calculation

```
Weighted scores:
  registry_score  × 0.20
  docs_score      × 0.25
  sync_score      × 0.30
  quality_score   × 0.25

test_score là BONUS — KHÔNG đưa vào overall_score. Hiển thị riêng.

THỨ TỰ ĐÁNH GIÁ (priority order — dừng khi match):
  1. FAIL   ← overall_score < 60% HOẶC có bất kỳ CRITICAL issue nào
  2. WARN   ← overall_score 60-79% HOẶC có HIGH severity issues
              HOẶC test_score < 50% (khi $HAS_RUN_TESTS_FLAG = true và test_score không null)
  3. PASS   ← overall_score >= 80% VÀ không CRITICAL VÀ không HIGH
              VÀ (test_score >= 50% hoặc test_score null hoặc --run-tests không được dùng)

Tie-breaking: FAIL > WARN > PASS — WARN luôn takes precedence over PASS.
```

**NULL redistribution** (khi phase bị skip): xem `_shared.md` §NULL Redistribution Algorithm.

**Coverage disclaimers (từ Phase 5b flags):**
```
IF $COVERAGE_DISCLAIMER = "low_coverage":
  → Thêm vào report: "⚠️ Độ tin cậy thấp: chỉ [N]/4 dimensions được đo. Chạy /wf-preflight với đầy đủ tooling để có verdict chính xác hơn."

IF $CODE_NOT_CHECKED = true:
  → Thêm vào report: "⚠️ Code chưa được kiểm tra (không tìm thấy src/ hoặc tooling không khả dụng). PASS/WARN chỉ phản ánh registry và docs."
```

**Ví dụ 1 — `quality_score = null` (E005: no tooling):**
```
remaining = 0.20 + 0.25 + 0.30 = 0.75
registry_adj = 0.20/0.75 = 0.267
docs_adj     = 0.25/0.75 = 0.333
sync_adj     = 0.30/0.75 = 0.400
overall = registry×0.267 + docs×0.333 + sync×0.400
```

**Ví dụ 2 — `sync_score = null + quality_score = null`:**
```
remaining = 0.20 + 0.25 = 0.45
overall = registry×0.444 + docs×0.556
```

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 7.1 | Tính `$OVERALL_SCORE` (dùng `$POST_FIX_SCORES` nếu có, ngược lại `$SCORES`) + xác định `$VERDICT` theo priority order ở trên | Verdict set với lý do rõ ràng |
| 7.1a | Nếu `$VERDICT = WARN`: ghi `$WARN_REASON` = danh sách lý do cụ thể (ví dụ: "HIGH lint errors (3)", "test_score 42% < 50%", "overall_score 71%") — dùng trong report để user hiểu tại sao WARN mặc dù score có thể cao | WARN_REASON set |
| 7.2 | Tổng hợp tất cả issues: CRITICAL → HIGH → MEDIUM → LOW | Issues sorted |
| 7.3 | Kiểm tra template existence: `test -f templates/preflight-report.md`. Nếu không tồn tại → STOP với E014-variant: "Template preflight-report.md không tìm thấy. Cài đặt lại DEVKIT." | Template exists |
| 7.3a | READ `templates/preflight-report.md` → POPULATE với data từ Phases 2-5b (scores, issues, verdict, $WARN_REASON, fixes, disclaimers từ $COVERAGE_DISCLAIMER/$CODE_NOT_CHECKED) → WRITE `$SESSION_DIR/preflight-report.md` | `test -s $SESSION_DIR/preflight-report.md` |
| 7.4 | READ `templates/preflight-status.json` → POPULATE toàn bộ schema v3: `session_id: "$SESSION_ID"`, `status: "completed"`, `verdict`, `overall_score`, `scores`, `issues`, `phases`, `metrics`, `checkpoint`, `audit_chain` → WRITE `$SESSION_DIR/preflight-status.json` | `test -s $SESSION_DIR/preflight-status.json` |
| 7.4a | Nếu `--fix` đã apply VÀ `$POST_FIX_SCORES` khác `$PRE_FIX_SCORES`: thêm section "Auto-fix Results" vào report với delta scores. **Thêm NOTE:** "docs_score và quality_score chưa được re-evaluate sau fix — chạy lại /wf-preflight để có report đầy đủ nếu --fix đã thay đổi docs hoặc code quality." | Delta noted + disclaimer present |
| 7.5 | IF `preflight-history.md` chưa tồn tại: READ `templates/preflight-history.md` → POPULATE header → WRITE. ELSE: APPEND dòng mới mà không đọc toàn bộ file (tránh memory issue với history lớn): `\| YYYY-MM-DD \| $SESSION_ID \| scope=[scope] \| PASS/WARN/FAIL \| X% \| ... \| YES/NO \|` | File exists + appended |
| 7.6 | Output report summary ra console | User thấy verdict |
| 7.7 | **Action recommendation:** Nếu `$VERDICT == FAIL` hoặc `WARN`: hiển thị lý do cụ thể ($WARN_REASON) + "**Khuyến nghị:** Chạy `/wf-fix-bugs --scope=[scope]` để tự động sửa [N] issues (CRITICAL: [count], HIGH: [count])." Nếu PASS: "Tiếp tục: `/wf-verify-sync`" + thêm NOTE: "✅ PASS xác nhận tính nhất quán cấu trúc. Chạy `/wf-verify-sync` để verify end-to-end traceability trước khi deploy." | Recommendation shown + wf-verify-sync note |
| 7.8 | **Phase Summary (CORE-028):** READ `templates/phase-summary.md` → POPULATE với verdict, scores, issues tóm tắt (tiếng Việt, viết cho non-specialist) → WRITE `$SESSION_DIR/phase-summary.md` | `test -s $SESSION_DIR/phase-summary.md` |
| 7.E | **Build preflight-impact.json (Sprint 3):** `bash .claude/scripts/wf-preflight/pf-impact-build.sh "$SESSION_DIR"`. Parse `{status:"built", verdict, total_issues}`. Nếu build fail → LOG WARN, tiếp tục (không block POST-GATE). | `test -f $SESSION_DIR/preflight-impact.json` |
| 7.F | **POST-GATE check report:** `bash .claude/scripts/wf-preflight/pf-postgate-check.sh "$SESSION_DIR/preflight-report.md" md 50 "Verdict" "Scores" "Issues" "Recommendations"`. Parse `{pass, results[]}`. Nếu FAIL → retry-auto-fix → escalate sau 3 lần (CORE-012). | `{pass:true}` |
| 7.G | **JSONL index finalize:** Append completed entry: `{event:"completed",session_id,scope_type,scope_name,completed_at,verdict,overall_score,issues_critical,issues_high,issues_medium,fix_applied,tests_run,status:"completed"}`. `bash .claude/scripts/wf-preflight/pf-index-append.sh "$ENTRY"`. | Entry appended |
| 7.H | **Kill heartbeat daemon:** `kill $HEARTBEAT_PID 2>/dev/null \|\| true`. Tránh orphan background process. | — |
| 7.I | **Release session lock:** `bash .claude/scripts/wf-preflight/pf-release-lock.sh session "$SESSION_DIR"`. | `{status:"released"}` |
| 7.9 | **Execution Trace (CORE-026):** APPEND entry vào `.mc-data/work/_trace/session-log.json`: `{"skill":"wf-preflight","event":"COMPLETE","timestamp":"...","session_id":"$SESSION_ID","verdict":"[PASS/WARN/FAIL]","score":"[X%]"}`. Nếu file chưa tồn tại → tạo mới với JSON array wrapper. | File exists + valid JSON |

---

## Output Report Template

> **Template file:** `templates/preflight-report.md` — READ → POPULATE → WRITE. Không tự do tạo format.

**Quy tắc output (bắt buộc khi populate template):**

- **Emoji BẮT BUỘC:** LUÔN dùng ✅ (PASS), ⚠️ (WARN), ❌ (FAIL) cho verdict VÀ mỗi dòng Status trong bảng check. Không bỏ emoji — đây là visual cue quan trọng giúp user scan nhanh.
- **Tiếng Việt có dấu:** Tất cả nội dung report (trừ tên file, ID, keyword kỹ thuật) PHẢI viết tiếng Việt có dấu đầy đủ. Ví dụ: "Không có issue nào" (KHÔNG viết "Khong co issue nao").
- **Score hiển thị:** Luôn hiển thị score calculation rõ ràng (weighted formula) để user có thể verify.
- **Sections rỗng:** Nếu section không có data (vd: không có Critical issues, không có Auto-fixes), ghi "Không có" thay vì bỏ trống section.

---

## POST-GATE

Tiered validation (T1→T4, Protocol 10) — chạy via `pf-postgate-check.sh`:

```bash
# T1+T2+T3+T4: report (section headings required)
bash .claude/scripts/wf-preflight/pf-postgate-check.sh \
  "$SESSION_DIR/preflight-report.md" md 50 "Verdict" "Scores" "Issues" "Recommendations"

# T1+T2+T3: impact JSON valid
bash .claude/scripts/wf-preflight/pf-postgate-check.sh \
  "$SESSION_DIR/preflight-impact.json" json 1

# T1+T2: phase-summary non-empty (P2-2 fix)
bash .claude/scripts/wf-preflight/pf-postgate-check.sh \
  "$SESSION_DIR/phase-summary.md" md 30 "Kết quả"

# T1+T3: status JSON valid + verdict non-null
jq -e '.verdict != null' "$SESSION_DIR/preflight-status.json"
```

**Retry policy:** FAIL → auto-fix (up to 3 retries) → escalate sau 3 lần (CORE-012, E009).

**Levels:**
- **T1:** File existence — `test -f`
- **T2:** Non-empty — `test -s`
- **T3:** Format valid — `jq '.'` cho JSON; heading check cho Markdown
- **T4:** Required content — report có sections: Verdict, Scores, Issues, Recommendations

---

## Output

- `$SESSION_DIR/preflight-report.md` — Markdown report (session-scoped)
- `$SESSION_DIR/preflight-status.json` — Session status + metrics (v3 schema)
- `$SESSION_DIR/preflight-impact.json` — Cross-skill artifact (schema `preflight-impact-v1`)
- `$SESSION_DIR/phase-summary.md` — CORE-028 phase summary (tiếng Việt)
- `.mc-data/work/wf-preflight/preflight-history.md` — Append history log (flat, persistent)
- `.mc-data/work/wf-preflight/_index/sessions.jsonl` — Session index (2 entries per run)
- `.mc-data/work/_trace/session-log.json` — CORE-026 execution trace (append)

**Consumed by:**
- `/wf-fix-bugs` (primary consumer — đọc report để triage issues)
- `/wf-verify-sync` (context — REQ-ID sync status)
- `/wf-prepare-deployment` (final gate check)

**Consumer integration via preflight-impact.json:**
- `/wf-verify-sync --from-preflight[=SESSION_ID]` — Phase 0 load + audit_chain verify
- `/wf-prepare-deployment --from-preflight[=SESSION_ID]` — Go/No-Go gate nếu verdict=FAIL

**END of wf-preflight flow.**
