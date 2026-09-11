# Phase 6: Sinh Digest Artifact (TỰ ĐỘNG — Phase Cuối)

> **Giai đoạn tự động** — KHÔNG hỏi user.
> Tạo `project-digest.json` từ Phase 0 output để downstream skills (đặc biệt `/wf-analyze-requirements`) load nhanh.
> Mapping sang SKILL.md: Phase 3 của SKILL.md → Phase 6 của procedures.

**PRE-GATE:**

- [ ] Phase 5 (phase5-init-registry.md) POST-GATE PASS
- [ ] `req-registry.json` đã được seed
- [ ] `project-intent-digest.json` đã tồn tại
- [ ] P0-01 và P0-02 đã được validate ở Phase 4 POST-GATE

**INPUT:** P0-01-brainstorm.md, P0-02-systems-users.md, req-registry.json

**OUTPUT:**
- `.mc-data/docs/_meta/project-digest.json` (compact ~200 words)
- Final state: `brainstorm-status.json` status = "completed"

---

## Reference Sections

- `_shared.md` §3 Template Usage Rule
- `_shared.md` §4 Status Tracking Protocol

---

## Step 6.1: Đọc Context Cho Digest

| Step | Hành động | Tool | Verify |
|------|-----------|------|--------|
| 6.1 | Đọc P0-01, P0-02, req-registry.json — thu thập context cho digest | Read | Context sẵn sàng |

---

## Step 6.2: Tạo `project-digest.json` (Template Usage Rule §3)

| Step | Hành động | Tool | Verify |
|------|-----------|------|--------|
| 6.2.1 | READ `.claude/doc-framework/_digests/project-digest.template.json` | Read | Template loaded |
| 6.2.2 | POPULATE: `project_name`, `project_summary`, `departments[]`, `systems[]`, `interface_type`, `tech_stack_summary`, `key_constraints[]`, `nfr_highlights`, `project_complexity` (**BẮT BUỘC map**: SIMPLE → `"low"`, STANDARD → `"medium"`, ENTERPRISE → `"high"` để khớp enum `'low' \| 'medium' \| 'high' \| 'very_high'` của schema digest) | — | Fields populated, project_complexity ∈ enum |
| 6.2.3 | WRITE `.mc-data/docs/_meta/project-digest.json` | Write | Digest hợp lệ JSON, ~200 words |

> **⚠️ Complexity Mapping (BẮT BUỘC):**
> Skill wf-brainstorm classify 3 mức `SIMPLE / STANDARD / ENTERPRISE` (xem `_shared.md §7`).
> Digest schema dùng 4 mức `low / medium / high / very_high`.
> Mapping dưới đây là quy chuẩn — KHÔNG được ghi trực tiếp `"SIMPLE"` vào digest.
>
> | Skill verdict | Digest value |
> |---------------|--------------|
> | SIMPLE | `"low"` |
> | STANDARD | `"medium"` |
> | ENTERPRISE | `"high"` |
> | (reserved for future mega-projects) | `"very_high"` |

---

## Step 6.3: Finalize Status

| Step | Hành động | Tool | Verify |
|------|-----------|------|--------|
| 6.3 | Update `brainstorm-status.json`: `status = "completed"`, `verdict = "pass"`, `current_phase = "completed"`, `phases.phase_6.status = "done"`, `phases.phase_6.completed_at = NOW`, `timestamps.completed_at = NOW`, `timestamps.last_updated = NOW`. Update artifacts: `project_digest.created = true` | Write | Status reflects completion |

---

## Step 6.4: Tạo `phase-summary.md` (CORE-028 — BẮT BUỘC)

> Shared Protocol §14 — viết bằng tiếng Việt cho non-specialist, tối đa 15 dòng.

| Step | Hành động | Tool | Verify |
|------|-----------|------|--------|
| 6.4.1 | READ template `.claude/doc-framework/_meta/phase-summary.template.md` | Read | Template loaded |
| 6.4.2 | POPULATE: "Đã làm gì" (đã chốt khung dự án + N phòng ban + complexity), "Kết quả" (P0-01, P0-02, N policies, registry seeded, digest), "Thay đổi chính" (các decision quan trọng), "Cần lưu ý" (pending items, [Cần làm rõ], legacy decisions nếu có), "Bước tiếp theo" = "Chạy `/wf-analyze-requirements`" | — | Fields populated |
| 6.4.3 | WRITE `.mc-data/work/wf-brainstorm/phase-summary.md` | Write | `test -s .mc-data/work/wf-brainstorm/phase-summary.md` |
| 6.4.4 | HIỂN THỊ nội dung phase-summary.md trong conversation (§14.4) | Output | User thấy summary |

