# Phase 0: SETUP — Chi tiết procedure

## 0.1 — Xử lý --status

Nếu `--status` flag có mặt:
```bash
# Tìm session gần nhất
ls -t .mc-data/work/wf-e2e-verify/sessions/ | head -5
# Đọc status.json
cat .mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-*/status.json | jq .
```
In dashboard: SESSION_ID, current_phase, sub_state, từng phase status, bo_sung_count.
Dừng sau khi in.

## 0.2 — Validate FEAT-ID

```bash
RESULT=$(cat .mc-data/docs/_meta/req-registry.json | jq -r --arg id "$FEAT_ID" '.features[] | select(.id == $id) | .id')
if [ -z "$RESULT" ]; then echo "E001: FEAT-ID $FEAT_ID không tồn tại trong registry"; fi
```

## 0.3 — Load feature metadata

```bash
cat .mc-data/docs/_meta/req-registry.json | jq --arg id "$FEAT_ID" '.features[] | select(.id == $id)'
```

Extract fields: `file`, `module_id`, `system_id`, `req_ids[]`, `dependencies[]`, `name`.

## 0.4 — Load feature spec

```bash
cat "{file từ step 0.3}"
```

Nếu file không tồn tại → E002. Ghi nhớ: path, FEAT-ID, module, system, req_ids.

## 0.5 — Resume check

Nếu `--resume` flag:
```bash
# Tìm session mới nhất của FEAT-ID
ls -td .mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-* 2>/dev/null | head -1
```
Nếu `--session=<id>`: dùng session đó trực tiếp.
Load `status.json` → `current_phase` → jump tới phase tương ứng trong SKILL.md.

## 0.5b — PRE-GATE CONSUME F0a (NEW — CORE-036)

Kiểm tra F0a wf-e2e-finding đã chạy và output hợp lệ trước khi bắt đầu live-test.

```bash
FINDINGS_DIR="$SESSION_DIR/findings"

# T1: findings/ tồn tại
F0A_READY=true
if [ ! -d "$FINDINGS_DIR" ]; then
  F0A_READY=false
fi

# T2: 8 finding files tồn tại + size > 500 bytes mỗi file
REQUIRED_FINDINGS="business-understanding.md business-rule-catalog.md state-machine.md cross-module-map.md db-mapping.md db-seed-data.md api-mapping.md ui-mapping.md"
if [ "$F0A_READY" = "true" ]; then
  for F in $REQUIRED_FINDINGS; do
    if [ ! -f "$FINDINGS_DIR/$F" ]; then
      F0A_READY=false
      break
    fi
    SIZE=$(wc -c < "$FINDINGS_DIR/$F")
    if [ "$SIZE" -le 500 ]; then
      F0A_READY=false
      break
    fi
  done
fi

# T3: finding-summary.md có status = "completed"
if [ "$F0A_READY" = "true" ]; then
  if [ ! -f "$FINDINGS_DIR/finding-summary.md" ]; then
    F0A_READY=false
  fi
fi

# T4: 4 SSOT JSONs tồn tại
if [ "$F0A_READY" = "true" ]; then
  for J in issues.json block-test.json implement-required.json manual.json; do
    if [ ! -f "$SESSION_DIR/$J" ]; then
      F0A_READY=false
      break
    fi
  done
fi

# T5: cross-module-map.md valid (modules tồn tại trong registry — lỏng lẻo, chỉ check file non-empty)
if [ "$F0A_READY" = "true" ]; then
  CM_SIZE=$(wc -c < "$FINDINGS_DIR/cross-module-map.md")
  [ "$CM_SIZE" -le 100 ] && F0A_READY=false
fi

if [ "$F0A_READY" = "false" ]; then
  # G5 SHIM: Backward compat — auto-spawn F0a nếu findings/ chưa tồn tại
  echo "WARN: F0a wf-e2e-finding chưa chạy hoặc incomplete."
  echo "Sẽ auto-spawn F0a trước khi bắt đầu live-test."
  
  # Ghi vào session log
  log_event "SPAWN_F0A" "phase0" "legacy_fallback_spawned_f0a — G5 shim activated"
  
  # Spawn wf-e2e-finding với cùng session
  # Agent --skill=wf-e2e-finding --args="$FEAT_ID --session=$SESSION_ID"
  # (Orchestrator hoặc standalone mode spawn sub-agent wf-e2e-finding)
  echo "Đang chạy /wf-e2e-finding $FEAT_ID --session=$SESSION_ID ..."
  
  # Sau khi F0a hoàn tất — re-verify
  for F in $REQUIRED_FINDINGS; do
    if [ ! -f "$FINDINGS_DIR/$F" ]; then
      echo "ERROR E001: F0a spawn xong nhưng $F vẫn thiếu. Abort."
      exit 1
    fi
  done
  
  echo "F0a completed (G5 shim). Tiếp tục F1 live-test..."
fi

echo "PRE-GATE CONSUME F0a: PASS — 8 findings verified"
```

## 0.6 — Tạo session mới

```bash
SESSION_ID="{FEAT-ID}-$(date +%Y%m%d-%H%M)"
SESSION_DIR=".mc-data/work/wf-e2e-verify/sessions/$SESSION_ID"
mkdir -p "$SESSION_DIR/findings" "$SESSION_DIR/outputs"
```

Ghi `status.json` từ template. Ghi `prompt-context.md` (user input verbatim).

## 0.7 — CORE-026 trace

```bash
# Append to session log (output-only, không read)
echo "{\"event\":\"START\",\"skill\":\"wf-e2e-verify\",\"session\":\"$SESSION_ID\",\"feat_id\":\"$FEAT_ID\",\"ts\":\"$(date -Iseconds)\"}" \
  >> .mc-data/work/_trace/session-log.json
```

## 0.8 — Start heartbeat daemon cho cross-session R/W locks (v1.2.0)

Skill này có thể chạy song song với session khác (vd: 2 feature test cùng lúc). Để tránh sập BE/FE/DB của session khác, BẮT BUỘC start heartbeat daemon ngay từ Phase 0:

```bash
# Spawned khi orchestrator gọi F1 standalone (không qua wf-e2e-verify)
# Nếu được spawn qua orchestrator, orchestrator đã start daemon → SKIP step này
if [ ! -f "$SESSION_DIR/_locks/global-lock-daemon.pid" ]; then
  mkdir -p "$SESSION_DIR/_locks"
  bash .claude/scripts/wf-e2e-shared/lock-daemon.sh start "$SESSION_ID" "$SESSION_DIR"
fi
```

Daemon sẽ:
- Heartbeat mọi resource lock của session mỗi 30s
- Cleanup stale locks (>2 phút không heartbeat)
- Tự exit + release_all_session_locks khi `$SESSION_DIR/.lock` biến mất hoặc parent PID chết

Khi Phase 6 OUTPUT hoàn tất (hoặc khi `--status` STOP), gọi `lock-daemon.sh stop "$SESSION_DIR"` để release sạch.
