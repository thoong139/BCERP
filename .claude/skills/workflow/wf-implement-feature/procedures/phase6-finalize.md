# Phase 6: Update Status & Finalization

> Update registry + impl-status + task file + impl-report + phase-summary.
>
> **Protocol:** Registry Safe-Write (CORE-006) + Token Limit Prevention — xem `_shared.md §Registry Safe-Write`.
>
> **Entry path:**
> - Normal: sau khi phase5a-crossval.md PASS
> - VERIFY_ONLY shortcut: từ phase0-7-safety-gate.md Step 0.7.V4 (nhảy thẳng đến đây)

**Quy tắc:** CHỈ update field `impl_status` per REQ-ID. KHÔNG modify `systems`, `modules`, `design_status`, `implementation_order`.
Đọc registry NGAY TRƯỚC KHI GHI → ghi atomic → validate `jq '.'`.

**PRE-GATE:** Phase 5a PASSED HOẶC `$CONFIRMED_STRATEGY == "VERIFY_ONLY"`.

Cụ thể:
```bash
test -s "$SOURCE_FILE" && (
  test "$PHASE_5A_PASSED" = "true" ||
  test "$CONFIRMED_STRATEGY" = "VERIFY_ONLY"
)
```

---

## 📥 INPUT

- Registry (đọc ngay trước khi ghi)
- `impl-status.json`
- `[feature]-impl.md (Phần B)` — để đánh dấu tasks done

## 📤 OUTPUT

| File | Đường dẫn | Ghi chú |
|------|-----------|---------|
| Registry | `.mc-data/docs/_meta/req-registry.json` | CHỈ update `impl_status` per REQ-ID |
| Status file | `$SESSION_DIR/impl-status.json` | `status = completed`, update `last_qa_attempt_number`, append `run_history` |
| Feature tasks | `.mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feature]-impl.md (Phần B)` | Đánh dấu tất cả tasks done |
| Implementation report | `$SESSION_DIR/impl-report.md` | Template: `templates/impl-report.md` |
| Phase summary | `$SESSION_DIR/phase-summary.md` | CORE-028 — viết tiếng Việt |

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 6.1-CDG | **CDG-02 Pre-Check (CORE-027, Protocol 16)** — BẮT BUỘC khi registry đã có content cho REQ-ID này. Check: `jq -e --arg id "$REQ_ID" '.requirements[] \| select(.req_id==$id) \| .impl_status' registry.json`. Nếu current status là "done" và sắp set lại "done" (idempotent) → skip CDG. Nếu current status khác "not_started"/"in_progress" → trigger CDG-02: hiển thị current vs target status, user confirm Y/N. Reject → skip update, log session-log.json `CDG_REJECTED`. Accept → proceed. Log token vào `$SESSION_DIR/cdg-tokens.json`. | CDG logged |
| 6.1-LOCK | **[Cross-Process Mutex v4.0]** Acquire registry lock qua bash script: `bash .claude/scripts/wf-implement-feature/implement-acquire-lock.sh --type=registry --timeout=30 \|\| exit 1; trap "rm -f .mc-data/docs/_meta/.registry.lock" EXIT`. Xem `_shared.md §Cross-Process Mutex`. Nếu timeout 30s → log ERROR (E601, alias E011) + escalate user. | Lock acquired |
| 6.1 | Update `req-registry.json`: `impl_status = done` per REQ-ID (narrow per-field jq: `(.requirements[] \| select(.req_id==$id) \| .impl_status) = "done"`, KHÔNG replace toàn bộ `.requirements[]` array). Atomic write: tmp file → mv. **Sau khi mv thành công → ngay lập tức `rm -f .mc-data/docs/_meta/.registry.lock`** để session khác không bị block lâu. | Status updated, lock released |
| 6.2 | Update `impl-status.json`: `status = completed` | — |
| 6.3 | Update `[feature]-impl.md (Phần B)`: tất cả tasks done | All done |
| 6.4 | **[Template Rule]** READ `templates/impl-report.md` → populate với executive summary, progress, files, metrics, review results, TDD summary, requirements coverage, issues → WRITE `$SESSION_DIR/impl-report.md` | `test -s impl-report.md` |
| 6.5 | **Registry safe-write verify (v4.0 — bash):** `bash .claude/scripts/wf-implement-feature/implement-snapshot.sh --before=$REGISTRY_BEFORE_SNAPSHOT --after=.mc-data/docs/_meta/req-registry.json --req-ids="$REQ_IDS_IN_SCOPE" \| jq -e '.passed'`. Confirm CHỈ `impl_status` thay đổi. Mọi field khác phải giữ nguyên. Unexpected changes → ERROR E602 (alias E011) + escalate. | exit 0 |
| 6.5b | **[v4.0 Sprint 3] Populate `consumer_hints` trong impl-status.json (schema v2.0):** Compute 3 sub-sections (`wf-prepare-deployment`, `wf-fix-bugs`, `wf-verify-sync`) từ `impl-status.json` + `decision-registry.json`. Atomic write qua `tmp` + `mv`. Xem § Consumer Hints Population bên dưới. | `jq -e '.consumer_hints["wf-verify-sync"].req_ids_completed \| length > 0' impl-status.json` |
| 6.6 | Ghi COMPLETE vào `session-log.json` (CORE-026): `source .claude/scripts/wf-implement-feature/implement-common.sh; trace_event "COMPLETE" "$FEATURE_SLUG" "$SESSION_ID" '{"files_created":'$FILES_CREATED_COUNT'}'`. Cũng append entry vào `.history/implementations-index.jsonl` qua `bash .claude/scripts/wf-implement-feature/implement-history-index.sh --feature-slug=$FEATURE_SLUG --feat-id=$FEAT_ID --session-id=$SESSION_ID --status=completed --files-created=$FILES_CREATED_COUNT --files-modified=$FILES_MODIFIED_COUNT --tests-count=$TESTS_COUNT --scenario=$SCENARIO --profile=${PROFILE:-standard}`. | JSON appended |
| 6.7 | **[Template Rule v4.0 Sprint 3+4]** Tạo `phase-summary.md` (CORE-028): READ `templates/phase-summary.md` → populate fields ([FEATURE_NAME], [REQ-ID], [SESSION_ID], [PROFILE], [N counts], [F/G decision counts], section "Cho skill kế tiếp" với consumer_hints reference, **section "Errors & Warnings" từ `error-ledger.json`** — xem § Errors & Warnings Population bên dưới) → WRITE `$SESSION_DIR/phase-summary.md`. Viết tiếng Việt cho non-specialist. | `test -s phase-summary.md` AND `grep -q "Cho skill kế tiếp" phase-summary.md` AND `grep -q "Errors & Warnings" phase-summary.md` |
| 6.8 | **[Per-Feature Lock Release — BẮT BUỘC v3.2+]** Release lock: `rm -f ".mc-data/work/wf-implement-feature/.locks/$SYSTEM_SLUG/$FEATURE_SLUG.lock"`. Cũng release nếu Phase 6 fail (qua EXIT trap đã setup ở Phase 0.2c). Log: "Released per-feature lock for $FEATURE_SLUG". | Lock file removed |

