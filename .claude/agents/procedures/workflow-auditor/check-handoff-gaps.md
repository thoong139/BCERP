# Playbook: Check Handoff Gaps

> **Type**: Agent Skill Playbook
> **Agent**: workflow-auditor
> **Triggered by**: Khi thêm/bỏ skill hoặc thay đổi output paths
> **Output**: Handoff Gap Analysis Report

---

## Khi nào dùng playbook này

- Khi thêm skill mới vào pipeline (cần verify handoff với skill liền kề)
- Khi xóa skill (cần verify skills xung quanh vẫn connect được)
- Khi thay đổi output path của 1 skill (cần verify consumer skill vẫn đọc đúng)
- Khi phát hiện phase sau không nhận được data từ phase trước

---

## Procedure

### Bước 1: Load Cross-Skill Output Path Contract

```
READ: .claude/rules/00-core.md

Extract bảng §4b — Cross-Skill Output Path Contract:
  Producer Skill | Output Path | Consumer Skill

Đây là danh sách tất cả handoffs cần verify.
```

### Bước 2: Map producer → consumer paths

```
Với mỗi handoff trong contract:
  Producer: [skill_name] → output tại [path]
  Consumer: [skill_name] → đọc từ [path]

Tạo list:
  {handoff_id, producer, output_path, consumer, input_path}
```

### Bước 3: Verify output files từ producers

```
Với mỗi producer trong list:
  READ skill file của producer
  Tìm section output/artifacts

  Kiểm tra:
  □ Skill có explicitly tạo file tại output_path?
  □ Path trong skill definition CHÍNH XÁC khớp path trong contract?
    (phân biệt case, slashes, v.v.)

  Flag CRITICAL nếu producer không tạo ra file đúng path.
```

### Bước 4: Verify consumers reference đúng paths

```
Với mỗi consumer trong list:
  READ skill file của consumer
  Tìm section input/pre-conditions

  Kiểm tra:
  □ Skill có đọc file tại input_path?
  □ Path trong skill definition CHÍNH XÁC khớp path trong contract?
  □ Nếu file không tồn tại → skill có fail gracefully (báo lỗi rõ) không?

  Flag CRITICAL nếu consumer đọc wrong path.
  Flag MAJOR nếu consumer không check pre-condition.
```

### Bước 5: Tìm handoffs missing trong contract

```
Glob: .claude/skills/**/SKILL.md
Scan mỗi skill → extract output files

So sánh với contract:
  □ Có output file nào không được liệt kê trong contract?
  □ Có skill nào đọc files không được liệt kê trong contract?

Flag MAJOR cho gaps — có thể là handoffs mới chưa được document.
```

### Bước 6: Check skills mới thêm/vừa thay đổi

```
Nếu có danh sách skills vừa thay đổi (từ caller):
  Focus vào skills đó và neighbors của chúng:
  → Previous skill (producer cho skill mới)
  → Next skill (consumer output từ skill mới)

Verify cả 2 chiều:
  □ Skill mới nhận đúng từ predecessor?
  □ Skill mới export đúng cho successor?
```

### Bước 7: Verify .mc-data/ path conventions

```
Check output paths tuân thủ conventions:
  □ Phase docs: .mc-data/docs/phase[N]-[name]/
  □ Working data: .mc-data/work/[skill-name]/
  □ Registry: .mc-data/docs/_meta/req-registry.json
  □ Sync data: .mc-data/sync/

Flag MINOR nếu path không theo convention (vẫn hoạt động nhưng inconsistent).
```

### Bước 8: Output — Handoff Gap Analysis Report

```
Format output:

# Handoff Gap Analysis Report
**Date**: [date]
**Handoffs in contract**: [N]
**Handoffs verified**: [M]

## Summary
[X CRITICAL gaps] [Y MAJOR gaps] [Z MINOR gaps]
[Overall: PASS / FAIL]

## Handoff Verification Matrix
| # | Producer | Output Path | Consumer | Input Path | Producer OK | Consumer OK | Status |
|---|----------|-------------|----------|------------|-------------|-------------|--------|
| 1 | wf-analyze-requirements | .mc-data/work/wf-analyze-requirements/deferred-issues.md | wf-define-features | .mc-data/work/wf-analyze-requirements/deferred-issues.md | YES | YES | PASS |

## Critical Gaps
[List handoffs broken — producer/consumer path mismatch]

## Major Gaps
[List undocumented handoffs hoặc missing pre-condition checks]

## Undocumented Handoffs Found
[List output files không có trong contract]

## Recommendations
[Cụ thể: sửa path X → Y trong skill Z, hoặc thêm handoff vào contract]
```

---

## Checklist trước khi submit

```
□ Đã đọc Cross-Skill Output Path Contract §4b
□ Đã verify TẤT CẢ handoffs trong contract — không skip
□ Đã kiểm tra 2 chiều: producer tạo đúng path VÀ consumer đọc đúng path
□ Đã tìm handoffs missing (output files không có trong contract)
□ Handoff matrix đầy đủ với status per handoff
□ Recommendations đủ cụ thể để developer fix trực tiếp
```
