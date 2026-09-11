# Nguyên Tắc Phát Triển MCV3

> Khung ưu tiên vận hành cho MCV3 để Claude, Codex và người phát triển bám thống nhất khi mở rộng DEVKIT.

---

## 1. Định Vị Dự Án

MCV3 là bộ công cụ hỗ trợ phát triển phần mềm cho người không chuyên trên IDE Claude, tuân thủ chuẩn tổ chức của Claude Code. Repo này không chỉ tạo ra code, mà còn tạo ra hệ thống tài liệu, quy trình và agent/skill giúp biến ý tưởng thành sản phẩm phần mềm có thể triển khai và vận hành được.

Điều đó dẫn tới 2 hệ quả quan trọng:

1. Tài liệu của MCV3 là tài sản vận hành thật, không phải output tham khảo tạm thời.
2. Mọi tối ưu về tốc độ chỉ có giá trị khi không làm giảm độ chính xác, chất lượng và khả năng truy vết.

---

## 2. Thứ Tự Ưu Tiên Bắt Buộc

### Ưu tiên 1: Độ chính xác, chất lượng và tính nhất quán

MCV3 phải ưu tiên:

- tài liệu logic, thống nhất, có căn cứ rõ ràng giữa các phase
- code bám sát requirement, không bỏ sót tính năng
- chất lượng kỹ thuật cao: đúng logic, build được, test được, an toàn bảo mật
- đầu ra đủ rõ ràng để doanh nghiệp dùng vận hành, và đủ chuẩn để AI dùng làm context phát triển tiếp

### Ưu tiên 2: Tốc độ xử lý

Chỉ sau khi bảo vệ được ưu tiên 1, MCV3 mới tối ưu:

- thời gian phân tích và sinh tài liệu
- thời gian triển khai code
- thời gian verify và sửa lỗi
- mức độ song song hóa giữa các agent, phase hoặc workstreams

### Quy tắc chốt

Nếu có xung đột giữa tốc độ và chất lượng:

> Chất lượng thắng. Tốc độ chỉ được tối ưu trong vùng an toàn của chất lượng.

---

## 3. Ý Tưởng Mở Rộng Từ Hai Ưu Tiên

### 3.1. Chuỗi truy vết xuyên phase

Mỗi output sinh ra sau phải chỉ rõ nó dựa trên input nào trước đó. Mục tiêu là tạo một chuỗi:

`Ý tưởng -> Requirements -> Features -> Design -> Task -> Code -> Verify -> Deployment`

Áp dụng thực tế:

- tài liệu phase sau phải đọc và bám tài liệu phase trước
- mọi thay đổi lớn phải phản ánh lại vào `req-registry.json`
- code phải trace được tới REQ-ID và FEAT-ID
- verify phải đối chiếu cả code lẫn tài liệu

### 3.2. Tài liệu phải vừa dành cho doanh nghiệp, vừa dành cho AI

Một tài liệu tốt trong MCV3 không chỉ “đúng”, mà còn phải:

- rõ ràng để người vận hành doanh nghiệp đọc được
- đủ ngắn gọn để AI không bị loãng context
- đủ cấu trúc để AI trích xuất lại chính xác
- tránh trùng lặp thông tin giữa nhiều file

Nguyên tắc thực thi:

- mỗi file chỉ giữ đúng mục đích của phase/module/feature đó
- không copy-paste nguyên văn thông tin giữa nhiều file nếu có thể reference
- phần quyết định, giả định, ràng buộc, open issues phải tách rõ

### 3.3. Definition of Done cho tài liệu

Một tài liệu chỉ được xem là hoàn thành khi:

- không mâu thuẫn với registry và tài liệu trước đó
- diễn đạt đủ để doanh nghiệp hiểu và kiểm soát được
- đủ chặt để AI tiếp tục dùng mà không tự suy diễn quá mức
- chỉ rõ nguồn căn cứ, giả định và giới hạn
- không thừa thông tin làm nặng context

### 3.4. Definition of Done cho code

Code chỉ được xem là hoàn thành khi:

