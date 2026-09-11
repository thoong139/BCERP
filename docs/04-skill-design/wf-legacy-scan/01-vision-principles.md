# 01 — Tầm Nhìn & Nguyên Tắc Thiết Kế

> **Đọc trước:** [README.md](README.md)
> **Đọc tiếp:** [02-scan-layers.md](02-scan-layers.md)

---

## 1. Tầm Nhìn (Vision)

`wf-legacy-scan` sau tái thiết kế là **hệ thống quét phân tích thích ứng (adaptive scan)** — hiểu dự án ở mức độ cần thiết, không over-scan hay under-scan, scale được cho dự án lớn (3,000+ files, ERP monorepo).

### 1.1 Yêu cầu từ người dùng phi kỹ thuật

Một Owner dùng `/wf-legacy-scan` trên dự án hiện có cần cảm nhận được 5 điều:

1. **Dễ gọi** — vẫn chỉ một command `/wf-legacy-scan /path`, profile mặc định là `standard`.
2. **Hiểu được dự án ở mức nào** — báo cáo rõ: tech stack, module map, domain, docs status, estimated effort.
3. **Chủ động được độ sâu** — muốn overview nhanh dùng `--profile=surface`; muốn deep analysis dùng `--profile=deep`.
4. **Resume bất cứ lúc nào** — crash giữa chừng → `--resume` tiếp tục chính xác từ điểm dừng (không cần chạy lại batch/module đã xong).
5. **Biết trước độ lâu** — trước khi bắt đầu layer nặng (L4/L5) có Workload Gate ước lượng thời gian + đề xuất chia nhỏ nếu job quá lớn.

### 1.2 Yêu cầu từ engineer triển khai

Một người triển khai DEVKIT cần cảm nhận thêm:

6. **Domain expert tự động match** — hệ thống detect domain (finance, healthcare, ...) → route đúng expert agent dựa trên IPS domain hints.
7. **Re-scan incremental** — đổi 10 files trong 500 files → chỉ re-process 10 files, không scan lại toàn bộ. Cache git-friendly cho team chia việc.
8. **Parallel an toàn** — concurrency controller ngăn context overflow hoặc OOM khi spawn nhiều agents.
9. **Audit trail đầy đủ** — mỗi session giữ scan-state, plan, log, error-ledger riêng để so sánh giữa các lần scan.
10. **Output không break downstream** — sub-skills hiện tại (wf-legacy-classify, wf-legacy-extract) và downstream workflow (brainstorm, analyze-req, ...) không cần sửa.

---

## 2. Problem Statement — 9 Vấn Đề Hiện Tại

| # | Vấn đề | Hệ quả | Bằng chứng |
|---|--------|--------|-----------|
| **PB-1** | Không có depth control — mọi dự án chạy full pipeline | Dự án nhỏ 50 files cũng chạy classify+extract tốn 30-60 min; dự án lớn 5,000 files bị context overflow | Không có profile/flag chọn depth; strategy S1-S7 chỉ route phases, không điều chỉnh depth |
| **PB-2** | Orchestrator không truyền depth/domain context cho sub-skills | Orchestrator spawn `general-purpose` agent wrapper (xem [phase2-classify.md:66](/.claude/skills/workflow/wf-legacy-scan/procedures/phase2-classify.md)). Sub-skills đã dùng specialized agents nội bộ (code-reviewer cho classify, business-analyst + 7 domain experts cho extract) nhưng không nhận pre-scan domain hints hay depth config → domain experts không được route đúng | SKILL.md Phase 2/3 spawn `subagent_type="general-purpose"`; sub-skills tự detect domain không có signal từ IPS |
| **PB-3** | State phân tán 3 files | Resume routing phải check 3 files; state inconsistency khi 1 file corrupt | `ledger.json` (root) + `checkpoint.json` (classify, path `.mc-data/work/legacy-scan/checkpoint.json`) + `extract-checkpoint.json` |
| **PB-4** | Không session isolation | Chạy lại scan mất data cũ; không audit trail; không so sánh được giữa các lần scan; concurrent session corrupt | CORE-030 yêu cầu session isolation; wf-fix-bugs v6 đã implement |
| **PB-5** | Bash scripts xây JSON bằng string concatenation (heredoc) | Edge cases (filenames với special chars, Unicode) có thể tạo JSON invalid; không schema validation | 4 scripts (2,567 dòng) đều dùng `cat > file <<EOF` pattern |
| **PB-6** | Code duplication: `legacy-scan-inventory.sh` và `ui-coverage-scan.sh` chia sẻ ~300 dòng near-identical | Bug fix phải apply 2 nơi; framework support mới phải duplicate | UI screen detection, route extraction, framework version detection |
| **PB-7** | Hardcoded `head -N` caps (500, 300, 200, 100, 20) giới hạn output | Dự án lớn có API/screen counts vượt cap → inventory không đầy đủ → L4/L5 miss modules | `legacy-scan-inventory.sh` — 40 instances của `head -N`, largest caps 500/300/200 |
| **PB-8** | Không có signal intelligence — assessment chỉ dựa trên file counts | Không detect được domain, complexity hotspots, hay focus areas cần deep analysis | `legacy-scan-assess.sh` chỉ đếm files, không phân tích content patterns |
| **PB-9** | Resume chỉ cấp phase — crash giữa L4 batch 5/8 hoặc L5 module 12/20 → mất toàn bộ progress của unit đó | Dự án lớn cần chạy nhiều giờ → rủi ro cao mất công | Checkpoint chỉ ghi sau khi hoàn thành 1 phase, không intra-phase |

