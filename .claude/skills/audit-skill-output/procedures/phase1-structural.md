# Phase 1 — Structural Audit (Main Agent)

> Dimensions tool-based: D1 + D2 + D3 + D6 + D7 + D8 (nếu enabled). Main agent chạy trực tiếp — context cost thấp, accuracy cao.

**PRE-GATE:** Phase 0 completed, `skill_spec` loaded, `master_plan_enabled` detected.

> **`--dimension` filter:** Khi user chỉ định `--dimension=D3,D6`, Phase 1 chỉ chạy các mục liên quan:
> - D1/D2 trong filter → chạy mục "D1 + D2"
> - D3 → chạy mục "D3"
> - D6 → chạy mục "D6"
> - D7 → chạy mục "D7"
> - D8 → chạy mục "D8" (vẫn cần `master_plan_enabled`)
> - Mục không thuộc filter → SKIP hoàn toàn
> - Bước Aggregate (cuối Phase 1) LUÔN chạy — chỉ aggregate các dimensions đã chạy

---

## D1 + D2: File Existence & Template Compliance

| Step | Action | Tool | Verify |
| ---- | ------ | ---- | ------ |
| 1.1 | **D1:** Glob tất cả expected output files từ skill_spec | Glob | files_found[] |
| 1.2 | So sánh files_found vs expected → log MISSING | — | d1_results[] |
| 1.3 | Kiểm tra mỗi file found có size > 0 | Bash (`test -s`) | empty_files[] |
| 1.4 | **D2.0:** Đọc `_contract.json` cho phase tương ứng: `.claude/doc-framework/[phase]/_contract.json` (mapping xem `_shared.md §4`) | Read | contract_loaded |
| 1.5 | Nếu không có contract → log WARNING + fallback mode (grep "## Phan A/B/C/D" trong stakeholder-review) | — | fallback_flag |
| 1.6 | Với mỗi output file: tìm template phù hợp bằng `output_pattern` glob matching | — | template_match[] |
| 1.7 | Với mỗi matched template: Grep từng `required_section` — đúng `startswith` matching | Grep | sections_found[] |
| 1.8 | Log MISSING_SECTION cho mỗi section thiếu (severity = MAJOR default) | — | d2_results[] |
| 1.9 | Nếu `required_metadata` có READS/USED BY: kiểm tra file có dòng bắt đầu bằng `> READS:` và `> USED BY:` | Grep | metadata_found[] |
| 1.10 | Kiểm tra placeholder/TODO/TBD còn lại trong final docs | Grep (`TODO\|TBD\|PLACEHOLDER\|\[.*\]`) | placeholders[] |

**Startswith matching algorithm:**
```
contract_section = "## Phan A"
for each line in output_file_lines:
    if line.startswith(contract_section): found = True
if not found: log MISSING_SECTION(contract_section)
```

**Shared skills (legacy flow) — MULTI-PHASE D2:**
- Step 1.4 load 4 contracts lần lượt: phase0-brainstorm, phase1-business, phase2-features, phase3-architecture
- Apply D2 check cho từng nhóm files tương ứng
- `wf-design` (legacy — gap analysis) KHÔNG có contract → skip D2.0, chạy fallback (grep "## " trong gap-report.md và final-report.md)

---

## D3: Registry Schema Validation

| Step | Action | Tool | Verify |
| ---- | ------ | ---- | ------ |
| 1.11 | Validate JSON: `jq '.' .mc-data/docs/_meta/req-registry.json` | Bash | json_valid |
| 1.12 | **Field Names:** Verify không dùng alias sai | Bash (jq) | wrong_names[] |
| 1.13 | **Field Types:** Verify types đúng (number/string/array/boolean) | Bash (jq) | wrong_types[] |
| 1.14 | **Required Fields:** Verify không thiếu | Bash (jq) | missing_fields[] |
| 1.15 | **Duplicates:** Verify không trùng id | Bash (jq) | duplicates[] |
| 1.16 | **Count Match:** entries = output files (chỉ áp dụng cho skills 1:1 — xem `_shared.md §1 D3.7 table`) | — | count_match |
| 1.17 | **Safe-Write:** Skill không ghi ngoài phạm vi | Bash (jq + diff) | violations[] |

> **Schema cụ thể per skill:** Xem `_shared.md §3 Registry Schema per Skill` — có `jq` commands sẵn cho từng skill (wf-brainstorm, wf-analyze-requirements, wf-define-features, wf-design, wf-plan-modules).

---

## D6: POST-GATE Re-execution

| Step | Action | Tool | Verify |
| ---- | ------ | ---- | ------ |
| 1.18 | Extract tất cả POST-GATE checks từ SKILL.md. **Grepping-first approach:** trước khi Read toàn bộ procedure files, chạy `grep -rn "POST-GATE" .claude/skills/workflow/[skill]/procedures/*.md` để tìm files chứa POST-GATE sections. Chỉ Read các files có match. Nếu SKILL.md không có POST-GATE và grep cũng không thấy → log E005. Gộp vào `gate_checks[]`. | Grep + Read | gate_checks[] |
| 1.19 | Chạy từng check (`test -f`, `test -s`, `jq`, `grep`) | Bash | gate_results[] |
| 1.20 | So sánh kết quả vs expected → log GATE_FAIL | — | gate_failures[] |

