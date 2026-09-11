<!--
_template_notes:
  purpose: Trả lời "Tại sao có skill này?" — vision + scope + non-goals + domain touch.
  populate:
    - §1 Tóm tắt: 2-3 câu mô tả vấn đề skill giải quyết
    - §2 Vấn đề trước khi có skill: hiện trạng + pain point (cụ thể, có ví dụ)
    - §3 Mục tiêu skill: 3-5 mục tiêu SMART (cụ thể, đo được)
    - §4 Nguyên tắc thiết kế: 4-6 principles dẫn dắt mọi quyết định trong skill
    - §5 Non-goals: tách rõ skill KHÔNG làm gì để tránh scope creep
    - §6 Tham chiếu: cross-link tới patterns/standards áp dụng
    - §7 Domain context (OPTIONAL — chỉ điền nếu skill chạm domain knowledge):
        liệt kê 24 domain experts/knowledge files được dùng + compliance phải tuân thủ
  độ dài tham khảo: 100-200 dòng (cộng thêm 30-60 dòng nếu có §7)
  bỏ §7 nếu skill thuần kỹ thuật, KHÔNG chạm `.claude/references/team-expert/`
-->

# 01 — Vision & Principles

> **Mục đích file:** Lý do tồn tại + scope + non-goals của skill `{skill-name}`.

---

## 1. Tóm tắt

`{skill-name}` giải quyết bài toán **{vấn đề chính}** bằng cách **{cách tiếp cận chính}**, trả về **{kết quả/deliverable}**.

---

## 2. Vấn đề trước khi có skill

| Hiện trạng | Pain point |
|------------|-----------|
| {Trạng thái cũ — không có skill, manual, hoặc skill cũ kém} | {Chi phí: thời gian, lỗi sai, không nhất quán} |
| ... | ... |

**Ví dụ cụ thể:** {1 case thực tế minh họa pain — VD: "Trước đây dev phải đọc 5 file để xác định REQ-ID nào đã code, mất 30 phút/lần."}

---

## 3. Mục tiêu skill (SMART)

| # | Mục tiêu | Đo bằng |
|---|----------|--------|
| 1 | {Cụ thể, hành động được} | {Metric} |
| 2 | {...} | {...} |
| 3 | {...} | {...} |

---

## 4. Nguyên tắc thiết kế

1. **{Tên nguyên tắc 1}** — {1-2 câu giải thích, ví dụ áp dụng}
2. **{Tên nguyên tắc 2}** — {...}
3. **{Tên nguyên tắc 3}** — {...}
4. **{Tên nguyên tắc 4}** — {...}

Ví dụ thực tế đã áp dụng các nguyên tắc trong [wf-fix-bugs vision](../wf-fix-bugs/01-vision-principles.md) hoặc [wf-legacy-scan vision](../wf-legacy-scan/01-vision-principles.md).

---

## 5. Non-goals (KHÔNG làm)

Để tránh scope creep, skill này **KHÔNG** xử lý:

- {Non-goal 1 — skill nào sẽ xử lý: VD "lint code → wf-implement-feature làm"}
- {Non-goal 2}
- {Non-goal 3}

---

## 6. Tham chiếu

- Patterns áp dụng:
  - [`../../03-design-patterns/01-lazy-load-procedures.md`](../../03-design-patterns/01-lazy-load-procedures.md) (nếu >3 phases)
  - {Patterns khác}
- Standards áp dụng:
  - [`../../02-standards/02-skill-standard.md`](../../02-standards/02-skill-standard.md)
  - {Standards khác relevant}
- Rules liên quan: CORE-{XXX}, BHV-{XXX}

---

## 7. Domain context (OPTIONAL — bỏ section này nếu skill thuần kỹ thuật)

> **Khi nào điền:** Skill đọc/ghi business rules, spawn domain expert agent, hoặc xử lý compliance theo ngành (healthcare, finance, logistics, ...).
> **Engine ánh xạ:** #14 Domain Graph + #15 Business Rule Inference — xem [`docs/01-architecture/10-mcv3-engines-overview.md`](../../01-architecture/10-mcv3-engines-overview.md) §1.

### 7.1 Domain experts được skill spawn

| Agent | Khi nào spawn | Knowledge file consume | Compliance phải kiểm |
|-------|---------------|------------------------|---------------------|
| `business-analyst` | Mọi phase business | `.claude/references/team-expert/business/*.md` | — |
| `healthcare-expert` | Module y tế | `.claude/references/team-expert/healthcare/*.md` | FDA/CE, EMR, BHYT |
| `finance-expert` | Module kế toán | `.claude/references/team-expert/finance/*.md` | Audit trail, GAAP/IFRS, hóa đơn điện tử |
| `logistics-expert` | Module logistics/XNK | `.claude/references/team-expert/logistics/*.md` | HS Code, Incoterms, VNACCS |
| {agent} | {điều kiện} | {file} | {standard} |

> Danh sách 24 domain experts đầy đủ: [`docs/01-architecture/08-agents-catalog.md`](../../01-architecture/08-agents-catalog.md) §business team. Compliance matrix per domain: [`.claude/rules/06-domain.md`](../../../.claude/rules/06-domain.md).

### 7.2 Knowledge graph touch points

| Touch point | Skill action | Risk nếu bỏ qua |
|-------------|--------------|----------------|
| Đọc `team-expert/{domain}/` | Inject vào agent prompt §3 Session context | Agent thiếu domain knowledge → output generic, miss compliance |
| Cross-domain conflict (vd: ecom + finance) | Trigger CDG khi 2 expert opinion lệch nhau | Silent contradiction trong requirements |
| Domain rule update | Skill phải re-read `team-expert/` mỗi session (no cache) | Stale rule → wrong output |

### 7.3 Domain compliance checklist

- [ ] Skill identify được domain từ context (registry `department`, project_type, hoặc explicit arg)?
- [ ] Spawn đúng `{domain}-expert` agent (xem bảng [`.claude/rules/06-domain.md`](../../../.claude/rules/06-domain.md))?
- [ ] Output references compliance standard cụ thể (PCI-DSS, GDPR, FDA, ...)?
- [ ] Phase report ghi rõ domain experts đã consult?

### 7.4 Anti-patterns

❌ Hard-code domain rules trong skill code (rule thay đổi → skill stale)
❌ Skip domain expert spawn "vì nhanh hơn" (vi phạm BHV-001 Think Before Coding)
❌ Aggregate output từ nhiều domain experts mà không CDG khi conflict
