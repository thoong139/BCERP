# Thiết Kế Lại `wf-legacy-scan` — Adaptive Legacy Intelligence

> **Trạng thái:** Design v2.1 · **Approved & Implemented** (2026-04-22) · Implementation v5.0.0 released · git tag `v5.0.0`
> **Phiên bản:** Design 2.1 · Implementation SKILL.md 5.0.0 · _contract.json 5.0.1
> **Ngày cập nhật:** 2026-04-23 (synced with implementation reality)
> **Người khởi xướng:** Owner MCV3
> **Owner:** DEVKIT core team
> **Thay thế / Bổ sung:** Pipeline hiện tại `wf-legacy-scan v4.1.0` (7 stages, 2 sub-skills, 4 bash scripts, 2,567 dòng)
> **Bám theo pattern:** `wf-fix-bugs v6` (session isolation + 4-level checkpoint + profile system + concurrency controller + scan cache + ISG Python module)
> **North Star:** **Extraction chính xác** — output của scan là foundation cho toàn bộ downstream pipeline. Thà scan chậm + chính xác còn hơn nhanh + sai. Không đánh đổi correctness lấy tốc độ.
> **Giai đoạn kế tiếp:** Implementation đã hoàn tất (v5.0.0). Outstanding: A.3 fixtures, A.4 human sign-off, v5.1 deferred items (Workload Partition Planner, ledger.json deprecation).

---

## 1. Tại Sao Có Tài Liệu Này

Pipeline `wf-legacy-scan` hiện tại (v4.1.0) đã làm tốt phần **deterministic detection + inventory** nhưng gặp 9 giới hạn về **chiều sâu phân tích, operational resilience, và khả năng scale cho dự án lớn**:

1. **Không có depth control** — dự án 50 files và 5,000 files cùng chạy full pipeline.
2. **Orchestrator không truyền context xuống sub-skills** — sub-skills đã dùng specialized agents (`code-reviewer`, `business-analyst`, 7 domain experts) nhưng orchestrator spawn qua `general-purpose` wrapper, không truyền domain hints hay depth config → domain experts không được route đúng theo signal.
3. **State phân tán 3 files** — `ledger.json` + `checkpoint.json` (classify) + `extract-checkpoint.json` → resume routing phức tạp, state inconsistency khi 1 trong 3 corrupt.
4. **Không session isolation** — re-scan ghi đè data cũ, mất audit trail (vi phạm CORE-030).
5. **Bash scripts fragile** — JSON bằng string concatenation, không schema validation, hardcoded `head -N` caps (500/300/200), duplication ~300 dòng với `ui-coverage-scan.sh`.
6. **Không signal intelligence** — không phân tích pre-scan để detect domain, complexity hotspots, hay focus areas cần deep analysis.
7. **Resume chỉ cấp phase** — crash giữa chừng của 1 batch classify / 1 module extract → mất toàn bộ progress của batch/module đó.
8. **Không parallel control** — sub-skill tự quyết parallel, không có global cap, rủi ro OOM hoặc context overflow trên dự án lớn.
9. **Không incremental** — re-scan luôn full, dù chỉ 10 files thay đổi.

Tài liệu này thiết kế lại wf-legacy-scan thành **hệ thống quét thích ứng (adaptive scan)** với 4 profiles, domain-aware agent delegation, unified state management, 4-level checkpoint, concurrency controller, và scan cache — tái dùng các pattern đã chứng minh từ wf-fix-bugs v6.

---

## 2. TL;DR (Đọc trước mọi thứ)

