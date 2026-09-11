# §20 CDG Token Persist Pattern

> Mọi quyết định CDG (Critical Decision Gate) PHẢI được persist vào `cdg-tokens.json` để bảo toàn audit trail + anti-loop tracking (CORE-027, Protocol 16).
>
> **v10.3 update:** Phase 1 KHÔNG còn chạy CDG gates trực tiếp — toàn bộ defer/auto-resolve (xem phase1-init.md Step 1.8). Step 1.12 giờ chỉ tạo file rỗng `{"$schema":"cdg-tokens-v1","tokens":[]}`. CDG decisions thực sự được append ở Phase 4 Step 4.3 (E090, E090b — just-in-time browser gates) và Phase 5 Step 5.7 (CDG-PRE-EXECUTE handoff).

## §20.1 Canonical Paths

| Phase | File | Khi nào populate |
|-------|------|------------------|
| Phase 1 | `$SESSION_DIR/phase1-init/cdg-tokens.json` | Empty stub (v10.3 — không có gate ở Phase 1) |
| Phase 4 | `$SESSION_DIR/phase4-find-bugs/cdg-tokens.json` | Step 4.3 Browser CDG (E090/E090b) — chỉ khi PW_LANE_COUNT > 0 |
| Phase 5 | `$SESSION_DIR/phase5-triage/cdg-tokens.json` | Step 5.7 CDG-PRE-EXECUTE handoff |

## §20.2 Schema (`cdg-tokens-v1`)

```json
{
  "$schema": "cdg-tokens-v1",
  "tokens": [
    {
      "gate": "E090-Browser",
      "decision": "continue",
      "timestamp": "2026-05-15T10:00:00Z",
      "phase": "phase1",
      "status": "accepted"
    }
  ]
}
```

## §20.3 Helper Function (append atomic, Phase 1)

```bash
# Append một token (atomic write — CORE-035)
_append_cdg_token() {
  local gate="$1" decision="$2" ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  local target="$SESSION_DIR/phase1-init/cdg-tokens.json"
  [ ! -s "$target" ] && echo '{"$schema":"cdg-tokens-v1","tokens":[]}' > "$target"

  jq --arg g "$gate" --arg d "$decision" --arg t "$ts" \
     '.tokens += [{gate:$g, decision:$d, timestamp:$t, phase:"phase1", status:"accepted"}]' \
     "$target" > "$target.tmp.$$" \
   && jq '.' "$target.tmp.$$" > /dev/null \
   && mv "$target.tmp.$$" "$target"
}
```

## §20.4 v10.3 Pattern — Empty Stub (Phase 1) + Just-in-Time Append (Phase 4)

**Phase 1 Step 1.12 (v10.3 stub):**

```bash
# Phase 1 chỉ tạo empty file — không còn buffer/flush logic vì toàn bộ CDG đã defer/auto-resolve
mkdir -p "$SESSION_DIR/phase1-init"
[ ! -s "$SESSION_DIR/phase1-init/cdg-tokens.json" ] && \
  echo '{"$schema":"cdg-tokens-v1","tokens":[]}' > "$SESSION_DIR/phase1-init/cdg-tokens.json"
```

**Phase 4 Step 4.3 (Browser CDG — just-in-time, chỉ khi PW_LANE_COUNT > 0):**

```bash
# Phase 4 đã có $SESSION_DIR → append trực tiếp, không cần buffer
_append_cdg_token_phase4() {
  local gate="$1" decision="$2" ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local target="$SESSION_DIR/phase4-find-bugs/cdg-tokens.json"
  mkdir -p "$(dirname "$target")"
  [ ! -s "$target" ] && echo '{"$schema":"cdg-tokens-v1","tokens":[]}' > "$target"
  jq --arg g "$gate" --arg d "$decision" --arg t "$ts" \
     '.tokens += [{gate:$g, decision:$d, timestamp:$t, phase:"phase4", status:"accepted"}]' \
     "$target" > "$target.tmp.$$" && mv "$target.tmp.$$" "$target"
}

# Khi có decision từ Step 4.3 CDG
_append_cdg_token_phase4 "E090-Browser" "$CDG_E090_DECISION"
_append_cdg_token_phase4 "E090b-BaseURLConflict" "$CDG_E090B_DECISION"
```

**v10.3 DELETED variables (không còn produce ở Phase 1):**
`$CDG_E090_DECISION`, `$CDG_E090B_DECISION`, `$CDG_E091_DECISION`, `$CDG_E092_DECISION`, `$CDG_E093_DECISION`, `$CDG_E100_DECISION`.

## §20.5 Phase 5 Pattern (existing — reference)

Phase 5 Step 5.7 đã append cdg-tokens.json đầy đủ (CDG-PRE-EXECUTE) — không cần Step trung gian. Xem `phase5-triage.md` Step 5.7 §"CDG Pre-Execute Handoff".

## §20.6 Verify

```bash
# T1: file exists + non-empty
test -s "$SESSION_DIR/phase1-init/cdg-tokens.json"
# T2: schema match
jq -e '."$schema" == "cdg-tokens-v1"' "$SESSION_DIR/phase1-init/cdg-tokens.json"
# T3: every token has required fields
jq -e '.tokens | all(has("gate") and has("decision") and has("timestamp") and has("phase"))' \
   "$SESSION_DIR/phase1-init/cdg-tokens.json"
```

## §20.7 Error Codes

| Lỗi | Code | Hành động |
|-----|------|-----------|
| Atomic write fail | E001 | Retry x1 → escalate (audit trail mất → block) |
| jq parse fail | E054 | Re-build file từ empty schema → re-append |
| Schema mismatch (manual edit) | E054 | WARN — vẫn append, ghi log |
