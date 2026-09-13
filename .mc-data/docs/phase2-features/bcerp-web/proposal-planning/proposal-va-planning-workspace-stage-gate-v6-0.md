# Tính Năng: Proposal & Planning Workspace (Stage-Gate V6.0)

> **Dựa trên:** REQ-OPS-005 trong `phase1-business/departments/operations/operations.md` (Phần A; business rules chi tiết Phần B.6)
> **Phân hệ:** Vận hành dự án & Marketing nội bộ (SYS-BCERP-WEB)
> **Module:** Proposal & Planning (MOD-PROPOSAL-PLANNING)
> **Ngày:** 12/09/2026
> **Trạng thái:** Chờ triển khai
>
> READS: `_meta/req-registry.json`, `phase1-business/departments/operations/operations.md`, `phase0-brainstorm/policies/stage-gate-lifecycle-v6.md` (bản 1.2), `documents/quy-trinh-lam-viec/` v1.1 (file 01, 03, 04, 08, 09, 10)
> USED BY: `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/*.md`, `phase4-ux/bcerp-web/proposal-planning/*.md`, `phase5-implementation/tasks/bcerp-web/proposal-planning/feat-erp-propln-001-impl.md`

> **Hướng dẫn ID:** FEAT-ID sinh từ REQ-ID (`REQ-[DEPT]-[NNN]` → `FEAT-[SYS]-[MOD]-[NNN]`); riêng tính năng này là **FEAT-ERP-PROPLN-001** theo mapping lane (REQ-OPS-005 fan-out 3 systems).

---

## Thông Tin Chung

| Trường | Giá trị |
|--------|--------|
| ID tính năng | FEAT-ERP-PROPLN-001 |
| Module | MOD-PROPOSAL-PLANNING |
| Yêu cầu nghiệp vụ | REQ-OPS-005 |
| Người dùng liên quan | OPS_PLAN, OPS_AM, OPS_CONT, OPS_DES, OPS_EDIT, OPS_ADS; vai duyệt: SALES_L4 (SM), SALES_L5 (GDKD — giá/margin), FIN_L1, BOD_CEO/BOD_CFO_CTO, SYS_ADMIN |
| Độ ưu tiên | Cao |
| Giai đoạn | Giai đoạn 2 |
| Phụ thuộc | Không có cross-dependency. REQ-OPS-005 fan-out 3 systems — bản này là phần SYS-BCERP-WEB; counterpart: SYS-CORE-BACKEND (gate engine chặn tầng API), SYS-MOBILE-INTERNAL (duyệt concept, nhận escalate). WEB gọi CORE và hiển thị đúng machine-state |

---

## 1. Mô Tả Tính Năng

**Mục đích:**
Workspace web nội bộ (Next.js, responsive) để BPVH điều khiển chặng EVALUATION → WON → DEPLOY của stage-gate V6.0: xem trạng thái gate machine-state, soạn proposal đúng định mức tier, duyệt đa vai, quản lý WBS, change log, A/B test. Tính năng hiện thực hóa nguyên tắc *"Không ghi nhận vào PMS = Không tồn tại"* — mọi checklist, chữ ký, vòng sửa, quyết định gate chỉ có giá trị khi nằm trên hệ thống với done-criteria machine-checkable.

**Phạm vi:**
- Bao gồm: workspace stage-gate (checklist tách "hệ thống tự kiểm" và "thuần phán đoán con người", đồng hồ SLA, escalate); soạn proposal từ template theo tier kèm validator đếm trang/vòng; checklist Brand Safety 7 tiêu chí + Weighted ≥3,5; WBS sau WON; duyệt creative đa vai; change log bất biến; A/B test; timeline D+0 → D+5.
- Không bao gồm: gate engine/e-approval backend (CORE); duyệt concept di động (M-INT); bề mặt khách nghiệm thu (PORTAL/M-PORTAL); TKQC và ví (REQ-OPS-001/002/003); capacity & timesheet chi tiết (REQ-OPS-007 — chỉ nhận kết quả check); SLA ticket (REQ-OPS-008/009); tích hợp CMS/TMS "tương lai" `[KXN-9]`; các khoản ngoài lõi: hình thức gửi Client Survey `[KXN-15]`, dọn node retro trùng lặp `[KXN-16]`, quy trình HR `[KXN-18]`, mốc non-payment 15/30 ngày `[KXN-22]`.

