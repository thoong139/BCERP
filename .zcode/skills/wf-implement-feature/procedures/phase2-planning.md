# Phase 2: Planning

> Chia nhỏ feature thành tasks + batches, ước lượng token, lên checkpoint strategy.
>
> **Protocols tham chiếu:** Protocol 9 (PLN-10 token estimates), Template Rule (CORE-031).

**PRE-GATE:** `test -n "$FEATURE_NAME"` AND `$CONFIRMED_STRATEGY != "VERIFY_ONLY"`

> Nếu `$CONFIRMED_STRATEGY == VERIFY_ONLY` → orchestrator skip file này.

**📥 INPUT:**
- Implementation plan (`phase5-implementation/tasks/`)
- Feature design
- `existing-patterns.json` (nếu EXTEND/MODIFY)
- `$GAPS_IDENTIFIED` (nếu COMPLETE_EXISTING)

**📤 OUTPUT:** `$SESSION_DIR/impl-plan.md` (template: `templates/impl-plan.md`)

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 2.0 | **[Template Rule]** READ `templates/impl-plan.md` → xác định sections cần populate | Template loaded |
| 2.0a | **[Finding #14 — Test Framework Detect v3.4+]** Detect test framework từ project files. Set `$TEST_FRAMEWORK` để inject vào template (thay placeholder "Jest / Vitest"). Detect logic (theo thứ tự ưu tiên): <br>• `package.json`: grep `"vitest"` → `Vitest`; `"jest"` → `Jest`; `"mocha"` → `Mocha`; `"@playwright/test"` → `Playwright`; `"cypress"` → `Cypress`. <br>• `pyproject.toml` hoặc `setup.cfg`: grep `pytest` → `pytest`; `unittest` → `unittest`. <br>• `*.csproj`: grep `xunit` → `xUnit`; `nunit` → `NUnit`; `MSTest` → `MSTest`. <br>• `go.mod`: default → `go test`. <br>• `Cargo.toml`: default → `cargo test`. <br>• `pom.xml`: grep `junit-jupiter` → `JUnit 5`; `junit` → `JUnit 4`. <br>Nếu không detect được → fallback `Jest / Vitest` (default JS) + log WARNING. Cache vào `$SESSION_DIR/test-framework.txt`. | `$TEST_FRAMEWORK` set |
| 2.0b | **[Sprint 2 — Profile Resolve v4.0+]** Resolve `$PROFILE` (quick/standard/deep/exhaustive). <br>• Parse `--profile=<name>` flag từ `$ARGUMENTS` → `$PROFILE_OVERRIDE`. <br>• Đếm scope files: ưu tiên `jq -r '.scope_files_exclusive | length' .mc-data/work/wf-implement-feature/.locks/$SYSTEM_SLUG/$FEATURE_SLUG.lock` (set bởi Phase 0.7 sau A2.4 parse); fallback đếm files trong A6 implementation strategy nếu lock chưa có. Set `$SCOPE_FILES_COUNT`. <br>• Resolve: `$PROFILE=$(bash .claude/scripts/wf-implement-feature/implement-resolve-profile.sh --scope-files-count=$SCOPE_FILES_COUNT --profile-override=$PROFILE_OVERRIDE)`. Lưu vào `$SESSION_DIR/profile.txt`. <br>• **Profile → flag interaction:** <br>&nbsp;&nbsp;- `quick` → IF `--parallel` set → log WARN "[PROFILE] --parallel ignored với profile=quick (sequential by design)" + force `$PARALLEL_MODE=false`. <br>&nbsp;&nbsp;- `deep` hoặc `exhaustive` → IF `--parallel` chưa set → log INFO "[PROFILE] Auto-enable parallel mode cho profile=$PROFILE" + set `$PARALLEL_MODE=true`. <br>&nbsp;&nbsp;- `standard` → giữ nguyên `$PARALLEL_MODE` từ flags. | `$PROFILE` ∈ {quick,standard,deep,exhaustive}; profile.txt tồn tại |
| 2.1 | Đọc implementation plan | Plan loaded |
| 2.2 | **[Finding #13 — A7-EXT Reconciliation v3.4+]** Routing rõ ràng cho task derivation: <br>• **IF** task file có A7-EXT section với micro-tasks (grep `^### A7-EXT` hoặc `MT-FEAT-` markers) → `$TASK_LIST` = parse A7-EXT micro-tasks; `$BATCHES` = group theo "Depends on" field. <br>&nbsp;&nbsp;&nbsp;&nbsp;**IF** `$CONFIRMED_STRATEGY == COMPLETE_EXISTING` AND `$GAPS_IDENTIFIED` không rỗng → filter micro-tasks chỉ giữ những task có `affects_files[]` intersect với `$GAPS_IDENTIFIED.scope_files[]`. Log: `"[A7-EXT-FILTER] Giữ N/M tasks (M-N skipped vì không thuộc gap scope)"`. <br>• **ELIF** `$CONFIRMED_STRATEGY == COMPLETE_EXISTING` AND `$GAPS_IDENTIFIED` không rỗng → derive tasks trực tiếp từ gaps. <br>• **ELSE** → derive tasks từ A6 (Implementation Strategy) + feature design acceptance criteria. <br>Log routing decision: `"[TASK-SOURCE] Mode=[A7_EXT_FILTERED|A7_EXT_FULL|GAPS_DERIVED|A6_DESIGN_DERIVED]"`. | Task list ready, source logged |
| 2.3 | Xác định files cần tạo/sửa + estimate complexity | File paths mapped |
| 2.4 | **Lên kế hoạch batches theo context budget + profile.** <br>• `$PROFILE == quick` → ưu tiên 1 batch chứa toàn bộ files nếu fit context budget (≤ 3 files thường gộp được); chỉ split khi vượt 80% context. Mode = SEQUENTIAL. <br>• `$PROFILE == standard` → 2-3 batches sequential theo dependency. Default behavior v3.x. <br>• `$PROFILE == deep` → multi-batches với parallel waves (Wave 1 = files độc lập, Wave 2 = files phụ thuộc Wave 1, ...). Cần `phase2-5-contracts.md` chạy trước. <br>• `$PROFILE == exhaustive` → giống deep + thêm batch e2e tests cuối cùng. <br>Annotation_only batch (REQ-ID injection) luôn 1 batch riêng regardless of profile (token saving). | Batches set, mode hợp lệ với profile |
| 2.5 | **[PLN-10] Token Estimates:** Thêm cột `Est. Token` vào batch table trong `impl-plan.md` | Estimates added |
| 2.6 | **[PLN-10] Checkpoint Strategy:** Thêm section "Checkpoint Strategy" — xác định checkpoint sau batch nào, resume points | Strategy documented |
| 2.7 | Populate template với tasks, batches, estimates → WRITE `$SESSION_DIR/impl-plan.md` + update `impl-status.json` | `test -s impl-plan.md` |
| 2.7b | **(RESUME RECONCILIATION — chỉ khi `--resume`)** Với mỗi file dự kiến: check `test -f [file] && test -s [file]`. Xác định `files_done[]` + `files_remaining[]`. Cập nhật checkpoint. Log: "Reconciled: [N] code files đã có — tiếp tục từ [first remaining]". | Reconciliation done |

---

## [PLN-10] impl-plan.md Batch Table Format

```markdown
### Batch Plan

| Batch | Files | Tasks | Mode | Dependencies | Est. Token |
|-------|-------|-------|------|-------------|------------|
| B1 | auth.service.ts, auth.controller.ts | T1, T2 | PARALLEL | — | ~8K |
| B2 | user.service.ts | T3 | SEQUENTIAL | B1 | ~5K |

### Checkpoint Strategy
- Checkpoint after: B1 (foundation files done), B3 (nếu có)
- Resume point: Batch number + completed files list
- Context threshold: 80% → force checkpoint trước batch tiếp theo
```

---

**POST-GATE:** `test -n "$TASK_LIST" && test -n "$BATCHES" && test -s $SESSION_DIR/impl-plan.md`

---

## Output State Variables

| Variable | Set | Consumed by |
|----------|-----|-------------|
| `$TASK_LIST` | Tasks breakdown | phase3 (3.0+) |
| `$BATCHES` | Batch plan với files + tasks | phase3 (batch loop) |
| `$TOKEN_ESTIMATES` | Per-batch token estimates | phase3 (proactive budget 9.6) |
| `$TEST_FRAMEWORK` | Detected từ project files | phase3 (TDD agent context) |
| `$TASK_SOURCE_MODE` | A7_EXT_FILTERED / A7_EXT_FULL / GAPS_DERIVED / A6_DESIGN_DERIVED | impl-plan.md (audit log) |
| `$PROFILE` | quick / standard / deep / exhaustive (Sprint 2 v4.0+) | phase3 (mode), phase4-5 (agent set), impl-status.json (`profile` field) |
| `$PARALLEL_MODE` | Có thể được force bởi profile=quick (false) hoặc auto-enable bởi deep/exhaustive (true) | phase2-5-contracts, phase3 |

---

## Routing sau Phase 2

```
$PARALLEL_MODE đã được resolve ở Step 2.0b dựa trên flags + profile:
  - profile=quick → force $PARALLEL_MODE=false
  - profile=deep|exhaustive → auto-enable $PARALLEL_MODE=true (nếu chưa set)
  - profile=standard → giữ nguyên flag từ user

IF $PARALLEL_MODE == true:
  → Load phase2-5-contracts.md TRƯỚC khi load phase3
ELSE:
  → Load phase3-tdd.md trực tiếp (sequential mode)
```
