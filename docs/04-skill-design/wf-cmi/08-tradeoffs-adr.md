# 08 — Tradeoffs & ADR (wf-cmi)

> **Mục đích file:** Ghi lại các quyết định kiến trúc quan trọng — Context → Decision → Alternatives → Consequences. Reviewer dùng để hiểu **tại sao** chứ không chỉ **gì**.

---

## 1. ADR Index

| ID | Tiêu đề | Status | Ngày |
|----|---------|--------|------|
| ADR-cmi-001 | Skill standalone, không phải lane bên trong wf-fix-bugs | ACCEPTED | 2026-05-15 |
| ADR-cmi-002 | wf-cmi sản xuất `business-invariants.json` (sidecar — KHÔNG bump registry) | ACCEPTED (Revised) | 2026-05-15 |
| ADR-cmi-003 | 10 lanes parallel với CORE-025 max 10 concurrency thay vì pipeline tuần tự | ACCEPTED | 2026-05-15 |
| ADR-cmi-004 | 3-pass LLM inference kế thừa pattern QD11 thay vì single-pass | ACCEPTED | 2026-05-15 |
| ADR-cmi-005 | Multi-session R/W lock qua Protocol 22 thay vì global mutex | ACCEPTED | 2026-05-15 |
| ADR-cmi-006 | Self-healing v1 chỉ ĐỀ XUẤT artifact, không auto-apply | ACCEPTED | 2026-05-15 |
| ADR-cmi-007 | Cross-skill artifact `integrity-impact.json` cho 4 consumers, opt-in qua `--from-cmi` | ACCEPTED | 2026-05-15 |
| ADR-cmi-008 | Coverage matrix 10 chiều (CD1-CD10), KHÔNG mở rộng thành 15+ | ACCEPTED | 2026-05-15 |

---

## 2. ADR-cmi-001: Skill standalone, không phải lane bên trong wf-fix-bugs

**Status:** ACCEPTED — 2026-05-15
**Owner:** orchestrator + architect team

### Context

`wf-fix-bugs` đã có 11 lanes QD1-QD11, trong đó QD10 (wf-fix-integration) và QD11 (wf-fix-business-completeness) đụng cross-module integrity. Hỏi: có nên implement wf-cmi như **lane QD12** bên trong wf-fix-bugs, hay làm **skill standalone**?

### Decision

**Skill standalone**, đứng cùng nhóm với `wf-scan-target` và `wf-diagram`. Slash command `/wf-cmi` (alias cho `/wf-cmi`).

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Lane QD12 trong wf-fix-bugs | Đơn giản, reuse infrastructure | Phải chạy qua bug fix pipeline (8 phases) → 30-60 min overhead; user không thể chạy chỉ integrity check standalone; trigger bởi bug report là sai — integrity check nên proactive | Trái triết lý — integrity check phải chủ động, không reactive sau bug |
| B. Skill standalone (chốt) | Standalone trigger, có thể chạy nhanh `quick` profile 5-10 min; chạy được khi không có bug; produce artifact cho 4 consumers | Phải re-implement orchestrator + session management | Best of both — đầu tư orchestrator một lần, dùng được nhiều case |
| C. Sub-skill của wf-verify-sync | Tích hợp với verify-sync flow tự nhiên | Verify-sync chỉ check REQ-ID traceability, không đụng integrity — semantic không khớp | Vi phạm BHV-002 Simplicity (force-fit) |

### Consequences

**Tích cực:**
- User chạy được `/wf-cmi --profile=quick` để hotfix check 5-10 min, không cần full fix-bugs pipeline
- Skill chạy theo cron/CI nightly mà không trigger bug-fix flow
- Cross-skill artifact `integrity-impact.json` consume được bởi wf-fix-bugs (`--from-cmi`) — giảm trùng lặp QD10/QD11
- Tránh "kitchen sink" wf-fix-bugs (đã có 11 lanes, thêm QD12 sẽ quá lớn)

**Tiêu cực:**
- Phải implement orchestrator độc lập (~3 tuần effort)
- 2 skills cùng đụng cross-module (QD10 + wf-cmi) → cần roadmap merge QD10 thành consumer của wf-cmi ở v2

**Risks:** Trùng lặp tạm thời với QD10 ~6 tháng cho đến khi QD10 migrate sang `--from-cmi`.