### 2.1 Hệ Quả Gộp

- **Về sản phẩm:** user không có lựa chọn "scan nhanh"; mỗi lần scan là commitment lớn thời gian; dự án lớn không chạy nổi 1 phiên.
- **Về kỹ thuật:** extraction quality quyết định toàn bộ downstream pipeline — sub-skills đã có specialized agents nhưng không nhận domain hints từ orchestrator → miss domain-specific requirements.
- **Về vận hành:** resume không tin cậy, re-scan tốn full time, bash output có thể silently invalid, không thể cộng tác team qua git.

---

## 3. Ý Tưởng Cốt Lõi (Key Insight)

> **Scan không phải "chạy hết hay không chạy". Scan là "hiểu dự án ở mức độ phù hợp với nhu cầu, không hy sinh correctness."**

Phân tích dự án chia thành 3 nhóm rõ ràng:

- **Deterministic layers (L1-L3):** Luôn chạy, luôn full depth. Bash scripts enumerates facts — tech stack, file counts, inventory. Không cần AI, không tốn context, không cần depth control.

- **Intelligent layers (L4-L5):** Cần AI, cần domain expertise, tốn context. Đây là nơi depth control, domain routing, và adaptive behavior áp dụng.

- **Synthesis layer (L6):** Tổng hợp output từ L1-L5 thành context cho downstream skills + impact graph cho verify-sync. Chạy trong main context, luôn chạy, chỉ khác nội dung theo `synthesis_mode`.

### 3.1 So Sánh Ngắn

| Khía cạnh | Pipeline hiện tại (v4.1) | Thiết kế mới (v5.0 adaptive) |
|-----------|--------------------------|-------------------------------|
| Trục chính | 7 stages tuyến tính | 6 Scan Layers với depth control |
| Depth | 1 level (full) | 3 levels per intelligent layer + synthesis_mode |
| Profile | Không có | 4 profiles (surface/standard/deep/exhaustive) |
| Agent delegation | Orchestrator dùng `general-purpose` wrapper | Orchestrator truyền depth + domain context cho sub-skills |
| State management | 3 files riêng biệt | `scan-state.json` canonical + ledger.json generated |
| Session | Flat directory | `sessions/{id}/` isolation với file-lock |
| Checkpoint | Cấp phase | 4-level (phase/layer/batch/intra-batch) |
| Concurrency | Ad-hoc | 3-tier token bucket |
| Re-scan | Luôn full | Incremental + content-addressable scan cache |
| Dự án lớn | Context overflow | Workload Gate + Partition Planner + multi-session |
| Bash output | String concat, no validation | jq validation, shared library, atomic write |
| Impact analysis | `dependency-graph.json` thô | `impact-graph.json` enriched (data flow + module deps) |

---

## 4. 11 Nguyên Tắc Thiết Kế (Design Principles)

### P1 — Extraction Correctness Over Speed · CORE-023

Output của wf-legacy-scan là **foundation cho toàn bộ downstream pipeline**. Sai ở đây lan truyền qua brainstorm → analyze-requirements → define-features → design → implement.

**Ràng buộc:**
- Profile `surface` được phép skip extraction (L5) nhưng **không được** tạo extraction sai. Thà không extract còn hơn extract sai.
- Profile `deep` phải tận dụng domain experts để đạt confidence ≥0.8.
- Standard profile **không giảm** capability so với v4.1 — luôn spawn business-analyst + 1 domain expert per module.

### P2 — Deterministic Before AI

L1-L3 (Discovery, Assessment, Inventory) luôn chạy deterministic bash scripts. Đây là foundation facts — không cần AI, không cần depth control, luôn chính xác. Chỉ L4-L5 mới cần AI và depth control.

**Nguyên tắc:** Nếu bash làm được, không dùng AI.

### P3 — Domain-Aware, Not Domain-Dependent

