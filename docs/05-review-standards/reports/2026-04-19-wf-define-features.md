# Rà soát skill: `wf-define-features` v2.1.0

> **Ngày:** 2026-04-19
> **Reviewer:** Claude Code (automated audit)
> **Tiêu chuẩn:** [`_template-common.md`](../_template-common.md) v1.0 + [`wf-define-features.md`](../wf-define-features.md) v1.0

---

## Tóm tắt

| Nhóm | PASS | PARTIAL | FAIL | N/A | Tổng áp dụng |
|------|------|---------|------|-----|-------------|
| A — Structural | 9 | 1 | 0 | 0 | 10 |
| B — Workflow Integrity | 5 | 0 | 2 | 3 | 7 |
| C — Output & Template | 6 | 1 | 0 | 0 | 7 |
| D — Cross-Skill | 2 | 2 | 0 | 0 | 4 |
| E — Protocol & CORE | 12 | 3 | 3 | 0 | 18 |
| F — Agent Delegation | 4 | 1 | 0 | 0 | 5 |
| H — Error Handling | 1 | 3 | 2 | 0 | 6 |
| I — Testability | 2 | 1 | 2 | 0 | 5 |
| J — Idempotency | 2 | 0 | 0 | 0 | 2 |
| G — Extension | 10 | 0 | 0 | 0 | 10 |
| CS — Cross-skill đặc thù | 4 | 1 | 0 | 0 | 5 |
| **Tổng** | **57** | **13** | **9** | **3** | **79** |

**Tỷ lệ PASS:** 72% (57/79) — kỹ năng có nền tảng tốt, cần khắc phục 3 vấn đề QUAN TRỌNG và 6 vấn đề TRUNG BÌNH.

---

## Phân loại phát hiện theo Mức độ nghiêm trọng

### QUAN TRỌNG (3 phát hiện)

#### E9-F1: `phase-summary.md` hoàn toàn thiếu — CORE-028 vi phạm

- **Ảnh hưởng:** Tất cả 9 giai đoạn tệp đều không tạo `phase-summary.md`. CORE-028 quy định BAT BUOC.
- **Bằng chứng:** Không có tài liệu tham khảo đến `phase-summary.md` hoặc CORE-028 trong bất kỳ tệp giai đoạn nào. `_shared.md` cũng không đề cập đến. Các kỹ năng khác (wf-verify-sync, wf-fix-execute) tạo hiện vật này đúng cách.
- **Gợi ý khắc phục:** Thêm bước tạo `phase-summary.md` vào cuối mỗi giai đoạn (trước ĐỊNH HƯỚNG TIẾP THEO), sử dụng mẫu `.claude/doc-framework/_meta/phase-summary.template.md`. Nội dung: tiếng Việt ≤15 dòng, phi chuyên môn.
- **Mức độ:** QUAN TRỌNG — vi phạm CORE rule BAT BUOC, phá vỡ khả năng quan sát liên kỹ năng.

#### E10-F2: `session-log.json` hoàn toàn thiếu — CORE-026 vi phạm

- **Ảnh hưởng:** Không có giai đoạn nào ghi NHẬT KÝ BẮT ĐẦU/HOÀN THÀNH/THẤT BẠI vào `.mc-data/work/_trace/session-log.json`. CORE-026 quy định BAT BUOC.
- **Bằng chứng:** Không có tài liệu tham khảo đến `session-log.json`, `_trace/` hoặc CORE-026 trong bất kỳ tệp wf-define-features nào. Protocol 15 định nghĩa định dạng chỉ thêm vào chính xác.
- **Gợi ý khắc phục:** Thêm bước ghi theo định dạng Protocol 15 vào đầu mỗi giai đoạn (NHẬT KÝ BẮT ĐẦU) và cuối mỗi giai đoạn (NHẬT KÝ HOÀN THÀNH/THẤT BẠI), trước ĐỊNH HƯỚNG TIẾP THEO.
- **Mức độ:** QUAN TRỌNG — vi phạm CORE rule BAT BUOC, không có dấu vết thực thi.

