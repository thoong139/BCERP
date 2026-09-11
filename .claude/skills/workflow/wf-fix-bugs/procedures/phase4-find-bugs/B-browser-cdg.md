# Phase 4 Group B — Browser CDG (Step 4.3 INLINE E090/E090b)

> **Entry condition:** Group A POST-GATE PASS + `PW_LANE_COUNT > 0`. **SKIP toàn bộ group nếu `PW_LANE_COUNT == 0`.**
> **Exit condition:** `$URL` non-empty + conflict resolved, hoặc browser dims loại khỏi `$DIMS_ARRAY`.
> **Next:** [phase4-find-bugs/C-create-lanes.md](C-create-lanes.md) (Create Lane Directories).
>
> **Shared protocols cần thiết:**
> - [`_shared/20-cdg-tokens.md`](../_shared/20-cdg-tokens.md) — CDG token persist E090/E090b
> - [`_shared/18-playwright.md`](../_shared/18-playwright.md) — Playwright modes (headless/visible/mobile)
> - [`_shared/04-error-handling.md`](../_shared/04-error-handling.md) — E090, E090b

> **⚠ GIỮ INLINE — KHÔNG extract sang script:** AskUserQuestion x2 (CORE-027). User-facing decision phải INLINE — không buffer, không delegate.

## Input contract (env vars từ Group A)

| Variable | Description |
|----------|-------------|
| `$SESSION_DIR`, `$SESSION_ID` | Pipeline state |
| `$DIMS_ARRAY`, `$DIMS_COUNT`, `$PW_LANE_COUNT`, `$PW_DIMS` | Từ Group A setup-lanes.sh |
| `$URL` (optional) | `--url=` flag hoặc env `MCV3_URL` |
| `$MCV3_PW_ALLOW_SHARED_URL` (optional) | `1` để bypass E090b conflict check |

## Output contract (env vars truyền sang Group C)

| Variable | Set by Step | Mô tả |
|----------|-------------|------|
| `$DIMS_ARRAY` (refined) | 4.3 | Loại browser dims (QD5/QD7/QD9) nếu user skip |
| `$PW_LANE_COUNT` (refined) | 4.3 | Recompute sau loại dims |
| `$URL` | 4.3 | Set từ user input nếu E090 fired |
| `phase4-find-bugs/cdg-tokens.json` | 4.3 | CDG decision persist (CORE-027) |

---

## Step 4.3 — Browser CDG (E090 + E090b) — GIỮ INLINE (user interaction)

**Mục đích:** Just-in-time gate cho Playwright lanes — chỉ chạy khi `PW_LANE_COUNT > 0`. Trước v10.3 gates này nằm ở Phase 1 (premature). v10.3 moved về đây để user thấy context đầy đủ.

**Điều kiện đầu vào:** Group A POST-GATE PASS + `PW_LANE_COUNT > 0`. **SKIP toàn bộ step nếu `PW_LANE_COUNT == 0`.**

**Thực thi (INLINE):**

