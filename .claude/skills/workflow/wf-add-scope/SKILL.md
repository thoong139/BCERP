---
name: wf-add-scope
version: 3.0.0
last_updated: 2026-04-29
description: |
  Thêm modules/features mới vào dự án đã có — SAFE-APPEND ONLY.
  v3.0.0: session isolation (sessions/{YYYY-MM-DD}-{sys-slug}/), dual lock (session + registry),
  heartbeat daemon, JSONL index, scope-impact.json cross-skill artifact, 12 bash scripts (76% token saving).
  Giải quyết gap: wf-analyze-requirements và wf-define-features giả định workflow "from scratch",
  không có path incremental để bổ sung scope vào registry đang active mà không phá data hiện có.

  Use cases:
  - Dự án legacy phát hiện orphan systems (registry có systems[] nhưng thiếu modules)
  - Dự án đã qua Phase 5+ cần thêm module mới mà không muốn regen full Phase 1
  - Bổ sung features cho module đã có trong registry nhưng chưa có feature specs

  TRIGGER khi:
  - /wf-plan-modules Phase 1.7 detect orphan systems và user chọn [1] STOP để bổ sung upstream
  - User hỏi "thêm module X vào registry", "bổ sung features cho module Y"
  - Keywords: "add module", "add system", "bổ sung scope", "thêm features", "register module"
  - Legacy project có code nhưng chưa được track trong registry (xem module-code-mapping.json)

  KHÔNG trigger khi:
  - Dự án mới hoàn toàn → dùng /wf-analyze-requirements
  - Cần regen toàn bộ Phase 1 → dùng /wf-analyze-requirements
  - Cần sửa module đã tồn tại → edit trực tiếp hoặc chạy /wf-define-features [module-name]

argument-hint: "--system=<sys-id> [--modules=<list>] [--from-mapping] [--from-scan=<session-id|path>] [--interactive] [--dry-run] [--no-docs] [--status] [--resume]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, AskUserQuestion, TodoWrite
---
# /wf-add-scope: $ARGUMENTS

## Overview

| Mục                    | Nội dung                                                                                 |
| ----------------------- | ----------------------------------------------------------------------------------------- |
| **Mục đích**   | Safe-append modules + features vào registry đã có (không regen)                      |
| **Prerequisites** | `req-registry.json` tồn tại + system target đã có trong `systems[]`              |
| **Duration**      | 10-30 phút (scales với số modules)                                                     |
| **Phases**        | 9 phase files (session-init + resume-routing + 0-6) + _shared.md — lazy-loaded         |
| **Input**         | Registry + (LEGACY_MODE: module-code-mapping.json + code files)                           |
| **Output**        | Registry updates (append-only) + Phase 2 feature stubs (optional)                         |
| **Procedure**     | `procedures/phaseN-*.md` (load per-phase) + `procedures/_shared.md` (protocols chung) |

### Workflow Position

```
/wf-plan-modules Phase 1.7 escalation STOP → /wf-add-scope ← YOU ARE HERE → /wf-plan-modules (re-run)
                                                                          → /wf-define-features (optional flesh-out)
```

### Relationship với existing skills

| Skill                          | So sánh                                                                                                       |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------- |
| `/wf-analyze-requirements`   | Phân tích requirements từ scratch → tạo systems/modules/departments/requirements. Dùng khi dự án mới. |
| `/wf-define-features`        | Tạo feature specs từ modules ĐÃ CÓ trong registry. Không tạo modules mới.                              |
| `/wf-add-scope` (skill này) | **Safe-append** modules + features vào registry. Dùng khi bổ sung scope incremental.                  |

### SKILL.md ↔ procedures/ Phase Mapping

