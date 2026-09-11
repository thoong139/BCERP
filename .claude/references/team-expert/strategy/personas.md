# Strategy User Personas

> Reference file cho strategy-expert agent
> Load file này khi cần hiểu về users trong domain Strategy & Corporate Governance

## Danh sách Personas

### 1. CEO / Tổng Giám đốc

**Profile:**
- Chức danh: CEO / Chief Executive Officer / Tổng Giám đốc
- Kinh nghiệm: Executive level (15+ năm), strategic decision maker
- Technical skill: Low — không muốn thao tác phức tạp
- Tần suất sử dụng hệ thống: Daily (mobile, 30-60 phút/ngày) + Weekly deep dive

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Xem KPI morning dashboard | Daily | 15-20 phút | Critical |
| Review board reports / pack | Monthly | 2-3 giờ | High |
| Approve strategic decisions | 3-5 lần/tuần | 20-30 phút/item | High |
| Stakeholder & investor meetings | 3-4 lần/tuần | 1-2 giờ/cuộc | High |
| Review OKR progress (all BUs) | Weekly | 30 phút | High |

**Key Decisions:**
| Decision | Based On | Consequences | Need System Support |
|----------|----------|--------------|---------------------|
| Resource allocation giữa BUs | BU KPI performance, strategic priority | Business growth / stagnation | Yes — BU comparison dashboard |
| M&A go/no-go | DD results, valuation, strategic fit | Capital deployment, market position | Yes — M&A pipeline tracking |
| Strategic pivot | Market signals, KPI trends, board mandate | Organizational direction | Yes — scenario analysis tools |
| CEO succession / key talent | Performance data, succession pipeline | Leadership continuity | Yes — linked to HR system |

**Pain Points:**
1. **Thông tin scattered**: Phải đọc từ nhiều nguồn — email, Excel, PowerPoint — không có single view
2. **Data inconsistency**: Số liệu từ các BU khác nhau, không biết tin nguồn nào
3. **Phải chờ CFO compile**: Không có real-time visibility — dashboard T+1 hoặc T+3
4. **Mobile unfriendly**: Báo cáo dạng PDF, không đọc được tốt trên điện thoại
5. **Không có exception alerts**: Chỉ biết khi hỏi — không có proactive notification

**Must-have Features:**
- Real-time KPI dashboard (mobile-first, tối đa 5 KPIs trên màn hình đầu)
- One-click drill-down từ Company → BU → Function → metric
- Exception alerts (push notification khi KPI đỏ)
- Board pack auto-generation từ system data

---

### 2. CFO / Giám đốc Tài chính

**Profile:**
- Chức danh: CFO / Chief Financial Officer / Giám đốc Tài chính
- Kinh nghiệm: Executive level (12+ năm), financial stewardship
- Technical skill: High — am hiểu financial models, analytics
- Tần suất sử dụng hệ thống: Daily (4-6 giờ/ngày)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Review financial KPIs & cash position | Daily | 30 phút | Critical |
| Approve CAPEX requests | 2-5 items/tuần | 20 phút/item | High |
| Manage treasury & liquidity | Daily | 1 giờ | High |
| Prepare board financial packs | Monthly | 4-6 giờ | Critical |
| Investor relations data preparation | Quarterly | 8+ giờ | High |

**Key Decisions:**
| Decision | Based On | Consequences | Need System Support |
|----------|----------|--------------|---------------------|
| Capital allocation giữa BUs | ROIC, strategic priority, cash position | Funding gaps, over-investment | Yes — capital allocation model |
| M&A valuation sign-off | DCF, comparables, synergy estimates | Deal price, premium paid | Yes — valuation tools |
| Dividend policy | Free cash flow, debt covenants, board mandate | Shareholder returns, cash retention | Yes — cash flow forecast |
| Financing structure | Cost of capital, market conditions | Leverage ratio, covenant compliance | Yes — debt capacity model |

