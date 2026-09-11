# Playbook: Tạo Scene & Editorial Prompts

> **Type**: Agent Skill Playbook
> **Agent**: image-prompt-engineer
> **Triggered by**: Khi cần tạo prompts cho editorial, lifestyle, storytelling images — không phải product shots
> **Output**: Document chứa scene prompts sẵn sàng dùng, kèm diversity notes

---

## Khi nào dùng playbook này

- Cần editorial/lifestyle images cho blog posts, case studies, landing page sections
- Cần hero scenes thể hiện emotional value (teamwork, growth, focus, joy)
- Cần ambient/environment photos không focused vào specific product
- Cần illustrative scenes cho onboarding, empty states, error pages
- Cần campaign imagery với human subjects trong bối cảnh thực tế

---

## Procedure

### Bước 1: Đọc context bài viết / campaign

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0, PHASE4

Cần xác định:
□ Topic / narrative cốt lõi (bài viết về gì? campaign message là gì?)
□ Target audience (demographics, profession, geography, life stage)
□ Emotional tone mong muốn (inspiring, calm, dynamic, serious, playful)
□ Usage context (blog header, social post, email, presentation slide)
□ Brand voice: formal / casual / approachable / authoritative
□ Geographic / cultural context của audience
□ Platform đích: Midjourney / DALL-E / Stable Diffusion / Flux
```

### Bước 2: Scene concept — xác định câu chuyện

```
Trả lời 4 câu hỏi để hình thành scene concept:

□ WHO: Ai là nhân vật chính? (age range, role/profession, số lượng)
   → Mô tả đặc điểm cụ thể, không để AI default sang stereotypes
□ WHAT: Họ đang làm gì? (action cụ thể, không vague như "working")
   → "người phụ nữ 35 tuổi đang trình bày slide trước nhóm nhỏ 3 người"
   thay vì "businesswoman presenting"
□ WHERE: Bối cảnh cụ thể (loại không gian, thời điểm trong ngày)
□ WHY: Cảm xúc hoặc kết quả được thể hiện (vui, tập trung, hợp tác)

Viết 1-2 câu scene description trước khi bắt đầu build prompt.
```

### Bước 3: Setting và environment

```
Specify environment đủ cụ thể để AI không default sang generic:

□ Loại không gian:
  - Interior: "modern open-plan office với natural light, exposed concrete ceiling"
  - Exterior: "rooftop terrace của building thương mại, thành phố phía sau"
  - Home: "home office với bookshelf, warm afternoon light"
  - Neutral: "clean minimal studio with white background" (khi không cần context)

□ Time of day → ảnh hưởng lighting:
  - Morning: soft directional light, fresh atmosphere
  - Midday: even bright light, productive energy
  - Late afternoon: warm golden tones, contemplative mood
  - Evening: artificial warm lights, intimate atmosphere

□ Cultural anchoring nếu region-specific:
  - Architecture style phù hợp region (không dùng generic Western office cho Đông Nam Á)
  - Clothing phù hợp climate và cultural norms
  - Không exotic hóa môi trường của non-Western subjects

Tham khảo inclusive-visuals-specialist nếu cần cultural accuracy review.
```

### Bước 4: Subject(s) và activity

```
Describe subjects với sufficient specificity để tránh AI stereotypes:

□ Age range cụ thể (thay vì "young" hay "old"): "mid-30s", "late 50s"
□ Appearance: natural, không idealized — "curly hair", "wearing glasses"
□ Clothing: phù hợp profession và context, authentic (không "generic suit")
□ Expression: genuine, không stock-photo-smile
   → "focused expression, slight smile, making eye contact với colleague"
□ Body language: action-based, tự nhiên
   → "leaning forward slightly, hand on keyboard, looking at second monitor"

Nếu có nhiều người:
□ Specify số lượng rõ (2, 3, small group)
□ Yêu cầu diversity trong age, appearance (invoke inclusive-visuals-specialist)
□ Tránh hierarchical positioning stereotypes (ai đứng, ai ngồi, ai "trung tâm")
```

### Bước 5: Lighting và mood

```
Lighting quyết định emotional tone của scene:

□ Soft natural light → calm, trustworthy, approachable
   "Diffused natural light from large windows, no harsh shadows, even skin illumination"

□ Golden hour / warm → inspirational, human, warm brand
   "Late afternoon golden light raking from left, warm 3200K color temperature,
    long soft shadows, rich atmospheric quality"

□ Bright editorial → energetic, modern, confident
   "Bright even studio lighting, clean whites, minimal shadow, commercial photography"

□ Moody dramatic → serious topics, depth, storytelling
   "Low-key lighting, single key light from side, deep shadows in background,
    cinematic quality, cool color temperature"

□ Environmental → documentary, authentic
   "Available light, mixed sources (window + overhead), realistic office illumination,
    slight grain, documentary feel"

Kỹ thuật quan trọng: Specify lighting phải suitable for diverse skin tones —
không được dùng setup làm "wash out" light skin hoặc "lose detail" trong dark skin.
```

### Bước 6: Camera angle và focal length analog

```
Camera perspective định hình cảm giác và power dynamics:

