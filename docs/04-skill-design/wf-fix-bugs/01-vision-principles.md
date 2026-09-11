# 01 — Tầm Nhìn & Nguyên Tắc Thiết Kế (v2.0)

> **Đọc trước:** [README.md](README.md)
> **Đọc tiếp:** [02-quality-dimensions.md](02-quality-dimensions.md)
> **Trạng thái:** v2.0 · Phản ánh skill `wf-fix-bugs v10.18.0` (2026-05-16)
> **Tiền thân:** [99-archive/wf-fix-bugs-design-v1.0/01-vision-principles.md](../../99-archive/wf-fix-bugs-design-v1.0/01-vision-principles.md) (v1.0 — design cho v6.0)

---

## 1. Tầm Nhìn (Vision)

`wf-fix-bugs` ở v10.18.0 là **"orchestrator phát hiện và sửa lỗi đa chiều, vận hành thật trên dự án ERP cỡ trung-lớn, có thể tự song song hoá an toàn và resume bất cứ lúc nào"**.

Vision này đặt 4 cam kết với người dùng và 4 cam kết với người triển khai.

### 1.1 Với người dùng (4 cam kết)

1. **Dễ gọi** — một slash command `/wf-fix-bugs`. Không cần biết phase nào, dimension nào, profile nào. Default đúng cho 80% trường hợp.
2. **Hiểu được kết quả** — báo cáo phân loại theo **chiều chất lượng** (correctness / security / performance / a11y / business / data / compat / observability / runtime-health / integration / completeness) chứ không theo layer kỹ thuật.
3. **Chủ động được phạm vi** — `--dims`, `--profile`, `--scope`, `--no-browser` cho power user. Default cho người mới.
4. **Không sợ chạy dài** — bất kỳ lúc nào cũng có thể `--status`, ngắt giữa chừng, rồi `--resume` bất kỳ lúc nào sau (lazy-load aware từ v10.18.0).

### 1.2 Với người triển khai (4 cam kết)

1. **Thêm dimension mới không phá code cũ** — mỗi QD là một sub-skill (`wf-fix-{slug}`) với contract chuẩn. v8.2.0 thêm QD8, v9.0.x thêm QD9+QD10, v9.1 thêm QD11 — không một dòng nào trong orchestrator phải đổi schema.
2. **Debug được rõ ràng** — từ Issue truy ngược về Probe → Signal gốc → Evidence (screenshot/HAR/log/code-ref). Mỗi lane có `signals.json` + `lane-status.json`. Phase 4 có `phase4-summary.json` rollup.
3. **Chạy song song an toàn** — Phase 4 dispatch tối đa 10 lane agents trong 1 response (CORE-025), Playwright tự acquire writer-lock qua Protocol 22, 1 file = 1 writer.
4. **Context không bùng nổ** — kiến trúc lazy-load (CORE-032): SKILL.md ~540 dòng routing, 9 procedure index files, mỗi phase chỉ load group cần thiết → peak context ~2.5K tokens/phase (vs 19K monolithic = -87%).

---

## 2. Problem Statement — Vấn Đề Đã Giải Quyết (v6 → v10)

### 2.1 Vấn đề kế thừa từ v1.0 (đã giải quyết bằng v6.0)

| # | Vấn đề v5.1 | Giải pháp v6.0 | Giải pháp v10.x |
|---|-------------|----------------|------------------|
| PB-1 | Bug nhét chung `issue-registry.json`, không có dimension | Issue schema v2 có `dimension` field | Vẫn đúng — issue-registry.json v2 với 11 dims |
| PB-2 | `wf-fix-discover` phình theo 5-Layer + 12 category | Dimension Lane plugin model | v7+: Lane skill độc lập `wf-fix-{slug}` |
| PB-3 | Flag rời rạc (`--deep`, `--full-test`, `--responsive`) | Profile (quick/standard/deep/exhaustive) | Vẫn đúng + thêm `--show-browser`, `--mobile`, `--no-browser` |
| PB-4 | Không chạy 1 dim độc lập | `--dims=QD3,QD5` first-class | Vẫn đúng — 11 dims, có thể `--dims=QD9` (chỉ runtime health) |
| PB-5 | Severity lẫn lộn impact | Severity per-dim + aggregate MAX-across-dim | Vẫn đúng — Triage agent xử lý |
| PB-6 | Evidence chưa chuẩn hoá multi-dim | Evidence schema (screenshot, har, log, code_ref) | Vẫn đúng — `lane-signals.json` template enforce |
| PB-7 | Exit criteria mập mờ | Exit criteria per dim per profile | Vẫn đúng — `dimension.json` per lane |
| PB-8 | 12 category không orthogonal | 7 QD orthogonal | v9.1: 11 QD orthogonal |

