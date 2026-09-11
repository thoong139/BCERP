# Plan: wf-implement-feature & wf-plan-modules Quality Improvement

## Context

wf-fix-bugs trên EUREKA-2026 web-customer phát hiện 123 issues (8 CRITICAL, 34 HIGH, 49 MEDIUM, 29 LOW). Phân tích root cause cho thấy 4 lỗ hổng trong pipeline plan-modules → implement-feature:

1. **wf-plan-modules chỉ check EXISTENCE, không check QUALITY** — COMPLETE_EXISTING features được đánh giá "code đã có" nhưng không ai kiểm tra code đó có vấn đề bảo mật, i18n, accessibility không.
2. **Task file template thiếu section về security, i18n, accessibility, data integrity** — agent không được cung cấp context để biết cần check những gì.
3. **wf-implement-feature review checklist thiếu check cụ thể** — không check `process.env` vs `import.meta.env`, NaN guard, React hooks deps, i18n compliance, memory cleanup.
4. **VERIFY_ONLY/COMPLETE_EXISTING modes bỏ qua quality gates** — strategy COMPLETE_EXISTING (confidence 0.9) → code được "verify" nhưng không review chất lượng.

Goal: Ngăn chặn ~30-40% trong số các issue patterns này ngay từ pipeline upstream, thay vì để wf-fix-bugs bắt sau.

---

## Implementation Plan

### Sprint A: wf-implement-feature (6 items, ~7h)

#### A1 (P0, 2h) — Environment-Aware Pre-Checks trong Phase 0.7 Safety Gate

**File:** `.claude/skills/workflow/wf-implement-feature/procedures/phase0-7-safety-gate.md`

**What:** Thêm BƯỚC 2b mới sau BƯỚC 2 hiện tại — "Environment Safety Scan". Chạy 5 grep patterns:

| # | Pattern | Target | Severity |
|---|---------|--------|----------|
| E1 | `process\.env\.` trong `*.{tsx,ts,jsx,js}` không thuộc `server/` | `process.env` in browser bundle | CRITICAL |
| E2 | `'(dev-secret\|admin123\|password\|changeme\|temp_key\|test_key)'` | Hardcoded secret fallback | CRITICAL |
| E3 | `parseInt\|parseFloat\|Number\(\|new Date\(` không có `isNaN\|Number.isNaN\|\.filter\(Boolean\)` trong 2 dòng tiếp theo | NaN propagation risk | HIGH |
| E4 | `\.replace\(['"]` (string arg, không phải regex) | String.replace chỉ thay lần đầu | MEDIUM |
| E5 | `define:\s*\{[^}]*process\.env` trong `vite\.config\.(ts\|js)` | API key leak qua Vite define vào client bundle | CRITICAL |

Kết quả append vào `$SAFETY_SCAN_FINDINGS`, inject vào agent context ở Phase 2 planning và Phase 3 TDD.

**Implementation details:**
- Thêm section `## BƯỚC 2b: Environment Safety Scan` sau line 64 (sau BƯỚC 2)
- Thêm step 0.7.8a: tổng hợp `$SAFETY_SCAN_FINDINGS` vào `$TASK_LIST` context
- Thêm exclusion patterns: `*.test.*`, `*.spec.*`, `node_modules/`, `dist/`, `build/`
- Cập nhật POST-GATE: xác nhận tất cả CRITICAL findings từ safety scan đã được resolved

---

#### A2 (P0, 1h) — Mở rộng Review Checklist

**File:** `.claude/skills/workflow/wf-implement-feature/templates/qa-review-report.md`

**What:** Thêm 3 sections mới vào Review Checklist (sau Security checklist hiện tại):

```markdown
### Environment Safety (tất cả agents)
- [ ] Không `process.env` trong browser-bundled code (Vite: dùng `import.meta.env`)
- [ ] Không hardcoded secrets/fallback values trong source code
- [ ] API keys/config từ env vars, không inject qua `define` vào client bundle

### Runtime Safety (qa-lead)
- [ ] NaN guard trên tất cả `parseInt()`, `parseFloat()`, `new Date()`, phép chia
- [ ] Blob URL / timer / subscription được cleanup trong useEffect return
- [ ] `String.replace()` dùng regex `/pattern/g` khi cần replace tất cả occurrences
- [ ] Optional chaining / nullish coalescing (`??`) thay vì `||` cho falsy values hợp lệ (0, '')

### i18n & Accessibility (qa-lead, frontend)
- [ ] Không hardcoded UI strings — tất cả qua `t()` hoặc i18n function
- [ ] Placeholder, aria-label, alt text cũng được translate
- [ ] Label có `htmlFor` attribute matching input `id`
- [ ] Hình ảnh có alt text mô tả (không generic như "Product", "Avatar")
```

