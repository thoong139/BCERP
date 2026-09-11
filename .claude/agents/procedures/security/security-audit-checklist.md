# Playbook: Security Audit Checklist Pre-deployment

> **Type**: Agent Skill Playbook
> **Agent**: security
> **Triggered by**: Pre-deployment security audit, compliance review, periodic security assessment
> **Output**: Security Audit Checklist Report

---

## Khi nào dùng playbook này

- Trước khi go-live hoặc release major version
- Khi `/wf-prepare-deployment` yêu cầu security sign-off
- Periodic security audit (hàng quý hoặc theo yêu cầu compliance)
- Sau khi có security incident để verify remediation đầy đủ
- Khi cần compliance review (PCI-DSS, HIPAA, SOC 2, GDPR)

---

## Procedure

### Bước 1: Xác định scope audit

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE6, PHASE3, CODE_PATHS

Thu thập thông tin:
□ Deployment target: production / staging / cloud region?
□ Tech stack: application layer, database, infrastructure
□ Compliance requirements: PCI-DSS / HIPAA / SOC 2 / GDPR / none?
□ Có thay đổi gì kể từ lần audit trước không?
□ Các open issues từ lần audit trước đã được close chưa?

READ: .claude/references/team-expert/engineering/security-checklist.md
  → Section 13: Compliance Mapping (dựa trên compliance requirements)
  → Section 14: Security Review Report Template
  → Section 15: Tools Reference
```

### Bước 2: Infrastructure Security

#### 2a. Network Segmentation

```
□ Có network segmentation giữa: internet / DMZ / app tier / data tier không?
□ Database server KHÔNG expose trực tiếp ra internet
□ Admin interfaces (/admin, SSH, RDP) KHÔNG expose ra internet
□ Internal services (cache, queue) chỉ accessible từ app tier
□ Firewall rules: deny by default, chỉ open ports cần thiết
□ VPC/subnet isolation: production tách biệt với staging/dev

Ports cần kiểm tra (không được expose ra internet):
- 22 (SSH) → dùng VPN + bastion host
- 3306, 5432, 27017 (DB ports) → private subnet only
- 6379 (Redis) → private subnet only
- 9200 (Elasticsearch) → private subnet only
- 2375, 2376 (Docker API) → không expose
```

#### 2b. TLS / Encryption in Transit

```
□ TLS version: tối thiểu TLS 1.2, khuyến nghị TLS 1.3
□ Không support SSLv3, TLS 1.0, TLS 1.1 (deprecated)
□ Certificate còn hạn: tối thiểu 30 ngày còn lại
□ Certificate chain hợp lệ (không self-signed trên production)
□ HSTS header được set với max-age >= 31536000
□ HTTP → HTTPS redirect cho tất cả endpoints
□ Internal service-to-service: có mTLS không? (microservices)

Kiểm tra:
  openssl s_client -connect [host]:443 -tls1_2
  hoặc dùng: ssllabs.com scan (grade A minimum)
```

#### 2c. Exposed Ports và Services

```
□ Port scan external-facing IP: chỉ 80 và 443 được mở (+ 22 nếu có VPN)
□ Admin panels (Kibana, Grafana, phpMyAdmin) KHÔNG expose public
□ Health check endpoints (/health, /metrics) có xác thực không?
□ Debug endpoints (/debug, /__debug__, /swagger trên production) đã bị disable?
□ Không có service nào listen trên 0.0.0.0 trừ khi cần thiết

Tools:
  nmap -sV --open [host] (chạy từ external IP)
```

### Bước 3: Application Security

#### 3a. WAF (Web Application Firewall)

```
□ Có WAF được deploy không? (AWS WAF, Cloudflare, ModSecurity)
□ WAF rules có cover OWASP Top 10 không?
□ WAF trong mode: Detection (log only) hay Prevention (block)?
  → Production PHẢI ở Prevention mode
□ WAF có được tune để giảm false positives không?
□ WAF bypass test: có test WAF effectiveness không?
```

#### 3b. Content Security Policy (CSP)

```
□ CSP header được set và đúng không?
□ Không dùng 'unsafe-inline' cho scripts (trừ khi có hash/nonce)
□ Không dùng 'unsafe-eval'
□ Không dùng wildcard (*) cho script-src
□ report-uri hoặc report-to được set để monitor violations
□ CSP được test: dùng CSP Evaluator (csp-evaluator.withgoogle.com)

Mức tối thiểu:
Content-Security-Policy: default-src 'self';
  script-src 'self';
  style-src 'self' 'unsafe-inline';
  img-src 'self' data: https:;
  connect-src 'self';
  frame-ancestors 'none';
```

#### 3c. Cookie Security

```
□ Session cookies có Secure flag (chỉ gửi qua HTTPS)?
□ Session cookies có HttpOnly flag (không accessible qua JavaScript)?
□ SameSite=Strict hoặc SameSite=Lax (chống CSRF)?
□ Session ID đủ entropy (≥ 128 bits)?
□ Session expire sau inactivity (idle timeout)?
□ Absolute session timeout (tối đa 24h cho normal users)?

