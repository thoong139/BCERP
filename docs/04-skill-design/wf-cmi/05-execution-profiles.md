# 05 — Execution Profiles (wf-cmi)

> **Mục đích file:** Đặc tả 4 profiles `quick / standard / deep / exhaustive` của skill wf-cmi — duration, scope, phase activation, cost, decision matrix. **BỔ SUNG** cho [05-error-codes.md](05-error-codes.md).
>
> **⚡ v2.0 UPDATE (2026-05-16):** Mở rộng từ 10 lanes (v1) → **26 lanes Gói C++ Logistics** (CD1-CD7, CD9, CD11, CD13, CD15-CD18, CD23-CD26, CD28-CD31, CD37-CD40). `deep` profile expand từ 10 → 26 lanes (breaking change). NEW: **3-WAVE dispatch strategy** (Wave 1 = 10 lanes graphs-only / Wave 2 = 10 lanes cross-layer / Wave 3 = 6 lanes final cross-ref). Xem §11 Wave Dispatch + `docs/04-skill-design/wf-cmi/v2-migration-notes.md`.

---

## 1. Profiles overview (v2.0)

| Profile        | Duration (EUREKA 17 modules) | Coverage threshold/dim | Số lanes active | LLM (Phase 3)                             | Playwright                   | Cache policy              | Cost estimate          | Max sessions/máy |
| -------------- | ---------------------------- | ---------------------- | ---------------- | ----------------------------------------- | ---------------------------- | ------------------------- | ---------------------- | ----------------- |
| `quick`      | 5-10 min                     | ≥60%                  | **7** (Wave 1 subset) | Heuristic only (no LLM)                   | ❌                           | Aggressive (24h TTL)      | ~10K tokens (~$0.05)  | 5                 |
| `standard`   | 15-30 min                    | ≥80%                  | **13** (W1+W2+W3 subset) | 1-pass LLM (cross-module pattern)         | Assisted (smoke nếu có UI) | Normal (24h TTL)          | ~100K tokens (~$0.50) | 5                 |
| `deep`       | **55-90 min** (v2 từ 45-90) | ≥95%                  | **26** (full Gói C++ 3-wave) | 3-pass LLM (full) + spawn domain experts  | Full                         | Selective (4h TTL probes) | ~500K tokens (~$2.50) | 2                 |
| `exhaustive` | 120-180 min                  | =100%                  | **30+** (26 + LLM enhance + deferred) | 3-pass + cross-domain conflict resolution | Full + cross-browser         | Skip cache                | ~1.5M tokens (~$7.50) | 2                 |

**Default:** `standard` (cân bằng thoroughness vs cost cho daily work).

> **Breaking change v1→v2:** `--profile=deep` thời gian tăng ~50% (45-90 → 55-90 min) do expand từ 10 lanes → 26 lanes. Migration notes có hướng dẫn tránh CI timeout.

---

## 2. Phase activation matrix (v2.0)

| Phase                          |         quick         |    standard    |       deep       |            exhaustive            |
| ------------------------------ | :-------------------: | :-------------: | :---------------: | :------------------------------: |
| 1. Init + CI PRE-GATE          |          ✅          |       ✅       |        ✅        |                ✅                |
| 2. Discovery (**13 graphs** v2) | ✅ (6 core, skip plugins) |  ✅ (6 core + 3 FE plugins) |  ✅ (all 13) |  ✅ (all 13)  |
| 3. Invariant Registry          |  ✅ (heuristic only)  | ✅ (1-pass LLM) |  ✅ (3-pass LLM)  |    ✅ (3-pass + cross-domain)    |
| 4. **Coverage Dispatch (3-WAVE)** | ✅ (**7 lanes Wave 1 only**) | ✅ (**13 lanes W1+W2+W3 subset**) | ✅ (**26 lanes full 3-wave**) | ✅ (**26 + LLM enhance + deferred**) |
| 5. Aggregate (**35 dim matrix v2**) | ✅ | ✅ | ✅ | ✅ |
| 6. Regression Map              |        ❌ skip        | ✅ (diff-aware) |  ✅ (predictive)  |       ✅ (predictive + ML)       |
| 7. GAP + CDG                   |      ✅ (basic)      |       ✅       | ✅ (auto-suggest) | ✅ (auto-suggest + cross-domain) |
| 8. Report (**v2 top 10 violations**) |   ✅  |   ✅  |   ✅  |   ✅  |

