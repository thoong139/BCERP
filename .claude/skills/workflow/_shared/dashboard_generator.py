#!/usr/bin/env python3
"""dashboard_generator.py — Tạo Bug/Signal Tracking Dashboard từ templates (CORE-031).

Vai trò:
    Đọc issue-registry.json + fix-log.json + fix-report.md (nếu có) →
    populate bug-dashboard.md template → ghi output.

Dùng bởi wf-fix-bugs pipeline:
    - Phase 5 (sau triage): tạo dashboard ban đầu (tất cả issues = pending)
    - Phase 6 (sau execute): cập nhật dashboard với kết quả fix
    - Phase 7 (verify): hoàn thiện dashboard cuối cùng

Registry role: NONE. Chỉ đọc input artifacts và ghi output dashboard.

Tham chiếu:
    - CORE-031: Template Usage Rule
    - CORE-028: Vietnamese output ≤40 dòng (dashboard được miễn trừ vì là bảng dữ liệu)
"""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

# ──────────────────────────────────────────────────────────────────────
# Constants
# ──────────────────────────────────────────────────────────────────────

STATUS_ICONS: dict[str, str] = {
    "fixed": "✅",
    "pending": "⬜",
    "in_progress": "🔄",
    "deferred": "⏸️",
    "failed": "❌",
    "cdg_blocked": "⚠️",
    "info": "ℹ️",
}

STATUS_LABELS: dict[str, str] = {
    "fixed": "Đã sửa",
    "pending": "Chưa xử lý",
    "in_progress": "Đang sửa",
    "deferred": "Hoãn lại",
    "failed": "Thất bại",
    "cdg_blocked": "Cần quyết định",
    "info": "Thông tin",
}

SEVERITY_BADGES: dict[str, str] = {
    "critical": "🔴 CRITICAL",
    "high": "🟠 HIGH",
    "medium": "🟡 MEDIUM",
    "low": "🟢 LOW",
    "info": "🔵 INFO",
}

SEVERITY_ORDER: dict[str, int] = {
    "critical": 0,
    "high": 1,
    "medium": 2,
    "low": 3,
    "info": 4,
}

# Dimension → recommended skill for standalone handling
DIM_SKILL_MAP: dict[str, str] = {
    "QD1": "`/wf-implement-feature [tên]` — sửa lỗi chức năng",
    "QD2": "`/wf-analyze-requirements` + domain expert agent — xem xét lại nghiệp vụ",
    "QD3": "`/wf-fix-bugs --dims=QD3 --profile=deep` — kiểm tra bảo mật chuyên sâu",
    "QD4": "`/wf-fix-bugs --dims=QD4 --profile=deep` — tối ưu hiệu năng",
    "QD5": "`/wf-fix-bugs --dims=QD5` hoặc `/ui-ux-pro-max` — sửa UX / accessibility",
    "QD6": "`/wf-fix-bugs --dims=QD6 --profile=deep` — kiểm tra dữ liệu",
    "QD7": "`/wf-fix-bugs --dims=QD7 --profile=deep` — kiểm tra tương thích",
    "QD8": "`/wf-fix-bugs --dims=QD8` — kiểm tra observability",
    "QD9": "`/wf-fix-bugs --dims=QD9 --profile=deep` — kiểm tra runtime health",
    "QD10": "`/wf-fix-bugs --dims=QD10 --profile=deep` — kiểm tra tích hợp",
    "QD11": "`/wf-fix-bugs --dims=QD11 --profile=deep` — phân tích business completeness",
}

# ──────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────


def _populate_template(template: str, replacements: dict[str, str]) -> str:
    """Replace [PLACEHOLDER] markers trong markdown template."""
    result = template
    for key, value in replacements.items():
        result = result.replace(f"[{key}]", str(value))
    return result


def _get_fix_status(issue: dict, fix_log_entries: list[dict]) -> str:
    """Xác định trạng thái sửa của 1 issue từ fix-log.

    Hỗ trợ 2 schema:
      - Runtime: {"status": "fixed"|"deferred", ...}
      - Template fix-log-v2: {"action": "...", "result": "...", ...}
    """
    issue_id = issue.get("issue_id", "")
    matching = [e for e in fix_log_entries if e.get("issue_id") == issue_id]
    if not matching:
        triage_status = issue.get("triage_status", "pending")
        if triage_status == "deferred":
            return "deferred"
        if triage_status == "closed":
            return "info"
        return "pending"
    latest = matching[-1]

    # Runtime schema: entry có field "status" trực tiếp
    runtime_status = latest.get("status", "")
    if runtime_status == "fixed":
        return "fixed"
    if runtime_status == "deferred":
        return "deferred"

    # Template fix-log-v2 schema: action + result
    action = latest.get("action", "")
    result = latest.get("result", "")
    if action == "cdg_blocked":
        return "cdg_blocked"
    if action == "defer":
        return "deferred"
    if result == "success":
        return "fixed"
    if result == "partial":
        return "in_progress"
    if result == "failed":
        return "failed"
    return "pending"


