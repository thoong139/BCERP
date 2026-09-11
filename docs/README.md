# MCV3 — Bộ Tài Liệu Chuẩn Hóa

> **Đây là chuẩn ràng buộc cho phát triển và mở rộng MCV3.** Mọi skill, agent, rule, hoặc cấu trúc mới ĐỀU PHẢI tham chiếu thư mục này trước khi bắt đầu.

**Phiên bản tài liệu:** v1.0 (2026-05-15)
**Phạm vi:** Toàn bộ DEVKIT (MCV3) — skills, agents, rules, doc-framework, hooks
**Ngôn ngữ chuẩn:** Tiếng Việt (user-facing) + English (code identifiers) — xem `02-standards/10-language-policy.md`

---

## 1. Tài liệu này để làm gì?

`docs/` là **single source of truth** cho:

1. **Kiến trúc tổng quan** MCV3 — hai lớp (Skills + Agents), 7 phases, dataflow, hooks, protocols
2. **Chuẩn ràng buộc** khi mở rộng — anatomy, contract schema, naming, error codes, output paths
3. **Pattern thiết kế** đã kiểm chứng — lazy-load procedures, CI-first integration, parallel lane dispatch, ...
4. **Design canon per-skill** — wf-fix-bugs, wf-legacy-scan, ... + template cho skill mới
5. **Hướng dẫn vận hành** — end-user guide, migration, release notes, troubleshooting

`docs/` KHÔNG bao gồm:
- Runtime artifacts → `.mc-data/` (sinh ra khi MCV3 chạy trên dự án thật)
- Working data của skill → `.claude/skills/{skill}/` (file SKILL.md, procedures, templates, _contract.json)
- Plans triển khai → `plans/` (kế hoạch cải tiến từng skill version)

---

## 2. Cấu trúc thư mục

```
docs/
├── README.md                    ◀ Bạn đang ở đây
├── CONTRIBUTING.md              ◀ Quy trình đóng góp + DoD
│
├── 00-overview/                 # WHAT/WHY — định vị MCV3
├── 01-architecture/             # HOW MCV3 vận hành (high-level)
├── 02-standards/                # ★ RULES — chuẩn ràng buộc khi mở rộng
├── 03-design-patterns/          # ★ HOW-TO + case studies thực tế
├── 04-skill-design/             # Design canon per-skill + template
├── 05-review-standards/         # Review checklist per skill
├── 06-user-guides/              # End-user (không kỹ thuật)
├── 07-operations/               # Vận hành, migration, runbooks
├── 08-reference/                # Tra cứu nhanh (cheatsheets)
└── 99-archive/                  # Tài liệu superseded
```

---

## 3. Đọc theo persona — tôi nên đọc gì trước?

### 🎯 Tôi muốn hiểu MCV3 là gì
1. [`00-overview/01-project-description.md`](00-overview/01-project-description.md) — Định vị + 7 phases
2. [`00-overview/02-positioning-priorities.md`](00-overview/02-positioning-priorities.md) — Thứ tự ưu tiên (chất lượng > tốc độ)
3. [`00-overview/03-glossary.md`](00-overview/03-glossary.md) — Thuật ngữ (DEVKIT, skill, agent, CDG, SSOT, FEAT-ID, ...)

### 🛠️ Tôi muốn tạo skill mới
1. [`02-standards/02-skill-standard.md`](02-standards/02-skill-standard.md) — Anatomy bắt buộc
2. [`02-standards/01-core-rules-index.md`](02-standards/01-core-rules-index.md) — 38 CORE + 4 BHV
3. [`02-standards/12-extension-checklist.md`](02-standards/12-extension-checklist.md) — Checklist trước khi merge
4. [`03-design-patterns/01-lazy-load-procedures.md`](03-design-patterns/01-lazy-load-procedures.md) — Pattern CORE-032
5. [`04-skill-design/_template/`](04-skill-design/_template/) — 9 file template cho design doc

### 🤖 Tôi muốn tạo agent mới
1. [`02-standards/03-agent-standard.md`](02-standards/03-agent-standard.md) — Agent + Knowledge definition
2. [`03-design-patterns/05-agent-prompt-template.md`](03-design-patterns/05-agent-prompt-template.md) — 8-section template (CORE-037)

### 🔧 Tôi muốn sửa skill có sẵn
1. [`02-standards/12-extension-checklist.md`](02-standards/12-extension-checklist.md) — Khi nào sửa vs tạo mới
2. [`02-standards/06-safe-write-protocol.md`](02-standards/06-safe-write-protocol.md) — Quy tắc safe-write (CORE-006)
3. [`02-standards/11-output-path-contract.md`](02-standards/11-output-path-contract.md) — Path contract (CORE-007)

### 🔍 Tôi muốn hiểu kiến trúc tổng quan
1. [`01-architecture/01-system-layers.md`](01-architecture/01-system-layers.md) — 2 lớp + hooks + data flow
2. [`01-architecture/02-workflow-model.md`](01-architecture/02-workflow-model.md) — 7 phases × 3 paths
3. [`01-architecture/06-protocols-overview.md`](01-architecture/06-protocols-overview.md) — 22 protocols