---

## POST-GATE (v4.0 — delegated to bash, T1-T4 tiered per Protocol 10 + CORE-012)

```bash
bash .claude/scripts/wf-implement-feature/implement-postgate.sh \
  --session-dir="$SESSION_DIR" \
  --req-ids="$REQ_IDS_IN_SCOPE" \
  --registry=".mc-data/docs/_meta/req-registry.json"
# Exit 0 = T1-T4 all pass
# Exit 1 = một hoặc nhiều T fail → trigger auto-fix (max 3 retries) hoặc escalate (E602, alias E011)
```

Script handle (chi tiết tham khảo `implement-postgate.sh`):
- **T1** — Existence + non-empty: `test -s` cho registry + impl-report.md + phase-summary.md + impl-status.json
- **T2** — Structure: required sections (`## Quality Metrics`, `## Requirements Coverage`, `## Đã làm gì`, `## Kết quả chính`)
- **T3** — Content depth: phase-summary ≥ 50 words, impl-report ≥ 100 words
- **T4.1** — Registry JSON valid + `impl_status == "done"` cho tất cả REQ-IDs in scope
- **T4.2** — REQ-ID comment present trong ít nhất 1 file đã tạo/sửa (warning, không fail strict mode)
- **T4.3** — Registry safe-write verify (Step 6.5 đã chạy `implement-snapshot.sh`)

Output JSON từ script: `{passed, T1, T2, T3, T4, failures: [...], warnings: [...], details: {...}}`. Caller dùng `jq -e '.passed'` để gate. Nếu fail → log details vào error-ledger.json (Sprint 4) + auto-fix retry. Sau 3 lần fail → escalate user.

---

## Consumer Hints Population (Step 6.5b — v4.0 Sprint 3)

> Populate 3 sub-sections trong `impl-status.json.consumer_hints` để 3 consumer skills (`wf-prepare-deployment`, `wf-fix-bugs`, `wf-verify-sync`) có thể đọc qua `--from-impl` (Q1: chưa modify trong v4.0).
> Schema v2.0 định nghĩa tại `templates/impl-status.schema.md § consumer_hints`.