#### D-F3: `ui-manifest.json` không được khai báo trong `_contract.json`

- **Ảnh hưởng:** `00-core.md §4b` quy định rõ `/wf-legacy-scan` Giai đoạn 1 tạo `ui-manifest.json` được `wf-define-features` Giai đoạn 2.7 tiêu thụ. `_contract.json` KHÔNG liệt kê phụ thuộc này ở đâu — không phải trong `inputs[]` và không phải trong `cross_skill_contracts.consumes_from`.
- **Bằng chứng:** Giai đoạn 2.7 `phase2.7-ui-coverage.md` sử dụng `ui-manifest.json` trong logic ĐIỀU KIỆN BAN ĐẦU nhưng `_contract.json` không có tài liệu tham khảo đến `wf-legacy-scan` dưới dạng nhà sản xuất cho tệp này.
- **Gợi ý khắc phục:** Thêm vào `_contract.json`:
  ```json
  {
    "path": ".mc-data/work/legacy-scan/inventory/ui-manifest.json",
    "description": "UI manifest từ wf-legacy-scan Stage 1 — dùng cho UI coverage cross-check (Phase 2.7)",
    "required": false,
    "condition": "LEGACY_MODE only"
  }
  ```
  Và thêm `wf-legacy-scan` vào `consumes_from` với đường dẫn này.
- **Mức độ:** QUAN TRỌNG — hợp đồng cross-skill không hoàn chỉnh có thể gây thất bại âm thầm trong Giai đoạn 2.7.

---

### CAO (4 phát hiện)

#### H5-F4: Các phần "Khi Thất Bại" hoàn toàn thiếu

- **Ảnh hưởng:** Không có tệp giai đoạn nào có phần tiêu đề "Khi Thất Bại" chuyên dụng. Một số giai đoạn (3, 4) có xử lý thất bại nội tuyến nhưng không nhất quán.
- **Gợi ý khắc phục:** Thêm phần "### Khi Thất Bại" vào cuối mỗi tệp giai đoạn trước "Giai đoạn Tiếp theo", xác định: số lần thử lại, trình kích hoạt leo thang, định dạng thông báo người dùng.

#### H1-F5: Nhật ký lỗi có cấu trúc thiếu

- **Ảnh hưởng:** `define-features-status.json` mẫu có `error_log: []` nhưng không có bước giai đoạn nào thêm các mục có cấu trúc `{giai đoạn, mã_lỗi, thông_điệp, dấu_thời_gian, độ_phân_giải}`. Xử lý lỗi là không chính thức và phân tán.
- **Gợi ý khắc phục:** Thêm bước nội tuyến trong `_shared.md` định nghĩa hàm tiện ích thêm lỗi vào `error_log[]` trong tệp trạng thái. Tham chiếu từ các bước xử lý lỗi giai đoạn.

#### B4-F6: Cổng hậu trường không hoàn chỉnh ở nhiều giai đoạn

- **Ảnh hưởng:** Chỉ 3/9 giai đoạn có đầy đủ T1-T4. Giai đoạn 0.5 KHÔNG có kiểm tra bash (toàn bộ dạng kể chuyện). Giai đoạn 0, 1, 2, 2.7 thiếu kiểm tra T2 hoặc T4 rõ ràng.
- **Gợi ý khắc phục:** Tăng cường các phần CỔNG HẬU TRƯỜNG với các kiểm tra cụ thể:
  - Giai đoạn 0.5: Thêm `jq` xác minh trên `impl-status-snapshot.json` đọc
  - Các giai đoạn khác: Thêm T2 (kiểm tra cấu trúc tiêu đề) và T4 (tham chiếu chéo ID) ở những nơi thiếu.

#### B3-F7: Cổng điều kiện ban đầu của Giai đoạn 3 thụ động

- **Ảnh hưởng:** Giai đoạn 3 `phase3-cross-validation.md` ĐIỀU KIỆN BAN ĐẦU chứa chỉ bình luận như "# Giai đoạn 2 CỔNG HẬU TRƯỜNG ĐÃ XẢY RA" mà không có lệnh xác minh thực tế (`jq`/`grep`).
- **Gợi ý khắc phục:** Thêm `grep -q "Verdict cuoi: PASS" .mc-data/work/wf-define-features/cross-validation-report.md` hoặc kiểm tra `jq` tương đương.

