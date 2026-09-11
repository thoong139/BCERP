<!-- From shared-protocols.md lines 1352-1517 (§18) -->
# Protocol 18 — Working Directory Session Isolation Protocol (BẮT BUỘC — MULTI-RUN SKILLS)

> Skills có thể chạy nhiều lần PHẢI cô lập data từng lần chạy vào session directories.
> Ngăn data loss khi re-run và cho phép parallel execution trên khác scope.

## 18.1 Session Directory Structure

```
.mc-data/work/[skill-name]/
├── _shared/                              # Cross-session aggregate data
│   ├── history.json                      # ← Khởi tạo từ session-history.template.json
│   │                                     #   Append-only: mỗi session thêm 1 entry khi COMPLETE/FAIL
│   └── latest-summary.md                 # Shortcut → latest session summary
├── sessions/
│   ├── 2026-04-11-crm-auth-change/       # Per-session isolated
│   │   ├── session-status.json           # ← Khởi tạo từ session-status.template.json
│   │   ├── phase-summary.md              # Tóm tắt (Protocol 14)
│   │   ├── checkpoint.json               # Resume data
│   │   └── [skill-specific files]        # Output files của session
│   └── 2026-04-12-ux-redesign/
│       └── ...
└── [aggregate report — nếu skill cần]    # Latest report at root (optional)
```

> **Lưu ý về naming:** Template `session-history.template.json` tạo ra file `_shared/history.json` tại runtime.
> Template `session-status.template.json` tạo ra file `sessions/{id}/session-status.json` tại runtime.
> Naming khác nhau vì template là generic (dùng cho mọi skill), còn runtime file nằm trong context cụ thể.

## 18.2 Session ID Format

```
FORMAT: {YYYY-MM-DD}-{scope-label}
VÍ DỤ:
  wf-manage-change:     2026-04-11-crm-pricing-change
  feature-addition:     2026-04-11-crm-export-feature
  wf-design-ux:         2026-04-12-crm-redesign
  wf-preflight:         2026-04-12-full-check
  wf-design:            2026-04-13-architecture-update

QUY TẮC:
- scope-label: lowercase-kebab-case, mô tả ngắn gọn scope của session
- Phải unique trong cùng skill — nếu trùng → append suffix -2, -3
- Human-readable — user nhìn tên folder hiểu ngay session đó làm gì
```

## 18.3 Session Status Schema

```json
{
  "session_id": "2026-04-11-crm-auth-change",
  "skill": "/wf-manage-change",
  "created_at": "ISO-8601",
  "status": "in_progress | completed | failed | paused",
  "scope": {
    "system": "crm",
    "module": "auth",
    "description": "Thay đổi logic tính phí đơn hàng"
  },
  "phases_completed": [0, 1, 2],
  "current_phase": 3,
  "files_created": 5,
  "files_modified": 3,
  "checkpoint_file": "checkpoint.json"
}
```

## 18.4 Cross-Session History

```json
{
  "$schema": "session-history-v1",
  "skill": "/wf-manage-change",
  "entries": [
    {
      "session_id": "2026-04-11-crm-auth-change",
      "timestamp": "ISO-8601",
      "status": "completed",
      "scope_description": "Thay đổi logic tính phí đơn hàng",
      "files_created": 5,
      "files_modified": 3
    }
  ]
}
```

> history.json là APPEND-ONLY — mỗi session thêm 1 entry khi COMPLETE hoặc FAIL.

## 18.5 Skills Áp Dụng — Theo Phase

### Phase P1 (CRITICAL — implement trước)

| Skill | Session ID pattern | Lý do P1 |
|-------|-------------------|----------|
| `wf-manage-change` | `{date}-{change-slug}` | Mỗi change request = 1 session. Rất thường xuyên re-run |
| `feature-addition` | `{date}-{feature-slug}` | Mỗi addition = 1 session. Rất thường xuyên re-run |

### Phase P2 (IMPORTANT — implement sau P1)

| Skill | Session ID pattern | Lý do P2 |
|-------|-------------------|----------|
| `wf-design-ux` | `{date}-{system-or-scope}` | Iterate design, có thể chạy lại nhiều lần |
| `wf-preflight` | `{date}-{scope}` | Chạy sau mỗi thay đổi, có thể song song |

