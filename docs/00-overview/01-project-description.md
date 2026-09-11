# 01 — DEVKIT là gì

> **Mức độ ràng buộc:** Tham khảo (overview)
> **File gốc:** [`docs/project-description.md`](../project-description.md), [`CLAUDE.md`](../../CLAUDE.md)
> **Mục đích:** Giới thiệu DEVKIT/MCV3 cho người mới — bài đọc đầu tiên

---

## 1. DEVKIT là gì?

**DEVKIT (MCV3)** là **bộ công cụ hỗ trợ người không chuyên phát triển phần mềm** trên nền tảng [Claude Code](https://claude.ai/code). Nó biến **ý tưởng mơ hồ** thành **sản phẩm phần mềm hoàn chỉnh** thông qua **đội ngũ 62 AI chuyên gia ảo**.

```
Người dùng nói:
   "Xây dựng phần mềm quản lý vận hành cho công ty xuất nhập khẩu"

DEVKIT làm:
   1. Brainstorm cùng user → chốt khung dự án
   2. Đội AI chuyên gia (Business Analyst + Logistics + Finance + ...) phân tích nghiệp vụ
   3. Định nghĩa tính năng → thiết kế kiến trúc → thiết kế UX
   4. Lập kế hoạch sprint → viết code theo TDD
   5. Health check + sửa lỗi + chuẩn bị triển khai

Kết quả:
   - Tài liệu nghiệp vụ + kiến trúc + UX hoàn chỉnh
   - Source code hoạt động + có test coverage
   - Hướng dẫn triển khai + vận hành
```

---

## 2. Vấn đề DEVKIT giải quyết

| Vấn đề thực tế | DEVKIT giải quyết |
|----------------|-------------------|
| Người có ý tưởng nhưng không biết bắt đầu từ đâu | Brainstorm có cấu trúc → ra khung dự án |
| Thiếu kiến thức chuyên môn để định hướng | 24 domain experts (Finance, Healthcare, Logistics, ...) tư vấn |
| Đi từ ý tưởng → code quá nhanh, bỏ qua phân tích | Bắt buộc đi qua 7 phases — không skip |
| Mất ngữ cảnh khi dự án phức tạp | SSOT `req-registry.json` + tài liệu Phase 0-6 |
| Code không truy vết được về requirement | REQ-ID/FEAT-ID trong mọi code file |
| AI "tự bịa" feature không có trong yêu cầu | CORE-004: cấm thêm feature ngoài registry |

---

## 3. Định vị cốt lõi

> **Output của DEVKIT phải là tài sản vận hành thật, không phải bản nháp tạm thời.**

Cụ thể:
- **Đủ tốt cho doanh nghiệp dùng vận hành** — tài liệu rõ ràng để chủ doanh nghiệp đọc + nhân viên triển khai
- **Đủ chuẩn cho AI dùng làm context phát triển tiếp** — schema, REQ-ID, structure đủ chặt để AI tiếp tục mà không tự suy diễn

Điều đó dẫn tới **thứ tự ưu tiên bắt buộc:**

```
1. Độ chính xác, tính nhất quán, tính đầy đủ, chất lượng kỹ thuật, bảo mật
2. Tốc độ xử lý và song song hóa — CHỈ SAU KHI mục 1 được bảo vệ
```

Nếu xung đột: **Chất lượng thắng.** Tốc độ chỉ tối ưu trong vùng an toàn của chất lượng.

Chi tiết: [`02-positioning-priorities.md`](02-positioning-priorities.md).

---

## 4. Quy trình 7 phases (Phase 0-6)

| Phase | Tên | Skill chính | Đầu ra chính |
|-------|-----|-------------|--------------|
| **0** | Brainstorm | `/wf-brainstorm` | Khung dự án + `.mc-data/` |
| **1** | Business Requirements | `/wf-analyze-requirements` | Phân tích nghiệp vụ, REQ-IDs |
| **2** | Feature Definition | `/wf-define-features` | Feature specs theo `[sys]/[mod]/[feat].md` |
| **3** | Architecture | `/wf-design` | API, DB schema, kiến trúc hệ thống |
| **4** | UX/UI (conditional) | `/wf-design-ux` | Design system, screen specs |
| **5** | Implementation | `/wf-plan-modules` → `/wf-implement-feature` → `/wf-verify-sync` | Roadmap, sprints, source code |
| **6** | Deployment | `/wf-prepare-deployment` | Deployment + user guides |

### Workflow tổng thể

```
STANDARD PATH (dự án mới):
  Ý tưởng → /wf-brainstorm → /wf-analyze-requirements → /wf-define-features →
  /wf-design → /wf-design-ux (nếu có UI) → /wf-plan-modules →
  /wf-implement-feature → /wf-preflight → /wf-verify-sync → /wf-prepare-deployment
                                                                          ↑
                                          /wf-fix-bugs (bất kỳ lúc nào sau khi có code)

EXISTING PATH (dự án có sẵn):
  /wf-legacy-scan → /wf-legacy-classify → /wf-legacy-extract → /wf-brainstorm* →
  /wf-analyze-requirements* → /wf-define-features* → /wf-design* →
  /wf-annotate-code (nếu có gaps) → /wf-design-ux* (nếu UI) → /wf-plan-modules → ...

  * = shared skills tự detect LEGACY_MODE
```

**Nguyên tắc cứng:** KHÔNG skip phases. Chưa có output phase trước → KHÔNG chạy phase sau.

---

## 5. Đội ngũ AI Agents — 62 chuyên gia

| Đội | Vị trí | Số lượng | Vai trò |
|-----|--------|---------|---------|
| **Business** | `.claude/agents/business/` | 25 | BA + 24 domain experts (Finance, Healthcare, Retail, Logistics, ...) |
| **Engineering** | `.claude/agents/engineering/` | 14 | Architect, Developer, DevOps, Security, AI Engineer, ... |
| **Design** | `.claude/agents/design/` | 7 | UX/UI Designer, Brand Guardian, Image Prompt, ... |
| **Testing** | `.claude/agents/testing/` | 9 | QA Lead, Code Reviewer, Performance, Accessibility, ... |
| **Review** | `.claude/agents/review/` | 6 | Agent/Skill auditors (DEVKIT self-quality) |
| **Orchestrator** | `.claude/agents/orchestrator.md` | 1 | Điều phối giữa các đội |

**Mỗi agent:**
- Có file definition tại `.claude/agents/{team}/{agent}.md`
- Có **knowledge base** tại `.claude/references/team-expert/{domain}/` (162 files, 29 domains)
- Có **procedure files** tại `.claude/agents/procedures/{agent}/` (HOW chi tiết per task)

Skills **spawn** agent qua `Agent` tool với `subagent_type = tên file agent (không .md)`.

---

## 6. Hai lớp kiến trúc chính

### Lớp 1: Skills — Người dùng gọi qua `/command`

```
User → /wf-brainstorm
         │
         ▼
  SKILL.md (≤500 dòng, lean routing hub)
         │
         ▼
  Phase 1 → Spawn Business Analyst agent
  Phase 2 → Spawn Domain Expert agent (auto-detect)
  Phase 3 → ...
         │
         ▼
  Output: .mc-data/docs/phase0-brainstorm/
```

### Lớp 2: Agents — Thực thi analysis/design/code

Agent đọc:
- Knowledge files (domain expertise)
- Procedure file (HOW chi tiết per task)
- Input từ skill (session context, CI context, prompt)

Agent viết:
- Output file theo schema từ skill caller
- Phase report tiếng Việt
- Spotcheck-friendly content

---

## 7. Single Source of Truth — `req-registry.json`

```
.mc-data/docs/_meta/req-registry.json
```

Chứa:
- `systems[]`, `modules[]`, `departments[]` — phân cấp dự án
- `requirements[]` — REQ-ID + metadata + impl_status
- `features[]` — FEAT-ID + dependencies
- `implementation_order`, `design_status`, `interface_type`, `locale`

**Quy tắc:**
- ĐỌC registry + docs trước khi thiết kế/code (CORE-001)
- KHÔNG thêm tính năng ngoài registry (CORE-004)
- Mỗi skill chỉ update đúng fields được phân công (CORE-006 Safe-Write)
- `impl_status` chỉ có 4 giá trị: `not_started` / `in_progress` / `done` / `skipped`

Chi tiết: [`02-standards/06-safe-write-protocol.md`](../02-standards/06-safe-write-protocol.md).

---

## 8. REQ-ID Tracking

Mọi code file PHẢI có comment trace về requirement:

```typescript
// REQ-ID: REQ-SALES-001
// FEAT-ID: FEAT-CRM-CUST-001
export class CustomerService { ... }
```

**Format:**
- Đơn giản: `REQ-[DEPT]-[NNN]` → `REQ-SALES-001`
- Phức tạp: `REQ-[SYSTEM]-[MODULE]-[NNN]` → `REQ-CRM-CUST-001`

**Luồng truy vết:**
```
REQ-SALES-001 → FEAT-CRM-CUST-001 → UI-...-001 + API-...-001 + DB-...-001 → code comment
```

Tất cả 3 nguồn (registry, folder, code) PHẢI khớp nhau (CORE-018).

---

## 9. 43 Skills + 3 Orchestrator Workflows

**Workflow chính:** 43 skills `wf-*` cover toàn bộ 7 phases + support.

**Orchestrator meta-workflows:**
- `/new-project` — Full workflow idea → deployment
- `/existing-project` — Onboard codebase + full workflow
- `/feature-addition` — Thêm features (Phase 3+)

**Self-audit:**
- `/audit-devkit` — MCV3 self-audit
- `/audit-agents`, `/audit-skill-output`, ...

Chi tiết: [`docs/skills-reference.md`](../skills-reference.md) (sẽ migrate sang `01-architecture/07-skills-catalog.md` ở Wave 2).

---

## 10. Cấu trúc dữ liệu dự án — `.mc-data/`

```
.mc-data/
├── docs/                          # Tài liệu chính thức 7 phases
│   ├── _meta/
│   │   └── req-registry.json      # ★ SSOT
│   ├── phase0-brainstorm/         # Khung dự án
│   ├── phase1-business/           # Nghiệp vụ
│   ├── phase2-features/           # Đặc tả tính năng
│   ├── phase3-architecture/       # Kiến trúc + spec
│   ├── phase4-ux/                 # UX/UI (conditional)
│   ├── phase5-implementation/     # Sprints, tasks
│   └── phase6-deployment/         # Deployment + user guides
├── work/                          # Runtime artifacts per skill
│   └── {skill}/sessions/{id}/...
├── sync/                          # REQ-ID sync tracking
└── knowledge-base/                # Optional notes
```

Chi tiết: [`02-standards/11-output-path-contract.md`](../02-standards/11-output-path-contract.md).

---

## 11. Quy ước ngôn ngữ

| Loại | Ngôn ngữ |
|------|---------|
| Tài liệu, comments nghiệp vụ | **Tiếng Việt** |
| Phase reports cho user | **Tiếng Việt** ≤15 dòng |
| File/folder names, variables, functions | **English** hoặc Vietnamese không dấu |
| Schema field keys | **English** |
| REQ-ID/FEAT-ID | **UPPERCASE format chuẩn** |

Chi tiết: [`02-standards/10-language-policy.md`](../02-standards/10-language-policy.md).

---

## 12. Đọc tiếp gì?

- **Bắt đầu sử dụng:** [`huong-dan-su-dung.md`](../huong-dan-su-dung.md) — luồng end-to-end cho user
- **Hiểu ưu tiên:** [`02-positioning-priorities.md`](02-positioning-priorities.md)
- **Tra cứu thuật ngữ:** [`03-glossary.md`](03-glossary.md)
- **Personas:** [`04-key-personas.md`](04-key-personas.md)
- **Muốn mở rộng MCV3:** [`../02-standards/README.md`](../02-standards/README.md) — đọc 12 chuẩn ràng buộc
- **Đóng góp:** [`../CONTRIBUTING.md`](../CONTRIBUTING.md)

---

## 13. Liên kết

- **[`00-company-context.md`](00-company-context.md)** — ★ Bối cảnh khách hàng BC Agency (đọc trước khi phân tích nghiệp vụ dự án BCERP)
- **CLAUDE.md** (root) — overview hiện tại của MCV3 cho Claude Code
- **AGENTS.md** (root) — quick reference cho contributors
- **CHANGELOG.md** — lịch sử phát hành các skill
- **Canonical source:** [`docs/project-description.md`](../project-description.md) (legacy location, sẽ deprecate sau Wave 3)
