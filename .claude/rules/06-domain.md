---
scope: always
description: Quy tắc domain-specific — luôn áp dụng khi làm việc với domain expert requirements.
---

# Domain Rules

Khi làm việc với domain-specific requirements:

1. **Invoke expert agent** phù hợp với domain (xem danh sách agents trong CLAUDE.md)
2. **Tham khảo** domain knowledge trong `.claude/references/team-expert/`
3. **Tuân thủ** compliance requirements cụ thể của domain

| Domain | Compliance cần chú ý |
|--------|----------------------|
| Healthcare | FDA/CE, data privacy, EMR standards |
| Finance | Audit trail, GAAP/IFRS, calculation accuracy |
| Logistics | HS Code accuracy, customs compliance, Incoterms |
| E-commerce | Payment security (PCI-DSS), inventory sync |
| HR/Payroll | Labor law, tax withholding |
| Legal | Contract management, GDPR, regulatory |
| Enterprise Risk | Risk governance, COSO ERM 2017, ISO 31000, risk appetite |
| Quality Excellence | QMS ISO 9001, Six Sigma DMAIC, FMEA, process improvement |
| Paid Media | Ad platform policies (Google/Meta), ROAS accountability, attribution |
| Manufacturing | BOM accuracy, MRP integrity, production traceability |
| Retail | POS reliability, inventory sync, loyalty program compliance |
| Procurement | Vendor due diligence, contract compliance, spend controls |
