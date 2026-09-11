# 07 — Operations

> **Mục đích:** Tài liệu vận hành — **runbooks** (xử lý sự cố), **migrations** (di chuyển version), **release notes** (changelog per version), **audits** (báo cáo kiểm toán).
> **Đối tượng:** Skill author, contributor, ops engineer.

---

## 1. Đọc theo tình huống

| Tình huống | Folder |
|-----------|--------|
| Skill đang chạy bị lỗi, cần troubleshoot | [`runbooks/`](runbooks/) |
| Cần upgrade skill từ version cũ → version mới | [`migrations/`](migrations/) |
| Muốn biết version X có gì mới so với version Y | [`release-notes/`](release-notes/) |
| Cần xem báo cáo audit (DEVKIT self-check) | [`audits/`](audits/) (chưa có content) |

---

## 2. Cấu trúc

```
07-operations/
├── README.md                  ← File này
├── runbooks/                  ← Step-by-step xử lý sự cố
├── migrations/                ← Hướng dẫn nâng cấp version
├── release-notes/             ← Changelog per skill version
└── audits/                    ← Audit reports (DEVKIT self-check)
```

---

## 3. Runbooks

| File | Skill | Mục đích |
|------|-------|----------|
| [`runbooks/wf-fix-bugs-troubleshooting.md`](runbooks/wf-fix-bugs-troubleshooting.md) | wf-fix-bugs | Xử lý lỗi thường gặp khi chạy `/wf-fix-bugs` |

**Còn thiếu:** Runbooks cho skill khác — sẽ bổ sung khi gặp incident thật.

---

## 4. Migrations

| File | Từ → Đến |
|------|----------|
| [`migrations/wf-e2e-migration-guide.md`](migrations/wf-e2e-migration-guide.md) | E2E pre-v8 → v8 (pipeline 11-step) |
| [`migrations/wf-e2e-rollback-strategy.md`](migrations/wf-e2e-rollback-strategy.md) | Strategy rollback khi v8 fail |
| [`migrations/wf-e2e-rollout-phases.md`](migrations/wf-e2e-rollout-phases.md) | Phased rollout cho wf-e2e-* v8 |
| [`migrations/wf-fix-bugs-v7-migration-guide.md`](migrations/wf-fix-bugs-v7-migration-guide.md) | wf-fix-bugs v6.x → v7 |

---

## 5. Release notes

| File | Skill | Version |
|------|-------|---------|
| [`release-notes/wf-e2e-performance-baseline.md`](release-notes/wf-e2e-performance-baseline.md) | wf-e2e-* | v8 performance baseline |
| [`release-notes/wf-e2e-pipeline-v8-guide.md`](release-notes/wf-e2e-pipeline-v8-guide.md) | wf-e2e-* | v8 pipeline overview |
| [`release-notes/wf-fix-bugs-v10.2.1-fixes.md`](release-notes/wf-fix-bugs-v10.2.1-fixes.md) | wf-fix-bugs | v10.2.1 |
| [`release-notes/wf-fix-bugs-v9-guide.md`](release-notes/wf-fix-bugs-v9-guide.md) | wf-fix-bugs | v9 |
| [`release-notes/wf-legacy-scan-v5.0.0-release-notes.md`](release-notes/wf-legacy-scan-v5.0.0-release-notes.md) | wf-legacy-scan | v5.0.0 |
| [`release-notes/wf-preflight-v3-guide.md`](release-notes/wf-preflight-v3-guide.md) | wf-preflight | v3 |

---

## 6. Audits

Folder chưa có content. Quy ước trong tương lai:
- `audits/YYYY-MM-DD-skill-compliance-audit-report.md` — kết quả chạy `./.claude/scripts/skill-compliance-audit.sh --all`
- `audits/YYYY-MM-DD-cross-reference-audit-report.md` — kết quả chạy `audit-devkit`
- `audits/YYYY-MM-DD-eval-suite-results.md` — kết quả chạy `run-skill-evals.sh --all`

---

## 7. Khi viết tài liệu mới trong folder này

| Loại | Quy ước đặt tên | Nơi đặt |
|------|-----------------|---------|
| Runbook | `{skill-name}-troubleshooting.md` hoặc `{skill}-{scenario}-recovery.md` | `runbooks/` |
| Migration | `{skill-name}-v{X}-migration-guide.md` | `migrations/` |
| Rollback strategy | `{skill-name}-rollback-strategy.md` | `migrations/` |
| Release notes | `{skill-name}-v{X}-{release-notes\|fixes\|guide}.md` | `release-notes/` |
| Audit report | `YYYY-MM-DD-{audit-type}-report.md` | `audits/` |

**Bắt buộc:**
- Tiếng Việt cho user-facing prose
- Tham chiếu **đầy đủ version + ngày** trong tiêu đề
- Cross-link tới: SKILL.md tương ứng, file design canon (nếu có), CHANGELOG.md root

---

## 8. Liên kết

- **Skill catalog:** [`../01-architecture/07-skills-catalog.md`](../01-architecture/07-skills-catalog.md)
- **Skill design canon:** [`../04-skill-design/`](../04-skill-design/)
- **Review standards (gate trước release):** [`../05-review-standards/`](../05-review-standards/)
- **Root changelog:** [`../../CHANGELOG.md`](../../CHANGELOG.md)
