# Phase 1.5: Seed Data Manifest — Auto-Seed có Guard Rails

## Mục đích
Đảm bảo DB có đủ test data TRƯỚC khi F1 test. Tự động seed với các guard rails an toàn.
Giải quyết 11 scenario SKIP "no records" từ FEEDBACK.

## Input
- `$SESSION_DIR/seed-requirements.json` (per-FEAT manifest)
- Current DB state

## Output
- `$SESSION_DIR/seed-report.json` (schema seed-report-v1)
- Trả về `F0B_PROCEED=true|false`

---

## Guard Rails (thực thi trước khi seed)

### G1: Kiểm tra môi trường

```bash
guard_env():
  # Kiểm tra NODE_ENV
  node_env=$(node -e "console.log(process.env.NODE_ENV)" 2>/dev/null || echo "unknown")
  if [ "$node_env" = "production" ]; then
    log_error "E021" "SEED BLOCKED: NODE_ENV=production — không cho phép seed"
    return 1
  fi

  # Kiểm tra DATABASE_URL không chứa "prod"
  db_url="${DATABASE_URL:-}"
  if echo "$db_url" | grep -qi "prod"; then
    log_error "E021" "SEED BLOCKED: DATABASE_URL chứa 'prod' — nghi ngờ production DB"
    return 1
  fi

  return 0
```

### G2: Kiểm tra idempotency

```bash
guard_idempotent():
  seed_script=$(jq -r '.seed_script // ""' seed-requirements.json)
  [ -z "$seed_script" ] && return 0  # no script to check

  if ! grep -qiE "upsert|onConflict|ON CONFLICT|REPLACE INTO|INSERT.*IGNORE" "$seed_script" 2>/dev/null; then
    # CDG-06: script không idempotent → ask user
    trigger_cdg "CDG-06" "Seed script $seed_script không dùng UPSERT/ON CONFLICT. Chạy có thể tạo duplicate data."
    # Nếu user từ chối → return 1
    if [ "${CDG_APPROVED:-false}" = "false" ]; then
      log_error "E022" "Seed script không idempotent — user từ chối"
      return 1
    fi
  fi
  return 0
```

### G3: Backup point

```bash
guard_backup():
  snapshot_path="$SESSION_DIR/db-snapshot-pre-seed.sql"

  # Detect DB type và backup
  if grep -q '"@prisma/client"' package.json 2>/dev/null; then
    db_url=$(node -e "const p=require('./prisma/schema.prisma').toString(); const m=p.match(/url\\s*=\\s*env\\(\"(\\w+)\"\\)/); console.log(process.env[m?m[1]:'DATABASE_URL'])" 2>/dev/null || echo "")

    if echo "$db_url" | grep -q "postgresql\|postgres"; then
      pg_dump "$db_url" --schema-only > "$snapshot_path" 2>/dev/null && echo "Backup tạo: $snapshot_path"
    elif echo "$db_url" | grep -q "sqlite\|.db"; then
      sqlite3 "$(echo $db_url | sed 's/file://')" ".dump" > "$snapshot_path" 2>/dev/null && echo "Backup tạo: $snapshot_path"
    fi
  fi
  return 0
```

---

## Thực Thi Seed

### Bước 1: Đọc seed-requirements.json

```json
// seed-requirements.json schema
{
  "$schema": "seed-requirements-v1",
  "feat_id": "FIN-006",
  "entities": [
    {
      "entity": "Invoice",
      "min_records": 5,
      "states_required": ["DRAFT", "SUBMITTED", "PAID", "OVERDUE"],
      "description": "Cần đủ 4 trạng thái cho state machine test"
    },
    {
      "entity": "Customer",
      "min_records": 3,
      "cross_module_fixture": true,
      "description": "Customer fixture cho cross-module test"
    }
  ],
  "seed_script": "prisma/seed.ts",
  "seed_command": "npx prisma db seed"
}
```

