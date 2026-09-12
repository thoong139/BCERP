# Tính Năng: Proposal & Planning Workspace (Stage-Gate V6.0)

> **Dựa trên:** REQ-OPS-005 trong `phase1-business/departments/operations/operations.md` (Mục REQ-OPS-005 + Phần B.6)
> **Phân hệ:** Vận hành & Marketing nội bộ (SYS-CORE-BACKEND)
> **Module:** MOD-PROPOSAL-PLANNING
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md` (A + B.6), `P1-02-business-workflow.md` (Luồng 3), `documents/quy-trinh-lam-viec/` file 01/03/04/08/09/10 (v1.1)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/SYS-CORE-BACKEND/MOD-PROPOSAL-PLANNING/[screen-group].md`, `phase5-implementation/tasks/.../FEAT-CORE-PROPLN-001-impl.md`
>
> **ID:** REQ-OPS-005 fan-out 3 hệ thống — bản riêng cho SYS-CORE-BACKEND: gate engine, đếm vòng sửa, hard block tầng API, audit log bất biến, tenant isolation là nguồn sự thật; counterparts: SYS-BCERP-WEB (workspace + checklist), SYS-MOBILE-INTERNAL (duyệt concept, nhận escalate).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-CORE-PROPLN-001 |
| Module | MOD-PROPOSAL-PLANNING |
| Yêu cầu nghiệp vụ | REQ-OPS-005 (Proposal & Planning Workspace — Stage-Gate V6.0) |
| Người dùng liên quan | OPS_PLAN (chính), OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; phối hợp: SALES_L4 (SM ký gate), SALES_L5 (GDKD duyệt GM), FIN_L1 (Accountant tính giá), BOD_CEO (escalation cuối), SYS_ADMIN (cấu hình) |
| Độ ưu tiên | Cao (HIGH) |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | Cross-dependencies: không có (theo lane). Nội hệ: đọc `qualifiedTier` đã khóa + e-approval engine từ lane CRM-PIPELINE (REQ-SALES-004); WBS chi tiết/editorial calendar thuộc REQ-OPS-006 (lane CAMPAIGN-DELIVERABLE — feature này chỉ sinh khung WBS sơ bộ sau WON) |
| Ghi chú Expert (A7) | `operations.md` Mục A7 hiện chờ Expert Review — chưa có điều chỉnh nội dung nào tại thời điểm lập spec (12/09/2026); business rules Phần B.6 do marketing-expert viết giữ nguyên làm căn cứ |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Xây dựng trên Core Backend workspace engine cho chu trình đánh giá — đề xuất — hoạch định của Stage-Gate V6.0: gate engine chấm done-criteria machine-checkable trên vòng đời 30 stage, quản lý proposal theo tier (template, số trang, vòng sửa), vận hành e-approval nội bộ (duyệt GM, thẩm định borderline, exception vòng sửa) và tự sinh dự án + khung WBS sơ bộ tại WON. Toàn bộ ràng buộc được enforce ở tầng service (headless API) — hard block chuyển stage khi thiếu done criteria, chặn cả UI lẫn API — theo nguyên tắc "Không ghi nhận vào PMS = Không tồn tại".

**Phạm vi:**
- Bao gồm: stage-gate engine 30 stage (done-criteria "hệ thống tự kiểm" / "thuần phán đoán con người" — bắt buộc có bản ghi); Brand Safety Hard Stop 7/7 tại EVALUATION + quyền "Từ chối vận hành"; Weighted ≥3,5 + thẩm định borderline 4h; proposal theo tier (validator số trang, đếm vòng nội bộ ≤3, vòng sửa khách B/C ≤2 / D/E ≤4); e-approval GDKD duyệt GM trước gửi khách; rehearsal record; quotation gắn proposal đã duyệt; WON tự sinh dự án Client Billable + khung WBS; done-criteria DEPLOY (stage-gate v1.2 bảng 2.1 — KXN-10) và quy tắc downstream: duyệt creative đa vai, change log bất biến, A/B testing; SLA gate + escalation tự động; audit log + tenant isolation. Chi tiết từng rule tại Mục 3.
- Không bao gồm: màn hình WEB/app MOBILE (counterparts — feature này chỉ cung cấp headless API); AUTO SCORING K1–K12 và xếp tier (lane CRM-PIPELINE); Handoff Package 5 nhóm (REQ-SALES-008); WBS chi tiết, editorial calendar, nghiệm thu milestone (REQ-OPS-006); SLA ticket (REQ-OPS-008/009); đối chiếu chi tiêu nền tảng (REQ-OPS-002/011 — chỉ tiêu thụ dữ liệu có nhãn nguồn).

---

