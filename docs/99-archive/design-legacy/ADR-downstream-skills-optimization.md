# ADR — Tối ưu 5 Workflow Skills Downstream

> **Kỹ thuật nguồn:** wf-legacy-scan v5.0 + wf-fix-bugs v6
> **Kỹ thuật đích:** wf-brainstorm, wf-analyze-requirements, wf-define-features, wf-design, wf-design-ux
> **Ngày tạo:** 2026-04-23
> **Trạng thái:** Proposed
> **Owner:** Vu Minh Tu

---

## 0. Context & Motivation

wf-legacy-scan v5.0 và wf-fix-bugs v6 là hai skill được thiết kế lại toàn diện với nhiều kỹ thuật nâng cao:
- **wf-legacy-scan v5.0:** session isolation, IPS 2-phase recommender, 4-level checkpoint, profile system (4 profiles), incremental scanning + 2-tier cache, dual-path observability, dependency graph, error ledger + retry.
- **wf-fix-bugs v6:** pure orchestrator pattern, ISG signal analysis, 7 parallel dimension lanes (QD1-QD7), partition planner + workload gate, signal aggregator + dedup bus, CDG handoff tokens, verify loop state machine (max 3 iter), fix-log append pattern.

5 workflow skills downstream (brainstorm → analyze-req → define-features → design → design-ux) đang **thiếu phần lớn các kỹ thuật này**, dẫn đến:

1. **Chậm hơn cần thiết** — phases có thể song song vẫn chạy tuần tự; không có workload gate để early-warning.
2. **Ít chính xác hơn** — không có signal dedup boundary → REQ-ID/FEAT-ID trùng lặp giữa các lanes.
3. **Resume thô** — checkpoint chỉ phase-level; batch-level resume không có.
4. **Không incremental** — mỗi lần chạy lại tính lại toàn bộ, kể cả khi upstream chỉ thay đổi nhỏ.

**Mục tiêu:** Import 10 kỹ thuật được chọn lọc (P0: 5, P1: 5) vào 5 skills, theo lộ trình 4 bước, với hạ tầng chung `_shared/` làm tiên quyết.

---

## 1. ADR Index (10 ADRs)

| ID | Quyết định | Priority | Áp dụng |
|----|-----------|----------|---------|
| ADR-OPT-01 | Lane Dispatch song song + write-scope isolation + token bucket | P0 | 5 skills |
| ADR-OPT-02 | Session Isolation `sessions/{id}/` + multi-level checkpoint | P0 | analyze-req, define-features, design, design-ux |
| ADR-OPT-03 | Partition Planner + Workload Gate | P0 | analyze-req, define-features, design, design-ux |
| ADR-OPT-04 | Signal Aggregator + Dedup boundary | P0 | analyze-req, define-features, design, design-ux |
| ADR-OPT-05 | Template stripping `_template_notes` + Atomic Write cho digests | P0 | 5 skills |
| ADR-OPT-06 | Profile System 3 cấp (quick/standard/deep) | P1 | analyze-req, define-features, design-ux |
| ADR-OPT-07 | ISG-style Intent Signal Analysis (profile recommendation) | P1 | analyze-req, design-ux |
| ADR-OPT-08 | CDG Handoff Tokens tại điểm critical | P1 | 5 skills (điểm khác nhau) |
| ADR-OPT-09 | Incremental + Cache (content-hash key, 2-tier) | P1 | analyze-req, define-features, design, design-ux |
| ADR-OPT-10 | CORE-028 Phase-Summary formal hóa (fix define-features MISSING) | P1 | define-features (MISSING), analyze-req (implicit) |

**Điều kiện tiên quyết (P0-PREREQ):** Tạo `.claude/skills/workflow/_shared/` chứa code/template dùng chung.

---

## 2. Điều kiện tiên quyết — P0-PREREQ: Hạ tầng dùng chung `_shared/`

### Quyết định

Tạo `.claude/skills/workflow/_shared/` chứa các module Python, template, và protocol file được trích xuất từ wf-legacy-scan và wf-fix-bugs. Mọi skill downstream import từ đây — không copy nội bộ.

### Cấu trúc

```
.claude/skills/workflow/_shared/
├── concurrency/
│   ├── token_bucket.py         ← Từ wf-legacy-scan (ADR-LS12)
│   ├── backpressure.py         ← Từ wf-legacy-scan
│   └── lane_dispatch.py        ← Từ wf-fix-bugs (asyncio semaphore, max_parallel)
├── partition/
│   ├── partition_planner.py    ← Từ wf-fix-bugs (group workloads)
│   └── workload_gate.md        ← Procedure file (gate threshold logic)
├── profiles/
│   ├── profile_resolver.py     ← Từ wf-fix-bugs (resolve + safety floor)
│   └── profiles.json           ← Template: quick/standard/deep definitions
├── aggregate/
│   └── signal_aggregator.py    ← Từ wf-fix-bugs (SignalBus dedup)
├── cdg/
│   └── cdg-handoff.md          ← Protocol 16 adapted cho linear skills
├── cache/
│   ├── content_cache.py        ← Từ wf-legacy-scan (content-addressable, TTL)
│   └── cache_types.md          ← 2-tier: session + project
├── templates/
│   ├── phase-summary.md        ← CORE-028 template (append-only)
│   ├── session-state.json      ← Session isolation state schema
│   └── workload-report.md      ← Workload gate output template
├── ips/                        ← Tái sử dụng từ wf-legacy-scan (đã tồn tại)
│   ├── ips_recommender.py
│   ├── domain_scorer.py
│   └── ...
├── isg/                        ← Tái sử dụng từ wf-fix-bugs (đã tồn tại)
│   ├── isg_recommender.py
│   ├── profile_resolver.py
│   └── ...
└── _shared.md                  ← Protocol strip _template_notes + atomic write
```

