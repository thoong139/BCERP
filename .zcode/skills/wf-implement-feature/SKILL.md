---
name: wf-implement-feature
version: 5.2.0
last_updated: 2026-05-09
description: |
  Triển khai code cho tính năng theo TDD — từ feature design đến code hoàn chỉnh, qua parallel code review + security review; multi-session parallel-safe + resume. System-grouped layout: $SYSTEM_SLUG/$FEATURE_SLUG/ (auto-derive từ registry, fallback _orphan/, override bằng --system). Cross-skill --from-fix-bugs: consume fix-impact.json từ wf-fix-bugs để prioritize features trùng code_files. Có Environment Profile/Safety Scan, mandatory security agent cho auth/data batches, VERIFY_ONLY review.

  TRIGGER khi:
  - User nói: "implement", "code", "viết code", "triển khai/làm tính năng"
  - User đề cập REQ-ID cụ thể, hoặc có technical design và muốn bắt đầu coding
  - Gọi lệnh: /wf-implement-feature [feature-name | REQ-ID] [flags]

  LUÔN trigger khi user muốn viết code cho feature/requirement cụ thể, dù không dùng từ "implement-feature".

  KHÔNG trigger khi:
  - Chưa có technical design → dùng /wf-design trước
  - Chỉ cần documentation/research → không cần coding
argument-hint: "[feature-name | REQ-ID] [--system=<slug>] [--module=<n>] [--extend] [--modify] [--skip-tests] [--skip-review] [--component=<type>] [--resume] [--micro-task=MT-FEAT-NNN] [--fresh] [--parallel] [--features=FEAT-001,FEAT-002,...] [--profile=quick|standard|deep|exhaustive] [--no-cache] [--status] [--from-fix-bugs[=<session_id>]]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent, TodoWrite
---
# /wf-implement-feature: $ARGUMENTS

## Overview

| Mục                    | Nội dung                                                                                           |
| ----------------------- | --------------------------------------------------------------------------------------------------- |
| **Mục đích**   | Viết code theo TDD + parallel review (code/security/qa)                                            |
| **Prerequisites** | `phase2-features/[sys]/[mod]/*.md` + task files từ wf-plan-modules                               |
| **Duration**      | Multi-session                                                                                       |
| **Procedures**    | Single feature: phase-per-file trong `procedures/` \| Multi-feature: `procedures/flow-multi.md` |
| **Output**        | Source code + tests +`impl-status.json` + `impl-report.md` + `phase-summary.md`               |

### Phase File Structure (v3.0)

| File                                       | Load khi                                      | Mục đích                                                                 |
| ------------------------------------------ | --------------------------------------------- | --------------------------------------------------------------------------- |
| `procedures/_shared.md`                  | Reference (on-demand)                         | Agent contexts + protocols refs + error codes                               |
| `procedures/phase0-existing-analysis.md` | `$SCENARIO != "new"`                        | Scan existing code patterns (EXTEND/MODIFY)                                 |
| `procedures/phase0-5-context-setup.md`   | LUÔN chạy                                   | LEGACY_MODE detect + Decision Registry load                                 |
| `procedures/phase0-6-env-profile.md`     | LUÔN chạy (SAU phase0-5)                   | Environment profile detection (v5.1+)                                        |
| `procedures/phase1-feature-context.md`   | LUÔN chạy                                   | Feature context + digest loading                                            |
| `procedures/phase0-7-safety-gate.md`     | LUÔN chạy (SAU phase1)                      | Safety gate + env scan + 3 modes routing (VERIFY_ONLY/COMPLETE_EXISTING/IMPLEMENT_NEW) |
| `procedures/phase2-planning.md`          | `$CONFIRMED_STRATEGY != "VERIFY_ONLY"`      | Task breakdown + batch plan                                                 |
| `procedures/phase2-4-populate-spec.md`   | `$A6_EXT_NEEDS_POPULATE == true`            | Architect populate A6-EXT (khi STUB) — BẮT BUỘC trước Phase 3          |
| `procedures/phase2-5-contracts.md`       | `$PARALLEL_MODE == true`                    | Contract-first generation (conditional)                                     |
| `procedures/phase3-tdd.md`               | `$CONFIRMED_STRATEGY != "VERIFY_ONLY"`      | TDD (sequential hoặc parallel waves)                                       |
| `procedures/phase4-5-review-fix.md`      | `--skip-review != true`                     | Review-Fix Loop (max 3 attempts)                                            |
| `procedures/phase5a-crossval.md`         | LUÔN chạy (sau Phase 4-5 hoặc skip-review) | Cross-validation auto-correction                                            |
| `procedures/phase6-finalize.md`          | LUÔN chạy (cũng entry từ VERIFY_ONLY)     | Update registry + reports + phase-summary                                   |
| `procedures/flow-multi.md`               | Flag `--features` được set               | Multi-feature orchestration + micro-task                                    |