def _get_guidance(issue: dict, fix_status: str, fix_log_entries: list[dict]) -> str:
    """Tạo hướng dẫn xử lý cho issue chưa được fix."""
    if fix_status == "fixed":
        return ""

    severity = (issue.get("severity") or "medium").lower()
    dimensions = issue.get("dimensions", [])
    triage_status = issue.get("triage_status", "pending")
    fixability = issue.get("fixability") or "unknown"
    issue_id = issue.get("issue_id", "")
    target = issue.get("target", {})
    target_file = target.get("file", "") if isinstance(target, dict) else str(target)

    guidance_parts: list[str] = []

    if fix_status == "cdg_blocked":
        matching = [e for e in fix_log_entries if e.get("issue_id") == issue_id]
        note = ""
        if matching:
            note = matching[-1].get("summary") or matching[-1].get("notes", "")
        guidance_parts.append(f"> ⚠️ **Cần quyết định từ bạn:** {note}")
        guidance_parts.append(f"> Vui lòng xem lại `fix-plan.md` mục [{issue_id}] và chọn ACCEPT / REJECT / MODIFY.")
        return "\n".join(guidance_parts)

    if fix_status == "deferred" or triage_status == "deferred":
        guidance_parts.append(f"> ⏸️ **Lý do hoãn lại:** {_get_defer_reason(issue, fix_log_entries)}")
        guidance_parts.append(f"> **Khuyến nghị:** {_get_skill_recommendation(dimensions, severity, fixability)}")
        if target_file:
            guidance_parts.append(f"> **File cần xem:** `{target_file}`")
        return "\n".join(guidance_parts)

    if fix_status == "failed":
        matching = [e for e in fix_log_entries if e.get("issue_id") == issue_id]
        reason = ""
        if matching:
            reason = matching[-1].get("summary") or matching[-1].get("notes", "") or matching[-1].get("error_code", "")
        guidance_parts.append(f"> ❌ **Lý do thất bại:** {reason}")
        guidance_parts.append(f"> **Khuyến nghị:** {_get_skill_recommendation(dimensions, severity, fixability)}")
        return "\n".join(guidance_parts)

    if fix_status == "pending":
        if severity in ("critical", "high"):
            guidance_parts.append(f"> 🔴 **Ưu tiên cao** — nên xử lý trong đợt sửa tiếp theo.")
        guidance_parts.append(f"> **Cách xử lý:** {_get_skill_recommendation(dimensions, severity, fixability)}")
        return "\n".join(guidance_parts)

    return ""


def _get_defer_reason(issue: dict, fix_log_entries: list[dict]) -> str:
    """Trích xuất lý do hoãn lại từ fix-log hoặc issue metadata."""
    issue_id = issue.get("issue_id", "")
    matching = [e for e in fix_log_entries if e.get("issue_id") == issue_id]
    if matching:
        # Runtime schema: summary; Template schema: notes
        reason = matching[-1].get("summary") or matching[-1].get("notes", "")
        if reason:
            return reason
    fixability = issue.get("fixability") or "unknown"
    if fixability == "manual":
        return "Cần can thiệp thủ công — vượt khả năng tự động sửa."
    if fixability == "deferred":
        return "Được đánh giá là chưa cần thiết ở thời điểm hiện tại."
    return "Không rõ lý do — xem chi tiết trong bug-triage.md."


