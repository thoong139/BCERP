# Phase 6: Output Report

> Tạo final report + CORE-028 phase summary + cập nhật index.json + close session.

> **Shared:** Xem `procedures/_shared.md` — CORE-026/028 Trace & Phase Summary.

---

## PRE-GATE

- Phase 5 đã PASSED (hoặc $DRY_RUN redirect từ Phase 4a)
- Tất cả checkpoints đã sync
- `$SESSION_DIR/change-status.json` phản ánh đầy đủ thay đổi

---

## INPUT

- `$SESSION_DIR/change-status.json` — metrics + phases summary
- `$SESSION_DIR/change-plan.md` — tasks executed
- `$SESSION_DIR/impact-report.md` — risk assessment
- `$SESSION_DIR/change-analysis.md` — analysis context

---

## OUTPUT

| File | Template | Condition |
|------|----------|-----------|
| `$SESSION_DIR/change-impact.json` | `templates/change-impact.json` | Always (S3 — schema `change-impact-v1`, cross-skill artifact) |
| `$SESSION_DIR/change-report.md` | `templates/change-report.md` | Always |
| `$SESSION_DIR/phase-summary.md` | `templates/phase-summary.md` (CORE-028 + CORE-031) | Always |
| `.mc-data/work/wf-manage-change/index.json` | — (update) | Always |
| `.mc-data/work/wf-manage-change/_index/sessions.jsonl` | — (append complete entry) | Always |
| `.mc-data/work/_trace/session-log.json` | — (append) | Always |
| `$SESSION_DIR/.session.lock` | — (DELETE) | Always (S2 cleanup) |

---

## Actions (theo thứ tự)

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 6.0.5 | **[S3] Build change-impact.json:** `bash .claude/scripts/wf-manage-change/mc-change-impact-build.sh --session-dir=$SESSION_DIR` — builder đọc `change-status.json` + `affected-artifacts.json` + registry checksum, tạo artifact `$SESSION_DIR/change-impact.json` (schema `change-impact-v1`) từ template `templates/change-impact.json`. Edge cases graceful: CLARIFY_REQ → `files_modified=[]`, `docs_modified=[]`; dry-run → `verify_evidence=null`, `regression_check=null`; backup không tồn tại → `audit_chain.checksum_pre=""`. | Bash | File `$SESSION_DIR/change-impact.json` tạo, `jq -e '."$schema" == "change-impact-v1"'` PASS |
| 6.0.5b | **[S3] Populate verify_evidence + regression_check:** Đọc `phase5` results từ `change-status.json` → patch `verify_evidence` (preflight_status, sync_rate, cross_validation_coverage) và `regression_check` (tests_passed/failed/total) vào `change-impact.json` bằng `jq` in-place. Skip nếu Phase 5 bị skip ($DRY_RUN) — giữ null values. Pattern: <br>`jq --argjson preflight "\"$PREFLIGHT_STATUS\"" --argjson sync_rate "$SYNC_RATE" --argjson coverage "$COVERAGE" '.verify_evidence = {preflight_status: $preflight, sync_rate: $sync_rate, cross_validation_coverage: $coverage}' $SESSION_DIR/change-impact.json > $SESSION_DIR/change-impact.json.tmp && mv $SESSION_DIR/change-impact.json.tmp $SESSION_DIR/change-impact.json` | Bash | `verify_evidence.preflight_status` non-null nếu Phase 5 ran, hoặc giữ null nếu dry-run |
| 6.1 | **Tạo change-report.md:** READ template `templates/change-report.md` → POPULATE change data (tất cả sections required) → WRITE `$SESSION_DIR/change-report.md` | Write | File created |
| 6.2 | **CORE-028 Phase Summary:** READ template `templates/phase-summary.md` → POPULATE 5 sections (Đã thay đổi gì? / Tại sao cần thay đổi? / Kết quả kiểm tra / Những file bị ảnh hưởng / Bước tiếp theo) bằng **tiếng Việt đơn giản cho non-specialist** (xem `_shared.md` §CORE-028) → WRITE `$SESSION_DIR/phase-summary.md` (CORE-031 compliant) | Write | File created |
| 6.3 | **Update index.json:** Set `sessions[$CHANGE_ID].status = "completed"`, `sessions[$CHANGE_ID].completed_at = NOW`. Nếu `active_session == $CHANGE_ID` → giữ hoặc clear tùy context | Read/Write | index updated |
| 6.3b | **[S2] Append sessions.jsonl complete entry:** `bash .claude/scripts/wf-manage-change/mc-index-append.sh --change-id=$CHANGE_ID --status=completed --summary="$USER_PROMPT" --change-type=$CHANGE_TYPE --risk-level=$RISK_LEVEL` — append entry mới vào `_index/sessions.jsonl` (immutable log — KHÔNG modify entry "in_progress" cũ). Dual-write với index.json. | Bash | sessions.jsonl có entry status=completed |
| 6.4 | **CORE-026 COMPLETE trace:** Append COMPLETE entry vào `.mc-data/work/_trace/session-log.json` | Write | Entry logged |
| 6.4b | **[S2] Cleanup heartbeat + release session lock:** ① `kill $HEARTBEAT_PID 2>/dev/null \|\| true` — dừng heartbeat daemon (background process từ Phase 0 Step 0.1 ③). ② `bash .claude/scripts/wf-manage-change/mc-release-lock.sh --type=session --id=$CHANGE_ID` — release session lock (xóa `$SESSION_DIR/.session.lock`). ③ Disable EXIT trap: `trap - EXIT` (đã cleanup explicit, tránh double-release từ trap). | Bash | `.session.lock` không tồn tại, heartbeat process đã kill |
| 6.5 | **Show Next Step Recommendation** (xem §Next Step Recommendation) | — | Displayed |

