# E-commerce Customer Journey

> Reference file cho ecommerce-expert agent
> Load file này khi cần map customer journey trong domain E-commerce

## Complete Customer Journey

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        CUSTOMER JOURNEY MAP                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  AWARENESS → CONSIDERATION → PURCHASE → RETENTION → ADVOCACY            │
│      │            │            │            │            │               │
│   Discover     Research      Transact    Engage      Refer              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Stage 1: Awareness / Discovery

### Touchpoints

| Channel | Description | User Actions |
|---------|-------------|--------------|
| Search (SEO/SEM) | Google, Bing | Search query → Landing page |
| Social Media | Facebook, Instagram, TikTok | Scroll → Click ad/post |
| Display Ads | Banner, retargeting | View → Click |
| Email | Newsletter, promotional | Open → Click |
| Direct | URL, bookmark | Navigate directly |
| Marketplace | Shopee, Lazada, Amazon | Browse marketplace |
| Influencer | KOL/KOC content | Watch/read → Click link |

### Key Metrics

| Metric | Description | Target |
|--------|-------------|--------|
| Reach | People exposed | Campaign dependent |
| Impressions | Ad views | CPM basis |
| CTR | Click-through rate | 2-5% |
| Bounce rate | Leave without action | <40% |
| Time on site | Engagement | >2 minutes |

---

## Stage 2: Consideration / Research

### Touchpoints

| Channel | User Actions |
|---------|--------------|
| Homepage | Browse categories, promotions |
| Category pages | Filter, sort, browse |
| Product listing (PLP) | Compare products |
| Product detail (PDP) | Read details, view images |
| Reviews | Read customer feedback |
| Comparison tools | Compare options |
| Wishlist | Save for later |
| Cart (first add) | Express interest |

### Product Page Elements

```
┌─────────────────────────────────────────────────────────┐
│  [Images Gallery]          │  Product Title            │
│  - Main image              │  Rating: ⭐⭐⭐⭐☆ (4.2)    │
│  - Thumbnails              │  Price: $99.99            │
│  - Zoom                    │  Was: $129.99 (-23%)      │
│                            │                           │
│                            │  Variants:                │
│                            │  Color: [Red] [Blue]      │
│                            │  Size: [S] [M] [L]        │
│                            │                           │
│                            │  [Add to Cart]            │
│                            │  [Buy Now]                │
├────────────────────────────┴───────────────────────────┤
│  Description │ Specifications │ Reviews │ Q&A          │
├─────────────────────────────────────────────────────────┤
│  Related Products │ Recently Viewed                    │
└─────────────────────────────────────────────────────────┘
```

### Key Metrics

| Metric | Description | Target |
|--------|-------------|--------|
| PDP views | Product page visits | - |
| Add to cart rate | % sessions with add | 5-10% |
| Time on PDP | Engagement | >1 minute |
| Review reads | % who read reviews | >50% |
| Wishlist adds | Save for later | - |

---

## Stage 3: Purchase / Conversion

### Checkout Flow

```
┌─────────────────────────────────────────────────────────┐
│                    CHECKOUT FUNNEL                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Cart View          ████████████████████  100%          │
│        │                                                │
│  Login/Register     ████████████████░░░░   80%          │
│        │                                                │
│  Shipping Info      ██████████████░░░░░░   70%          │
│        │                                                │
│  Payment Method     ████████████░░░░░░░░   60%          │
│        │                                                │
│  Review Order       ███████████░░░░░░░░░   55%          │
│        │                                                │
│  Confirmation       █████████░░░░░░░░░░░   45%          │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Checkout Best Practices

| Practice | Why Important |
|----------|---------------|
| Guest checkout | 25% abandon if forced to register |
| Progress indicator | Shows remaining steps |
| Auto-fill addresses | Reduces friction |
| Multiple payment options | Customer preference |
| Clear error messages | Fix issues quickly |
| Mobile optimized | 70% of traffic |

### Key Metrics

| Metric | Description | Target |
|--------|-------------|--------|
| Conversion rate | % visitors purchase | 2-3% |
| Cart abandonment | % carts not purchased | <70% |
| Checkout abandonment | % exit during checkout | <30% |
| AOV | Average order value | Varies |
| Payment success rate | Successful payments | >95% |

---

## Stage 4: Retention / Post-Purchase

### Touchpoints

| Touchpoint | Timing | Purpose |
|------------|--------|---------|
| Order confirmation | Immediate | Reassurance |
| Shipping notification | When shipped | Set expectations |
| Delivery notification | When delivered | Confirm receipt |
| Review request | 7-14 days post | Get feedback |
| Replenishment reminder | Product dependent | Re-order |
| Newsletter | Weekly/monthly | Stay engaged |
| Loyalty program | Ongoing | Reward loyalty |

### Order Tracking Experience

```
┌─────────────────────────────────────────────────────────┐
│  ORDER #12345                                           │
│                                                          │
│  ●━━━━━━●━━━━━━○━━━━━━○                                 │
│  Ordered Shipped In Transit Delivered                    │
│                                                          │
│  Current Status: In Transit                              │
│  Estimated Delivery: Mar 15, 2024                        │
│                                                          │
│  Tracking: ABC123456789                                  │
│  Carrier: Fedex                                          │
│                                                          │
│  [Track on Carrier Site]                                 │
└─────────────────────────────────────────────────────────┘
```

### Key Metrics

| Metric | Description | Target |
|--------|-------------|--------|
| Repeat purchase rate | % customers return | >25% |
| Customer lifetime value | Total revenue per customer | Varies |
| Email open rate | Post-purchase emails | >30% |
| Review rate | % who leave reviews | 5-10% |
| Return rate | % orders returned | <10% |

---

## Stage 5: Advocacy / Referral

### Touchpoints

| Channel | User Action |
|---------|-------------|
| Product reviews | Write review |
| Photo reviews | Upload product photos |
| Social sharing | Share on social media |
| Referral program | Refer friends |
| UGC | Create content |

### Key Metrics

| Metric | Description | Target |
|--------|-------------|--------|
| NPS | Net Promoter Score | >50 |
| Review rate | % who review | 5-10% |
| Referral rate | % who refer | 5-10% |
| Social shares | Shares per order | - |

---

## Cross-Journey Analytics

### Attribution Models

| Model | Description | When to Use |
|-------|-------------|-------------|
| First touch | Credit first interaction | Brand awareness focus |
| Last touch | Credit last interaction | Direct response focus |
| Linear | Equal credit all | Simple, fair |
| Time decay | More credit to recent | Long consideration |
| Position-based | First + last weighted | Balanced |

### Cohort Analysis

```
Month     │ M0    │ M1    │ M2    │ M3    │
──────────┼───────┼───────┼───────┼───────┤
Jan 2024  │ 100%  │  25%  │  18%  │  15%  │
Feb 2024  │ 100%  │  28%  │  20%  │   -   │
Mar 2024  │ 100%  │  30%  │   -   │   -   │
```

---

## Journey Pain Points & Solutions

| Pain Point | Impact | Solution |
|------------|--------|----------|
| Slow page load | High bounce | Optimize performance |
| Complex navigation | Exit early | Simplify menu |
| No stock info | Frustration | Real-time inventory |
| Hidden costs | Cart abandon | Show all costs early |
| Long checkout | Abandonment | Simplify to 3 steps |
| No guest checkout | 25% abandon | Allow guest |
| Poor search | Can't find product | Improve search |
| No reviews | Trust issues | Enable reviews |