def _get_skill_recommendation(dimensions: list[str], severity: str, fixability: str) -> str:
    """Đề xuất skill MCV3 dựa trên dimension và severity."""
    if fixability == "manual":
        if "QD3" in dimensions:
            return f"Yêu cầu **security expert** kiểm tra thủ công. Chạy {DIM_SKILL_MAP['QD3']} để có thêm phân tích."
        if "QD2" in dimensions:
            return f"Cần **business analyst** xem xét lại logic nghiệp vụ. Chạy {DIM_SKILL_MAP['QD2']}."
        if "QD11" in dimensions:
            return f"Cần phân tích business completeness chuyên sâu. Chạy {DIM_SKILL_MAP['QD11']}."
        return "Cần **developer** xem xét thủ công. Tham khảo `bug-triage.md` để biết chi tiết."

    recs = []
    for dim in dimensions:
        if dim in DIM_SKILL_MAP:
            recs.append(DIM_SKILL_MAP[dim])
    if not recs:
        if severity in ("critical", "high"):
            return "Chạy lại `/wf-fix-bugs --profile=deep` để phân tích chuyên sâu hơn."
        return "Chạy `/wf-fix-bugs --scope=module --name=[tên]` để sửa trong phạm vi hẹp hơn."
    return recs[0]


def _get_dimension_names(dimensions: list[str]) -> str:
    """Chuyển danh sách dimension IDs thành tên hiển thị."""
    dim_names = {
        "QD1": "Chức năng", "QD2": "Nghiệp vụ", "QD3": "Bảo mật",
        "QD4": "Hiệu năng", "QD5": "UX/A11y", "QD6": "Dữ liệu",
        "QD7": "Tương thích", "QD8": "Observability", "QD9": "Runtime Health",
        "QD10": "Tích hợp", "QD11": "Business Completeness",
    }
    return ", ".join(dim_names.get(d, d) for d in dimensions)


# ──────────────────────────────────────────────────────────────────────
# Row Builders
# ──────────────────────────────────────────────────────────────────────


def _build_issue_rows(issues: list[dict], fix_log_entries: list[dict]) -> str:
    """Tạo markdown cho danh sách issues."""
    if not issues:
        return "> ✅ **Không có lỗi nào được phát hiện.** Hệ thống healthy.\n"

    # Sort by severity then status (pending first)
    sorted_issues = sorted(issues, key=lambda i: (
        SEVERITY_ORDER.get((i.get("severity") or "medium").lower(), 2),
        0 if _get_fix_status(i, fix_log_entries) in ("pending", "in_progress", "cdg_blocked") else 1,
    ))

    rows: list[str] = []
    for issue in sorted_issues:
        issue_id = issue.get("issue_id", "ISS-????")
        severity = (issue.get("severity") or "medium").lower()
        title = issue.get("title") or issue.get("description") or "(không có mô tả)"
        if len(title) > 120:
            title = title[:117] + "..."

        # Runtime schema: file_path + line; Template schema: target.file + target.line_range
        target_file = issue.get("file_path", "?")
        target_line = str(issue.get("line", "?"))
        if not target_file or target_file == "?":
            target = issue.get("target", {})
            if isinstance(target, dict):
                target_file = target.get("file", "?")
                target_line = str(target.get("line_range", target.get("line", "?")))
            elif target:
                target_file = str(target)

        # Runtime schema: single "dimension" string; Template: "dimensions" array
        dimensions = issue.get("dimensions", [])
        if not dimensions:
            single_dim = issue.get("dimension", "")
            if single_dim:
                dimensions = [single_dim]
        dim_display = _get_dimension_names(dimensions)

        fix_status = _get_fix_status(issue, fix_log_entries)
        icon = STATUS_ICONS.get(fix_status, "⬜")
        label = STATUS_LABELS.get(fix_status, "Không rõ")
        badge = SEVERITY_BADGES.get(severity, "⚪ UNKNOWN")

        guidance = _get_guidance(issue, fix_status, fix_log_entries)

        # Action taken (from fix-log). Hỗ trợ runtime schema (status/files_changed/summary)
        # và template fix-log-v2 schema (action/result/file_changed/notes).
        matching = [e for e in fix_log_entries if e.get("issue_id") == issue_id]
        action_taken = ""
        if matching:
            latest = matching[-1]
            # Runtime schema
            if latest.get("status") == "fixed":
                files = latest.get("files_changed", [])
                file_str = files[0] if files else "?"
                action_taken = f"Đã sửa trong `{file_str}`"
            elif latest.get("status") == "deferred":
                action_taken = "Đã hoãn — " + (latest.get("summary") or "xem chi tiết bên dưới")
            # Template fix-log-v2 schema
            elif latest.get("result") == "success":
                action_taken = f"Đã sửa trong `{latest.get('file_changed', '?')}` ({latest.get('duration_sec', 0)}s)"
            elif latest.get("result") == "partial":
                action_taken = f"Sửa một phần trong `{latest.get('file_changed', '?')}` — cần kiểm tra lại"
            elif latest.get("action") == "defer":
                action_taken = "Đã hoãn — " + (latest.get("notes") or "xem chi tiết bên dưới")
            elif latest.get("action") == "cdg_blocked":
                action_taken = "Đang chờ quyết định từ người dùng"
            else:
                action_taken = latest.get("summary") or latest.get("notes", "") or f"Kết quả: {latest.get('result', '?')}"
        else:
            action_taken = "Chưa xử lý"

        row = (
            f"### {icon} {issue_id} — {badge} {title}\n\n"
            f"- **File:** `{target_file}` (dòng {target_line})\n"
            f"- **Khía cạnh:** {dim_display}\n"
            f"- **Trạng thái:** {icon} {label}\n"
            f"- **Hành động:** {action_taken}\n"
        )
        if guidance:
            row += f"\n{guidance}\n"
        row += "\n---\n"
        rows.append(row)

    return "\n".join(rows)


