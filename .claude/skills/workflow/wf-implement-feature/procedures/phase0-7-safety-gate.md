# Phase 0.7: Pre-Implementation Safety Gate (CORE-020)

> **BLOCKING GATE** — Phải hoàn thành trước khi viết bất kỳ code nào.
>
> - **LEGACY_MODE:** Chạy FULL gate (3 modes: VERIFY_ONLY / COMPLETE_EXISTING / IMPLEMENT_NEW)
> - **NEW project:** Chạy lightweight search — nếu tìm thấy code liên quan → cảnh báo + hỏi user
>
> **Thứ tự:** Chạy SAU phase1-feature-context.md (cần `$TASK_FILE` loaded).
> Tên "0.7" giữ theo naming convention cũ để không vỡ cross-references.

**PRE-GATE:** Phase 1 Feature Context đã hoàn thành (`$FEATURE_NAME`, `$REQ_ID`, `$TASK_FILE` set)

---

## BƯỚC 1: Đọc Task File → Xác định Strategy

| Step | Action | Verify |
|------|--------|--------|
| 0.7.1 | Đọc task file `[feat]-impl.md` → tìm section `## ⚠️ Implementation Strategy` | Strategy found (hoặc null nếu new project) |
| 0.7.2 | Extract `implementation_strategy`: VERIFY_ONLY / COMPLETE_EXISTING / IMPLEMENT_NEW / null | Strategy set |
| 0.7.3 | Extract `existing_code_refs` và `gaps_identified` nếu có | Refs loaded |
| 0.7.3a | **[A2.4 Scope Files — Cross-Feature Conflict Check]** Extract section `#### A2.4 Scope Files` từ task file → parse bảng → set `$SCOPE_FILES` (list `{path, mode, shared_with[]}`) + `$PARALLEL_VERDICT`. Xem §A2.4 Cross-Feature Conflict Detection. Nếu A2.4 thiếu → log WARNING + `$PARALLEL_VERDICT="UNKNOWN"` (treat conservative — chỉ 1 session active được phép cho feature này). | Scope files loaded |

---

## BƯỚC 2: Double-check Độc lập (Safety Net)

> Chạy BẤT KỂ strategy trong task file nói gì. Đây là verification độc lập.

### CI-ROUTE: find_existing_code (Protocol 20 §20.5)

> **Khi CI tools available:** Dùng CI-ROUTE thay vì Grep. Graceful degradation: mỗi tier fail → fallback tier tiếp theo.
> **Khi index stale (>0 behind):** kết quả kèm caveat "Index N commits behind. Results may be incomplete."

| CI Task | Tool chính | Tool bổ trợ | Fallback |
|---------|-----------|-------------|----------|
| `find_definition` (entity/model) | **Serena** `find_definition` | — | Concrete Grep (bên dưới) |
| `find_references` (service/component) | **Serena** `find_references` | **GitNexus** `context()` | Concrete Grep (bên dưới) |
| `impact_analysis` (MODIFY only) | **GitNexus** `impact({symbol}, upstream)` | — | Manual trace |
| `api_routes` (endpoint paths) | **GitNexus** `route_map()` | — | Concrete Grep (bên dưới) |

**MODIFY scenario CI impact check:** Trước BƯỚC 3, nếu `$CONFIRMED_STRATEGY ∈ {MODIFY, COMPLETE_EXISTING}`:
1. CI-ROUTE `impact_analysis` cho mỗi entity/service name từ feature spec
2. Nếu GitNexus `impact()` returns HIGH/CRITICAL risk → **CDG render (CORE-027)** với blast radius report
3. Nếu index stale: CDG thêm dòng "Warning: index N commits behind. Blast radius may be incomplete."

### Concrete Grep Patterns (Fallback — BẮT BUỘC v3.3+ — Finding #10)

