---
name: wf-e2e-credentials
description: >
  Credential Vault cho e2e testing. Lưu trữ/truy xuất test credentials an toàn
  qua OS keychain. CDG bắt buộc cho register/revoke. KHÔNG bao giờ log values.
---

Đọc `.claude/skills/workflow/wf-e2e-credentials/SKILL.md` và thực thi đầy đủ theo đúng command được truyền vào.

**Lưu ý bảo mật:** KHÔNG bao giờ in credential values ra stdout/stderr. Chỉ log key names.
CDG bắt buộc cho mọi `register` và `revoke` — kể cả trong `--auto` mode.
