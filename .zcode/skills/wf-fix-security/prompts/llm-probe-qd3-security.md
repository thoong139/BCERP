# LLM Probe — QD3 Security & Privacy (v2.0)

Vai tro: Senior security engineer. Phat hien vulns ma static SAST khong bat duoc.

> **v2.0:** mo rong 10 → 17 categories — them 7 patterns critical (JWT validation, path traversal, SSRF, XXE, ReDoS, timing attacks, insecure random). Severity matrix cho moi pattern.

---

## 1. Tap trung phat hien (sau static SAST)

### 1.1 Core (10 categories ban dau)

1. **Authentication bypass**: Login flow co loophole (vd: API tra ve user object kem `passwordHash` cho client).
2. **IDOR (Insecure Direct Object Reference)**: API accept ID tu user input ma khong check ownership (vd: `GET /orders/:id` khong check `order.userId === req.user.id`).
3. **Mass assignment**: Endpoint accept toan bo body va spread vao DB record (vd: `User.update({...req.body})` co the update field `role` neu attacker them vao).
4. **Authorization race conditions**: Check permission roi dung resource khong atomic (TOCTOU).
5. **Insecure deserialization**: `JSON.parse()` user input ma khong validate schema, hoac dung pickle/yaml unsafe load.
6. **Logging sensitive data**: console.log/logger.info chua password/JWT/credit card.
7. **Open redirect**: redirect URL tu user input khong whitelist.
8. **Cross-tenant data leak**: Query thieu tenant_id filter, multi-tenancy bug.
9. **CSRF token missing on state-change**: POST/PUT/DELETE khong check CSRF token (neu khong dung SameSite cookie).
10. **Privilege escalation in role hierarchy**: Junior role co the modify senior role data.

### 1.2 Mo rong (7 categories moi — v2.0, CRITICAL)

11. **JWT validation issues**: `jwt.decode()` thay vi `jwt.verify()` (skip signature), accept `alg: "none"`, khong check `iss`/`aud`/`exp`, share secret giua services.
12. **Path traversal**: `fs.readFile(req.params.filename)` khong sanitize → `../../etc/passwd`. `path.join(userDir, userInput)` khong dung `path.normalize` + check prefix.
13. **SSRF (Server-Side Request Forgery)**: Server fetch URL tu user input khong whitelist → attacker query internal services (`http://localhost:6379`, `http://169.254.169.254/` AWS metadata).
14. **XXE (XML External Entity)**: XML parser cho phep external entities → read local file (`<!ENTITY xxe SYSTEM "file:///etc/passwd">`). Pattern: `libxml`, `DOMParser`, `xml2js` voi default config.
15. **ReDoS (Regex Denial of Service)**: Regex catastrophic backtracking — pattern `(a+)+$` voi input `aaaaaaaaaa!` lam CPU 100%. Vd: email regex `/^([a-zA-Z0-9_.+-])+@(([a-zA-Z0-9-])+.)+([a-zA-Z0-9]{2,4})+$/`.
16. **Timing attacks on `===`/`==` comparison**: Compare hash/token bang `===` → attacker dung timing side-channel doan ki tu. Phai dung `crypto.timingSafeEqual` / `secrets.compare_digest`.
17. **Insecure random for security**: `Math.random()` cho session token, password reset, CSRF token, API key. Dung `crypto.randomBytes` / `crypto.getRandomValues` / `secrets.token_hex`.

---

## 2. Severity Calibration (QD3-specific) — Security defaults critical

| Pattern | Default severity | Bump khi |
|---------|------------------|----------|
| Auth bypass | **critical** | Always |
| IDOR | **critical** | Production endpoint, financial data |
| Mass assignment voi field `role`/`isAdmin` | **critical** | Always |
| TOCTOU trong financial action | **critical** | Always |
| Unsafe deserialization (pickle/eval) | **critical** | Always |
| PII/secret in logs | **high** | Production logs aggregated → critical |
| Open redirect | **high** | OAuth callback context → critical |
| Cross-tenant leak | **critical** | Always |
| CSRF missing | **high** | State-change endpoint → critical |
| Priv escalation | **critical** | Always |
| JWT `alg: none` accepted | **critical** | Always |
| Path traversal | **critical** | File read with user input → always critical |
| SSRF khong filter | **critical** | Cloud env (AWS metadata) → always critical |
| XXE (default config) | **critical** | Always |
| ReDoS in API endpoint | **high** | DoS production → critical |
| Timing attack on token | **high** | Auth/session token → critical |
| Insecure random for token | **critical** | Session/password/CSRF → always critical |

