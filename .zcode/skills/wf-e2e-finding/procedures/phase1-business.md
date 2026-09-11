# F0a — Phase 1: BUSINESS ANALYSIS

## Mục tiêu

Phân tích nghiệp vụ feature từ spec + code (KHÔNG live-test). Người dùng verify tính chính xác (trừ khi --auto).

---

## FIND — Nguồn đọc (theo thứ tự ưu tiên)

1. Feature spec `$SPEC_FILE` — sections: "Mô Tả Tính Năng", "Luồng Người Dùng", "Quy Tắc Nghiệp Vụ", "Phân Quyền", "Acceptance Criteria"
2. REQ-ID context: đọc `.mc-data/docs/phase1-business/` cho module liên quan
3. Related features: `registry.features[].dependencies` — đọc feature spec của từng dep
4. Business policies: `.mc-data/docs/phase0-brainstorm/` nếu liên quan đến domain
5. Phase 3 architecture: `.mc-data/docs/phase3-architecture/technical-specs/` cho API contract

---

## ASSESS — Checklist tự đánh giá

```
[ ] Mục đích: rõ ràng, cụ thể — không chỉ là copy tên feature
[ ] Actors: biết ≥1 role cụ thể + permission cần có
[ ] Dữ liệu tác động: biết ≥1 entity/bảng chính bị tạo/sửa/xoá
[ ] Business flow: có ≥3 bước cụ thể cho happy path
[ ] Business rules: có ≥3 BR với điều kiện + hậu quả vi phạm
[ ] State machine: có ≥2 trạng thái hợp lệ (hoặc N/A rõ ràng)
[ ] Cross-module: đã xác định domain events và consumer (hoặc N/A rõ ràng)
```

Nếu bất kỳ mục nào chưa đạt → BỔ SUNG.

---

## BỔ SUNG — Nguồn bổ sung (theo thứ tự)

```bash
# 1. Serena: tìm entity từ tên feature/module
mcp__serena__find_symbol --name_path_pattern="{EntityName}" --relative_path="apps/backend/"

# 2. GitNexus: concept từ feature name
mcp__gitnexus__query --query="{feature_concept_keyword}"

# 3. Grep domain layer
grep -r "class.*Command\|class.*Query\|IValidator" apps/backend/Eureka.Modules.{Module}/Application/ --include="*.cs" -l

# 4. Grep entities, value objects
find apps/backend/Eureka.Modules.{Module}/Domain/ -name "*.cs" | head -20

# 5. Đọc task implementation
ls .mc-data/docs/phase5-implementation/tasks/ | grep -i "{feat_id}"
```

Context > 50% sau BỔ SUNG → gọi `save_checkpoint()` từ `_shared.md`.

---

## VERIFY — AskUserQuestion (skip nếu --auto)

Trình bày tóm tắt (≤20 dòng):

```
HIỂU NGHIỆP VỤ — {FEAT-ID}: {tên feature}

Mục đích: {1-2 câu}
Ai dùng: {roles}
Dữ liệu tác động: {entities/tables}
Luồng chính:
  1. {bước 1}
  2. {bước 2}
  3. {bước 3}
Quy tắc quan trọng:
  - BR-001: {rule} — vi phạm → {hậu quả}
  - BR-002: {rule}
Cross-module: {domain events + consumer modules / N/A}
```

Dùng AskUserQuestion với lựa chọn:
- "Đúng hoàn toàn — tiếp tục P2"
- "Đúng phần lớn, chỉnh: {note}"
- "Sai — cần đọc lại: {note}"

Nếu `--auto`: tự chọn "Đúng hoàn toàn".

### Xử lý kết quả

- **"Đúng hoàn toàn"**: ghi files → tiếp tục P2
- **"Đúng phần lớn"**: cập nhật theo note → ghi files → tiếp tục P2
- **"Sai"**: `verify_attempts += 1` → quay FIND với hint từ note

---

## Output — Ghi 4 files

### business-understanding.md

Từ template `templates/business-understanding.template.md`. Điền đầy đủ:
- Mục đích (2-4 câu)
- Actors table (role, permission, hành động)
- Dữ liệu tác động table (entity, schema, loại, ghi chú)
- Business flow happy path (≥3 bước)
- Business rules table (BR-NNN, quy tắc, điều kiện vi phạm, hậu quả)
- Out of scope

### business-rule-catalog.md