- map được tới requirements/features liên quan
- không thiếu hành vi đã cam kết
- không có lỗi logic, lỗi build, lỗi test và lỗi bảo mật rõ ràng
- thư viện/phụ thuộc được rà soát ở mức hợp lý
- trạng thái tài liệu và registry được đồng bộ lại

### 3.5. Song song hóa phải có kế hoạch

Song song hóa là công cụ tăng tốc, không phải mục tiêu tự thân. Chỉ song song khi có thể trả lời rõ:

- phần việc nào độc lập
- ai sở hữu mỗi output
- ranh giới ghi file ở đâu
- contract/interface nào đã chốt
- sau khi hợp nhất sẽ verify lại bằng bước nào

Nếu chưa trả lời được các câu hỏi này, không nên song song hóa.

---

## 4. Mẫu Song Song Hóa An Toàn

### 4.1. Song song theo miền nghiệp vụ

Phù hợp cho:

- phân tích nhiều department
- nhiều module nghiệp vụ độc lập
- audit nhiều nhóm agent/skill/template

Điều kiện:

- cùng template
- cùng tiêu chí đánh giá
- có bước merge và cross-check cuối

### 4.2. Song song Frontend và Backend

Chỉ nên làm khi:

- API contract đã chốt
- data contract rõ ràng
- scope ghi file tách biệt
- có checkpoint tích hợp lại

### 4.3. Song song Docs, Code và QA

Có thể tách thành:

- một luồng hoàn thiện tài liệu/tác vụ
- một luồng triển khai code
- một luồng review/test/security

Điều kiện là các luồng dùng chung một nguồn sự thật và có nhịp đồng bộ định kỳ.

### 4.4. Song song theo module

Hiệu quả khi:

- dependency graph rõ
- module ít phụ thuộc chéo
- shared package/interface đã ổn định

---

## 5. Những Anti-Pattern Cần Tránh

- Viết code quá sớm khi requirement và feature chưa ổn định.
- Cho nhiều agent chỉnh cùng một output mà không có owner rõ.
- Song song hóa trước khi chốt contract dữ liệu hoặc API.
- Đẩy nhanh output bằng cách bỏ qua verify, review hoặc security check.
- Tạo tài liệu dài nhưng loãng, khiến AI tốn context mà vẫn thiếu tín hiệu.
- Đánh dấu “xong” khi code chạy được một phần nhưng tài liệu và registry chưa đồng bộ.

---

## 6. Cơ Chế Vận Hành Khuyến Nghị Cho MCV3

Để hiện thực hóa hai ưu tiên trên, MCV3 nên luôn duy trì các cơ chế sau:

1. Phase gates rõ ràng: mỗi phase có PRE-GATE và POST-GATE.
2. SSOT rõ ràng: registry và output path contract phải nhất quán.
3. Verification before completion: không kết luận hoàn tất nếu chưa có bằng chứng xác minh phù hợp.
4. Planner-first parallelization: muốn tăng tốc phải tách scope, owner và checkpoint trước.
5. Sync ngược sau khi sửa: bug fix hoặc implementation thay đổi phải phản ánh lại docs/registry khi cần.
6. Security và dependency hygiene: kiểm tra ở mức phù hợp trước khi chốt code.

---

## 7. Checklist Ra Quyết Định Nhanh Cho Agent

Trước khi làm một bước mới, Claude/Codex nên tự kiểm:

1. Bước này có đang bám đúng tài liệu và registry trước đó không?
2. Output mới có nguy cơ mâu thuẫn với output cũ không?
3. Có đang đánh đổi chất lượng để lấy tốc độ không?
4. Nếu muốn làm song song, đã tách rõ write scope và owner chưa?
5. Sau bước này, bằng chứng verify nào sẽ chứng minh là an toàn?

---

## 8. Tóm Tắt Một Câu

MCV3 phải được phát triển theo nguyên tắc:

> Tạo ra tài liệu và code đủ chính xác để doanh nghiệp vận hành được và AI phát triển tiếp được; sau đó mới tối ưu tốc độ bằng kế hoạch song song hóa an toàn.
