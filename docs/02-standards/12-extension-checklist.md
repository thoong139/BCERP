# 12 — Extension Checklist (BẮT BUỘC)

> **Mức độ ràng buộc:** BẮT BUỘC khi mở rộng MCV3
> **File gốc canonical:** Tổng hợp từ 01-11 trong thư mục này + [`.claude/skills/workflow-skill.md`](../../.claude/skills/workflow-skill.md)
> **Mục đích:** Hướng dẫn quyết định **khi nào tạo mới vs sửa cũ**, checklist toàn diện cho contributor

---

## 1. Decision tree — Tạo mới hay sửa cũ?

```
Bạn muốn mở rộng MCV3?
│
├─ Thêm tính năng cho workflow hiện có?
│   ├─ Có liên quan đến phase/skill đã tồn tại không?
│   │   ├─ CÓ → SỬA skill hiện có (xem §4 Sửa skill)
│   │   └─ KHÔNG → Đánh giá: có phải workflow mới (>3 phase)?
│   │       ├─ CÓ → TẠO skill mới (xem §3 Tạo skill mới)
│   │       └─ KHÔNG → Thêm phase vào skill phù hợp nhất
│   │
├─ Thêm chuyên gia domain mới?
│   ├─ Đã có agent nào cover được chưa?
│   │   ├─ CÓ → BỔ SUNG knowledge file (xem §5 Knowledge)
│   │   └─ KHÔNG → Đánh giá: domain có ≥10 file knowledge ý nghĩa?
│   │       ├─ CÓ → TẠO agent mới (xem §6 Tạo agent mới)
│   │       └─ KHÔNG → Bổ sung knowledge cho agent gần nhất
│   │
├─ Sửa rule hành vi?
│   └─ Mở Issue + ADR trước → review → update `.claude/rules/` + sync docs/02-standards/
│
├─ Sửa output path?
│   └─ BẮT BUỘC: update CẢ producer + consumer + Protocol 21 + 11-output-path-contract.md trong 1 PR
│
└─ Thêm error code?
    └─ Xem `08-error-code-registry.md` §9 — đăng ký namespace
```

---

## 2. Mind-map "What I want to do"

| Tôi muốn | Hành động chính | File cần đọc trước |
|---------|----------------|-------------------|
| Thêm phase mới cho skill | Sửa SKILL.md + thêm procedure file | [`02-skill-standard.md`](02-skill-standard.md) §4 |
| Đổi output schema | Bump version + viết migration_notes | [`04-contract-schema.md`](04-contract-schema.md) §9 |
| Thêm error code | Đăng ký namespace | [`08-error-code-registry.md`](08-error-code-registry.md) |
| Thêm CDG point | Đăng ký vào Protocol 16 + viết rejection behavior | [`05-quality-gates.md`](05-quality-gates.md) §4 |
| Thêm output path | Sync 3 nơi: Protocol 21 + `_contract.json` + bảng §3 11-output-path-contract.md | [`11-output-path-contract.md`](11-output-path-contract.md) §6 |
| Thêm registry field | Định nghĩa role (PRIMARY/SAFE-UPDATE/...) | [`06-safe-write-protocol.md`](06-safe-write-protocol.md) |
| Tạo skill mới | Copy template + theo §3 dưới | [`02-skill-standard.md`](02-skill-standard.md) §7 |
| Tạo agent mới | Copy template + theo §6 dưới | [`03-agent-standard.md`](03-agent-standard.md) §9 |
| Đổi REQ-ID format | Sửa CORE-003 + tất cả hooks + script audit | [`07-naming-conventions.md`](07-naming-conventions.md) §4 |
| Đổi tiếng (vi → en) | Sửa `req-registry.json.locale` + override phase reports | [`10-language-policy.md`](10-language-policy.md) §8 |

---

## 3. Tạo skill mới — Master Checklist

### Bước 1: Pre-design

