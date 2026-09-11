# Playbook: Phát triển Brand Identity

> **Type**: Agent Skill Playbook
> **Agent**: brand-guardian
> **Triggered by**: /wf-design hoặc /wf-design-ux khi project cần xây dựng brand identity
> **Output**: `.mc-data/docs/phase4-ux/brand/brand-identity-guide.md`

---

## Khi nào dùng playbook này

- Phase 0-4 khi dự án cần xây dựng brand identity từ đầu
- Khi stakeholder yêu cầu: brand strategy, visual identity, brand voice, color palette, typography system
- Khi project là sản phẩm mới (new brand) hoặc rebranding
- Khi cần define visual language cho design system

---

## Procedure

### Bước 1: Đọc business context và target audience

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE1, PHASE2

Cần xác định:
□ Loại sản phẩm (SaaS, E-commerce, Mobile App, B2B platform...)
□ Business model (B2B / B2C / B2B2C)
□ Target audience: demographics, psychographics, pain points
□ Industry / vertical (Healthcare, Fintech, Retail, EdTech...)
□ Competitive landscape: đối thủ dùng brand strategy gì?
□ Brand personality kỳ vọng từ stakeholders (nếu có gợi ý)
□ Existing brand assets (nếu có) — màu sắc, logo, fonts đang dùng
```

### Bước 2: Brand Positioning

Dựa trên context đã đọc, xác định:

```
Brand Positioning Framework:
□ Unique Value Proposition (UVP): Thương hiệu giải quyết vấn đề gì
   khác biệt so với đối thủ?
□ Brand Personality: Chọn 3-5 traits từ các nhóm:
   - Sincerity: genuine, honest, cheerful, wholesome
   - Excitement: daring, imaginative, innovative, spirited
   - Competence: reliable, intelligent, successful, efficient
   - Sophistication: elegant, prestigious, glamorous
   - Ruggedness: tough, strong, outdoorsy, rugged
□ Brand Voice Adjectives: 3 tính từ mô tả cách thương hiệu "nói chuyện"
□ Positioning Statement:
   "Với [target audience], [brand name] là [category] duy nhất
   [benefit chính] vì [reason to believe]."
```

### Bước 3: Logo Usage Guidelines

Tạo spec cho logo system (dạng text spec, không phải file design):

```markdown
## Logo System Spec

### Variations
- Primary logo: [Mô tả — wordmark, icon+wordmark, emblem, etc.]
- Secondary / Horizontal variant: [Mô tả]
- Icon-only / Favicon variant: [Mô tả]
- Monochrome (white): Dùng trên background tối
- Monochrome (dark): Dùng khi không in màu

### Clear Space
- Minimum clear space = [X]px (thường = chiều cao chữ cái 'x' của wordmark)
- Không đặt nội dung khác trong vùng clear space

### Minimum Size
- Print: không nhỏ hơn 20mm chiều rộng
- Digital: không nhỏ hơn 120px chiều rộng
- Favicon/Icon: 32px × 32px

### Logo Don'ts (liệt kê các vi phạm phổ biến)
- Không stretch hoặc squish tỷ lệ
- Không thêm drop shadow hoặc outline
- Không thay đổi màu ngoài bộ màu được phê duyệt
- Không đặt trên background có độ tương phản thấp
- Không thêm text hoặc graphic vào trong clear space
- Không dùng gradient ngoài brand gradient đã quy định (nếu có)
```

### Bước 4: Color Palette

Xây dựng hệ thống màu 3 lớp. Với MỖI màu, bắt buộc kiểm tra WCAG contrast:

```markdown
## Color System

### Primary Palette
| Tên | Hex | RGB | Dùng cho |
|-----|-----|-----|---------|
| Primary | #[hex] | rgb() | CTA buttons, links, brand accent |
| Primary Dark | #[hex] | rgb() | Hover states, active states |
| Primary Light | #[hex] | rgb() | Backgrounds, tints |