---

## 3. Lane activation matrix (v2.0 — 26 active + 9 SKIPPED + 5 skeleton v3-deferred)

> **Legend:** ✅ active / ❌ SKIPPED (placeholder trong coverage-matrix) / 🔒 SKELETON v3-deferred (KHÔNG present trong coverage-matrix)

### 3.1 Wave 1 lanes (graphs-only, max 10 parallel, ~10-12 min)

| Lane                              | Group     | quick | standard | deep | exhaustive | Owner Agents                       |
| --------------------------------- | --------- | :---: | :------: | :--: | :--------: | ---------------------------------- |
| CD1 Business domain               | Core      |  ✅   |   ✅    |  ✅  |    ✅      | business-analyst                   |
| CD2 Entity dependency             | Core      |  ✅   |   ✅    |  ✅  |    ✅      | architect                          |
| CD3 Workflow coverage             | Core      |  ✅   |   ✅    |  ✅  |    ✅      | architect + business-analyst       |
| CD4 API contract                  | Core      |  ✅   |   ✅    |  ✅  |    ✅      | architect                          |
| CD5 Event coverage                | Core      |  ❌   |   ✅    |  ✅  |    ✅      | architect                          |
| CD6 Permission/RBAC               | Core      |  ❌   |   ✅    |  ✅  |    ✅      | security                           |
| CD7 Data integrity                | Core      |  ✅   |   ✅    |  ✅  |    ✅      | dba                                |
| CD11 FE Component Contracts ★ NEW | Frontend  |  ❌   |   ✅    |  ✅  |    ✅      | frontend-developer                 |
| CD16 Domain Logic Integrity ★ NEW | Backend   |  ✅   |   ✅    |  ✅  |    ✅      | architect + business-analyst       |
| CD17 Persistence Consistency ★ NEW | Backend  |  ✅   |   ✅    |  ✅  |    ✅      | dba + data-engineer                |

### 3.2 Wave 2 lanes (cross-layer, max 10 parallel, ~12-15 min)

| Lane                                  | Group       | quick | standard | deep | exhaustive | Owner Agents                                  |
| ------------------------------------- | ----------- | :---: | :------: | :--: | :--------: | --------------------------------------------- |
| CD13 FE↔BE Contract Sync ★ NEW       | Frontend    |  ❌   |   ✅    |  ✅  |    ✅      | architect + frontend-developer                |
| CD15 UI Permission Mirror ★ NEW       | Frontend    |  ❌   |   ❌    |  ✅  |    ✅      | frontend-developer + security                 |
| CD18 CQRS Pipeline Integrity ★ NEW    | Backend     |  ❌   |   ✅    |  ✅  |    ✅      | architect + developer                         |
| CD23 UX Design System ★ NEW           | UX          |  ❌   |   ❌    |  ✅  |    ✅      | ui-designer + brand-guardian                  |
| CD24 UX Display Format ★ NEW          | UX          |  ❌   |   ❌    |  ✅  |    ✅      | ux-designer + frontend-developer              |
| CD25 UX Flow Continuity ★ NEW         | UX          |  ❌   |   ❌    |  ✅  |    ✅      | ux-researcher + frontend-developer            |
| CD28 MDM Consistency ★★★ NEW        | Logistics   |  ❌   |   ❌    |  ✅  |    ✅      | data-engineer + dba + logistics-expert        |
| CD30 Time & Numbering ★★★ NEW       | Logistics   |  ❌   |   ❌    |  ✅  |    ✅      | architect + dba + logistics-expert            |
| CD31 Money & Tax ★★★ NEW            | Logistics   |  ❌   |   ❌    |  ✅  |    ✅      | finance-expert + dba + architect              |
| CD37 Regulatory Compliance ★★★ NEW  | Compliance  |  ❌   |   ❌    |  ✅  |    ✅      | compliance-expert + legal-expert + dba        |

