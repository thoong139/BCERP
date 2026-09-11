<!-- From shared-protocols.md lines 296-461 (§6 + §6.1-6.6, EXCLUDING template content extracted to templates/digest.template.md) -->
# Protocol 6 — Token Limit Prevention

## 6.1 Nguyên tắc cơ bản

```
QUY TẮC:
- Registry update: Main conversation trực tiếp — KHÔNG spawn agent
- Report generation: Agent OK (output nhỏ)
- Large JSON operations: Read → modify in memory → Write
```

## 6.2 Agent Input Compression (BẮT BUỘC khi agent cần >3 files)

Khi một agent cần đọc >3 files làm input, PHẢI dùng pattern sau:

```
// Main conversation thực hiện TRƯỚC KHI spawn agent:
FOR each file IN input_files:
  key_info = Grep(file, pattern="^##|REQ-|Quy trình|Yêu cầu|→")
  summaries[file] = key_info  // ~100-200 từ/file

// Agent prompt nhận summary, không nhận full file:
"Input digest: [summaries]
Nếu cần chi tiết cụ thể về một section, đọc file tại [path] — chỉ section cần thiết."
```

**Khi nào áp dụng:**

| Tình huống | Input files | Pattern |
|-----------|------------|---------|
| Phase 6b (Cross-dept workflow) | >5 dept files | Pre-compress → agent nhận digest |
| Phase 6c (Stakeholder review) | >5 dept files | Pre-compress → agent nhận digest |
| Phase 6d (Conflict resolution) | Dept files liên quan | Chỉ pass sections chứa conflict |
| Phase 4 (Expert 1 dept) | 1-2 files | OK, không cần compress |
| Phase 3 (BA 1 dept) | 1 template | OK, không cần compress |

## 6.3 Output Size Guidance (BẮT BUỘC)

Mỗi agent prompt PHẢI có dòng output target ở cuối:

| Agent Task | Standard | Large Project Mode (6.6) |
|-----------|----------|--------------------------|
| BA Phần A — 1 dept | ~800–1200 từ | ~1200–2000 từ |
| Domain Expert Phần B — 1 dept | ~1000–1500 từ | ~1500–2500 từ |
| P1-02 Business Workflow | ~2000–3000 từ | ~3000–5000 từ |
| Stakeholder Review (toàn bộ) | ~1500–2500 từ | ~2500–4000 từ |
| Architecture design | ~2000–4000 từ | ~3000–6000 từ |
| Feature spec | ~1000–2000 từ/feature | ~1500–3000 từ/feature |
| Deployment Guide (Mục 1-8) | ~2000–3500 từ | ~3500–5500 từ |

**Luôn thêm dòng này vào cuối mỗi agent prompt:**
```
Output mục tiêu: [target theo bảng]. Súc tích, đủ ý, không lặp context đã biết.
```

> **Ưu tiên chất lượng:** Target là hướng dẫn, không phải hard cap. Nội dung phức tạp thực sự cần nhiều hơn → ưu tiên viết đủ ý. Tuyệt đối không thêm padding hay lặp context để đạt số từ.

## 6.4 Large Doc Analysis Pattern (khi đọc >5 files)

Dùng cho Phase 6b, 6c và bất kỳ stakeholder review nào:

```
THAY VÌ:
  spawn agent → agent tự đọc 13 files → agent tổng hợp (agent context ~60K+)

DÙNG:
  Step 1 — Main conversation đọc từng file, Grep key sections (headers, REQ-IDs, quy trình)
  Step 2 — Tạo "dept-digest.md" (~200 từ/dept × 13 = ~2600 từ tổng)
  Step 3 — Spawn agent với digest làm primary input
  Step 4 — Agent đọc file gốc CHỈ khi cần xác nhận chi tiết cụ thể
  → Agent context giảm từ ~52K xuống ~15K tokens
```

**Tiered Digest Size (chọn theo độ phức tạp doc):**

| Doc Size | Digest Target |
|----------|--------------|
| < 1000 từ | ~150 từ/file |
| 1000–3000 từ | ~200 từ/file (Standard) |
| > 3000 từ HOẶC Large Project Mode | ~300 từ/file (Extended) |