### Related

- Rule liên quan: BHV-002 (Simplicity), CORE-002 (Workflow phases)
- File khác cùng skill: [01-vision-principles.md](01-vision-principles.md) §5 Non-goals
- Engines: #2 Workflow Orchestration, #5 Cross-Module Verification

---

## 3. ADR-cmi-002: wf-cmi sản xuất `business-invariants.json` (sidecar — KHÔNG bump registry)

**Status:** ACCEPTED (Revised) — 2026-05-15
**Owner:** business-analyst + architect
**Note:** Initial proposal "bump registry schema v1/v2 → v3" đã bị REJECT (user feedback rủi ro quá cao cho v1) — chuyển sang sidecar artifact pattern.

### Context

Engine #4 Business Invariant Registry hiện ⚠ Partial: REQ-ID/FEAT-ID/impl_status lưu trong `req-registry.json` v1/v2, nhưng business invariants trải rác trong `phase1-business/*.md`. Cần cơ chế **runtime registry** query được, nhưng KHÔNG được rủi ro phá registry hiện tại.

### Decision (REVISED)

**wf-cmi sản xuất `business-invariants.json` như SIDECAR ARTIFACT tại `.mc-data/work/wf-cmi/business-invariants.json`** — KHÔNG bump registry schema, KHÔNG touch `req-registry.json`.

- **Producer:** wf-cmi (PRIMARY, Phase 3 inference + Phase 7 CDG ACCEPT)
- **Schema:** `business-invariants-v1` (independent, không phụ thuộc registry schema)
- **Consumers:** Opt-in qua flag `--from-cmi` (wf-verify-sync, wf-fix-bugs, wf-implement-feature, wf-prepare-deployment, wf-design)
- **Cross-reference với registry:** qua `req_id_ref` field trong mỗi invariant (lookup khi cần)
- **Audit chain:** `audit_chain.source_registry_checksum` ghi sha256 của registry tại lúc artifact produce — consumer detect stale
- **Multi-session:** R/W lock qua Protocol 22; write lock ngắn khi update canonical artifact

### Alternatives considered (REVISED)

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Bump registry v3 (initial proposal) | Single SSOT trong registry; query trực tiếp jq | **Rủi ro cao**: 5+ skill consumers phải migrate; v1/v2 → v3 migration script có thể fail → registry corrupt → break workflow | **REJECTED** — rủi ro quá cao cho v1 |
| B. Sidecar artifact `.mc-data/work/wf-cmi/` (CHỐT) | Zero impact lên registry; an toàn v1; consumers opt-in; schema versioning độc lập | Skills cần đọc 2 files (registry + sidecar) thay vì 1 | **ACCEPTED** — CORE-036 cross-skill artifact pattern đã handle |
| C. Sidecar tại `.mc-data/docs/_meta/business-invariants.json` | Gần SSOT level | Trách nhiệm sở hữu vượt scope `work/` boundary | Vi phạm CORE-030 (work là per-skill runtime) |
| D. Embed trong `req-registry.json` v2 (optional field, no schema bump) | Single file | Schema lỏng; consumer không biết khi nào trust field | Vi phạm CORE-004 (registry schema phải versioned chặt) |

### Consequences

**Tích cực:**
- **Zero risk lên registry** — v1/v2 registry unchanged, không break existing consumers
- Schema `business-invariants-v1` độc lập — bump dễ control
- Consumers opt-in qua `--from-cmi` — không bắt buộc consume
- Engine #4 nâng từ ⚠ Partial → ✅ Đầy đủ qua sidecar pattern (không cần bump SSOT)
- Implementation v1 đơn giản hơn (không cần migration script v1/v2 → v3)
- Multi-user: artifact gắn `inferred_by.session_id` + `approver` xuyên người dùng

**Tiêu cực:**
- 2 files để query thay vì 1 (consumer phải đọc cả `req-registry.json` + `business-invariants.json` cho complete view)
- Cross-reference qua `req_id_ref` cần audit_chain enforcement
- Long-term: nếu invariants count >1000, có thể cần split theo module

**Risks:**
- Sidecar artifact stale so với registry → mitigate qua `audit_chain.source_registry_checksum` field
- LLM inference low confidence → mitigate qua CDG E094 user accept + status="proposed" cho confidence <0.5