## 2. Luồng Người Dùng (User Stories)

Touchpoint SYS-CORE-BACKEND: domain service headless — mọi business rule, SLA clock, đếm vòng, hard block chạy ở service layer; WEB (browser UI responsive) và MOBILE-INTERNAL (React Native offline-capable) chỉ là kênh gọi API, không phải lớp enforce. Mọi endpoint ghi audit log và scope theo tenant.

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_PLAN | Engine tự chấm done-criteria machine-checkable, chỉ mở chuyển stage khi 100% đạt | Không stage nào "nhảy bước"; phần phán đoán vẫn phải có bản ghi |
| 2 | OPS_AM | Soạn proposal từ template đúng tier (B/C — 8–12 trang), hệ thống đếm vòng và chặn khi chạm hạn | Kỷ luật vòng sửa được enforce nhất quán |
| 3 | OPS_PLAN | Proposal Weighted 3,0–3,49 tự vào hàng đợi thẩm định 4h do SM chỉ định người | Borderline không tự pass, có kết luận kèm lý do |
| 4 | OPS_AM | Nút gửi khách chỉ mở khi GDKD đã duyệt GM (e-approval SLA 1 ngày LV) | Không tồn tại trạng thái "đã gửi khách" ngoài quy trình |
| 5 | OPS_CONT | Pipeline duyệt creative đa vai có trạng thái từng bước, comment bắt buộc khi reject | Vòng sửa minh bạch, đúng SLA (AM 2h — video dài 4h — trend 1h; self-QC + Lead 4h) |
| 6 | OPS_ADS | Mọi thay đổi ngân sách/bid/target bắt buộc reason, lưu cũ/mới vào change log bất biến; chỉ declare winner A/B khi đủ sample (≥50 clicks hoặc ≥10 conversions) và chênh ≥20% | Truy vết mọi quyết định chi tiêu; kết luận dựa trên dữ liệu |
| 7 | SALES_L4 (SM) / SALES_L5 (GDKD) | Ký/duyệt qua API engine theo mã vai, người ký ≠ người đề xuất, có escalation tự động khi quá SLA | Chống xung đột lợi ích; quyết định không chồng chất |

---

## 3. Quy Tắc Nghiệp Vụ

