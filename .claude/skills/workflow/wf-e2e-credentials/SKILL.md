---
id: wf-e2e-credentials
version: 1.0.0
phase: support
description: >
  Credential Vault cho e2e testing pipeline. Lưu trữ và truy xuất test credentials
  an toàn qua OS keychain. KHÔNG bao giờ log credential values. CDG bắt buộc cho
  mọi credential mới — kể cả trong --auto mode.
---

# wf-e2e-credentials — Credential Vault

> **Lazy-load:** SKILL.md là routing hub. Execution logic trong `procedures/`.
> **CORE-032 compliant** — SKILL.md ≤ 300 dòng.

---

## Mục đích

Quản lý test credentials an toàn cho `wf-e2e-verify` pipeline:
- Lưu credential vào OS keychain (macOS/Linux/Windows/fallback AES-256-CBC)
- Cấp quyền truy cập credentials cho các FEAT khi test
- Ngăn credentials bị log, inject vào prompts, hoặc ghi vào disk plain-text

---

## Arguments

```
/wf-e2e-credentials <command> [options]

Commands:
  register    Đăng ký credential mới (CDG bắt buộc)
  get         Truy xuất credential (chỉ inject vào env, KHÔNG in ra)
  revoke      Xóa credential khỏi vault
  list        Liệt kê credentials đã đăng ký (chỉ hiện key names, KHÔNG values)
  check       Kiểm tra credentials required cho một FEAT có đủ không

Options:
  --feat=FEAT_ID      FEAT cần credential
  --key=KEY_NAME      Tên credential key (e.g. TEST_ADMIN_PASSWORD)
  --service=SERVICE   Keychain service name (default: wf-e2e-{project})
  --backend=auto      Backend: auto | macos | linux | windows | file (default: auto)
  --force             Overwrite existing credential (CDG required)
  --dry-run           Mô phỏng không thực thi
```

---

## Security Rules (BẮT BUỘC)

```
RULE 1: NEVER log credential values — chỉ log key names
RULE 2: NEVER inject credential values vào agent prompts
RULE 3: CDG required cho mọi 'register' và 'revoke' — kể cả --auto mode
RULE 4: Credentials KHÔNG bao giờ ghi vào .mc-data/ plain-text
RULE 5: Session tokens expire sau 8h — auto-revoke khi session end
RULE 6: Credentials chỉ inject qua env vars (process isolation)
RULE 7: --force overwrite LUÔN cần CDG xác nhận riêng
```

---

## Phase Routing

| Command | Procedure | Mô tả |
|---------|-----------|-------|
| `register` | [procedures/credential-operations.md](procedures/credential-operations.md) §register | Đăng ký mới với CDG |
| `get` | [procedures/credential-operations.md](procedures/credential-operations.md) §get | Truy xuất an toàn |
| `revoke` | [procedures/credential-operations.md](procedures/credential-operations.md) §revoke | Xóa với CDG |
| `list` | [procedures/credential-operations.md](procedures/credential-operations.md) §list | Liệt kê key names |
| `check` | [procedures/credential-operations.md](procedures/credential-operations.md) §check | Validate FEAT credentials |
| Backend detection | [procedures/keychain-backend.md](procedures/keychain-backend.md) | Chọn OS keychain |

---

## PRE-GATE

```
T1: Command hợp lệ (register|get|revoke|list|check)
T2: --feat cung cấp khi command = get | check
T3: --key cung cấp khi command = register | get | revoke
T4: Project context tồn tại (.mc-data/work/ hoặc project dir)
```

Fail → E070 (invalid command) hoặc E071 (missing required arg).

---

## POST-GATE

```
register: T1 credential tồn tại trong keychain (verify bằng get probe) → T2 manifest updated
get:      T1 env var được set → T2 KHÔNG in ra stdout
revoke:   T1 get probe FAIL (credential đã xóa) → T2 manifest updated
check:    T1 report trả về missing_count + available_count
```

---

## Output Files

| File | Template | Mô tả |
|------|----------|-------|
| `.mc-data/work/wf-e2e-credentials/{project}/credentials-manifest.json` | [templates/credentials-manifest.template.json](templates/credentials-manifest.template.json) | Registry key names per FEAT |
| `.mc-data/work/_decisions/DECISION-{NN}.md` | Từ wf-e2e-verify | CDG record cho register/revoke |

---

## Error Codes

| Code | Mô tả | Recovery |
|------|-------|----------|
| E070 | Invalid command | Xem usage |
| E071 | Missing required argument | Cung cấp --feat / --key |
| E072 | Keychain backend unavailable | Chạy `--backend=file` hoặc cài keychain tool |
| E073 | CDG rejected — credential not registered | User từ chối → credential không được lưu |
| E074 | Credential not found | Chạy `register` trước |
| E075 | Credential expired / revoked | Re-register với giá trị mới |
| E076 | FEAT not found in registry | Kiểm tra FEAT_ID |

---

## Procedure Files

- [procedures/keychain-backend.md](procedures/keychain-backend.md) — Backend detection + store/get/revoke per OS
- [procedures/credential-operations.md](procedures/credential-operations.md) — Command implementations