---

## 2. Luồng Người Dùng (User Stories)

| # | Với tư cách là... | Tôi muốn... | Để... |
|---|------------------|------------|-------|
| 1 | OPS_PLAN | Xem stage hiện tại, checklist done-criteria, đồng hồ SLA từng gate | Biết chính xác việc nào chặn gate, không đoán cảm tính |
| 2 | OPS_AM | Soạn proposal tier B/C 8–12 trang từ template theo `qualifiedTier` đã khóa | Đúng định mức ngay từ bản đầu, không bị chặn lúc gửi |
| 3 | OPS_PLAN | Chủ trì proposal 15–25 trang tier D/E với section chiến lược (tier E thêm Team Bios + Brand Safety) | Khách giá trị cao nhận proposal sâu đúng chuẩn V6.0 |
| 4 | OPS_AM / OPS_PLAN | Nhận "Request changes" kèm comment bắt buộc, thấy số vòng còn lại, bị chặn khi hết hạn mức | Vòng sửa có kỷ luật, không sửa vô tận |
| 5 | OPS_CONT / OPS_DES / OPS_EDIT | Nhận brief gắn WBS node, tự QC theo checklist rồi chuyển Lead review 4h | Chuỗi content → design/video lưu vết từng bước |
| 6 | OPS_PLAN / OPS_AM | Duyệt creative đa vai trên web, hệ thống chặn tự duyệt task của mình | Không bước duyệt nghiệp vụ nào bị bỏ sót |
| 7 | OPS_ADS | Kê khai A/B test và thấy hệ thống xác nhận đủ sample trước khi AM declare winner | Quyết định tắt/scale theo ngưỡng thống kê chuẩn |
| 8 | OPS_ADS | Đổi ngân sách/bid/targeting qua form change log bắt buộc lý do, ghi giá trị cũ/mới | Mọi thay đổi chiến dịch truy vết được |
| 9 | SALES_L4 (SM) | Nhận escalate khi khách im 5 ngày ở PROPOSAL_REVIEW hoặc negotiation trễ SLA | Deal không chết âm thầm vì thiếu người vào cuộc |
| 10 | SALES_L5 (GDKD — duyệt giá) | Duyệt Gross Margin bằng e-approval SLA 1 ngày làm việc, quá hạn tự escalate | Không có proposal nào lọt tới khách khi chưa duyệt giá |

---

## 3. Quy Tắc Nghiệp Vụ

> *Quy tắc bắt buộc — developer xử lý đúng trong code. WEB gọi gate engine của CORE; hard block phải tồn tại ở tầng API, UI chỉ phản chiếu.*

