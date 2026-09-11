# 10 — CDG Gate (Critical Decision Gate)

> **Mức độ ràng buộc:** BẮT BUỘC tại 13 điểm critical
> **Rule liên quan:** CORE-027
> **Protocol liên quan:** Protocol 16
> **Khi nào dùng:** User cần confirm quyết định critical (overwrite, scope change, high-risk fix)

---

## 1. Vấn đề pattern giải quyết

Có những quyết định trong workflow MCV3 mà:
- AI KHÔNG được tự quyết (impact lớn, irreversible)
- Cần user informed consent
- Phải lưu trail để audit

**Anti-pattern:**
- AI tự quyết → user surprised when see result
- AI hỏi mọi quyết định nhỏ → annoying
- AI hỏi nhưng không lưu trail → mất context

**Pattern giải quyết:**
- 13 CDG points đã định nghĩa (critical, đáng hỏi)
- User responds qua AskUserQuestion
- Decision lưu vào `decision-registry.global.json`
- Skill tiếp tục theo response

---

## 2. Pattern definition

### 2.1. CDG anatomy

```
CDG point reached
   ↓
Skill prepares:
  - Question (tiếng Việt, rõ ràng cho user không chuyên)
  - Options (3-4 options, mỗi option có short + detailed description)
  - Rationale (TẠI SAO câu hỏi này quan trọng)
  - Default option (recommended, nhưng user có thể không chọn)
   ↓
AskUserQuestion tool → UI hiển thị decision
   ↓
User selects option (hoặc nhập custom response)
   ↓
Skill:
  1. Append decision-registry.global.json
  2. Log to session-log.json
  3. Route execution theo user response
```

### 2.2. CDG question template

```markdown
## Quyết định cần xác nhận: {short title}

**Bối cảnh:**
{1-2 câu mô tả tình huống — tiếng Việt cho user không chuyên}

**Lý do hỏi:**
{TẠI SAO quyết định này critical — không reversible? scope lớn? impact compliance?}

**Lựa chọn:**

A) {Option name} (khuyến nghị)
   - {Hệ quả ngắn}
   - {Trade-off}

B) {Option name}
   - {Hệ quả ngắn}

C) Hủy / dừng

**Khuyến nghị mặc định:** A — {lý do}
```

### 2.3. 13 CDG points

| CDG | Skill | Tại sao critical |
|-----|-------|------------------|
| CDG-01 | wf-brainstorm | Chốt scope — không thể quay đầu |
| CDG-02 | wf-analyze-requirements | Chốt departments + experts — thay đổi sau = re-do Phase 1 |
| CDG-03 | wf-define-features | Chốt MVP list — feature freeze |
| CDG-04 | wf-design | Architecture style — không thể đổi monolith ↔ microservices dễ dàng |
| CDG-05 | wf-design-ux | Design system — visual identity |
| CDG-06 | wf-plan-modules | Sprint plan — schedule commitment |
| CDG-07 | wf-implement-feature | Pre-impl safety — overwrite existing code? |
| CDG-08 | wf-fix-bugs | Triage signature — fix scope correctness |
| CDG-09 | wf-fix-bugs | High-risk fix authorization (vd: DB migration) |
| CDG-10 | wf-fix-bugs | Auto-fix budget exhausted — continue/skip/cancel |
| CDG-11 | wf-fix-business-completeness | Enhancement suggestions (ACCEPT/REJECT) |
| CDG-12 | wf-manage-change | Confirm change impact scope |
| CDG-13 | wf-add-scope | Confirm append-only operation |

### 2.4. Decision registry entry

```json
{
  "decisions": [
    {
      "id": "DEC-2026-05-15-001",
      "timestamp": "2026-05-15T10:30:00+07:00",
      "skill": "wf-fix-bugs",
      "session_id": "2026-05-15-crm-payment-01",
      "phase": "Phase 4 — Find Bugs",
      "cdg_id": "CDG-10",
      "question": "Q1 lane timeout — cut loss hay extend timeout?",
      "options": [
        {"id": "A", "label": "Extend timeout +5min", "selected": false},
        {"id": "B", "label": "Cut loss, proceed with 9/10 lanes", "selected": false},
        {"id": "C", "label": "Restart with profile=quick", "selected": true}
      ],
      "user_response": "C",
      "user_rationale": "Sec lane đang phát hiện critical issue cần kết quả đầy đủ",
      "outcome": "Phase 4 restarted with quick profile"
    }
  ]
}
```

---

## 3. Case study — CDG-07 (wf-implement-feature pre-impl safety)

**Scenario:**
```
User chạy /wf-implement-feature FEAT-CRM-CUST-001
   ↓
Phase 0.5b: Pre-Implementation Safety Gate
   ↓
Skill search code hiện tại:
  - Serena.find_definition("createCustomer")
  - Result: src/crm/customer/create.ts (đã tồn tại, 145 dòng code)
```