Cập nhật section header comment trong template để agents biết đây là checklist BẮT BUỘC phải điền.

---

#### A3 (P0, 0.5h) — Security Agent Mandatory cho Auth/Security Batches

**File:** `.claude/skills/workflow/wf-implement-feature/procedures/phase4-5-review-fix.md`

**What:** Sửa Step 4.0b2 profile overlay rules:

**Current logic (line ~82-84):**
```
$PROFILE == standard => $AGENT_SET = $BATCH_AGENT_SET
```

**New logic:**
```
$PROFILE == standard:
  IF $BATCH_TYPE == auth_security AND security NOT IN $BATCH_AGENT_SET:
    => ADD security to $AGENT_SET (mandatory for auth_security)
    => Log: "Security agent mandatory for auth_security batch (CORE-XXX)"
  IF $BATCH_TYPE == data_layer AND security NOT IN $BATCH_AGENT_SET:
    => ADD security to $AGENT_SET (SQL injection risk)
    => Log: "Security agent mandatory for data_layer batch (CORE-XXX)"
  ELSE:
    => $AGENT_SET = $BATCH_AGENT_SET
```

Tương tự cho `quick` profile: nếu batch type = auth_security hoặc data_layer, thay vì replace toàn bộ bằng `[code-reviewer]`, vẫn giữ `security` agent.

---

#### A4 (P1, 1.5h) — Environment Profile Detection

**File mới:** `.claude/skills/workflow/wf-implement-feature/procedures/phase0-6-env-profile.md`

**What:** Thêm phase mới chạy trước Phase 0.7, detect môi trường build:

| Detection | Signal | `$ENV_PROFILE` |
|-----------|--------|----------------|
| `vite.config.*` exists | Vite project | `vite` |
| `next.config.*` exists | Next.js project | `nextjs` |
| `package.json` has `"react"` but no vite/next | CRA/Custom React | `react-generic` |
| Only `server/` has `package.json` | Pure Node.js backend | `node-server` |
| None of the above | Unknown | `generic` |

Set `$ENV_PROFILE` variable, inject vào tất cả agent prompts qua `_shared.md`.

**Environment-specific rules (injected vào agent context):**

| Profile | Rules |
|---------|-------|
| `vite` | `import.meta.env.VITE_*` cho client, `process.env` cho server (Vite SSR/config); KHÔNG `define` secrets; `import.meta.env` values là string constants at build time |
| `nextjs` | `NEXT_PUBLIC_*` cho client components; server components dùng `process.env`; middleware edge runtime restrictions |
| `node-server` | Validate env vars at startup; KHÔNG hardcoded fallback secrets; dùng `dotenv` hoặc built-in |
| `react-generic` | React hooks rules; strict mode compliance |
| `generic` | No specific rules — rely on general best practices |

**Cập nhật SKILL.md execution flow:** Thêm `phase0-6-env-profile.md` vào DAG giữa phase0-5 và phase0-7.

---

#### A5 (P1, 1h) — VERIFY_ONLY Mode Enhancement

**File:** `.claude/skills/workflow/wf-implement-feature/procedures/phase4-5-review-fix.md`

**What:** VERIFY_ONLY mode hiện tại skip toàn bộ Phase 4-5 (không viết code → không cần review). Enhancement:

- Thêm PRE-GATE check: nếu `$CONFIRMED_STRATEGY == VERIFY_ONLY`:
  - **Luôn** chạy code-reviewer agent (lightweight scan: security patterns + environment safety)
  - Nếu feature type = auth/payment/data → thêm security agent
  - Skip qa-lead, api-tester, accessibility-auditor, performance-benchmarker (không có code changes)
  - Review scope: chỉ check existing code, không yêu cầu changes
  - Output: `qa-review-attempt-0.md` (attempt 0 = verify-only)
  - Issues found → log vào `gaps_identified` thay vì yêu cầu fix ngay

**Implementation:**
- Thêm `$STRATEGY` check ở đầu Phase 4-5 PRE-GATE
- Nếu `$CONFIRMED_STRATEGY == VERIFY_ONLY`: route sang `phase4-5-verify-only.md` (new sub-procedure)
- Sub-procedure: lightweight review, output gaps, không block nếu có issues (chỉ document)

---

#### A6 (P1, 1h) — Agent Output Spot-Check (CORE-029)

**File:** `.claude/skills/workflow/wf-implement-feature/procedures/phase4-5-review-fix.md`

