# 04 — File Contract

> **Mục đích file:** Session dir layout + SSOT JSONs ownership (4 shared JSONs) + e2e-status.json + cross-skill orchestrates[].

---

## 1. Session directory layout

Path duy nhất cho cả orchestrator + 11 sub-skills:

```
.mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-{YYYYMMDD-HHmm}/
├── e2e-status.json              ← ORCHESTRATOR SSOT 8-step (CHỈ orchestrator write)
├── session-log.json             ← CORE-026 APPEND-only (sub-skills cũng append)
├── error-ledger.json            ← CORE-034 APPEND-only, namespaced E001-E099
├── prompt-context.md            ← input user verbatim
├── .lock                        ← session-level lock + heartbeat
│
├── issues.json                  ← SHARED — F1,F2,F5,F7,F8 APPEND; F6 UPDATE
├── block-test.json              ← SHARED — F1,F2 APPEND; F3 UPDATE; F5 UPDATE
├── implement-required.json      ← SHARED — F1,F2 APPEND; F4 UPDATE
├── manual.json                  ← SHARED — F1,F2,F3 APPEND; report-only
│
├── findings/                    ← F0a OWNED (8 files: business-rules, db-schema, api-contracts, ui-flows, cross-module-gaps, seed-requirements, test-scenarios, edge-cases)
├── outputs/                     ← F1 init (test-scenario.md, user-guide.md skeletons); F2,F7,F8 UPDATE
├── screenshots/                 ← F2,F7,F8 SHARED (prefix: browser-, scenario-, demo-)
│
├── F0-infra/, F0a-finding/, F0b-seed/,
├── F1-test/, F2-browser/, F3-unblock/, F4-implement/, F5-retest/,
├── F6-fix/, F7-scenario/, F8-demo/  ← per-skill workspaces
│
├── _locks/
│   ├── browser-mcp.lock         ← F2, F5, F7, F8 sequential (Protocol 22)
│   ├── source-{hash}.lock       ← F4, F6 acquire khi edit
│   ├── migration.lock           ← F1 DB migrate
│   └── module-{id}.lock         ← cross-session safety
│
├── orchestrator-summary.md      ← orchestrator finalize
└── phase-summary.md             ← CORE-028 tổng kết tiếng Việt ≤15 dòng
```

---

## 2. SSOT JSONs ownership (4 shared files)

Pattern: **multiple writers, defined ownership rules**.

| File | F1 | F2 | F3 | F4 | F5 | F6 | F7 | F8 | Description |
|------|----|----|----|----|----|----|----|----|-------------|
| `issues.json` | APPEND | APPEND | — | — | APPEND | UPDATE | APPEND | APPEND | Bug/issue tracking, status=open\|in_progress\|fixed\|still_fail |
| `block-test.json` | APPEND | APPEND | UPDATE | — | UPDATE | — | — | — | Blocked tests, 4 groups: 1 (data) / 2 (infra) / 3 (impl) / 4 (manual) |
| `implement-required.json` | APPEND | APPEND | — | UPDATE | — | — | — | — | Missing features cần implement (signal cho F4) |
| `manual.json` | APPEND | APPEND | APPEND | — | — | — | — | — | Manual verification items (Nhóm 4) — report-only, không có UPDATE |

**APPEND-only pattern:**
```bash
# Atomic append via jq (no race condition)
TMP=$(mktemp)
jq --argjson new "$NEW_ENTRY" '.signals += [$new]' "$FILE" > "$TMP" && mv "$TMP" "$FILE"
```

**UPDATE pattern:**
```bash
# Update by ID
TMP=$(mktemp)
jq --arg id "$SIGNAL_ID" --arg status "fixed" \
   '(.signals[] | select(.id == $id) | .status) = $status' "$FILE" > "$TMP" && mv "$TMP" "$FILE"
```

---

## 3. PRE-GATE Orchestrator (CORE-011)

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | FEAT-ID hợp lệ trong registry | jq | E001 |
| T2 | Registry schema valid | `jq -e '.requirements \| length > 0 and .features \| length > 0'` | E001 |
| T3 | Feature spec tồn tại + ≥500 bytes | `test -f && stat size` | E002 |
| T4 | 11 sub-skill directories tồn tại | `test -d .claude/skills/workflow/wf-e2e-*` | E003 |

---

## 4. POST-GATE Orchestrator (CORE-012)

Sau khi 8 steps complete (hoặc partial):

