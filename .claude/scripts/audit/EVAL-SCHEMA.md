# Eval Schema — Workflow Skills

> Discovered Phiên 17 (2026-04-08) bằng cách read 16 evals.json files.
> Stats cập nhật 2026-04-10: 114 cases, 682 assertions.
> Used by `run-skill-evals.sh` (Lớp 3 — Behavioral Eval Harness).

## Top-level (per file)

```jsonc
{
  "skill_name": "wf-brainstorm",
  "evals": [ /* array of cases */ ]
}
```

- Top-level field là **`evals`** (KHÔNG phải `cases` hoặc `test_cases`).
- 16/16 files dùng cùng top-level shape.

## Per case

```jsonc
{
  "id": 1,                              // integer hoặc string
  "prompt": "user prompt for the skill",
  "expected_output": "free-form description",
  "assertions": [ /* array */ ],
  "files": []                           // optional, fixture files (mostly empty)
}
```

- 16/16 dùng `id`, `prompt`, `expected_output`, `assertions`.
- `files[]` xuất hiện ở một số skills nhưng hầu hết trống — không phải fixture seed thực sự.

## Per assertion

```jsonc
{
  "type": "file_exists",      // 1 trong 7 types (xem bên dưới)
  "text": "human-readable expectation"
}
```

- Schema **đồng nhất** giữa 16 skills: chỉ có `type` + `text`.
- KHÔNG có `expected_path`, `pattern`, `regex`, hoặc `command` field.
- → Harness phải **parse `text`** để rút thông tin (file paths, section names, ...).

## Assertion types (7 distinct, 682 total assertions across 114 cases)

| Type             | Count | Auto-checkable? | Notes                                                                 |
|------------------|-------|-----------------|-----------------------------------------------------------------------|
| `behavior`       | 366   | NO (judge)      | Yêu cầu real run + LLM judge. v1 → `skip:needs-judge`.                |
| `file_content`   | 109   | YES             | Grep pattern trong text (extract path + substring/section heading).   |
| `file_exists`    | 99    | YES             | Extract `.mc-data/...` path từ text → `test -f`.                      |
| `content_check`  | 64    | PARTIAL         | Variant của file_content nhưng text mơ hồ hơn (số liệu, format, ...). |
| `output_contains`| 24    | NO (judge)      | Cần stdout của skill thật → `skip:needs-judge`.                       |
| `structure`      |  5    | PARTIAL         | Cấu trúc JSON/MD — cần LLM hoặc regex phức tạp.                       |
| `registry_check` | 15    | YES             | Cần seed registry → check field cụ thể (impl_status invariants).      |

**Auto-checkable subtotal:** 292 / 682 = 42.8% (file_exists + file_content + content_check + structure + registry_check)
**Needs-judge subtotal:** 390 / 682 = 57.2% (behavior + output_contains)

## Path extraction heuristics (cho v1)

Trong `text` của assertion, paths thường xuất hiện theo pattern:

- Backticked: `` `.mc-data/docs/phase0-brainstorm/P0-01-brainstorm.md` ``
- Bare: `File .mc-data/docs/.../foo.md được tạo`
- Quoted: `'.mc-data/work/.../bar.json'`

Regex v1 dùng: `\.mc-data[\-a-zA-Z0-9/_\.]+\.(md|json|sh|sql|yaml|yml|ts|tsx|js|jsx)`

Section heading patterns: `'## ...'` hoặc `"## ..."` trong text → extract giữa quotes.

## Schema drift / inconsistencies

- **wf-legacy-scan** có nested objects với `id` keys (jq đếm 27 vs 17 top-level cases) — do nested expected_output có sub-items với id. Top-level case count vẫn đúng = 17.
- **wf-verify-sync** tương tự (5 cases nhưng 41 id-bearing objects) — nested assertion sub-objects.
- → Harness chỉ iterate `evals[]` top-level, không recurse.

## Judge mode (v2, added Phiên 19 — 2026-04-08)

Harness v2 adds `--mode={stub|judge|auto}` để convert assertion `skip`
thành concrete verdict bằng LLM judge qua `claude -p`.

### Modes

| Mode   | v1-compat | Khi nào dùng |
|--------|-----------|--------------|
| stub   | ✅ identical | CI fast lane, PR gate (deterministic, ~3 min, no LLM cost) |
| auto   | superset     | Default khi muốn tăng coverage — stub trước, escalate skip → judge |
| judge  | divergent    | Deep audit — judge-first cho mọi type trừ `file_exists` ground truth |

### Judge contract

- **Input**: `assertion.type` + `assertion.text` + skill design context (SKILL.md đầu ~4500 chars + _contract.json compact)
- **Backend**: `claude -p` (subprocess, 90s timeout per call)
- **Output**: Strict single-line JSON `{"verdict":"pass|fail|inconclusive","reason":"...","confidence":0.0-1.0}`
- **Rationale**: Harness KHÔNG invoke skill thật → judge đánh giá **design validity** (liệu SKILL.md có mô tả behavior thỏa mãn assertion không), KHÔNG phải runtime verification.