```
IF $PW_LANE_COUNT == 0:
  SKIP — không có lane nào cần browser
  → tiếp tục Group C (đọc C-create-lanes.md)

# ── E090: Missing URL CDG ─────────────────────────────────────
IF $URL is empty (no --url flag, no ENV MCV3_URL):
  AskUserQuestion {
    question: "Cần URL để chạy $PW_LANE_COUNT lane browser tests. Nhập URL hoặc skip browser lanes?"
    options: [
      {label: "Nhập URL", description: "Cung cấp BASE_URL"},
      {label: "Skip browser lanes", description: "Loại browser dims khỏi DIMS_ARRAY, tiếp tục static lanes"},
      {label: "Cancel session", description: "STOP — chạy lại với --no-browser hoặc --url=<url>"}
    ]
  }
  IF "Nhập URL" → set $URL → tiếp tục E090b check
  IF "Skip" → loại browser dims (QD5/QD7/QD9) khỏi $DIMS_ARRAY → recompute $PW_LANE_COUNT
              → IF $PW_LANE_COUNT == 0: SKIP rest of step → Group C
              → ELSE: tiếp tục E090b
  IF "Cancel" → STOP với code E090

# ── E090b: BASE_URL Conflict CDG (v10.2 multi-session safety) ───────
IF $URL not empty AND $MCV3_PW_ALLOW_SHARED_URL != "1":
  CONFLICT_JSON=$(bash .claude/scripts/wf-fix-baseurl-conflict-check.sh \
                  --url="$URL" --current-session="$SESSION_ID")
  HAS_CONFLICT=$(echo "$CONFLICT_JSON" | jq -r '.conflict')

  IF "$HAS_CONFLICT" == "true":
    PEERS=$(echo "$CONFLICT_JSON" | jq -r '.peer_sessions[] | "  • \(.session_id) (\(.age_minutes)p)"')
    AskUserQuestion {
      question: "Phát hiện phiên wf-fix-bugs khác đang test cùng URL ($URL):\n$PEERS\nChạy parallel có thể flaky. Tiếp tục?"
      options: [
        {label: "Tiếp tục", description: "Chấp nhận rủi ro (test data isolated)"},
        {label: "Đợi", description: "STOP — chạy lại sau khi phiên kia xong"},
        {label: "Huỷ", description: "STOP — đổi URL hoặc dùng --no-browser"}
      ]
    }
    Persist decision vào $SESSION_DIR/phase4-find-bugs/cdg-tokens.json
    IF "Đợi"|"Huỷ" → STOP với code E090b

# Bypass: env MCV3_PW_ALLOW_SHARED_URL=1 → skip E090b
```

**VERIFY:**

- IF browser lanes still present → `$URL` non-empty, conflict resolved (HAS_CONFLICT="false" hoặc user "Tiếp tục")
- IF user skipped → `$DIMS_ARRAY` không chứa browser dims (QD5/QD7/QD9), `$PW_LANE_COUNT` recomputed
- IF user cancelled → STOP, KHÔNG advance Group C

**On Failure:**

| Code | Tình huống | Hành động |
|------|-----------|-----------|
| E090 | Missing URL → user skip/cancel | Persist decision cdg-tokens.json. Cancel → halt session. |
| E090b | URL conflict → user wait/cancel | Persist decision cdg-tokens.json. Wait/Cancel → halt session. |
| E001 | `wf-fix-baseurl-conflict-check.sh` missing | Verify Protocol 22 infrastructure |

**Quy tắc:** Bước này **GIỮ INLINE** vì có user interaction qua `AskUserQuestion`. KHÔNG delegate sang script (tương tự CDG-11 Workload Gate Phase 3 v10.5 và CDG Critical Phase 5 v10.17).

**CDG Token Persist (CORE-027):**

```bash
# Sau mỗi AskUserQuestion answer, append vào cdg-tokens.json
CDG_TOKENS="$SESSION_DIR/phase4-find-bugs/cdg-tokens.json"
[ -s "$CDG_TOKENS" ] || echo '{"tokens":[]}' > "$CDG_TOKENS"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
TMP="$CDG_TOKENS.tmp.$$"
jq --arg gate "E090" --arg dec "$USER_DECISION" --arg ts "$NOW" \
   '.tokens += [{gate: $gate, decision: $dec, timestamp: $ts}]' \
   "$CDG_TOKENS" > "$TMP" && mv "$TMP" "$CDG_TOKENS"
```

**Cross-ref:** CORE-027 (CDG), [`_shared/20-cdg-tokens.md`](../_shared/20-cdg-tokens.md) (CDG Token Persist), `.claude/scripts/wf-fix-baseurl-conflict-check.sh`.

---

## Group B POST-GATE Verify

```bash
# Case 1: User cancelled → halt session (không đến đây)
# Case 2: All browser dims skipped → PW_LANE_COUNT == 0, $URL có thể empty
# Case 3: URL provided + no conflict → $URL non-empty
[ "$PW_LANE_COUNT" -eq 0 ] || [ -n "$URL" ] && echo "Group B PASS (PW=$PW_LANE_COUNT, URL=${URL:-skipped})" \
  || echo "Group B FAIL (PW lanes present nhưng URL empty)"
```

## Next Group

→ Group C Create Lane Directories — đọc [`phase4-find-bugs/C-create-lanes.md`](C-create-lanes.md)
