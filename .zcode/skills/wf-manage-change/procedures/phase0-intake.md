# Phase 0: Context Loading & Intake

> Đọc prompt + hiểu dự án đang ở đâu + phân loại yêu cầu thay đổi.
> Phase 0 là bước đầu tiên — mọi lần chạy `/wf-manage-change` đều bắt đầu từ đây (trừ `--resume`).

> **Shared:** Xem `procedures/_shared.md` — State Variables, Session Isolation, LEGACY Detection, Fix Rules.

---

## PRE-GATE

```bash
test -f .mc-data/docs/_meta/req-registry.json
jq -e '.requirements | length > 0' .mc-data/docs/_meta/req-registry.json
```

Nếu fail → STOP: *"Dự án chưa có registry. Chạy `/wf-brainstorm` trước."*

**Forensic validation (Protocol 10.4 — CORE-011):** kiểm tra content, không chỉ file existence.

---

## INPUT

| File | Đường dẫn | Điều kiện |
|------|-----------|-----------|
| Registry | `.mc-data/docs/_meta/req-registry.json` | BẮT BUỘC |
| Legacy decisions | `.mc-data/work/wf-brainstorm/legacy-decisions.json` | BẮT BUỘC khi LEGACY_MODE (CORE-022) |
| Design digest | `.mc-data/docs/_meta/design-input-digest.json` | Optional |
| User prompt | `$ARGUMENTS` | BẮT BUỘC |

---

## OUTPUT