---

### TRUNG BÌNH (8 phát hiện)

#### C1-F8: Trôi lệch tệp đầu ra giữa `SKILL.md` và `_contract.json`

- **Chi tiết:** `SKILL.md §Working Files` liệt kê 6 tệp làm việc. `_contract.json outputs.working[]` liệt kê 9 mục. Thiếu trong bảng `SKILL.md`: `deferred-findings.md`, `feature-briefs.json` (`_meta/` tiêu chuẩn), `ui-coverage-gaps.json` (đầu ra kế thừa).
- **Gợi ý khắc phục:** Đồng bộ hóa bảng `SKILL.md §Working Files` với `_contract.json`. Thêm các mục bị thiếu với ghi chú có điều kiện.

#### E6-F9: Độ bao phủ Cổng hậu trường không đồng nhất

- **Chi tiết:** Như B4-F6 nhưng được nhìn từ góc độ E6. Độ phủ T1-T4 không đồng nhất giữa các giai đoạn.

#### I2-F10: Các trường hợp đánh giá thiếu bao phủ chế độ KẾ THỪA + Giai đoạn 2.7

- **Chi tiết:** 3 trường hợp kiểm tra hiện có bao phủ: chế độ MỚI đơn giản, chế độ MỚI đơn giản khác và chế độ MỚI đa hệ thống. Không có trường hợp nào bao phủ: (a) chế độ KẾ THỪA, (b) Giai đoạn 2.7 phạm vi bao phủ giao diện người dùng, (c) xử lý sơ khai.
- **Gợi ý khắc phục:** Thêm 2-3 trường hợp kiểm tra: (1) Kế thừa với các mô-đun lỗi thời, (2) Phạm vi bao phủ giao diện người dùng với màn bản thể, (3) Xử lý sơ khai từ `add-scope`.

#### I3-F11: Thiếu các trường hợp kiểm tra biên

- **Chi tiết:** Không có trường hợp kiểm tra nào cho: tiếp tục sau gián đoạn, đầu vào trống (không có yêu cầu), dry-run, hoặc không có tệp tóm tắt phân tích yêu cầu.
- **Gợi ý khắc phục:** Thêm ít nhất 1 trường hợp kiểm tra biên (tiếp tục) và 1 trường hợp (đầu vào trống → thông báo DỪNG LẠI).

#### D1-F12: Trôi lệcdrift `produces_for` nhỏ (2 mục)

- **Chi tiết:** (1) `wf-plan-modules` tiêu thụ `feature-briefs.json` theo `_contract.json` nhưng không được liệt kê rõ ràng trong `00-core.md §4b` dưới dạng người tiêu thụ của đầu ra đó. (2) `wf-implement-feature` tiêu thụ trực tiếp thông số đặc tính tính năng theo `_contract.json` nhưng `§4b` chỉ hiển thị việc tiêu thụ gián tiếp thông qua các tệp tác vụ.
- **Gợi ý khắc phục:** Đồng bộ hóa — hoặc cập nhật `00-core.md §4b` để phản ánh `_contract.json`, hoặc ngược lại.

#### D2-F13: Trôi lệcdrift `consumes_from` nhỏ (2 mục)

- **Chi tiết:** (1) `wf-legacy-extract` liệt kê đường dẫn được tiêu thụ trong `_contract.json` nhưng `§4b` liệt kê người tiêu thụ là `wf-brainstorm`, không phải `wf-define-features`. (2) `wf-fix-bugs` so với quy ước đặt tên `wf-fix-execute` — `_contract.json` sử dụng tên bộ điều phối, `§4b` sử dụng tên phụ kỹ năng.
- **Gợi ý khắc phục:** Sử dụng tên phụ kỹ năng nhất quán `wf-fix-execute` trong `_contract.json consumes_from` để khớp với `§4b`.

