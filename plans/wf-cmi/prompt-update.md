# Session Re-Entry Prompt — wf-cmi v2.0 Expansion (Gói C++ Logistics)

> **Mục đích:** Prompt khởi động cho session Claude Code mới để triển khai **mở rộng wf-cmi từ v1.0.0 (10 lanes) → v2.0.0 (26 lanes Gói C++)**. Đọc file này NGAY khi bắt đầu session.
>
> **Khác với `session-prompt.md`:** File đó dành cho v1.0.0 implementation (đã hoàn thành). File này dành cho v2.0 expansion (NEW work).

---

## Khởi động session mới — Copy paste prompt sau

```
Tôi đang triển khai mở rộng skill `wf-cmi` từ v1.0.0 → v2.0.0 (Gói C++ Logistics, 26 lanes).
v1.0.0 đã ship với 10 lanes CD1-CD10. v2.0 thêm 16 lanes mới.

Đọc các tài liệu sau theo thứ tự trước khi bắt đầu code:

1. plans/wf-cmi/prompt-update.md (file này — context v2.0 expansion)
2. plans/wf-cmi/progress-update.md (tracking 9 stages)
3. plans/wf-cmi/ui-interactivity-spec.eureka-template.json (CD38 SSOT template)
4. plans/wf-cmi/session-prompt.md (v1.0 context — đã DONE, đọc reference)
5. plans/wf-cmi/progress.md (v1.0 progress — đã DONE)
6. .claude/skills/workflow/wf-cmi/SKILL.md (current v1.0 state)
7. .claude/skills/workflow/wf-cmi/_contract.json (current v1.0 contract)
8. docs/04-skill-design/wf-cmi/05-execution-profiles.md (profile activation)

Sau đó, đọc các file design canon liên quan tới task hiện tại.

Quy tắc bắt buộc:
- Tuân thủ CLAUDE.md (BHV-001 đến BHV-004 + CORE-001 đến CORE-038)
- KHÔNG break v1.0 backward compat — schema bump v1 → v2 phải có migration notes
- SKILL.md vẫn ≤500 dòng (CORE-032 lazy-load) — dùng procedure files
- Mọi lane mới CHỈ tạo qua template pattern (CORE-031): READ template → POPULATE → WRITE
- 26 lanes dispatch theo 3-wave strategy (max 10 parallel/wave)
- Cross-skill artifact integrity-impact.json bump schema v1 → v2 (backward-compat read v1)
- Mọi agent prompt PHẢI có 8 sections (CORE-037)

Bước tiếp theo: xem progress-update.md mục "Next Step" — bắt đầu Stage 1 Foundation Refactor.
```

---

## Tóm tắt Quyết Định Scope (8 Round Discussion)

### Final scope: Gói C++ Logistics — 26 lanes

```
GÓI C BASE (23 lanes — đã thống nhất trong session design):
├── Core 8:        CD1, CD2, CD3, CD4, CD5, CD6, CD7, CD9
├── Frontend 3:    CD11, CD13, CD15
├── Backend 3:     CD16, CD17, CD18
├── UX 4:          CD23, CD24, CD25, CD26
├── Logistics 3:   CD28, CD30, CD31   ★★★
└── Compliance 2:  CD29, CD37          ★★★

ADDITIONS (3 lanes — phát hiện gap trong cuối session):
├── CD38 UI Implementation Coverage   ★ NEW (đặc biệt cần thiết)
├── CD39 Error UX & Recovery          ★ NEW
└── CD40 Print & Export Consistency   ★ NEW (logistics document-heavy)

TỔNG: 26 lanes
```

### Đã thống nhất BỎ (transparency):
- **Security Deep** (CD20) — user không cần security trong scope hiện tại
- **Performance probes** — không cần performance trong scope hiện tại
- **CD8 Observability full** — chỉ giữ phần log correlation
- **CD10 Documentation** — đắt, để v2.1
- **CD12, CD14, CD19, CD21, CD22, CD27** — deferred v2.1+
- **CD32-CD36** (Document/Notification/Search/MultiTenant/Operational) — tách thành skill riêng v3+
- **CD42 Carrier Integration** — defer v2.1 (logistics-critical nhưng effort cao, cần focus 26 lanes trước)

---

## Context Cốt Lõi