---

## Change Report Required Sections

`change-report.md` PHẢI chứa các headings sau (T3 validation):

- `## Summary`
- `## Changes Made`
  - Docs updated
  - Code updated
  - Tests updated
  - Registry updated (nếu có)
- `## Verification Results`
- `## Registry Updated`
- `## Next Steps`

Nội dung chi tiết: xem `templates/change-report.md`.

---

## Phase Summary — CORE-028

`phase-summary.md` viết bằng **tiếng Việt đơn giản**, dành cho người không chuyên.

**Nội dung bắt buộc (≤ 20 dòng):**

```markdown
# Tóm tắt thay đổi — $CHANGE_ID

## Đã thay đổi gì?
[Mô tả ngắn bằng ngôn ngữ nghiệp vụ — KHÔNG dùng thuật ngữ kỹ thuật]

## Tại sao cần thay đổi?
[Context từ user prompt ban đầu]

## Kết quả kiểm tra
- Preflight: [PASS/WARN/FAIL]
- Traceability: [sync_rate %]
- Cross-validation: [coverage %]

## Những file bị ảnh hưởng
- [N] tài liệu cập nhật
- [N] file code cập nhật
- [N] test cập nhật

## Bước tiếp theo
[Khuyến nghị cụ thể cho user]
```

---

## POST-GATE — Actions + T1→T4 (CORE-012)

### T1: File existence + lock cleanup

```bash
test -f $SESSION_DIR/change-impact.json                    # [S3] cross-skill artifact
test -f $SESSION_DIR/change-report.md
test -f $SESSION_DIR/phase-summary.md
test ! -f $SESSION_DIR/.session.lock                       # [S2] session lock đã release
test ! -f .mc-data/work/wf-manage-change/.locks/registry.lock  # [S2] registry lock đã release từ Phase 4a
grep -q "\"change_id\":\"$CHANGE_ID\"" .mc-data/work/wf-manage-change/_index/sessions.jsonl
grep -q "\"status\":\"completed\"" .mc-data/work/wf-manage-change/_index/sessions.jsonl
```

### T2: Non-empty

```bash
test -s $SESSION_DIR/change-report.md
test -s $SESSION_DIR/phase-summary.md
```

### T3: Format valid (required sections + schema)

```bash
grep -q "## Summary" $SESSION_DIR/change-report.md
grep -q "## Changes Made" $SESSION_DIR/change-report.md
grep -q "## Verification Results" $SESSION_DIR/change-report.md
jq -e '."$schema" == "change-impact-v1"' $SESSION_DIR/change-impact.json    # [S3] schema check
jq -e 'has("change_id") and has("change_type") and has("risk_level") and has("registry_changes") and has("files_modified") and has("docs_modified") and has("generated_at")' $SESSION_DIR/change-impact.json  # [S3] 8 base fields
```

### T4: Required content present

```bash
grep -q "## Registry Updated" $SESSION_DIR/change-report.md
# phase-summary.md content check — bằng tiếng Việt, không phải placeholder
```

**Verification (mc-postgate-check.sh):**
```bash
bash .claude/scripts/wf-manage-change/mc-postgate-check.sh \
  --file=$SESSION_DIR/change-report.md \
  --type=markdown \
  --headings="## Summary,## Changes Made,## Verification Results"
bash .claude/scripts/wf-manage-change/mc-postgate-check.sh \
  --file=$SESSION_DIR/phase-summary.md \
  --type=markdown \
  --headings="## Đã thay đổi gì?,## Kết quả kiểm tra,## Bước tiếp theo"
# → {"pass":true} required. Nếu fail → auto-fix re-generate → retry tối đa 3 lần.
```

