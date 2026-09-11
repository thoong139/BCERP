# Phase 5: Merge Findings & Output Report

> Merge tất cả findings từ phases trước, tính compliance, generate báo cáo markdown.

## PRE-GATE

- Ít nhất 1 findings-*.json tồn tại trong `$SESSION_DIR/`
- Phase 0 completed

## Steps

### 5.1 — Merge findings

| Step | Action | Tool | Output |
|------|--------|------|--------|
| 5.1.1 | Read tất cả `$SESSION_DIR/findings-*.json` | Read | Arrays loaded |
| 5.1.2 | Concat thành 1 array; dedup theo `(target, check)`. Nếu duplicate: giữ severity cao hơn | — | Merged array |
| 5.1.3 | Sort theo severity: CRITICAL → MAJOR → MINOR, sau đó theo target | — | Sorted array |

### 5.2 — Tính metrics

| Step | Action | Output |
|------|--------|--------|
| 5.2.1 | Count: critical, major, minor | `summary.critical`, `summary.major`, `summary.minor` |
| 5.2.2 | Total checks = tổng criteria đã run (tùy scope): A1-A10 * agents + P0-P6 * procedures + K0-K3+KG+KP * domains + X1-X6 | `total_checks` |
| 5.2.3 | Compliance rate = 100 * (total_checks - critical*3 - major*2 - minor*1) / total_checks | `compliance_rate` |
| 5.2.4 | Verdict theo `_shared.md §Verdict Computation` | `verdict` |

### 5.3 — Write audit-result.json

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 5.3.1 | Tạo object `audit-result` theo schema `_shared.md §Schemas — audit-result.json` | — | Schema valid |
| 5.3.2 | Write `$SESSION_DIR/audit-result.json` | Write | jq valid |

### 5.4 — Generate markdown report (inline template)

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 5.4.1 | Populate inline template (xem Output Template dưới) với metrics + findings | — | Template filled |
| 5.4.2 | Đảm bảo mkdir -p `docs/audit/reports/` | Bash | dir tồn tại |
| 5.4.3 | Write `docs/audit/reports/agent-audit-$REPORT_DATE.md` | Write | File tồn tại |

### 5.5 — Update status.json → completed

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 5.5.1 | Set `status.json.completed_at = now()`, append `phase5-report` vào completed_phases, empty pending_phases | Write | status valid |

### 5.6 — Hiển thị summary cho user

In ra console:
- Compliance rate + verdict
- Counts CRITICAL/MAJOR/MINOR
- Top 5 CRITICAL findings (target + check + title)
- Report path

## POST-GATE (Protocol 10 — T1→T4)

- **T1:** `test -f docs/audit/reports/agent-audit-$REPORT_DATE.md` → file tồn tại
- **T2:** `test -s docs/audit/reports/agent-audit-$REPORT_DATE.md` → file không rỗng
- **T3:** Report có đúng headings (`# Agent & Knowledge Compliance Audit Report`, `## Tóm tắt`, `## Findings`, `## Recommendations`)
- **T4:** Findings table có ≥1 row (hoặc "No findings" explicit statement); Summary table có đủ metrics
- `audit-result.json` valid JSON, có `summary` + `findings` fields
- `status.json.completed_at != null`

## Output Template (inline)

```markdown
# Agent & Knowledge Compliance Audit Report

> **Ngày:** [YYYY-MM-DD]
> **Phạm vi:** [N] agents, [N] procedures, [N] knowledge domains
> **Spec version:** [version from README.md]
> **Session ID:** [YYYYMMDD-HHMMSS]
> **Verdict:** [EXCELLENT | GOOD | ACCEPTABLE | NEEDS ATTENTION]

## Tóm tắt

| Metric | Giá trị |
|--------|---------|
| Tổng agents kiểm tra | [N] |
| Tổng procedures kiểm tra | [N] |
| Tổng knowledge domains kiểm tra | [N] |
| CRITICAL | [N] |
| MAJOR | [N] |
| MINOR | [N] |
| Compliance rate | [%] |

## Findings (sorted by severity)

| # | Severity | Target | Check | Vấn đề | Đề xuất sửa |
|---|----------|--------|-------|--------|-------------|
| 1 | CRITICAL | [agent/proc/domain] | [TC-XX] | [Mô tả] | [Fix] |

## Recommendations
1. [Quick wins — fix ngay]
2. [Structural changes — cần plan]
3. [Spec updates — nếu cần]

## Session artifacts

- Working dir: `.mc-data/work/audit-agents/[session-id]/`
- Merged result: `.mc-data/work/audit-agents/[session-id]/audit-result.json`
- Findings (per phase): `findings-agents.json`, `findings-procedures.json`, `findings-knowledge.json`, `findings-crossref.json`
```

## Lưu ý

- **Tiếng Việt có dấu đầy đủ** — Report dùng "Ngày", "Tổng", "Phạm vi", "Đề xuất" — không viết không dấu
- **Đếm dòng** — Không đếm blank lines và `---` separators (áp dụng khi tính size violations)
- **Heading variants** — Chấp nhận "Cognitive Framework" = "Dual Perspective Framework" khi sort findings
- **Report path** — `docs/audit/reports/` (KHÔNG `.mc-data/` — đây là DEVKIT self-audit, không phải project workspace)

## Next

- Fix findings theo priority (CRITICAL → MAJOR → MINOR)
- Re-run `/audit-agents --full` để verify
- Muốn audit toàn diện (skills + templates + workflow) → dùng `/audit-devkit --full`

## Errors liên quan

- Merge: nếu findings files corrupt → attempt re-read, nếu fail log WARNING vào report header
- Write report fail: retry ×3, nếu vẫn fail → ghi vào `$SESSION_DIR/audit-result.json` và báo user path backup

Chi tiết: `_shared.md §Error Handling Reference`.
