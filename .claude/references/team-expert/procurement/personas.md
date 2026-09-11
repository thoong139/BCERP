# Procurement User Personas

> Reference file cho procurement-expert agent
> Load file này khi cần hiểu về users trong domain Procurement

## Danh sách Personas

### 1. Procurement Manager

**Profile:**
- Chức danh: Procurement Manager / Trưởng phòng Thu mua
- Kinh nghiệm: Senior level (7+ năm)
- Technical skill: High - chiến lược sourcing, negotiation
- Tần suất sử dụng hệ thống: Daily (4-6 hours/day)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Review procurement requests | 10-20 PRs/ngày | 10 phút/PR | High |
| Vendor performance review | 1 lần/tuần | 2 giờ | High |
| Strategic sourcing initiatives | Ongoing | Variable | High |
| Contract negotiations | 2-5/tuần | 2-4 giờ/negotiation | Critical |
| Budget monitoring | Daily | 30 phút | High |

**Key Decisions:**
| Decision | Based On | Consequences | Need System Support |
|----------|----------|--------------|---------------------|
| Approve vendor selection | Price, quality, delivery | Long-term partnership | Yes - vendor scorecard |
| Waive competitive bidding | Urgency, single source | Compliance risk | Yes - approval workflow |
| Contract renewal/termination | Performance metrics | Supply continuity | Yes - contract alerts |

**Pain Points:**
1. **No visibility**: Không biết spending patterns across departments
2. **Maverick buying**: Users mua ngoài quy trình
3. **Contract tracking**: Missed renewal dates, auto-renewals
4. **Vendor data silos**: Thông tin vendor nằm rải rác

**Must-have Features:**
- Spend analytics dashboard
- Enforced policy compliance
- Contract lifecycle management
- Centralized vendor database

---

### 2. Buyer / Purchasing Officer

**Profile:**
- Chức danh: Buyer / Purchasing Officer / Nhân viên thu mua
- Kinh nghiệm: Entry to Mid level (1-5 năm)
- Technical skill: Medium
- Tần suất sử dụng hệ thống: Daily (6-8 hours/day)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Process purchase requisitions | 20-40 PRs/ngày | 10 phút/PR | High |
| Issue RFQs to vendors | 5-10 RFQs/ngày | 15 phút/RFQ | High |
| Compare quotes & recommend | 5-10 comparisons/ngày | 20 phút/compare | High |
| Create purchase orders | 15-30 POs/ngày | 5 phút/PO | High |
| Track order status | Multiple/day | 30 phút total | High |

**Key Decisions:**
| Decision | Based On | Consequences | Need System Support |
|----------|----------|--------------|---------------------|
| Vendor selection (below threshold) | Price, lead time, stock | Order placement | Yes - quote comparison matrix |
| Expedite order | Urgency, cost | Additional freight cost | Yes - order tracking |
| Accept substitute item | Specs match, price | Quality, user acceptance | Yes - item comparison |

**Pain Points:**
1. **Manual quote comparison**: Copy-paste giữa emails, Excel
2. **Status inquiries**: Users hỏi liên tục về PR/PO status
3. **Re-entering data**: Từ PR → RFQ → PO manual entry
4. **Vendor response tracking**: Không biết vendor đã respond chưa

**Must-have Features:**
- Automated RFQ distribution
- Online quote comparison
- Self-service status tracking
- Vendor portal for responses

---

### 3. Requisitioner / Requester

**Profile:**
- Chức danh: Any employee requesting purchases
- Kinh nghiệm: Varies
- Technical skill: Low to Medium
- Tần suất sử dụng hệ thống: Weekly to Monthly

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Create purchase requisition | 1-5/tháng | 15 phút/PR | Medium |
| Check PR status | 2-3 times/PR | 5 phút | Medium |
| Receive goods | As needed | 10 phút/receipt | High |
| Report issues | Ad-hoc | Varies | High |

**Pain Points:**
1. **Unclear process**: Không biết mua gì theo quy trình nào
2. **Long lead times**: Không biết khi nào nhận hàng
3. **Wrong items**: Hàng nhận không đúng spec
4. **Status black hole**: Không biết PR đang ở đâu

**Must-have Features:**
- Guided requisition wizard
- Real-time status updates
- Easy goods receipt
- Issue reporting

---

### 4. Category Manager

**Profile:**
- Chức danh: Category Manager
- Kinh nghiệm: Senior level (5+ năm)
- Technical skill: High
- Tần suất sử dụng hệ thống: Daily (4-6 hours/day)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Category spend analysis | Daily | 1 giờ | High |
| Supplier relationship management | Ongoing | 2-3 giờ | High |
| Market research | Weekly | 3 giờ | Medium |
| Contract development | As needed | Variable | High |

**Pain Points:**
1. **Fragmented spend data**: Không có full category picture
2. **Supplier info scattered**: Thông tin nằm nhiều hệ thống
3. **Manual market intelligence**: Update giá thị trường thủ công

---

### 5. Vendor / Supplier

**Profile:**
- Chức danh: External vendor user
- Kinh nghiệm: Varies
- Technical skill: Low to Medium
- Tần suất sử dụng hệ thống: Multiple times/week

**Tasks:**
| Task | Frequency | Time Spent |
|------|-----------|------------|
| Receive & respond to RFQs | As received | 15-30 phút/RFQ |
| Acknowledge POs | As received | 5 phút/PO |
| Update order status | As needed | 5 phút |
| Submit invoices | Per delivery | 10 phút |

**Pain Points:**
1. **Multiple portals**: Phải login nhiều hệ thống khách hàng
2. **Unclear requirements**: RFQ thiếu thông tin
3. **Payment status**: Không biết khi nào được thanh toán

---

## Quick Reference

| Persona | Primary Focus | Key Metric |
|---------|---------------|------------|
| Procurement Manager | Strategy & savings | Cost reduction % |
| Buyer | Execution | PO cycle time |
| Requisitioner | Getting items | Lead time |
| Category Manager | Category optimization | Savings, compliance |
| Vendor | Orders & payments | Response rate, payment terms |