| Hạng mục | Nội dung |
|---------|----------|
| **Góc nhìn mới** | 6 Scan Layers (L1-L6) thay 7 stages tuyến tính. L1-L3 deterministic (bash), L4-L5 intelligent (AI adaptive depth), L6 synthesis (main context). |
| **North Star** ★ | **Extraction chính xác** — output là foundation cho downstream pipeline. Không đánh đổi correctness lấy tốc độ (CORE-023). |
| **4 Profiles** | `surface` (5-10 min, bash-only + heuristic L4 + skip L5) · `standard` (20-40 min, bám v4.1) · `deep` (45-90 min, domain experts enriched) · `exhaustive` (90-180 min, full extraction + divergence + impact graph). |
| **Backward-Compat LOCKED** | `standard` profile **= tương đương v4.1.0 behaviour** — spawn `business-analyst` + 1 domain-expert per module. Không giảm capability. |
| **IPS Python module** ★ v2.1 | `_shared/ips/` tái dùng pattern wf-fix-bugs v6 ISG. 2-phase: A sau L2 (recommend profile + domain), B sau L3 (refine module routing). Unit-testable. |
| **Vietnamese keyword pool** ★ v2.1 | 14 domains × ~8 keywords (qlkh, hoadon, qlns, chamcong, nhapkho, benhnhan, ...). Diacritic normalization + multi-signal boost. |
| **Entry point** | Giữ nguyên `/wf-legacy-scan [path]` + flags mới `--profile`, `--layers`, `--depth`, `--session`, `--incremental`, `--since`, `--no-cache`. Workload partition flags (`--workload`, `--chunk`) defer v5.1. |
| **Domain-Aware Routing** | Orchestrator truyền domain hints + depth config cho sub-skills. Domain expert list **bám v4.1** (finance, procurement, sales, hr, ecommerce, operations, compliance) + mở rộng tuỳ chọn (healthcare, logistics, manufacturing, retail, legal, insurance, education). Confidence threshold ≥0.6 (v2.1 raised từ 0.4). |
| **Unified State** ★ v2.1 | `scan-state.json` canonical. Sub-skills migrate đọc+ghi scan-state trực tiếp (Phase D). ledger.json chỉ generate 1 lần bởi orchestrator tại POST Phase 4 — read-only legacy projection cho downstream. **Zero reverse-sync debt.** |
| **Session Isolation** | `sessions/{id}/` chứa runtime state, plan, summary, log, error-ledger. Output data giữ nguyên location cho backward-compat. File-lock ngăn concurrent session corrupt. |
| **4-Level Checkpoint** | L0 Phase · L1 Layer · L2 Batch/Module · L3 Intra-batch/Intra-module. Mất tối đa 1 unit khi crash. |
| **Concurrency Controller** | 3-tier token bucket — global_max=8, per_layer=3, per_probe=4, reserved_for_synthesis=2. **+ per-agent timeout 300s/600s (v2.1)**. |
| **Scan Cache** | Content-addressable cache theo fingerprint `(probe, file_hash, dep_closure)`. 2-tier: session (ephemeral) + project (git-friendly opt-in). Invalidation rules rõ. |
| **Workload Gate** ★ v2.1 | Dự án lớn (>1,000 files hoặc >30 modules) → Gate WARN + 3 options (continue-as-is / downgrade-profile / abort). **Full Partition Planner + multi-session defer v5.1.** |
| **Impact Graph** | L6 synthesis build `impact-graph.json` (module dependency + data flow) cho downstream `/wf-verify-sync` + `/wf-fix-bugs` R5 ripple verification. |
| **Thresholds Formal** ★ v2.1 | Bảng threshold justification (`09-thresholds-justification.md`) — domain 0.4→0.6, drift tiered 3%/5%, delta 20%→25%, timeout 300s/600s. |
| **CORE-029 Integration** ★ v2.1 | Agent Output Spot-Check tại L4/L5 POST-GATE — random sample 3 files/reqs per batch/module + semantic validation. |
| **Giữ lại** | 7 strategies (S1-S7) routing logic, maturity levels, doc-quality-map, impl-status-snapshot, CORE-021 LEGACY_MODE anchor, tất cả downstream contracts. |
| **Cải thiện** | Bash shared library, jq validation, per-component score clamp, configurable caps, VN + EN domain hint detection, schema-validated output. |
| **Out-of-scope** | Không thay đổi downstream skills (brainstorm, analyze-req, ...). Không thay đổi SSOT `req-registry.json` (NONE role). Không tự phát hành scanner ngoài. Workload partition (v5.1). |

---

## 3. Mục Lục — Đọc Theo Thứ Tự

