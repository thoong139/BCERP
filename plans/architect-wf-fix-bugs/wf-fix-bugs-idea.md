**Ý tưởng mục tiêu hoạt động của skill wf-fix-bugs**

Mô tả:

- Skill wf-fix-bugs là **orchestrator ** điều phối hoạt động tìm kiếm, phân tích, rà soát lỗi trong phạm vi mà người dùng yêu cầu skill này làm việc.
- SKILL.md  **chỉ chứa** : overview, arguments, phase routing map table, condensed phase summaries (1 dòng/step), output files list, error quick-lookup. **KHÔNG chứa** code thực thi. Tất cả logic execution nằm trong `procedures/phase*.md`.
- Tất cả các quá trình làm việc của skill và các sub-skill thực hiện làm việc trong pipeline của skill wf-fix-bugs cần có trong templates của skill này. Các files phục vụ làm việc cần tuân thủ trong templates của từng Phase. Và các sub-skill tuân thủ đúng theo các mẫu files đó.
- 

Ý tưởng về Quá trình skill thực hiện:

* Phase 1 (Init): Sẽ thực hiện phân tích thông tin mà người dùng yêu cầu skill cần thực hiện. Sau đó Khởi tạo cấu trúc thư mục để chuẩn bị làm việc (Giống các skill khác trong .mc-data)
* Phase 2 (Scan phạm vi thực hiện): Sẽ thực hiện phân tích và Scan để tìm hiểu phạm vi công việc; Cung cấp cho quá trình lên kế hoạch trong Phase 2, và có thể làm đầu vào là Context cho các Phase tiếp theo làm việc tốt hơn. (Scan code, Scan tài liệu liên quan,..). Mục tiêu Scan này là để tiết kiệm thời gian cho các Phase sau khi thực hiện công việc.
  Chú ý: Phase 1: Cần báo cáo chi tiết và đưa ra 1 hoặc vài file kết quả thực hiện.
* Phase 3 (Plan): Phân tích và lên Plan để thực hiện toàn bộ công việc
* Phase 4 (Find Bugs): Đây là Phase sẽ thực hiện các công việc chính và nặng nhất.
  * Phase 3 cần: Thực hiện song song các quá trình:

    1. Thực hiện Spawn các Agent (Mỗi Agent sẽ thực hiện một nhiệm vụ chuyên biệt. Ví dụ như skill Z:\Working\MCV3\.claude\skills\workflow\wf-fix-functional thì skill này chuyên dò tìm và phát hiện lỗi QD1 Functional Correctness Lane — phat hien bug functional qua probes P-QD1-xxx (10 probes lazy-load).
       (Có thể Spawn max 10 Agent để thực hiện 1 lần để thực hiện)

    * **Khi các Sub-Skill thực hiện thì cần:**
      * Chạy các script để phân tích tìm lỗi (static) và sử dụng các Agent để thực hiện tìm Signal => Thực hiện chạy các script và tìm lỗi (static)
      * Và đồng thời trong lúc Script thực hiện thì Sub-Agent cũng phân tích và tìm Signal theo chuyên môn Context được cung cấp của mình.
        Các công việc có thể làm song song (Chạy Parrapell để phân tích). Luôn có thiết kế để chạy song song để thực hiện các công việc được nhanh hơn.

    **Lưu ý:** Luôn luôn cần có thể thực hiện -resume công việc trong trường hợp lỗi, hoặc người dùng chủ đích muốn dừng công việc

5. Phase 5 (Kiểm tra và phân loại Bug/Signal): Trong quá trình Phase 3 thực hiện, có thể nhiều Bugs bị trùng, hoặc xử lý vấn đề có liên quan tới nhau. Phiên này sẽ xử lý phân tích & Phân loại các  Bug/Signal đã phát hiện tại Phase 3 và Verify lại và đề xuất cách thực hiện để xử lý từng vấn đề lỗi. Phiên này có thể Huy động các Agent chuyên gia bám sát các yêu cầu tài liệu có trong dự án (nếu có) tại .mc-data/docs để có Context thực hiện tốt và sát nhất về dự án.
6. Phase 6 (Execute Fix): Đây là Phase chính thực hiện các nhiệm vụ Fix bugs, Cần Spawn các Agent (Có chuyên môn kĩ thuật để thực hiện Fix song song) Hoặc cần thiết thì tận dụng các skill khác tham gia vào công việc như các skill trong flow của MCV3 để thực hiện Fix, hoặc bổ sung tính năng....
7. Phase 7 (Verify & Report): (Kiểm tra & Báo cáo): Thực hiện kiểm tra và báo cáo lại toàn bộ công việc.


  Chú ý:

- Mỗi Phase làm việc cần có báo cáo (phase report): **Ví dụ:** Phase1-report.md, Phase2-report.md
- Trong Phase 3 (Find Bugs) thì mỗi Agent sẽ có báo cáo kèm đánh giá đề xuất nhận định riêng:
  Ví dụ: QD1-functional-report.md, QD2-business-report.md, ...
- Cách đặt tên cũng cần cho người dùng dễ nhìn.
- Các File được tạo ra nằm trong thư mục làm việc trong phiên đó và nằm trong các thư mục Phase chính đang thực hiện để dễ theo dõi.
- Công việc qua mỗi Phase có thể kế thừa và đọc lại kết quả của Phase trước để bám sát công việc được tốt nhất có thể (Không đoán khi thực hiện)
