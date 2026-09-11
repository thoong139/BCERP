# 03 — Glossary (Bảng thuật ngữ)

> **Mức độ ràng buộc:** Tham khảo
> **Mục đích:** Định nghĩa các thuật ngữ chính dùng xuyên suốt MCV3 — đọc khi gặp từ lạ trong docs/SKILL.md

---

## Cách dùng

- Sắp xếp theo alphabet (English) hoặc nhóm chủ đề
- Mỗi thuật ngữ: định nghĩa ngắn + ví dụ + link tới tài liệu chi tiết

---

## A

### Agent

**Định nghĩa:** Chuyên gia AI ảo trong MCV3, được Skill spawn để thực thi task chuyên môn (analysis, design, code, review).

**Khác với Skill:** Skill là orchestrator, Agent là chuyên gia. Skill spawn Agent qua `Agent` tool với `subagent_type`.

**Ví dụ:** `business-analyst`, `architect`, `security`, `finance-expert`

**Tài liệu:** [`02-standards/03-agent-standard.md`](../02-standards/03-agent-standard.md)

### APPEND-only

**Định nghĩa:** File chỉ được thêm entries mới, không sửa/xóa entries cũ.

**Ví dụ:** `session-log.json`, `error-ledger.json`, `_index/sessions.jsonl`, `fix-history.md`

**Quy tắc:** KHÔNG đọc lại làm input context (CORE-026 output-only).

### Atomic Write

**Định nghĩa:** Pattern ghi file an toàn: build vào tmp → validate → mv tmp target.

**Mục đích:** Tránh partial write làm file invalid khi process bị crash giữa chừng.

**Ví dụ:**
```bash
echo "$content" > file.tmp.$$
jq '.' file.tmp.$$ > /dev/null || { rm file.tmp.$$; exit 1; }
mv file.tmp.$$ file
```

### Audit chain

**Định nghĩa:** Field `audit_chain` trong cross-skill artifact ghi nguồn gốc + checksum của state file mà artifact derived từ.

**Cấu trúc:**
```json
"audit_chain": {
  "source": "$SESSION_DIR/fix-status.json",
  "checksum": "sha256:..."
}
```

**Mục đích:** Consumer biết artifact dựa trên state nào → verify tính nhất quán.

### Auto-fix Budget

**Định nghĩa:** Số lần retry tối đa cho mỗi phase khi POST-GATE fail. CORE-034 chốt max = 3 retries/phase.

**Flow:**
```
POST-GATE FAIL → AUTO-FIX 1 → FAIL → AUTO-FIX 2 → FAIL → AUTO-FIX 3 → FAIL → ESCALATE
```

---

## B

### BHV (Behavioral Principle)

**Định nghĩa:** 4 nguyên tắc hành vi (BHV-001 → BHV-004) áp dụng cho mọi agent + skill MCV3.

| ID | Nguyên tắc |
|----|-----------|
| BHV-001 | Think Before Coding |
| BHV-002 | Simplicity First |
| BHV-003 | Surgical Changes |
| BHV-004 | Goal-Driven Execution |

**Tài liệu:** [`.claude/rules/00-behavioral.md`](../../.claude/rules/00-behavioral.md)

---

## C

### CDG (Critical Decision Gate)

**Định nghĩa:** Gate trong khi execution, hỏi user trước khi làm hành động không-undo.

**13 CDG points hiện tại** (CDG-01 → CDG-13). Ví dụ: CDG-02 (overwrite file), CDG-03 (downgrade `impl_status`).

**Quy tắc:** User REJECT → tuân thủ rejection behavior. Anti-loop: max 2 reject/CDG-id.

**Tài liệu:** [`02-standards/05-quality-gates.md`](../02-standards/05-quality-gates.md) §4

### CI (Code Intelligence)

**Định nghĩa:** Tools phát hiện và phân tích code structure — GitNexus + Serena.

**Vai trò:**
- GitNexus: impact analysis, execution flows, API routes (cross-file)
- Serena: find definition, find references, rename symbol (symbol-level)

**Pattern:** CI PRE-GATE Na/Nb/Nc + CI-ROUTE matrix với graceful degradation Grep/Glob.

**Tài liệu:** [`.claude/skills/protocols/20-code-intelligence.md`](../../.claude/skills/protocols/20-code-intelligence.md)

