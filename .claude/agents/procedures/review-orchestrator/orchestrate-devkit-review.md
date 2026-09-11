# Playbook: Điều phối Review DEVKIT

> **Type**: Agent Skill Playbook
> **Agent**: review-orchestrator
> **Triggered by**: Khi cần review toàn bộ hoặc một phần DEVKIT
> **Output**: DEVKIT Review Report tổng hợp từ tất cả auditors

---

## Khi nào dùng playbook này

- Khi user yêu cầu kiểm tra tính nhất quán của DEVKIT (`--full`, `--agents`, `--skills`, v.v.)
- Khi có thay đổi lớn trong cấu trúc DEVKIT (thêm agent mới, đổi tên skill, restructure templates)
- Khi cần báo cáo tổng thể trước khi release DEVKIT version mới

---

## Procedure

### Bước 1: Xác định scope review

```
Parse user request → xác định scope:
  --full       → toàn bộ DEVKIT (agents + skills + templates + cross-refs + workflow)
  --agents     → chỉ agents/ directory
  --skills     → chỉ skills/ directory
  --templates  → chỉ doc-framework/ directory
  --cross-ref  → chỉ cross-component references
  --workflow   → chỉ workflow integrity
  [agent-name] → 1 agent cụ thể

Nếu scope không rõ → hỏi user trước khi tiến hành.
```

### Bước 2: Lập kế hoạch huy động auditors

Dựa trên scope, quyết định auditors nào cần chạy và thứ tự:

```
BATCH 1 (song song — độc lập nhau):
  --full hoặc --agents  → agent-auditor
  --full hoặc --skills  → skill-auditor
  --full hoặc --templates → template-auditor

BATCH 2 (sau BATCH 1 — cần context từ batch trước):
  --full hoặc --cross-ref → cross-reference-auditor
                            (input: kết quả từ agent/skill/template auditors)

BATCH 3 (cuối cùng — cần toàn bộ context):
  --full hoặc --workflow → workflow-auditor
                           (input: kết quả từ tất cả batches trước)
```

### Bước 3: Huy động BATCH 1 (song song)

```
Spawn các auditors độc lập cùng lúc.
Với mỗi auditor, truyền:
  - Scope cụ thể (agent nào / skill nào / template nào cần kiểm tra)
  - Yêu cầu output: findings dạng list với severity label

Chờ TẤT CẢ auditors trong BATCH 1 hoàn thành trước khi tiếp tục.
```

### Bước 4: Huy động BATCH 2 — Cross-reference

```
Spawn cross-reference-auditor với:
  - Input: danh sách files đã scan từ BATCH 1
  - Task: verify references giữa components, tìm broken paths

Chờ cross-reference-auditor hoàn thành.
```

### Bước 5: Huy động BATCH 3 — Workflow

```
Spawn workflow-auditor với:
  - Input: toàn bộ context từ BATCH 1 và BATCH 2
  - Task: verify end-to-end workflow integrity, handoff paths

Chờ workflow-auditor hoàn thành.
```

### Bước 6: Tổng hợp findings

```
Thu thập findings từ tất cả auditors.
Deduplicate: cùng 1 vấn đề có thể được nhiều auditors flag.
Classify theo severity:
  CRITICAL → break functionality, phải fix ngay
  MAJOR    → inconsistency, có thể gây lỗi, fix trong sprint
  MINOR    → style/suggestion, cân nhắc fix

Đếm tổng: [X CRITICAL] [Y MAJOR] [Z MINOR]
```

### Bước 7: Tạo DEVKIT Review Report

```
Format output:

# DEVKIT Review Report
**Scope**: [scope được review]
**Date**: [ngày review]
**Summary**: [X CRITICAL] [Y MAJOR] [Z MINOR]

## Critical Issues
[Danh sách issues CRITICAL với file path + mô tả + đề xuất fix]

## Major Issues
[Danh sách issues MAJOR]

## Minor Issues
[Danh sách issues MINOR]

## Recommended Action Plan
[Thứ tự ưu tiên fix, dependencies giữa fixes]
```

---

## Checklist trước khi submit

```
□ Scope đã xác định rõ trước khi huy động auditors
□ Auditors độc lập đã chạy song song (không tuần tự không cần thiết)
□ Cross-reference chạy SAU individual auditors
□ Workflow chạy CUỐI CÙNG
□ Mọi finding đều có severity label
□ Duplicate findings đã được deduplicate
□ Action plan có thứ tự ưu tiên rõ ràng
```