### Project context
- **Repository:** D:\MCV3 (MCV3 framework)
- **Target ban đầu:** EUREKA-2026 ERP (D:\EUREKA-2026)
  - 17 modules .NET 10 + Next.js 16 + PostgreSQL 16
  - 3 clients: erp-web + mobile-customer + mobile-staff
  - DDD + CQRS (MediatR), 90+ RBAC permissions, 4 SignalR hubs, RabbitMQ
  - Logistics Việt-Trung, multi-currency VND/CNY/USD, multi-language VN/CN/EN

### Skill identity (giữ nguyên từ v1.0)
- **Tên:** `wf-cmi` (Cross-Module Integrity)
- **Loại:** Standalone Orchestrator skill
- **Slash command:** `/wf-cmi`
- **Path:** `.claude/skills/workflow/wf-cmi/`
- **Version bump:** 1.0.0 → 2.0.0

### Architecture preserved (8 ADRs giữ nguyên)
1. **ADR-cmi-001:** Standalone, KHÔNG phải lane QD12 trong wf-fix-bugs
2. **ADR-cmi-002 Revised:** Sidecar artifact, KHÔNG bump registry v3
3. **ADR-cmi-003:** 3-pass LLM inference
4. **ADR-cmi-004:** Dynamic profile activation
5. **ADR-cmi-005:** Cross-skill artifact `integrity-impact.json`
6. **ADR-cmi-006:** Protocol 22 R/W lock cho multi-session
7. **ADR-cmi-007:** Audit chain checksum
8. **ADR-cmi-008:** 8-phase pipeline (Init→Discovery→Invariant→Coverage→Aggregate→Regression→GAP→Report)

### What changes in v2.0
| Aspect | v1.0 | v2.0 |
|---|---|---|
| Lanes | 10 (CD1-CD10) | 26 (CD1-CD7, CD9, CD11-CD18, CD23-CD31, CD37-CD40) |
| Phase 2 graphs | 6 | 13 (6 core + 7 plugin) |
| SSOT files | 2-3 | 9 |
| Wave dispatch | 1-2 wave | 3 wave |
| Coverage matrix dims | 10 | 26 (kể cả SKIPPED markers) |
| Threshold (deep) | ≥95% | ≥95% (giữ) |
| Time estimate (deep) | 30-60 min | 55-90 min |
| Cross-skill artifact schema | `integrity-impact-v1` | `integrity-impact-v2` |
| Backward compat | — | Read v1 artifacts được, ghi v2 |

---

## 18 New Lanes — Quick Reference

| Lane | Tên | Effort | Group |
|---|---|---|---|
| CD11 | FE Component Contracts | 2d | FE |
| CD13 | FE↔BE Contract Sync | 3d | FE |
| CD15 | UI Permission Mirror | 2d | FE |
| CD16 | Domain Logic Integrity | 4d | BE |
| CD17 | Persistence Consistency | 4d | BE |
| CD18 | CQRS Pipeline Integrity | 3d | BE |
| CD23 | UX Design System | 2d | UX |
| CD24 | UX Display Format | 2d | UX |
| CD25 | UX Flow Continuity | 3d | UX |
| CD26 | UX Workflow Visibility | 4d | UX |
| CD28 | MDM Consistency ★★★ | 5d | Logistics |
| CD29 | Audit Trail | 3d | Compliance |
| CD30 | Time & Numbering ★★★ | 4d | Logistics |
| CD31 | Money & Tax ★★★ | 4d | Logistics |
| CD37 | Regulatory Compliance ★★★ | 5d | Compliance |
| **CD38** | **UI Implementation Coverage ★** | 3d | Implementation |
| **CD39** | **Error UX & Recovery ★** | 3d | UX-Quality |
| **CD40** | **Print & Export Consistency ★** | 4d | UX-Quality |

**Total:** ~60 days dev effort.

---

## 9 SSOT Files cần Define (cho EUREKA)

| File | Status | Cho lane(s) |
|---|---|---|
| **ui-interactivity-spec.json** | ✅ **Template ready** (xem `plans/wf-cmi/ui-interactivity-spec.eureka-template.json`) | CD38 |
| ux-conventions.json | ⚠ Cần tạo | CD23, CD24, CD25, CD26 |
| mdm-canonical-entities.json | ⚠ Cần tạo | CD28 |
| compliance-mapping.json | ⚠ Cần tạo | CD37 |
| rbac-permission-catalog.json | ⚠ Cần tạo | CD15 |
| workflow-state-machines.json | ⚠ Cần tạo | CD26, CD38 |
| audit-critical-entities.json | ⚠ Cần tạo | CD29 |
| error-code-catalog.json | ⚠ Cần tạo | CD39 |
| print-export-templates.json | ⚠ Cần tạo | CD40 |

