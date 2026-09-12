# PROMPT — RESUME `/wf-define-features` PHIÊN MỚI (BCERP)

> **Cách dùng:** mở phiên zCode/Claude Code mới tại `E:\BC-Working`, dán nội dung dưới đây vào tin nhắn đầu tiên. Không cần context phiên trước — prompt tự chứa.
> **Soạn:** 12/09/2026 (sau audit độc lập + duyệt 11/22 KXN). Trạng thái pipeline: **resume-ready**.

---

## PROMPT BẮT ĐẦU TẠI ĐÂY

Chạy `/wf-define-features --resume` cho dự án **BCERP**. Session đang dở: `20260912-112934-6bcf` (P0 + P0.5 workload gate đã xong; override **CDG-A02** — Plan B full scope 19 modules ~190 phút; vị trí hiện tại: **phase1-scope-mapping**, 59 REQ → FEAT).

### Đọc trước khi chạy (theo thứ tự)

1. `.mc-data/work/wf-define-features/sessions/20260912-112934-6bcf/checkpoint.json` — `next_action` đã cập nhật.
2. `.mc-data/work/wf-analyze-requirements/deferred-issues.md` — **chỉ còn DI-004 cần hỏi tôi** (tên phần mềm kế toán VAS); DI-001/002/003/005/008 đã resolved.
3. `documents/quy-trinh-lam-viec/README.md` + `10_..._Khoan_Can_Xac_nhan.md` §4 + §8 — bộ gốc **v1.1**: 11/22 KXN đã chốt (cả 6 P0), nhật ký quyết định đầy đủ.
4. `.mc-data/docs/phase0-brainstorm/policies/phan-loai-khach-hang-tier.md` (bản 1.1) + `stage-gate-lifecycle-v6.md` (bản 1.2) — 2 policy đã đồng bộ chiều V6.0.

### Quyết định đã có (KHÔNG mở lại)

- **Tier:** 5 tier A–E theo V6.0 (A<1.5 AUTO LOST → E≥3.5 bypass); CQ 30/25/20/15/10; AUTO SCORING trước First Meeting + `qualifiedTier` sau Full Brief.
- **Proposal:** B/C = AM 8–12 trang ≤2 vòng; D/E = Planner 15–25 trang ≤4 vòng (DI-002/AUD-01 đã đóng).
- **Deploy (KXN-10):** D+0 = tiền vào + LOI/HĐ đã ký (HĐ đầy đủ ≤7 ngày); checklist tài nguyên D+4; Planning TT→ĐH→AD trong ngày D+0; 6 Rules ký tại D+3; ONGOING D+5 (DI-003 đã đóng).
- **Bàn giao:** tại QUALIFIED + Handoff Package 5 nhóm bắt buộc.
- **Vai:** AD = mã mới `OPS_AD` (nạp vào registry qua skill phase5 — không sửa tay); Creative Lead = Lead Content; bỏ CS; SM = SALES_L4 TPKD; registry hiện 18 vai.
- **Communication Rules 1/2/3/5:** bản dự thảo nội bộ đã duyệt (xem `documents/quy-trinh-lam-viec/09 §4`) — dùng được cho spec, ghi chú "chờ khách hàng xác nhận chính thức".
- **DI-001/005:** các con số đã chốt (mặc định experts + 3 mục từ v2.3) — xem deferred-issues chi tiết.

### Việc cần hỏi tôi trong phiên (duy nhất)

**DI-004:** tên phần mềm kế toán đang dùng (VAS) — để thiết kế connector đối chiếu sổ. (Hướng PMS cũ đã chốt: migrate chọn lọc + legacy read-only.)

### Ràng buộc

- Nạp REQ mới (39 ONGOING sub-protocol + Deploy timeline + UPSELL stage) **chỉ qua skill** (phase5-registry-update hoặc `/wf-add-scope`) — tuyệt đối không sửa tay `req-registry.json`.
- 11 KXN còn mở (6, 7, 9, 15, 16, 17, 18, 19, 20, 21, 22) **không chặn** — ghi nhận như assumption có tag trong spec, không tự quyết.
- Bối cảnh doanh nghiệp: đọc `AGENTS.md` §0 + `docs/00-overview/00-company-context.md`.

## HẾT PROMPT
