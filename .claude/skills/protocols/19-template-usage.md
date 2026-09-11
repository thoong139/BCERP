<!-- From shared-protocols.md lines 1519-1609 (§19) -->
# Protocol 19 — Template Usage Rule Protocol (BẮT BUỘC — MỌI SKILL)

> Mọi output file PHẢI được tạo từ template — KHÔNG tự viết schema từ đầu.
> Đảm bảo output nhất quán giữa các lần chạy, hỗ trợ resume và cross-skill handoff.

## 19.1 Quy tắc cốt lõi

```
TEMPLATE USAGE RULE (READ → POPULATE → WRITE):

Bước 1: READ template     → Đọc file template để BIẾT schema cần gì
Bước 2: POPULATE data     → Điền dữ liệu thực tế vào ĐÚNG fields của template
Bước 3: WRITE output      → Ghi kết quả đã populate ra output path

KHÔNG ĐƯỢC:
- Tạo output file từ đầu (ad-hoc) — luôn phải đọc template trước
- Bỏ qua fields trong template — populate tất cả fields hoặc ghi rõ lý do bỏ
- Tự thêm fields không có trong template — mở rộng template nếu thực sự cần
```

## 19.2 Template Locations

| Loại output | Template location | Ví dụ |
|-------------|-------------------|-------|
| Working files (status, checkpoint, plan...) | `.claude/skills/workflow/[skill]/templates/` | `templates/checkpoint.json`, `templates/define-features-status.json` |
| Doc output (Phase 1-6 docs) | `.claude/doc-framework/[phase]/` | `doc-framework/phase2-features/[sys]/[mod]/[feature].md` |
| Digest artifacts (_meta/) | `.claude/doc-framework/_digests/` | `_digests/feature-briefs.template.json` |
| Meta templates | `.claude/doc-framework/_meta/` | `_meta/deferred-findings-template.md` |

## 19.3 Cách enforce trong SKILL.md / flow-new.md

```
TRONG MỌI STEP TABLE — khi step tạo output file:

SAI:  | 2.5 | SAVE CHECKPOINT | Checkpoint saved |
ĐÚNG: | 2.5 | SAVE CHECKPOINT từ template `templates/checkpoint.json`
      |     | — populate position, progress, next_action   | Checkpoint saved |

NGUYÊN TẮC:
- Mỗi step tạo file PHẢI chứa chữ "từ template" + đường dẫn template
- Nếu template nằm ngoài skill (doc-framework) → ghi ĐẦY ĐỦ path
- Nếu output dùng inline schema (không có template riêng) → ghi "inline schema" rõ ràng
```

## 19.4 _contract.json phải khớp

```
Mỗi entry trong _contract.json outputs.working[] PHẢI có field "template":
- Nếu có template file → ghi path: "template": "templates/checkpoint.json"
- Nếu dùng inline schema → ghi null: "template": null
- template: null PHẢI kèm "notes" giải thích vì sao không có template riêng
```

## 19.5 Bảng áp dụng theo Skill

| Skill | Templates trong `templates/` | Enforce cần kiểm tra |
|-------|------------------------------|---------------------|
| wf-brainstorm | — | Dùng doc-framework templates |
| wf-analyze-requirements | — | Dùng doc-framework templates |
| wf-define-features | 5 (checkpoint, status, plan, briefs, ui-coverage-gaps) | ✅ Đã enforce |
| wf-design | — | Dùng doc-framework templates |
| wf-design-ux | — | Dùng doc-framework templates |
| wf-plan-modules | — | Dùng doc-framework templates |
| wf-implement-feature | decision-registry + others | Cần kiểm tra |
| wf-preflight | — | Inline schema |
| wf-fix-bugs | checkpoint, fix-status (orchestrator) | Inline schema — execute templates thuộc wf-fix-execute |
| wf-fix-execute *(spawned)* | 5 templates: fix-log, e2e-results, fix-plan, fix-report, fix-history | ✅ Đã enforce (contract template field cho 5 outputs có template; phase-summary.md dùng inline schema có notes) |
| wf-verify-sync | — | Inline schema |
| wf-prepare-deployment | — | Dùng doc-framework templates |
| wf-manage-change | — | Dùng doc-framework templates |

> **Lưu ý:** Bảng trên chỉ liệt kê templates trong `templates/` folder của skill.
> Templates cho doc output (Phase 1-6) nằm trong `.claude/doc-framework/` và cũng phải được enforce.

## 19.6 Audit Checklist

```
KHI AUDIT SKILL — kiểm tra Template Usage Rule:

1. Liệt kê tất cả output files trong _contract.json outputs.working[]
2. Cho mỗi file có "template" != null:
   a. Template file có tồn tại không? (test -f)
   b. Trong flow-new.md/SKILL.md — step tạo file có ghi "từ template" không?
   c. Template schema có khớp với output thực tế không?
3. Cho mỗi file có "template" == null:
   a. Có "notes" giải thích không?
   b. Inline schema trong flow-new.md có đầy đủ không?
4. Tỷ lệ enforce = (files có "từ template" trong steps) / (tổng files có template)
   → Target: 100%
```
