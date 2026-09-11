# Audit Skill Output Report

> **Ngày:** [YYYY-MM-DD]
> **Skill:** [skill-name]
> **Project:** [tên dự án từ brainstorm]
> **Dự án phase:** [Phase N]
> **Verdict:** [PASS | PASS_WITH_WARN | FAIL]
> **Dimensions kiểm tra:** [N] / 7 (skipped: [danh sách nếu có])

---

## Tóm Tắt

| Metric | Giá trị |
|--------|---------|
| Dimensions kiểm tra | [N] / 7 |
| Tổng checks | [N] |
| PASS | [N] |
| WARN | [N] |
| FAIL | [N] |
| Content Score (D4) | [0-100 hoặc N/A] |
| Auto-fix applied | [N] |
| **Verdict** | [PASS / PASS_WITH_WARN / FAIL] |

> **Verdict dựa trên [N]/7 dimensions.** [Nếu có dimension bị skip: "D4, D5 bị skip — xem ghi chú bên dưới."]

---

## Chi Tiết theo Dimension

### D1: File Existence & Completeness

| # | Check | File/Target | Kết quả | Ghi chú |
|---|-------|-------------|---------|---------|
| D1.1 | File tồn tại | [path] | PASS/FAIL/WARN | [chi tiết] |
| D1.2 | Non-empty | [path] | PASS/FAIL | |
| D1.3 | Status file | `.mc-data/work/[skill]/` | PASS/FAIL | |
| D1.4 | Report file | [path] | PASS/FAIL | |
| D1.5 | Stakeholder review | [path] | PASS/FAIL/N/A | |

### D2: Template Compliance

> Sections populate dynamically từ `_contract.json` — không hardcode.

| # | Check | File | Kết quả | Chi tiết |
|---|-------|------|---------|----------|
| D2.0 | Contract loaded | `_contract.json` | PASS/FAIL/WARN | [phase contract path] |
| D2.1 | Required section: [từ contract] | [file] | PASS/FAIL | [section name] |
| D2.2 | Required section: [từ contract] | [file] | PASS/FAIL | [section name] |
| D2.3 | Metadata (READS/USED BY) | [file] | PASS/WARN/N/A | |
| D2.4 | Không còn placeholder/TODO/TBD | [file] | PASS/WARN | |

### D3: Registry Schema Validation

| # | Check | Field/Entry | Kết quả | Chi tiết |
|---|-------|-------------|---------|----------|
| D3.1 | JSON valid | req-registry.json | PASS/FAIL | |
| D3.2 | Safe-Write fields | [skill fields] | PASS/FAIL | |
| D3.3 | Field names đúng schema | [fields] | PASS/FAIL | |
| D3.4 | Field types đúng | [fields] | PASS/FAIL | |
| D3.5 | Required fields tồn tại | [fields] | PASS/FAIL | |
| D3.6 | Không duplicate entries | [count] | PASS/FAIL | |
| D3.7 | Count khớp (registry = files) | [N] vs [N] | PASS/FAIL/WARN/N/A | [exact/partial/SKIP] |

### D4: Content Quality

| Dimension | Score | Verdict | Chi tiết |
|-----------|-------|---------|----------|
| Completeness | [0-40] | PASS/WARN/FAIL | |
| Consistency | [0-30] | PASS/WARN/FAIL | |
| Traceability | [0-20] | PASS/WARN/FAIL | |
| Coherence | [0-10] | PASS/WARN/FAIL | |
| **Tổng** | **[0-100]** | | |

> [Nếu skip: "D4 bị skip — [lý do]. Recommend: chạy lại với --dimension=D4"]

### D5: Cross-Phase Consistency

| # | Check | Expected | Actual | Kết quả |
|---|-------|----------|--------|---------|
| D5.1 | Count khớp (modules/features/REQ-IDs) | [N] | [N] | PASS/FAIL |
| D5.2 | Tên khớp (case-insensitive) | — | — | PASS/WARN |
| D5.3 | Scope guard (không mở rộng) | — | — | PASS/FAIL |
| D5.4 | Cross-refs path đúng | — | — | PASS/WARN |
| D5.5 | Deferred findings integrated | — | — | PASS/WARN/N/A |

> [Nếu skip: "D5 bị skip — [lý do]. Recommend: chạy lại với --dimension=D5"]

### D6: POST-GATE Re-execution

