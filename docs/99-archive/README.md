# 99 — Archive

> **Mục đích:** Lưu trữ tài liệu **superseded / deprecated / một-lần-dùng** — giữ lịch sử để tra cứu, không tiếp tục cập nhật.
> **Quy tắc:** Mọi file ở đây là **READ-ONLY**. Không sửa, không xóa (trừ khi có lý do rõ).

---

## 1. Tại sao có folder này?

Trong quá trình tái cấu trúc `docs/` (Wave 1-4), nhiều file cũ bị **thay thế** bởi nội dung mới ở `00-overview/`, `01-architecture/`, `04-skill-design/`, `02-standards/`. Thay vì xóa, giữ lại ở đây để:

- Truy vết lịch sử quyết định cũ
- Cross-reference khi review tài liệu mới
- Backup khi cần rollback

---

## 2. Categories

### 2.1. Legacy overview / catalog files

| File | Đã thay bởi |
|------|-------------|
| [`project-description-LEGACY.md`](project-description-LEGACY.md) | [`../00-overview/01-project-description.md`](../00-overview/01-project-description.md) |
| [`mcv3-development-priorities-LEGACY.md`](mcv3-development-priorities-LEGACY.md) | [`../00-overview/02-positioning-priorities.md`](../00-overview/02-positioning-priorities.md) |
| [`skills-reference-LEGACY.md`](skills-reference-LEGACY.md) | [`../01-architecture/07-skills-catalog.md`](../01-architecture/07-skills-catalog.md) |
| [`skills-dependency-graph-LEGACY.md`](skills-dependency-graph-LEGACY.md) | [`../01-architecture/09-dependencies-graph.md`](../01-architecture/09-dependencies-graph.md) |

### 2.2. Design legacy — [`design-legacy/`](design-legacy/)

15 ADR + phase files cũ từ `docs/design/skills/` (root level, không thuộc skill nào):
- 2 ADR cho downstream-skills-optimization
- 13 phase rollout files (phase1-5)

**Status:** ✅ Quyết định đã được áp dụng → giữ làm reference, không tiếp tục cập nhật.

### 2.3. wf-fix-bugs implementation artifacts

| Folder | Nội dung |
|--------|---------|
| [`wf-fix-bugs-prompts/`](wf-fix-bugs-prompts/) | Prompts engineering cho lane skills (đã đưa vào lane SKILL.md) |
| [`wf-fix-bugs-reviews/`](wf-fix-bugs-reviews/) | Review notes per sprint trong quá trình phát triển v10 |
| [`wf-fix-bugs-scripts/`](wf-fix-bugs-scripts/) | Helper scripts thử nghiệm (final scripts đã ở `.claude/scripts/`) |

### 2.4. wf-legacy-scan implementation artifacts

| Folder | Nội dung |
|--------|---------|
| [`wf-legacy-scan-implementation/`](wf-legacy-scan-implementation/) | Session logs + implementation notes (16 file) |
| [`wf-legacy-scan-archive/`](wf-legacy-scan-archive/) | Snapshots cũ |
| [`wf-legacy-scan-fixtures/`](wf-legacy-scan-fixtures/) | Test fixtures dùng trong quá trình dev |
| [`wf-legacy-scan-examples/`](wf-legacy-scan-examples/) | Examples output cũ |

### 2.5. Ad-hoc prompts / one-time docs

| File | Lý do archive |
|------|---------------|
| [`wf-fix-bugs-fix-prompt-2026-05-15.md`](wf-fix-bugs-fix-prompt-2026-05-15.md) | Prompt 1-lần để fix bug session 2026-05-15 |
| [`e2e-test-wf-fix-bugs-prompt.md`](e2e-test-wf-fix-bugs-prompt.md) | Prompt E2E test 1-lần |
| [`template-usage-audit-prompts.md`](template-usage-audit-prompts.md) | Audit prompts cho template usage check |
| [`DEVKIT-extraction.md`](DEVKIT-extraction.md) | Doc tách DEVKIT khỏi EUREKA — đã hoàn tất |
| [`codex-guide.md`](codex-guide.md) | Hướng dẫn Codex (legacy) |

---

## 3. Quy tắc xử lý file trong archive

| Action | Khi nào | Cách làm |
|--------|---------|---------|
| Đọc tham khảo | Khi cần truy vết lịch sử | OK, luôn được |
| Sửa nội dung | Sửa typo / cập nhật version pointer | OK nhỏ |
| Restore (move ra khỏi archive) | Nếu phát hiện canonical mới có gap quan trọng | Discuss với owner, document trong CHANGELOG |
| Xóa hẳn | Khi file gây nhầm lẫn + nội dung đã merge vào canonical | Cần PR review |

---

## 4. Khi nào archive file mới?

Khi muốn archive file:

1. Xác định **canonical replacement** (file mới thay nó là gì)
2. Đặt rename pattern: `{original-name}-LEGACY.md` HOẶC giữ tên + để trong category folder
3. Update §2 của file này (`99-archive/README.md`) với row mới
4. Cross-link 2 chiều: archive file mention canonical, canonical mention archive (nếu cần)

---

## 5. Liên kết

- **Canonical replacement sources:** [`../00-overview/`](../00-overview/), [`../01-architecture/`](../01-architecture/), [`../04-skill-design/`](../04-skill-design/)
- **CHANGELOG (lịch sử thay đổi):** [`../../CHANGELOG.md`](../../CHANGELOG.md)
- **Plan tái cấu trúc:** [`../../plans/docs-restructure-v1/`](../../plans/docs-restructure-v1/)
