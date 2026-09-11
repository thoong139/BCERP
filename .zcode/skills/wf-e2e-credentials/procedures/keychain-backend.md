# wf-e2e-credentials — Keychain Backend (G7: Credential Encrypt at Rest)

## Mục đích

Lưu trữ E2E test credentials được mã hóa, không bao giờ lưu plaintext trong session files.

WHY encrypt at rest: Test credentials (sysadmin, test users) thường là real passwords trong staging environment.
Lưu plaintext vào `.mc-data/` hoặc session files vi phạm OWASP A02 (Cryptographic Failures).
Keychain backend cô lập credential khỏi session data — ngay cả khi session dir bị leak, credentials vẫn an toàn.

---

## Backends theo Environment

Thứ tự ưu tiên:

| Priority | Backend | Điều kiện | Lý do chọn |
|----------|---------|-----------|-----------|
| 1 | OS Keychain (macOS/Linux) | `security` hoặc `secret-tool` available | Native, không cần thêm dependency |
| 2 | Encrypted file (AES-256) | OS keychain không available | Portable, đủ an toàn cho staging |
| 3 | Environment variables | CI environment | Standard CI practice |
| 4 | Prompt user | Không có backend nào | Fallback cuối cùng — không cache |

---

## API

```bash
# Lưu credential
store_credential(key, value, backend="auto"):
  case "$backend" in
    auto)   detect_best_backend ;;
    keychain) store_to_keychain "$key" "$value" ;;
    file)   store_to_encrypted_file "$key" "$value" ;;
    env)    export "${key^^}"="$value" ;;
  esac

# Đọc credential
get_credential(key):
  # Thử từng backend theo thứ tự ưu tiên
  val=$(get_from_keychain "$key" 2>/dev/null) && echo "$val" && return
  val=$(get_from_encrypted_file "$key" 2>/dev/null) && echo "$val" && return
  val="${!key^^:-}" && [ -n "$val" ] && echo "$val" && return
  echo ""  # Không tìm thấy
```

---

## macOS Keychain Backend

```bash
KEYCHAIN_SERVICE="wf-e2e-verify"

store_to_keychain() {
  local KEY="$1"
  local VALUE="$2"
  # Xóa entry cũ nếu có (tránh duplicate)
  security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEY" 2>/dev/null || true
  security add-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEY" -w "$VALUE" 2>/dev/null
}

get_from_keychain() {
  local KEY="$1"
  security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEY" -w 2>/dev/null
}

keychain_available() {
  command -v security >/dev/null 2>&1
}
```

---

## Linux Secret Service Backend

```bash
store_to_secret_service() {
  local KEY="$1"
  local VALUE="$2"
  echo -n "$VALUE" | secret-tool store --label="wf-e2e-$KEY" service wf-e2e-verify account "$KEY" 2>/dev/null
}

get_from_secret_service() {
  local KEY="$1"
  secret-tool lookup service wf-e2e-verify account "$KEY" 2>/dev/null
}

secret_service_available() {
  command -v secret-tool >/dev/null 2>&1
}
```

---

## Encrypted File Backend (AES-256-CBC)

WHY file backend: CI environments không có OS keychain. File encrypt với session-specific key (từ session ID + machine ID) cho đủ bảo vệ trong staging.

```bash
CRED_FILE=".mc-data/work/_meta/.e2e-credentials.enc"
CRED_KEY_FILE=".mc-data/work/_meta/.e2e-cred-key"

# Session-specific encryption key (không hardcode)
derive_cred_key() {
  local SESSION_ID="$1"
  local MACHINE_ID=$(cat /etc/machine-id 2>/dev/null || hostname | sha256sum | cut -d' ' -f1 || echo "default")
  echo -n "${SESSION_ID}:${MACHINE_ID}" | sha256sum | cut -d' ' -f1
}

store_to_encrypted_file() {
  local KEY="$1"
  local VALUE="$2"
  local ENC_KEY="${3:-$(derive_cred_key "${SESSION_ID:-default}")}"

  mkdir -p "$(dirname "$CRED_FILE")"
  chmod 700 "$(dirname "$CRED_FILE")"

  # Đọc store hiện tại (nếu có)
  local CURRENT="{}"
  if [ -f "$CRED_FILE" ]; then
    CURRENT=$(openssl enc -d -aes-256-cbc -pbkdf2 -k "$ENC_KEY" -in "$CRED_FILE" 2>/dev/null || echo "{}")
  fi

  # Update và re-encrypt
  echo "$CURRENT" | jq --arg k "$KEY" --arg v "$VALUE" '.[$k] = $v' \
    | openssl enc -e -aes-256-cbc -pbkdf2 -k "$ENC_KEY" -out "$CRED_FILE.tmp" 2>/dev/null && \
    mv "$CRED_FILE.tmp" "$CRED_FILE"
  chmod 600 "$CRED_FILE"
}

get_from_encrypted_file() {
  local KEY="$1"
  local ENC_KEY="${2:-$(derive_cred_key "${SESSION_ID:-default}")}"

  [ ! -f "$CRED_FILE" ] && return 1

  openssl enc -d -aes-256-cbc -pbkdf2 -k "$ENC_KEY" -in "$CRED_FILE" 2>/dev/null \
    | jq -r --arg k "$KEY" '.[$k] // ""'
}
```

---

## Auto-Detection

```bash
detect_best_backend() {
  if keychain_available; then
    echo "keychain_macos"
  elif secret_service_available; then
    echo "secret_service_linux"
  elif [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${GITLAB_CI:-}" ]; then
    echo "env"
  else
    echo "encrypted_file"
  fi
}
```

---

## Quy tắc bắt buộc

1. KHÔNG bao giờ ghi plaintext credential vào session files, logs, hay `.mc-data/` ngoài `CRED_FILE`.
2. KHÔNG log giá trị credential — chỉ log key name.
3. Khi session kết thúc: `cleanup_credentials()` xóa CRED_FILE nếu backend=encrypted_file.
4. CI environments: dùng GitHub Actions Secrets / GitLab CI Variables, không file.

```bash
cleanup_credentials() {
  local BACKEND="${ACTIVE_BACKEND:-encrypted_file}"
  if [ "$BACKEND" = "encrypted_file" ]; then
    rm -f "$CRED_FILE" "$CRED_KEY_FILE"
  fi
}
```
