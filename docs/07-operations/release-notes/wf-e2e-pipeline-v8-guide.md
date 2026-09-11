# wf-e2e Pipeline v8.0 — Migration Guide

> Version 8.0.0 (2026-05-15) — Breaking changes từ v7.0

## Tổng quan thay đổi

Pipeline v8.0 bổ sung 3 pre-flight phases mới (F0/F0a/F0b) và tách wf-e2e-test thành 2 skills:
- **wf-e2e-finding** (F0a): Analysis only — FIND business/DB/API/UI
- **wf-e2e-test** (F1): Live test only — consume findings từ F0a

## Pipeline v7.0 vs v8.0

### v7.0 (cũ)
```
F1 → F2 → [F3] → [F4] → F5 → [F6] → F7 → F8
```

### v8.0 (mới)
```
F0 (infra) → F0a (finding) → F0b (seed) → F1 → F2 → [F3] → [F4] → F5 → [F6] → F7 → F8
```

## Breaking Changes

### 1. e2e-status.json Schema — 8 → 11 steps

**Trước (v7):** `f1_test, f2_browser, f3_unblock, f4_implement, f5_retest, f6_fix, f7_scenario, f8_demo`

**Sau (v8):** `f0_infra, f0a_finding, f0b_seed, f1_test, f2_browser, f3_unblock, f4_implement, f5_retest, f6_fix, f7_scenario, f8_demo`

### 2. wf-e2e-test v2.0 — PRE-GATE mới

F1 wf-e2e-test bây giờ BẮT BUỘC F0a findings tồn tại TRƯỚC khi test.
**Backward compat:** Nếu chạy `/wf-e2e-test` trực tiếp mà chưa có F0a → auto-spawn F0a trước (G5 shim).

### 3. --max-items DEPRECATED

```
# Cũ (bị ignore)
/wf-e2e-verify FEAT-ID --max-impl-items=5

# Mới
/wf-e2e-verify FEAT-ID --max-time=60m
```

### 4. --no-playwright DEGRADE (không skip)

```
# Cũ: skip F2/F7/F8 → completed=true (fantasy)
# Mới: degrade F2/F7/F8 → status="degraded_no_browser" → final="degraded"
```

### 5. F6 Anti-loop per-severity

```
# Cũ: max 3 vòng F6↔F5 cứng
# Mới: CRITICAL=5, HIGH=4, MEDIUM=3, LOW=2 + HIGH+ từ F7 có 1 override slot
```

## New Skills

| Skill | Command | Mô tả |
|-------|---------|-------|
| `wf-e2e-finding` | `/wf-e2e-finding FEAT-ID` | Analysis only. Auto-spawned bởi wf-e2e-verify |
| `wf-e2e-batch` | `/wf-e2e-batch --scope=fin` | Batch N FEATs với dependency graph |
| `wf-e2e-credentials` | spawned bởi F0 | Credential Vault |

## --auto Mode Policy (T4.4)

| CDG Type | --auto behavior |
|----------|----------------|
| CDG-01 DEPRECATE module | BLOCK + ask user |
| CDG-06 Destructive DB | BLOCK + ask user |
| CDG-NEW-01 Cross-Module Gap | Expert dispatch (architect + domain) |
| F4 product decision | Expert dispatch (domain + product) |

## Expert Dispatch System

`--auto` kích hoạt expert agent tự quyết cho non-destructive decisions:
- architect, domain-expert, product-expert, qa-lead, security
- 2 experts phải đồng thuận cho destructive actions
- Post-hoc notification với 24h rollback window

## Migration từ v7

```bash
# Migrate sessions cũ (backward compat)
bash .claude/scripts/wf-e2e-migrate-v7-to-v8.sh

# v7 sessions vẫn chạy được với --legacy flag
/wf-e2e-verify FEAT-ID --resume --legacy
```

## Phased Rollout

- v7.1.0 (Week 1-2): Tier 0 + Tier 1 stable
- v7.2.0 (Week 3): Tier 2 logic fixes
- v7.3.0 (Week 4): Tier 4 expert dispatch
- v7.4.0 (Week 5-6): Tier 5 hardening
- v8.0.0 (Week 7): Tier 3 batch + Tier 6 operational

_Tài liệu: DEVKIT MCV3 v8.0.0_
