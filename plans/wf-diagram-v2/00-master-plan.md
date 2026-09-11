# Master Plan — wf-diagram v2.0

**Ngày tạo:** 2026-05-03
**Phiên bản từ:** v1.2.0 (2026-04-30)
**Phiên bản đích:** v2.0.0
**Estimated effort:** ~12-15h, chia 6 sprints (~1-2 sessions/sprint)
**Trạng thái:** ⏳ PLANNING

---

## 1. Mục tiêu (theo thứ tự ưu tiên — CORE-023)

### Ưu tiên 1: Độ chính xác và tuân thủ chuẩn

- Skill phải tuân thủ ĐẦY ĐỦ chuẩn cấu trúc của các skill đã overhaul (wf-scan-target v2.0, wf-add-scope v3.0, wf-verify-sync v3.0)
- Lazy-load procedures (`SKILL.md` ≤ 250 dòng + 10 phase files ≤ 250 dòng/file)
- POST-GATE T1-T4 (Protocol 10) cho mọi diagram output
- Mermaid 8.8.0 Safety Rules được enforce qua bash validator
- Idempotent: re-run cùng input → output tương đương (trừ timestamp)
- Không bịa entity/endpoint không có trong source — `// TODO: cần xác nhận`

### Ưu tiên 2: Tốc độ và song song hóa

- Lazy-load procedures (chỉ đọc phase đang chạy) — tiết kiệm ~75% context
- Phase 4-6 chạy diagrams PARALLEL (5 / N+2 / N file độc lập)
- Bash scripts thay AI inference cho enumeration tasks (Phase 2 source scan)
- Reuse session khi `--resume` (không scan lại source)

### Ưu tiên 3: Tiết kiệm token

- Delegate Phase 2 source analysis cho bash (~80% token saving)
- SKILL.md ≤ 250 dòng, mỗi phase file ≤ 250 dòng
- `analysis.json` được build bởi bash, AI chỉ POPULATE templates

---

## 2. Scope

### Trong scope

| Khu vực | Ảnh hưởng |
|---------|-----------|
| `.claude/skills/workflow/wf-diagram/SKILL.md` | Refactor → routing hub ≤ 250 dòng |
| `.claude/skills/workflow/wf-diagram/procedures/` | Tách `flow-new.md` thành 10 files (8 phase + `_shared.md` + `resume-status.md`) |
| `.claude/skills/workflow/wf-diagram/templates/` | Audit + patch 14 templates với Mermaid 8.8.0 safety |
| `.claude/skills/workflow/wf-diagram/evals/evals.json` | Update v1.2.0 schema + thêm ≥3 cases mới |
| `.claude/skills/workflow/wf-diagram/_contract.json` | Update `procedure_files[]` |
| `.claude/scripts/wf-diagram-*.sh` | Tạo MỚI 5 bash scripts |
| `.claude/rules/00-core.md` §4b | Đã có entry — kiểm tra paths khớp |
| `plans/wf-diagram-v2/` | Tạo + cập nhật progress |
| Memory: `project_wf-diagram-v2-improvement-plan.md` | Tạo + cập nhật progress |

### Ngoài scope (KHÔNG đụng vào)

- Các skills khác (`wf-design`, `wf-design-ux`, `wf-scan-target`, `wf-implement-feature`, `wf-verify-sync`)
  - wf-diagram là standalone — không cần cross-skill changes
- `req-registry.json` — wf-diagram vẫn `registry_scope.fields_owned: []` (NONE)
- Pipeline DEVKIT chính — wf-diagram vẫn standalone
- Multi-dev safety (lock + heartbeat + JSONL index) → DEFER v2.1
- Cache + delta + profiles → DEFER v2.1

---

## 3. Definition of Done — v2.0.0

| # | Tiêu chí | Sprint chịu trách nhiệm |
|---|---------|------------------------|
| 1 | SKILL.md ≤ 250 dòng (lazy-load routing) | Sprint 2 |
| 2 | 10 phase files trong `procedures/`, mỗi file ≤ 250 dòng | Sprint 2-3 |
| 3 | `procedures/_shared.md` chứa state vars, helpers, error matrix | Sprint 2 |
| 4 | `procedures/resume-status.md` dispatcher | Sprint 3 |
| 5 | 5 bash scripts trong `.claude/scripts/wf-diagram-*.sh` | Sprint 4 |
| 6 | `_contract.json.procedure_files[]` đầy đủ 11 entries | Sprint 2 (cuối) |
| 7 | 14 templates được audit + Mermaid 8.8.0 safety patches | Sprint 5 |
| 8 | Evals ≥ 8 cases, schema v1.2.0+ aligned | Sprint 5 |
| 9 | `bash .claude/scripts/skill-compliance-audit.sh wf-diagram` PASS | Sprint 6 |
| 10 | `bash .claude/scripts/validate-schema-sync.sh wf-diagram` PASS | Sprint 6 |
| 11 | Smoke test trên project thật (chọn module có ≥1 entity, endpoint, state machine) | Sprint 6 |
| 12 | Backward compat — v1.2.0 sessions có thể `--resume` được trong v2.0 (hoặc clear migration) | Sprint 3 |
| 13 | `analysis.json` schema documented + jq validate sau Phase 2 | Sprint 4 |
| 14 | Cross-skill output paths trong `00-core.md` §4b khớp paths v2.0 | Sprint 6 |
| 15 | `phase-summary.md` tiếng Việt cho non-specialist (Protocol 14, CORE-028) — đã có v1.2.0, giữ nguyên | Sprint 2 (verify) |