### Alternatives considered

1. **Copy code vào mỗi skill** → drift nhanh, 5× maintenance. Loại.
2. **Tạo npm/pip package riêng** → over-engineering cho internal tooling. Loại.
3. **Để code trong wf-legacy-scan và import cross-skill** → coupling cứng, thay đổi legacy-scan phá các skill khác. Loại.

### Consequences

- (+) 1 nguồn duy nhất cho partition/cache/profile logic
- (+) Sửa 1 lần, hưởng tất cả skills
- (+) Unit-testable (Python modules)
- (-) Thêm dependency: mọi skill phải reference `_shared/` path
- (-) Cần convention chuẩn cho import path (relative từ SKILL.md)

---

## 3. ADR Details

### ADR-OPT-01: Lane Dispatch Song Song + Write-Scope Isolation + Token Bucket

**Nguồn:** wf-fix-bugs v6 `lane_dispatch.py` (asyncio, max_parallel=3) + wf-legacy-scan v5.0 ADR-LS12 (token bucket)

**Context:** Tất cả 5 skills đều có phase "spawn experts" nhưng chạy không formal — không có concurrency control, không có write-scope isolation, không có backpressure khi spawn quá nhiều agents.

**Decision:** Formal hóa lane dispatch pattern:

1. Mỗi phase "spawn experts" chia work thành **lanes** theo key ngữ nghĩa:
   - brainstorm Phase 3: lanes theo **role** (ux-expert, ba, architect, security, domain)
   - analyze-req Phase 4: lanes theo **department/domain**
   - define-features Phase 2: lanes theo **feature-group** (system-based grouping)
   - design Phase 2: lanes theo **spec-type** (api-contract, db-design, infra-spec)
   - design-ux Phase 3: lanes theo **system**

2. Mỗi lane viết vào isolated dir: `lanes/{KEY}/signals.json`

3. Concurrency: `max_parallel=3` (semaphore), token bucket backpressure, per-agent timeout 300s

4. Ownership: mỗi lane có đúng 1 agent writer → không lock contention (CORE-025)

**Alternatives considered:**
1. **Spawn tất cả agents không giới hạn** → context overflow, API rate limit. Loại.
2. **Sequential từng agent** → mất lợi thế song song. Loại.
3. **max_parallel=5+** → quá nhiều concurrent agents cho Claude API. Loại.

**Mapping skill → lanes:**

| Skill | Phase | Lane Key | Max Parallel | Agent Type |
|-------|-------|----------|-------------|------------|
| brainstorm | P3 | role | 3 | Mixed (ux-expert, ba, architect...) |
| analyze-req | P4 | department | 3 | domain-expert per dept |
| define-features | P2 | system | 3 | ba per system |
| design | P2 | spec-type | 3 | architect, developer, dba |
| design-ux | P3 | system | 3 | ux-designer per system |

**Consequences:**
- (+) Wall-time giảm 40-60% cho phases có thể song song
- (+) Write-scope isolation → không conflict
- (+) Token bucket → predictable resource usage
- (-) Complexity tăng: cần lane output schema + aggregation step sau
- (-) Agent timeout cần tune per skill (brainstorm nhẹ hơn design-ux)

---

### ADR-OPT-02: Session Isolation `sessions/{id}/` + Multi-level Checkpoint

**Nguồn:** wf-legacy-scan v5.0 ADR-LS05 (session isolation) + ADR-LS11 (4-level checkpoint)

**Context:**
- 4 skills (analyze-req, define-features, design, design-ux) dùng fixed working dir `.mc-data/work/{skill}/` — chạy lại ghi đè session cũ.
- Checkpoint chỉ phase-level — resume phải chạy lại toàn bộ phase, kể cả khi chỉ fail ở batch cuối.
- wf-design và wf-design-ux có LPM (Large Project Mode) auto-detect nhưng checkpoint thô, không batch-level.

**Decision:**

1. **Session isolation:** Mỗi run tạo session dir `sessions/{YYYYMMDD-HHMMSS}-{hash}/`:
   ```
   .mc-data/work/{skill}/
   ├── sessions/
   │   ├── 20260423-103000-a1b2c3/    ← Run 1
   │   │   ├── session-state.json     ← State machine
   │   │   ├── lanes/                 ← Lane outputs
   │   │   ├── checkpoints/           ← Per-phase checkpoints
   │   │   ├── phase-summary.md       ← CORE-028 append-only
   │   │   └── ...
   │   └── 20260423-140000-d4e5f6/    ← Run 2
   └── latest → symlink to latest session
   ```

2. **Multi-level checkpoint** (3 levels đủ cho linear skills — không cần 4 như legacy-scan):
   - **L1 Phase-level:** `session-state.json phases.P{N}.status`
   - **L2 Batch-level:** `session-state.json phases.P{N}.batches[{K}].status`
   - **L3 Item-level:** `session-state.json phases.P{N}.batches[{K}].items[{I}].status` (optional, chỉ cho phases nặng)

3. **Resume routing:** `--resume` đọc `session-state.json → next_action` → dispatch đúng phase+batch+item

4. **brainstorm:** Skill ngắn, chỉ cần L1 phase-level checkpoint. Không cần session isolation (single-run đủ).

**Alternatives considered:**
1. **4-level checkpoint như legacy-scan** → quá chi tiết cho linear skills. 3 levels đủ.
2. **Không đổi — giữ fixed dir** → multi-run unsafe, không traceable. Loại.
3. **Database (SQLite) thay JSON** → over-engineering. Loại.

**Checkpoint depth per skill:**

| Skill | Levels | L1 (phase) | L2 (batch) | L3 (item) |
|-------|--------|-----------|-----------|-----------|
| brainstorm | 1 | ✅ | — | — |
| analyze-req | 3 | ✅ | ✅ dept-batch | ✅ req-item (optional) |
| define-features | 3 | ✅ | ✅ feature-group | — |
| design | 3 | ✅ | ✅ system-batch | ✅ spec-section (optional) |
| design-ux | 3 | ✅ | ✅ system-batch | ✅ screen-item (optional) |