> *Quy tắc bắt buộc — enforce ở tầng service Core Backend (không tin UI). Nguồn: `operations.md` B.6; quy-trinh-lam-viec v1.1 file 01/03/04/08/09; số liệu SLA/vòng sửa/A-B theo DI-005 đã resolve.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-OPS-6.0 | **"Không ghi nhận vào PMS = Không tồn tại" + hard block hai lớp:** trạng thái, điểm scoring, chữ ký, vòng sửa, feedback khách (kể cả qua Zalo/Email) chỉ có hiệu lực khi là bản ghi hệ thống; gate engine chặn ở tầng service, không chỉ ẩn nút WEB; MOBILE ghi offline sync qua cùng API | Chuyển stage thiếu criteria bị API từ chối kèm danh sách mục chưa đạt; bản ghi ngoài hệ thống không tạo hiệu lực |
| BR-OPS-6.1 | **Stage-gate V6.0 machine-checkable trên 30 stage / 5 giai đoạn:** mỗi stage có done-criteria phân loại "hệ thống tự kiểm" (validation, đếm checklist/SLA, kiểm e-approval) và "thuần phán đoán con người" (bắt buộc có bản ghi); hệ thống tự chuyển stage khi đủ 100%; done-criteria DEPLOY áp bộ phê chuẩn KXN-10 — stage-gate-lifecycle v1.2 bảng 2.1: D+0 cần LOI/HĐ + tiền vào TK do FIN_L1 xác nhận 4h; checklist tài nguyên trước D+4; Planning trong ngày D+0; 6 Rules ký D+3; ONGOING từ D+5 | Stage không chuyển khi thiếu criteria; auto fail giữ stage kèm lý do; bộ criteria khác v1.2 bảng 2.1 bị từ chối khi cấu hình |
| BR-OPS-6.2 | **Brand Safety Hard Stop 7/7 tại EVALUATION — rule engine all-pass chặn tầng API, fail 1 → dừng ngay, không ngoại lệ.** 7 tiêu chí: (1) SP hợp pháp + giấy phép con; (2) không vi phạm Ads Policy nền tảng; (3) không spam/leading/misleading theo Luật Quảng cáo VN; (4) quyền image/video/bản quyền hợp lệ; (5) landing page hợp pháp, khớp quảng cáo; (6) dữ liệu mục tiêu có cơ sở thu thập hợp lệ; (7) không thuộc ngành cấm/nhạy cảm chưa duyệt nội bộ. Kèm Weighted ≥3,5 (9 tiêu chí, trọng số 20/15/15/10/10/10/10/5/5). Khách đang vận hành vi phạm 1/7 → "Từ chối vận hành": xác nhận pháp lý + OPS_PLAN duyệt 24h, khóa HĐ, notify legal + ops | Không sang PROPOSAL khi 7/7 chưa pass; Weighted <3,0 → LOST chủ động; "Từ chối vận hành" quá 24h → escalate BOD_CEO; mọi pass/fail ghi audit |
| BR-OPS-6.3 | **Template & định mức proposal theo tier (KXN-1/KXN-8 — chiều V6.0):** B/C — OPS_AM soạn 8–12 trang, vòng sửa khách ≤2; D/E — OPS_PLAN chủ trì 15–25 trang, vòng sửa ≤4; Tier E Big Corp thêm Team Bios + Brand Safety; engine đọc tier từ `qualifiedTier` đã khóa — **cấm hardcode nhãn tier**; validator đếm trang; định dạng riêng → GDKD duyệt lệch định mức, ghi log | Sai định mức trang không thể chuyển trạng thái gửi khách; gán tier sai profile bị từ chối; lệch định mức không e-approval bị audit flag |
| BR-OPS-6.4 | **Đếm vòng review + escalation:** vòng chỉ ghi nhận khi reviewer chuyển "Request changes" kèm comment bắt buộc; engine đếm độc lập trên proposal và quotation — vòng nội bộ v0.x tối đa 3 (v0.1→v0.3) trong SLA 5 ngày LV, vòng sửa khách theo tier (B/C ≤2, D/E ≤4); chạm hạn → chặn tạo vòng mới, escalate SM/OPS_PLAN quyết 1 trong 3: chốt gửi bản hiện có / gia hạn có lý do (GDKD duyệt, log bất biến, tối đa 1 lần/proposal) / dừng deal | "Request changes" thiếu comment bị từ chối; vòng vượt hạn bị chặn; gia hạn lần 2 không thể duyệt; revision history append-only |
| BR-OPS-6.5 | **Duyệt nội bộ trước khi gửi khách:** GDKD duyệt GM bằng e-approval SLA 1 ngày LV, quá hạn tự escalate; chưa duyệt → không tồn tại trạng thái "đã gửi khách" (API từ chối); điều kiện kèm: rehearsal đã ghi nhận (pitch thử ≥1 lần + Q&A script + kịch bản từ chối), giá cuối GDKD xác nhận; Quotation chỉ phát hành sau Pitching, gắn proposal đã duyệt — FIN_L1 tính giá, GDKD duyệt margin; borderline 3,0–3,49 vào hàng đợi thẩm định do SM chỉ định người, SLA 4h, kết luận kèm lý do | Gửi khách thiếu duyệt GM bị từ chối; quotation không gắn proposal duyệt không phát hành; borderline hết 4h escalate GDKD; AM không tự thỏa giá ngoài khung |
| BR-OPS-6.6 | **WON — tự sinh dự án + WBS khung:** done criteria WON: HĐ/LOI ký 2 bên + cập nhật PMS trong 24h (không gia hạn) + tự sinh dự án "Dự án Khách hàng" (Client Billable) + OPS_AM xác nhận capacity; engine sinh khung WBS sơ bộ từ template theo `servicePackage` (mỗi deliverable map ≥1 WBS node, dependency mặc định finish-to-start); từ WON Sales chuyển observe; D+0 chỉ kích hoạt khi tiền vào TK + FIN_L1 xác nhận 4h + LOI/HĐ đã ký (HĐ đầy đủ ≤7 ngày sau D+0) | WON không ghi 24h → cảnh báo + escalate; sinh dự án fail (thiếu tier/servicePackage) → block WON; WBS node không map deliverable là mồ côi — không tính công |
| BR-OPS-6.7 | **WBS + duyệt creative đa vai:** pipeline bắt buộc OPS_CONT → OPS_DES/OPS_EDIT → OPS_AM/OPS_PLAN duyệt nghiệp vụ; mỗi bước Approved/Request changes (comment bắt buộc khi reject); **cấm tự duyệt task của mình — approver ≠ creator, chặn tầng API**; SLA duyệt: AM 2h (video dài 4h, trend gấp 1h), content self-QC + Lead review 4h; quá SLA nhắc, chậm 2 bước liên tiếp escalate OPS_PLAN; vòng sửa creative tối đa 3 vòng nội bộ — vòng 4 escalate AM chốt phạm vi bằng văn bản với khách; task gắn WBS node bắt buộc trước khi gán người (capacity check thuộc REQ-OPS-007) | Tự duyệt bị từ chối kèm audit; vòng 4 tự sinh escalation đến AM; task mồ côi không lưu được; SLA breach sinh escalation record không xóa được |
| BR-OPS-6.8 | **Campaign change log bất biến:** mọi thay đổi ngân sách/bid/target/audience/creative chính (kể cả trong A/B test) bắt buộc reason; lưu giá trị cũ/mới, actor, timestamp — append-only, cấm sửa/xóa; phân bậc duyệt hạn mức: buyer tự quyết trong hạn mức ngày — vượt ngày → OPS_PLAN duyệt — vượt dự án → OPS_AM duyệt; khẩn cấp (die account, brand safety) pause trước, bổ sung reason trong 4h làm việc | Request thiếu reason bị từ chối tầng API; sửa/xóa change log bị chặn + alert bảo mật; quá 4h không bổ sung reason → escalate OPS_PLAN |
| BR-OPS-6.9 | **A/B testing kỷ luật sample:** 1 biến/test; 2–7 ngày; budget ≥2–3× CPL target/ngày/ad set; chỉ declare winner khi **sample ≥50 clicks hoặc ≥10 conversions và chênh ≥20%**; OPS_AM declare bằng e-approval có audit; kết luận gắn evidence (số liệu nguồn, thời điểm chốt) | Declare thiếu sample hoặc lift <20% bị từ chối; test không đăng ký trước không tạo bản ghi; đổi biến giữa chừng → force kết thúc + ghi lý do vào change log |
| BR-OPS-6.10 | **SLA gate + escalation + audit + tenant isolation:** mọi gate/duyệt có SLA clock tính giờ làm việc cấu hình theo tenant; quá hạn sinh escalation tự động (chuỗi SALES_L4 → SALES_L5 → BOD_CEO — borderline 4h, duyệt GM 1 ngày LV, WON update 24h); mọi chuyển stage, chữ ký, override, escalation, cấu hình ghi audit log bất biến WORM (ai, khi nào, từ/sang gì, căn cứ); toàn bộ truy vấn scope theo tenant | SLA breach không sinh escalation là lỗi P0; sửa/xóa audit log bị chặn + alert; request cross-tenant bị từ chối kể cả token hợp lệ |

