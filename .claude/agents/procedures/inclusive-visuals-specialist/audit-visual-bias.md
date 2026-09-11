# Playbook: Audit Visual Bias

> **Type**: Agent Skill Playbook
> **Agent**: inclusive-visuals-specialist
> **Triggered by**: Khi cần review AI-generated images hoặc image prompts cho bias trước khi publish
> **Output**: Visual Bias Audit Report kèm actionable prompt corrections

---

## Khi nào dùng playbook này

- Trước khi approve bất kỳ AI-generated image nào có human subjects
- Khi image-prompt-engineer hoàn thành draft prompts có người
- Khi team review batch assets từ campaign production
- Khi có complaint hoặc concern về representation trong visual đang dùng
- Khi onboard project có existing image library cần audit

---

## Procedure

### Bước 1: Đọc context — product, audience, market

```
INPUT: Paths do skill cung cấp qua prompt + draft prompts từ image-prompt-engineer

Cần xác định:
□ Product / service là gì? Dùng cho ai?
□ Primary market geography (Đông Nam Á, châu Âu, Bắc Mỹ, toàn cầu?)
□ Target audience demographics (age range, profession, income level, culture)
□ Usage context của image (marketing, app UI, editorial, onboarding)
□ Brand values liên quan đến inclusion (có equity commitments không?)
□ Platform phân phối (website, social, app store, internal)

Lý do: Context định nghĩa "appropriate representation" —
một prompt tốt cho thị trường Bắc Âu có thể thiếu sót cho thị trường Việt Nam.
```

### Bước 2: Representation inventory

```
Với mỗi image / prompt, lập bảng kiểm kê:

| Chiều đa dạng    | Hiện tại trong prompt/image | Đủ diverse? |
|-----------------|------------------------------|-------------|
| Age range       | [ghi cụ thể]                 | Y / N / N/A |
| Apparent gender | [ghi cụ thể]                 | Y / N / N/A |
| Skin tone range | [ghi cụ thể]                 | Y / N / N/A |
| Body type       | [ghi cụ thể]                 | Y / N / N/A |
| Ability         | [ghi cụ thể]                 | Y / N / N/A |
| Clothing/style  | [ghi cụ thể]                 | Y / N / N/A |
| Cultural markers| [ghi cụ thể]                 | Y / N / N/A |

Quy tắc đánh giá:
□ "Diverse" không có nghĩa mọi chiều phải 50/50
□ "Appropriate" dựa trên actual audience và use case
□ Single-subject images: đánh giá theo pattern — nếu mọi single-subject image
  đều default "young slim light-skinned" → đó là systemic bias, dù từng image "fine"
```

### Bước 3: Bias detection checklist (5 bias types)

```
Kiểm tra từng bias type:

BIAS 1: Clone Faces
□ Có nhiều người trong scene không?
□ Nếu có → prompt có "distinct facial structures, varied ages, different features" không?
□ Nếu image đã generated → các khuôn mặt có distinct không?
□ Nếu lỗi: Add "each person with distinct facial features, varied bone structure, different ages"

BIAS 2: Gibberish Text
□ Prompt có yêu cầu AI render text không? (tên, số, label, signage)
□ Nếu có → ĐÂY LÀ VẤN ĐỀ — AI không render readable text chính xác
□ Fix: Negative prompt "no text, no written words, no signage, no logos"
   + Hướng dẫn thêm text trong Figma/Canva sau generation

BIAS 3: Hero-Symbol (exoticizing via symbols)
□ Prompt có yêu cầu cultural symbols không? (traditional dress, religious items, landmarks)
□ Nếu có → symbols có chiếm ưu thế so với human subject không?
□ Nếu symbols là focal point thay vì human moment → đây là exoticizing
□ Fix: Reframe để human action là focal point, symbols là background context

BIAS 4: Exoticizing
□ Lighting và framing có "lạ hóa" subject không?
   → High-saturation "exotic" filter trên non-Western subjects
   → "Ethnic" framing (dramatic lighting chỉ khi subject là người màu)
   → Environment overdramatic và "foreign" so với subject's actual lived reality
□ Fix: Mandate natural, respectful lighting. Anchor subjects trong actual lived environment.

BIAS 5: Tokenism
□ Có add "one diverse person" vào otherwise homogeneous group không?
□ "Diverse" person có same age, body type, styled similarly như nhóm majority không?
□ Fix: Yêu cầu intersectional variance: "varied age ranges, body types, hair textures,
   attire styles within the group — authentic to their actual professional context"
```

