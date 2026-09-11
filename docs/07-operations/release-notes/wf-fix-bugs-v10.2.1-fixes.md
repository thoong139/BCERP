# wf-fix-bugs v10.2.1 — Tổng hợp sửa lỗi

**Ngày phát hành:** 2026-05-14
**Phiên bản trước:** v10.2.0 (2026-05-14, cùng ngày)
**Loại bản phát hành:** Patch — sửa lỗi pipeline broken phát hiện qua audit toàn diện

---

## Vì sao có v10.2.1

v10.2.0 hoàn thành 6 sprint UI coverage (BASE_URL conflict, disabled CTA check, multi-session notes) và pass compliance audit (12/12 CRITICAL). Tuy nhiên audit toàn diện ngay sau khi release phát hiện **8 vấn đề pipeline broken** + **6 data integrity gap** chưa được phát hiện vì v10.2 chỉ chạy structural audit, KHÔNG chạy end-to-end test thực tế.

v10.2.1 sửa toàn bộ các vấn đề này — pipeline có thể chạy từ Phase 1 đến Phase 7 mà không bị đứt ở handoff.

---

## Hành vi mục tiêu — không thay đổi

| Hành vi | v10.2.0 | v10.2.1 |
|---------|---------|---------|
| 7-phase pipeline (Init → Verify) | ✅ | ✅ |
| 11 lane dimension (QD1-QD11) | ✅ | ✅ |
| CI-first GitNexus + Serena | ✅ | ✅ |
| Playwright 3 modes (headless/visible/mobile) | ✅ | ✅ |
| Multi-session safety + BASE_URL conflict | ✅ | ✅ |
| Resume/Status/Migrate dispatch | ✅ | ✅ |
| Cross-skill artifact `fix-impact.json` | ✅ | ✅ (sửa schema field) |

**Tuyên bố:** Không có hành vi mục tiêu nào bị thay đổi. v10.2.1 chỉ là sửa lỗi runtime + đồng bộ data contract.

---

## 8 fix CRITICAL — Pipeline không bị đứt

| # | Vấn đề trước v10.2.1 | Fix |
|---|----------------------|------|
| P1.1 | `SOURCE_VALID` chỉ set `false` (else), không set `true` ở success branch → Phase 2 PRE-GATE luôn fail | `phase1-init.md:483` — thêm `SOURCE_VALID=true` ở cả 2 success branch (src/, apps/) |
| P1.2 | Phase 2 POST-GATE T2 check `.modules and .total_files` (flat) — JSON là `.code.total_files` (nested) → luôn fail | `phase2-scan.md:811` — đổi sang `.interface_type and .scope and .code and .docs` |
| P1.3 | Phase 3 POST-GATE T4 chạy `(.dimensions \| keys)` trên work-plan.json (key này ở dimension-plan.json) → `null == array = false` | `phase3-plan.md:1050-1053` — cross-file check 2 file riêng biệt |
| P1.4 | Phase 4 DIMS_ARRAY format `"QD1\|Functional Correctness"` → bash word-split phá vỡ tên có space | `phase4-find-bugs.md:121-127` — slug-hóa: `QD1-functional-correctness` (path-safe, no space) |
| P1.5 | Phase 4 Step 4.9 đọc `Phase4-report.md.aggregate.json` không tồn tại → `SIGNALS_TOTAL` empty | `phase4-find-bugs.md:773-787` — tính SIGNALS_TOTAL bằng vòng lặp lanes/$dim/{stream}/signals.json |
| P1.6 | Phase 5 set `reason="E005"` nhưng KHÔNG set `e005_healthy=true` → Phase 7 check `e005_healthy == true` luôn false → route sai khi N=0 healthy | `phase5-triage.md:110` — thêm `e005_healthy: true` vào jq update cho cả phase5 và phase6 |
| P1.7 | Phase 5 Step 5.9 ghi cdg-tokens.json bằng `>>` flat append → file JSON invalid sau lần CDG thứ 2. Phase 6 đọc `[.tokens[]]` (object) — schema không khớp | `phase5-triage.md:564-575` — APPEND vào mảng `.tokens[]` bằng jq atomic write, thêm field `status` để Phase 6 PRE-GATE check |
| P1.8 | fix-impact.json template thiếu `$schema` field → 3 consumer skills (wf-verify-sync, wf-prepare-deployment, wf-implement-feature) validate `jq -e '."$schema" == "fix-impact-v1"'` luôn fail silent → cross-skill validation bị skip | `templates/phase7-verify/fix-impact.json` — thêm `"$schema": "fix-impact-v1"` + `audit_chain.source` field |

