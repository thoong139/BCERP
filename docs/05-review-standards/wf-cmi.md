# Tiêu chuẩn rà soát — `wf-cmi` v1.0.0

> **Kế thừa:** [`_template-common.md`](./_template-common.md) v1.0
> **Path skill:** `.claude/skills/workflow/wf-cmi/`
> **Phiên bản rà soát:** 1.0 (2026-05-16)
> **Variant:** ❸ ORCHESTRATOR (spawn ≥3 lanes — thực tế 10 lanes CD1-CD10 + triage agent)

File này chỉ viết **Skill Profile** và **Extension section** (tiêu chuẩn đặc thù). Các nhóm tiêu chuẩn chung (A/B/C/D/E/F/H/I/J) nằm trong [`_template-common.md`](./_template-common.md).

---

## 0. Tổng quan skill

| Mục | Nội dung |
|-----|----------|
| **Vai trò** | **Standalone Orchestrator** — AI Enterprise Integrity Orchestrator chạy system-wide trên ERP để build 6 dependency graphs, infer + enforce business invariants liên module, đo coverage matrix 10 chiều (CD1-CD10), phát hiện GAP và đề xuất artifact bổ sung qua CDG |
| **Entry point** | `procedures/phase1-init.md` (Phase 1 Init + CI PRE-GATE) — lazy-loaded từ SKILL.md routing map |
| **Kiến trúc** | Lean SKILL.md (487 dòng — CORE-032) + 10 procedure files lazy-load (5344 dòng tổng) + 29 templates + 5 evals test cases |
| **Execution mode** | 8 phases tuần tự với Phase 4 SPAWN 10 lane agents parallel (max concurrency 10 — CORE-025) |
| **Strategy routing** | 4 profiles (`quick` 5/10/30 dim threshold `≥60%`, `standard` 7 lanes `≥80%`, `deep` 10 lanes `≥95%`, `exhaustive` 10 + LLM enhance `100%`) với lane activation matrix |
| **Đặc trưng** | Multi-session R/W lock (Protocol 22); 3-pass LLM Phase 3 (kế thừa QD11); regression-aware (`--since`); CDG self-healing chỉ ĐỀ XUẤT (không auto-apply) |
| **Output** | 31 session-scoped artifacts (8 Phase reports, 6 graphs, signals/lane-status per lane, coverage-matrix, regression-map, gap-suggestions, integrity-report, integrity-impact) + 1 **canonical sidecar** `business-invariants.json` ngoài sessions/ + 5 auxiliary (lock, session-log, error-ledger, index) |
| **Registry** | **NONE** — READ-ONLY consumer của `req-registry.json`. Mọi invariant đi vào sidecar artifact `.mc-data/work/wf-cmi/business-invariants.json` (APPEND-only — ADR-cmi-002 Revised, **KHÔNG bump registry v3**) |
| **Cross-skill** | 6 consumers (opt-in qua `--from-cmi`): `wf-verify-sync`, `wf-fix-bugs`, `wf-implement-feature`, `wf-prepare-deployment`, `wf-design`, `wf-add-scope`. 9 producers consumes_from (`wf-brainstorm`, `wf-analyze-requirements`, `wf-define-features`, `wf-design`, `wf-implement-feature`, `wf-verify-sync`, `wf-fix-bugs`, `wf-legacy-scan`, `wf-e2e-finding`) |

---

## 1. Skill Profile

