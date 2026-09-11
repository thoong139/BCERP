# Master Plan — Tái cấu trúc `docs/` thành chuẩn MCV3

**Phiên bản:** v1.0
**Ngày tạo:** 2026-05-15
**Owner:** Vu Minh Tu (it@erktransport.com)
**Trạng thái:** 📋 PLANNED

---

## 1. Vision

`docs/` trở thành **single source of truth** cho:
- **Kiến trúc & thiết kế** MCV3 (tổng quan đến chi tiết per-skill)
- **Chuẩn ràng buộc** khi mở rộng (mọi skill/agent mới phải tham chiếu)
- **Hướng dẫn vận hành** cho end-user và developer

**Nguyên tắc cốt lõi:**
- Cấu trúc phản ánh **MCV3 thực tế đang chạy** (không lý thuyết)
- Phát hiện kiến trúc chưa tốt → cải tiến + chuẩn hóa
- Mỗi rule có **ví dụ Pass/Fail**, không chỉ định nghĩa
- Tiếng Việt cho user-facing, English cho code identifiers

---

## 2. Cấu trúc đích

```
docs/
├── README.md                    # Master index, đọc theo persona
├── CONTRIBUTING.md              # Quy trình đóng góp (skill mới, agent mới, sửa rule)
│
├── 00-overview/                 # WHAT/WHY
│   ├── 01-project-description.md
│   ├── 02-positioning-priorities.md
│   ├── 03-glossary.md
│   └── 04-key-personas.md
│
├── 01-architecture/             # HOW MCV3 vận hành
│   ├── 01-system-layers.md
│   ├── 02-workflow-model.md
│   ├── 03-data-model.md
│   ├── 04-code-intelligence.md
│   ├── 05-hooks-and-gates.md
│   ├── 06-protocols-overview.md
│   ├── 07-skills-catalog.md
│   ├── 08-agents-catalog.md
│   └── 09-dependencies-graph.md
│
├── 02-standards/                # ★ CHUẨN RÀNG BUỘC
│   ├── README.md
│   ├── 01-core-rules-index.md
│   ├── 02-skill-standard.md
│   ├── 03-agent-standard.md
│   ├── 04-contract-schema.md
│   ├── 05-quality-gates.md
│   ├── 06-safe-write-protocol.md
│   ├── 07-naming-conventions.md
│   ├── 08-error-code-registry.md
│   ├── 09-session-checkpoint.md
│   ├── 10-language-policy.md
│   ├── 11-output-path-contract.md
│   └── 12-extension-checklist.md
│
├── 03-design-patterns/          # ★ HOW-TO + ví dụ
│   ├── README.md
│   ├── 01-lazy-load-procedures.md
│   ├── 02-ci-first-integration.md
│   ├── 03-cross-skill-artifacts.md
│   ├── 04-parallel-lane-dispatch.md
│   ├── 05-agent-prompt-template.md
│   ├── 06-checkpoint-resume.md
│   ├── 07-playwright-3-modes.md
│   ├── 08-auto-detect-fallback.md
│   ├── 09-multi-session-locking.md
│   ├── 10-cdg-gate.md
│   └── 11-bash-utility-design.md
│
├── 04-skill-design/             # Design canon per-skill + template
│   ├── README.md
│   ├── _template/               # 9 file template chuẩn cho skill mới
│   ├── wf-fix-bugs/
│   └── wf-legacy-scan/
│
├── 05-review-standards/         # Per-skill review checklist (đầy đủ 43 skills)
│   ├── README.md
│   ├── _template-common.md
│   └── {skill}.md × 43
│
├── 06-user-guides/              # End-user (không kỹ thuật)
│   ├── README.md
│   ├── huong-dan-su-dung.md
│   ├── devkit-workflow-overview.md
│   └── per-skill/
│
├── 07-operations/               # Vận hành
│   ├── README.md
│   ├── runbooks/
│   ├── migrations/
│   ├── release-notes/
│   └── audits/
│
├── 08-reference/                # Tra cứu nhanh
│   ├── skill-anatomy-quick.md
│   ├── microtask-schema.md
│   ├── error-codes-quick.md
│   └── glossary-quick.md
│
└── 99-archive/                  # Lưu trữ superseded docs
```

---

## 3. Bốn waves

### Wave 1 — Foundation (W1)
**Mục tiêu:** Xây nền tảng chuẩn ràng buộc + entry point.

**Files (14):**
- `docs/README.md` (master index)
- `docs/CONTRIBUTING.md`
- `docs/00-overview/` × 4 (01-04)
- `docs/02-standards/` × 12 (README + 01-12)

