# Playbook: Viết Release Notes

> **Type**: Agent Skill Playbook
> **Agent**: tech-writer
> **Triggered by**: Pre-release khi cần viết release notes cho một version mới
> **Output**: `.mc-data/docs/phase6-deployment/release-notes-v[version].md`

---

## Khi nào dùng playbook này

- Trước mỗi production release (major, minor, patch)
- Khi cần changelog cho API consumers trước breaking changes
- Khi chuẩn bị announcement cho users và stakeholders
- Sau hotfix cần thông báo nhanh

---

## Procedure

### Bước 1: Đọc git log, feature specs và bug tracker

```
INPUT: Paths do skill cung cấp qua prompt
FALLBACK: tra .claude/references/path-registry.md → PHASE2 (features), PHASE5 (implementation)
READ: tech-writing-patterns.md (release notes template, writing guidelines)

Thu thập từ nhiều nguồn:
□ Git commits từ version trước đến version này
□ Feature specs tương ứng từ phase2-features/
□ Bug reports đã fixed
□ REQ-IDs của features đã implement
□ Known issues chưa fix trong release này
□ Breaking changes (nếu có)
□ Migration steps cần thiết
```

Lấy git log theo format có cấu trúc:

```bash
# Lấy commits từ tag trước đến HEAD
git log v[previous]..HEAD --oneline --no-merges

# Lọc theo type (conventional commits)
git log v[previous]..HEAD --oneline --grep="^feat\|^fix\|^breaking"
```

### Bước 2: Categorize changes

Phân loại THEO TÁC ĐỘNG đến người dùng, không theo technical implementation:

```markdown
## Phân loại changes

### Tier 1: Cần đọc ngay (Breaking Changes)
→ Bất kỳ change nào yêu cầu user/developer phải làm gì đó

### Tier 2: Đáng chú ý (New Features)
→ Tính năng mới người dùng sẽ thấy và có thể dùng ngay

### Tier 3: Cải thiện (Improvements)
→ Thứ đang hoạt động nhưng giờ tốt hơn

### Tier 4: Sửa lỗi (Bug Fixes)
→ Thứ đang hỏng giờ đã fix

### Tier 5: Ghi chú (Known Issues)
→ Biết có vấn đề nhưng chưa fix trong release này
```

Với mỗi change, điền template:

```
Change: [tên thay đổi]
Category: [Breaking / Feature / Improvement / Bug Fix]
User-facing: [Yes / No / Partially]
REQ-ID: [REQ-xxx hoặc BUGFIX-xxx]
Impact: [Tất cả users / Admin only / API users only / Specific feature users]
Action required: [None / Migrate before upgrade / Update config / Etc.]
```

### Bước 3: User-facing language — không jargon

Quy tắc viết mỗi release note item:

```
SAI: "Fixed NullPointerException in OrderService.calculateDiscount()"
ĐÚNG: "Sửa lỗi tính sai giá khi áp dụng nhiều mã giảm giá cùng lúc"

SAI: "Refactored authentication middleware to use JWT RS256"
ĐÚNG: "Cải thiện tốc độ đăng nhập và tăng bảo mật phiên làm việc"

SAI: "Implemented pagination with cursor-based approach for performance"
ĐÚNG: "Danh sách đơn hàng tải nhanh hơn khi có nhiều dữ liệu"

SAI: "Deprecated v1 endpoints — will be removed in v3.0"
ĐÚNG: "API v1 sẽ ngừng hoạt động từ 01/01/2027 — xem hướng dẫn migration"
```

Câu hỏi kiểm tra: "Developer vừa mới bắt đầu dùng sản phẩm có hiểu ngay không?" → Nếu không, viết lại.

### Bước 4: Migration guide cho breaking changes

Mỗi breaking change PHẢI có migration guide đầy đủ:

```markdown
## Breaking Changes

### [BC-1]: [Tên thay đổi mô tả impact]

**Ảnh hưởng**: [API v1 users / Admin users / All users]
**Bắt buộc migration trước**: [Version / Date]

#### Thay đổi gì

Trước đây:
```json
{ "user_role": "admin" }
```

Sau thay đổi:
```json
{ "role": "admin" }
```

#### Cách migrate

**Option 1: Update client code** (recommended)
```javascript
// Trước
const payload = { user_role: 'admin' };

// Sau
const payload = { role: 'admin' };
```

**Option 2: Dùng compatibility header** (hết hạn 01/07/2026)
```
X-API-Compatibility: v1
```

#### Timeline

| Mốc | Date | Action |
|-----|------|--------|
| Breaking change released | 2026-03-19 | Bắt đầu migrate |
| v1 field deprecated | 2026-03-19 | v1 vẫn work, cảnh báo trong logs |
| v1 field removed | 2027-01-01 | Requests không có `role` sẽ fail |

#### Cần hỗ trợ?

[link to migration support channel / email / documentation]
```