### Phase P3 (NICE-TO-HAVE — implement khi cần)

| Skill | Session ID pattern | Lý do P3 |
|-------|-------------------|----------|
| `wf-design` | `{date}-{scope}` | Ít re-run, nhưng cần preserve khi có |
| `wf-analyze-requirements` | `{date}-{scope}` | Ít re-run |
| `wf-define-features` | `{date}-{scope}` | Ít re-run |
| `wf-verify-sync` | `{date}-{scope}` | Đã có prompt UPDATE/SKIP |

## 18.6 Skills KHÔNG cần áp dụng

| Skill | Lý do |
|-------|-------|
| `wf-implement-feature` | Đã có per-feature subdirs ($FEATURE_SLUG/) |
| `wf-fix-bugs` | Đã có `sessions/{YYYY-MM-DD-{scope}-{slug}-{NN}}/` với `_index/sessions.jsonl` (áp dụng cho cả wf-fix-triage + wf-fix-execute + 7 dimension lanes — share cùng session dir). Session ID format: `{date}-{scope}-{slug}-{NN}` với NN là sequential counter per scope-day. |
| `wf-add-scope` | Idempotent — re-run an toàn |
| `wf-plan-modules` | SKIP-IF-EXISTS cho task files |
| `wf-legacy-scan/classify/extract` | Pipeline state machine |
| `wf-annotate-code` | Annotation check prevent duplicate |
| `wf-prepare-deployment` | Skip files đã tồn tại |
| `wf-brainstorm` | Entry point, chạy 1 lần |
| `new-project`, `existing-project` | Orchestrator, chạy 1 lần |

## 18.7 Quy tắc

QUY TẮC:
1. Session ID = "{YYYY-MM-DD}-{scope-label}" — unique, human-readable
2. Root-level files chỉ chứa aggregate/latest data
3. Mỗi session tự chứa: status + checkpoint + phase-summary + output files
4. history.json ở _shared/ là APPEND-ONLY — mọi sessions ghi vào
5. Re-run KHÔNG ghi đè session cũ → tạo session mới
6. --resume tìm session chưa hoàn thành (status = in_progress | paused) trong sessions/ → tiếp tục
7. Kết hợp session-log.json (Protocol 15) — mỗi session ghi 1 START entry
8. Phase-summary (Protocol 14) nằm TRONG session dir, không ở root
9. CDG (Protocol 16) triggers nằm trong session context

## 18.8 Migration cho Existing Skills

Khi cập nhật skill từ flat dir sang session dir:

THAY ĐỔI:
1. Phase 0: Thay `mkdir -p .mc-data/work/[skill]/` bằng `mkdir -p .mc-data/work/[skill]/sessions/{session_id}/`
2. Phase 0: Thêm logic detect existing flat files → migrate vào session
3. Mọi Write path: thêm prefix `sessions/{session_id}/`
4. Checkpoint path: `sessions/{session_id}/checkpoint.json`

GIỮ NGUYÊN:
- Template files (không đổi)
- Registry safe-write rules (không đổi)
- Cross-skill output paths trong _meta/ (không đổi — những file này ở docs/, không phải work/)

BACKWARD COMPAT:
- Nếu skill tìm thấy flat files cũ (không có sessions/ dir) → tự migrate vào session đầu tiên
- --resume kiểm tra cả flat dir cũ lẫn sessions/ mới

MIGRATION SAFETY:
- Migration phải hoàn thành trong 1 operation (atomic): tạo session dir → copy files → xác nhận → xóa flat files cũ
- Nếu migration bị gián đoạn (context limit, crash):
  - Session dir có thể tồn tại với data không đầy đủ → KHÔNG xóa flat files cũ
  - Skill detect: nếu flat files VÀ session dir cùng tồn tại → cảnh báo user, hỏi muốn retry migration hay xóa session dir chưa hoàn thành
  - KHÔNG bao giờ xóa flat files cũ cho đến khi session dir đã xác nhận đầy đủ
