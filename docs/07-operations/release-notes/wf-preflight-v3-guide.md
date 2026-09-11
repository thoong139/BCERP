# Migration Guide: /wf-preflight v2 → v3

> **Version:** v3.0.0 (2026-05-03)
> **Áp dụng cho:** Người dùng đã từng chạy `/wf-preflight` v2.x và muốn hiểu thay đổi v3.0.

---

## Thay Đổi Chính

| Tính năng | v2.x | v3.0.0 |
|-----------|------|--------|
| Output path | `.mc-data/work/wf-preflight/preflight-report.md` (flat, bị ghi đè) | `.mc-data/work/wf-preflight/sessions/{SESSION_ID}/preflight-report.md` (session-scoped) |
| Nhiều lần chạy | Ghi đè lẫn nhau | Mỗi lần chạy = session riêng biệt |
| Session ID | Không có | `{YYYY-MM-DD}-{scope-slug}-{NN}` — VD: `2026-05-03-all-01` |
| Lock an toàn | Không có | POSIX atomic mkdir, heartbeat 30s, stale detection 60min |
| History index | Chỉ `preflight-history.md` (flat) | + `_index/sessions.jsonl` (append-only, machine-readable) |
| Cross-skill artifact | Không có | `preflight-impact.json` (schema `preflight-impact-v1`) |
| Bash scripts | Không có | 10 bash scripts `pf-*.sh` (giảm ~78% token overhead) |
| CDG cho `--fix` | Không có | 3-point: pre-fix confirm, per-fix verify, post-fix summary |
| Duplicate run | Silent | CDG cảnh báo trước khi tạo session mới |

---

## Migration Tự Động (Không Cần Làm Gì)

Khi bạn chạy `/wf-preflight` lần đầu sau khi update v3.0, hệ thống **tự động**:

1. **Detect** v2 flat data trong `.mc-data/work/wf-preflight/`
2. **Archive** toàn bộ flat files vào `sessions/_legacy-v2/{timestamp}/`
3. **Tạo session mới** theo layout v3 — sạch, không xung đột

> `preflight-history.md` **không bị di chuyển** — giữ nguyên vị trí flat để backward compat.
>
> Nếu migration đã chạy rồi (có `sessions/_legacy-v2/`), lần sau sẽ skip — **idempotent**.

### Revert v2 Data

Nếu cần xem lại dữ liệu v2 cũ:

```
.mc-data/work/wf-preflight/sessions/_legacy-v2/{timestamp}/
```

---

## Session ID

V3 dùng format: `{YYYY-MM-DD}-{scope-slug}-{NN}`

| Lệnh | Session ID mẫu |
|------|----------------|
| `/wf-preflight` | `2026-05-03-all-01` |
| `/wf-preflight --scope=system --name=SYS-ERP` | `2026-05-03-sys-erp-01` |
| `/wf-preflight --scope=module --name=MOD-ERP-FIN` | `2026-05-03-mod-erp-fin-01` |
| `/wf-preflight --scope=feature --name=FEAT-ERP-FIN-001` | `2026-05-03-feat-erp-fin-001-01` |

`NN` tự tăng khi cùng scope + cùng ngày — không bao giờ bị overwrite.

---

## Output Files (v3.0)

Tất cả output nằm trong session dir `.mc-data/work/wf-preflight/sessions/{SESSION_ID}/`:

| File | Mô tả |
|------|-------|
| `preflight-report.md` | Báo cáo chính — PASS/WARN/FAIL + danh sách issues |
| `preflight-status.json` | Session state — scores, phases, lock, audit_chain |
| `preflight-impact.json` | Cross-skill artifact (schema `preflight-impact-v1`) |
| `phase-summary.md` | Tóm tắt tiếng Việt cho non-specialist |
| `checkpoint.json` | Resume data khi context bị cắt |

Flat files giữ nguyên:

| File | Mô tả |
|------|-------|
| `preflight-history.md` | Lịch sử append-only (backward compat) |
| `_index/sessions.jsonl` | Index JSONL — 2 entries/session (machine-readable) |

---

## Lệnh Mới (v3.0)

### Xem danh sách sessions

```
/wf-preflight --status
```

Hiển thị bảng sessions gần nhất, verdict, thời gian.

### Resume session bị cắt

```
/wf-preflight --resume
```

Auto-discover session `in_progress` mới nhất → tiếp tục từ `RESUME_FROM` trong checkpoint.

```
/wf-preflight --resume=2026-05-03-all-01
```

Resume session ID cụ thể.

### Chạy nhiều lần cùng scope

```
/wf-preflight --scope=all
```

Nếu đã có session hôm nay, hệ thống hiển thị CDG:

```
⚠️ Đã có session 2026-05-03-all-01 (completed, verdict=WARN) hôm nay.
Tạo session mới 2026-05-03-all-02?
[r] Tạo session mới  [n] Huỷ  [q] Quit
```

Bypass trong CI/CD: `MCV3_PREFLIGHT_DUPLICATE_OK=1 /wf-preflight`

---

## Cross-Skill Consumers (v3.1+)

`preflight-impact.json` là cross-skill artifact để downstream skills consume:

```
/wf-fix-bugs --from-preflight              # auto-discover latest session
/wf-fix-bugs --from-preflight=2026-05-03-all-01   # session cụ thể

/wf-prepare-deployment --from-preflight    # Go/No-Go gate từ preflight verdict
/wf-verify-sync --from-preflight           # prioritize coverage gaps
```

> Backward compat: nếu consumer chưa hỗ trợ `--from-preflight` → no-op (không block).

---

## CDG cho `--fix` (v3.0)

Khi dùng `--fix`, hệ thống hiển thị **3 checkpoint**:

1. **Pre-fix confirm:** Liệt kê các lỗi sẽ auto-fix, yêu cầu xác nhận
   ```
   Tìm thấy 5 lỗi có thể auto-fix: 3 orphan_code_file + 2 registry_json_invalid
   Tiến hành fix? [yes / no / dry-run]
   ```

2. **Per-fix verify:** Sau mỗi lần sửa, verify lại file không có lỗi mới

3. **Post-fix summary:** Báo cáo N/M thành công, rollback nếu có lỗi mới

---

## Troubleshooting

| Vấn đề | Giải pháp |
|--------|-----------|
| Lock stale (>60 min) | Tự động detect và takeover — không cần can thiệp |
| Lock bởi process đang chạy (alive PID) | Chờ session đó kết thúc, hoặc kill PID trong `.session.lock` |
| Session corrupt | Xóa `sessions/{SESSION_ID}/` và chạy lại |
| Không tìm thấy dữ liệu v2 cũ | Tìm trong `sessions/_legacy-v2/{timestamp}/` |
| `jq` chưa cài | `winget install jqlang.jq` (Windows) hoặc `brew install jq` (Mac) |
| Chạy ngoài project root | `cd` về thư mục có `.mc-data/` trước khi chạy |

---

## CORE Compliance (v3.0)

| CORE ID | Đáp ứng |
|---------|---------|
| CORE-026 | Execution trace `_trace/session-log.json` |
| CORE-027 | CDG 3-point cho `--fix` |
| CORE-028 | `phase-summary.md` tiếng Việt sau POST-GATE |
| CORE-030 | Session isolation `sessions/{SESSION_ID}/` |
| CORE-031 | 7 output files từ templates |
