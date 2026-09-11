# Phase 3: Brainstorm & Phân Tích Chính Sách (TỰ ĐỘNG)

> **Giai đoạn tự động** — KHÔNG hỏi user.
> Domain experts brainstorm requirements + phân tích chính sách (conditional theo `project_complexity`).
> Working files → `.mc-data/work/wf-brainstorm/`. Kết quả cuối ghi thẳng ở Phase 4.

**PRE-GATE:**

- [ ] Phase 2 (phase2-ba-departments.md) POST-GATE PASS
- [ ] `active_depts[]` non-empty
- [ ] `project_complexity` ∈ {SIMPLE, STANDARD, ENTERPRISE}
- [ ] Nếu STANDARD/ENTERPRISE: `policy_status[]` non-empty

**INPUT:** Toàn bộ context Phase 1+2

**OUTPUT (working files trong `.mc-data/work/wf-brainstorm/`):**
- `brainstorm-notes.md`
- `policy-analysis.md` (STANDARD/ENTERPRISE only)
- `complexity-assessment.md`
- Context: `final_scope_context`, `compliance_analysis`, `final_policy_gaps[]`

---

## Reference Sections

- `_shared.md` §8 Agent Roles Per Phase
- `_shared.md` §9 Domain Expert Selection Workflow
- `_shared.md` §10 Expert Persona Prompt (CHỌN format theo `project_complexity`)
- `_shared.md` §11 Policy Agent-Responsible Mapping
- `_shared.md` §12 LEGACY_MODE Context Injection (nếu LEGACY)

---

## Step 3.0: Init Working Directory

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.0 | `mkdir -p .mc-data/work/wf-brainstorm` (đã tạo từ Phase 1, idempotent) → Thông báo: "Đội ngũ [N] chuyên gia đang brainstorm — vui lòng chờ..." | Bash + Output | Directory exists |

---

## Step 3.1: Resolve Experts

| Step | Hành động | Tool | Lưu vào context |
|------|-----------|------|-----------------|
| 3.1 | Resolve experts: `active_depts[]` → `domain-experts.md` §1 → union Primary + Supporting → dedup → so sánh §2 → `expert_list[]` | — | `expert_list[]` |

---

## Step 3.2a: Spawn Domain Experts (PARALLEL)

| Step | Hành động | Tool | Notes |
|------|-----------|------|-------|
| 3.2a | Spawn domain experts PARALLEL (`run_in_background: true`, batch 5 nếu > 5) — sử dụng Expert Persona Prompt phù hợp `project_complexity` (§10) | Agent (×N, background) | Outputs thu ở Step 3.3 |

> Nếu LEGACY_MODE: prompt PHẢI inject `$LEGACY_CONTEXT` + `legacy-decisions.json` (§12).

---

## Step 3.2b: (STANDARD/ENTERPRISE only) Spawn Legal + Compliance

| Step | Hành động | Tool | Notes |
|------|-----------|------|-------|
| 3.2b | _(STANDARD/ENTERPRISE only)_ Spawn `legal-expert` + `compliance-expert` PARALLEL (background) — phân tích tuân thủ pháp lý dựa trên `industry`, loại dữ liệu, thị trường → output cho P0-01 §5.1 | Agent (×2, background) | Outputs thu ở Step 3.3 |

> **SIMPLE:** SKIP — P0-01 §5.1 sẽ ghi "N/A — Dự án không yêu cầu phân tích tuân thủ"

---

## Step 3.3: Tổng Hợp Brainstorm Notes + Ghi Complexity Assessment

| Step | Hành động | Tool | Lưu vào context |
|------|-----------|------|-----------------|
| 3.3 | **Chờ tất cả background agents (3.2a + 3.2b) hoàn thành.** Thu toàn bộ outputs → spawn `business-analyst` tổng hợp: (1) tổng hợp yêu cầu/lo ngại/modules, (2) **extract `policy_expert_recommendations[]` từ section "Chính sách đề xuất" của từng expert** → lưu `brainstorm-notes.md` | Agent + Write | `brainstorm_notes`, `compliance_analysis`, `policy_expert_recommendations[]` |
| 3.3a | **BẮT BUỘC — ghi `complexity-assessment.md` cho TẤT CẢ complexity levels (bao gồm SIMPLE).** Nội dung: verdict `project_complexity` ∈ {SIMPLE, STANDARD, ENTERPRISE}, lý do cụ thể (keyword nào match, số active_depts[], business context), và hệ quả (có làm policy analysis hay không). Viết tiếng Việt có dấu, 1-2 trang. | Write | `complexity_assessment_written = true` |

### Format `brainstorm-notes.md`

```markdown
# Biên Bản Brainstorm — [Tên Công Ty]
**Ngày:** [date]
**Chuyên gia tham gia:** [N] experts

## Phòng [Tên] (chuyên gia [domain])
**Yêu cầu chính:**
- [Yêu cầu 1]
**Lo ngại:**
- [Lo ngại 1]
**Đề xuất ưu tiên:** [Module A], [Module B]
**Chính sách đề xuất:** _(STANDARD/ENTERPRISE only — để trống nếu SIMPLE)_
- [Tên chính sách] — Ưu tiên: [Bắt buộc/Nên có/Tùy chọn] — Lý do: [ngắn gọn]

---
## Phân Tích Tuân Thủ Pháp Lý
> Bởi legal-expert + compliance-expert
[Tóm tắt quy định áp dụng, yêu cầu cụ thể với dự án]
```

