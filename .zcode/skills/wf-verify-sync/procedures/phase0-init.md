# Phase 0: Init — Prerequisites Validation & Preflight Context

> Entry point của procedures/ — load file này NGAY KHI SKILL.md route vào procedures/.
> Gộp Prerequisites Validation (cũ Phase 1) + Preflight Context Loading (cũ Phase 1.5).

**PRE-GATE:**
- `test -f ".mc-data/docs/_meta/req-registry.json"`

> **Forensic validation (Protocol 10.4):** `jq '.requirements | length > 0' .mc-data/docs/_meta/req-registry.json` + `(test -d src || test -d apps)`. Nếu FAIL → "Registry chưa có requirements hoặc chưa có code. Chạy skills trước đó."

**Working Directory:** Skill này PHẢI chạy từ project root (nơi có `.mc-data/`). Nếu current directory không có `.mc-data/`, tìm parent directory hoặc yêu cầu user cd đến project root.

**📥 INPUT:**

| File | Đường dẫn |
|------|-----------|
| Registry | `.mc-data/docs/_meta/req-registry.json` |
| Status file (nếu `--resume`) | `$SESSION_DIR/verify-sync-status.json` |
| Checkpoint (nếu `--resume`) | `$SESSION_DIR/checkpoint.json` |
| Preflight report (optional) | `.mc-data/work/wf-preflight/preflight-report.md` |
| Preflight status (optional) | `.mc-data/work/wf-preflight/preflight-status.json` |

**📤 OUTPUT:**
- `$SESSION_DIR/verify-sync-status.json` (init)
- `$SESSION_DIR/checkpoint.json` (init)
- In-memory state: `$SESSION_ID`, `$SESSION_DIR`, `$SCOPE`, `$NAME`, `$HAS_FIX_FLAG`, `$HAS_STATUS_FLAG`, `$HAS_RESUME_FLAG`, `$SCOPE_FILTER`, `$REGISTRY_FINGERPRINT`, `$PREFLIGHT_CONTEXT`

---

## Reference Sections

- `_shared/state-variables.md`
- `_shared/flag-handlers.md`
- `_shared/scope-filtering.md`
- `_shared/checkpoint-protocol.md`

---

## Steps — Prerequisites & Init (cũ Phase 1)