### Checkpoint

**Định nghĩa:** Snapshot state file để resume session sau khi interrupt.

**Triggers:**
- Context budget > 65% → chuẩn bị checkpoint
- Context budget > 80% → save checkpoint + stop sau phase hiện tại
- Context budget > 90% → FORCE STOP (E009)

**Tài liệu:** [`02-standards/09-session-checkpoint.md`](../02-standards/09-session-checkpoint.md)

### CORE rule

**Định nghĩa:** 38 quy tắc cốt lõi (CORE-001 → CORE-038) áp dụng cho mọi dự án trên MCV3.

**Ví dụ:**
- CORE-001: Đọc registry trước khi code
- CORE-004: Registry là SSOT
- CORE-032: Lazy-load procedures (SKILL.md ≤500 dòng)

**Tài liệu:** [`02-standards/01-core-rules-index.md`](../02-standards/01-core-rules-index.md)

### Cross-skill artifact

**Định nghĩa:** File được skill A sản xuất + skill B consume. Phải có `$schema` + `audit_chain`.

**Ví dụ:** `fix-impact.json` (wf-fix-bugs → wf-verify-sync), `change-impact.json` (wf-manage-change → wf-preflight).

**Tài liệu:** [`02-standards/04-contract-schema.md`](../02-standards/04-contract-schema.md) §8

---

## D

### DEVKIT

**Định nghĩa:** Tên thân thiện của MCV3 — bộ công cụ phát triển phần mềm trên Claude Code.

**Equivalent:** DEVKIT = MCV3 = "Master Claude V3"

### Domain expert

**Định nghĩa:** Agent chuyên gia 1 lĩnh vực nghiệp vụ (Finance, Healthcare, Logistics, ...). 24 domain experts trong team Business.

**Tài liệu:** [`.claude/agents/business/`](../../.claude/agents/business/), knowledge tại [`.claude/references/team-expert/`](../../.claude/references/team-expert/)

---

## E

### Error code

**Định nghĩa:** Mã lỗi format `E{NNN}[suffix]` (vd: `E001`, `E090b`) trong namespace per-skill phase-based.

**Namespace:**
- E001-E009: Shared
- E010-E019: Phase 1
- E020-E029: Phase 2
- ... (mỗi phase 10 codes)
- E090-E099: CDG
- E100-E109: Warnings

**Tài liệu:** [`02-standards/08-error-code-registry.md`](../02-standards/08-error-code-registry.md)

---

## F

### FEAT-ID

**Định nghĩa:** Feature identifier với format `FEAT-[SYSTEM]-[MODULE]-[NNN]`.

**Ví dụ:** `FEAT-CRM-CUST-001`

**Tài liệu:** [`02-standards/07-naming-conventions.md`](../02-standards/07-naming-conventions.md) §4

### Forensic PRE-GATE

**Định nghĩa:** PRE-GATE kiểm tra **content** (headings, words, markers) thay vì chỉ file existence (CORE-011).

**Vì sao:** File rỗng `{}` PASS `test -f` nhưng phase này consume vẫn fail.

---

## G

### Gate (PRE-GATE / POST-GATE / CDG)

**3 loại gate:**

| Gate | Khi | Mục đích |
|------|-----|----------|
| PRE-GATE | Đầu phase | Check input file/state có đầy đủ không |
| POST-GATE | Cuối phase | Check output T1 (exists) → T2 (structure) → T3 (content) → T4 (cross-ref) |
| CDG | Giữa execution | Hỏi user trước hành động không-undo |

**Tài liệu:** [`02-standards/05-quality-gates.md`](../02-standards/05-quality-gates.md)

---

## I

### `impl_status`

**Định nghĩa:** Field trong `req-registry.json.requirements[].impl_status` — trạng thái triển khai của REQ-ID.

**4 giá trị (CORE-010):**
- `not_started` (default)
- `in_progress`
- `done`
- `skipped` (chỉ DEPRECATE modules)

**Quy tắc CORE-008:** KHÔNG downgrade từ `done` → giá trị khác.

---

## L

### LEGACY_MODE

**Định nghĩa:** Chế độ skill detect dự án đã có code (legacy) qua check `project-context.md > 500 bytes`.

**Skill detection (CORE-021):**
```
LEGACY_MODE = test -f .mc-data/work/legacy-scan/project-context.md && size > 500 bytes
```