**Nếu fail:** Auto-fix (re-generate section thiếu) → retry tối đa 3 lần → escalate nếu vẫn fail.

---

## Next Step Recommendation (Step 6.5)

Hiển thị gợi ý cho user theo tình huống:

| Tình huống | Gợi ý |
|-----------|-------|
| Có code changes | `"Next: /wf-preflight để kiểm tra toàn diện, hoặc git diff để review changes."` |
| Chỉ có doc changes | `"Next: /status để xem tiến độ dự án."` |
| Preflight có warning | `"Next: /wf-preflight --fix để xử lý các warning."` |
| Verify-sync sync_rate < baseline | `"Next: /wf-verify-sync để re-check traceability."` |
| Test run failed | `"Next: /wf-fix-bugs để xử lý các test failures."` |
| Dry-run hoàn tất | `"Để thực hiện thay đổi thật: /wf-manage-change --resume (không có --dry-run)."` |

---

## Final Output Structure

```
$SESSION_DIR/ (= .mc-data/work/wf-manage-change/$CHANGE_ID/)
├── change-status.json          # Skill state (status = "completed")
├── change-intake.json          # Phase 0 intake
├── change-analysis.md          # Phase 1 analysis
├── affected-artifacts.json     # Phase 1 artifacts
├── impact-report.md            # Phase 2 impact
├── change-plan.md              # Phase 3 plan
├── change-impact.json          # [S3] Cross-skill artifact (schema change-impact-v1)
├── change-report.md            # Phase 6 final report
├── phase-summary.md            # CORE-028 tiếng Việt
├── checkpoint.json             # Last checkpoint
└── .session.lock               # DELETED ở Step 6.4b (S2 cleanup)

.mc-data/work/wf-manage-change/
├── index.json                  # Session registry (updated)
├── _index/
│   └── sessions.jsonl          # Append-only log — entry "completed" được thêm ở Step 6.3b
└── .locks/
    └── registry.lock           # KHÔNG tồn tại sau Phase 4a (đã release ở 4a.5c)

.mc-data/work/_trace/
└── session-log.json            # COMPLETE entry appended
```

---

## Done — Skill Complete

Sau Phase 6 POST-GATE PASS:

- Update `change-status.json.status = "completed"`, `progress_pct = 100`
- **[S2]** Heartbeat process killed, `.session.lock` released, sessions.jsonl có entry `status=completed`
- **[S3]** `$SESSION_DIR/change-impact.json` (schema `change-impact-v1`) sẵn sàng cho consumer skills
- Skill exit successfully (EXIT trap đã disable ở Step 6.4b để tránh double-release)
- User có thể chạy `/wf-preflight` hoặc `/status` theo gợi ý

---

## [S3] Cross-Skill Consumption Spec (chuẩn bị cho Sprint 6)

**LƯU Ý:** Sprint 3 CHỈ tạo producer artifact `change-impact.json`. Consumer skills KHÔNG được wire ở Sprint 3 — đó là Sprint 6.

Khi `change-impact.json` đã sẵn sàng, các consumer skills sau (sẽ wire ở Sprint 6) có thể opt-in qua `--from-manage-change[=<CHANGE_ID>]`:

| Consumer | Fields consumed | Wiring point | Behavior |
|----------|----------------|--------------|----------|
| `/wf-verify-sync` | `registry_changes.*`, `files_modified[]`, `verify_evidence.*` | Phase 0 Step 0.18-0.22 (load), Phase 5 Check 5.11 (cross-check `registry_changes` vs current registry), Phase 6 Section 14 (Change Impact Cross-Reference) | Hard-gate cross-check; nếu mismatch giữa `registry_changes` và actual registry state → WARNING với chi tiết diff |
| `/wf-preflight` | `files_modified[]`, `verify_evidence.preflight_status` | Phase 1 priming (inform-only) | Soft inform — preflight tự re-run, KHÔNG dựa vào `verify_evidence` cũ |
| `/wf-implement-feature` | `files_modified[]` | Phase 0 context priming | Inform-only — alert dev rằng files này vừa thay đổi qua change request |

**Resolve `<CHANGE_ID>`:**
- Nếu user pass `--from-manage-change=CHG-20260429-001` → load trực tiếp
- Nếu user pass `--from-manage-change` (không value) → đọc `index.json.active_session` HOẶC `_index/sessions.jsonl` last completed entry
- Nếu file `$SESSION_DIR/change-impact.json` không tồn tại → graceful degrade: log WARNING, tiếp tục với behavior cũ (KHÔNG block)

**Backward compat:** Consumer skills phải graceful — file thiếu → no-op, behavior cũ giữ nguyên (giống pattern `--from-fix-bugs` đã wire ở wf-fix-bugs v7.1.0).