## Workflow Position

```
/wf-design → /wf-plan-modules → /wf-implement-feature ← YOU ARE HERE → /wf-verify-sync
```

---

## --status / --resume Handlers

> Logic đầy đủ (auto-migrate chain, SYSTEM_SLUG/SESSION_DIR resolution, soft-resume fallback):
> [procedures/status-resume.md](procedures/status-resume.md). FEATURE_SLUG Derivation luôn chạy đầu tiên (bên dưới).

### FEATURE_SLUG Derivation (Luôn chạy đầu tiên — v4.0 delegated to bash)

```
FEATURE_SLUG derive từ argument đầu tiên (trước flags):
  IF argument match FEAT-ID pattern (FEAT-[A-Z]+-[0-9]+):
    → Read req-registry.json → find feature by id → extract feature.title
    → Apply normalize_slug(title) → FEATURE_SLUG
    → IF NOT FOUND in registry → STOP (Error E103, alias E003)
  ELIF argument match REQ-ID pattern (REQ-[A-Z]+-[0-9]+):
    → Read req-registry.json → find feature by req_id → extract feature.title → normalize_slug
    → IF NOT FOUND → STOP (Error E103, alias E003)
  ELSE:
    → Argument là feature name trực tiếp → normalize_slug → FEATURE_SLUG

normalize_slug() — v4.0 delegated to bash script:
  source .claude/scripts/wf-implement-feature/implement-common.sh
  SLUG=$(normalize_slug "$TITLE")

  Implementation chi tiết: `.claude/scripts/wf-implement-feature/implement-common.sh`
  function `normalize_slug()` — Vietnamese-safe manual lookup table + ASCII translit fallback,
  cross-platform reliable trên Git Bash Windows + WSL + Linux + macOS.

Ví dụ:
  FEAT-CRM-CUST-001 → "Customer Management" → "customer-management"
  FEAT-STW-ACCT-002 → "Đăng nhập SmartTax (email/password + JWT)" → "dang-nhap-smarttax-email-password-jwt"
  "Quản lý Văn bản Pháp luật" → "quan-ly-van-ban-phap-luat"
  REQ-CRM-CUST-001 → registry lookup → feature title → normalize_slug
```

---

## Phase 0: Auto-Detection & Routing (BẮT BUỘC — chạy trước tiên)

**PRE-GATE:** `test -n "$ARGUMENTS"` — Phải có feature name hoặc flag

### CI PRE-GATE: Code Intelligence Detection (Protocol 20 §20.8)

> **Protocol:** `.claude/skills/protocols/20-code-intelligence.md` — CI-ROUTE convention.
> CI tools được auto-detect, không hỏi user (D7). Lock held → fallback Grep/Glob ngay (D8).
> Graceful degradation: thiếu tool → fallback → Grep/Glob (current behavior, zero regression).

| Step | Action | Verify |
| ---- | ------ | ------ |
| 0.Na | **Load CI Capabilities:** Run `bash .claude/scripts/ci-detect.sh` → check per-tool TTL. ALL fresh → load cache. ANY stale + lock acquired → scan MCP tools → write cache → release. Lock held → exit 2 → fallback Grep/Glob (current behavior). Read `.mc-data/work/_meta/code-intelligence.json` → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. | CI flags set |
| 0.Nb | **Index Freshness Check:** Run `bash .claude/scripts/ci-freshness-check.sh` → so sánh HEAD vs index_commit. exit 0 (ok) → continue. exit 1 (light, ≤5 behind) → slight warning. exit 2 (strong, 6-20 behind) → prominent warning. exit 3 (severe, >20 behind) → urgent warning + gợi ý re-index. Short-circuit: non-git → skip. Lưu freshness status để inject vào agent context. | Freshness status set |
| 0.Nc | **Agent Context Injection:** IF CI available → `bash .claude/scripts/ci-inject-context.sh` → 4 templates auto-select (Both-OK, Both-Stale, GitNexus-only, Serena-only) → append vào agent spawn instructions. IF no CI → exit 1 → continue Grep/Glob. | CI context ready (hoặc skipped) |

**Graceful:** ci-detect.sh fail → WARNING → continue without CI. ci-freshness-check.sh fail → skip → continue. Lock held → fallback Grep (không block, không regression). Non-git → skip all CI.

