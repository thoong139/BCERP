---
name: wf-preflight
version: 3.0.0
last_updated: 2026-05-03
description: |
  Kiểm tra toàn diện trước khi chạy — xác nhận không có lỗi ở bất kỳ tầng nào
  (registry, docs, code, tests). Có thể scope xuống system, module, hoặc feature cụ thể.
  Output verdict rõ ràng: PASS / WARN / FAIL với score và danh sách issues kèm action.
  v3.0: Session isolation (CORE-030), lock+heartbeat, JSONL index, 10 bash scripts,
  preflight-impact.json cross-skill artifact, CDG cho --fix (CORE-027).

  TRIGGER khi:
  - User nói: "kiểm tra toàn bộ hệ thống", "chạy thử xem có lỗi không"
  - User nói: "kiểm tra [system/module/feature] cụ thể"
  - User hỏi: "ready chưa", "có lỗi gì không", "kiểm tra trước khi deploy"
  - Keywords: "preflight", "health check", "sanity check", "validate", "kiểm tra lỗi"
  - Gọi lệnh: /wf-preflight [--scope=...] [--name=...] [--fix] [--run-tests]

  KHÔNG trigger khi:
  - Chỉ cần REQ-ID sync report → /wf-verify-sync
  - Chỉ cần audit cấu trúc DEVKIT → /audit-devkit
  - Chỉ cần xem tiến độ → /status

argument-hint: "[--scope=all|system|module|feature] [--name=<id>] [--fix] [--run-tests] [--status] [--resume[=SESSION_ID]]"
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent
---
# /wf-preflight: $ARGUMENTS

## Overview

Kiểm tra toàn diện — xác nhận không còn lỗi ở mọi tầng trước khi chạy.

| Mục                    | Nội dung                                                                              |
| ----------------------- | -------------------------------------------------------------------------------------- |
| **Mục đích**   | Validate registry + docs + code + tests cho scope chỉ định — output PASS/WARN/FAIL |
| **Prerequisites** | `.mc-data/docs/_meta/req-registry.json` tồn tại + có requirements > 0           |
| **Workflow**      | Sau `/wf-implement-feature` hoặc bất kỳ lúc nào cần validate                   |
| **Input**         | `req-registry.json` + `.mc-data/docs/` + `src/` hoặc `apps/`                  |
| **Output**        | `sessions/{SESSION_ID}/preflight-report.md` + `preflight-impact.json` (v3.0+)       |

**Workflow Position:** `/wf-implement-feature` → **`/wf-preflight ← YOU ARE HERE`** → `/wf-verify-sync` → `/wf-prepare-deployment` (có thể chạy bất kỳ lúc nào)

---

## Arguments

| Argument        | Mô tả                                                                                           | Default |
| --------------- | ------------------------------------------------------------------------------------------------- | ------- |
| `--scope`     | `all` / `system` / `module` / `feature`                                                   | `all` |
| `--name`      | ID của system/module/feature khi scope hẹp (`SYS-ERP`, `MOD-ERP-FIN`, `FEAT-ERP-FIN-001`) | —      |
| `--fix`       | Auto-fix các lỗi có thể sửa được (orphan code, registry format)                           | —      |
| `--run-tests` | Chạy unit tests + integration tests nếu được cấu hình                                      | —      |
| `--status`    | Xem tiến độ check hiện tại                                                                   | —      |
| `--resume`    | Resume từ checkpoint session trước                                                             | —      |

**Ví dụ:** `/wf-preflight` · `/wf-preflight --scope=system --name=SYS-ERP` · `/wf-preflight --fix --run-tests` · `/wf-preflight --status` · `/wf-preflight --resume`

---

## Protocols & Strategy

> **Protocol:** Xem `.claude/skills/protocols/`