**DoD:**
- Tất cả 14 file ≥80% hoàn thiện (có nội dung, không placeholder)
- Cross-link giữa các file đúng
- 1 ví dụ Pass/Fail cho mỗi rule trong `02-standards/`
- Bảng error-code registry phủ ≥80% skills
- Tài liệu nói rõ "đây là chuẩn ràng buộc"

### Wave 2 — Architecture & Patterns (W2)
**Mục tiêu:** Mô tả kiến trúc tổng quan + công thức mẫu.

**Files (20):**
- `docs/01-architecture/` × 9
- `docs/03-design-patterns/` × 11 (README + 01-11)

**DoD:**
- Mỗi pattern có ≥1 case study từ skill thực tế
- Catalog skills/agents khớp 100% với `.claude/skills/` và `.claude/agents/`
- Diagram (Mermaid) cho data flow, workflow model, dependency graph

### Wave 3 — Migration & Templates (W3)
**Mục tiêu:** Di chuyển file cũ + tạo template + scaffold review-standards.

**Tasks:**
- Move file theo bảng "Mapping cũ→mới" (xem §5)
- Viết `04-skill-design/_template/` × 9 file
- Bổ sung 25 file `05-review-standards/` còn thiếu (scaffold từ `_template-common.md`)
- Viết script `scripts/update-docs-refs.sh` để update `.claude/**` refs (chưa chạy)

**DoD:**
- Mọi file đã di chuyển, không trùng lặp
- Template hoàn chỉnh, có thể dùng ngay
- 43/43 skills có review-standards file (ít nhất scaffold)

### Wave 4 — User Guides & Operations (W4)
**Mục tiêu:** Hoàn thiện docs cho end-user và ops.

**Files:**
- `06-user-guides/` (move + viết README index)
- `07-operations/` (move migration/release-notes + viết README)
- `08-reference/` (move + viết cheatsheets)
- `99-archive/` (move superseded)
- Update `CLAUDE.md` và `AGENTS.md` để trỏ tới `docs/README.md`

**DoD:**
- Không file rời rạc ở `docs/` top-level (chỉ `README.md` + `CONTRIBUTING.md`)
- `docs/99-archive/` có README giải thích tại sao archive
- Final review pass: link integrity check

---

## 4. 10 cải tiến kiến trúc bake vào chuẩn

| # | Vấn đề hiện tại | Bake vào |
|---|-----------------|----------|
| 1 | CORE rules dày đặc, không có ví dụ | `02-standards/01-core-rules-index.md` — mỗi rule có Pass/Fail example |
| 2 | Skill anatomy không đồng nhất | `02-standards/02-skill-standard.md` — chốt 1 cấu trúc |
| 3 | Error code namespace chưa có registry chính thức | `02-standards/08-error-code-registry.md` — bảng E001..E999 |
| 4 | Output path contract rải rác | `02-standards/11-output-path-contract.md` — 1 bảng `.mc-data/` |
| 5 | Session ID format không nhất quán | `02-standards/09-session-checkpoint.md` — chốt format |
| 6 | Cross-skill schema chưa versioned đầy đủ | `02-standards/04-contract-schema.md` — yêu cầu `$schema` |
| 7 | 22 protocols thiếu overview cấp cao | `01-architecture/06-protocols-overview.md` |
| 8 | `design/skills/` chỉ có 2/43 skills | `04-skill-design/_template/` + yêu cầu mỗi skill mới có folder |
| 9 | `skill-review-standards/` chỉ 18/43 skills | Wave 3 — scaffold 25 file thiếu |
| 10 | Bash vs Python utility — không có guideline | `03-design-patterns/11-bash-utility-design.md` |

---

## 5. Mapping cũ → mới (Wave 3)