---

## 4. Phân Quyền

| Hành động | OPS_PLAN | OPS_AM | OPS_CONT/DES/EDIT | OPS_ADS | SALES_L4 (SM) | SALES_L5 (GDKD) | FIN_L1 | SYS_ADMIN |
|-----------|----------|--------|--------------------|---------|---------------|-----------------|--------|-----------|
| Xem workspace/trạng thái gate (theo tenant) | ✅ | ✅ | ✅ | ✅ | ✅ (deal mình) | ✅ | ✅ (phần giá) | ✅ |
| Chấm Brand Safety + Weighted (EVALUATION) | ✅ | ✅ | ❌ | ❌ | ✅ (chỉ định thẩm định) | ❌ (nhận escalate) | ❌ | ❌ |
| Soạn proposal theo template tier | ✅ (D/E) | ✅ (B/C) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Tạo vòng review "Request changes" | ✅ | ✅ | ✅ (creative của mình) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Duyệt GM / margin / giá cuối | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ (chỉ tính giá) | ❌ |
| Duyệt exception vượt vòng / lệch định mức / gia hạn (≤1 lần) | ❌ (đề xuất) | ❌ (đề xuất) | ❌ | ❌ | ✅ (quyết 3 phương án) | ✅ (duyệt gia hạn) | ❌ | ❌ |
| Gửi proposal v1.0 cho khách | ❌ | ✅ (sau duyệt GM + Rehearsal pass) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Tính giá quotation | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Chạy campaign + ghi change log (có reason) | ❌ (duyệt vượt hạn mức ngày) | ❌ (duyệt vượt hạn mức dự án) | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Đăng ký A/B test / declare winner | ✅ (duyệt đăng ký) | ✅ (declare) | ❌ | ✅ (thực thi) | ❌ | ❌ | ❌ | ❌ |
| Xác nhận WON / confirm tiền D+0 | ❌ | ✅ (xác nhận capacity) | ❌ | ❌ | ❌ (xác nhận bàn giao) | ❌ | ✅ (confirm tiền) | ❌ |
| Cấu hình SLA/escalation/trọng số/template | ❌ (đề xuất) | ❌ | ❌ | ❌ | ❌ | ✅ (đề xuất trình BOD) | ❌ | ✅ (thực thi) |
| Xóa/sửa audit log, change log | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ (WORM — cả SYS_ADMIN bị chặn) |

