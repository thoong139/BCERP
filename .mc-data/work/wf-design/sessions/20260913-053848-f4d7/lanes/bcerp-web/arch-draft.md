# Architecture Draft — SYS-BCERP-WEB (BCERP Web nội bộ)

> Session 20260913-053848-f4d7 | Lane bcerp-web | $APPROACH = Platform Design, LEGACY_MODE=false (mọi decision là đề xuất mới).
> Tuân thủ business-context.md v4.1 (actor matrix, lifecycle, ownership, exceptions). Scope guard CORE-006: chỉ 14 module được chỉ định; RBAC/DATAHUB/SETTINGS-GW/CLIENT-PORTAL/TIKTOK-SHOP là consumption surface từ system owner.

## 1. Vai trò trong platform + biên giới (boundaries)

SYS-BCERP-WEB là **working surface nghiệp vụ chính** cho toàn bộ nhân sự nội bộ (BOD, FIN, SALES, OPS, HR) — nơi lead, deal, tiền giữ hộ, TKQC, campaign, ticket được thao tác hằng ngày. Hệ thống này sở hữu **backend domain của 14 module business** (theo consolidation review §6): từ thu nhận lead đến giải ngân, từ handoff đến báo cáo campaign.

**Biên giới — KHÔNG sở hữu:**
- **SYS-CORE-BACKEND**: RBAC/SSO/MFA (18 vai chuẩn, DI-006), audit WORM ≥10 năm, DataHub ETL/BI (P&L realtime, alert center). BCERP-WEB tiêu thụ.
- **SYS-INTEGRATION-GW**: connector 7 nền tảng TKQC (Meta, Google, TikTok, Bing, X, Pinterest, Yandex), VAS kế toán, credentials vault, TikTok Shop backend. BCERP-WEB gọi qua contract API, tôn trọng degraded mode.
- **SYS-PORTAL-WEB / SYS-MOBILE-PORTAL**: client-facing, trust boundary riêng. BCERP-WEB chỉ cấp phát tài khoản portal và publish read-model.
- **SYS-MOBILE-INTERNAL**: app nhân viên — tái sử dụng cùng API domain của hệ thống này, không nhân bản logic.

58 feature touchpoints của hệ thống có chứa RBAC/DHUB/STGW/CPORT/TIKTOK — đó là **giao diện tiêu thụ** (xem dashboard, truy xuất audit, thấy trạng thái kết nối GW, cấp tài khoản portal Day 14, xem alert TikTok Shop), canonical design thuộc system owner.

**Giả định kiến trúc:** web SPA + BFF + domain services gói trong **một modular monolith**; biên giới module là code boundary + event contract, không phải network hop ngày 1.

## 2. Components & trách nhiệm