### Bước 2: Probe DB hiện trạng

```bash
probe_db_state():
  for entity in $(jq -r '.entities[].entity' seed-requirements.json); do
    table=$(echo "$entity" | sed 's/\([A-Z]\)/_\1/g' | sed 's/^_//' | tr '[:upper:]' '[:lower:]')
    count=$(npx prisma query "SELECT COUNT(*) FROM $table" 2>/dev/null | grep -o '[0-9]*' | tail -1 || echo "0")
    echo "$entity: $count records"
  done
```

### Bước 3: Guard rails check

Chạy G1, G2, G3 theo thứ tự. Fail → stop + return F0B_PROCEED=false.

### Bước 4: Chạy seed command

```bash
run_seed():
  seed_cmd=$(jq -r '.seed_command // "npx prisma db seed"' seed-requirements.json)

  echo "Đang seed: $seed_cmd"
  if $seed_cmd 2>&1 | tee "$SESSION_DIR/seed-output.log"; then
    return 0
  else
    log_error "E023" "Seed command thất bại"
    return 1
  fi
```

### Bước 5: Re-probe và verify

```bash
verify_seed():
  all_ok=true
  for entity in $(jq -c '.entities[]' seed-requirements.json); do
    entity_name=$(echo $entity | jq -r '.entity')
    min_records=$(echo $entity | jq -r '.min_records')
    table=$(echo "$entity_name" | sed 's/\([A-Z]\)/_\1/g' | sed 's/^_//' | tr '[:upper:]' '[:lower:]')
    count=$(npx prisma query "SELECT COUNT(*) FROM $table" 2>/dev/null | grep -o '[0-9]*' | tail -1 || echo "0")

    if [ "$count" -lt "$min_records" ]; then
      log_error "E024" "$entity_name có $count records, cần >= $min_records"
      all_ok=false
    fi
  done

  $all_ok && return 0 || return 1
```

### Bước 6: Ghi seed-report.json

```bash
write_seed_report():
  cat > "$SESSION_DIR/seed-report.json.tmp" <<JSON
  {
    "\$schema": "seed-report-v1",
    "session_id": "$SESSION_ID",
    "feat_id": "$FEAT_ID",
    "seeded_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "seed_command": "$SEED_CMD",
    "entities_seeded": [],
    "snapshot_path": "$snapshot_path",
    "status": "completed|failed",
    "audit_chain": ""
  }
JSON

  # Validate + atomic write
  jq '.' "$SESSION_DIR/seed-report.json.tmp" > /dev/null && mv "$SESSION_DIR/seed-report.json.tmp" "$SESSION_DIR/seed-report.json"

  # Audit chain
  hash=$(sha256sum "$SESSION_DIR/seed-report.json" | cut -d' ' -f1)
  jq --arg h "sha256:$hash" '.audit_chain = $h' "$SESSION_DIR/seed-report.json" > tmp.$$ && mv tmp.$$ "$SESSION_DIR/seed-report.json"
```

---

## Error Codes

| Code | Mô tả |
|------|-------|
| E021 | NODE_ENV=production hoặc DB URL chứa "prod" — BLOCKED |
| E022 | Seed script không idempotent — CDG-06 ask user |
| E023 | Seed command thất bại |
| E024 | Sau seed vẫn thiếu records (min_records không đạt) |
| E025 | seed-requirements.json không hợp lệ (malformed JSON) |

---

## Failure Behavior

- Fail G1 (production env) → BLOCKED: E021, không seed, F0B_PROCEED=false
- Fail G2 (not idempotent) → CDG-06 ask user → nếu từ chối: BLOCKED E022, F0B_PROCEED=false
- Fail seed command → E023, F0B_PROCEED=false
- Fail verify → E024, F0B_PROCEED=false
- F0B_PROCEED=false → orchestrator mark session="BLOCKED_SEED", không advance F1