> Chữ ký và duyệt theo **mã vai** trong registry 18 vai, không theo người — hỗ trợ vai kiêm nhiệm (GDKD `SALES_L5` tạm do BOD đảm nhận). Vai AD (KXN-12 — `OPS_AD`) chưa nằm trong registry hiện hành, quyền duyệt giá/margin gán GDKD theo BR-OPS-6.5 (xem Mục 5). **Không dùng `OPS_CX`/`FIN_COMPL`** (DI-006). Xác nhận pháp lý cho "Từ chối vận hành" là bản ghi văn bản ngoài registry — duyệt cuối trên hệ thống thuộc OPS_PLAN trong 24h, BOD_CEO oversight.

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ mà tính năng này phải xử lý.*

- **Deal chiến lược override knockout (thượng nguồn):** workspace đọc nhãn override K1–K5 do gate engine lane CRM-PIPELINE ghi (GDKD phê duyệt, lý do văn bản, log bất biến); workspace không "hóa giải" được nhãn override và bắt buộc đưa vào danh sách rà quý.
- **Khách tái ký:** Initial Brief rút gọn nhưng Gate 1/Gate 2 không bỏ; proposal vẫn theo `qualifiedTier` hiện hành — không có cấu hình "bỏ gate" cho phân khúc nào.
- **Vai AD (KXN-12):** `OPS_AD` chốt tách vai nhưng chưa đồng bộ registry 18 vai; quyền duyệt giá sơ bộ/giá cuối/vượt giới hạn revision tạm gán GDKD (`SALES_L5`) theo BR-OPS-6.5; câu hỏi "Quản lý GM (V6.0) = AD hay BOD/CFO?" còn mở — khi chốt chỉ tách quyền theo mã vai, không đổi API contract.
- **Ma trận RACI chờ xác nhận `[KXN-19]`:** chuỗi phê duyệt/escalation mặc định theo file 08 nhưng cấu hình được theo tenant; khi RACI chính thức được xác nhận chỉ cập nhật cấu hình, không sửa code.
- **GW degraded mode (DI-007):** chưa có quyền API developer trên nền tảng QC — dữ liệu chi tiêu đối chiếu hiệu quả gắn nhãn `manual` + nguồn + timestamp; gate logic feature này không phụ thuộc GW nên không bị chặn.
- **11 khoản KXN còn mở — assumption có tag, không tự quyết:** `[KXN-6]` bộ tiêu chí Evaluation — mặc định theo bộ V6.0 (Brand Safety 7 + Weighted ≥3,5), thay được khi chốt; `[KXN-7]` 16 sections Strategic Brief — template tạo 16 slot, điều kiện ≥80%, nội dung trống chờ khách hàng; `[KXN-9]` phạm vi "tương lai" CMS/TMS/AI Agent — chỉ giữ extension point; `[KXN-17]` 4 nhóm LOST A/B/C/D — enum placeholder cấu hình được; `[KXN-20]` cờ K6–K12 — mở rộng bằng cấu hình; `[KXN-21]` 4 lý do LOST Pitching/Negotiation — enum đề xuất (thua đối thủ/chiến lược/thời điểm/nhân sự) chờ xác nhận.
- **Khẩn cấp dừng chiến dịch:** pause ngay không cần duyệt trước; reason bổ sung vào change log trong 4h làm việc, quá hạn escalate OPS_PLAN — không có "khẩn cấp = miễn reason".
- **Đổi người giữa chừng (AM/Planner nghỉ, backup):** vòng sửa, chữ ký chưa ký và SLA clock bám dự án chứ không bám người; backup nhận nguyên revision history — không reset vòng đếm.
- **KXN còn mở ngoài phạm vi feature nhưng ghi nhận để đầy đủ (assumption có tag, không tự quyết):** `[KXN-15]` hình thức gửi Client Survey (thuộc REQ-OPS-009/06 — feature này không xử lý survey); `[KXN-16]` node trùng `internal_retro` trong dữ liệu gốc v2.3 (thuộc giai đoạn Kết thúc); `[KXN-18]` quy trình HR (thuộc lane HR-CORE); `[KXN-22]` mốc non-payment 15 ngày → PAUSE (thuộc finance/campaign pause — feature này chỉ đọc trạng thái PAUSED, không định nghĩa mốc).

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Entity chính là `project` — vòng đời 30 stage chia 5 giai đoạn (Sales → Đánh giá & Đề xuất → Triển khai D+0→D+5 → ONGOING → Kết thúc). Sơ đồ dưới trình bày đoạn thuộc workspace (EVALUATION → WON → DEPLOY); stage Sales và Kết thúc do lane/module tương ứng sở hữu — workspace chỉ đọc.*

**Entity:** Project (stage machine 30 stage)

