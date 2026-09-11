# Playbook: Kiểm thử Bảo mật API

> **Type**: Agent Skill Playbook
> **Agent**: api-tester
> **Triggered by**: Security testing của API endpoints trước khi deploy
> **Output**: API Security Test Report tại path do skill cung cấp

---

## Khi nào dùng playbook này

- Trước khi release API lên production (bắt buộc)
- Khi có thay đổi authentication/authorization logic
- Định kỳ (hàng tháng) cho production APIs
- Sau khi có security incident liên quan đến API
- Khi onboard API endpoint mới có xử lý dữ liệu nhạy cảm

**Nguyên tắc**: Mọi phát hiện bảo mật nghiêm trọng → escalate ngay sang security agent. Không tự ý "fix nhỏ" mà không có review từ security.

---

## Procedure

### Bước 1: Thu thập ngữ cảnh API

```
INPUT: API spec, danh sách endpoints, môi trường test do skill cung cấp
FALLBACK: tra .claude/references/path-registry.md → PHASE3

Thu thập:
□ Danh sách endpoints và HTTP methods
□ Authentication scheme (JWT, API key, OAuth2, session cookie)
□ Authorization model (RBAC, ABAC, ownership-based)
□ Sensitive data fields (PII, payment info, credentials)
□ REQ-IDs liên quan từ req-registry.json

READ: .claude/references/team-expert/testing/api-testing-patterns.md
READ: .claude/references/team-expert/testing/api-test-examples.md

CẢNH BÁO: Chỉ test trên môi trường staging/test, KHÔNG test trên production.
Chuẩn bị test accounts với các roles khác nhau:
  - Anonymous (không có token)
  - Regular user (role: user)
  - Admin user (role: admin)
  - User B (để test IDOR — cross-user access)
```

### Bước 2: Authentication Bypass Attempts

```
Test các cách bypass authentication:

Missing token:
□ Request không có Authorization header → 401?
□ Request có header "Authorization: " (empty) → 401?
□ Request có header "Authorization: Bearer " (empty token) → 401?

Invalid token formats:
□ "Authorization: Bearer invalid_string" → 401?
□ "Authorization: Bearer null" → 401?
□ "Authorization: Bearer undefined" → 401?
□ JWT với invalid signature → 401?
□ JWT với expired timestamp → 401?
□ JWT với future "issued at" (iat) → 401 hoặc 403?

Token manipulation (JWT):
□ JWT với algorithm "none" (alg: none attack) → rejected?
□ JWT với RS256 thay bằng HS256 (algorithm confusion) → rejected?
□ JWT payload thay đổi user_id nhưng không re-sign → 401?
□ JWT với elevated role claim tự thêm vào → không có effect?

Session/Cookie (nếu dùng session):
□ Session fixation: dùng session ID cũ sau khi login → invalid?
□ Session replay: dùng session đã logout → 401?
□ Cookie có HttpOnly flag không?
□ Cookie có Secure flag (HTTPS only) không?
□ Cookie có SameSite attribute không?

Phát hiện bypass bất kỳ → BLOCKER, escalate sang security agent
```

### Bước 3: Authorization — IDOR và Privilege Escalation

```
IDOR (Insecure Direct Object Reference):
□ User A không được access resource của User B

Test pattern:
  1. Login với User A → tạo resource (order, profile, document)
     → ghi lại resource ID (e.g., order_id: 123)
  2. Login với User B
  3. User B GET /orders/123 → 403 hoặc 404 (không phải 200)
  4. User B PUT /orders/123 → 403 hoặc 404
  5. User B DELETE /orders/123 → 403 hoặc 404

Test với numeric IDs (dễ đoán):
□ Enumerate IDs: /users/1, /users/2, /users/3 → chỉ access được của mình?
□ Bulk endpoints: GET /orders?user_id=456 → không được lấy data của user khác?
□ Nested resources: /users/456/settings → User A không access được User B settings?

Privilege Escalation (Vertical):
□ Regular user gọi admin-only endpoints → 403?
□ Regular user sửa role field của mình thành "admin" → không có effect?
□ Regular user thực hiện admin actions qua API trực tiếp → 403?
□ Batch operations: tạo 1000 records khi limit là 10 → rejected?

Privilege Escalation (Horizontal):
□ Manager của team A không access được team B data?
□ Read-only role không POST/PUT/DELETE được?

Phát hiện IDOR → BLOCKER, escalate sang security agent
```

### Bước 4: Input Validation — Injection và Fuzzing

