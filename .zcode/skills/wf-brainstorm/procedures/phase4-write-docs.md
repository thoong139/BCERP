# Phase 4: Soạn & Ghi Tài Liệu (TỰ ĐỘNG)

> **Giai đoạn tự động** — KHÔNG hỏi user.
> Soạn và **ghi thẳng** vào `.mc-data/docs/phase0-brainstorm/` — không qua bước duyệt.
> BA + architect + domain experts chạy PARALLEL.
> Chạy POST-GATE Protocol 8 (cross-validation) sau khi files đã được tạo.

**PRE-GATE:**

- [ ] Phase 3 (phase3-brainstorm-policy.md) POST-GATE PASS
- [ ] `brainstorm-notes.md` exists, content > 200 bytes
- [ ] `final_scope_context` populated
- [ ] Nếu STANDARD/ENTERPRISE: `final_policy_gaps[]` available

**INPUT:** Toàn bộ context Phase 1+2+3, working files

**OUTPUT (vào `.mc-data/docs/phase0-brainstorm/`):**
- `P0-01-brainstorm.md` (6 sections)
- `P0-02-systems-users.md` (4 sections)
- `policies/[ten-kebab-case].md` (0-N files theo `final_policy_gaps[]`)
- `.mc-data/work/wf-brainstorm/crosscheck-report.md` (audit log)

---

## Reference Sections

- `_shared.md` §2 Quy Tắc Ngôn Ngữ & File Output (BẮT BUỘC tiếng Việt có dấu)
- `_shared.md` §3 Template Usage Rule
- `_shared.md` §8 Agent Roles Per Phase
- `_shared.md` §11 Policy Agent-Responsible Mapping (cho Step 4.0c)
- `_shared.md` §12 LEGACY_MODE Context Injection (nếu LEGACY)

---

## Step 4.0: Init Output Directory

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 4.0 | `mkdir -p .mc-data/docs/phase0-brainstorm/policies` | Bash | Directory exists |

---

## Step 4.0a, 4.0b, 4.0c: Spawn 3 Nhóm Agent PARALLEL

> **3 nhóm agent độc lập — chạy PARALLEL.**

### Step 4.0a: P0-01 Drafting

| Step | Hành động | Tool | Verify |
|------|-----------|------|--------|
| 4.0a | Spawn `business-analyst` + `architect` → soạn P0-01 (6 sections theo template `.claude/doc-framework/phase0-brainstorm/P0-01-brainstorm.md`) — input: toàn bộ context Phase 1+2+3 + working files | Agent | Draft đủ 6 sections |

**P0-01 Section structure (6 sections):**

- §1 Thông Tin Cơ Bản: điền từ context Phase 1+2
- §2 Phòng Ban: từ `active_depts[]`
- §3 Phạm Vi Hệ Thống: §3.1 từ brainstorm, §3.2 từ `excluded_scope[]`, §3.3 từ `existing_systems[]`
- §4 Đối Tượng Người Dùng: §4.1 architect + BA phân tích, §4.2 BA tổng hợp nhóm, §4.3 architect nhận xét kiến trúc sơ bộ
- §5 Chính Sách:
  - §5.0 từ `project_complexity` (đánh giá mức cần chính sách)
  - **SIMPLE:** §5.0 ghi "Không cần phân tích chính sách", §5.1-5.3 để trống hoặc ghi "N/A"
  - **STANDARD/ENTERPRISE:** §5.0 + §5.1 từ `compliance_analysis` + §5.2 từ `policy_status[]` + §5.3 từ `final_policy_gaps[]`
- §6 Chốt Khung: tóm tắt + checklist

### Step 4.0b: P0-02 Drafting

| Step | Hành động | Tool | Verify |
|------|-----------|------|--------|
| 4.0b | Spawn `architect` + `business-analyst` → soạn P0-02 (4 sections theo template `.claude/doc-framework/phase0-brainstorm/P0-02-systems-users.md`) — input: platform, modules[], company_size, industry, active_depts[], compliance_analysis | Agent | Draft đủ 4 sections |

**P0-02 Section structure (4 sections):**