### 3.3 Wave 3 lanes (final cross-ref, max 6 parallel, ~8-10 min)

| Lane                                  | Group         | quick | standard | deep | exhaustive | Owner Agents                                       |
| ------------------------------------- | ------------- | :---: | :------: | :--: | :--------: | -------------------------------------------------- |
| CD9 Regression coverage               | Core          |  ❌   |   ✅    |  ✅  |    ✅      | architect + qa-lead                                |
| CD26 UX Workflow Visibility ★★★ NEW | UX            |  ❌   |   ❌    |  ✅  |    ✅      | ux-designer + business-analyst + logistics-expert  |
| CD29 Audit Trail Completeness ★ NEW   | Compliance    |  ❌   |   ❌    |  ✅  |    ✅      | data-engineer + compliance-expert                  |
| CD38 UI Implementation Coverage ★ NEW | Implementation |  ❌   |   ❌    |  ✅  |    ✅      | ux-researcher + frontend-developer + BA            |
| CD39 Error UX & Recovery ★ NEW        | Implementation |  ❌   |   ❌    |  ✅  |    ✅      | ux-designer + frontend-developer                   |
| CD40 Print & Export Consistency ★ NEW | Implementation |  ❌   |   ❌    |  ✅  |    ✅      | ui-designer + frontend-developer + tech-writer     |

### 3.4 SKIPPED lanes (9 markers — placeholder, NOT executed v2.0)

| Lane                              | Lý do defer                                        | Reactivate khi               |
| --------------------------------- | -------------------------------------------------- | ----------------------------- |
| CD8 Observability                 | User không cần performance hiện tại            | Pre-production go-live        |
| CD10 Documentation                | Đắt, không critical hàng ngày                 | Pre-release                   |
| CD12 FE State Integrity           | Deep profile only — defer v2.1                    | Khi cần FE state debugging   |
| CD14 FE i18n Coverage             | Deep profile only — defer v2.1                    | Khi mở rộng multi-language deep |
| CD19 Distributed Transaction      | Cần SRE expertise — defer v2.1                    | Production hardening          |
| CD20 Security Deep                | User không cần security scope hiện tại         | Public API / external user    |
| CD21 Reliability                  | Deep profile only — defer v2.1                    | Monitoring readiness          |
| CD22 Config & Secret              | Defer v2.1 (chỉ CD22 trim)                       | Production go-live            |
| CD27 UX Microcopy                 | Deep profile only — defer v2.1                    | Khi UX matures                |

### 3.5 SKELETON lanes (5 entries — v3.0 deferred)

CD32-CD36 (Vertical lanes: Document Lifecycle, Notification, Search, MultiTenant, Operational) hiện chỉ có placeholder trong `_contract.json.lanes_defined[]` với `status: "skeleton-v3-deferred"`. KHÔNG có procedure file, KHÔNG có template, KHÔNG dispatch ở v2.0. Activate ở v3.0 qua Wave 4.

| **Tổng active lanes** | **quick=7** | **standard=13** | **deep=26** | **exhaustive=30+** |
| --------------------- | :----------: | :--------------: | :----------: | :-----------------: |

---

## 4. Cache policy per profile

| Profile    | GitNexus cache | Serena cache  | Graph cache | LLM inference cache | Bust rules               |
| ---------- | -------------- | ------------- | ----------- | ------------------- | ------------------------ |
| quick      | Use 24h        | Use 24h       | Use 24h     | N/A (no LLM)        | Manual `--no-cache`    |
| standard   | Use 24h        | Use 24h       | Use 4h      | Use 7 days          | HEAD changed > 5 commits |
| deep       | Refresh > 12h  | Refresh > 12h | Skip cache  | Use 3 days          | HEAD changed > 1 commit  |
| exhaustive | Skip cache     | Skip cache    | Skip cache  | Skip cache          | Always fresh             |