**Vị trí runtime:** `.mc-data/docs/_meta/` (EUREKA project)

---

## 7 New Graphs cần Build (Phase 2)

| Graph | Cho lane(s) | Source detect |
|---|---|---|
| `fe-component-graph.json` | CD11 | Glob `apps/erp-web/components/**/*.tsx` + AST props |
| `fe-api-client-graph.json` | CD13, CD38 | Grep `useQuery\|useMutation\|fetch\|axios` + Refit |
| `fe-permission-graph.json` | CD15, CD38 | Grep `<PermissionGate>\|usePermission` |
| `fe-route-graph.json` | CD25, CD38 | Glob `app/**/page.tsx,layout.tsx,middleware.ts` |
| `be-db-schema-graph.json` | CD17 | Parse EF Migrations + DB schema reverse-engineer |
| `be-domain-graph.json` | CD16 | Serena `find_symbol` + Grep DDD patterns |
| `be-cqrs-graph.json` | CD18 | Grep MediatR patterns + IPipelineBehavior |

---

## 3-Wave Dispatch Strategy (26 lanes)

```
═══════════════════════════════════════════════════════
WAVE 1 (10 parallel, ~10-12 min) — Graphs only:
├── CD1  Business domain
├── CD2  Entity dependency
├── CD3  Workflow coverage
├── CD4  API contract
├── CD5  Event coverage
├── CD6  Permission/RBAC
├── CD7  Data integrity
├── CD11 FE Component Contracts
├── CD16 Domain Logic Integrity
└── CD17 Persistence Consistency

═══════════════════════════════════════════════════════
WAVE 2 (10 parallel, ~12-15 min) — Cross-layer:
├── CD13 FE↔BE Contract Sync
├── CD15 UI Permission Mirror
├── CD18 CQRS Pipeline Integrity
├── CD23 UX Design System
├── CD24 UX Display Format
├── CD25 UX Flow Continuity
├── CD28 MDM Consistency ★★★
├── CD30 Time & Numbering ★★★
├── CD31 Money & Tax ★★★
└── CD37 Regulatory Compliance ★★★

═══════════════════════════════════════════════════════
WAVE 3 (6 parallel, ~8-10 min) — Final cross-ref:
├── CD9  Regression coverage
├── CD26 UX Workflow Visibility
├── CD29 Audit Trail Completeness
├── CD38 UI Implementation Coverage  ★ NEW
├── CD39 Error UX & Recovery         ★ NEW
└── CD40 Print & Export Consistency  ★ NEW

═══════════════════════════════════════════════════════
Tổng Phase 4: ~30-37 min cho EUREKA 17 modules
Tổng pipeline: ~55-90 min profile deep
```

---

## Quy Tắc Bắt Buộc Khi Code v2.0

### 1. Tuân thủ CLAUDE.md
- BHV-001 đến BHV-004 (behavioral principles)
- CORE-001 đến CORE-038 (core rules)
- Đặc biệt:
  - CORE-031: Template Usage Rule (READ → POPULATE → WRITE)
  - CORE-032: Lean SKILL.md ≤500 dòng
  - CORE-035: Phase output organization
  - CORE-036: Cross-skill artifact contract
  - CORE-037: Agent prompt 8 sections

### 2. Backward Compatibility
- Schema bump `v1 → v2` cho:
  - `integrity-status.json` (thêm field `lanes_active_v2`)
  - `coverage-matrix.json` (handle 26 dims)
  - `integrity-impact.json` (bump consumer contract)
- Consumer skills (wf-verify-sync, wf-fix-bugs, wf-implement-feature, wf-prepare-deployment) PHẢI read v1 OR v2

### 3. Profile Activation
- Giữ `quick` / `standard` / `deep` / `exhaustive` profile names
- v2 expand `deep` profile từ 10 → 26 lanes
- Hoặc tạo profile mới `c-plus-plus` (quyết định trong Stage 1)
- `--dims=CD11,CD13` flag vẫn work — chỉ activate subset

### 4. Multi-Session Safety (Protocol 22)
- Tất cả new lanes phải respect R/W lock cho sidecar
- 26 lanes parallel KHÔNG được ghi cùng file
- Session lock + heartbeat giữ nguyên

### 5. Critical Decision Gate (CORE-027)
- CDG E090 threshold breach
- CDG E094 sidecar APPEND
- CDG E095 multi-user dual-approval
- Thêm CDG cho new lanes:
  - CDG cho CD37 Compliance violation (phải user ACCEPT trước khi enforce)
  - CDG cho CD38 UI orphan (phải user ACCEPT trước khi mark deprecated)

