Bạn đang đóng vai trò là:

- Kiến trúc sư Enterprise cấp cao (Senior Enterprise Architect)
- Kỹ sư đảm bảo tính toàn vẹn nghiệp vụ (Business Integrity Engineer)
- Chuyên gia phân tích hệ thống phân tán (Distributed Systems Analyst)
- Chuyên gia thiết kế AI Workflow & Agent System

Dự án: EUREKA-2026

Đường dẫn dự án đang làm: D:\EUREKA-2026

Nhiệm vụ: Thiết kế một hệ thống Skill chuẩn MCV3 ở cấp độ production nhằm đảm bảo:

- tính toàn vẹn liên module (cross-module integrity)
- tính nhất quán nghiệp vụ (business consistency)
- tính chính xác workflow
- quản trị dependency
- phân tích regression thông minh
- khả năng self-healing
- khả năng orchestration toàn hệ thống ERP

====================================================
BÀI TOÁN CỐT LÕI
====================

Hệ thống hiện tại bao gồm nhiều module ERP đang được phát triển tương đối độc lập.

Rủi ro lớn nhất hiện nay:

- từng tính năng có thể hoạt động riêng lẻ
- nhưng khi kết nối liên module thì phát sinh lỗi
- business consistency không được đảm bảo
- quan hệ entity bị sai lệch
- workflow phụ thuộc bị hỏng ngầm
- regression lan sang nhiều module
- business invariant không được enforce ở cấp hệ thống

Mục tiêu KHÔNG phải chỉ để test tính năng.

Mục tiêu thực sự là xây dựng một hệ thống AI Enterprise Integrity có khả năng:

- hiểu business domain
- hiểu relationship giữa các entity
- hiểu workflow dependency
- validate integrity liên module
- phát hiện GAP kiến trúc
- sinh ra artifact còn thiếu
- enforce business invariant
- thực hiện regression analysis thông minh
- orchestration việc kiểm tra toàn hệ thống

====================================================
MỤC TIÊU CHÍNH
=================

Skill này cần đảm bảo:

1. Cross-module feature integrity

Khi một tính năng được thực thi, toàn bộ:

- module phụ thuộc
- workflow liên quan
- entity liên quan
- permission
- event
- downstream system

đều phải hợp lệ và đồng bộ.

**Ví dụ:**
Khi tạo khách hàng phải validate:

- CRM customer profile
- sales owner assignment
- sự tồn tại của employee trong HRM
- Customer360 aggregation
- workflow registration
- audit logging
- permission consistency
- analytics propagation
- notification trigger
- financial dependency

2. Business invariant enforcement

Hệ thống phải có khả năng:

- infer
- định nghĩa
- validate
- enforce

các business invariant như:

- sales owner phải tồn tại
- employee phải active
- tax code phải unique
- warehouse phải thuộc branch
- shipment phải có customs declaration
- invoice phải tạo accounting entry

3. Intelligent dependency analysis

Hệ thống phải build được:

- entity dependency graph
- module dependency graph
- workflow graph
- API dependency graph
- event propagation graph
- permission dependency graph

4. Intelligent regression analysis

Khi bất kỳ module nào thay đổi:

- detect affected modules
- xác định regression scope
- generate test plan cần chạy lại
- xác định workflow risk
- detect side-effect tiềm ẩn

5. GAP detection & self-healing

Hệ thống phải detect:

- missing business rules
- missing validation
- missing workflow
- missing audit coverage
- missing observability
- inconsistent schema
- broken contract
- undocumented dependency

Đồng thời hệ thống phải có khả năng đề xuất & tự động thực hiện:

- fix
- artifact còn thiếu
- test còn thiếu
- contract còn thiếu
- cải tiến kiến trúc
- governance improvement

6. Coverage assurance — đảm bảo chất lượng xử lý cao nhất

Skill phải đảm bảo độ bao phủ (coverage) theo nhiều chiều để đạt chất lượng xử lý công việc ở cấp doanh nghiệp:

Coverage layers (các chiều phủ bắt buộc):