| Step | Action | Verify |
|------|--------|--------|
| 0.0  | **Project root detection (E002):** Check `test -d .mc-data` tồn tại trong current directory. Nếu KHÔNG tồn tại → tìm parent directories (lên tối đa 3 level) cho `.mc-data/`. Nếu vẫn không tìm thấy → **E002**: "Không chạy từ project root. Yêu cầu cd đến thư mục chứa .mc-data/" → STOP | `.mc-data/` found |
| 0.0b | **Parse flags sớm:** Parse `--scope`, `--name`, `--fix`, `--resume`, `--status`, `--from-fix-bugs[=<id>]`, `--from-add-scope[=<id>]`, `--from-manage-change[=<id>]`, `--from-preflight[=<id>]` flags → set `$SCOPE` (default: `all`), `$NAME`, `$HAS_FIX_FLAG`, `$HAS_RESUME_FLAG`, `$HAS_STATUS_FLAG`, `$HAS_FROM_FIX_BUGS_FLAG`, `$FROM_FIX_BUGS_SESSION_ID`, `$HAS_FROM_ADD_SCOPE_FLAG`, `$FROM_ADD_SCOPE_SESSION_ID`, `$HAS_FROM_MANAGE_CHANGE_FLAG`, `$FROM_MANAGE_CHANGE_ID`, `$HAS_FROM_PREFLIGHT_FLAG`, `$FROM_PREFLIGHT_SESSION_ID`. Nếu `$HAS_RESUME_FLAG = true` → skip SI, load resume-routing.md thay thế. | Flags parsed |
| 0.0c | **Session Init:** Nếu `$HAS_RESUME_FLAG = false` → Read `procedures/session-init.md` → execute SI.1–SI.7. Returns: `$SESSION_ID`, `$SESSION_DIR`, `$LOCK_PATH`, `$HEARTBEAT_PID`. Nếu `$HAS_RESUME_FLAG = true` → Read `procedures/resume-routing.md` → execute RR.1–RR.8. Returns: `$SESSION_ID`, `$SESSION_DIR` (re-bound), `$LOCK_PATH`, `$HEARTBEAT_PID`. | `$SESSION_DIR` created và lock acquired |
| 0.1  | Check `.mc-data/docs/` tồn tại | `test -d .mc-data/docs` |
| 0.2  | Check `src/` hoặc `apps/` tồn tại | `test -d src \|\| test -d apps` |
| 0.3  | Check `req-registry.json` tồn tại + forensic validation `jq '.requirements \| length > 0'` | Forensic pass |
| 0.5  | **[READ-TEMPLATE] Status file:** READ `templates/verify-sync-status.json` → POPULATE placeholders (`skill_id`, `project`, `scope`, `scope_name`, `has_fix_flag`, `session_id=$SESSION_ID`, `timestamps.started_at`, `phases.*.status="pending"`) → WRITE `$SESSION_DIR/verify-sync-status.json` | `test -s $SESSION_DIR/verify-sync-status.json` |
| 0.6  | **[READ-TEMPLATE] Checkpoint init:** READ `templates/checkpoint.json` → POPULATE (`checkpoint_id`, `skill_id`, `session_id=$SESSION_ID`, `timestamp`, `trigger.reason="fresh_start"`, `scope.type=$SCOPE`, `scope.has_fix_flag=$HAS_FIX_FLAG`, `position.current_phase="phase_0"`) → WRITE `$SESSION_DIR/checkpoint.json` | `test -s $SESSION_DIR/checkpoint.json` |
| 0.6a | **Registry fingerprint:** Đọc `requirements[].id` từ `req-registry.json` → sort ascending → join bằng `|` → compute fingerprint string (dạng `REQ-A-001|REQ-A-002|REQ-B-001|...`). Lưu vào `$REGISTRY_FINGERPRINT`. Cập nhật `$SESSION_DIR/checkpoint.json`: `registry_state.fingerprint=$REGISTRY_FINGERPRINT`, `registry_state.snapshot_timestamp=now`. | `$REGISTRY_FINGERPRINT` non-empty |
| 0.7  | **Session Log (CORE-026):** Nếu `.mc-data/work/_trace/session-log.json` chưa tồn tại → READ template `.claude/doc-framework/_meta/session-log.template.json` → tạo file. Append entry: `{event: "START", skill: "wf-verify-sync", timestamp, arguments}`. Nếu file tồn tại → chỉ append entry mới. | Entry appended |
| 0.8  | Parse `--scope`, `--name`, `--fix` flags → set `$SCOPE`, `$NAME`, `$HAS_FIX_FLAG` | Flags captured |
| 0.9  | **Scope resolution** (theo `_shared/scope-filtering.md`): Nếu `--scope=system` hoặc `--scope=module` → validate `--name` tồn tại trong registry. Nếu không tìm thấy → **E006** (liệt kê valid IDs, STOP). Build `$SCOPE_FILTER`: danh sách REQ-IDs + module paths thuộc scope | `$SCOPE_FILTER` non-empty |
| 0.10 | **Log validation result** to Output: "Working directory validated: project root found. Scope=$SCOPE Name=$NAME" | Logged |

---

## Steps — Preflight Context Loading (cũ Phase 1.5, optional)

> Load context từ preflight report gần nhất (nếu có) — bổ sung cho Phase 6 cross-reference.