**Pain Points:**
1. **Manual consolidation**: Subsidiaries gửi Excel file → CFO team tổng hợp thủ công (3-5 ngày/tháng)
2. **Reconciliation time-consuming**: Intercompany eliminations thủ công, dễ sai
3. **No real-time subsidiary visibility**: Chỉ biết subsidiary performance khi họ report
4. **Board pack production**: Mất 1-2 ngày compile số liệu, định dạng báo cáo
5. **Scenario modeling siloed**: Model trên Excel không kết nối với actuals

**Must-have Features:**
- Consolidated P&L / Balance Sheet / Cash Flow real-time (Group + Subsidiary drill-down)
- Variance analysis vs budget/forecast với automatic commentary
- Subsidiary performance dashboard với intercompany eliminations
- One-click board pack generation (PDF) từ live data

---

### 3. Board Director / Thành viên Hội đồng Quản trị

**Profile:**
- Chức danh: Board Director / Independent Director / Thành viên HĐQT
- Kinh nghiệm: Senior, part-time oversight role
- Technical skill: Low-Medium — cần UI đơn giản, secure
- Tần suất sử dụng hệ thống: Monthly (trước họp) + Ad-hoc queries

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Review board packs | Trước mỗi cuộc họp | 3-5 giờ/lần | Critical |
| Attend board & committee meetings | Quarterly / per schedule | 3-4 giờ/cuộc | Critical |
| Approve major resolutions | Per meeting agenda | 30 phút/resolution | High |
| Oversee risk & audit reports | Semi-annual | 2 giờ/lần | High |

**Key Decisions:**
| Decision | Based On | Consequences | Need System Support |
|----------|----------|--------------|---------------------|
| Strategy approval | Management proposals, market context | Company direction for 3-5 năm | Yes — strategy review documents |
| CEO remuneration | Performance review, market benchmarks | Executive incentives, retention | Yes — secure board portal |
| Major CAPEX/M&A approval | Business case, financial analysis | Capital deployment, risk exposure | Yes — approval workflow |
| Risk appetite | Risk reports, regulatory requirements | Acceptable risk level for company | Yes — risk dashboard |

**Pain Points:**
1. **Board pack delivered too late**: Nhận tài liệu 1-2 ngày trước họp, không đủ thời gian đọc
2. **Data not pre-analyzed**: Số liệu raw, không có executive summary, không có variance explanation
3. **No ability to query between meetings**: Muốn hỏi thêm thông tin nhưng phải email và chờ
4. **Security concerns**: Tài liệu nhạy cảm được share qua email không encrypted
5. **No digital voting**: Phải có mặt hoặc gửi proxy bằng giấy

**Must-have Features:**
- Secure board portal (encrypted, remote wipe, no unauthorized download)
- Board pack access 10 ngày trước họp (theo quy định)
- Digital voting / resolution management
- Audit trail của tất cả board document access

---

### 4. Strategy Manager / Trưởng phòng Chiến lược

**Profile:**
- Chức danh: Strategy Manager / Head of Strategy / Trưởng phòng Chiến lược
- Kinh nghiệm: Mid-Senior level (7-10 năm), strategic planning process owner
- Technical skill: High — thoải mái với Excel, BI tools, project management
- Tần suất sử dụng hệ thống: Daily (full-time user)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Thu thập OKR check-in từ các BU | Weekly/Monthly | 2-3 giờ/lần | High |
| Compile strategy progress reports | Monthly | 4-6 giờ | High |
| Track strategic initiative milestones | Daily | 30 phút | High |
| Coordinate với BU heads về resource gaps | 2-3 lần/tuần | 1 giờ/lần | High |
| Chuẩn bị CEO briefing materials | Weekly | 2 giờ | High |

**Key Decisions:**
| Decision | Based On | Consequences | Need System Support |
|----------|----------|--------------|---------------------|
| Initiative prioritization (recommend) | Resource availability, strategic impact | Which initiatives move forward | Yes — initiative scoring matrix |
| Resource gap identification | Current vs planned headcount/budget | Escalation to CEO/CFO | Yes — resource tracking |
| Milestone escalation | Delay signals, confidence scores | CEO awareness, corrective action | Yes — OKR alerting |