- [ ] Đọc [`02-skill-standard.md`](02-skill-standard.md) toàn bộ
- [ ] Đọc 2 skill case study tương tự: `wf-fix-bugs` và `wf-legacy-scan`
- [ ] Tham chiếu CORE-032..039 trong [`01-core-rules-index.md`](01-core-rules-index.md)
- [ ] Tham chiếu workflow path: skill này nằm ở phase nào trong 7-phase model?
- [ ] Quyết định: cần multi-phase (≥3) hay single-purpose?
- [ ] **CORE-039 Pre-design:** Phác thảo Parallelization Strategy — phase nào có thể song song (lane parallel/wave/read-then-merge)? Phase nào bắt buộc sequential (linear dependency)? Ước lượng thời gian sequential vs parallel để justify

### Bước 2: Scaffold

- [ ] Copy template `.claude/skills/workflow-skill.md` → `.claude/skills/workflow/{skill}/SKILL.md`
- [ ] Tạo folder structure đầy đủ (xem [02-skill-standard.md §2](02-skill-standard.md))
  ```
  {skill}/
  ├── SKILL.md
  ├── _contract.json
  ├── procedures/
  │   ├── _shared.md
  │   ├── phase1-{name}.md
  │   ├── phase2-{name}.md
  │   └── resume-status.md
  ├── templates/
  ├── evals/
  │   └── evals.json
  └── scripts/  (optional)
  ```

### Bước 3: SKILL.md (≤500 dòng)

- [ ] Header: name, version, owner
- [ ] Arguments table (CLI flags)
- [ ] Phase routing map (bảng + Mermaid)
- [ ] PRE-GATE / POST-GATE file contract table
- [ ] Error codes quick lookup
- [ ] Context & checkpoint thresholds (CORE-038)
- [ ] **Parallelization Strategy (CORE-039)** — bảng phase-by-phase (Mode/Owner/Write scope/Lý do an toàn/Merge checkpoint); hoặc ghi rõ lý do nếu 100% sequential
- [ ] Cross-skill contract (orchestrates / produces_for / consumes_from)
- [ ] **Verify:** `wc -l SKILL.md` ≤ 500

### Bước 4: Procedure files (CORE-032)

- [ ] `_shared.md` — state variables, atomic write, error handling, CI detection
- [ ] `phase{N}-{name}.md` cho mỗi phase
  - [ ] Header (input, output, auto-fix budget)
  - [ ] PRE-GATE checks
  - [ ] Execution steps
  - [ ] POST-GATE T1→T4
  - [ ] Phase report template (CORE-028)
- [ ] `resume-status.md` cho `--resume` và `--status`

### Bước 5: `_contract.json` (CORE-036)

- [ ] `$schema: "skill-contract-v1"`
- [ ] `version` semver
- [ ] `prerequisites` với `forensic_validation` (CORE-011)
- [ ] `inputs[]` — args với type, default, description
- [ ] `procedure[]` — list procedure files
- [ ] `outputs.working[]` — mỗi file có `template` (CORE-031)
- [ ] `registry_scope.write_role` (CORE-006)
- [ ] `cross_skill_contracts` — orchestrates / produces_for / consumes_from
- [ ] `errors{}` — namespace đăng ký (xem [`08-error-code-registry.md`](08-error-code-registry.md))
- [ ] `code_intelligence` nếu cần CI integration (CORE-033)
- [ ] `evals` config

### Bước 6: Templates

- [ ] Mọi output trong `_contract.json.outputs.working[]` có template tương ứng
- [ ] Template tại `templates/{phase-prefix}/{file}.{ext}`
- [ ] Template có `_template_notes` (strip khi WRITE)
- [ ] Phase report template tiếng Việt ≤15 dòng (CORE-028)

### Bước 7: Evals

- [ ] `evals/evals.json` có ≥3 test cases
- [ ] (Optional) `evals/regression-tests/` cho bug coverage
- [ ] (Optional) `evals/e2e-large-codebase.test.sh` cho stress test
- [ ] `ci_workflow` reference trong `_contract.json`