**Consequences:**
- (+) Multi-run safe — không ghi đè session cũ
- (+) Resume chính xác đến batch/item → tiết kiệm thời gian retry
- (+) Audit trail: mọi session persisted, user so sánh được
- (-) Storage tăng nhẹ (session dirs). Mitigate: cleanup policy giữ 5 sessions mới nhất
- (-) Complexity: session-state.json schema cần maintain
- (-) Downstream consumers cần resolve `latest` symlink thay vì fixed path

---

### ADR-OPT-03: Partition Planner + Workload Gate

**Nguồn:** wf-fix-bugs v6 `partition_planner.py` + `workload-gate.md`

**Context:** 4 skills có phases "nặng" mà user không biết trước sẽ mất bao lâu. Không có estimate → user chỉ phát hiện quá trễ khi context cạn.

**Decision:**

1. **Partition Planner** chạy ở Phase 0 (PRE-GATE), ước tính workload:
   - Input: registry data (systems count, features count, departments count) + upstream digest metadata
   - Output: `workload-estimate.json` với breakdown theo lane/batch
   - Estimate heuristic: `EST_MINUTES = items_count × avg_time_per_item × complexity_factor`

2. **Workload Gate** ở Phase 0.5 (sau estimate, trước execute):
   ```
   ratio = estimated_total_sec / gate_threshold_sec

   if ratio < 0.8 → dead_zone (silent continue)
   if 0.8 ≤ ratio ≤ 1.5 → WARN (hiển thị estimate, hỏi continue)
   if ratio > 1.5 → BLOCK (Plan A/B menu)
   ```

3. **Gate thresholds per skill:**

| Skill | Threshold (minutes) | Rationale |
|-------|---------------------|-----------|
| analyze-req | 45 | Multi-agent dept analysis; 45 min = reasonable max for standard |
| define-features | 60 | Feature specs creation; 60 min = reasonable for multi-system |
| design | 60 | Architecture + specs parallel; 60 min reasonable |
| design-ux | 60 | Screen design; 60 min reasonable |

4. **Plan A/B options khi BLOCK:**
   - **Plan A-1:** Narrow scope (chỉ top-N systems/modules)
   - **Plan A-2:** Lower profile (`--profile=quick` thay `standard`)
   - **Plan A-3:** Override + CDG-01 confirmation
   - **Plan B:** Partition — chạy từng workload riêng, checkpoint giữa mỗi workload

5. **brainstorm:** Skill ngắn (15-30 min), không cần workload gate. Loại.

**Alternatives considered:**
1. **Hard time limit (timeout)** → kill giữa chừng mất work. Loại.
2. **Không gate — chạy tự do** → user bất ngờ khi context cạn. Loại.
3. **Gate ở mỗi phase** → quá nhiều prompts. Gate 1 lần ở Phase 0.5 đủ.

**Consequences:**
- (+) User có知情权 trước khi commit thời gian
- (+) Block sớm → tránh context overflow giữa chừng
- (+) Plan A/B structured → user có choice, không bị force
- (-) Estimate heuristic không chính xác tuyệt đối → cần calibration theo thời gian
- (-) Thêm 1 phase (Phase 0.5) → slight overhead cho small projects

---

### ADR-OPT-04: Signal Aggregator + Dedup Boundary

**Nguồn:** wf-fix-bugs v6 `signal_aggregator.py` (SignalBus dedup)

**Context:** Khi nhiều lane agents chạy song song, chúng có thể tạo output trùng lặp:
- analyze-req: 2 dept-experts cùng generate REQ cho cross-dept requirement
- define-features: feature specs trùng giữa systems
- design: API endpoints trùng giữa api-contract và infra-spec lanes
- design-ux: components trùng giữa system lanes

Hiện tại: không có dedup → trùng lặp chỉ phát hiện ở cross-validation phase (sửa muộn, đắt).

**Decision:**

1. Mỗi lane viết `lanes/{KEY}/signals.json` chứa structured output
2. **Signal Aggregator** đọc tất cả lane signals, dedup bằng composite key:
   - analyze-req: key = `REQ-ID` (normalize lowercase, strip department prefix)
   - define-features: key = `FEAT-ID`
   - design: key = `endpoint_path | entity_name | component_name`
   - design-ux: key = `component_id + variant`
3. **Conflict resolution:** Nếu 2 lanes tạo cùng key → flag CONFLICT, giữ cả 2 versions, yêu cầu user/CQG giải quyết
4. **Dedup metrics** ghi vào aggregator output: `dedup_input_count`, `dedup_output_count`, `conflicts[]`

**Alternatives considered:**
1. **Dedup ở cross-validation phase (muộn)** → chi phí sửa cao hơn. Loại.
2. **Không dedup** → REQ-ID trùng downstream gây chaos. Loại.
3. **Dedup bằng fuzzy matching** → false positive rate cao. Dùng exact key matching.

**Consequences:**
- (+) Phát hiện conflict sớm → sửa rẻ
- (+) REQ-ID/FEAT-ID uniqueness được enforce tại aggregation boundary
- (+) Dedup metrics cho observability
- (-) Lane output phải tuân schema chuẩn → thêm validation
- (-) Conflict resolution cần logic per skill (không generic)

---

### ADR-OPT-05: Template Stripping `_template_notes` + Atomic Write cho Digest Files

**Nguồn:** wf-legacy-scan v5.0 `_shared.md §Template Metadata Stripping` + atomic write pattern

