# Phase 1: Scan — Delegate `/audit-devkit-scan`

> **Đọc:** `procedures/_shared.md §Sub-Skill Invocation Model` + `§Session-ID Discovery Protocol`.

**Điều kiện chạy:** `scan` ∈ `$STAGES[]`.

**Mục đích:** Gọi sub-skill `/audit-devkit-scan` với `$SCAN_ARGS`, chờ hoàn thành, discover session-id, verify output, hiển thị summary.

---

## Display Header

```
Phase 1/N: Scanning components... (N = số stages đang chạy)
```

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.1 | Gọi Skill tool: `{ skill: "audit-devkit-scan", args: "<$SCAN_ARGS>" }` | Skill | Skill started |
| 1.2 | Chờ hoàn thành | — | Skill completed |
| 1.3 | **Discover `$SESSION_ID`:** Glob `.mc-data/work/audit-devkit-scan/*/audit-scan-result.json` → pick latest timestamp directory. Extract directory name → `$SESSION_ID`. | Glob | `$SESSION_ID` set |
| 1.4 | **Verify output:** `.mc-data/work/audit-devkit-scan/$SESSION_ID/audit-scan-result.json` tồn tại + JSON valid | Read | File exists + valid |
| 1.5 | Đọc summary: extract `{total, critical, major, minor}` từ scan result → `$SCAN_SUMMARY` | Read | Counts extracted |
| 1.6 | Hiển thị cho user: | Output | Displayed |

```
Scan hoàn tất (session: $SESSION_ID): $SCAN_SUMMARY.total findings
  (CRITICAL: $SCAN_SUMMARY.critical, MAJOR: $SCAN_SUMMARY.major, MINOR: $SCAN_SUMMARY.minor)
```

---

## POST-GATE

| Check | Required |
|-------|----------|
| `$SESSION_ID` set (non-empty) | ✓ |
| `audit-scan-result.json` tồn tại + JSON valid | ✓ |
| `$SCAN_SUMMARY` populated | ✓ |

---

## Errors

| Tình huống | Action |
|------------|--------|
| Scan skill fail | Hiển thị error → **STOP** pipeline (E003) |
| Không tìm thấy audit-scan-result.json trong bất kỳ session directory | **STOP E004**: "Scan không tạo output — kiểm tra /audit-devkit-scan" |
| JSON invalid | Retry read 1 lần. Nếu vẫn fail → **STOP E006** |
| Partial results (missing batches) | **WARNING E007** + tiếp tục verify/fix với available data. Hiển thị cảnh báo: "Scan incomplete: missing batches [list]. Verdict may be inaccurate" |