| Mã | Quy tắc | Khi vi phạm thì... |
|----|---------|------------------|
| BR-001 | **Stage-gate V6.0 30 stage, done-criteria machine-checkable:** vòng đời 5 giai đoạn (Raw Data → CLOSED/RENEW) qua 30 stage; bảng 2.1 policy `stage-gate-lifecycle-v6.md` bản 1.2 chuẩn hóa entry/done criteria, tách tiêu chí hệ thống tự kiểm (validation, đếm checklist %, Weighted, e-approval, SLA) và thuần phán đoán con người (bắt buộc có bản ghi). Done criteria DEPLOY đã phê chuẩn theo `[KXN-10]` (tái dựng từ Lifecycle v2.3) | Thiếu bất kỳ criteria → nút chuyển stage vô hiệu trên UI, API từ chối; nỗ lực bị chặn ghi audit log |
| BR-002 | **"Không ghi nhận vào PMS = Không tồn tại":** feedback KH qua Zalo/Email bắt buộc nhập lại; mọi chuyển stage/override/escalation ghi audit log bất biến (ai, khi nào, giá trị cũ/mới) | Giao dịch thiếu bản ghi không được công nhận; feedback chưa nhập không tính vòng review |
| BR-003 | **EVALUATION chặn cứng Brand Safety 7/7 + Weighted ≥3,5:** fail 1/7 tiêu chí → dừng, không sang PROPOSAL, không ngoại lệ; borderline 3,0–3,49 vào hàng đợi thẩm định 4h, kết luận kèm lý do; cờ K6–K12 theo danh sách chờ chốt `[KXN-20]`; bộ tiêu chí bản V6.0 chờ phê chuẩn chính thức `[KXN-6]` | Checklist thiếu pass → gate không mở; fail Brand Safety → LOST chủ động |
| BR-004 | **Template và định mức theo tier (tier policy §2.2 — KXN-1/KXN-8):** B/C — 8–12 trang, OPS_AM soạn, ≤2 vòng; D/E — 15–25 trang, OPS_PLAN chủ trì, ≤4 vòng; đọc tier từ profile khách (`qualifiedTier` khóa sau Gate 1, cấm hardcode); validator đếm trang, chặn gửi khi sai định mức | Lệch định mức → nút gửi khóa + báo lỗi cụ thể; soạn sai vai → cảnh báo, ghi lệch quy trình |
| BR-005 | **Đếm vòng review + escalation:** mỗi vòng = "Request changes" + comment bắt buộc; đếm trên proposal và quotation; nội bộ v0.x tối đa 3 vòng (v0.1→v0.3); client theo tier; chạm giới hạn → chặn vòng mới, escalate: chốt gửi bản hiện có / gia hạn có lý do (tối đa 1 lần/proposal, GM duyệt, log bất biến) / dừng deal | Tạo vòng mới khi hết hạn → API từ chối; tiếp tục chỉ sau quyết định escalation |
| BR-006 | **Duyệt nội bộ trước gửi khách:** duyệt giá/Gross Margin e-approval SLA 1 ngày làm việc, quá hạn tự escalate; chưa duyệt → không tồn tại trạng thái "đã gửi khách"; giá sơ bộ duyệt trước Rehearsal, giá cuối chốt tại Rehearsal; Rehearsal bắt buộc trước Pitching; Quotation chỉ phát hành sau Pitching, gắn proposal đã duyệt | Gửi thiếu duyệt → API từ chối + khóa nút; đã gửi thiếu e-approval → vi phạm quy trình riêng |
| BR-007 | **WBS sinh từ approved proposal sau WON:** mỗi deliverable map ≥1 WBS node; task bắt buộc gắn node (mồ côi không tính công); dependency mặc định finish-to-start, overlap phải duyệt có lý do; project type bắt buộc (Khách hàng/Nội bộ) khóa tập nhãn timesheet; capacity check bắt buộc trước mọi gán (từ REQ-OPS-007) | Tạo WBS khi chưa approved → từ chối; gán vượt capacity → chặn tầng API |
| BR-008 | **Duyệt creative đa vai + SLA từng bước:** pipeline OPS_CONT → OPS_DES/OPS_EDIT → OPS_PLAN/OPS_AM (duyệt nghiệp vụ); ý kiến khách qua AM; cấm tự duyệt (approver ≠ creator); SLA: OPS_AM 2h (video dài 4h, trend gấp 1h); content self-QC + Lead review 4h; tối đa 3 vòng sửa nội bộ/deliverable, vòng 4 escalate AM/TL chốt phạm vi bằng văn bản | Tự duyệt → chặn tầng API; quá SLA → nhắc, chậm 2 bước liên tiếp escalate TL; quá 3 vòng → chặn đến khi escalation chốt |
| BR-009 | **Campaign change log bất biến:** mọi thay đổi ngân sách/bid/target/audience/creative chính (kể cả trong A/B test) bắt buộc reason; lưu cũ/mới, ai, khi nào — append-only, cấm sửa/xóa; phân bậc: OPS_ADS tự quyết trong hạn mức ngày do TL cấu hình, vượt ngày → TL (OPS_PLAN), vượt dự án → OPS_AM; khẩn cấp pause trước, bổ sung reason trong 4h làm việc | Thiếu reason → engine từ chối tầng API; sửa/xóa → bị chặn; quá 4h không bổ sung → escalate |
| BR-010 | **A/B testing chuẩn sample:** 1 variable, 2–7 ngày, budget ≥2–3× CPL target/ngày/ad set; winner chỉ declare khi sample ≥50 clicks hoặc ≥10 conversions và chênh ≥20%; OPS_AM declare; kết quả ghi change log kèm evidence | Declare chưa đủ sample/chênh <20% → API từ chối; quá 7 ngày chưa đủ sample → cảnh báo, quyết gia hạn/dừng |
| BR-011 | **WON → DEPLOY điều kiện duy nhất:** WON cập nhật 24h, tự sinh dự án, OPS_AM xác nhận capacity; D+0 chỉ kích hoạt khi tiền vào TK + FIN_L1 confirm 4h LV + LOI hoặc HĐ đã ký (KXN-5; HĐ đầy đủ ≤7 ngày, cảnh báo ngày 3); Planning TT→ĐH→AD trong ngày D+0; kick-off nội bộ D+1/D+2 không lùi; 6 Communication Rules KH ký tại D+3 (Rules 1/2/3/5 bản dự thảo nội bộ — KXN-11); đủ tài nguyên trước ONGOING D+5 | Thiếu điều kiện D+0 → timeline không khởi động, hiển thị mốc bị chặn + lý do; thiếu tài nguyên → D+5 tự lùi |
| BR-012 | **SLA gate + escalation + quyền từ chối vận hành:** quá SLA gate → tự escalate cấp trên, ghi log; OPS phát hiện khách đang vận hành vi phạm 1/7 Brand Safety → "Từ chối vận hành": legal-expert xác nhận + TP OPS duyệt 24h, khóa trạng thái HĐ + notify legal + ops | Quá SLA không escalate → breach riêng; vi phạm không kích hoạt → escalate BOD xem trách nhiệm |
| BR-013 | **Ngoại lệ có kiểm soát:** deal chiến lược được SM override knockout K1–K5 — lý do văn bản + GM/BOD phê duyệt lại, log bất biến; khách tái ký rút gọn Initial Brief nhưng không bỏ Gate 1/Gate 2 | Override thiếu phê duyệt → không hiệu lực; bỏ Gate khi tái ký → từ chối chuyển stage |

