# Playbook: Tạo Product & UI Visuals Prompts

> **Type**: Agent Skill Playbook
> **Agent**: image-prompt-engineer
> **Triggered by**: Khi cần tạo prompts cho product screenshots, app mockups, marketing visuals, app store assets
> **Output**: Document chứa image generation prompts sẵn sàng dùng

---

## Khi nào dùng playbook này

- Cần tạo hero images, feature screenshots cho landing page
- Cần app mockups hoặc UI screenshots cho app store (Google Play, App Store)
- Cần product visuals cho marketing campaigns, social cards, email headers
- Cần consistent visual set cho một product line hoặc feature release

---

## Procedure

### Bước 1: Đọc brand guidelines và product context

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE4 (UX design), PHASE3 (architecture)

Cần xác định:
□ Brand color palette (primary, secondary, accent, neutrals)
□ Typography — font families chính của brand
□ Brand personality (minimalist, playful, enterprise, warm, tech-forward)
□ Product name và category (SaaS dashboard, mobile app, e-commerce, B2B tool)
□ Target audience (age group, profession, region)
□ Existing visual references hoặc mood board (nếu có)
□ Platform đích: Midjourney / DALL-E / Stable Diffusion / Flux
```

### Bước 2: Định nghĩa Subject — xác định chính xác cần show gì

```
Trả lời 3 câu hỏi:
□ PRIMARY SUBJECT: Sản phẩm / tính năng cụ thể nào đang được thể hiện?
   Ví dụ: "analytics dashboard với bar chart hiển thị revenue trends"
□ CONTEXT DEVICE: Hiển thị trên device nào? (MacBook Pro, iPhone 15, tablet, browser chrome)
□ USAGE MOMENT: Ai đang dùng, trong bối cảnh gì?
   Ví dụ: "không có người" (clean product shot) vs "tay người dùng đang scroll"

Lưu ý: Mô tả product UI cụ thể — không dùng placeholder text.
Dùng "sales funnel visualization với 4 stages" thay vì "dashboard screen".
```

### Bước 3: Chọn style phù hợp

```
Map product type → style khuyến nghị:

| Product Type        | Style khuyến nghị                              |
|---------------------|------------------------------------------------|
| B2B SaaS / Enterprise | Clean photorealistic, neutral backgrounds, device mockup |
| Consumer mobile app | Lifestyle integration, bright colors, real hands |
| E-commerce          | Studio product shot, clean white/gradient backdrop |
| Creative tool       | Vibrant, hands-on, artistic environment        |
| Healthcare / Finance | Professional, soft neutral, trustworthy lighting |

Quyết định: photorealistic / 3D render / illustration / mixed
```

### Bước 4: Composition và framing

```
Chọn shot type theo mục đích sử dụng:

□ Hero image (landing page): 3/4 perspective device mockup, environment background
   → "MacBook Pro at 30-degree angle, screen showing [UI], blurred office background"
□ Feature highlight: Close-up của specific UI element, high contrast
   → "Extreme close-up of toggle button interaction, soft rim lighting"
□ App store screenshot: Full device frame, portrait orientation, minimal background
   → "iPhone 15 Pro frame, portrait, white background, drop shadow"
□ Social card (1200×630): Wide composition, text-safe zones
   → "Centered device mockup, gradient background, left 40% clear for text overlay"
□ Email header (600px wide): Horizontal, balanced composition
   → "Side-by-side before/after comparison, clean white background"

Composition rule: Quan trọng nhất ở vị trí optical center (40% từ top).
```

### Bước 5: Lighting setup

```
Chọn lighting dựa trên brand personality:

□ Enterprise / Professional:
   "Soft diffused studio lighting, even illumination, no harsh shadows,
    cool neutral color temperature (5500K)"

□ Modern / Tech-forward:
   "Subtle gradient backlight, soft rim light creating depth,
    screen glow contributing ambient light, deep shadow"

□ Warm / Consumer / Lifestyle:
   "Natural window lighting from left, warm color temperature (4000K),
    golden hour quality, organic shadow"

□ Premium / Luxury:
   "Low-key lighting with single key light, dramatic shadows,
    rich contrast, dark neutral background"

Luôn specify: key light direction + fill ratio + background treatment.
```

### Bước 6: Color palette alignment với brand

```
Extract từ brand guidelines:
□ Primary brand color → dominant accent trong image
□ Background: solid / gradient / transparent / environment photo
□ Screen UI colors: phải match actual UI được implemented
□ Atmospheric color grade: warm/cool/neutral?

Ví dụ color instruction trong prompt:
"Dominant brand blue (#1E40AF) on screen, warm cream (#FFF8F0) surface,
 subtle teal gradient background, overall warm-neutral color grade"