Hệ thống auto-detect domain hints từ code patterns, `package.json` dependencies, directory naming, import patterns. Domain hints được dùng để:
- Recommend domain expert agents cho extraction
- Adjust glossary generation focus
- Prioritize module analysis

Nhưng **không block** nếu không detect được domain. Fallback: `business-analyst` general-purpose.

**Domain expert list (ADR-LS06):**
- **Core 7 (v4.1 bám cứng):** finance, procurement, sales, hr, ecommerce, operations, compliance
- **Optional (v5.0 mở rộng khi IPS detect):** healthcare, logistics, manufacturing, retail, legal, insurance, education

### P4 — Profile-Driven, User-Controllable · ADR-LS02

Profile là preset depth cho toàn pipeline. User chọn profile (`--profile=surface`) hoặc override từng layer (`--layers=L4,L5 --depth=deep`).

**Ràng buộc:**
- `--profile` sets default depth per layer
- `--depth` override cho layers được chọn
- Surface profile không skip L1-L3 (deterministic phases luôn chạy)
- Deep/exhaustive profiles không skip L4-L5
- Standard profile **khoá** = v4.1 behaviour (backward-compat guarantee)

### P5 — Single State, Unified Recovery · ADR-LS04

`scan-state.json` canonical + `ledger.json` generated cho backward-compat. Reverse-sync contract explicit:
- Sub-skills write to ledger.json (legacy API) → scan-state watcher re-sync
- scan-state.json là write-once-per-transition; ledger.json có thể overwrite

**State transitions:** `not_started` → `in_progress` → `completed` | `failed` | `skipped_by_profile`

### P6 — Session Isolation · CORE-030

Mỗi scan run tạo `sessions/{timestamp-id}/`. Runtime state (scan-state, plan, digest, phase-summary, log, error-ledger) lưu trong session. Output data (inventory, classified, extracted) tại standard location cho backward-compat.

**File-lock:** Session khởi tạo acquire `.mc-data/work/legacy-scan/.session.lock` — ngăn 2 scan chạy concurrent trên cùng project corrupt state.

### P7 — 4-Level Checkpoint · ADR-LS11

| Cấp | Đối tượng | File | Granularity |
|-----|-----------|------|-------------|
| **L0 Phase** | Detection/Assessment/Inventory/Classification/Extraction/Synthesis | `scan-state.json` | Resume vào đúng layer |
| **L1 Layer** | Per-layer progress | `layers.<L>.status` trong scan-state | Resume vào layer đang dở |
| **L2 Batch/Module** | L4 batch N / L5 module M | `layers.<L>.batch_progress` | Resume vào batch/module chưa xong |
| **L3 Intra-batch** | Files trong batch / features trong module | `layers.<L>.partial.json` | Resume vào file/feature kế tiếp |

**"Never lose more than 1 unit"** — checkpoint ghi sau mỗi file/feature/batch complete. Crash → mất tối đa 1 unit (vài giây công việc).

### P8 — Concurrency Safety · ADR-LS12 · CORE-025

3-tier token bucket:
- `global_max = 8` (hard cap)
- `per_layer_max = 3` (mỗi layer tối đa 3 parallel agent)
- `per_probe_max = 4` (mỗi probe fanout tối đa 4)
- `reserved_for_synthesis = 2`

**Điều kiện parallel (CORE-025):** write scope tách biệt, contract stable, POST-GATE verify sau merge.

### P9 — Incremental + Cache · ADR-LS10

Re-scan trên cùng dự án chỉ re-process files thay đổi. Scan cache content-addressable:
- Fingerprint = `SHA256(probe_id || probe_version || input_hash || dep_closure_hash)`
- 2-tier: session cache (ephemeral, gitignore) + project cache (opt-in commit git)
- Invalidation: file hash đổi / dep closure đổi / probe version bump / TTL 14 ngày / `--no-cache`

Baseline: <20% files thay đổi → re-scan time ≤30% full scan time.

### P10 — Bash Robustness · ADR-LS07

Bash scripts dùng shared library `legacy-scan-common.sh` cho common functions. Mỗi JSON output validate bằng `jq` sau write. Hardcoded caps thay bằng configurable env vars.

**Cross-platform:** `BASH_SOURCE[0]` resolution + `normalize_path()` handle Windows Git Bash + WSL + Linux + macOS.

**Nguyên tắc:** Nếu jq available, dùng jq. Nếu không, fallback but warn.

### P11 — Backward Compatibility · CORE-024

- Entry point `/wf-legacy-scan` giữ nguyên
- Flags cũ (`--resume`, `--status`, `--re-vision`, `--batch-size`) vẫn hoạt động
- Output file locations không đổi (`.mc-data/work/legacy-scan/...`)
- `project-context.md` vẫn là LEGACY_MODE anchor (CORE-021), không đổi format
- `--profile` default = `standard` (tương đương hành vi v4.1)
- **Standard profile = v4.1 behaviour** — business-analyst + 1 domain expert per module (không giảm capability)
- Ledger.json vẫn được generate để sub-skills không cần sửa ngay