| Step | Action | Verify |
|------|--------|--------|
| 0.11 | Check `test -f .mc-data/work/wf-preflight/preflight-report.md` — nếu không tồn tại → SKIP các bước 0.12–0.14, set `$PREFLIGHT_CONTEXT = null` | File check done |
| 0.12 | Đọc `preflight-report.md` → extract: `verdict`, overall `score`, critical issue count, high issue count | Data extracted |
| 0.13 | Đọc `preflight-status.json` → extract: `run_id`, `scope` | Status loaded |
| 0.14 | Lưu vào `$PREFLIGHT_CONTEXT`: `{verdict, score, critical_count, high_count, run_id, scope, loaded_at}` | Context saved |
| 0.15 | Log: "Preflight context loaded: verdict=[verdict], score=[score]%, [critical_count] critical, [high_count] high issues" (nếu skip → log "No preflight context available") | Logged |
| 0.16 | **Fix-report context (optional):** Check `test -f .mc-data/work/wf-fix-bugs/fix-history.md` (canonical append-only path theo CORE-007). Nếu tồn tại → đọc extract từ **tail** của file (entry mới nhất): `total_fixes`, `critical_fixes`, `high_fixes`, `scope`. Lưu vào `$FIX_REPORT_CONTEXT`: `{total_fixes, critical_fixes, high_fixes, scope, loaded_at}`. Nếu không → `$FIX_REPORT_CONTEXT = null` | Context saved or null |
| 0.17 | Log: "Fix-report context loaded: [total_fixes] fixes, [critical_fixes] critical" (nếu skip → log "No fix-report context available") | Logged |

> `$PREFLIGHT_CONTEXT` sẽ được dùng trong Phase 6 Output Report — section "Preflight Cross-Reference".
> `$FIX_REPORT_CONTEXT` sẽ được dùng trong Phase 6 Output Report — section "Fix Report Cross-Reference" (nếu có).
> Nếu null → Phase 6 bỏ qua section tương ứng.

---

## Steps — Fix-Impact Context Loading (v2.1+ S9 — `--from-fix-bugs`)

> **Conditional:** Chỉ chạy khi `$HAS_FROM_FIX_BUGS_FLAG = true`. Mục đích: load `fix-impact.json` + `docs-sync-report.json` từ wf-fix-bugs session để Phase 5 cross-check registry changes + Phase 6 render Fix Impact section.

| Step | Action | Verify |
|------|--------|--------|
| 0.18 | **Skip nếu flag không pass:** IF `$HAS_FROM_FIX_BUGS_FLAG != true` → set `$FIX_IMPACT_CONTEXT = null`, `$DOCS_SYNC_CONTEXT = null`, `$FROM_FIX_BUGS_SESSION_DIR = null`, jump to POST-GATE. ELSE → continue. | Branch decided |
| 0.19 | **Resolve session_dir:** IF `$FROM_FIX_BUGS_SESSION_ID` non-empty (user pass `=<id>`): `$FROM_FIX_BUGS_SESSION_DIR=".mc-data/work/wf-fix-bugs/sessions/$FROM_FIX_BUGS_SESSION_ID"`. Verify dir tồn tại — nếu không → WARNING "Session ID không tồn tại: $FROM_FIX_BUGS_SESSION_ID. Skip --from-fix-bugs.", set tất cả contexts = null, jump to POST-GATE. ELSE (auto-resolve): check `test -f .mc-data/work/wf-fix-bugs/_index/sessions.jsonl` — nếu không tồn tại → WARNING "Index sessions.jsonl không tồn tại. wf-fix-bugs chưa chạy?", skip. Auto-resolve: `LATEST_SID=$(jq -r 'select(.status=="completed")\|.session_id' _index/sessions.jsonl \| sort \| tail -1)`. Nếu rỗng → WARNING "Không có completed session", skip. Set `$FROM_FIX_BUGS_SESSION_DIR=".mc-data/work/wf-fix-bugs/sessions/$LATEST_SID"`. | `$FROM_FIX_BUGS_SESSION_DIR` resolved hoặc null |
| 0.20 | **Load + validate fix-impact.json:** IF `$FROM_FIX_BUGS_SESSION_DIR != null`: check `test -f $FROM_FIX_BUGS_SESSION_DIR/fix-impact.json`. Nếu không → WARNING "fix-impact.json không tồn tại trong session — wf-fix-bugs có thể chưa hoàn tất POST-GATE step 3.5". Nếu có: validate `jq -e '."$schema" == "fix-impact-v1"' fix-impact.json` — fail → WARNING "Schema mismatch, expected fix-impact-v1", skip. **(D4 audit_chain check):** Compute checksum reproducible: `EXPECTED=$(jq -r .audit_chain.checksum_sha256 fix-impact.json)`; recompute từ fix-log entries: `ACTUAL=$(jq -Sc 'sort_by(.issue_id)' fix-log.json \| sha256sum \| cut -d" " -f1)`. So sánh: nếu mismatch → WARNING "audit_chain.checksum_sha256 mismatch — possible tamper or fix-log diverged", set warning trong context but vẫn LOAD (graceful — không fail). Parse vào `$FIX_IMPACT_CONTEXT` (object). | `$FIX_IMPACT_CONTEXT` set hoặc null |
| 0.21 | **Load docs-sync-report.json (optional):** IF `$FROM_FIX_BUGS_SESSION_DIR != null`: check `test -f $FROM_FIX_BUGS_SESSION_DIR/docs-sync-report.json`. Nếu có: validate `jq -e '."$schema" == "docs-sync-report-v1"'` — fail → log debug, set null. Pass → parse vào `$DOCS_SYNC_CONTEXT`. Nếu file không tồn tại → SKIP silently (Phase 4a có thể không chạy nếu wf-fix-execute không có docs sync). | `$DOCS_SYNC_CONTEXT` set hoặc null |
| 0.22 | **Log:** "Fix-Impact context: session=$FROM_FIX_BUGS_SESSION_DIR, fix-impact=[loaded\|null], docs-sync=[loaded\|null], audit_chain_warning=[true\|false]" | Logged |

