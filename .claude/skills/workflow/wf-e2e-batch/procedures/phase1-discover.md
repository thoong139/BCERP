# Phase 1: Discover FEATs

> **Load khi:** Bắt đầu Phase 1, sau khi P0 INIT pass.
> **Input:** Registry + $SCOPE/$FEATS
> **Output:** `feat-list.json`

## PRE-GATE

```
T1: Registry tồn tại — test -f "$REGISTRY_PATH"
T2: Registry valid JSON — jq '.' "$REGISTRY_PATH" > /dev/null
T3: --scope hoặc --feats được cung cấp (không được cả hai rỗng)
```

Fail T1/T2 → E001 — STOP.
Fail T3 → E002 — STOP, hướng dẫn user cung cấp --scope hoặc --feats.

## Steps

### Step 1.1 — Đọc registry và filter FEATs

```bash
discover_feats() {
  local registry="$REGISTRY_PATH"

  if [ -n "${SCOPE:-}" ]; then
    # Filter theo scope: prefix match (case-insensitive)
    local scope_upper
    scope_upper=$(echo "$SCOPE" | tr '[:lower:]' '[:upper:]')
    feats=$(jq -r --arg prefix "$scope_upper" \
      '.features[] | select(.id | ascii_upcase | startswith($prefix + "-")) |
       select(.impl_status != "not_started") | .id' "$registry")

  elif [ -n "${FEATS:-}" ]; then
    # Filter theo danh sách cụ thể
    feats=$(echo "$FEATS" | tr ',' '\n' | sed 's/^ *//;s/ *$//')
    # Validate từng FEAT-ID tồn tại trong registry
    while IFS= read -r feat_id; do
      if ! jq -e --arg id "$feat_id" '.features[] | select(.id == $id)' "$registry" > /dev/null 2>&1; then
        log_error "E050" "FEAT-ID không tìm thấy trong registry: $feat_id"
        return 1
      fi
    done <<< "$feats"
  else
    log_error "E002" "--scope hoặc --feats phải được cung cấp"
    return 1
  fi

  # Kiểm tra có FEAT nào không
  local count
  count=$(echo "$feats" | grep -c '[A-Z]' 2>/dev/null || echo 0)
  if [ "$count" -eq 0 ]; then
    log_error "E050" "Không tìm được FEAT nào từ scope='${SCOPE:-}' feats='${FEATS:-}'"
    return 1
  fi

  log "Phát hiện $count FEATs cần test"
  echo "$feats"
}
```

### Step 1.2 — Sort FEATs (stable sort theo ID)

```bash
# Sort bằng jq để stable sort
sort_feats() {
  local feats="$1"
  echo "$feats" | sort -u
}
```

### Step 1.3 — Tạo feat-list.json

```bash
# Template (inline vì minimal):
# {
#   "batch_id": "$BATCH_ID",
#   "scope": "$SCOPE",
#   "feats": ["FEAT-1", "FEAT-2"],
#   "count": N,
#   "discovery_method": "scope|explicit",
#   "created_at": "ISO-8601"
# }

create_feat_list() {
  local feats_sorted="$1"
  local method
  [ -n "${SCOPE:-}" ] && method="scope" || method="explicit"

  # Build JSON array từ list
  local feats_json
  feats_json=$(echo "$feats_sorted" | jq -R . | jq -sc '.')

  local count
  count=$(echo "$feats_sorted" | grep -c '[A-Z]')

  local content
  content=$(jq -n \
    --arg bid "$BATCH_ID" \
    --arg scope "${SCOPE:-}" \
    --argjson feats "$feats_json" \
    --argjson count "$count" \
    --arg method "$method" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      batch_id: $bid,
      scope: $scope,
      feats: $feats,
      count: $count,
      discovery_method: $method,
      created_at: $ts
    }')

  atomic_write_json "$SESSION_DIR/feat-list.json" "$content"
  log "feat-list.json tạo thành công: $count FEATs"
}
```

### Step 1.4 — Update batch-status.json

```bash
update_batch_status "P1_DISCOVER" "running"
# Cập nhật feats_total
jq --argjson count "$count" '.feats_total = $count' \
  "$SESSION_DIR/batch-status.json" > /tmp/bs.tmp && mv /tmp/bs.tmp "$SESSION_DIR/batch-status.json"
```

## Execution

```
1. Chạy PRE-GATE → fail → E001/E002 STOP
2. discover_feats → nếu fail → E050 STOP
3. sort_feats → stable sorted list
4. create_feat_list → ghi feat-list.json
5. update batch-status.json
6. append session-log.json: event=PHASE_COMPLETE phase=P1_DISCOVER count=$count
7. Log Phase 1 report (≤15 dòng tiếng Việt, CORE-028)
```

## POST-GATE

```
T1: feat-list.json tồn tại tại $SESSION_DIR/feat-list.json
T2: feat-list.json valid JSON (jq '.' pass)
T3: .count > 0
T4: .feats[] tất cả tồn tại trong registry
```

Fail → auto-fix retry x3 (re-run step 1.1-1.3) → E050 nếu vẫn fail.

## Phase 1 Report (CORE-028)

```markdown
## Phase 1: Discover FEATs — PASS

Thời gian: {ISO-8601}
**Đã làm:** Đọc registry, filter FEATs theo {scope/explicit list}.
**Kết quả:** Tìm thấy {count} FEATs → feat-list.json
**Tiếp theo:** Phase 2 Build Dependency Matrix
```

## NEXT → `procedures/phase2-dependency.md`
