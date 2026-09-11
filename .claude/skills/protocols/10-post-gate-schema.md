<!-- From shared-protocols.md lines 797-863 (§10) -->
# Protocol 10 — POST-GATE Schema Validation Protocol (BẮT BUỘC)

> Đảm bảo output documents đạt chuẩn cấu trúc và nội dung — không chỉ tồn tại mà còn đúng schema.
> Bổ sung cho Protocol 1 (structural) và Protocol 8 (semantic).

## 10.1 Bốn tầng validation (Tiered)

| Tier | Tên | Kiểm tra gì | Công cụ |
|------|-----|-------------|---------|
| **T1** | Existence | File tồn tại, non-empty (`test -s`) | `test -s file` |
| **T2** | Structure | Required sections/headings present | Grep headings, đếm sections |
| **T3** | Content | Minimum content depth (word count, sentence count per section) | Đếm words, verify >= threshold |
| **T4** | Cross-reference | IDs/references khớp giữa docs và registry | Cross-check sets |

## 10.2 Schema Source

Sử dụng `_contract.json` có sẵn trong `doc-framework/` cho mỗi phase:
- `.claude/doc-framework/phase1-business/_contract.json`
- `.claude/doc-framework/phase2-features/_contract.json`
- `.claude/doc-framework/phase3-architecture/_contract.json`
- `.claude/doc-framework/phase4-ux/_contract.json`
- `.claude/doc-framework/phase5-implementation/_contract.json`
- `.claude/doc-framework/phase6-deployment/_contract.json`

Nếu `_contract.json` không tồn tại → fallback về manual heading check.

## 10.3 Bảng áp dụng theo Skill

| Skill | Phase | Tier áp dụng | Chi tiết |
|-------|-------|-------------|----------|
| wf-design-ux | Phase 1 POST-GATE | T2 | 6 required sections: Colors, Typography, Spacing, Components, Breakpoints, Icons |
| wf-design-ux | Phase 3 POST-GATE | T3 | >= 200 words per screen group |
| wf-implement-feature | Phase 4 POST-GATE | T4 | REQ-IDs in source match registry |
| wf-prepare-deployment | Phase 2 POST-GATE | T2 + T3 | Mục 1-8 headings present + >= 500 words |
| wf-prepare-deployment | Phase 3a POST-GATE | T2 + T3 | User guide headings + adequate content |

## 10.4 Forensic PRE-GATE Validation

> Thay thế `test -f` đơn giản bằng content validation cho entry PRE-GATE (Phase 0).
> CHỈ áp dụng cho entry PRE-GATE — internal phase PRE-GATEs giữ nguyên `test -f`/`test -s`.

**Forensic check thay thế file existence check:**

```
THAY VÌ: test -f prerequisite.md
DÙNG:
  1. test -s prerequisite.md                    (non-empty)
  2. heading_count = grep -c "^##" file         (>= min_headings)
  3. word_count = wc -w file                    (>= min_words)
  4. grep -q "REQUIRED_MARKER" file             (chứa marker nếu cần)

NẾU BẤT KỲ check FAIL:
  → "[prerequisite] không đạt yêu cầu nội dung (found: X headings, Y words; required: >= A headings, >= B words). Chạy `/wf-[skill]` để tạo/hoàn thiện."
```

**Bảng thresholds theo prerequisite:**

| Prerequisite file | Min headings | Min words | Required marker | Dùng bởi skill |
|-------------------|-------------|-----------|-----------------|----------------|
| P0-01-project-brief.md | 3 | 200 | — | wf-analyze-requirements |
| departments/**/*.md | 4 | 300 | `REQ-` | wf-define-features |
| phase2-features/**/*.md | 6 | 400 | — | wf-design |
| P3-01-architecture.md | 7 | 500 | — | wf-design-ux, wf-plan-modules, wf-prepare-deployment |
| task-impl.md | 6 | 400 | — | wf-implement-feature |
| req-registry.json | — | — | `.requirements \| length > 0` | wf-preflight, wf-verify-sync |
| Source files (>= 1) | — | — | Có nội dung | wf-fix-bugs, wf-fix-execute, wf-verify-sync |
