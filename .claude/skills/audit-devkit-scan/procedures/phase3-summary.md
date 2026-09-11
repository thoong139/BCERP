# Phase 3: Summary Display & Status Finalize

> Hiển thị kết quả scan cho user, hướng dẫn bước tiếp theo, finalize status.

**PRE-GATE:** `$SESSION_DIR/audit-scan-result.json` tồn tại + JSON valid

**📤 OUTPUT:**
- User-facing markdown summary (xem `Output Report Template` trong SKILL.md)
- `$SESSION_DIR/scan-status.json` finalized với `status="completed"`
- Lock release

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.1 | READ `$SESSION_DIR/audit-scan-result.json` | Read | loaded |
| 3.2 | READ `$SESSION_DIR/audit-index.json` để lấy counts breakdown per component type | Read | loaded |
| 3.3 | Render bảng tóm tắt cho user (xem template Output Report bên dưới). Bao gồm: tổng findings (CRITICAL/MAJOR/MINOR), auto_fixable vs manual, breakdown per component, session-id, paths đến output files | Output | displayed |
| 3.4 | Render hướng dẫn bước tiếp theo: `/audit-devkit-verify` (next pipeline step) | Output | displayed |
| 3.5 | UPDATE `$SESSION_DIR/scan-status.json`: `status = "completed"`, `phases.phase_3_summary.status = "completed"`, `phases.phase_3_summary.completed_at = NOW`, `next_action = "run_audit_devkit_verify"` | Edit | updated |
| 3.6 | **Lock release:** `rm $SESSION_DIR/.lock` | Bash | lock removed |

**POST-GATE:** User nhận được summary + hướng dẫn. `scan-status.json.status == "completed"`.

---

## Output Report Template

```markdown
## /audit-devkit-scan Hoàn tất!

| Mục | Giá trị |
|-----|---------|
| Session ID | [session-id] |
| Components scanned | [total_scanned] |
| Findings | [total] (CRITICAL: [n], MAJOR: [n], MINOR: [n]) |
| Auto-fixable | [auto_fixable] |
| Manual required | [manual] |
| Batches executed | [batch_count] |
| Agent spawns | [metrics.agent_spawns] |
| Split events | [metrics.split_events] (auto-split when batch overflow) |

### Breakdown by Component

| Component | Indexed | Findings |
|-----------|---------|----------|
| Agents | [count] | [n] |
| Skills | [count] | [n] |
| Templates | [count] | [n] |
| Rules | [count] | [n] |
| Hooks | [count] | [n] |
| Scripts | [count] | [n] |
| Master Plan Components | [7 checks] | [n] *(NOT_FOUND = 0 findings)* |

### Output Files

| # | File | Path |
|---|------|------|
| 1 | audit-index.json | `.mc-data/work/audit-devkit-scan/[session-id]/audit-index.json` |
| 2 | findings-*.json | `.mc-data/work/audit-devkit-scan/[session-id]/findings-*.json` |
| 3 | audit-scan-result.json | `.mc-data/work/audit-devkit-scan/[session-id]/audit-scan-result.json` |
| 4 | scan-status.json | `.mc-data/work/audit-devkit-scan/[session-id]/scan-status.json` |
| 5 | phase-summary.md | `.mc-data/work/audit-devkit-scan/[session-id]/phase-summary.md` (CORE-028: tóm tắt tiếng Việt cho non-specialist sau Phase 3 — template `.claude/doc-framework/_meta/phase-summary.template.md`) |

### Next Step

```bash
/audit-devkit-verify
```

→ Cross-validate findings, build verified-findings.json cho `/audit-devkit-fix`.
```

---

## Edge Cases

- **Findings = 0 (PASS hoàn hảo):** vẫn hiển thị summary, ghi rõ "Không phát hiện issue nào — DEVKIT PASS"
- **Partial scan (E003/E008):** hiển thị warnings về batches bị skip + suggest re-run với `--resume`
- **Circuit breaker triggered:** flag `metrics.circuit_breaker_triggered = true` → hiển thị "⚠️ PARTIAL — circuit breaker triggered. Consider re-run sau khi điều tra."

---

## Cross-references

- audit-scan-result schema: `templates/audit-scan-result.json`
- scan-status schema: `templates/scan-status.json`
- Next skill in pipeline: `/audit-devkit-verify`
