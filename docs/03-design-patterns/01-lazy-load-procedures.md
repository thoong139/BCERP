# 01 — Lazy-Load Procedures

> **Mức độ ràng buộc:** KHUYẾN NGHỊ MẠNH cho skill có >3 phases
> **Rule liên quan:** CORE-032
> **Khi nào dùng:** Skill có nhiều phase phức tạp, logic dài ≥1000 dòng nếu viết monolithic

---

## 1. Vấn đề pattern giải quyết

Trước v10.0, một số skill MCV3 dùng cấu trúc **monolithic**:

```
.claude/skills/workflow/wf-fix-bugs-OLD/
└── SKILL.md   ← 2500-3000 dòng (toàn bộ logic)
```

**Hệ quả:**
- Mỗi lần `/wf-fix-bugs` chạy → Claude load full SKILL.md → 60-80% context dùng để đọc skill
- Logic phase 1 và phase 7 nằm chung 1 file → khó debug
- Mỗi sửa nhỏ phải đọc lại toàn bộ
- Skill grow up đến limit không thể mở rộng

**Pattern lazy-load giải quyết:**
- `SKILL.md` chỉ là **routing hub** ≤500 dòng
- Logic chi tiết per phase nằm trong file riêng → **chỉ load khi cần**

---

## 2. Pattern definition

### 2.1. Cấu trúc folder

```
.claude/skills/workflow/{skill-name}/
├── SKILL.md                    ◀ ≤500 dòng (lean routing hub)
├── _contract.json
├── procedures/                 ◀ LAZY-LOAD execution logic
│   ├── _shared.md              ← Cross-cutting concerns (state, atomic write, error handling)
│   ├── phase1-init.md          ← PRE-GATE → Steps → POST-GATE → Report
│   ├── phase2-scan.md
│   ├── phase3-plan.md
│   ├── ...
│   ├── phaseN-verify.md
│   └── resume-status.md        ← --resume + --status handlers
├── templates/                  ◀ Output templates (Protocol 19)
├── evals/
└── scripts/                    ◀ Bash helpers
```

### 2.2. SKILL.md (≤500 dòng) chỉ chứa

1. Header + metadata
2. Arguments table
3. Phase routing map (bảng + Mermaid flow)
4. PRE-GATE / POST-GATE file contract table
5. Error codes quick lookup
6. Context budget thresholds
7. Cross-skill contract

**KHÔNG chứa:**
- Logic thực thi
- Bash script inline >10 dòng
- Tool call examples (đặt trong procedure)
- Long prose explanation

### 2.3. Procedure file structure (mỗi phase)

```markdown
# Phase {N}: {Tên phase}

**Đầu vào:** [file/state cần có]
**Đầu ra:** [file/state sẽ tạo]
**Auto-fix budget:** 3 retries

## PRE-GATE
| Check | Cách kiểm tra | Fail action |
|-------|--------------|-------------|

## Steps
| # | Mô tả | Tool | Output |
|---|------|------|--------|

## POST-GATE
| Tier | Check | Fail action |
|------|-------|-------------|

## Phase Report Template
```markdown
## Phase {N}: {Tên} — PASS|FAIL
... (CORE-028)
```
```

---

## 3. Case study — wf-fix-bugs v10.0

Trước v10.0:
```
SKILL.md: 2847 dòng
Mỗi /wf-fix-bugs load: ~80% context limit
```

Sau v10.0 (lazy-load):
```
SKILL.md: 332 dòng (routing hub)
procedures/_shared.md: 285 dòng (cross-cutting)
procedures/phase1-init.md: 197 dòng
procedures/phase2-scan.md: 234 dòng
procedures/phase3-plan.md: 142 dòng
procedures/phase4-find-bugs.md: 412 dòng
procedures/phase5-triage.md: 218 dòng
procedures/phase6-execute.md: 287 dòng
procedures/phase7-verify.md: 196 dòng
procedures/resume-status.md: 124 dòng

Khi /wf-fix-bugs chạy:
  - Init: load SKILL.md (332) + _shared.md (285) + phase1-init.md (197) = 814 dòng
  - Phase 4: chỉ load thêm phase4-find-bugs.md (412)
  - Tổng từng phase: ~600-1000 dòng (giảm 70%+ vs monolithic 2847)
```