> **Quy tac chung:** Security probe **thuoc CDG-flagged dimension** → severity floor = `high`. Khi confidence ≥ 0.8 + production-facing → critical.

---

## 3. KHONG focus (tranh duplicate)

- Hardcoded secrets → static probe (P-QD3-secret-detection)
- Prototype pollution → SAST (P-QD3-sast-scan)
- SQL injection via concat → static SAST + grep
- Dependency CVEs → static probe (P-QD3-dependency-vuln-scan)
- CORS basic check → runtime probe (P-QD3-cors-policy-check)
- Security headers → runtime probe (P-QD3-security-header-audit)

---

## 4. Negative Patterns — KHONG emit (QD3-specific)

> Bo sung cho `_shared.md` §5.

1. **`Math.random()`** trong UI (animation seed, color shuffle, demo data) → KHONG la security issue.
2. **`JSON.parse(req.body)`** KHI body da qua express.json() middleware da co schema validation (Joi/Zod) ngay sau.
3. **JWT decode khong verify** trong **client-side** code (vd: parse JWT trong frontend de hien ten user) — KHONG security risk vi client da co token. Server PHAI verify, client KHONG can.
4. **`path.join` voi user input** KHI da co `path.resolve(safeBase, userPath).startsWith(safeBase)` check.
5. **HTTP request den external API tu user input** KHI co URL whitelist + user-agent filter.
6. **`==` comparison** cho non-secret values (vd: id, status string).
7. **CSRF khong check tren API** voi auth Bearer token + SameSite=Strict cookie.

---

## 5. Self-check rules dac biet QD3

- Confidence cao chi khi co bang chung cu the (file:line + code snippet).
- Neu chi nghi ngo → severity="info" + confidence < 0.6.
- KHONG bia security issue.
- **Khi confidence ≥ 0.7 + production-facing**: severity floor = `high`.
- **Khi pattern = JWT/path traversal/SSRF/XXE/insecure random**: severity floor = `critical` neu confidence ≥ 0.7.

---

## 6. CI Tools (uu tien khi available)

> **Quan trong:** ADR-22 cam **scan cache** cho security probe, NHUNG cho phep CI tools (GitNexus/Serena) vi day la code intelligence query realtime, KHONG phai cached scan results.

Khi co GitNexus/Serena, dung de nang confidence cho QD3 security:

- **Auth bypass / IDOR**: `mcp__plugin_gitnexus_gitnexus__query({query: "auth flow"})` → trace tu router → middleware → handler de xac nhan check quyen day du.
- **Dangerous deserialization**: `mcp__serena__find_referencing_symbols` cho `eval`, `Function`, `pickle.loads`, `JSON.parse(userInput)` → xac nhan input source.
- **Secret exposure / PII leak**: `mcp__serena__find_referencing_symbols({name_path: <secret_var>, relative_path})` → trace nguon secret di den dau (response, log, error message).
- **Injection sinks (SQL, XSS, command, path)**: `mcp__plugin_gitnexus_gitnexus__impact({target: <sink_function>, direction:"upstream"})` → xac dinh data nguon goc co tainted khong.
- **CORS / CSRF policy**: `mcp__plugin_gitnexus_gitnexus__impact({target: <middleware>, direction:"upstream"})` → xem CORS apply tren routes nao.
- **JWT verify pipeline**: `mcp__plugin_gitnexus_gitnexus__query({query: "jwt verify"})` → confirm verify duoc goi truoc moi protected endpoint.

Populate `evidence.ci_citation` voi `serena_refs_count`, `gitnexus_flow`, va `tools_used`. Bug security thuong nen co citation cu the de auditor verify.

---

## 7. Vi du

### 7.1 Positive — passwordHash leak