def _build_custom_actions(issues: list[dict], fix_log_entries: list[dict]) -> str:
    """Tạo section 'Hạng Mục Cần Xử Lý Thêm' cho các issue chưa resolved."""
    unresolved = []
    for issue in issues:
        status = _get_fix_status(issue, fix_log_entries)
        if status in ("pending", "deferred", "failed", "cdg_blocked", "in_progress"):
            unresolved.append((issue, status))

    if not unresolved:
        return "> ✅ Tất cả các lỗi đã được xử lý. Không có hạng mục nào cần xử lý thêm.\n"

    lines = ["Các mục dưới đây chưa được giải quyết và cần xử lý thêm:\n"]
    for issue, status in unresolved:
        issue_id = issue.get("issue_id", "ISS-????")
        severity = (issue.get("severity") or "medium").lower()
        dimensions = issue.get("dimensions", [])
        title = issue.get("description") or issue.get("title") or "(không có mô tả)"
        if len(title) > 100:
            title = title[:97] + "..."

        icon = STATUS_ICONS.get(status, "⬜")
        skill_rec = _get_skill_recommendation(dimensions, severity, issue.get("fixability", "unknown"))

        lines.append(f"- {icon} **{issue_id}** ({SEVERITY_BADGES.get(severity, 'MEDIUM')}): {title}")
        lines.append(f"  → {skill_rec}")

    return "\n".join(lines) + "\n"


def _build_guidance_legend() -> str:
    """Tạo section hướng dẫn xử lý từng loại vấn đề."""
    return (
        "Dưới đây là các skill MCV3 có thể dùng để xử lý riêng từng loại vấn đề:\n\n"
        "| Vấn đề | Skill khuyến nghị |\n"
        "|--------|-------------------|\n"
        "| Lỗi chức năng / logic phức tạp | `/wf-implement-feature [tên]` |\n"
        "| Lỗi kiến trúc / thiết kế hệ thống | `/wf-design` |\n"
        "| Lỗi bảo mật (OWASP) | `/wf-fix-bugs --dims=QD3 --profile=deep` |\n"
        "| Lỗi hiệu năng (chậm, nặng) | `/wf-fix-bugs --dims=QD4 --profile=deep` |\n"
        "| Lỗi giao diện / UX | `/ui-ux-pro-max` hoặc `/wf-design-ux` |\n"
        "| Lỗi truy cập / accessibility | `/wf-fix-bugs --dims=QD5 --profile=deep` |\n"
        "| Lỗi dữ liệu / database | `/wf-fix-bugs --dims=QD6 --profile=deep` |\n"
        "| Lỗi tương thích (trình duyệt, thiết bị) | `/wf-fix-bugs --dims=QD7 --profile=deep` |\n"
        "| Lỗi runtime (console, network, auth) | `/wf-fix-bugs --dims=QD9 --profile=deep` |\n"
        "| Lỗi tích hợp (cross-module, API contract) | `/wf-fix-bugs --dims=QD10 --profile=deep` |\n"
        "| Thiếu logic nghiệp vụ | `/wf-fix-bugs --dims=QD11 --profile=deep` |\n"
        "| Cần phân tích yêu cầu lại | `/wf-analyze-requirements` |\n"
        "| Cần kiểm tra đồng bộ | `/wf-verify-sync` |\n"
        "| Cần kiểm tra tổng quan dự án | `/status` |\n"
    )


# ──────────────────────────────────────────────────────────────────────
# Main Generator
# ──────────────────────────────────────────────────────────────────────