| # | File | Mục đích | Ai cần đọc |
|---|------|----------|------------|
| 00 | **README.md** (file này) | Nav + TL;DR + ADR quick ref + decision closure | Tất cả |
| 01 | [01-vision-principles.md](01-vision-principles.md) | Vision, 9 vấn đề hiện tại, 11 nguyên tắc thiết kế | Decision-makers, reviewers |
| 02 | [02-scan-layers.md](02-scan-layers.md) | **Core** — 6 Scan Layers, depth levels, probes, exit criteria T1-T4 | Architects, implementers |
| 03 | [03-architecture.md](03-architecture.md) | Kiến trúc adaptive: components, data flow, concurrency, impact graph | Architects, implementers |
| 04 | [04-data-model.md](04-data-model.md) | scan-state.json schema, output schemas, cross-skill contracts, sub-skill migration (v2.1) | Implementers |
| 05 | [05-profiles-ips.md](05-profiles-ips.md) | 4 profiles, IPS Python module 2-phase (v2.1), Workload Gate WARN, incremental | UX reviewers, implementers |
| 06 | [06-bash-scripts.md](06-bash-scripts.md) | Shared library, script improvements, jq validation, code dedup | Implementers, DevOps |
| 07 | [07-migration-plan.md](07-migration-plan.md) | Roadmap 10 phases (v2.1), backward-compat matrix, rollback strategy | PMO, implementers |
| 08 | [08-tradeoffs-adr.md](08-tradeoffs-adr.md) | 17 Architecture Decision Records + resolved questions | Decision-makers |
| **09** | **[09-thresholds-justification.md](09-thresholds-justification.md)** ★ v2.1 | **Threshold justification table — domain 0.6, drift tiered, delta 25%, timeout, CORE-029, synthesis truncation** | **Decision-makers, reviewers** |
| **10** | **[10-vietnamese-keywords.md](10-vietnamese-keywords.md)** ★ v2.1 | **VN keyword pool cho 14 domains, normalization, Phase C implementation checklist** | **Implementers** |

---

## 4. Quick Reference — Khái Niệm Mới

| Khái niệm | Định nghĩa ngắn | Tương ứng pipeline cũ |
|-----------|------------------|-----------------------|
| **Scan Layer (SL/L)** | Trục phân tích độc lập: L1 Discovery · L2 Assessment · L3 Inventory · L4 Classification · L5 Extraction · L6 Synthesis | 7 stages tuyến tính (0, 0A, 0.5, 1, 2, 3, 4) |
| **Depth Level** | `surface` (heuristic, không AI) · `standard` (AI basic) · `deep` (AI + domain expert) — chỉ áp dụng cho L4, L5. L6 dùng `synthesis_mode` riêng. | Không có — luôn chạy full |
| **Profile** | Preset depth cho toàn pipeline: surface/standard/deep/exhaustive | Không có — 1 level duy nhất |
| **synthesis_mode** | L6 depth: `condensed` (surface) · `full` (standard) · `full+insights` (deep) · `full+divergence` (exhaustive) | Không có |
| **IPS** | Intelligent Pre-Scan — 2 phase: (A) sau L2 recommend profile + domain, (B) sau L3 refine complexity hotspots + module routing | Assessment scores only |
| **Domain Hint** | Signal từ code/doc patterns → domain expert recommendation. Confidence 0-1. | Không có — general-purpose agent |
| **Workload Gate** | Phát hiện job lớn (>1,000 files hoặc >30 modules) → gợi ý chia chunks | Không có — user tự đoán |
| **Partition Planner** | Chia modules thành chunks độc lập với dedup_key cho multi-session | Không có |
| **4-Level Checkpoint** | L0 Phase · L1 Layer · L2 Batch/Module · L3 Intra-batch | Resume chỉ cấp phase |
| **Concurrency Controller** | Token bucket 3-tier — cap parallel spawn | Ad-hoc spawn |
| **Scan Cache** | Content-addressable cache theo fingerprint — skip probe đã chạy với input không đổi | Luôn scan lại |
| **Impact Graph** | Module dependency + data flow graph cho ripple verification downstream | Chỉ `dependency-graph.json` thô |
| **scan-state.json** | Unified state machine thay `ledger.json + checkpoint.json + extract-checkpoint.json` | 3 files riêng biệt |
| **Session Isolation** | Runtime state per `sessions/{timestamp-id}/`; output data tại standard location | Flat directory |

