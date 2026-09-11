# Phase 2 — Auto-Fix Structural Issues (mặc định BẬT)

> Fix lỗi structural TRƯỚC khi chạy semantic audit.
> D4/D5 agents sẽ audit trên state ĐÃ SỬA → không báo false positives.

**PRE-GATE:** Phase 1 completed, `structural_findings[]` có sẵn.

> **`--no-fix`:** SKIP toàn bộ Phase 2. Update status: `phases.phase_2.skipped = true`, `phases.phase_2.skip_reason = "--no-fix flag"`. Đi thẳng đến `phase3-semantic.md`.

## Steps

| Step | Action | Tool | Verify |
| ---- | ------ | ---- | ------ |
| 2.1 | Filter findings có thể auto-fix (D1/D2/D3/D7) | — | fixable[] |
| 2.2 | **D3 fix** (ưu tiên cao nhất): field names, types, required | Edit | d3_fixed[] |
| 2.3 | **D1 fix**: Tạo file thiếu từ template + context | Write | d1_fixed[] |
| 2.4 | **D2 fix**: Thêm section headers thiếu | Edit | d2_fixed[] |
| 2.5 | **D7 fix**: Thêm fields thiếu với default values | Edit | d7_fixed[] |
| 2.6 | Re-check tất cả items đã fix (max 3 iterations) | Bash/Grep | recheck_results[] |
| 2.7 | Log fix results | — | fix_log[] |

## Auto-Fix Priority & Rules

> Xem `_shared.md §5 Fix Rules` — có table đầy đủ: Error Type → Auto-Fix Strategy → Escalate If.

**Thứ tự fix (tự động khi phát hiện lỗi):**
1. D3 Registry schema (field names, types, missing fields) — ưu tiên cao nhất
2. D1 File thiếu (tạo từ template nếu có context)
3. D2 Template sections thiếu (thêm headers)
4. D7 Status file thiếu fields (thêm defaults)

**KHÔNG BAO GIỜ auto-fix:**
- D6 POST-GATE failures → chỉ báo cáo (phải re-run skill)
- D4 Content quality thấp → phải re-run skill
- D5 Cross-phase scope mismatch → phải re-run phase trước
- D8 Digest/A6-EXT/A7-EXT/context_digest thiếu → phải re-run skill với Master Plan enabled

**SAFETY GATE — `.claude/` Protection:**
```
QUY TẮC: KHÔNG auto-fix files trong .claude/ — chỉ flag + ESCALATE.
- .claude/ chứa DEVKIT infrastructure (agents, skills, templates, rules, hooks)
- Sửa sai 1 file trong .claude/ có thể break toàn bộ pipeline
- Exception: KHÔNG có exception — mọi .claude/ files đều READ-ONLY cho auto-fix
- Nếu phát hiện issue trong .claude/ → log CRITICAL + ESCALATE + recommend user chạy /audit-devkit-fix
```

## POST-GATE

- Fixable issues resolved. State clean cho semantic audit
- Update status: `phases.phase_2.status = "completed"` (hoặc `"skipped"` nếu --no-fix), `phases.phase_2.fixes_applied`, `findings.auto_fixed`, `last_updated`

## Next

→ READ `procedures/phase3-semantic.md` và thực thi.
