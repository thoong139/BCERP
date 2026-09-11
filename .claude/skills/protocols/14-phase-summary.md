<!-- From shared-protocols.md lines 1075-1121 (§14) -->
# Protocol 14 — Phase Summary Protocol (BẮT BUỘC — MỌI SKILL)

> Người không chuyên cần biết "phase này đã làm gì" bằng ngôn ngữ đọc được.

## 14.1 Output

- File: `.mc-data/work/[skill-name]/phase-summary.md`
- Template: `.claude/doc-framework/_meta/phase-summary.template.md`
- Tạo bởi: mỗi skill, SAU POST-GATE structural checks pass
- **Trường hợp FAIL:** Nếu POST-GATE fail sau 3 iterations → VẪN tạo phase-summary.md với trạng thái "THẤT BẠI", ghi rõ phase dừng ở đâu + errors. KHÔNG bỏ qua summary khi fail.

**Exception — Sub-skills spawned bởi orchestrator multi-run family:**

Các skill được spawn bởi orchestrator dùng shared session directory (fix-bugs family) PHẢI ghi phase-summary.md vào `$SESSION_DIR/phase-summary.md` (đường dẫn session cụ thể của orchestrator) thay vì `.mc-data/work/[skill-name]/phase-summary.md`. Mỗi phase chạy sẽ overwrite phase-summary.md của phase trước — người dùng xem summary cuối cùng.

| Orchestrator | Sub-skills | phase-summary.md path |
|-------------|-----------|----------------------|
| `wf-fix-bugs` | `wf-fix-triage`, `wf-fix-execute` | `.mc-data/work/wf-fix-bugs/[sessions/{sys}/{mod}/]run-NNN--YYYYMMDD/phase-summary.md` |

**Rationale:** Sub-skills trong cùng pipeline chia sẻ SESSION_DIR để co-locate toàn bộ artifacts của 1 lần chạy (fix-status.json, issue-registry.json, phase-summary.md per phase). Tránh fragmented output giữa nhiều skill directory.

**Quy tắc phase-summary.md cho orchestrator family:**
- Mỗi sub-skill ghi summary cho phase của mình — overwrite phase-summary.md trước đó
- Nội dung vẫn tuân thủ §14.2 (tiếng Việt, ≤15 dòng, non-technical)
- Orchestrator có thể aggregate summaries cross-phase vào `fix-report.md` (hoặc tương đương) ở phase cuối

## 14.2 Quy tắc nội dung

QUY TẮC:
1. Viết bằng TIẾNG VIỆT — ngôn ngữ doanh nghiệp, không thuật ngữ kỹ thuật
2. Tối đa 15 dòng — người đọc nắm được trong 30 giây
3. "Đã làm gì" tập trung vào KẾT QUẢ, không mô tả quá trình
4. "Cần lưu ý" chỉ ghi items cần user action — không ghi warnings đã auto-fix
5. "Bước tiếp theo" PHẢI chỉ đúng skill tiếp theo trong workflow
6. KHÔNG duplicate nội dung chi tiết đã có trong docs
7. DEFERRED findings từ Stakeholder Review PHẢI xuất hiện trong "Cần lưu ý"

## 14.3 Resume & Re-run Behavior

| Tình huống | Behavior |
|-----------|----------|
| Skill chạy lần đầu | Tạo phase-summary.md mới |
| Skill chạy lại từ đầu (không --resume) | Overwrite phase-summary.md |
| Skill resume từ checkpoint (--resume) | GIỮ NGUYÊN summary cũ, chỉ UPDATE khi phase cuối hoàn thành |

## 14.4 Hiển thị cho user
Sau khi ghi phase-summary.md → HIỂN THỊ nội dung trong conversation.
