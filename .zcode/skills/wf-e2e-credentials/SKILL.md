---
name: wf-e2e-credentials
version: 1.1.0
last_updated: 2026-09-12
phase: support
description: |
  Credential Vault cho e2e testing pipeline. Lưu trữ và truy xuất test credentials
  an toàn qua OS keychain. KHÔNG bao giờ log credential values. CDG bắt buộc cho
  mọi credential mới — kể cả trong --auto mode.

  TRIGGER khi:
  - E2E test cần credential cho FEAT đang test (login, API key, service token)
  - Gọi lệnh: /wf-e2e-credentials register|get|revoke|list|check
  - wf-e2e-test / wf-e2e-verify / wf-e2e-batch báo missing credentials (E074/E076)

  KHÔNG trigger khi:
  - Production credentials — vault chỉ dành cho TEST credentials
  - Dự án chưa có code implement (chưa cần E2E testing lane)

argument-hint: "<register|get|revoke|list|check> [--feat=FEAT_ID] [--key=KEY_NAME] [--force] [--dry-run]"
---

# wf-e2e-credentials — Credential Vault

> **Lazy-load:** SKILL.md là routing hub. Execution logic trong `procedures/`.
> **CORE-032 compliant** — SKILL.md ≤ 300 dòng.
> **Quick single-session utility** — mỗi command chạy trọn vẹn trong 1 session; vault state
> persists trong OS keychain nên KHÔNG hỗ trợ resume/checkpoint (không cần).

### Workflow Position

```
/wf-implement-feature → /wf-e2e-credentials (chuẩn bị credentials) → /wf-e2e-test → /wf-e2e-verify
                                |
                           YOU ARE HERE — E2E testing lane (standalone utility, không thuộc main pipeline)
```

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

## Prerequisites

- **Standalone utility** — không prerequisites bắt buộc về skill khác; chạy được bất kỳ lúc nào
  sau `/wf-implement-feature` khi E2E testing cần credentials.
- Project context tồn tại (`.mc-data/work/` hoặc project dir) — PRE-GATE T4.

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

## Phase 0: Command Dispatch (BẮT BUỘC — entry point)

> Phase 0 parse command + options, chạy PRE-GATE rồi lazy-load procedure tương ứng.

| Step | Action | Verify |
|------|--------|--------|
| 1 | Parse `$ARGUMENTS` → `$COMMAND`, `$FEAT`, `$KEY`, `$SERVICE`, `$BACKEND`, `$FORCE`, `$DRY_RUN` | Command ∈ {register, get, revoke, list, check}; else E070 |
| 2 | PRE-GATE T1-T4 (command hợp lệ; `--feat` khi get/check; `--key` khi register/get/revoke; project context tồn tại) | Mọi T pass; thiếu → E071 |
| 3 | Detect keychain backend (lazy-load `procedures/keychain-backend.md`) | `$BACKEND` resolved; unavailable → E072 |
| 4 | Lazy-load `procedures/credential-operations.md §$COMMAND` rồi thực thi | POST-GATE của command pass (xem dưới) |

## Phase Routing Map (lazy-loaded)

| # | Command | Procedure | Mô tả |
|---|---------|-----------|-------|
| **1** | `register` | [procedures/credential-operations.md](procedures/credential-operations.md) §register | Đăng ký mới với CDG |
| **2** | `get` | [procedures/credential-operations.md](procedures/credential-operations.md) §get | Truy xuất an toàn (env-only) |
| **3** | `revoke` | [procedures/credential-operations.md](procedures/credential-operations.md) §revoke | Xóa với CDG |
| **4** | `list` | [procedures/credential-operations.md](procedures/credential-operations.md) §list | Liệt kê key names |
| **5** | `check` | [procedures/credential-operations.md](procedures/credential-operations.md) §check | Validate FEAT credentials |
| **6** | Backend detection | [procedures/keychain-backend.md](procedures/keychain-backend.md) | Chọn OS keychain (dùng bởi mọi command) |

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

> **Next:** credentials sẵn sàng → chạy `/wf-e2e-test [FEAT-ID]` (test đơn feature) hoặc `/wf-e2e-verify` (pipeline E2E đầy đủ).

---

## Error Handling

| Code | Mô tả | Recovery |
|------|-------|----------|
| E070 | Invalid command | Xem usage |
| E071 | Missing required argument | Cung cấp --feat / --key |
| E072 | Keychain backend unavailable | Chạy `--backend=file` hoặc cài keychain tool |
| E073 | CDG rejected — credential not registered | User từ chối → credential không được lưu |
| E074 | Credential not found | Chạy `register` trước |
| E075 | Credential expired / revoked | Re-register với giá trị mới |
| E076 | FEAT not found in registry | Kiểm tra FEAT_ID |

### Fix Rules

| Error Type | Auto-Fix | Escalate khi |
|------------|----------|--------------|
| Keychain backend unavailable (E072) | Auto-fallback `--backend=file` (AES-256-CBC) khi `--backend=auto` | User cố định backend OS nhưng tool chưa cài — hướng dẫn cài đặt |
| Credential not found (E074) | Hiện prompt hướng dẫn `register` với đúng `--key` | Key name sai format `[A-Z_]+` — user tự đổi tên |
| CDG rejected (E073) | Không auto-fix — vault KHÔNG lưu gì, exit sạch | Không escalate; user tái chạy register khi đổi ý |
| FEAT not found (E076) | WARN + vẫn cho register (credential map sẵn cho FEAT) | FEAT-ID không tồn tại trong registry khi `check` — hướng dẫn kiểm tra ID |

---

## Related Skills

| Skill | Quan hệ |
|-------|---------|
| `/wf-e2e-verify` | Orchestrator của E2E pipeline — consumer chính của credentials-manifest.json |
| `/wf-e2e-test` | Test đơn feature — consume credentials qua env khi chạy test |
| `/wf-e2e-batch` | Batch E2E — consume credentials-manifest.json cho nhiều FEAT |
| `/wf-e2e-browser` | Browser E2E — nhận credentials đã inject qua env vars |

---

## Procedure Files

- [procedures/keychain-backend.md](procedures/keychain-backend.md) — Backend detection + store/get/revoke per OS
- [procedures/credential-operations.md](procedures/credential-operations.md) — Command implementations
