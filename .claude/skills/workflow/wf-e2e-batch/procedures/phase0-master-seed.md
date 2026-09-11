# Phase 0: Master Seed (Global Mutex) — G6

## Mục đích

Seed master data đúng 1 lần cho toàn batch. Tránh duplicate seed khi nhiều FEAT chạy parallel.

WHY global mutex: Nhiều FEAT trong batch có thể trigger seed cùng lúc. Seed chạy song song gây
race condition trong DB (duplicate records, constraint violations, test data không nhất quán).
Lock file pattern đơn giản và đủ vì seed command thường nhanh (<5 phút).

WHY idempotency check qua manifest hash: Nếu req-registry.json không đổi và seed < 24h trước,
data vẫn valid — tránh seed không cần thiết làm chậm batch.

---

## Global Lock + Idempotency

```bash
LOCK_FILE=".mc-data/work/_meta/master-seed.lock"
SEED_STATE=".mc-data/work/_meta/batch-master-seed-state.json"

acquire_master_seed_lock() {
  mkdir -p ".mc-data/work/_meta"

  # Kiểm tra stale lock (>10 phút — seed bình thường không quá 10 phút)
  if [ -f "$LOCK_FILE" ]; then
    # macOS: stat -f %m, Linux: stat -c %Y
    LOCK_MTIME=$(stat -f %m "$LOCK_FILE" 2>/dev/null || stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)
    LOCK_AGE=$(( $(date +%s) - LOCK_MTIME ))

    if [ "$LOCK_AGE" -gt 600 ]; then
      log_warn "Stale master-seed.lock (${LOCK_AGE}s) — auto-release"
      rm -f "$LOCK_FILE"
    else
      # Lock còn valid — wait tối đa 5 phút (30 × 10s)
      local WAITED=0
      while [ -f "$LOCK_FILE" ] && [ "$WAITED" -lt 30 ]; do
        sleep 10
        WAITED=$((WAITED + 1))
        # Refresh age check
        LOCK_MTIME=$(stat -f %m "$LOCK_FILE" 2>/dev/null || stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)
        LOCK_AGE=$(( $(date +%s) - LOCK_MTIME ))
        [ "$LOCK_AGE" -gt 600 ] && rm -f "$LOCK_FILE" && break
      done

      if [ -f "$LOCK_FILE" ]; then
        log_error "E067" "master-seed" "Master seed lock timeout sau 5 phut — seed co the da chay boi process khac"
        return 1
      fi
    fi
  fi

  # Acquire via noclobber (atomic trên hầu hết POSIX filesystems)
  # WHY noclobber: tránh race condition giữa check và write
  (set -o noclobber && echo "$$:$(date +%s):batch-$BATCH_ID" > "$LOCK_FILE") 2>/dev/null || {
    log_error "E067" "master-seed" "Cannot acquire master-seed.lock (race condition)"
    return 1
  }

  return 0
}

check_seed_already_done() {
  [ ! -f "$SEED_STATE" ] && return 1  # Chưa seed lần nào

  local SEEDED_AT
  SEEDED_AT=$(jq -r '.seeded_at // ""' "$SEED_STATE" 2>/dev/null || echo "")
  [ -z "$SEEDED_AT" ] && return 1

  # Check age < 24h
  local SEED_TS NOW_TS AGE
  SEED_TS=$(date -d "$SEEDED_AT" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$SEEDED_AT" +%s 2>/dev/null || echo 0)
  NOW_TS=$(date +%s)
  AGE=$(( NOW_TS - SEED_TS ))

  if [ "$AGE" -gt 86400 ]; then
    log_warn "master-seed state expired (${AGE}s > 24h) — re-seed"
    return 1
  fi

  # Check hash khớp với manifest hiện tại
  local STORED_HASH CURRENT_HASH
  STORED_HASH=$(jq -r '.manifest_hash // ""' "$SEED_STATE" 2>/dev/null || echo "")
  CURRENT_HASH=$(sha256sum ".mc-data/docs/_meta/req-registry.json" 2>/dev/null | cut -d' ' -f1 || echo "")

  if [ "$STORED_HASH" = "$CURRENT_HASH" ] && [ -n "$CURRENT_HASH" ]; then
    return 0  # Seed còn valid
  fi

  log_warn "master-seed manifest hash mismatch — re-seed (registry thay doi)"
  return 1
}

run_master_seed() {
  acquire_master_seed_lock || return 1

  if check_seed_already_done; then
    log "Master seed da hoan tat (<24h, same manifest) — SKIP"
    rm -f "$LOCK_FILE"
    return 0
  fi

  # Đọc seed command từ batch-config nếu có, fallback sang default
  local SEED_CMD
  SEED_CMD=$(jq -r '.master_seed_command // ""' "${BATCH_CONFIG:-batch-config.json}" 2>/dev/null || echo "")
  [ -z "$SEED_CMD" ] && SEED_CMD="npx prisma db seed"

  log "Chay master seed: $SEED_CMD"

  if eval "$SEED_CMD"; then
    local MANIFEST_HASH
    MANIFEST_HASH=$(sha256sum ".mc-data/docs/_meta/req-registry.json" 2>/dev/null | cut -d' ' -f1 || echo "")

    local ISO
    ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Atomic write seed state
    cat > "$SEED_STATE.tmp" <<JSON
{
  "seeded_at": "$ISO",
  "seed_command": "$SEED_CMD",
  "manifest_hash": "$MANIFEST_HASH",
  "batch_id": "${BATCH_ID:-unknown}"
}
JSON
    jq '.' "$SEED_STATE.tmp" > /dev/null 2>&1 || {
      rm -f "$SEED_STATE.tmp" "$LOCK_FILE"
      log_error "E068" "master-seed" "Seed state JSON invalid"
      return 1
    }
    mv "$SEED_STATE.tmp" "$SEED_STATE"

    log "Master seed hoan tat tai $ISO (hash: ${MANIFEST_HASH:0:12}...)"
  else
    log_error "E068" "master-seed" "Master seed command failed: $SEED_CMD"
    rm -f "$LOCK_FILE"
    return 1
  fi

  rm -f "$LOCK_FILE"
  return 0
}
```

---

## Error Codes (E067-E068)

| Code | Mô tả | Action |
|------|-------|--------|
| E067 | Master seed lock timeout | WARN + tiếp tục (seed có thể đã chạy bởi process khác) |
| E068 | Master seed command failed | BLOCK batch — seed cần thành công để test có data |

---

## Điểm gọi trong pipeline

Được gọi từ `phase3-execute.md` trước khi spawn sub-skills theo FEAT:

```bash
# phase3-execute.md: trước vòng lặp spawn FEAT
run_master_seed || {
  log_error "E068" "batch-phase3" "Master seed fail — abort batch"
  finalize_batch "failed"
  exit 1
}
```

---

## Ghi chú

- Lock file không dùng `flock` (không portable trên macOS/Linux) mà dùng `noclobber` pattern.
- Seed state lưu tại `_meta/` (không trong session/) vì dùng chung toàn batch.
- Nếu seed command không có (project không có Prisma seed), set `master_seed_command: ""` trong batch-config.json để skip.
