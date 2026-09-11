# Runbook — Troubleshooting `/wf-fix-bugs` (E-codes)

> **Tham chiếu:** wf-fix-bugs v6.0 design, CORE-023 (chất lượng trước tốc độ)
> **Cập nhật:** 2026-04-21 (B4-4)

Tài liệu này liệt kê tất cả error codes (E-codes) trong pipeline `/wf-fix-bugs` và sub-skills, kèm hướng dẫn xử lý cho người dùng non-technical.

---

## 1. Cách Đọc E-code

Khi `/wf-fix-bugs` dừng, nó hiển thị message dạng:

```
STOP E024: Workflow tam dung tai Workload Gate.
Dung `/wf-fix-bugs --resume` de chon lai plan.
```

**Quy ước:**
- **STOP** = skill dừng hoàn toàn, cần can thiệp
- **WARNING** = skill tiếp tục nhưng có rủi ro
- **ESCALATE** = chuyển cho người có chuyên môn cao hơn

---

## 2. Orchestrator `/wf-fix-bugs` — E001 đến E025

| Code | Nguyên nhân | Mức | Hành động |
|------|-------------|-----|-----------|
| **E001** | Sub-skill POST-GATE fail sau 3 lần retry | STOP | Kiểm tra `phase-summary.md` trong session dir. Chạy lại sub-skill riêng hoặc `--resume`. |
| **E002** | User từ chối tiếp tục | STOP | Dùng `--resume` để tiếp tục từ checkpoint. |
| **E003** | `req-registry.json` không tồn tại | STOP | Chạy `/wf-brainstorm` hoặc `/existing-project` trước. |
| **E004** | Sub-skill SKILL.md không tìm thấy | STOP | Kiểm tra thư mục `.claude/skills/workflow/wf-fix-*/`. |
| **E005** | Không tìm thấy issues (Discover N=0) | STOP | Hệ thống healthy — không cần fix. |
| **E009** | Context > 90% giữa sub-skill | STOP | Dùng `--resume` trong session mới để tiếp tục. |
| **E011** | `--resume` / `--status` nhưng chưa có session | STOP | Chạy `/wf-fix-bugs [mô-tả]` để bắt đầu session mới. |
| **E023** | Flag conflict (`--deep` + `--no-browser`) | WARNING | `--no-browser` wins. Nếu muốn deep scan cần bật browser. |
| **E024** | Workload Gate Aborted — user chọn dừng hoặc từ chối WARN prompt | STOP | Dùng `--resume` để chọn lại plan, hoặc `--scope=<hẹp hơn>` để restart. |
| **E025** | CDG Rejected — user từ chối Critical Decision Gate | WARNING | Quay lại Triage để re-plan các issue thành ESCALATE bucket. |

---

## 3. `/wf-fix-discover` — E013 đến E049

| Code | Nguyên nhân | Mức | Hành động |
|------|-------------|-----|-----------|
| **E013** | App không chạy tại `app_url` | WARNING | Skip runtime scan, chỉ chạy static analysis. Khởi động app rồi `--resume`. |
| **E014** | Playwright MCP không khả dụng | WARNING | Skip runtime layers. Cài Playwright: `npx playwright install`. |
| **E017** | Auto-login Giai đoạn 3 SKIPPED | WARNING | CDG chưa accept hoặc production env. Dùng `--credentials` hoặc login thủ công. |
| **E018** | Deep scan >15 pages trong 1 session | STOP | FORCE checkpoint. Dùng `--resume` để tiếp tục. |
| **E019** | Auto-login Giai đoạn 2 SKIPPED | WARNING | Thử Giai đoạn 3 nếu có, else fallback manual. |
| **E020** | Cần dọn dep (hiển thị khi có) | INFO | Theo hướng dẫn để dọn artifacts cũ. |
| **E045** | Infrastructure health check fail | WARNING | LOG + SET status, không block discovery. Kiểm tra DB/API infrastructure. |
| **E046** | Database fail | WARNING | Tiếp tục static + API discovery. Kiểm tra DB connection. |
| **E047** | Zero API endpoints tìm thấy | WARNING | Tiếp tục sang Phase 1c. Có thể dự án chưa có API. |
| **E048** | >50% features chưa có docs | WARNING | Tiếp tục. Gap analysis sẽ phát hiện. |
| **E049** | Gap analysis fail | WARNING | Skip discovery-report.md, dùng inline summary. |

---

## 4. `/wf-fix-triage` — E010 đến E011

| Code | Nguyên nhân | Mức | Hành động |
|------|-------------|-----|-----------|
| **E010** | Template `bug-triage.md` không tồn tại | STOP | Retry 3 lần (Protocol 2). Nếu fail → verify `.claude/skills/workflow/wf-fix-triage/templates/`. |
| **E011** | `checkpoint.json` missing/invalid khi `--deep` | STOP | Chạy `/wf-fix-discover --resume` để regenerate checkpoint. |

---

## 5. `/wf-fix-execute` — E005 đến E041

| Code | Nguyên nhân | Mức | Hành động |
|------|-------------|-----|-----------|
| **E005** | Developer agent fix gây regression | STOP | Rollback fix → escalate với context. Kiểm tra `fix-log.json`. |
| **E006** | Tests fail sau fix | STOP | Retry fix max 3 lần, nếu vẫn fail → escalate. |
| **E007** | Feature spec không tìm thấy cho behavior change | WARNING | LOG, tiếp tục. |
| **E008** | Registry JSON invalid sau update | STOP | Retry x3, rollback nếu vẫn fail. |
| **E013** | Playwright navigate thất bại | WARNING | LOG warning, skip gracefully. |
| **E017** | Auth required khi Playwright verify | WARNING | Apply 4-giai đoạn auto-login. |
| **E039** | CRITICAL issues remain sau iter 3 (hoặc 4) | STOP | Xem `fix-report.md` section "Unfixed Critical Issues". |
| **E040** | Loop fix gây regression mới | WARNING | Thêm vào issue-registry. Max 5 regressions → ESCALATE. |
| **E041** | Numeric metrics mismatch trong fix-report | WARNING | Flag "Validation Notes", không block. |

---

## 6. Quy Trình Xử Lý Tổng Quát

### Khi gặp STOP

```
1. Đọc message hiển thị (có E-code)
2. Xem bảng trên để hiểu nguyên nhân
3. Thực hiện hành động được gợi ý
4. Dùng /wf-fix-bugs --resume để tiếp tục
```

### Khi gặp WARNING

```
1. Đọc warning message
2. Nếu chấp nhận rủi ro → tiếp tục
3. Nếu cần xử lý → thực hiện rồi --resume
4. Warning được ghi vào session-log.json (CORE-026)
```

### Khi cần xem chi tiết

```bash
# Đọc execution trace
python -m _shared.read_trace --skill=wf-fix-bugs --last=20

# Đọc session status
cat .mc-data/work/wf-fix-bugs/run-*/fix-status.json

# Đọc issue registry
cat .mc-data/work/wf-fix-bugs/run-*/issue-registry.json
```

---

## 7. Liên Hệ

Nếu E-code không có trong bảng hoặc hành động không giải quyết được:
1. Kiểm tra `phase-summary.md` trong session directory
2. Xem `session-log.json` trace (CORE-026)
3. Báo cáo qua GitHub issue với E-code + log excerpt
