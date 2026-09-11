# Sprint 1: Foundation — Bash Scripts + Common Helpers

> **Estimate:** 2h
> **Phụ thuộc:** Không (sprint đầu tiên)
> **Solves:** G3 (bash script delegation), G9 (session ID retry)
> **PR Group:** PR #1

---

## Mục tiêu

Tạo 10 bash scripts trong `.claude/scripts/wf-manage-change/` — foundation cho toàn bộ v3.0. Scripts này sẽ được gọi bởi phase files trong Sprint 5.

## Deliverables

| # | File | Mục đích | Dòng estimate |
|---|------|----------|---------------|
| 1 | `mc-common.sh` | Shared helpers (color, jq, timestamp, dirs, identity) | ~60 |
| 2 | `mc-generate-session-id.sh` | Session ID generation with retry loop | ~45 |
| 3 | `mc-acquire-lock.sh` | Per-session + registry lock (PID/host/user/stale detect) | ~80 |
| 4 | `mc-release-lock.sh` | Lock cleanup | ~25 |
| 5 | `mc-heartbeat.sh` | Background heartbeat daemon (30s interval) | ~25 |
| 6 | `mc-backup-registry.sh` | Registry backup + timestamp + checksum | ~35 |
| 7 | `mc-validate-registry.sh` | jq validation + content checks (T1-T4) | ~40 |
| 8 | `mc-safety-check.sh` | Pre-execution safety gate (registry xref, uncommitted check) | ~60 |
| 9 | `mc-index-append.sh` | Append-only sessions.jsonl entry | ~40 |
| 10 | `mc-change-impact-build.sh` | Build change-impact.json artifact from session data | ~70 |
| 11 | `mc-postgate-check.sh` | T1→T4 validation cho bất kỳ phase/file | ~55 |

**Tổng:** ~535 dòng bash code.

## Chi tiết từng script

Full code samples → xem [`02-architecture-design.md`](../02-architecture-design.md) §3.

## Acceptance Criteria

| # | Criteria | Verify bằng |
|---|----------|-------------|
| AC1 | Tất cả 11 scripts tồn tại, executable (`chmod +x`) | `ls -la .claude/scripts/wf-manage-change/` |
| AC2 | `mc-common.sh` sourced bởi 10 scripts khác — không lỗi | `bash -n mc-generate-session-id.sh` (syntax check) |
| AC3 | `mc-generate-session-id.sh` generate unique ID, retry khi duplicate | Manual test: chạy 2 lần liên tiếp → 2 IDs khác nhau |
| AC4 | `mc-validate-registry.sh` pass khi registry valid, fail khi invalid | Test với valid JSON + invalid JSON |
| AC5 | `mc-backup-registry.sh` tạo backup file + output JSON checksum | `jq '.' backup.json` pass |
| AC6 | `mc-postgate-check.sh` trả JSON `{"pass":true/false,...}` | Test với file valid + file missing |
| AC7 | `mc-index-append.sh` append entry vào sessions.jsonl | `tail -1 sessions.jsonl` là JSON valid |
| AC8 | `mc-acquire-lock.sh` phát hiện stale lock (>60 min) → allow takeover | Manual test: tạo lock cũ → chạy acquire |
| AC9 | Mỗi script có `set -euo pipefail` ở đầu | `head -3 mc-*.sh` |

## Token Saving Estimate

| Task | Inline tokens | Script call tokens | Saving |
|------|---------------|-------------------|--------|
| Session ID gen (with retry) | ~150 | ~40 | 73% |
| Registry backup + validate | ~100 | ~30 | 70% |
| Lock acquire/release | ~80 | ~25 | 69% |
| T1→T4 POST-GATE | ~200 | ~50 | 75% |
| Registry safe-write validate | ~180 | ~45 | 75% |
| **Per run** | **~710** | **~190** | **73%** |

## Risks

| Risk | Mitigation |
|------|------------|
| `jq` không có trên Windows | `jq` đã có trong prerequisites (CLAUDE.md §Lệnh Thường Dùng). Trên Windows: Git Bash hoặc WSL. |
| `date` format khác giữa GNU/BSD | Dùng GNU date format (`date -u +"%Y-%m-%dT%H:%M:%SZ"`). Git Bash trên Windows có GNU date. |
| `sha256sum` không có trên macOS | macOS dùng `shasum -a 256`. Wrap trong mc-common.sh: `command -v sha256sum >/dev/null && sha256sum || shasum -a 256` |

## Definition of Done

- [ ] 11 scripts tạo trong `.claude/scripts/wf-manage-change/`
- [ ] Mỗi script `chmod +x`
- [ ] Syntax check pass (`bash -n`)
- [ ] Manual test AC1-AC9 pass
- [ ] Code review: naming consistent (`mc-` prefix), error handling đồng nhất