**Pain Points:**
1. **Chasing updates via email/spreadsheet**: Gửi email mỗi tuần để hỏi tiến độ, tỷ lệ phản hồi thấp
2. **Manual aggregation**: Copy-paste từ nhiều nguồn vào báo cáo tổng hợp — mất 4-6 giờ/tháng
3. **Version control nightmare**: Nhiều version Excel file, không biết cái nào final
4. **No real-time view**: Chỉ thấy tình trạng khi ai đó update — thiếu live dashboard
5. **Narrative + data không kết nối**: Số liệu một chỗ, bình luận một chỗ

**Must-have Features:**
- OKR tracking platform với automated check-in reminders
- Initiative dashboard (milestone, owner, RAG status)
- Auto-aggregation từ BU updates lên Company level
- Narrative + data combined trong 1 view

---

### 5. Business Unit Head / Giám đốc Kinh doanh BU

**Profile:**
- Chức danh: BU Head / Division Head / Giám đốc Kinh doanh / GM
- Kinh nghiệm: Senior level (10+ năm), P&L owner
- Technical skill: Medium — dùng dashboard thường xuyên, không muốn setup phức tạp
- Tần suất sử dụng hệ thống: Daily (1-2 giờ/ngày)

**Daily Tasks:**
| Task | Frequency | Time Spent | Priority |
|------|-----------|------------|----------|
| Review BU KPI dashboard | Daily | 20-30 phút | Critical |
| Manage BU OKRs và team OKRs | Weekly | 1 giờ | High |
| Report up to CEO / Strategy team | Monthly | 2-3 giờ | High |
| Allocate BU resources (headcount/budget) | Monthly | 1-2 giờ | High |
| Review BU budget variance | Monthly | 1 giờ | High |

**Key Decisions:**
| Decision | Based On | Consequences | Need System Support |
|----------|----------|--------------|---------------------|
| BU resource reallocation | BU KPI, initiative priority | Team effectiveness | Yes — BU resource view |
| BU strategy adjustment | Market signals, BU performance | Revenue/margin impact | Yes — BU performance dashboard |
| Team OKR scoring | Evidence from team | Performance review input | Yes — OKR scoring workflow |
| BU budget variance justification | Actuals vs budget | CFO escalation or approval | Yes — variance analysis |

**Pain Points:**
1. **KPI data fragmented**: Phải mở 3-4 hệ thống khác nhau để có đủ số liệu BU
2. **Cannot compare with peer BUs**: Không biết BU mình đứng ở đâu so với các BU khác
3. **OKR updates manual**: Phải tự nhập mọi thứ, không tự động pull từ operational systems
4. **Cascade not visible**: Không thấy rõ OKR của team có đóng góp cho Company OKR như thế nào
5. **Reporting to CEO manual**: Phải chuẩn bị PowerPoint mỗi tháng — tốn 2-3 giờ

**Must-have Features:**
- BU-level dashboard (KPIs, financials, OKR score)
- OKR cascade view: Company → BU → Team → Individual
- Peer BU benchmarking (blinded — thấy rank, không thấy tên BU khác)
- Auto-generated monthly BU report cho CEO review

---

## Quick Reference

| Persona | Primary Focus | Key Metric | Usage Frequency |
|---------|---------------|------------|-----------------|
| CEO | Strategic decisions & oversight | Company KPI vs target, M&A pipeline | Daily (mobile) |
| CFO | Financial stewardship & reporting | EBITDA, ROIC, Cash position | Daily (desktop) |
| Board Director | Governance & oversight | Strategy approval, risk tolerance | Monthly + meetings |
| Strategy Manager | Planning process & OKR coordination | OKR completion rate, initiative health | Daily (power user) |
| BU Head | BU performance & execution | BU KPI, OKR score, budget variance | Daily |
