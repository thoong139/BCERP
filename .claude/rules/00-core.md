---
paths:
  - "**/*"
---

# Core Rules

Rules cốt lõi - LUÔN áp dụng cho mọi dự án.

---

## 0. Priority Order (BẮT BUỘC)

1. **Độ chính xác, tính nhất quán, tính đầy đủ, chất lượng kỹ thuật, bảo mật**
2. **Tốc độ xử lý và song song hóa** — chủ động tối ưu sau khi mục 1 được bảo vệ

- KHÔNG đánh đổi correctness, completeness, security để lấy tốc độ (CORE-023)
- Mọi output downstream PHẢI bám upstream docs + registry (CORE-024)
- Song song hóa CHỈ khi có owner rõ, write scope tách biệt, contract ổn định, re-verification (CORE-025)
- Thiết kế skill PHẢI chủ động xem xét song song hóa, không mặc định sequential (CORE-039)

---

## 1. Single Source of Truth (BẮT BUỘC)

**Primary SSOT:** `.mc-data/docs/_meta/req-registry.json`
**Documents:** `.mc-data/docs/` (doc-framework)

- ĐỌC registry + docs trước khi thiết kế/code (CORE-001)
- KHÔNG thêm tính năng ngoài registry (CORE-004)
- `.mc-data/knowledge-base/` là optional, dùng cho ghi chú bổ sung

---

## 2. Workflow (BẮT BUỘC)

**Không skip phases.** Chưa có output phase trước → KHÔNG chạy phase sau. (CORE-002)

| Phase | Prerequisite |
|-------|-------------|
| Brainstorm (Phase 0) | Entry point |
| Requirements (Phase 1) | Brainstorm |
| Features (Phase 2) | Requirements |
| Design (Phase 3) | Feature specs |
| UX (Phase 4) | Architecture |
| Code (Phase 5) | Design + Plans |
| Preflight | Code |
| Fix Bugs | Code |

> Path chi tiết (STANDARD/EXISTING): xem CLAUDE.md

---

## 3. REQ-ID Tracking (BẮT BUỘC)

Mọi code file PHẢI có REQ-ID tham chiếu requirements: (CORE-003)

```typescript
// REQ-ID: REQ-SALES-001
// FEAT-ID: FEAT-CRM-001
```

Format: `REQ-[DEPT]-[NNN]` (simple) hoặc `REQ-[SYSTEM]-[MODULE]-[NNN]` (complex)

---

## 4. Structured Contract Layer

**Single Source of Truth:** `.mc-data/docs/_meta/req-registry.json`

- `/wf-design` KHÔNG thiết kế module ngoài registry
- `/wf-design` KHÔNG tự tạo REQ-ID mới ngoài registry
- `/wf-plan-modules` PHẢI đọc registry JSON, không parse Markdown

### 4a. Registry Safe-Write Protocol

Mỗi skill chỉ update ĐÚNG fields được phân công. KHÔNG ghi đè fields của skill khác. (CORE-006)

**Role quy ước:** PRIMARY (owner, write đầy đủ) | SEED (write 1 lần) | APPEND (chỉ thêm mới) | SAFE-UPDATE (chỉ upgrade impl_status) | FIX-INVALID (invalid → default) | UPDATE-MODE (theo change_type) | NONE (không update)

> **Bảng phân công chi tiết (canonical):** `.claude/skills/protocols/05-registry-safe-write.md`

```
QUY TẮC SAFE-WRITE:
1. ĐỌC registry NGAY TRƯỚC KHI GHI — không cache từ đầu session
2. CHỈ MODIFY fields được phân công — giữ nguyên mọi fields khác
3. GHI ATOMIC — single write operation cho toàn bộ JSON
4. VALIDATE sau ghi — `jq '.' registry.json` phải pass

VERIFY-SYNC SAFE-UPDATE (CORE-008):
- KHÔNG downgrade impl_status từ "done" → giá trị khác
- Nếu code scan không tìm thấy REQ-ID đã done → WARNING, hỏi user

IMPL_STATUS STATES (CORE-010):
- "not_started" (default) | "in_progress" | "done" | "skipped"

REGISTRY SCHEMA VALIDATION (CORE-009):
- Validate: jq -e '.requirements | length > 0' req-registry.json
- KHÔNG chỉ check file existence — phải check content validity
```

