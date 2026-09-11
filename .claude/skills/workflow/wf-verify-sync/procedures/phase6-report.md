# Phase 6: Generate Report + Finalize

> Cũ Phase 7. Phase cuối — ghi `verify-sync.md`, safe-update registry, append history,
> finalize status/checkpoint, tạo phase summary, log session COMPLETE.

**PRE-GATE:**
- Phase 5 (`phase5-crossval.md`) POST-GATE PASS (zero errors hoặc đã escalate)
- `test -n "$GAPS_LIST" && test -n "$SYNC_RATE"`

**📥 INPUT:**
- Registry (đọc NGAY TRƯỚC khi ghi — Safe-Write rule)
- Validated data từ Phase 5: `$VALIDATION_REPORT`, `$SYNC_RATE`, `$COVERAGE_RATE`, `$W001_ANOMALIES`, `$GAPS_LIST`, `$ORPHAN_LIST`
- `$UI_COVERAGE_DATA` (nếu Phase 3 chạy)
- `$FIX_LOG` (nếu Phase 4 chạy)
- `$PREFLIGHT_CONTEXT` (nếu Phase 0 load được)
- `$FIX_IMPACT_CONTEXT`, `$DOCS_SYNC_CONTEXT`, `$FROM_FIX_BUGS_SESSION_DIR` (v2.1+ S9 — nếu Phase 0 load được khi `--from-fix-bugs`)

**📤 OUTPUT:**

| File | Đường dẫn | Template |
|------|-----------|---------|
| Verify-sync report (SESSION) | `$SESSION_DIR/verify-sync.md` | Generated theo schema "Output Report" trong SKILL.md — report lưu trữ theo session |
| Actionable checklist | `$SESSION_DIR/actionable-checklist.md` | Trích xuất riêng phần kế hoạch triển khai |
| Registry (impl_status) | `.mc-data/docs/_meta/req-registry.json` | — (safe-update: chỉ field `impl_status` per REQ-ID) |
| History log | `.mc-data/work/wf-verify-sync/verify-sync-history.md` | — (append-only, top-level KHÔNG session-scoped) |
| Status finalize | `$SESSION_DIR/verify-sync-status.json` | (cập nhật existing) |
| Checkpoint finalize | `$SESSION_DIR/checkpoint.json` | (cập nhật existing) |
| Phase summary | `$SESSION_DIR/phase-summary.md` | `.claude/doc-framework/_meta/phase-summary.template.md` |

---

## Reference Sections

