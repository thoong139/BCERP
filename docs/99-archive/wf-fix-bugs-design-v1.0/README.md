# Thiết Kế Lại `wf-fix-bugs` — Góc Nhìn Chiều Chất Lượng (Quality Dimensions)

> **Trạng thái:** Design v1.0 · **Approved** (2026-04-20) · git tag `design-v1.0-approved` · Implementation **v6.1.0 COMPLETE**
> **Phiên bản:** Design 1.0 · Implementation SKILL.md 6.1.0 · _contract.json 6.1.1
> **Ngày tạo:** 2026-04-20
> **Ngày sign-off:** 2026-04-20 — Owner Eureka (ERK Transport)
> **Người khởi xướng:** Eureka (IT — ERK Transport)
> **Owner:** DEVKIT core team
> **Thay thế / Bổ sung:** Pipeline hiện tại `wf-fix-bugs v5.1.0` (pure orchestrator 3 sub-skills) + tái sử dụng ý tưởng tốt từ `plans/coverage-expansion/`.
> **North Star:** Ưu tiên logic + nghiệp vụ + UI (QD1+QD2+QD5). Các chiều khác giải tốt nhưng không làm cồng kềnh. Xem [09-design-decisions.md](09-design-decisions.md).
> **Giai đoạn kế tiếp:** Implementation đã hoàn tất (v6.1.0). Không còn next actions.

---

## 1. Tại Sao Có Tài Liệu Này

Pipeline hiện tại của `wf-fix-bugs` (`Discover → Triage → Execute`) đã làm tốt phần **điều phối quy trình** nhưng đang gặp các giới hạn về **cách phân tích bug**:

1. Mỗi phase trộn lẫn mọi loại bug (UI, API, security, performance, ...) vào chung `issue-registry.json`, khiến việc mở rộng coverage phải nhồi thêm layer/logic vào bên trong `wf-fix-discover` (5-Layer hiện tại).
2. Plan mở rộng `plans/coverage-expansion/` cố khắc phục bằng cách thêm 8 scanner mới, nhưng vẫn giữ trục phase → khiến skill `wf-fix-discover` phình to về cả trách nhiệm lẫn file.
3. Khi user hỏi "tại sao bug này lọt?", không có cách trả lời theo **chiều chất lượng** (correctness, security, performance, ...) mà chỉ trả lời theo phase.
4. Việc tuỳ biến độ sâu (`--deep`, `--full-test`, `--responsive`) bị ghép với phase, khó cho phép user yêu cầu "tôi chỉ cần kiểm tra security + accessibility" mà bỏ qua các phần khác.

Tài liệu này đặt lại vấn đề theo **Quality Dimensions**: coi mỗi bug là một vi phạm một chiều chất lượng cụ thể; mỗi chiều có pipeline phân tích riêng (Sense → Think → Act → Verify) và có thể chạy độc lập hoặc song song với các chiều khác. Orchestrator compose các chiều thành một session theo profile người dùng chọn.

---

## 2. TL;DR (Đọc trước mọi thứ)