---

## 4. Phân Quyền

> Chỉ dùng 18 vai registry. Ánh xạ: quyền "duyệt giá sơ bộ/giá cuối/margin, vượt vòng sửa" gốc thuộc Account Director/GDKD — mã `OPS_AD` đã chốt (KXN-12) nhưng **chưa thuộc registry 18 vai hiện hành**, gán tạm cho SALES_L5 (GDKD — vị trí quy hoạch, BOD tạm kiêm nhiệm theo 07 §1) và BOD. Assumption `[KXN-12 — phần còn mở]`: khi chốt "Quản lý GM = AD hay BOD/CFO" sẽ cấu hình lại approver trong RBAC, không đổi logic gate.

| Hành động | OPS_AM | OPS_PLAN | CONT/DES/EDIT/ADS | SALES_L4 | SALES_L5* | FIN_L1 | BOD | SYS_ADMIN |
|-----------|--------|----------|-------------------|----------|-----------|--------|-----|-----------|
| Xem deal/dự án phụ trách | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Xem tất cả | ❌ | ✅ | ❌ | ✅ | ✅ | ❌ | ✅ | ✅ |
| Soạn/chỉnh proposal theo tier | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Review/Request changes strategy | ✅ | ✅ | ✅ (feedback) | ❌ | ❌ | ❌ | ❌ | ❌ |
| Duyệt giá sơ bộ/giá cuối/Gross Margin | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ |
| Gửi proposal v1.0 cho khách (sau duyệt) | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Quyết vượt vòng sửa | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ |
| Tạo/điều chỉnh WBS | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Duyệt creative (cấm tự duyệt) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Ghi change log trong hạn mức | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Duyệt change vượt hạn mức ngày/dự án | ✅ (dự án) | ✅ (ngày) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Khai báo A/B test | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Declare winner A/B | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| "Từ chối vận hành" (Brand Safety) | ✅ (đề xuất) | ✅ (duyệt TP OPS) | ❌ | ❌ | ❌ | ❌ | ✅ (oversight) | ❌ |
| Ghi nhận tiền + LOI/HĐ → D+0 | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| Override knockout (đề xuất/phê duyệt) | ❌ | ❌ | ❌ | ✅ (đề xuất) | ❌ | ❌ | ✅ (duyệt lại) | ❌ |
| Cấu hình template/định mức/SLA; xóa/archive | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

