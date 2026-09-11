# 02 — Arguments

> **Mục đích file:** Đặc tả 16 arguments của skill — type, default, profile system, scenario detection, validation.

---

## 1. Bảng arguments

| Arg | Type | Default | Required | Mô tả |
|-----|------|---------|----------|-------|
| `[feature-name \| REQ-ID \| FEAT-ID]` | string (positional) | — | Có (trừ `--resume` / `--status` / `--features`) | Feature cần implement |
| `--system=<slug>` | string | auto-derive từ registry | Không | Override `$SYSTEM_SLUG` khi ambiguous hoặc feature không có trong registry (v5.0) |
| `--module=<n>` | string | auto-detect | Không | Chỉ định module nếu ambiguous |
| `--extend` | flag | — | Không | Force scenario = EXTEND |
| `--modify` | flag | — | Không | Force scenario = MODIFY |
| `--skip-tests` | flag | — | Không | Bỏ qua viết tests |
| `--skip-review` | flag | — | Không | Bỏ Phase 4 review agents (CHỈ dùng cho hotfix khẩn) |
| `--component=<type>` | enum | All | Không | `entity` / `service` / `endpoint` / `frontend` / `test` |
| `--resume` | flag | — | Không | Resume từ checkpoint |
| `--micro-task=MT-FEAT-NNN` | string | — | Không | Implement chỉ 1 micro-task (cần A7-EXT trong task file) |
| `--fresh` | flag | — | Không | Archive session cũ, bắt đầu mới |
| `--parallel` | flag | Off | Không | Contract-first parallel agents Phase 3 |
| `--features=FEAT-001,...` | CSV | Off | Không | Multi-feature mode (load `flow-multi.md`) |
| `--profile=<name>` | enum | auto-detect by file count | Không | `quick` / `standard` / `deep` / `exhaustive` |
| `--no-cache` | flag | Off | Không | Bypass pattern cache (luôn fresh scan) |
| `--status` | flag | — | Không | Hiển thị tiến độ session, không thực thi |
| `--from-fix-bugs[=<session_id>]` | string optional | — | Không | (v5.2+) Consume `fix-impact.json` từ wf-fix-bugs session, auto-resolve latest completed nếu không pass `<id>` |

---

## 2. Argument interactions

| Combo | Behavior |
|-------|----------|
| `--resume` + positional | Positional bỏ qua → resume từ session cũ |
| `--status` + positional | Chỉ hiển thị status, exit 0 (không thực thi) |
| `--fresh` + có session cũ | Archive cũ vào `$FEATURE_DIR/archived/`, tạo session mới |
| `--profile=quick` + `--parallel` | WARNING — `--parallel` ignored (quick = sequential by design) |
| `--profile=quick` + `--skip-review` | Skip ALL review agents (override profile review set) |
| `--features=...` + positional | Positional ignored — load `flow-multi.md` |
| `--component=entity` + `--profile=deep` | Profile applies, nhưng chỉ implement entity files |
| `--from-fix-bugs` không có `<id>` | Auto-resolve latest completed session từ `_index/sessions.jsonl` |
| `--from-fix-bugs=<id>` + session không tồn tại | E102 — registry lookup fail; ESCALATE |
| `--extend` + `--modify` cùng lúc | ERROR — mutually exclusive |

---

## 3. Profile System

Profile điều phối **độ sâu xử lý** xuyên suốt Phase 2-4 — số batches, agent reviewers, độ phủ tests.

### Profile Matrix

| Profile | Phase 3 mode | Phase 4 review agents | Tests run | Estimated time | Use case |
|---------|-------------|----------------------|-----------|---------------|----------|
| `quick` | sequential, no waves | code-reviewer only | smoke (failed-fast) | 5-15 min | Hotfix, prototype, throwaway |
| `standard` (default) | sequential | code-reviewer + qa-lead | full unit | 15-45 min | Daily dev work |
| `deep` | parallel waves auto | code-reviewer + qa-lead + security | unit + integration | 30-90 min | Production-ready feature |
| `exhaustive` | parallel waves + e2e | code-reviewer + qa-lead + security + accessibility-auditor + performance-benchmarker | unit + integration + e2e | 60-180 min | Release-candidate |

### Profile Auto-Resolution

Khi `--profile` KHÔNG được set, skill tự chọn dựa trên scope file count:

