# Progress — docs-restructure-v1

**Cập nhật lần cuối:** 2026-05-15 (Phiên #6 — W4 COMPLETE 7/7 tasks)
**Trạng thái tổng:** ✅ W1 19/19 · ✅ W2 21/21 · ✅ W3 5/5 · ✅ W4 7/7 (100% — PROJECT DONE)

---

## Tóm tắt nhanh

| Wave | Trạng thái | % hoàn thành | Phiên |
|------|-----------|--------------|-------|
| W1 — Foundation | ✅ COMPLETED | 19/19 files (100%) | #1 (plan), #2 (start 5 file), #3 (finish 14 file) |
| W2 — Architecture & Patterns | ✅ COMPLETED | 21/21 files (100%) | #4 (toàn bộ W2 trong 1 phiên) |
| W3 — Migration & Templates | ✅ COMPLETED | 5/5 tasks (100%) | #5 |
| W4 — User Guides & Ops | ✅ COMPLETED | 7/7 tasks (100%) | #6 |

---

## Wave 1 — Foundation (chi tiết)

### Checklist files

#### Entry point (2 files)
- [x] `docs/README.md` — Master index, persona-driven navigation (Phiên 2)
- [x] `docs/CONTRIBUTING.md` — Quy trình đóng góp pointer-heavy (Phiên 3)

#### 00-overview/ (4 files)
- [x] `00-overview/01-project-description.md` — migrate + refresh (Phiên 3)
- [x] `00-overview/02-positioning-priorities.md` — migrate + refresh (Phiên 3)
- [x] `00-overview/03-glossary.md` — NEW thuật ngữ + acronyms (Phiên 3)
- [x] `00-overview/04-key-personas.md` — NEW 4 personas + matrix (Phiên 3)

#### 02-standards/ (13 files)
- [x] `02-standards/README.md` — Index 12 chuẩn (Phiên 2)
- [x] `02-standards/01-core-rules-index.md` — 38 CORE + 4 BHV với Pass/Fail (Phiên 2)
- [x] `02-standards/02-skill-standard.md` — Skill anatomy (CORE-032..038) (Phiên 2)
- [x] `02-standards/03-agent-standard.md` — Agent + Knowledge + Procedures (Phiên 2)
- [x] `02-standards/04-contract-schema.md` — `_contract.json` deep dive (Phiên 3)
- [x] `02-standards/05-quality-gates.md` — PRE/POST-GATE T1→T4 + CDG (Phiên 3)
- [x] `02-standards/06-safe-write-protocol.md` — CORE-006 fields ownership (Phiên 3)
- [x] `02-standards/07-naming-conventions.md` — kebab-case, REQ-ID, session-ID (Phiên 3)
- [x] `02-standards/08-error-code-registry.md` — ★ Registry E001..E999 (Phiên 3)
- [x] `02-standards/09-session-checkpoint.md` — CORE-035 + CORE-038 (Phiên 3)
- [x] `02-standards/10-language-policy.md` — Tiếng Việt / English (Phiên 3)
- [x] `02-standards/11-output-path-contract.md` — ★ Bảng `.mc-data/` paths (Phiên 3)
- [x] `02-standards/12-extension-checklist.md` — Master extension checklist (Phiên 3)

**Tổng W1:** 19 files | **Done:** 19 | **Remaining:** 0

---

## Wave 2 — Architecture & Patterns

### 01-architecture/ (9 files) ✅ DONE
- [x] `01-system-layers.md` (Phiên 4)
- [x] `02-workflow-model.md` (Phiên 4)
- [x] `03-data-model.md` (Phiên 4)
- [x] `04-code-intelligence.md` (Phiên 4)
- [x] `05-hooks-and-gates.md` (Phiên 4)
- [x] `06-protocols-overview.md` ★ (Phiên 4)
- [x] `07-skills-catalog.md` (Phiên 4)
- [x] `08-agents-catalog.md` (Phiên 4)
- [x] `09-dependencies-graph.md` (Phiên 4)

### 03-design-patterns/ (12 files) ✅ DONE
- [x] `README.md` (Phiên 4)
- [x] `01-lazy-load-procedures.md` (Phiên 4)
- [x] `02-ci-first-integration.md` (Phiên 4)
- [x] `03-cross-skill-artifacts.md` (Phiên 4)
- [x] `04-parallel-lane-dispatch.md` (Phiên 4)
- [x] `05-agent-prompt-template.md` (Phiên 4)
- [x] `06-checkpoint-resume.md` (Phiên 4)
- [x] `07-playwright-3-modes.md` (Phiên 4)
- [x] `08-auto-detect-fallback.md` (Phiên 4)
- [x] `09-multi-session-locking.md` (Phiên 4)
- [x] `10-cdg-gate.md` (Phiên 4)
- [x] `11-bash-utility-design.md` ★ (Phiên 4)

---

## Wave 3 — Migration & Templates ✅ DONE

### Tasks
- [x] Move file theo bảng "Mapping cũ→mới" trong `00-master-plan.md` §5 (Phiên 5)
- [x] Viết `04-skill-design/_template/` (9 files) (Phiên 5)
- [x] Scaffold 28 file `05-review-standards/` còn thiếu (Phiên 5)
- [x] Viết `scripts/update-docs-refs.sh` (KHÔNG chạy) (Phiên 5)
- [x] Update `05-review-standards/README.md` thêm inventory scaffold (Phiên 5)
- [x] Tạo `04-skill-design/README.md` (Phiên 5)

### Số liệu

- **Files moved (git mv):** ~60 files (overview, catalog, design skills wf-fix-bugs/wf-legacy-scan, ADRs, review-standards, skills-manual, runbooks, e2e migrations, release-notes, archive)
- **Files created:**
  - `scripts/update-docs-refs.sh` (1 file)
  - `docs/04-skill-design/README.md` (1)
  - `docs/04-skill-design/_template/*.md` (9 files)
  - `docs/05-review-standards/{skill}.md` scaffold (28 files)
- **Dirs created:** `docs/{04-skill-design,05-review-standards/reports,06-user-guides/per-skill,07-operations/{runbooks,migrations,release-notes,audits},08-reference,99-archive/{design-legacy,wf-fix-bugs-prompts,wf-fix-bugs-reviews,wf-fix-bugs-scripts,wf-legacy-scan-{implementation,archive,fixtures,examples}}}`
- **Dirs removed:** `docs/design/`, `docs/design/skills/`, `docs/runbooks/`, `docs/skills-manual/`, `docs/skill-review-standards/`

---

## Wave 4 — User Guides & Ops ✅ DONE

### Tasks
- [x] Move `huong-dan-su-dung.md`, `devkit-workflow-overview.md` → `06-user-guides/` (đã làm ở W3)
- [x] Move `skills-manual/*` → `06-user-guides/per-skill/` (đã làm ở W3)
- [x] Move `runbooks/*` → `07-operations/runbooks/` (đã làm ở W3)
- [x] Move migrations + release notes → `07-operations/migrations/` & `release-notes/` (đã làm ở W3)
- [x] Move archive files → `99-archive/` (đã làm ở W3)
- [x] Tạo `06-user-guides/README.md` (Phiên 6)
- [x] Tạo `07-operations/README.md` (Phiên 6)
- [x] Tạo `99-archive/README.md` (Phiên 6)
- [x] Tạo `08-reference/README.md` cheatsheets index (Phiên 6)
- [x] Update `CLAUDE.md` + `AGENTS.md` trỏ về `docs/README.md` (Phiên 6)
- [x] Final link integrity check (Phiên 6) — 0 broken links ngoài `99-archive/`

### Số liệu W4
- **Files created:** 4 README.md (06/07/08/99)
- **Files updated:** CLAUDE.md + AGENTS.md (chỉ section "Tài liệu nên đọc trước")
- **Link check:** 60 broken links — TẤT CẢ trong `99-archive/wf-legacy-scan-{implementation,archive}/phases/` (link tới `../../*.md` từ phase files đã được archive sâu). Archive là READ-ONLY → NOT FIX. Tài liệu chính ngoài archive: 0 broken.

---

## Lịch sử phiên

### Phiên #1 — 2026-05-15 (khởi tạo plan)

**Người thực hiện:** Claude (Opus 4.7)
**Việc đã làm:**
- Phân tích `docs/` hiện tại (127 refs từ `.claude/`)
- Thảo luận với user qua 3 vòng → chốt cấu trúc đích
- Tạo `plans/docs-restructure-v1/` với master plan + progress
- Tạo memory entry + update MEMORY.md

### Phiên #2 — 2026-05-15 (W1 start — autonomous)

**Người thực hiện:** Claude (Opus 4.7) — user delegate "tự quyết"
**Quyết định defaults:**
- Wave bắt đầu: W1 ✅
- Review cadence: Wave-batch (tự verify, không file-by-file)
- Scope cải tiến: tất cả 10
- Style: teaching cho 02/03, formal cho 01/05
- Ngôn ngữ: tiếng Việt
- `.claude/**` refs: defer
- README: medium (~200 dòng persona table + sitemap)
- CONTRIBUTING: pointer-heavy (~100 dòng)
- Thứ tự W1: README → 02-standards (foundation) → 00-overview → CONTRIBUTING

**Việc đã làm:**
- Đọc ground truth: `.claude/rules/00-core.md`, `.claude/rules/00-behavioral.md`, `docs/project-description.md`
- Viết 5 file W1:
  1. `docs/README.md` — Master index + persona-driven navigation
  2. `docs/02-standards/README.md` — Index 12 chuẩn
  3. `docs/02-standards/01-core-rules-index.md` — 38 CORE + 4 BHV với ví dụ Pass/Fail cho 12 rule quan trọng nhất, bảng tra cứu đầy đủ
  4. `docs/02-standards/02-skill-standard.md` — Skill anatomy (lazy-load procedures, file contract, error codes, session structure, anti-patterns, compliance checklist)
  5. `docs/02-standards/03-agent-standard.md` — Agent definition + knowledge + procedures + 8-section spawn pattern

### Phiên #4 — 2026-05-15 (W2 start — 01-architecture/ DONE 9/9)

**Người thực hiện:** Claude (Opus 4.7) — user delegate "tự quyết, không hỏi xác nhận"
**Việc đã làm:** Viết 9 files của `01-architecture/`, đóng phần đầu W2.

Files viết theo thứ tự (formal pattern cho architecture overview):
1. `01-architecture/01-system-layers.md` — 2 lớp Skills + Agents, 4 thành phần hỗ trợ (Hooks, Rules, References, Doc-framework), luồng end-to-end khi user gõ `/`
2. `01-architecture/02-workflow-model.md` — 7 phases (P0-P6) + 3 paths (STANDARD/EXISTING/HYBRID), skills phụ trợ, CDG, Mermaid graph
3. `01-architecture/03-data-model.md` — Cấu trúc `.mc-data/`, SSOT `req-registry.json`, impl_status lifecycle, cross-skill artifacts, legacy data
4. `01-architecture/04-code-intelligence.md` — Protocol 20 chi tiết, CI PRE-GATE 3-step Na/Nb/Nc, CI-ROUTE matrix, per-tool TTL, graceful degradation
5. `01-architecture/05-hooks-and-gates.md` — 12 hooks (Session/PreTool/PostTool/Stop), 3 gate types (PRE-GATE forensic, POST-GATE T1→T4, CDG 13 points), Hook vs Gate phân định
6. `01-architecture/06-protocols-overview.md` ★ — Bảng quick map 22 protocols + phân nhóm theo chủ đề + bảng "khi tạo skill mới load protocol nào"
7. `01-architecture/07-skills-catalog.md` — Inventory 43 wf-* + 9 nhóm, decision tree chọn skill, ước lượng thời gian, version current
8. `01-architecture/08-agents-catalog.md` — 62 agents per 5 teams + orchestrator, routing matrix per use case, domain knowledge + procedures mapping
9. `01-architecture/09-dependencies-graph.md` — Mermaid diagram + phase layers + cross-skill artifacts table + bottleneck analysis

**Tổng:** W2 = 9/21 files (43%) — 01-architecture/ HOÀN TẤT phần đầu phiên.

Sau đó tiếp tục viết 12 file `03-design-patterns/` (teaching pattern với case study + anti-patterns + checklist):
10. `03-design-patterns/README.md` — Index 11 patterns + category map + apply matrix
11. `03-design-patterns/01-lazy-load-procedures.md` — CORE-032, case study wf-fix-bugs v10.0 vs monolithic (giảm 70% context)
12. `03-design-patterns/02-ci-first-integration.md` — CORE-033, 3-step PRE-GATE Na/Nb/Nc, case study wf-fix-bugs Phase 4
13. `03-design-patterns/03-cross-skill-artifacts.md` — CORE-036, $schema + audit_chain, case study fix-impact.json
14. `03-design-patterns/04-parallel-lane-dispatch.md` — CORE-025, 5 điều kiện, case study wf-fix-bugs 11 QD lanes
15. `03-design-patterns/05-agent-prompt-template.md` — CORE-037, 8 sections, mã ví dụ build_lane_prompt
16. `03-design-patterns/06-checkpoint-resume.md` — CORE-038, context budget tiers, 7-step resume flow, wf-legacy-scan 4 levels
17. `03-design-patterns/07-playwright-3-modes.md` — none/assisted/full, case study wf-fix-bugs QD9 + wf-e2e-verify
18. `03-design-patterns/08-auto-detect-fallback.md` — Auto-detect + cache + TTL + fallback, case study Protocol 20
19. `03-design-patterns/09-multi-session-locking.md` — Protocol 22, R/W lock + heartbeat + writer priority, case study wf-e2e
20. `03-design-patterns/10-cdg-gate.md` — Protocol 16, 13 CDG points, question template, case study CDG-07
21. `03-design-patterns/11-bash-utility-design.md` ★ — Decision tree bash vs Python, case studies, refactor candidates

**Tổng W2:** 21/21 files (100%). 01-architecture/ + 03-design-patterns/ HOÀN TẤT.

**Phiên kế tiếp bắt đầu từ:** Wave 3 — Migration & Templates
- Move file cũ theo bảng "Mapping cũ→mới" (`00-master-plan.md` §5)
- Viết `04-skill-design/_template/` (9 file template)
- Scaffold 25 file `05-review-standards/` còn thiếu
- Viết script `scripts/update-docs-refs.sh` (chưa chạy)
- Tạo `05-review-standards/README.md` + `04-skill-design/README.md`

### Phiên #6 — 2026-05-15 (W4 COMPLETE — autonomous batch — PROJECT DONE)

**Người thực hiện:** Claude (Opus 4.7) — user delegate "tự quyết, không hỏi xác nhận"
**Việc đã làm:** 7 tasks W4 trong 1 phiên.

**4 README.md cho các sections W3 đã move file:**

1. `docs/06-user-guides/README.md` — Index 2 file tổng quan + 2 file per-skill, persona table, cấu trúc khi viết user guide mới (template 6-section)
2. `docs/07-operations/README.md` — Index 1 runbook + 4 migrations + 6 release notes + audits (placeholder), quy ước đặt tên per loại
3. `docs/08-reference/README.md` — Index 2 cheatsheets + bảng "khi cần tra cứu → canonical source ở đâu", anti-pattern cheatsheet làm secondary source
4. `docs/99-archive/README.md` — Tại sao archive, 5 categories (Legacy overview, Design legacy, wf-fix-bugs artifacts, wf-legacy-scan artifacts, Ad-hoc), quy tắc xử lý (READ-ONLY mặc định)

**Update CLAUDE.md + AGENTS.md:**

- CLAUDE.md §"Tài liệu đọc trước khi bắt đầu task": từ 6 file legacy → 8 file mới có docs/README.md là entry point + cross-link 02-standards/ cho contributor; chú thích cấu trúc mới
- AGENTS.md §"Tài Liệu Nên Đọc Trước": từ 5 file legacy → 7 file mới với docs/README.md là entry point; chú thích các path cũ đã chuyển vào 99-archive

**Link integrity check (`/tmp/link-check.sh`):**

- Script bash custom parse markdown links `[...](X)`, skip http/mailto/anchor, resolve relative paths, check file existence
- Result: 60 broken — TẤT CẢ trong `99-archive/wf-legacy-scan-{implementation,archive}/phases/` (legacy phase files link với pattern `../../*.md` mà nay đã ở depth khác)
- Verdict: PASS cho tài liệu chính. 99-archive read-only, không cần fix.

**Phiên tiếp theo:** KHÔNG có. Project docs-restructure-v1 COMPLETE.

**Khuyến nghị follow-up (ngoài scope plan này):**
- Chạy `scripts/update-docs-refs.sh --apply` để update refs trong `.claude/**` (cần backup trước qua git commit)
- Hoàn thiện 28 file scaffold trong `05-review-standards/` theo nhu cầu review từng skill
- Commit toàn bộ docs/ structure mới qua 1 PR

---

### Phiên #5 — 2026-05-15 (W3 COMPLETE — autonomous batch)

**Người thực hiện:** Claude (Opus 4.7) — user delegate "tự quyết, không hỏi xác nhận"
**Việc đã làm:** 5 tasks W3 trong 1 phiên.

**Task 5 — Viết `scripts/update-docs-refs.sh` (KHÔNG chạy):**
- 23 mapping entries (overview → 00-overview, catalogs → 01-architecture, design skills → 04-skill-design, review-standards → 05-, skills-manual → 06-/per-skill, runbooks → 07-/runbooks, migrations → 07-/migrations, release-notes → 07-/release-notes)
- Bash với set -euo pipefail, color output, --dry-run mặc định, --apply ghi thực, --filter pattern, --mapping-only chỉ in mapping, --verbose
- Exclude: .git, .mc-data, node_modules, docs/99-archive, .claude/worktrees
- Include: .claude/skills, .claude/agents, .claude/rules, .claude/doc-framework, .claude/references, .claude/schemas, .claude/scripts, CLAUDE.md, AGENTS.md, CHANGELOG.md, README.md
- Test với `--filter wf-fix-functional/SKILL.md` → preview chính xác 4 replacements
- An toàn: atomic write tmp → cmp verify → mv

**Task 1 — Move file legacy (60+ git mv):**
- `docs/project-description.md`, `mcv3-development-priorities.md`, `skills-reference.md`, `skills-dependency-graph.md` → `docs/99-archive/*-LEGACY.md`
- `docs/devkit-workflow-overview.md`, `huong-dan-su-dung.md` → `docs/06-user-guides/`
- `docs/skill-anatomy-guide.md` → `docs/08-reference/skill-anatomy-quick.md`
- `docs/microtask-schema.md` → `docs/08-reference/`
- `docs/design/skills/wf-fix-bugs/{01-09,README}.md` × 10 → `docs/04-skill-design/wf-fix-bugs/`
- `docs/design/skills/wf-fix-bugs/{prompts,reviews,scripts}/` → `docs/99-archive/wf-fix-bugs-{prompts,reviews,scripts}/`
- `docs/design/skills/wf-legacy-scan/{01-10,README,MIGRATION-PROGRESS,adr-signoff}.md` × 13 → `docs/04-skill-design/wf-legacy-scan/`
- `docs/design/skills/wf-legacy-scan/{implementation,archive,fixtures,examples}/` → `docs/99-archive/wf-legacy-scan-*/`
- 15 ADR/phase files trong `docs/design/skills/` → `docs/99-archive/design-legacy/`
- `docs/skill-review-standards/` × 22 files → `docs/05-review-standards/` (+ fix nested reports/reports/)
- `docs/skills-manual/` × 3 → `docs/06-user-guides/per-skill/` + `docs/07-operations/release-notes/`
- `docs/runbooks/` × 1 → `docs/07-operations/runbooks/`
- 9 wf-e2e/wf-fix-bugs/wf-preflight version files → `docs/07-operations/{migrations,release-notes}/`
- 5 archive files (fix-prompt, e2e-test, audit-prompts, DEVKIT-extraction, codex-guide) → `docs/99-archive/`
- Empty dirs removed: `docs/design/skills/{wf-fix-bugs,wf-legacy-scan}/`, `docs/design/skills/`, `docs/design/`

**Task 3 — Tạo `docs/04-skill-design/README.md`:**
- Index 9 file template, mapping cấu trúc thư mục per-skill
- Bảng "skills đã có folder design" — wf-fix-bugs ✅, wf-legacy-scan ✅
- Cách dùng template `_template/` cho skill mới
- Phong cách viết per-file (độ dài tham khảo)
- Checklist khi tạo folder design

**Task 2 — Viết `docs/04-skill-design/_template/` (9 files):**
- `README.md` — Index 9 file + persona-driven entry
- `01-vision-principles.md` — Vision + non-goals + nguyên tắc thiết kế
- `02-arguments.md` — Bảng arguments + validation + profile dispatch
- `03-phase-routing.md` — Phase routing map + Mermaid + profile dispatch + conditional skip + pipeline state
- `04-file-contract.md` — PRE-GATE/POST-GATE per phase + cross-skill produces_for/consumes_from + artifact schemas + atomic write pattern
- `05-error-codes.md` — Namespace E0xx allocation + auto-fix budget + error ledger pattern + escalation
- `06-templates-list.md` — Templates output + metadata stripping + versioning
- `07-procedures-structure.md` — `_shared.md` + `phase{N}-*.md` 4-section template + `resume-status.md`
- `08-tradeoffs-adr.md` — ADR template Context→Decision→Alternatives→Consequences
- `09-evals-test-cases.md` — ≥3 test cases với pass/fail criteria + coverage matrix
- Mỗi file có `_template_notes:` ở đầu → hướng dẫn skill author populate

**Task 4 — Scaffold 28 file `05-review-standards/` (`/tmp/scaffold-review.sh` helper):**
- 12 wf-e2e-* (verify, batch, browser, credentials, demo, finding, fix, implement, retest, scenario, test, unblock)
- 11 lane skills wf-fix-* (functional, business, security, performance, ux-a11y, data, compat, observability, runtime-health, integration, business-completeness)
- 5 còn lại (status, wf-diagram, wf-scan-target, wf-migrate-module, wf-test-business-workflow)
- Mỗi file: Header + Skill Profile (YAML TODO) + 2-table nhóm tiêu chuẩn + Extension section TODO + Quick-check TODO + Liên kết
- Total review files: 20 full + 28 scaffold + README + _template-common = 50 files
- Update `05-review-standards/README.md` thêm 3 sections inventory (Lane skills, E2E pipeline, Standalone & Tracking)
- Fix stale refs trong `05-review-standards/README.md` (skill-anatomy-guide → skill-anatomy-quick, skills-reference → 01-architecture/07-skills-catalog)

**Phiên kế tiếp bắt đầu từ:** Wave 4 — User Guides & Operations
- Update README.md cho từng folder (06-user-guides, 07-operations, 99-archive, 08-reference)
- Final integrity check: cross-link không broken
- Update CLAUDE.md + AGENTS.md trỏ về docs/README.md

---

### Phiên #3 — 2026-05-15 (W1 COMPLETE — autonomous batch)

**Người thực hiện:** Claude (Opus 4.7) — user delegate "tự quyết, không hỏi xác nhận"
**Việc đã làm:** Viết 14 file còn lại của W1, đóng W1 100%.

Files viết theo thứ tự:
1. `02-standards/04-contract-schema.md` — `_contract.json` deep dive (top-level fields, registry_scope 7 roles, cross_skill_contracts với produces_for/consumes_from, artifact schema versioning với audit_chain, anti-patterns, checklist, compliance audit)
2. `02-standards/05-quality-gates.md` — 3 gate types (PRE-GATE forensic, POST-GATE T1→T4 với auto-fix budget, CDG 13 points với rejection behavior), flow diagram
3. `02-standards/06-safe-write-protocol.md` — 7 write_role values, bảng phân công đầy đủ 17+ skills, 4 quy tắc Safe-Write, impl_status lifecycle (CORE-008 no downgrade), APPEND-only pattern, UPDATE-MODE pattern
4. `02-standards/07-naming-conventions.md` — skill prefixes, lowercase-kebab cho folders, REQ-ID/FEAT-ID format UPPERCASE, SESSION_ID format, slug rules với Vietnamese diacritics strip, code variable conventions
5. `02-standards/08-error-code-registry.md` — ★ Namespace ranges E001-E109, shared E001-E009 semantic, per-skill allocation bảng, wf-fix-bugs case study chi tiết (Phase 1/4/CDG), severity levels, auto-fix budget, error ledger pattern
6. `02-standards/09-session-checkpoint.md` — Session ID format, session directory structure với lock + heartbeat, stale check 30 min, context budget 65/80/90% (CORE-038), checkpoint với context_digest, resume flow 7 steps, skills KHÔNG cần session
7. `02-standards/10-language-policy.md` — Bảng phân loại ngôn ngữ per content type, mix rules trong 1 file, Vietnamese không dấu khi nào dùng, anglicism acceptable, CDG message templates
8. `02-standards/11-output-path-contract.md` — ★ Bảng tổng `.mc-data/` structure, paths theo phase 0-6, implementation/preflight/fix-bugs/legacy pipeline paths, variable conventions ($SESSION_DIR), 8 OPC rules
9. `02-standards/12-extension-checklist.md` — Decision tree tạo mới vs sửa, master checklist tạo skill (11 bước), surgical checklist sửa skill (5 bước), tạo agent mới (7 bước), pre-merge final checklist
10. `00-overview/01-project-description.md` — DEVKIT là gì, 7 phases, 62 agents, 2 lớp kiến trúc, SSOT, REQ-ID, .mc-data structure, language policy summary
11. `00-overview/02-positioning-priorities.md` — Định vị MCV3, thứ tự ưu tiên BẮT BUỘC, 5 hệ quả thực tế (truy vết, DoD docs/code, song song hóa), khung quyết định, trách nhiệm theo vai trò, exception path
12. `00-overview/03-glossary.md` — Bảng thuật ngữ A-W + acronyms, cross-link tới tài liệu chi tiết
13. `00-overview/04-key-personas.md` — 4 personas (End User, Skill Author, Agent Author, Auditor), profile + goal + docs cho mỗi persona, matrix tài liệu × persona
14. `CONTRIBUTING.md` — Pointer-heavy quy trình đóng góp 9 loại đóng góp + PR workflow + compliance audit + FAQ

**Tổng:** W1 = 19/19 files (100%).

**Phiên kế tiếp bắt đầu từ:**
- W2: `01-architecture/` (9 files) + `03-design-patterns/` (12 files)
- File đầu tiên: `01-architecture/01-system-layers.md`
- Cần đọc ground truth: `CLAUDE.md` (kiến trúc), `.claude/skills/protocols/` (22 protocols), `.claude/skills/workflow/` (43 skills)

---

## Resume protocol (khi vào phiên mới)

```
1. Đọc file này (progress.md) trước
2. Tìm dòng cuối cùng có "[x]" → đó là điểm cuối phiên trước
3. Dòng "[ ]" đầu tiên kế tiếp → bắt đầu từ đó
4. Đọc file wave master tương ứng để hiểu DoD
5. Trước khi sửa file `docs/`: đọc 2-3 file `.claude/skills/`/`.claude/rules/` liên quan để bám ground truth
6. Sau khi xong 1 file: tick [x] + ghi 1 dòng vào "Lịch sử phiên"
7. Sau mỗi 3-5 file hoặc cuối phiên: update memory file `project_docs_restructure_v1.md`
```

---

## Style guide — tham khảo file đã viết

Để giữ phong cách nhất quán cross-session, file mới nên theo cấu trúc của các file đã viết:

**Pattern chuẩn cho file `02-standards/{NN}-*.md`:**
```
# {NN} — {Title} (BẮT BUỘC)

> **Mức độ ràng buộc:** BẮT BUỘC / KHUYẾN NGHỊ
> **File gốc canonical:** [path]
> **Mục đích:** {1 câu}

## 1. {Triết lý / Tại sao có chuẩn này}
## 2. {Khái niệm / Cấu trúc}
## 3-N. {Chi tiết}
## {N+1}. Anti-patterns — KHÔNG được làm  ← bảng ❌/✅
## {N+2}. Checklist (nếu áp dụng)
## {Cuối}. Liên kết
```

**Pattern chuẩn cho file `00-overview/`:**
- Ngắn gọn (300-500 dòng)
- Hướng người không kỹ thuật (overview)
- Nhiều bảng/diagram, ít list bullet dài

---

## Open issues / Decisions pending

| # | Issue | Trạng thái |
|---|-------|-----------|
| 1 | User confirm scope (đã defaults trong phiên #2) | ✅ DECIDED autonomous |
| 2 | Bắt đầu W1 (đã bắt đầu phiên #2) | ✅ DECIDED autonomous |
| 3 | README master length (đã ~200 dòng medium) | ✅ DECIDED autonomous |
| 4 | CONTRIBUTING chi tiết hay pointer (chọn pointer-heavy) | ✅ DECIDED autonomous |
| 5 | Có commit git từng wave hay cuối project? | ⏳ PENDING (đề xuất: cuối mỗi wave) |