> `$FIX_IMPACT_CONTEXT` sẽ được dùng trong Phase 5 (check 5.11 cross-check registry_changes) và Phase 6 (section "Fix Impact Cross-Reference").
> `$DOCS_SYNC_CONTEXT` sẽ được dùng trong Phase 3 (UI Coverage flag mismatches) và Phase 6.
> Backward compat: nếu skip (không pass flag) hoặc fail (file không tồn tại / schema mismatch) → tất cả context = null, downstream phases skip cross-check tương ứng.

---

## Steps — Add-Scope Impact Context Loading (v4.0+ S3 — `--from-add-scope`)

> **Conditional:** Chỉ chạy khi `$HAS_FROM_ADD_SCOPE_FLAG = true`. Mục đích: load `scope-impact.json` từ wf-add-scope session để Phase 5 cross-check modules mới + Phase 6 render Add-Scope Impact section.

| Step | Action | Verify |
|------|--------|--------|
| 0.23 | **Skip nếu flag không pass:** IF `$HAS_FROM_ADD_SCOPE_FLAG != true` → set `$ADD_SCOPE_CONTEXT = null`, jump to step 0.26. ELSE → continue. | Branch decided |
| 0.24 | **Resolve session_dir:** IF `$FROM_ADD_SCOPE_SESSION_ID` non-empty (user pass `=<id>`): set `$FROM_ADD_SCOPE_SESSION_DIR=".mc-data/work/wf-add-scope/sessions/$FROM_ADD_SCOPE_SESSION_ID"`. Verify dir tồn tại — nếu không → WARNING "Session ID không tồn tại: $FROM_ADD_SCOPE_SESSION_ID. Skip --from-add-scope.", set `$ADD_SCOPE_CONTEXT = null`, jump to step 0.26. ELSE (auto-resolve): check `test -f .mc-data/work/wf-add-scope/_index/sessions.jsonl` — nếu không tồn tại → WARNING "Index sessions.jsonl không tồn tại. wf-add-scope chưa chạy?", skip. Auto-resolve: `LATEST_SID=$(jq -r 'select(.status=="completed") | .session_id' _index/sessions.jsonl | sort | tail -1)`. Nếu rỗng → WARNING "Không có completed session", skip. Set session_dir = `.mc-data/work/wf-add-scope/sessions/$LATEST_SID`. | Session dir resolved hoặc null |
| 0.25 | **Load + validate scope-impact.json:** IF session_dir resolved: check `test -f $session_dir/scope-impact.json`. Nếu không → WARNING "scope-impact.json không tồn tại trong session". Nếu có: validate `jq -e '."$schema" == "scope-impact-v1"' scope-impact.json` — fail → WARNING "Schema mismatch, expected scope-impact-v1", skip. Pass → parse vào `$ADD_SCOPE_CONTEXT` (object). Log: "Add-Scope context: session=[session_dir], scope-impact=[loaded|null]" | `$ADD_SCOPE_CONTEXT` set hoặc null |