- business domain coverage — mọi domain/module có ≥1 invariant đăng ký
- entity coverage — mọi entity quan trọng có dependency graph + ownership
- workflow coverage — mọi business workflow được trace end-to-end (start → end state)
- API contract coverage — mọi API public có request/response schema được validate
- event coverage — mọi event được map producer/consumer + propagation path
- permission coverage — mọi resource có RBAC matrix đầy đủ (actor × action × resource)
- data integrity coverage — mọi FK, unique constraint, NOT NULL được enforce
- observability coverage — mọi critical path có log + metric + trace
- regression coverage — mọi affected module có test plan tương ứng
- documentation coverage — mọi invariant + dependency có ghi chú nghiệp vụ tiếng Việt

Coverage gates (ngưỡng tối thiểu theo profile):

- quick: ≥60% mỗi chiều — chỉ cho hotfix khẩn
- standard: ≥80% mỗi chiều — default cho daily work
- deep: ≥95% mỗi chiều — pre-release gate
- exhaustive: 100% mỗi chiều — audit/compliance release
- coverage < threshold → escalate qua CDG (Critical Decision Gate), KHÔNG silent skip
- thiếu coverage → tự động đề xuất artifact bổ sung (test case, contract, invariant rule, doc snippet)

Coverage reporting:

- `coverage-report.md` cho người vận hành (tiếng Việt, ≤15 dòng/phase, CORE-028)
- `coverage-matrix.json` cho downstream skill consume (schema versioned, CORE-036)
- `coverage-trend.jsonl` lưu lịch sử để phát hiện regression coverage giữa các run

7. Multi-session parallelism — chạy song song nhiều phiên trên cùng máy

Skill phải cho phép một dev mở nhiều phiên làm việc đồng thời trên cùng máy mà không corrupt state:

Session isolation (CORE-030, CORE-035):

- mỗi run cô lập trong `sessions/{SESSION_ID}/` riêng
- SESSION_ID format `YYYY-MM-DD-{scope}-{slug}-{NN}` đảm bảo unique cross-process
- session lock + heartbeat daemon — chống 2 instance ghi đè cùng SESSION_DIR
- stale lock auto-release sau 30 phút (CORE-038 resume flow)
- session index `_index/sessions.jsonl` append-only — track mọi phiên đang chạy

Shared resource access (Protocol 22 — cross-session R/W lock):

- registry, scan cache, CI cache dùng R/W lock cross-session
- read lock cho phép N reader đồng thời; write lock độc quyền
- atomic write pattern cho mọi JSON state (build tmp → validate → mv → release)
- KHÔNG block phiên khác khi 1 phiên đang chạy phase analyze (read-only)
- chỉ block ở write registry/SSOT (vài giây) hoặc CDG approval

Concurrency limits (theo profile để bảo vệ máy yếu):

- max 10 agents/session (CORE-025)
- max 5 session/máy với profile quick/standard
- max 2 session/máy với profile deep/exhaustive
- vượt limit → reject với gợi ý chạy tuần tự hoặc nâng profile

Tình huống tiêu biểu:

- dev đang chạy `--scope=system` toàn ERP (deep, 2h) → vẫn mở phiên 2 `--scope=module=CRM` (quick, 10p) cho bug khẩn
- dev verify-sync ở phiên A → có thể chạy GAP-detection ở phiên B trên cùng workspace
- phiên A crash giữa chừng → phiên B không bị ảnh hưởng, phiên A resume được qua `--resume`

8. Multi-user collaboration — nhiều dev cộng tác qua GitHub

Skill phải hỗ trợ nhiều dev cùng làm việc trên dự án qua GitHub (mỗi dev một máy, không share workspace):

Git-friendly artifact contract:

- session artifact (`fix-status.json`, `Phase{N}-report.md`, `coverage-report.md`, `integrity-report.md`, `regression-map.json`) — text/JSON deterministic, commit được
- artifact filename gắn SESSION_ID + author slug → tránh conflict tên file khi merge
- `.mc-data/work/{skill}/sessions/` được commit (KHÔNG gitignore phần share) để truyền state qua branch
- audit_chain checksum (CORE-036) cho phép verify artifact không bị sửa giữa các commit
- session-log.json và error-ledger.json append-only → merge chỉ là concatenate, không conflict

Branch isolation & resume cross-machine:

- mô hình "1 dev = 1 branch", mỗi branch có session subtree riêng
- dev B pull branch dev A → có thể `--resume` tiếp session của dev A nếu lock đã release (stale > 30p)
- conflict trong session JSON → resolve theo phase subdirectory → ưu tiên append-only sections

Conflict resolution & coordination:

- registry merge conflict → ưu tiên SSOT canonical (CORE-006 safe-write per-skill ownership đã giảm vùng conflict)
- 2 dev cùng touch 1 invariant → CDG gate yêu cầu cả 2 approve trước khi enforce
- PR template gắn liền session report — `Phase{N}-report.md` được render trong PR description
- reviewer xem được `integrity-report.md` + `regression-map.json` + `coverage-report.md` trực tiếp trong PR

Audit chain xuyên người dùng:

- mỗi session ghi `author = git user.email + git config user.name` vào session-log.json
- integrity-report tổng hợp trace được ai chạm invariant nào, khi nào, branch nào, commit nào
- không ai downgrade ngầm `impl_status=done` (CORE-008) — phải qua PR + reviewer approve
- mỗi CDG decision lưu lại approver chain để audit/compliance

GitHub automation hooks (optional, không bắt buộc cho v1):

- GitHub Action có thể trigger skill ở chế độ `--ci` (read-only verify + comment lên PR)
- bot post `coverage-report` + `integrity-report` lên PR mỗi lần push
- nightly Action chạy `wf-cmi --scope=system --profile=deep` trên main branch → mở issue nếu integrity giảm

====================================================
GIAI ĐOẠN RESEARCH BẮT BUỘC
===============================

Trước khi đề xuất bất kỳ kiến trúc hay implementation nào, cần thực hiện:

1. Phân tích toàn bộ cấu trúc dự án hiện tại
2. Xác định tất cả module
3. Xác định business domain
4. Xác định relationship giữa các entity
5. Xác định API và event
6. Xác định workflow dependency
7. Xác định cấu trúc RBAC / permission
8. Xác định integration pattern
9. Xác định database relationship
10. Xác định architectural gap hiện tại
11. Xác định documentation còn thiếu
12. Infer business intent từ:

- source code
- database schema
- naming
- API
- UI flow
- validation logic

====================================================
YÊU CẦU THIẾT KẾ
====================

Thiết kế đầy đủ kiến trúc Skill MCV3 bao gồm:

1. Theo chuẩn của MCV3 skill-design ..\MCV3\docs\04-skill-design
2. Các tài liệu skill ..\MCV3\docs

====================================================
OUTPUT MONG MUỐN
=================

Generate đầy đủ các output production-grade bao gồm:

1. Định nghĩa output mong muốn Theo chuẩn của ..\MCV3\docs\04-skill-design

====================================================
YÊU CẦU QUAN TRỌNG
=====================

Thiết kế phải:

- hoạt động như một enterprise-grade integrity system
- ưu tiên business consistency hơn feature isolation
- hỗ trợ ERP quy mô lớn
- hỗ trợ distributed workflow
- hỗ trợ automation về sau
- hỗ trợ agent orchestration
- hỗ trợ Claude Code workflow
- hỗ trợ autonomous execution pipeline

Thiết kế KHÔNG được:

- quá generic
- quá hời hợt
- chỉ tập trung testing
- chỉ tập trung code quality
- bỏ qua business workflow
- bỏ qua system-wide dependency

====================================================
THINKING MODE
=============

Hãy suy nghĩ sâu và có hệ thống.

Hoạt động như:

- enterprise architect
- ERP solution architect
- distributed systems engineer
- business process auditor
- system integrity engineer
- AI orchestration designer

Liên tục tìm kiếm:

- hidden dependency
- implicit business rule
- side-effect
- failure propagation
- consistency risk
- regression risk
- workflow corruption risk
- observability gap
- governance weakness

====================================================
KỲ VỌNG CUỐI CÙNG
=====================

Hãy tạo ra một bản thiết kế hoàn chỉnh ở cấp độ enterprise cho hệ thống AI-driven Cross-Module Integrity & Business Consistency MCV3 Skill System dành cho dự án EUREKA-2026.
