# Phase 1 — Wave 3: Templates + Rules + Hooks (3 batches PARALLEL + 1 Bash)

> Scan templates (2 sub-batches), rules (1 batch), hooks (Bash verify). Templates + rules dùng agents song song, hooks dùng Bash check.

**PRE-GATE:** Wave 1, 2 hoàn thành (hoặc skip nếu --skill mode)

**📤 OUTPUT:** 4 files: `findings-templates-{a,b}.json`, `findings-rules.json`, `findings-hooks.json`

---

## Pre-step: Template Path Validation [F-SKL-015]

Trước khi spawn template-auditor, verify mỗi template path tồn tại:

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.3.0 | Duyệt `audit-index.json:components.templates[].path`. Cho mỗi path: `test -f [path]`. Nếu NOT_FOUND → log `WARNING [E_TEMPLATE_PATH_NOT_FOUND]` → loại khỏi batch list | Bash | invalid filtered |

---

## Batch Plan

| Batch | Auditor | Scope | Max Files | Output |
|-------|---------|-------|-----------|--------|
| 1.3a | `template-auditor` | templates first half (alphabet) | ≤18 | `findings-templates-a.json` |
| 1.3b | `template-auditor` | templates second half (alphabet) | ≤18 | `findings-templates-b.json` |
| 1.4 | `skill-auditor` | `rules/*.md` | ≤8 | `findings-rules.json` |
| 1.5 | Bash verify | `hooks/*.sh` (trừ `_hook-utils.sh`) | ≤11 | `findings-hooks.json` |

> **Spawn 1.3a + 1.3b + 1.4 ĐỒNG THỜI** (3 Agent calls). Batch 1.5 chạy bằng Bash (không cần agent).
> `_hook-utils.sh` được loại — kiểm tra riêng bởi Wave 4 MP-1.

---

## Steps — Agent Batches (1.3a + 1.3b + 1.4)

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.3.1 | Chia template paths thành 2 halves ≤18 files theo alphabet | Read | 2 lists |
| 1.3.2 | Đọc `components.rules[]` từ audit-index | Read | rules list |
| 1.3.3 | **Spawn 1.3a + 1.3b + 1.4 PARALLEL** (3 Agent calls). Criteria: T1-T5 cho templates, S1-S10 cho rules (xem `_shared.md`) | Agent (×3) | 3 agents started |
| 1.3.4 | Thu thập + parse JSON, fallback E004 | Read | parsed |
| 1.3.5 | WRAP results vào schema → WRITE 3 files findings-* | Read+Write | files written |

---

## Steps — Hooks Bash Verify (1.5)

> Hooks là script Bash, không cần agent — chạy trực tiếp các check.

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.5.1 | Cho mỗi hook `*.sh` (trừ `_hook-utils.sh`): `bash -n [hook]` syntax check | Bash | syntax valid per file |
| 1.5.2 | Verify shebang dòng 1: `head -1 [hook]` chứa `#!/`  | Grep | shebang found |
| 1.5.3 | Verify executable permission: `test -x [hook]` (Unix-style; Windows skip) | Bash | exec bit OK |
| 1.5.4 | Grep paths referenced trong hook → verify tồn tại (Glob) | Grep+Glob | paths checked |
| 1.5.5 | Build findings array: cho mỗi hook fail → 1 finding (severity = MAJOR cho syntax fail, MINOR cho missing shebang/exec) | - | findings collected |
| 1.5.6 | WRAP vào schema `audit-findings-v1` (source = "bash-verify", batch = "hooks") → WRITE `$SESSION_DIR/findings-hooks.json` | Read+Write | file written |
| 1.5.7 | Validate JSON | Bash | OK |

---

## POST-GATE

- 4 files tồn tại trong `$SESSION_DIR/`: findings-templates-a.json, findings-templates-b.json, findings-rules.json, findings-hooks.json
- Mỗi file là JSON valid với `$schema: "audit-findings-v1"`
- UPDATE `scan-status.json`: `wave_3_templates_rules_hooks.completed_batches` += 4 batch IDs, status = "completed", `metrics.agent_spawns += 3`

---

## Note về `references/`

`.claude/references/**/*.md` (161 files) được indexed ở Phase 0 nhưng **KHÔNG scan riêng** — references là domain knowledge read-only, không có structural criteria. Cross-reference verification (agents ↔ references) được xử lý bởi `/audit-devkit-verify` Phase 1.

---

## Cross-references

- Auditor prompt template: `_shared.md` §Auditor Prompt Template
- Criteria T1-T5 (template) và S1-S10 (rules): `_shared.md` §Criteria Catalog
- Findings schema: `templates/findings.json`
- Next: `phase1-wave3.5-scripts.md`
