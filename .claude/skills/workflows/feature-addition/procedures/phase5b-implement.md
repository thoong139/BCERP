# Phase 5b: Implement Features (vòng lặp)

> Implement từng feature mới. User có thể dừng/resume giữa vòng lặp — mỗi feature là 1 checkpoint.

## PRE-GATE

- Phase 5a completed (`test -f .mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md`)
- `$STATUS_FILE.new_feature_ids.length > 0`

## Preparation

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 5b.0 | Đọc `$STATUS_FILE.new_feature_ids` + registry → lọc features chưa `impl_status: "done"` | Read | `$PENDING_FEATURES[]` built |
| 5b.0b | Nếu `$PENDING_FEATURES` rỗng → trigger E006 (skip Phase 5b, chuyển thẳng Preflight) | - | - |
| 5b.0c | Hiển thị danh sách features cần implement + tổng số | - | Displayed |

### Overview hiển thị

```
▶ Phase 5b: Triển khai Code
Tìm thấy [N] features cần implement:
  1. [feature-name-1] (FEAT-XXX)
  2. [feature-name-2] (FEAT-YYY)
  ...

Bắt đầu implement từng feature. Sau mỗi feature bạn có thể dừng và tiếp tục sau.
```

## Vòng lặp per feature

```
Cho mỗi FEAT_ID trong $PENDING_FEATURES (theo order từ roadmap):

  1. Hiển thị: `▶ Implement: [feature-name] ([i]/[total])`
  2. Verify .claude/skills/workflow/wf-implement-feature/SKILL.md tồn tại (else E004)
  3. Gọi Skill("wf-implement-feature", args=[feature-name])
  4. POST-GATE per-feature:
     jq -e --arg id "$FEAT_ID" \
       '.requirements[] | select(.id==$id) | .impl_status == "done"' \
       .mc-data/docs/_meta/req-registry.json
     NOTE: impl_status tracked ở requirements[] (theo CORE-006 fields_owned)

  4a. Nếu POST-GATE PASS → cập nhật $STATUS_FILE NGAY LẬP TỨC (trước khi hỏi user):
      phases_completed += "implement:[FEAT_ID]"
      updated_at = now()
      (Ghi ngay để đảm bảo checkpoint an toàn kể cả khi crash ở bước tiếp theo)

  5. Nếu POST-GATE fail → trigger E008 (hỏi user: retry hoặc skip)
     - retry → quay lại bước 3
     - skip  → KHÔNG cập nhật STATUS_FILE cho FEAT_ID này, loop tiếp

  6. Hỏi user: "Tiếp tục feature tiếp theo? (yes / no / skip)"
     - yes  → loop tiếp
     - skip → bỏ qua feature này (nếu chưa implement), loop tiếp (không mark done)
     - no   → dừng loop, lưu checkpoint (STATUS_FILE đã cập nhật ở 4a), trigger E007
```

> **Lý do thứ tự 4a trước bước 6:** Nếu crash xảy ra sau POST-GATE pass nhưng trước khi STATUS_FILE ghi, resume sẽ thấy feature chưa có trong `phases_completed` và implement lại từ đầu — vi phạm CORE-020. Ghi STATUS_FILE ngay sau PASS tránh được lost-update này. wf-implement-feature tự có Pre-Implementation Safety Gate (CORE-020) làm defense-in-depth.

## LEGACY_MODE guardrail (CORE-020)

wf-implement-feature tự áp dụng Pre-Implementation Safety Gate. Orchestrator chỉ cần ensure
arguments truyền đúng `feature-name` — không override safety gate.

## POST-GATE (khi hết vòng lặp)

```bash
# Đếm features đã implement thành công trong session này
DONE_COUNT=$(jq --argjson ids "$NEW_FEATURE_IDS_JSON" \
  '[.requirements[] | select(.id as $id | $ids | index($id)) | select(.impl_status=="done")] | length' \
  .mc-data/docs/_meta/req-registry.json)
```

**Routing dựa trên DONE_COUNT:**

| DONE_COUNT | Hành động |
|-----------|-----------|
| ≥ 1 | Tiếp tục bình thường → `phases_completed += "phase5b"`, `current_phase = "preflight"` |
| 0 (user skip tất cả) | Ghi `phase5b_all_skipped: true` vào STATUS_FILE → thông báo rõ → hỏi user có muốn tiếp tục Preflight không |

**Khi DONE_COUNT == 0 (tất cả bị skip):**

```
⚠ Lưu ý: Không có feature nào được implement trong session này.
  Tất cả [N] features đã được bỏ qua bởi user.

  Preflight sẽ chạy kiểm tra tổng thể dự án, nhưng sẽ không kiểm tra
  các features mới vì chưa có code nào được tạo.

  Tiếp tục Preflight? (yes/no)
  - yes → tiếp tục (Phase 5b sẽ hiển thị ⏭ trong final report)
  - no  → dừng, lưu checkpoint để resume sau
```

> Khác với WARNING cũ: User được thông báo rõ ràng rằng "không có gì được implement" và phải **chủ động xác nhận** trước khi tiếp tục. Trạng thái `phase5b_all_skipped: true` được ghi vào STATUS_FILE để final report hiển thị đúng (⏭ thay vì ✅).

## Transition

```
✅ Phase 5b hoàn thành — [M]/[N] features implemented (skipped: [S])

→ Next: Preflight — kiểm tra sức khỏe dự án sau implement
```

Nếu `phase5b_all_skipped == true`:
```
⏭ Phase 5b — tất cả features bị bỏ qua bởi user (0/[N] implemented)

→ Next: Preflight — kiểm tra tổng thể dự án (không có code mới để verify)
```

## Errors liên quan

- **E003** — POST-GATE fail sau 3 lần retry
- **E004** — wf-implement-feature SKILL.md không tồn tại
- **E006** — Không có feature nào chưa implement → skip Phase 5b
- **E007** — User dừng giữa vòng lặp → lưu checkpoint, thoát workflow
- **E008** — Individual feature POST-GATE fail → hỏi skip/retry
- **E011** — Context overflow → force checkpoint ngay sau feature hiện tại

Chi tiết: `_shared.md §Error Handling Reference`.
