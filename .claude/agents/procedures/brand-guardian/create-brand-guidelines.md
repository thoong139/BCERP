# Playbook: Tạo Brand Guidelines Document

> **Type**: Agent Skill Playbook
> **Agent**: brand-guardian
> **Triggered by**: Khi cần tạo brand guidelines chính thức cho team hoặc stakeholders
> **Output**: `.mc-data/docs/phase4-ux/brand/brand-guidelines.md`

---

## Khi nào dùng playbook này

- Sau khi đã có `brand-identity-guide.md` (cần chạy `develop-brand-identity.md` trước)
- Khi cần tài liệu brand guidelines để chia sẻ với team design, team dev, external partners
- Khi onboarding designer mới hoặc agency cần brand reference
- Khi chuẩn bị go-live và cần official brand documentation

---

## Procedure

### Bước 1: Compile Brand Assets Inventory

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: đọc .mc-data/docs/phase4-ux/brand/brand-identity-guide.md

Kiểm kê những gì đã có:
□ Logo files (variations, formats) — ghi chú path hoặc storage location
□ Color palette (approved hex values, CSS variables)
□ Font files hoặc Google Fonts / Adobe Fonts links
□ Icon library (tên thư viện hoặc custom asset path)
□ Photography assets (nếu có)
□ Illustration assets (nếu có)
□ Brand templates (email, presentation, document)
□ Brand voice guidelines (nếu đã document riêng)

Nếu brand-identity-guide.md không tồn tại → DỪNG, hỏi user:
"Brand identity chưa được xây dựng. Cần chạy develop-brand-identity trước."
```

### Bước 2: Viết Brand Story và Positioning

```markdown
## Brand Story & Positioning

### Lý do tồn tại (Brand Purpose)
[Không phải là "kiếm tiền" — mà là tác động có ý nghĩa với người dùng và thị trường]

### Tầm nhìn (Brand Vision)
[Thế giới sẽ như thế nào nếu thương hiệu thành công hoàn toàn?]

### Sứ mệnh (Brand Mission)
[Thương hiệu đang làm gì, cho ai, để đạt được vision đó?]

### Giá trị cốt lõi (Brand Values)
Mỗi value phải có:
- Tên ngắn gọn
- Định nghĩa rõ ràng
- Biểu hiện hành vi cụ thể (thương hiệu làm gì / không làm gì vì value này)

Ví dụ format:
**Đơn giản hóa**: Chúng tôi tin rằng công nghệ phức tạp nên ẩn sau trải
nghiệm đơn giản. Chúng tôi không bao giờ thêm tính năng chỉ để thêm —
mỗi quyết định đều phải làm người dùng dễ dàng hơn, không phải ngược lại.

### Brand Personality
3-5 traits mô tả thương hiệu như một con người:
[Trait]: [Biểu hiện trong sản phẩm và truyền thông]

### Positioning Statement
"Với [target audience], [brand name] là [category frame]
duy nhất [primary benefit] vì [reason to believe]."
```

### Bước 3: Document Visual Identity — Usage và Misuse Examples

Đây là phần khác biệt quan trọng nhất trong brand guidelines: phải có cả ví dụ sai để team tránh:

```markdown
## Visual Identity

### 3.1 Logo System

#### Cách dùng đúng
| Variant | Khi dùng | Background được phép |
|---------|----------|----------------------|
| Primary (full color) | Trên white/light neutral backgrounds | White, Neutral 50-100 |
| White version | Trên dark backgrounds, ảnh tối | Primary, Secondary, Neutral 700-900 |
| Dark version | In đen trắng, emboss | N/A |
| Icon only | Favicon, app icon, very small sizes | Any (với contrast đủ) |

