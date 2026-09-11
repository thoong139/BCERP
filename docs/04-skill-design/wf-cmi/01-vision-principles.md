# 01 — Vision & Principles

> **Mục đích file:** Lý do tồn tại + scope + non-goals của skill `wf-cmi` (wf-cmi).

---

## 1. Tóm tắt

`wf-cmi` giải quyết bài toán **cross-module integrity vỡ ngầm trong ERP nhiều module phát triển độc lập** bằng cách **build entity/workflow/event/permission graphs system-wide + infer + enforce business invariants liên module + đo coverage matrix 10 chiều + detect GAP + đề xuất artifact bổ sung qua CDG**, trả về **báo cáo tiếng Việt cho người vận hành + artifact JSON cho downstream skills consume**.

---

## 2. Vấn đề trước khi có skill

| Hiện trạng (MCV3 v10.x) | Pain point |
|------------------------|-----------|
| `wf-fix-integration` (lane QD10) chỉ chạy được **bên trong** wf-fix-bugs pipeline | Không gọi được standalone khi muốn audit toàn hệ thống ngoài bug fix flow |
| `wf-fix-business-completeness` (QD11) phát hiện MISSING_BUSINESS_RULE nhưng chỉ ở phạm vi bug fix | Không có **runtime registry** chứa business invariants để skills khác cross-check |
| Engine #4 Business Invariant Registry hiện ⚠ Partial (lưu trong markdown rời rạc) | Không query được — wf-design tạo module mới có thể vi phạm invariant của module khác mà không biết |
| Engine #6 Regression Intelligence hiện ⚠ Basic (chỉ diff-aware Git) | Không predict được "thay đổi file X sẽ ảnh hưởng test plan nào của module Y/Z" |
| Cross-module dependencies không có graph chính thức | Permission matrix, event propagation, FK references trải rác — không audit được system-wide |
| `wf-e2e-finding` build `cross-module-gaps.md` per-FEAT | Không scale lên cấp system; không có coverage matrix 10 chiều |
| Coverage assurance chưa chuẩn hóa | Mỗi skill đo coverage khác nhau (code coverage, UI coverage, doc coverage) — không có matrix gộp theo profile |

**Ví dụ cụ thể (EUREKA-2026):**
> EUREKA-2026 có 17 modules .NET 10 (CRM, Orders, Finance, TMS, WMS, Customs, ...). Dev triển khai feature "Tạo Order" trong module `Orders` — feature isolation chạy OK. Nhưng:
> - `Order.CustomerId` reference `CRM.Customer.Id` — nếu Customer chưa có `sales_owner` (HRM.Employee.IsActive=true), order vẫn được tạo → **invariant business vỡ ngầm**.
> - `Order.QuotationId` reference `Quotation.Quote.Id` — nếu Quotation đã expired, order tạo nhưng Finance không thể tạo journal entry → **workflow corruption**.
> - Permission `orders.create` cấp cho Sales role nhưng thiếu mapping qua mobile-staff (`/api/v1/staff/mobile/orders/`) → **RBAC matrix thiếu**.
> - Order tạo trigger event qua RabbitMQ → 4 SignalR hubs (dashboard, tracking, notifications, orders) — nếu 1 consumer thiếu handler, **event coverage gap**.
>
> Dev không có công cụ để kiểm tra **toàn bộ 4 vấn đề trên** trong 1 lần chạy. Hiện phải dùng wf-fix-bugs (cồng kềnh) hoặc chạy thủ công 4-5 skills khác nhau.

---

## 3. Mục tiêu skill (SMART)