WCAG Check Primary:
- Primary (#hex) trên White (#FFFFFF): contrast ratio [X]:1 → AA Pass/Fail
- White (#FFFFFF) trên Primary (#hex): contrast ratio [X]:1 → AA Pass/Fail

### Secondary Palette
| Tên | Hex | RGB | Dùng cho |
|-----|-----|-----|---------|
| Secondary | #[hex] | rgb() | Supporting elements, illustrations |
| Secondary Dark | #[hex] | rgb() | |
| Secondary Light | #[hex] | rgb() | |

### Neutral Palette
| Tên | Hex | Scale | Dùng cho |
|-----|-----|-------|---------|
| Neutral 50 | #[hex] | Lightest | Page backgrounds |
| Neutral 100 | #[hex] | | Card backgrounds |
| Neutral 300 | #[hex] | | Borders, dividers |
| Neutral 500 | #[hex] | Mid | Placeholder text |
| Neutral 700 | #[hex] | | Secondary text |
| Neutral 900 | #[hex] | Darkest | Primary text |

### Semantic Colors (Functional)
| Tên | Hex | Dùng cho | WCAG vs White |
|-----|-----|---------|---------------|
| Success | #[hex] | Thành công, confirmed, online | [X]:1 |
| Warning | #[hex] | Cảnh báo, cần chú ý | [X]:1 |
| Error | #[hex] | Lỗi, destructive actions | [X]:1 |
| Info | #[hex] | Thông tin trung tính | [X]:1 |

LƯU Ý: Semantic colors PHẢI đạt WCAG AA (4.5:1 cho text thường,
3:1 cho text lớn và UI components) khi ghép với background màu trắng.
```

### Bước 5: Typography System

```markdown
## Typography System

### Font Selection
- Heading Font: [Tên font] — [Lý do chọn: geometric, humanist, slab-serif...]
  Fallback stack: [font1], [font2], sans-serif
- Body Font: [Tên font] — [Lý do chọn]
  Fallback stack: [font1], [font2], sans-serif
- Code/Monospace Font (nếu cần): [Tên font]
  Fallback stack: 'Courier New', Courier, monospace

### Type Scale
| Step | Role | Size | Weight | Line Height | Letter Spacing |
|------|------|------|--------|-------------|----------------|
| Display | Hero headings | 48-72px | 700-800 | 1.1 | -0.02em |
| H1 | Page title | 36px | 700 | 1.2 | -0.01em |
| H2 | Section title | 28px | 600 | 1.25 | 0 |
| H3 | Subsection | 22px | 600 | 1.3 | 0 |
| H4 | Card title | 18px | 600 | 1.35 | 0 |
| Body LG | Lead paragraph | 18px | 400 | 1.6 | 0 |
| Body | Default text | 16px | 400 | 1.6 | 0 |
| Body SM | Secondary text | 14px | 400 | 1.5 | 0 |
| Caption | Labels, meta | 12px | 400 | 1.4 | 0.01em |
| Overline | Category tags | 11px | 500 | 1.4 | 0.08em (uppercase) |

### Web Implementation
- Load strategy: Preconnect → Preload critical weights → Font-display: swap
- Self-host nếu có yêu cầu GDPR (tránh Google Fonts external request)
- Variable font ưu tiên nếu font hỗ trợ (giảm số lượng file cần load)
```

### Bước 6: Iconography Style

```markdown
## Iconography Guidelines

### Style Direction
Chọn 1 trong các phong cách và nhất quán:
- Outline (Stroke): Nhẹ, tinh tế, modern — phù hợp SaaS, fintech
- Filled: Đậm, dễ nhận biết — phù hợp mobile, B2C
- Duotone: 2 màu, có chiều sâu — phù hợp marketing, creative tools

### Specifications
- Grid: 24×24px (standard), 16×16 (compact), 32×32 (featured)
- Stroke width: 1.5px (outline style)
- Corner radius: 2px cho góc vuông, 50% cho đường tròn
- Format: SVG, viewBox="0 0 24 24"

### Library Reference
- Khuyến nghị dùng [Heroicons / Phosphor / Lucide / custom] để đảm bảo consistency
- Tất cả custom icons phải theo cùng grid và stroke width
```

### Bước 7: Photography và Illustration Style

```markdown
## Visual Content Style

### Photography Direction
- Mood: [Ví dụ: Authentic, candid, warm light — tránh stock photo giả tạo]
- Subject: [Ví dụ: Real people using product, workplace environments]
- Color grading: [Ví dụ: Warm tones, slight desaturation, consistent filter]
- Composition: [Ví dụ: Negative space for text overlay, rule of thirds]
- Avoid: [Ví dụ: Cheesy posed shots, excessive retouching, cliché imagery]

### Illustration Style (nếu dùng)
- Style direction: [Flat, isometric, line art, 3D render...]
- Color palette: Phải dùng brand color palette
- Complexity level: [Simple và clean / Detailed và rich]
- Consistency rule: Tất cả illustrations trong cùng 1 visual language
```

### Bước 8: Motion và Animation Guidelines

```markdown
## Motion & Animation Principles

### Brand Motion Personality
[Ví dụ: Precise và purposeful — animations phục vụ chức năng, không phô trương]

### Timing Tokens
| Token | Duration | Easing | Dùng cho |
|-------|----------|--------|---------|
| Instant | 0ms | — | Toggle states không cần animation |
| Micro | 100ms | ease-out | Hover, focus rings |
| Standard | 200ms | ease-in-out | Dropdown, tooltip, button states |
| Enter | 300ms | cubic-bezier(0, 0, 0.2, 1) | Elements xuất hiện |
| Exit | 200ms | cubic-bezier(0.4, 0, 1, 1) | Elements biến mất |
| Deliberate | 500ms | spring | Onboarding, success celebrations |

### Performance Rules
- Chỉ animate transform và opacity (GPU-accelerated)
- Tránh animate width, height, top, left (trigger layout reflow)
- Tôn trọng prefers-reduced-motion: wrap animations trong media query
```

### Bước 9: Brand Voice và Tone Examples

```markdown
## Brand Voice & Tone

### Voice Characteristics (nhất quán dù ai viết)
- [Trait 1 — Ví dụ: Knowledgeable nhưng không arrogant]: Giải thích rõ ràng, dùng
  ngôn ngữ đơn giản, tránh jargon không cần thiết
- [Trait 2 — Ví dụ: Warm nhưng không suồng sã]: Friendly, conversational,
  không dùng slang hoặc informal language quá mức
- [Trait 3 — Ví dụ: Confident nhưng không hống hách]: Statements rõ ràng,
  tránh hedging language quá nhiều ("maybe", "might", "could be")

### Tone Variations theo Context
| Context | Tone | Ví dụ |
|---------|------|-------|
| Marketing copy | Inspiring, energetic | "Transform the way your team works." |
| Onboarding | Warm, encouraging | "You're all set. Let's get started." |
| Error messages | Clear, helpful | "Something went wrong. Try refreshing — it usually helps." |
| Empty states | Friendly, actionable | "No projects yet. Create your first one in 30 seconds." |
| Success messages | Brief, affirming | "Invoice sent." |
| Warning/Danger | Direct, calm | "This will permanently delete your data." |

### Vocabulary Guidelines
- Dùng: [List từ ngữ phù hợp với brand personality]
- Tránh: [List từ ngữ không phù hợp, generic, hoặc off-brand]
- Viết hoa: [Brand name, product names] — nhất quán trong mọi tài liệu
```

### Bước 10: Ghi output

```
OUTPUT PATH: .mc-data/docs/phase4-ux/brand/brand-identity-guide.md

Cấu trúc file output:
1. Header: Tên thương hiệu + version + ngày tạo
2. Brand Positioning (UVP, personality, positioning statement)
3. Logo System (variations, clear space, min size, don'ts)
4. Color Palette (primary, secondary, neutral, semantic + WCAG table)
5. Typography System (fonts, scale, implementation)
6. Iconography (style, specs, library)
7. Photography & Illustration Style
8. Motion & Animation Guidelines
9. Brand Voice & Tone (characteristics, variations, vocabulary)
10. Quick Reference Card (1-page summary cho team)
```

---

## Checklist trước khi submit

```
□ Brand positioning statement rõ ràng và khác biệt với đối thủ
□ Logo don'ts list đủ chi tiết để team tránh vi phạm
□ Tất cả màu trong palette đã kiểm tra WCAG contrast ratio
□ Semantic colors (success/warning/error/info) đạt WCAG AA vs white
□ Typography scale đủ các cấp từ Display xuống Caption
□ Brand voice có ví dụ cụ thể theo từng context (error, success, onboarding)
□ Motion guidelines có prefers-reduced-motion consideration
□ File output ghi vào đúng path: .mc-data/docs/phase4-ux/brand/brand-identity-guide.md
```
