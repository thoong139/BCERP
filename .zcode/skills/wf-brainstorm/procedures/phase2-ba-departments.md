# Phase 2: BA Khai Thác & Phòng Ban (THU THẬP)

> BA phân tích Phase 1, hỏi follow-up, xác định phòng ban, đánh giá phức tạp, khảo sát chính sách.
> BA chủ động dẫn dắt — user chỉ cần trả lời và confirm.
> **Tối ưu:** Gộp internal processing vào transitions — 5 steps, 2-3 lượt hỏi user.

**PRE-GATE:**

- [ ] Phase 1 (phase1-collect-basic.md) POST-GATE PASS
- [ ] Context có: `company_name`, `industry`, `pain_points[]` (tối thiểu)
- [ ] `brainstorm-status.json` exists, `current_phase = "phase_2"`

**INPUT:** Toàn bộ context Phase 1

**OUTPUT (lưu vào context):**
- `ba_questions[]`, `ba_followup_context[]`
- `project_context_summary`, `detected_industries[]`, `active_depts[]`
- `project_complexity` (SIMPLE/STANDARD/ENTERPRISE)
- `policy_status[]`, `policy_gaps[]` (STANDARD/ENTERPRISE only)

---

## Reference Sections

- `_shared.md` §5 Sequential Question Protocol
- `_shared.md` §6 AskUserQuestion Protocol
- `_shared.md` §7 Project Complexity Classification (BẮT BUỘC đọc trước Step 2.4)
- `_shared.md` §9 Domain Expert Selection Workflow
- `_shared.md` §12 LEGACY_MODE Context Injection (nếu LEGACY)
- `_shared.md` §14 Fix Rules

---

## Step 2.1: BA Spawn — Generate Follow-up Questions

| Step | Hành động | Tool | Lưu vào context |
|------|-----------|------|-----------------|
| 2.1 | Spawn `business-analyst` (subagent_type) → phân tích Phase 1 → "Chuyên gia phân tích có thêm vài câu hỏi:" → tạo **≤3 câu follow-up** (timeline, tech constraints, mô hình vận hành, excluded scope...) | Agent (×1) → Output | `ba_questions[]` |

> Nếu LEGACY_MODE: prompt agent inject `$LEGACY_CONTEXT` + `legacy-decisions.json` (xem §12).

---

## Step 2.2: Hỏi Follow-up Questions (1 câu/turn)

| Step | Hành động | Tool | Lưu vào context |
|------|-----------|------|-----------------|
| 2.2 | Hỏi lần lượt `ba_questions[]` — **1 câu/turn** — skip nếu đã biết từ Phase 1 | Output / AskUserQuestion | `ba_followup_context[]` |

---

## Step 2.3: Tóm Tắt + Detect Industries + Đề Xuất Departments

> Gộp tóm tắt + detect + đề xuất trong 1 step liền mạch.

```
Sau khi thu thập đủ ba_followup_context[], BA thực hiện liền mạch:

IF $LEGACY_MODE = true:
  Đọc .mc-data/work/legacy-scan/module-code-mapping.json
  Extract: danh sách module names thực tế trong code
  Dùng trong reasoning bước detect + đề xuất:
    "## Codebase Structure (từ code scan — HIGH trust)
     Các modules thực tế đã có trong code: [list từ module-code-mapping.json]
     ⚠️ Ưu tiên map departments dựa trên structure này.
     Chỉ đề xuất departments phù hợp với modules trên."

1. Tóm tắt bối cảnh → hiển thị cho user (tạo trust)
2. Detect industries: scan keywords → domain-experts.md §4 → detected_industries[]
3. Lookup §3 → đề xuất departments → trình AskUserQuestion
```

| Step | Hành động | Tool | Lưu vào context |
|------|-----------|------|-----------------|
| 2.3 | BA tóm tắt bối cảnh (2-3 câu) → detect industries (`domain-experts.md` §4) → đề xuất phòng ban (§3) → **"Phòng ban nào sẽ tham gia?"** — top 10 (★ = phù hợp nhất) | AskUserQuestion (multiSelect: true) | `project_context_summary`, `detected_industries[]`, `active_depts[]` |

> User thấy: tóm tắt ngắn + danh sách phòng ban để chọn. Internal processing ẩn phía sau.

---

## Step 2.4: Auto-Classify Complexity + Conditional Policy Survey