| Phase                        | procedures/ file                   | Luôn chạy | Điều kiện                                |
| ---------------------------- | ---------------------------------- | ----------- | ------------------------------------------- |
| **Session Init**       | `procedures/session-init.md`     | ✅          | Entry — always (trước Phase 0 main)       |
| **Resume Routing**     | `procedures/resume-routing.md`   | ❌          | `--resume` flag only                       |
| **0 Context**          | `procedures/phase0-context.md`   | ✅          | Entry — always                             |
| **1 Scope**            | `procedures/phase1-scope.md`     | ✅          | Always                                      |
| **2 Feature Stubs**    | `procedures/phase2-stubs.md`     | ❌          | `$LEGACY_MODE == true`                    |
| **3 Dry-Run**          | `procedures/phase3-dryrun.md`    | ✅          | Always (STOP nếu `--dry-run`)            |
| **4 Safe-Append**      | `procedures/phase4-append.md`    | ❌          | User confirmed + `--dry-run` OFF          |
| **5 Doc Stubs**        | `procedures/phase5-docs.md`      | ❌          | `--no-docs` OFF + `features_to_add > 0` |
| **6 Report + Summary** | `procedures/phase6-report.md`    | ✅          | Always (kể cả sau DRY_RUN STOP)           |

### Load-on-Demand Pattern

AI chỉ đọc phase file đang thực thi + `_shared.md` (cho protocols/templates chung) — KHÔNG đọc toàn bộ `procedures/` 1 lần. Tiết kiệm ~60-70% tokens so với monolithic `flow-new.md` cũ.

- **Entry:** Luôn load `procedures/session-init.md` (session init) → `procedures/phase0-context.md` + `procedures/_shared.md`
- **Resume:** `--resume` flag → load `procedures/resume-routing.md` → discover session qua `_index/sessions.jsonl` → route to phase file
- **Shared content** (State Variables, Safe-Write, Fix Rules, Error Codes, LEGACY detection, Trace pattern): tất cả ở `_shared.md`

---

## Arguments

| Flag                  | Mô tả                                                                               | Default                      |
| --------------------- | ------------------------------------------------------------------------------------- | ---------------------------- |
| `--system=<sys-id>` | **BẮT BUỘC.** System ID target (phải tồn tại trong `registry.systems[]`) | —                           |
| `--modules=<list>`  | Danh sách module names (comma-separated, lowercase). VD:`crm,orders,finance`       | — (interactive nếu thiếu) |
| `--from-mapping`    | LEGACY_MODE only. Auto-detect modules từ `module-code-mapping.json`                | false                        |
| `--from-scan=<session-id\|path>` | **OPTIONAL (Sprint 5 cross-skill).** Seed modules/features từ `wf-scan-target` target-map.json — đọc `consumer_hints["wf-add-scope"].modules_to_seed` và `module_code_mapping`. Idempotent: skip nếu module đã tồn tại. | —                           |
| `--interactive`     | Interactive mode —`AskUserQuestion` cho mỗi module + feature                      | false                        |
| `--dry-run`         | Preview changes, KHÔNG ghi vào registry                                             | false                        |
| `--no-docs`         | Skip tạo Phase 2 feature doc stubs (chỉ update registry)                            | false                        |
| `--status`          | Hiển thị state từ `add-scope-status.json`                                        | —                           |
| `--resume`          | Resume từ checkpoint                                                                 | —                           |

**Ví dụ:**

```bash
# Interactive mode — safest cho dự án mới chưa legacy-scanned
/wf-add-scope --system=SYS-ERP-WEB --interactive

# Auto-detect từ legacy scan (recommended cho legacy projects)
/wf-add-scope --system=SYS-ERP-WEB --from-mapping

# Explicit list
/wf-add-scope --system=SYS-ERP-WEB --modules=crm,orders,finance,wms,tms

# Sprint 5 cross-skill — seed từ wf-scan-target (OPTIONAL)
/wf-add-scope --system=SYS-ERP-WEB --from-scan=2026-04-27-crm

# Preview changes
/wf-add-scope --system=SYS-ERP-WEB --from-mapping --dry-run
```

> **Sprint 5 cross-skill — `--from-scan`:** OPTIONAL flag đọc `target-map.json` từ session
> `wf-scan-target` (tại `.mc-data/work/wf-scan-target/sessions/<id>/target-map.json`) và seed
> `modules[]` + `features[]` từ `consumer_hints["wf-add-scope"]` + `module_code_mapping`.
> Idempotent: skip module/feature đã có trong registry. KHÔNG thay đổi default behavior —
> không pass `--from-scan` thì skill chạy như cũ.