**Sơ đồ trạng thái:**
```
[QUALIFIED·Gate2] ──(handoff pass)──► [EVALUATION] ──(BS 7/7 + Weighted ≥3,5)──► [SECOND_MEETING]
        │                                   │ (fail 1/7 BS — không ngoại lệ)               │ (Strategic Brief ≥80% [KXN-7])
        │                                   ▼                                              ▼
        │                             [LOST chủ động]                                  [PROPOSAL_INTERNAL v0.x ≤3 vòng]
        │                                                                                     │ (giá sơ bộ GDKD confirm)
        │          [PROPOSAL v1.0] ◄──(Rehearsal pass + GDKD duyệt GM + đúng định mức)── [REHEARSAL]
        │                 │ (gửi KH — log ProposalRevision)                                     │ (chưa ổn → sửa v0.x)
        │                 ▼
        │          [PROPOSAL_REVIEW ≤2/≤4 vòng theo tier] ──(vượt hạn → chặn + escalate SM/GDKD)
        │                 ▼
        │           [PITCHING] ──(KH chọn)──► [QUOTATION — FIN_L1 giá + GDKD duyệt margin]
        │                 │ (từ chối → LOST [KXN-21])                                           ▼
        │                 └───────────────────────────────────────────────────────► [NEGOTIATION — HĐ/LOI ký] ──► [WON]
        │                                                                                       │ (24h update + sinh dự án + AM xác nhận capacity)
        │                                                                                       ▼
        │                                    [COLLECTING ∥ WAIT_PAYMENT] ──(tiền vào + FIN_L1 confirm 4h + LOI/HĐ [KXN-5])──► [DEPLOY D+0→D+5] ──► [ONGOING]
        ▼
[PAUSED] (bất kỳ stage — SM/GDKD duyệt; review 2 tuần; 60 ngày im lặng → LOST nhóm A [KXN-17])
```

**Bảng chuyển đổi:**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `QUALIFIED` (Gate 2 pass) | Nhận bàn giao | `EVALUATION` | Hệ thống | SLA đánh giá 2 ngày LV (+1 phức tạp) |
| `EVALUATION` | Chấm BS 7/7 + Weighted | `SECOND_MEETING` / `LOST` | OPS_AM/OPS_PLAN chấm; hệ thống validate | Pass: BS 7/7 + Weighted ≥3,5 (borderline 3,0–3,49 → thẩm định 4h do SM chỉ định rồi mới quyết); fail ≥1/7 BS → `LOST` chủ động, không ngoại lệ, evidence từng tiêu chí |
| `SECOND_MEETING` | Strategic Brief ≥80% | `PROPOSAL_INTERNAL` | OPS_AM/OPS_PLAN | 16 sections ≥80% `[KXN-7]`; SLA 3 ngày (+2 KH bận) |
| `PROPOSAL_INTERNAL` | Hoàn tất v0.x | `REHEARSAL` | OPS_AM/OPS_PLAN; GDKD giá sơ bộ | ≤3 vòng nội bộ trong 5 ngày LV |
| `REHEARSAL` | Pitch thử đạt | `PROPOSAL` (v1.0) | OPS_AM ghi nhận; GDKD giá cuối | Pitch ≥1 lần; Q&A script + kịch bản từ chối; giá cuối GDKD xác nhận |
| `PROPOSAL` | Gửi khách v1.0 | `PROPOSAL_REVIEW` | OPS_AM | GDKD đã duyệt GM (SLA 1 ngày LV); đúng định mức trang; vòng trong hạn; log ProposalRevision |
| `PROPOSAL_REVIEW` | Vòng sửa khách (nội hạn) | `PROPOSAL_REVIEW` (n+1) / `PITCHING` / `LOST` | OPS_AM sửa; SM/GDKD quyết khi chạm hạn | KH 3 ngày / AM 2 ngày; im 3 ngày nhắc, 5 ngày escalate SM; quá B/C ≤2 hay D/E ≤4 → chặn, quyết 1 trong 3: pitch bản hiện có / gia hạn GDKD duyệt ≤1 lần / dừng deal |
| `PITCHING` | KH chọn agency | `QUOTATION` | OPS_AM ghi nhận | SLA 5 ngày LV (+3); từ chối → `LOST` với `lostReason` enum `[KXN-21]` |
| `QUOTATION` → `NEGOTIATION` | Phát hành báo giá; HĐ/LOI ký 2 bên | `NEGOTIATION` → `WON`/`LOST` | FIN_L1 tính giá; GDKD duyệt margin; OPS_AM dẫn đàm phán | Quotation chỉ sau Pitching, gắn proposal đã duyệt (SLA 2 ngày LV); Negotiation SLA 5 ngày (gia hạn SM khi lý do pháp lý); thay đổi giá ghi audit; reporting frequency set |
| `WON` | Chốt + sinh dự án | `COLLECTING ∥ WAIT_PAYMENT` | Hệ thống + OPS_AM | Update PMS 24h; dự án Client Billable tự sinh; checklist tài nguyên tự tạo; SE observe |
| `COLLECTING ∥ WAIT_PAYMENT` | Kích hoạt D+0 | `DEPLOY` (PLANNING_DRAFT → KICKOFF_I1 D+1 → KICKOFF_I2 D+2 → KICKOFF_CLIENT D+3 → ONGOING D+5) | FIN_L1 confirm tiền; OPS_AM điều phối | Tiền vào + FIN_L1 xác nhận 4h + LOI/HĐ `[KXN-5]`; tài nguyên trước D+4; 6 Rules ký D+3; done-criteria theo stage-gate v1.2 bảng 2.1 (KXN-10) |