Kiểm tra:
  Dùng browser DevTools → Application → Cookies → check flags
```

#### 3d. Authentication Security

```
□ Password policy: tối thiểu 8 ký tự, recommend 12+
□ Password hashing: Argon2id hoặc bcrypt (cost ≥ 12) — không MD5/SHA1/SHA256
□ Account lockout: sau 5-10 lần fail login
□ MFA: có enable không? Bắt buộc cho admin accounts?
□ Password reset: token có expiry (≤ 1 giờ)? Single-use?
□ Forgot password: không enumerate users (same response nếu email tồn tại hay không)
□ Brute force protection: rate limiting + captcha cho auth endpoints
□ Session invalidation: logout có revoke server-side session không?
```

#### 3e. Authorization Security

```
□ Deny by default: endpoint không có explicit auth check → return 401/403
□ Server-side authorization: không tin role/permission từ client
□ IDOR prevention: resource ID có được verify ownership không?
□ Admin endpoints: có separate auth layer không?
□ Horizontal access control: user A không xem được data của user B
□ Privilege escalation test: user thường không thể gọi admin functions
□ Service accounts: có least privilege không?
```

### Bước 4: Data Security

#### 4a. Encryption Standards

```
□ Encryption at rest: database có enable full encryption không?
  - PostgreSQL: pgcrypto hoặc tablespace encryption
  - MySQL: InnoDB tablespace encryption
  - MongoDB: Encrypted Storage Engine
□ PII columns: có column-level encryption cho sensitive fields không?
  (email, phone, CCCD, địa chỉ đầy đủ, financial data)