---

## 5. Trường Hợp Đặc Biệt

> *Các tình huống ngoại lệ tính năng phải xử lý.*

- **Deal chiến lược override knockout:** SM override K1–K5 với lý do văn bản + GM/BOD phê duyệt lại; workspace hiển thị "override chờ phê duyệt" đến khi đủ chữ ký.
- **Khách tái ký:** nhận diện qua `parentProjectId`/luồng renew (A/B/C) — checklist rút gọn nhưng Gate 1/Gate 2 vẫn bắt buộc.
- **Borderline Weighted 3,0–3,49:** không tự pass — hàng đợi thẩm định 4h do SM chỉ định người (AM Lead tier A/B/C, AD tier D/E `[KXN-6]`), quá 4h tự escalate, kết luận kèm lý do.
- **Vượt vòng sửa:** nội bộ >3 vòng → AM họp Planner + người duyệt giá quyết nhanh, nhận version tốt nhất vào Rehearsal; khách chạm ≤2/≤4 → tự block + escalate (gửi thêm 1 lần / pitch bản hiện tại / dừng deal).
- **Feedback ngoài hệ thống:** Zalo/Email bắt buộc nhập lại kèm dẫn chứng gốc; chưa nhập thì không tính vòng review.
- **Rehearsal fail:** quay về sửa v0.x (trong trần 3 vòng); strategy sai cơ bản → dừng, sửa Strategic Brief, lịch lại trong 2 ngày.
- **Tier E Big Corp:** template tự thêm Team Bios + bảo mật dữ liệu + Brand Safety + rà soát điều khoản HĐ, validator tính vào hạn mức mở rộng.
- **AM vắng:** backup chain — OPS_PLAN backup #1, escalation cuối là quản lý (`OPS_AD` — `[KXN-12]` chờ đồng bộ registry); alert AM inactive >4h giờ làm việc.
- **Khẩn cấp dừng chiến dịch (die account, sự cố brand safety):** pause trước, bổ sung reason trong 4h; tắt toàn bộ campaign là quyền của AM, OPS_ADS chỉ tắt ad set đơn lẻ.
- **Ngoài giờ/lễ:** SLA tính giờ làm việc cấu hình (T2–T6 9:00–18:00, nghỉ trưa 12:00–13:00, GMT+7 mốc duy nhất).
- **KH im lặng:** PROPOSAL_REVIEW im 3 ngày nhắc, 5 ngày escalate SM; PITCHING im tuần 3 mặc định LOST — lý do theo enum đề xuất `[KXN-21]`, phân nhóm LOST A/B/C/D dùng tiêu chí đề xuất chờ khách hàng `[KXN-17]`.

