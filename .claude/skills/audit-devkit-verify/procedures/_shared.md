# Shared Protocols — audit-devkit-verify

> Cross-cutting protocols, state variables, auditor prompt templates, và reference schemas
> được dùng bởi nhiều Phase trong audit-devkit-verify.
> KHÔNG đọc file này standalone — chỉ load section cụ thể khi cần (Table of Contents phía dưới).

## Sections

- [State Variables Glossary](#state-variables-glossary)
- [Cross-Phase Data Flow](#cross-phase-data-flow)
- [Fix Rules](#fix-rules)
- [Auditor Prompt Templates](#auditor-prompt-templates)
- [Finding ID Prefixes](#finding-id-prefixes)
- [Schemas](#schemas)
- [Checkpoint & Resume](#checkpoint--resume)
- [Error Handling Reference](#error-handling-reference)
- [Verdict Computation](#verdict-computation)

---

## State Variables Glossary

| Variable | Set by Phase | Read by Phase | Description |
|----------|-------------|---------------|-------------|
| `$SCOPE` | Phase 0.1 | 0, 1, 1.F, 2, 3, 3.5, 4 | `crossref` / `workflow` / `consistency` / `master-plan` / `all` / `skill` |
| `$FOCUSED_SKILL` | Phase 0.1 | 1.F, 2, 3, 4 | Tên skill khi scope=`skill` (VD: `wf-legacy-scan`). NULL khi scope khác |
| `$SESSION_ID` | Phase 0.1b | All phases | Discovered session-id từ scan folder (latest timestamp) |
| `$SCAN_DIR` | Phase 0.1b | All phases | `.mc-data/work/audit-devkit-scan/[session-id]/` |
| `$VERIFY_DIR` | Phase 0.2 | All phases | `.mc-data/work/audit-devkit-verify/[session-id]/` |
| `$INDEX` | Phase 0.3 | 1, 1.F, 2, 3, 3.5 | Content của `audit-index.json` |
| `$SCAN_RESULT` | Phase 0.6 | 4 | Content của `audit-scan-result.json` |
| `$MP_COMPONENTS` | Phase 3.5.0 | 3.5 V1-V6 | `audit-index.json:master_plan_components` object |
| `$SKIP_PHASE_3_5` | Phase 3.5.0 | 3.5 | Boolean — true nếu tất cả master_plan_components = NOT_FOUND |
| `$FINDINGS_FILES[]` | Phase 1-3.5 | 4 | Danh sách các findings JSON files đã tạo |

---

## Cross-Phase Data Flow

```
Phase 0 (load)          → $SCOPE, $FOCUSED_SKILL, $SESSION_ID, $INDEX, $SCAN_RESULT
                         → verify-status.json (initial)
Phase 1 (crossref A-D)  → findings-crossref-*.json × 4
Phase 1.F (focused)     → findings-crossref-[name].json × 1
Phase 2 (workflow)      → findings-workflow.json
Phase 3 (consistency)   → findings-consistency.json
Phase 3.5 (masterplan)  → findings-masterplan-verify.json
Phase 4 (merge)         → audit-verified-result.json + report.md
                         → verify-status.json (completed)
```

**Quy tắc:** Mỗi phase chỉ READ variables đã được SET ở phase trước. POST-GATE của phase N cập nhật `verify-status.json.completed_phases[]`.

---

## Fix Rules

| Error Type | Auto-Fix Strategy | Escalate If |
|-----------|-------------------|-------------|
| Scan result JSON invalid | Re-read + validate. Nếu corrupt → yêu cầu re-run scan | Parse fail sau 3 lần |
| Agent timeout / không trả output | Re-spawn agent 1 lần | Fail lần 2 |
| Agent trả text thay vì JSON | Fallback parse: extract JSON từ text | Parse fail → log raw text + MANUAL |
| Ground truth index stale (files đã bị xóa/rename) | Update index in-place, add WARNING | >10% files stale → yêu cầu re-scan |
| Findings dedup conflict | Giữ finding có severity cao hơn | Cùng severity → giữ có evidence cụ thể hơn |

---

## Auditor Prompt Templates

### Template chung (dùng cho Phase 1 Pass A-D, Phase 2)

```
Bạn là [AGENT_TYPE]. Verify [DOMAIN] cho DEVKIT.

Ground truth (từ audit-index.json):
[paste relevant component lists]

Kiểm tra:
[specific checks cho pass này]

OUTPUT FORMAT (BẮT BUỘC — JSON):
Trả về KẾT QUẢ dạng JSON array. Mỗi finding là 1 object:
{
  "id": "F-[PREFIX]-[NNN]",
  "severity": "CRITICAL|MAJOR|MINOR",
  "component": "[component type]",
  "file": "[path]",
  "line": [number or null],
  "criterion": "[criterion ID or null]",
  "issue": "[mô tả cụ thể]",
  "fix_type": "AUTO|MANUAL",
  "fix_proposal": "[đề xuất fix cụ thể]",
  "evidence": "[bằng chứng — Glob/Grep result]"
}

KHÔNG trả kết quả text. CHỈ JSON array.
Chỉ report items có issues. Items PASS không cần report.
```

### Template focused crossref (Phase 1.F — `--skill=<name>`)

```
Bạn là cross-reference-auditor. Focused verify cho skill: [name].

Target skill:
- SKILL.md: [path]
- _contract.json: [path]

Cross-Skill Output Path Contract (00-core.md §4b — filtered):
[chỉ rows liên quan đến target skill]

Downstream skills (target produces for):
[list skills + paths từ produces_for]

Upstream skills (target consumes from):
[list skills + paths từ consumes_from]

Kiểm tra:
1. _contract.json `produces_for` paths = SKILL.md output paths (EXACT match)
2. _contract.json `consumes_from` paths = SKILL.md input paths (EXACT match)
3. Output paths trong SKILL.md tồn tại trong 00-core.md §4b
4. Template references trong SKILL.md tồn tại trên disk
5. Downstream skills: PRE-GATE references target outputs
6. Upstream skills: POST-GATE produces files target expects

OUTPUT FORMAT (BẮT BUỘC — JSON):
Trả về KẾT QUẢ dạng JSON array. Mỗi finding:
{
  "id": "F-XRF-[NNN]",
  "severity": "CRITICAL|MAJOR|MINOR",
  "category": "functional|structural",
  "criterion_group": "contract|crossref|path-alignment",
  "file": "[path]",
  "line": [number or null],
  "criterion": "[criterion ID]",
  "issue": "[mô tả cụ thể]",
  "fix_type": "AUTO|MANUAL",
  "fix_proposal": "[đề xuất fix cụ thể]",
  "evidence": "[bằng chứng]"
}

KHÔNG trả kết quả text. CHỈ JSON array.
Chỉ report items có issues. Items PASS không cần report.
```

### Template workflow integrity (Phase 2)

```
Bạn là workflow-auditor. Verify workflow integrity cho DEVKIT.

Ground truth (từ audit-index.json):
[paste skills list]

Cross-reference verification đã tìm:
[paste summary từ 4 crossref findings]

Cross-Skill Output Path Contract (từ rules/00-core.md §4b):
[paste toàn bộ contract table]

Registry Safe-Write Protocol (từ rules/00-core.md §4a):
[paste safe-write table]

Kiểm tra:
1. TỪNG handoff trong §4b: Producer output path = Consumer input path (EXACT string match)
2. Phase prerequisites: Phase N+1 PRE-GATE check Phase N output
3. REQ-ID continuity: mỗi skill chỉ update fields được phân công

OUTPUT FORMAT (BẮT BUỘC — JSON):
[same template as Phase 1, with id prefix "F-WFL-"]
```

---

## Finding ID Prefixes

| Prefix | Pass / Source |
|--------|---------------|
| `F-XRF-` | Cross-reference (Phase 1 Pass A-D + Phase 1.F focused) |
| `F-WFL-` | Workflow integrity (Phase 2) |
| `F-CON-001...` | Agent coordination symmetry (Phase 3.1) |
| `F-CON-100...` | Deprecated name usage (Phase 3.2) |
| `F-CON-200...` | Naming inconsistency (Phase 3.3) |
| `F-MPV-V1-` | Master Plan V1 — Hook 2-Tầng |
| `F-MPV-V2-` | Master Plan V2 — Checkpoint Schema |
| `F-MPV-V3-` | Master Plan V3 — Digest Pipeline |
| `F-MPV-V4-` | Master Plan V4 — A6-EXT ↔ A7-EXT |
| `F-MPV-V5-` | Master Plan V5 — Parallel Execution |
| `F-MPV-V6-` | Master Plan V6 — Backward Compatibility |
| `F-MPV-V7-` | Master Plan V7 — Digest Pipeline Chain Integrity |
| `F-MPV-V8-` | Master Plan V8 — Bridge File Existence |
| `F-MPV-V9-` | Master Plan V9 — Registry Ownership Uniqueness |

---

## Schemas

### audit-findings-v1 (dùng cho tất cả findings-*.json)

```jsonc
{
  "$schema": "audit-findings-v1",
  "pass": "[pass identifier]",      // VD: "crossref-agents-skills", "workflow", "consistency", "masterplan-verify"
  "generated_at": "2026-04-19T10:00:00Z",
  "findings": [
    {
      "id": "F-[PREFIX]-[NNN]",
      "severity": "CRITICAL|MAJOR|MINOR",
      "category": "functional|structural",   // [v2.0] optional cho focused mode
      "component": "[component type]",
      "file": "[path]",
      "line": 42,                             // hoặc null
      "criterion": "[criterion ID]",
      "issue": "[mô tả]",
      "fix_type": "AUTO|MANUAL",
      "fix_proposal": "[đề xuất]",
      "evidence": "[bằng chứng]"
    }
  ]
}
```

### audit-verified-result-v1 (Phase 4 output)

```jsonc
{
  "$schema": "audit-verified-result-v1",
  "verified_at": "2026-04-19T10:30:00Z",
  "scan_source": "audit-scan-result.json",
  "additional_sources": [
    "findings-crossref-agents-skills.json",
    "findings-crossref-skills-templates.json",
    "findings-crossref-docs.json",
    "findings-crossref-hooks.json",
    "findings-workflow.json",
    "findings-consistency.json",
    "findings-masterplan-verify.json"       // optional — null nếu Phase 3.5 skipped
  ],
  "findings": [ /* deduped, final severity */ ],
  "dedup_log": [
    {
      "kept": "F-XRF-001",
      "removed": "F-AGT-005",
      "reason": "Same issue (broken path), detected by both scan and crossref"
    }
  ],
  "summary": {
    "from_scan": 37,
    "from_crossref": 8,
    "from_workflow": 3,
    "from_consistency": 2,
    "from_master_plan": 4,
    "deduped": 5,
    "final_total": 49,
    "critical_functional": 4,
    "critical_structural": 2,
    "critical": 6,
    "major": 17,
    "minor": 26,
    "auto_fixable": 32,
    "manual": 17
  },
  "master_plan_verify": {                     // null nếu Phase 3.5 skipped
    "skipped": false,
    "skip_reason": null,
    "v1_hook_2tier": 0,
    "v2_checkpoint": 1,
    "v3_digest_pipeline": 2,
    "v4_a6ext_a7ext": 0,
    "v5_parallel_safety": 1,
    "v6_backward_compat": 0,
    "v7_digest_chain": 0,                     // [v1.2] Digest pipeline link mismatches
    "v8_bridge_file_existence": 0,            // [v1.2] Missing bridge file templates
    "v9_registry_ownership": 0                // [v1.2] Overlapping PRIMARY ownership
  },
  "verdict_pre_fix": "BROKEN"                 // BROKEN | NEEDS ATTENTION | ACCEPTABLE | CLEAN
}
```

### verify-status.json (checkpoint schema)

```jsonc
{
  "skill": "audit-devkit-verify",
  "session_id": "20260419-100000",            // format YYYYMMDD-HHMMSS — khớp với scan session
  "status": "in_progress",                    // "in_progress" | "completed"
  "started_at": "2026-04-19T10:00:00Z",
  "completed_at": null,                       // ISO timestamp khi completed
  "scope": "all",                             // "crossref" | "workflow" | "consistency" | "master-plan" | "all" | "skill"
  "focused_skill": null,                      // tên skill khi scope="skill"
  "completed_phases": [
    "phase0-load",
    "phase1-pass-a",
    "phase1-pass-b"
  ],
  "pending_phases": [
    "phase1-pass-c",
    "phase1-pass-d"
  ],
  "next_action": "Phase 1, Pass C: agents ↔ rules ↔ CLAUDE.md"
}
```

**Phase ID hợp lệ:**

| Phase ID | Tên | Scope |
|----------|-----|-------|
| `phase0-load` | Load & Validate | all scopes |
| `phase1-pass-a` | Cross-ref: agents ↔ skills | crossref, all |
| `phase1-pass-b` | Cross-ref: skills ↔ templates | crossref, all |
| `phase1-pass-c` | Cross-ref: docs | crossref, all |
| `phase1-pass-d` | Cross-ref: hooks | crossref, all |
| `phase1-focused-crossref` | **[v2.0]** Focused crossref | skill |
| `phase2-workflow` | Workflow integrity | workflow, all, skill |
| `phase3-consistency` | Bidirectional consistency | consistency, all, skill |
| `phase3_5-master-plan` | **[v1.1]** Master Plan V1-V6 | master-plan, all |
| `phase4-merge` | Final merge & report | all, skill (tất cả scope partial cũng chạy mini-merge để tính verdict) |

---

## Checkpoint & Resume

| Context Usage | Hành động |
|---------------|-----------|
| < 65% | Tiếp tục bình thường |
| 65-80% | Chuẩn bị checkpoint |
| 80-90% | Lưu checkpoint ngay |
| > 90% | FORCE STOP — checkpoint bắt buộc |

### Resume Process

1. READ `verify-status.json` từ `$VERIFY_DIR`
2. LOAD `audit-index.json` + `audit-scan-result.json` (không cần rebuild)
3. Xác định passes đã completed từ existing findings-*.json files
4. CONTINUE từ pass tiếp theo chưa hoàn thành

---

## Error Handling Reference

> **Error code prefix:** VERIFY- (VD: VERIFY-E001, VERIFY-E002). Dùng khi log/display để phân biệt với errors từ scan/fix/orchestrator.

| Code | Situation | Action |
|------|-----------|--------|
| E001 | PRE-GATE fail — `audit-index.json` không tồn tại | STOP — chạy `/audit-devkit-scan` trước |
| E002 | PRE-GATE fail — `audit-scan-result.json` không tồn tại | STOP — chạy `/audit-devkit-scan` trước |
| E003 | `audit-index.json` JSON invalid | Retry read 3 lần. Nếu vẫn invalid → STOP, yêu cầu re-scan |
| E004 | `audit-scan-result.json` JSON invalid | Retry read 3 lần. Nếu vẫn invalid → STOP, yêu cầu re-scan |
| E005 | Spot-check fail (>20% files stale) | WARNING + yêu cầu user chạy lại scan |
| E006 | Agent timeout / không trả output | Re-spawn agent 1 lần, sau đó skip pass + WARNING |
| E007 | Agent trả text thay vì JSON | Fallback parse: extract JSON từ text. Nếu fail → log raw + MANUAL |
| E008 | `findings-crossref-*.json` missing sau Phase 1 | Re-run missing pass. Nếu vẫn fail → partial merge + WARNING |
| E009 | Dedup conflict (không rõ giữ finding nào) | Giữ finding severity cao hơn. Cùng severity → giữ evidence cụ thể hơn |
| E010 | File write fail (permission/disk) | Retry 3 lần, sau đó escalate to user |
| E011 | Resume: `verify-status.json` corrupt | Rebuild status từ existing findings-crossref-*.json files |
| E012 | `rules/00-core.md` §4b contract table parse fail | Fallback: manual Read + regex extract contract rows |
| E013 | scope=partial ghi sai completed_phases (list phases ngoài scope) | completed_phases CHỈ chứa phases thuộc scope đã chọn. pending_phases=[] khi scope hoàn thành |
| E014 | **[v1.1]** Phase 3.5: `audit-index.json` không có `master_plan_components` | Log WARNING + skip Phase 3.5. Tiếp tục Phase 4 mà không có master plan findings |
| E015 | **[v1.1]** Phase 3.5: V1-V6 không đọc được file (VD: `protocols/` không tồn tại) | Skip check + ghi finding MINOR: "[file] không tìm thấy". Tiếp tục các checks còn lại |
| E016 | **[v1.1]** Phase 3.5 V3: digest path §4b KHÔNG khớp template filename | MAJOR finding per mismatch. Không auto-fix (cần review thủ công) |

---

## Verdict Computation

Rule áp dụng cho `verdict_pre_fix` trong `audit-verified-result.json`:

**Phân biệt CRITICAL-functional vs CRITICAL-structural:**
- `CRITICAL-functional`: issue khiến downstream skill fail (broken cross-ref, contract mismatch, missing required field)
- `CRITICAL-structural`: cosmetic/structural issue không block downstream (naming convention, formatting, missing optional field)

**Chỉ CRITICAL-functional ảnh hưởng verdict.** CRITICAL-structural liệt kê riêng trong report.

| Điều kiện | Verdict |
|-----------|---------|
| Total = 0 | `CLEAN` |
| CRITICAL-functional = 0, MAJOR ≤ 5 | `ACCEPTABLE` |
| CRITICAL-functional = 0, MAJOR > 5 | `NEEDS ATTENTION` |
| CRITICAL-functional 1-3 | `NEEDS ATTENTION` |
| CRITICAL-functional > 3 | `BROKEN` |

**STRICT RULE:** Verdict PHẢI tuân theo bảng CHÍNH XÁC dựa trên số CRITICAL-functional. KHÔNG exercise judgment.

**Lưu ý:** Khi scope=partial (crossref/workflow/consistency/master-plan/skill), verdict tính chỉ trên findings thuộc scope đó (không merge với scan findings).
