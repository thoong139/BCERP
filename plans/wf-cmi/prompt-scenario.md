# Session Re-Entry Prompt — wf-cmi v3.0 E2E Scenario Engine

> **Mục đích:** Prompt khởi động cho session Claude Code mới để triển khai **mở rộng wf-cmi từ v2.0.0 (26 lanes Gói C++ Logistics) → v3.0.0 (26 lanes + Phase 9-10 E2E Scenario Engine)**. Đọc file này NGAY khi bắt đầu session.
>
> **Khác với các prompt khác:**
> - `session-prompt.md` — v1.0 implementation (DONE)
> - `prompt-update.md` — v2.0 expansion Gói C++ Logistics (DONE)
> - **`prompt-scenario.md` (file này)** — v3.0 E2E Scenario Engine (NEW)

---

## Khởi động session mới — Copy paste prompt sau

```
Tôi đang triển khai mở rộng skill `wf-cmi` từ v2.0.0 → v3.0.0 (E2E Scenario Engine).
v2.0.0 đã ship với 26 active lanes Gói C++ Logistics + 9 SKIPPED + 5 skeleton v3-deferred.
v3.0.0 KHÔNG đụng vào 26 lanes hiện tại — chỉ ADD:
  - 1 lane mới CD41 "E2E Scenario Synthesizer" ở Wave 3
  - Phase 9 mới "E2E Execute & Verify" (opt-in qua --exec-scenarios)
  - Phase 10 mới "E2E Resolution" (auto-run nếu Phase 9 có FAIL)
  - Schema bump integrity-impact v2 → v3 (backward-compat read v1+v2+v3)

Đọc các tài liệu sau theo thứ tự trước khi bắt đầu code:

1. plans/wf-cmi/prompt-scenario.md (file này — context v3.0)
2. plans/wf-cmi/progress-scenario.md (tracking 10 stages)
3. plans/wf-cmi/v3.0-e2e-integration-plan.md (spec đầy đủ kiến trúc)
4. plans/wf-cmi/prompt-update.md (v2.0 context — đã DONE, đọc reference)
5. plans/wf-cmi/progress-update.md (v2.0 progress — đã DONE, đọc reference)
6. .claude/skills/workflow/wf-cmi/SKILL.md (current v2.0 state)
7. .claude/skills/workflow/wf-cmi/_contract.json (current v2.0 contract)
8. .claude/skills/workflow/wf-e2e-scenario/SKILL.md (SOURCE để port engine)
9. .claude/skills/workflow/wf-e2e-scenario/procedures/scenario-runner.md (SOURCE engine)
10. .claude/skills/workflow/wf-e2e-scenario/procedures/failure-analyzer.md (SOURCE failure analyzer)
11. .claude/skills/workflow/wf-e2e-scenario/procedures/screenshot-evidence.md (SOURCE evidence)
12. .claude/skills/workflow/wf-e2e-scenario/templates/test-scenario.template.md (SOURCE template)

Quy tắc bắt buộc (BHV-001 đến BHV-004 + CORE-001 đến CORE-038):
- KHÔNG break v2.0 backward compat — mọi thay đổi là ADD-ONLY
- SKILL.md vẫn ≤500 dòng (CORE-032 lazy-load) — Phase 9-10 routing 1 dòng/phase, logic ở procedure files
- Mọi template mới CHỈ tạo qua template pattern (CORE-031): READ → POPULATE → WRITE
- Cross-skill artifact integrity-impact.json bump schema v2 → v3 (consumer phải read được v1+v2+v3)
- Mọi agent prompt PHẢI có 8 sections (CORE-037)
- KHÔNG bao giờ tự chạy Playwright theo mặc định — phải có cờ --exec-scenarios
- Phase 9 auto-trigger khi --exec-scenarios + profile=deep|exhaustive
- Phase 9 prompt user (AskUserQuestion) khi --exec-scenarios + profile=quick|standard
- Phase 9 PRE-GATE check Playwright MCP, không có → SKIP Phase 9-10 với E150 WARN
- Phase 10 default chỉ browser-fix, source-fix cần --auto-fix-source + CDG E195 confirm
- KHÔNG xóa wf-e2e-scenario cho đến Stage 10 (port đủ engine và migrate xong)

Bước tiếp theo: xem progress-scenario.md mục "Next Step" — bắt đầu Stage 1 Foundation Refactor.
```

---

## Tóm tắt Quyết Định Scope (đã chốt với user 2026-05-16)

### Scope: Full integration

