# Shared Protocols — new-project

> Cross-cutting protocols, state variables, schemas, và error reference được dùng bởi
> nhiều Phase của new-project orchestrator.
> KHÔNG đọc file này standalone — các phase file chỉ trỏ section cụ thể khi cần.

## Sections

- [Step Map & DEVKIT Phase Mapping](#step-map--devkit-phase-mapping)
- [State Variables Glossary](#state-variables-glossary)
- [Cross-Phase Data Flow](#cross-phase-data-flow)
- [Status File Schema](#status-file-schema)
- [Fix Rules](#fix-rules)
- [Resume Protocol](#resume-protocol)
- [`--from-phase` Mapping](#--from-phase-mapping)
- [Status Check Protocol](#status-check-protocol)
- [Error Handling Reference](#error-handling-reference)
- [Context & Checkpoint](#context--checkpoint)
- [Sub-Skill Invocation Pattern](#sub-skill-invocation-pattern)

---

## Step Map & DEVKIT Phase Mapping

> Orchestrator có **10 bước tuần tự** (Bước 0 → Bước 9). Mỗi bước delegate đến 1 sub-skill.
> File `phaseN-*.md` trong `procedures/` là **bước orchestrator**, KHÔNG phải DEVKIT phase.

| File | Orch. step | Sub-skill | DEVKIT phase | Conditional |
|------|-----------|-----------|--------------|-------------|
| `phase0-init.md` | — (entry) | — | — | Always |
| `phase1-brainstorm.md` | Bước 0 | `wf-brainstorm` | Phase 0 | Always |
| `phase2-analyze.md` | Bước 1 | `wf-analyze-requirements` | Phase 1 | Always |
| `phase3-features.md` | Bước 2 | `wf-define-features` | Phase 2 | Always |
| `phase4-design.md` | Bước 3 | `wf-design` | Phase 3 | Always |
| `phase5-ux.md` | Bước 4 | `wf-design-ux` | Phase 4 | `interface_type != "api-only"` |
| `phase6-plan.md` | Bước 5 | `wf-plan-modules` | Phase 5a | Always |
| `phase7-implement.md` | Bước 6 | `wf-implement-feature` | Phase 5b | Loop per feature |
| `phase8-preflight.md` | Bước 7 | `wf-preflight` | Phase 5c | Always |
| `phase9-verify.md` | Bước 8 | `wf-verify-sync` | Verify | Always |
| `phase10-deploy.md` | Bước 9 | `wf-prepare-deployment` | Phase 6 | Always |

---

## State Variables Glossary

| Variable | Set by | Read by | Description |
|----------|--------|---------|-------------|
| `$PROJECT_NAME` | phase0-init | 1 | Tên project từ argument (hoặc lấy từ brainstorm) |
| `$STATUS_FILE` | phase0-init | All phases | `.mc-data/work/new-project/status.json` |
| `$INTERFACE_TYPE` | phase4-design | 5 | Giá trị `interface_type` trong registry (default `web+mobile`) |
| `$PHASE5_SKIPPED` | phase5-ux | Resume | Boolean — true nếu Phase 4 (UX) bị skip do api-only |
| `$PENDING_FEATURES[]` | phase7-implement | 7 (loop) | Danh sách feature_id có `impl_status != "done"` |
| `$CURRENT_FEATURE` | phase7-implement | Resume | Feature đang implement trong loop |
| `$PREFLIGHT_STATUS` | phase8-preflight | 9 | `PASS` / `WARN` / `FAIL` |
| `$CURRENT_STEP` | Mọi bước | Resume | Orchestrator step đang chạy — ghi vào status file sau mỗi bước |

---

## Cross-Phase Data Flow

```
phase0-init            → $STATUS_FILE, $PROJECT_NAME, flags (--resume, --from-phase, --status)
phase1-brainstorm      → .mc-data/ init, req-registry.json seed, phase0-brainstorm/*
phase2-analyze         → registry.systems[], registry.modules[], registry.requirements[],
                         phase1-business/*
phase3-features        → registry.features[], phase2-features/**/*.md
phase4-design          → registry.design_status, registry.interface_type (read), phase3-architecture/*
phase5-ux (conditional)→ registry.ux_design_status, phase4-ux/*
phase6-plan            → phase5-implementation/P5-00-implementation-roadmap.md + task files
phase7-implement (loop)→ registry.requirements[].impl_status = "done" per feature
phase8-preflight       → .mc-data/work/wf-preflight/preflight-report.md ($PREFLIGHT_STATUS)
phase9-verify          → .mc-data/docs/_meta/verify-sync.md
phase10-deploy         → phase6-deployment/*
```

**Quy tắc:** mỗi phase chỉ READ biến đã được SET ở phase trước. POST-GATE của bước N
cập nhật `$STATUS_FILE.steps_completed[]` hoặc `steps_skipped[]` + `current_step = N+1`.

---

## Status File Schema

**Path:** `.mc-data/work/new-project/status.json`

```json
{
  "skill": "new-project",
  "version": "4.0.0",
  "project_name": "tên-dự-án",
  "started_at": "ISO-8601 timestamp",
  "updated_at": "ISO-8601 timestamp",
  "current_step": 0,
  "current_phase": "phase0-init",
  "steps_completed": [],
  "steps_skipped": [],
  "phase5_skipped": false,
  "interface_type": null,
  "implement_progress": {
    "total_features": 0,
    "completed_features": 0,
    "current_feature": null,
    "pending_features": []
  },
  "preflight_status": null,
  "next_action": "Bắt đầu Bước 0 — Phase 0: Brainstorm",
  "last_updated": "ISO-8601 timestamp"
}
```

**Hợp lệ của `current_phase`:**
`"phase0-init" | "phase1-brainstorm" | "phase2-analyze" | "phase3-features" | "phase4-design" | "phase5-ux" | "phase6-plan" | "phase7-implement" | "phase8-preflight" | "phase9-verify" | "phase10-deploy" | "completed"`.

**Hợp lệ của `current_step`:** `0 | 1 | 2 | ... | 9 | "completed"`.

**Ghi checkpoint SAU MỖI BƯỚC hoàn thành** — không chờ đến cuối workflow.

---

## Fix Rules

| Error Type | Auto-Fix Strategy | Escalate If |
|-----------|-------------------|-------------|
| POST-GATE fail | Retry sub-skill (max 3 lần) | Vẫn fail sau 3 lần (E001) |
| Sub-skill SKILL.md không tồn tại | Kiểm tra path `.claude/skills/workflow/` | Path không tồn tại (E004) |
| Registry JSON invalid | `jq '.' registry.json` → fix syntax | Structure corruption |
| `--from-phase` thiếu prerequisite | Chạy prerequisite check → báo user | User không muốn chạy prerequisite |
| Resume status.json corrupt | Xóa status file, chạy resume detection bằng file checks | Không xác định được trạng thái (E009) |
| Context > 90% giữa sub-skill | Force checkpoint, thông báo resume | — (E013) |
| `jq` không khả dụng | Fallback python một dòng | Python cũng không có (E012) |
| Sub-skill timeout / partial output | Retry 1 lần, nếu fail → escalate user | Retry fail → E014 |

---

## Resume Protocol

Khi có flag `--resume`:

```
0. Nếu .mc-data/ KHÔNG tồn tại → báo E011: "Chưa có dự án nào. Dùng /new-project [tên] để bắt đầu mới." → DỪNG
1. Nếu tồn tại $STATUS_FILE → đọc trạng thái từ file
2. Nếu không → chạy file-based detection qua PHASE_CHECKS (xem dưới)
3. VALIDATE current_phase ∈ danh sách hợp lệ (xem Status File Schema)
   Nếu invalid → STOP: "current_phase không hợp lệ. Dùng --from-phase để override."
4. LOAD context: steps_completed, steps_skipped, interface_type, implement_progress
5. CROSS-VALIDATE với file system (xem PHASE_CHECKS bên dưới)
6. HIỂN THỊ progress dashboard (ký hiệu ✅/⏭/⏳/⬜)
7. HỎI user xác nhận trước khi tiếp tục từ current_step
8. JUMP tới phase file tương ứng
```

### File-based Phase Detection (PHASE_CHECKS)

```
PHASE_CHECKS = [
  { step: 0, name: "Phase 0: Brainstorm",
    check: "test -f .mc-data/docs/phase0-brainstorm/P0-01-brainstorm.md" },
  { step: 1, name: "Phase 1: Requirements",
    check: "jq -e '.requirements | length > 0' .mc-data/docs/_meta/req-registry.json" },
  { step: 2, name: "Phase 2: Features",
    check: "jq -e '.features | length > 0' .mc-data/docs/_meta/req-registry.json" },
  { step: 3, name: "Phase 3: Design",
    check: "test -f .mc-data/docs/phase3-architecture/stakeholder-review.md" },
  { step: 4, name: "Phase 4: UX",
    check: "test -f .mc-data/docs/phase4-ux/stakeholder-review.md",
    skip_check: "jq -e '.interface_type == \"api-only\"' .mc-data/docs/_meta/req-registry.json" },
  { step: 5, name: "Phase 5a: Plan",
    check: "test -f .mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md" },
  { step: 6, name: "Phase 5b: Implement",
    check: "jq -e '[.features[] | select(.impl_status == \"done\")] | length > 0' .mc-data/docs/_meta/req-registry.json" },
  { step: 7, name: "Phase 5c: Preflight",
    check: "test -f .mc-data/work/wf-preflight/preflight-report.md" },
  { step: 8, name: "Verify: Sync",
    check: "test -f .mc-data/docs/_meta/verify-sync.md" },
  { step: 9, name: "Phase 6: Deployment",
    check: "test -f .mc-data/docs/phase6-deployment/stakeholder-review.md" }
]
```

### Dashboard icons

```
[✓]    = hoàn thành (check PASS)
[SKIP] = bỏ qua (skip_check PASS — VD: Phase 4 api-only)
[~]    = đang dở (check FAIL, là phase đầu tiên chưa hoàn thành)
[ ]    = chưa bắt đầu
```

---

## `--from-phase` Mapping

| Giá trị (user arg) | Nhảy đến file | Orch. step | DEVKIT phase | Prerequisite cần |
|---------|----------|------------|--------------|------------------|
| `0` | `phase1-brainstorm.md` | 0 | Phase 0 | Không |
| `1` | `phase2-analyze.md` | 1 | Phase 1 | Phase 0 output + registry |
| `2` | `phase3-features.md` | 2 | Phase 2 | Phase 1 output (requirements[]) |
| `3` | `phase4-design.md` | 3 | Phase 3 | Phase 2 output (features[]) |
| `4` | `phase5-ux.md` | 4 | Phase 4 | Phase 3 output |
| `5a` | `phase6-plan.md` | 5 | Phase 5a | Phase 4 output (hoặc Phase 3 nếu api-only) |
| `5b` | `phase7-implement.md` | 6 | Phase 5b | Phase 5a output |
| `5c` | `phase8-preflight.md` | 7 | Phase 5c | Phase 5b output (≥1 feature done) |
| `verify` | `phase9-verify.md` | 8 | Verify | Preflight output |
| `6` | `phase10-deploy.md` | 9 | Phase 6 | Verify output |

**Giá trị không hợp lệ** → E007: "Giá trị --from-phase không hợp lệ. Các giá trị chấp nhận: 0, 1, 2, 3, 4, 5a, 5b, 5c, verify, 6."

### Prerequisite Validation (BẮT BUỘC cho `--from-phase`)

Trước khi nhảy đến phase N, kiểm tra output của phase N-1 tồn tại (tuân thủ CORE-002).

```
PREREQUISITE_CHECKS = {
  "1":      test -f .mc-data/docs/phase0-brainstorm/P0-01-brainstorm.md
            && test -f .mc-data/docs/_meta/req-registry.json,
  "2":      jq -e '.requirements | length > 0' .mc-data/docs/_meta/req-registry.json,
  "3":      jq -e '.features | length > 0' .mc-data/docs/_meta/req-registry.json,
  "4":      test -f .mc-data/docs/phase3-architecture/stakeholder-review.md,
  "5a":     test -f .mc-data/docs/phase3-architecture/stakeholder-review.md
            && (jq -e '.interface_type == "api-only"' .mc-data/docs/_meta/req-registry.json
                || test -f .mc-data/docs/phase4-ux/stakeholder-review.md),
  "5b":     test -f .mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md,
  "5c":     jq -e '[.features[] | select(.impl_status == "done")] | length > 0' .mc-data/docs/_meta/req-registry.json,
  "verify": test -f .mc-data/work/wf-preflight/preflight-report.md
            && test -s .mc-data/work/wf-preflight/preflight-report.md,
  "6":      test -f .mc-data/docs/_meta/verify-sync.md
}
```

Nếu prerequisite FAIL → E010: "Phase [N-1] chưa hoàn thành. Cần chạy từ phase [N-1] trước. Chạy từ phase [N-1] thay thế? (yes/no)"

---

## Status Check Protocol

Khi có flag `--status`:

```
0. Nếu .mc-data/ KHÔNG tồn tại → E011 → DỪNG
1. Đọc $STATUS_FILE nếu tồn tại
2. Nếu không có $STATUS_FILE → chạy file-based detection (PHASE_CHECKS)
3. Hiển thị progress dashboard:

   DEVKIT — New Project Progress
   ─────────────────────────────────
   [✓] Phase 0: Brainstorm
   [✓] Phase 1: Requirements Analysis
   [ ] Phase 2: Feature Definitions     ← tiep tuc tu day
   [ ] Phase 3 → Phase 6

   Dung /new-project --resume de tiep tuc.

4. DỪNG — không thực thi gì thêm
```

---

## Error Handling Reference

| Code | Tình huống | Xử lý |
|------|-----------|--------|
| E001 | POST-GATE fail sau 3 lần retry | STOP phase, hiển thị lỗi cụ thể, hỏi user |
| E002 | User từ chối tiếp tục giữa bước | Ghi checkpoint, thông báo resume bằng `--resume` |
| E003 | registry.json không tồn tại | Kiểm tra Phase 0 output, chạy lại nếu cần |
| E004 | Sub-skill SKILL.md không tồn tại | STOP, báo path cụ thể, liệt kê paths đúng |
| E005 | Implement feature vòng lặp bị gián đoạn | Ghi checkpoint (feature hiện tại + progress), user resume |
| E006 | Context > 90% giữa sub-skill | Force checkpoint, thông báo: dùng `--resume` trong session mới |
| E007 | `--from-phase` giá trị không hợp lệ | Hiển thị mapping table, yêu cầu user chọn lại |
| E008 | `--resume` và `--from-phase` cùng lúc | Báo conflict, hỏi user chọn 1 trong 2 |
| E009 | status.json corrupt hoặc invalid JSON | Xóa status file, chạy file-based detection thay thế |
| E010 | `--from-phase` nhưng prerequisite chưa hoàn thành | Hiển thị prerequisite thiếu, đề xuất chạy từ phase trước |
| E011 | `--resume` hoặc `--status` khi `.mc-data/` chưa tồn tại | "Chưa có dự án nào. Dùng /new-project [tên] để bắt đầu mới." → DỪNG |
| E012 | `jq` không khả dụng | Fallback: `python -c "import json; d=json.load(open('.mc-data/docs/_meta/req-registry.json')); print(d.get('interface_type','web+mobile'))"` |
| E013 | Context > 90% giữa sub-skills | FORCE STOP — lưu checkpoint ngay, thông báo tiếp tục bằng `--resume` |
| E014 | Sub-skill timeout / partial output | Retry 1 lần. Nếu fail lần 2 → escalate user với stage name và last known state |
| E015 | Preflight FAIL (Bước 7) | Hiển thị warnings, hỏi user: continue (note) / fix (/wf-fix-bugs rồi resume) |

---

## Context & Checkpoint

Đây là multi-session orchestrator — checkpoint rất quan trọng vì workflow kéo dài nhiều giờ.

| Context Usage | Hành động |
|---------------|-----------|
| < 65% | Tiếp tục bình thường |
| 65-80% | Chuẩn bị checkpoint |
| 80-90% | Lưu checkpoint ngay |
| > 90% | FORCE STOP — checkpoint bắt buộc (E013) |

Checkpoint = cập nhật `$STATUS_FILE` (tối thiểu `current_step`, `current_phase`, `steps_completed`, `updated_at`).

### Resume Process

1. READ `status.json` từ `.mc-data/work/new-project/`
2. LOAD context: đọc registry + output files của phases đã hoàn thành
3. CONTINUE từ `next_action` trong status file

---

## Sub-Skill Invocation Pattern

Mọi phase (trừ `phase0-init.md`) delegate đến sub-skill theo pattern chung:

```
1. Hiển thị: `▶ Bước N — Phase X: [tiêu đề]`
2. VERIFY .claude/skills/workflow/[sub-skill]/SKILL.md tồn tại (Read → nếu fail → E004)
3. Gọi Skill("[sub-skill]", args=<nếu có>)
4. Đợi sub-skill hoàn thành POST-GATE của chính nó
5. Chạy POST-GATE của phase này (đặc thù per phase file)
6. Cập nhật $STATUS_FILE: steps_completed += step-id, current_step = step kế
7. Transition message: `✅ Bước N hoàn thành` → hỏi user xác nhận tiếp tục (trừ loop Bước 6)
```

**Luật retry:** nếu POST-GATE của phase fail → retry sub-skill tối đa 3 lần → E001 nếu vẫn fail.

### Sub-skill Paths (validation trước khi chạy)

```
SUB_SKILLS = [
  ".claude/skills/workflow/wf-brainstorm/SKILL.md",          # Bước 0
  ".claude/skills/workflow/wf-analyze-requirements/SKILL.md", # Bước 1
  ".claude/skills/workflow/wf-define-features/SKILL.md",      # Bước 2
  ".claude/skills/workflow/wf-design/SKILL.md",               # Bước 3
  ".claude/skills/workflow/wf-design-ux/SKILL.md",            # Bước 4
  ".claude/skills/workflow/wf-plan-modules/SKILL.md",         # Bước 5
  ".claude/skills/workflow/wf-implement-feature/SKILL.md",    # Bước 6
  ".claude/skills/workflow/wf-preflight/SKILL.md",            # Bước 7
  ".claude/skills/workflow/wf-verify-sync/SKILL.md",          # Bước 8
  ".claude/skills/workflow/wf-prepare-deployment/SKILL.md"    # Bước 9
]
```

`phase0-init` validate toàn bộ 10 paths tồn tại trước khi confirm start với user.