- `_shared/registry-safe-write.md`
- `_shared/state-variables.md`
- `_shared/canonical-cdg.md` (Step 6.2c CDG logic)

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 6.1 | **Bash delegation (v4.0+ S4):** Chạy `bash .claude/scripts/wf-verify-sync/vs-build-report-data.sh --analysis-results $SESSION_DIR/analysis-results.json --ui-scan $SESSION_DIR/ui-scan-results.json --validation $SESSION_DIR/validation-report.json --registry .mc-data/docs/_meta/req-registry.json --output $SESSION_DIR/report-data.json --session-id "$SESSION_ID" --scope "$SCOPE" --scope-name "$NAME"`. Nếu có `--fix-impact` / `--add-scope` / `--manage-change` / `--preflight` → pass tương ứng. | `test -s $SESSION_DIR/report-data.json` |
| 6.1a | Đọc `$SESSION_DIR/report-data.json` → set `$REPORT_DATA` (in-memory). Extract tất cả fields: `summary`, `warnings`, `feature_completion`, `gaps_list`, `ui_coverage`, `validation`, `cross_references`, `next_recommended_action`. | `$REPORT_DATA` loaded |
| 6.1b | **Build report content:** Dùng `$REPORT_DATA` để render markdown theo schema "Output Report" trong SKILL.md. **Verdict + next step** đã pre-computed trong `$REPORT_DATA.summary.verdict` và `$REPORT_DATA.next_recommended_action`. **Actionable Checklist:** Dùng `$REPORT_DATA.feature_completion` để render checklist features `in_progress` / `not_started` với `/wf-implement-feature [FEAT-ID]`. Lưu vào in-memory `$REPORT_CONTENT`. | `$REPORT_CONTENT` non-empty |
| 6.2a | **WRITE session copy (BẮT BUỘC):** Mở tool ghi nội dung `$REPORT_CONTENT` ra file `$SESSION_DIR/verify-sync.md`. Đây là bản sao lưu trữ bắt buộc của session, KHÔNG ĐƯỢC BỎ QUA. | `test -s $SESSION_DIR/verify-sync.md` |
| 6.2b | **WRITE Actionable Checklist:** Trích xuất và ghi riêng phần "Actionable Checklist" (đã build ở bước 6.1) ra file độc lập tại `$SESSION_DIR/actionable-checklist.md` để user theo dõi tiến độ một cách tiện lợi nhất. | `test -s $SESSION_DIR/actionable-checklist.md` |
| 6.2c | **Canonical Dual-Write (BẮT BUỘC):** Ghi bản sao ra canonical `.mc-data/docs/_meta/verify-sync.md` với CDG conflict check (xem `_shared/canonical-cdg.md`).<br>1. Check `test -f .mc-data/docs/_meta/verify-sync.md` — nếu chưa tồn tại → WRITE trực tiếp (no conflict).<br>2. Nếu tồn tại: lấy mtime canonical (xem cross-platform mtime trong `_shared/canonical-cdg.md`).<br>3. Compute `delta = canonical_mtime - session_start_at_epoch`.<br>4. Nếu `delta > $MCV3_VERIFY_SYNC_CDG_TOLERANCE_SEC` (default 5): render CDG với 3 options — [1] Override [2] Skip canonical [3] Cancel.<br>5. Nếu user chọn Override (hoặc delta ≤ tolerance): WRITE `.mc-data/docs/_meta/verify-sync.md` (nội dung giống `$SESSION_DIR/verify-sync.md`). Set `canonical_decision="override"`.<br>6. Nếu user chọn Skip: log WARNING "canonical not updated — session copy preserved at $SESSION_DIR/verify-sync.md". Set `canonical_decision="skip"`.<br>7. Nếu user chọn Cancel: log WARNING "canonical write cancelled by user". Set `canonical_decision="cancel"`. KHÔNG xóa session copy.<br>8. Ghi decision vào `$SESSION_DIR/checkpoint.json`.`canonical_decision` field. | Canonical written hoặc decision logged |
| 6.3 | **Acquire registry lock:** `vs-acquire-lock.sh registry $SESSION_DIR 30` → set `$REGISTRY_LOCK_ACQUIRED` | Lock acquired |
| 6.3a | **Backup registry trước khi update:** `cp .mc-data/docs/_meta/req-registry.json $SESSION_DIR/req-registry.backup.json`. **Capture before state:** `jq '[.requirements[] | {req_id: .id, impl_status: .impl_status}]' req-registry.json > $SESSION_DIR/registry-before.json` — lưu snapshot impl_status trước safe-update. Sau đó **Update `req-registry.json`** field `impl_status` theo Safe-Write rule (xem `_shared/registry-safe-write.md`). Read-before-write: load registry HIỆN TẠI ngay trước khi ghi (atomic). **Capture after state:** `jq '[.requirements[] | {req_id: .id, impl_status: .impl_status}]' req-registry.json > $SESSION_DIR/registry-after.json`. **Compute registry_changes:** `jq -n --slurpfile before $SESSION_DIR/registry-before.json --slurpfile after $SESSION_DIR/registry-after.json '$before[0] as $b | $after[0] as $a | [$b[] as $br | $a[] | select(.req_id == $br.req_id and .impl_status != $br.impl_status) | {req_id: .req_id, field: "impl_status", before: $br.impl_status, after: .impl_status}]'` → lưu kết quả vào `$REGISTRY_CHANGES`. **Persist vào checkpoint:** cập nhật `$SESSION_DIR/checkpoint.json` — `data_snapshot.registry_changes = $REGISTRY_CHANGES`. | `jq '.' registry.json` pass, backup saved, `$REGISTRY_CHANGES` computed |
| 6.3b | **Release registry lock:** `vs-release-lock.sh registry $SESSION_DIR` | Lock released |
| 6.4 | Append history line vào `.mc-data/work/wf-verify-sync/verify-sync-history.md` (top-level, NOT session-scoped): `[YYYY-MM-DD] session=$SESSION_ID scope=[scope] sync=[rate]% implemented=[N] total=[N]` | History file appended |
| 6.5 | **BẮT BUỘC — KHÔNG BỎ QUA BƯỚC NÀY:** Chạy `bash .claude/scripts/wf-verify-sync/vs-finalize-session.sh` với đầy đủ tham số để cập nhật status + checkpoint atomically:<br>`bash .claude/scripts/wf-verify-sync/vs-finalize-session.sh --session-dir "$SESSION_DIR" --session-id "$SESSION_ID" --sync-rate "$SYNC_RATE" --coverage-rate "$COVERAGE_RATE" --total-req-ids "$REQS_TOTAL" --implemented "$IMPLEMENTED" --in-progress "$IN_PROGRESS" --not-started "$NOT_STARTED" --skipped "$SKIPPED" --orphan-count "${#ORPHAN_LIST[@]}" --w001-count "${#W001_ANOMALIES[@]}" --w002-count "${#W002_ANOMALIES[@]}" --w003-count "${#W003_ANOMALIES[@]}" --canonical-decision "${CANONICAL_DECISION:-no_conflict}"`<br>Script tự động cập nhật cả `verify-sync-status.json` (status=completed, progress_pct=100, sync_results populated, all phases completed) và `checkpoint.json` (current_phase=completed, pending_phases=[]). Verify kết quả trả về: `status: "ok"` hoặc `status: "partial"`. | `jq -e '.sync_results.total_req_ids > 0' $SESSION_DIR/verify-sync-status.json` + `jq -e '.progress_pct == 100' $SESSION_DIR/verify-sync-status.json` + `jq -e '.position.current_phase == "completed"' $SESSION_DIR/checkpoint.json` |
| 6.7 | **[READ-TEMPLATE] Phase Summary (CORE-028):** READ `.claude/doc-framework/_meta/phase-summary.template.md` → POPULATE với tóm tắt toàn bộ skill (scope, session_id, total REQ-IDs, sync rate, coverage rate, gaps count, orphan count, W001 count, W003 count, UI coverage nếu có, next step) → WRITE `$SESSION_DIR/phase-summary.md`. Viết bằng tiếng Việt, dễ hiểu cho non-specialist. Hiển thị nội dung trong conversation. | `test -s $SESSION_DIR/phase-summary.md` |
| 6.8 | **Build verify-sync-impact.json:** `bash .claude/scripts/wf-verify-sync/vs-impact-build.sh "$SESSION_DIR"` → `$SESSION_DIR/verify-sync-impact.json` | `test -s $SESSION_DIR/verify-sync-impact.json` |
| 6.9 | **Session Finalization:** Append JSONL completion entry + release lock + kill heartbeat (xem Session Finalization đầy đủ tại `procedures/session-init.md`). Chạy tuần tự 3 lệnh sau:<br>1. `bash .claude/scripts/wf-verify-sync/vs-index-append.sh "$(jq -cn --arg sid "$SESSION_ID" --arg sc "$SCOPE" --arg nm "${NAME:-}" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg host "$(hostname 2>/dev/null \|\| echo unknown)" --argjson total "${REQS_TOTAL:-0}" --argjson rate "${SYNC_RATE:-0}" '{session_id:$sid,scope:$sc,scope_name:$nm,created_at:$ts,host:$host,status:"completed",reqs_total:$total,sync_rate:$rate,completed_at:$ts}')"` <br>2. `bash .claude/scripts/wf-verify-sync/vs-release-lock.sh session "$SESSION_DIR"`<br>3. `kill "$HEARTBEAT_PID" 2>/dev/null \|\| true` | `wc -l < _index/sessions.jsonl` ≥ 2 (init + completed entry) |
| 6.10 | **Session Log (CORE-026):** Append entry vào `.mc-data/work/_trace/session-log.json`: `{event: "COMPLETE", skill: "wf-verify-sync", session_id: $SESSION_ID, timestamp, sync_rate, coverage_rate, scope, gaps_count, orphan_count, w001_count, canonical_decision: "skipped"}` | Entry appended |