```bash
IMPL_STATUS="$SESSION_DIR/impl-status.json"
DECISION_REG="$SESSION_DIR/decision-registry.json"
TMP=$(mktemp)

# 1) wf-prepare-deployment hints
#    - files_for_changelog: files_created + files_modified, exclude tests
#    - breaking_changes: decisions có category="breaking" (v3.x decisions chưa có flag → empty default)
#    - migrations_required: bất kỳ file nào path khớp /migrations/
#    - feature_summary_vi: từ feature.name (Vietnamese-friendly title)

# 2) wf-fix-bugs hints
#    - scope_modules: [feature.module] (1 entry — feature implement scope)
#    - test_files_added: files match \.(test|spec)\.[a-z]+$
#    - decision_ids_new: tất cả decision IDs append trong session
#    - implementation_strategy_used: scenario uppercased (NEW → IMPLEMENT_NEW; extend/modify → COMPLETE_EXISTING)

# 3) wf-verify-sync hints
#    - req_ids_completed: [feature.req_id] (per-feature scope)
#    - files_with_req_id: count files chứa "REQ-ID:" comment
#    - session_dir: $SESSION_DIR (resolve relative path)

# Compute decision IDs from decision-registry.json (graceful nếu không tồn tại)
if [[ -f "$DECISION_REG" ]]; then
  DECISION_IDS_JSON=$(jq -c '[.decisions[]?.id // empty]' "$DECISION_REG")
  BREAKING_JSON=$(jq -c '[.decisions[]? | select(.category == "breaking" or .is_breaking == true) | .id]' "$DECISION_REG")
else
  DECISION_IDS_JSON='[]'
  BREAKING_JSON='[]'
fi

# Files lists (từ existing impl-status.json fields)
FILES_CREATED_JSON=$(jq -c '[.metrics.files_created_list[]? // empty]' "$IMPL_STATUS" 2>/dev/null || echo '[]')
FILES_MODIFIED_JSON=$(jq -c '[.metrics.files_modified_list[]? // empty]' "$IMPL_STATUS" 2>/dev/null || echo '[]')

# Compute strategy mapping
SCENARIO=$(jq -r '.scenario // "new"' "$IMPL_STATUS" | tr -d '\r')
case "$SCENARIO" in
  new)    STRATEGY="IMPLEMENT_NEW" ;;
  extend|modify) STRATEGY="COMPLETE_EXISTING" ;;
  *)      STRATEGY="IMPLEMENT_NEW" ;;
esac

# Count files với REQ-ID comment (best-effort)
REQ_ID=$(jq -r '.feature.req_id' "$IMPL_STATUS" | tr -d '\r')
if [[ -n "$REQ_ID" && "$REQ_ID" != "null" ]]; then
  FILES_WITH_REQ_ID=$(grep -rcl "REQ-ID:.*$REQ_ID" --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' --include='*.py' --include='*.go' --include='*.java' . 2>/dev/null | wc -l | tr -d ' \r' || echo 0)
else
  FILES_WITH_REQ_ID=0
fi

# Atomic write
jq \
  --argjson files_created "$FILES_CREATED_JSON" \
  --argjson files_modified "$FILES_MODIFIED_JSON" \
  --argjson decision_ids "$DECISION_IDS_JSON" \
  --argjson breaking "$BREAKING_JSON" \
  --arg strategy "$STRATEGY" \
  --arg session_dir "$SESSION_DIR" \
  --arg files_with_req_id "$FILES_WITH_REQ_ID" \
  '
    ($files_created + $files_modified) as $all_files
    | (
        # files_for_changelog: exclude test/spec files
        [$all_files[] | select(test("\\.(test|spec)\\.[a-z]+$") | not)]
      ) as $changelog_files
    | (
        # test_files_added: only test/spec
        [$files_created[] | select(test("\\.(test|spec)\\.[a-z]+$"))]
      ) as $test_files
    | (
        # migrations_required: bất kỳ path chứa /migrations/
        [$all_files[] | select(test("/migrations/"))] | length > 0
      ) as $needs_migration
    | .consumer_hints["wf-prepare-deployment"] = {
        files_for_changelog: $changelog_files,
        breaking_changes: $breaking,
        migrations_required: $needs_migration,
        feature_summary_vi: (.feature.name // "")
      }
    | .consumer_hints["wf-fix-bugs"] = {
        scope_modules: [(.feature.module // "")] | map(select(. != "")),
        test_files_added: $test_files,
        decision_ids_new: $decision_ids,
        implementation_strategy_used: $strategy
      }
    | .consumer_hints["wf-verify-sync"] = {
        req_ids_completed: [(.feature.req_id // "")] | map(select(. != "")),
        files_with_req_id: ($files_with_req_id | tonumber),
        session_dir: $session_dir
      }
  ' "$IMPL_STATUS" > "$TMP" \
  && mv "$TMP" "$IMPL_STATUS" \
  || { echo "[ERROR] Failed to populate consumer_hints"; rm -f "$TMP"; exit 1; }

# Verify size cap (≤ 500 bytes per sub-section, log warning nếu vượt)
for SUB in "wf-prepare-deployment" "wf-fix-bugs" "wf-verify-sync"; do
  SIZE=$(jq ".consumer_hints[\"$SUB\"]" "$IMPL_STATUS" | wc -c | tr -d ' \r')
  if (( SIZE > 500 )); then
    echo "[WARN E102] consumer_hints.$SUB = $SIZE bytes > 500 cap"
  fi
done
```