| Hạng mục | Nội dung |
|---------|---------|
| **Góc nhìn mới** | 7 chiều chất lượng (Quality Dimensions) — QD1…QD7 — thay cho trục phase đơn thuần. |
| **North Star** ★ | Ưu tiên đảm bảo **không có lỗi logic, nghiệp vụ, UI** (QD1+QD2+QD5) — chi phối mọi default, heuristic và safety defaults. Xem [09-design-decisions.md §1](09-design-decisions.md). |
| **Default profile LOCKED** | `quick = [QD1, QD5]` · `standard = [QD1, QD2, QD5]` · `deep = [QD1, QD2, QD5, QD6, QD3]` · `exhaustive = QD1-7`. ADR-21. |
| **Entry point** | Giữ nguyên `/wf-fix-bugs` + flags mới `--dims=<list>`, `--only`, `--skip`, `--profile=<preset>` (backward-compat với `--deep`, `--full-test`, `--responsive`). |
| **Phạm vi do user kiểm soát** | **First-class:** user có thể chọn **một hoặc nhiều** QD để skill làm việc. Toàn bộ pipeline (lanes, Signal Bus, Triage, Fixer, Verifier, Report) **chỉ xử lý trong phạm vi QD đã chọn** — không có "drift" ngoài scope. **Safety floor:** profile ≥ `standard` không được bỏ toàn bộ QD1+QD2+QD5. Chi tiết [05 §3.0](05-execution-profiles.md) + [09 §8](09-design-decisions.md). |
| **Thành phần mới** | Dimension Lane (một lane per dimension), Signal Bus (normalise findings), Shared Triage/Planner/Fixer/Verifier. |
| **Giữ lại** | Orchestrator pattern, `SESSION_DIR` layout, `issue-registry.json` như SSOT bug-level, Safe-Write Protocol CORE-006, Path Contract CORE-007. |
| **Rút gọn** | Bỏ 5-Layer bên trong `wf-fix-discover`; thay bằng các **Probe** thuộc từng Dimension Lane. |
| **Mở rộng** | Plugin model: thêm chiều mới = thêm lane + probe + rules, không cần đụng orchestrator. |
| **Migration** | Không breaking change cho user; skill cũ được wrap dần (xem [06-migration-plan.md](06-migration-plan.md)). |
| **Out-of-scope** | Không thay đổi `req-registry.json` ownership, không đổi workflow upstream (brainstorm/analyze/design/...). |

---

## 3. Mục Lục — Đọc Theo Thứ Tự

| # | File | Mục đích | Ai cần đọc |
|---|------|----------|------------|
| 00 | **README.md** (file này) | Nav + TL;DR + ADR quick ref | Tất cả |
| 01 | [01-vision-principles.md](01-vision-principles.md) | Vision, problem statement chi tiết, 11 nguyên tắc thiết kế (gồm P11 User-Controlled Scope) | Decision-makers, reviewers |
| 02 | [02-quality-dimensions.md](02-quality-dimensions.md) | **Core** — định nghĩa 7 chiều chất lượng + probes + exit criteria | Architects, implementers, QA |
| 03 | [03-architecture.md](03-architecture.md) | Kiến trúc dimension-based: components, data flow, sequence | Architects, implementers |
| 04 | [04-contracts-data-model.md](04-contracts-data-model.md) | Signal schema, Issue schema, SESSION_DIR layout, contracts CORE-007 | Implementers |
| 05 | [05-execution-profiles.md](05-execution-profiles.md) | Profiles × dimensions × scope, multi-session ERP | UX reviewers, SRE |
| 06 | [06-migration-plan.md](06-migration-plan.md) | Roadmap migrate từ pipeline hiện tại, backward-compat, timeline | PMO, implementers |
| 07 | [07-tradeoffs-adr.md](07-tradeoffs-adr.md) | Architecture Decision Records + open questions | Decision-makers |
| 08 | [08-user-scenarios-solutions.md](08-user-scenarios-solutions.md) | **Operational design** — 6 yêu cầu thực tế + 7 scenario bổ sung: ISG, Workload Gate, 4-level checkpoint, Concurrency Controller, Impact Graph, Scan Cache, Incremental mode + roadmap 14 tuần | Owner, PMO, implementers |
| 09 | [09-design-decisions.md](09-design-decisions.md) ★ | **Design decisions đã khoá (v1.0)** — North Star, Q14-Q23 answered, default profile shift (QD1+QD2+QD5), safety defaults non-negotiable | Decision-makers, implementers |

> Mỗi file độc lập nhưng có cross-link. Người mới nên đọc tuần tự 01 → 09. Người đã quen DEVKIT có thể skip thẳng tới 02 hoặc 03. File 08 là **operational extension**, file 09 là **decision closure** — đọc 09 trước khi implement để hiểu rõ các ràng buộc đã khoá.

---

## 4. Quick Reference — Khái Niệm Mới

