# 09 — Evals & Test Cases

> **Mục đích file:** Đặc tả 19 evals match `evals/evals.json` — coverage matrix args × phases × profiles × scenarios.

---

## 1. Bảng test cases (19 evals)

| ID | Type | Scope | Profile | Mục đích kiểm tra |
|----|------|-------|---------|-------------------|
| 1 | integration | Standard NEW feature | standard | Full pipeline: TDD + parallel review + registry update + phase-summary tiếng Việt |
| 2 | smoke | `--status` mode | — | Status check không thực thi, không tạo file code |
| 3 | edge | Feature không tồn tại | — | Error E103 (alias E003) — feature/REQ-ID lookup fail |
| 4 | resume | Resume từ checkpoint Phase 3 batch 2 | standard | KHÔNG duplicate work — chỉ implement Batch 3 |
| 5 | integration | EXTEND scenario | standard | Phase 0a Existing Analysis chạy, existing-patterns.json đầy đủ |
| 6 | integration | Template Usage Rule (CORE-031) | standard | Mọi phase READ template trước khi write |
| 7 | integration | Decision Registry tracking (Protocol 12) | standard | decision-registry.json appended + no conflict |
| 8 | integration | Phase 5a Cross-Validation Loop | standard | Auto-correction loop chạy 1-3 iter, auto-fix REQ-ID missing |
| 9 | integration | CORE-028 phase-summary.md | standard | Tiếng Việt + next step + non-specialist readable |
| 10 | edge | `--skip-review --skip-tests` hotfix path | standard | Phase 4 skip, Phase 5a vẫn chạy với reduced checks |
| 11 | integration | Multi-feature flow (`--features=...`) | standard | flow-multi.md loaded, dependency graph built, isolated outputs |
| 12 | integration | v4.0 Session Isolation (multi-run) | standard | 2 sessions cùng feature → 2 subdirs riêng, current.txt trỏ latest |
| 13 | integration | v4.0 `--fresh` archive | standard | Sessions cũ moved to archived/, KHÔNG xóa data |
| 14 | integration | Profile=quick | quick | profile.txt=quick, single reviewer, sequential, smoke tests |
| 15 | integration | Profile=deep | deep | profile.txt=deep, 3 reviewers, parallel waves, contracts.json |
| 16 | integration | Pattern Cache HIT (2 features cùng module) | standard | Cache MISS lần 1, HIT lần 2, saved_tokens_estimated ≥5000 |
| 17 | edge | Multi-dev safety (JSONL append-only) | standard | 2 hostnames → 2 lines JSONL khác short_host, không conflict |
| 18 | edge | Error Ledger Trigger (E301 tests fail) | standard | error-ledger.json lazy-init, entry có code/severity/phase/action |
| 19 | integration | Output Schema v2.0 + consumer_hints | standard | impl-status schema_version=2.0, 3 consumer_hints sections populated |

---

## 2. Test case detail (extract)

### TC-01 — Standard NEW feature (smoke + integration full pipeline)

**Setup:**
```bash
# Working directory: Z:/Working/MCV3/mock-project/
# Feature: FEAT-CRM-CUST-001 Customer Management
# Tech: NestJS + TypeORM + PostgreSQL
# Files prerequisite:
#   .mc-data/docs/phase2-features/sys-crm/mod-crm/customer-management.md
#   .mc-data/docs/phase5-implementation/tasks/sys-crm/mod-crm/customer-management-impl.md
```

**Run:**
```bash
/wf-implement-feature FEAT-CRM-CUST-001
```

**Expected outputs:**
- Source files: `customer.entity.ts`, `customer.service.ts`, `customer.controller.ts` + DTOs
- Test files: `customer.service.spec.ts`, `customer.controller.spec.ts`
- TDD order: test files mtime ≤ source files mtime
- Mỗi source file có `// REQ-ID: REQ-CRM-CUST-001` comment
- Entity dùng TypeORM `@Entity`, `@PrimaryGeneratedColumn('uuid')`, `@DeleteDateColumn`
- DTOs dùng `@IsEmail`, `@IsNotEmpty` (class-validator)
- Parallel review: spawn code-reviewer + qa-lead (standard profile)
- Registry updated: `impl_status=done` cho REQ-CRM-CUST-001
- `impl-report.md` exists tại `$SESSION_DIR`
- `phase-summary.md` tiếng Việt, có next step

**Pass criteria:** All 10 assertions PASS (xem `evals.json` id=1).

### TC-04 — Resume từ checkpoint

**Setup:**
- Session trước đã tạo `checkpoint.json` tại Phase 3 Batch 2 (context 82%)
- Batches 1 (Entity) và 2 (Service) đã done
- Batch 3 (Controller + API) chưa start

**Run:**
```bash
/wf-implement-feature FEAT-CRM-CUST-001 --resume
```