| File | Template |
|------|----------|
| `$SESSION_DIR/change-status.json` | `templates/change-status.json` |
| `$SESSION_DIR/change-intake.json` | `templates/change-intake.json` |
| `.mc-data/work/wf-manage-change/index.json` | `templates/index.json` |

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.0 | **CORE-026 START trace:** Append START entry vào `.mc-data/work/_trace/session-log.json` (xem `_shared.md` §CORE-026) | Write | Entry logged |
| 0.1 | **Generate session ID + acquire lock + start heartbeat (CORE-030):** ① `CHANGE_ID=$(bash .claude/scripts/wf-manage-change/mc-generate-session-id.sh)` — generate unique ID với retry loop (S1 script). ② `bash .claude/scripts/wf-manage-change/mc-acquire-lock.sh --type=session --id=$CHANGE_ID` — acquire session lock (S2 — tạo `$SESSION_DIR/.session.lock`). NẾU lock fail (exit 1) → session đang chạy ở process khác → STOP với WARNING. ③ `bash .claude/scripts/wf-manage-change/mc-heartbeat.sh --id=$CHANGE_ID & HEARTBEAT_PID=$!` — start heartbeat daemon (background, cập nhật heartbeat_at mỗi 30s); **PHẢI capture `$HEARTBEAT_PID` để Step 0.1c và Phase 6.4b kill được**. ④ `mkdir -p $SESSION_DIR` (nếu chưa tạo bởi acquire-lock). **BỎ QUA nếu `--resume`**. | Bash | `$SESSION_DIR` exists, `$CHANGE_ID` unique, `.session.lock` exists, `$HEARTBEAT_PID` non-empty |
| 0.1a | **[GAP-8 fix] Auto-detect phiên dở dang:** Nếu `index.json` tồn tại VÀ `active_session != null` VÀ `sessions[active_session].status == "in_progress"` → AskUserQuestion: "Có phiên làm việc dở dang ($active_session — [summary từ sessions[$active_session].summary]). Bạn muốn tiếp tục phiên cũ hay bắt đầu thay đổi mới?" Options: "Tiếp tục phiên cũ" → route sang `--resume` (§Flag Handlers §--resume) → STOP sau khi route; "Bắt đầu mới" → set `sessions[$active_session].status = "abandoned"` trong `index.json` → tiếp tục Step 0.1b. **BỎ QUA nếu `--resume` hoặc `--status`**. | Read/AskUserQuestion | User confirmed |
| 0.1b | **Cập nhật index.json + sessions.jsonl:** ① `bash .claude/scripts/wf-manage-change/mc-index-append.sh --change-id=$CHANGE_ID --status=in_progress --summary="$USER_PROMPT"` — append vào `_index/sessions.jsonl` (S2 — append-only, concurrent-safe). ② READ template `templates/index.json` → POPULATE entry cho `$CHANGE_ID` (status="in_progress") → WRITE `.mc-data/work/wf-manage-change/index.json` (dual-write với sessions.jsonl cho `--status` display). **BỎ QUA nếu `--resume`.** | Bash/Write | index.json updated, sessions.jsonl có entry |
| 0.1c | **[S2] EXIT trap cleanup:** Set trap để dọn dẹp khi session kết thúc bất thường (Ctrl+C, crash, STOP): `trap "kill $HEARTBEAT_PID 2>/dev/null; bash .claude/scripts/wf-manage-change/mc-release-lock.sh --type=session --id=$CHANGE_ID" EXIT`. Đảm bảo lock luôn được release. **BỎ QUA nếu `--resume`** (trap sẽ set lại trong `_shared.md` §Resume Logic). | Bash | Trap active |
| 0.2 | **Handle --status / --resume flags** (xem dưới §Flag Handlers) | — | Handled |
| 0.3 | Parse registry → load context (systems, modules, features, requirements) | Read | Registry parsed |
| 0.4 | **LEGACY_MODE Detection (CORE-021):** xem `_shared.md` §LEGACY Detection → set `$LEGACY_MODE` | Bash | Flag set |
| 0.4b | **CORE-022 — Đọc legacy-decisions.json (nếu LEGACY_MODE):** xem `_shared.md` §Legacy Decisions Bridge → set `$DEPRECATED_MODULES[]` | Read | DEPRECATED_MODULES set |
| 0.5 | **Detect project maturity:** Đọc phase docs tồn tại → determine `$MATURITY` (xem §Maturity Detection) | Glob | Maturity set |
| 0.6 | **Parse `$ARGUMENTS`:** Extract mô-tả-thay-đổi, scope, name, mode flags, `$DRY_RUN`, `$RUN_TESTS`. **$USER_PROMPT** = phần mô-tả-thay-đổi từ `$ARGUMENTS` sau khi loại bỏ tất cả flags (`--scope`, `--name`, `--mode`, `--dry-run`, `--run-tests`, `--resume`, `--status`). Nếu `$USER_PROMPT` rỗng sau khi loại bỏ flags → E002 (hỏi user mô tả thêm). | — | Args parsed, `$USER_PROMPT` non-empty |
| 0.7 | **Analyze user prompt:** Trích rút references (systems, modules, features, REQ-IDs) → `$REFERENCED_ARTIFACTS` | Read/Grep | References extracted |
| 0.8 | **Match với existing artifacts:** Tìm references trong registry. **NẾU LEGACY_MODE:** Loại bỏ tất cả artifacts thuộc `$DEPRECATED_MODULES` khỏi match results — không phân tích, không đưa vào scope. | Grep | Match results (deprecated excluded) |
| 0.9 | **Classify change type (preliminary):** `MODIFY_FEATURE \| MODIFY_REQUIREMENT \| ADD_FEATURE \| DELETE_FEATURE \| CLARIFY_REQ \| UNCLEAR` (xem §Change Type Classification) | — | Type set |
| 0.10 | **Determine analysis mode:** `quick` / `deep` (xem §Analysis Mode Auto-Detection) | — | Mode set |
| 0.11 | **Khởi tạo session files:** READ template `templates/change-status.json` → POPULATE session data (bao gồm `flags.run_tests = $RUN_TESTS`, `flags.dry_run = $DRY_RUN`, `flags.analysis_mode`) → WRITE `$SESSION_DIR/change-status.json`. READ template `templates/change-intake.json` → POPULATE intake data → WRITE `$SESSION_DIR/change-intake.json` | Write | Files created |

---

## Flag Handlers

### `--status`

```
IF test -f .mc-data/work/wf-manage-change/index.json:
  → Doc index.json
  → Hiển thị: active_session + bảng tất cả sessions (change_id, status, summary, created_at, risk_level)
  → STOP
ELSE:
  → "Chưa có session wf-manage-change nào." → STOP
```

### `--resume`

```
IF test -f .mc-data/work/wf-manage-change/index.json:
  → Doc index.json → $CHANGE_ID = active_session → $SESSION_DIR
  → IF test -f $SESSION_DIR/checkpoint.json:
      → Route theo `_shared.md` §Resume Logic & Routing Table → STOP sau khi route
  → ELSE: STOP "Không tìm thấy checkpoint. Chạy /wf-manage-change từ đầu."
ELSE:
  → STOP: "Không tìm thấy session nào. Chạy /wf-manage-change từ đầu."
```

---

## Project Maturity Detection

