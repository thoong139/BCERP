# Phase 1: Fix với Per-Fix Verification

> **ĐIỂM THEN CHỐT:** Mỗi fix đi qua vòng lặp Read → Edit → IMMEDIATELY Verify → Log.
> Nếu verify FAIL → Revert ngay → move sang MANUAL. **KHÔNG BAO GIỜ** tiếp tục mà bỏ qua verify.

**PRE-GATE:** Phase 0 POST-GATE pass — `fix_queue` sorted, `fix-status.json` tồn tại.

**📤 OUTPUT (Phase 1):**
- `$SESSION_DIR/fix-log.json` (template: `templates/fix-log.template.json`) — populated dần qua loop
- Code files được sửa in-place (theo giới hạn tại `_shared.md §Auto-Fix Limits`)

---

## Per-Fix Verification Loop (CHI TIẾT)

```
FOR EACH finding IN fix_queue:

  ┌─────────────────────────────────────────────────┐
  │ STEP 1: READ — Lấy snapshot trước fix           │
  │   original_content = Read(finding.file)          │
  │   Lưu original_content vào memory               │
  │   (dùng để revert nếu verify fail)              │
  └─────────────────────┬───────────────────────────┘
                        ▼
  ┌─────────────────────────────────────────────────┐
  │ STEP 2: EDIT — Áp dụng fix                      │
  │   Nếu --dry-run → SKIP step này, log proposal   │
  │   Nếu live → Edit(file, old_string, new_string) │
  └─────────────────────┬───────────────────────────┘
                        ▼
  ┌─────────────────────────────────────────────────┐
  │ STEP 3: VERIFY — Kiểm tra NGAY LẬP TỨC         │
  │   3a. Theo edit_type:                             │
  │       REPLACEMENT: Grep old_value → PHẢI = 0     │
  │       ADDITIVE: SKIP (old_value là context)       │
  │   3b. Grep new_value trong file → PHẢI ≥ 1       │
  │   3c. Nếu là path/name REPLACEMENT:               │
  │       Grep old_value TOÀN BỘ .claude/ → PHẢI = 0 │
  │   3d. Cross-ref check (theo category):             │
  │       REFERENCE/NAMING: Glob target → EXISTS      │
  │       STRUCTURAL/DEPRECATED: SKIP                 │
  │   [STRUCTURAL] Nếu fix thêm/sửa frontmatter:     │
  │       Validate YAML syntax sau edit               │
  └─────────────────────┬───────────────────────────┘
                        ▼
              ┌─────────┴─────────┐
              │  ALL checks PASS? │
              └────┬─────────┬────┘
                   │         │
                 YES         NO
                   │         │
                   ▼         ▼
  ┌────────────────────┐  ┌────────────────────────────┐
  │ STEP 4a: PASS      │  │ STEP 4b: REVERT + MANUAL   │
  │ Log:               │  │ Edit(file, back to          │
  │  status=            │  │   original_content)         │
  │  "FIXED_VERIFIED"  │  │ Verify revert thành công    │
  │  verify_steps=[..] │  │ Log:                        │
  └────────────────────┘  │  status="REVERTED"          │
                          │  reason="[check nào fail]"  │
                          │ Move finding → MANUAL list  │
                          └────────────────────────────┘
```

---

