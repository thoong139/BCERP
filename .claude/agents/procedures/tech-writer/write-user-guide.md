# Playbook: Viết User Guide

> **Type**: Agent Skill Playbook
> **Agent**: tech-writer
> **Triggered by**: Khi cần viết user guide hoặc manual cho end users
> **Output**: User guide document tại `.mc-data/docs/phase6-deployment/user-guide-[module].md`

---

## Khi nào dùng playbook này

- Sau khi feature implementation hoàn thành và QA approved
- Khi cần onboarding documentation cho end users hoặc admin
- Khi existing guide cần update sau major feature changes
- Pre-deployment để chuẩn bị support team và end users

---

## Procedure

### Bước 1: Đọc feature specs và UX flows

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE2 (features), PHASE4 (UX)
READ: tech-writing-patterns.md (Divio system, writing guidelines, user guide template)

Thu thập:
□ Feature specs từ phase2-features/
□ UX flows và wireframes từ phase4-ux/
□ Acceptance criteria (dùng để verify guide đủ)
□ REQ-IDs liên quan
□ Known edge cases và error messages từ developer
□ Screenshots hoặc mockups (nếu có)
```

### Bước 2: Audience identification

Xác định chính xác ai đọc guide này — quyết định tone, depth, và vocabulary:

```markdown
## Audience Analysis

**Primary audience**: [End user / Admin / Power user / IT admin]

| Attribute | Detail |
|-----------|--------|
| Technical level | [Non-technical / Some technical / Technical] |
| Domain knowledge | [Beginner / Intermediate / Expert] |
| Goal khi đọc | [Learn how to do X / Troubleshoot Y / Setup Z] |
| Context | [First-time setup / Daily use / Occasional reference] |

**Audience-specific decisions**:
- Technical jargon level: [None / Minimal with explanation / Full]
- Screenshot density: [Heavy (non-tech) / Moderate / Light (tech-savvy)]
- Step detail level: [Every click / Key steps / High level]
```

Nếu có nhiều audience, tạo sections riêng biệt theo audience, không trộn lẫn.

### Bước 3: Task-based structure

Organize theo tasks người dùng cần làm, KHÔNG theo features hoặc UI components:

```
SAI: "Chapter 3: The Settings Panel"
ĐÚNG: "Chapter 3: Configuring Your Account"

SAI: "Button Overview"
ĐÚNG: "How to Export Your Data"
```

Tạo table of contents theo task structure:

```markdown
## Nội dung

### Phần 1: Bắt đầu
1.1 Đăng ký tài khoản
1.2 Thiết lập lần đầu
1.3 Giới thiệu giao diện chính

### Phần 2: Công việc hàng ngày
2.1 [Task A quan trọng nhất]
2.2 [Task B]
2.3 [Task C]

### Phần 3: Tính năng nâng cao
3.1 [Advanced task 1]
3.2 [Advanced task 2]

### Phần 4: Quản trị (Admin only — nếu có)
4.1 [Admin task 1]
4.2 [Admin task 2]

### Phần 5: Xử lý sự cố
5.1 Các lỗi thường gặp
5.2 Câu hỏi thường gặp (FAQ)

### Tài liệu tham khảo
- Glossary
- Phím tắt
- Liên hệ hỗ trợ
```

### Bước 4: Step-by-step instructions — numbered, actionable verbs

Format chuẩn cho mỗi task:

```markdown
## [Tên task — động từ + object, ví dụ: "Tạo đơn hàng mới"]

[REQ-ID: REQ-[DEPT]-[NNN]]

[1 câu mô tả task này làm gì và khi nào cần dùng]

**Trước khi bắt đầu**: [Prerequisites nếu có — ví dụ: cần có quyền Admin, cần có dữ liệu X]

### Các bước

1. **Mở** menu [Tên menu] ở góc trên bên trái.

2. **Chọn** [Tên option] từ danh sách xuất hiện.

3. **Điền** thông tin vào form:
   - **Tên khách hàng** (bắt buộc): Nhập tên đầy đủ
   - **Email** (bắt buộc): Phải là địa chỉ email hợp lệ
   - **Số điện thoại** (tùy chọn): Định dạng +84xxxxxxxxx

4. **Nhấn** nút **Lưu** màu xanh ở cuối form.

5. **Xác nhận** khi hệ thống hiển thị thông báo "Đã tạo thành công".

[Screenshot placeholder: Hình chụp màn hình sau bước 4, highlight nút Lưu]

**Kết quả**: [Mô tả điều gì xảy ra sau khi hoàn thành — ví dụ: "Đơn hàng mới xuất hiện trong danh sách với trạng thái 'Đang xử lý'"]
```

Quy tắc viết steps:
- Bắt đầu mỗi step bằng động từ hành động (Mở, Chọn, Nhập, Nhấn, Xác nhận)
- Một step = một hành động duy nhất
- Bold tên UI elements: nút, menu, tab, field names
- Không dùng "click" — dùng "nhấn" hoặc "chọn" (mobile-friendly)

### Bước 5: Screenshots và diagrams placeholders

Đánh dấu rõ vị trí cần screenshot để designer/developer cung cấp:

```markdown
[Screenshot cần: Trang tổng quan sau khi đăng nhập lần đầu. Highlight: thanh điều hướng bên trái, vùng content chính, nút thêm mới ở góc trên phải]

