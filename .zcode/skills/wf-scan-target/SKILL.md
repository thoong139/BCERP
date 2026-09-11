---
name: wf-scan-target
version: 2.0.1
last_updated: 2026-04-28
description: |
  Skill quét toàn bộ một target (module, hệ thống ERP, website, hoặc path source code),
  trả về module map, feature inventory, JSON metadata và gap report.

  Dùng để hiểu rõ một module/hệ thống đang có những gì trước khi tạo module mới hoặc
  lên kế hoạch refactor, migration, hay integration.

  LUÔN dùng skill này khi user:
  - Muốn "quét module cũ" để hiểu cấu trúc trước khi tạo module mới
  - Cần biết một module/hệ thống đang có những API, screens, entities nào
  - Muốn so sánh module hiện tại với spec/yêu cầu mới
  - Cần output dạng tài liệu để các workflow khác có thể consume
  - Gọi trực tiếp: /wf-scan-target --target=<path|url>

  KHÔNG trigger khi: đang implement code mới, fix bug, chỉ cần đọc 1-2 file cụ thể.

argument-hint: "--target=<path|url> [--module=<name>] [--compare=<spec-path>] [--depth=shallow|deep] [--profile=quick|standard|deep|exhaustive] [--max-pages=N] [--since=<git-ref>] [--resume] [--status] [--session=<id>] [--output=<dir>] [--no-cache] [--cache-fingerprint-mode=strict|loose]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, WebFetch, WebSearch, AskUserQuestion
---

# /wf-scan-target: $ARGUMENTS

## Overview

| Mục | Nội dung |
|-----|----------|
| **Mục đích** | Quét target và tạo module map, feature inventory, JSON metadata, gap report |
| **Prerequisites** | Không — standalone skill |
| **Workflow position** | Standalone — KHÔNG thuộc main DEVKIT pipeline |
| **Phases** | 6 phases: Setup → Detect → Multi-Layer Scan → Synthesis → Gap → Output |
| **Duration** | 5-20 phút tùy target size và depth |
| **Output** | `module-map.md`, `target-map.json`, `feature-inventory.md`, `phase-summary.md`, `gap-report.md` (conditional) |

### Workflow Position

```
[Standalone — không thuộc main DEVKIT pipeline]

Có thể gọi bất kỳ lúc nào:
  /wf-scan-target --target=apps/backend/Eureka.Modules.CRM --module=crm
  /wf-scan-target --target=https://example.com --module=dashboard
  /wf-scan-target --target=./old-project/src --compare=.mc-data/docs/phase2-features/crm/crm-feat.md
```

---

## Arguments

| Argument | Mô tả | Required | Default |
|----------|-------|----------|---------|
| `--target=<path\|url>` | Path source code local hoặc URL cần scan | **BẮT BUỘC** | — |
| `--module=<name>` | Tên module cụ thể cần focus | Optional | _(auto-detect)_ |
| `--compare=<path>` | Path đến spec/feature file để so sánh và tạo gap report | Optional | — |
| `--depth=shallow\|deep` | Mức độ scan: shallow (structure only), deep (full analysis) | Optional | `deep` |
| `--output=<dir>` | Thư mục output tùy chỉnh (trigger CDG-02 nếu dir đã có nội dung) | Optional | `.mc-data/work/wf-scan-target/sessions/{session_id}/` |
| `--resume` | Tiếp tục session in_progress/paused gần nhất | Optional | — |
| `--status` | Hiển thị status các sessions (table 5 latest), KHÔNG scan → STOP | Optional | — |
| `--session=<id>` | (chỉ dùng cùng `--resume`) Resume session ID cụ thể | Optional | _(auto-pick latest)_ |
| `--no-cache` | Sprint 6 — Bypass cache lookup (Phase 1.5) + KHÔNG ghi cache mới khi xong. Dùng khi muốn fresh scan dù fingerprint match cache (TTL 24h) | Optional | _(false — cache enabled)_ |
| `--profile=quick\|standard\|deep\|exhaustive` | **Sprint 7** — Profile system. Map sang depth + MAX_PAGES (URL crawl): quick/standard/deep/exhaustive → 5/25/50/100 pages. exhaustive bật LPM (15 validators, 20-30 features, similarity 0.5 + fuzzy notes). Xem section Profiles bên dưới. | Optional | `standard` |
| `--max-pages=N` | **Sprint 7** — Override profile default MAX_PAGES (URL crawl). Hard cap 200 (Q4 — vượt phải chạy nhiều sessions với scope filter, tránh DDoS target). | Optional | _(theo profile: 5/25/50/100)_ |
| `--since=<git-ref>` | **Sprint 7** — Delta scan. Compute changed files giữa `<git-ref>..HEAD`, restrict L1-L4 chỉ trên changed files. Yêu cầu target=local-source trong git repo. Filter A/M/R, skip D. Defensive: skip cache lookup + write khi delta mode. | Optional | _(null — full scan)_ |
| `--cache-fingerprint-mode=strict\|loose` | **v2.0.1 BUG-003 fix** — Control git_dirty signal trong fingerprint composite. `strict` (default): include git_dirty → cache invalidate khi có uncommitted changes (an toàn). `loose`: skip git_dirty → cache stable trên dev project chưa gitignore `.mc-data/` (mỗi scan tạo session files mới sẽ KHÔNG toggle fingerprint). Trade-off: loose mode có thể serve cached output stale nếu source thực sự có uncommitted changes. | Optional | `strict` |