## Step Table

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.1 | READ template `templates/fix-log.template.json` → khởi tạo `fix_log` structure với mode, severity_filter, source (từ verified result), empty `fixes[]`/`manual_issues[]`/`regressions[]` | Read | structure matches template |
| 1.2 | FOR EACH finding in `fix_queue`: | - | loop started |
| 1.3 | — **READ**: Đọc `finding.file` → lưu `original_content` | Read | content captured |
| 1.4 | — **CHECK**: Verify finding vẫn valid (`old_value` still exists) | Grep | old_value found |
| 1.5 | — Nếu `old_value` KHÔNG tìm thấy → status="SKIPPED" (đã fix bởi fix trước) | - | logged |
| 1.6 | — Nếu `--dry-run` → log fix proposal, status="DRY_RUN", CONTINUE | - | logged |
| 1.7 | — **EDIT**: Apply fix theo `finding.fix_proposal`. Nếu match Fix Pattern (FP1-FP9) → READ section tương ứng trong `fix-patterns.md` để lấy steps chi tiết + confirm CDG nếu HIGH-RISK | Edit | edit applied |
| 1.7b | — **CDG check (FP3 explicit):** Nếu fix type = FP3 (digest template creation bằng Write) → **BẮT BUỘC** hiển thị CDG prompt: "Will CREATE new file [path] with [N] lines. Approve? [y/n]". User phải confirm trước khi apply. Xem `_shared.md §NGOẠI LỆ — FP3` | - | CDG confirmed (FP3) |
| 1.8 | — **VERIFY 3a**: Kiểm tra theo `edit_type` (từ `finding.fix_proposal.edit_type`): | Grep | per rules below |
|     | &nbsp;&nbsp;• `REPLACEMENT` (mặc định): Grep `old_value` → PHẢI = 0 (old đã bị thay thế) | | |
|     | &nbsp;&nbsp;• `ADDITIVE` (FP2, FP4, FP5, FP6, FP7): **SKIP check này** — `old_value` là context giữ nguyên | | |
| 1.9 | — **VERIFY 3b**: Grep `new_value` trong `finding.file` | Grep | result_count ≥ 1 |
|     | &nbsp;&nbsp;&nbsp;⚠ Nếu `new_value` là multi-line → Grep một key substring (e.g., dòng mới thêm) | | |
| 1.10 | — **VERIFY 3c** (nếu path/name change): Grep `old_value` toàn bộ `.claude/`. Nếu timeout → fallback E013 (subdirectory sequential) | Grep | result_count = 0 (hoặc chỉ unrelated) |
| 1.11 | — **VERIFY 3d**: Áp dụng theo category: | Glob | per rules below |
|     | &nbsp;&nbsp;• `REFERENCE`: Glob target file path → PHẢI EXISTS | | |
|     | &nbsp;&nbsp;• `STRUCTURAL`: SKIP (không có target file) | | |
|     | &nbsp;&nbsp;• `DEPRECATED` (text substitution): SKIP | | |
|     | &nbsp;&nbsp;• `NAMING`: Glob renamed file path → PHẢI EXISTS | | |
| 1.12 | — Nếu ALL verify PASS → log `status="FIXED_VERIFIED"` + `verify_steps[]` | - | logged |
| 1.13 | — Nếu ANY verify FAIL → **REVERT**: Edit file về `original_content` | Edit | content restored |
| 1.14 | — Verify revert: Read file → so sánh với `original_content` | Read | match confirmed |
| 1.15 | — Nếu revert FAIL → log CRITICAL warning, STOP processing file này (E014) | - | E014 triggered |
| 1.16 | — Log `status="REVERTED"`, `reason="[check nào fail]"` | - | logged |
| 1.17 | — Move finding → `manual_list[]` | - | moved |
| 1.18 | Progress update mỗi 5 fixes: "[N]/[total] processed" | Output | displayed |
| 1.19 | **Checkpoint mỗi 10 fixes hoặc khi context > 65%**: Update `fix-status.json` (`processed`, `last_processed_finding`), flush partial `fix-log.json` | Write | checkpoint saved |

---

## Ví dụ 1: Fix broken knowledge path

```
Finding: F-AGT-001, severity=CRITICAL
  file: .claude/agents/business/sales-expert.md
  issue: Knowledge path ".claude/references/team-expert/sales/crm.md" không tồn tại
  fix_proposal:
    edit_type: REPLACEMENT
    old_value: ".claude/references/team-expert/sales/crm.md"
    new_value: ".claude/references/team-expert/sales/methodology.md"
    category: REFERENCE

STEP 1 — READ:
  original_content = Read(".claude/agents/business/sales-expert.md")
  → Lưu toàn bộ content

STEP 2 — EDIT:
  Edit(file, old=".claude/references/team-expert/sales/crm.md",
            new=".claude/references/team-expert/sales/methodology.md")

STEP 3 — VERIFY:
  3a. Grep "crm.md" trong file
      → 0 results ✓ (REPLACEMENT: old path đã bị xóa)
  3b. Grep "methodology.md" trong file
      → 1 result at line 15 ✓ (new path tồn tại đúng chỗ)
  3c. Grep "crm.md" toàn bộ .claude/
      → 0 results ✓ (không file nào khác reference old path)
  3d. Glob ".claude/references/team-expert/sales/methodology.md"
      → EXISTS ✓ (REFERENCE category: target file thực sự tồn tại)

  ALL PASS → status = "FIXED_VERIFIED"
  verify_steps = [
    {"check": "Grep old path in file = 0", "result": "PASS"},
    {"check": "Grep new path in file exists", "result": "PASS"},
    {"check": "Grep old path in .claude/ = 0", "result": "PASS"},
    {"check": "Glob new path exists", "result": "PASS"}
  ]
```