---

## Step 6.5: Append Session Log (CORE-026 — BẮT BUỘC)

> Shared Protocol §15 — output-only observability.

| Step | Hành động | Tool | Verify |
|------|-----------|------|--------|
| 6.5.1 | `mkdir -p .mc-data/work/_trace` + nếu `session-log.json` chưa tồn tại → tạo từ template `.claude/doc-framework/_meta/session-log.template.json` | Bash + Write | File exists |
| 6.5.2 | APPEND event `COMPLETE`: `{skill: "wf-brainstorm", event: "COMPLETE", timestamp: NOW, files_created: [P0-01, P0-02, policies/*, req-registry.json, project-digest.json], phase: "phase6-generate-digest"}` dùng atomic pattern `tmp=$(mktemp); jq '.entries += [...]' session-log.json > "$tmp" && mv "$tmp" session-log.json` | Bash | `jq '.entries | length > 0' session-log.json` |

> Failure log KHÔNG block skill execution — log là best-effort (§15.3 quy tắc 5).

---

## Fallback

> Nếu digest generation fail → log warning trong `brainstorm-status.json.error_log`, tiếp tục (backward compatible — consumer skill sẽ đọc full docs).
>
> Nếu phase-summary.md fail → VẪN tạo file với trạng thái "THẤT BẠI", ghi rõ lỗi (§14.1 exception). KHÔNG bỏ qua summary.
>
> Nếu session-log.json fail → log warning, tiếp tục (best-effort).

---

## POST-GATE Phase 6

- T1: `test -f .mc-data/docs/_meta/project-digest.json` — digest file created
- T2: `test -s .mc-data/docs/_meta/project-digest.json` — digest non-empty
- T3: `jq empty .mc-data/docs/_meta/project-digest.json` — valid JSON
- T4: `grep -q "project_summary" .mc-data/docs/_meta/project-digest.json` — meaningful content present
- T5: `jq -e '.status == "completed" and .verdict == "pass"' .mc-data/work/wf-brainstorm/brainstorm-status.json`

---

## Output Report (Final)

```markdown
## /wf-brainstorm Hoàn tất!

| Mục | Giá trị |
|-----|---------|
| Tên dự án | [project_name] |
| Lĩnh vực | [industry] |
| Mức phức tạp | [SIMPLE / STANDARD / ENTERPRISE] |
| P0-01 | `.mc-data/docs/phase0-brainstorm/P0-01-brainstorm.md` |
| P0-02 | `.mc-data/docs/phase0-brainstorm/P0-02-systems-users.md` |
| Policy files | [N] files trong `policies/` (hoặc "Không cần — dự án SIMPLE") |
| Phòng ban | [N] phòng ban tham gia |
| Phân hệ | [N] modules |
| Chuyên gia | [N] domain experts |
| Cấu trúc .mc-data/ | Tối thiểu cho Phase 0 (docs/_meta, phase0-brainstorm, sync) |
| Registry | `.mc-data/docs/_meta/req-registry.json` — seeded (project, departments, interface_type) |
| Digest | `.mc-data/docs/_meta/project-digest.json` — compact overview cho downstream skills |
| Handoff Phase 1 | `.mc-data/work/wf-brainstorm/project-intent-digest.json` |
| Working files | `.mc-data/work/wf-brainstorm/` |

> **Lưu ý:** Skill này KHÔNG tự tạo `stakeholder-review.md` — đây là bước review thủ công do stakeholder thực hiện sau khi đọc P0-01, P0-02 và policies/. Template có sẵn tại `.claude/doc-framework/phase0-brainstorm/stakeholder-review.md`.

Next: `/wf-analyze-requirements` để bắt đầu phân tích yêu cầu

> Xem kết quả trong các file trên. Nếu cần điều chỉnh, hãy yêu cầu trực tiếp.
```

---

## Next Phase

→ **END OF SKILL.** Hand-off cho `/wf-analyze-requirements`.

> Skill kết thúc. Output cho consumer skills:
> - `.mc-data/docs/_meta/project-digest.json` → `/wf-analyze-requirements` Phase 0.1 (PRE-GATE digest loading)
> - `.mc-data/docs/phase0-brainstorm/P0-01-brainstorm.md`, `P0-02-systems-users.md`, `policies/`
> - `.mc-data/docs/_meta/req-registry.json` (seeded)
> - `.mc-data/work/wf-brainstorm/project-intent-digest.json`