> `$ADD_SCOPE_CONTEXT` sẽ được dùng trong Phase 5 (check 5.12 cross-check new modules[]) và Phase 6 (section "Add-Scope Impact Cross-Reference").
> Backward compat: nếu skip hoặc fail → `$ADD_SCOPE_CONTEXT = null`, downstream phases skip cross-check tương ứng.

---

## Steps — Manage-Change Impact Context Loading (v4.0+ S3 — `--from-manage-change`)

> **Conditional:** Chỉ chạy khi `$HAS_FROM_MANAGE_CHANGE_FLAG = true`. Mục đích: load `change-impact.json` từ wf-manage-change session để Phase 5 cross-check registry_changes + Phase 6 render Change Impact section.

| Step | Action | Verify |
|------|--------|--------|
| 0.26 | **Skip nếu flag không pass:** IF `$HAS_FROM_MANAGE_CHANGE_FLAG != true` → set `$MANAGE_CHANGE_CONTEXT = null`, jump to step 0.29. ELSE → continue. | Branch decided |
| 0.27 | **Resolve change_dir:** IF `$FROM_MANAGE_CHANGE_ID` non-empty (user pass `=<id>`): set `$FROM_MANAGE_CHANGE_DIR=".mc-data/work/wf-manage-change/$FROM_MANAGE_CHANGE_ID"`. Verify dir tồn tại — nếu không → WARNING "Change ID không tồn tại: $FROM_MANAGE_CHANGE_ID. Skip --from-manage-change.", set `$MANAGE_CHANGE_CONTEXT = null`, jump to step 0.29. ELSE (auto-resolve): check `test -f .mc-data/work/wf-manage-change/_index/sessions.jsonl` — nếu không tồn tại → WARNING "Index sessions.jsonl không tồn tại. wf-manage-change chưa chạy?", skip. Auto-resolve: `LATEST_CID=$(jq -r 'select(.status=="completed") | .change_id' _index/sessions.jsonl | sort | tail -1)`. Nếu rỗng → WARNING "Không có completed change", skip. Set change_dir = `.mc-data/work/wf-manage-change/$LATEST_CID`. | Change dir resolved hoặc null |
| 0.28 | **Load + validate change-impact.json:** IF change_dir resolved: check `test -f $change_dir/change-impact.json`. Nếu không → WARNING "change-impact.json không tồn tại". Nếu có: validate `jq -e '."$schema" == "change-impact-v1"' change-impact.json` — fail → WARNING "Schema mismatch, expected change-impact-v1", skip. Pass → parse vào `$MANAGE_CHANGE_CONTEXT` (object). Log: "Manage-Change context: change=[change_dir], change-impact=[loaded|null]" | `$MANAGE_CHANGE_CONTEXT` set hoặc null |

> `$MANAGE_CHANGE_CONTEXT` sẽ được dùng trong Phase 5 (check 5.13 cross-check registry_changes[]) và Phase 6 (section "Change Impact Cross-Reference").
> Backward compat: nếu skip hoặc fail → `$MANAGE_CHANGE_CONTEXT = null`, downstream phases skip cross-check tương ứng.

---

## Steps — Preflight Impact Context Loading (v4.0+ S3 — `--from-preflight`)

> **Conditional:** Chỉ chạy khi `$HAS_FROM_PREFLIGHT_FLAG = true`. Mục đích: load `preflight-impact.json` từ wf-preflight session (session-scoped artifact, khác với `$PREFLIGHT_CONTEXT` từ flat path ở steps 0.11-0.15) để Phase 5 cross-check preflight findings + Phase 6 render Preflight Impact section.