#### Misuse Examples (liệt kê cụ thể — càng cụ thể càng tốt)
- KHÔNG: Kéo dài hoặc nén logo theo chiều ngang/dọc
- KHÔNG: Đặt logo trên ảnh chụp có nhiều chi tiết mà không có overlay
- KHÔNG: Thêm gradient lên logo trừ khi brand gradient được phê duyệt
- KHÔNG: Thay màu logo bằng màu ngoài bộ được phê duyệt
- KHÔNG: Đặt text hoặc graphic chạm vào vùng clear space
- KHÔNG: Dùng logo cũ (version trước khi rebrand)
- KHÔNG: Tạo logo animation ngoài animation đã phê duyệt

#### Clear Space Rule
Minimum clear space = [X] — tính bằng [ví dụ: chiều cao chữ "O" trong wordmark]
Minh họa: [Mô tả vị trí padding bằng text, ví dụ: "padding = 1× chiều cao icon"]

#### Minimum Size
- Digital: [X]px chiều rộng
- Print: [X]mm chiều rộng

---

### 3.2 Color System

#### Primary Palette
| Color | Name | Hex | RGB | Dùng cho |
|-------|------|-----|-----|---------|
| [swatch description] | Primary | #[hex] | rgb([r],[g],[b]) | CTAs, links, key brand moments |
| | Primary Dark | #[hex] | | Hover, active states |
| | Primary Light | #[hex] | | Tinted backgrounds, highlights |

#### Secondary Palette
[Tương tự format trên]

#### Neutral Palette
| Scale | Hex | Dùng cho |
|-------|-----|---------|
| 50 | #[hex] | Page background |
| 100 | #[hex] | Card, panel background |
| 200 | #[hex] | Subtle borders |
| 300 | #[hex] | Dividers |
| 400 | #[hex] | Disabled elements |
| 500 | #[hex] | Placeholder, secondary icons |
| 600 | #[hex] | Secondary text |
| 700 | #[hex] | Body text |
| 800 | #[hex] | Headings |
| 900 | #[hex] | Display text, darkest |

#### Semantic Colors
| Color | Hex | Contrast vs White | Dùng cho |
|-------|-----|-------------------|---------|
| Success | #[hex] | [X]:1 (AA Pass) | Thành công, confirmed, active |
| Warning | #[hex] | [X]:1 | Cảnh báo, cần xem lại |
| Error | #[hex] | [X]:1 | Lỗi, destructive, hủy |
| Info | #[hex] | [X]:1 | Thông tin trung tính |

#### Color Don'ts
- KHÔNG: Dùng màu ngoài palette đã phê duyệt trong UI
- KHÔNG: Chỉ dùng màu để truyền thông tin (phải có text/icon kèm theo — WCAG 1.4.1)
- KHÔNG: Đặt text màu nhạt trên background nhạt (vi phạm WCAG contrast)
- KHÔNG: Mix semantic colors (ví dụ: dùng Success green cho highlight không liên quan đến thành công)

---

### 3.3 Typography

#### Font Families
| Role | Font | Fallback stack |
|------|------|----------------|
| Heading | [Font Name] | [fallback1], [fallback2], sans-serif |
| Body | [Font Name] | [fallback1], [fallback2], sans-serif |
| Code (nếu có) | [Font Name] | 'Courier New', Courier, monospace |

#### Type Scale
[Copy từ brand-identity-guide.md — Display, H1 xuống Caption]

#### Typography Rules
- KHÔNG: Dùng font-weight không phải 400 / 500 / 600 / 700 (chỉ dùng weights đã chọn)
- KHÔNG: Dùng font-size ngoài type scale (không có 15px, 17px, 21px)
- KHÔNG: Uppercase tùy tiện (uppercase chỉ dùng cho Overline và specific UI labels)
- KHÔNG: Viết text dài bằng UPPERCASE (khó đọc)

---

### 3.4 Iconography

#### Style và Specs
- Style: [Outline / Filled / Duotone]
- Sizes: 16×16, 24×24, 32×32
- Stroke width: [X]px (cho outline style)
- Library: [Tên thư viện — ví dụ: Heroicons 2.0]