#### F3-F14: Các lời nhắc tác nhân thiếu kỳ vọng Cổng hậu trường

- **Chi tiết:** Cả 3 mẫu ngữ cảnh tác nhân trong `_shared.md` (BA Giai đoạn 2, BA Giai đoạn 4, PE Giai đoạn 4) bao gồm: các đường dẫn ĐẦU VÀO, các đường dẫn ĐẦU RA, các kỳ vọng chất lượng, tài liệu tham khảo mẫu. Không có mẫu nào bao gồm tiêu chí thành công CỔNG HẬU TRƯỜNG của giai đoạn gọi (ví dụ: "tệp đầu ra của bạn phải vượt qua Xác minh T1-T4").
- **Gợi ý khắc phục:** Thêm "Tiêu chí thành công" ngắn vào mỗi mẫu tác nhân với các kiểm tra CỔNG HẬU TRƯỜNG chính.

#### A7-F15: `SKILL.md` chứa logic điều phối cụ thể

- **Chi tiết:** `SKILL.md §Phase 0` có mã giả định tuyến giống bash (BƯỚC 1/2/3 với `LEGACY_MODE = test -f ...`). Mặc dù đây là logic điều hướng (không phải bước thực thi chi tiết), nó vi phạm tinh thần của A7 ("không có mã/giọng nói cụ thể trong `SKILL.md`").
- **Mức độ:** Thấp — logic điều hướng hợp lý ở cấp `SKILL.md` nhưng nên là tham chiếu đến `phase0-context.md` thay vì mã giả nội tuyến.

---

### THẤP (2 phát hiện)

#### H2-F16: Chế độ ghi nguyên tử không được thực thi rõ ràng

- **Chi tiết:** `_shared.md` đề cập "ghi đè nguyên tử" nhưng không có mẫu `tmp + mv` rõ ràng. Các kỹ năng khác sử dụng rõ ràng mẫu ghi tạm thời.
- **Gợi ý khắc phục:** Thêm hướng dẫn ghi nguyên tử rõ ràng vào phần `§Registry Safe-Write` của `_shared.md`.

#### A9-F17: Tiếng Anh thỉnh thoảng tràn vào tài liệu hướng dẫn

- **Chi tiết:** Một số tiêu đề phần và mô tả trong `_shared.md` và các tệp giai đoạn sử dụng tiếng Anh thay vì tiếng Việt (ví dụ: "Stub Detection & Flesh-out Rules", "Scan Method Selection", "WARN Triage Decision"). CORE-005 yêu cầu tài liệu bằng tiếng Việt.
- **Gợi ý khắc phục:** Chuyển các tiêu đề phần thành tiếng Việt trong khi giữ tên tiếng Anh cho các mã/biến.

---

## Ma trận chi tiết: Pass 1-5

### Pass 1 — Tuân thủ tĩnh (A1-A10, C1-C7)

