---
name: wf-test-business-workflow
version: 1.1.0
last_updated: 2026-09-13
description: |
  Test E2E + auto-fix + sinh business/technical narration cho mỗi business workflow spec
  trong .mc-data/docs/phase1-business/workflows/ (WF-L1 → WF-L6).
  Pipeline 3-phase: ANALYZE (parse spec) → TEST (Playwright MCP + auto-fix) → NARRATE (dual-agent).
  Output: .mc-data/docs/phase1-business/workflows/_presentations/{WF-id}.presentation.md.

  TRIGGER khi:
  - User muốn validate 1 hoặc nhiều WF-L*-NN-*.md chạy đúng end-to-end trong erp-web/backend
  - User cần sinh presentation gửi BA/PM cho mỗi business workflow
  - User muốn resume session test đang dở

  KHÔNG trigger khi:
  - Test 1 module code (dùng /wf-test-flow)
  - Sinh WF spec mới (dùng /wf-analyze-requirements)
  - Fix 1 bug cụ thể (dùng /wf-fix-bugs)

argument-hint: "[--workflow=WF-L1-01|--all|--level=L1|--set=WF-L1-10,WF-L1-11,WF-L2-03] [--resume] [--status] [--setup-machine] [--stop] [--no-spawn] [--phase=analyze|test|narrate] [--dry-run]"
disable-model-invocation: true
allowed-tools: >
  Read, Glob, Grep, Bash, Write, Edit, TodoWrite, Agent,
  mcp__gitnexus__query, mcp__gitnexus__context, mcp__gitnexus__impact
---
# wf-test-business-workflow

> Test E2E + auto-fix + dual-narrative presentation cho business workflow specs (WF-L1 → WF-L6).
> Pipeline: PRE-GATE → ANALYZE → TEST → NARRATE → SPAWN NEXT.
> Session-based, resumable, autonomous loop với kill-switch.

---

> **ĐỌC TRƯỚC KHI CHẠY**
>
> Skill này chạy theo mô hình **1 session = 1 WF**. Mỗi WF hoàn thành, skill **BẮT BUỘC**
> tự động spawn Claude Code tab mới cho WF tiếp theo thông qua
> `python -X utf8 scripts/next-session.py` (Step 4.6). Script copy prompt
> `/wf-test-business-workflow --resume` vào clipboard, kích hoạt editor, mở tab mới và paste —
> không cần thao tác thủ công.
>
> **KHÔNG được tự tiếp tục WF tiếp theo trong cùng session** (context blow-up).
> Ngoại lệ duy nhất: script trả Exit 1 → FALLBACK MODE in-session (có log rõ ràng).

---

### Workflow Position

```
/wf-analyze-requirements → [WF-L*.md specs] → /wf-test-business-workflow → _presentations/
                                                          |
                                                   YOU ARE HERE
```

> Prerequisite: ≥1 WF-L*.md trong `.mc-data/docs/phase1-business/workflows/`
> Next: Review presentations tại `.mc-data/docs/phase1-business/workflows/_presentations/`

---

## Protocols & Strategy

### Priority Ladder (BẮT BUỘC)

1. **Độ chính xác, chất lượng kỹ thuật, bảo mật**
2. **Tốc độ và song song hóa** — chỉ sau khi mục 1 được bảo vệ

### Execution Strategy

| Condition                              | Mode                                                               |
| -------------------------------------- | ------------------------------------------------------------------ |
| Phase 3 Narrate — 2 agents độc lập | **PARALLEL** — spawn developer + domain-expert đồng thời |
| Phase 0→1→2→3→4                    | **SEQUENTIAL** — output phase trước là input phase sau   |

### Fix Rules (BẮT BUỘC — fix đến sạch, không giới hạn số lần)

> **Nguyên tắc:** Thấy lỗi → phân loại → fix ngay → chạy lại test → lặp đến khi pass hết.
> Không có "max attempts". Không có "blast radius > 10 → blocked".
> CHỈ escalate khi fix đòi hỏi quyết định ngoài kỹ thuật (xem cột Escalate).

