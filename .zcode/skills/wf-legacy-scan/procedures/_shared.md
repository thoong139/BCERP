# Shared Protocols — wf-legacy-scan

> Cross-cutting protocols, state variables glossary, tech stack verification, external docs scan,
> agent prompt templates, và error handling được sử dụng bởi nhiều Phase trong wf-legacy-scan.
> KHÔNG đọc file này standalone — chỉ load section cụ thể khi phase file chỉ định.

## Prerequisite cho mọi phase

> **BẮT BUỘC trước khi invoke any log_*/flock_*/helper function:**
> `source .claude/scripts/legacy-scan-common.sh` đã được gọi tại Phase 0 Session Init (Step 0.0c).
> Nếu invoke procedure file standalone (test/debug), tự source từ repo root trước.

## Sections

- [State Variables Glossary](#state-variables-glossary)
- [Cross-Phase Data Flow](#cross-phase-data-flow)
- [LEGACY_MODE Detection](#legacy_mode-detection)
- [Project Size Tiers](#project-size-tiers)
- [Tech Stack Verification Protocol (CORE-014)](#tech-stack-verification-protocol-core-014)
- [External Docs Scan Protocol](#external-docs-scan-protocol)
- [Pipeline Data Persistence Rules](#pipeline-data-persistence-rules)
- [Atomic Write Pattern](#atomic-write-pattern)
- [Agent Prompt Templates (Stage 2 & 3)](#agent-prompt-templates-stage-2--3)
- [Strategy & Stage Mode Reference](#strategy--stage-mode-reference)
- [Fix Rules](#fix-rules)
- [Auto-Fix & Escalation Protocol (Protocol 1, 2)](#auto-fix--escalation-protocol-protocol-1-2)
- [Error Handling](#error-handling)
- [On Failure — Standard Format](#on-failure--standard-format)
- [Execution Trace (CORE-026)](#execution-trace-core-026)
- [Phase Summary (CORE-028)](#phase-summary-core-028)
- [Task Planning (Protocol 9)](#task-planning-protocol-9)
- [Context & Checkpoint](#context--checkpoint)
- [Template Usage Rule (CORE-031)](#template-usage-rule-core-031)

---

## State Variables Glossary

Các biến in-memory được set/đọc xuyên suốt pipeline execution.

| Variable | Set by Phase | Read by Phase | Description |
|----------|--------------|---------------|-------------|
| `$PROJECT_PATH` | Phase 0 | 0, 0A, 0.5, 1, 2, 3, 4 | Absolute path của dự án target (argument hoặc CWD) |
| `$WORK_DIR` | Phase 0 | All | `.mc-data/work/legacy-scan/` — root of all artifacts |
| `$MATURITY_LEVEL` | Phase 0 (via script) | 0A, 0.5, 1, 4 | `CODE_ONLY` / `CODE_PLUS_EXTERNAL_DOCS` / `CODE_PLUS_DEVKIT_PARTIAL` / `CODE_PLUS_DEVKIT_COMPLETE` / `NEAR_COMPLETE` / `DOCS_ONLY` |
| `$STRATEGY` | Phase 0A | 0.5, 1, 2, 3, 4 | `S1` .. `S7` — driving pipeline routing |
| `$STAGE_MODES` | Phase 0A (+ 0.5 override) | 2, 3, 4 | Object map stage → `full/skip/delta/create/merge/validate/fast-track` |
| `$PROJECT_SIZE` | Phase 0 | 0A, 1, 2, 3 | `SMALL` / `MEDIUM` / `LARGE` — driving batch sizes & checkpoint strategy |
| `$LPM_PARAMS` | Phase 0 | 1, 2, 3 | Object `{batch_size, checkpoint_strategy, max_parallel_agents}` |
| `$TECH_STACK_VERIFIED` | Phase 0 | 0A, 1, 4 | Boolean — phải `true` trước khi Stage 0A chạy |
| `$USER_FLAG_RE_VISION` | Phase 0 | 0A | Boolean — true nếu `--re-vision` trong arguments |
| `$BATCH_SIZE` | Phase 0 | 2 (downstream) | Integer — default 100, override qua `--batch-size=N` |
| `$INCREMENTAL` | Phase 0 | 0A, 1, 2, 3 | Boolean — true nếu `--incremental`. Kích hoạt staleness + delta-plan per layer (Phase F F.3). |
| `$SINCE_REF` | Phase 0 | 0A, 1 | String — git ref (VD `HEAD~5`). Kèm `--incremental` để dùng `git diff` thay mtime compare. Require git repo. |
| `$NO_CACHE` | Phase 0 | 2, 3, 4 | Boolean — true nếu `--no-cache`. Bypass `ScanCache` get/set trong mọi layer. |
| `$CACHE_PUBLISH` | Phase 0 | 4 (post-scan) | Boolean — true nếu `--cache-publish`. Promote session cache → project cache sau khi scan xong. |
| `$CONTEXT_PERCENT` | Every phase | Every phase | Context budget usage — trigger checkpoint tại 65/80/90% |
| `error_log[]` | All phases | All phases | Array errors cumulative — ghi vào `error-ledger.json` |

---

## Cross-Phase Data Flow

```
Phase 0 (detection)    → project-profile.json, legacy-scan-status.json, legacy-scan-plan.md,
                          error-ledger.json, $PROJECT_PATH, $MATURITY_LEVEL, $PROJECT_SIZE,
                          $TECH_STACK_VERIFIED, $LPM_PARAMS
Phase 0A (assessment)  → assessment-report.json, ledger.json (strategy + stage_modes),
                          $STRATEGY, $STAGE_MODES
Phase 0.5 (maturity)   → [override] ledger.maturity + $STAGE_MODES          [CHỈ DEVKIT_PARTIAL+]
Phase 1 (inventory)    → inventory/*.json (screens, api-endpoints, doc-files, source-files,
                          dependency-graph, external-docs, ui-manifest*, doc-classified**),
                          ledger.summary.total_items, session-digest.md
Phase 2 (classify)     → classified/batch-*.json, glossary.json, classify-naming-fixes.json
                          (do Agent delegate tới /wf-legacy-classify)
Phase 3 (extract)      → extracted/{module}.json, module-code-mapping.json, dedup-report.json
                          (do Agent delegate tới /wf-legacy-extract)
Phase 4 (synthesize)   → project-context.md, doc-quality-map.json, impl-status-snapshot.json,
                          ledger.pipeline_status = "COMPLETE"
```

`*` ui-manifest chỉ tạo khi `screens.count > 0`. `**` doc-classified chỉ tạo khi `$MATURITY_LEVEL == DOCS_ONLY`.

---

## LEGACY_MODE Detection

> CORE-021: Tất cả shared skills downstream detect LEGACY_MODE bằng cùng 1 mechanism.

```bash
# Canonical bash syntax (matches wf-plan-modules, wf-implement-feature)
LEGACY_MODE=$(test -f .mc-data/work/legacy-scan/project-context.md \
  && test $(wc -c < .mc-data/work/legacy-scan/project-context.md) -gt 500 \
  && echo "true" || echo "false")
```

- KHÔNG detect bằng `ledger.json` (false positive — tồn tại từ Phase 0)
- `project-context.md` là anchor duy nhất cho downstream skills
- Phase 4 Synthesize là điểm duy nhất tạo file này

---

## Project Size Tiers

Xác định tại Phase 0 sau detection script. Ảnh hưởng `$LPM_PARAMS`.

| Tier | Điều kiện | LPM | Batch | Checkpoint | Sessions |
|------|-----------|-----|-------|------------|----------|
| `SMALL` | `total_files < 100` | OFF | All-at-once | Cuối pipeline | 1 |
| `MEDIUM` | `100 <= total_files <= 500` | PARTIAL (max 3 agents) | batch=200 | Per stage | 1-2 |
| `LARGE` | `total_files > 500` | FULL | batch=100 | Per 3 batches | 3+ |

> **Backward compatible:** LARGE tier = behavior cũ của v1.

---

## Tech Stack Verification Protocol (CORE-014)

> Áp dụng tại Phase 0 Step 0.5b. Bắt buộc sau detection. Cross-validate tech stack bằng code evidence,
> KHÔNG suy luận từ docs/README.

```
TECH STACK VERIFICATION:

1. Backend framework:
   - Đọc *.csproj → parse <TargetFramework> (vd: net8.0, net10.0)
   - Đọc *.sln → list projects
   - KHÔNG suy luận version từ docs hay README

2. Frontend framework:
   - Đọc package.json → check dependencies (next, react, vue, angular)
   - Phân biệt: Next.js (có "next" dep) vs React+Vite (có "vite" + "react" NHƯNG KHÔNG có "next")
   - Parse version chính xác từ package.json

3. Authentication:
   - Scan code patterns: JWT middleware, OAuth config, Keycloak config
   - KHÔNG đọc .env.example để xác định auth provider (config ≠ implementation)
   - Ưu tiên: code evidence > config evidence > doc evidence

4. Database/ORM:
   - Parse NuGet packages (*.csproj → <PackageReference>) hoặc package.json dependencies
   - Xác định version chính xác

5. Infrastructure services:
   - Đọc docker-compose.yml → list services
   - PHÂN BIỆT: "application dependency" (code import/reference) vs "infrastructure service" (chỉ trong docker-compose)
   - Label mỗi service: REQUIRED (code references) | OPTIONAL (infra only)

OUTPUT: Cập nhật project-profile.json với:
  "tech_stack_verified": true,
  "verification_method": "code_parse" | "config_parse" | "doc_infer",
  "confidence_per_item": { "backend": 0.95, "frontend": 0.95, ... },
  "infra_services": [{ "name": "...", "type": "REQUIRED|OPTIONAL", "source": "..." }]

NẾU verification FAIL (không parse được bất kỳ tech stack nào):
  → tech_stack_verified = false
  → WARNING, tiếp tục nhưng ghi note cần manual review
```

---

## External Docs Scan Protocol

> Áp dụng tại Phase 1 Step 1.6b. Tìm và inventory toàn bộ tài liệu ngoài source code
> (business docs, integration specs, infra configs).

```
EXTERNAL DOCS SCAN:

1. Tìm docs/ directory (hoặc tương đương: documentation/, doc/, wiki/) trong project root
2. Tìm thêm: infra/, deploy/, k8s/, helm/, monitoring/ directories
3. Inventory ALL doc files (*.md, *.docx, *.pdf, *.yaml trong infra dirs) — không chỉ source code

4. Classify docs:
   - "business-policy" — policies, SLAs, pricing rules, business logic docs
   - "legacy-analysis" — existing system analysis, migration docs, competitor analysis
   - "integration-spec" — API specs, 3rd party integration docs, OpenAPI/Swagger
   - "infrastructure" — K8s manifests, Helm charts, monitoring configs (Prometheus/Grafana/Loki), CI/CD
   - "user-guide" — user stories, UX specs, user manuals

5. Persist vào inventory/external-docs.json:
   {
     "total_docs": N,
     "categories": {
       "business-policy": [{ "path": "...", "title": "...", "size_bytes": N }],
       "legacy-analysis": [...],
       "integration-spec": [...],
       "infrastructure": [...],
       "user-guide": [...]
     }
   }

6. Nếu 0 external docs found → ghi empty categories (valid), log info

DOWNSTREAM USAGE:
- Business policies → enrich Phase 0 policies (brainstorm legacy flow)
- Legacy analysis → enrich Phase 1 context (analyze-requirements legacy flow)
- Integration specs → enrich Phase 3 integration-map (design legacy flow)
- Infrastructure → enrich Phase 3 infra-spec
```

---

## Pipeline Data Persistence Rules

> Áp dụng cho tất cả phases. Đảm bảo working data LUÔN persist vào files, không chỉ in-memory.

```
PIPELINE PERSISTENCE:

1. Tất cả working data PHẢI persist vào files (KHÔNG chỉ lưu stats vào ledger)
2. Validate sau mỗi phase: directory KHÔNG được empty
3. Nếu inventory/ empty sau scan → ERROR E004, không proceed
4. Checkpoint PHẢI ghi vào file trước khi báo "completed"
5. Khi skill bị interrupt (context limit, user cancel):
   - Save checkpoint với current stage + progress
   - Log: "Skill interrupted. Run --resume to continue"
6. Mọi write JSON/MD vào ledger.json, legacy-scan-status.json, error-ledger.json
   PHẢI dùng Atomic Write Pattern (xem section dưới) để tránh corrupt khi interrupt.
```

---

## Dual-Status Mirror Protocol (v5.0)

> BAT BUOC sau moi lan update stage/layer status. Ghi song song 2 file de
> backward-compat (`legacy-scan-status.json` v4.1) + canonical (scan-state.json v5.0).

Moi phase khi update status PHAI goi ca 2 writes:

```bash
# Khi mark stage X completed — vi du Phase 1 Inventory:
# 1. Legacy path (v4.1 compat — se bo o v5.1):
jq '.stages.inventory.status = "completed"' \
  .mc-data/work/legacy-scan/legacy-scan-status.json > "$TMP1" && \
  mv "$TMP1" .mc-data/work/legacy-scan/legacy-scan-status.json

# 2. Canonical path (v5.0 — ADR-LS04/LS05):
# Map: phase 1 → layer L3 (inventory), phase 2 → L4 (classify), phase 3 → L5 (extract), phase 4 → L6 (synthesis)
jq '.layers.L3.status = "completed" | .last_completed = "L3"' \
  "$SESSION_DIR/scan-state.json" > "$TMP2" && \
  mv "$TMP2" "$SESSION_DIR/scan-state.json"
```

**Mapping phase → layer:**
| Phase | Layer (scan-state.layers.*) |
|-------|-----------------------------|
| 0 Detection | L1 (discovery) |
| 0A Assessment | L2 (assessment) |
| 0B Profile | L2 (augments IPS) |
| 0.5 Maturity | L2 (augments) |
| 1 Inventory | L3 (inventory) |
| 2 Classify | L4 (classification) |
| 3 Extract | L5 (extraction) |
| 4 Synthesize | L6 (synthesis) |

Khong goi mirror → `--status` hien thi stale (L3-L6 luon not_started dau da completed) →
`--resume` chon sai resume point.

---

## Template Metadata Stripping

> Templates (scan-state.json, domain-hints.json, impact-graph.json, fix-workload.json, etc.)
> chứa field `_template_notes` để document schema intent. KHI POPULATE runtime, PHAI strip field này:

```bash
# Pattern bat buoc cho moi READ-TEMPLATE step:
jq 'del(._template_notes, ._schema_notes, ._notes)' "$TEMPLATE_PATH" \
  | jq '. + {"field1": $f1, ...}' --arg f1 "value" \
  > "$OUTPUT_PATH"
```

Neu khong strip: consumer downstream se thay field `_template_notes` trong output runtime →
pollute data + confusing. POST-GATE nao validate `has("_template_notes") | not` deu fail.

---

## Atomic Write Pattern

> CORE-006 Safe-Write + Pipeline Persistence Rule §6. Áp dụng cho mọi file shared state
> (`ledger.json`, `legacy-scan-status.json`, `error-ledger.json`).

```bash
# Pattern bắt buộc cho ledger.json + legacy-scan-status.json + error-ledger.json:
TARGET=".mc-data/work/legacy-scan/ledger.json"
TMP="${TARGET}.tmp.$$"

# 1. Build new content vào tmp file (jq edit hoặc Write)
jq '.stages.detection.status = "completed"' "$TARGET" > "$TMP"

# 2. Validate tmp file pass JSON parse
jq '.' "$TMP" > /dev/null || { rm -f "$TMP"; echo "FAIL: invalid JSON"; exit 1; }

# 3. Atomic move (POSIX guarantees mv atomic on same FS)
mv "$TMP" "$TARGET"
```

**Lý do:**
- `Write tool` ghi đè trực tiếp → nếu interrupt giữa chừng → file 0 bytes hoặc partial JSON.
- `jq > tmp && mv` đảm bảo target hoặc giữ nguyên cũ, hoặc đã được replace bằng tmp valid.
- Khi dùng `Edit tool` cho JSON: phải re-read sau Edit, validate `jq '.'`, nếu fail → revert.

**KHÔNG áp dụng cho:**
- File MD output cuối (project-context.md, session-digest.md, phase-summary.md) — nếu corrupt, rerun phase tạo lại được.
- File trong `inventory/`, `classified/`, `extracted/` — script tự handle.

---

## Agent Prompt Templates (Stage 2 & 3)

> Phase 2 & Phase 3 delegate work cho sub-skills qua Agent tool với bounded context.
> Main context KHÔNG tin agent output — luôn POST-GATE validate bằng Read/Bash.
>
> **Phase D update:** subagent_type chuyển từ `general-purpose` sang `code-reviewer` (Phase 2) và
> `business-analyst`/`[domain]-expert` (Phase 3) — direct spawn, không còn wrapper.
> Depth + IPS context được thêm vào prompt.
>
> **Agent selection rationale:**
> - Phase 2 Classify dùng `code-reviewer`: task đọc source files, phân loại theo module/layer,
>   detect naming conventions — overlap mạnh với code-reviewer's expertise (pattern recognition,
>   dependency analysis, code structure). Agent đọc SKILL.md của `/wf-legacy-classify` như script
>   hướng dẫn — có đủ tool permissions (Read/Grep/Glob/Write/Bash) + Python helpers trong _shared/.
> - Phase 3 Extract dùng `business-analyst` primary + `[domain]-expert` secondary: task là trích
>   xuất business requirements/features từ code — overlap với BA expertise. Domain expert (theo
>   IPS Phase B routing, confidence ≥ 0.6) enrich knowledge layer domain-specific.
> - Nếu sub-skill SKILL.md yêu cầu capability không có (vd low-level bash orchestration), agent
>   sẽ fail gracefully → POST-GATE catch → auto-fix re-spawn hoặc escalate.

### Stage 2 Classify Prompt (subagent_type: code-reviewer)

```
Bạn đang thực hiện Stage 2 (Classify) của legacy scan pipeline.
Đọc file .claude/skills/workflow/wf-legacy-classify/SKILL.md và thực thi đầy đủ.

Working directory: .mc-data/work/legacy-scan/
Prerequisites đã hoàn tất:
- scan-state.layers.L3.status == "completed" (HOẶC ledger.json Stage 1 completed — v4.1 compat)
- inventory/ có dữ liệu (screens, api-endpoints, source-files, doc-files, dependency-graph, external-docs)
- project-profile.json có tech_stack_verified=true

[PHASE D CONTEXT]
- Depth: [$DEPTH_L4]  (surface/standard/deep)
- Batch size: [$BATCH_SIZE]  (default 100, --batch-size=N CLI override propagated)
- IPS Phase A detected domains: [top 3 với confidence từ read_ips_phase_a()]
- Naming convention: lowercase-kebab-case (CORE-016/017) — dedup case-insensitive

[DEEP MODE additions — nếu $DEPTH_L4 == "deep"]
- Hot-signal files: [unresolved_patterns từ ips.phase_a]
- Confidence target ≥ 0.85 (vs 0.75 standard)
- Secondary spawn business-analyst cho glossary enrichment sau khi xong

Khi hoàn tất, báo cáo:
- Số items classified
- Glossary size (số terms)
- Bất kỳ errors nào
- classify-naming-fixes.json có được tạo (CORE-016)
```

### Stage 3 Extract Prompt (subagent_type: business-analyst primary; domain-expert secondary per module)

```
Bạn đang thực hiện Stage 3 (Extract) của legacy scan pipeline.
Đọc file .claude/skills/workflow/wf-legacy-extract/SKILL.md và thực thi đầy đủ.

Working directory: .mc-data/work/legacy-scan/
Prerequisites đã hoàn tất:
- Classify completed (classified/batch-*.json + glossary.json có dữ liệu HOẶC auto-grouped.json cho surface)
- scan-state.layers.L4.status ∈ {"completed", "skipped_by_profile"}

[PHASE D CONTEXT]
- Depth: [$DEPTH_L5]  (skip/surface/standard/deep/exhaustive)
- IPS Phase B routing: [module_routing từ read_ips_phase_b()]
  • per-module domain assignments với confidence ≥ 0.6 threshold (ADR-LS06)
- Complexity hotspots: [top 5 modules by file_count + coupling]
- Workload estimate: [total_features_est, est_time_min]

[SPAWN STRATEGY per $DEPTH_L5]
- standard: BA + DE parallel, max 3 per group
- deep: BA → DE sequential cross-validation; confidence target ≥ 0.8
- exhaustive: deep + divergence detection (from_code vs from_docs)

[CORE-029 SPOT-CHECK]
Sau mỗi module extract: sample 3 random requirements — verify TMP-ID format,
source_files exist, confidence ∈ [0,1], description ≥ 20 chars.

Khi hoàn tất, báo cáo:
- Số modules extracted
- Avg confidence score
- Dedup results (total duplicates merged)
- module-code-mapping.json tồn tại và hợp lệ
- CORE-029 spot-check pass/fail count
```

---

## Strategy & Stage Mode Reference

> Chi tiết logic trong `phase0a-assessment.md` (Strategy Routing Logic + Strategy-to-Modes Mapping).
> Bảng này chỉ để reference nhanh khi phase downstream đọc `$STRATEGY` và `$STAGE_MODES`.

**Stage Mode Decision Table** (full reference):

> Maturity enum full names: `CODE_ONLY`, `CODE_PLUS_EXTERNAL_DOCS`, `CODE_PLUS_DEVKIT_PARTIAL`, `CODE_PLUS_DEVKIT_COMPLETE`, `NEAR_COMPLETE`, `DOCS_ONLY`. Table headers short-hand cho readability.

| Stage | CODE_ONLY | CODE+EXT_DOCS | CODE+DEVKIT_PARTIAL | CODE+DEVKIT_COMPLETE | NEAR_COMPLETE | DOCS_ONLY |
|-------|-----------|---------------|---------------------|----------------------|---------------|-----------|
| 0 Detection | full | full | full | full | full | full |
| 0A Assessment | full | full | full | full | full | full |
| 0.5 Maturity Val | skip | skip | run | run | run | skip |
| 1 Inventory | full | full | full | full | full | full |
| 2 Classify | full | full | delta | delta | skip | full\* |
| 3 Extract | full | full | delta | skip | skip | full\* |
| 4p Phase 0 | create | create | merge | validate | skip | create |
| 4a Phase 1 | create | create | merge | validate | skip | create |
| 4b Phase 2 | create | create | merge | validate | skip | create |
| 4c Phase 3 | create | create | merge | validate | skip | create\* |
| 4d Registry | create | create | merge | validate | skip | create |
| 5 Gap Analysis | full | full | full | full | fast-track | full\* |

> `*` DOCS_ONLY: classify/extract dùng docs làm primary source, confidence cap 0.7. Phase 3 architecture = `create` nhưng limited. Gap analysis = coverage analysis.
> Rows Stage 2-5 là reference cho downstream skills. Strategy + stage_modes ghi vào `ledger.json`.

**7 Strategies** (quick reference):

| ID | Name | Typical maturity |
|----|------|------------------|
| S1 | FAST-TRACK | DEVKIT_COMPLETE/NEAR_COMPLETE + HIGH alignment |
| S2 | CODE-FIRST | CODE_ONLY, MED+ code (default) |
| S3 | DOCS-FIRST | DOCS_ONLY, HIGH docs |
| S4 | DOCS-BRAINSTORM | DOCS_ONLY, LOW docs |
| S5 | DIVERGENCE-RESOLVE | EXTERNAL_DOCS + LOW alignment |
| S6 | RE-VISION | User explicit `--re-vision` |
| S7 | FULL-REBUILD | CODE_ONLY, LOW code |

---

## Fix Rules

| Error Type | Auto-Fix Strategy | Escalate If |
|-----------|-------------------|-------------|
| `detection_failed` | Retry script x3 với verbose logging | Vẫn fail sau 3 lần |
| `inventory_empty` | Retry x3 với broader patterns | Vẫn 0 items sau retry |
| `context_overflow` | FORCE checkpoint, STOP | — |
| `stale_items_30pct` | WARN, recommend full re-scan | — |
| `post_gate_t1_t4_fail` | Retry phase x1 với verbose logging | Vẫn fail → escalate user |
| `template_missing` | Đọc lại template từ git history (git show HEAD:path) | Không có history → escalate |
| `agent_output_invalid` | Re-spawn agent x1 với prompt nhấn mạnh schema | Vẫn invalid → STOP, gợi ý standalone re-run |

---

## Auto-Fix & Escalation Protocol (Protocol 1, 2)

> Áp dụng SAU mỗi POST-GATE. Mục tiêu: tự sửa lỗi nhỏ, không làm phiền user khi không cần.

```
WORKFLOW khi POST-GATE Tier T1-T4 fail (canonical semantic — v5.0 unified):

BUDGET MODEL: PER-PHASE (max 3 retries total / phase), KHONG phai per-tier.
  - Moi tier fail trigger 1 attempt fix → increment $RETRY_COUNT[$PHASE]
  - Khac tier cung share 1 budget
  - Reset $RETRY_COUNT[$PHASE] = 0 khi POST-GATE PASS

1. ATTEMPT auto-fix theo Fix Rules table:
   - T1 fail (file missing) → re-run step tao file
   - T2 fail (structure wrong) → re-read template + populate lai
   - T3 fail (content too short) → re-generate voi more context
   - T4 fail (cross-ref mismatch) → re-read source + re-write target

2. Retry counter ($RETRY_COUNT[$PHASE]):
   - PERSISTED trong scan-state.retries[$PHASE] — survive --resume (v5.0 fix)
   - Init tu error-ledger.json khi resume (count entries phase hien tai)
   - Tang sau moi attempt (bat ke tier nao)
   - Reset = 0 khi PASS

3. ESCALATE khi:
   - $RETRY_COUNT[$PHASE] >= 3 → STOP voi error message
   - Hoac auto-fix khong kha thi (vd: agent output invalid hoan toan)

4. ESCALATION format:
   - Hien AskUserQuestion voi options: "Re-run phase manually" / "Skip phase (risky)" / "Cancel"
   - Append entry vao error-ledger.json: {phase, error_code, retry_count, escalation_reason, timestamp}

NOTE: phase files noi "max 1 retry per tier" deprecated — nhat quan theo
per-phase budget. Neu phase file con wording cu, tuan theo per-phase rule.
```

---

## Error Handling

> **Canonical table (SSOT).** Phase-specific codes tham chieu den bang nay + phase file rieng.
> SKILL.md duy tri quick-lookup table nhung _shared.md la authority.

### Namespace convention (v5.0)
- **E001-E014** pipeline/session/lock
- **E015-E019** phase 0 detection
- **E020-E029** phase 0B profile resolver
- **E030-E039** phase 0.5 maturity (reserved)
- **E040-E049** phase 2/3 agent delegation
- **E0101-E0199** phase 1 workload gate
- **E-L6-XX** phase 4 synthesis non-blocking
- **W0B0X, W0101-W0102, I0101, W-L6-XX** warnings / info

### Canonical codes

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E001 | Project path không tồn tại | STOP |
| E002 | Project path trống (0 files) | STOP |
| E003 | Script detect thất bại | Auto-fix theo Auto-Fix Protocol (max 3), STOP |
| E004 | Inventory 0 items | Auto-fix theo Auto-Fix Protocol (max 3), STOP |
| E005 | Pipeline đã COMPLETE | ASK: re-scan / cancel |
| E006 | `scan-state.json` corrupt on resume | Fallback legacy `ledger.json` (ADR-LS04 graceful) |
| E007 | Lock held by other process | STOP — inform user, wait or `--session=ID` |
| E008 | Lock stale (>= LOCK_STALE_MINUTES) | Auto-release, WARN, continue |
| E009 | Cache read error | Bypass cache, continue |
| E010 | IPS-A/B failure (non-blocking) | Fallback profile=standard, log warning |
| E011 | Workload Gate user chose abort | Clean exit, pipeline_status=aborted_by_workload_gate |
| E012 | Context > 90% | FORCE checkpoint, STOP |
| E013 | >30% stale khi resume | WARN, AskUserQuestion |
| E014 | Rollback module không tồn tại (reserved) | STOP |

### Phase-specific codes (defined in phase files)

| Code range | Owner phase | See |
|-----------|-------------|-----|
| E015-E019 | Phase 0 Detection — incremental flag validation | `phase0-detection.md §Incremental Flag Validation` |
| E020-E025 | Phase 0B Profile Resolver — invalid profile/layer/depth | `phase0b-profile.md §Error Codes` |
| E040-E049 | Phase 2/3 agent output / CORE-029 spot-check | `phase3-extract.md §CORE-029` |
| E0101 | Phase 1 Workload Gate abort | `phase1-inventory.md §Workload Gate` |
| W-L6-02 | Phase 4 impact-graph build failure (non-blocking warning) | `phase4-synthesize.md §Impact Graph Build` |
| W0B01-W0B05 | Phase 0B warnings | `phase0b-profile.md §Warning Matrix` |
| W0101-W0102, I0101 | Phase 1 Workload Gate info/warn | `phase1-inventory.md §Workload Gate` |

---

## On Failure — Standard Format

> Áp dụng cho mọi phase. Khi POST-GATE fail hoặc step quan trọng fail, phase PHẢI đi qua flow này.

```
ON FAILURE (BẮT BUỘC mỗi phase):

1. APPEND error-ledger.json (xem Atomic Write Pattern):
   {
     "phase": "[phase-id]",
     "error_code": "[E001-E018]",
     "message": "[mô tả ngắn]",
     "timestamp": "ISO-8601",
     "retry_count": $RETRY_COUNT[$PHASE]
   }

2. AUTO-FIX qua Auto-Fix & Escalation Protocol (max 3 retries / phase).

3. Nếu vẫn fail sau retry:
   a. WRITE phase-summary.md với status=FAILED + reason (xem Phase Summary section)
   b. WRITE session-log.json entry FAIL (xem Execution Trace section)
   c. UPDATE legacy-scan-status.json: stages.[phase].status = "failed"
   d. STOP pipeline + AskUserQuestion: "Re-run --resume / Cancel / Open issue"

4. KHÔNG advance sang phase tiếp theo khi POST-GATE chưa pass.
```

---

## Execution Trace (CORE-026)

> Mọi phase ghi START/COMPLETE/FAIL events vào **HAI** session log để observability.
> CORE-026: output-only — KHÔNG đọc lại file này làm input context.
>
> **Hai log song song (đều cần):**
> 1. **Global skill-level (CORE-026):** `.mc-data/work/_trace/session-log.json` —
>    dùng cho audit/metrics toàn hệ thống (mọi skill chung).
> 2. **Session-scoped (v5.0 ADR-LS05):** `$SESSION_DIR/session-log.json` —
>    dùng cho `--status`/`--resume` của wf-legacy-scan (session isolation).
>
> Cả hai được append cùng nội dung event. `_contract.json` declare session-scoped path.

```
EVENT FORMAT:
{
  "timestamp": "ISO-8601",
  "skill": "wf-legacy-scan",
  "phase": "[phase-id]",      // 0, 0A, 0B, 0.5, 1, 2, 3, 4
  "event": "START|COMPLETE|FAIL",
  "duration_ms": [int, only on COMPLETE/FAIL],
  "metadata": { ... }          // optional, e.g. items_processed, retry_count
}

WHEN TO WRITE:
- START: ngay sau PRE-GATE pass, trước Step đầu tiên
- COMPLETE: ngay sau POST-GATE pass
- FAIL: trong On Failure flow §3.b

PATTERN (atomic append — dual-write):
GLOBAL_TRACE=".mc-data/work/_trace/session-log.json"
SESSION_TRACE="${SESSION_DIR:-.}/session-log.json"

mkdir -p "$(dirname "$GLOBAL_TRACE")"
for TARGET in "$GLOBAL_TRACE" "$SESSION_TRACE"; do
  [ -z "$TARGET" ] && continue
  [ ! -s "$TARGET" ] && echo "[]" > "$TARGET"
  TMP="${TARGET}.tmp.$$"
  jq --arg ts "$(date -Iseconds)" --arg ph "$PHASE" --arg ev "START" \
     '. + [{timestamp:$ts, skill:"wf-legacy-scan", phase:$ph, event:$ev}]' \
     "$TARGET" > "$TMP" && mv "$TMP" "$TARGET"
done
```

---

## Phase Summary (CORE-028)

> Mọi phase TẠO `phase-summary.md` sau POST-GATE — viết tiếng Việt, ≤15 dòng,
> dành cho non-specialist (chủ doanh nghiệp / non-tech user) đọc hiểu tiến độ.

```
PATH: .mc-data/work/legacy-scan/phase-summary.md
WRITE-MODE: APPEND mỗi phase một section (không ghi đè) — file accumulate qua phases.

SECTION FORMAT (tiếng Việt, ≤15 dòng):

## Phase [X]: [Tên phase] — [PASS|FAIL|SKIPPED]
Thời gian: [ISO-8601]

**Đã làm gì:**
- [1-2 câu mô tả hành động chính, ngôn ngữ thường dân]

**Kết quả:**
- [Số liệu chính: vd "Phát hiện 45 modules, 1200 source files"]
- [File đầu ra chính: vd "→ project-profile.json"]

**Tiếp theo:**
- [Phase kế tiếp HOẶC hành động user cần làm]

---

QUY TẮC:
- KHÔNG dùng jargon (LPM, CORE-014, jq) — viết cho người không chuyên
- ≤15 dòng MỖI section
- File tổng thể có thể nhiều phases → dài tối đa 7 phases × 15 dòng ≈ 105 dòng
```

---

## Task Planning (Protocol 9)

> Phase 0 (entry point) PHẢI init TodoWrite với danh sách 8 phases.
> Mỗi phase POST-GATE PASS → mark phase đó completed.

```
TODOWRITE INIT (Phase 0 Step 0.0):

todos = [
  {content: "Phase 0: Detection — verify tech stack", activeForm: "Detecting project structure"},
  {content: "Phase 0A: Assessment — chọn strategy S1-S7", activeForm: "Assessing maturity & alignment"},
  {content: "Phase 0B: Profile Resolver + IPS-A", activeForm: "Resolving scan profile + depth_map"},
  {content: "Phase 0.5: Maturity Validation (conditional)", activeForm: "Validating existing DEVKIT artifacts"},
  {content: "Phase 1: Inventory — enumerate artifacts", activeForm: "Building inventory"},
  {content: "Phase 2: Classify (delegate /wf-legacy-classify)", activeForm: "Classifying files"},
  {content: "Phase 3: Extract (delegate /wf-legacy-extract)", activeForm: "Extracting requirements"},
  {content: "Phase 4: Synthesize project-context.md", activeForm: "Synthesizing project context"}
]

UPDATE pattern (sau mỗi POST-GATE pass):
- Mark phase hiện tại = completed
- Mark phase kế tiếp = in_progress (trừ phase 0.5 conditional)

SKIP pattern (Phase 0.5 không chạy):
- Mark Phase 0.5 = completed với note "skipped — $MATURITY_LEVEL không đáp ứng"

FAIL pattern (POST-GATE fail sau auto-fix):
- Giữ phase = in_progress
- Thêm task mới: "Resolve [error_code] và --resume"
```

---

## Context & Checkpoint

| Context Usage | Hành động |
|---------------|-----------|
| < 65% | Tiếp tục |
| 65-80% | Chuẩn bị checkpoint |
| 80-90% | Lưu checkpoint, STOP sau stage hiện tại |
| > 90% | FORCE STOP (E012) |

Checkpoint files: `legacy-scan-status.json` + `ledger.json` + `session-digest.md` (~300 từ).

---

## Template Usage Rule (CORE-031)

> BẮT BUỘC: Mọi file có template PHẢI được tạo bằng pattern:
> 1. **READ** template file từ `templates/` directory
> 2. **POPULATE** values (thay thế placeholders)
> 3. **WRITE** output file
>
> KHÔNG viết từ đầu — luôn đọc template trước để đảm bảo đúng schema.
> Template files nằm tại: `.claude/skills/workflow/wf-legacy-scan/templates/`.

### Placeholder Convention (v5.0 canonical)

Templates dung 3 pattern placeholder tuy theo file type — **khong mix trong cung 1 file**:

| File type | Pattern | Lý do | Vi du |
|-----------|---------|-------|-------|
| JSON templates moi (v5.0+) | `{{VAR_NAME}}` | jq friendly, regex clear | `scan-state.json`, `domain-hints.json`, `impact-graph.json` |
| Markdown templates | `[VAR_NAME]` hoac `[TEN_DU_AN]` | Readability as prose | `project-context.md`, `legacy-scan-plan.md` |
| JSON legacy (v4.1) | Empty strings `""` / `0` / `[]` | Populate by setting field values | `project-profile.json`, `assessment-report.json`, `ledger.json` |

**Khi populate:**
- JSON `{{VAR}}` → regex `s/"{{VAR}}"/actual-value/` HOAC `jq 'del(._template_notes)' | jq '. + {field: value}'`
- MD `[VAR]` → `sed "s/\[VAR\]/actual-value/g"` (escape brackets)
- JSON empty → `jq '.field = "value"'`

Template migrate sang `{{VAR}}` pattern se dien ra dan o v5.1+.

Templates được phân bổ theo phase (xem `Output Files` trong SKILL.md).