---

## Registry Safe-Write — Tóm tắt

> Chi tiết đầy đủ + schema reference: `_shared/registry-safe-write.md`.

```
QUY TẮC BẤT DI BẤT DỊCH (CORE-008):
- KHÔNG downgrade impl_status="done" → giá trị khác
- W001 anomalies → LOG WARNING, KHÔNG tự downgrade
- Chỉ UPGRADE: not_started → in_progress (nếu có code), in_progress → done (nếu có code)
- Nếu impl_status != "done" và không có evidence → GIỮ NGUYÊN
```

---

## Output Report — Sections cần có

> Schema chi tiết xem trong SKILL.md §Output Report. Phase 6 phải đảm bảo include đủ:

1. **Header** — Project, Date, Scope
2. **Summary table** — Total REQ-IDs, Implemented, In Progress, Not Started, Skipped, Orphan Code Files
3. **Sync Rate + Coverage Rate + Verdict** — verdict theo logic v3.1+: READY (≥80% AND features_in_progress=0) / PARTIAL_FEATURES (≥80% nhưng features_in_progress>0) / PARTIAL (60-79%) / NOT READY (<60%)
4. **Feature Completion section (BẮT BUỘC khi `$FEATURES_TOTAL > 0`)** — table tổng hợp features[] theo status. Nếu `$HAS_IN_PROGRESS_FEATURES == true` → hiển thị danh sách `$IN_PROGRESS_FEATURES_LIST` (tối đa 20 entries) với ⚠️ WARNING. Nếu `$FEATURES_TOTAL == 0` → ghi chú "Registry không có features[]".
5. **Skipped notice** — N REQ-IDs (deprecated theo legacy-decisions.json hoặc user skip)
6. **Warnings (W001/W003)** — table với code, REQ-ID, mô tả, phân loại, suggested fix, hành động (W003: "impl_status=done và có code nhưng Feature cha chưa hoàn thành")
7. **Actionable Checklist (Kế hoạch triển khai)** — Thay thế "Gaps" và "In Progress". Phân tích mảng `features` trong `req-registry.json` để tìm các FEAT có `impl_status` là `in_progress` hoặc `not_started`. Nhóm chúng theo `system_id` thành các mục con (ví dụ: `#### 📱 SYS-MOBILE-STAFF`). Dưới mỗi mục là bảng checklist với các cột: `Trạng thái ([ ] in_progress/not_started)`, `Module`, `Tính năng (Feature ID: Name)`, `Thuộc Yêu cầu (REQ-IDs)`, `Lệnh triển khai (/wf-implement-feature [FEAT-ID])`. Việc này yêu cầu bạn (AI Agent) tự trích xuất và map data từ mảng features, đảm bảo tính Actionable cho từng hệ thống cụ thể.
8. **Orphan Code** — table với File, Suggested REQ-ID, Action
10. **UI Coverage (conditional)** — nếu Phase 3 chạy: tổng screens, matched, gaps, `coverage_pct`, `partial_coverage_pct`, MISSING_FROM_FEATURES warnings, MISSING_FROM_CODE warnings. **Ghi chú MISSING_FROM_CODE phải chỉ rõ số lượng features not_started — KHÔNG tự label là "planned, không phải gap".** Thay vào đó ghi: "X features chưa có screen tương ứng trong code — xem Feature Completion section để biết status."
11. **Preflight Cross-Reference (conditional)** — nếu `$PREFLIGHT_CONTEXT != null`: verdict, score, critical/high counts, run_id
12. **Fix Log (conditional)** — nếu `$FIX_LOG` non-empty: list các files đã fix + W001 classifications
13. **Validation Report** — từ `$VALIDATION_REPORT`: iterations run, checks passed, errors fixed
14. **Footer** — Full report path + Next step suggestion
15. **(v2.1+ S9) Fix Impact Cross-Reference (conditional)** — nếu `$FIX_IMPACT_CONTEXT != null`: section consume từ wf-fix-bugs session — schema dưới