### Related

- Rule liên quan: CORE-004 (SSOT — sidecar không vi phạm vì là OWN SSOT cho field business invariants), CORE-006 (Safe-Write KHÔNG áp dụng — chỉ áp dụng cho registry), CORE-036 (Cross-Skill Artifact Contract — chính)
- Engines: #4 Business Invariant Registry (this skill upgrades qua sidecar pattern, KHÔNG đụng registry SSOT)
- File khác: [04-file-contract.md](04-file-contract.md) §6 Business invariants (sidecar pattern detail)
- Patterns: 3-pass LLM kế thừa từ [`../wf-fix-bugs/02-quality-dimensions.md`](../wf-fix-bugs/02-quality-dimensions.md) §QD11
- Path canonical: `.mc-data/work/wf-cmi/business-invariants.json` — sẽ add vào [`../../02-standards/11-output-path-contract.md`](../../02-standards/11-output-path-contract.md) §3.14 khi PR skill

---

## 4. ADR-cmi-003: 10 lanes parallel với CORE-025 max 10 concurrency

**Status:** ACCEPTED — 2026-05-15
**Owner:** architect

### Context

Coverage matrix yêu cầu kiểm tra 10 dim (CD1-CD10). Hỏi: pipeline tuần tự (10 phases) hay parallel (1 phase, 10 lanes)?

### Decision

**Phase 4 dispatch 10 lanes PARALLEL** với max concurrency 10 (đúng CORE-025 limit). Mỗi lane là 1 agent độc lập (1 file = 1 writer), produces `signals.json`.

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Pipeline tuần tự (10 phases CD1→CD10) | Đơn giản, debug dễ | Total time = sum(per-lane time) ~50-100 min standard; không reuse được parallel pattern của wf-fix-bugs | Quá chậm cho daily work |
| B. Parallel max 5 lanes (conservative) | Tránh resource exhaustion | 2 batches × 5 lanes ~30 min; phức tạp batching logic | Không tận dụng max budget CORE-025 |
| C. Parallel max 10 lanes (chốt) | ~5-10 min total cho 10 lanes; tận dụng CORE-025 max | Mỗi lane 1 agent → 10 agents concurrent → load cao | Tương đương wf-fix-bugs Phase 4 đã proven (11 lanes QD1-QD11) |
| D. Parallel 15+ lanes | Faster | Vi phạm CORE-025 (max 10) | NOT ALLOWED |

### Consequences

**Tích cực:**
- Total Phase 4 time ~5-12 min (standard profile) — competitive với wf-fix-bugs
- Reuse architecture pattern từ wf-fix-bugs (proven trong production)
- Mỗi lane độc lập — fail 1 lane không cascade (per-lane retry budget)

**Tiêu cực:**
- 10 agents concurrent → context budget per agent ~10% tổng budget — phải design prompt chặt
- Aggregation Phase 5 cần dedupe cross-lane (E049 fingerprint collision risk)
- Profile=quick chỉ 5 lanes (skip CD5,6,8,9,10) — phải có activation matrix

**Risks:** Lane timeout (3 min/lane — E041) cascade nếu codebase quá lớn; mitigate qua per-lane retry x1.

### Related

- Rule: CORE-025 (Parallelization max 10), CORE-037 (Agent Prompt Template)
- Real example: [`../wf-fix-bugs/03-architecture.md`](../wf-fix-bugs/03-architecture.md) (11 lanes pattern)
- File: [agent-prompt.md](agent-prompt.md) (10 lane prompts), [03-phase-routing.md](03-phase-routing.md) Phase 4

---

## 5. ADR-cmi-004: 3-pass LLM inference kế thừa pattern QD11 thay vì single-pass

**Status:** ACCEPTED — 2026-05-15
**Owner:** business-analyst + architect

### Context

Phase 3 Invariant Registry cần infer business invariants từ code + docs. Single-pass LLM (gửi all context + ask "extract invariants") quick nhưng kém chính xác. QD11 đã có 3-pass pattern proven.

### Decision

**Áp dụng 3-pass LLM kế thừa QD11:**
- Pass 1: Cross-module pattern compare (architect agent)
- Pass 2: Domain heuristic (spawn `{domain}-expert` agents parallel — max 5)
- Pass 3: Registry gap detection (business-analyst aggregate)