> **CORE-011 — Forensic PRE-GATE:** Entry PRE-GATE kiểm tra CONTENT files, không chỉ existence. Protocol: `.claude/skills/protocols/10-post-gate-schema.md` §10.4.
> **CORE-012 — POST-GATE:** T1 (exists) → T2 (structure) → T3 (content depth) → T4 (cross-reference). Protocol: `.claude/skills/protocols/10-post-gate-schema.md` §10.1.

### 4b. Cross-Skill Output Path Contract (CORE-007)

Paths giữa các skills PHẢI khớp nhau.

> **Bảng contract chi tiết (canonical):** `.claude/skills/protocols/21-cross-skill-output-path-contract.md`

### 4c. CORE-019: Feature-Level Code Verification (BẮT BUỘC cho legacy)

```
wf-plan-modules PHẢI xác định implementation_strategy per feature
dựa trên cross-reference code thực tế (KHÔNG chỉ dựa vào impl_status registry).

Mỗi task file PHẢI có:
- implementation_strategy: VERIFY_ONLY | COMPLETE_EXISTING | IMPLEMENT_NEW
- existing_code_refs: [list of code files if applicable]
- gaps_identified: [list of specific gaps if COMPLETE_EXISTING]
```

### 4d. CORE-020: Pre-Implementation Safety Gate (BẮT BUỘC — MỌI DỰ ÁN)

```
wf-implement-feature PHẢI tìm kiếm code hiện tại TRƯỚC khi viết code mới.
KHÔNG bao giờ silent overwrite existing working code.

- LEGACY_MODE: Route theo implementation_strategy từ task file
- NEW project: Lightweight search — nếu tìm thấy code liên quan → cảnh báo + hỏi user
```

### 4e. CORE-021: LEGACY_MODE Detection (BẮT BUỘC)

```
Tất cả skills detect LEGACY_MODE bằng cùng 1 mechanism:
  LEGACY_MODE = test -f .mc-data/work/legacy-scan/project-context.md && size > 500 bytes

KHÔNG detect bằng ledger.json (false positive — tồn tại từ Stage 0.5).
```

### 4f. CORE-022: Legacy Decisions Bridge (BẮT BUỘC — LEGACY_MODE)

```
- wf-brainstorm PHẢI tạo legacy-decisions.json ở Phase 0.5.7, kể cả khi rỗng
- Tất cả downstream skills PHẢI đọc file này ở PRE-GATE
- Modules có action="DEPRECATE" bị loại khỏi mọi output downstream
- File READ-ONLY sau khi tạo — downstream skills KHÔNG được ghi đè

GRACEFUL DEGRADATION: file không tồn tại → cảnh báo, tiếp tục với DEPRECATED_MODULES=[]
```

### 4g. CORE-026: Execution Trace

Mọi skill ghi START/COMPLETE/FAIL vào `.mc-data/work/_trace/session-log.json` (output-only, KHÔNG dùng làm input context). KHÔNG Read toàn bộ file — chỉ append.

### 4h. CORE-031: Template Usage Rule (BẮT BUỘC)

> Mọi output file PHẢI tạo từ template: READ → POPULATE → WRITE. Protocol: `.claude/skills/protocols/19-template-usage.md`

```
- Mọi step tạo output file PHẢI ghi "từ template [path]"
- _contract.json outputs.working[] PHẢI có field "template"
- KHÔNG tạo output từ đầu (ad-hoc)
- Template locations: skills/workflow/[skill]/templates/, doc-framework/[phase]/, doc-framework/_digests/, doc-framework/_meta/
- Template metadata stripping: xóa _template_notes, _schema_notes trước khi write
```