---

## 5. 6 Scan Layers (Quick List)

| # | Layer | Tên tiếng Việt | Mục tiêu chính | Phương thức | Depth control? |
|---|-------|-----|----------------|-------------|----|
| **L1** | Discovery | Phát hiện | Tech stack, structure, file metrics, domain hint (preliminary) | Bash (deterministic) | Không — luôn full |
| **L2** | Assessment | Đánh giá | Maturity scoring, complexity, risk, domain hint (enrichment) | Bash (deterministic) | Không — luôn full |
| **L3** | Inventory | Liệt kê | Screens, APIs, source, docs, deps, UI manifest, external docs | Bash (deterministic) | Không — luôn full |
| **L4** | Classification | Phân loại | Module/system grouping, glossary, naming normalization | Adaptive — heuristic / code-reviewer / code-reviewer+domain-expert | ✅ surface/standard/deep |
| **L5** | Extraction | Trích xuất | Requirements, features, acceptance criteria, domain knowledge | Adaptive — skip / business-analyst+domain / business-analyst+domain-expert-enriched | ✅ skip/standard/deep |
| **L6** | Synthesis | Tổng hợp | `project-context.md`, `doc-quality-map`, `impl-status-snapshot`, `impact-graph` | Main context (AI) | `synthesis_mode` (condensed/full/full+insights/full+divergence) |

> Chi tiết đầy đủ (probes, depth behavior, exit criteria per layer) xem [02-scan-layers.md](02-scan-layers.md).

---

## 6. ADR Quick Reference

| ID | Quyết định | Lý do ngắn gọn |
|----|-----------|----------------|
| ADR-LS01 | **6 Scan Layers** thay 7 stages — L1-L3 deterministic, L4-L5 adaptive, L6 synthesis | Tách rõ deterministic vs AI; depth control gọn gàng; dependency chain minh bạch. |
| ADR-LS02 | **4 Profiles** (surface/standard/deep/exhaustive) | Khớp 4 use case: overview nhanh · onboarding chuẩn · dự án phức tạp · audit toàn diện. |
| ADR-LS03 ★ v2.1 | **IPS 2-phase — Python module `_shared/ips/`** (revised từ inline) | Unit-testable; VN + EN keyword pool chung; tái dùng pattern wf-fix-bugs v6 ISG. |
| ADR-LS04 ★ v2.1 | **scan-state.json canonical — sub-skill migration Phase D** (revised — bỏ reverse-sync) | Single source of truth; zero race condition; ledger.json chỉ generate 1 lần bởi orchestrator. |
| ADR-LS05 | **Session isolation (runtime-only)** — output tại standard location | Audit trail; không breaking downstream; file-lock ngăn concurrent corrupt. |
| ADR-LS06 | **Domain-Aware Agent Delegation** — classify `code-reviewer`, extract `business-analyst` + 1 domain expert (bám v4.1) + mở rộng optional | Extraction quality cao; **không giảm** capability so với v4.1. |
| ADR-LS07 | **Bash shared library** `legacy-scan-common.sh` với jq validation, atomic_write_json, Windows-compat | Giảm duplication ~300 dòng; tăng robustness; cross-platform. |
| ADR-LS08 | **Strategy × Profile orthogonal** — 7 strategies × 4 profiles; source-priority formal | Hai trục độc lập, compose được; source-priority (code/doc/balanced) được formalize. |
| ADR-LS09 | **Configurable caps** env vars (`LEGACY_SCAN_MAX_*`) + CLI flag `--max-files` override | Dự án lớn không bị truncate; default safe cho 90% case. |
| ADR-LS10 | **Incremental scan + Scan Cache** (content-addressable) — 2-tier (session + project git-friendly) | 50-80% time savings khi re-scan. |
| ADR-LS11 | **4-Level Checkpoint** — L0 Phase · L1 Layer · L2 Batch/Module · L3 Intra-batch | Mất tối đa 1 unit khi crash. |
| ADR-LS12 ★ v2.1 | **Concurrency Controller 3-tier + per-agent timeout 300s/600s** | Safe spawn parallel; pipeline không hang vì 1 agent. |
| ADR-LS13 ★ v2.1 | **Workload Gate detect+WARN only** (revised — Partition Planner defer v5.1) | Detect + WARN đủ cho v5.0; aggregate merge complexity defer. |
| ADR-LS14 | **Impact Graph** tại L6 — module dependency + data flow cho downstream ripple | Tái dùng pattern wf-fix-bugs R5. |
| **ADR-LS15** ★ v2.1 NEW | **Vietnamese Keyword Pool** (14 domains × ~8 kw) cho IPS domain detection | Cover 70%+ dự án Việt Nam; diacritic normalization; multi-signal boost. |
| **ADR-LS16** ★ v2.1 NEW | **Thresholds Justification Table bắt buộc** — `09-thresholds-justification.md` | Mọi threshold có căn cứ; domain 0.4→0.6; drift tiered; timeout; CORE-029. |
| **ADR-LS17** ★ v2.1 NEW | **Agent Output Spot-Check (CORE-029)** tại L4/L5 POST-GATE | Catch semantic errors trước khi commit SSOT; align DEVKIT rules. |