**CDG-07 triggered:**
```markdown
## Quyết định cần xác nhận: Code cho FEAT-CRM-CUST-001 đã tồn tại

**Bối cảnh:**
Tôi tìm thấy code có sẵn cho feature "Tạo khách hàng":
- File: src/crm/customer/create.ts (145 dòng)
- Function: createCustomer()
- Tests: src/crm/customer/__tests__/create.test.ts (3 test cases)
- Last modified: 2026-04-20

**Lý do hỏi:**
Implement mới có thể GHI ĐÈ code đang chạy production. Cần xác nhận chiến lược.

**Lựa chọn:**

A) **VERIFY_ONLY** (khuyến nghị)
   - Đọc code hiện tại, verify đúng spec
   - KHÔNG sửa code
   - Update impl_status=done nếu match

B) **COMPLETE_EXISTING**
   - Code có sẵn nhưng có gaps so với spec
   - Bổ sung missing parts, GIỮ working code
   - Risk: thay đổi behavior

C) **IMPLEMENT_NEW** (NGUY HIỂM)
   - Ghi đè toàn bộ code hiện tại
   - Mất working code + tests
   - Chỉ chọn nếu code cũ broken

**Khuyến nghị mặc định:** A — bảo vệ working code
```

**User selects A:**
```
→ Skill route Phase 1 với strategy=VERIFY_ONLY
→ Log DEC-2026-05-15-002 vào decision-registry
→ Continue without overwriting
```

---

## 4. Variations / Edge cases

### 4.1. `--auto` flag bypass

```
User chạy /wf-fix-bugs --auto
   ↓
Skill bỏ qua CDG-08 (triage), tự chọn default options
→ Log decisions với rationale="auto-mode"
→ User phải đồng ý risk trước qua arg
```

KHÔNG mọi CDG có thể bypass — vd CDG-07 (overwrite code) BẮT BUỘC.

### 4.2. Custom response

User có thể nhập text thay vì chọn A/B/C:
```
Question: "Continue or skip lane QD3?"
User response: "Re-run với scope hẹp hơn (chỉ /api/payment)"
   ↓
Skill phải interpret + route accordingly
→ Log custom_response field
```

### 4.3. Multi-step CDG

Một số CDG là chuỗi câu hỏi:
```
CDG-04 (Architecture style):
  Q1: Monolith hay Microservices?
  Q2 (if microservices): Bao nhiêu services?
  Q3 (if microservices): Service mesh nào?
```

Skill phải handle multi-step gracefully (mỗi step lưu DEC riêng).

### 4.4. CDG timeout

```
User không response trong 30 phút
   ↓
Default action: CANCEL (an toàn nhất)
→ Skill stop, lưu state, output: "User không response, đã hủy. /wf-X --resume để tiếp tục."
```

---

## 5. Anti-patterns

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| CDG question viết tiếng Anh | Tiếng Việt cho user-facing |
| CDG không có "Lý do hỏi" | Phải có rationale |
| Default option nguy hiểm (CDG-07 → IMPLEMENT_NEW) | Default = an toàn nhất |
| Quá nhiều CDG (mỗi tool call hỏi 1 lần) | Chỉ 13 critical points |
| CDG không lưu decision-registry | Bắt buộc lưu (Protocol 12) |
| Skill tự bypass CDG khi không có `--auto` | KHÔNG được |
| Options vague ("Yes/No" không rõ hệ quả) | Mỗi option có hệ quả ngắn + trade-off |
| CDG-07 không show preview code đang ghi đè | Phải show diff hoặc summary |
| Decision log không có session_id | Cần trace per session |
| Quá nhiều options (>5) | Max 4 options + Cancel |

---

## 6. Checklist áp dụng

**Khi thêm CDG mới:**

- [ ] Tình huống đáng hỏi: impact lớn / irreversible / compliance issue
- [ ] CDG ID đăng ký vào Protocol 16
- [ ] Question template: bối cảnh + lý do hỏi + options + default
- [ ] Tiếng Việt
- [ ] Options max 4 + Cancel
- [ ] Default option = an toàn nhất
- [ ] Decision lưu vào `decision-registry.global.json` với schema
- [ ] Log to session-log.json (event: CDG)
- [ ] Test eval: simulate user responses → verify routing
- [ ] Document trong SKILL.md (CDG-XX khi nào trigger)
- [ ] Bypass condition (vd: `--auto`) document rõ

---

## 7. Liên kết

- **Protocol 16 (canonical):** [`.claude/skills/protocols/16-critical-decision-gate.md`](../../.claude/skills/protocols/16-critical-decision-gate.md)
- **Protocol 12 (Decision Registry):** [`.claude/skills/protocols/12-decision-registry.md`](../../.claude/skills/protocols/12-decision-registry.md)
- **Rule:** CORE-027 trong [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md)
- **Hook:** `.claude/hooks/validate-critical-decision.sh`
- **Standard:** [`../02-standards/05-quality-gates.md`](../02-standards/05-quality-gates.md) §CDG section
- **Related patterns:**
  - [`05-agent-prompt-template.md`](05-agent-prompt-template.md) — Agent KHÔNG được tự CDG