□ File storage: S3/GCS objects có được encrypt không? (SSE-S3 minimum, SSE-KMS preferred)
□ Backup encryption: backups có được encrypt trước khi upload không?
□ Key management: encryption keys được lưu ở đâu? (secrets manager, không cùng server với data)
```

#### 4b. Key Rotation Policy

```
□ Có documented rotation schedule không?
□ Database credentials: rotate mỗi 90 ngày hoặc khi có personnel change
□ API keys external services: rotate mỗi 90–180 ngày
□ TLS certificates: auto-renewal được setup (Let's Encrypt, AWS ACM)
□ JWT signing keys: có procedure rotate khi cần không?
□ Secrets manager: có enable automatic rotation không? (AWS Secrets Manager, Vault)
```

#### 4c. Backup Encryption

```
□ Database backups có được encrypt không?
□ Backup files có test restore procedure không? (backup test định kỳ)
□ Backup storage có access control riêng không?
□ Offsite backup: có encrypted copy ở location khác không?
□ Retention policy: backup được giữ bao lâu? Có xóa đúng lịch không?
□ Point-in-time recovery (PITR): có enable không?
```

### Bước 5: Identity & Access Management

#### 5a. Multi-Factor Authentication (MFA)

```
□ MFA bắt buộc cho:
  - Tất cả admin/privileged accounts ✅
  - Developer access vào production ✅
  - Cloud console (AWS/GCP/Azure) ✅
  - VPN access ✅
□ MFA optional nhưng recommended cho: end users
□ Backup codes: có recovery option không?
□ MFA bypass: có emergency bypass procedure không? (documented + controlled)
```

#### 5b. Privileged Access Management

```
□ Production database: ai có access? (list cụ thể)
  → Tối thiểu: chỉ DBAs + automated backup service
□ Production server SSH: ai có access?
  → Tối thiểu: DevOps team + emergency access policy
□ Cloud console: chỉ những người cần
□ Just-In-Time access: có dùng không? (Vault, AWS IAM temporary credentials)
□ Privileged sessions: có được recorded không? (session recording)
□ Quarterly access review: có process review và revoke unused access không?
```

#### 5c. Service Accounts

```
□ Mỗi service có dedicated service account riêng (không share)?
□ Service accounts có least privilege? (chỉ quyền service đó cần)
□ Service account credentials không hardcoded trong code
□ Service accounts không có console/SSH access
□ Automated rotation cho service account credentials
□ Unused service accounts đã bị disabled/deleted?
```

### Bước 6: Secrets Management

#### 6a. Không có Hardcoded Secrets

```
Chạy secret detection:
  gitleaks detect --source . --report-format json --report-path gitleaks-report.json
  truffleHog filesystem .

□ Không có secrets trong code files
□ Không có secrets trong git history (check last 100 commits)
□ Không có secrets trong Docker layers (inspect image)
□ Không có secrets trong CI/CD logs (check build logs)
□ .env files có trong .gitignore không?
□ Không có secrets trong documentation, comments
```

#### 6b. Rotation Policy

```
□ Có documented rotation schedule cho mỗi loại secret?
□ Emergency rotation procedure: nếu secret bị compromise → rotate trong bao lâu?
□ Rotation automation: có automated rotation không?
□ Notification: khi secret sắp expire → có alert không?

Schedule khuyến nghị:
- Database passwords: 90 ngày
- API keys (external): 90–180 ngày
- JWT signing keys: 1 năm (hoặc theo policy)
- TLS certificates: tự động, alert khi còn < 30 ngày
- Root/Master keys: 1–2 năm (highly controlled)
```

#### 6c. Secrets Storage

```
□ Tất cả secrets được lưu trong secrets manager:
  - AWS: Secrets Manager hoặc Parameter Store (SecureString)
  - GCP: Secret Manager
  - Azure: Key Vault
  - Self-hosted: HashiCorp Vault
□ Không dùng plaintext environment variables cho production secrets
  (dùng secrets manager inject vào runtime)
□ Access to secrets manager được audit logged
□ Secrets có tags phân loại (environment, team, expiry)?
```

### Bước 7: Logging & Monitoring

#### 7a. Security Events Logging

```
□ Authentication events:
  - Login success (user ID, IP, user agent, timestamp)
  - Login failure (IP, user agent, timestamp, reason)
  - Password change, reset
  - MFA enable/disable
□ Authorization events:
  - Access denied (403) với context
  - Privilege escalation attempts
□ Sensitive operations:
  - Data export (who, when, how many records)
  - User role changes
  - Config changes
  - Admin actions
□ System events:
  - Service start/stop
  - Config file changes
  - Certificate changes

Verify: PII KHÔNG được log (password, token, credit card, CCCD)
```

#### 7b. Anomaly Detection

```
□ Có rule phát hiện:
  - Nhiều login failures từ cùng IP (brute force indicator)
  - Login từ new geolocation (account takeover indicator)
  - Unusual data access patterns (data exfiltration indicator)
  - High error rate (attack indicator)
  - Spike in traffic từ single IP (DoS indicator)
□ Alerts có được route đến đúng team không? (#security-incidents Slack, PagerDuty)
□ SIEM: logs có được centralized không?
□ Retention: logs được lưu tối thiểu 90 ngày, khuyến nghị 1 năm
□ Log integrity: logs không thể bị xóa bởi application users
```

#### 7c. Incident Response Readiness

```
□ Incident Response Plan có documented không?
□ Security contacts đã update: security team, on-call, legal/DPO
□ Run playbook test: simulate incident response drill
□ Escalation matrix: P0 (critical) → ai được notify trong 15 phút?
□ Communication template: có template notify users nếu data breach không?
□ GDPR: nếu có data breach → notify DPO + regulator trong 72 giờ (có procedure không?)
□ Backup/restore đã test: biết cách restore từ backup khi cần
```

### Bước 8: Compliance Checks (OWASP ASVS Level 2)

```
Kiểm tra theo ASVS categories — đánh dấu PASS/FAIL cho mỗi control:
V1 Architecture: threat model, auth design, key management
V2 Authentication: adaptive hash, anti-automation, safe credential recovery
V3 Session: entropy ≥128 bits, timeout, CSRF protection
V4 Access Control: deny by default, server-side, least privilege
V5 Validation: whitelist input, sanitize, context-aware output encoding
V7 Logging: no PII in logs, auth events logged, generic errors to users
V8 Data: classified, no client cache, PII encrypted at rest
V9 Communication: TLS 1.2+, valid certificates
V12 Files: size limits, no path traversal
```

### Bước 9: Tổng hợp Audit Report

```
Cấu trúc: Executive Summary (date, scope, posture: PASS/CONDITIONAL/FAIL) →
Findings per Category (✅/❌/⚠️) → Issues List (ID, severity, description, action, owner, deadline) →
Compliance Status (ASVS score) → Sign-off (APPROVED/CONDITIONAL/BLOCKED) → Action Plan (table)
```

---

## Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase6-deployment/security-audit-[date].md

Nếu verdict là BLOCKED:
→ Thông báo rõ ràng: KHÔNG DEPLOY
→ List cụ thể Critical/High issues cần resolve
→ Đề xuất timeline fix

Nếu có findings liên quan đến infrastructure:
→ Notify devops agent

Nếu có findings liên quan đến code:
→ Notify developer agent với specific fix recommendations
```

---

## Checklist trước khi submit

```
□ Đã cover đủ 8 domains: Infrastructure / Application / Data / IAM / Secrets / Logging / Incident Response / Compliance
□ Mỗi FAIL item có severity rating rõ ràng
□ Mỗi issue có recommended action cụ thể
□ Compliance mapping đã được check (nếu applicable)
□ Sign-off verdict rõ ràng: APPROVED / CONDITIONAL / BLOCKED
□ Action plan có owner và deadline
□ Critical issues đã được escalate ngay (không chờ report)
```