### 📐 Tôi muốn áp dụng pattern cụ thể
- [`03-design-patterns/`](03-design-patterns/) — 11 pattern (lazy-load, CI-first, cross-skill artifact, parallel lane, agent prompt, checkpoint resume, Playwright 3 modes, auto-detect fallback, multi-session locking, CDG gate, bash vs Python)

### 🚀 Tôi muốn dùng MCV3 (không lập trình)
1. [`06-user-guides/huong-dan-su-dung.md`](06-user-guides/huong-dan-su-dung.md) — Luồng end-to-end
2. [`06-user-guides/devkit-workflow-overview.md`](06-user-guides/devkit-workflow-overview.md)

### 🛠️ Tôi cần vận hành / migration / troubleshoot
1. [`07-operations/`](07-operations/) — Runbooks, migrations, release notes

---

## 4. Bảng tra cứu nhanh

| Tôi cần biết... | Đọc... |
|-----------------|--------|
| Tất cả CORE rules + ví dụ Pass/Fail | [`02-standards/01-core-rules-index.md`](02-standards/01-core-rules-index.md) |
| Cấu trúc bắt buộc của 1 skill | [`02-standards/02-skill-standard.md`](02-standards/02-skill-standard.md) |
| Schema `_contract.json` | [`02-standards/04-contract-schema.md`](02-standards/04-contract-schema.md) |
| PRE-GATE / POST-GATE là gì | [`02-standards/05-quality-gates.md`](02-standards/05-quality-gates.md) |
| Tên file/REQ-ID/FEAT-ID/session-ID | [`02-standards/07-naming-conventions.md`](02-standards/07-naming-conventions.md) |
| Error code của skill nào range nào | [`02-standards/08-error-code-registry.md`](02-standards/08-error-code-registry.md) |
| Output path trong `.mc-data/` | [`02-standards/11-output-path-contract.md`](02-standards/11-output-path-contract.md) |
| Khi nào checkpoint, khi nào FORCE STOP | [`02-standards/09-session-checkpoint.md`](02-standards/09-session-checkpoint.md) |
| Catalog 43 skills | [`01-architecture/07-skills-catalog.md`](01-architecture/07-skills-catalog.md) |
| Catalog 62 agents | [`01-architecture/08-agents-catalog.md`](01-architecture/08-agents-catalog.md) |
| 15 engines kiến trúc (skill arch, dependency, knowledge graph, ...) | [`01-architecture/10-mcv3-engines-overview.md`](01-architecture/10-mcv3-engines-overview.md) |

---

## 5. Mối quan hệ với file gốc trong `.claude/`

`docs/` là **tài liệu tham chiếu** — không phải executable. Mọi rule, skill, agent vẫn được định nghĩa tại file gốc:

| Loại nội dung | File gốc (canonical) | Doc trong `docs/` |
|---------------|---------------------|-------------------|
| CORE/BHV rules | `.claude/rules/00-core.md`, `00-behavioral.md` | `02-standards/01-core-rules-index.md` (lookup + examples) |
| Skill definition | `.claude/skills/workflow/{skill}/SKILL.md` | `04-skill-design/{skill}/` (design canon) |
| Agent definition | `.claude/agents/{team}/{agent}.md` | (catalog tại `01-architecture/08-agents-catalog.md`) |
| Protocols | `.claude/skills/protocols/{NN}-*.md` | `01-architecture/06-protocols-overview.md` (overview) |
| Skill template | `.claude/skills/workflow-skill.md` | `02-standards/02-skill-standard.md` (chuẩn anatomy) |

**Quy tắc tham chiếu:**
- Khi conflict giữa `docs/` và file gốc → **file gốc thắng** (vì là canonical)
- Khi `docs/` rõ hơn file gốc → mở Issue/PR cập nhật file gốc, KHÔNG silent override
- File gốc thay đổi → cập nhật `docs/` trong cùng PR

---

## 6. Đóng góp — quy trình

Xem [`CONTRIBUTING.md`](CONTRIBUTING.md) — quy trình ngắn cho:
- Đề xuất skill/agent/rule mới
- Sửa đổi rule có sẵn
- Cập nhật chuẩn (`02-standards/*`)
- Bổ sung pattern (`03-design-patterns/*`)

---

## 7. Lịch sử & roadmap

- **v1.0** (2026-05-15) — Khởi tạo bộ tài liệu chuẩn, rebuild từ trạng thái cũ `docs/` lẫn lộn
- Plan triển khai: [`plans/docs-restructure-v1/`](../plans/docs-restructure-v1/)
- 4 waves: Foundation → Architecture & Patterns → Migration & Templates → User Guides & Ops

---

## 8. Liên hệ

- **Owner:** Vu Minh Tu (it@erktransport.com)
- **Repo:** `D:\Working\MCV3\`
- **Issue:** mở issue ở repo MCV3 với label `docs`