| # | Mục tiêu | Đo bằng |
|---|----------|--------|
| 1 | **Build 6 system-wide graphs** trong Phase 2 (entity, module, workflow, API, event, RBAC) | 6 JSON files trong `$SESSION_DIR/phase2-discovery/` với ≥100 nodes/graph cho ERP cỡ EUREKA |
| 2 | **Producer chính của Business Invariant Registry** (Engine #4 upgrade) — san xuat sidecar artifact với field `invariants[]` | `business-invariants.json` ≥50 invariants cho ERP 17 modules + sidecar artifact `business-invariants.json` schema validate PASS |
| 3 | **Coverage matrix 10 chiều** (CD1-CD10) với gates theo profile | `coverage-matrix.json` đầy đủ 10 dim × {quick=60%, standard=80%, deep=95%, exhaustive=100%} thresholds |
| 4 | **Detect cross-module GAP** + đề xuất artifact qua CDG | `gap-report.md` ≥5 candidate artifacts (test/contract/invariant), user ACCEPT/REJECT per item |
| 5 | **Regression intelligence predictive** (Engine #6 upgrade) — input `--since=<git-ref>` + GitNexus impact graph | `regression-map.json` với `predicted_affected_modules[]`, `test_plan[]`, `confidence_score` |
| 6 | **Multi-session + Multi-user collaboration** (Protocol 22 R/W lock + Git-friendly artifacts) | 2+ sessions song song không corrupt; artifacts text deterministic commit qua PR |
| 7 | **Cross-skill artifact** `integrity-impact.json` cho 4 consumers (wf-verify-sync, wf-fix-bugs, wf-implement-feature, wf-prepare-deployment) | Artifact pass schema validate `integrity-impact-v1` + `audit_chain.checksum` verify được |
| 8 | **Output user-friendly** tiếng Việt cho người không chuyên (CORE-028) | `integrity-report.md` ≤30 dòng, mỗi `Phase{N}-report.md` ≤15 dòng |

---

## 4. Nguyên tắc thiết kế

1. **Cross-module first, feature isolation second** — Mục tiêu cốt lõi là phát hiện vỡ ngầm liên module, KHÔNG phải test feature đơn lẻ. Khi xung đột, ưu tiên correctness liên module hơn coverage feature riêng.

2. **Inference + Enforcement, không chỉ Detection** — Skill không chỉ report "module A thiếu invariant X", mà **infer** rule từ pattern + domain knowledge (3-pass LLM kế thừa QD11) + **enforce** qua registry update với CDG approval.

3. **Standalone + Composable** — Skill chạy được độc lập (`/wf-cmi`) nhưng cũng produce artifact cho 4 downstream skills consume qua `--from-cmi`. KHÔNG hard-couple vào main pipeline.

4. **Profile-driven coverage gates** — 4 profiles (quick/standard/deep/exhaustive) với threshold khác nhau (60/80/95/100%). Coverage < threshold → CDG ESCALATE, KHÔNG silent skip (CORE-023 priority order).

5. **Graceful CI degradation** — Tận dụng GitNexus + Serena nếu available (Engine #3 + #13), fallback Grep/Glob nếu không. Zero-config user (CORE-033).

6. **Multi-session safe (Protocol 22)** — R/W lock cho registry + cache cho phép N session đọc song song. Write lock chỉ khi update registry (vài giây) hoặc CDG approve. Multi-user collab qua Git-friendly artifacts text deterministic + audit_chain checksum xuyên người dùng.

7. **Self-healing không tự sửa code** (v1.0) — Skill đề xuất artifact bổ sung (test case, invariant rule, contract) qua CDG; user ACCEPT/REJECT từng cái. KHÔNG tự apply (an toàn cho v1; v2 sẽ có `--auto-apply` cho artifact loại non-code).

8. **Báo cáo nghiệp vụ trước, technical trail sau** — `integrity-report.md` tiếng Việt cho PO/BA non-coder hiểu được. Technical detail (audit_chain, schema version) đi vào JSON artifacts.

---

## 5. Non-goals (KHÔNG làm trong v1)

Để tránh scope creep, skill này **KHÔNG** xử lý:

- **Code linting/formatting** → `wf-fix-bugs` lane QD1/QD2 đã làm
- **Unit test execution** → `wf-implement-feature` + CI pipeline
- **Performance benchmark** → `wf-fix-bugs` lane QD4 (Performance)
- **Security vulnerability scan** → `wf-fix-bugs` lane QD3 (Security)
- **Auto-apply fix vào code** → v1 chỉ đề xuất; v2 sẽ có `--auto-apply` chỉ cho non-code artifacts
- **Single-FEAT testing** → `wf-e2e-verify` per-FEAT đã làm
- **Legacy code scan tổng quan** → `wf-legacy-scan` đã làm (wf-cmi chỉ consume `cross-module-gaps.md` nếu có)
- **Generate code** → wf-cmi chỉ generate `.md` artifacts (test case description, invariant rule), KHÔNG generate `.ts/.cs` code
- **Replace wf-fix-integration (QD10)** — wf-cmi và QD10 cùng đụng cross-module nhưng phạm vi khác: QD10 chạy trong fix-bugs pipeline với scope thu hẹp; wf-cmi chạy standalone system-wide. **Roadmap v2:** wf-fix-bugs có thể consume `integrity-impact.json` từ wf-cmi qua `--from-cmi` để skip QD10 (giảm trùng lặp).

---

## 6. Tham chiếu

- **Patterns áp dụng:**
  - [`../../03-design-patterns/01-lazy-load-procedures.md`](../../03-design-patterns/01-lazy-load-procedures.md) (8 phases — CORE-032)
  - [`../../03-design-patterns/02-ci-first-integration.md`](../../03-design-patterns/02-ci-first-integration.md) (CI PRE-GATE 3-step — CORE-033)
  - [`../../03-design-patterns/03-cross-skill-artifacts.md`](../../03-design-patterns/03-cross-skill-artifacts.md) (`integrity-impact.json` — CORE-036)
  - [`../../03-design-patterns/05-agent-prompt-template.md`](../../03-design-patterns/05-agent-prompt-template.md) (10 lane agents — CORE-037)
  - [`../../03-design-patterns/06-checkpoint-resume.md`](../../03-design-patterns/06-checkpoint-resume.md) (`--resume` 8 phases — CORE-038)
- **Standards áp dụng:**
  - [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md)
  - [`../../02-standards/08-error-code-registry.md`](../../02-standards/08-error-code-registry.md) (claim ranges E010-E099)
  - [`../../02-standards/11-output-path-contract.md`](../../02-standards/11-output-path-contract.md) (paths trong §3.14 mới)
- **Rules liên quan:** CORE-007, CORE-023, CORE-024, CORE-025 (parallelization 10 agents), CORE-027 (CDG), CORE-030, CORE-032-038, BHV-001 (Think Before Coding cho LLM inference), BHV-002 (Simplicity v1 không auto-apply)
- **Engines map (15 engines):** Skill chạm 10/15 engines — xem [`../../01-architecture/10-mcv3-engines-overview.md`](../../01-architecture/10-mcv3-engines-overview.md) §3 và bảng dưới.

---

## 7. Domain context (Engine #14 + #15 — Domain Graph + Business Rule Inference)

> **Khi nào điền:** Skill spawn 24 domain experts cho CD1 Business domain coverage; consume `.claude/references/team-expert/` cho compliance checking.
> **Engine ánh xạ:** #14 Domain Graph + #15 Business Rule Inference.

### 7.1 Domain experts được skill spawn

Skill spawn agent đúng theo domain phát hiện được từ registry `requirements[].department` + project tech stack. EUREKA-2026 là logistics, nhưng có module Finance, HRM, CRM, ... — wf-cmi spawn nhiều experts song song:

| Agent | Khi nào spawn (CD1 Business Coverage) | Knowledge file consume | Compliance phải kiểm |
|-------|---------------------------------------|------------------------|---------------------|
| `business-analyst` | Always (orchestrate inference) | `team-expert/business/*.md` | — |
| `logistics-expert` | Module TMS/WMS/Customs/Orders | `team-expert/logistics/*.md` | HS Code, Incoterms, VNACCS, customs clearance |
| `finance-expert` | Module Finance/Tax/Quotation | `team-expert/finance/*.md` | GAAP/IFRS Vietnam, hóa đơn điện tử, audit trail |
| `sales-expert` | Module CRM/Orders/Quotation | `team-expert/sales/*.md` | Sales pipeline, quotation expiry, commission |
| `hr-expert` | Module HRM/Settings (employee) | `team-expert/hr/*.md` | Labor law Vietnam, payroll, attendance |
| `customer-expert` | Module CRM/CMS (customer-facing) | `team-expert/customer/*.md` | NPS/CSAT, customer journey, mobile-customer endpoints |
| `compliance-expert` | Always (cross-domain compliance) | `team-expert/compliance/*.md` | GDPR (web-customer), audit chain, AML |
| `enterprise-risk-expert` | Profile=deep/exhaustive (governance) | `team-expert/enterprise-risk/*.md` | COSO ERM, risk appetite, BCP |
| `dba` | CD2 Entity coverage + CD7 Data integrity | — (technical) | FK/unique/NOT NULL enforcement |
| `architect` | CD3 Workflow + CD5 Event + CD10 cross-cutting | — (technical) | DDD + CQRS pattern (EUREKA: MediatR pipeline) |

> Danh sách 24 domain experts đầy đủ: [`docs/01-architecture/08-agents-catalog.md`](../../01-architecture/08-agents-catalog.md) §business team. Compliance matrix per domain: [`.claude/rules/06-domain.md`](../../../.claude/rules/06-domain.md).

### 7.2 Knowledge graph touch points

| Touch point | Skill action | Risk nếu bỏ qua |
|-------------|--------------|----------------|
| Đọc `team-expert/{domain}/` khi spawn agent | Inject vào agent prompt §3 Session context | Agent thiếu domain knowledge → invariant inference miss compliance |
| Cross-domain conflict (vd: logistics + finance trên Customs declaration) | Trigger CDG khi 2 expert opinion lệch nhau | Silent contradiction trong invariant registry |
| Domain rule update (compliance mới ban hành) | Skill re-read `team-expert/` mỗi session (no cache cho compliance check) | Stale rule → invariant outdated, audit fail |

### 7.3 Domain compliance checklist (verified per session)

- [ ] Skill identify được domain từ `requirements[].department` + project_type (EUREKA: logistics primary)?
- [ ] Spawn đúng `{domain}-expert` agent theo bảng §7.1?
- [ ] Output `business-invariants.json` references compliance standard cụ thể (HS Code, Incoterms, GDPR, GAAP)?
- [ ] Phase 3 report (`Phase3-report.md`) ghi rõ domain experts đã consult + số invariants infer từ mỗi expert?
- [ ] Cross-domain conflict (vd: customer mobile endpoint + GDPR + audit trail) trigger CDG (E093) trước khi commit invariant?

### 7.4 Anti-patterns (domain context)

❌ **Hard-code domain rules trong skill code** — domain rule thay đổi (vd: Vietnam ban hành Nghị định mới về hóa đơn điện tử) → skill stale; phải đọc `team-expert/finance/` mỗi run
❌ **Skip domain expert spawn "vì nhanh hơn"** — vi phạm BHV-001 (Think Before Coding); kết quả invariant generic, miss compliance Vietnam-specific
❌ **Aggregate invariants từ nhiều domain experts mà không CDG khi conflict** — vi phạm CORE-027 (Critical Decision Gate); user phải biết để judge edge case
❌ **Spawn 24 domain experts cho mọi project** — overkill; chỉ spawn theo registry `department` + project_type, max 10 concurrency (CORE-025)