### Bước 4: Power dynamics analysis

```
Với group images hoặc narrative scenes:

□ Ai centered trong composition? Ai ở periphery?
   → Subject ở center thường perceived là authority/protagonist
□ Ai đứng? Ai ngồi? Ai "active"? Ai "passive"?
   → Stereotypical: manager (đứng, light-skinned) → staff (ngồi, darker skin)
□ Ai có eye contact với camera? Ai bị cropped hay half-visible?
□ Ai có professional props (laptop, clipboard)? Ai không?
□ Nếu phát hiện hierarchical visual storytelling phản ánh stereotype:
   → Rewrite composition description explicitly

Ví dụ correction:
Before: "team meeting, manager presenting at whiteboard"
After: "three colleagues in collaborative discussion, no hierarchical positioning,
       each engaged and contributing, equal visual weight in composition"
```

### Bước 5: Cultural accuracy check

```
Nếu image có cultural specificity (region, ethnicity, religion):

□ Clothing: authentic cho actual culture, không phải "generic ethnic wear"
   → Áo dài Việt Nam có các style khác nhau; không phải mọi người Việt đều mặc áo dài
□ Environment / architecture: geographically correct
   → Không dùng generic "Asian city" (mix Japan + China + SE Asia)
□ Hair texture: accurate và được rendered với dignity
   → Natural coils, locs, braids — không softened/straightened trong rendering
□ Religious/cultural accessories: worn naturally, không displayed as exotic prop
□ Seasonal/climate appropriateness: clothing phù hợp weather của region được depicted

Cross-reference với actual knowledge nếu cần — không assume.
Flag uncertainty: "Cần verify với người từ [community] trước khi approve"
```

### Bước 6: Actionable rewrite suggestions

```
Với mỗi vấn đề phát hiện, cung cấp:

FORMAT PER ISSUE:
- Bias Type: [tên bias]
- Severity: HIGH / MEDIUM / LOW
- Observed: [mô tả vấn đề cụ thể trong prompt/image]
- Impact: [tại sao đây là vấn đề]
- Corrected Prompt Segment: [đoạn prompt đã sửa]
- Negative Constraints Added: [negative prompts mới]

Severity guidelines:
HIGH: Stereotype rõ ràng, cultural insensitivity, tokenism overt — BLOCK approval
MEDIUM: Missed opportunity for diversity, could be improved — FLAG for revision
LOW: Suboptimal but not harmful — NOTE for future iterations
```

### Bước 7: Severity rating tổng hợp và kết luận

```
Tổng hợp:
□ Đếm HIGH / MEDIUM / LOW issues
□ Xác định verdict:
   APPROVED: Không có HIGH issues, MEDIUM ≤ 2 với corrections đã apply
   NEEDS REVISION: Có HIGH issues hoặc MEDIUM > 2 — trả về image-prompt-engineer với corrections
   REJECTED: Fundamental representation failures — cần concept mới hoàn toàn

Pattern observation (nếu audit batch):
□ Có systemic bias pattern không? (tất cả images đều thiếu một nhóm nào đó?)
□ Recommend guidelines update nếu phát hiện systemic issue
```

### Bước 8: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase4-ux/inclusive-visuals/bias-audit-[date].md

Cấu trúc output:
1. Audit Summary (scope, date, verdicts overview)
2. Per-asset findings (representation inventory + bias checklist)
3. Power dynamics notes
4. Cultural accuracy flags
5. Corrected prompts (full rewrite nơi cần)
6. Overall pattern observations
7. Recommendations cho guidelines update nếu cần
```

---

## Checklist trước khi submit

```
□ Representation inventory đã lập cho mỗi asset
□ 5 bias types đã checked: Clone Faces, Gibberish Text, Hero-Symbol, Exoticizing, Tokenism
□ Power dynamics đã analyzed với group images
□ Cultural accuracy đã flagged (không assume — verify khi uncertain)
□ Mỗi issue có Severity rating
□ Corrected prompt segments được cung cấp (không chỉ nêu vấn đề)
□ Verdict rõ ràng: APPROVED / NEEDS REVISION / REJECTED
□ Nếu APPROVED với conditions — conditions được ghi rõ
```