---

## 6 fix DATA INTEGRITY — Cross-skill consumer

| # | Vấn đề | Fix |
|---|--------|-----|
| P2.1 | QD9 `dimension.json §exit_criteria.standard` chỉ có 3 probes — SKILL.md v10.2 hứa 6 probes (3 core + 3 promote) | `wf-fix-runtime-health/dimension.json` — `standard.probes_required` mở rộng thành 6 probes (thêm interactive-smoke, spa-route-coverage, disabled-cta-check) |
| P2.2 | `dimension.json §execution_order` thiếu `P-QD9-disabled-cta-check` → probe mới không được thực thi | dimension.json — insert disabled-cta-check vào execution_order + parallel_groups |
| P2.3 | `wf-fix-runtime-health/_contract.json` version vẫn 1.0.0, procedure[] thiếu probe mới | _contract.json — bump version `1.0.0 → 1.1.0`, thêm probe mới vào procedure[], cập nhật description |
| P2.4 | fix-status.json template thiếu `project_name` field → lane-agent-prompt substitution `{{PROJECT_NAME}}` fail | `templates/phase1-init/fix-status.json` — thêm `"project_name": "{{PROJECT_NAME}}"` + Phase 1 Step 1.19 populate từ env/registry/basename |
| P2.5 | scope-analysis.json template flat (.modules, .total_files) — Phase 2 write nested (.code.total_files) → mismatch + thiếu source_dir field | `templates/phase2-scan/scope-analysis.json` — restructure nested + thêm `source_dir` + Phase 2 Step 2.6 populate |
| P2.6 | fix-impact schema mâu thuẫn: template ghi v1, contract notes ghi v2, 3 consumers check v1 | _contract.json — đồng nhất sang fix-impact-v1, ghi rõ trong notes |

---

## v10.2 wire completion

| Gap | Fix |
|-----|-----|
| `lane-agent-prompt.md` orphan trong _contract.json | _contract.json `outputs.working[]` — thêm entry với schema lane-agent-prompt-v10.2, ghi rõ render qua substitution, KHÔNG ghi ra file |
| `fix-execution-result.json` orphan | _contract.json — thêm entry với schema fix-execution-result-v1, owner=wf-fix-execute |
| E090b error code v10.2 chưa register | _contract.json `errors` — thêm E090b với mô tả đầy đủ + bypass env var |

---

## Cách upgrade từ v10.2.0 → v10.2.1

**Không có breaking change.** Pipeline mới chạy đúng — không cần migrate session hay xoá data cũ.

### Cho session đang chạy

Nếu bạn đang có session v10.2.0 ở giữa pipeline:
1. **Phase 1-3 đã complete:** Tiếp tục bình thường — không bị ảnh hưởng
2. **Phase 4-7 đang chạy hoặc fail:** Khuyến nghị `--resume` để pipeline áp dụng các fix mới

### Cho session mới

Chạy `/wf-fix-bugs ...` bình thường — pipeline tự động dùng v10.2.1 logic.

### Nếu pipeline trước đó fail tại POST-GATE Phase 2 hoặc Phase 3

Đây là bug v10.2.0 đã được sửa ở v10.2.1. Chạy lại session mới hoặc `--resume`.

---

## Validation đã chạy

- `jq` validation toàn bộ JSON templates: PASS
- POST-GATE T1-T4 cross-check: PASS cho Phase 2, Phase 3
- QD9 dimension.json: standard=6 probes, execution_order=9 probes, procedure[]=11 entries
- cdg-tokens.json schema: object với `.tokens[]` array — consumer-compatible
- fix-impact.json `$schema` field: present và match consumers

---

## Tham chiếu

- Audit report 2026-05-14 (4 subagent: workflow-auditor, template-auditor, skill-auditor, cross-reference-auditor)
- CHANGELOG.md entry v10.2.1
- Plan tham khảo `plans/wf-fix-bugs-v10.2-ui-coverage/` (v10.2.0 baseline)
