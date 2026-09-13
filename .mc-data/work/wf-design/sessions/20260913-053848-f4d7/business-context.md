# Business Context Baseline — BCERP (Phase 1 Step 1.0, v4.1)

> Session 20260913-053848-f4d7 | Nguồn: req-registry.json (5 DEPT, 19 MOD, 59 REQ, 170 FEAT touchpoints) + feature-briefs.json.
> Scope guard CORE-006: chỉ dùng roles/states/modules có trong registry + features. Chỗ thiếu → [NEEDS_REVIEW].
> Lưu ý cấu trúc: 170 FEAT registry là **touchpoint per system** của cùng logic feature (VD FEAT-CORE-ARAP-004 = FEAT-ERP-ARAP-002 = "Duyệt chi/giải ngân") — module là owner canonical.

---

## §1. Actor & Role Matrix (role × module × hành động)

| Vai | Phòng ban | Systems chính | Module dùng | Hành động chính |
|-----|-----------|---------------|-------------|-----------------|
| BOD_CEO | DEPT-BOD | CORE-BACKEND, BCERP-WEB, MOBILE-INTERNAL | DATAHUB-BI, ARAP, RBAC | Xem P&L realtime + BI dashboard; duyệt phê vượt ngưỡng (escalation cuối); duyệt chính sách/tier; giám sát audit; alert center |
| BOD_CFO_CTO (kiêm nhiệm, compensating control) | DEPT-BOD | CORE-BACKEND, BCERP-WEB, INTEGRATION-GW | ARAP, WALLET, STGW, RBAC, DATAHUB | Duyệt tài chính độc quyền (chi/giải ngân, hóa đơn); quản trị Integration Gateway + credentials vault; phê duyệt chính sách, tham số quản trị; dual approval điều chỉnh ví |
| SYS_ADMIN | DEPT-BOD | CORE-BACKEND, BCERP-WEB | RBAC, STGW | Quản trị RBAC/SSO/MFA; quarterly access review; cấu hình kết nối (Settings, vendor-agnostic DI-004) |
| HR_L1 / HR_L2 | DEPT-HR | BCERP-WEB, MOBILE-INTERNAL | HR-CORE, KPI, CAPTS, RBAC | Hồ sơ L1–L5; HĐLĐ; chấm công; duyệt nghỉ phép phân cấp; cost rate card (thẩm định cùng FIN); KPI + calibration; PIP 30-60-90; bảo vệ PII lương (Confidential/Restricted) |
| FIN_L1 / FIN_L2 | DEPT-FINANCE | BCERP-WEB, MOBILE-INTERNAL | WALLET, ARAP, ADACC, RBAC, DATAHUB | Sổ phụ ví + lệnh giao dịch tiền giữ hộ; đối trừ 3 số; dual approval điều chỉnh; **Financial Hard Stop "đã khớp tiền" (FIN_L1)**; AR/AP aging + nhắc nợ; duyệt chi SoD 4 vai (ngưỡng 5/50/200 triệu + delegate); hóa đơn điện tử TT78/NĐ123; AML T1–T6 |
| SALES_L1 / L2 / L3 | DEPT-SALES | BCERP-WEB | CRM, QDD, HONB, COMM | Thu nhận lead đa kênh; hard gate "không ghi nhận = không tồn tại"; scoring K1–K12 → Tier A–E; Gate 1/Gate 2 Go-No-Go + ký handoff; quotation + chiết khấu phân cấp (vượt định mức → duyệt GM); hợp đồng/LOI/NDA + e-sign; commission theo thực nhận |
| OPS_PLAN / OPS_AM / OPS_CONT | DEPT-OPS | BCERP-WEB, MOBILE-INTERNAL | PROPLN, CAMP, CAPTS, HONB, ADACC, SLANOT, CSKH, TIKTOK, PORTAL, WALLET | Proposal stage-gate V6.0; campaign + deliverable + A/B testing; capacity/timesheet (duyệt phối hợp HR); nhận handoff + onboarding; registry + vòng đời TKQC (cần hard stop FIN); SLA engine; ticket CSKH; TikTok Shop monitoring; cấp tài khoản client portal; ví góc ops (cảnh báo + escalation) |
| Nhân viên (ESS) | mọi phòng | MOBILE-INTERNAL | HR-CORE, CAPTS | Chấm công; xin nghỉ phép; nhập timesheet; xem thông tin cá nhân |
| Khách hàng (external client) | — | PORTAL-WEB, MOBILE-PORTAL | CLIENT-PORTAL | Xem số dư ví read-only; ticket CSKH; theo dõi campaign/deliverable; nhận invoice |