| Khái niệm | Định nghĩa ngắn | Tương ứng pipeline cũ |
|-----------|------------------|-----------------------|
| **Quality Dimension (QD)** | Trục chất lượng độc lập (correctness, security, performance, ...) | (không có — mọi bug trộn chung) |
| **Dimension Lane** | Đường xử lý per-dimension: Sense → Think → Act → Verify | Một phần của `wf-fix-discover` + `wf-fix-triage` + `wf-fix-execute` |
| **Probe** | Đơn vị phát hiện nhỏ nhất (static rule, runtime check, LLM review, tool bên ngoài) | "Layer" trong 5-Layer của `wf-fix-discover` |
| **Signal** | Finding thô từ một probe, chưa dedup, chưa gán severity cuối | Entry raw trong `issue-registry.json` (pre-triage) |
| **Issue** | Bug sau khi dedup + tagged với 1-N Quality Dimension + severity | Entry trong `issue-registry.json` (post-triage) |
| **Signal Bus** | Thành phần nhận tất cả Signal từ các lane, dedup + normalize → emit Issue | Logic rải rác trong `wf-fix-discover` Layer 4 |
| **Profile** | Preset depth/scope cho một run (quick/standard/deep/exhaustive) | Các flag `--deep`, `--full-test`, `--responsive` |
| **Dimension Selection** | **First-class capability** — user chọn subset QD (`--dims=QD3,QD5` hoặc `--only=security`). Toàn pipeline enforce scope. Xem [05 §3.0](05-execution-profiles.md). | (không có — phải chạy toàn bộ pipeline) |
| **Interactive Selection Gate (ISG)** | Khi không có flag dim, orchestrator mở bảng tick QD + recommend dựa trên git diff/preflight/domain. Xem [08 §3](08-user-scenarios-solutions.md) | Flag CLI rời rạc |
| **Workload Gate + Partition Planner** | Phát hiện job lớn (ERP module, 20-30 menu), đề xuất chia chunk + cho phép multi-session parallel. Xem [08 §4](08-user-scenarios-solutions.md) | User phải tự đoán |
| **4-Level Checkpoint** | Resume bất cứ lúc nào ở 4 cấp (phase/lane/probe/intra-probe); mất tối đa 1 feature khi crash. Xem [08 §5](08-user-scenarios-solutions.md) | Resume chỉ ở cấp phase |
| **Concurrency Controller** | 3-tier token bucket (inter-lane/intra-lane/intra-probe), global cap 12. Xem [08 §6](08-user-scenarios-solutions.md) | Ad-hoc spawn |
| **Impact Graph + Verification Ripple** | Cross-module impact analysis — sửa F → verify neighbors theo graph. Xem [08 §7](08-user-scenarios-solutions.md) | Verify chỉ trong scope |
| **Scan Cache (content-addressable) + Incremental** | Cache probe result theo fingerprint; git-friendly để 2 dev chia sẻ qua git; `--since=<git-ref>` scan diff-only. Xem [08 §8](08-user-scenarios-solutions.md) ★ | Luôn scan lại từ đầu |

---

## 5. 7 Quality Dimensions (Quick List)

| # | Dimension | Tiếng Việt | Mục tiêu chính |
|---|-----------|------------|----------------|
| **QD1** | Functional Correctness | Đúng chức năng | Feature hoạt động đúng spec đã viết trong `phase2-features/` và `req-registry.json` |
| **QD2** | Business Correctness | Đúng nghiệp vụ | Business logic khớp domain rules (cần domain expert agent) |
| **QD3** | Security & Privacy | An toàn & Riêng tư | Auth, authz, injection, secrets, data leakage (OWASP Top 10) |
| **QD4** | Performance & Efficiency | Hiệu năng | CWV, query perf, memory, bundle size, rendering |
| **QD5** | Accessibility & UX | Khả dụng & Trải nghiệm | WCAG 2.2 AA + UX heuristics (Nielsen) + content quality |
| **QD6** | Data Integrity & Resilience | Toàn vẹn dữ liệu & Chịu lỗi | Validation, constraints, edge case, concurrency, idempotency |
| **QD7** | Compatibility & Portability | Tương thích | Cross-browser, responsive, i18n, env parity |