| ID | Tiêu chuẩn | Kết quả | Bằng chứng |
|----|------------|---------|-----------|
| **A1** | Tiền liệu YAML hợp lệ | **PASS** | 7 trường bắt buộc có mặt: name, version, last_updated, description, argument-hint, disable-model-invocation, allowed-tools |
| **A2** | `_contract.json` v1 schema | **PASS** | `$schema: "skill-contract-v1"` + tất cả các trường bắt buộc có mặt |
| **A3** | Phiên bản đồng bộ `SKILL.md` ↔ `contract` | **PASS** | Cả hai: `2.1.0` |
| **A4** | `disable-model-invocation: true` | **PASS** | Tiền liệu dòng 39 |
| **A5** | `allowed-tools` khớp với sử dụng thực tế | **PASS** | 8 công cụ: Đọc, Toàn cầu, Tìm kiếm, Bash, Viết, Chỉnh sửa, Tác nhân, ViếtViệcCầnLàm — tất cả được sử dụng |
| **A6** | Cấu trúc thư mục | **PASS** | Có: `SKILL.md`, `_contract.json`, `procedures/` (10 tệp), `templates/` (5 tệp), `evals/evals.json` |
| **A7** | `SKILL.md` không có bước thực thi | **PARTIAL** | Mã giả định tuyến Giai đoạn 0 nội tuyến — xem F15 |
| **A8** | Tệp thủ tục tồn tại khớp sơ đồ định tuyến | **PASS** | 10 tệp thủ tục khớp với bản đồ định tuyến + `_contract.json procedure_files` |
| **A9** | Tài liệu tiếng Việt, mã tiếng Anh | **PASS** | Nhìn chung tốt; xem F17 cho các trường hợp ngoại lệ nhỏ |
| **A10** | `evals.json` ≥ 3 trường hợp kiểm tra | **PASS** | 3 trường hợp kiểm tra |
| **C1** | Bảng Tệp Đầu ra đồng bộ | **PARTIAL** | Xem F8 — `SKILL.md` liệt kê 6 mục làm việc, `_contract.json` có 9 |
| **C2** | Các mục mẫu=null có ghi chú | **PASS** | 2 mục null (báo cáo xác thực chéo, báo cáo đặc tính) đều có giải thích nội tuyến |
| **C3** | Các tệp mẫu tồn tại | **PASS** | 5 mẫu cục bộ + 4 mẫu bên ngoài — tất cả đều tồn tại và hợp lệ |
| **C4** | Mẫu ĐỌC→ĐIỀN→VIẾT | **PASS** | Giai đoạn tham chiếu mẫu; `_shared.md` mẫu tác nhân bao gồm refs mẫu |
| **C5** | Đầu ra có điều kiện có bảo vệ | **PASS** | `ui-coverage-gaps.json`: điều kiện + bắt buộc: sai + bảo vệ Giai đoạn 2.7 |
| **C6** | Đầu ra tập lệnh có tài liệu tham khảo schema | **PASS** | Các mục null mẫu có ghi chú trỏ đến schema nội tuyến |
| **C7** | Các tệp mẫu tự hợp lệ | **PASS** | Tất cả 5 JSON phân tích cú pháp đúng; mẫu MD có trình giữ chỗ |

### Pass 2 — Logic & Luồng (B1-B8, F1-F4)

| ID | Tiêu chuẩn | Kết quả | Bằng chứng |
|----|------------|---------|-----------|
| **B1** | Sơ đồ định tuyến đầy đủ | **PASS** | `_shared.md §Phase Ordering` + mỗi giai đoạn có "Giai đoạn tiếp theo" |
| **B2** | Mỗi giai đoạn tự chứa (6 phần) | **PASS** | 9/9 giai đoạn có ĐIỀU KIỆN BAN ĐẦU, ĐẦU VÀO, Các bước, ĐẦU RA, CỔNG HẬU TRƯỜNG, Giai đoạn tiếp theo |
| **B3** | Điều kiện ban đầu pháp y | **FAIL** | Giai đoạn 3 thụ động — xem F7 |
| **B4** | Cổng hậu trường T1-T4 | **FAIL** | 3/9 hoàn toàn, 5/9 một phần, 1/9 thất bại — xem F6 |
| **B5** | Bảo vệ giai đoạn có điều kiện | **PASS** | Giai đoạn 0.5, 2.5, 2.7 đều có trả về sớm rõ ràng |
| **B7** | Trạng thái/tiếp tục xử lý trước Giai đoạn 0 | **PASS** | `phase0-context.md` các dòng 37-66 |
| **B8** | Quy tắc chuyển tiếp | **PASS** | Trạng thái hỗ trợ chờ xử lý → đang tiến hành → hoàn thành/thất bại |
| **F1** | Giai đoạn xác định không tạo tác nhân | **PASS** | Giai đoạn 0, 0.5, 1, 2.5, 2.7, 3, 5 — không có lệnh gọi Tác nhân |
| **F2** | Loại phụ tác nhân đúng | **PASS** | Giai đoạn 2: business-analyst; Giai đoạn 4: business-analyst + product-expert |
| **F3** | Các mẫu lời nhắc tác nhân | **PARTIAL** | Các mẫu trong `_shared.md` thiếu tiêu chí thành công CỔNG HẬU TRƯỜNG — xem F14 |
| **F4** | Bối cảnh chính xác nhận đầu ra tác nhân | **PASS** | CỔNG HẬU TRƯỜNG chạy sau khi tác nhân hoàn thành ở cả Giai đoạn 2 và 4 |