### Bước 8: Scripts (optional)

- [ ] Mọi bash logic >20 dòng tách ra `scripts/{purpose}.sh`
- [ ] Scripts có comment header tiếng Việt
- [ ] Error messages → user: tiếng Việt
- [ ] Scripts có shebang `#!/bin/bash` + `set -euo pipefail`

### Bước 9: Naming + Path validation

- [ ] Folder + file lowercase-kebab-case (CORE-016)
- [ ] Output paths khớp Protocol 21 — update [`11-output-path-contract.md`](11-output-path-contract.md) §3 nếu thêm path mới
- [ ] Error codes nằm trong namespace của skill — update [`08-error-code-registry.md`](08-error-code-registry.md) §4

### Bước 10: Docs (đồng PR)

- [ ] Tạo `docs/04-skill-design/{skill}/` với 9 file từ `_template/`
- [ ] Tạo `docs/05-review-standards/{skill}.md` từ `_template-common.md`
- [ ] Update `docs/01-architecture/07-skills-catalog.md`
- [ ] Update `CLAUDE.md` nếu skill thêm vào workflow path chính

### Bước 11: Compliance audit

- [ ] `./.claude/scripts/skill-compliance-audit.sh {skill}` → PASS
- [ ] `./.claude/scripts/validate-schema-sync.sh {skill}` → PASS
- [ ] `./.claude/scripts/validate-pipeline-naming.sh` → không có vi phạm naming
- [ ] Manual: chạy thử skill trên dự án test, verify session structure

---

## 4. Sửa skill hiện có — Surgical Checklist

### Bước 1: Phân tích impact

- [ ] Đọc [BHV-003 Surgical Changes](../../.claude/rules/00-behavioral.md) — KHÔNG sửa thứ không cần
- [ ] Dùng GitNexus `impact()` (nếu có) để xem callers
- [ ] Xác định: thay đổi nội bộ hay breaking cho consumer?

### Bước 2: Giữ nguyên contract (mặc định)

- [ ] **GIỮ NGUYÊN** output paths trừ khi chủ ý đổi workflow
- [ ] **GIỮ NGUYÊN** PRE-GATE / POST-GATE markers
- [ ] **GIỮ NGUYÊN** registry_scope fields nếu không đổi role
- [ ] **GIỮ NGUYÊN** error code semantic (chỉ thêm code mới trong namespace)

### Bước 3: Khi đổi schema

- [ ] Bump version trong `_contract.json` (semver)
  - Major: breaking schema, đổi semantic
  - Minor: thêm field optional, thêm enum value
  - Patch: sửa lỗi typo, không đổi shape
- [ ] Viết `migration_notes` trong `_contract.json` (như `wf-legacy-scan` v5.0)
- [ ] Bump `$schema` artifact version nếu cross-skill (`fix-impact-v1` → `fix-impact-v2`)
- [ ] Consumer skills update PRE-GATE validate version mới
- [ ] Backward-compat trong 1 release (alias hoặc dual-write)

### Bước 4: Sửa output path

- [ ] Update `_contract.json.outputs.working[]`
- [ ] Update `cross_skill_contracts.produces_for{}`
- [ ] Update Protocol 21 (canonical)
- [ ] Update [`11-output-path-contract.md`](11-output-path-contract.md) §3
- [ ] Update consumer skills PRE-GATE
- [ ] **Tất cả trong 1 PR**

### Bước 5: Compliance + version bump

- [ ] `wc -l SKILL.md` ≤ 500 (CORE-032)
- [ ] Compliance audit PASS
- [ ] Schema sync PASS
- [ ] Update `version` trong SKILL.md + `_contract.json`
- [ ] Update `description` với changelog ngắn (như wf-fix-bugs v10.0)

---

## 5. Bổ sung Knowledge — Khi không tạo agent mới

