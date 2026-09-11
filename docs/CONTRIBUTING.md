# CONTRIBUTING — Quy trình đóng góp MCV3

> **Đọc trước khi đóng góp:** [`00-overview/01-project-description.md`](00-overview/01-project-description.md), [`00-overview/02-positioning-priorities.md`](00-overview/02-positioning-priorities.md)
> **Mục đích:** Quy trình ngắn gọn cho contributor — pointer-heavy, không lặp lại chi tiết

---

## 1. Tôi muốn đóng góp gì?

Chọn 1 trong các loại đóng góp dưới đây → đọc tài liệu hướng dẫn tương ứng.

### 1.1. Tạo skill mới

**Đọc:**
- [`02-standards/12-extension-checklist.md`](02-standards/12-extension-checklist.md) §3 — Master Checklist
- [`02-standards/02-skill-standard.md`](02-standards/02-skill-standard.md) — Skill anatomy
- [`02-standards/04-contract-schema.md`](02-standards/04-contract-schema.md) — `_contract.json` schema

**Template:**
- [`.claude/skills/workflow-skill.md`](../.claude/skills/workflow-skill.md) — Canonical template
- `docs/04-skill-design/_template/` — 9 file template (sẽ tạo ở Wave 3)

**Case study:**
- `docs/04-skill-design/wf-fix-bugs/`
- `docs/04-skill-design/wf-legacy-scan/`

### 1.2. Sửa skill có sẵn

**Đọc:**
- [`02-standards/12-extension-checklist.md`](02-standards/12-extension-checklist.md) §4 — Surgical Checklist
- [`.claude/rules/00-behavioral.md`](../.claude/rules/00-behavioral.md) BHV-003 (Surgical Changes)

**Quy tắc:**
- Giữ nguyên output paths trừ khi đổi workflow
- Bump version khi đổi schema
- Update CẢ producer + consumer + Protocol 21 trong 1 PR

### 1.3. Tạo agent mới

**Đọc:**
- [`02-standards/03-agent-standard.md`](02-standards/03-agent-standard.md)
- [`02-standards/12-extension-checklist.md`](02-standards/12-extension-checklist.md) §6 — Tạo agent mới
- [`.claude/agents/spec/README.md`](../.claude/agents/spec/README.md)

**Template:**
- [`.claude/agents/spec/agent-definition-template.md`](../.claude/agents/spec/agent-definition-template.md)
- [`.claude/agents/spec/knowledge-template.md`](../.claude/agents/spec/knowledge-template.md)

### 1.4. Bổ sung Knowledge cho agent có sẵn

**Đọc:**
- [`02-standards/03-agent-standard.md`](02-standards/03-agent-standard.md) §4 — Knowledge files
- [`02-standards/12-extension-checklist.md`](02-standards/12-extension-checklist.md) §5

**Path:**
- `.claude/references/team-expert/{domain}/`

### 1.5. Sửa CORE rule / Protocol

**Quy trình:**
1. Mở Issue mô tả vấn đề
2. Viết ADR đề xuất (trong Issue hoặc draft PR)
3. Review + discussion
4. Update CẢ `.claude/rules/` + `docs/02-standards/` trong 1 PR
5. Reviewer signoff bắt buộc

### 1.6. Thêm error code

**Đọc:**
- [`02-standards/08-error-code-registry.md`](02-standards/08-error-code-registry.md)

**Quy trình:**
1. Check bảng §4 trong file trên → range nào free
2. Khai báo `errors{}` trong `_contract.json` của skill
3. Update bảng registry trong cùng PR

### 1.7. Sửa output path

**Đọc:**
- [`02-standards/11-output-path-contract.md`](02-standards/11-output-path-contract.md)
- [`.claude/skills/protocols/21-cross-skill-output-path-contract.md`](../.claude/skills/protocols/21-cross-skill-output-path-contract.md)

**Quy tắc 3-nơi-1-PR:**
1. `_contract.json` của producer + consumer
2. Protocol 21 (canonical)
3. `docs/02-standards/11-output-path-contract.md` §3

### 1.8. Bug fix

**Đọc:**
- [`.claude/rules/00-behavioral.md`](../.claude/rules/00-behavioral.md) BHV-003 — chỉ sửa đúng bug, không "improve" code xung quanh

**Quy trình:**
1. Reproduce bug trên dev environment
2. Viết test case fail trước (TDD)
3. Fix → test pass
4. Đăng ký regression test trong `evals/regression-tests/`

### 1.9. Cập nhật docs (`docs/`)

**Đọc:**
- File này (CONTRIBUTING)
- [`02-standards/10-language-policy.md`](02-standards/10-language-policy.md) — quy ước tiếng Việt

**Quy tắc:**
- Tiếng Việt 100% cho user-facing
- File `02-standards/{NN}-*.md` PHẢI có header + sections chuẩn (xem 2-3 file đã có làm mẫu)

---

## 2. Quy trình PR

### 2.1. Trước khi mở PR

- [ ] Đọc rule liên quan trong `.claude/rules/` + `docs/02-standards/`
- [ ] Test trên dự án thật (không phải fixture giả)
- [ ] Chạy compliance audit (xem §3 dưới)
- [ ] Update docs trong cùng PR (không tách PR riêng)
- [ ] Viết regression test cho bug fix

### 2.2. Khi mở PR