### Pass 3 — Hợp đồng & Giao thức (D1-D4, E1-E18)

| ID | Tiêu chuẩn | Kết quả | Bằng chứng |
|----|------------|---------|-----------|
| **D1** | `produces_for` khớp `§4b` | **PARTIAL** | 2 trôi lệch nhỏ — xem F12 |
| **D2** | `consumes_from` khớp với nhà sản xuất | **PARTIAL** | 1 trôi lệch vừa + 1 trôi lệch nhỏ — xem F3, F13 |
| **D3** | Đường dẫn tuyệt đối & ổn định | **PASS** | Tất cả đường dẫn tương đối với `.mc-data/` |
| **D4** | Số lượng tài liệu tham khảo chéo khớp hồ sơ | **PASS** | 4 nhà sản xuất, 4 người tiêu thụ — khớp với hồ sơ |
| **E1** | Đảm bảo độ chính xác | **PASS** | Giai đoạn 3 vòng lặp tự động sửa chữa tối đa 3 lần |
| **E2** | Tự động sửa chữa | **PASS** | Quy tắc sửa chữa trong `_shared.md §Fix Rules` |
| **E3** | Bối cảnh & Điểm kiểm tra | **PASS** | Mẫu điểm kiểm tra, `_shared.md §Token Budget` |
| **E4** | Ngăn chặn Giới hạn Mã thông báo | **PASS** | Ngưỡng mã thông báo trong `_shared.md`, ngữ cảnh tác nhân bị giới hạn |
| **E5** | Lập kế hoạch tác vụ | **PASS** | ViếtViệcCầnLàm trong các công cụ được cho phép |
| **E6** | Cổng hậu trường T1-T4 | **PARTIAL** | Không đồng nhất — xem F6, F9 |
| **E7** | Điều kiện ban đầu pháp y | **FAIL** | Giai đoạn 3 bị động — xem F7 |
| **E8** | Cổng quyết định quan trọng | **PASS** | Cổng an toàn ghi sổ đăng ký Giai đoạn 5 |
| **E9** | Tóm tắt giai đoạn | **FAIL** | Hoàn toàn thiếu — xem F1 |
| **E10** | Dấu vết thực thi | **FAIL** | Hoàn toàn thiếu — xem F2 |
| **E11** | Kiểm tra điểm đầu ra tác nhân | **PASS** | CỔNG HẬU TRƯỜNG Giai đoạn 2 và 4 xác nhận đầu ra tác nhân |
| **E12** | Cách ly phiên | **N/A** | `is_multi_run: false` |
| **E13** | Quy tắc sử dụng mẫu | **PASS** | Bảng mẫu trong `SKILL.md`, các giai đoạn tham chiếu mẫu |
| **E14** | Thứ tự ưu tiên | **PASS** | Chất lượng đầu tiên được nêu rõ ràng |
| **E15** | Ghi an toàn sổ đăng ký | **PASS** | Giai đoạn 5 `phase5-registry-update.md` có giao thức ghi an toàn |
| **E16** | Vai trò sổ đăng ký đúng | **PASS** | CHÍNH cho features[], CẬP NHẬT AN TOÀN cho `impl_status` — khớp với `§4a` |
| **E17** | Phát hiện chế độ kế thừa | **PASS** | Sử dụng `project-context.md` > 500 byte (CORE-021) |
| **E18** | Cầu quyết định kế thừa | **PASS** | `_shared.md` có chèn bối cảnh + giảm cấp duyên dáng |

### Pass 4 — Thời gian chạy & Lỗi (H1-H5, I1-I5, J1-J2)

