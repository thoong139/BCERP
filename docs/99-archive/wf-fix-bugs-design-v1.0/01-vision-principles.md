# 01 — Tầm Nhìn & Nguyên Tắc Thiết Kế

> **Đọc trước:** [README.md](README.md)
> **Đọc tiếp:** [02-quality-dimensions.md](02-quality-dimensions.md)

---

## 1. Tầm Nhìn (Vision)

`wf-fix-bugs` sau tái thiết kế là **"hệ thống phân tích chất lượng đa chiều, có thể mở rộng bằng plugin"** thay vì một pipeline tuyến tính 3 phase.

Một người không chuyên kỹ thuật dùng `/wf-fix-bugs` cần cảm nhận được 3 điều:

1. **Dễ gọi** — vẫn chỉ một command, không cần biết "discover/triage/execute" hay 7 chiều.
2. **Hiểu được bug ở mức nào** — báo cáo phân loại theo chiều chất lượng (đúng chức năng / an toàn / hiệu năng / ...), không phải theo "layer 2" hay "pass 3".
3. **Chủ động được độ sâu** — muốn kiểm nhanh chỉ 1 chiều thì chạy 1 chiều; muốn quét toàn diện thì dùng profile cao hơn.

Một người triển khai DEVKIT (engineer) cần cảm nhận thêm:

4. **Thêm chiều mới không phá code cũ** — thêm một Dimension Lane là thêm một folder skill con + rules + probes, orchestrator không đụng.
5. **Debug được rõ ràng** — từ Issue có thể truy ngược về Probe → Signal gốc → Evidence (screenshot/stack/log).
6. **Chạy song song an toàn** — các lane độc lập được thiết kế theo CORE-025; Signal Bus đảm nhận merge.

---

## 2. Problem Statement — Tại Sao Không Tiếp Tục Pipeline Hiện Tại

### 2.1 Các Vấn Đề Thực Tế Đã Ghi Nhận

| # | Vấn đề | Hệ quả | Bằng chứng |
|---|--------|--------|-----------|
| PB-1 | Mọi loại bug nhét chung vào `issue-registry.json`, không có trường `dimension` | Không trả lời được "security coverage của run này là gì" | Schema `issue-registry.json` hiện tại chỉ có `severity`, `fixability`, không có trục dimension |
| PB-2 | `wf-fix-discover` phình lên theo số scanner — 5-Layer chưa đủ đã phải thêm PASS 1/2/3, runtime/static split | Một file SKILL.md + procedures phức tạp; khó onboard | Plan `coverage-expansion/04-phase-B` cần thêm 8 sub-skill mới đều nhét vào giai đoạn discover |
| PB-3 | `--deep`, `--full-test`, `--responsive` là các flag rời rạc, không rõ ngữ nghĩa | User không biết kết hợp flag nào cho nhu cầu của mình | Docs `SKILL.md` phải giải thích 9+ flag |
| PB-4 | Không có khái niệm "chạy 1 chiều" | User muốn kiểm tra nhanh security không có cách nào ngoài full pipeline | — |
| PB-5 | Phân loại severity lẫn lộn trục impact (kỹ thuật vs nghiệp vụ) | Ví dụ: memory leak ở trang rất ít dùng bị tag HIGH như login xss | Protocol `03-triage` không phân biệt bối cảnh dimension |
| PB-6 | Evidence chưa được chuẩn hoá cho multi-dimension | Security cần diff, performance cần flame-graph, a11y cần axe report — schema hiện tại chỉ có `evidence_files: []` | Schema `issue-registry.json` |
| PB-7 | Exit criteria ("đã đủ chưa") mập mờ | Không biết khi nào dừng scan — dễ underscan (miss bug) hoặc overscan (tốn token) | Không có `exit_criteria` per category |
| PB-8 | Plan `coverage-expansion` dùng lại trục scanner phẳng (12 category song song) — vẫn khó đo "coverage" | Không rõ 12 category có orthogonal không; một bug có thể thuộc nhiều category | Matrix trong `01-strategy.md §5` thiếu overlap rule |

### 2.2 Hệ Quả Gộp