### 4i. CORE-032: Skill Architecture — Lazy-Load Procedures (BẮT BUỘC)

> Đúc kết từ wf-fix-bugs v10.0 và wf-legacy-scan v5.0. Áp dụng cho MỌI skill có >3 bước xử lý.

```
SKILL.md là lean routing hub (≤500 dòng, KHÔNG chứa code thực thi):
  - Overview, arguments, phase routing map (bảng + flow diagram)
  - Condensed summaries per phase (input → output → steps overview)
  - PRE-GATE / POST-GATE file contract table
  - Output files table với template paths
  - Error codes quick lookup
  - Context & checkpoint thresholds

TOÀN BỘ execution logic trong procedure files riêng:
  - procedures/_shared.md — cross-cutting concerns (state variables, atomic write, error handling, CI detection)
  - procedures/phase{N}-{name}.md — chi tiết từng phase (PRE-GATE → Steps → POST-GATE → Report)
  - procedures/resume-status.md — --resume & --status handlers

QUY TẮC:
  - Mỗi procedure file CHỈ đọc khi tới phase tương ứng (lazy-load)
  - Phase transition qua PRE-GATE verify output phase trước → execute → POST-GATE validate
  - Pipeline state lưu trong fix-status.json (hoặc tương đương), update atomic sau mỗi POST-GATE
  - KHÔNG nhúng bash script inline — delegate sang scripts/ hoặc Python CLI _shared/
```

**Lợi ích:** Giảm 70%+ context so với monolithic skill. Mỗi phase tự chứa đầy đủ logic, dễ kiểm tra và debug.

### 4j. CORE-033: CI-First Integration (BẮT BUỘC)

> Đúc kết từ Protocol 20 + wf-fix-bugs v10.0 CI PRE-GATE. Áp dụng cho MỌI skill cần đọc/analyze code.

```
CI PRE-GATE (3-step — chạy tại Phase Init, trước PRE-GATE validation):

  Na. LOAD CI CAPABILITIES:
      Run bash .claude/scripts/ci-detect.sh → check per-tool TTL
      Set $GITNEXUS_AVAILABLE, $SERENA_AVAILABLE
      Graceful: lock held → fallback Grep/Glob

  Nb. INDEX FRESHNESS CHECK:
      Run bash .claude/scripts/ci-freshness-check.sh
      4 mức: ok (0-5 commits behind) / light (6-20) / strong (>20) / severe (stale index)
      Strong/severe → WARN, fallback Grep

  Nc. AGENT CONTEXT INJECTION:
      IF CI available → bash .claude/scripts/ci-inject-context.sh → $CI_CONTEXT
      Pass CI_CONTEXT vào spawned agents qua prompt

CI-ROUTE MATRIX (ưu tiên tool):
  1. Primary tool (GitNexus/Serena) → 2. Secondary → 3. Fallback (Grep/Glob)
  KHÔNG hỏi user chọn tool — auto-detect + graceful degradation
  Cache TTL: GitNexus 24h (available) / 4h (absent), Serena 24h / 1h
```

### 4k. CORE-034: Namespaced Error Codes & Auto-Fix Budget (BẮT BUỘC)

> Đúc kết từ wf-fix-bugs v10.0 Error Handling Canonical. Áp dụng cho MỌI skill có multi-phase pipeline.