> **Backward compat:** Nếu `metrics.files_created_list[]` không tồn tại (v3.x compat), fallback `[]` — empty arrays an toàn cho consumers.
>
> **Cross-platform:** `tr -d '\r'` sau mọi `jq -r` (Git Bash Windows safety, pattern từ Sprint 1+2).
>
> **Error handling:** Nếu `mv` fail → cleanup tmp + exit 1 (E602 alias E011). Step 6.5b BLOCK Phase 6 hoàn thành nếu không write thành công.

---

## Errors & Warnings Population (Step 6.7 — v4.0 Sprint 4)

> Phase summary có section "Errors & Warnings" populate từ `error-ledger.json`. Nếu file không tồn tại (zero errors during session) → render single line "✅ Không có lỗi hoặc cảnh báo trong session này."

```bash
LEDGER="$SESSION_DIR/error-ledger.json"

if [[ ! -f "$LEDGER" ]]; then
  ERRORS_SECTION="✅ Không có lỗi hoặc cảnh báo trong session này."
else
  CRITICAL=$(jq -r '[.errors[] | select(.severity == "critical")] | length' "$LEDGER" 2>/dev/null || echo 0)
  ERRORS=$(jq -r '[.errors[] | select(.severity == "error")] | length' "$LEDGER" 2>/dev/null || echo 0)
  WARNINGS=$(jq -r '[.errors[] | select(.severity == "warning")] | length' "$LEDGER" 2>/dev/null || echo 0)
  INFO=$(jq -r '[.errors[] | select(.severity == "info")] | length' "$LEDGER" 2>/dev/null || echo 0)

  # Render từng nhóm:
  # - Critical: list đầy đủ (mỗi entry dòng `[code] phase: message`)
  CRITICAL_LIST=$(jq -r '.errors[] | select(.severity == "critical") | "- [\(.code)] \(.phase): \(.message)"' "$LEDGER" 2>/dev/null)
  [[ -z "$CRITICAL_LIST" ]] && CRITICAL_LIST="Không có"

  # - Errors: phân nhóm auto_resolved vs escalated
  ERRORS_RESOLVED=$(jq -r '.errors[] | select(.severity == "error" and .auto_resolved == true) | "- [\(.code)] \(.phase): \(.message)"' "$LEDGER" 2>/dev/null)
  ERRORS_ESCALATED=$(jq -r '.errors[] | select(.severity == "error" and .auto_resolved == false) | "- [\(.code)] \(.phase): \(.message)"' "$LEDGER" 2>/dev/null)

  # - Warnings: short list, top 5 + count
  WARN_TOP=$(jq -r '[.errors[] | select(.severity == "warning") | .code] | unique | join(", ")' "$LEDGER" 2>/dev/null)

  # Build section content và replace [Liệt kê...] placeholders trong template

  # Nếu CRITICAL=0 AND ERRORS=0 AND WARNINGS=0 AND INFO=0:
  #   ERRORS_SECTION="✅ Không có lỗi hoặc cảnh báo trong session này."
fi

# Inject vào phase-summary.md sau khi populate template
```

**Verify sau write:**
```bash
grep -q "Errors & Warnings" "$SESSION_DIR/phase-summary.md"
```

---

## Output Report Template (cho final message)

```markdown
## Implementation Complete: [Feature Name]

**Scenario:** NEW / EXTEND / MODIFY | **Sessions:** X

### Phase Summary
| Phase | Status |
|-------|--------|
| Phase 0: Analysis | Done / SKIP |
| Phase 1–2: Context & Planning | Done |
| Phase 3: TDD Implementation | Done |
| Phase 4–5: Review-Fix Loop | Done (attempt N/3) |
| Phase 5a: Cross-Validation | Done |
| Phase 6: Finalize | Done |

### Quality Metrics
| Metric | Value |
|--------|-------|
| Files created | X |
| Tests written / passing | Y / Y |
| Test coverage | Z% |

Next: `/wf-verify-sync` để verify full project sync
```