### Cost controls

- `--max-judges=N` (default **50**): hard cap live calls mỗi run. Khi hit → phần còn lại `skip` với reason `judge-budget-exhausted`.
- **Cache**: `hash(skill+case_id+type+text)` → `.mc-data-eval/.judge-cache/<sha256>.json`. Re-run hoàn toàn deterministic khi cache hot.
- `--clear-judge-cache`: wipe cache trước khi chạy.
- `--judge-model=<name>`: optional override, default dùng `claude -p` model mặc định.

### Conservative verdict bias

Judge được instructed "prefer inconclusive over uncertain pass/fail". Empirical từ wf-brainstorm baseline: ~16% resolution rate (19 calls → 3 pass, 16 inconclusive). Đây là feature, không phải bug — static design review không nên over-claim runtime correctness.

### Manual notes preservation

MD report generator preserve các block `<!-- MANUAL -->...<!-- /MANUAL -->` giữa các lần regenerate. Dùng để lưu analyst notes mà không bị wipe khi re-run.

### Known limitations

- Design review ≠ runtime verification. Assertion pass theo judge chỉ có nghĩa "SKILL.md mô tả behavior này", KHÔNG có nghĩa implementation thực tế pass.
- v3 (real Claude Code CLI invocation) sẽ close gap này.
- Subshell counters: call_judge chạy trong `$(...)` subshells nên dùng append-only log file `$JUDGE_LOG` để track, aggregate post-hoc bằng awk.

---

## Total cases per skill (verified 2026-04-08)

| Skill                    | Cases |
|--------------------------|-------|
| wf-add-scope             |  3    |
| wf-analyze-requirements  | 14    |
| wf-annotate-code         |  3    |
| wf-brainstorm            |  4    |
| wf-define-features       |  3    |
| wf-design                |  5    |
| wf-design-ux             |  8    |
| wf-fix-bugs              |  7    |
| wf-implement-feature     |  3    |
| wf-legacy-classify       | 17    |
| wf-legacy-extract        | 13    |
| wf-legacy-scan           | 17    |
| wf-plan-modules          |  4    |
| wf-preflight             |  5    |
| wf-prepare-deployment    |  3    |
| wf-verify-sync           |  5    |
| **TOTAL**                | **114** |

> Cập nhật 2026-04-10: 114 cases, 682 assertions. wf-fix-bugs tăng từ 5→7 cases. 15 skills còn lại giữ nguyên.

---

## Audit Pipeline Integration (từ /audit-devkit v3.1.0)

`run-skill-evals.sh` được tích hợp vào `/audit-devkit` orchestrator như **optional Phase 3.6**, kích hoạt bằng flag `--evals`.

### Trigger

```
/audit-devkit --evals                          # + Phase 3.6, default mode=stub
/audit-devkit --evals --eval-mode=auto         # + Phase 3.6, mode=auto
/audit-devkit --evals --eval-skill=wf-brainstorm --eval-mode=judge  # + Phase 3.6, 1 skill, judge mode
/audit-devkit --no-fix                         # KHÔNG chạy Phase 3.6 (no --evals)
```

### Mode flags

| Flag | Default | Values |
|------|---------|--------|
| `--evals` | OFF (opt-in) | Flag only, không có value |
| `--eval-mode=<mode>` | stub | stub / judge / auto / real |
| `--eval-skill=<name>` | --all (tất cả workflow skills) | Tên skill (VD: wf-brainstorm) |

### Output paths

| File | Path | Tạo khi |
|------|------|---------|
| eval-results.json | `docs/audit/work/eval-results.json` | `--evals` flag truyền |
| eval-results.md | `docs/audit/reports/eval-results.md` | `--evals` flag truyền |

### Eval verdict logic

| Điều kiện | Verdict |
|-----------|---------|
| fail=0, skip=0 | EVAL-CLEAN |
| fail=0, skip>0 | EVAL-PARTIAL |
| fail 1-5 | EVAL-NEEDS-REVIEW |
| fail>5 | EVAL-NEEDS-FIX |

Eval verdict độc lập với Audit verdict và Master Plan verdict.

### Non-workflow skills

`audit-devkit` nằm ở `.claude/skills/` (không phải `.claude/skills/workflow/`). Để chạy eval cho non-workflow skills:

```bash
bash .claude/scripts/audit/run-skill-evals.sh audit-devkit --skills-dir=.claude/skills --mode=auto
```

Flag `--skills-dir` override default `SKILLS_DIR` (workflow/) — cho phép Phase 3.6 truyền đúng directory khi chạy eval cho audit skill riêng lẻ.