---

## §2. Business Object Lifecycle (object × state × owner)

> States suy ra từ REQ/FEAT titles + briefs; state không ghi rõ trong nguồn → [NEEDS_REVIEW: đọc feature spec gốc].

| Object (module owner) | States (chuẩn hóa đề xuất) | Transitions chính — ai đổi |
|-----------------------|----------------------------|---------------------------|
| **Lead** (CRM) | new → dedup_check → assigned → scored(K1–K12, Tier A–E) → gate1_go / gate1_no_go → qualified → gate2_signed_handoff → handed_to_cs; rejected; recycled | SALES_L1 thu nhận + ghi nhận (hard gate "không ghi nhận = không tồn tại"); scoring tự động; Gate 1/2 Go-No-Go do SALES_L2/L3; chuyển tier Sales→CS cuối vòng đời; rà soát quý |
| **Quotation/Deal** (QDD) | draft → margin_check(định mức) → discount_approval_phân_cấp (vượt định mức → GM) → approved → contracting(LOI/NDA/HD + brand safety + e-sign) → signed / rejected | SALES soạn; duyệt chiết khấu phân cấp theo ma trận; GM duyệt vượt định mức; e-sign hoàn tất |
| **Handoff Package** (HONB) | draft → sales_submit → ops_ack (ký nhận bridge) → onboarding_tasks → completed | SALES submit; OPS_AM nhận + ký; onboarding tasks sinh cho ADACC (cấp TKQC), PORTAL (tài khoản client), CAMP |
| **Proposal/Plan** (PROPLN) | stage-gate V6.0 — [NEEDS_REVIEW: tên gates đọc spec proposal-va-planning-workspace-stage-gate-v6-0.md] | OPS_PLAN soạn; duyệt theo stage-gate |
| **Campaign / Deliverable** (CAMP) | planned → in_flight → delivered → reported; variant A/B [NEEDS_REVIEW: state chi tiết] | OPS_AM lập; OPS_CONT thực hiện deliverable; báo cáo theo mục tiêu khách |
| **TKQC Ad Account** (ADACC) | kyc_required → kyc_verified → registered → pre_spend_hardstop_check → active → suspended / closed | OPS registry + vòng đời; KYC pháp nhân trước cấp phát (REQ-FIN-009); **chặn cấp phát nếu chưa "đã khớp tiền"** (hard stop FIN_L1) |
| **Ví TKQC & Lệnh tiền** (WALLET) | Sổ phụ: entry(sync/API) → reconciling(đối trừ 3 số: portal vs bank vs ledger) → matched / mismatch → period_locked; Lệnh: draft → dual_approval(FIN_L1+L2) → executed; Đ.gtỷ giá/hoàn tiền dual approval | FIN sở hữu; sync từ STGW (7 nền tảng); chốt & khóa kỳ; cảnh báo số dư đủ chi ≥3 ngày, SLA đỏ 2h; AML T1–T6 hoàn tiền đúng nguồn |
| **AR/AP & Lệnh chi** (ARAP) | AR: invoice → aging_bucket → dunning(nhắc nợ) → paid / overdue; AP/Chi: draft → theo ngưỡng 5/50/200tr (L1 → CFO → CEO escalation + delegate) → SoD 4 vai approved → disbursed; HĐĐT: draft → issued(TT78/NĐ123) → delivered | FIN_L1 khởi tạo; duyệt theo ngưỡng + SoD; CFO độc quyền tài chính (REQ-BOD-010); tích hợp VAS kế toán qua Settings (DI-004) |
| **Timesheet/Capacity** (CAPTS) | draft(nhân viên nhập) → submitted → reviewed(OPS ∥ HR) → approved → capacity_computed | Nhân viên nhập (ESS/mobile); OPS_AM + HR duyệt; feed KPI + COMM |
| **Nghỉ phép** (HR-CORE) | requested → balance_check(số dư tự động) → approval_phân_cấp(L1→L2) → approved / rejected | Nhân viên; HR_L1/L2 duyệt phân cấp |
| **Hồ sơ & HĐLĐ** (HR-CORE) | active → expiring(90/60/30 cảnh báo) → renewed / expired; hồ sơ L1–L5 + mã vai | HR quản; cảnh báo tự động |
| **KPI / PIP** (KPI) | auto_aggregate(3 trụ cột) → calibration → finalized; PIP: triggered → 30-60-90 checkpoints → closed | Tự tổng hợp từ CAPTS/COMM/CRM; HR_L2 + quản lý calibration |
| **Ticket CSKH** (CSKH) | open → assigned → in_progress → resolved → closed | OPS_CONT xử lý; SLA timer từ SLANOT; tier khách ảnh hưởng SLA |
| **Commission/Quota** (COMM) | computed(theo thực nhận) → clawback_check → approved → paid | Tự tính từ ARAP (tiền đã thu) + QDD; clawback khi hoàn tiền/hủy |
| **Integration Connection** (STGW) | configured → credentials_vaulted (nạp credential — API-GW-009) → active → degraded(manual mode) / disabled / revoked | CTO (BOD_CFO_CTO) + SYS_ADMIN quản trị; vendor-agnostic qua Settings (DI-004); 7 nền tảng: Meta, Google, TikTok, Bing, X, Pinterest, Yandex |
| **TikTok Shop** (TIKTOK) | connected → monitoring → alert(ra anomaly) | OPS theo dõi; tự động từ API |
| **P&L / BI** (DATAHUB) | ingest(ETL từ mọi module) → reconcile → publish(realtime dashboard) → alert | Tự động; BOD + FIN tiêu thụ |