| # | Gate Check | Command | Kết quả | Expected |
|---|-----------|---------|---------|----------|
| D6.1 | [check từ SKILL.md] | `[command]` | PASS/FAIL | [expected] |
| D6.2 | File existence | `test -f [path]` | PASS/FAIL | file exists |
| D6.3 | Non-empty | `test -s [path]` | PASS/FAIL | size > 0 |
| D6.4 | Registry valid | `jq '.'` | PASS/FAIL | valid JSON |
| D6.5 | Content check | `grep "[pattern]"` | PASS/FAIL | match found |

### D7: Status & Report Integrity

| # | Check | Kết quả | Chi tiết |
|---|-------|---------|----------|
| D7.1 | Status file có phase, status, verdict | PASS/WARN/FAIL | |
| D7.2 | Verdict phản ánh thực tế | PASS/FAIL | |
| D7.3 | Report có error_log[] | PASS/WARN/N/A | |
| D7.4 | Report có output summary | PASS/WARN | |
| D7.5 | Timestamps hợp lệ | PASS/WARN | |

### D8: Master Plan Compliance (OPTIONAL)

> **Chỉ khi Master Plan enabled.** Nếu không enabled → ghi "D8: SKIP — Master Plan không enabled".

| # | Check | Skill áp dụng | Kết quả | Chi tiết |
|---|-------|---------------|---------|----------|
| D8.1 | project-digest.json tồn tại | wf-brainstorm | PASS/FAIL/SKIP | |
| D8.2 | project-digest.json required fields | wf-brainstorm | PASS/FAIL/SKIP | |
| D8.3 | dept-digests.json tồn tại | wf-analyze-req | PASS/FAIL/SKIP | |
| D8.4 | dept-digests.json required fields | wf-analyze-req | PASS/FAIL/SKIP | |
| D8.5 | phase1-handoff.json tồn tại | wf-analyze-req | PASS/FAIL/SKIP | |
| D8.6 | phase1-handoff.json required fields | wf-analyze-req | PASS/FAIL/SKIP | |
| D8.7 | feature-briefs.json tồn tại | wf-define-features | PASS/FAIL/SKIP | |
| D8.8 | feature-briefs.json required fields | wf-define-features | PASS/FAIL/SKIP | |
| D8.9 | design-input-digest.json tồn tại | wf-design | PASS/FAIL/SKIP | |
| D8.10 | design-input-digest.json required fields | wf-design | PASS/FAIL/SKIP | |
| D8.11 | ux-input-digest.json tồn tại | wf-design-ux | PASS/FAIL/SKIP | |
| D8.12 | ux-input-digest.json required fields | wf-design-ux | PASS/FAIL/SKIP | |
| D8.13 | Task files có A6-EXT section | wf-plan-modules | PASS/FAIL/SKIP | |
| D8.14 | A6-EXT có file paths, REQ-IDs, methods, test cases | wf-plan-modules | PASS/FAIL/SKIP | |
| D8.15 | Task files có A7-EXT section (nếu >=3 files) | wf-plan-modules | PASS/FAIL/SKIP | |
| D8.16 | A7-EXT micro-tasks có MT-* id, estimated_time <= 15min | wf-plan-modules | PASS/FAIL/SKIP | |
| D8.17 | Checkpoint có context_digest object | wf-implement-feature | PASS/FAIL/SKIP | |
| D8.18 | context_digest có đủ 6 subfields | wf-implement-feature | PASS/FAIL/SKIP | |

---

## Hành Động Cần Thiết

### CRITICAL — Fix ngay trước khi tiếp tục workflow

| # | Vấn đề | Dimension | File | Đề xuất fix |
|---|--------|-----------|------|-------------|
| — | *(không có)* | — | — | — |

### MAJOR — Fix trước khi chuyển sang phase tiếp theo

| # | Vấn đề | Dimension | File | Đề xuất fix |
|---|--------|-----------|------|-------------|
| — | *(không có)* | — | — | — |

### MINOR — Backlog / cải thiện

| # | Vấn đề | Dimension | File | Đề xuất fix |
|---|--------|-----------|------|-------------|
| — | *(không có)* | — | — | — |

---

## Fix Results (auto-fix)

| # | Vấn đề gốc | Fix Applied | Kết quả sau fix |
|---|-----------|-------------|-----------------|
| — | *(không có fix)* | — | — |

---

## Đề Xuất Cải Thiện Skill

> Những phát hiện có thể giúp cải thiện SKILL.md thiết kế:

| # | Khu vực | Phát hiện | Đề xuất cho SKILL.md |
|---|---------|-----------|---------------------|
| — | *(không có)* | — | — |
