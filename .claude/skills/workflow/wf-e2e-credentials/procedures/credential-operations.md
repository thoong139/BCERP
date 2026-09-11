# Credential Operations — wf-e2e-credentials

Procedures cho từng command: register, get, revoke, list, check.

**Shared dependencies:** Đọc [keychain-backend.md](keychain-backend.md) trước để detect backend.

---

## §register — Đăng ký Credential Mới

```
PRE-GATE:
  T1: --key và --feat đã cung cấp
  T2: Key name theo format: [A-Z_]+ (uppercase + underscore)
  T3: FEAT_ID tồn tại (optional — warn nếu không tìm thấy)

FLOW:
  1. detect_keychain_backend() → $BACKEND
  2. Kiểm tra credential đã tồn tại chưa:
     - get_credential($KEY, $SERVICE) → nếu tồn tại + KHÔNG có --force → E074 warn + stop
     - nếu --force → CDG riêng (xem step 3b)
  3. CDG (BẮT BUỘC — kể cả --auto mode):
     Hiển thị:
       "Bạn đang đăng ký credential mới:
        - Key: $KEY_NAME
        - FEAT: $FEAT_ID
        - Backend: $BACKEND
        - GIÁ TRỊ SẼ ĐƯỢC NHẬP RIÊNG QUA stdin (không hiển thị)
        Xác nhận? [yes/no]"
     Nếu user NO → E073, stop
     3b. Nếu --force: CDG thứ 2:
       "CẢNH BÁO: Credential '$KEY_NAME' đã tồn tại. Ghi đè? [yes/no]"
       Nếu NO → stop
  4. Prompt credential value qua stdin (masked):
     echo -n "Nhập giá trị cho $KEY_NAME: "
     read -s CRED_VALUE
     echo ""  # newline
  5. store_credential($KEY, $CRED_VALUE, $SERVICE, $BACKEND)
  6. Xóa $CRED_VALUE khỏi memory ngay sau store
  7. POST-GATE:
     - Verify: get_credential($KEY, $SERVICE) → KHÔNG NULL → PASS
     - Update credentials-manifest.json (APPEND key name + feat, KHÔNG lưu value)
  8. Log: "REGISTERED: key=$KEY_NAME feat=$FEAT_ID backend=$BACKEND" (KHÔNG log value)
```

---

## §get — Truy xuất Credential

```
PRE-GATE:
  T1: --key và --feat đã cung cấp
  T2: Backend available

FLOW:
  1. detect_keychain_backend() → $BACKEND
  2. get_credential($KEY, $SERVICE) → $CRED_VALUE
     Nếu không tìm thấy → E074
  3. Inject vào env (process isolation):
     export $KEY_NAME="$CRED_VALUE"
  4. Clear $CRED_VALUE từ bash var ngay:
     unset CRED_VALUE
  5. Log: "GET: key=$KEY_NAME feat=$FEAT_ID — injected to env" (KHÔNG log value)
  6. Return: 0 (success) hoặc 1 (E074 not found)

POST-GATE:
  T1: env var $KEY_NAME được set (non-empty)
  T2: KHÔNG xuất hiện giá trị trong stdout/stderr

SECURITY NOTE: Chỉ dùng trong scripts chạy trong isolated shell subprocess.
  Không gọi 'get' từ agent prompt — chỉ từ bash scripts.
```

---

## §revoke — Xóa Credential

```
PRE-GATE:
  T1: --key đã cung cấp
  T2: Credential tồn tại (probe trước khi xóa)

FLOW:
  1. detect_keychain_backend() → $BACKEND
  2. Kiểm tra tồn tại: get_credential($KEY, $SERVICE) → nếu NULL → E074
  3. CDG (BẮT BUỘC):
     "Bạn đang XÓA credential '$KEY_NAME'. Hành động không thể hoàn tác.
      Xác nhận? [yes/no]"
     Nếu NO → stop
  4. revoke_credential($KEY, $SERVICE, $BACKEND)
  5. POST-GATE:
     - Verify: get_credential($KEY, $SERVICE) → phải NULL → PASS
     - Update credentials-manifest.json: set status=revoked
  6. Log: "REVOKED: key=$KEY_NAME feat=$FEAT_ID"
```

---

## §list — Liệt kê Key Names

```
FLOW:
  1. Đọc credentials-manifest.json
  2. Hiển thị table: KEY_NAME | FEAT_ID | STATUS | REGISTERED_AT
     (KHÔNG hiển thị values)
  3. Nếu manifest không tồn tại → "Chưa có credentials đăng ký."
  4. Exit 0

OUTPUT FORMAT:
  Credentials đã đăng ký:
  ┌─────────────────────────┬──────────┬───────────┬─────────────────────┐
  │ Key Name                │ FEAT     │ Status    │ Registered At       │
  ├─────────────────────────┼──────────┼───────────┼─────────────────────┤
  │ TEST_ADMIN_PASSWORD     │ FIN-001  │ active    │ 2026-05-15T10:00Z   │
  │ TEST_DB_CONNECTION      │ FIN-002  │ active    │ 2026-05-15T10:05Z   │
  └─────────────────────────┴──────────┴───────────┴─────────────────────┘
```

---

## §check — Kiểm tra FEAT Credentials

```
PRE-GATE:
  T1: --feat đã cung cấp

FLOW:
  1. Đọc credentials-manifest.json → lấy danh sách keys required cho $FEAT_ID
  2. Nếu không có entry cho FEAT → "WARN: Không có credential requirements cho $FEAT_ID"
  3. Với mỗi required key:
     - get_credential probe → available | missing | expired
  4. Tổng hợp report:
     FEAT $FEAT_ID credential check:
     ✓ TEST_ADMIN_PASSWORD — available
     ✗ TEST_PAYMENT_KEY   — MISSING (chạy: /wf-e2e-credentials register --key=TEST_PAYMENT_KEY --feat=$FEAT_ID)
  5. Return: 0 nếu tất cả available, 1 nếu có missing

OUTPUT FILE (optional --json):
  {
    "feat_id": "$FEAT_ID",
    "checked_at": "...",
    "total": N,
    "available": M,
    "missing": K,
    "missing_keys": ["TEST_PAYMENT_KEY", ...]
  }
```

---

## Credentials Manifest Update (shared helper)

```python
# Được gọi sau register và revoke để update credentials-manifest.json
import json, datetime, os

MANIFEST_FILE = ".mc-data/work/wf-e2e-credentials/{project}/credentials-manifest.json"
os.makedirs(os.path.dirname(MANIFEST_FILE), exist_ok=True)

if os.path.exists(MANIFEST_FILE):
    with open(MANIFEST_FILE) as f:
        manifest = json.load(f)
else:
    manifest = {"$schema": "credentials-manifest-v1", "credentials": []}

# Register: append or update entry (NO values)
entry = {
    "key_name": KEY_NAME,
    "feat_id": FEAT_ID,
    "service": SERVICE,
    "backend": BACKEND,
    "status": "active",  # or "revoked"
    "registered_at": datetime.datetime.utcnow().isoformat() + "Z",
    "last_verified_at": datetime.datetime.utcnow().isoformat() + "Z"
}
# Upsert by key_name + feat_id
existing = next((c for c in manifest["credentials"]
                 if c["key_name"] == KEY_NAME and c["feat_id"] == FEAT_ID), None)
if existing:
    existing.update(entry)
else:
    manifest["credentials"].append(entry)

# Atomic write
tmp = MANIFEST_FILE + ".tmp"
with open(tmp, "w") as f:
    json.dump(manifest, f, indent=2)
os.replace(tmp, MANIFEST_FILE)
```
