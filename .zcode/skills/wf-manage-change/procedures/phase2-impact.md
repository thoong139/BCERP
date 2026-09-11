# Phase 2: Impact Assessment

> Đánh giá toàn diện trước khi chạm vào bất kỳ file nào.
> Đây là cổng kiểm tra quan trọng nhất — đảm bảo không có regression.

> **Shared:** Xem `procedures/_shared.md` — Fix Rules, Checkpoint Protocol.

---

## PRE-GATE

- Phase 1 đã PASSED
- User đã confirm scope thay đổi
- `$SESSION_DIR/affected-artifacts.json` tồn tại với `docs_affected` hoặc `code_affected` non-empty

---

## INPUT

- `$SESSION_DIR/affected-artifacts.json` — từ Phase 1
- `.mc-data/docs/_meta/req-registry.json`
- Source code files (từ `code_affected[]`)
- Docs files (từ `docs_affected[]`)

---

## OUTPUT

- `$SESSION_DIR/impact-report.md` (template: `templates/impact-report.md`)

---

## Execution Strategy — Parallel Eligibility Check

Kiểm tra TRƯỚC khi quyết định song song:

| Điều kiện | Mô tả |
|-----------|-------|
| ✅ Context usage < 65% | Đủ window cho cả 2 luồng đồng thời |
| ✅ Luồng độc lập | Luồng A (code scan 2.1-2.2) và Luồng B (doc check 2.3) KHÔNG chia sẻ output trung gian |
| ✅ Không phụ thuộc kết quả | Không cần kết quả A để chạy B |

**Quy tắc:**

- NẾU ĐỦ cả 3 điều kiện → chạy 2.1-2.2 SONG SONG với 2.3
- NẾU KHÔNG ĐỦ (context cao, hoặc code scan cần làm input cho doc check) → SEQUENTIAL
- Bước 2.4 và 2.5 **LUÔN SEQUENTIAL** sau khi cả 2 luồng hoàn thành

---

## Steps

### CI-ROUTE: Impact Assessment (Protocol 20 §20.5)

> **Khi CI tools available:** Dung GitNexus + Serena de tu dong hoa impact analysis thay vi manual Grep/Read.
> **Graceful:** CI unavailable → fallback Grep/Read (current behavior, zero regression).

| CI Task | Primary Tool | Fallback | Purpose |
|---------|-------------|----------|---------|
| `impact_analysis` | **GitNexus** `impact({changed_symbol}, upstream, depth=3)` | Grep | Tu dong map blast radius: d=1 (WILL BREAK), d=2 (LIKELY AFFECTED), d=3 (MAY NEED TESTING) |
| `find_references` | **Serena** `find_references` | Grep | Tim tat ca call sites cua changed symbol |
| `api_routes` | **GitNexus** `route_map({affected_route})` | Grep | Kiem tra API consumers khi API thay doi |

> **Freshness caveat:** Neu index behind > 0 → "Results based on index N commits behind HEAD."

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 2.1 | **[LUỒNG A] Deep code scan:** Đọc mỗi code file trong `code_affected[]` → identify functions/classes bị ảnh hưởng trực tiếp | Read | Files read |
| 2.2 | **[LUỒNG A] Dependency scan:** Grep import/usage của affected code → identify indirect impacts | Grep | Dependencies mapped |
| 2.3 | **[LUỒNG B — song song với 2.1-2.2 nếu đủ điều kiện] Doc consistency check:** Đọc mỗi doc trong `docs_affected[]` → verify current content | Read | Docs read |
| 2.4 | **Test impact (sau khi Luồng A xong):** Scan existing tests cho affected code files | Glob/Grep | Tests found |
| 2.5 | **Regression risk assessment (sau khi cả 2 luồng xong):** Classify risk level (HIGH/MEDIUM/LOW) — xem §Risk Classification | — | Risk classified |
| 2.6 | **Tạo impact report:** READ template `templates/impact-report.md` → POPULATE impact data → WRITE `$SESSION_DIR/impact-report.md` | Write | File created |
| 2.7 | ***** USER GATE:**** Present impact report → hỏi user confirm tiếp tục | AskUserQuestion | Confirmed |

---

## Risk Classification

| Level | Trigger |
|-------|---------|
| **HIGH** | Thay đổi API contract → tất cả consumers bị ảnh hưởng<br>Thay đổi DB schema → migration needed<br>Xóa feature → downstream code bị break |
| **MEDIUM** | Thay đổi internal logic → callers trong cùng module<br>Thêm feature mới → ảnh hưởng cục bộ |
| **LOW** | Thay đổi config/display only<br>Bổ sung thông tin docs, không ảnh hưởng code |

---

## Impact Report — Required Headings

`impact-report.md` PHẢI chứa TẤT CẢ các headings sau (T3/T4 validation):

- `## Thay đổi chính`
- `## Cross-system Impacts`
- `## Regression Risk Assessment`
- `## Registry Changes`

Nội dung chi tiết: xem `templates/impact-report.md`.

---

## User Gate Logic (Step 2.7)

```
AskUserQuestion: "Đã phân tích impact. Tiếp tục Phase 3 (lập plan)?"
  Options:
    - "Yes, tiếp tục"           → Phase 3
    - "Điều chỉnh scope"         → quay lại Phase 1 (Step 1.5) để brainstorm lại
    - "Hủy thay đổi"             → STOP, đánh dấu session "cancelled"

NẾU user từ chối impact report (VD: "scope quá lớn"):
  → quay lại Phase 1 để điều chỉnh scope
  → KHÔNG tiếp tục Phase 3
```

---

## POST-GATE

- `$SESSION_DIR/impact-report.md` tồn tại, non-empty
- `jq` validation: report có đủ 4 required headings
- User đã review và confirm
- `change-status.json.impact_summary.risk_level` đã được set

**Trước POST-GATE — Cập nhật risk_level vào change-status.json:**
```
Update $SESSION_DIR/change-status.json:
  .impact_summary.risk_level = $RISK_LEVEL (từ Step 2.5)
  .impact_summary.docs_affected = |docs_affected|
  .impact_summary.code_affected = |code_affected|
  .impact_summary.tests_affected = |tests_affected|
  .impact_summary.cross_systems = |cross_systems|
  .impact_summary.registry_changes = (registry_changes non-empty)
```

**Verification (mc-postgate-check.sh):**
```bash
bash .claude/scripts/wf-manage-change/mc-postgate-check.sh \
  --file=$SESSION_DIR/impact-report.md \
  --type=markdown \
  --headings="## Thay đổi chính,## Cross-system Impacts,## Regression Risk Assessment,## Registry Changes"
# → {"pass":true} required. Nếu fail → auto-fix re-generate → retry tối đa 3 lần.
```

**Sau khi PASS:** Update `change-status.json.phases.phase2.status = "completed"` → tiếp tục `procedures/phase3-plan.md`.