Output → CDG (Phase 7), user ACCEPT/REJECT/DEFER per candidate.

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Single-pass LLM | Fast (1 LLM call/domain) | Low precision — miss domain compliance (HS Code, GDPR); không cross-validate; high false positive | Vi phạm CORE-023 quality > speed |
| B. 3-pass LLM kế thừa QD11 (chốt) | Proven pattern, high precision; cross-validation built-in | 3x LLM cost; complex orchestration | Reuse architecture; cost mitigate qua profile=quick skip Phase 3 LLM |
| C. Rule-based inference only (no LLM) | Zero cost, deterministic | Miss invariants không match pattern; không hiểu domain context | Engine #15 (Business Rule Inference) yêu cầu LLM |
| D. Fine-tune dedicated model | Highest precision | Quá phức tạp cho v1; cost upfront cao | Defer to v3 (nếu có) |

### Consequences

**Tích cực:**
- Precision cao (kế thừa QD11 proven trong production)
- Cross-domain conflict detection tự nhiên qua Pass 2 spawn multiple domain experts
- Profile-gated: quick=skip LLM, standard=1-pass, deep/exhaustive=3-pass

**Tiêu cực:**
- Cost: ~500K tokens (~$2.50) cho deep profile
- Time: Phase 3 mất 2-5 min với 3-pass
- Phụ thuộc LLM API availability — E034 timeout fallback

**Risks:** LLM hallucination → false invariants — mitigate qua CDG (user must accept), confidence threshold filter (`< 0.5 → proposed only`).

### Related

- Rule: CORE-027 (CDG), BHV-001 (Think Before Coding)
- Pattern: [`../wf-fix-bugs/02-quality-dimensions.md`](../wf-fix-bugs/02-quality-dimensions.md) §QD11 (3-pass canonical)
- File: [04-file-contract.md](04-file-contract.md) §6.5 Inference workflow

---

## 6. ADR-cmi-005: Multi-session R/W lock qua Protocol 22 thay vì global mutex

**Status:** ACCEPTED — 2026-05-15
**Owner:** orchestrator + sre

### Context

Plan §7 yêu cầu multi-session parallelism: dev mở 2+ phiên `/wf-cmi` đồng thời trên cùng máy. Hỏi: lock strategy như thế nào?

### Decision

**Apply Protocol 22 (cross-session R/W lock):**
- Read lock: N readers đồng thời cho registry/cache (Phase 2, 3, 6 read-only)
- Write lock: độc quyền chỉ khi update sidecar artifact `business-invariants.json` (Phase 7) hoặc atomic write SSOT (Phase 1, 5, 8)
- Session lock per-session ($SESSION_DIR/.lock) — isolated workspace

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Global mutex (file lock toàn dự án) | Đơn giản | Block toàn bộ phiên khác kể cả khi read-only — vi phạm yêu cầu "phase analyze (read-only) không block" | Vi phạm plan §7 |
| B. Protocol 22 R/W lock (chốt) | Read lock không block; write lock chỉ vài giây | Phức tạp implement (per-resource lock) | Plan §7 yêu cầu explicit |
| C. Optimistic concurrency (no lock, retry on conflict) | Zero overhead | Race condition trên registry → CORE-006 violation | Quá risky cho SSOT |
| D. Postgres-style MVCC | Mạnh nhất | Overkill — DEVKIT là file-based | Vi phạm BHV-002 Simplicity |

### Consequences

**Tích cực:**
- Dev A chạy `--scope=system deep` (2h) + Dev B chạy `--scope=module=crm quick` (10 min) song song mà không block
- 2 dev cùng phiên read scope khác nhau → 2 read locks đồng thời
- Phiên A crash → phiên B không bị ảnh hưởng (per-session $SESSION_DIR)

**Tiêu cực:**
- Implement complex hơn (per-resource lock management)
- Edge case: write lock starvation nếu readers liên tục — mitigate qua write priority queue

**Risks:** Lock deadlock cross-session → mitigate qua stale check 30 min auto-release (E008).

### Related

- Protocol 22: [`.claude/skills/protocols/22-r-w-lock.md`](../../../.claude/skills/protocols/22-r-w-lock.md)
- Rule: CORE-030 (Session Isolation), CORE-035 (Phase Output)
- File: [07-procedures-structure.md](07-procedures-structure.md) §2 (R/W lock helpers)