```
SQL Injection:
□ String fields: ' OR '1'='1 → không có data leak, không có 500
□ Numeric fields: 1 OR 1=1 → không có effect
□ Search fields: %' OR '%'=' → không dump database
□ Order/sort params: id; DROP TABLE users → rejected
□ ORM usage: raw query với user input? → BLOCKER nếu có

XSS (Cross-Site Scripting) — chỉ relevant nếu API trả về HTML:
□ <script>alert(1)</script> trong string fields → được encode không?
□ Nếu API trả về JSON chỉ: XSS ít relevant nhưng vẫn check encoding

Command Injection (nếu API có file processing):
□ Filename: ../../../../etc/passwd → rejected?
□ Filename: file.txt; rm -rf / → rejected?

NoSQL Injection (MongoDB, etc.):
□ {"$gt": ""} trong filter params → không trả về all records?
□ {"$where": "sleep(5000)"} → không gây delay?

Path Traversal:
□ /files/../../../etc/passwd → 400/403?
□ File download: ?filename=../../config.json → rejected?

Fuzzing với special characters:
□ Emoji, Unicode, null bytes (\x00), newlines (\n\r) trong string fields
□ Rất dài string (10,000 chars) → 413 hoặc 422, không crash
□ Deeply nested JSON (100 levels) → rejected gracefully?
□ Array với 10,000 items → 413 hoặc 422, không crash

Phát hiện injection vulnerability → BLOCKER, escalate ngay
```

### Bước 5: Rate Limiting Effectiveness

```
Test rate limiting implementation:

Authentication endpoints (tấn công brute force):
□ POST /auth/login: 100 requests/phút → rate limit triggered?
□ POST /auth/forgot-password: 10 requests/phút → rate limit triggered?
□ POST /auth/verify-otp: 5 attempts → account locked?
□ Rate limit response: 429 với Retry-After header?

API endpoints:
□ Regular endpoints: 1000 requests/phút per user → rate limit?
□ Expensive endpoints: 10 requests/phút per user → rate limit?
□ Rate limit per IP hoặc per user?

Rate limit bypass attempts:
□ Thay đổi IP (X-Forwarded-For header manipulation) → vẫn bị limit?
□ Thay đổi User-Agent → vẫn bị limit?
□ Dùng nhiều user accounts → global rate limit per IP?
□ Distributed attack simulation → DDoS protection?

Rate limit response format:
□ 429 status code?
□ Retry-After: [seconds] header?
□ X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset headers?

Không có rate limit trên auth endpoints → BLOCKER
```

### Bước 6: Sensitive Data Exposure

```
Kiểm tra data không được expose:

Response body:
□ Password hash KHÔNG được có trong response (bất kỳ endpoint nào)?
□ Internal server paths không xuất hiện trong error messages?
□ Database IDs nội bộ (autoincrement) không thay vì UUIDs?
□ Stack traces không xuất hiện trong production responses?
□ API keys, tokens của third-party không được log/return?

Response headers:
□ Server header có reveal version không? (e.g., "Server: nginx/1.18.0" → ẩn version)
□ X-Powered-By header tắt chưa? (e.g., "X-Powered-By: Express" → remove)
□ Via header không có internal routing info?

Logs (yêu cầu dev check):
□ Passwords không được log (kể cả ở debug level)?
□ Credit card numbers, CVV không được log?
□ JWT tokens không được log đầy đủ?
□ PII (tên, email, phone, CMND) không được log raw?

Debug endpoints (không được có trên production):
□ /debug, /info, /health chi tiết → chỉ 200 OK, không có sensitive info?
□ /metrics endpoint có auth không?
□ Swagger/OpenAPI UI tắt trên production?
□ /actuator (Spring Boot) endpoints có auth không?
□ GraphQL introspection tắt trên production?
```

### Bước 7: CORS Misconfiguration

```
Kiểm tra CORS policy:

□ Access-Control-Allow-Origin: * (wildcard) được dùng cho private APIs? → FAIL
□ Wildcard CORS + credentials allowed → CRITICAL FAIL

Test CORS headers:
  Request: Origin: https://evil.com
  Response: Access-Control-Allow-Origin: https://evil.com → misconfigured

  Request: Origin: null
  Response: Access-Control-Allow-Origin: null → FAIL (allows local file attacks)

Allowed origins:
□ Chỉ whitelist domains thực sự cần?
□ Subdomain wildcard: *.trusted-domain.com → có chấp nhận evil.trusted-domain.com không?
□ Origin header dễ bypass: https://trusted.com.evil.com → bị reject?

Preflight (OPTIONS) requests:
□ OPTIONS request trả về đúng CORS headers không?
□ Non-simple requests (PUT, DELETE, custom headers) có preflight check không?

Credentials:
□ Access-Control-Allow-Credentials: true chỉ với specific origins?
□ Không bao giờ dùng * với credentials:true?
```

### Bước 8: Security Headers

```
Kiểm tra HTTP response security headers:

Bắt buộc có:
□ Content-Security-Policy (CSP) cho web APIs?
□ X-Content-Type-Options: nosniff
□ X-Frame-Options: DENY (hoặc SAMEORIGIN)
□ Strict-Transport-Security: max-age=31536000; includeSubDomains (HTTPS only)
□ Referrer-Policy: strict-origin-when-cross-origin

Không được có:
□ X-Powered-By (expose framework info)
□ Server: với version number

HTTPS:
□ HTTP traffic redirect sang HTTPS (301)?
□ HSTS preload list?
□ TLS version: chỉ TLS 1.2+ (không có TLS 1.0/1.1)?
□ Weak cipher suites bị disable?

API-specific:
□ Cache-Control: no-store cho endpoints trả về sensitive data?
□ Content-Type: application/json cho JSON responses?
```