### Section 14 template (Fix Impact Cross-Reference)

```markdown
### Fix Impact Cross-Reference (--from-fix-bugs)

| Field | Value |
|-------|-------|
| Source session | $FROM_FIX_BUGS_SESSION_DIR (basename) |
| Generated at | $FIX_IMPACT_CONTEXT.generated_at |
| Audit checksum | $FIX_IMPACT_CONTEXT.audit_chain.checksum_sha256 (first 16 chars) |
| Audit warning | [tampered: yes/no — từ Phase 0.20 audit_chain check] |

**Fix Summary từ wf-fix-bugs:**
| Total | Fixed | Deferred | Escalated | Skipped | Verify iterations |
|-------|-------|----------|-----------|---------|-------------------|
| N | N | N | N | N | N |

**Registry changes verified (check 5.11):**
- Total changes: N
- Mismatches: N (xem `$VALIDATION_REPORT.fix_impact_xref.mismatches[]` nếu > 0)
- Warnings: N

**Next recommended action (từ fix-impact):**
- Skill: $FIX_IMPACT_CONTEXT.next_recommended_action.skill
- Rationale: $FIX_IMPACT_CONTEXT.next_recommended_action.rationale
- Blocking items: $FIX_IMPACT_CONTEXT.next_recommended_action.blocking_items[].count với type=escalated → BLOCK release nếu > 0

**Docs sync (từ docs-sync-report.json — nếu loaded):**
- Mismatches: $DOCS_SYNC_CONTEXT.summary.mismatches_count (cross-check với UI Coverage section)
```