> Chi tiết đầy đủ (probes, exit criteria, severity default, map sang 12 bug categories cũ) xem [02-quality-dimensions.md](02-quality-dimensions.md).

---

## 6. ADR Quick Reference

| ID | Quyết định | Lý do ngắn gọn |
|----|-----------|----------------|
| ADR-01 | **Dimension là primary axis** thay vì Layer (7 QD thay 5-Layer + 12 category phẳng) | Orthogonal semantic + exit criteria đo được; cho phép chạy 1 dim độc lập. |
| ADR-02 | **Signal Bus là utility module**, không phải skill (`_shared/signal_bus/`) | Luôn chạy inline sau lane; không cần user-facing command; ít boilerplate. |
| ADR-03 | **Shared Services 4 thành phần** (Triage/Planner/Fixer/Verifier) thay cho `/wf-fix-execute` monolith | Mỗi service ≤200 dòng, dễ debug; retry policy tập trung; safety gate rõ scope. |
| ADR-04 | **Issue schema v2 extend** v1 (không breaking) — field mới optional | User không gián đoạn; migration helper chuyển v1 → v2; carry field tạm đến Phase 6. |
| ADR-05 | **Max 3 lane song song** mặc định; override `--max-parallel-lanes=N` | Agent concurrency limit + browser instance OOM + debug log readability. |
| ADR-06 | **Skill name convention** `wf-fix-<slug>` (functional/business/security/...) | User gõ tự nhiên `--only=security`; giữ QD1-7 trong schema cho sort. |
| ADR-07 | **Registry role NONE** cho tất cả lane; chỉ Fixer SAFE-UPDATE `impl_status` | Không drift SSOT; không race condition; audit đơn giản. |
| ADR-08 | **4 profiles** (quick/standard/deep/exhaustive) — không 3, không 5 | Khớp 4 moment trong dev lifecycle; budget predictable. |
| ADR-09 | **Evidence bắt buộc** cho mọi Signal (≥1 non-empty field) | Verifier re-run deterministic; user trust cao khi có "proof". |
| ADR-10 | **CORE-028 phase-summary hai cấp** — lane technical + orchestrator human | User đọc 1 file ở root; debugger đọc đủ 8 file. |
| ADR-11 | **LEGACY_MODE không đổi** profile/dim selection, chỉ đổi probe behavior | User prediction: flag họ gõ = kết quả họ nhận. |
| ADR-12 | **`--explain`** là first-class UX feature (preview plan không chạy) | Giảm surprise budget blow với profile nặng. |
| ADR-13 | **`--auto`** opt-in, không default | Default predictable; power user có option khi cần. |
| ADR-14…20 | **Operational ADRs** (ISG, Workload Gate, 4-level checkpoint, Concurrency, Impact Graph, Scan Cache, Incremental) | Đã đề xuất trong [08 §10](08-user-scenarios-solutions.md), pending viết vào 07. |
| ADR-21 ★ | **Default profile shift** — `standard = [QD1, QD2, QD5]` thay vì `[QD1, QD3, QD5]` | Ưu tiên North Star (logic + nghiệp vụ + UI). Chi tiết [09 §4](09-design-decisions.md). |
| ADR-22 ★ | **Safety Defaults non-negotiable** — 6 rules: profile ≥ standard không bỏ QD1+QD2+QD5; Ripple always on; QD3 no-cache; CDG secrets; POST-GATE T1-T4; SAFE-UPDATE impl_status | Bảo vệ correctness trong mọi tổ hợp flag. [09 §8](09-design-decisions.md). |
| ADR-23 | **Partition Planner: ISG-guided vs priority-based** — ưu tiên ISG recommendation, fallback priority-based (QD1+QD2+QD5 trước) | ISG-aware partition cho kết quả tốt; default fallback đảm bảo always-working. [07 §23](07-tradeoffs-adr.md). |
| ADR-24 | **AggregationStats v2 schema** — thêm 6 dimension-level coverage fields | Pre-computed coverage metrics cho report generation. [07 §24](07-tradeoffs-adr.md). |