---

## Protocols & Strategy

> **Protocol:** Xem `.claude/skills/protocols/` — Protocol 10 (POST-GATE tiered), Protocol 10.4 (Forensic PRE-GATE), Protocol 14 (Phase Summary), Protocol 15 (Session Log), Protocol 19 (Template Usage Rule).
>
> **Internal shared:** Xem `procedures/_shared.md` — State Variables, Template Usage, Safe-Write Protocol (CORE-006), Fix Rules, Error Codes, LEGACY Detection (CORE-021), Legacy Decisions (CORE-022), Resume Routing, Trace Pattern.

### Priority Ladder (BẮT BUỘC)

1. **Độ chính xác, tính nhất quán, tính đầy đủ, bảo mật** — CORE-023
2. **Tốc độ và song song hóa** — chỉ sau khi mục 1 được bảo vệ

### Execution Strategy

| Điều kiện                                | Chế độ                                      |
| ------------------------------------------- | ---------------------------------------------- |
| Parse input, validate system (Phase 0)      | **SEQUENTIAL**                           |
| Auto-detect từ mapping (Phase 1, LEGACY)   | **SEQUENTIAL** (1 pass qua mapping.json) |
| Build module entries (Phase 1)              | **SEQUENTIAL**                           |
| Generate feature stubs per module (Phase 2) | **PARALLEL** (mỗi module độc lập)    |
| Safe-append registry (Phase 4)              | **SEQUENTIAL** (1 atomic write)          |
| Create Phase 2 doc stubs (Phase 5)          | **PARALLEL** (mỗi file độc lập)      |

> **Agent Invocation:** Skill này xử lý trực tiếp (không spawn agents). Lý do: logic thuần túy data manipulation + template generation. Không cần domain expertise.

### Safe-Write Summary (CORE-006)

**Fields OWNED:** `modules[]`, `features[]` — APPEND-ONLY.
**Fields NOT TOUCHED:** `project`, `systems[]`, `departments[]`, `requirements[]`, `interface_type`, `design_status`, `ux_design_status`, `implementation_order`, per-REQ `impl_status`.

> Chi tiết đầy đủ + validation rules: `procedures/_shared.md §3`.

### Fix Rules Summary

| Loại lỗi                      | Auto-Fix            | Escalate                    |
| ------------------------------- | ------------------- | --------------------------- |
| Module ID đã tồn tại        | SKIP + log          | —                          |
| Module name trùng (khác ID)   | Rename `-2`       | User từ chối              |
| Registry JSON invalid sau write | Rollback từ backup | Backup không đọc được |
| Phase 2 doc stub path conflict  | SKIP + log          | —                          |

> Chi tiết + error codes đầy đủ: `procedures/_shared.md §5-6`.

---

## Phase 0 Entry & Routing

**PRE-GATE:**

```bash
test -f .mc-data/docs/_meta/req-registry.json
jq -e '.systems | length > 0 and .modules != null' .mc-data/docs/_meta/req-registry.json
```

Nếu FAIL → STOP E004: *"Registry JSON invalid hoặc không tồn tại. Fix manually hoặc chạy `/wf-brainstorm` trước."*

| Step | Action |
|------|--------|
| 0 | Session Init: `Read procedures/session-init.md` → SI.1-SI.7 → returns `$SESSION_ID`, `$SESSION_DIR`, `$LOCK_PATH`, `$HEARTBEAT_PID` |
| 1a | `--status` flag: Read `procedures/phase0-context.md §Step 0.2` → STOP sau khi hiển thị sessions table |
| 1b | `--resume` flag: Load `procedures/resume-routing.md` → discover sessions via `sessions.jsonl` → CDG → re-acquire lock + restart heartbeat → route to checkpoint phase |
| 2 | Normal entry: `Read procedures/phase0-context.md + procedures/_shared.md` → execute Phase 0 → return → continue theo Phase Routing Map |

