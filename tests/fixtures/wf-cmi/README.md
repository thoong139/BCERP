# Test Fixtures — `wf-cmi` (Cross-Module Integrity)

> **Mục đích:** Fixtures cho 5 test cases trong [`evals/evals.json`](../../../.claude/skills/workflow/wf-cmi/evals/evals.json) (v1). Reference: [`docs/04-skill-design/wf-cmi/09-evals-test-cases.md`](../../../docs/04-skill-design/wf-cmi/09-evals-test-cases.md).

---

## Fixtures map

| Fixture | Test cases | Mô tả ngắn |
|---------|------------|------------|
| [`minimal/`](minimal/) | TC-cmi-001 (smoke) | 1 module CRM, 3 entity stubs, 5 REQs trong registry, profile=quick (<5 min) |
| [`realistic/`](realistic/) | TC-cmi-002 (integration), TC-cmi-004 (resume) | 3 modules CRM+Orders+Finance, ~15 stub files, cross-module FK, profile=standard (15-30 min) |
| [`corrupt/`](corrupt/) | TC-cmi-003 (edge) | Registry corruption inject mid-Phase 3, kiểm tra auto-fix budget 3 retries + ESCALATE E039 |
| [`concurrent/`](concurrent/) | TC-cmi-005 (concurrent) | Runner orchestrate 2 sessions song song trên cùng máy, kiểm tra Protocol 22 R/W lock |

> **Note:** Fixture `regression/` cho TC-cmi-006 (`--since=HEAD~5`) defer v2 — cần git history setup phức tạp.

---

## Convention

- Mỗi fixture có README.md riêng mô tả setup + expected behavior
- Stubs `.cs` là code minimal — đủ để skill phát hiện entities/relationships qua AST hoặc Grep fallback
- `.mc-data/docs/` chứa phase docs minimal (1-3 files mỗi phase) — đủ để PRE-GATE pass
- `req-registry.json` luôn có `$schema: "req-registry-v2"` và REQ-IDs format chuẩn `REQ-{DEPT}-{NNN}` hoặc `REQ-{SYSTEM}-{MODULE}-{NNN}`
- REQ-IDs sử dụng trong stubs có annotation `// REQ-ID: ...` ngay đầu file (CORE-003)

## Chạy test cases

```bash
# Single test
./.claude/scripts/audit/run-skill-evals.sh wf-cmi --test-id=TC-cmi-001

# All 5 test cases
./.claude/skills/workflow/wf-cmi/evals/run-all.sh

# Type filter
./.claude/scripts/audit/run-skill-evals.sh wf-cmi --type=smoke,integration
```

## Output

Results lưu tại: `.claude/skills/workflow/wf-cmi/evals/results/TC-cmi-{ID}-{timestamp}.json` (schema xem [`docs/04-skill-design/wf-cmi/09-evals-test-cases.md`](../../../docs/04-skill-design/wf-cmi/09-evals-test-cases.md) §5).
