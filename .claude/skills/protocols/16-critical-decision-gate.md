<!-- From shared-protocols.md lines 1175-1311 (§16) -->
# Protocol 16 — Critical Decision Gate Protocol (BẮT BUỘC — MỌI SKILL)

> Người không chuyên không thể tự phát hiện AI quyết định sai.
> Hành động KHÔNG THỂ UNDO phải có xác nhận trước khi thực thi.

## 16.1 Danh sách Critical Decision Points

| ID | Hành động | Skill liên quan | Yêu cầu |
|----|-----------|-----------------|----------|
| CDG-01 | DEPRECATE hoặc loại module khỏi scope | wf-brainstorm (legacy), wf-add-scope | Hiển thị modules bị ảnh hưởng + hỏi user xác nhận |
| CDG-02 | Overwrite file đã tồn tại có nội dung | Mọi skill có Write operation | Hiển thị file path + hỏi user |
| CDG-03 | Thay đổi impl_status từ "done" → giá trị khác | wf-verify-sync, wf-fix-execute | Hiển thị REQ-ID + status cũ/mới + hỏi user (bổ sung CORE-008) |
| CDG-04 | Xóa hoặc rename REQ-ID/FEAT-ID đã tồn tại | Mọi skill có registry write | Hiển thị ID + dependencies + hỏi user |
| CDG-05 | Chuyển phase khi có HIGH/CRITICAL findings PENDING | Mọi skill có Stakeholder Review | Hiển thị findings + chỉ cho ACCEPT (fix trước) hoặc REDO phase — KHÔNG cho DEFER bypass |
| CDG-06 | Destructive mutation trên database (password reset, INSERT admin, schema change, UPDATE production data) | wf-fix-execute (auto-login 4 giai đoạn), mọi skill ghi DB trực tiếp | Hiển thị SQL + target DB + env_type + hậu quả + cleanup instructions → hỏi user (xem §16.4 message template CDG-06) |
| CDG-07 | Gọi external service gây side-effect không hoàn tác (email send, payment trigger, external API write với billing impact) | Mọi skill tương tác external | Hiển thị endpoint + payload + cost estimate → hỏi user |
| CDG-08 | Pre-Implementation Safety Check có blockers (collision, uncommitted, deprecated, xref fail) | `/wf-fix-bugs` Step 2.6 | Hiển thị 4-check kết quả (collision, xref, uncommitted, deprecated) + hỏi user resolve hoặc override |
| CDG-09 | CQG Hard-Enforce Override — E001 numeric metric mismatch >5% sau 3 retries | `/wf-fix-execute` Phase 6 CQG | Hiển thị mismatch chi tiết (expected vs actual) + hỏi user accept (override) | reject (quay lại Phase 6) | modify (manual adjust) |
| CDG-10 | Auto-fix Iteration Cap Override — MAX_ITERATIONS=3 đạt với HIGH issues còn lại | `/wf-fix-execute` Phase 3 | Hiển thị danh sách HIGH issues còn lại + hỏi user grant 1 iteration nữa (absolute max=4) | stop |
| CDG-11 | Workload Budget Override — workload ratio > 1.5 và user chọn option 4 (override) tại Workload Gate | `/wf-fix-bugs` Step 1.5 + Step 2.5 re-confirm | Hiển thị workload ratio + threshold + density factor + hỏi user xác nhận lần 2 (defense-in-depth) hoặc downgrade scope/profile |
| CDG-12 | Full-scan khi project có nhiều modules (>20) với `--scope=all` | `/wf-fix-bugs` Phase 0 Step 4.6 | Hiển thị module count + thời gian ước tính + top 5 module IDs + suggest `--scope=module` hoặc `--since=HEAD~10` → hỏi user |
| CDG-13 | Chi phí ước tính vượt ngưỡng $5.00 trước khi spawn probe lanes | `/wf-fix-bugs` Phase 0 Step 4.7 | Hiển thị estimate_usd + profile + dims breakdown → hỏi user tiếp tục / hạ profile / huỷ |

## 16.2 Confirmation Flow

TRƯỚC KHI THỰC THI HÀNH ĐỘNG CRITICAL:
1. Detect: Kiểm tra hành động có thuộc CDG-01..07 không
2. Display: Hiển thị cho user bằng tiếng Việt (xem §16.4 message templates)
   - Mô tả hành động sắp thực hiện
   - Dữ liệu bị ảnh hưởng (tên file, REQ-ID, module name)
   - Hậu quả nếu thực hiện
   - Nếu CDG-02: hiển thị tóm tắt thay đổi (before/after diff)
