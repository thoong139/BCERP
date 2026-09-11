# Hướng Dẫn Làm Việc Với Codex Trên MCV3

Tài liệu này bổ sung cho `AGENTS.md` và `CLAUDE.md`, tập trung vào những gì giúp Codex làm việc ổn định, ít nhiễu và đúng workflow hơn trong repo MCV3.

## 1. Mục Tiêu Của Bộ Thiết Lập

MCV3 không phải application thông thường. Đây là repo chứa chính bộ công cụ DEVKIT:

- hệ thống agents trong `.claude/agents/`
- workflow skills trong `.claude/skills/`
- hooks, rules, doc-framework và script hỗ trợ
- tài liệu mô tả cách DEVKIT vận hành

Vì vậy, Codex cần ưu tiên:

1. hiểu đúng lớp đang sửa
2. giữ contract giữa các thành phần
3. tránh làm bẩn working tree bởi artefact runtime
4. xác minh thay đổi bằng đúng công cụ của repo

## 1.1. Thứ Tự Ưu Tiên Của MCV3

Khi làm việc trên MCV3, Codex phải ghi nhớ thứ tự ưu tiên sau:

1. độ chính xác, chất lượng, tính nhất quán, tính đầy đủ và an toàn
2. tốc độ xử lý, tối ưu plan và song song hóa

Quy tắc vận hành:

- không được đánh đổi correctness, security hoặc traceability để lấy tốc độ
- tài liệu phase sau phải có căn cứ từ tài liệu phase trước và registry
- code phải bám requirement/feature, không được bỏ sót behavior
- chỉ song song hóa khi đã tách rõ write scope, owner và checkpoint verify

Chi tiết đầy đủ: `docs/mcv3-development-priorities.md`

## 2. Thứ Tự Nạp Ngữ Cảnh Khuyến Nghị

Không nên đọc toàn bộ repo ngay từ đầu. Hãy nạp theo task:

### Khi sửa hoặc tạo skill

Đọc theo thứ tự:

1. `CLAUDE.md`
2. `docs/skills-reference.md`
3. skill cần sửa trong `.claude/skills/.../SKILL.md`
4. procedure, template, evals đi kèm của skill đó
5. nếu ảnh hưởng workflow lớn, đọc thêm tài liệu trong `docs/prompt/`

### Khi sửa hoặc tạo agent

Đọc theo thứ tự:

1. `CLAUDE.md`
2. agent file trong `.claude/agents/...`
3. procedure liên quan trong `.claude/agents/procedures/...`
4. tài liệu tham chiếu trong `.claude/references/...` nếu agent dựa vào kiến thức domain

### Khi sửa hooks hoặc rules

Đọc theo thứ tự:

1. `CLAUDE.md`
2. `.claude/settings.json`
3. hook hoặc rule mục tiêu
4. `docs/claude-guide/03-hooks-automation.md` nếu cần đối chiếu cách vận hành

### Khi xử lý self-audit

Đọc theo thứ tự:

1. `docs/audit/devkit-existing-project-audit.md`
2. `docs/audit/devkit-problem-resolution.md`
3. file trong `docs/audit/work/...` đúng phiên làm việc đang được người dùng quan tâm

## 3. Những Thư Mục Nên Coi Là Artefact

Các thư mục sau thường là dữ liệu phát sinh:

- `.mc-data/`
- `docs/audit/work/`

Nguyên tắc:

- không chỉnh trực tiếp nếu người dùng không yêu cầu
- chỉ đọc để lấy trạng thái, bằng chứng hoặc debug
- không dùng chúng làm "nguồn sự thật" thay cho skill, template và rule definitions

## 4. Chiến Lược Chỉnh Sửa Theo Lớp

### Skill layer

Khi sửa skill, cần giữ các phần sau nhất quán:

- workflow position
- prerequisites
- phase tables
- PRE-GATE và POST-GATE
- output paths
- error handling
- related skills

Nếu đổi contract output, phải rà cả:

- template đi kèm
- evals
- docs tham chiếu trong `docs/skills-reference.md`

### Agent layer

Khi sửa agent hoặc procedure:

- giữ đúng tên agent file vì đó là định danh được skill gọi tới
- rà path procedure được nhắc trong agent
- tránh để procedure và agent mô tả mâu thuẫn nhau

### Hook và rule layer

Khi sửa hooks hoặc rules:

- kiểm tra `.claude/settings.json` còn trỏ đúng script
- lưu ý môi trường Windows hiện chủ yếu chạy qua PowerShell
- với script `.sh`, ưu tiên xác minh qua wrapper PowerShell thay vì giả định shell Unix

## 5. Chạy Script Bash Từ PowerShell

Repo hiện có nhiều script `.sh`. Để Codex thao tác dễ hơn trên Windows, dùng wrapper:

```powershell
powershell -ExecutionPolicy Bypass -File .claude/scripts/run-devkit-bash.ps1 .claude/scripts/skill-compliance-audit.sh wf-legacy-scan
```

Ví dụ audit toàn bộ:

```powershell
powershell -ExecutionPolicy Bypass -File .claude/scripts/run-devkit-bash.ps1 .claude/scripts/skill-compliance-audit.sh --all
```

Wrapper này:

- nhận path script theo chuẩn của repo
- tự chuyển path Windows sang đường dẫn dùng được trong bash
- giữ working directory ở repo root trước khi chạy

## 6. Checklist Nhanh Trước Khi Kết Luận Hoàn Thành

1. Đã đọc đúng lớp tài liệu liên quan chưa.
2. Đã tránh sửa artefact runtime chưa.
3. Đã giữ nguyên hoặc cập nhật đầy đủ output contract chưa.
4. Đã chạy ít nhất một bước xác minh phù hợp chưa.
5. Đã kiểm tra `git diff` để chắc không lôi theo thay đổi ngoài ý muốn chưa.
6. Đã chứng minh rằng tối ưu tốc độ đưa vào không làm giảm chất lượng chưa.

## 7. Khi Nào Nên Mở Rộng Thiết Lập

Nếu về sau muốn Codex làm việc sâu hơn nữa trên MCV3, các bước mở rộng hợp lý là:

1. thêm wrapper PowerShell cho các script bash dùng thường xuyên ngoài audit
2. bổ sung README ngắn cho từng nhóm thư mục lớn như `.claude/agents/` hoặc `.claude/skills/`
3. chuẩn hóa thêm `.gitignore` cho mọi artefact runtime mới phát sinh

Hiện tại, `AGENTS.md`, tài liệu này, wrapper PowerShell và `.gitignore` đã đủ để Codex có điểm bám tốt khi làm việc thường xuyên trong repo.
