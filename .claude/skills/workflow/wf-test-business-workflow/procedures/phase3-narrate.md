# Procedure: Phase 3 NARRATE — wf-test-business-workflow

> Chỉ chạy khi Phase 2 `test_status = pass`. Dual-agent narration cho BA/PM.

## PRE-GATE

`test_status=pass`

## Step 3.1 — Spawn Dual-Agent (PARALLEL)

```
Spawn 2 agents SONG SONG:

Agent 1 — developer:
  - Input: workflow-analysis.md + fix-log.json + API evidence
  - Output: §3 Góc nhìn kỹ thuật (~600 từ, tiếng Việt)
    (sequence BE/FE, validation layers, side effects, assertion points)

Agent 2 — domain expert (theo level):
  L1 → sales-expert hoặc customer-expert
  L2 → procurement-expert
  L3 → hr-expert (+ finance-expert nếu có GL posting)
  L4 → customer-expert
  L5 → logistics-expert
  L6 → finance-expert / customer-expert / logistics-expert (theo subject)

  - Input: WF-L*.md (§1-§4) + workflow-analysis.md
  - Output: §2 Góc nhìn nghiệp vụ (~600 từ, tiếng Việt)
    (mục đích, actors, KPIs, downstream impact, edge cases)

E007: NẾU level không map được domain expert phù hợp → fallback developer-only
      narration (bỏ §2, ghi chú trong presentation).
```

## Step 3.2 — Compose Presentation

```
Đọc templates/presentation.template.md → populate 5 sections:
  §1 Tổng quan demo     (từ §1 spec + run metadata)
  §2 Góc nhìn nghiệp vụ (từ domain expert agent)
  §3 Góc nhìn kỹ thuật  (từ developer agent)
  §4 Kết quả QA         (từ fix-log + bugs + phase 2 observations)
  §5 Artifacts          (screenshots, checkpoint path, re-run command)

Ghi: .mc-data/docs/phase1-business/workflows/_presentations/{WF-id}-{slug}.presentation.md
Update README.md index tại _presentations/ (idempotent — 1 row per WF-id)
```

## Step 3.3-3.5 — Wrap-up

```
3.3 Verify presentation.md > 500 bytes
3.4 _presentations/README.md có row mới
3.5 Update test-status.json: narration_status=done, next_action="spawn_pending"
```

## POST-GATE

`presentation.md exists && size > 500 bytes && README.md updated`