| ID | Tiêu chuẩn | Kết quả | Bằng chứng |
|----|------------|---------|-----------|
| **H1** | Nhật ký lỗi có cấu trúc | **PARTIAL** | Mẫu có `error_log: []`, mã lỗi E000-E011 trong `_shared.md` — nhưng không có bước nối thêm — xem F5 |
| **H2** | Ghi trạng thái nguyên tử | **PARTIAL** | Được đề cập trong `_shared.md` nhưng không có mẫu `tmp + mv` rõ ràng — xem F16 |
| **H3** | Tóm tắt có dấu thời gian | **PASS** | Các mẫu trạng thái và tóm tắt có `generated_at` ISO-8601 |
| **H4** | Xả điểm kiểm tra sau mỗi giai đoạn | **PASS** | `_shared.md §Token Budget` xác định tần suất điểm kiểm tra |
| **H5** | Phần Khi Thất Bại | **FAIL** | Không có phần chuyên dụng trong bất kỳ giai đoạn nào — xem F4 |
| **I1** | Đánh giá ≥ 3 | **PASS** | 3 trường hợp kiểm tra |
| **I2** | Bao phủ nhánh | **PARTIAL** | Không có chế độ KẾ THỪA, Giai đoạn 2.7, hoặc trường hợp kiểm tra sơ khai — xem F10 |
| **I3** | Các trường hợp biên | **FAIL** | Không có trường hợp tiếp tục, đầu vào trống, hoặc dry-run — xem F11 |
| **I4** | Khẳng định schema đầu ra | **PASS** | Các kiểu `file_content` + `file_exists` được sử dụng |
| **I5** | Kiểm tra khói chạy nội bộ | **N/A** | Không thể xác minh mà không thực thi |
| **J1** | Chạy lại ghi đè an toàn | **PASS** | Mẫu trạng thái hỗ trợ đặt lại |
| **J2** | Tiếp tục không trùng lặp | **PASS** | Thứ tự giai đoạn + hòa giải điểm kiểm tra ngăn chặn việc chạy lại |

### Pass 5 — Phần mở rộng (G1-G10, CS1-CS5)

| ID | Tiêu chuẩn | Kết quả | Bằng chứng |
|----|------------|---------|-----------|
| **G1** | `feature-briefs.json` sơ đồ kép | **PASS** | Mẫu làm việc (`feat_id`) vs. tiêu chuẩn (`feature_id`) — có chủ ý, được tài liệu hóa trong mẫu `_comment` |
| **G2** | Phát hiện sơ khai | **PASS** | `_shared.md §Stub Detection` có lệnh `grep` + logic xử lý sơ khai |
| **G3** | Gieo `impl_status` 1 lần Giai đoạn 0.5 | **PASS** | Bảo vệ kế thừa + lũy đẳng + không cập nhật sau |
| **G4** | Ánh xạ đặc tính Giai đoạn 2.5 | **PASS** | Tạo `feat-mapping.json` cho chế độ KẾ THỪA |
| **G5** | Bảo vệ điều kiện giao diện người dùng Giai đoạn 2.7 | **PASS** | Bảo vệ ba lần: KẾ THỪA + `ui-manifest` + `screens > 0` |
| **G6** | Khác biệt đặt tên tệp MỚI vs KẾ THỪA | **PASS** | Được tài liệu hóa trong `SKILL.md §File Naming Difference` |
| **G7** | Tự động sửa chữa chéo Giai đoạn 3 | **PASS** | Tối đa 3 lần lặp, 4 loại sửa chữa |
| **G8** | Đánh giá các bên liên quan Giai đoạn 4 | **PASS** | 4 phần (A-D) với việc leo thang sau 3 vòng |
| **G9** | Ghi an toàn Giai đoạn 5 2 quyền hạn | **PASS** | CHÍNH cho features[], CẬP NHẬT AN TOÀN cho `impl_status` |
| **G10** | Bao phủ giao diện người dùng 4 loại | **PASS** | ĐƯỢC BAO PHỦ/CƠ SỞ HẠ TẦNG/KHOẢNG TRỐNG/MƠ HỒ trong mẫu |
| **CS1** | Nhà sản xuất sơ khai 4 → giai đoạn 2 | **PASS** | `add-scope` + `fix-bugs` sơ khai được xử lý trong `_shared.md` |
| **CS2** | `ui-coverage-gaps.json` được chia sẻ | **PASS** | `produces_for` liệt kê `wf-design-ux` + `wf-plan-modules` |
| **CS3** | `feature-briefs.json` tiêu chuẩn sử dụng mẫu `_digests/` | **PASS** | `_meta/` đường dẫn với mẫu tiêu chuẩn |
| **CS4** | `impl-status-snapshot.json` CHỈ ĐỌC | **PARTIAL** | Được tiêu thụ ở Giai đoạn 0.5 nhưng `wf-legacy-scan` không nằm trong `cross_skill_contracts.consumes_from` |
| **CS5** | Đường dẫn người tiêu thụ giữ chỗ | **PASS** | `[sys-slug]/[mod-slug]/[feat-slug].md` mẫu được sử dụng |