### Bước 5: Known issues

Tuyệt đối không ẩn known issues — document chúng để users không tốn thời gian tìm:

```markdown
## Known Issues

### [KI-1]: [Tên vấn đề mô tả triệu chứng]

**Triệu chứng**: [User thấy gì]
**Điều kiện xảy ra**: [Khi nào / với ai]
**Workaround**: [Cách tạm thời để tiếp tục làm việc]
**Status**: [Đang điều tra / Fix trong v[X.Y.Z] / Sẽ không fix — lý do]

---

### [KI-2]: ...
```

Nếu không có known issues: viết "Không có known issues trong release này." — Đừng bỏ section này vì sau sẽ cần thêm.

### Bước 6: Version numbers và format chuẩn

Format release notes header:

```markdown
# Release Notes — v[MAJOR.MINOR.PATCH]

**Release date**: [DD/MM/YYYY]
**Type**: [Major / Minor / Patch / Hotfix]

**Summary**: [1-2 câu tóm tắt release này về cái gì]

**Compatibility**:
- API: v[N] (breaking changes? yes/no)
- Minimum app version: [X.Y] (nếu có mobile app)
- Database migration: [Required / Not required]
```

Phân biệt:
- **Major** (X.0.0): Breaking changes, major features, architecture changes
- **Minor** (x.Y.0): New features, non-breaking improvements
- **Patch** (x.y.Z): Bug fixes, security patches, performance improvements
- **Hotfix**: Critical fix ngoài release cycle

### Bước 7: Release notes hoàn chỉnh — full document structure

```markdown
# Release Notes — v[MAJOR.MINOR.PATCH]

**Release date**: [DD/MM/YYYY]
**Type**: [Major / Minor / Patch / Hotfix]

[1-2 câu summary]

---

## Breaking Changes ⚠️

[Nếu có] — Bắt buộc đọc trước khi upgrade

### [Tên change 1]
[Migration guide đầy đủ — xem Bước 4]

---

## Tính năng mới

### [Feature 1 — REQ-ID: REQ-xxx]
[Mô tả user-facing, 2-4 câu. Ai được hưởng lợi? Dùng thế nào?]
[Documentation: [link]]

### [Feature 2 — REQ-ID: REQ-xxx]
...

---

## Cải thiện

- **[Module/Feature]**: [Mô tả improvement, bắt đầu bằng verb — "Tăng tốc...", "Cải thiện...", "Giảm..."]
- **[Module/Feature]**: ...

---

## Sửa lỗi

- **[Triệu chứng lỗi]**: [Giải thích ngắn gọn lỗi là gì và đã fix như thế nào] (REQ-ID hoặc BUGFIX-xxx)
- **[Triệu chứng lỗi]**: ...

---

## Known Issues

[Xem Bước 5]

---

## Upgrade Instructions

[Nếu cần bước đặc biệt ngoài update thông thường]

```bash
# Database migration (nếu cần)
npm run migrate

# Config update (nếu cần)
# Thêm vào .env: NEW_REQUIRED_VAR=value
```

---

## Phiên bản trước

- [v2.0.1](release-notes-v2.0.1.md) — 2026-03-01
- [v2.0.0](release-notes-v2.0.0.md) — 2026-02-15
```

### Bước 8: Output

```
Ghi vào path do skill cung cấp.
Fallback: .mc-data/docs/phase6-deployment/release-notes-v[version].md

Đồng thời cập nhật:
- CHANGELOG.md ở root project (nếu có)
- API docs changelog section (nếu có API changes)
```

---

## Checklist trước khi submit

```
□ Version number đúng format SemVer
□ Breaking changes ở ĐẦU document, không ẩn
□ Mọi breaking changes có migration guide đầy đủ với timeline
□ Language user-facing — không có technical jargon không giải thích
□ Known issues được document, không ẩn
□ REQ-IDs reference đầy đủ trong new features
□ Release date chính xác
□ Upgrade instructions có nếu cần migration steps
□ Links đến full documentation nếu feature phức tạp
□ Đã review với developer để đảm bảo technical accuracy
```

---

## Lưu ý kỹ thuật

- **Hotfix release notes**: Ngắn gọn — chỉ cần: version, date, what was fixed, impact, upgrade urgency
- **Audience split**: Nếu có cả developer API và end user, viết 2 sections riêng biệt
- **Security patches**: Không tiết lộ vulnerability details — chỉ nói "Fixed security issue in [component]" và link đến CVE khi đã public
- **Retroactive notes**: Nếu note bị missed, add vào version đó chứ không gán sai version
