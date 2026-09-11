# Phase 1 Group D — Session Setup (Steps 1.10 → 1.13)

> **Entry condition:** Group C POST-GATE PASS (auto-resolve complete, `$SCOPE` finalized).
> **Exit condition:** Step 1.13 PASS (session indexed, lock+heartbeat active, CDG stub created).
> **Next:** [phase1-init/E-isg.md](E-isg.md) (ISG Fast-Path).
>
> **Shared protocols cần thiết:**
> - [`_shared/13-lock-heartbeat.md`](../_shared/13-lock-heartbeat.md) — Lock acquire/heartbeat pattern (Step 1.11)
> - [`_shared/20-cdg-tokens.md`](../_shared/20-cdg-tokens.md) §20.4 — CDG token stub schema (Step 1.12)

## Input contract (env vars từ Group C)

| Variable | Description |
|----------|-------------|
| `$SCOPE`, `$NAME`, `$PROFILE` | CLI flags (SCOPE possibly narrowed) |

## Output contract (env vars truyền sang Group E)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `$SESSION_ID`, `$SESSION_DIR` | 1.10 | Atomic-claimed session identity |
| Lock file + heartbeat daemon | 1.11 | `$SESSION_DIR/.lock` |
| `$HEARTBEAT_PID` | 1.11 | Daemon PID cho cleanup trap |
| CDG stub file | 1.12 | `$SESSION_DIR/phase1-init/cdg-tokens.json` |
| Session indexed | 1.13 | Entry trong `sessions.jsonl` |

---

## Step 1.10 — Generate SESSION_ID + Create Directory Structure (delegated to script)

> **v10.14.0:** 40 dòng inline bash extracted → `phase1-create-session.sh` (~80 dòng).

```bash
# Delegate SESSION_ID claim + mkdir tree → eval env-style stdout
eval "$(SCOPE="$SCOPE" NAME="$NAME" bash .claude/scripts/wf-fix-bugs/phase1-create-session.sh)"

# Verify outputs
test -n "$SESSION_ID" && test -d "$SESSION_DIR" || {
  echo "E011: SESSION_ID claim fail"; exit 11
}
echo "SESSION_ID=$SESSION_ID"
echo "SESSION_DIR=$SESSION_DIR"
```

**Outputs:** `$SESSION_ID` (format `YYYY-MM-DD-{scope}-{slug}-{NN}`), `$SESSION_DIR` (POSIX-atomic claimed).

**On Failure:**

| Lỗi | Code | Hành động |
|------|------|-----------|
| >99 sessions/ngày/scope | E011 | STOP — clean old sessions hoặc đổi --name |
| mkdir subdirectory fail | E035 | STOP — kiểm tra disk + permissions |

**Cross-ref:** CORE-035 (Session Output Organization), CORE-030 (Session Isolation).

---

## Step 1.11 — Acquire Lock + Start Heartbeat Daemon

> **Pattern canonical:** [_shared/13-lock-heartbeat.md](../_shared/13-lock-heartbeat.md).

```bash
LOCK_FILE="$SESSION_DIR/.lock"

# acquire_lock(): POSIX-atomic mkdir guard + JSON lock metadata
# auto-release stale >MCV3_LOCK_STALE_MINUTES (default 30 phút)
if ! acquire_lock "$SESSION_DIR"; then
  LOCK_OWNER=$(cat "$LOCK_FILE" 2>/dev/null || echo "unknown")
  echo "E019: Lock held by $LOCK_OWNER — STOP"
  exit 19
fi

# Start heartbeat daemon (atomic tmp→mv prevent concurrent reader partial reads)
start_heartbeat_daemon "$SESSION_DIR"
HEARTBEAT_PID=$!

# Update cleanup trap để kill heartbeat + release lock khi thoát
trap "kill $HEARTBEAT_PID 2>/dev/null; release_lock \"$SESSION_DIR\"; cleanup" EXIT INT TERM
```

**On Failure:**

| Lỗi | Code | Hành động |
|------|------|-----------|
| Lock held (active) | E019 | STOP — process khác đang chạy |
| Stale lock (≥30 phút) | E008 | Auto-release + re-acquire |
| Heartbeat fail | E019 | WARN — continue không heartbeat (risky) |

---

## Step 1.12 — Init Empty CDG Tokens File (v10.3 — stub)

> **v10.3:** Phase 1 KHÔNG còn CDG decisions trực tiếp — toàn bộ defer/auto-resolve. Step này CHỈ tạo stub để Phase 4/5 APPEND.
>
> Pattern canonical: [_shared/20-cdg-tokens.md §20.4](../_shared/20-cdg-tokens.md#204-v103-pattern--empty-stub-phase-1--just-in-time-append-phase-4).

```bash
CDG_TOKENS="$SESSION_DIR/phase1-init/cdg-tokens.json"
mkdir -p "$(dirname "$CDG_TOKENS")"

# Idempotent stub init
if [ ! -s "$CDG_TOKENS" ]; then
  echo '{"$schema":"cdg-tokens-v1","tokens":[]}' > "$CDG_TOKENS"
fi

# VERIFY: schema correct
jq -e '."$schema" == "cdg-tokens-v1"' "$CDG_TOKENS" >/dev/null || {
  echo "E001: cdg-tokens.json schema fail"; exit 1
}
```

**On Failure:** E001 atomic write fail → retry x1. Non-blocking — Phase 4/5 re-init nếu missing.

---

## Step 1.13 — Append Session Index

```bash
INDEX_FILE=".mc-data/work/wf-fix-bugs/_index/sessions.jsonl"
mkdir -p "$(dirname "$INDEX_FILE")"

jq -n \
  --arg id "$SESSION_ID" \
  --arg started "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg scope "$SCOPE" \
  --arg name "$NAME" \
  --arg profile "$PROFILE" \
  '{session_id: $id, started_at: $started, scope: $scope, name: $name, profile: $profile, status: "active"}' \
  >> "$INDEX_FILE"

# Verify entry appended
tail -1 "$INDEX_FILE" | jq -e '.session_id == "'"$SESSION_ID"'"' >/dev/null
```

**On Failure:**

| Lỗi | Code | Hành động |
|------|------|-----------|
| Không ghi được index | E035 | WARN — non-blocking (output-only) |
| JSONL corrupt | — | Rotate backup, tạo mới |

**Cross-ref:** CORE-035 (Session Index — APPEND-only JSONL).

---

## Group D POST-GATE Verify

```bash
test -n "$SESSION_ID" && \
test -d "$SESSION_DIR" && \
test -f "$SESSION_DIR/.lock" && \
test -s "$SESSION_DIR/phase1-init/cdg-tokens.json" && \
ps -p ${HEARTBEAT_PID:-0} >/dev/null 2>&1 && \
  echo "Group D PASS" || echo "Group D FAIL"
```

## Next Group

→ Group E ISG Fast-Path — đọc [`phase1-init/E-isg.md`](E-isg.md)