---

## Kiểm tra nhanh (§6 mẫu chung)

- [x] A1: Tiền liệu đủ 7 trường
- [x] A2: `_contract.json` phân tích cú pháp đúng
- [x] A3: Phiên bản `SKILL.md` = phiên bản `contract`
- [x] A6: Cấu trúc thư mục chuẩn
- [x] A10: `evals/evals.json` ≥ 3 trường hợp kiểm tra
- [x] C3: Các mẫu tồn tại (tất cả 5 cục bộ + 4 bên ngoài)
- [x] D1: `produces_for` khớp `§4b` (trôi lệch nhỏ)
- [ ] E6: CỔNG HẬU TRƯỜNG T1-T4 (3/9 hoàn toàn, cần cải thiện)
- [x] E16: Vai trò sổ đăng ký khớp `§4a`

---

## Khuyến nghị hành động (ưu tiên)

| Ưu tiên | Phát hiện | Nỗ lực | Rủi ro |
|--------|-----------|--------|--------|
| 1 | E9-F1: Thêm `phase-summary.md` cho mỗi giai đoạn | ~2h | Vi phạm BAT BUOC |
| 2 | E10-F2: Thêm ghi `session-log.json` cho mỗi giai đoạn | ~1h | Vi phạm BAT BUOC |
| 3 | D-F3: Thêm `ui-manifest.json` vào `_contract.json` | ~15m | Thất bại âm thầm trong Giai đoạn 2.7 |
| 4 | H5-F4: Thêm phần "Khi Thất Bại" cho mỗi giai đoạn | ~2h | Tính mạnh mẽ |
| 5 | B4-F6: Tăng cường T1-T4 CỔNG HẬU TRƯỜNG | ~2h | Chất lượng đầu ra |
| 6 | C1-F8: Đồng bộ hóa bảng Tệp Đầu ra `SKILL.md` | ~30m | Tính nhất quán tài liệu |
| 7 | I2-F10, I3-F11: Thêm trường hợp kiểm tra biên/kế thừa | ~1h | Bao phủ kiểm tra |
| 8 | H1-F5: Thêm mẫu nối thêm nhật ký lỗi | ~30m | Khả năng quan sát |

---

## Tệp tham chiếu

| Tệp | Vai trò |
|------|--------|
| [SKILL.md](../../.claude/skills/workflow/wf-define-features/SKILL.md) | Tổng quan kỹ năng |
| [_contract.json](../../.claude/skills/workflow/wf-define-features/_contract.json) | Hợp đồng |
| [procedures/](../../.claude/skills/workflow/wf-define-features/procedures/) | 10 tệp giai đoạn + `_shared.md` |
| [templates/](../../.claude/skills/workflow/wf-define-features/templates/) | 5 mẫu |
| [evals/evals.json](../../.claude/skills/workflow/wf-define-features/evals/evals.json) | 3 trường hợp kiểm tra |
| [00-core.md](../../.claude/rules/00-core.md) | Quy tắc CORE |
| [wf-define-features.md](../wf-define-features.md) | Tiêu chuẩn đánh giá |
| [_template-common.md](../_template-common.md) | Tiêu chuẩn chung |
