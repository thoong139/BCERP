# Shared Protocols — wf-brainstorm

> Cross-cutting protocols, reference tables và templates được dùng bởi nhiều Phase.
> KHÔNG đọc file này standalone — chỉ load section cụ thể khi phase file yêu cầu.

## Sections (Navigation)

- [§1 Nguyên Tắc Cốt Lõi & Giao Tiếp](#1-nguyen-tac-cot-loi--giao-tiep)
- [§2 Quy Tắc Ngôn Ngữ & File Output](#2-quy-tac-ngon-ngu--file-output)
- [§3 Template Usage Rule (READ → POPULATE → WRITE)](#3-template-usage-rule)
- [§4 Status Tracking Protocol](#4-status-tracking-protocol)
- [§5 Sequential Question Protocol](#5-sequential-question-protocol)
- [§6 AskUserQuestion Protocol](#6-askuserquestion-protocol)
- [§7 Project Complexity Classification](#7-project-complexity-classification)
- [§8 Agent Roles Per Phase](#8-agent-roles-per-phase)
- [§9 Domain Expert Selection Workflow](#9-domain-expert-selection-workflow)
- [§10 Expert Persona Prompt](#10-expert-persona-prompt)
- [§11 Policy Agent-Responsible Mapping](#11-policy-agent-responsible-mapping)
- [§12 LEGACY_MODE Context Injection](#12-legacy_mode-context-injection)
- [§13 Platform → interface_type Mapping](#13-platform--interface_type-mapping)
- [§14 Fix Rules & Error Handling](#14-fix-rules--error-handling)
- [§15 Phase File Map (Hand-off Routing)](#15-phase-file-map-hand-off-routing)

---

## §1 Nguyên Tắc Cốt Lõi & Giao Tiếp

**2 giai đoạn rõ ràng:**

| Giai đoạn       | Phases       | Mục đích                                                                   | User tham gia                |
| ---------------- | ------------ | ----------------------------------------------------------------------------- | ---------------------------- |
| **Thu thập**  | Phase 1 + 2  | Hỏi thông tin doanh nghiệp, BA khai thác, xác định phòng ban + complexity | Trả lời câu hỏi          |
| **Tự động** | Phase 3-6    | Brainstorm, soạn docs, seed registry, sinh digest                           | Không — chỉ xem kết quả |

> Sau khi thu thập đủ thông tin → chạy tự động hoàn toàn.
> User xem kết quả cuối và tự yêu cầu điều chỉnh nếu cần.

**Quy tắc giao tiếp (Phase 1+2):**

- **Non-technical:** Dùng ngôn ngữ kinh doanh, tránh jargon kỹ thuật
- **1 câu / 1 turn:** KHÔNG gom nhiều câu hỏi vào 1 lượt
- **Không hỏi lại:** Trước mỗi câu hỏi, kiểm tra context tích lũy — skip nếu thông tin đã biết
- **Hỏi đủ cho template:** Đảm bảo thu thập hết thông tin 📝 (user-provided) trong P0-01 template

---

## §2 Quy Tắc Ngôn Ngữ & File Output

**Ngôn ngữ output (BẮT BUỘC):**

- Output PHẢI dùng **tiếng Việt CÓ DẤU UNICODE** (VD: "Thông Tin Cơ Bản", KHÔNG PHẢI "Thong Tin Co Ban")
- Áp dụng cho TẤT CẢ files: P0-01, P0-02, policy files, working files
- **Bất kể ngôn ngữ input của user** — dù user viết tiếng Anh, output vẫn phải tiếng Việt có dấu

**Quy tắc file:**

- **Working files** (biên bản, phân tích trung gian) → `.mc-data/work/wf-brainstorm/`
- **Output files** (kết quả cuối) → `.mc-data/docs/phase0-brainstorm/` — ghi thẳng, KHÔNG qua bước duyệt

---

## §3 Template Usage Rule

Mọi file output có template PHẢI tuân theo **READ → POPULATE → WRITE**:

1. **READ** template file
2. **POPULATE** với dữ liệu thực tế
3. **WRITE** output file vào `.mc-data/`

| Output File | Template Path (READ) |
|------------|---------------------|
| `brainstorm-status.json` | `.claude/skills/workflow/wf-brainstorm/templates/brainstorm-status.json` |
| `project-intent-digest.json` | `.claude/skills/workflow/wf-brainstorm/templates/project-intent-digest.json` |
| `project-digest.json` | `.claude/doc-framework/_digests/project-digest.template.json` |
| `req-registry.json` | `.claude/doc-framework/_meta/req-registry.json` |
| `P0-01-brainstorm.md` | `.claude/doc-framework/phase0-brainstorm/P0-01-brainstorm.md` |
| `P0-02-systems-users.md` | `.claude/doc-framework/phase0-brainstorm/P0-02-systems-users.md` |
| `policies/*.md` | `.claude/doc-framework/phase0-brainstorm/policies/_policy-template.md` |

> **CORE-031:** KHÔNG tạo output từ đầu (ad-hoc). Mọi step tạo file PHẢI ghi rõ "từ template [path]".

---

## §4 Status Tracking Protocol

File `brainstorm-status.json` theo dõi tiến độ xuyên suốt skill. Sau mỗi phase POST-GATE:

1. **READ** `.mc-data/work/wf-brainstorm/brainstorm-status.json`
2. **UPDATE** các fields:
   - `phases.phase_N.status = "done"`, `phases.phase_N.completed_at = [now]` (phase vừa hoàn thành)
   - `current_phase = "phase_{N+1}"` (hoặc `"completed"` nếu phase cuối)
   - `phases.phase_{N+1}.status = "in_progress"` (nếu có phase tiếp)
   - `timestamps.last_updated = [now]`
   - `artifacts.[key].created = true` cho mỗi artifact mới được tạo
3. **WRITE** lại file (atomic)

**Shorthand trong steps:**

```
STATUS-UPDATE(done: phase_N → start: phase_{N+1})
```

---

## §5 Sequential Question Protocol

Mỗi lượt CHỈ hỏi MỘT câu. Trước khi hỏi, kiểm tra context:

- Thông tin đã có đủ → **skip**, chuyển bước tiếp
- Thiếu 1 phần → hỏi phần thiếu, không lặp phần đã biết
- Mỗi câu trả lời được lưu vào context ngay lập tức

---

## §6 AskUserQuestion Protocol

Mọi câu hỏi có lựa chọn PHẢI dùng `AskUserQuestion`:

```
Tool: AskUserQuestion
  question: "[Nội dung câu hỏi]"
  header: "[Chip label ≤12 ký tự]"
  multiSelect: true | false
  options:
    - label: "[Tên 1-5 từ]"
      description: "[Mô tả ngắn]"
```

- `multiSelect: false` → tối đa **10 options**
- `multiSelect: true` → tối đa **10 options**, ★ recommendation đặt đầu tiên + thêm "(Đề xuất)"

---

## §7 Project Complexity Classification

> Đánh giá tại Phase 2 step 2.4. Quyết định mức phân tích chính sách ở Phase 3.

| Mức                 | Tiêu chí                                                                                                                                             | Phân tích chính sách                                                |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------- |
| **SIMPLE**     | Landing page, portfolio, blog, website giới thiệu, API tool đơn lẻ. `active_depts[] ≤ 2`, modules ≤ 5, không keyword quản trị/vận hành    | **KHÔNG** — skip policy analysis hoàn toàn                    |
| **STANDARD**   | SaaS app, marketplace, content platform, ứng dụng có nghiệp vụ quản lý. `active_depts[]` 3-4, modules 6-10                                     | **CHỌN LỌC** — chỉ chính sách core liên quan trực tiếp   |
| **ENTERPRISE** | ERP, CMS quản trị, hệ thống đa phòng ban. `active_depts[] ≥ 5`, hoặc keyword: ERP/CRM/quản trị/vận hành/kho/kế toán/nhân sự/logistics | **ĐẦY ĐỦ** — full policy analysis + proactive recommendation |

**Keywords detect ENTERPRISE:** ERP, CRM, quản trị, vận hành doanh nghiệp, kho bãi, kế toán doanh nghiệp, nhân sự, logistics, xuất nhập khẩu, bán hàng B2B, chuỗi cung ứng, sản xuất, bệnh viện, tài chính doanh nghiệp

**Keywords detect SIMPLE:** landing page, portfolio, blog, giới thiệu, one-page, static, brochure

> **Nguồn scan keywords:** Chỉ scan trong `project_name`, `industry`, `business_model`, `pain_points[]`.
> **KHÔNG scan tên phòng ban** (`active_depts[]`) — "Phòng Vận hành" không phải keyword ENTERPRISE.

**Override rules:**

- **Enterprise override:** Có BẤT KỲ keyword ENTERPRISE trong nguồn scan → `ENTERPRISE` (bất kể số phòng ban)
- **Simple override:** Có keyword SIMPLE + ≤2 depts + ≤5 modules → `SIMPLE`
- **Default:** Không khớp rule nào → `STANDARD`

---

## §8 Agent Roles Per Phase

> Tất cả agents spawn qua `subagent_type`. Lookup vai trò công ty tại `domain-experts.md` Section 5.

| Phase             | Agent (`subagent_type`)                           | Vai trò                                                          |
| ----------------- | --------------------------------------------------- | ----------------------------------------------------------------- |
| **Phase 2** | `business-analyst` (solo)                         | Khai thác thông tin, đề xuất phòng ban, classify complexity |
| **Phase 3** | Domain experts (PARALLEL)                           | Brainstorm requirements + phân tích chính sách (conditional)  |
| **Phase 3** | `legal-expert` + `compliance-expert` (PARALLEL) | Phân tích tuân thủ pháp lý → P0-01 §5.1                   |
| **Phase 3** | `business-analyst` (tổng hợp)                   | Thu kết quả experts → lưu working files                       |
| **Phase 4** | `business-analyst` + `architect`                | Soạn + ghi thẳng P0-01 (6 sections)                             |
| **Phase 4** | `architect` + `business-analyst`                | Soạn + ghi thẳng P0-02 (4 sections)                             |
| **Phase 4** | Domain experts (nếu có policy gaps)               | Soạn + ghi thẳng policy files                                   |

---

## §9 Domain Expert Selection Workflow

Lookup `.claude/references/domain-experts.md`:

```
1. Phase 2 step 2.3: Detect ngành từ context
   → Scan keywords → lookup Section 4 (Keyword Detection) → detected_industries[]

2. Phase 2 step 2.3: BA đề xuất departments[]
   → Lookup Section 3 (Industry → Departments) → user confirm → active_depts[]

3. Phase 3 step 3.1: Resolve experts từ active_depts[]
   → Section 1 (Department → Expert Mapping): Primary + Supporting → Union → Dedup
   → So sánh Section 2 (Multi-System Patterns) → bổ sung nếu khớp
   → Spawn PARALLEL (batch 5 nếu > 5)
```

---

## §10 Expert Persona Prompt

Mỗi domain expert đã có domain knowledge sẵn. Expert Persona Prompt **chuyển vai trò**: từ "DEVKIT consultant" → "Trưởng phòng [X] tại công ty user".

**Format — SIMPLE projects:**

```
Bạn đóng vai [vai trò từ domain-experts.md §5] tại [company_name] — [industry], [company_size].

Bối cảnh dự án:
- Vấn đề đang gặp: [pain_points[]]
- Mục tiêu dự án: [project_goal]
- Thông tin bổ sung từ BA: [ba_followup_context[]]

Đưa ra góc nhìn từ phòng ban:
1. **Yêu cầu quan trọng nhất** (3-5 điểm)
2. **Lo ngại chính** (2-3 điểm)
3. **Đề xuất modules ưu tiên** (2-4 modules)

Output mục tiêu: ~300-500 từ. Súc tích, đủ ý, không lặp context đã biết.
```

**Format — STANDARD/ENTERPRISE projects (thêm phần chính sách):**

```
Bạn đóng vai [vai trò từ domain-experts.md §5] tại [company_name] — [industry], [company_size].

Bối cảnh dự án:
- Vấn đề đang gặp: [pain_points[]]
- Mục tiêu dự án: [project_goal]
- Thông tin bổ sung từ BA: [ba_followup_context[]]
- Mức phức tạp: [STANDARD/ENTERPRISE]
- Chính sách đã có: [policy_status[] — các chính sách user đã đánh dấu "Đã có"]

Đưa ra góc nhìn từ phòng ban:
1. **Yêu cầu quan trọng nhất** (3-5 điểm)
2. **Lo ngại chính** (2-3 điểm)
3. **Đề xuất modules ưu tiên** (2-4 modules)
4. **Chính sách cần thiết cho phòng ban** (2-5 chính sách)
   Với mỗi chính sách:
   - Tên chính sách
   - Tại sao cần (liên quan module/nghiệp vụ nào)
   - Mức ưu tiên: Bắt buộc / Nên có / Tùy chọn
   - Nội dung cốt lõi cần quy định (3-5 bullet points)
5. **Quy trình kiểm soát** cần xây dựng (1-3 quy trình)

Output mục tiêu: ~500-800 từ. Súc tích, đủ ý, không lặp context đã biết.
```

---

## §11 Policy Agent-Responsible Mapping

Dùng tại Phase 3.3b (gán `agent_responsible` cho mỗi policy) và Phase 4.0c (group spawning).

| Lĩnh vực chính sách | `agent_responsible` |
|---------------------|---------------------|
| Bán hàng / Giá / Chiết khấu / Hoa hồng / Đổi trả | `sales-expert` |
| Nhân sự / Lương / Phúc lợi / Tuyển dụng / Nghỉ phép | `hr-expert` |
| Tài chính / Thanh toán / Công nợ / Ngân sách / Phê duyệt chi | `finance-expert` |
| Kho / Xuất nhập kho / FIFO / Kiểm kho | `operations-expert` |
| Mua hàng / Thu mua / Nhà cung cấp / RFQ | `procurement-expert` |
| Khách hàng / CSKH / SLA / Phân loại KH / After-sales | `customer-expert` |
| Pháp lý / Hợp đồng / GDPR / NDA | `legal-expert` |
| Logistics / Vận chuyển / Giao nhận | `logistics-expert` |
| Marketing / Quảng cáo / Brand / Campaign | `marketing-expert` |
| Tuân thủ / Kiểm soát nội bộ / Audit / AML | `compliance-expert` |
| Chất lượng / QMS / ISO / FMEA | `quality-excellence-expert` |
| Rủi ro / ERM / GRC / Risk appetite | `enterprise-risk-expert` |
| Công nghệ / IT Governance / Change Management / SLA nội bộ IT | `sre` |
| Bảo mật dữ liệu / Backup / Recovery / BCP / Incident Response IT | `enterprise-risk-expert` |
| Không khớp rõ ràng | `business-analyst` (fallback) |

**Policy gap merge logic (STANDARD/ENTERPRISE):**

1. Lấy `policy_gaps[]` từ Phase 2 (user đánh dấu "Chưa có" / "Có 1 phần")
2. Lấy `policy_expert_recommendations[]` từ `brainstorm-notes.md` (section "Chính sách đề xuất" của từng expert)
3. **Merge:** Union cả hai → dedup theo tên/lĩnh vực → `final_policy_gaps[]`
4. Experts có thể đề xuất chính sách mà user KHÔNG nghĩ tới → thêm vào gaps
5. **Assign `agent_responsible`** theo bảng trên

---

## §12 LEGACY_MODE Context Injection

> Áp dụng cho TẤT CẢ agent spawns trong flow này. Mỗi lần spawn agent, thêm LEGACY_CONTEXT vào prompt nếu LEGACY_MODE = true.

```
IF LEGACY_MODE:
  Mỗi agent prompt PHẢI bao gồm:
  ---
  ## PROJECT REFERENCE MATERIAL (Dự án cũ — tham chiếu)

  [Nội dung project-context.md — Sections 1-6]

  ## Ý định của User
  [Nội dung user_intent.md]

  ## Hướng dẫn sử dụng Reference Material:
  - Thông tin có trust_level = HIGH → ưu tiên sử dụng
  - Thông tin có trust_level = MEDIUM → kiểm chứng với code trước khi dùng
  - Thông tin có trust_level = LOW → chỉ tham khảo, không làm primary source
  - Nếu reference material thiếu hoặc sai → xây dựng dựa trên best practices
  - KHÔNG bị giới hạn bởi reference material — hãy CẢI THIỆN nếu cần

  ## Quyết định của User (legacy-decisions.json)
  [Đọc và inject nội dung .mc-data/work/wf-brainstorm/legacy-decisions.json]

  Áp dụng BẮT BUỘC:
  - Modules có action = "DEPRECATE" → KHÔNG tạo requirements/features/design cho module này
  - Modules có action = "KEEP" → giữ nguyên, không redesign trừ khi user yêu cầu
  - divergence_resolutions: với mỗi conflict đã resolve → follow decision (trust_code/trust_docs/manual)
  - scope_exclusions: KHÔNG đưa các items này vào bất kỳ output nào
  ---
```

---

## §13 Platform → interface_type Mapping

Dùng tại Phase 5.3 khi seed `req-registry.json`:

| Câu trả lời user (Phase 1.4) | `interface_type` value |
|------------------------------|------------------------|
| Web / Chỉ web / Web app | `"web"` |
| Mobile / Chỉ mobile / App | `"mobile"` |
| Cả hai / Web + Mobile / Web và Mobile | `"web+mobile"` |
| API / Backend only / Không có UI | `"api-only"` |
| Chưa xác định / Chưa biết | `"web"` (default — cập nhật sau khi rõ hơn) |

> ⚠️ Nếu user không đề cập platform ở Phase 1.4 → mặc định `"web"`, ghi chú `[Cần xác nhận]` vào P0-01 §1.

---

## §14 Fix Rules & Error Handling

**Skill-specific Fix Rules:**

| Error Type          | Auto-Fix Strategy                                          | Escalate If                     |
| ------------------- | ---------------------------------------------------------- | ------------------------------- |
| `missing_info`    | Đánh dấu `[Cần làm rõ]`, BA hỏi follow-up Phase 2 | User từ chối cung cấp 3 lần |
| `vague_answer`    | Chấp nhận as-is, lưu context                            | —                              |
| `no_dept_match`   | BA tự tổng hợp scope theo `detected_industries[]`     | —                              |
| `agent_fail`      | BA tự tổng hợp; log warning                             | —                              |
| `file_write_fail` | Retry 3 lần                                               | Permission denied               |

**Error Handling (toàn skill):**

| Code | Tình huống                             | Xử lý                                                             |
| ---- | ---------------------------------------- | ------------------------------------------------------------------- |
| E001 | User trả lời quá ngắn Phase 1        | BA hỏi follow-up Phase 2, đánh dấu `[Cần làm rõ]`          |
| E002 | User không biết phòng ban             | BA đề xuất (step 2.3), user chỉ cần confirm                    |
| E003 | User không có chính sách nào        | Tất cả → "Chưa có", experts chủ động đề xuất + soạn     |
| E004 | Không khớp domain-experts.md §1       | BA tự tổng hợp scope theo `detected_industries[]`; log warning |
| E005 | Agent spawn fail                         | BA tự tổng hợp; log warning                                      |
| E006 | File write fail                          | Retry 3 lần, sau đó escalate                                     |
| E007 | User đã có requirements rõ ràng     | Gợi ý: `/wf-analyze-requirements` trực tiếp                    |
| E008 | File P0-01/P0-02 đã tồn tại          | Tự động ghi đè (Phase 0 brainstorm — safe to overwrite)       |
| E009 | User yêu cầu điều chỉnh sau khi xem | Chỉnh sửa file trực tiếp theo yêu cầu, không chạy lại      |

---

## §15 Phase File Map (Hand-off Routing)

> Pipeline tuyến tính: mỗi phase đọc file kế tiếp khi POST-GATE PASS.

| Phase File | Vai trò | Điều kiện chạy |
|------------|--------|----------------|
| `phase0-detect-route.md` | Auto-detect NEW/LEGACY, prepare context | LUÔN — entry point |
| `phase0-5-legacy-snapshot.md` | Hiển thị legacy snapshot, thu thập user intent, tạo legacy-decisions.json | CHỈ khi `LEGACY_MODE = true` |
| `phase1-collect-basic.md` | 4 câu hỏi cơ bản về doanh nghiệp | LUÔN |
| `phase2-ba-departments.md` | BA khai thác + departments + complexity + policy survey | LUÔN |
| `phase3-brainstorm-policy.md` | Spawn domain experts PARALLEL + tổng hợp + policy gap analysis | LUÔN |
| `phase4-write-docs.md` | Soạn & ghi P0-01, P0-02, policies (PARALLEL) + cross-check | LUÔN |
| `phase5-init-registry.md` | Seed req-registry.json + project-intent-digest.json + scaffolding tối thiểu | LUÔN |
| `phase6-generate-digest.md` | Sinh project-digest.json + finalize status | LUÔN |

**Hand-off rule:** Mỗi phase file kết thúc bằng section `## Next Phase` chỉ rõ file kế tiếp. KHÔNG nhảy phase ngoài thứ tự.