---

## Phase Routing Map (lazy-loaded)

> SKILL.md routing block KHÔNG chứa execution steps. Toàn bộ logic chi tiết được lazy-load
> qua các phase files riêng. Read MỖI phase file CHỈ KHI tới phase tương ứng để giảm context load.

| Phase       | Procedure file                   | Điều kiện                                | Mục đích                                                                                                         |
| ----------- | -------------------------------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| **0** | `procedures/phase0-context.md` | Always (entry)                              | Session init + mkdir + PRE-GATE forensic + parse args + validate system + LEGACY_MODE detect + init status files    |
| **1** | `procedures/phase1-scope.md`   | Always                                      | Build `scope-spec.json` từ source (from-mapping / modules-list / interactive) + dedup + legacy decisions respect |
| **2** | `procedures/phase2-stubs.md`   | `$LEGACY_MODE == true`                    | Auto-detect features từ code sub-dirs + inherit req_ids từ parent backend module                                  |
| **3** | `procedures/phase3-dryrun.md`  | Always                                      | Build `dry-run-diff.md` preview + CDG user confirm + STOP nếu `--dry-run`                                      |
| **4** | `procedures/phase4-append.md`  | User confirmed +`--dry-run` OFF           | Backup + atomic append modules/features + validate post-write + rollback on failure                                 |
| **5** | `procedures/phase5-docs.md`    | `--no-docs` OFF + `features_to_add > 0` | Tạo Phase 2 feature stubs (PARALLEL per feature)                                                                   |
| **6** | `procedures/phase6-report.md`  | Always                                      | Terminal report + phase-summary.md (CORE-028) + execution trace COMPLETE (CORE-026) + T1→T4 POST-GATE              |

**Routing flow:**

```
SKILL.md Phase 0 Entry → Read procedures/session-init.md → execute SI.1-SI.7 → return
   ↓ ($SESSION_ID, $SESSION_DIR, $LOCK_PATH, $HEARTBEAT_PID set)
Read procedures/phase0-context.md → execute → return
   ↓
Read procedures/phase1-scope.md → execute → return
   ↓
IF $LEGACY_MODE == true:
   Read procedures/phase2-stubs.md → execute → return
ELSE:
   Skip Phase 2 (features defer to /wf-define-features)
   ↓
Read procedures/phase3-dryrun.md → execute → USER GATE
   ↓
IF $DRY_RUN == true OR user denied:
   → Jump to procedures/phase6-report.md (report-only path)
ELSE:
   Read procedures/phase4-append.md → execute → return
   ↓
   IF $NO_DOCS == false AND features_to_add > 0:
      Read procedures/phase5-docs.md → execute → return
   ↓
Read procedures/phase6-report.md → execute → STOP
```

> **Mỗi phase file là self-contained** — chứa PRE-GATE, INPUT, OUTPUT, Steps, POST-GATE riêng.
> Phase file tham chiếu `procedures/_shared.md` cho cross-cutting: State Variables, Safe-Write, Template Usage, Fix Rules, Error Codes, LEGACY detection, Resume Routing.

### Phase 1 — Scope (Lazy-loaded)
> Tham chiếu: `procedures/phase1-scope.md`. Build `scope-spec.json` từ source (from-mapping / modules-list / interactive) + dedup + legacy decisions respect.

### Phase 2 — Feature Stubs (Lazy-loaded, LEGACY only)
> Tham chiếu: `procedures/phase2-stubs.md`. Auto-detect features từ code sub-dirs, chỉ chạy khi `$LEGACY_MODE == true`.

### Phase 3 — Dry-Run (Lazy-loaded)
> Tham chiếu: `procedures/phase3-dryrun.md`. Build `dry-run-diff.md` + CDG user confirm. STOP nếu `--dry-run`.

### Phase 4 — Safe-Append (Lazy-loaded)
> Tham chiếu: `procedures/phase4-append.md`. Backup + registry lock + atomic append + validate + rollback on fail.

