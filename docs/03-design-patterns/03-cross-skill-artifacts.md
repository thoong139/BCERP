# 03 — Cross-Skill Artifacts

> **Mức độ ràng buộc:** BẮT BUỘC cho skill có output được skill khác consume
> **Rule liên quan:** CORE-036
> **Khi nào dùng:** Skill A produces output mà skill B/C/D cần đọc

---

## 1. Vấn đề pattern giải quyết

Khi 2 skills cần giao tiếp:

```
Skill A produces  →  ???  →  Skill B consumes
```

**Anti-pattern phổ biến:**
- Skill A ghi vào path X
- Skill B đọc path Y (khác X) → broken
- Skill A đổi format → Skill B parse fail → silent error
- Skill B đọc artifact stale từ run cũ → quyết định sai

**Pattern giải quyết:**
- Artifact có `$schema` field (versioned)
- Artifact có `audit_chain.source + checksum` (truy vết)
- Consumer validate ở PRE-GATE: T1 (exists) → T2 (structure) → T3 (content)
- Producer + consumer + path đăng ký trong `_contract.json` cross-skill section

---

## 2. Pattern definition

### 2.1. Artifact schema versioned

```json
{
  "$schema": "fix-impact-v1",
  "audit_chain": {
    "source": ".mc-data/work/wf-fix-bugs/sessions/2026-05-15-.../fix-status.json",
    "checksum": "sha256:abc123..."
  },
  "session_id": "2026-05-15-crm-payment-01",
  "ended_at": "2026-05-15T11:30:00+07:00",
  "fixes_applied": [
    {"req_id": "REQ-CRM-PAY-003", "dimension": "QD3-security", "fix_type": "input_validation"}
  ],
  "code_files_changed": ["src/crm/payment/validator.ts"],
  "tests_added": ["src/crm/payment/__tests__/validator.test.ts"]
}
```

### 2.2. `_contract.json` cross-skill section

**Producer:**
```json
{
  "produces_for": {
    "wf-verify-sync": [
      "fix-impact.json (fix-impact-v1) at $SESSION_DIR/phase7-verify/fix-impact.json"
    ],
    "wf-prepare-deployment": ["fix-impact.json (same)"],
    "wf-implement-feature": ["fix-impact.json (same)"]
  }
}
```

**Consumer:**
```json
{
  "consumes_from": {
    "wf-fix-bugs": [
      "fix-impact.json (fix-impact-v1) — load via --from-fix-bugs flag"
    ]
  }
}
```

### 2.3. Consumer PRE-GATE validation

```bash
# T1: file exists
test -f "$FIX_IMPACT_PATH" || exit_error "Artifact missing"

# T2: structure valid
jq -e '.["$schema"]' "$FIX_IMPACT_PATH" > /dev/null \
  || exit_error "Invalid schema"

# T3: content non-empty
[ "$(jq -r '.fixes_applied | length' "$FIX_IMPACT_PATH")" -gt 0 ] \
  || warn "No fixes applied — proceed with caution"

# T4: checksum (optional, nếu cần verify integrity)
expected_checksum=$(jq -r '.audit_chain.checksum' "$FIX_IMPACT_PATH")
actual_checksum=$(sha256sum "$(jq -r '.audit_chain.source' "$FIX_IMPACT_PATH")" | cut -d' ' -f1)
[ "$expected_checksum" = "sha256:$actual_checksum" ] || warn "Source modified after artifact gen"
```

---

## 3. Case study — `fix-impact.json` (wf-fix-bugs v10.0)

```
wf-fix-bugs Phase 7:
  1. Đọc fix-status.json (SSOT pipeline state)
  2. Compute fix summary:
     - fixes_applied[] from phase6-execute/
     - code_files_changed[] from git diff stats
     - tests_added[] from phase6 logs
  3. Build fix-impact.json:
     - $schema: "fix-impact-v1"
     - audit_chain.source: path fix-status.json
     - audit_chain.checksum: sha256 fix-status.json
  4. Atomic write to $SESSION_DIR/phase7-verify/fix-impact.json
```

**Consumers + flag:**

| Consumer | Flag | Use case |
|----------|------|----------|
| wf-verify-sync | `--from-fix-bugs` | Update `impl_status` cho fixes |
| wf-prepare-deployment | `--from-fix-bugs` | Include fixes trong release notes |
| wf-implement-feature | `--from-fix-bugs` | Avoid re-implementing fixed code |

**Wired status:** v2.1+ — flag handle code đầy đủ. Consumer validate schema version.

---

## 4. Artifact family (5 artifacts trong MCV3)