```

### Bước 7: Background choices

```
Quyết định background theo context:

□ Transparent/White: App store screenshots, docs, dark mode compatibility
   → "Pure white background, subtle drop shadow below device"
□ Gradient: Landing pages, social media
   → "Soft linear gradient from pale blue-gray to white, 135 degrees"
□ Environment: Lifestyle shots, emotional connection
   → "Modern coworking space, shallow depth of field, natural daylight"
□ Abstract/Geometric: Techy, modern brand
   → "Abstract low-poly mesh background, brand colors, subtle depth"

Tránh: busy patterns làm mất focus khỏi product.
```

### Bước 8: Text overlay considerations

```
□ Xác định vùng safe cho text overlay (thường left hoặc right 40%)
□ Nếu image sẽ có text overlay → instruct clear/blurred background tại vùng đó
□ Negative prompt: "no text, no labels, no watermarks, no UI text visible"
   (text trong AI image thường bị distorted — thêm text trong Figma/Canva)
□ Nếu cần số/stat trên screen → mô tả tổng quát, không yêu cầu AI render text chính xác

Lưu ý: Tuyệt đối không yêu cầu AI render readable text — kết quả sẽ gibberish.
```

### Bước 9: Platform-specific format considerations

```
Xác định platform output:

| Format           | Aspect Ratio | Midjourney param | Ghi chú               |
|-----------------|--------------|------------------|-----------------------|
| Hero image      | 16:9         | --ar 16:9        | landscape             |
| App store (iOS) | 9:19.5       | --ar 9:19        | portrait              |
| Social card     | 1.91:1       | --ar 191:100     | Open Graph standard   |
| Instagram post  | 1:1          | --ar 1:1         | square                |
| Instagram story | 9:16         | --ar 9:16        | full-screen vertical  |
| Email header    | 2:1          | --ar 2:1         | wide landscape        |

Platform quality params:
- Midjourney: --v 6 --style raw --q 2
- DALL-E: "high resolution, professional photography quality"
- Flux: "photorealistic, 8K, sharp details"
```

### Bước 10: Kiểm tra với inclusive-visuals-specialist (nếu có người)

```
Nếu prompt bao gồm người (tay, người dùng, nhân vật):
□ Invoke inclusive-visuals-specialist để review representation
□ Đảm bảo diversity trong age, skin tone, body type
□ Tránh stereotypical "tech worker" default appearance
□ Lighting phù hợp cho diverse skin tones

Nếu product-only (không có người) → skip bước này.
```

### Bước 11: Prompt construction

```
Ghép tất cả layers theo cấu trúc chuẩn:

TEMPLATE:
[Subject: device type + product description + specific UI elements] |
[Composition: angle, framing, shot type] |
[Lighting: setup, direction, color temperature, quality] |
[Background: type, color/environment] |
[Style: photorealistic/3D/illustration, aesthetic reference] |
[Color: palette alignment, grade] |
[Technical: aspect ratio, render quality] |
[Negative: unwanted elements]

Ví dụ hoàn chỉnh:
"MacBook Pro 14-inch at 30-degree angle, screen displaying clean SaaS analytics
 dashboard with bar charts in brand blue, minimal UI, open space composition |
 Soft studio lighting from upper left, 5500K color temperature, subtle screen glow,
 clean neutral shadow | Gradient background from pale blue-gray (#EFF6FF) to white |
 Photorealistic product photography, Apple product aesthetic | Sharp device details,
 soft background blur f/8 equivalent | --ar 16:9 --v 6 --style raw --q 2 |
 negative: text, labels, watermarks, people, clutter, busy background"
```

### Bước 12: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase4-ux/image-prompts/product-visuals.md

Cấu trúc output:
1. Brief Summary (mục đích visual set, platform targets)
2. Style Guide áp dụng (extracted từ brand)
3. Prompts theo từng format (label rõ: Hero / App Store / Social / Email)
4. Negative prompts chung (reusable)
5. Platform-specific params
6. Usage notes (where to add text, safe zones)
```

---

## Checklist trước khi submit

```
□ Mỗi prompt có đủ 5 layers: Subject, Environment, Lighting, Technical, Style
□ Brand colors được reference cụ thể (hex hoặc description)
□ Aspect ratios đúng cho từng platform
□ Negative prompts bao gồm: no text, no watermarks
□ Nếu có người trong image → inclusive-visuals-specialist đã review
□ Không yêu cầu AI render readable text trong UI
□ Platform-specific syntax đã apply (--ar, --v params cho Midjourney v.v.)
```