Từ template `templates/business-rule-catalog.template.md`. Mỗi BR-NNN ghi:
- Mô tả rule
- Expected HTTP status khi vi phạm
- Expected error code
- CFV (Cross-Field Validation) nếu có
- CALC (formula) nếu là tính toán

### state-machine.md

Từ template `templates/state-machine.template.md`. Ghi:
- Danh sách trạng thái hợp lệ (nếu entity có status field)
- Các chuyển trạng thái hợp lệ + trigger
- Các chuyển trạng thái KHÔNG hợp lệ
- Side effects (domain events phát ra khi chuyển trạng thái)
- Nếu không có status field → ghi rõ "N/A: Feature này không có state machine"

### cross-module-map.md

Từ template `templates/cross-module-map.template.md`. LUÔN generate, ghi:
- Domain events feature này phát ra
- Consumer modules + hành động khi nhận event
- Dependency modules (từ registry.dependencies) + impl_status của từng module
- CDG-NEW-02 warnings (nếu có module chưa implement)
- Nếu không publish events → ghi rõ "N/A: Feature này không publish domain events"

---

### B1: Cross-Module Gap Detection (T4.1)

Sau khi generate cross-module-map.md:

1. Đọc cross-module-map.md → liệt kê modules phụ thuộc
2. Với mỗi module phụ thuộc:
   a. Cross-check registry.json: tìm feature/module với tên tương ứng
   b. Lấy impl_status của module đó
   c. Nếu impl_status ∈ {not_started, in_progress, skipped}:
      → Tạo entry trong cross-module-gaps.json

3. Nếu cross-module-gaps.json có entries → CDG-NEW-01:
   AskUserQuestion "Phát hiện {N} module phụ thuộc chưa implement":
   Options:
     A. "Block + chạy /wf-implement-feature [missing-module] trước"
     B. "Run với MOCK cross-module (limit scope, document mocks)"
     C. "Skip FEAT này, defer tới khi module xong"

   Nếu --auto: dispatch architect agent + domain expert để quyết định (T4.4 policy)
   Default --auto action: Option B (MOCK với full log)

4. Ghi quyết định vào cross-module-gaps.json + session-log.json

**Output mới: cross-module-gaps.json** (schema cross-module-gap-v1)

```json
{
  "$schema": "cross-module-gap-v1",
  "feat_id": "",
  "detected_at": "",
  "gaps": [
    {
      "gap_id": "GAP-001",
      "module_name": "Banking",
      "dependency_type": "entity | service | event",
      "reason": "FIN-006 PaymentRun consume BankingSession entity",
      "target_feat_id": "FIN-008",
      "impl_status": "not_started | in_progress | skipped",
      "decision": "block | mock | skip | implement_first",
      "decision_at": "",
      "mock_scope": "Nếu mock: mô tả mock sẽ cover gì",
      "severity": "CRITICAL | HIGH | MEDIUM"
    }
  ],
  "summary": {
    "total_gaps": 0,
    "critical": 0,
    "resolved": 0,
    "mocked": 0
  },
  "audit_chain": ""
}
```

---

## POST-GATE Phase 1

```bash
# T1: 4 files tồn tại
for F in business-understanding.md business-rule-catalog.md state-machine.md cross-module-map.md; do
  test -f "$FINDINGS_DIR/$F" || { log_error "E029" "phase1" "$F không tồn tại"; return 1; }
done

# T2: size > 500 bytes mỗi file
for F in business-understanding.md business-rule-catalog.md state-machine.md cross-module-map.md; do
  SIZE=$(wc -c < "$FINDINGS_DIR/$F")
  [ "$SIZE" -gt 500 ] || { log_error "E022" "phase1" "$F quá nhỏ ($SIZE bytes)"; return 1; }
done

# T3: content depth
BR_COUNT=$(grep -c 'BR-[0-9]' "$FINDINGS_DIR/business-rule-catalog.md" 2>/dev/null || echo 0)
[ "$BR_COUNT" -ge 1 ] || { log_error "E022" "phase1" "Thiếu BR trong business-rule-catalog.md"; return 1; }
```

Fail → auto-fix retry (max 3) từ BỔ SUNG → nếu vẫn fail → escalate.

---

## Cập nhật status.json

```bash
update_phase_status "p1_business" "done"
advance_phase 2 "run P2 DB mapping"
log_event "COMPLETE" "phase1" "4 business findings generated"
check_context_budget  # G4: kiểm tra ngưỡng context
```