**Context:**
- Digest files (project-digest.json, dept-digests.json, feature-briefs.json, design-input-digest.json, ux-input-digest.json) được downstream skills tiêu thụ làm context nén.
- Templates có `_template_notes`, `_comments`, `_examples` fields — metadata cho người tạo template, không phải data cho downstream consumer.
- Hiện tại: nhiều digest files vẫn chứa template metadata → downstream context bị nhiễm rác.
- Ghi file không atomic → downstream có thể đọc partial file nếu đọc cùng lúc với write.

**Decision:**

1. **Template stripping:** Trước khi ghi digest, chạy:
   ```bash
   jq 'del(._template_notes, ._comments, ._examples, ._placeholder)' input.json > output.json
   ```

2. **Atomic write pattern:**
   ```bash
   # Write to temp, then atomic rename
   jq '.' data.json > data.json.tmp && mv data.json.tmp data.json
   ```

3. **Áp dụng cho mọi digest output** của 5 skills (15+ files total theo §4b Cross-Skill Output Path Contract).

4. **Enforcement:** Hook `validate-contract-sync.sh` check digest files không chứa `_template_notes` key.

**Alternatives considered:**
1. **Không strip — downstream tự ignore** → waste context tokens, pollution. Loại.
2. **Strip ở consumer side** → mỗi consumer phải thêm logic, violate DRY. Loại.
3. **Dùng JSON Schema `additionalProperties: false`** → quá cứng, khó iterate. Loại.

**Consequences:**
- (+) Downstream context sạch hơn ~10-20% (loại metadata)
- (+) Atomic write → không partial read
- (+) Consistent pattern across all skills
- (-) Cần thêm 1 bước jq trong write pipeline
- (-) Template authors mất inline guidance khi đọc output → nhưng template source vẫn giữ notes

---

### ADR-OPT-06: Profile System 3 Cấp (quick/standard/deep)

**Nguồn:** wf-fix-bugs v6 `profiles.json` + `profile_resolver.py` + wf-legacy-scan v5.0 ADR-LS02

**Context:**
- analyze-req, define-features không có profile — luôn chạy full depth.
- design và design-ux có LPM (Large Project Mode) auto-detect nhưng không có user-controllable profile.
- User đôi khi chỉ cần overview nhanh, không cần edge-case analysis.
- wf-fix-bugs và wf-legacy-scan đã chứng minh profile system hiệu quả.

**Decision:** 3 profiles (không 4 — "exhaustive" không có ý nghĩa cho linear authoring):

| Profile | analyze-req | define-features | design-ux |
|---------|-------------|-----------------|-----------|
| **quick** | Summary requirements, no edge cases | Feature stubs only, no acceptance criteria | Wireframes only, no responsive |
| **standard** | Full requirements + acceptance criteria (default, = current behavior) | Full specs + acceptance criteria | Full design + responsive (default, = current behavior) |
| **deep** | + Edge cases + compliance matrix + regulatory constraints | + Edge cases + non-functional specs + test scenarios | + Accessibility audit + animation specs + interaction states |

**Safety floor:** `standard` là minimum cho production-bound projects. `quick` chỉ dùng cho early exploration. enforce bằng profile_resolver.

**Default:** `standard` (backward-compat — output parity với phiên bản hiện tại).

**CLI flag:** `--profile=quick|standard|deep`. Nếu không chỉ định → `standard`.

**brainstorm:** Skill ngắn, không cần profile. Loại.
**design:** Đã có LPM auto-detect — có thể integrate vào profile system nhưng không urgent.

**Alternatives considered:**
1. **4 profiles (thêm exhaustive)** → Linear authoring không có "audit" dimension. Over-specify. Loại.
2. **2 profiles (quick/full)** → Quá coarse. Loại.
3. **Không profile — giữ hiện tại** → User không có control over depth. Loại.

**Consequences:**
- (+) User control depth ↔ time trade-off
- (+) quick profile cho early-stage exploration (giảm 50% thời gian)
- (+) deep profile cho regulated industries (healthcare, finance)
- (+) standard = backward-compat lock (không breaking change)
- (-) Mỗi skill phải maintain 3 variants của mỗi phase procedure
- (-) Test matrix mở rộng: 3 profiles × N phases

---

### ADR-OPT-07: ISG-style Intent Signal Analysis (Profile Recommendation)

**Nguồn:** wf-fix-bugs v6 `isg/isg_recommender.py` + wf-legacy-scan v5.0 `ips/ips_recommender.py`

**Context:** ADR-OPT-06 thêm profile system, nhưng user có thể không biết profile nào phù hợp. Cần cơ chế recommend.

**Decision:**

1. **Intent Signal Analysis** chạy ở Phase 0 (PRE-GATE), đọc metadata không cần scan code:
   - Input: registry (departments count, interface_type), upstream digests (size, complexity signals), project-context.md (legacy mode signals)
   - Output: `profile-recommendation.json` với `recommended_profile`, `signals[]`, `confidence`

2. **Signal heuristics per skill:**

   | Skill | Signals phân tích | Quick trigger | Deep trigger |
   |-------|-------------------|---------------|--------------|
   | analyze-req | dept_count, compliance_keywords, interface_type, legacy_mode | dept ≤ 2, no compliance | compliance detected, dept ≥ 5, healthcare/finance/legal domain |
   | define-features | features_count, systems_count, has_ui | features ≤ 10, single system | features ≥ 30, multi-system, has_edge_cases |
   | design-ux | interface_type, screen_count, has_design_system | api-only or ≤ 5 screens | ≥ 20 screens, no design system, multi-platform |

3. **User override:** CDG (CORE-027) — hiển thị recommendation +理由, cho user accept/override.

4. **Integration với ADR-OPT-06:** Recommendation auto-set `--profile` flag nếu user không chỉ định.

**brainstorm + design:** Không đủ signals để recommend. Loại.