| Protocol | Áp dụng |
|----------|---------|
| 1 Accuracy Assurance | POST-GATE mọi phase, Fix Rules, Error Tracking |
| 2 Auto-Correction Loop | Phase 5b max 3 iterations |
| 3 Context & Checkpoint | Thresholds 65/80/90% |
| 6 Token Limit | Scan-based (Read/Grep/Bash trực tiếp), chỉ spawn qa-lead Phase 5a.5 |
| 7 Parallel Execution | Group A: Phase 2+3 · Group B: Phase 4+5 |
| 10 POST-GATE | T1→T4 tiered Phase 7 |
| 19 Template Usage | READ→POPULATE→WRITE mọi output file |

### Execution Strategy

**Flow:** Phase 0 (session-init) → Phase 1 (setup) → **[Group A: Phase 2+3 PARALLEL]** → **[Group B: Phase 4+5 PARALLEL]** → Phase 5a (conditional) → Phase 5b → Phase 6 (conditional `--fix`) → Phase 6.5 (conditional) → Phase 7 (report)

> Protocol 7: Group A = registry+docs parallel. Group B = code+quality parallel. Group C (5a→7) sequential.

### Fix Rules (`--fix` only, Phase 6)

| Error Type | Auto-Fix | Escalate If |
|------------|---------|-------------|
| `registry_json_invalid` | Fix JSON syntax only (không đổi nội dung) | Structure corruption không parse được |
| `orphan_code_file` | Thêm REQ-ID comment | Không xác định được REQ-ID phù hợp |
| `id_format_error` | Chuẩn hóa → `REQ-[DEPT]-[NNN]` | ID ambiguous |
| `missing_doc`, `test_failure`, `type_error`, `duplicate_id`, `stale_impl_status` | LOG + escalate | Không auto-fix |

---

## Phase 0: Session Routing (v3.0+)

> **Toàn bộ Phase 0 delegate sang `procedures/session-init.md`** — bao gồm PRE-GATE forensic, migration check, `--status` display, `--resume` routing, session ID generation, duplicate CDG, lock acquisition, heartbeat start.

```
READ procedures/session-init.md → execute SI.1 → SI.9 → return
```

Sau khi session-init.md hoàn thành, `$SESSION_ID`, `$SESSION_DIR`, `$SCOPE_TYPE`, `$SCOPE_NAME`, `$HAS_FIX_FLAG`, `$HAS_RUN_TESTS_FLAG` được export cho tất cả phases tiếp theo.

---

## Phase 1-7: Routing Map

> **Internal shared:** Xem `procedures/_shared.md` — State Variables Glossary, Scope Resolution, Scoring Formulas, Checkpoint Protocol, Error Handling Matrix, Fix Rules.

| Phase | File                                       | Chạy khi                                       | Mục đích                                                   |
| ----- | ------------------------------------------ | ---------------------------------------------- | ----------------------------------------------------------- |
| **1**   | `procedures/phase1-setup.md`             | Always (entry point)                           | Setup + Scope Resolution + Tech stack detect + status init |
| **2**   | `procedures/phase2-registry.md`          | Always (PARALLEL Group A)                      | Registry Integrity Check                                    |
| **3**   | `procedures/phase3-docs.md`              | Always (PARALLEL Group A)                      | Document Completeness Check                                 |
| **4**   | `procedures/phase4-code-sync.md`         | `test -d src \|\| test -d apps` (PARALLEL Group B) | Code-REQ Sync Check                                         |
| **5**   | `procedures/phase5-quality.md`           | `test -d src \|\| test -d apps` (PARALLEL Group B) | Code Quality Check (tsc/eslint/go build)                    |
| **5a**  | `procedures/phase5a-tests.md`            | `$HAS_RUN_TESTS_FLAG = true`                   | Test Execution + Coverage                                   |
| **5b**  | `procedures/phase5b-crossval.md`         | Always                                         | Cross-Validation + Content Quality + Inter-Phase Consistency |
| **6**   | `procedures/phase6-autofix.md`           | `$HAS_FIX_FLAG = true`                         | Auto-fix + Re-score (Phase 6 + 6.5 gộp)                     |
| **7**   | `procedures/phase7-report.md`            | Always                                         | Generate Report + Status + History                          |

### Execution Flow