```
ERROR CODE NAMESPACE CONVENTION:
  E001-E009   → Pipeline/session/lock (shared across all phases)
  E010-E019   → Phase 1 (Init)
  E020-E029   → Phase 2
  E030-E039   → Phase 3
  ... (mỗi phase 1 range 10 codes)
  E090-E099   → CDG User-Facing Gates
  E100-E109   → Recommendations/Warnings

ERROR LEDGER:
  - File: $SESSION_DIR/error-ledger.json (APPEND-only JSONL, Atomic Write Pattern)
  - Mỗi entry: {phase, error_code, message, timestamp, retry_count}
  - KHÔNG đọc lại làm input context (output-only, như CORE-026)

AUTO-FIX BUDGET MODEL (per-phase):
  - Max 3 retries / phase (tất cả tier gộp chung budget)
  - Auto-fix strategies per error type:
    · T1 fail (file missing) → re-run step tạo file
    · T2 fail (structure wrong) → re-read template + populate lại
    · T3 fail (content too short) → re-generate với more context
    · T4 fail (cross-ref mismatch) → re-read source + re-write target
  - Budget hết → ESCALATE: AskUserQuestion "Re-run phase / Skip (risky) / Cancel"
  - Reset budget khi POST-GATE PASS

ON FAILURE STANDARD FORMAT:
  1. APPEND error-ledger.json
  2. AUTO-FIX attempt (max 3)
  3. Nếu vẫn fail: WRITE Phase{N}-report.md FAILED → UPDATE fix-status → STOP
  4. KHÔNG advance sang phase tiếp theo khi POST-GATE chưa pass
```

### 4l. CORE-035: Phase Output Organization (BẮT BUỘC)

> Đúc kết từ wf-fix-bugs v10.0 session directory structure. Áp dụng cho MỌI skill có multi-phase output.

```
SESSION DIRECTORY STRUCTURE:
  $SESSION_DIR/                          # .mc-data/work/{skill}/sessions/{SESSION_ID}/
  ├── fix-status.json                    # SSOT pipeline state (Atomic Write)
  ├── session-log.json                   # Execution trace (CORE-026, APPEND-only)
  ├── error-ledger.json                  # Error tracking (CORE-034, APPEND-only)
  ├── .lock                              # Session lock + heartbeat daemon
  ├── phase{N}-{name}/                   # MỖI PHASE CÓ SUBDIRECTORY RIÊNG
  │   ├── Phase{N}-report.md             # Báo cáo tiếng Việt ≤15 dòng (CORE-028)
  │   ├── [output files].json/md         # Output đặc thù của phase
  │   └── ...

PHASE REPORT FORMAT (CORE-028, tiếng Việt, ≤15 dòng):
  ## Phase [N]: [Tên phase] — PASS|FAIL
  Thời gian: [ISO-8601]
  **Đã làm:** [1-2 câu]
  **Kết quả:** [Số liệu chính] + [File đầu ra]
  **Tiếp theo:** [Phase kế tiếp hoặc hành động user]
  
  QUY TẮC: KHÔNG dùng jargon kỹ thuật — viết cho người không chuyên

ATOMIC WRITE PATTERN (cho MỌI JSON state file):
  1. Build new content vào tmp file (.tmp.$$)
  2. Validate tmp file pass JSON parse (jq '.' > /dev/null)
  3. Atomic move (mv tmp → target)

SESSION_ID FORMAT: YYYY-MM-DD-{scope}-{slug}-{NN}
INDEX: .mc-data/work/{skill}/_index/sessions.jsonl (APPEND-only)
```

### 4m. CORE-036: Cross-Skill Artifact Contract (BẮT BUỘC)

> Đúc kết từ wf-fix-bugs v10.0 `_contract.json` cross-skill contracts. Áp dụng cho MỌI skill có output được skill khác consume.

```
_CONTRACT.JSON CROSS-SKILL SECTION:
  - orchestrates[]: skills được spawn bởi skill này (trigger, passes, validation)
  - produces_for{}: map skill-name → [list artifacts produced]
  - consumes_from{}: map skill-name → [list artifacts consumed]

CROSS-SKILL ARTIFACT REQUIREMENTS:
  - Schema versioned (vd: fix-impact-v2)
  - audit_chain = sha256 của source state file
  - Consumer skills validate artifact ở PRE-GATE (T1 exists → T2 structure → T3 content)
  - KHÔNG hardcode paths — dùng canonical paths từ _contract.json

PRODUCER-CONSUMER CONTRACT:
  - Producer skill ghi artifact vào output path cố định
  - Consumer skill đọc artifact ở PRE-GATE, validate schema version
  - Nếu artifact thiếu/version mismatch → WARN, graceful degradation
```

