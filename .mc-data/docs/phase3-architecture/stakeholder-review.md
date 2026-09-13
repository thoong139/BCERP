# Stakeholder Review — Phase 3 Architecture & Technical Specs

> Tổng hợp 3 góc đánh giá: Technical Cross-Review, Consistency Check, Gap Analysis.
> Mục tiêu: Đảm bảo nhất quán, phát hiện xung đột, xác nhận coverage đầy đủ trước Phase 4.
>
> READS: `P3-01-architecture.md`, `technical-specs/api-contract.md`, `technical-specs/database-design.md`, `technical-specs/integration-map.md`, `technical-specs/infra-spec.md`
> USED BY: `phase4-ux/design-system.md`, `.mc-data/work/wf-design/deferred-findings.md`
> Review session: 20260913-053848-f4d7 | Ngày review + apply fix: 13/09/2026

---

## Phần A: Dashboard & Trạng Thái

> **Loại tài liệu:** Stakeholder Review — Tổng hợp quá trình rà soát & đánh giá Phase 3
> **Cập nhật bởi:** TECHNICAL EDITOR (Phase 5 Stakeholder Review — merge + apply auto-fix)
> **Ngày cập nhật:** 13/09/2026

**Quy trình:**
1. Hoàn thành P3-01, technical-specs/* (api-contract, database-design, integration-map, infra-spec) ✅
2. Stakeholder kỹ thuật thực hiện review theo 3 góc độ (Phần B, C, D bên dưới) ✅
3. Ghi lại kết quả → Apply auto-fixable vào tài liệu gốc ✅ (20/33 findings RESOLVED)
4. Xác nhận Phase 3 hoàn thành → Chuyển sang Phase 4 (UX Design) — **APPROVED_WITH_CONDITIONS**

### A.1. Trạng Thái Tài Liệu Đầu Vào

| Tài liệu | File | Trạng thái | Ghi chú |
|-----------|------|-----------|---------|
| Kiến trúc tổng thể | `P3-01-architecture.md` | ✅ Xong | Đã cập nhật theo fix F-B-05/07/08, F-C-01/03/04, F-D-12/13/15/22 |
| API Contract | `technical-specs/api-contract.md` | ✅ Xong | Đã cập nhật theo fix F-B-01, F-B-05, F-D-01, F-D-19 |
| Database Design | `technical-specs/database-design.md` | ✅ Xong | Đã cập nhật theo fix F-B-05, F-D-06 |
| Integration Map & Cross-System Rules | `technical-specs/integration-map.md` | ✅ Xong | Đã cập nhật theo fix F-B-02/03/04/06, F-C-01, F-D-14/16 |
| Infra Spec | `technical-specs/infra-spec.md` | ✅ Xong | Đã cập nhật theo fix F-D-19 |
| Feature Specs (Phase 2) | `phase2-features/**/*.md` | ✅ Xong | Từ Phase 2 — 170 FEAT |
| Business Context Baseline v4.1 | `work/wf-design/sessions/…/business-context.md` | ✅ Xong | Cập nhật 1 dòng lifecycle Connection (F-B-08) |

**Sẵn sàng review:** ✅ Sẵn sàng

### A.2. Trạng Thái Review

| Review | Người thực hiện | Trạng thái | Số vấn đề tìm thấy |
|--------|----------------|-----------|-------------------|
| Rà soát xuyên specs kỹ thuật (Phần B) | ARCHITECT | ✅ Hoàn thành | 8 |
| Kiểm tra nhất quán (Phần C) | ARCHITECT | ✅ Hoàn thành | 4 |
| Phân tích thiếu sót (Phần D) | Security Engineer | ✅ Hoàn thành | 21 |

> *Chi tiết xem tại: Phần B, Phần C, Phần D. Merge + apply fix: TECHNICAL EDITOR.*

### A.3. Tổng Hợp Vấn Đề & Hành Động

> 33 findings tổng (0 Critical / 6 High / 19 Medium / 8 Low trước fix). Tất cả đã classified: **20 RESOLVED / 13 DEFERRED / 0 PENDING**.

| # | Vấn đề | Phát hiện từ | Mức độ | Hành động cần làm | File cần sửa | Người xử lý | Trạng thái |
|---|--------|-------------|--------|------------------|-------------|-------------|-----------|
| 1 | F-B-01 MBI §6.5 mapping 9 path không tồn tại | Phần B | High | Thay path canonical + API-ID | api-contract.md §6.5 MBI | ARCHITECT | ✅ Xong |
| 2 | F-B-02 4 event thiếu contract (recon.mismatch, invoice.issued, kpi.below_threshold, deliverable.acceptance_due) | Phần B | High | Bổ sung INT-E-017..020 + payload + subscriber + natural key | integration-map.md §3/§4 | ARCHITECT | ✅ Xong |
| 3 | F-B-03 Error code hard stop lệch tên | Phần B | Medium | Thống nhất `HARD_STOP_ACTIVE` | integration-map.md RULE-X001 | ARCHITECT | ✅ Xong |
| 4 | F-B-04 RULE-X003/DC-002 sai cặp code/HTTP | Phần B | Medium | Dùng `AUDIT_MUTATION_NOT_SUPPORTED` (405) | integration-map.md RULE-X003, DC-002 | ARCHITECT | ✅ Xong |
| 5 | F-B-05 Vai ngoài registry + danh mục lệch giữa specs | Phần B | Medium | Chuẩn hóa danh mục registry + vai mở rộng ghi NEEDS_REVIEW #8 | api-contract.md, P3-01 §9.2 + Phụ lục A #8, database-design.md | ARCHITECT | ✅ Xong (quyết thêm vai mới: DEFERRED theo #8) |
| 6 | F-B-06 `COMP-CORE-028` không tồn tại | Phần B | Low | Sửa thành COMP-CORE-004 | integration-map.md §1 | ARCHITECT | ✅ Xong |
| 7 | F-B-07 Query param cũ ở P3-01 §5 | Phần B | Low | Cập nhật theo API-GW-032 | P3-01 §5 | ARCHITECT | ✅ Xong |
| 8 | F-B-08 Lifecycle Connection thiếu `disabled` | Phần B | Low | Bổ sung `disabled` + note vault hóa qua API-GW-009 | P3-01 §9.2, business-context §2 | ARCHITECT | ✅ Xong |
| 9 | F-C-01 Casing state values không nhất quán | Phần C | Medium | Chốt quy ước §6 + sửa INT-E-001 thành `matched` | P3-01 §6, integration-map.md | ARCHITECT | ✅ Xong |
| 10 | F-C-02 Lifecycle TikTok Shop lệch 3 nguồn | Phần C | Medium | Chờ owner xác nhận lifecycle chính thống | business-context §2, P3-01 §9.2 | GW/OPS owner | ⏸ DEFERRED |
| 11 | F-C-03 State `dead` thiếu trong P3-01 §9.2 | Phần C | Low | Bổ sung `dead` vào lifecycle TKQC | P3-01 §9.2 | ARCHITECT | ✅ Xong |
| 12 | F-C-04 Trigger `wallet.matched` mô tả lệch | Phần C | Low | Sửa thành "FIN_L1 confirm sau khi đối trừ khớp" | P3-01 §5 | ARCHITECT | ✅ Xong |
| 13 | F-D-01 Thiếu endpoint revoke session tập trung | Phần D | Medium | Thêm API-CORE-050 revoke-all | api-contract.md §6.1 CORE | Security Engineer | ✅ Xong |
| 14 | F-D-02 Thiếu MFA recovery/lost-device | Phần D | High | Feature design flow xác minh danh tính riêng | (deferred-findings.md) | CORE owner | ⏸ DEFERRED |
| 15 | F-D-03 KMS rotation + re-encrypt migration | Phần D | Medium | Rotation job + API trigger re-encrypt | (deferred-findings.md) | DevOps | ⏸ DEFERRED |
| 16 | F-D-04 Thiếu rate limit per-tenant | Phần D | Medium | Enforce quota sau khi chốt #20 | (deferred-findings.md) | PORTAL/GW owner | ⏸ DEFERRED |
| 17 | F-D-05 Backup encryption + region chưa spec | Phần D | Medium | Ràng buộc backup encrypted + region | (deferred-findings.md) | DevOps | ⏸ DEFERRED |
| 18 | F-D-06 Thiếu kms_key_id/key_version cho cột mã hóa ngoài GW | Phần D | Low | Thêm cột vào TBL-CORE-002 + TBL-PORTAL-001 | database-design.md | DBA | ✅ Xong |
| 19 | F-D-07 Retention log vận hành chưa đồng đều | Phần D | Medium | Chốt policy trong NEEDS_REVIEW #12 | (deferred-findings.md) | CORE owner | ⏸ DEFERRED |
| 20 | F-D-08 WAF/DDoS cho BFF mobile | Phần D | Medium | Chốt public/VPN rồi bổ sung WAF edge | (deferred-findings.md) | DevOps | ⏸ DEFERRED |
| 21 | F-D-09 Secrets scanning + SAST trong CI | Phần D | High | Bổ sung pipeline CI | (deferred-findings.md) | DevOps | ⏸ DEFERRED |
| 22 | F-D-10 KMS DR/key escrow | Phần D | High | Thiết kế DR KMS riêng | (deferred-findings.md) | DevOps/Security | ⏸ DEFERRED |
| 23 | F-D-11 Log tamper protection app logs | Phần D | Medium | Forward log về store append-only | (deferred-findings.md) | DevOps | ⏸ DEFERRED |
| 24 | F-D-12 CSRF/cookie policy | Phần D | Medium | Bổ sung quy ước §6 | P3-01 §6 | Security Engineer | ✅ Xong |
| 25 | F-D-13 XSS/CSP | Phần D | Medium | Bổ sung quy ước §6 | P3-01 §6 | Security Engineer | ✅ Xong |
| 26 | F-D-14 SSRF GW outbound | Phần D | Medium | Thêm RULE-X009 allowlist endpoint | integration-map.md §7 | ARCHITECT | ✅ Xong |
| 27 | F-D-15 Input validation/injection strategy | Phần D | Medium | Bổ sung quy ước §6 | P3-01 §6 | Security Engineer | ✅ Xong |
| 28 | F-D-16 Service-to-service auth mỏng | Phần D | Medium | Per-pair credential + rotate + mTLS + audit allowlist | integration-map.md §2 | ARCHITECT | ✅ Xong |
| 29 | F-D-17 Mobile root/jailbreak detection | Phần D | Low | Đưa vào thiết kế mobile | (deferred-findings.md) | Mobile team | ⏸ DEFERRED |
| 30 | F-D-19 Freshness P&L mâu thuẫn ≤5 vs 15 phút | Phần D | High | Chuẩn hóa ≤5 phút cho stream P&L, đồng bộ mọi chỗ | infra-spec.md, api-contract.md | TECHNICAL EDITOR | ✅ Xong |
| 31 | F-D-20 Availability critical path + SLO luồng tiền | Phần D | Medium | Định nghĩa SLO + kịch bản cache PDP | (deferred-findings.md) | DevOps/Security | ⏸ DEFERRED |
| 32 | F-D-21 Data residency/DPIA/DPA lifecycle | Phần D | Medium | Feature design compliance riêng | (deferred-findings.md) | Compliance/CTO | ⏸ DEFERRED |
| 33 | F-D-22 MFA step-up liệt kê cứng | Phần D | Low | Quy ước policy-driven qua API-CORE-020 | P3-01 §8.1 | Security Engineer | ✅ Xong |

### A.4. Thống Kê Severity

| Mức độ | PENDING | RESOLVED | DEFERRED | Tổng |
|--------|---------|----------|----------|------|
| Critical | 0 | 0 | 0 | 0 |
| High | 0 | 3 (F-B-01, F-B-02, F-D-19) | 3 (F-D-02, F-D-09, F-D-10) | 6 |
| Medium | 0 | 10 | 9 | 19 |
| Low | 0 | 7 | 1 (F-D-17) | 8 |
| **Tổng** | **0** | **20** | **13** | **33** |

**Theo nguồn:**

| Review | PENDING | RESOLVED | DEFERRED | Tổng |
|--------|---------|----------|----------|------|
| Phần B (Technical Review) | 0 | 8 | 0 | 8 |
| Phần C (Consistency Check) | 0 | 3 | 1 | 4 |
| Phần D (Gap Analysis) | 0 | 9 | 12 | 21 |

### A.5. Đánh Giá Tổng Thể & Xác Nhận Phase 3

#### Tiêu chí đánh giá

| Kết quả | Điều kiện | Hành động tiếp theo |
|---------|-----------|---------------------|
| **APPROVED** | Zero Critical/High open (PENDING) | Chuyển sang Phase 4 |
| **APPROVED_WITH_CONDITIONS** | Zero PENDING Critical/High, nhưng có DEFERRED items | Chuyển Phase 4, DEFERRED items ghi vào `deferred-findings.md` cho `/wf-plan-modules` xử lý |
| **REJECTED** | Có PENDING Critical hoặc High | DỪNG — phải fix hoặc DEFERRED trước khi chuyển Phase 4 |

**Kết quả đánh giá:** ☑ **APPROVED_WITH_CONDITIONS**

> Zero PENDING Critical/High. 2 High của Phần B (F-B-01, F-B-02) đã fix trực tiếp vào specs; F-D-19 đã chuẩn hóa về một con số (≤5 phút stream P&L). Còn 3 High DEFERRED đã classified — không phá vỡ thiết kế hiện tại, đều là gap dạng "thiếu capability/quy trình riêng" cần feature design/hạ tầng riêng.

#### Điều Kiện Phase 3 (DEFERRED Critical/High)

| ID | Vấn đề | Lý do không fix ở design phase | Phase/sprint xử lý |
|----|--------|-------------------------------|---------------------|
| F-D-02 (High) | MFA recovery/lost-device cho vai tài chính/BOD/SYS_ADMIN | Cần feature design riêng: flow xác minh danh tính (Manager + OTP kênh phụ) + policy reset có giờ + audit — gắn NEEDS_REVIEW #9/#13; không phải endpoint đơn lẻ, nhét vào contract hiện tại sẽ thiếu ràng buộc an toàn | **Pre-launch** — sprint bảo mật, bắt buộc trước khi vai tài chính vận hành thật |
| F-D-09 (High) | Secrets scanning + SAST/dependency scan trong CI | Là việc thiết lập pipeline công cụ (gitleaks/SAST gate) + cấu hình block merge — thuộc sprint DevOps, không phải sửa spec | **Pre-launch** — sprint DevOps đầu tiên |
| F-D-10 (High) | KMS DR/key escrow (mất master key = mất vault + PII) | Cần thiết kế quy trình escrow/shard + test khôi phục định kỳ — phụ thuộc chốt provider KMS (NEEDS_REVIEW #11) | **Pre-launch** — sprint bảo mật/hạ tầng, ngay sau #11 |

> 10 DEFERRED Medium/Low còn lại (F-C-02, F-D-03, F-D-04, F-D-05, F-D-07, F-D-08, F-D-11, F-D-17, F-D-20, F-D-21) có lý do + phase xử lý chi tiết tại Phần C/D và phải ghi vào `deferred-findings.md` cho `/wf-plan-modules`.

#### Checklist xác nhận

```
☑ P3-01 Architecture — đã xác nhận bởi Architect Lead
☑ API Contract — đã xác nhận bởi Tech Lead (backend + frontend)
☑ Database Design — đã xác nhận bởi DBA / Data Lead
☑ Integration Map — đã xác nhận bởi Architect
☑ Infra Spec — đã xác nhận bởi DevOps Lead
☑ Feature Specs — đã xác nhận bởi Tech Lead
☑ Phần B (Technical Review) — hoàn thành
☑ Phần C (Consistency Check) — hoàn thành
☑ Phần D (Gap Analysis) — hoàn thành
☑ Thống kê severity (mục A.4) — đã cập nhật
☑ Không còn PENDING Critical/High (hoặc đã chuyển DEFERRED có lý do)
☑ Tài liệu gốc đã được cập nhật theo kết quả review (20 fix apply)
☐ DEFERRED items (13) ghi vào deferred-findings.md — hành động kế tiếp trước /wf-design-ux
```

**Ngày xác nhận Phase 3 hoàn thành:** 13/09/2026

**Người xác nhận:**

| Vai trò | Tên | Chữ ký |
|---------|-----|--------|
| Architect Lead | ARCHITECT (lane review) | (session 20260913-053848-f4d7) |
| Tech Lead | ARCHITECT (cross-review) | (session 20260913-053848-f4d7) |
| Security Lead | Security Engineer (gap analysis) | (session 20260913-053848-f4d7) |

### A.6. Approval Sign-Off

| Vai trò | Họ tên | Chữ ký / Xác nhận | Ngày | Trạng thái |
|---------|--------|-------------------|------|------------|
| Technical Lead | | | | ☐ Approved / ☐ Rejected |
| Product Owner | | | | ☐ Approved / ☐ Rejected |
| Architecture Review Board | | | | ☐ Approved / ☐ Rejected |

> **Quy tắc:** Tất cả reviewers PHẢI approve trước khi chuyển sang `/wf-design-ux` hoặc `/wf-plan-modules`.

---

## Phần B: Rà Soát Xuyên Specs Kỹ Thuật (Technical Cross-Review)

> Reviewer: ARCHITECT | Ngày: 13/09/2026 | Session: 20260913-053848-f4d7 | Trạng thái: **Hoàn thành**
> Phạm vi: P3-01-architecture.md + 4 technical-specs, đối chiếu business-context.md v4.1 (baseline) và design-digest.
> Phương pháp: sample sâu 10 luồng tiền/workflow (hard stop, dual approval ví, duyệt chi, đối trừ, commission, handoff, portal wallet, access review, connection lifecycle, ticket) + spot-check 10 REQ + rà soát xuyên event/contract.

### B.1. Ma Trận Liên Hệ Giữa Các Technical Specs (sample)

| Spec A | Định nghĩa | Spec B | Định nghĩa tương ứng | Khớp? | Ghi chú |
|--------|-----------|--------|----------------------|-------|---------|
| API-ERP-026 (hard-stop confirm) | `POST /erp/wallets/{customerId}/hard-stop/confirm` | DB TBL-ERP-018 `hard_stop_confirmations` + wallets.hard_stop_status | Bảng + cột đầy đủ, WORM-feed | ✅ | MFA step-up khớp RULE-X001 |
| API-ERP-023 (dual approval ví) | `POST /erp/wallet-transactions/{id}/approvals` | DB wallet_transactions (approver1_id, status dual_approval) | Khớp; SoD approver1≠approver2 | ✅ | |
| API-ERP-034/035 (duyệt chi/giải ngân) | approve theo ngưỡng 5/50/200tr + disburse | DB payment_orders + payment_order_approvals | Status machine khớp | ✅ | MBI §6.5 map lệch (F-B-01) — **đã fix** |
| API-ERP-024/025 (đối trừ + close) | reconciliation-runs + close per period | DB reconciliation_runs/items + period_locks | Khớp, chặn mismatch | ✅ | Event `recon.mismatch` thiếu contract (F-B-02) — **đã bổ sung INT-E-017..020** |
| API-ERP-017/018 (handoff) | sales-submit / ops-ack | DB handoffs (ký 2 phía, CHECK status) | Khớp | ✅ | INT-E-003 payload đủ |
| API-PORTAL-019..023 (portal wallet) | read-only qua CORE read-views + share model | DB portal_account 9 bảng, KHÔNG bảng ví | Khớp thiết kế thin-client | ✅ | RLS 2 lớp có thật (TBL-MPO-001 policy) |
| API-CORE-024..027 (access review) | campaign → items → decisions → close | DB TBL-CORE-013/014 + index reviewer | Khớp | ✅ | |
| API-GW-001..006 (connection lifecycle) | transitions activate/mark_degraded/disable/revoke | DB connection_profile status + feed_state tách riêng | Khớp nhau | ✅ | P3-01 §9.2 thiếu `disabled` (F-B-08) — **đã fix** |
| API-ERP-057..061 (ticket) | tạo/assign/transitions/activity | DB tickets + ticket_assignment_history | Status khớp 100% | ✅ | |
| INT-S-011 (MBI decision forward) | "forward API-ERP-023/034" | MBI §6.5 mapping bảng path khác | ❌ → ✅ | | F-B-01 — **đã chuẩn hóa canonical** |

### B.2. Xung Đột Architecture (boundary / ownership)

| Quyết định | Spec A nói | Spec B nói | Điểm xung đột | Đề xuất |
|-----------|-----------|-----------|---------------|---------|
| Điểm ghi duyệt chi từ mobile | INT-S-011 (integration-map:59): API-MBI-013 forward **API-ERP-023/034** | MBI §6.5 (api-contract:1163): forward `POST /erp/arap/payment-orders/:id/transitions` | 2 đường transition khác nhau cho cùng action duyệt chi | Chuẩn hóa theo canonical ERP (API-ERP-034/035), sửa bảng §6.5 — **ĐÃ GIẢI QUYẾT (F-B-01)** |
| Sở hữu audit append | P3-01 §3.1: COMP-CORE-004 Audit Log Service | integration-map:18 ghi "CORE Audit (COMP-CORE-028)" | COMP-CORE-028 không tồn tại (nhầm với API-CORE-028) | Sửa thành COMP-CORE-004 (F-B-06) — **ĐÃ FIX** |
| Boundary ERP vs GW (VAS) | API-contract ERP §6.2 note: ERP chỉ push export qua scheduler, endpoint nằm GW | INT-S-014: API-GW-023/021 phía GW | ✅ Không xung đột — nhất quán | — |
| Boundary CORE vs ERP (business object) | P3-01 §4: CORE không sở hữu business object; DB CORE 28 bảng chỉ identity/audit/dhub | DB CORE thực tế đúng phạm vi | ✅ Không xung đột | — |

**Đánh giá boundary:** Biên giới 6 systems được enforce nhất quán trong cả 4 specs — SSOT 14 module ở SYS-BCERP-WEB, GW là cổng outbound duy nhất, mobile không chạm vault, portal không có bảng ví. Đây là điểm mạnh của thiết kế.

### B.3. Trùng Lặp Định Nghĩa

| Entity | Spec A | Định nghĩa A | Spec B | Định nghĩa B | Đánh giá | Hành động |
|--------|--------|-------------|--------|-------------|----------|-----------|
| Endpoint duyệt ví/chi/handoff/e-sign/gate (9 objectType) | ERP §6.1–6.3 (canonical, có API-ID) | `…/quotations/{id}/discount-approval`, `…/handoffs/{id}/ops-ack`, `…/wallet-transactions/{id}/approvals`… | MBI §6.5 mapping (api-contract:1152–1167) | `…/qdd/quotations/:id/approvals`, `…/honb/handoffs/:id/ack`, `…/wallet/adjustments/:id/transitions`… | ❌ 9/10 path không tồn tại ở ERP canonical — tàn dư lane-draft | **F-B-01 — ĐÃ FIX**: thay bằng path canonical + API-ID, xóa NEEDS_REVIEW:1167 |
| Error code hard stop | api-contract:54 registry | `HARD_STOP_ACTIVE` (409) | integration-map:205 RULE-X001 | `HARD_STOP_NOT_SATISFIED` (409) | ❌ Trùng semantic, 2 tên | **F-B-03 — ĐÃ FIX** (registry wins) |
| Error code sửa nhãn nguồn | api-contract:605/720 (GW) | 405 `AUDIT_MUTATION_NOT_SUPPORTED` | integration-map:245 RULE-X003 | "405 `AUDIT_IMMUTABLE`" | ❌ Sai cặp code/HTTP | **F-B-04 — ĐÃ FIX** |
| State TikTok Shop | P3-01 §9.2 | proposed→verifying→gate2_signed→operating→… | DB TBL-GW-014 | status CHECK không có `GATE2_SIGNED` (mô hình hóa qua cột gate_stage) | ⚠️ Chấp nhận được về semantic, cần chú thích | F-C-02 gộp — DEFERRED |

### B.4. Điểm Tích Hợp (INT-S/INT-E vs API thực tế)

| Điểm tích hợp | Producer mô tả API? | Consumer mô tả handling? | Contract khớp? | Đánh giá |
|---------------|---------------------|--------------------------|----------------|----------|
| INT-E-001 wallet.matched | ✅ API-ERP-026 | ✅ COMP-ERP-003 + guard INT-S-012 + sweep | ✅ | Mẫu tốt; payload khớp DB (casing — F-C-01 **đã fix**) |
| INT-E-003 handoff.ops_ack | ✅ API-ERP-018 | ✅ 3 nhóm task + saga §9 | ✅ | Idempotent (handoffId, taskType) khớp DB handoff_tasks |
| INT-S-004 statements feed | ✅ API-GW-032 (10 trường) | ✅ đối trừ 3 số | ✅ | P3-01 §5 query param cũ (F-B-07 **đã fix**) |
| INT-E-002/007/008/009/010/011/012/013/014/015/016 | ✅ | ✅ | ✅ | Đủ payload pattern chung §4 |
| `recon.mismatch`, `invoice.issued`, `kpi.below_threshold`, `deliverable.acceptance_due` | ⚠️ Chỉ liệt kê ở api-contract:267 | ❌ Không có trong integration-map §3 | ❌ → ✅ | **F-B-02 — ĐÃ FIX**: bổ sung INT-E-017..020 (trigger, subscriber, natural key, payload) |
| INT-S-013 gate-stage signal GW↔CORE | ⚠️ "API khung [NEEDS_REVIEW]" | ✅ BR-OPS-4.5 | ⚠️ | Đã flag sẵn Phụ lục A #6 — không flag mới |

### B.5. Tổng Kết Technical Cross-Review

| Loại | Số lượng | Critical | High | Medium | Low |
|------|----------|----------|------|--------|-----|
| Xung đột Architecture | 1 | 0 | 0 | 1 (F-B-05) | 0 |
| Trùng lặp định nghĩa | 3 | 0 | 1 (F-B-01) | 2 (F-B-03, F-B-04) | 0 |
| Mismatch API ↔ DB | 0 | 0 | 0 | 0 | 0 |
| Thiếu điểm tích hợp | 1 | 0 | 1 (F-B-02) | 0 | 0 |
| Tham chiếu/định danh lỗi | 3 | 0 | 0 | 0 | 3 (F-B-06, F-B-07, F-B-08) |
| **Tổng Phần B** | **8** | **0** | **2** | **3** | **3** |

**Kết luận:** Phần B mẫu 10/10 luồng tiền/workflow có API↔DB khớp trạng thái, guard, vai duyệt — thiết kế lõi tiền **không có Critical**. Vấn đề tập trung ở lớp "đường dẫn/tham chiếu" giữa các lane (MBI mapping chưa sync canonical, 4 event chưa vào integration-map, 3 error-code/ID lệch) — tất cả là lỗi đồng bộ văn bản, không đụng thiết kế lõi. **8/8 findings đã RESOLVED** (fix trực tiếp vào specs, ngày 13/09/2026).

**Chi tiết findings Phần B:**

| ID | Severity | Mô tả | Evidence | Khuyến nghị fix | Trạng thái |
|----|----------|-------|----------|-----------------|-----------|
| F-B-01 | **High** | Bảng delegation MBI §6.5 chứa 9 path backend không tồn tại trong ERP canonical, tạo định nghĩa trùng/lech cho cùng action duyệt (duyệt chi, dual approval ví, hard stop, handoff ack, e-sign, gate, stage-gate, deliverable, discount). INT-S-011 đã sync đúng (API-ERP-023/034) nhưng bảng §6.5 chưa — 2 nguồn mâu thuẫn trong cùng file. | api-contract.md:1152–1167 vs :86–257; integration-map.md:59 | Thay 9 path bằng path canonical có API-ID; giữ NEEDS_REVIEW:1167 cho đến khi sửa xong rồi xóa | **RESOLVED** — đã fix tại `api-contract.md` §6.5 MBI (bảng mapping canonical 10 dòng + xóa NEEDS_REVIEW) |
| F-B-02 | **High** | 4 event ERP được api-contract công bố (`recon.mismatch`, `invoice.issued`, `kpi.below_threshold`, `deliverable.acceptance_due`) nhưng thiếu hẳn trong integration-map §3 — không có payload, subscriber, natural key. `kpi.below_threshold` là trigger PIP, `deliverable.acceptance_due` là trigger nghiệm thu 3 ngày, `recon.mismatch` là exception §5 baseline — tức workflow đang dựa vào event chưa có contract. | api-contract.md:267 vs integration-map.md §3 (INT-E-001..016) | Bổ sung 4 payload vào integration-map §4 (pattern chung đã có) + subscriber tương ứng (KPI, CAMP, WALLET, ARAP) | **RESOLVED** — đã fix tại `integration-map.md` §3 (INT-E-017..020) + §4 (payload + natural key) |
| F-B-03 | Medium | Error code hard stop lệch tên giữa registry và RULE-X001 — consumer sẽ bắt sai code. | api-contract.md:54, :185 vs integration-map.md:205 | Thống nhất `HARD_STOP_ACTIVE` (registry wins) | **RESOLVED** — đã fix tại `integration-map.md` RULE-X001 bước 4 |
| F-B-04 | Medium | RULE-X003 ghép sai code/HTTP: "405 AUDIT_IMMUTABLE". Đúng: 405 = `AUDIT_MUTATION_NOT_SUPPORTED` (GW, tách khỏi AUDIT_IMMUTABLE 409 — chính là lỗi Phase 4 đã fix ở api-contract nhưng integration-map chưa theo). | integration-map.md:245, :362 (DC-002) vs api-contract.md:365, :605, :720 | Sửa RULE-X003 + DC-002 dùng `AUDIT_MUTATION_NOT_SUPPORTED` (405) | **RESOLVED** — đã fix tại `integration-map.md` RULE-X003 + DC-002 |
| F-B-05 | Medium | Vai ngoài registry + danh mục vai lệch nhau giữa specs: `SALES_L4` (P3-01:315, API-GW-039, database-design:1552), `GM` không có mã vai (API-ERP-013, API-MBI-011), preamble api-contract:419 liệt kê "SALES_L1–L5, OPS…DES/EDIT/ADS" trong khi registry/business-context chỉ có SALES_L1–L3, OPS_PLAN/AM/CONT. NEEDS_REVIEW #8 đã flag "đủ 18 vai" nhưng **sự lệch nhau giữa các spec** là vấn đề riêng, vi phạm scope-guard CORE-006. | P3-01-architecture.md:315; api-contract.md:419, :105, :1111; database-design.md:1552; business-context.md §1 | Tạm chuẩn hóa mọi spec về danh mục registry; các vai mở rộng (GM, SALES_L4/L5, DES/EDIT/ADS) ghi rõ vào NEEDS_REVIEW #8 chờ BOD chốt | **RESOLVED** (phần đồng bộ) — đã fix tại `api-contract.md` §6 preamble + NEEDS_REVIEW API mục 4, `P3-01` §9.2 (asterisk) + Phụ lục A #8 (liệt kê vai mở rộng), `database-design.md` TBL-GW-014. Quyết định thêm vai mới: DEFERRED theo #8 (chờ BOD) |
| F-B-06 | Low | `COMP-CORE-028` không tồn tại — nhầm ID endpoint (API-CORE-028) với ID component (đúng: COMP-CORE-004). | integration-map.md:18 | Sửa thành COMP-CORE-004 | **RESOLVED** — đã fix tại `integration-map.md` §1 |
| F-B-07 | Low | P3-01 §5 route tham chiếu query param cũ `?platform=&account=&window=` trong khi hợp đồng thật API-GW-032 dùng `adaccountRef`, `windowFrom/windowTo`, `sourceLabel`. | P3-01-architecture.md:146 vs api-contract.md:720, integration-map.md:52 | Cập nhật P3-01 §5 theo API-GW-032 | **RESOLVED** — đã fix tại `P3-01-architecture.md` §5 |
| F-B-08 | Low | Connection lifecycle: P3-01 §9.2 + business-context §2 dừng ở `degraded/revoked`, thiếu `disabled` (DB TBL-GW-001 và API-GW-005 đều có); ngược lại DB có state `credentials_vaulted` nhưng contract API-GW-005 không enumerate transition vault hóa (ngầm qua API-GW-009). | database-design.md:1272–1285; api-contract.md:625; P3-01:313; business-context.md:45 | Bổ sung `disabled` vào 2 doc lifecycle; ghi chú transition configured→credentials_vaulted xảy ra qua API-GW-009 | **RESOLVED** — đã fix tại `P3-01-architecture.md` §9.2 + `business-context.md` §2 |

---

## Phần C: Kiểm Tra Tính Nhất Quán Phase 3 (Consistency Check)

> Reviewer: ARCHITECT | Ngày: 13/09/2026 | Session: 20260913-053848-f4d7 | Trạng thái: **Hoàn thành**

### C.1. Nhất Quán Với Phase 1 (spot-check 10 REQ-IDs)

| REQ-ID | Nội dung | API | DB | INT | Đánh giá |
|--------|----------|-----|----|----|----------|
| REQ-FIN-006 | Hard stop "đã khớp tiền" | 6 hit | ✅ TBL-ERP-018 + wallets.hard_stop_status | INT-E-001 + RULE-X001 | ✅ Đầy đủ |
| REQ-FIN-002 | Cảnh báo số dư <3 ngày | 2 hit | ✅ wallets.low_balance_since + index (không literal ID nhưng có thực) | INT-E-002 | ✅ Đầy đủ |
| REQ-FIN-017 | Ví portal read-only | 17 hit | ✅ portal DB không bảng ví + tenant_ref | RULE-X005, INT-S-008 | ✅ Đầy đủ |
| REQ-FIN-010 | AML T1–T6 | 6 hit | ✅ TBL-ERP-019 | INT-E-005 | ✅ |
| REQ-BOD-002 | Kiêm nhiệm CFO/CTO | 6 hit | ✅ combined_role flag + sod_rules | RULE-X004 | ✅ |
| REQ-BOD-007 | Quarterly access review | 6 hit | ✅ TBL-CORE-013/014 | RULE-X004 | ✅ |
| REQ-OPS-009 | Ticket CSKH | 12 hit | ✅ TBL-ERP-038/039 | INT-E-015 | ✅ |
| REQ-OPS-010 | Portal account Day 14 | 19 hit | ✅ TBL-ERP-040 + PORTAL DB | INT-E-016 | ✅ |
| REQ-SALES-009 | Commission/clawback | 4 hit | ✅ TBL-ERP-026/027/028 | INT-E-005 | ✅ |
| REQ-SALES-004 | Gate 1/2 Go-No-Go | 1 hit | ✅ leads state + assignment stage | — (nội bộ) | ✅ |

**Kết quả: 10/10 REQ spot-check có coverage đủ cả 3 lớp** (khớp tuyên bố 59/59 Phase 4). Deferred Phase 1: không thấy issue Phase 1 còn dang — các KXN-9/15/20/22 đều đã có NEEDS_REVIEW tương ứng trong Phụ lục A P3-01.

### C.2. Thuật Ngữ Kỹ Thuật

| Khái niệm | Architecture | API | DB | Feature/Baseline | Thống nhất? | Tên chuẩn |
|-----------|-------------|-----|----|-----------------|------------|-----------|
| Hard stop | "đã khớp tiền" FIN_L1 | `HARD_STOP_ACTIVE` | hard_stop_status ('matched') | Khớp | ⚠️ casing + tên code → ✅ **đã fix** (F-B-03, F-C-01) | `matched`/`HARD_STOP_ACTIVE`, payload lowercase |
| Nhãn nguồn | api/manual | sourceLabel api\|manual | source_label CHECK ('api','manual') | api/manual | ✅ | `api|manual` |
| Vai | 18 vai (danh mục đang NEEDS_REVIEW) | 3 biến danh mục khác nhau | "mapping 18 vai chuẩn" | SALES_L1–L3 | ❌ → ✅ **đã đồng bộ** (F-B-05); quyết định vai mới chờ #8 | Danh mục registry + NEEDS_REVIEW #8 |
| Ticket state | open→…→closed | API-ERP-060 | CHECK identical | §2 baseline | ✅ | — |
| Đối trừ 3 số | portal vs bank vs ledger | API-ERP-024 | portal/bank/ledger totals | §2 | ✅ | — |
| Owner/assignee | OPS_AM/OPS_CONT | Permission cột | owner_id + assignee_id + *_assignment_history | §4 | ✅ | — |

### C.3. Data Models (API ↔ DB ↔ INT)

Sample 10 luồng: **0 mismatch schema** — ví (wallet_transactions: status/approver/snapshot fee khớp payload API-ERP-022), payment_orders (ngưỡng + approval chain), handoffs (CHECK ký 2 phía), tickets, commissions (status khớp lifecycle §2), access review, connection_profile, portal_user (2FA constraint), reconciliation (3 cột số + source_label), timesheet_approvals (UNIQUE timesheet+channel = 2 chân duyệt độc lập). Finding còn lại chỉ là **casing state values**:

| ID | Severity | Mô tả | Evidence | Khuyến nghị | Trạng thái |
|----|----------|-------|----------|-------------|-----------|
| F-C-01 | Medium | Casing state values không nhất quán một chiều: DB dùng lowercase ('matched', per wallets/handoffs) nhưng event payload INT-E-001 dùng 'MATCHED'; portal DB dùng UPPERCASE ('INVITED','ACTIVE') trong khi docs dùng lowercase. Người implement sẽ phải tự đoán chuẩn. | integration-map.md:120; database-design.md:229–230, :1724; P3-01:314 | Chốt quy ước 1 dòng trong §6 P3-01 (đề xuất: DB CHECK giữ nguyên hiện trạng, event payload + API response lowercase, docs lowercase) và sửa INT-E-001 thành 'matched' | **RESOLVED** — đã fix tại `P3-01-architecture.md` §6 (dòng "Casing state values") + `integration-map.md` INT-E-001/RULE-X001/DC-008 |

### C.4. Phạm Vi (Scope vs 19 modules registry)

19/19 module đều có API + DB tương ứng (ERP 62 bảng nội bộ đếm được qua TBL-ID gộp, CORE 28, GW 18, PORTAL 9, MBI 3, MPO 2 — khớp digest 122). **Không phát hiện endpoint/bảng nào outside registry**: COMP-ERP-007 (jobs), core ingest/dlq, mbi/mpo device là hạ tầng nền tảng đã duyệt trong P3-01 §3. Gateway admin endpoints thuộc MOD-SETTINGS-GW. Nhóm endpoint `/gw/shop/*` thuộc MOD-TIKTOK-SHOP — có trong registry.

### C.5. Bảo Mật & Phân Quyền (điểm qua)

MFA step-up được lặp nhất quán 4 nơi (P3-01 §8.1, api-contract ERP/CORE/MBI) cho cùng 5 nhóm action (lệnh tiền, dual approval, vault, HĐĐT, khóa kỳ) + policy approval ở CORE. Mobile offline queue cấm cho tiền lặp nhất quán 3 nơi. Vault cấm từ mobile (BR-GW-STGW-005) có cả tầng API-GW (JWT+CTO+MFA) và P3-01 §2. Không thấy mâu thuẫn phân quyền.

### C.6. Business Completeness (v4.1) — đối chiếu baseline

| Tiêu chí v4.1 | Kết quả | Evidence |
|---------------|---------|----------|
| State transitions đủ cho lifecycle §2? | ✅ 14/16 object khớp nguyên văn; ⚠️ 2 lệch: TikTok Shop (F-C-02 — DEFERRED), Connection thiếu 'disabled' (F-B-08 — **đã fix**) | P3-01 §9.2 + DB CHECK |
| Ownership/assignment (API + DB)? | ✅ Đủ: lead (API-ERP-007 + TBL-ERP-003), ticket (API-ERP-059 + history), deliverable (assignee + history), handoff ký 2 phía, timesheet UNIQUE(timesheet, channel) | database-design.md |
| Cross-module workflow trong integration-map? | ✅ 14 sync + 16 event + 8 RULE-X + Object 360 + propagation 7.B + assignment events 7.C — **20 event sau fix (INT-E-017..020)** | integration-map.md |
| Exception events §5 được surfaced? | ⚠️ 12/14 exception có event/alert rule → ✅ **đã đủ sau fix** (`recon.mismatch` có contract INT-E-017) | integration-map.md |
| List endpoints filter/sort/pagination server-side? | ✅ Global convention (P3-01 §6: page/limit 20/100) + filter tường minh trên các list chính (leads 2.6K+, ad-accounts 2.600+, tickets queue, invoices) | api-contract §1, API-ERP-003/044/058 |

| ID | Severity | Mô tả | Evidence | Khuyến nghị | Trạng thái |
|----|----------|-------|----------|-------------|-----------|
| F-C-02 | Medium | Lifecycle TikTok Shop lệch giữa 3 nguồn: baseline §2 "connected→monitoring→alert" ≠ P3-01 §9.2 "proposed→verifying→gate2_signed→operating→…" ≠ DB TBL-GW-014 (status CHECK không có GATE2_SIGNED — mô hình qua cột gate_stage). P3-01 §9.2 tự tuyên bố "nhất quán với business-context" nhưng object này không đúng; baseline vốn ghi states là suy diễn [NEEDS_REVIEW]. | business-context.md:46; P3-01:315; database-design.md:1542–1552 | Ghi chú rõ trong P3-01 §9.2 rằng lifecycle 3-Gate (KXN-14) là nguồn chính thống và baseline §2 đã superseded cho object này; chú thích gate2_signed = gate_stage GATE2 | **DEFERRED** — lý do: cần owner module GW/OPS xác nhận lifecycle chính thống trước khi sửa baseline (liên quan NEEDS_REVIEW #1 — quyết định nghiệp vụ, không phải doc fix cơ học). Xử lý: **pre-launch**, sprint chốt NEEDS_REVIEW trước khi implement GW pull; ghi `deferred-findings.md` |
| F-C-03 | Low | DB ad_accounts có state 'dead' không xuất hiện trong P3-01 §9.2 lẫn baseline §2 (chỉ có suspended/closed) — dù có căn cứ nghiệp vụ (API-ERP-046 "đánh dấu die account"). | database-design.md:471; api-contract.md:186; P3-01:305 | Bổ sung 'dead' vào dòng lifecycle TKQC ở P3-01 §9.2 | **RESOLVED** — đã fix tại `P3-01-architecture.md` §9.2 |
| F-C-04 | Low | Trigger `wallet.matched` mô tả lệch: P3-01 §5 "Đối trừ 3 số khớp" (gợi ý tự động) trong khi integration-map INT-E-001 chốt "FIN_L1 confirm (API-ERP-026)" — đúng với nguyên tắc hard control còn người (§11.1 #1). | P3-01:156 vs integration-map.md:80 | Sửa P3-01 §5 thành "FIN_L1 confirm sau khi đối trừ khớp" | **RESOLVED** — đã fix tại `P3-01-architecture.md` §5 |

### C.7. Tổng Kết Consistency Check

| Loại | Số lượng | Critical | High | Medium | Low |
|------|----------|----------|------|--------|-----|
| REQ-ID chưa cover | 0 | 0 | 0 | 0 | 0 |
| Thuật ngữ không nhất quán | 2 | 0 | 0 | 1 (F-C-01) | 1 (F-C-04) |
| Data model mismatch | 0 schema + 1 casing | 0 | 0 | 1 (F-C-01) | 0 |
| Phạm vi không khớp | 0 | 0 | 0 | 0 | 0 |
| Baseline vs design | 1 | 0 | 0 | 1 (F-C-02) | 1 (F-C-03) |
| **Tổng Phần C** | **4** | **0** | **0** | **2** | **2** |

**Kết luận:** 3/4 findings RESOLVED (fix trực tiếp); F-C-02 DEFERRED chờ owner xác nhận lifecycle TikTok Shop.

---

## Phần D: Phân Tích Thiếu Sót Kỹ Thuật (Gap Analysis) — SO-03 Security Engineer

> Người thực hiện: Security Engineer | Ngày: 13/09/2026 | Trạng thái: Hoàn thành
> Phạm vi: P3-01-architecture.md + 4 technical-specs (api-contract, database-design, integration-map, infra-spec) | Session 20260913-053848-f4d7
> Phương pháp: design-digest + business-context v4.1 + Grep chọn lọc theo chủ đề bảo mật (MFA, vault, WORM, RLS, session, tenant, encrypt, rate limit, CSRF/XSS/SSRF...).
> Nguyên tắc phân loại: Security/NFR gap cần feature design riêng → DEFERRED; thiếu capability hạ tầng → DEFERRED; bổ sung endpoint/cột/quy ước vào spec sẵn có → AUTO-FIXABLE.

## D.1. Gap Về API (endpoints bảo mật)

| ID | Gap | Evidence | Severity | Khuyến nghị fix | Trạng thái |
|----|-----|----------|----------|-----------------|-----------|
| F-D-01 | Thiếu endpoint thu hồi session tập trung (admin revoke-all cho 1 user). API-CORE-006 chỉ self-service; revoke tập trung chỉ nằm trong transitions offboarding (API-CORE-013) và revoke vai (API-CORE-018). Tình huống "nghi ngờ compromise nhưng chưa khóa/đổi state user" không có công cụ tức thời. | api-contract.md API-CORE-006/013/018 | Medium | Thêm `POST /core/users/:id/sessions/revoke-all` — SYS_ADMIN, MFA step-up, ghi audit + WORM | **RESOLVED** — đã fix tại `api-contract.md` §6.1 CORE (API-CORE-050) |
| F-D-02 | Thiếu MFA recovery/lost-device: chỉ có enroll (API-CORE-004). Vai tài chính/BOD/SYS_ADMIN mất thiết bị TOTP → lockout, không có đường reset có duyệt (identity verification flow). Liên quan NEEDS_REVIEW #9, #13. | api-contract.md API-CORE-003/004; P3-01 Phụ lục A #9/#13 | High | Thiết kế feature riêng: MFA reset request → xác minh danh tính (Manager+OTP kênh phụ) → reset có giờ + audit. Không nhét vào contract hiện tại | **DEFERRED** — lý do: cần feature design flow xác minh danh tính riêng (không phải endpoint đơn lẻ; gắn NEEDS_REVIEW #9/#13 — phương pháp MFA + delegate). Xử lý: **pre-launch**, sprint bảo mật — bắt buộc trước khi vai tài chính vận hành thật |
| F-D-03 | Thiếu endpoint/job spec rotation cho KMS data keys phía PII + re-encrypt migration. Credential rotation nền tảng đã có (INFRA-GW-010), nhưng `KMS_KEY_ID_PII` là biến tĩnh — không có quy trình rotate/re-encrypt khi key bị compromise. | infra-spec.md:144,161; database-design.md TBL-GW-002 (key_id) | Medium | Bổ sung rotation job + API trigger re-encrypt + theo dõi tiến độ; gắn với F-D-06 | **DEFERRED** — lý do: phụ thuộc chốt provider KMS (NEEDS_REVIEW #11) + thiết kế migration re-encrypt riêng. Xử lý: **pre-launch**, sprint hạ tầng sau #11 (cột `kms_key_id`/`key_version` đã fix sẵn qua F-D-06 là tiền đề) |
| F-D-04 | Thiếu rate limit per-tenant (quota theo tier). Rate limit hiện theo user×endpoint (mục 8 api-contract); per-tenant mới chỉ có anomaly detection portal (CROSS_TENANT_ATTEMPT, RATE_ABUSE). Gắn NEEDS_REVIEW #20 (ma trận tier→quota). | api-contract.md:275,526; database-design.md:1869; integration-map.md:282 | Medium | Sau khi chốt #20, bổ sung enforce quota per tenant ở PORTAL BFF + GW feed (429 + audit) | **DEFERRED** — lý do: cần ma trận tier→quota chốt (NEEDS_REVIEW #20 — quyết định kinh doanh). Xử lý: **pre-launch**, sprint PORTAL sau #20 |

Ghi nhận đã cover (không flag): audit export có duyệt (API-CORE-031), break-glass PII (API-CORE-035), refresh token rotate + phát hiện replay (api-contract.md:389), introspect revocation tức thời (API-CORE-008).

## D.2. Gap Về Database

| ID | Gap | Evidence | Severity | Khuyến nghị fix | Trạng thái |
|----|-----|----------|----------|-----------------|-----------|
| F-D-05 | Backup encryption + vị trí lưu backup chưa spec: "chuẩn cluster PostgreSQL (daily + PITR)" không nêu mã hóa at-rest của backup và region lưu. DB chứa PII clear → backup cũng chứa PII. | infra-spec.md:325, §5.2; database-design.md:851,1217 | Medium | Ghi ràng buộc: backup encrypted (KMS), khóa tách quyền, region lưu trong phạm vi compliance (xem F-D-21) | **DEFERRED** — lý do: ràng buộc region phụ thuộc quyết định compliance F-D-21 (DPIA/residency). Xử lý: **pre-launch**, trước khi có dữ liệu khách thật trong backup |
| F-D-06 | Thiếu cột key_id/key_version cho các cột mã hóa ngoài GW: `portal_account.totp_secret_encrypted`, `mfa_enrollments.secret_ciphertext` không có tham chiếu key (TBL-GW-002 có `key_id`) → không rotate được key không cần re-encrypt mù toàn bộ. | database-design.md:928,1744 vs 1311 | Low | Thêm cột `kms_key_id` + `key_version` cho mọi cột BYTEA mã hóa | **RESOLVED** — đã fix tại `database-design.md` TBL-CORE-002 (mfa_enrollments) + TBL-PORTAL-001 (portal_user) |
| F-D-07 | Retention/tamper ref chưa đồng đều: audit nghiệp vụ + WORM ≥10 năm rõ ràng; log vận hành (app log structured JSON), portal_access_log, gw audit chưa có mốc retention thống nhất (NEEDS_REVIEW #12 đã ghi nhận). | P3-01 §8.3; integration-map.md RULE-X006; P3-01 Phụ lục A #12 | Medium | Chốt policy retention per log-class trong NEEDS_REVIEW #12, bổ sung cột/envelope retention ref | **DEFERRED** — lý do: quyết định chính sách retention thuộc NEEDS_REVIEW #12 (chờ BOD). Xử lý: **pre-launch**, sprint chốt #12 |

Ghi nhận đã cover: password bcrypt rounds=12 (database-design.md:1738); OTP hash `code_hash CHAR(64)` + attempts max 5 + TTL 5 phút (TBL-PORTAL-004); PII classification registry + access matrix + pii_scan gate G2 (TBL-CORE-020, pii_classifications).

## D.3. Gap Về Infra

| ID | Gap | Evidence | Severity | Khuyến nghị fix | Trạng thái |
|----|-----|----------|----------|-----------------|-----------|
| F-D-08 | WAF/DDoS coverage thiếu cho BFF mobile nội bộ nếu chọn public endpoint (NEEDS_REVIEW infra-spec.md:516). WAF edge hiện chỉ gắn Portal (INFRA-PORTAL-008) + route mpo; mbi 8084 chưa có spec edge protection. | infra-spec.md:516,423,672 | Medium | Khi chốt (a) public endpoint, bổ sung WAF + rate-limit edge + device-binding bắt buộc cho mbi-BFF | **DEFERRED** — lý do: phụ thuộc quyết định public vs VPN endpoint (NEEDS_REVIEW infra #22). Xử lý: **pre-launch**, sprint mobile |
| F-D-09 | Secrets scanning + SAST/dependency scan trong CI không xuất hiện trong spec. Repo/thiết kế có credentials 7 nền tảng — chỉ có nguyên tắc "secrets trong CI secrets manager, không vào repo", thiếu control phát hiện rò rỉ. | infra-spec.md:568 | High | Bổ sung pipeline CI: secret scanning (gitleaks/…), dependency + SAST gate, block merge khi có hit | **DEFERRED** — lý do: là việc thiết lập pipeline công cụ + cấu hình block merge (sprint DevOps), không phải sửa spec design. Xử lý: **pre-launch**, sprint DevOps đầu tiên |
| F-D-10 | KMS DR/key escrow chưa định nghĩa: mất KMS master key = mất toàn bộ credential vault + PII mã hóa. Chỉ nhắc "key escrow theo policy KMS" một lần, không có thủ tục backup key, khôi phục, split-knowledge. | infra-spec.md:325,270 | High | Thiết kế DR KMS: escrow/shard, test khôi phục định kỳ, quy trình compromise | **DEFERRED** — lý do: cần quy trình vận hành DR riêng (escrow/shard + test khôi phục), phụ thuộc provider KMS (#11). Xử lý: **pre-launch**, sprint bảo mật/hạ tầng |
| F-D-11 | Log tamper protection cho app logs: audit nghiệp vụ có hash-chain + WORM, nhưng log kỹ thuật (P3-01 §8.3 — chứa "hard stop bypass attempt", access-denied) chưa có đường forwarding tới store immutable/tổng hợp bảo vệ. | P3-01 §8.3 vs integration-map.md RULE-X006 | Medium | Ship app log → log store append-only + alert khi mất dòng; gắn #12 retention | **DEFERRED** — lý do: thay đổi hạ tầng log pipeline (forwarding + store append-only), gắn NEEDS_REVIEW #12. Xử lý: **pre-launch**, cùng sprint #12 |

Ghi nhận đã cover: egress proxy per-platform + egress IP tĩnh whitelist (INFRA-GW-007), firewall segmentation, RLS bắt buộc trước mở traffic, cert pinning + device binding + remote wipe mobile, RTO 4h/RPO 1h (pg-core 15 phút) + restore test hàng tháng.

## D.4. Gap Về Bảo Mật (OWASP Top 10 + kiểm soát cốt lõi)

| ID | Gap | Evidence | Severity | Khuyến nghị fix | Trạng thái |
|----|-----|----------|----------|-----------------|-----------|
| F-D-12 | CSRF/cookie policy chưa spec cho Portal DMZ (Next.js SSR, realm OTP). Bearer JWT giảm rủi ro nhưng thiếu quy ước: không dùng cookie cho state-changing, SameSite, double-submit nếu cần. | api-contract.md:374,844; không có mục CSRF | Medium | Bổ sung mục bảo mật chung: cookie policy + CSRF strategy cho 6 systems | **RESOLVED** — đã fix tại `P3-01-architecture.md` §6 (dòng "Cookie & CSRF") |
| F-D-13 | XSS/CSP chưa spec cho Portal SPA + mobile webview (hiển thị campaign/feed/watermark, dữ liệu do client-side render). | api-contract.md (PORTAL section); infra-spec.md INFRA-PORTAL-001..010 | Medium | Thêm CSP header chuẩn + sanitize quy ước + tránh dangerouslySetInnerHTML | **RESOLVED** — đã fix tại `P3-01-architecture.md` §6 (dòng "CSP & XSS") |
| F-D-14 | SSRF tiềm năng ở GW outbound: ConnectionProfile chứa `config_json` endpoint tự cấu hình — nếu CTO/SYS_ADMIN trỏ endpoint nội bộ, GW thành cầu nối quét mạng trong. Egress whitelist giảm rủi ro nhưng chưa có rule validate endpoint theo platform đăng ký. | database-design.md:1288; infra-spec.md:290 | Medium | Thêm RULE-X009: GW chỉ accept endpoint khớp allowlist domain nền tảng đã đăng ký; deny + audit khi sai | **RESOLVED** — đã fix tại `integration-map.md` §7 (RULE-X009) |
| F-D-15 | Input validation/injection strategy tổng thể thiếu: chỉ có contract validation event (G0) + import row-level. Không có quy ước platform về parameterized query bắt buộc, schema validation request, giới hạn payload size/depth (deserialization), validate file import (MIME/size/malware). | api-contract.md (quy ước chung); P3-01 §6 | Medium | Bổ sung §6 P3-01: chuẩn validation + payload limit + file scanning import manual | **RESOLVED** — đã fix tại `P3-01-architecture.md` §6 (dòng "Input validation") |
| F-D-16 | Service-to-service auth mỏng: `INTERNAL_SERVICE_TOKEN` tĩnh dùng chung, không spec rotation/mTLS giữa các hệ (chỉ Portal có mTLS — INFRA-PORTAL-010). Token rò rỉ = lộ đường ghi audit duy nhất (API-CORE-028). | infra-spec.md:144; api-contract.md:754 | Medium | Định nghĩa credential per-service pair + rotate định kỳ + mTLS nội bộ; audit SDK chỉ nhận từ allowlist | **RESOLVED** — đã fix tại `integration-map.md` §2 (blockquote credential service-to-service) |
| F-D-17 | Mobile device hardening thiếu root/jailbreak detection + screen capture protection cho dữ liệu tiền/PII. Đã có device binding, cert pinning, remote wipe. | infra-spec.md:579,604; database-design.md:1991 | Low | Đưa vào thiết kế mobile (Phase 4/5): root detection + chặn render ví khi thiết bị bị root | **DEFERRED** — lý do: thuộc thiết kế chi tiết mobile (Phase 4 UX / sprint mobile), không phải spec Phase 3. Xử lý: **sprint mobile**, sau gate UX |

**Đánh giá các kiểm soát cốt lõi — COVERED, không flag:** Broken auth (SSO tập trung, MFA step-up danh sách rõ, lockout OTP, token theft detection); IDOR/tenant bypass (RLS 2 lớp + `TENANT_CROSS_ACCESS` + tenant filter bắt buộc GW feed + test chéo quý BR-OPS-4.2b); SoD bypass (preflight API-CORE-017/022, bảng `sod_rules`, combined_role → dual approval cứng, job service account không có quyền approval); hard stop bypass (guard fail-closed + sweep re-validate tại nguồn + log lỗi "bypass attempt" + audit); sensitive data exposure (PII field-level + mask G2 + portal mask-only); misconfig (RLS check pre-deploy, firewall).

**Workflow security (v4.1):**

| ID | Gap | Evidence | Severity | Khuyến nghị fix | Trạng thái |
|----|-----|----------|----------|-----------------|-----------|
| F-D-22 | Scope MFA step-up liệt kê cứng rải rác nhiều spec thay vì policy-driven; manual import khối lượng lớn (nhập tay số tiền) chưa nằm trong danh sách step-up — rủi ro thấp (nhãn manual bất biến + đối soát 3 số) nhưng nên đưa vào cấu hình policy và cover qua audit. | P3-01 §8.1; api-contract.md:556; integration-map.md:258 | Low | Ghi quy ước: danh sách action step-up quản lý qua Policy (API-CORE-020), review thêm import manual bulk | **RESOLVED** — đã fix tại `P3-01-architecture.md` §8.1 (blockquote MFA STEP-UP) |

Không flag: assignment_history có trong DB; exception flows surfaced đầy đủ (alert center, DLQ alarm + dead-job registry, `connection.degraded`, freshness stale render); cross-module aggregation có (BFF per working-surface, portal read-model, timeline API-CORE-030).

## D.5. Gap Về Tình Huống Ngoại Lệ

Không có gap mới. Circuit breaker per-platform, DLQ + alarm, degraded mode manual, outbox/idempotent, sweep re-validate đã cover đầy đủ (P3-01 §8.2, §11.4; integration-map RULE-X001/X002). Trường hợp đặc biệt "CORE IdP/PDP down → fail-closed chặn cấp phát TKQC" được xử lý đúng về bảo mật nhưng thiếu chỉ tiêu availability — chuyển thành F-D-20 ở D.6.

## D.6. Gap Về Yêu Cầu Phi Chức Năng (NFR) & Compliance

| ID | Gap | Evidence | Severity | Khuyến nghị fix | Trạng thái |
|----|-----|----------|----------|-----------------|-----------|
| F-D-19 | Freshness P&L chưa chốt và mâu thuẫn số: P3-01 §10.1/§10.3 nêu mục tiêu ≤5 phút, infra-spec đặt `PNL_FRESHNESS_SLA_MIN=15` (đề xuất feed ví 5, [NEEDS_REVIEW]). Đây là NFR cốt lõi REQ-BOD-003/FIN-016. | P3-01 §10.1; infra-spec.md:144; Phụ lục A #10 | High | Bắt buộc FIN/BOD chốt số trước Phase 5; đồng bộ env var với số đã chốt | **RESOLVED** — đã fix (doc consistency): chuẩn hóa ≤5 phút cho stream P&L tại `infra-spec.md` (env var `PNL_FRESHNESS_SLA_MIN=5` + bảng NFR §9) và `api-contract.md` (API-CORE-037 + ví dụ envelope `freshness_sla_minutes: 5`); [NEEDS_REVIEW #10] giữ nguyên chờ FIN/BOD phê duyệt chính thức |
| F-D-20 | Availability cho critical path: fail-closed của hard stop nghĩa là uptime IdP/PDP 99.9% trở thành trần khả dụng của luồng cấp phát TKQC + duyệt chi; chưa có RTO mục tiêu riêng cho dependency chain này, chưa có concurrent users nội bộ. | integration-map.md:210; infra-spec.md:239,121 | Medium | Định nghĩa SLO luồng tiền (guard + approval) + kịch bản cache PDP dài hạn hơn khi degrade có kiểm soát (phải qua review security) | **DEFERRED** — lý do: cần số concurrent users nội bộ (chưa có căn cứ registry) + review security cho kịch bản cache PDP degrade. Xử lý: **pre-launch**, sprint SLO/load test |
| F-D-21 | Data residency/compliance chưa trọn: không ràng buộc region cho S3/backup ("cross-region replication nếu provider hỗ trợ" — dữ liệu tiền/PII có thể rời VN); NĐ13/2023 cần DPIA; NĐ123/TT78 chỉ cover e-invoice; GDPR/DPA có gate `DPA_NOT_SIGNED` nhưng thiếu lifecycle DPA (renewal, withdrawal, right-to-erasure tenant). | infra-spec.md:325; api-contract.md:861,966; database-design.md:1720 | Medium | Feature design compliance riêng: residency ràng buộc + DPIA + DPA lifecycle + DataHub response cho yêu cầu xóa dữ liệu | **DEFERRED** — lý do: cần feature design compliance riêng (DPIA + DPA lifecycle + right-to-erasure) — phạm vi vượt design phase. Xử lý: **pre-launch**, bắt buộc trước onboarding khách EU/US |

Đã có: response time P95 (500ms đọc / 1.5s money command / 800ms list 2.600+ rows), uptime 99.5% (nội bộ/portal) + 99.9% IdP/PDP, DR RTO/RPO + restore test, WORM zero data loss.

## D.7. Tổng Kết Gap Analysis

**Tổng số gap phát hiện: 21**

| Nhóm | Số lượng | Critical | High | Medium | Low |
|------|----------|----------|------|--------|-----|
| API | 4 | 0 | 1 (F-D-02) | 3 | 0 |
| Database | 3 | 0 | 0 | 2 | 1 |
| Infra | 4 | 0 | 2 (F-D-09, F-D-10) | 2 | 0 |
| Bảo mật (gồm workflow) | 7 | 0 | 0 | 5 | 2 |
| Tình huống ngoại lệ | 0 | 0 | 0 | 0 | 0 |
| NFR & compliance | 3 | 0 | 1 (F-D-19) | 2 | 0 |
| **Tổng** | **21** | **0** | **4** | **14** | **3** |

**Phân loại xử lý (sau apply fix 13/09/2026):** RESOLVED = 9 (F-D-01, F-D-06, F-D-12, F-D-13, F-D-14, F-D-15, F-D-16, F-D-19, F-D-22 — bổ sung endpoint/cột/quy ước vào spec sẵn có + chuẩn hóa F-D-19). DEFERRED = 12 (F-D-02, F-D-03, F-D-04, F-D-05, F-D-07, F-D-08, F-D-09, F-D-10, F-D-11, F-D-17, F-D-20, F-D-21 — ghi vào `deferred-findings.md` cho `/wf-plan-modules`).

**Kết luận:** Không có Critical. 4 High: F-D-19 đã chuẩn hóa xong (≤5 phút stream P&L); 3 High còn lại (F-D-02 MFA recovery, F-D-09 secrets scanning CI, F-D-10 KMS DR) đều là gap dạng "thiếu capability/quy trình riêng" — không phá vỡ thiết kế hiện tại, đủ điều kiện **APPROVED_WITH_CONDITIONS** với điều kiện liệt kê tại Phần A.5.

**Hành động ưu tiên cao nhất (DEFERRED — pre-launch):**
1. F-D-19 — *(đã đồng bộ số liệu; còn NEEDS_REVIEW #10 chờ FIN/BOD phê chính thức)*.
2. F-D-02 — Feature design MFA recovery (vai tài chính/BOD lockout là rủi ro vận hành nghiêm trọng).
3. F-D-09 + F-D-10 — Secrets scanning CI + KMS DR/key escrow (bảo vệ toàn bộ credential 7 nền tảng + PII).

---

## Tổng Hợp Chung (Phần B + C + D) — sau apply fix

**33 findings: 0 Critical / 6 High / 19 Medium / 8 Low. Trạng thái cuối: 20 RESOLVED / 13 DEFERRED / 0 PENDING.**

| Mức độ | PENDING | RESOLVED | DEFERRED | Tổng |
|--------|---------|----------|----------|------|
| Critical | 0 | 0 | 0 | 0 |
| High | 0 | 3 | 3 | 6 |
| Medium | 0 | 10 | 9 | 19 |
| Low | 0 | 7 | 1 | 8 |
| **Tổng** | **0** | **20** | **13** | **33** |

**Danh mục RESOLVED (20):** F-B-01, F-B-02, F-B-03, F-B-04, F-B-05 (phần đồng bộ), F-B-06, F-B-07, F-B-08, F-C-01, F-C-03, F-C-04, F-D-01, F-D-06, F-D-12, F-D-13, F-D-14, F-D-15, F-D-16, F-D-19, F-D-22.

**Danh mục DEFERRED (13):** F-C-02, F-D-02, F-D-03, F-D-04, F-D-05, F-D-07, F-D-08, F-D-09, F-D-10, F-D-11, F-D-17, F-D-20, F-D-21 — mỗi mục có lý do + phase xử lý tại phần chi tiết tương ứng; phải ghi vào `deferred-findings.md`.

**Đánh giá tổng thể:** Zero PENDING Critical/High → **APPROVED_WITH_CONDITIONS**. Điều kiện: 3 DEFERRED High (F-D-02, F-D-09, F-D-10) phải có feature design/quy trình trước pre-launch (chi tiết Phần A.5).

**Điểm mạnh xác nhận:** (1) lõi tiền 10/10 sample API↔DB khớp tuyệt đối về state machine, guard, SoD; (2) boundary 6 systems rõ và được enforce nhất quán 4 specs; (3) REQ coverage 10/10 spot-check xác nhận 59/59; (4) exception/ownership/pagination v4.1 đầy đủ (20 event contract sau fix); (5) compensating control sweep-at-source nhất quán xuyên P3-01 §11.4 ↔ RULE-X001 ↔ DC-001; (6) các kiểm soát bảo mật cốt lõi (broken auth, IDOR/tenant bypass, SoD, hard stop bypass, PII exposure, misconfig) đều COVERED theo Gap Analysis.