---

## 5. Decision matrix — khi nào dùng profile nào

| Tình huống EUREKA-2026      | Profile khuyến nghị                                  | Rationale                                      |
| ----------------------------- | ------------------------------------------------------ | ---------------------------------------------- |
| Trước commit local 1 module | `quick --scope=module=<name>`                        | Fast feedback, 5-10 min                        |
| Trước PR review             | `standard --since=main`                              | Diff-aware vs main, ~15-30 min                 |
| Trước merge to main         | `standard` toàn system                              | Full coverage 7 lanes                          |
| Trước release/deploy        | `deep`                                               | 3-pass LLM + 10 lanes, ~1h                     |
| Audit định kỳ tháng/quý  | `exhaustive`                                         | Comprehensive baseline 2-3h                    |
| Bug report cross-module       | `quick --dims=CD1,CD2,CD5 --scope=module=<affected>` | Targeted CD1 Business + CD2 Entity + CD5 Event |
| Onboarding repo mới          | `standard` toàn system                              | Hiểu tổng thể không tốn token             |
| Resume sau interrupt          | Same as before                                         | Auto-detect từ `integrity-status.json`      |
| CI nightly job                | `--ci --profile=standard`                            | Read-only, post lên PR                        |
| CI release gate               | `--ci --profile=deep --since=main`                   | Block release nếu coverage < 95%              |

---

## 6. Auto-upgrade rules

Skill có thể **tự bump profile** trong các case sau (báo qua CDG):

| Trigger                                                    | From → To                            | Reason                                | CDG code |
| ---------------------------------------------------------- | ------------------------------------- | ------------------------------------- | -------- |
| `--scope=system` + project >100 files với profile=quick | `quick` → `standard`             | Quick có thể miss coverage ≥7 dims | E096     |
| Phát hiện CRITICAL cross-domain conflict ở Phase 3      | `standard` → `deep`              | Cần LLM 3-pass + domain expert       | E091     |
| Cross-module dependencies detected ≥10 ở Phase 2         | `quick` → `standard`             | Quick không activate CD5 Event lane  | E096     |
| Registry v1/v2 detected (cần migrate)                     | Add Phase 3 LLM regardless of profile | Migration v3 cần LLM                 | E094     |

**Auto-downgrade rules (giảm load):**

| Trigger                   | From → To                              | Reason                              | CDG code |
| ------------------------- | --------------------------------------- | ----------------------------------- | -------- |
| `--ci` mode             | `deep`/`exhaustive` → `standard` | CI timeout (>30 min GitHub Actions) | E108     |
| `--scope=feat=<id>`     | `exhaustive` → `deep`              | Exhaustive overkill cho 1 FEAT      | E108     |
| Cost estimate >$5 (deep+) | Confirm via CDG                         | Tránh waste token                  | E098     |

**Quy tắc:** Auto-upgrade **BẮT BUỘC** qua CDG — user xác nhận trước khi tăng cost. Auto-downgrade chỉ WARN (log), không cần CDG.

---

## 7. Profile interaction with `--scope`

| Scope                     | Profile compat               | Note                                 |
| ------------------------- | ---------------------------- | ------------------------------------ |
| `--scope=system`        | standard / deep / exhaustive | quick auto-bump → standard via E096 |
| `--scope=module=<name>` | quick / standard / deep      | exhaustive overkill cho 1 module     |
| `--scope=feat=<id>`     | quick / standard             | deep+ overkill cho 1 feat            |

---

## 8. Profile interaction with `--ci`

| Profile +`--ci`   | Behavior                                                                                                     |
| ------------------- | ------------------------------------------------------------------------------------------------------------ |
| `quick --ci`      | OK — fast feedback PR comment                                                                               |
| `standard --ci`   | OK — recommended for nightly + PR review                                                                    |
| `deep --ci`       | WARN — có thể timeout GitHub Actions; auto-downgrade → standard với E108 nếu CI runner timeout <30 min |
| `exhaustive --ci` | ERROR E012 — too long for CI; phải chạy local hoặc dedicated server                                      |