### 6. Error Handling (CORE-034)
- Extend namespace error codes:
  - E110-E119: CD11-CD18 lanes (FE+BE plugin)
  - E120-E129: CD23-CD27 lanes (UX)
  - E130-E139: CD28-CD37 lanes (Logistics + Compliance)
  - E140-E149: CD38-CD40 lanes (NEW additions)

### 7. Documentation
- Mọi procedure file mới có 8 sections: §A Header, §B PRE-GATE, §C Steps, §D POST-GATE, §E Error Handling, §F Phase Report, §G Output Path Contract, §H Resume Logic
- Template files có `_template_notes` strip before write
- Schema files có `$schema` field

---

## Files cần touch trong v2.0

### MODIFY (existing files)
- `.claude/skills/workflow/wf-cmi/SKILL.md` (version bump + lane table expand)
- `.claude/skills/workflow/wf-cmi/_contract.json` (add lanes_defined[] + profile_activation)
- `.claude/skills/workflow/wf-cmi/procedures/phase2-discovery.md` (add 7 graph builders)
- `.claude/skills/workflow/wf-cmi/procedures/phase4-coverage-dispatch.md` (3-wave strategy)
- `.claude/skills/workflow/wf-cmi/procedures/phase5-aggregate.md` (handle 26 dims)
- `.claude/skills/workflow/wf-cmi/procedures/phase8-report.md` (26-dim report)
- `.claude/skills/workflow/wf-cmi/templates/coverage-matrix.json` (schema v2)
- `.claude/skills/workflow/wf-cmi/templates/integrity-status.json` (schema v2)
- `.claude/skills/workflow/wf-cmi/templates/integrity-impact.json` (schema v2)
- `.claude/skills/workflow/wf-cmi/templates/integrity-report.md` (26-dim layout)
- `.claude/skills/workflow/wf-cmi/evals/evals.json` (add 8 test cases)
- `CHANGELOG.md` (v2.0 entry)
- `CLAUDE.md` (wf-cmi entry refresh)

### CREATE (new files)
- `.claude/skills/workflow/wf-cmi/procedures/lanes/CD{11,13,15-18,23-31,37-40}.md` (18 lane procedures)
- `.claude/skills/workflow/wf-cmi/templates/{7-new-graphs}.json` (7 templates)
- `.claude/skills/workflow/wf-cmi/templates/lane-{CD11..CD40}.json` (lane-specific templates)
- `docs/06-user-guides/per-skill/wf-cmi-v2-guide.md`
- `docs/04-skill-design/wf-cmi/v2-migration-notes.md`

---

## Sai Lầm Cần Tránh

### ⚠ KHÔNG được làm
1. **KHÔNG break v1 backward compat** — consumer skills phải read được v1 artifacts
2. **KHÔNG inline bash trong SKILL.md** — delegate sang procedure files (CORE-032)
3. **KHÔNG ghi 2 agent cùng 1 file** — 1 file = 1 writer (CORE-037)
4. **KHÔNG bump registry schema v3** — vẫn dùng sidecar pattern (ADR-cmi-002 Revised)
5. **KHÔNG hardcode paths** — dùng canonical paths từ `_contract.json`
6. **KHÔNG skip CDG cho enforce actions** — user phải ACCEPT trước khi enforce
7. **KHÔNG nâng max concurrency > 10** — giữ 3-wave dispatch
8. **KHÔNG create file mới khi có existing** — Edit thay vì Write

### ✅ Cần làm
1. **Template-first approach** — mọi output từ template, không ad-hoc
2. **Schema versioned** — mọi JSON output có `$schema` field
3. **Audit chain checksum** — track upstream source state
4. **Vietnamese-first reports** — Phase report ≤15 dòng tiếng Việt
5. **Atomic write** — `.tmp.$$` → validate → mv
6. **Graceful degradation** — CI tool missing → fallback Grep, không fail
7. **Test-driven** — Stage 8 eval ≥7/8 pass trước merge

---

## Câu Hỏi Cần User Trả Lời Trước Stage 1

1. **Profile naming:**
   - Option A: Expand `deep` profile thành 26 lanes (đơn giản, breaking)
   - Option B: Tạo profile mới `c-plus-plus` riêng (preserve `deep` cho v1, không breaking)
   - **Khuyến nghị:** Option B để backward-compat

