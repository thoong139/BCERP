# Sprint Dashboard

> **Mục đích:** Dashboard theo dõi tiến độ tất cả các sprint
>
> **Cập nhật:** Tự động cập nhật khi có thay đổi trong các sprint
>
> READS: `P5-00-implementation-roadmap.md`
> USED BY: `sprints/S0X-*.md`

---

## Mục Đích

File này là **Sprint Index** — tổng hợp trạng thái tất cả sprints trong dự án.

**Relationship với sprint files:**
- Mỗi sprint cụ thể được document trong `S0X-[sprint-name].md` cùng thư mục
- File này track progress TỔNG HỢP — cập nhật sau mỗi sprint kết thúc

**Cách cập nhật:** Sau khi sprint N kết thúc, cập nhật status + actual metrics trong bảng này. Index này do project team bảo trì — cập nhật cột Status và Done mỗi tuần. Chi tiết từng sprint trong file `SXX-*.md` tương ứng.

---

## Sprint Overview

| Sprint | Tên | Start | End | Features | Done | Progress | Status |
|--------|-----|-------|-----|----------|------|----------|--------|
| S01 | Foundation | *[Date]* | *[Date]* | X | 0 | 0% | ⬜ |
| S02 | *[Tên]* | *[Date]* | *[Date]* | X | 0 | 0% | ⬜ |
| S03 | *[Tên]* | *[Date]* | *[Date]* | X | 0 | 0% | ⬜ |
| ... | ... | ... | ... | ... | ... | ... | ... |

**Status Legend:**
- ⬜ `planned` - Đã kế hoạch
- 🔄 `active` - Đang chạy
- ✅ `completed` - Hoàn thành
- ⏸️ `paused` - Tạm dừng

---

## Timeline

```
Week 1-2:  S01 - Foundation         [⬜ planned]
Week 3-4:  S02 - *[Tên]*            [⬜ planned]
Week 5-6:  S03 - *[Tên]*            [⬜ planned]
Week 7-8:  S04 - *[Tên]*            [⬜ planned]
...
```

---

## Current Sprint: *[S0X]*

### Thông tin
| Mục | Giá trị |
|-----|---------|
| Sprint | *[S0X - Tên]* |
| Start Date | *[YYYY-MM-DD]* |
| End Date | *[YYYY-MM-DD]* |
| Days Remaining | *[X]* |

### Mục tiêu
*[Liệt kê mục tiêu sprint]*

### Features trong Sprint
| Feature ID | Name | Status | Assignee |
|------------|------|--------|----------|
| ... | ... | ... | ... |

---

## Metrics

### Velocity History
| Sprint | Planned | Completed | Velocity |
|--------|---------|-----------|----------|
| S01 | X | - | - |
| S02 | X | - | - |

### Burndown
*[Link đến burndown chart hoặc mô tả]*

---

## Links

- [Implementation Roadmap](../P5-00-implementation-roadmap.md)
- [Stakeholder Review](../stakeholder-review.md)
- [Tasks Directory](../tasks/)