| component_id | Tên | Module coverage | Trách nhiệm chính | Dependencies |
|---|---|---|---|---|
| COMP-ERP-001 | Sales & Pipeline Service | MOD-CRM-PIPELINE, MOD-QUOTATION-DEALDESK, MOD-HANDOFF-ONBOARD | Lead đa kênh + anti-duplicate + hard gate "không ghi nhận = không tồn tại"; scoring K1–K12 → Tier A–E (A<1.5 AUTO LOST, E≥3.5 bypass); Gate 1/2 Go-No-Go; quotation + chiết khấu phân cấp + duyệt GM; HD/LOI/NDA + brand safety + e-sign; Handoff Package ký 2 phía, sinh onboarding tasks Day 1/7/14/30 | COMP-ERP-002/003/006/007, SYS-CORE-BACKEND |
| COMP-ERP-002 | Finance & Treasury Service | MOD-WALLET-RECON, MOD-ARAP-PAYMENT, MOD-COMMISSION-QUOTA | Sổ phụ ví per-khách multi-currency (USD/VND không gộp), lệnh tiền giữ hộ, snapshot fee %; đối trừ 3 số, chốt & khóa kỳ; dual approval điều chỉnh/đổi tỷ giá/hoàn tiền; AML T1–T6; Financial Hard Stop "đã khớp tiền" FIN_L1; cảnh báo đủ chi ≥3 ngày + SLA đỏ 2h; AR/AP aging + dunning; lệnh chi ngưỡng 5/50/200 triệu + SoD 4 vai + delegate; HĐĐT TT78/NĐ123; VAS qua GW (DI-004); commission theo thực nhận + clawback | COMP-ERP-001/003/006/007, SYS-CORE-BACKEND, SYS-INTEGRATION-GW |
| COMP-ERP-003 | Ad Account & Delivery Service | MOD-ADACCOUNT-CC, MOD-PROPOSAL-PLANNING, MOD-CAMPAIGN-DELIVERABLE | TKQC registry 2.600+ (kyc_required → … → active → suspended/closed; die account; thu hồi 24h; hard stop trước active); proposal stage-gate V6.0 30 stage machine-checkable; campaign/deliverable WBS + A/B testing; nghiệm thu 3 ngày (nhắc ngày 2, escalate ngày 4, không "im lặng = đồng ý") | COMP-ERP-001/002/005/006/007, SYS-INTEGRATION-GW, SYS-CORE-BACKEND |
| COMP-ERP-004 | Client Care Service | MOD-TICKET-CSKH | Ticket open → assigned → in_progress → resolved → closed; queue OPS_CONT; escalation AM → AD → BOD; SLA tier×priority GMT+7; nhận ticket từ portal | COMP-ERP-001/003/006, SYS-PORTAL-WEB, SYS-CORE-BACKEND |
| COMP-ERP-005 | People & Performance Service | MOD-HR-CORE, MOD-CAPACITY-TIMESHEET, MOD-KPI-PERFORMANCE | Hồ sơ L1–L5 + mã vai (SSOT); HĐLĐ 90/60/30; chấm công; nghỉ phép duyệt phân cấp; ESS; rate card version hóa + thẩm định FIN; PII lương field-level security; timesheet OPS ∥ HR duyệt song song; capacity vàng 90%/đỏ 100%; KPI 3 trụ cột + calibration; PIP 30-60-90 | SYS-CORE-BACKEND, COMP-ERP-002/003/006/007 |
| COMP-ERP-006 | SLA & Notification Worker (worker) | MOD-SLA-NOTIF | SLA ma trận tier×priority GMT+7; timer mọi object có SLA; escalation tự động; Critical on-call 4h ngoài giờ (DI-005); dispatch đa kênh, idempotent + retry | COMP-ERP-001…005, SYS-CORE-BACKEND |
| COMP-ERP-007 | Batch & Reconciliation Scheduler (scheduler) | WALLET, ARAP, HR-CORE, KPI, COMM, CAPTS, CRM (jobs) | Đối trừ 3 số định kỳ; **sweep re-validate hard stop tại nguồn**; aging + dunning; chốt/khóa kỳ; clawback sweep; HĐLĐ expiry; KPI auto-aggregate; rà soát tier quý; capacity compute; checkpoint handoff | COMP-ERP-001/002/003/005/006, SYS-INTEGRATION-GW |

## 3. Business layer tóm tắt: vòng đời object chính + actor matrix

**Vòng đời (chuẩn hóa theo baseline §2):**
- **Lead** (CRM): new → dedup_check → assigned → scored (K1–K12, Tier A–E) → gate1_go/no_go → qualified → gate2_signed_handoff → handed_to_cs; rejected/recycled. SALES_L1 ghi nhận (hard gate), SALES_L2/L3 duyệt gate, reassign bởi SALES_L2+.
- **Quotation/Deal** (QDD): draft → margin_check → discount_approval phân cấp (vượt định mức → GM) → approved → contracting (e-sign) → signed/rejected.
- **Handoff** (HONB): draft → sales_submit → ops_ack (ký 2 phía) → onboarding_tasks → completed. Sinh việc cho ADACC/PORTAL/CAMP.
- **TKQC** (ADACC): kyc_required → kyc_verified → registered → pre_spend_hardstop_check → active → suspended/closed. OPS_AM registry; **hard stop tài chính FIN_L1 bắt buộc** trước active.
- **Ví & Lệnh tiền** (WALLET): entry → reconciling (đối trừ 3 số) → matched/mismatch → period_locked; lệnh: draft → dual_approval (FIN_L1+L2) → executed.
- **AR/AP** (ARAP): invoice → aging_bucket → dunning → paid/overdue; lệnh chi: draft → duyệt ngưỡng 5/50/200tr (L1→CFO→CEO + delegate) → SoD 4 vai → disbursed; HĐĐT draft → issued → delivered.
- **Campaign/Deliverable** (CAMP): planned → in_flight → delivered → reported; A/B variant [NEEDS_REVIEW: state chi tiết].
- **Timesheet** (CAPTS): draft → submitted → reviewed (OPS ∥ HR) → approved → capacity_computed.
- **Nghỉ phép / HĐLĐ** (HR-CORE): requested → balance_check → approval L1→L2; active → expiring 90/60/30 → renewed.
- **KPI/PIP** (KPI): auto_aggregate → calibration → finalized; PIP triggered → 30-60-90 → closed.
- **Ticket** (CSKH): open → assigned → in_progress → resolved → closed.
- **Commission** (COMM): computed (theo thực nhận) → clawback_check → approved → paid.

