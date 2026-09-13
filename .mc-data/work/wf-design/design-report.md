# Design Report — Cross-Validation BCERP (Technical Validator)

- **Session:** `20260913-053848-f4d7`
- **Ngày chạy:** 2026-09-13
- **Phạm vi:** req-registry.json (59 REQ / 19 MOD / 170 FEAT) × 4 technical specs (`api-contract.md`, `database-design.md`, `integration-map.md`, `infra-spec.md`)
- **Phương pháp:** script node (expand token REQ/FEAT dạng nén `001/002`, range `001…005`, tiếp diễn `001, 003` và `REQ-BOD-002, FIN-008`) + judgment thủ công cho 4.3/4.5/4.9. Script lưu tại `.mc-data/work/wf-design/sessions/20260913-053848-f4d7/validation/`.

---

## §Aggregation Conflicts

**0 conflicts** — đã clean từ Phase 3 (`aggregation-result.json`: 60 components / 280 apis / 122 tables / 0 conflicts). Không có việc nào phải xử lý ở bước này.

---

## §Iteration 1 — Chạy đủ 8 checks

| Check | Nội dung | Kết quả | Errors found |
|-------|----------|---------|--------------|
| 4.2 | 59 REQ-ID được tham chiếu ≥1 lần trong technical-specs | **PASS** | 0 (59/59, đã tính dạng nén `REQ-X-001/002`) |
| 4.3 | Write endpoint chính → có entity/table | **PASS** (sample theo module group) | 0 — mọi module ghi đều có bảng: `handoffs`, `wallet_transactions`, `reconciliation_runs/items`, `hard_stop_confirmations`, `payment_orders(+approvals)`, `commissions(+clawbacks)`, `ad_accounts`, `access_review_campaigns/items` (TBL-CORE-013/014) |
| 4.4 | MOD-* trong integration-map tồn tại trong registry | **PASS** | 0 unknown (map không cần nhắc đủ 19 MOD — chỉ check chiều tham chiếu) |
| 4.5 | Feature specs Phase 2 đủ info | **PASS** (spot-check 5 file: FEAT-CORE-RBAC-002, FEAT-CORE-CAPTS-001, FEAT-GW-ARAP-001, FEAT-CORE-ADACC-002, FEAT-PORTAL-CSKH-001) | 0 — 5/5 đủ Dependencies + Acceptance, 3.163–4.344 từ, 11 headings |
| 4.6a | Trùng table_name khác TBL-ID giữa fragments | **PASS** | 0/111 CREATE TABLE trùng tên; 0 TBL-ID trùng (marker ghép `TBL-ERP-012/013` là 1 marker nhiều bảng — hợp lệ) |
| 4.6b | Trùng path+method khác API-ID | **PASS** | 0/307 row-method-path trùng |
| 4.7 | 1 error code 1 nghĩa | **FAIL → FIXED** | 5 conflict (+1 phát hiện thêm khi fix): SOD_VIOLATION (403↔409), AUDIT_IMMUTABLE (409 CORE ↔ 405 GW), QUOTA_EXCEEDED (desc lệch), INVITE_EXPIRED (409↔410), DPA_NOT_SIGNED (403↔409), OTP_REQUIRED/OTP_INVALID (401/400 PORTAL ↔ 403 MPO) |
| 4.8 | Table refs trong integration-map tồn tại trong DB | **PASS** | 4 candidate thiếu (`import_export`, `low_balance`, `payment_id`, `tenant_id`) — xác nhận **false positive**: event name / payload field / tên cột (`wallets.low_balance_since` có thật), không phải bảng |
| 4.9 | API↔DB field match (8 endpoint mẫu) | **FAIL → FIXED** | 1 mismatch: API-ERP-022 request có `related_payment_order_id`, `note` nhưng `wallet_transactions` không có cột tương ứng. 7/8 còn lại PASS (API-ERP-023, 026, 031, 034/035, 040, 018, API-PORTAL-023 read-through, API-CORE-024…027) |