---

## 9. Coverage threshold details

### 9.1 Per-profile threshold (CD1-CD10)

Coverage % của mỗi dim được tính theo công thức:

```
coverage_pct(CD_N) = (entities_in_scope_with_dim_check) / (total_entities_in_scope) * 100
```

| Dim                | Công thức cụ thể                                            |
| ------------------ | --------------------------------------------------------------- |
| CD1 Business       | (requirements với ≥1 invariant) / (total requirements)        |
| CD2 Entity         | (entities với dependency graph node) / (total entities)        |
| CD3 Workflow       | (workflows với end-to-end trace) / (total workflows)           |
| CD4 API            | (public APIs với schema validated) / (total public APIs)       |
| CD5 Event          | (events với producer+consumer map) / (total events)            |
| CD6 RBAC           | (resources với full RBAC matrix) / (total resources)           |
| CD7 Data integrity | (FK/unique/NOT NULL constraints enforced) / (total expected)    |
| CD8 Observability  | (critical paths với log+metric+trace) / (total critical paths) |
| CD9 Regression     | (affected modules với test plan) / (total affected)            |
| CD10 Documentation | (invariants/dependencies với doc tiếng Việt) / (total)       |

### 9.2 Threshold gate behavior

```
Profile.threshold = {quick: 60%, standard: 80%, deep: 95%, exhaustive: 100%}

Phase 5 POST-GATE:
  for each active dim:
    if dim.coverage_pct < Profile.threshold:
      → CDG E090 escalate

  if Profile == exhaustive AND any active dim < 100%:
    → CDG E090 mandatory (KHÔNG cho continue mặc dù user accept gap)
    → exhaustive là audit/compliance mode, không cho skip
```

### 9.3 Failure cascade

Khi 1 dim FAIL threshold:

- **quick:** WARN, continue, ghi vào report
- **standard:** CDG E090, user choose accept/generate/cancel
- **deep:** CDG E090 + suggest auto-generate artifacts
- **exhaustive:** ABORT — exhaustive yêu cầu 100% mọi dim

---

## 10. Liên kết

- Argument detail: [02-arguments.md](02-arguments.md) §1 — `--profile` row
- Phase routing: [03-phase-routing.md](03-phase-routing.md) §3 (profile dispatch table)
- Error codes: [05-error-codes.md](05-error-codes.md) §2 (E090-E099 CDG)
- Real example: [`../wf-fix-bugs/05-execution-profiles.md`](../wf-fix-bugs/05-execution-profiles.md), [`../wf-legacy-scan/05-profiles-ips.md`](../wf-legacy-scan/05-profiles-ips.md)

---

## 11. Wave Dispatch Strategy (v2.0 NEW)

> Lý do tách 3-WAVE: 26 lanes parallel sẽ vi phạm CORE-025 (max 10 concurrent agents) + context budget overflow. Tách thành 3 wave sequential, mỗi wave ≤10 lanes parallel.

### 11.1 Wave overview

```
═══════════════════════════════════════════════════════
WAVE 1 (10 parallel, ~10-12 min) — Graphs only:
  CD1, CD2, CD3, CD4, CD5, CD6, CD7, CD11, CD16, CD17
  → KHÔNG phụ thuộc lane khác. Tận dụng graphs Phase 2.

WAVE 2 (10 parallel, ~12-15 min) — Cross-layer:
  CD13, CD15, CD18, CD23, CD24, CD25, CD28, CD30, CD31, CD37
  → Cross-ref FE↔BE + UX cross-component + Logistics + Compliance.

WAVE 3 (6 parallel, ~8-10 min) — Final cross-ref:
  CD9, CD26, CD29, CD38, CD39, CD40
  → Cross-validate Wave 1+2 outputs (regression, workflow viz, audit, UI gaps).

═══════════════════════════════════════════════════════
Tổng Phase 4: ~30-37 min cho EUREKA 17 modules
```