---

## §3. Cross-Module Dependency Map (object → module cung cấp → dữ liệu)

| Object tiêu thụ | Module cung cấp | Loại dữ liệu / trạng thái |
|-----------------|-----------------|---------------------------|
| TKQC cấp phát (ADACC) | WALLET (FIN hard stop) | Trạng thái "đã khớp tiền" — bắt buộc trước khi active |
| Lệnh giải ngân (ARAP) | WALLET, QDD | Số dư ví khả dụng; giá trị hợp đồng đã ký |
| Commission (COMM) | ARAP, QDD, CRM | Thực nhận (đã thu tiền); deal value; tier nhân viên |
| KPI (KPI) | CAPTS, COMM, CRM | Timesheet duyệt; doanh số; pipeline kết quả |
| Handoff (HONB) | QDD, CRM | Hợp đồng signed; tier khách; scope cam kết |
| Campaign (CAMP) | HONB, ADACC, CAPTS | Khách onboarded; TKQC active; nhân sự phân bổ |
| Ticket (CSKH) | CRM, SLANOT, CAMP | Tier khách (SLA theo tier); hạn mức SLA; context campaign |
| Client Portal (PORTAL) | WALLET, CAMP, CSKH, ARAP | Số dư ví read-only; trạng thái campaign; ticket; invoice |
| DATAHUB-BI (ETL) | TẤT CẢ modules | Sự kiện tài chính/vận hành phục vụ P&L realtime + alert center |
| SLANOT | mọi module có SLA | Hạn mức SLA + timer; điều phối notification đa kênh |
| HR-CORE | RBAC | PII lương Confidential/Restricted — field-level security |
| STGW | — (nền cho mọi integration) | Connector 7 nền tảng + VAS kế toán; degraded mode manual |

