# Fix Patterns — FP1 đến FP9

> Fix patterns áp dụng cho findings từ `audit-devkit-scan` liên quan đến Master Plan.
> **Load ON-DEMAND:** Phase 1 chỉ đọc section tương ứng với finding đang xử lý.
> Mỗi pattern: **Trigger** (điều kiện kích hoạt) → **Fix** (hành động) → **Verify** (kiểm tra ngay sau).
>
> **HIGH-RISK patterns (CDG-02) → YÊU CẦU CONFIRM từ user trước khi apply.**

---

## FP1: Hook 2-Tầng Missing

| Thuộc tính | Giá trị |
|-----------|---------|
| **Risk** | MEDIUM — sửa logic hook hiện có |
| **Category** | STRUCTURAL |
| **Confirm trước khi apply** | Khuyến nghị (hỏi user nếu hook phức tạp) |
| **Priority** | 1 (Structural) |

**Trigger:**
- Scan phát hiện: file trong `.claude/hooks/*.sh` (trừ `_hook-utils.sh`) không có `hook_detect_tier_mode` hoặc không có `source _hook-utils.sh`

**Fix (theo thứ tự):**
1. Đọc `.claude/hooks/_hook-utils.sh` → xác nhận hàm `hook_detect_tier_mode` tồn tại
2. Đọc hook file → xác định vị trí shebang (`#!/bin/bash`)
3. Inject `source "${BASH_SOURCE%/*}/_hook-utils.sh"` ngay sau dòng shebang (nếu chưa có)
4. Xác định điểm phù hợp để gọi tier detection (thường sau khi parse arguments, trước logic chính)
5. Inject `hook_detect_tier_mode` call — ADDITIVE, không xóa logic cũ

**Verify ngay sau fix:**
```
V1: bash -n <hook-file> → exit code 0 (syntax valid)
V2: Grep 'source.*_hook-utils.sh' <hook-file> → count ≥ 1
V3: Grep 'hook_detect_tier_mode' <hook-file> → count ≥ 1
V4: Grep 'MCV3_HOOK_TIER' <hook-file> (nếu hàm dùng biến này) → count ≥ 0 (optional check)
```

---

## FP2: Checkpoint Schema Missing `context_digest`

| Thuộc tính | Giá trị |
|-----------|---------|
| **Risk** | LOW — thêm field mới, không xóa |
| **Category** | STRUCTURAL |
| **Confirm trước khi apply** | Không cần |
| **Priority** | 1 (Structural) |

**Trigger:**
- Scan phát hiện: `.claude/skills/schemas/checkpoint-schema.json` không có field `context_digest`

**Fix:**
1. Đọc `checkpoint-schema.json` → lưu original content
2. Thêm `context_digest` object với đủ 6 subfields theo chuẩn Master Plan Section 4.1:
   - `feature_summary` (string)
   - `architectural_decisions` (array)
   - `interfaces_established` (object)
   - `patterns_in_use` (object)
   - `cross_batch_contracts` (object)
   - `gotchas_and_warnings` (array)
3. Edit file — ADDITIVE, không sửa các fields hiện có

**Verify ngay sau fix:**
```
V1: jq '.' .claude/skills/schemas/checkpoint-schema.json → exit code 0 (valid JSON)
V2: jq '.context_digest' checkpoint-schema.json → non-null
V3: jq '.context_digest | keys' checkpoint-schema.json → phải chứa đủ 6 subfields
V4: Grep 'context_digest' checkpoint-schema.json → count ≥ 1
```

**`edit_type`:** `ADDITIVE` — Phase 1 verify 3a skip check `old_value = 0`.

---

## FP3: Digest Template Missing

| Thuộc tính | Giá trị |
|-----------|---------|
| **Risk** | HIGH — tạo file mới (xem NGOẠI LỆ trong `_shared.md` §Auto-Fix Limits) |
| **Category** | STRUCTURAL |
| **Confirm trước khi apply** | **BẮT BUỘC — CDG-02** (tạo file mới) |
| **Priority** | 1 (Structural) |

**Trigger:**
- Scan phát hiện: `.claude/doc-framework/_digests/` thiếu 1+ trong 6 templates:
  - `project-digest.template.json`
  - `dept-digests.template.json`
  - `phase1-handoff.template.json`
  - `feature-briefs.template.json`
  - `design-input-digest.template.json`
  - `ux-input-digest.template.json`

**Fix (cho từng template còn thiếu):**
1. **CDG-02 Confirmation (BẮT BUỘC):** Hiển thị cho user theo template `protocols/16-critical-decision-gate.md §16.4` — mô tả file sẽ tạo + nội dung dự kiến → chờ confirm
2. Chờ user confirm → KHÔNG tự động apply
3. Sau khi có confirm: Write file từ structure chuẩn trong Master Plan Section 4.3
4. Lưu ý: Nếu có ≥ 1 template khác đã tồn tại → tham khảo để giữ format nhất quán
5. Ghi CDG decision vào execution trace (Protocol §15)