---

**POST-GATE (v4.0+ S6 — bash delegation):**
- Chạy `bash .claude/scripts/wf-verify-sync/vs-postgate-check.sh --session-dir "$SESSION_DIR" --registry .mc-data/docs/_meta/req-registry.json --interface-type "$INTERFACE_TYPE"` → `$SESSION_DIR/postgate-report.json`
- T1 Existence: Tất cả 11 files tồn tại + non-empty + valid JSON
- T2 Structure: Required fields/headings trong status, checkpoint, impact, session copy, phase summary, actionable checklist, registry
- T3 Content: Word count thresholds (verify-sync.md ≥200w, actionable-checklist.md ≥50w, phase-summary.md ≥100w) + progress_pct=100 + sync_results populated + data_snapshot depth
- T4 Cross-reference: Session ID consistency across status/checkpoint/impact, REQ-ID count cross-ref, sync rate cross-ref, JSONL completed entry, canonical/session content match
- `jq -e '.passed' $SESSION_DIR/postgate-report.json` → PASS (tất cả 4 tiers pass) hoặc FAIL (≥1 tier fail)
- Nếu FAIL: render failure details từ `postgate-report.json.checks[]`, escalate với error count
- POST-GATE PASS thì skill exit thành công

**Manual check bổ sung (không trong script):**
- T1: `jq '.' .mc-data/docs/_meta/req-registry.json` (JSON valid)
- T2: `test -s .mc-data/work/wf-verify-sync/verify-sync-history.md` (history appended)
- T3: `test -s "$SESSION_DIR/phase-summary.md"` (summary written)
- T4: `test -s "$SESSION_DIR/verify-sync.md"` (session copy written)
- Status file `$SESSION_DIR/verify-sync-status.json`: `status="completed"`, `progress_pct=100`
- Session log có entry COMPLETE

---

## SKILL EXIT

> Sau Phase 6 → skill hoàn thành. Hiển thị summary trong conversation theo schema "Output Report" trong SKILL.md.
> Next step (gợi ý cho user) — dựa theo `$VERDICT`:
> - **READY** (Sync Rate ≥ 80% AND features_in_progress = 0) → `"/wf-prepare-deployment"` (chuẩn bị release)
> - **PARTIAL_FEATURES** (Sync Rate ≥ 80% nhưng features_in_progress > 0) → Hoàn thành các features in_progress trước khi release: `"/wf-implement-feature [FEAT-ID]"` cho từng feature trong `$IN_PROGRESS_FEATURES_LIST`, rồi chạy lại `"/wf-verify-sync"`. **KHÔNG gợi ý `/wf-prepare-deployment` khi verdict là PARTIAL_FEATURES.**
> - **PARTIAL** (Sync Rate 60-79%) → `"/wf-implement-feature [REQ-ID]"` cho từng gap, rồi chạy lại `"/wf-verify-sync"`
> - **NOT_READY** (Sync Rate < 60%) → Review gap list, ưu tiên features priority=high, lên kế hoạch implement
