# Sprint 2: Lock/Heartbeat + sessions.jsonl

> **Estimate:** 2h
> **Phụ thuộc:** S1 (mc-common.sh, mc-acquire-lock.sh, mc-release-lock.sh, mc-heartbeat.sh, mc-index-append.sh)
> **Solves:** G1 (lock/heartbeat), G2 (sessions.jsonl)
> **PR Group:** PR #1

---

## Mục tiêu

Tích hợp lock/heartbeat/session-index vào skill workflow. Sau sprint này, wf-manage-change chạy an toàn với multi-developer.

## Deliverables

### 2.1 sessions.jsonl infrastructure

Tạo directory structure + initial file:

```
.mc-data/work/wf-manage-change/
├── _index/
│   └── sessions.jsonl         # Append-only
├── .locks/
│   └── (registry.lock — created on demand)
└── index.json                  # Giữ nguyên — dual-write
```

### 2.2 Phase 0 integration

Update `procedures/phase0-intake.md`:

| Step | Thay đổi |
|------|----------|
| 0.0 | Thêm: acquire session lock qua `mc-acquire-lock.sh --type=session --id=$CHANGE_ID` |
| 0.0b | Thêm: start heartbeat daemon `mc-heartbeat.sh --id=$CHANGE_ID &` (background) |
| 0.1 | Đổi: gọi `mc-generate-session-id.sh` thay vì inline bash |
| 0.1b | Đổi: gọi `mc-index-append.sh` thay vì modify index.json inline |
| 0.1b+ | Thêm: dual-write index.json (giữ cho `--status`) |
| New 0.1c | Thêm: EXIT trap — gọi `mc-release-lock.sh` khi session kết thúc |

### 2.3 Phase 4a lock integration

Update `procedures/phase4a-registry-docs.md`:

| Step | Thay đổi |
|------|----------|
| 4a.1 | Đổi: gọi `mc-backup-registry.sh` thay vì inline `cp` |
| Before 4a.5 | Thêm: acquire registry lock `mc-acquire-lock.sh --type=registry --id=$CHANGE_ID` |
| 4a.5 | Giữ nguyên: registry update logic |
| After 4a.5 | Thêm: release registry lock `mc-release-lock.sh --type=registry --id=$CHANGE_ID` |
| 4a.5 validate | Đổi: gọi `mc-validate-registry.sh` thay vì inline `jq` |

### 2.4 Phase 6 lock release

Update `procedures/phase6-report.md`:

| Step | Thay đổi |
|------|----------|
| After 6.4 | Thêm: kill heartbeat process + release session lock |
| 6.4+ | Thêm: final index.jsonl append (status=completed) |

### 2.5 Resume lock-aware

Update `procedures/_shared.md` §Resume Logic:

| Step | Thay đổi |
|------|----------|
| After Step 1 | Thêm: check `.session.lock` active → nếu active + heartbeat fresh → từ chối resume |
| After Step 1 | Thêm: nếu heartbeat stale → cho phép takeover |
| After Step 4 | Thêm: re-acquire session lock khi resume thành công |
| After Step 4 | Thêm: restart heartbeat daemon |

## Acceptance Criteria

| # | Criteria | Verify bằng |
|---|----------|-------------|
| AC1 | Phase 0 Step 0.0 acquire session lock trước khi tạo bất kỳ file nào | `ls $SESSION_DIR/.session.lock` |
| AC2 | sessions.jsonl có entry khi session bắt đầu | `grep $CHANGE_ID sessions.jsonl` |
| AC3 | Heartbeat running trong suốt session | `.session.lock` heartbeat_at cập nhật mỗi 30s |
| AC4 | Registry lock acquire trước Phase 4a.5, release sau | Test: `ls .locks/registry.lock` trước/sau write |
| AC5 | Phase 6 kill heartbeat + release lock | `.session.lock` không tồn tại sau session complete |
| AC6 | Resume bị từ chối nếu session lock active + heartbeat fresh | Test: start session, thử resume từ terminal khác → rejected |
| AC7 | Resume cho phép takeover nếu heartbeat stale (>60 min) | Test: modify heartbeat_at → cũ hơn 60min → resume OK |
| AC8 | EXIT trap cleanup khi Ctrl+C | Ctrl+C giữa Phase 4 → lock released |

## Risks

| Risk | Mitigation |
|------|------------|
| Heartbeat process zombie nếu session crash | EXIT/INT/TERM trap kill heartbeat. Stale detection (>60min) cho phép takeover. |
| Git merge conflict trên .session.lock | .session.lock trong .gitignore (không check in) |
| Windows: background process `&` không hoạt động trong Git Bash | Git Bash hỗ trợ `&`. Nếu không → fallback: heartbeat inline mỗi checkpoint save. |

## Definition of Done

- [ ] sessions.jsonl append-only hoạt động
- [ ] index.json dual-write đồng bộ với sessions.jsonl
- [ ] Session lock acquire/release trong Phase 0 + 6
- [ ] Registry lock acquire/release trong Phase 4a
- [ ] Heartbeat daemon chạy + stale detection
- [ ] EXIT trap cleanup
- [ ] Lock-aware resume
- [ ] AC1-AC8 pass