**Alternatives considered:**
1. **Luôn default standard** → User không biết có option nhanh hơn. Loại.
2. **IPS Python module** (như legacy-scan) → Overkill cho 3 skills. Inline heuristic đủ.
3. **User tự chọn không gợi ý** → User không đủ context để quyết định. Loại.

**Consequences:**
- (+) User có informed recommendation
- (+) CDG override — không force
- (+) Giảm 50% thời gian cho projects đơn giản (auto-quick)
- (-) Signal heuristics cần calibration
- (-) False recommendation → user phải override (minor friction)

---

### ADR-OPT-08: CDG Handoff Tokens tại điểm Critical

**Nguồn:** wf-fix-bugs v6 `cdg-handoff.md` + `cdg-tokens.json`

**Context:** CORE-027 yêu cầu user confirmation cho hành động không-undo. Hiện tại 5 skills có CDG không formal:
- brainstorm Phase 0.5: legacy decisions (đã có nhẹ)
- analyze-req: domain ambiguity (chưa có)
- define-features: bỏ feature (chưa có CDG explicit)
- design: architecture trade-offs (chưa có formal CDG tokens)
- design-ux: redesign primary flow (chưa có formal CDG tokens)

**Decision:**

1. **Formalize CDG points per skill:**

   | Skill | CDG Points | Description |
   |-------|-----------|-------------|
   | brainstorm | CDG-B01 | Legacy decisions: KEEP/DEPRECATE modules |
   | brainstorm | CDG-B02 | Profile override (nếu khác recommendation) |
   | analyze-req | CDG-A01 | Domain ambiguity resolution (finance vs accounting) |
   | analyze-req | CDG-A02 | Scope narrowing (workload gate block) |
   | define-features | CDG-D01 | Skip feature (set `impl_status: "skipped"`) |
   | define-features | CDG-D02 | Scope narrowing (workload gate block) |
   | design | CDG-DS01 | Architecture pattern change (vs brainstorm policies) |
   | design | CDG-DS02 | Skip module from design (not in original scope) |
   | design-ux | CDG-UX01 | Remove/relocate primary CTA |
   | design-ux | CDG-UX02 | Redesign existing flow (legacy mode) |
   | design-ux | CDG-UX03 | Scope narrowing (workload gate block) |

2. **CDG Token schema** (tái dùng từ wf-fix-bugs):
   ```json
   {
     "cdg_id": "CDG-A01",
     "decision": "accept|reject",
     "timestamp": "2026-04-23T10:30:00+07:00",
     "context": "Phát hiện ambiguity: 'kế toán' referenced trong cả finance dept và hr dept"
   }
   ```

3. **Anti-loop guard:** Cùng 1 CDG reject ≥ 2 lần → force ESCALATE, không hỏi lại.

4. **Storage:** `session-dir/cdg-tokens.json` (APPEND-only).

**Alternatives considered:**
1. **AskUserQuestion ad-hoc** (hiện tại) → Không audit trail, không enforce anti-loop. Loại.
2. **CDG cho mọi decision** → Quá nhiều prompts. Chỉ điểm critical. Giữ current.
3. **Không CDG** → User mất知情权. Loại.

**Consequences:**
- (+) Audit trail cho critical decisions
- (+) Anti-loop → không hỏi vô tận
- (+) CDG tokens reusable cho downstream (e.g., design đọc analyze-req CDG tokens)
- (-) Thêm prompt friction tại CDG points
- (-) Cần identify CDG points upfront per skill (maintenance khi skill thay đổi)

---

### ADR-OPT-09: Incremental + Cache (Content-hash Key, 2-tier)

**Nguồn:** wf-legacy-scan v5.0 ADR-LS10 (incremental scan + 2-tier cache)

**Context:**
- 4 skills (analyze-req, define-features, design, design-ux) tạo digest outputs tốn kém (multi-agent analysis).
- Chạy lại sau small upstream change → tính lại toàn bộ. Waste.
- Upstream digests có content hash ổn định → cache key tự nhiên.

**Decision:**

1. **Content-hash cache key:**
   ```
   cache_key = sha256(file_path + content_hash_of_inputs)
   ```
   - analyze-req: key = sha256(registry.json + project-digest.json)
   - define-features: key = sha256(registry.json + dept-digests.json + phase1-handoff.json)
   - design: key = sha256(registry.json + feature-briefs.json)
   - design-ux: key = sha256(registry.json + design-input-digest.json)

2. **2-tier cache:**
   - **Session cache:** In-memory, TTL = session lifetime. Fast-path khi retry.
   - **Project cache:** `.mc-data/cache/{skill}/`, TTL = 14 days. Cross-session reuse.

3. **Incremental behavior:**
   - Mặc định: kiểm tra cache trước khi re-compute
   - `--no-cache`: bỏ qua cache, re-compute tất cả
   - `--incremental`: chỉ re-compute phần cache miss (content-hash changed)

4. **Cache invalidation:**
   - Content-hash thay đổi → tự động invalidate
   - TTL expired → invalidate
   - `--no-cache` → clear all

**brainstorm:** Entry point, không consume upstream digest. Không cần cache. Loại.

**Alternatives considered:**
1. **Không cache — luôn re-compute** → Waste khi upstream không đổi. Loại.
2. **Git-based incremental** (như legacy-scan `--since=git-ref`) → Digests không phải source code, không track bằng git. Dùng content-hash phù hợp hơn.
3. **1-tier cache only** → Không cross-session reuse. Thiếu.

**Consequences:**
- (+) Re-run sau small change: chỉ re-compute phần thay đổi
- (+) Cross-session: session 2 reuse kết quả session 1 nếu inputs giống
- (+) Content-hash → tự động invalidation khi data đổi
- (-) Cache storage占用 disk space (mitigate: TTL 14d + size limit)
- (-) Cache hit/miss metrics cần monitor (thêm observability)
- (-) Edge case: cache corruption → silent wrong data. Mitigate: validate cached output (T1 check)

