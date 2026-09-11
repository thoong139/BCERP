# Phase 8b: Final Cross-Validation (AUTO-CORRECTION LOOP)

> Kiểm tra toàn diện: registry nhất quán với docs đã tạo. Tối đa 3 iterations.
> **Auto-Correction:** Xem `.claude/skills/protocols/`

**PRE-GATE:** `jq '.' .mc-data/docs/_meta/req-registry.json` succeeds (Phase 8 POST-GATE PASS)

**INPUT:** Registry + tất cả `[dept].md` files + `.mc-data/work/wf-analyze-requirements/deferred-issues.md` + analyze-report

**OUTPUT (auto-fix):** Registry, dept docs (nếu cần fix) + `.mc-data/work/wf-analyze-requirements/analyze-report-[date].md` (append log)

## Validation Checks (mỗi iteration)

| Check | Action | Khi FAIL → Auto-Fix |
| ----- | ------ | ------------------- |
| 8b.1  | Verify: mỗi REQ-ID trong registry → `primary_module` tham chiếu module_id hợp lệ trong `modules[]`; và `dept` tham chiếu department_id hợp lệ trong `departments[]` | Fix dept/primary_module value trong registry |
| 8b.2  | Verify: mỗi REQ-ID trong dept docs → có trong registry | Thêm missing REQ-ID vào registry |
| 8b.3  | Verify: `deferred-issues.md` **KHÔNG chứa items severity KHẨN CẤP** (đã phải resolve ở Phase 6d.5). **Nếu file không tồn tại** (scope=business/module skip Phase 6d) → SKIP check này | Nếu có KHẨN CẤP trong deferred → **FAIL — quay lại Phase 6d.5 chạy BLOCKING-RESOLVE**. Items TRUNG BÌNH/NHỎ → OK (defer cho phase sau) |
| 8b.3b | Verify: `stakeholder-review.md` Phần E (AI Decision Records) tồn tại nếu có BLOCKING-RESOLVED items ở Phase 6d | Nếu thiếu Phần E → tạo từ Phase 6d output |
| 8b.4  | Verify: registry JSON valid (`jq '.'` pass) | Fix JSON syntax |
| 8b.5  | Verify: không có duplicate REQ-IDs | Remove duplicates, keep latest |
| 8b.6  | Verify: tất cả dept docs không có placeholders (TODO/TBD) | Fill placeholders từ context |
| 8b.7  | Verify: REQ-ID traceability — mỗi REQ-ID phải trace back đến user input hoặc P0 brainstorm. REQ-IDs chỉ có trong dept docs mà KHÔNG có anchor trong P0/user input → FLAG as hallucinated | Xóa REQ-ID khỏi docs + registry, log warning |
| 8b.8  | **Per-system coverage re-check (BẮT BUỘC):** `jq -e '[.systems[] \| select(.phase == "MVP")] as $mvp \| ([.requirements[].systems[]?] \| unique) as $cov \| all($mvp[]; . as $s \| ($cov \| index($s.id)))' registry.json`. Nếu FAIL → identify systems thiếu coverage → log "System {id} (MVP) thiếu requirements" → Auto-Fix: spawn BA re-run cho departments trong `systems[id].related_departments[]` để bổ sung requirements. | 100% MVP systems có ≥ 1 REQ |
| 8b.9  | **Multi-touchpoint cross-check:** Với mỗi REQ thuộc department multi-system (vd DEPT-CX phục vụ web-customer + mobile-customer), kiểm tra `systems[]` có chứa tất cả multi-touchpoint systems tương ứng không. Nếu REQ chỉ có 1 system trong khi dept phục vụ 2+ → WARNING: "REQ {id} có thể miss fan-out — BA nên xác nhận là chỉ áp dụng cho 1 system hay phải mở rộng". | WARNINGS logged, không block |

## Fix Rules cho Phase 8b

Xem `_shared.md §Fix Rules` — bao gồm `missing_file`, `missing_registry_entry`, `duplicate_id`, `invalid_json`, `placeholder_found`, `pending_deferred`, `missing_decision_record`, `hallucinated_req`.

## Steps (per iteration)

| Step | Action | Verify |
| ---- | ------ | ------ |
| 8b.9  | Log validation results vào `.mc-data/work/wf-analyze-requirements/analyze-report-[date].md` (mỗi iteration) | Report updated |
| 8b.10 | Ghi tổng kết: iterations count, errors fixed, errors remaining | Summary logged |

## Auto-Correction Loop

- Chạy toàn bộ checks (8b.1 → 8b.7)
- Nếu có FAIL → apply auto-fix theo Fix Rules
- Re-run validation
- Repeat tối đa 3 iterations
- Nếu sau iteration 3 vẫn còn errors → **E013** escalate với context

**POST-GATE:** Zero validation errors (tất cả checks PASS) HOẶC user acknowledged remaining errors

**Status update:** `analyze-status.json` → `phase_8b.status = "completed"`, `phase_8b.iterations = <N>`, `phase_8b.errors_fixed = <N>`.

**Next phase:** `phase8c-handoff.md`