### 11.2 Per-wave gate threshold

| Wave   | max_concurrency | fail_threshold | Exit code if exceed | CDG code |
| ------ | :-------------: | :------------: | ------------------- | -------- |
| Wave 1 |       10        |       3        | 1 (FAIL_THRESHOLD STOP) | E120 |
| Wave 2 |       10        |       3        | 1 (FAIL_THRESHOLD STOP) | E121 |
| Wave 3 |        6        |       2        | 1 (FAIL_THRESHOLD STOP) | E122 |

- `pass + skip` count gộp vào PASS pool. `fail + timeout` count gộp vào fail pool.
- Nếu fail < threshold: exit 2 = PARTIAL_FAIL E123 WARN retry (orchestrator decide retry hoặc continue).
- Nếu fail ≥ threshold: STOP dispatch (KHÔNG advance wave kế tiếp), CDG escalate.

### 11.3 Dispatcher script

`.claude/scripts/wf-cmi/wave-coordinator.sh` với 5 subcommands:

| Subcommand    | Mục đích                                                                                |
| ------------- | -------------------------------------------------------------------------------------- |
| `init`      | Strip template metadata + populate session_id/profile vào `wave-status.json`          |
| `start`     | Mark wave started + populate lanes_active (filter canonical ∩ requested)                |
| `end`       | Aggregate per-lane lane-status.json → wave-status.json + gate threshold check          |
| `status`    | 3-wave summary với gate_status + counts + duration (read-only)                       |
| `gate-check`| Re-evaluate recorded gate_status (read-only, không re-aggregate)                      |

**Idempotency:** Re-run `end` cùng wave KHÔNG double-count `total_lanes_completed/failed` (subfield sum thay vì accumulation).

### 11.4 Profile → Wave activation mapping (v2.0)

| Profile      | Wave 1 lanes               | Wave 2 lanes                                                             | Wave 3 lanes                              |
| ------------ | -------------------------- | ------------------------------------------------------------------------ | ----------------------------------------- |
| `quick`    | CD1-4, CD7, CD16, CD17 (7) | _SKIPPED_                                                              | _SKIPPED_                               |
| `standard` | CD1-7, CD11, CD16, CD17 (10) | CD13, CD15, CD18 (3)                                                  | CD9 (1)                                  |
| `deep`     | full Wave 1 canonical (10)  | full Wave 2 canonical (10) — incl. CD23-25, CD28, CD30, CD31, CD37    | full Wave 3 canonical (6) — incl. CD26, CD29, CD38-40 |
| `exhaustive` | deep + LLM enhance + deferred lanes | deep + LLM enhance | deep + LLM enhance |

### 11.5 Subset activation qua `--dims`

User có thể `--dims=CD11,CD13,CD28` để chỉ activate subset cụ thể. Dispatcher route lanes về Wave tương ứng:

- `CD11` → Wave 1
- `CD13` → Wave 2
- `CD28` → Wave 2

Wave 3 sẽ SKIPPED nếu không có lane Wave 3 trong `--dims`. Coverage matrix vẫn populate 35 dims nhưng các lane KHÔNG activate sẽ có `status="NOT_RUN"` (phân biệt với `status="SKIPPED"` cho deferred lanes).

### 11.6 Liên kết

- Wave coordinator script: [`.claude/scripts/wf-cmi/wave-coordinator.sh`](../../../.claude/scripts/wf-cmi/wave-coordinator.sh)
- Wave status template: [`templates/wave-status.json`](../../../.claude/skills/workflow/wf-cmi/templates/wave-status.json)
- Phase 4 dispatcher procedure: [`procedures/phase4-coverage-dispatch.md`](../../../.claude/skills/workflow/wf-cmi/procedures/phase4-coverage-dispatch.md)
- Migration notes v1→v2: [`v2-migration-notes.md`](v2-migration-notes.md)
- Pattern: [`../../03-design-patterns/02-ci-first-integration.md`](../../03-design-patterns/02-ci-first-integration.md) (cache TTL per profile)