**What:** Thêm Step 4.7 sau khi tất cả agents hoàn thành — post-agent validation:

| Check | Method | Action on hit |
|-------|--------|---------------|
| `process\.env\.(?!NODE_ENV)` trong browser files | grep modified files từ `git diff --name-only` | WARNING → auto-fix hoặc escalate |
| `'(dev-secret\|admin123\|password\|changeme)'` | grep tất cả modified files | ERROR → block merge, yêu cầu fix |
| `console\.log\(` (trừ test files) | grep modified files | WARNING → log, suggest remove |
| `\.replace\(['\"][^/]` (non-regex replace) | grep modified *.ts,*.tsx | INFO → log, agent tự check |

Output: `$SESSION_DIR/agent-spot-check.json` (schema: `{passed: bool, warnings: [], errors: []}`).

Nếu `errors > 0` → block POST-GATE, yêu cầu agent fix lại.

---

### Sprint B: wf-plan-modules (4 items, ~5.5h)

#### B1 (P0, 2h) — Quality Sections trong Task File Template

**Files:**
- `.claude/doc-framework/phase5-implementation/tasks/[system]/[module]/[feature]-impl.md` (template)
- `.claude/skills/workflow/wf-plan-modules/procedures/phase7.5-tasks.md` (injection logic)

**What:** Thêm 2 sections mới vào task file template:

**A2.5 Quality Requirements (thêm sau A2.4 Scope Files):**

```markdown
### A2.5 Quality Requirements (AUTO-GENERATED — không sửa tay)

> Các checklist dưới đây được tự động sinh bởi wf-plan-modules dựa trên module type,
> interface type, và tech stack. Agent wf-implement-feature PHẢI verify từng mục.

#### Security Checklist
- [ ] **AUTH-01:** JWT expiry ≤ 1h, refresh token rotation có sẵn
- [ ] **AUTH-02:** Không hardcoded secrets/fallback values trong source
- [ ] **INPUT-01:** Tất cả user input được validate (type, length, format)
- [ ] **SQL-01:** Tất cả SQL queries dùng parameterized statements (không string concat)
- [ ] **XSS-01:** User-generated content được sanitize trước khi render
- [ ] **CORS-01:** CORS origin configurable qua environment variable
- [ ] **RATE-01:** Rate limiting trên auth endpoints (login, forgot-password, verify-otp)

#### Data Integrity Checklist
- [ ] **VALID-01:** NOT NULL columns được validate trước INSERT/UPDATE
- [ ] **FK-01:** Foreign key constraints enabled (PRAGMA foreign_keys = ON)
- [ ] **CONS-01:** Constants (exchange rates, tax rates, tiers) có single source of truth
- [ ] **ENV-01:** API response format nhất quán `{success, data, error}`

#### i18n Checklist _(conditional: chỉ khi interface_type != "api-only")_
- [ ] **I18N-01:** Tất cả user-facing strings qua `t()` function
- [ ] **I18N-02:** Placeholder, aria-label, alt text được translate
- [ ] **I18N-03:** Number/date formats theo locale (không hardcode định dạng)

#### Accessibility Checklist _(conditional: chỉ khi interface_type != "api-only")_
- [ ] **A11Y-01:** Label có `htmlFor` match với input `id`
- [ ] **A11Y-02:** Images có descriptive alt text (không "Product", "Avatar")
- [ ] **A11Y-03:** Modal/Drawer có focus trap + Escape to close
- [ ] **A11Y-04:** Error/success feedback dùng Toast component (không `alert()`)
- [ ] **A11Y-05:** Color không phải là chỉ báo duy nhất (thêm icon/text)

#### Performance Checklist _(conditional: chỉ khi interface_type != "api-only")_
- [ ] **PERF-01:** Large components dùng React.lazy() code splitting
- [ ] **PERF-02:** Expensive computations dùng useMemo / useCallback
- [ ] **PERF-03:** Images dùng lazy loading (`loading="lazy"`)
```

**A2.6 Environment Notes (thêm sau A2.5):**

```markdown
### A2.6 Environment Notes (AUTO-GENERATED)

| Aspect | Rule | Reason |
|--------|------|--------|
| Build tool | [detected] | [specific rules] |
| Env vars client | [prefix pattern] | [security note] |
| Env vars server | [validation rule] | [fallback rule] |
| Framework | [React/Vue/etc] | [specific rules] |
| CSS | [Tailwind/CSS Modules/etc] | [optimization note] |
```

**Phase 7.5 injection logic (trong phase7.5-tasks.md):**