#### Icon Rules
- KHÔNG: Mix icons từ các thư viện khác nhau
- KHÔNG: Scale icon lên kích thước lớn mà không có filled/feature variant
- KHÔNG: Thêm màu vào icons khi không cần thiết (icons thường inherit màu text)
```

### Bước 4: Document Brand Voice

```markdown
## Brand Voice

### Voice vs Tone: Sự khác biệt
- **Voice**: Nhất quán dù ai viết, dù context nào — đây là "tính cách" của thương hiệu
- **Tone**: Thay đổi theo context (vui vẻ hơn trong onboarding, nghiêm túc hơn khi báo lỗi)

### Voice Characteristics

Với mỗi characteristic, cần có cả ví dụ đúng và ví dụ sai:

**[Characteristic 1 — ví dụ: Clear and direct]**
Viết rõ ràng, không vòng vo, không dùng corporate jargon.
- ĐÚNG: "Xóa tài khoản sẽ xóa vĩnh viễn tất cả dữ liệu của bạn."
- SAI: "Việc tiến hành thực hiện xóa tài khoản sẽ dẫn đến việc các dữ liệu liên quan được xóa bỏ khỏi hệ thống một cách vĩnh viễn và không thể phục hồi."

**[Characteristic 2 — ví dụ: Helpful, not preachy]**
Hỗ trợ người dùng, không phán xét hay giáo huấn.
- ĐÚNG: "Mật khẩu phải có ít nhất 8 ký tự."
- SAI: "Để bảo vệ tài khoản của bạn, bạn nên luôn luôn sử dụng mật khẩu mạnh với ít nhất 8 ký tự."

**[Characteristic 3 — ví dụ: Warm without being informal]**
Thân thiện và gần gũi mà vẫn chuyên nghiệp.
- ĐÚNG: "Chào mừng bạn quay lại."
- SAI (quá formal): "Kính chào Quý khách hàng."
- SAI (quá informal): "Yo! Mày lại đến rồi!"

### Tone Variations

| Situation | Tone | Ví dụ |
|-----------|------|-------|
| Marketing copy | Aspirational, energetic | "Làm chủ workflow của bạn." |
| Onboarding | Warm, encouraging, guiding | "Tuyệt vời! Bước cuối cùng — nhập thông tin team của bạn." |
| Error message | Calm, helpful, non-blaming | "Không thể lưu. Kiểm tra kết nối mạng rồi thử lại." |
| Success | Brief, affirming | "Đã lưu." / "Đã gửi thành công." |
| Empty state | Friendly, actionable | "Chưa có dữ liệu. Tạo mục đầu tiên →" |
| Destructive confirmation | Clear, direct | "Xóa vĩnh viễn 3 tệp? Không thể hoàn tác." |
| Warning | Informative, calm | "Phiên làm việc sẽ hết hạn sau 5 phút." |

### Vocabulary Reference

**Dùng:**
- [Từ/cụm từ phù hợp brand personality — ví dụ: "đơn giản", "nhanh chóng", "chính xác"]

**Tránh:**
- [Generic words: "giải pháp toàn diện", "hệ sinh thái", "leverage", "synergy"]
- [Jargon không cần thiết với target audience]

**Spelling/Naming conventions (nhất quán):**
- [Tên sản phẩm]: luôn viết [Đúng] — không viết [Sai]
- [Tên tính năng]: luôn viết [Đúng]
```

### Bước 5: Digital Application Guidelines

```markdown
## Digital Application Guidelines

### Web Application
- Header height: [X]px (desktop), [X]px (mobile)
- Max content width: [X]px
- Sidebar width: [X]px
- Primary CTA button: Primary color, [radius]px border-radius
- Form labels: Body SM font, Neutral 700
- Input borders: Neutral 300 (default), Primary (focus), Error (error state)

### Mobile App (nếu có)
- Follow platform conventions: iOS HIG / Material Design — với brand customization
- Bottom tab bar: White background, Primary màu icon active
- Primary action: Full-width button, Primary color, [X]px height
- Safe area: Luôn respect iOS safe area và Android status bar

