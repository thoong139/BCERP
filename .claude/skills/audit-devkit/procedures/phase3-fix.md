# Phase 3: Fix — Delegate `/audit-devkit-fix`

> **Đọc:** `procedures/_shared.md §Sub-Skill Invocation Model` trước khi execute.

**Điều kiện chạy:** `fix` ∈ `$STAGES[]` VÀ `$FIX_MODE = ON`.

**Mục đích:** Gọi sub-skill `/audit-devkit-fix` với `$FIX_SEVERITY`, chờ hoàn thành, đọc fix summary + post-fix verdict.

---

## Display Header

```
Phase 3/N: Auto-fixing verified issues...
```

Nếu `$FIX_MODE = OFF` → Skip Phase 3, nhảy sang Phase 3.5 hoặc Phase 4.

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.1 | Gọi Skill tool: `{ skill: "audit-devkit-fix", args: "--severity=<$FIX_SEVERITY> --session=$SESSION_ID" }`. **Bắt buộc append `--session=$SESSION_ID`** để pin session đã discover ở Phase 1 hoặc Phase 0 Step 0.7 (fix-only mode). `$SESSION_ID` PHẢI non-empty ở thời điểm gọi. | Skill | Skill started |
| 3.2 | Chờ hoàn thành | — | Skill completed |
| 3.3 | **Verify output:** `.mc-data/work/audit-devkit-fix/$SESSION_ID/fix-log.json` tồn tại + JSON valid | Read | File exists + valid |
| 3.4 | Extract metrics từ fix-log: `{attempted, fixed, reverted, skipped}` → `$FIX_SUMMARY` | Read | Counts extracted |
| 3.5 | Extract `verdict_post_fix` từ fix-log → `$VERIFY_VERDICT_POST_FIX` | Read | Verdict extracted |
| 3.6 | Hiển thị fix summary cho user: | Output | Displayed |

```
Fix hoàn tất: $FIX_SUMMARY.fixed/$FIX_SUMMARY.attempted verified.
Verdict: **$VERIFY_VERDICT_PRE_FIX** → **$VERIFY_VERDICT_POST_FIX**
```

---

## POST-GATE

| Check | Required |
|-------|----------|
| `fix-log.json` tồn tại + JSON valid | ✓ |
| `$FIX_SUMMARY` populated | ✓ |
| `$VERIFY_VERDICT_POST_FIX` set | ✓ |

---

## Errors

| Tình huống | Action |
|------------|--------|
| Fix skill fail | Hiển thị error → **WARNING** + nhảy Phase 3.5/4 (vẫn có scan + verify data). KHÔNG stop pipeline |
| fix-log.json không tồn tại | **WARNING** + nhảy Phase 4 với `$FIX_SUMMARY = null`, verdict_post_fix = verdict_pre_fix |
| JSON invalid | Retry read 1 lần. Nếu fail → **WARNING** + nhảy Phase 4 với partial data |
| `verdict_post_fix` missing | Fallback: `$VERIFY_VERDICT_POST_FIX = $VERIFY_VERDICT_PRE_FIX` + WARNING |

---

## Lưu ý về Fix-Only mode

Khi `--fix-only`, Phase 1 và Phase 2 đã bị skip. `$SESSION_ID` được lấy từ prerequisite validation tại Phase 0 Step 0.7 (Glob latest `audit-devkit-verify/*/audit-verified-result.json`).

`$VERIFY_VERDICT_PRE_FIX` có thể chưa set trong Phase 2 → đọc trực tiếp từ `audit-verified-result.json` tại Step 3.5 để hiển thị.