```yaml
skill:
  name: wf-cmi
  version: 1.0.0
  review_version: 1.0
  path: .claude/skills/workflow/wf-cmi/

profile:
  # Kiến trúc
  is_orchestrator: true           # ORCHESTRATOR variant ❸ (spawn 10 lane agents)
                                  # KHÁC wf-fix-bugs (pure orchestrator): wf-cmi có procedures/ + templates/
  has_procedures: true            # 10 procedure files lazy-load (CORE-032)
  has_templates: true             # 29 templates (16 JSON + 13 Markdown)
  has_phases: true                # 8 phases (Init → Discovery → Invariant → Coverage Dispatch
                                  # → Aggregate → Regression → GAP+CDG → Report)

  # State & Resume
  has_state_machine: true         # integrity-status.json (SSOT pipeline state) + 8 phase tracking
  has_resume: true                # --resume (đọc state, route next_action, staleness guard 30 min)
  has_status: true                # --status (in trạng thái, không chạy phases)
  is_multi_run: true              # Protocol 22 cross-session R/W lock; max 5 session/máy (quick/standard),
                                  # max 2 session/máy (deep/exhaustive)

  # Execution
  spawns_agents: true             # 10 lane agents (CD1-CD10) + 1 triage agent + 24 domain experts (CD1)
                                  # via Agent({subagent_type, prompt}) max concurrency 10
  has_strategy_routing: true      # 4 profiles → lane activation matrix:
                                  # quick=5 lanes (CD1,2,3,4,7), standard=7 (+CD5,6,9),
                                  # deep=10, exhaustive=10+LLM enhance

  # Registry
  writes_registry: false          # ADR-cmi-002 Revised — KHÔNG bump registry, dùng sidecar
  registry_role: NONE             # safe_write_rule: CORE-006 NONE — sidecar artifact riêng

contracts:
  producers_count: 9              # wf-brainstorm, wf-analyze-requirements, wf-define-features,
                                  # wf-design, wf-implement-feature, wf-verify-sync, wf-fix-bugs,
                                  # wf-legacy-scan, wf-e2e-finding
  consumers_count: 6              # wf-verify-sync, wf-fix-bugs, wf-implement-feature,
                                  # wf-prepare-deployment, wf-design, wf-add-scope (opt-in --from-cmi)
```

**Nhóm tiêu chuẩn áp dụng (từ common template):**

| Nhóm | Áp dụng | Ghi chú |
|------|---------|---------|
| **A** Structural | Toàn bộ A1-A10 | A6 nhánh `is_orchestrator=true` nhưng VẪN có procedures/+templates/ (đặc thù wf-cmi vs wf-fix-bugs pure). A8 áp dụng — 10 procedure files khớp routing map SKILL.md |
| **B** Workflow Integrity | B1-B10 | B7 `--status`/`--resume` qua `procedures/resume-status.md` (7 step status + 10 step resume); B9-B10 cho profile→lane activation routing |
| **C** Output & Template | C1-C7 | 29 templates với `$schema` cho JSON + HTML comment metadata cho MD. C5 conditional: `regression-map` skip nếu profile=quick OR no `--since` |
| **D** Cross-Skill | D1-D4 | 9 producers (consumes_from), 6 consumers (produces_for opt-in `--from-cmi`). Sidecar canonical path OUTSIDE sessions/ là cross-skill mass-producer pattern đặc thù |
| **E** Protocol & CORE | Toàn bộ E1-E14 + **E12 MULTI-RUN nghiêm ngặt** + E10 (trace), E11 (agent spot-check 10 lanes); E15-E18 SKIP (NONE registry role) | |
| **F** Determinism/Agent | F1-F5 + F6 (deterministic enumeration cho 6 graphs Phase 2) | F7 SKIP (không có scoring) |
| **H** Error Handling | H1-H5 | E001-E109 (108 entries) — namespace đầy đủ 8 phase + shared + CDG + warnings |
| **I** Testability | I1-I5 | 5 test cases (TC-cmi-001..005) cover: smoke (1 module), integration (3 modules), edge (corrupt), resume (interrupt Phase 4), concurrent (2 session cùng máy). TC-006/007/008 defer v2 |
| **J** Idempotency | J1-J4 | J3 dual mode (predictive GitNexus vs diff-aware git diff) — fingerprint deterministic; J4 session isolation `sessions/{YYYY-MM-DD-{scope}-{slug}-NN}/` |

---

## 2. Điểm đặc thù skill (Extension)

### 2.1 NHÓM G — Sidecar Artifact + 10 Lanes + 3-Pass Inference + CDG