### 4n. CORE-037: Agent Prompt Templates (BẮT BUỘC)

> Đúc kết từ wf-fix-bugs v10.0 Agent Prompt Templates. Áp dụng cho MỌI skill spawn agent.

```
MỖI AGENT PROMPT PHẢI CÓ:
  1. Role declaration — "Bạn là [role] cho [skill]"
  2. Task instruction — "Đọc file [SKILL.md path] và thực thi đầy đủ"
  3. Session context — SESSION_DIR, PROFILE, SCOPE, NAME
  4. CI context injection — $CI_CONTEXT (nếu CI available)
  5. Playwright context — mode, devices, base URL (nếu applicable)
  6. Output contract — path cụ thể cho từng output, schema reference
  7. Ownership rules — 1 file = 1 writer, KHÔNG ghi đè output của agent khác
  8. Completion criteria — "Khi hoàn tất, outputs phải pass POST-GATE validation"

QUY TẮC SPAWN:
  - Spawn với model="opus" (nếu Sonnet quota hết)
  - Max concurrency: 10 agents (CORE-025)
  - 1 file = 1 writer — không 2 agent ghi cùng 1 file
  - CI context injection string đã được chuẩn bị ở CI PRE-GATE Nc
```

### 4o. CORE-038: Context Budget Management (BẮT BUỘC)

> Đúc kết từ wf-fix-bugs v10.0 và wf-legacy-scan v5.0. Áp dụng cho MỌI skill có multi-phase hoặc xử lý dữ liệu lớn.

```
CONTEXT BUDGET TIERS:
  < 65%    → Tiếp tục bình thường
  65-80%   → Chuẩn bị checkpoint (lưu state files)
  80-90%   → Lưu checkpoint, STOP sau phase hiện tại → hướng dẫn --resume
  > 90%    → FORCE STOP (E009) — checkpoint bắt buộc, không advance

CHECKPOINT FILES TỐI THIỂU:
  - fix-status.json (hoặc state file tương đương) — phase hiện tại + next_action
  - session-log.json — execution trace đến thời điểm checkpoint
  - Current Phase{N}-report.md — báo cáo phase hiện tại

RESUME FLOW:
  1. Đọc fix-status.json → xác định last completed phase
  2. Stale check: lock age > 30 min → auto-release
  3. Route đến next_action (phase tiếp theo hoặc re-run phase hiện tại nếu interrupt)
  4. Re-validate PRE-GATE trước khi tiếp tục
```

### 4p. CORE-039: Parallelization Strategy (BẮT BUỘC cho skill mới và overhaul)

> Đúc kết từ feedback 2026-05-16 + pattern wf-fix-bugs QD1-QD11 + wf-cmi v2.0 26-lane 3-wave. Áp dụng cho MỌI skill mới hoặc khi overhaul skill hiện có. Skill hiện có (trước 2026-05-16) được grandfathered — KHUYẾN NGHỊ bổ sung khi có cơ hội.

