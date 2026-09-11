# Project Context — mcv3-bench-wf-fix-bugs

## Tổng quan

Synthetic ERP system mini với 3 modules cho mục đích benchmark `/wf-fix-bugs`.
KHÔNG phải production code — 15 bugs intentional được inject.

## Mục tiêu kinh doanh

Project benchmark — không có business goal thực sự. Dùng để đo lường performance & quality của workflow fix-bugs.

## Phạm vi

- **Systems:** 1 (ERP)
- **Modules:** 3 (sales, crm, finance)
- **Features:** 6 (orders, quotations, customers, leads, invoices, payments)
- **Requirements:** 15 (REQ-SALES-001..005, REQ-CRM-001..005, REQ-FIN-001..005)

## Tech Stack

- Language: TypeScript (ES2022)
- Runtime: Node.js (chưa cần install cho static benchmark)
- Interface: API-only (no UI in v1)

## Constraints

- Read-only — không deploy production
- Static scan + LLM scan only (v1)
- Runtime tests deferred to v2

## Dependencies

- `sales` depends on `crm` (Customer type)
- `finance` depends on `sales` (Order type)

> Note: file này có size > 500 bytes để satisfy LEGACY_MODE detection threshold (CORE-021).
> Đây là synthetic project mới (không phải legacy), nhưng project-context.md vẫn được generate để workflow consistency.
