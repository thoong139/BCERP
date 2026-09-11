# Phase 1: Feature Context

> Load feature specification + task file + architecture digest → chuẩn bị cho implementation.
>
> **PRE-GATE Digest Loading** (Phiên 6 — Digest Pipeline) được chạy đầu tiên để nhanh chóng load upstream context.

**PRE-GATE:** `test -n "$ARGUMENTS"`

> **Forensic validation (Protocol 10.4):** task-impl.md phải có >= 6 headings, >= 400 words.
> Nếu FAIL → "Implementation plan không đạt yêu cầu nội dung. Chạy `/wf-plan-modules` để hoàn thiện."
> Nếu file không tồn tại → xử lý theo **E201 (alias E004b)** (xem `_shared.md §Error Codes Reference`).

---

## PRE-GATE Digest Loading (Phiên 6 — Digest Pipeline)

> Đọc `feature-briefs.json` + `design-input-digest.json` từ upstream để nhanh chóng lên tốc độ.
> Fallback vào đọc full `phase2-features/` + `phase3-architecture/` docs nếu digests không tồn tại.

| Step | Action | Verify |
|------|--------|--------|
| 0.1 | Kiểm tra `feature-briefs.json` tồn tại ở `.mc-data/docs/_meta/` | Nếu có → đọc; nếu không → fallback đọc full phase2 docs |
| 0.2 | Kiểm tra `design-input-digest.json` tồn tại ở `.mc-data/docs/_meta/` | Nếu có → đọc; nếu không → fallback đọc full phase3 docs |
| 0.3 | Inject context vào state từ digests hoặc full docs | Context sẵn sàng |

---

## 📥 INPUT

| File | Đường dẫn |
|------|-----------|
| Registry | `.mc-data/docs/_meta/req-registry.json` |
| Feature design | `.mc-data/docs/phase2-features/[sys]/[mod]/[feature].md` |
| Implementation plan | `.mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feature]-impl.md` |
| Implementation roadmap | `.mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md` |
| Stakeholder review | `.mc-data/docs/phase5-implementation/stakeholder-review.md` |
| Design summary *(optional)* | `.mc-data/work/wf-design/design-summary.json` |
| Checkpoint (nếu `--resume`) | `$SESSION_DIR/checkpoint.json` |

## 📤 OUTPUT

