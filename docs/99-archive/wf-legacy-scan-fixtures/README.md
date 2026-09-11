# Fixtures — wf-legacy-scan v5.0 Test Harness

> **Trạng thái:** Folder structure + stub README đã tạo ở Phase A.6 (technical part).
> **Pending:** Thực tế fixture content + v4.1 baseline output (cần user hoặc session kế tiếp).

---

## Mục Đích

3 fixtures + v4.1 baseline outputs được dùng cho:

- **Phase D** — Backward-compat lock verify (standard profile phải match v4.1 output parity ±5%).
- **Phase I** — E2E integration test trên cả 4 profiles (surface/standard/deep/exhaustive).
- **Regression test** — mọi PR đụng vào wf-legacy-scan phải pass fixture tests.

---

## 3 Fixtures

| Fixture | Size | Stack | Language | Domain | Status |
|---------|------|-------|----------|--------|--------|
| `small-en/` | 50 files, 3 modules | TypeScript + React | EN | sales (simple CRM) | ⬜ Pending content |
| `medium-vn/` | 500 files, 10 modules | .NET + React | VN (qlkh, hoadon, qlns, ...) | finance + HR + sales | ⬜ Pending content |
| `large-mixed/` | 1,500 files, 30 modules | Node.js monorepo | EN + VN mix | finance + logistics | ⬜ Pending content |

---

## Baseline Output Folders

| Folder | Purpose |
|--------|---------|
| `small-en.baseline-v4.1/` | Output của `/wf-legacy-scan` v4.1 khi chạy trên `small-en/` |
| `medium-vn.baseline-v4.1/` | Output của `/wf-legacy-scan` v4.1 khi chạy trên `medium-vn/` |
| `large-mixed.baseline-v4.1/` | Output của `/wf-legacy-scan` v4.1 khi chạy trên `large-mixed/` |

Mỗi baseline folder phải chứa (sau khi user chạy scan):

- `project-context.md`
- `project-profile.json`
- `assessment-report.json`
- `ledger.json`
- `inventory/` (8 JSON files)
- `classified/` (batch files)
- `extracted/` (module files)
- `doc-quality-map.json`
- `impl-status-snapshot.json`

---

## Cách Tạo Fixture Content

### Option A — Generate synthetic (ưu tiên)

Dùng template có sẵn, rename modules, fill files:

```bash
# small-en (50 files, TS+React)
# Clone create-react-app hoặc Vite template → trim xuống 50 files → 3 modules:
#   - customer/
#   - sales/
#   - reporting/

# medium-vn (500 files, .NET + React)
# Clone ABP framework template hoặc custom → rename modules sang VN:
#   - qlkh/         (quản lý khách hàng)
#   - hoadon/       (hoá đơn)
#   - qlns/         (quản lý nhân sự)
#   - chamcong/     (chấm công)
#   - nhapkho/      (nhập kho)
#   - xuatkho/      (xuất kho)
#   - bangluong/    (bảng lương)
#   - baocao/       (báo cáo)
#   - caidat/       (cài đặt)
#   - dangnhap/     (đăng nhập/auth)

# large-mixed (1500 files, Node.js monorepo)
# Clone turborepo/nx template → add 30 mixed modules (EN + VN)
```

### Option B — Anonymize real project

Lấy 1 project nội bộ, strip secrets, rename domain identifiers nhạy cảm.

⚠️ **Rủi ro:** Privacy — phải review 2-pass trước khi commit.

---

## Workflow Để Hoàn Thành A.3

```bash
# 1. Content cho 3 fixtures (user hoặc session mới)
cd docs/design/skills/wf-legacy-scan/fixtures/small-en
# ... populate files ...

# 2. Checkout v4.1 baseline tag (sau khi user push tag legacy-scan-v4.1.0-baseline)
git checkout legacy-scan-v4.1.0-baseline

# 3. Run v4.1 scan trên mỗi fixture
cd fixtures/small-en
/wf-legacy-scan .
cp -r .mc-data/work/legacy-scan/* ../small-en.baseline-v4.1/
rm -rf .mc-data

# Lặp lại cho medium-vn và large-mixed

# 4. Checkout back phase-a branch
git checkout feat/wf-legacy-scan-v5.0-phase-a

# 5. Verify cả 3 baselines đầy đủ
for fx in small-en medium-vn large-mixed; do
  test -s fixtures/${fx}.baseline-v4.1/project-context.md && echo "${fx}: project-context.md OK"
  test -s fixtures/${fx}.baseline-v4.1/project-profile.json && echo "${fx}: project-profile.json OK"
  test -s fixtures/${fx}.baseline-v4.1/assessment-report.json && echo "${fx}: assessment-report.json OK"
  test -s fixtures/${fx}.baseline-v4.1/ledger.json && echo "${fx}: ledger.json OK"
  test -d fixtures/${fx}.baseline-v4.1/inventory/ && echo "${fx}: inventory/ OK"
done

# 6. Commit baseline outputs
git add docs/design/skills/wf-legacy-scan/fixtures/*.baseline-v4.1/
git commit -m "Phase A A.3: Add v4.1 baseline output for 3 fixtures"
```

---

## Acceptance Criteria (từ phase-A-design-closure.md §A.3)

- [x] Folder structure + README cho 3 fixtures tồn tại (**Phase A.6 tech part**)
- [ ] 3 fixtures có content với đúng size + stack + language (user hoặc session mới)
- [ ] 3 baseline folders có đầy đủ: project-context.md, project-profile.json, assessment-report.json, ledger.json, inventory/, classified/, extracted/
- [ ] Baselines committed vào git (fixture content có thể gitignore nếu lớn)
- [ ] `medium-vn` fixture có ≥5 modules với tên tiếng Việt (qlkh, hoadon, qlns, chamcong, nhapkho, ...)

---

## Risks

- Không có real VN project để anonymize → fallback: generate synthetic từ template.
- `large-mixed` 1,500 files có thể v4.1 context overflow → dùng `large=800 files` thay thế, note trong session log.
