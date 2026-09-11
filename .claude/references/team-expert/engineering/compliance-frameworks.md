# Compliance Frameworks & Security Controls

> **Domain**: Engineering / Security
> **Last Updated**: 2026-03-22

---

## 13. Compliance Mapping

| Framework | Scope | Yêu cầu chính |
|-----------|-------|----------------|
| PCI-DSS | Payment processing | Encryption, access control, logging |
| HIPAA | Healthcare data | PHI protection, audit trail, BAA |
| SOC 2 | SaaS services | Security, availability, confidentiality |
| GDPR | EU personal data | Consent, right to erasure, DPO |

---

## 6. Data Protection

### Encryption At Rest / In Transit

| Layer | Minimum Standard | Recommended |
|-------|-----------------|-------------|
| In transit | TLS 1.2 | TLS 1.3 |
| Database | AES-256 tablespace encryption | + column-level for PII |
| Backups | Encrypted before upload | Customer-managed keys |
| File storage | SSE-S3 hoặc SSE-KMS | Customer-managed KMS |

### PII Handling

| Kỹ thuật | Mô tả | Dùng khi |
|---------|-------|---------|
| Masking | Che một phần: `user@e***.com` | Logs, UI display |
| Tokenization | Thay PII bằng token không có nghĩa | Payment card data (PCI-DSS) |
| Pseudonymization | Thay identifier bằng ID giả | Analytics, testing với real data |
| Anonymization | Không thể reverse | Data export, research |

### Password Hashing

```python
# Chuẩn: dùng adaptive hashing — không dùng MD5, SHA1, SHA256 cho passwords
import argon2  # Argon2id — recommended by OWASP 2023

ph = argon2.PasswordHasher(
    time_cost=2,      # iterations
    memory_cost=65536, # 64MB
    parallelism=1
)

# Hash
hashed = ph.hash("user_password")

# Verify
try:
    ph.verify(hashed, "user_password")
    if ph.check_needs_rehash(hashed):
        hashed = ph.hash("user_password")  # Rehash với params mới
except argon2.exceptions.VerifyMismatchError:
    raise InvalidPasswordError()

# Nếu cần dùng bcrypt: cost factor >= 12
# bcrypt.hashpw(password, bcrypt.gensalt(rounds=12))
```

---

## 7. Security Headers Checklist

```nginx
# Thêm vào Nginx hoặc middleware layer
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https://api.company.com" always;
```

| Header | Mục đích |
|--------|---------|
| HSTS | Bắt buộc HTTPS, chặn downgrade attacks |
| X-Content-Type-Options | Ngăn MIME sniffing |
| X-Frame-Options | Chặn clickjacking |
| CSP | Kiểm soát nguồn gốc scripts, styles, images |
| Referrer-Policy | Giới hạn thông tin Referrer header leak |

Kiểm tra headers: [securityheaders.com](https://securityheaders.com)

---

## 8. Dependency Security

- [ ] **SCA Scanning:** Chạy `npm audit` / `pip-audit` / `trivy` trong CI pipeline
- [ ] **CVE Monitoring:** Bật Dependabot (GitHub) hoặc Renovate để tự động PR khi có bản vá
- [ ] **Lockfile integrity:** Commit `package-lock.json` / `poetry.lock` vào git
- [ ] **Pin versions:** Dùng exact versions cho production dependencies
- [ ] **Audit regularly:** Chạy security scan tối thiểu 1 lần/tuần

```bash
# Kiểm tra vulnerabilities
npm audit --audit-level=high
pip-audit --requirement requirements.txt
trivy fs --exit-code 1 --severity HIGH,CRITICAL .
```

---

## 11. CI/CD Security Pipeline — GitHub Actions

```yaml
# REQ-ID: REQ-SEC-003
name: Security Checks

on:
  pull_request:
    branches: [main, develop]

jobs:
  sast:
    name: SAST — Static Analysis
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Semgrep SAST
        uses: semgrep/semgrep-action@v1
        with:
          config: p/owasp-top-ten

  dependency-scan:
    name: Dependency Vulnerability Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Snyk
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

  secrets-scan:
    name: Secrets & Credentials Scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 14. Security Review Report Template

> Chi tiết template: Xem procedure files của security agent.
> Bao gồm: Overview, Summary (severity counts), Findings (severity + MITRE ATT&CK), Sign-off.

---

## 15. Tools Reference

> SAST: SonarQube, Semgrep, CodeQL | Dependency: npm audit, Snyk, Trivy | DAST: OWASP ZAP | Secrets: Gitleaks, TruffleHog
