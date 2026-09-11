# Shared Protocols — Redirect

> **Refactored 2026-04-19:** File này đã được tách thành 20 protocol files riêng.
> File này giữ lại CHỈ làm redirect backward-compatible.

---

## Entry point

→ **Quick map + index đầy đủ:** [protocols/README.md](protocols/README.md)
→ **Protocol files:** [protocols/](protocols/) — 19 files + README
→ **Templates:** [templates/](templates/) — digest, execution-plan

## Cách reference từ skills mới

**Recommended pattern (gọn):**
```markdown
> **Protocol:** Xem `.claude/skills/protocols/` — `06-token-limit`, `07-parallel-execution`, `08-content-quality-gate`.
```

**Per-protocol full path (rõ ràng):**
```markdown
> **Protocol:** Xem [.claude/skills/protocols/06-token-limit.md](.claude/skills/protocols/06-token-limit.md) §6.6 (Large Project Mode).
```

## Lịch sử

| Giai đoạn | Commit | Ngày | Thay đổi |
|-----------|--------|------|----------|
| 1 Split | `3e57c23` | 2026-04-19 | Tách 1609-line monolith → 20 protocol files + 2 templates |
| 2 Update refs | `b98d8e0` | 2026-04-19 | Update 95+ references skills/ + external → protocols/ |
| 3 Cleanup | *this commit* | 2026-04-19 | Slim file này thành pure redirect |

**Audit báo cáo:** `.mc-data/work/shared-protocols-refactor-audit/audit-report.md`