| Pattern Type | Regex | Example match |
|--------------|-------|---------------|
| Entity/Model | `(class\|interface\|type)\s+[A-Z]\w+(Entity\|Model\|Schema\|Dto\|Type)` | `class CustomerEntity`, `interface UserDto` |
| Endpoint | `(POST\|GET\|PUT\|DELETE\|PATCH)[\s\(\[\"']{1,3}/[\w/-]+` | `POST /api/login`, `app.get("/users")` |
| Component | `(function\|const)\s+[A-Z]\w+\s*[:=(<]` (loại trừ files .test.tsx) | `function LoginForm`, `const UserCard = ` |
| Service | `(class\|export)\s+\w+(Service\|Repository\|Manager\|Handler\|Controller)` | `class AuthService`, `export class UserRepo` |
| Hook | `(export\s+)?function\s+(use[A-Z]\w+)` | `function useAuth`, `export function useLogin` |

### Exclusion patterns (Finding #11 — false positives)

```bash
EXCLUDE_GLOBS=(
  "*.test.{ts,tsx,js,jsx,py,cs}"
  "*.spec.{ts,tsx,js,jsx}"
  "**/__snapshots__/**"
  "**/node_modules/**"
  "**/.next/**"
  "**/dist/**"
  "**/build/**"
  "**/*.md"
  "**/*.snap"
)
```