3. Ask: Hỏi user xác nhận
4. Execute: Chỉ thực hiện khi user xác nhận
5. Log: Ghi quyết định vào session-log.json nếu có (Protocol 15), hoặc ghi trong conversation

### 16.2.1 Rejection Behavior (BẮT BUỘC)

Khi user TỪ CHỐI xác nhận CDG:

| CDG | Hành vi khi user từ chối | Giải thích cho user |
|-----|--------------------------|---------------------|
| CDG-01 | SKIP module đó, tiếp tục với modules còn lại | "Module [name] sẽ giữ nguyên. Tiếp tục xử lý các module khác." |
| CDG-02 | KHÔNG ghi đè file, SKIP thao tác đó, tiếp tục skill | "File [name] sẽ giữ nguyên nội dung hiện tại." |
| CDG-03 | GIỮ NGUYÊN impl_status cũ, LOG warning | "Trạng thái [REQ-ID] giữ nguyên là [old_status]." |
| CDG-04 | HỦY thao tác xóa/rename, DỪNG skill nếu là thao tác bắt buộc | "REQ-ID [id] không bị thay đổi. [Tiếp tục/Dừng skill.]" |
| CDG-05 | DỪNG chuyển phase, hiển thị lại findings để user xử lý | "Phase hiện tại chưa hoàn thành do còn [N] vấn đề chưa giải quyết." |
| CDG-06 | SKIP destructive DB mutation, fallback sang phương án ít destructive hơn hoặc LOG error | "Không thay đổi DB. Fallback: [tên phương án] hoặc dừng flow." |
| CDG-07 | HỦY gọi external service, LOG reason, skill tiếp tục ở chế độ dry | "Không gọi [service]. Skill tiếp tục không có side-effect bên ngoài." |
| CDG-08 | DỪNG execute, LOG từng blocker riêng, hỏi user resolve hay skip từng cái | "Safety check phát hiện [N] vấn đề. Bạn muốn giải quyết từng cái hay bỏ qua?" |
| CDG-09 | KHÔNG advance phase_6.status, quay lại Phase 6 sửa fix-report.md | "Chỉ số CQG chưa khớp. Cần sửa lại fix-report.md trước khi hoàn thành." |
| CDG-10 | DỪNG fix loop, move remaining HIGH issues → ESCALATE bucket | "Đã đạt giới hạn 3 lần sửa. Các vấn đề còn lại được chuyển sang danh sách cần xem xét thủ công." |
| CDG-11 | HỦY override, quay về Workload Gate menu (E024 Aborted), gợi ý user thu hẹp scope/profile | "Workload vượt ngưỡng và bạn không xác nhận override. Hãy chọn lại: thu hẹp scope, hạ profile, hoặc bỏ bớt dimensions." |
| CDG-12 | DỪNG workflow (E099), hiển thị hướng dẫn re-run với scope hẹp hơn | "Full-scan đã dừng. Re-run với scope hẹp hơn để tiết kiệm thời gian và chi phí." |
| CDG-13 | DỪNG workflow (E100), hiển thị hướng dẫn re-run với profile thấp hơn | "Chi phí ước tính vượt ngưỡng. Re-run với `--profile=standard` để giảm chi phí." |

QUY TẮC CHUNG:
- KHÔNG hỏi lại cùng một CDG cho cùng dữ liệu trong cùng session
- Log rejection vào session-log (event: CDG_REJECTED)
- Nếu user từ chối CDG-05 3 lần liên tiếp → DỪNG skill, ghi FAILED phase-summary

## 16.3 Quy tắc