| Step | Action                                                                                                                                                                                                                                                                                                                                          | Verify                                   |
| ---- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| 0.0a | **[v3→v4 Auto-Migration]** Run `bash .claude/scripts/wf-implement-feature/implement-migrate-v3-to-v4.sh` (idempotent). Migrate flat v3.x data → `sessions/{date}-migrated/`.                                                                                                                                                  | Migration script exit 0                  |
| 0.0b | **[v4→v5 Auto-Migration]** Run `bash .claude/scripts/wf-implement-feature/implement-migrate-v4-to-v5.sh` (idempotent — no-op nếu `.layout-version=5`). Migrate flat `$FEATURE_SLUG/` → `$SYSTEM_SLUG/$FEATURE_SLUG/`. Locks và cache cũng scope theo system. Orphans → `_orphan/`.                                          | Migration script exit 0                  |
| 0.1  | `source .claude/scripts/wf-implement-feature/implement-common.sh; trace_event "START" "" ""` (CORE-026)                                                                                                                                                                                                                                       | JSON appended to _trace/session-log.json |
| 0.2  | Parse `$ARGUMENTS` → detect `--features`, `--resume`, `--status`, `--parallel`, `--skip-review`, `--micro-task`, `--component`, `--fresh`, `--system=<slug>`, `--from-fix-bugs[=<id>]` flags. **`--from-fix-bugs`:** `HAS_FROM_FIX_BUGS_FLAG=$([[ "$ARGUMENTS" == *"--from-fix-bugs"* ]] && echo true \|\| echo false); FROM_FIX_BUGS_SESSION_ID=$(echo "$ARGUMENTS" \| grep -oP -- '--from-fix-bugs=\K[^ ]+' \|\| echo "")` | Flags identified                         |
| 0.2b | **Derive `$FEATURE_SLUG`** (xem "FEATURE_SLUG Derivation" bên trên) → `source implement-common.sh; SLUG=$(normalize_slug "$TITLE")` | `$FEATURE_SLUG` set                                                                                                                                                                        |                                          |
| 0.2b2 | **[v5.0] Derive `$SYSTEM_SLUG`** từ registry (auto) hoặc `--system=<slug>` (override). Logic: `SYSTEM_OVERRIDE=$(echo "$ARGUMENTS" \| grep -oP -- '--system=\K[^ ]+' \|\| echo ""); SYSTEM_SLUG=$(derive_system_slug "$FEAT_ID_OR_SLUG" "$SYSTEM_OVERRIDE")`. Nếu `_unknown` AND không có `--system` → WARN: "Feature không có trong registry. Dùng `--system=<slug>` hoặc thêm feature vào registry." | `$SYSTEM_SLUG` set       |
| 0.2c | **[Per-Feature Lock — v5.0]** `bash .claude/scripts/wf-implement-feature/implement-acquire-lock.sh --system=$SYSTEM_SLUG --slug=$FEATURE_SLUG --type=feature --resume=$([[ "$ARGUMENTS" == *"--resume"* ]] && echo true \|\| echo false) --feature-id="$FEAT_ID"`. Exit 1 → "Feature đang được session khác implement. Dùng `--resume` hoặc đợi." | Lock acquired (exit 0)                   |
| 0.2d | **[v5.0 Session Dir]** `SESSION_DIR=$(source implement-common.sh; resolve_session_dir "$SYSTEM_SLUG" "$FEATURE_SLUG" "$([[ "$ARGUMENTS" == *"--resume"* ]] && echo true \|\| echo false)")`                                                                                                                                  | `$SESSION_DIR` resolved                  |
| 0.2e | **[v4.0 --fresh handler]** IF `--fresh` AND có session đang dở → archive cũ: `mv $FEATURE_DIR/sessions/$OLD $FEATURE_DIR/archived/`, sau đó `resolve_session_dir` tạo session mới.                                                                                                                                         | Old archived                             |
| 0.3  | IF `--features` → Load `procedures/flow-multi.md` → STOP (flow-multi.md xử lý toàn bộ)                                                                                                                                                                                                                                                | Routed                                   |
| 0.4  | ELSE → Set `$PARALLEL_MODE` = (`--parallel` hoặc `--features` flag)                                                                                                                                                                                                                                                                     | Mode set                                 |
| 0.5  | Tiến vào Phase Orchestration (xem bảng dưới)                                                                                                                                                                                                                                                                                               | Orchestration started                    |

**POST-GATE:** Route xác định, flags parsed, per-feature lock acquired, `$SESSION_DIR` resolved.

### §Per-Feature Lock Protocol (v4.0 — delegated to bash)

> **Lý do:** Ngăn 2 sessions cùng implement 1 feature (user có thể chạy nhầm 2 lần cùng FEAT-ID
> ở 2 IDE windows). v4.0 delegate toàn bộ logic sang `implement-acquire-lock.sh`.

**Lock file:** `.mc-data/work/wf-implement-feature/.locks/$SYSTEM_SLUG/$FEATURE_SLUG.lock`