```
NGUYÊN TẮC:
  Sau khi đảm bảo accuracy + quality (Priority §0 mục 1),
  thiết kế skill PHẢI CHỦ ĐỘNG tối ưu thời gian xử lý bằng song song hóa
  các bước an toàn — không mặc định sequential.

BẮT BUỘC TRONG SKILL.md:
  Section "Parallelization Strategy" liệt kê phase-by-phase:
  - Step/Phase nào dùng PARALLEL | SEQUENTIAL | HYBRID
  - Owner agent (nếu PARALLEL)
  - Write scope tách biệt (path/file đầu ra của từng lane)
  - Lý do an toàn (contract ổn định, không race condition)
  - Merge checkpoint (POST-GATE / aggregate step)
  - Nếu 100% sequential → ghi rõ "KHÔNG có cơ hội song song hóa an toàn vì [lý do]"

PATTERN PARALLEL-SAFE ĐÃ CHUẨN HÓA (ưu tiên dùng):
  - Lane parallel: spawn nhiều Agent() trong cùng 1 message
    (vd: wf-fix-bugs QD1-QD11, wf-cmi CD1-CD40)
    → Tham chiếu: docs/03-design-patterns/04-parallel-lane-dispatch.md
  - Wave dispatch: chia theo dependency graph
    (vd: wf-cmi v2.0 wave-coordinator 3-wave, wf-e2e-batch topology sort)
  - Read-then-merge: nhiều reader song song + 1 writer hợp nhất (CORE-006)
  - Bash parallel: chạy nhiều bash command độc lập trong cùng response

ĐIỀU KIỆN BẮT BUỘC TRƯỚC KHI CHẤP NHẬN PARALLEL (CORE-025):
  1. Contract đầu ra rõ ràng cho từng lane
  2. 1 file = 1 writer (Safe-Write Protocol)
  3. Write scope KHÔNG chồng lấn (lock + heartbeat nếu cần)
  4. Có checkpoint hợp nhất + verify sau merge

KHÔNG song song hóa khi:
  - Lane sau cần đọc kết quả lane trước (dependency thật sự)
  - Cùng ghi vào một file/registry mà không có lock
  - Output không deterministic dưới race condition

COMPLIANCE:
  - skill-compliance-audit.sh kiểm tra section tồn tại (BẮT BUỘC cho skill v ≥ release_date 2026-05-16)
  - Skill cũ grandfathered: WARN nếu thiếu, không fail
  - Khi overhaul skill cũ → BẮT BUỘC bổ sung section
```

---

## 5. Ngôn ngữ (CORE-005)

| Loại | Ngôn ngữ |
|------|----------|
| Documentation, comments | **Tiếng Việt** |
| File names, variables, functions | **English** hoặc tiếng Việt không dấu |

---

## Quick Reference

