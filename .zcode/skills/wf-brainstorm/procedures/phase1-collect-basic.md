# Phase 1: Thu Thập Thông Tin Cơ Bản (THU THẬP)

> 3-4 câu hỏi không kỹ thuật — thu thập thông tin cho P0-01 Section 1.
> Nếu `$ARGUMENTS` hoặc câu trước đã chứa thông tin → skip câu hỏi tương ứng.
> Cũng tạo `brainstorm-status.json` để track progress xuyên suốt skill.

**PRE-GATE:**

- [ ] Phase 0 (phase0-detect-route.md) POST-GATE PASS
- [ ] Nếu LEGACY: Phase 0.5 (phase0-5-legacy-snapshot.md) POST-GATE PASS
- [ ] `$PROJECT_TYPE`, `$LEGACY_MODE`, `project_name` (optional), `force_flag` đã set

**INPUT:** User context (từ `$ARGUMENTS` hoặc câu hỏi)

**OUTPUT:**
- `.mc-data/work/wf-brainstorm/brainstorm-status.json` (init từ template)
- Context fields: `company_name`, `industry`, `company_size`, `business_model`, `pain_points[]`, `existing_systems[]`, `excluded_scope[]`, `platform`

---

## Reference Sections

- `_shared.md` §1 Nguyên Tắc Cốt Lõi & Giao Tiếp
- `_shared.md` §3 Template Usage Rule
- `_shared.md` §4 Status Tracking Protocol
- `_shared.md` §5 Sequential Question Protocol

---

## PRE-GATE Branch — Check Existing `.mc-data/`

```
IF test -d .mc-data:
  IF $LEGACY_MODE = true AND NOT $force_flag:
    → Auto-select "Merge" — không hỏi
    → Log: "Legacy project detected — keeping existing .mc-data/, creating missing files only"

  ELSE IF $LEGACY_MODE = true AND $force_flag:
    → Cảnh báo: "⚠️ --force trên dự án legacy sẽ xóa toàn bộ .mc-data/ bao gồm legacy-scan data. Xác nhận?"
    → Chờ user confirm trước khi rm -rf

  ELSE IF NOT $force_flag (NEW project, có .mc-data sẵn):
    → AskUserQuestion: Reset / Backup / Merge / Cancel

  ELSE ($force_flag = true, NOT LEGACY):
    → rm -rf .mc-data/

ELSE:
  → Tiếp tục — không có gì cần xử lý
```

---

## Step 1.0: Parse Arguments (đã thực hiện ở Phase 0)

| Step | Action | Tool | Lưu vào context |
|------|--------|------|-----------------|
| 1.0 | (Đã thực hiện ở phase0-detect-route.md Step 0.3) — verify `project_name`, `force_flag` đã set | — | `project_name`, `force_flag` |

---

## Step 1.0b: Khởi tạo `brainstorm-status.json`

> Template Usage Rule (§3): READ → POPULATE → WRITE.

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 1.0b.1 | `mkdir -p .mc-data/work/wf-brainstorm/` | Bash | Directory exists |
| 1.0b.2 | READ template `.claude/skills/workflow/wf-brainstorm/templates/brainstorm-status.json` | Read | Template loaded |
| 1.0b.3 | POPULATE: `project = $project_name`, `status = "in_progress"`, `current_phase = "phase_1"`, `phases.phase_1.status = "in_progress"`, `phases.phase_1.started_at = NOW`, `timestamps.started_at = NOW`, `timestamps.last_updated = NOW` | — | Fields populated |
| 1.0b.4 | WRITE `.mc-data/work/wf-brainstorm/brainstorm-status.json` | Write | `test -f brainstorm-status.json` |

---

## Step 1.1-1.4: Hỏi Thông Tin Cơ Bản (Sequential — §5)

| Step | Hành động | Tool | Lưu vào context |
|------|-----------|------|-----------------|
| 1.1 | Chào: "Tôi sẽ hỏi vài câu đơn giản về doanh nghiệp — không cần biết kỹ thuật. Sau đó đội chuyên gia sẽ phân tích và thảo luận cùng bạn." | Output | — |
| 1.2 | **"Tên công ty, ngành nghề và quy mô của bạn?"** | Output | `company_name`, `industry`, `company_size` |
| 1.3 | **"Doanh nghiệp kiếm tiền bằng cách nào? Khó khăn gì khiến bạn muốn xây phần mềm?"** | Output | `business_model`, `pain_points[]` |
| 1.4 | **"Đang dùng phần mềm gì? Có mảng nào KHÔNG muốn làm? Muốn xây Web, Mobile hay cả hai?"** | Output | `existing_systems[]`, `excluded_scope[]`, `platform` |

> **Skip rule (§5):** Nếu user đã cung cấp thông tin ở câu trước → skip câu tương ứng, chuyển bước tiếp.
> VD: User ở 1.2 nói "Công ty ABC, XNK, 80 người, đang dùng MISA" → skip phần `existing_systems` ở 1.4.

---

## POST-GATE Phase 1

- T1: Context có đủ 3 fields tối thiểu: `company_name`, `industry`, `pain_points[]`
- T2: `test -f .mc-data/work/wf-brainstorm/brainstorm-status.json`
- T3: `jq -e '.current_phase == "phase_1" and .phases.phase_1.status == "in_progress"' brainstorm-status.json`

> **STATUS-UPDATE(done: phase_1 → start: phase_2):** Update `brainstorm-status.json`:
> - `phases.phase_1.status = "done"`, `phases.phase_1.completed_at = NOW`
> - `current_phase = "phase_2"`, `phases.phase_2.status = "in_progress"`
> - `timestamps.last_updated = NOW`

---

## Next Phase

→ **`phase2-ba-departments.md`** (BA Khai Thác & Phòng Ban)