**Quy tắc:**
- Hard gate không nhảy bước: chỉ chuyển stage khi 100% done-criteria đạt — chặn tầng service kể cả yêu cầu từ WEB/MOBILE; `WON`/`LOST` là nhánh kết thúc chu trình đề xuất — khách quay lại đi bằng RENEW 3 luồng A/B/C.
- `PAUSED` khả dụng ở mọi stage (AM đề xuất + SALES_L4/SALES_L5 duyệt, 24h update; review 2 tuần/lần; 60 ngày không hồi âm → LOST nhóm A `[KXN-17]`); resume quay đúng stage trước pause.
- Mọi chuyển trạng thái, chữ ký, override, escalation ghi audit log WORM scope theo tenant; revision/round counter append-only — không reset bằng thao tác thường.

---

## 7. Tóm Tắt Entity (Quick Reference)

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| `project` | `stage_code` (enum 30), `client_tier` (đã khóa, read-only), `service_package`, `reporting_frequency`, `project_type`, `tenant_id` | FK → `clients.id`, `tenants.id` | Tier khóa sau Gate 1 — engine chỉ đọc |
| `stage_gate_check` | `project_id`, `stage_code`, `criterion_code`, `check_type` (AUTO/HUMAN), `passed`, `evidence_ref` | FK → `project.id` | Snapshot mỗi lần mở gate; không xóa |
| `brand_safety_assessment` | `client_id`, `contract_id`, `criterion_no` (1–7), `status`, `evidence_ref`, `assessed_by` | FK → `clients.id` | All-pass ràng buộc EVALUATION; tái dùng cho "Từ chối vận hành" |
| `weighted_evaluation` | `project_id`, `criterion_code` (9), `weight`, `score_1_5`, `weighted_total`, `verdict` | FK → `project.id` | Trọng số cấu hình theo tenant |
| `proposal` / `proposal_revision` | `project_id`, `version`, `round_type` (INTERNAL/CLIENT), `round_no`, `page_count`, `tier_rule_snapshot`, `reviewer_id`, `comment`, `status` | FK → `project.id` | Append-only; snapshot định mức tier lúc tạo |
| `e_approval` | `object_type` (GM/BORDERLINE/GIA_HAN/LECH_DINH_MUC/DECLARE_WINNER), `object_id`, `requester_id`, `approver_role`, `sla_due_at`, `decision` | FK → `users.id` | Dùng chung approval engine; approver theo mã vai ≠ requester |
| `rehearsal_record` | `project_id`, `held_at`, `participants`, `qa_script_ref`, `price_confirmed_by` | FK → `project.id` | Done criteria trước PROPOSAL v1.0 |
| `quotation` | `project_id`, `proposal_id`, `priced_by` (FIN_L1), `margin_approval_id`, `status` | FK → `proposal.id` | Chỉ phát hành sau Pitching + margin approved |
| `wbs_node` | `project_id`, `parent_id`, `deliverable_ref`, `dependency_type` (FS), `estimate_hours` | FK → `project.id` | Khung sơ bộ; chi tiết thuộc REQ-OPS-006 |
| `campaign_change_log` | `campaign_id`, `field`, `old_value`, `new_value`, `reason`, `actor_id`, `changed_at` | FK → `campaigns.id` | Append-only WORM; write thiếu `reason` bị từ chối |
| `ab_test` | `project_id`, `variable`, `started_at`, `sample_clicks`, `sample_conversions`, `lift_percent`, `winner_id`, `declared_by` | FK → `project.id` | Đăng ký trước khi chạy; validate sample/lift lúc declare |
| `audit_log` | `tenant_id`, `actor_id`, `action`, `object_type`, `object_id`, `from_value`, `to_value`, `basis_ref`, `at` | FK → `tenants.id` | WORM — cả SYS_ADMIN không sửa/xóa |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — phác thảo sơ bộ test được ở Phase 2; chi tiết hóa tại Phase 5 (implementation tasks).*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Brand Safety fail 1/7 | Deal ở EVALUATION, tiêu chí (4) quyền ảnh = FAIL | OPS_AM cố chuyển sang PROPOSAL | API từ chối "BS not all-pass"; stage giữ nguyên; không có ngoại lệ; evidence lưu | [ ] |
| SC-002: Borderline Weighted | Weighted total = 3,2 | Hệ thống chấm xong | Tự vào hàng đợi thẩm định SLA 4h (SM chỉ định); hết 4h escalate GDKD; không tự pass | [ ] |
| SC-003: Sai định mức trang / vượt vòng | Tier C (8–12 trang, ≤2 vòng), proposal 14 trang hoặc đã dùng 2/2 vòng | OPS_AM gửi duyệt / tạo vòng 3 | Validator từ chối theo `tier_rule_snapshot`; escalate SM 3 phương án; gia hạn chỉ GDKD duyệt ≤1 lần, log bất biến | [ ] |
| SC-004: Gửi khách khi chưa duyệt GM | Proposal đủ trang, trong hạn vòng, chưa có e-approval GM | OPS_AM gửi v1.0 | API từ chối "GM approval missing"; WEB khóa nút đồng bộ; quá SLA escalation tự sinh | [ ] |
| SC-005: WON tự sinh dự án | HĐ đã ký, NEGOTIATION kết thúc | Hệ thống chuyển WON | Dự án Client Billable tự sinh trong 24h; thiếu `servicePackage` → block + alert; OPS_AM xác nhận capacity; SE observe | [ ] |
| SC-006: Change log thiếu reason | OPS_ADS đổi daily budget | Submit không nhập reason | API từ chối; không tạo bản ghi; pause khẩn cấp cho phép nhưng quá 4h không bổ sung reason → escalate OPS_PLAN | [ ] |
| SC-007: A/B declare thiếu điều kiện | Sample 30 clicks, lift 12% | OPS_ADS declare winner | API từ chối (cần ≥50 clicks hoặc ≥10 conversions và chênh ≥20%); declare hợp lệ cần đủ điều kiện + e-approval OPS_AM | [ ] |
| SC-008: Tự duyệt creative + vòng 4 | OPS_CONT vừa soạn bài; deliverable đã qua 3 vòng nội bộ | OPS_CONT tự duyệt; vòng 4 được tạo | Tự duyệt bị từ chối (approver = creator); vòng 4 tự sinh escalation đến OPS_AM kèm văn bản chốt phạm vi | [ ] |
| SC-009: D+0 thiếu điều kiện | Tiền đã vào nhưng chưa có LOI/HĐ | Hệ thống đánh giá kích hoạt D+0 | Không kích hoạt; cảnh báo HĐ mốc ngày 3; kích hoạt khi FIN_L1 confirm + LOI/HĐ đủ `[KXN-5]` | [ ] |