**Standard Digest Format (~200 từ):**
```markdown
### Digest: [name]
- REQ-IDs: REQ-[X]-001 (Bắt buộc), REQ-[X]-002 (Quan trọng), ...
- Quy trình chính: [tên QT-1], [tên QT-2], [tên QT-3]
- Điểm giao với depts khác: [dept-a] (gửi đi), [dept-b] (nhận về)
- Vấn đề nổi bật: [bullet 1-2 câu]
- Nguồn: [file path]
```

**Extended Digest Format (~300 từ — Large Project Mode hoặc docs phức tạp >3000 từ):**
```markdown
### Digest: [name] — Extended
- REQ-IDs: REQ-[X]-001 (BẮT BUỘC), REQ-[X]-002 (QUAN TRỌNG), ... [kèm priority]
- Quy trình chính: [QT-1 (~N bước, mô tả ngắn)], [QT-2], [QT-3]
- Điểm giao: [dept-a → gửi X, trigger Y], [dept-b → nhận Z, phụ thuộc W]
- Constraints: [compliance rules, data invariants, performance SLAs nếu có]
- Vấn đề nổi bật: [Issue 1 (Critical/High)], [Issue 2 (Medium)]
- Tech implications: [external APIs, integration points, system dependencies]
- Nguồn: [file path]
```

> **Standalone template:** `.claude/skills/templates/digest.template.md`

## 6.5 Phased Output Pattern (khi output phase >3000 từ — hoặc >2000 từ với Large Project Mode)

```
THAY VÌ: 1 agent tạo toàn bộ document lớn

DÙNG:
  Pass 1: agent tạo skeleton (section headers + 1-2 câu/section) → ~500 từ
  Pass 2: agents song song điền chi tiết từng section (mỗi section 1 agent, nếu độc lập)
  Main conversation: merge outputs → write file
```

**Áp dụng cho:** P1-02-business-workflow.md, stakeholder-review.md khi project có >8 depts; architecture docs, deployment guide khi Large Project Mode (Protocol 6.6).

## 6.6 Large Project Mode (AUTO-TRIGGER)

> Kích hoạt tự động khi project đủ lớn để thresholds mặc định không đảm bảo chất lượng.
> **Ưu tiên chất lượng > tốc độ** — dự án lớn cần nhiều context hơn, không thể tiết kiệm.

**Trigger conditions** (kiểm tra từ `req-registry.json` tại Phase 0 hoặc Phase 1):

```
LARGE_PROJECT_MODE = True IF ANY:
  systems.length >= 5          // 5+ hệ thống con
  departments.length >= 10     // 10+ phòng ban
  requirements.length >= 50    // 50+ REQ-IDs
  features.length >= 40        // 40+ features
```

**Parameter overrides khi LARGE_PROJECT_MODE = True:**

| Tham số | Standard | Large Project Mode | Lý do |
|---------|----------|--------------------|-------|
| 6.2 — Compression trigger | > 3 files | > 2 files | Files lớn hơn → overflow sớm hơn |
| 6.3 — Output targets | Standard column | Large Project column | Complexity cần space nhiều hơn |
| 6.4 — Digest size | ~200 từ/file | ~300 từ/file (Extended) | Preserve more context |
| 6.5 — Skeleton-first | > 3000 từ | > 2000 từ | Đảm bảo structure trước detail |
| Max agents đồng thời | 5 | 3 | Mỗi agent context nặng hơn — tránh conflict |
| Checkpoint frequency | After major phases | After EVERY phase | Bảo vệ tiến độ dự án lớn |

**Khai báo sử dụng trong skill (bắt buộc với heavy skills):**

```
// Cuối Phase 0 hoặc Phase 1 — sau khi đọc registry:
large_project = (
  registry.systems.length >= 5 OR
  registry.departments.length >= 10 OR
  registry.requirements.length >= 50 OR
  registry.features.length >= 40
)
// Apply overrides vào tất cả bước còn lại của skill
if large_project:
  → digest_size = 300          // Extended Digest Format
  → compression_threshold = 2  // files (thay vì 3)
  → skeleton_threshold = 2000  // words (thay vì 3000)
  → output_targets = "Large Project Mode column"
  → max_parallel_agents = 3
```

**Heavy skills bắt buộc check Protocol 6.6:**
`wf-analyze-requirements`, `wf-define-features`, `wf-design`, `wf-design-ux`, `wf-fix-bugs`, `wf-fix-execute`, `wf-prepare-deployment`