- [ ] Xác định domain phù hợp: `.claude/references/team-expert/{domain}/`
- [ ] File mới ≤800 dòng, 1 chủ đề chuyên sâu
- [ ] Format: định nghĩa → ví dụ → liên kết tài liệu chính thức
- [ ] Tiếng Việt cho concepts/terminology địa phương
- [ ] English cho international standards
- [ ] KHÔNG duplicate code/executable — knowledge là reference
- [ ] Update README của domain folder nếu có

---

## 6. Tạo agent mới — Master Checklist

### Bước 1: Pre-design

- [ ] Đọc [`03-agent-standard.md`](03-agent-standard.md) toàn bộ
- [ ] Đọc `.claude/agents/spec/README.md`
- [ ] Xác định team: business / engineering / design / testing / review
- [ ] Đảm bảo: chưa có agent tương tự cover

### Bước 2: Scaffold

- [ ] Tạo file `.claude/agents/{team}/{agent-name}.md`
- [ ] Tên file kebab-case (CORE-016)
- [ ] Frontmatter:
  - `name` khớp tên file (không `.md`)
  - `description` có triggers + use cases + keywords
  - `tools` KHÔNG bao gồm `Agent`
- [ ] Content: Vai trò + Knowledge + Quy tắc + Output

### Bước 3: Knowledge files (nếu domain mới)

- [ ] Tạo folder `.claude/references/team-expert/{domain}/`
- [ ] Bổ sung ≥3 knowledge files
- [ ] README giới thiệu domain (optional)

### Bước 4: Procedures files (nếu cần per-task)

- [ ] Tạo folder `.claude/agents/procedures/{agent-name}/`
- [ ] 1 file = 1 task type
- [ ] Format: Inputs / Outputs / Quality gates / Step-by-step

### Bước 5: Spawn pattern (CORE-037)

- [ ] Test với 1 skill spawn agent này
- [ ] Agent prompt có đầy đủ 8 sections (xem [`03-agent-standard.md`](03-agent-standard.md) §6)
- [ ] Output spot-check (CORE-029) trước khi advance

### Bước 6: Docs

- [ ] Update `docs/01-architecture/08-agents-catalog.md`
- [ ] (Optional) `docs/04-skill-design/...` nếu agent dành riêng cho skill nào

### Bước 7: Compliance

- [ ] `./.claude/scripts/audit-agents/...` (nếu có) → PASS
- [ ] Manual: spawn agent trong test session, verify output schema

---

## 7. Khi nào TẠO MỚI vs MỞ RỘNG

### TẠO skill mới khi:

- Workflow phase mới không cover bởi skill nào
- Workflow >3 phase độc lập
- Vai trò hoàn toàn khác (vd: `wf-test-business-workflow` khác `wf-fix-bugs`)
- Output schema không chia sẻ với skill hiện có

### MỞ RỘNG skill có sẵn khi:

- Thêm dimension/lane (vd: QD12 mới cho `wf-fix-bugs`)
- Thêm phase nội bộ trong cùng workflow
- Thêm output mode (--quick, --deep)
- Thêm subargs hoặc opt-in flags

### TẠO agent mới khi:

- Domain hoàn toàn mới không có chuyên gia cover (vd: thêm "agriculture")
- Vai trò mới không khớp đội hiện có (rare)
- Workflow phase cần expert specialized chưa tồn tại

### BỔ SUNG knowledge khi:

- Domain đã có agent, chỉ cần thêm chiều sâu chuyên môn
- Compliance regulation mới (vd: thêm tax law update)
- Standard/protocol mới (vd: HL7 FHIR v5)

---

## 8. Khi vi phạm chuẩn (CORE/BHV)