**Lợi ích đo được:**
- Context per phase giảm 70%+
- Mỗi phase tự chứa đầy đủ logic → debug độc lập
- Thay đổi Phase 4 không ảnh hưởng Phase 1
- Lane agents spawn nhanh hơn (mỗi lane chỉ cần `phase4-find-bugs.md` + lane-specific file)

### 3.1. wf-legacy-scan v5.0 — case thứ 2

```
SKILL.md: ~480 dòng
procedures/_shared.md
procedures/stage0-detect.md
procedures/stage1-inventory.md
procedures/stage2-classify.md
procedures/stage3-extract.md
procedures/stage4-synthesize.md
procedures/resume-status.md
```

Tương tự pattern, scan dự án lớn 10K+ files giảm context bloat đáng kể.

---

## 4. Variations / Edge cases

### 4.1. Skill nhỏ ≤3 phases — không cần pattern này

```
.claude/skills/workflow/wf-diagram/
└── SKILL.md  ← 350 dòng, đủ logic (3 phases nhỏ)
```

Pattern này có overhead — không bắt buộc khi skill thật sự nhỏ.

### 4.2. Skill có dimension lanes — thêm subfolder

```
.claude/skills/workflow/wf-fix-bugs/
├── procedures/
│   ├── phase4-find-bugs.md
│   └── lanes/
│       ├── QD1-functional.md   ← Per-lane logic
│       ├── QD2-business.md
│       └── ...
```

Hoặc tách thành skill riêng (wf-fix-functional, wf-fix-business, ...) — wf-fix-bugs chọn approach này.

### 4.3. _shared.md là gì?

Cross-cutting concerns dùng chung mọi phase:
- State variables (SESSION_ID, SESSION_DIR, PROFILE)
- Atomic write pattern function
- Error handling defaults
- CI detection helper
- Phase report template generator
- Logging helpers

KHÔNG có logic phase-specific.

---

## 5. Anti-patterns

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| `SKILL.md` >500 dòng | Tách logic sang `procedures/` |
| Procedure file copy 100% nội dung _shared.md | Reference `_shared.md` — không duplicate |
| Inline bash 50+ dòng trong procedure | Delegate sang `scripts/{skill}/helper-*.sh` |
| Phase N procedure import Phase M procedure | Phase độc lập — chỉ qua state file (fix-status.json) |
| `SKILL.md` chứa step-by-step "do X, then Y" | Đó là procedure file's job |
| Procedure không có PRE-GATE/POST-GATE rõ ràng | Bắt buộc structure 4 sections (Header, PRE-GATE, Steps, POST-GATE) |
| `_shared.md` chứa phase-specific logic | _shared CHỈ cross-cutting |
| Lazy-load nhưng SKILL.md vẫn 1500 dòng | Đo bằng `wc -l SKILL.md` — phải ≤500 |

---

## 6. Checklist áp dụng

**Trước khi tạo skill mới >3 phases:**

- [ ] Copy template `.claude/skills/workflow-skill.md` (v3.0)
- [ ] Đặt `SKILL.md` cho routing hub (≤500 dòng)
- [ ] Tạo `procedures/_shared.md` cho cross-cutting
- [ ] Tạo `procedures/phase{N}-{name}.md` cho mỗi phase
- [ ] Tạo `procedures/resume-status.md` nếu skill multi-session
- [ ] Đảm bảo mỗi procedure có 4 sections (Header, PRE-GATE, Steps, POST-GATE)
- [ ] Phase Report Template (CORE-028) trong mỗi procedure
- [ ] Không nhúng bash >10 dòng inline → tách `scripts/`
- [ ] Đo `wc -l SKILL.md` ≤500
- [ ] Đo từng `procedures/phase*.md` ≤800 dòng (recommendation)
- [ ] Compliance audit: `./.claude/scripts/skill-compliance-audit.sh {skill}`

---

## 7. Liên kết

- **Standard chính:** [`../02-standards/02-skill-standard.md`](../02-standards/02-skill-standard.md)
- **Rule:** CORE-032 trong [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4i
- **Template:** [`.claude/skills/workflow-skill.md`](../../.claude/skills/workflow-skill.md) v3.0
- **Case studies:**
  - `.claude/skills/workflow/wf-fix-bugs/`
  - `.claude/skills/workflow/wf-legacy-scan/`
- **Related patterns:**
  - [`06-checkpoint-resume.md`](06-checkpoint-resume.md) — Resume cần pipeline state
  - [`05-agent-prompt-template.md`](05-agent-prompt-template.md) — Phase 4 spawn agents
