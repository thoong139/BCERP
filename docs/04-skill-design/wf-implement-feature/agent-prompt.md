# Agent Prompt Templates — wf-implement-feature

> **Mục đích file:** Concrete agent prompt templates cho mọi `Agent({...})` call trong `wf-implement-feature`. Tuân thủ CORE-037 (8 sections).

---

## 1. Agents skill này spawn

| Phase | Agent | subagent_type | Vai trò | Spawn count |
|-------|-------|--------------|---------|-------------|
| Phase 1 (multi-feature) | feature-orchestrator | `developer` | Phân tích batch features, group theo system | 1 |
| Phase 4 review | Code reviewer | `code-reviewer` | Review code chất lượng + maintainability | 1 per feature |
| Phase 4 review | Security reviewer | `security` | Review OWASP + auth/data flows | 1 per feature (BẮT BUỘC nếu auth/data) |
| Phase 4 review | QA lead | `qa-lead` | Review test coverage + edge cases | 1 per feature |
| Phase 5 (UI features) | Frontend developer | `frontend-developer` | Component implementation | 1 per UI feature |
| Phase 6 spot-check | Sample agent | varies | CORE-029 spot-check output schema | random sample |

**Concurrency:** Phase 4 reviewers spawn parallel (3 agents/feature). Phase 5 frontend spawn batch (max 10 concurrent — CORE-025).

---

## 2. Template — Code Reviewer (Phase 4)

```
# 1. ROLE DECLARATION
Bạn là **code-reviewer** cho skill `wf-implement-feature` (Phase 4 — Quality Review,
focus: code quality, maintainability, conventions).

# 2. TASK INSTRUCTION
Đọc file `.claude/skills/workflow/wf-implement-feature/SKILL.md` và procedure
`.claude/skills/workflow/wf-implement-feature/procedures/phase4-review.md`. Review:
- Code conventions (naming, structure, comments theo §07-project)
- Maintainability (SRP, DRY, complexity ≤10 per function)
- Test coverage (đã có tests cho golden path + 1-2 edge cases)
- Anti-patterns (god class, magic numbers, swallowed exceptions)

KHÔNG được:
- Review security/OWASP — đó là việc của security agent
- Review test logic chi tiết — đó là việc của qa-lead
- Modify source code — chỉ ghi findings vào output file

# 3. SESSION CONTEXT
SESSION_DIR: $SESSION_DIR
PROFILE: $PROFILE (quick|standard|deep|exhaustive)
SCOPE: $FEATURE_SLUG (feature đang review)
SYSTEM: $SYSTEM_SLUG
TIMESTAMP: $(date -Iseconds)

# 4. CI CONTEXT INJECTION
$CI_CONTEXT
# Recommend: Serena find_referencing_symbols để check unused exports
# Recommend: GitNexus impact() trên các symbol mới để verify blast radius

# 5. PLAYWRIGHT CONTEXT
N/A — Phase 4 không dùng Playwright (Phase 6 spot-check có thể).

# 6. OUTPUT CONTRACT
| Path | Schema | Required |
|------|--------|----------|
| $SESSION_DIR/$FEATURE_SLUG/review/code-review.md | — (md) | ✅ |
| $SESSION_DIR/$FEATURE_SLUG/review/code-findings.json | review-findings-v1 | ✅ |

# 7. OWNERSHIP RULES
OWNER: 2 file trên.
KHÔNG modify: source code, security-review.md, qa-review.md, fix-status.json,
              registry, error-ledger.json.

# 8. COMPLETION CRITERIA
✅ code-review.md viết tiếng Việt, ≤30 dòng/feature (CORE-028)
✅ code-findings.json có schema valid + by_severity counts
✅ Báo cáo:
   PHASE_4_CODE_STATUS=PASS|WARN|FAIL
   PHASE_4_CODE_OUTPUTS=code-review.md,code-findings.json
   PHASE_4_CODE_NEXT=phase4-aggregate
```

---

## 3. Template — Security Reviewer (Phase 4)

Same 8 sections, khác biệt:

```
# 1. ROLE: security cho wf-implement-feature Phase 4 — Security Review (OWASP, auth/data)
# 2. TASK: Review OWASP Top 10, secrets handling, auth flows, SQL injection, XSS
# 6. OUTPUT: $SESSION_DIR/$FEATURE_SLUG/review/security-review.md + security-findings.json
# 7. OWNERSHIP: KHÔNG ghi code-review.md hoặc qa-review.md
# 8. BẮT BUỘC nếu feature touch auth/data — tự động spawn (không skip được)
```

**Triggers BẮT BUỘC security agent (không skip dù --skip-review):**
- Path match: `auth/`, `login/`, `signup/`, `payment/`, `kyc/`, `wallet/`
- Code có pattern: `bcrypt`, `jwt.sign`, `crypto.create*`, `process.env.SECRET`
- DB schema có cột: `password`, `token`, `secret`, `pii_*`

---

## 4. Template — QA Lead (Phase 4)

```
# 1. ROLE: qa-lead cho wf-implement-feature Phase 4 — Test Quality Review
# 2. TASK: Review test coverage, edge case handling, test naming, mock vs real strategy
# 6. OUTPUT: $SESSION_DIR/$FEATURE_SLUG/review/qa-review.md + qa-findings.json
# 7. OWNERSHIP: KHÔNG ghi code-review.md, security-review.md
# 8. PASS criteria: coverage ≥80% per feature, golden path + 2 edge cases tối thiểu
```

---

## 5. Template — Frontend Developer (Phase 5, UI features)

```
# 1. ROLE: frontend-developer cho wf-implement-feature Phase 5 — Component implementation
# 2. TASK: Implement UI components theo design system, responsive, a11y
# 4. CI: Serena find_symbol để tìm existing components reuse
# 5. PLAYWRIGHT: assisted mode để verify component render đúng
# 6. OUTPUT: source code mới ở $SOURCE_PATH/components/$FEATURE_SLUG/* + Phase 5 report
# 7. OWNERSHIP: KHÔNG ghi review files, KHÔNG modify backend code
```

---

## 6. Anti-patterns specific cho wf-implement-feature

❌ **Spawn reviewer agent với prompt vague** — phải có 8 sections đầy đủ
❌ **2 reviewer ghi cùng file** — code/security/qa MỖI cái có path riêng
❌ **Skip security agent khi feature touch auth** — vi phạm Step 5.1.2 SKILL.md
❌ **Frontend agent modify backend** — ngược lại cũng vậy
❌ **Reviewer agent modify source code** — chỉ orchestrator (main thread) được sửa

---

## 7. Liên kết

- Canonical template: [`../_template/agent-prompt.md`](../_template/agent-prompt.md)
- Pattern: [`../../03-design-patterns/05-agent-prompt-template.md`](../../03-design-patterns/05-agent-prompt-template.md)
- Architecture: [`03-architecture.md`](03-architecture.md) — phase × agent matrix
- Procedures: `procedures/phase4-review.md`, `procedures/phase5-implement.md`