### Phase 5 — Doc Stubs (Lazy-loaded)
> Tham chiếu: `procedures/phase5-docs.md`. Tạo Phase 2 feature stubs (PARALLEL per feature), skip nếu `--no-docs`.

### Phase 6 — Report & Summary (Lazy-loaded)
> Tham chiếu: `procedures/phase6-report.md`. Terminal report + scope-impact.json + phase-summary.md + JSONL update + lock release.

---

## Output Files

| #  | File            | Path                                                                   | Phase | Template                                                   |
| -- | --------------- | ---------------------------------------------------------------------- | ----- | ---------------------------------------------------------- |
| 1  | Status          | `$SESSION_DIR/add-scope-status.json`                                 | 0     | `templates/add-scope-status.json`                        |
| 2  | Plan            | `$SESSION_DIR/add-scope-plan.md`                                     | 0     | `templates/add-scope-plan.md`                            |
| 3  | Scope spec      | `$SESSION_DIR/scope-spec.json`                                       | 1     | `templates/scope-spec.json`                              |
| 4  | Dry-run diff    | `$SESSION_DIR/dry-run-diff.md`                                       | 3     | — (inline)                                                |
| 5  | Registry        | `.mc-data/docs/_meta/req-registry.json`                              | 4     | — (safe-append:`modules`, `features`)                 |
| 6  | Registry backup | `.mc-data/docs/_meta/req-registry.json.pre-addscope-<ts>`            | 4     | — (as-backup-registry.sh)                                |
| 7  | Phase 2 stubs   | `.mc-data/docs/phase2-features/[sys-slug]/[mod-slug]/[feat-slug].md` | 5     | `templates/feature-stub.md`                              |
| 8  | scope-impact    | `$SESSION_DIR/scope-impact.json`                                     | 6     | `templates/scope-impact.json` (as-scope-impact-build.sh) |
| 9  | Phase summary   | `$SESSION_DIR/phase-summary.md`                                      | 6     | `doc-framework/_meta/phase-summary.template.md`          |
| 10 | Execution trace | `.mc-data/work/_trace/session-log.json`                              | 6     | `doc-framework/_meta/session-log.template.json` (APPEND) |
| 11 | Session lock    | `$SESSION_DIR/.session.lock`                                         | init  | — (as-acquire-lock.sh)                                   |
| 12 | JSONL index     | `.mc-data/work/wf-add-scope/_index/sessions.jsonl`                   | init+6| — (as-index-append.sh, APPEND)                           |
| 13 | Checkpoint      | `$SESSION_DIR/checkpoint.json`                                       | any   | `templates/checkpoint.json`                              |

**Next steps:** `/wf-define-features` (flesh-out stubs) → `/wf-plan-modules` (re-run) → `/wf-annotate-code` (REQ-IDs)

### Template Usage Rule (CORE-031)

> **BẮT BUỘC:** Mọi file có template PHẢI được tạo bằng pattern **READ** → **POPULATE** → **WRITE**.
> **SKIP bước READ template → STOP skill.**
>
> Chi tiết mapping template ↔ output path: `procedures/_shared.md §2`.

---

## Context & Checkpoint

| Context Usage | Hành động                        |
| ------------- | ----------------------------------- |
| < 65%         | Tiếp tục bình thường           |
| 65-80%        | Chuẩn bị checkpoint               |
| 80-90%        | Lưu checkpoint ngay                |
| > 90%         | FORCE STOP — checkpoint bắt buộc |

> Resume Process + Routing chi tiết → `procedures/resume-routing.md` (v3.0, tách từ `_shared.md §9`).

---

## Error Handling

> Chi tiết đầy đủ: `procedures/_shared.md §6` — bao gồm xử lý, rollback path, và escalation criteria.