---

## 6. Trạng Thái & Chuyển Đổi (State Machine)

> *Entity chính có state machine — bảng chuyển đổi dùng trực tiếp để implement validation. CORE quản lý trạng thái, WEB hiển thị và thu thập input.*

**Entity:** Deal/Dự án theo stage-gate V6.0 (đoạn workspace phụ trách: EVALUATION → ONGOING)

**Sơ đồ trạng thái:**
```
[EVALUATION] ──(7/7 + Weighted ≥3.5)──► [SECOND_MEETING] ──(16 sections ≥80%)──► [PROPOSAL_INTERNAL]
     │ (fail → LOST)                                                            │ (≤3 vòng + giá sơ bộ duyệt)
     ▼                                                                          ▼
   [LOST]                                                                [REHEARSAL] ──(pass + giá cuối duyệt)──► [PROPOSAL v1.0]
                                                                                                                    │ (e-approval + gửi ≤1 ngày)
                                                                                                                    ▼
                     [PITCHING] ──(KH chọn)──► [QUOTATION] ──(margin duyệt)──► [NEGOTIATION] ──(HĐ/LOI ký)──► [PROPOSAL_REVIEW]
                          │ (từ chối → LOST `[KXN-21]`)                                             ▼ (tiền vào + LOI/HĐ + capacity)
                          ▼                                                                                    ▼
                       [LOST/PAUSED]                                                 [DEPLOY D+0→D+5] ──(đủ tài nguyên)──► [ONGOING]
Nhánh ngang: stage bất kỳ ──(AM đề xuất + SM/AD duyệt)──► [PAUSED] ──(60 ngày im)──► [LOST nhóm A] `[KXN-17]`
```

**Bảng chuyển đổi (chính):**

| Trạng thái hiện tại | Hành động | Trạng thái mới | Ai được phép | Điều kiện bắt buộc |
|---------------------|-----------|----------------|-------------|---------------------|
| `EVALUATION` | Pass gate | `SECOND_MEETING` | Hệ thống | Brand Safety 7/7 + Weighted ≥3,5 + 2 meeting đủ 5 output; borderline có kết luận thẩm định 4h `[KXN-6]`; fail 1/7 → `LOST` không ngoại lệ |
| `SECOND_MEETING` | Chốt brief | `PROPOSAL_INTERNAL` | OPS_AM | Strategic Brief 16 sections ≥80% (cấu trúc chờ khách hàng `[KXN-7]`) + notes + 5 output |
| `PROPOSAL_INTERNAL` | Hoàn tất nội bộ | `REHEARSAL` | OPS_AM + duyệt giá | ≤3 vòng nội bộ (đếm tự động); giá sơ bộ đã duyệt |
| `REHEARSAL` | Pass pitch thử | `PROPOSAL` (v1.0) | OPS_AM | Pitch ≥1 lần; giá cuối + điều khoản duyệt tại Rehearsal; v1.0 link + Q&A script ghi hệ thống |
| `PROPOSAL` | Gửi khách | `PROPOSAL_REVIEW` | OPS_AM | E-approval duyệt giá (SLA 1 ngày LV); gửi ≤1 ngày sau Rehearsal; log `ProposalRevision`; KH im 3 ngày nhắc, 5 ngày escalate SM |
| `PROPOSAL_REVIEW` | Vòng sửa mới | `PROPOSAL_REVIEW` | OPS_AM/reviewer | Comment bắt buộc; trong hạn mức tier (B/C ≤2, D/E ≤4); vượt → chặn + escalation |
| `QUOTATION` | Duyệt margin + gửi | `NEGOTIATION` | Duyệt giá (SALES_L5/BOD) + FIN_L1 tính giá | Giá theo định mức; duyệt margin trước gửi; SLA 2 ngày |
| `NEGOTIATION` | Ký thỏa thuận | `WON` | OPS_AM + SM xác nhận | HĐ/LOI ký 2 bên + reporting frequency set; cập nhật 24h |
| `WON` | Kích hoạt D+0 | `DEPLOY` | FIN_L1 + Hệ thống | Tiền vào + confirm 4h + LOI/HĐ (KXN-5) + capacity confirm; tự sinh dự án + checklist |
| `DEPLOY` | Vào vận hành | `ONGOING` | Hệ thống + OPS_AM | Tài nguyên đủ trước D+4; kick-off nội bộ D+1/D+2 không lùi; KH ký 6 Rules tại D+3 (KXN-11); ONGOING D+5 |
| Stage bất kỳ | Tạm dừng / fail | `PAUSED` / `LOST` | OPS_AM đề xuất + SM/AD duyệt | Lý do bắt buộc; PAUSED review 2 tuần/lần, 60 ngày im → LOST nhóm A `[KXN-17]`; LOST ghi 24h `[KXN-21]` |