- **Về sản phẩm:** user dùng skill xong không chắc là đã an toàn cho release, vì không có bảng coverage theo chiều chất lượng.
- **Về kỹ thuật:** code base của skill `wf-fix-*` ngày càng couple chặt, khó thay thế 1 layer khi công nghệ đổi (ví dụ: đổi runtime Playwright sang Puppeteer; đổi axe-core sang pa11y).
- **Về vận hành:** không có cách trả lời "đã kiểm chiều X cho module Y" khi user ERP hỏi audit trail.

---

## 3. Ý Tưởng Cốt Lõi (Key Insight)

> Bug tồn tại trong **một hoặc nhiều chiều chất lượng** — không tồn tại trong "phase". Phase chỉ là công đoạn xử lý. Nếu tổ chức skill theo **chiều chất lượng**, mỗi chiều có thể có phase nội bộ riêng, nhưng trục chính là chiều.

Do đó:

- **Trục chính (outer axis):** Quality Dimension (QD1…QD7).
- **Trục phụ (inner axis per lane):** Sense → Think → Act → Verify (4 giai đoạn nội bộ của một lane).
- **Shared services (cross-cutting):** Signal Bus, Triage, Planner, Fixer, Verifier — dùng chung để không duplicate 7 lần.

### 3.1 So Sánh Ngắn

| Khía cạnh | Pipeline hiện tại | Thiết kế mới (dimension-based) |
|-----------|-------------------|-------------------------------|
| Trục chính | Phase (Discover/Triage/Execute) | Dimension (7 chiều) |
| Đơn vị phát hiện | Layer + PASS trong 5-Layer | Probe (static rule / runtime check / LLM review / external tool) |
| Mức độ | Flag rời rạc | Profile (preset) + Dimension Selection (opt-in/out) |
| Output phân loại | severity, fixability | severity, fixability, **dimension**, **confidence**, **probe_source** |
| Mở rộng | Sửa `wf-fix-discover` + thêm skill con | Thêm lane (plugin) |
| Song song hoá | Theo layer (giới hạn) | Theo lane (7 lane độc lập) |

---

## 4. 11 Nguyên Tắc Thiết Kế (Design Principles)

Các nguyên tắc dưới đây phải luôn được tôn trọng. Nếu design có xung đột với nguyên tắc → viết rationale vào ADR ([07-tradeoffs-adr.md](07-tradeoffs-adr.md)).

### P1 — Chính xác trước tốc độ (Correctness Over Speed) · CORE-023

Không hy sinh độ chính xác để chạy nhanh. Một lane thà chạy chậm + flag WARNING còn hơn bỏ qua silent. Profile `quick` được phép giảm *coverage* nhưng không được *nói sai* về kết quả đã chạy (ví dụ: quick skip security thì báo cáo phải ghi rõ "security: skipped by profile").

### P2 — Dimension Orthogonality

Mỗi Quality Dimension phải có:

- Scope độc lập đủ để người đọc hiểu mà không phải đọc dimension khác.
- Exit criteria đo được (numeric threshold, checklist).
- Probe riêng — không dùng chung logic phát hiện với dimension khác. Nếu trùng → refactor thành shared utility, nhưng ownership vẫn thuộc 1 dimension.
- Overlap được phép ở Issue level (1 Issue có thể tag 2 dimension), nhưng **Probe phải thuộc đúng 1 dimension**.

### P3 — Evidence-Based · CORE-024

Mọi Signal emit ra phải có:

- `probe_source`: id probe sinh ra signal.
- `evidence`: ít nhất 1 trong {code_ref, screenshot, log_excerpt, stack_trace, reproducer_command}.
- `confidence`: `high` / `medium` / `low` — lane phải tự tính, không để mặc định.

Không hallucinate. Thà emit ít Signal chắc chắn còn hơn nhiều Signal mơ hồ.

### P4 — Safe Parallelism · CORE-025

Lane chạy song song chỉ khi:

- Write scope tách biệt: `$SESSION_DIR/lanes/{dimension}/`.
- Contract Signal Bus stable (schema versioned).
- Retry độc lập: 1 lane fail không lan sang lane khác.
- Aggregator verify sau merge: Signal Bus phải có POST-GATE check duplicates + orphan.

### P5 — Single Source of Truth Respect · CORE-004, CORE-006