> Bối cảnh đầy đủ, alternatives đã cân nhắc, consequences xem [08-tradeoffs-adr.md](08-tradeoffs-adr.md).

---

## 7. Success Metrics (Design-level)

| # | Metric | Baseline (v4.1.0) | Target (v5.0) | Cách đo |
|---|--------|-------------------|---------------|---------|
| M1 | **Surface profile time** | N/A (luôn full) | ≤10 min cho 500 files | Wall-clock P50, bash-only path |
| M2 | **Standard profile time** (100-500 files) | 30-90 min | 20-40 min | Wall-clock P50 (giảm nhờ IPS routing + cache hit) |
| M3 | **Deep extraction confidence** | avg ~0.65 (general-purpose wrapper) | avg ≥0.82 | Confidence score trong `extracted/*.json` |
| M4 | **Re-scan time** (20% files changed) | 100% (luôn full) | ≤30% full scan time | Wall-clock compare với cache hit rate |
| M5 | **Session recovery success** | ~60% (fragmented checkpoints) | ≥95% | `--resume` success rate sau crash injection test |
| M6 | **JSON output validity** | ~95% (string concat edge cases) | 100% | jq schema validation pass rate post-write |
| M7 | **Code duplication** (inventory vs ui-coverage) | ~300 dòng identical | 0 dòng | Diff compare sau shared library |
| M8 | **Domain coverage** | 0 (general-purpose) | Auto-detect + route 1-3 domain experts per scan | `domain-hints.json` confidence ≥0.75 for top match |
| M9 | **Large project scale** (3,000+ files) | Context overflow >50% runs | ≤10% overflow + graceful workload partitioning | Crash injection + workload report |
| M10 | **Cache hit rate** (re-scan 2-day delta) | 0% | ≥60% | `cache_hit_count / total_probe_calls` |
| M11 | **Parallel efficiency** (3 modules concurrent) | N/A | ≥0.65× speedup vs sequential | Wall-clock ratio |

---

## 8. Non-Goals — Những Thứ KHÔNG Làm

1. **Không** thay đổi downstream skills (wf-brainstorm, wf-analyze-requirements, ...) — output locations giữ nguyên.
2. **Không** thay đổi SSOT `req-registry.json` hay ownership rules (CORE-004, CORE-006) — wf-legacy-scan = NONE role.
3. **Không** thay đổi LEGACY_MODE detection (CORE-021) — vẫn `project-context.md > 500 bytes`.
4. **Không** thay đổi strategy routing (S1-S7) — strategies quyết định routing, profiles quyết định depth.
5. **Không** breaking change cho user dùng `/wf-legacy-scan /path --resume` — backward-compat matrix §9.
6. **Không** giảm capability so với v4.1 — standard profile **phải** = v4.1 behaviour (business-analyst + 1 domain expert per module).
7. **Không** thêm scanner bên ngoài (Semgrep, CodeQL, ...) — giữ nguyên scope.
8. **Không** tự tạo `req-registry.json` — vẫn do `/wf-design` tạo trong legacy flow.
9. **Không** gộp sub-skills wf-legacy-classify và wf-legacy-extract vào wf-legacy-scan — giữ skill architecture, chỉ improve delegation.
10. **Không** dashboard UI — giữ CLI + markdown reports.