**Quy tắc:**
- Không quay về stage trước, trừ duy nhất `REHEARSAL` chưa đạt → về `PROPOSAL_INTERNAL` sửa v0.x (trong trần 3 vòng); mọi lần lùi ghi audit log. Bản `ProposalRevision` chạy: DRAFT → INTERNAL_REVIEW (≤3 vòng) → REHEARSAL_APPROVED → SENT_TO_CLIENT → CLIENT_REVIEW (≤2/≤4 vòng tier) → FINAL_PITCHED.
- `WON`/`LOST` một chiều: WON không revert thành NEGOTIATION; LOST chỉ tái kích hoạt qua luồng nurture/re-qualify riêng.
- Chuyển stage chỉ hợp lệ khi 100% done criteria pass — hard block cả UI lẫn API; override/escalation bắt buộc chữ ký + log bất biến; timestamps GMT+7, SLA giờ làm việc trừ mục 24/7.

---

## 7. Tóm Tắt Entity (Quick Reference)

> *Tóm tắt entity chính — chi tiết DDL tại `database-design.md`.*

| Entity | Fields chính | Quan hệ | Ghi chú |
|--------|-------------|---------|---------|
| Deal/Project | `stage`, `clientTier`, `qualifiedTier`, `servicePackage`, `reportingFrequency`, `dStartDate`, `paymentConfirmedAt`, `hasContractWarning`, `backup_am_id`, `parentProjectId`, `lostStage`, `lostReason`, `pausedAt`, `archivedAt` | FK → `customers.id`, `users.id` | Stage do CORE gate engine quản lý |
| GateCriteriaCheck | `deal_id`, `stage`, `criterion_code`, `machine_checkable`, `pass`, `evidence_ref`, `checked_by`, `checked_at` | FK → `deals.id` | Brand Safety 7 + Weighted 9 + checklist; bất biến |
| StrategicBrief | `deal_id`, `sections_payload`, `completion_pct`, `meeting_notes_ref` | FK → `deals.id` | 16 sections `[KXN-7]`; done khi ≥80% |
| ProposalRevision | `proposal_id`, `version_no`, `round_type`, `revision_count`, `reviewer_id`, `comment`, `status`, `sent_at` | FK → `proposals.id`, `deals.id` | Append-only; nguồn đếm vòng BR-005 |
| WBSNode | `project_id`, `parent_id`, `deliverable_ref`, `owner_id`, `dependency_type`, `status`, `project_type` | FK → `projects.id` | Task phải gắn node; dependency finish-to-start |
| CampaignChangeLog | `campaign_id`, `field`, `old_value`, `new_value`, `reason`, `actor_id`, `approval_level`, `created_at` | FK → `campaigns.id` | Append-only tuyệt đối; approval buyer/TL/AM |
| ABTest | `campaign_id`, `variable`, `start_date`, `end_date`, `daily_budget_cpl_ratio`, `sample_clicks`, `sample_conversions`, `lift_pct`, `winner_variant`, `declared_by` | FK → `campaigns.id` | Validate BR-010; declare bởi OPS_AM |
| ApprovalRecord | `subject_type`, `subject_id`, `approval_kind`, `approver_id`, `decision`, `reason`, `signed_at` | FK → entity cha | E-approval SLA 1 ngày LV; log bất biến |