- `req-registry.json` là SSOT cho Feature/Requirement — wf-fix-bugs **KHÔNG** được ghi.
- `$SESSION_DIR/issue-registry.json` là SSOT cho Issue trong phạm vi session.
- `$SESSION_DIR/lanes/{dim}/signals.json` là raw data của lane — Signal Bus consume, không ghi ngược.
- Ownership Safe-Write giữ nguyên: `wf-fix-bugs` = NONE (orchestrator); `wf-fix-execute` (hoặc successor) = SAFE-UPDATE `impl_status`.

### P6 — Graceful Degradation

- Tool bên ngoài không có → Probe skip + ghi vào `coverage-report.md` mục "tools missing".
- Timeout → Probe dừng, emit partial signal với flag `truncated=true`.
- CDG (Critical Decision Gate · CORE-027) trigger → lane pause, Signal Bus lưu checkpoint, orchestrator hỏi user.

### P7 — Backward-Compat cho User

- Entry `/wf-fix-bugs` giữ nguyên.
- Flag cũ (`--deep`, `--full-test`, `--responsive`, `--dry-run`, `--resume`, `--status`, `--scope`, `--name`, `--url`, `--credentials`, `--no-browser`, `--browser-only`) phải map vào Profile + Dimension Selection tương đương.
- Output files (`fix-status.json`, `issue-registry.json`, `fix-report.md`, ...) giữ tên + vị trí (SESSION_DIR layout).
- Schema thêm field chứ không rename/remove; field mới có default giá trị tương thích đọc ngược.

### P8 — Plugin-able Dimensions

Thêm một Quality Dimension mới phải trong vòng 1 PR:

- 1 folder `wf-fix-<dim>/` trong `.claude/skills/workflow/`.
- 1 manifest `dimension.json` khai báo probes, exit criteria, severity mapping.
- 1 registration entry trong orchestrator config.
- Không sửa các skill dimension khác.

### P9 — Testable Bootstrapping (Golden Suite)

Mỗi dimension có golden fixture riêng — tập bug đã biết + expected Issues. CI/manual-check có thể chạy:

```
/wf-fix-bugs --dim=<D> --golden=<fixture> → đo detect rate và false positive
```

### P10 — User Observability

User phải thấy được:

- `coverage-report.md`: dimension nào đã chạy, tool nào missing, skip lý do gì.
- `phase-summary.md`: bản tiếng Việt ≤15 dòng cho non-specialist — **phải liệt kê theo dimension** (CORE-028 extended).
- `orchestrator-summary.md`: tổng kết theo profile + dimension.
- Resume command rõ ràng theo dimension: `/wf-fix-bugs --resume --dim=security` khả dụng.

### P11 — User-Controlled Scope (Dimension Selection là First-Class)

Người dùng luôn có quyền chọn **một hoặc nhiều** Quality Dimension để `/wf-fix-bugs` làm việc. Đây là nguyên tắc thiết kế cứng, không phải tuỳ chọn phụ:

- **Ràng buộc tối thiểu:** `selected_dims.length ≥ 1` và `selected_dims ⊆ enabled_dimensions`.
- **Scope enforcement toàn pipeline:** Orchestrator, Lanes, Signal Bus, Triage, Planner, Fixer, Verifier, Report — tất cả **chỉ xử lý Issue/Signal có dimension ∈ selected_dims**. Thành phần ngoài scope không khởi chạy, không tốn budget.
- **Transparency:** `fix-status.json` ghi rõ `selected_dimensions` và `excluded_dimensions`. `fix-report.md` có 2 mục bắt buộc: "Phạm vi đã xử lý" và "Ngoài phạm vi (chưa kiểm)".
- **No silent widening:** `--resume` bắt buộc load đúng `selected_dimensions` từ session cũ; orchestrator KHÔNG được tự mở rộng scope.
- **No silent narrowing:** Profile default cung cấp dims mặc định; nhưng nếu user truyền `--dims/--only/--skip`, các flag này **override** profile — và skill phải log rõ "đã override profile default".
- **Multi-dim là bình đẳng với single-dim:** `--dims=QD3,QD5,QD6` không kém ưu tiên so với `--only=security`; cả hai đều là valid first-class inputs.

Chi tiết enforcement xem [05-execution-profiles.md §3.0](05-execution-profiles.md) và [03-architecture.md](03-architecture.md) (Signal Bus filtering).