- [ ] Title rõ ràng: `feat:`, `fix:`, `refactor:`, `docs:`, `chore:` prefix
- [ ] Description có: WHAT + WHY (không chỉ WHAT)
- [ ] Link Issue/ADR liên quan
- [ ] Screenshots/output samples cho UI/output changes
- [ ] Reviewer: 1-3 người tùy size

### 2.3. Sau merge

- Update CHANGELOG.md nếu skill có version visible với user
- Update plan file trong `plans/` nếu có

---

## 3. Compliance audit

Chạy trước khi mở PR:

```bash
# Audit skill compliance (yêu cầu jq)
./.claude/scripts/skill-compliance-audit.sh {skill-name}
./.claude/scripts/skill-compliance-audit.sh --all

# Validate _contract.json schema sync
./.claude/scripts/validate-schema-sync.sh {skill-name}
./.claude/scripts/validate-schema-sync.sh --all

# Pipeline naming validation
./.claude/scripts/validate-pipeline-naming.sh
```

**Windows users (Git Bash hoặc PowerShell wrapper):**
```powershell
powershell -ExecutionPolicy Bypass -File .claude/scripts/run-devkit-bash.ps1 .claude/scripts/skill-compliance-audit.sh --all
```

---

## 4. Khi vi phạm chuẩn

| Tình huống | Hành động |
|-----------|-----------|
| PR vi phạm CORE → audit fail | Block merge, fix trong cùng PR |
| Skill có sẵn vi phạm khi sửa nhỏ | Cảnh báo, tạo follow-up issue |
| Cần ngoại lệ có lý do chính đáng | Viết ADR trong `04-skill-design/{skill}/08-tradeoffs-adr.md` + reviewer signoff |
| Phát hiện rule không phù hợp thực tế | Mở Issue đề xuất sửa rule + ADR |

---

## 5. Quy ước commit message

```
<type>: <subject ngắn gọn tiếng Việt>

<body chi tiết nếu cần>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

**Types:**
- `feat:` — tính năng mới
- `fix:` — sửa bug
- `refactor:` — refactor không đổi behavior
- `docs:` — chỉ sửa docs
- `test:` — chỉ sửa tests
- `chore:` — task hành chính (bump version, ...)
- `perf:` — tối ưu hiệu năng

---

## 6. Đọc trước khi đóng góp lần đầu

| Tôi cần biết | Đọc file |
|-------------|---------|
| MCV3 là gì? | [`00-overview/01-project-description.md`](00-overview/01-project-description.md) |
| Ưu tiên chất lượng vs tốc độ? | [`00-overview/02-positioning-priorities.md`](00-overview/02-positioning-priorities.md) |
| Thuật ngữ MCV3 | [`00-overview/03-glossary.md`](00-overview/03-glossary.md) |
| Persona tôi thuộc nhóm nào? | [`00-overview/04-key-personas.md`](00-overview/04-key-personas.md) |
| 38 CORE rules + 4 BHV | [`02-standards/01-core-rules-index.md`](02-standards/01-core-rules-index.md) |
| 12 chuẩn ràng buộc | [`02-standards/README.md`](02-standards/README.md) |
| Master checklist khi extension | [`02-standards/12-extension-checklist.md`](02-standards/12-extension-checklist.md) |

---

## 7. Liên kết quick

- **Issues:** [GitHub Issues](https://github.com/...)  ← (project owner thêm link)
- **Plans:** `plans/` — active improvement plans per skill
- **Audit skills:** `/audit-devkit`, `/audit-agents`, `/audit-skill-output`
- **Hooks reference:** `.claude/hooks/`
- **CHANGELOG:** [`../CHANGELOG.md`](../CHANGELOG.md)

---

## 8. Câu hỏi thường gặp

**Q: Tôi có thể tạo skill mới không cần SKILL.md ≤500 dòng được không?**
A: KHÔNG — CORE-032 bắt buộc lazy-load procedures. Logic thực thi vào `procedures/phase{N}-*.md`.

**Q: Skill nhỏ có cần POST-GATE T1→T4 đủ không?**
A: CÓ — CORE-012 không miễn trừ skill nào.

**Q: Tôi sửa output path mà chỉ update `_contract.json`, không sync Protocol 21?**
A: PR sẽ block — phải sync 3 nơi (xem §1.7 trên).

**Q: Tôi muốn skill output tiếng Anh thay vì tiếng Việt?**
A: Chỉ override khi `req-registry.json.locale = "en"`. Default phải tiếng Việt (CORE-005).

**Q: Tôi có thể skip phase trong workflow?**
A: KHÔNG — CORE-002 bắt buộc không skip. Chưa có output phase trước → KHÔNG chạy phase sau.

---

## 9. Liên kết documentation

- **Standards:** [`02-standards/`](02-standards/) — 12 chuẩn ràng buộc
- **Design patterns:** [`03-design-patterns/`](03-design-patterns/) — 11 patterns + ví dụ (Wave 2)
- **Skill design:** [`04-skill-design/`](04-skill-design/) — per-skill design canon (Wave 3)
- **Review standards:** [`05-review-standards/`](05-review-standards/) — per-skill review checklist (Wave 3)
- **CLAUDE.md** (root) — overview hiện tại cho Claude Code
- **AGENTS.md** (root) — quick reference contributors