### Bước 9: API Versioning Exposure

```
Kiểm tra information disclosure qua versioning:

URL-based versioning:
□ /v1/ endpoints có bị deprecated không? Nếu có → redirect sang v2 hay 410?
□ /v0/ hoặc /beta/ endpoints có được remove trên production không?
□ Version enumeration: thử /v0, /v1, /v2, /v99 → không leak info

Header-based versioning:
□ Unsupported version trong header → 400 với clear error (không phải default version silently)

GraphQL (nếu có):
□ Introspection query disabled trên production?
□ Overly permissive query depth limit?
□ Query cost analysis/limiting?

Error messages không được reveal:
□ "Endpoint moved to v2" → không nên có trong 404 của production
□ Stack trace không được có version info của framework
□ Error messages không reveal database type (MySQL, PostgreSQL)
```

---

## Format Output: API Security Test Report

```markdown
## API Security Test Report

**Agent**: api-tester
**Ngày test**: [date]
**Environment**: staging (KHÔNG phải production)
**Scope**: [N] endpoints
**Kết luận**: [PASS / FAIL — có thể deploy / không được deploy]

---

### Executive Summary
[2-3 câu: tổng số findings, critical issues, overall security posture]

---

### Findings theo Severity

#### CRITICAL (phải fix trước khi deploy)
| # | Endpoint | Loại | Mô tả | Evidence | REQ-ID |
|---|----------|------|-------|----------|--------|
| 1 | POST /auth/login | Brute Force | Không có rate limiting | 1000 req/min không bị block | ... |

#### HIGH (fix trong sprint này)
| # | Endpoint | Loại | Mô tả | Gợi ý |
|---|----------|------|-------|-------|

#### MEDIUM (fix trong 2 sprints)
| # | Endpoint | Loại | Mô tả | Gợi ý |
|---|----------|------|-------|-------|

#### LOW (fix trong backlog)
| # | Loại | Mô tả |
|---|------|-------|

#### INFORMATIONAL (không cần fix, chỉ để biết)
- [...]

---

### OWASP API Security Top 10 Coverage

| OWASP ID | Tên | Tested | Kết quả |
|----------|-----|--------|---------|
| API1 | Broken Object Level Authorization | YES | PASS |
| API2 | Broken Authentication | YES | FAIL — xem finding #1 |
| API3 | Broken Object Property Level Authorization | YES | PASS |
| API4 | Unrestricted Resource Consumption | YES | PASS |
| API5 | Broken Function Level Authorization | YES | PASS |
| API6 | Unrestricted Access to Sensitive Business Flows | YES | PASS |
| API7 | Server Side Request Forgery | PARTIAL | N/A |
| API8 | Security Misconfiguration | YES | FAIL — xem finding #3 |
| API9 | Improper Inventory Management | YES | PASS |
| API10 | Unsafe Consumption of APIs | N/A | Not tested |

---

### Security Headers Check

| Header | Status | Ghi chú |
|--------|--------|---------|
| X-Content-Type-Options | PRESENT | nosniff |
| X-Frame-Options | PRESENT | DENY |
| Strict-Transport-Security | PRESENT | max-age=31536000 |
| Content-Security-Policy | MISSING | Cần thêm |
| X-Powered-By | PRESENT | Nên xóa (expose Express version) |

---

### Authentication & Authorization Summary
- Auth bypass attempts: [N] tested, [N] PASS, [N] FAIL
- IDOR tests: [N] tested, [N] PASS, [N] FAIL
- Privilege escalation: [N] tested, [N] PASS, [N] FAIL
- Rate limiting: [N] endpoints tested, [N] have rate limiting

---

### Go/No-Go Recommendation
**[PASS — có thể deploy / FAIL — không được deploy]**

Điều kiện để deploy (nếu FAIL):
1. [Fix finding #1: thêm rate limiting cho /auth/login — ETA: 2h]
2. [Fix finding #3: remove X-Powered-By header — ETA: 30m]
```

---

## Checklist trước khi submit

```
□ Chỉ test trên staging (không phải production)
□ Test accounts đủ roles: anonymous, user, admin, cross-user
□ Authentication bypass: ít nhất 5 attack vectors
□ IDOR test: cross-user access cho mọi resource endpoint
□ Input validation: SQL injection, XSS, path traversal
□ Rate limiting trên auth endpoints
□ Sensitive data: password, API keys không trong response
□ CORS policy verified
□ Security headers check
□ OWASP API Top 10 đã cover (ghi rõ N/A nếu không áp dụng)
□ Critical findings được escalate sang security agent
□ REQ-ID được reference
□ Go/No-Go recommendation rõ ràng
```