**Khi LEGACY_MODE:**
- Shared skills (wf-brainstorm, wf-analyze-requirements, ...) inject context
- DEPRECATE modules bị loại khỏi downstream output

### Lazy-load procedures (CORE-032)

**Định nghĩa:** Pattern SKILL.md là lean routing hub ≤500 dòng, logic thực thi trong `procedures/phase{N}-{name}.md` chỉ đọc khi tới phase.

**Lợi ích:** Giảm 70%+ context so với monolithic SKILL.md.

**Tài liệu:** [`02-standards/02-skill-standard.md`](../02-standards/02-skill-standard.md)

---

## M

### MCV3

**Định nghĩa:** Master Claude V3 — codename của DEVKIT. Phiên bản thứ 3 của hệ thống.

### `.mc-data/`

**Định nghĩa:** Thư mục data của DEVKIT khi chạy trên dự án thật. Chứa docs, work artifacts, registry.

**Cấu trúc:** xem [`02-standards/11-output-path-contract.md`](../02-standards/11-output-path-contract.md) §2

---

## O

### Orchestrator

**Định nghĩa:**
- **Agent orchestrator:** `.claude/agents/orchestrator.md` — điều phối giữa các đội agents
- **Skill orchestrator:** Skill spawn sub-skills (vd: wf-fix-bugs orchestrate wf-fix-triage + wf-fix-execute)
- **Workflow orchestrator:** Meta-skill chạy full workflow (vd: `/new-project`)

---

## P

### Phase 0-6

**Định nghĩa:** 7 phases trong DEVKIT workflow.

| Phase | Tên |
|-------|-----|
| 0 | Brainstorm |
| 1 | Business Requirements |
| 2 | Feature Definition |
| 3 | Architecture |
| 4 | UX/UI (conditional) |
| 5 | Implementation |
| 6 | Deployment |

**Tài liệu:** [`01-project-description.md`](01-project-description.md) §4

### Phase report (CORE-028)

**Định nghĩa:** Báo cáo cuối phase, tiếng Việt, ≤15 dòng, cho người không chuyên.

**Path:** `$SESSION_DIR/phase{N}-{name}/Phase{N}-report.md`

### Protocol

**Định nghĩa:** Tài liệu shared rules trong `.claude/skills/protocols/`. Có 22 protocols (01-22).

**Ví dụ:**
- Protocol 5: Registry Safe-Write
- Protocol 10: POST-GATE Schema
- Protocol 16: CDG
- Protocol 21: Cross-Skill Output Path Contract

---

## R

### Registry (`req-registry.json`)

**Định nghĩa:** Single Source of Truth của dự án, chứa systems/modules/requirements/features.

**Path:** `.mc-data/docs/_meta/req-registry.json`

**Quy tắc:** Safe-Write (CORE-006), 1 field = 1 PRIMARY owner.

### REQ-ID

**Định nghĩa:** Requirement identifier với format `REQ-[DEPT]-[NNN]` hoặc `REQ-[SYSTEM]-[MODULE]-[NNN]`.

**Ví dụ:** `REQ-SALES-001`, `REQ-CRM-CUST-001`

### Resume

**Định nghĩa:** Tiếp tục session đang dở với `--resume` flag. Skill đọc checkpoint + state file + inject digest.

**Tài liệu:** [`02-standards/09-session-checkpoint.md`](../02-standards/09-session-checkpoint.md) §7

---

## S

### Safe-Write Protocol (CORE-006)

**Định nghĩa:** Mỗi skill chỉ update đúng fields được phân công trong `req-registry.json`. 7 roles: PRIMARY/SEED/APPEND/SAFE-UPDATE/FIX-INVALID/UPDATE-MODE/NONE.

**Tài liệu:** [`02-standards/06-safe-write-protocol.md`](../02-standards/06-safe-write-protocol.md)

### Session

**Định nghĩa:** Một lần chạy skill, có ID format `YYYY-MM-DD-{scope}-{slug}-{NN}`.

**Path:** `.mc-data/work/{skill}/sessions/{SESSION_ID}/`

**Chứa:** state file + log + error ledger + .lock + phase subdirectories.

### Skill

**Định nghĩa:** Đơn vị chính người dùng gọi qua `/command`. Mỗi skill là 1 phase của workflow hoặc support function.