---

## 5. Bindings Với CORE Rules

Các CORE rules bắt buộc phải bám khi triển khai thiết kế này:

| CORE | Ảnh hưởng tới thiết kế |
|------|------------------------|
| CORE-004 | `req-registry.json` không bị ghi bởi wf-fix-bugs. Lane phải đọc registry để biết scope feature. |
| CORE-005 | Docs tiếng Việt, tên file/biến English hoặc VN không dấu. |
| CORE-006 | Safe-Write: wf-fix-bugs = NONE; Fixer service = SAFE-UPDATE `impl_status`. |
| CORE-007 | Cross-skill output path contract giữ nguyên; thêm sub-path `lanes/{dim}/` phải được ghi vào §4b. |
| CORE-023 | Priority: chất lượng > tốc độ. |
| CORE-024 | Downstream output (Issue) phải có căn cứ từ upstream (Signal → Probe → Code/Runtime evidence). |
| CORE-025 | Lane song song chỉ khi đủ điều kiện ownership/isolation/contract/verify. |
| CORE-026 | Execution Trace: mỗi lane ghi START/COMPLETE/FAIL vào `session-log.json`. |
| CORE-027 | CDG: các thao tác không thể undo (fix security bằng cách xoá feature, downgrade dep major, ...) phải pause + hỏi user. |
| CORE-028 | Phase Summary tiếng Việt, ≤15 dòng, non-specialist — thiết kế này mở rộng: **summary phải có breakdown theo dimension**. |
| CORE-029 | Agent Output Spot-Check: Probe dùng agent (business/security expert) phải chạy schema validation trước khi ghi Signal. |
| CORE-030 | Session Isolation: `SESSION_DIR/lanes/{dim}/` cô lập per-lane. |
| CORE-031 | Template Usage: mỗi Signal/Issue/report dùng template — thiết kế này bắt buộc có `templates/` cho từng lane. |

---

## 6. Những Gì Đã Cố Ý Không Đưa Vào Nguyên Tắc

Để tránh over-specify, các nội dung sau **không** nằm trong principle:

- **Chọn tool cụ thể** (Semgrep vs Snyk, Lighthouse vs k6, axe-core vs pa11y): để từng lane quyết định, có thể đổi mà không vi phạm principle.
- **Thời gian chạy** từng profile: là mục tiêu vận hành, thuộc [05-execution-profiles.md](05-execution-profiles.md).
- **UI dashboard**: đã thuộc Non-Goals ([README §8](README.md)).
- **Ngôn ngữ agent** (business-analyst, security-expert, ...): để lane chọn.

---

## 7. Open Design Questions Được Nêu Ở Đây

Các câu hỏi này cần user/team trả lời để đóng thiết kế. Liệt kê ngắn ở đây; bối cảnh đầy đủ xem [07-tradeoffs-adr.md §Open Questions](07-tradeoffs-adr.md).

- **OQ-A**: Có gộp QD1 (Functional) và QD2 (Business) thành 1 dimension "Correctness" với 2 sub-level không? → ảnh hưởng plugin model.
- **OQ-B**: Signal Bus là một skill độc lập hay là utility library + contract? → ảnh hưởng CORE-007 path table.
- **OQ-C**: Profile `exhaustive` có yêu cầu chạy **hết** 7 dimension hay cho phép user xếp tổ hợp? → ảnh hưởng UX.
- **OQ-D**: Migration timeline — 2 release deprecation hay 1 release? → ảnh hưởng roadmap.

---

## 8. Checklist Trước Khi Chuyển Sang Phần Kiến Trúc

Trước khi đọc [02-quality-dimensions.md](02-quality-dimensions.md), reviewer xác nhận:

- [ ] Hiểu trục chính là Dimension, không phải Phase.
- [ ] Đồng ý 10 nguyên tắc P1–P10 là ràng buộc cứng.
- [ ] Không yêu cầu thay đổi CORE rules hiện hành.
- [ ] Chấp nhận backward-compat là điều kiện tiên quyết.
- [ ] Đã xem qua mục "Non-Goals" trong [README §8](README.md).

Nếu có mục nào chưa đồng ý → ghi issue trong review của file này trước khi đọc tiếp.