---

## Ví dụ 2: Fix nhưng verify FAIL → Revert

```
Finding: F-SKL-015, severity=MINOR
  file: .claude/agents/engineering/developer.md
  issue: Missing frontmatter field "version"
  fix_proposal:
    edit_type: ADDITIVE
    old_value: "---\nname: developer"
    new_value: "---\nversion: 1.0.0\nname: developer"
    category: STRUCTURAL

STEP 1 — READ:
  original_content = Read(".claude/agents/engineering/developer.md")

STEP 2 — EDIT:
  Edit(file, old="---\nname: developer",
            new="---\nversion: 1.0.0\nname: developer")

STEP 3 — VERIFY:
  3a. SKIP (edit_type = ADDITIVE)
  3b. Grep "version: 1.0.0" trong file
      → 1 result ✓
  3c. N/A (không phải path change)
  3d. SKIP (category = STRUCTURAL)
  [STRUCTURAL check] Validate YAML frontmatter — kiểm tra bổ sung:
      Bash: python -c "import yaml; yaml.safe_load(open(file).read().split('---')[1])"
      → FAIL ✗ (thụt lề sai, YAML parse error — edit tạo ra indentation lỗi)

  VERIFY FAIL → REVERT:
  Edit(file, old=current_content, new=original_content)
  Verify revert: Read file → khớp original_content ✓

  status = "REVERTED"
  reason = "YAML frontmatter validate fail sau edit — thụt lề không hợp lệ"
  Move finding → manual_list[]
```

---

## Ví dụ 3: FP4 (ADDITIVE) — thêm digest step vào SKILL.md

```
Finding: F-MP-FP4-002, severity=MAJOR
  file: .claude/skills/workflow/wf-design/SKILL.md
  issue: Missing digest generation step trong POST-GATE (Phiên 6)
  fix_proposal:
    edit_type: ADDITIVE
    old_value: "## POST-GATE\n\n- design outputs tồn tại"
    new_value: "## POST-GATE\n\n- design outputs tồn tại\n- design-input-digest.json tồn tại (Phiên 6)"
    category: STRUCTURAL
    pattern: FP4

STEP 0 — CDG-02 Confirm (FP4 là HIGH-RISK):
  Hiển thị: "Sẽ sửa SKILL.md của wf-design (workflow skill) để thêm digest step.
            Proposed content: [new_value preview]
            Approve? [y/n]"
  User confirm → tiếp tục.

STEP 1 — READ: original_content = Read(file)
STEP 2 — EDIT: Edit(file, old, new)
STEP 3 — VERIFY:
  3a. SKIP (ADDITIVE)
  3b. Grep "design-input-digest.json" trong file
      → 1 result ✓
  3c. N/A
  3d. SKIP (STRUCTURAL)
  [Extra FP4 check] Grep "digest" trong file
      → count sau fix ≥ count trước fix + 1 ✓

  ALL PASS → status = "FIXED_VERIFIED"
```

---

## POST-GATE

- Tất cả findings trong `fix_queue` đã processed
- `fix_log[]` populated (mỗi entry có status + verify_steps)
- Không có finding nào bị "bỏ sót" (total = fixed + reverted + skipped + dry_run)
- `fix-status.json` updated: `phase1-fix.status = "completed"`

**Update `fix-status.json`:**
```
phases.phase1-fix.status = "completed"
phases.phase1-fix.completed_at = NOW
phases.phase1-fix.fixes_applied = <FIXED_VERIFIED count>
phases.phase1-fix.fixes_reverted = <REVERTED count>
phases.phase1-fix.fixes_skipped = <SKIPPED count>
phases.phase2-rescan.status = "pending"
timestamps.last_updated = NOW
current_phase = "phase2-rescan"
```

---

## Graceful Degradation

- `original_content` lost trước khi revert (E004/E014) → CRITICAL STOP, log đường dẫn file, user phải restore thủ công
- Grep timeout trong `.claude/` (Step 1.10) → E013 fallback: grep từng subdir (`agents/`, `skills/`, `references/`) tuần tự
- Edit conflict khi `old_string` không tìm thấy (E006) → re-read file, recalculate. Fail 2 lần → MANUAL