### (a) Classify complexity (tự động ngay sau user chọn phòng ban)

> Đọc `_shared.md` §7 để biết override rules.

```
1. Đếm active_depts[]: ≤2 → SIMPLE; 3-4 → STANDARD; ≥5 → ENTERPRISE
2. Scan keywords ENTERPRISE trong project_name + industry + business_model + pain_points[]:
   ERP, CRM, quản trị, vận hành doanh nghiệp, kho bãi, kế toán, nhân sự, logistics, chuỗi cung ứng, sản xuất
   ⚠️ KHÔNG scan active_depts[] — tên phòng ban (VD: "Phòng Vận hành") không phải keyword
3. Scan keywords SIMPLE (cùng nguồn): landing page, portfolio, blog, giới thiệu, one-page, static
4. Enterprise override: Có BẤT KỲ keyword ENTERPRISE → ENTERPRISE
5. Simple override: Có keyword SIMPLE + ≤2 depts + ≤5 modules → SIMPLE
6. Default: → STANDARD
```

### (b) Conditional policy survey (ngay sau classify)

| `project_complexity` | Hành động |
|----------------------|-----------|
| **SIMPLE** | **SKIP** — `policy_status[] = []`, `policy_gaps[] = []` → thẳng Step 2.5 |
| **STANDARD** | Hiện **3-5 chính sách core** phù hợp `industry` + `active_depts[]`. User đánh dấu |
| **ENTERPRISE** | Hiện **full checklist** (filter P0-01 §5.2 theo ngành + phòng ban) + cho phép thêm đặc thù |

- User đánh dấu: Đã có / Có 1 phần / Chưa có
- Không rõ → mặc định "Chưa có"
- `policy_gaps[]` = "Chưa có" + "Có 1 phần"

### ⚠️ ENTERPRISE — xử lý khi checklist > 10 items

> AskUserQuestion giới hạn 10 options/call. Chia thành **2 lần hỏi** theo nhóm, dùng header rõ ràng:

1. **Nhóm Thương mại & Khách hàng:** bảng giá, chiết khấu, đổi trả, phân loại KH, công nợ, hợp đồng (tối đa 10)
2. **Nhóm Vận hành & Nội bộ:** kho, mua hàng, nhân sự, tài chính, tuân thủ, kiểm soát nội bộ (tối đa 10)

Merge kết quả 2 lần hỏi trước khi tính `policy_gaps[]`.

| Step | Hành động | Tool | Lưu vào context |
|------|-----------|------|-----------------|
| 2.4a | Classify complexity (auto) | — | `project_complexity` |
| 2.4b | Conditional policy survey (skip nếu SIMPLE) | AskUserQuestion (multiSelect) | `policy_status[]`, `policy_gaps[]` |

---

## Step 2.5: Xác Nhận Trước Phase 3

| Step | Hành động | Tool | Lưu vào context |
|------|-----------|------|-----------------|
| 2.5 | Hiển thị tóm tắt: "Sẵn sàng brainstorm với **[N] chuyên gia** cho **[N] phòng ban** (độ phức tạp: **[COMPLEXITY]**). Tôi sẽ tự động phân tích và soạn tài liệu — không cần bạn làm thêm gì. Tiếp tục?" → User confirm | Output / AskUserQuestion | User xác nhận hoặc điều chỉnh scope |

> **Mục đích:** Tạo cơ hội cuối để user điều chỉnh phòng ban / scope trước khi spawn agents. Nếu user confirm → Phase 3 tự động hoàn toàn. Nếu user muốn điều chỉnh → quay lại Step 2.3.

---

## POST-GATE Phase 2

- T1: `active_depts[]` non-empty
- T2: `project_context_summary` non-empty
- T3: `project_complexity` ∈ {SIMPLE, STANDARD, ENTERPRISE}
- T4: Nếu STANDARD/ENTERPRISE: `policy_status[]` non-empty
- T5: User đã confirm ở Step 2.5

> **STATUS-UPDATE(done: phase_2 → start: phase_3):** Update `brainstorm-status.json`:
> - `phases.phase_2.status = "done"`, `phases.phase_2.completed_at = NOW`
> - `current_phase = "phase_3"`, `phases.phase_3.status = "in_progress"`
> - `timestamps.last_updated = NOW`

---

## Next Phase

→ **`phase3-brainstorm-policy.md`** (Brainstorm & Phân Tích Chính Sách — TỰ ĐỘNG)
