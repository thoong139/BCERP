# Fixture: small-en

**Status:** ⬜ Pending content (Phase A.6 tech part: folder stub created)

---

## Specs

| Item | Value |
|------|-------|
| **Files target** | 50 |
| **Modules target** | 3 |
| **Stack** | TypeScript + React |
| **Language** | EN |
| **Domain** | sales (simple CRM) |

## Expected Modules

```
small-en/
├── customer/     # ~15 files — customer management
├── sales/        # ~20 files — order + quote
└── reporting/    # ~15 files — sales reports
```

## Expected IPS Detection (sau Phase C)

- `sales: 0.75+` (EN keywords strong)
- No VN signals
- Fallback to `sales-expert` agent

## Source

- Base template: `create-vite` + `vite-plugin-react`
- Sample data: synthetic (anonymized)

## Population Instructions

```bash
# From within this folder:
npx create-vite@latest . --template react-ts
# Then rename default src/ structure sang 3 modules above.
# Populate mỗi module với:
#   - index.ts, types.ts
#   - 2-3 components .tsx
#   - service.ts (API client mock)
#   - __tests__/ folder
```

## Baseline Output

Sau khi populate + run `/wf-legacy-scan` v4.1, baseline xuất sang `../small-en.baseline-v4.1/`.
