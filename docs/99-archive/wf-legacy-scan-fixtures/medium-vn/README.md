# Fixture: medium-vn

**Status:** ⬜ Pending content (Phase A.6 tech part: folder stub created)

---

## Specs

| Item | Value |
|------|-------|
| **Files target** | 500 |
| **Modules target** | 10 (≥5 with VN names) |
| **Stack** | .NET (backend) + React (frontend) |
| **Language** | Tiếng Việt không dấu (primary) |
| **Domain** | finance + HR + sales |

## Expected Modules

```
medium-vn/
├── qlkh/          # ~50 files — quản lý khách hàng (sales)
├── hoadon/        # ~60 files — hoá đơn (finance)
├── qlns/          # ~50 files — quản lý nhân sự (HR)
├── chamcong/      # ~45 files — chấm công (HR)
├── bangluong/     # ~50 files — bảng lương (HR)
├── nhapkho/       # ~40 files — nhập kho (operations)
├── xuatkho/       # ~40 files — xuất kho (operations)
├── baocao/        # ~50 files — báo cáo
├── caidat/        # ~40 files — cài đặt (settings)
└── dangnhap/      # ~75 files — đăng nhập + auth + user management
```

## Expected IPS Detection (sau Phase C)

- `sales: 0.75+` (qlkh strong)
- `hr: 0.80+` (qlns + chamcong + bangluong multi-signal boost)
- `finance: 0.65+` (hoadon)
- `operations: 0.75+` (nhapkho + xuatkho multi-signal)

**Language tag:** `vn` (primary)

## Source

- Base template: ABP Framework hoặc custom template
- Sample data: synthetic (không dùng data production)

## Population Instructions

```bash
# From within this folder:
# Option A: Clone minimal ABP Framework skeleton
#   git clone https://github.com/abpframework/abp-samples ./tmp-abp
#   # Extract + rename modules sang VN
# Option B: Create minimal .NET Web API + React SPA manually
dotnet new webapi -n VnErp -o backend
cd frontend && npx create-vite@latest . --template react-ts

# Rename default structure sang 10 modules trên
# Populate mỗi module ~40-60 files
```

## CRITICAL

- Module names PHẢI dùng tiếng Việt không dấu (qlkh, hoadon, ...) để test VN keyword detection (Phase C).
- File names bên trong có thể English (Customer.cs, Invoice.cs, ...) — reflect reality của VN dev teams.
- Comments tiếng Việt cho thêm signal.

## Baseline Output

Sau khi populate + run `/wf-legacy-scan` v4.1, baseline xuất sang `../medium-vn.baseline-v4.1/`.
