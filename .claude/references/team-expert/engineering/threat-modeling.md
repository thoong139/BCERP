# Threat Modeling & Detection Engineering

> **Domain**: Engineering / Security
> **Last Updated**: 2026-03-22

---

## 10. STRIDE Threat Model

Mỗi security review bao gồm threat model theo format STRIDE:

| Threat | Component | Risk | Mitigation |
|--------|-----------|------|------------|
| Spoofing (Giả mạo danh tính) | Auth service | HIGH | MFA, token rotation |
| Tampering (Giả mạo dữ liệu) | API endpoints | HIGH | Input validation, HMAC |
| Repudiation (Chối bỏ hành động) | Transaction logs | MEDIUM | Audit trail, digital signature |
| Information Disclosure (Lộ thông tin) | Database, API responses | HIGH | Encryption, data masking |
| Denial of Service (Từ chối dịch vụ) | Public endpoints | MEDIUM | Rate limiting, WAF |
| Elevation of Privilege (Leo thang đặc quyền) | RBAC layer | CRITICAL | Least privilege, RBAC review |

---

## 12. Threat Detection & Hunting

### MITRE ATT&CK Integration

- Mỗi security finding map đến ATT&CK technique ID
- Đánh giá coverage theo tactic: Initial Access, Execution, Persistence, Lateral Movement, Exfiltration
- Xác định gaps: tactics nào chưa có detection rule

### Sigma Detection Rules

- Sử dụng Sigma format cho detection rules (title, logsource, detection, condition)
- Mỗi rule có field `falsepositives` với danh sách nguồn false alarm
- Threshold: Disable rule nếu FP rate > 15%
- Allowlist: Ghi lại lý do và ngày review cho mỗi exception

---

## 9. Incident Response Quick Reference

```
Bước 1: DETECT
  - Alert kích hoạt hoặc user report
  - Xác định severity (P0/P1/P2)

Bước 2: CONTAIN
  - Isolate affected systems (network segmentation)
  - Revoke compromised credentials ngay
  - Block malicious IPs nếu DDOS

Bước 3: INVESTIGATE
  - Thu thập logs (không modify evidence)
  - Xác định blast radius: dữ liệu nào bị ảnh hưởng?
  - Timeline attack từ logs

Bước 4: REMEDIATE
  - Patch vulnerability
  - Rotate toàn bộ credentials liên quan
  - Restore từ clean backup nếu cần

Bước 5: RECOVER
  - Verify hệ thống sạch trước khi restore service
  - Monitor chặt 24–48 giờ sau

Bước 6: POST-MORTEM
  - Blameless post-mortem trong 72 giờ
  - Root cause analysis
  - Action items với owner và deadline
  - Thông báo user/regulator nếu data breach (GDPR: 72 giờ)
```

**Contacts nhanh:**
- Security team: `#security-incidents` Slack
- On-call engineer: PagerDuty escalation policy
- Legal (nếu data breach): Notify DPO ngay