**Verify ngay sau fix:**
```
V1: Glob <template-path> → file EXISTS
V2: jq '.' <template-path> → exit code 0 (valid JSON)
V3: Đọc file → xác nhận có đúng required fields theo chuẩn từng template
```

---

## FP4: Producer/Consumer Skill Missing Digest Step

| Thuộc tính | Giá trị |
|-----------|---------|
| **Risk** | HIGH — sửa SKILL.md của workflow skill |
| **Category** | STRUCTURAL |
| **Confirm trước khi apply** | **BẮT BUỘC — CDG-02** (sửa SKILL.md của workflow skill) |
| **Priority** | 1 (Structural) |

**Trigger:**
- Scan phát hiện skill SKILL.md thiếu digest generation step (producer) hoặc digest loading step (consumer):
  - PRODUCER skills: `wf-brainstorm`, `wf-analyze-requirements`, `wf-define-features`, `wf-design`, `wf-design-ux`
  - CONSUMER skills: `wf-analyze-requirements`, `wf-define-features`, `wf-design`, `wf-design-ux`, `wf-plan-modules`, `wf-implement-feature`

**Fix:**
1. Xác định loại: PRODUCER → thiếu step trong POST-GATE; CONSUMER → thiếu step trong PRE-GATE
2. Đọc SKILL.md → xác định vị trí PRE-GATE hoặc POST-GATE hiện có
3. Hiển thị cho user: proposed step content + vị trí sẽ thêm → chờ confirm
4. Sau confirm: Edit SKILL.md — ADDITIVE ONLY, chỉ thêm step, không sửa steps hiện có
5. Không thay đổi logic, không sửa phase numbers, không xóa content

**Verify ngay sau fix:**
```
V1: Grep 'digest' <SKILL.md> → count sau fix ≥ count trước fix + 1
V2: Đọc file → xác nhận step mới nằm đúng vị trí (POST-GATE hoặc PRE-GATE)
V3: Kiểm tra total line count của file không giảm (không mất content)
V4: Grep existing PRE-GATE/POST-GATE keywords → vẫn tồn tại (không bị xóa)
```

**`edit_type`:** `ADDITIVE` — Phase 1 verify 3a skip.

---

## FP5: Task Template Missing A6-EXT/A7-EXT

| Thuộc tính | Giá trị |
|-----------|---------|
| **Risk** | MEDIUM — sửa task file template |
| **Category** | STRUCTURAL |
| **Confirm trước khi apply** | Khuyến nghị (hiển thị section sẽ thêm) |
| **Priority** | 1 (Structural) |

**Trigger:**
- Scan phát hiện: task file template trong `.claude/doc-framework/phase5-implementation/tasks/` thiếu section `A6-EXT` hoặc `A7-EXT`

**Fix:**
1. Đọc template file → xác định vị trí section A5 hoặc A6 cuối cùng
2. **Nếu thiếu A6-EXT:** Thêm section theo chuẩn Master Plan Section 4.2 sau section A6 — bao gồm file specs, columns, methods, test cases skeleton
3. **Nếu thiếu A7-EXT:** Thêm section theo chuẩn Master Plan Section 4.4 — bao gồm `micro_task_id`, `estimated_time`, `input`, `output`, `success_criteria`
4. ADDITIVE ONLY — không sửa A1-A5 hiện có

**Verify ngay sau fix:**
```
V1: Grep 'A6-EXT' <template-path> → count ≥ 1
V2: Grep 'A7-EXT' <template-path> → count ≥ 1 (nếu cả hai thiếu)
V3: Đọc file → xác nhận structure của section mới đúng format (heading + required subsections)
V4: Kiểm tra không mất sections A1-A5 (grep từng section)
```

**`edit_type`:** `ADDITIVE` — Phase 1 verify 3a skip.

---

## FP6: Parallel Flags Missing

| Thuộc tính | Giá trị |
|-----------|---------|
| **Risk** | HIGH — sửa SKILL.md của `wf-implement-feature` |
| **Category** | STRUCTURAL |
| **Confirm trước khi apply** | **BẮT BUỘC — CDG-02** |
| **Priority** | 1 (Structural) |

**Trigger:**
- Scan phát hiện: `wf-implement-feature` SKILL.md thiếu `--parallel` hoặc `--features` trong Arguments section

**Fix:**
1. Đọc `.claude/skills/workflow/wf-implement-feature/SKILL.md` → xác định Arguments table
2. **Nếu thiếu `--parallel`:** Thêm dòng vào Arguments table:
   `| \`--parallel\` | Chạy implement song song nhiều features (dùng với --features) | - |`
