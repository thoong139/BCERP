# Phase 2: Verify — Delegate `/audit-devkit-verify`

> **Đọc:** `procedures/_shared.md §Sub-Skill Invocation Model` + `§Verdict Computation` trước khi execute.

**Điều kiện chạy:** `verify` ∈ `$STAGES[]`.

**Mục đích:** Gọi sub-skill `/audit-devkit-verify` với `$VERIFY_ARGS`, chờ hoàn thành, verify output, đọc verdict_pre_fix.

---

## Display Header

```
Phase 2/N: Cross-validating findings...
```

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 2.1 | Gọi Skill tool: `{ skill: "audit-devkit-verify", args: "<$VERIFY_ARGS> --session=$SESSION_ID" }`. **Bắt buộc append `--session=$SESSION_ID`** để pin session đã discover ở Phase 1 (chống race khi repo có nhiều historical sessions). `$SESSION_ID` PHẢI non-empty ở thời điểm gọi (set bởi Phase 1 Step 1.3 hoặc Phase 0 Step 0.7 cho fix-only mode). | Skill | Skill started |
| 2.2 | Chờ hoàn thành | — | Skill completed |
| 2.3 | **Verify output:** `.mc-data/work/audit-devkit-verify/$SESSION_ID/audit-verified-result.json` tồn tại + JSON valid | Read | File exists + valid |
| 2.4 | Extract `verdict_pre_fix` + `summary.final_total` từ verified result → `$VERIFY_VERDICT_PRE_FIX` + `$VERIFY_TOTAL` | Read | Verdict extracted |
| 2.5 | Hiển thị pre-fix verdict cho user: | Output | Displayed |

```
Verify hoàn tất: $VERIFY_TOTAL findings.
Verdict (pre-fix): **$VERIFY_VERDICT_PRE_FIX**
```

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 2.6 | Nếu `$FIX_MODE = OFF` → hiển thị hướng dẫn fix thủ công: | Output | Displayed |

```
Fix mode: OFF. Để auto-fix findings, chạy:
  /audit-devkit --fix-only
hoặc fix thủ công theo hướng dẫn trong audit-verified-result.json
```

---

## Special: `--skill=<name>` Focused Mode

Khi `$VERIFY_ARGS` chứa `--skill=<name>`, verify sub-skill chạy focused mode (skip crossref passes A-D + Phase 3.5). Duration giảm xuống 1-3 min. Output format giống nhau.

---

## POST-GATE

| Check | Required |
|-------|----------|
| `audit-verified-result.json` tồn tại + JSON valid | ✓ |
| `$VERIFY_VERDICT_PRE_FIX` ∈ {`CLEAN`, `ACCEPTABLE`, `NEEDS ATTENTION`, `BROKEN`} | ✓ |
| `$VERIFY_TOTAL` là integer ≥ 0 | ✓ |

---

## Errors

| Tình huống | Action |
|------------|--------|
| Verify skill fail | Hiển thị error → **STOP** pipeline (E003) |
| audit-verified-result.json không tồn tại | **STOP E004**: "Verify không tạo output — kiểm tra /audit-devkit-verify" |
| JSON invalid | Retry read 1 lần. Nếu vẫn fail → **STOP E006** |
| `verdict_pre_fix` field missing | Fallback compute từ `summary.critical`/`summary.major` theo bảng §Verdict Computation. WARNING hiển thị cho user |
