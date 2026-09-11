# Engineering - Tech Writing Patterns

> **Domain**: Engineering / Technical Writing
> **Last Updated**: 2026-03-15

---

## 1. Divio Documentation System

Phân loại documentation theo mục đích — **KHÔNG BAO GIỜ trộn lẫn**:

| Loại | Hướng tới | Mục đích | Ví dụ |
|------|-----------|----------|-------|
| **Tutorials** | Học tập | "Sau bài này, bạn sẽ hiểu X" | Getting Started, First App |
| **How-to Guides** | Thực hiện task | "Cách làm Y bằng Z" | Deploy to production, Add auth |
| **Reference** | Tra cứu thông tin | API endpoints, config options | API docs, Schema reference |
| **Explanation** | Hiểu sâu lý do | Tại sao thiết kế như vậy, trade-offs | Architecture decisions, Concepts |

Mỗi trang documentation chỉ phục vụ MỘT mục đích. Nếu trang có cả tutorial lẫn reference → tách ra.

---

## 2. Documentation Types Matrix

| Type | Audience | Purpose | Divio Category |
|------|----------|---------|---------------|
| API Docs | Developers | Integration guide | Reference |
| User Guide | End Users | How to use | How-to Guide |
| Tutorial | New Users | Learn concepts | Tutorial |
| Admin Guide | Administrators | Configuration | How-to Guide |
| Release Notes | All | What's new | — |
| Knowledge Base | End Users | Self-service | Explanation |
| Architecture Decisions | Developers | Understand why | Explanation |

---

## 3. Output Templates

### API Documentation

```markdown
# API Documentation: [API Name]

## Overview
[Brief description of the API]

## Base URL
https://api.example.com/v1

## Authentication
[Authentication method and examples]

## Endpoints

### [GET/POST/PUT/DELETE] /endpoint

**Description**: [What this endpoint does]
**REQ-ID**: [Related requirement]

**Request**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| field1 | string | Yes | Description |

**Response** (200 OK):
```json
{ "data": {}, "message": "Success" }
```

**Error Responses**:
| Code | Description |
|------|-------------|
| 400 | Bad Request |
| 401 | Unauthorized |
| 404 | Not Found |

**Example**:
```bash
curl -X GET "https://api.example.com/v1/endpoint" \
  -H "Authorization: Bearer token"
```
```

---

### User Guide Template

```markdown
# User Guide: [Feature Name]

## Overview
[Brief description for end users]

## Prerequisites
- Requirement 1

## Getting Started

### Step 1: [Action]
[Instructions with screenshots]

## Common Tasks

### Task 1: [Name]
1. Step 1
2. Step 2

## Troubleshooting
| Problem | Solution |
|---------|----------|

## FAQ
**Q: [Question]**
A: [Answer]
```

---

### Release Notes Template

```markdown
# Release Notes - Version X.Y.Z

**Release Date**: YYYY-MM-DD

## Highlights
[Key features and improvements]

## New Features
| Feature | Description | REQ-ID |
|---------|-------------|--------|

## Improvements
| Improvement | Description |
|-------------|-------------|

## Bug Fixes
| Bug | Description |
|-----|-------------|

## Breaking Changes
| Change | Migration Guide |
|--------|-----------------|

## Known Issues
| Issue | Workaround |
|-------|------------|

## Upgrade Instructions
1. Step 1
2. Step 2
```

---

### README Template

Mọi README phải pass **5-second test**: Đây là gì? Tại sao cần? Bắt đầu thế nào?

```markdown
# [Tên Dự án]

[Một câu mô tả dự án giải quyết vấn đề gì — KHÔNG phải mô tả kỹ thuật]

## Tại sao cần [Tên Dự án]?
[1-2 đoạn giải thích pain point mà dự án giải quyết]

## Cài đặt
[Hướng dẫn ngắn gọn nhất để chạy được]

## Cấu hình
| Biến | Mô tả | Mặc định | Bắt buộc |
|------|-------|----------|----------|

## Sử dụng nhanh
[Code example ngắn nhất cho use case phổ biến nhất]

## Tài liệu chi tiết
[Link đến docs site]
```

---

### Tutorial Template

```markdown
# Tutorial: [Điều bạn sẽ xây dựng] trong [Thời gian ước tính]

**Bạn sẽ xây dựng**: [Mô tả + screenshot/demo]
**Bạn sẽ học**: [Danh sách bullet]
**Yêu cầu trước**: [Checklist tools/kiến thức cần có]

## Bước 1: [Tiêu đề]
[TẠI SAO trước, rồi mới CÁCH LÀM]
[Code block với output mong đợi]

## Tổng kết
[Recap những gì đã học, link đến bước tiếp theo]
```

---

## 4. Docs-as-Code

