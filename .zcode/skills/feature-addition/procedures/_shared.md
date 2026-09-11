# Shared Protocols — feature-addition

> Cross-cutting protocols, state variables, schemas, và error reference được dùng bởi
> nhiều Phase của feature-addition orchestrator.
> KHÔNG đọc file này standalone — các phase file chỉ trỏ section cụ thể khi cần.

## Sections

- [State Variables Glossary](#state-variables-glossary)
- [Cross-Phase Data Flow](#cross-phase-data-flow)
- [Status File Schema](#status-file-schema)
- [LEGACY_MODE Detection](#legacy_mode-detection)
- [Lock File Mechanism](#lock-file-mechanism)
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
| `$FEATURE_NAME` | Phase 0.5 | 0, 2 | Tên feature mới (optional — có thể define trong Phase 2) |
| `$STATUS_FILE` | Phase 0.4 | All phases | `.mc-data/work/feature-addition/feature-addition-status.json` |
| `$FEATURE_COUNT_BEFORE` | Phase 0.2 | 2 | Số features đã có trong registry trước khi chạy |
| `$EXISTING_FEATURE_IDS` | Phase 0.2 | 2 | Danh sách feature IDs đã có |
| `$EXISTING_MODULE_IDS` | Phase 0.3 | 1 | Danh sách module IDs đã có |
| `$NEW_FEATURE_IDS` | Phase 2 | 5a, 5b, 6, 7 | Danh sách feature IDs mới (tính bằng diff) |
| `$INTERFACE_TYPE` | Phase 3 | 4 | Giá trị `interface_type` trong registry (default `web+mobile`) |
| `$LEGACY_MODE` | Phase 0.6 | 1, 5b | Boolean — true khi project-context.md > 500 bytes |
| `$DEPRECATED_MODULES` | Phase 0.6 | 1, 5b | Modules có `action == "DEPRECATE"` trong legacy-decisions.json |
| `$MODULE_SCOPE_ADDED` | Phase 1 | 2 | Boolean — true nếu Phase 1 đã append module mới |
| `$CURRENT_PHASE` | Mọi phase | Resume | Phase đang chạy — ghi vào status file sau mỗi bước |

---

## Cross-Phase Data Flow

```
Phase 0 (init)         → $STATUS_FILE, $FEATURE_COUNT_BEFORE, $EXISTING_FEATURE_IDS,
                         $EXISTING_MODULE_IDS, $LEGACY_MODE, $DEPRECATED_MODULES
Phase 1 (scope, cond.) → $MODULE_SCOPE_ADDED, registry.modules[] += module mới
Phase 2 (features)     → $NEW_FEATURE_IDS, registry.features[] += features mới
Phase 3 (design, cond.)→ $INTERFACE_TYPE, registry.design_status cập nhật
Phase 4 (ux, cond.)    → registry.ux_design_status cập nhật
Phase 5a (plan)        → phase5-implementation/P5-00-implementation-roadmap.md
Phase 5b (implement)   → registry.requirements[].impl_status = "done" per feature
Phase 6 (preflight)    → preflight-report.md (PASS/WARN/FAIL)
Phase 7 (verify)       → verify-sync.md + final report
```

**Quy tắc:** mỗi phase chỉ READ biến đã được SET ở phase trước. POST-GATE của phase N
cập nhật `$STATUS_FILE.phases_completed[]` hoặc `phases_skipped[]` + `current_phase = phase[N+1]`.

---

## Status File Schema

**Path:** `.mc-data/work/feature-addition/feature-addition-status.json`

```json
{
  "started_at": "ISO-8601 timestamp",
  "updated_at": "ISO-8601 timestamp",
  "feature_name": "tên feature từ argument (hoặc null)",
  "feature_count_before": 5,
  "existing_feature_ids": ["FEAT-001", "FEAT-002"],
  "existing_module_ids": ["MOD-001", "MOD-002"],
  "new_feature_ids": [],
  "current_phase": "phase0",
  "phases_completed": [],
  "phases_skipped": [],
  "interface_type": null,
  "legacy_mode": false,
  "deprecated_modules": [],
  "module_scope_added": false,
  "phase2_zero_feature_override": false,
  "phase5b_all_skipped": false
}
```

**Hợp lệ của `current_phase`:** `"phase0" | "phase1" | "phase2" | "phase3" | "phase4" | "phase5a" | "phase5b" | "preflight" | "verify" | "completed"`.

**Các fields mở rộng:**
- `phase2_zero_feature_override`: `true` khi user chọn "force-continue" sau khi Phase 2 tạo 0 features — phục vụ audit.
- `phase5b_all_skipped`: `true` khi user skip toàn bộ features trong vòng lặp 5b — để final report hiển thị ⏭ thay vì ✅.

> **Schema reference:** feature-addition mở rộng custom schema so với `.claude/skills/schemas/status-file-schema.json` — thêm `feature_count_before`, `existing_feature_ids`, `existing_module_ids`, `new_feature_ids`, `legacy_mode`, `deprecated_modules`, `module_scope_added`, `phase2_zero_feature_override`, `phase5b_all_skipped`.

---

## LEGACY_MODE Detection

> Theo CORE-021, chỉ detect bằng `project-context.md > 500 bytes`. KHÔNG dùng ledger.json.

```bash
LEGACY_MODE=false
DEPRECATED_MODULES="[]"

if test -f .mc-data/work/legacy-scan/project-context.md \
   && test "$(wc -c < .mc-data/work/legacy-scan/project-context.md)" -gt 500; then
  LEGACY_MODE=true

  # Đọc legacy-decisions.json (CORE-022)
  if test -f .mc-data/work/wf-brainstorm/legacy-decisions.json; then
    DEPRECATED_MODULES=$(jq -c '[.modules[] | select(.action=="DEPRECATE") | .id]' \
      .mc-data/work/wf-brainstorm/legacy-decisions.json)
  else
    echo "WARNING: legacy-decisions.json không tồn tại — tiếp tục với DEPRECATED_MODULES=[]"
  fi
fi
```

Ghi vào status file: `legacy_mode`, `deprecated_modules`.

---

## Lock File Mechanism

> Ngăn chặn hai phiên `/feature-addition` chạy đồng thời trên cùng project, tránh registry corruption và duplicate implementation.

**Path:** `.mc-data/work/feature-addition/.lock`

### Tạo lock (Phase 0, Step 0.0)

```bash
mkdir -p .mc-data/work/feature-addition/
echo "$(date +%s)" > .mc-data/work/feature-addition/.lock
```

### Xóa lock

Lock được xóa trong các trường hợp sau:

| Trường hợp | Hành động |
|-----------|-----------|
| Phase 7 hoàn thành (`current_phase = "completed"`) | Xóa `.lock` |
| E001 hoặc E002 STOP ở PRE-GATE | Xóa `.lock` (session không bắt đầu) |
| User cancel tại overview (Phase 0 hỏi yes/no → no) | Xóa `.lock` |

> Các error codes E003–E015 **giữ nguyên lock** — cho phép user dùng `--resume` để tiếp tục. Lock chỉ bị xóa khi workflow hoàn toàn kết thúc hoặc chưa bắt đầu.

### Kiểm tra lock khi khởi động

```bash
LOCK_FILE=".mc-data/work/feature-addition/.lock"
if test -f "$LOCK_FILE"; then
  LOCK_TS=$(cat "$LOCK_FILE" | grep -o '[0-9]*' | head -1)
  NOW_TS=$(date +%s)
  LOCK_AGE=$(( NOW_TS - ${LOCK_TS:-0} ))
  if [ "$LOCK_AGE" -lt 7200 ]; then   # < 2 giờ: có thể đang chạy
    # Hiển thị cảnh báo, hỏi user (xem phase0-init.md §PRE-GATE)
    echo "⚠ Lock file phát hiện (${LOCK_AGE}s trước). Tiếp tục? (yes/no)"
  else
    # Lock cũ (> 2 giờ): tự động xóa, tiếp tục bình thường
    rm -f "$LOCK_FILE"
  fi
fi
```

---

## Fix Rules

| Error Type | Auto-Fix Strategy | Escalate If |
|-----------|-------------------|-------------|
| Feature trùng tên trong registry | Đổi tên thêm suffix (v2, extended) | User xác nhận tên mới |
| POST-GATE Phase 2 fail | Re-check registry, retry wf-define-features | 3 lần vẫn fail |
| `interface_type` không xác định | Default `"web+mobile"` | Giá trị bất thường |
| `impl_status` không chuyển `"done"` | Retry wf-implement-feature | User chọn skip |
| Sub-skill SKILL.md thiếu | — | Luôn escalate — không auto-fix |
| Module mới cần thêm nhưng wf-add-scope fail | Retry wf-add-scope | User chọn skip module mới hoặc manual add |
| Status file corrupt | Rebuild từ registry + phase2 docs (E012 flow) | Không xác định được → hỏi user |
| `jq` không khả dụng | Dùng python fallback (E005) | Python cũng không có |

---

## Resume Protocol

Khi có flag `--resume`:

```
1. READ $STATUS_FILE
2. VALIDATE current_phase ∈ {phase0, phase1, phase2, phase3, phase4, phase5a, phase5b, preflight, verify, completed}
   Nếu invalid → STOP: "current_phase không hợp lệ. Dùng --from-phase để override."
3. LOAD context: new_feature_ids, phases_completed, phases_skipped, legacy_mode, deprecated_modules
4. CROSS-VALIDATE với file system:
   Phase 1  : module_scope_added == true HOẶC "phase1" in phases_skipped
   Phase 2  : new_feature_ids.length > 0
   Phase 3  : "phase3" in phases_completed HOẶC phases_skipped
   Phase 4  : "phase4" in phases_completed HOẶC phases_skipped
   Phase 5a : test -f .mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md
   Phase 5b : impl_status của từng feature trong new_feature_ids (registry là SSOT)
   Preflight: test -f .mc-data/work/wf-preflight/preflight-report.md
   Verify   : test -f .mc-data/docs/_meta/verify-sync.md

4b. RE-VALIDATE new_feature_ids từ registry (chống lost-update):
    Nếu "phase2" ∈ phases_completed:
      CURRENT_REGISTRY_COUNT = jq '.features | length' registry.json
      EXPECTED_COUNT = feature_count_before + new_feature_ids.length
      Nếu CURRENT_REGISTRY_COUNT != EXPECTED_COUNT:
        → Tính lại: new_feature_ids_recalc = (current registry feature ids) - existing_feature_ids
        → Hiển thị: "ℹ new_feature_ids được tính lại từ registry (phát hiện drift):"
          "  Trước: [STATUS_FILE list]"
          "  Sau:   [recalculated list]"
        → Hỏi user xác nhận trước khi ghi lại vào STATUS_FILE
        → Nếu confirmed: cập nhật STATUS_FILE.new_feature_ids = recalculated

4c. RE-VALIDATE legacy-decisions.json (chống stale deprecated_modules):
    Nếu legacy_mode == true VÀ test -f legacy-decisions.json:
      CURRENT_DEPRECATED=$(jq -c '[.modules[] | select(.action=="DEPRECATE") | .id]' legacy-decisions.json)
      Nếu CURRENT_DEPRECATED != STATUS_FILE.deprecated_modules:
        → Cập nhật STATUS_FILE.deprecated_modules = CURRENT_DEPRECATED
        → Hiển thị: "ℹ Danh sách modules ngưng dùng đã được cập nhật từ legacy-decisions.json"

5. HIỂN THỊ progress dashboard (ký hiệu ✅/⏭/⏳/⬜)
   Format: "[ký hiệu] Phase [tên]: [trạng thái]"
   Bao gồm: số features đã/chưa implement, thời gian bắt đầu
6. HỎI user xác nhận trước khi tiếp tục từ current_phase
7. JUMP tới phase tương ứng (xem mapping phía dưới)
```

**Status file bị mất/corrupt (E012 fallback):**
```
1. READ registry → lấy features[].id hiện tại
2. Glob .mc-data/docs/phase2-features/**/*.md (lấy theo modified date)
3. Xác định new_feature_ids = features trong registry + có file phase2 docs
   NHƯNG không có trong phase5-implementation/tasks/ trước started_at (nếu có)
4. Re-validate legacy-decisions.json nếu LEGACY_MODE (bước 4c)
5. Fallback cuối: hiển thị danh sách, hỏi user xác nhận
```

---

## `--from-phase` Mapping

| Giá trị | Nhảy đến | Prerequisite cần | Cross-validation bắt buộc |
|---------|----------|------------------|--------------------------|
| `1` | phase1-scope.md | Phase 0 context loaded | Không cần |
| `2` | phase2-features.md | Phase 1 xong/skip | Không cần |
| `3` | phase3-design.md | Phase 2 — new_feature_ids > 0 | Re-validate `new_feature_ids` từ registry (bước 4b) |
| `4` | phase4-ux.md | Phase 3 xong/skip | Re-validate `new_feature_ids` từ registry |
| `5a` | phase5a-plan.md | Phase 4 xong/skip | Re-validate `new_feature_ids` từ registry |
| `5b` | phase5b-implement.md | Phase 5a: roadmap file tồn tại VÀ `new_feature_ids.length > 0` | Re-validate `new_feature_ids` + verify roadmap content (không chỉ existence) |
| `preflight` | phase6-preflight.md | ≥1 feature đã implement HOẶC `phase5b_all_skipped == true` | Không cần |
| `verify` | phase7-verify.md | Preflight completed (hoặc user confirm sau WARN) | Không cần |

**Giá trị không hợp lệ:** báo lỗi `E010` — "Giá trị --from-phase không hợp lệ. Các giá trị chấp nhận: 1, 2, 3, 4, 5a, 5b, preflight, verify."

**Quy trình khi `--from-phase` được dùng:**

```
1. Phase 0 vẫn chạy đầy đủ (PRE-GATE + Steps 0.0-0.6)
2. Nếu STATUS_FILE tồn tại → load context (new_feature_ids, feature_count_before, ...)
3. Áp dụng cross-validation tương ứng với phase đích (xem cột phải)
   - Re-validate new_feature_ids: So sánh STATUS_FILE.new_feature_ids với registry thực tế
     RECALC = (current registry feature ids) - existing_feature_ids
     Nếu khác → hỏi user xác nhận trước khi dùng giá trị nào
4. Hiển thị progress dashboard → nhảy đến phase được chỉ định
```

> **Lý do cross-validate:** Khi dùng `--from-phase`, STATUS_FILE có thể có `new_feature_ids` stale (lost-update, registry bị ghi bởi session khác, v.v.). Các phases 3+ phụ thuộc vào list này để biết feature nào cần xử lý.

---

## Error Handling Reference

| Code | Tình huống | Xử lý |
|------|-----------|--------|
| E001 | PRE-GATE fail: thiếu `phase3-architecture` | STOP → "Dự án chưa có architecture. Dùng `/new-project` hoặc `/existing-project` trước." + xóa lock file |
| E002 | PRE-GATE fail: thiếu hoặc `req-registry.json` không hợp lệ | STOP → "Registry không tồn tại hoặc không hợp lệ. Chạy `/wf-analyze-requirements` trước." + xóa lock file |
| E003 | POST-GATE fail sau 3 lần retry | STOP phase → hiển thị lệnh fail, hỏi user cách xử lý |
| E004 | Sub-skill `SKILL.md` không tồn tại | STOP → báo path thiếu, dừng workflow |
| E005 | `jq` không khả dụng | Fallback: `python -c "import json; d=json.load(open('.mc-data/docs/_meta/req-registry.json')); print(d.get('interface_type','web+mobile'))"` |
| E006 | Không có feature nào chưa implement | Thông báo: "Tất cả features đã implement." → skip Phase 5b, chuyển thẳng sang Preflight |
| E007 | Implement feature bị gián đoạn (user dừng) | Lưu checkpoint → "Dùng `/feature-addition --resume` để tiếp tục." |
| E008 | wf-implement-feature POST-GATE fail | Hỏi user: skip feature này hay retry? |
| E009 | wf-verify-sync POST-GATE fail | Retry tối đa 2 lần; nếu vẫn fail → WARNING, cho phép tiếp tục sau xác nhận |
| E010 | `--from-phase` giá trị không hợp lệ | Hiển thị bảng mapping, yêu cầu user chọn lại |
| E011 | Context overflow (>80%) | Lưu checkpoint ngay, thông báo resume |
| E012 | Status file bị mất/corrupt | Rebuild theo fallback (xem Resume Protocol) |
| E013 | Module mục tiêu nằm trong deprecated list | STOP → "Module [name] đã bị DEPRECATE. Không thêm features vào module này." |
| E014 | wf-add-scope fail (module mới) | STOP → hiển thị lỗi, hỏi user: thử lại / skip module mới / manual add |
| E015 | Preflight FAIL | Hiển thị errors, gợi ý `/wf-fix-bugs` trước khi Verify |

---

## Context & Checkpoint

| Context Usage | Hành động |
|---------------|-----------|
| < 65% | Tiếp tục bình thường |
| 65–80% | Chuẩn bị checkpoint |
| 80–90% | Lưu checkpoint ngay |
| > 90% | FORCE STOP — checkpoint bắt buộc |

Checkpoint = cập nhật `$STATUS_FILE` (tối thiểu `current_phase`, `phases_completed`, `updated_at`).

---

## Sub-Skill Invocation Pattern

Mọi phase delegate đến sub-skill theo pattern chung:

```
1. Hiển thị: `▶ Phase N: [tiêu đề]`
2. VERIFY .claude/skills/workflow/[sub-skill]/SKILL.md tồn tại (Read → nếu fail → E004)
3. Gọi Skill("[sub-skill]", args=<nếu có>)
4. Đợi sub-skill hoàn thành POST-GATE của chính nó
5. Chạy POST-GATE của phase này (đặc thù per phase file)
6. Cập nhật $STATUS_FILE: phases_completed += phase-id, current_phase = phase kế
7. Transition message: `✅ Phase N hoàn thành` → hỏi user xác nhận tiếp tục (trừ loop 5b)
```

**Luật retry:** nếu POST-GATE của phase fail → retry sub-skill tối đa 3 lần → E003 nếu vẫn fail.