---

### ADR-OPT-10: CORE-028 Phase-Summary Formal hóa

**Nguồn:** wf-legacy-scan v5.0 CORE-028 implementation + wf-fix-bugs v6 `phase-summary.md`

**Context:**
- **wf-define-features:** MISSING phase-summary.md hoàn toàn — vi phạm CORE-028.
- **wf-analyze-requirements:** Phase-summary chỉ implicit qua session-log, không có file formal.
- 3 skills còn lại (brainstorm, design, design-ux) đã có nhưng format không nhất quán.

**Decision:**

1. **wf-define-features:** Thêm phase-summary.md emission ở cuối Phase 5 (sau registry update):
   - Template: `_shared/templates/phase-summary.md`
   - Content: feature count per system, total REQs mapped, skipped features, cross-validation result
   - Location: `.mc-data/work/wf-define-features/sessions/{id}/phase-summary.md`

2. **wf-analyze-requirements:** Formalize phase-summary ở Phase 8c (sau handoff):
   - Hiện tại: implicit trong session-log events
   - Mới: explicit file, append-only, tiếng Việt
   - Content: dept count, requirement count per dept, conflict count, deferred issues count

3. **Chuẩn hóa format** cho cả 5 skills:
   ```markdown
   # Phase Summary — {skill-name}

   ## Tổng quan
   - Thời gian thực thi: {duration}
   - Profile: {profile_used}
   - Session: {session_id}

   ## Phase {N}: {name} — {PASS|WARN|FAIL}
   - Metric 1: {value}
   - Metric 2: {value}

   ## Phase {N+1}: {name} — {PASS|WARN|FAIL}
   ...
   ```

4. **Append-only:** Không rewrite — mỗi phase thêm section mới.

**Alternatives considered:**
1. **Không fix — define-features sống thiếu phase-summary** → Vi phạm CORE-028. Loại.
2. **Tạo phase-summary ở mỗi phase** → Quá nhiều writes. Chỉ tạo ở cuối skill run, append per phase. Giữ.
3. **Format khác nhau per skill** → User phải học 5 formats. Chuẩn hóa 1 format.

**Consequences:**
- (+) CORE-028 compliance cho define-features (fix MISSING)
- (+) Nhất quán format → user quen 1 pattern
- (+) Machine-parseable → future tooling có thể extract metrics
- (-) Thêm 1 write operation cuối mỗi skill run
- (-) Phase-summary file cần cleanup policy (keep N sessions)

---

## 4. Skill-by-Skill Impact Analysis

### 4.1 wf-brainstorm

| Kỹ thuật | Impact | Ghi chú |
|----------|--------|---------|
| ADR-OPT-01 Lane Dispatch | ✅ Áp dụng Phase 3 (5 expert roles) | 3/5 roles chạy song song → tiết kiệm ~40% |
| ADR-OPT-02 Session Isolation | ⚠️ Không cần | Skill ngắn, single-run đủ. Chỉ L1 checkpoint. |
| ADR-OPT-03 Workload Gate | ❌ Không cần | 15-30 min max, không vượt threshold. |
| ADR-OPT-04 Signal Aggregator | ⚠️ Lightweight | Chỉ cần cho Phase 3 (dedup policy suggestions giữa experts). Không cần full SignalBus. |
| ADR-OPT-05 Template Strip + Atomic | ✅ Áp dụng | project-digest.json + project-intent-digest.json cần strip. |
| ADR-OPT-06 Profile System | ❌ Không cần | Skill ngắn, single mode đủ. |
| ADR-OPT-07 ISG Intent Analysis | ❌ Không cần | Entry point, không có signals upstream. |
| ADR-OPT-08 CDG Tokens | ✅ Áp dụng | CDG-B01 (legacy decisions) + CDG-B02 (profile override — khi downstream có profile). |
| ADR-OPT-09 Incremental Cache | ❌ Không cần | Entry point, không consume upstream. |
| ADR-OPT-10 Phase-Summary | 🟢 Đã có | Chỉ cần chuẩn hóa format theo _shared template. |

**Net improvement:** ~40% wall-time giảm ở Phase 3 + audit trail (CDG tokens) + cleaner digests.

### 4.2 wf-analyze-requirements

| Kỹ thuật | Impact | Ghi chú |
|----------|--------|---------|
| ADR-OPT-01 Lane Dispatch | ✅ Áp dụng Phase 4 | Dept-experts song song (max_parallel=3) → tiết kiệm ~50%. |
| ADR-OPT-02 Session Isolation | ✅ Áp dụng | sessions/{id}/ + 3-level checkpoint. Khắc phục 14-phase problem: resume chính xác dept-batch. |
| ADR-OPT-03 Workload Gate | ✅ Áp dụng | Phase 0.5: estimate dept×reqs → gate nếu > 45 min. |
| ADR-OPT-04 Signal Aggregator | ✅ Áp dụng Phase 6 | Dedup REQ-ID giữa dept-lanes. Conflict flag cho cross-dept requirements. |
| ADR-OPT-05 Template Strip + Atomic | ✅ Áp dụng | dept-digests.json + phase1-handoff.json. |
| ADR-OPT-06 Profile System | ✅ Áp dụng | quick (summary) / standard (full) / deep (+edge cases + compliance). |
| ADR-OPT-07 ISG Intent Analysis | ✅ Áp dụng | Analyze dept_count + compliance keywords + interface_type → recommend profile. |
| ADR-OPT-08 CDG Tokens | ✅ Áp dụng | CDG-A01 (domain ambiguity) + CDG-A02 (scope narrowing). |
| ADR-OPT-09 Incremental Cache | ✅ Áp dụng | Cache dept-digests theo content-hash của registry + project-digest. |
| ADR-OPT-10 Phase-Summary | ✅ Fix MISSING | Formalize phase-summary.md ở Phase 8c. |

