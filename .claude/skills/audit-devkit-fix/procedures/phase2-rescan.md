# Phase 2: Post-Fix Targeted Re-scan

> **CHỈ re-scan files đã sửa** (status=`FIXED_VERIFIED`). KHÔNG re-scan toàn bộ DEVKIT.
> Mục đích: phát hiện regressions và confirm fix không tạo issue mới.

**PRE-GATE:** Phase 1 POST-GATE pass — `fix_log` populated.

**📤 OUTPUT (Phase 2):**
- `$SESSION_DIR/fix-log.json` updated với `regressions[]`
- `$SESSION_DIR/fix-status.json` updated với `phase2-rescan.regressions_found`

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 2.1 | Collect `changed_files[]` từ `fix_log` (status="FIXED_VERIFIED") | - | list created |
| 2.1b | **Cascading impact for REPLACEMENT fixes:** Với mỗi fix có `edit_type=REPLACEMENT`, Grep `old_value` trong toàn bộ `.claude/` → thêm files reference `old_value` vào `changed_files[]` (cross-referenced files). Tránh duplicate. | Grep | cascading files collected |
| 2.2 | Nếu `changed_files = 0` (all skipped/reverted/dry-run) → SKIP Phase 2 | - | skip condition |
| 2.3 | Phân loại changed files theo component type: | - | categorized |
|     | — agent files → `agent_files[]` | | |
|     | — skill files → `skill_files[]` | | |
|     | — other files → `other_files[]` | | |
| 2.4 | Nếu `agent_files` non-empty → spawn `agent-auditor` cho CHỈ `agent_files` | Agent (`agent-auditor`) | findings returned |
| 2.5 | Nếu `skill_files` non-empty → spawn `skill-auditor` cho CHỈ `skill_files` | Agent (`skill-auditor`) | findings returned |
| 2.6 | Spawn 2.4 + 2.5 **ĐỒNG THỜI** nếu cả hai non-empty | Agent | parallel execution |
| 2.7 | Cross-ref spot-check: Grep verify 0 broken refs cho mỗi changed file | Grep | 0 broken refs |
| 2.8 | Thu thập re-scan findings | - | `rescan_findings[]` |
| 2.9 | **Regression detection**: So sánh `rescan_findings` vs pre-fix findings | - | comparison done |
|     | — Finding MỚI (`id` không có trong pre-fix) = **REGRESSION** | | |
|     | — Finding CŨ vẫn còn = NOT_FIXED (should not happen nếu verify đúng) | | |
| 2.10 | Log regressions nếu có (KHÔNG revert — quá phức tạp, chỉ WARNING E012) | - | logged |
| 2.11 | Update `$SESSION_DIR/fix-status.json`: `phase2-rescan.regressions_found` | Write | updated |

---

## Re-scan Agent Prompt Template

```
Bạn là [auditor-type: agent-auditor | skill-auditor].
Re-scan CHỈ các files sau (đã được auto-fix):

CHANGED FILES (CHỈ scan những file này — KHÔNG scan toàn bộ .claude/):
— [file_path_1]
— [file_path_2]
— ...

PRE-FIX FINDINGS cho các file này (để so sánh):
[paste relevant pre-fix findings — chỉ findings cho files trong list trên]

KIỂM TRA:
1. Chạy full criteria cho auditor type của bạn
2. So sánh với pre-fix findings:
   — Finding đã fix → KHÔNG report lại
   — Finding cũ vẫn còn → REPORT (severity giữ nguyên)
   — Finding MỚI chưa từng có → REPORT (đánh dấu regression: true)

OUTPUT FORMAT (BẮT BUỘC — JSON, schema audit-findings-v1):
{
  "$schema": "audit-findings-v1",
  "findings": [
    {
      "id": "F-RSC-[NNN]",
      "severity": "CRITICAL|MAJOR|MINOR",
      "component": "agents|skills",
      "file": "[path]",
      "line": [number],
      "criterion": "[check name]",
      "issue": "[mô tả]",
      "fix_type": "AUTO|MANUAL",
      "fix_proposal": "[gợi ý]",
      "evidence": "[chi tiết]"
    }
  ],
  "summary": { "critical": N, "major": N, "minor": N, "total": N }
}

LƯU Ý:
— Tools: CHỈ dùng Read, Grep, Glob (không Edit, Write)
— Chỉ report issues MỚI hoặc issues CŨ vẫn còn
— Issues đã fix thành công KHÔNG cần report
```

---

## POST-GATE

- Re-scan complete cho tất cả changed files (hoặc Phase 2 skipped nếu `changed_files = 0`)
- Regression check done
- Regressions logged vào `fix_log.regressions[]` nếu có
- `fix-status.json` updated: `phase2-rescan.status = "completed"`

**Update `fix-status.json`:**
```
phases.phase2-rescan.status = "completed"
phases.phase2-rescan.completed_at = NOW
phases.phase2-rescan.agents_spawned = <count>
phases.phase2-rescan.regressions_found = <count>
phases.phase3-report.status = "pending"
timestamps.last_updated = NOW
current_phase = "phase3-report"
```

---

## Graceful Degradation

- Agent timeout (E007) → re-spawn 1 lần. Fail lần 2 → skip re-scan cho batch đó, log WARNING
- Agent trả text thay vì JSON (E008) → fallback parse JSON từ text. Fail → log raw text + skip
- Regression detected (E012) → log WARNING + hiển thị chi tiết. KHÔNG revert (out-of-scope cho auto-fix)