QUY TẮC:
1. CDG KHÔNG áp dụng cho auto-fix trong Auto-Correction Loop (Protocol 2) — chỉ cho hành động user-facing
2. CDG-02 kiểm tra: file tồn tại VÀ `test -s "$file"` (size > 0 bytes) → ALWAYS ASK. Whitespace-only files (chỉ spaces/newlines) cũng trigger nếu `test -s` pass. Không đếm số dòng.
3. CDG-05 KHÔNG cho phép DEFER bypass — tuân thủ CORE-012 (POST-GATE phải pass T1-T4)
4. Skills CÓ THỂ thêm CDG riêng — đăng ký tại bảng §16.1
5. CDG confirmation KHÔNG đếm vào iteration count của Auto-Correction Loop
6. **Decision Fatigue Mitigation (BẮT BUỘC):**
   - **CDG-02 Batch Accept:** Khi 1 skill cần overwrite nhiều files trong cùng 1 phase, hỏi 1 lần với danh sách đầy đủ + option "Đồng ý tất cả". User chọn "Đồng ý tất cả" → các files còn lại trong phase đó tự động accept.
   - **CDG-03 Batch Confirm:** Thay vì hỏi từng REQ-ID, nhóm lại thành 1 prompt: "AI muốn thay đổi trạng thái [N] yêu cầu sau..." — user confirm tất cả cùng lúc. Chỉ tách riêng nếu các REQ-ID có lý do khác nhau.
   - **Same-session, same-type dedup:** KHÔNG hỏi lại cùng loại CDG cho cùng pattern trong cùng session (đã cover bởi §16.2.1 quy tắc chung).

## 16.4 User Communication Templates (BẮT BUỘC)

Mẫu message hiển thị cho user — viết bằng tiếng Việt, KHÔNG dùng thuật ngữ kỹ thuật:

**CDG-01 (Loại module):**
```
⚠️ AI dự định loại module "[module-name]" khỏi dự án.
Lý do: [lý do bằng tiếng Việt]

Modules bị ảnh hưởng: [danh sách]
Yêu cầu liên quan sẽ bị xóa: [N] yêu cầu

Bạn có muốn loại module này không? (Có / Không)
```

**CDG-02 (Ghi đè file):**
```
⚠️ AI sắp cập nhật file "[tên file]" — file này đã có nội dung từ trước.

Thay đổi dự kiến:
- Thêm: [mô tả ngắn gọn nội dung mới]
- Sửa: [mô tả ngắn gọn nội dung bị thay đổi, nếu có]
- Giữ nguyên: [nội dung không đổi, nếu có]

Bạn có muốn tiếp tục cập nhật không? (Có / Không)
```

**CDG-03 (Thay đổi impl_status):**
```
⚠️ AI dự định thay đổi trạng thái yêu cầu "[REQ-ID]" từ "[trạng thái cũ]" sang "[trạng thái mới]".

Lý do: [lý do bằng tiếng Việt]

Bạn có đồng ý thay đổi không? (Có / Không)
```

**CDG-04 (Xóa/rename REQ-ID):**
```
⚠️ AI dự định [xóa/đổi tên] mã yêu cầu "[REQ-ID]".

Yêu cầu liên quan: [danh sách REQ-IDs phụ thuộc]

Bạn có muốn thực hiện không? (Có / Không)
```

**CDG-05 (Chuyển phase có findings pending):**
```
⚠️ AI phát hiện [N] vấn đề chưa giải quyết trước khi chuyển sang bước tiếp theo:

Bạn đang ở: [Tên bước hiện tại — VD: "Phân tích yêu cầu"]
Chuyển sang: [Tên bước tiếp theo — VD: "Đặc tả tính năng"]

Các vấn đề chưa giải quyết:
1. [Mô tả vấn đề 1 bằng tiếng Việt] — Mức độ: [CAO/TRUNG BÌNH]
2. [Mô tả vấn đề 2 bằng tiếng Việt] — Mức độ: [CAO/TRUNG BÌNH]

Bạn có 2 lựa chọn:
- "Sửa trước" — AI sẽ xử lý từng vấn đề trên, sau đó tự động tiếp tục sang bước tiếp theo
- "Làm lại bước này" — Quay lại [tên bước hiện tại] từ đầu (kết quả các bước TRƯỚC đó được giữ nguyên)

Lưu ý: Bạn không thể bỏ qua các vấn đề này — đây là quy định bảo vệ chất lượng dự án.

Bạn chọn gì?
```

## 16.5 Mối quan hệ với protocol hiện tại

| CDG | Bổ sung cho | Không mâu thuẫn với |
|-----|-------------|---------------------|
| CDG-01 | CORE-022 (Legacy Decisions Bridge) | — |
| CDG-02 | CORE-020 (Pre-Implementation Safety Gate) | — |
| CDG-03 | CORE-008 (verify-sync safe-update) | — |
| CDG-04 | CORE-006 (Registry Safe-Write) | — |
| CDG-05 | Protocol 4 Stakeholder Review | CORE-012 (POST-GATE enforcement) |