| Error Type           | Auto-Fix Strategy                                        | Escalate If (và chỉ khi)                               |
| -------------------- | -------------------------------------------------------- | -------------------------------------------------------- |
| `TEST_BRITTLE`     | Adjust selector / add wait_for trong .spec.ts            | Không bao giờ — luôn fix được                     |
| `DATA_STATE`       | Seed data qua API trong beforeEach/beforeAll             | API seed trả 5xx và không có endpoint seed           |
| `AUTH_EXPIRED`     | Re-login + lưu storageState                             | Login fail do tài khoản bị khoá (cần Admin)         |
| `FRONTEND_BUG`     | Serena edit apps/erp-web/src/ → re-run                  | Cần business owner quyết định UX/behavior            |
| `BACKEND_BUG`      | Serena edit apps/backend/ → đợi rebuild 90s → re-run | Cần EF migration mới / cần thay đổi DB schema       |
| `MISSING_ENDPOINT` | Implement endpoint + handler đơn giản → re-run       | Cần domain design phức tạp (cross-module transaction) |
| `RENDER_TIMING`    | Thêm wait_for + retry trong .spec.ts                    | Không bao giờ — luôn fix được                     |
| `BUILD_ERROR`      | Fix TypeScript/compile error → re-run typecheck         | Cần thay đổi interface đã published                 |

### Template Usage (CORE-031)

Mọi output file: **READ template → POPULATE → WRITE**. Templates tại `templates/`:
`checkpoint.json`, `prompt-template.md`, `wf.spec.ts.template`, `workflow-analysis.template.md`,
`presentation.template.md`, `final-report.template.md`.

### Machine Config

Config máy (FE URL, backend health URL, rebuild wait, editor app, test accounts path) do
**first-run wizard** ghi vào auto-memory của project + mirror tại
`.mc-data/work/wf-test-business-workflow/_runs/.machine-mirror.json` (scripts đọc mirror).
Chi tiết: `procedures/first-run-wizard.md`. Chưa có config → E008 trigger wizard.

---

## Cách Dùng

```bash
# Chạy 1 WF cụ thể (không spawn next)
/wf-test-business-workflow --workflow=WF-L1-01 --no-spawn

# Autonomous loop toàn bộ WF
/wf-test-business-workflow --all

# Chạy danh sách WF tùy chọn (comma-separated)
/wf-test-business-workflow --set=WF-L1-10,WF-L1-11,WF-L2-03

# Chỉ 1 level
/wf-test-business-workflow --level=L1

# Xem dashboard tiến độ
/wf-test-business-workflow --status

# Resume session đang dở
/wf-test-business-workflow --resume

# Dừng loop sau WF hiện tại
/wf-test-business-workflow --stop

# Setup lại machine config
/wf-test-business-workflow --setup-machine

# Dry-run: chỉ Phase 1 (analyze), không test/narrate/spawn
/wf-test-business-workflow --workflow=WF-L1-01 --dry-run
```

---

## Phase 0: PRE-GATE

> Procedure: `procedures/session-dir.md` + `procedures/resume-routing.md` + `procedures/first-run-wizard.md`

**PRE-GATE:** `test -d .mc-data/docs/phase1-business/workflows/ && ls WF-L*.md 2>/dev/null | wc -l | grep -v ^0`

| Step | Action                                                   | Tool  | Verify                 |
| ---- | -------------------------------------------------------- | ----- | ---------------------- |
| 0.0  | Kill-switch check — đọc _runs/STOP                    | Read  | File tồn tại → exit |
| 0.1  | Flag dispatch (--status/--resume/--stop/--setup-machine) | -     | Route đúng           |
| 0.2  | Load machine config từ auto-memory                      | Read  | Config loaded          |
| 0.3  | Validate prerequisites (WF files + FE/BE running)        | Bash  | 200 OK từ localhost   |
| 0.4  | Build/refresh progress.json (scripts/build-progress.py)  | Bash  | File tồn tại         |
| 0.5  | Claim WF (atomic write inprogress)                       | Write | status=inprogress      |
| 0.6  | Init session directory + copy templates                  | Write | SESSION_DIR created    |