**CQG-08 (đo ở iteration 1):** CQG1 = 100/170 FEAT có endpoint tham chiếu trực tiếp — **70 FEAT variant thiếu** (toàn bộ FEAT-CORE-* nghiệp vụ + FEAT-ERP-RBAC/DHUB/STGW + FEAT-GW-* + FEAT-PORTAL-SLANOT-001). CQG2 = **19/19 module có bảng** (qua FEAT tags trong database-design) — PASS ngay từ đầu.

**Ghi chú CQG1:** 70/70 variant đều có FEAT "sibling" cùng module + cùng số hiệu đã được tham chiếu — capability không mất, chỉ thiếu chú giải traceability do Phase 3 tập trung nghiệp vụ vào 1 touchpoint chính. Không phải CRITICAL gap.

---

## §Auto-fix log

| # | File | Vị trí | Loại lỗi | Nội dung fix |
|---|------|--------|----------|--------------|
| 1 | api-contract.md | §WEB Error Registry (dòng ~58) | `duplicate_error_code` | `SOD_VIOLATION` 403→**409**, desc đồng bộ canonical của SYS-CORE-BACKEND |
| 2 | api-contract.md | §GW Error Registry (dòng ~605) | `duplicate_error_code` | Tách code mới **`AUDIT_MUTATION_NOT_SUPPORTED`** (405, BR-GW-STGW-007) khỏi `AUDIT_IMMUTABLE` (409, CORE) |
| 3 | api-contract.md | API-GW-032 data contract (dòng ~720) | `duplicate_error_code` (ref) | Cập nhật reference 405 `AUDIT_IMMUTABLE` → 405 `AUDIT_MUTATION_NOT_SUPPORTED` |
| 4 | api-contract.md | §MPO Error Registry (dòng ~1237) | `duplicate_error_code` | `QUOTA_EXCEEDED` desc đồng bộ chữ PORTAL (BR-003, SC-002) |
| 5 | api-contract.md | §MPO Error Registry (dòng ~1238) | `duplicate_error_code` | `INVITE_EXPIRED` 410→**409**, desc đồng bộ PORTAL (owner của invite flow) |
| 6 | api-contract.md | §MPO Error Registry (dòng ~1239) | `duplicate_error_code` (phát hiện thêm khi fix) | `OTP_REQUIRED`/`OTP_INVALID` 403→**401/400**, đồng bộ PORTAL (BR-008) |
| 7 | api-contract.md | §MPO Error Registry (dòng ~1241) | `duplicate_error_code` | `DPA_NOT_SIGNED` 409→**403**, desc đồng bộ PORTAL (BR-FIN-605) |
| 8 | api-contract.md | Cuối file — mục **§9 FEAT Traceability** (mới) | CQG1 coverage | Bổ sung bảng 70 dòng: FEAT variant → sibling capability → touchpoint thi công → API IDs chính (sinh tự động từ mapping đã xác thực, không bịa endpoint mới) |
| 9 | database-design.md | `erp_finance.wallet_transactions` (TBL-ERP-014) | `api_db_field_mismatch` | Thêm 2 cột nullable: `related_payment_order_id UUID REFERENCES erp_finance.payment_orders(id)` và `note TEXT` — khớp request của API-ERP-022 |

Không có fix nào bịa thông tin nghiệp vụ: error code giữ HTTP của registry sở hữu (CORE/PORTAL là owner); cột mới là nullable và map 1:1 với field request đã có trong hợp đồng API; appendix CQG1 chỉ chú giải traceability từ dữ liệu mapping có thật.

---

## §Iteration 2 — Re-run sau fix

| Check | Kết quả | Remaining |
|-------|---------|-----------|
| 4.2 | PASS | 0 |
| 4.6a / 4.6b | PASS | 0 / 0 |
| 4.7 | PARTIAL | 4 pair còn flag `sameMeaning=false` do desc khác chuỗi (khác wording, cùng nghĩa + cùng HTTP) |
| CQG1 | **PASS** | 170/170 |

## §Iteration 3 — Re-run sau khi đồng bộ desc

