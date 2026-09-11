# 04 — Key Personas

> **Mức độ ràng buộc:** Tham khảo (overview)
> **Mục đích:** Bốn nhóm đối tượng dùng MCV3 — tài liệu, skill, agent thiết kế theo persona

---

## 1. Tại sao cần persona?

MCV3 phục vụ nhiều đối tượng có **nhu cầu khác nhau**:
- Chủ doanh nghiệp đọc Phase report tiếng Việt để vận hành
- Developer mở SKILL.md để debug workflow
- Reviewer audit PR để đảm bảo compliance
- Agent author tạo chuyên gia AI mới

Nếu thiết kế docs/skill theo "mọi người dùng giống nhau" → không ai vừa lòng. **Persona-driven design** chốt: mỗi tài liệu xác định rõ đối tượng đọc là ai → optimize cho persona đó.

---

## 2. Bốn personas chính

| Persona | Mục đích chính | Tài liệu chính đọc | Skill chính dùng |
|---------|---------------|---------------------|------------------|
| **P1. End User** (chủ doanh nghiệp / non-developer) | Biến ý tưởng thành phần mềm vận hành | `00-overview/`, `06-user-guides/`, Phase reports trong `.mc-data/docs/` | `/new-project`, `/wf-*` |
| **P2. Skill Author** (developer của MCV3) | Tạo/sửa skill workflow | `02-standards/`, `04-skill-design/`, `.claude/rules/` | Sửa file trong `.claude/skills/` |
| **P3. Agent Author** (developer agent + knowledge) | Tạo/sửa agent + knowledge files | `02-standards/03-agent-standard.md`, `04-skill-design/`, `.claude/agents/spec/` | Sửa file trong `.claude/agents/` |
| **P4. Auditor / Reviewer** (PR review, compliance) | Đảm bảo PR tuân thủ chuẩn | `02-standards/` (cả 12 file), `05-review-standards/`, audit scripts | `/audit-devkit`, `/audit-skill-output`, `/audit-agents` |

---

## 3. Persona 1 — End User

### 3.1. Profile

**Ai:**
- Chủ doanh nghiệp Việt Nam vừa và nhỏ
- Quản lý vận hành công ty xuất nhập khẩu / nhà hàng / phòng khám / ...
- KHÔNG có background kỹ thuật, KHÔNG biết code
- Có ý tưởng phần mềm nhưng không biết cụ thể cần gì

**Kỹ năng:**
- Hiểu nghiệp vụ doanh nghiệp của mình
- Đọc tiếng Việt nhanh, English chậm
- Sử dụng được tool (Claude Code) qua tutorial

**Frustration:**
- "AI làm gì tôi không hiểu, làm sao tin tưởng?"
- "Tôi không phân biệt được code đúng/sai"
- "Documents tiếng Anh quá nhiều thuật ngữ"

### 3.2. Goal khi dùng MCV3

```
1. Mô tả ý tưởng → DEVKIT brainstorm cùng
2. Đọc Phase reports (tiếng Việt) → tin tưởng AI đang đi đúng hướng
3. Xác nhận CDG khi được hỏi (Có/Không) → cảm thấy có kiểm soát
4. Nhận output cuối: source code + tài liệu vận hành
```

### 3.3. Tài liệu MCV3 thiết kế cho P1

- **Phase reports** (CORE-028) — Tiếng Việt ≤15 dòng, KHÔNG jargon
- **`huong-dan-su-dung.md`** — Hướng dẫn end-to-end
- **CDG messages** (Protocol 16 §16.4) — Tiếng Việt rõ ràng
- **Stakeholder review docs** trong mỗi phase
- **`.mc-data/docs/phase0-brainstorm/`** — Kết quả brainstorm dễ đọc
- **`/status` skill** — Dashboard tiến độ

### 3.4. Tài liệu KHÔNG cho P1

- Code (`.ts`, `.py`, `.sh`)
- `_contract.json` (schema technical)
- `.claude/rules/` (rules cho AI behavior)
- `02-standards/` (chuẩn ràng buộc cho developer)
- Stack traces, error codes raw

### 3.5. Quy tắc thiết kế cho P1

```
Quy tắc:
- Tiếng Việt 100%
- KHÔNG jargon: "POST-GATE" → "kiểm tra đầu ra"
- ≤15 dòng cho summary (không bắt user đọc 100 dòng)
- Hiển thị progress: "Đã xong 4/7 bước"
- Khi cần user quyết định: 2-4 options rõ ràng
- Tránh hiển thị technical detail trừ khi user yêu cầu
```

---

## 4. Persona 2 — Skill Author

### 4.1. Profile

