---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.py"
  - "**/*.java"
  - "**/*.cs"
  - "**/*.go"
  - "**/*.rs"
---

# Security Rules

> Nếu phát hiện vi phạm bảo mật → DỪNG, báo cáo ngay.

## 1. Authentication & Authorization

- Auth middleware trên MỌI endpoint (trừ `/health`, `/auth/login`, `/auth/register`)
- Authorization check role TRƯỚC khi trả data/action
- User chỉ access data của mình (trừ ADMIN hoặc có permission)
- `/internal/` chỉ accept service-to-service token

## 2. Input Validation

- Validate TẤT CẢ inputs tại controller
- Parameterized queries — KHÔNG string concatenation (SQL injection)
- Sanitize HTML output (XSS)
- File upload: validate MIME type + size + scan content
- Re-validate client data ở server

**Validation scope theo loại endpoint:**

| Loại endpoint | Mức validation | Lý do |
|--------------|----------------|-------|
| **Public/External** (internet-facing, user input) | Đầy đủ theo OWASP: format, range, business rules, sanitize | Đây là system boundary — mọi input đều untrusted |
| **Internal** (service-to-service trong cùng cluster) | Chỉ validate struct/type (kiểu dữ liệu đúng, required fields) | Internal call không phải boundary — caller đã validate; over-validation làm chậm |
| **Admin/Internal tool** (behind auth, trusted user) | Validate format + business rules nhưng không cần sanitize HTML | Trusted user nhưng vẫn cần business rule enforcement |

> **Nguyên tắc "only validate at system boundaries":** Internal endpoints (`/internal/` prefix) được gọi từ trong cùng service hoặc trusted service — không cần full OWASP validation. Chỉ validate khi data vượt qua trust boundary (public API, file upload, webhook từ bên ngoài).

## 3. Secrets Management

- KHÔNG hardcode credentials/API keys/tokens trong code
- Secrets trong ENV variables, `.env` trong `.gitignore`
- `.env.example` chỉ có placeholders

## 4. Data Protection

- KHÔNG log: password, JWT, credit card, PII
- Password: bcrypt rounds ≥12. KHÔNG dùng md5/sha1
- JWT access token ≤1 giờ, refresh token ≤7 ngày
- KHÔNG expose stack trace cho client
- `jwt.verify()` với algorithm + issuer, KHÔNG dùng `jwt.decode()` thay verify

## 5. Sensitive Data Matrix

| Data | Lưu DB | Log | API Response |
|------|--------|-----|--------------|
| Password | Bcrypt only | ❌ | ❌ |
| JWT Token | ❌ | ❌ | Login only |
| API Key | Encrypted | ❌ | Tạo 1 lần |
| SĐT | Plain | Mask | Mask `090***567` |
| Email | Plain | ✅ | ✅ |
| Credit Card | ❌ | ❌ | ❌ |
| CMND/CCCD | Encrypted | ❌ | Mask 4 số cuối |

## 6. Rate Limiting & Headers

- Rate limit: Auth 5/phút, Public 100/phút
- Request body size limit
- CORS whitelist only
- Security headers: HSTS, X-Frame-Options, X-Content-Type-Options

## 7. Incident Protocol

| Mức | Loại lỗi | Hành động |
|-----|---------|-----------|
| CRITICAL | SQL injection, Auth bypass, Secret exposed | DỪNG, fix ngay, rotate secrets |
| HIGH | Missing auth, XSS, Sensitive in logs | Fix cùng PR |
| MEDIUM | Missing rate limit, Weak validation | Sprint này |
| LOW | Missing header | Backlog |
