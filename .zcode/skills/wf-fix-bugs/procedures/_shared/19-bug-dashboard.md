# §19 Bug Dashboard Update Pattern

> Pattern canonical cho `bug-dashboard.md` — single source of truth cho dashboard logic dùng xuyên suốt Phase 1 (init), Phase 5 (generate), Phase 6 (update), Phase 7 (finalize).
> Mục tiêu: đảm bảo 4 vòng update tuân thủ CORE-031 (Template Usage Rule), CORE-035 (Atomic Write), CORE-028 (non-specialist readable).

## §19.1 Canonical Paths

| Tên | Đường dẫn |
|-----|----------|
| Template | `.claude/skills/workflow/wf-fix-bugs/templates/phase5-triage/bug-dashboard.md` |
| Output | `$SESSION_DIR/bug-dashboard.md` (session root, KHÔNG đặt trong subdirectory phase) |
| Meta | `$SESSION_DIR/bug-dashboard.md.meta.json` (init phase only) |

## §19.2 Pattern (READ → POPULATE → ATOMIC WRITE → VERIFY)

```bash
# 1. READ template (CORE-031)
DASHBOARD_TEMPLATE=".claude/skills/workflow/wf-fix-bugs/templates/phase5-triage/bug-dashboard.md"
test -f "$DASHBOARD_TEMPLATE" || { echo "E035: template missing" >&2; exit 1; }

# 2. POPULATE — ưu tiên Python CLI, fallback inline
python -m dashboard_generator \
  --session-dir="$SESSION_DIR" \
  --template="$DASHBOARD_TEMPLATE" \
  --output="$SESSION_DIR/bug-dashboard.md" \
  --current-phase="<phase-id>" \
  [--issue-registry=...] [--fix-report=...] 2>/dev/null

# Nếu Python CLI fail → inline fallback (heredoc / sed populate)
# Mỗi phase có context riêng (init / generate / update / finalize)
# nhưng CHUNG schema markdown (header, table, legend, hướng dẫn)

# 3. ATOMIC WRITE (CORE-035)
# Pattern: build vào tmp file → mv. Áp dụng cả khi populate qua Python CLI hay inline.

# 4. VERIFY (POST-GATE T1-T2)
test -s "$SESSION_DIR/bug-dashboard.md"                           # T1: exists + non-empty
grep -q "Bug Dashboard\|$SESSION_ID" "$SESSION_DIR/bug-dashboard.md"  # T2: header marker
```

## §19.3 Phase-Specific Context (chỉ phần khác nhau giữa 4 sites)

| Phase | Step | Mục tiêu | Input cần POPULATE |
|-------|------|----------|--------------------|
| Phase 1 | Wave 4 W2 (v10.12+) | Tạo dashboard rỗng cùng meta JSON | `SESSION_ID`, `NAME`, `SCOPE`, `PROFILE`, current-phase="init" |
| Phase 5 | 5.12 — Generate | Render toàn bộ issue checklist | `issue-registry.json`, current-phase="5" |
| Phase 6 | 6.7b — Update | Cập nhật trạng thái sau Phase 6 execute | `fix-log.json`, `fix-report.md`, current-phase="6" |
| Phase 7 | 7.5b — Finalize | Tổng kết cuối + hướng dẫn next | `fix-report.md`, `E005_HEALTHY`, current-phase="7" |

## §19.4 Error Codes (canonical mapping)

| Lỗi | Code | Phase | Hành động |
|-----|------|-------|-----------|
| `dashboard_generator` Python CLI fail | E035 (Phase 1), E051 (Phase 5), E065 (Phase 6), E075 (Phase 7) | per-phase | Fallback inline generation — không block pipeline |
| Template không tồn tại | E035 | Phase 1 chính | Tạo dashboard stub tối thiểu — escalate |
| `issue-registry.json` parse fail | E051 | Phase 5 | Re-read + retry x1 |
| Atomic write fail | E001 | shared | Retry x1 → escalate |

**Lưu ý:** Dashboard fail là **non-blocking** ở Phase 5/6/7 — pipeline tiếp tục advance. Phase 1 dashboard init fail (E035) cũng KHÔNG block — pipeline tiếp tục.

## §19.5 Cross-ref các call sites

- Phase 1 — `phase1-init.md` Wave 4 Worker 2 (v10.12+ — gộp với init-session-state qua bundle)
- Phase 5 — `phase5-triage.md` Step 5.9 "Generate Reports" (đã gộp Bug Dashboard từ v10.7)
- Phase 6 — `phase6-execute.md` Step 6.5 "Validate + Verify + Dashboard" (đã gộp từ v10.8)
- Phase 7 — `phase7-verify.md` Step 7.4 "Mobile + Dashboard" (đã gộp từ v10.9)

**BHV-002 (Simplicity First):** 4 sites giữ phase-specific context (data source, current-phase parameter, fallback heredoc) nhưng tham chiếu §19 cho pattern chung — tránh duplicate documentation về template path, atomic write, verify pattern.