Tiêu chuẩn này **không tổng quát hóa** — chỉ áp dụng cho `wf-cmi` (ORCHESTRATOR có sidecar canonical pattern).

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **G1** | Sidecar artifact KHÔNG bump registry (ADR-cmi-002 Revised) | `jq '.registry_scope' _contract.json` | `write_role == "NONE"` + `fields_owned == []` + `safe_write_rule` ghi rõ "wf-cmi không có quyền write registry". `business-invariants.json` ghi vào `.mc-data/work/wf-cmi/` (OUTSIDE sessions/) — KHÔNG vào `.mc-data/docs/_meta/` |
| **G2** | Sidecar canonical path OUTSIDE sessions/ | `jq '.outputs.working[] \| select(.path \| contains("business-invariants"))' _contract.json` | Có 2 entries cho `business-invariants.json`: (1) draft `$SESSION_DIR/phase3-invariants/business-invariants.json` + (2) **canonical** `.mc-data/work/wf-cmi/business-invariants.json` (APPEND-only). Path canonical KHÔNG chứa `sessions/` segment. Bổ sung 1 lock file `.mc-data/work/wf-cmi/_locks/business-invariants.rwlock` (Protocol 22) |
| **G3** | 10 lanes CD1-CD10 cố định v1 (ADR-cmi-008) | `procedures/phase4-coverage-dispatch.md` + agent-prompt.md | Đủ 10 lane: CD1 business-analyst+24 domain experts, CD2 architect+dba, CD3 architect+BA, CD4 api-tester+architect, CD5 architect+data-engineer, CD6 security+BA, CD7 dba+data-engineer, CD8 sre+devops, CD9 qa-lead+architect, CD10 tech-writer+BA. Tăng dim → defer v2, KHÔNG mở rộng inline |
| **G4** | Profile→lane activation matrix đúng | `phase1-init.md` Step F + `05-execution-profiles.md` | `quick=5 (CD1,2,3,4,7) ≥60%`, `standard=7 (+CD5,6,9) ≥80%`, `deep=10 ≥95%`, `exhaustive=10+LLM ≥100%`. Mismatch → CDG E091 auto-upgrade (vd `scope=system`+`profile=quick` → standard) |
| **G5** | 3-pass LLM Phase 3 (kế thừa QD11 — ADR-cmi-004) | `phase3-invariant-artifact.md` Steps C.1-C.3 | Pass 1 cross-module pattern comparison (deterministic), Pass 2 domain heuristic (24 experts parallel max 5), Pass 3 registry gap detection. Cross-domain conflict → CDG E093/E036 trước khi APPEND sidecar |
| **G6** | 10 lanes spawn parallel với CORE-025 (ADR-cmi-003) | `phase4-coverage-dispatch.md` Step C | Spawn qua `Agent({subagent_type, prompt})` ĐỒNG THỜI trong 1 message; max concurrency 10; per-lane timeout 3 min; per-lane retry x1 (max 1 retry/lane vs 3 retries/phase mặc định) |
| **G7** | Agent prompt 8-section CORE-037 cho mỗi lane | `agent-prompt.md` template | 10 lane prompts đều có: (1) Role declaration per CD, (2) Task instruction read SKILL.md, (3) Session context (SESSION_DIR, PROFILE, SCOPE), (4) CI context injection, (5) ~~Playwright~~ (N/A cho wf-cmi), (6) Output contract (signals.json path schema), (7) Ownership 1 file = 1 writer, (8) Completion criteria pass POST-GATE |
| **G8** | CDG self-healing v1 chỉ ĐỀ XUẤT (ADR-cmi-006) | `phase7-gap-cdg.md` Step D-E | Phase 7 spawn triage agent → suggestions per kind (test/invariant/contract/doc/validation). User ACCEPT (E094 sidecar APPEND) / REJECT / DEFER. **KHÔNG auto-apply** — mọi enforce chờ user qua CDG. `--dry-run` chỉ report đề xuất, không invoke write |
| **G9** | 6 CDG gates đầy đủ | Grep `E090-E099` trong `_contract.json.errors` | E090 coverage threshold (Phase 5), E090b buffer-flush (Phase 1), E091 scope×profile auto-upgrade (Phase 1), E093 cross-domain conflict (Phase 3 — alias E036), E094 sidecar APPEND ACCEPT/REJECT (Phase 7), E095 multi-user dual-approval (Phase 7 collab) |
| **G10** | Regression mode dual (predictive vs diff-aware) | `phase6-regression.md` Step C | Predictive: GitNexus `impact()` analysis nếu CI available; Diff-aware: `git diff --name-only $SINCE..HEAD` nếu `--since` set hoặc GitNexus absent. Skip nếu `profile=quick` HOẶC no `--since` HOẶC scope=feat (early-exit) |
| **G11** | 6 discovery graphs Phase 2 đầy đủ schema | Phase 2 POST-GATE T2 (`jq` schema) | Đủ 6 graphs: `entity-graph.json` (nodes=entities, edges=FK), `module-graph.json` (cross-module deps), `workflow-graph.json` (state transitions), `api-graph.json` (3-client endpoint routing), `event-graph.json` (RabbitMQ+SignalR), `rbac-matrix.json` (actor×action×resource). Mỗi graph có ≥1 node (E031 nếu rỗng) |
| **G12** | Coverage formula deterministic per dim | `phase5-aggregate.md` Step B | Formula: `coverage[CDi] = (covered_items[CDi] / total_items[CDi]) * 100`. Threshold check theo profile. E005 healthy early-exit nếu mọi dim ≥ threshold + 0 signals high severity. CDG E090 nếu < threshold |
| **G13** | Multi-session safety qua Protocol 22 (ADR-cmi-005) | `_shared.md` §R/W lock + `phase1-init.md` lock-daemon | Read-heavy phases (Phase 2 Discovery, Phase 6 Regression) dùng READ LOCK (cho phép N reader). Phase 3 APPEND sidecar + Phase 7 CDG dùng WRITE LOCK (exclusive). Lock heartbeat 30s, stale auto-release > 30 min. Lock PID-aware cho `--resume` cross-machine (Git pull) |