---

## 7. ADR-cmi-006: Self-healing v1 chỉ ĐỀ XUẤT artifact, không auto-apply

**Status:** ACCEPTED — 2026-05-15
**Owner:** business-analyst + product-expert + security

### Context

Plan §5 yêu cầu "self-healing" — tự đề xuất + tự thực hiện fix, test, contract, invariant còn thiếu. Hỏi: v1 có nên auto-apply hay chỉ đề xuất?

### Decision

**v1: Chỉ ĐỀ XUẤT artifact, không auto-apply.** User ACCEPT/REJECT từng cái qua CDG. KHÔNG tự sửa code, KHÔNG tự thêm test file, KHÔNG tự edit contract.

Exception: **invariant rules** được auto-apply vào sidecar artifact `business-invariants.json` sau user CDG ACCEPT (E094) — vì invariant là metadata, không phải code.

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Full self-healing v1 (auto-apply mọi loại) | Maximum automation | Rủi ro overwrite working code; vi phạm BHV-003 Surgical Changes; trust issue với user mới | Quá risky cho v1 |
| B. Chỉ đề xuất, user accept manually (chốt) | An toàn, build trust; user control | Workflow chậm hơn — user phải review mỗi suggestion | Acceptable cho v1; v2 sẽ có `--auto-apply=non-code` flag |
| C. Auto-apply chỉ artifact non-code (test description, invariant rule, doc) | Cân bằng | Vẫn risky nếu suggestion sai context | Defer to v2 sau khi có metrics confidence từ v1 |
| D. Auto-apply với undo + audit trail | Có undo | Implement complex; user có thể không kịp catch lỗi | Defer to v2 |

### Consequences

**Tích cực:**
- An toàn cho v1 — user luôn có quyền final
- Build user trust dần dần (sau khi user thấy 50+ suggestions chính xác)
- Tuân thủ BHV-003 (Surgical Changes) — không tự "improve" code

**Tiêu cực:**
- User phải review từng suggestion → slow workflow (mitigate qua batch CDG)
- Workflow không "fully automated" như plan §5 mong muốn

**Risks:** v2 add `--auto-apply` cần migration path — phải có audit chain rõ.

### Related

- Rule: BHV-001 (Think Before Coding), BHV-003 (Surgical Changes), CORE-027 (CDG)
- File: [01-vision-principles.md](01-vision-principles.md) §5 Non-goals (auto-apply là non-goal v1)
- Plan: [`../../../plans/wf-cmi/wf-cmi.md`](../../../plans/wf-cmi/wf-cmi.md) §5 GAP & self-healing

---

## 8. ADR-cmi-007: Cross-skill artifact `integrity-impact.json` cho 4 consumers, opt-in qua `--from-cmi`

**Status:** ACCEPTED — 2026-05-15
**Owner:** architect + orchestrator

### Context

wf-cmi produce nhiều artifacts (coverage matrix, invariants, regression map, gap suggestions). Các skill downstream có thể consume. Hỏi: bundle thành 1 artifact hay multiple?

### Decision

**Bundle thành 1 artifact `integrity-impact.json`** (schema `integrity-impact-v1`) — single source of truth cho 4 consumers. Consumer activate qua `--from-cmi` flag opt-in.

Detail artifacts (matrix, invariants, regression-map) vẫn ghi riêng để debug, nhưng consumer chỉ cần đọc `integrity-impact.json`.

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. Multiple artifacts, consumer đọc từng cái | Flexible, debug-friendly | Consumer phải biết path 4-5 files; schema drift risk | Vi phạm CORE-036 — cross-skill artifact phải single |
| B. 1 bundle artifact (chốt) | Consumer chỉ 1 path; schema versioned; audit_chain single | Bundle artifact lớn (~50KB cho EUREKA) | Acceptable size; consumer chỉ đọc field cần |
| C. GraphQL-style query API | Maximum flexibility | Quá phức tạp cho file-based DEVKIT | Vi phạm BHV-002 Simplicity |

### Consequences

**Tích cực:**
- Consumer code: chỉ check `--from-cmi` flag → đọc 1 path → done
- Schema versioned (`integrity-impact-v1`) — bump dễ control
- audit_chain.checksum verify được consumer dùng đúng artifact

