# PROMPT — AUDIT ĐỘC LẬP BỘ TÀI LIỆU QUY TRÌNH & ĐỐI CHIẾU PIPELINE MCV3

> **Cách dùng (cho chủ dự án):** mở phiên zCode/Claude Code mới tại repo `E:\BC-Working`, dọn toàn bộ nội dung dưới đường kẻ vào tin nhắn đầu tiên (hoặc `@` file này). Không cần context phiên trước — prompt tự chứa.
> **Soạn bởi:** phiên rà soát 12/09/2026 · **Chưa từng thực hiện** — đây là lần chạy đầu tiên.

---

## PROMPT BẮT ĐẦU TẠI ĐÂY

Bạn là auditor độc lập cho dự án **BCERP** — hệ thống ERP nội bộ của **BC Agency** (digital marketing agency; bối cảnh bắt buộc đọc: `AGENTS.md` §0 + `docs/00-overview/00-company-context.md`). Repo này là DEVKIT MCV3: pipeline tài liệu chạy qua các skill `wf-*`, artifacts runtime nằm ở `.mc-data/` (gitignored), tài liệu nguồn của khách hàng nằm ở `documents/`.

### 1. Đối tượng audit

**Bộ tài liệu vận hành chính thức (bộ gốc):** `documents/quy-trinh-lam-viec/` — 11 file Markdown (README + 10 file đánh số), phiên bản 1.0 ngày 12/09/2026, tái dựng từ 3 nguồn:
1. `documents/BC_Agency_Project_Lifecycle (1).html` — Project Lifecycle **v2.3** (flowchart tương tác, 72 entry: 33 stage + 39 sub-protocol ONGOING)
2. `documents/01_Quy_trinh_MKT_Tong_the.md` — Lifecycle **V6.0** (bị cắt cụt tại GIAI ĐOẠN 3)
3. `documents/05_Co_cau_To_chuc_Va_Triet_ly_He_thong.md` — cơ cấu tổ chức 17 mã vai

**Pipeline MCV3:** `.mc-data/docs/` (Phase 0-1 hoàn thành, Phase 2 dở) + `.mc-data/work/` (state, audit trail).

### 2. Nhiệm vụ audit (4 phần, độc lập nhau)

**Phần A — Kiểm bộ gốc với 3 nguồn gốc.**
- Cấu trúc: đủ 11 file theo danh mục README §2; Mermaid render được; đánh số mục trong file cross-ref đúng (vd file 01 nhắc "02 §6", "06 §5" — mở đúng chỗ có nội dung tương ứng).
- Nội dung: trích ngẫu nhiên **tối thiểu mỗi giai đoạn 5 sự kiện** (tổng ≥ 25: stage, SLA, gate, hằng số, RACI) từ các file 02–06, 08, 09 và đối chiếu về nguồn tương ứng (v2.3 HTML — dùng tìm kiếm chuỗi trong file HTML; V6.0; documents/05). Ghi VERDICT từng mẫu: MATCH / MISMATCH / SOURCE-NOT-FOUND / TAGGED-KXN (đã gắn thẻ KXN là hành vi đúng, không tính lỗi).
- Độ phủ KXN: quét 2 nguồn tìm mâu thuẫn/giá trị chưa định nghĩa **chưa** được gắn `[KXN-n]` nào trong bộ gốc — nếu phát hiện mâu thuẫn mới chưa gắn thẻ → finding.
- Bộ đếm: xác minh các con số tuyên bố (72 entry = 33 + 39; 20 KXN với 6 P0; 11 file; 33/39 key og trong `coverage-check.js`).

**Phần B — Kiểm tính chính xác các tham chiếu từ `.mc-data` sang bộ gốc.**
Các điểm tham chiếu hợp lệ (từ tiền phiên): `phase0-brainstorm/policies/stage-gate-lifecycle-v6.md` §2.3 + mục Lịch Sử Phiên Bản 1.1; `phase1-business/stakeholder-review.md` Phần F.4; `work/audit-documents-alignment-20260912.md` §7 + §8; `work/wf-analyze-requirements/deferred-issues.md` DI-002/DI-003 (ghi chú) + DI-008; `work/wf-define-features/define-features-status.json` (+ mirror session) `context_sources.process_docs`; `work/wf-define-features/sessions/20260912-112934-6bcf/checkpoint.json`. Với mỗi điểm: mở file bộ gốc bị dẫn tới, xác nhận nội dung khớp và không bị trích sai chiều. Đối chiếu `work/lifecycle-v23/DATA-extract.json` (72 entry) với file 01/08/09 ít nhất 3 entry.