> Bối cảnh đầy đủ, alternatives đã cân nhắc, consequences + open questions xem [07-tradeoffs-adr.md](07-tradeoffs-adr.md) (ADR-14 → ADR-22 sẽ được viết trong Giai đoạn A).

---

## 7. Success Metrics (Design-level)

Metrics dưới đây đo **thành công của thiết kế mới** (sau khi implement + rollout):

| # | Metric | Baseline (v5.1.0) | Target (v6.0 dimension-based) | Cách đo |
|---|--------|-------------------|-------------------------------|---------|
| M1 | **Detect rate weighted** trên golden suite | 0.60 | ≥0.90 | Inject 50+ bug đã biết theo 7 dimensions, đo % bắt được × weight |
| M2 | **Dimension coverage transparency** | Không có | 100% issue có `dimension` field + `probe_source` | Schema validation POST-GATE |
| M3 | **Time to first critical (quick profile)** | 5–15 min | <10 min | P50 từ start → first CRITICAL issue emit |
| M4 | **Runtime standard profile (20–50 features)** | 30–60 min | 45–90 min | P50 wall-clock |
| M5 | **False positive rate** | <10% | <15% (chấp nhận tăng vì coverage rộng) | Manual review 50 issue ngẫu nhiên/release |
| M6 | **Lane parallel efficiency** (lane song song vs tuần tự) | N/A | ≥0.7× speedup khi chạy 3 lane ss | Runtime ss / Runtime seq |
| M7 | **Plugin-ability** (thêm dimension mới) | Khó đo | <2 người-ngày để thêm 1 dimension stub | Spike: thêm `wf-fix-observability` |
| M8 | **User understandability** | N/A | >80% user non-technical đọc phase-summary hiểu dimension nào fail | User test N=10 |

> Metrics vận hành (token cost, resume success, ...) nằm trong [05-execution-profiles.md](05-execution-profiles.md).

---

## 8. Non-Goals — Những Thứ KHÔNG Làm

1. **Không** thay đổi workflow upstream (`/wf-brainstorm` → `/wf-plan-modules`) — wf-fix-bugs là downstream.
2. **Không** thay đổi SSOT `req-registry.json` hay ownership (CORE-004, CORE-006).
3. **Không** tự phát hành tool scanner bên ngoài (Semgrep, Lighthouse, k6, axe-core) — giữ nguyên opt-in như plan cũ.
4. **Không** làm dashboard UI riêng — giữ CLI + markdown reports như hiện tại.
5. **Không** breaking change cho user đang dùng `/wf-fix-bugs --deep --full-test --responsive` — các flag này vẫn map vào profile mới.
6. **Không** tự fix security/performance issues trong phase đầu — shared Fixer chỉ auto-fix các issue có confidence cao + low-risk. Các issue còn lại ESCALATE.
7. **Không** mở rộng CI/CD integration trong scope này — để phase sau.

---

## 9. Liên Kết Tham Khảo

| Tài liệu | Lý do tham chiếu |
|----------|------------------|
| `CLAUDE.md` | Định vị DEVKIT, priority order |
| `.claude/rules/00-core.md` | CORE-004/006/007/023/024/025 — ràng buộc design phải bám |
| `.claude/skills/workflow/wf-fix-bugs/SKILL.md` | Pipeline hiện tại — baseline để so sánh |
| `.claude/skills/workflow/wf-fix-discover/SKILL.md` | ~~5-Layer hiện tại — đã xoá Phase 6~~ (giữ link cho tham chiếu lịch sử) |
| `.claude/skills/protocols/` | 19 protocols shared — cần map dimension lane sang protocols nào |
| `plans/coverage-expansion/01-strategy.md` | 12 bug categories — nguồn input cho mapping QD × category |
| `plans/coverage-expansion/02-architecture.md` | Multi-scanner design — nguồn cho lane concept |
| `plans/coverage-expansion/08-erp-module-strategy.md` | Multi-session ERP — cần tái sử dụng trong [05-execution-profiles.md](05-execution-profiles.md) |