3. **Nếu thiếu `--features`:** Thêm dòng vào Arguments table:
   `| \`--features=<id1,id2,...>\` | Danh sách feature IDs cần implement (dùng với --parallel) | - |`
4. Nếu Phase 2.5 (Contract Generation) chưa tồn tại → thêm vào MANUAL list (quá phức tạp cho auto-fix)
5. ADDITIVE ONLY — không sửa flags hiện có

**Verify ngay sau fix:**
```
V1: Grep '\-\-parallel' <SKILL.md> → count ≥ 1
V2: Grep '\-\-features' <SKILL.md> → count ≥ 1
V3: Đọc Arguments section → xác nhận flag documentation hoàn chỉnh (có description)
V4: Kiểm tra không mất existing flags (total rows trong Arguments table ≥ trước fix)
```

**`edit_type`:** `ADDITIVE` — Phase 1 verify 3a skip.

---

## FP7: SKILL.md Structural Addition

| Thuộc tính | Giá trị |
|-----------|---------|
| **Risk** | HIGH — sửa SKILL.md workflow skills |
| **Category** | STRUCTURAL |
| **Confirm trước khi apply** | **BẮT BUỘC — CDG-02** |
| **Priority** | 1 (Structural) |

**Trigger:**
- Scan phát hiện SKILL.md thiếu markers/steps/error codes

**Fix:**
1. Edit SKILL.md — ADDITIVE ONLY (thêm step/marker, không sửa/xóa steps hiện có)
2. Thêm PRE-GATE/POST-GATE markers nếu thiếu
3. Thêm steps theo chuẩn workflow
4. Thêm error codes theo schema

**Verify ngay sau fix:**
```
V1: Grep marker/step mới trong SKILL.md → count ≥ 1
V2: Verify existing markers vẫn intact (không bị xóa/sửa)
V3: Validate YAML/JSON syntax nếu có frontmatter/schema changes
```

---

## FP8: Agent Section Fix

| Thuộc tính | Giá trị |
|-----------|---------|
| **Risk** | MEDIUM — sửa agent section headers/terminology |
| **Category** | STRUCTURAL |
| **Confirm trước khi apply** | Khuyến nghị (nhiều files cùng loại thì batch confirm) |
| **Priority** | 1 (Structural) |

**Trigger:**
- Scan phát hiện agent dùng sai terminology, thiếu/dư section

**Fix:**
1. Edit agent `.md` — thay terminology, thêm/đổi section header
2. ADDITIVE ONLY khi thêm section — không xóa content hiện có
3. Thay thế terminology theo chuẩn DEVKIT

**Verify ngay sau fix:**
```
V1: Grep old term trong file → count = 0
V2: Grep new term trong file → count ≥ 1
V3: Kiểm tra sections count đúng theo chuẩn
V4: Validate không mất content hiện có (line count không giảm)
```

---

## FP9: Documentation Count/Text Sync

| Thuộc tính | Giá trị |
|-----------|---------|
| **Risk** | LOW — cập nhật text/count trong docs |
| **Category** | CONTENT |
| **Confirm trước khi apply** | Không cần (text fix đơn giản) |
| **Priority** | 2 (Naming) |

**Trigger:**
- Scan phát hiện counts không khớp thực tế, cross-refs sai

**Fix:**
1. Edit text — thay số, sửa reference
2. Cập nhật counts theo số liệu thực tế
3. Sửa cross-refs để trỏ đúng target

**Verify ngay sau fix:**
```
V1: Grep new value trong file → count ≥ 1
V2: Grep old value trong file → count = 0
V3: Kiểm tra cross-ref target tồn tại (Glob path)
```

**`edit_type`:** `REPLACEMENT` — Phase 1 verify 3a enforce old_value = 0.

---

## Quick Reference: edit_type cho Phase 1 Verify

> Phase 1 Step 1.8 (Verify 3a) dựa trên `edit_type` để quyết định có check `old_value = 0` hay không:

| Pattern | edit_type | Verify 3a (Grep old_value = 0) |
|---------|-----------|--------------------------------|
| FP1 (Hook) | REPLACEMENT hoặc ADDITIVE (tuỳ step) | Enforce / Skip theo step |
| FP2 (Checkpoint Schema) | ADDITIVE | **SKIP** |
| FP3 (Digest Template) | NEW FILE (Write) | N/A |
| FP4 (Skill Digest Steps) | ADDITIVE | **SKIP** |
| FP5 (Task Template A6/A7) | ADDITIVE | **SKIP** |
| FP6 (Parallel Flags) | ADDITIVE | **SKIP** |
| FP7 (SKILL.md Structural) | ADDITIVE | **SKIP** |
| FP8 (Agent Section) | Mixed (thay terminology = REPLACEMENT, thêm section = ADDITIVE) | Theo step |
| FP9 (Doc Count/Text) | REPLACEMENT | **ENFORCE** old_value = 0 |