| Step | Action | Verify |
|------|--------|--------|
| 0.29 | **Skip nếu flag không pass:** IF `$HAS_FROM_PREFLIGHT_FLAG != true` → set `$PREFLIGHT_IMPACT_CONTEXT = null`, jump to POST-GATE. ELSE → continue. | Branch decided |
| 0.30 | **Resolve session_dir:** IF `$FROM_PREFLIGHT_SESSION_ID` non-empty (user pass `=<id>`): set `$FROM_PREFLIGHT_SESSION_DIR=".mc-data/work/wf-preflight/sessions/$FROM_PREFLIGHT_SESSION_ID"`. Verify dir tồn tại — nếu không → WARNING "Session ID không tồn tại: $FROM_PREFLIGHT_SESSION_ID. Skip --from-preflight.", set `$PREFLIGHT_IMPACT_CONTEXT = null`, jump to POST-GATE. ELSE (auto-resolve): check `test -f .mc-data/work/wf-preflight/_index/sessions.jsonl` — nếu không tồn tại → WARNING "Index sessions.jsonl không tồn tại. wf-preflight chưa chạy?", skip. Auto-resolve: `LATEST_SID=$(jq -r 'select(.status=="completed") | .session_id' _index/sessions.jsonl | sort | tail -1)`. Nếu rỗng → WARNING "Không có completed session", skip. Set session_dir = `.mc-data/work/wf-preflight/sessions/$LATEST_SID`. | Session dir resolved hoặc null |
| 0.31 | **Load + validate preflight-impact.json:** IF session_dir resolved: check `test -f $session_dir/preflight-impact.json`. Nếu không → WARNING "preflight-impact.json không tồn tại trong session". Nếu có: validate `jq -e '."$schema" == "preflight-impact-v1"' preflight-impact.json` — fail → WARNING "Schema mismatch, expected preflight-impact-v1", skip. Pass → parse vào `$PREFLIGHT_IMPACT_CONTEXT` (object). Log: "Preflight-Impact context: session=[session_dir], preflight-impact=[loaded|null]" | `$PREFLIGHT_IMPACT_CONTEXT` set hoặc null |

> `$PREFLIGHT_IMPACT_CONTEXT` sẽ được dùng trong Phase 5 (check 5.14 cross-check preflight findings) và Phase 6 (section "Preflight Impact Cross-Reference").
> Lưu ý: `$PREFLIGHT_CONTEXT` (steps 0.11-0.15) là auto-load từ flat path — dùng cho backward compat. `$PREFLIGHT_IMPACT_CONTEXT` (flag `--from-preflight`) là load từ session-scoped artifact.
> Backward compat: nếu skip hoặc fail → `$PREFLIGHT_IMPACT_CONTEXT = null`, downstream phases skip cross-check tương ứng.

---

**POST-GATE:**
- `test -f .mc-data/docs/_meta/req-registry.json && (test -d src || test -d apps)`
- `test -n "$SESSION_ID" && test -d "$SESSION_DIR"`
- `test -s "$SESSION_DIR/verify-sync-status.json"`
- `test -s "$SESSION_DIR/checkpoint.json"`
- `$SCOPE_FILTER` đã build xong (non-empty hoặc all)
- `$REGISTRY_FINGERPRINT` set (non-empty string)
- `$PREFLIGHT_CONTEXT` set (object hoặc null — không undefined)
- `$FIX_REPORT_CONTEXT` set (object hoặc null — không undefined)
- **(v2.1+ S9):** `$FIX_IMPACT_CONTEXT` set (object hoặc null), `$DOCS_SYNC_CONTEXT` set (object hoặc null), `$FROM_FIX_BUGS_SESSION_DIR` set (string hoặc null)
- **(v4.0+ S3):** `$ADD_SCOPE_CONTEXT` set (object hoặc null), `$MANAGE_CHANGE_CONTEXT` set (object hoặc null), `$PREFLIGHT_IMPACT_CONTEXT` set (object hoặc null)

**NEXT:** Load `phase1-scan.md`.