| Check | Kết quả | Remaining |
|-------|---------|-----------|
| 4.7 | **PASS** | 0 conflict — 4 cross-system pair (SOD_VIOLATION, QUOTA_EXCEEDED, INVITE_EXPIRED, DPA_NOT_SIGNED) cùng HTTP + cùng desc chuẩn; `AUDIT_MUTATION_NOT_SUPPORTED` đã tách riêng |
| CQG1 | PASS | 170/170 |
| CQG2 | PASS | 19/19 |
| Các check khác | PASS (giữ nguyên từ iteration 2) | 0 |

---

## §CQG-08 — Content Quality

| Gate | Kết quả | Chi tiết |
|------|---------|----------|
| **CQG1** — mỗi FEAT-ID (170) ≥1 endpoint | **PASS — 170/170 (100%)** | Trước fix: 100/170 trực tiếp. Sau fix: 70 variant còn lại được map đầy đủ qua mục §9 FEAT Traceability của api-contract.md (touchpoint thật: COMP-ERP-001…007 tại SYS-BCERP-WEB, COMP-CORE-* tại CORE, adapter tại GW, BFF tại MBI/MPO/PORTAL) |
| **CQG2** — mỗi module (19) ≥1 bảng | **PASS — 19/19 (100%)** | Tất cả module có FEAT tags trong database-design.md; 111 CREATE TABLE / 6 system fragments; 0 module thiếu bảng |

---

## §Tổng kết

| Chỉ số | Giá trị |
|--------|---------|
| Số iteration chạy | **3** (giới hạn 3 — dừng đúng hạn) |
| Tổng errors phát hiện | **9** (6 error-code conflict + 1 field mismatch + 70 FEAT thiếu ref tính 1 cụm CQG1; riêng check 4.8 có 4 false positive đã loại bằng judgment, không tính lỗi) |
| Đã fix | **9/9** |
| Remaining | **0** (đạt mục tiêu) |
| ESCALATED | **0** |

### Quan sát (không phải lỗi, không fix)
- 31 CREATE TABLE không có marker TBL riêng — được cover bởi marker ghép (`TBL-ERP-012/013`, …). Số 122 bảng trong aggregation tính theo TBL token; DB thực tế có 111 CREATE TABLE + các bảng tóm tắt markdown (CORE). Không trùng lặp.
- `direction` (debit/credit) của API-ERP-022 không nằm ở `wallet_transactions` mà materialize ở `wallet_journal_lines.direction` — đúng thiết kế double-entry, không phải mismatch.
- PORTAL không có bảng ví cục bộ — read-through + cache kèm `is_stale` theo RULE-X007, đúng thiết kế.
- `deferred-findings.md` (CF6 cross-FEAT refs upstream): cụm 70 FEAT variant thiếu tham chiếu chính là bề mặt của CF6 — đã xử lý trọn ở mục §9 api-contract.md.


---

# Completion Summary (Phase 6 — 13/09/2026)

| Mục | Kết quả |
|-----|---------|
| Phase 5 Stakeholder Review | APPROVED_WITH_CONDITIONS — 33 findings: 20 RESOLVED / 13 DEFERRED / 0 PENDING (0 Critical) |
| Điều kiện Phase 3 (DEFERRED High) | F-D-02 MFA recovery (pre-launch) · F-D-09 SAST CI (pre-launch) · F-D-10 KMS DR (pre-launch, sau khi chốt provider) |
| Deferred findings | .mc-data/work/wf-design/deferred-findings.md (13 items — consumer /wf-plan-modules) |
| Registry Safe-Write | design_status: pending → completed (chỉ 1 field; 170 FEAT / 19 MOD nguyên vẹn) |
| design-summary.json | 19 modules compressed spec (api_quick_ref + db_tables + constraints + integration_calls + folder_map) |

## Deliverables cuối cùng

1. phase3-architecture/P3-01-architecture.md (7.3K từ, 11 sections)
2. technical-specs/api-contract.md (280 API) · database-design.md (122 bảng) · integration-map.md (14 sync + 16 events + 8 rules) · infra-spec.md (55 items)
3. stakeholder-review.md (8.4K từ, Phần A–D)
4. design-summary.json (canonical sync ở Phase 8) + design-input-digest.json (Phase 8)