**Vị trí:** `.claude/skills/workflow/{skill}/SKILL.md`

**Tài liệu:** [`02-standards/02-skill-standard.md`](../02-standards/02-skill-standard.md)

### Slug

**Định nghĩa:** Chuỗi lowercase-kebab-case dùng làm folder name, file name, ID component.

**Quy tắc:** Strip Vietnamese diacritics, special chars → `[a-z0-9-]+`

**Ví dụ:** "Quản Lý Khách Hàng" → "quan-ly-khach-hang"

### SSOT (Single Source of Truth)

**Định nghĩa:** Nguồn dữ liệu chính thức duy nhất. Trong MCV3 = `req-registry.json`.

**Quy tắc CORE-004:** Không thêm tính năng ngoài registry.

### `$SESSION_DIR`

**Định nghĩa:** Variable thay thế path session directory.

**Giá trị:** `.mc-data/work/{skill}/sessions/{SESSION_ID}/`

---

## T

### Template (CORE-031)

**Định nghĩa:** File mẫu trong `templates/` mà mọi output phải READ → POPULATE → WRITE từ đó.

**Quy tắc:** KHÔNG tạo output ad-hoc. Mọi `outputs.working[]` trong `_contract.json` PHẢI có field `template`.

### Tier T1-T4 (POST-GATE)

**Định nghĩa:** 4 tầng validation POST-GATE theo Protocol 10.

| Tier | Kiểm tra |
|------|---------|
| T1 | Existence (file tồn tại, non-empty) |
| T2 | Structure (sections, JSON valid) |
| T3 | Content (depth, word count) |
| T4 | Cross-reference (IDs khớp upstream) |

---

## W

### `wf-` prefix

**Định nghĩa:** Prefix cho workflow skills. Tất cả 43 skills chính có prefix `wf-`.

**Ví dụ:** `/wf-brainstorm`, `/wf-fix-bugs`, `/wf-implement-feature`

### `write_role`

**Định nghĩa:** Vai trò ghi registry của skill — 1 trong 7 giá trị (PRIMARY/SEED/APPEND/SAFE-UPDATE/FIX-INVALID/UPDATE-MODE/NONE).

**Tài liệu:** [`02-standards/06-safe-write-protocol.md`](../02-standards/06-safe-write-protocol.md) §2

---

## Acronyms

| Viết tắt | Đầy đủ |
|---------|--------|
| AI | Artificial Intelligence |
| API | Application Programming Interface |
| ADR | Architecture Decision Record |
| BA | Business Analyst |
| BHV | Behavioral Principle |
| CDG | Critical Decision Gate |
| CI | Code Intelligence (trong MCV3 context) |
| CORE | Core Rule |
| CQG | Code Quality Gate |
| DB | Database |
| DBA | Database Administrator |
| DoD | Definition of Done |
| ERD | Entity Relationship Diagram |
| FEAT-ID | Feature Identifier |
| GAAP | Generally Accepted Accounting Principles |
| HL7 FHIR | Healthcare interoperability standard |
| IDE | Integrated Development Environment |
| ISG | Issue Signal Graph (wf-fix-bugs Phase 3) |
| JSON | JavaScript Object Notation |
| KPI | Key Performance Indicator |
| LLM | Large Language Model |
| MCV3 | Master Claude V3 |
| MES | Manufacturing Execution System |
| ML | Machine Learning |
| OWASP | Open Web Application Security Project |
| PR | Pull Request |
| QA | Quality Assurance |
| QD | Quality Dimension (wf-fix-bugs lanes QD1-QD11) |
| REQ-ID | Requirement Identifier |
| SLM | Small Language Model |
| SLO/SLI | Service Level Objective / Indicator |
| SRE | Site Reliability Engineering |
| SSOT | Single Source of Truth |
| TDD | Test-Driven Development |
| UAT | User Acceptance Testing |
| UI | User Interface |
| UX | User Experience |
| WCAG | Web Content Accessibility Guidelines |

---

## Liên kết

- **Project overview:** [`01-project-description.md`](01-project-description.md)
- **Standards index:** [`../02-standards/README.md`](../02-standards/README.md)
- **CORE rules (canonical):** [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md)
- **Reference quick:** [`../08-reference/glossary-quick.md`](../08-reference/glossary-quick.md) (sẽ tạo ở Wave 4)