**Actor matrix rút gọn (đúng baseline §1):**

| Vai | Thao tác chính trên hệ thống này |
|---|---|
| BOD_CEO | Xem P&L/BI (từ DATAHUB); duyệt vượt ngưỡng escalation cuối; duyệt chính sách/tier; alert center |
| BOD_CFO_CTO | Duyệt tài chính độc quyền (chi/giải ngân, hóa đơn); dual approval điều chỉnh ví; phê duyệt chính sách |
| SYS_ADMIN | Vận hành cấu hình; quarterly access review (RBAC thuộc CORE) |
| FIN_L1/L2 | Sổ phụ ví, lệnh tiền, đối trừ 3 số, hard stop "đã khớp tiền", AR/AP + HĐĐT, dunning, duyệt chi theo ngưỡng |
| SALES_L1/L2/L3 | Lead + gate + tier; quotation/chiết khấu; e-sign; submit handoff; commission theo thực nhận |
| OPS_PLAN/AM/CONT | Proposal stage-gate; campaign/deliverable; TKQC registry + hard stop điểm chặn; timesheet duyệt; handoff nhận; ticket; portal account cấp phát |
| HR_L1/L2 | Hồ sơ, HĐLĐ, nghỉ phép phân cấp, rate card, KPI calibration, PIP |
| Nhân viên (ESS) | Chấm công, nghỉ phép, timesheet (chủ yếu qua MOBILE-INTERNAL, cùng API) |
| Khách hàng | Không vào hệ thống này — chỉ tương tác qua SYS-PORTAL-WEB |

## 4. Data ownership

**Sở hữu canonical (SSOT):** Lead/tier/gate; quotation/contract/e-sign record; handoff package; TKQC registry + KYC state; ví ledger + lệnh tiền + kết quả đối trừ + period lock; AR/AP/HĐĐT; commission/quota; proposal stage; campaign/deliverable/A-B; timesheet/capacity; hồ sơ HR/HĐLĐ/chấm công/nghỉ phép/rate card; KPI/PIP; ticket; SLA policy instance + notification log.

**Đọc từ system khác:**
- Từ **SYS-CORE-BACKEND**: user/role/permission/mã vai (RBAC 18 vai), chính sách + tham số ngưỡng đã duyệt (REQ-BOD-009), audit WORM storage, published BI metrics + alert feed (DATAHUB là nơi tổng hợp; BCERP-WEB render dashboard).
- Từ **SYS-INTEGRATION-GW**: số dư/spend TKQC per platform (đối trừ 3 số), trạng thái account ngoại vi (die account), health + degraded mode flag, export VAS, TikTok Shop GMV (tách GMV shop vs NSQC ads), sao kê ngân hàng [NEEDS_REVIEW: connector nguồn chưa xác định trong registry].
- **Ghi sang SYS-PORTAL-WEB**: lệnh cấp/thu hồi tài khoản portal (Day 14), publish read-model ví read-only + invoice + campaign status qua contract API — portal chỉ đọc.

**PII lương:** HR-CORE sở hữu dữ liệu, enforcement Confidential/Restricted bằng field-level security của RBAC (CORE); ETL sang DATAHUB phải tôn trọng masking.

## 5. Giao tiếp

**Sync REST:**
- → **CORE-BACKEND**: verify token/SSO/MFA + role per request; đọc tham số duyệt (ngưỡng 5/50/200, ma trận tier, SLA policy); ghi audit trail tiền (WORM).
- → **INTEGRATION-GW**: truy vấn số dư/spend/external account status phục vụ đối trừ + vòng đời TKQC; kiểm tra degraded mode trước khi hiển thị "số liệu sync" vs "nhập manual".
- BFF nội bộ cho web SPA: aggregation per màn hình, không expose domain service trực tiếp ra browser.

**Async events (outbox pattern, consumer idempotent):**

| Event | Phát từ | Nhận bởi | Hiệu ứng |
|---|---|---|---|
| ví.matched | COMP-ERP-002 | COMP-ERP-003 | Mở hard stop, cho phép TKQC pre_spend_check → active |
| wallet.low_balance | COMP-ERP-002 | COMP-ERP-006 | SLA đỏ 2h → escalation ops theo ma trận |
| recon.mismatch | COMP-ERP-002 | COMP-ERP-006 | Chặn đối soát; điều chỉnh cần dual approval |
| handoff.ops_ack | COMP-ERP-001 | COMP-ERP-003 + PORTAL | Sinh onboarding tasks: cấp TKQC (sau hard stop), cấp portal account, tạo campaign |
| deal.signed | COMP-ERP-001 | COMP-ERP-002 | Mở AR invoice schedule + handoff draft |
| payment.received / refund.executed | COMP-ERP-002 | COMP-ERP-002 (COMM) | Commission computed theo thực nhận / clawback_check |
| invoice.issued | COMP-ERP-002 | SLANOT, PORTAL | Delivered HĐĐT + notify |
| timesheet.approved | COMP-ERP-005 | KPI + DATAHUB (qua event bus) | Giờ duyệt mới vào P&L + KPI 3 trụ cột |
| kpi.below_threshold | COMP-ERP-005 | HR | Trigger PIP 30-60-90 |
| sla.breach / sla.warning | COMP-ERP-006 | Module owner + escalation path | Notify + escalate (ticket AM→AD→BOD) |
| deliverable.acceptance_due | COMP-ERP-003 | COMP-ERP-006 | Nhắc ngày 2, escalate AD ngày 4 |

