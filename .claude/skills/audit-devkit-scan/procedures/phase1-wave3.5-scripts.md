# Phase 1 — Wave 3.5: Scripts Scan (Bash verify)

> Bash verify cho `.claude/scripts/*.sh`. Tương tự hooks scan — không cần agent.

**PRE-GATE:** `audit-index.json:components.scripts[]` non-empty (có thể empty → tạo file findings rỗng)

**📤 OUTPUT:** `findings-scripts.json` (template: `templates/findings.json`)

> Wave 3.5 có thể chạy ĐỒNG THỜI với Wave 3 (cả 2 đều nhẹ).

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.5s.1 | Cho mỗi script `*.sh` trong `audit-index.json:components.scripts[]`: `bash -n [script]` syntax check | Bash | syntax valid |
| 1.5s.2 | Verify shebang dòng 1: `head -1 [script]` chứa `#!/bin/bash` (hoặc `#!/usr/bin/env bash`) | Grep | shebang found |
| 1.5s.3 | Verify paths referenced trong script (Grep `\.claude/`, `\.mc-data/`) → check tồn tại bằng Glob | Grep+Glob | paths checked |
| 1.5s.4 | Cross-check: scripts được referenced trong skills/hooks → verify scripts tồn tại (Grep skill/hook → script paths) | Grep | cross-refs valid |
| 1.5s.5 | Build findings array: cho mỗi script fail → 1 finding (severity = MAJOR cho syntax, MINOR cho missing shebang/cross-ref) | - | findings collected |
| 1.5s.6 | WRAP vào schema `audit-findings-v1` (source = "bash-verify", batch = "scripts") → WRITE `$SESSION_DIR/findings-scripts.json` | Read+Write | file written |
| 1.5s.7 | Validate JSON | Bash | OK |
| 1.5s.8 | UPDATE `scan-status.json`: `wave_3_5_scripts.completed_batches` += ["scripts"], status = "completed" | Edit | status updated |

---

## POST-GATE

- `$SESSION_DIR/findings-scripts.json` tồn tại + JSON valid với `$schema: "audit-findings-v1"`
- Nếu `components.scripts[]` empty → file vẫn tồn tại với `findings: []` và `summary` zeros

---

## Cross-references

- Findings schema: `templates/findings.json`
- Next: `phase1-wave4-masterplan.md`