| # | Câu hỏi | Quyết định | Implication |
|---|---------|-----------|-------------|
| 1 | Phạm vi tích hợp | **Full** — toàn bộ 9 capability của wf-e2e-scenario | CD41 synth + Phase 9 execute + Phase 10 resolution loop-back. KHÔNG cắt bớt. |
| 2 | Mặc định execute Playwright? | **KHÔNG** — chỉ chạy khi có cờ `--exec-scenarios` | An toàn cho user v2.0. Quick/standard không bị tăng thời gian. |
| 3 | Trigger auto-run | **`--exec-scenarios` + profile=deep\|exhaustive → auto chạy hết**. profile=quick\|standard → execute subset + AskUserQuestion confirm. | Smart default: deep verify đầy đủ, quick hỏi user. |
| 4 | Browser unavailable | **SKIP Phase 9-10 với E150 WARN**, vẫn xuất integrity-report | Graceful degradation (CORE-033). |
| 5 | wf-e2e-scenario lifecycle | DEPRECATE sau v3.0 stable 2 sprint. wf-e2e-credentials GIỮ standalone | Migration plan Stage 10. |

### Đã thống nhất port

```
9 CAPABILITY TỪ wf-e2e-scenario:
├── 1. test-scenario.template.md       → wf-cmi/templates/test-scenario.template.md
├── 2. scenario-runner.md (Engine)     → wf-cmi/procedures/_e2e-runner.md
├── 3. Step pattern recognition        → _e2e-runner.md §Step Execution
├── 4. Expected result verification    → _e2e-runner.md §Expected Result
├── 5. screenshot-evidence.md          → wf-cmi/procedures/_screenshot-evidence.md
├── 6. failure-analyzer.md (Engine)    → wf-cmi/procedures/_failure-analyzer.md
├── 7. Quality gates (G1.1-G1.5)       → phase9-e2e-execute.md + scripts/wf-cmi-e2e/
├── 8. Cross-module scenarios          → _e2e-runner.md §Cross-Module
└── 9. Browser-mcp.lock                → _shared.md §Browser Lock Pattern (UPDATE)
```

### Đã thống nhất KHÔNG port

| wf-e2e-* skill | Hành động |
|----------------|-----------|
| wf-e2e-credentials | **GIỮ standalone** — credential vault không thuộc CMI scope |
| wf-e2e-browser (F2) | **Decide Stage 10** — pre-scan browser test, review case-by-case |
| wf-e2e-demo (F8) | **Decide Stage 10** — user guide generation, không thuộc CMI |
| 10 skill còn lại | **DEPRECATE** Stage 10 |

---

## Checklist context window tối thiểu

Trước khi viết code, đảm bảo đã load:

- [x] `plans/wf-cmi/v3.0-e2e-integration-plan.md` (spec đầy đủ)
- [x] `plans/wf-cmi/progress-scenario.md` (mục Next Step + Stage hiện tại)
- [x] `.claude/skills/workflow/wf-cmi/SKILL.md` (current state)
- [x] `.claude/skills/workflow/wf-cmi/_contract.json` (current contract)
- [x] Stage hiện tại files cần đọc (xem progress-scenario.md per stage)
- [x] Source wf-e2e-scenario file tương ứng (nếu Stage 2/4/5 cần port)
- [x] CLAUDE.md (project rules), `.claude/rules/00-core.md` (CORE-032 → CORE-038)

---

## Critical Decision Gates (CDG) đã đặt sẵn

Trong quá trình triển khai, các CDG sau sẽ trigger AskUserQuestion:

| CDG ID | Khi nào trigger | Options |
|--------|-----------------|---------|
| E195 (Phase 10) | User chạy `--auto-fix-source` lần đầu trong session | Confirm/Reject/Skip-this-time |
| Subset execute (Phase 9) | `--exec-scenarios` + profile=quick\|standard | Execute all/Execute MUST-only/Cancel |
| Quarantine override | Scenario flaky 3 lần liên tiếp | Quarantine permanent/Retry x1 more/Skip |
| Schema migration v2→v3 (Stage 6) | Sau khi update integrity-impact template | Confirm bump version |
| Wave 3 thêm CD41 (Stage 1) | Khi update _contract.json profile_activation | Confirm 26 → 27 lanes deep |
| DEPRECATE wf-e2e-* (Stage 10) | Sau khi v3.0 ship 2 sprint stable | Confirm DEPRECATE timing |

---

## Common Pitfalls để tránh