---

## 9. Liên Kết Tham Khảo

| Tài liệu | Lý do tham chiếu |
|----------|-----------------|
| `CLAUDE.md` | Định vị DEVKIT, priority order, workflow skills |
| `.claude/rules/00-core.md` | CORE-004/005/006/007/021/023/024/025/026/027/028/030/031 — ràng buộc design |
| `.claude/skills/workflow/wf-legacy-scan/SKILL.md` | Pipeline v4.1.0 — baseline |
| `.claude/skills/workflow/wf-legacy-classify/SKILL.md` | Sub-skill classify hiện tại — dùng code-reviewer |
| `.claude/skills/workflow/wf-legacy-extract/SKILL.md` | Sub-skill extract hiện tại — dùng business-analyst + 7 domain experts |
| `docs/design/skills/wf-fix-bugs/` | Design pattern reference — ISG, profiles, session isolation, checkpoint, concurrency, impact graph, scan cache |
| `.claude/scripts/legacy-scan-*.sh` | 4 bash scripts hiện tại (2,567 dòng) |
| `.claude/scripts/ui-coverage-scan.sh` | Code duplication target (362 dòng) |
| `.claude/agents/business/` | 25 business agents (domain experts pool) |

---

## 10. Quy Ước Tài Liệu

- Tiếng Việt có dấu cho nội dung; tên file/biến giữ English hoặc tiếng Việt không dấu (CORE-005).
- Mỗi file mở đầu bằng block meta (Trạng thái, Phiên bản, Đọc trước/sau).
- Sơ đồ dùng Mermaid hoặc ASCII.
- Tham chiếu CORE-xxx khi trích dẫn rules; không paste lại nội dung rules.
- Scan Layer viết tắt L1-L6 (ưu tiên) hoặc SL1-SL6 (alias). Profile viết thường.
- depth level: `surface / standard / deep / skip`. synthesis_mode: `condensed / full / full+insights / full+divergence`.

---

## 11. Status & Next Actions

**Trạng thái hiện tại (2026-04-23):** Design v2.1 · **Approved** · Implementation **v5.0.0 COMPLETE** (10 phases A-J hoàn tất, _contract.json v5.0.1).

### Tiến độ Implementation

| Stage | Nội dung | Ước lượng | Status |
|-------|----------|-----------|--------|
| **A** | Design Closure — 17 ADRs, sign-off (OQ đã resolve hết) | 2-3 ngày | ✅ TECH-COMPLETE (6/7, A.3 fixtures deferred) |
| **B** | Foundation — `scan-state.json`, session isolation, bash shared library | 2-3 ngày | ✅ TECH-COMPLETE (51/51 pytest) |
| **C** | Profile System + IPS Python module 2-phase + VN keyword pool | 3-4 ngày | ✅ TECH-COMPLETE (110/110 pytest) |
| **D** | Domain-Aware Agent Delegation + Sub-skill migration (v2.1 add) | 4-5 ngày | ✅ TECH-COMPLETE (8/9, D.9 blocked by A.3) |
| **E** | 4-Level Checkpoint + Concurrency Controller (+ timeout) + Scan Cache | 3-4 ngày | ✅ TECH-COMPLETE (239/239 pytest) |
| **F** | Impact Graph + Incremental mode (v2.1: NO workload partition) | 2 ngày | ✅ TECH-COMPLETE (361/361 pytest) |
| **G** | Bash script refactor (shared library, jq validation, configurable caps) | 2-3 ngày | ✅ TECH-COMPLETE (40/40 smoke, bit-identical v4.1) |
| **H** | Resume Routing 4-level (v2.1: no reverse-sync logic) | 1 ngày | ✅ TECH-COMPLETE (410/410 pytest) |
| **I** | Integration + E2E testing (small/medium/large + VN fixtures) | 3-5 ngày | ✅ TECH-COMPLETE (11/12, I.10 perf blocked by A.3) |
| **J** | Migration + backward-compat verification + docs | 1-2 ngày | ✅ RELEASED (tag `v5.0.0`) |

