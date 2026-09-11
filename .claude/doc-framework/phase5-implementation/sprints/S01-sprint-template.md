# Sprint [S0X]: *[Tên Sprint]*

> **Mục đích:** Kế hoạch chi tiết cho một sprint
>
> **Thời gian:** *[Start Date]* → *[End Date]* (*[X]* tuần)
>
> READS: `P5-00-implementation-roadmap.md`, `tasks/[sys]/[mod]/[feat]-impl.md`, `phase4-ux/[sys]/[mod]/[screen-group].md` (nếu có UI)
> USED BY: (sprint tracking — implementation progress)

---

## 1. Sprint Info

| Mục | Giá trị |
|-----|---------|
| **Sprint ID** | S0X |
| **Tên** | *[Tên Sprint]* |
| **Start Date** | *[YYYY-MM-DD]* |
| **End Date** | *[YYYY-MM-DD]* |
| **Sprint Goal** | *[Mục tiêu chính của sprint]* |
| **Status** | ⬜ planned / 🔄 active / ✅ completed |

---

## 2. Sprint Goal

*[Mô tả chi tiết mục tiêu sprint - kết quả kỳ vọng sau khi hoàn thành]*

**Success Criteria:**
- [ ] *[Tiêu chí thành công 1]*
- [ ] *[Tiêu chí thành công 2]*
- [ ] *[Tiêu chí thành công 3]*

---

## 3. Scope

### 3.1 Systems/Modules

| System | Module | Reason |
|--------|--------|--------|
| *[SYS-1]* | *[MOD-1]* | *[Lý do chọn]* |
| *[SYS-2]* | *[MOD-2]* | *[Lý do chọn]* |

### 3.2 Features

| Feature ID | Name | Priority | Complexity | Story Points |
|------------|------|----------|------------|--------------|
| FEAT-XXX-001 | *[Tên]* | Critical | Medium | 5 |
| FEAT-XXX-002 | *[Tên]* | High | Simple | 3 |
| ... | ... | ... | ... | ... |

**Total Story Points:** *[X]*

---

## 4. Tasks Breakdown

### FEAT-XXX-001: *[Tên Feature]*

| Task ID | Description | Type | Assignee | Status | Est (hrs) | Actual |
|---------|-------------|------|----------|--------|-----------|--------|
| T001 | *[Mô tả]* | entity | *[Tên]* | ⬜ | 2 | - |
| T002 | *[Mô tả]* | service | *[Tên]* | ⬜ | 4 | - |
| T003 | *[Mô tả]* | controller | *[Tên]* | ⬜ | 3 | - |
| T004 | *[Mô tả]* | test | *[Tên]* | ⬜ | 2 | - |

**Chi tiết:** Xem `tasks/[system]/[module]/[feature]-impl.md`

### FEAT-XXX-002: *[Tên Feature]*

| Task ID | Description | Type | Assignee | Status | Est (hrs) | Actual |
|---------|-------------|------|----------|--------|-----------|--------|
| ... | ... | ... | ... | ... | ... | ... |

---

## 5. Dependencies

### 5.1 Internal Dependencies

| Feature/Task | Depends On | Type |
|--------------|------------|------|
| *[ID]* | *[ID]* | block / relate |

### 5.2 External Dependencies

| Dependency | Type | Owner | Status |
|------------|------|-------|--------|
| *[Mô tả]* | API / Library / Resource | *[Tên]* | ⬜ pending |

---

## 6. Risks & Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| *[Mô tả rủi ro]* | High/Med/Low | High/Med/Low | *[Cách giảm thiểu]* |

---

## 7. Daily Standup Notes

### Day 1 - *[Date]*
**Completed:**
- *[Đã hoàn thành]*

**In Progress:**
- *[Đang làm]*

**Blockers:**
- *[Block nếu có]*

### Day 2 - *[Date]*
...

---

## 8. Sprint Review

> Điền sau khi sprint hoàn thành

### 8.1 Completed Work
- *[Các công việc đã hoàn thành]*

### 8.2 Incomplete Work
| Feature/Task | Reason | Action |
|--------------|--------|--------|
| *[ID]* | *[Lý do]* | *[Xử lý thế nào]* |

### 8.3 Retrospective

**What went well:**
- *[Điểm tốt]*

**What could be improved:**
- *[Điểm cần cải thiện]*

**Action items for next sprint:**
- [ ] *[Action item]*

### 8.4 Metrics

| Metric | Planned | Actual |
|--------|---------|--------|
| Story Points | X | X |
| Features | X | X |
| Tasks | X | X |
| Velocity | - | X |

---

## 9. Links

- [Implementation Roadmap](../P5-00-implementation-roadmap.md)
- [Sprint Dashboard](./_index.md)
- Feature Plans: `../tasks/[system]/[module]/`