---

## D7: Status & Report Integrity

| Step | Action | Tool | Verify |
| ---- | ------ | ---- | ------ |
| 1.21 | **D7.1:** Đọc status file, verify required fields (phase, status, verdict) | Read | status_valid |
| 1.22 | **D7.2:** So sánh status verdict với actual findings | — | verdict_accurate |
| 1.23 | **D7.3-4:** Kiểm tra report có error_log + summary section | Grep | report_checks |
| 1.24 | **D7.5:** Verify timestamps không ở tương lai | Read | timestamps_valid |

---

## D8: Master Plan Compliance (conditional)

> **Chỉ chạy khi:** `master_plan_enabled == true` VÀ (`--dimension` filter không có HOẶC có D8).
> Nếu không → SKIP toàn bộ section, ghi `d8_results = "SKIPPED"`.

| Step | Action | Tool | Verify |
| ---- | ------ | ---- | ------ |
| 1.26 | **D8 Digest checks:** Dựa trên skill đang audit, chạy checks tương ứng (xem D8 Checks per Skill bên dưới) | Bash + Read | d8_results[] |
| 1.27 | **D8 Task file checks (wf-plan-modules):** Grep `A6-EXT` và `A7-EXT` trong task files. Validate A6-EXT có file paths, REQ-IDs, methods, test cases. Validate A7-EXT micro-tasks có `MT-*` id, estimated_time ≤ 15min, input/output/success_criteria | Grep + Read | d8_task_results[] |
| 1.28 | **D8 Checkpoint checks (wf-implement-feature):** Đọc checkpoint file, kiểm tra `context_digest` có 6 subfields | Read | d8_checkpoint_results[] |

### D8 Checks per Skill

```bash
# wf-brainstorm — D8.1 + D8.2
test -s .mc-data/docs/_meta/project-digest.json && \
jq -e '.project_name and .project_summary and .departments and .interface_type and .tech_stack_summary' \
  .mc-data/docs/_meta/project-digest.json

# wf-analyze-requirements — D8.3 + D8.4 + D8.5 + D8.6
test -s .mc-data/docs/_meta/dept-digests.json && \
jq -e '.departments | length > 0 and all(has("dept_name","dept_id","key_requirements","business_rules","priority_workflows"))' \
  .mc-data/docs/_meta/dept-digests.json
test -s .mc-data/docs/_meta/phase1-handoff.json && \
jq -e '.key_decisions and .scope_boundaries' \
  .mc-data/docs/_meta/phase1-handoff.json

# wf-define-features — D8.7 + D8.8
test -s .mc-data/docs/_meta/feature-briefs.json && \
jq -e '.features | length > 0 and all(has("feature_id","name","summary","acceptance_criteria"))' \
  .mc-data/docs/_meta/feature-briefs.json
# D8.8 word count: jq '[.features[].summary | split(" ") | length | select(. > 100)] | length' → phải = 0

# wf-design — D8.9 + D8.10
test -s .mc-data/docs/_meta/design-input-digest.json && \
jq -e '.architecture_summary and .tech_stack and .api_summary' \
  .mc-data/docs/_meta/design-input-digest.json

# wf-design-ux — D8.11 + D8.12
test -s .mc-data/docs/_meta/ux-input-digest.json && \
jq -e '.design_system_summary and .navigation_structure and .responsive_strategy' \
  .mc-data/docs/_meta/ux-input-digest.json

# wf-plan-modules — D8.13 + D8.14 + D8.15 + D8.16
grep -rl "A6-EXT" .mc-data/docs/phase5-implementation/tasks/ | wc -l
# Nếu = 0 khi master_plan_enabled → FAIL D8.13
# D8.15: Chỉ check A7-EXT cho features có >= 3 files trong A6-EXT

# wf-implement-feature — D8.17 + D8.18
# Đọc .mc-data/work/wf-implement-feature/checkpoint.json
# jq -e '.context_digest' → phải tồn tại
# jq -e '.context_digest | has("feature_summary","architectural_decisions","interfaces_established","patterns_in_use","cross_batch_contracts","gotchas_and_warnings")' → true
```

---

## Aggregate

| Step | Action | Tool | Verify |
| ---- | ------ | ---- | ------ |
| 1.29 | **Aggregate** tất cả structural findings (D1+D2+D3+D6+D7+D8) | — | structural_findings[] |

## POST-GATE

- D1+D2+D3+D6+D7 (+ D8 nếu enabled) findings logged
- Structural audit hoàn tất
- Update status: `phases.phase_1.status = "completed"`, `phases.phase_1.dimensions_run`, `findings.by_dimension` (D1/D2/D3/D6/D7/D8 counts), `last_updated`

## Next

→ Nếu `--no-fix` → SKIP `phase2-autofix.md` → đi thẳng đến `phase3-semantic.md`.
→ Nếu không → READ `procedures/phase2-autofix.md` và thực thi.
