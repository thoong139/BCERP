# Playbook: Review Bảo mật Code

> **Type**: Agent Skill Playbook
> **Agent**: security
> **Triggered by**: Pre-merge review, pre-deployment security gate, periodic security audit
> **Output**: Security Review Report với severity ratings

---

## Khi nào dùng playbook này

- Trước khi merge code vào nhánh chính (pre-merge gate)
- Trước khi deploy lên production (pre-deployment gate)
- Khi `/wf-implement-feature` hoàn thành một module mới
- Periodic security audit theo lịch (mỗi sprint hoặc mỗi tháng)
- Khi có thay đổi lớn về authentication, authorization, hoặc data handling

---

## Procedure

### Bước 1: Xác định phạm vi review

```
INPUT: Paths do skill cung cấp qua prompt (thư mục code, PR diff, feature branch)
FALLBACK: tra .claude/references/path-registry.md → PHASE5, CODE_PATHS

Xác định:
□ Files nào thuộc scope review? (src/, app/, lib/)
□ Loại thay đổi: tính năng mới / refactor / hotfix / dependency update
□ Có thay đổi auth flow, permission, hoặc data access không?
□ Có xử lý PII (email, số điện thoại, CCCD, thông tin thanh toán) không?
□ Có endpoint mới expose ra internet không?

→ Ghi lại scope rõ ràng trong phần Overview của report
```

### Bước 2: Load knowledge phù hợp với scope

```
READ: .claude/references/team-expert/engineering/security-checklist.md

Chọn sections cần focus dựa trên scope:
□ Auth/Session thay đổi     → Section 2 (Auth Patterns), Section 3 (Authorization)
□ Có user input             → Section 4 (Input Validation)
□ Có API endpoints mới      → Section 5 (API Security)
□ Xử lý PII hoặc payments   → Section 6 (Data Protection)
□ HTTP responses, headers   → Section 7 (Security Headers)
□ Dependency updates        → Section 8 (Dependency Security)
□ Tất cả                    → Load toàn bộ
```

### Bước 3: OWASP Top 10 (2021) — Kiểm tra từng loại lỗ hổng

Đi qua từng OWASP category theo thứ tự. Dừng lại ở bất kỳ finding nào thì ghi lại ngay.

#### A01 — Broken Access Control (Kiểm soát truy cập bị lỗi)

```
Grep pattern: tìm các endpoint, function nhận user input mà không kiểm tra quyền
□ Mọi endpoint có kiểm tra authentication chưa?
□ Có kiểm tra authorization ở server-side không, hay chỉ hide UI?
□ Tìm IDOR: /api/users/{id} — có kiểm tra id thuộc về user đang login không?
□ Tìm privilege escalation: user thường có thể gọi admin API không?
□ Deny by default: nếu thiếu role check → mặc định là từ chối hay cho qua?
□ Horizontal access: user A có xem được data của user B không?

MITRE ATT&CK: T1078 (Valid Accounts), T1548 (Abuse Elevation Control)
```

#### A02 — Cryptographic Failures (Lỗi mã hóa)

```
□ PII có được mã hóa at rest không? (email, số điện thoại, địa chỉ, CCCD)
□ TLS version: tối thiểu TLS 1.2, khuyến nghị TLS 1.3
□ Password có dùng Argon2id hoặc bcrypt (cost >= 12) không?
□ Không dùng MD5, SHA1 cho password hoặc sensitive data
□ API keys, tokens có được mã hóa khi lưu vào DB không?
□ Backup files có được mã hóa trước khi upload không?

MITRE ATT&CK: T1552 (Unsecured Credentials), T1040 (Network Sniffing)
```

#### A03 — Injection (Tấn công chèn lệnh)

```
□ SQL: dùng parameterized queries hoặc ORM — không bao giờ concatenate user input
□ Command injection: os.system(), exec(), eval() với user input
□ LDAP injection: input có được escape không?
□ NoSQL injection: MongoDB $where, $regex với user input
□ Template injection: Jinja2, Handlebars với unescaped user data
□ XPath injection: XML parsing với user-controlled paths

Grep: tìm các pattern: + userInput, f"...{user...}", string.format(user...)
MITRE ATT&CK: T1190 (Exploit Public-Facing Application)
```

#### A04 — Insecure Design (Thiết kế không an toàn)

```
□ Có threat model cho tính năng này không? (xem playbook threat-model-system.md)
□ Business logic: rate limiting cho OTP, tránh brute force
□ Luồng reset password có thể bị abuse để enumerate users không?
□ File upload: kiểm tra MIME type, giới hạn size, không execute uploaded files
□ Import/Export: có giới hạn số lượng records, timeout không?

MITRE ATT&CK: T1110 (Brute Force), T1499 (Endpoint Denial of Service)
```

#### A05 — Security Misconfiguration (Cấu hình bảo mật sai)