---

## §4. Ownership & Assignment Rules

| Stage/Object | Owner | Approver | Reassign/escalation |
|--------------|-------|----------|---------------------|
| Lead | SALES_L1 (phân bổ theo rule) | SALES_L2/L3 (Gate 1/2) | Reassign bởi SALES_L2+; rà soát tier quý |
| Deal/Quotation | SALES (AM sở hữu) | Chiết khấu phân cấp; GM (vượt định mức); e-sign | — |
| Handoff | SALES (submit) → OPS_AM (nhận) | Ký nhận 2 phía (bridge) | — |
| Campaign/Deliverable | OPS_AM (campaign), OPS_CONT (deliverable) | OPS_PLAN (stage-gate proposal) | — |
| Ví & đối soát | FIN_L1 | Dual approval FIN_L1+FIN_L2 (điều chỉnh/đ.gtỷ giá/hoàn tiền); chốt kỳ FIN_L2 | Cảnh báo → escalation ops theo ma trận (SLA đỏ 2h) |
| Chi/giải ngân | FIN_L1 (khởi tạo) | Ngưỡng 5/50/200 triệu: FIN_L2 → CFO → CEO; SoD 4 vai; delegate khi vắng | Escalation timeout → cấp trên |
| TKQC | OPS_AM (registry) | Hard stop tài chính FIN_L1 (bắt buộc) | — |
| Timesheet | Nhân viên (nhập) | OPS ∥ HR duyệt | — |
| Nghỉ phép | Nhân viên | HR phân cấp L1→L2 | — |
| KPI/PIP | HR_L2 | Ban điều hành (calibration) | — |
| Ticket | OPS_CONT (queue) | Escalate khi SLA vỡ | SLANOT tự escalation |
| Integration/Settings | SYS_ADMIN (vận hành) | CTO/BOD_CFO_CTO (phê duyệt thay đổi credentials/chính sách) | Quarterly access review |

---

## §5. Exception Events (exception × object × mức)

| Exception | Object | Mức / hành vi |
|-----------|--------|----------------|
| Số dư ví < đủ chi ≥3 ngày | WALLET | Cảnh báo vàng; SLA đỏ 2h → escalation |
| Mismatch đối trừ 3 số | WALLET | Chặn đối soát; điều chỉnh cần dual approval |
| AML flag T1–T6 | WALLET | Chờ hoàn tiền đúng nguồn; điều tra |
| Chưa "đã khớp tiền" | ADACC/TKQC | **Hard stop** chặn cấp phát TKQC |
| Aging vượt hạn | AR/AP | Nhắc nợ tự động; escalation theo bucket |
| Vượt ngưỡng chi | Lệnh chi | Phân nhánh duyệt lên CFO/CEO; thiếu báo giá → chặn |
| HĐLĐ hết hạn 90/60/30 ngày | HR | Cảnh báo HR_L1/L2 |
| SLA sắp vỡ / đã vỡ | mọi object có SLA | Notification + escalation tự động (SLANOT) |
| API nền tảng fail | STGW | **Degraded mode**: chuyển nhập manual, đánh dấu dữ liệu thủ công |
| Lead trùng lặp | CRM | Anti-duplicate: merge/từ chối |
| Khách hoàn tiền / hủy | COMM | Clawback hoa hồng |
| KPI dưới chuẩn liên tục | KPI | Trigger PIP 30-60-90 |
| Deliverable overdue | CAMP | Cảnh báo OPS_AM; SLA nhắc |
| Anomaly TikTok Shop | TIKTOK | Alert center (DATAHUB) |

---

## §6. Module Consolidation Review (19 modules)

