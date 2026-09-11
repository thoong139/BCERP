---
$schema: strategy-matrix-v1
migrate_id: {MIGRATE_ID}
---

# Ma tran Chien luoc — {SOURCE_MODULE} → {TARGET_MODULE}

## Tong ket

| Strategy | So luong | Ty le |
|----------|---------|-------|
| Keep | {N} | {X}% |
| Redesign | {N} | {X}% |
| Deprecate | {N} | {X}% |
| Merge | {N} | {X}% |
| **Tong** | **{N}** | **100%** |

## Chi tiet tung feature

### Keep — Giu nguyen logic, implement lai theo pattern moi

| # | Feature | Rationale | Entities |
|---|---------|-----------|----------|
| 1 | {ten feature} | {ly do giu: logic tot, van con phu hop} | {entities} |

### Redesign — Thay doi logic de phu hop he thong moi

| # | Feature | Rationale | Thay doi chinh |
|---|---------|-----------|---------------|
| 1 | {ten feature} | {ly do can thay doi: khong phu hop pattern moi, can toi uu, ...} | {mo ta thay doi} |

### Merge — Trong voi tinh nang da co trong EUREKA

| # | Feature cu | Merge vao feature EUREKA | Rationale |
|---|-----------|------------------------|-----------|
| 1 | {ten feature cu} | {FEAT-ID hoac ten feature moi} | {ly do merge} |

### Deprecate — Bo vi khong con phu hop

| # | Feature | Rationale |
|---|---------|-----------|
| 1 | {ten feature} | {ly do bo: khong con can thiet, da co alternative, ...} |