```
□ Debug mode có bị bật trên production không? (DEBUG=True, stacktrace exposed)
□ Default credentials còn tồn tại không? (admin/admin, postgres/postgres)
□ CORS: có dùng wildcard (*) cho credentialed requests không?
□ Error messages có leak internal info không? (stack trace, DB schema, paths)
□ Unnecessary HTTP methods được enable? (PUT, DELETE trên endpoints không cần)
□ Directory listing bị bật?

MITRE ATT&CK: T1592 (Gather Victim Host Information)
```

#### A06 — Vulnerable Components (Thành phần lỗi thời)

```
□ Chạy: npm audit --audit-level=high / pip-audit / trivy fs
□ Có dependency nào có CVE mức High/Critical không?
□ Lockfile có được commit không? (package-lock.json, poetry.lock)
□ Docker base image có cũ không? (scan với trivy image)
□ Transitive dependencies: không chỉ kiểm tra direct deps

Lưu ý: report CVE ID + CVSS score + có patch chưa
MITRE ATT&CK: T1195 (Supply Chain Compromise)
```

#### A07 — Authentication & Session Failures (Lỗi xác thực và phiên)

```
□ JWT: dùng RS256/ES256, validate exp/iss/aud, không lưu trong localStorage
□ Access token TTL ngắn (≤ 15 phút), refresh token lưu HttpOnly cookie
□ Không dùng alg: "none"
□ Session: regenerate session ID sau login thành công
□ Password policy: tối thiểu 8 ký tự, có check breach databases (HaveIBeenPwned)?
□ MFA: có bắt buộc cho admin accounts không?
□ Account lockout: sau N lần fail login có lockout hoặc captcha không?

MITRE ATT&CK: T1539 (Steal Web Session Cookie), T1110 (Brute Force)
```

#### A08 — Data Integrity Failures (Lỗi toàn vẹn dữ liệu)

```
□ Deserialization: dùng safe parsers, không deserialize untrusted data trực tiếp
□ CI/CD: có verify checksum của artifacts không?
□ Auto-update mechanisms: có verify signatures không?
□ Package integrity: có dùng --ignore-scripts khi install không? (npm)
□ Webhook: có verify HMAC signature của incoming webhooks không?

MITRE ATT&CK: T1195 (Supply Chain Compromise), T1554 (Compromise Client Software Binary)
```

#### A09 — Security Logging Failures (Lỗi ghi nhật ký bảo mật)

```
□ Login events (success + failure) có được log không?
□ Authorization failures (403) có được log không?
□ Sensitive operations (password change, role change, data export) có audit trail không?
□ PII KHÔNG được log ra: không log passwords, tokens, credit card numbers, CCCD
□ Logs có centralized và tamper-evident không?
□ Log retention policy: tối thiểu 90 ngày, khuyến nghị 1 năm

MITRE ATT&CK: T1562.002 (Impair Defenses: Disable Windows Event Logging)
```

#### A10 — SSRF (Server-Side Request Forgery)

```
□ Endpoint nào nhận URL từ user và thực hiện HTTP request?
□ Có allowlist domain/IP được phép không?
□ Block private IP ranges: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16
□ Không redirect đến user-supplied URLs
□ Webhook URLs: có validate host trước khi gửi request không?
□ File import từ URL: có validate scheme (chỉ https://) không?

MITRE ATT&CK: T1090 (Proxy), T1210 (Exploitation of Remote Services)
```

### Bước 4: Kiểm tra Input Validation

```
Focus vào các điểm đầu vào:
□ API request body, query params, path params
□ File upload (tên file, MIME type, kích thước, nội dung)
□ HTTP headers (User-Agent, X-Forwarded-For, Referer)
□ Webhook payloads
□ Import files (CSV, JSON, XML)

Với mỗi điểm đầu vào:
□ Có validate type, length, format không?
□ Có sanitize trước khi lưu DB hoặc render ra HTML không?
□ Error message khi validation fail có an toàn không? (không leak schema)
```

### Bước 5: Kiểm tra Authentication / Authorization

```
□ Tìm tất cả endpoints — có endpoint nào thiếu auth middleware không?
□ Kiểm tra permission checks: role-based hay resource-based?
□ Tìm IDOR patterns: /api/orders/{orderId} — orderId có phải của user đó không?
□ Admin endpoints: có riêng biệt và được bảo vệ thêm không?
□ Service-to-service: có dùng mTLS hoặc API key riêng không?
□ Token refresh flow: có revoke old token sau khi issue new không?
```

### Bước 6: Kiểm tra xử lý Sensitive Data

```
□ Grep: tìm console.log, print, logger với các pattern: password, token, secret, key, card, ssn
□ API responses: có trả về fields không cần thiết (password hash, internal IDs) không?
□ Error responses: có leak stack trace, file paths, SQL queries không?
□ PII trong URL: tránh đặt PII trong query params (xuất hiện trong server logs)
□ Database: columns chứa PII có được mã hóa không?
□ Temp files: có cleanup sau khi xử lý xong không?
```