- §1 Bản Đồ Hệ Thống: architect phân tích từ platform + modules + ngành
- §2 Users & Roles: BA + domain experts từ ngành + phòng ban
- §3 NFR: architect ước tính từ company_size + industry + volume
- §4 Tech Stack: architect đề xuất (bỏ qua nếu user đã có tech constraints bắt buộc)

### Step 4.0c: Policy Files (STANDARD/ENTERPRISE only)

> _(STANDARD/ENTERPRISE, nếu `final_policy_gaps[]` không rỗng)_

**Bước 1 — Group policies by expert (BẮT BUỘC):**

```
Đọc policy-analysis.md → lấy "Chính Sách Cần Xây Dựng" table
Group theo cột "Agent phụ trách" (§11) → dict: {agent_type: [policy_1, policy_2, ...]}
Spawn 1 agent per expert type (KHÔNG spawn 1 agent per policy)
Nếu số expert types > 5 → batch 5, chạy parallel từng batch
```

**Bước 2 — Agent context template (truyền cho MỖI expert spawn):**

```
Bạn là [domain-expert]. Soạn [N] policy files cho [company_name] — [industry], [company_size].

Context dự án:
- Ngành: [industry] | Mô hình: [business_model] | Mức phức tạp: [STANDARD/ENTERPRISE]
- Pain points: [pain_points[]]

Danh sách policies bạn phụ trách ([N] files):
1. [policy_name_1] — Ưu tiên: [priority] — Nội dung cốt lõi: [content_outline_1]
2. [policy_name_2] — Ưu tiên: [priority] — Nội dung cốt lõi: [content_outline_2]
(liệt kê tất cả policies của expert này)

Template bắt buộc: Đọc .claude/doc-framework/phase0-brainstorm/policies/_policy-template.md
Cấu trúc: 6 sections (Phạm Vi, Nội Dung Chính Sách, Ngoại Lệ, Quy Trình Phê Duyệt, Yêu Cầu Hệ Thống Phải Thực Thi, Xác Nhận)

Với MỖI policy trong danh sách, thực hiện tuần tự:
1. Soạn nội dung đầy đủ (KHÔNG để TODO/TBD/placeholder rỗng)
2. Ghi file: .mc-data/docs/phase0-brainstorm/policies/[ten-khong-dau-kebab-case].md
   VD: chinh-sach-gia.md, chinh-sach-chiet-khau.md, chinh-sach-nhan-su.md
   KHÔNG ghi vào .mc-data/work/ hoặc đường dẫn khác

Ngôn ngữ: Tiếng Việt CÓ DẤU UNICODE trong toàn bộ nội dung
Output mục tiêu: ~800-1200 từ/policy file
```

| Step | Hành động | Tool | Verify |
|------|-----------|------|--------|
| 4.0c | _(STANDARD/ENTERPRISE, nếu `final_policy_gaps[]` không rỗng)_ Group `final_policy_gaps[]` theo `agent_responsible` → **1 agent spawn per expert type** (mỗi spawn nhận TẤT CẢ policies của expert đó) → mỗi agent **ghi thẳng** policy files vào `policies/`. Batch ≤5 experts song song. | Agent (×experts, background) | Mỗi policy đủ 6 sections, đúng path |

**Validation sau khi tất cả agents hoàn thành:**

```bash
# Verify files ở đúng vị trí
ls .mc-data/docs/phase0-brainstorm/policies/*.md
# Nếu có file nhầm trong work/ → xóa ngay
rm -rf .mc-data/work/wf-brainstorm/policies/ 2>/dev/null || true
```

---

## Step 4.1: Ghi P0-01 và P0-02

| Step | Hành động | Tool | Verify |
|------|-----------|------|--------|
| 4.1 | Ghi **P0-01** (draft từ agent 4.0a) và **P0-02** (draft từ agent 4.0b) vào `.mc-data/docs/phase0-brainstorm/`. **Policy files KHÔNG ghi ở đây — đã được agents step 4.0c ghi trực tiếp.** | Write | `test -f P0-01-brainstorm.md && test -f P0-02-systems-users.md` |

---

## Step 4.2: Thông Báo Hoàn Thành

| Step | Hành động | Tool | Verify |
|------|-----------|------|--------|
| 4.2 | Thông báo hoàn thành + hiển thị Output Report (sẽ được hoàn thiện sau Phase 6) + bước tiếp theo | Output | — |

---