### 2.2 NHÓM CS — Cross-skill artifact contract (sidecar canonical + opt-in consumer flag)

`wf-cmi` có cross-skill contract đặc thù: 1 sidecar canonical APPEND-only + 1 cross-skill bundle `integrity-impact.json` cho 6 opt-in consumers.

| ID | Tiêu chuẩn | Phương pháp | PASS khi |
|----|------------|-------------|----------|
| **CS1** | Sidecar APPEND-only enforced (canonical) | `phase7-gap-cdg.md` CDG E094 logic | Mọi APPEND vào `.mc-data/work/wf-cmi/business-invariants.json` phải qua CDG E094 ACCEPT. KHÔNG có code path DELETE/UPDATE invariant entry — chỉ APPEND new + mark `deprecated=true` cho stale entries (soft-delete). audit_chain ghi `source_registry_checksum` để detect drift |
| **CS2** | Cross-skill artifact schema versioned (CORE-036) | `jq '.["$schema"]' integrity-impact.json` | `$schema == "integrity-impact-v1"` + `audit_chain.source == "wf-cmi"` + `audit_chain.checksum == sha256(...)`. Schema thay đổi → bump v2, giữ v1 file song song trong template để consumer validate version mismatch |
| **CS3** | 6 consumers opt-in qua `--from-cmi` flag | Grep `--from-cmi` trong consumer SKILL.md | `wf-fix-bugs`, `wf-verify-sync`, `wf-implement-feature`, `wf-prepare-deployment`, `wf-design`, `wf-add-scope` đều có handler `--from-cmi`. Nếu artifact absent/version mismatch → WARN graceful degradation (CORE-036), KHÔNG fail consumer skill |
| **CS4** | `produces_for{}` khớp 21-cross-skill-output-path-contract | Diff `_contract.json.cross_skill_contracts.produces_for` vs Protocol 21 §21.1 | 6 entries khớp 12 rows wf-cmi trong Protocol 21 (Phase 2-8 + canonical sidecar + integrity-impact + session/index). Path style: `.mc-data/work/wf-cmi/sessions/{YYYY-MM-DD-{scope}-{slug}-NN}/phase{N}-{name}/<file>` |
| **CS5** | `consumes_from{}` đủ 9 producers | `jq '.cross_skill_contracts.consumes_from | keys'` | 9 entries: `wf-brainstorm` (project context), `wf-analyze-requirements` (Phase 1 docs), `wf-define-features` (Phase 2 specs), `wf-design` (architecture), `wf-implement-feature` (impl-status), `wf-verify-sync` (verify-sync-impact opt `--from-verify-sync`), `wf-fix-bugs` (fix-impact opt `--from-fix-bugs`), `wf-legacy-scan` (project-context for LEGACY), `wf-e2e-finding` (cross-module-gaps.md if exists) |
| **CS6** | Session SSOT path duy nhất + index APPEND-only | `_contract.json.outputs` + `_shared.md` §session | SSOT = `$SESSION_DIR/integrity-status.json` (atomic write tmp→validate→mv). Index = `.mc-data/work/wf-cmi/_index/sessions.jsonl` APPEND-only (Git merge concatenate, không conflict) |
| **CS7** | Multi-user Git collaboration audit_chain | session-log.json + integrity-report.md schema | `session-log.json` ghi `author = git user.email + user.name` per session. `integrity-report.md` Section "Audit trail" trace ai chạm invariant nào, branch nào, commit nào. CDG E095 dual-approval khi 2 dev cùng touch 1 invariant |

