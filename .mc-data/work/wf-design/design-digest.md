# Design Digest — BCERP Phase 3 (dành cho stakeholder review, Protocol 6.4)

> Session 20260913-053848-f4d7 | 13/09/2026 | LPM. Specs tổng ~50K từ — reviewer dùng digest + Grep theo ID, KHÔNG đọc toàn bộ.

## Kiến trúc (P3-01-architecture.md, 7.3K từ, 11 sections)
- **Platform 6 systems:** SYS-BCERP-WEB (modular monolith domain services, 7 components COMP-ERP), SYS-CORE-BACKEND (nền tảng RBAC/Audit/DataHub, 11 components), SYS-INTEGRATION-GW (headless outbound gateway 7 nền tảng + VAS, 13 components), SYS-PORTAL-WEB (DMZ client-facing, 6), SYS-MOBILE-INTERNAL (thin client, 20), SYS-MOBILE-PORTAL (thin client, 3). Tổng 60 components (aggregation 0 conflicts).
- **Stack:** NestJS/TS, PostgreSQL 16 per-system schema + RLS, ClickHouse OLAP, Redis, Kafka, OIDC SSO + MFA step-up, S3 + Object Lock WORM ≥10 năm.
- **Kiểm soát cốt lõi:** Financial Hard Stop "đã khớp tiền" FIN_L1 chặn cấp phát TKQC (+ sweep re-validate tại nguồn); dual approval ví; SoD 4 vai ngưỡng 5/50/200 triệu; compensating control CFO kiêm CTO (combined_role → dual approval cứng); nhãn nguồn api/manual bất biến; degraded mode manual là khởi điểm (DI-007); RBAC 4 chiều 18 vai; PII lương field-level encryption; tenant isolation 2 lớp portal.

## Specs
| File | Từ | Nội dung |
|------|-----|----------|
| api-contract.md | 15.5K | 280 endpoint (API-ERP 77 / CORE 49 / GW 48 / PORTAL 39 / MBI 34 / MPO 33), transition + list server-side 20/100 + bulk + activity; §9 FEAT Traceability 70 dòng |
| database-design.md | 14.1K | 122 bảng (ERP 62 / CORE 28 / GW 18 / PORTAL 9 / MBI 3 / MPO 2), state machine CHECK, owner/assignee, assignment_history, audit hash-chain, double-entry ví, period lock |
| integration-map.md | 5.1K | 14 sync INT-S + 16 events INT-E (outbox, DLQ, idempotent) + 8 cross-system rules + Object 360 (6) + propagation realtime/near-RT/batch + assignment events |
| infra-spec.md | 8K | 55 items: containers, vault KMS envelope, WORM store, egress proxy, DMZ segmentation, push gateway, HA worker/queue |
| design-report.md | 1.2K | Phase 4: 9/9 lỗi fixed (6 error-code mapping, 2 cột wallet_transactions, FEAT traceability), 0 remaining |

## Kết quả validation (Phase 4)
- 4.2 REQ coverage **59/59**; CQG1 FEAT→API **170/170**; CQG2 MOD→table **19/19**; 0 duplicate def; error codes chuẩn hóa (SOD_VIOLATION 409, INVITE_EXPIRED 409, DPA_NOT_SIGNED 403, OTP 401/400, AUDIT_MUTATION_NOT_SUPPORTED 405 tách khỏi AUDIT_IMMUTABLE 409).

## Danh sách [NEEDS_REVIEW] (23 mục — Phụ lục A P3-01, review có thể bổ sung)
1. 30 stage proposal V6.0 (tên + done-criteria) · 2. Nguồn feed sao kê ngân hàng · 3. Kênh notification ngoài in-app · 4. E-sign provider + đường dẫn · 5. State A/B variant · 6. Contract read-model → PORTAL · 7. Công thức quota coverage ≥3× · 8. Danh mục đủ 18 vai · 9. Phương pháp MFA · 10. Schedule/SLA ingest DataHub · 11. Chốt stack hạ tầng (Kafka/ClickHouse/Keycloak/S3) · 12. Retention audit vận hành + warehouse · 13. Delegate CFO kiêm CTO · 14. Fail-open/closed policy đọc · 15. Webhook receiver GW · 16. Cơ chế VAS (API/import) [KXN-9] · 17. Phạm vi GMV Portal · 18. Mốc cấp quyền API nền tảng (DI-007) · 19. Bộ trường campaign/invoice khách · 20. Ma trận tier→quota/SLA · 21. Touchpoint HR-CORE mobile ESS · 22. Platform mobile + offline chấm công + MFA mobile · 23. Ownership Portal API Gateway chung + KXN-15/20/22

## Hướng dẫn reviewer
- Tra cứu: Grep theo API-xxx / TBL-xxx / COMP-xxx / INT-S-xxx / INT-E-xxx / REQ-xxx / FEAT-xxx trong technical-specs.
- Business baseline bắt buộc: `sessions/20260913-053848-f4d7/business-context.md` (2.4K từ — đọc được toàn bộ).
- Feature gốc khi cần: `.mc-data/docs/phase2-features/**` (170 file, đọc chọn lọc).
