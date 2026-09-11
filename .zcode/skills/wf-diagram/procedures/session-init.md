# /wf-diagram — Session Initialization

> Quy trình khởi tạo session mới. Gọi bởi `phase0-setup.md` (steps 0.4-0.8 — fresh run).
> Có thể tái dùng bởi reset/restart logic trong tương lai.
> Xem `_shared.md` cho state vars, helpers, error matrix.
> **Input:** $module, $source_path, $output_path, $scope đã được parse và validate.

---

## Load Condition

Gọi từ `phase0-setup.md` sau Step 0.3 (args validated). Chỉ cho fresh run.
KHÔNG gọi khi `--resume` (đã có session data — xem `resume-routing.md`).

---

## Step SI-1: Generate SESSION_ID (Protocol 18.2)

```bash
scope_label=$(slugify "${module:-system}")
# Nếu scope=system-only mà module rỗng → scope_label="system"
[ "$scope" = "system-only" ] && [ -z "$module" ] && scope_label="system"

SESSION_ID="$(date +%Y-%m-%d)-$scope_label"
SESSION_DIR=".mc-data/work/wf-diagram/sessions/$SESSION_ID"

# Suffix tránh collision (-2, -3, ...)
SUFFIX=2
while test -d "$SESSION_DIR"; do
  SESSION_ID="$(date +%Y-%m-%d)-$scope_label-$SUFFIX"
  SESSION_DIR=".mc-data/work/wf-diagram/sessions/$SESSION_ID"
  SUFFIX=$((SUFFIX + 1))
done

# Ví dụ: 2026-05-03-order, 2026-05-03-order-2, 2026-05-03-system
```

---

## Step SI-2: Create Directories

```bash
mkdir -p "$SESSION_DIR"
mkdir -p "$output_path"
mkdir -p ".mc-data/work/_trace"   # Protocol 15 trace dir
```

---

## Step SI-3: Init diagram-status.json (CORE-031: READ → POPULATE → WRITE)

```
1. Read template: .claude/skills/workflow/wf-diagram/templates/diagram-status.json
2. Populate:
   .session_id  ← $SESSION_ID
   .module      ← $module
   .source_path ← $source_path
   .output_path ← $output_path
   .scope       ← $scope
   .status      ← "in_progress"
   .started_at  ← $(date -u +%Y-%m-%dT%H:%M:%SZ)
3. Write → $SESSION_DIR/diagram-status.json
4. Verify:
   test -s "$SESSION_DIR/diagram-status.json"
   jq -e '.session_id | length > 0' "$SESSION_DIR/diagram-status.json"
```

---

## Step SI-4: Init checkpoint.json (CORE-031: READ → POPULATE → WRITE)

```
1. Read template: .claude/skills/workflow/wf-diagram/templates/checkpoint.json
2. Populate:
   .checkpoint_id          ← "$SESSION_ID-cp-0"
   .session_id             ← $SESSION_ID
   .skill_version          ← "2.0.0"
   .module                 ← $module
   .scope                  ← $scope
   .created_at             ← $(date -u +%Y-%m-%dT%H:%M:%SZ)
   .updated_at             ← (same)
   .args_snapshot.module       ← $module
   .args_snapshot.source_path  ← $source_path
   .args_snapshot.output_path  ← $output_path
   .args_snapshot.scope        ← $scope
   .next_action.phase      ← "phase_1"   # Phase 0 khởi tạo xong → next: Phase 1
3. Write → $SESSION_DIR/checkpoint.json
4. Verify: test -s "$SESSION_DIR/checkpoint.json"
```

---

## Step SI-5: Append Trace START (Protocol 15)

```bash
trace_file=".mc-data/work/_trace/session-log.json"

# Init trace file nếu chưa tồn tại
[ -f "$trace_file" ] || echo '{"entries":[]}' > "$trace_file"

# Atomic append (mktemp + mv)
tmp=$(mktemp)
jq --arg sid "$SESSION_ID" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.entries += [{"skill":"/wf-diagram","session_id":$sid,"phase":"phase_0",
                  "event":"START","timestamp":$ts}]' \
   "$trace_file" > "$tmp" && mv "$tmp" "$trace_file"
```

---

## POST-GATE (Session Init)

```
- [ ] $SESSION_DIR tồn tại (test -d)
- [ ] diagram-status.json non-empty (test -s) + .session_id valid (jq -e)
- [ ] checkpoint.json non-empty (test -s) + .next_action.phase = "phase_1" (jq -e)
- [ ] trace_file có entry với event="START" và session_id=$SESSION_ID (jq)
```

---

## Called By

| Caller | Bước | Khi nào |
|--------|------|---------|
| `procedures/phase0-setup.md` | Steps 0.4–0.8 | Fresh run (không có `--resume`) |
| Future reset/restart logic | SI-1 → SI-5 toàn bộ | Khi cần tạo lại session data |
