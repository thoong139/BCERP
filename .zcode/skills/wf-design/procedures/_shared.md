# Shared Protocols — wf-design

> Cross-cutting protocols, state variables glossary, architecture labels,
> LEGACY context injection spec và agent prompt templates được sử dụng bởi
> nhiều Phase trong wf-design.
> KHÔNG đọc file này standalone — chỉ load section cụ thể khi cần.

## Sections

- [State Variables Glossary](#state-variables-glossary)
- [Phase → File Mapping](#phase--file-mapping)
- [Cross-Phase Data Flow](#cross-phase-data-flow)
- [Session Isolation Protocol (ADR-OPT-02)](#session-isolation-protocol-adr-opt-02)
- [_shared Module Imports (ADR-OPT Integration)](#_shared-module-imports-adr-opt-integration)
- [Large Project Mode (LPM)](#large-project-mode-lpm)
- [Architecture Documentation Labels](#architecture-documentation-labels)
- [Fix Rules đặc thù](#fix-rules-đặc-thù)
- [Registry Safe-Write](#registry-safe-write)
- [Token Limit Prevention](#token-limit-prevention)
- [LEGACY Context Injection](#legacy-context-injection)
- [Business Context Injection (v4.1)](#business-context-injection-v41)
- [Agent Prompt Templates](#agent-prompt-templates)
- [Checkpoint Protocol](#checkpoint-protocol)
- [LEGACY_MODE Detection](#legacy_mode-detection)

---

## State Variables Glossary

Các biến in-memory được set/đọc xuyên suốt skill execution.

| Variable | Set by Phase | Read by Phase | Description |
|----------|--------------|---------------|-------------|
| `$LEGACY_MODE` | Phase 0 | 0–8 | Boolean — true nếu `project-context.md > 500 bytes` (CORE-021) |
| `$LEGACY_CONTEXT` | Phase 0 | 1–7 (agent spawns) | Nội dung `project-context.md` (LEGACY) |
| `$LEGACY_DECISIONS` | Phase 0 | 1–7 | Nội dung `legacy-decisions.json` (LEGACY) |
| `$DEPRECATED_MODULES` | Phase 0 | 1, 5, 7 | Array module IDs có `action="DEPRECATE"` — KHÔNG design architecture cho modules này |
| `$REGISTRY_DATA` | Phase 0 | 1, 4, 5, 6, 7, 8 | Parsed JSON từ `req-registry.json` |
| `$APPROACH` | Phase 0 | 1 | `Module` / `System` / `Platform` Design |
| `$TARGET_SYSTEMS` | Phase 0 | 1 | Array systems thuộc scope design |
| `$TARGET_MODULES` | Phase 0 | 1 | Array modules thuộc scope design |
| `$HAS_AI_ML` | Phase 0 | 1 | Boolean — domain có AI/ML → spawn `ai-engineer` |
| `$HAS_DATA_PIPELINE` | Phase 0 | 1 | Boolean — domain có ETL/pipeline → spawn `data-engineer` |
| `$HAS_AUTOMATION` | Phase 0 | 1 | Boolean — domain có workflow automation → spawn `automation-architect` |
| `$LARGE_PROJECT` | Phase 0 | 1, 2, 3, 5 | Boolean — `systems.length >= 5 OR features.length >= 40` |
| `$LPM_PARAMS` | Phase 0 | 1, 2, 3, 5 | Object `{compression_threshold, digest_size, skeleton_threshold, max_parallel_agents, checkpoint_strategy}` |
| `$FEATURE_DIGEST_PATH` | Phase 0 | 1, 2, 3 | Path tới `feature-digest.md` (nếu compression triggered) |
| `$BUSINESS_CONTEXT` | Phase 1 (Step 1.0) | 1–5 (agent spawns) | Nội dung `business-context.md` — actor/role matrix, business object lifecycle, cross-module deps, ownership rules, exception events. Inject vào mọi agent prompt (xem §Business Context Injection) |
| `$CONTEXT_PERCENT` | Every phase | Every phase | Context budget usage — trigger checkpoint at 65/80% |
| `$AGENTS_SPAWNED` | Every phase | Phase 8 | Array — log agents đã spawn (name, phase, status) |
| `$SESSION_DIR` | Phase 0 | 0.5–8 | `.mc-data/work/wf-design/sessions/{YYYYMMDD-HHMMSS}-{hash4}/` — session-scoped working dir |
| `$SESSION_ID` | Phase 0 | 0.5–8 | `YYYYMMDD-HHMMSS-{hash4}` — unique ID per run |
| `$WORKLOAD_ESTIMATE` | Phase 0.5 | 0.5 (report) | Số phút ước tính tổng workflow từ workload_gate |
| `$GATE_RESULT` | Phase 0.5 | 0.5 (decision) | `dead_zone` \| `warn` \| `block` — kết quả gate check |
| `$ACTIVE_SYSTEMS` | Phase 0 | 0.5, 1, 2 | `$TARGET_SYSTEMS` sau khi loại bỏ `$DEPRECATED_MODULES` |
| `$PARTITIONS` | Phase 0.5 | 1 | Array partitions từ plan_partitions() — mỗi partition: list systems |
| `error_log[]` | All phases | Phase 6, 8 | Array errors collected — dùng cho Auto-Correction Loop + report |

---

## Phase → File Mapping

| Phase | File | Mục đích |
|-------|------|----------|
| Phase 0 | `phase0-context.md` | Context Loading, LEGACY detect, LPM eval, Approach, Execution Plan, Session Init |
| Phase 0.5 | `phase0.5-workload-gate.md` | Workload estimation + gate evaluation (ADR-OPT-03) |
| Phase 1 | `phase1-architecture.md` | Architecture Overview — Lane Dispatch (ADR-OPT-01) |
| Phase 2 | `phase2-specs-parallel.md` | Technical Specs PARALLEL per system lane — API + DB + Infra |
| Phase 3 | `phase3-integration.md` | Integration Map + Signal Aggregation (ADR-OPT-04) |
| Phase 4 | `phase4-crossval.md` | Cross-Validation + conflict resolution từ aggregation |
| Phase 5 | `phase5-review.md` | Stakeholder Review (PARALLEL architect + security) |
| Phase 6 | `phase6-finalize.md` | Registry Safe-Write (`design_status`) + Compressed Spec |
| Phase 7 | `phase7-gap.md` | Gap Analysis — CHỈ LEGACY_MODE, KHÔNG lane-ify |
| Phase 8 | `phase8-digest-summary.md` | Digest artifact (Template Strip + Atomic Write) + Phase Summary |

**Phase Ordering:** `0 → 0.5 → 1 → 2 → 3 → 4 → 5 → 6 → [7 LEGACY] → 8`

---

## Cross-Phase Data Flow

```
Phase 0 (context)        → $REGISTRY_DATA, $APPROACH, $LARGE_PROJECT, $LPM_PARAMS,
                           $LEGACY_MODE, $LEGACY_CONTEXT, $DEPRECATED_MODULES,
                           $HAS_AI_ML, $HAS_DATA_PIPELINE, $HAS_AUTOMATION,
                           $SESSION_DIR, $SESSION_ID, $ACTIVE_SYSTEMS,
                           $SESSION_DIR/design-status.json, design-plan.md, execution-plan.md
Phase 0.5 (workload)     → $WORKLOAD_ESTIMATE, $GATE_RESULT, $PARTITIONS,
                           $SESSION_DIR/workload-report.md
Phase 1 (architecture)   → $SESSION_DIR/business-context.md ($BUSINESS_CONTEXT — Step 1.0, v4.1),
                           $SESSION_DIR/lanes/{sys}/signals.json,
                           P3-01-architecture.md
Phase 2 (specs parallel) → $SESSION_DIR/lanes/{sys}/specs-signals.json,
                           technical-specs/{api-contract,database-design,infra-spec}.md
Phase 3 (integration)    → $SESSION_DIR/aggregation-result.json (components + apis),
                           technical-specs/integration-map.md
Phase 4 (crossval)       → design-report.md (log), auto-fix results trong specs
Phase 5 (review)         → stakeholder-review.md (Phần A–D), deferred-findings.md
Phase 6 (finalize)       → registry.design_status = "completed",
                           $SESSION_DIR/design-summary.json (working copy),
                           .mc-data/work/wf-design/design-summary.json (canonical)
Phase 7 (gap)            → gap-report.md, gap-categories.json, action-items.json,
                           final-report.md                        [CHỈ LEGACY_MODE]
Phase 8 (digest)         → $SESSION_DIR/design-input-digest.json (working copy),
                           .mc-data/docs/_meta/design-input-digest.json (canonical sync),
                           phase-summary.md, session log
```

**Quy tắc:** Mỗi phase chỉ READ variables đã được SET ở phase trước. KHÔNG được SET lại variables của phase khác.

---

## Session Isolation Protocol (ADR-OPT-02)

Mỗi lần chạy `wf-design` tạo một session directory riêng biệt. Các runs không ghi đè lẫn nhau.

### Session Directory Structure

```
.mc-data/work/wf-design/sessions/{YYYYMMDD-HHMMSS}-{hash4}/
├── session-state.json             ← Trạng thái phases (primary checkpoint)
├── design-status.json             ← Runtime status (working copy)
├── checkpoint.json                ← Backward-compat mirror
├── workload-report.md             ← Phase 0.5 output
├── feature-digest.md              ← Phase 0 conditional
├── lanes/
│   ├── {system-slug}/
│   │   ├── signals.json           ← Lane 1: architecture signals
│   │   └── specs-signals.json     ← Lane 2: specs signals (api/db/infra)
│   └── ...
├── aggregation-result.json        ← Phase 3: components + APIs dedup
├── design-input-digest.json       ← Phase 8: working copy (pre-sync)
├── design-summary.json            ← Phase 6: working copy
└── phase-summary.md               ← Phase 8 CORE-028

latest pointer: .mc-data/work/wf-design/latest  (symlink/content = SESSION_ID)
```

### Session Init (Phase 0)

```python
import datetime, hashlib

ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
hash4 = hashlib.sha1(ts.encode()).hexdigest()[:4]
SESSION_ID = f"{ts}-{hash4}"
SESSION_DIR = f".mc-data/work/wf-design/sessions/{SESSION_ID}"
mkdir -p $SESSION_DIR/lanes/
```

### 3-Level Checkpoint (trong session-state.json)

```
L1 Phase:  phases.P{N}.status = pending | in_progress | completed | skipped
L2 Batch:  phases.P{N}.batches["{system-slug}"].status
L3 Item:   phases.P{N}.batches["{system-slug}"].items["{component/api-id}"].status
```

### Session Cleanup

Giữ tối đa **5 sessions** trong `sessions/`. Khi tạo session mới thứ 6, xoá session cũ nhất (theo timestamp prefix trong SESSION_ID). Không xoá session đang chạy (latest pointer trỏ tới).

### Canonical Sync (Phase 6 + 8)

Sau khi hoàn thành một phase sinh output canonical, SYNC từ session dir → working/canonical path:

| Session file | Canonical path | Sync at |
|---|---|---|
| `$SESSION_DIR/design-summary.json` | `.mc-data/work/wf-design/design-summary.json` | Phase 6 |
| `$SESSION_DIR/design-input-digest.json` | `.mc-data/docs/_meta/design-input-digest.json` | Phase 8 |
| `$SESSION_DIR/design-status.json` | `.mc-data/work/wf-design/design-status.json` | Phase 0 + mỗi phase |
| `$SESSION_DIR/checkpoint.json` | `.mc-data/work/wf-design/checkpoint.json` | Phase 0 + mỗi phase (backward-compat) |

---

## _shared Module Imports (ADR-OPT Integration)

Xem import convention tại `.claude/skills/workflow/_shared/_shared.md` §3-4.

```python
import sys
sys.path.insert(0, ".claude/skills/workflow/_shared")

from lane import dispatch_lanes, LaneConfig          # Phase 1-2: Lane Dispatch
from partition import plan_partitions, estimate_workload, check_workload_gate  # Phase 0.5
from aggregate import aggregate_lane_signals, dedup_by_id   # Phase 3-4
from cdg import create_cdg_token, check_anti_loop   # Phase 0.5 (CDG-A02)
from cache import get_cached, set_cached             # Phase 0.5 (cache layer)
```

| Module | Dùng tại Phase | Mục đích |
|--------|---------------|----------|
| `lane` | Phase 1, 2 | Dispatch parallel per-system lanes |
| `partition` | Phase 0.5 | Partition systems + workload gate |
| `aggregate` | Phase 3, 4 | Aggregate lane signals + dedup (component_id, api_id) |
| `cdg` | Phase 0.5 | CDG-A02 override token khi user chọn block-override |
| `cache` | Phase 0.5 | Content-hash để skip re-computation nếu REGISTRY unchanged |

**KHÔNG viết Python code trong procedure files** — procedure files là Markdown instructions tham chiếu các modules này.

---

## Large Project Mode (LPM)

> Protocol 6.6 — Khi `$LARGE_PROJECT = true`: áp dụng compression/skeleton sớm hơn, giảm parallel.

**Trigger:** `systems.length >= 5 OR departments.length >= 10 OR requirements.length >= 50 OR features.length >= 40`

**Parameter overrides:**

| Tham số | Standard | LPM | Dùng tại |
|---------|----------|-----|----------|
| `compression_threshold` | > 3 files | > 2 files | Phase 0 (feature-digest), Phase 1, 2, 3 (agent input) |
| `digest_size` | ~200 từ/file | ~300 từ/file (Extended) | Phase 0 (feature-digest) |
| `skeleton_threshold` | > 3000 từ | > 2000 từ | Phase 1 (P3-01 skeleton-first), Phase 2 (api-contract/database-design) |
| `max_parallel_agents` | 5 | 3 | Phase 1 (conditional agents), Phase 2 (specs), Phase 5 (review) |
| `checkpoint_strategy` | Per phase | Per phase + per sub-step | Phase 1, 2, 3 |
| `output_targets` | Standard column | Large Project Mode column | Tất cả agent prompts |

**LPM override khi >= 3 agents conditional:** Phase 1 có architect + bất kỳ conditional (ai-engineer/data-engineer/automation-architect) — nếu tổng >= 3 agents VÀ LPM = true → chạy SEQUENTIAL sau architect thay vì PARALLEL.

---

## Architecture Documentation Labels

> Convention cho mọi architecture document — cả NEW và LEGACY projects.

```
Label convention:
  [VERIFIED]    — Confirmed từ code/config (chỉ khi LEGACY_MODE, dựa trên module-code-mapping)
  [INFERRED]    — Có evidence gián tiếp (log references, config mentions)
  [RECOMMENDED] — Mới đề xuất, chưa có trong code

Agents PHẢI gắn label cho mỗi architecture decision:
  VD: "[VERIFIED] PostgreSQL 14 — confirmed from docker-compose.yml"
  VD: "[RECOMMENDED] Redis cache layer — không tìm thấy trong code hiện tại"

Khi LEGACY_MODE = false: tất cả decisions là [RECOMMENDED] (default, không cần ghi rõ label)
```

---

## Fix Rules đặc thù

| Loại lỗi | Auto-Fix | Escalate nếu |
|-----------|----------|---------------|
| `missing_ref` (REQ-ID không reference) | Tìm spec phù hợp → thêm reference | REQ-ID không match module nào |
| `missing_entity` (API endpoint không có entity) | Extract từ API contract → tạo DB entity | Không đủ thông tin infer schema |
| `invalid_module_ref` | Lookup correct module in registry → fix ref | Module không tồn tại trong registry |
| `incomplete_feature_spec` | Bổ sung missing sections từ architecture + registry context | Feature spec thiếu core info |
| `duplicate_def` | Merge vào single definition, update references | Ambiguous cấu trúc |
| `duplicate_error_code` | Tạo error code mới cho scenario trùng | Không thống nhất được scenario |
| `missing_db_entity_ref` | Thêm table/column DDL vào database-design.md | API contract mơ hồ về type |
| `api_db_field_mismatch` | Thêm missing column vào DB HOẶC sửa API response | Conflict không giải quyết được |
| File output rỗng (size 0) | Re-run agent (max 3×) | Vẫn rỗng sau retry |
| Missing required section | Re-run agent với instruction bổ sung | Agent vẫn không điền |

> **Retry:** Mỗi step retry tối đa 3 lần. Nếu vẫn fail → escalate với thông báo đầy đủ.

### Fix Rules cho Phase 5 (Stakeholder Review)

| Loại Finding | Ví dụ | Auto-Fix? | Strategy |
|-------------|-------|-----------|----------|
| Cross-spec inconsistency | Error code conflict, missing subscriber | YES | Sửa source doc (api-contract, integration-map) |
| Missing DB entity | Saga table, session table, missing column | YES | Thêm DDL vào database-design.md |
| API↔DB mismatch | Missing column, type mismatch | YES | Sửa DB hoặc API cho khớp |
| Terminology inconsistency | Provisional vs Draft, GRN vs receipts | YES | Chuẩn hóa trong integration-map |
| Missing API endpoint | Bulk operations, admin endpoints, webhooks | YES | Thêm endpoint vào api-contract.md |
| Missing infra component | Container definition, ENV variable | YES | Thêm vào infra-spec.md |
| Security/NFR gap | Missing MFA, encryption, egress filtering | NO | → DEFERRED (cần feature design riêng) |
| Missing infrastructure capability | SAST pipeline, monitoring alert | NO | → DEFERRED (cần infra work riêng) |

---

## Registry Safe-Write

> **Protocol 5 — chi tiết:** xem `.claude/skills/protocols/` §5.

`/wf-design` CHỈ được update 1 field trong `req-registry.json` (standard flow):
- `design_status` (Phase 6) — set `"completed"` sau khi Phase 5 PASS

**Legacy flow extension:** cũng được phép update `systems[]`, `modules[]`, `departments[]`, `requirements[]`, `features[]`, `interface_type` và `requirements[].impl_status` (CHỈ fix invalid values → `not_started`, theo CORE-010).

```
QUY TẮC SAFE-WRITE:
1. ĐỌC registry NGAY TRƯỚC KHI GHI — không cache từ đầu session
2. CHỈ MODIFY fields được phân công — giữ nguyên mọi fields khác
3. NEVER MODIFY (standard flow): systems[], modules[], departments[], requirements[],
   features[], interface_type, implementation_order, impl_status, ux_design_status
4. GHI ATOMIC — single write operation cho toàn bộ JSON (sử dụng Write tool cho file ≤100KB)
5. VALIDATE sau ghi — `jq '.' registry.json` phải pass
6. Update trong MAIN conversation — KHÔNG spawn agent (Protocol 6.1)
```

---

## Token Limit Prevention

> **Protocol 6 — chi tiết:** xem `.claude/skills/protocols/` §6.

Áp dụng riêng cho wf-design:

| Phase | Tình huống | Strategy |
|-------|------------|----------|
| Phase 0 | Feature files > `compression_threshold` | Grep key sections (endpoints, entities, constraints, `^##`, `REQ-`) → `feature-digest.md` (~`digest_size` từ/file). Agents đọc digest thay vì full files. |
| Phase 0 | Feature files > 5 | Dùng dept-digest format (Protocol 6.4) |
| Phase 1 | Architecture phức tạp (>3 systems HOẶC >8 modules) | SKELETON-FIRST: Pass 1 headers + 1-2 câu tóm tắt/section, Pass 2 điền chi tiết |
| Phase 2 | api-contract HOẶC database-design > `skeleton_threshold` | SKELETON-FIRST |
| Phase 5 | Stakeholder review đọc > 5 spec files | Tạo `design-digest` trước spawn agent |
| Phase 6 | Registry update | Write trực tiếp — KHÔNG spawn agent (Protocol 6.1) |

**Context thresholds:**
- < 65% → tiếp tục
- 65-80% → chuẩn bị checkpoint (finish current phase, không start phase mới)
- 80-90% → SAVE checkpoint NGAY, resume session mới
- > 90% → FORCE STOP, prompt `--resume`

---

## LEGACY Context Injection

> Áp dụng cho TẤT CẢ agent spawns trong Phase 1–5 khi `$LEGACY_MODE = true`.
> Mỗi agent prompt PHẢI inject block dưới đây ngay sau phần Context.

```markdown
---
## PROJECT REFERENCE MATERIAL (Dự án cũ — tham chiếu)
[$LEGACY_CONTEXT — Sections 1-6 của project-context.md]

## Ý định của User
[.mc-data/work/wf-brainstorm/user_intent.md nếu có]

## Quyết định Cấu Trúc Dự Án
[$LEGACY_DECISIONS từ legacy-decisions.json]
- Modules DEPRECATE ($DEPRECATED_MODULES): KHÔNG thiết kế architecture cho modules này
- Scope exclusions: loại khỏi technical specs, integration map, gap analysis

## Hướng dẫn sử dụng Reference Material
- trust_level = HIGH → ưu tiên sử dụng
- trust_level = MEDIUM → kiểm chứng với code trước khi dùng
- trust_level = LOW → chỉ tham khảo
- Thiếu/sai → xây dựng từ best practices
- [VERIFIED] label: dùng cho decisions có bằng chứng từ code
- [INFERRED] label: dùng cho decisions suy ra gián tiếp
- [RECOMMENDED] label: dùng cho đề xuất mới
- KHÔNG bị giới hạn bởi reference material — hãy CẢI THIỆN nếu cần
---
```

**Graceful degradation (CORE-022):** Nếu `legacy-decisions.json` không tồn tại → `$DEPRECATED_MODULES = []`, hiển thị cảnh báo, tiếp tục bình thường.

---

## Business Context Injection (v4.1)

> Áp dụng cho TẤT CẢ agent spawns trong Phase 1–5 (cả NEW và LEGACY).
> Inject ngay sau phần Context của prompt, TRƯỚC LEGACY block (nếu có).
> Nguồn: `$BUSINESS_CONTEXT` từ Phase 1 Step 1.0 (`$SESSION_DIR/business-context.md`).

```markdown
---
## BUSINESS CONTEXT (ERP Workflow Layer — bắt buộc tuân thủ)
[$BUSINESS_CONTEXT — actor/role matrix, business object lifecycle (states + transitions),
cross-module dependencies, ownership/assignment rules, exception events]

Quy tắc sử dụng:
- Mọi thiết kế (API/DB/integration/review) PHẢI nhất quán với lifecycle states + ownership trong block này
- API contract PHẢI cover: state transitions (action endpoints), assignment/reassignment,
  list endpoints có search/filter/sort/pagination server-side, bulk operations (nếu features cần),
  activity/audit endpoints cho objects có timeline
- Database PHẢI có: status, owner/assignee, timestamps, audit trail cho mọi object có workflow
- Integration map PHẢI thể hiện cross-module dependencies (object nào cần trạng thái từ module nào)
  + propagation rules (realtime/near-realtime/batch)
- Thiếu/sai thông tin → ghi [NEEDS_REVIEW], KHÔNG tự bịa state/role/module mới ngoài registry
---
```

**Tư duy thiết kế (bắt buộc):** Một ERP không phải tập hợp module độc lập. Mỗi API/bảng/integration phải trace được về: *ai* (role/phòng ban) — *đối tượng nào* — *ở stage nào của vòng đời* — *cần thông tin gì từ module khác* — *phải hành động gì*. Không thiết kế backend cho "màn hình CRUD" — thiết kế cho working context của role tại từng workflow stage.

---

## Agent Prompt Templates

> Templates dùng chung — phase files tham chiếu section này thay vì copy nội dung.
> `[INJECT LEGACY BLOCK]` = inject nội dung từ §LEGACY Context Injection nếu `$LEGACY_MODE = true`.
>
> **Chung cho mọi agent prompt:**
> - **Error handling:** Nếu thiếu thông tin → ghi `[NEEDS_REVIEW]` tại vị trí thiếu, KHÔNG tự placeholder/bịa thông tin.
> - **Return format:** Ghi output trực tiếp đến file path chỉ định. KHÔNG trả output dạng conversational text.

### P1-A: architect (Phase 1 — Architecture Overview)

```
Bạn là Architect. Thiết kế $APPROACH architecture.
Context: Systems: $TARGET_SYSTEMS, Modules: $TARGET_MODULES, Requirements: [REQ_IDS]
[NẾU $FEATURE_DIGEST_PATH tồn tại]: Feature digest: [NỘI DUNG feature-digest.md]. Nếu cần chi tiết → đọc file gốc tại path trong digest.
[NẾU không có digest]: Features: [DANH SÁCH feature files ≤3]
[INJECT LEGACY BLOCK nếu LEGACY_MODE]
Task: Tạo .mc-data/docs/phase3-architecture/P3-01-architecture.md

REGISTRY SCOPE GUARD (CORE-006 — BẮT BUỘC):
Chỉ thiết kế architecture cho systems và modules có trong registry:
  Systems: $TARGET_SYSTEMS
  Modules: $TARGET_MODULES
KHÔNG được tự thêm module mới (Auth, Notification, Admin, Logging, v.v.) dù chúng có vẻ hữu ích.
  - Auth/Security là cross-cutting concern → thiết kế như shared layer/middleware, KHÔNG phải module riêng
  - Notifications, Audit, File Storage → cross-cutting concerns hoặc shared infrastructure
  - Chỉ khi module đã được define trong registry mới thiết kế riêng cho nó

BẮT BUỘC — Business Layer (v4.1, trước khi vẽ kiến trúc kỹ thuật):
Với mỗi business object chính (theo $BUSINESS_CONTEXT — Order, Customer, ...), kiến trúc PHẢI thể hiện:
1. Actor matrix: role/phòng ban nào tương tác với object, hành động gì (view/edit/approve/assign)
2. Lifecycle: các trạng thái + transitions hợp lệ + bộ phận nào tạo/đổi state nào
3. Cross-module: object cần dữ liệu/trạng thái từ module nào (Phase 4 UX sẽ dùng để thiết kế working surface)
4. Ownership: owner/assignee/approver ở từng stage + luật reassign
5. Exceptions: overdue/blocked/rejected/missing-info cần được surfaced lên người dùng
Nơi ghi trong P3-01: §3 (phân hệ + phòng ban), §4 (data ownership), §5 (giao tiếp + workflow states).
Nếu cần thêm chỗ → append "## 9. Ma Trận Vai Trò & Vòng Đời Nghiệp Vụ" — KHÔNG được làm thiếu 7 sections chuẩn.

BẮT BUỘC — Template: Đọc và tuân thủ CHÍNH XÁC cấu trúc từ
`.claude/doc-framework/phase3-architecture/P3-01-architecture.md`

BẮT BUỘC — 7 sections phải có (đọc template để biết chi tiết):
1. Quyết Định Kiến Trúc (bảng quyết định + ADRs)
2. Sơ Đồ Kiến Trúc (ASCII diagram)
3. Danh Sách Phân Hệ (bảng systems + ports + schemas)
4. Phân Quyền Dữ Liệu (data ownership matrix — system nào sở hữu data nào)
5. Giao Tiếp Giữa Các Phân Hệ (sync + async tổng quan, tham chiếu integration-map)
6. Các Quy Ước Áp Dụng (UUID, UTC, soft delete, pagination, error format, logging, API versioning)
7. Môi Trường Triển Khai (dev/staging/prod summary — chi tiết trong infra-spec)

(Protocol 6.5 — Skeleton-first): Nếu architecture phức tạp (>3 systems HOẶC >8 modules) HOẶC $LARGE_PROJECT = true:
  → Pass 1: Tạo skeleton (7 section headers + 1-2 câu tóm tắt/section, ~500 từ) → write file
  → Pass 2: Điền chi tiết từng section (có thể song song nếu sections độc lập)
  Lý do: Tránh output >4000 từ trong 1 pass — giảm risk context overflow và quality degradation.

Quality: Non-empty, REQ-IDs referenced, No placeholders, đủ 7 sections
Output mục tiêu: Standard ~2000–4000 từ / LPM ~3000–6000 từ. Tập trung vào decisions và trade-offs, không mô tả lại requirements.
```

### P1-B: ai-engineer (Phase 1, conditional — `$HAS_AI_ML = true`)

```
Bạn là AI Engineer. Review architecture cho AI/ML components.
Context: Architecture overview từ architect, Systems, Modules, Requirements
[INJECT LEGACY BLOCK nếu LEGACY_MODE]
Task: Bổ sung vào P3-01-architecture.md — section ML Pipeline Architecture:
- Model serving infrastructure (inference endpoints, batch vs realtime)
- Training pipeline (data → features → training → evaluation → deployment)
- ML monitoring (model drift, data quality, prediction accuracy)
- Feature store / embedding store nếu cần
Output: Append ML section vào `.mc-data/docs/phase3-architecture/P3-01-architecture.md`
Quality: Actionable ML architecture, integrated với overall system architecture
Output mục tiêu: ~800–1500 từ. Tập trung vào infrastructure decisions, không lặp lại architecture overview.
```

### P1-C: data-engineer (Phase 1, conditional — `$HAS_DATA_PIPELINE = true`)

```
Bạn là Data Engineer. Review architecture cho data pipeline components.
Context: Architecture overview từ architect, Systems, Modules, Requirements
[INJECT LEGACY BLOCK nếu LEGACY_MODE]
Task: Bổ sung vào P3-01-architecture.md — section Data Pipeline Architecture:
- ETL/ELT pipeline design (sources → staging → warehouse)
- Data quality gates và validation rules
- CDC (Change Data Capture) strategy nếu cần
- Data lineage và governance
Output: Append Data Pipeline section vào `.mc-data/docs/phase3-architecture/P3-01-architecture.md`
Quality: Actionable data architecture, integrated với overall system architecture
Output mục tiêu: ~800–1500 từ. Tập trung vào pipeline decisions, không lặp lại architecture overview.
```

### P1-D: automation-architect (Phase 1, conditional — `$HAS_AUTOMATION = true`)

```
Bạn là Automation Architect. Đánh giá và thiết kế workflow automation components.
Context: Architecture overview từ architect, Systems, Modules, Requirements
[INJECT LEGACY BLOCK nếu LEGACY_MODE]
Task: Bổ sung vào P3-01-architecture.md — section Workflow Automation Architecture:
- Đánh giá giá trị automation vs manual cho từng workflow
- Business process automation patterns (event-driven, scheduled, triggered)
- Integration governance (n8n/Zapier/custom engine selection)
- Error handling và retry strategy cho automated workflows
Output: Append Automation section vào `.mc-data/docs/phase3-architecture/P3-01-architecture.md`
Quality: ROI-driven assessment, risk evaluation, maintainability considerations
Output mục tiêu: ~800–1500 từ. Tập trung vào ROI assessment và governance, không lặp lại architecture overview.
```

### P2-A: architect (Phase 2 — API Contract)

```
Bạn là architect. Tạo API Contract cho [project].
Context: Architecture overview, Systems, Modules, Requirements
[INJECT LEGACY BLOCK nếu LEGACY_MODE]

BẮT BUỘC — Template: Đọc và tuân thủ CHÍNH XÁC cấu trúc từ
`.claude/doc-framework/phase3-architecture/technical-specs/api-contract.md`

Yêu cầu ERP working-surface (v4.1 — theo $BUSINESS_CONTEXT): endpoint set PHẢI phục vụ cả working context + data grid của UI:
- State transitions: action endpoints cho từng workflow transition (VD: POST /orders/:id/approve) — không chỉ CRUD
- Assignment: assign/reassign endpoints cho objects có ownership
- List endpoints: document đầy đủ query params search/filter/sort/pagination (server-side, mặc định limit=20, tối đa 100)
- Bulk operations khi features yêu cầu (bulk update/assign/export)
- Activity/audit endpoints cho objects có timeline (GET /orders/:id/activity)

Output: `.mc-data/docs/phase3-architecture/technical-specs/api-contract.md`
Quality: Non-empty, đúng template structure, REQ-IDs referenced, No placeholders
Output mục tiêu: Standard ~1500–3000 từ / LPM ~2500–5000 từ. Endpoints đầy đủ nhưng ngắn gọn.

(Protocol 6.5/6.6 — Skeleton-first): Nếu $LARGE_PROJECT = true VÀ output ước tính >2000 từ:
  → Pass 1: Tạo skeleton (section headers + 1-2 câu tóm tắt/section) → write file
  → Pass 2: Điền chi tiết từng section
  Áp dụng cho api-contract (nhiều endpoints).
```

### P2-B: dba + architect (Phase 2 — Database Design)

```
Bạn là dba/architect. Tạo Database Design cho [project].
Context: Architecture overview, Systems, Modules, Requirements
[INJECT LEGACY BLOCK nếu LEGACY_MODE]

BẮT BUỘC — Template: Đọc và tuân thủ CHÍNH XÁC cấu trúc từ
`.claude/doc-framework/phase3-architecture/technical-specs/database-design.md`

Yêu cầu ERP workflow fields (v4.1 — theo $BUSINESS_CONTEXT): mỗi bảng của business object có workflow PHẢI có:
- `status` + state machine constraint (chỉ cho transitions hợp lệ theo lifecycle)
- `owner_id`/`assignee_id` FK + `created_by`/`updated_by` + timestamps
- Assignment history table (nếu multi-stage handoff giữa phòng ban)
- Audit/Activity log table cho objects có timeline
- Index cho các cột lọc danh sách hay dùng (status, owner, dates) — phục vụ server-side filtering

Output: `.mc-data/docs/phase3-architecture/technical-specs/database-design.md`
Quality: Non-empty, đúng template structure, REQ-IDs referenced, No placeholders
Output mục tiêu: Standard ~1500–3000 từ / LPM ~2500–5000 từ. Schema tables + relationships + indices + rationale.

(Protocol 6.5/6.6 — Skeleton-first): Nếu $LARGE_PROJECT = true VÀ output ước tính >2000 từ:
  → Pass 1: Tạo skeleton (section headers + 1-2 câu tóm tắt/section) → write file
  → Pass 2: Điền chi tiết từng section
  Áp dụng cho database-design (nhiều tables).
```

### P2-C: devops + architect (Phase 2 — Infra Spec)

```
Bạn là devops/architect. Tạo Infra Spec cho [project].
Context: Architecture overview, Systems, Modules, Requirements
[INJECT LEGACY BLOCK nếu LEGACY_MODE]

BẮT BUỘC — Template: Đọc và tuân thủ CHÍNH XÁC cấu trúc từ
`.claude/doc-framework/phase3-architecture/technical-specs/infra-spec.md`

Output: `.mc-data/docs/phase3-architecture/technical-specs/infra-spec.md`
Quality: Non-empty, đúng template structure, REQ-IDs referenced, No placeholders
Output mục tiêu: Standard ~1000–2000 từ / LPM ~1500–3000 từ. Environments + containers + networking, không lặp architecture overview.
```

### P3: architect (Phase 3 — Integration Map)

```
Bạn là architect. Thiết kế integration points và cross-system rules.
Context: API contract + Database design + Architecture overview
[INJECT LEGACY BLOCK nếu LEGACY_MODE]

BẮT BUỘC — Template: Đọc và tuân thủ CHÍNH XÁC cấu trúc từ:
`.claude/doc-framework/phase3-architecture/technical-specs/integration-map.md`

Yêu cầu cross-module surfacing (v4.1 — theo $BUSINESS_CONTEXT): ngoài technical integrations, map "object 360" data needs:
- Mỗi business object cần aggregation data từ module nào (VD: Order Detail cần Purchasing + Warehouse + Finance status)
- Propagation rules cho cross-department status change (realtime / near-realtime / batch) — để UI working surface không bắt user rời màn hình để hiểu tình trạng
- Event cho assignment/ownership change (phòng ban khác cần biết record vừa đổi người phụ trách)

Output: `.mc-data/docs/phase3-architecture/technical-specs/integration-map.md`
Lưu ý: Cross-system rules đã được merge vào integration-map.md (sections 7-9)
Quality: Non-empty, đúng template structure, REQ-IDs referenced, No placeholders
Output mục tiêu: ~1500–2500 từ. Integration points + cross-system rules, không lặp API/DB details.
```

### P5-A: architect (Phase 5 — Review Phần B+C)

```
Bạn là architect. Thực hiện Stakeholder Review (Phần B + C) cho Phase 3 Architecture Design.
Context: Tất cả technical specs + features (hoặc design-digest nếu > 5 files)
[INJECT LEGACY BLOCK nếu LEGACY_MODE]
Tasks:
1. Phần B (SO-01): Rà soát xuyên specs — phát hiện xung đột architecture, API↔DB mismatch, duplicate definitions
2. Phần C (SO-02): Kiểm tra nhất quán — REQ-IDs coverage, thuật ngữ kỹ thuật, data models, phạm vi
3. (v4.1) Business completeness (so với $BUSINESS_CONTEXT): mỗi business object có state transitions đủ?
   ownership/assignment được thể hiện (API + DB)? cross-module workflow được integration-map cover?
   exception events có đường được surfaced? API list endpoints có filter/sort/pagination server-side?

BẮT BUỘC — Template: Đọc và tuân thủ CHÍNH XÁC cấu trúc từ:
`.claude/doc-framework/phase3-architecture/stakeholder-review.md` (Phần B và Phần C)

Severity definitions cho architecture findings:
- Critical: API↔DB mismatch blocking, missing core entity, security hole
- High: Inconsistent error codes, missing required endpoint, broken integration
- Medium: Minor spec inconsistency, non-blocking gap
- Low: Cosmetic issue, nice-to-have improvement

Output: `.mc-data/work/wf-design/_tmp-so-bc.md` (KHÔNG ghi trực tiếp vào stakeholder-review.md)
Quality: Actionable findings, severity classification (Critical/High/Medium/Low), No TODO/TBD, đúng template
Output mục tiêu: ~1500–2500 từ. Findings cụ thể với evidence, không mô tả lại architecture.
```

### P5-B: security (Phase 5 — Review Phần D, Gap Analysis)

```
Bạn là security engineer. Thực hiện Gap Analysis (Phần D) cho Phase 3 Architecture Design.
Context: Tất cả technical specs + architecture
[INJECT LEGACY BLOCK nếu LEGACY_MODE]
Task: Phần D (SO-03): Phân tích thiếu sót — API gaps, DB gaps, infra gaps, security gaps, NFR gaps.
(v4.1) Thêm: missing workflow endpoints (state transition/assign/reassign), missing assignment history/audit tables,
missing exception flows, missing cross-module aggregation endpoints cho working surfaces (so với $BUSINESS_CONTEXT).

BẮT BUỘC — Template: Đọc và tuân thủ CHÍNH XÁC cấu trúc từ:
`.claude/doc-framework/phase3-architecture/stakeholder-review.md` (Phần D)

Output: `.mc-data/work/wf-design/_tmp-so-d.md` (KHÔNG ghi trực tiếp vào stakeholder-review.md)
Quality: Actionable findings, severity classification (Critical/High/Medium/Low), No TODO/TBD, đúng template
Output mục tiêu: ~800–1500 từ. Gap analysis cụ thể với evidence, không lặp lại specs đã có.
```

---

## Checkpoint Protocol

> **Primary:** `$SESSION_DIR/session-state.json` (3-level: L1 Phase → L2 Batch → L3 Item).
> **Backward-compat:** `$SESSION_DIR/checkpoint.json` được sync từ session-state sau mỗi save, mirror ra `.mc-data/work/wf-design/checkpoint.json`.

**session-state.json schema:**

```json
{
  "$schema": "design-session-state-v1",
  "session_id": "$SESSION_ID",
  "created_at": "YYYY-MM-DDTHH:MM:SSZ",
  "next_action": "phase1-architecture",
  "phases": {
    "P0": { "status": "completed" },
    "P0_5": { "status": "completed", "gate_result": "dead_zone", "est_minutes": 30 },
    "P1": {
      "status": "in_progress",
      "batches": {
        "{system-slug}": {
          "status": "completed",
          "items": {
            "{component-id}": { "status": "completed" }
          }
        }
      }
    }
  }
}
```

**checkpoint.json** (backward-compat): dùng template `templates/checkpoint.json`, schema `design-checkpoint-v1`. Sync từ session-state sau mỗi phase save.

**Khi nào SAVE:**
- Cuối mỗi Phase (1, 2, 3, 5, 6 đều có step SAVE CHECKPOINT ở cuối)
- Phase 2: sau khi 3 specs parallel hoàn thành (per batch Standard, per spec LPM)
- Context >= 65%: chuẩn bị checkpoint (finish current phase, không start mới)
- Context >= 80%: FORCE SAVE NGAY, resume session mới với `--resume`

**--resume routing:** Đọc `$SESSION_DIR/session-state.json` → `next_action` → dispatch phase. Fallback về `checkpoint.json` nếu session-state.json không tồn tại (pre-v4.0 sessions).

**Paths:**
- Session-scoped: `$SESSION_DIR/session-state.json`, `$SESSION_DIR/checkpoint.json`
- Canonical backward-compat: `.mc-data/work/wf-design/checkpoint.json` (mirror)

---

## Agent Output Validation (CORE-029)

> Mỗi agent output PHẢI được validate trước khi accept. Phase files thực hiện validate trong POST-GATE.
> Đối với JSON outputs: `jq '.' file.json` phải pass. Đối với MD outputs: `test -s` + grep required sections.

**Minimum validation per agent output:**
1. File tồn tại và non-empty (`test -s`)
2. Đúng template structure (grep required headings/sections)
3. Không placeholder (`grep -v '<!-- TODO\|TBD\|...'`)
4. REQ-IDs referenced (nếu applicable)

---

## LEGACY_MODE Detection

Theo CORE-021 (BẮT BUỘC):

```bash
LEGACY_MODE=$(test -f .mc-data/work/legacy-scan/project-context.md \
  && test $(wc -c < .mc-data/work/legacy-scan/project-context.md) -gt 500 \
  && echo "true" || echo "false")
```

**KHÔNG** detect bằng `ledger.json` (false positive — tồn tại từ Stage 0.5).
**KHÔNG** detect bằng check khác giữa các skills.

Khi `LEGACY_MODE = true`:
- Phase 0 load `$LEGACY_CONTEXT` từ `project-context.md`
- Phase 0 load `$LEGACY_DECISIONS` từ `legacy-decisions.json`, set `$DEPRECATED_MODULES`
- Mọi agent spawn trong Phase 1–5 phải inject LEGACY BLOCK (xem §LEGACY Context Injection)
- Phase 7 (Gap Analysis) CHỈ chạy khi LEGACY_MODE
- Modules thuộc `$DEPRECATED_MODULES` bị loại khỏi mọi output (architecture specs, technical-specs, integration-map, gap analysis)
- Architecture labels [VERIFIED]/[INFERRED]/[RECOMMENDED] được enforce (xem §Architecture Documentation Labels)

**Graceful degradation (CORE-022):** Nếu `legacy-decisions.json` không tồn tại → `$DEPRECATED_MODULES = []`, hiển thị cảnh báo: "legacy-decisions.json không tìm thấy — user decisions từ wf-brainstorm chưa được propagate. Khuyến nghị: Chạy lại /wf-brainstorm Phase 0.5."