### 2.2 Vấn đề mới phát sinh trong v6.x và đã giải quyết trong v10.x

| # | Vấn đề v6.x | Giải pháp v10.x | Tham chiếu |
|---|-------------|------------------|-------------|
| PB-9 | SKILL.md v6 còn lớn, mixin routing + logic | Lazy-load procedures (CORE-032) — SKILL.md lean ≤500 dòng | ADR-30, [03-architecture.md §3](03-architecture.md) |
| PB-10 | CI tools (GitNexus/Serena) chưa được tận dụng | CI-first PRE-GATE 3-step (CORE-033) — auto-detect + graceful Grep/Glob fallback | ADR-31, [03-architecture.md §5](03-architecture.md) |
| PB-11 | Error codes ad-hoc | Namespaced error codes E001-E109 (CORE-034) — 10 ranges theo phase | ADR-32, [04-contracts-data-model.md §6](04-contracts-data-model.md) |
| PB-12 | Output trải khắp `$SESSION_DIR/` | Session subdirectories `phase{N}-{name}/` (CORE-035) | ADR-33, [03-architecture.md §6](03-architecture.md) |
| PB-13 | Cross-skill artifact chưa có audit chain | `fix-impact.json` schema versioned + `audit_chain.checksum_sha256` (CORE-036) | ADR-34, [04-contracts-data-model.md §4](04-contracts-data-model.md) |
| PB-14 | Agent prompt không nhất quán | 8-section template bắt buộc (CORE-037) — role/task/session/CI/playwright/output/ownership/completion | ADR-35, [03-architecture.md §7](03-architecture.md) |
| PB-15 | Context bùng nổ trên ERP lớn | Context budget tiered (CORE-038) — <65/65-80/80-90/>90% + checkpoint | ADR-36, [03-architecture.md §8](03-architecture.md) |
| PB-16 | Runtime bug chỉ thấy qua browser | QD9 Runtime Health Playwright (v9.0.x) | ADR-27, [02-quality-dimensions.md §QD9](02-quality-dimensions.md) |
| PB-17 | Cross-module bug khó phát hiện | QD10 Cross-Module Integration (v9.0.x) | ADR-28, [02-quality-dimensions.md §QD10](02-quality-dimensions.md) |
| PB-18 | Missing business logic do dev mới chưa thấy được | QD11 Business Completeness 3-pass LLM (v9.1) | ADR-29, [02-quality-dimensions.md §QD11](02-quality-dimensions.md) |
| PB-19 | Phụ thuộc telemetry/observability không kiểm | QD8 Observability (v8.2.0) | ADR-26, [02-quality-dimensions.md §QD8](02-quality-dimensions.md) |
| PB-20 | Multi-session conflict (2 phiên cùng BASE_URL) | E090b Browser CDG + Protocol 22 R/W lock | ADR-38, [03-architecture.md §9](03-architecture.md) |
| PB-21 | Resume mất `lanes/QD*/completed` khi re-run Phase 4 | Phase 4 Selective Archive — preserve completed lanes | ADR-40, [03-architecture.md §10](03-architecture.md), [resume-status.md §Phase 4 Selective Archive](../../.claude/skills/workflow/wf-fix-bugs/procedures/resume-status.md) |
| PB-22 | Context overflow trên ERP lớn (EUREKA-2026 trigger /compact) | Optimization Playbook T1-T10 (v10.3 → v10.18) | ADR-39, [03-architecture.md §11](03-architecture.md) |

