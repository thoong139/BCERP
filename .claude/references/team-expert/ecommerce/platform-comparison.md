# E-commerce Platform Comparison

> Reference file cho ecommerce-expert agent
> Load file này khi cần chọn platform trong domain E-commerce

## Platform Categories

### 1. SaaS Platforms (Hosted)

| Platform | Best For | Pricing Model |
|----------|----------|---------------|
| Shopify | SMB, scaling businesses | Monthly fee + transaction % |
| BigCommerce | Growing SMB | Monthly fee |
| Wix eCommerce | Small, simple stores | Monthly fee |
| Squarespace | Design-focused small stores | Monthly fee |

### 2. Open Source Platforms (Self-hosted)

| Platform | Best For | Technical Requirement |
|----------|----------|----------------------|
| WooCommerce | WordPress users, SMB | Medium |
| Magento Open Source | Large, complex stores | High |
| PrestaShop | European SMB | Medium |
| OpenCart | Budget-conscious | Low-Medium |

### 3. Marketplace Platforms

| Platform | Region | Fee Structure |
|----------|--------|---------------|
| Shopee | Southeast Asia | Commission 1-5% |
| Lazada | Southeast Asia | Commission 3-8% |
| Tiki | Vietnam | Commission 8-15% |
| Amazon | Global | Commission 8-15% + fees |
| eBay | Global | Listing + final value fees |

### 4. Enterprise Platforms

| Platform | Best For | Pricing |
|----------|----------|---------|
| Shopify Plus | High-volume | $2,000+/month |
| Magento Commerce | Large enterprise | Custom quote |
| Salesforce Commerce Cloud | Global enterprise | Revenue share |
| SAP Hybris | Complex B2B/B2C | Custom quote |

---

## Detailed Comparison

### Shopify vs WooCommerce vs Magento

| Feature | Shopify | WooCommerce | Magento |
|---------|---------|-------------|---------|
| **Hosting** | Included | Self-hosted | Self-hosted |
| **Setup Time** | Hours | Days | Weeks |
| **Technical Skill** | Low | Medium | High |
| **Monthly Cost** | $29-299 | $0 + hosting | $0 + hosting |
| **Transaction Fee** | 0.5-2% (if not Shopify Payments) | 0% | 0% |
| **Themes** | 100+ | 1000s | 100s |
| **Apps/Plugins** | 8000+ | 50000+ | 5000+ |
| **Scalability** | High | Medium | Very High |
| **Multi-store** | No* | No | Yes |
| **B2B Features** | Limited | Via plugins | Native |
| **API** | REST, GraphQL | REST | REST, GraphQL |
| **Headless** | Yes (Hydrogen) | Yes (WP API) | Yes (PWA Studio) |

*Available on Shopify Plus

---

## Feature Checklist

### Core E-commerce Features

| Feature | Essential | Nice to Have |
|---------|-----------|--------------|
| Product catalog | ✓ | |
| Shopping cart | ✓ | |
| Checkout | ✓ | |
| Payment integration | ✓ | |
| Order management | ✓ | |
| Customer accounts | ✓ | |
| Mobile responsive | ✓ | |
| SEO tools | ✓ | |
| Inventory management | ✓ | |
| Shipping integration | ✓ | |
| Tax calculation | ✓ | |
| Discount codes | ✓ | |
| Email notifications | ✓ | |
| Analytics | ✓ | |
| Multi-currency | | ✓ |
| Multi-language | | ✓ |
| Product reviews | | ✓ |
| Wishlist | | ✓ |
| Product comparison | | ✓ |
| Live search | | ✓ |
| Recommendations | | ✓ |

### Advanced Features

| Feature | Use Case |
|---------|----------|
| Subscription/recurring | DTC, consumables |
| B2B features | Wholesale |
| Multi-store | Multiple brands/regions |
| Headless/API | Custom frontends |
| PWA | Mobile performance |
| Marketplace integration | Multi-channel |
| PIM integration | Complex catalogs |
| ERP integration | Enterprise |

---

## Selection Criteria

### Business Size

| Size | Recommended Platforms |
|------|----------------------|
| Startup (< $100K GMV) | Shopify Basic, WooCommerce |
| Small ($100K-$1M GMV) | Shopify, BigCommerce, WooCommerce |
| Medium ($1M-$10M GMV) | Shopify, BigCommerce, Magento |
| Large ($10M-$50M GMV) | Shopify Plus, Magento Commerce |
| Enterprise ($50M+ GMV) | Shopify Plus, Magento, SFCC |

### Business Model

| Model | Platform Considerations |
|-------|------------------------|
| B2C Retail | Most platforms suitable |
| B2B | Magento, Shopify Plus (B2B) |
| Marketplace | Custom build or Mirakl |
| Subscription | Recharge + Shopify, WooCommerce Subscriptions |
| Digital Products | Shopify, Gumroad, EasyDigitalDownloads |
| Multi-vendor | Dokan (WooCommerce), Multi-vendor marketplace |

### Technical Resources

| Resources | Recommendation |
|-----------|---------------|
| No dev team | SaaS (Shopify, BigCommerce) |
| Small dev team | WooCommerce, Shopify with customizations |
| Dedicated dev team | Magento, headless |

---

## Platform Migration Considerations

### Migration Checklist

- [ ] Data audit (products, customers, orders)
- [ ] URL structure mapping (301 redirects)
- [ ] SEO preservation plan
- [ ] Integration inventory
- [ ] Custom functionality mapping
- [ ] Design migration or redesign
- [ ] Testing timeline
- [ ] Launch plan (staged vs big bang)

### Common Migration Risks

| Risk | Mitigation |
|------|------------|
| Data loss | Full backup, staged migration |
| SEO drop | 301 redirects, maintain URL structure |
| Downtime | Staged migration, low-traffic launch |
| Integration breaks | API compatibility check |
| Performance issues | Load testing before launch |

---

## Vietnam Market Specifics

### Local Platforms

| Platform | Description |
|----------|-------------|
| Haravan | Vietnamese Shopify alternative |
| Sapo | Vietnamese, multiple channels |
| KiotViet | POS + Online |
| Nhanh.vn | Omnichannel |

### Local Integrations Needed

| Integration | Purpose |
|-------------|---------|
| VNPay, MoMo, ZaloPay | Local payments |
| GHN, GHTK, Viettel Post | Local shipping |
| eInvoice (eHoadon) | VAT invoicing |
| Zalo OA | Customer communication |
| Shopee/Lazada/Tiki sync | Marketplace presence |

---

## Quick Selection Guide

```
START
  │
  ├── Budget < $100/month?
  │     └── YES → WooCommerce + cheap hosting
  │     └── NO → Continue
  │
  ├── Have dev team?
  │     └── YES → Magento or headless
  │     └── NO → Continue
  │
  ├── Need multi-store/complex B2B?
  │     └── YES → Magento or Shopify Plus
  │     └── NO → Continue
  │
  ├── Focus on Vietnam only?
  │     └── YES → Haravan, Sapo, or Shopify
  │     └── NO → Continue
  │
  └── Recommended: Shopify or BigCommerce
```