□ Eye-level: neutral, equal, relatable
   → Dùng khi muốn audience feel "cùng level" với subjects
□ Slightly above eye-level: overview, clarity, professional
   → Editorial standard cho most business content
□ Low angle: empowering, aspirational (dùng có chủ đích)
□ Over-shoulder POV: intimate, narrative, first-person feel

Focal length analog:
□ 35mm: wide context, environment cũng quan trọng, slight narrative feel
□ 50mm: natural perspective, most like human eye, versatile
□ 85mm: portrait standard, subject-focused, background compression
□ 135mm: strong compression, subject isolated, editorial quality

Depth of field:
□ f/1.4–2: Subject isolated, soft background (emotional portrait)
□ f/4–5.6: Subject sharp, environment readable (editorial)
□ f/8: Group + environment đều sharp (story-driven)
```

### Bước 7: Style — photography, illustration, hoặc mixed

```
Chọn style theo brand và use case:

□ Documentary photography: authentic, real, slightly imperfect
   → "candid photography, available light, slight motion, natural expressions"
□ Editorial photography: polished, styled, intentional
   → "editorial photography, art directed, magazine quality, clean backgrounds"
□ Illustration: controllable, scalable, culturally neutral
   → "flat design illustration, simple shapes, brand color palette"
□ Photo-illustration hybrid: thể hiện concept abstract + human element
   → "person in foreground photo-real, abstract geometric data visualization overlay"
□ Painterly/artistic: brand phù hợp (creative, education, art platform)
   → "digital painting, soft brushwork, impressionistic lighting"

Khi dùng illustration: đặc biệt chú ý diversity trong character design.
```

### Bước 8: Diversity và inclusion considerations

```
BẮT BUỘC: Invoke inclusive-visuals-specialist khi có human subjects.

Trước khi hoàn thiện prompt, verify:
□ Representation inventory: age/gender/race/ability/body type có diverse không?
□ Không default sang: young White/East Asian, slim, abled, Western-dressed
□ Không tokenism: không chỉ add "one person of color" vào otherwise homogeneous group
□ Power dynamics: ai centered? ai peripheral? có phản ánh stereotype không?
□ Cultural accuracy: clothing, environment, props phù hợp cultural context

Chuyển draft prompt cho inclusive-visuals-specialist review trước khi finalize.
Ghi nhận suggestions và update prompt accordingly.
```

### Bước 9: Negative prompts

```
Core negative prompts (luôn include):
"no stock photo smiles, no fake expressions, no plastic-looking skin,
 no text or watermarks, no logos, no generic suits, no obvious AI artifacts,
 no uncanny valley faces"

Thêm context-specific negatives:
□ Corporate editorial: "no motivational poster clichés, no staged handshakes"
□ Tech/Office: "no glass office stereotypes, no all-male team"
□ Diversity-focused: "no clone faces, no tokenism positioning"
□ Outdoor/nature: "no oversaturated filters, no HDR"
□ Cultural-specific: "no Westernized environment, no exotic framing"

Platform syntax:
- Midjourney: thêm "--no [terms]" hoặc dùng negative weighting
- Stable Diffusion: negative prompt field riêng
- DALL-E / Flux: tích hợp vào prompt dạng "avoid: ..."
```

### Bước 10: Platform optimization

```
Finalize technical specs:

| Platform        | Optimization                                          |
|----------------|-------------------------------------------------------|
| Midjourney     | --ar [ratio] --v 6 --style raw --chaos 10 --q 2       |
| DALL-E 3       | Narrative prompt, specify style explicitly            |
| Stable Diffusion | (keyword:weight) syntax, negative prompt field      |
| Flux           | Long-form descriptive prompt, photorealistic emphasis |

Aspect ratios theo use case:
□ Blog header: 16:9 hoặc 2:1
□ Social (LinkedIn/Twitter): 1.91:1
□ Instagram: 1:1 hoặc 4:5
□ Email: 2:1 hoặc 3:1
□ Presentation slide: 16:9

Nếu cần variation prompts: tạo 2-3 variants với thay đổi nhỏ
(lighting, camera angle) để team có lựa chọn.
```

### Bước 11: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase4-ux/image-prompts/scene-prompts.md

Cấu trúc output:
1. Scene Brief (narrative intent, audience, emotional tone)
2. Diversity Notes (representation decisions và rationale)
3. Prompts theo use case (label: Blog Header / Social / Campaign / etc.)
4. Negative prompts (core + context-specific)
5. Platform variants (nếu cần multi-platform)
6. Inclusive Visuals Review Status (đã consult hay chưa)
```

---

## Checklist trước khi submit

```
□ Scene concept được articulate rõ (who, what, where, why)
□ Subjects được mô tả đủ cụ thể — tránh vague "businessperson"
□ Lighting specification suitable for diverse skin tones
□ Camera angle và focal length được chỉ định
□ Inclusive-visuals-specialist đã review (nếu có human subjects)
□ Negative prompts đủ mạnh — no stock smiles, no clone faces
□ Platform syntax đúng cho target platform
□ Aspect ratio đúng cho use case
□ Cultural context accurate (environment, clothing, architecture)
```