---

## 5. Bindings Với CORE Rules

| CORE | Ảnh hưởng tới thiết kế |
|------|------------------------|
| CORE-004 | `req-registry.json` không bị ghi bởi wf-legacy-scan (NONE role). Scan chỉ đọc registry nếu tồn tại. |
| CORE-005 | Docs tiếng Việt, tên file/biến English hoặc VN không dấu. |
| CORE-006 | Safe-Write: wf-legacy-scan = NONE trên registry; chỉ produce inventory/classify/extract data. |
| CORE-007 | Cross-skill output path contract giữ nguyên; thêm `sessions/` sub-path + `scan-state.json` + `impact-graph.json`. |
| CORE-021 | LEGACY_MODE detection không đổi — vẫn check `project-context.md > 500 bytes`. |
| CORE-023 | Priority: extraction correctness > tốc độ. Profile surface skip extraction thay vì làm extraction hời. |
| CORE-024 | Output phải có căn cứ: extracted requirements phải có `source_files` + `confidence`. Downstream không suy diễn ngoài scope. |
| CORE-025 | Parallel agent delegation với concurrency controller 3-tier; write scope tách biệt; POST-GATE verify. |
| CORE-026 | Execution Trace: mọi scan run ghi START/COMPLETE/FAIL vào `session-log.json` (output-only observability). |
| CORE-027 | Critical Decision Gate: Workload Gate + user decision tại profile shift + scan cache invalidate → cần user confirmation. |
| CORE-028 | Phase Summary: mọi skill tạo `phase-summary.md` sau POST-GATE, tiếng Việt cho non-specialist. |
| CORE-030 | Session isolation: `sessions/{id}/` cho mỗi scan run + file-lock concurrent protection. |
| CORE-031 | Template usage: mọi output file tạo từ template, validate sau write. |

---

## 6. Những Gì Đã Cố Ý Không Đưa Vào Nguyên Tắc

- **Chọn domain expert cụ thể** — để IPS routing quyết định dựa trên detected signals.
- **Timeout per phase** — mục tiêu vận hành, thuộc [05-profiles-ips.md](05-profiles-ips.md).
- **UI dashboard** — Non-Goal (xem README §8).
- **Integration với CI/CD** — Non-Goal trong scope này.
- **Migration strategy** — Chi tiết trong [07-migration-plan.md](07-migration-plan.md).

---

## 7. Open Design Questions (3 còn lại — đã resolve 2 questions)

**Đã resolve** (move sang ADRs):
- ~~OQ-A: L4 surface chạy hay skip?~~ → Chạy L4 surface (heuristic grouping) — xem [ADR-LS01](08-tradeoffs-adr.md).
- ~~OQ-C: Session isolation scope?~~ → Runtime-only — [ADR-LS05](08-tradeoffs-adr.md).
- ~~OQ-D: Sub-skill refactor?~~ → Keep as-is — [ADR-LS06](08-tradeoffs-adr.md).

**Còn lại (cần user/team input):**

- **OQ-B**: Domain hints detect nên chạy trong bash (L1/L2) hay trong IPS (sau L2)?
  - Recommendation: trong bash L2 (đã scan files sẵn).
- **OQ-E**: Có thêm L0 Pre-Scan Validation (project path, permissions, git status)?
  - Recommendation: giữ trong Phase 0 init (fail-fast inline).
- **OQ-F**: Scan cache project-level có default opt-in hay opt-out?
  - Recommendation: opt-in (user chạy `--cache-publish` mới commit git). Lý do: không phải team nào cũng muốn share cache.

---

## 8. Checklist Trước Khi Chuyển Sang Scan Layers

Trước khi đọc [02-scan-layers.md](02-scan-layers.md), reviewer xác nhận:

- [ ] Hiểu trục chính là Scan Layer với depth control, không phải phase tuyến tính.
- [ ] Đồng ý 11 nguyên tắc P1-P11 là ràng buộc cứng.
- [ ] Không yêu cầu thay đổi CORE rules hiện hành.
- [ ] Chấp nhận backward-compat là điều kiện tiên quyết — standard profile = v4.1 behaviour.
- [ ] Chấp nhận extraction correctness là North Star, không phải scan speed.
- [ ] Đã xem qua "Non-Goals" trong README §8.
- [ ] Hiểu 9 vấn đề hiện tại (PB-1 đến PB-9) và tại sao thiết kế này giải quyết từng vấn đề.

Nếu có mục nào chưa đồng ý → ghi issue trước khi đọc tiếp.