**POST-GATE:** `test -f _runs/progress.json && SESSION_DIR exists && WF status=inprogress`

Chi tiết từng step (kill-switch, flag dispatch, claim logic, session dir layout):
`procedures/session-dir.md`. Dashboard `--status` + routing `--resume`: `procedures/resume-routing.md`.

---

## Phase 1: ANALYZE

> **Procedure chi tiết:** `procedures/phase1-analyze.md`

**PRE-GATE:** `test -f $SESSION_DIR/test-status.json && WF analysis_status=pending`

| Step | Action                                      | Tool  | Verify               |
| ---- | ------------------------------------------- | ----- | -------------------- |
| 1.1  | Locate + read WF-L*.md spec + parse-workflow-spec.py | Read/Bash | JSON output OK |
| 1.2  | Resolve test accounts từ §3 Actors        | Read  | accounts mapped      |
| 1.3  | Naming gap check vs naming-alignment-matrix | Read  | MAJOR gaps flagged   |
| 1.4  | Sinh workflow-analysis.md từ template      | Write | File > 100 bytes     |
| 1.5  | Update test-status.json                     | Write | analysis_status=done |

**POST-GATE:** `test -f $SESSION_DIR/workflows/{WF-id}-analysis.md && analysis_status=done`

---

## Phase 2: TEST — WRITE → RUN/FIX → MCP VERIFY

> **Procedure chi tiết:** `procedures/phase2-test.md`
> **Triết lý:** Viết test script trước (ground truth), chạy và fix code đến sạch, cuối cùng
> dùng Playwright MCP như manual user để lấy evidence. Spec file = regression suite tái sử dụng.

**PRE-GATE:** `analysis_status=done && BE/FE running`

| Step | Action                                                               | Tool             | Verify                      |
| ---- | -------------------------------------------------------------------- | ---------------- | --------------------------- |
| 2.1  | Đọc analysis + sinh `{WF-id}.spec.ts` (templates/wf.spec.ts.template) | Write            | File tồn tại tại e2e/wf/ |
| 2.2  | Run `pnpm e2e --grep {WF-id}` lần đầu                           | Bash             | Output có kết quả        |
| 2.3  | Fix loop: phân loại lỗi → fix code → re-run → lặp đến sạch | Edit/Serena/Bash | Exit 0 từ pnpm e2e         |
| 2.4  | MCP Verify: login manual + happy path + deep verify + screenshots    | MCP tools        | ≥1 .png evidence           |
| 2.5  | Record results (tc_results object format bắt buộc)                   | Write            | test-status.json updated    |

**POST-GATE:** `pnpm e2e exit 0 && screenshots ≥1 && spec file tồn tại`

---

## Phase 3: NARRATE (chỉ khi Phase 2 PASS)

> **Procedure chi tiết:** `procedures/phase3-narrate.md`

**PRE-GATE:** `test_status=pass`

| Step | Action                                            | Tool  | Verify                |
| ---- | ------------------------------------------------- | ----- | --------------------- |
| 3.1  | Map domain expert agent theo WF level             | -     | Agent name resolved   |
| 3.2  | Spawn developer + domain-expert agents (PARALLEL) | Agent | Both return output    |
| 3.3  | Compose presentation.md từ template (5 sections) | Write | File > 500 bytes      |
| 3.4  | Update _presentations/README.md index             | Edit  | Row added             |
| 3.5  | Update test-status.json                           | Write | narration_status=done |

**POST-GATE:** `presentation.md exists && size > 500 bytes && README.md updated`

Domain expert mapping theo level (L1→sales/customer … L6→finance/customer/logistics):
`procedures/phase3-narrate.md §Step 3.1`.

---

## Phase 4: SPAWN NEXT SESSION

> **Procedure chi tiết:** `procedures/phase4-spawn-next.md`

**PRE-GATE:** `status=done|blocked (not inprogress)`