1. **KHÔNG dùng Phase 9-10 logic inline trong SKILL.md** — vi phạm CORE-032. Phải lazy-load qua procedure files.
2. **KHÔNG hardcode Playwright tool names trong SKILL.md** — declare trong _contract.json `allowed-tools` + reference từ procedure.
3. **KHÔNG sửa Phase 1-7 logic v2.0** — vi phạm BHV-003. v3.0 là ADD-ONLY. Phase 8 chỉ UPDATE thêm section, KHÔNG đổi logic core.
4. **KHÔNG xóa wf-e2e-scenario template/procedure trước Stage 10** — Stage 1-9 cần làm reference để port.
5. **KHÔNG quên backward-compat schema** — integrity-impact v3 PHẢI có `schema_version_compat.readable_by = ["v1","v2","v3"]` + ALL v2 fields preserved + NEW v3 fields = null/[] nếu `--exec-scenarios` không bật.
6. **KHÔNG silent overwrite** — kiểm tra `.mc-data/work/wf-cmi/sessions/{ID}/` trước khi write. Áp dụng Atomic Write Pattern.
7. **KHÔNG spawn agent trong Phase 9** — Phase 9 chỉ Playwright orchestration. Spawn agent là Phase 10 §Step 10.2 Bước 7 Phase B.
8. **KHÔNG quên --no-prompt flag** — CI mode cần bypass AskUserQuestion. Test cả 2 path.
9. **KHÔNG quên loop-back guard** — Phase 10 APPEND gap-suggestions CHỈ với kind="e2e_scenario_fix" (mới), KHÔNG re-trigger CD41 → tránh infinite loop.
10. **KHÔNG dùng v2 paths sau v3** — session subdirectory phải là `phase9-e2e-execute/` và `phase10-e2e-resolution/`, không hợp nhất vào phase8 dù về mặt logic gần.

---

## Khi gặp vấn đề trong quá trình triển khai

### Stage 1-3 (Foundation + CD41 + Templates)
- Compliance audit FAIL → check SKILL.md ≤500 dòng, _contract.json JSON valid
- Schema sync FAIL → re-run `.claude/scripts/validate-schema-sync.sh wf-cmi`
- Template missing → reference từ wf-e2e-scenario/templates/, copy + customize CMI metadata

### Stage 4 (Phase 9 Execute Engine)
- Playwright MCP test fail → verify MCP server running, check tool names trong allowed-tools
- Lint script fail → check `.claude/scripts/wf-e2e-verify/lint-scenario.sh` reference
- 5x flakiness check timeout → tăng timeout, kiểm tra FE warm-up

### Stage 5 (Phase 10 Resolution Engine)
- Spawn agent fail → verify agent name exists trong `.claude/agents/`, check subagent_type chính xác
- Auto-fix source fail → verify file write permissions, check Atomic Write Pattern
- Loop-back gap-suggestions invalid schema → re-validate gap-suggestions-v1, nếu schema bump → coordinate Phase 7

### Stage 6 (Phase 8 Report v3)
- Schema validation fail v3 → ensure readable_by chứa v1+v2+v3, ALL v2 fields preserved
- Backward-compat fail → test v1/v2 consumer mock read v3 artifact OK

### Stage 7-8 (Arguments + Quality Gates)
- Smoke test 7 scenarios §7.2 fail → debug per scenario, check resume-status.md routing
- Eval TC-cmi-014→018 fail → check evals.json schema + test fixture paths

### Stage 9-10 (Ship Docs + Migration)
- CHANGELOG/CLAUDE.md inconsistency → cross-check version bump everywhere
- wf-e2e-* migration EUREKA real test fail → rollback DEPRECATE timing, document blocker

---

## Communication Style trong session

- **Tiếng Việt cho documentation + comments**
- **English cho code identifiers** (function names, variables)
- **Báo cáo per stage** theo template progress-scenario.md
- **CDG escalate qua AskUserQuestion** — đừng tự quyết định scope changes
- **Update progress-scenario.md** sau mỗi gate PASS/FAIL

---

## Khi resume session

Nếu session ngắt giữa chừng, đọc file này lại + `progress-scenario.md` mục "Stage hiện tại" + "Last gate status". Resume từ next pending step.

Tham khảo cả `procedures/resume-status.md` của wf-cmi v2 hiện tại để hiểu pattern resume.

---

## Liên hệ

- User: it@erktransport.com (EUREKA-2026 owner)
- Target dự án thực tế: EUREKA-2026 (ERP logistics Việt-Trung, 17 modules .NET 10 + Next.js 16)
- Skill version target: wf-cmi v3.0.0 ship target chưa chốt (flexible, quality > speed per CORE-023)

---

**END prompt-scenario.md**

> Sau khi đọc file này, đọc tiếp `progress-scenario.md` để biết Stage hiện tại + next step.