| Tình huống | Hành động |
|-----------|-----------|
| PR mới vi phạm CORE → audit fail | Block merge, fix trong cùng PR |
| Skill có sẵn vi phạm khi sửa nhỏ | Cảnh báo, tạo follow-up issue |
| Cần ngoại lệ có lý do chính đáng | Viết ADR trong `04-skill-design/{skill}/08-tradeoffs-adr.md` + reviewer signoff |
| Phát hiện rule không phù hợp thực tế | Mở Issue đề xuất sửa rule, viết ADR, update `.claude/rules/` + sync `docs/02-standards/` trong 1 PR |

---

## 9. Pre-merge final checklist

**Trước khi mở PR:**

- [ ] Audit script PASS:
  ```bash
  ./.claude/scripts/skill-compliance-audit.sh --all
  ./.claude/scripts/validate-schema-sync.sh --all
  ./.claude/scripts/validate-pipeline-naming.sh
  ```
- [ ] Đã test trên dự án real (không phải fixture giả)
- [ ] Đã chạy regression tests cho skill liên quan
- [ ] Đã update docs trong cùng PR (không tạch PR docs riêng cho thay đổi `.claude/`)
- [ ] Đã viết test case mới nếu fix bug
- [ ] Đã cập nhật `CHANGELOG.md` (nếu skill có version visible với user)

**Trong PR:**

- [ ] Mô tả: WHAT + WHY (không chỉ WHAT)
- [ ] Link Issue/ADR liên quan
- [ ] Screenshots/output samples cho thay đổi UI/output format
- [ ] Reviewer 1-3 người tùy size PR

---

## 10. Anti-patterns — KHÔNG được làm khi mở rộng

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Tạo skill mới khi có thể thêm phase vào skill có sẵn | Đánh giá kỹ §2, ưu tiên mở rộng |
| Sửa output path mà không sync 3 nơi (Protocol 21 + `_contract.json` + bảng §3) | Update tất cả trong 1 PR |
| Tạo agent mới chỉ để có thêm knowledge | Bổ sung knowledge cho agent hiện có |
| Skip CORE-032 (lazy-load) cho skill >3 phase | Tách procedures/ ngay từ đầu |
| Schema breaking change không bump major | Bump major + viết migration_notes |
| Thêm field SAFE-UPDATE → ghi đè PRIMARY của skill khác | Tôn trọng `write_role` (CORE-006) |
| Hook chặn user mà không có thông báo tiếng Việt | Error message tiếng Việt + suggest fix |
| Skip POST-GATE T3-T4 vì "skill nhỏ không cần" | T1-T4 luôn bắt buộc (CORE-012) |
| PR docs tách riêng khỏi PR `.claude/` | Đồng bộ 1 PR (vi phạm sync sẽ kẹt) |
| Update rule mà không bump CORE-XX rule list | Sync `.claude/rules/00-core.md` + `docs/02-standards/01-core-rules-index.md` |

---

## 11. Liên kết

- **Skill standard:** [`02-skill-standard.md`](02-skill-standard.md)
- **Agent standard:** [`03-agent-standard.md`](03-agent-standard.md)
- **Contract schema:** [`04-contract-schema.md`](04-contract-schema.md)
- **Quality gates:** [`05-quality-gates.md`](05-quality-gates.md)
- **Safe-Write:** [`06-safe-write-protocol.md`](06-safe-write-protocol.md)
- **Naming:** [`07-naming-conventions.md`](07-naming-conventions.md)
- **Error codes:** [`08-error-code-registry.md`](08-error-code-registry.md)
- **Sessions:** [`09-session-checkpoint.md`](09-session-checkpoint.md)
- **Language:** [`10-language-policy.md`](10-language-policy.md)
- **Output paths:** [`11-output-path-contract.md`](11-output-path-contract.md)
- **CORE rules index:** [`01-core-rules-index.md`](01-core-rules-index.md)
- **Canonical workflow template:** [`.claude/skills/workflow-skill.md`](../../.claude/skills/workflow-skill.md)
- **Audit scripts:** `.claude/scripts/skill-compliance-audit.sh`, `validate-schema-sync.sh`, `validate-pipeline-naming.sh`