**Ai:**
- Developer MCV3 contributor
- Hiểu Claude Code + Anthropic API
- Biết bash, jq, basic Python
- Đã đọc qua 38 CORE rules + 4 BHV principles

**Kỹ năng:**
- Read/write SKILL.md, `_contract.json`, procedure files
- Debug skill workflow qua session logs
- Hiểu schema versioning + cross-skill artifacts

**Frustration:**
- "12 file standards, đọc cái nào trước?"
- "Skill template có 500 dòng, làm sao biết bắt đầu từ đâu?"
- "Compliance audit fail mà không rõ vì sao"

### 4.2. Goal khi tạo/sửa skill

```
1. Đọc 02-standards/ (12 file) để hiểu chuẩn ràng buộc
2. Copy template workflow-skill.md → customize
3. Implement procedure files theo CORE-032 (lazy-load)
4. Định nghĩa _contract.json + outputs + cross-skill contracts
5. Test với compliance audit + manual run trên dự án thật
6. PR + đồng bộ docs/04-skill-design/{skill}/
```

### 4.3. Tài liệu MCV3 thiết kế cho P2

- **`02-standards/`** — 12 chuẩn ràng buộc (BẮT BUỘC đọc)
- **`02-skill-standard.md`** — Skill anatomy detailed
- **`04-contract-schema.md`** — `_contract.json` deep dive
- **`12-extension-checklist.md`** — Master checklist
- **`04-skill-design/_template/`** — 9 file template per skill
- **`.claude/skills/workflow-skill.md`** — Canonical template
- **`.claude/rules/00-core.md`** — 38 CORE rules
- **Case studies:** `04-skill-design/wf-fix-bugs/`, `wf-legacy-scan/`

### 4.4. Quy tắc thiết kế cho P2

```
Quy tắc:
- Teaching pattern: Pass/Fail examples thay vì chỉ định nghĩa
- Anti-patterns rõ ràng (bảng ❌/✅)
- Checklist tổng kết cuối mỗi standard
- Compliance audit script reference
- Cross-link tới case studies thực tế
- Code blocks dài OK (developer đọc)
```

---

## 5. Persona 3 — Agent Author

### 5.1. Profile

**Ai:**
- MCV3 contributor focus vào agents + knowledge
- Có expertise domain (vd: finance domain expert)
- Biết cấu trúc 5 teams + orchestrator
- Đã đọc `.claude/agents/spec/README.md`

**Kỹ năng:**
- Viết knowledge file 200-800 dòng chuyên sâu
- Định nghĩa agent frontmatter + triggers
- Hiểu 8-section spawn pattern (CORE-037)

**Frustration:**
- "Agent của tôi có spawn được không?"
- "Knowledge file của tôi có duplicate với file khác không?"
- "Agent output không match schema từ skill"

### 5.2. Goal khi tạo agent mới

```
1. Đọc 03-agent-standard.md
2. Đọc .claude/agents/spec/README.md
3. Quyết định: cần knowledge mới hay bổ sung knowledge file?
4. Quyết định: tạo agent mới hay extend agent có sẵn?
5. Tạo agent file + knowledge files + procedures
6. Test với 1 skill spawn agent này
7. Verify output spot-check (CORE-029)
```

### 5.3. Tài liệu MCV3 thiết kế cho P3

- **`02-standards/03-agent-standard.md`** — Agent anatomy
- **`.claude/agents/spec/README.md`** — Spec canonical
- **`.claude/agents/spec/agent-definition-template.md`** — Template
- **`.claude/agents/spec/knowledge-template.md`** — Knowledge template
- **`01-architecture/08-agents-catalog.md`** — Existing 62 agents
- **`.claude/references/team-expert/`** — 162 knowledge files reference
- **`03-design-patterns/05-agent-prompt-template.md`** — 8-section spawn pattern

### 5.4. Quy tắc thiết kế cho P3

```
Quy tắc:
- Chỉ rõ khi nào TẠO MỚI vs BỔ SUNG knowledge
- Knowledge file: 1 chủ đề chuyên sâu, không trùng lặp
- Agent definition: triggers + keywords rõ ràng (Claude auto-route)
- 8-section prompt template (CORE-037) bắt buộc
- 1 agent có thể có nhiều procedures (1 file = 1 task type)
```

---

## 6. Persona 4 — Auditor / Reviewer

### 6.1. Profile

**Ai:**
- PR reviewer của MCV3 repo
- Compliance officer / Senior engineer
- Biết toàn bộ rule + protocol
- Có quyền block merge

**Kỹ năng:**
- Đọc nhanh PR diff, focus impact
- Chạy audit scripts
- Phát hiện violation pattern thường gặp