> **Liên kết:** SC-001…SC-009 map về REQ-OPS-005 (stage-gate machine-checkable, Brand Safety 7/7, định mức tier, đếm vòng + escalation, duyệt GM trước gửi khách, WON sinh dự án, change log bất biến, A/B sample, duyệt creative đa vai, D+0 `[KXN-5]`) và rule B.6 trong `operations.md`.

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Các chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) — project, stage_gate_check, brand_safety_assessment, proposal_revision, change_log, ab_test, audit_log | `phase3-architecture/technical-specs/database-design.md` |
| API Endpoints — StageGateService, ProposalService, CreativeApprovalService, ChangeLogService, ABTestService | `phase3-architecture/technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống — WEB/M-INT counterparts, GW degraded mode, hard block tầng API | `phase3-architecture/technical-specs/integration-map.md` |
| Màn hình UI soạn proposal + checklist (WEB) và app duyệt (M-INT) | `phase4-ux/SYS-BCERP-WEB/MOD-PROPOSAL-PLANNING/[screen-group].md`, `phase4-ux/SYS-MOBILE-INTERNAL/MOD-PROPOSAL-PLANNING/[screen-group].md` |
| Nghiệp vụ gốc & business rules đầy đủ | `phase1-business/departments/operations/operations.md` (REQ-OPS-005 + B.6), `P1-02-business-workflow.md` (Luồng 3), `documents/quy-trinh-lam-viec/01` (vòng đời + tier), `03` (GĐ2), `04` (Deploy), `08` (RACI `[KXN-19]`), `09` (hằng số), `10` (KXN chốt/còn mở) |
