<!-- From shared-protocols.md lines 552-617 (§8) + 913-941 (§13.5 → renamed §8.5 — bug fix per audit A1) -->
# Protocol 8 — Content Quality Gate Protocol (BẮT BUỘC)

> Kiểm tra chất lượng NỘI DUNG, không chỉ cấu trúc.
> Bổ sung cho Protocol 1 (Accuracy Assurance) — protocol 1 kiểm tra structural, protocol 8 kiểm tra semantic.

## 8.1 Hai tầng kiểm tra

```
POST-GATE = Structural Check (Protocol 1) + Content Quality Check (Protocol 8)

Structural Check (đã có):
✓ File tồn tại, non-empty
✓ JSON valid
✓ Required sections present
✓ REQ-ID format đúng

Content Quality Check (MỚI):
✓ Completeness: Mỗi section có nội dung thực (không chỉ headers)
✓ Consistency: Cross-reference giữa docs khớp nhau
✓ Traceability: Mỗi output map ngược về input
✓ No Hallucination: Không có thông tin không derive từ input
```

## 8.2 Content Quality Dimensions

| Dimension | Kiểm tra gì | Cách kiểm tra |
|-----------|-------------|---------------|
| **Completeness** | Mỗi section có >= 2 câu nội dung thực | Đếm sentences, loại trừ headers/bullets rỗng |
| **Consistency** | REQ-IDs trong feature specs = REQ-IDs trong registry | Cross-check sets: registry ∩ docs = docs |
| **Traceability** | Feature → REQ-ID → Code file → Test file | Chain verification: mỗi link tồn tại |
| **Coherence** | Docs cùng phase không mâu thuẫn | So sánh data points giữa docs (vd: module count, dept names) |
| **Freshness** | Docs reflect latest registry state | Timestamp check + field comparison |

## 8.3 Inter-Phase Consistency Check

```
SAU MỖI PHASE HOÀN THÀNH:
1. Đọc output docs của phase hiện tại
2. Đọc output docs của phase trước đó
3. Verify:
   a. SỐ LƯỢNG: Số modules/features/REQ-IDs khớp giữa phases
   b. TÊN: Tên modules/features/systems giống nhau (case-insensitive)
   c. SCOPE: Phase sau KHÔNG mở rộng scope ngoài phase trước
   d. REFERENCES: Cross-refs đến docs phase trước đúng path

NẾU KHÔNG KHỚP:
- Log chi tiết mismatch (expected vs actual)
- Auto-fix nếu chỉ là naming inconsistency
- ESCALATE nếu scope mismatch (phase sau có nhiều hơn phase trước)
```

## 8.4 Content Scoring (optional, cho audit)

```
Mỗi doc nhận điểm 0-100:

completeness_score = (filled_sections / total_sections) * 40
consistency_score  = (matching_refs / total_refs) * 30
traceability_score = (traceable_items / total_items) * 20
coherence_score    = (non_conflicting / total_checks) * 10

total = completeness_score + consistency_score + traceability_score + coherence_score

PASS: >= 80 | WARN: 60-79 | FAIL: < 60
```

## 8.5 CQG Registry — Canonical Quality Gate IDs

> **Lưu ý:** Phần này trước đây là §13.5 trong shared-protocols.md (numbering bug — placed before §12-13).
> Refactor đã chuyển vào §8.5 (sub-section của Protocol 8) cho đúng hierarchy.

> Danh sách chính thức các Content Quality Gate IDs sử dụng trong DEVKIT.
> Mỗi skill tham chiếu CQG-ID khi áp dụng Content Quality Gate (Protocol 8).

| CQG-ID | Scope | Mô tả | Skills sử dụng |
|--------|-------|-------|----------------|
| CQG-01 | Phase 1 completeness | Business docs đầy đủ, non-placeholder | wf-analyze-requirements |
| CQG-02 | Phase 1 cross-dept | Cross-department workflow consistency | wf-analyze-requirements |
| CQG-03 | Phase 2 feature specs | Feature specs đầy đủ, REQ-IDs traceable | wf-define-features |
| CQG-04 | Phase 2 registry sync | Features trong docs khớp registry | wf-define-features |
| CQG-05 | Phase 3 architecture | Architecture docs đầy đủ, consistent | wf-design |
| CQG-05.1 | API contract | API endpoints khớp features | wf-design |
| CQG-05.2 | DB schema | Tables/relationships khớp data model | wf-design |
| CQG-05.3 | Integration | Integration specs khớp architecture | wf-design |
| CQG-06 | Phase 3 stakeholder | Architecture review findings resolved | wf-design |
| CQG-07 | Phase 4 design system | Design system tokens đầy đủ | wf-design-ux |
| CQG-08 | Phase 4 navigation | Navigation specs khớp features | wf-design-ux |
| CQG-09 | Phase 4 screens | Screen groups đầy đủ, khớp features | wf-design-ux |
| CQG-10 | Phase 5 impl | Code implement đúng specs | wf-implement-feature |
| CQG-11 | Phase 6 deployment | Deployment docs đầy đủ | wf-prepare-deployment |
| CQG-12 | Verify sync | Sync rate tính đúng, gap list đầy đủ | wf-verify-sync |
| CQG-13 | Phase 2 UI coverage (legacy) | UI screens matched to features, gaps identified | wf-define-features (Phase 2.7) |
| CQG-14 | Post-impl UI verify | Code UI screens vs features[], both directions | wf-verify-sync (Phase 5b) |
| CQG-15 | Fix execute content quality | fixed_count accuracy, escalated_count match, score delta >=0, issue ID completeness, runtime re-verify, button re-test | wf-fix-execute (Phase 5 steps 5.7-5.12) |

> **Sub-numbering convention:** CQG-05.1, CQG-05.2, CQG-05.3 thuộc base CQG-05 — dùng khi cần granular check trong 1 phase.
> **Next available ID:** CQG-16
