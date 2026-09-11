# Quality Excellence - FMEA Methodology

> **Domain**: Quality Excellence / Failure Mode and Effects Analysis
> **Last Updated**: 2026-03-22
> **Nguồn**: AIAG-VDA FMEA Handbook (4th Edition, 2019), IEC 60812, ASQ FMEA Guide

---

## 1. FMEA Fundamentals

### Mục đích

FMEA là công cụ phòng ngừa proactive — xác định và loại bỏ nguyên nhân gây lỗi TRƯỚC KHI xảy ra,
không phải phản ứng sau khi defect đã xuất hiện.

### Các loại FMEA

| Loại | Viết tắt | Đối tượng | Khi nào dùng |
|------|---------|-----------|--------------|
| **Design FMEA** | DFMEA | Product/system design | Thiết kế sản phẩm mới, thay đổi design |
| **Process FMEA** | PFMEA | Manufacturing/service process | Quy trình sản xuất, quy trình dịch vụ |
| **System FMEA** | SFMEA | System architecture | Systems engineering, complex integrations |
| **Software FMEA** | — | Software functions, processes | Software development, critical applications |

### Khi nào tiến hành FMEA

- Sản phẩm hoặc quy trình **mới hoàn toàn**
- Thay đổi design hoặc process **significant** (>10% thay đổi, hoặc đánh giá là significant)
- Môi trường sử dụng thay đổi (vị trí, nhiệt độ, tải trọng)
- **Recurring failures** — failure modes đã xảy ra lặp lại
- Transfer line (sản xuất chuyển sang địa điểm khác)
- Yêu cầu từ customer hoặc regulatory

---

## 2. FMEA Process Steps (7 Steps — AIAG-VDA 2019)

### Step 1: Planning & Scope Definition

- Xác định: sản phẩm/quy trình gì được phân tích
- Define boundaries: in-scope vs out-of-scope
- Assemble team: Design/Process Engineer, QA, Manufacturing, Supplier (nếu cần)
- Review previous FMEA hoặc lesson learned

### Step 2: Structure Analysis

- Identify system elements, process steps, sub-elements
- Create structure tree hoặc process flow diagram
- DFMEA: System → Sub-system → Component
- PFMEA: Process step → Work element → Equipment/Material/Person

### Step 3: Function Analysis

- Cho mỗi element: xác định FUNCTION (phải làm gì?) và REQUIREMENT (phải làm tốt đến mức nào?)
- DFMEA: "Component X phải withstand 100N load"
- PFMEA: "Step 3 phải apply torque 25±2 Nm"

### Step 4: Failure Analysis

- **Failure Mode**: Cách element có thể KHÔNG thực hiện đúng function
  - Examples: fracture, leak, short circuit, incorrect output, delayed response
- **Failure Effect**: Tác động lên customer/end user khi failure mode xảy ra
  - Local effect (sub-system), next level effect, end effect (customer)
- **Failure Cause**: Tại sao failure mode xảy ra
  - Physical cause, design weakness, process variation, human error

### Step 5: Risk Analysis

#### Severity (S) — 1-10

| Rating | Effect | Severity Criteria |
|--------|--------|-------------------|
| 10 | Safety/Regulatory — without warning | May endanger operator, violates regulations |
| 9 | Safety/Regulatory — with warning | Degraded operation, safety warning detected |
| 8 | Loss of primary function | Product inoperable, vehicle unable to operate |
| 7 | Degraded primary function | Product operable, performance reduced |
| 6 | Loss of secondary function | Comfort/convenience inoperable |
| 5 | Degraded secondary function | Comfort reduced, partial loss |
| 4 | Appearance/Noise fit/finish — noticed by most | Noticeable by >75% customers |
| 3 | Appearance/Noise — noticed by some | Noticeable by 25-75% customers |
| 2 | Appearance/Noise — noticed by few | Noticeable by <25% customers |
| 1 | No discernible effect | Unaffected by failure |

#### Occurrence (O) — 1-10

| Rating | Likelihood | Failure Rate (per item/cycle) |
|--------|-----------|-------------------------------|
| 10 | Very High | > 1 in 10 |
| 9 | High | 1 in 10 |
| 8 | Moderately High | 1 in 50 |
| 7 | Moderate | 1 in 100 |
| 6 | Low-Moderate | 1 in 500 |
| 5 | Low | 1 in 2,000 |
| 4 | Very Low | 1 in 15,000 |
| 3 | Remote | 1 in 150,000 |
| 2 | Very Remote | 1 in 1,500,000 |
| 1 | Unlikely | < 1 in 1,500,000 |

#### Detection (D) — 1-10