### Email Templates
- Max width: 600px (email client compatibility)
- Header background: Brand primary hoặc white
- Font trong email: Web-safe stack (Arial, Georgia — không dùng custom font)
- CTA button: Brand primary, px-based padding (không % trong email)
- Footer: Include unsubscribe link, company address (CAN-SPAM compliance)
- Logo trong email: PNG với 2x resolution, inline hoặc hosted URL

### Social Media (nếu có)
- Profile image: Icon-only logo trên brand primary background
- Cover image: Brand visual với tagline
- Post image template: Luôn có logo clear space, dùng brand colors
```

### Bước 6: Partner và Vendor Usage Guidelines

```markdown
## Partner & Vendor Brand Usage

### Khi ai đó muốn dùng logo/brand của chúng tôi

#### Được phép
- Mention brand name trong text khi reference đến sản phẩm
- Dùng approved logo asset (lấy từ [nguồn chính thức])
- "Powered by [Brand]" badge trong approved format

#### Không được phép mà không có approval
- Thay đổi logo dưới bất kỳ hình thức nào
- Dùng brand name hoặc logo để ngụ ý partnership/endorsement không có thật
- Đặt logo cạnh competitor's logo theo cách gây nhầm lẫn
- Tạo derivative brand assets

#### Quy trình xin sử dụng
1. Liên hệ [email/contact]
2. Cung cấp context sử dụng và mockup
3. Chờ approval — SLA [X] ngày làm việc
```

### Bước 7: Approval Process cho Brand Deviations

```markdown
## Brand Deviation Process

### Khi nào được phép request deviation
- Campaign đặc biệt (seasonal, event-specific) cần visual treatment khác
- Co-branding với partner có brand riêng
- Platform-specific constraint (ví dụ: app store icon phải flat, không có drop shadow)

### Quy trình approval
1. **Submitter**: Chuẩn bị mockup deviation + rationale viết rõ lý do
2. **Review**: Brand Guardian review trong [X] ngày làm việc
3. **Decision**: Approve / Approve with conditions / Reject + feedback
4. **Documentation**: Deviation được approve → ghi vào exceptions log

### Không thể request deviation (hard rules)
- Dùng màu ngoài brand palette cho logo
- Vi phạm WCAG AA contrast (accessibility là non-negotiable)
- Thay đổi wordmark/logo shape
```

### Bước 8: Ghi output

```
OUTPUT PATH: .mc-data/docs/phase4-ux/brand/brand-guidelines.md

Cấu trúc file output (tổng hợp tất cả sections):
1. Header: Brand Guidelines v[X.X] | Ngày cập nhật | Maintainer
2. Quick Start (1 trang summary cho người mới)
3. Brand Story & Positioning
4. Visual Identity
   4.1 Logo System (usage + misuse examples)
   4.2 Color System (palette + WCAG table + don'ts)
   4.3 Typography (scale + rules + don'ts)
   4.4 Iconography
5. Brand Voice
   5.1 Voice Characteristics (với examples đúng/sai)
   5.2 Tone Variations (by context)
   5.3 Vocabulary Reference
6. Digital Application Guidelines (Web, Mobile, Email, Social)
7. Partner & Vendor Usage
8. Brand Deviation Process
9. Changelog (version history)
```

---

## Checklist trước khi submit

```
□ Đã đọc brand-identity-guide.md làm source of truth
□ Mỗi visual rule có cả ví dụ đúng và ví dụ sai (misuse)
□ Tất cả màu có hex value chính xác và WCAG contrast ratio
□ Brand voice có ví dụ cụ thể theo từng context (error, success, onboarding, warning)
□ Email guidelines có web-safe font fallbacks (không phải custom font)
□ Partner usage guidelines rõ ràng: được phép vs cần approval vs không được
□ Deviation process có SLA cụ thể
□ File có version number và ngày cập nhật
□ File output ghi vào đúng path: .mc-data/docs/phase4-ux/brand/brand-guidelines.md
```