`$SESSION_DIR/impl-status.json` (template: `templates/impl-status.json`)

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 1.1  | Parse arguments → extract REQ-ID | ID found |
| 1.2  | Nếu `--status` → hiển thị và exit | — |
| 1.2b | Check `impl-status.json` trong `$FEATURE_SLUG` dir → xử lý theo **Multi-Run Logic** (SKILL.md) | Action determined |
| 1.3  | `mkdir -p $SESSION_DIR/` | Directory exists |
| 1.4  | Đọc `req-registry.json` → tìm feature theo FEAT-ID hoặc REQ-ID | Feature found |
| 1.4a | **[Finding #1 — Upstream Registry Inconsistency Fallback v3.4+]** Sau khi tìm thấy feature, lookup `requirements[req_id == feature.req_ids[0]]`. Nếu KHÔNG TỒN TẠI → graceful fallback: derive `$REQUIREMENT_DESC` từ `feature.title + ". " + feature.notes` (hoặc `feature.acceptance_criteria` nếu có). Log WARNING vào `impl-status.json.warnings[]`: `"upstream_registry_inconsistency: REQ-ID [X] referenced trong features[].req_ids nhưng không có entry trong requirements[]. Description derived từ feature.title+notes. Khuyến nghị: chạy `/wf-analyze-requirements` để bổ sung requirement entry."`. KHÔNG block — tiếp tục. | `$REQUIREMENT_DESC` set, warning logged nếu fallback |
| 1.5  | Đọc feature design — **NẾU KHÔNG TÌM THẤY → STOP (E202, alias E004a)** + `ledger_log "E202" "phase1-feature-context" "critical" "Feature design missing" '{"design_path":"$FEATURE_DESIGN_FILE"}' false` | Design loaded |
| 1.6  | Đọc implementation plan — **NẾU KHÔNG TÌM THẤY → xử lý theo E201 (alias E004b)** | Plan loaded |
| 1.6a | **[Phiên 7 - A6-EXT]** Kiểm tra A6-EXT section trong task file. **STUB DETECTION (BẮT BUỘC):** IF A6-EXT chứa marker `**STUB**` HOẶC `Stage 4 Phase B không spawn architect` HOẶC chỉ có Coverage Summary với placeholder `[...]` → SET `$A6_EXT_STATE = "stub"`, `$EXECUTABLE_SPEC = ""` (force fallback to full Phase 1-3 docs), SET `$A6_EXT_NEEDS_POPULATE = true`. IF A6-EXT có method signatures + cross-file contracts đầy đủ → SET `$A6_EXT_STATE = "complete"`, lưu nội dung vào `$EXECUTABLE_SPEC`. IF A6-EXT không tồn tại → SET `$A6_EXT_STATE = "absent"`, `$EXECUTABLE_SPEC = ""`. Lưu ý: A6-EXT có thể được populate ở Phase 2.4 nếu STUB. | `$A6_EXT_STATE` set |
| 1.7  | Detect scenario (NEW/EXTEND/MODIFY) từ design + flags | `$SCENARIO` set |
| 1.7a | IF `$LEGACY_MODE` AND `$DEPRECATED_MODULES` không rỗng: extract module của feature từ registry. IF module ∈ `$DEPRECATED_MODULES` → WARN + AskUserQuestion: "Vẫn muốn implement không?" Options: [Tiếp tục] / [Dừng — skip]. IF dừng → set `impl_status = "skipped"` → STOP. | Module check done |
| 1.8  | **[Template Rule]** READ `templates/impl-status.json` → populate với feature info, scenario, session, phases → WRITE `$SESSION_DIR/impl-status.json`. Hoặc nếu file đã tồn tại: update theo Multi-Run Logic. **CORE-006:** `feature.req_id` PHẢI chỉ chứa REQ-ID của feature đang implement (từ registry `features[].req_id`). KHÔNG bao gồm REQ-IDs của features khác trong cùng module. **[Finding #5 — Complexity derivation v3.4+]** Compute `feature.complexity` theo rule trong `templates/impl-status.schema.md §Complexity derivation rule`: ưu tiên `task_file.effort_estimate` (≤1h=simple, ≤4h=medium, >4h=complex); fallback theo file count trong A2.4 (≤3=simple, ≤10=medium, >10=complex); default=`medium`. Validate sau write: `jq -e '.feature.complexity \| IN("simple","medium","complex")' impl-status.json`. | `test -s impl-status.json && jq -e '.feature.complexity \| IN("simple","medium","complex")'` |
| 1.9  | **[C1 Compressed Spec]** Load `design-summary.json` nếu tồn tại: đọc entry cho module hiện tại → lưu vào `$DESIGN_SUMMARY`. Nếu không → fallback: Grep key sections từ `api-contract.md`, `database-design.md`, `integration-map.md`. | Summary hoặc fallback loaded |
| 1.10 | **[v5.2+ Fix-Impact Context Loading]** IF `$HAS_FROM_FIX_BUGS_FLAG != true` → set `$FIX_IMPACT_CONTEXT = null`, skip. ELSE → resolve session: nếu `$FROM_FIX_BUGS_SESSION_ID` non-empty → `FROM_DIR=".mc-data/work/wf-fix-bugs/sessions/$FROM_FIX_BUGS_SESSION_ID"`; nếu không → auto-resolve `LATEST_SID=$(jq -r 'select(.status=="completed")\|.session_id' .mc-data/work/wf-fix-bugs/_index/sessions.jsonl 2>/dev/null \| sort \| tail -1)`. Verify `test -d "$FROM_DIR" && test -s "$FROM_DIR/fix-impact.json"`. Validate schema: `jq -e '."$schema" == "fix-impact-v1"' "$FROM_DIR/fix-impact.json"`. Pass → load vào `$FIX_IMPACT_CONTEXT`. Fail / file missing → WARNING "fix-impact.json không tồn tại hoặc schema mismatch — skip --from-fix-bugs", set null, continue. | `$FIX_IMPACT_CONTEXT` set hoặc null |
| 1.11 | **[v5.2+ Feature-Code Match]** IF `$FIX_IMPACT_CONTEXT != null`: extract `code_files[].path` từ `affected_artifacts.code_files[]`. Filter những path có substring chứa `$FEATURE_SLUG` (case-insensitive). Lưu vào `$FIX_RELATED_CODE_FILES` (array). Compute `$FIX_RELATED_COUNT = length`. Nếu `>0` → log "Fix-Impact: $FIX_RELATED_COUNT code files đã được fix touch trong feature này — sẽ ưu tiên review existing code (CORE-020)". Append vào `impl-status.json.warnings[]`: `"fix_impact_context: $FIX_RELATED_COUNT code files từ wf-fix-bugs session [SID] trùng feature slug. Recommend review trước khi implement new code."`. Nếu `==0` → log "Fix-Impact: không có code files trùng feature slug — không có action item từ context". | `$FIX_RELATED_CODE_FILES` set hoặc empty |

**POST-GATE:** `test -n "$FEATURE_NAME" && test -n "$REQ_ID" && test -s "$FEATURE_DESIGN_FILE"`

---

## Error Handling (E2xx series — v4.0 namespaced)

### E202 (alias E004a) — Feature design không tồn tại
STOP. "Feature design chưa có. Chạy `/wf-design` trước."
Log: `ledger_log "E202" "phase1-feature-context" "critical" "Feature design not found"`.

### E201 (alias E004b) — Implementation plan không tồn tại

1. Kiểm tra `implementation_order` trong registry:
   - Nếu KHÔNG có → STOP: "Chưa có kế hoạch triển khai. Chạy `/wf-plan-modules` trước." Log: `ledger_log "E201" "phase1-feature-context" "critical" "Task file + impl order missing"`.
   - Nếu CÓ nhưng thiếu task file → **FALLBACK:** tự generate task stub từ feature design + roadmap:
     Tạo `[feat]-impl.md` với nội dung cơ bản. Log: `ledger_log "E201" "phase1-feature-context" "warning" "Task file fallback-generated" '{"feat":"$FEATURE_SLUG"}' true` (auto_resolved=true). Tiếp tục bình thường.
2. Nếu cả registry lẫn design đều thiếu → STOP: "Chạy `/wf-plan-modules` trước."

---

## Output State Variables

| Variable | Set | Consumed by |
|----------|-----|-------------|
| `$FEATURE_NAME` | From registry.features[].title | phase3 (agent context) |
| `$REQ_ID` | From registry.features[].req_id | phase3, phase5a, phase6 |
| `$FEATURE_DESIGN_FILE` | Path to phase2-features/... | phase0-7, phase2 |
| `$TASK_FILE` | Path to phase5-implementation/tasks/... | phase0-7, phase2, phase3 |
| `$SCENARIO` | NEW / EXTEND / MODIFY | phase2, phase3 |
| `$EXECUTABLE_SPEC` | A6-EXT content (nếu complete) hoặc "" | phase3 (agent context) |
| `$A6_EXT_STATE` | `complete` / `stub` / `absent` | phase2 (populate gate), phase3 |
| `$A6_EXT_NEEDS_POPULATE` | true/false | phase2 (populate gate) |
| `$DESIGN_SUMMARY` | From design-summary.json hoặc fallback grep | phase3 (agent context) |
| `$REQUIREMENT_DESC` | Step 1.4a — từ requirements[] hoặc fallback features.title+notes | phase3 (agent context — when registry inconsistent) |
| `$FIX_IMPACT_CONTEXT` | Step 1.10 — fix-impact.json từ wf-fix-bugs session (v5.2+) | phase0-7 (safety-gate — pre-fix overlap check), phase3 (agent context warning) |
| `$FIX_RELATED_CODE_FILES` | Step 1.11 — code_files trùng `$FEATURE_SLUG` | phase0-7, phase3 |