**Frustration:**
- "PR sửa 1 file nhưng impact 5 skill khác"
- "Schema breaking change không bump version"
- "Output path đổi mà không sync Protocol 21"

### 6.2. Goal khi review PR

```
1. Đọc PR description + ADR (nếu có)
2. Chạy ./scripts/skill-compliance-audit.sh {skill}
3. Chạy ./scripts/validate-schema-sync.sh {skill}
4. Check Protocol 21 + 11-output-path-contract.md cập nhật chưa
5. Check breaking schema có bump version + migration_notes
6. Verify test coverage (evals/) cho thay đổi
7. Approve / Request changes / Block
```

### 6.3. Tài liệu MCV3 thiết kế cho P4

- **`02-standards/`** — Toàn bộ 12 file (audit criteria)
- **`05-review-standards/`** — Per-skill review checklist (43 files)
- **`12-extension-checklist.md`** — Pre-merge final checklist
- **Audit scripts:**
  - `.claude/scripts/skill-compliance-audit.sh`
  - `.claude/scripts/validate-schema-sync.sh`
  - `.claude/scripts/validate-pipeline-naming.sh`
- **Audit skills:** `/audit-devkit`, `/audit-agents`, `/audit-skill-output`

### 6.4. Quy tắc thiết kế cho P4

```
Quy tắc:
- Anti-patterns rõ ràng (table format)
- Checklist tổng kết per standard
- Manual checks documented
- Audit script invocation examples
- Block criteria (khi nào REQUEST_CHANGES)
- Exception path: ADR + signoff
```

---

## 7. Persona table — Matrix tài liệu

| Tài liệu | P1 End User | P2 Skill Author | P3 Agent Author | P4 Auditor |
|---------|:-----------:|:---------------:|:---------------:|:----------:|
| `00-overview/` | ✅ Primary | ✅ Background | ✅ Background | ✅ Background |
| `01-architecture/` | ⚠️ Optional | ✅ Primary | ✅ Primary | ✅ Primary |
| `02-standards/` | ❌ | ✅ Primary | ✅ Primary | ✅ Primary |
| `03-design-patterns/` | ❌ | ✅ Primary | ✅ Primary | ⚠️ Reference |
| `04-skill-design/` | ❌ | ✅ Primary | ⚠️ Reference | ✅ Primary |
| `05-review-standards/` | ❌ | ⚠️ Reference | ❌ | ✅ Primary |
| `06-user-guides/` | ✅ Primary | ⚠️ Reference | ⚠️ Reference | ⚠️ Reference |
| `07-operations/` | ⚠️ Optional | ⚠️ Reference | ❌ | ⚠️ Reference |
| `08-reference/` | ✅ Quick lookup | ✅ Quick lookup | ✅ Quick lookup | ✅ Quick lookup |
| Phase reports (`.mc-data/docs/`) | ✅ Primary | ⚠️ Debug | ❌ | ⚠️ Audit |
| `_contract.json` | ❌ | ✅ Primary | ⚠️ Reference | ✅ Primary |
| `.claude/rules/` | ❌ | ✅ Primary | ✅ Primary | ✅ Primary |

**Legend:**
- ✅ Primary: Đọc thường xuyên, content optimized cho persona này
- ⚠️ Reference: Đọc khi cần lookup
- ❌: Không cần đọc (hoặc không có quyền)

---

## 8. Khi sửa MCV3, hỏi: "Tôi đang viết cho persona nào?"

| Persona target | Pattern |
|---------------|---------|
| P1 End User | Tiếng Việt, ngắn, ví dụ business, không jargon |
| P2 Skill Author | Teaching: Pass/Fail, anti-patterns, checklist, code blocks dài OK |
| P3 Agent Author | Concept + 8-section spawn pattern + knowledge guidelines |
| P4 Auditor | Audit criteria, checklist, block conditions, exception paths |

**Test:** Đọc lại doc → nếu persona target không hiểu nội dung → rewrite.

---

## 9. Liên kết

- **Project overview:** [`01-project-description.md`](01-project-description.md)
- **Standards (cho P2/P4):** [`../02-standards/README.md`](../02-standards/README.md)
- **User guide (cho P1):** [`../huong-dan-su-dung.md`](../huong-dan-su-dung.md) (sẽ migrate sang `06-user-guides/` ở Wave 4)
- **Agent spec (cho P3):** [`.claude/agents/spec/README.md`](../../.claude/agents/spec/README.md)
- **Review checklist (cho P4):** [`../05-review-standards/`](../05-review-standards/) (sẽ scaffold ở Wave 3)
