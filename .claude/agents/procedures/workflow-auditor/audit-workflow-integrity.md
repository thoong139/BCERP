# Playbook: Audit Workflow Integrity

> **Type**: Agent Skill Playbook
> **Agent**: workflow-auditor
> **Triggered by**: Khi review toàn bộ workflow pipeline
> **Output**: Workflow Integrity Audit Report với handoff matrix

---

## Khi nào dùng playbook này

- Khi review-orchestrator yêu cầu `--workflow` scope
- Khi thêm hoặc bỏ skill trong pipeline
- Khi thay đổi phase order hoặc pre-conditions
- Khi phát hiện dữ liệu không được chuyển đúng giữa các phases

---

## Procedure

### Bước 1: Extract canonical workflow

```
READ: .claude/rules/00-core.md
  □ Extract workflow sequence (thứ tự skills)
  □ Extract phase prerequisites (Phase N cần Phase N-1)
  □ Extract Cross-Skill Output Path Contract (§4b)

Đây là CANONICAL SOURCE — mọi thứ khác phải khớp với file này.
```

### Bước 2: Extract documented workflow từ CLAUDE.md

```
READ: CLAUDE.md
  □ Extract workflow documentation
  □ Extract skill table (Skill | Command | Purpose)
  □ Note bất kỳ conditional paths nào (ví dụ: wf-design-ux skip nếu API-only)

So sánh với canonical (Bước 1):
  □ Tên skills có khớp?
  □ Thứ tự có khớp?
  □ Có skill nào trong CLAUDE.md không có trong canonical?
  □ Có skill nào trong canonical không có trong CLAUDE.md?

Flag MAJOR cho mỗi discrepancy.
```

### Bước 3: Scan individual skills

```
Glob: .claude/skills/**/SKILL.md

Với mỗi skill, extract:
  □ Tên skill (frontmatter name)
  □ Pre-conditions (PRE-GATE section)
  □ Post-conditions / outputs (POST-GATE section)
  □ Output paths (files được tạo ra)
  □ Input paths (files được đọc vào)
  □ Next step recommendation
  □ Conditional paths (skip conditions)
```

### Bước 4: Verify phase prerequisites

```
Với mỗi phase pair (Phase N → Phase N+1) theo canonical workflow:

  □ Phase N+1 có PRE-GATE yêu cầu artifacts từ Phase N không?
  □ Phase N có POST-GATE đảm bảo tạo ra artifacts đó không?
  □ Nếu Phase N chưa done → Phase N+1 có fail gracefully không?

Ví dụ:
  wf-analyze-requirements → phải tạo phase1-business/
  wf-define-features PRE-GATE → phải check phase1-business/ tồn tại

Flag CRITICAL nếu phase N+1 không check pre-condition.
```

### Bước 5: Trace handoff paths

```
READ: .claude/rules/00-core.md §4b — Cross-Skill Output Path Contract

Với mỗi handoff được định nghĩa trong contract:
  Producer skill: [skill] → Output path: [path]
  Consumer skill: [skill] → Input path: [path]

Verify:
  □ Producer skill thực sự tạo ra file tại output path?
  □ Consumer skill đọc đúng path đó?
  □ Hai paths KHỚP NHAU (không typo, không path mismatch)?

Flag CRITICAL nếu producer/consumer paths không khớp.
```

### Bước 6: Check skill recommendations

```
Mỗi skill kết thúc nên recommend next step:
  □ Sau wf-brainstorm → recommend /wf-analyze-requirements
  □ Sau wf-analyze-requirements → recommend /wf-define-features
  ... (theo canonical workflow)

Exceptions hợp lệ:
  □ wf-prepare-deployment: workflow kết thúc, không cần next step
  □ wf-implement-feature: loop back đến chính nó nếu còn features

Flag MINOR nếu skill không recommend hoặc recommend sai.
```

### Bước 7: Check alternative paths

```
Các conditional paths phải được documented rõ:

  □ wf-design-ux: có điều kiện skip nếu API-only?
  □ wf-verify-sync: có điều kiện khi nào run?
  □ wf-legacy-scan: separate entry point — có documented không?

Error paths:
  □ Nếu pre-conditions chưa met → skill có hướng dẫn rõ không?
  □ Nếu agent fails → có fallback không?

Flag MINOR nếu alternative paths không documented.
```

### Bước 8: Check REQ-ID tracking continuity

```
REQ-ID phải xuất hiện liên tục từ requirements đến code:
  Phase 1: REQ-IDs được define trong req-registry.json
  Phase 2: Features reference REQ-IDs
  Phase 3: Architecture reference REQ-IDs
  Phase 5: Code files reference REQ-IDs

Verify mỗi phase có skill enforce REQ-ID tracking.
Flag MAJOR nếu có phase gap trong REQ-ID tracking.
```

### Bước 9: Output — Workflow Integrity Audit Report

```
Format output:

# Workflow Integrity Audit Report
**Date**: [date]
**Skills in canonical workflow**: [N]

## Summary
[A CRITICAL] [B MAJOR] [C MINOR]

## Workflow Definition Consistency
| Source | Skills Listed | Matches Canonical |
|--------|--------------|-------------------|
| rules/00-core.md | [list] | CANONICAL |
| CLAUDE.md | [list] | PASS/FAIL |

## Handoff Matrix
| From Skill | Output Path | To Skill | Input Path | Status |
|-----------|-------------|----------|------------|--------|
| wf-analyze-requirements | .mc-data/work/wf-analyze-requirements/deferred-issues.md | wf-define-features | .mc-data/work/wf-analyze-requirements/deferred-issues.md | PASS |

## Phase Prerequisites
| Phase | Pre-condition Checked | Fail Graceful | Status |
|-------|----------------------|---------------|--------|

## Critical Issues
[Broken handoffs, missing pre-conditions]

## Major Issues
[Inconsistent definitions, missing REQ-ID tracking]

## Minor Issues
[Missing next-step recommendations, undocumented alternative paths]
```

---

## Checklist trước khi submit

```
□ Đã đọc rules/core.md làm canonical source — không dùng source khác
□ Đã verify Cross-Skill Output Path Contract §4b cho mọi handoff
□ Đã trace từng handoff pair: producer path = consumer path?
□ Đã kiểm tra phase prerequisites enforcement
□ Đã check REQ-ID tracking continuity
□ Handoff matrix đầy đủ tất cả handoffs được định nghĩa trong §4b
```