```
$MATURITY =
  "docs_only"     — Chỉ có Phase 0-1 (brainstorm + requirements)
  "designed"      — Có Phase 2-3 (features + architecture)
  "implementing"  — Có Phase 5 (code)
  "near_done"     — Có Phase 5-6 (code + deployment docs)
```

---

## Change Type Classification

```
MODIFY_FEATURE:
  "Thay đổi cách tính phí..."         → sửa logic feature đã có
  "Sửa lại luồng xác thực..."         → sửa quy trình business
  "Update feature X để..."

MODIFY_REQUIREMENT:
  "Thay đổi yêu cầu business..."      → sửa nội dung requirement
  "Tách module X thành A và B..."     → structural change
  "Gộp 2 module..."

ADD_FEATURE:
  "Bổ sung tính năng xuất báo cáo..." → thêm feature mới vào module đã có
  "Thêm logic kiểm tra..."

DELETE_FEATURE:
  "Xóa tính năng xuất Excel..."       → loại bỏ feature
  "Bỏ tính năng..."

CLARIFY_REQ:
  "Bổ sung thông tin cho REQ-SALES-001..." → làm rõ requirement đã có
  "Làm rõ hơn về điều kiện..."

UNCLEAR:
  "Tôi muốn thay đổi..."              → không rõ thay đổi gì
  "Chạy không ổn"                     → mô tả vague
  IF referenced_artifacts rỗng AND prompt vague → UNCLEAR
```

> **Lưu ý:** `SPLIT_MODULE`/`MERGE_MODULES` KHÔNG có trong enum. Các trường hợp "tách/gộp module" classify thành `MODIFY_REQUIREMENT` (DEEP mode) + hỏi user chi tiết. Nếu chỉ cần thêm module mới → hướng dẫn dùng `/wf-add-scope`.

---

## Clarification Protocol (BẮT BUỘC khi UNCLEAR)

```
IF $CHANGE_TYPE == "UNCLEAR":
  PRE-CONDITION: change-intake.json phải đã được tạo (Step 0.11) trước khi AskUserQuestion.

  BƯỚC NGAY TRƯỚC KHI HỎI:
    - Populate unclear_points[] vào $SESSION_DIR/change-intake.json với các điểm cụ thể
    - Ghi rõ lý do mỗi unclear_point (VD: "không map vào artifact nào", "mô tả vague")
    - Save $SESSION_DIR/change-status.json với intake.unclear_points đã cập nhật

  1. AskUserQuestion — tối đa 2 VÒNG:
     - "Bạn muốn thay đổi chính xác điều gì?" (what)
     - "Ở phạm vi nào? Module/feature nào?" (where)
     - "Tại sao cần thay đổi?" (why)
     - TRIAGE: "Đây là lỗi (code sai) hay thay đổi logic nghiệp vụ?"
       → Nếu là lỗi → hướng dẫn dùng /wf-fix-bugs thay thế
  2. KHÔNG tiếp tục phân tích khi user chưa trả lời
  3. Nếu user vẫn không rõ sau 2 vòng → STOP với E002 + hướng dẫn cụ thể
  4. Sau khi làm rõ → re-run Steps 0.7–0.10 với thông tin mới → re-classify → tiếp tục
```

---

## Analysis Mode Auto-Detection

```
IF --mode set → use user choice
ELSE:
  IF $CHANGE_TYPE in [UNCLEAR, MODIFY_REQUIREMENT] → DEEP
  IF $CHANGE_TYPE == CLARIFY_REQ → QUICK   (ít ảnh hưởng kỹ thuật)
  IF cross-system references detected (>= 2 systems affected) → DEEP
  IF prompt <= 20 words AND references exactly 1 artifact → QUICK
  ELSE → DEEP   (mặc định: ưu tiên phân tích kỹ)
```

---

## POST-GATE — T1→T4 (CORE-012)

**Verification (mc-postgate-check.sh):**
```bash
bash .claude/scripts/wf-manage-change/mc-postgate-check.sh \
  --file=$SESSION_DIR/change-status.json --type=json
bash .claude/scripts/wf-manage-change/mc-postgate-check.sh \
  --file=$SESSION_DIR/change-intake.json --type=json
# → {"pass":true} required. Nếu fail → auto-fix re-generate → retry tối đa 3 lần.
```

Nếu fail → Auto-fix theo `protocols/01-accuracy-assurance.md` → retry tối đa 3 lần → escalate nếu vẫn fail.

**Sau khi PASS:** Update `change-status.json.phases.phase0.status = "completed"` → tiếp tục `procedures/phase1-analyze.md`.