| Module | Phòng ban sở hữu | Business objects | Lý do tồn tại riêng | Đánh giá gộp |
|--------|------------------|------------------|---------------------|--------------|
| MOD-RBAC-AUDIT | BOD (cross-cutting) | User/Role/Permission, Audit, Policy | Cross-cutting toàn platform; WORM 10 năm | GIỮ |
| MOD-DATAHUB-BI | BOD + FIN | P&L, Dashboard, Alert | ETL riêng, realtime pipeline | GIỮ |
| MOD-SETTINGS-GW | BOD (CTO) | Connection, Credential vault | Config lifecycle ≠ business objects; vendor-agnostic DI-004 | GIỮ |
| MOD-TIKTOK-SHOP | OPS | Shop monitor, Alert | Integration nền tảng chuyên biệt, lifecycle pull-based | GIỮ |
| MOD-HR-CORE | HR | Hồ sơ, HĐLĐ, Chấm công, Nghỉ phép, ESS, Rate card | PII boundary riêng | GIỮ |
| MOD-KPI-PERFORMANCE | HR | KPI, PIP | Vòng đời năm/quý + calibration ≠ CRUD nhân sự (1/3 tiêu chí) | GIỮ |
| MOD-CAPACITY-TIMESHEET | OPS ∥ HR | Timesheet, Capacity | Duyệt song song 2 phòng | GIỮ |
| MOD-CRM-PIPELINE | SALES | Lead, Tier, Gate | Vòng đời riêng V6.0 | GIỮ |
| MOD-QUOTATION-DEALDESK | SALES | Quotation, Contract | Deal desk + e-sign | GIỮ |
| MOD-HANDOFF-ONBOARD | SALES→OPS bridge | Handoff package | Bridge 2 phòng, ký nhận 2 phía | GIỮ |
| MOD-ADACCOUNT-CC | OPS | TKQC registry | Vòng đời TKQC + hard stop tài chính | GIỮ |
| MOD-WALLET-RECON | FIN | Ví, Lệnh tiền, Đối soát | Tiền giữ hộ — kiểm soát nội bộ chặt nhất | GIỮ |
| MOD-ARAP-PAYMENT | FIN | AR, AP, HĐĐT | Vòng đời hóa đơn + giải ngân | GIỮ |
| MOD-COMMISSION-QUOTA | SALES | Commission, Quota | Tính toán theo thực nhận | GIỮ |
| MOD-PROPOSAL-PLANNING | OPS | Proposal, Plan | Stage-gate V6.0 riêng | GIỮ |
| MOD-CAMPAIGN-DELIVERABLE | OPS | Campaign, Deliverable, A/B | Core vận hành | GIỮ |
| MOD-SLA-NOTIF | OPS (cross-cutting) | SLA policy, Notification | Engine phục vụ đa module | GIỮ |
| MOD-TICKET-CSKH | OPS | Ticket | Vòng đời CSKH riêng | GIỮ |
| MOD-CLIENT-PORTAL | OPS ∥ FIN (data) | Portal account, View | Bên ngoài client-facing, trust boundary riêng | GIỮ |

**Kết luận:** Không có ứng viên gộp thỏa ≥2/3 tiêu chí (cùng phòng ban sở hữu + cùng nhóm lifecycle + schema chia sẻ tự nhiên). Cấu trúc 19 module khớp quyết định đã duyệt 12/09 (gộp FIN 1 module; 5 module khởi điểm + 2 lớp) → **không flag [NEEDS_REVIEW: propose-merge] mới**.

---

## Ghi chú cho agent (Business Context Injection)

- Mọi API/DB/integration phải trace được: *ai* — *object* — *stage vòng đời* — *cần gì từ module khác* — *hành động gì*.
- API phải cover: state transition endpoints, assign/reassign, list server-side (search/filter/sort/pagination, limit mặc định 20 max 100), bulk nếu cần, activity/audit cho object có timeline.
- DB phải có: status + state machine, owner/assignee, created_by/updated_by + timestamps, assignment history (nếu multi-stage handoff), audit/activity log, index cho cột lọc hay dùng.
- Module bị flag merge (không có trong baseline này) → thiết kế theo registry hiện tại, KHÔNG tự gộp.
- Thiếu/sai thông tin → ghi [NEEDS_REVIEW], KHÔNG bịa state/role/module mới ngoài registry.