```
SKILL.md Phase 0 → session-init.md (SI.1-SI.9) → phase1-setup.md
  ↓
PARALLEL: phase2-registry.md + phase3-docs.md
  ↓
PARALLEL: phase4-code-sync.md + phase5-quality.md
  ↓
[phase5a-tests.md if --run-tests] → phase5b-crossval.md
  ↓
[phase6-autofix.md + phase6.5 if --fix] → phase7-report.md → STOP
```

> Phase files tham chiếu `procedures/_shared.md` cho cross-cutting: State Variables, Scope Resolution, Scoring, Checkpoint, Error Handling.

### Steps Summary

| Step | Action |
|------|--------|
| 0 | Session init — lock, migration detect, session dir tạo |
| 1-5b | Analysis — registry, docs, code sync, quality, cross-val |
| 6-7 | Fix (`--fix` only) + Report + artifacts + lock release |

**Registry Safe-Write:** NONE — skill chỉ READ `req-registry.json`, không ghi registry.

---

## Session Isolation (v3.0+)

Mỗi lần chạy tạo session riêng biệt (CORE-030):

| Item | Giá trị |
|------|---------|
| Session ID | `{YYYY-MM-DD}-{scope-slug}-{NN}` — ví dụ `2026-05-03-all-01` |
| Session dir | `.mc-data/work/wf-preflight/sessions/{SESSION_ID}/` |
| Lock | `.session.lock` (POSIX atomic mkdir, heartbeat 30s) |
| Registry lock | `.mc-data/work/wf-preflight/.locks/registry.lock` (Phase 6 --fix only) |
| Index | `.mc-data/work/wf-preflight/_index/sessions.jsonl` (append-only, 2 entries/session) |

**Session lifecycle:** `session-init.md` (SI.1-SI.9) → run phases → `phase7-report.md` (7.G kill heartbeat, 7.H release lock)

**Multi-run same scope today:** CDG hiển thị trước khi tạo session mới (SI.6). Bypass: `MCV3_PREFLIGHT_DUPLICATE_OK=1`.

---

## Script Delegation (v3.0+)

10 bash scripts trong `.claude/scripts/wf-preflight/` — giảm ~78% token overhead:

| Script | Chức năng |
|--------|-----------|
| `pf-common.sh` | Shared helpers: paths, sha_hash, get_timestamp, warn |
| `pf-generate-session-id.sh` | Tạo session ID `{YYYY-MM-DD}-{scope}-{NN}` |
| `pf-acquire-lock.sh` | POSIX atomic mkdir lock, stale/dead-PID detection |
| `pf-release-lock.sh` | Release lock + cleanup acquiring guard |
| `pf-heartbeat.sh` | Background daemon cập nhật heartbeat_at mỗi 30s |
| `pf-index-append.sh` | Atomic append entry vào sessions.jsonl |
| `pf-validate-registry.sh` | Protocol 10.4 forensic registry check (T1+content) |
| `pf-postgate-check.sh` | T1→T3 POST-GATE cho MD/JSON outputs |
| `pf-impact-build.sh` | Build `preflight-impact.json` (schema preflight-impact-v1) |
| `pf-migrate-flat-to-sessions.sh` | Auto-archive v2 flat files → `sessions/_legacy-v2/` |

---

## Output Files

| # | File                  | Đường dẫn                                                       | Phase      |
| - | --------------------- | ------------------------------------------------------------------ | ---------- |
| 1 | Preflight report      | `sessions/{SESSION_ID}/preflight-report.md`                      | 7          |
| 2 | Session status        | `sessions/{SESSION_ID}/preflight-status.json`                    | 1/7        |
| 3 | Impact artifact       | `sessions/{SESSION_ID}/preflight-impact.json` (cross-skill v3.0) | 7          |
| 4 | Phase summary         | `sessions/{SESSION_ID}/phase-summary.md`                         | 7          |
| 5 | Checkpoint            | `sessions/{SESSION_ID}/checkpoint.json`                          | 3/5b/6     |
| 6 | History log (flat)    | `preflight-history.md` (append-only, persistent)                 | 7 (append) |
| 7 | Sessions index        | `_index/sessions.jsonl` (2 entries/session)                      | 0/7        |

