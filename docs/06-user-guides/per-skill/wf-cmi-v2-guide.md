# Hướng dẫn Sử dụng wf-cmi v2.0 (Gói C++ Logistics)

> **Phiên bản:** v2.0.0 · **Ngày:** 2026-05-16 · **Ngôn ngữ:** Tiếng Việt
>
> Hướng dẫn dành cho người dùng không chuyên kỹ thuật muốn dùng `/wf-cmi` để kiểm tra toàn vẹn liên module cho hệ thống ERP đa module (target chính: EUREKA-2026 logistics Việt-Trung).

---

## Mục lục

1. [Giới thiệu](#1-giới-thiệu)
2. [Khi nào dùng wf-cmi](#2-khi-nào-dùng-wf-cmi)
3. [Bắt đầu nhanh (Quick Start)](#3-bắt-đầu-nhanh-quick-start)
4. [Chọn Profile phù hợp](#4-chọn-profile-phù-hợp)
5. [26 Lanes (Coverage Dimensions) — Gói C++ Logistics](#5-26-lanes-coverage-dimensions--gói-c-logistics)
6. [3-Wave Dispatch Strategy](#6-3-wave-dispatch-strategy)
7. [9 SSOT Files cần chuẩn bị](#7-9-ssot-files-cần-chuẩn-bị)
8. [Pipeline 8 Phases](#8-pipeline-8-phases)
9. [Output Files](#9-output-files)
10. [Critical Decision Gate (CDG)](#10-critical-decision-gate-cdg)
11. [Resume sau Interrupt](#11-resume-sau-interrupt)
12. [Multi-session Safety (Protocol 22)](#12-multi-session-safety-protocol-22)
13. [Troubleshooting](#13-troubleshooting)
14. [Migration từ v1.0](#14-migration-từ-v10)
15. [FAQ](#15-faq)

---

## 1. Giới thiệu

### wf-cmi là gì?

`/wf-cmi` (Cross-Module Integrity) là skill chuyên kiểm tra **tính toàn vẹn liên module** cho hệ thống ERP phức tạp. Không giống các skill khác chỉ kiểm tra trong phạm vi 1 module, `wf-cmi` đánh giá:

- Mối quan hệ giữa **18+ modules** (CRM, Sales, Finance, Logistics, HR, ...)
- Sự nhất quán **cross-layer** (FE component ↔ BE API ↔ DB schema)
- Tuân thủ **quy định pháp lý** (VN-PDPL, TT 78/2021 e-invoice, CN-PIPL, GDPR)
- **Logistics-critical** rules (multi-currency VND/CNY/USD, numbering Invoice/BOL/Customs, multi-language VN/CN/EN)

### Khác gì với wf-fix-bugs?

| Aspect | wf-fix-bugs | wf-cmi |
|--------|-------------|--------|
| Scope | 1 module hoặc feature | Toàn system hoặc cross-module |
| Mục đích | Sửa bug đã biết | Phát hiện gap chưa biết |
| Output | Code fix | Báo cáo + suggestions (KHÔNG sửa code) |
| Khi dùng | Có bug report | Định kỳ audit / Pre-release |

### v2.0 có gì mới so với v1.0?

| Aspect | v1.0 | v2.0 |
|--------|------|------|
| Số lanes | 10 (CD1-CD10) | **26** (CD1-7, CD9, CD11, CD13, CD15-18, CD23-26, CD28-31, CD37-40) |
| Wave dispatch | 1-2 wave | **3 wave** (graphs / cross-layer / final cross-ref) |
| Logistics rules | Không có | **★★★** CD28 MDM + CD30 Time & Numbering + CD31 Money & Tax |
| Compliance | Cơ bản | **★★★** CD37 với 5 VN + 3 CN + 3 intl regulations |
| Thời gian deep profile | ~60 min | ~90 min |
| Output schema | v1 | **v2 backward-compat** (consumer v1 vẫn đọc được) |

---

## 2. Khi nào dùng wf-cmi

### Nên dùng khi:

- ✅ **Trước release lớn** (audit toàn diện toàn system, profile=deep)
- ✅ **Tháng/Quý audit** (compliance + integrity baseline, profile=exhaustive)
- ✅ **Sau merge nhánh lớn** (validate cross-module impact, profile=standard --since=main)
- ✅ **Bug cross-module nghi ngờ** (subset dims, profile=quick --dims=CD1,CD11,CD28)
- ✅ **Onboarding repo mới** (hiểu tổng thể không sửa code, profile=standard)

### KHÔNG nên dùng khi:

- ❌ Chỉ cần fix 1 bug đã biết → dùng `/wf-fix-bugs`
- ❌ Module mới chưa có code → dùng `/wf-design` + `/wf-implement-feature`
- ❌ Chưa có `req-registry.json` → dùng `/wf-brainstorm` + `/wf-analyze-requirements` trước
- ❌ Project < 5 modules → wf-cmi overkill, dùng `/wf-verify-sync` + `/wf-preflight`

---

## 3. Bắt đầu nhanh (Quick Start)

### Bước 1: Kiểm tra điều kiện tiên quyết

```bash
# Có req-registry.json không?
test -f .mc-data/docs/_meta/req-registry.json && echo "OK" || echo "MISSING"

# Có code để scan không? (≥1 .cs, .ts, .tsx file)
find apps -type f \( -name "*.cs" -o -name "*.ts" -o -name "*.tsx" \) 2>/dev/null | head -1
```

### Bước 2: Chạy quick scan đầu tiên

```bash
/wf-cmi --profile=quick
```

Sau ~5-10 phút, bạn sẽ thấy:
- `integrity-report.md` (≤55 dòng tiếng Việt, top 10 violations)
- `coverage-matrix.json` (35 dim entries)
- `integrity-impact.json` (schema v2)

### Bước 3: Đọc báo cáo

Mở `.mc-data/work/wf-cmi/sessions/{LATEST}/phase8-report/integrity-report.md`. Đọc 5 sections:
1. **Tổng quan**: Status + coverage % + số violations
2. **Coverage matrix**: 7 lanes (quick profile) với pass/fail per dim
3. **Top 10 violations**: Sắp xếp theo severity (MUST > HIGH > MEDIUM > LOW)
4. **Suggested artifacts**: Test cases / contracts / invariants nên tạo
5. **Next steps**: Hành động tiếp theo (re-run deep / fix bug / accept gap)

### Bước 4: Decide

- ✅ **0 MUST violations** → safe to ship
- ⚠ **HIGH severity** → đánh giá rủi ro + tạo ticket
- 🛑 **MUST severity** → BLOCK release, fix trước

---

## 4. Chọn Profile phù hợp

| Tình huống | Profile khuyến nghị | Thời gian | Lanes | Cost ước tính |
|-------------|---------------------|-----------|-------|---------------|
| Trước commit local module | `quick --scope=module=<name>` | 5-10 min | 7 | ~$0.05 |
| Trước PR review | `standard --since=main` | 15-30 min | 13 | ~$0.50 |
| Trước merge to main | `standard` toàn system | 15-30 min | 13 | ~$0.50 |
| Trước release/deploy | `deep` | 55-90 min | **26** | ~$2.50 |
| Audit tháng/quý | `exhaustive` | 120-180 min | 30+ | ~$7.50 |
| Bug cross-module | `quick --dims=CD1,CD2,CD11,CD28` | 5-10 min | subset | ~$0.05 |
| CI nightly | `--ci --profile=standard` | <30 min | 13 | ~$0.50 |
| CI release gate | `--ci --profile=deep --since=main` | <90 min | 26 | ~$2.50 |

> **Default:** `standard` cho daily work. Đừng dùng `deep` mỗi lần — tốn token.

---

## 5. 26 Lanes (Coverage Dimensions) — Gói C++ Logistics

26 lanes chia thành 7 nhóm:

### Core (8 lanes — v1.0 carried)
- **CD1** Business domain consistency
- **CD2** Entity dependency graph
- **CD3** Workflow coverage
- **CD4** API contract sync
- **CD5** Event coverage
- **CD6** Permission/RBAC matrix
- **CD7** Data integrity (FK + unique + NOT NULL)
- **CD9** Regression coverage (with `--since`)

### Frontend (3 lanes — v2 NEW)
- **CD11** FE Component Contracts (props type completeness, naming convention)
- **CD13** FE↔BE Contract Sync (FE call existent BE endpoint, HTTP method match)
- **CD15** UI Permission Mirror (UI gate matches BE auth, admin action protected)

### Backend (3 lanes — v2 NEW)
- **CD16** Domain Logic Integrity (DDD aggregate boundary, domain event, VO immutability)
- **CD17** Persistence Consistency (EF migration drift, missing index, schema-entity sync)
- **CD18** CQRS Pipeline Integrity (command-handler binding, validator coverage)

### UX (4 lanes — v2 NEW)
- **CD23** UX Design System Consistency (color tokens, button variants — brand-guardian gate)
- **CD24** UX Display Format Consistency (date/number/currency format, VND no-decimal TT 78/2021)
- **CD25** UX Flow Continuity (broken user journey, missing confirmation dialog)
- **CD26** UX Workflow Visibility ★★★ (status badge, progress indicator cho Booking/Invoice)

### Logistics ★★★ (3 lanes — v2 NEW)
- **CD28** MDM Consistency (master data ownership, unique constraint, reference data sync)
- **CD30** Time & Numbering Integrity (timezone-aware datetime, Invoice/BOL/Customs uniqueness)
- **CD31** Money & Tax Integrity (Money VO, multi-currency, VAT VN 8% + CN 13%/9%/6%)

### Compliance (2 lanes — v2 NEW)
- **CD29** Audit Trail Completeness (audit table existence, PII access logging VN-PDPL)
- **CD37** Regulatory Compliance ★★★ (5 VN + 3 CN + 3 intl regulations, cross-border CN→VN)

### Implementation ★ (3 lanes — v2 NEW additions)
- **CD38** UI Implementation Coverage (orphan API, missing CRUD UI, workflow state trigger)
- **CD39** Error UX & Recovery (error boundary Next.js, Vietnamese error message)
- **CD40** Print & Export Consistency (TT 78/2021 e-invoice, BOL VN+EN+CN bilingual)

### SKIPPED (9 lanes — v2.0 defer cho v2.1+)
- CD8 Observability, CD10 Documentation, CD12 FE State, CD14 FE i18n, CD19 Distributed TX, CD20 Security Deep, CD21 Reliability, CD22 Config & Secret, CD27 UX Microcopy

### SKELETON (5 lanes — v3.0 deferred)
- CD32-CD36 (Document Lifecycle, Notification, Search, MultiTenant, Operational) — chỉ placeholder, KHÔNG dispatch ở v2.0

---

## 6. 3-Wave Dispatch Strategy

Lý do tách 3 wave: 26 lanes parallel sẽ vượt giới hạn 10 concurrent agents + context budget. Dispatcher (`wave-coordinator.sh`) chạy sequentially:

```
═══════════════════════════════════════════════════════
WAVE 1 (~10-12 min) — 10 lanes graphs-only:
  CD1, CD2, CD3, CD4, CD5, CD6, CD7, CD11, CD16, CD17

WAVE 2 (~12-15 min) — 10 lanes cross-layer:
  CD13, CD15, CD18, CD23, CD24, CD25, CD28, CD30, CD31, CD37

WAVE 3 (~8-10 min) — 6 lanes final cross-ref:
  CD9, CD26, CD29, CD38, CD39, CD40
═══════════════════════════════════════════════════════
```

### Per-wave gate threshold

| Wave | max parallel | fail threshold | Hậu quả vượt threshold |
|------|--------------|----------------|--------------------------|
| Wave 1 | 10 | 3 fail/timeout | STOP dispatch (E120) — KHÔNG advance Wave 2 |
| Wave 2 | 10 | 3 fail/timeout | STOP dispatch (E121) |
| Wave 3 | 6 | 2 fail/timeout | STOP dispatch (E122) |

Dưới threshold (1-2 fail) → PARTIAL_FAIL E123, orchestrator có thể retry.

---

## 7. 9 SSOT Files cần chuẩn bị

Một số lanes yêu cầu **Single Source of Truth** (SSOT) files trong `.mc-data/docs/_meta/`. Nếu thiếu, lane sẽ ESCALATE (chặn pipeline).

| File | Cho lane(s) | Mandatory? | Người populate |
|------|--------------|------------|------------------|
| `rbac-permission-catalog.json` | CD15, CD38 | ✅ Mandatory | security + architect |
| `ux-conventions.json` | CD23, CD24, CD25 | ✅ Mandatory | ux-designer + brand-guardian |
| `workflow-state-machines.json` | CD3, CD26, CD38 | ✅ Mandatory cho CD26 | business-analyst + architect |
| `mdm-canonical-entities.json` | CD28 | ✅ Mandatory | data-engineer + BA + logistics-expert |
| `compliance-mapping.json` | CD37 | ✅ Mandatory | compliance-expert + legal-expert |
| `audit-critical-entities.json` | CD29 | ✅ Mandatory | data-engineer + compliance-expert |
| `ui-interactivity-spec.json` | CD38 | ✅ Mandatory | ux-researcher + frontend-developer + BA |
| `error-code-catalog.json` | CD39 | ⚠ Optional (fallback Grep) | architect + tech-writer |
| `print-export-templates.json` | CD40 | ⚠ Optional (fallback filesystem) | ui-designer + tech-writer |

### Cách populate

Templates đã có sẵn tại `plans/wf-cmi/*.eureka-template.json`. Cách dùng:

```bash
# Copy template → location runtime, strip metadata
cp plans/wf-cmi/rbac-permission-catalog.eureka-template.json \
   .mc-data/docs/_meta/rbac-permission-catalog.json

# Strip _template_notes + _instructions
jq 'del(._template_notes, ._instructions, ._schema_notes)' \
   .mc-data/docs/_meta/rbac-permission-catalog.json > /tmp/clean.json
mv /tmp/clean.json .mc-data/docs/_meta/rbac-permission-catalog.json

# Sau đó edit file với giá trị thực tế EUREKA (91 permissions, 13 roles, 17 modules)
```

> **Tip:** Mỗi template có section `_instructions` hướng dẫn populate. Đọc trước khi sửa.

---

## 8. Pipeline 8 Phases

| Phase | Mục đích | Output chính |
|-------|---------|---------------|
| 1. Init + CI PRE-GATE | Setup session, detect GitNexus/Serena, load SSOTs | `integrity-status.json` |
| 2. Discovery (**13 graphs** v2) | Build entity/module/workflow/API/event/RBAC graphs + 7 plugin graphs (FE/BE) | 13 graph JSON files |
| 3. Invariant Registry | 3-pass LLM phát hiện cross-module invariants | `business-invariants.json` (sidecar) |
| 4. **Coverage Dispatch (3-WAVE)** | Spawn 26 lane agents qua 3 wave sequential | 26 lane signal files |
| 5. Aggregate | Tổng hợp signals → 35-dim coverage matrix v2 | `coverage-matrix.json` |
| 6. Regression Map | Predictive impact qua GitNexus hoặc `--since` diff | `regression-map.json` |
| 7. GAP + CDG | Đề xuất artifact (test/contract/invariant) | `gap-suggestions.json` |
| 8. Report | Render báo cáo cuối + cross-skill artifact | `integrity-report.md` + `integrity-impact.json` |

---

## 9. Output Files

Sau khi pipeline hoàn tất, output ở `.mc-data/work/wf-cmi/sessions/{SESSION_ID}/`:

```
sessions/2026-05-16-system-deep-01/
├── integrity-status.json              # SSOT pipeline state
├── session-log.json                   # Execution trace
├── error-ledger.json                  # Error tracking (nếu có)
├── phase1-init/
│   └── Phase1-report.md
├── phase2-discovery/
│   ├── entity-graph.json
│   ├── module-graph.json
│   ├── ... (13 graphs)
│   └── Phase2-report.md
├── phase3-invariant/
│   ├── business-invariants.json       # Sidecar — KHÔNG bump registry
│   └── Phase3-report.md
├── phase4-coverage/
│   ├── wave-status.json               # 3-wave tracking
│   ├── lanes/CD11/
│   │   ├── signals.json
│   │   ├── lane-status.json
│   │   └── CD11-report.md
│   └── ... (26 lane subdirs)
├── phase5-aggregate/
│   ├── coverage-matrix.json           # 35 dims (26 active + 9 SKIPPED)
│   ├── coverage-report.md
│   └── Phase5-report.md
├── phase6-regression/
│   ├── regression-map.json
│   └── Phase6-report.md
├── phase7-gap-cdg/
│   ├── gap-suggestions.json
│   └── Phase7-report.md
└── phase8-report/
    ├── integrity-report.md            # ≤55 dòng tiếng Việt, top 10 violations
    └── integrity-impact.json          # Schema v2 cho consumer skills
```

### Đọc gì trước?

1. **`phase8-report/integrity-report.md`** — Tổng quan + top 10 violations
2. **`phase5-aggregate/coverage-matrix.json`** — Coverage detail per dim
3. **`phase4-coverage/lanes/CD{N}/signals.json`** — Detail signal cụ thể nếu cần fix

---

## 10. Critical Decision Gate (CDG)

Một số tình huống cần user decision (không auto-decide). CDG sẽ prompt `AskUserQuestion`:

| Code | Tình huống | Options |
|------|-------------|---------|
| E090 | Coverage < threshold | Accept gap / Generate artifacts / Cancel |
| E094 | Sidecar artifact append (business-invariants) | Accept / Reject / Modify |
| E141-E146 | SSOT mandatory missing | Populate SSOT / Skip lane / Cancel |
| E120-E122 | Wave fail threshold exceeded | Retry / Skip wave / Cancel |
| E091 | Cross-domain conflict detected (Phase 3) | Auto-bump profile / Accept current / Cancel |

> **Mode `--ci`**: Tự động accept default option. KHÔNG block CI pipeline.

---

## 11. Resume sau Interrupt

Nếu session bị interrupt (Ctrl+C, máy crash, network down):

```bash
# Tự động resume từ last checkpoint
/wf-cmi --resume

# Hoặc target session cụ thể
/wf-cmi --resume --session-id=2026-05-16-system-deep-01
```

Resume sẽ:
1. Detect last completed phase từ `integrity-status.json`
2. Skip lanes đã PASS (KHÔNG re-spawn)
3. Re-execute lane RUNNING bị cắt
4. Continue Phase 5-8 bình thường

> **Stale lock:** Lock age > 30 min → auto-release. Lock < 30 min → wait hoặc force release qua CDG.

---

## 12. Multi-session Safety (Protocol 22)

Cho phép chạy nhiều session song song trên cùng máy:

```bash
# Session A: full deep scan
/wf-cmi --profile=deep &

# Sau 30s, session B: quick subset
/wf-cmi --profile=quick --dims=CD11,CD13 &
```

Cơ chế:
- **Read locks**: Cho phép N reader đồng thời (Phase 2 Discovery, Phase 5 Aggregate)
- **Write locks**: Độc quyền (Phase 7 CDG sidecar APPEND)
- Heartbeat 30s update `.mc-data/work/wf-cmi/_index/sessions.jsonl`

Limit: 5 sessions quick+standard, 2 sessions deep+exhaustive trên cùng máy.

---

## 13. Troubleshooting

### "E144: SSOT mandatory missing"

Lane (vd CD15) yêu cầu SSOT chưa có. Populate trước:

```bash
cp plans/wf-cmi/rbac-permission-catalog.eureka-template.json \
   .mc-data/docs/_meta/rbac-permission-catalog.json
# Edit file với giá trị EUREKA thực tế
/wf-cmi --resume
```

### "E120: Wave 1 batch fail threshold exceeded"

≥3 lanes Wave 1 fail. Options:
- Đọc `wave-status.json` xem lane nào fail
- Đọc `lane-status.json` per lane xem reason
- Fix root cause hoặc `--dims=` exclude lane đó

### "E009: Context budget > 90%"

Pipeline auto-stop. Resume sau:
```bash
/wf-cmi --resume
```

### "Pipeline chạy lâu hơn 90 min"

- Check `wave-status.json` xem wave nào chậm
- Reduce scope: `--scope=module=<name>` hoặc `--dims=` subset
- Profile=deep với EUREKA 17 modules tối ưu ~55-75 min; nếu >90 min do GitNexus index stale → re-index

### "Coverage thấp bất ngờ"

- Check `coverage-matrix.json` per dim
- Verify SSOT files populated đầy đủ (vd compliance-mapping có ≥10 regulations)
- Đọc lane signals.json xem có signals dạng "false positive" không

---

## 14. Migration từ v1.0

### Backward-compat

✅ **Tốt:** Pipeline 8 phase + cách trigger `/wf-cmi` + output directory structure không thay đổi
✅ **Tốt:** Cross-skill artifact `integrity-impact.json` v2 vẫn có TẤT CẢ v1 fields → consumer skill v1 đọc được bình thường

### Breaking changes

⚠ **Profile=deep** từ 10 lanes → 26 lanes → thời gian từ ~60 min → ~90 min
   - Migration: Cập nhật CI timeout từ 60 min → 120 min (an toàn margin)
   - Hoặc dùng `--profile=standard` cho CI (13 lanes, <30 min)

⚠ **9 SSOT files mới** mandatory cho 7 lanes (CD15, CD23-25, CD28-31, CD37, CD38) + 2 optional (CD39, CD40)
   - Migration: Populate templates trước khi chạy `--profile=deep` lần đầu

⚠ **Schema bump v1→v2** cho 3 artifacts (`integrity-status.json`, `coverage-matrix.json`, `integrity-impact.json`)
   - Migration: Consumer skills cần detect `$schema` field để route reader. Detail tại `v2-migration-notes.md`.

### Chi tiết migration

Xem [`docs/04-skill-design/wf-cmi/v2-migration-notes.md`](../../04-skill-design/wf-cmi/v2-migration-notes.md)

---

## 15. FAQ

**Q: Tôi cần biết coding để dùng wf-cmi?**
A: Không. Chỉ cần đọc tiếng Việt + understand business workflow. Báo cáo output viết cho non-specialist.

**Q: Skill có sửa code không?**
A: KHÔNG. wf-cmi chỉ phát hiện + báo cáo. Sửa code dùng `/wf-fix-bugs` riêng.

**Q: Có thể bỏ qua 1 lane không?**
A: Có. Dùng `--dims=` để chỉ activate subset lanes mong muốn.

**Q: Mất bao nhiêu tiền token cho 1 lần chạy deep?**
A: Ước tính ~$2.50/lần cho EUREKA 17 modules. Exhaustive ~$7.50. Quick chỉ ~$0.05.

**Q: Có thể chạy CI không?**
A: Có. `/wf-cmi --ci --profile=standard` cho PR review. Profile=deep cho release gate (timeout 90 min).

**Q: Báo cáo có tiếng Việt không?**
A: Có. Tất cả Phase report + integrity-report.md đều tiếng Việt. JSON outputs có field names English (chuẩn AI context).

**Q: 9 SSOT files có nhiều quá, có cách rút gọn không?**
A: Chỉ populate SSOT cho lanes bạn quan tâm. Lanes có SSOT optional (CD39/CD40) có fallback. Lanes mandatory (CD15/CD23-25/CD28-31/CD37/CD38) nếu skip thì pipeline ESCALATE → bạn có thể `--dims=` exclude lane đó.

**Q: Có thể chạy chỉ logistics-critical lanes (★★★) không?**
A: Có. `/wf-cmi --profile=deep --dims=CD28,CD30,CD31,CD37,CD38,CD39,CD40` (~30 min, focus logistics).

---

## Liên kết

- Skills catalog: [`docs/01-architecture/07-skills-catalog.md`](../../01-architecture/07-skills-catalog.md)
- Execution profiles canon: [`docs/04-skill-design/wf-cmi/05-execution-profiles.md`](../../04-skill-design/wf-cmi/05-execution-profiles.md)
- Migration notes v1→v2: [`docs/04-skill-design/wf-cmi/v2-migration-notes.md`](../../04-skill-design/wf-cmi/v2-migration-notes.md)
- SKILL.md: [`.claude/skills/workflow/wf-cmi/SKILL.md`](../../../.claude/skills/workflow/wf-cmi/SKILL.md)
- CHANGELOG v2.0.0: [`CHANGELOG.md`](../../../CHANGELOG.md)
- Templates SSOT: [`plans/wf-cmi/*.eureka-template.json`](../../../plans/wf-cmi/)