---

## 4. Roadmap (theo thứ tự dependency)

```
Sprint 1 (1h)   ──>  Sprint 2 (3h)  ──>  Sprint 3 (2h)  ──>  Sprint 4 (3h)
Decisions +          Split SKILL.md     resume-status      Bash scripts
gap analysis         + 8 phase files   + session-init     (5 scripts)
                     + _shared.md
                                                                │
                                                                ▼
                     Sprint 6 (1.5h)  <── Sprint 5 (2h)  <─────┘
                     Compliance audit    Templates audit
                     + smoke test        + evals expansion
```

### Lý do thứ tự này

1. **Sprint 1** — Decisions pending + gap analysis (đã làm trong session này, đợi user duyệt 3-4 quyết định)
2. **Sprint 2** trước vì split là blocker — không có phase files thì các sprint sau làm việc trên file rỗng
3. **Sprint 3** sau Sprint 2 vì resume routing dùng phase files đã tách
4. **Sprint 4** sau Sprint 3 vì bash scripts được gọi từ phase files đã tách
5. **Sprint 5** sau Sprint 4 vì evals test bash scripts + templates patches
6. **Sprint 6** cuối — verify toàn bộ qua compliance audit + smoke test

### Có thể làm song song

- Sprint 4 (bash scripts) và Sprint 5 (templates audit) → song song nếu chia owner
- Sprint 2 (split) và Sprint 5 (evals update) — KHÔNG song song vì evals reference phase files

---

## 5. Sprint summary

### Sprint 1 — Decisions + Gap Analysis (1h) ⏳ NOT_STARTED
- [x] Đọc + đối chiếu wf-diagram với chuẩn các skill đã overhaul
- [x] Tạo `00-master-plan.md`, `01-compliance-gaps.md`
- [ ] Tạo `02-architecture-design.md` (target structure chi tiết)
- [ ] Tạo `03-decisions-pending.md` (3-4 quyết định cần user duyệt)
- [ ] Lưu memory entry
- [ ] **GATE:** chờ user duyệt decisions

### Sprint 2 — Split monolith (3h) ⏸ NOT_STARTED
- [ ] Backup `procedures/flow-new.md` → `procedures/flow-legacy.md.bak`
- [ ] Tạo `procedures/_shared.md` — state vars, helpers, error matrix
- [ ] Tạo 8 phase files (phase0-7) — mỗi file ≤ 250 dòng
- [ ] Refactor `SKILL.md` thành routing hub ≤ 250 dòng (giữ overview, args, output files, phase routing map)
- [ ] Update `_contract.json.procedure_files[]` thành 11 entries
- [ ] Verify: tất cả phase files self-contained (PRE-GATE, INPUT, Steps, POST-GATE, Next Phase)

### Sprint 3 — Resume + session-init (2h) ⏸ NOT_STARTED
- [ ] Tạo `procedures/resume-status.md` — `--status` (table 5 sessions) / `--resume` (route to checkpoint.next_action.phase) / fingerprint validate
- [ ] Tạo `procedures/session-init.md` — bootstrap helpers (mkdir, init status, init checkpoint, append trace START)
- [ ] Update `phase0-setup.md` reference `session-init.md`
- [ ] Backward compat: v1.2.0 sessions trong `.mc-data/work/wf-diagram/sessions/` còn `--resume` được