### 2.3 Constraint đặc biệt

- **ADR-cmi-002 Revised — KHÔNG bump registry v3** — Toàn bộ business invariants đi vào sidecar `.mc-data/work/wf-cmi/business-invariants.json` (APPEND-only). `req-registry.json` v1/v2 unchanged. Tiêu chuẩn E15-E16 SKIP (NONE registry role). Reviewer KIỂM TRA: không có code path nào trong skill ghi `req-registry.json`.
- **Phase 3 file naming**: `phase3-invariant-artifact.md` (ĐỔI TÊN từ "registry" theo ADR-cmi-002 Revised — file có note đầu §A). Tránh nhầm lẫn với canonical registry.
- **24 domain experts spawn CHỈ trong CD1** (`phase4-coverage-dispatch.md` CD1 lane) — `business-analyst` chủ trì + 24 domain experts parallel max 5/wave (HR, Finance, Logistics, Healthcare, ... — tùy domain detect từ `req-registry.json.requirements[].domain`). KHÔNG spawn ngoài CD1.
- **Standalone — KHÔNG thuộc main pipeline** — `wf-cmi` cùng nhóm với `wf-scan-target`, `wf-diagram` (CLAUDE.md Standalone Skills table). Reviewer KIỂM TRA: KHÔNG có entry trong Standard/Existing/Hybrid Path flow.
- **CDG (Critical Decision Gate) trigger points (6 gates)** — E090 (coverage < threshold), E090b (buffer-flush), E091 (scope×profile auto-upgrade), E093/E036 (cross-domain invariant conflict), E094 (sidecar APPEND ACCEPT/REJECT), E095 (multi-user dual-approval). Mọi destructive/non-reversible action phải qua CDG (CORE-027).
- **5 LLM-driven sub-phases** — Phase 3 (3-pass inference), Phase 4 (10 lane agents), Phase 7 (triage agent). Mọi LLM output phải pass agent spot-check (CORE-029) trước khi đưa vào aggregator.
- **Concurrency limit hard-cap** — `max 10 agents/session` (CORE-025) + `max 5 session/máy` (quick/standard) hoặc `max 2 session/máy` (deep/exhaustive). Vượt limit → reject với gợi ý chạy tuần tự hoặc nâng profile.
- **`--ci` mode read-only** — KHÔNG update registry (đã NONE), KHÔNG ghi CDG decisions, KHÔNG APPEND sidecar. Output JSON post lên PR. `--ci` + `--auto-suggest` mutually exclusive (E012).

---

## 3. Quick-check đặc thù (bổ sung ngoài common §6)

- [ ] G1: `_contract.json.registry_scope.write_role == "NONE"` và `fields_owned == []`
- [ ] G2: `business-invariants.json` canonical path = `.mc-data/work/wf-cmi/business-invariants.json` (OUTSIDE sessions/)
- [ ] G3: 10 lanes CD1-CD10 đầy đủ trong `agent-prompt.md` + `phase4-coverage-dispatch.md`
- [ ] G4: Profile→lane activation matrix khớp `quick=5/standard=7/deep=10/exhaustive=10+LLM`
- [ ] G5: Phase 3 có Pass 1+2+3 (deterministic + domain heuristic + registry gap)
- [ ] G6: Phase 4 spawn 10 lanes ĐỒNG THỜI 1 message, max concurrency 10, retry x1/lane
- [ ] G8: CDG self-healing v1 KHÔNG auto-apply — chỉ ĐỀ XUẤT (E094 ACCEPT mới ghi)
- [ ] G9: 6 CDG gates đủ E090/E090b/E091/E093/E094/E095
- [ ] G11: Phase 2 produce đủ 6 graphs (entity/module/workflow/api/event/rbac)
- [ ] CS1: Sidecar canonical APPEND-only (không có code path DELETE/UPDATE invariant entry)
- [ ] CS2: `integrity-impact.json` có `$schema=="integrity-impact-v1"` + audit_chain
- [ ] CS3: 6 consumers có handler `--from-cmi` opt-in flag (grep trong consumer SKILL.md)
- [ ] CS5: 9 producers trong `consumes_from{}` khớp danh sách upstream skills
- [ ] E12: Protocol 22 R/W lock — 2 session đồng thời không corrupt (TC-cmi-005)
- [ ] E16: `registry_role: NONE` khớp `00-core.md §4a` (SKIP E15/E16 audit)
- [ ] I1-I5: 5 test cases TC-cmi-001..005 đầy đủ assertions + fixtures (`tests/fixtures/wf-cmi/`)