---

## 10. Quy Ước Tài Liệu

- Tiếng Việt có dấu cho nội dung; tên file/biến giữ English hoặc tiếng Việt không dấu (CORE-005).
- Mỗi file mở đầu bằng block meta (Trạng thái, Phiên bản, Đọc trước/sau).
- Sơ đồ dùng Mermaid hoặc ASCII; tránh hình ảnh nhị phân để diff dễ review.
- Thuật ngữ mới viết hoa chữ đầu khi lần đầu xuất hiện (Quality Dimension, Signal, Probe, ...) + link tới định nghĩa trong section tương ứng của 02/03/04.
- Tham chiếu CORE-xxx khi trích dẫn rules; không paste lại nội dung rules.

---

## 11. Status & Next Actions

**Trạng thái hiện tại (2026-04-23):** Design v1.0 · **Approved** · Implementation **v6.1.0 COMPLETE** (v5 removed, v6 only, post-release audit fixes applied).

### Tiến độ Implementation

| Stage | Nội dung | Ngày | Tests | Status |
|-------|----------|------|-------|--------|
| **A** | Design Closure — ADR-14→22, sign-off | 2026-04-20 | — | ✅ |
| **B1** | Skeleton scaffold (5 modules, contracts, schemas) | 2026-04-20 | — | ✅ |
| **B2** | Full business logic (8 modules, 259 tests) | 2026-04-20 | 259 | ✅ |
| **B3** | Integration wiring (3 sub-skills + impact_graph) | 2026-04-20 | — | ✅ |
| **B4** | CI/CD, trace reader, runbook, doc polish | 2026-04-21 | — | ✅ |
| **C** | Bellweather lanes QD1 + QD2 (12 probes, 16 E2E) | 2026-04-21 | +16 | ✅ |
| **D** | Extended lanes QD3-QD7 (31 probes, 43 E2E) | 2026-04-21 | +43 | ✅ |
| **E** | Orchestrator integration + lane dispatch | 2026-04-21 | +37 → 413 | ✅ |
| **F** | Probe execution + Agent wiring + scan cache | 2026-04-21 | +29 → 442 | ✅ |
| **G** | Dimension config completion (24/43 probe fixes) | 2026-04-21 | 442 | ✅ |
| **H** | SKILL.md integration + profile wiring + contracts | 2026-04-21 | +21 → 463 | ✅ |
| **I** | E2E validation + downstream v6 wiring + reports | 2026-04-21 | +17 → 480 | ✅ |
| **J** | ISG integration + partition planner + discover v6 dispatch | 2026-04-21 | +12 → 492 | ✅ |
| **K** | Contract sync + `00-core.md §4b` path contract update | 2026-04-21 | 492 | ✅ |
| **L** | Multi-workload integration tests | 2026-04-21 | +15 → ~507 | ✅ |
| **N** | v5 Removal — xóa wf-fix-discover/, --engine flag, v5 paths | 2026-04-21 | ~507 | ✅ |

### Mapping Design Phases → Actual Stages

| Design Phase (roadmap gốc) | Actual Stages | Status |
|---|---|---|
| A — Design Closure | A | ✅ DONE |
| B — Skeleton | B1, B2, B3, B4 | ✅ DONE |
| C — Bellweather | C (QD1+QD2) | ✅ DONE |
| D — Remaining Lanes | D (QD3-QD7) | ✅ DONE |
| E — Golden Suite | (Tích hợp vào F-I) | ⚠️ Partial — golden-v6 fixture có 12 signals |
| F — Migration (--engine flag, wiring) | E, F, G, H, I, J, K, L | ✅ DONE |
| G — Docs + Training | M (doc sync) + CLAUDE.md update (2026-04-21) | ✅ DONE |
| Phase 5 — Cutover (default v6) | SKILL.md v6.0.0 | ✅ DONE |
| Phase 6 — v5 Removal | N | ✅ DONE |