def generate_dashboard(
    template_path: Path,
    output_path: Path,
    session_id: str,
    project_name: str,
    scope: str,
    profile: str,
    current_phase: str,
    issue_registry_path: Path,
    fix_log_path: Path | None = None,
    fix_report_path: Path | None = None,
    total_signals: int = 0,
    dimensions_covered: str = "",
    dimensions_total: str = "",
    fixed_count_override: int | None = None,
) -> Path:
    """READ templates + input data → POPULATE → WRITE bug-dashboard.md (CORE-031).

    Args:
        template_path: Path đến bug-dashboard.md template.
        output_path: Path ghi output dashboard.
        session_id: Session ID.
        project_name: Tên dự án.
        scope: Phạm vi (all/system/module).
        profile: Mức độ (quick/standard/deep/exhaustive).
        current_phase: Giai đoạn hiện tại (5/6/7).
        issue_registry_path: Path đến issue-registry.json.
        fix_log_path: Path đến fix-log.json (optional — có thể chưa có entry).
        fix_report_path: Path đến fix-report.md (optional — chỉ có sau Phase 6).
        total_signals: Tổng số signals thô.
        dimensions_covered: Danh sách dimensions đã chạy.
        dimensions_total: Tổng số dimensions available.
        fixed_count_override: Ghi đè fixed_count (dùng khi đọc từ fix-report.md).

    Returns:
        Path đến output file đã ghi.
    """
    if not template_path.exists():
        raise FileNotFoundError(f"Dashboard template not found: {template_path}")

    # ── Đọc dữ liệu ──
    issues: list[dict] = []
    if issue_registry_path.exists():
        try:
            registry = json.loads(issue_registry_path.read_text(encoding="utf-8"))
            issues = registry.get("issues", [])
        except (json.JSONDecodeError, OSError):
            issues = []

    fix_log_entries: list[dict] = []
    if fix_log_path and fix_log_path.exists():
        try:
            fix_log = json.loads(fix_log_path.read_text(encoding="utf-8"))
            fix_log_entries = fix_log.get("entries", [])
        except (json.JSONDecodeError, OSError):
            fix_log_entries = []

    # ── Tính toán số liệu ──
    total_issues = len(issues)
    fixed_count = 0
    deferred_count = 0
    failed_count = 0

    for issue in issues:
        status = _get_fix_status(issue, fix_log_entries)
        if status == "fixed":
            fixed_count += 1
        elif status == "deferred":
            deferred_count += 1
        elif status == "failed":
            failed_count += 1

    if fixed_count_override is not None:
        fixed_count = fixed_count_override

    pending_count = total_issues - fixed_count - deferred_count - failed_count
    progress_pct = round((fixed_count / total_issues) * 100, 1) if total_issues > 0 else 100.0

    # ── Đọc template ──
    template_content = template_path.read_text(encoding="utf-8")

    # ── Build dynamic sections ──
    issue_rows = _build_issue_rows(issues, fix_log_entries)
    custom_actions = _build_custom_actions(issues, fix_log_entries)
    guidance_legend = _build_guidance_legend()

    # ── Populate template ──
    def pct(count: int) -> str:
        return str(round((count / total_issues) * 100, 1)) if total_issues > 0 else "0"

    populated = _populate_template(template_content, {
        "SESSION_ID": session_id,
        "PROJECT_NAME": project_name,
        "SCOPE": scope,
        "PROFILE": profile,
        "UPDATED_AT": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "CURRENT_PHASE": current_phase,
        "TOTAL_SIGNALS": str(total_signals),
        "TOTAL_ISSUES": str(total_issues),
        "FIXED_COUNT": str(fixed_count),
        "PENDING_COUNT": str(pending_count),
        "DEFERRED_COUNT": str(deferred_count),
        "FAILED_COUNT": str(failed_count),
        "DIMENSIONS_COVERED": dimensions_covered,
        "DIMENSIONS_TOTAL": dimensions_total,
        "PROGRESS_PCT": str(progress_pct),
        "FIXED_PCT": pct(fixed_count),
        "PENDING_PCT": pct(pending_count),
        "DEFERRED_PCT": pct(deferred_count),
        "FAILED_PCT": pct(failed_count),
        "CUSTOM_ACTIONS_SECTION": custom_actions,
        "GUIDANCE_LEGEND_SECTION": guidance_legend,
    })

    # Replace the per-issue placeholder block with actual issue rows.
    # Split on markers (exclusive) for robust cross-platform handling.
    begin_marker = "[BEGIN_ISSUE_ROWS]"
    end_marker = "[END_ISSUE_ROWS]"
    if begin_marker in populated and end_marker in populated:
        before = populated[: populated.index(begin_marker)]
        after = populated[populated.index(end_marker) + len(end_marker):]
        populated = before + "\n" + issue_rows + "\n" + after

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(populated, encoding="utf-8")
    return output_path