**Net improvement:** ~50% wall-time giảm (Phase 4 parallel) + profile flexibility + incremental re-run + CORE-028 fix.

### 4.3 wf-define-features

| Kỹ thuật | Impact | Ghi chú |
|----------|--------|---------|
| ADR-OPT-01 Lane Dispatch | ✅ Áp dụng Phase 2 | Feature-group agents song song → tiết kiệm ~40%. |
| ADR-OPT-02 Session Isolation | ✅ Áp dụng | sessions/{id}/ + 2-level checkpoint (phase + feature-group). |
| ADR-OPT-03 Workload Gate | ✅ Áp dụng | Phase 0.5: estimate features × systems → gate nếu > 60 min. |
| ADR-OPT-04 Signal Aggregator | ✅ Áp dụng Phase 3 | Dedup FEAT-ID giữa system-lanes. |
| ADR-OPT-05 Template Strip + Atomic | ✅ Áp dụng | feature-briefs.json (cả working + digest schemas). |
| ADR-OPT-06 Profile System | ✅ Áp dụng | quick (stubs) / standard (full specs) / deep (+acceptance criteria + test scenarios). |
| ADR-OPT-07 ISG Intent Analysis | ⚠️ Reuse IPS | Reuse analyze-req recommendation (cùng input signals). Không chạy lại. |
| ADR-OPT-08 CDG Tokens | ✅ Áp dụng | CDG-D01 (skip feature) + CDG-D02 (scope narrowing). |
| ADR-OPT-09 Incremental Cache | ✅ Áp dụng | Cache feature-briefs theo content-hash của dept-digests + registry. |
| ADR-OPT-10 Phase-Summary | ✅ Fix MISSING | Thêm phase-summary.md ở Phase 5 (hiện không có). |

**Net improvement:** ~40% wall-time giảm (Phase 2 parallel) + CORE-028 fix + incremental re-run.

### 4.4 wf-design

| Kỹ thuật | Impact | Ghi chú |
|----------|--------|---------|
| ADR-OPT-01 Lane Dispatch | ✅ Áp dụng Phase 2 | api-contract + db-design + infra-spec song song (đã có partially, formalize). |
| ADR-OPT-02 Session Isolation | ✅ Áp dụng | sessions/{id}/ + 3-level checkpoint (phase + system + spec-section). |
| ADR-OPT-03 Workload Gate | ✅ Áp dụng | Phase 0.5: estimate systems × complexity → gate nếu > 60 min. |
| ADR-OPT-04 Signal Aggregator | ✅ Áp dụng Phase 3 | Dedup API endpoints + DB entities giữa spec-lanes. |
| ADR-OPT-05 Template Strip + Atomic | ✅ Áp dụng | design-input-digest.json + design-summary.json. |
| ADR-OPT-06 Profile System | ⚠️ Low priority | Đã có LPM auto-detect. Có thể formalize nhưng không urgent. |
| ADR-OPT-07 ISG Intent Analysis | ❌ Không cần | LPM auto-detect đủ. |
| ADR-OPT-08 CDG Tokens | ✅ Áp dụng | CDG-DS01 (architecture pattern change) + CDG-DS02 (skip module). |
| ADR-OPT-09 Incremental Cache | ✅ Áp dụng | Cache design-input-digest theo content-hash của feature-briefs + registry. |
| ADR-OPT-10 Phase-Summary | 🟢 Đã có | Chuẩn hóa format theo _shared template. |

**Net improvement:** ~30% wall-time giảm (Phase 2 formalize) + better checkpoint + CDG audit.

### 4.5 wf-design-ux

| Kỹ thuật | Impact | Ghi chú |
|----------|--------|---------|
| ADR-OPT-01 Lane Dispatch | ✅ Áp dụng Phase 1 + Phase 3 | Phase 1: parallelize brand-guardian + ux-researcher (hiện sequential). Phase 3: system lanes song song. |
| ADR-OPT-02 Session Isolation | ✅ Áp dụng | sessions/{id}/ + 3-level checkpoint (phase + system + screen). |
| ADR-OPT-03 Workload Gate | ✅ Áp dụng | Phase 0.5: estimate screens × breakpoints → gate nếu > 60 min. |
| ADR-OPT-04 Signal Aggregator | ✅ Áp dụng Phase 4 | Dedup component variants giữa system-lanes. |
| ADR-OPT-05 Template Strip + Atomic | ✅ Áp dụng | ux-input-digest.json. |
| ADR-OPT-06 Profile System | ✅ Áp dụng | quick (wireframes) / standard (full design) / deep (+a11y audit + animations). |
| ADR-OPT-07 ISG Intent Analysis | ✅ Áp dụng | Analyze interface_type + screen_count → recommend profile. API-only → auto-skip. |
| ADR-OPT-08 CDG Tokens | ✅ Áp dụng | CDG-UX01 (remove primary CTA) + CDG-UX02 (redesign flow) + CDG-UX03 (scope narrowing). |
| ADR-OPT-09 Incremental Cache | ✅ Áp dụng | Cache ux-input-digest theo content-hash của design-input-digest + registry. |
| ADR-OPT-10 Phase-Summary | 🟢 Đã có | Chuẩn hóa format theo _shared template. |

**Net improvement:** ~50% wall-time giảm (Phase 1 parallelize + Phase 3 lanes) + profile flexibility + CDG audit.

---

## 5. Lộ trình Triển khai

### Phase 1: Hạ tầng (P0-PREREQ) — 1-2 ngày

```
.claude/skills/workflow/_shared/
├── concurrency/        ← Extract từ wf-legacy-scan + wf-fix-bugs
├── partition/          ← Extract từ wf-fix-bugs
├── profiles/           ← Extract từ wf-fix-bugs, adapt 3 profiles
├── aggregate/          ← Extract từ wf-fix-bugs
├── cdg/                ← Protocol 16 adapted
├── cache/              ← Extract từ wf-legacy-scan
├── templates/          ← New templates (phase-summary, session-state, workload-report)
└── _shared.md          ← Template strip + atomic write protocol
```