### Bước 7: Kiểm tra Dependency Vulnerabilities

```
Chạy các lệnh scan:

Node.js:
  npm audit --audit-level=high
  npx better-npm-audit --level high

Python:
  pip-audit --requirement requirements.txt

Container:
  trivy image [image-name]:[tag] --severity HIGH,CRITICAL

General:
  trivy fs --exit-code 1 --severity HIGH,CRITICAL .

Với mỗi CVE tìm thấy:
□ Ghi CVE ID + CVSS score
□ Có patch version không?
□ Exploitability trong context của dự án này?
```

### Bước 8: Phát hiện Secrets bị hardcode

```
Grep patterns cần tìm:
□ api_key = "[^{]"
□ password = "[^{]"
□ secret = "[^{]"
□ private_key
□ AWS_ACCESS_KEY, AWS_SECRET
□ DATABASE_URL với credentials inline
□ Bearer [token dài]
□ BEGIN RSA PRIVATE KEY

Tools:
  gitleaks detect --source . --report-format json
  truffleHog filesystem .

Kiểm tra:
□ .env files có được gitignore không?
□ Có secrets trong git history không? (gitleaks detect --log-opts="HEAD~10..HEAD")
□ Docker images có bake secrets vào layers không?
```

### Bước 9: Kiểm tra Rate Limiting và DoS Protection

```
□ Auth endpoints (/login, /register, /forgot-password): giới hạn 5 requests/phút/IP
□ OTP/verification endpoints: giới hạn 3 attempts, lockout sau fail
□ File upload: giới hạn kích thước (body size limit)
□ Expensive operations (export, report generation): có queue không?
□ GraphQL: có complexity limit, depth limit không?
□ Regex trong validation: có ReDoS risk không? (catastrophic backtracking)
```

### Bước 10: Kiểm tra Security Headers

```
Dùng curl -I hoặc review middleware configuration:
□ Strict-Transport-Security (HSTS): max-age >= 31536000
□ X-Content-Type-Options: nosniff
□ X-Frame-Options: SAMEORIGIN hoặc DENY
□ Content-Security-Policy: không dùng unsafe-inline, unsafe-eval
□ Referrer-Policy: strict-origin-when-cross-origin
□ Permissions-Policy: disable unused browser APIs
□ Không expose X-Powered-By, Server headers
```

### Bước 11: Viết Security Review Report

```
Format output (theo template tại security-checklist.md Section 14):

1. Overview: scope, date, reviewer
2. Summary table: Critical/High/Medium/Low counts
3. Findings list (mỗi finding có đầy đủ fields)
4. Sign-off checklist

Severity definitions:
- Critical: Exploit trực tiếp được, ảnh hưởng toàn bộ hệ thống hoặc nhiều users
            → Phải fix NGAY, KHÔNG deploy
- High:     Cần điều kiện cụ thể để exploit, ảnh hưởng đáng kể
            → Fix trước khi deploy
- Medium:   Khó exploit, ảnh hưởng giới hạn, hoặc defense-in-depth bị yếu
            → Fix trong sprint hiện tại
- Low:      Best practice violations, minor information disclosure
            → Fix trong sprint tiếp theo hoặc backlog

Với mỗi Finding:
□ Severity: Critical/High/Medium/Low
□ OWASP Category: A01–A10
□ MITRE ATT&CK Technique ID (bắt buộc)
□ Location: file path + line number
□ Description: mô tả rõ vấn đề
□ Impact: quantify — "attacker có thể đọc toàn bộ bảng users với N records"
□ Recommendation: giải pháp cụ thể với code example nếu có
□ Status: Open / Fixed / Accepted Risk (cần lý do nếu Accept)
```

---

## Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase3-architecture/security-review-[feature]-[date].md

Cấu trúc output:
1. Security Review Report (đầy đủ theo template)
2. Summary verdict: APPROVED / APPROVED WITH CONDITIONS / BLOCKED
   - APPROVED: không có Critical/High issues
   - APPROVED WITH CONDITIONS: có Medium issues, cam kết fix trong sprint
   - BLOCKED: có Critical hoặc High issues chưa giải quyết
3. Action items với priority và owner gợi ý
```

---

## Checklist trước khi submit

```
□ Đã cover tất cả 10 OWASP categories
□ Mỗi finding có MITRE ATT&CK technique ID
□ Không có finding nào thiếu remediation cụ thể
□ Severity được đánh giá theo exploitability thực tế, không chỉ lý thuyết
□ PII và sensitive data handling đã được kiểm tra
□ Secrets scan đã chạy
□ Dependency scan đã chạy
□ Report có verdict rõ ràng: APPROVED / BLOCKED
□ Nếu có Critical issues → đã thông báo rõ: KHÔNG DEPLOY
```
