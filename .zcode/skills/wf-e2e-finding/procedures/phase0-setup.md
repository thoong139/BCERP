# F0a — Phase 0: SETUP

## Mục tiêu

Khởi tạo session, validate FEAT-ID, load spec, acquire lock. Không sinh output finding.

---

## 0.1 — Xử lý --status (nếu có flag)

```bash
if [ "${STATUS_FLAG:-false}" = "true" ]; then
  # Tìm session gần nhất của FEAT-ID
  SESSION_DIR=$(ls -td .mc-data/work/wf-e2e-verify/sessions/${FEAT_ID}-* 2>/dev/null | head -1)
  if [ -z "$SESSION_DIR" ]; then
    echo "Không có session nào cho $FEAT_ID"
    exit 0
  fi
  # Đọc status + hiển thị dashboard
  cat "$SESSION_DIR/status.json" | jq '{
    session_id,
    feat_id,
    current_phase,
    overall_status,
    phases,
    context_estimate_pct,
    next_action
  }'
  exit 0
fi
```

---

## 0.2 — Resolve session (--resume / --session= / new)

Gọi `resolve_session()` từ `_shared.md`:

```bash
source procedures/_shared.md
resolve_session
```

Nếu là session mới: `init_session()` tạo SESSION_DIR + status.json + log files.

---

## 0.3 — CI PRE-GATE (CORE-033)

```bash
ci_detect  # Na/Nb/Nc từ _shared.md
```

---

## 0.4 — PRE-GATE Validation (CORE-011 Forensic)

```bash
run_pregate  # T1-T4 từ _shared.md
# Load feature metadata sau khi validate
FEAT_ENTRY=$(jq -r --arg id "$FEAT_ID" '.features[] | select(.feat_id == $id or .id == $id)' .mc-data/docs/_meta/req-registry.json)
SPEC_FILE=$(echo "$FEAT_ENTRY" | jq -r '.file')
MODULE_ID=$(echo "$FEAT_ENTRY" | jq -r '.module_id // .module')
SYSTEM_ID=$(echo "$FEAT_ENTRY" | jq -r '.system_id // .system')
FEAT_NAME=$(echo "$FEAT_ENTRY" | jq -r '.name')
REQ_IDS=$(echo "$FEAT_ENTRY" | jq -r '.req_ids[]?' | tr '\n' ' ')
DEPS=$(echo "$FEAT_ENTRY" | jq -r '.dependencies[]?' | tr '\n' ' ')
```

---

## 0.5 — Load feature spec

```bash
SPEC_CONTENT=$(cat "$SPEC_FILE")
# Ghi nhớ các sections chính: Mô Tả, Luồng Người Dùng, Quy Tắc Nghiệp Vụ, Acceptance Criteria
```

---

## 0.6 — Kiểm tra CDG-NEW-02: Cross-module dependency

```bash
# CDG-NEW-02: Phát hiện module phụ thuộc chưa implement
if [ -n "$DEPS" ]; then
  for DEP in $DEPS; do
    DEP_STATUS=$(jq -r --arg d "$DEP" '.features[] | select(.feat_id == $d or .id == $d) | .impl_status // "not_started"' .mc-data/docs/_meta/req-registry.json 2>/dev/null)
    case "$DEP_STATUS" in
      "not_started"|"in_progress"|"skipped")
        echo "WARN E021: Dependency $DEP có status=$DEP_STATUS — cross-module gap sẽ được ghi vào cross-module-map.md"
        log_error "E021" "phase0" "Cross-module gap: $DEP status=$DEP_STATUS"
        ;;
    esac
  done
fi
```

---

## 0.7 — Update status

```bash
update_phase_status "p0_setup" "done"
advance_phase 1 "run P1 business analysis"
log_event "COMPLETE" "phase0" "Setup hoàn tất — session $SESSION_ID"
```

---

## Output

- `status.json` khởi tạo với `current_phase=1`
- `prompt-context.md` ghi input verbatim
- `session-log.json` + `error-ledger.json` khởi tạo
- Variables `$SPEC_CONTENT`, `$MODULE_ID`, `$SYSTEM_ID`, `$FEAT_NAME`, `$REQ_IDS`, `$DEPS` sẵn sàng cho Phase 1