**Phần C — Kiểm nhất quán tầng trạng thái pipeline (khả năng resume Phase 2).**
- `define-features-status.json` (top + session mirror) ↔ `session-state.json` ↔ `checkpoint.json` ↔ `latest` pointer: cùng vị trí (phase1-scope-mapping), cùng trạng thái P0/P0.5 completed, gate override CDG-A02.
- `phase1-handoff.json`: `deferred_issues_file` + `stakeholder_review_file` trỏ đúng file tồn tại; DI-008 hiển thị đủ 6 KXN P0 đúng mã (1, 2, 5, 8, 10, 11).
- `req-registry.json`: KHÔNG được có dấu hiệu sửa tay từ thời điểm sau run Phase 1 (kiểm git không khả dụng do gitignored — thay bằng: schema validate + counters khớp `docs_reqs.txt`; 59 REQ / 19 modules / 18 roles).

**Phần D — Kiểm các cam kết "chưa làm" (đảm bảo không ai tự ý thực thi).**
- DI-002/AUD-01 **chưa được thực thi**: `phan-loai-khach-hang-tier.md` §2.2 và `stage-gate-lifecycle-v6.md` §2.1 vẫn còn 2 chiều mâu thuẫn nguyên vẹn (đây là trạng thái ĐÚNG — chờ stakeholder chốt KXN-1/KXN-8).
- Tiêu chí DEPLOY bảng 2.1 stage-gate policy **vẫn là bản đề xuất cũ** (chờ KXN-10).
- Không file nào trong `.mc-data/docs/phase2-features/` tồn tại (Phase 2 chưa chạy tiếp).

### 3. Phương pháp & ràng buộc (BẮT BUỘC)

- **Contract-driven:** kiểm cấu trúc phase docs theo `.claude/doc-framework/*/_contract.json`. Script sẵn có: `.mc-data/work/audit-structure-check.js` (read-only, chạy lại được).
- **KHÔNG dùng** `phase0-cross-check.sh` (script Eureka cũ, false positive — đã ghi nhận trong audit 12/09).
- **Môi trường Windows:** không có Python/jq; dùng `node -e` cho JSON; chạy bash script trực tiếp (không qua ps1 wrapper); path dạng forward-slash trong Bash.
- **Read-only với** `documents/`, `.claude/`, `.zcode/`, `docs/`. Nếu bắt buộc phải sửa JSON trong `.mc-data` để vá lỗi tìm thấy: tạo `.bak` kèm cạnh + validate JSON sau ghi + ghi rõ vào báo cáo. **Tuyệt đối không sửa tay `req-registry.json`** và **không chạy skill `wf-*`** trong phiên audit.
- Không phát sinh phạm vi ngoài bộ gốc — finding nào ngoài phạm vi chỉ ghi nhận ở mục "outside-scope observations", không tự xử lý.

### 4. Định dạng kết quả

Xuất báo cáo `.mc-data/work/audit-independent-<YYYYMMDD>.md` gồm:
1. **TL;DR** — bảng verdict 4 phần (A/B/C/D) + tổng PASS/FAIL.
2. **Findings** — mã `IND-xx` (severity Critical/High/Medium/Low/Info), mỗi finding: bằng chứng (path + dòng/trích dẫn), ảnh hưởng, đề xuất hành động, ai là người chốt (stakeholder hay fixable-by-auditor).
3. **Sample evidence** — bảng ≥ 25 mẫu Phần A với verdict từng mẫu.
4. **Ma trận KXN** — xác nhận 20 KXN còn mở đúng trạng thái; đánh dấu KXN nào nếu có đã được chốt (so với file 10 phiên bản hiện tại).
5. **Khuyến nghị pipeline** — sau audit, Phase 2 resume cần những quyết định nào (kỳ vọng: DI-001, DI-004, DI-005, DI-008 gồm 6 KXN P0), và có finding nào mới chặn không.

### 5. Bối cảnh các quyết định đã có (để không "mở lại" oan)

- DI-006 đã RESOLVED bằng cách stakeholder **TỪ CHỐI** vai OPS_CX/FIN_COMPL → registry 18 vai; CX Head → OPS_PLAN, Compliance → FIN_L2 + BOD oversight (stakeholder-review.md F.3).
- Gate Workload Phase 2: BLOCK 4.22×, user override **CDG-A02** (Plan B, full 19 modules ~190 phút).
- Bộ gốc dùng v2.3 làm chuẩn trình tự; mọi mâu thuẫn với V6.0 đều gắn `[KXN-n]` và tập hợp ở file 10 — đó là chủ đích, không phải thiếu nhất quán.

Hãy bắt đầu bằng việc đọc `documents/quy-trinh-lam-viec/README.md` rồi lập kế hoạch audit trước khi thực hiện; báo cáo kết quả theo mục 4.

## HẾT PROMPT