| Rating | Detection | Criteria |
|--------|-----------|---------|
| 10 | Absolutely Uncertain | No current control; cannot detect |
| 9 | Very Remote | Very unlikely to detect before shipment/use |
| 8 | Remote | Remote chance of detection |
| 7 | Very Low | Very low chance — inspection prone to errors |
| 6 | Low | Moderate chance with manual inspection |
| 5 | Moderate | Moderate chance with automated inspection |
| 4 | Moderately High | High chance with automated detection |
| 3 | High | Nearly certain to detect — multiple controls |
| 2 | Very High | Very high — poka-yoke / mistake proofing |
| 1 | Almost Certain | Current controls will almost certainly detect |

### Step 6: RPN Calculation & Action Priority

**RPN = Severity × Occurrence × Detection**

| RPN Threshold | Action Required |
|---------------|-----------------|
| RPN ≥ 100 | Mandatory action — assign Risk Owner, set deadline |
| S ≥ 9 (any RPN) | Mandatory action regardless of O and D scores |
| O ≥ 8 (any RPN) | High priority — process not in control |
| D ≥ 8 (any RPN) | Review detection controls |
| RPN 50-99 | Recommended action — review in next revision cycle |
| RPN < 50 | Monitor only — document as acceptable risk |

**AIAG-VDA 2019 note**: Action Priority (AP) thay thế raw RPN trong phiên bản mới:
- AP-H (High): Mandatory action required
- AP-M (Medium): Action desirable
- AP-L (Low): No action needed unless improvement opportunity exists

### Step 7: Recommended Actions & Verification

- Assign **Risk Owner** (by name, không phải department) cho mọi high-priority items
- Set **target completion date**
- After action: re-score S', O', D' → New RPN
- Document **action taken** và evidence

---

## 3. Process FMEA (PFMEA) Template

```
| Process Step | Failure Mode | Effect (S) | S | Cause | O | Current Controls | D | RPN | Recommended Action | Owner | Target Date | Action Taken | S' | O' | D' | New RPN |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
```

**Column guide:**
- **Process Step**: Tên bước quy trình (ví dụ: "Torque bolt to 25Nm")
- **Failure Mode**: Cách bước này fail (ví dụ: "Under-torque", "Over-torque")
- **Effect**: Tác động lên customer/next step
- **S**: Severity score 1-10
- **Cause**: Root cause của failure mode (ví dụ: "Torque wrench not calibrated")
- **O**: Occurrence score 1-10
- **Current Controls**: Gì đang prevent hoặc detect failure (ví dụ: "Calibration schedule")
- **D**: Detection score 1-10
- **RPN**: S × O × D
- **Recommended Action**: Specific action để giảm S, O, hoặc D
- **Owner**: Responsible person (tên người, không phải team)
- **Target Date**: Deadline cho recommended action
- **Action Taken**: What was actually done
- **S'/O'/D'**: Re-scored after action
- **New RPN**: S' × O' × D'

---

## 4. Software FMEA Application

### Software Failure Modes (adapted for PFMEA)

| Software Context | Failure Mode Examples |
|-----------------|----------------------|
| Incorrect output | Wrong calculation, wrong data returned, field truncated |
| Missing function | Feature not executed, API timeout not handled |
| Data corruption | Concurrent write without lock, incomplete transaction |
| Security breach | SQL injection, unauthorized access, data exposure |
| Performance degradation | Query timeout, memory leak, deadlock |
| Integration failure | API contract mismatch, downstream system unavailable |

### Software PFMEA Example Row

```
Process Step  : Order Total Calculation
Failure Mode  : Discount applied twice (double discount)
Effect        : Customer overcharged or undercharged (S=7)
Cause         : Discount logic called from two code paths
Occurrence    : Rare but possible (O=3)
Current Ctrl  : Unit test for single discount case
Detection     : Test does not cover multi-discount scenario (D=7)
RPN           : 7 × 3 × 7 = 147 → ACTION REQUIRED
Action        : Add integration test for multiple simultaneous discounts
Owner         : Dev Lead
Target Date   : Sprint 15 end
```

### Quality Gates in SDLC as PFMEA Controls

| SDLC Gate | FMEA Control Type | Detection Level |
|-----------|-------------------|-----------------|
| Requirements review | Prevention — catch ambiguity early | D=5 (moderate) |
| Design review + DFMEA | Prevention — architecture level | D=4 |
| Code review | Detection — human review | D=5 |
| Unit test (>80% coverage) | Detection — automated | D=3 |
| Integration test | Detection — system-level | D=3 |
| UAT | Detection — user-level | D=4 |
| Production monitoring | Detection — post-release | D=6 (late detection) |