**Acquire (Phase 0.2c):**

```bash
bash .claude/scripts/wf-implement-feature/implement-acquire-lock.sh \
  --slug=$FEATURE_SLUG \
  --type=feature \
  --feature-id="$FEAT_ID" \
  --resume=$([[ "$ARGUMENTS" == *"--resume"* ]] && echo true || echo false)
# Exit 0 = acquired, Exit 1 = busy → STOP

# Setup release trap (in calling shell context)
trap "rm -f '.mc-data/work/wf-implement-feature/.locks/$SYSTEM_SLUG/$FEATURE_SLUG.lock'" EXIT
```

Lock content (JSON, set bởi script):

```json
{
  "type": "feature",
  "feature_slug": "customer-management",
  "feature_id": "FEAT-CRM-CUST-001",
  "pid": 12345,
  "host": "laptop-pc",
  "user": "cntt",
  "started_at": "2026-04-26T11:30:00Z",
  "scope_files_exclusive": []
}
```

**Update scope_files_exclusive sau Phase 0.7 (khi A2.4 đã parse):**

```bash
LOCK_FILE=".mc-data/work/wf-implement-feature/.locks/$SYSTEM_SLUG/$FEATURE_SLUG.lock"
TMP=$(mktemp)
jq --argjson files "$SCOPE_EXCLUSIVE_JSON" '.scope_files_exclusive = $files' "$LOCK_FILE" > "$TMP" && mv "$TMP" "$LOCK_FILE"
```

**Release** (Phase 6 step 6.8 + EXIT trap):

```bash
rm -f ".mc-data/work/wf-implement-feature/.locks/$SYSTEM_SLUG/$FEATURE_SLUG.lock"
```

> Stale detection (PID dead OR age > 60min), cross-host detection, atomic create — đã handle hoàn toàn trong script. Xem `.claude/scripts/wf-implement-feature/implement-acquire-lock.sh`.

---

## Phase Orchestration (Single-Feature — thay thế flow.md)

Load các phase files theo thứ tự sau. Mỗi file chỉ load khi cần — giúp giảm context.