### 2.3 Vấn đề còn mở (chưa giải quyết — defer v11)

| # | Vấn đề | Workaround hiện tại | Roadmap |
|---|--------|---------------------|---------|
| PB-O1 | Scan cache git-share giữa 2 dev | Mỗi dev có cache riêng | v11 — content-addressable cache + git-friendly |
| PB-O2 | Lock cross-host (network) | Lock chỉ local — multi-machine cần manual coordinate | v11 — cluster lock service |
| PB-O3 | Phase 5 spot-check `CORE-029` chỉ sample 3 issue | Trust triage agent với spot-check ngẫu nhiên | v11 — full validation pass |

---

## 3. Ý Tưởng Cốt Lõi (v10.x Key Insights)

### 3.1 Bug tồn tại trong **chiều chất lượng**, không trong "phase"

Phase chỉ là **công đoạn xử lý**. Trục chính là **Dimension** (QD1-QD11). Insight này (từ v6.0) vẫn đúng và là nền tảng cho:
- 11 dimension lanes plugin
- Severity per-dim + aggregation
- Exit criteria per dim per profile

### 3.2 Pipeline 7-phase với lazy-load procedures (v10.0)

Ngược lại với v6.0 pipeline tuyến tính ngắn (`Orchestrator → Lane → Signal Bus → Shared Services`), v10 tổ chức thành **7 phase rõ ràng**:

1. **Init** — bootstrap session, CI PRE-GATE, lock, heartbeat, ISG
2. **Scan** — interface detection, code/doc inventory, scope analysis
3. **Plan** — ISG + Partition, Workload Gate (CDG-11), work-plan + dimension-plan
4. **Find Bugs** — PARALLEL dispatch ≤10 lane agents, Playwright via Protocol 22 lock
5. **Triage** — aggregate signals, spawn `wf-fix-triage`, CDG Pre-Execute, Safety Check
6. **Execute** — CI impact, spawn `wf-fix-execute`, validate output, dashboard
7. **Verify** — CQG-1 numeric + CQG-2 browser/integration, 4 reports, `fix-impact.json`

Mỗi phase có **procedure index** (~80-140 dòng) + **group sub-files** (~50-160 dòng/group) → orchestrator chỉ load group cần thiết (lazy-load — CORE-032).

### 3.3 CI-first với graceful degradation (v10.0)

Mọi scan/impact analysis dùng **GitNexus + Serena** trước (Protocol 20). Lock held → fallback Grep/Glob. KHÔNG hỏi user — auto-detect.

CI PRE-GATE 3 steps (Na/Nb/Nc) chạy ở Phase 1 Init:
- **Na** Load CI Capabilities — `ci-detect.sh` → `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`
- **Nb** Index Freshness — `ci-freshness-check.sh` → ok/light/strong/severe
- **Nc** Agent Context Injection — `ci-inject-context.sh` → `$CI_CONTEXT` cho spawned agents

### 3.4 Playwright 3 modes (v10.0)

| Mode | Flag | Khi dùng |
|------|------|----------|
| **Headless** (default) | — | CI, pre-commit, batch run |
| **Visible** | `--show-browser` | Debug, user observation, demo |
| **Mobile** | `--mobile` | Test responsive trên iPhone 14, Pixel 7, iPad Pro device emulation |

Phase 4 lane (QD5/QD7/QD9) tự acquire writer-lock `playwright` qua Protocol 22 `global-rw-lock.sh` — orchestrator KHÔNG cần split wave.

### 3.5 Multi-session an toàn (v10.2)

Cho phép N phiên `wf-fix-bugs` song song trên cùng máy cho module/hệ thống khác nhau (lock per-session). E090b Browser CDG block khi 2 phiên cùng BASE_URL chia sẻ state.

---

## 4. So Sánh Vision v6.0 vs v10.x