**Verify:** Unit tests cho mỗi Python module. Schema validation cho mỗi template.

### Phase 2: P0 Rollout — 5-7 ngày

**Thứ tự skill (bottleneck lớn nhất trước):**
1. **wf-analyze-requirements** (14 phases, heaviest)
2. **wf-design** (architecture critical path)
3. **wf-design-ux** (most parallelizable)
4. **wf-define-features** (CORE-028 fix)
5. **wf-brainstorm** (lightest, least changes)

**Mỗi skill rollout:**
1. Session isolation + checkpoint schema (ADR-OPT-02)
2. Lane dispatch cho phase "spawn experts" (ADR-OPT-01)
3. Partition + Workload Gate ở Phase 0 (ADR-OPT-03)
4. Signal Aggregator cho phase consolidate (ADR-OPT-04)
5. Template strip + atomic write cho digest outputs (ADR-OPT-05)
6. Verify: fixture tests → backward-compat parity với current behavior

### Phase 3: P1 Rollout — 3-5 ngày

- Profile System (ADR-OPT-06): analyze-req, define-features, design-ux
- ISG Intent Analysis (ADR-OPT-07): analyze-req, design-ux
- CDG Handoff Tokens (ADR-OPT-08): tất cả 5 skills
- Incremental Cache (ADR-OPT-09): analyze-req, define-features, design, design-ux
- Phase-Summary fix (ADR-OPT-10): define-features (MISSING), analyze-req (formalize)

### Phase 4: Verification & Documentation — 1-2 ngày

- Run full workflow trên test project (brainstorm → design-ux)
- Verify backward-compat: standard profile output = current output
- Update CLAUDE.md nếu cần (skills table, flags)
- Update _contract.json per skill

---

## 6. Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| `_shared/` coupling — thay đổi _shared phá tất cả skills | HIGH | Version _shared modules (v1, v2). Skills pin version. |
| Profile system tăng test matrix (3×N phases) | MEDIUM | Test standard profile primary; quick/deep smoke-test only. |
| Cache corruption → wrong output | MEDIUM | T1 existence check trên cached output; TTL 14d auto-expire. |
| Session dirs chiếm disk | LOW | Cleanup policy: keep 5 latest sessions; configurable. |
| Workload estimate sai → false block | MEDIUM | Calibrate heuristic sau 5 projects real; tune thresholds. |
| CDG prompts gây friction | LOW | Chỉ 2-3 CDG points per skill; non-critical không prompt. |
| Signal dedup aggressive → mất unique items | HIGH | Conflict flag giữ cả 2 versions; user resolve; không auto-merge. |
| Backward compat break | HIGH | Standard profile = current behavior; fixture tests enforce parity. |

---

## 7. Open Questions

| # | Question | Owner | Deadline |
|---|----------|-------|----------|
| 1 | Đồng ý tạo `.claude/skills/workflow/_shared/` không? (P0-PREREQ) | Owner | Trước Phase 1 |
| 2 | Workload gate thresholds (45/60 min) phù hợp với expectation không? | Owner | Trước Phase 2 |
| 3 | Session cleanup policy: keep 5 sessions đủ? Hay prefer keep-all? | Owner | Trước Phase 2 |
| 4 | CDG points per skill (§3.8) có đủ/thừa không? | Owner | Trước Phase 3 |
| 5 | Profile "deep" có cần thêm dimension nào cho domain cụ thể? | Domain expert | Trước Phase 3 |
| 6 | Cache TTL 14 ngày phù hợp? Hay prefer 7 ngày / 30 ngày? | Owner | Trước Phase 3 |

---

## 8. Anti-patterns — Kỹ thuật KHÔNG Import

| Kỹ thuật (không import) | Nguồn | Lý do loại |
|---|---|---|
| 7 Dimension Lanes (QD1-QD7) | wf-fix-bugs | Fix-bugs chuyên "tìm lỗi đa chiều". Linear authoring skills dùng lanes theo domain/department/system, không phải quality dimension. |
| Verify Loop state machine (VERIFY_INIT→SCAN→EVAL→FIX) | wf-fix-bugs | 5 skills không có "verify against ground-truth" loop. Cross-validation hiện tại đủ dùng. |
| Deep mode stub creation (Phase 4b) | wf-fix-bugs | Upstream skills không đủ thông tin tạo stub chuẩn cho downstream. Giữ upstream→downstream single-direction. |
| IPS Python ML recommender cho mọi skill | wf-legacy-scan | Overkill cho brainstorm/design. Chỉ analyze-req và design-ux hưởng lợi đủ để justify complexity. |
| Pure Orchestrator `fields_owned: []` cho mọi skill | wf-fix-bugs | analyze-req, define-features là PRIMARY owner của registry fields — bắt buộc phải viết. Không thể tách. |
| 4 profiles (quick/standard/deep/exhaustive) | wf-legacy-scan | "Exhaustive" không có ý nghĩa cho linear authoring. 3 profiles đủ. |
| Error ledger with retry per tier (E001-E0199) | wf-legacy-scan | Linear skills có error handling đơn giản hơn scan. Không cần structured error codes. |
| Batch-size tuning per scan layer | wf-legacy-scan | Batch sizing là scan-specific. Authoring skills dùng feature-group/system grouping. |

---

## 9. Approval

| Role | Name | Decision | Date |
|------|------|----------|------|
| Architect | Claude (AI) | ✅ Tech Review PASSED | 2026-04-23 |
| Owner | Vu Minh Tu | ⬜ Pending | — |

**Sign-off condition:** Owner approve §7 Open Questions → status chuyển "Accepted".
