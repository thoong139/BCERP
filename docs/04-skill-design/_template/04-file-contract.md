<!--
_template_notes:
  purpose: Đặc tả PRE-GATE/POST-GATE per phase + cross-skill artifacts + business invariants.
  populate:
    - §1 PRE-GATE per phase (T1→T4 forensic)
    - §2 POST-GATE per phase (T1→T4 tier check)
    - §3 Cross-skill produces_for/consumes_from
    - §4 Artifact schemas (JSON Schema cho từng artifact với $schema version)
    - §5 Atomic write pattern dùng trong skill
    - §6 Business invariants (OPTIONAL — chỉ điền nếu skill đọc/ghi business rules,
        constraints, hoặc tương tác registry invariants[] field)
    - §7 Liên kết
  độ dài tham khảo: 200-500 dòng (cộng thêm 50-100 dòng nếu có §6)
  bỏ §6 nếu skill thuần xử lý code/infra, KHÔNG chạm business rules
-->

# 04 — File Contract

> **Mục đích file:** Định nghĩa rõ contracts (PRE-GATE/POST-GATE/cross-skill) — căn cứ để reviewer verify skill có tuân thủ CORE-007, CORE-012, CORE-036.

---

## 1. PRE-GATE per phase (forensic)

### Phase 1 — Init

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | `test -f .mc-data/docs/_meta/req-registry.json` | bash | E010 — registry missing |
| T2 | `jq -e '.requirements' registry.json` | jq | E011 — schema invalid |
| T3 | `jq -e '.requirements \| length > 0'` | jq | E012 — empty registry |
| T4 | Cross-ref: registry consistent với phase2-features | bash | E013 — drift |

### Phase 2 — {name}

| Tier | Check | Fail action |
|------|-------|-------------|
| T1 | {file exists} | E020 |
| T2 | {structure valid} | E021 |
| T3 | {content non-empty} | E022 |
| T4 | {cross-ref} | E023 |

{... lặp cho mỗi phase ...}

---

## 2. POST-GATE per phase (tiered T1→T4)

### Phase 1 — Init

| Tier | Check | Auto-fix |
|------|-------|----------|
| T1 | `test -f $SESSION_DIR/fix-status.json` | Retry write |
| T2 | `jq '.' fix-status.json` | Re-build từ template |
| T3 | `jq -e '.session_id != null'` | Re-generate ID |
| T4 | `current_phase == 1` | Reset state |

{... lặp cho mỗi phase ...}

---

## 3. Cross-skill contract

### Produces for (downstream consumers)

| Skill consumer | Artifact | Schema | Path |
|---------------|---------|--------|------|
| wf-verify-sync | `{skill}-impact.json` | `{skill}-impact-v1` | `.mc-data/work/{skill}/sessions/{id}/{skill}-impact.json` |
| wf-implement-feature | (optional) | (optional) | (optional) |

### Consumes from (upstream producers)

| Skill producer | Artifact | Schema | Path |
|---------------|---------|--------|------|
| wf-brainstorm | `req-registry.json` | `req-registry-v1` | `.mc-data/docs/_meta/req-registry.json` |
| wf-preflight (optional) | `preflight-report.json` | `preflight-v1` | `.mc-data/work/wf-preflight/sessions/{id}/preflight-report.json` |

---

## 4. Artifact schemas

### `fix-status.json` (pipeline state)

```json
{
  "$schema": "fix-status-v1",
  "session_id": "string (YYYY-MM-DD-{scope}-{slug}-NN)",
  "current_phase": "integer (1-N)",
  "phases_completed": "array<integer>",
  "next_action": "string (phase name)",
  "context_budget_used_pct": "integer (0-100)",
  "checkpoint_at": "string (ISO 8601)",
  "audit_chain": {
    "source": "string (upstream artifact path)",
    "checksum": "string (sha256)"
  }
}
```

### `{skill}-impact.json` (cross-skill output)

```json
{
  "$schema": "{skill}-impact-v1",
  "skill": "{skill-name}",
  "session_id": "string",
  "generated_at": "string (ISO 8601)",
  "impacted_reqs": ["array<string>"],
  "impacted_files": ["array<string>"],
  "audit_chain": {
    "source": ".mc-data/work/{skill}/sessions/{id}/fix-status.json",
    "checksum": "string"
  }
}
```

---

## 5. Atomic write pattern

```bash
# Step 1: build vào tmp
echo "$new_content" > "$file.tmp.$$"

# Step 2: validate JSON
jq '.' "$file.tmp.$$" > /dev/null || { rm "$file.tmp.$$"; exit 1; }

# Step 3: atomic move
mv "$file.tmp.$$" "$file"

# Step 4: verify
test -f "$file" && jq -e '.' "$file" > /dev/null
```

Source canonical: [`../../02-standards/04-contract-schema.md`](../../02-standards/04-contract-schema.md) §5.

---

