# AGENTS.md

> File này tuân theo quy ước [agents.md](https://agents.md/) — được Claude Code, Codex, zCode, Google Antigravity và các AI coding agent khác tự động đọc khi mở repo. Nếu tool của bạn có file cấu hình riêng (`CLAUDE.md`, `QWEN.md`, ...), file đó bổ sung chi tiết vận hành — nhưng bối cảnh khách hàng ở §0 dưới đây là bắt buộc đọc trước với MỌI agent.

## 0. Dự Án Này Là Gì — Khách Hàng: BC Agency (BẮT BUỘC đọc trước)

Repo này dùng DEVKIT (MCV3) để xây **BCERP** — hệ thống ERP nội bộ cho **BC Agency** (Công ty TNHH Truyền thông & Dịch vụ BC Việt Nam), một **digital marketing agency** — KHÔNG phải doanh nghiệp sản xuất/bán lẻ thông thường.

- **Ngành nghề:** Trung gian quản lý tài khoản quảng cáo đa nền tảng (Meta, Google, TikTok, Bing, X, Pinterest, Yandex) + Facebook/TikTok/Google marketing, SEO, thiết kế web/đồ họa.
- **Khách hàng mục tiêu của BC Agency:** doanh nghiệp FMCG, F&B, Retail, Beauty, B2B (1.000+ khách hàng toàn cầu, 2.600+ tài khoản quảng cáo active, 8+ năm kinh nghiệm).
- **Đối tác chính thức:** Google, TikTok, Yandex.
- **Ưu tiên domain expert khi phân tích nghiệp vụ:** `paid-media-expert` (trung tâm), `marketing-expert`, `sales-expert`, `finance-expert`, `customer-expert`, `compliance-expert` — ngoài `business-analyst` mặc định.

**Chi tiết đầy đủ + hàm ý thiết kế module:** [`docs/00-overview/00-company-context.md`](docs/00-overview/00-company-context.md) — ĐỌC file này trước khi chạy `/wf-brainstorm` hoặc bất kỳ phân tích nghiệp vụ nào. KHÔNG tự suy diễn ngành nghề/mô hình kinh doanh khác với thông tin đã xác nhận ở đó.

## Mục Tiêu Repo

MCV3 là DEVKIT — framework xây dựng phần mềm cho người không chuyên trên nền tảng AI coding. Repo chứa agents, skills, hooks, rules, doc-framework và scripts. Khi làm việc ở đây, ưu tiên nhất quán của workflow và output contract hơn tối ưu cục bộ từng file.

## Thứ Tự Ưu Tiên

1. Độ chính xác, tính nhất quán, tính đầy đủ, chất lượng, bảo mật.
2. Tốc độ và song song hóa — chỉ sau khi ưu tiên 1 được bảo vệ.

Nếu chất lượng và tốc độ xung đột → chất lượng thắng. Tài liệu phase sau phải có căn cứ từ phase trước và `req-registry.json`.

## Tài Liệu Nên Đọc Trước

0. **`docs/00-overview/00-company-context.md`** — ★★ Bối cảnh khách hàng BC Agency — BẮT BUỘC đọc đầu tiên.
1. **`docs/README.md`** — ★ ENTRY POINT (persona-driven navigation cho `docs/`).
2. `CLAUDE.md` — Tổng quan, workflow, cấu trúc thư mục, lệnh validation.
3. `docs/00-overview/02-positioning-priorities.md` — Khung ưu tiên vận hành.
4. `docs/00-overview/01-project-description.md` — Mục tiêu sản phẩm và mô hình 7 phases.
5. `docs/01-architecture/07-skills-catalog.md` — Catalog 43 skills, output paths, contracts.
6. `docs/06-user-guides/huong-dan-su-dung.md` — Luồng end-to-end cho người dùng cuối.
7. `docs/02-standards/` — ★ Chuẩn ràng buộc bắt buộc khi tạo/sửa skill/agent.

> **Lưu ý cấu trúc `docs/` mới (2026-05-15):** 8 sections (00-overview, 01-architecture, 02-standards, 03-design-patterns, 04-skill-design, 05-review-standards, 06-user-guides, 07-operations, 08-reference) + 99-archive. Các path cũ (`docs/project-description.md`, `docs/skills-reference.md`, ...) đã chuyển vào `docs/99-archive/` với suffix `-LEGACY.md` (giữ làm reference, không tiếp tục cập nhật).

## Bản Đồ Repo

- `.claude/agents/` — 62 agent definitions (5 đội + orchestrator) + 62 procedure directories.
- `.claude/skills/workflow/` — 35 skills `wf-*` (gồm 11 spawned dimension lanes QD1–QD11 + wf-scan-target/wf-diagram standalone + wf-fix-bugs orchestrator v10.0); mỗi cái có SKILL.md + _contract.json + procedures/ + templates/ + evals/.
- `.claude/skills/workflows/` — 3 orchestrator skills (new-project, existing-project, feature-addition).
- `.claude/skills/protocols/` — 22 protocol files (21 protocol + README, shared quality gates).
- `.claude/hooks/` — 12 validation hooks (Pre/Post tool) + _hook-utils.sh.
- `.claude/rules/` — 9 rule files (00-behavioral, 00-core, 01-coding → 07-project) — 31 CORE rules trong 00-core.md (updated 2026-05-13 với CORE-032 → CORE-038 từ wf-fix-bugs v10.0).
- `.claude/doc-framework/` — 40 document templates + 20 schema files (Phase 0-6).
- `.claude/scripts/` — 160+ audit + validation scripts; chạy qua PowerShell wrapper trên Windows.
- `docs/` — Hướng dẫn, reference, audit notes.
- `.mc-data/` — Runtime artifacts (gitignored). `.claude/` là read-only trong runtime.

## Phân Lớp Thay Đổi

| Loại | Vị trí |
|------|--------|
| Workflow | `.claude/skills/workflow/[skill]/` |
| Agent behavior | `.claude/agents/[team]/[agent].md` + `procedures/` |
| Validation | `.claude/hooks/` hoặc `.claude/rules/` |
| Output template | `.claude/doc-framework/` |

Khi sửa skill: giữ nguyên output paths, gate markers và contract với `.mc-data/` trừ khi đổi workflow có chủ đích. Khi sửa agent: kiểm tra chéo tên file, path procedures và tài liệu tham chiếu liên quan.

## Verification Sau Thay Đổi

```powershell
# Audit skill (Windows)
powershell -ExecutionPolicy Bypass -File .claude/scripts/run-devkit-bash.ps1 .claude/scripts/skill-compliance-audit.sh <skill-name>
powershell -ExecutionPolicy Bypass -File .claude/scripts/run-devkit-bash.ps1 .claude/scripts/skill-compliance-audit.sh --all

# Validate schema sync
powershell -ExecutionPolicy Bypass -File .claude/scripts/run-devkit-bash.ps1 .claude/scripts/validate-schema-sync.sh --all
```

Nếu thay đổi không có automated test, nêu rõ rằng verify chỉ dừng ở structural review và cross-referencing.

## Quy Ước

- Trả lời người dùng bằng tiếng Việt có dấu.
- Tài liệu và comment viết tiếng Việt. Tên file, biến, hàm dùng English hoặc tiếng Việt không dấu.
- `.mc-data/` và `docs/audit/work/` là artefact runtime — mặc định không commit.
- Dùng path tương đối theo repo root, tránh hardcode đường dẫn máy cục bộ.
- Bắt đầu task bằng cách đọc `CLAUDE.md` và chỉ nạp thêm tài liệu đúng với phạm vi task.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **MCV3** (5030 symbols, 5584 relationships, 6 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/MCV3/context` | Codebase overview, check index freshness |
| `gitnexus://repo/MCV3/clusters` | All functional areas |
| `gitnexus://repo/MCV3/processes` | All execution flows |
| `gitnexus://repo/MCV3/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