Documentation được quản lý như source code — versioned, reviewed, và deployed tự động.

### Documentation Pipelines

- **Docusaurus**: Phù hợp cho project React/JavaScript, hỗ trợ MDX, versioning, i18n tích hợp sẵn
- **MkDocs**: Phù hợp cho Python projects, cấu hình đơn giản qua `mkdocs.yml`, theme Material phổ biến
- **VitePress**: Phù hợp cho Vue/Vite ecosystem, build nhanh, static site tối ưu

### API Reference Automation

OpenAPI/Swagger spec là nguồn duy nhất để sinh API docs:
- Viết spec trước (spec-first), sau đó generate code stubs và docs đồng thời
- Tools: `redoc-cli`, `swagger-ui`, `openapi-generator` để tạo interactive documentation
- Docs được regenerate tự động mỗi khi spec thay đổi — không cần viết tay

### CI/CD Integration

- Outdated docs fail the build — nếu code thay đổi API mà không cập nhật spec, CI block merge
- Link checker chạy tự động: broken links = build failure
- Doc preview deploy trên mỗi pull request để reviewer có thể đọc trước khi approve

### Versioned Documentation

- Mỗi minor/major release tạo snapshot doc mới (ví dụ: `/docs/v2.1/`, `/docs/v3.0/`)
- "Latest" luôn trỏ đến stable release mới nhất
- Deprecated versions vẫn accessible nhưng có banner cảnh báo

---

## 5. Writing Guidelines

### Style
- Use active voice
- Be concise and clear
- Use simple language (8th grade reading level)
- Include examples
- Code examples phải chạy được — test trước khi publish

### Structure
- Start with overview
- Use headings and lists
- Include table of contents for long docs
- Add cross-references
- Một concept per section — không gộp nhiều chủ đề

### Formatting
- Use code blocks for code
- Use tables for structured data
- Include screenshots where helpful
- Use callouts for important info

---

## 6. Content Architecture (Advanced)

- **Information architecture**: Phân loại nội dung theo mental model của người dùng, không theo cấu trúc internal của team. Sử dụng card sorting để validate navigation labels.
- **Progressive disclosure**: Đặt thông tin theo tầng — overview → getting started → deep dive → reference.
- **Doc site navigation**: Sidebar tối đa 2 cấp độ. Breadcrumb cho phép định hướng. Search phải là first-class feature.
- **Search optimization**: Thêm metadata tags, aliases cho thuật ngữ hay bị nhầm lẫn.

---

## 7. API Documentation Excellence

- **OpenAPI/Swagger best practices**: Mỗi field có `description`, `example`, và constraints. Response schema đầy đủ cho cả success và error cases. Dùng `$ref` để tái sử dụng schema.
- **Interactive API explorers**: Tích hợp Swagger UI hoặc Redoc để developer có thể thử trực tiếp từ trang docs.
- **SDK documentation**: Mỗi SDK method có docstring, type signature, và ít nhất một code example.
- **Code sample quality**: Cung cấp samples cho ít nhất 3 ngôn ngữ phổ biến (JavaScript, Python, cURL). Sample phải realistic — không dùng `foo`/`bar`.

---

## 8. Documentation Analytics

- **Measuring doc effectiveness**: Kết hợp page views, time-on-page, và scroll depth để xác định trang nào người đọc bỏ dở.
- **Heatmaps**: Dùng heatmap tool (Microsoft Clarity) để xem người đọc click và scroll đến đâu.
- **Search analytics**: Theo dõi search queries không trả về kết quả — đây là danh sách topics cần bổ sung.
- **Feedback loops**: Đặt widget "Was this helpful? Yes / No" cuối mỗi trang.
- **A/B testing doc formats**: Thử nghiệm hai cách trình bày. Đo conversion để chọn format hiệu quả hơn.

---

## 9. Content Debt Tracking

| URL/Page | Lần review cuối | Accuracy Score | Traffic | Action |
|----------|-----------------|----------------|---------|--------|
| | | | | |

Review quarterly — trang có accuracy < 80% hoặc traffic cao nhưng outdated → ưu tiên cập nhật.

---

## 10. Chỉ số Thành công

| Chỉ số | Mục tiêu | Cách đo |
|--------|----------|---------|
| Documentation coverage | 100% public APIs có docs | Đếm endpoints vs. endpoints có description |
| Doc freshness | Cập nhật trong vòng 1 sprint sau code change | Ngày commit code vs. ngày cập nhật doc |
| Support ticket reduction | Giảm 30% tickets "how to" | So sánh ticket volume trước và sau |
| Time to first success | Developer mới onboard trong <15 phút | Đo thời gian từ Quick Start đến "Hello World" |
| Zero broken links | 0 broken links | Link checker tự động trong CI |