> Tất cả paths trên có prefix `.mc-data/work/wf-preflight/`. History log giữ flat path — backward compat.

**Next:** PASS → `/wf-verify-sync` · FAIL → `/wf-fix-bugs` · WARN → `/wf-fix-bugs` hoặc tiếp tục tùy mức độ

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|------------|-------|
| E001/E002 | Registry không tồn tại hoặc JSON invalid | STOP → chạy `/wf-brainstorm` / fix syntax |
| E003/E004 | `--scope` thiếu `--name` hoặc ID không tồn tại | STOP → hướng dẫn valid IDs |
| E005 | Code tool không tồn tại | Skip Phase 5, `quality_score = null`, NULL redistribution |
| E006/E013 | Tests timeout (>5min) hoặc no readable output | FORCE STOP + log WARNING |
| E007/E012 | File read errors / registry rỗng | WARN, tiếp tục degraded |
| E008 | Context > 90% | FORCE checkpoint → `--resume` |
| E009 | POST-GATE fail sau 3 retries | STOP phase, escalate |
| E010 | `--fix` gây lỗi mới | Rollback từ `file_snapshots`, log "Fix regression", escalate |
| E011/E014 | Không chạy từ project root / `jq` chưa cài | STOP → hướng dẫn cài |

---

## Related Skills

| Skill                      | Quan hệ                                                             |
| -------------------------- | -------------------------------------------------------------------- |
| `/wf-implement-feature`  | Prerequisite — chạy sau khi code implement                         |
| `/wf-fix-bugs`           | **Next step** — chạy để tự động fix issues tìm được |
| `/wf-verify-sync`        | Detailed REQ-ID sync (chạy sau `/wf-preflight` PASS)              |
| `/wf-prepare-deployment` | Next step nếu PASS                                                  |
| `/audit-devkit`          | DEVKIT structure audit — khác: audit DEVKIT, không phải project  |
| `/status`                | Quick progress overview — không validate                           |

---

## Context & Checkpoint

| Context | Hành động |
|---------|-----------|
| < 65% | Tiếp tục bình thường |
| 65-80% | Chuẩn bị checkpoint |
| 80-90% | Lưu `$SESSION_DIR/checkpoint.json` ngay |
| > 90% | FORCE STOP — checkpoint bắt buộc, dùng `--resume` |

**Resume:** `/wf-preflight --resume` → session-init.md RR.2-RR.5 auto-discover session in_progress mới nhất → tiếp tục từ `RESUME_FROM` trong checkpoint.

### CORE Compliance Notes

| CORE ID | Compliance | Ghi chú |
|---------|-----------|---------|
| CORE-026 | Đáp ứng | Execution trace: START (Phase 1 step 1.8), COMPLETE (Phase 7 step 7.9) → `_trace/session-log.json` |
| CORE-027 | Đáp ứng | CDG 3 points trong phase6-autofix.md: pre-fix confirm, per-fix verify, post-fix summary |
| CORE-028 | Đáp ứng | Phase summary (Phase 7 step 7.8) → `$SESSION_DIR/phase-summary.md` |
| CORE-030 | Đáp ứng | Session isolation: `sessions/{SESSION_ID}/` per run, POSIX lock, heartbeat, JSONL index |
| CORE-031 | Đáp ứng | 7 output files từ templates: report, status, impact, history, checkpoint, phase-summary, sessions.jsonl |

---

## Examples

```
# Full check + auto-fix
/wf-preflight --fix
→ Session 2026-05-03-all-01 created. Registry 100%, docs 80%, sync 75% (5 orphan files).
→ CDG: --fix 5 items. Confirm? yes → thêm REQ-ID vào 5 files.
→ Verdict: WARN (80%) — 2 REQs chưa implement. Chạy /wf-fix-bugs.

# Module check với tests
/wf-preflight --scope=module --name=MOD-ERP-FIN --run-tests
→ Session 2026-05-03-mod-erp-fin-01. Code sync 100%, 47 tests PASS.
→ Verdict: PASS (95%) ✅ → /wf-verify-sync
```