### Test Status

- ~507 tests, 0 failures (after Stage L)
- E2E coverage: full v6 pipeline from profiles → ISG → partition → dispatch → aggregate → reports

### Next Actions

Phase 6 hoàn tất — không còn next actions. Pipeline v6 dimension-based là engine duy nhất.

> Khi có feedback, cập nhật **cả 10 files** nếu quyết định thay đổi trục phân tích; cập nhật **chỉ file liên quan** nếu chỉ chỉnh chi tiết. Các decision đã LOCKED trong [09](09-design-decisions.md) chỉ được mở lại qua ADR mới override.

---

## 12. Sign-off History

| Ngày | Phiên bản | Hành động | Owner | Ghi chú |
|------|----------|-----------|-------|---------|
| 2026-04-20 | v1.0 | **Approved** — Design v1.0 đóng dấu; chuyển sang Giai đoạn B | Eureka (ERK Transport) | Git tag `design-v1.0-approved`. Giai đoạn A (1 tuần) hoàn tất: 9 ADR mới, Q14-Q23 locked, CORE §4b patched. |
| 2026-04-21 | impl-B4 | Stage B (Skeleton) hoàn tất — 4 sub-stages, 259+ tests | DEVKIT | Signal Bus, Scan Cache, Probe Executor skeleton, ISG, Workload Estimator, Concurrency Controller, Impact Graph |
| 2026-04-21 | impl-D | Stage D (Remaining Lanes) hoàn tất — 7/7 lanes, 380 tests | DEVKIT | QD1-QD7 dimension.json + probes, golden-v6 fixture |
| 2026-04-21 | impl-E | Stage E (Orchestrator) hoàn tất — profile resolver, lane dispatch, signal aggregation, 413 tests | DEVKIT | dispatch_lanes(), aggregate_lane_signals(), resolve_probes() |
| 2026-04-21 | impl-F | Stage F (Probe Execution) hoàn tận — probe_executor.py, scan_cache integration, 442 tests | DEVKIT | grep/agent/runtime execution, Signal v2 emission |
| 2026-04-21 | impl-H | Stage H (SKILL.md Integration) hoàn tất — profiles.json, v6 templates, contract update, 463 tests | DEVKIT | 4 profiles (ADR-21), 3 v6 templates, CORE-007 updated |
| 2026-04-21 | impl-I | Stage I (E2E Validation) hoàn tất — resolve_dimensions, report_generator, downstream v6 wiring, 480 tests | DEVKIT | wf-fix-triage/execute v6 mode, fix-status v6 fields |
| 2026-04-21 | impl-J | Stage J (ISG Integration) hoàn tất — ISG + partition planner + discover v6 dispatch, 492 tests | DEVKIT | partition_planner.py (ADR-23), AggregationStats v2 (ADR-24) |
| 2026-04-21 | impl-K | Stage K (Contract Sync) hoàn tất — all _contract.json synced + 00-core.md §4b updated | DEVKIT | Cross-skill path contract aligned |
| 2026-04-21 | impl-L | Stage L (Multi-workload Integration) hoàn tới — ~507 tests, 0 failures | DEVKIT | Full v6 pipeline E2E validated |
| 2026-04-21 | phase-6 | Stage N (v5 Removal) hoàn tất — wf-fix-discover/ deleted, --engine flag removed, 00-core.md + CLAUDE.md cleaned | DEVKIT | v6-only pipeline, 0 v5 references remaining |
| 2026-04-21 | v6.0.0 | **Implementation COMPLETE** — fix-status.json template tạo, 2 stale tests sửa (wf-fix-discover ref → _shared/templates), _contract.json version bump 6.0.0 + --engine removed, CLAUDE.md cập nhật 7 dimension lanes, Phase G ✅ | DEVKIT | 505/505 tests pass, 0 failures |
| 2026-04-22 | v6.1.0 | Post-release audit fixes — minor bump | DEVKIT | SKILL.md 6.1.0, _contract.json 6.1.1 |