| Khía cạnh | v6.0 (design v1.0) | v10.18.0 (design v2.0) |
|-----------|---------------------|-------------------------|
| Pipeline | Tuyến tính 4 stage (Compose/Dispatch/Aggregate/Triage-Fix-Verify) | 7 phase (Init→Scan→Plan→FindBugs→Triage→Execute→Verify) |
| Dimensions | 7 QD (QD1-QD7) | 11 QD (QD1-QD11) — thêm Observability + Runtime Health + Integration + Completeness |
| Procedures | SKILL.md ~700 dòng monolithic | SKILL.md ~540 dòng routing + 9 procedure index + 30+ group sub-files (lazy-load CORE-032) |
| CI tools | Optional, manual | CI-first PRE-GATE 3-step + graceful Grep/Glob fallback (CORE-033) |
| Playwright | Headless only | Headless / `--show-browser` / `--mobile` (3 modes) |
| Multi-session | Best-effort | Lock + heartbeat + JSONL index + E090b BASE_URL gate (Protocol 22) |
| Cross-skill artifact | `issue-v2` schema | `fix-impact-v1` + `phase4-summary-v1` + `coverage-report-v1` + audit_chain sha256 (CORE-036) |
| Agent prompts | Free-form | 8-section template bắt buộc (CORE-037) |
| Error codes | Ad-hoc | Namespaced E001-E109 + auto-fix budget 3/phase (CORE-034) |
| Output organization | `$SESSION_DIR/` flat | `phase{N}-{name}/` subdirectories (CORE-035) |
| Context budget | Best-effort | Tiered <65/65-80/80-90/>90% + checkpoint (CORE-038) |
| Lane count | 7 lane skills | 11 lane skills (max 10 parallel CORE-025) |

---

## 5. 11 Nguyên Tắc Thiết Kế (v10.x)

Các nguyên tắc kế thừa từ v1.0 và bổ sung cho v10.x. Nếu design có xung đột với nguyên tắc → viết rationale vào ADR ([07-tradeoffs-adr.md](07-tradeoffs-adr.md)).

### P1 — Chính xác trước tốc độ (Correctness Over Speed) · CORE-023

Không hy sinh độ chính xác để chạy nhanh. Quick profile chỉ giảm **coverage**, KHÔNG nói sai về kết quả đã chạy.

### P2 — Dimension Orthogonality · CORE-004 + ADR-01

Mỗi QD độc lập về scope. Bug có thể thuộc nhiều dim — nhưng probe nằm trong đúng 1 lane. Severity aggregate MAX-across-dim.

### P3 — Plugin Model (lane skill) · ADR-06

Mỗi dim là `wf-fix-{slug}` riêng. Thêm dim mới = thêm sub-skill + `dimension.json` + probes — KHÔNG đụng orchestrator.

### P4 — Single Source of Truth · CORE-004

`req-registry.json` là SSOT. Registry write delegate qua `wf-fix-execute` (Phase 6), Safe-Write Protocol CORE-006.

### P5 — Evidence-First · ADR-09

Mọi Signal PHẢI có ≥1 non-empty evidence field (code_ref / screenshot / har / log / artifact). Phase 7 CQG-2 enforce.

### P6 — User-Controlled Scope · ADR-08 + ADR-21

User chọn QD subset via `--dims` / `--only` / `--skip` — toàn pipeline enforce scope. Safety floor: profile ≥ standard không bỏ toàn bộ QD1+QD2+QD5.

### P7 — Lazy-Load Procedures · CORE-032 (v10.x mới)

SKILL.md lean routing hub (≤500 dòng), logic chi tiết trong `procedures/phase{N}-{name}/` group files load on-demand. Mỗi phase peak context ~2.5K tokens.

### P8 — CI-First with Graceful Degradation · CORE-033 (v10.x mới)

Auto-detect GitNexus + Serena (3-step PRE-GATE). Lock held / index stale / tool absent → fallback Grep/Glob. KHÔNG hỏi user.

### P9 — Parallelization Strategy · CORE-025 + CORE-039 (v10.x mới)