| Step | Action                                          | Tool      | Verify                    |
| ---- | ----------------------------------------------- | --------- | ------------------------- |
| 4.0  | Phase Completeness Audit (BẮT BUỘC)            | Read      | steps_skipped documented  |
| 4.1  | Pre-exit verification (artifacts check)         | Read/Bash | All artifacts present     |
| 4.2  | Ghi checkpoint JSON + atomic update progress.json | Write   | Files exist, status đúng  |
| 4.3  | Digest mỗi 10 WF done                          | Write     | Optional                  |
| 4.4  | Re-check STOP kill-switch                       | Read      | Exit nếu STOP            |
| 4.5  | Regenerate _runs/prompt-template.md             | Write     | File updated              |
| 4.6  | Invoke next-session.py (nếu không --no-spawn) | Bash      | Exit 0=spawn / 1=fallback |
| 4.7  | --set mode: loop back to Step 0.5             | -         | Next WF in set claimed    |

**POST-GATE:** `checkpoint exists && progress.json status correct && (spawned OR --no-spawn)`

Completeness checklist (14 steps P1-P3), pre-exit artifact list, prompt-template regen logic,
spawn/fallback semantics: `procedures/phase4-spawn-next.md`.

---

## Session & Run Directory

```
.mc-data/work/wf-test-business-workflow/
├── _runs/
│   ├── progress.json            # SSOT tiến độ toàn bộ WF (build-progress.py sinh)
│   ├── STOP                     # kill-switch (--stop tạo; xóa để chạy lại)
│   ├── .machine-mirror.json     # mirror machine config cho scripts
│   ├── prompt-template.md       # prompt cho tab kế tiếp (Step 4.5 regen)
│   ├── checkpoints/{WF-id}.json # checkpoint per WF
│   ├── digest-{ts}.md           # mỗi 10 WF done
│   ├── FINAL-REPORT.md          # khi hết pending
│   └── next-session.log         # spawn script log
└── sessions/{YYYY-MM-DD-{WF-id}-{NN}}/
    ├── test-status.json         # SSOT session (next_action cho --resume)
    ├── workflows/{WF-id}-analysis.md (+ -analysis-raw.json)
    ├── bugs/BUG-{NNN}.json
    ├── shared/fix-log.json + e2e-run-log.txt
    └── playwright/evidence/{WF-id}/*.png
```

---

## Error Handling

| Code | Mô tả                                    | Xử lý                                     |
| ---- | ------------------------------------------ | ------------------------------------------- |
| E001 | WF-L*.md không tồn tại                  | Hướng dẫn chạy /wf-analyze-requirements |
| E002 | Context > 70%                              | Ghi checkpoint + hướng dẫn --resume      |
| E003 | Playwright MCP không khả dụng           | Hướng dẫn manual test guide              |
| E004 | Backend không chạy                       | docker compose / dotnet run                 |
| E005 | Naming gap MAJOR — endpoint không match  | Escalate, hỏi user                         |
| E006 | Bug fix thất bại 3 lần                  | Escalate, mark blocked                      |
| E007 | Domain expert agent không phù hợp level | Fallback developer-only narration           |
| E008 | Machine config chưa setup                 | Trigger first-run wizard                    |
| E009 | Spawn script fail                          | FALLBACK MODE in-session                    |
| E010 | STOP file detected                         | Mark inprogress→pending, exit              |
| E011 | Pre-exit verification fail                 | Fix artifact trước khi spawn              |

---

## Related Skills

| Skill                        | Relationship                                    | Notes                                             |
| ---------------------------- | ----------------------------------------------- | ------------------------------------------------- |
| `/wf-analyze-requirements` | Upstream — sinh WF-L*.md specs                 | Prerequisite                                      |
| `/wf-test-flow`            | Sibling — test module-level features           | Dùng cho code flow, không dùng cho business WF |
| `/wf-fix-bugs`             | Companion — fix bugs khi blast radius quá cao | Invoke khi E006 escalate                          |
| `/wf-define-features`      | Upstream upstream — định nghĩa features     | Context                                           |
| `/status`                  | Standalone — xem tiến độ dự án tổng thể | Bổ sung cho --status flag                        |
