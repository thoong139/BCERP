# Shared Protocols — wf-analyze-requirements

> Cross-cutting protocols, state variables, agent templates, fix rules và reference data
> được sử dụng bởi nhiều Phase trong wf-analyze-requirements.
> KHÔNG đọc file này standalone — chỉ load section cụ thể khi cần.

## Sections

- [State Variables Glossary](#state-variables-glossary)
- [Phase → File Mapping](#phase--file-mapping)
- [Phase Ordering by Scope](#phase-ordering-by-scope)
- [Session Isolation Protocol (ADR-OPT-02)](#session-isolation-protocol-adr-opt-02)
- [_shared Module Imports (ADR-OPT Integration)](#_shared-module-imports-adr-opt-integration)
- [Protocol 6.6 — Large Project Mode](#protocol-66--large-project-mode)
- [LEGACY_MODE Context Injection](#legacy_mode-context-injection)
- [Agent Context Templates](#agent-context-templates)
- [Resolution Tracks (Phase 6d)](#resolution-tracks-phase-6d)
- [Registry Schema — requirements[]](#registry-schema--requirements)
- [Registry Safe-Write](#registry-safe-write)
- [Fix Rules](#fix-rules)
- [Token Budget & Checkpoint](#token-budget--checkpoint)
- [Error Codes](#error-codes)
- [Output Report Template](#output-report-template)

---

## State Variables Glossary

Biến in-memory được set/đọc xuyên suốt skill execution.

| Variable | Set by Phase | Read by Phase | Description |
|----------|--------------|---------------|-------------|
| `$LEGACY_MODE` | Phase 0 | ALL agent spawns, 3.5 | Boolean — true nếu `.mc-data/work/legacy-scan/project-context.md > 500 bytes` (CORE-021) |
| `$LEGACY_CONTEXT` | Phase 0 | ALL agent spawns | Nội dung `project-context.md` (LEGACY) |
| `$REGISTRY_DATA` | Phase 0 | 1, 6, 8 | Parsed registry JSON (in-memory) |
| `$BRAINSTORM_SYSTEMS` | Phase 0 | 3, 4, 6, 8, 8b | Array systems[] đã seed từ wf-brainstorm (id, name, user_roles[], touchpoints[], related_departments[], phase). Dùng để enforce per-system coverage + tách requirements theo touchpoint. |
| `$BRAINSTORM_CONTEXT` | Phase 0 | 1, 2, 3 | Content `P0-01-brainstorm.md` |
| `$ACTIVE_DEPTS` | Phase 1 | 2, 3, 4 | Array departments từ P0 Section 2 |
| `$DETECTED_INDUSTRIES` | Phase 1 | 2 | Array ngành nhận diện từ context |
| `$SCOPE` | Phase 1 | 2, 3, 6b, 6c, 6d | `all` / `business` / `[module-name]` |
| `$HAS_EXISTING_DOCS` | Phase 1 | 5 | Boolean — true nếu có onboarding docs |
| `$EXPERT_LIST` | Phase 2 | 4, 6d | Array domain experts cho project |
| `$EXPERT_DEPT_MAP` | Phase 2 | 4 | Map expert → departments phụ trách Phần B |
| `$HEAVYWEIGHT_DEPTS` | Phase 2 | 4 | Array departments có >= 4 domain areas (cần split) |
| `$LARGE_PROJECT` | Phase 2 | ALL agent spawns, 6b, 6c | Boolean — true nếu LPM active (xem Protocol 6.6) |
| `$MAX_PARALLEL_AGENTS` | Phase 2 | 3, 4 | 5 (Standard) hoặc 3 (LPM) |
| `$CONSOLIDATED_REQS` | Phase 6 | 8 | Array requirements sau consolidation |
| `$INTERFACE_TYPE` | Phase 6 | 8 | `web`/`mobile`/`desktop`/`api-only`/`web+mobile` |
| `$FINDINGS_CLASSIFIED` | Phase 6d | 6d steps | Classified findings (AUTO/EXPERT/BLOCKING/DEFER) |
| `error_log[]` | All phases | 8b | Array errors — dùng cho Auto-Correction Loop |
| `$SESSION_DIR` | Phase 0 | ALL | `.mc-data/work/wf-analyze-requirements/sessions/{YYYYMMDD-HHMMSS}-{hash4}/` (ADR-OPT-02) |
| `$SESSION_ID` | Phase 0 | ALL | `YYYYMMDD-HHMMSS-hash4` — unique session identifier |
| `$WORKLOAD_ESTIMATE` | Phase 0.5 | 1, 2, 3, 4 | `WorkloadEstimate` object từ `_shared/partition/` (total_minutes, partition_count, items_count) |
| `$GATE_RESULT` | Phase 0.5 | 1, 2 | `GateResult` (status ∈ dead_zone/warn/block, ratio) |

---

## Phase → File Mapping

| Phase | File | Vai trò |
|-------|------|---------|
| Phase 0 | `phase0-context.md` | Context loading, PRE-GATE registry + brainstorm, session init (ADR-OPT-02) |
| Phase 0.5 | `phase0.5-workload-gate.md` | Workload estimation + gate evaluation (ADR-OPT-03) |
| Phase 1 | `phase1-scope.md` | Registry validation + scope determination (in-memory) |
| Phase 2 | `phase2-plan.md` | Expert planning, LPM detection, execution plan |
| Phase 3 | `phase3-ba-parta.md` | BA spawn parallel per dept (Phần A) |
| Phase 3.5 | `phase3.5-legacy.md` | Naming normalization (CHỈ LEGACY_MODE) |
| Phase 4 | `phase4-experts-partb.md` | Domain experts spawn parallel per dept (Phần B) |
| Phase 5 | `phase5-existing-docs.md` | Merge existing docs (CHỈ khi $HAS_EXISTING_DOCS) |
| Phase 6 | `phase6-consolidate.md` | Consolidate requirements (in-memory) |
| Phase 6b | `phase6b-workflow.md` | P1-02 business workflow cross-dept (scope=all) |
| Phase 6c | `phase6c-stakeholder.md` | Stakeholder review SO-01/02/03 (scope=all) |
| Phase 6d | `phase6d-conflict.md` | Conflict resolution 4 tracks (scope=all) |
| Phase 8 | `phase8-registry.md` | Registry safe-write + schema validation |
| Phase 8b | `phase8b-crossval.md` | Cross-validation auto-correction loop |
| Phase 8c | `phase8c-handoff.md` | Generate department-digests + phase1-handoff |

> Phase 7 (Feature Specs) thuộc `/wf-define-features`, KHÔNG nằm trong skill này.

---

## Phase Ordering by Scope

| Scope | Phases chạy | Mô tả |
|-------|-------------|-------|
| `all` | 0→0.5→1→2→3→3.5(L)→4→5(C)→6→6b→6c→6d→8→8b→8c | Full analysis |
| `business` | 0→0.5→1→2→3→3.5(L)→4→5(C)→6→8→8b→8c | Skip workflow + stakeholder + conflict |
| `[module-name]` | 0→0.5→1→2→3→3.5(L)→4→5(C)→6→8→8b→8c | Same as business, scope=1 dept |

> `(L)` = chỉ chạy nếu `$LEGACY_MODE = true`. `(C)` = chỉ chạy nếu `$HAS_EXISTING_DOCS = true`.

---

## Session Isolation Protocol (ADR-OPT-02)

> Mỗi `/wf-analyze-requirements` run tạo session dir riêng — multi-run safe, không đè output cũ.
> Áp dụng CORE-030 Working Directory Session Isolation.

### Session Directory Structure

```
.mc-data/work/wf-analyze-requirements/sessions/{YYYYMMDD-HHMMSS}-{hash4}/
├── session-state.json          ← 3-level checkpoint state machine (PRIMARY)
├── analyze-status.json         ← Phase status tracking (copy về root để backward-compat)
├── checkpoint.json             ← Legacy checkpoint (backward-compat, dual-write)
├── workload-report.md          ← Workload gate report (Phase 0.5)
├── cdg-tokens.json             ← CDG accept/reject tokens (nếu có)
├── lanes/                      ← Lane outputs (Phase 4)
│   ├── {dept-key-1}/
│   │   └── signals.json
│   ├── {dept-key-2}/
│   │   └── signals.json
│   └── ...
├── aggregation-result.json     ← Signal aggregation result (Phase 6)
├── department-digests.json     ← Digest pre-sync (Phase 8c)
├── phase1-handoff.json         ← Handoff pre-sync (Phase 8c)
└── phase-summary.md            ← CORE-028 append-only
```

### Latest Pointer

Text file tại `.mc-data/work/wf-analyze-requirements/latest` — nội dung là absolute path tới session dir mới nhất. Downstream consumers + `--resume` resolve session qua pointer này.

```bash
# Tạo/update latest pointer
echo "$SESSION_DIR" > .mc-data/work/wf-analyze-requirements/latest
```

### 3-Level Checkpoint Hierarchy

| Level | Field trong session-state.json | Granularity | Use case |
|-------|-------------------------------|-------------|----------|
| **L1 Phase** | `phases.P{N}.status` | Per phase (P0, P0_5, P1, ..., P8c) | Resume từ phase đang dở |
| **L2 Batch** | `phases.P{N}.batches[{dept-key}].status` | Per dept-batch (trong Phase 3, 4) | Resume giữa batch dept |
| **L3 Item** | `phases.P{N}.batches[{dept}].items[{req-id}].status` | Per req-item (optional, LPM-only) | Resume fine-grained |

**Checkpoint write rule (dual-write cho backward-compat):**

- SAVE CHECKPOINT = update `session-state.json` (PRIMARY source of truth) + update legacy `checkpoint.json` (mirror subset)
- Session-state.json atomic write (theo `_shared/_shared.md §2`)
- Legacy `checkpoint.json` vẫn tạo để consumers cũ chưa migrate không bị vỡ

### Cleanup Policy

Giữ **5 sessions mới nhất** per skill (Sign-off Item #3 — ADR-OPT-02):

```bash
# Đếm sessions hiện có (sắp xếp theo timestamp trong tên folder)
ls -1d sessions/*/ | sort | head -n -5 | xargs -r rm -rf
```

---

## _shared Module Imports (ADR-OPT Integration)

> Import convention theo `.claude/skills/workflow/_shared/_shared.md §3-4`:
> `from {module} import {function}` — path `sys.path.insert(0, ".claude/skills/workflow/_shared")`.

### Module Usage Map trong wf-analyze-requirements

| Module | Import | Dùng tại Phase | Mục đích |
|--------|--------|---------------|----------|
| `partition` | `from partition import plan_partitions, check_workload_gate` | Phase 0.5 | Partition $ACTIVE_DEPTS + workload gate (ADR-OPT-03) |
| `lane` | `from lane import dispatch_lanes, LaneConfig` | Phase 4 | Dept-expert lane dispatch song song (ADR-OPT-01) |
| `aggregate` | `from aggregate import aggregate_lane_signals, dedup_by_id` | Phase 6 | Signal aggregation + dedup REQ-ID (ADR-OPT-04) |
| `cache` | `from cache import get_cached, set_cached` | Phase 0.5 (optional) | Content-hash cache cho workload estimate |
| `cdg` | `from cdg import create_cdg_token, check_anti_loop` | Phase 0.5, 6d | CDG handoff + anti-loop guard (ADR-OPT-08) |

### Import Template

```python
import sys
sys.path.insert(0, ".claude/skills/workflow/_shared")

# Phase 0.5
from partition import plan_partitions, check_workload_gate
from cdg import create_cdg_token

# Phase 4
from lane import dispatch_lanes, LaneConfig

# Phase 6
from aggregate import aggregate_lane_signals, dedup_by_id
```

### Write-Scope Isolation (CORE-025)

Mỗi module ghi vào path riêng → không lock contention khi chạy song song:

- `lane/` → `$SESSION_DIR/lanes/{dept-key}/signals.json` (unique per dept)
- `aggregate/` → `$SESSION_DIR/aggregation-result.json` (single writer, Phase 6 only)
- `partition/` → `$SESSION_DIR/workload-report.md` (single writer, Phase 0.5 only)

---

## Protocol 6.6 — Large Project Mode

**Detection (tại Phase 2 Step 2.4):**

```
$LARGE_PROJECT = (
  active_depts.length >= 10 OR
  registry.requirements.length >= 50 OR
  registry.systems.length >= 5 OR
  registry.features.length >= 40
)
```

**LPM Overrides:**

| Setting | Standard | Large Project Mode |
|---------|----------|---------------------|
| `max_parallel_agents` | 5 | 3 |
| `compression_threshold` | > 3 dept files | > 2 dept files |
| `digest_size` | ~200 từ/dept | ~300 từ/dept (Extended) |
| `skeleton_threshold` | > 3000 từ output | > 2000 từ output |
| `checkpoint_frequency` | sau phase chính | sau MỖI phase |
| BA output target | ~800–1200 từ | ~1200–2000 từ |
| Expert output target | ~1000–1500 từ | ~1500–2500 từ |
| P1-02 output | ~2000–3000 từ | ~3000–5000 từ |
| Stakeholder review output | ~1500–2500 từ | ~2500–4000 từ |

**Áp dụng:** Ghi `large_project_mode: true/false` vào `analyze-plan.md` + `analyze-status.json`.

---

## LEGACY_MODE Context Injection

> Áp dụng cho TẤT CẢ agent spawns trong skill này (Phase 3, 4, 6b, 6c, 6d).
> Mỗi lần spawn agent, nếu `$LEGACY_MODE = true` thì PHẢI thêm block sau vào prompt.

```
---
## PROJECT REFERENCE MATERIAL (Dự án cũ — tham chiếu)
[Nội dung project-context.md — Sections 1-6]

## Ý định của User
[Nội dung .mc-data/work/wf-brainstorm/user_intent.md]

## Quyết định Cấu Trúc Dự Án (legacy-decisions.json)
[Đọc .mc-data/work/wf-brainstorm/legacy-decisions.json]
- Modules DEPRECATE: [list] → KHÔNG tạo requirements cho các modules này
- Divergence resolutions: [list] → follow decision khi encounter conflict
- Scope exclusions: [list] → loại khỏi analysis scope

Hướng dẫn xử lý DEPRECATE:
- Nếu requirements analysis phát hiện feature thuộc module DEPRECATE → skip + log vào deferred-issues.md

## Hướng dẫn sử dụng Reference Material:
- trust_level = HIGH → ưu tiên sử dụng
- trust_level = MEDIUM → kiểm chứng với code trước khi dùng
- trust_level = LOW → chỉ tham khảo
- Thiếu/sai → xây dựng từ best practices
- KHÔNG bị giới hạn bởi reference material — hãy CẢI THIỆN nếu cần
---
```

**Graceful degradation (CORE-022):** Nếu `legacy-decisions.json` không tồn tại → hiển thị cảnh báo, set `$DEPRECATED_MODULES = []`, tiếp tục không enforce scope exclusion.

---

## Agent Context Templates

### Template BA Phần A (Phase 3, per dept)

```
Bạn là business-analyst. Phân tích stakeholders và user needs cho [project].
Context: Project: [name], Domain: [domain]
Task: Tạo Phần A cho department [dept-name]:
  - Output: .mc-data/docs/phase1-business/departments/[dept]/[dept].md
Template: Đọc và tuân thủ cấu trúc từ .claude/doc-framework/phase1-business/departments/[dept-name]/[dept-name].md (Phần A)
Quality: Non-empty, REQ-IDs format REQ-[DEPT]-[NNN], không có TODO/TBD
LƯU Ý: CHỈ tạo Phần A cho 1 department được giao — KHÔNG tạo file cho departments khác.

MULTI-SYSTEM COVERAGE (BẮT BUỘC — ngăn thiếu features per system):
Hệ thống declared trong brainstorm ($BRAINSTORM_SYSTEMS — JSON paste dưới):
[Paste nội dung $BRAINSTORM_SYSTEMS — mỗi system có id, name, user_roles[], touchpoints[], related_departments[]]

Department [dept-name] phục vụ các systems sau (từ related_departments match):
[List filtered systems]

Với MỖI requirement trong phần A của bạn, PHẢI:
1. Khai báo rõ `Hệ thống liên quan:` — liệt kê TẤT CẢ systems mà requirement cần được đáp ứng.
   Ví dụ: requirement "Theo dõi đơn hàng realtime" cho DEPT-CX → Hệ thống liên quan: web-customer + mobile-customer (cùng behavior, 2 touchpoints).
2. Nếu requirement thuộc department phục vụ ≥ 2 systems (vd DEPT-CX phục vụ web-customer + mobile-customer, DEPT-TMS phục vụ erp + mobile-staff) và feature có UI/touchpoint riêng biệt cho từng system → KHÔNG được gộp chung. Phải nêu rõ bản cho web + bản cho mobile (hoặc các systems khác) để downstream skill phân biệt được.
3. Ghi 1 section "Ma trận Requirement × System" (bảng ngắn) ở đầu Phần A:
   | REQ-ID | Title | Systems liên quan | Primary system | Lý do tách/gộp |
4. KHÔNG được bỏ system nào mà brainstorm đã khai báo có `related_departments` chứa department này. Nếu không có requirement nào cho system → vẫn liệt kê system đó trong ma trận với note "Không có requirement riêng — dùng chung với [system khác]".

Output mục tiêu: ~800–1200 từ (Standard) hoặc ~1200–2000 từ (Large Project Mode). Súc tích, đủ ý, không lặp context đã biết.
```

### Template Expert Phần B (Phase 4, per dept)

```
Bạn là [domain-expert]. Phân tích quy trình làm việc cho phòng ban [dept] trong dự án [project].
Context: User needs từ .mc-data/docs/phase1-business/departments/[dept]/[dept].md (Phần A) — bao gồm ma trận Requirement × System đã được BA đặt ở đầu file.
Template: Đọc và tuân thủ cấu trúc từ .claude/doc-framework/phase1-business/departments/[dept-name]/[dept-name].md (Phần B)
Output: Thêm Phần B vào CUỐI file .mc-data/docs/phase1-business/departments/[dept]/[dept].md (sau Phần A)
Quality: Non-empty, REQ-IDs format REQ-[DEPT]-[NNN], không có TODO/TBD
LƯU Ý: Dùng Edit tool để APPEND Phần B sau Phần A — KHÔNG ghi đè nội dung Phần A đã có.

MULTI-SYSTEM COVERAGE (BẮT BUỘC):
Hệ thống declared ($BRAINSTORM_SYSTEMS — JSON paste dưới):
[Paste nội dung $BRAINSTORM_SYSTEMS]

Với mỗi REQ-ID trong Phần A, Phần B bạn tạo phải:
1. Cover đầy đủ workflow/logic cho TỪNG system được khai trong "Hệ thống liên quan" của REQ (không chỉ system chính).
2. Nếu 1 REQ phục vụ nhiều systems với touchpoint khác biệt (vd web vs mobile) — đặc tả business rules, UI expectations, permission matrix RIÊNG cho từng system trong Phần B. Đừng giả định "web và mobile giống hệt nhau" mà không kiểm chứng.
3. Ở cuối Phần B, bổ sung "Ma trận Business-Rules × System" để Phase 2 fan-out đúng — giúp wf-define-features sinh features cho mỗi system tương ứng.

Output mục tiêu: ~1000–1500 từ (Standard) hoặc ~1500–2500 từ (Large Project Mode) cho Phần B. Súc tích, đủ ý, không lặp lại Phần A.
HARD LIMIT: Nếu nội dung đầy đủ sẽ vượt 2500 từ → viết sections B1–B3 trong file này, dừng lại, ghi chú "SPLIT_REQUIRED" vào cuối file. Main conversation sẽ spawn call-2 cho sections còn lại. KHÔNG cố gắng viết toàn bộ trong 1 call.
```

### Template P1-02 Cross-Dept Workflow (Phase 6b)

```
Bạn là business-analyst. Tổng hợp cross-dept workflow cho [project].
Input: [digest nội bộ hoặc file paths — tuỳ compression threshold]
Template: .claude/doc-framework/phase1-business/P1-02-business-workflow.md
Output: .mc-data/docs/phase1-business/P1-02-business-workflow.md
Quality: Mermaid diagrams, No TODO/TBD
Output mục tiêu: ~2000–3000 từ (Standard) hoặc ~3000–5000 từ (Large Project Mode). Tập trung vào luồng cross-dept, không mô tả lại nội bộ từng phòng ban.
```

### Template Stakeholder Review (Phase 6c)

```
Bạn là business-analyst. Thực hiện Stakeholder Review cho Phase 1.
Input: [dept-digest từ main conversation] + P1-02-business-workflow.md
Nếu cần xác nhận chi tiết của dept cụ thể, đọc file .mc-data/docs/phase1-business/departments/[dept]/[dept].md — chỉ section liên quan.
Tasks: Rà soát chéo (cross-dept conflicts/overlaps/gaps), REQ-IDs/terminology/data consistency, missing requirements/NFRs
Template: .claude/doc-framework/phase1-business/stakeholder-review.md
Output: .mc-data/docs/phase1-business/stakeholder-review.md
Quality: Actionable findings, severity (Critical/High/Medium/Low), No TODO/TBD
Output mục tiêu: ~1500–2500 từ (Standard) hoặc ~2500–4000 từ (Large Project Mode). Tập trung vào findings có giá trị, không liệt kê lại nội dung đã biết.
```

### Template BLOCKING-RESOLVE (Phase 6d.5)

```
Bạn là [domain-expert]. Bạn đại diện cho [phòng ban] trong dự án [project].

FINDING CẦN GIẢI QUYẾT:
- Issue: [mô tả finding]
- Severity: KHẨN CẤP — blocking Phase 2
- REQ-IDs liên quan: [list]
- Phòng ban liên quan: [list]

CONTEXT:
[Trích nội dung liên quan từ dept docs]

YÊU CẦU:
1. Phân tích vấn đề từ góc độ chuyên môn [domain]
2. Đề xuất giải pháp cụ thể (không chung chung, không placeholder)
3. Nếu cần data model/schema: thiết kế draft schema
4. Nếu cần quy trình: mô tả step-by-step
5. Nếu cần ma trận phê duyệt: đề xuất ngưỡng + roles cụ thể
6. Ghi rõ: đây là AI-recommended decision, stakeholder có thể điều chỉnh trong Phase 2

OUTPUT FORMAT:
## Giải pháp đề xuất cho [issue-name]
### Phân tích
[phân tích ngắn gọn]
### Giải pháp recommended
[giải pháp cụ thể, actionable]
### Impact
[ảnh hưởng đến REQ-IDs/departments nào]
### Trạng thái: BLOCKING-RESOLVED (AI-recommended)
```

> **Subagent context fallback:** Nếu Agent tool không khả dụng (đang chạy trong subagent context): thực hiện role inline — đọc templates từ `.claude/doc-framework/`, tạo/update files trực tiếp. Ghi chú vào transcript: "[role] executed inline (no Agent tool)."

---

## Resolution Tracks (Phase 6d)

### 4 Tracks Overview

| Track              | Criteria                                                                     | Xử lý                                                                                                                                     |
| ------------------ | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| AUTO-RESOLVE       | Terminology (T-*), SSOT data ownership, status standardization               | BA agent cập nhật docs tự động                                                                                                         |
| EXPERT-RESOLVE     | Priority conflicts (CON-*), scope conflicts, BR choices (severity TRUNG BÌNH/NHỎ) | Spawn domain expert(s) → expert phân tích options → chọn recommended → apply tự động                                                |
| **BLOCKING-RESOLVE** | **Mọi finding severity KHẨN CẤP** + business-rule conflicts blocking Phase 2 | **Spawn expert agents bắt buộc** → experts đề xuất giải pháp best-practice → apply vào dept docs → ghi AI Decision Record |
| DEFER-TO-PHASE     | **CHỈ** items cần architecture context (Phase 3) hoặc implementation context (Phase 5) | Ghi `.mc-data/work/wf-analyze-requirements/deferred-issues.md` — **KHÔNG được defer items KHẨN CẤP**                                   |

### Classification Logic

```
FOR EACH finding:
  IF severity = KHẨN CẤP hoặc finding blocks Phase 2 entry:
    → BLOCKING-RESOLVE (bắt buộc resolve trước khi skill hoàn thành)
    ⚠️ KHÔNG được classify KHẨN CẤP thành DEFER-TO-PHASE vì "cần stakeholder confirm"
    ⚠️ Ví dụ sai: "PDPA consent schema chưa có → cần DEPT-LEGAL xác nhận → DEFER"
    ✅ Ví dụ đúng: "PDPA consent schema chưa có → legal-expert DRAFT schema theo PDPA best practices
       → apply vào dept docs → ghi AI Decision Record → stakeholder có thể điều chỉnh ở Phase 2"
    ✅ Rule: Expert agents có đủ domain knowledge để DRAFT giải pháp ngay.
       "Cần stakeholder confirm" không phải lý do DEFER — stakeholder review xảy ra ở Phase 2.
  ELSE IF finding là terminology/SSOT/standardization:
    → AUTO-RESOLVE
  ELSE IF finding là business-rule conflict/choice VÀ có expert agent phù hợp:
    → EXPERT-RESOLVE
  ELSE IF finding cần architecture/technical design context chưa có:
    → DEFER-TO-PHASE
  ELSE:
    → EXPERT-RESOLVE (default)
```

> **Nguyên tắc:** Ưu tiên RESOLVE tối đa. Chỉ DEFER khi item **thực sự cần context từ phase sau**. Business-rule decisions, compliance requirements, process definitions → expert agents CÓ THỂ giải quyết → KHÔNG được defer.

### AI Decision Record Schema

Append vào cuối `stakeholder-review.md` sau khi BLOCKING-RESOLVE xong:

```markdown
## Phần E: AI Decision Records (BLOCKING-RESOLVED)

> Các quyết định do expert agents đề xuất cho items KHẨN CẤP.
> Stakeholder có thể điều chỉnh trong `/wf-define-features` Phase 0.

### DR-001: [tên issue gốc]
- **Issue gốc:** [DI-ID] — [mô tả]
- **Expert(s) giải quyết:** [expert-name(s)]
- **Giải pháp applied:** [tóm tắt giải pháp]
- **Dept docs updated:** [list files đã cập nhật]
- **Trạng thái:** BLOCKING-RESOLVED (AI-recommended — pending stakeholder confirmation)
```

### deferred-issues.md Schema

CHỈ chứa items DEFER-TO-PHASE — items KHẨN CẤP đã resolve ở step 6d.5.

```markdown
# Deferred Issues từ /wf-analyze-requirements

> Nguồn: phase1-business/stakeholder-review.md — DEFER-TO-PHASE items
> Ngày tạo: [date]
> Consumer: /wf-define-features Phase 0 (context), /wf-design Phase 0 (context)
> LƯU Ý: Không có items KHẨN CẤP — đã được resolve bởi expert agents (xem stakeholder-review.md Phần E)

## Tóm Tắt

| Mức độ | Số lượng | Xử lý khi nào |
|--------|----------|---------------|
| TRUNG BÌNH | [N] | Trong Phase 2 hoặc đầu Phase 3 |
| NHỎ | [N] | Có thể xử lý trong Phase 3 |

## Danh sách Issues

| # | Issue ID | Loại | Severity | Mô tả | Departments liên quan | Phase xử lý |
|---|---------|------|----------|--------|----------------------|-------------|
| 1 | DI-001 | dependency/integration/NFR | Medium/Low | [mô tả issue] | [dept-a, dept-b] | /wf-define-features hoặc /wf-design |

## Chi tiết

### DI-001: [tên issue]
- **Loại:** dependency conflict / integration gap / NFR spec
- **Mô tả:** [chi tiết]
- **Departments:** [liên quan]
- **Đề xuất:** [hướng giải quyết tại phase sau]
- **Tại sao defer:** [lý do cần context từ phase sau — bắt buộc ghi]
```

---

## Registry Schema — requirements[]

Schema chuẩn cho entries trong `requirements[]` (dùng khi extract + Schema Guard Phase 8.3a):

```json
{
  "id": "REQ-[DEPT]-[NNN]",        // string, format REQ-[DEPT]-[NNN]
  "dept": "DEPT-[ID]",             // string, ID phòng ban (không phải "department")
  "title": "string",               // tiêu đề ngắn requirement (không phải "description")
  "priority": "HIGH|MEDIUM|LOW",   // string enum
  "phase": "MVP|Phase2|Phase3",    // string, phase triển khai
  "status": "DRAFT|APPROVED",      // string, trạng thái
  "systems": ["SYS-..."],          // BẮT BUỘC array ≥ 1 system ID — REQ được đáp ứng bởi các systems này
  "primary_module": "MOD-..."      // string, module chính chịu trách nhiệm
}
```

**Ghi chú về `systems[]`:**

- BẮT BUỘC chứa ≥ 1 system ID (khớp với `systems[].id` trong registry).
- Nếu REQ chỉ cần 1 system → `["SYS-X"]`. Nếu REQ cần multi-touchpoint (web + mobile) → `["SYS-WEB-CUSTOMER","SYS-MOBILE-CUSTOMER"]`.
- Extract từ "Hệ thống liên quan" trong ma trận Requirement × System do BA tạo ở Phần A.
- wf-define-features Phase 1 dùng array này để fan-out → 1 FEAT-ID riêng cho mỗi system trong array.
- **Quy tắc cross-check:** Nếu REQ.dept thuộc multi-system department (department có ≥ 2 systems trong `systems[].related_departments` match) → `systems[]` NÊN có ≥ 2 entries trừ khi REQ rõ ràng chỉ dành cho 1 system (ghi rõ lý do trong dept doc).

**Schema Guard jq check (chạy sau upsert):**

```bash
# Phải = 0. Nếu > 0 → có entry dùng field name sai
jq '[.requirements[] | select(has("department") or has("description") or has("source_file"))] | length' registry.json

# Phải = 0. Mỗi REQ phải có systems[] ≥ 1 phần tử
jq '[.requirements[] | select((.systems // []) | length == 0)] | length' registry.json

# Phải = 0. Mỗi REQ.systems[] phải match với .systems[].id đã khai báo
jq --argjson valid "$(jq '[.systems[].id]' registry.json)" \
  '[.requirements[] | .systems[] | select(. as $s | ($valid | index($s)) | not)] | length' registry.json
```

---

## Registry Safe-Write

> Áp dụng cho mọi lần ghi registry trong skill này.

```
1. ĐỌC registry NGAY TRƯỚC KHI GHI — không cache từ đầu session
2. CHỈ MODIFY fields được phân công: systems[], modules[], departments[], requirements[], interface_type
3. NEVER MODIFY: features[], design_status, ux_design_status, implementation_order, impl_status
4. GHI ATOMIC — single write operation cho toàn bộ JSON
5. VALIDATE sau ghi — `jq '.' registry.json` phải pass
```

---

## Fix Rules

| Loại lỗi | Auto-Fix | Escalate nếu |
| --------- | -------- | ------------- |
| File không tồn tại | Tạo từ template/context | Không đủ context |
| File rỗng | Re-run step | Vẫn rỗng sau retry |
| Placeholder (TODO/TBD) | Điền từ context | Không có context → hỏi user |
| REQ-ID format sai | Chuẩn hóa `REQ-[DEPT]-[NNN]` | Ambiguous ID |
| JSON invalid | Fix syntax | Structure corruption |
| Duplicate entries | Merge/deduplicate | Conflicting data |
| Missing cross-reference | Tạo reference | Không biết target |
| `missing_file` (8b) | Check rename/move → fix path; nếu thực sự thiếu → tạo từ context | Context không đủ |
| `missing_registry_entry` | Extract REQ-ID từ source doc → upsert vào registry | Source doc không có |
| `duplicate_id` | Merge duplicates, keep entry với nhiều thông tin hơn | Conflicting data |
| `invalid_json` | Parse error location → fix syntax | Structure corruption |
| `placeholder_found` | Đọc context xung quanh → điền nội dung thực | Context không đủ |
| `pending_deferred` | Items TRUNG BÌNH/NHỎ: WARNING — OK. Items KHẨN CẤP: **FAIL — quay lại Phase 6d.5 BLOCKING-RESOLVE** | — |
| `missing_decision_record` | Tạo AI Decision Record trong stakeholder-review.md Phần E từ Phase 6d output | Source data mất |
| `hallucinated_req` | Xóa REQ-ID khỏi dept docs + registry → log vào report | — |

---

## Token Budget & Checkpoint

### Token Threshold (Protocol 9 — PLN-03)

| Context usage | Hành động |
|---------------|-----------|
| < 65% | Tiếp tục bình thường |
| >= 65% | Ưu tiên finish batch hiện tại → SAVE CHECKPOINT → dừng session |
| >= 80% | KHÔNG spawn thêm agent |
| >= 90% | FORCE STOP |

### Checkpoint Creation (Template Usage Rule)

**Primary checkpoint:** `$SESSION_DIR/session-state.json` (ADR-OPT-02 — 3-level hierarchy L1 Phase / L2 Batch / L3 Item).
**Legacy mirror:** `.mc-data/work/wf-analyze-requirements/checkpoint.json` (backward-compat only — dual-write).

```
1. READ primary template: .claude/skills/workflow/_shared/templates/session-state.json
2. FILL: session_id, skill_name, profile_used, next_action, phases.P{N}.status,
         phases.P{N}.batches[], lanes_completed[], digests_produced[], cdg_decisions[]
3. WRITE atomic: $SESSION_DIR/session-state.json (tmp → validate → mv)
4. DUAL-WRITE legacy: READ templates/checkpoint.json → FILL position/progress/partial_state
   → WRITE atomic: .mc-data/work/wf-analyze-requirements/checkpoint.json
```

**Mọi lần SAVE CHECKPOINT sau:**
- Update `session-state.json` (primary) — merge phases, lanes, cdg_decisions
- Mirror subset sang legacy `checkpoint.json` (position/progress only)
- Cả hai đều atomic write

### Resume Reconciliation (khi `--resume`)

Sau khi load checkpoint: `find .mc-data/docs/phase1-business/departments/ -name "*.md"` → đếm dept files thực tế. Nếu `actual_depts_done != checkpoint.depts_completed` → cập nhật checkpoint: `depts_completed = actual_depts_done`, `current_dept = first_incomplete_dept`. Log: "Reconciled: tìm thấy [N] dept files trên disk — tiếp tục từ dept [next]".

### LPM Checkpoint Frequency

- **Standard:** checkpoint sau Phase 2 (bắt buộc) + sau phases chính (3, 4, 6, 6d, 8b)
- **LPM (Protocol 6.6 LPM-05):** checkpoint sau MỖI phase

---

## Error Codes

| Code | Tình huống | Xử lý |
| ---- | ---------- | ----- |
| E000 | `req-registry.json` không tồn tại | STOP → chạy `/wf-brainstorm` trước |
| E001 | `analyze-status.json` không tạo được | Retry Phase 0, kiểm tra permissions |
| E002 | Scope không xác định được | Hỏi user |
| E003 | Domain không nhận dạng được | Review project overview |
| E004 | `analyze-plan.md` không tạo được | Retry Phase 2 |
| E005 | Không chọn được experts | Kiểm tra domain mapping |
| E006 | BA output thiếu | Retry Phase 3 |
| E007 | Không có consolidated requirements | Retry Phase 6 |
| E008 | Registry thiếu required fields (systems/modules/requirements arrays) | STOP → kiểm tra registry structure, có thể chạy lại `/wf-brainstorm` |
| E009 | Invalid JSON trong registry | Fix JSON syntax, retry Phase 8 |
| E010 | Phase 6d không resolve hết findings | Retry 6d — list PENDING items |
| E011 | Domain expert output thiếu/fail (Phase 4) | Retry expert spawn tối đa 3 lần → nếu 1 expert fail và các expert khác OK → continue, ghi warning; nếu >50% fail → STOP |
| E012 | Registry JSON malformed sau write | Retry 8.6, validate jq trước write |
| E013 | Cross-validation mismatch (8b) | Auto-fix loop (max 3 iterations) → escalate nếu vẫn fail |
| E014 | POST-GATE fail sau 3 retries | STOP — báo cáo chi tiết → user quyết định |
| E015 | Auto-fix gây regression (lỗi mới) | Rollback fix (restore từ checkpoint gần nhất) → escalate with context |
| E016 | Brainstorm output (`P0-01-brainstorm.md`) không tồn tại | STOP → chạy `/wf-brainstorm` trước (bắt buộc theo 00-core Rule 2) |
| E017 | REQ thiếu `systems[]` hoặc chứa system ID không hợp lệ | Auto-fix: derive default = `[modules[primary_module].system]`. Nếu không derive được → STOP, yêu cầu BA bổ sung |
| E018 | System declared trong brainstorm nhưng KHÔNG có REQ nào thuộc `systems[]` (per-system coverage 0) | STOP → rerun BA Phase 3/4 cho department liên quan (được xác định qua `systems[].related_departments[]`). Không được tiếp tục Phase 8b nếu phase=MVP system thiếu coverage |

---

## Output Report Template

ALWAYS dùng template này khi hoàn thành (sau Phase 8c):

**Trước khi in report:** Cập nhật `analyze-status.json`:
- `status = "completed"`
- `progress_pct = 100`
- `timestamps.completed_at = <ISO timestamp>`
- Tất cả phases chưa được đánh dấu → `status = "completed"`

```markdown
## Requirements Analysis hoàn tất!

| Sessions | [X] | Experts | [count] |
|----------|-----|---------|---------|

### Kết quả
| Mục | Số lượng |
|-----|---------|
| Systems | [count] |
| Modules | [count] |
| REQ-IDs | [count] |
| Department digests | `.mc-data/work/wf-analyze-requirements/department-digests.json` |
| Phase 1 handoff | `.mc-data/work/wf-analyze-requirements/phase1-handoff.json` |

### Conflict Resolution Summary
| Track | Số lượng | Trạng thái |
|-------|----------|------------|
| AUTO-RESOLVE | [N] | Đã áp dụng tự động |
| EXPERT-RESOLVE | [N] | Đã áp dụng theo expert recommendation |
| BLOCKING-RESOLVE | [N] | Đã giải quyết bởi expert agents (xem stakeholder-review.md Phần E) |
| DEFER-TO-PHASE | [N] | Chờ xử lý trong Phase 2/3 (xem deferred-issues.md) |

[Nếu có BLOCKING-RESOLVED items:]
### Quyết định AI-Recommended (cần stakeholder review)
| Issue | Expert(s) | Giải pháp tóm tắt |
|-------|-----------|-------------------|
| [DI-ID]: [tên] | [expert-name] | [1-line summary] |

> Stakeholder có thể điều chỉnh các quyết định này trong `/wf-define-features` Phase 0.

[Nếu có DEFER-TO-PHASE items:]
### Deferred Issues (không blocking)
- [N] items TRUNG BÌNH → xử lý trong Phase 2/3
- [N] items NHỎ → xử lý trong Phase 3
- Chi tiết: `.mc-data/work/wf-analyze-requirements/deferred-issues.md`

**Next:** `/wf-define-features` để tạo feature specifications
```