---

## Profiles (Sprint 7)

| Profile | scan_depth | MAX_PAGES (URL crawl) | LPM | Use case |
|---------|-----------|----------------------|-----|----------|
| `quick` | shallow | 5 | — | Smoke test, quick overview, ~30s |
| `standard` (default) | deep | 25 | — | Default scan, ~3-8 min |
| `deep` | deep | 50 | — | Comprehensive scan, business rules deep extract, ~10-20 min |
| `exhaustive` | deep | 100 | ✓ | Enterprise full coverage, ~30+ min — bật LPM extensions: 15 validators (vs 5), key_features 20-30 (vs 10-20) + coverage validation, gap match similarity 0.5 (vs 0.6) + fuzzy notes |
| (override) | từ `--depth` | từ `--max-pages` (1-200) | — | User control |

**Q4 ADAPTIVE quyết định:** Profile mapping cố định 5/25/50/100 + hard cap 200 cho `--max-pages`. Vượt 200 phải chạy nhiều sessions với scope filter (tránh DDoS / rate-limit / billing impact).

**Examples (Sprint 7):**
```bash
# Quick smoke test (chỉ L1, max 5 URL pages)
/wf-scan-target --target=apps/backend/Eureka.Modules.CRM --profile=quick

# Exhaustive enterprise scan với LPM
/wf-scan-target --target=apps/backend/Eureka.Modules.Finance --profile=exhaustive

# Delta scan: chỉ scan files thay đổi 5 commits gần nhất
/wf-scan-target --target=apps/backend/Eureka.Modules.CRM --since=HEAD~5

# Override max-pages cho URL scan lớn (max 200, Q4 hard cap)
/wf-scan-target --target=https://docs.example.com --profile=deep --max-pages=100

# Combine: delta + profile + module
/wf-scan-target --target=. --module=crm --since=v1.5.0 --profile=deep
```

---

## Output Files