## POST-GATE Phase 4 (Cross-Validation Protocol 8)

```
LOAD CONTRACT (BẮT BUỘC):
  contract = Read .claude/doc-framework/phase0-brainstorm/_contract.json
  Nếu không tồn tại → WARN "Contract missing — fallback mode" + dùng count-based checks bên dưới

STRUCTURAL CHECK:
  test -f .mc-data/docs/phase0-brainstorm/P0-01-brainstorm.md
  test -f .mc-data/docs/phase0-brainstorm/P0-02-systems-users.md

CONTRACT-DRIVEN SECTION CHECK (thay thế count-based — Protocol 8):
  1. P0-01: Với mỗi pattern trong contract["P0-01-brainstorm"]["required_sections"]:
     → Grep P0-01 tìm line bắt đầu bằng pattern (startswith matching)
     → Verify section có nội dung thực (>= 2 lines sau header, không chỉ là placeholder)
     → FAIL nếu section thiếu hoặc rỗng → re-run agent cho section đó (max 3 iterations)
  2. P0-02: Với mỗi pattern trong contract["P0-02-systems-users"]["required_sections"]:
     → Grep P0-02 → startswith matching → verify nội dung thực
     → FAIL nếu thiếu/rỗng → re-run agent (max 3 iterations)
  3. Nếu STANDARD/ENTERPRISE: Với mỗi file trong policies/*.md:
     → Với mỗi pattern trong contract["policy-file"]["required_sections"]:
        → Grep file → startswith matching
        → FAIL nếu section thiếu → re-run agent phụ trách policy đó (max 3 iterations)

FALLBACK (chỉ dùng khi contract không tồn tại):
  P0-01: verify file có >= 6 section headers (lines bắt đầu bằng "## ")
  P0-02: verify file có >= 4 section headers
  Policy files: verify mỗi file có >= 6 section headers

CROSS-DOCUMENT VERIFICATION → ghi vào crosscheck-report.md:
  4. Policy file count: đếm *.md trong policies/ → phải khớp với số trong P0-01 §5.3
  5. Policy filename mapping: mỗi policy trong P0-01 §5.3 phải có file tương ứng trong policies/ (tên file kebab-case không dấu, VD: chinh-sach-gia.md)
  6. Systems consistency: systems trong registry == systems trong P0-01 §4 == systems trong P0-02 §1
  7. Departments consistency: departments[] trong registry == phòng ban trong P0-01 §2
  8. Cross-policy thresholds: 4-eyes, SoD, discount thresholds nhất quán giữa các policy files và P0-02
  9. Ghi kết quả vào .mc-data/work/wf-brainstorm/crosscheck-report.md (audit log: lỗi phát hiện, đã sửa, PASS/FAIL)
  10. Nếu có lỗi → tự sửa ngay (max 3 iterations); escalate nếu không sửa được
```

> **Lưu ý:** `crosscheck-report.md` là working file nội bộ — lưu tại `.mc-data/work/wf-brainstorm/`, KHÔNG tạo file nào trong `.mc-data/docs/phase0-brainstorm/` ngoài P0-01, P0-02 và `policies/`. **Phase 0 KHÔNG tạo `stakeholder-review.md`** — file đó chỉ xuất hiện từ Phase 1 trở đi.

> **Lưu ý:** Tại bước 5-6 cross-doc verification, `req-registry.json` chưa được seed (Phase 5 mới seed). Nếu registry chưa tồn tại → bỏ qua check 6-7, ghi note "Registry not yet seeded — verified in Phase 5b". Sẽ được verify lại trong Phase 5 Step 5.3b.

---

## STATUS-UPDATE

> **STATUS-UPDATE(done: phase_4 → start: phase_5):** Update `brainstorm-status.json`:
> - `phases.phase_4.status = "done"`, `phases.phase_4.completed_at = NOW`
> - `current_phase = "phase_5"`, `phases.phase_5.status = "in_progress"`
> - `timestamps.last_updated = NOW`
> - `artifacts.p0_01.created = true`, `artifacts.p0_02.created = true`
> - `artifacts.crosscheck_report.created = true`

---

## Next Phase

→ **`phase5-init-registry.md`** (Khởi Tạo Cấu Trúc Dự Án — TỰ ĐỘNG)