| Tier | Check | Auto-fix |
|------|-------|----------|
| T1 | `e2e-status.json` valid + tất cả steps có status terminal (completed\|skipped\|failed) | Re-run failed step (max 3) |
| T2 | `orchestrator-summary.md` tồn tại | Re-generate từ template |
| T3 | Phase-summary tiếng Việt ≤15 dòng (CORE-028) | Re-generate |
| T4 | Tổng outputs khớp với declared trong sub-skill contracts (cross-ref) | Re-run sub-skill (max 3) |

---

## 5. Cross-skill contract — `orchestrates[]`

Orchestrator KHÔNG `produces_for` / `consumes_from` truyền thống — thay vào đó dùng `orchestrates[]` schema:

```json
{
  "cross_skill_contracts": {
    "produces_for": {},
    "consumes_from": {},
    "orchestrates": [
      {
        "step": "F1",
        "skill": "wf-e2e-test",
        "trigger": "Always run — mandatory live-test (consume F0a findings)",
        "passes": ["<FEAT-ID>", "--session=<id>", "--auto (if set)"],
        "validation": "POST-VERIFY db/api/ui/integration test reports tồn tại"
      },
      {
        "step": "F4",
        "skill": "wf-e2e-implement",
        "trigger": "Conditional: implement-required.json có ≥1 status=pending",
        "passes": ["<FEAT-ID>", "--session=<id>", "--max-items (if)"],
        "validation": "POST-VERIFY impl-log.json + registry impl_status updated"
      }
      // ... 9 more steps
    ],
    "anti_loop": {
      "f6_f5_max_loops": 3,
      "f3_f2_max_loops": 2
    }
  }
}
```

---

## 6. `e2e-status.json` schema

```json
{
  "$schema": "e2e-status-v1",
  "session_id": "FEAT-EW-CRM-001-20260513-1200",
  "feat_id": "FEAT-EW-CRM-001",
  "started_at": "ISO 8601",
  "completed_at": "ISO 8601 | null",
  "current_step": "F0 | F0a | ... | F8",
  "overall_status": "running | success | partial | failed",
  "steps": {
    "F0": {
      "status": "pending | running | completed | skipped | failed",
      "duration_ms": "integer | null",
      "started_at": "ISO 8601",
      "completed_at": "ISO 8601 | null",
      "outputs": ["array<path>"],
      "skip_reason": "string | null"
    },
    "F0a": { ... },
    "F0b": { ... },
    "F1": { ... },
    "F2": { ... },
    "F3": { ... },
    "F4": { ... },
    "F5": { ... },
    "F6": { ... },
    "F7": { ... },
    "F8": { ... }
  },
  "anti_loop": {
    "f6_f5_loop_count": "integer (0-3)",
    "f3_f2_loop_count": "integer (0-2)"
  },
  "legacy_flags_used": ["array<string>"],
  "standalone_step": "string | null (vd: F6 khi --fix=<path>)",
  "summary": {
    "total_issues_found": "integer",
    "issues_fixed": "integer",
    "issues_open": "integer",
    "tests_passed": "integer",
    "tests_failed": "integer"
  }
}
```

---

## 7. Registry Safe-Write

**write_role:** NONE
**fields_owned:** `[]`

Orchestrator KHÔNG update registry. F4 (`wf-e2e-implement`) delegate `wf-implement-feature` — `wf-implement-feature` mới có SAFE-UPDATE role `impl_status`.

---

## 8. Atomic write pattern

Áp dụng cho `e2e-status.json`:

```bash
# Step 1: build vào tmp
echo "$new_content" > "$file.tmp.$$"

# Step 2: validate JSON
jq '.' "$file.tmp.$$" > /dev/null || { rm "$file.tmp.$$"; exit 1; }

# Step 3: atomic move
mv "$file.tmp.$$" "$file"
```

SSOT JSONs (`issues.json` v.v.) dùng jq UPDATE/APPEND pattern (xem §2).

---

## 9. Liên kết

- Standards: [`../../02-standards/04-contract-schema.md`](../../02-standards/04-contract-schema.md) §orchestrates
- Standards: [`../../02-standards/06-safe-write-protocol.md`](../../02-standards/06-safe-write-protocol.md) — NONE role
- Standards: [`../../02-standards/11-output-path-contract.md`](../../02-standards/11-output-path-contract.md)
- Pattern: [`../../03-design-patterns/03-cross-skill-artifacts.md`](../../03-design-patterns/03-cross-skill-artifacts.md)
- Pattern: [`../../03-design-patterns/09-multi-session-locking.md`](../../03-design-patterns/09-multi-session-locking.md) — Protocol 22
- Source `_contract.json`: [`.claude/skills/workflow/wf-e2e-verify/_contract.json`](../../../.claude/skills/workflow/wf-e2e-verify/_contract.json)