---

## 4. Reference

| File | Mục đích |
|------|----------|
| [`../04-skill-design/wf-cmi/`](../04-skill-design/wf-cmi/) | **Skill design canon (14 files + README)** — vision, arguments, phase routing, file contract, error codes, profiles, templates, procedures, ADRs, user scenarios, evals, agent-prompt |
| [SKILL.md](../../.claude/skills/workflow/wf-cmi/SKILL.md) | Lean routing hub 487 dòng (CORE-032) — Phase Routing Map, Output Files, Cross-Skill Contract |
| [_contract.json](../../.claude/skills/workflow/wf-cmi/_contract.json) | Schema `skill-contract-v1`, 15 inputs, 10 procedures, 37 outputs, 6 produces_for, 9 consumes_from, 108 errors |
| [procedures/_shared.md](../../.claude/skills/workflow/wf-cmi/procedures/_shared.md) | Cross-cutting protocols 20 sections — atomic write, error handlers, CI detection, R/W lock, agent prompts, audit chain |
| [procedures/phase*.md](../../.claude/skills/workflow/wf-cmi/procedures/) | 8 phase files + `resume-status.md` (lazy-load CORE-032) |
| [templates/](../../.claude/skills/workflow/wf-cmi/templates/) | 29 templates (16 JSON + 13 Markdown) — 6 graphs, sidecar, coverage-matrix, regression-map, integrity-impact, 8 Phase reports |
| [evals/evals.json](../../.claude/skills/workflow/wf-cmi/evals/evals.json) | 5 test cases TC-cmi-001..005 (31 assertions) + 4 fixtures trong `tests/fixtures/wf-cmi/` |
| [agent-prompt.md](../04-skill-design/wf-cmi/agent-prompt.md) | Template 8-section CORE-037 cho 10 lane agents + triage |
| [08-tradeoffs-adr.md](../04-skill-design/wf-cmi/08-tradeoffs-adr.md) | 8 ADRs decisions lớn (sidecar pattern, 10 lanes, 3-pass, multi-session lock, self-healing, cross-skill bundle, CD10 fixed) |
| [`_template-common.md`](./_template-common.md) | Tiêu chuẩn chung A/B/C/D/E/F/H/I/J |
| [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) | CORE — §4a NONE role, CORE-025 concurrency, CORE-027 CDG, CORE-030 session isolation, CORE-032 lazy-load, CORE-036 cross-skill artifact |
| [`.claude/skills/protocols/22-infrastructure-rw-lock.md`](../../.claude/skills/protocols/22-infrastructure-rw-lock.md) | R/W lock protocol multi-session |
| [`.claude/skills/protocols/21-cross-skill-output-path-contract.md`](../../.claude/skills/protocols/21-cross-skill-output-path-contract.md) | §21.1 — 12 rows wf-cmi paths |

---

## 5. Ghi chú bảo trì riêng file này

- Khi bump major (2.0…) → re-check G3 (CD lanes có thay đổi không — ADR-cmi-008 mở CD11+), G6 (concurrency limit có thay đổi qua CORE-025 update), G13 (Protocol 22 spec).
- Khi sidecar schema `business-invariants-v1` bump v2 → cập nhật CS2 + audit toàn bộ 6 consumers có handle version mismatch graceful không.
- Khi thêm CD11+ (lane mới) → cập nhật G3 + G4 (lane activation matrix theo profile) + agent-prompt.md template.
- Khi thêm consumer thứ 7 (skill mới có `--from-cmi`) → cập nhật `contracts.consumers_count` + CS3 quick-check + Protocol 21 §21.1.
- Khi thêm producer thứ 10 (upstream input) → cập nhật `contracts.producers_count` + CS5.
- Khi CDG gate mới (E096+) thêm vào Phase 7 → cập nhật G9 + §2.3 Constraint CDG list.
- Khi 24 domain experts mở rộng → cập nhật §2.3 "24 domain experts" (ADR-cmi-008 reference).
- Khi profile thứ 5 (vd `audit`) được bổ sung → cập nhật G4 lane activation matrix.
- File này là **read-only** trong quá trình review — findings ghi vào `reports/YYYY-MM-DD-wf-cmi.md`.