> **⚠️ BẮT BUỘC — Section "Phân Tích Tuân Thủ Pháp Lý":**
> Section này PHẢI là section **riêng ở cuối file** — KHÔNG được embed vào expert sections (legal-expert / compliance-expert) và KHÔNG được bỏ qua. BA agent tổng hợp phải extract kết quả từ legal-expert + compliance-expert rồi viết lại thành summary độc lập sau dấu `---` cuối cùng. Nếu legal/compliance sections đã được viết riêng trong file → vẫn phải có summary section này ở cuối.

> **⚠️ BẮT BUỘC — Terminology `complexity-assessment.md`:** Dùng đúng thang **3 mức** theo SKILL.md: `SIMPLE / STANDARD / ENTERPRISE`. **KHÔNG dùng** SMALL / MEDIUM / LARGE / Very Large hay bất kỳ thang nào khác.

---

## Step 3.3b: (STANDARD/ENTERPRISE only) Policy Gap Analysis

| Step | Hành động | Tool | Lưu vào context |
|------|-----------|------|-----------------|
| 3.3b | _(STANDARD/ENTERPRISE only)_ Spawn `business-analyst` → đọc `brainstorm-notes.md` (section "Chính sách đề xuất" của từng expert) + `policy_expert_recommendations[]` → cross-reference `policy_status[]` từ Phase 2 → identify final gaps → **assign `agent_responsible` cho từng policy** (theo §11) → lưu `policy-analysis.md` (complexity-assessment.md đã ghi ở 3.3a) | Agent + Write | `final_policy_gaps[]` |

### Format `policy-analysis.md` (STANDARD/ENTERPRISE)

```markdown
# Phân Tích & Đề Xuất Chính Sách — [Tên Công Ty]
**Mức phức tạp:** [STANDARD/ENTERPRISE]
**Ngày:** [date]

## Tổng Hợp Đề Xuất Từ Chuyên Gia

| # | Chính sách | Đề xuất bởi | Lý do | Ưu tiên | User đã có? |
|---|-----------|-------------|-------|---------|------------|
| 1 | [tên] | [agent] | [lý do] | Bắt buộc/Nên có/Tùy chọn | Đã có/Chưa có/Có 1 phần |

## Chính Sách Cần Xây Dựng (Final)
final_policy_gaps[] = user_gaps ∪ expert_recommended_gaps (dedup)

| # | Chính sách | Agent phụ trách | Nội dung cốt lõi |
|---|-----------|----------------|------------------|
```

### Working files structure

```
.mc-data/work/wf-brainstorm/
├── brainstorm-notes.md          ← Tổng hợp yêu cầu + lo ngại + modules từ experts
├── policy-analysis.md           ← (STANDARD/ENTERPRISE) Đề xuất chính sách + gap analysis
└── complexity-assessment.md     ← Kết quả phân loại project_complexity + lý do
```

---

## Step 3.4: Merge & Hand-off

| Step | Hành động | Tool | Lưu vào context |
|------|-----------|------|-----------------|
| 3.4 | Merge tất cả → `final_scope_context` → **tự động chuyển Phase 4** — không dừng lại | — | `final_scope_context` |

---

## Fallbacks (xem `_shared.md` §14 Fix Rules)

- **Fallback 3.2a:** Nếu `active_depts[]` không khớp `domain-experts.md` §1 → BA tự tổng hợp scope; log warning.
- **Fallback agent_fail:** BA tự tổng hợp; log warning, vẫn proceed.

---

## POST-GATE Phase 3

- T1: `test -f .mc-data/work/wf-brainstorm/brainstorm-notes.md && wc -c < brainstorm-notes.md > 200`
- T2: `test -f .mc-data/work/wf-brainstorm/complexity-assessment.md`
- T3: Nếu STANDARD/ENTERPRISE: `test -f .mc-data/work/wf-brainstorm/policy-analysis.md`
- T4: Context có `final_scope_context.modules[]` non-empty
- T5: Context có `compliance_analysis` (SIMPLE: "N/A"; STANDARD/ENTERPRISE: actual analysis)
- T6: Nếu STANDARD/ENTERPRISE: context có `final_policy_gaps[]`

> **STATUS-UPDATE(done: phase_3 → start: phase_4):** Update `brainstorm-status.json`:
> - `phases.phase_3.status = "done"`, `phases.phase_3.completed_at = NOW`
> - `current_phase = "phase_4"`, `phases.phase_4.status = "in_progress"`
> - `timestamps.last_updated = NOW`
> - `artifacts.brainstorm_notes.created = true`, `artifacts.complexity_assessment.created = true`
> - Nếu STANDARD/ENTERPRISE: `artifacts.policy_analysis.created = true`

---

## Next Phase

→ **`phase4-write-docs.md`** (Soạn & Ghi Tài Liệu — TỰ ĐỘNG)
