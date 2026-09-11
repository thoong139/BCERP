# Phase 3: Final Report

> Write `fix-log.json`, create audit report, compute post-fix verdict, ghi Protocol 14/15.
> Phase cuối của skill — tổng hợp kết quả cho user.

**PRE-GATE:** Phase 2 POST-GATE pass (hoặc Phase 2 skipped).

**📤 OUTPUT (Phase 3):**
- `$SESSION_DIR/fix-log.json` (final)
- `.mc-data/work/audit-devkit-fix/reports/devkit-audit-fix-[date].md` (report mới, KHÔNG edit verify report)
- `$SESSION_DIR/phase-summary.md` (Protocol §14, tiếng Việt ≤15 dòng)
- `$SESSION_DIR/fix-status.json` — `status="completed"`

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.1 | Compute summary counts: | - | counts computed |
|     | — `attempted`: total fixes attempted | | |
|     | — `fixed_verified`: status="FIXED_VERIFIED" | | |
|     | — `reverted`: status="REVERTED" | | |
|     | — `skipped`: status="SKIPPED" | | |
|     | — `dry_run`: status="DRY_RUN" (nếu --dry-run) | | |
|     | — `regressions_detected`: count từ Phase 2 | | |
| 3.2 | Compute `post_fix_counts`: | - | counts computed |
|     | — Lấy original counts từ `audit-verified-result.json` | | |
|     | — Trừ đi `fixed_verified` findings theo severity | | |
|     | — Cộng regressions (nếu có) | | |
| 3.3 | Compute `verdict_post_fix`: | - | verdict determined |
|     | — total = 0 → "CLEAN" | | |
|     | — critical = 0, major ≤ 5 → "ACCEPTABLE" | | |
|     | — critical = 0, major > 5 → "NEEDS ATTENTION" | | |
|     | — critical 1-3 → "NEEDS ATTENTION" | | |
|     | — critical > 3 → "BROKEN" | | |
| 3.4 | WRITE `fix-log.json` từ template `templates/fix-log.template.json` — POPULATE: `fixed_at`, `source`, `mode`, `severity_filter`, `fixes[]` (từ `fix_log`), `manual_issues[]`, `regressions[]`, `summary`, `post_fix_counts`, `verdict_pre_fix`, `verdict_post_fix` | Write | File created |
| 3.5 | Validate: `jq '.' .mc-data/work/audit-devkit-fix/[session-id]/fix-log.json` | Bash | exit code 0 |
| 3.6 | **Tạo report MỚI** tại `.mc-data/work/audit-devkit-fix/reports/devkit-audit-fix-[date].md` | Write | File created |
|     | — Nếu verify report tồn tại tại `.mc-data/work/audit-devkit-verify/reports/` → đọc làm context | Read | |
|     | — Nội dung: Before/after severity comparison, Fix success rate, Regression warnings, Updated verdict, Manual issues cần user xử lý | | |
|     | — **KHÔNG edit report của verify skill** — chỉ đọc làm context, tạo report mới trong scope riêng | | |
| 3.7 | Hiển thị summary cho user (xem [Output Report](#output-report) bên dưới) | Output | displayed |
| 3.8 | List manual issues cần user xử lý | Output | displayed |
| 3.9 | Update `.mc-data/work/audit-devkit-fix/[session-id]/fix-status.json`: `status: "completed"` | Write | updated |
| 3.10 | **Ghi Execution Trace COMPLETE** (Protocol §15): Append entry vào `.mc-data/work/_trace/session-log.json`: `{event: "COMPLETE", skill: "audit-devkit-fix", session_id, timestamp, agents_invoked: [...], files_created: [...], warnings: [...]}` | Write/Bash | entry appended |
| 3.11 | **Tạo Phase Summary** (Protocol §14): READ template `.claude/doc-framework/_meta/phase-summary.template.md` → POPULATE thời gian, trạng thái, đã làm gì (tóm tắt fix results), kết quả (counts), thay đổi chính (key fixes), cần lưu ý (regressions/manual issues), bước tiếp theo → WRITE `phase-summary.md`. Tiếng Việt, ≤15 dòng. Hiển thị cho user. | Read, Write | file created + displayed |

---

## fix-log.json Schema (`fix-log-v1`)

> **QUY TẮC BẮT BUỘC — Schema nhất quán:** Mọi `fix-log.json` PHẢI tuân thủ schema dưới đây CHÍNH XÁC. Không được thêm top-level fields ngoài schema (như `fixes_applied`, `manual_fixes_applied`, `fixes_skipped`). Tất cả fixes (auto + manual) PHẢI nằm trong `fixes[]` array duy nhất.

```jsonc
{
  "$schema": "fix-log-v1",
  "fixed_at": "2026-04-19T10:45:00Z",
  "source": "audit-verified-result.json",
  "mode": "live",                        // "live" | "dry-run"
  "severity_filter": "ALL",             // "CRITICAL" | "MAJOR" | "ALL"
  "fixes": [
    {
      "finding_id": "F-AGT-001",
      "file": ".claude/agents/business/sales-expert.md",
      "action": "Edit: sửa path line 15",
      "old_value": ".claude/references/team-expert/sales/crm-systems.md",
      "new_value": ".claude/references/team-expert/sales/sales-methodology.md",
      "verify_steps": [
        {"check": "Grep old path in file = 0", "result": "PASS"},
        {"check": "Grep new path in file exists", "result": "PASS"},
        {"check": "Grep old path in .claude/ = 0", "result": "PASS"},
        {"check": "Glob new path exists", "result": "PASS"}
      ],
      "status": "FIXED_VERIFIED"
      // Possible statuses: FIXED_VERIFIED | REVERTED | SKIPPED | DRY_RUN
    }
  ],
  "manual_issues": [
    {
      "finding_id": "F-SKL-015",
      "file": ".claude/agents/engineering/developer.md",
      "issue": "Missing frontmatter field 'version' — YAML parse fail sau edit",
      "original_fix_type": "AUTO",
      "reason_manual": "Revert sau verify fail — cần user sửa thủ công"
    }
  ],
  "regressions": [
    {
      "finding_id": "F-NEW-001",
      "file": ".claude/agents/business/sales-expert.md",
      "issue": "New finding phát hiện sau fix — có thể do side effect",
      "source": "post-fix-rescan"
    }
  ],
  "summary": {
    "attempted": 30,
    "fixed_verified": 27,
    "reverted": 2,
    "skipped": 1,
    "dry_run": 0,
    "regressions_detected": 0
  },
  "post_fix_counts": {
    "critical": 1,
    "major": 8,
    "minor": 20
  },
  "verdict_pre_fix": "BROKEN",
  "verdict_post_fix": "NEEDS ATTENTION"
}
```

---

## Output Report (hiển thị cho user ở Step 3.7)

```markdown
## /audit-devkit-fix Hoàn tất!

| Mục | Giá trị |
|-----|---------|
| Mode | [live / dry-run] |
| Severity filter | [CRITICAL / MAJOR / ALL] |
| Total in queue | [N] |
| Fixed & verified | [N] ✓ |
| Reverted (verify fail) | [N] ↩ |
| Skipped (already fixed) | [N] ⊘ |
| Regressions detected | [N] |

### Before → After

| Severity | Before | After | Delta |
|----------|--------|-------|-------|
| CRITICAL | [N] | [N] | [−N] |
| MAJOR | [N] | [N] | [−N] |
| MINOR | [N] | [N] | [−N] |
| **Verdict** | **[BEFORE]** | **[AFTER]** | |

### Manual Issues (cần user xử lý)

| # | Finding | File | Issue | Reason |
|---|---------|------|-------|--------|
| 1 | [id] | [file] | [issue] | [reason manual] |

### Output Files

| # | File | Path | Purpose |
|---|------|------|---------|
| 1 | fix-log.json | .mc-data/work/audit-devkit-fix/[session-id]/ | Chi tiết từng fix + verify steps |
| 2 | devkit-audit-fix-[date].md | .mc-data/work/audit-devkit-fix/reports/ | Report MỚI với Auto-Fix Summary (dùng verify report làm context) |
| 3 | phase-summary.md | .mc-data/work/audit-devkit-fix/[session-id]/ | Tóm tắt kết quả cho non-technical user |

### Regressions (nếu có)

| # | Finding | File | Issue |
|---|---------|------|-------|
| 1 | [id] | [file] | [new issue phát hiện sau fix] |
```

---

## POST-GATE

- `$SESSION_DIR/fix-log.json` tồn tại, JSON valid, schema = `fix-log-v1`
- `.mc-data/work/audit-devkit-fix/reports/devkit-audit-fix-[date].md` tồn tại (report MỚI, KHÔNG phải edit của verify)
- `summary.attempted` = `length(fixes[])`
- `summary.fixed_verified + reverted + skipped + dry_run` = `summary.attempted`
- `verdict_post_fix` computed correctly based on `post_fix_counts`
- `$SESSION_DIR/phase-summary.md` tồn tại (Protocol §14)
- Execution Trace COMPLETE entry appended (Protocol §15)
- `fix-status.json.status = "completed"`, `phases.phase3-report.status = "completed"`

---

## Graceful Degradation

- `fix-log.json` write fail (E009) → retry 3 lần, sau đó escalate to user
- Verify report không tồn tại (E010) → Tạo report mới không cần context từ verify report
- Phase Summary template fail → fallback: tạo inline theo structure cơ bản (thời gian, trạng thái, kết quả, manual issues)