## 6. Business invariants (OPTIONAL — bỏ section này nếu skill thuần kỹ thuật)

> **Khi nào điền:** Skill đọc/sửa business rules, constraints, postconditions trong `req-registry.json` hoặc `phase{N}-*` docs.
> **Engine ánh xạ:** #4 Business Invariant Registry + #15 Business Rule Inference — xem [`docs/01-architecture/10-mcv3-engines-overview.md`](../../01-architecture/10-mcv3-engines-overview.md) §1.

### 6.1 Invariants consumed (đọc làm input)

| Source | Field/Section | Skill action |
|--------|--------------|--------------|
| `req-registry.json` | `requirements[].invariants[]` (v3+, optional) | Validate logic mới không vi phạm |
| `phase1-business/[dept].md` | §Business rules | Inject vào agent prompt §3 |
| `phase2-features/[sys]/[mod]/[feat].md` | §Invariants, §Postconditions | Cross-check với code/test |
| `.claude/references/team-expert/{domain}/rules.md` | Domain compliance rules | Enforce trong agent reasoning |

### 6.2 Invariants produced/updated (ghi làm output)

| Target | Field/Section | Update mode | Conflict policy |
|--------|--------------|-------------|----------------|
| `req-registry.json` | `requirements[].invariants[]` | APPEND-only (per CORE-006 Safe-Write role) | KHÔNG ghi đè existing — CDG nếu conflict |
| `phase1-business/[dept].md` | §Business rules | PRIMARY (chỉ skill business owner) | KHÔNG sửa từ skill khác |
| `$SESSION_DIR/invariants-diff.json` | (new artifact, optional) | PRIMARY this skill | — |

### 6.3 Invariant schema (nếu skill bump registry v3)

```json
{
  "$schema": "req-registry-v3",
  "requirements": [
    {
      "id": "REQ-SALES-001",
      "title": "Quản lý khách hàng",
      "impl_status": "in_progress",
      "invariants": [
        {
          "id": "INV-SALES-001-01",
          "kind": "precondition|postcondition|invariant",
          "expression": "customer.email IS NOT NULL AND customer.email MATCHES email_regex",
          "severity": "MUST|SHOULD|MAY",
          "source_doc": "phase1-business/sales.md#L42",
          "verified_by": ["unit-test:test_email_validation", "code:src/sales/customer.ts:L23"]
        }
      ]
    }
  ]
}
```

### 6.4 Validation rules

| Tier | Check | Tool | Fail action |
|------|-------|------|-------------|
| T1 | `jq '.requirements[].invariants' registry.json` không null khi `$schema=v3` | jq | E0{NN} |
| T2 | Mỗi invariant có `id`, `kind`, `expression`, `source_doc` | jq | E0{NN} |
| T3 | `source_doc` path tồn tại + line ref valid | bash | E0{NN} |
| T4 | Cross-check: invariant referenced bởi ≥1 code/test (qua REQ-ID grep hoặc GitNexus query) | Grep / GitNexus | E0{NN} WARN |

### 6.5 Inference workflow (nếu skill suy luận invariant mới)

Tham chiếu QD11 3-pass pattern ([`../wf-fix-bugs/02-quality-dimensions.md`](../wf-fix-bugs/02-quality-dimensions.md) §QD11):

```
Pass 1 — Cross-module pattern compare: tìm field/rule có ở module A nhưng thiếu ở module B
Pass 2 — Domain heuristic: spawn {domain}-expert, ask "rule nào BẮT BUỘC theo industry standard"
Pass 3 — Registry gap: list invariant trong docs nhưng chưa có code/test verification

OUTPUT → CDG: trình bày 3-5 candidate invariants, user ACCEPT/REJECT từng cái
ACCEPTED → ghi vào registry qua Safe-Write APPEND
```

### 6.6 Anti-patterns

❌ Skill tự ghi invariants vào registry KHÔNG qua CDG (vi phạm BHV-001)
❌ Inferred invariant không có `source_doc` reference (không truy vết được)
❌ Override `invariants[]` cũ thay vì APPEND (vi phạm CORE-006)

---

## 7. Liên kết

- Standards: [`../../02-standards/04-contract-schema.md`](../../02-standards/04-contract-schema.md)
- Standards: [`../../02-standards/05-quality-gates.md`](../../02-standards/05-quality-gates.md)
- Standards: [`../../02-standards/11-output-path-contract.md`](../../02-standards/11-output-path-contract.md)
- Pattern: [`../../03-design-patterns/03-cross-skill-artifacts.md`](../../03-design-patterns/03-cross-skill-artifacts.md)
- Engines overview: [`../../01-architecture/10-mcv3-engines-overview.md`](../../01-architecture/10-mcv3-engines-overview.md) (#4, #5, #15)
- Real example: [`../wf-fix-bugs/02-quality-dimensions.md`](../wf-fix-bugs/02-quality-dimensions.md) §QD11 (3-pass inference)
