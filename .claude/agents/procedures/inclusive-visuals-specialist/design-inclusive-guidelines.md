# Playbook: Thiết kế Inclusive Visual Guidelines

> **Type**: Agent Skill Playbook
> **Agent**: inclusive-visuals-specialist
> **Triggered by**: Khi cần tạo visual representation guidelines cho team hoặc project
> **Output**: Inclusive Visual Guidelines document — tài liệu chuẩn cho toàn team

---

## Khi nào dùng playbook này

- Khi bắt đầu dự án mới cần visual identity với human subjects
- Khi team mở rộng và cần codify representation standards
- Khi chuẩn bị production cho marketing campaign lớn
- Khi audit phát hiện systemic bias và cần guidelines mới
- Khi client/stakeholder yêu cầu DEI visual standards chính thức

---

## Procedure

### Bước 1: Đọc product context và audience definition

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE0 (brainstorm), PHASE1 (requirements)

Cần xác định:
□ Product category và mission
□ Actual user demographics (từ requirements, không assume)
□ Geographic markets phục vụ
□ Brand values và equity commitments (nếu có trong docs)
□ Industry context (healthcare, fintech, education, consumer app, B2B)
□ Existing brand guidelines (có rồi → extend, chưa có → start fresh)
□ Distribution channels (website, app, social, print, OOH)

Lý do: Guidelines phải reflect actual audience, không aspirational stereotype
về "typical user". Nếu product phục vụ nông dân Việt Nam — guidelines phải
reflect thực tế của họ, không phải Silicon Valley tech worker.
```

### Bước 2: Define diversity dimensions phù hợp product

```
Không phải mọi dimension đều equally relevant cho mọi product.
Xác định dimensions nào là primary concern:

UNIVERSAL (luôn apply):
□ Age — representation across life stages relevant to product
□ Apparent gender — không default one gender, avoid binary extremes
□ Skin tone range — sử dụng Monk Skin Tone Scale (10 tones) làm reference
□ Body type — avoid exclusively slim, young, abled-body defaults

CONTEXT-DEPENDENT (apply nếu relevant):
□ Disability & accessibility — wheelchair users, prosthetics, hearing aids, visual impairments
□ Socioeconomic markers — clothing, accessories, environment cues
□ Cultural expression — traditional dress, religious attire, hair texture/style
□ Family structures — single parent, same-sex couples, multigenerational
□ Professional backgrounds — không chỉ white-collar office contexts

REGIONAL (apply nếu product có geographic specificity):
□ List specific cultural groups trong target market
□ Identify cultural markers quan trọng với từng group
□ Flag areas cần community consultation

Ghi rõ: "Dimension X là PRIMARY — phải present trong >X% assets"
Ghi rõ: "Dimension Y là SECONDARY — phải appear trong campaign set"
```

### Bước 3: Target representation ratios

```
Định nghĩa ratios cho CAMPAIGN SET (không nhất thiết per-image):

Ví dụ framework:

AGE DISTRIBUTION (trong campaign set):
□ 18-34: [X]% — thể hiện young adult users
□ 35-54: [X]% — core professional segment
□ 55+: [X]% — không invisible, especially nếu product hỗ trợ aging population

SKIN TONE (sử dụng Monk Scale reference):
□ Monk 1-3 (lightest): [X]%
□ Monk 4-6 (medium): [X]%
□ Monk 7-10 (deepest): [X]%
□ Target: >50% Monk 4-10 nếu product phục vụ global audience

ABILITY REPRESENTATION:
□ Visible disability: tối thiểu [X]% của campaign assets có người khuyết tật visible
□ Không ghetto hóa: người khuyết tật xuất hiện trong everyday contexts, không chỉ "disability-themed" images

Lưu ý: Ratios là guidelines, không quota cứng nhắc per-image.
Đánh giá theo campaign set (≥10 images) hoặc asset library quarterly.
```

### Bước 4: Cultural context requirements (region-specific)

```
Với mỗi geographic market được phục vụ:

FORMAT PER MARKET:
Market: [Tên region/country]
Primary cultural groups: [list]
Do (nên làm):
  □ [Specific authentic representation cues]
  □ [Environment/setting phù hợp]
  □ [Clothing/hair/accessory authenticity]
Don't (không làm):
  □ [Common stereotypes cần tránh]
  □ [Exoticizing behaviors]
  □ [Inaccurate cultural mashups]
Local consultation needed for: [list areas uncertain]

Ví dụ cho Việt Nam:
Do: Thể hiện diversity trong người Kinh, Hoa, các dân tộc thiểu số khi relevant.
    Modern urban contexts (Hà Nội, TP.HCM) xen kẽ với suburban/rural.
    Phụ nữ trong professional roles là accurate, không aspirational.
Don't: Mặc áo dài làm "default Vietnamese woman" cho every context.
       Dùng conical hat (nón lá) như generic "Asian" symbol.
       Mix Vietnamese, Chinese, Japanese cultural elements.
Consultation: Ethnic minority representation (Hmong, Tay, Muong, v.v.) cần review thực tế.
```

### Bước 5: Avoiding stereotypes per category

```
Tạo "Stereotype → Authentic Alternative" pairs cho từng major category:

PROFESSIONAL REPRESENTATION:
Stereotype → Alternative
"Kỹ sư = young Asian/White man với laptop" → "Engineers span genders, ages, ethnicities; some remote, some in field"
"Bác sĩ = middle-aged White male" → "Doctors and nurses span genders, skin tones, ages"
"CEO/Leader = tall, slim, suited, light-skinned" → "Leadership looks like: varied, casual-to-formal, all body types"
"Customer service = young woman of color" → "Support staff span genders, ages, all ethnicities equally"