### Sprint 4 — Bash scripts (3h) ⏸ NOT_STARTED
- [ ] `wf-diagram-common.sh` — atomic_write_json, json_escape, slugify, parse_args, ISO-8601 timestamp, ensure_dir, append_trace_event
- [ ] `wf-diagram-source-scan.sh` — Phase 2 scan: modules / entities / endpoints / actors / state_machines / processes / scenarios → `analysis.json` v1
- [ ] `wf-diagram-mermaid-validate.sh` — POST-GATE T2: grep ` ```mermaid ` blocks + 9 8.8.0 safety patterns
- [ ] `wf-diagram-dbml-validate.sh` — POST-GATE T2: grep `Project `, `Table `, `Ref:` + count column blocks
- [ ] `wf-diagram-resume-helper.sh` — list 5 latest sessions table cho `--status`
- [ ] Test mỗi script độc lập

### Sprint 5 — Templates + Evals (2h) ⏸ NOT_STARTED
- [ ] Audit 14 templates với Mermaid 8.8.0 + Protocol 14 + DBML safety checklist
- [ ] Patch placeholders thiếu quote / thiếu Note / thiếu safety wrapper
- [ ] Update 5 evals existing với schema v1.2.0+ (`usecases/{group}.md`, `modules/{module}/_system/`)
- [ ] Thêm ≥3 evals mới: resume case, large module (10+ entities), error case (`--source-path` không tồn tại)
- [ ] Verify evals.json schema valid

### Sprint 6 — Compliance + Smoke test (1.5h) ⏸ NOT_STARTED
- [ ] Chạy `bash .claude/scripts/skill-compliance-audit.sh wf-diagram` → fix bất kỳ FAIL
- [ ] Chạy `bash .claude/scripts/validate-schema-sync.sh wf-diagram` → fix bất kỳ FAIL
- [ ] Smoke test thật trên 1 project thật:
  - Chọn 1 module có ≥1 entity, ≥3 endpoint, ≥1 state machine ≥3 trạng thái
  - Run `/wf-diagram --module=X --scope=full` → verify 5 _system + class + erd + N usecase + ≥1 state diagram
  - Verify Mermaid render được trên https://mermaid.live
  - Verify DBML render được trên https://dbdiagram.io
- [ ] Update `00-core.md` §4b nếu paths khác v1.2.0
- [ ] Bump version SKILL.md `1.2.0` → `2.0.0` + last_updated
- [ ] Update memory entry → COMPLETED

---

## 6. Quy ước tài liệu

### Trạng thái sprint

| Status | Ý nghĩa |
|--------|---------|
| ⏸ NOT_STARTED | Chưa bắt đầu |
| 🔄 IN_PROGRESS | Đang làm (1 phiên đang xử lý) |
| ⚠️ BLOCKED | Đang chờ user trả lời câu hỏi hoặc decision |
| ✅ COMPLETED | Đã hoàn thành + verify PASS |
| ❌ FAILED | Đã thử nhưng fail — cần retry |

### Cách cập nhật giữa các phiên

Sau mỗi session làm việc:
1. Update `progress.md` — sprint status, what done, what next, blockers
2. Nếu phát hiện gap mới → thêm vào `01-compliance-gaps.md`
3. Nếu cần thay đổi architecture → update `02-architecture-design.md`
4. Nếu cần user decide → thêm vào `03-decisions-pending.md` + set sprint status = BLOCKED
5. Sync memory entry `project_wf-diagram-v2-improvement-plan.md`

### Sprint file structure

Mỗi sprint file (sẽ tạo trong sprints/) có cấu trúc:
```
1. Mục tiêu sprint
2. Why (lý do, evidence)
3. Files modified (CHECKLIST)
4. Detailed changes (per file/section)
5. Verify checklist
6. Rollback plan (nếu có)
7. Status & notes
```

---

## 7. Risk register (xem chi tiết `01-compliance-gaps.md` §4)

| Risk | Mức độ | Mitigation |
|------|--------|-----------|
| Refactor làm hỏng v1.2.0 đang chạy | HIGH | `flow-new.md` → `.bak`, smoke test sau mỗi sprint |
| Bash scripts không cross-platform | MEDIUM | Source legacy-scan-common.sh patterns; test Git Bash |
| Mermaid 8.8.0 safety không cover hết | MEDIUM | Bash validator grep 9 patterns block |
| `analysis.json` schema drift | MEDIUM | Define schema rõ trong `_shared.md`; jq validate Phase 2 POST-GATE |
| Evals fail vì source thật khác mock | LOW | Manual smoke test, eval dùng "expected_behavior" descriptive |
| User reject decision khi đang implement | LOW | Sprint 1 đợi user duyệt trước Sprint 2 |

---

## 8. Tham chiếu code mẫu

| Pattern | Reference |
|---------|-----------|
| Lazy-load phase files | `wf-scan-target/procedures/`, `wf-add-scope/procedures/`, `wf-verify-sync/procedures/` |
| Bash script common helpers | `.claude/scripts/scan-target-common.sh`, `legacy-scan-common.sh` |
| Atomic write JSON | `scan-target-common.sh::atomic_write_json` |
| Resume routing | `wf-scan-target/procedures/resume-status.md` |
| Phase routing map trong SKILL.md | `wf-scan-target/SKILL.md` "Phase Routing Map (lazy-loaded)" |
| `_shared.md` cấu trúc | `wf-scan-target/procedures/_shared.md` |
| Compliance audit | `.claude/scripts/skill-compliance-audit.sh wf-scan-target` |
| Mermaid 8.8.0 safety patterns | `wf-diagram/SKILL.md` §"Mermaid 8.8.0 Safety Rules" (đã có) |

---

## 9. Inter-session handoff checklist

Khi kết thúc 1 phiên:
- [ ] Update `progress.md` — sprint status, what done, what next, blockers
- [ ] Update memory entry
- [ ] Commit (nếu user yêu cầu) — ghi rõ "Sprint X partial: ..."
- [ ] Note next session prompt trong `_next-session-prompt.md`

Khi bắt đầu phiên mới:
- [ ] Đọc `progress.md` để biết đang ở đâu
- [ ] Đọc `_next-session-prompt.md` để biết task tiếp theo
- [ ] Check memory entry có cập nhật mới không
- [ ] Verify: lần làm trước có để code dở dang không (git diff)