| # | File | Mô tả | Bắt buộc |
|---|------|-------|----------|
| 1 | `module-map.md` | Bản đồ toàn diện của module: structure, APIs, screens, entities | Có |
| 2 | `target-map.json` | Machine-readable metadata (v2 schema từ Sprint 5: scan_fingerprint, scan_diff, traceability, module_code_mapping, consumer_hints) — dùng cho consumer skills via OPTIONAL `--from-scan` | Có |
| 3 | `feature-inventory.md` | Danh sách tính năng, CRUD ops, business rules đã có | Có |
| 4 | `phase-summary.md` | Tóm tắt scan tiếng Việt cho non-specialist (Protocol 14) | Có |
| 5 | `gap-report.md` | So sánh với spec, đánh dấu FOUND/MISSING/PARTIAL | Chỉ khi `--compare` |
| 6 | `scan-status.json` | Tracking file — status, session metadata, target_fingerprint | Có |
| 7 | `checkpoint.json` | Checkpoint cho `--resume` (next_action, intermediate_outputs) | Có |
| 8 | `intermediate/*.json` | Partial layer outputs (tech-stack, l1-l4, synthesis, gap) + **Sprint 7:** `changed-files.json` (chỉ khi `--since`) | Khi đa-phase chạy |
| 9 | `_shared/scans-index.jsonl` | APPEND 1 entry / scan completed (Sprint 6 — git-sync friendly JSONL) | Có |
| 10 | `_shared/history.jsonl` | APPEND compact rotation log (Sprint 6 — Sprint 7 sẽ rotation 200-entry) | Có |
| 11 | `_shared/cache/{TARGET_FINGERPRINT}.json` | Per-machine cache (Sprint 6 — `.gitignore`'d, TTL 24h, bypass via `--no-cache`) | Có (trừ khi `--no-cache`) |

### Output Location

```
.mc-data/work/wf-scan-target/
├── sessions/{YYYY-MM-DD}-{scope-label}[-{N}]/
│   ├── module-map.md, target-map.json, feature-inventory.md
│   ├── phase-summary.md       (Protocol 14 — tiếng Việt)
│   ├── gap-report.md          (chỉ khi --compare)
│   ├── scan-status.json, checkpoint.json
│   ├── .lock                  (Sprint 6 — process lock với cross-host detection + trap EXIT cleanup)
│   └── intermediate/
│       ├── tech-stack.json (sau Phase 1)
│       ├── l{1,2,3,4}-*.json (sau Phase 2 layers)
│       ├── synthesis.json (sau Phase 3)
│       └── gap.json (sau Phase 4 — nếu --compare)
└── _shared/                   (Sprint 6 multi-dev safety)
    ├── scans-index.jsonl      (APPEND 1 entry / scan completed — git-sync friendly)
    ├── history.jsonl          (compact rotation log — Sprint 7 sẽ rotation 200-entry)
    └── cache/                 (per-machine, .gitignore'd, TTL 24h)
        └── {TARGET_FINGERPRINT}.json

Session ID format (Protocol 18.2): {YYYY-MM-DD}-{scope-label}[-{N}]
Trace log (Protocol 15 — output-only): .mc-data/work/_trace/session-log.json
```

---

## Resume & Status (Sprint 2 — GAP-05)

```
/wf-scan-target --status                          # Hiển thị 5 sessions gần nhất → STOP
/wf-scan-target --resume                          # Tiếp tục session in_progress/paused gần nhất
/wf-scan-target --resume --session=2026-04-27-crm # Tiếp tục session cụ thể
```

Cơ chế: `procedures/resume-status.md` dispatch TRƯỚC khi parse args đầy đủ. `--resume` verify
target_fingerprint (composite path+tech+depth+git_HEAD+git_dirty+manifests). Khác → CDG hỏi user.

---

## Protocols Reference

> **Protocol:** Xem `.claude/skills/protocols/` — Protocol 10 (POST-GATE Schema), Protocol 14 (Phase Summary),
> Protocol 15 (Execution Trace), Protocol 16 (CDG), Protocol 18 (Session Isolation), Protocol 19 (Template Usage Rule / CORE-031).
>
> **Internal shared:** Xem `procedures/_shared.md` — State Variables, Helper Functions, Agent Prompts, Error Handling.
>
> **Bash scripts (Sprint 4 — bash delegation, ~88% token saving):**
> - `.claude/scripts/scan-target-common.sh` — atomic_write_json, json_escape, slugify, lock helpers
> - `.claude/scripts/scan-target-fingerprint.sh` — Q6 composite hash (path+tech+depth+git_HEAD+git_dirty+manifests)
> - `.claude/scripts/scan-target-detect.sh` — Phase 1 tech stack detection
> - `.claude/scripts/scan-target-inventory.sh` — Phase 2 L1 file structure + key files
> - `.claude/scripts/scan-target-api.sh` — Phase 2 L2 API endpoints discovery
> - `.claude/scripts/scan-target-ui.sh` — Phase 2 L3 UI screens (LOCAL only — URL crawl giữ AI)
> - `.claude/scripts/scan-target-db.sh` — Phase 2 L4 DB entities (.NET EF + Prisma + TypeORM + Drizzle)

---

## Phase Routing Map (lazy-loaded)

> SKILL.md routing block KHÔNG chứa execution steps. Toàn bộ logic chi tiết được lazy-load
> qua các phase files riêng. Read MỖI phase file CHỈ KHI tới phase tương ứng để giảm context load.

| Phase | Procedure file | Điều kiện |
|-------|----------------|-----------|
| **Resume/Status** | `procedures/resume-status.md` | `--status` hoặc `--resume` (TRƯỚC parse args đầy đủ) |
| **0** | `procedures/phase0-setup.md` | Fresh run (entry point) |
| **1** | `procedures/phase1-detect.md` | Always (sau Phase 0) |
| **2.L1** | `procedures/phase2-l1-structure.md` | Always (sau Phase 1) |
| **2.L2** | `procedures/phase2-l2-api.md` | `$scan_depth != "shallow"` |
| **2.L3** | `procedures/phase2-l3-ui.md` | `$scan_depth != "shallow"` + có UI |
| **2.L4** | `procedures/phase2-l4-db.md` | `$scan_depth != "shallow"` |
| **3** | `procedures/phase3-synthesis.md` | Always (sau Phase 2 POST-GATE) |
| **4** | `procedures/phase4-gap.md` | `$compare_path` không null |
| **5** | `procedures/phase5-output.md` | Always (entry FAIL handler nếu gặp lỗi) |

### Routing Flow

```
SKILL.md entry → Parse $ARGUMENTS
  ├── --status → Read procedures/resume-status.md §CASE A → STOP
  ├── --resume → Read procedures/resume-status.md §CASE B → route to checkpoint.next_action.phase
  └── Fresh run → Read procedures/phase0-setup.md → execute → return
       ↓
Read procedures/phase1-detect.md → execute → return
       ↓
Read procedures/phase2-l1-structure.md → execute (always) → return
       ↓ (scan_depth != shallow)
PARALLEL: Read procedures/phase2-l2-api.md, phase2-l3-ui.md, phase2-l4-db.md
   (Caller bash invocation: dùng run_phase2_parallel helper — xem _shared.md §BUG-002 fix)
       ↓
Read procedures/phase3-synthesis.md → execute → return
       ↓ (compare_path set)
Read procedures/phase4-gap.md → execute → return
       ↓
Read procedures/phase5-output.md → execute (T1-T4 POST-GATE + trace COMPLETE + cleanup lock) → STOP (DONE)
```

> **Mỗi phase file là self-contained** — chứa PRE-GATE, INPUT, OUTPUT, Steps, POST-GATE, Next Phase.
> Phase file tham chiếu `procedures/_shared.md` cho cross-cutting concerns.

---

## Phase Summary (condensed — chi tiết trong procedure files)

> Mỗi phase chi tiết được lazy-load qua procedure files tương ứng. Đây là overview ngắn gọn.

### Phase 0 — Setup

| Step | Action |
|------|--------|
| 0.0 | Resume/Status dispatch — `procedures/resume-status.md` (CHỈ khi `--status`/`--resume`) |
| 0.1 | Parse arguments (`$target`, `$module_name`, `$compare_path`, `$scan_depth`, `$output_dir`, `$NO_CACHE`, **Sprint 7:** `$SCAN_PROFILE`, `$CLI_MAX_PAGES`, `$SINCE_REF`) |
| 0.1b | **Sprint 7** — Argument validation hardening: enum (`--depth`, `--profile`), numeric (`--max-pages` 1-200), conflict detection |
| 0.1c | **Sprint 7** — Resolve profile + apply defaults (Q4 ADAPTIVE 5/25/50/100) → set `$scan_depth` + `$MAX_PAGES` |
| 0.2 | Validate target & detect type (local-source / url / swagger-spec) |
| 0.2b | **Sprint 7** — Validate `--since` (git repo + ref exists + conflict với url/swagger) |
| 0.3 | Tạo SESSION_ID = `{YYYY-MM-DD}-{scope-label}[-{N}]` (Protocol 18.2) |
| 0.3b | CDG-02 — output dir conflict (chỉ khi `--output`) |
| 0.4 | Khởi tạo `scan-status.json` từ template |
| 0.4b | Khởi tạo `checkpoint.json` từ template |
| 0.5b | Trace START event vào `_trace/session-log.json` (Protocol 15) |
| 0.6 | save_checkpoint phase_0 → next phase_1 |

### Phase 1 — Target Analysis

| Step | Action |
|------|--------|
| 1.1 | Tech stack detection — **bash:** `scan-target-detect.sh` (Sprint 4) |
| 1.2 | Resolve module name (input or auto từ target) |
| 1.3 | Scope resolution — tìm sub-module dir nếu `--module` |
| 1.4 | Compute target_fingerprint — **bash:** `scan-target-fingerprint.sh` (Sprint 4 — Q6 composite) |
| 1.4b | **Sprint 7** — Compute changed files (delta scan) — `git diff --name-status A/M/R SINCE_REF..HEAD` → `intermediate/changed-files.json` (chỉ khi `--since` set) |
| 1.5 | **Cache hit lookup (Sprint 6)** — IF `--no-cache` không set AND `--since` không set AND `_shared/cache/{fp}.json` < 24h → reuse, skip Phase 2-4 |

### Phase 2 — Multi-Layer Deep Scan (PARALLEL)

| Step | Action |
|------|--------|
| L1 | File structure + key files — **bash:** `scan-target-inventory.sh` (always). **Sprint 7:** Khi `$DELTA_MODE=true` → filter key_files chỉ giữ paths trong `intermediate/changed-files.json` |
| L2 | API endpoints — **bash:** `scan-target-api.sh` (skip nếu shallow). **Sprint 7:** delta mode → filter endpoints theo `source_file` ∈ changed files |
| L3 | UI screens — **bash:** `scan-target-ui.sh` (local) hoặc AI WebFetch+CDG-07 (URL). **Sprint 7:** URL crawl `URL_MAX_DEPTH=2` hardcoded; CDG-07 trigger khi `estimated_pages > $MAX_PAGES` (theo profile); delta mode → filter screens/components |
| L4 | Entities/DB analysis — **bash:** `scan-target-db.sh` (skip nếu shallow). **Sprint 7:** delta mode → filter entities theo `source_file` ∈ changed files |

### Phase 3 — Synthesis (Sprint 4 Q3 split + Sprint 7 LPM)

| Step | Action |
|------|--------|
| 3.1 | **developer agent** — Build CRUD matrix + extract business rules từ code. **Sprint 7:** profile=exhaustive → MAX 15 validators (vs 5 default). Token ~8K standard / ~11K exhaustive |
| 3.2 | **business-analyst agent** — Compile key_features tiếng Việt. **Sprint 7:** profile=exhaustive → target 20-30 features (vs 10-20) |
| 3.2b | **Sprint 7** — Coverage sanity check (chỉ exhaustive): % entities trong key_features ≥ 80%, warn nếu < 80% |
| 3.3 | Tính completeness estimate dựa trên 4 layer signals |
| 3.4 | save_checkpoint phase_3 → next phase_4 (nếu compare) hoặc phase_5 |

### Phase 4 — Gap Analysis (Conditional)

| Step | Action |
|------|--------|
| 4.1 | Read spec file (`$compare_path`) — JSON / MD / raw |
| 4.2 | Match & classify FOUND/PARTIAL/MISSING. **Sprint 7:** similarity threshold theo profile — 0.6 default / 0.5 exhaustive (relaxed match + fuzzy notes cho similarity 0.5-0.6) |
| 4.3 | save_checkpoint phase_4 → next phase_5 |

### Phase 5 — Output Generation

| Step | Action |
|------|--------|
| 5.1 | Write `module-map.md` từ template |
| 5.2 | Write `target-map.json` từ template (v2 schema — Sprint 5: scan_fingerprint, previous_scans, scan_diff, traceability, module_code_mapping, consumer_hints; **Sprint 7:** thêm `scan_profile`, `delta_scan` field khi `--since` set) + jq validate |
| 5.3 | Write `feature-inventory.md` từ template |
| 5.4 | Write `gap-report.md` từ template (nếu `--compare`) |
| 5.4b | Write `phase-summary.md` tiếng Việt (Protocol 14) |
| 5.5 | Update `scan-status.json` → completed |
| 5.5b | POST-GATE T1-T4 (Existence → Structure → Content → Cross-reference) |
| 5.5c | Trace COMPLETE event vào `_trace/session-log.json` |
| 5.5d | save_checkpoint phase_5 → null + cleanup `.lock` (Sprint 6 — `release_lock` helper) |
| 5.5e | **Sprint 6** — Append `_shared/scans-index.jsonl` (1 entry) — git-sync friendly |
| 5.5f | **Sprint 6** — Append `_shared/history.jsonl` (compact rotation log) |
| 5.5g | **Sprint 6** — Cache write `_shared/cache/{fp}.json` (skip nếu `--no-cache` hoặc cache hit) |
| 5.6 | Hiển thị Output Report cho user |

---

## Fix Rules

| Error Type | Auto-Fix Strategy |
|------------|-------------------|
| `scan-status.json` invalid/empty | Re-run from Phase 0.4 (init from template) |
| `checkpoint.json` corrupted on resume | Fallback dùng scan-status.json để route (resume-status.md CASE B step 4) |
| Tech stack ambiguous | AskUserQuestion CDG nếu detect nhiều stacks conflict |
| Layer agent timeout | Direct tool scan (no agent), log warning |
| POST-GATE T1-T4 fail | Retry x3 → FAIL handler (xem `_shared.md §FAIL Event Handler`) |

---

## Error Handling

> **Canonical table:** xem `procedures/_shared.md §Error Handling Matrix`. Bảng dưới chỉ là quick lookup.

| Code | Tình huống | Hành động |
|------|------------|-----------|
| E001 | `--target` không cung cấp | Hiển thị usage, STOP |
| E002 | Path không tồn tại | ERROR + suggest `ls`, STOP |
| E003 | URL không reachable | WARNING + tiếp tục layers khả dụng |
| E004 | Tech stack không detect được | Generic file tree scan |
| E005 | `--compare` path không tồn tại | WARNING + skip gap analysis |
| E006 | Layer agent timeout | Direct tool scan |
| E007 | File write fail | Retry 3 lần → escalate |
| E008 | Target quá lớn (>10k files) | Limit to `--module` scope, warn |
| E009 | Module không tìm thấy | WARN + scan toàn bộ target |

---

## Next Step

Sau khi hoàn thành Phase 0-5 (full pipeline):

```
→ Đọc kết quả:
    cat {SESSION_DIR}/module-map.md         # Bản đồ toàn diện
    cat {SESSION_DIR}/feature-inventory.md  # Danh sách tính năng
    cat {SESSION_DIR}/phase-summary.md      # Tóm tắt tiếng Việt

→ Optional consumers (target-map.json là input):
    /wf-implement-feature  # context priming khi implement
    /wf-define-features    # Sprint 5 — OPTIONAL --from-scan flag
    /wf-design             # Sprint 5 — gap-analysis baseline
```

> **Standalone skill** — không thuộc main DEVKIT pipeline. Có thể gọi bất kỳ lúc nào.

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `/wf-legacy-scan` | Scan toàn bộ project (không focused) |
| `/wf-implement-feature` | Consumer — đọc `target-map.json` để hiểu context trước khi implement |
| `/wf-add-scope` | OPTIONAL consumer (Sprint 5) — `--from-scan=<session-id>` auto-seed modules + features từ `consumer_hints` + `module_code_mapping` |
| `/wf-define-features` | OPTIONAL consumer (Sprint 5) — `--from-scan=<session-id>` đọc `feature-inventory.md` để suggest features (không auto-import) |
| `/wf-design` | OPTIONAL consumer (Sprint 5) — `--from-scan=<session-id>` dùng làm gap-analysis baseline (legacy design, scan_diff context) |

---

## References

| File | Purpose |
|------|---------|
| `procedures/_shared.md` | State vars, helpers, agent prompts, error handling, FAIL handler, Template Usage Rule |
| `procedures/resume-status.md` | --resume / --status dispatch (Phase 0.0) |
| `procedures/phase0-setup.md` | Phase 0 PRE-GATE + setup (parse args, session init, trace START) |
| `procedures/phase1-detect.md` | Phase 1 tech stack detection + module name + fingerprint |
| `procedures/phase2-l1-structure.md` | Phase 2 Layer 1 — file structure |
| `procedures/phase2-l2-api.md` | Phase 2 Layer 2 — API endpoints |
| `procedures/phase2-l3-ui.md` | Phase 2 Layer 3 — UI screens (CDG-07 cho URL crawl) |
| `procedures/phase2-l4-db.md` | Phase 2 Layer 4 — entities/DB |
| `procedures/phase3-synthesis.md` | Phase 3 — CRUD matrix, business rules, key features, completeness |
| `procedures/phase4-gap.md` | Phase 4 — gap analysis (conditional --compare) |
| `procedures/phase5-output.md` | Phase 5 — output generation + POST-GATE T1-T4 + trace COMPLETE |
| `templates/*` | Output file templates (CORE-031) |
| `procedures/flow-legacy.md.bak` | v1.2 monolithic procedure (backup, deprecated) |
