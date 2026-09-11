# /wf-diagram — Phase 0: Setup & Argument Validation

> Lazy-loaded từ SKILL.md. Xem `_shared.md` cho state variables, helpers, error matrix.

---

## PRE-GATE

```
- [ ] $ARGUMENTS đã có (CLI args)
- [ ] HOẶC $module được cung cấp HOẶC $scope = "system-only"
- [ ] $source_path tồn tại (test -d)
```

---

## Steps

### 0.0 — Resume/Status Dispatch

```
NẾU --resume HOẶC --status:
  Load `procedures/resume-routing.md` → dispatch đầy đủ → STOP hoặc GOTO phase
KHÔNG fresh run nếu --resume/--status set.
```

> Chi tiết đầy đủ (CASE A/B): `procedures/resume-routing.md`.

### 0.1 — Parse Arguments

```bash
module=$(echo "$ARGUMENTS" | grep -oP -- '--module=\K[^ ]+' || echo "")
source_path=$(echo "$ARGUMENTS" | grep -oP -- '--source-path=\K[^ ]+' || echo ".")
output_path=$(echo "$ARGUMENTS" | grep -oP -- '--output-path=\K[^ ]+' || echo ".mc-data/docs/diagrams")
scope=$(echo "$ARGUMENTS" | grep -oP -- '--scope=\K[^ ]+' || echo "full")
```

### 0.2 — Validate Args

```
NẾU $scope ≠ "system-only" AND $module == "":
  → STDOUT: "Workflow yêu cầu tên module. Vui lòng cung cấp `--module=<tên>`
     hoặc dùng `--scope=system-only` nếu chỉ muốn sinh sơ đồ tổng thể."
  → Exit E001

NẾU $scope NOT IN {"full", "module-only", "system-only"}:
  → STDOUT: "--scope phải là full | module-only | system-only"
  → Exit E001
```

### 0.3 — Validate Source Path

```bash
test -d "$source_path" || {
  echo "ERROR: $source_path không tồn tại. Hãy kiểm tra bằng \`ls\`"
  exit 2  # E002
}
```

### 0.4 — Generate SESSION_ID (Protocol 18.2)

```
scope_label = lowercase-kebab-case của $module (hoặc "system" nếu scope=system-only)
SESSION_ID = "$(date +%Y-%m-%d)-$scope_label"

NẾU đã có session cùng tên:
  Append suffix -2, -3, ...

# Ví dụ: 2026-04-30-order, 2026-04-30-order-2, 2026-04-30-system
```

### 0.5 — Create Directories

```bash
mkdir -p ".mc-data/work/wf-diagram/sessions/$SESSION_ID"
mkdir -p "$output_path"
mkdir -p ".mc-data/work/_trace"  # Cho Protocol 15
```

### 0.6 — Init diagram-status.json (READ → POPULATE → WRITE)

```
1. Read templates/diagram-status.json
2. Populate: session_id, module, source_path, output_path, scope, started_at (ISO-8601)
3. Write → $session_dir/diagram-status.json
4. Verify: jq '.session_id' diagram-status.json ≠ "" AND test -s diagram-status.json
```

### 0.7 — Init checkpoint.json (READ → POPULATE → WRITE)

```
1. Read templates/checkpoint.json
2. Populate: {{SESSION_ID}}, {{MODULE}}, {{SCOPE}}, {{CREATED_AT_ISO8601}}, args_snapshot
3. Write → $session_dir/checkpoint.json
4. Verify: test -s checkpoint.json
```

### 0.8 — Append Trace START (Protocol 15)

```bash
trace_file=".mc-data/work/_trace/session-log.json"

# Init nếu chưa tồn tại
[ -f "$trace_file" ] || {
  Read template: .claude/doc-framework/_meta/session-log.template.json
  Write → $trace_file
}

# Atomic append
tmp=$(mktemp)
jq --arg sid "$SESSION_ID" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.entries += [{"skill":"/wf-diagram","session_id":$sid,"phase":"phase_0",
                  "event":"START","timestamp":$ts}]' \
   "$trace_file" > "$tmp" && mv "$tmp" "$trace_file"
```

---

## POST-GATE

```
- [ ] $session_dir tồn tại (test -d)
- [ ] diagram-status.json non-empty (test -s) + .session_id valid (jq)
- [ ] checkpoint.json non-empty (test -s)
- [ ] trace_file có entry START (jq '.entries[-1].event == "START"')
```

---

## Next Phase

→ Phase 1: `procedures/phase1-precheck.md` (Pre-check Existing Diagrams)