| Step | Action | Verify |
|------|--------|--------|
| 0.7.4 | Extract entity/model names từ feature spec → grep với "Entity/Model" pattern (loại trừ EXCLUDE_GLOBS) | Search done |
| 0.7.5 | Extract endpoint paths từ spec/A6-EXT → grep với "Endpoint" pattern | Search done |
| 0.7.6 | Extract component names (PascalCase imports trong A6-EXT.1) → grep với "Component" pattern | Search done |
| 0.7.7 | Extract service/hook names → grep với "Service"/"Hook" pattern | Search done |
| 0.7.7a | **[Finding #9 — Partial-Fix Detection]** IF `$CONFIRMED_STRATEGY == COMPLETE_EXISTING` AND task file có gaps về REQ-ID annotation: với mỗi scope file trong A2.4, grep current REQ-ID/FEAT-ID values. SET `$ANNOTATION_STATE_PER_FILE` = map `{file: {req_id, feat_id}}`. IF heterogeneous (≥2 distinct values) → log "PARTIAL-FIX detected" + inject vào `$TASK_LIST` cho Phase 3 agent context (các file có annotation nào → cần đổi thành gì). | State map populated |
| 0.7.8 | Tổng hợp kết quả: `$FOUND_CODE_REFS` (list of file:line matches) + `$ANNOTATION_STATE_PER_FILE` (nếu COMPLETE_EXISTING) | Results compiled |

---

## BƯỚC 2b: Environment Safety Scan (v5.1+)

> Chạy SAU BƯỚC 2, TRƯỚC BƯỚC 3. Quét các pattern nguy hiểm phổ biến trong code hiện tại và code sẽ sinh.
> Áp dụng cho TẤT CẢ modes (VERIFY_ONLY / COMPLETE_EXISTING / IMPLEMENT_NEW).

### Scan Patterns

| # | Pattern | Target | Severity | Action |
|---|---------|--------|----------|--------|
| E1 | `process\.env\.` trong `*.{tsx,ts,jsx,js}` không thuộc `server/` | `process.env` trong browser bundle | CRITICAL | BLOCK — yêu cầu sửa trước khi tiếp tục |
| E2 | `'(dev-secret\|admin123\|password\|changeme\|temp_key\|test_key)'` | Hardcoded secret fallback | CRITICAL | BLOCK — yêu cầu sửa trước khi tiếp tục |
| E3 | `parseInt\|parseFloat\|Number\(\|new Date\(` không có `isNaN\|Number.isNaN\|\.filter\(Boolean\)` trong 2 dòng tiếp theo | NaN propagation risk | HIGH | WARNING — inject vào agent context |
| E4 | `\.replace\(['\"]` (string arg, không phải regex) | String.replace chỉ thay lần đầu | MEDIUM | INFO — log, agent tự check |
| E5 | `define:\s*\{[^}]*process\.env` trong `vite\.config\.(ts\|js)` | API key leak qua Vite define vào client bundle | CRITICAL | BLOCK — yêu cầu sửa trước khi tiếp tục |

### Exclusion Patterns

```bash
EXCLUDE_GLOBS_SAFETY=(
  "*.test.{ts,tsx,js,jsx,py,cs}"
  "*.spec.{ts,tsx,js,jsx}"
  "**/__snapshots__/**"
  "**/node_modules/**"
  "**/.next/**"
  "**/dist/**"
  "**/build/**"
  "**/*.md"
  "**/*.snap"
  "**/*.d.ts"
)
```

### Scan Steps

| Step | Action | Verify |
|------|--------|--------|
| 0.7.S1 | Build target scope: nếu VERIFY_ONLY/COMPLETE_EXISTING → scan files trong `$EXISTING_CODE_REFS`; nếu IMPLEMENT_NEW → scan toàn bộ source dir (trừ exclusions) | Scope defined |
| 0.7.S2 | Chạy E1: `grep -rn 'process\.env\.' --include='*.tsx' --include='*.ts' --include='*.jsx' --include='*.js' [scope] \| grep -v '/server/' \| grep -v '\.test\.' \| grep -v '\.spec\.'` | Scan done |
| 0.7.S3 | Chạy E2: `grep -rnE "(dev-secret\|admin123\|password\|changeme\|temp_key\|test_key)" [scope] \| grep -v node_modules \| grep -v '\.test\.' \| grep -v '\.spec\.'` | Scan done |
| 0.7.S4 | Chạy E3: `grep -rnE "(parseInt\|parseFloat\|Number\(|new Date\()" --include='*.ts' --include='*.tsx' [scope] \| grep -v '\.test\.' \| grep -v '\.spec\.'` → cross-check với `isNaN`/`Number.isNaN`/`.filter(Boolean)` trong 2 dòng tiếp theo | Scan done |
| 0.7.S5 | Chạy E4: `grep -rn '\.replace(['"'"'"'"]' --include='*.ts' --include='*.tsx' [scope] \| grep -v '\.test\.' \| grep -v '\.spec\.'` | Scan done |
| 0.7.S6 | Chạy E5 (chỉ khi có vite config): `test -f vite.config.ts \|\| test -f vite.config.js` → `grep -n 'define:\s*{[^}]*process\.env' vite.config.*` | Scan done |
| 0.7.S7 | Tổng hợp → `$SAFETY_SCAN_FINDINGS` = array `{pattern, severity, file, line, match}`. Phân loại: `$SAFETY_CRITICAL` (E1/E2/E5), `$SAFETY_WARNINGS` (E3), `$SAFETY_INFO` (E4) | Results compiled |

### Decision Routing

```
IF $SAFETY_CRITICAL không rỗng:
  ┌────────────────────────────────────────────────────────┐
  │ ⚠️ CẢNH BÁO: Phát hiện vấn đề an toàn môi trường        │
  │                                                        │
  │ Các file sau có pattern CRITICAL cần sửa TRƯỚC KHI     │
  │ tiếp tục implementation:                              │
  │                                                        │
  │ [Bảng liệt kê file:line, pattern, severity]            │
  │                                                        │
  │ Bạn muốn:                                             │
  │ (a) Sửa các file này trước → re-run safety scan       │
  │ (b) Ghi nhận rủi ro, tiếp tục (KHÔNG khuyến nghị)    │
  │ (c) Abort — exit skill                                │
  └────────────────────────────────────────────────────────┘
  → DỪNG — chờ user confirm
  → (a) → STOP với E_SAFETY_CRITICAL, user fix rồi re-run
  → (b) → log WARNING vào session-log + impl-status.json.safety_overrides, CONTINUE
  → (c) → STOP

IF $SAFETY_WARNINGS hoặc $SAFETY_INFO không rỗng:
  → Inject vào $TASK_LIST context cho Phase 2 planning + Phase 3 agent
  → Log WARNING vào session-log (không block)
```

### Output State Variables (BƯỚC 2b)

| Variable | Set | Consumed by |
|----------|-----|-------------|
| `$SAFETY_SCAN_FINDINGS` | Array `{pattern, severity, file, line, match}` | phase2 (planning context), phase3 (agent context) |
| `$SAFETY_CRITICAL` | Subset của `$SAFETY_SCAN_FINDINGS` với severity=CRITICAL | BƯỚC 2b routing |
| `$SAFETY_WARNINGS` | Subset với severity=HIGH | phase2, phase3 |
| `$SAFETY_INFO` | Subset với severity=MEDIUM | phase2, phase3 |

---

## BƯỚC 3: Mismatch Detection + Routing

```
IF $FOUND_CODE_REFS không rỗng AND strategy == IMPLEMENT_NEW:
  ┌────────────────────────────────────────────────────────┐
  │ ⚠️ DỪNG LẠI — Phát hiện Code Hiện tại                 │
  │                                                        │
  │ Feature [FEAT-ID] có vẻ đã có code tại:               │
  │   [file_path] (lines [X]-[Y])                         │
  │                                                        │
  │ Nhưng task file nói: IMPLEMENT_NEW                     │
  │                                                        │
  │ Bạn muốn:                                             │
  │ (a) Verify code hiện tại → đánh dấu DONE nếu đúng    │
  │ (b) Bổ sung phần còn thiếu (không rewrite)            │
  │ (c) Rewrite hoàn toàn [cần lý do rõ ràng]            │
  │ (d) Bỏ qua feature này (skipped)                      │
  └────────────────────────────────────────────────────────┘
  → DỪNG — chờ user confirm trước khi tiếp tục
  → Map user choice:
      (a) → VERIFY_ONLY
      (b) → COMPLETE_EXISTING
      (c) → IMPLEMENT_NEW (confirmed)
      (d) → SKIP

IF $FOUND_CODE_REFS không rỗng AND strategy == null (new project):
  → Cảnh báo: "Tìm thấy code liên quan tại [refs]. Bạn muốn tiếp tục implement mới?"
  → Wait for user confirm

IF strategy khớp với thực tế (VD: VERIFY_ONLY và code tồn tại):
  → Tiếp tục theo mode tương ứng

SET $CONFIRMED_STRATEGY = strategy đã xác nhận
```

---

## BƯỚC 3.5: Recent Fix-Bugs Sessions Cross-Check (v4.1+ S9 — Default Behavior)

> **Mục đích (CORE-020 enhanced):** Sau khi Step 0.7.4-0.7.7 search code hiện tại, ALSO scan `fix-impact.json` từ N=3 sessions wf-fix-bugs gần nhất. Nếu file dự kiến viết/edit trùng với `affected_artifacts.code_files[].path` → render CDG để user confirm overwrite (tránh conflict với fix gần đây).
>
> **Default behavior — KHÔNG cần flag.** Áp dụng mọi mode (VERIFY_ONLY/COMPLETE_EXISTING/IMPLEMENT_NEW). Chạy SAU BƯỚC 3 (mismatch detection đã xong).
>
> **Backward compat:** Nếu `.mc-data/work/wf-fix-bugs/_index/sessions.jsonl` không tồn tại hoặc không có completed session → SKIP silently (fallback Phase 0.7 cũ).

### Steps

| Step | Action | Verify |
|------|--------|--------|
| 0.7.RFC1 | Check `test -f .mc-data/work/wf-fix-bugs/_index/sessions.jsonl`. Nếu không tồn tại → SKIP toàn bộ BƯỚC 3.5, set `$RECENT_FIX_CONFLICTS = []`, jump to Mode Routing. | File check done |
| 0.7.RFC2 | Lấy N=3 sessions completed gần nhất: `RECENT_SIDS=$(jq -r 'select(.status=="completed")\|.session_id' _index/sessions.jsonl \| sort -r \| head -3)`. Nếu rỗng → SKIP. | Session list resolved |
| 0.7.RFC3 | Build `$TARGET_FILES` list: từ `$SCOPE_FILES` (A2.4 EXCLUSIVE_WRITE/EXCLUSIVE_CREATE/SHARED_APPEND files) + `$FOUND_CODE_REFS` (BƯỚC 2 results). Đây là files dự kiến viết/edit trong Phase 3. | List built |
| 0.7.RFC4 | Cho mỗi `$SID` trong `$RECENT_SIDS`: load `$IMPACT_PATH=".mc-data/work/wf-fix-bugs/sessions/$SID/fix-impact.json"`. Skip nếu file không tồn tại (graceful — session có thể chưa hoàn tất POST-GATE). Validate `jq -e '."$schema" == "fix-impact-v1"'` — fail → skip session đó. | Per-session loaded |
| 0.7.RFC5 | Cho mỗi loaded fix-impact: extract `AFFECTED=$(jq -r '.affected_artifacts.code_files[].path' fix-impact.json)`. Cho mỗi target file trong `$TARGET_FILES`, check intersection. Nếu match: append vào `$RECENT_FIX_CONFLICTS = [{session_id, target_file, fix_session_issues, fix_session_generated_at}]`. | Conflicts collected |
| 0.7.RFC6 | IF `$RECENT_FIX_CONFLICTS` empty → log "No recent fix-bugs conflicts detected", continue Mode Routing. ELSE → render CDG (xem §Recent Fix Conflicts CDG). | Decision made |

### §Recent Fix Conflicts CDG

```
RENDER CDG (Critical Decision Gate — Protocol 16):

⚠️ CẢNH BÁO: File trùng với fix gần đây
─────────────────────────────────────────────
Feature [FEAT-ID] sẽ viết/edit các file sau, nhưng những file này
vừa được fix trong wf-fix-bugs session(s) gần đây:

| Target File | Fix Session | Issues fixed | Fix time |
|-------------|-------------|--------------|----------|
| apps/backend/src/auth/login.ts | 2026-04-28-module-auth-02 | ISSUE-007, ISSUE-012 | 2026-04-28T11:30:00Z |
| ...

Viết đè có thể:
- Mất các fix vừa apply (regression)
- Conflict với verify_evidence của wf-fix-bugs session
- Vô hiệu hóa audit_chain checksum

Bạn muốn:
(a) Đọc kỹ fix-log của session trước → continue có chủ đích (recommended)
(b) Force tiếp tục (RỦI RO — không đọc fix history)
(c) Abort — exit skill, manual review fix history trước

User input:
  - (a) → log decision token {type: 'recent_fix_acknowledged', session_ids, files}, CONTINUE
  - (b) → log warning {type: 'recent_fix_force_continue', accepted_by_user}, CONTINUE với strong warning
  - (c) → STOP với E_RECENT_FIX_BLOCK, recommend "Đọc $SESSION_DIR/fix-log.json + fix-impact.json trước khi re-run"
```

### Output State Variables (BƯỚC 3.5)

| Variable | Set | Consumed by |
|----------|-----|-------------|
| `$RECENT_FIX_CONFLICTS` | Array `{session_id, target_file, fix_session_issues, fix_session_generated_at}` | phase3 (developer agent context — inject as context khi viết file đã fix) |
| `$RECENT_FIX_CDG_DECISION` | "acknowledged" / "force_continue" / null | phase6-finalize.md (log vào impl-status.json.cross_skill_signals) |

---

## Mode Routing (sau BƯỚC 3 + BƯỚC 3.5)

### → VERIFY_ONLY Mode

| Step | Action | Verify |
|------|--------|--------|
| 0.7.V1 | Load `existing_code_refs` từ task file | Refs loaded |
| 0.7.V2 | Run existing tests → nếu FAIL → STOP, báo cáo | Tests pass |
| 0.7.V3 | Cross-check code logic vs feature spec | Logic verified |
| 0.7.V4 | **IF logic khớp:** Inject REQ-ID annotations → update `impl_status = "done"` → ghi verification-report → **SKIP phase2 → phase5a, nhảy thẳng phase6-finalize.md** | Done |
| 0.7.V5 | **IF logic KHÔNG khớp:** Hỏi user: "(a) Sửa spec (code đúng) \| (b) Sửa code (spec đúng)" → route theo lựa chọn | User decided |

> **VERIFY_ONLY mode KHÔNG tạo file code mới.** Chỉ annotate REQ-ID vào code hiện tại.

### → COMPLETE_EXISTING Mode

| Step | Action | Verify |
|------|--------|--------|
| 0.7.C1 | Read existing code (KHÔNG viết lại) | Code loaded |
| 0.7.C2 | Read `gaps_identified` từ task file | Gaps loaded |
| 0.7.C3 | Set `$TASK_LIST` = chỉ gaps (KHÔNG bao gồm existing code) | Task list filtered |
| 0.7.C4 | Tiếp tục phase2 + phase3 bình thường — nhưng chỉ implement gaps | Proceed |

> **COMPLETE_EXISTING mode KHÔNG rewrite existing code.** TDD chỉ cho phần thiếu. Run FULL test suite (cũ + mới).

### → IMPLEMENT_NEW Mode

| Step | Action | Verify |
|------|--------|--------|
| 0.7.N1 | Hiển thị: "Xác nhận: Không tìm thấy code cho [FEAT-ID]. Tiến hành TDD?" | User confirmed |
| 0.7.N2 | Tiếp tục phase2 + phase3 bình thường (TDD cycle đầy đủ) | Proceed |

---

## POST-GATE

`$CONFIRMED_STRATEGY` set.
**(v4.1+ S9):** `$RECENT_FIX_CONFLICTS` set (array, có thể empty), `$RECENT_FIX_CDG_DECISION` set khi conflicts > 0.
**(v5.1+):** `$SAFETY_SCAN_FINDINGS` set (array, có thể empty). Nếu `$SAFETY_CRITICAL` không rỗng → user đã resolve hoặc acknowledged.

- Nếu VERIFY_ONLY (Step 0.7.V4 passed) → orchestrator skip phase2-5a, nhảy thẳng phase6-finalize.md
- Nếu COMPLETE_EXISTING / IMPLEMENT_NEW → tiếp tục phase2-planning.md
- Nếu Recent Fix CDG = "abort" → STOP với E_RECENT_FIX_BLOCK
- Nếu Safety Scan phát hiện CRITICAL và user chọn "abort" → STOP với E_SAFETY_CRITICAL

---

## §A2.4 Cross-Feature Conflict Detection (Step 0.7.3a chi tiết)

> **Mục đích:** Khi user chạy NHIỀU phiên `/wf-implement-feature` song song (mỗi phiên 1 feature),
> phát hiện file conflict TRƯỚC khi spawn developer agent → tránh overwrite code.

```bash
# 1. Parse A2.4 table từ task file
SCOPE_FILES=$(awk '/^#### A2.4 Scope Files/,/^---|^####[^#]/' "$TASK_FILE" \
              | grep -E "\| (EXCLUSIVE_WRITE|EXCLUSIVE_CREATE|SHARED_APPEND|SHARED_READ) \|")

# 2. Extract Parallel-Safe Verdict
PARALLEL_VERDICT=$(grep -oE "Parallel-Safe Verdict.*?(SAFE_PARALLEL|REQUIRES_SEQUENTIAL_WITH:[A-Z0-9-,]+)" "$TASK_FILE" \
                   | head -1)

# 3. Cross-session conflict check — kiểm tra xem có session khác đang implement
#    1 trong các EXCLUSIVE_WRITE files của feature này không
LOCK_DIR=".mc-data/work/wf-implement-feature/.locks"
mkdir -p "$LOCK_DIR"

# v5.0: locks scoped theo system → glob 2-level (.locks/{system}/{feature}.lock)
CONFLICT_FEATURES=()
for OTHER_LOCK in "$LOCK_DIR"/*/*.lock; do
  [ -f "$OTHER_LOCK" ] || continue
  OTHER_SLUG=$(basename "$OTHER_LOCK" .lock)
  [ "$OTHER_SLUG" = "$FEATURE_SLUG" ] && continue  # skip self

  # Đọc scope files của feature đang lock
  OTHER_SCOPE=$(jq -r '.scope_files_exclusive[]?' "$OTHER_LOCK" 2>/dev/null)

  # Check intersection với MY exclusive files
  MY_EXCLUSIVE=$(echo "$SCOPE_FILES" | grep -E "EXCLUSIVE_(WRITE|CREATE)" | awk -F'|' '{print $2}' | xargs)
  for MY_FILE in $MY_EXCLUSIVE; do
    if echo "$OTHER_SCOPE" | grep -qF "$MY_FILE"; then
      CONFLICT_FEATURES+=("$OTHER_SLUG: file $MY_FILE")
    fi
  done
done

# 4. Decision routing
if [ ${#CONFLICT_FEATURES[@]} -gt 0 ]; then
  ⚠️ CROSS-SESSION CONFLICT phát hiện:
     Feature [FEAT-ID] EXCLUSIVE_WRITE files conflict với sessions đang chạy:
     ${CONFLICT_FEATURES[@]}

  AskUserQuestion:
  (a) Đợi session khác hoàn thành (recommend) — STOP với message "Chạy lại sau khi session khác done"
  (b) Force tiếp tục (RỦI RO — overwrite có thể xảy ra)
  (c) Abort — exit skill

  IF (a) → STOP + emit FAIL session-log
  IF (b) → continue + log WARNING vào session-log
  IF (c) → exit
fi

# 5. Display verdict cho user (informational)
LOG: "[A2.4] Parallel verdict cho $FEATURE_SLUG: $PARALLEL_VERDICT"
LOG: "[A2.4] Scope files: $(echo "$SCOPE_FILES" | wc -l) entries"
```

**Backward compatibility:**
- Nếu A2.4 thiếu trong task file → `$PARALLEL_VERDICT="UNKNOWN"`, vẫn cho phép tiếp tục nhưng với WARNING.
- Nếu skill chạy không có lock dir (.locks/) → skip cross-session check, log WARNING "Per-feature lock không sẵn".

---

## Output State Variables

| Variable | Set | Consumed by |
|----------|-----|-------------|
| `$CONFIRMED_STRATEGY` | VERIFY_ONLY / COMPLETE_EXISTING / IMPLEMENT_NEW / SKIP | phase2, phase3, phase6 (routing) |
| `$FOUND_CODE_REFS` | List of existing code references | phase2 (inform planning) |
| `$EXISTING_CODE_REFS` | From task file | phase3 (agent context) |
| `$GAPS_IDENTIFIED` | From task file (COMPLETE_EXISTING only) | phase2, phase3 |
| `$SCOPE_FILES` | List `{path, mode, shared_with[]}` từ A2.4 | phase3 (developer agent guard) |
| `$PARALLEL_VERDICT` | SAFE_PARALLEL / REQUIRES_SEQUENTIAL_WITH:... / UNKNOWN | phase3 (informational) |
| `$ANNOTATION_STATE_PER_FILE` | Map {file: {current_req_id, current_feat_id, target_req_id, target_feat_id}} (only when COMPLETE_EXISTING + annotation gap) | phase3 (developer agent context — disambiguate partial-fix state) |
| `$SAFETY_SCAN_FINDINGS` | Array `{pattern, severity, file, line, match}` (v5.1+) | phase2 (planning context), phase3 (agent context), phase6 (report) |
| `$SAFETY_CRITICAL` | Subset của `$SAFETY_SCAN_FINDINGS` với severity=CRITICAL (v5.1+) | BƯỚC 2b routing |
| `$SAFETY_WARNINGS` | Subset với severity=HIGH (v5.1+) | phase2, phase3 |
| `$SAFETY_INFO` | Subset với severity=MEDIUM (v5.1+) | phase2, phase3 |
