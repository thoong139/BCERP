# Shared Protocols — existing-project

> Cross-cutting protocols, state variables, schemas, và error reference được dùng bởi
> nhiều Phase của existing-project orchestrator.
> KHÔNG đọc file này standalone — các phase file chỉ trỏ section cụ thể khi cần.

## Sections

- [State Variables Glossary](#state-variables-glossary)
- [Cross-Phase Data Flow](#cross-phase-data-flow)
- [Status File Schema](#status-file-schema)
- [LEGACY_MODE Detection](#legacy_mode-detection)
- [Fix Rules](#fix-rules)
- [Resume Protocol](#resume-protocol)
- [`--from-phase` Mapping](#--from-phase-mapping)
- [Error Handling Reference](#error-handling-reference)
- [Context & Checkpoint](#context--checkpoint)
- [Sub-Skill Invocation Pattern](#sub-skill-invocation-pattern)

---

## State Variables Glossary

| Variable | Set by | Read by | Description |
|----------|--------|---------|-------------|
| `$STATUS_FILE` | phase0-init | All phases | `.mc-data/work/existing-project/checkpoint.json` |
| `$LEGACY_PIPELINE_DONE` | phase0-init | scan, 0b cluster | true nếu ledger.pipeline_status == "COMPLETE" → skip scan + 0b |
| `$STRATEGY` | phase-scan | All phases sau scan | Strategy code (S1-S7) detect bởi wf-legacy-scan |
| `$MATURITY_LEVEL` | phase-annotate | annotate | DOCS_ONLY / CODE_ONLY / BOTH (đọc từ ledger.json) |
| `$HAS_ANNOTATION_GAPS` | phase-annotate | annotate | Boolean — true nếu gap-report.md có annotation gaps |
| `$INTERFACE_TYPE` | phase-design | phase4-ux, phase5a-plan | Đọc từ registry sau khi pipeline 0b xong (default `web+mobile`) |
| `$DEPRECATED_MODULES` | phase0-init | Mọi phase có liên quan | Modules có `action == "DEPRECATE"` trong legacy-decisions.json |
| `$PENDING_FEATURES` | phase5b-implement | phase5b-implement | Features có `impl_status != "done"` từ registry |
| `$PREFLIGHT_VERDICT` | phase-preflight | phase-verify | PASS / WARN / FAIL |

---

## Cross-Phase Data Flow

```
phase0-init        → $STATUS_FILE, $LEGACY_PIPELINE_DONE, $DEPRECATED_MODULES
phase-scan         → $STRATEGY, ledger.pipeline_status (downstream)
phase-brainstorm   → phase0-brainstorm/ docs + legacy-decisions.json
phase-analyze-req  → phase1-business/ docs + registry.requirements/systems/modules
phase-define-feats → phase2-features/ docs + registry.features
phase-design       → phase3-architecture/ docs + registry.design_status + gap-report.md + $INTERFACE_TYPE
phase-annotate     → annotation-report.md (conditional)
phase4-ux          → phase4-ux/ docs (conditional)
phase5a-plan       → phase5-implementation/P5-00-implementation-roadmap.md + task files
phase5b-implement  → registry.requirements[].impl_status = "done" per feature (loop)
phase-preflight    → preflight-report.md + $PREFLIGHT_VERDICT
phase-verify       → verify-sync.md
phase6-deployment  → phase6-deployment/ docs + stakeholder-review.md
```

**Quy tắc:** mỗi phase chỉ READ biến đã được SET ở phase trước. POST-GATE của phase N
cập nhật `$STATUS_FILE.phases_completed[]` hoặc `phases_skipped[]` + `current_step = phase[N+1]`.

---

## Status File Schema

**Path:** `.mc-data/work/existing-project/checkpoint.json`

```json
{
  "version": "4.0.0",
  "started_at": "ISO-8601 timestamp",
  "updated_at": "ISO-8601 timestamp",
  "current_step": "phase0",
  "strategy": null,
  "legacy_pipeline_done": false,
  "deprecated_modules": [],
  "phase_0b_progress": {
    "brainstorm": "pending",
    "analyze_requirements": "pending",
    "define_features": "pending",
    "design": "pending"
  },
  "annotate_skip_reason": null,
  "phase_4_skip_reason": null,
  "phase_5b_progress": {
    "total_features": 0,
    "completed": [],
    "skipped": [],
    "next_feature": null
  },
  "phases_completed": [],
  "phases_skipped": [],
  "interface_type": null,
  "preflight_verdict": null
}
```

**Hợp lệ của `current_step`:** `"phase0" | "scan" | "brainstorm" | "analyze-req" | "define-features" | "design" | "annotate" | "phase4" | "phase5a" | "phase5b" | "preflight" | "verify" | "deployment" | "completed"`.

**Hợp lệ của `annotate_skip_reason`:** `null | "docs-only" | "no-gaps" | "user-skip"`.
**Hợp lệ của `phase_4_skip_reason`:** `null | "api-only" | "ui-unchanged"`.
**Hợp lệ của `preflight_verdict`:** `null | "PASS" | "WARN" | "FAIL"`.

> **Schema reference:** existing-project mở rộng custom schema so với `.claude/skills/schemas/status-file-schema.json` — thêm `strategy`, `legacy_pipeline_done`, `phase_0b_progress`, `annotate_skip_reason`, `phase_4_skip_reason`, `phase_5b_progress`, `preflight_verdict`, `deprecated_modules`.

---

## LEGACY_MODE Detection

> Theo CORE-021, legacy-mode trong DEVKIT detect bằng `project-context.md > 500 bytes`.
> Trong existing-project, project-context.md được TẠO bởi wf-legacy-scan ở phase-scan.
> Trước phase-scan, không có legacy-context — các phase 0b cluster sẽ tự detect khi chạy.

**Đọc deprecated_modules sau khi phase-brainstorm tạo legacy-decisions.json:**

```bash
DEPRECATED_MODULES="[]"

if test -f .mc-data/work/wf-brainstorm/legacy-decisions.json; then
  DEPRECATED_MODULES=$(jq -c '[.modules[] | select(.action=="DEPRECATE") | .id]' \
    .mc-data/work/wf-brainstorm/legacy-decisions.json)
fi
```

Ghi vào status file: `deprecated_modules`. Phase downstream (define-features, design, plan-modules, implement-feature) tự enforce filter theo CORE-022.

---

## Fix Rules

| Error Type | Auto-Fix Strategy | Escalate If |
|-----------|-------------------|-------------|
| `codebase_not_found` | Hỏi user verify path | Path không tồn tại |
| `mcdata_conflict` | Hỏi user: resume / backup + onboard lại | User cancel |
| `post_gate_fail` | Retry 3 lần theo Accuracy Assurance Protocol | Vẫn fail sau 3 lần |
| `sub_skill_fail` | Retry sub-skill 1 lần → STOP + hỏi user retry/skip/abort | User abort |
| `sub_skill_invalid_output` | Validate output JSON/content → retry sub-skill 1 lần | Vẫn invalid sau retry |
| `sub_skill_missing` | STOP — báo path bị thiếu | Không thể auto-fix |
| `jq_unavailable` | Fallback python | Python cũng không có |
| `registry_missing` | Chạy lại phase-scan (tối đa 1 lần) | Vẫn thiếu sau retry |
| `registry_invalid_schema` | Validate schema → chạy lại phase-design (rebuild registry, tối đa 1 lần) | Vẫn invalid sau retry |
| `skip_state_lost` | Đọc checkpoint.json → nếu không có, hỏi user lại về skip decision | — |

---

## Resume Protocol

Khi có flag `--resume`:

```
1. READ $STATUS_FILE (.mc-data/work/existing-project/checkpoint.json)
   - Nếu không tồn tại → fallback output-path inference (xem phía dưới)
2. VALIDATE current_step ∈ {phase0, scan, brainstorm, analyze-req, define-features, design,
                            annotate, phase4, phase5a, phase5b, preflight, verify, deployment, completed}
   Nếu invalid → STOP: "current_step không hợp lệ. Dùng --from-phase để override."
3. LOAD context: strategy, legacy_pipeline_done, phase_0b_progress, annotate_skip_reason,
                 phase_4_skip_reason, phase_5b_progress, deprecated_modules, interface_type
4. CROSS-VALIDATE với file system (xem bảng phía dưới)
5. HIỂN THỊ progress dashboard (✅ done / ⏭ skipped / ⏳ in-progress / ⬜ pending)
6. HỎI user xác nhận trước khi tiếp tục từ current_step
7. JUMP tới phase tương ứng
```

### Cross-validation table (Resume)

| Step | File system check |
|------|-------------------|
| `scan` | `test -f .mc-data/work/legacy-scan/project-context.md && test $(wc -c < ...) -gt 500 && jq -e '.pipeline_status == "COMPLETE"' ledger.json` |
| `brainstorm` | `test -d .mc-data/docs/phase0-brainstorm && test -f .mc-data/work/wf-brainstorm/legacy-decisions.json` |
| `analyze-req` | `test -d .mc-data/docs/phase1-business` |
| `define-features` | `test -d .mc-data/docs/phase2-features` |
| `design` | `jq -e '.requirements \| length > 0' .mc-data/docs/_meta/req-registry.json` |
| `annotate` | `checkpoint.annotate_skip_reason != null` HOẶC `test -f .mc-data/work/legacy-scan/annotation-report.md` |
| `phase4` | `checkpoint.phase_4_skip_reason != null` HOẶC `test -d .mc-data/docs/phase4-ux` |
| `phase5a` | `test -f .mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md` |
| `phase5b` | `checkpoint.phase_5b_progress.next_feature` HOẶC kiểm tra `impl_status` trong registry |
| `preflight` | `test -f .mc-data/work/wf-preflight/preflight-report.md` |
| `verify` | `test -f .mc-data/docs/_meta/verify-sync.md` |
| `deployment` | `test -f .mc-data/docs/phase6-deployment/stakeholder-review.md` |

### Status file fallback (E012)

Nếu `$STATUS_FILE` không tồn tại hoặc corrupt:
```
1. Infer state từ output paths theo bảng cross-validation phía trên (top-down)
2. Bước cuối cùng có file → current_step = bước kế tiếp
3. Hiển thị inferred state, hỏi user xác nhận trước khi resume
4. Rebuild $STATUS_FILE với inferred fields
```

---

## `--from-phase` Mapping

| Giá trị | Nhảy đến | Prerequisite cần |
|---------|----------|------------------|
| `scan` | phase-scan.md | Codebase tồn tại |
| `0` | phase-brainstorm.md | scan completed (project-context.md > 500 bytes) |
| `1` | phase-analyze-req.md | brainstorm completed |
| `2` | phase-define-features.md | analyze-req completed (registry có requirements) |
| `3` | phase-design.md | define-features completed (registry có features) |
| `annotate` | phase-annotate.md | design completed (gap-report.md tồn tại) |
| `4` | phase4-ux.md | design completed; KHÔNG api-only |
| `5a` | phase5a-plan.md | phase4 xong/skip + registry có features |
| `5b` | phase5b-implement.md | phase5a completed (roadmap tồn tại) |
| `preflight` | phase-preflight.md | ≥1 feature có impl_status="done" |
| `verify` | phase-verify.md | preflight completed (hoặc user confirm sau WARN) |
| `6` | phase6-deployment.md | verify-sync.md tồn tại |

**Giá trị không hợp lệ:** báo lỗi `E010` — "Giá trị --from-phase không hợp lệ. Các giá trị chấp nhận: scan, 0, 1, 2, 3, annotate, 4, 5a, 5b, preflight, verify, 6."

---

## Error Handling Reference

| Code | Tình huống | Xử lý |
|------|-----------|--------|
| E001 | Codebase không tồn tại khi PRE-GATE | STOP → "Không tìm thấy codebase. Kiểm tra thư mục project." |
| E002 | `.mc-data/` đã tồn tại, user chọn onboard lại | Backup `.mc-data/` → `_mc-data-backup-YYYYMMDD-HHMMSS/` trước khi overwrite |
| E003 | POST-GATE fail sau 3 lần retry | STOP phase → hiển thị lệnh fail, hỏi user cách xử lý |
| E004 | Sub-skill SKILL.md không tồn tại | STOP → báo path bị thiếu, dừng workflow |
| E005 | `req-registry.json` không tồn tại sau shared skills cluster | Kiểm tra skill nào chưa hoàn thành, hướng dẫn user chạy lại |
| E006 | `jq` không khả dụng | Dùng `python -c "import json; ..."` thay thế |
| E007 | Implement feature vòng lặp bị gián đoạn (user dừng) | Thông báo: "Đã dừng. Dùng `/existing-project --resume` để tiếp tục từ feature kế tiếp." |
| E008 | wf-implement-feature POST-GATE fail (impl_status không == "done") | Hỏi user: skip feature này hay retry? |
| E009 | wf-verify-sync POST-GATE fail | Retry tối đa 2 lần; nếu vẫn fail → hiển thị warning, cho phép tiếp tục với xác nhận user |
| E010 | `--from-phase` N không hợp lệ | Hiển thị bảng mapping hợp lệ |
| E011 | `--from-phase N` nhưng prerequisites của phase đích chưa sẵn sàng | Thông báo thiếu gì, gợi ý chạy từ phase nào trước |
| E012 | Registry tồn tại nhưng thiếu required fields (requirements, systems) | Chạy lại `/wf-design` (legacy flow rebuild registry), tối đa 1 lần |
| E013 | wf-preflight POST-GATE fail (preflight-report không tồn tại) | Retry 1 lần; nếu vẫn fail → cho phép skip preflight với user xác nhận |
| E014 | Sub-skill fail sau retry (sub_skill_fail) | STOP, hiển thị lỗi cụ thể, hỏi user: retry / skip sub-skill / abort workflow |
| E015 | Preflight FAIL | Hiển thị errors, gợi ý `/wf-fix-bugs` trước khi resume Verify |
| E016 | Status file corrupt → trigger E012 fallback (rebuild từ output paths) | Rebuild theo Resume Protocol §Status file fallback |
| E017 | Module mục tiêu nằm trong `deprecated_modules` (LEGACY_MODE) | Sub-skill tự enforce theo CORE-022 — orchestrator chỉ propagate context |

---

## Context & Checkpoint

| Context Usage | Hành động |
|---------------|-----------|
| < 65% | Tiếp tục bình thường |
| 65–80% | Chuẩn bị checkpoint |
| 80–90% | Lưu checkpoint ngay |
| > 90% | FORCE STOP — checkpoint bắt buộc, thông báo user dùng `--resume` |

Checkpoint = cập nhật `$STATUS_FILE` (tối thiểu `current_step`, `phases_completed`, `updated_at`).

---

## Sub-Skill Invocation Pattern

Mọi phase delegate đến sub-skill theo pattern chung:

```
1. Hiển thị: `▶ [Phase title]`
2. VERIFY .claude/skills/workflow/[sub-skill]/SKILL.md tồn tại (Read → nếu fail → E004)
3. Gọi Skill("[sub-skill]", args=<nếu có>)
4. Đợi sub-skill hoàn thành POST-GATE của chính nó
5. Chạy POST-GATE của phase này (đặc thù per phase file)
6. Cập nhật $STATUS_FILE: phases_completed += step-id, current_step = step kế
7. Transition message: `✅ [Phase title] hoàn thành` → hỏi user xác nhận tiếp tục (trừ loop 5b)
```

**Luật retry:** nếu POST-GATE của phase fail → retry sub-skill tối đa 3 lần → E003 nếu vẫn fail.

**Shared skills cluster (Buoc 0b):** brainstorm/analyze-req/define-features/design tự detect LEGACY_MODE
qua CORE-021 (đọc project-context.md) và inject context. Orchestrator KHÔNG truyền `--legacy` flag.
Giữa mỗi sub-skill trong cluster, hỏi user xác nhận tiếp tục + cập nhật `phase_0b_progress` trong checkpoint.
