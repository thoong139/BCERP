# Fixture: `concurrent/` — TC-cmi-005 (2 Sessions Parallel)

> **Mục đích:** Kiểm tra Protocol 22 R/W lock cross-session khi 2 phiên `wf-cmi` chạy đồng thời trên cùng máy.

---

## Cấu trúc

```
concurrent/
├── README.md                  ← Bạn đang đọc
└── concurrent-runner.sh       ← Bash orchestrator chạy 2 sessions song song
```

> **Note:** Fixture concurrent **reuse** dữ liệu từ `realistic/` (cross-module 3 modules). Runner chỉ orchestrate timing.

## Test scenario

| Thời điểm | Session A | Session B |
|-----------|-----------|-----------|
| t=0s | START `/wf-cmi --scope=system --profile=deep` | (idle) |
| t=30s | Đang ở Phase 2 Discovery (read-heavy) | START `/wf-cmi --scope=module=crm --profile=quick` |
| t=30-90s | Phase 2 Discovery (read lock) | Phase 1 Init → Phase 2 Discovery (read lock OK) |
| t=90s+ | Phase 7 GAP+CDG (write lock cần) | Phase 7 GAP+CDG (write lock cần) |
| Conflict | (giữ write lock) | E090b CDG: "Lock đang giữ bởi Session A, expected release ~2 min. Chờ? / Force? / Cancel?" |

## Protocol 22 R/W lock expected behavior

- **Read lock (Phase 2-5):** N readers đồng thời OK → 2 sessions không block nhau
- **Write lock (Phase 7 sidecar APPEND):** Exclusive → second session phải wait hoặc CDG escalate
- **Heartbeat 30s:** Cả 2 sessions update `_index/sessions.jsonl` đều đặn
- **Stale lock auto-release:** Sau 30 min (CORE-038) nếu heartbeat dừng

## Run

```bash
cd tests/fixtures/wf-cmi/concurrent
bash concurrent-runner.sh
```

## Pass criteria

- 2 SESSION_ID khác nhau (YYYY-MM-DD-{scope}-{slug}-NN format)
- 2 SESSION_DIR riêng biệt, không corrupt nhau
- Read-heavy phases (Phase 2-5) chạy song song không block
- Write-heavy phase (Phase 7) serialize qua write lock OR E090b CDG escalate
- `_index/sessions.jsonl` ghi 2 entries START + heartbeats + COMPLETE/FAIL
- Cleanup: lock release đúng cho cả 2 sessions
- Không vi phạm CORE-030 (Session Isolation) hoặc CORE-025 (concurrency limit)

## Concurrency limits (CORE-025)

- profile=quick + standard: max 5 sessions/máy
- profile=deep + exhaustive: max 2 sessions/máy
- Vượt limit → reject với gợi ý chạy tuần tự hoặc nâng profile

## Liên kết

- Eval definition: [`.claude/skills/workflow/wf-cmi/evals/evals.json`](../../../../.claude/skills/workflow/wf-cmi/evals/evals.json) §TC-cmi-005
- Design canon: [`docs/04-skill-design/wf-cmi/09-evals-test-cases.md`](../../../../docs/04-skill-design/wf-cmi/09-evals-test-cases.md) §2.TC-cmi-005
- Protocol 22: [`.claude/skills/protocols/22-rw-lock-cross-session.md`](../../../../.claude/skills/protocols/22-rw-lock-cross-session.md)
- Fixture reuse: [`../realistic/`](../realistic/)