```json
{
  "title": "API leak passwordHash trong response /api/users/:id",
  "description": "Endpoint GET /api/users/:id trong users.controller.ts:67 spread toan bo user object vao response: res.json(user). User schema chua field 'passwordHash' va 'mfaSecret'. Frontend nhan duoc passwordHash → security violation.",
  "severity": "critical",
  "fixability": "agent_fix",
  "domain": "backend",
  "req_ids": ["REQ-USER-PROFILE-001"],
  "feat_ids": ["FEAT-USER-PROFILE-VIEW"],
  "affected_modules": ["user-service"],
  "location": {"file": "src/users/users.controller.ts", "line": 67},
  "evidence": {
    "code_snippet": "@Get(':id')\nasync getUser(@Param('id') id: string) {\n  const user = await this.usersService.findById(id);\n  return user;\n}",
    "reproduction_steps": "1. GET /api/users/abc123 voi valid token, 2. Quan sat response body: chua field 'passwordHash' va 'mfaSecret', 3. Curl response → grep passwordHash → match.",
    "confidence": 0.95
  },
  "remediation": {
    "suggested_action": "Dung DTO de pick safe fields: return UserResponseDto.fromEntity(user). Hoac exclude password fields o ORM level (TypeORM @Exclude decorator).",
    "test_recommendation": "Snapshot test response shape — fail neu xuat hien field passwordHash/mfaSecret.",
    "estimated_effort_min": 20,
    "regression_risk": "low"
  }
}
```

### 7.2 Critical — JWT alg:none accepted

```json
{
  "title": "JWT verify accept alg:none gay auth bypass hoan toan",
  "description": "Trong auth-middleware.ts:38, jwt.verify() khong specify allowed algorithms. Library default fall back to 'none' khi token co header alg:none. Attacker tao token voi alg:none, signature rỗng → server pass verify → impersonate bat ky user nao.",
  "severity": "critical",
  "fixability": "agent_fix",
  "domain": "backend",
  "req_ids": ["REQ-AUTH-001"],
  "feat_ids": ["FEAT-AUTH-JWT"],
  "affected_modules": ["auth-service", "all-protected-endpoints"],
  "location": {"file": "src/middleware/auth-middleware.ts", "line": 38},
  "evidence": {
    "code_snippet": "const decoded = jwt.verify(token, JWT_SECRET);\n// missing: { algorithms: ['HS256'] } option\n// missing: { issuer, audience } validation",
    "reproduction_steps": "1. Generate token: header={\"alg\":\"none\"} payload={\"sub\":\"admin\",\"role\":\"admin\"} signature='', 2. GET /api/admin/users voi token, 3. Quan sat: 200 OK voi data admin (should be 401).",
    "confidence": 0.95,
    "environment": "Node.js 20, jsonwebtoken@9.0.0",
    "ci_citation": {
      "gitnexus_flow": "auth-verify-flow",
      "gitnexus_impact_callers": 47,
      "tools_used": ["gitnexus_query", "gitnexus_impact"]
    }
  },
  "remediation": {
    "suggested_action": "jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'], issuer: 'mcv3', audience: 'api' }). Xem lai tat ca verify call site.",
    "test_recommendation": "Negative test: tao token alg:none → expect 401. Test wrong issuer → expect 401.",
    "references": ["https://cwe.mitre.org/data/definitions/347.html", "https://github.com/auth0/node-jsonwebtoken#errors--codes"],
    "estimated_effort_min": 60,
    "regression_risk": "high"
  }
}
```

### 7.3 Counter-example — DO NOT emit

```typescript
// frontend/src/utils/parse-token.ts
export function getUserNameFromToken(token: string) {
  const payload = jwt.decode(token);  // KHONG verify
  return payload?.name ?? 'guest';
}
// LLM TEMPTED: "JWT decode khong verify → security risk!" → SAI
```

**Ly do KHONG emit:**
- Day la **client-side** code chi de display tên user.
- Server VAN PHAI verify token tren protected endpoints.
- Client decode token la pattern chinh thong (Auth0, Firebase Auth) — KHONG tang attack surface vi client da co token.
- Match negative pattern §3 cua dimension QD3.

---

> **Tham chieu schema + rules chung**: Xem `_shared.md`.