# ──────────────────────────────────────────────────────────────────────
# CLI
# ──────────────────────────────────────────────────────────────────────


def main(argv: list[str] | None = None) -> int:
    """CLI: generate bug-dashboard.md từ templates.

    Dashboard được khởi tạo rỗng ở Phase 1, populate ở Phase 5, cập nhật ở Phase 6, hoàn thiện ở Phase 7.
    Đặt ở SESSION_DIR root để người dùng theo dõi xuyên suốt phiên xử lý bug.

    Usage (chạy từ CWD=`_shared/`):
        # Phase 1: khởi tạo rỗng
        cd .claude/skills/workflow/_shared && python -m dashboard_generator \\
            --template ../wf-fix-bugs/templates/phase5-triage/bug-dashboard.md \\
            --output $SESSION_DIR/bug-dashboard.md \\
            --session-id YYYY-MM-DD-all-auto-01 \\
            --project-name "MyProject" \\
            --scope all --profile standard \\
            --current-phase 1 \\
            --total-signals 0 --dimensions-covered "" \\
            --dimensions-total 11

        # Phase 5: populate issues
        cd .claude/skills/workflow/_shared && python -m dashboard_generator \\
            --template ../wf-fix-bugs/templates/phase5-triage/bug-dashboard.md \\
            --output $SESSION_DIR/bug-dashboard.md \\
            --session-id YYYY-MM-DD-all-auto-01 \\
            --project-name "MyProject" \\
            --scope all --profile standard \\
            --current-phase 5 \\
            --issue-registry $SESSION_DIR/phase5-triage/issue-registry.json \\
            --fix-log $SESSION_DIR/phase5-triage/fix-log.json \\
            --total-signals 25 --dimensions-covered "QD1,QD3,QD5,QD9" \\
            --dimensions-total 11
    """
    import argparse
    import sys

    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="Bug/Signal Tracking Dashboard Generator (CORE-031)")
    parser.add_argument("--template", required=True, type=Path, help="Path đến bug-dashboard.md template")
    parser.add_argument("--output", required=True, type=Path, help="Path ghi output dashboard")
    parser.add_argument("--session-id", required=True, help="Session ID")
    parser.add_argument("--project-name", default="Unknown", help="Tên dự án")
    parser.add_argument("--scope", default="all", help="Phạm vi: all/system/module")
    parser.add_argument("--profile", default="standard", help="Mức độ: quick/standard/deep/exhaustive")
    parser.add_argument("--current-phase", default="5", help="Giai đoạn hiện tại: 5/6/7")
    parser.add_argument("--issue-registry", required=True, type=Path, help="Path đến issue-registry.json")
    parser.add_argument("--fix-log", type=Path, default=None, help="Path đến fix-log.json")
    parser.add_argument("--fix-report", type=Path, default=None, help="Path đến fix-report.md")
    parser.add_argument("--total-signals", type=int, default=0, help="Tổng signals thô")
    parser.add_argument("--dimensions-covered", default="", help="Comma-separated dimensions đã chạy")
    parser.add_argument("--dimensions-total", default="11", help="Tổng dimensions available")
    parser.add_argument("--fixed-count-override", type=int, default=None, help="Ghi đè fixed count")

    args = parser.parse_args(argv)

    try:
        out = generate_dashboard(
            template_path=args.template,
            output_path=args.output,
            session_id=args.session_id,
            project_name=args.project_name,
            scope=args.scope,
            profile=args.profile,
            current_phase=args.current_phase,
            issue_registry_path=args.issue_registry,
            fix_log_path=args.fix_log,
            fix_report_path=args.fix_report,
            total_signals=args.total_signals,
            dimensions_covered=args.dimensions_covered,
            dimensions_total=args.dimensions_total,
            fixed_count_override=args.fixed_count_override,
        )
    except (OSError, FileNotFoundError, json.JSONDecodeError, ValueError) as exc:
        print(f"[dashboard_generator ERROR] {exc}", file=sys.stderr)
        return 1

    print(json.dumps({"output": str(out), "mode": "dashboard"}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