| File cũ | Đi đâu |
|---------|--------|
| `docs/project-description.md` | `docs/00-overview/01-project-description.md` |
| `docs/mcv3-development-priorities.md` | `docs/00-overview/02-positioning-priorities.md` |
| `docs/skills-reference.md` | `docs/01-architecture/07-skills-catalog.md` (rewrite slim) |
| `docs/skills-dependency-graph.md` | `docs/01-architecture/09-dependencies-graph.md` |
| `docs/devkit-workflow-overview.md` | `docs/06-user-guides/devkit-workflow-overview.md` |
| `docs/huong-dan-su-dung.md` | `docs/06-user-guides/huong-dan-su-dung.md` |
| `docs/skill-anatomy-guide.md` | `docs/08-reference/skill-anatomy-quick.md` (cheatsheet) + content sâu vào `02-standards/02-skill-standard.md` |
| `docs/microtask-schema.md` | `docs/08-reference/microtask-schema.md` |
| `docs/design/skills/wf-fix-bugs/01-09-*.md` | `docs/04-skill-design/wf-fix-bugs/01-09-*.md` |
| `docs/design/skills/wf-fix-bugs/prompts/` | `docs/99-archive/wf-fix-bugs-prompts/` |
| `docs/design/skills/wf-fix-bugs/reviews/` | `docs/99-archive/wf-fix-bugs-reviews/` |
| `docs/design/skills/wf-fix-bugs/scripts/` | `docs/99-archive/wf-fix-bugs-scripts/` hoặc `plans/` |
| `docs/design/skills/wf-legacy-scan/01-10-*.md` | `docs/04-skill-design/wf-legacy-scan/...` |
| `docs/design/skills/wf-legacy-scan/implementation/`, `archive/`, `fixtures/`, `examples/` | `docs/99-archive/wf-legacy-scan-implementation/` |
| `docs/skill-review-standards/*` | `docs/05-review-standards/` |
| `docs/skills-manual/*` | `docs/06-user-guides/per-skill/` |
| `docs/runbooks/*` | `docs/07-operations/runbooks/` |
| `docs/wf-e2e-*.md` | `docs/07-operations/migrations/` hoặc `release-notes/` |
| `docs/wf-fix-bugs-v*.md` | `docs/07-operations/migrations/` hoặc `release-notes/` |
| `docs/wf-preflight-v*-guide.md` | `docs/07-operations/release-notes/` |
| `docs/wf-legacy-scan-v5-guide.md` | `docs/07-operations/release-notes/` |
| `docs/wf-fix-bugs-fix-prompt-2026-05-15.md`, `e2e-test-wf-fix-bugs-prompt.md`, `template-usage-audit-prompts.md`, `DEVKIT-extraction.md`, `codex-guide.md` | `docs/99-archive/` |

---

## 6. Definition of Done (toàn dự án)

- ✅ 4 waves hoàn thành theo DoD per-wave
- ✅ `docs/README.md` có persona-driven navigation hoạt động
- ✅ Tất cả cross-link nội bộ trong `docs/` không broken (chạy link checker)
- ✅ 100% skills có review-standard file (ít nhất scaffold)
- ✅ 100% skills mới sau ngày này có folder `docs/04-skill-design/{skill}/` theo `_template/`
- ✅ Script `scripts/update-docs-refs.sh` viết xong (chạy sau, ngoài scope wave)
- ✅ `CLAUDE.md` và `AGENTS.md` cập nhật trỏ về `docs/README.md`
- ✅ Final review sign-off

---

## 7. Assumed defaults (chưa được user xác nhận chính thức)

> Chốt lại trước khi bắt đầu Wave 1 nếu cần thay đổi.

| Mục | Mặc định | Ghi chú |
|-----|---------|---------|
| Wave bắt đầu | W1 Foundation | Giá trị ràng buộc cao nhất |
| Review cadence | File-by-file (mỗi file viết xong báo user xem) | An toàn |
| Scope cải tiến kiến trúc | Tất cả 10 (xem §4) | Có thể downgrade về top-5 |
| Style viết | Teaching (kèm ví dụ + anti-pattern) cho 02/03; Formal cho 01/05 | |
| Ngôn ngữ | Tiếng Việt cho mọi user-facing docs | English cho file/var/function names |
| `.claude/**` refs stale | Defer — viết script xong nhưng KHÔNG chạy trong wave này | Bảo vệ `.claude/` |

---

## 8. Risk & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Scope creep — viết quá chi tiết | High | Medium | Strict DoD per file: 300-800 dòng, 1 ví dụ là đủ |
| `.claude/**` refs stale gây nhầm lẫn | Medium | Low | Defer fix sang wave riêng, script tự động |
| Multi-session mất context | High | Medium | `progress.md` update sau mỗi file |
| Cải tiến kiến trúc vượt scope docs | Medium | High | Chỉ ghi vào docs, KHÔNG đụng `.claude/skills/` — flag riêng |
| Audit gate fail vì docs path đổi | Low | Medium | Wave 3 viết script, chạy sau cùng |

---

## 9. Liên kết

- **Plan files:** `plans/docs-restructure-v1/`
- **Progress tracker:** `plans/docs-restructure-v1/progress.md`
- **Memory entry:** `project_docs_restructure_v1.md`
- **Source rules:** `.claude/rules/00-core.md`, `.claude/rules/00-behavioral.md`, `.claude/rules/07-project.md`
- **Source structure:** `.claude/skills/`, `.claude/agents/`, `.claude/skills/protocols/`
- **CLAUDE.md** (root) — overview hiện tại của MCV3