2. **CD32-CD36 vertical lanes:**
   - Tách thành 5 skill riêng (`wf-doc-lifecycle-audit`, `wf-notification-audit`, etc.) — clean separation
   - Hoặc merge dần vào wf-cmi v3 sau này
   - **Khuyến nghị:** Tách riêng để tránh wf-cmi phình to

3. **EUREKA mobile apps:**
   - Có cần scan `mobile-customer` và `mobile-staff` cho fe-route-graph không?
   - Hay chỉ scan `erp-web` ở v2, mobile để v2.1?

4. **Domain expert agents:**
   - Cần verify: `compliance-expert`, `legal-expert`, `finance-expert`, `logistics-expert`, `ux-researcher`, `brand-guardian`, `ui-designer`, `dba`, `sre` đã có procedure files chưa?
   - Nếu thiếu agent → cần tạo trước Stage 4

5. **Timeline expectation:**
   - 9 tuần ship hard deadline? Hay flexible?
   - Có team mới tham gia không? (Effort 60 ngày dev needs parallel)

---

## Next Step Cho Session Tiếp Theo

**Phase Init (15 phút đầu):**
1. Đọc `prompt-update.md` + `progress-update.md`
2. Check trạng thái wf-cmi v1.0:
   - `cat .claude/skills/workflow/wf-cmi/SKILL.md | head -50`
   - `jq '.version' .claude/skills/workflow/wf-cmi/_contract.json`
3. Verify EUREKA target structure available

**Bắt đầu Stage 1 — Foundation Refactor (Tuần 1):**
1. Plan với TodoWrite (12 task con cho Stage 1)
2. Update `_contract.json` — bump version + add `lanes_v2[]`
3. Bump SKILL.md → 2.0 + expand lane table
4. Update 5 template files (integrity-status, coverage-matrix, integrity-impact, integrity-report, contract schemas)
5. Update 2 procedure files (phase4-coverage-dispatch, phase5-aggregate)
6. Validate audit scripts pass

**Stage 1 Gate:**
- [ ] All 7 modified files atomic write OK
- [ ] `bash .claude/scripts/skill-compliance-audit.sh wf-cmi` PASS
- [ ] `bash .claude/scripts/validate-schema-sync.sh wf-cmi` PASS
- [ ] SKILL.md vẫn ≤500 dòng
- [ ] _contract.json valid JSON + lanes_v2[] có 26 entries

→ Sau Stage 1 PASS, chuyển sang Stage 2 (Graphs) + Stage 3 (SSOT) song song.

---

## Communication

- **Session log:** Update `progress-update.md` mỗi khi hoàn thành 1 task con
- **Blocker escalation:** Note ngay trong `progress-update.md` mục "Risk Assessment"
- **Stakeholder ping:** Khi cần input cho SSOT files

---

## References

| File | Purpose |
|---|---|
| `plans/wf-cmi/wf-cmi.md` | Plan gốc từ user |
| `plans/wf-cmi/session-prompt.md` | v1.0 session prompt (đã DONE, reference) |
| `plans/wf-cmi/progress.md` | v1.0 progress (đã DONE) |
| **`plans/wf-cmi/prompt-update.md`** | **File này — v2.0 session prompt** |
| **`plans/wf-cmi/progress-update.md`** | **v2.0 progress tracking** |
| **`plans/wf-cmi/ui-interactivity-spec.eureka-template.json`** | **CD38 SSOT template** |
| `docs/04-skill-design/wf-cmi/README.md` | Design canon index |
| `docs/04-skill-design/wf-cmi/00-master-checklist.md` | Gating 10-step |
| `docs/04-skill-design/wf-cmi/05-execution-profiles.md` | Profile activation |
| `docs/04-skill-design/wf-cmi/08-tradeoffs-adr.md` | 8 ADRs |
| `.claude/skills/workflow/wf-cmi/SKILL.md` | Current v1.0 state |
| `.claude/rules/00-core.md` | CORE-001 → CORE-038 rules |
| `.claude/rules/00-behavioral.md` | BHV-001 → BHV-004 principles |

---

## Versioning

- **wf-cmi v1.0.0** — Released 2026-05-16 (10 lanes CD1-CD10)
- **wf-cmi v2.0.0** — Target release sau 9 tuần (26 lanes Gói C++ Logistics)
- **wf-cmi v2.1.0** — Future (add CD42 Carrier Integration + reactivate CD12, CD14, CD22)
- **wf-cmi v3.0.0** — Future (decide on integrating CD32-CD36 hoặc tách skill)