| ID | Rule | Priority |
|----|------|----------|
| CORE-001 | Đọc registry + docs trước khi code | BẮT BUỘC |
| CORE-002 | Không skip workflow phases | BẮT BUỘC |
| CORE-003 | REQ-ID trong mọi code files | BẮT BUỘC |
| CORE-004 | Registry là single source of truth | BẮT BUỘC |
| CORE-005 | Vietnamese docs, English code | BẮT BUỘC |
| CORE-006 | Registry safe-write: chỉ update fields được phân công | BẮT BUỘC |
| CORE-007 | Cross-skill output paths phải khớp nhau | BẮT BUỘC |
| CORE-008 | Verify-sync không downgrade impl_status=done | BẮT BUỘC |
| CORE-009 | Registry schema validation: check content, không chỉ file existence | BẮT BUỘC |
| CORE-010 | impl_status chỉ có 4 giá trị: not_started, in_progress, done, skipped | BẮT BUỘC |
| CORE-011 | Forensic PRE-GATE: entry PRE-GATE kiểm tra content, không chỉ file existence (Protocol 10.4) | BẮT BUỘC |
| CORE-012 | POST-GATE schema validation: tiered T1→T4 checks (Protocol 10) | BẮT BUỘC |
| CORE-013 | Module-code alignment required trước normalize (module-code-mapping.json) | BẮT BUỘC |
| CORE-014 | Tech stack verification: code_parse > config > doc_infer | BẮT BUỘC |
| CORE-015 | Naming normalization required trước Phase 2 doc generation | BẮT BUỘC |
| CORE-016 | Classify POST-GATE phải check naming consistency (kebab-case) | BẮT BUỘC |
| CORE-017 | Extract Module Resolution phải normalize names (lowercase-kebab-case) | BẮT BUỘC |
| CORE-018 | Gap analysis phải cross-validate naming giữa registry, Phase 2, module-code-mapping, Phase 0-1 | BẮT BUỘC |
| CORE-019 | Feature-Level Code Verification: implementation_strategy per feature từ code thực tế | BẮT BUỘC |
| CORE-020 | Pre-Implementation Safety Gate: search code hiện tại trước khi viết mới (mọi dự án) | BẮT BUỘC |
| CORE-021 | LEGACY_MODE Detection: dùng project-context.md (>500 bytes), không dùng ledger.json | BẮT BUỘC |
| CORE-022 | legacy-decisions.json: wf-brainstorm tạo, downstream đọc và enforce | BẮT BUỘC |
| CORE-023 | Priority Order: chất lượng, correctness, security trước tốc độ | BẮT BUỘC |
| CORE-024 | Downstream outputs phải có căn cứ từ upstream docs + registry | BẮT BUỘC |
| CORE-025 | Song song hóa chỉ khi có ownership, isolated scope, stable contract, re-verification | BẮT BUỘC |
| CORE-026 | Execution Trace: ghi START/COMPLETE/FAIL vào session-log.json (output-only) | BẮT BUỘC |
| CORE-027 | Critical Decision Gate: 7 CDG points — xem `protocols/16-critical-decision-gate.md` | BẮT BUỘC |
| CORE-028 | Phase Summary: tạo phase-summary.md sau POST-GATE, tiếng Việt, cho non-specialist | BẮT BUỘC |
| CORE-029 | Agent Output Spot-Check: kiểm tra agent output tuân thủ schema trước khi ghi | BẮT BUỘC |
| CORE-030 | Working Directory Session Isolation: cô lập data vào sessions/{id}/ | BẮT BUỘC |
| CORE-031 | Template Usage Rule: mọi output file phải từ template (READ→POPULATE→WRITE), Protocol 19 | BẮT BUỘC |
| CORE-032 | Skill Architecture: lazy-load procedures — SKILL.md lean routing hub (≤500 dòng), logic trong procedure files | BẮT BUỘC |
| CORE-033 | CI-First Integration: auto-detect GitNexus/Serena, CI PRE-GATE 3-step (Na/Nb/Nc), graceful degradation | BẮT BUỘC |
| CORE-034 | Namespaced Error Codes: phase-based ranges (E010-E019 Phase 1, ...), auto-fix budget max 3 retries/phase | BẮT BUỘC |
| CORE-035 | Phase Output Organization: session subdirectories phase{N}-{name}/, Phase{N}-report.md, atomic write JSON | BẮT BUỘC |
| CORE-036 | Cross-Skill Artifact Contract: produces_for/consumes_from, schema versioned, audit_chain checksum | BẮT BUỘC |
| CORE-037 | Agent Prompt Templates: 8 required sections (role, task, session, CI, playwright, output, ownership, completion) | BẮT BUỘC |
| CORE-038 | Context Budget Management: tiered thresholds (<65% OK, 65-80% prep, 80-90% stop, >90% FORCE STOP E009) | BẮT BUỘC |
| CORE-039 | Parallelization Strategy: SKILL.md bắt buộc có section "Parallelization Strategy" phase-by-phase (grandfathered cho skill cũ) | BẮT BUỘC |

**Behavioral Principles** (xem `.claude/rules/00-behavioral.md`):

| ID | Rule | Priority |
|----|------|----------|
| BHV-001 | Hỏi trước khi giả định (Think Before Coding) | BẮT BUỘC |
| BHV-002 | Đơn giản trước tiên (Simplicity First) | BẮT BUỘC |
| BHV-003 | Thay đổi phẫu thuật (Surgical Changes) | BẮT BUỘC |
| BHV-004 | Thực thi hướng mục tiêu (Goal-Driven Execution) | BẮT BUỘC |