LIFESTYLE REPRESENTATION:
"Active/Athletic = slim, young, light-skinned" → "Movement across body types, ages, abilities"
"Family = nuclear, 2 parents, same ethnicity" → "Multigenerational, single-parent, blended, same-sex couples"
"Elderly = passive, dependent" → "Older adults as active, professional, tech-savvy"
"Disability = inspiration prop" → "Disabled people in everyday professional/social contexts"

CULTURAL REPRESENTATION:
"Non-Western = traditional dress only" → "Mix of traditional and contemporary clothing authentic to lifestyle"
"Muslim woman = oppressed/submissive" → "Muslim women as professionals, leaders, athletes"
"Asian = math/tech only" → "Asian subjects in creative, leadership, manual skill roles"

Thêm product-specific stereotypes vào list dựa trên industry context.
```

### Bước 6: Accessibility trong visuals

```
Accessibility không chỉ là representation — là usability:

ALT TEXT STANDARDS:
□ Không dùng "image of..." hoặc "photo showing..." (redundant với img tag)
□ Mô tả: relevant content first, then visual details nếu cần
□ For decorative images: alt="" (empty, không bỏ attribute)
□ For complex images (charts, diagrams): long description trong caption hoặc aria-describedby
□ Không describe người bằng race/gender trừ khi contextually relevant
□ Format: "[Action/subject] [relevant context] [mood/quality nếu cần]"
   Ví dụ: "Software engineer reviewing code on dual monitors in home office"
   Không phải: "Image of a young Asian woman sitting at a desk with a computer"

COLOR ACCESSIBILITY trong images:
□ Đảm bảo key thông tin không chỉ conveyed bằng color
□ Sufficient contrast nếu image có text overlay
□ Nếu infographic có data visualization: pattern/texture bổ sung màu

MOTION (nếu áp dụng cho animated assets):
□ Không auto-play với flashing >3 times/second
□ Provide pause control
□ Không design motion triggers cho vestibular disorders (spinning, rapid zoom)
```

### Bước 7: Approval process cho visual assets

```
Định nghĩa workflow:

STEP 1: Draft prompt creation
→ image-prompt-engineer tạo prompt
→ inclusive-visuals-specialist review representation plan trước generation

STEP 2: Generation review
→ Generated images qua audit-visual-bias.md checklist
→ Issues documented với severity

STEP 3: Approval tiers
□ GREEN (auto-approve): Đạt 7-point checklist, không HIGH issues
□ YELLOW (stakeholder review): 1-2 MEDIUM issues, corrections applied — brand/comms lead review
□ RED (reject): Bất kỳ HIGH issue nào, hoặc fundamental concept problem

STEP 4: Community validation (cho high-stakes assets)
□ Pre-publish review với representative community members nếu possible
□ Tối thiểu: cross-cultural review với colleague từ represented community
□ Document validation outcome

STEP 5: Archive và pattern tracking
□ Lưu approved prompts vào prompt library
□ Track representation metrics quarterly
□ Flag patterns needing guideline update
```

### Bước 8: Example prompts — inclusive vs non-inclusive

```
Tạo concrete before/after examples phù hợp product context:

FORMAT:
Scenario: [Use case cụ thể]

NON-INCLUSIVE PROMPT:
[Prompt gốc — thiếu sót]
Problem: [Tại sao đây là vấn đề]

INCLUSIVE PROMPT:
[Prompt đã viết lại]
Improvement: [Tại sao tốt hơn]
Negative constraints: [Negative prompts áp dụng]

---
Ví dụ:

Scenario: Hero image cho fintech app landing page

NON-INCLUSIVE:
"Young professional woman smiling at phone, city background"
Problem: Defaults to young + slim + vague ethnicity.
"Professional woman" often renders light-skinned in AI. No age variance.

INCLUSIVE:
"Woman in her early 40s, natural curly hair, business casual attire,
 genuinely focused expression checking banking app on phone,
 modern Southeast Asian city street background, authentic urban environment.
 35mm lens perspective, natural afternoon light, editorial quality."
Negative: "no stock smile, no posed expression, no Westernized city background,
           no text on phone screen, no generic suit"
Improvement: Age specific, appearance specific, emotion authentic,
             environment geographically accurate, no text rendering trap.
```

### Bước 9: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase4-ux/inclusive-visuals/visual-guidelines.md

Cấu trúc output:
1. Executive Summary (scope, markets, key commitments)
2. Diversity Dimensions (primary + secondary + regional)
3. Target Representation Ratios (với measurement methodology)
4. Cultural Context Requirements (per market)
5. Stereotype → Authentic Alternative Reference
6. Accessibility Standards (alt text + color + motion)
7. Approval Workflow
8. Example Prompt Library (inclusive vs non-inclusive pairs)
9. Quarterly Review Checklist
10. Community Consultation Process
```

---

## Checklist trước khi submit

```
□ Diversity dimensions được define dựa trên actual product audience — không generic
□ Representation ratios realistic và measurable
□ Mỗi geographic market được phục vụ có cultural context section riêng
□ Stereotype → Alternative table đủ cover major categories trong product context
□ Alt text standards được included
□ Approval workflow có ít nhất 3 tiers rõ ràng
□ Có ít nhất 3 before/after prompt examples relevant cho product
□ Guidelines được viết đủ cụ thể để designer/prompt engineer áp dụng
   (không chỉ là aspirational statements)
□ Quarterly review process được define
```