| Code | Tình huống | Xử lý |
|------|------------|-------|
| E001 | System ID không tồn tại trong registry | STOP → liệt kê available systems → hỏi user |
| E002 | Thiếu `--from-mapping` / `--modules` / `--interactive` | STOP → yêu cầu user chọn 1 mode |
| E003 | `--from-mapping` nhưng không phải LEGACY_MODE | STOP → hướng dẫn chạy `/wf-legacy-scan` trước |
| E004 | Registry JSON invalid khi đọc | STOP → yêu cầu user fix registry manually |
| E005 | Write failed / validation failed | ROLLBACK từ backup → STOP → log error chi tiết |
| E006 | All modules trong list đã tồn tại (0 new) | WARNING → exit cleanly với report "nothing to do" |
| E007 | Phase 2 stub path conflict với non-stub file | SKIP stub + log warning (không overwrite user content) |
| E008 | target-map.json not found hoặc missing consumer_hints (--from-scan) | STOP → hướng dẫn check path hoặc chạy lại /wf-scan-target Sprint 5+ |
| E010 | Session đang chạy bởi process khác (lock alive) | STOP → hiển thị PID + host → CDG (chờ/force-cancel) |
| E011 | Lock giữ bởi host khác (cross-host) | STOP → hiển thị host + age → CDG takeover nếu stale |
| E012 | Lock acquire failed — filesystem error | STOP → check disk space + permissions tại `$WORK_ROOT` |

---

## Related Skills

| Skill                        | Quan hệ                                                                                |
| ---------------------------- | --------------------------------------------------------------------------------------- |
| `/wf-analyze-requirements` | **Orthogonal** — analyze là for-scratch, add-scope là incremental              |
| `/wf-define-features`      | **Next step (optional)** — dùng để flesh-out feature stubs                    |
| `/wf-plan-modules`         | **Next step (recommended)** — sau add-scope, re-run để update Phase 5 planning |
| `/wf-legacy-scan`          | **Upstream** — phải chạy trước nếu dùng `--from-mapping`                 |
| `/wf-annotate-code`        | **Downstream** — annotate code với REQ-ID sau khi features đã add             |
| `/wf-manage-change`        | **Orthogonal** — manage-change sửa/xóa existing; add-scope chỉ append mới    |

---

## Design Rationale

### Tại sao cần skill này?

Trước v1.0, workflow DEVKIT có **gap nghiêm trọng** cho LEGACY projects:

1. `wf-analyze-requirements` assume full regen — rủi ro mất data khi chỉ muốn thêm scope
2. `wf-define-features [module-name]` giả định module đã tồn tại — không tạo module mới
3. Không có "incremental add" path → user phải manual-edit JSON → dễ lỗi, không safe-write
4. Đặc biệt với LEGACY projects sau khi chạy nhiều phases, phát hiện orphan systems → không có skill nào fix được

### Design Principles

1. **Single Responsibility:** CHỈ add scope. Không regen, không re-analyze, không delete.
2. **Safe by default:** `--dry-run` first, backup trước khi write, atomic operations.
3. **LEGACY-aware:** Leverage existing `module-code-mapping.json` để auto-detect modules.
4. **Idempotent:** Re-run an toàn — already-exist entries bị skip, không duplicate.
5. **Transparent:** Mọi changes đều có preview + backup + rollback path rõ ràng.
6. **Lazy-load procedures (v2.0.0+):** 9 phase files + `_shared.md` — AI chỉ load phase file cần thiết, giảm 60-70% context usage so với monolithic `flow-new.md` cũ.
7. **Session Isolation (v3.0.0):** Mỗi run có `sessions/{YYYY-MM-DD}-{sys-slug}/` riêng — không ghi đè session cũ, safe concurrent access, resume chính xác.
8. **Dual Lock + Heartbeat (v3.0.0):** Session lock (full duration) + registry lock (Phase 4 only, <30s) + heartbeat daemon (30s interval, 60min stale threshold) — cross-process + cross-host safety.
9. **JSONL Index + scope-impact.json (v3.0.0):** Append-only session index + cross-skill artifact cho wf-verify-sync, wf-preflight, wf-implement-feature consumers.

### Tại sao KHÔNG patch vào wf-analyze-requirements?

- `wf-analyze-requirements` đã phức tạp với 14 phase files trong `procedures/`
- Thêm `--add-system` flag sẽ branch logic phức tạp, rủi ro regression cao
- Violates Single Responsibility Principle
- Làm khó test/debug