**Tiêu cực:**
- Bundle size lớn (consumer load 50KB dù chỉ cần 5KB field)
- v2 cần `partial-load` flag nếu performance issue

**Risks:** Consumer ignore version mismatch → mitigate qua PRE-GATE T2 validate `$schema`.

### Related

- Rule: CORE-036 (Cross-Skill Artifact Contract)
- Pattern: [`../../03-design-patterns/03-cross-skill-artifacts.md`](../../03-design-patterns/03-cross-skill-artifacts.md)
- File: [04-file-contract.md](04-file-contract.md) §4.5 `integrity-impact.json` schema
- Real example: `fix-impact.json` (wf-fix-bugs), `preflight-impact.json`, `change-impact.json`

---

## 9. ADR-cmi-008: Coverage matrix 10 chiều (CD1-CD10), KHÔNG mở rộng thành 15+

**Status:** ACCEPTED — 2026-05-15
**Owner:** business-analyst + architect

### Context

Plan §6 đề xuất 10 coverage layers (business/entity/workflow/API/event/permission/data/observability/regression/documentation). Hỏi: có nên thêm dim như "Performance coverage", "Security coverage", "i18n coverage" cho ERP đa ngôn ngữ?

### Decision

**Giữ 10 dim (CD1-CD10) đúng plan §6**, KHÔNG mở rộng v1. Lý do:
- Performance / Security đã có lane riêng trong wf-fix-bugs (QD4, QD3) — wf-cmi reuse qua `--from-fix-bugs`
- i18n coverage là sub-concern của CD10 Documentation
- Vi phạm BHV-002 nếu mở rộng quá sớm

Roadmap v2: nếu user feedback yêu cầu, thêm CD11 (Performance cross-module), CD12 (Security cross-module), CD13 (i18n consistency) — nhưng phải qua CORE-027 CDG.

### Alternatives considered

| Option | Pros | Cons | Lý do reject |
|--------|------|------|--------------|
| A. 10 dim (chốt) | Đúng plan; vừa đủ comprehensive; manageable concurrency 10 | Có thể miss edge case (vd performance cross-module) | Mitigate qua roadmap v2 + consume từ wf-fix-bugs |
| B. 13 dim (thêm performance, security, i18n) | Comprehensive hơn | Vượt CORE-025 max 10 concurrency Phase 4 → phải batch | Vi phạm CORE-025 |
| C. 15+ dim (kitchen sink) | Maximum coverage | Implement 5 skill effort; vi phạm BHV-002 | NOT ALLOWED v1 |

### Consequences

**Tích cực:**
- Manageable scope v1 (~6 tuần implementation)
- CORE-025 max 10 concurrency Phase 4 fit đúng 10 lanes
- Clear roadmap v2 cho dim mở rộng

**Tiêu cực:**
- v1 không phủ performance/security cross-module (user phải chạy wf-fix-bugs riêng + consume)
- Số 10 cố định — tăng dim phải bump major version

**Risks:** User expectation từ plan §6 nói "10 layers" → đúng promise; nếu sau đó user yêu cầu thêm → roadmap v2 ADR mới.

### Related

- Rule: BHV-002 (Simplicity), CORE-025 (Concurrency)
- Plan: [`../../../plans/wf-cmi/wf-cmi.md`](../../../plans/wf-cmi/wf-cmi.md) §6
- File: [05-execution-profiles.md](05-execution-profiles.md) §3 (lane activation), [agent-prompt.md](agent-prompt.md) (10 lane prompts)

---

## 10. Liên kết

- ADR style chung: Tham khảo [Michael Nygard's ADR template](https://github.com/joelparkerhenderson/architecture-decision-record)
- Ví dụ hay trong MCV3:
  - [`../wf-fix-bugs/07-tradeoffs-adr.md`](../wf-fix-bugs/07-tradeoffs-adr.md)
  - [`../wf-legacy-scan/08-tradeoffs-adr.md`](../wf-legacy-scan/08-tradeoffs-adr.md)
- ADR roadmap v2 (planned): performance/security/i18n cross-module dimensions, --auto-apply non-code artifacts, dedicated fine-tuned model thay 3-pass LLM