Thêm step 7.5.3a — trước khi spawn architect agents, compute:
- `$QUALITY_SECTIONS`: dựa trên module type prefix + interface_type + tech stack
- `$ENV_NOTES`: dựa trên detection từ project-profile.json hoặc package.json

Inject `$QUALITY_SECTIONS` và `$ENV_NOTES` vào `TASK_GENERATION_PROMPT_TEMPLATE` dưới dạng additional context parameters.

**Conditional logic cho checklist items:**

| Module prefix | Extra security items |
|---------------|---------------------|
| `auth` | AUTH-01, AUTH-02 expanded |
| `payment`, `wallet` | DATA-01 expanded (audit trail) |
| `crm`, `profile` | I18N-01-03, A11Y-01-05 all enabled |
| `admin` | A11Y-01-05 all enabled |
| `api`, `webhook` | ENV-01, RATE-01 |

| interface_type | Sections enabled |
|----------------|-----------------|
| `web` | Tất cả sections |
| `mobile` | Security + Data Integrity + i18n (skip A11Y web-specific) |
| `api-only` | Security + Data Integrity only |

---

#### B2 (P0, 1h) — Environment Context trong Task File

**File:** `.claude/doc-framework/phase5-implementation/tasks/[system]/[module]/[feature]-impl.md`

**What:** Thêm A2.6 section (như trên) vào template. Phase 7.5 sẽ auto-populate dựa trên tech stack detection.

**Detection source (trong phase7.5-tasks.md Step 7.5.3a):**
- Đọc `.mc-data/work/legacy-scan/project-profile.json` (LEGACY_MODE)
- Hoặc scan `package.json` trong source directory
- Fallback: parse `apps/*/package.json` hoặc root `package.json`

**Environment notes template mapping:**

| Detection | A2.6 Row |
|-----------|----------|
| `"vite"` in devDependencies | Build tool: Vite — dùng `import.meta.env.VITE_*` cho client, KHÔNG dùng `process.env` |
| `"react"` in dependencies | Framework: React — Strict Mode, hooks exhaustive-deps, useEffect cleanup |
| `"tailwindcss"` in devDependencies | CSS: Tailwind — dùng `@apply` trong CSS modules, KHÔNG CDN trong production |
| `"hono"` or `"express"` in dependencies | Server: [name] — validate env vars at startup, throw nếu thiếu |
| `"better-sqlite3"` in dependencies | Database: SQLite — PRAGMA foreign_keys = ON, parameterized queries |

---

#### B3 (P1, 1.5h) — Code Quality Scan trong Phase 1.5

**File:** `.claude/skills/workflow/wf-plan-modules/procedures/phase1.5-legacy-impl.md`

**What:** Khi `implementation_strategy == COMPLETE_EXISTING` và `confidence >= 0.7`, thêm step 1.5.3b — quick grep scan cho common issues. KHÔNG spawn full agent (quá nặng), chỉ chạy bash grep patterns:

| # | Pattern | What it finds |
|---|---------|---------------|
| G1 | `grep -rn 'process\.env\.' --include='*.tsx' --include='*.jsx' apps/` | `process.env` in browser code |
| G2 | `grep -rn "dev-secret\|admin123\|changeme\|temp_key" apps/` | Hardcoded secrets |
| G3 | `grep -rn '\.replace([^/]' --include='*.ts' --include='*.tsx' apps/` | Non-global replace |
| G4 | `grep -rn 'alert(' --include='*.tsx' --include='*.jsx' apps/` | alert() calls (accessibility) |
| G5 | `grep -rn 'console\.log(' --include='*.ts' --include='*.tsx' apps/` | Console.log leaks |

Append findings vào `gaps_identified` trong `feature-impl-map.json`:

```json
{
  "feat_id": "FEAT-WC-AUTH-001",
  "gaps_identified": [
    "Unit tests missing",
    "Error messages hardcoded tiếng Việt",
    "AUTO-SCAN: process.env in Login.tsx (line 45) — Vite browser code",
    "AUTO-SCAN: Hardcoded 'dev-secret' in middleware/auth.ts (line 10)"
  ]
}
```

**Scope giới hạn:** Chỉ scan files trong `existing_code_refs[]` của feature đó, không scan toàn bộ repo.

**Performance:** grep patterns chạy nhanh (<2s cho 100 files), không đáng kể so với tổng thời gian Phase 1.5.

---

#### B4 (P1, 1h) — Domain-Specific Injection

**File:** `.claude/skills/workflow/wf-plan-modules/procedures/phase7.5-tasks.md`

**What:** Mở rộng `$QUALITY_SECTIONS` computation trong Step 7.5.3a với domain-specific rules:

