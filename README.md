# BCERP — Hệ Thống Quản Trị Doanh Nghiệp (ERP) | BCAgency

> **Repository chính thức:** [https://github.com/thoong139/BCERP](https://github.com/thoong139/BCERP)  
> **Nền tảng:** MCV3 AI DevKit & Enterprise ERP Framework

---

## 📌 Giới Thiệu Dự Án

**BCERP** là giải pháp phần mềm quản trị doanh nghiệp toàn diện (Enterprise Resource Planning) được xây dựng và tối ưu hoá cho **BCAgency**, phát triển trên nền tảng **MCV3 DevKit** — framework kiến trúc phần mềm tích hợp sâu với các AI coding agents (Claude Code, Antigravity, CodeGraph,...).

Hệ thống bao gồm các phân hệ cốt lõi:
- **CRM & Khách hàng:** Quản lý thông tin đối tác, khách hàng, hành trình tương tác và lead pipeline.
- **Sales & Đơn hàng:** Quản lý báo giá, đơn hàng, chính sách giá và chiết khấu.
- **Finance & Kế toán:** Quản lý hóa đơn, thanh toán, công nợ, đối soát và sổ cái.
- **Vận hành & Dự án:** Quản trị quy trình làm việc, phân công nhiệm vụ và tiến độ dự án.

---

## 🏗 Kiến Trúc Hệ Thống & Cấu Trúc Repo

Dự án tuân thủ mô hình chuẩn hóa với 2 lớp: **DevKit Framework** & **ERP Application Modules**.

```text
BCERP/
├── .claude/                # Agent definitions, skills, hooks, và doc-framework
│   ├── agents/             # 62 chuyên gia domain (Architect, QA, Security, UX,...)
│   ├── skills/             # 35+ workflow skills (wf-fix-bugs, wf-implement-feature,...)
│   ├── hooks/              # Pre/Post validation hooks
│   ├── rules/              # Core coding standards và architectural rules
│   └── doc-framework/      # Templates tài liệu từ Phase 0 đến Phase 6
├── docs/                   # Single Source of Truth — Tài liệu chuẩn hóa toàn bộ dự án
│   ├── 00-overview/        # Tổng quan dự án, mục tiêu và mô hình 7 phases
│   ├── 01-architecture/    # Kiến trúc kỹ thuật và skills catalog
│   ├── 02-standards/       # Bộ tiêu chuẩn ràng buộc (coding, review, security)
│   └── 06-user-guides/     # Hướng dẫn vận hành end-to-end
├── scripts/                # Bộ công cụ tự động hóa kiểm thử, audit và deploy
├── tools/                  # Utilities và benchmark tooling
├── .codegraph/             # Code intelligence index (CodeGraph)
├── AGENTS.md               # Quy định điều phối AI Agents
├── CLAUDE.md               # Hướng dẫn tác vụ và workflow
└── README.md               # Tài liệu tổng quan dự án
```

---

## 🚀 Hướng Dẫn Bắt Đầu Nhanh

### 1. Yêu cầu môi trường
- **Git** >= 2.40
- **Node.js** >= 18.x
- **Python** >= 3.10
- **PowerShell** (Windows) hoặc **Bash** (Linux/macOS)

### 2. Thiết lập dự án

```bash
# Clone repository chính thức
git clone https://github.com/thoong139/BCERP.git
cd BCERP

# Kiểm tra trạng thái Git
git status
```

### 3. Vận hành với AI Coding Agents
Dự án được cấu hình sẵn cho các agent tự động tuân thủ theo các quy chuẩn trong `AGENTS.md` và `CLAUDE.md`.
- **Đọc tài liệu khởi đầu:** Bắt đầu với [docs/README.md](docs/README.md).
- **Audit & Validation:**
  ```powershell
  # Chạy audit tuân thủ quy chuẩn
  powershell -ExecutionPolicy Bypass -File .claude/scripts/run-devkit-bash.ps1 .claude/scripts/skill-compliance-audit.sh --all
  ```

---

## 📄 Bản Quyền & Giấy Phép

Phát triển và quản lý bởi **BCAgency** — Giữ toàn bộ quyền sở hữu trí tuệ.
