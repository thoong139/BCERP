# Security Checklist - OWASP, Authentication & Input Validation

> **Domain**: Engineering / Security
> **Last Updated**: 2026-03-22
> **Nguồn**: OWASP Top 10 (2021), NIST SP 800-63, CWE Top 25, SANS Top 20

---

## 1. OWASP Top 10 (2021) Quick Reference

| # | Rủi ro | Phòng tránh |
|---|--------|------------|
| A01 | Broken Access Control | Kiểm tra authz mọi request, deny by default, test với user không có quyền |
| A02 | Cryptographic Failures | Dùng TLS 1.2+, mã hóa PII at rest, không dùng MD5/SHA1 |
| A03 | Injection (SQL, Command, LDAP) | Parameterized queries, input validation, ORMs |
| A04 | Insecure Design | Threat modeling, secure design patterns, security requirements |
| A05 | Security Misconfiguration | Hardening checklist, disable debug mode production, scan với tools |
| A06 | Vulnerable Components | SCA scanning, CVE monitoring, update dependencies |
| A07 | Auth & Session Failures | MFA, strong password policy, secure session management |
| A08 | Software & Data Integrity | Code signing, verify downloads, SLSA framework |
| A09 | Security Logging Failures | Log auth events, anomaly detection, centralized logging |
| A10 | SSRF | Allowlist external URLs, block internal IP ranges, network segmentation |

---

## 2. Authentication Patterns Comparison

| Pattern | Cơ chế | Stateless | Phù hợp | Rủi ro |
|---------|--------|-----------|---------|--------|
| Session (Cookie) | Server lưu session state | Không | Web apps truyền thống | Session fixation, CSRF |
| JWT (Access Token) | Signed token, client lưu | Có | API, SPA, mobile | Token theft (không revoke được) |
| OAuth2 + OIDC | Authorization delegation | Có | Third-party login, B2B | Misconfiguration phức tạp |
| API Key | Pre-shared key | Có | Machine-to-machine, B2B API | Key leak, không có expiry |

### JWT Best Practices

```
DOs:
  - Dùng RS256 hoặc ES256 (asymmetric) — không dùng HS256 cho public API
  - Access token TTL ngắn: 15 phút
  - Refresh token TTL dài hơn: 7–30 ngày, lưu HttpOnly cookie
  - Validate: exp, iss, aud mọi request
  - Dùng token rotation cho refresh tokens (refresh token một lần)

DON'Ts:
  - Không lưu JWT trong localStorage (XSS risk)
  - Không đặt sensitive data trong payload (base64 decoded dễ dàng)
  - Không dùng alg: "none"
```

---

## 3. Authorization Patterns

| Pattern | Mô tả | Phù hợp | Ví dụ |
|---------|-------|---------|-------|
| RBAC | Quyền gắn với Role | Ứng dụng phổ biến, domain rõ ràng | admin, manager, viewer |
| ABAC | Quyền dựa trên Attributes (user, resource, environment) | Policy phức tạp, dynamic | "Manager chỉ xem orders của department mình trong giờ hành chính" |
| ReBAC | Quyền dựa trên Relationships giữa entities | Social networks, document sharing | "User có thể edit document nếu là owner hoặc được owner share" |

### RBAC Implementation Checklist

- [ ] Deny by default — phải explicit grant quyền
- [ ] Principle of least privilege — chỉ grant quyền tối thiểu cần thiết
- [ ] Kiểm tra authz ở server-side, không chỉ hide UI
- [ ] Log authorization failures (có thể là dấu hiệu tấn công)
- [ ] Review quyền định kỳ (quarterly access review)

---

## 4. Input Validation Checklist

### XSS (Cross-Site Scripting)

```
Phòng tránh:
  - [ ] Encode output theo context: HTML encode, JavaScript encode, URL encode
  - [ ] Content-Security-Policy header (chặn inline scripts)
  - [ ] HttpOnly và Secure flags cho cookies
  - [ ] Dùng framework templating có auto-escape (React, Vue, Angular)
  - [ ] Sanitize HTML input nếu cần render HTML (DOMPurify)
```

### SQL Injection

```sql
-- KHÔNG BAO GIỜ concatenate user input vào query
-- BAD:
query = "SELECT * FROM users WHERE email = '" + userInput + "'";

-- Chuẩn: dùng parameterized queries
-- GOOD (Node.js/pg):
await db.query('SELECT * FROM users WHERE email = $1', [userInput]);

-- GOOD (SQLAlchemy):
db.execute(select(User).where(User.email == user_input))
```

### CSRF (Cross-Site Request Forgery)

```
Phòng tránh:
  - [ ] CSRF token trong state-changing requests (POST, PUT, DELETE)
  - [ ] SameSite=Strict hoặc SameSite=Lax cho session cookies
  - [ ] Kiểm tra Origin/Referer header
  - [ ] Double submit cookie pattern
```

### SSRF (Server-Side Request Forgery)

```
Phòng tránh:
  - [ ] Allowlist domain/IP được phép request đến
  - [ ] Block các IP ranges nội bộ: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16
  - [ ] Không redirect đến user-supplied URLs
  - [ ] Network egress filtering ở infrastructure level
```

---

## 5. API Security Checklist

- [ ] **Authentication:** Mọi endpoint cần auth phải verify token (không tin client claims)
- [ ] **Rate Limiting:** Áp dụng cho tất cả endpoints, đặc biệt auth endpoints
  - Login: 5 requests/phút/IP
  - API: 100–1000 requests/phút tùy endpoint
- [ ] **CORS:** Chỉ allow origins cụ thể, không dùng `*` cho credentialed requests
- [ ] **Content-Type:** Validate `Content-Type: application/json`, reject nếu sai
- [ ] **Request Size:** Giới hạn body size (mặc định 1MB, điều chỉnh theo use case)
- [ ] **API Keys:** Không log API keys, mask trong error messages
- [ ] **Sensitive Endpoints:** `/admin`, `/internal` không expose ra internet
- [ ] **Versioning:** Deprecated endpoints vẫn cần security patches

```nginx
# Rate limiting với Nginx
limit_req_zone $binary_remote_addr zone=api:10m rate=100r/m;
limit_req_zone $binary_remote_addr zone=auth:10m rate=5r/m;

location /api/auth/ {
    limit_req zone=auth burst=3 nodelay;
}

location /api/ {
    limit_req zone=api burst=20 nodelay;
}
```