**Outstanding:** A.3 (fixtures cần populate), A.4 (human sign-off 5 items), v5.1 roadmap (Workload Partition Planner, ledger.json deprecation, Tier 2 E2E).

### Next Actions (post v5.0.0 release)

1. Populate A.3 fixtures (3 real project fixtures + v4.1 baselines) — unblocks D.9, I.10
2. A.4 human sign-off (5 items: agent list, concurrency caps, calibration thresholds, VN keyword accuracy, resource commitment)
3. v5.1 roadmap: Full Workload Partition Planner + multi-session aggregate

### v5.1 Roadmap (Deferred)

- Full Workload Partition Planner + multi-session aggregate (ADR-LS13 revised)
- ledger.json deprecation (sau khi downstream skills migrate)
- Machine learning domain detection + VN BERT embeddings
- ASEAN language support (Thai, Indonesian)

---

## 12. Thay Đổi So Với v2.0 (v2.1 Review Response)

Design v2.1 này xử lý **10 issues** từ review v2.0 (2026-04-22):

**Critical (§3.1, §3.2) đã giải quyết:**
- ✅ **§3.1 Timeline risk cao + độ phức tạp** — Defer Workload Partitioning sang v5.1 (ADR-LS13 revised); Phase F giảm 1 ngày; timeline net neutral.
- ✅ **§3.2 Reverse-sync debt** — Sub-skills migrate đọc+ghi scan-state trực tiếp trong Phase D (ADR-LS04 revised); ledger.json chỉ generate 1 lần bởi orchestrator; zero race condition.

**High (§3.3-3.5, §3.7, §3.10) đã giải quyết:**
- ✅ **§3.3 IPS inline maintainability** — Chuyển sang Python module `_shared/ips/` (ADR-LS03 revised); unit-testable.
- ✅ **§3.4 Session isolation không thực sự isolate output** — Clarified trong ADR-LS05 là "runtime-only"; future `--output-isolated` flag trong v5.1+.
- ✅ **§3.5 Thresholds thiếu căn cứ** — Formal table `09-thresholds-justification.md` (ADR-LS16 NEW); domain 0.4→0.6, drift tiered 3%/5%, delta 20%→25%.
- ✅ **§3.7 CORE-029 Agent Output Spot-Check missing** — Integration tại L4/L5 POST-GATE (ADR-LS17 NEW).
- ✅ **§3.10 Per-agent timeout missing** — Thêm timeout 300s/600s trong ADR-LS12 revised; pipeline không hang vì 1 agent.

**Medium (§3.6, §3.8, §3.9) đã giải quyết:**
- ✅ **§3.6 Domain detection miss dự án Việt Nam** — VN keyword pool 14 domains × ~8 keywords (ADR-LS15 NEW); `10-vietnamese-keywords.md`.
- ✅ **§3.8 Workload aggregate merge semantic chưa rõ** — Defer Partition Planner sang v5.1 (ADR-LS13 revised); v5.0 chỉ Gate+WARN.
- ✅ **§3.9 L6 synthesis truncation** — Priority matrix + truncation strategy trong 09-thresholds §2.9.

**ADR mới trong v2.1:**
- **ADR-LS15** — Vietnamese Keyword Pool cho IPS
- **ADR-LS16** — Thresholds Justification Table bắt buộc
- **ADR-LS17** — Agent Output Spot-Check (CORE-029) integration

**ADR revised trong v2.1:**
- **ADR-LS03** — IPS inline → Python module
- **ADR-LS04** — Reverse-sync → Sub-skill migration Phase D
- **ADR-LS12** — Concurrency cap → + per-agent timeout
- **ADR-LS13** — Full Partition → Gate+WARN only

**Open Questions:**
- ✅ **Tất cả 3 OQ resolved** trong v2.1 (OQ-B, OQ-E, OQ-F locked trong 09/10 + ADR-LS03/LS15).

---

## 13. Thay Đổi So Với v1.0 (v2.0 Review Response — Đã Xử Lý)

Design v2.0 đã xử lý 19 issues từ review v1.0 (xem [08-tradeoffs-adr.md §7](08-tradeoffs-adr.md) cho comparison table v1.0 → v2.0 → v2.1).