---

## 8. Acceptance Criteria

> *Điều kiện nghiệm thu — phác thảo sơ bộ Phase 2, chi tiết ở Phase 5. Mỗi scenario map về REQ-OPS-005.*

| Scenario | Given | When | Then | Status |
|----------|-------|------|------|--------|
| SC-001: Brand Safety chặn gate | Deal ở EVALUATION | 1/7 tiêu chí fail | LOST chủ động, gate không mở, không nút ngoại lệ; audit ghi lý do | [ ] |
| SC-002: Validator định mức trang | Tier B, draft 6 trang | Bấm gửi/nhờ duyệt | Từ chối với lỗi cụ thể; nút gửi giữ khóa | [ ] |
| SC-003: Chặn vượt vòng sửa | Tier B/C đã đủ 2 vòng client | Tạo Request changes thứ 3 | API từ chối; mở luồng escalation 3 lựa chọn | [ ] |
| SC-004: Gửi khi chưa duyệt giá | Chưa có ApprovalRecord | Bấm "Gửi khách" | API từ chối + khóa nút; quá SLA 1 ngày tự escalate | [ ] |
| SC-005: Chặn tự duyệt creative | Task do OPS_CONT tạo | OPS_CONT bấm Approved | API từ chối (approver ≠ creator); ghi attempt vào audit | [ ] |
| SC-006: Change log thiếu reason | OPS_ADS đổi daily budget | Submit không nhập reason | API từ chối; nhập đủ thì ghi append-only old/new value | [ ] |
| SC-007: A/B winner chưa đủ sample | 30 clicks, chênh 25% | Declare winner | API từ chối vì chưa đạt ≥50 clicks hoặc ≥10 conversions | [ ] |
| SC-008: WON tự sinh dự án | NEGOTIATION pass (HĐ/LOI ký) | SM xác nhận WON trong 24h | Sinh dự án + checklist tài nguyên; DEPLOY mở sau capacity confirm | [ ] |

---

## Tài Liệu Kĩ Thuật Liên Quan

> *Chi tiết kĩ thuật (data model, API, integration) nằm tại file chuyên trách:*

| Nội dung | File |
|---------|------|
| Cấu trúc dữ liệu (DDL) | `technical-specs/database-design.md` |
| API Endpoints | `technical-specs/api-contract.md` |
| Tích hợp & quy tắc xuyên hệ thống | `technical-specs/integration-map.md` (CORE gate engine ↔ WEB workspace) |
| Màn hình UI | `phase4-ux/bcerp-web/proposal-planning/*.md` |
| Business rules nguồn | `phase1-business/departments/operations/operations.md` Phần B.6 (BR-OPS-6.1→6.5) |
| Policy stage-gate | `phase0-brainstorm/policies/stage-gate-lifecycle-v6.md` bản 1.2 — bảng 2.1 (DEPLOY phê chuẩn theo KXN-10) |
| Nguồn quy trình domain | `documents/quy-trinh-lam-viec/` v1.1 — file 01 (vòng đời), 03 (GĐ2), 04 (Deploy D+0→D+5), 08 (RACI/Gate/SLA `[KXN-19]`), 09 (hằng số), 10 (KXN, nhật ký §8) |
| Đối tác cùng REQ (fan-out) | SYS-CORE-BACKEND (gate engine, đếm vòng, hard block API); SYS-MOBILE-INTERNAL (duyệt concept, escalate di động) |