| File count trong scope | Profile auto-resolved |
|------------------------|----------------------|
| ≤ 5 | `quick` |
| 6–30 | `standard` |
| 31–100 | `deep` |
| > 100 | `exhaustive` |

User chỉ định `--profile=<name>` luôn override auto-recommendation.

Resolver: `.claude/scripts/wf-implement-feature/implement-resolve-profile.sh` (stdout = profile, stderr = note).

---

## 4. Implementation Scenarios

Skill detect scenario tự động từ flag + registry + existing code:

| Scenario | Khi nào | Phase 0 Existing Analysis | CORE-020 Safety Gate |
|----------|---------|---------------------------|---------------------|
| **NEW** | Default — feature chưa có code | Skip | Lightweight search (cảnh báo nếu tìm thấy code) |
| **EXTEND** | `--extend` hoặc registry impl_status != not_started | Required | Full safety scan |
| **MODIFY** | `--modify` hoặc user xác nhận | Required | Full safety scan + impact analysis (GitNexus) |

**LEGACY_MODE override:** Khi project có `legacy-scan/project-context.md > 500 bytes` (CORE-021), skill đọc `implementation_strategy` per feature từ task file → route VERIFY_ONLY / COMPLETE_EXISTING / IMPLEMENT_NEW (CORE-019).

---

## 5. Validation rules

| Arg | Rule | Error code |
|-----|------|------------|
| `[feature-name]` | Match FEAT-ID `^FEAT-[A-Z]+-[0-9]+$` OR REQ-ID `^REQ-[A-Z]+-[0-9]+$` OR free-form text | E103 |
| `--system=<slug>` | Match `^[a-z0-9-]+$` (lowercase-kebab) | E103 |
| `--profile` | In set `{quick, standard, deep, exhaustive}` | (silent default → standard) |
| `--component` | In set `{entity, service, endpoint, frontend, test}` | E103 |
| `--from-fix-bugs=<id>` | Session phải tồn tại trong `_index/sessions.jsonl` với status=`completed` | E102 |
| Registry lookup | FEAT-ID/REQ-ID có trong `req-registry.json` | E103 |
| Per-feature lock | Acquire trong < 5s, không stale (PID alive, age <60min) | E901 |

---

## 6. Examples

```bash
# Default standard profile
/wf-implement-feature FEAT-CRM-CUST-001

# Quick hotfix
/wf-implement-feature FEAT-CRM-CUST-001 --profile=quick --skip-review

# Deep production-ready
/wf-implement-feature FEAT-CRM-CUST-001 --profile=deep --parallel

# EXTEND existing module (auto Phase 0 Existing Analysis)
/wf-implement-feature FEAT-CRM-CUST-001 --extend

# Resume session đang dở
/wf-implement-feature FEAT-CRM-CUST-001 --resume

# Status check
/wf-implement-feature FEAT-CRM-CUST-001 --status

# Multi-feature batch
/wf-implement-feature --features=FEAT-CRM-CUST-001,FEAT-CRM-ORD-001

# Single component (entity only)
/wf-implement-feature FEAT-CRM-CUST-001 --component=entity

# Cross-skill từ fix-bugs (v5.2+)
/wf-implement-feature FEAT-CRM-CUST-001 --from-fix-bugs

# Cross-skill từ specific session
/wf-implement-feature FEAT-CRM-CUST-001 --from-fix-bugs=2026-05-10-crm-customer-mgmt-01

# Override system khi feature không trong registry
/wf-implement-feature my-orphan-feature --system=crm

# Fresh restart (archive sessions cũ)
/wf-implement-feature FEAT-CRM-CUST-001 --fresh
```

---

## 7. Liên kết

- Profile resolver: [`.claude/scripts/wf-implement-feature/implement-resolve-profile.sh`](../../../.claude/scripts/wf-implement-feature/)
- Lock script: [`.claude/scripts/wf-implement-feature/implement-acquire-lock.sh`](../../../.claude/scripts/wf-implement-feature/)
- Error codes detail: [05-error-codes.md](05-error-codes.md)
- Profile execution: [03-phase-routing.md](03-phase-routing.md) §Profile dispatch
- Cross-skill `--from-fix-bugs`: [04-file-contract.md](04-file-contract.md) §consumes_from + [08-tradeoffs-adr.md](08-tradeoffs-adr.md) ADR-005
