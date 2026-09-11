## ⚠️ Implementation Strategy: [VERIFY_ONLY | COMPLETE_EXISTING | IMPLEMENT_NEW]

### Khi VERIFY_ONLY:
> Code hiện tại đã có. KHÔNG implement lại từ đầu.
> Chỉ: Verify + Annotate REQ-ID

**Existing Code:**
- `[file_path]` (lines [X]-[Y])
- Tests: `[test_file]` ([N] tests)

**Việc cần làm:**
- [ ] Run existing tests → xác nhận pass
- [ ] Verify logic khớp với spec bên dưới
- [ ] Inject REQ-ID annotations
- [ ] Update impl_status = "done"

**KHÔNG làm:**
- ❌ Không tạo file code mới
- ❌ Không refactor code hiện tại
- ❌ Không thay đổi logic đang hoạt động

### Khi COMPLETE_EXISTING:
> Code hiện tại đã có NHƯNG còn thiếu.
> KHÔNG rewrite code hiện tại. CHỈ bổ sung phần thiếu.

**Existing Code:** [refs từ $FEATURE_IMPL_MAP.existing_code_refs]

**Còn thiếu (cần bổ sung):**
- [ ] [gap 1 từ $FEATURE_IMPL_MAP.gaps_identified]
- [ ] [gap 2]

**KHÔNG làm:**
- ❌ Không rewrite [existing class/file]
- ❌ Không xóa/thay thế existing logic
- ❌ Không refactor code đang hoạt động

### Khi IMPLEMENT_NEW:
> Không tìm thấy code liên quan. Triển khai mới theo TDD.

[Standard TDD task structure — giữ nguyên format hiện tại]