| Artifact | Schema | Producer | Consumers |
|----------|--------|----------|-----------|
| `fix-impact.json` | fix-impact-v1 | wf-fix-bugs | wf-verify-sync, wf-prepare-deployment, wf-implement-feature |
| `preflight-impact.json` | preflight-impact-v1 | wf-preflight | wf-fix-bugs, wf-prepare-deployment, wf-verify-sync |
| `verify-sync-impact.json` | (TBD) | wf-verify-sync | wf-prepare-deployment, wf-fix-bugs, wf-implement-feature |
| `change-impact.json` | change-impact-v1 | wf-manage-change | wf-verify-sync, wf-preflight, wf-implement-feature |
| `scope-impact.json` | (TBD) | wf-add-scope | wf-verify-sync, wf-preflight, wf-implement-feature |

---

## 5. Variations / Edge cases

### 5.1. Schema evolution

```
v1 → v2 thêm field "deployment_recommendations[]"

Producer v2.0:
  $schema: "fix-impact-v2"
  fixes_applied: [...]
  deployment_recommendations: [...]   ← NEW

Consumer cũ (v1 aware):
  Đọc $schema → "fix-impact-v2"
  Warn: "Unknown version, proceeding with best-effort"
  Đọc các fields v1 biết → skip fields lạ
```

**Quy tắc evolution:**
- Tăng MINOR (v1.0 → v1.1) cho APPEND field (backward compat)
- Tăng MAJOR (v1.x → v2.0) cho BREAKING change
- Consumer phải handle "unknown $schema version" gracefully

### 5.2. Stale artifact

```
fix-impact.json từ session cũ (1 tuần trước)
Consumer load → audit_chain checksum mismatch (source đã thay đổi)
→ Warn "Source modified after artifact generation — consider re-running wf-fix-bugs"
```

### 5.3. OPT-IN vs WIRED

```
OPT-IN: artifact tồn tại, consumer chưa có flag → manual
  Use: scope-impact.json, verify-sync-impact.json

WIRED: flag --from-X handle code đầy đủ
  Use: --from-fix-bugs (v2.1+), --from-manage-change (v4.1.0+)
```

Mục tiêu dài hạn: mọi artifact → WIRED.

---

## 6. Anti-patterns

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Artifact thiếu `$schema` field | Bắt buộc (CORE-036) |
| Schema không versioned | `fix-impact-v1`, `fix-impact-v2`, ... |
| Consumer hardcode path artifact | Đọc canonical từ Protocol 21 + `_contract.json` |
| Producer ghi vào path không declare trong `_contract.json.produces_for` | Phải declare → audit detect |
| Consumer không validate `$schema` version | Phải check ở PRE-GATE T2 |
| Atomic write thiếu validate JSON trước mv | Build tmp → jq validate → mv (CORE-035) |
| Artifact không có `audit_chain` | Cần truy vết source |
| 2 producers cùng ghi 1 artifact path | 1 path = 1 producer (OPC-1) |
| Consumer mute warn khi schema mismatch | Phải log + show user |

---

## 7. Checklist áp dụng

**Producer skill:**

- [ ] Artifact có `$schema` field với version (vd: `"fix-impact-v1"`)
- [ ] Artifact có `audit_chain.source + checksum`
- [ ] Đăng ký path trong `_contract.json.outputs.working[]`
- [ ] Đăng ký consumers trong `_contract.json.produces_for{}`
- [ ] Atomic write (build tmp → validate → mv)
- [ ] Update [`../02-standards/11-output-path-contract.md`](../02-standards/11-output-path-contract.md) §3 bảng

**Consumer skill:**

- [ ] Đăng ký producer trong `_contract.json.consumes_from{}`
- [ ] PRE-GATE: T1 (exists) → T2 (schema validate) → T3 (content) → T4 (audit_chain)
- [ ] Handle unknown `$schema` version gracefully (warn + best-effort)
- [ ] Document flag `--from-{producer}` trong SKILL.md arguments
- [ ] Test eval cho cả "artifact present" và "artifact absent"

---

## 8. Liên kết

- **Standard:** [`../02-standards/04-contract-schema.md`](../02-standards/04-contract-schema.md)
- **Output Path Contract:** [`../02-standards/11-output-path-contract.md`](../02-standards/11-output-path-contract.md) §3.13
- **Rule:** CORE-036 trong [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4m
- **Protocol 21:** [`.claude/skills/protocols/21-cross-skill-output-path-contract.md`](../../.claude/skills/protocols/21-cross-skill-output-path-contract.md)
- **Case study source:** `.claude/skills/workflow/wf-fix-bugs/templates/phase7-verify/fix-impact.json`