| Domain | Module IDs | Extra checklist items |
|--------|-----------|----------------------|
| **E-commerce** | `orders`, `products`, `cart`, `checkout` | Payment security (PCI-DSS), inventory sync, order idempotency |
| **Finance** | `finance`, `accounting`, `tax`, `wallet`, `debt` | Audit trail, tính chính xác số học, currency rounding |
| **Logistics** | `tms`, `wms`, `customs`, `sourcing` | HS Code accuracy, Incoterms, container tracking |
| **HR** | `hrm`, `payroll` | Labor law compliance, tax withholding, data privacy |
| **CRM** | `crm`, `marketing`, `loyalty` | Customer data privacy, consent management, campaign attribution |

**Mapping:** Đọc `req-registry.json` → `departments[]` field → map sang domain → inject domain-specific checklist items.

---

## Critical Files Summary

### Files to CREATE:
1. `.claude/skills/workflow/wf-implement-feature/procedures/phase0-6-env-profile.md` — Environment profile detection (A4)

### Files to MODIFY:
1. `.claude/skills/workflow/wf-implement-feature/procedures/phase0-7-safety-gate.md` — Add environment safety scan patterns (A1)
2. `.claude/skills/workflow/wf-implement-feature/templates/qa-review-report.md` — Expand checklist (A2)
3. `.claude/skills/workflow/wf-implement-feature/procedures/phase4-5-review-fix.md` — Security mandatory (A3) + VERIFY_ONLY enhancement (A5) + Agent spot-check (A6)
4. `.claude/skills/workflow/wf-implement-feature/SKILL.md` — Add phase0-6 to execution DAG (A4)
5. `.claude/skills/workflow/wf-implement-feature/procedures/_shared.md` — Add ENV_PROFILE to state variables (A4)
6. `.claude/doc-framework/phase5-implementation/tasks/[system]/[module]/[feature]-impl.md` — Add A2.5+A2.6 sections (B1+B2)
7. `.claude/skills/workflow/wf-plan-modules/procedures/phase7.5-tasks.md` — Quality section injection logic (B1+B2+B4)
8. `.claude/skills/workflow/wf-plan-modules/procedures/phase1.5-legacy-impl.md` — Code quality scan (B3)

---

## Implementation Order

```
Sprint A (wf-implement-feature):
  Day 1: A1 (2h) → A2 (1h) → A3 (0.5h)
  Day 2: A4 (1.5h) → A5 (1h) → A6 (1h)

Sprint B (wf-plan-modules):
  Day 3: B1 (2h) → B2 (1h)
  Day 4: B3 (1.5h) → B4 (1h)
```

A1+A2+B1 nên làm trước (P0, impact cao nhất, giải quyết ~50% vấn đề).

---

## Verification Plan

### Per-Item Verification

| Item | Verify method |
|------|---------------|
| A1 | Chạy thử Safety Gate trên EUREKA-2026 web-customer → phải phát hiện process.env trong services/gemini.ts, hardcoded secret trong middleware/auth.ts |
| A2 | Agent chạy review trên sample code có lỗi → checklist phải có entries cho env safety, runtime safety, i18n |
| A3 | Auth feature với standard profile → security agent PHẢI được spawn |
| A4 | Chạy trên EUREKA-2026 → phải detect `vite` profile |
| A5 | VERIFY_ONLY feature → phải có qa-review-attempt-0.md với gaps |
| A6 | Agent sửa code thêm `console.log` → spot-check phải WARNING |
| B1 | Generate task file cho auth module → phải có A2.5 Security Checklist |
| B2 | Generate task file cho web UI module → phải có A2.6 Environment Notes |
| B3 | COMPLETE_EXISTING feature → gaps_identified phải có AUTO-SCAN findings |
| B4 | Finance module → checklist phải có audit trail items |

### End-to-End Verification

1. Chạy `/wf-plan-modules` trên EUREKA-2026 → task files mới phải có A2.5 + A2.6
2. Chạy `/wf-implement-feature` với COMPLETE_EXISTING feature → Safety Gate phải phát hiện environment issues, review phải cover checklist mở rộng
3. Re-run `/wf-fix-bugs` trên web-customer → số lượng issues CRITICAL/HIGH phải giảm đáng kể (target: -30%)

### Compliance Checks

- `./.claude/scripts/skill-compliance-audit.sh wf-implement-feature` → PASS
- `./.claude/scripts/skill-compliance-audit.sh wf-plan-modules` → PASS
- `./.claude/scripts/validate-schema-sync.sh wf-implement-feature` → PASS
- `./.claude/scripts/validate-schema-sync.sh wf-plan-modules` → PASS
