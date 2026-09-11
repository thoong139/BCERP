# GEMINI.md

Ngữ cảnh dự án MCV3 cho Google Antigravity, Gemini CLI và các AI assistants nền tảng Google tương đương.

> File này là bản tóm tắt. Nguồn canonical đầy đủ: **`AGENTS.md`** (quy ước chung mọi agent đọc) và **`CLAUDE.md`** (chi tiết vận hành DEVKIT). Khi có xung đột, `AGENTS.md`/`CLAUDE.md` thắng.

---

## 0. Khách Hàng Dự Án: BC Agency (BẮT BUỘC đọc trước)

Repo này dùng DEVKIT (MCV3) để xây **BCERP** — ERP nội bộ cho **BC Agency** (Công ty TNHH Truyền thông & Dịch vụ BC Việt Nam, MST 0109354342, trụ sở Hà Nội), một **digital marketing agency** 8+ năm kinh nghiệm.

- **Mô hình kinh doanh:** trung gian (agency) quản lý tài khoản quảng cáo đa nền tảng — Meta, Google, TikTok, Bing, X, Pinterest, Yandex — cho 1.000+ khách hàng toàn cầu (FMCG, F&B, Retail, Beauty, B2B), 2.600+ tài khoản active. Kèm dịch vụ Facebook/TikTok marketing, TikTok Shop, Google Ads, SEO, thiết kế web/đồ họa.
- **Đối tác chính thức:** Google, TikTok, Yandex.
- **KHÔNG suy diễn** ngành nghề/phạm vi ERP khác với thông tin đã xác nhận. Chi tiết đầy đủ + hàm ý thiết kế module: [`docs/00-overview/00-company-context.md`](docs/00-overview/00-company-context.md) — đọc trước khi chạy `/wf-brainstorm` hoặc bất kỳ phân tích nghiệp vụ nào.
- **Ưu tiên domain expert:** `paid-media-expert` (trung tâm), `marketing-expert`, `sales-expert`, `finance-expert`, `customer-expert`, `compliance-expert` bên cạnh `business-analyst` mặc định.

---

## 1. Dự Án Là Gì

**MCV3** là DEVKIT — framework hỗ trợ người không chuyên xây dựng phần mềm trên nền tảng AI coding (Claude Code, Google Antigravity, Codex, Qwen Code...). Biến ý tưởng mơ hồ thành phần mềm hoàn chỉnh qua đội ngũ 62 AI agents chuyên biệt.

**Invariant không được vi phạm:**
- `.claude/` là read-only trong runtime dự án. Mọi runtime data ghi vào `.mc-data/`.
- Chất lượng, độ chính xác, tính đầy đủ luôn đứng trước tốc độ.
- Tài liệu phase sau phải có căn cứ từ tài liệu phase trước và từ `req-registry.json`.
- KHÔNG skip workflow phases. Chưa có output phase trước → KHÔNG chạy phase sau.
- KHÔNG thêm tính năng ngoài `req-registry.json` (CORE-004).

## 2. Kiến Trúc — Hai Lớp

- **Skills** (`.claude/skills/workflow/`): skills `wf-*` — lệnh `/wf-*` user gọi. Mỗi skill chạy PRE-GATE → EXECUTION → POST-GATE, ghi output vào `.mc-data/`.
- **Agents** (`.claude/agents/`): Skills spawn agents để phân tích, thiết kế, implement. Agent tên file (không `.md`) = `subagent_type`.

```
User → Skill (/wf-*) → Agents → Output vào .mc-data/docs/phase[N]/
                              ↓
                   req-registry.json (SSOT duy nhất)
```

## 3. Workflow Chuẩn (dự án mới)

```
/wf-brainstorm → /wf-analyze-requirements → /wf-define-features →
/wf-design → /wf-design-ux (UI only) → /wf-plan-modules →
/wf-implement-feature → /wf-preflight → /wf-verify-sync → /wf-prepare-deployment
                                ↑
                /wf-fix-bugs (bất kỳ lúc sau khi có code)
```

Danh sách đầy đủ lệnh + mô tả: xem `CLAUDE.md` §"Danh sách Skills".

## 4. Single Source Of Truth

`req-registry.json` tại `.mc-data/docs/_meta/req-registry.json`. ĐỌC trước khi thiết kế/code; mỗi skill CHỈ update field được phân công (Safe-Write Protocol); `impl_status` chỉ có 4 giá trị: `not_started` | `in_progress` | `done` | `skipped`, KHÔNG downgrade từ `done`.

### REQ-ID trong code

```typescript
// REQ-ID: REQ-SALES-001
// FEAT-ID: FEAT-CRM-CUST-001
export class CustomerService { ... }
```

## 5. Validation

Trên Windows dùng PowerShell wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File .claude/scripts/run-devkit-bash.ps1 .claude/scripts/skill-compliance-audit.sh --all
powershell -ExecutionPolicy Bypass -File .claude/scripts/run-devkit-bash.ps1 .claude/scripts/validate-schema-sync.sh --all
```

Đây là framework, không có build/test truyền thống.

## 6. Ngôn Ngữ

| Loại | Ngôn ngữ |
|------|---------|
| Tài liệu, comments | Tiếng Việt có dấu |
| File names, variables, functions | English hoặc tiếng Việt không dấu |

## 7. Đọc Thêm

- `AGENTS.md` — quy ước chung mọi agent (canonical cho bối cảnh khách hàng)
- `CLAUDE.md` — hướng dẫn đầy đủ, danh sách skill/agent, cấu trúc thư mục
- `docs/00-overview/00-company-context.md` — hồ sơ BC Agency + hàm ý thiết kế module
- `docs/README.md` — entry point điều hướng toàn bộ `docs/`