Phase 4 dispatch ≤10 lane agents trong 1 response (single-response parallel). 1 file = 1 writer. Playwright lane acquire lock qua Protocol 22 — orchestrator KHÔNG split wave.

### P10 — Context Budget Management · CORE-038 (v10.x mới)

<65% bình thường. 65-80% chuẩn bị checkpoint. 80-90% STOP sau phase. >90% FORCE STOP E009.

### P11 — Resume-First Design · ADR-40 (v10.18.0 mới)

Mọi phase phải resumable. Phase 4 SPECIAL CASE: selective archive — preserve `lanes/QD*/completed`, archive `failed/in_progress`. Group-level routing trong phase `in_progress`.

---

## 6. Behavioural Principles (BHV-001 → BHV-004)

Toàn bộ skill tuân thủ 4 BHV principles trong [`.claude/rules/00-behavioral.md`](../../../.claude/rules/00-behavioral.md):

- **BHV-001** Think Before Coding — orchestrator hỏi user qua AskUserQuestion ở mọi CDG point (E090, E090b, CDG-11 Workload, CDG-Pre-Execute, Safety Check, CQG-2 REJECT)
- **BHV-002** Simplicity First — Lazy-load thay vì preload, single-response parallel thay vì wave coordinator, default profile thay vì wizard
- **BHV-003** Surgical Changes — Phase 4 selective archive, R5 partial output handling, atomic write pattern
- **BHV-004** Goal-Driven Execution — POST-GATE T1-T4 mọi phase, CQG-1 numeric + CQG-2 browser/integration, `fix-impact.json` với audit_chain

---

## 7. Mối Quan Hệ Với CORE Rules

Bộ thiết kế v2.0 thực hiện đầy đủ 39 CORE rules. Đặc biệt 8 CORE rules **mới** introduced cùng v10.x (đúc kết từ wf-fix-bugs):

| CORE | Tên | Áp dụng |
|------|-----|---------|
| CORE-032 | Lazy-Load Procedures | SKILL.md ≤500 dòng + procedures/phase{N}-{name}/ groups |
| CORE-033 | CI-First Integration | CI PRE-GATE Na/Nb/Nc + graceful Grep/Glob |
| CORE-034 | Namespaced Error Codes | E001-E109 + auto-fix budget 3 retries/phase |
| CORE-035 | Phase Output Organization | session subdirectories phase{N}-{name}/ + Phase{N}-report.md |
| CORE-036 | Cross-Skill Artifact Contract | fix-impact.json + phase4-summary.json + audit_chain sha256 |
| CORE-037 | Agent Prompt Templates | 8 sections bắt buộc (role/task/session/CI/playwright/output/ownership/completion) |
| CORE-038 | Context Budget Management | Tiered <65/65-80/80-90/>90% + checkpoint |
| CORE-039 | Parallelization Strategy | SKILL.md có section "Parallelization Strategy" phase-by-phase |

> Chi tiết 39 CORE rules: [`.claude/rules/00-core.md`](../../../.claude/rules/00-core.md).

---

## 8. Liên Kết

| Tài liệu | Lý do tham chiếu |
|----------|------------------|
| [README.md](README.md) | Entry point + sitemap |
| [02-quality-dimensions.md](02-quality-dimensions.md) | 11 QDs canonical |
| [03-architecture.md](03-architecture.md) | 7-phase pipeline + lazy-load + CI-first + Playwright |
| [06-evolution-history.md](06-evolution-history.md) | Timeline v5 → v6 → v7 → v8 → v9 → v10 |
| [07-tradeoffs-adr.md](07-tradeoffs-adr.md) | ADR-01 → ADR-40 |
| [09-design-decisions.md](09-design-decisions.md) | Locked decisions v2.0 (North Star, Q14-Q23, plus v10.x decisions) |
| `.claude/skills/workflow/wf-fix-bugs/SKILL.md` | Skill thực tế v10.18.0 |
| `.claude/rules/00-core.md` | 39 CORE rules + 4 BHV principles |
