# Phase 0: Build Ground Truth Index

> Glob TẤT CẢ DEVKIT components, populate audit-index.json làm SSOT cho toàn bộ pipeline scan.

**PRE-GATE:** `.claude/` directory tồn tại

**📤 OUTPUT:**
- `$SESSION_DIR/audit-index.json` (template: `templates/audit-index.json`)
- `$SESSION_DIR/scan-status.json` (template: `templates/scan-status.json`)
- `$SESSION_DIR/.lock` (heartbeat lock)

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.1 | Parse arguments → xác định scope. Accept cả `--agents` và `--component=agents` (map về cùng scope). Nếu cả 2 formats được cung cấp → `--component=X` higher priority. Log ARGUMENT_CONFLICT WARNING (xem `_shared.md` §Error Handling). | - | scope set |
| 0.2 | **Session ID** = timestamp `YYYYMMDD-HHMMSS`. **$SESSION_DIR** = `.mc-data/work/audit-devkit-scan/[session-id]/`. `mkdir -p $SESSION_DIR`. | Bash | `test -d $SESSION_DIR` |
| 0.2a | **Lock acquire:** Write `$SESSION_DIR/.lock` chứa `{pid: $$, started_at: NOW, heartbeat_at: NOW}`. Xem `_shared.md` §Session Lock & Heartbeat. | Write | `test -f .lock` |
| 0.3 | Glob agents: `.claude/agents/**/*.md` (trừ `spec/`, `procedures/`) | Glob | paths[] collected |
| 0.4 | Glob skills: `.claude/skills/**/SKILL.md` | Glob | paths[] collected |
| 0.5 | Glob templates: `.claude/doc-framework/**/*.md` | Glob | paths[] collected |
| 0.6 | Glob rules: `.claude/rules/*.md` | Glob | paths[] collected |
| 0.7 | Glob hooks: `.claude/hooks/*.sh` | Glob | paths[] collected |
| 0.8 | Glob references: `.claude/references/**/*.md` | Glob | paths[] collected |
| 0.9 | Glob scripts: `.claude/scripts/*.sh` | Glob | paths[] collected |
| 0.10 | Glob hook utilities: `.claude/hooks/_hook-utils.sh` — dùng cho Wave 4 MP-1 | Glob | path or NOT_FOUND |
| 0.11 | Glob digest templates: `.claude/doc-framework/_digests/*.json` — dùng cho Wave 4 MP-4 | Glob | paths[] or empty |
| 0.12 | Glob baseline metrics: `.mc-data/work/shared-metrics/baseline-*.json` + `benchmark-*.md` — dùng cho MP-2 | Glob | paths[] or empty |
| 0.13 | Glob checkpoint schema + protocols: `.claude/skills/schemas/checkpoint-schema.json`, `.claude/skills/protocols/` — dùng cho MP-3 | Glob | paths or NOT_FOUND |
| 0.14 | Glob task file templates: `.claude/doc-framework/phase5-implementation/tasks/**/*.md` — dùng cho MP-5/MP-6 | Glob | paths[] or empty |
| 0.15 | Cho mỗi component: đọc size, phân loại team/category/phase | Bash/Read | metadata populated |
| 0.16 | Cho agents: kiểm tra procedure files (`procedures/[agent-name]/`) | Glob | has_procedures + procedure_count |
| 0.17 | **Build audit-index.json từ template:** READ `templates/audit-index.json` → REPLACE `{{TIMESTAMP_ISO}}`, `{{SESSION_ID}}`, `{{SCOPE}}` → POPULATE `components.{agents,skills,templates,rules,hooks,references,scripts}[]` từ data Step 0.3-0.16 → COMPUTE `counts` → `master_plan_components.*` giữ NOT_FOUND placeholders (Wave 4 sẽ populate). WRITE `$SESSION_DIR/audit-index.json`. | Read+Write | file created |
| 0.18 | Validate: `node -e "JSON.parse(require('fs').readFileSync('$SESSION_DIR/audit-index.json'))"` pass | Bash | exit code 0 |
| 0.19 | Validate counts: `agents > 0 AND skills > 0` (E006 nếu fail) | Read | counts verified |
| 0.20 | **Build scan-status.json từ template:** READ `templates/scan-status.json` → REPLACE placeholders → SET `phases.phase_0_index.status = "completed"`, `started_at`, `completed_at` → SET `phases.phase_1_scan.status = "in_progress"` → SET `next_action = "phase_1_wave_1_agents"` → SET `metrics.total_components_indexed = counts.total`. WRITE `$SESSION_DIR/scan-status.json`. | Read+Write | `test -f scan-status.json` |

**POST-GATE:**
- `$SESSION_DIR/audit-index.json` tồn tại + JSON valid
- `counts.agents > 0 AND counts.skills > 0`
- `counts.total` = tổng tất cả component counts
- `$SESSION_DIR/scan-status.json` initialized với `phase_0_index.status = "completed"`

---

## Delta Scan Mode (`--since=<commit>`)

> Nếu user pass `--since=<commit>`:

1. Resolve changed files: `git diff --name-only <commit>..HEAD -- .claude/`
2. Categorize changed files theo component type (agents/skills/templates/rules/hooks/scripts)
3. Trong `audit-index.json.components.*[]`: chỉ giữ entries thuộc changed files
4. SET `audit-index.json.scope = "delta:<commit>"`
5. Nếu changed files = 0 → log INFO "Không có files thay đổi từ <commit>" → tạo empty `audit-scan-result.json` ngay (skip Phase 1, 2) → jump to Phase 3 summary

## Focused Scan Mode (`--skill=<name>`)

> Nếu user pass `--skill=<name>`:

1. Glob `.claude/skills/**/[name]/SKILL.md`
2. Nếu không tìm thấy → suggest closest match (xem `_shared.md` Fix Rules row "skill not exists")
3. Trong `audit-index.json.components.skills[]`: chỉ giữ 1 skill được chỉ định + downstream/upstream skills (đọc `cross_skill_contracts` từ `_contract.json`)
4. SET `audit-index.json.scope = "focused:<name>"`
5. Phase 1 chỉ chạy Wave 2 focused (xem `phase1-wave2-skills.md` §Focused Mode)

---

## Resume Behavior

Nếu `--resume` được pass:
1. Tìm latest session: `ls -t .mc-data/work/audit-devkit-scan/ | head -1` → `$SESSION_DIR`
2. READ `$SESSION_DIR/scan-status.json`
3. Nếu `phases.phase_0_index.status == "completed"` → SKIP Phase 0 → continue Phase 1 từ `next_action`
4. Nếu corrupt (E010): rebuild status từ existing findings-*.json files

---

## Cross-references

- Schema: `templates/audit-index.json` (audit-index-v1)
- Status: `templates/scan-status.json`
- Lock protocol: `_shared.md` §Session Lock & Heartbeat
- Error codes: `_shared.md` §Error Handling Codes
- Next phase: `phase1-wave1-agents.md`