## 6. Quy ước kỹ thuật đề xuất cho system này

(Cross-cutting platform-level để mức platform; đây là điểm riêng.)
- **API:** REST resource per object; state transition là endpoint tường minh (`POST /{object}/{id}/transitions`) với guard role+state machine; list server-side (search/filter/sort, page size mặc định 20, tối đa 100); bulk cho import lead, gán deliverable, khóa kỳ; activity/audit timeline endpoint cho mọi object.
- **DB:** status + state machine versioned (JSON definition dùng chung); owner/assignee + `assignment_history` cho multi-stage handoff (lead, handoff, ticket); created_by/updated_by + timestamps; audit log append-only; index theo cột lọc phổ biến (owner+status, customer_id, period, due_date, tier).
- **Tiền:** DECIMAL per-currency, không quy đổi gộp USD/VND; snapshot fee % tại thời điểm giao dịch; ghi sổ ví double-entry; Idempotency-Key cho mọi money command.
- **Approval engine** (ngưỡng, dual, SoD 4 vai, delegate, cấm cùng người duyệt 2 chân khi kiêm nhiệm) là thư viện dùng chung trong monolith — không phải module mới.
- **AuthN/AuthZ + notification channel hạ tầng + object storage chứng từ:** cross-cutting, dùng nền tảng chung (CORE RBAC, storage platform); MOD-SLA-NOTIF chỉ sở hữu SLA policy + timer + escalation + notification log nghiệp vụ.
- **Event:** outbox + dead-letter; scheduler dùng distributed lock (Redis); timezone GMT+7 cho mọi SLA.

## 7. Rủi ro & trade-offs + NEEDS_REVIEW

**Rủi ro & trade-offs:**
1. **Ví tiền giữ hộ** là rủi ro compliance cao nhất: dual approval + WORM + khóa kỳ làm chậm vận hành — chấp nhận chậm để đổi kiểm soát nội bộ (nguyên tắc nền tảng: chất lượng > tốc độ).
2. **Event loss giữa WALLET → ADACC** làm lộ hard stop: COMP-ERP-007 sweep re-validate "đã khớp tiền" tại nguồn trước mọi active; event chỉ là tối ưu, không phải nguồn truth.
3. **Kiêm nhiệm CFO=CTO**: compensating control phải enforce trong approval engine (cùng người không tự duyệt 2 chân) + quarterly access review từ CORE.
4. **Modular monolith**: risk vi phạm boundary khi dev nhanh — mitigated bằng enforce tool + event contract; nếu sau này tách service, seam đã có sẵn.
5. **2.600 TKQC sync qua GW**: rate limit + degraded mode — UI phải đánh dấu rõ dữ liệu manual (exception §5 baseline).
6. **PII lương chung DB với BI ETL**: rủi ro leak qua DATAHUB — bắt buộc masking trước ingest.

**[NEEDS_REVIEW]:**
1. Proposal stage-gate V6.0: tên + done-criteria 30 stage — cần đọc spec `proposal-va-planning-workspace-stage-gate-v6-0.md` (baseline đã flag).
2. Nguồn feed sao kê ngân hàng cho đối trừ 3 số (portal vs bank vs ledger) — chưa thấy connector nào trong registry.
3. Kênh notification ngoài in-app (email/SMS/OTT) cho SLA-NOTIF — registry không chỉ định.
4. e-sign provider cho REQ-SALES-007 — provider và đường dẫn (trực tiếp hay qua GW) chưa chốt.
5. State chi tiết variant A/B của Campaign — baseline để mở.
6. Contract API publish read-model sang SYS-PORTAL-WEB (ví read-only, invoice, campaign status) — cần thống nhất ở bước tích hợp platform.
7. Công thức chính xác "quota coverage ≥3×" (tử số/mẫu số) — brief nêu ngưỡng nhưng không thấy định nghĩa.