**Expected:**
- Checkpoint loaded từ `.mc-data/work/wf-implement-feature/$SYSTEM_SLUG/customer-management/sessions/{old_id}/checkpoint.json`
- `context_digest` injected vào Phase 1 context
- KHÔNG re-implement Batch 1/2 files (entity, service đã có code)
- Chỉ tạo controller.ts + controller.spec.ts
- impl-status.json reflect: batches[0,1].status=done, batches[2].status=in_progress→done

### TC-14 — Profile=quick

**Run:** `/wf-implement-feature FEAT-CRM-CUST-001 --profile=quick`

**Expected:**
- `$SESSION_DIR/profile.txt` content = `quick`
- `impl-status.json.profile = "quick"`
- Phase 3 sequential mode (no waves)
- Phase 4 spawn ONLY code-reviewer (no security, qa-lead, a11y, performance)
- Tests = smoke only (failed-fast)
- Nếu user cũng truyền `--parallel` → WARN log + force sequential

### TC-19 — Output Schema v2.0 + consumer_hints

**Expected `impl-status.json`:**
```json
{
  "schema_version": "2.0",
  "session_id": "...",
  "consumer_hints": {
    "for_prepare_deployment": {
      "files_for_changelog": ["src/customer.entity.ts", "..."],
      "breaking_changes": [],
      "migrations_required": ["20260515-add-customers.ts"],
      "feature_summary_vi": "Quản lý khách hàng — CRUD + soft delete"
    },
    "for_fix_bugs": {
      "scope_modules": ["crm"],
      "test_files_added": ["customer.service.spec.ts"],
      "decision_ids_new": ["DEC-001"],
      "implementation_strategy_used": "IMPLEMENT_NEW"
    },
    "for_verify_sync": {
      "req_ids_completed": ["REQ-CRM-CUST-001"],
      "files_with_req_id": ["src/customer.entity.ts", "..."],
      "session_dir": ".mc-data/work/wf-implement-feature/crm/customer-management/sessions/..."
    }
  }
}
```

Synthetic consumer (mock prepare-deployment) đọc `consumer_hints.for_prepare_deployment.files_for_changelog` → list files OK.

---

## 3. Eval criteria

### Pass criteria (per test case)

| Criteria | Threshold |
|----------|-----------|
| POST-GATE T1-T4 PASS | 100% |
| Error count trong session | 0 (smoke), ≤3 with auto-fix recovery (edge) |
| Context budget | <80% (smoke), <90% (integration) |
| File outputs exist | Khớp expected list |
| Phase reports valid | Tiếng Việt, ≤15 dòng (CORE-028) |
| TDD order | Test file mtime ≤ source file mtime |
| REQ-ID coverage | 100% source files có REQ-ID comment |

### Fail criteria (đỏ ngay)

| Criteria | Verdict |
|----------|---------|
| `impl-status.json` missing `$schema` field | FAIL |
| `impl-status.json` schema_version ≠ "2.0" | FAIL |
| Cross-skill artifact (`fix-impact.json` consume) missing `audit_chain` | FAIL |
| POST-GATE T4 fail không recover sau 3 retries | FAIL |
| Context budget >90% mà không checkpoint | FAIL |
| Silent overwrite existing code (CORE-020 bypassed) | FAIL |
| Registry `impl_status` downgrade từ `done` (CORE-008 violated) | FAIL |

---

## 4. Coverage matrix

| | quick | standard | deep | exhaustive |
|---|-------|----------|------|-----------|
| **NEW scenario** | TC-14 | TC-01, TC-06, TC-09, TC-12, TC-16, TC-19 | TC-15 | (untested) |
| **EXTEND scenario** | — | TC-05 | — | — |
| **MODIFY scenario** | — | (untested) | — | — |
| **--resume** | — | TC-04 | — | — |
| **--status** | — | TC-02 | — | — |
| **--skip-review** | — | TC-10 | — | — |
| **--features** | — | TC-11 | — | — |
| **--fresh** | — | TC-13 | — | — |
| **Error injection** | — | TC-03, TC-18 | — | — |
| **Concurrent multi-dev** | — | TC-17 | — | — |
| **Cache HIT** | — | TC-16 | — | — |

---

## 5. Eval execution

```bash
# Chạy 1 test case
./.claude/scripts/audit/run-skill-evals.sh wf-implement-feature --test-id=1

# Chạy tất cả 19 evals
./.claude/scripts/audit/run-skill-evals.sh wf-implement-feature --all

# Output:
# evals/results/wf-implement-feature-TC-{ID}-{timestamp}.json
```

---

## 6. Liên kết

- Eval schema: [`.claude/scripts/audit/EVAL-SCHEMA.md`](../../../.claude/scripts/audit/EVAL-SCHEMA.md)
- Eval source: [`.claude/skills/workflow/wf-implement-feature/evals/evals.json`](../../../.claude/skills/workflow/wf-implement-feature/evals/evals.json)
- Standards: [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md) §7 (compliance audit)
- Review checklist: [`../../05-review-standards/wf-implement-feature.md`](../../05-review-standards/wf-implement-feature.md)
