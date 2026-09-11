# Fixture: large-mixed

**Status:** ⬜ Pending content (Phase A.6 tech part: folder stub created)

---

## Specs

| Item | Value |
|------|-------|
| **Files target** | 1,500 (fallback 800 nếu v4.1 context overflow) |
| **Modules target** | 30 |
| **Stack** | Node.js monorepo (turborepo hoặc nx) |
| **Language** | EN + VN mix (≈60% EN, 40% VN) |
| **Domain** | finance + logistics (primary); HR, sales, compliance (secondary) |

## Expected Modules (30 total)

### EN-named (~18 modules)

```
billing/, invoice/, payment/, tax/           # finance
shipping/, delivery/, customs/, warehouse/    # logistics
hr/, payroll/, benefits/                      # HR
sales-crm/, leads/, quotes/                   # sales
audit-log/, compliance/                       # compliance
reporting/, analytics/, settings/             # ops
```

### VN-named (~12 modules)

```
qlkh/                # quản lý khách hàng
hoadon/              # hoá đơn
baogia/              # báo giá
vanchuyen/           # vận chuyển
haiquan/             # hải quan
khobai/              # kho bãi
qlns/                # quản lý nhân sự
chamcong/            # chấm công
bangluong/           # bảng lương
baocao/              # báo cáo
caidat/              # cài đặt
tuanthu/             # tuân thủ
```

## Expected IPS Detection (sau Phase C)

- `finance: 0.80+` (billing + invoice + hoadon + thue — multi-signal EN+VN)
- `logistics: 0.85+` (shipping + delivery + vanchuyen + haiquan — multi-signal EN+VN)
- `hr: 0.70+` (hr + payroll + qlns + chamcong)
- `operations: 0.60+` (warehouse + khobai)
- **Language mix detected:** `en: 60%, vn: 40%`

## Source

- Base template: turborepo or nx starter
- Multiple `apps/*` and `packages/*` folders

## Population Instructions

```bash
# From within this folder:
npx create-turbo@latest .
# Expand structure:
mkdir -p apps/{frontend-web,backend-api,worker-jobs,mobile-admin}
mkdir -p packages/{finance-core,logistics-core,hr-core,shared-ui,shared-types,vn-utils}

# Populate mỗi app/package với 50-100 files
# Mix EN + VN module names in packages/ và apps/*/src/modules/
```

## CRITICAL

- Monorepo structure để test tech stack detection (CORE-014).
- Mixed EN+VN để test IPS handle both languages.
- Dependency graph phức tạp để test L3 inventory + L4 classification.

## Size Fallback

Nếu v4.1 bị context overflow với 1,500 files (đã note risk trong phase-A-design-closure.md):

- **Fallback:** 800 files, 20 modules thay vì 30.
- Ghi rõ trong session log của A.3.
- Document việc này trong `baseline-v4.1/NOTE.md`.

## Baseline Output

Sau khi populate + run `/wf-legacy-scan` v4.1, baseline xuất sang `../large-mixed.baseline-v4.1/`.
