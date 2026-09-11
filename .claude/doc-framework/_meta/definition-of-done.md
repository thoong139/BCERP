# Definition of Done — Per Phase Checklist

> Template chuẩn để đánh giá mỗi phase đã hoàn thành hay chưa.
> Skills tham chiếu template này trong POST-GATE output.

---

## Phase 0: Brainstorm

- [ ] P0-01-brainstorm.md: đã điền đầy đủ tất cả sections và >= 200 words
- [ ] P0-02-systems-users.md: systems và users được định nghĩa, >= 100 words
- [ ] `.mc-data/` directory structure đã khởi tạo
- [ ] Brainstorm status = "completed"
- [ ] Stakeholder review: ít nhất 1 sign-off (A.4)
- [ ] Scope và out-of-scope được confirm rõ ràng

## Phase 1: Business Requirements

- [ ] Mỗi department có ít nhất 1 file `.md` trong `phase1-business/departments/`
- [ ] Mỗi dept file có >= 4 headings và >= 300 words
- [ ] P1-02-business-workflow.md tồn tại và non-empty
- [ ] stakeholder-review.md tồn tại, không có CRITICAL/HIGH findings PENDING
- [ ] req-registry.json có `requirements[].length > 0`
- [ ] Tất cả REQ-IDs theo format chuẩn `REQ-[DEPT]-[NNN]`

## Phase 2: Feature Specifications

- [ ] Mỗi feature có 1 file `.md` trong `phase2-features/[sys]/[mod]/`
- [ ] Mỗi feature file có >= 6 headings và >= 400 words
- [ ] req-registry.json có `features[].length > 0`
- [ ] Tất cả features tham chiếu REQ-IDs hợp lệ từ registry
- [ ] Không có placeholder/TODO trong feature specs

## Phase 3: Architecture & Technical Design

- [ ] P3-01-architecture.md tồn tại, >= 7 headings, >= 500 words
- [ ] api-contract.md tồn tại và có endpoint definitions
- [ ] database-design.md tồn tại và có table definitions
- [ ] stakeholder-review.md tồn tại, không có CRITICAL/HIGH findings PENDING
- [ ] req-registry.json có `design_status` updated

## Phase 4: UX/UI Design (conditional — skip nếu api-only)

> **Điều kiện trigger:** Chỉ apply khi `req-registry.json.interface_type != "api-only"`. Nếu api-only → Phase 4 được SKIP, chuyển thẳng sang Phase 5.

- [ ] design-system.md tồn tại với 6 sections: Colors, Typography, Spacing, Components, Breakpoints, Icons
- [ ] Navigation specs tồn tại cho mỗi system có UI
- [ ] Screen groups tồn tại, mỗi group >= 200 words
- [ ] stakeholder-review.md tồn tại, không có CRITICAL/HIGH findings PENDING
- [ ] req-registry.json có `ux_design_status` updated

## Phase 5: Implementation

- [ ] P5-00-implementation-roadmap.md tồn tại
- [ ] Task files tồn tại trong `tasks/[sys]/[mod]/`
- [ ] Source code files có REQ-ID comments
- [ ] Tests tồn tại cho implemented features
- [ ] req-registry.json có `impl_status` per REQ-ID updated
- [ ] Preflight verdict != FAIL (nếu đã chạy)

## Phase 6: Deployment

- [ ] deployment-guide.md tồn tại, có Mục 1-8, >= 500 words
- [ ] user-guide.md tồn tại và non-empty
- [ ] stakeholder-review.md tồn tại, không có CRITICAL/HIGH findings PENDING
- [ ] verify-sync.md cho thấy sync rate >= 80%

## Code Implementation (per feature)

- [ ] Source files tạo đúng theo technical design
- [ ] Mỗi file có REQ-ID comment header
- [ ] Unit tests tồn tại và pass
- [ ] Code review PASSED (code-reviewer agent)
- [ ] Security review PASSED (security agent)
- [ ] impl_status updated trong req-registry.json