[Diagram cần: Luồng duyệt đơn hàng — từ trạng thái "Mới" → "Đang xử lý" → "Hoàn thành"/"Hủy"]
```

Khi đã có screenshot thực tế:
```markdown
![Trang tổng quan hệ thống](screenshots/dashboard-overview.png)
*Hình 1: Trang tổng quan — (1) Thanh điều hướng, (2) Vùng thống kê nhanh, (3) Danh sách gần đây*
```

Quy tắc screenshot:
- Caption mỗi screenshot giải thích CÁI GÌ đang được thể hiện
- Dùng số hoặc mũi tên highlight elements quan trọng
- Không screenshot khi UI chưa final — placeholder tốt hơn screenshot sai

### Bước 6: Warning và tip callouts

Sử dụng callouts để highlight thông tin quan trọng — KHÔNG trộn vào body text:

```markdown
> **Lưu ý**: [Thông tin cần biết nhưng không nguy hiểm — ví dụ: "Thao tác này không thể hoàn tác"]

> **Quan trọng**: [Có thể gây mất dữ liệu hoặc lỗi nếu không chú ý]

> **Mẹo**: [Shortcut hoặc cách làm nhanh hơn — optional nhưng hữu ích]

> **Ví dụ**: [Ví dụ cụ thể giúp hiểu rõ hơn]
```

Không lạm dụng: Nếu mọi paragraph đều có callout, callout mất hiệu lực. Tối đa 1-2 callouts per section.

### Bước 7: Troubleshooting section

Format mỗi issue theo triệu chứng (không phải theo tên kỹ thuật):

```markdown
## Xử lý sự cố

### Không đăng nhập được

**Triệu chứng**: Nhấn nút Đăng nhập nhưng không vào được, hoặc thấy thông báo lỗi.

**Nguyên nhân thường gặp và cách xử lý**:

| Thông báo lỗi | Nguyên nhân | Cách xử lý |
|---------------|-------------|-----------|
| "Sai mật khẩu" | Nhập sai mật khẩu | Kiểm tra Caps Lock, thử Quên mật khẩu |
| "Tài khoản bị khóa" | Nhập sai quá 5 lần | Liên hệ Admin để mở khóa |
| "Phiên đăng nhập hết hạn" | Không hoạt động 30 phút | Đăng nhập lại |
| Trang trắng / không tải được | Kết nối mạng | Kiểm tra kết nối internet |

**Nếu vẫn không được**: Liên hệ hỗ trợ kỹ thuật tại [email/link].

---

### [Issue 2]: [Tên theo triệu chứng user thấy]

...
```

### Bước 8: Glossary

Giải thích thuật ngữ chuyên ngành hoặc terminology đặc thù của hệ thống:

```markdown
## Từ điển thuật ngữ

| Thuật ngữ | Giải thích |
|-----------|-----------|
| **Đơn hàng** | Yêu cầu mua hàng từ khách, có trạng thái từ Mới đến Hoàn thành |
| **Phiếu nhập** | Tài liệu ghi nhận hàng hóa nhận vào kho |
| **SKU** | Mã định danh duy nhất cho từng sản phẩm hoặc biến thể |
| **Admin** | Người dùng có quyền quản trị toàn bộ hệ thống |
```

Quy tắc: Chỉ giải thích terms thực sự cần giải thích. Không giải thích "Email", "Password", v.v.

### Bước 9: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase6-deployment/user-guide-[module].md

Cấu trúc output:
1. Giới thiệu (Đây là tài liệu gì, ai nên đọc)
2. Table of Contents
3. Phần 1: Bắt đầu
4. Phần 2-N: Tasks theo module
5. Troubleshooting
6. Glossary
7. Thông tin hỗ trợ (contact, ticket system)
```

---

## Checklist trước khi submit

```
□ Audience được xác định rõ ràng ngay đầu document
□ Structure theo tasks, không theo UI components
□ Mọi steps dùng actionable verbs (Mở, Chọn, Nhập, Nhấn)
□ UI elements được bold nhất quán
□ Screenshots có caption mô tả CÁI GÌ đang được thể hiện
□ Troubleshooting theo triệu chứng, không theo error code kỹ thuật
□ REQ-IDs được reference trong task sections
□ Không có jargon không được giải thích trong Glossary
□ Liên hệ hỗ trợ được cung cấp ở ít nhất 2 nơi
```

---

## Lưu ý kỹ thuật

- **Divio classification**: User guide là "How-to guide" — không trộn tutorial hoặc reference
- **Mobile users**: Dùng "chọn" / "nhấn" thay "click", mô tả steps work trên cả desktop lẫn mobile
- **Localization**: Nếu guide cần dịch, tránh idioms và wordplay khó dịch
- **Version pinning**: Ghi rõ version của sản phẩm tài liệu này áp dụng