| #  | File                                                           | Load khi                                 | Mục đích                          |
| -- | -------------------------------------------------------------- | ---------------------------------------- | ------------------------------------ |
| 1  | `procedures/phase0-existing-analysis.md`                     | `$SCENARIO != "new"` (EXTEND/MODIFY)   | Scan existing patterns               |
| 2  | `procedures/phase0-5-context-setup.md`                       | Always                                   | LEGACY_MODE + Decision Registry      |
| 3  | `procedures/phase0-6-env-profile.md`                         | Always (SAU phase0-5)                    | Environment profile (v5.1+)          |
| 4  | `procedures/phase1-feature-context.md`                       | Always                                   | Feature context + digest             |
| 5  | `procedures/phase0-7-safety-gate.md`                         | Always (SAU phase1)                      | Safety gate + env scan + 3 modes     |
| — | *(IF `$CONFIRMED_STRATEGY == VERIFY_ONLY` → jump to #10)* |                                          |                                      |
| 5  | `procedures/phase2-planning.md`                              | `$CONFIRMED_STRATEGY != "VERIFY_ONLY"` | Task + batch plan                    |
| 5b | `procedures/phase2-4-populate-spec.md`                       | `$A6_EXT_NEEDS_POPULATE == true`       | Architect populate A6-EXT (khi STUB) |
| 6  | `procedures/phase2-5-contracts.md`                           | `$PARALLEL_MODE == true`               | Contract-first                       |
| 7  | `procedures/phase3-tdd.md`                                   | `$CONFIRMED_STRATEGY != "VERIFY_ONLY"` | TDD implementation                   |
| 8  | `procedures/phase4-5-review-fix.md`                          | `--skip-review != true`                | Review-Fix Loop                      |
| 9  | `procedures/phase5a-crossval.md`                             | Always                                   | Auto-correction loop                 |
| 10 | `procedures/phase6-finalize.md`                              | Always                                   | Registry + reports + summary         |

> **`_shared.md`:** KHÔNG load standalone — chỉ tham chiếu section cụ thể từ phase files khi cần agent contexts, protocols refs, error codes.

**State variables passed between phases:** Xem `procedures/_shared.md §Execution Flow Between Phase Files`.

---

## Phase 1–6: Execution Summary (delegated)

**PRE-GATE Phase 1:** `test -n "$FEATURE_NAME" || test -n "$REQ_ID"`

| Phase | File                                     | Output                                                                              |
| ----- | ---------------------------------------- | ----------------------------------------------------------------------------------- |
| 0     | `phase0-existing-analysis.md`          | `existing-patterns.json` (conditional)                                            |
| 0.5   | `phase0-5-context-setup.md`            | `$LEGACY_MODE`, `$CONSTRAINT_LIST`, `decision-registry.json`                  |
| 0.6   | `phase0-6-env-profile.md`              | `$ENV_PROFILE`, `$ENV_CONTEXT` (v5.1+)                                           |
| 1     | `phase1-feature-context.md`            | `impl-status.json`                                                                |
| 0.7   | `phase0-7-safety-gate.md`              | `$CONFIRMED_STRATEGY`, `$SAFETY_SCAN_FINDINGS` (routing decision)                |
| 2     | `phase2-planning.md`                   | `impl-plan.md`, `$TASK_LIST`, `$BATCHES`                                      |
| 2.5   | `phase2-5-contracts.md` (conditional)  | `contracts.json`, shared types/interfaces/DTOs                                    |
| 3     | `phase3-tdd.md`                        | Source + test files,`checkpoint.json`, new decisions                              |
| 4-5   | `phase4-5-review-fix.md` (conditional) | `qa-review-attempt-[N].md`, fixed files                                           |
| 5a    | `phase5a-crossval.md`                  | Validated files +`impl-report.md` (iteration logs)                                |
| 6     | `phase6-finalize.md`                   | Registry updated (`impl_status=done`) + `impl-report.md` + `phase-summary.md` |

**POST-GATE Phase 6 (v4.0 — delegated to bash):**

```bash
bash .claude/scripts/wf-implement-feature/implement-postgate.sh \
  --session-dir="$SESSION_DIR" \
  --req-ids="$REQ_IDS_IN_SCOPE" \
  --registry=".mc-data/docs/_meta/req-registry.json"
# Exit 0 = PASS (T1-T4 all pass)
# Exit 1 = FAIL → trigger auto-fix (max 3 retries) hoặc escalate (E602, alias E011)
```

Logic chi tiết T1-T4: xem `procedures/phase6-finalize.md §POST-GATE`.

> **Registry Safe-Write (CORE-006):** CHỈ MODIFY field `impl_status` per REQ-ID. Đọc registry ngay trước khi ghi. Không ghi đè fields của skill khác. Xem `procedures/_shared.md §Registry Safe-Write`.

> **A6-EXT Handling:** phase1 (1.6a) đọc A6-EXT section từ task file → lưu vào `$EXECUTABLE_SPEC` → phase3 Developer Agent đọc A6-EXT TRƯỚC khi tham khảo full docs. Nếu A6-EXT không tồn tại → fallback đọc A1-A6 sections bình thường.

---

## Arguments

| Flag                         | Mô tả                                                                                                    | Default                |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------- | ---------------------- |
| `[feature-name \| REQ-ID]`  | Feature cần implement (**bắt buộc**)                                                              | —                     |
| `--module=<n>`             | Chỉ định module nếu ambiguous                                                                          | —                     |
| `--extend`                 | Force EXTEND scenario                                                                                      | —                     |
| `--modify`                 | Force MODIFY scenario                                                                                      | —                     |
| `--skip-tests`             | Bỏ qua viết tests                                                                                        | —                     |
| `--skip-review`            | Bỏ qua Phase 4 (review agents) — CHỈ dùng khi hotfix khẩn cấp. Phase 5a vẫn chạy.                  | —                     |
| `--component=<type>`       | Chỉ implement 1 component:`entity/service/endpoint/frontend/test`                                       | All                    |
| `--resume`                 | Resume từ checkpoint                                                                                      | —                     |
| `--micro-task=MT-FEAT-NNN` | Implement chỉ 1 micro-task (cần A7-EXT trong task file)                                                  | Off                    |
| `--fresh`                  | Bắt đầu lại từ đầu, bỏ qua session dang dở                                                        | —                     |
| `--parallel`               | Contract-first parallel agents trong Phase 3 (requires architect)                                          | Off                    |
| `--features=FEAT-001,...`  | Implement nhiều features với scheduling tối ưu                                                         | Off                    |
| `--profile=<name>`         | Chế độ adaptive (xem "Profile System" bên dưới):`quick` / `standard` / `deep` / `exhaustive` | Auto (theo file_count) |
| `--no-cache`               | Bypass pattern cache — luôn fresh scan existing patterns                                                 | Off                    |
| `--status`                 | Hiển thị tiến độ, không thực thi                                                                    | —                     |
| `--from-fix-bugs[=<id>]`   | **(v5.2+)** Cross-check với fix-bugs session — consume `fix-impact.json` để ưu tiên features có code_files trùng `$FEATURE_SLUG` (LEGACY_MODE-friendly: detect feature đã có code edited bởi fix). Không pass `<id>` → auto-resolve latest completed session từ `_index/sessions.jsonl`. **Opt-in:** không pass flag → behavior cũ. | —                     |

---

## Profile System (v4.0+)

Profile điều phối **độ sâu xử lý** xuyên suốt Phase 2-4 — số batches, agent reviewers, và độ phủ tests. Default: `standard`. User chỉ định qua `--profile=<name>`, hoặc skill auto-detect dựa trên scope file count.

### Profile Matrix

| Profile                | Phase 3 mode         | Phase 4 review agents                                                                | Tests run                | Estimated time | Use case                     |
| ---------------------- | -------------------- | ------------------------------------------------------------------------------------ | ------------------------ | -------------- | ---------------------------- |
| `quick`              | sequential, no waves | code-reviewer only                                                                   | smoke (failed-fast)      | 5-15 min       | Hotfix, prototype, throwaway |
| `standard` (default) | sequential           | code-reviewer + qa-lead                                                              | full unit                | 15-45 min      | Daily dev work               |
| `deep`               | parallel waves auto  | code-reviewer + qa-lead + security                                                   | unit + integration       | 30-90 min      | Production-ready feature     |
| `exhaustive`         | parallel waves + e2e | code-reviewer + qa-lead + security + accessibility-auditor + performance-benchmarker | unit + integration + e2e | 60-180 min     | Release-candidate            |

### Profile Resolution

Nếu `--profile` KHÔNG được set:

- ≤ 5 files trong scope → `quick`
- 6-30 files → `standard`
- 31-100 files → `deep`
- > 100 files → `exhaustive`
  >

Resolver: `bash .claude/scripts/wf-implement-feature/implement-resolve-profile.sh --scope-files-count=N` → stdout = profile name, stderr = recommendation note.

User chỉ định `--profile=<name>` luôn override auto-recommendation.

### Profile Flag Interaction

| Flag combination                          | Behavior                                                        |
| ----------------------------------------- | --------------------------------------------------------------- |
| `--profile=quick`                       | Auto: code-reviewer only, smoke tests, sequential               |
| `--profile=quick --skip-review`         | Skip ALL review (override profile review agents)                |
| `--profile=deep --component=entity`     | Profile applies to selected components only                     |
| `--profile=exhaustive --features=A,B,C` | Mỗi feature trong batch dùng exhaustive                       |
| `--profile=quick --parallel`            | `--parallel` ignored + WARNING (quick = sequential by design) |
| `--profile=<X> --no-cache`              | Profile vẫn resolve, nhưng pattern scan luôn fresh           |

### Pattern Cache (v4.0+)

Pattern scan trong Phase 0 (existing-analysis) dùng cache với **dual invalidation** (CORE-023 — bảo thủ):

- **Cache key:** `{module_slug}|{git_sha_short}` — file: `.mc-data/work/wf-implement-feature/.cache/{system_slug}/{module_slug}/existing-patterns.{git_sha}.json`
- **TTL:** 24h — `find $CACHE_FILE -mmin -1440`
- **Git invalidation:** `git ls-tree -r HEAD -- $MODULE_PATH | sha1sum` — bắt commit thay đổi module ngay lập tức
- **Bypass:** `--no-cache` flag

Implement 2 features cùng module trong 24h → cache hit → tiết kiệm ~80% tokens scan-pattern. Cache hit/miss được log vào `impl-status.json.cache_hits` + trace event `CACHE_HIT` / `CACHE_MISS`.

Validator: `bash .claude/scripts/wf-implement-feature/implement-cache-resolver.sh --validate $CACHE_FILE` (exit 0 = valid).

---

## Implementation Scenarios

| Scenario         | Khi nào                     | `phase0-existing-analysis.md` |
| ---------------- | ---------------------------- | ------------------------------- |
| **NEW**    | Tạo feature mới (default)  | Skip                            |
| **EXTEND** | Mở rộng feature hiện có  | Required                        |
| **MODIFY** | Sửa/refactor code hiện có | Required                        |

## Partial Implementation (--component)

```bash
/wf-implement-feature FEAT-ERP-CRM-001 --component=entity
/wf-implement-feature FEAT-ERP-CRM-001 --component=frontend
```

| Type         | Files tương ứng                                    |
| ------------ | ----------------------------------------------------- |
| `entity`   | `*.entity.ts`, `*.model.ts`, `Models/*.cs`      |
| `service`  | `*.service.ts`, `*Service.cs`, `*Command.cs`    |
| `endpoint` | `*.controller.ts`, `*Controller.cs`, `routes/*` |
| `frontend` | `*.tsx`, `*.vue`, `pages/*`, `components/*`   |
| `test`     | `*.test.ts`, `*.spec.ts`, `*Tests.cs`           |

Khi `--component` được dùng: `impl_status = "done"` CHỈ khi TẤT CẢ components = "done".

## FEATURE_SLUG

`$FEATURE_SLUG` **LUÔN derive từ feature name** (không dùng FEAT-ID làm slug):

```
feature.name → lowercase, spaces → hyphens, bỏ ký tự đặc biệt
"Customer Management" → customer-management
"Authentication"      → authentication
```

Mỗi feature có riêng một subdirectory trong `work/wf-implement-feature/` — đảm bảo không ghi đè khi chạy nhiều features.

## Multi-Run Logic

> Chi tiết (resume chain per feature, session numbering, conflict rules): [procedures/flow-multi.md](procedures/flow-multi.md) §Multi-Run Logic.

## Protocols & Strategy

> **Toàn bộ logic chi tiết nằm trong các phase files `procedures/phase*-*.md` và `procedures/flow-multi.md`.**
> Agent contexts + common protocol references: xem `procedures/_shared.md`
> Protocol definitions: xem `.claude/skills/protocols/`

| Protocol                                    | Áp dụng                                                                          |
| ------------------------------------------- | ---------------------------------------------------------------------------------- |
| Protocol 3 — Context & Checkpoint + Digest | Thresholds 65/80/90% + context_digest generation + digest injection on resume      |
| Protocol 6 — Token Limit Prevention        | Developer agents có output size target. >3 input files → pre-compress bằng Grep |
| Protocol 7 — PAR-09                        | Multi-feature parallel khi không share source files                               |
| Protocol 8 — CQG-11                        | REQ-ID match + test coverage ratio + architecture compliance                       |
| Protocol 9 — PLN-10 + 9.6                  | Token estimates + proactive budget check                                           |
| Protocol 10 — POST-GATE Schema Validation  | T1→T4 tiered checks                                                               |
| Protocol 12 — Decision Registry            | Track + enforce architectural decisions                                            |
| Protocol 13 — Test Gates                   | GATE-13: tests PHẢI PASS trước khi tiếp tục                                   |

**Execution Strategy:**

| Điều kiện                   | Chế độ                                                                    |
| ------------------------------ | ---------------------------------------------------------------------------- |
| Phase 4–5: Reviews            | **PARALLEL** (spawn đồng thời)                                      |
| Phase 4–5: Fix iterations     | **SEQUENTIAL**                                                         |
| Files trong batch (độc lập) | **PARALLEL**                                                           |
| Files có dependency           | **SEQUENTIAL**                                                         |
| --parallel mode Phase 3        | **PARALLEL Waves** (Wave 1/2/3)                                        |
| --features mode                | **PARALLEL** features (độc lập), **SEQUENTIAL** (phụ thuộc) |

**Fix Rules đặc thù:**

| Loại lỗi        | Auto-Fix                   | Escalate nếu                    |
| ----------------- | -------------------------- | -------------------------------- |
| File thiếu/rỗng | Tạo từ template / re-run | Không đủ context / vẫn rỗng |
| REQ-ID thiếu     | Thêm REQ-ID comment       | Không xác định vị trí      |
| Tests fail        | Re-run, fix nếu rõ       | Logic error cần user            |
| JSON invalid      | Fix syntax                 | Structure corruption             |
| Missing test      | Tạo test stub             | Complex logic cần user          |

> **Retry:** Mỗi step retry tối đa 3 lần. Nếu vẫn fail → escalate với thông báo đầy đủ.
> **Templates:** `.claude/skills/workflow/wf-implement-feature/templates/`

---

## Output Files

| File                  | Đường dẫn                                                                                                                                                                                                                                                              | Phase File                                       | Template                             |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ | ------------------------------------ |
| Pattern analysis      | `$SESSION_DIR/existing-patterns.json`                                                                                                                                                                                                                                    | `phase0-existing-analysis.md`                  | `templates/existing-patterns.json` |
| Status file           | `$SESSION_DIR/impl-status.json`                                                                                                                                                                                                                                          | `phase1-feature-context.md`                    | `templates/impl-status.json`       |
| Decision Registry     | `$SESSION_DIR/decision-registry.json`                                                                                                                                                                                                                                    | `phase0-5-context-setup.md`                    | `templates/decision-registry.json` |
| Implementation plan   | `$SESSION_DIR/impl-plan.md`                                                                                                                                                                                                                                              | `phase2-planning.md`                           | `templates/impl-plan.md`           |
| Contracts             | `$SESSION_DIR/contracts.json` + shared types/interfaces/DTOs                                                                                                                                                                                                             | `phase2-5-contracts.md` (conditional)          | —                                   |
| Source code           | `src/**/*.{ts,py,...}` hoặc `apps/[app]/src/**/*`                                                                                                                                                                                                                     | `phase3-tdd.md`                                | —                                   |
| Test files            | `tests/**/*` hoặc `src/**/*.test.*`                                                                                                                                                                                                                                   | `phase3-tdd.md`                                | —                                   |
| Checkpoint            | `$SESSION_DIR/checkpoint.json`                                                                                                                                                                                                                                           | `phase3-tdd.md` (3.4)                          | `templates/checkpoint.json`        |
| QA Review Reports     | `$SESSION_DIR/qa-review-attempt-[N].md`                      | `phase4-5-review-fix.md`                       | `templates/qa-review-report.md` (default) hoặc `templates/qa-review-report-annotation.md` (khi `$BATCH_TYPE == annotation_only` — Finding #23) |                                                  |                                      |
| Implementation report | `$SESSION_DIR/impl-report.md`                                                                                                                                                                                                                                            | `phase5a-crossval.md` + `phase6-finalize.md` | `templates/impl-report.md`         |
| Registry (updated)    | `.mc-data/docs/_meta/req-registry.json`                                                                                                                                                                                                                                  | `phase6-finalize.md`                           | — (CHỈ update `impl_status`)     |
| Feature tasks (done)  | `.mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feature]-impl.md`                                                                                                                                                                                                | `phase6-finalize.md`                           | —                                   |
| Phase summary         | `$SESSION_DIR/phase-summary.md`                                                                                                                                                                                                                                          | `phase6-finalize.md`                           | — (CORE-028, tiếng Việt)          |

## Output Report

ALWAYS dùng template này khi hoàn thành:

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

---

## Error Handling (v4.0+ namespaced — xem `procedures/_shared.md §Error Codes Reference` cho full table)

| Code | (was)     | Tình huống                                                       | Xử lý                                                                                          |
| ---- | --------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------ |
| E103 | E001/E003 | Thiếu / không xác định feature/REQ-ID                         | Hỏi user / Retry Phase 1                                                                        |
| E102 | E002/E014 | Registry không tìm thấy / inconsistent / re-run không có flag | Chạy `/wf-analyze-requirements` / Hỏi scenario EXTEND-MODIFY                                 |
| E202 | E004a     | Feature design không tồn tại                                    | Chạy `/wf-design` trước                                                                     |
| E201 | E004b     | Task file không tồn tại                                         | Xem `phase1-feature-context.md` Step 1.6 — tự generate stub hoặc chạy `/wf-plan-modules` |
| E203 | E005      | Task list không tạo được                                      | Retry Phase 2                                                                                    |
| E204 | E015      | A6-EXT populate failed                                             | Retry Phase 2.4 với context, hoặc fallback A6                                                  |
| E303 | E006      | Source file không tạo được                                    | Retry với error context                                                                         |
| E304 | E007      | Thiếu REQ-ID trong source code                                    | Thêm REQ-ID comment                                                                             |
| E301 | E008      | Tests failing                                                      | Debug và fix                                                                                    |
| E402 | E009      | Critical/Security issues từ review                                | Fix trong Review-Fix Loop (max 3 attempts) → escalate                                           |
| E401 | E010      | Agent timeout trong Phase 4                                        | Retry 1 lần. Vẫn timeout → skip agent đó, log warning, tiếp tục với agents còn lại.    |
| E602 | E011      | POST-GATE fail sau 3 retries                                       | STOP — báo cáo chi tiết → user quyết định                                                |
| E305 | E012      | Auto-fix gây regression                                           | Rollback fix → escalate with context                                                            |
| E901 | E013      | Session dang dở, user chọn Fresh                                 | Xóa impl-status.json, impl-plan.md, checkpoint.json trong $SESSION_DIR                          |
| E601 | —        | Registry mutex timeout                                             | Kiểm tra session khác đang giữ lock — wait hoặc force release nếu stale                   |
| E501 | —        | Cross-validation auto-correction loop > 3                          | STOP — escalate với history                                                                    |

> Tất cả errors auto-logged vào `error-ledger.json` per-session qua `ledger_log` helper. Phase summary đọc ledger để render Errors & Warnings section.

---

## Related Skills

| Skill                | Quan hệ                                                       |
| -------------------- | -------------------------------------------------------------- |
| `/wf-design`       | Prerequisite                                                   |
| `/wf-plan-modules` | Prerequisite                                                   |
| `/status`          | Xem tiến độ                                                 |
| `/wf-preflight`    | **Next step** — kiểm tra sức khỏe sau implement      |
| `/wf-fix-bugs`     | Alternative — chạy khi cần fix bugs thay vì implement mới |
| `/wf-verify-sync`  | **Next step** — verify traceability                     |
